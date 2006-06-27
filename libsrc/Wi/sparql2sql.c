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
#ifdef __cplusplus
extern "C" {
#endif
#include "sparql_p.h"
#ifdef __cplusplus
}
#endif


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
  if (trav_env_this > sparp->sparp_trav_envs + SPARP_MAX_SYNTDEPTH)
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
    case SPAR_QNAME_NS:
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
    case BOP_LIKE:
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
    spar_internal_error (sparp, "sparp_gp_trav() re-entered");
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

/* Removal of redundand unions in GPs and top-level ANDs in FILTERs.
\c trav_env_this is not used.
\c common_env is not used. */

int
sparp_gp_trav_flatten (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env)
{
  int is_dirt = 0;
  if (SPAR_GP != curr->type) /* Not a gp ? -- nothing to do */
    return 0;
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
      eq = sparp_equiv_get (sparp, (SPART *)(trav_env_this[-1]), fld, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE);
      eq->e_restrictions |= fld->_.var.restrictions;
/* This was:
      if (SPART_TRIPLE_GRAPH_IDX == fctr)
	eq->e_const_reads += 1;
      else
	eq->e_pso_uses += 1;
Not this is more stupid: */
      eq->e_gpso_uses += 1;
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
  eq = sparp_equiv_get (sparp, gp, curr, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE);
  eq->e_const_reads += 1;
  eq->e_restrictions |= curr->_.var.restrictions;
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
  curr->_.var.tabid = NULL;
  eq = sparp_equiv_get (sparp, top_gp, curr, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE);
  eq->e_const_reads += 1;
  eq->e_restrictions |= SPART_VARR_EXPORTED;
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
		if (SPARP_EQUIV_MERGE_ROLLBACK != ret)
		  eq_l->e_const_reads -= 2;
	        goto eq_inspected;
	      }
	    else if (SPAR_IS_LIT (r))
	      {
		sparp_equiv_t *eq_l = sparp_equiv_get (sparp, curr, l, 0);
	        ret = sparp_equiv_restrict_by_literal (sparp, eq_l, NULL, r);
		if (SPARP_EQUIV_MERGE_ROLLBACK != ret)
		  eq_l->e_const_reads -= 1;
	        goto eq_inspected;
              }
          }
        else if (SPAR_IS_LIT (l))
          {
            if (SPAR_IS_BLANK_OR_VAR (r))
              {
		sparp_equiv_t *eq_r = sparp_equiv_get (sparp, curr, r, 0);
	        ret = sparp_equiv_restrict_by_literal (sparp, eq_r, NULL, l);
		if (SPARP_EQUIV_MERGE_ROLLBACK != ret)
		  eq_r->e_const_reads -= 1;
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
            arg1_eq->e_restrictions |= SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_NOT_NULL;
            arg1_eq->e_const_reads -= 1;
            return 1;
          case isBLANK_L:
            arg1_eq->e_restrictions |= SPART_VARR_IS_REF | SPART_VARR_IS_BLANK | SPART_VARR_NOT_NULL;
            arg1_eq->e_const_reads -= 1;
            return 1;
          case isLITERAL_L:
            arg1_eq->e_restrictions |= SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL;
            arg1_eq->e_const_reads -= 1;
            return 1;
          case BOUND_L:
            arg1_eq->e_restrictions |= SPART_VARR_NOT_NULL;
            arg1_eq->e_const_reads -= 1;
            return 1;
#ifdef DEBUG
          case STR_L:
          case LANG_L:
          case LANGMATCHES_L:
          case DATATYPE_L:
          case REGEX_L:
            break;
          default: spar_internal_error (sparp, "sparp_filter_to_equiv(): unsupported built-in");
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
      curr->_.gp.filters = (SPART **)t_list_remove_nth ((caddr_t)(curr->_.gp.filters), fctr);
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
          char fake_var_buf[sizeof (SPART) + BOX_AUTO_OVERHEAD];
          SPART *fake_var;
	  BOX_AUTO_TYPED (SPART *, fake_var, fake_var_buf, sizeof (SPART), DV_ARRAY_OF_POINTER);
	  fake_var->type = SPAR_VARIABLE;
	  fake_var->_.var.vname = var_name;
          sparp_equiv_get (sparp, curr, fake_var, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_GET_NAMESAKES);
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
    } END_SPARP_FOREACH_GP_EQUIV
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
    spar_internal_error (sparp, "sparp_gp_add_chain_aliases () has NULL eq for inner_var");
  if (curr_eq->e_gp != trav_stack[0])
    spar_internal_error (sparp, "sparp_gp_add_chain_aliases () has eq for inner_var not equal to trav_stack[0]");
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
    } END_SPARP_FOREACH_GP_EQUIV
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
        (0 != eq->e_gpso_uses) ||
        (0 != BOX_ELEMENTS_INT_0 (eq->e_receiver_idxs)) ||
        (1 < BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs)) ||
        (0 != eq->e_var_count) ||
        (SPART_VARR_EXPORTED & eq->e_restrictions) )
	continue;
      for (sub_ctr = BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs); sub_ctr--; /* no step */)
        {
          sparp_equiv_t *sub_eq = SPARP_EQUIV(sparp, eq->e_subvalue_idxs[sub_ctr]);
          sparp_equiv_disconnect (sparp, eq, sub_eq);
        }
      sparp_equiv_remove (sparp, eq);
    } END_SPARP_REVFOREACH_GP_EQUIV
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
sparp_remove_redundand_connections (sparp_t *sparp)
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
      if (!((SPART_VARR_GLOBAL | SPART_VARR_FIXED) & eq->e_restrictions))
        continue;
      for (sub_ctr = BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs); sub_ctr--; /*no step*/)
        {
          int can_unlink = 0;
          sparp_equiv_t *sub_eq = equivs[eq->e_subvalue_idxs[sub_ctr]];
          if (!((SPART_VARR_GLOBAL | SPART_VARR_FIXED) & sub_eq->e_restrictions))
            continue;
          if (
            (SPART_VARR_GLOBAL & eq->e_restrictions) &&
            (SPART_VARR_GLOBAL & sub_eq->e_restrictions) )
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
  dk_set_t common_vars = NULL;
  DO_BOX_FAST (ptrlong, sub_eq_idx, sub_ctr, eq->e_subvalue_idxs)
    {
      sparp_equiv_t *sub_eq = equivs[sub_eq_idx];
      SPART *sub_gp = sub_eq->e_gp;
      if (0 == sub_ctr)
        {
          eq->e_restrictions = sub_eq->e_restrictions;
          eq->e_fixedvalue = sub_eq->e_fixedvalue;
          eq->e_datatype = sub_eq->e_datatype;
          DO_BOX_FAST (caddr_t, varname, varname_ctr, sub_eq->e_varnames)
            {
              if (!SPART_VARNAME_IS_GLOB (varname))
                continue;
              t_set_push (&common_vars, varname);
            }
          END_DO_BOX_FAST;
        }
      else
        {
          dk_set_t new_common_vars = NULL;
          eq->e_restrictions &= (sub_eq->e_restrictions | SPART_VARR_CONFLICT | SPART_VARR_EXPORTED | SPART_VARR_GLOBAL) ;
          eq->e_restrictions &= ~SPART_VARR_TYPED; /*!!!TBD: make a separate check for equal types*/
          DO_BOX_FAST (caddr_t, varname, varname_ctr, sub_eq->e_varnames)
            {
              if (!SPART_VARNAME_IS_GLOB (varname))
                continue;
              if (0 > dk_set_position_of_string (common_vars, varname))
                continue;
              t_set_push (&new_common_vars, varname);
            }
          END_DO_BOX_FAST;
          common_vars = new_common_vars;
        }
      if (OPTIONAL_L == sub_gp->_.gp.subtype)
        eq->e_restrictions &= ~SPART_VARR_NOT_NULL;
      if ((0 < sub_ctr) &&
        (SPART_VARR_FIXED & eq->e_restrictions) &&
        !sparp_equivs_have_same_fixedvalue (sparp, eq, sub_eq) )
        eq->e_restrictions &= ~SPART_VARR_FIXED;
    }
  END_DO_BOX_FAST;
  if (NULL == common_vars)
    eq->e_restrictions &= ~SPART_VARR_GLOBAL;
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
  if (BOX_ELEMENTS (eq->e_subvalue_idxs) < BOX_ELEMENTS (eq->e_gp->_.gp.members))
    eq->e_restrictions &= ~SPART_VARR_NOT_NULL;
}

void
sparp_restr_of_join_eq_from_connected_subvalues (sparp_t *sparp, sparp_equiv_t *eq)
{
  sparp_equiv_t **equivs = sparp->sparp_env->spare_equivs;
  int sub_ctr;
#if 0
  int count_of_opts = 0;
  ptrlong intersect_of_opts = 0;
  caddr_t datatype_of_opts = NULL;
  SPART * fixedvalue_of_opts = NULL;
#endif
  DO_BOX_FAST (ptrlong, sub_eq_idx, sub_ctr, eq->e_subvalue_idxs)
    {
      sparp_equiv_t *sub_eq = equivs[sub_eq_idx];
      SPART *sub_gp = sub_eq->e_gp;
      if (OPTIONAL_L != sub_gp->_.gp.subtype)
        {
          if ((SPART_VARR_FIXED & sub_eq->e_restrictions) &&
	    !(SPART_VARR_FIXED & eq->e_restrictions) )
            eq->e_fixedvalue = (SPART *)t_box_copy_tree ((caddr_t)(sub_eq->e_fixedvalue));
          if ((SPART_VARR_TYPED & sub_eq->e_restrictions) &&
	    !(SPART_VARR_TYPED & eq->e_restrictions) )
            eq->e_datatype = t_box_copy_tree (sub_eq->e_datatype);
          eq->e_restrictions |= sub_eq->e_restrictions;
        }
#if 0
      else
        {
          if (0 == count_of_opts)
            {
              intersect_of_opts = sub_eq->e_restrictions;
              datatype_of_opts = sub_eq->e_datatype;
              fixedvalue_of_opts = sub_eq->e_fixedvalue;
            }
          else
            {
	      if ((SPART_VARR_TYPED & intersect_of_opts & sub_eq->e_restrictions) &&
                !strcmp (
                  ((NULL != datatype_of_opts) ? datatype_of_opts : ""),
                  ((NULL != sub_eq->e_datatype) ? sub_eq->e_datatype : "") ) )
	        intersect_of_opts &= ~SPART_VARR_TYPED;
	      if ((SPART_VARR_FIXED & intersect_of_opts & sub_eq->e_restrictions) &&
                !sparp_fixedvalues_equal (sparp, fixedvalue_of_opts, sub_eq->e_fixedvalue) )
	        intersect_of_opts &= ~SPART_VARR_FIXED;
              intersect_of_opts &= sub_eq->e_restrictions;
            }
          count_of_opts++;
        }
#endif
    }
  END_DO_BOX_FAST;
#if 0
  if (0 < count_of_opts)
    {
      eq->e_restrictions |= intersect_of_opts;
      if ((SPART_VARR_TYPED & intersect_of_opts) && (NULL == eq->e_datatype))
        eq->e_datatype = datatype_of_opts;
      if ((SPART_VARR_FIXED & intersect_of_opts) && (NULL == eq->e_fixedvalue))
        eq->e_fixedvalue = fixedvalue_of_opts;
    }
#endif
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
    } END_SPARP_FOREACH_GP_EQUIV
  return 0;
}


void
sparp_restr_of_eq_from_connected_receiver (sparp_t *sparp, sparp_equiv_t *sub_eq, sparp_equiv_t *eq)
{
  SPART *sub_gp = sub_eq->e_gp;
  ptrlong mask = (
    SPART_VARR_CONFLICT |
    SPART_VARR_IS_BLANK |
    SPART_VARR_IS_IRI |
    SPART_VARR_IS_LIT |
    SPART_VARR_IS_REF |
    SPART_VARR_TYPED |
    SPART_VARR_FIXED );
  if ((SPART_VARR_FIXED & eq->e_restrictions) &&
    !(SPART_VARR_FIXED & sub_eq->e_restrictions) )
    sub_eq->e_fixedvalue = (SPART *)t_box_copy_tree ((caddr_t)(eq->e_fixedvalue));
  if ((SPART_VARR_TYPED & eq->e_restrictions) &&
    !(SPART_VARR_TYPED & sub_eq->e_restrictions) )
    sub_eq->e_datatype = t_box_copy_tree (eq->e_datatype);
  if (OPTIONAL_L != sub_gp->_.gp.subtype)
    mask = mask | SPART_VARR_NOT_NULL;
  sub_eq->e_restrictions |= (eq->e_restrictions & mask);
/*!!! TBD better support for other bits*/
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
           sparp_restr_of_eq_from_connected_receiver (sparp, sub_eq, eq);
       }
      END_DO_BOX_FAST;
    } END_SPARP_FOREACH_GP_EQUIV
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
	  var->_.var.restrictions |= eq->e_restrictions;
	  var->_.var.equiv_idx = eq->e_own_idx;
	}
    } END_SPARP_FOREACH_GP_EQUIV
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
        (int)(eq->e_gpso_uses), (int)(eq->e_const_reads) ));
      varname_count = BOX_ELEMENTS (eq->e_varnames);
      for (varname_ctr = 0; varname_ctr < varname_count; varname_ctr++)
        {
          spar_dbg_printf ((" %s", eq->e_varnames[varname_ctr]));
        }
      spar_dbg_printf ((")"));
    } END_SPARP_FOREACH_GP_EQUIV
  spar_dbg_printf (("\n"));
}

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
      sparp->sparp_env->spare_equivs = eqs = new_eqs;
    }
  res->e_own_idx = eqcount;
  eqs[eqcount++] = res;
  sparp->sparp_env->spare_equiv_count = eqcount;
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
  switch (SPART_TYPE(needle_var))
    {
    case SPAR_VARIABLE: break;
    case SPAR_BLANK_NODE_LABEL: break;
    case SPAR_LIT:
      if (
        (flags & SPARP_EQUIV_GET_NAMESAKES) &&
        ((DV_STRING == DV_TYPE_OF (needle_var)) || (DV_UNAME == DV_TYPE_OF (needle_var))) )
        break;
    default: spar_internal_error (sparp, "sparp_equiv_get() with non-variable SPART *needle_var"); break;
    }
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
      curr_eq->e_var_count = 1;
    }
  else
    {
      curr_eq->e_vars = (SPART **)t_list (1, NULL);
      curr_eq->e_var_count = 0;
    }
  curr_eq->e_gp = haystack_gp;
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
  curr_vars[varcount++] = needle_var;
  curr_eq->e_var_count = varcount;
#ifdef DEBUG
  sparp_dbg_gp_print (sparp, haystack_gp);
#endif
  return curr_eq;

retnull:
  if (SPARP_EQUIV_GET_ASSERT & flags)
    spar_internal_error (sparp, "sparp_equiv_get(): attempt of returning NULL when SPARP_EQUIV_GET_ASSERT & flags");
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
        spar_internal_error (sparp, "sparp_equiv_connect(): unidirectional link (1) ?");
#endif
      return 1;
    }
#ifdef DEBUG
  if (i_listed_in_o)
    spar_internal_error (sparp, "sparp_equiv_connect(): unidirectional link (2) ?");
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
        spar_internal_error (sparp, "sparp_equiv_disconnect(): unidirectional link (1) ?");
#endif
      return 0;
    }
#ifdef DEBUG
  if (-1 == i_listed_in_o)
    spar_internal_error (sparp, "sparp_equiv_disconnect(): unidirectional link (2) ?");
#endif
  outer->e_subvalue_idxs = (ptrlong *)t_list_remove_nth ((caddr_t)(outer->e_subvalue_idxs), i_listed_in_o);
  inner->e_receiver_idxs = (ptrlong *)t_list_remove_nth ((caddr_t)(inner->e_receiver_idxs), o_listed_in_i);
  return 1;
}

int sparp_equiv_restrict_by_literal (sparp_t *sparp, sparp_equiv_t *pri, caddr_t datatype, SPART *value)
{
/* TBD !!! something smart is needed */
  if (NULL == pri->e_datatype)
    {
      pri->e_datatype = datatype;
    }
  else
    {
      if (NULL != datatype)
        return SPARP_EQUIV_MERGE_ROLLBACK;
    }
  if (NULL == pri->e_fixedvalue)
    pri->e_fixedvalue = value;
  else
    {
      if (NULL != value)
        return SPARP_EQUIV_MERGE_ROLLBACK;
    }
  if (NULL != pri->e_datatype)
    pri->e_restrictions |= SPART_VARR_TYPED;
  if (NULL != pri->e_fixedvalue)
    pri->e_restrictions |= SPART_VARR_FIXED;
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
    (0 != eq->e_gpso_uses) ||
    (0 != eq->e_var_count) ||
    (0 != BOX_ELEMENTS_INT_0 (eq->e_receiver_idxs)) ||
    (0 != BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs)) ||
    (SPART_VARR_EXPORTED & eq->e_restrictions) )
    spar_internal_error (sparp, "sparp_equiv_remove (): can't remove equiv that is still in use");
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
  spar_internal_error (sparp, "sparp_equiv_remove (): failed to remove eq from its gp");

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
  sec_gp = sec->e_gp;
#ifdef DEBUG
  if (pri->e_gp != sec_gp)
    spar_internal_error (sparp, "sparp_equiv_merge () can not merge equivs from two different gps");
  for (ctr1 = BOX_ELEMENTS_INT_0 (sec->e_varnames); ctr1--; /* no step*/)
    {
      for (ctr2 = BOX_ELEMENTS_INT_0 (pri->e_varnames); ctr2--; /* no step*/)
        {
          if (!strcmp (sec->e_varnames[ctr1], pri->e_varnames[ctr2]))
	    spar_internal_error (sparp, "sparp_equiv_merge (): same variable name in two different equivs of same gp");
	}
    }
  for (ctr1 = sec->e_var_count; ctr1--; /* no step*/)
    {
      for (ctr2 = pri->e_var_count; ctr2--; /* no step*/)
        {
          if (sec->e_vars[ctr1] == pri->e_vars[ctr2])
	    spar_internal_error (sparp, "sparp_equiv_merge (): same variable in two different equivs of same gp");
	}
    }
#endif
  if ((pri->e_restrictions & SPART_VARR_EXPORTED) && (sec->e_restrictions & SPART_VARR_EXPORTED))
    return SPARP_EQUIV_MERGE_ROLLBACK;
  ret = sparp_equiv_restrict_by_literal (sparp, pri, sec->e_datatype, sec->e_fixedvalue);
  if (SPARP_EQUIV_MERGE_ROLLBACK == ret)
    return ret;
  pri->e_varnames = t_list_concat ((caddr_t)(pri->e_varnames), (caddr_t)(sec->e_varnames));
  sec->e_varnames = t_list (0);
  if (0 < sec->e_var_count)
    {
      SPART **new_vars = (SPART **) t_alloc_box ((pri->e_var_count + sec->e_var_count) * sizeof (SPART *), DV_ARRAY_OF_POINTER);
      memcpy (new_vars, pri->e_vars, pri->e_var_count * sizeof (SPART *));
      memcpy (new_vars + pri->e_var_count, sec->e_vars, sec->e_var_count * sizeof (SPART *));
      pri->e_vars = new_vars;
      sec->e_vars = (SPART **)t_list (1, NULL);
      pri->e_var_count += sec->e_var_count;
      sec->e_var_count = 0;
    }
  pri->e_restrictions |= sec->e_restrictions;
  pri->e_uses += sec->e_uses;
  sec->e_uses = 0;
  pri->e_gpso_uses += sec->e_gpso_uses;
  sec->e_gpso_uses = 0;
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
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (first))
    {
      first_val = first->_.lit.val;
      first_language = first->_.lit.language;
    }
  else
    first_val = (caddr_t)(first);
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (second))
    {
      second_val = second->_.lit.val;
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
  if (!(SPART_VARR_FIXED & first_eq->e_restrictions))
    return 0;
  if (!(SPART_VARR_FIXED & second_eq->e_restrictions))
    return 0;
  if ( strcmp (
    ((NULL == first_eq->e_datatype) ? "" : first_eq->e_datatype),
    ((NULL == second_eq->e_datatype) ? "" : second_eq->e_datatype) ) )
    return 0;
  return sparp_fixedvalues_equal (sparp, first_eq->e_fixedvalue, second_eq->e_fixedvalue);
}

/* Main rewriting functions */

void
sparp_rewrite_basic (sparp_t *sparp)
{
  sparp_equiv_t **equivs;
  int equiv_ctr, equiv_count;
  SPART *root = sparp->sparp_expr;
  sparp_expand_top_retvals (sparp);
/* Unlike spar_retvals_of_construct() that can be called during parsing,
spar_retvals_of_describe() should wait for obtaining all variables and then
sparp_expand_top_retvals () to process 'DESCRIBE * ...'. */
  if (DESCRIBE_L == sparp->sparp_expr->_.req_top.subtype)
    sparp->sparp_expr->_.req_top.retvals = 
      spar_retvals_of_describe (sparp, sparp->sparp_expr->_.req_top.retvals);
  sparp_flatten (sparp);
  sparp_count_usages (sparp);
  sparp_restrict_by_simple_filters (sparp);
  sparp_make_common_eqs (sparp);
  sparp_make_aliases (sparp);
  sparp_eq_restr_from_connected (sparp);
  sparp_eq_restr_to_vars (sparp);
  sparp_remove_redundand_connections (sparp);
  equivs = root->_.req_top.equivs = sparp->sparp_env->spare_equivs;
  equiv_count = root->_.req_top.equiv_count = sparp->sparp_env->spare_equiv_count;
  for (equiv_ctr = equiv_count; equiv_ctr--; /* no step */)
    {
      sparp_equiv_t *eq = equivs[equiv_ctr];
      if (NULL == eq)
        continue;
      if ((0 == eq->e_gpso_uses) &&
        (0 == BOX_ELEMENTS_0 (eq->e_subvalue_idxs)) &&
        !(eq->e_restrictions & (SPART_VARR_FIXED | SPART_VARR_GLOBAL)) )
      spar_error (sparp, "Variable '%s' is used but never assigned", eq->e_varnames[0]);
      equivs[equiv_ctr]->e_gp = NULL;
    }
}
