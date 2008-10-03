/*
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2008 OpenLink Software
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

#include "sparql2sql.h"
#include "sqlparext.h"
#include "arith.h"
#include "sqlcmps.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "sparql_p.h"
#ifdef __cplusplus
}
#endif
#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser.h"
#include "xmlparser_impl.h"
#ifdef __cplusplus
}
#endif
#include "xml_ecm.h"

/* ROUTINES FOR SPART TREE TRAVERSAL */

int
sparp_gp_trav_int (sparp_t *sparp, SPART *tree,
  sparp_trav_state_t *sts_this, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 )
{
  SPART **sub_gps = NULL;
  SPART **sub_expns = NULL;
  SPART *fields[2];
  int tree_type;
  int sub_gp_count = 0, sub_expn_count = 0, ctr;
  int tree_cat = 0;
  int in_rescan = 0;
  void *save_sts_this = BADBEEF_BOX; /* To keep gcc 4.0 happy */
  int retcode = 0;
  if (sts_this == (sparp->sparp_stss + SPARP_MAX_SYNTDEPTH))
    spar_error (sparp, "The nesting depth of subexpressions exceed limits of SPARQL compiler");

scan_for_children:
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    {
      tree_type = SPAR_LIT;
      tree_cat = 2;
      goto cat_recognized;
    }
  tree_type = tree->type;
  switch (tree_type)
    {
    case SPAR_LIT:
    case SPAR_QNAME:
    /*case SPAR_QNAME_NS:*/
      {
        tree_cat = 2;
        break;
      }
    case SPAR_ALIAS:
      {
        tree_cat = 1;
        sub_expns = &(tree->_.alias.arg);
        sub_expn_count = 1;
        break;
      }
    case SPAR_BLANK_NODE_LABEL:
    case SPAR_VARIABLE:
      {
	tree_cat = 1;
	break;
      }
    case SPAR_BUILT_IN_CALL:
      {
        tree_cat = 1;
        sub_expns = tree->_.builtin.args;
	sub_expn_count = BOX_ELEMENTS (sub_expns);
        break;
      }
    case SPAR_FUNCALL:
      {
        tree_cat = 1;
        sub_expns = tree->_.funcall.argtrees;
	sub_expn_count = BOX_ELEMENTS (sub_expns);
        break;
      }
    case SPAR_GP:
      {
        tree_cat = 0;
        sub_gps = tree->_.gp.members;
	sub_gp_count = BOX_ELEMENTS (sub_gps);
        sub_expns = tree->_.gp.filters;
	sub_expn_count = BOX_ELEMENTS (sub_expns);
        break;
      }
    case SPAR_REQ_TOP:
      spar_internal_error (sparp, "TOP of request as subexpression");
    case SPAR_TRIPLE:
      {
        tree_cat = 0;
        sub_expns = tree->_.triple.tr_fields;
	sub_expn_count = SPART_TRIPLE_FIELDS_COUNT;
        break;
      }
    case SPAR_LIST:
      {
        sub_expns = tree->_.list.items;
	sub_expn_count = BOX_ELEMENTS (sub_expns);
        break;
      }
    case BOP_EQ: case BOP_NEQ:
    case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
    /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! BTW, 'IN' is also BOP */
    case BOP_SAME: case BOP_NSAME:
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
    case BOP_AND: case BOP_OR:
      {
        tree_cat = 1;
        sub_expns = fields;
	sub_expn_count = 2;
        fields[0] = tree->_.bin_exp.left;
        fields[1] = tree->_.bin_exp.right;
        break;
      }
    case BOP_NOT:
      {
        tree_cat = 1;
        sub_expns = fields;
	sub_expn_count = 1;
        fields[0] = tree->_.bin_exp.left;
        break;
      }
    case ORDER_L:
      {
        sub_expns = fields;
	sub_expn_count = 1;
        fields[0] = tree->_.oby.expn;
        break;
      }
    default:
      {
        spar_internal_error (sparp, "Internal SPARQL compiler error: unsupported subexpression type");
        break;
      }
    }

cat_recognized:
  if (in_rescan)
    goto process_children; /* See below */
  switch (tree_cat)
    {
    case 0:
      if (gp_in_cbk)
	retcode = gp_in_cbk (sparp, tree, sts_this, common_env);
      else
        retcode = 0;
      break;
    case 1:
      if (expn_in_cbk)
	retcode = expn_in_cbk (sparp, tree, sts_this, common_env);
      else
        retcode = 0;
      break;
    case 2:
      if (literal_cbk)
        {
	  retcode = literal_cbk (sparp, tree, sts_this, common_env);
          return retcode;
        }
      return 0;
    default: GPF_T;
    }
  if (retcode & SPAR_GPT_COMPLETED)
    return SPAR_GPT_COMPLETED;
  save_sts_this = sts_this;
  if (retcode & SPAR_GPT_NODOWN)
    goto end_process_children;
  if (retcode & SPAR_GPT_ENV_PUSH)
    {
      sts_this++;
      memset (sts_this, 0, sizeof (sparp_trav_state_t));
      sts_this->sts_ancestor_gp = sts_this[-1].sts_ancestor_gp;
    }
  if (retcode & SPAR_GPT_RESCAN)
    {
      in_rescan = 1;
      goto scan_for_children; /* see above */
    }

process_children:
  if (SPAR_GP == tree_type)
    sts_this->sts_ancestor_gp = tree;
  /*else
    sts_this->sts_ancestor_gp = sts_this[-1].sts_ancestor_gp;*/
  for (ctr = 0; ctr < sub_gp_count; ctr++)
    {
      sts_this->sts_parent = tree;
      sts_this->sts_curr_array = sub_gps;
      sts_this->sts_ofs_of_curr_in_array = ctr;
      retcode = sparp_gp_trav_int (sparp, sub_gps[ctr], sts_this, common_env,
        gp_in_cbk, gp_out_cbk,
        expn_in_cbk, expn_out_cbk, expn_subq_cbk,
        literal_cbk );
      if (retcode & SPAR_GPT_COMPLETED)
        return SPAR_GPT_COMPLETED;
    }
  if (sub_expn_count && (
      (NULL != expn_in_cbk) || (NULL != expn_out_cbk) || (NULL != expn_subq_cbk) ||
      (NULL != literal_cbk) ) )
    {
      for (ctr = 0; ctr < sub_expn_count; ctr++)
        {
          SPART *sub_expn = sub_expns[ctr];
          sts_this->sts_parent = tree;
          sts_this->sts_curr_array = sub_expns;
          sts_this->sts_ofs_of_curr_in_array = ctr;
          if (SPAR_GP == SPART_TYPE (sub_expn))
            {
              if (NULL != expn_subq_cbk)
                retcode = expn_subq_cbk (sparp, sub_expn, sts_this, common_env);
              else
                retcode = 0;
            }
          else
            retcode = sparp_gp_trav_int (sparp, sub_expn, sts_this, common_env,
              gp_in_cbk, gp_out_cbk,
              expn_in_cbk, expn_out_cbk, expn_subq_cbk,
              literal_cbk );
          if (retcode & SPAR_GPT_COMPLETED)
            return SPAR_GPT_COMPLETED;
        }
    }

end_process_children:
  /*if (SPAR_GP == tree_type)
    sts_this->sts_ancestor_gp = tree; */
  if (retcode & SPAR_GPT_NOOUT)
    return (retcode & SPAR_GPT_COMPLETED);
  switch (tree_cat)
    {
    case 0:
      if (gp_out_cbk)
	retcode = gp_out_cbk (sparp, tree, save_sts_this, common_env);
      else
        retcode = 0;
      break;
    case 1:
      if (expn_out_cbk)
	retcode = expn_out_cbk (sparp, tree, save_sts_this, common_env);
      else
        retcode = 0;
      break;
    }
  if (retcode & SPAR_GPT_COMPLETED)
    return SPAR_GPT_COMPLETED;
  return 0;
}

int
sparp_trav_out_clauses_int (sparp_t *sparp, SPART *req_top,
  sparp_trav_state_t *sts_this, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 )
{
  SPART **lists[4];
  int list_ctr;
  int retcode = 0;
  if (SPAR_REQ_TOP != SPART_TYPE (req_top))
    GPF_T1 ("sparp_" "trav_out_clauses_int(): bad req_top");
  lists[0] = req_top->_.req_top.orig_retvals;
  lists[1] = req_top->_.req_top.retvals;
  lists[2] = req_top->_.req_top.groupings;
  lists[3] = req_top->_.req_top.order;
  for (list_ctr = 0; list_ctr < 4; list_ctr++)
    {
      SPART **list = lists [list_ctr];
      int ctr;
      DO_BOX_FAST (SPART *, expn, ctr, list)
        {
          if (SPAR_GP == SPART_TYPE (expn))
            retcode = ((NULL != expn_subq_cbk) ? expn_subq_cbk (sparp, expn, sts_this, common_env) : 0);
          else retcode = sparp_gp_trav_int (sparp, expn, sts_this, common_env,
            gp_in_cbk, gp_out_cbk,
            expn_in_cbk, expn_out_cbk, expn_subq_cbk,
            literal_cbk );
          if (retcode & SPAR_GPT_COMPLETED)
            return retcode;
        }
      END_DO_BOX_FAST;
    }
  return 0;
}

int
sparp_gp_trav (sparp_t *sparp, SPART *tree, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk )
{
  return sparp_gp_trav_1 (sparp, sparp_gp_trav_int, tree, common_env,
    gp_in_cbk, gp_out_cbk,
    expn_in_cbk, expn_out_cbk, expn_subq_cbk,
    literal_cbk );
}

int
sparp_trav_out_clauses (sparp_t *sparp, SPART *root, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk )
{
  return sparp_gp_trav_1 (sparp, sparp_trav_out_clauses_int, root, common_env,
    gp_in_cbk, gp_out_cbk,
    expn_in_cbk, expn_out_cbk, expn_subq_cbk,
    literal_cbk );
}

int
sparp_gp_trav_1 (sparp_t *sparp, sparp_gp_trav_int_t *intcall, SPART *root, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 )
{
  int res;
  sparp_trav_params_t stp;
  sparp_trav_state_t stss[SPARP_MAX_SYNTDEPTH+2];
  if (sparp->sparp_trav_running)
    spar_internal_error (sparp, "sparp_" "gp_trav_1() re-entered");
  sparp->sparp_trav_running = 1;
  stp.stp_gp_in_cbk = gp_in_cbk;
  stp.stp_gp_out_cbk = gp_out_cbk;
  stp.stp_expn_in_cbk = expn_in_cbk;
  stp.stp_expn_out_cbk = expn_out_cbk;
  stp.stp_expn_subq_cbk = expn_subq_cbk;
  stp.stp_literal_cbk = literal_cbk;
#ifndef NDEBUG
  if (NULL != sparp->sparp_stp)
    spar_internal_error (sparp, "sparp_" "gp_trav_1() has non-NULL sparp_stp");
#endif
  sparp->sparp_stp = &stp;
  memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
  stss[0].sts_parent = NULL;
  stss[0].sts_curr_array = NULL;
  stss[0].sts_ofs_of_curr_in_array = -1;
  sparp->sparp_stss = stss;
  res = intcall (sparp, root, sparp->sparp_stss + 1, common_env,
    gp_in_cbk, gp_out_cbk,
    expn_in_cbk, expn_out_cbk, expn_subq_cbk,
    literal_cbk );
  sparp->sparp_stp = NULL;
  sparp->sparp_stss = NULL;
  sparp->sparp_trav_running = 0;
  return (res & SPAR_GPT_COMPLETED);
}


void sparp_gp_trav_suspend (sparp_t *sparp)
{
  sparp_env_t *env = sparp->sparp_env;
  if (env->spare_gp_trav_is_saved)
    spar_internal_error (sparp, "sparp_" "gp_trav_suspend() is called twice for same spare");
  if (!sparp->sparp_trav_running)
    spar_internal_error (sparp, "sparp_" "gp_trav_suspend() outside sparp_ " "gp_trav()");
  env->spare_saved_stp = sparp->sparp_stp;
  env->spare_saved_stss = sparp->sparp_stss;
  env->spare_gp_trav_is_saved = 1;
#ifndef NDEBUG
  sparp->sparp_stp = NULL;
  sparp->sparp_stss = NULL;
#endif
  sparp->sparp_trav_running = 0;
}

void sparp_gp_trav_resume (sparp_t *sparp)
{
  sparp_env_t *env = sparp->sparp_env;
  if (!env->spare_gp_trav_is_saved)
    spar_internal_error (sparp, "sparp_" "gp_trav_resume() is called without sparp_" "gp_trav_suspend()");
  sparp->sparp_stp = env->spare_saved_stp;
  sparp->sparp_stss = env->spare_saved_stss;
  sparp->sparp_trav_running = 1;
#ifndef NDEBUG
  env->spare_saved_stp = NULL;
  env->spare_saved_stss = NULL;
#endif
  env->spare_gp_trav_is_saved = 0;
}

sparp_t *
sparp_down_to_sub (sparp_t *sparp, SPART *subq_gp_wrapper)
{
  SPART *subq;
  sparp_t *sub_sparp;
  if ((SPAR_GP != SPART_TYPE (subq_gp_wrapper)) || (SELECT_L != subq_gp_wrapper->_.gp.subtype))
    GPF_T1("sparp_" "down_to_sub (): bad subq_gp_wrapper");
  subq = subq_gp_wrapper->_.gp.subquery;
  sparp_gp_trav_suspend (sparp);
  sub_sparp = (sparp_t *)t_box_copy ((caddr_t)sparp);
  sub_sparp->sparp_expr = subq;
  sub_sparp->sparp_env = subq->_.req_top.shared_spare;
  sub_sparp->sparp_parent_sparp = sparp;
  return sub_sparp;
}

void
sparp_up_from_sub (sparp_t *sparp, SPART *subq_gp_wrapper, sparp_t *sub_sparp)
{
  sparp_gp_trav_resume (sparp);
  subq_gp_wrapper->_.gp.subquery = sub_sparp->sparp_expr;
  sparp->sparp_equivs = sub_sparp->sparp_equivs;
  sparp->sparp_equiv_count = sub_sparp->sparp_equiv_count;
  sparp->sparp_cloning_serial = sub_sparp->sparp_cloning_serial;
}

void
sparp_continue_gp_trav_in_sub (sparp_t *sparp, SPART *subq_gp_wrapper, void *common_env)
{
  sparp_trav_params_t *stp = sparp->sparp_stp; /* This is done before sparp_down_to_sub() because it suspends and move the sparp_stp to spare */
  sparp_t *sub_sparp = sparp_down_to_sub (sparp, subq_gp_wrapper);
  sparp_gp_trav (sub_sparp, subq_gp_wrapper->_.gp.subquery->_.req_top.pattern, common_env,
    SPARP_GP_TRAV_CALLBACK_ARGS(stp[0]) );
  sparp_up_from_sub (sparp, subq_gp_wrapper, sub_sparp);
}

void
sparp_gp_localtrav_treelist (sparp_t *sparp, SPART **treelist,
  void *init_stack_env, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 )
{
  int ctr;
  sparp_trav_state_t stss [SPARP_MAX_SYNTDEPTH+2];
  memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
  stss[0].sts_env = init_stack_env;
  stss[1].sts_curr_array = treelist;
  DO_BOX_FAST (SPART *, tree, ctr, treelist)
    {
      stss[1].sts_ofs_of_curr_in_array = ctr;
      sparp_gp_trav_int (sparp, tree, stss+1, common_env,
        gp_in_cbk, gp_out_cbk,
        expn_in_cbk, expn_out_cbk, expn_subq_cbk,
        literal_cbk );
    }
  END_DO_BOX_FAST;
}

/* EQUIVALENCE CLASSES */

sparp_equiv_t *
sparp_equiv_alloc (sparp_t *sparp)
{
  ptrlong eqcount = sparp->sparp_equiv_count;
  sparp_equiv_t **eqs = sparp->sparp_equivs;
  sparp_equiv_t *res;
  if (eqcount >= 0x10000)
    {
      if (NULL == sparp->sparp_env->spare_storage_name)
        spar_internal_error (sparp, "The SPARQL optimizer has failed to process the query with reasonable quality. The resulting SQL query is abnormally long. Please paraphrase the SPARQL query.");
      else
        spar_error (sparp, "The query is prohibitively ineffecient if it should be exectuted on storage <%s>. Please optimize your mappings of relational data to RDF or paraphrase the SPARQL query.", sparp->sparp_env->spare_storage_name);
    }
  res = (sparp_equiv_t *)t_alloc_box (sizeof (sparp_equiv_t), DV_ARRAY_OF_POINTER);
  memset (res, 0, sizeof (sparp_equiv_t));
  if (BOX_ELEMENTS_INT_0 (eqs) == eqcount)
    {
      size_t new_size = ((NULL == eqs) ? 4 * sizeof (sparp_equiv_t *) : 2 * box_length (eqs));
      sparp_equiv_t **new_eqs = (sparp_equiv_t **)t_alloc_box (new_size, DV_ARRAY_OF_POINTER);
      if (NULL != eqs)
        memcpy (new_eqs, eqs, box_length (eqs));
#ifdef DEBUG
      if (NULL != eqs)
        memset (eqs, -1, box_length (eqs));
#endif
      sparp->sparp_equivs = eqs = new_eqs;
    }
  res->e_own_idx = eqcount;
#ifdef DEBUG
  res->e_clone_idx = (SPART_BAD_EQUIV_IDX-1);
#endif
  res->e_merge_dest_idx = SPART_BAD_EQUIV_IDX;
  res->e_external_src_idx = SPART_BAD_EQUIV_IDX;
  eqs[eqcount++] = res;
  sparp->sparp_equiv_count = eqcount;
  return res;
}  

sparp_equiv_t *
sparp_equiv_get (sparp_t *sparp, SPART *haystack_gp, SPART *needle_var, int flags)
{
  ptrlong *eq_idxs;
  sparp_equiv_t *curr_eq;
  SPART **curr_vars;
  caddr_t needle_var_name;
  int eqctr, eqcount;
  int varctr, varcount;
  int varnamectr, varnamecount;

  eqcount = haystack_gp->_.gp.equiv_count;
  eq_idxs = haystack_gp->_.gp.equiv_indexes;
#ifdef DEBUG
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &sparp, 1000))
    spar_internal_error (NULL, "sparp_equiv_get(): stack overflow");
  switch (SPART_TYPE(needle_var))
    {
    case SPAR_VARIABLE: break;
    case SPAR_BLANK_NODE_LABEL: break;
    case SPAR_LIT:
      if (flags & SPARP_EQUIV_INS_VARIABLE)
        spar_internal_error (sparp, "sparp_" "equiv_get() with SPARP_EQUIV_INS_VARIABLE needs SPART * as needle_var");
      if (
        (flags & SPARP_EQUIV_GET_NAMESAKES) &&
        ((DV_STRING == DV_TYPE_OF (needle_var)) || (DV_UNAME == DV_TYPE_OF (needle_var))) )
        break;
    default: spar_internal_error (sparp, "sparp_" "equiv_get() with non-variable SPART *needle_var"); break;
    }
  if ((flags & SPARP_EQUIV_INS_VARIABLE) && strcmp (needle_var->_.var.selid, haystack_gp->_.gp.selid))
    spar_internal_error (sparp, "sparp_" "equiv_get() with SPARP_EQUIV_INS_VARIABLE and wrong selid");
#endif
  needle_var_name = (
    ((DV_STRING == DV_TYPE_OF (needle_var)) || (DV_UNAME == DV_TYPE_OF (needle_var))) ?
    ((caddr_t)(needle_var)) : spar_var_name_of_ret_column (needle_var) );
#ifndef NDEBUG
  if (!IS_BOX_POINTER (needle_var_name))
    GPF_T;
#endif
#ifdef DEBUG
  if (BOX_ELEMENTS_INT_0 (eq_idxs) < eqcount)
    spar_internal_error (sparp, "gp.equivs overflow");
#endif
  for (eqctr = 0; eqctr < eqcount; eqctr++)
    {
      curr_eq = SPARP_EQUIV (sparp, eq_idxs[eqctr]);
      varnamecount = BOX_ELEMENTS (curr_eq->e_varnames);
      for (varnamectr = 0; varnamectr < varnamecount; varnamectr++)
        {
#ifndef NDEBUG
          if (!IS_BOX_POINTER (curr_eq->e_varnames[varnamectr]))
            GPF_T;
#endif
          if (!strcmp (curr_eq->e_varnames[varnamectr], needle_var_name))
            {
              goto namesake_found; /* see below */
            }
        }
    }
  if (! (SPARP_EQUIV_INS_CLASS & flags))
    goto retnull;
  curr_eq = sparp_equiv_alloc (sparp);
  curr_eq->e_gp = haystack_gp;
  if (BOX_ELEMENTS_INT_0 (eq_idxs) == eqcount)
    {
      size_t new_size = ((NULL == eq_idxs) ? 4 * sizeof (ptrlong) : 2 * box_length (eq_idxs));
      ptrlong *new_eq_idxs = (ptrlong *)t_alloc_box (new_size, DV_ARRAY_OF_LONG);
      if (NULL != eq_idxs)
        memcpy (new_eq_idxs, eq_idxs, box_length (eq_idxs));
      haystack_gp->_.gp.equiv_indexes = eq_idxs = new_eq_idxs;
    }
  eq_idxs[eqcount++] = curr_eq->e_own_idx;
  haystack_gp->_.gp.equiv_count = eqcount;
  curr_eq->e_varnames = t_list (1, needle_var_name);
  if (SPARP_EQUIV_INS_VARIABLE & flags)
    {
      curr_eq->e_vars = (SPART **)t_list (2, needle_var, NULL);
      needle_var->_.var.equiv_idx = curr_eq->e_own_idx;
      curr_eq->e_var_count = 1;
      if (SPARP_EQUIV_ADD_GPSO_USE & flags)
        curr_eq->e_gspo_uses++;
      if (SPARP_EQUIV_ADD_CONST_READ & flags)
        curr_eq->e_const_reads++;
      if (SPARP_EQUIV_ADD_SUBQUERY_USE & flags)
        spar_internal_error (sparp, "SPARP_EQUIV_INS_VARIABLE conflicts with SPARP_EQUIV_ADD_SUBQUERY_USE");
    }
  else
    {
      curr_eq->e_vars = (SPART **)t_list (1, NULL);
      curr_eq->e_var_count = 0;
      if (SPARP_EQUIV_ADD_SUBQUERY_USE & flags)
        curr_eq->e_subquery_uses++;
      if (SPARP_EQUIV_ADD_OPTIONAL_READ & flags)
        curr_eq->e_optional_reads++;
    }
#ifdef SPARQL_DEBUG
  sparp_dbg_gp_print (sparp, haystack_gp);
#endif
  return curr_eq;

namesake_found:
  if (SPARP_EQUIV_GET_NAMESAKES & flags)
    return curr_eq;
  curr_vars = curr_eq->e_vars;
  varcount = curr_eq->e_var_count;
  for (varctr = 0; varctr < varcount; varctr++)
    {
      if (curr_vars[varctr] == needle_var)
        return curr_eq;
    }
  if (! (SPARP_EQUIV_INS_VARIABLE & flags))
    goto retnull;
  if (BOX_ELEMENTS_INT (curr_vars) == varcount)
    {
      SPART **new_vars = (SPART **)t_alloc_box (2 * box_length (curr_vars), DV_ARRAY_OF_POINTER);
      memcpy (new_vars, curr_vars, box_length (curr_vars));
#ifdef DEBUG
      memset (curr_vars, -1, box_length (curr_vars));
#endif
      curr_eq->e_vars = curr_vars = new_vars;
    }
  if (SPARP_EQUIV_ADD_GPSO_USE & flags)
    curr_eq->e_gspo_uses++;
  if (SPARP_EQUIV_ADD_CONST_READ & flags)
    curr_eq->e_const_reads++;
  curr_vars[varcount++] = needle_var;
  needle_var->_.var.equiv_idx = curr_eq->e_own_idx;
  curr_eq->e_var_count = varcount;
#ifdef SPARQL_DEBUG
  sparp_dbg_gp_print (sparp, haystack_gp);
#endif
  return curr_eq;

retnull:
  if (SPARP_EQUIV_GET_ASSERT & flags)
    spar_internal_error (sparp, "sparp_" "equiv_get(): attempt of returning NULL when SPARP_EQUIV_GET_ASSERT & flags");
  return NULL;
}

sparp_equiv_t *
sparp_equiv_get_ro (sparp_equiv_t **equivs, ptrlong equiv_count, SPART *haystack_gp, SPART *needle_var, int flags)
{
  ptrlong *eq_idxs;
  sparp_equiv_t *curr_eq;
  SPART **curr_vars;
  caddr_t needle_var_name;
  int eqctr, eqcount;
  int varctr, varcount;
  int varnamectr, varnamecount;

  eqcount = haystack_gp->_.gp.equiv_count;
  eq_idxs = haystack_gp->_.gp.equiv_indexes;
#ifdef DEBUG
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &equivs, 1000))
    spar_internal_error (NULL, "sparp_equiv_get_ro(): stack overflow");    
  switch (SPART_TYPE(needle_var))
    {
    case SPAR_VARIABLE: break;
    case SPAR_BLANK_NODE_LABEL: break;
    case SPAR_RETVAL:
      if (flags & SPARP_EQUIV_GET_NAMESAKES)
        break;
      spar_internal_error (NULL, "sparp_equiv_get_ro() with SPAR_RETVAL SPART *needle_var and without SPARP_EQUIV_GET_NAMESAKES");
      break;
    case SPAR_LIT:
      if (
        (flags & SPARP_EQUIV_GET_NAMESAKES) &&
        ((DV_STRING == DV_TYPE_OF (needle_var)) || (DV_UNAME == DV_TYPE_OF (needle_var))) )
        break;
    default: spar_internal_error (NULL, "sparp_equiv_get_ro() with non-variable SPART *needle_var"); break;
    }
#endif
  needle_var_name = (
    ((DV_STRING == DV_TYPE_OF (needle_var)) || (DV_UNAME == DV_TYPE_OF (needle_var))) ?
    ((caddr_t)(needle_var)) : needle_var->_.var.vname );
#ifdef DEBUG
  if (BOX_ELEMENTS_INT_0 (eq_idxs) < eqcount)
    spar_internal_error (NULL, "sparp_equiv_get_ro(): gp.equivs overflow");
#endif
  for (eqctr = 0; eqctr < eqcount; eqctr++)
    {
#ifdef DEBUG
      if (eq_idxs[eqctr] >= equiv_count)
        spar_internal_error (NULL, "sparp_equiv_get_ro(): run out out equivs");
#endif
      curr_eq = equivs[eq_idxs[eqctr]];
      varnamecount = BOX_ELEMENTS (curr_eq->e_varnames);
      for (varnamectr = 0; varnamectr < varnamecount; varnamectr++)
        {
          if (!strcmp (curr_eq->e_varnames[varnamectr], needle_var_name))
            {
              goto namesake_found; /* see below */
            }
        }
    }
  goto retnull;

namesake_found:
  if (SPARP_EQUIV_GET_NAMESAKES & flags)
    return curr_eq;
  curr_vars = curr_eq->e_vars;
  varcount = curr_eq->e_var_count;
  for (varctr = 0; varctr < varcount; varctr++)
    {
      if (curr_vars[varctr] == needle_var)
        return curr_eq;
    }

retnull:
  if (SPARP_EQUIV_GET_ASSERT & flags)
    spar_internal_error (NULL, "sparp_equiv_get_ro(): attempt of returning NULL when SPARP_EQUIV_GET_ASSERT & flags");
  return NULL;
}

sparp_equiv_t *
sparp_equiv_get_subvalue_ro (sparp_equiv_t **equivs, ptrlong equiv_count, SPART *haystack_gp, sparp_equiv_t *receiver)
{
  int sub_ctr, sub_len;
  int gp_ctr, gp_len;
  sparp_equiv_t *res = NULL;
  sub_len = BOX_ELEMENTS_INT_0 (receiver->e_subvalue_idxs);
  gp_len = haystack_gp->_.gp.equiv_count;
  for (sub_ctr = 0; sub_ctr < sub_len; sub_ctr++)
    {
      int subeq_idx = receiver->e_subvalue_idxs[sub_ctr];
#ifdef DEBUG
      if (subeq_idx >= equiv_count)
        spar_internal_error (NULL, "sparp_equiv_get_subvalue_ro(): run out out equivs");
#endif
      for (gp_ctr = 0; gp_ctr < gp_len; gp_ctr++)
        {
          if (haystack_gp->_.gp.equiv_indexes[gp_ctr] != subeq_idx)
            continue;
/* The result is either 'good' or 'bad'.
'Good' is one returned from the triple of the gp, hence it's non-NULL for sure.
'Bad' is returned from an underlaying select, hence can be NULL. */
          res = equivs[subeq_idx];
	  if (res->e_var_count > 0)
	    return res; /* Good can be returned immediately. */
        }
    }
  return res; /* Bad, if any, can wait. */
}

/* Returns 1 if connection exists (or added), 0 otherwise. GPFs if tries to add the second up */
int
sparp_equiv_connect (sparp_t *sparp, sparp_equiv_t *outer, sparp_equiv_t *inner, int add_if_missing)
{
  int i_ctr, i_count;
  int o_listed_in_i = 0;
#ifdef DEBUG
  int o_ctr, o_count;
  int i_listed_in_o = 0;
  o_count = BOX_ELEMENTS_0 (outer->e_subvalue_idxs);
  for (o_ctr = o_count; o_ctr--; /* no step */)
    {
      if (outer->e_subvalue_idxs[o_ctr] == inner->e_own_idx)
        {
          i_listed_in_o = 1;
	  break;
	}
    }
#endif
  i_count = BOX_ELEMENTS_0 (inner->e_receiver_idxs);
  for (i_ctr = i_count; i_ctr--; /* no step */)
    {
      if (inner->e_receiver_idxs[i_ctr] == outer->e_own_idx)
        {
          o_listed_in_i = 1;
	  break;
	}
    }
  if (o_listed_in_i)
    {
#ifdef DEBUG
      if (!i_listed_in_o)
        spar_internal_error (sparp, "sparp_" "equiv_connect(): unidirectional link (1) ?");
#endif
      return 2;
    }
#ifdef DEBUG
  if (i_listed_in_o)
    spar_internal_error (sparp, "sparp_" "equiv_connect(): unidirectional link (2) ?");
#endif
  if (!add_if_missing)    
    return 0;
  outer->e_subvalue_idxs = (ptrlong *)t_list_concat_tail ((caddr_t)(outer->e_subvalue_idxs), 1, inner->e_own_idx);
  inner->e_receiver_idxs = (ptrlong *)t_list_concat_tail ((caddr_t)(inner->e_receiver_idxs), 1, outer->e_own_idx);
  if ((0 < inner->e_gspo_uses) || (0 < inner->e_nested_bindings) || (0 < inner->e_subquery_uses))
    outer->e_nested_bindings += 1;
  return 1;
}


/* Returns 1 if connection existed and removed. */
int
sparp_equiv_disconnect (sparp_t *sparp, sparp_equiv_t *outer, sparp_equiv_t *inner)
{
  int o_ctr, o_count, i_ctr, i_count;
  int o_listed_in_i = -1;
  int i_listed_in_o = -1;
  o_count = BOX_ELEMENTS_0 (outer->e_subvalue_idxs);
  for (o_ctr = o_count; o_ctr--; /* no step */)
    {
      if (outer->e_subvalue_idxs[o_ctr] == inner->e_own_idx)
        {
          i_listed_in_o = o_ctr;
	  break;
	}
    }
  i_count = BOX_ELEMENTS_0 (inner->e_receiver_idxs);
  for (i_ctr = i_count; i_ctr--; /* no step */)
    {
      if (inner->e_receiver_idxs[i_ctr] == outer->e_own_idx)
        {
          o_listed_in_i = i_ctr;
	  break;
	}
    }
  if (-1 == o_listed_in_i)
    {
#ifdef DEBUG
      if (-1 != i_listed_in_o)
        spar_internal_error (sparp, "sparp_" "equiv_disconnect(): unidirectional link (1) ?");
#endif
      return 0;
    }
#ifdef DEBUG
  if (-1 == i_listed_in_o)
    spar_internal_error (sparp, "sparp_" "equiv_disconnect(): unidirectional link (2) ?");
#endif
  outer->e_subvalue_idxs = (ptrlong *)t_list_remove_nth ((caddr_t)(outer->e_subvalue_idxs), i_listed_in_o);
  inner->e_receiver_idxs = (ptrlong *)t_list_remove_nth ((caddr_t)(inner->e_receiver_idxs), o_listed_in_i);
  if ((0 < inner->e_gspo_uses) || (0 < inner->e_nested_bindings) || (0 < inner->e_subquery_uses))
    outer->e_nested_bindings -= 1;
  return 1;
}

void
sparp_equiv_remove_var (sparp_t *sparp, sparp_equiv_t *eq, SPART *var)
{
  int namesakes_count = 0;
  int varctr;
  int hit_idx = -1;
  if (NULL == eq)
    {
      int eq_idx = var->_.var.equiv_idx;
      if (SPART_BAD_EQUIV_IDX == eq_idx)
        return;
      if (eq_idx >= sparp->sparp_equiv_count)
        spar_internal_error (sparp, "sparp_" "equiv_remove_var(): eq_idx is too big");
      eq = SPARP_EQUIV (sparp, eq_idx);
      if (NULL == eq)
        spar_internal_error (sparp, "sparp_" "equiv_remove_var(): eq is merged and disabled");
    }
  for (varctr = eq->e_var_count; varctr--; /*no step*/)
    {
      SPART *curr_var = eq->e_vars [varctr];
      if (curr_var == var)
        {
          if (0 <= hit_idx)
            spar_internal_error (sparp, "sparp_" "equiv_remove_var(): duplicate occurrence of var in equiv ?");
          hit_idx = varctr;
        }
      if (!strcmp (curr_var->_.var.vname, var->_.var.vname))
        namesakes_count++;
    }
  if (0 > hit_idx)
    spar_internal_error (sparp, "sparp_" "equiv_remove_var(): var is not in equiv ?");
  if (1 > namesakes_count)
    spar_internal_error (sparp, "sparp_" "equiv_remove_var(): no namesakes of var in equiv ?");
  eq->e_vars[hit_idx] = eq->e_vars[eq->e_var_count - 1];
  eq->e_vars[eq->e_var_count - 1] = NULL;
  eq->e_var_count--;
  var->_.var.equiv_idx = SPART_BAD_EQUIV_IDX;
  if (1 == namesakes_count)
    { /* The name of variable is no longer in explicit use, but it can not be removed from eq.
The reason is that it still may be used to establish relationship between this eq and namesake of the removed variable in other gps.
An example is name "s1" in OPTIONAL clause of  ?s1 ?p1 ?o1 OPTIONAL { ?s2 ?p2 ?o2 . FILTER (?s1 = ?s2) }
When filter is optimized away, the only ?s1 in OPTIONAL disappears but ?s1 outside still should find its namesake in OPTIONAL to not forget ON (s1 = s2) after LEFT OUTER JOIN.
At the same time, the unused name should not appear at the first place of \c e_varnames list because that may result in inaccurate alias in result list.
So it should be reordered in the list in such a way that it will never appear at the first position if there are any better names. */
      int count = BOX_ELEMENTS (eq->e_varnames), ctr;
      for (ctr = count; ctr--; /* no step */)
        {
          if (strcmp (eq->e_varnames [ctr], var->_.var.vname))
            continue;
          while (++ctr < count) eq->e_varnames [ctr-1] = eq->e_varnames [ctr];
          eq->e_varnames [count-1] = var->_.var.vname;
          break;
        }
    }
}

sparp_equiv_t *
sparp_equiv_clone (sparp_t *sparp, sparp_equiv_t *orig, SPART *cloned_gp)
{
  sparp_equiv_t *tgt;
  if (orig->e_cloning_serial == sparp->sparp_cloning_serial)
    spar_internal_error (sparp, "sparp_" "equiv_clone(): can't make second clone of equiv during same gp cloning");
#ifdef DEBUG
  if (orig->e_deprecated)
    spar_internal_error (sparp, "sparp_" "equiv_clone(): weird cloning of deprecated equiv");
#endif
  tgt = sparp_equiv_alloc (sparp);
  orig->e_cloning_serial = sparp->sparp_cloning_serial;
  orig->e_clone_idx = tgt->e_own_idx;
  tgt->e_gp = cloned_gp;
  tgt->e_varnames = (caddr_t *)t_full_box_copy_tree ((caddr_t)(orig->e_varnames));
  tgt->e_vars = (SPART **)t_alloc_box (box_length (orig->e_vars), DV_ARRAY_OF_POINTER); /* no real copying of e_vars */
  /* no copying for e_var_count */
  /* no copying for e_gspo_uses */
  /* no copying for e_nested_bindings */
  /* no copying for e_const_reads */
  /* no copying for e_optional_reads */
  /* no copying for e_subquery_uses */
  sparp_rvr_copy (sparp, &(tgt->e_rvr), &(orig->e_rvr));
  /* no copying for e_subvalue_idxs */
  /* no copying for e_receiver_idxs */
  /* no copying for e_clone_idx */
  /* no copying for e_cloning_serial */
  if (SPART_BAD_EQUIV_IDX != orig->e_external_src_idx)
    {
      sparp_equiv_t *esrc = SPARP_EQUIV(sparp, orig->e_external_src_idx);
      while (SPART_BAD_EQUIV_IDX != esrc->e_merge_dest_idx)
        {
          sparp_equiv_t *merged_esrc = SPARP_EQUIV(sparp, esrc->e_merge_dest_idx);
          esrc = merged_esrc;
        }
      if (esrc->e_cloning_serial == sparp->sparp_cloning_serial)
         tgt->e_external_src_idx = orig->e_external_src_idx;
    }
  tgt->e_merge_dest_idx = orig->e_merge_dest_idx;
#ifdef DEBUG
  /* no copying for e_dbg_saved_gp */
#endif
  /* Add more lines here when more fields added to struct sparp_equiv_s. */
  return tgt;
}

#if 0
sparp_equiv_t *
sparp_equiv_exact_copy (sparp_t *sparp, sparp_equiv_t *orig)
{
  sparp_equiv_t *tgt;
  if (orig->e_cloning_serial == sparp->sparp_cloning_serial)
    spar_internal_error (sparp, "sparp_" "equiv_clone(): can't make second clone of equiv during same gp cloning");
  tgt = (sparp_equiv_t *)t_alloc_box (sizeof (sparp_equiv_t), DV_ARRAY_OF_POINTER);
  memcpy (tgt, orig, sizeof (sparp_equiv_t));
  /* no real copying of e_gp */
  tgt->e_varnames = (caddr_t *)t_full_box_copy_tree ((caddr_t)(orig->e_varnames));
  tgt->e_vars = (SPART **)t_alloc_box (box_length (orig->e_vars), DV_ARRAY_OF_POINTER); /* no real copying of e_vars */
  sparp_rvr_copy (sparp, &(tgt->e_rvr), &(orig->e_rvr));
  tgt->e_subvalue_idxs = (caddr_t *)t_full_box_copy_tree ((caddr_t)(orig->e_subvalue_idxs));
  tgt->e_receiver_idxs = (caddr_t *)t_full_box_copy_tree ((caddr_t)(orig->e_receiver_idxs));
  /* Check if more lines are needed here when more fields added to struct sparp_equiv_s. */
  return tgt;
}
#endif

int
sparp_equiv_restrict_by_constant (sparp_t *sparp, sparp_equiv_t *pri, ccaddr_t datatype, SPART *value)
{
  rdf_val_range_t tmp;  
  sparp_rvr_set_by_constant (sparp, &tmp, datatype, value);
  sparp_rvr_tighten (sparp, &tmp, &(pri->e_rvr), ~0);
  if (tmp.rvrRestrictions & SPART_VARR_CONFLICT)
    return SPARP_EQUIV_MERGE_ROLLBACK;
  sparp_rvr_copy (sparp, &(pri->e_rvr), &tmp);
  return SPARP_EQUIV_MERGE_OK;
}

void sparp_equiv_remove (sparp_t *sparp, sparp_equiv_t *eq)
{
  SPART *eq_gp = eq->e_gp;
  ptrlong eq_own_idx = eq->e_own_idx;
  ptrlong *eq_gp_indexes = eq_gp->_.gp.equiv_indexes;
  int ctr1, len;
#ifdef DEBUG
  if (
    (0 != eq->e_const_reads) ||
    (0 != eq->e_gspo_uses) ||
    (0 != eq->e_subquery_uses) ||
    (0 != eq->e_var_count) ||
    (0 != BOX_ELEMENTS_INT_0 (eq->e_receiver_idxs)) ||
    (0 != BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs)) ||
    (SPART_VARR_EXPORTED & eq->e_rvr.rvrRestrictions) )
    spar_internal_error (sparp, "sparp_" "equiv_remove (): can't remove equiv that is still in use");
  memset (eq, -1, sizeof (sparp_equiv_t));
#endif
  for (ctr1 = len = eq_gp->_.gp.equiv_count; ctr1--; /* no step */)
    {
      if (eq_gp_indexes[ctr1] != eq_own_idx)
        continue;
      eq_gp_indexes[ctr1] = eq_gp_indexes[len-1];
      eq_gp_indexes[len-1] = 0;
      len--;
      goto found_in_gp;
    }
  spar_internal_error (sparp, "sparp_" "equiv_remove (): failed to remove eq from its gp");

found_in_gp:
  sparp->sparp_equivs[eq_own_idx] = NULL;
  eq_gp->_.gp.equiv_count = len;
}

int
sparp_equiv_merge (sparp_t *sparp, sparp_equiv_t *pri, sparp_equiv_t *sec)
{
  int ctr1, ret;
#ifdef DEBUG
  int ctr2;
#endif
  SPART *sec_gp;
  if (pri == sec)
    return SPARP_EQUIV_MERGE_DUPE;
  sparp_equiv_audit_all (sparp, 0);
  sec_gp = sec->e_gp;
#ifdef DEBUG
  if (pri->e_gp != sec_gp)
    spar_internal_error (sparp, "sparp_" "equiv_merge () can not merge equivs from two different gps");
  for (ctr1 = BOX_ELEMENTS_INT_0 (sec->e_varnames); ctr1--; /* no step*/)
    {
      for (ctr2 = BOX_ELEMENTS_INT_0 (pri->e_varnames); ctr2--; /* no step*/)
        {
          if (!strcmp (sec->e_varnames[ctr1], pri->e_varnames[ctr2]))
	    spar_internal_error (sparp, "sparp_" "equiv_merge (): same variable name in two different equivs of same gp");
	}
    }
  for (ctr1 = sec->e_var_count; ctr1--; /* no step*/)
    {
      for (ctr2 = pri->e_var_count; ctr2--; /* no step*/)
        {
          if (sec->e_vars[ctr1] == pri->e_vars[ctr2])
	    spar_internal_error (sparp, "sparp_" "equiv_merge (): same variable in two different equivs of same gp");
	}
    }
#endif
  if ((pri->e_rvr.rvrRestrictions & SPART_VARR_EXPORTED) && (sec->e_rvr.rvrRestrictions & SPART_VARR_EXPORTED))
    return SPARP_EQUIV_MERGE_ROLLBACK;
  if ((0 != pri->e_subquery_uses) || (0 != sec->e_subquery_uses))
    return SPARP_EQUIV_MERGE_ROLLBACK;
  ret = sparp_equiv_restrict_by_constant (sparp, pri, sec->e_rvr.rvrDatatype, (SPART *)(sec->e_rvr.rvrFixedValue));
  if (SPARP_EQUIV_MERGE_ROLLBACK == ret)
    return ret;
  pri->e_varnames = t_list_concat ((caddr_t)(pri->e_varnames), (caddr_t)(sec->e_varnames));
  sec->e_varnames = t_list (0);
  if (0 < sec->e_var_count)
    {
      SPART **new_vars = (SPART **) t_alloc_box ((pri->e_var_count + sec->e_var_count) * sizeof (SPART *), DV_ARRAY_OF_POINTER);
      memcpy (new_vars, pri->e_vars, pri->e_var_count * sizeof (SPART *));
      memcpy (new_vars + pri->e_var_count, sec->e_vars, sec->e_var_count * sizeof (SPART *));
      for (ctr1 = sec->e_var_count; ctr1--; /* no step*/)
        sec->e_vars[ctr1]->_.var.equiv_idx = pri->e_own_idx;
      pri->e_vars = new_vars;
      sec->e_vars = (SPART **)t_list (1, NULL);
      pri->e_var_count += sec->e_var_count;
      sec->e_var_count = 0;
    }
  sparp_rvr_tighten (sparp, &(pri->e_rvr), &(sec->e_rvr), ~0);
  pri->e_gspo_uses += sec->e_gspo_uses;
  sec->e_gspo_uses = 0;
  sec->e_nested_bindings = 0;
  pri->e_const_reads += sec->e_const_reads;
  sec->e_const_reads = 0;
  while (BOX_ELEMENTS_INT_0 (sec->e_subvalue_idxs))
    {
      ptrlong sub_idx = sec->e_subvalue_idxs[0];
      sparp_equiv_t *sub_eq = SPARP_EQUIV(sparp,sub_idx);
      sparp_equiv_disconnect (sparp, sec, sub_eq);
      sparp_equiv_connect (sparp, pri, sub_eq, 1);
    }
  while (BOX_ELEMENTS_INT_0 (sec->e_receiver_idxs))
    {
      ptrlong recv_idx = sec->e_receiver_idxs[0];
      sparp_equiv_t *recv_eq = SPARP_EQUIV(sparp,recv_idx);
      sparp_equiv_disconnect (sparp, recv_eq, sec);
      sparp_equiv_connect (sparp, recv_eq, pri, 1);
    }
  pri->e_nested_bindings = 0;
  DO_BOX_FAST_REV (ptrlong, sub_idx, ctr1, pri->e_subvalue_idxs)
    {
      sparp_equiv_t *sub_eq = SPARP_EQUIV(sparp,sub_idx);
      if ((0 < sub_eq->e_gspo_uses) || (0 < sub_eq->e_subquery_uses) || (0 < sub_eq->e_nested_bindings))
        pri->e_nested_bindings += 1;
    }
  END_DO_BOX_FAST;
  sec->e_merge_dest_idx = pri->e_own_idx;
  if (SPART_VARR_EXPORTED & sec->e_rvr.rvrRestrictions)
    {
      pri->e_rvr.rvrRestrictions |= SPART_VARR_EXPORTED;
      sec->e_rvr.rvrRestrictions &= ~SPART_VARR_EXPORTED;
    }
  sparp_equiv_remove (sparp, sec);
  return ret;
}

caddr_t
rvr_string_fixedvalue (rdf_val_range_t *rvr)
{
  caddr_t fv = (caddr_t) (rvr->rvrFixedValue);
  dtp_t fv_dtp = DV_TYPE_OF (fv);
  if (DV_ARRAY_OF_POINTER == fv_dtp)
    {
      fv = ((SPART *)fv)->_.lit.val;
      fv_dtp = DV_TYPE_OF (fv);
    }
  if (IS_STRING_DTP (fv_dtp))
    return fv;
  return NULL;
}

int sparp_fixedvalues_equal (sparp_t *sparp, SPART *first, SPART *second)
{
  caddr_t first_val, first_language = NULL;
  caddr_t second_val, second_language = NULL;
  if (first == second)
    return 1;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (first))
    {
      first_val = first->_.lit.val;
      if (SPAR_LIT == first->type)
        first_language = first->_.lit.language;
    }
  else
    first_val = (caddr_t)(first);
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (second))
    {
      second_val = second->_.lit.val;
      if (SPAR_LIT == second->type)
        second_language = second->_.lit.language;
    }
  else
    second_val = (caddr_t)(second);
  if (strcmp (
      ((NULL == first_language) ? "" : first_language),
      ((NULL == second_language) ? "" : second_language) ) )
    return 0;
  if (DVC_MATCH != cmp_boxes (first_val, second_val, NULL, NULL))
    return 0;
  return 1;
}

int
sparp_equivs_have_same_fixedvalue (sparp_t *sparp, sparp_equiv_t *first_eq, sparp_equiv_t *second_eq)
{
  if (!(SPART_VARR_FIXED & first_eq->e_rvr.rvrRestrictions))
    return 0;
  if (!(SPART_VARR_FIXED & second_eq->e_rvr.rvrRestrictions))
    return 0;
  if ( strcmp (
    ((NULL == first_eq->e_rvr.rvrDatatype) ? "" : first_eq->e_rvr.rvrDatatype),
    ((NULL == second_eq->e_rvr.rvrDatatype) ? "" : second_eq->e_rvr.rvrDatatype) ) )
    return 0;
  return sparp_fixedvalues_equal (sparp, (SPART *)(first_eq->e_rvr.rvrFixedValue), (SPART *)(second_eq->e_rvr.rvrFixedValue));
}


void
sparp_rvr_add_iri_classes (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *add_classes, ptrlong add_count)
{
  int len = rvr->rvrIriClassCount;
  int ctr, addctr;
  int oldsize, newmax;
  newmax = len + add_count;
  oldsize = BOX_ELEMENTS_0 (rvr->rvrIriClasses);
  if (oldsize < newmax)
    {
      int newsize = oldsize ? oldsize : 1;
      ccaddr_t *new_buf;
      do newsize *= 2; while (newsize < newmax);
      new_buf = (ccaddr_t *)t_alloc_box (newsize * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      if (NULL != rvr->rvrIriClasses)
        memcpy (new_buf, rvr->rvrIriClasses, oldsize * sizeof (caddr_t));
      rvr->rvrIriClasses = new_buf;
    }
#if 0 /* Version with no class hierarchy and alphabetcally sorted rvrIriClasses */
  ctr = 0;
  for (addctr = 0; addctr < add_count; addctr++)
    {
      int cmp, movectr;
next_ctr:
#ifdef DEBUG
      if ((0 < ctr) && (0 <= strcmp (rvr->rvrIriClasses [ctr-1], rvr->rvrIriClasses [ctr])))
        spar_internal_error (sparp, "sparp_" "rvr_add_iri_classes(): misordered e_iri_classes");
      if ((0 < addctr) && (0 <= strcmp (add_classes [addctr-1], add_classes [addctr])))
        spar_internal_error (sparp, "sparp_" "rvr_add_iri_classes(): misordered add_classes");
#endif
      cmp = ((ctr >= len) ? 2 : strcmp (rvr->rvrIriClasses [ctr], add_classes [addctr]));
      if (cmp < 0)
        {
          ctr++;
          goto next_ctr;
        }
      if (0 == cmp)
        continue;
      for (movectr = len; movectr > ctr; movectr--)
        rvr->rvrIriClasses [movectr] = rvr->rvrIriClasses [movectr - 1];
      rvr->rvrIriClasses [ctr] = add_classes [addctr];
      len++;
    }
#else /* Version with nonrecursive class hierarchy and unsorted rvrIriClasses */
  for (addctr = 0; addctr < add_count; addctr++)
    {
      int cmpctr, cmpcount;
      ccaddr_t addon = add_classes [addctr];
      caddr_t *addon_superclasses, *addon_subclasses;
      for (ctr = 0; ctr < len; ctr++)
        {
          ccaddr_t old = rvr->rvrIriClasses [ctr];
          if (old == addon) /* Already here */
            goto skip_addon; /* see below */
        }
      addon_superclasses = jso_triple_get_objs ((caddr_t *)(sparp->sparp_sparqre->sparqre_qi), (caddr_t) addon, (caddr_t) uname_virtrdf_ns_uri_isSubclassOf);
      cmpcount = BOX_ELEMENTS (addon_superclasses);
      for (ctr = 0; ctr < len; ctr++)
        {
          ccaddr_t old = rvr->rvrIriClasses [ctr];
          for (cmpctr = 0; cmpctr < cmpcount; cmpctr++)
            {
              if (old == addon_superclasses [cmpctr]) /* A superclass is already here */
                {
                  dk_free_tree (addon_superclasses);
                  goto skip_addon; /* see below */
                }
            }
        }
      dk_free_tree (addon_superclasses);
      addon_subclasses = jso_triple_get_subjs ((caddr_t *)(sparp->sparp_sparqre->sparqre_qi), (caddr_t) uname_virtrdf_ns_uri_isSubclassOf, (caddr_t) addon);
      cmpcount = BOX_ELEMENTS (addon_subclasses);
      for (ctr = 0; ctr < len; ctr++)
        {
          ccaddr_t old = rvr->rvrIriClasses [ctr];
          for (cmpctr = 0; cmpctr < cmpcount; cmpctr++)
            {
              if (old == addon_subclasses [cmpctr]) /* old is redundant because addon superclass will be added */
                {
                  if (ctr < (len-1))
                    rvr->rvrIriClasses [ctr] = rvr->rvrIriClasses [len - 1];
                  len--;
                }
            }
        }
      dk_free_tree (addon_subclasses);
      rvr->rvrIriClasses [len++] = addon;
skip_addon: ;
    }
#endif
  rvr->rvrIriClassCount = len;
}

void
sparp_rvr_intersect_iri_classes (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *isect_classes, ptrlong isect_count)
{
  int len = rvr->rvrIriClassCount;
#if 0 /* Version with no class hierarchy and alphabetcally sorted rvrIriClasses */
  int ctr, movectr = 0, isectctr = 0;
  for (ctr = 0; ctr < len; ctr++)
    {
      int cmp;
next_isectctr:
#ifdef DEBUG
      if ((0 < ctr) && (0 <= strcmp (rvr->rvrIriClasses [ctr-1], rvr->rvrIriClasses [ctr])))
        spar_internal_error (sparp, "sparp_" "rvr_intersect_iri_classes(): misordered e_iri_classes");
      if ((0 < isectctr) && (0 <= strcmp (isect_classes [isectctr-1], isect_classes [isectctr])))
        spar_internal_error (sparp, "sparp_" "rvr_intersect_iri_classes(): misordered isect_classes");
#endif
      cmp = ((isectctr >= isect_count) ? -2 : strcmp (rvr->rvrIriClasses [ctr], isect_classes [isectctr]));
      if (cmp > 0)
        {
          isectctr++;
          goto next_isectctr;
        }
      if (0 == cmp)
        rvr->rvrIriClasses [movectr++] = rvr->rvrIriClasses [ctr];
    }
  rvr->rvrIriClassCount = movectr;
#else /* Version with nonrecursive class hierarchy and unsorted rvrIriClasses */
  int ctr;
  for (ctr = 0; ctr < len; ctr++)
    {
      ccaddr_t old = rvr->rvrIriClasses [ctr];
      caddr_t *old_superclasses, *old_subclasses;
      int cmpctr, cmpcount, isectctr;
      for (isectctr = 0; isectctr < isect_count; isectctr++)
        {
          if (isect_classes [isectctr] == old) /* Found in isect */
            goto test_next_old; /* see below */
        }
      old_superclasses = jso_triple_get_objs ((caddr_t *)(sparp->sparp_sparqre->sparqre_qi), (caddr_t) old, (caddr_t) uname_virtrdf_ns_uri_isSubclassOf);
      cmpcount = BOX_ELEMENTS (old_superclasses);
      for (isectctr = 0; isectctr < isect_count; isectctr++)
        {
          for (cmpctr = 0; cmpctr < cmpcount; cmpctr++)
            {
              if (isect_classes [isectctr] == old_superclasses [cmpctr]) /* Found in isect */
                {
                  dk_free_tree (old_superclasses);
                  goto test_next_old; /* see below */
                }
            }
        }
      dk_free_tree (old_superclasses);
/* At this point we know that \c old is out of intersection. Let's remove it. */
      if (ctr < (len-1))
        rvr->rvrIriClasses [ctr] = rvr->rvrIriClasses [len - 1];
      len--;
/* Now we should add subclasses of \c old that are in the \c isect_classes */
      old_subclasses = jso_triple_get_subjs ((caddr_t *)(sparp->sparp_sparqre->sparqre_qi), (caddr_t) uname_virtrdf_ns_uri_isSubclassOf, (caddr_t) old);
      cmpcount = BOX_ELEMENTS (old_subclasses);
      for (cmpctr = 0; cmpctr < cmpcount; cmpctr++)
        {
          caddr_t old_sub = old_subclasses [cmpctr];
          for (isectctr = 0; isectctr < isect_count; isectctr++)
            {
              if (isect_classes [isectctr] == old_sub) /* Found in isect */
                {
                  int sctr;
                  int oldsize, newmax;
                  for (sctr = len; sctr--; /*no step*/)
                    {
                      if (rvr->rvrIriClasses [sctr] == old_sub)
                        goto test_next_subclass; /* see below */
                    }
                  oldsize = BOX_ELEMENTS_0 (rvr->rvrIriClasses);
                  newmax = len + isect_count;
                  if (oldsize < (len+1))
                    {
                      int newsize = oldsize ? oldsize : 1;
                      ccaddr_t *new_buf;
                      do newsize *= 2; while (newsize < newmax);
                      new_buf = (ccaddr_t *)t_alloc_box (newsize * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
                      if (NULL != rvr->rvrIriClasses)
                        memcpy (new_buf, rvr->rvrIriClasses, oldsize * sizeof (caddr_t));
                      rvr->rvrIriClasses = new_buf;
                    }
                  rvr->rvrIriClasses [len++] = old_sub;
                  goto test_next_subclass; /* see below */
                }
            }
test_next_subclass: ;
        }
      dk_free_tree (old_subclasses);
test_next_old: ;
    }
  rvr->rvrIriClassCount = len;
#endif
}

void
sparp_rvr_add_red_cuts (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *add_cuts, ptrlong add_count)
{
  int old_len, len;
  int ctr, addctr;
  int oldsize, newmax;
  old_len = len = rvr->rvrRedCutCount;
  newmax = len + add_count;
  oldsize = BOX_ELEMENTS_0 (rvr->rvrRedCuts);
  if (oldsize < newmax)
    {
      int newsize = oldsize ? oldsize : 1;
      ccaddr_t *new_buf;
      do newsize *= 2; while (newsize < newmax);
      new_buf = (ccaddr_t *)t_alloc_box (newsize * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      if (NULL != rvr->rvrRedCuts)
        memcpy (new_buf, rvr->rvrRedCuts, oldsize * sizeof (caddr_t));
      rvr->rvrRedCuts = new_buf;
    }
  for (addctr = add_count; addctr--; /* no step */)
    {
      ccaddr_t addon = add_cuts [addctr];
      for (ctr = old_len; ctr--; /* no step */)
        {
          ccaddr_t old = rvr->rvrRedCuts [ctr];
          if (old == addon) /* Already here */
            goto skip_addon; /* see below */
        }
      rvr->rvrRedCuts [len++] = addon;
skip_addon: ;
    }
  rvr->rvrRedCutCount = len;
}

void
sparp_rvr_intersect_red_cuts (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *isect_cuts, ptrlong isect_count)
{
  int len = rvr->rvrRedCutCount;
  int ctr;
  for (ctr = 0; ctr < len; ctr++)
    {
      ccaddr_t old = rvr->rvrRedCuts [ctr];
      int isectctr;
      for (isectctr = 0; isectctr < isect_count; isectctr++)
        {
          if (isect_cuts [isectctr] == old) /* Found in isect */
            goto test_next_old; /* see below */
        }
/* At this point we know that \c old is out of intersection. Let's remove it. */
      if (ctr < (len-1))
        rvr->rvrRedCuts [ctr] = rvr->rvrRedCuts [len - 1];
      len--;
test_next_old: ;
    }
  rvr->rvrRedCutCount = len;
}

int
rvr_sprintffs_like (caddr_t value, rdf_val_range_t *rvr)
{
  int ctr;
#ifdef DEBUG
  if (!(SPART_VARR_SPRINTFF & rvr->rvrRestrictions))
    GPF_T1 ("Invalid call of rvr_sprintffs_like()");
#endif
  for (ctr = rvr->rvrSprintffCount; ctr--; /* no step */)
    {
      if (sprintff_like (value, rvr->rvrSprintffs[ctr]))
        return 1+ctr;
    }
  return 0;
}

#ifdef DEBUG
void
dbg_sparp_rvr_audit (const char *file, int line, sparp_t *sparp, rdf_val_range_t *rvr)
{
  caddr_t err = NULL;
  int ctr;
#define GOTO_RVR_ERR(x) { err = x; goto rvr_err; }
  if (!(rvr->rvrRestrictions & SPART_VARR_SPRINTFF) && (0 != rvr->rvrSprintffCount))
    GOTO_RVR_ERR("nonzero rvrSprintffCount when not SPART_VARR_SPRINTFF");
  if ((rvr->rvrRestrictions & SPART_VARR_FIXED) && (0 != rvr->rvrSprintffCount))
    GOTO_RVR_ERR("nonzero rvrSprintffCount when SPART_VARR_FIXED");
  if ((rvr->rvrRestrictions & SPART_VARR_FIXED) && (rvr->rvrRestrictions & SPART_VARR_SPRINTFF))
    GOTO_RVR_ERR("SPART_VARR_FIXED and SPART_VARR_SPRINTFF");
  if (rvr->rvrRestrictions & SPART_VARR_SPRINTFF)
    {
      for (ctr = 0; ctr < rvr->rvrSprintffCount; ctr++)
        {
          ccaddr_t sff = rvr->rvrSprintffs[ctr];
          dtp_t sff_dtp = DV_TYPE_OF (sff);
            if (!IS_STRING_DTP(sff_dtp))
              GOTO_RVR_ERR("non-string sprintff");
        }
    }
  return;
rvr_err:
    spar_internal_error (sparp, t_box_sprintf (1000, "sparp_" "rvr_audit (%s:%d): %s", file, line, err));
}
#endif

rdf_val_range_t *
sparp_rvr_copy (sparp_t *sparp, rdf_val_range_t *dest, rdf_val_range_t *src)
{
  if (SPARP_RVR_CREATE == dest)
    dest = (rdf_val_range_t *)t_alloc (sizeof (rdf_val_range_t));
  if (src->rvrRestrictions & SPART_VARR_CONFLICT)
    {
      memset (dest, 0, sizeof (rdf_val_range_t));
      dest->rvrRestrictions = SPART_VARR_CONFLICT;
      return dest;
    }
  sparp_rvr_audit (sparp, src);
  memcpy (dest, src, sizeof (rdf_val_range_t));
  if (NULL != src->rvrSprintffs)
    dest->rvrSprintffs = (ccaddr_t *)t_box_copy ((caddr_t)(src->rvrSprintffs));
  if (NULL != src->rvrIriClasses)
    dest->rvrIriClasses = (ccaddr_t *)t_box_copy ((caddr_t)(src->rvrIriClasses));
  if (NULL != src->rvrRedCuts)
    dest->rvrRedCuts = (ccaddr_t *)t_box_copy ((caddr_t)(src->rvrRedCuts));
  sparp_rvr_audit (sparp, dest);
  return dest;
}

void
sparp_rvr_set_by_constant (sparp_t *sparp, rdf_val_range_t *dest, ccaddr_t datatype, SPART *value)
{
  memset (dest, 0, sizeof (rdf_val_range_t));
  if (NULL != datatype)
    {
      dest->rvrDatatype = datatype;
      dest->rvrRestrictions |= SPART_VARR_TYPED;
    }
  if (NULL != value)
    {
      if (SPAR_QNAME == SPART_TYPE (value))
        {
#ifdef DEBUG
          if (DV_UNAME != DV_TYPE_OF (value->_.lit.val))
            GPF_T1 ("sparp_" "rvr_set_by_constant(): bad QNAME");
#endif
          dest->rvrFixedValue = value->_.lit.val;
          dest->rvrRestrictions |= (SPART_VARR_IS_REF | SPART_VARR_FIXED);
        }
      else if (DV_UNAME == DV_TYPE_OF (value))
        {
          dest->rvrFixedValue = (ccaddr_t)value;
          dest->rvrRestrictions |= (SPART_VARR_IS_REF | SPART_VARR_FIXED);
        }
      else
        {
#ifdef DEBUG
              if (SPAR_LIT != SPART_TYPE (value))
                GPF_T1("sparp_" "rvr_set_by_constant(): value is neither QNAME nor a literal");
#endif
          dest->rvrFixedValue = (ccaddr_t)value;
          dest->rvrRestrictions |= (SPART_VARR_IS_LIT | SPART_VARR_FIXED);
        }
    }
}

void
sparp_rvr_tighten (sparp_t *sparp, rdf_val_range_t *dest, rdf_val_range_t *addon, int changeable_flags)
{
  ptrlong new_restr;
  new_restr = (dest->rvrRestrictions | (addon->rvrRestrictions & changeable_flags));
  if (new_restr & SPART_VARR_CONFLICT)
    goto conflict; /* see below */
  sparp_rvr_audit (sparp, dest);
  sparp_rvr_audit (sparp, addon);
  if (dest->rvrDatatype != addon->rvrDatatype)
    {
      if (dest->rvrRestrictions & addon->rvrRestrictions & SPART_VARR_TYPED)
        goto conflict; /* see below */
      else
        {
          ccaddr_t isect_dt = sparp_largest_intersect_superdatatype (sparp, dest->rvrDatatype, addon->rvrDatatype);
          dest->rvrDatatype = isect_dt;
        }
    }
  if (addon->rvrRestrictions & changeable_flags & SPART_VARR_FIXED)
    {
      if (dest->rvrRestrictions & SPART_VARR_FIXED)
        {
          if (!sparp_fixedvalues_equal (sparp, (SPART *)(dest->rvrFixedValue), (SPART *)(addon->rvrFixedValue)))
            goto conflict; /* see below */
        }
      else
        {
#ifdef DEBUG
              if (SPAR_LIT != SPART_TYPE ((SPART *)(addon->rvrFixedValue)))
                GPF_T1("sparp_" "rvr_tighten(): addon->rvrFixedValue is not a literal");
#endif
          dest->rvrFixedValue = addon->rvrFixedValue;
        }
    }
  if (new_restr & SPART_VARR_FIXED)
    {
      caddr_t fv = rvr_string_fixedvalue (dest);
      if (NULL != fv)
        {
          int ctr;
          if (dest->rvrRestrictions & SPART_VARR_SPRINTFF)
            {
              for (ctr = dest->rvrSprintffCount; ctr--; /* no step */)
                {
                  if (sprintff_like (fv, dest->rvrSprintffs[ctr]))
                    goto fv_like_dest_sff;
                }
              goto conflict; /* see below */
            }
fv_like_dest_sff:
          if (addon->rvrRestrictions & changeable_flags & SPART_VARR_SPRINTFF)
            {
              for (ctr = addon->rvrSprintffCount; ctr--; /* no step */)
                {
                  if (sprintff_like (fv, addon->rvrSprintffs[ctr]))
                    goto fv_like_addon_sff;
                }
              goto conflict; /* see below */
            }
fv_like_addon_sff:
          new_restr &= ~SPART_VARR_SPRINTFF; /* With fixed string value, there's no need in sprintffs at all */
          dest->rvrSprintffCount = 0;
          goto end_of_sff_processing; /* see below */
        }
    }
  if (addon->rvrRestrictions & changeable_flags & SPART_VARR_SPRINTFF)
    {
      if (dest->rvrRestrictions & SPART_VARR_SPRINTFF)
        {
          sparp_rvr_intersect_sprintffs (sparp, dest, addon->rvrSprintffs, addon->rvrSprintffCount);
          if (0 == dest->rvrSprintffCount)
            goto conflict; /* see below */
        }
      else
        {
          dest->rvrSprintffs = (ccaddr_t *) t_box_copy ((caddr_t)(addon->rvrSprintffs));
          dest->rvrSprintffCount = addon->rvrSprintffCount;
        }
    }

end_of_sff_processing:
  if (addon->rvrRestrictions & changeable_flags & SPART_VARR_IRI_CALC)
    {
      if (dest->rvrRestrictions & SPART_VARR_IRI_CALC)
        {
          sparp_rvr_intersect_iri_classes (sparp, dest, addon->rvrIriClasses, addon->rvrIriClassCount);
          if (0 == dest->rvrIriClassCount)
#if 0 /*!!! TBD enable when iri classes are valid */
            goto conflict; /* see below */
#else
            new_restr &= ~SPART_VARR_IRI_CALC;
#endif
        }
      else
        {
          dest->rvrIriClasses = (ccaddr_t *) t_box_copy ((caddr_t)(addon->rvrIriClasses));
          dest->rvrIriClassCount = addon->rvrIriClassCount;
        }
    }
  if (0 != addon->rvrRedCutCount)
    sparp_rvr_add_red_cuts (sparp, dest, addon->rvrRedCuts, addon->rvrRedCutCount);
  if (dest->rvrRestrictions & SPART_VARR_FIXED)
    {
      int cut_ctr;
      for (cut_ctr = dest->rvrRedCutCount; cut_ctr--; /* no step */)
        {
          ccaddr_t cut_val = dest->rvrRedCuts [cut_ctr];
          if (sparp_fixedvalues_equal (sparp, (SPART *)cut_val, (SPART *)(dest->rvrFixedValue)))
            goto conflict; /* see below */
        }
    }
  if (
    ((new_restr & SPART_VARR_IS_REF) && (new_restr & SPART_VARR_IS_LIT)) ||
    ((new_restr & SPART_VARR_IS_BLANK) && (new_restr & SPART_VARR_IS_IRI)) ||
    ((new_restr & SPART_VARR_ALWAYS_NULL) &&
     (new_restr & (SPART_VARR_NOT_NULL | SPART_VARR_IS_LIT | SPART_VARR_IS_REF)) ) )    
    goto conflict; /* see below */

#if 0
  do {
      dk_session_t *ses = strses_allocate ();
      caddr_t strg;
      spart_dump_rvr (ses, dest);
      strg = strses_string (ses);
      printf ("Nice tighten op: %s\n", strg);
      dk_free_box ((caddr_t)ses);
      dk_free_box (strg);
    } while (0);
#endif
  dest->rvrRestrictions = new_restr;
  sparp_rvr_audit (sparp, dest);
  sparp_rvr_audit (sparp, addon);
  return;

conflict:
  new_restr |= SPART_VARR_CONFLICT;
  dest->rvrRestrictions = new_restr;
}

void
sparp_rvr_loose (sparp_t *sparp, rdf_val_range_t *dest, rdf_val_range_t *addon, int changeable_flags)
{
  ptrlong new_restr;
  if (addon->rvrRestrictions & SPART_VARR_CONFLICT)
    return;
  if (dest->rvrRestrictions & SPART_VARR_CONFLICT)
    {
      int persistent_restr = (dest->rvrRestrictions & (SPART_VARR_EXPORTED | SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL));
      sparp_rvr_copy (sparp, dest, addon);
      dest->rvrRestrictions |= persistent_restr;
      sparp_rvr_audit (sparp, dest);
      return;
    }
  sparp_rvr_audit (sparp, dest);
  sparp_rvr_audit (sparp, addon);
  /* Can't loose these flags: */
  changeable_flags &= ((ptrlong)(SPART_VARR__ALL)) &
    ~(SPART_VARR_EXPORTED | SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL);
  new_restr = dest->rvrRestrictions & (addon->rvrRestrictions | ~changeable_flags);
  if (dest->rvrDatatype != addon->rvrDatatype)
    {
      ccaddr_t union_dt = sparp_smallest_union_superdatatype (sparp, dest->rvrDatatype, addon->rvrDatatype);
      new_restr &= ~SPART_VARR_TYPED;
      dest->rvrDatatype = union_dt;
    }
  if (new_restr & changeable_flags & SPART_VARR_FIXED)
    {
      if (!sparp_fixedvalues_equal (sparp, (SPART *)(dest->rvrFixedValue), (SPART *)(addon->rvrFixedValue)))
        new_restr &= ~SPART_VARR_FIXED;
    }
  if (!(new_restr & changeable_flags & SPART_VARR_FIXED))
    { /* We may preserve the knowledge of fixed value in formats */
      if (dest->rvrRestrictions & changeable_flags & SPART_VARR_FIXED)
        {
          caddr_t fv = rvr_string_fixedvalue (dest);
          if (NULL != fv)
            {
              ccaddr_t fv_fmt = sprintff_from_strg (fv, 1);
              if (0 != dest->rvrSprintffCount)
                spar_internal_error (sparp, "sparp_" "rvr_loose (): bad dest: nonzero rvrSprintffCount when SPART_VARR_FIXED");
              sparp_rvr_add_sprintffs (sparp, dest, &fv_fmt, 1);
              dest->rvrRestrictions |= SPART_VARR_SPRINTFF;
              new_restr |= (addon->rvrRestrictions & changeable_flags & SPART_VARR_SPRINTFF);
            }
        }
      if ((addon->rvrRestrictions & changeable_flags & SPART_VARR_FIXED) &&
        (dest->rvrRestrictions & SPART_VARR_SPRINTFF) )
        {
          caddr_t fv = rvr_string_fixedvalue (addon);
          if (NULL != fv)
            {
              ccaddr_t fv_fmt = sprintff_from_strg (fv, 1);
              if (0 != addon->rvrSprintffCount)
                spar_internal_error (sparp, "sparp_" "rvr_loose (): bad addon: nonzero rvrSprintffCount when SPART_VARR_FIXED");
              sparp_rvr_add_sprintffs (sparp, dest, &fv_fmt, 1);
              dest->rvrRestrictions |= SPART_VARR_SPRINTFF;
              new_restr |= SPART_VARR_SPRINTFF;
              goto end_of_sff_processing; /* see below */
            }
        }
    }
  if (new_restr & changeable_flags & SPART_VARR_SPRINTFF)
    sparp_rvr_add_sprintffs (sparp, dest, addon->rvrSprintffs, addon->rvrSprintffCount);
  else
    dest->rvrSprintffCount = 0;

end_of_sff_processing:
  if (new_restr & changeable_flags & SPART_VARR_IRI_CALC)
    sparp_rvr_add_iri_classes (sparp, dest, addon->rvrIriClasses, addon->rvrIriClassCount);
  sparp_rvr_intersect_red_cuts (sparp, dest, addon->rvrRedCuts, addon->rvrRedCutCount);
  dest->rvrRestrictions = new_restr;
  sparp_rvr_audit (sparp, dest);
  sparp_rvr_audit (sparp, addon);
 }

void
sparp_equiv_tighten (sparp_t *sparp, sparp_equiv_t *eq, rdf_val_range_t *addon, int changeable_flags)
{
#ifdef DEBUG
  if (eq->e_deprecated)
    spar_internal_error (sparp, "sparp_" "equiv_tighten(): can't change deprecated eq");
#endif
  sparp_rvr_tighten (sparp, &(eq->e_rvr), addon, changeable_flags);
}

void
sparp_equiv_loose (sparp_t *sparp, sparp_equiv_t *eq, rdf_val_range_t *addon, int changeable_flags)
{
#ifdef DEBUG
  if (eq->e_deprecated)
    spar_internal_error (sparp, "sparp_" "equiv_loose(): can't change deprecated eq");
#endif
  if (addon->rvrRestrictions & SPART_VARR_CONFLICT)
    return;
  sparp_rvr_loose (sparp, &(eq->e_rvr), addon, changeable_flags);
}


/* RELATIONS BETWEEN QUAD MAP FORMATS AND BUILT-IN VALMODES */

ccaddr_t
sparp_smallest_union_superdatatype (sparp_t *sparp, ccaddr_t iri1, ccaddr_t iri2)
{
  if (iri1 == iri2)
    return iri1;
  if ((NULL == iri1) || (NULL == iri2))
    return NULL;
#ifdef DEBUG
  if ((DV_UNAME != DV_TYPE_OF (iri1)) || (DV_UNAME != DV_TYPE_OF (iri2)))
    spar_internal_error (sparp, "sparp_" "smallest_union_superdatatype(): non-UNAME datatype IRI");
#endif
  if (strcmp (iri1, iri2) > 0)
    {
      ccaddr_t swap;
      swap = iri1; iri1 = iri2; iri2 = swap;
    }
  if ((uname_xmlschema_ns_uri_hash_any == iri1) || (uname_xmlschema_ns_uri_hash_any == iri2))
    return uname_xmlschema_ns_uri_hash_any;
  if ((uname_xmlschema_ns_uri_hash_anyURI == iri1) || (uname_xmlschema_ns_uri_hash_anyURI == iri2))
    return uname_xmlschema_ns_uri_hash_any; /* anyURI nd non-anyURI result in any, because they're probably for an IRI REF and a literal */
  if ((uname_xmlschema_ns_uri_hash_double == iri1) && (uname_xmlschema_ns_uri_hash_float == iri2))
    return uname_xmlschema_ns_uri_hash_double;
  if ((uname_xmlschema_ns_uri_hash_decimal == iri1) && (uname_xmlschema_ns_uri_hash_integer == iri2))
    return uname_xmlschema_ns_uri_hash_decimal;
  return uname_xmlschema_ns_uri_hash_any;
}

ccaddr_t
sparp_largest_intersect_superdatatype (sparp_t *sparp, ccaddr_t iri1, ccaddr_t iri2)
{
  if (iri1 == iri2)
    return iri1;
  if (NULL == iri1)
    return iri2;
  if (NULL == iri2)
    return iri1;
#ifdef DEBUG
  if ((DV_UNAME != DV_TYPE_OF (iri1)) || (DV_UNAME != DV_TYPE_OF (iri2)))
    spar_internal_error (sparp, "sparp_" "largest_intersect_subdatatype(): non-UNAME datatype IRI");
#endif
  if (strcmp (iri1, iri2) > 0)
    {
      ccaddr_t swap;
      swap = iri1; iri1 = iri2; iri2 = swap;
    }
  if (uname_xmlschema_ns_uri_hash_any == iri1)
    return iri2;
  if (uname_xmlschema_ns_uri_hash_any == iri2)
    return iri1;
  if ((uname_xmlschema_ns_uri_hash_anyURI == iri1) || (uname_xmlschema_ns_uri_hash_anyURI == iri2))
    return uname_xmlschema_ns_uri_hash_anyURI;
  if ((uname_xmlschema_ns_uri_hash_double == iri1) && (uname_xmlschema_ns_uri_hash_float == iri2))
    return uname_xmlschema_ns_uri_hash_float;
  if ((uname_xmlschema_ns_uri_hash_decimal == iri1) && (uname_xmlschema_ns_uri_hash_integer == iri2))
    return uname_xmlschema_ns_uri_hash_integer;
  return iri1;
}

/* BASIC TREE MODIFICATION FUNCTIONS */

SPART *
sparp_gp_detach_member_int (sparp_t *sparp, SPART *parent_gp, int member_idx, dk_set_t *touched_equivs_set_ptr)
{
  SPART *memb;
  SPART **old_members = parent_gp->_.gp.members;
#ifdef DEBUG
  int old_len = BOX_ELEMENTS (old_members);
  if ((0 > member_idx) || (old_len <= member_idx))
    spar_internal_error (sparp, "sparp_" "gp_detach_member(): bad member_idx");
#endif
  memb = old_members[member_idx];
  if (SPAR_GP == SPART_TYPE (memb))
    {
      int memb_eq_ctr;
#ifdef DEBUG
      int parent_eq_ctr;
#endif
      SPARP_REVFOREACH_GP_EQUIV (sparp, memb, memb_eq_ctr, eq)
        {
          while (BOX_ELEMENTS_0 (eq->e_receiver_idxs))
            {
              sparp_equiv_t *recv_eq = SPARP_EQUIV (sparp, eq->e_receiver_idxs[0]);
              sparp_equiv_disconnect (sparp, recv_eq, eq);
              if (NULL != touched_equivs_set_ptr)
                t_set_pushnew (touched_equivs_set_ptr, recv_eq);
            }
          eq->e_rvr.rvrRestrictions &= ~SPART_VARR_EXPORTED;
        }
      END_SPARP_REVFOREACH_GP_EQUIV;
#ifdef DEBUG
      SPARP_REVFOREACH_GP_EQUIV (sparp, parent_gp, parent_eq_ctr, parent_eq)
        {
          int subv_eq_ctr;
          DO_BOX_FAST (ptrlong, subv_eq_idx, subv_eq_ctr, parent_eq->e_subvalue_idxs)
            {
              sparp_equiv_t *subv_eq = SPARP_EQUIV (sparp, subv_eq_idx);
              SPART *subv_gp = sparp_find_gp_by_eq_idx (sparp, subv_eq_idx);
              if (subv_gp != subv_eq->e_gp)
                spar_internal_error (sparp, "sparp_" "gp_detach_member(): subv_gp != subv_eq->e_gp");
              if (subv_gp == memb)
                spar_internal_error (sparp, "sparp_" "gp_detach_member(): receiver not disconnected");
            }
          END_DO_BOX_FAST;
        }
      END_SPARP_REVFOREACH_GP_EQUIV;
#endif
    }
  else
    {
      int fld_ctr;
#ifdef DEBUG
      if (SPAR_TRIPLE != SPART_TYPE (memb))
        spar_internal_error (sparp, "sparp_" "gp_detach_member(): type of memb is neither SPAR_GP nor SPAR_TRIPLE");
#endif
      for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /*no step*/)
        {
          SPART *field = memb->_.triple.tr_fields [fld_ctr];
          if (SPAR_IS_BLANK_OR_VAR(field))
            {
              sparp_equiv_t *parent_eq = sparp_equiv_get (sparp, parent_gp, field, SPARP_EQUIV_GET_ASSERT);
              sparp_equiv_remove_var (sparp, parent_eq, field);
              if (NULL != touched_equivs_set_ptr)
                t_set_pushnew (touched_equivs_set_ptr, parent_eq);
              parent_eq->e_gspo_uses--;
            }
        }
    }
  return memb;
}

caddr_t
sparp_clone_id (sparp_t *sparp, caddr_t orig_name)
{
  int orig_len = strlen (orig_name);
  char buf[100];
  if (orig_len > 20)
    {
      int hash;
      BYTE_BUFFER_HASH (hash, orig_name, orig_len);
      memcpy (buf, orig_name, 20);
      sprintf (buf + 20, "X%c%c%c%c-c%d",
        'A' + (hash & 0x10), 'A' + ((hash >> 4) & 0x10),
        'A' + ((hash >> 8) & 0x10), 'A' + ((hash >> 12) & 0x10),
        (int)(sparp->sparp_cloning_serial) );
    }
  else
    sprintf (buf, "%s-c%d", orig_name, (int)(sparp->sparp_cloning_serial));
  return t_box_dv_short_string (buf);
}

static SPART **
sparp_treelist_full_clone_int (sparp_t *sparp, SPART **origs, SPART *parent_gp);

SPART *
sparp_tree_full_clone_int (sparp_t *sparp, SPART *orig, SPART *parent_gp)
{
  int filt_ctr, memb_ctr, eq_ctr, arg_ctr, fld_ctr, eq_idx, cloned_eq_idx;
  SPART *tgt;
  switch (SPART_TYPE (orig))
    {
    case SPAR_ALIAS:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.alias.arg = sparp_tree_full_clone_int (sparp, orig->_.alias.arg, parent_gp);
      return tgt;
    case SPAR_BLANK_NODE_LABEL: case SPAR_VARIABLE:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      eq_idx = orig->_.var.equiv_idx;
      if (SPART_BAD_EQUIV_IDX != eq_idx)
        {
          sparp_equiv_t *eq = SPARP_EQUIV (sparp, eq_idx);
          sparp_equiv_t *cloned_eq;
          int var_pos;
          if (eq->e_cloning_serial != sparp->sparp_cloning_serial)
            spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): eq not cloned for a variable");
          tgt->_.var.equiv_idx = eq->e_clone_idx;
          cloned_eq = SPARP_EQUIV (sparp, eq->e_clone_idx);
          for (var_pos = eq->e_var_count; var_pos--; /*no step*/)
            if (eq->e_vars [var_pos] == orig)
              break;
          if (0 > var_pos)
            spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): orig var is not in its eq");
          if (var_pos >= BOX_ELEMENTS (cloned_eq->e_vars))
            spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): mismatch of lengths of buffers for variables in orig and clone equivs");
          if (NULL != cloned_eq->e_vars [var_pos])
            spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): cloned variable overwrites an var in cloned equiv");
          if (NULL != orig->_.var.tabid)
            cloned_eq->e_gspo_uses += 1;
          else
            cloned_eq->e_const_reads += 1;
          cloned_eq->e_vars [var_pos] = tgt;
          if (cloned_eq->e_var_count <= var_pos)
            cloned_eq->e_var_count = var_pos + 1;
        }
      else
        {
          sparp_equiv_t *cloned_eq = sparp_equiv_get (sparp, parent_gp, tgt, 0);
          if (NULL != cloned_eq)
            spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): cloned variable is in equiv, original is not");
        }
      tgt->_.var.selid = sparp_clone_id (sparp, orig->_.var.selid);
      if (NULL != orig->_.var.tabid)
        tgt->_.var.tabid = sparp_clone_id (sparp, orig->_.var.tabid);
      tgt->_.var.vname = t_box_copy (orig->_.var.vname);
      sparp_rvr_copy (sparp, &(tgt->_.var.rvr), &(orig->_.var.rvr));
      return tgt;
    case SPAR_GP:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.gp.equiv_indexes = (ptrlong *)t_box_copy ((caddr_t) orig->_.gp.equiv_indexes);
      for (eq_ctr = 0; eq_ctr < orig->_.gp.equiv_count; eq_ctr++)
        {
          sparp_equiv_t *eq, *cloned_eq;
          eq_idx = orig->_.gp.equiv_indexes [eq_ctr];
          if (SPART_BAD_EQUIV_IDX == eq_idx)
            spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): bad equiv idx in list of gp.equiv_indexes");
          eq = SPARP_EQUIV (sparp, eq_idx);
          if (orig != eq->e_gp)
            spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): orig != e_gp");
          cloned_eq = sparp_equiv_clone (sparp, eq, tgt);
          tgt->_.gp.equiv_indexes [eq_ctr] = cloned_eq->e_own_idx;
          if (NULL != parent_gp)
            {
              int recv_ctr;
              ptrlong *cloned_recvs = (ptrlong *)t_box_copy ((caddr_t)(eq->e_receiver_idxs));
              cloned_eq->e_receiver_idxs = cloned_recvs;
              DO_BOX_FAST_REV (ptrlong, recv, recv_ctr, cloned_recvs)
                {
                  sparp_equiv_t *recv_eq = SPARP_EQUIV (sparp, recv);
                  if (recv_eq->e_cloning_serial != sparp->sparp_cloning_serial)
                    spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): recv eq not cloned");
                  cloned_recvs [recv_ctr] = recv_eq->e_clone_idx;
                }
              END_DO_BOX_FAST_REV;
            }
          else
            {
              if (0 != BOX_ELEMENTS_0 (eq->e_receiver_idxs))
                spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): nonempty recv list without parent, maybe clone source is not detached");
              cloned_eq->e_receiver_idxs = (ptrlong *)t_list (0);
            }
        }
      if (NULL != orig->_.gp.filters)
        {
          tgt->_.gp.filters = (SPART **)t_box_copy ((caddr_t)(orig->_.gp.filters));
          DO_BOX_FAST_REV (SPART *, filt, filt_ctr, orig->_.gp.filters)
            {
              tgt->_.gp.filters [filt_ctr] = sparp_tree_full_clone_int (sparp, filt, orig);
            }
          END_DO_BOX_FAST_REV;
        }
      tgt->_.gp.members = (SPART **)t_box_copy ((caddr_t)(orig->_.gp.members));
      DO_BOX_FAST_REV (SPART *, memb, memb_ctr, orig->_.gp.members)
        {
          tgt->_.gp.members [memb_ctr] = sparp_tree_full_clone_int (sparp, memb, orig);
        }
      END_DO_BOX_FAST_REV;
      if (NULL != orig->_.gp.subquery)
          tgt->_.gp.subquery = sparp_tree_full_clone_int (sparp, orig->_.gp.subquery, orig);
      tgt->_.gp.selid = sparp_clone_id (sparp, orig->_.gp.selid);
      for (eq_ctr = 0; eq_ctr < orig->_.gp.equiv_count; eq_ctr++)
        {
          sparp_equiv_t *eq;
          sparp_equiv_t *cloned_eq;
          eq_idx = orig->_.gp.equiv_indexes [eq_ctr];
          cloned_eq_idx = tgt->_.gp.equiv_indexes [eq_ctr];
          if (SPART_BAD_EQUIV_IDX == eq_idx)
            spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): bad equiv idx in list of gp.equiv_indexes");
          eq = SPARP_EQUIV (sparp, eq_idx);
          cloned_eq = SPARP_EQUIV (sparp, cloned_eq_idx);
          if (NULL != eq->e_subvalue_idxs)
            {
              int subv_ctr;
              ptrlong *cloned_subs = (ptrlong *)t_box_copy ((caddr_t)(eq->e_subvalue_idxs));
              cloned_eq->e_subvalue_idxs = cloned_subs;
              DO_BOX_FAST_REV (ptrlong, subv, subv_ctr, cloned_subs)
                {
                  sparp_equiv_t *subv_eq = SPARP_EQUIV (sparp, subv);
                  sparp_equiv_t *cloned_subv_eq;
                  if (subv_eq->e_cloning_serial != sparp->sparp_cloning_serial)
                    spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): subv eq not cloned");
                  cloned_subs [subv_ctr] = subv_eq->e_clone_idx;
                  cloned_subv_eq = SPARP_EQUIV (sparp, subv_eq->e_clone_idx);
                  if (NULL == subv_eq->e_receiver_idxs)
                    spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): subv has no receivers");
                  if (NULL == cloned_subv_eq->e_receiver_idxs)
                    {
                      int subv_recv_ctr;
                      ptrlong *cloned_sub_recvs = (ptrlong *)t_box_copy ((caddr_t)(subv_eq->e_receiver_idxs));
                      cloned_subv_eq->e_receiver_idxs = cloned_sub_recvs;
                      DO_BOX_FAST_REV (ptrlong, subv_recv, subv_recv_ctr, cloned_sub_recvs)
                        {
                          sparp_equiv_t *subv_recv_eq = SPARP_EQUIV (sparp, subv_recv);
                          if (subv_recv_eq->e_cloning_serial != sparp->sparp_cloning_serial)
                            spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): recv eq of subv eq not cloned");
                          cloned_sub_recvs [subv_recv_ctr] = subv_recv_eq->e_clone_idx;
                        }
                      END_DO_BOX_FAST_REV;
                    }
                }
              END_DO_BOX_FAST_REV;
            }
          cloned_eq->e_var_count = eq->e_var_count;
          cloned_eq->e_gspo_uses = eq->e_gspo_uses;
          cloned_eq->e_nested_bindings = eq->e_nested_bindings;
          cloned_eq->e_const_reads = eq->e_const_reads;
          cloned_eq->e_optional_reads = eq->e_optional_reads;
          cloned_eq->e_subquery_uses = eq->e_subquery_uses;
        }
      return tgt;
    case SPAR_LIT: case SPAR_QNAME: /* case SPAR_QNAME_NS: */
      return (SPART *)t_full_box_copy_tree ((caddr_t)orig);
    case SPAR_TRIPLE:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.triple.selid = sparp_clone_id (sparp, orig->_.triple.selid);
      tgt->_.triple.tabid = sparp_clone_id (sparp, orig->_.triple.tabid);
      for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /*no step*/)
        {
          sparp_jso_validate_format (sparp, tgt->_.triple.native_formats[fld_ctr]);
          tgt->_.triple.tr_fields[fld_ctr] = sparp_tree_full_clone_int (sparp, orig->_.triple.tr_fields[fld_ctr], parent_gp);
        }
      return tgt;
    case SPAR_BUILT_IN_CALL:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.builtin.args = sparp_treelist_full_clone_int (sparp, orig->_.builtin.args, parent_gp);
      return tgt;
    case SPAR_FUNCALL:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.funcall.argtrees = sparp_treelist_full_clone_int (sparp, orig->_.funcall.argtrees, parent_gp);
      return tgt;
    case SPAR_REQ_TOP:
      {
        SPART *orig_pattern = orig->_.req_top.pattern;
        tgt = (SPART *)t_box_copy ((caddr_t) orig);
        tgt->_.req_top.pattern = sparp_tree_full_clone_int (sparp, orig->_.req_top.pattern, parent_gp); /* Should be before everything else to clone equivs */
        tgt->_.req_top.retvals = sparp_treelist_full_clone_int (sparp, orig->_.req_top.retvals, orig_pattern);
        tgt->_.req_top.orig_retvals = sparp_treelist_full_clone_int (sparp, orig->_.req_top.orig_retvals, orig_pattern);
        tgt->_.req_top.expanded_orig_retvals = sparp_treelist_full_clone_int (sparp, orig->_.req_top.expanded_orig_retvals, orig_pattern);
        /* !!! TBD something with retselid :) */
        tgt->_.req_top.groupings = sparp_treelist_full_clone_int (sparp, orig->_.req_top.groupings, orig_pattern);
        tgt->_.req_top.order = sparp_treelist_full_clone_int (sparp, orig->_.req_top.order, orig_pattern);
        return tgt;
      }
    case BOP_EQ: case BOP_NEQ:
    case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
    /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! */
    case BOP_SAME: case BOP_NSAME:
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
    case BOP_AND: case BOP_OR: case BOP_NOT:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.bin_exp.left = sparp_tree_full_clone_int (sparp, orig->_.bin_exp.left, parent_gp);
      if (NULL != orig->_.bin_exp.right)
        tgt->_.bin_exp.right = sparp_tree_full_clone_int (sparp, orig->_.bin_exp.right, parent_gp);
      return tgt;
    case ORDER_L:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.oby.expn = sparp_tree_full_clone_int (sparp, orig->_.oby.expn, parent_gp);
      return tgt;
    case SPAR_QM_SQL_FUNCALL:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.qm_sql_funcall.fname = t_box_copy (orig->_.qm_sql_funcall.fname);
      tgt->_.qm_sql_funcall.fixed = (SPART **)t_box_copy ((caddr_t) orig->_.qm_sql_funcall.fixed);
      DO_BOX_FAST_REV (SPART *, arg, arg_ctr, orig->_.qm_sql_funcall.fixed)
        {
          tgt->_.qm_sql_funcall.fixed[arg_ctr] = sparp_tree_full_clone_int (sparp, arg, parent_gp);
        }
      END_DO_BOX_FAST_REV;
      tgt->_.qm_sql_funcall.named = (SPART **)t_box_copy ((caddr_t) orig->_.qm_sql_funcall.named);
      DO_BOX_FAST_REV (SPART *, arg, arg_ctr, orig->_.qm_sql_funcall.named)
        {
          tgt->_.qm_sql_funcall.named[arg_ctr] = sparp_tree_full_clone_int (sparp, arg, parent_gp);
        }
      END_DO_BOX_FAST_REV;
      return tgt;
    case SPAR_LIST:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.list.items = sparp_treelist_full_clone_int (sparp, orig->_.list.items, parent_gp);
      return tgt;
/* Add more cases right above this line when introducing more SPAR_nnn constants */
    default: break; /* No need to copy names and literals because we will never change them in-place. */
    }
  spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): unsupported type of expression");
  return NULL; /* to keep C compiler happy */
}

SPART **
sparp_treelist_full_clone_int (sparp_t *sparp, SPART **origs, SPART *parent_gp)
{
  SPART **tgts = (SPART **)t_box_copy ((caddr_t) origs);
  int ctr;
  DO_BOX_FAST_REV (SPART *, org, ctr, origs)
    {
      tgts [ctr] = sparp_tree_full_clone_int (sparp, org, parent_gp);
    }
  END_DO_BOX_FAST_REV;
  return tgts;
}


SPART *
sparp_gp_full_clone (sparp_t *sparp, SPART *gp)
{
  SPART *tgt;
  sparp_equiv_audit_all (sparp, 0);
  sparp_audit_mem (sparp);
  sparp->sparp_cloning_serial++;
  tgt = sparp_tree_full_clone_int (sparp, gp, NULL);
  sparp->sparp_cloning_serial++;
  sparp_equiv_audit_all (sparp, 0);
  sparp_audit_mem (sparp);
  t_check_tree (tgt);
  return tgt;
}

SPART *
sparp_tree_full_copy (sparp_t *sparp, SPART *orig, SPART *parent_gp)
{
  int fld_ctr, eq_idx;
  SPART *tgt;
  switch (SPART_TYPE (orig))
    {
    case SPAR_ALIAS:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.alias.aname = t_box_copy (orig->_.alias.aname);
      tgt->_.alias.arg = sparp_tree_full_copy (sparp, orig->_.alias.arg, parent_gp);
      return tgt;
    case SPAR_BLANK_NODE_LABEL: case SPAR_VARIABLE:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      eq_idx = orig->_.var.equiv_idx;
      tgt->_.var.vname = t_box_copy (orig->_.var.vname);
      sparp_rvr_copy (sparp, &(tgt->_.var.rvr), &(orig->_.var.rvr));
      return tgt;
    case SPAR_GP:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.gp.members = sparp_treelist_full_copy (sparp, orig->_.gp.members, orig);
      tgt->_.gp.filters = sparp_treelist_full_copy (sparp, orig->_.gp.filters, orig);
      tgt->_.gp.equiv_indexes = (ptrlong *)t_box_copy ((caddr_t)(orig->_.gp.equiv_indexes));
      return tgt;
    case FROM_L: case NAMED_L: case SPAR_LIT: case SPAR_QNAME: /* case SPAR_QNAME_NS: */
      return (SPART *)t_full_box_copy_tree ((caddr_t)orig);
    case ORDER_L:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.oby.expn = sparp_tree_full_copy (sparp, orig->_.oby.expn, parent_gp);
      return tgt;
    case SPAR_TRIPLE:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /*no step*/)
        {
          sparp_jso_validate_format (sparp, tgt->_.triple.native_formats[fld_ctr]);
          tgt->_.triple.tr_fields[fld_ctr] = sparp_tree_full_copy (sparp, orig->_.triple.tr_fields[fld_ctr], parent_gp);
        }
      tgt->_.triple.options = sparp_treelist_full_copy (sparp, orig->_.triple.options, parent_gp);
      return tgt;
    case SPAR_BUILT_IN_CALL:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.builtin.args = sparp_treelist_full_copy (sparp, orig->_.builtin.args, parent_gp);
      return tgt;
    case SPAR_FUNCALL:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.funcall.argtrees = sparp_treelist_full_copy (sparp, orig->_.funcall.argtrees, parent_gp);
      return tgt;
    case SPAR_REQ_TOP:
      if (0 != sparp->sparp_equiv_count)
        spar_internal_error (sparp, "sparp_tree_full_copy() is used to copy req_top with nonzero equiv_count");
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.req_top.retvals = sparp_treelist_full_copy (sparp, orig->_.req_top.retvals, parent_gp);
      tgt->_.req_top.orig_retvals = sparp_treelist_full_copy (sparp, orig->_.req_top.orig_retvals, parent_gp);
      tgt->_.req_top.expanded_orig_retvals = sparp_treelist_full_copy (sparp, orig->_.req_top.expanded_orig_retvals, parent_gp);
      tgt->_.req_top.sources = sparp_treelist_full_copy (sparp, orig->_.req_top.sources, parent_gp);
      tgt->_.req_top.pattern = sparp_tree_full_copy (sparp, orig->_.req_top.pattern, parent_gp);
      tgt->_.req_top.groupings = sparp_treelist_full_copy (sparp, orig->_.req_top.groupings, parent_gp);
      tgt->_.req_top.order = sparp_treelist_full_copy (sparp, orig->_.req_top.order, parent_gp);
      tgt->_.req_top.limit = t_box_copy (orig->_.req_top.limit);
      tgt->_.req_top.offset = t_box_copy (orig->_.req_top.offset);
      return tgt;
    case BOP_EQ: case BOP_NEQ:
    case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
    /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! */
    case BOP_SAME: case BOP_NSAME:
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
    case BOP_AND: case BOP_OR: case BOP_NOT:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.bin_exp.left = sparp_tree_full_copy (sparp, orig->_.bin_exp.left, parent_gp);
      if (NULL != orig->_.bin_exp.right)
        tgt->_.bin_exp.right = sparp_tree_full_copy (sparp, orig->_.bin_exp.right, parent_gp);
      return tgt;
    case SPAR_QM_SQL_FUNCALL:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.qm_sql_funcall.fname = t_box_copy (orig->_.qm_sql_funcall.fname);
      tgt->_.qm_sql_funcall.fixed = sparp_treelist_full_copy (sparp, orig->_.qm_sql_funcall.fixed, parent_gp);
      tgt->_.qm_sql_funcall.named = sparp_treelist_full_copy (sparp, orig->_.qm_sql_funcall.named, parent_gp);
      return tgt;
    case SPAR_LIST:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.list.items = sparp_treelist_full_copy (sparp, orig->_.list.items, parent_gp);
      return tgt;
/* Add more cases right above this line when introducing more SPAR_nnn constants */
    default: break; /* No need to copy names and literals because we will never change them in-place. */
    }
  spar_internal_error (sparp, "sparp_" "tree_full_copy(): unsupported type of expression");
  return NULL; /* to keep C compiler happy */
}

SPART **
sparp_treelist_full_copy (sparp_t *sparp, SPART **origs, SPART *parent_gp)
{
  SPART **tgts = (SPART **)t_box_copy ((caddr_t) origs);
  int ctr;
  DO_BOX_FAST_REV (SPART *, org, ctr, origs)
    {
      tgts [ctr] = sparp_tree_full_copy (sparp, org, parent_gp);
    }
  END_DO_BOX_FAST_REV;
  return tgts;
}

SPART *
sparp_gp_detach_member (sparp_t *sparp, SPART *parent_gp, int member_idx, sparp_equiv_t ***touched_equivs_ptr)
{
  dk_set_t touched_equivs_set = NULL;
  dk_set_t *touched_equivs_set_ptr = ((NULL != touched_equivs_ptr) ? &touched_equivs_set : NULL);
  SPART **old_members = parent_gp->_.gp.members;
  SPART *memb;
  memb = sparp_gp_detach_member_int (sparp, parent_gp, member_idx, touched_equivs_set_ptr);
  if (NULL != touched_equivs_ptr)
    touched_equivs_ptr[0] = (sparp_equiv_t **)(t_revlist_to_array (touched_equivs_set));
  parent_gp->_.gp.members = (SPART **)t_list_remove_nth ((caddr_t)old_members, member_idx);
  sparp_equiv_audit_all (sparp, 0);
  return memb;
}

SPART **
sparp_gp_detach_all_members (sparp_t *sparp, SPART *parent_gp, sparp_equiv_t ***touched_equivs_ptr)
{
  dk_set_t touched_equivs_set = NULL;
  dk_set_t *touched_equivs_set_ptr = ((NULL != touched_equivs_ptr) ? &touched_equivs_set : NULL);
  SPART **old_members = parent_gp->_.gp.members;
  int member_idx;
  for (member_idx = BOX_ELEMENTS (old_members); member_idx--; /* no step */)
    sparp_gp_detach_member_int (sparp, parent_gp, member_idx, touched_equivs_set_ptr);
  if (NULL != touched_equivs_ptr)
    touched_equivs_ptr[0] = (sparp_equiv_t **)(t_revlist_to_array (touched_equivs_set));
  parent_gp->_.gp.members = (SPART **)t_list(0);
  sparp_equiv_audit_all (sparp, 0);
  return old_members;
}

void
sparp_gp_attach_member_int (sparp_t *sparp, SPART *parent_gp, SPART *memb, dk_set_t *touched_equivs_set_ptr)
{
  /*SPART **old_members = parent_gp->_.gp.members;*/
  if (SPAR_GP == SPART_TYPE (memb))
    {
      int memb_eq_ctr;
      SPARP_REVFOREACH_GP_EQUIV (sparp, memb, memb_eq_ctr, eq)
        {
          int varname_idx;
          DO_BOX_FAST (caddr_t, varname, varname_idx, eq->e_varnames)
            {
              sparp_equiv_t *parent_eq;
              parent_eq = sparp_equiv_get (sparp, parent_gp, (SPART *)varname, SPARP_EQUIV_GET_NAMESAKES | SPARP_EQUIV_INS_CLASS);
              sparp_equiv_connect (sparp, parent_eq, eq, 1);
            }
          END_DO_BOX_FAST;
        }
      END_SPARP_REVFOREACH_GP_EQUIV;
    }
  else
    {
      int fld_ctr;
#ifdef DEBUG
      if (SPAR_TRIPLE != SPART_TYPE (memb))
        spar_internal_error (sparp, "sparp_" "gp_attach_member(): type of memb is neither SPAR_GP nor SPAR_TRIPLE");
#endif
      for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /*no step*/)
        {
          SPART *field = memb->_.triple.tr_fields [fld_ctr];
          if (SPAR_IS_BLANK_OR_VAR(field))
            {
              sparp_equiv_t *parent_eq;
              field->_.var.selid = t_box_copy (parent_gp->_.gp.selid);
              parent_eq = sparp_equiv_get (sparp, parent_gp, field, SPARP_EQUIV_INS_VARIABLE | SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_ADD_GPSO_USE);
            }
        }
      memb->_.triple.selid = t_box_copy (parent_gp->_.gp.selid);
    }
}

void
sparp_gp_attach_member (sparp_t *sparp, SPART *parent_gp, SPART *memb, int insert_before_idx, sparp_equiv_t ***touched_equivs_ptr)
{
  dk_set_t touched_equivs_set = NULL;
  dk_set_t *touched_equivs_set_ptr = ((NULL != touched_equivs_ptr) ? &touched_equivs_set : NULL);
  SPART **old_members = parent_gp->_.gp.members;
#ifdef DEBUG
  if ((0 > insert_before_idx) || (BOX_ELEMENTS (parent_gp->_.gp.members) < insert_before_idx))
    spar_internal_error (sparp, "sparp_" "gp_attach_member(): bad member_idx");
#endif
  parent_gp->_.gp.members = (SPART **)t_list_insert_before_nth ((caddr_t)old_members, (caddr_t)memb, insert_before_idx);
  sparp_gp_attach_member_int (sparp, parent_gp, memb, touched_equivs_set_ptr);
  if (NULL != touched_equivs_ptr)
    touched_equivs_ptr[0] = (sparp_equiv_t **)(t_revlist_to_array (touched_equivs_set));
  sparp_equiv_audit_all (sparp, 0);
}

void
sparp_gp_attach_many_members (sparp_t *sparp, SPART *parent_gp, SPART **new_members, int insert_before_idx, sparp_equiv_t ***touched_equivs_ptr)
{
  dk_set_t touched_equivs_set = NULL;
  dk_set_t *touched_equivs_set_ptr = ((NULL != touched_equivs_ptr) ? &touched_equivs_set : NULL);
  SPART **old_members = parent_gp->_.gp.members;
  int ins_count = BOX_ELEMENTS (new_members);
  int memb_ctr;
#ifdef DEBUG
  if ((0 > insert_before_idx) || (BOX_ELEMENTS (parent_gp->_.gp.members) < insert_before_idx))
    spar_internal_error (sparp, "sparp_" "gp_attach_member(): bad member_idx");
#endif
  if (0 < ins_count)
    {
      parent_gp->_.gp.members = (SPART **)t_list_insert_many_before_nth ((caddr_t)old_members, (caddr_t *)new_members, ins_count, insert_before_idx);
      for (memb_ctr = ins_count; memb_ctr--; /*no step*/)
        sparp_gp_attach_member_int (sparp, parent_gp, new_members [memb_ctr], touched_equivs_set_ptr);
    }
  if (NULL != touched_equivs_ptr)
    touched_equivs_ptr[0] = (sparp_equiv_t **)(t_revlist_to_array (touched_equivs_set));
  sparp_equiv_audit_all (sparp, 0);
}

int
sparp_gp_detach_filter_expn_in_cbk (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  if (SPAR_IS_BLANK_OR_VAR (curr))
    {
      dk_set_t *touched_equivs_set_ptr = (dk_set_t *)common_env;
      int idx = curr->_.var.equiv_idx;
      sparp_equiv_t *eq;
      if (SPART_BAD_EQUIV_IDX == idx)
        return 0;
      eq = SPARP_EQUIV (sparp, idx);
      if (NULL != touched_equivs_set_ptr)
        if (0 > dk_set_position (touched_equivs_set_ptr[0], eq))
          t_set_push (touched_equivs_set_ptr, eq);
      sparp_equiv_remove_var (sparp, eq, curr);
      eq->e_const_reads -= 1;
    }
  return 0;
}

int
sparp_gp_distinct_varnames_expn_in_cbk (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  if (SPAR_VARIABLE == SPART_TYPE (curr))
    t_set_push_new_string ((dk_set_t *)common_env, curr->_.var.vname);
  return 0;
}

int
sparp_gp_distinct_varnames_expn_subq_cbk (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_distinct_varnames_of_tree (sparp, curr->_.req_top.pattern, common_env);
  return 0;
}

void
sparp_distinct_varnames_of_tree (sparp_t *sparp, SPART *tree, dk_set_t *acc)
{
  sparp_trav_state_t stss [SPARP_MAX_SYNTDEPTH+2];
  memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
  sparp_gp_trav_int (sparp, tree, stss + 1, acc,
    NULL, NULL,
    sparp_gp_distinct_varnames_expn_in_cbk, NULL, sparp_gp_distinct_varnames_expn_subq_cbk,
    NULL );
}

int
sparp_gp_detach_filter_expn_subq_cbk (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  dk_set_t distinct_varnames = NULL;
  SPART *gp = sts_this->sts_ancestor_gp;
  sparp_distinct_varnames_of_tree (sparp, curr->_.gp.subquery->_.req_top.pattern, &distinct_varnames);
  DO_SET (caddr_t, varname, &distinct_varnames)
    {
      sparp_equiv_t *eq = sparp_equiv_get (sparp, gp, (SPART *)varname, SPARP_EQUIV_GET_NAMESAKES);
      if (NULL != eq)
        eq->e_optional_reads -= 1;
    }
  END_DO_SET();
  return 0;
}

SPART *
sparp_gp_detach_filter (sparp_t *sparp, SPART *parent_gp, int filter_idx, sparp_equiv_t ***touched_equivs_ptr)
{
  sparp_trav_state_t stss [SPARP_MAX_SYNTDEPTH+2];
  SPART *filt;
  SPART **old_filters = parent_gp->_.gp.filters;
  int old_len = BOX_ELEMENTS (old_filters);
  dk_set_t touched_equivs_set = NULL;
  dk_set_t *touched_equivs_set_ptr = ((NULL == touched_equivs_ptr) ? NULL : &touched_equivs_set);
#ifdef DEBUG
  if ((0 > filter_idx) || (old_len <= filter_idx))
    spar_internal_error (sparp, "sparp_" "gp_detach_filter(): bad filter_idx");
#endif
  filt = old_filters [filter_idx];
  memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
  stss[0].sts_ofs_of_curr_in_array = -1;
  stss[1].sts_ancestor_gp = parent_gp;
  sparp_gp_trav_int (sparp, filt, stss + 1, touched_equivs_set_ptr,
    NULL, NULL,
    sparp_gp_detach_filter_expn_in_cbk, NULL, sparp_gp_detach_filter_expn_subq_cbk,
    NULL );
  if (NULL != touched_equivs_ptr)
    touched_equivs_ptr[0] = (sparp_equiv_t **)(t_revlist_to_array (touched_equivs_set));
  parent_gp->_.gp.filters = (SPART **)t_list_remove_nth ((caddr_t)old_filters, filter_idx);
  if (filter_idx >= (old_len - parent_gp->_.gp.glued_filters_count))
    parent_gp->_.gp.glued_filters_count -= 1;
  sparp_equiv_audit_all (sparp, 0);
  return filt;
}

SPART **
sparp_gp_detach_all_filters (sparp_t *sparp, SPART *parent_gp, sparp_equiv_t ***touched_equivs_ptr)
{
  sparp_trav_state_t stss [SPARP_MAX_SYNTDEPTH+2];
  SPART **filters = parent_gp->_.gp.filters;
  int filt_ctr;
  dk_set_t touched_equivs_set = NULL;
  dk_set_t *touched_equivs_set_ptr = ((NULL == touched_equivs_ptr) ? NULL : &touched_equivs_set);
  if (0 != parent_gp->_.gp.glued_filters_count)
    spar_internal_error (sparp, "sparp_" "gp_detach_all_filters(): optimization tries to break the semantics of LEFT OUTER JOIN for OPTIONAL clause");
  DO_BOX_FAST_REV (SPART *, filt, filt_ctr, filters)
    {
      memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
      stss[0].sts_ofs_of_curr_in_array = -1;
      stss[1].sts_ancestor_gp = parent_gp;
      sparp_gp_trav_int (sparp, filt, stss + 1, touched_equivs_set_ptr,
        NULL, NULL,
        sparp_gp_detach_filter_expn_in_cbk, NULL, sparp_gp_detach_filter_expn_subq_cbk,
        NULL );
    }
  END_DO_BOX_FAST_REV;
  if (NULL != touched_equivs_ptr)
    touched_equivs_ptr[0] = (sparp_equiv_t **)(t_revlist_to_array (touched_equivs_set));
  parent_gp->_.gp.filters = (SPART **)t_list (0);
  sparp_equiv_audit_all (sparp, 0);
  return filters;
}


int
sparp_gp_attach_filter_cbk (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  if (SPAR_IS_BLANK_OR_VAR (curr))
    {
      dk_set_t *touched_equivs_set_ptr = (dk_set_t *) common_env;
      SPART *parent_gp;
      sparp_equiv_t *eq;
      int idx = curr->_.var.equiv_idx;
      if (SPART_BAD_EQUIV_IDX != idx)
        spar_internal_error (sparp, "sparp_" "gp_attach_filter_cbk(): attempt to attach a filter with used variable");
      parent_gp = (SPART *)(sts_this[-1].sts_env);
      curr->_.var.selid = t_box_copy (parent_gp->_.gp.selid);
      eq = sparp_equiv_get (sparp, parent_gp, curr, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE | SPARP_EQUIV_ADD_CONST_READ);
      if (NULL != touched_equivs_set_ptr)
        if (0 > dk_set_position (touched_equivs_set_ptr[0], eq))
          t_set_push (touched_equivs_set_ptr, eq);
/*!!!TBD: the following is added to hide errors like 'Variable ':named_graphs' is used in subexpressions of the query but not assigned'.
These errors should be additionally checked when list of global variables is known, say in xsl:for-each-sparql implementation. */
      eq->e_rvr.rvrRestrictions |= ((SPART_VARR_GLOBAL | SPART_VARR_EXPORTED) & curr->_.var.rvr.rvrRestrictions);
    }
  return 0;
}

void
sparp_gp_attach_filter (sparp_t *sparp, SPART *parent_gp, SPART *new_filt, int insert_before_idx, sparp_equiv_t ***touched_equivs_ptr)
{
  sparp_trav_state_t stss [SPARP_MAX_SYNTDEPTH+2];
  SPART **old_filters = parent_gp->_.gp.filters;
  int old_len = BOX_ELEMENTS (old_filters);
  dk_set_t touched_equivs_set = NULL;
  dk_set_t *touched_equivs_set_ptr = ((NULL == touched_equivs_ptr) ? NULL : &touched_equivs_set);
#ifdef DEBUG
  if ((0 > insert_before_idx) || (old_len < insert_before_idx))
    spar_internal_error (sparp, "sparp_" "gp_attach_filter(): bad insert_before_idx");
#endif
  parent_gp->_.gp.filters = (SPART **)t_list_insert_before_nth ((caddr_t)old_filters, (caddr_t)new_filt, insert_before_idx);
  if (insert_before_idx > (old_len - parent_gp->_.gp.glued_filters_count))
    parent_gp->_.gp.glued_filters_count += 1;
  memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
  stss[0].sts_ofs_of_curr_in_array = -1;
  stss[0].sts_env = parent_gp;
  sparp_gp_trav_int (sparp, new_filt, stss + 1, touched_equivs_set_ptr,
    NULL, NULL,
    sparp_gp_attach_filter_cbk, NULL, NULL,
    NULL );
  if (NULL != touched_equivs_ptr)
    touched_equivs_ptr[0] = (sparp_equiv_t **)(t_revlist_to_array (touched_equivs_set));
  sparp_equiv_audit_all (sparp, 0);
}

void
sparp_gp_attach_many_filters (sparp_t *sparp, SPART *parent_gp, SPART **new_filters, int insert_before_idx, sparp_equiv_t ***touched_equivs_ptr)
{
  sparp_trav_state_t stss [SPARP_MAX_SYNTDEPTH+2];
  SPART **old_filters = parent_gp->_.gp.filters;
  int old_len = BOX_ELEMENTS (old_filters);
  int filt_ctr, ins_count;
  dk_set_t touched_equivs_set = NULL;
  dk_set_t *touched_equivs_set_ptr = ((NULL == touched_equivs_ptr) ? NULL : &touched_equivs_set);
#ifdef DEBUG
  if ((0 > insert_before_idx) || (old_len < insert_before_idx))
    spar_internal_error (sparp, "sparp_" "gp_attach_filter(): bad insert_before_idx");
#endif
  ins_count = BOX_ELEMENTS (new_filters);
  if (0 == ins_count)
    {
      if (NULL != touched_equivs_ptr)
        touched_equivs_ptr[0] = (sparp_equiv_t **)t_list (0);
      return;
    }
  parent_gp->_.gp.filters = (SPART **)t_list_insert_many_before_nth ((caddr_t)old_filters, (caddr_t *)new_filters, ins_count, insert_before_idx);
  if (insert_before_idx > (old_len - parent_gp->_.gp.glued_filters_count))
    parent_gp->_.gp.glued_filters_count += ins_count;
  memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
  stss[0].sts_ofs_of_curr_in_array = -1;
  stss[0].sts_env = parent_gp;
  for (filt_ctr = ins_count; filt_ctr--; /*no step*/)
    sparp_gp_trav_int (sparp, new_filters [filt_ctr], stss + 1, touched_equivs_set_ptr,
      NULL, NULL,
      sparp_gp_attach_filter_cbk, NULL, NULL,
      NULL );
  if (NULL != touched_equivs_ptr)
    touched_equivs_ptr[0] = (sparp_equiv_t **)(t_revlist_to_array (touched_equivs_set));
  sparp_equiv_audit_all (sparp, 0);
}

int
sparp_gp_trav_gp_deprecate_expn_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_gp_deprecate (sparp, curr);
  return 0;
}

void
sparp_gp_deprecate (sparp_t *sparp, SPART *gp)
{
  int eq_ctr, memb_ctr, filt_ctr;
#ifdef DEBUG
  if (SPART_BAD_GP_SUBTYPE == gp->_.gp.subtype)
    spar_internal_error (sparp, "sparp_" "gp_deprecate(): gp re-deprecation");
  sparp_equiv_audit_gp (sparp, gp, 0, NULL);
#endif
  gp->_.gp.subtype = SPART_BAD_GP_SUBTYPE;
  SPARP_FOREACH_GP_EQUIV (sparp, gp, eq_ctr, eq)
    {
      if (eq->e_deprecated)
        spar_internal_error (sparp, "sparp_" "gp_deprecate(): equiv re-deprecation");
      eq->e_deprecated = 1;
    }
  END_SPARP_FOREACH_GP_EQUIV;
  DO_BOX_FAST (SPART *, memb, memb_ctr, gp->_.gp.members)
    {
      if (SPAR_GP == memb->type)
        sparp_gp_deprecate (sparp, gp);
    }
  END_DO_BOX_FAST;
  if (SELECT_L == gp->_.gp.subtype)
    sparp_req_top_deprecate (sparp, gp->_.gp.subquery);
  DO_BOX_FAST (SPART *, filt, filt_ctr, gp->_.gp.members)
    {
      sparp_trav_state_t fake_stack;
      sparp_gp_trav_int (sparp, filt, &fake_stack, NULL,
        NULL, NULL,
        NULL, NULL, sparp_gp_trav_gp_deprecate_expn_subq,
        NULL );
    }
  END_DO_BOX_FAST;
}

void
sparp_req_top_deprecate (sparp_t *sparp, SPART *top)
{
  sparp_trav_state_t fake_stack;
  sparp_gp_deprecate (sparp, top->_.req_top.pattern);
  sparp_trav_out_clauses_int (sparp, top, &fake_stack, NULL,
  NULL, NULL,
  NULL, NULL, sparp_gp_trav_gp_deprecate_expn_subq,
  NULL );
}

/* MISC. SPARP_FIND_XXX FUNCTIONS */

SPART *
sparp_find_gp_by_alias_int (sparp_t *sparp, SPART *gp, caddr_t alias)
{
  int ctr;
  if (SPAR_GP != SPART_TYPE (gp))
    return NULL;
  if (!strcmp (gp->_.gp.selid, alias))
    return gp;
  for (ctr = BOX_ELEMENTS_INT_0 (gp->_.gp.members); ctr--; /*no step*/)
    {
      SPART *res = sparp_find_gp_by_alias_int (sparp, gp->_.gp.members[ctr], alias);
      if (NULL != res)
        return res;
    }
  return NULL;
}

SPART *
sparp_find_gp_by_alias (sparp_t *sparp, caddr_t alias)
{
  do {
    SPART *res = sparp_find_gp_by_alias_int (sparp, sparp->sparp_expr->_.req_top.pattern, alias);
    if (NULL != res)
      return res;
    sparp = sparp->sparp_parent_sparp;
    } while (NULL != sparp);
  return NULL;
}

SPART *
sparp_find_triple_of_var (sparp_t *sparp, SPART *gp, SPART *var)
{
  int ctr;
  SPART **members;
  if (NULL == var->_.var.tabid)
    return NULL;
  if (NULL == gp)
    {
      sparp_equiv_t *eq = SPARP_EQUIV (sparp, var->_.var.equiv_idx);
      gp = eq->e_gp;
/*      gp = sparp_find_gp_by_alias_int (sparp, sparp->sparp_expr->_.req_top.pattern, var->_.var.selid);
      if (NULL == gp)
        return NULL;*/
    }
  members = gp->_.gp.members;
  for (ctr = BOX_ELEMENTS_0 (members); ctr--; /*no step*/)
    {
      SPART *memb = members[ctr];
      if (SPAR_TRIPLE != SPART_TYPE (memb))
        continue;
      if (memb->_.triple.tr_fields[var->_.var.tr_idx] == var)
        return memb;
    }
  spar_internal_error (sparp, "sparp_" "find_triple_of_var(): triple not found");
  return NULL; /* Never reached */
}


SPART *
sparp_find_triple_of_var_or_retval (sparp_t *sparp, SPART *gp, SPART *var)
{
  int ctr;
  SPART **members;
  if (NULL == var->_.var.tabid)
    return NULL;
  if (NULL == gp)
    {
      gp = sparp_find_gp_by_alias_int (sparp, sparp->sparp_expr->_.req_top.pattern, var->_.var.selid);
      if (NULL == gp)
        return NULL;
    }
  members = gp->_.gp.members;
  for (ctr = BOX_ELEMENTS_0 (members); ctr--; /*no step*/)
    {
      SPART *memb = members[ctr];
      SPART *fld;
      if (SPAR_TRIPLE != SPART_TYPE (memb))
        continue;
      if (strcmp (memb->_.triple.tabid, var->_.var.tabid))
        continue;
      fld = memb->_.triple.tr_fields[var->_.var.tr_idx];
      if (!SPAR_IS_BLANK_OR_VAR (fld))
        continue;
      if (!strcmp (fld->_.var.vname, var->_.var.vname))
        return memb;
    }
  return NULL;
}

qm_value_t *sparp_find_qmv_of_var_or_retval (sparp_t *sparp, SPART *var_triple, SPART *gp, SPART *var)
{
  quad_map_t *qm;
  qm_value_t *qmv;
  if (NULL == var_triple)
    {
      switch (SPART_TYPE (var))
        {
        case SPAR_BLANK_NODE_LABEL:
        case SPAR_VARIABLE:
          var_triple = sparp_find_triple_of_var (sparp, gp, var);
          break;
        case SPAR_RETVAL:
          var_triple = sparp_find_triple_of_var_or_retval (sparp, gp, var);
          break;
        default:
          spar_internal_error (sparp, "sparp_" "find_qmv_of_var_or_retval(): var expected");
          break;
        }
      if (NULL == var_triple)
        spar_internal_error (sparp, "sparp_" "find_qmv_of_var_or_retval(): can't find triple");
    }
  qm = var_triple->_.triple.tc_list[0]->tc_qm;
  qmv = JSO_FIELD_ACCESS(qm_value_t *, qm, qm_field_map_offsets[var->_.var.tr_idx])[0];
  return qmv;   
}

SPART *sparp_find_gp_by_eq_idx_int (sparp_t *sparp, SPART *gp, ptrlong eq_idx)
{
  int ctr;
  if (SPAR_GP != SPART_TYPE (gp))
    return NULL;
  for (ctr = gp->_.gp.equiv_count; ctr--; /*no step*/)
     {
       if (gp->_.gp.equiv_indexes[ctr] == eq_idx)
         return gp;
     }
  for (ctr = BOX_ELEMENTS_INT_0 (gp->_.gp.members); ctr--; /*no step*/)
    {
      SPART *res = sparp_find_gp_by_eq_idx_int (sparp, gp->_.gp.members[ctr], eq_idx);
      if (NULL != res)
        return res;
    }
  if (SELECT_L == gp->_.gp.subtype)
    return sparp_find_gp_by_eq_idx_int (sparp, gp->_.gp.subquery->_.req_top.pattern, eq_idx);
  return 0;
}

SPART *sparp_find_gp_by_eq_idx (sparp_t *sparp, ptrlong eq_idx)
{
#ifdef DEBUG
  if (SPART_BAD_EQUIV_IDX == eq_idx)
    spar_internal_error (sparp, "sparp_" "find_gp_by_eq_idx(): bad eq_idx");
  if (eq_idx >= sparp->sparp_equiv_count)
    spar_internal_error (sparp, "sparp_" "find_gp_by_eq_idx(): eq_idx is too big");
  if (NULL == sparp->sparp_equivs [eq_idx])
    spar_internal_error (sparp, "sparp_" "find_gp_by_eq_idx(): eq_idx of merged and disabled equiv");
#endif
  do {
      SPART *res = sparp_find_gp_by_eq_idx_int (sparp, sparp->sparp_expr->_.req_top.pattern, eq_idx);
      if (NULL != res)
        return res;
      sparp = sparp->sparp_parent_sparp;
    } while (NULL != sparp);
  return NULL;
}


quad_storage_t *
sparp_find_storage_by_name (ccaddr_t name)
{
  jso_class_descr_t *quad_storage_cd;
  jso_rtti_t *ds_rtti;
  if (NULL == name)
    name = uname_virtrdf_ns_uri_DefaultQuadStorage;
  if ('\0' == name[0])
    return NULL;
  jso_get_cd_and_rtti (
    uname_virtrdf_ns_uri_QuadStorage,
    name,
    &quad_storage_cd, &ds_rtti, 1 );
  if ((NULL != ds_rtti) && (JSO_STATUS_LOADED == ds_rtti->jrtti_status))
    return (quad_storage_t *)(ds_rtti->jrtti_self);
  return NULL;
}

quad_map_t *
sparp_find_quad_map_by_name (ccaddr_t name)
{
  jso_class_descr_t *quad_map_cd;
  jso_rtti_t *ds_rtti;
  jso_get_cd_and_rtti (
    uname_virtrdf_ns_uri_QuadMap,
    name,
    &quad_map_cd, &ds_rtti, 1 );
  if ((NULL != ds_rtti) && (JSO_STATUS_LOADED == ds_rtti->jrtti_status))
    return (quad_map_t *)(ds_rtti->jrtti_self);
  return NULL;
}

SPART *
sparp_find_origin_of_external_var (sparp_t *sparp, SPART *var)
{
  sparp_equiv_t *eq, *esrc;
  int vctr;
#ifdef DEBUG
  if (!(SPART_VARR_EXTERNAL & var->_.var.rvr.rvrRestrictions))
    spar_internal_error (sparp, "sparp_" "find_origin_of_external_var(): non-external variable as argument");
#endif
  eq = SPARP_EQUIV(sparp, var->_.var.equiv_idx);
  if (SPART_BAD_EQUIV_IDX == eq->e_external_src_idx)
    spar_internal_error (sparp, "sparp_" "find_origin_of_external_var(): bad e_external_src_idx");
  esrc = SPARP_EQUIV(sparp, eq->e_external_src_idx);
  while (SPART_BAD_EQUIV_IDX != esrc->e_merge_dest_idx)
    {
      sparp_equiv_t *merged_esrc = SPARP_EQUIV(sparp, esrc->e_merge_dest_idx);
      esrc = merged_esrc;
    }
/* The best origin is triple pattern right in the GP because this increases the chance that SQL optimizer will find a good place for some condition on variable from subquery */
  for (vctr = esrc->e_var_count; vctr--; /*no step*/)
     {
       SPART *source = esrc->e_vars[vctr];
       if ((NULL != source->_.var.tabid) && !strcmp (source->_.var.vname, var->_.var.vname))
         return source;
    }
/* If nothing really good is found then let's find any appropriate item. */
  for (vctr = esrc->e_var_count; vctr--; /*no step*/)
     {
       SPART *source = esrc->e_vars[vctr];
       if (!strcmp (source->_.var.vname, var->_.var.vname))
         return source;
    }
  spar_internal_error (sparp, "sparp_" "find_origin_of_external_var(): external source equiv is found, external source var is not");
  return NULL;
}

SPART *
sparp_find_subexpn_in_retlist (sparp_t *sparp, ccaddr_t varname, SPART **retvals, int return_alias)
{
  int retvalctr;
  DO_BOX_FAST (SPART *, retval, retvalctr, retvals)
    {
      switch (SPART_TYPE (retval))
        {
        case SPAR_ALIAS:
          if (!strcmp (retval->_.alias.aname, varname))
            return (return_alias ? retval : retval->_.alias.arg);
          break;
        case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
          if (!strcmp (retval->_.var.vname, varname))
            return retval;
          break;
        }
    }
  END_DO_BOX_FAST;
  return NULL;
}

int
sparp_subexpn_position1_in_retlist (sparp_t *sparp, ccaddr_t varname, SPART **retvals)
{
  int retvalctr;
  DO_BOX_FAST (SPART *, retval, retvalctr, retvals)
    {
      switch (SPART_TYPE (retval))
        {
        case SPAR_ALIAS:
          if (!strcmp (retval->_.alias.aname, varname))
            return 1+retvalctr;
          break;
        case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
          if (!strcmp (retval->_.var.vname, varname))
            return 1+retvalctr;
          break;
        }
    }
  END_DO_BOX_FAST;
  return 0;
}


/* MISCELLANIA */

SPART **
sparp_get_options_of_tree (sparp_t *sparp, SPART *tree)
{
  switch (SPART_TYPE (tree))
    {
    case SPAR_GP: return tree->_.gp.options; 
    case SPAR_TRIPLE: return tree->_.triple.options; 
    }
  return NULL;
}

void
sparp_validate_options_of_tree (sparp_t *sparp, SPART *tree)
{
  SPART **options = NULL;
  int ttype = SPART_TYPE (tree);
  int has_inference = 0;
  int has_transitive = 0;
  int needs_transitive = 0;
  SPART **subq_orig_retvals = NULL;
  SPART **in_list = NULL;
  SPART **out_list = NULL;
  ptrlong direction = 0;
  int idx;
  switch (ttype)
    {
    case SPAR_GP:
      options = tree->_.gp.options;
      if (SELECT_L == tree->_.gp.subtype)
        subq_orig_retvals = tree->_.gp.subquery->_.req_top.orig_retvals;
      break;
    case SPAR_TRIPLE: options = tree->_.triple.options; break;
    }
  if (NULL == options)
    return;
  for (idx = BOX_ELEMENTS_0 (options) - 2; idx >= 0; idx -= 2)
    {
      ptrlong key = ((ptrlong)(options [idx]));
      SPART *val = options [idx+1];
      switch (key)
        {
        case INFERENCE_L: has_inference = 1; continue;
        case SAME_AS_L: case SAME_AS_S_L: case SAME_AS_O_L: has_inference = 1; continue;
        case TRANSITIVE_L: has_transitive = 1; continue;
        case T_CYCLES_ONLY_L:
        case T_DISTINCT_L:
        case T_END_FLAG_L:
        case T_EXISTS_L:
        case T_MAX_L:
        case T_MIN_L:
        case T_NO_CYCLES_L:
        case T_NO_ORDER_L:
        case T_SHORTEST_ONLY_L:
          needs_transitive++; continue;
        case T_DIRECTION_L: needs_transitive++;
          direction = (ptrlong)(val);
          if ((direction > 3) || (direction < 1))
            spar_error (sparp, "The value of T_DIRECTION option should be an integer value 1, 2 or 3");
          continue;
        case T_IN_L: case T_OUT_L:
          {
            int v_ctr;
            if (NULL == subq_orig_retvals)
              spar_error (sparp, "T_IN and T_OUT options can be used only for SELECT subquery because they should refer to result-set of a subquery");
            ((T_IN_L == key) ? &in_list : &out_list)[0] = val->_.list.items;
            DO_BOX_FAST (SPART *, v, v_ctr, val->_.list.items)
              {
                int pos1_ret;
                SPART *ret;
                if (SPART_VARNAME_IS_GLOB(v->_.var.vname))
                  spar_error (sparp, "Global variable ?%.100s can not be used in %s option",
                    v->_.var.vname, ((T_IN_L == key) ? "T_IN" : "T_OUT") );
                pos1_ret = sparp_subexpn_position1_in_retlist (sparp, v->_.var.vname, subq_orig_retvals);
                if (0 == pos1_ret)
                  spar_error (sparp, "Variable ?%.100s is used in %s option but not in the result-set of a subquery",
                    v->_.var.vname, ((T_IN_L == key) ? "T_IN" : "T_OUT") );
                ret = subq_orig_retvals [pos1_ret-1];
                if (SPAR_ALIAS != SPART_TYPE (ret))
                  subq_orig_retvals [pos1_ret-1] = spartlist (sparp, 4, SPAR_ALIAS, ret, v->_.var.vname, SSG_VALMODE_AUTO);
              }
            END_DO_BOX_FAST;
            continue;
          }
        case T_STEP_L:
          {
            SPART *arg = val->_.alias.arg;
            if (SPAR_VARIABLE == SPART_TYPE (arg))
              {
                caddr_t vname = arg->_.var.vname;
                if (NULL == sparp_find_subexpn_in_retlist (sparp, vname, subq_orig_retvals, 1))
                  spar_error (sparp, "Variable ?%.100s is used in T_STEP option but not in the result-set of a subquery",
                    vname );
              }
            else
              {
                if (strcmp ((caddr_t)arg, "path_id") && strcmp ((caddr_t)arg, "step_no"))
                  spar_error (sparp, "T_STEP option support only \"path_id\" and \"step_no\" output values, not \"%.100s\"",
                    (caddr_t)arg );
              }
            if (sparp_subexpn_position1_in_retlist (sparp, val->_.alias.aname, subq_orig_retvals))
              spar_error (sparp, "The alias ?%.100s of T_STEP option conflicts with same name in the result-set of a subquery",
                (caddr_t)(val->_.alias.aname) );
            continue;
          }
        default: spar_internal_error (sparp, "sparp_" "validate_options_of_tree(): unsupported option");
        }
    }
  switch (ttype)
    {
    case SPAR_GP:
      if (has_inference)
        spar_error (sparp, "Inference options can be specified only for triples, not for group patterns");
      if (needs_transitive && !has_transitive)
        spar_error (sparp, "Transitive-specific options are used without TRANSITIVE option");
      break;
    case SPAR_TRIPLE:
      if (needs_transitive || has_transitive)
        spar_error (sparp, "Transitive-specific options can be specified only for group patterns, not for triples");
      break;
    }
  if (has_transitive)
    {
      if (NULL == in_list)
        spar_error (sparp, "TRANSITIVE option require T_IN option as well");
      if (NULL == out_list)
        spar_error (sparp, "TRANSITIVE option require T_OUT option as well");
      if (BOX_ELEMENTS (in_list) != BOX_ELEMENTS (out_list))
        spar_error (sparp, "Mismatch in length of T_IN and T_OUT lists of names");
    }
}

SPART *
sparp_get_option (sparp_t *sparp, ptrlong key, SPART **options)
{
  int idx;
  for (idx = BOX_ELEMENTS_0 (options) - 2; idx >= 0; idx -= 2)
    {
      if (((ptrlong)(options [idx])) == key)
        return options [idx+1];
    }
  return (SPART *)NULL;
}

caddr_t
spar_var_name_of_ret_column (SPART *tree)
{
  switch (DV_TYPE_OF (tree))
    {
    case DV_ARRAY_OF_POINTER:
      switch (tree->type)
        {
        case SPAR_ALIAS: return spar_var_name_of_ret_column (tree->_.alias.arg); 
        case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL: return tree->_.var.vname;
        }
      return NULL;
/*
    case DV_STRING: case DV_UNAME:
      return (ccaddr_t)tree;
*/
    }
  return NULL;
}

caddr_t
spar_alias_name_of_ret_column (SPART *tree)
{
  if ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree)) &&
    (SPAR_ALIAS == tree->type) )
    return tree->_.alias.aname;
  return spar_var_name_of_ret_column (tree);
}

/* DEBUGGING */

const char *
spart_dump_opname (ptrlong opname, int is_op)
{

  if (is_op)
    switch (opname)
    {
    case BOP_AND: return "boolean operation 'AND'";
    case BOP_OR: return "boolean operation 'OR'";
    case BOP_NOT: return "boolean operation 'NOT'";
    case BOP_EQ: return "boolean operation '='";
    case BOP_NEQ: return "boolean operation '!='";
    case BOP_LT: return "boolean operation '<'";
    case BOP_LTE: return "boolean operation '<='";
    case BOP_GT: return "boolean operation '>'";
    case BOP_GTE: return "boolean operation '>='";
    /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! return "boolean operation 'like'"; */
    case BOP_SAME: return "boolean operation '=='";
    case BOP_NSAME: return "boolean operation '!=='";
    case BOP_PLUS: return "arithmetic operation '+'";
    case BOP_MINUS: return "arithmetic operation '-'";
    case BOP_TIMES: return "arithmetic operation '*'";
    case BOP_DIV: return "arithmetic operation 'div'";
    case BOP_MOD: return "arithmetic operation 'mod'";
    }

  switch (opname)
    {
    case _LBRA: return "quad mapping parent group name";
    case ASC_L: return "ascending order";
    case ASK_L: return "ASK result-mode";
    case BOUND_L: return "BOUND builtin";
    case CONSTRUCT_L: return "CONSTRUCT result-mode";
    case CREATE_L: return "quad mapping name";
    case DATATYPE_L: return "DATATYPE builtin";
    case DESC_L: return "descending";
    case DESCRIBE_L: return "DESCRIBE result-mode";
    case DISTINCT_L: return "SELECT DISTINCT result-mode";
    case false_L: return "false boolean";
    case FILTER_L: return "FILTER";
    case FROM_L: return "FROM";
    case GRAPH_L: return "GRAPH gp";
    case IRI_L: return "IRI builtin";
    case IN_L: return "IN";
    case isBLANK_L: return "isBLANK builtin";
    case isIRI_L: return "isIRI builtin";
    case isLITERAL_L: return "isLITERAL builtin";
    case isURI_L: return "isURI builtin";
    case LANG_L: return "LANG builtin";
    case LANGMATCHES_L: return "LANGMATCHES builtin";
    case LIKE_L: return "LIKE";
    case LIMIT_L: return "LIMIT";
    case NAMED_L: return "NAMED";
    case NIL_L: return "NIL";
    case OBJECT_L: return "OBJECT";
    case OFFSET_L: return "OFFSET";
    case OPTIONAL_L: return "OPTIONAL gp";
    case ORDER_L: return "ORDER";
    case PREDICATE_L: return "PREDICATE";
    case PREFIX_L: return "PREFIX";
    case REGEX_L: return "REGEX builtin";
    case SAMETERM_L: return "sameTerm builtin";
    case SELECT_L: return "SELECT result-mode";
    case STR_L: return "STR builtin";
    case SUBJECT_L: return "SUBJECT";
    case true_L: return "true boolean";
    case UNION_L: return "UNION gp";
    case WHERE_L: return "WHERE gp";

    case SPAR_BLANK_NODE_LABEL: return "blank node label";
    case SPAR_BUILT_IN_CALL: return "built-in call";
    case SPAR_FUNCALL: return "function call";
    case SPAR_GP: return "group pattern";
    case SPAR_LIT: return "lit";
    case SPAR_QNAME: return "QName";
    /*case SPAR_QNAME_NS: return "QName NS";*/
    case SPAR_REQ_TOP: return "SPARQL query";
    case SPAR_VARIABLE: return "Variable";
    case SPAR_TRIPLE: return "Triple";
  }
  return NULL;
}


char *spart_dump_addr (void *addr)
{
  return NULL;
}


void spart_dump_long (void *addr, dk_session_t *ses, int is_op)
{
  if (!IS_BOX_POINTER(addr))
    {
      const char *op_descr = spart_dump_opname((ptrlong)(addr), is_op);
      if (NULL != op_descr)
	{
	  SES_PRINT (ses, op_descr);
	  return;
	}
    }
  else
    {
      char *addr_descr = spart_dump_addr(addr);
      if (NULL != addr_descr)
	{
	  SES_PRINT (ses, addr_descr);
	  return;
	}
    }
  {
    char buf[30];
    sprintf (buf, "LONG " BOXINT_FMT, unbox (addr));
    SES_PRINT (ses, buf);
    return;
  }
}

void spart_dump_varr_bits (dk_session_t *ses, int varr_bits)
{
  char buf[200];
  char *tail = buf;
#define VARR_BIT(b,txt) \
  do { \
    if (varr_bits & (b)) \
      { const char *t = (txt); while ('\0' != (tail[0] = (t++)[0])) tail++; } \
    } while (0);
  VARR_BIT (SPART_VARR_CONFLICT, " CONFLICT");
  VARR_BIT (SPART_VARR_GLOBAL, " GLOBAL");
  VARR_BIT (SPART_VARR_EXTERNAL, " EXTERNAL");
  VARR_BIT (SPART_VARR_ALWAYS_NULL, " always-NULL");
  VARR_BIT (SPART_VARR_NOT_NULL, " notNULL");
  VARR_BIT (SPART_VARR_FIXED, " fixed");
  VARR_BIT (SPART_VARR_TYPED, " typed");
  VARR_BIT (SPART_VARR_IS_LIT, " lit");
  VARR_BIT (SPART_VARR_IRI_CALC, " IRI-namecalc");
  VARR_BIT (SPART_VARR_SPRINTFF, " SprintfF");
  VARR_BIT (SPART_VARR_IS_BLANK, " bnode");
  VARR_BIT (SPART_VARR_IS_IRI, " IRI");
  VARR_BIT (SPART_VARR_IS_REF, " reference");
  VARR_BIT (SPART_VARR_EXPORTED, " exported");
  session_buffered_write (ses, buf, tail-buf);
}

void spart_dump_rvr (dk_session_t *ses, rdf_val_range_t *rvr)
{
  char buf[300];
  char *tail = buf;
  int len;
  int varr_bits = rvr->rvrRestrictions;
  ccaddr_t fixed_dt = rvr->rvrDatatype;
  ccaddr_t fixed_val = rvr->rvrFixedValue;
  spart_dump_varr_bits (ses, varr_bits);
  if (varr_bits & SPART_VARR_TYPED)
    {
      len = sprintf (tail, "; dt=%.100s", fixed_dt);
      tail += len;
    }
  if (varr_bits & SPART_VARR_FIXED)
    {
      dtp_t dtp = DV_TYPE_OF (fixed_val);
      const char *dtp_name = dv_type_title (dtp);
      const char *meta = "";
      const char *lit_dt = NULL;
      const char *lit_lang = NULL;
      if (DV_ARRAY_OF_POINTER == dtp)
        {
          SPART *fixed_tree = ((SPART *)fixed_val);
          if (SPAR_QNAME == SPART_TYPE (fixed_tree))
            {
              meta = " QName";
              fixed_val = fixed_tree->_.lit.val;
            }
          else if (SPAR_LIT == SPART_TYPE (fixed_tree))
            {
              meta = " lit";
              fixed_val = fixed_tree->_.lit.val;
              lit_dt = fixed_tree->_.lit.datatype;
              lit_lang = fixed_tree->_.lit.language;
            }
          dtp = DV_TYPE_OF (fixed_val);
          dtp_name = dv_type_title (dtp);
        }
      if (IS_STRING_DTP (dtp))
        len = sprintf (tail, "; fixed%s %s '%.100s'", meta, dtp_name, fixed_val);
      else if (DV_LONG_INT == dtp)
        len = sprintf (tail, "; fixed%s %s %ld", meta, dtp_name, (long)(unbox (fixed_val)));
      else
        len = sprintf (tail, "; fixed%s %s", meta, dtp_name);
      tail += len;
      if (NULL != lit_dt)
        tail += sprintf (tail, "^^'%.50s'", lit_dt);
      if (NULL != lit_lang)
        tail += sprintf (tail, "@'%.50s'", lit_lang);
      SES_PRINT (ses, buf);
    }
  if (rvr->rvrIriClassCount)
    {
      int iricctr;
      SES_PRINT (ses, "; IRI classes");
      for (iricctr = 0; iricctr < rvr->rvrIriClassCount; iricctr++)
        {
          SES_PRINT (ses, " ");
          SES_PRINT (ses, rvr->rvrIriClasses[iricctr]);
        }
    }
  if (rvr->rvrRedCutCount)
    {
      int rcctr;
      SES_PRINT (ses, "; Not one of");
      for (rcctr = 0; rcctr < rvr->rvrRedCutCount; rcctr++)
        {
          SES_PRINT (ses, " ");
          SES_PRINT (ses, rvr->rvrRedCuts[rcctr]);
        }
    }
  if (rvr->rvrSprintffs)
    {
      int sffctr;
      SES_PRINT (ses, "; Formats ");
      for (sffctr = 0; sffctr < rvr->rvrSprintffCount; sffctr++)
        {
          SES_PRINT (ses, " |");
          SES_PRINT (ses, rvr->rvrSprintffs[sffctr]);
          SES_PRINT (ses, "|");
        }
    }
}

void
spart_dump_eq (int eq_ctr, sparp_equiv_t *eq, dk_session_t *ses)
{
  int varname_count, varname_ctr, var_ctr;
  char buf[100];
  session_buffered_write_char ('\n', ses);
  if (NULL == eq)
    {
      sprintf (buf, "#%d: merged and destroyed", eq_ctr);
      SES_PRINT (ses, buf);
      return;
    }
  sprintf (buf, "#%d: %s( %d subv (%d bindings), %d recv, %d gspo, %d const, %d opt, %d subq:", eq_ctr,
  (eq->e_deprecated ? "deprecated " : ""),
    BOX_ELEMENTS_INT_0(eq->e_subvalue_idxs), (int)(eq->e_nested_bindings), BOX_ELEMENTS_INT_0(eq->e_receiver_idxs),
    (int)(eq->e_gspo_uses), (int)(eq->e_const_reads), (int)(eq->e_optional_reads), (int)(eq->e_subquery_uses) );
  SES_PRINT (ses, buf);
  varname_count = BOX_ELEMENTS (eq->e_varnames);
  for (varname_ctr = 0; varname_ctr < varname_count; varname_ctr++)
    {
      SES_PRINT (ses, " ");
      SES_PRINT (ses, eq->e_varnames[varname_ctr]);
    }
  SES_PRINT (ses, " in");
  for (var_ctr = 0; var_ctr < eq->e_var_count; var_ctr++)
    {
      SPART *var = eq->e_vars[var_ctr];
      SES_PRINT (ses, " ");
      SES_PRINT (ses, ((NULL != var->_.var.tabid) ? var->_.var.tabid : var->_.var.selid));
    }
  SES_PRINT (ses, ";"); spart_dump_rvr (ses, &(eq->e_rvr));
  SES_PRINT (ses, ")");
}

void
spart_dump (void *tree_arg, dk_session_t *ses, int indent, const char *title, int hint)
{
  SPART *tree = (SPART *) tree_arg;
  int ctr;
  if ((NULL == tree) && (hint < 0))
    return;
  if (indent > 0)
    {
      session_buffered_write_char ('\n', ses);
      for (ctr = indent; ctr--; /*no step*/ )
        session_buffered_write_char (' ', ses);
    }
  if (title)
    {
      SES_PRINT (ses, title);
      SES_PRINT (ses, ": ");
    }
  if ((-1 == hint) && IS_BOX_POINTER(tree))
    {
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
        {
          SES_PRINT (ses, "special: ");
          hint = 0;
        }
      else if ((SPART_HEAD >= BOX_ELEMENTS(tree)) || IS_BOX_POINTER (tree->type))
        {
          SES_PRINT (ses, "special: ");
          hint = -2;
        }
    }
  if (!hint)
    hint = DV_TYPE_OF (tree);
  switch (hint)
    {
    case -1:
      {
	int childrens;
	char buf[50];
	if (!IS_BOX_POINTER(tree))
	  {
	    SES_PRINT (ses, "[");
	    spart_dump_long (tree, ses, 0);
	    SES_PRINT (ses, "]");
	    goto printed;
	  }
        sprintf (buf, "(line %d) ", (int) (ptrlong) tree->srcline);
        SES_PRINT (ses, buf);
	childrens = BOX_ELEMENTS (tree);
	switch (tree->type)
	  {
	  case SPAR_ALIAS:
	    {
	      sprintf (buf, "ALIAS:");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.alias.aname, ses, indent+2, "ALIAS NAME", 0);
	      spart_dump (tree->_.alias.arg, ses, indent+2, "VALUE", -1);
		/* _.alias.native is temp so it is not printed */
	      break;
	    }
	  case SPAR_BLANK_NODE_LABEL:
	    {
	      sprintf (buf, "BLANK NODE:");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.var.vname, ses, indent+2, "NAME", 0);
	      spart_dump (tree->_.var.selid, ses, indent+2, "SELECT ID", 0);
	      spart_dump (tree->_.var.tabid, ses, indent+2, "TABLE ID", 0);
	      break;
	    }
	  case SPAR_BUILT_IN_CALL:
	    {
	      sprintf (buf, "BUILT-IN CALL:");
	      SES_PRINT (ses, buf);
	      spart_dump_long ((void *)(tree->_.builtin.btype), ses, -1);
	      spart_dump (tree->_.builtin.args, ses, indent+2, "ARGUMENT", -2);
	      break;
	    }
	  case SPAR_FUNCALL:
	    {
	      int argctr, argcount = BOX_ELEMENTS (tree->_.funcall.argtrees);
	      spart_dump (tree->_.funcall.qname, ses, indent+2, "FUNCTION NAME", 0);
              if (tree->_.funcall.agg_mode)
		spart_dump ((void *)(tree->_.funcall.agg_mode), ses, indent+2, "AGGREGATE MODE", 0);
	      for (argctr = 0; argctr < argcount; argctr++)
		spart_dump (tree->_.funcall.argtrees[argctr], ses, indent+2, "ARGUMENT", -1);
	      break;
	    }
	  case SPAR_GP:
            {
              int eq_count, eq_ctr;
	      sprintf (buf, "GRAPH PATTERN:");
	      SES_PRINT (ses, buf);
	      spart_dump_long ((void *)(tree->_.gp.subtype), ses, -1);
	      spart_dump (tree->_.gp.members, ses, indent+2, "MEMBERS", -2);
	      spart_dump (tree->_.gp.subquery, ses, indent+2, "SUBQUERY", -1);
	      spart_dump (tree->_.gp.filters, ses, indent+2, "FILTERS", -2);
	      spart_dump (tree->_.gp.selid, ses, indent+2, "SELECT ID", 0);
	      spart_dump (tree->_.gp.options, ses, indent+2, "OPTIONS", -2);
	      /* spart_dump (tree->_.gp.results, ses, indent+2, "RESULTS", -2); */
              session_buffered_write_char ('\n', ses);
	      for (ctr = indent+2; ctr--; /*no step*/ )
	        session_buffered_write_char (' ', ses);
	      sprintf (buf, "EQUIVS:");
	      SES_PRINT (ses, buf);
              eq_count = tree->_.gp.equiv_count;
	      for (eq_ctr = 0; eq_ctr < eq_count; eq_ctr++)
                {
	          sprintf (buf, " %d", (int)(tree->_.gp.equiv_indexes[eq_ctr]));
		  SES_PRINT (ses, buf);
                }
	      break;
	    }
	  case SPAR_LIT:
	    {
	      sprintf (buf, "LITERAL:");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.lit.val, ses, indent+2, "VALUE", 0);
              if (tree->_.lit.datatype)
	        spart_dump (tree->_.lit.datatype, ses, indent+2, "DATATYPE", 0);
              if (tree->_.lit.language)
	        spart_dump (tree->_.lit.language, ses, indent+2, "LANGUAGE", 0);
	      break;
	    }
	  case SPAR_QNAME:
	    {
	      sprintf (buf, "QNAME:");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.lit.val, ses, indent+2, "IRI", 0);
	      break;
	    }
	  /*case SPAR_QNAME_NS:
	    {
	      sprintf (buf, "QNAME_NS:");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.lit.val, ses, indent+2, "NAMESPACE", 0);
	      break;
	    }*/
	  case SPAR_REQ_TOP:
	    {
	      sprintf (buf, "REQUEST TOP NODE (");
	      SES_PRINT (ses, buf);
	      spart_dump_long ((void *)(tree->_.req_top.subtype), ses, 1);
	      SES_PRINT (ses, "):");
              if (NULL != tree->_.req_top.retvalmode_name)
	        spart_dump (tree->_.req_top.retvalmode_name, ses, indent+2, "VALMODE FOR RETVALS", 0);
              if (NULL != tree->_.req_top.formatmode_name)
	        spart_dump (tree->_.req_top.formatmode_name, ses, indent+2, "SERIALIZATION FORMAT", 0);
              if (NULL != tree->_.req_top.storage_name)
	        spart_dump (tree->_.req_top.storage_name, ses, indent+2, "RDF DATA STORAGE", 0);
	      if (IS_BOX_POINTER(tree->_.req_top.retvals))
	        spart_dump (tree->_.req_top.retvals, ses, indent+2, "RETVALS", -2);
	      else
	        spart_dump (tree->_.req_top.retvals, ses, indent+2, "RETVALS", 0);
	      spart_dump (tree->_.req_top.retselid, ses, indent+2, "RETVALS SELECT ID", 0);
	      spart_dump (tree->_.req_top.sources, ses, indent+2, "SOURCES", -2);
	      spart_dump (tree->_.req_top.pattern, ses, indent+2, "PATTERN", -1);
	      spart_dump (tree->_.req_top.order, ses, indent+2, "ORDER", -1);
	      spart_dump ((void *)(tree->_.req_top.limit), ses, indent+2, "LIMIT", 0);
	      spart_dump ((void *)(tree->_.req_top.offset), ses, indent+2, "OFFSET", 0);
	      break;
	    }
	  case SPAR_VARIABLE:
	    {
	      sprintf (buf, "VARIABLE:");
	      SES_PRINT (ses, buf);
              spart_dump_rvr (ses, &(tree->_.var.rvr));
              if (NULL != tree->_.var.tabid)
                {
                  static const char *field_full_names[] = {"graph", "subject", "predicate", "object"};
                  sprintf (buf, " (%s)", field_full_names[tree->_.var.tr_idx]); SES_PRINT (ses, buf);
                }
	      spart_dump (tree->_.var.vname, ses, indent+2, "NAME", 0);
	      spart_dump (tree->_.var.selid, ses, indent+2, "SELECT ID", 0);
	      spart_dump (tree->_.var.tabid, ses, indent+2, "TABLE ID", 0);
	      spart_dump ((void*)(tree->_.var.equiv_idx), ses, indent+2, "EQUIV", 0);
	      break;
	    }
	  case SPAR_TRIPLE:
	    {
	      sprintf (buf, "TRIPLE:");
	      SES_PRINT (ses, buf);
	      if (tree->_.triple.ft_type)
                {
	          sprintf (buf, " ft predicate %d", (int)(tree->_.triple.ft_type));
	          SES_PRINT (ses, buf);
                }
              if (NULL != tree->_.triple.options)
                spart_dump (tree->_.triple.options, ses, indent+2, "OPTIONS", -2);
	      spart_dump (tree->_.triple.tr_graph, ses, indent+2, "GRAPH", -1);
	      spart_dump (tree->_.triple.tr_subject, ses, indent+2, "SUBJECT", -1);
	      spart_dump (tree->_.triple.tr_predicate, ses, indent+2, "PREDICATE", -1);
	      spart_dump (tree->_.triple.tr_object, ses, indent+2, "OBJECT", -1);
	      spart_dump (tree->_.triple.selid, ses, indent+2, "SELECT ID", 0);
	      spart_dump (tree->_.triple.tabid, ses, indent+2, "TABLE ID", 0);
	      spart_dump (tree->_.triple.options, ses, indent+2, "OPTIONS", -2);
	      break;
	    }
	  case BOP_EQ: case BOP_NEQ:
	  case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
	  /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! */
	  case BOP_SAME: case BOP_NSAME:
	  case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
	  case BOP_AND: case BOP_OR: case BOP_NOT:
	    {
	      sprintf (buf, "OPERATOR EXPRESSION ("/*, tree->type*/);
	      SES_PRINT (ses, buf);
	      spart_dump_long ((void *)(tree->type), ses, 1);
	      SES_PRINT (ses, "):");
	      spart_dump (tree->_.bin_exp.left, ses, indent+2, "LEFT", -1);
	      spart_dump (tree->_.bin_exp.right, ses, indent+2, "RIGHT", -1);
	      break;
	    }
          case ORDER_L:
            {
	      sprintf (buf, "ORDERING ("/*, tree->_.oby.direction*/);
	      SES_PRINT (ses, buf);
	      spart_dump_long ((void *)(tree->_.oby.direction), ses, 1);
	      SES_PRINT (ses, "):");
	      spart_dump (tree->_.oby.expn, ses, indent+2, "CRITERION", -1);
	      break;
            }
	  case FROM_L:
	    {
	      sprintf (buf, "FROM (default):");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.lit.val, ses, indent+2, "IRI", 0);
	      break;
	    }
	  case NAMED_L:
	    {
	      sprintf (buf, "FROM NAMED:");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.lit.val, ses, indent+2, "IRI", 0);
	      break;
	    }
	  case SPAR_LIST:
	    {
	      sprintf (buf, "LIST:");
	      SES_PRINT (ses, buf);
	      spart_dump (tree->_.list.items, ses, indent+2, "ITEMS", -2);
	    }
	  default:
	    {
	      sprintf (buf, "NODE OF TYPE %ld (", (ptrlong)(tree->type));
	      SES_PRINT (ses, buf);
	      spart_dump_long ((void *)(tree->type), ses, 0);
	      sprintf (buf, ") with %d children:\n", childrens-SPART_HEAD);
	      SES_PRINT (ses, buf);
	      for (ctr = SPART_HEAD; ctr < childrens; ctr++)
		spart_dump (((void **)(tree))[ctr], ses, indent+2, NULL, 0);
	      break;
	    }
	  }
	break;
      }
    case DV_ARRAY_OF_POINTER:
      {
	int childrens = BOX_ELEMENTS (tree);
	char buf[50];
	sprintf (buf, "ARRAY with %d children: {", childrens);
	SES_PRINT (ses,	buf);
	for (ctr = 0; ctr < childrens; ctr++)
	  spart_dump (((void **)(tree))[ctr], ses, indent+2, NULL, 0);
	if (indent > 0)
	  {
	    session_buffered_write_char ('\n', ses);
	    for (ctr = indent; ctr--; /*no step*/ )
	      session_buffered_write_char (' ', ses);
	  }
	SES_PRINT (ses,	" }");
	break;
      }
    case -2:
      {
	int childrens = BOX_ELEMENTS (tree);
	char buf[50];
	if (0 == childrens)
	  {
	    SES_PRINT (ses, "EMPTY ARRAY");
	    break;
	  }
	sprintf (buf, "ARRAY OF NODES with %d children: {", childrens);
	SES_PRINT (ses,	buf);
	for (ctr = 0; ctr < childrens; ctr++)
	  spart_dump (((void **)(tree))[ctr], ses, indent+2, NULL, -1);
	if (indent > 0)
	  {
	    session_buffered_write_char ('\n', ses);
	    for (ctr = indent; ctr--; /*no step*/ )
	    session_buffered_write_char (' ', ses);
	  }
	SES_PRINT (ses,	" }");
	break;
      }
#if 0
    case -3:
      {
	char **execname = (char **)id_hash_get (xpf_reveng, (caddr_t)(&tree));
	SES_PRINT (ses, "native code started at ");
	if (NULL == execname)
	  {
	    char buf[30];
	    sprintf (buf, "0x%p", (void *)tree);
	    SES_PRINT (ses, buf);
	  }
	else
	  {
	    SES_PRINT (ses, "label '");
	    SES_PRINT (ses, execname[0]);
	    SES_PRINT (ses, "'");
	  }
	break;
      }
#endif
    case DV_LONG_INT:
      {
	char buf[30];
	sprintf (buf, "LONG %ld", (long)(unbox ((ccaddr_t)tree)));
	SES_PRINT (ses,	buf);
	break;
      }
    case DV_STRING:
      {
	SES_PRINT (ses,	"STRING `");
	SES_PRINT (ses,	(char *)(tree));
	SES_PRINT (ses,	"'");
	break;
      }
    case DV_UNAME:
      {
	SES_PRINT (ses,	"UNAME `");
	SES_PRINT (ses,	(char *)(tree));
	SES_PRINT (ses,	"'");
	break;
      }
    case DV_SYMBOL:
      {
	SES_PRINT (ses,	"SYMBOL `");
	SES_PRINT (ses,	(char *)(tree));
	SES_PRINT (ses,	"'");
	break;
      }
    case DV_NUMERIC:
      {
        numeric_t n = (numeric_t)(tree);
        char buf[0x100];
	SES_PRINT (ses,	"NUMERIC ");
        numeric_to_string (n, buf, 0x100);
	SES_PRINT (ses,	buf);
      }
    default:
      {
	char buf[30];
	sprintf (buf, "UNEXPECTED TYPE (%u)", (unsigned)(DV_TYPE_OF (tree)));
	SES_PRINT (ses,	buf);
	break;
      }
    }
printed:
  if (0 == indent)
    session_buffered_write_char ('\n', ses);
}


void 
sparp_dbg_gp_print (sparp_t *sparp, SPART *tree)
{
  int eq_ctr, eq_count;
  eq_count = tree->_.gp.equiv_count;
  SPARP_FOREACH_GP_EQUIV(sparp,tree,eq_ctr,eq)
    {
      int varname_count, varname_ctr;
      spar_dbg_printf ((" ( %d subv (%d bindings), %d recv, %d gspo, %d const, %d opt, %d subq:",
      BOX_ELEMENTS_INT_0(eq->e_subvalue_idxs), (int)(eq->e_nested_bindings), BOX_ELEMENTS_INT_0(eq->e_receiver_idxs),
        (int)(eq->e_gspo_uses), (int)(eq->e_const_reads), (int)(eq->e_optional_reads), (int)(eq->e_subquery_uses) ));
      varname_count = BOX_ELEMENTS (eq->e_varnames);
      for (varname_ctr = 0; varname_ctr < varname_count; varname_ctr++)
        {
          spar_dbg_printf ((" %s", eq->e_varnames[varname_ctr]));
        }
      spar_dbg_printf ((")"));
    } END_SPARP_FOREACH_GP_EQUIV;
  spar_dbg_printf (("\n"));
}

int sparp_valmode_is_correct (ssg_valmode_t fmt)
{
  jso_rtti_t *rtti;
  if (!IS_BOX_POINTER (fmt))
    return 1;
  if ((qm_format_default_iri_ref == fmt) || (qm_format_default_iri_ref_nullable == fmt) ||
    (qm_format_default_ref == fmt) || (qm_format_default_ref_nullable == fmt) ||
    (qm_format_default == fmt) || (qm_format_default_nullable == fmt) )
    return 2;
  rtti = gethash (fmt, jso_rttis_of_structs);
  if ((NULL != rtti) && (fmt == rtti->jrtti_self))
    {
      return 3;
    }
#ifndef NDEBUG
  box_tag_modify (fmt, DV_XQI);
#endif
  return 0;
}

void sparp_jso_validate_format (sparp_t *sparp, ssg_valmode_t fmt)
{
  if (!sparp_valmode_is_correct (fmt))
    spar_internal_error (sparp, "sparp_jso_validate_format(): custom format does not have JSO RTTI");
}

#if 0
void ssg_jso_validate_format (spar_sqlgen_t *ssg, ssg_valmode_t fmt)
{
  if (!sparp_valmode_is_correct (fmt))
    spar_sqlprint_error ("ssg_jso_validate_format(): custom format does not have JSO RTTI");
}
#endif
