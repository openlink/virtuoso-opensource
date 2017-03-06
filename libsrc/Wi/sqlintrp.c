/*
 *  sqlintrp.c
 *
 *  $Id$
 *
 *  SQL interpreter
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
#include "sqlfn.h"
#include "lisprdr.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqltype.h"
#include "repl.h"
#include "replsr.h"
#include "mhash.h"

static instruction_t dummy_ins_t;

unsigned char ins_lengths[INS_MAX + 1] = {
  0,
  ALIGN_INSTR(sizeof (dummy_ins_t._.artm_fptr)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.pred)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.label)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.vret)),
  0, /* IN LABEL is not stored in the code_vec */
  ALIGN_INSTR(sizeof (dummy_ins_t._.cmp)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.open)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.fetch)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.close)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.subq)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.qnode)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.call)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.aref)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.aref)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.call)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.handler)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.handler_end)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.compound_start)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.compound_start)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.breakpoint)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.artm)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.artm)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.artm)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.artm)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.artm)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.bif)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.bret)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.agg)),
  ALIGN_INSTR(sizeof (dummy_ins_t._.for_vect))
};




caddr_t
ins_call_vec_deflt (state_slot_t ** default_ssls, caddr_t val, int n_formal, int * ctr)
{
  state_slot_t * defaults = *default_ssls;
  int nth = *ctr;
  if (!defaults)
    *default_ssls =  defaults = (state_slot_t *)dk_alloc_box_zero (sizeof (state_slot_t) * n_formal, DV_BIN);
  defaults[nth].ssl_type = SSL_CONSTANT;
  defaults[nth].ssl_constant = val;
  defaults[nth].ssl_sqt.sqt_dtp = DV_TYPE_OF (val);
  (*ctr)++;
  return (caddr_t)&defaults[nth];
}


void
ins_call_kwds (caddr_t * qst, query_t * proc, instruction_t * ins, caddr_t * params,
	       int * any_out, code_vec_t code_vec, state_slot_t ** vec_defaults)
{
  caddr_t err;
  int deflt_ctr = 0;
  int is_vec_call = proc->qr_proc_vectored;
  int n_param_box = BOX_ELEMENTS (params);
  caddr_t * kwds = ins->_.call.kwds, * copy = (caddr_t *) box_copy (params);
  state_slot_t * param_ssl = NULL;
  int param_inx;
  int inx;
  int n_ret_param = ((query_instance_t *)qst)->qi_query->qr_is_call == 2 ? 1 : 0;
  for (inx = 0; inx < n_param_box; inx++)
    params[inx] = (caddr_t) 0x7fffffff /* not a pointer nor an unboxed int */;
  memset (copy, 0, n_param_box * sizeof (caddr_t));
  for (inx = n_ret_param; inx < (ins->_.call.params ?
	BOX_ELEMENTS_INT (ins->_.call.params) : 0); inx++)
    {
      state_slot_t *actual_ssl = (state_slot_t *)ins->_.call.params[inx];
      if (kwds && kwds[inx - n_ret_param])
	{
	  param_inx = 0;
	  param_ssl = NULL;
	  DO_SET (state_slot_t *, param, &proc->qr_parms)
	    {
	      if (param && 0 == stricmp (param->ssl_name, kwds[inx - n_ret_param]))
		{
		  param_ssl = param;
		  break;
		}
	      param_inx++;
	    }
	  END_DO_SET();
	  if (!param_ssl)
	    {
	      err = srv_make_new_error ("07S01", "SR179",
		  "The function %s does not accept a keyword parameter %s", proc->qr_proc_name, kwds[inx - n_ret_param]);
	      goto err_end;
	    }
	}
      else
	{
	  param_inx = inx - n_ret_param;
	  param_ssl = (state_slot_t *) dk_set_nth (proc->qr_parms, param_inx);
	  if (!param_ssl)
	    {
	      err = srv_make_new_error ("07S01", "SR180",
		"Extra arguments to %s, takes only %lu", proc->qr_proc_name, (unsigned long) dk_set_length (proc->qr_parms));
	      goto err_end;
	    }
	}
      if (param_ssl && IS_SSL_REF_PARAMETER (param_ssl->ssl_type))
	{
	  caddr_t address;
	  if (actual_ssl->ssl_type == SSL_CONSTANT)
	    {
	      err = srv_make_new_error ("HY105", "SR181", "Cannot pass literal as reference parameter \"%.100s\"", param_ssl->ssl_name );
	      goto err_end;
	    }
	  if (SSL_VEC == actual_ssl->ssl_type ||SSL_REF == actual_ssl->ssl_type)
	    {
	      QNCAST (query_instance_t, caller, qst);
	      int row = caller->qi_set;
	      data_col_t * dc = QST_BOX (data_col_t *, qst, actual_ssl->ssl_index);
	      if (!(DCT_BOXES & dc->dc_type))
		{
		  err = srv_make_new_error ("42000", "VEC..", "In vectored code calling non-vectored inout parameter mode is supported only if caller variable is a boxed vector, e.g. type any array (caller variable \"%.100s\", calling parameter \"%.100s\")",
		      actual_ssl->ssl_name, param_ssl->ssl_name );
		  goto err_end;
		}
	      if (SSL_REF == actual_ssl->ssl_type)
		row = sslr_set_no (qst, actual_ssl, row);
	      address = (caddr_t)&((caddr_t*)dc->dc_values)[row];
	    }
	  else if ((!ins->_.call.ret || !IS_REAL_SSL (ins->_.call.ret) || !ins->_.call.ret->ssl_is_observer) &&
	      actual_ssl->ssl_is_observer)
	    address = udt_i_find_member_address (qst, actual_ssl, code_vec, ins);
	  else
	    address = (caddr_t) qst_address (qst, actual_ssl);
	  params[param_inx] = address;
	  *any_out = 1;
	}
      else
	{
	  if (is_vec_call)
	    params[param_inx] = (caddr_t)actual_ssl;
	  else
	    copy[param_inx] = params[param_inx] = box_copy_tree (QST_GET (qst, actual_ssl));
	}
    }
  inx = 0;
  DO_SET (state_slot_t *, formal, &proc->qr_parms)
    {
      if (0x7fffffff == (ptrlong) params[inx])
	{
	  if (IS_SSL_REF_PARAMETER (formal->ssl_type)
	      || formal->ssl_vec_param >= SSL_VP_OUT)
	    {
	      err = srv_make_new_error ("HY502", "SR182",
		"inout or out parameter %s not supplied in keyword parameter call of %s", formal->ssl_name, proc->qr_proc_name);
	      goto err_end;
	    }
	  /* XXX: what about the =0 case */
	  if (proc->qr_parm_default && BOX_ELEMENTS (proc->qr_parm_default) > inx && proc->qr_parm_default[inx])
	    params[inx] = is_vec_call ? ins_call_vec_deflt (vec_defaults, (caddr_t)proc->qr_parm_default[inx], n_param_box, &deflt_ctr) : box_copy_tree (proc->qr_parm_default[inx]);
	  else
	    {
	      err = srv_make_new_error ("07S01", "SR183",
		  "Required argument %s (no %d) not supplied to %s", formal->ssl_name, inx + 1, proc->qr_proc_name);
	      goto err_end;
	    }
	}
      inx++;
    }
  END_DO_SET();
  dk_free_box (copy);
  return;
err_end:
  dk_free_tree (copy);
  sqlr_resignal (err);
}

caddr_t
sqlr_run_bif_in_sandbox (bif_metadata_t *bmd, caddr_t *args, caddr_t *err_ret)
{
  int argctr, argcount = BOX_ELEMENTS (args);
  size_t ssls_size = sizeof (state_slot_t) * argcount;
  state_slot_t *ssls = NULL;
  state_slot_t **params = (state_slot_t **)dk_alloc_list (argcount);
  query_instance_t *qi_stub = (query_instance_t *)dk_alloc_list_zero (QI_FIRST_FREE + argcount);
  caddr_t ret_val = NULL;
  if (ssls_size)
    {
      ssls = (state_slot_t *)dk_alloc (ssls_size);
      memset (ssls, 0, ssls_size);
    }
  qi_stub->qi_client = sqlc_client ();
  qi_stub->qi_u_id = U_ID_NOBODY;
  qi_stub->qi_g_id = U_ID_NOGROUP;
  qi_stub->qi_thread = THREAD_CURRENT_THREAD;
  for (argctr = argcount; argctr--; /* no step */)
    {
      state_slot_t *sl = ssls + argctr;
      caddr_t val = args[argctr];
      sl->ssl_index = QI_FIRST_FREE + argctr;
      sl->ssl_type = SSL_CONSTANT;
      sl->ssl_constant = ((caddr_t *)(qi_stub))[QI_FIRST_FREE + argctr] = val;
      sl->ssl_dtp = DV_TYPE_OF (val);
      if (sl->ssl_dtp == DV_LONG_STRING)
        sl->ssl_prec = box_length (val) - 1;
      else
        sl->ssl_prec = ddl_dv_default_prec (sl->ssl_dtp);
      params[argctr] = sl;
    }
  QR_RESET_CTX
    {
      if (!bmd->bmd_is_pure)
        sqlr_new_error ("42000", "SR650", "Only pure function can be executed in a sandbox, %.200s() is not pure", bmd->bmd_name);
      ret_val = bmd->bmd_main_impl ((caddr_t *)qi_stub, err_ret, params);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      err_ret[0] = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
      /*no POP_QR_RESET*/;
    }
  END_QR_RESET
  dk_free_box ((caddr_t)qi_stub);
  dk_free_box ((caddr_t)params);
  if (ssls) dk_free (ssls, ssls_size);
  if (NULL != err_ret[0])
    {
      dk_free_tree (ret_val);
      return NULL;
    }
  return ret_val;
}

void
ins_call_bif (instruction_t * ins, caddr_t * qst, code_vec_t code_vec)
{
  caddr_t err = NULL;
      caddr_t value;
  instruction_t ins_tmp;
  instruction_t * ins_to_use = ins;
  if (ins->_.bif.ret == CV_CALL_PROC_TABLE)
	{
	  sqlr_new_error ("42000", "SR184",
	      "Built-in function is not allowed as the outermost "
	      "function in a procedure view.  "
	      "Define an intermediate PL function to call the bif.");
	}
  if (ins->_.bif.vectored)
    {
#if 0
      sqlr_new_error ("42000", "SR184", "Vectored Built-in function is not allowed");
#else
      memcpy (&ins_tmp, ins, INS_LEN (ins));
      ins_to_use = &ins_tmp;
      ins_tmp._.bif.bif = bif_find (ins->_.bif.proc);
#endif
    }

#ifdef WIRE_DEBUG
  /*      list_wired_buffers (__FILE__, __LINE__, "BIF call start");*/
#endif
  value = ins_to_use->_.bif.bif (qst, &err, ins_to_use->_.call.params);
#ifdef WIRE_DEBUG
  /*      list_wired_buffers (__FILE__, __LINE__, "BIF call finish");*/
#endif

      if (!err)
	{
      if (ins_to_use->_.bif.ret && IS_REAL_SSL (ins_to_use->_.bif.ret))
	{
	  if (!IS_BOX_POINTER (value))
	    qst_set_long (qst, ins_to_use->_.bif.ret, (ptrlong)value);
	  else
	    qst_set (qst, ins_to_use->_.bif.ret, value);
	}
	  else
	    dk_free_tree (value);
	  return;
	}
      else
	{
#ifndef NDEBUG
	  /* GK: that should really be uncommented, but all the bifs should be checked first */
	  dk_free_tree (value);
#endif
	  sqlr_resignal (err);
	}

}


void
ins_call_bif_vec (instruction_t * ins, caddr_t * qst, code_vec_t code_vec, int * use_scalar)
{
  caddr_t err = NULL;
  if (ins->_.bif.ret == CV_CALL_PROC_TABLE)
	{
	  sqlr_new_error ("42000", "SR184",
			  "Vectored built-in function is not allowed as the outermost "
	      "function in a procedure view.  "
	      "Define an intermediate PL function to call the bif.");
	}

  ((bif_vec_t)ins->_.bif.bif) (qst, &err, ins->_.call.params, ins->_.bif.ret);
  if (err)
    {
      if (BIF_NOT_VECTORED == err)
	{
	  *use_scalar = 1;
	  return;
	}
    sqlr_resignal (err);
}
}


void
complete_proc_name (char * proc_name, char * complete, char * def_qual, char * def_owner)
{
  char q[MAX_NAME_LEN];
  char o[MAX_NAME_LEN];
  char n[MAX_NAME_LEN];
  q[0] = 0;
  o[0] = 0;
  n[0] = 0;
  sch_split_name (def_qual, proc_name, q, o, n);
  if (0 == o[0])
    strcpy_ck (o, def_owner);
  snprintf (complete, MAX_QUAL_NAME_LEN, "%s.%s.%s", q, o, n);
}

#ifdef ROLLBACK_XQ
#error rollback xq should not be defd
#endif

#define CALL_SET_PN(ins, proc) \
{ \
  if (proc && proc->qr_pn && INS_CALL == ins->ins_type)	\
    { \
      proc_name_t * prev_pn = ins->_.call.pn; \
      ins->_.call.pn = proc_name_ref (proc->qr_pn); \
      proc_name_free (prev_pn); \
    } \
}



void
ins_call (instruction_t * ins, caddr_t * qst, code_vec_t code_vec)
{
  PROC_SAVE_VARS;
  state_slot_t *vec_defaults = NULL;
  oid_t eff_g_id, eff_u_id;
  int is_computed = ins->ins_type == INS_CALL_IND;
  caddr_t value;
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  client_connection_t * cli = qi->qi_client;
  query_t *proc = NULL;
  caddr_t proc_name = is_computed ? qst_get (qst, ins->_.call.proc_ssl) : ins->_.call.proc;
  char *proc_name_2 = NULL;
  state_slot_t *ret = ins->_.call.ret;
  caddr_t err = NULL;
  caddr_t pars_auto[30];
  int param_len = box_length ((caddr_t) ins->_.call.params);
  caddr_t *pars;
  caddr_t ptmp;
  int inx;
  int any_out = 0;
  int n_ret_param = qi->qi_query->qr_is_call == 2 ? 1 : 0;
  char auto_qi[AUTO_QI_DEFAULT_SZ];
  if (ins->_.call.pn && (proc = ins->_.call.pn->pn_query))
    ;
  else if (DV_TYPE_OF (proc_name) == DV_ARRAY_OF_POINTER)
    {
      caddr_t err = NULL;
      caddr_t *proc_mtd_call = (caddr_t *)proc_name;
      sql_class_t *udt = NULL;
      sql_method_t *mtd = NULL;
      ptrlong mtd_inx = -1;
      if (BOX_ELEMENTS (proc_name) != 2 || !DV_STRINGP (proc_mtd_call[0]) ||
	  !DV_LONG_INT == DV_TYPE_OF (proc_mtd_call[1]))
	{
	  err = srv_make_new_error ("22023", "UD004", "Invalid proc_name array supplied");
	  goto report_error;
	}
      udt = sch_name_to_type (isp_schema (qi->qi_space), proc_mtd_call[0]);
      mtd_inx = unbox (proc_mtd_call[1]);
      if (!udt)
	{
	  err = srv_make_new_error ("22023", "UD005", "Non-existent user defined type %.200s",
	      proc_mtd_call[0]);
	  goto report_error;
	}
      if (!udt->scl_method_map || mtd_inx < 0 ||
	  mtd_inx >= BOX_ELEMENTS_INT (udt->scl_method_map))
	{
	  err = srv_make_new_error ("22023", "UD006", "No such method in user defined type %.200s",
	      proc_mtd_call[0]);
	  goto report_error;
	}
      mtd = udt->scl_method_map[mtd_inx];

      if (udt->scl_ext_lang == UDT_LANG_SQL)
	{ /* make that an qr_exec so it makes kwd parms */
	  if (!mtd->scm_qr)
	    {
	      err = srv_make_new_error ("22023", "UD007", "Method %.200s in user defined type %.200s not defined",
		  mtd->scm_name, proc_mtd_call[0]);
	      goto report_error;
	    }
	  proc = mtd->scm_qr;
	  proc_name = mtd->scm_name;
	}
      else
	{ /* should call the bif - no kwd_params */
	  caddr_t udi = NULL, ref = NULL;
          caddr_t ret;
	  dtp_t dtp;

	  udi = qst_get (qst, ins->_.call.params[0]);
	  dtp = DV_TYPE_OF (udi);
	  if (dtp == DV_REFERENCE)
	    {
	      ref = udi;
	      udi = udo_find_object_by_ref (ref);
	    }
	  else if (dtp != DV_OBJECT)
	    sqlr_new_error ("22023", "UD008",
		"Method %.200s needs an user defined type instance as argument 1, not an arg of type %s (%d)",
		mtd->scm_name, dv_type_title (dtp), dtp);

          ret = udt_method_call (qst, udt, udi, mtd, ins->_.call.params,
	      BOX_ELEMENTS (ins->_.call.params));
	  if (ins->_.call.ret && IS_REAL_SSL (ins->_.call.ret))
	    qst_set (qst, ins->_.call.ret, ret);
	  else
	    dk_free_tree (ret);
	  return;
	}
report_error:
      if (err)
	sqlr_resignal (err);
    }
  else if (DV_STRINGP (proc_name) || DV_C_STRING == DV_TYPE_OF (proc_name))
    {
      if (!QR_IS_MODULE_PROC (qi->qi_query))
	{
	  proc = sch_partial_proc_def (isp_schema (qi->qi_space), proc_name,
	      qi->qi_query->qr_qualifier, CLI_OWNER (qi->qi_client));
	  /*fprintf (stderr, "in sch_partial_proc_def for %s returned %p\n", proc_name, proc);*/
	  if ((query_t *) -1L == proc)
	    proc = NULL;
	  CALL_SET_PN (ins, proc);
	}
      else
	proc = sch_proc_def (isp_schema (qi->qi_space), proc_name);
    }
  else /*if (is_computed)*/
    {
      sqlr_new_error ("42001", "SR518",
	  "Procedure name value of invalid type %s (%d) supplied in an indirect CALL statement",
	  dv_type_title (DV_TYPE_OF (proc_name)), (int) DV_TYPE_OF (proc_name));
    }
  if (!proc || IS_REMOTE_ROUTINE_QR (proc))
    {
      bif_t bif = bif_find (proc_name);
      if (bif)
	{
	  caddr_t value = bif (qst, &err, ins->_.call.params);
	  if (!err)
	    {
	      if (ins->_.call.ret && IS_REAL_SSL (ins->_.call.ret))
		qst_set (qst, ins->_.call.ret, value);
	      else
		dk_free_tree (value);
	      return;
	    }
	  else
	    sqlr_resignal (err);
	}
      if (QR_IS_MODULE_PROC (qi->qi_query))
	{
	  char rq[MAX_NAME_LEN], ro[MAX_NAME_LEN], rn[MAX_NAME_LEN];
	  sch_split_name (qi->qi_query->qr_qualifier,
	      qi->qi_query->qr_module->qr_proc_name,
              rq, ro, rn);
	  proc_name_2 = sch_full_proc_name_1 (isp_schema (qi->qi_space), proc_name,
	      rq, CLI_OWNER (qi->qi_client), rn);
	}
      if (!proc_name_2)
	proc_name_2 = sch_full_proc_name (isp_schema (qi->qi_space), proc_name,
	    qi->qi_query->qr_qualifier, CLI_OWNER (qi->qi_client));
      if (proc_name_2)
	proc = sch_proc_def (isp_schema (qi->qi_space), proc_name_2);
      if (proc && !IS_REMOTE_ROUTINE_QR (proc) && !is_computed)
	{
	  ins->_.call.proc = box_dv_uname_string (proc_name_2);
	  qr_garbage (qi->qi_query, proc_name); /* free later, not now because this not serialized */
	  CALL_SET_PN (ins, proc);
	}
      if (!proc)
	{
	  char complete_proc_name_str[MAX_QUAL_NAME_LEN];
	  complete_proc_name (proc_name, complete_proc_name_str, qi->qi_query->qr_qualifier, CLI_OWNER (qi->qi_client));
	  sqlr_new_error ("42001", "SR185", "Undefined procedure %s.", complete_proc_name_str);
	}
    }
  param_len -= n_ret_param * sizeof (caddr_t);
  if (proc->qr_to_recompile)
    proc = qr_recompile (proc, NULL);
  if (!qi->qi_query->qr_proc_name)
    {
      eff_g_id = qi->qi_g_id;
      eff_u_id = qi->qi_u_id;
    }
  else
    {
      user_t * usr = sec_id_to_user (qi->qi_query->qr_proc_owner);
      eff_u_id = qi->qi_query->qr_proc_owner;
      if (usr)
	eff_g_id = usr->usr_g_id;
      else
	eff_g_id = eff_u_id;
    }
  if (!sec_proc_check (proc, eff_g_id, eff_u_id))
    sqlr_new_error ("42000", "SR186:SECURITY", "No permission to execute procedure %s with user ID %d, group ID %d",
      proc_name, (int)eff_g_id, (int)eff_u_id );
  if (1 || ins->_.call.kwds || 0 == param_len)
    {
      int formal_len = dk_set_length (proc->qr_parms);
      BOX_AUTO (ptmp, pars_auto, formal_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      pars = (caddr_t *) ptmp;

ins_call_kwds (qst, proc, ins, pars, &any_out, code_vec, &vec_defaults);
    }
#ifndef ROLLBACK_XQ
  dk_free_tree ((caddr_t) qi->qi_thread->thr_func_value); /* IvAn/010801/LeakOnReturn: this line added */
#endif
  qi->qi_thread->thr_func_value = NULL;
  /* Procedure's call is published */
  if (CV_CALL_PROC_TABLE == ins->_.call.ret)
    {
      PROC_SAVE_PARENT;
      cli->cli_result_qi = qi;
      cli->cli_result_ts = (table_source_t *) unbox_ptrlong (qst_get (qst, ins->_.call.proc_ssl));
    }
  if (proc->qr_proc_vectored)
    {
    err = qr_subq_exec_vec (qi->qi_client, proc, qi,
			    (caddr_t *) & auto_qi, sizeof (auto_qi), (state_slot_t**)pars, ins->_.call.ret, NULL, NULL);
      if (vec_defaults)
	dk_free_box ((caddr_t)vec_defaults);
    }
  else
  err = qr_subq_exec (qi->qi_client, proc, qi,
		 (caddr_t *) & auto_qi, sizeof (auto_qi), NULL, pars, NULL);
  if (CV_CALL_PROC_TABLE == ins->_.call.ret)
    {
      if (err || qi->qi_set == qi->qi_n_sets - 1 || proc->qr_proc_vectored)
	{
	  /* for vectored call of non vectored proc filling proc table temp, do not drop the fill itc until there is termination from eerror of having done the last set */
	  hash_area_t *ha = (hash_area_t *) cli->cli_result_ts;
	  caddr_t *result_qst = (caddr_t *) cli->cli_result_qi;
	  if (result_qst)
	    {
	      it_cursor_t *ins_itc = (it_cursor_t *) result_qst[ha->ha_insert_itc->ssl_index];
	      if (ins_itc)
		itc_free (ins_itc);
	      result_qst[ha->ha_insert_itc->ssl_index] = NULL;
	    }
	  else log_error ("result_qst is null");
	}
      PROC_RESTORE_SAVED;
    }
  BOX_DONE (pars, pars_auto);
  value = qi->qi_thread->thr_func_value;
  qi->qi_thread->thr_func_value = NULL;
  if ((caddr_t) SQL_NO_DATA_FOUND == err
      && CALLER_CLIENT == qi->qi_caller)
    {
      /* unhandled 'not found' will appear as end of possible results and
       * procedure return to client.
       * It will be resignaled if caller is a procedure
       */
      err = SQL_SUCCESS;
    }
  if (err)
    {
      dk_free_tree (value);
      sqlr_resignal (err);
    }
  if (!ret
      && (qi->qi_caller == CALLER_CLIENT
	  || qi->qi_lc))
    {
      /* Top level proc. Make client return block */
      caddr_t *cli_ret = (caddr_t *) dk_alloc_box_zero
      (param_len + (2 + n_ret_param) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      cli_ret[0] = (caddr_t) QA_PROC_RETURN;
      if (n_ret_param)
	cli_ret[2] = value;
      else
	cli_ret[1] = value;
#ifndef ROLLBACK_XQ
      value = NULL;		/* IvAn/010801/LeakOnReturn: this line added */
#endif
      inx = n_ret_param;
      DO_SET (state_slot_t *, sl, &proc->qr_parms)
      {
	if (IS_SSL_REF_PARAMETER (sl->ssl_type))
	  {
	    int kwdinx = inx;
	    if (ins->_.call.kwds)
	      {
		DO_BOX (caddr_t, kwd, kwdinx, ins->_.call.kwds)
		  {
		    if (kwd && 0 == stricmp (kwd, sl->ssl_name))
		      {
			kwdinx += n_ret_param;
			goto kwd_found;
		      }
		  }
		END_DO_BOX;
		kwdinx = inx;
	      }
	  kwd_found:
	    if (BOX_ELEMENTS_INT (cli_ret) > kwdinx + 2)
	      cli_ret[kwdinx + 2] = box_copy_tree (qst_get (qst, ins->_.call.params[kwdinx]));
	  }
	inx++;
      }
      END_DO_SET ();
      if (qi->qi_lc)
	/* if invoked from server internal api and result needed, put it in lc */
	qi->qi_lc->lc_proc_ret = (caddr_t) cli_ret;
      else
	qi->qi_proc_ret = (caddr_t) cli_ret;
    }

  if (!proc->qr_proc_vectored)
    {
  if (ret && IS_REAL_SSL (ins->_.call.ret))
    qst_set (qst, ins->_.call.ret, value);
#ifndef ROLLBACK_XQ /* IvAn/010801/LeakOnReturn: this #if added */
  else if (NULL != value)
    dk_free_tree (value);
#else /* this variant was here, causing memory leak */
  else if (qi->qi_caller != CALLER_CLIENT
	   && !qi->qi_lc)
    dk_free_tree (value);
#endif
}
}


query_t *
ins_call_proc (instruction_t * ins, caddr_t * qst, code_vec_t code_vec)
{
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  query_t *proc = NULL;
  caddr_t proc_name = ins->_.call.proc;
  char *proc_name_2 = NULL;

  if (ins->_.call.pn && (proc = ins->_.call.pn->pn_query))
    ;
  else if (DV_STRINGP (proc_name) || DV_C_STRING == DV_TYPE_OF (proc_name))
    {
      if (!QR_IS_MODULE_PROC (qi->qi_query))
	{
	  proc = sch_partial_proc_def (isp_schema (qi->qi_space), proc_name,
	      qi->qi_query->qr_qualifier, CLI_OWNER (qi->qi_client));
	  if ((query_t *) -1L == proc)
	    proc = NULL;
	  CALL_SET_PN (ins, proc);
	}
      else
	proc = sch_proc_def (isp_schema (qi->qi_space), proc_name);
    }
  else /*if (is_computed)*/
    {
      sqlr_new_error ("42001", "SR518",
	  "Procedure name value of invalid type %s (%d) supplied in an indirect CALL statement",
	  dv_type_title (DV_TYPE_OF (proc_name)), (int) DV_TYPE_OF (proc_name));
    }
  if (!proc || IS_REMOTE_ROUTINE_QR (proc))
    {
      if (QR_IS_MODULE_PROC (qi->qi_query))
	{
	  char rq[MAX_NAME_LEN], ro[MAX_NAME_LEN], rn[MAX_NAME_LEN];
	  sch_split_name (qi->qi_query->qr_qualifier,
	      qi->qi_query->qr_module->qr_proc_name,
              rq, ro, rn);
	  proc_name_2 = sch_full_proc_name_1 (isp_schema (qi->qi_space), proc_name,
	      rq, CLI_OWNER (qi->qi_client), rn);
	}
      if (!proc_name_2)
	proc_name_2 = sch_full_proc_name (isp_schema (qi->qi_space), proc_name,
	    qi->qi_query->qr_qualifier, CLI_OWNER (qi->qi_client));
      if (proc_name_2)
	proc = sch_proc_def (isp_schema (qi->qi_space), proc_name_2);
      if (proc && !IS_REMOTE_ROUTINE_QR (proc))
	{
	  ins->_.call.proc = box_dv_uname_string (proc_name_2);
	  qr_garbage (qi->qi_query, proc_name); /* free later, not now because this not serialized */
	  CALL_SET_PN (ins, proc);
	}
      if (!proc)
	{
	  char complete_proc_name_str[MAX_QUAL_NAME_LEN];
	  complete_proc_name (proc_name, complete_proc_name_str, qi->qi_query->qr_qualifier, CLI_OWNER (qi->qi_client));
	  sqlr_new_error ("42001", "SR185", "Undefined procedure %s.", complete_proc_name_str);
	}
    }
  if (proc->qr_to_recompile)
    proc = qr_recompile (proc, NULL);
  return proc;
}

void
ins_call_vec_vec (instruction_t * ins, caddr_t * qst, query_t * proc, code_vec_t code_vec)
{
  PROC_SAVE_VARS;
  state_slot_t * vec_defaults = NULL;
  oid_t eff_g_id, eff_u_id;
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  client_connection_t * cli = qi->qi_client;
  caddr_t err = NULL;
  caddr_t pars_auto[30];
  int param_len = box_length ((caddr_t) ins->_.call.params), formal_len;
  caddr_t *pars;
  caddr_t ptmp;
  int any_out = 0;
  int n_ret_param = qi->qi_query->qr_is_call == 2 ? 1 : 0;
  char auto_qi[AUTO_QI_DEFAULT_SZ];

  param_len -= n_ret_param * sizeof (caddr_t);
  if (!qi->qi_query->qr_proc_name)
    {
      eff_g_id = qi->qi_g_id;
      eff_u_id = qi->qi_u_id;
    }
  else
    {
      user_t * usr = sec_id_to_user (qi->qi_query->qr_proc_owner);
      eff_u_id = qi->qi_query->qr_proc_owner;
      if (usr)
	eff_g_id = usr->usr_g_id;
      else
	eff_g_id = eff_u_id;
    }
  if (!sec_proc_check (proc, eff_g_id, eff_u_id))
    sqlr_new_error ("42000", "SR186:SECURITY", "No permission to execute vectored procedure %s with user ID %d, group ID %d",
      proc->qr_proc_name ? proc->qr_proc_name : "<unknown>", (int)eff_g_id, (int)eff_u_id );
  formal_len = dk_set_length (proc->qr_parms);
  BOX_AUTO (ptmp, pars_auto, formal_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  pars = (caddr_t *) ptmp;
  ins_call_kwds (qst, proc, ins, pars, &any_out, code_vec, &vec_defaults);
#ifndef ROLLBACK_XQ
  dk_free_tree ((caddr_t) qi->qi_thread->thr_func_value); /* IvAn/010801/LeakOnReturn: this line added */
#endif
  qi->qi_thread->thr_func_value = NULL;
  /* Procedure's call is published */
  if (CV_CALL_PROC_TABLE == ins->_.call.ret)
    {
      PROC_SAVE_PARENT;
      cli->cli_result_qi = qi;
      cli->cli_result_ts = (table_source_t *) unbox_ptrlong (qst_get (qst, ins->_.call.proc_ssl));
    }
  err = qr_subq_exec_vec (qi->qi_client, proc, qi,
			  (caddr_t *) & auto_qi, sizeof (auto_qi), (state_slot_t **)pars, ins->_.call.ret, NULL, NULL);
  if (vec_defaults)
    dk_free_box ((caddr_t)vec_defaults);
  if (CV_CALL_PROC_TABLE == ins->_.call.ret)
    {
      hash_area_t *ha = (hash_area_t *)cli->cli_result_ts;
      caddr_t *result_qst = (caddr_t *)cli->cli_result_qi;
      it_cursor_t *ins_itc = (it_cursor_t *) result_qst[ha->ha_insert_itc->ssl_index];
      if (ins_itc)
	itc_free (ins_itc);
      result_qst [ha->ha_insert_itc->ssl_index] = NULL;
      PROC_RESTORE_SAVED;
    }
  BOX_DONE (pars, pars_auto);
  qi->qi_thread->thr_func_value = NULL;
  if (err)
    {
      sqlr_resignal (err);
    }
  if (CALLER_CLIENT == qi->qi_caller && !qi->qi_query->qr_select_node)
    {
      int n_sets = qi->qi_n_sets, first_set = 0, set;
      db_buf_t set_mask = qi->qi_set_mask;
      caddr_t * rets = (caddr_t*)dk_alloc_box_zero (sizeof (caddr_t) * n_sets, DV_ARRAY_OF_POINTER);
      SET_LOOP
	{
	  rets[set] = list (3, QA_PROC_RETURN, NULL, NULL);
	}
      END_SET_LOOP;
      qi->qi_proc_ret = (caddr_t)rets;
    }
}


void
ins_call_vec (instruction_t * ins, caddr_t * inst, code_vec_t code_vec, int first_set, int n_sets)
{
  QNCAST (query_instance_t, qi, inst);
  query_t * qr ;
  caddr_t proc_name = ins->_.call.proc;
  if (INS_CALL_IND == ins->ins_type || DV_ARRAY_OF_POINTER == box_tag (proc_name))
    goto general;
  qr = ins_call_proc (ins, inst, code_vec);
  if (!qr->qr_proc_vectored || n_sets - first_set <= 1)
    goto general;
  ins_call_vec_vec (ins, inst, qr, code_vec);
  return;
 general:
  {
    caddr_t * rets = NULL;
    int set;
    db_buf_t set_mask = qi->qi_set_mask;
    if (CALLER_CLIENT == qi->qi_caller && !ins->_.call.ret && !qi->qi_query->qr_select_node)
      rets = dk_alloc_box_zero (sizeof (caddr_t) * n_sets, DV_ARRAY_OF_POINTER);
    SET_LOOP
      {
	qi->qi_proc_ret = (caddr_t)rets;
	ins_call (ins, inst, code_vec);
	if (rets)
	  rets[set] = qi->qi_proc_ret;
      }
    END_SET_LOOP;
    qi->qi_proc_ret = rets;
  }
}


int
qn_is_flushable (data_source_t * qn)
{
  if (IS_RTS (((remote_table_source_t *)qn))
      || (qn_input_fn)insert_node_input == qn->src_input
      || (qn_input_fn)query_frag_input == qn->src_input)
    return 1;
  return 0;
}


void
ins_qnode_resume (data_source_t * qn, caddr_t * qst)
{
  /* if it's a remote ts with array params flush the  rows */
  if (qn_is_flushable (qn))
    {
      if (qst[qn->src_in_state])
	qn->src_input (qn, qst, NULL);
    }
}

void
qn_init (table_source_t * ts, caddr_t * inst)
{
  /* Reset a single state query node in a qr */
  if (ts->src_gen.src_out_fill)
    QST_INT (inst, ts->src_gen.src_out_fill) = 0;
  cl_node_init (ts, inst);

  if (IS_TS (ts))
    {
      if (ts->ts_aq_qis)
	qst_set (inst, ts->ts_aq_qis, NULL);
      if (ts->ts_order_ks  /* not set if inx op */
      && ts->ts_order_ks->ks_key->key_id == KI_TEMP)
    {
      /* if there is a read from sort temp and there is a cursor for the space, delete it here, so as not to reuse the cursor on a different temp space later */
      it_cursor_t *volatile order_itc = NULL;
      if (ts->ts_order_cursor)
	{
	  order_itc = TS_ORDER_ITC (ts, inst);
	  TS_ORDER_ITC (ts, inst) = NULL;
	  if (order_itc)
	    itc_free (order_itc);
	}
    }
    }

  qn_record_in_state ((data_source_t*) ts, inst, NULL);
  /* no subq nodes continuable after init */
  if (ts->src_gen.src_input == (qn_input_fn) setp_node_input)
    {
      QNCAST (setp_node_t, setp, ts);
      if (HA_FILL != setp->setp_ha->ha_op)
    setp_temp_clear ((setp_node_t *) ts, ((setp_node_t*)ts)->setp_ha, inst);
    }
  else if (ts->src_gen.src_input == (qn_input_fn) fun_ref_node_input)
    {
      fun_ref_node_t * fref = (fun_ref_node_t*) ts;
      DO_SET (hash_area_t *, ha, &fref->fnr_distinct_ha)
	{
	  setp_temp_clear (NULL, ha, inst);
	}
      END_DO_SET();
    }
  else if (ts->src_gen.src_input == (qn_input_fn) skip_node_input)
    {
      QNCAST (skip_node_t, sk, ts);
      if (sk->src_gen.src_sets)
	dc_reset (QST_BOX (data_col_t*, inst, sk->sk_row_ctr->ssl_index));
      else
      qst_set_long (inst, ((skip_node_t *)ts)->sk_row_ctr, 0);
    }
  else if ((qn_input_fn) select_node_input == ts->src_gen.src_input
      || (qn_input_fn) select_node_input_subq == ts->src_gen.src_input)
    {
      QNCAST (select_node_t, sel, ts);
      if (sel->sel_row_ctr)
	qst_set_long (inst, sel->sel_row_ctr, 0);
      if (sel->sel_row_ctr_array)
	qst_set_long (inst, sel->sel_row_ctr_array, 0);
    }
  else if (IS_QN (ts, trans_node_input))
    tn_qn_init ((data_source_t*)ts, inst);
  else if (IS_QN (ts, chash_read_input))
    {
      key_source_t * ks = ts->ts_order_ks;
      if (ts->ts_nth_slice)
	QST_INT (inst, ts->ts_nth_slice) = 0;
      QST_INT (inst, ks->ks_nth_cha_part) = 0;
      QST_BOX (chash_page_t *, inst, ks->ks_cha_chp) = NULL;
      QST_INT (inst, ks->ks_pos_in_temp) = 0;
    }
}



void
subq_init (query_t * subq, caddr_t * inst)
{
  dk_set_t nodes = subq->qr_bunion_reset_nodes ? subq->qr_bunion_reset_nodes : subq->qr_nodes;
  QNCAST (QI, qi, inst);
  if (qi->qi_slice_needs_init)
    return; /* this is a just allocated dfg branch that does not yet have the dcs in place.  Nodes are not inited and hence cannot be safely reset */
  /* nodes to reset - a bunion term's nodes are owned by the enclosing qr, hence the different list */
  if (subq->qr_cl_run_started)
    inst[subq->qr_cl_run_started] = NULL;

  DO_SET (table_source_t *, ts, &nodes)
    {
      cl_node_init (ts, inst);
      if (ts->src_gen.src_input == (qn_input_fn) subq_node_input)
	{
	  QNCAST (subq_source_t, sqs, ts);
	  subq_init (sqs->sqs_query, inst);
	}
	   else if ((ts->src_gen.src_input == (qn_input_fn) table_source_input ||
	  ts->src_gen.src_input == (qn_input_fn) table_source_input_unique)
	  && ts->ts_order_ks  /* not set if inx op */
	  && ts->ts_order_ks->ks_key->key_id == KI_TEMP
		    && ts->ts_order_cursor)
	{
	  /* if there is a read from sort temp and there is a cursor for the space, delete it here, so as not to reuse the cursor on a different temp space later */
	  it_cursor_t *volatile order_itc = TS_ORDER_ITC (ts, inst);
	  TS_ORDER_ITC (ts, inst) = NULL;
	  if (order_itc)
	    itc_free (order_itc);
	}
    }
  END_DO_SET();

  DO_SET (table_source_t *, ts, &nodes)
    {
      qn_record_in_state ((data_source_t*) ts, inst, NULL);
      /* no subq nodes continuable after init */
      if (ts->src_gen.src_input == (qn_input_fn) fun_ref_node_input)
	{
	  fun_ref_node_t * fref = (fun_ref_node_t*) ts;
	  DO_SET (hash_area_t *, ha, &fref->fnr_distinct_ha)
	    {
	      setp_temp_clear (NULL, ha, inst);
	    }
	  END_DO_SET();
	}
      else if (IS_QN (ts, hash_fill_node_input))
	{
	  QNCAST (fun_ref_node_t, fref, ts);
	  setp_temp_clear (fref->fnr_setp, fref->fnr_setp->setp_ha, inst);
	}
      qn_init (ts, inst);
    }
  END_DO_SET ();
  if (subq->qr_select_node && subq->qr_select_node->sel_row_ctr)
    qst_set_long (inst, subq->qr_select_node->sel_row_ctr, 0);
  if (subq->qr_select_node && subq->qr_select_node->sel_row_ctr_array)
    qst_set (inst, subq->qr_select_node->sel_row_ctr_array, NULL);
}

caddr_t
subq_handle_reset (query_instance_t * qi, int reset)
{
  /* Handle a reset into qr_exec or qr_more. Prime thread only */
  query_instance_t *caller = qi->qi_caller;
  caddr_t err = NULL;
  QI_CHECK_ANYTIME_RST (qi, reset);
  switch (reset)
    {
    case RST_KILLED:
      {
	err = srv_make_new_error ("HY008", "SR189", "Async statement killed by SQLCancel.");
	return (err);
      }
    case RST_ENOUGH:
      {
	return NULL;
      }
    case RST_DEADLOCK:
      {
	int trx_code = qi->qi_trx->lt_error;
	if (!trx_code)
	  trx_code = LTE_DEADLOCK;
	SEND_TRX_ERROR_CALLER (err, caller, trx_code, LT_ERROR_DETAIL (qi->qi_trx));
	return err;
      }
    case RST_ERROR:
      {
	err = thr_get_error_code (qi->qi_thread);
	return err;
      }

    default:
      GPF_T1 (" Bad subg reset code");
    }
  return NULL;
}


void
qi_bunion_term_reset (query_instance_t * qi, query_t * qr)
{
  caddr_t * state = (caddr_t *) qi;
  union_node_t * un = qr->qr_bunion_node;
  int nth = (int) unbox (qst_get (state, un->uni_nth_output));
  query_t * term = (query_t *) dk_set_nth (un->uni_successors, nth - 1);
  if (term)
    subq_init (term, state);
}


int
qi_bunion_error_row (query_instance_t * qi, query_t * qr, caddr_t err)
{
  int inx, any = 0;
  select_node_t * sel = qr->qr_select_node;
  union_node_t * un = qr->qr_bunion_node;
  caddr_t * state = (caddr_t *) qi;
  caddr_t nth = qst_get (state, un->uni_nth_output);
  qi->qi_set = 0;
  DO_BOX (state_slot_t *, ssl, inx, sel->sel_out_slots)
    {
      if (inx >= sel->sel_n_value_slots)
	break;
      if (ssl->ssl_name && 0 == CASEMODESTRCMP (ssl->ssl_name, "__SQLSTATE"))
	{
	  any = 1;
	  qst_set ((caddr_t*) qi, ssl, box_copy (ERR_STATE (err)));
	}
      else if (ssl->ssl_name && 0 == CASEMODESTRCMP (ssl->ssl_name, "__MESSAGE"))
	{
	  any = 1;
	  qst_set ((caddr_t*) qi, ssl, box_copy (ERR_MESSAGE (err)));
	}
      else if (ssl->ssl_name && 0 == CASEMODESTRCMP (ssl->ssl_name, "__SET_NO"))
	{
	  any = 1;
	  qst_set ((caddr_t*) qi, ssl, box_copy (nth));
	}
      else
	qst_set_null ((caddr_t*) qi, ssl);
    }
  END_DO_BOX;
  return any;
}


caddr_t
qi_bunion_reset (query_instance_t * qi, query_t * qr, int is_subq)
{
  int err_row;
  caddr_t err = NULL;
 bunion_next:
  err = thr_get_error_code (qi->qi_thread);
  qi_bunion_term_reset (qi, qr);
  err_row = qi_bunion_error_row (qi, qr, err);
  dk_free_tree (err);
  QR_RESET_CTX_T (qi->qi_thread)
    {
      if (err_row)
	{
	  data_source_t * sel_prev = qr->qr_select_node->src_gen.src_prev;
	  if (sel_prev && sel_prev->src_out_fill)
	    { /* vectored case */
	      QST_INT ((caddr_t*)qi, sel_prev->src_out_fill) = 1; /* 1 row of output for the error row */
	    }
	qn_input ((data_source_t *) qr->qr_select_node, (caddr_t *) qi, (caddr_t *) qi);
	}
      qr_resume_pending_nodes (qr, (caddr_t*) qi);
    }
  QR_RESET_CODE
    {
      POP_QR_RESET;
      if (RST_ERROR == reset_code)
	goto bunion_next;
      if (is_subq)
	return (subq_handle_reset (qi, reset_code));
      else
	return (qi_handle_reset (qi, reset_code));

    }
  END_QR_RESET;
  return (SQL_BUNION_COMPLETE);
}


void
qr_resume_pending_nodes (query_t * subq, caddr_t * inst)
{
  dk_set_t nodes = subq->qr_bunion_reset_nodes ? subq->qr_bunion_reset_nodes : subq->qr_nodes;
  QNCAST (QI, qi, inst);
  int n_sets_save = qi->qi_n_sets;
  /* if the qr is a union term, continue the nodes that belong to the union term itself. qr_nodes is null and the nodes of the union term are added to the nodes of the containing qr */
cont_innermost_loop:
  DO_SET (data_source_t *, src, &nodes)
  {
    if (inst[src->src_in_state])
      {
	if (src->src_continue_reset)
	  dc_reset_array (inst, src, src->src_continue_reset, -1);
	qi->qi_n_sets = n_sets_save;
	SRC_RESUME (src, inst);
	src->src_input (src, inst, NULL);
	SRC_RETURN (src, inst);
	goto cont_innermost_loop;
      }
  }
  END_DO_SET ();
  if (subq->qr_cl_run_started)
    inst[subq->qr_cl_run_started] = NULL;
  {
    query_instance_t * qi = (query_instance_t *)inst;
    client_connection_t * cli = qi->qi_client;
    if ((qi->qi_caller == CALLER_CLIENT || qi->qi_caller == CALLER_LOCAL)
	&& cli->cli_row_autocommit && cli->cli_n_to_autocommit && !cli->cli_clt && !cli->cli_in_daq)
      {
	/* at the end of a top level dml or other stmt, transact if in autocommit mode and not cluster server thread */
	caddr_t err = NULL;
	cli->cli_n_to_autocommit = 0;
	bif_commit ((caddr_t*) qi, &err, NULL);
	if (err)
	  sqlr_resignal (err);
      }
  }
}


void
cli_restore_slice (client_connection_t * cli, cl_slice_t * old_csl)
{
  if (old_csl)
    {
      caddr_t err = NULL;
      cli_set_slice (cli, old_csl->csl_clm, old_csl->csl_id, &err);
      dk_free_tree (err);
    }
  else
    cli_set_slice (cli, NULL, QI_NO_SLICE, NULL);
}


caddr_t
subq_next (query_t * subq, caddr_t * inst, int cr_state)
{
  query_instance_t *qi = (query_instance_t *) inst;
  client_connection_t * cli = qi->qi_client;
  cl_slice_t * old_csl = cli->cli_csl;
  QR_RESET_CTX_T (qi->qi_thread)
  {
    if (CR_INITIAL == cr_state)
      {
	int qi_sets = qi->qi_n_sets;
	if (subq->qr_no_cast_error)
	  qi->qi_no_cast_error = 1;
	qn_input (subq->qr_head_node, inst, inst);
	qi->qi_n_sets = qi_sets;
	qr_resume_pending_nodes (subq, inst);
      }
    else
      {
	qr_resume_pending_nodes (subq, inst);
      }
  }
  QR_RESET_CODE
  {
    POP_QR_RESET;
    QI_BUNION_RESET (qi, subq, 1);
    cli_restore_slice (cli, old_csl);
    return (subq_handle_reset (qi, reset_code));
  }
  END_QR_RESET;
 qr_complete:
  cli_restore_slice (cli, old_csl);
  return ((caddr_t) SQL_NO_DATA_FOUND);
}



int
ins_subq (instruction_t * ins, caddr_t * qst)
{
  caddr_t err;
  query_instance_t * qi = (query_instance_t *) qst;
  char save_lock = qi->qi_lock_mode;
  int n_sets_save = qi->qi_n_sets;
  db_buf_t sm_save = qi->qi_set_mask;
  client_connection_t * cli = qi->qi_client;
  int at_start = cli->cli_anytime_started;
  if (!ins->_.subq.query->qr_select_node)
    cli->cli_anytime_started = 0;
  qi->qi_n_affected = 0;
  qi->qi_n_sets = 0;
  qi->qi_set_mask = NULL;
  subq_init (ins->_.subq.query, qst);
  err = subq_next (ins->_.subq.query, qst, CR_INITIAL);
  qi->qi_lock_mode = save_lock;
  qi->qi_set_mask = sm_save;
  qi->qi_n_sets = n_sets_save;
  cli->cli_anytime_started = at_start;
  if (ins->_.subq.query->qr_proc_vectored)
    {
      int n_rows;
      select_node_t * sel = ins->_.subq.query->qr_select_node;
      if (IS_BOX_POINTER (err))
	sqlr_resignal (err);
      if (!sel)
	return DVC_MATCH;
      n_rows = QST_INT (qst, sel->src_gen.src_prev->src_out_fill);
      if (!n_rows)
	{
	  qst_set_bin_string (qst, ins->_.subq.scalar_ret, NULL, 0, DV_DB_NULL);
	  return DVC_MATCH;
	}
      qi->qi_set = 0;
      qst_set (qst, ins->_.subq.scalar_ret, box_copy_tree (qst_get (qst, sel->sel_out_slots[0])));
      return DVC_MATCH;
    }
  if (err == (caddr_t) SQL_NO_DATA_FOUND
      && ins->_.subq.query->qr_select_node
      && BOX_ELEMENTS (ins->_.subq.query->qr_select_node->sel_out_slots) > 0
      && ins->_.subq.query->qr_select_node->sel_out_slots[0])
    qst_set_bin_string (qst, ins->_.subq.query->qr_select_node->sel_out_slots[0], (db_buf_t) "", 0, DV_DB_NULL);
  if (err != SQL_SUCCESS
      && err != (caddr_t) SQL_NO_DATA_FOUND)
    {
      sqlr_resignal (err);
    }
  return DVC_MATCH;
}

void
ins_open (instruction_t * ins, caddr_t * qst)
{
  /*int inx;*/

  if (ins->_.open.exclusive)
    ins->_.open.query->qr_lock_mode = PL_EXCLUSIVE;
/*
  DO_BOX (ST *, opt, inx, ins->_.open.options)
  {
    if (opt == (ST *) EXCLUSIVE_OPT)
      ins->_.open.query->qr_lock_mode = PL_EXCLUSIVE;
  }
  END_DO_BOX;
*/
  subq_init (ins->_.open.query, qst);

  qst_set (qst, ins->_.open.cursor, (caddr_t) CR_INITIAL);
}


void
bing ()
{
}


#define AC_ENLIST_CK(qi)

void
ins_fetch (instruction_t * ins, caddr_t * qst)
{
  QNCAST (query_instance_t, qi, qst);
  int n_sets_save = qi->qi_n_sets;
  int inx;
  query_t * qr = ins->_.fetch.query;
  select_node_t * sel = qr->qr_select_node;
  int n_rows = qr->qr_proc_vectored ? QST_INT (qst, sel->src_gen.src_prev->src_out_fill) : 1;
  int nth_row = ins->_.fetch.row_ctr ? QST_INT (qst, ins->_.fetch.row_ctr) : 0;
  caddr_t err;
  int cr_state = (int) (ptrlong) qst_get (qst, ins->_.fetch.cursor);
  if (cr_state == CR_CLOSED)
    {
      sqlr_new_error ("24000", "SR190", "Fetch of unopened cursor.");
    }

  /*
     On open cursor, check the params and if they changed , re-bind them
   */
  if (!qr->qr_proc_vectored && cr_state == CR_OPEN)
    {
      dk_set_t nodes = qr->qr_bunion_reset_nodes ? qr->qr_bunion_reset_nodes : qr->qr_nodes;
      DO_SET (table_source_t *, ts, &nodes)
	{
	  if (ts->src_gen.src_input == (qn_input_fn) table_source_input && ts->ts_order_ks && ts->ts_order_cursor)
	    {
	      it_cursor_t *volatile order_itc = TS_ORDER_ITC (ts, qst);
	      if (order_itc && order_itc->itc_type == ITC_CURSOR)
		ks_check_params_changed (order_itc, ts->ts_order_ks, qst);
	    }
	}
      END_DO_SET();
    }
  if (CR_INITIAL == cr_state || nth_row + 1 == n_rows)
    {
      if (ins->_.fetch.row_ctr)
	nth_row = QST_INT (qst, ins->_.fetch.row_ctr) = 0;
  err = subq_next (ins->_.fetch.query, qst, cr_state);
      qi->qi_n_sets = n_sets_save;
  if (err != SQL_SUCCESS)
    {
      qst_set (qst, ins->_.fetch.cursor, (caddr_t) CR_AT_END);
      sqlr_resignal (err);
    }
  if (cr_state == CR_INITIAL)
    qst_set (qst, ins->_.fetch.cursor, (caddr_t) CR_OPEN);

      AC_ENLIST_CK (((query_instance_t*)qst));
    }
  else if (ins->_.fetch.row_ctr)
    QST_INT (qst, ins->_.fetch.row_ctr) = nth_row = nth_row + 1;
  if (ins->_.fetch.targets)
    {
      int old_set = qi->qi_set;
      int set_no = sel->sel_set_no ? qst_vec_get_int64 (qst, sel->sel_set_no, nth_row) : 0;
      if (ins->_.fetch.row_ctr)
	qi->qi_set = nth_row;
      if (ins->_.fetch.set_no_ret)
	qst_set_long (qst, ins->_.fetch.set_no_ret, set_no);
      DO_BOX (state_slot_t *, target, inx, ins->_.fetch.targets)
      {
	if (target)
	  {
	    caddr_t value = box_copy_tree (qst_get (qst, ins->_.fetch.query->qr_select_node->sel_out_slots[inx]));
	    qst_set (qst, ins->_.fetch.targets[inx], value);
	  }
      }
      END_DO_BOX;
      qi->qi_set = old_set;
    }
}


void
ins_close (instruction_t * ins, caddr_t * qst)
{
  qst_set (qst, ins->_.close.cursor, CR_CLOSED);	/* will free old value */
}


#define IS_COMPOUND_START(ins) ((ins)->ins_type == INS_COMPOUND_START && !(ins)->_.compound_start.skip)
#define IS_COMPOUND_END(ins) ((ins)->ins_type == INS_COMPOUND_END && !(ins)->_.compound_start.skip)

static instruction_t *
ins_handler_end (code_vec_t code_vec, caddr_t *qst, instruction_t *end)
{
  short ofs = (short) unbox (qst_get (qst, end->_.handler_end.throw_location));

  if (end->_.handler_end.type == HANDT_EXIT)
    {
      long end_nesting_level = 0;
      short end_ofs = ofs;
      instruction_t *in = INSTR_ADD_OFS (code_vec, end_ofs);

      DO_INSTR (in2, end_ofs, code_vec)
	{
	  in = in2;
	  if (IS_COMPOUND_END(in))
	    {
	      if (!end_nesting_level)
		break;
	      else
		end_nesting_level--;
	    }
	  else if (IS_COMPOUND_START(in))
	    end_nesting_level++;
	}
      END_DO_INSTR
      return in;
    }
  else
    return INSTR_ADD_OFS (code_vec, ofs);
}

#ifdef PLDBG

static void
do_pl_stats (query_instance_t *qi, int32 lineno)
{
  int32 thisct;
  ptrlong *callct;
  static caddr_t no_caller;
  caddr_t caller_name = NULL;
  query_t *qr = qi->qi_query, *qr_caller = NULL;
  query_instance_t *caller = qi->qi_caller;
  if (!no_caller)
    no_caller = box_dv_short_string ("<dynamic>");
  if (IS_POINTER (caller))
    {
      qr_caller = caller->qi_query;
      caller_name = qr_caller ? qr_caller->qr_proc_name : NULL;
    }
  mutex_enter (qr->qr_stats_mtx);
  thisct = (int32) (ptrlong) gethash ((void *) (ptrlong) lineno, qr->qr_line_counts);
  sethash ((void *) (ptrlong) lineno,  qr->qr_line_counts, (void *) (ptrlong) (++thisct));
  if (!caller_name)
    caller_name = no_caller;
  if (!qi->qi_last_break)
    {
      callct = (ptrlong *) id_hash_get (qr->qr_call_counts, (caddr_t)&caller_name);
      if (callct)
	(*callct)++;
      else
	{
	  caddr_t new_caller_name = box_dv_short_string (caller_name);
	  ptrlong callct = 1;
	  id_hash_set (qr->qr_call_counts, (caddr_t)&new_caller_name, (caddr_t)&callct);
	}
      qr->qr_calls++;
    }
  mutex_leave (qr->qr_stats_mtx);
}

void pldbg_make_answer (client_connection_t * cli);

static void
ins_break (instruction_t * ins, caddr_t * qst)
{
  query_instance_t *qi = (query_instance_t *)qst;
  client_connection_t *cli = qi->qi_client;
  if (0 != (pl_debug_all & 2))
    do_pl_stats (qi, (int32)(ins->_.breakpoint.line_no)); /* this must be always before setting qi_last_break */
  cli->cli_pldbg->pd_inst = qi; /* this was inside break */
  qi->qi_last_break = (void *)ins;
  if ((ins->_.breakpoint.brk_set & 2) ||
      ((ins->_.breakpoint.brk_set & 1) && cli->cli_pldbg->pd_session) ||
      (cli->cli_pldbg->pd_session &&
       (cli->cli_pldbg->pd_step & (PLDS_STEP|PLDS_INT))) ||
      (qi->qi_step > 0 &&
       cli->cli_pldbg->pd_session &&
       cli->cli_pldbg->pd_step)
      )

    {
      cli->cli_pldbg->pd_is_step = 1;

      if (cli->cli_pldbg->pd_session &&
	  (cli->cli_pldbg->pd_step & (PLDS_STEP|PLDS_NEXT))
	  && cli->cli_pldbg->pd_send)
	cli->cli_pldbg->pd_send (cli);

      if (!qi->qi_step && !(cli->cli_pldbg->pd_step & PLDS_STEP))
	cli->cli_pldbg->pd_step = 0;

      ins->_.breakpoint.brk_set &= 2;

      qi->qi_step = PLDS_NEXT;
      cli->cli_pldbg->pd_frame = NULL;

      semaphore_enter (cli->cli_pldbg->pd_sem);
      if (cli->cli_pldbg) /* as in the middle debug connection can be dropped*/
	cli->cli_pldbg->pd_is_step = 0;
    }
}
#endif

static int
handler_has_state (instruction_t *handler, caddr_t err_state, long *star_pos)
{
  if (IS_BOX_POINTER (handler->_.handler.states))
    {
      int inx;
      DO_BOX (caddr_t *, state, inx, handler->_.handler.states)
	{
	  if (err_state == (caddr_t) state ||
	      (state == (caddr_t *) SQL_SQLEXCEPTION &&
	       IS_BOX_POINTER (err_state) &&
	       strncmp (err_state, "00", 2) &&
	       strncmp (err_state, "01", 2) &&
	       strncmp (err_state, "02", 2)) ||
	      (IS_BOX_POINTER (err_state) && IS_BOX_POINTER (state) &&
	       unbox (state[1]) >= *star_pos &&
	       !strncmp (state[0], err_state, unbox (state[1]))))
	    {
	      if (IS_BOX_POINTER (err_state))
		*star_pos = IS_BOX_POINTER (state) ? (long) unbox (state[1]) : -1;
	      return 1;
	    }
	}
      END_DO_BOX;
    }
  return 0;
}

#define OPT_CACHE_SIZE	 50

typedef struct opt_set_s {
  dk_set_t os_set;
  caddr_t os_initial[OPT_CACHE_SIZE];
  int os_ctr;
} opt_set_t;

static void
opt_set_push (opt_set_t *set, caddr_t value)
{
  if (set->os_ctr < sizeof (set->os_initial) / sizeof (caddr_t))
    set->os_initial[set->os_ctr++] = value;
  else
    dk_set_push (&set->os_set, value);
}

static caddr_t
opt_set_pop (opt_set_t *set)
{
  if (set->os_set)
    return (caddr_t) dk_set_pop (&set->os_set);
  else if (set->os_ctr > 0)
    return set->os_initial[--set->os_ctr];
  else
    return NULL;
}

#define opt_set_init(set) \
	memset (set, 0, sizeof (opt_set_t));

#define opt_set_free(set) \
        { \
	  dk_set_free ((set)->os_set); \
	  opt_set_init (set); \
	}
#define opt_set_empty(set) \
	(!(set)->os_set && !(set)->os_ctr)

/* enable this to get the opt_set_xxx functions debugged */
/* #define OPT_SET_DEBUG */

#ifdef OPT_SET_DEBUG
static int
opt_set_test ()
{
  ptrlong inx;
  opt_set_t test_set;

  dbg_printf (("Starting OPT set tests\n"));
  opt_set_init (&test_set);


  dbg_printf (("After init\n"));
  for (inx = 0; inx < OPT_CACHE_SIZE * 2; inx ++)
    {
      dbg_printf (("Fill %ld\n", (long) inx));
      opt_set_push (&test_set, (caddr_t) inx);
    }
  dbg_printf (("After fillup\n"));

  if (test_set.os_ctr != OPT_CACHE_SIZE)
    GPF_T1 ("full os_ctr is not set at end");
  if (dk_set_length (test_set.os_set) != OPT_CACHE_SIZE)
    GPF_T1 ("full os_set length is not correct");
  if (opt_set_empty (&test_set))
    GPF_T1 ("full set empty");

  dbg_printf (("After fillup checks\n"));
  for (inx = OPT_CACHE_SIZE; inx > 0; inx --)
    {
      ptrlong inx1 = (ptrlong) opt_set_pop (&test_set);
      dbg_printf (("Popped %ld\n", (long) inx1));
      if (inx1 + 1 != inx + OPT_CACHE_SIZE)
	GPF_T1 ("data not consistent");
    }
  dbg_printf (("After half-empty\n"));

  if (test_set.os_ctr != OPT_CACHE_SIZE)
    GPF_T1 ("half os_ctr is not set at start");
  if (dk_set_length (test_set.os_set) != 0)
    GPF_T1 ("half os_set length is not 0");
  if (opt_set_empty (&test_set))
    GPF_T1 ("half set empty");

  dbg_printf (("After half-empty checks\n"));
  for (inx = OPT_CACHE_SIZE; inx > 0; inx --)
    {
      ptrlong inx1 = (ptrlong) opt_set_pop (&test_set);
      dbg_printf (("Popped %ld\n", (long) inx1));
      if (inx1 + 1 != inx)
	GPF_T1 ("data not consistent");
    }
  dbg_printf (("After empty\n"));

  if (test_set.os_ctr != 0)
    GPF_T1 ("empty os_ctr is not set at start");
  if (dk_set_length (test_set.os_set) != 0)
    GPF_T1 ("empty os_set length is not 0");
  if (!opt_set_empty (&test_set))
    GPF_T1 ("empty set not empty");

  dbg_printf (("After empty checks\n"));
  for (inx = 0; inx < OPT_CACHE_SIZE * 2; inx ++)
    opt_set_push (&test_set, (caddr_t) inx);
  dbg_printf (("After second fillup\n"));

  opt_set_free (&test_set);
  dbg_printf (("After free\n"));

  if (test_set.os_ctr != 0)
    GPF_T1 ("cleared os_ctr is not set at start");
  if (dk_set_length (test_set.os_set) != 0)
    GPF_T1 ("cleared os_set length is not 0");
  if (!opt_set_empty (&test_set))
    GPF_T1 ("cleared set not empty");
  dbg_printf (("After free checks\n"));
  return 0;
}
#endif

long callstack_on_exception = 0;
void err_append_callstack_procname (caddr_t err, caddr_t proc_name, caddr_t file_name, int line_no)
{
  if (0 >= callstack_on_exception)
    return;
  if (DV_TYPE_OF (err) == DV_ARRAY_OF_POINTER)
    {
      caddr_t err_msg = ERR_MESSAGE (err), new_msg;
      const char *in_msg = (NULL != strstr (err_msg, "\nin\n") ? ",\n" : "\nin\n");
      const char *msg_proc_name = proc_name ? proc_name : "<Top Level>";
      char line[15];

      if (line_no == -1)
	strcpy_ck (line, ":(BIF)");
      else if (line_no > 0)
	snprintf (line, sizeof (line), ":%d", line_no);
      else
	line[0] = 0;

      if (file_name)
	new_msg = box_sprintf (
	    box_length (err_msg) +
	    strlen (in_msg) +
	    strlen (msg_proc_name) +
	    strlen (file_name) +
	    strlen (line) + 2,
	    "%s%s%s(%s%s)",
	    err_msg,
	    in_msg,
	    msg_proc_name,
	    file_name,
	    line );
      else
	new_msg = box_sprintf (
	    box_length (err_msg) +
	    strlen (in_msg) +
	    strlen (msg_proc_name) +
	    strlen (line),
	    "%s%s%s%s",
	    err_msg,
	    in_msg,
	    msg_proc_name,
	    line );
      dk_free_box (ERR_MESSAGE (err));
      ERR_MESSAGE (err) = new_msg;
    }
}


caddr_t
box_err_print_box (caddr_t param_value, int call_depth)
{
  if (call_depth > 1)
    return box_dv_short_string ("...");
  switch (DV_TYPE_OF (param_value))
    {
    case DV_STRING:
      return box_sprintf (200, "'%.100s'%s", param_value,
        ( ((box_length (param_value) > 100) ||
          (box_length (param_value) != (strlen (param_value) + 1))) ?
          " (truncated)" : "") );
    case DV_UNAME:
      return box_sprintf (200, "UNAME'%.100s'%s", param_value,
        ( ((box_length (param_value) > 100) ||
          (box_length (param_value) != (strlen (param_value) + 1))) ?
          " (truncated)" : "") );
    case DV_LONG_INT:
      return box_sprintf (40, BOXINT_FMT, unbox (param_value));
    case DV_DB_NULL:
      return box_string ("NULL");
    case DV_OBJECT:
      return box_sprintf (500, "instance %p of %.300s", param_value, UDT_I_CLASS(param_value)->scl_name);
    case DV_IRI_ID:
      {
        iri_id_t iid = unbox_iri_id (param_value);
        if (iid >= MIN_64BIT_BNODE_IRI_ID)
          return box_sprintf (30, "#ib" IIDBOXINT_FMT, (boxint)(iid-MIN_64BIT_BNODE_IRI_ID));
        else
          return box_sprintf (30, "#i" IIDBOXINT_FMT, (boxint)(iid));
      }
    case DV_REFERENCE:
      {
        caddr_t udi = udo_find_object_by_ref (param_value);
        if (NULL != udi)
          return box_sprintf (500, "reference %p to instance %p of %.300s", param_value, udi, UDT_I_CLASS(udi)->scl_name);
        else
          return box_sprintf (500, "reference %p to missing UDT instance", param_value);
      }
    case DV_RDF:
      {
        rdf_bigbox_t *rbb = (rdf_bigbox_t *)param_value;
        caddr_t printed_rb_box = box_err_print_box (rbb->rbb_base.rb_box, call_depth+1);
        caddr_t res;
        if (rbb->rbb_base.rb_chksum_tail)
          {
            caddr_t printed_rbb_chksum = box_err_print_box (rbb->rbb_chksum, call_depth+1);
            res = box_sprintf (500, "rdf_box (%.300s, %d, %d, %d, %d, %.50s, %d)",
              printed_rb_box, (int)(rbb->rbb_base.rb_type), (int)(rbb->rbb_base.rb_lang),
              (int)(rbb->rbb_base.rb_ro_id), (int)(rbb->rbb_base.rb_is_complete),
              printed_rbb_chksum, (int)(rbb->rbb_box_dtp) );
            dk_free_box (printed_rbb_chksum);
          }
        else
          {
            res = box_sprintf (500, "rdf_box (%.300s, %d, %d, %d, %d)",
              printed_rb_box, (int)(rbb->rbb_base.rb_type), (int)(rbb->rbb_base.rb_lang),
              (int)(rbb->rbb_base.rb_ro_id), (int)(rbb->rbb_base.rb_is_complete) );
          }
        dk_free_box (printed_rb_box);
        return res;
      }
    default:
      return box_sprintf (100, "(%s value, tag %d)", dv_type_title (DV_TYPE_OF (param_value)), DV_TYPE_OF (param_value));
    }
}

void err_append_callstack_param (caddr_t err, caddr_t param_name, caddr_t param_value)
{
  if (1 >= callstack_on_exception)
    return;
  if (NULL == param_name)
    param_name = "?unnamed?";
  if (DV_TYPE_OF (err) == DV_ARRAY_OF_POINTER)
    {
      caddr_t err_msg = ERR_MESSAGE (err);
      caddr_t new_msg;
      caddr_t param_print = box_err_print_box (param_value, 0);
      new_msg = box_sprintf (30 + box_length (err_msg) + strlen (param_name) + strlen (param_print),
	"%s,\n  %10s => %s", err_msg, param_name, param_print );
      dk_free_box (param_print);
      dk_free_box (ERR_MESSAGE (err));
      ERR_MESSAGE (err) = new_msg;
    }
}

void
qn_input_v (data_source_t * xx, caddr_t * inst, caddr_t * state)
{
  query_instance_t *qi = (query_instance_t *) inst;
  int n_sets = 0;
  dtp_t * mask = qi->qi_set_mask;
  if (state && (xx->src_pre_reset || xx->src_batch_size))
    {
      dc_reset_array (inst, xx, xx->src_pre_reset, n_sets);
    }
  if (state && xx->src_pre_code)
    {
      code_vec_run_v (xx->src_pre_code, inst, 0, -1, qi->qi_n_sets, NULL, NULL, 0);
    }
  xx->src_input (xx, inst, state);
  qi->qi_set_mask = mask;
}

void
ins_qnode (instruction_t * ins, caddr_t * qst, int from_vec)
{
  query_instance_t * qi = (query_instance_t *) qst;
  client_connection_t * cli = qi->qi_client;
  int at_start = cli->cli_anytime_started;
  int at_to = cli->cli_anytime_timeout;
  cli->cli_anytime_started = 0;
  QR_RESET_CTX_T (qi->qi_thread)
    {
      data_source_t * xx = ins->_.qnode.node;
      if (!IS_QN (ins->_.qnode.node, dpipe_node_input))
      qi->qi_n_affected = 0;
      if (xx->src_sets)
	{
	  if (!from_vec)
	    {
	      qi->qi_n_sets = 1;
	      qi->qi_set_mask = NULL;
	    }
	qn_input_v (ins->_.qnode.node, QST_INSTANCE (qst), qst);
	}
      else
      qn_input (ins->_.qnode.node, QST_INSTANCE (qst), qst);
      ins_qnode_resume (ins->_.qnode.node, qst);
    }
  QR_RESET_CODE
    {
      POP_QR_RESET;
      cli->cli_anytime_started = at_start;
      cli->cli_anytime_timeout = at_to;
      cl_node_init ((table_source_t *) ins->_.qnode.node, (caddr_t*) qi);
      sqlr_resignal (subq_handle_reset (qi, reset_code));
    }
  END_QR_RESET;
  AC_ENLIST_CK (qi);
  cli->cli_anytime_started = at_start;
  cli->cli_anytime_timeout = at_to;
}


#define 	  VEC_QST_CLR_NULL(inst, ssl, set) \
{ \
 if (SSL_VEC == ssl->ssl_type){						\
  data_col_t * dc = QST_BOX (data_col_t *, inst, ssl->ssl_index); \
	      if (dc->dc_nulls) \
		DC_CLR_NULL (dc, qi->qi_set);  \
 }}

void
ins_agg (instruction_t * ins, caddr_t * inst)
{
  QNCAST (query_instance_t, qi, inst);
  caddr_t prev;
  int set_no = ins->_.agg.set_no ? qst_vec_get_int64 (inst, ins->_.agg.set_no, qi->qi_set) : 0;
  int prev_set = qi->qi_set, rc;
  caddr_t arg;
  dtp_t arg_dtp;
  arg = qst_get (inst, ins->_.agg.arg);
  arg_dtp = DV_TYPE_OF (arg);
  if (DV_DB_NULL == arg_dtp)
    return;
  qi->qi_set = set_no;
  switch (ins->_.agg.op)
{
    case AMMSC_COUNT:
      if (SSL_VEC == ins->_.agg.result->ssl_type)
    {
	  data_col_t * dc = QST_BOX (data_col_t *, inst, ins->_.agg.result->ssl_index);
	  DC_CHECK_LEN (dc, set_no);
	  ((int64*)dc->dc_values)[set_no]++;
	}
      else
	qst_set_long (inst, ins->_.agg.result, 1 + unbox (QST_GET (inst, ins->_.agg.result)));
      break;
    case AMMSC_ONE:
      GPF_T1 ("single state exec of vectored subq ret not expected");
    case AMMSC_SUM:
      prev = qst_get (inst, ins->_.agg.result);
      if (DV_DB_NULL == DV_TYPE_OF (prev))
	{
	  qst_set (inst, ins->_.agg.result, box_copy_tree (arg));
	  VEC_QST_CLR_NULL (inst, ins->_.agg.result, set);
	}
      else
	box_add (prev, arg, inst, ins->_.agg.result);
      break;
    case AMMSC_MIN:
    case AMMSC_MAX:
      prev = qst_get (inst, ins->_.agg.result);
      rc = cmp_boxes (arg, prev, NULL, NULL);
      if (DVC_UNKNOWN == rc
	  || (rc == DVC_LESS && AMMSC_MIN == ins->_.agg.op)
	  || (rc == DVC_GREATER && AMMSC_MAX == ins->_.agg.op))
	    {
	  qst_set (inst, ins->_.agg.result, box_copy_tree (arg));
	  if (DV_DB_NULL != DV_TYPE_OF (arg))
	    {
	      VEC_QST_CLR_NULL (inst, ins->_.agg.result, set);
	    }
	}
      break;
    }
  qi->qi_set = prev_set;
}


void
ins_for_vect (caddr_t * inst, instruction_t * ins)
{
  QNCAST (query_instance_t, qi, inst);
  int inx, inx2;
  int len = -1;
  DO_BOX (state_slot_t *, arg, inx, ins->_.for_vect.in_values)
    {
      caddr_t * arr = (caddr_t*)qst_get (inst, arg);
      data_col_t * dc = QST_BOX (data_col_t *, inst, ins->_.for_vect.in_vars [inx]->ssl_index);
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (arr))
	sqlr_new_error ("42000", "VEC..",  "Argument of for_vectored is not an array");
      if (-1 == len)
	len = BOX_ELEMENTS (arr);
      else if (len != BOX_ELEMENTS (arr))
	sqlr_new_error ("42000", "VEC..", "Input arrays  in for_vectored not of equal length");
      dc_reset (dc);
      if (len > dc_max_batch_sz)
	sqlr_new_error ("42000", "FRVEC",  "array in for vectored over max vector length %d > %d", len, dc_max_batch_sz);
      if (ins->_.for_vect.modify && (DCT_BOXES & dc->dc_type))
	{
	  int len = BOX_ELEMENTS (arr);
	  DC_CHECK_LEN (dc, len - 1);
	  DO_BOX (caddr_t, in, inx2, arr)
	    {
	      ((caddr_t*)dc->dc_values)[inx2] = in;
	      arr[inx2] = NULL;
	      if (IS_BOX_POINTER (in) && DV_DB_NULL == box_tag (in))
		dc->dc_any_null = 1;
	    }
	  END_DO_BOX;
	  dc->dc_n_values = inx2;
	}
      else
	{
	  DO_BOX (caddr_t, in, inx2, arr)
	    {
	    dc_append_box (dc, in);
	    }
	  END_DO_BOX;
	}
    }
  END_DO_BOX;
  qi->qi_n_sets = len;
  qi->qi_set_mask = NULL;
  if (len)
    code_vec_run_v (ins->_.for_vect.code, inst, 0, -1, -1, NULL, 0, 0);
  DO_BOX (state_slot_t *, ssl, inx, ins->_.for_vect.out_vars)
    {
      caddr_t * arr = (caddr_t*)dk_alloc_box_zero (sizeof (caddr_t) * len, DV_ARRAY_OF_POINTER);
      qst_set (inst, ssl, (caddr_t)arr);
      for (inx2 = 0; inx2 < len; inx2++)
	{
	  qi->qi_set = inx2;
	  arr[inx2] = box_copy_tree (qst_get (inst, ins->_.for_vect.out_values[inx]));
	}
    }
  END_DO_BOX;
  qi->qi_set = 0;
  qi->qi_n_sets = 0;
}


void
vdb_enter_lt_nc (lock_trx_t * lt)
{
  IN_TXN;
  lt->lt_vdb_threads++;
  LEAVE_TXN;
}


void
vdb_enter_lt_1 (lock_trx_t * lt, caddr_t * err_ret, int enter_always)
{
  caddr_t err, detail;
  int lte = LTE_OK;
  IN_TXN;
  CHECK_DK_MEM_RESERVE (lt);
  if (LT_PENDING != lt->lt_status)
    {
      if (LT_FREEZE == lt->lt_status)
	{
	  lt_ack_freeze_inner (lt);
	  if (LT_PENDING != lt->lt_status)
	    {
	      lte = lt->lt_error != LTE_OK ? lt->lt_error : LTE_UNSPECIFIED;
	      detail = lt->lt_error_detail;
	      lt->lt_error_detail = NULL;
	      lt_rollback (lt, TRX_CONT);
	      if (enter_always)
		lt->lt_vdb_threads++;
	      LEAVE_TXN;
	      MAKE_TRX_ERROR (lte, err, detail);
	      if (err_ret)
		{
		  dk_free_tree (*err_ret);
		  *err_ret = err;
		  return;
		}
	      else
	      sqlr_resignal (err);
	    }
	}
      else
	{
	  lte = lt->lt_error != LTE_OK ? lt->lt_error : LTE_UNSPECIFIED;
	  detail = lt->lt_error_detail;
	  lt->lt_error_detail = NULL;
	  lt_rollback (lt, TRX_CONT);
	  if (enter_always)
	    lt->lt_vdb_threads++;
	  LEAVE_TXN;
	  MAKE_TRX_ERROR (lte, err, detail);
	  if (err_ret)
	    {
	      dk_free_tree (*err_ret);
	      *err_ret = err;
	      return;
	    }
	  else
	  sqlr_resignal (err);
	}
    }
  lt->lt_vdb_threads++;
  LEAVE_TXN;
}


void
vdb_enter_lt (lock_trx_t * lt)
{
  vdb_enter_lt_1 (lt, NULL, 0);
}


void
vdb_leave_lt (lock_trx_t * lt, caddr_t *err_ret)
{
  IN_TXN;
  if (lt->lt_vdb_threads <= 0)
    GPF_T1 ("lt_vdb_threads negative");
  lt->lt_vdb_threads--;
  CHECK_DK_MEM_RESERVE (lt);
  if (LT_FREEZE == lt->lt_status)
    {
      lt_ack_freeze_inner (lt);
    }
  if (LT_PENDING != lt->lt_status)
    {
      int lte = lt->lt_error;
      caddr_t err, detail = lt->lt_error_detail;
      lt->lt_error_detail = NULL;
      lt_ack_close (lt);
      lt->lt_status = LT_BLOWN_OFF;
      lt_rollback (lt, TRX_CONT);
      LEAVE_TXN;
      MAKE_TRX_ERROR (lte, err, detail);
      if (err_ret)
	{
	  if (*err_ret)
	    dk_free_tree (*err_ret);
	  *err_ret = err;
	}
      else
	sqlr_resignal (err);
    }
  else
    {
      LEAVE_TXN;
    }
}

void
vdb_enter (query_instance_t * qi)
{
  vdb_enter_lt (qi->qi_trx);
}

void
vdb_leave_1 (query_instance_t * qi, caddr_t *err_ret)
{
  vdb_leave_lt (qi->qi_trx, err_ret);
}

void
vdb_leave (query_instance_t * qi)
{
  vdb_leave_1 (qi, NULL);
}


void
lt_check_error (lock_trx_t * lt)
{
  if (lt->lt_status != LT_PENDING)
    {
      caddr_t err = NULL;
      int lt_err = lt->lt_error;
      IN_TXN;
      if (LT_FREEZE == lt->lt_status)
	{
	  if (lt->lt_vdb_threads)
	    {
	      /* in io sect, proceed if freeze, end of io sect will block to wait for cpt */
	      LEAVE_TXN;
	      return;
	    }
	  lt_ack_freeze_inner (lt);
	  lt->lt_status = LT_PENDING;
	  LEAVE_TXN;
	  return;
	}
      if (lt->lt_vdb_threads)
	{
	  MAKE_TRX_ERROR (lt_err, err, LT_ERROR_DETAIL (lt));
	  LEAVE_TXN;
	  sqlr_resignal (err);
	}
      if (lt->lt_client->cli_clt && lt->lt_client->cli_in_daq != CLI_IN_DAQ_AC)
	{
	  /* a cluster server thread must rb and signal and leave the final rb for the master, unless inside an autocommit, non enlisted ddaq */
	  lt->lt_close_ack_threads = 1;
	  lt_transact (lt, SQL_ROLLBACK);
	}
      else
	{
	  lt_rollback (lt, TRX_CONT);
	}
      LEAVE_TXN;
      MAKE_TRX_ERROR (lt_err, err, LT_ERROR_DETAIL (lt));
      sqlr_resignal (err);
    }
}


void
qi_check_trx_error (query_instance_t * qi, int flags)
{
  caddr_t err = NULL;
  client_connection_t * cli = qi->qi_client;
  AC_ENLIST_CK (qi);
  CHECK_SESSION_DEAD (qi->qi_trx, NULL, NULL);
  CHECK_DK_MEM_RESERVE (qi->qi_trx);
  if (qi->qi_trx->lt_status != LT_PENDING)
    {
      lock_trx_t * lt = qi->qi_trx;
      int lt_err = lt->lt_error, must_signal;
      IN_TXN;
      if (LT_FREEZE == lt->lt_status)
	{
	  lt_ack_freeze_inner (lt);
	  lt->lt_status = LT_PENDING;
	  LEAVE_TXN;
	  return;
	}
      if (lt->lt_client->cli_clt && lt->lt_client->cli_in_daq != CLI_IN_DAQ_AC)
	{
	  /* a cluster server thread must rb and signal and leave the final rb for the master, unless inside an autocommit, non enlisted ddaq */
	  lt->lt_close_ack_threads = 1;
	  lt_transact (lt, SQL_ROLLBACK);
	  must_signal = 1;
	}
      else
	{
	  lt_rollback (lt, TRX_CONT);
	  must_signal = CLI_IN_DAQ == lt->lt_client->cli_in_daq; /* if transactional daq call in coord node, must still signal regardless of handler */
	}
      LEAVE_TXN;
      if (!must_signal && (NO_TRX_SIGNAL & flags))
	return;
      MAKE_TRX_ERROR (lt_err, err, LT_ERROR_DETAIL (lt));
      sqlr_resignal (err);
    }

  if (cli->cli_start_time &&
      time_now_msec - cli->cli_start_time > BURST_STOP_TIMEOUT
      && cli->cli_session
      && cli_is_interactive (cli)
      && !cli->cli_ws)
    {
      dks_stop_burst_mode (cli->cli_session);
    }

  if (cli->cli_ws && cli_check_ws_terminate (cli))
    cli->cli_terminate_requested = 1;

  if (cli->cli_terminate_requested)
    {
      longjmp_splice (qi->qi_thread->thr_reset_ctx, RST_KILLED);
    }
}


void
qi_signal_if_trx_error (query_instance_t * qi)
{
  caddr_t err = NULL;
  CHECK_SESSION_DEAD (qi->qi_trx, NULL, NULL);
  CHECK_DK_MEM_RESERVE (qi->qi_trx);
  if (qi->qi_trx->lt_status != LT_PENDING)
    {
      lock_trx_t * lt = qi->qi_trx;
      int lt_err = lt->lt_error;
      MAKE_TRX_ERROR (lt_err, err, LT_ERROR_DETAIL (lt));
      sqlr_resignal (err);
    }
}


instruction_t *
code_vec_handle_error (code_vec_t code_vec, query_instance_t * qi,
    instruction_t *iins, int *pbreak_nesting_level, caddr_t err)
{
  caddr_t err_state = NULL;
  int nesting_level = 0, ret_nesting_level = nesting_level;
  long star_pos = -1;
  instruction_t *curr = NULL, *start_ins = NULL, *ins_ret = iins;
  opt_set_t starts_set, handlers_set;
  int break_nesting_level = *pbreak_nesting_level;
  int src_line_no = 0;
  char *src_file = NULL;

#ifdef OPT_SET_DEBUG
  opt_set_test ();
#endif
  opt_set_init (&starts_set);
  opt_set_init (&handlers_set);

  if (err == (caddr_t) SQL_NO_DATA_FOUND)
    err_state = (caddr_t) SQL_NO_DATA_FOUND;
  else
    err_state = ERR_STATE (err);

  DO_INSTR (ins, 0, code_vec)
    {
      if (ins > iins)
	break;
      if (ins->ins_type == INS_COMPOUND_START)
	{
	  opt_set_push (&starts_set, (caddr_t) ins);
	}
      else if (ins->ins_type == INS_COMPOUND_END)
	{
	  opt_set_pop (&starts_set);
	}
    }
  END_DO_INSTR;

  start_ins = (instruction_t *) opt_set_pop (&starts_set);
  opt_set_free (&starts_set);

  DO_INSTR (ins, 0, code_vec)
    {
      if (ins > iins)
	break;
      if (ins->ins_type == INS_COMPOUND_START)
	  nesting_level++;
      else if (ins->ins_type == INS_COMPOUND_END)
	  nesting_level--;
      else if (ins->ins_type == INS_HANDLER &&
	  (nesting_level < break_nesting_level ||
	   (nesting_level == break_nesting_level && ins > start_ins)))
	{
	  opt_set_push (&handlers_set, (caddr_t) ins);
	}
      else if (ins->ins_type == INS_HANDLER_END &&
	  (nesting_level < break_nesting_level ||
	   (nesting_level == break_nesting_level && ins > start_ins)))
	{
	  instruction_t *ins_start = (instruction_t *) opt_set_pop (&handlers_set);
	  int last_nesting_level = nesting_level, in_scope = 1;

	  DO_INSTR (ins3, INSTR_OFS(ins, code_vec), code_vec)
	    {
	      if (ins3 > iins)
		break;

	      if (ins3->ins_type == INS_COMPOUND_START)
		nesting_level++;
	      else if (ins3->ins_type == INS_COMPOUND_END)
		nesting_level--;
	      if (nesting_level < last_nesting_level)
		{
		  in_scope = 0;
		  ins = ins3;
		  break;
		}
	    }
	  END_DO_INSTR;


	  if (in_scope)
	    nesting_level = last_nesting_level;
	  if (in_scope && handler_has_state (ins_start, err_state, &star_pos))
	    {
	      curr = ins_start;
	      ins_ret = ins_start;
	      ret_nesting_level = nesting_level;
	    }
	}
    }
  END_DO_INSTR;
  if (!opt_set_empty (&handlers_set))
    { /* there is no exception handling in the handler's context */
      opt_set_free (&handlers_set);
      curr = NULL;
    }
  if (curr)
    {
      qst_set ((caddr_t *) qi, curr->_.handler.throw_location, box_num (INSTR_OFS (iins, code_vec)));
      qst_set ((caddr_t *) qi, curr->_.handler.throw_nesting_level, box_num (break_nesting_level));
      if (curr->_.handler.state)
	qst_set ((caddr_t *) qi, curr->_.handler.state, box_copy (err_state));
      if (curr->_.handler.message)
	qst_set ((caddr_t *) qi, curr->_.handler.message,
	    DV_TYPE_OF (err) == DV_ARRAY_OF_POINTER ?
	     box_copy (ERR_MESSAGE (err)) :
	     dk_alloc_box (0, DV_DB_NULL));
#ifndef ROLLBACK_XQ
      dk_free_tree (err);	/* IvAn/010801/LeakOnError */
#endif
      *pbreak_nesting_level = ret_nesting_level;
      return ins_ret;
    }

  if (start_ins && start_ins->ins_type == INS_COMPOUND_START)
    {
      src_line_no = start_ins->_.compound_start.l_line_no;
      src_file = start_ins->_.compound_start.file_name;
    }
  err_append_callstack_procname (err, qi->qi_query->qr_proc_name, src_file, src_line_no);
  if (1 < callstack_on_exception)
    {
      DO_SET (state_slot_t *, parm, &qi->qi_query->qr_parms)
	{
	  err_append_callstack_param (err, parm->ssl_name, QST_GET ((caddr_t*)qi, parm));
	}
      END_DO_SET ();
    }
  sqlr_resignal (err);
  return iins; /* dummy */
}

#define HANDLE_ARTM_IN(f) \
  if (ins->_.artm.func) \
    dc_artm_1_funcs[ins->_.artm.func] (ins, qst); \
  else \
    f (QST_GET (qst, ins->_.artm.left), \
	  ins->_.artm.right \
	  ? QST_GET (qst, ins->_.artm.right) : (caddr_t) NULL, \
	  qst, ins->_.artm.result)

#define HANDLE_ARTM(func) \
      HANDLE_ARTM_IN(func); \
      ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.artm))); \
      break

#define HANDLE_ARTM_FPTR(func) \
      HANDLE_ARTM_IN(func); \
      ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.artm_fptr))); \
      break



buffer_desc_t *
buf_identity (buffer_desc_t * buf)
{
  return buf;
}
#ifdef MTX_DEBUG_0

void
qi_check_buf_writers (void)
{
  buffer_desc_t volatile *buf;
  int inx1, inx = 0;
  du_thread_t volatile * self = THREAD_CURRENT_THREAD;
  DO_BOX (buffer_pool_t *, bp, inx, wi_inst.wi_bps)
    {
      for (inx1 = 0; inx1 < bp->bp_n_bufs; inx1++)
	{
	  buf = &bp->bp_bufs[inx1];
	  if (self == buf->bd_writer && buf->bd_space &&
	      buf->bd_space->isp_tree &&
	      buf->bd_space->isp_tree->it_key &&
	      buf->bd_space->isp_tree->it_key->key_id != KI_TEMP)
	    {
	      fprintf (stderr, "bd_writer=%p CURRENT_THREAD=%p\n", buf_identity (buf->bd_writer), self);
	      GPF_T1 ("Thread is not supposed to own a buffer at start of code_vec_run");
	    }
	}
    }
  END_DO_BOX;
}
#endif



caddr_t
code_vec_run_1 (code_vec_t code_vec, caddr_t * qst, int offset)
{
  volatile int nesting_level = 0;
  instruction_t * volatile ins;
  instruction_t * volatile prev_ins = NULL;
#ifdef PLDBG
  instruction_t * volatile prev_breakpoint_ins = NULL;
#endif
  query_instance_t * volatile qi = (query_instance_t *)qst;
  int no_vec = 0;
  if (CV_THIS_SET_ONLY == offset)
    {
      offset = 0;
      no_vec = 1;
    }
  ins = INSTR_ADD_OFS (code_vec, offset);
  qi_check_trx_error (qi, 0);
  qi_check_buf_writers ();
again:
  QR_RESET_CTX_T (qi->qi_thread)
    {
      if (qi->qi_query->qr_proc_vectored && !no_vec)
	{
	  qi->qi_set_mask = NULL;
	  code_vec_run_v (code_vec, qst, offset, -1, -1, NULL, 0, 0);
	  POP_QR_RESET;
	  return (caddr_t) 1;
	}
      for (;;)
	{
	  qi_check_buf_writers ();
	  prev_ins = ins;
	  if (DK_MEM_RESERVE)
	    {
	      SET_DK_MEM_RESERVE_STATE (qi->qi_trx);
	      qi_check_trx_error (qi, 0);
	    }
	  switch (ins->ins_type)
	    {
	    case IN_ARTM_PLUS:	HANDLE_ARTM(box_add);
	    case IN_ARTM_MINUS:	HANDLE_ARTM(box_sub);
	    case IN_ARTM_TIMES:	HANDLE_ARTM(box_mpy);
	    case IN_ARTM_DIV:		HANDLE_ARTM(box_div);
	    case IN_ARTM_IDENTITY:	HANDLE_ARTM(box_identity);
	    case IN_ARTM_FPTR:	HANDLE_ARTM_FPTR(ins->_.artm_fptr.func);
	    case IN_AGG:
	      ins_agg (ins, qst);
	      ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.agg)));
	      break;
	    case IN_PRED:
	      {
		int flag;
		qi_check_trx_error (qi, 0);
		flag = ins->_.pred.func (qst, ins->_.pred.cmp);
		if (flag == DVC_QUEUED)
		  {
		    POP_QR_RESET;
		    return (caddr_t)DVC_QUEUED;
		  }
		if (flag == DVC_UNKNOWN)
		  ins = INSTR_ADD_OFS (code_vec, ins->_.pred.unkn);
		else if (flag)
		  ins = INSTR_ADD_OFS (code_vec, ins->_.pred.succ);
		else
		  ins = INSTR_ADD_OFS (code_vec, ins->_.pred.fail);
		break;
	      }
	    case IN_COMPARE:
		    {
		      int flag = cmp_boxes_safe (QST_GET (qst, ins->_.cmp.left), QST_GET (qst, ins->_.cmp.right),
			  ins->_.cmp.left->ssl_sqt.sqt_collation, ins->_.cmp.right->ssl_sqt.sqt_collation);
		      if (flag & (int) ins->_.cmp.op)
			ins = INSTR_ADD_OFS (code_vec, ins->_.cmp.succ);
		      else if (flag == DVC_UNKNOWN)
			ins = INSTR_ADD_OFS (code_vec, ins->_.cmp.unkn);
		      else
			ins = INSTR_ADD_OFS (code_vec, ins->_.cmp.fail);
#ifdef CMP_DEBUG
		      do {
			  instruction_t * volatile unsafe_ins;
			  int unsafe_flag = cmp_boxes (QST_GET (qst, prev_ins->_.cmp.left), QST_GET (qst, prev_ins->_.cmp.right),
			    prev_ins->_.cmp.left->ssl_sqt.sqt_collation, prev_ins->_.cmp.right->ssl_sqt.sqt_collation);
			  if (unsafe_flag == DVC_UNKNOWN)
			    unsafe_ins = INSTR_ADD_OFS (code_vec, prev_ins->_.cmp.unkn);
			  else if (unsafe_flag & (int) prev_ins->_.cmp.op)
			    unsafe_ins = INSTR_ADD_OFS (code_vec, prev_ins->_.cmp.succ);
			  else
			    unsafe_ins = INSTR_ADD_OFS (code_vec, prev_ins->_.cmp.fail);
			  if (ins != unsafe_ins)
			    {
			      fprintf (stderr, "\n%s:%d\n*** IN_COMPARE mismatch: unsafe is %d hence %s, safe is %d hence %s, cmp_op is %d,\n",
				__FILE__, __LINE__,
				unsafe_flag, ((unsafe_ins == INSTR_ADD_OFS (code_vec, prev_ins->_.cmp.succ)) ? "succ" : "not succ"),
				flag, ((ins == INSTR_ADD_OFS (code_vec, prev_ins->_.cmp.succ)) ? "succ" : "not succ"),
				(int) prev_ins->_.cmp.op );
			      dbg_print_box (QST_GET (qst, prev_ins->_.cmp.left), stderr);
			      fprintf (stderr, ", ");
			      dbg_print_box (QST_GET (qst, prev_ins->_.cmp.right), stderr);
			      fprintf (stderr, "\n");
			    }
			} while (0);
#endif
		      break;
		    }
	      case INS_CALL:
	      case INS_CALL_IND:
		  ins_call ((instruction_t *) ins, qst, code_vec);
		  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.call)));
		  break;
	      case INS_CALL_BIF:
		  ins_call_bif ((instruction_t *) ins, qst, code_vec);
		  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.bif)));
		  break;
  	    case INS_SUBQ:
		if (DVC_QUEUED == ins_subq ((instruction_t *) ins, qst))
		  {
		    POP_QR_RESET;
		    return (caddr_t)DVC_QUEUED;
		  }
		ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.subq)));
		break;
	    case INS_QNODE:
	      ins_qnode ((instruction_t *) ins, qst, 0);
		  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.qnode)));
		  break;
	      case INS_OPEN:
		  ins_open ((instruction_t *) ins, qst);
		  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.open)));
		  break;
	      case INS_FETCH:
		  qi_check_buf_writers ();
		  ins_fetch ((instruction_t *) ins, qst);
		  qi_check_buf_writers ();
		  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.fetch)));
		  break;
	      case INS_CLOSE:
		  ins_close ((instruction_t *) ins, qst);
		  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.close)));
		  break;
	      case INS_COMPOUND_START:
		  nesting_level++;
		  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.compound_start)));
		  break;
	      case INS_COMPOUND_END:
		  nesting_level--;
		  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.compound_start)));
		  break;
	      case INS_HANDLER:
		  ins = INSTR_ADD_OFS (code_vec, ins->_.handler.label);
		  break;
	      case INS_HANDLER_END:
		  nesting_level = (int) unbox (qst_get (qst, ins->_.handler_end.throw_nesting_level));
		  ins = ins_handler_end (code_vec, qst, ins);
		  ins = INSTR_NEXT (ins);
		  break;
	      case INS_AREF:
	      case INS_SET_AREF:
		  sqlr_new_error ("39000", "SR191", "Unsupported instruction AREF");
	      case IN_VRET:
		  POP_QR_RESET;
		    {
		      caddr_t value;
#ifndef ROLLBACK_XQ
		      dk_free_tree (qi->qi_thread->thr_func_value); /* IvAn/010801/LeakOnReturn: this line added */
#endif
		      if (ins->_.vret.value)
			{
			  value = qst_get (qst, ins->_.vret.value);
			  if (ins->_.vret.value->ssl_is_callret)
			    qst[ins->_.vret.value->ssl_index] = NULL;
			  else
			    value = box_copy_tree (value);
			}
		      else
			value = NULL;
		      qi->qi_thread->thr_func_value = value;
		      qi_check_buf_writers ();
		      return value;
		    }

	      case IN_BRET:
		  POP_QR_RESET;
		  qi_check_buf_writers ();
		  return ((caddr_t) (ptrlong) ins->_.bret.bool_value);

	      case IN_JUMP:
		  nesting_level = ins->_.label.nesting_level;
		  ins = INSTR_ADD_OFS (code_vec, ins->_.label.label);
		  qi_check_trx_error (qi, 0); /* handlers in jmp target ctx are in effect */
		  break;
#ifdef PLDBG
              case INS_BREAKPOINT:
		  prev_breakpoint_ins = (instruction_t *) ins;
		  ins_break ((instruction_t *) ins, qst);
		  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.breakpoint)));
		  break;
#endif
	    case INS_FOR_VECT:
	      ins_for_vect (qst, ins);
	      ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.for_vect)));
	      break;
	    }
	}
    }
  QR_RESET_CODE
    {
      int new_nesting_level = nesting_level;
      POP_QR_RESET;
      if (reset_code == RST_ERROR || reset_code == RST_DEADLOCK)
	{
	  caddr_t err = RST_ERROR == reset_code ? thr_get_error_code (qi->qi_thread)
	    : srv_make_new_error ("40001", "SR...", "Transaction deadlock, from SQL built-in function.");
	  CHECK_DK_MEM_RESERVE (qi->qi_trx);
	  CHECK_SESSION_DEAD(qi->qi_trx, NULL, NULL);
	  if (qi->qi_trx->lt_status != LT_PENDING && (
		qi->qi_trx->lt_error == LTE_TIMEOUT ||
		qi->qi_trx->lt_error == LTE_OUT_OF_MEM))
	    {
	      sqlr_resignal (err);
	    }
	  qi_check_trx_error (qi, NO_TRX_SIGNAL);
	  if (ins->ins_type == INS_CALL_BIF)
	    {
	      err_append_callstack_procname (err, ins->_.bif.proc, NULL, -1);
	      if (1 < callstack_on_exception)
	        {
		  int argidx;
	          DO_BOX (state_slot_t *, parm, argidx, ins->_.call.params)
		    {
		      char name[20]; snprintf (name, sizeof (name), "__%02d", argidx + 1);
		      err_append_callstack_param (err, name, QST_GET ((caddr_t*)qi, parm));
		    }
	          END_DO_BOX;
	        }
	    }

	  ins = code_vec_handle_error (code_vec, qi, ins, &new_nesting_level, err);
	  ins = INSTR_NEXT (ins);
	  nesting_level = new_nesting_level;
	  goto again;
	}
      else
	{
	  longjmp_splice (qi->qi_thread->thr_reset_ctx, reset_code);
	}
    }
  END_QR_RESET;
  qi_check_buf_writers ();
  return NULL;
}



caddr_t
code_vec_run_no_catch (code_vec_t code_vec, it_cursor_t *itc)
{
  instruction_t * ins = code_vec;
  caddr_t *qst = itc->itc_out_state;
  query_instance_t *qi = (query_instance_t *)qst;
  if (CLI_RESULT == qi->qi_client->cli_terminate_requested)
    cli_anytime_timeout (qi->qi_client);
  for (;;)
    {
      switch (ins->ins_type)
	{
	case IN_ARTM_PLUS:	HANDLE_ARTM(box_add);
	case IN_ARTM_MINUS:	HANDLE_ARTM(box_sub);
	case IN_ARTM_TIMES:	HANDLE_ARTM(box_mpy);
	case IN_ARTM_DIV:	HANDLE_ARTM(box_div);
	case IN_ARTM_IDENTITY:	HANDLE_ARTM(box_identity);
	case IN_ARTM_FPTR:	HANDLE_ARTM_FPTR(ins->_.artm_fptr.func);
	case IN_AGG:
	  ins_agg (ins, qst);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.agg)));
	  break;
	case IN_PRED:
	  {
	    int flag = ins->_.pred.func (qst, ins->_.pred.cmp);
	    if (flag == DVC_UNKNOWN)
	      ins = INSTR_ADD_OFS (code_vec, ins->_.pred.unkn);
	    else if (flag)
	      ins = INSTR_ADD_OFS (code_vec, ins->_.pred.succ);
	    else
	      ins = INSTR_ADD_OFS (code_vec, ins->_.pred.fail);
	    break;
	  }
	case IN_COMPARE:
	  {
	    int flag = ins->_.cmp.func ? dc_cmp_1_funcs[ins->_.cmp.func] (ins, qst)
	      : cmp_boxes (QST_GET (qst, ins->_.cmp.left), QST_GET (qst, ins->_.cmp.right),
		ins->_.cmp.left->ssl_sqt.sqt_collation, ins->_.cmp.right->ssl_sqt.sqt_collation);
	    if (flag == DVC_UNKNOWN)
	      ins = INSTR_ADD_OFS (code_vec, ins->_.pred.unkn);
	    else if (flag & (int) ins->_.cmp.op)
	      ins = INSTR_ADD_OFS (code_vec, ins->_.pred.succ);
	    else
	      ins = INSTR_ADD_OFS (code_vec, ins->_.pred.fail);
	    break;
	  }
	case INS_CALL:
	case INS_CALL_IND:
	  ins_call (ins, qst, code_vec);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.call)));
	  break;
	case INS_CALL_BIF:
	  ins_call_bif (ins, qst, code_vec);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.bif)));
	  break;
	case INS_SUBQ:
	  ins_subq (ins, qst);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.subq)));
	  break;
	case INS_QNODE:
	  ins_qnode (ins, qst, 0);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.qnode)));
	  break;
	case INS_OPEN:
	  ins_open (ins, qst);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.open)));
	  break;
	case INS_FETCH:
	  ins_fetch (ins, qst);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.fetch)));
	  break;
	case INS_CLOSE:
	  ins_close (ins, qst);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.close)));
	  break;
	case INS_COMPOUND_START:
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.compound_start)));
	  break;
	case INS_COMPOUND_END:
#if 0
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.compound_start)));
#endif
	  break;
	case INS_HANDLER:
	  ins = INSTR_ADD_OFS (ins, ins->_.handler.label);
	  break;
	case INS_HANDLER_END:
	  ins = ins_handler_end (code_vec, qst, ins);
	  break;
	case INS_AREF:
	case INS_SET_AREF:
	  sqlr_new_error ("39000", "SR191", "Unsupported instruction AREF");
	case IN_VRET:
	    {
	      caddr_t value = ins->_.vret.value ?
		  box_copy_tree (qst_get (qst, ins->_.vret.value)) :
		  NULL;
	      qi->qi_thread->thr_func_value = value;
	      return value;
	    }
	case IN_BRET:
	  return ((caddr_t) (ptrlong) ins->_.bret.bool_value);

	case IN_JUMP:
	  ins = INSTR_ADD_OFS (code_vec, ins->_.label.label);
	  break;
	}
    }

  /*NOTREACHED*/
  return NULL;
}


int
distinct_comp_func (caddr_t * qst, void * ha)
{
  itc_ha_feed_ret_t ihfr;
  if (DVC_MATCH == itc_ha_feed (&ihfr, (hash_area_t *) ha, qst, 0, NULL))
    return 0;
  else
    return 1;
}


int
bop_comp_func (caddr_t * qst, void * _bop)
{
  bop_comparison_t * bop = (bop_comparison_t *) _bop;
  int op = bop->cmp_op;
  int res;

  switch (op)
    {
    case BOP_NULL:
      {
	caddr_t v = QST_GET (qst, bop->cmp_left);
	return (IS_BOX_POINTER (v) && DV_DB_NULL == box_tag (v));
      }
    case BOP_LIKE:
      {
        int st = LIKE_ARG_CHAR, pt = LIKE_ARG_CHAR;
	caddr_t l = QST_GET (qst, bop->cmp_left);
	caddr_t r = QST_GET (qst, bop->cmp_right);
	collation_t *coll1, *coll2;
	dtp_t ltype = DV_TYPE_OF (l);
	dtp_t rtype = DV_TYPE_OF (r);
	if ((!DV_STRINGP (r)) && (!DV_WIDESTRINGP (r)))
	  {sqlr_new_error ("HY105", "SR192", "Like pattern not a string");}
	if (DV_RDF == ltype && ((rdf_box_t*)l)->rb_is_complete)
	  {
	    l = ((rdf_box_t*)l)->rb_box;
	    ltype = DV_TYPE_OF (l);
	  }
        if (DV_WIDE == rtype || DV_LONG_WIDE == rtype)
	  pt = LIKE_ARG_WCHAR;
        if (DV_WIDE == ltype || DV_LONG_WIDE == ltype || DV_BLOB_WIDE_HANDLE == ltype)
	  st = LIKE_ARG_WCHAR;
	coll1 = bop->cmp_left->ssl_sqt.sqt_collation;
	coll2 = bop->cmp_right->ssl_sqt.sqt_collation;
	if (coll1)
	  {
	    if (coll1 && coll2 != coll1)
	      coll1 = NULL;
	  }
	else
	  coll1 = coll2;
	if (!coll1)
	  coll1 = default_collation;

	if (DV_DB_NULL == ltype)
	  return 0;
	if (DV_BLOB_HANDLE == ltype || DV_BLOB_WIDE_HANDLE == ltype) {
	  query_instance_t * qi = (query_instance_t *) qst;
	  blob_handle_t * bh = (blob_handle_t*) l;
	  caddr_t bbox;
	  int rc;

	  if (bh -> bh_length > 1000000)
	    sqlr_new_error ("HY105", "SR193", "Blob of %lu bytes in like", (unsigned long)bh->bh_length);
	  bbox = blob_to_string (qi -> qi_trx, l);
	  rc = cmp_like (bbox, r, coll1, bop->cmp_like_escape, st, pt);
	  dk_free_box (bbox);
	  return (DVC_MATCH == rc);
	}
	if ((!DV_STRINGP (l)) && (!DV_WIDESTRINGP (l)))
	  sqlr_new_error ("HY105", "SR194", "LIKE must be between strings.");
	return (DVC_MATCH == cmp_like (l, r, coll1, bop->cmp_like_escape, st, pt));
      }
    default:
      res = cmp_boxes (QST_GET (qst, bop->cmp_left),
		       QST_GET (qst, bop->cmp_right),
		       bop->cmp_left->ssl_sqt.sqt_collation,
		       bop->cmp_right->ssl_sqt.sqt_collation);

      switch (res)
	{
	case DVC_UNKNOWN:
	  if (op == BOP_NEQ)
	    return 1;
	  return DVC_UNKNOWN;
	case DVC_MATCH:
	  if (op == BOP_EQ || op == BOP_LTE || op == BOP_GTE)
	    return 1;
	  else
	    return 0;
	case DVC_LESS:
	  if (op == BOP_LTE || op == BOP_LT || op == BOP_NEQ)
	    return 1;
	  else
	    return 0;
	case DVC_GREATER:
	  if (op == BOP_GTE || op == BOP_GT || op == BOP_NEQ)
	    return 1;
	  else
	    return 0;
	}
    }
  return 0;
}






int
exists_pred_func (caddr_t * qst, subq_pred_t * subp)
{
  QNCAST (query_instance_t, qi, qst);
  int n_sets_save = qi->qi_n_sets;
  query_t *subq = subp->subp_query;
  caddr_t err;
  subq_init (subq, qst);


  err = subq_next (subq, qst, CR_INITIAL);
  qi->qi_n_sets = n_sets_save;
  if (err == (caddr_t) SQL_NO_DATA_FOUND)
    return 0;
  if (err != SQL_SUCCESS)
    sqlr_resignal (err);
  return 1;
}






int
subq_comp_func (caddr_t * qst, void * _subp)
{
  subq_pred_t *subp = (subq_pred_t *) _subp;
  switch (subp->subp_type)
    {
    case EXISTS_PRED:
      return (exists_pred_func (qst, subp));
    case ONE_PRED:
    case SOME_PRED:
    case ALL_PRED:
      {
	GPF_T1 ("all sub preds are supposed to be existences");
#if 0
	caddr_t left = qst_get (qst, subp->subp_left);
	caddr_t err;
	int pred_succ = 0, successp;
	int op = subp->subp_comparison;
	int cr_state = CR_INITIAL;

	subq_init (subp->subp_query, qst);
	for (;;)
	  {
	    err = subq_next (subp->subp_query, qst, cr_state);
	    if (err == (caddr_t) SQL_NO_DATA_FOUND)
	      break;
	    if (err != SQL_SUCCESS)
	      sqlr_resignal (err);
	    cr_state = CR_OPEN;
	    data = qst_get (qst, subp->subp_query->qr_select_node->sel_out_slots[0]);
	    res = cmp_boxes (left, data,
		subp->subp_left->ssl_sqt.sqt_collation,
		subp->subp_query->qr_select_node->sel_out_slots[0]->ssl_sqt.sqt_collation);
	    successp = 0;

	    switch (res)
	      {
	      case DVC_MATCH:
		if (op == BOP_EQ || op == BOP_LTE || op == BOP_GTE)
		  successp = 1;
		break;
	      case DVC_LESS:
		if (op == BOP_LTE || op == BOP_LT || op == BOP_NEQ)
		  successp = 1;
		break;
	      case DVC_GREATER:
		if (op == BOP_GTE || op == BOP_GT || op == BOP_NEQ)
		  successp = 1;
		break;
	      }
	    if ((successp && subp->subp_type == SOME_PRED)
		|| (successp && subp -> subp_type == ONE_PRED))
	      {
		pred_succ = 1;	/*success */
		break;
	      }
	    if ((!successp && subp->subp_type == ALL_PRED)
		|| (! successp && subp -> subp_type == ONE_PRED))
	      {
		pred_succ = -1;	/* fail */
		break;
	      }
	  }

	if (pred_succ == 0)
	  return (subp->subp_type == ALL_PRED ? 1 : 0);
	return (pred_succ == 1 ? 1 : 0);

#endif
      }
    default:
      GPF_T;			/*Bad subq predicate. */
    }

  /*NOTREACHED*/
  return 0;
}

#define CLRNULL(dc, set, dtp)			\
  if (dc->dc_any_null) { \
      if (BIT_IS_SET (dc->dc_nulls, set)) {		\
      BIT_CLR (dc->dc_nulls, set); \
      ((dtp*)dc->dc_values)[set] = 0; \
      }}
void
ins_vec_agg_int_sum (instruction_t * ins, caddr_t * inst)
{
  QNCAST (QI, qi, inst);
  int64 * resv, *argv;
  int sets[ARTM_VEC_LEN];
  int arg_sets[ARTM_VEC_LEN];
  data_col_t * res_dc = QST_BOX (data_col_t *, inst, ins->_.agg.result->ssl_index);
  data_col_t * sets_dc = QST_BOX (data_col_t *, inst, ins->_.agg.set_no->ssl_index);
  int64 * sets_v = (int64*)sets_dc->dc_values;
  int inx;
  int is_const = SSL_CONSTANT == ins->_.agg.arg->ssl_type;
  int64 cnst = is_const ? unbox (ins->_.agg.arg->ssl_constant) : 0;
  int n_sets = qi->qi_n_sets;
  for (inx = 0; inx < n_sets; inx += ARTM_VEC_LEN)
    {
      int last = MIN (n_sets, inx + ARTM_VEC_LEN);
      int row, max_res_set =1;
      sslr_n_consec_ref (inst, (state_slot_ref_t*)ins->_.agg.set_no, sets, inx, last - inx);

      for (row = 0; row < last - inx; row++)
	if (sets_v[sets[row]] >= max_res_set)
	  max_res_set = sets_v[sets[row]] + 1;
      if (max_res_set > res_dc->dc_n_values)
	{
	  DC_CHECK_LEN (res_dc, max_res_set - 1);
	  memzero (((int64*)res_dc->dc_values) + res_dc->dc_n_values, sizeof (int64) * (max_res_set - res_dc->dc_n_values));
	  res_dc->dc_n_values = max_res_set;
	}
      resv = (int64*)res_dc->dc_values;
      if (!is_const)
	{
	  argv = (int64*)QST_BOX (data_col_t *, inst, ins->_.agg.arg->ssl_index)->dc_values;
	  if (SSL_VEC == ins->_.agg.arg->ssl_type)
	    {
	      for (row = inx; row < last; row++)
		{
		  int set = sets_v[sets[row - inx]];
		  CLRNULL (res_dc, set, int64);
		  resv[set] += argv[row];
		}
	    }
	  else
	    {
	      sslr_n_consec_ref (inst, (state_slot_ref_t*)ins->_.agg.arg, arg_sets, inx, last - inx);
	      for (row = 0; row < last - inx; row++)
		{
		  int set = sets_v[sets[row]];
		  CLRNULL (res_dc, set, int64);
		  resv[set] += argv[arg_sets[row]];
		}
	    }
	}
      else
	{
	  for (row = 0; row < last - inx; row++)
	    resv[sets_v[sets[row]]] += cnst;
	}
    }
}

void
ins_vec_agg_ord_distinct (instruction_t * ins, caddr_t * inst)
{
  /* count distinct where all equal values of argg are consecutive.  Approximate of anies and changes in dc type */
  data_col_t * arg_dc = QST_BOX (data_col_t *, inst, ins->_.agg.arg->ssl_index);
  data_col_t * res_dc = QST_BOX (data_col_t *, inst, ins->_.agg.result->ssl_index);
  int n_sets = arg_dc->dc_n_values;
  hash_area_t * ha = ins->_.agg.distinct;
  caddr_t h_box = QST_GET_V (inst, ha->ha_tree);
  uint64 prev_hno;
  int ctr = 0;
  int inx, any = NULL != h_box;
  if (h_box)
    prev_hno = *(int64*)h_box;
  else
    prev_hno = -1;
  if (DV_ANY == arg_dc->dc_dtp)
    {
      for (inx = 0; inx < n_sets; inx++)
	{
	  int64 hno = 1;
	  int len;
	  db_buf_t dv = ((db_buf_t *)arg_dc->dc_values)[inx];
	  DB_BUF_TLEN (len,dv[0], dv);
	  MHASH_VAR (hno, dv, len);
	  ctr += hno != prev_hno;
	  prev_hno = hno;
	}
    }
  else if (DV_DATETIME == arg_dc->dc_dtp)
    {
      for (inx = 0; inx < n_sets; inx++)
	{
	  uint64 hno = *(int64*) (arg_dc->dc_values + DT_LENGTH * inx); 
	    ctr += prev_hno != hno;
	    prev_hno = hno;
	}
    }
  else if (DV_SINGLE_FLOAT == arg_dc->dc_dtp)
    {
      for (inx = 0; inx < n_sets; inx++)
	{
	  uint64 hno = ((int32*) arg_dc->dc_values)[inx];
	    ctr += prev_hno != hno;
	    prev_hno = hno;
	}
    }
  else
    {
      for (inx = 0; inx < n_sets; inx++)
	{
	  uint64 hno = ((int64*) arg_dc->dc_values)[inx];
	  ctr += prev_hno != hno;
	  prev_hno = hno;
	}

    }
  ((int64*)res_dc->dc_values)[0] += ctr;
  res_dc->dc_n_values = 1;
  if (!h_box)
    QST_GET_V (inst, ha->ha_tree) = h_box = box_num (0xfffffff);
  *(int64*)h_box = prev_hno;
}


void
ins_vec_agg (instruction_t * ins, caddr_t * inst)
{
  QNCAST (query_instance_t, qi, inst);
  caddr_t prev;
  int n_sets = qi->qi_n_sets, set, first_set = 0, rc;
  data_col_t * res = QST_BOX (data_col_t *, inst, ins->_.agg.result->ssl_index);
  db_buf_t set_mask = qi->qi_set_mask;
  if (!set_mask)
    {
      if ((AMMSC_COUNT == ins->_.agg.op || AMMSC_COUNTSUM == ins->_.agg.op   || AMMSC_SUM == ins->_.agg.op)
	  && !ins->_.agg.distinct
	  && DV_LONG_INT == res->dc_dtp
	  && ((SSL_IS_VEC_OR_REF (ins->_.agg.arg)  && DV_LONG_INT == QST_BOX (data_col_t*, inst, ins->_.agg.arg->ssl_index)->dc_sqt.sqt_dtp && !QST_BOX (data_col_t*, inst, ins->_.agg.arg->ssl_index)->dc_any_null)
	      || (SSL_CONSTANT == ins->_.agg.arg->ssl_type && DV_LONG_INT == ins->_.agg.arg->ssl_sqt.sqt_dtp)))
	{
	  ins_vec_agg_int_sum (ins, inst);
	  return;
	}
    }
  if (ins->_.agg.distinct && HA_ORD_DISTINCT == ins->_.agg.distinct->ha_op)
    {
      ins_vec_agg_ord_distinct (ins, inst);
	return;
    }
  SET_LOOP
    {
      int set_no = qst_vec_get_int64 (inst, ins->_.agg.set_no, set), op;
      caddr_t arg = qst_get (inst, ins->_.agg.arg);
      dtp_t arg_dtp = DV_TYPE_OF (arg);
      if (DV_DB_NULL == arg_dtp)
	continue;
      if (ins->_.agg.distinct)
	{
	  itc_ha_feed_ret_t ihfr;
	  if (DVC_MATCH == itc_ha_feed (&ihfr, ins->_.agg.distinct, inst, 0, NULL))
	    continue;
	}
      op = ins->_.agg.op;
      qi->qi_set = set_no;
      if (res->dc_n_values <= set_no)
	{
	  int inx;
	  DC_CHECK_LEN (res, set_no);
	  for (inx = res->dc_n_values; inx <= set_no; inx++)
	    {
	      if (AMMSC_MIN == op || AMMSC_MAX == op || AMMSC_SUM == op)
		dc_set_null (res, inx);
	      else
		{
		  dc_append_box (res, (caddr_t)0);
		}
	    }
	}
      switch (op)
	{
	case AMMSC_COUNT:
	  ((int64*)res->dc_values)[set_no]++;
	  break;
	case AMMSC_ONE:
	  if (DC_ANY_IS_NULL (res, set_no))
	    qst_vec_set_copy (inst, ins->_.agg.result, arg);
	  break;
	case AMMSC_SUM:
	  prev = qst_get (inst, ins->_.agg.result);
	  if (DV_DB_NULL == DV_TYPE_OF (prev))
	    {
	      qst_set (inst, ins->_.agg.result, box_copy_tree (arg));
	      VEC_QST_CLR_NULL (inst, ins->_.agg.result, qi->qi_set);
	    }
	  else
	    box_add (prev, arg, inst, ins->_.agg.result);
	  break;
	case AMMSC_MIN:
	case AMMSC_MAX:
	  prev = qst_get (inst, ins->_.agg.result);
	  rc = cmp_boxes (arg, prev, ins->_.agg.arg->ssl_sqt.sqt_collation, ins->_.agg.arg->ssl_sqt.sqt_collation);
	  if (DVC_UNKNOWN == rc
	      || (rc == DVC_LESS && AMMSC_MIN == ins->_.agg.op)
	      || (rc == DVC_GREATER && AMMSC_MAX == ins->_.agg.op))
	    {
	      qst_set (inst, ins->_.agg.result, box_copy_tree (arg));
	      if (DV_DB_NULL != DV_TYPE_OF (arg))
		{
		  VEC_QST_CLR_NULL (inst, ins->_.agg.result, qi->qi_set);
		}
	    }
	  break;
	}
    }
  END_SET_LOOP;
}




#define SET_MASK_NEG(mask, in_mask, n_sets)		\
{ \
  int inx, n = ALIGN_8 (n_sets) / 8; \
  if (in_mask) {		     \
    for (inx = 0; inx < n; inx++) \
      mask[inx] ^= in_mask[inx]; }		\
  else {					\
    for (inx = 0; inx < n; inx++) \
      mask[inx] = ~mask[inx]; }	  \
}


#define V_HANDLE_ARTM(f, ops)			\
  if (!set_mask && ops && artm_vec (qst, ins, ops)) \
; \
  else if (ins->_.artm.func)			\
    dc_artm_funcs[ins->_.artm.func] (ins, qst); \
  else \
    { \
      SET_LOOP { \
	HANDLE_ARTM_IN(f);			\
      } END_SET_LOOP;						      \
    } \
      ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.artm))); \
      break


#define V_HANDLE_ARTM_FPTR(f) \
  SET_LOOP { \
    HANDLE_ARTM_IN(f); \
  } END_SET_LOOP;							\
  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.artm_fptr))); \
  break


int
qi_caller_set (query_instance_t * caller, int * pos, int skip)
{
  int set;
  db_buf_t mask = caller->qi_set_mask;
  if (!mask)
    return *pos = *pos + skip;
  for (set = *pos + 1; set < caller->qi_n_sets; set++)
    {
      if (mask[set >> 3] & (1 << (set & 7)))
	{
	  skip--;
	  if (!skip)
	    {
	      *pos = set;
	      return set;
	    }
	}
    }
  return -1;
}

int enable_cmp_vec = 1;


void
ins_not_vect (caddr_t * inst, instruction_t * ins)
{
  QNCAST (QI, qi, inst);
  qi->qi_set = 0;
  code_vec_run_1 (ins->_.for_vect.code, inst, CV_THIS_SET_ONLY);
}


void
code_vec_run_v (code_vec_t code_vec, caddr_t * qst, int offset, int run_until, int n_sets, data_col_t * ret_dc, int * bool_ret, ssl_index_t bool_ret_fill)
{
  volatile int nesting_level = 0;
  instruction_t * volatile ins;
  instruction_t * volatile prev_ins = NULL;
#ifdef PLDBG
  instruction_t * volatile prev_breakpoint_ins = NULL;
#endif
  query_instance_t *qi = (query_instance_t *)qst;
  dtp_t * set_mask = qi->qi_set_mask;
  int set, first_set = 0;
  if (-1 == n_sets)
    n_sets = qi->qi_n_sets;
  else if (n_sets < -1)
    {
      first_set = -2 - n_sets;
      n_sets = first_set + 1;
    }
  else
    qi->qi_n_sets = n_sets;
  ins = INSTR_ADD_OFS (code_vec, offset);
  qi_check_trx_error (qi, 0);
  qi_check_buf_writers ();
  for (;;)
    {
      qi_check_buf_writers ();
      prev_ins = ins;
      if (DK_MEM_RESERVE)
	{
	  SET_DK_MEM_RESERVE_STATE (qi->qi_trx);
	  qi_check_trx_error (qi, 0);
	}
      switch (ins->ins_type)
	{
	case IN_ARTM_PLUS:	V_HANDLE_ARTM(box_add, vec_adds);
	case IN_ARTM_MINUS:	V_HANDLE_ARTM(box_sub, vec_subs);
	case IN_ARTM_TIMES:	V_HANDLE_ARTM(box_mpy, vec_mpys);
	case IN_ARTM_DIV:		V_HANDLE_ARTM(box_div, vec_divs);
	case IN_ARTM_IDENTITY:
	  vec_ssl_assign (qst, ins->_.artm.result, ins->_.artm.left);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.artm)));
	  break;
	  V_HANDLE_ARTM(box_identity, NULL);
	case IN_ARTM_FPTR:	V_HANDLE_ARTM_FPTR(ins->_.artm_fptr.func);

	case IN_PRED:
	  {
	    int unk_is_fail = ins->_.cmp.unkn == ins->_.cmp.fail;
	    int n_true = 0, n_false = 0, flag;
	    dtp_t * next_mask;
	    dtp_t * save_mask = qi->qi_set_mask;
	    NEXT_MASK (next_mask, qst, ins->_.cmp.next_mask);
	    SET_MASK_CLEAR (next_mask, n_sets);
	    if (bop_comp_func == ins->_.pred.func)
	      {
		for (set = first_set; set < n_sets; set++)
		  {
		    if (!QI_IS_SET (qi, set))
		      continue;
		    qi->qi_set = set;
		    flag = ins->_.pred.func (qst, ins->_.pred.cmp);
		    if (DVC_UNKNOWN == flag)
		      flag = unk_is_fail ? 0 : 1;
		    if (flag)
		      {
			SET_MASK_SET (next_mask, set);
			n_true++;
		      }
		    else
		      n_false++;
		  }
	      }

	    else if (subq_comp_func == ins->_.pred.func)
	      {
		ins_vec_exists (ins, qst, next_mask, &n_true, &n_false);
	      }
	    if (n_true && n_false)
	      {
		int end = ins->_.cmp.end ? ins->_.cmp.end : run_until;
		qi->qi_set_mask = next_mask;
		code_vec_run_v (code_vec, qst, ins->_.cmp.succ, end, n_sets, ret_dc, bool_ret, bool_ret_fill);
		SET_MASK_NEG (next_mask, save_mask, n_sets)
		  qi->qi_set_mask = next_mask;
		code_vec_run_v (code_vec, qst, ins->_.cmp.fail, end, n_sets, ret_dc, bool_ret, bool_ret_fill);
		if (!ins->_.cmp.end)
		  return;
		qi->qi_set_mask = save_mask;
		ins = INSTR_ADD_OFS (code_vec, ins->_.cmp.end);
		break;
	      }
	    else if (n_true)
	      {
		qi->qi_set_mask = next_mask;
		ins = INSTR_ADD_OFS (code_vec, ins->_.cmp.succ);
		continue;
	      }
	    else
	      {
		SET_MASK_NEG (next_mask, save_mask, n_sets);
		qi->qi_set_mask = next_mask;
		ins = INSTR_ADD_OFS (code_vec, ins->_.cmp.fail);
		continue;
	      }

	    break;
	  }
	case IN_COMPARE:
	  {
	    int unk_is_fail = ins->_.cmp.unkn == ins->_.cmp.fail;
	    int n_true = 0, n_false = 0, flag, mix;
	    dtp_t * next_mask;
	    NEXT_MASK (next_mask, qst, ins->_.cmp.next_mask);
	    SET_MASK_CLEAR (next_mask, n_sets);
	    if (enable_cmp_vec && CMP_VEC_NA != (mix = cmp_vec (qst, ins, qi->qi_set_mask, next_mask)))
	      ;
	    else if (ins->_.cmp.func)
	      mix = dc_cmp_funcs[ins->_.cmp.func] (ins, qst, next_mask);
	    else
	      {
		for (set = first_set; set < n_sets; set++)
		  {
		    if (!QI_IS_SET (qi, set))
		      continue;
		    qi->qi_set = set;
		    flag = cmp_boxes_safe (QST_GET (qst, ins->_.cmp.left), QST_GET (qst, ins->_.cmp.right),
					   ins->_.cmp.left->ssl_sqt.sqt_collation, ins->_.cmp.right->ssl_sqt.sqt_collation);
		    if (DVC_UNKNOWN == flag)
		      flag = unk_is_fail ? 0 : ins->_.cmp.op;
		    if (flag & ins->_.cmp.op)
		      {
			SET_MASK_SET (next_mask, set);
			n_true++;
		      }
		    else
		      n_false++;
		  }
		mix = n_true && n_false ? 2 : n_true ? 1 : 0;
	      }
	    if (2 == mix)
	      {
		int end = ins->_.cmp.end ? ins->_.cmp.end : run_until;
		dtp_t * save_mask = qi->qi_set_mask;
		qi->qi_set_mask = next_mask;
		code_vec_run_v (code_vec, qst, ins->_.cmp.succ, end, n_sets, ret_dc, bool_ret, bool_ret_fill);
		SET_MASK_NEG (next_mask, save_mask, n_sets)
		qi->qi_set_mask = next_mask;
		  code_vec_run_v (code_vec, qst, ins->_.cmp.fail, end, n_sets, ret_dc, bool_ret, bool_ret_fill);
		if (!ins->_.cmp.end)
		  return;
		qi->qi_set_mask = save_mask;
		ins = INSTR_ADD_OFS (code_vec, ins->_.cmp.end);
		break;
	      }
	    else if (1 == mix)
	      {
		qi->qi_set_mask = next_mask;
		ins = INSTR_ADD_OFS (code_vec, ins->_.cmp.succ);
		continue;
	      }
	    else
	      {
		SET_MASK_NEG (next_mask, qi->qi_set_mask, n_sets);
		qi->qi_set_mask = next_mask;
		ins = INSTR_ADD_OFS (code_vec, ins->_.cmp.fail);
		continue;
	      }

	    break;
	  }
	case INS_CALL:
	case INS_CALL_IND:
	  ins_call_vec ((instruction_t *) ins, qst, code_vec, first_set, n_sets);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.call)));
	  break;
	case INS_CALL_BIF:
	  {
	    instruction_t ins_tmp;
	    instruction_t * ins_to_use = ins;
	  if (ins->_.bif.vectored)
	    {
		int use_scalar = 0;
		ins_call_bif_vec ((instruction_t *) ins, qst, code_vec, &use_scalar);
		if (use_scalar)
		  {
		    memcpy (&ins_tmp, ins, INS_LEN (ins));
		    ins_to_use = &ins_tmp;
		    ins_tmp._.bif.bif = bif_find (ins->_.bif.proc);
		    goto scalar_case;
		  }
	      ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.bif)));
	      break;
	    }
	  scalar_case:
	  SET_LOOP
	    {
		ins_call_bif ((instruction_t *) ins_to_use, qst, code_vec);
	    }
	  END_SET_LOOP;
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.bif)));
	  break;
	  }
	case INS_SUBQ:
	  ins_vec_subq ((instruction_t *) ins, qst);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.subq)));
	  break;
	case INS_QNODE:
	  ins_qnode ((instruction_t *) ins, qst, 1);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.qnode)));
	  break;
	case INS_OPEN:
	  ins_open ((instruction_t *) ins, qst);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.open)));
	  break;
	case INS_FETCH:
	  qi_check_buf_writers ();
	  ins_fetch ((instruction_t *) ins, qst);
	  qi_check_buf_writers ();
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.fetch)));
	  break;
	case INS_CLOSE:
	  ins_close ((instruction_t *) ins, qst);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.close)));
	  break;
	case INS_COMPOUND_START:
	  nesting_level++;
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.compound_start)));
	  break;
	case INS_COMPOUND_END:
	  nesting_level--;
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.compound_start)));
	  break;
	case INS_HANDLER:
	case IN_AGG:
	  ins_vec_agg (ins, qst);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.agg)));
	  break;

	case INS_HANDLER_END:
	  sqlr_new_error ("42000", "VEC..", "Error handler not allowed in vectored code");
	  break;
	case INS_AREF:
	case INS_SET_AREF:
	  sqlr_new_error ("39000", "SR191", "Unsupported instruction AREF");
	case IN_VRET:
	  {
	    if (ins->_.vret.value && qi->qi_proc_ret)
	      {
		int pos_in_caller = -1, prev_set = -1;
		state_slot_t * ret_ssl = (state_slot_t*)qi->qi_proc_ret;
		query_instance_t * caller_qi = qi->qi_caller;
		int caller_set_save;
		if (SSL_VEC != ret_ssl->ssl_type)
		  {
		    qi->qi_set = 0;
		    qst_set ((caddr_t*)qi->qi_caller, (state_slot_t*)qi->qi_proc_ret, box_copy_tree (qst_get (qst, ins->_.vret.value)));
		    return;
		  }
		caller_set_save = caller_qi->qi_set;
		SET_LOOP
		  {
		    int caller_set = qi_caller_set (qi->qi_caller, &pos_in_caller, qi->qi_set - prev_set);
		    prev_set = qi->qi_set;
		    if (caller_set < 0)
		      break;
		    caller_qi->qi_set = caller_set;
		    qst_vec_set_copy ((caddr_t*)caller_qi, ret_ssl, qst_get (qst, ins->_.vret.value));
		  }
		END_SET_LOOP;
		caller_qi->qi_set = caller_set_save;
		qi_check_buf_writers ();
		return;
	      }
	  }
	  return;
	case IN_BRET:
	  qi_check_buf_writers ();
	  if (ins->_.bret.bool_value)
	    {
	      SET_LOOP
		{
		  bool_ret[QST_INT (qst, bool_ret_fill)++] = qi->qi_set;
		}
	      END_SET_LOOP;
	    }
	  return;

	case IN_JUMP:
	  qi_check_trx_error (qi, 0);
	  nesting_level = ins->_.label.nesting_level;
	  if (run_until == ins->_.label.label)
	    return;
	  ins = INSTR_ADD_OFS (code_vec, ins->_.label.label);
	  break;
#ifdef PLDBG
	case INS_BREAKPOINT:
	  prev_breakpoint_ins = (instruction_t *) ins;
	  ins_break ((instruction_t *) ins, qst);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.breakpoint)));
	  break;
#endif
	case INS_FOR_VECT:
	  if (NO_VEC != ins->_.for_vect.modify)
	    sqlr_new_error ("42000", "VEC..", "for_vectored not allowed inside vectored code");
	  ins_not_vect (qst, ins);
	  ins = INSTR_ADD_BOFS (ins, ALIGN_INSTR (sizeof (ins->_.for_vect)));
	  break;
	}

    }
  qi_check_buf_writers ();
  return;
}

