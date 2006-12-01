/*
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

/* PART 1. EXPRESSION TERM REWRITING */

int
sparp_gp_trav_int (sparp_t *sparp, SPART *tree,
  void **trav_env_this, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 )
{
  SPART **sub_gps = NULL;
  SPART **sub_expns = NULL;
  SPART *fields[2];
  int sub_gp_count = 0, sub_expn_count = 0, ctr;
  int tree_cat = 0;
  int in_rescan = 0;
  void *save_trav_env_this = BADBEEF_BOX; /* To keep gcc 4.0 happy */
  int retcode = 0;
  if (trav_env_this == (sparp->sparp_trav_envs + SPARP_MAX_SYNTDEPTH))
    spar_error (sparp, "The nesting depth of subexpressions exceed limits of SPARQL compiler");

scan_for_children:
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    {
      tree_cat = 2;
      goto cat_recognized;
    }
  switch (tree->type)
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
	sub_expn_count = tree->_.funcall.argcount;
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
      spar_error (sparp, "Internal SPARQL compiler error: TOP of request as subexpression");
    case SPAR_TRIPLE:
      {
        tree_cat = 0;
        sub_expns = tree->_.triple.tr_fields;
	sub_expn_count = SPART_TRIPLE_FIELDS_COUNT;
        break;
      }
    case BOP_EQ: case BOP_NEQ:
    case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
    /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! */
    case BOP_SAME: case BOP_NSAME:
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
    case BOP_AND: case BOP_OR: case BOP_NOT:
      {
        tree_cat = 1;
        sub_expns = fields;
	sub_expn_count = 2;
        fields[0] = tree->_.bin_exp.left;
        fields[1] = tree->_.bin_exp.right;
        break;
      }
    default:
      {
        spar_error (sparp, "Internal SPARQL compiler error: unsupported subexpression type %d", tree->type);
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
	retcode = gp_in_cbk (sparp, tree, trav_env_this, common_env);
      else
        retcode = 0;
      break;
    case 1:
      if (expn_in_cbk)
	retcode = expn_in_cbk (sparp, tree, trav_env_this, common_env);
      else
        retcode = 0;
      break;
    case 2:
      if (literal_cbk)
        {
	  retcode = literal_cbk (sparp, tree, trav_env_this, common_env);
          return retcode;
        }
      return 0;
    default: GPF_T;
    }
  if (retcode & SPAR_GPT_COMPLETED)
    return SPAR_GPT_COMPLETED;
  if (retcode & SPAR_GPT_NODOWN)
    return 0;
  save_trav_env_this = trav_env_this;
  if (retcode & SPAR_GPT_ENV_PUSH)
    {
      trav_env_this++;
      trav_env_this[0] = NULL;
    }
  if (retcode & SPAR_GPT_RESCAN)
    {
      in_rescan = 1;
      goto scan_for_children; /* see above */
    }

process_children:
  for (ctr = 0; ctr < sub_gp_count; ctr++)
    {
      retcode = sparp_gp_trav_int (sparp, sub_gps[ctr], trav_env_this, common_env, gp_in_cbk, gp_out_cbk, expn_in_cbk, expn_out_cbk, literal_cbk);
      if (retcode & SPAR_GPT_COMPLETED)
        return SPAR_GPT_COMPLETED;
    }
  if (sub_expn_count && ((NULL != expn_in_cbk) || (NULL != expn_out_cbk) || (NULL != literal_cbk)))
    {
      for (ctr = 0; ctr < sub_expn_count; ctr++)
        {
          retcode = sparp_gp_trav_int (sparp, sub_expns[ctr], trav_env_this, common_env, gp_in_cbk, gp_out_cbk, expn_in_cbk, expn_out_cbk, literal_cbk);
          if (retcode & SPAR_GPT_COMPLETED)
            return SPAR_GPT_COMPLETED;
        }
    }
  switch (tree_cat)
    {
    case 0:
      if (gp_out_cbk)
	retcode = gp_out_cbk (sparp, tree, save_trav_env_this, common_env);
      else
        retcode = 0;
      break;
    case 1:
      if (expn_out_cbk)
	retcode = expn_out_cbk (sparp, tree, save_trav_env_this, common_env);
      else
        retcode = 0;
      break;
    }
  if (retcode & SPAR_GPT_COMPLETED)
    return SPAR_GPT_COMPLETED;
  return 0;
}

int
sparp_gp_trav (sparp_t *sparp, SPART *root, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 )
{
  int res;
#ifdef DEBUG
  if (sparp->sparp_trav_running)
    spar_internal_error (sparp, "sparp_" "gp_trav() re-entered");
  sparp->sparp_trav_running = 1;
#endif
  memset (sparp->sparp_trav_envs, 0, sizeof (void *) * SPARP_MAX_SYNTDEPTH);
  res = sparp_gp_trav_int (sparp, root, sparp->sparp_trav_envs + 1, common_env, gp_in_cbk, gp_out_cbk, expn_in_cbk, expn_out_cbk, literal_cbk);
#ifdef DEBUG
  sparp->sparp_trav_running = 0;
#endif
  return (res & SPAR_GPT_COMPLETED);
}

/* Composing list of retvals instead of '*'.
\c trav_env_this is not used.
\c common_env points to dk_set_t of collected distinct variable names. */

int sparp_gp_trav_list_retvals (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  caddr_t varname;
  if (SPAR_VARIABLE != curr->type) /* Not a variable ? -- nothing to do */
    return 0;
  varname = curr->_.var.vname;
  if (SPART_VARNAME_IS_GLOB(varname)) /* Query run-time env or external query param ? -- not in result-set */
    return SPAR_GPT_NODOWN;
  DO_SET (caddr_t, listed, (dk_set_t *)(common_env))
    {
      if (!strcmp (listed, varname))
        return SPAR_GPT_NODOWN;
    }
  END_DO_SET()
  t_set_push ((dk_set_t *)(common_env), varname);
  return SPAR_GPT_NODOWN;
}

void
sparp_expand_top_retvals (sparp_t *sparp)
{
  sparp_env_t *env = sparp->sparp_env;
  caddr_t retselid = sparp->sparp_expr->_.req_top.retselid;
  dk_set_t names = NULL;
  SPART **new_retvals;
  int varctr, varcount;
  if (((SPART **)_STAR) != sparp->sparp_expr->_.req_top.retvals)
    return;
  sparp_gp_trav (sparp, sparp->sparp_expr->_.req_top.pattern, &names,
    NULL, NULL,
    sparp_gp_trav_list_retvals, NULL,
    NULL );
  new_retvals = (SPART **)t_revlist_to_array (names);
  varcount = BOX_ELEMENTS (new_retvals);
  t_set_push (&(env->spare_selids), retselid);
  for (varctr = 0; varctr < varcount; varctr++)
    {
      caddr_t varname = (caddr_t)new_retvals[varctr];
      new_retvals[varctr] = spar_make_variable (sparp, varname);
    }  
  t_set_pop (&(env->spare_selids));
  sparp->sparp_expr->_.req_top.retvals = new_retvals;
}

/* Removal of redundant unions in GPs and top-level ANDs in FILTERs.
\c trav_env_this is not used.
\c common_env is not used. */

int
sparp_gp_trav_flatten (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  int is_dirt = 0;
  if (SPAR_GP != curr->type) /* Not a gp ? -- nothing to do */
    return 0;
#if 0
  {
    if (UNION_L == curr->_.gp.subtype)
      {
        int ctr, len, sublen;
        SPART **oldmembers;
        SPART **newmembers;
        if (0 != BOX_ELEMENTS (curr->_.gp.filters))
	  spar_internal_error (sparp, "SPARQL: filter conditions in union?");
flatten_unions_of_unions:
	oldmembers = curr->_.gp.members;
	len = BOX_ELEMENTS (oldmembers);
	for (ctr = 0; ctr < len; ctr++)
          {
            SPART *memb = oldmembers[ctr];
            if (SPAR_GP != SPART_TYPE (memb))
	      break;
	    if (UNION_L != memb->_.gp.subtype)
	      continue;
            sublen = BOX_ELEMENTS (memb->_.gp.members);
	    newmembers = (SPART **)t_alloc_box ((len + sublen - 1) * sizeof (SPART *), DV_ARRAY_OF_POINTER);
	    memcpy (newmembers, oldmembers, ctr * sizeof (SPART *));
	    memcpy (newmembers + ctr, memb->_.gp.members, sublen * sizeof (SPART *));
	    memcpy (newmembers + ctr + sublen, oldmembers + ctr + 1, (len - (ctr + 1)) * sizeof (SPART *));
            mp_check_tree (THR_TMP_POOL, newmembers);
	    /*curr[0] = memb[0];*/
	    curr->_.gp.members = newmembers;
            is_dirt = 1;
	    goto flatten_unions_of_unions;
          }
      }
  }
#endif
  {
    int ctr, len;
    SPART **oldfilters;
    SPART **newfilters;
flatten_top_ands_in_filters:
    oldfilters = curr->_.gp.filters;
    len = BOX_ELEMENTS (oldfilters);
    for (ctr = 0; ctr < len; ctr++)
      {
        SPART *filt = oldfilters[ctr];
	if (BOP_AND != SPART_TYPE (filt))
	  continue;
        newfilters = (SPART **)t_alloc_box ((len + 1)* sizeof (SPART *), DV_ARRAY_OF_POINTER);
        memcpy (newfilters, oldfilters, ctr * sizeof (SPART *));
        newfilters[ctr] = filt->_.bin_exp.left;
        newfilters[ctr + 1] = filt->_.bin_exp.right;
        memcpy (newfilters + ctr + 2, oldfilters + ctr + 1, (len - (ctr + 1)) * sizeof (SPART *));
        curr->_.gp.filters = newfilters;
        is_dirt = 1;
        goto flatten_top_ands_in_filters;
      }
  }
  return is_dirt ? SPAR_GPT_RESCAN : 0;  
}

void
sparp_flatten (sparp_t *sparp)
{
  sparp_env_t *env = sparp->sparp_env;
  sparp_gp_trav (sparp, sparp->sparp_expr->_.req_top.pattern, NULL,
    sparp_gp_trav_flatten, NULL,
    NULL, NULL,
    NULL );
}

/* Composing counters of usages.
\c trav_env_this points to the innermost graph pattern.
\c common_env is not used. */

int
sparp_gp_trav_cu_in_triples (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  int fctr;
  SPART *gp = (SPART *)(trav_env_this[-1]);
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      trav_env_this[0] = curr;
      return SPAR_GPT_ENV_PUSH;
    case SPAR_TRIPLE: break;
    default: return 0;
    }
  for (fctr = 0; fctr < SPART_TRIPLE_FIELDS_COUNT; fctr++)
    {
      SPART *fld = curr->_.triple.tr_fields[fctr];
      sparp_equiv_t *eq;
      switch (SPART_TYPE(fld))
        {
	case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL: break;
	default: continue;
	}
      eq = sparp_equiv_get (sparp, gp, fld, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE | SPARP_EQUIV_ADD_GPSO_USE);
      if (UNION_L != gp->_.gp.subtype)
        sparp_rvr_tighten (sparp, &(eq->e_rvr), &(fld->_.var.rvr), ~0);
    }
  if (UNION_L == gp->_.gp.subtype)
    {
      int eq_ctr;
      SPARP_FOREACH_GP_EQUIV (sparp, gp, eq_ctr, eq)
        {
          if ((0 < eq->e_gspo_uses) && (0 == eq->e_rvr.rvrRestrictions))
            {
	      int varctr;
              rdf_val_range_t acc;
              memset (&acc, 0, sizeof (rdf_val_range_t));
              acc.rvrRestrictions = SPART_VARR_CONFLICT;
              for (varctr = eq->e_var_count; varctr--; /*no step*/)
                sparp_rvr_loose (sparp, &acc, &(eq->e_vars[varctr]->_.var.rvr), ~SPART_VARR_NOT_NULL);
              sparp_rvr_tighten (sparp, &(eq->e_rvr), &acc, ~0);              
            }
        }
      END_SPARP_FOREACH_GP_EQUIV;
    }
  return SPAR_GPT_NODOWN;
}

int
sparp_gp_trav_cu_in_expns (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  SPART *gp = (SPART *)(trav_env_this[-1]);
  sparp_equiv_t *eq;
  switch (SPART_TYPE(curr))
    {
    case SPAR_VARIABLE: break;
    case SPAR_BLANK_NODE_LABEL: break;
    default: return 0;
    }
  eq = sparp_equiv_get (sparp, gp, curr, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE | SPARP_EQUIV_ADD_CONST_READ);
  sparp_rvr_tighten (sparp, &(eq->e_rvr), &(curr->_.var.rvr), ~0);
  return 0;
}

int
sparp_gp_trav_cu_in_retvals (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  SPART *top_gp = (SPART *)(common_env);
  sparp_equiv_t *eq;
  switch (SPART_TYPE(curr))
    {
    case SPAR_VARIABLE: break;
    case SPAR_BLANK_NODE_LABEL: break;
    default: return 0;
    }
  curr->_.var.selid = top_gp->_.gp.selid;
  curr->_.var.tabid = NULL;
  eq = sparp_equiv_get (sparp, top_gp, curr, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE | SPARP_EQUIV_ADD_CONST_READ);
  curr->_.var.equiv_idx = eq->e_own_idx;
  curr->_.var.rvr.rvrRestrictions |= SPART_VARR_EXPORTED;
  sparp_equiv_tighten (sparp, eq, &(curr->_.var.rvr), ~0);
  return 0;
}


void
sparp_count_usages (sparp_t *sparp)
{
  int ctr;
  sparp_env_t *env = sparp->sparp_env;
  sparp_gp_trav (sparp, sparp->sparp_expr->_.req_top.pattern, NULL,
    sparp_gp_trav_cu_in_triples, NULL,
    sparp_gp_trav_cu_in_expns, NULL,
    NULL );
  DO_BOX_FAST (SPART *, expn, ctr, sparp->sparp_expr->_.req_top.retvals)
    {
      sparp_gp_trav (sparp, expn, sparp->sparp_expr->_.req_top.pattern,
        NULL, NULL,
        sparp_gp_trav_cu_in_retvals, NULL,
        NULL );
    }
  END_DO_BOX_FAST;
  DO_BOX_FAST (SPART *, oby, ctr, sparp->sparp_expr->_.req_top.order)
    {
      sparp_gp_trav (sparp, oby->_.oby.expn, sparp->sparp_expr->_.req_top.pattern,
        NULL, NULL,
        sparp_gp_trav_cu_in_retvals, NULL,
        NULL );
    }
  END_DO_BOX_FAST;
}

/* Processing of simple filters that introduce restrictions on variables
\c trav_env_this is not used.
\c common_env is not used. */

int
sparp_filter_to_equiv (sparp_t *sparp, SPART *curr, SPART *filt)
{
  switch (filt->type)
    {
    case BOP_EQ:
      {
        SPART *l = filt->_.bin_exp.left;
        SPART *r = filt->_.bin_exp.right;
        int ret = 0;
        if (SPAR_IS_BLANK_OR_VAR (l))
          {
            if (SPAR_IS_BLANK_OR_VAR (r))
              {
		sparp_equiv_t *eq_l = sparp_equiv_get (sparp, curr, l, 0);
		sparp_equiv_t *eq_r = sparp_equiv_get (sparp, curr, r, 0);
	        ret = sparp_equiv_merge (sparp, eq_l, eq_r);
	        goto eq_inspected;
	      }
	    else if (SPAR_IS_LIT (r))
	      {
		sparp_equiv_t *eq_l = sparp_equiv_get (sparp, curr, l, 0);
	        ret = sparp_equiv_restrict_by_literal (sparp, eq_l, NULL, r);
	        goto eq_inspected;
              }
          }
        else if (SPAR_IS_LIT (l))
          {
            if (SPAR_IS_BLANK_OR_VAR (r))
              {
		sparp_equiv_t *eq_r = sparp_equiv_get (sparp, curr, r, 0);
	        ret = sparp_equiv_restrict_by_literal (sparp, eq_r, NULL, l);
	        goto eq_inspected;
	      }
	  }
eq_inspected:
        if (
          (SPARP_EQUIV_MERGE_OK == ret) ||
          (SPARP_EQUIV_MERGE_CONFLICT == ret) ||
          (SPARP_EQUIV_MERGE_DUPE == ret) )
          return 1;
        break;
     }
    case BOP_NOT: break;
    case SPAR_BUILT_IN_CALL:
      {
        SPART *arg1 = filt->_.builtin.args[0];
        sparp_equiv_t *arg1_eq;
	if (SPAR_IS_BLANK_OR_VAR (arg1))
	  arg1_eq = sparp_equiv_get (sparp, curr, arg1, 0);
	else
	  break;
        switch (filt->_.builtin.btype)
          {
          case isIRI_L:
          case isURI_L:
            arg1_eq->e_rvr.rvrRestrictions |= SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_NOT_NULL;
            return 1;
          case isBLANK_L:
            arg1_eq->e_rvr.rvrRestrictions |= SPART_VARR_IS_REF | SPART_VARR_IS_BLANK | SPART_VARR_NOT_NULL;
            return 1;
          case isLITERAL_L:
            arg1_eq->e_rvr.rvrRestrictions |= SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL;
            return 1;
          case BOUND_L:
            arg1_eq->e_rvr.rvrRestrictions |= SPART_VARR_NOT_NULL;
            return 1;
#ifdef DEBUG
          case IRI_L:
          case STR_L:
          case LANG_L:
          case LANGMATCHES_L:
          case DATATYPE_L:
          case REGEX_L:
            break;
          default: spar_internal_error (sparp, "sparp_" "filter_to_equiv(): unsupported built-in");
#else
          default: break;
#endif
        }
      break;
      }
    default: break;
    }
  return 0;
}

int
sparp_gp_trav_restrict_by_simple_filters (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  int fctr;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      break;
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN;
    default: return 0;
    }
  for (fctr = BOX_ELEMENTS (curr->_.gp.filters); fctr--; /* no step */)
    {
      SPART *filt = curr->_.gp.filters[fctr];
      int ret = sparp_filter_to_equiv (sparp, curr, filt);
      if (0 == ret)
        continue;
      sparp_gp_detach_filter (sparp, curr, fctr, NULL);
    }
  return 0;
}

void
sparp_restrict_by_simple_filters (sparp_t *sparp)
{
  sparp_gp_trav (sparp, sparp->sparp_expr->_.req_top.pattern, NULL,
    sparp_gp_trav_restrict_by_simple_filters, NULL,
    NULL, NULL,
    NULL );
}


/* Composing equivs for common names without local variables.
\c trav_env_this points to dk_set_t of names.
\c common_env is not used. */

int
sparp_gp_trav_make_common_eqs_in (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      if (UNION_L == curr->_.gp.subtype)
        return 0;
      trav_env_this[0] = NULL;
      return SPAR_GPT_ENV_PUSH;      
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN;
    default: return 0;
    }
}

int
sparp_gp_trav_make_common_eqs_out (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  int eq_ctr;
  dk_set_t *local_vars, *parent_vars;
  dk_set_t vars_to_propagate = NULL;
  caddr_t var_name;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP: break;
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN;
    default: return 0;
    }
  local_vars = (dk_set_t *)trav_env_this;
  parent_vars = (dk_set_t *)(trav_env_this-1);
  while (NULL != local_vars[0])
    {
      var_name = dk_set_pop (local_vars);
      if (-1 != dk_set_position_of_string (local_vars[0], var_name))
        {
          sparp_equiv_get (sparp, curr, (SPART *)var_name, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_GET_NAMESAKES);
        }
      else
        dk_set_push (&vars_to_propagate, var_name);
    }
  SPARP_FOREACH_GP_EQUIV(sparp,curr,eq_ctr,eq)
    {
      int var_ctr;
      for (var_ctr = eq->e_var_count; var_ctr--; /* no step */)
        {
	  SPART *var = eq->e_vars[var_ctr];
          var_name = var->_.var.vname;
          if (SPART_VARNAME_IS_GLOB (var_name))
            continue;
          if (-1 == dk_set_position_of_string (vars_to_propagate, var_name))
	    dk_set_push (&vars_to_propagate, var_name);
        }
    } END_SPARP_FOREACH_GP_EQUIV;
  while (NULL != vars_to_propagate)
    dk_set_push (parent_vars, dk_set_pop (&vars_to_propagate));
  return 0;
}


void
sparp_make_common_eqs (sparp_t *sparp)
{
  sparp_gp_trav (sparp, sparp->sparp_expr->_.req_top.pattern, NULL,
    sparp_gp_trav_make_common_eqs_in, sparp_gp_trav_make_common_eqs_out,
    NULL, NULL,
    NULL );
  while (NULL != sparp->sparp_trav_envs[0])
    dk_set_pop ((dk_set_t *)(sparp->sparp_trav_envs));
}

/* Composing aliases.
\c trav_env_this points to the innermost graph pattern.
\c common_env is used in sparp_gp_trav_make_retval_aliases to pass vector of query return variables. */

void
sparp_gp_add_chain_aliases (sparp_t *sparp, SPART *inner_var, sparp_equiv_t *inner_eq, SPART **trav_stack, SPART *top_gp)
{
  SPART *parent_gp;
  sparp_equiv_t *parent_eq;
  sparp_equiv_t *curr_eq = inner_eq;
#ifdef DEBUG
  if (NULL == curr_eq)
    spar_internal_error (sparp, "sparp_" "gp_add_chain_aliases () has NULL eq for inner_var");
  if (curr_eq->e_gp != trav_stack[0])
    spar_internal_error (sparp, "sparp_" "gp_add_chain_aliases () has eq for inner_var not equal to trav_stack[0]");
#endif
  for (;;)
    {
      parent_gp = trav_stack[-1];
      if (NULL == parent_gp)
        break;
      parent_eq = sparp_equiv_get (sparp, parent_gp, inner_var, SPARP_EQUIV_GET_NAMESAKES | SPARP_EQUIV_INS_CLASS);
      sparp_equiv_connect (sparp, parent_eq, curr_eq, 1);
      if (parent_gp == top_gp)
        break;
      curr_eq = parent_eq;
      trav_stack--;
    }
}

int
sparp_gp_trav_make_retval_aliases (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  SPART **retvars = (SPART **)common_env;
  int retvar_ctr;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP: break;
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN;
    default: return 0;
    }
  trav_env_this[0] = curr;
  for (retvar_ctr = BOX_ELEMENTS (retvars); retvar_ctr--; /* no step */)
    {
      SPART *curr_retvar = retvars[retvar_ctr];
      sparp_equiv_t *curr_eq;
      caddr_t curr_varname = spar_var_name_of_ret_column (curr_retvar);
      if (NULL == curr_varname)
        continue;
      curr_eq = sparp_equiv_get (sparp, curr, (SPART *)curr_varname, SPARP_EQUIV_GET_NAMESAKES);
      if (NULL != curr_eq)
        sparp_gp_add_chain_aliases (sparp, curr_retvar, curr_eq, (SPART **)trav_env_this, NULL);
    }
  return SPAR_GPT_ENV_PUSH;
}

int
sparp_gp_trav_make_common_aliases (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  int eq_ctr;
  SPART **outer_gp_ptr;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP: break;
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN;
    default: return 0;
    }
  trav_env_this[0] = curr;
  SPARP_FOREACH_GP_EQUIV(sparp,curr,eq_ctr,eq)
    {
      int var_ctr;
      for (var_ctr = eq->e_var_count; var_ctr--; /* no step */)
        {
	  SPART *var = eq->e_vars[var_ctr];
          for (outer_gp_ptr = (SPART **)(sparp->sparp_trav_envs+1); outer_gp_ptr < (SPART **)trav_env_this; outer_gp_ptr++)
            {
              SPART *outer_gp = outer_gp_ptr[0];
	      sparp_equiv_t *topmost_eq = sparp_equiv_get (sparp, outer_gp, var, SPARP_EQUIV_GET_NAMESAKES);
	      if (NULL != topmost_eq)
		{
		  sparp_gp_add_chain_aliases (sparp, var, eq, (SPART **)trav_env_this, outer_gp);
		  break;
		}
            }
        }
    } END_SPARP_FOREACH_GP_EQUIV;
  return SPAR_GPT_ENV_PUSH;
}


int
sparp_gp_trav_remove_unused_aliases (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  int eq_ctr;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP: break;
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN;
    default: return 0;
    }
  trav_env_this[0] = curr;
  SPARP_REVFOREACH_GP_EQUIV(sparp,curr,eq_ctr,eq)
    {
      int sub_ctr;
      if (
        (0 != eq->e_const_reads) ||
        (0 != eq->e_gspo_uses) ||
        (0 != BOX_ELEMENTS_INT_0 (eq->e_receiver_idxs)) ||
        (1 < BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs)) ||
        (0 != eq->e_var_count) ||
        (SPART_VARR_EXPORTED & eq->e_rvr.rvrRestrictions) )
	continue;
      for (sub_ctr = BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs); sub_ctr--; /* no step */)
        {
          sparp_equiv_t *sub_eq = SPARP_EQUIV(sparp, eq->e_subvalue_idxs[sub_ctr]);
          sparp_equiv_disconnect (sparp, eq, sub_eq);
        }
      sparp_equiv_remove (sparp, eq);
    }
  END_SPARP_REVFOREACH_GP_EQUIV;
  return SPAR_GPT_ENV_PUSH;
}


void
sparp_make_aliases (sparp_t *sparp)
{
  SPART **retvars = sparp->sparp_expr->_.req_top.retvals;
  SPART *top_pattern = sparp->sparp_expr->_.req_top.pattern;
  /*int retvar_ctr;*/
  sparp_gp_trav (sparp, top_pattern, retvars,
    sparp_gp_trav_make_retval_aliases, NULL,
    NULL, NULL,
    NULL );
  sparp_gp_trav (sparp, top_pattern, NULL,
    sparp_gp_trav_make_common_aliases, NULL,
    NULL, NULL,
    NULL );
  sparp_gp_trav (sparp, top_pattern, NULL,
    sparp_gp_trav_remove_unused_aliases, NULL,
    NULL, NULL,
    NULL );
}

void
sparp_remove_redundant_connections (sparp_t *sparp)
{
  SPART *top_pattern = sparp->sparp_expr->_.req_top.pattern;
  sparp_equiv_t **equivs = sparp->sparp_env->spare_equivs;
  int eq_ctr;
  sparp_gp_trav (sparp, top_pattern, NULL,
    sparp_gp_trav_remove_unused_aliases, NULL,
    NULL, NULL,
    NULL );
  for (eq_ctr = sparp->sparp_env->spare_equiv_count; eq_ctr--; /*no step*/)
    {
      sparp_equiv_t *eq = equivs[eq_ctr];
      int sub_ctr;
      if (NULL == eq)
        continue;
      if (!((SPART_VARR_GLOBAL | SPART_VARR_FIXED) & eq->e_rvr.rvrRestrictions))
        continue;
      for (sub_ctr = BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs); sub_ctr--; /*no step*/)
        {
          int can_unlink = 0;
          sparp_equiv_t *sub_eq = equivs[eq->e_subvalue_idxs[sub_ctr]];
          if (!((SPART_VARR_GLOBAL | SPART_VARR_FIXED) & sub_eq->e_rvr.rvrRestrictions))
            continue;
          if (
            (SPART_VARR_GLOBAL & eq->e_rvr.rvrRestrictions) &&
            (SPART_VARR_GLOBAL & sub_eq->e_rvr.rvrRestrictions) )
            can_unlink = 1;
          if (sparp_equivs_have_same_fixedvalue (sparp, eq, sub_eq))
            can_unlink = 1;
          if (can_unlink)
            sparp_equiv_disconnect (sparp, eq, sub_eq);
        }
    }
  sparp_gp_trav (sparp, top_pattern, NULL,
    sparp_gp_trav_remove_unused_aliases, NULL,
    NULL, NULL,
    NULL );
}

/* Copying restrictions from equivalences to variables */

void
sparp_restr_of_union_eq_from_connected_subvalues (sparp_t *sparp, sparp_equiv_t *eq)
{
  sparp_equiv_t **equivs = sparp->sparp_env->spare_equivs;
  int sub_ctr, varname_ctr;
  int nice_sub_count = 0;
  dk_set_t common_vars = NULL;
  rdf_val_range_t acc;
  memset (&acc, 0, sizeof (rdf_val_range_t));
  acc.rvrRestrictions = SPART_VARR_CONFLICT;
  DO_BOX_FAST (ptrlong, sub_eq_idx, sub_ctr, eq->e_subvalue_idxs)
    {
      sparp_equiv_t *sub_eq = equivs[sub_eq_idx];
      SPART *sub_gp = sub_eq->e_gp;
          DO_BOX_FAST (caddr_t, varname, varname_ctr, sub_eq->e_varnames)
            {
              if (!SPART_VARNAME_IS_GLOB (varname))
                continue;
          if (0 > dk_set_position_of_string (common_vars, varname))
            continue;
              t_set_push (&common_vars, varname);
            }
          END_DO_BOX_FAST;
      if (sub_eq->e_rvr.rvrRestrictions & SPART_VARR_CONFLICT)
        nice_sub_count++; /* Conflict is nice because it will be removed soon */
      else
        {
          sparp_rvr_loose (sparp, &acc, &(sub_eq->e_rvr), ~0);
          if (OPTIONAL_L != sub_gp->_.gp.subtype)
            nice_sub_count++;
        }
    }
  END_DO_BOX_FAST;
  if (nice_sub_count < BOX_ELEMENTS (eq->e_gp->_.gp.members))
    acc.rvrRestrictions &= ~SPART_VARR_NOT_NULL;
  sparp_rvr_tighten (sparp, &(eq->e_rvr), &acc, ~0);
  if (NULL == common_vars)
    eq->e_rvr.rvrRestrictions &= ~SPART_VARR_GLOBAL;
  else
    {
      DO_BOX_FAST (caddr_t, varname, varname_ctr, eq->e_varnames)
        {
          if (0 > dk_set_position_of_string (common_vars, varname))
            t_set_push (&common_vars, varname);
        }
      END_DO_BOX_FAST;
      eq->e_varnames = t_list_to_array (common_vars);
    }            
}

void
sparp_restr_of_join_eq_from_connected_subvalues (sparp_t *sparp, sparp_equiv_t *eq)
{
  sparp_equiv_t **equivs = sparp->sparp_env->spare_equivs;
  int sub_ctr;
  DO_BOX_FAST (ptrlong, sub_eq_idx, sub_ctr, eq->e_subvalue_idxs)
    {
      sparp_equiv_t *sub_eq = equivs[sub_eq_idx];
      SPART *sub_gp = sub_eq->e_gp;
      if (OPTIONAL_L != sub_gp->_.gp.subtype)
        sparp_rvr_tighten (sparp, &(eq->e_rvr), &(sub_eq->e_rvr), ~0);
    }
  END_DO_BOX_FAST;
}


int
sparp_gp_trav_eq_restr_from_connected_subvalues (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  int eq_ctr;
  if (SPAR_GP != SPART_TYPE(curr))
    return 0;
  SPARP_FOREACH_GP_EQUIV(sparp,curr,eq_ctr,eq)
    {
      if (UNION_L == curr->_.gp.subtype)
        sparp_restr_of_union_eq_from_connected_subvalues (sparp, eq);
      else
        sparp_restr_of_join_eq_from_connected_subvalues (sparp, eq);
    } END_SPARP_FOREACH_GP_EQUIV;
  return 0;
}

int
sparp_gp_trav_eq_restr_from_connected_receivers (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  sparp_equiv_t **equivs = sparp->sparp_env->spare_equivs;
  int sub_ctr;
  dk_set_t common_vars = NULL;
  int eq_ctr;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      break;
    case SPAR_TRIPLE:
      return SPAR_GPT_NODOWN;
    default: return 0;
    }
  SPARP_FOREACH_GP_EQUIV(sparp,curr,eq_ctr,eq)
    {
      DO_BOX_FAST (ptrlong, sub_eq_idx, sub_ctr, eq->e_subvalue_idxs)
       {
         sparp_equiv_t *sub_eq = equivs[sub_eq_idx];
         SPART *sub_gp = sub_eq->e_gp;
         int changeable =
           ( SPART_VARR_CONFLICT |
             SPART_VARR_IS_BLANK | SPART_VARR_IS_IRI |
             SPART_VARR_IS_LIT | SPART_VARR_IS_REF |
             SPART_VARR_TYPED | SPART_VARR_FIXED );
         if (UNION_L != sub_gp->_.gp.subtype)
           changeable |= SPART_VARR_NOT_NULL;
         sparp_equiv_tighten (sparp, sub_eq, &(eq->e_rvr), changeable);
       }
      END_DO_BOX_FAST;
    } END_SPARP_FOREACH_GP_EQUIV;
  return 0;
}


void
sparp_eq_restr_from_connected (sparp_t *sparp)
{
  sparp_env_t *env = sparp->sparp_env;
  sparp_gp_trav (sparp, sparp->sparp_expr->_.req_top.pattern, NULL,
    NULL, sparp_gp_trav_eq_restr_from_connected_subvalues,
    NULL, NULL,
    NULL );
  sparp_gp_trav (sparp, sparp->sparp_expr->_.req_top.pattern, NULL,
    sparp_gp_trav_eq_restr_from_connected_receivers, NULL,
    NULL, NULL,
    NULL );
}

/* Copying restrictions from equivalences to variables */

int
sparp_gp_trav_eq_restr_to_vars (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  int eq_ctr, var_ctr;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      break;
    case SPAR_TRIPLE:
      return SPAR_GPT_NODOWN;
    default: return 0;
    }
  SPARP_FOREACH_GP_EQUIV(sparp,curr,eq_ctr,eq)
    {
      for (var_ctr = eq->e_var_count; var_ctr--; /* no step */)
	{
	  SPART *var = eq->e_vars[var_ctr];
#ifdef DEBUG
	  if ((SPAR_VARIABLE != SPART_TYPE(var)) && (SPAR_BLANK_NODE_LABEL != SPART_TYPE(var)))
	    spar_internal_error (sparp, "Not a variable in equiv in sparp_gp_trav_eq_restr_to_vars()");
#endif
	  sparp_rvr_tighten (sparp, &(var->_.var.rvr), &(eq->e_rvr), ~0);
	  var->_.var.equiv_idx = eq->e_own_idx;
	}
    } END_SPARP_FOREACH_GP_EQUIV;
  return 0;
}

void
sparp_eq_restr_to_vars (sparp_t *sparp)
{
  sparp_env_t *env = sparp->sparp_env;
  sparp_gp_trav (sparp, sparp->sparp_expr->_.req_top.pattern, NULL,
    sparp_gp_trav_eq_restr_to_vars, NULL,
    NULL, NULL,
    NULL );
}

/* Aux functions */

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


void 
sparp_dbg_gp_print (sparp_t *sparp, SPART *tree)
{
  int eq_ctr, eq_count;
  eq_count = tree->_.gp.equiv_count;
  SPARP_FOREACH_GP_EQUIV(sparp,tree,eq_ctr,eq)
    {
      int varname_count, varname_ctr;
      spar_dbg_printf ((" ( %d subv, %d recv, %d pso, %d const:",
      BOX_ELEMENTS_INT_0(eq->e_subvalue_idxs), BOX_ELEMENTS_INT_0(eq->e_receiver_idxs),
        (int)(eq->e_gspo_uses), (int)(eq->e_const_reads) ));
      varname_count = BOX_ELEMENTS (eq->e_varnames);
      for (varname_ctr = 0; varname_ctr < varname_count; varname_ctr++)
        {
          spar_dbg_printf ((" %s", eq->e_varnames[varname_ctr]));
        }
      spar_dbg_printf ((")"));
    } END_SPARP_FOREACH_GP_EQUIV;
  spar_dbg_printf (("\n"));
}

#define SPARP_EQUIV_AUDIT_NOBAD 0x01
#ifdef DEBUG

static int
sparp_gp_trav_equiv_audit_inner_vars (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  SPART *gp = (SPART *)(trav_env_this[-1]);
  int eq_ctr;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      trav_env_this[0] = curr;
      SPARP_FOREACH_GP_EQUIV (sparp, curr, eq_ctr, eq)
        {
          int recv_ctr;
          DO_BOX_FAST (ptrlong, recv_idx, recv_ctr, eq->e_receiver_idxs)
            {
              sparp_equiv_t *recv = SPARP_EQUIV (sparp, recv_idx);
              if (recv->e_gp != gp)
                spar_internal_error (sparp, "sparp_" "gp_trav_equiv_audit_inner_vars(): gp of recv eq is not parent of gp of curr eq");
            }
          END_DO_BOX_FAST;
        }
      END_SPARP_FOREACH_GP_EQUIV;
      return SPAR_GPT_ENV_PUSH;
    case SPAR_VARIABLE: break;
    case SPAR_BLANK_NODE_LABEL: break;
    default: return 0;
    }
  if (SPART_BAD_EQUIV_IDX != curr->_.var.equiv_idx)
    {
      sparp_equiv_t *eq = sparp_equiv_get (sparp, gp, curr, SPARP_EQUIV_GET_ASSERT);
      if (eq->e_own_idx != curr->_.var.equiv_idx)
        spar_internal_error (sparp, "sparp_" "gp_trav_equiv_audit_inner_vars(): eq idx mismatch");
      if (strcmp (gp->_.gp.selid, curr->_.var.selid))
        spar_internal_error (sparp, "sparp_" "gp_trav_equiv_audit_inner_vars(): var selid differs from gp selid");
    }
  else if (SPARP_EQUIV_AUDIT_NOBAD & ((ptrlong)common_env))
    spar_internal_error (sparp, "sparp_" "gp_trav_equiv_audit_inner_vars(): var with SPART_BAD_EQUIV_IDX");
  return 0;
}

static int
sparp_gp_trav_equiv_audit_retvals (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  SPART *top_gp = (SPART *)(common_env);
  sparp_equiv_t *eq;
  switch (SPART_TYPE(curr))
    {
    case SPAR_VARIABLE: break;
    case SPAR_BLANK_NODE_LABEL: break;
    default: return 0;
    }
  eq = sparp_equiv_get (sparp, top_gp, curr, SPARP_EQUIV_GET_ASSERT | SPARP_EQUIV_GET_NAMESAKES);
  if (eq->e_own_idx != curr->_.var.equiv_idx)
    spar_internal_error (sparp, "sparp_" "gp_trav_equiv_audit_retvals(): eq idx mismatch");
  if (!(eq->e_rvr.rvrRestrictions & SPART_VARR_EXPORTED))
    spar_internal_error (sparp, "sparp_" "gp_trav_equiv_audit_retvals(): lost SPART_VARR_EXPORTED");
  return 0;
}

static void
sparp_equiv_audit_retvals (sparp_t *sparp)
{
  int ctr;
  void *trav_envs [SPARP_MAX_SYNTDEPTH];
  DO_BOX_FAST (SPART *, expn, ctr, sparp->sparp_expr->_.req_top.retvals)
    {
      sparp_gp_trav_int (sparp, expn, trav_envs+1, sparp->sparp_expr->_.req_top.pattern,
        NULL, NULL,
        sparp_gp_trav_equiv_audit_retvals, NULL,
        NULL );
    }
  END_DO_BOX_FAST;
  DO_BOX_FAST (SPART *, oby, ctr, sparp->sparp_expr->_.req_top.order)
    {
      sparp_gp_trav_int (sparp, oby->_.oby.expn, trav_envs+1, sparp->sparp_expr->_.req_top.pattern,
        NULL, NULL,
        sparp_gp_trav_equiv_audit_retvals, NULL,
        NULL );
    }
  END_DO_BOX_FAST;
}

static void
sparp_equiv_audit_gp (sparp_t *sparp, SPART *gp, int is_deprecated, sparp_equiv_t *chk_eq)
{
  int gp_eq_ctr;
  SPARP_FOREACH_GP_EQUIV (sparp, gp, gp_eq_ctr, gp_eq)
    {
      if (gp_eq->e_gp != gp)
        spar_internal_error (sparp, "sparp_" "equiv_audit_gp(): gp_eq->e_gp != gp");
      if (chk_eq == gp_eq)
        chk_eq = NULL;
      if (gp_eq->e_deprecated && !is_deprecated)
        spar_internal_error (sparp, "sparp_" "equiv_audit_gp(): eq is deprecated");
      if (is_deprecated && !(gp_eq->e_deprecated))
        spar_internal_error (sparp, "sparp_" "equiv_audit_gp(): eq is expected to be deprecated");
    }
  END_SPARP_FOREACH_GP_EQUIV;
  if (NULL != chk_eq)
    spar_internal_error (sparp, "sparp_" "equiv_audit_gp(): no reference to chk_eq in gp");
}

static void
sparp_equiv_audit_all (sparp_t *sparp, int flags)
{
  void *trav_envs [SPARP_MAX_SYNTDEPTH];
  int eq_ctr, var_ctr, recv_ctr, subv_ctr;
  memset (trav_envs, 0, sizeof (void *) * SPARP_MAX_SYNTDEPTH);
  sparp_gp_trav_int (sparp, sparp->sparp_expr->_.req_top.pattern, trav_envs+1, (void *)((ptrlong)flags),
    sparp_gp_trav_equiv_audit_inner_vars, NULL,
    sparp_gp_trav_equiv_audit_inner_vars, NULL,
    NULL );
  sparp_equiv_audit_retvals (sparp);
  for (eq_ctr = sparp->sparp_env->spare_equiv_count; eq_ctr--; /*no step*/)
    {
      sparp_equiv_t *eq = SPARP_EQUIV (sparp, eq_ctr);
      SPART *gp;
      if (NULL == eq)
        continue;
      if (eq->e_own_idx != eq_ctr)
        spar_internal_error (sparp, "sparp_" "equiv_audot_all(): wrong own index");
      gp = eq->e_gp;
      sparp_equiv_audit_gp (sparp, gp, ((SPART_BAD_GP_SUBTYPE == gp->_.gp.subtype) ? 1 : 0), eq);
      for (var_ctr = eq->e_var_count; var_ctr--; /*no step*/)
        {
          SPART *var = eq->e_vars [var_ctr];
          if (var->_.var.equiv_idx != eq_ctr)
            spar_internal_error (sparp, "sparp_" "equiv_audit_all(): no reference to chk_eq in gp");
          if (strcmp (var->_.var.selid, gp->_.gp.selid))
            spar_internal_error (sparp, "sparp_" "equiv_audit_all(): selid of var of eq differs from selid of gp of eq");
        }
      recv_ctr = BOX_ELEMENTS_0 (eq->e_receiver_idxs);
      if (0 != recv_ctr)
        {
          SPART *recv_gp_0 = (SPARP_EQUIV (sparp, eq->e_receiver_idxs[0]))->e_gp;
          while (recv_ctr-- > 1)
            {
              SPART *recv_gp_N = (SPARP_EQUIV (sparp, eq->e_receiver_idxs[recv_ctr]))->e_gp;
              if (recv_gp_N != recv_gp_0)
                spar_internal_error (sparp, "sparp_" "equiv_audit_all(): gps of different recvs differ");
            }
          DO_BOX_FAST_REV (ptrlong, recv_idx, recv_ctr, eq->e_receiver_idxs)
            {
              sparp_equiv_t *recv = SPARP_EQUIV (sparp, recv_idx);
              DO_BOX_FAST_REV (ptrlong, subv_idx, subv_ctr, recv->e_subvalue_idxs)
                {
                  if (subv_idx == eq_ctr)
                    goto subv_of_recv_ok;
                }
              END_DO_BOX_FAST_REV;
              spar_internal_error (sparp, "sparp_" "equiv_audit_all(): no matching subv for recv");
subv_of_recv_ok: ;
            }
          END_DO_BOX_FAST_REV;
          DO_BOX_FAST_REV (ptrlong, subv_idx, subv_ctr, eq->e_subvalue_idxs)
            {
              sparp_equiv_t *subv = SPARP_EQUIV (sparp, subv_idx);
              DO_BOX_FAST_REV (ptrlong, recv_idx, recv_ctr, subv->e_receiver_idxs)
                {
                  if (recv_idx == eq_ctr)
                    goto recv_of_subv_ok;
                }
              END_DO_BOX_FAST_REV;
              spar_internal_error (sparp, "sparp_" "equiv_audit_all(): no matching recv for subv");
recv_of_subv_ok: ;
            }
          END_DO_BOX_FAST_REV;
        }
#if 0
      if ((0 == eq->e_gspo_uses) &&
        (0 == BOX_ELEMENTS_0 (eq->e_subvalue_idxs)) &&
        !(eq->e_rvr.rvrRestrictions & (SPART_VARR_FIXED | SPART_VARR_GLOBAL)) &&
        ((0 != eq->e_const_reads) ||
          (0 != BOX_ELEMENTS_0 (eq->e_receiver_idxs)) /*||
          (eq->e_rvr.rvrRestrictions & SPART_VARR_EXPORTED)*/ ) )
      spar_error (sparp, "Variable '%.100s' is used but not assigned", eq->e_varnames[0]);
#endif
    }
}

static void
sparp_audit_mem (sparp_t *sparp)
{
  t_check_tree (sparp->sparp_expr);
}

#else
#define sparp_equiv_audit_all(sparp,flags)
#define sparp_audit_mem(sparp)
#endif

sparp_equiv_t *
sparp_equiv_alloc (sparp_t *sparp)
{
  ptrlong eqcount = sparp->sparp_env->spare_equiv_count;
  sparp_equiv_t **eqs = sparp->sparp_env->spare_equivs;
  sparp_equiv_t *res = (sparp_equiv_t *)t_alloc_box (sizeof (sparp_equiv_t), DV_ARRAY_OF_POINTER);
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
      sparp->sparp_expr->_.req_top.equivs = sparp->sparp_env->spare_equivs = eqs = new_eqs;
    }
  res->e_own_idx = eqcount;
#ifdef DEBUG
  res->e_clone_idx = (SPART_BAD_EQUIV_IDX-1);
#endif
  eqs[eqcount++] = res;
  sparp->sparp_expr->_.req_top.equiv_count = sparp->sparp_env->spare_equiv_count = eqcount;
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
    }
  else
    {
      curr_eq->e_vars = (SPART **)t_list (1, NULL);
      curr_eq->e_var_count = 0;
    }
#ifdef DEBUG
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
#ifdef DEBUG
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
  int o_ctr, o_count, i_ctr, i_count;
  int o_listed_in_i = 0;
#ifdef DEBUG
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
      return 1;
    }
#ifdef DEBUG
  if (i_listed_in_o)
    spar_internal_error (sparp, "sparp_" "equiv_connect(): unidirectional link (2) ?");
#endif
  if (!add_if_missing)    
    return 0;
  outer->e_subvalue_idxs = (ptrlong *)t_list_concat_tail ((caddr_t)(outer->e_subvalue_idxs), 1, inner->e_own_idx);
  inner->e_receiver_idxs = (ptrlong *)t_list_concat_tail ((caddr_t)(inner->e_receiver_idxs), 1, outer->e_own_idx);
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
  return 1;
}

void
sparp_equiv_remove_var (sparp_t *sparp, sparp_equiv_t *eq, SPART *var)
{
#ifdef DEBUG
  int namesakes_count = 0;
#endif
  int varctr;
  int hit_idx = -1;
  if (NULL == eq)
    {
      int eq_idx = var->_.var.equiv_idx;
      if (SPART_BAD_EQUIV_IDX == eq_idx)
        return;
#ifdef DEBUG
      if (eq_idx >= sparp->sparp_env->spare_equiv_count)
        spar_internal_error (sparp, "sparp_" "equiv_remove_var(): eq_idx is too big");
#endif
      eq = SPARP_EQUIV (sparp, eq_idx);
#ifdef DEBUG
      if (NULL == eq)
        spar_internal_error (sparp, "sparp_" "equiv_remove_var(): eq is merged and disabled");
#endif
    }
  for (varctr = eq->e_var_count; varctr--; /*no step*/)
    {
      SPART *curr_var = eq->e_vars [varctr];
      if (curr_var == var)
        {
#ifdef DEBUG
          if (0 <= hit_idx)
            spar_internal_error (sparp, "sparp_" "equiv_remove_var(): duplicate occurrence of var in equiv ?");
#endif
          hit_idx = varctr;
    }
#ifdef DEBUG
      if (!strcmp (curr_var->_.var.vname, var->_.var.vname))
        namesakes_count++;
#endif
    }
#ifdef DEBUG
  if (0 > hit_idx)
    spar_internal_error (sparp, "sparp_" "equiv_remove_var(): var is not in equiv ?");
  if (1 > namesakes_count)
    spar_internal_error (sparp, "sparp_" "equiv_remove_var(): no namesakes of var in equiv ?");
#endif
  eq->e_vars[hit_idx] = eq->e_vars[eq->e_var_count - 1];
  eq->e_vars[eq->e_var_count - 1] = NULL;
  eq->e_var_count--;
  var->_.var.equiv_idx = SPART_BAD_EQUIV_IDX;
}

sparp_equiv_t *
sparp_equiv_clone (sparp_t *sparp, sparp_equiv_t *orig, SPART *cloned_gp)
{
  sparp_equiv_t *tgt;
  if (orig->e_cloning_serial == sparp->sparp_cloning_serial)
    spar_internal_error (sparp, "sparp_" "equiv_clone(): can't make second clone of equiv during same gp cloning");
  tgt = sparp_equiv_alloc (sparp);
  orig->e_cloning_serial = sparp->sparp_cloning_serial;
  orig->e_clone_idx = tgt->e_own_idx;
  tgt->e_gp = cloned_gp;
  tgt->e_varnames = (caddr_t *)t_full_box_copy_tree ((caddr_t)(orig->e_varnames));
  tgt->e_vars = (SPART **)t_alloc_box (box_length (orig->e_vars), DV_ARRAY_OF_POINTER); /* no real copying of e_vars */
  /* no copying for e_var_count */
  /* no copying for e_gspo_uses */
  /* no copying for ptrlong e_const_reads;	/ *!< Number of constant-read uses in filters and in 'graph' of members */
  sparp_rvr_copy (sparp, &(tgt->e_rvr), &(orig->e_rvr));
  /* no copying for e_subvalue_idxs;	/ *!< Subselects where values of these variables come from */
  /* no copying for e_receiver_idxs;	/ *!< Aliases of surrounding query where values of variables from this equiv are used */
  /* no copying for e_clone_idx;	/ *!< Index of the current clone of the equiv */
  /* no copying for e_cloning_serial;	/ *!< The serial used when e_clone_idx is set, should be equal to sparp_cloning_serial */
#ifdef DEBUG
  /* no copying for e_dbg_saved_gp;	/ *!< e_gp that is boxed as ptrlong, to same the pointer after e_gp is set to NULL */
#endif
  /* Add more lines here when more fields added to struct sparp_equiv_s. */
  return tgt;
}

int
sparp_equiv_restrict_by_literal (sparp_t *sparp, sparp_equiv_t *pri, ccaddr_t datatype, SPART *value)
{
  rdf_val_range_t tmp;
  memset (&tmp, 0, sizeof (rdf_val_range_t));
  if (NULL != datatype)
    {
      tmp.rvrDatatype = datatype;
      tmp.rvrRestrictions |= SPART_VARR_TYPED;
    }
      if (NULL != value)
    {
      tmp.rvrFixedValue = (ccaddr_t)value;
      tmp.rvrRestrictions |= SPART_VARR_FIXED;
    }
  sparp_rvr_tighten (sparp, &tmp, &(pri->e_rvr), ~0);
  if (tmp.rvrRestrictions & SPART_VARR_CONFLICT)
    return SPARP_EQUIV_MERGE_ROLLBACK;
  memcpy (&(pri->e_rvr), &tmp, sizeof (rdf_val_range_t));
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
  sparp->sparp_env->spare_equivs[eq_own_idx] = NULL;
  eq_gp->_.gp.equiv_count = len;
}

int
sparp_equiv_merge (sparp_t *sparp, sparp_equiv_t *pri, sparp_equiv_t *sec)
{
  int ctr1, ctr2, ret;
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
  ret = sparp_equiv_restrict_by_literal (sparp, pri, sec->e_rvr.rvrDatatype, sec->e_rvr.rvrFixedValue);
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
  sparp_equiv_remove (sparp, sec);
  return ret;
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
  return sparp_fixedvalues_equal (sparp, first_eq->e_rvr.rvrFixedValue, second_eq->e_rvr.rvrFixedValue);
}

caddr_t
sparp_smallest_union_superdatatype (sparp_t *sparp, caddr_t iri1, caddr_t iri2)
{
  if (iri1 == iri2)
    return iri1;
  if ((NULL == iri1) || (NULL == iri2))
    return NULL;
#ifdef DEBUG
  if ((DV_UNAME != DV_TYPE_OF (iri1)) || (DV_UNAME != DV_TYPE_OF (iri2)))
    spar_internal_error (sparp, "sparp_" "smallest_common_datatype(): non-UNAME datatype IRI");
#endif
  if (strcmp (iri1, iri2) > 0)
    {
      caddr_t swap;
      swap = iri1; iri1 = iri2; iri2 = swap;
    }
  if ((uname_xmlschema_ns_uri_hash_any == iri1) || (uname_xmlschema_ns_uri_hash_any == iri2))
    return uname_xmlschema_ns_uri_hash_any;
  if ((uname_xmlschema_ns_uri_hash_double == iri1) && (uname_xmlschema_ns_uri_hash_float == iri2))
    return uname_xmlschema_ns_uri_hash_double;
  if ((uname_xmlschema_ns_uri_hash_decimal == iri1) && (uname_xmlschema_ns_uri_hash_integer == iri2))
    return uname_xmlschema_ns_uri_hash_decimal;
  return NULL;
}

caddr_t
sparp_largest_intersect_superdatatype (sparp_t *sparp, caddr_t iri1, caddr_t iri2)
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
      caddr_t swap;
      swap = iri1; iri1 = iri2; iri2 = swap;
    }
  if (uname_xmlschema_ns_uri_hash_any == iri1)
    return iri2;
  if (uname_xmlschema_ns_uri_hash_any == iri2)
    return iri1;
  if ((uname_xmlschema_ns_uri_hash_double == iri1) && (uname_xmlschema_ns_uri_hash_float == iri2))
    return uname_xmlschema_ns_uri_hash_float;
  if ((uname_xmlschema_ns_uri_hash_decimal == iri1) && (uname_xmlschema_ns_uri_hash_integer == iri2))
    return uname_xmlschema_ns_uri_hash_integer;
  return iri1;
}

void
sparp_rvr_add_iri_classes (sparp_t *sparp, rdf_val_range_t *rvr, caddr_t *add_classes, ptrlong add_count)
{
  int len = rvr->rvrIriClassCount;
  int ctr, addctr;
  int oldsize, newmax;
  newmax = len + add_count;
  oldsize = BOX_ELEMENTS_0 (rvr->rvrIriClasses);
  if (oldsize < newmax)
    {
      int newsize = oldsize ? oldsize : 1;
      caddr_t *new_buf;
      do newsize *= 2; while (newsize < newmax);
      new_buf = (caddr_t *)t_alloc_box (newsize * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
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
      caddr_t addon = add_classes [addctr];
      caddr_t *addon_superclasses, *addon_subclasses;
      for (ctr = 0; ctr < len; ctr++)
    {
          caddr_t old = rvr->rvrIriClasses [ctr];
          if (old == addon) /* Already here */
            goto skip_addon; /* see below */
    }
      addon_superclasses = jso_triple_get_objs (sparp->sparp_sparqre->sparqre_qi, addon, uname_virtrdf_ns_uri_isSubclassOf);
      cmpcount = BOX_ELEMENTS (addon_superclasses);
      for (ctr = 0; ctr < len; ctr++)
    {
          caddr_t old = rvr->rvrIriClasses [ctr];
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
      addon_subclasses = jso_triple_get_subjs (sparp->sparp_sparqre->sparqre_qi, uname_virtrdf_ns_uri_isSubclassOf, addon);
      cmpcount = BOX_ELEMENTS (addon_subclasses);
      for (ctr = 0; ctr < len; ctr++)
        {
          caddr_t old = rvr->rvrIriClasses [ctr];
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
sparp_rvr_intersect_iri_classes (sparp_t *sparp, rdf_val_range_t *rvr, caddr_t *isect_classes, ptrlong isect_count)
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
      caddr_t old = rvr->rvrIriClasses [ctr];
      caddr_t *old_superclasses, *old_subclasses;
      int cmpctr, cmpcount, isectctr;
      for (isectctr = 0; isectctr < isect_count; isectctr++)
        {
          if (isect_classes [isectctr] == old) /* Found in isect */
            goto test_next_old; /* see below */
        }
      old_superclasses = jso_triple_get_objs (sparp->sparp_sparqre->sparqre_qi, old, uname_virtrdf_ns_uri_isSubclassOf);
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
      old_subclasses = jso_triple_get_subjs (sparp->sparp_sparqre->sparqre_qi, uname_virtrdf_ns_uri_isSubclassOf, old);
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
                      caddr_t *new_buf;
                      do newsize *= 2; while (newsize < newmax);
                      new_buf = (caddr_t *)t_alloc_box (newsize * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
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

rdf_val_range_t *
sparp_rvr_copy (sparp_t *sparp, rdf_val_range_t *dest, rdf_val_range_t *src)
{
  if (SPARP_RVR_CREATE == dest)
    dest = (rdf_val_range_t *)t_alloc (sizeof (rdf_val_range_t));
  memcpy (dest, src, sizeof (rdf_val_range_t));
  if (NULL != src->rvrIriClasses)
    dest->rvrIriClasses = (ccaddr_t *)t_box_copy ((caddr_t)(src->rvrIriClasses));
  return dest;
}

void
sparp_rvr_tighten (sparp_t *sparp, rdf_val_range_t *dest, rdf_val_range_t *addon, int changeable_flags)
{
  ptrlong new_restr;
  new_restr = (dest->rvrRestrictions | (addon->rvrRestrictions & changeable_flags));
  if (changeable_flags & SPART_VARR_TYPED)
    {
      if (new_restr & SPART_VARR_TYPED)
        {
          caddr_t isect_dt = sparp_largest_intersect_superdatatype (sparp, dest->rvrDatatype, addon->rvrDatatype);
          dest->rvrDatatype = isect_dt;
        }
    }
  if (addon->rvrRestrictions & changeable_flags & SPART_VARR_FIXED)
    {
      if (dest->rvrRestrictions & SPART_VARR_FIXED)
        {
          if (!sparp_fixedvalues_equal (sparp, dest->rvrFixedValue, addon->rvrFixedValue))
            new_restr |= SPART_VARR_CONFLICT;
        }
      else
        dest->rvrFixedValue = addon->rvrFixedValue;
    }
  if (addon->rvrRestrictions & changeable_flags & SPART_VARR_IRI_CALC)
    {
      if (dest->rvrRestrictions & SPART_VARR_IRI_CALC)
        {
          sparp_rvr_intersect_iri_classes (sparp, dest, addon->rvrIriClasses, addon->rvrIriClassCount);
          if (0 == dest->rvrIriClassCount)
            new_restr |= SPART_VARR_CONFLICT;
        }
      else
        {
          dest->rvrIriClasses = (ccaddr_t *) t_box_copy ((caddr_t)(addon->rvrIriClasses));
          dest->rvrIriClassCount = addon->rvrIriClassCount;
        }
    }
  if (
    ((new_restr & SPART_VARR_IS_REF) && (new_restr & SPART_VARR_IS_LIT)) ||
    ((new_restr & SPART_VARR_IS_BLANK) && (new_restr & SPART_VARR_IS_IRI)) ||
    ((new_restr & SPART_VARR_ALWAYS_NULL) &&
     (new_restr & (SPART_VARR_NOT_NULL | SPART_VARR_IS_LIT | SPART_VARR_IS_REF)) ) )    
    new_restr |= SPART_VARR_CONFLICT;
  dest->rvrRestrictions = new_restr;
}

void
sparp_rvr_loose (sparp_t *sparp, rdf_val_range_t *dest, rdf_val_range_t *addon, int changeable_flags)
{
  ptrlong new_restr;
  if (dest->rvrRestrictions & SPART_VARR_CONFLICT)
    {
      int persistent_restr = (dest->rvrRestrictions & (SPART_VARR_EXPORTED | SPART_VARR_GLOBAL));
      sparp_rvr_copy (sparp, dest, addon);
      dest->rvrRestrictions |= persistent_restr;
      return;
    }
  if (addon->rvrRestrictions & SPART_VARR_CONFLICT)
    return;
  /* Can't loose these flags: */
  changeable_flags &= ~(SPART_VARR_EXPORTED | SPART_VARR_GLOBAL);
  new_restr = dest->rvrRestrictions & (addon->rvrRestrictions | ~changeable_flags);
  if (new_restr & changeable_flags & SPART_VARR_TYPED)
    {
      caddr_t union_dt = sparp_smallest_union_superdatatype (sparp, dest->rvrDatatype, addon->rvrDatatype);
      dest->rvrDatatype = union_dt;
      if (NULL == dest->rvrDatatype)
        new_restr &= ~SPART_VARR_TYPED;
    }
  if (new_restr & changeable_flags & SPART_VARR_FIXED)
    {
      if (!sparp_fixedvalues_equal (sparp, dest->rvrFixedValue, addon->rvrFixedValue))
        new_restr &= ~SPART_VARR_FIXED;
    }
  if (new_restr & changeable_flags & SPART_VARR_IRI_CALC)
    {
      sparp_rvr_add_iri_classes (sparp, dest, addon->rvrIriClasses, addon->rvrIriClassCount);
    }
  dest->rvrRestrictions = new_restr;
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

/* Main rewriting functions */

void
sparp_rewrite_basic (sparp_t *sparp)
{
  SPART *root = sparp->sparp_expr;
  sparp_audit_mem (sparp);
  sparp_flatten (sparp);
  sparp_count_usages (sparp);
  sparp_audit_mem (sparp);
  sparp_restrict_by_simple_filters (sparp);
  sparp_audit_mem (sparp);
  sparp_make_common_eqs (sparp);
  sparp_make_aliases (sparp);
  sparp_eq_restr_from_connected (sparp);
  sparp_eq_restr_to_vars (sparp);
  sparp_remove_redundant_connections (sparp);
  root->_.req_top.equivs = sparp->sparp_env->spare_equivs;
  root->_.req_top.equiv_count = sparp->sparp_env->spare_equiv_count;
  sparp_audit_mem (sparp);
}

/* PART 2. GRAPH PATTERN TERM REWRITING */

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
  return sparp_find_gp_by_alias_int (sparp, sparp->sparp_expr->_.req_top.pattern, alias);
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
      gp = sparp_find_gp_by_alias_int (sparp, sparp->sparp_expr->_.req_top.pattern, var->_.var.selid);
      if (NULL == gp)
        return NULL;
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
  return NULL;
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
  qm = var_triple->_.triple.qm_list[0];
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
  return 0;
}

SPART *sparp_find_gp_by_eq_idx (sparp_t *sparp, ptrlong eq_idx)
{
#ifdef DEBUG
  if (SPART_BAD_EQUIV_IDX == eq_idx)
    spar_internal_error (sparp, "sparp_" "find_gp_by_eq_idx(): bad eq_idx");
  if (eq_idx >= sparp->sparp_env->spare_equiv_count)
    spar_internal_error (sparp, "sparp_" "find_gp_by_eq_idx(): eq_idx is too big");
  if (NULL == sparp->sparp_env->spare_equivs [eq_idx])
    spar_internal_error (sparp, "sparp_" "find_gp_by_eq_idx(): eq_idx of merged and disabled equiv");
#endif
  return sparp_find_gp_by_eq_idx_int (sparp, sparp->sparp_expr->_.req_top.pattern, eq_idx);
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

typedef struct sparp_tm_s {
  SPART rem_g, rem_s, rem_p, rem_o, isect_g, isect_s, isect_p, isect_o;
} sparp_tm_t;

ptrdiff_t qm_field_map_offsets[4] = {
  JSO_FIELD_OFFSET(quad_map_t,qmGraphMap),
  JSO_FIELD_OFFSET(quad_map_t,qmSubjectMap),
  JSO_FIELD_OFFSET(quad_map_t,qmPredicateMap),
  JSO_FIELD_OFFSET(quad_map_t,qmObjectMap) };

ptrdiff_t qm_field_constants_offsets[4] = {
  JSO_FIELD_OFFSET(quad_map_t,qmGraphRange.rvrFixedValue),
  JSO_FIELD_OFFSET(quad_map_t,qmSubjectRange.rvrFixedValue),
  JSO_FIELD_OFFSET(quad_map_t,qmPredicateRange.rvrFixedValue),
  JSO_FIELD_OFFSET(quad_map_t,qmObjectRange.rvrFixedValue) };

#define SSG_QM_NO_MATCH			0	/*!< Triple matching triple pattern can not match the qm restriction, disjoint */
#define SSG_QM_PARTIAL_MATCH		1	/*!< Triple matching triple pattern may match the qm restriction, but no warranty, common case */
#define SSG_QM_FULL_MATCH		2	/*!< Triple matching triple pattern will also match the qm restriction, but no warranty, triple pattern is more strict than qm */
#define SSG_QM_FULL_EXCLUSIVE_MATCH	3	/*!< SSG_QM_FULL_MATCH plus qm is exclusive so red cut and no more search for possible quad maps of lower priority */

int
sparp_check_field_mapping_g (sparp_t *sparp, SPART *triple, SPART *field, SPART **sources, int ignore_named_sources,
  quad_map_t *qm, rdf_val_range_t *rvr)
{
  if (SPAR_IS_BLANK_OR_VAR(field))
    {
      int ctr;
      int source_found = 0;
      if (SPART_VARR_FIXED & field->_.var.rvr.rvrRestrictions)
        {
          sparp_equiv_t *eq_g = sparp->sparp_env->spare_equivs[field->_.var.equiv_idx];
          if (DV_UNAME != DV_TYPE_OF (eq_g->e_rvr.rvrFixedValue))
            { /* This would be very strange failure */
#ifdef DEBUG
              GPF_T1 ("sparp_check_triple_mapping(): non-UNAME fixed value of variable used as graph of a triple. Legal but strange");
#else
              return SSG_QM_NO_MATCH;
#endif
            }
          if (!sparp_fixedvalues_equal (sparp, eq_g->e_rvr.rvrFixedValue, rvr->rvrFixedValue))
            return SSG_QM_NO_MATCH;
          return SSG_QM_FULL_MATCH;
        }
      DO_BOX_FAST (SPART *, source, ctr, sources)
        {
          if ((NAMED_L == SPART_TYPE(source)) && ignore_named_sources)
            continue;
          if (!strcmp (source->_.lit.val, rvr->rvrFixedValue))
            {
              source_found = 1;
              break;
            }
        }
      END_DO_BOX_FAST;
      if (!source_found)
        {
          if (0 != BOX_ELEMENTS (sources))
            return SSG_QM_NO_MATCH;
          return SSG_QM_PARTIAL_MATCH;
        }
      return SSG_QM_PARTIAL_MATCH;
    }
  if (SPAR_IS_LIT_OR_QNAME (field))
    {
      caddr_t eff_val = SPAR_LIT_OR_QNAME_VAL (field);
      if (DV_UNAME != DV_TYPE_OF (eff_val))
        { /* This would be very-very strange failure */
#ifdef DEBUG
          GPF_T1 ("sparp_check_triple_mapping(): non-UNAME constant used as graph of a triple, legal but strange");
#else
          return SSG_QM_NO_MATCH;
#endif
        }
      if (!sparp_fixedvalues_equal (sparp, field, rvr->rvrFixedValue))
        return SSG_QM_NO_MATCH;
      return SSG_QM_FULL_MATCH;
    }
  GPF_T1("ssg_check_field_mapping_g(): field is neither variable nor literal?");
  return SSG_QM_NO_MATCH;
}

int
sparp_check_field_mapping_spo (sparp_t *sparp, SPART *triple, SPART *field,
  quad_map_t *qm, rdf_val_range_t *rvr)
{
  if (SPAR_IS_BLANK_OR_VAR(field))
    {
      int source_found = 0;
      if (SPART_VARR_FIXED & field->_.var.rvr.rvrRestrictions)
        {
          sparp_equiv_t *eq_g = sparp->sparp_env->spare_equivs[field->_.var.equiv_idx];
          if (!sparp_fixedvalues_equal (sparp, eq_g->e_rvr.rvrFixedValue, rvr->rvrFixedValue))
            return SSG_QM_NO_MATCH;
          return SSG_QM_FULL_MATCH;
        }
      return SSG_QM_PARTIAL_MATCH;
    }
  if (SPAR_IS_LIT_OR_QNAME (field))
    {
      caddr_t eff_val = SPAR_LIT_OR_QNAME_VAL (field);
      if (!sparp_fixedvalues_equal (sparp, field, rvr->rvrFixedValue))
        return SSG_QM_NO_MATCH;
      return SSG_QM_FULL_MATCH;
    }
  GPF_T1("ssg_check_field_mapping_spo(): field is neither variable nor literal?");
  return SSG_QM_NO_MATCH;
}

int
sparp_check_triple_mapping (sparp_t *sparp, SPART *triple, SPART **sources, int ignore_named_sources,
  quad_map_t *qm /*, SPART **remaining_triple_ptr, SPART **intersect_triple_ptr */ )
{
  sparp_tm_t tm;
  SPART *src_g = triple->_.triple.tr_graph;
  SPART *src_s = triple->_.triple.tr_subject;
  SPART *src_p = triple->_.triple.tr_predicate;
  SPART *src_o = triple->_.triple.tr_object;
  int g_match = SSG_QM_FULL_MATCH, s_match = SSG_QM_FULL_MATCH,
    p_match = SSG_QM_FULL_MATCH, o_match = SSG_QM_FULL_MATCH;
  if (NULL == qm)
    return SSG_QM_NO_MATCH;    
  memset (&tm, 0, sizeof (sparp_tm_t));
  if (NULL != qm->qmGraphRange.rvrFixedValue)
    {
      g_match = sparp_check_field_mapping_g (sparp, triple, triple->_.triple.tr_graph, sources, ignore_named_sources, qm, &(qm->qmGraphRange));
      if (SSG_QM_NO_MATCH == g_match)
        return SSG_QM_NO_MATCH;
    }
  if (NULL != qm->qmSubjectRange.rvrFixedValue)
    {
      s_match = sparp_check_field_mapping_spo (sparp, triple, triple->_.triple.tr_subject, qm, &(qm->qmSubjectRange));
      if (SSG_QM_NO_MATCH == s_match)
        return SSG_QM_NO_MATCH;
    }
  if (NULL != qm->qmPredicateRange.rvrFixedValue)
    {
      p_match = sparp_check_field_mapping_spo (sparp, triple, triple->_.triple.tr_predicate, qm, &(qm->qmPredicateRange));
      if (SSG_QM_NO_MATCH == p_match)
        return SSG_QM_NO_MATCH;
    }
  if (NULL != qm->qmObjectRange.rvrFixedValue)
    {
      o_match = sparp_check_field_mapping_spo (sparp, triple, triple->_.triple.tr_object, qm, &(qm->qmObjectRange));
      if (SSG_QM_NO_MATCH == o_match)
        return SSG_QM_NO_MATCH;
    }
  if ((SSG_QM_FULL_MATCH == g_match) && (SSG_QM_FULL_MATCH == s_match) &&
    (SSG_QM_FULL_MATCH == p_match) && (SSG_QM_FULL_MATCH == o_match) )
    return SSG_QM_FULL_MATCH;
  return SSG_QM_PARTIAL_MATCH;
}

int
sparp_qm_find_triple_mappings (sparp_t *sparp, SPART *triple, SPART **sources, int ignore_named_sources, quad_map_t *qm, dk_set_t *qm_set_ret /*, SPART **remaining_triple_ptr, SPART **intersect_triple_ptr */ )
{
  int ctr;
  int common_status = sparp_check_triple_mapping (sparp, triple, sources, ignore_named_sources, qm /*, SPART **remaining_triple_ptr, SPART **intersect_triple_ptr */ );
  if (SSG_QM_NO_MATCH == common_status)
    return SSG_QM_NO_MATCH;
  DO_BOX_FAST (quad_map_t *, sub_qm, ctr, qm->qmUserSubMaps)
    {
      int status = sparp_qm_find_triple_mappings (sparp, triple, sources, ignore_named_sources, sub_qm, qm_set_ret);
      if (SSG_QM_FULL_EXCLUSIVE_MATCH == status)
        return SSG_QM_FULL_EXCLUSIVE_MATCH;
    }
  END_DO_BOX_FAST;
  if (!(SPART_QM_EMPTY & qm->qmMatchingFlags))
    dk_set_push (qm_set_ret, qm);
  if ((SSG_QM_FULL_MATCH == common_status) && (SPART_QM_EXCLUSIVE & qm->qmMatchingFlags))
    return SSG_QM_FULL_EXCLUSIVE_MATCH;
  return common_status;
}

quad_map_t **
sparp_find_triple_mappings (sparp_t *sparp, SPART *triple, SPART **sources, int ignore_named_sources)
{
  int ctr;
  dk_set_t res = NULL;
  quad_map_t **res_list;
  if (NULL == sparp->sparp_storage)
    {
      quad_map_t **res_list = (quad_map_t **)t_list (1, qm_default);
      mp_box_tag_modify (res_list, DV_ARRAY_OF_LONG);
      return res_list;
    }
  DO_BOX_FAST (quad_map_t *, qm, ctr, sparp->sparp_storage->qsMjvMaps)
    {
      int status;
      if (0 != BOX_ELEMENTS_0 (qm->qmUserSubMaps))
        spar_internal_error (sparp, "RDF quad mapping metadata are corrupted: MJV has submaps; the quad storage used in the query should be configured again");
      if (SPART_QM_EMPTY & qm->qmMatchingFlags)
        spar_internal_error (sparp, "RDF quad mapping metadata are corrupted: MJV is declared as empty; the quad storage used in the query should be configured again");
      status = sparp_check_triple_mapping (sparp, triple, sources, ignore_named_sources, qm /*, SPART **remaining_triple_ptr, SPART **intersect_triple_ptr */ );
      if (SSG_QM_NO_MATCH != status)
        dk_set_push (&res, qm);
      if (SSG_QM_FULL_EXCLUSIVE_MATCH == status)
        goto full_exclusive_match_detected;
    }
  END_DO_BOX_FAST;
  DO_BOX_FAST (quad_map_t *, qm, ctr, sparp->sparp_storage->qsUserMaps)
    {
      int status = sparp_qm_find_triple_mappings (sparp, triple, sources, ignore_named_sources, qm, &res /*, SPART **remaining_triple_ptr, SPART **intersect_triple_ptr */ );
      if (SSG_QM_FULL_EXCLUSIVE_MATCH == status)
        goto full_exclusive_match_detected;
    }
  END_DO_BOX_FAST;
  if (NULL != sparp->sparp_storage->qsDefaultMap)
    dk_set_push (&res, sparp->sparp_storage->qsDefaultMap);

full_exclusive_match_detected:
#if 0
  if (NULL == res)
    spar_internal_error (sparp, "Empty quad map list :(");
#else
#ifdef DEBUG
  if (NULL == res)
    {
      printf ("Empty quad map list:");
      printf ("\nStorage : "); dbg_print_box (sparp->sparp_env->spare_storage_name, stdout);
      printf ("\nGraph   : "); dbg_print_box ((caddr_t)(triple->_.triple.tr_graph), stdout);
      printf ("\nSubj    : "); dbg_print_box ((caddr_t)(triple->_.triple.tr_subject), stdout);
      printf ("\nPred    : "); dbg_print_box ((caddr_t)(triple->_.triple.tr_predicate), stdout);
      printf ("\nObj     : "); dbg_print_box ((caddr_t)(triple->_.triple.tr_object), stdout);
      printf ("\n");
    }
#endif
#endif
  res_list = (quad_map_t **)t_revlist_to_array (res);
  mp_box_tag_modify (res_list, DV_ARRAY_OF_LONG);
  while (res) dk_set_pop (&res);
  return res_list;
}

void
sparp_refresh_triple_mappings (sparp_t *sparp, SPART *triple)
{
  SPART **sources = sparp->sparp_expr->_.req_top.sources;
  /*ssg_valmode_t valmodes[SPART_TRIPLE_FIELDS_COUNT];*/
  quad_map_t **new_mappings;
  int new_mappings_count, ctr;
  int field_ctr;
  SPART *graph = triple->_.triple.tr_graph;
  int ignore_named_sources = (
    (SPAR_VARIABLE == SPART_TYPE(graph)) &&
    !strcmp (SPAR_VARNAME_DEFAULT_GRAPH, graph->_.var.vname) );
  new_mappings = sparp_find_triple_mappings (sparp, triple, sources, ignore_named_sources);
  for (field_ctr = SPART_TRIPLE_FIELDS_COUNT; field_ctr--; /*no step*/)
    {
      ssg_valmode_t field_valmode = SSG_VALMODE_AUTO;
      SPART *field_expn = triple->_.triple.tr_fields[field_ctr];
      rdf_val_range_t acc_rvr;
      new_mappings_count = BOX_ELEMENTS (new_mappings);
/*      if (!SPAR_IS_BLANK_OR_VAR (field_expn))
        {
          continue;
        }
*/
      memset (&acc_rvr, 0, sizeof (rdf_val_range_t));
      acc_rvr.rvrRestrictions = SPART_VARR_CONFLICT;
      for (ctr = 0; ctr < new_mappings_count; ctr++)
        {
          quad_map_t *qm = new_mappings[ctr];
          qm_value_t *qmv = SPARP_FIELD_QMV_OF_QM (qm,field_ctr);
          caddr_t fld_const = SPARP_FIELD_CONST_OF_QM (qm,field_ctr);
          rdf_val_range_t qmv_rvr;
          if (NULL != qmv)
            {
              field_valmode = ssg_smallest_union_valmode (field_valmode, qmv->qmvFormat);
              sparp_rvr_copy (sparp, &qmv_rvr, &(qmv->qmvRange));
              if ((NULL != qmv->qmvIriClass) && !(SPART_VARR_IRI_CALC & qmv_rvr.rvrRestrictions))
                {
                  qmv_rvr.rvrRestrictions |= (SPART_VARR_IRI_CALC | SPART_VARR_IS_REF | SPART_VARR_IS_IRI);
                  sparp_rvr_add_iri_classes (sparp, &qmv_rvr, &(qmv->qmvIriClass), 1);
                }
            }
          else if (NULL != fld_const)
            {
              if (NULL != qmv)
                spar_internal_error (sparp, "Invalid quad map storage metadata: quad map has set both quad map value and a constant for same field.");
              memset (&qmv_rvr, 0, sizeof (rdf_val_range_t));
              qmv_rvr.rvrFixedValue = fld_const;
            }
          else
            spar_internal_error (sparp, "Invalid quad map storage metadata: neither quad map value nor a constant is set for a field of a quad map.");
          if ((NULL != qmv_rvr.rvrFixedValue) && !(SPART_VARR_FIXED & qmv_rvr.rvrRestrictions))
            {
              if (DV_UNAME == DV_TYPE_OF (qmv_rvr.rvrFixedValue))
                qmv_rvr.rvrRestrictions |= (SPART_VARR_FIXED | SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_NOT_NULL);
              else
                qmv_rvr.rvrRestrictions |= (SPART_VARR_FIXED | SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL);
            }
          if (NULL != qmv)
            sparp_rvr_tighten (sparp, &qmv_rvr, &(qmv->qmvFormat->qmfValRange), ~SPART_VARR_IRI_CALC);
          sparp_rvr_loose (sparp, &acc_rvr, &qmv_rvr, ~0);
        }
      triple->_.triple.native_formats[field_ctr] = field_valmode;
      if (SPAR_IS_BLANK_OR_VAR (field_expn))
        sparp_rvr_tighten (sparp, &(field_expn->_.var.rvr), &acc_rvr, ~0);
    }
  triple->_.triple.qm_list = new_mappings;
}

SPART *
sparp_gp_detach_member_int (sparp_t *sparp, SPART *parent_gp, int member_idx, dk_set_t *touched_equivs_set_ptr)
{
  SPART *memb;
  SPART **old_members = parent_gp->_.gp.members;
  int old_len = BOX_ELEMENTS (old_members);
#ifdef DEBUG
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

SPART *
sparp_tree_full_clone_int (sparp_t *sparp, SPART *orig, SPART *parent_gp)
{
  int filt_ctr, memb_ctr, eq_ctr, arg_ctr, fld_ctr, eq_idx, cloned_eq_idx;
  SPART *tgt;
  switch (SPART_TYPE (orig))
    {
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
      tgt->_.var.selid = t_box_sprintf (100, "%s-c%d", orig->_.var.selid, sparp->sparp_cloning_serial);
      if (NULL != orig->_.var.tabid)
        tgt->_.var.tabid = t_box_sprintf (100, "%s-c%d", orig->_.var.tabid, sparp->sparp_cloning_serial);
      tgt->_.var.vname = t_box_copy (orig->_.var.vname);
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
      tgt->_.gp.selid = t_box_sprintf (100, "%s-c%d", orig->_.gp.selid, sparp->sparp_cloning_serial);
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
                  if (subv_eq->e_cloning_serial != sparp->sparp_cloning_serial)
                    spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): subv eq not cloned");
                  cloned_subs [subv_ctr] = subv_eq->e_clone_idx;
                }
              END_DO_BOX_FAST_REV;
            }
        }
      return tgt;
    case SPAR_LIT: case SPAR_QNAME: /* case SPAR_QNAME_NS: */
      return (SPART *)t_full_box_copy_tree ((caddr_t)orig);
    case SPAR_TRIPLE:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.triple.selid = t_box_sprintf (100, "%s-c%d", orig->_.triple.selid, sparp->sparp_cloning_serial);
      tgt->_.triple.tabid = t_box_sprintf (100, "%s-c%d", orig->_.triple.tabid, sparp->sparp_cloning_serial);
      for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /*no step*/)
        tgt->_.triple.tr_fields[fld_ctr] = sparp_tree_full_clone_int (sparp, orig->_.triple.tr_fields[fld_ctr], parent_gp);
      return tgt;
    case SPAR_BUILT_IN_CALL:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.builtin.args = (SPART **)t_box_copy ((caddr_t) orig->_.builtin.args);
      DO_BOX_FAST_REV (SPART *, arg, arg_ctr, orig->_.builtin.args)
        {
          tgt->_.builtin.args[arg_ctr] = sparp_tree_full_clone_int (sparp, arg, parent_gp);
        }
      END_DO_BOX_FAST_REV;
      return tgt;
    case SPAR_FUNCALL:
      tgt = (SPART *)t_box_copy ((caddr_t) orig);
      tgt->_.funcall.argtrees = (SPART **)t_box_copy ((caddr_t) orig->_.funcall.argtrees);
      for (arg_ctr = orig->_.funcall.argcount; arg_ctr--; /*no step*/)
        tgt->_.funcall.argtrees[arg_ctr] = sparp_tree_full_clone_int (sparp, orig->_.funcall.argtrees[arg_ctr], parent_gp);
      return tgt;
    case SPAR_REQ_TOP:
      spar_error (sparp, "Internal SPARQL compiler error: can not clone TOP of request");
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
/* Add more cases right above this line when introducing more SPAR_nnn constants */
    default: break; /* No need to copy names and literals because we will never change them in-place. */
    }
  spar_internal_error (sparp, "sparp_" "tree_full_clone_int(): unsupported type of expression");
  return NULL; /* to keep C compiler happy */
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
sparp_gp_detach_member (sparp_t *sparp, SPART *parent_gp, int member_idx, sparp_equiv_t ***touched_equivs_ptr)
{
  dk_set_t touched_equivs_set = NULL;
  dk_set_t *touched_equivs_set_ptr = ((NULL != touched_equivs_ptr) ? &touched_equivs_set : NULL);
  SPART **old_members = parent_gp->_.gp.members;
  SPART *memb = sparp_gp_detach_member_int (sparp, parent_gp, member_idx, touched_equivs_set_ptr);
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
  DO_BOX_FAST_REV (SPART *, memb, member_idx, old_members)
    {
      sparp_gp_detach_member_int (sparp, parent_gp, member_idx, touched_equivs_set_ptr);
    }
  END_DO_BOX_FAST_REV;
  if (NULL != touched_equivs_ptr)
    touched_equivs_ptr[0] = (sparp_equiv_t **)(t_revlist_to_array (touched_equivs_set));
  parent_gp->_.gp.members = (SPART **)t_list(0);
  sparp_equiv_audit_all (sparp, 0);
  return old_members;
}

void
sparp_gp_attach_member_int (sparp_t *sparp, SPART *parent_gp, SPART *memb, dk_set_t *touched_equivs_set_ptr)
{
  SPART **old_members = parent_gp->_.gp.members;
  int old_len = BOX_ELEMENTS (old_members);
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
  int old_len = BOX_ELEMENTS (old_members);
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
  int old_len = BOX_ELEMENTS (old_members);
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

int sparp_gp_detach_filter_cbk (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
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

SPART *
sparp_gp_detach_filter (sparp_t *sparp, SPART *parent_gp, int filter_idx, sparp_equiv_t ***touched_equivs_ptr)
{
  void *trav_envs [SPARP_MAX_SYNTDEPTH];
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
  sparp_gp_trav_int (sparp, filt, trav_envs + 1, touched_equivs_set_ptr,
    NULL, NULL,
    sparp_gp_detach_filter_cbk, NULL, NULL );
  if (NULL != touched_equivs_ptr)
    touched_equivs_ptr[0] = (sparp_equiv_t **)(t_revlist_to_array (touched_equivs_set));
  parent_gp->_.gp.filters = (SPART **)t_list_remove_nth ((caddr_t)old_filters, filter_idx);
  sparp_equiv_audit_all (sparp, 0);
  return filt;
}

SPART **
sparp_gp_detach_all_filters (sparp_t *sparp, SPART *parent_gp, sparp_equiv_t ***touched_equivs_ptr)
{
  void *trav_envs [SPARP_MAX_SYNTDEPTH];
  SPART **filters = parent_gp->_.gp.filters;
  int len = BOX_ELEMENTS (filters);
  int filt_ctr;
  dk_set_t touched_equivs_set = NULL;
  dk_set_t *touched_equivs_set_ptr = ((NULL == touched_equivs_ptr) ? NULL : &touched_equivs_set);
  DO_BOX_FAST_REV (SPART *, filt, filt_ctr, filters)
    {
      sparp_gp_trav_int (sparp, filt, trav_envs + 1, touched_equivs_set_ptr,
        NULL, NULL,
        sparp_gp_detach_filter_cbk, NULL, NULL );
    }
  END_DO_BOX_FAST_REV;
  if (NULL != touched_equivs_ptr)
    touched_equivs_ptr[0] = (sparp_equiv_t **)(t_revlist_to_array (touched_equivs_set));
  parent_gp->_.gp.filters = (SPART **)t_list (0);
  sparp_equiv_audit_all (sparp, 0);
  return filters;
}


int
sparp_gp_attach_filter_cbk (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  if (SPAR_IS_BLANK_OR_VAR (curr))
    {
      dk_set_t *touched_equivs_set_ptr = (dk_set_t *) common_env;
      SPART *parent_gp;
      sparp_equiv_t *eq;
      int idx = curr->_.var.equiv_idx;
      if (SPART_BAD_EQUIV_IDX != idx)
        spar_internal_error (sparp, "sparp_" "gp_attach_filter_cbk(): attempt to attach a filter with used variable");
      parent_gp = (SPART *)(trav_env_this [-1]);
      curr->_.var.selid = t_box_copy (parent_gp->_.gp.selid);
      eq = sparp_equiv_get (sparp, parent_gp, curr, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE | SPARP_EQUIV_ADD_CONST_READ);
      if (NULL != touched_equivs_set_ptr)
        if (0 > dk_set_position (touched_equivs_set_ptr[0], eq))
          t_set_push (touched_equivs_set_ptr, eq);
/*!!!TBD: the following is added to hide errors like 'Variable ':named_graphs' is used in subexpressions of the query but not assigned' */
      if (SPART_VARR_GLOBAL & curr->_.var.rvr.rvrRestrictions)
        eq->e_rvr.rvrRestrictions |= SPART_VARR_GLOBAL;
    }
  return 0;
}

void
sparp_gp_attach_filter (sparp_t *sparp, SPART *parent_gp, SPART *new_filt, int insert_before_idx, sparp_equiv_t ***touched_equivs_ptr)
{
  void *trav_envs [SPARP_MAX_SYNTDEPTH];
  SPART **old_filters = parent_gp->_.gp.filters;
  int old_len = BOX_ELEMENTS (old_filters);
  dk_set_t touched_equivs_set = NULL;
  dk_set_t *touched_equivs_set_ptr = ((NULL == touched_equivs_ptr) ? NULL : &touched_equivs_set);
#ifdef DEBUG
  if ((0 > insert_before_idx) || (old_len < insert_before_idx))
    spar_internal_error (sparp, "sparp_" "gp_attach_filter(): bad insert_before_idx");
#endif
  parent_gp->_.gp.filters = (SPART **)t_list_insert_before_nth ((caddr_t)old_filters, (caddr_t)new_filt, insert_before_idx);
  memset (trav_envs, 0, sizeof (void *) * SPARP_MAX_SYNTDEPTH);
  trav_envs [0] = parent_gp;
  sparp_gp_trav_int (sparp, new_filt, trav_envs + 1, touched_equivs_set_ptr,
    NULL, NULL,
    sparp_gp_attach_filter_cbk, NULL, NULL );
  if (NULL != touched_equivs_ptr)
    touched_equivs_ptr[0] = (sparp_equiv_t **)(t_revlist_to_array (touched_equivs_set));
  sparp_equiv_audit_all (sparp, 0);
}

void
sparp_gp_attach_many_filters (sparp_t *sparp, SPART *parent_gp, SPART **new_filters, int insert_before_idx, sparp_equiv_t ***touched_equivs_ptr)
{
  void *trav_envs [SPARP_MAX_SYNTDEPTH];
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
  memset (trav_envs, 0, sizeof (void *) * SPARP_MAX_SYNTDEPTH);
  trav_envs [0] = parent_gp;
  for (filt_ctr = ins_count; filt_ctr--; /*no step*/)
    sparp_gp_trav_int (sparp, new_filters [filt_ctr], trav_envs + 1, touched_equivs_set_ptr,
      NULL, NULL,
      sparp_gp_attach_filter_cbk, NULL, NULL );
  if (NULL != touched_equivs_ptr)
    touched_equivs_ptr[0] = (sparp_equiv_t **)(t_revlist_to_array (touched_equivs_set));
  sparp_equiv_audit_all (sparp, 0);
}

void sparp_gp_deprecate (sparp_t *sparp, SPART *gp)
{
  int eq_ctr, memb_ctr;
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
}


void
sparp_flatten_union (sparp_t *sparp, SPART *parent_gp)
{
  int memb_ctr;
#ifdef DEBUG
  if (SPAR_GP != SPART_TYPE (parent_gp))
    spar_internal_error (sparp, "sparp_" "flatten_union(): parent_gp is not a GP");
  if (UNION_L != parent_gp->_.gp.subtype)
    spar_internal_error (sparp, "sparp_" "flatten_union(): parent_gp is not a union");
#endif
  for (memb_ctr = BOX_ELEMENTS (parent_gp->_.gp.members); memb_ctr--; /*no step*/)
    {
      SPART *memb = parent_gp->_.gp.members [memb_ctr];
      if ((SPAR_GP == SPART_TYPE (memb)) && (UNION_L == memb->_.gp.subtype))
        {
          int sub_count = BOX_ELEMENTS (memb->_.gp.members);
          int sub_ctr;
          SPART **memb_filters = sparp_gp_detach_all_filters (sparp, memb, NULL);
          int memb_filters_count = BOX_ELEMENTS_0 (memb_filters);
          for (sub_ctr = sub_count; sub_ctr--; /* no step */)
            {
              SPART *sub_memb = sparp_gp_detach_member (sparp, memb, sub_ctr, NULL);
              sparp_gp_attach_member (sparp, parent_gp, sub_memb, memb_ctr, NULL);
              if (0 != memb_filters_count)
                sparp_gp_attach_many_filters (sparp, sub_memb, (SPART **)t_full_box_copy_tree ((caddr_t)memb_filters), 0, NULL);
            }
          memb_ctr += sub_count;
          sparp_gp_detach_member (sparp, parent_gp, memb_ctr, NULL);
        }
    }
}

void
sparp_set_triple_selid_and_tabid (sparp_t *sparp, SPART *triple, caddr_t new_selid, caddr_t new_tabid)
{
  int field_ctr;
  if (
    !strcmp (triple->_.triple.tabid, new_tabid) &&
    !strcmp (triple->_.triple.selid, new_selid) )
    return;
  for (field_ctr = SPART_TRIPLE_FIELDS_COUNT; field_ctr--; /*no step*/)
    {
      SPART *fld_expn = triple->_.triple.tr_fields[field_ctr];
      if (!SPAR_IS_BLANK_OR_VAR (fld_expn))
        continue;
      if (strcmp (fld_expn->_.var.selid, new_selid)) /* weird re-location */
        {
          if (SPART_BAD_EQUIV_IDX != fld_expn->_.var.equiv_idx)
            {
              sparp_equiv_t *eq = SPARP_EQUIV (sparp, fld_expn->_.var.equiv_idx);
              sparp_equiv_remove_var (sparp, eq, fld_expn);
            }
          fld_expn->_.var.selid = t_box_copy (new_selid);
        }
      fld_expn->_.var.tabid = t_box_copy (new_tabid);
    }
  triple->_.triple.selid = t_box_copy (new_selid);
  triple->_.triple.tabid = t_box_copy (new_tabid);
}

int
sparp_set_retval_selid_cbk (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  if (SPAR_IS_BLANK_OR_VAR (curr))
    curr->_.var.selid = t_box_copy (common_env);
  return 0;
}

void
sparp_set_retval_and_order_selid (sparp_t *sparp)
{
  int ctr;
  void *trav_envs [SPARP_MAX_SYNTDEPTH];
  caddr_t top_gp_selid = sparp->sparp_expr->_.req_top.pattern->_.gp.selid;
  DO_BOX_FAST (SPART *, filt, ctr, sparp->sparp_expr->_.req_top.retvals)
    {
      sparp_gp_trav_int (sparp, filt, trav_envs + 1, top_gp_selid,
        NULL, NULL,
        sparp_set_retval_selid_cbk, NULL, NULL );
    }
  END_DO_BOX_FAST;
  DO_BOX_FAST (SPART *, oby, ctr, sparp->sparp_expr->_.req_top.order)
    {
      sparp_gp_trav_int (sparp, oby->_.oby.expn, trav_envs + 1, top_gp_selid,
        NULL, NULL,
        sparp_set_retval_selid_cbk, NULL, NULL );
    }
  END_DO_BOX_FAST;
}

int
sparp_set_special_order_selid_cbk (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  SPART *new_gp = (SPART *)common_env;
  if (SPAR_IS_BLANK_OR_VAR (curr))
    {
      sparp_equiv_t *eq;
/* !!! TBD: replace with silent detach if needed.
      int idx = curr->_.var.equiv_idx;
      if (SPART_BAD_EQUIV_IDX != idx)
        spar_internal_error (sparp, "sparp_" "set_special_order_selid(): attempt to attach a filter with used variable"); */
      curr->_.var.selid = t_box_copy (new_gp->_.gp.selid);
      eq = sparp_equiv_get (sparp, new_gp, curr, SPARP_EQUIV_INS_VARIABLE/* !!!TBD: add | SPARP_EQUIV_ADD_CONST_READ*/);
      if (NULL == eq)
        spar_internal_error (sparp, "sparp_" "set_special_order_selid(): variable in order by comes from nowhere");
      curr->_.var.equiv_idx = eq->e_own_idx;
    }
  return 0;
}

void
sparp_set_special_order_selid (sparp_t *sparp, SPART *new_gp)
{
  int ctr;
  void *trav_envs [SPARP_MAX_SYNTDEPTH];
  DO_BOX_FAST (SPART *, oby, ctr, sparp->sparp_expr->_.req_top.order)
    {
      sparp_gp_trav_int (sparp, oby->_.oby.expn, trav_envs + 1, new_gp,
        NULL, NULL,
        sparp_set_special_order_selid_cbk, NULL, NULL );
    }
  END_DO_BOX_FAST;
}

SPART **
sparp_make_qm_cases (sparp_t *sparp, SPART *triple)
{
  quad_map_t **qm_list = triple->_.triple.qm_list;
  SPART **res;
  int qm_idx;
#ifdef DEBUG
  if (1 >= BOX_ELEMENTS (triple->_.triple.qm_list))
    spar_internal_error (sparp, "sparp_" "make_qm_cases(): redundant call");
#endif
  res = (SPART **)t_alloc_box (box_length (qm_list), DV_ARRAY_OF_POINTER);
  DO_BOX_FAST (quad_map_t *, qm, qm_idx, qm_list)
    {
      int field_ctr;
      SPART *qm_case_triple = (SPART *)t_box_copy ((caddr_t)triple);
      SPART *qm_case_gp = sparp_new_empty_gp (sparp, 0, unbox (triple->srcline));
      caddr_t qm_selid = qm_case_gp->_.gp.selid;
      caddr_t qm_tabid = t_box_sprintf (100, "%s-qm%d", triple->_.triple.tabid, qm_idx);
      quad_map_t **one_qm = (quad_map_t **)t_list (1, qm);
      mp_box_tag_modify (one_qm, DV_ARRAY_OF_LONG);
      qm_case_triple->_.triple.qm_list = one_qm;
      qm_case_triple->_.triple.selid = t_box_copy (qm_selid);
      qm_case_triple->_.triple.tabid = qm_tabid;
      for (field_ctr = SPART_TRIPLE_FIELDS_COUNT; field_ctr--; /*no step*/)
        {
          SPART *fld_expn = triple->_.triple.tr_fields[field_ctr];
          qm_value_t *fld_qmv = SPARP_FIELD_QMV_OF_QM (qm,field_ctr);
          caddr_t fld_const = SPARP_FIELD_CONST_OF_QM (qm,field_ctr);
          SPART *new_fld_expn;
          if (SPAR_IS_BLANK_OR_VAR (fld_expn))
            {
              sparp_equiv_t *eq;
              new_fld_expn = (SPART *)t_box_copy ((caddr_t)fld_expn);
              new_fld_expn->_.var.selid = t_box_copy (qm_selid);
              new_fld_expn->_.var.tabid = t_box_copy (qm_tabid);
              new_fld_expn->_.var.vname = t_box_copy (fld_expn->_.var.vname);
              new_fld_expn->_.var.equiv_idx = SPART_BAD_EQUIV_IDX;
              eq = sparp_equiv_get (sparp, qm_case_gp, new_fld_expn, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE | SPARP_EQUIV_ADD_GPSO_USE);
              if (NULL == fld_qmv)
                sparp_equiv_restrict_by_literal (sparp, eq, NULL, (SPART *)fld_const);
              else
                {
                  sparp_equiv_tighten (sparp, eq, &(fld_qmv->qmvRange), ~SPART_VARR_IRI_CALC);
                  sparp_equiv_tighten (sparp, eq, &(fld_qmv->qmvFormat->qmfValRange), ~SPART_VARR_IRI_CALC);
                }
              sparp_rvr_tighten (sparp, (&new_fld_expn->_.var.rvr), &(eq->e_rvr), ~0);
            }
          else
            new_fld_expn = (SPART *)t_full_box_copy_tree ((caddr_t)fld_expn);
          qm_case_triple->_.triple.tr_fields[field_ctr] = new_fld_expn;
          qm_case_triple->_.triple.native_formats[field_ctr] = ((NULL != fld_qmv) ? fld_qmv->qmvFormat : SSG_VALMODE_AUTO);
        }
      sparp_gp_attach_member (sparp, qm_case_gp, qm_case_triple, 0, NULL);
      res [qm_idx] = qm_case_gp;
    }
  END_DO_BOX_FAST;
  return res;
}

SPART *
sparp_new_empty_gp (sparp_t *sparp, ptrlong subtype, ptrlong srcline)
{
  SPART *res = spartlist (sparp, 7,
    SPAR_GP, subtype,
    t_list (0),
    t_list (0),
    spar_mkid (sparp, "s"),
    NULL, (ptrlong)(0) );
  res->srcline = t_box_num (srcline);
  return res;
}

void
sparp_gp_produce_nothing (sparp_t *sparp, SPART *curr)
{
  int eq_ctr;
  SPARP_REVFOREACH_GP_EQUIV (sparp, curr, eq_ctr, eq)
    {
      int recv_eq_ctr;
      switch (curr->_.gp.subtype)
        {
          case OPTIONAL_L:
            eq->e_rvr.rvrRestrictions |= SPART_VARR_ALWAYS_NULL;
            continue;
          case UNION_L:
            eq->e_rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
            continue;
        }
      DO_BOX_FAST (ptrlong, recv_eq_idx, recv_eq_ctr, eq->e_receiver_idxs)
        {
          sparp_equiv_t *recv_eq = SPARP_EQUIV (sparp, recv_eq_idx);
          recv_eq->e_rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
          sparp_equiv_disconnect (sparp, recv_eq, eq);
        }
      END_DO_BOX_FAST;
    }
  END_SPARP_REVFOREACH_GP_EQUIV;
  sparp_gp_detach_all_filters (sparp, curr, NULL);
  while (0 < BOX_ELEMENTS (curr->_.gp.members))
    sparp_gp_detach_member (sparp, curr, 0, NULL);
}

int sparp_gp_trav_refresh_triple_mappings (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  if (SPAR_TRIPLE != curr->type) /* Not a triple ? -- nothing to do */
    return 0;
  sparp_refresh_triple_mappings (sparp, curr);
  return SPAR_GPT_NODOWN;
}


int sparp_gp_trav_multiqm_to_unions (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  int memb_ctr;
  if (SPAR_GP != curr->type) /* Not a gp ? -- nothing to do */
    return 0;
  DO_BOX_FAST_REV (SPART *, memb, memb_ctr, curr->_.gp.members)
    { /* countdown direction of 'for' is important due to possible insertions/removals */
      int qm_count;
      SPART **qm_cases;
      int case_ctr;
      if (SPAR_TRIPLE != memb->type)
        continue;
      qm_count = BOX_ELEMENTS (memb->_.triple.qm_list);
      if (1 == qm_count)
        continue;
      if (0 == qm_count)
        {
          if (UNION_L != curr->_.gp.subtype)
            {
              sparp_gp_produce_nothing (sparp, curr);
              return SPAR_GPT_NODOWN;
            }
          sparp_gp_detach_member (sparp, curr, memb_ctr, NULL);
          continue;
        }
      sparp_gp_detach_member (sparp, curr, memb_ctr, NULL);
      qm_cases = sparp_make_qm_cases (sparp, memb);
      if (UNION_L == curr->_.gp.subtype)
        {
          DO_BOX_FAST_REV (SPART *, qm_case, case_ctr, qm_cases)
            {
              sparp_gp_attach_member (sparp, curr, qm_case, memb_ctr, NULL);
            }
          END_DO_BOX_FAST_REV;
        }
      else
        {
          SPART *case_union = sparp_new_empty_gp (sparp, UNION_L, unbox (memb->srcline));
          DO_BOX_FAST_REV (SPART *, qm_case, case_ctr, qm_cases)
            {
              sparp_gp_attach_member (sparp, case_union, qm_case, 0, NULL);
            }
          END_DO_BOX_FAST_REV;
          sparp_gp_attach_member (sparp, curr, case_union, memb_ctr, NULL);
        }
    }
  END_DO_BOX_FAST_REV;
  if (UNION_L == curr->_.gp.subtype)
    sparp_flatten_union (sparp, curr);
  return 0;
}

int
sparp_calc_importance_of_eq (sparp_t *sparp, sparp_equiv_t *eq)
{
  int res = 4 * eq->e_gspo_uses + 2 * eq->e_const_reads + 2 * BOX_ELEMENTS_0 (eq->e_receiver_idxs);
  if (SPART_VARR_FIXED & eq->e_rvr.rvrRestrictions)
    res *= 4;
  if (SPART_VARR_TYPED & eq->e_rvr.rvrRestrictions)
    res *= 2;
  if ((SPART_VARR_IS_IRI | SPART_VARR_IS_BLANK | SPART_VARR_IS_LIT) & eq->e_rvr.rvrRestrictions)
    res = res * 3 / 2;
  return res;
}

int
sparp_calc_importance_of_member (sparp_t *sparp, SPART *memb)
{
  int ctr;
  int res = 0;
  switch (memb->type)
    {
    case SPAR_TRIPLE:
      for (ctr = SPART_TRIPLE_FIELDS_COUNT; ctr--; /* no step */)
        {
          SPART *field = memb->_.triple.tr_fields [ctr];
          if (SPAR_IS_BLANK_OR_VAR (field))
            {
              sparp_equiv_t *eq = SPARP_EQUIV (sparp, field->_.var.equiv_idx);
              res += sparp_calc_importance_of_eq (sparp, eq);            
            }
          else
            res += 12;
        }
    case SPAR_GP:
      SPARP_REVFOREACH_GP_EQUIV (sparp, memb, ctr, eq)
        {
          res += sparp_calc_importance_of_eq (sparp, eq);
        }
      END_SPARP_REVFOREACH_GP_EQUIV;
      break;
    }
  return res;
}

int
sparp_find_index_of_most_important_union (sparp_t *sparp, SPART *parent_gp)
{
  int idx, best_idx = -1, best_importance = -1;
  DO_BOX_FAST_REV (SPART *, memb, idx, parent_gp->_.gp.members)
    {
      int importance;
      if ((SPAR_GP != memb->type) || (UNION_L != memb->_.gp.subtype))
        continue;
      importance = sparp_calc_importance_of_member (sparp, memb);
      if (importance >= best_importance) /* '>=', not '>' to give little preference to the leftmost union of a few */
        {
          best_idx = idx;
          best_importance = importance;
        }
    }
  END_DO_BOX_FAST_REV;
  return best_idx; 
}

int
sparp_gp_trav_union_of_joins_in (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      trav_env_this[0] = curr;
      return SPAR_GPT_ENV_PUSH;      
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN;
    default: return 0;
    }
}

int
sparp_gp_trav_union_of_joins_out (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  if (SPAR_GP != curr->type)
    return 0;
  if ((0 == curr->_.gp.subtype) || (WHERE_L == curr->_.gp.subtype))
    {
      int union_idx;
      int case_ctr, case_count;
      int curr_had_one_member = ((1 >= BOX_ELEMENTS (curr->_.gp.members)) ? 1 : 0);
      SPART *sub_union;
      SPART **detached_join_parts;
      SPART **detached_join_filters;
      SPART **detached_union_parts;
      SPART **detached_union_filters;
      SPART *new_union;
      SPART **new_union_joins;
      if ((curr_had_one_member) && (WHERE_L == curr->_.gp.subtype))
        return 0; /* top-level union can not be really optimized: we need a wrapper to give alias name to retval vars */
      union_idx = sparp_find_index_of_most_important_union (sparp, curr);
      if (0 > union_idx)
        return 0;
      sub_union = curr->_.gp.members [union_idx];
      case_count = BOX_ELEMENTS (sub_union->_.gp.members);
      if (WHERE_L == curr->_.gp.subtype)
        {
          if (curr_had_one_member)
            return 0;
        }
      else
        {
          int parent_len = 1;
          SPART *parent = (SPART *)(trav_env_this[-1]);
#ifdef DEBUG
          if (SPAR_GP != SPART_TYPE (parent))
            spar_internal_error (sparp, "sparp_" "gp_trav_union_of_joins_out (): parent is not a gp");
#endif
          if (UNION_L == parent->_.gp.subtype)
            parent_len = BOX_ELEMENTS (parent->_.gp.members);
          if (200 < (parent_len + case_count))
            return 0; /* This restricts the size of the resulting SQL statement */
        }
      sparp_equiv_audit_all (sparp, 0);
      detached_union_filters = sparp_gp_detach_all_filters (sparp, sub_union, NULL);
      detached_union_parts = sparp_gp_detach_all_members (sparp, sub_union, NULL);
      detached_join_filters = sparp_gp_detach_all_filters (sparp, curr, NULL);
      detached_join_parts = sparp_gp_detach_all_members (sparp, curr, NULL);
      if (curr_had_one_member)
        {
          new_union_joins = detached_union_parts;
        }
      else
        {
          new_union_joins = (SPART **)t_alloc_box (case_count * sizeof (SPART *), DV_ARRAY_OF_POINTER);
          for (case_ctr = 0; case_ctr < case_count; case_ctr++)
            new_union_joins [case_ctr] = sparp_new_empty_gp (sparp, 0, unbox (detached_union_parts [case_ctr]->srcline));
        }
      if (WHERE_L != curr->_.gp.subtype)
        {
          curr->_.gp.subtype = UNION_L;
          new_union = curr;
        }
      else
        {
          new_union = sparp_new_empty_gp (sparp, UNION_L, unbox (curr->srcline));
          sparp_gp_attach_member (sparp, curr, new_union, 0, NULL);
        }
      sparp_gp_attach_many_members (sparp, new_union, new_union_joins, 0, NULL);
      detached_join_parts [union_idx] = NULL;
      for (case_ctr = 0; case_ctr < case_count; case_ctr++)
        {
          int last_case = (((case_count-1) == case_ctr) ? 1 : 0);
          SPART *new_join = new_union->_.gp.members [case_ctr]; /* equal to union_part if curr_had_one_member */
          SPART **new_filts_u = (last_case ? detached_union_filters : (SPART **)t_full_box_copy_tree ((caddr_t)detached_union_filters));
          SPART **new_filts_j = (last_case ? detached_join_filters : (SPART **)t_full_box_copy_tree ((caddr_t)detached_join_filters));
          SPART **new_join_filts = (SPART **)t_list_concat ((caddr_t)new_filts_u, (caddr_t)new_filts_j);
          if (!curr_had_one_member)
            {
              int join_part_ctr;
              SPART *union_part = detached_union_parts [case_ctr];
              SPART **new_join_parts = (SPART **)t_box_copy ((caddr_t)detached_join_parts);
              new_join_parts [union_idx] = union_part;
              DO_BOX_FAST (SPART *, join_part, join_part_ctr, new_join_parts)
                {
                  if (SPAR_GP == join_part->type)
                    {
                      SPART *cloned_join_part = (last_case ? join_part : sparp_gp_full_clone (sparp, join_part));
                      new_join_parts [join_part_ctr] = cloned_join_part;
                    }
                  else
                    new_join_parts [join_part_ctr] = (last_case ? join_part : (SPART *)t_full_box_copy_tree ((caddr_t)join_part));
                }
              END_DO_BOX_FAST;
              sparp_gp_attach_many_members (sparp, new_join, new_join_parts, 0, NULL);
              sparp_equiv_audit_all (sparp, 0);
            }
          sparp_gp_attach_many_filters (sparp, new_join, new_join_filts, 0, NULL);
          sparp_equiv_audit_all (sparp, 0);
        }
      sparp->sparp_rewrite_dirty += 10;
      sparp_gp_deprecate (sparp, sub_union);
      sparp_equiv_audit_all (sparp, 0);
    }
  return 0;
}

int
sparp_gp_trav_reuse_tabids (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  if (SPAR_GP != curr->type)
    return 0;
  if ((0 == curr->_.gp.subtype) || (WHERE_L == curr->_.gp.subtype))
    {
      int base_idx;
      DO_BOX_FAST (SPART *, base, base_idx, curr->_.gp.members)
        {
          int key_field_idx;
          quad_map_t *base_qm;
          if (SPAR_TRIPLE != base->type) /* Only triples have tabids to merge */
            continue;
          if (1 != BOX_ELEMENTS (base->_.triple.qm_list)) /* Only triples with one qm can be reused, unions can not */
            continue;
          base_qm = base->_.triple.qm_list[0];
          for (key_field_idx = 0; key_field_idx < SPART_TRIPLE_FIELDS_COUNT; key_field_idx++)
            {
              SPART *key_field = base->_.triple.tr_fields[key_field_idx];
              ssg_valmode_t key_fmt = base->_.triple.native_formats[key_field_idx];
              qm_value_t *key_qmv;
              sparp_equiv_t *key_eq;
              int dep_ctr;
              if (!SPAR_IS_BLANK_OR_VAR (key_field)) /* Non-variables can not result in tabid reuse atm, !!!TBD: support for { <pk> ?p1 ?o1 . <pk> ?p2 ?o2 } */
                continue;
              key_qmv = SPARP_FIELD_QMV_OF_QM (base_qm,key_field_idx);
              if (NULL == key_qmv) /* Funny case: join on field that is mapped to constant. Thus there's no actual join, only filter (FIELD = CONST) for other triples */
                continue;
              if (!key_qmv->qmvColumnsFormKey) /* No key -- no reuse */
                continue;
              key_eq = sparp_equiv_get (sparp, curr, key_field, SPARP_EQUIV_GET_ASSERT);
              if (2 > key_eq->e_gspo_uses) /* No reuse of key -- no reuse of triples */
                continue;
              for (dep_ctr = key_eq->e_var_count; dep_ctr--; /* no step */)
                {
                  SPART *dep_field = key_eq->e_vars[dep_ctr];
                  int dep_triple_idx, dep_field_tr_idx;
                  SPART *dep_triple;
                  quad_map_t *dep_qm;
                  qm_value_t *dep_qmv;
                  if (NULL == dep_field->_.var.tabid) /* The variable is not a field in a triple (const read, not gspo use) */
                    continue;
                  if (!strcmp (dep_field->_.var.tabid, key_field->_.var.tabid)) /* Either tabid is reused already or reference to self -- nothing to do in both cases */
                    continue;
                  dep_field_tr_idx = dep_field->_.var.tr_idx;
                  for (dep_triple_idx = BOX_ELEMENTS (curr->_.gp.members); dep_triple_idx--; /* no step */)
                    {
                      dep_triple = curr->_.gp.members[dep_triple_idx];
                      if (SPAR_TRIPLE != dep_triple->type)
                        continue;
                      if (dep_triple->_.triple.tr_fields [dep_field_tr_idx] == dep_field)
                        break;
                    }
                  if (0 > dep_triple_idx)
                    spar_internal_error (sparp, "sparp_" "gp_trav_reuse_tabids(): dep_field not found in members");
                  if (dep_triple_idx < base_idx) /* Merge is symmetrical, so this pair of key and dep is checked from other end. In that time current dep was base and the current base was dep */
                    continue;
                  if (1 != BOX_ELEMENTS (dep_triple->_.triple.qm_list)) /* Only triples with one qm can be reused, unions can not */
                    continue;
                  dep_qm = dep_triple->_.triple.qm_list[0];
#if 0 /* There's no need to check this because if QMVs match then tables are the same, otherwise names does not matter anyway */
                  if (strcmp (dep_qm->qmTableName, base_qm->qmTableName)) /* Can not reuse tabid for different tables */
                    continue;
#endif
                  dep_qmv = SPARP_FIELD_QMV_OF_QM (dep_qm, dep_field_tr_idx);
                  if (NULL == dep_qmv) /* Funny case similar to the above checked case 'if (NULL == key_qmv)' */
                    continue;
                  if (key_qmv != dep_qmv) /* The key mapping differs in set of source columns or in the IRI serialization (or literal cast) */
                    continue;
                  /* Glory, glory, hallelujah; we can reuse the tabid so the final SQL query will have one join less. */
                  sparp_set_triple_selid_and_tabid (sparp, dep_triple, curr->_.gp.selid, base->_.triple.tabid);
                  if (dep_triple_idx > (base_idx + 1)) /* Adjustment to keep reused tabids together. The old join order of dep is of zero importance because there's no more dep as a separate subtable */
                    {
                      int swap_ctr;
                      for (swap_ctr = base_idx + 1; swap_ctr < dep_triple_idx; swap_ctr++)
                        curr->_.gp.members[swap_ctr + 1] = curr->_.gp.members[swap_ctr];
                      curr->_.gp.members[base_idx + 1] = dep_triple;
                    }
                }
            }
        }
      END_DO_BOX_FAST;
    }
  return 0;
}


void
sparp_rewrite_all (sparp_t *sparp)
{
  SPART *root = sparp->sparp_expr;
  if (SPAR_QM_SQL_FUNCALL == SPART_TYPE (root))
    return;
  sparp_expand_top_retvals (sparp);
/* Unlike spar_retvals_of_construct() that can be called during parsing,
spar_retvals_of_describe() should wait for obtaining all variables and then
sparp_expand_top_retvals () to process 'DESCRIBE * ...'. */
  if (DESCRIBE_L == sparp->sparp_expr->_.req_top.subtype)
    sparp->sparp_expr->_.req_top.retvals = 
      spar_retvals_of_describe (sparp, sparp->sparp_expr->_.req_top.retvals);
  if (NULL != sparp->sparp_env->spare_grab_vars)
    {
      sparp_rewrite_grab (sparp);
      return;
    }
  sparp_rewrite_qm (sparp);
}


void
sparp_rewrite_qm (sparp_t *sparp)
{
  sparp_equiv_t **equivs;
  int equiv_ctr, equiv_count;
  int opt_ctr = 0;
  SPART *root = sparp->sparp_expr;
  sparp_rewrite_basic (sparp);
  sparp->sparp_storage = sparp_find_storage_by_name (sparp->sparp_expr->_.req_top.storage_name);
/* Building qm_list for every triple in the tree. */
  sparp_gp_trav (sparp, sparp->sparp_expr->_.req_top.pattern, NULL,
    sparp_gp_trav_refresh_triple_mappings, NULL,
    NULL, NULL,
    NULL );

again:

  sparp_equiv_audit_all (sparp, 0);
  sparp->sparp_rewrite_dirty = 0;
/* Converting to GP_UNION of every triple such that many quad maps contains triples that matches the mapping pattern */
  sparp_gp_trav (sparp, sparp->sparp_expr->_.req_top.pattern, NULL,
    NULL, sparp_gp_trav_multiqm_to_unions,
    NULL, NULL,
    NULL );
  sparp_equiv_audit_all (sparp, 0);
  sparp_rewrite_basic (sparp);
  sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
/* Converting join with a union into a union of joins with parts of union
  sparp_gp_trav (sparp, sparp->sparp_expr->_.req_top.pattern, NULL,
    sparp_gp_trav_union_of_joins_in, sparp_gp_trav_union_of_joins_out,
    NULL, NULL,
    NULL ); */
  sparp_equiv_audit_all (sparp, 0);
  sparp_rewrite_basic (sparp);
  sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);

  if (sparp->sparp_rewrite_dirty)
    {
      if (opt_ctr++ < 10)
        goto again;
#ifdef DEBUG
      spar_internal_error (sparp, "sparp_" "rewrite_qm(): endless optimization loop");
#endif
    }

  sparp_gp_trav (sparp, sparp->sparp_expr->_.req_top.pattern, NULL,
    NULL, sparp_gp_trav_reuse_tabids,
    NULL, NULL,
    NULL );

/* Final processing: */
  equivs = root->_.req_top.equivs = sparp->sparp_env->spare_equivs;
  equiv_count = root->_.req_top.equiv_count = sparp->sparp_env->spare_equiv_count;
  for (equiv_ctr = equiv_count; equiv_ctr--; /* no step */)
    {
      sparp_equiv_t *eq = equivs[equiv_ctr];
      if (NULL == eq)
        continue;
      if (eq->e_deprecated)
        continue;
      if ((0 == eq->e_gspo_uses) &&
        (0 == BOX_ELEMENTS_0 (eq->e_subvalue_idxs)) &&
	((0 != eq->e_const_reads) || (0 != BOX_ELEMENTS_0 (eq->e_subvalue_idxs))) &&
        !(eq->e_rvr.rvrRestrictions & (SPART_VARR_FIXED | SPART_VARR_GLOBAL)) )
        {
          if (eq->e_rvr.rvrRestrictions & SPART_VARR_EXPORTED)
            spar_error (sparp, "Variable '%.100s' is used in the query result set but not assigned", eq->e_varnames[0]);
          if ((0 != eq->e_const_reads) ||
            (0 != BOX_ELEMENTS_0 (eq->e_receiver_idxs)) )
            spar_error (sparp, "Variable '%.100s' is used in subexpressions of the query but not assigned", eq->e_varnames[0]);
        }
#ifdef DEBUG
      equivs[equiv_ctr]->e_dbg_saved_gp = (SPART **)t_box_num ((ptrlong)(equivs[equiv_ctr]->e_gp));
#endif
      equivs[equiv_ctr]->e_gp = NULL;
    }
}


void
sparp_rewrite_grab (sparp_t *sparp)
{
  sparp_t *sparp_of_seed;	/* This will compile the statement that will collect the first set of graphs */
  sparp_t *sparp_of_iter;	/* This will compile the statement that will called while the set of graphs growth */
  sparp_t *sparp_of_final;	/* This will compile the statement that will produce the final result set */
  sparp_t *sub_sparps[3];
  caddr_t sql_texts[3];
  sparp_env_t *env = sparp->sparp_env;
  SPART **grab_retvals;
  caddr_t retselid;
  ptrlong top_subtype;
  dk_set_t new_vars = NULL;
  spar_sqlgen_t ssg;
  sql_comp_t sc;
  int sub_sparp_ctr;
  retselid = sparp->sparp_expr->_.req_top.retselid;
  top_subtype = sparp->sparp_expr->_.req_top.subtype;
  t_set_push (&(env->spare_selids), retselid);
  DO_SET (caddr_t, grab_name, &(env->spare_grab_vars))
    {
      t_set_push (&new_vars, spar_make_variable (sparp, grab_name));
    }
  END_DO_SET()
  t_set_pop (&(env->spare_selids));
  grab_retvals = (SPART **)t_revlist_to_array (new_vars);
/* Making subqueries */
  sub_sparps[0] = sparp_of_seed = sparp_clone_for_variant (sparp);
  sparp_of_seed->sparp_expr = (SPART *)t_full_box_copy_tree ((caddr_t)(sparp->sparp_expr));
  sparp_of_seed->sparp_expr->_.req_top.subtype = SELECT_L;
  sparp_of_seed->sparp_expr->_.req_top.retvals = grab_retvals;
  sparp_of_seed->sparp_expr->_.req_top.retvalmode_name = t_box_string ("LONG");
  sparp_of_seed->sparp_expr->_.req_top.limit = t_box_num (SPARP_MAXLIMIT);
  sparp_of_seed->sparp_expr->_.req_top.offset = 0;
  sub_sparps[1] = sparp_of_iter = sparp_clone_for_variant (sparp_of_seed);
  sparp_of_iter->sparp_expr = (SPART *)t_full_box_copy_tree ((caddr_t)(sparp_of_seed->sparp_expr));
/*!!! TBD: relax graph conditions in sparp_of_iter */
  sub_sparps[2] = sparp_of_final = sparp_clone_for_variant (sparp);
  sparp_of_final->sparp_expr = (SPART *)t_full_box_copy_tree ((caddr_t)(sparp->sparp_expr));
/*!!! TBD: relax graph conditions in sparp_of_final */
  for (sub_sparp_ctr = 3; sub_sparp_ctr--; /* no step */)
    {
      sparp_t *sub_sparp = sub_sparps [sub_sparp_ctr];
      sparp_rewrite_qm (sub_sparp);
      memset (&ssg, 0, sizeof (spar_sqlgen_t));
      memset (&sc, 0, sizeof (sql_comp_t));
      sc.sc_client = sub_sparp->sparp_sparqre->sparqre_cli;
      ssg.ssg_out = strses_allocate ();
      ssg.ssg_sc = &sc;
      ssg.ssg_sparp = sub_sparp;
      ssg.ssg_tree = sub_sparp->sparp_expr;
      ssg.ssg_sources = ssg.ssg_tree->_.req_top.sources; /*!!!TBD merge with environment */
      ssg_make_sql_query_text (&ssg);
      sql_texts [sub_sparp_ctr] = strses_string (ssg.ssg_out);
      strses_free (ssg.ssg_out);
    }
  sparp->sparp_expr = spartlist (sparp, 11, SPAR_CODEGEN,
    t_box_num ((ptrlong)(ssg_grabber_codegen)),
    t_full_box_copy_tree ((caddr_t)(sparp->sparp_expr->_.req_top.retvals)),
    t_box_dv_short_string ("sql:SPARQL_GRABBER"),
    sql_texts[0], sql_texts[1], sql_texts[2],
    t_box_copy (sparp->sparp_expr->_.req_top.limit), 
    sparp->sparp_env->spare_grab_depth,
    sparp->sparp_env->spare_grab_base_iri,
    sparp->sparp_env->spare_grab_iri_resolver );
}


void
ssg_grabber_codegen (struct spar_sqlgen_s *ssg, struct spar_tree_s *spart, ...)
{
  int argctr = 0;
/* The order of declarations is important: side effect on init */
  SPART **retvals		= (SPART **)(spart->_.codegen.args [argctr++]);
  caddr_t procedure_name	= (caddr_t)(spart->_.codegen.args [argctr++]);
  caddr_t seed_sql_text		= (caddr_t)(spart->_.codegen.args [argctr++]);
  caddr_t iter_sql_text		= (caddr_t)(spart->_.codegen.args [argctr++]);
  caddr_t final_sql_text	= (caddr_t)(spart->_.codegen.args [argctr++]);
  caddr_t limit			= (caddr_t)(spart->_.codegen.args [argctr++]);
  caddr_t depth			= (caddr_t)(spart->_.codegen.args [argctr++]);
  caddr_t base_iri		= (caddr_t)(spart->_.codegen.args [argctr++]);
  caddr_t resolver		= (caddr_t)(spart->_.codegen.args [argctr++]);
  int varctr, varcount = BOX_ELEMENTS (retvals);
  caddr_t call_alias = t_box_sprintf (0x100, "grabber-t%d", ssg->ssg_sparp->sparp_key_gen);
  ssg->ssg_sparp->sparp_key_gen += 1;
  if (NULL == depth)
    depth = (caddr_t)1L;
  if (NULL == base_iri)
    base_iri = t_NEW_DB_NULL;
  if (NULL == resolver)
    resolver = t_box_dv_short_string ("DB.DBA.SPARQL_GRABBER_DEFAULT_RESOLVER");
  ssg_puts ("SELECT ");
  for (varctr = 0; varctr < varcount; varctr++)
    {
      char buf[30];
      char *asname;
      if (varctr)
        ssg_puts (", ");
      ssg_prin_id (ssg, call_alias);
      sprintf (buf, ".rset[%d] as ", varctr);
      ssg_puts (buf);
      asname = spar_alias_name_of_ret_column (retvals [varctr]);
      if (NULL == asname)
        {
          sprintf (buf, "callret-%d", varctr);
          asname = buf;
        }
      ssg_prin_id (ssg, asname);
    }
  ssg_newline (0);
  ssg_puts ("FROM ");
  ssg_prin_function_name (ssg, procedure_name);
  ssg_puts (" (_grabber_seed, _grabber_iter, _grabber_final, _grabber_limit, _grabber_depth, _grabber_base_iri, _grabber_resolver) (rset any)");
  ssg_prin_id (ssg, call_alias);
  ssg_newline (0);
#define PROC_PARAM_EQ_SPART(txt,var) do { \
    ssg_puts (txt); \
    ssg_print_scalar_expn (ssg, (SPART *)(var), SSG_VALMODE_SQLVAL, NULL_ASNAME); \
    } while (0)
  PROC_PARAM_EQ_SPART ("WHERE _grabber_seed = ", seed_sql_text);
  PROC_PARAM_EQ_SPART (" AND _grabber_iter = ", iter_sql_text);
  PROC_PARAM_EQ_SPART (" AND _grabber_final = ", final_sql_text);
  PROC_PARAM_EQ_SPART (" AND _grabber_limit = ", limit);
  PROC_PARAM_EQ_SPART (" AND _grabber_depth = ", depth);
  PROC_PARAM_EQ_SPART (" AND _grabber_base_iri = ", base_iri);
  PROC_PARAM_EQ_SPART (" AND _grabber_resolver = ", resolver);
#undef PROC_PARAM_EQ_SPART
}
