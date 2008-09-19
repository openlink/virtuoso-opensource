/*
 *  sqlexp.c
 *
 *  $Id$
 *
 *  Dynamic SQL Expression Generator
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
 *  
*/

#include "libutil.h"
#include "sqlnode.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqlo.h"
#include "sqltype.h"
#include "sqltype_c.h"
#include "sqlcstate.h"


bop_comparison_t *bop_comparison (int op, state_slot_t * l, state_slot_t * r);
void cv_call_set_result_cols (sql_comp_t * sc, instruction_t * ins, state_slot_t **params);


caddr_t
nao_func (caddr_t l, caddr_t r, caddr_t * qst, state_slot_t * target)
{
  sqlr_new_error ("42000", "SR170", "Unsupported arithmetic op.");
  return NULL;
}


#if 0
ao_func_t
bop_to_artm_func (int bop)
{
  switch (bop)
    {
    case BOP_PLUS:
      return (ao_func_t)(box_add);
    case BOP_MINUS:
      return (ao_func_t)(box_sub);
    case BOP_TIMES:
      return (ao_func_t)(box_mpy);
    case BOP_DIV:
      return (ao_func_t)(box_div);
    default:
      return (ao_func_t)(nao_func);
    }
}


char *
artm_func_to_text (ao_func_t ao)
{
  if (ao == (ao_func_t)(box_add))
    return "+";
  else if (ao == (ao_func_t)(box_sub))
    return "-";
  else if (ao == (ao_func_t)(box_mpy))
    return "*";
  else if (ao == (ao_func_t)(box_div))
    return "/";
  else if (ao == (ao_func_t)(box_identity))
    return ":=";
  else
    return "<UNKNOWN>";
}
#else
char
bop_to_artm_code (int bop)
{
  switch (bop)
    {
    case BOP_PLUS:
      return IN_ARTM_PLUS;
    case BOP_MINUS:
      return IN_ARTM_MINUS;
    case BOP_TIMES:
      return IN_ARTM_TIMES;
    case BOP_DIV:
      return IN_ARTM_DIV;
    default:
      return INS_NOT_VALID;
    }
}
const char *
ins_type_to_artm_name (char type)
{
  switch (type)
    {
    case IN_ARTM_PLUS:		return "+";
    case IN_ARTM_MINUS:		return "-";
    case IN_ARTM_TIMES:		return "*";
    case IN_ARTM_DIV:		return "/";
    case IN_ARTM_IDENTITY:	return ":=";
    default: 			return "<unknown>";
    }
}
#endif


void
sqlc_call_ret_name (ST * tree, char * func_name, state_slot_t * ssl)
{
  caddr_t name;
  if (!ssl)
    return;
  name = sqlo_iri_constant_name  (tree);
  if (DV_STRINGP (name))
    {
      caddr_t pref, local ;
      iri_split (name, &pref, &local);
      dk_free_box (pref);
      dk_free_box (ssl->ssl_name);
      ssl->ssl_name = local;
    }
}


void
sqlc_call_exp (sql_comp_t * sc, dk_set_t * code, state_slot_t * ret, ST * tree)
{
  caddr_t * kwds = NULL;
  ST **act_params = tree->_.call.params;
  ST *ret_param = BOX_ELEMENTS (tree) > 3 ? tree->_.call.ret_param : NULL;
  caddr_t func = tree->_.call.name;
  state_slot_t *fun_ssl = NULL;
  caddr_t fun_name = NULL;
  state_slot_t **params = NULL;
  char *full_name = NULL;
  query_t *proc = NULL;
  int inx;
  int n_params = act_params ? BOX_ELEMENTS (act_params) : 0;
  caddr_t fun_udt_name = NULL, type_name = BOX_ELEMENTS (tree) > 4 ? tree->_.call.type_name : NULL;
  size_t func_len = ((DV_SYMBOL == DV_TYPE_OF (func)) ? (box_length (func) - 1) : 0);
  if ((func_len > 10) && !stricmp (func + (func_len - 10), " (w/cache)") && (n_params > 0))
    {
      state_slot_t *cache = ssl_new_inst_variable (sc->sc_cc, "cache", DV_ARRAY_OF_POINTER);
      ((ptrlong *)(act_params[n_params - 1]))[0] = cache->ssl_index;
    }
  if (ret_param)
    params = (state_slot_t **) t_alloc_box ((n_params + 1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  else
    params = (state_slot_t **) t_box_copy ((caddr_t) act_params);

  DO_BOX (ST *, par, inx, act_params)
  {
    if (ST_P (par, KWD_PARAM))
      {
	if (!kwds)
	  {
	    kwds = (caddr_t *) t_alloc_box (box_length ((caddr_t) act_params), DV_ARRAY_OF_POINTER);
	    memset (kwds, 0, box_length (kwds));
	  }
	kwds[inx] = t_box_copy ((caddr_t) par->_.bin_exp.left);
	params[inx + (ret_param ? 1 : 0) ] = scalar_exp_generate (sc, par->_.bin_exp.right, code);
      }
    else
      params[inx + (ret_param ? 1 : 0)] = scalar_exp_generate (sc, par, code);
  }
  END_DO_BOX;
  if (ret_param)
    {
      params[0] = scalar_exp_generate (sc, ret_param, code);
    }


  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (func) && BOX_ELEMENTS (func) == 1)
    {
      fun_ssl = scalar_exp_generate (sc, ((ST **) func)[0], code);
    }
  else if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (func) && BOX_ELEMENTS (func) == 2)
    {
      fun_name = ((caddr_t *) func)[0];
      fun_udt_name = ((caddr_t *) func)[1];
    }
  else
    fun_name = func;

  sqlc_call_ret_name (tree, fun_name, ret);
  if (fun_name && !fun_udt_name && !bif_find (fun_name))
    {

      if (sc->sc_super && QR_IS_MODULE (sc->sc_super->sc_cc->cc_query))
	{
	  char rq[MAX_NAME_LEN], ro[MAX_NAME_LEN], rn[MAX_NAME_LEN];
	  sch_split_name (cli_qual (sqlc_client ()),
	      sc->sc_super->sc_cc->cc_query->qr_proc_name,
              rq, ro, rn);
	  full_name = sch_full_proc_name_1 (sc->sc_cc->cc_schema, fun_name,
	      cli_qual (sqlc_client ()), CLI_OWNER (sqlc_client ()), rn);
	}
      else
	full_name = sch_full_proc_name (sc->sc_cc->cc_schema, fun_name,
	    cli_qual (sqlc_client ()), CLI_OWNER (sqlc_client ()));
      if (full_name)
	proc = sch_proc_def (sc->sc_cc->cc_schema, full_name);
    }

  if (!fun_udt_name &&
      sqlc_udt_method_call (sc,
	fun_name, code, ret,
	params, (caddr_t) ret_param,
	type_name))
      return;

  if (fun_name /*&& !bif_find (fun_name)*/)
    {
      if (!proc)
	{
	  if (sqlc_udt_is_udt_call (sc, fun_name, code, ret, params, (caddr_t) ret_param, fun_udt_name))
	    return;
	}
    }
  cv_call (code, fun_ssl, fun_name, ret, (state_slot_t **) box_copy ((box_t) params));
  cv_call_set_type (sc, (instruction_t *) (*code)->data, NULL);
  if (kwds)
    ((instruction_t*) (*code)->data)->_.call.kwds = (caddr_t *) box_copy_tree ((box_t) kwds);
  /*cv_call_set_result_cols (sc, (instruction_t *) (*code)->data, params);*/
  if (proc)
    {
      int inx = 0;
      char tm[MAX_NAME_LEN * 3 + 20];
      _DO_BOX (inx, act_params)
	{
	  state_slot_t *actual;
	  state_slot_t *formal = NULL;
	  actual = params[inx + (ret_param ? 1 : 0)];
	  if (kwds && kwds[inx])
	    {
	      formal = NULL;
	      DO_SET (state_slot_t *, param, &proc->qr_parms)
		{
		  if (param && 0 == stricmp (param->ssl_name, kwds[inx]))
		    {
		      formal = param;
		      break;
		    }
		}
	      END_DO_SET ();
	    }
	  else
	    {
	      formal = (state_slot_t *) dk_set_nth (proc->qr_parms, inx);
	    }
	  if (formal)
	    {
	      snprintf (tm, sizeof (tm), "%s() %dth arg",
		  proc->qr_proc_name ? proc->qr_proc_name : "<unnamed>",
		  inx + 1);
	      cv_bop_params (formal, actual, &tm[0]);
	    }
	}
      END_DO_BOX;
      cv_call_set_type (sc, (instruction_t *) (*code)->data, proc);
    }
}


state_slot_t *
sqlc_new_temp (sql_comp_t * sc, const char *name, dtp_t dtp)
{
  state_slot_t *out;
  if (sc->sc_temp_in_qst)
    {
      out = ssl_new_variable (sc->sc_cc, name, dtp);
      return out;
    }
  else
    return (ssl_new_inst_variable (sc->sc_cc, name, dtp));
}

#define DEF_PRIVATE_ELTS \
        id_hash_t *old_private_elts = NULL

#define SET_PRIVATE_ELTS(sc,dfe,inx) \
        if ((sc)->sc_so && dfe && dfe->_.control.terms) \
          { \
	    old_private_elts = (sc)->sc_so->so_df_private_elts; \
	    (sc)->sc_so->so_df_private_elts = (dfe)->_.control.private_elts[(inx)]; \
	  }

#define RESTORE_PRIVATE_ELTS(sc,dfe) \
        if ((sc)->sc_so && dfe && dfe->_.control.terms) \
          (sc)->sc_so->so_df_private_elts = old_private_elts

#define GENERATE_CONTROL_EXP(sc,dfe,inx,code) \
	if (dfe && dfe->_.control.terms) \
          { \
	    df_elt_t **elt = dfe->_.control.terms[inx]; \
	    int inx2; \
	    for (inx2 = 1; inx2 < BOX_ELEMENTS_INT (elt); inx2++) \
	      sqlg_dfe_code (sc->sc_so, elt[inx2], code, 0, 0, 0); \
	  }



state_slot_t *
sqlc_comma_exp (sql_comp_t * sc, ST * tree, dk_set_t * code)
{
  state_slot_t *res = NULL;
  int inx;
  df_elt_t *dfe = sc->sc_so ? sqlo_df (sc->sc_so, tree) : NULL;
  DEF_PRIVATE_ELTS;

  DO_BOX (ST *, exp, inx, (ST **) tree->_.comma_exp.exps)
  {
    SET_PRIVATE_ELTS (sc, dfe, inx);
    GENERATE_CONTROL_EXP (sc, dfe, inx, code);
    res = scalar_exp_generate (sc, exp, code);
    RESTORE_PRIVATE_ELTS (sc, dfe);
  }
  END_DO_BOX;
  return res;
}


state_slot_t *
sqlc_simple_case (sql_comp_t * sc, ST * tree, dk_set_t * code)
{
  int was_else = 0;
  jmp_label_t end = sqlc_new_label (sc);
  int n_exps = BOX_ELEMENTS (tree->_.comma_exp.exps);
  state_slot_t *res = sqlc_new_temp (sc, "callret", DV_UNKNOWN);
  state_slot_t *sel;
  int inx;
  ST **exps = tree->_.comma_exp.exps;
  df_elt_t *dfe = sc->sc_so ? sqlo_df (sc->sc_so, tree) : NULL;
  DEF_PRIVATE_ELTS;

  res->ssl_is_callret = 1;
  SET_PRIVATE_ELTS (sc, dfe, 0);
  GENERATE_CONTROL_EXP (sc, dfe, 0, code);
  sel = scalar_exp_generate (sc, exps[0], code);
  RESTORE_PRIVATE_ELTS (sc, dfe);
  for (inx = 1; inx < n_exps; inx += 2)
    {
      jmp_label_t ok = sqlc_new_label (sc);
      jmp_label_t next = sqlc_new_label (sc);
      ST *cond = exps[inx];
      ST *then = exps[inx + 1];
      state_slot_t *cres, *val;

      if (ST_P (cond, QUOTE))
	{
	  if (inx != n_exps - 2 || n_exps == 3)
	    sqlc_new_error (sc->sc_cc, "37000", "SQ080", "ELSE must be last clause in CASE.");
	  SET_PRIVATE_ELTS (sc, dfe, inx + 1);
	  GENERATE_CONTROL_EXP (sc, dfe, inx + 1, code);
	  val = scalar_exp_generate (sc, then, code);
	  cv_artm (code, box_identity, res, val, NULL);
	  was_else = 1;
	  RESTORE_PRIVATE_ELTS (sc, dfe);
	  break;
	}
      SET_PRIVATE_ELTS (sc, dfe, inx);
      GENERATE_CONTROL_EXP (sc, dfe, inx, code);
      cres = scalar_exp_generate (sc, cond, code);
      cv_compare (code, BOP_EQ, sel, cres, ok, next, next);
      cv_label (code, ok);
      RESTORE_PRIVATE_ELTS (sc, dfe);
      SET_PRIVATE_ELTS (sc, dfe, inx + 1);
      GENERATE_CONTROL_EXP (sc, dfe, inx + 1, code);
      val = scalar_exp_generate (sc, then, code);
      cv_artm (code, box_identity, res, val, NULL);
      cv_jump (code, end);
      cv_label (code, next);
      RESTORE_PRIVATE_ELTS (sc, dfe);
    }
  if (!was_else)
    {
      state_slot_t *nullc = ssl_new_constant (sc->sc_cc,
	  t_alloc_box (0, DV_DB_NULL));
      cv_artm (code, (ao_func_t) box_identity, res,
	  nullc, NULL);
    }
  cv_label (code, end);

  return res;
}


state_slot_t *
sqlc_searched_case (sql_comp_t * sc, ST * tree, dk_set_t * code)
{
  int was_else = 0;
  jmp_label_t end = sqlc_new_label (sc);
  int n_exps = BOX_ELEMENTS (tree->_.comma_exp.exps);
  state_slot_t *res = sqlc_new_temp (sc, "callret", DV_UNKNOWN);
  int inx;
  ST **exps = tree->_.comma_exp.exps;
  df_elt_t *dfe = sc->sc_so ? sqlo_df (sc->sc_so, tree) : NULL;
  DEF_PRIVATE_ELTS;

  res->ssl_is_callret = 1;
  for (inx = 0; inx < n_exps; inx += 2)
    {
      jmp_label_t ok;
      jmp_label_t next;
      ST *cond;
      ST *then;
      state_slot_t *val;

      ok = sqlc_new_label (sc);
      next = sqlc_new_label (sc);
      cond = exps[inx];
      then = exps[inx + 1];

      if (ST_P (cond, QUOTE))
	{
	  if (inx != n_exps - 2 || n_exps == 3)
	    sqlc_new_error (sc->sc_cc, "37000", "SQ081", "ELSE must be last clause in CASE.");
	  SET_PRIVATE_ELTS (sc, dfe, inx + 1);
	  GENERATE_CONTROL_EXP (sc, dfe, inx + 1, code);
	  val = scalar_exp_generate (sc, then, code);
	  cv_artm (code, box_identity, res, val, NULL);
	  was_else = 1;
	  RESTORE_PRIVATE_ELTS (sc, dfe);
	  break;
	}
      SET_PRIVATE_ELTS (sc,dfe,inx);
      GENERATE_CONTROL_EXP (sc, dfe, inx, code);
      pred_gen_1 (sc, cond, code, ok, next, next);
      cv_label (code, ok);
      RESTORE_PRIVATE_ELTS (sc, dfe);
      SET_PRIVATE_ELTS (sc,dfe,inx + 1);
      GENERATE_CONTROL_EXP (sc, dfe, inx + 1, code);
      val = scalar_exp_generate (sc, then, code);
      cv_artm (code, box_identity, res, val, NULL);
      cv_jump (code, end);
      cv_label (code, next);
      RESTORE_PRIVATE_ELTS (sc, dfe);
    }
  if (!was_else)
    {
      state_slot_t *nullc = ssl_new_constant (sc->sc_cc,
	  t_alloc_box (0, DV_DB_NULL));
      cv_artm (code, (ao_func_t) box_identity, res, nullc, NULL);
    }
  cv_label (code, end);

  return res;
}


state_slot_t *
sqlc_coalesce_exp (sql_comp_t * sc, ST * tree, dk_set_t * code)
{
  state_slot_t *nullc = ssl_new_constant (sc->sc_cc, t_alloc_box (0, DV_DB_NULL));
  jmp_label_t end = sqlc_new_label (sc);
  int n_exps = BOX_ELEMENTS (tree->_.comma_exp.exps);
  state_slot_t *res = sqlc_new_temp (sc, "coalesce_ret", DV_UNKNOWN);
  int inx;
  ST **exps = tree->_.comma_exp.exps;
  df_elt_t *dfe = sc->sc_so ? sqlo_df (sc->sc_so, tree) : NULL;

  res->ssl_is_callret = 1;
  for (inx = 0; inx < n_exps; inx++)
    {
      jmp_label_t ok = sqlc_new_label (sc);
      jmp_label_t next = sqlc_new_label (sc);
      ST *cond = exps[inx];
      state_slot_t *cres;
      DEF_PRIVATE_ELTS;

      SET_PRIVATE_ELTS (sc, dfe, inx);
      GENERATE_CONTROL_EXP (sc, dfe, inx, code);
      cres = scalar_exp_generate (sc, cond, code);
      cv_bop_params (res, cres, "COALESCE");
      cv_compare (code, BOP_NULL, cres, nullc, next, ok, next);
      cv_label (code, ok);
      cv_artm (code, box_identity, res, cres, NULL);
      cv_jump (code, end);
      cv_label (code, next);
      RESTORE_PRIVATE_ELTS (sc, dfe);
    }
  cv_artm (code, box_identity, res, nullc, NULL);
  cv_label (code, end);
  return res;
}


state_slot_t *
seg_ret_fn (df_elt_t * dfe, state_slot_t * ssl)
{
  if (dfe)
    dfe->dfe_ssl = ssl;
  return ssl;
}


#define seg_return(x) \
  return (seg_ret_fn (dfe, x))

state_slot_t *
scalar_exp_generate (sql_comp_t * sc, ST * tree, dk_set_t * code)
{
  df_elt_t * dfe = NULL;
  if (sc->sc_so)
    {
      dfe = sqlo_df (sc->sc_so, tree);
      if (dfe->dfe_ssl)
	return (dfe->dfe_ssl);
    }
  if (SYMBOLP (tree))
    {
      state_slot_t * ssl;
      if (sc->sc_so)
	ssl = sqlg_dfe_ssl (sc->sc_so, dfe);
      else
	ssl = sqlc_col_ref_ssl (sc, tree);
      return ssl;
    }
  if (LITERAL_P (tree))
    {
      seg_return (ssl_new_constant (sc->sc_cc, (caddr_t) tree));
    }
  if (!ARRAYP (tree))
    sqlc_new_error (sc->sc_cc, "42000", "SQ194", "Can't generate scalar exp from a literal of type %d", DV_TYPE_OF(tree));
  if (ST_P (tree, QUOTE))
    {
      seg_return (ssl_new_constant (sc->sc_cc, (caddr_t) tree->_.op.arg_1));
    }
  if (ST_P (tree, COL_DOTTED) ||
      ST_P (tree, FUN_REF))
    {
      state_slot_t * ssl;
      if (sc->sc_so)
	ssl = sqlg_dfe_ssl (sc->sc_so, dfe);
      else
	ssl = sqlc_col_ref_ssl (sc, tree);
      switch (ssl->ssl_type)
	{
	case SSL_COLUMN:
	case SSL_VARIABLE:
	case SSL_PARAMETER:
	case SSL_REF_PARAMETER:
	case SSL_REF_PARAMETER_OUT:
	  return ssl;
	default:
	  sqlc_new_error (sc->sc_cc, "37000", "SQ082", "Reference to non-object variable");
	}
    }
  if (ST_P (tree, BOP_AS))
    return (scalar_exp_generate (sc, tree->_.bin_exp.left, code));
  if (BIN_EXP_P (tree))
    {
      state_slot_t *left = scalar_exp_generate (sc, tree->_.bin_exp.left, code);
      state_slot_t *right = scalar_exp_generate (sc, tree->_.bin_exp.right, code);
      NEW_INSTR (ins, bop_to_artm_code ((int) tree->type), code);
      ins->_.artm.left = left;
      ins->_.artm.right = right;
      ins->_.artm.result = sqlc_new_temp (sc, "temp", DV_UNKNOWN);
      if (ins->ins_type == INS_NOT_VALID)
	sqlc_new_error (sc->sc_cc, "37000", "SQ460", "Invalid arithmetic operation");
      cv_artm_set_type (ins);
      seg_return (ins->_.artm.result);
    }

  switch (tree->type)
    {
    case ARRAY_REF:
      {
	state_slot_t *arr = scalar_exp_generate (sc, tree->_.aref.arr, code);
	state_slot_t *inx = scalar_exp_generate (sc, tree->_.aref.inx, code);
	state_slot_t *res = ssl_new_variable (sc->sc_cc, "aref", DV_SHORT_STRING);
	cv_aref (code, res, arr, inx, NULL);
	seg_return (res);
      }
    case ASG_STMT:
      seg_return (sqlc_asg_stmt (sc, tree, code));
    case COMMA_EXP:
      seg_return (sqlc_comma_exp (sc, tree, code));
    case SIMPLE_CASE:
      seg_return (sqlc_simple_case (sc, tree, code));
    case SEARCHED_CASE:
      seg_return (sqlc_searched_case (sc, tree, code));
    case COALESCE_EXP:
      seg_return (sqlc_coalesce_exp (sc, tree, code));
    case CALL_STMT:
      {
	state_slot_t *res = sqlc_new_temp (sc, "callret", DV_UNKNOWN);
	res->ssl_is_callret = 1;
	tree = sqlo_udt_check_method_call (sc->sc_so, sc, tree);
	sqlc_call_exp (sc, code, res, tree);
	seg_return (res);
      }
    case SCALAR_SUBQ:
      {
	subq_compilation_t * sqc = sqlc_subq_compilation (sc, tree->_.bin_exp.left, NULL);
	cv_subq (code, sqc);
	return (sqc->sqc_query->qr_select_node->sel_out_slots[0]);
      }
    }
  sqlc_new_error (sc->sc_cc, "42000", "SQ083", "Can't generate scalar exp %d", tree->type);
  return NULL;
}


state_slot_t *
scalar_exp_generate_typed (sql_comp_t * sc, ST * tree, dk_set_t * code, sql_type_t * expect)
{
  state_slot_t * ssl = scalar_exp_generate (sc, tree, code);
  if (SSL_IS_UNTYPED_PARAM (ssl) && IS_BOX_POINTER (expect))
    {
      ssl->ssl_sqt = *expect;
    }
  return ssl;
}

jmp_label_t
sqlc_new_label (sql_comp_t * sc)
{
  return (sc->sc_last_label++);
}



void
cv_label (dk_set_t * code, jmp_label_t label)
{
  NEW_INSTR (ins, IN_LABEL, code);
  ins->_.label.label = label;
}


const char *
ssl_type_to_name (char ssl_type)
{
  switch (ssl_type)
    {
      case SSL_PARAMETER: return "<parameter>";
      case SSL_COLUMN: return "<column>";
      case SSL_VARIABLE: return "<variable>";
      case SSL_PLACEHOLDER: return "<placeholder>";
      case SSL_ITC: return "<int.cursor>";
      case SSL_CURSOR: return "<cursor>";
      case SSL_REMOTE_STMT: return "<remote stmt>";
      case SSL_CONSTANT: return "<constant>";
      case SSL_REF_PARAMETER: return "<in/out param>";
      case SSL_REF_PARAMETER_OUT: return "<out param>";
    }
  return "<unnamed>";
}

void
cv_bop_params (state_slot_t * l, state_slot_t * r, const char *op)
{
  if (!r || !l)
    return;
  if (!SSL_IS_UNTYPED_PARAM (l) &&
      !SSL_IS_UNTYPED_PARAM (r) &&
      SQW_DTP_COLIDE (l->ssl_dtp, l->ssl_class, r->ssl_dtp, r->ssl_class))
    {
      if ((DV_UNAME == l->ssl_dtp) && (DV_STRING == r->ssl_dtp))
        goto skip_warning;
      if ((DV_UNAME == r->ssl_dtp) && (DV_STRING == l->ssl_dtp))
        goto skip_warning;
      if (l->ssl_dtp != DV_TIMESTAMP && r->ssl_dtp != DV_TIMESTAMP)
	{
	  sqlc_warning ("01V01", "QW004",
	      "Incompatible types %.*s%s%s%s (%d) and %.*s%s%s%s (%d) in %s for %.*s and %.*s",
	      MAX_NAME_LEN, dv_type_title (l->ssl_dtp),
              l->ssl_class ? " " : "",
              l->ssl_class ? l->ssl_class->scl_name : "",
              l->ssl_class && l->ssl_class->scl_obsolete ? ":obsolete" : "",
	      (int) l->ssl_dtp,
	      MAX_NAME_LEN, dv_type_title (r->ssl_dtp),
              r->ssl_class ? " " : "",
              r->ssl_class ? r->ssl_class->scl_name : "",
              r->ssl_class && r->ssl_class->scl_obsolete ? ":obsolete" : "",
	      (int) r->ssl_dtp,
	      op,
	      MAX_NAME_LEN, SSL_HAS_NAME (l) ? l->ssl_name : ssl_type_to_name (l->ssl_type),
	      MAX_NAME_LEN, SSL_HAS_NAME (r) ? r->ssl_name : ssl_type_to_name (r->ssl_type));
	}
skip_warning:
       /*no op */;
    }

  if (SSL_IS_UNTYPED_PARAM (r))
    {
      if (SSL_IS_UNTYPED_PARAM (l))
	return;
      else
	r->ssl_sqt = l->ssl_sqt;
    }
  if (SSL_IS_UNTYPED_PARAM (l))
    l->ssl_sqt = r->ssl_sqt;
}


void
cv_artm_set_type (instruction_t * ins)
{
  if (DV_UNKNOWN == ins->_.artm.result->ssl_dtp)
    {
      if (ins->_.artm.right)
	{
	  ins->_.artm.result->ssl_dtp = MAX (ins->_.artm.left->ssl_dtp, ins->_.artm.right->ssl_dtp);
	  if (DV_NUMERIC == ins->_.artm.result->ssl_dtp)
	    {
	      ins->_.artm.result->ssl_sqt.sqt_precision = NUMERIC_MAX_PRECISION;
	      ins->_.artm.result->ssl_sqt.sqt_scale = NUMERIC_MAX_SCALE;
	    }
	  cv_bop_params (ins->_.artm.left, ins->_.artm.right,
	      ins_type_to_artm_name (ins->ins_type));
	}
      else
	{
	  cv_bop_params (ins->_.artm.result, ins->_.artm.left,
	      ins_type_to_artm_name (ins->ins_type));
	}
    }
  else
    {
      if (ins->_.artm.right)
	{
	  cv_bop_params (ins->_.artm.left, ins->_.artm.right,
	      ins_type_to_artm_name (ins->ins_type));
	}
      cv_bop_params (ins->_.artm.result, ins->_.artm.left,
	  ins_type_to_artm_name (ins->ins_type));
    }
}

#define CHECK_ARTM_SSL(ssl,op) \
  if ((ssl) && \
      DV_UNKNOWN != (ssl)->ssl_dtp && \
      DV_ANY != (ssl)->ssl_dtp && \
      !IS_NUM_DTP ((ssl)->ssl_dtp)) \
    { \
      sqlc_warning ("01V01", "QW008", \
	 "Invalid %s arithmetic operation argument %s type %s (%d)", \
	 (op), \
	 SSL_HAS_NAME(ssl) ? (ssl)->ssl_name : ssl_type_to_name ((ssl)->ssl_type), \
	 dv_type_title((ssl)->ssl_dtp), \
	 (ssl)->ssl_dtp); \
    }


void
cv_artm (dk_set_t * code, ao_func_t f, state_slot_t * res,
	 state_slot_t * l, state_slot_t * r)
{
  if (f == (ao_func_t) box_add)
    {
      NEW_INSTR (ins, IN_ARTM_PLUS, code);
      CHECK_ARTM_SSL(l, "addition (+)");
      CHECK_ARTM_SSL(r, "addition (+)");
      ins->_.artm.left = l;
      ins->_.artm.right = r;
      ins->_.artm.result = res;
    }
  else if (f == (ao_func_t) box_sub)
    {
      NEW_INSTR (ins, IN_ARTM_MINUS, code);
      CHECK_ARTM_SSL(l, "subtraction (-)");
      CHECK_ARTM_SSL(r, "subtraction (-)");
      ins->_.artm.left = l;
      ins->_.artm.right = r;
      ins->_.artm.result = res;
    }
  else if (f == (ao_func_t) box_mpy)
    {
      NEW_INSTR (ins, IN_ARTM_TIMES, code);
      CHECK_ARTM_SSL(l, "multiplication (*)");
      CHECK_ARTM_SSL(r, "multiplication (*)");
      ins->_.artm.left = l;
      ins->_.artm.right = r;
      ins->_.artm.result = res;
    }
  else if (f == (ao_func_t) box_div)
    {
      NEW_INSTR (ins, IN_ARTM_DIV, code);
      CHECK_ARTM_SSL(l, "division (/)");
      CHECK_ARTM_SSL(r, "division (/)");
      ins->_.artm.left = l;
      ins->_.artm.right = r;
      ins->_.artm.result = res;
    }
  else if (f == (ao_func_t) box_identity)
    {
      NEW_INSTR (ins, IN_ARTM_IDENTITY, code);
      ins->_.artm.left = l;
      ins->_.artm.right = r;
      ins->_.artm.result = res;
    }
  else
    {
      NEW_INSTR (ins, IN_ARTM_FPTR, code);
      ins->_.artm_fptr.func = f;
      ins->_.artm_fptr.left = l;
      ins->_.artm_fptr.right = r;
      ins->_.artm_fptr.result = res;
    }
  cv_artm_set_type ((instruction_t *)(*code)->data);
}

#define CHECK_CMP_SSL(ssl,op) \
  if ((ssl) && \
      (IS_BLOB_DTP ((ssl)->ssl_dtp) || \
       IS_UDT_DTP ((ssl)->ssl_dtp))) \
    { \
      sqlc_warning ("01V01", "QW008", \
	 "Invalid %s comparison operation argument %s type %s (%d)", \
	 (op), \
	 (SSL_HAS_NAME (ssl)) ? (ssl)->ssl_name : ssl_type_to_name ((ssl)->ssl_type), \
	 dv_type_title((ssl)->ssl_dtp), \
	 (ssl)->ssl_dtp); \
    }

void
cv_compare (dk_set_t * code, int bop,
     state_slot_t * l, state_slot_t * r, jmp_label_t succ, jmp_label_t fail, jmp_label_t unkn)
{
  if (bop != BOP_NULL && bop != BOP_LIKE)
    {
      if (l && l->ssl_column && IS_BLOB_DTP (l->ssl_column->col_sqt.sqt_dtp))
	sqlc_new_error (NULL, "22023", "SQ167",
	    "The long varchar, long varbinary and long nvarchar "
	    "data types cannot be used in the WHERE, HAVING, or ON clause, "
	    "except with the IS NULL predicate for column %s", l->ssl_column->col_name);
      if (r && r->ssl_column && IS_BLOB_DTP (r->ssl_column->col_sqt.sqt_dtp))
	sqlc_new_error (NULL, "22023", "SQ168",
	    "The long varchar, long varbinary and long nvarchar "
	    "data types cannot be used in the WHERE, HAVING, or ON clause, "
	    "except with the IS NULL predicate for column %s", r->ssl_column->col_name);
    }

  switch (bop)
    {
    case BOP_EQ: case BOP_LT: case BOP_GT: case BOP_LTE: case BOP_GTE: case BOP_NEQ:
      {
	NEW_INSTR (ins, IN_COMPARE, code);
	ins->_.cmp.succ = succ;
	ins->_.cmp.fail = fail;
	ins->_.cmp.unkn = unkn;
	ins->_.cmp.left = l;
	ins->_.cmp.right = r;
	ins->_.cmp.op = bop_to_dvc (bop);
	CHECK_CMP_SSL(l, bop_text (bop));
	CHECK_CMP_SSL(r, bop_text (bop));
	cv_bop_params (l, r, bop_text (bop));
/*#ifdef CMP_DEBUG
	if ((DVC_MATCH & (int)(ins->_.cmp.op)) && (unkn == succ))
	  fprintf (stderr, "\n%s:%d:*** weird args of cv_compare(): DVC_MATCH bit contradicts with unkn == succ\n",
	    __FILE__, __LINE__ );
#endif*/
	break;
      }
    default:
      {
	NEW_INSTR (ins, IN_PRED, code);
	ins->_.pred.succ = succ;
	ins->_.pred.fail = fail;
	ins->_.pred.unkn = unkn;
	ins->_.pred.func = bop_comp_func;
	ins->_.pred.cmp = bop_comparison (bop, l, r);
	if (BOP_NULL != bop) /* IS NULL infers nothing for the type */
	  {
	    CHECK_CMP_SSL(l, bop_text (bop));
	    CHECK_CMP_SSL(r, bop_text (bop));
	    cv_bop_params (l, r, bop_text (bop));
	  }
      }
    }
}


void *
distinct_comparison (state_slot_t * data, sql_comp_t * sc)
{
  setp_node_t setp;
  memset (&setp, 0, sizeof (setp));
  setp.src_gen.src_query = sc->sc_cc->cc_query;
  t_set_push (&setp.setp_keys, (void*) data);
  setp_distinct_hash (sc, &setp, 0);
  return ((void*) setp.setp_ha);
}

void
cv_distinct (dk_set_t * code,
       state_slot_t * data, sql_comp_t * sc, jmp_label_t succ, jmp_label_t fail)
{
  void * ha; /* hash_area_t* */
  NEW_INSTR (ins, IN_PRED, code);
  ins->_.pred.succ = succ;
  ins->_.pred.fail = fail;
  ins->_.pred.unkn = fail;
  ins->_.pred.func = distinct_comp_func;
  ins->_.pred.cmp = ha = distinct_comparison (data, sc);
  ((hash_area_t *)ha)->ha_allow_nulls = 0;
  dk_set_push (&sc->sc_fref->fnr_distinct_ha, ha);
}




void
cv_vret (dk_set_t * code, state_slot_t * ssl)
{
  NEW_INSTR (ins, IN_VRET, code);
  ins->_.vret.value = ssl;
  if (top_sc && top_sc->sc_cc->cc_query &&
      top_sc->sc_cc->cc_query->qr_proc_ret_type)
    {
      state_slot_t lsl;
      memset (&lsl, 0, sizeof (state_slot_t));
      lsl.ssl_name = box_dv_uname_string ("<return>");
      lsl.ssl_type = SSL_VARIABLE;
      ddl_type_to_sqt (&(lsl.ssl_sqt), (caddr_t *) top_sc->sc_cc->cc_query->qr_proc_ret_type);
      cv_bop_params (&lsl, ssl, "RETURN");
    }
}


void
cv_bret (dk_set_t * code, int val)
{
  NEW_INSTR (ins, IN_BRET, code);
  ins->_.bret.bool_value = val;
#if 0 /* GK: possibly too pedantic, but the code has to be there anyway in the ideal case */
  if (top_sc && top_sc->sc_cc->cc_query &&
      top_sc->sc_cc->cc_query->qr_proc_ret_type)
    {
      dtp_t dtp = ddl_type_to_dtp ((caddr_t *) top_sc->sc_cc->cc_query->qr_proc_ret_type);
      if (SQW_DTP_COLIDE (dtp, NULL, DV_LONG_INT, NULL))
	{
	  sqlc_warning ("01V01", "QW005",
	      "Incompatible types %.*s (%d) and %.*s (%d) in RETURN",
	      MAX_NAME_LEN, dv_type_title (DV_LONG_INT), (int) DV_LONG_INT,
	      MAX_NAME_LEN, dv_type_title (dtp), (int) dtp);
	}
    }
#endif
}


void
cv_jump (dk_set_t * code, jmp_label_t label)
{
  NEW_INSTR (ins, IN_JUMP, code);
  ins->_.label.label = label;
}


void
cv_open (dk_set_t * code, subq_compilation_t * sqc, ST ** opts)
{
  int inx;
  NEW_INSTR (ins, INS_OPEN, code);
  ins->_.open.query = sqc->sqc_query;
  sqc->sqc_is_generated = 1;
  ins->_.open.cursor = sqc->sqc_cr_state_ssl;
#if 0
  ins->_.open.options = opts;
#else
  DO_BOX (ST *, opt, inx, opts)
  {
    if (opt == (ST *) EXCLUSIVE_OPT)
      ins->_.open.exclusive = 1;
  }
  END_DO_BOX;
#endif
}


void
cv_fetch (dk_set_t * code, subq_compilation_t * sqc, state_slot_t ** targets)
{
  int inx;
  NEW_INSTR (ins, INS_FETCH, code);
  ins->_.fetch.query = sqc->sqc_query;
  ins->_.fetch.cursor = sqc->sqc_cr_state_ssl;
  ins->_.fetch.targets = targets;
  t_set_push (&sqc->sqc_fetches, (void *) ins);
  if (targets)
    {
      DO_BOX (state_slot_t *, target, inx, targets)
	{
	  if (target)
	    cv_bop_params (target, sqc->sqc_query->qr_select_node->sel_out_slots[inx], "FETCH");
	}
      END_DO_BOX;
    }
}


void
cv_close (dk_set_t * code, state_slot_t * cr_ssl)
{
  NEW_INSTR (ins, INS_CLOSE, code);
  ins->_.close.cursor = cr_ssl;
}


void
cv_subq (dk_set_t * code, subq_compilation_t * sqc)
{
  NEW_INSTR (ins, INS_SUBQ, code);
  ins->_.subq.query = sqc->sqc_query;
  sqc->sqc_is_generated = 1;
}


void
cv_subq_qr (dk_set_t * code, query_t * qr)
{
  NEW_INSTR (ins, INS_SUBQ, code);
  ins->_.subq.query = qr;
}


void
cv_qnode (dk_set_t * code, data_source_t * node)
{
  NEW_INSTR (ins, INS_QNODE, code);
  ins->_.qnode.node = node;
}

void
cv_call_set_type (sql_comp_t * sc, instruction_t * ins, query_t *qr_found)
{
  state_slot_t *ret = ins->_.call.ret;
  bif_type_t *bt;
  if (!ret || ret->ssl_dtp != DV_UNKNOWN || ins->ins_type == INS_CALL_IND)
    return;
  bt = bif_type (ins->_.call.proc);
  if (bt && !qr_found)
    {
      bif_type_set (bt, ret, ins->_.call.params);
    }
  else
    {
      query_t *qr = qr_found ? qr_found : sch_proc_def (sc->sc_cc->cc_schema, ins->_.call.proc);
      if (!qr || IS_REMOTE_ROUTINE_QR (qr) || !qr->qr_proc_ret_type)
	return;
      else
	{
	  ptrlong *rtype = (ptrlong *) qr->qr_proc_ret_type;
	  ret->ssl_dtp = (dtp_t) rtype[0];
	  ret->ssl_prec = (uint32) rtype[1];
	}
    }
}

caddr_t *
proc_result_col_from_ssl (int inx, state_slot_t *ssl, long type, caddr_t pq, caddr_t po, caddr_t pn)
{
  caddr_t *col = (caddr_t *) dk_alloc_box (10 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  col[0] = pq;
  col[1] = po;
  col[2] = pn;
  col[3] = box_dv_short_string (ssl->ssl_name);
  col[4] = box_num (type);
  col[5] = box_num (ssl->ssl_dtp);
  col[6] = box_num (ssl->ssl_scale);
  col[7] = box_num (ssl->ssl_prec);
  col[8] = box_num (ssl->ssl_non_null ? 0 : 1);
  col[9] = box_num (inx);
  return col;
}

void
cv_call_set_result_cols (sql_comp_t * sc, instruction_t * ins, state_slot_t **params)
{
  query_t *qr = sc->sc_cc->cc_query;
  if (INS_CALL_BIF == ins->ins_type && ins->_.bif.bif == bif_result_names && qr)
    {
      int inx;
      DO_BOX (state_slot_t *, ssl, inx, params)
	{
	  caddr_t *col = proc_result_col_from_ssl (inx + 1, ssl, 3, NULL, NULL, NULL);
	  dk_set_push (&qr->qr_proc_result_cols, col);
	}
      END_DO_BOX;
    }
}


void
cv_call (dk_set_t * code, state_slot_t * fun_exp, caddr_t proc,
	 state_slot_t * ret, state_slot_t ** params)
{
  bif_t bif = NULL;
  NEW_INSTR (ins, INS_CALL, code);
  if (proc)
    {
      proc = find_pl_bif_name (proc);
      ins->_.call.proc = box_dv_uname_string (proc);
    }
  ins->_.call.proc_ssl = fun_exp;
  if (fun_exp && IS_REAL_SSL (ret))
    ins->ins_type = INS_CALL_IND;
  else
    bif = bif_find (proc);
  ins->_.call.ret = ret;
  ins->_.call.params = params;
  if (bif)
    {
      ins->_.bif.bif = bif;
      ins->ins_type = INS_CALL_BIF;
    }
}

void
cv_bif_call (dk_set_t * code, bif_t bif, caddr_t proc, state_slot_t * ret, state_slot_t ** params)
{
  NEW_INSTR (ins, INS_CALL, code);
  if (proc)
    ins->_.call.proc = box_dv_uname_string (proc);
  ins->_.call.ret = ret;
  ins->_.call.params = params;
  ins->_.bif.bif = bif;
  ins->ins_type = INS_CALL_BIF;
}

void
cv_aref (dk_set_t * code, state_slot_t * ret, state_slot_t * arr, state_slot_t * inx, state_slot_t * val)
{
  NEW_INSTR (ins, val ? INS_SET_AREF : INS_AREF, code);
  ins->_.aref.inx = inx;
  ins->_.aref.arr = arr;
  ins->_.aref.val = val ? val : ret;
}


void
cv_handler (dk_set_t * code, caddr_t *states, long label, state_slot_t *throw_loc,
    state_slot_t *nest, state_slot_t *sql_state, state_slot_t *sql_message)
{
  NEW_INSTR (ins, INS_HANDLER, code);
  ins->_.handler.states = (caddr_t *) box_copy_tree ((box_t) states);
  ins->_.handler.label = label;
  ins->_.handler.throw_location = throw_loc;
  ins->_.handler.throw_nesting_level = nest;
  ins->_.handler.state = sql_state;
  ins->_.handler.message = sql_message;
}


void
cv_handler_end (dk_set_t * code, long type, state_slot_t *throw_loc, state_slot_t *nest)
{
  NEW_INSTR (ins, INS_HANDLER_END, code);
  ins->_.handler_end.type = type;
  ins->_.handler_end.throw_location = throw_loc;
  ins->_.handler_end.throw_nesting_level = nest;
}


bop_comparison_t *
bop_comparison (int op, state_slot_t * l, state_slot_t * r)
{
  NEW_VARZ (bop_comparison_t, bop);
  bop->cmp_op = op;
  bop->cmp_left = l;
  bop->cmp_right = r;
  return bop;
}

subq_pred_t *
cmp_subq_call (sql_comp_t * sc, ST * tree, dk_set_t * code,
	       state_slot_t * left)
{
  NEW_VARZ (subq_pred_t, subp);
  if (sc->sc_so)
    {
      sqlo_t *so = sc->sc_so;
      df_elt_t *dfe = sqlo_df (so, tree);
      subp->subp_query = sqlg_dt_query (so, dfe, NULL, NULL);
      dk_set_push (&sc->sc_cc->cc_query->qr_subq_queries, subp->subp_query);
      subp->subp_query->qr_select_node->src_gen.src_input = (qn_input_fn) select_node_input_subq;
      subp->subp_type = EXISTS_PRED;
    }
  else
    {
      subq_compilation_t *subq = sqlc_subq_compilation (sc, tree->_.subq.subq, NULL);
      subp->subp_query = subq->sqc_query;

      subp->subp_comparison = (int) tree->_.subq.cmp_op;
      subp->subp_type = (int) tree->type;
      subp->subp_left = left;
      subq->sqc_is_generated = 1;
    }
  return subp;
}


void
pred_gen_1 (sql_comp_t * sc, ST * tree, dk_set_t * code, int succ, int fail, int unkn)
{
  if (ST_P (tree, BOP_NOT))
    {
      pred_gen_1 (sc, tree->_.bin_exp.left, code, fail, succ, unkn);
      return;
    }
  if (ST_P (tree, BOP_OR))
    {
      jmp_label_t temp_fail = sqlc_new_label (sc);
      pred_gen_1 (sc, tree->_.bin_exp.left, code, succ, temp_fail, temp_fail);
      cv_label (code, temp_fail);
      pred_gen_1 (sc, tree->_.bin_exp.right, code, succ, fail, unkn);
      return;
    }
  if (ST_P (tree, BOP_AND))
    {
      jmp_label_t temp_succ = sqlc_new_label (sc);
      pred_gen_1 (sc, tree->_.bin_exp.left, code, temp_succ, fail, unkn);
      cv_label (code, temp_succ);
      pred_gen_1 (sc, tree->_.bin_exp.right, code, succ, fail, unkn);
      return;
    }
  if (BIN_EXP_P (tree))
    {

      state_slot_t *left_ssl = scalar_exp_generate (sc, tree->_.bin_exp.left, code);
      state_slot_t *right_ssl = scalar_exp_generate (sc, tree->_.bin_exp.right, code);
      cv_compare (code, (int) tree->type, left_ssl, right_ssl, succ, fail, unkn);
      if (ST_P (tree, BOP_LIKE))
	{
	  instruction_t *ins = (instruction_t *)(*code)->data;
	  bop_comparison_t *pred = (bop_comparison_t *) (ins ? ins->_.pred.cmp : NULL);
	  if (pred)
	    pred->cmp_like_escape = tree->_.bin_exp.more ? tree->_.bin_exp.more[0] : 0;
	}
    }
  else if (SUBQ_P (tree))
    {
      state_slot_t *left = tree->_.subq.left
      ? scalar_exp_generate (sc, tree->_.subq.left, code) : NULL;
      NEW_INSTR (ins, IN_PRED, code);
      ins->_.pred.fail = fail;
      ins->_.pred.succ = succ;
      ins->_.pred.unkn = unkn;
      ins->_.pred.cmp = (void *) cmp_subq_call (sc, tree, code, left);
      ins->_.pred.func = subq_comp_func;
    }
  else
    {
      sqlc_new_error (sc->sc_cc, "42000", "SQ084", "Subquery predicate not supported.");
    }
}



void
pred_list_generate (sql_comp_t * sc, dk_set_t pred_list, dk_set_t * code)
{
  jmp_label_t succ;
  jmp_label_t fail = sqlc_new_label (sc);
  if (!pred_list)
    return;
  DO_SET (predicate_t *, pred, &pred_list)
  {
    succ = sqlc_new_label (sc);
    pred_gen_1 (sc, pred->pred_text, code, succ, fail, fail);
    cv_label (code, succ);
  }
  END_DO_SET ();
  cv_bret (code, 1);
  cv_label (code, fail);
  cv_bret (code, 0);
}


int
src_is_local (data_source_t * src)
{
  if (IS_TS (((table_source_t *)src)))
    return 0;
  if ((qn_input_fn) union_node_input == src->src_input
      || (qn_input_fn) subq_node_input == src->src_input
      || (qn_input_fn) remote_table_source_input == src->src_input
      )
    return 0;
  return 1;
}


int
qr_is_local (query_t * qr)
{
  DO_SET (data_source_t *, src, &qr->qr_nodes)
    {
      if (!cv_is_local (src->src_after_code)
	  || !cv_is_local (src->src_after_test)
	  || !cv_is_local (src->src_pre_code))
	return 0;
      if (!src_is_local (src))
	return 0;
    }
  END_DO_SET();
  return 1;
}


int
cv_is_local (code_vec_t cv)
{
  DO_INSTR (ins, 0, cv)
    {
      switch (ins->ins_type)
	{
	case IN_PRED:
	  if (subq_comp_func == ins->_.pred.func)
	    {
	      subq_pred_t * subq = (subq_pred_t *) ins->_.pred.cmp;
	      if (!qr_is_local (subq->subp_query))
		return 0;
	    }
	  break;
	case INS_SUBQ:
	  return 0;
	case INS_CALL:
	case INS_CALL_IND:
	    return 0;
	case INS_CALL_BIF:
	  if (bif_uses_index (ins->_.bif.bif))
	    return 0;
	  break;
	}
    }
  END_DO_INSTR
  return 1;
}


dk_set_t
cv_assigned_slots (code_vec_t cv)
{
  state_slot_t ** out;
  dk_set_t res = NULL;
  if (!cv)
    return NULL;
  DO_INSTR (ins, 0, cv)
    {
      switch (ins->ins_type)
	{
	case INS_CALL:
	case INS_CALL_IND:
	case INS_CALL_BIF:
	  if (ins->_.call.ret)
	    dk_set_push (&res, (void*) ins->_.call.ret);
	  break;
	case IN_ARTM_FPTR:
	case IN_ARTM_IDENTITY:
	case IN_ARTM_PLUS: case IN_ARTM_MINUS:
	case IN_ARTM_TIMES: case IN_ARTM_DIV:
	  if (ins->_.artm.result)
	    dk_set_push (&res, (void*) ins->_.artm.result);
	  break;
	case INS_SUBQ:
	  if (ins->_.subq.query && ins->_.subq.query->qr_select_node 
	      && ((out = ins->_.subq.query->qr_select_node->sel_out_slots)))
	    {
	      int inx;
	      DO_BOX (state_slot_t *, ssl, inx, out)
		{
		  if (ssl->ssl_type == SSL_VARIABLE || ssl->ssl_type == SSL_COLUMN)
		    dk_set_push (&res,  (void*) ssl);
		}	      
	      END_DO_BOX;
	    }
	}
    }
  END_DO_INSTR
  return res;
}

static short
cv_find_label (sql_comp_t * sc, dk_hash_t *ht, jmp_label_t label)
{
  short val = (short) (ptrlong) gethash ((void *) (ptrlong) label, ht);
  if (!val)
    sqlc_new_error (sc->sc_cc, "42000", "SQ085", "Reference to undefined label.");

  return (val - 1);
}

static int
cv_calculate_label_nesting_level (sql_comp_t * sc, code_vec_t cv, dk_set_t list, jmp_label_t label)
{
  int nesting_level = 0;
  DO_SET (instruction_t *, ins, &list)
    {
      switch (ins->ins_type)
	{
	  case INS_COMPOUND_START:
	      nesting_level++;
	      break;
	  case INS_COMPOUND_END:
	      nesting_level--;
	      break;
	  case IN_LABEL:
	      if (ins->_.label.label == label)
		return nesting_level;
	      else
		break;
	}
    }
  END_DO_SET();
  sqlc_new_error (sc->sc_cc, "42000", "SQ166", "Reference to undefined label.");
  return 0;
}


static size_t
code_vec_byte_len (dk_set_t code)
{
  size_t len = 0;
  DO_SET (instruction_t *, ins, &code)
    {
      len += ALIGN_INSTR (INS_LEN (ins));
    }
  END_DO_SET();
  return len;
}

code_vec_t
code_to_cv_1 (sql_comp_t * sc, dk_set_t code, int trim_one_long_cv)
{
  /* Resolve labels and convert list to code vector */
  if (code && code->data)
    {
      if (!IS_INS_RET (((instruction_t*) (code->data))->ins_type))
	cv_bret (&code, 0);
      else if (dk_set_length (code) == 1 && trim_one_long_cv)
	code = NULL;
    }
  if (code)
    {
      dk_set_t list;
      size_t byte_len;
      code_vec_t cv;
      instruction_t *dins;
      int nesting_level = 0;
      dk_hash_t *lblhash;
      caddr_t volatile err = NULL;

      list = dk_set_nreverse (code);
      byte_len = code_vec_byte_len (list);
      if (BOFS_TO_OFS (byte_len) > SHRT_MAX)
	{
	  sqlc_new_error (sc->sc_cc, "42000", "SQ199",
	      "Maximum size (%ld) of a code vector exceeded by %ld bytes. "
	      "Please split the code in smaller units.", (long) SHRT_MAX, (long) (byte_len - SHRT_MAX));
	}
      cv = (code_vec_t) dk_alloc_box (byte_len, DV_BIN);
      dins = cv;

      lblhash = hash_table_allocate (BOX_ELEMENTS (cv) / 4);

      DO_SET (instruction_t *, ins, &list)
	{
	  unsigned short ins_len = INS_LEN (ins);

	  if (ins->ins_type == IN_LABEL)
	    {
	      sethash (
		  (void *)(ptrlong) ins->_.label.label,
		  lblhash,
		  (void *)(ptrlong) (INSTR_OFS (dins, cv) + 1));
	    }
	  if (ins_len)
	    {
	      memcpy (dins, ins, ins_len);
	      if (dins->ins_type == INS_FETCH)
		{
		  DO_SET (subq_compilation_t *, sqc, &sc->sc_subq_compilations)
		    {
		      s_node_t *memb = dk_set_member (sqc->sqc_fetches, ins);
		      if (memb)
			memb->data = dins;
		    }
		  END_DO_SET ();
		}
	      dins = INSTR_NEXT (dins);
	    }
	}
      END_DO_SET();
      CATCH (CATCH_LISP_ERROR)
	{
	  DO_INSTR (ins, 0, cv)
	    {
	      switch (ins->ins_type)
		{
		  case IN_PRED:
		      ins->_.pred.succ = cv_find_label (sc, lblhash, ins->_.pred.succ);
		      ins->_.pred.fail = cv_find_label (sc, lblhash, ins->_.pred.fail);
		      ins->_.pred.unkn = cv_find_label (sc, lblhash, ins->_.pred.unkn);
		      break;
		  case IN_COMPARE:
		      ins->_.cmp.succ = cv_find_label (sc, lblhash, ins->_.pred.succ);
		      ins->_.cmp.fail = cv_find_label (sc, lblhash, ins->_.pred.fail);
		      ins->_.cmp.unkn = cv_find_label (sc, lblhash, ins->_.pred.unkn);
		      break;
		  case IN_JUMP:
		      ins->_.label.nesting_level = cv_calculate_label_nesting_level (sc, cv, list, ins->_.label.label);
		      ins->_.label.label = cv_find_label (sc, lblhash, ins->_.label.label);
		      break;

		  case INS_HANDLER:
		      if (ins->_.handler.label != -1)
			ins->_.handler.label = cv_find_label (sc, lblhash, ins->_.handler.label);
		      break;

		  case INS_HANDLER_END:
		      break;

		  case INS_COMPOUND_START:
		      nesting_level++;
		      break;

		  case INS_COMPOUND_END:
		      nesting_level--;
		      break;

		}
	    }
	  END_DO_INSTR;
	}
      THROW_CODE
	{
	  err = (caddr_t) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR);
	}
      END_CATCH;
      hash_table_free (lblhash);
      if (err)
	sqlc_resignal_1 (sc->sc_cc, err);

      return cv;
    }
  else
    return NULL;
}

code_vec_t
code_to_cv (sql_comp_t * sc, dk_set_t code)
{
  return code_to_cv_1 (sc, code, 1);
}

#ifdef PLDBG
void pldbg_break_delete (void * ins);
#endif

void
cv_free (code_vec_t cv)
{
  if (!cv)
    return;
  DO_INSTR (ins, 0, cv)
    {
      if (ins->ins_type == IN_PRED
	  && ins->_.pred.cmp)
	{
	  if (ins->_.pred.func == distinct_comp_func)
	    {
	      ha_free ((hash_area_t *) ins->_.pred.cmp);
	    }
	  else
	    dk_free ((box_t) ins->_.pred.cmp, -1);
	}
      else if (ins->ins_type == INS_CALL
	       || ins->ins_type == INS_CALL_IND)
	{
	  dk_free_box (ins->_.call.proc);
	  dk_free_box ((caddr_t) ins->_.call.params);
	  dk_free_tree ((caddr_t) ins->_.call.kwds);
	  proc_name_free (ins->_.call.pn);
	}
      else if (ins->ins_type == INS_CALL_BIF)
	{
	  dk_free_box (ins->_.bif.proc);
	  dk_free_box ((caddr_t) ins->_.bif.params);
	}      else if (ins->ins_type == INS_HANDLER)
	{
	  dk_free_tree ((box_t) ins->_.handler.states);
	}
      else if (ins->ins_type == INS_COMPOUND_START)
	{
	  dk_free_box (ins->_.compound_start.file_name);
	}
#ifdef PLDBG
      else if (ins->ins_type == INS_BREAKPOINT)
	{
	  if (ins->_.breakpoint.brk_set)
	    pldbg_break_delete (ins);
	  dk_set_free (ins->_.breakpoint.scope);
	}
#endif
    }
  END_DO_INSTR
  dk_free_box ((caddr_t) cv);
}



state_slot_t *
select_ref_generate (sql_comp_t * sc, ST * tree, dk_set_t * code,
		     dk_set_t * fun_ref_code, int *is_fun_ref)
{

  if (ST_P (tree, FUN_REF))
    {
      state_slot_t *result = NULL;
      jmp_label_t next_fun_ref = 0;
      jmp_label_t is_distinct = 0;
      *is_fun_ref = 1;
      if (!sc->sc_cc->cc_any_result_ind)
	{
	  sc->sc_cc->cc_any_result_ind = cc_new_instance_slot (sc->sc_cc);
	}
      if (tree->_.fn_ref.all_distinct)
	{
	  state_slot_t *arg = scalar_exp_generate (sc, tree->_.fn_ref.fn_arg, fun_ref_code);
	  is_distinct = sqlc_new_label (sc);
	  next_fun_ref = sqlc_new_label (sc);
	  cv_distinct (fun_ref_code, arg, sc, is_distinct, next_fun_ref);
	  cv_label (fun_ref_code, is_distinct);
	}
      switch (tree->_.fn_ref.fn_code)
	{
	case AMMSC_MIN:
	case AMMSC_MAX:
	  {
	    state_slot_t *best = ssl_new_inst_variable (sc->sc_cc, "best", DV_UNKNOWN);
	    state_slot_t *arg = scalar_exp_generate (sc, tree->_.fn_ref.fn_arg, fun_ref_code);
	    jmp_label_t end = sqlc_new_label (sc);
	    jmp_label_t unk = sqlc_new_label (sc);
	    jmp_label_t better = sqlc_new_label (sc);

	    dk_set_push (&sc->sc_fun_ref_temps, (void *) best);

	    sc->sc_fun_ref_defaults = NCONC (sc->sc_fun_ref_defaults, CONS (dk_alloc_box (0, DV_DB_NULL), NULL));
	    sc->sc_fun_ref_default_ssls = NCONC (sc->sc_fun_ref_default_ssls, CONS (best, NULL));

	    cv_compare (fun_ref_code, tree->_.fn_ref.fn_code == AMMSC_MAX ? BOP_LT : BOP_GT,
		best, arg, better, end, unk);

	    cv_label (fun_ref_code, unk);
	    cv_compare (fun_ref_code, BOP_NULL, arg, NULL, end, better, end);

	    cv_label (fun_ref_code, better);
	    cv_artm (fun_ref_code, box_identity, best, arg, NULL);
	    cv_label (fun_ref_code, end);
	    result = best;
	    break;
	  }

	case AMMSC_SUM:
	case AMMSC_COUNTSUM:
	  {
	    state_slot_t * arg = scalar_exp_generate (sc, tree->_.fn_ref.fn_arg, fun_ref_code);
	    int is_constant_arg = arg && arg->ssl_type == SSL_CONSTANT;
	    state_slot_t *sum;
	    if (tree->_.fn_ref.fn_code == AMMSC_SUM)
	      sum = ssl_new_inst_variable (sc->sc_cc, "sum", DV_UNKNOWN);
	    else
	      sum = ssl_new_inst_variable (sc->sc_cc, "count", DV_UNKNOWN);
	    dk_set_push (&sc->sc_fun_ref_temps, (void *) sum);
	    if (tree->_.fn_ref.fn_code == AMMSC_SUM)
	      sc->sc_fun_ref_defaults = NCONC (sc->sc_fun_ref_defaults,
		  CONS (dk_alloc_box (0, DV_DB_NULL), NULL));
	    else
	      sc->sc_fun_ref_defaults = NCONC (sc->sc_fun_ref_defaults,
		  CONS (box_num (0), NULL));
	    sc->sc_fun_ref_default_ssls = NCONC (sc->sc_fun_ref_default_ssls, CONS (sum, NULL));
	    if (!is_constant_arg)
	      {
		jmp_label_t nosum = sqlc_new_label (sc);
		jmp_label_t dosum = sqlc_new_label (sc);
		jmp_label_t doset = sqlc_new_label (sc);
		jmp_label_t dosum_real = !is_constant_arg ? sqlc_new_label (sc) : 0;
		cv_compare (fun_ref_code, BOP_NULL, arg, NULL, nosum, dosum, nosum);

		cv_label (fun_ref_code, dosum);
		cv_compare (fun_ref_code, BOP_NULL, sum, NULL, doset, dosum_real, nosum);

		cv_label (fun_ref_code, doset);
		cv_artm (fun_ref_code, box_identity, sum, arg, NULL);
		cv_jump (fun_ref_code, nosum);

		cv_label (fun_ref_code, dosum_real);
		cv_artm (fun_ref_code, box_add, sum, sum, arg);
		cv_label (fun_ref_code, nosum);
	      }
	    else
	      {
		if (arg->ssl_dtp != DV_DB_NULL)
		  cv_artm (fun_ref_code, box_add, sum, sum, arg);
	      }
	    result = sum;
	    break;
	  }

	case AMMSC_COUNT:
	  {
	    state_slot_t *count = ssl_new_inst_variable (sc->sc_cc, "count", DV_LONG_INT);
	    dk_set_push (&sc->sc_fun_ref_temps, (void *) count);
	    if (!tree->_.fn_ref.all_distinct)
	      sc->sc_fun_ref_defaults = NCONC (sc->sc_fun_ref_defaults, CONS (box_num (-1), NULL));
	    else
	      sc->sc_fun_ref_defaults = NCONC (sc->sc_fun_ref_defaults, CONS (box_num (0), NULL));
	    sc->sc_fun_ref_default_ssls = NCONC (sc->sc_fun_ref_default_ssls, CONS (count, NULL));
	    if (tree->_.fn_ref.all_distinct)
	      cv_artm (fun_ref_code, box_add, count, count, ssl_new_constant (sc->sc_cc, box_num (1)));
	    result = count;
	    break;
	  }

	case AMMSC_AVG:
	  {
	    state_slot_t * arg = scalar_exp_generate (sc, tree->_.fn_ref.fn_arg, fun_ref_code);
	    jmp_label_t some = sqlc_new_label (sc);
	    jmp_label_t done = sqlc_new_label (sc);
	    jmp_label_t avgsum = sqlc_new_label (sc);
	    jmp_label_t noavg = sqlc_new_label (sc);
	    caddr_t deflt;
	    state_slot_t *sum = ssl_new_inst_variable (sc->sc_cc, "sum", DV_UNKNOWN);
	    state_slot_t *count = ssl_new_inst_variable (sc->sc_cc, "count", DV_UNKNOWN);
	    deflt = dk_alloc_box (0, DV_DB_NULL);
	    sc->sc_fun_ref_defaults = NCONC (sc->sc_fun_ref_defaults, CONS (deflt, NULL));
	    sc->sc_fun_ref_default_ssls = NCONC (sc->sc_fun_ref_default_ssls, CONS (sum, NULL));
	    dk_set_push (&sc->sc_fun_ref_temps, (void *) count);
	    dk_set_push (&sc->sc_fun_ref_temps, (void *) sum);

	    cv_compare (fun_ref_code, BOP_NULL, arg, NULL, noavg,  avgsum, noavg);
	    cv_label (fun_ref_code, avgsum);
	    cv_artm (fun_ref_code, box_add, count, count, ssl_new_constant (sc->sc_cc, (caddr_t) 1L));
	    cv_artm (fun_ref_code, box_add, sum, sum, arg);
	    cv_label (fun_ref_code, noavg);
	    cv_compare (code, BOP_EQ, count, ssl_new_constant (sc->sc_cc, t_box_num (0)), done, some, done);
	    cv_label (code, some);
	    cv_artm (code, box_div, sum, sum, count);
	    cv_label (code, done);
	    result = sum;
	    break;
	  }

	case AMMSC_USER:
	  {
	    state_slot_t *const_short_1 = ssl_new_constant (sc->sc_cc, (caddr_t) 1L);
	    user_aggregate_t *ua = (user_aggregate_t *)(unbox_ptrlong (tree->_.fn_ref.user_aggr_addr));
	    int argidx;
	    jmp_label_t setenv_begin = sqlc_new_label (sc);
	    jmp_label_t setenv_end = sqlc_new_label (sc);

	    state_slot_t *flag = ssl_new_inst_variable (sc->sc_cc, "user_aggr_notfirst", DV_SHORT_INT);
	    state_slot_t *env = ssl_new_inst_variable (sc->sc_cc, "user_aggr_env", DV_UNKNOWN);
	    state_slot_t *ret = ssl_new_inst_variable (sc->sc_cc, "user_aggr_ret", DV_UNKNOWN);
	    caddr_t deflt_env;
	    state_slot_t ** acc_args = (state_slot_t **) dk_alloc_box (sizeof (state_slot_t *) * (1 + BOX_ELEMENTS(tree->_.fn_ref.fn_arglist)), DV_ARRAY_OF_POINTER);

	    acc_args[0] = env;
	    const_short_1->ssl_dtp = DV_SHORT_INT;
	    DO_BOX_FAST (ST *, arg_st, argidx, tree->_.fn_ref.fn_arglist)
	      {
		acc_args[argidx+1] = scalar_exp_generate (sc, arg_st, fun_ref_code);
	      }
	    END_DO_BOX_FAST;
	    deflt_env = NEW_DB_NULL;
	    sc->sc_fun_ref_defaults = NCONC (sc->sc_fun_ref_defaults, CONS (deflt_env, NULL));
	    sc->sc_fun_ref_default_ssls = NCONC (sc->sc_fun_ref_default_ssls, CONS (env, NULL));
	    dk_set_push (&sc->sc_fun_ref_temps, (void *) env);
	    dk_set_push (&sc->sc_fun_ref_temps, (void *) flag);
	    cv_compare (fun_ref_code, BOP_EQ, flag, const_short_1,
	      setenv_end, setenv_begin, setenv_begin);
	    cv_label (fun_ref_code, setenv_begin);
	    cv_artm (fun_ref_code, box_identity, flag, const_short_1, NULL);
	    cv_call (fun_ref_code, NULL, ua->ua_init.uaf_name, ret, (state_slot_t **) /*list*/ sc_list (1, env));
	    cv_label (fun_ref_code, setenv_end);
	    cv_call (fun_ref_code, NULL, ua->ua_acc.uaf_name, ret, acc_args);
	    result = env;
	    break;
	  }

	}
      if (next_fun_ref)
	{
	  cv_label (fun_ref_code, next_fun_ref);

	}
      return (result);
    }
  else
    {
      state_slot_t *out;
      *is_fun_ref = 0;
      sc->sc_temp_in_qst = 1;
      out = (scalar_exp_generate (sc, tree, code));
      sc->sc_temp_in_qst = 0;
      return out;
    }
}
