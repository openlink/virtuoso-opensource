/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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
#include "sqlbif.h"
#include "sqlcmps.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "sparql_p.h"
#include "xmlparser.h"
#include "xmlparser_impl.h"
#ifdef __cplusplus
}
#endif
#include "xml_ecm.h"
#include "xqf.h"
#include "rdf_core.h"

/* PART 1. EXPRESSION TERM REWRITING */

#define SPART_VARNAME_IS_NICE_RETVAL(name,known) ( \
  (NULL != (name))						/* no name --- no return column */ \
  && !SPART_VARNAME_IS_GLOB((name))				/* Query run-time env or external query param? -- not in result-set */ \
  && !SPART_VARNAME_IS_BNODE((name))				/* An automatically generated name in a transitive triple patterns or a property paths? -- not in result-set */ \
  && (0 > dk_set_position_of_string ((known), (name))) )	/* Known already? --- not in the result-set for a second time */


/* Composing list of retvals instead of '*'.
\c trav_env_this is not used.
\c common_env points to dk_set_t of collected distinct variable names. */
int
sparp_gp_trav_list_expn_retval_names (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  caddr_t varname;
  switch (curr->type)
    {
    case SPAR_VARIABLE: varname = curr->_.var.vname; break;
    case SPAR_ALIAS: varname = curr->_.alias.aname; break;
    default: return 0;
    }
  if (SPART_VARNAME_IS_NICE_RETVAL (varname, ((dk_set_t *)(common_env))[0]))
    t_set_push_new_string ((dk_set_t *)(common_env), varname);
  return SPAR_GPT_NODOWN;
}

int
sparp_gp_trav_list_subquery_retval_names (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  int ctr;
  SPART **options = curr->_.gp.options;
  if (SPAR_GP != curr->type)
    return 0;
  if (SELECT_L == curr->_.gp.subtype)
    {
      DO_BOX_FAST (SPART *, retval, ctr, curr->_.gp.subquery->_.req_top.retvals)
        {
          caddr_t name;
          switch (SPART_TYPE (retval))
            {
              case SPAR_VARIABLE: name = retval->_.var.vname; break;
              case SPAR_ALIAS: name = retval->_.alias.aname; break;
              default: name = NULL;
            }
          if (SPART_VARNAME_IS_NICE_RETVAL (name, ((dk_set_t *)(common_env))[0]))
            t_set_push_new_string ((dk_set_t *)(common_env), name);
        }
      END_DO_BOX_FAST;
      for (ctr = BOX_ELEMENTS_0 (options); 1 < ctr; ctr -= 2)
        {
          ptrlong key = ((ptrlong)(options[ctr-2]));
          SPART *val = options[ctr-1];
          caddr_t name = NULL;
          switch (key)
            {
            case OFFBAND_L: case SCORE_L: name = val->_.var.vname; break;
            case T_STEP_L: name = val->_.alias.aname; break;
            }
          if (SPART_VARNAME_IS_NICE_RETVAL (name, ((dk_set_t *)(common_env))[0]))
            t_set_push_new_string ((dk_set_t *)(common_env), name);
        }
    }
  if (VALUES_L == curr->_.gp.subtype)
    {
      DO_BOX_FAST (SPART *, retval, ctr, curr->_.gp.subquery->_.binv.vars)
        {
          caddr_t name = retval->_.var.vname;
          if (SPART_VARNAME_IS_NICE_RETVAL (name, ((dk_set_t *)(common_env))[0]))
            t_set_push_new_string ((dk_set_t *)(common_env), name);
        }
      END_DO_BOX_FAST;
    }
  return 0;
}

typedef struct list_nonaggregate_retvals_s {
  dk_set_t names;
  ptrlong agg_found;
  } list_nonaggregate_retvals_t;

int
sparp_gp_trav_list_nonaggregate_retvals (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  switch (curr->type)
    {
    case SPAR_VARIABLE:
      {
        caddr_t varname;
        varname = curr->_.var.vname;
        if (SPART_VARNAME_IS_NICE_RETVAL (varname, ((dk_set_t *)(common_env))[0]))
        if (SPART_VARNAME_IS_GLOB(varname)) /* Query run-time env or external query param ? -- not in result-set */
          return SPAR_GPT_NODOWN;
        DO_SET (caddr_t, listed, (dk_set_t *)(common_env))
          {
            if (!strcmp (listed, varname))
              return SPAR_GPT_NODOWN;
          }
        END_DO_SET()
        t_set_push (&(((list_nonaggregate_retvals_t *)(common_env))->names), varname);
        return SPAR_GPT_NODOWN;
      }
    case SPAR_FUNCALL:
      if (curr->_.funcall.agg_mode)
        {
          ((list_nonaggregate_retvals_t *)(common_env))->agg_found = 1;
          return SPAR_GPT_NODOWN;
        }
      break;
    case SPAR_GP:
      return SPAR_GPT_NODOWN;
    }
  return SPAR_GPT_ENV_PUSH; /* To preserve sts_this->sts_curr_array and sts_this->sts_ofs_of_curr_in_array for wrapper of vars into fake MAX() */
}

static void
sparp_preprocess_obys (sparp_t *sparp, SPART *root)
{
  int oby_ctr;
  SPART **retvals = root->_.req_top.retvals;
  int rv_count = (IS_BOX_POINTER (retvals) ? BOX_ELEMENTS (retvals) : -1);
  DO_BOX_FAST (SPART *, oby, oby_ctr, root->_.req_top.order)
    {
      SPART *oby_expn = oby->_.oby.expn;
      if (IS_BOX_POINTER (oby_expn))
        {
          if (SPAR_VARIABLE == SPART_TYPE (oby_expn))
            {
              int rv_ctr;
              caddr_t vname = oby_expn->_.var.vname;
              for (rv_ctr = 0; rv_ctr < rv_count; rv_ctr++)
                {
                  SPART *rv = root->_.req_top.retvals[rv_ctr];
                  if ((SPAR_ALIAS == SPART_TYPE (rv)) && !strcmp (vname, rv->_.alias.aname))
                    {
                      oby->_.oby.expn = (SPART *)((ptrlong)(rv_ctr+1));
                      break;
                    }
                }
            }
        }
      else
        {
          long i = (ptrlong)(oby_expn);
          if (0 >= rv_count)
            spar_error (sparp, "SELECT query should contain explicit list of returned columns if ORDER BY refers to indexes of that columns");
          if ((0 >= i) || (rv_count < i))
            spar_error (sparp, "ORDER BY refers to resulting column index %ld, should be in range 1 to %d", i, rv_count );
        }
    }
  END_DO_BOX_FAST;
}

void
sparp_expand_top_retvals (sparp_t *sparp, SPART *query, int safely_copy_all_vars, dk_set_t binds_revlist)
{
  sparp_env_t *env = sparp->sparp_env;
  list_nonaggregate_retvals_t lnar;
  dk_set_t new_vars = NULL;
  SPART **retvals = query->_.req_top.retvals;
  sparp_preprocess_obys (sparp, query);
  lnar.agg_found = 0;
  lnar.names = NULL;
  if (IS_BOX_POINTER (retvals))
    {
#if 0
      if (safely_copy_all_vars)
        query->_.req_top.orig_retvals = sparp_treelist_full_copy (sparp, retvals, query->_.req_top.pattern); /* No cloning equivs here but no equivs at this moment at all */
      else
        query->_.req_top.orig_retvals = (SPART **) t_box_copy ((box_t) retvals);
#endif
      if (0 == sparp->sparp_query_uses_aggregates)
        return;
      sparp_gp_localtrav_treelist (sparp, retvals,
        NULL, &lnar,
        NULL, NULL,
        sparp_gp_trav_list_nonaggregate_retvals, NULL, sparp_gp_trav_list_nonaggregate_retvals,
        NULL );
      if (NULL != query->_.req_top.having)
        {
          sparp_trav_state_t stss [SPARP_MAX_SYNTDEPTH+2];
          memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
          stss[0].sts_env = NULL;
          stss[1].sts_curr_array = NULL;
          stss[1].sts_ofs_of_curr_in_array = 0;
          sparp_gp_trav_int (sparp, query->_.req_top.having, stss+1, &lnar,
          NULL, NULL,
          sparp_gp_trav_list_nonaggregate_retvals, NULL, sparp_gp_trav_list_nonaggregate_retvals,
          NULL );
        }
      sparp_gp_localtrav_treelist (sparp, query->_.req_top.order,
        NULL, &lnar,
        NULL, NULL,
        sparp_gp_trav_list_nonaggregate_retvals, NULL, sparp_gp_trav_list_nonaggregate_retvals,
        NULL );
      if (0 == lnar.agg_found)
        return;
      if (NULL != query->_.req_top.groupings)
        {
          dk_set_t names_in_groupings = NULL;
          sparp_gp_localtrav_treelist (sparp, query->_.req_top.groupings,
            NULL, &names_in_groupings,
            sparp_gp_trav_list_subquery_retval_names, NULL,
            sparp_gp_trav_list_expn_retval_names, NULL, NULL,
            NULL );
          while (NULL != lnar.names)
            {
              caddr_t varname = (caddr_t)t_set_pop (&(lnar.names));
              if (0 > dk_set_position_of_string (names_in_groupings, varname))
                spar_error (sparp, "Variable ?%.200s is used in the result set outside aggregate and not mentioned in GROUP BY clause", varname);
            }
          return;
        }
      while (NULL != lnar.names)
        {
          caddr_t varname = (caddr_t)t_set_pop (&(lnar.names));
          SPART *var = spar_make_variable (sparp, varname);
          t_set_push (&new_vars, var);
        }
      query->_.req_top.groupings = (SPART **)t_revlist_to_array_or_null (new_vars);
      return;
    }
  {
    sparp_trav_state_t stss [SPARP_MAX_SYNTDEPTH+2];
    memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
    sparp_gp_trav_int (sparp, query->_.req_top.pattern, stss+1, &(lnar.names),
      sparp_gp_trav_list_subquery_retval_names, NULL,
      sparp_gp_trav_list_expn_retval_names, NULL, NULL,
      NULL );
  }
  if (((SPART **)_STAR == retvals) && (NULL == lnar.names) && sparp->sparp_sg->sg_signal_void_variables)
    spar_error (sparp, "The list of return values contains '*' but the pattern does not contain variables");
  while (NULL != binds_revlist)
    {
      t_set_push (&new_vars, sparp_tree_full_copy (sparp, (SPART *)(t_set_pop (&binds_revlist)), query->_.req_top.pattern));
    }
  while (NULL != lnar.names)
    {
      caddr_t varname = (caddr_t)t_set_pop (&(lnar.names));
      SPART *var = spar_make_variable (sparp, varname);
      t_set_push (&new_vars, var);
    }

  if ((SPART **)_STAR == retvals)
    {
      if (NULL == new_vars)
        {
          t_set_push (&new_vars, spartlist (sparp, 6, SPAR_ALIAS,
            t_box_num (1), t_box_dv_short_string ("_star_fake"), SSG_VALMODE_AUTO, (ptrlong)0, (ptrlong)0 ) );
        }
      query->_.req_top.retvals = retvals = (SPART **)t_list_to_array (new_vars);
#if 0
      if (safely_copy_all_vars)
        query->_.req_top.orig_retvals = sparp_treelist_full_copy (sparp, retvals, query->_.req_top.pattern); /* No cloning equivs here but no equivs at this moment at all */
      else
        query->_.req_top.orig_retvals = (SPART **) t_box_copy ((box_t) retvals);
#endif
    }
  else
    spar_internal_error (sparp, "sparp_" "expand_top_retvals () failed to process special result-set");
}

int
sparp_gp_trav_wrap_vars_in_max (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  caddr_t varname;
  ssg_valmode_t native;
  if ((SPAR_FUNCALL == curr->type) && curr->_.funcall.agg_mode)
    return SPAR_GPT_NODOWN;
  if ((SPAR_ALIAS == curr->type) && !memcmp (curr->_.alias.aname, "ctor-", 5))
    return SPAR_GPT_NODOWN;
  if (SPAR_VARIABLE != curr->type) /* Not a variable ? -- nothing to do */
    return SPAR_GPT_ENV_PUSH; /* To preserve sts_this->sts_curr_array and sts_this->sts_ofs_of_curr_in_array for wrapper of vars into fake MAX() */
  varname = curr->_.var.vname;
  if (SPART_VARNAME_IS_GLOB(varname)) /* Query run-time env or external query param ? -- not in result-set */
    return SPAR_GPT_NODOWN;
  native = sparp_expn_native_valmode (sparp, curr);
  if (IS_BOX_POINTER (native) && native->qmfIsBijection)
    return SPAR_GPT_NODOWN;
  if (curr->_.var.rvr.rvrRestrictions & SPART_VARR_FIXED)
    return SPAR_GPT_NODOWN;
  sts_this->sts_curr_array[sts_this->sts_ofs_of_curr_in_array] =
    spartlist (sparp, 6, SPAR_ALIAS,
      spar_make_funcall (sparp, 1, t_box_dv_uname_string ("SPECIAL::bif:_LONG_MAX"), (SPART **)t_list (1, curr)),
      varname, SSG_VALMODE_AUTO, (ptrlong)0, (ptrlong)0 );
  return SPAR_GPT_NODOWN;
}

void
sparp_wpar_retvars_in_max (sparp_t *sparp, SPART *query)
{
  SPART **retvals = query->_.req_top.retvals;
  const char *formatter, *agg_formatter, *agg_meta;
  caddr_t retvalmode_name, formatmode_name;
  if ((0 == sparp->sparp_query_uses_aggregates) || (0 != BOX_ELEMENTS_0 (query->_.req_top.groupings)))
    return;
  retvalmode_name = query->_.req_top.retvalmode_name;
  formatmode_name = query->_.req_top.formatmode_name;
  ssg_find_formatter_by_name_and_subtype (formatmode_name, query->_.req_top.subtype, &formatter, &agg_formatter, &agg_meta);
  if (((SELECT_L == query->_.req_top.subtype) ||
    (DISTINCT_L == query->_.req_top.subtype) ) &&
    (NULL == formatter) && (NULL == agg_formatter) )
    {
      ssg_valmode_t retvalmode;
      if (NULL == retvalmode_name)
        return;
      retvalmode = ssg_find_valmode_by_name (retvalmode_name);
      if ((SSG_VALMODE_SQLVAL == retvalmode) || (SSG_VALMODE_AUTO == retvalmode))
        return;
    }
  sparp_gp_localtrav_treelist (sparp, retvals,
    NULL, NULL,
    NULL, NULL,
    sparp_gp_trav_wrap_vars_in_max, NULL, NULL,
    NULL );
}

int
sparp_gp_trav_preopt_in_gp (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      if (SELECT_L == curr->_.gp.subtype)
        {
          sparp_gp_trav_suspend (sparp);
          sparp_rewrite_retvals (sparp, curr->_.gp.subquery, 1);
          sparp_gp_trav_resume (sparp);
        }
      return SPAR_GPT_ENV_PUSH;
    }
  return 0;
}

int
sparp_gp_trav_preopt_expn_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_gp_trav_suspend (sparp);
  sparp_rewrite_retvals (sparp, curr->_.gp.subquery, 1);
  sparp_gp_trav_resume (sparp);
  return 0;
}

SPART *
sparp_find_bind_in_dk_set_by_alias (dk_set_t binds, caddr_t aname)
{
  DO_SET (SPART *, b, &binds)
    {
      if (b->_.alias.aname == aname)
        return b;
    }
  END_DO_SET()
  return NULL;
}

typedef struct sparp_expand_binds_env_s
{
  dk_set_t binds;
  SPART *parent_gp;
} sparp_expand_binds_env_t;

int
sparp_gp_trav_expand_binds_gp_in (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_expand_binds_env_t *e = (sparp_expand_binds_env_t *)common_env;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      if (SELECT_L == curr->_.gp.subtype)
        {
          sparp_gp_trav_suspend (sparp);
          sparp_expand_binds_like_macro (sparp, &(curr->_.gp.subquery), e->binds, curr->_.gp.subquery->_.req_top.pattern);
          sparp_gp_trav_resume (sparp);
        }
    }
  return SPAR_GPT_ENV_PUSH;
}

int
sparp_gp_trav_expand_binds_expn_in (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_expand_binds_env_t *e = (sparp_expand_binds_env_t *)common_env;
  switch (SPART_TYPE (curr))
    {
    case SPAR_VARIABLE:
      {
        SPART *prev_bind = sparp_find_bind_in_dk_set_by_alias (e->binds, curr->_.var.vname);
        if (NULL != prev_bind)
          {
            SPART *gp = sts_this->sts_ancestor_gp;
            if (NULL == gp)
              gp = e->parent_gp;
            sts_this->sts_curr_array[sts_this->sts_ofs_of_curr_in_array] = sparp_tree_full_copy (sparp, prev_bind->_.alias.arg, gp);
          }
        return 0;
      }
    case SPAR_ALIAS:
      spar_error (sparp, "Aliases of form (expression AS ?name) should not be nested into other expressions");
    }
  return SPAR_GPT_ENV_PUSH;
}

int
sparp_gp_trav_expand_binds_expn_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_expand_binds_env_t *e = (sparp_expand_binds_env_t *)common_env;
  sparp_gp_trav_suspend (sparp);
  sparp_expand_binds_like_macro (sparp, &(curr->_.gp.subquery), e->binds, curr->_.gp.subquery->_.req_top.pattern);
  sparp_gp_trav_resume (sparp);
  return 0;
}

void
sparp_expand_binds_like_macro (sparp_t *sparp, SPART **expr_ptr, dk_set_t binds, SPART *parent_gp)
{
  switch (SPART_TYPE (expr_ptr[0]))
    {
    case SPAR_REQ_TOP:
      {
        int ctr, count;
        sparp_expand_binds_like_macro (sparp, &(expr_ptr[0]->_.req_top.pattern), binds, parent_gp);
        count = BOX_ELEMENTS_0 (expr_ptr[0]->_.req_top.groupings);
        for (ctr = 0; ctr < count; ctr++)
          sparp_expand_binds_like_macro (sparp, expr_ptr[0]->_.req_top.groupings + ctr, binds, parent_gp);
        if (NULL != expr_ptr[0]->_.req_top.having)
          sparp_expand_binds_like_macro (sparp, &(expr_ptr[0]->_.req_top.having), binds, parent_gp);
        count = BOX_ELEMENTS (expr_ptr[0]->_.req_top.retvals);
        for (ctr = 0; ctr < count; ctr++)
          sparp_expand_binds_like_macro (sparp, expr_ptr[0]->_.req_top.retvals + ctr, binds, parent_gp);
        DO_BOX_FAST (SPART *, oby, ctr, expr_ptr[0]->_.req_top.order)
          {
            sparp_expand_binds_like_macro (sparp, &(oby->_.oby.expn), binds, parent_gp);
          }
        END_DO_BOX_FAST;
        return;
      }
    case SPAR_VARIABLE:
      {
        caddr_t vname = expr_ptr[0]->_.var.vname;
        SPART *prev_bind = sparp_find_bind_in_dk_set_by_alias (binds, vname);
        if (NULL == prev_bind)
          return;
        expr_ptr[0] = spartlist (sparp, 6, SPAR_ALIAS, sparp_tree_full_copy (sparp, prev_bind->_.alias.arg, parent_gp), vname, SSG_VALMODE_AUTO, (ptrlong)0, (ptrlong)1);
        return;
      }
    case SPAR_GP:
      {
        sparp_expand_binds_env_t e;
        e.binds = binds;
        e.parent_gp = parent_gp;
        sparp_gp_trav (sparp, NULL /*unused*/, expr_ptr[0], &e,
          sparp_gp_trav_expand_binds_gp_in, NULL,
          sparp_gp_trav_expand_binds_expn_in, NULL, sparp_gp_trav_expand_binds_expn_subq,
          NULL );
        return;
      }
    case SPAR_ALIAS:
      {
        SPART *prev_bind = sparp_find_bind_in_dk_set_by_alias (binds, expr_ptr[0]->_.alias.aname);
        if (NULL != prev_bind)
          spar_error (sparp, "Alias ?%.200s is defined twice", expr_ptr[0]->_.alias.aname);
        expr_ptr = &(expr_ptr[0]->_.alias.arg);
        /* no break */
      }
    default:
      {
        sparp_expand_binds_env_t e;
        char tmp_oby_buf[sizeof (SPART) + BOX_AUTO_OVERHEAD];
        caddr_t tmp_oby;
        BOX_AUTO (tmp_oby, tmp_oby_buf, sizeof (SPART), DV_ARRAY_OF_POINTER);
        /*memset (tmp_oby, 0, sizeof (SPART));*/
        ((SPART *)tmp_oby)->type = ORDER_L;
        ((SPART *)tmp_oby)->_.oby.expn = expr_ptr[0];
        e.binds = binds;
        e.parent_gp = parent_gp;
        sparp_gp_trav (sparp, NULL /*unused*/, (SPART *)tmp_oby, &e,
          sparp_gp_trav_expand_binds_gp_in, NULL,
          sparp_gp_trav_expand_binds_expn_in, NULL, sparp_gp_trav_expand_binds_expn_subq,
          NULL );
        expr_ptr[0] = ((SPART *)tmp_oby)->_.oby.expn;
      }
    }
  return;
}

void
sparp_rewrite_retvals (sparp_t *sparp, SPART *req_top, int safely_copy_retvals)
{
  dk_set_t binds = NULL;
  int ctr;
  rdf_grab_config_t *rgc = &(sparp->sparp_env->spare_src.ssrc_grab);
  if (rgc->rgc_all)
    spar_add_rgc_vars_and_consts_from_retvals (sparp, req_top->_.req_top.retvals);
  if (safely_copy_retvals)
    req_top->_.req_top.expanded_orig_retvals = sparp_treelist_full_copy (sparp, req_top->_.req_top.retvals, req_top->_.req_top.pattern);
  else
    req_top->_.req_top.expanded_orig_retvals = (SPART **)t_box_copy ((caddr_t)(req_top->_.req_top.retvals));
/* Unlike spar_retvals_of_construct() that can be called during parsing,
spar_retvals_of_describe() should wait for obtaining all variables and then
sparp_expand_top_retvals () to process 'DESCRIBE * ...'. */
  if (DESCRIBE_L == req_top->_.req_top.subtype)
    {
      req_top->_.req_top.retvals =
        spar_retvals_of_describe (sparp, req_top,
          req_top->_.req_top.retvals,
          req_top->_.req_top.limit,
          req_top->_.req_top.offset );
    }
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    sparp_gp_trav_preopt_in_gp, NULL,
    NULL, NULL, sparp_gp_trav_preopt_expn_subq,
    NULL );
  DO_BOX_FAST (SPART *, gby, ctr, req_top->_.req_top.groupings)
    {
      if (NULL != binds)
        sparp_expand_binds_like_macro (sparp, req_top->_.req_top.groupings + ctr, binds, req_top->_.req_top.pattern);
      if (SPAR_ALIAS == SPART_TYPE (gby))
        t_set_push (&binds, gby);
    }
  END_DO_BOX_FAST;
  if ((NULL != req_top->_.req_top.having) && (NULL != binds))
    sparp_expand_binds_like_macro (sparp, &(req_top->_.req_top.having), binds, req_top->_.req_top.pattern);
  DO_BOX_FAST (SPART *, rval, ctr, req_top->_.req_top.retvals)
    {
      if (NULL != binds)
        sparp_expand_binds_like_macro (sparp, req_top->_.req_top.retvals + ctr, binds, req_top->_.req_top.pattern);
      if (SPAR_ALIAS == SPART_TYPE (rval))
        t_set_push (&binds, rval);
    }
  END_DO_BOX_FAST;
  if (NULL != binds)
    {
      DO_BOX_FAST (SPART *, oby, ctr, req_top->_.req_top.order)
        {
          sparp_expand_binds_like_macro (sparp, &(oby->_.oby.expn), binds, req_top->_.req_top.pattern);
        }
      END_DO_BOX_FAST;
    }
}

/* Composing counters of usages.
\c trav_env_this points to the innermost graph pattern.
\c common_env is not used. */

int sparp_gp_trav_cu_in_triples (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env);
int sparp_gp_trav_cu_out_triples_1 (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env);
int sparp_gp_trav_cu_out_triples_2 (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env);
int sparp_gp_trav_cu_in_expns (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env);
int sparp_gp_trav_cu_in_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env);
int sparp_gp_trav_cu_in_retvals (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env);

void
sparp_gp_trav_cu_in_options (sparp_t *sparp, SPART *gp, SPART *curr, SPART **options, void *common_env)
{
  int ctr;
  int set_tabid = (SPAR_TRIPLE == curr->type);
  for (ctr = BOX_ELEMENTS (options); 1 < ctr; ctr -= 2)
    {
      ptrlong key = ((ptrlong)(options[ctr-2]));
      SPART *val = options[ctr-1];
      switch (key)
        {
        case OFFBAND_L: case SCORE_L:
          {
            if (SPART_VARR_GLOBAL & val->_.var.rvr.rvrRestrictions)
              spar_error (sparp, "Only plain variables can be used in OFFBAND_L or SCORE_L options, not parameters like ?%.50s", val->_.var.vname);
            sparp_equiv_get (sparp, gp, val, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE | SPARP_EQUIV_ADD_GSPO_USE);
            if (!set_tabid)
              spar_internal_error (sparp, "sparp_" "gp_trav_cu_in_options(): OFFBAND_L or SCORE_L not in triple");
            val->_.var.tabid = curr->_.triple.tabid;
            break;
          }
        case T_STEP_L:
          {
            caddr_t name = val->_.alias.aname;
            sparp_equiv_get (sparp, gp, (SPART *)name, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_GET_NAMESAKES | SPARP_EQUIV_ADD_SUBQUERY_USE);
            break;
          }
        case SAME_AS_L: case SAME_AS_O_L: case SAME_AS_P_L: case SAME_AS_S_L:  case SAME_AS_S_O_L:
        case GEO_L: case PRECISION_L:
        case SCORE_LIMIT_L: case T_MIN_L: case T_MAX_L:
          {
            sparp_trav_state_t stss [SPARP_MAX_SYNTDEPTH+2];
            if (!IS_BOX_POINTER (val))
              break;
            memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
            stss[1].sts_ancestor_gp = gp;
            sparp_gp_trav_int (sparp, val, stss+1, common_env,
              sparp_gp_trav_cu_in_triples, sparp_gp_trav_cu_out_triples_1,
              sparp_gp_trav_cu_in_expns, NULL, sparp_gp_trav_cu_in_subq, NULL );
            break;
          }
        case T_IN_L: case T_OUT_L:
          {
            int v_ctr;
            DO_BOX_FAST (SPART *, v, v_ctr, val->_.list.items)
              {
                sparp_equiv_t *eq = sparp_equiv_get (sparp, gp, (SPART *)(v->_.var.vname), SPARP_EQUIV_GET_NAMESAKES | SPARP_EQUIV_GET_ASSERT);
                ptrlong *pos1_ptr = ((T_IN_L == key) ? &(eq->e_pos1_t_in) : &(eq->e_pos1_t_out));
                if ((0 != pos1_ptr[0]) && ((1+v_ctr) != pos1_ptr[0]))
                  spar_error (sparp, "Variable ?%.100s is used twice in %s option (directly or via equality with other variable)",
                    v->_.var.vname, ((T_IN_L == key) ? "T_IN" : "T_OUT") );
                pos1_ptr[0] = 1+v_ctr;
              }
            END_DO_BOX_FAST;
            break;
          }
        case SPAR_SERVICE_INV:
          {
            SPART *ep = val->_.sinv.endpoint;
            if (SPAR_VARIABLE == SPART_TYPE (ep))
              sparp_equiv_get (sparp, gp, ep, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE | SPARP_EQUIV_ADD_CONST_READ);
            break;
          }
        }
    }
}

int
sparp_gp_trav_cu_in_triples (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  int fctr;
  SPART *gp = sts_this->sts_ancestor_gp;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      if ((SELECT_L == curr->_.gp.subtype) && (0 == curr->_.gp.equiv_count))
        {
          int ctr;
          sparp_gp_trav_suspend (sparp);
          curr->_.gp.subquery = sparp_rewrite_all (sparp, curr->_.gp.subquery, 1);
          sparp_gp_trav_resume (sparp);
          DO_BOX_FAST (SPART *, retval, ctr, curr->_.gp.subquery->_.req_top./*orig_*/retvals)
            {
              caddr_t name;
              switch (SPART_TYPE (retval))
                {
                  case SPAR_VARIABLE:
                    name = retval->_.var.vname;
                    curr->_.gp.subquery->_.req_top./*orig_*/retvals[ctr] =
                      retval = spartlist (sparp, 6, SPAR_ALIAS, retval, name, SSG_VALMODE_AUTO, (ptrlong)0, (ptrlong)1);
                    break;
                  case SPAR_ALIAS:
                    name = retval->_.alias.aname; break;
                  default: name = NULL;
                }
              if (NULL == name)
                goto ignore_retval_name; /* see below */
              if (SPART_VARNAME_IS_GLOB(name))
                goto ignore_retval_name; /* see below */
              sparp_equiv_get (sparp, curr, (SPART *)name, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_GET_NAMESAKES | SPARP_EQUIV_ADD_SUBQUERY_USE);
ignore_retval_name: ;
            }
          END_DO_BOX_FAST;
          if (NULL != curr->_.gp.options)
            sparp_gp_trav_cu_in_options (sparp, curr, curr, curr->_.gp.options, common_env);
        }
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
      if (OPTIONAL_L == curr->_.triple.subtype)
        continue;
      eq = sparp_equiv_get (sparp, gp, fld, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE | SPARP_EQUIV_ADD_GSPO_USE);
      fld->_.var.tabid = curr->_.triple.tabid;
      sparp_equiv_tighten (sparp, eq, &(fld->_.var.rvr), ~0);
    }
  if (NULL != curr->_.triple.options)
    sparp_gp_trav_cu_in_options (sparp, gp, curr, curr->_.triple.options, common_env);
  return SPAR_GPT_NODOWN;
}

int
sparp_gp_trav_cu_out_triples_1 (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  if (SPAR_GP == SPART_TYPE(curr))
    {
      int eq_ctr;
      SPARP_FOREACH_GP_EQUIV (sparp, curr, eq_ctr, eq)
        {
          int sub_ctr;
          eq->e_nested_bindings = ((VALUES_L == curr->_.gp.subtype) ? 1 : 0);
          DO_BOX_FAST_REV (ptrlong, sub_idx, sub_ctr, eq->e_subvalue_idxs)
            {
              sparp_equiv_t *sub_eq = SPARP_EQUIV(sparp,sub_idx);
              if (SPARP_EQ_IS_ASSIGNED_LOCALLY(sub_eq))
                eq->e_nested_bindings += 1;
            }
          END_DO_BOX_FAST;
        }
      END_SPARP_FOREACH_GP_EQUIV;
    }
  return 0;
}

int
sparp_gp_trav_cu_out_triples_1_merge_recvs (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  int eq_ctr;
  sparp_gp_trav_cu_out_triples_1 (sparp, curr, sts_this, common_env);
  if (SPAR_GP != SPART_TYPE(curr))
    return 0;
  if (OPTIONAL_L == curr->_.gp.subtype)
    return 0;
  SPARP_FOREACH_GP_EQUIV (sparp, curr, eq_ctr, eq)
    {
      int ctr_r1;
      DO_BOX_FAST_REV (ptrlong, recv1_idx, ctr_r1, eq->e_receiver_idxs)
        {
          int ctr_r2;
          for (ctr_r2 = BOX_ELEMENTS (eq->e_receiver_idxs); --ctr_r2 > ctr_r1; /* no step */)
            {
              int recv2_idx = eq->e_receiver_idxs[ctr_r2];
              SPART *recv_gp;
              sparp_equiv_t *recv1_eq = SPARP_EQUIV(sparp,recv1_idx);
              sparp_equiv_t *recv2_eq = SPARP_EQUIV(sparp,recv2_idx);
              if (recv1_eq == recv2_eq)
                spar_internal_error (sparp, "sparp_" "gp_trav_cu_out_triples_1_merge_recvs (): duplicate receiver");
              recv_gp = recv1_eq->e_gp;
              if (recv_gp != recv2_eq->e_gp)
                spar_internal_error (sparp, "sparp_" "gp_trav_cu_out_triples_1_merge_recvs (): receivers in different gps");
              if ((UNION_L == recv_gp->_.gp.subtype) || (SPAR_UNION_WO_ALL == recv_gp->_.gp.subtype))
                return 0;
              sparp_equiv_merge (sparp, recv1_eq, recv2_eq);
            }
        }
      END_DO_BOX_FAST;
    }
  END_SPARP_FOREACH_GP_EQUIV;
  return 0;
}


int
sparp_gp_trav_cu_out_triples_2 (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  if (SPAR_GP == SPART_TYPE(curr))
    {
      int eq_ctr;
      SPARP_FOREACH_GP_EQUIV (sparp, curr, eq_ctr, eq)
        {
          int varnamectr;
          DO_BOX_FAST (caddr_t, varname, varnamectr, eq->e_varnames)
            {
              t_set_push_new_string ((dk_set_t *)common_env, varname);
            }
          END_DO_BOX_FAST;
        }
      END_SPARP_FOREACH_GP_EQUIV;
    }
  return 0;
}

int
sparp_gp_trav_cu_in_expns (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  SPART *gp = sts_this->sts_ancestor_gp;
  switch (SPART_TYPE(curr))
    {
    case SPAR_BOP_EQNAMES:
      {
        sparp_equiv_t *eq_l = sparp_equiv_get (sparp, gp, (SPART *)(curr->_.bin_exp.left->_.var.vname), SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_GET_NAMESAKES);
        sparp_equiv_t *eq_r = sparp_equiv_get (sparp, gp, (SPART *)(curr->_.bin_exp.right->_.var.vname), SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_GET_NAMESAKES);
        if ((eq_l == eq_r) || (SPARP_EQUIV_MERGE_OK == sparp_equiv_merge (sparp, eq_l, eq_r)))
          {
            eq_l->e_replaces_filter |= SPART_VARR_EQ_VAR;
            sts_this->sts_curr_array[sts_this->sts_ofs_of_curr_in_array] = SPAR_MAKE_BOOL_LITERAL(sparp, 1);
            sparp->sparp_rewrite_dirty++;
          }
        else
          curr->type = BOP_EQ;
        return 0;
      }
    case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
      {
        sparp_equiv_t *eq = sparp_equiv_get (sparp, gp, curr,
          SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE |
          ((NULL == curr->_.var.tabid) ? SPARP_EQUIV_ADD_CONST_READ : SPARP_EQUIV_ADD_GSPO_USE) );
        eq->e_rvr.rvrRestrictions |= (curr->_.var.rvr.rvrRestrictions & (SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL)); /* sparp_equiv_tighten (sparp, eq, &(curr->_.var.rvr), ~0); A variable in an expression can not bring knowledge by itself */
        return 0;
      }
    default: ;
    }
  return 0;
}

int
sparp_gp_trav_cu_in_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  dk_set_t all_sub_vars = NULL;
  sparp_gp_trav_suspend (sparp);
  sparp_count_usages (sparp, curr->_.gp.subquery, &all_sub_vars);
  sparp_gp_trav_resume (sparp);
  DO_SET (caddr_t, varname, &all_sub_vars)
    {
      SPART *rel_gp;
      sparp_equiv_get (sparp, curr, (SPART *)varname, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_GET_NAMESAKES | SPARP_EQUIV_ADD_OPTIONAL_READ);
      if (NULL != sts_this->sts_ancestor_gp)
        rel_gp = sts_this->sts_ancestor_gp;
      else
        rel_gp = sparp->sparp_stp->stp_trav_req_top->_.req_top.pattern;
      sparp_equiv_get (sparp, rel_gp, (SPART *)varname, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_GET_NAMESAKES | SPARP_EQUIV_ADD_OPTIONAL_READ);
    }
  END_DO_SET ()
  sparp_gp_trav_cu_out_triples_1 (sparp, curr, sts_this, common_env);
  return 0;
}

int
sparp_gp_trav_cu_in_retvals (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  SPART *top_gp = sparp->sparp_stp->stp_trav_req_top->_.req_top.pattern;
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
  curr->_.var.rvr.rvrRestrictions |= SPART_VARR_EXPORTED /* This is redundand: if these bits are set, why set them again: | (curr->_.var.rvr.rvrRestrictions & (SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL))*/ ;
  sparp_equiv_tighten (sparp, eq, &(curr->_.var.rvr), ~0);
  return 0;
}

void
sparp_count_usages (sparp_t *sparp, SPART *req_top, dk_set_t *optvars_ret)
{
  sparp_gp_trav_top_pattern (sparp, req_top, optvars_ret,
    sparp_gp_trav_cu_in_triples, sparp_gp_trav_cu_out_triples_1,
    sparp_gp_trav_cu_in_expns, NULL, sparp_gp_trav_cu_in_subq,
    NULL );
  sparp_trav_out_clauses (sparp, req_top, optvars_ret,
        NULL, NULL,
        sparp_gp_trav_cu_in_retvals, NULL, sparp_gp_trav_cu_in_subq,
        NULL );
  if (NULL != optvars_ret)
    sparp_gp_trav_top_pattern (sparp, req_top, optvars_ret,
      NULL, sparp_gp_trav_cu_out_triples_2,
      NULL, NULL, sparp_gp_trav_cu_in_subq,
      NULL );
}

int
sparp_tree_returns_ref (sparp_t *sparp, SPART *tree)
{
  switch (SPART_TYPE (tree))
    {
    case SPAR_QNAME: return 1;
    case SPAR_BUILT_IN_CALL:
      if (IRI_L == tree->_.builtin.btype)
        return 1;
      break;
    }
  return 0;
}

static int
sparp_expn_rside_rank (SPART *tree)
{
  switch (SPART_TYPE (tree))
    {
    case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
      {
        ptrlong restr = tree->_.var.rvr.rvrRestrictions;
        if (SPARP_FIXED_AND_NOT_NULL (restr))
          return 0x40;
        if (SPART_VARR_FIXED & restr)
          return 0x20;
        if ((SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL) & restr)
          return 0x10;
        if (SPART_VARR_IS_IRI & restr)
          return 0x8;
        if (SPART_VARR_IS_REF & restr)
          return 0x4;
        if (SPART_VARR_IS_LIT & restr)
          return 0x2;
        return 0x0;
      }
    case SPAR_LIT: return 0x400;
    case SPAR_QNAME: return 0x1000;
    case SPAR_BUILT_IN_CALL: return 0x4000;
    case SPAR_FUNCALL: return 0x10000;
    }
  return 0x20000;
}

void
sparp_rotate_comparisons_by_rank (SPART *filt)
{
  switch (SPART_TYPE (filt))
    {
    case SPAR_BOP_EQ_NONOPT: /* no break */
    case SPAR_BOP_EQNAMES: /* no break */
    case BOP_EQ:
    case BOP_NEQ:
    case BOP_LT:
    case BOP_LTE:
    case BOP_GT:
    case BOP_GTE:
      {
        SPART *l = filt->_.bin_exp.left;
        SPART *r = filt->_.bin_exp.right;
        int lrrank = sparp_expn_rside_rank (l);
        int rrrank = sparp_expn_rside_rank (r);
        if (lrrank > rrrank)
          {
            filt->_.bin_exp.right = l;
            filt->_.bin_exp.left = r;
            switch (SPART_TYPE (filt))
              {
              case BOP_LT:	filt->type = BOP_GT; break;
              case BOP_LTE:	filt->type = BOP_GTE; break;
              case BOP_GT:	filt->type = BOP_LT; break;
              case BOP_GTE:	filt->type = BOP_LTE; break;
              }
          }
        break;
      }
    case SPAR_BUILT_IN_CALL:
      if (SPAR_BIF_SAMETERM == filt->_.builtin.btype)
        {
          SPART *l = filt->_.builtin.args[0];
          SPART *r = filt->_.builtin.args[1];
          int lrrank = sparp_expn_rside_rank (l);
          int rrrank = sparp_expn_rside_rank (r);
          if (lrrank > rrrank)
            {
              filt->_.builtin.args[0] = r;
              filt->_.builtin.args[1] = l;
            }
        }
      break;
    default:
      break;
    }
}

#define SPAR_ASSUME_IS_ALWAYS_TRUE	((SPART *)((ptrlong)1))
#define SPAR_ASSUME_IS_CONTRADICTION	((SPART *)((ptrlong)0))

void
sparp_use_assume_rvr_restr (sparp_t *sparp, SPART *curr, SPART **expn_ptr, SPART *arg, ptrlong addon_restrictions)
{
  switch (SPART_TYPE (arg))
    {
    case SPAR_VARIABLE:
/*      if (SPART_VARNAME_IS_GLOB (arg->_.var.vname))*/
        {
          int eq_ctr, eq_count = sparp->sparp_sg->sg_equiv_count;
          for (eq_ctr = sparp->sparp_first_equiv_idx; eq_ctr < eq_count; eq_ctr++)
            {
              sparp_equiv_t *eq = SPARP_EQUIV (sparp, eq_ctr);
              int vctr = ((NULL != eq) ? eq->e_var_count : 0);
              while (vctr--)
                if ((eq->e_vars[vctr]->_.var.vname == arg->_.var.vname)
                  && ((eq->e_vars[vctr]->_.var.rvr.rvrRestrictions & addon_restrictions) != addon_restrictions) )
                  {
                    sparp_rvr_add_restrictions (sparp, &(eq->e_vars[vctr]->_.var.rvr), addon_restrictions);
                    eq->e_vars[vctr]->_.var.restr_of_col |= addon_restrictions;
                  }
            }
        }
/*      else
        {
          sparp_rvr_add_restrictions (sparp, &(arg->_.var.rvr), addon_restrictions);
          arg->_.var.restr_of_col |= addon_restrictions;
        }*/
      return;
    case SPAR_QNAME: case SPAR_LIT:
      if (NULL != expn_ptr)
        {
          rdf_val_range_t rvr;
          sparp_rvr_set_by_constant (sparp, &rvr, NULL, arg);
          sparp_rvr_add_restrictions (sparp, &rvr, addon_restrictions);
          if (rvr.rvrRestrictions & SPART_VARR_CONFLICT)
            expn_ptr[0] = SPAR_ASSUME_IS_CONTRADICTION;
        }
      return;
    default:
      if (NULL != expn_ptr)
        {
          rdf_val_range_t rvr;
          sparp_get_expn_rvr (sparp, arg, &rvr, 0);
          sparp_rvr_add_restrictions (sparp, &rvr, addon_restrictions);
          if (rvr.rvrRestrictions & SPART_VARR_CONFLICT)
            expn_ptr[0] = SPAR_ASSUME_IS_CONTRADICTION;
        }
      return;
    }
}

void
sparp_use_assume_eq (sparp_t *sparp, SPART *curr, SPART **stmt_ptr, SPART *left, SPART *right)
{
  sparp_use_assume_rvr_restr (sparp, curr, stmt_ptr, left, SPART_VARR_NOT_NULL);
  sparp_use_assume_rvr_restr (sparp, curr, stmt_ptr, right, SPART_VARR_NOT_NULL);
  if (SPAR_ASSUME_IS_CONTRADICTION != stmt_ptr[0])
    {
      rdf_val_range_t left_rvr, right_rvr, mix_rvr;
      ptrlong addon_restrs;
      sparp_get_expn_rvr (sparp, left, &left_rvr, 1);
      sparp_get_expn_rvr (sparp, right, &right_rvr, 0);
      sparp_rvr_copy (sparp, &mix_rvr, &left_rvr);
      sparp_rvr_tighten (sparp, &mix_rvr, &right_rvr, ~(SPART_VARR_EXTERNAL | SPART_VARR_GLOBAL));
      if (mix_rvr.rvrRestrictions & SPART_VARR_CONFLICT)
        {
          stmt_ptr[0] = SPAR_ASSUME_IS_CONTRADICTION;
          return;
        }
      addon_restrs = (mix_rvr.rvrRestrictions & ~left_rvr.rvrRestrictions & ~(SPART_VARR_FIXED | SPART_VARR_TYPED | SPART_VARR_SPRINTFF | SPART_VARR_IRI_CALC));
      if (0x0 != addon_restrs)
        sparp_use_assume_rvr_restr (sparp, curr, stmt_ptr, left, addon_restrs);
      addon_restrs = (mix_rvr.rvrRestrictions & ~right_rvr.rvrRestrictions & ~(SPART_VARR_FIXED | SPART_VARR_TYPED | SPART_VARR_SPRINTFF | SPART_VARR_IRI_CALC));
      if (0x0 != addon_restrs)
        sparp_use_assume_rvr_restr (sparp, curr, stmt_ptr, left, addon_restrs);
    }
}

void
sparp_use_assume (sparp_t *sparp, SPART *curr, SPART **stmt_ptr)
{
  SPART *stmt = stmt_ptr[0];
  int stmt_type = SPART_TYPE (stmt);
  if (BOP_AND == stmt_type)
    {
      sparp_use_assume (sparp, curr, &(stmt->_.bin_exp.left));
      if (SPAR_ASSUME_IS_CONTRADICTION == stmt->_.bin_exp.left)
        {
          stmt_ptr[0] = SPAR_ASSUME_IS_CONTRADICTION;
          return;
        }
      sparp_use_assume (sparp, curr, &(stmt->_.bin_exp.right));
      if (SPAR_ASSUME_IS_CONTRADICTION == stmt->_.bin_exp.right)
        {
          stmt_ptr[0] = SPAR_ASSUME_IS_CONTRADICTION;
          return;
        }
      return;
    }
  switch (stmt_type)
    {
    case SPAR_QNAME: case SPAR_LIT: spar_error (sparp, "Constant expression in ASSUME is formally valid but too suspicious");
    case SPAR_BUILT_IN_CALL:
      {
        SPART *arg;
        if (0 == BOX_ELEMENTS (stmt->_.builtin.args))
          return;
        arg = stmt->_.builtin.args[0];
        switch (stmt->_.builtin.btype)
          {
          case SPAR_BIF_ISBLANK: sparp_use_assume_rvr_restr (sparp, curr, stmt_ptr, arg, SPART_VARR_NOT_NULL | SPART_VARR_IS_REF | SPART_VARR_IS_BLANK); return;
          case SPAR_BIF_ISIRI: sparp_use_assume_rvr_restr (sparp, curr, stmt_ptr, arg, SPART_VARR_NOT_NULL | SPART_VARR_IS_REF | SPART_VARR_IS_IRI); return;
          case SPAR_BIF_ISREF: sparp_use_assume_rvr_restr (sparp, curr, stmt_ptr, arg, SPART_VARR_NOT_NULL | SPART_VARR_IS_REF); return;
          case SPAR_BIF_ISLITERAL: sparp_use_assume_rvr_restr (sparp, curr, stmt_ptr, arg, SPART_VARR_NOT_NULL | SPART_VARR_IS_LIT); return;
          case SPAR_BIF_ISNUMERIC: sparp_use_assume_rvr_restr (sparp, curr, stmt_ptr, arg, SPART_VARR_NOT_NULL | SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL); return;
          case BOUND_L: sparp_use_assume_rvr_restr (sparp, curr, stmt_ptr, arg, SPART_VARR_NOT_NULL); return;
          case SPAR_BIF_SAMETERM:
            sparp_rotate_comparisons_by_rank (stmt);
            sparp_use_assume_eq (sparp, curr, stmt_ptr, stmt->_.builtin.args[0], stmt->_.builtin.args[1]);
            return;
          }
      }
    case SPAR_FUNCALL:
      {
        ccaddr_t qname = stmt->_.funcall.qname;
        SPART *arg;
        if (0 == BOX_ELEMENTS (stmt->_.funcall.argtrees))
          return;
        arg = stmt->_.funcall.argtrees[0];
        if (!strcmp (qname, "bif:isnull")) { sparp_use_assume_rvr_restr (sparp, curr, stmt_ptr, arg, SPART_VARR_ALWAYS_NULL); return; }
        if (!strcmp (qname, "bif:isnotnull")) { sparp_use_assume_rvr_restr (sparp, curr, stmt_ptr, arg, SPART_VARR_NOT_NULL); return; }
      }
    case BOP_EQ:
      {
        sparp_rotate_comparisons_by_rank (stmt);
        sparp_use_assume_eq (sparp, curr, stmt_ptr, stmt->_.bin_exp.left, stmt->_.bin_exp.right);
        return;
      }
    }
}


typedef struct so_BOP_OR_filter_ctx_s
{
  sparp_t *bofc_sparp;				/*!< parser/compiler context, to not pass an extra argument */
  SPART *bofc_var_sample;			/*!< Common optimizable variable in question */
  dk_set_t bofc_strings;			/*!< Collected string values, they may be convert into sprintf format strings to tighten equiv of the common variable */
  SPART *bofc_reason_for_union;			/*!< The filter has a call of contains() or st_intersects() as members so the gp containing this OR should be converted to UNION */
  SPART **bofc_BOP_OR_of_reason_for_union;	/*!< When a { pattern FILTER ( ... OR ... ) } should be replaced with UNION, one OR should be edited */
  int bofc_not_optimizable;			/*!< The filter is of complicated form or the variable is not common or global */
  int bofc_can_be_iri;				/*!< Flag if there's at least equality to a IRI */
  int bofc_can_be_string;			/*!< Flag if there's at least equality to a literal string */
  int bofc_can_be_nonstringlit;			/*!< Flag if there's at least equality to a non-string literal */
} so_BOP_OR_filter_ctx_t;

int
sparp_optimize_BOP_OR_filter_walk_lvar (SPART *lvar, so_BOP_OR_filter_ctx_t *ctx)
{
  if (SPAR_VARIABLE != SPART_TYPE (lvar))
    { /* for optimization, there should be variable at left */
      ctx->bofc_not_optimizable = 1;
      return 1;
    }
  if (NULL == ctx->bofc_var_sample)
    ctx->bofc_var_sample = lvar;
  else if (strcmp (ctx->bofc_var_sample->_.var.vname, lvar->_.var.vname))
    { /* for optimization, there should be _same_ variable at left */
      ctx->bofc_not_optimizable = 1;
      return 1;
    }
  return 0;
}

int
sparp_optimize_BOP_OR_filter_walk_rexpn (SPART *rexpn, so_BOP_OR_filter_ctx_t *ctx)
{
  caddr_t lit_val;
  switch (SPART_TYPE (rexpn))
    {
    case SPAR_QNAME:
      ctx->bofc_can_be_iri++;
      dk_set_push (&(ctx->bofc_strings), rexpn->_.lit.val);
      return 0;
    case SPAR_LIT:
      lit_val = rexpn->_.lit.val;
      if (!IS_STRING_DTP (DV_TYPE_OF (lit_val)))
        ctx->bofc_can_be_nonstringlit++;
      else
        {
          ctx->bofc_can_be_string++;
          dk_set_push (&(ctx->bofc_strings), lit_val);
        }
      return 0;
/* !!! TBD support for constant expressions here */
    }
  ctx->bofc_not_optimizable = 1;
  return 1;
}

int
sparp_merge_BOP_OR_of_INs_prep (SPART *tree, so_BOP_OR_filter_ctx_t *ctx, SPART **var_ret, SPART ***vals_ret, int *val_count_ret)
{
  switch (SPART_TYPE (tree))
    {
    case BOP_EQ:
      var_ret[0] = tree->_.bin_exp.left;
      vals_ret[0] = &(tree->_.bin_exp.right);
      val_count_ret[0] = 1;
      break;
    case SPAR_BUILT_IN_CALL:
      if (IN_L != tree->_.builtin.btype)
        return 1;
      var_ret[0] = tree->_.builtin.args[0];
      vals_ret[0] = tree->_.builtin.args+1;
      val_count_ret[0] = BOX_ELEMENTS (tree->_.builtin.args) - 1;
      break;
    default:
      return 1;
    }
  if (SPAR_VARIABLE != SPART_TYPE (var_ret[0]))
    return 1;
  return 0;
}

SPART *
sparp_merge_BOP_OR_of_INs (SPART *first, SPART *second, so_BOP_OR_filter_ctx_t *ctx)
{
  sparp_t *sparp = ctx->bofc_sparp;
  SPART *first_var, *second_var;
  SPART **first_vals, **second_vals;
  SPART **res_IN_args;
  int first_val_count, second_val_count;
  if (sparp_merge_BOP_OR_of_INs_prep (first, ctx, &first_var, &first_vals, &first_val_count))
    return NULL;
  if (sparp_merge_BOP_OR_of_INs_prep (second, ctx, &second_var, &second_vals, &second_val_count))
    return NULL;
  if (strcmp (first_var->_.var.vname, second_var->_.var.vname))
    return NULL;
  res_IN_args = (SPART **)t_alloc_box ((1 + first_val_count + second_val_count) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  res_IN_args[0] = first_var;
  memcpy (res_IN_args + 1, first_vals, first_val_count * sizeof (caddr_t));
  memcpy (res_IN_args + 1 + first_val_count, second_vals, second_val_count * sizeof (caddr_t));
  sparp_equiv_remove_var (sparp, SPARP_EQUIV (sparp, second_var->_.var.equiv_idx), second_var);
  return sparp_make_builtin_call (sparp, IN_L, res_IN_args);
}

void
sparp_optimize_BOP_OR_filter_walk (SPART **filt_ptr, SPART **filt_parent_ptr, so_BOP_OR_filter_ctx_t *ctx)
{
  SPART *filt = filt_ptr[0];
  ptrlong filt_type = SPART_TYPE (filt);
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &filt_type, 8000))
    spar_error (ctx->bofc_sparp, "Stack overflow");
  switch (filt_type)
    {
    case BOP_OR:
      {
        SPART *new_l, *new_r, *new_merged;
        sparp_optimize_BOP_OR_filter_walk (&(filt->_.bin_exp.left), filt_ptr, ctx);
        if (ctx->bofc_reason_for_union)
          return;
        sparp_optimize_BOP_OR_filter_walk (&(filt->_.bin_exp.right), filt_ptr, ctx);
        if (ctx->bofc_reason_for_union)
          return;
        new_l = filt->_.bin_exp.left;
        new_r = filt->_.bin_exp.right;
        if (BOP_OR != SPART_TYPE (new_r))
          {
            if (BOP_OR != SPART_TYPE (new_l))
              {
                new_merged = sparp_merge_BOP_OR_of_INs (new_l, new_r, ctx);
                if (NULL != new_merged)
                  {
                    filt_ptr[0] = new_merged;
                    return;
                  }
              }
            else
              {
                new_merged = sparp_merge_BOP_OR_of_INs (new_l->_.bin_exp.left, new_r, ctx);
                if (NULL != new_merged)
                  {
                    new_l->_.bin_exp.left = new_merged;
                    filt_ptr[0] = new_l;
                    return;
                  }
                new_merged = sparp_merge_BOP_OR_of_INs (new_l->_.bin_exp.right, new_r, ctx);
                if (NULL != new_merged)
                  {
                    new_l->_.bin_exp.right = new_merged;
                    filt_ptr[0] = new_l;
                    return;
                  }
              }
          }
        return;
      }
    case SPAR_BUILT_IN_CALL:
      if (IN_L == filt->_.builtin.btype)
        {
          int argctr;
          if (sparp_optimize_BOP_OR_filter_walk_lvar (filt->_.builtin.args[0], ctx))
            goto cannot_optimize; /* see below */
          for (argctr = BOX_ELEMENTS (filt->_.builtin.args); 0 < --argctr; /* no step */)
            {
              if (sparp_optimize_BOP_OR_filter_walk_rexpn (filt->_.builtin.args[argctr], ctx))
                goto cannot_optimize; /* see below */
            }
          return;
        }
      if (SPAR_BIF_SAMETERM != filt->_.builtin.btype)
        goto cannot_optimize; /* see below */
      /* no break, try get optimization hints like it is BOP_EQ */
    case BOP_EQ: case SPAR_BOP_EQNAMES: /* No case for SPAR_BOP_EQ_NONOPT ! */
      sparp_rotate_comparisons_by_rank (filt);
      if (sparp_optimize_BOP_OR_filter_walk_lvar (filt->_.bin_exp.left, ctx))
        goto cannot_optimize; /* see below */
      if (sparp_optimize_BOP_OR_filter_walk_rexpn (filt->_.bin_exp.right, ctx))
        goto cannot_optimize; /* see below */
      return;
    case SPAR_FUNCALL:
      {
        if (NULL != spar_filter_is_freetext (ctx->bofc_sparp, filt, NULL))
          {
            ctx->bofc_reason_for_union = filt;
            ctx->bofc_BOP_OR_of_reason_for_union = filt_parent_ptr;
            return;
          }
        break;
      }
    default: ;
    }
cannot_optimize:
/* The very natural default is to say 'cannot optimize' and escape */
  ctx->bofc_not_optimizable = 1;
  return;
}

/*! Processes of simple filters inside BOP_OR (or top-level IN_L) that introduce restrictions on variables. */
int
sparp_optimize_BOP_OR_filter (sparp_t *sparp, SPART *parent_gp, SPART *gp, int gp_idx, int filt_idx)
{
  SPART **filt_ptr = gp->_.gp.filters + filt_idx;
  sparp_equiv_t *eq_l;
  rdf_val_range_t new_rvr;
  so_BOP_OR_filter_ctx_t ctx;
  int sff_ctr;
  memset (&ctx, 0, sizeof (so_BOP_OR_filter_ctx_t));
  ctx.bofc_sparp = sparp;
  sparp_optimize_BOP_OR_filter_walk (filt_ptr, NULL, &ctx);
  if (NULL != ctx.bofc_reason_for_union)
    { /* This eliminates the need in the rest of processing because OR will be changed (or even disappear entirely) */
      SPART *alt_for_reason, *case_with_reason, *case_with_rest;
#ifdef SPARQL_DEBUG
      if (((NULL == parent_gp) ? 1 : 0) != ((WHERE_L == gp->_.gp.subtype) ? 1 : 0))
        spar_internal_error (sparp, "sparp_" "optimize_BOP_OR_filter(): weird NULL parent gp / WHERE_L gp subtype combination");
#endif
      if (filt_idx >= BOX_ELEMENTS (gp->_.gp.filters) - gp->_.gp.glued_filters_count)
        spar_error (sparp, "A special predicate, like bif:contains or bif:st_intersects, can not be used as an argument of '||' operator in a \"joining\" FILTER at line %ld of query; please re-phrase the query", (long)unbox (filt_ptr[0]->srcline));
      if (0 != gp->_.gp.subtype)
        {
          SPART **all_membs, *filt, *new_gp;
          filt = sparp_gp_detach_filter (sparp, gp, filt_idx, NULL);
          all_membs = sparp_gp_detach_all_members (sparp, gp, NULL);
          new_gp = sparp_new_empty_gp (sparp, 0, unbox (gp->srcline));
          sparp_gp_attach_many_members (sparp, new_gp, all_membs, 0, NULL);
          sparp_gp_attach_filter (sparp, new_gp, filt, 0, NULL);
          parent_gp = gp;
          gp = new_gp;
          gp_idx = 0;
          filt_idx = 0;
          if (ctx.bofc_BOP_OR_of_reason_for_union == filt_ptr)
            ctx.bofc_BOP_OR_of_reason_for_union = gp->_.gp.filters + filt_idx;
          filt_ptr = gp->_.gp.filters + filt_idx;
        }
      else
        sparp_gp_detach_member (sparp, parent_gp, gp_idx, NULL);
      if (ctx.bofc_BOP_OR_of_reason_for_union[0]->_.bin_exp.left == ctx.bofc_reason_for_union)
        alt_for_reason = ctx.bofc_BOP_OR_of_reason_for_union[0]->_.bin_exp.right;
      else if (ctx.bofc_BOP_OR_of_reason_for_union[0]->_.bin_exp.right == ctx.bofc_reason_for_union)
        alt_for_reason = ctx.bofc_BOP_OR_of_reason_for_union[0]->_.bin_exp.left;
      else
        spar_internal_error (sparp, "sparp_" "optimize_BOP_OR_filter(): bad bofc_BOP_OR_of_reason_for_union");
      ctx.bofc_BOP_OR_of_reason_for_union[0] = alt_for_reason;
      case_with_rest = sparp_gp_full_clone (sparp, gp);
      if (ctx.bofc_BOP_OR_of_reason_for_union == filt_ptr)
        {
          caddr_t ft_type = spar_filter_is_freetext (sparp, alt_for_reason, NULL);
          if (NULL != ft_type)
            {
              SPART *triple_with_var_obj = sparp_find_triple_with_var_obj_of_freetext (sparp, case_with_rest, alt_for_reason, SPAR_TRIPLE_FOR_FT_SHOULD_EXIST | SPAR_TRIPLE_SHOULD_HAVE_NO_FT_TYPE);
              triple_with_var_obj->_.triple.ft_type = ft_type;
            }
        }

      ctx.bofc_BOP_OR_of_reason_for_union[0] = ctx.bofc_reason_for_union;
      if (ctx.bofc_BOP_OR_of_reason_for_union == filt_ptr)
        {
          caddr_t ft_type = spar_filter_is_freetext (sparp, ctx.bofc_reason_for_union, NULL);
          if (NULL != ft_type)
            {
              SPART *triple_with_var_obj = sparp_find_triple_with_var_obj_of_freetext (sparp, gp, ctx.bofc_reason_for_union, SPAR_TRIPLE_FOR_FT_SHOULD_EXIST | SPAR_TRIPLE_SHOULD_HAVE_NO_FT_TYPE);
              triple_with_var_obj->_.triple.ft_type = ft_type;
            }
        }
      case_with_reason = gp;
      if (SPAR_UNION_WO_ALL == parent_gp->_.gp.subtype)
        {
          sparp_gp_attach_member (sparp, parent_gp, case_with_rest, gp_idx, NULL);
          sparp_gp_attach_member (sparp, parent_gp, case_with_reason, gp_idx, NULL);
        }
      else
        {
          SPART *new_union = sparp_new_empty_gp (sparp, SPAR_UNION_WO_ALL, unbox (gp->srcline));
          sparp_gp_attach_member (sparp, parent_gp, new_union, gp_idx, NULL);
          sparp_gp_attach_member (sparp, new_union, case_with_rest, 0, NULL);
          sparp_gp_attach_member (sparp, new_union, case_with_reason, 0, NULL);
        }
      return 2;
    }
  if (ctx.bofc_not_optimizable)
    {
      while (NULL != ctx.bofc_strings) dk_set_pop (&(ctx.bofc_strings));
      return 0;
    }
  eq_l = sparp_equiv_get (sparp, gp, ctx.bofc_var_sample, 0);
  memset (&new_rvr, 0, sizeof (rdf_val_range_t));
  new_rvr.rvrRestrictions |= SPART_VARR_NOT_NULL;
  if (0 == ctx.bofc_can_be_iri)
    new_rvr.rvrRestrictions |= SPART_VARR_IS_LIT;
  if ((0 == ctx.bofc_can_be_string) && (0 == ctx.bofc_can_be_nonstringlit))
    new_rvr.rvrRestrictions |= SPART_VARR_IS_REF | SPART_VARR_IS_IRI;
  if (0 == ctx.bofc_can_be_nonstringlit)
    {
      new_rvr.rvrRestrictions |= SPART_VARR_SPRINTFF;
      new_rvr.rvrSprintffCount = dk_set_length (ctx.bofc_strings);
      new_rvr.rvrSprintffs = (ccaddr_t *)t_alloc_box (new_rvr.rvrSprintffCount * sizeof(caddr_t), DV_ARRAY_OF_POINTER);
      for (sff_ctr = new_rvr.rvrSprintffCount; sff_ctr--; /* no step */)
        new_rvr.rvrSprintffs[sff_ctr] = sprintff_from_strg (dk_set_pop (&(ctx.bofc_strings)), 1);
    }
  else
    {
      while (NULL != ctx.bofc_strings) dk_set_pop (&(ctx.bofc_strings));
    }
  sparp_equiv_tighten (sparp, eq_l, &new_rvr, ~0);
  return 1;
}

int
sparp_equiv_contains_t_io (sparp_t *sparp, sparp_equiv_t *eq)
{
  int sub_ctr;
  if ((0 != eq->e_pos1_t_in) || (0 != eq->e_pos1_t_in))
    return 1;
  DO_BOX_FAST_REV (ptrlong, sub_idx, sub_ctr, eq->e_subvalue_idxs)
    {
      sparp_equiv_t *sub = SPARP_EQUIV (sparp, sub_idx);
      if (sparp_equiv_contains_t_io (sparp, sub))
        return 1;
    }
  END_DO_BOX_FAST_REV;
  return 0;
}

/*! For an equality in group \c curr between member of \c eq_l and expression \c r,
the function restricts \c eq_l or even merges it with variable of other equiv.
\returns SPART_VARR_XXX bits that can be added to eq_l->e_replaces_filter if equality is no longer needed due to merge, 0 otherwise */
int
spar_var_eq_to_equiv (sparp_t *sparp, SPART *curr, sparp_equiv_t *eq_l, SPART *r)
{
  int ret = 0;
  int flags = 0;
  ptrlong tree_restr_bits = sparp_restr_bits_of_expn (sparp, r);
  eq_l->e_rvr.rvrRestrictions |= SPART_VARR_NOT_NULL | (tree_restr_bits & (
    SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_IS_BLANK |
    SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL |
    SPART_VARR_NOT_NULL | SPART_VARR_ALWAYS_NULL ) );
  switch (SPART_TYPE (r))
    {
    case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
      {
        sparp_equiv_t *eq_r = sparp_equiv_get (sparp, curr, r, 0);
        eq_l->e_rvr.rvrRestrictions |= SPART_VARR_NOT_NULL;
        ret = sparp_equiv_merge (sparp, eq_l, eq_r);
        if (
          (SPARP_EQUIV_MERGE_OK != ret) &&
          (SPARP_EQUIV_MERGE_CONFLICT != ret) &&
          (SPARP_EQUIV_MERGE_DUPE != ret) )
          return 0;
        if (sparp_equiv_contains_t_io (sparp, eq_r))
          return 0;
        flags = SPART_VARR_EQ_VAR;
        break;
      }
    case SPAR_LIT: case SPAR_QNAME:
      {
        int old_rvr = eq_l->e_rvr.rvrRestrictions;
        ret = sparp_equiv_restrict_by_constant (sparp, eq_l, NULL, r);
        if (
          (SPARP_EQUIV_MERGE_OK != ret) &&
          (SPARP_EQUIV_MERGE_CONFLICT != ret) &&
          (SPARP_EQUIV_MERGE_DUPE != ret) )
          return 0;
        flags = SPART_VARR_FIXED | (eq_l->e_rvr.rvrRestrictions & ~old_rvr);
        break;
      }
    case SPAR_BUILT_IN_CALL:
      {
        switch (r->_.builtin.btype)
          {
          case SPAR_BIF_STR: eq_l->e_rvr.rvrRestrictions |= SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL; break;
          case IRI_L: eq_l->e_rvr.rvrRestrictions |= SPART_VARR_IS_REF | SPART_VARR_NOT_NULL; break;
          default:
            {
              const sparp_bif_desc_t *bif_desc = sparp_bif_descs + r->_.builtin.desc_ofs;
              if ((SSG_VALMODE_NUM == bif_desc->sbd_ret_valmode) || (SSG_VALMODE_BOOL == bif_desc->sbd_ret_valmode))
                eq_l->e_rvr.rvrRestrictions |= SPART_VARR_LONG_EQ_SQL;
            }
          }
        return 0;
      }
     default: return 0;
    }
  if (sparp_equiv_contains_t_io (sparp, eq_l))
    return 0;
  return flags | SPART_VARR_NOT_NULL;
}

/* For an != in group \c curr between member of \c eq_l and expression \c r,
the function may sometimes set conflict to \c eq_l or find that the filter is useless (say, inequality between literal and IRI)
\returns SPART_VARR_CONFLICT if != is no longer needed due to added conflict, -1 if proven useless, 0 otherwise */
int
spar_var_bangeq_to_equiv (sparp_t *sparp, SPART *curr, sparp_equiv_t *eq_l, SPART *r)
{
  ptrlong tree_restr_bits = sparp_restr_bits_of_expn (sparp, r);
  if ((eq_l->e_rvr.rvrRestrictions & SPART_VARR_IS_REF) && (tree_restr_bits & SPART_VARR_IS_LIT))
    return -1;
  if ((eq_l->e_rvr.rvrRestrictions & SPART_VARR_IS_LIT) && (tree_restr_bits & SPART_VARR_IS_REF))
    return -1;
  if ((eq_l->e_rvr.rvrRestrictions & SPART_VARR_IS_IRI) && (tree_restr_bits & SPART_VARR_IS_BLANK))
    return -1;
  if ((eq_l->e_rvr.rvrRestrictions & SPART_VARR_IS_BLANK) && (tree_restr_bits & SPART_VARR_IS_IRI))
    return -1;
  if (!(eq_l->e_rvr.rvrRestrictions & SPART_VARR_FIXED))
    return 0;
  switch (SPART_TYPE (r))
    {
    case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
      {
        sparp_equiv_t *eq_r = sparp_equiv_get (sparp, curr, r, 0);
        if (!(eq_r->e_rvr.rvrRestrictions & SPART_VARR_FIXED))
          return 0;
        if (sparp_equivs_have_same_fixedvalue (sparp, eq_l, eq_r))
          {
            SPARP_DEBUG_WEIRD(sparp,"conflict");
            eq_l->e_rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
            eq_r->e_rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
            return SPART_VARR_CONFLICT;
          }
        break;
      }
    case SPAR_LIT: case SPAR_QNAME:
      {
        if (sparp_values_equal (sparp, eq_l->e_rvr.rvrFixedValue, eq_l->e_rvr.rvrDatatype, eq_l->e_rvr.rvrLanguage, (ccaddr_t)r, NULL, NULL))
          {
            SPARP_DEBUG_WEIRD(sparp,"conflict");
            eq_l->e_rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
            return SPART_VARR_CONFLICT;
          }
        break;
      }
    }
  return 0;
}

/* Processing of simple filters that introduce restrictions on variables
\c trav_env_this is not used.
\c common_env is not used. */
int
sparp_filter_to_equiv (sparp_t *sparp, SPART *curr, SPART *filt)
{
  int flags;
/* We rotate comparisons before anything else */
  sparp_rotate_comparisons_by_rank (filt);
/* Now filters can be processed */
  switch (SPART_TYPE (filt))
    {
    case BOP_EQ: case SPAR_BOP_EQNAMES: /* No case for SPAR_BOP_EQ_NONOPT ! Indeed, this is the main reason for introducing SPAR_BOP_EQ_NONOPT at all */
      {
        SPART *l = filt->_.bin_exp.left;
        SPART *r = filt->_.bin_exp.right;
        switch (SPART_TYPE (l))
          {
          case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
            {
              sparp_equiv_t *eq_l = sparp_equiv_get (sparp, curr, l, 0);
              flags = spar_var_eq_to_equiv (sparp, curr, eq_l, r);
              if (flags)
                {
                  eq_l->e_replaces_filter |= flags;
                  return 1;
                }
              return 0;
            }
          case SPAR_QNAME:
            {
              caddr_t lval = l->_.lit.val;
              if ((SPAR_BUILT_IN_CALL == SPART_TYPE (r)) &&
                (DATATYPE_L == r->_.builtin.btype) )
                {
                  SPART *rarg1 = r->_.builtin.args[0];
                  if (SPAR_IS_BLANK_OR_VAR (rarg1))
                    {
                      sparp_equiv_t *rarg1_eq = sparp_equiv_get (sparp, curr, rarg1, 0);
                      flags = SPART_VARR_NOT_NULL;
                      if (
                        (lval == uname_xmlschema_ns_uri_hash_boolean) ||
                        (lval == uname_xmlschema_ns_uri_hash_string) )
                        {
                          flags |= SPART_VARR_IS_LIT;
                        }
                      else if (
                        (lval == uname_xmlschema_ns_uri_hash_date) ||
                        (lval == uname_xmlschema_ns_uri_hash_dateTime) ||
                        (lval == uname_xmlschema_ns_uri_hash_decimal) ||
                        (lval == uname_xmlschema_ns_uri_hash_double) ||
                        (lval == uname_xmlschema_ns_uri_hash_float) ||
                        (lval == uname_xmlschema_ns_uri_hash_integer) ||
                        (lval == uname_xmlschema_ns_uri_hash_time) )
                        {
                          flags |= SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL;
                        }
                      rarg1_eq->e_rvr.rvrRestrictions |= flags;
                      rarg1_eq->e_replaces_filter |= flags;
                    }
                  return 0;
                }
            }
          case SPAR_LIT:
            {
              caddr_t str_lval = NULL;
              switch (DV_TYPE_OF (l))
                {
                case DV_ARRAY_OF_POINTER:
                  str_lval = l->_.lit.val;
                  if (DV_STRING != DV_TYPE_OF (str_lval))
                    str_lval = NULL;
                  break;
                case DV_STRING:
                  str_lval = (caddr_t)l;
                  break;
                }
              if ((NULL != str_lval) && (SPAR_BUILT_IN_CALL == SPART_TYPE (r)) && (SPAR_BIF_STR == r->_.builtin.btype))
                {
                  SPART *rarg1 = r->_.builtin.args[0];
                  if (SPAR_IS_BLANK_OR_VAR (rarg1))
                    {
                      sparp_equiv_t *rarg1_eq = sparp_equiv_get (sparp, curr, rarg1, 0);
                      flags = SPART_VARR_NOT_NULL;
                      rarg1_eq->e_rvr.rvrRestrictions |= flags;
                      rarg1_eq->e_replaces_filter |= flags;
                      if (SPART_VARR_IS_REF & rarg1_eq->e_rvr.rvrRestrictions)
                        {
                          int old_rvr = rarg1_eq->e_rvr.rvrRestrictions;
                          int restr_ret;
                          SPART *lval_tmp_qname = spartlist (sparp, 2, SPAR_QNAME, t_box_dv_uname_nchars (str_lval, box_length (str_lval)-1));
                          restr_ret = sparp_equiv_restrict_by_constant (sparp, rarg1_eq, NULL, lval_tmp_qname);
                          if (
                            (SPARP_EQUIV_MERGE_OK != restr_ret) &&
                            (SPARP_EQUIV_MERGE_CONFLICT != restr_ret) &&
                            (SPARP_EQUIV_MERGE_DUPE != restr_ret) )
                            return 0;
                          flags = SPART_VARR_FIXED | (rarg1_eq->e_rvr.rvrRestrictions & ~old_rvr);
/* no need in <code>if (sparp_equiv_contains_t_io (sparp, eq_l)) return 0;</code> as it is written in spar_var_eq_to_equiv(),
because const=str(var) is never recognized as a special condition on t_in or t_out variables. */
/* no need in <code>rarg1_eq->e_rvr.rvrRestrictions |= flags;</code>, because it is set in sparp_equiv_restrict_by_constant() above */
                          rarg1_eq->e_replaces_filter |= flags;
                          return 1;
                        }
                    }
                  return 0;
                }
            }
          }
        break;
      }
    case BOP_NEQ:
      {
        SPART *l = filt->_.bin_exp.left;
        SPART *r = filt->_.bin_exp.right;
        switch (SPART_TYPE (l))
          {
          case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
            {
              sparp_equiv_t *eq_l = sparp_equiv_get (sparp, curr, l, 0);
              flags = spar_var_bangeq_to_equiv (sparp, curr, eq_l, r);
              if (flags)
                {
                  if (-1 != flags)
                    eq_l->e_replaces_filter |= flags;
                  return 1;
                }
              return 0;
            }
          }
        break;
      }
    case BOP_NOT: break;
    case SPAR_BUILT_IN_CALL:
      {
        SPART *arg1;
        sparp_equiv_t *arg1_eq;
        if (0 == BOX_ELEMENTS_0 (filt->_.builtin.args))
          break;
        arg1 = filt->_.builtin.args[0];
        if (ASSUME_L == filt->_.builtin.btype)
          {
            sparp_use_assume (sparp, curr, &arg1);
            return 1;
          }
        if (SPAR_IS_BLANK_OR_VAR (arg1))
          arg1_eq = sparp_equiv_get (sparp, curr, arg1, 0);
        else
          break;
        switch (filt->_.builtin.btype)
          {
          case SPAR_BIF_ISIRI:
          case SPAR_BIF_ISURI:
            flags = SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_NOT_NULL;
            arg1_eq->e_rvr.rvrRestrictions |= flags;
            arg1_eq->e_replaces_filter |= flags;
            return 1;
          case SPAR_BIF_ISBLANK:
            flags = SPART_VARR_IS_REF | SPART_VARR_IS_BLANK | SPART_VARR_NOT_NULL;
            arg1_eq->e_rvr.rvrRestrictions |= flags;
            arg1_eq->e_replaces_filter |= flags;
            return 1;
          case SPAR_BIF_ISREF:
            flags = SPART_VARR_IS_REF | SPART_VARR_NOT_NULL;
            arg1_eq->e_rvr.rvrRestrictions |= flags;
            arg1_eq->e_replaces_filter |= flags;
            return 1;
          case SPAR_BIF_ISLITERAL:
            flags = SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL;
            arg1_eq->e_rvr.rvrRestrictions |= flags;
            arg1_eq->e_replaces_filter |= flags;
            return 1;
          case SPAR_BIF_ISNUMERIC:
            flags = SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL | SPART_VARR_NOT_NULL;
            arg1_eq->e_rvr.rvrRestrictions |= flags;
            arg1_eq->e_replaces_filter |= flags;
            break;
          case BOUND_L:
            flags = SPART_VARR_NOT_NULL;
            arg1_eq->e_rvr.rvrRestrictions |= flags;
            arg1_eq->e_replaces_filter |= flags;
            return 1;
          case SPAR_BIF_SAMETERM:
            {
              SPART *arg2 = filt->_.builtin.args[1];
              spar_var_eq_to_equiv (sparp, curr, arg1_eq, arg2); /* No return because sameTerm is more strict than merge of equivs */
              break;
            }
        }
      break;
      }
    default: break;
    }
  return 0;
}

int
sparp_gp_trav_restrict_by_simple_filters_gp_in (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  int fctr, first_glued_filt_idx;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      break;
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN;
    default: return 0;
    }
/* Note that glued filters do not participate in filter-to-equiv optimization, otherwise
select * where { graph <g1> { ?s1 ?p1 ?o1 } optional { graph <g2> { ?s2 ?p2 ?o2 } filter (?o1 = <const>) }}
become an equivalent of
select * where { graph <g1> { ?s1 ?p1 ?o1 . filter (?o1 = <const>) } optional { graph <g2> { ?s2 ?p2 ?o2 } filter (?o1 = <const>) }}
*/
  first_glued_filt_idx = BOX_ELEMENTS (curr->_.gp.filters) - curr->_.gp.glued_filters_count;
  for (fctr = BOX_ELEMENTS (curr->_.gp.filters); fctr--; /* no step */)
    { /* The descending order of fctr values is important -- note possible sparp_gp_detach_filter () */
      SPART *filt = curr->_.gp.filters[fctr];
      int ret;
      if (BOP_OR == SPART_TYPE (filt))
        {
          SPART *parent_gp = sts_this->sts_parent;
          int curr_gp_idx = sts_this->sts_ofs_of_curr_in_array;
          int optimization_status = sparp_optimize_BOP_OR_filter (sparp, parent_gp, curr, curr_gp_idx, fctr);
          if (2 == optimization_status)
            return SPAR_GPT_COMPLETED; /* The tree has changed, other optimizations should take place only on a next optimization round */
          continue;
        }
      if (fctr >= first_glued_filt_idx)
        continue;
      ret = sparp_filter_to_equiv (sparp, curr, filt);
      if (0 != ret)
        sparp_gp_detach_filter (sparp, curr, fctr, NULL);
    }
  return SPAR_GPT_ENV_PUSH;
}

int
sparp_gp_trav_restrict_by_simple_filters_expn_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_continue_gp_trav_in_sub (sparp, curr, common_env, 0);
  return 0;
}


void
sparp_restrict_by_simple_filters (sparp_t *sparp, SPART *req_top)
{
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    sparp_gp_trav_restrict_by_simple_filters_gp_in, NULL,
    NULL, NULL, sparp_gp_trav_restrict_by_simple_filters_expn_subq,
    NULL );
}


/* Composing equivs for common names without local variables.
\c trav_env_this points to dk_set_t of names.
\c common_env is not used. */

int
sparp_gp_trav_make_common_eqs_in (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      /*000 if (UNION_L == curr->_.gp.subtype)
        return 0;*/
      if (sts_this == sparp->sparp_stss+1)
        {
          sts_this[0].sts_env = ((dk_set_t *)common_env)[0];
          ((dk_set_t *)common_env)[0] = NULL;
        }
      else
        {
          if (NULL != ((dk_set_t *)common_env)[0])
            GPF_T;
          sts_this[0].sts_env = NULL;
        }
      return SPAR_GPT_ENV_PUSH;
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN;
    default: return 0;
    }
}

/*! For each duplicate name in \c local_vars the procedure adds new eq to \c curr.
\returns variables that can me propagated */
dk_set_t
sparp_create_eqs_for_dupe_locals (sparp_t *sparp, SPART *curr, dk_set_t *local_vars)
{
  int eq_ctr;
  caddr_t var_name;
  dk_set_t vars_to_propagate = NULL;
  while (NULL != local_vars[0])
    {
      var_name = (caddr_t)dk_set_pop (local_vars);
      if (-1 != dk_set_position_of_string (local_vars[0], var_name))
        {
          sparp_equiv_get (sparp, curr, (SPART *)var_name, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_GET_NAMESAKES);
        }
      else
        dk_set_push (&vars_to_propagate, var_name);
    }
  SPARP_FOREACH_GP_EQUIV(sparp,curr,eq_ctr,eq)
    {
      int varname_ctr;
      DO_BOX_FAST (caddr_t, vname, varname_ctr, eq->e_varnames)
        {
          if (SPART_VARNAME_IS_GLOB (vname))
            continue;
          if (-1 == dk_set_position_of_string (vars_to_propagate, vname))
	    dk_set_push (&vars_to_propagate, vname);
        }
      END_DO_BOX_FAST;
    }
  END_SPARP_FOREACH_GP_EQUIV;
  return vars_to_propagate;
}

int
sparp_gp_trav_make_common_eqs_out (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  dk_set_t *local_vars;
  dk_set_t vars_to_propagate;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP: break;
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN;
    default: return 0;
    }
  local_vars = (dk_set_t *)(&(sts_this[0].sts_env));
  vars_to_propagate = sparp_create_eqs_for_dupe_locals (sparp, curr, local_vars);
  if (sts_this == sparp->sparp_stss+1)
    {
      if (NULL != ((dk_set_t *)common_env)[0])
        GPF_T;
      ((dk_set_t *)common_env)[0] = vars_to_propagate;
    }
  else
    {
      dk_set_t *parent_vars = (dk_set_t *)(&(sts_this[-1].sts_env));
      while (NULL != vars_to_propagate)
        dk_set_push (parent_vars, dk_set_pop (&vars_to_propagate));
    }
  return 0;
}

int
sparp_gp_trav_make_common_eqs_expn_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  dk_set_t *parent_vars;
  dk_set_t vars_to_propagate = NULL;
  sparp_gp_trav_suspend (sparp);
  sparp_make_common_eqs (sparp, curr->_.gp.subquery);
  sparp_gp_trav_resume (sparp);
  if (sts_this == sparp->sparp_stss+1)
    parent_vars = ((dk_set_t *)common_env);
  else
    parent_vars = (dk_set_t *)(&(sts_this[-1].sts_env));
  vars_to_propagate = sparp_create_eqs_for_dupe_locals (sparp, curr, (dk_set_t *)common_env);
  while (NULL != vars_to_propagate)
    dk_set_push (parent_vars, dk_set_pop (&vars_to_propagate));
  return 0;
}

void
sparp_make_common_eqs (sparp_t *sparp, SPART *req_top)
{
  dk_set_t top_vars_to_propagate = NULL;
  sparp_trav_out_clauses (sparp, req_top, &top_vars_to_propagate,
    sparp_gp_trav_make_common_eqs_in, sparp_gp_trav_make_common_eqs_out,
    NULL, NULL, sparp_gp_trav_make_common_eqs_expn_subq,
    NULL );
  sparp_gp_trav_top_pattern (sparp, req_top, &top_vars_to_propagate,
    sparp_gp_trav_make_common_eqs_in, sparp_gp_trav_make_common_eqs_out,
    NULL, NULL, sparp_gp_trav_make_common_eqs_expn_subq,
    NULL );
  while (NULL != top_vars_to_propagate)
   dk_set_pop (&top_vars_to_propagate);
}

/* Composing aliases.
\c trav_env_this points to the innermost graph pattern.
\c common_env is used in sparp_gp_trav_make_retval_aliases to pass vector of query return variables. */

void
sparp_gp_add_chain_aliases (sparp_t *sparp, SPART *inner_var, sparp_equiv_t *inner_eq, sparp_trav_state_t *sts_this, SPART *top_gp)
{
  sparp_trav_state_t *sts_iter = sts_this;
  sparp_equiv_t *curr_eq = inner_eq;
#ifdef DEBUG
  if (NULL == curr_eq)
    spar_internal_error (sparp, "sparp_" "gp_add_chain_aliases () has NULL eq for inner_var");
  if (curr_eq->e_gp != sts_iter[0].sts_env)
    spar_internal_error (sparp, "sparp_" "gp_add_chain_aliases () has eq for inner_var not equal to sts_iter[0].sts_env");
#endif
  for (;;)
    {
      sparp_equiv_t *parent_eq;
      SPART *parent_gp = (SPART *)(sts_iter[-1].sts_env);
      if (NULL == parent_gp)
        break;
      parent_eq = sparp_equiv_get (sparp, parent_gp, inner_var, SPARP_EQUIV_GET_NAMESAKES | SPARP_EQUIV_INS_CLASS);
      sparp_equiv_connect_outer_to_inner (sparp, parent_eq, curr_eq, 1);
      if (parent_gp == top_gp)
        break;
      curr_eq = parent_eq;
      sts_iter--;
    }
}

int
sparp_gp_trav_make_retval_aliases (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  SPART **retvars = (SPART **)common_env;
  int retvar_ctr;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP: break;
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN;
    default: return 0;
    }
  sts_this[0].sts_env = curr;
  for (retvar_ctr = BOX_ELEMENTS (retvars); retvar_ctr--; /* no step */)
    {
      SPART *curr_retvar = retvars[retvar_ctr];
      sparp_equiv_t *curr_eq;
      caddr_t curr_varname = spar_var_name_of_ret_column (curr_retvar);
      if (NULL == curr_varname)
        continue;
      curr_eq = sparp_equiv_get (sparp, curr, (SPART *)curr_varname, SPARP_EQUIV_GET_NAMESAKES);
      if (NULL != curr_eq)
        {
          if (SPAR_ALIAS == SPART_TYPE(curr_retvar))
            curr_retvar = curr_retvar->_.alias.arg;
          sparp_gp_add_chain_aliases (sparp, curr_retvar, curr_eq, sts_this, NULL);
        }
    }
  return SPAR_GPT_ENV_PUSH;
}

int
sparp_gp_trav_make_common_aliases_gp_in (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  int eq_ctr;
  sparp_trav_state_t *outer_gp_sts;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP: break;
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN;
    default: return 0;
    }
  sts_this[0].sts_env = curr;
  SPARP_FOREACH_GP_EQUIV(sparp,curr,eq_ctr,eq)
    {
#if 0
      int var_ctr;
      for (var_ctr = eq->e_var_count; var_ctr--; /* no step */)
        {
	  SPART *var = eq->e_vars[var_ctr];
          for (outer_gp_sts = sparp->sparp_stss+1; outer_gp_sts < sts_this; outer_gp_sts++)
            {
              SPART *outer_gp = outer_gp_sts->sts_env;
	      sparp_equiv_t *topmost_eq = sparp_equiv_get (sparp, outer_gp, var, SPARP_EQUIV_GET_NAMESAKES);
	      if (NULL != topmost_eq)
		{
		  sparp_gp_add_chain_aliases (sparp, var, eq, sts_this, outer_gp);
		  break;
		}
            }
        }
#else
      int varname_ctr;
      DO_BOX_FAST (caddr_t, vname, varname_ctr, eq->e_varnames)
        {
          for (outer_gp_sts = sparp->sparp_stss+1; outer_gp_sts < sts_this; outer_gp_sts++)
            {
              SPART *outer_gp = (SPART *)(outer_gp_sts->sts_env);
	      sparp_equiv_t *topmost_eq = sparp_equiv_get (sparp, outer_gp, (SPART *)vname, SPARP_EQUIV_GET_NAMESAKES);
	      if (NULL != topmost_eq)
		{
		  sparp_gp_add_chain_aliases (sparp, (SPART *) vname, eq, sts_this, outer_gp);
		  break;
		}
            }
        }
      END_DO_BOX_FAST;
#endif
    } END_SPARP_FOREACH_GP_EQUIV;
  return SPAR_GPT_ENV_PUSH;
}

int
sparp_gp_trav_make_aliases_expn_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_gp_trav_suspend (sparp);
  sparp_make_aliases (sparp, curr->_.gp.subquery);
  sparp_gp_trav_resume (sparp);
  return 0;
}

int
sparp_gp_trav_remove_unused_aliases (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  int eq_ctr;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP: break;
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN;
    default: return 0;
    }
  sts_this[0].sts_env = curr;
  SPARP_REVFOREACH_GP_EQUIV(sparp,curr,eq_ctr,eq)
    {
      int sub_ctr;
      if (
        (0 != eq->e_const_reads) ||
        (0 != eq->e_gspo_uses) ||
        (0 != eq->e_subquery_uses) ||
        (0 != BOX_ELEMENTS_INT_0 (eq->e_receiver_idxs)) ||
        (1 < (eq->e_nested_bindings + eq->e_optional_reads)) ||
        (0 != eq->e_var_count) ||
        (SPART_VARR_EXPORTED & eq->e_rvr.rvrRestrictions) ||
        eq->e_replaces_filter )
	continue; /* Do not remove if in use */
      for (sub_ctr = BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs); sub_ctr--; /* no step */)
        {
          sparp_equiv_t *sub_eq = SPARP_EQUIV(sparp, eq->e_subvalue_idxs[sub_ctr]);
          sparp_equiv_disconnect_outer_from_inner (sparp, eq, sub_eq);
        }
      sparp_equiv_remove (sparp, eq);
    }
  END_SPARP_REVFOREACH_GP_EQUIV;
  return SPAR_GPT_ENV_PUSH;
}

void
sparp_make_aliases (sparp_t *sparp, SPART *req_top)
{
  SPART **retvars = req_top->_.req_top.retvals;
  /*int retvar_ctr;*/
  sparp_gp_trav_top_pattern (sparp, req_top, retvars,
    sparp_gp_trav_make_retval_aliases, sparp_gp_trav_cu_out_triples_1,
    NULL, NULL, NULL,
    NULL );
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    sparp_gp_trav_make_common_aliases_gp_in, sparp_gp_trav_cu_out_triples_1_merge_recvs,
    NULL, NULL, sparp_gp_trav_make_aliases_expn_subq,
    NULL );
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    sparp_gp_trav_remove_unused_aliases, sparp_gp_trav_cu_out_triples_1,
    NULL, NULL, NULL,
    NULL );
  sparp_trav_out_clauses (sparp, req_top, NULL,
    NULL, NULL /* was sparp_gp_trav_cu_out_triples_1 */,
    NULL, NULL, sparp_gp_trav_make_aliases_expn_subq,
    NULL );
}

sparp_equiv_t *
sparp_find_external_namesake_eq_of_varname (sparp_t *sparp, caddr_t varname, dk_set_t parent_gps)
{
  DO_SET (SPART *, parent, &parent_gps)
    {
      sparp_equiv_t *parent_eq = sparp_equiv_get (sparp, parent, (SPART *)varname, SPARP_EQUIV_GET_NAMESAKES);
      if ((NULL != parent_eq) &&
        ((0 < parent_eq->e_gspo_uses) ||
          (0 < parent_eq->e_subquery_uses) ||
          (0 < parent_eq->e_nested_bindings) ) )
        {
      /*
          if ((SPART_BAD_EQUIV_IDX != eq->e_external_src_idx) &&
            (parent_eq->e_own_idx != eq->e_external_src_idx) &&
            !(parent_eq->e_rvr.rvrRestrictions & SPART_VARR_EXTERNAL) )
            spar_internal_error (sparp, "sparp_" "gp_trav_label_external_vars_gp_in (): mismatch in origin of external");
      */
          return parent_eq;
        }
    }
  END_DO_SET ()
  return NULL;
}

int
sparp_gp_trav_label_external_vars_gp_in (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  int eqctr;
  sparp_label_external_vars_env_t *sleve;
  if (SPAR_GP != SPART_TYPE (curr))
    return 0;
  sleve = (sparp_label_external_vars_env_t *)common_env;
  if (NULL == sleve->parent_gps_for_table_subq)
    return SPAR_GPT_ENV_PUSH;
  if (SELECT_L == curr->_.gp.subtype)
    {
      sparp_label_external_vars_env_t tmp_sleve;
      tmp_sleve.parent_gps_for_var_search = tmp_sleve.parent_gps_for_table_subq = sleve->parent_gps_for_table_subq;
      sparp_gp_trav_suspend (sparp);
      sparp_label_external_vars (sparp, curr->_.gp.subquery, &tmp_sleve);
      sparp_gp_trav_resume (sparp);
    }
  SPARP_FOREACH_GP_EQUIV (sparp, curr, eqctr, eq)
    {
      int varnamectr, varctr;
      DO_BOX_FAST_REV (caddr_t, varname, varnamectr, eq->e_varnames)
        {
          sparp_equiv_t *external_namesake_eq = sparp_find_external_namesake_eq_of_varname (sparp, varname, sleve->parent_gps_for_var_search);
          if (NULL == external_namesake_eq)
            continue;
          if (external_namesake_eq->e_own_idx != eq->e_external_src_idx)
            sparp_equiv_connect_param_to_external (sparp, eq, external_namesake_eq);
          eq->e_rvr.rvrRestrictions |= SPART_VARR_EXTERNAL;
          for (varctr = eq->e_var_count; varctr--; /* no step */)
            {
              SPART *var = eq->e_vars[varctr];
              if (var->_.var.vname == varname)
                var->_.var.rvr.rvrRestrictions |= SPART_VARR_EXTERNAL;
            }
        }
      END_DO_BOX_FAST_REV;
    }
  END_SPARP_FOREACH_GP_EQUIV;
  return SPAR_GPT_ENV_PUSH;
}

/* This makes same labeling as \c sparp_gp_trav_label_external_vars_gp_in() but should be used for retvals.
Note that it label retval vals whereas sparp_gp_trav_label_external_vars_gp_in() does not. */
int
sparp_gp_trav_label_external_vars_expn_in (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  if (SPAR_IS_BLANK_OR_VAR (curr))
    {
      sparp_label_external_vars_env_t *sleve = (sparp_label_external_vars_env_t *)common_env;
      sparp_equiv_t *external_namesake_eq = sparp_find_external_namesake_eq_of_varname (sparp, curr->_.var.vname, sleve->parent_gps_for_var_search);
      if (NULL != external_namesake_eq)
        {
          sparp_equiv_t *eq = SPARP_EQUIV (sparp, curr->_.var.equiv_idx);
          if (external_namesake_eq->e_own_idx < eq->e_external_src_idx)
            sparp_equiv_connect_param_to_external (sparp, eq, external_namesake_eq);
          eq->e_rvr.rvrRestrictions |= SPART_VARR_EXTERNAL;
          curr->_.var.rvr.rvrRestrictions |= SPART_VARR_EXTERNAL;
        }
    }
  return 0;
}

int
sparp_gp_trav_label_external_vars_expn_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_label_external_vars_env_t *sleve = (sparp_label_external_vars_env_t *)common_env;
  SPART *anc_gp = sts_this->sts_ancestor_gp;
  s_node_t tmp_stack;
  sparp_label_external_vars_env_t tmp_sleve;
  tmp_stack.data = anc_gp;
  tmp_stack.next = sleve->parent_gps_for_var_search;
  tmp_sleve.parent_gps_for_var_search = tmp_sleve.parent_gps_for_table_subq = &tmp_stack;
  sparp_gp_trav_suspend (sparp);
  sparp_label_external_vars (sparp, curr->_.gp.subquery, &tmp_sleve);
  sparp_gp_trav_resume (sparp);
  return 0;
}

void
sparp_label_external_vars (sparp_t *sparp, SPART *req_top, sparp_label_external_vars_env_t *sleve)
{
  sparp_label_external_vars_env_t tmp_sleve;
  if (NULL == sleve)
    {
      tmp_sleve.parent_gps_for_var_search = tmp_sleve.parent_gps_for_table_subq = NULL;
      sleve = &tmp_sleve;
    }
  sparp_trav_out_clauses (sparp, req_top, sleve,
    NULL, NULL,
    ((NULL != sleve->parent_gps_for_var_search) ?
      sparp_gp_trav_label_external_vars_expn_in : NULL ),
    NULL,
    sparp_gp_trav_label_external_vars_expn_subq,
    NULL );
  sparp_gp_trav_top_pattern (sparp, req_top, sleve,
    sparp_gp_trav_label_external_vars_gp_in, NULL,
    NULL, NULL, sparp_gp_trav_label_external_vars_expn_subq,
    NULL );
}

void
sparp_remove_totally_useless_equivs (sparp_t *sparp)
{
  int equiv_first_idx, equiv_ctr, recv_ctr, dirty;

again:
  dirty = 0;
  equiv_first_idx = sparp->sparp_first_equiv_idx;
  for (equiv_ctr = sparp->sparp_sg->sg_equiv_count; equiv_first_idx < equiv_ctr--; /*no step*/)
    {
      sparp_equiv_t *eq = SPARP_EQUIV (sparp, equiv_ctr);
      if (NULL == eq)
        continue;
      if (SPARP_EQ_IS_ASSIGNED_LOCALLY(eq) || (0 != eq->e_const_reads) || (0 != eq->e_optional_reads) || eq->e_replaces_filter || (0 != BOX_ELEMENTS_0 (eq->e_subvalue_idxs)))
        continue;
      DO_BOX_FAST_REV (ptrlong, recv_idx, recv_ctr, eq->e_receiver_idxs)
        {
          sparp_equiv_disconnect_outer_from_inner (sparp, SPARP_EQUIV (sparp, recv_idx), eq);
        }
      END_DO_BOX_FAST_REV;
      if (WHERE_L != eq->e_gp->_.gp.subtype)
        eq->e_rvr.rvrRestrictions &= ~SPART_VARR_EXPORTED;
      else if (eq->e_rvr.rvrRestrictions & SPART_VARR_EXPORTED)
        continue;
      sparp_equiv_remove (sparp, eq);
      dirty = 1;
    }
  if (dirty)
    goto again; /* see above */
}

int
sparp_gp_trav_remove_redundant_connections (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_gp_trav_suspend (sparp);
  sparp_remove_redundant_connections (sparp, curr->_.gp.subquery, (ptrlong)common_env);
  sparp_gp_trav_resume (sparp);
  return 0;
}

void
sparp_remove_redundant_connections (sparp_t *sparp, SPART *req_top, ptrlong flags)
{
  sparp_equiv_t **equivs = sparp->sparp_sg->sg_equivs;
  int eq_first_idx, eq_ctr;
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    sparp_gp_trav_remove_unused_aliases, sparp_gp_trav_cu_out_triples_1,
    NULL, NULL, sparp_gp_trav_remove_redundant_connections,
    NULL );
  sparp_trav_out_clauses (sparp, req_top, NULL,
    NULL, NULL /* was sparp_gp_trav_cu_out_triples_1*/,
    NULL, NULL, sparp_gp_trav_remove_redundant_connections,
    NULL );
  if (!(SPARP_UNLINK_IF_ASSIGNED_EXTERNALLY & flags))
    goto skip_ext_ext_unlinks; /* see below */
  eq_first_idx = sparp->sparp_first_equiv_idx;
  for (eq_ctr = sparp->sparp_sg->sg_equiv_count; eq_first_idx < eq_ctr--; /*no step*/)
    {
      sparp_equiv_t *eq = equivs[eq_ctr];
      int sub_ctr;
      if (NULL == eq)
        continue;
      if (!SPARP_EQ_IS_ASSIGNED_EXTERNALLY (eq))
        continue;
      for (sub_ctr = BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs); sub_ctr--; /*no step*/)
        {
          int can_unlink = 0;
          sparp_equiv_t *sub_eq = equivs[eq->e_subvalue_idxs[sub_ctr]];
          if ((OPTIONAL_L == sub_eq->e_gp->_.gp.subtype) && !SPARP_EQ_IS_ASSIGNED_LOCALLY(sub_eq))
            continue; /* To avoid disconnect of loj filter in SELECT * { ?x <p> ?v . OPTIONAL { ?y <q> ?w . FILTER (?v=2) }} */
          if (!SPARP_EQ_IS_ASSIGNED_EXTERNALLY(sub_eq))
            continue;
          if (
            SPARP_EQ_IS_ASSIGNED_BY_CONTEXT(eq) &&
            SPARP_EQ_IS_ASSIGNED_BY_CONTEXT(sub_eq) &&
            (1 == BOX_ELEMENTS (eq->e_varnames)) &&
            (1 == BOX_ELEMENTS (sub_eq->e_varnames)) &&
            !strcmp (eq->e_varnames[0], sub_eq->e_varnames[0]) )
            can_unlink = 1;
          else if (sparp_equivs_have_same_fixedvalue (sparp, eq, sub_eq) && (0 != eq->e_gspo_uses))
            can_unlink = 1;
          if (can_unlink)
            sparp_equiv_disconnect_outer_from_inner (sparp, eq, sub_eq);
        }
    }

skip_ext_ext_unlinks:
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    sparp_gp_trav_remove_unused_aliases, NULL,
    NULL, NULL, NULL,
    NULL );
}

/* Copying restrictions from equivalences to variables */

void
sparp_restr_of_select_eq_from_connected_subvalues (sparp_t *sparp, sparp_equiv_t *eq)
{
  SPART *gp = eq->e_gp;
  caddr_t vname = eq->e_varnames[0];
  SPART *sub_expn = sparp_find_subexpn_in_retlist (sparp, vname, gp->_.gp.subquery->_.req_top./*orig_*/retvals, 0);
  if (NULL != sub_expn)
    {
      if (SPAR_IS_BLANK_OR_VAR(sub_expn))
        {
          sparp_equiv_t *eq_sub = sparp_equiv_get (sparp, gp->_.gp.subquery->_.req_top.pattern, sub_expn, 0);
          sparp_equiv_tighten (sparp, eq, &(eq_sub->e_rvr), ~(SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL));
        }
      else
        {
          ptrlong restr_bits = sparp_restr_bits_of_expn (sparp, sub_expn);
          eq->e_rvr.rvrRestrictions |= restr_bits & (
            SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_IS_BLANK |
            SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL |
            SPART_VARR_NOT_NULL | SPART_VARR_ALWAYS_NULL );
        }
    }
}

void
sparp_restr_of_union_eq_from_connected_subvalues (sparp_t *sparp, sparp_equiv_t *eq)
{
  sparp_equiv_t **equivs = sparp->sparp_sg->sg_equivs;
  int sub_ctr, varname_ctr;
  int nice_sub_count = 0;
  ptrlong nice_sub_chksum = 0;
  int memb_count = BOX_ELEMENTS (eq->e_gp->_.gp.members);
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
        {
          nice_sub_chksum ^= (ptrlong)(sub_gp);
          nice_sub_count++; /* Conflict is nice because it will be removed soon */
          continue;
        }
      if (!SPARP_EQ_IS_ASSIGNED_LOCALLY (sub_eq))
        continue;
      sparp_rvr_loose (sparp, &acc, &(sub_eq->e_rvr), ~0);
      if ((0 == sub_gp->_.gp.subtype) & (sub_eq->e_rvr.rvrRestrictions & SPART_VARR_NOT_NULL))
        {
          nice_sub_chksum ^= (ptrlong)(sub_gp);
          nice_sub_count++;
        }
    }
  END_DO_BOX_FAST;
  if (nice_sub_count == memb_count)
    {
      int memb_ctr;
      for (memb_ctr = memb_count; memb_ctr--; /* no step */)
        nice_sub_chksum ^= (ptrlong)(eq->e_gp->_.gp.members[memb_ctr]);
    }
  else
    nice_sub_chksum = -1;
  if ((0 != nice_sub_chksum) || (0 == nice_sub_count))
    acc.rvrRestrictions &= ~SPART_VARR_NOT_NULL;
#ifdef DEBUG
  if ((acc.rvrRestrictions & SPART_VARR_NOT_NULL) && (!(eq->e_rvr.rvrRestrictions & SPART_VARR_NOT_NULL)))
    dbg_printf (("sparp_" "restr_of_union_eq_from_connected_subvalues(): strong optimization on ?%s (was 0x%x) by 0x%x acc", eq->e_varnames[0],
      (unsigned)(eq->e_rvr.rvrRestrictions), (unsigned)(acc.rvrRestrictions) ) );
#endif
  sparp_equiv_tighten (sparp, eq, &acc, ~(SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL));
  if (NULL == common_vars)
    eq->e_rvr.rvrRestrictions &= ~(SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL);
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
sparp_restr_of_join_eq_from_connected_subvalue (sparp_t *sparp, sparp_equiv_t *eq, sparp_equiv_t *sub_eq)
{
  SPART *sub_gp = sub_eq->e_gp;
  if (OPTIONAL_L == sub_gp->_.gp.subtype)
    {
      if ((1 == eq->e_nested_bindings) && (0 == eq->e_gspo_uses) && (0 == eq->e_subquery_uses) &&
        (0 == eq->e_replaces_filter) && SPARP_EQ_IS_ASSIGNED_LOCALLY (sub_eq) &&
        !(sub_eq->e_rvr.rvrRestrictions & (SPART_VARR_CONFLICT | SPART_VARR_ALWAYS_NULL)) )
        sparp_equiv_tighten (sparp, eq, &(sub_eq->e_rvr), ~(SPART_VARR_NOT_NULL | SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL));
    }
  else
    if (SPARP_EQ_IS_ASSIGNED_LOCALLY (sub_eq))
      sparp_equiv_tighten (sparp, eq, &(sub_eq->e_rvr), ~(SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL));
}

void
sparp_restr_of_join_eq_from_connected_subvalues (sparp_t *sparp, sparp_equiv_t *eq)
{
  sparp_equiv_t **equivs = sparp->sparp_sg->sg_equivs;
  int sub_ctr;
  DO_BOX_FAST (ptrlong, sub_eq_idx, sub_ctr, eq->e_subvalue_idxs)
    {
      sparp_equiv_t *sub_eq = equivs[sub_eq_idx];
      sparp_restr_of_join_eq_from_connected_subvalue (sparp, eq, sub_eq);
    }
  END_DO_BOX_FAST;
}

void
sparp_find_best_join_eq_for_optional (sparp_t *sparp, SPART *parent, int pos_of_curr_memb, sparp_equiv_t *eq, sparp_equiv_t **ret_parent_eq, SPART **ret_tree_in_parent, SPART **ret_source_in_parent)
{
  SPART *prev = NULL;
  int varname_ctr, ctr;
  int pos_of_prev_memb;
  int good_is_gp = 0;
  caddr_t good_varname = NULL;
  SPART *good_prev = NULL;
  SPART *good_prev_var = NULL;
  sparp_equiv_t *good_parent_eq = NULL;
  sparp_equiv_t *good_prev_eq = NULL;
#ifndef NDEBUG
  if ((SPAR_GP != SPART_TYPE (parent)) || (BOX_ELEMENTS (parent->_.gp.members) <= pos_of_curr_memb))
    spar_internal_error (sparp, "sparp_" "find_best_join_eq_for_optional(): bad call");
#endif
  ret_parent_eq[0] = NULL;
  ret_tree_in_parent[0] = NULL;
  ret_source_in_parent[0] = NULL;
  if (0 == pos_of_curr_memb)
    return;
  for (pos_of_prev_memb = 0; pos_of_prev_memb < pos_of_curr_memb; pos_of_prev_memb++)
    {
      prev = parent->_.gp.members[pos_of_prev_memb];
      if (SPAR_GP == prev->type)
        {
          DO_BOX_FAST (caddr_t, varname, varname_ctr, eq->e_varnames)
            {
              sparp_equiv_t *parent_eq, *prev_eq;
              parent_eq = sparp_equiv_get_ro (sparp->sparp_sg->sg_equivs, sparp->sparp_sg->sg_equiv_count, parent, (SPART *)varname, SPARP_EQUIV_GET_NAMESAKES);
              if (NULL == parent_eq)
                continue;
              prev_eq = sparp_equiv_get_ro (sparp->sparp_sg->sg_equivs, sparp->sparp_sg->sg_equiv_count, prev, (SPART *)varname, SPARP_EQUIV_GET_NAMESAKES);
              if (NULL == prev_eq)
                continue;
              good_prev = prev;
              good_varname = varname;
              good_parent_eq = parent_eq;
              good_prev_var = NULL;
              good_prev_eq = prev_eq;
              good_is_gp = 1;
              if (SPART_VARR_NOT_NULL & prev_eq->e_rvr.rvrRestrictions)
                goto good_found; /* see below */
            }
          END_DO_BOX_FAST;
        }
      else
        {
          DO_BOX_FAST (caddr_t, varname, varname_ctr, eq->e_varnames)
            {
              sparp_equiv_t *parent_eq;
              parent_eq = sparp_equiv_get_ro (sparp->sparp_sg->sg_equivs, sparp->sparp_sg->sg_equiv_count, parent, (SPART *)varname, SPARP_EQUIV_GET_NAMESAKES);
              if (NULL == parent_eq)
                continue;
              for (ctr = parent_eq->e_var_count; ctr--; /* no step */)
                {
                  SPART *prev_var = parent_eq->e_vars[ctr];
                  if (NULL == prev_var->_.var.tabid)
                    continue;
                  if (strcmp (prev_var->_.var.tabid, prev->_.triple.tabid))
                    continue;
                  good_prev = prev;
                  good_varname = NULL;
                  good_parent_eq = parent_eq;
                  good_prev_var = prev_var;
                  good_is_gp = 0;
                  if (SPART_VARR_NOT_NULL & prev_var->_.var.rvr.rvrRestrictions)
                    goto good_found; /* see below */
                }
            }
          END_DO_BOX_FAST;
        }
    }
good_found:
  ret_parent_eq[0] = good_parent_eq;
  ret_source_in_parent[0] = good_prev;
  if (good_is_gp)
    {
      SPART *var_rv = (SPART *)t_alloc_box (sizeof (SPART), DV_ARRAY_OF_POINTER);
      memset (var_rv, 0, sizeof (SPART));
      var_rv->type = SPAR_RETVAL;
      var_rv->_.retval.equiv_idx = good_prev_eq->e_own_idx;
      var_rv->_.retval.gp = prev;
      memcpy (&(var_rv->_.retval.rvr), &(good_prev_eq->e_rvr), sizeof (rdf_val_range_t));
      var_rv->_.retval.selid = prev->_.gp.selid;
      var_rv->_.retval.vname = good_varname;
      ret_tree_in_parent[0] = var_rv;
    }
  else
    {
      ret_tree_in_parent[0] = good_prev_var;
    }
}

int
sparp_gp_trav_eq_restr_from_connected_subvalues_gp_out (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  int eq_ctr;
  if (SPAR_GP != SPART_TYPE(curr))
    return 0;
  SPARP_FOREACH_GP_EQUIV(sparp,curr,eq_ctr,eq)
    {
      switch (curr->_.gp.subtype)
        {
        case SELECT_L: sparp_restr_of_select_eq_from_connected_subvalues (sparp, eq); break;
        case UNION_L: case SPAR_UNION_WO_ALL: sparp_restr_of_union_eq_from_connected_subvalues (sparp, eq); break;
        default: sparp_restr_of_join_eq_from_connected_subvalues (sparp, eq); break;
        }
      if (SPARP_EQ_IS_ASSIGNED_LOCALLY(eq))
        continue;
      if (SPARP_EQ_IS_ASSIGNED_BY_CONTEXT(eq))
        continue;
      if (OPTIONAL_L == curr->_.gp.subtype)
        {
          int recv_ctr;
          sparp_equiv_t *good_loj_for_filter_var = 0;
          DO_BOX_FAST_REV (ptrlong, recv_idx, recv_ctr, eq->e_receiver_idxs)
            {
              sparp_equiv_t *recv_eq = SPARP_EQUIV (sparp, recv_idx);
              if ((SPARP_EQ_IS_ASSIGNED_LOCALLY(recv_eq) || SPARP_EQ_IS_ASSIGNED_BY_CONTEXT(recv_eq)) &&
                !(recv_eq->e_rvr.rvrRestrictions & SPART_VARR_ALWAYS_NULL) )
                {
                  good_loj_for_filter_var = recv_eq;
                  break;
                }
            }
          END_DO_BOX_FAST_REV;
          if (NULL != good_loj_for_filter_var)
            continue;
        }
/*      if ((eq->e_replaces_filter) && (OPTIONAL_L == curr->_.gp.subtype))
        continue;*/
      if (eq->e_rvr.rvrRestrictions & SPART_VARR_NOT_NULL)
        {
          SPARP_DEBUG_WEIRD(sparp,"conflict");
          eq->e_rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
        }
      else
        eq->e_rvr.rvrRestrictions |= SPART_VARR_ALWAYS_NULL;
    } END_SPARP_FOREACH_GP_EQUIV;
  return 0;
}

int
sparp_gp_trav_eq_restr_from_connected_subvalues_expn_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_continue_gp_trav_in_sub (sparp, curr, common_env, 0);
  return 0;
}

int
sparp_gp_trav_eq_restr_from_connected_receivers_gp_in (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_equiv_t **equivs = sparp->sparp_sg->sg_equivs;
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
      int var_ctr;
      for (var_ctr = eq->e_var_count; var_ctr--; /*no step*/)
       {
         SPART *var = eq->e_vars[var_ctr];
         sparp_trav_state_t *sts_iter;
         int changeable =
           ( SPART_VARR_CONFLICT | SPART_VARR_NOT_NULL |
             SPART_VARR_IS_BLANK | SPART_VARR_IS_IRI |
             SPART_VARR_IS_LIT | SPART_VARR_IS_REF |
             SPART_VARR_TYPED | SPART_VARR_FIXED |
             SPART_VARR_SPRINTFF | SPART_VARR_LONG_EQ_SQL );
         if ((NULL == var->_.var.tabid) && (VALUES_L != curr->_.gp.subtype))
           continue;
         sparp_rvr_tighten (sparp, &(var->_.var.rvr), &(eq->e_rvr), changeable);
         for (sts_iter = sts_this;
           (NULL != sts_iter->sts_parent) &&
           (SPAR_GP == SPART_TYPE (sts_iter->sts_parent)) &&
           (SELECT_L != sts_iter->sts_parent->_.gp.subtype);
           sts_iter-- )
           {
             sparp_equiv_t *outer_eq = sparp_equiv_get_ro (equivs, sparp->sparp_sg->sg_equiv_count, sts_iter->sts_parent, (SPART *)(var->_.var.vname), SPARP_EQUIV_GET_NAMESAKES);
             if (NULL != outer_eq)
               sparp_rvr_tighten (sparp, &(var->_.var.rvr), &(outer_eq->e_rvr), changeable);
           }
       }
    } END_SPARP_FOREACH_GP_EQUIV;
  if (VALUES_L == curr->_.gp.subtype)
    {
      SPART *binv = curr->_.gp.subquery;
      SPART *parent_gp = (((NULL != sts_this->sts_parent) && (SPAR_GP == SPART_TYPE (sts_this->sts_parent))) ? sts_this->sts_parent : NULL);
      spar_shorten_binv_dataset (sparp, binv);
      if ((NULL != parent_gp) && (1 == BOX_ELEMENTS (binv->_.binv.vars)) && (0 == binv->_.binv.counters_of_unbound[0]) &&
        spar_binv_is_convertible_to_filter (sparp, parent_gp, curr, binv) )
        {
          spar_refresh_binv_var_rvrs (sparp, binv);
          spar_binv_to_filter (sparp, parent_gp, curr, binv);
        }
      else
        spar_refresh_binv_var_rvrs (sparp, binv);
    }
  return SPAR_GPT_ENV_PUSH;
}

int
sparp_gp_trav_eq_restr_from_connected_receivers_expn_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_continue_gp_trav_in_sub (sparp, curr, common_env, 0);
  return 0;
}

void
sparp_eq_restr_from_connected (sparp_t *sparp, SPART *req_top)
{
  /*sparp_env_t *env = sparp->sparp_env;*/
  SPART *binv = req_top->_.req_top.binv;
  if (NULL != binv)
    {
      int varctr, varcount = BOX_ELEMENTS (binv->_.binv.vars);
      SPART **retlist = req_top->_.req_top.retvals;
      for (varctr = varcount; varctr--; /* no step */)
        {
          SPART *var, *ret_expn = NULL;
          int retctr, ret_expn_type;
          if (binv->_.binv.counters_of_unbound[varctr])
            continue;
          var = binv->_.binv.vars[varctr];
          for (retctr = BOX_ELEMENTS (retlist); retctr--; /* no step */)
            {
              SPART *candidate = retlist[retctr];
              ret_expn_type = SPART_TYPE (candidate);
              if (SPAR_VARIABLE == ret_expn_type)
                {
                  if (strcmp (candidate->_.var.vname, var->_.var.vname))
                    continue;
                  ret_expn = candidate;
                  break;
                }
              if (SPAR_ALIAS == ret_expn_type)
                {
                  if (strcmp (candidate->_.alias.aname, var->_.var.vname))
                    continue;
                  ret_expn = candidate->_.alias.arg;
                  ret_expn_type = SPART_TYPE (ret_expn);
                  break;
                }
            }
          if (NULL == ret_expn)
            {
              if (sparp->sparp_sg->sg_signal_void_variables)
                spar_error (sparp, "Variable name '%.100s' is used in the BINDINGS clause but not in the query result set", var->_.var.vname);
              SPARP_DEBUG_WEIRD(sparp,"conflict");
              var->_.var.rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
            }
          else
            {
              if (SPAR_VARIABLE == ret_expn_type)
                {
                  sparp_equiv_t *ret_orig_eq = SPARP_EQUIV (sparp, ret_expn->_.var.equiv_idx);
                  sparp_rvr_tighten (sparp, &(var->_.var.rvr), &(ret_orig_eq->e_rvr), ~(SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL));
                  if (!(sparp_req_top_has_limofs (req_top) && (NULL != req_top->_.req_top.order)))
                    sparp_equiv_tighten (sparp, ret_orig_eq, &(var->_.var.rvr), ~(SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL));
                }
              else
                {
                  ptrlong restr = sparp_restr_bits_of_expn (sparp, ret_expn);
                  sparp_rvr_add_restrictions (sparp, &(var->_.var.rvr), restr & ~(SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL));
                }
            }
        }
      spar_shorten_binv_dataset (sparp, binv);
      spar_refresh_binv_var_rvrs (sparp, binv);
    }
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    NULL, sparp_gp_trav_eq_restr_from_connected_subvalues_gp_out,
    NULL, NULL, sparp_gp_trav_eq_restr_from_connected_subvalues_expn_subq,
    NULL );
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    sparp_gp_trav_eq_restr_from_connected_receivers_gp_in, NULL,
    NULL, NULL, sparp_gp_trav_eq_restr_from_connected_receivers_expn_subq,
    NULL );
}

/* Copying restrictions from equivalences to variables */

int
sparp_gp_trav_eq_restr_to_vars_gp_in (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
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
#if 0 /* It's not clear for me what to do with externals that have no external namespakes */
	  sparp_rvr_tighten (sparp, &(var->_.var.rvr), &(eq->e_rvr), ~0 /* not (SPART_VARR_EXTERNAL | SPART_VARR_GLOBAL)*/);
#else
	  sparp_rvr_tighten (sparp, &(var->_.var.rvr), &(eq->e_rvr), ~(SPART_VARR_EXTERNAL | SPART_VARR_GLOBAL));
#endif
	  var->_.var.equiv_idx = eq->e_own_idx;
	}
    } END_SPARP_FOREACH_GP_EQUIV;
  return 0;
}

int
sparp_gp_trav_eq_restr_to_vars_expn_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_continue_gp_trav_in_sub (sparp, curr, common_env, 0);
  return 0;
}

void
sparp_eq_restr_to_vars (sparp_t *sparp, SPART *req_top)
{
  /*sparp_env_t *env = sparp->sparp_env;*/
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    sparp_gp_trav_eq_restr_to_vars_gp_in, NULL,
    NULL, NULL, sparp_gp_trav_eq_restr_to_vars_expn_subq,
    NULL );
}

#ifdef DEBUG

static int
sparp_gp_trav_equiv_audit_inner_vars (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  SPART *gp = sts_this->sts_ancestor_gp;
  int eq_ctr;
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      SPARP_FOREACH_GP_EQUIV (sparp, curr, eq_ctr, eq)
        {
          int recv_ctr;
          if (NULL == eq)
            {
              spar_audit_error (sparp, "sparp_" "gp_trav_equiv_audit_inner_vars(): gp with deleted eq in use");
              continue; /* spar_audit_error can continue without a signal if runs inside sparp_internal_error in DEBUG mode. */
            }
          DO_BOX_FAST (ptrlong, recv_idx, recv_ctr, eq->e_receiver_idxs)
            {
              sparp_equiv_t *recv = SPARP_EQUIV (sparp, recv_idx);
              if (recv->e_gp != gp)
                spar_audit_error (sparp, "sparp_" "gp_trav_equiv_audit_inner_vars(): gp of recv eq is not parent of gp of curr eq, gp %s eq %# for %s", gp->_.gp.selid, eq->e_own_idx, eq->e_varnames[0]);
            }
          END_DO_BOX_FAST;
        }
      END_SPARP_FOREACH_GP_EQUIV;
      if (SPAR_REQ_TOP == SPART_TYPE (curr->_.gp.subquery))
        {
          sparp_trav_state_t stss [SPARP_MAX_SYNTDEPTH+2];
          memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
          stss[0].sts_ofs_of_curr_in_array = -1;
          stss[1].sts_ancestor_gp = curr->_.gp.subquery->_.req_top.pattern;
          sparp_gp_trav_int (sparp, curr->_.gp.subquery->_.req_top.pattern, stss+1, common_env,
            sparp_gp_trav_equiv_audit_inner_vars, NULL,
            sparp_gp_trav_equiv_audit_inner_vars, NULL, sparp_gp_trav_equiv_audit_inner_vars,
            NULL );
          sparp_equiv_audit_retvals (sparp, curr->_.gp.subquery);
          return SPAR_GPT_NODOWN;
        }
      return SPAR_GPT_ENV_PUSH;
    case SPAR_VARIABLE: break;
    case SPAR_BLANK_NODE_LABEL: break;
    default: return 0;
    }
  if (SPART_BAD_EQUIV_IDX != curr->_.var.equiv_idx)
    {
      sparp_equiv_t *eq_by_id, *eq;
      eq_by_id = SPARP_EQUIV (sparp, curr->_.var.equiv_idx);
      if (NULL == eq_by_id)
        {
          spar_audit_error (sparp, "sparp_" "gp_trav_equiv_audit_inner_vars(): curr with deleted eq_by_id in use");
          return 0;
        }
      if (eq_by_id->e_gp != gp)
        spar_audit_error (sparp, "sparp_" "gp_trav_equiv_audit_inner_vars(): e_gp of eq_by_id does not match gp, gp %s var %s/%s/%s", gp->_.gp.selid, curr->_.var.selid, curr->_.var.tabid, curr->_.var.vname);
      eq = sparp_equiv_get (sparp, gp, curr, 0);
      if (NULL == eq)
        {
          spar_audit_error (sparp, "sparp_" "gp_trav_equiv_audit_inner_vars(): eq not found, gp %s var %s/%s/%s", gp->_.gp.selid, curr->_.var.selid, curr->_.var.tabid, curr->_.var.vname);
          return 0;
        }
      if (eq->e_own_idx != curr->_.var.equiv_idx)
        spar_audit_error (sparp, "sparp_" "gp_trav_equiv_audit_inner_vars(): eq idx mismatch, gp %s var %s/%s/%s", gp->_.gp.selid, curr->_.var.selid, curr->_.var.tabid, curr->_.var.vname);
      if (strcmp (gp->_.gp.selid, curr->_.var.selid))
        spar_audit_error (sparp, "sparp_" "gp_trav_equiv_audit_inner_vars(): var selid differs from gp selid, gp %s var %s/%s/%s", gp->_.gp.selid, curr->_.var.selid, curr->_.var.tabid, curr->_.var.vname);
    }
  /*else if (SPARP_EQUIV_AUDIT_NOBAD & ((ptrlong)common_env))
    spar_audit_error (sparp, "sparp_" "gp_trav_equiv_audit_inner_vars(): var with SPART_BAD_EQUIV_IDX, var %s/%s/%s", curr->_.var.selid, curr->_.var.tabid, curr->_.var.vname);*/
  return 0;
}

static int
sparp_gp_trav_equiv_audit_retvals (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  SPART *top_gp = (SPART *)(common_env);
  sparp_equiv_t *eq;
  switch (SPART_TYPE(curr))
    {
    case SPAR_VARIABLE: break;
    case SPAR_BLANK_NODE_LABEL: break;
    default: return 0;
    }
  if (SPART_BAD_EQUIV_IDX == curr->_.var.equiv_idx)
    {
      eq = sparp_equiv_get (sparp, top_gp, curr, SPARP_EQUIV_GET_NAMESAKES);
      if ((NULL != eq) && (0 != curr->_.var.rvr.rvrRestrictions))
        spar_audit_error (sparp, "sparp_" "gp_trav_equiv_audit_retvals(): variable out of eq but there is an eq for its namesakes");
      return 0;
    }
  eq = sparp_equiv_get (sparp, top_gp, curr, SPARP_EQUIV_GET_ASSERT | SPARP_EQUIV_GET_NAMESAKES);
  if (eq->e_own_idx != curr->_.var.equiv_idx)
    spar_audit_error (sparp, "sparp_" "gp_trav_equiv_audit_retvals(): eq idx mismatch");
  if (!(eq->e_rvr.rvrRestrictions & SPART_VARR_EXPORTED))
    spar_audit_error (sparp, "sparp_" "gp_trav_equiv_audit_retvals(): lost SPART_VARR_EXPORTED");
  return 0;
}

void
sparp_equiv_audit_retvals (sparp_t *sparp, SPART *top)
{
  int ctr;
  sparp_trav_state_t stss [SPARP_MAX_SYNTDEPTH+2];
  DO_BOX_FAST (SPART *, expn, ctr, top->_.req_top.retvals)
    {
      memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
      stss[0].sts_ofs_of_curr_in_array = -1;
      sparp_gp_trav_int (sparp, expn, stss+1, top->_.req_top.pattern,
        NULL, NULL,
        sparp_gp_trav_equiv_audit_retvals, NULL, NULL,
        NULL );
    }
  END_DO_BOX_FAST;
  DO_BOX_FAST (SPART *, grouping, ctr, top->_.req_top.groupings)
    {
      memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
      stss[0].sts_ofs_of_curr_in_array = -1;
      sparp_gp_trav_int (sparp, grouping, stss+1, top->_.req_top.pattern,
        NULL, NULL,
        sparp_gp_trav_equiv_audit_retvals, NULL, NULL,
        NULL );
    }
  END_DO_BOX_FAST;
  if (NULL != top->_.req_top.having)
    {
      memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
      stss[0].sts_ofs_of_curr_in_array = -1;
      sparp_gp_trav_int (sparp, top->_.req_top.having, stss+1, top->_.req_top.pattern,
        NULL, NULL,
        sparp_gp_trav_equiv_audit_retvals, NULL, NULL,
        NULL );
    }
  DO_BOX_FAST (SPART *, oby, ctr, top->_.req_top.order)
    {
      memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
      stss[0].sts_ofs_of_curr_in_array = -1;
      sparp_gp_trav_int (sparp, oby->_.oby.expn, stss+1, top->_.req_top.pattern,
        NULL, NULL,
        sparp_gp_trav_equiv_audit_retvals, NULL, NULL,
        NULL );
    }
  END_DO_BOX_FAST;
}

void
sparp_equiv_audit_gp (sparp_t *sparp, SPART *gp, int is_deprecated, sparp_equiv_t *chk_eq)
{
  int gp_eq_ctr;
  SPARP_FOREACH_GP_EQUIV (sparp, gp, gp_eq_ctr, gp_eq)
    {
      if (gp_eq->e_gp != gp)
        spar_audit_error (sparp, "sparp_" "equiv_audit_gp(): gp_eq->e_gp != gp, gp %s eq #%d for %s", gp->_.gp.selid, gp_eq->e_own_idx, gp_eq->e_varnames[0]);
      if (chk_eq == gp_eq)
        chk_eq = NULL;
      if (gp_eq->e_deprecated && !is_deprecated)
        spar_audit_error (sparp, "sparp_" "equiv_audit_gp(): eq is deprecated, gp %s eq #%d for %s", gp->_.gp.selid, gp_eq->e_own_idx, gp_eq->e_varnames[0]);
      if (is_deprecated && !(gp_eq->e_deprecated))
        spar_audit_error (sparp, "sparp_" "equiv_audit_gp(): eq is expected to be deprecated, gp %s eq #%d for %s", gp->_.gp.selid, gp_eq->e_own_idx, gp_eq->e_varnames[0]);
    }
  END_SPARP_FOREACH_GP_EQUIV;
  if (NULL != chk_eq)
    spar_audit_error (sparp, "sparp_" "equiv_audit_gp(): no reference to chk_eq in gp, gp %s chk_eq #%d for %s", gp->_.gp.selid, chk_eq->e_own_idx, chk_eq->e_varnames[0]);
}

void
sparp_equiv_audit_all (sparp_t *sparp, int flags)
{
  sparp_trav_state_t stss [SPARP_MAX_SYNTDEPTH+2];
  int eq_ctr, eq_count, var_ctr, recv_ctr, subv_ctr;
  if (NULL == sparp->sparp_entire_query)
    return; /* Internal error during parsing phase, there's no complete query to validate equivalence classes in it. */
  memset (stss, 0, sizeof (sparp_trav_state_t) * (SPARP_MAX_SYNTDEPTH+2));
  stss[0].sts_ofs_of_curr_in_array = -1;
  sparp_gp_trav_int (sparp, sparp->sparp_entire_query->_.req_top.pattern, stss+1, (void *)((ptrlong)flags),
    sparp_gp_trav_equiv_audit_inner_vars, NULL,
    sparp_gp_trav_equiv_audit_inner_vars, NULL, sparp_gp_trav_equiv_audit_inner_vars,
    NULL );
  sparp_equiv_audit_retvals (sparp, sparp->sparp_entire_query);
  eq_count = sparp->sparp_sg->sg_equiv_count;
  for (eq_ctr = sparp->sparp_first_equiv_idx; eq_ctr < eq_count; eq_ctr++)
    {
      sparp_equiv_t *eq = SPARP_EQUIV (sparp, eq_ctr);
      SPART *gp;
      int count_of_global_vars = 0;
      if (NULL == eq)
        continue;
      if (eq->e_own_idx != eq_ctr)
        spar_audit_error (sparp, "sparp_" "equiv_audot_all(): wrong own index, eq #%d for %s has e_own_idx %d", eq_ctr, eq->e_varnames[0], eq->e_own_idx);
      for (var_ctr = eq->e_var_count; var_ctr--; /*no step*/)
        {
          SPART *var = eq->e_vars [var_ctr];
          if (var->_.var.equiv_idx != eq_ctr)
            spar_audit_error (sparp, "sparp_" "equiv_audit_all(): var->_.var.equiv_idx != eq_ctr: eq #%d for %s, gp %s, var %s/%s/%s with equiv_idx %d", eq_ctr, eq->e_varnames[0], eq->e_gp->_.gp.selid, var->_.var.selid, var->_.var.tabid, var->_.var.vname, var->_.var.equiv_idx);
        }
      gp = eq->e_gp;
      if (SPAR_GP != gp->type)
        continue;
      /*if (eq->e_nested_bindings != BOX_ELEMENTS_0 (eq->e_subvalue_idxs))
        printf ("sparp_" "equiv_audit_all(): warning: strange: equiv %d (?%s): e_nested_bindings = %d, %d subvalues in list, e_optional_reads = %d\n",
            (int)(eq->e_own_idx), eq->e_varnames[0],
            (int)(eq->e_nested_bindings), BOX_ELEMENTS_INT_0 (eq->e_subvalue_idxs), (int)(eq->e_optional_reads) );*/
      sparp_equiv_audit_gp (sparp, gp, ((SPART_BAD_GP_SUBTYPE == gp->_.gp.subtype) ? 1 : 0), eq);
      for (var_ctr = eq->e_var_count; var_ctr--; /*no step*/)
        {
          SPART *var = eq->e_vars [var_ctr];
          if (var->_.var.equiv_idx != eq_ctr)
            spar_audit_error (sparp, "sparp_" "equiv_audit_all(): var->_.var.equiv_idx != eq_ctr: eq #%d for %s, gp %s, var %s/%s/%s with equiv_idx %d", eq_ctr, eq->e_varnames[0], var->_.var.selid, var->_.var.tabid, var->_.var.vname, var->_.var.equiv_idx);
          if (strcmp (var->_.var.selid, gp->_.gp.selid))
            spar_audit_error (sparp, "sparp_" "equiv_audit_all(): selid of var of eq differs from selid of gp of eq, gp %s, var %s/%s/%s with equiv_idx %d", gp->_.gp.selid, var->_.var.selid, var->_.var.tabid, var->_.var.vname, var->_.var.equiv_idx);
          if (SPART_VARNAME_IS_GLOB (var->_.var.vname))
            {
              count_of_global_vars++;
              if (!(var->_.var.rvr.rvrRestrictions & SPART_VARR_GLOBAL))
                spar_audit_error (sparp, "sparp_" "equiv_audit_all(): varname is global, SPART_VARR_GLOBAL of var is not set, var %s/%s/%s with equiv_idx %d", gp->_.gp.selid, var->_.var.selid, var->_.var.tabid, var->_.var.vname, var->_.var.equiv_idx);
            }
          else
            if (var->_.var.rvr.rvrRestrictions & SPART_VARR_GLOBAL)
              spar_audit_error (sparp, "sparp_" "equiv_audit_all(): varname is not global, SPART_VARR_GLOBAL of var is set, var %s/%s/%s with equiv_idx %d", gp->_.gp.selid, var->_.var.selid, var->_.var.tabid, var->_.var.vname, var->_.var.equiv_idx);
          if (NULL != var->_.var.tabid)
            {
              int var_tr_idx = var->_.var.tr_idx;
              int triple_idx;
              for (triple_idx = BOX_ELEMENTS (gp->_.gp.members); triple_idx--; /* no step */)
                {
                  SPART *triple = gp->_.gp.members[triple_idx];
                  if (SPAR_TRIPLE != triple->type)
                    continue;
                  if (var_tr_idx < SPART_TRIPLE_FIELDS_COUNT)
                    {
                      if (triple->_.triple.tr_fields[var_tr_idx] == var)
                        break;
                    }
                  else
                    {
                      if (sparp_get_option (sparp, triple->_.triple.options, var_tr_idx) == var)
                        break;
                    }
                }
              if (0 > triple_idx)
                {
                  if (var_tr_idx < SPART_TRIPLE_FIELDS_COUNT)
                    spar_audit_error (sparp, "sparp_" "equiv_audit_all(): var is in equiv but not in any triple of the group, var %s/%s#%d/%s", var->_.var.selid, var->_.var.tabid, var->_.var.tr_idx, var->_.var.vname);
#if 0
                  else
                    spar_audit_error (sparp, "sparp_" "equiv_audit_all(): var is in equiv but not in any triple of the group, var %s/%s#%d/%s", var->_.var.selid, var->_.var.tabid, var->_.var.tr_idx, var->_.var.vname);
#endif
                }
            }
        }
      if (!count_of_global_vars && (eq->e_rvr.rvrRestrictions & SPART_VARR_GLOBAL))
        spar_audit_error (sparp, "sparp_" "equiv_audit_all(): No vars with global names, but SPART_VARR_GLOBAL of var is set, equiv_idx %d in %s", eq_ctr, gp->_.gp.selid);
      recv_ctr = BOX_ELEMENTS_0 (eq->e_receiver_idxs);
      if (0 != recv_ctr)
        {
          SPART *recv_gp_0 = (SPARP_EQUIV (sparp, eq->e_receiver_idxs[0]))->e_gp;
          while (recv_ctr-- > 1)
            {
              SPART *recv_gp_N = (SPARP_EQUIV (sparp, eq->e_receiver_idxs[recv_ctr]))->e_gp;
              if (recv_gp_N != recv_gp_0)
                spar_audit_error (sparp, "sparp_" "equiv_audit_all(): gps of different recvs differ");
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
              spar_audit_error (sparp, "sparp_" "equiv_audit_all(): no matching subv for recv");
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
              spar_audit_error (sparp, "sparp_" "equiv_audit_all(): no matching recv for subv");
recv_of_subv_ok: ;
            }
          END_DO_BOX_FAST_REV;
        }
#if 0
      if (!SPARP_EQ_IS_ASSIGNED_LOCALLY(eq) &&
        !SPARP_EQ_IS_ASSIGNED_EXTERNALLY (eq) &&
        ((0 != eq->e_const_reads) || /* no check for (0 != eq->e_optional_reads) */
          (0 != BOX_ELEMENTS_0 (eq->e_receiver_idxs)) /*||
          (eq->e_rvr.rvrRestrictions & SPART_VARR_EXPORTED)*/ ) )
      spar_error (sparp, "Variable '%.100s' is used but not assigned", eq->e_varnames[0]);
#endif
    }
}

void
sparp_audit_mem (sparp_t *sparp)
{
  t_check_tree (sparp->sparp_entire_query);
}

#endif

int sparp_gp_trav_check_if_local (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  if ((SPAR_VARIABLE == curr->type) || (SPAR_RETVAL == curr->type))
    {
      caddr_t varname = curr->_.var.vname;
      if (!SPART_VARNAME_IS_GLOB(varname))
        return SPAR_GPT_COMPLETED;
      return SPAR_GPT_NODOWN;
    }
  if (SPAR_BLANK_NODE_LABEL == curr->type)
    return SPAR_GPT_COMPLETED;
  return 0;
}

int
sparp_tree_is_global_expn (sparp_t *sparp, SPART *tree)
{

  int res;
  int sparp_inside_gp_trav = (NULL != sparp->sparp_stp);
  if (sparp_inside_gp_trav)
    sparp_gp_trav_suspend (sparp);
  res = sparp_gp_trav (sparp, NULL /* unused */, tree, NULL,
    NULL, NULL,
    sparp_gp_trav_check_if_local, NULL, NULL /*!!!TBD add*/,
    NULL );
  if (sparp_inside_gp_trav)
    sparp_gp_trav_resume (sparp);
  return !(SPAR_GPT_COMPLETED & res);
}

int sparp_gp_trav_expn_reads_equiv (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  if ((SPAR_VARIABLE == curr->type) || (SPAR_BLANK_NODE_LABEL == curr->type))
    {
      if (curr->_.var.equiv_idx == ((ptrlong)(common_env)))
        return SPAR_GPT_COMPLETED;
    }
  return 0;
}

int
sparp_expn_reads_equiv (sparp_t *sparp, SPART *expn, sparp_equiv_t *eq)
{
  ptrlong eq_idx = eq->e_own_idx;
  int res = sparp_gp_trav (sparp, NULL /* unused */, expn, (void *)eq_idx,
    NULL, NULL,
    sparp_gp_trav_expn_reads_equiv, NULL, NULL /*!!!TBD add*/,
    NULL );
  return (SPAR_GPT_COMPLETED & res);
}

SPART *
bifsparqlopt_special_bif_agg (sparp_t *sparp, int bif_opt_opcode, SPART *tree, bif_metadata_t *bmd, void *more)
{
  switch (bif_opt_opcode)
    {
    case BIF_OPT_SIMPLIFY: return tree;
    case BIF_OPT_RET_TYPE:
      {
        rdf_val_range_t *rvr_ret = (rdf_val_range_t *)more;
        caddr_t qname = tree->_.funcall.qname;
        if (uname_SPECIAL_cc_bif_c_COUNT == qname)
          {
            memset (rvr_ret, 0, sizeof (rdf_val_range_t));
            rvr_ret->rvrRestrictions = SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL | SPART_VARR_NOT_NULL;
            break;
          }
        if (1 == BOX_ELEMENTS (tree->_.funcall.argtrees))
          sparp_get_expn_rvr (sparp, tree->_.funcall.argtrees[0], rvr_ret, 1 /*return_independent_copy*/);
        else
          memset (rvr_ret, 0, sizeof (rdf_val_range_t));
        if (uname_SPECIAL_cc_bif_c_MAX == qname || uname_SPECIAL_cc_bif_c_MIN == qname)
          {
            rvr_ret->rvrRestrictions &= ~SPART_VARR_NOT_NULL;
            break;
          }
        if (uname_SPECIAL_cc_bif_c_AVG == qname)
          {
            rvr_ret->rvrRestrictions &= ~SPART_VARR_NOT_NULL;
            rvr_ret->rvrRestrictions |= SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL;
            break;
          }
        if (uname_SPECIAL_cc_bif_c_SUM == qname)
          {
            rvr_ret->rvrRestrictions &= ~(SPART_VARR_NOT_NULL | SPART_VARR_FIXED);
            rvr_ret->rvrRestrictions |= SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL;
            break;
          }
        GPF_T;
      }
    }
  return NULL;
}

SPART *
bifsparqlopt_args_in_same_eq (sparp_t *sparp, int bif_opt_opcode, SPART *tree, bif_metadata_t *bmd, void *more)
{
  int answer = 0;
  SPART *arg0 = tree->_.funcall.argtrees[0];
  SPART *arg1 = tree->_.funcall.argtrees[1];
  sparp_equiv_t *eq0 = NULL, *eq1 = NULL;
  if (SPAR_IS_BLANK_OR_VAR (arg0))
    eq0 = SPARP_EQUIV (sparp, arg0->_.var.equiv_idx);
  if (SPAR_IS_BLANK_OR_VAR (arg1))
    eq1 = SPARP_EQUIV (sparp, arg1->_.var.equiv_idx);
  if ((NULL != eq0) && (NULL != eq1))
    {
      if (SPARP_EQUIV_MERGE_OK == sparp_equiv_merge (sparp, eq0, eq1))
        {
          eq0->e_replaces_filter |= SPART_VARR_EQ_VAR;
          sparp_equiv_forget_var (sparp, arg0);
          sparp_equiv_forget_var (sparp, arg1);
          answer = 1;
        }
    }
  switch (bif_opt_opcode)
    {
    case BIF_OPT_SIMPLIFY:
      if (answer)
        return SPAR_MAKE_BOOL_LITERAL (sparp, answer);
      return spartlist (sparp, 3, BOP_EQ, arg0, arg1);
    case BIF_OPT_RET_TYPE:
      {
        rdf_val_range_t *rvr_ret = (rdf_val_range_t *)more;
        rvr_ret->rvrRestrictions = SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_TYPED | SPART_VARR_FIXED;
        rvr_ret->rvrDatatype = uname_xmlschema_ns_uri_hash_boolean;
        rvr_ret->rvrFixedValue = t_box_num_nonull (answer ? 1 : 0);
      }
    }
  return NULL;
}
;


SPART *
bifsparqlopt_arg_is_local_var (sparp_t *sparp, int bif_opt_opcode, SPART *tree, bif_metadata_t *bmd, void *more)
{
  int answer = 0;
  SPART *arg0 = tree->_.funcall.argtrees[0];
  if (SPAR_IS_BLANK_OR_VAR (arg0))
    {
      sparp_equiv_t *eq = SPARP_EQUIV (sparp, arg0->_.var.equiv_idx);
      answer = !(eq->e_rvr.rvrRestrictions & SPART_VARR_EXTERNAL);
    }
  switch (bif_opt_opcode)
    {
    case BIF_OPT_SIMPLIFY:
      return SPAR_MAKE_BOOL_LITERAL (sparp, answer);
    case BIF_OPT_RET_TYPE:
      {
        rdf_val_range_t *rvr_ret = (rdf_val_range_t *)more;
        rvr_ret->rvrRestrictions = SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_TYPED | SPART_VARR_FIXED;
        rvr_ret->rvrDatatype = uname_xmlschema_ns_uri_hash_boolean;
        rvr_ret->rvrFixedValue = t_box_num_nonull (answer ? 1 : 0);
      }
    }
  return NULL;
}
;

void
sparql_init_bif_optimizers (void)
{
  bif_define_ex ("SPECIAL::bif:COUNT"		, NULL, BMD_SPARQL_OPTIMIZER_IMPL, bifsparqlopt_special_bif_agg		, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, &bt_integer	, BMD_SPARQL_ONLY, BMD_DONE);
  bif_define_ex ("SPECIAL::bif:MAX"		, NULL, BMD_SPARQL_OPTIMIZER_IMPL, bifsparqlopt_special_bif_agg		, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1				, BMD_SPARQL_ONLY, BMD_DONE);
  bif_define_ex ("SPECIAL::bif:MIN"		, NULL, BMD_SPARQL_OPTIMIZER_IMPL, bifsparqlopt_special_bif_agg		, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1				, BMD_SPARQL_ONLY, BMD_DONE);
  bif_define_ex ("SPECIAL::bif:AVG"		, NULL, BMD_SPARQL_OPTIMIZER_IMPL, bifsparqlopt_special_bif_agg		, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1				, BMD_SPARQL_ONLY, BMD_DONE);
  bif_define_ex ("SPECIAL::bif:SUM"		, NULL, BMD_SPARQL_OPTIMIZER_IMPL, bifsparqlopt_special_bif_agg		, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1				, BMD_SPARQL_ONLY, BMD_DONE);
  bif_define_ex ("sparql_only:args_in_same_eq"	, NULL, BMD_SPARQL_OPTIMIZER_IMPL, bifsparqlopt_args_in_same_eq		, BMD_MIN_ARGCOUNT, 2, BMD_MAX_ARGCOUNT, 2, BMD_RET_TYPE, &bt_integer	, BMD_SPARQL_ONLY, BMD_DONE);
  bif_define_ex ("sparql_only:arg_is_local_var"	, NULL, BMD_SPARQL_OPTIMIZER_IMPL, bifsparqlopt_arg_is_local_var	, BMD_MIN_ARGCOUNT, 1, BMD_MAX_ARGCOUNT, 1, BMD_RET_TYPE, &bt_integer	, BMD_SPARQL_ONLY, BMD_DONE);
}

int
sparp_literal_is_xsd_valid (sparp_t *sparp, caddr_t sqlval, caddr_t dt_iri, caddr_t lang)
{
  dtp_t sqlval_dtp = DV_TYPE_OF (sqlval);
  if (DV_STRING != sqlval_dtp)
    return 1; /* IRI or successfully parsed literal */
  if (NULL == dt_iri)
    return 1; /* no datatype --- no restrictions */
  if (!strncmp (dt_iri, XMLSCHEMA_NS_URI "#", XMLSCHEMA_NS_URI_LEN + 1 /* +1 is for '#' */))
    {
      const char *p_name = dt_iri + XMLSCHEMA_NS_URI_LEN + 1;
      long desc_idx = ecm_find_name (p_name, xqf_str_parser_descs_ptr, xqf_str_parser_desc_count, sizeof (xqf_str_parser_desc_t));
      xqf_str_parser_desc_t *desc;
      dtp_t sqlval_dtp = DV_TYPE_OF (sqlval);
      caddr_t cvt;
      if (ECM_MEM_NOT_FOUND == desc_idx)
        return 1; /* an unknown type */
      desc = xqf_str_parser_descs_ptr + desc_idx;
      if (DV_STRING != sqlval_dtp)
        return 1;
      else
        {
          caddr_t parsed_value = NULL;
          QR_RESET_CTX
            {
              desc->p_proc (&parsed_value, sqlval, desc->p_opcode);
            }
          QR_RESET_CODE
            {
              POP_QR_RESET;
              return 0; /* see below */
            }
          END_QR_RESET
          dk_free_tree (parsed_value);
          return 1;
        }
    }
  return 1;
}

void
sparp_get_expn_rvr (sparp_t *sparp, SPART *tree, rdf_val_range_t *rvr_ret, int return_independent_copy)
{
  switch (SPART_TYPE (tree))
    {
    case SPAR_ALIAS:
      sparp_get_expn_rvr (sparp, tree->_.alias.arg, rvr_ret, return_independent_copy);
      return;
    case SPAR_BLANK_NODE_LABEL: case SPAR_VARIABLE: case SPAR_RETVAL:
      if (return_independent_copy)
        sparp_rvr_copy (sparp, rvr_ret, &(tree->_.var.rvr));
      else
        memcpy (rvr_ret, &(tree->_.var.rvr), sizeof (rdf_val_range_t));
      return;
    case SPAR_LIT: case SPAR_QNAME: /* case SPAR_QNAME_NS: */
      sparp_rvr_set_by_constant (sparp, rvr_ret, NULL, tree);
      return;
    case ORDER_L:
    case SPAR_GRAPH:
    case SPAR_TRIPLE:
    case SPAR_REQ_TOP:
    case SPAR_QM_SQL_FUNCALL:
    case SPAR_LIST:
    case SPAR_SERVICE_INV:
    case SPAR_DEFMACRO:
    case SPAR_MACROCALL:
    case SPAR_MACROPU:
      spar_internal_error (sparp, "sparp_" "get_expn_rvr(): non-expression tree");
      return;
    case SPAR_GP: /* This is possible if a scalar subquery is argument of BOP_XXX, SPAR_ALIAS and the like. */
      memset (rvr_ret, 0, sizeof (rdf_val_range_t)); /*!!!TBD: inherit one from rvr of the first retval */
      return;
    case SPAR_BUILT_IN_CALL:
      memset (rvr_ret, 0, sizeof (rdf_val_range_t));
      return; /* !!!TBD */
    case SPAR_FUNCALL:
      {
        caddr_t qname = tree->_.funcall.qname;
        bif_metadata_t *bmd = NULL;
        if (!strncmp (qname, "bif:", 4))
          {
            caddr_t iduqname = sqlp_box_id_upcase (qname+4);
            bmd = find_bif_metadata_by_name (iduqname);
            dk_free_box (iduqname);
          }
        else
          bmd = (bif_metadata_t *)gethash (qname, name_to_bif_sparql_only_metadata_hash);
        memset (rvr_ret, 0, sizeof (rdf_val_range_t));
        if (NULL != bmd)
          {
            bif_type_t * bt = bmd->bmd_ret_type;
            bif_sparql_optimizer_t *bso = bmd->bmd_sparql_optimizer_impl;
            if (NULL != bt)
              rvr_ret->rvrRestrictions = sparp_restr_bits_of_dtp (bt->bt_dtp) & ~SPART_VARR_NOT_NULL;
            if (NULL != bso)
              bso (sparp, BIF_OPT_RET_TYPE, tree, bmd, rvr_ret);
          }
        return; /* !!! TBD better output */
      }
     case BOP_EQ: case SPAR_BOP_EQNAMES: case SPAR_BOP_EQ_NONOPT: case BOP_NEQ:
    case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
    /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! */
    case BOP_SAME: case BOP_NSAME:
    case BOP_AND: case BOP_OR: case BOP_NOT:
      memset (rvr_ret, 0, sizeof (rdf_val_range_t));
      rvr_ret->rvrRestrictions = SPART_VARR_TYPED | SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL;
      rvr_ret->rvrDatatype = uname_xmlschema_ns_uri_hash_boolean;
      return;
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
      memset (rvr_ret, 0, sizeof (rdf_val_range_t));
      rvr_ret->rvrRestrictions = SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL;
      return;
    }
  spar_internal_error (sparp, "sparp_" "get_expn_rvr(): unsupported type of expression");
}

static sparp_bool4way_t
sparp_cast_fv_dt_to_bool4way (ccaddr_t fv, ccaddr_t dt)
{
  if ((uname_xmlschema_ns_uri_hash_string == dt) || (NULL == dt))
    return (((DV_STRING == DV_TYPE_OF (fv)) && (1 < box_length (fv))) ? 'T' : 'F');
  if ((uname_xmlschema_ns_uri_hash_boolean == dt) || (uname_xmlschema_ns_uri_hash_integer == dt))
    return (((DV_LONG_INT == DV_TYPE_OF (fv)) && (0 != unbox (fv))) ? 'T' : 'F');
  if (uname_xmlschema_ns_uri_hash_double == dt)
    return (((DV_DOUBLE_FLOAT == DV_TYPE_OF (fv)) && (0 != unbox_double (fv))) ? 'T' : 'F');
  if (uname_xmlschema_ns_uri_hash_float == dt)
    return (((DV_SINGLE_FLOAT == DV_TYPE_OF (fv)) && (0 != unbox_float (fv))) ? 'T' : 'F');
  return '?';
}

sparp_bool4way_t
sparp_cast_rvr_to_bool4way (sparp_t *sparp, rdf_val_range_t *rvr)
{
  if (rvr->rvrRestrictions & (SPART_VARR_ALWAYS_NULL | SPART_VARR_CONFLICT))
    return 'U';
  if (!(rvr->rvrRestrictions & SPART_VARR_NOT_NULL))
    return '?';
  if (rvr->rvrRestrictions & SPART_VARR_IS_REF)
    return 'F'; /* proper EBV would be type error */
  if (NULL != rvr->rvrLanguage)
    return 'F'; /* proper EBV would be type error */
  if (rvr->rvrRestrictions & SPART_VARR_FIXED)
    {
      ccaddr_t fv = SPAR_LIT_OR_QNAME_VAL ((SPART *)(rvr->rvrFixedValue));
      ccaddr_t dt = rvr->rvrDatatype;
      return sparp_cast_fv_dt_to_bool4way (fv, dt);
    }
  return '?';
}

sparp_bool4way_t
sparp_cast_var_or_lit_to_bool4way (sparp_t *sparp, SPART *tree)
{
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    return sparp_cast_fv_dt_to_bool4way ((ccaddr_t)tree, NULL);
  switch (tree->type)
    {
    case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
      return sparp_cast_rvr_to_bool4way (sparp, &(tree->_.var.rvr));
    case SPAR_QNAME:
      return 'F'; /* proper EBV would be type error */
    case SPAR_LIT:
      if (NULL != tree->_.lit.language)
        return 'F'; /* proper EBV would be type error */
      return sparp_cast_fv_dt_to_bool4way (tree->_.lit.val, tree->_.lit.datatype);
    }
  return '?';
}

int
sparp_calc_bop_of_fixed_vals (sparp_t *sparp, ptrlong bop_type, rdf_val_range_t *left, rdf_val_range_t *right, SPART **res_ret)
{
  switch (bop_type)
    {
    case BOP_SAME: case BOP_NSAME:
      if (!sparp_expns_are_equal (sparp, (SPART *)(left->rvrLanguage), (SPART *)(right->rvrLanguage))
        || !sparp_expns_are_equal (sparp, (SPART *)(left->rvrDatatype), (SPART *)(right->rvrDatatype)) )
        {
          if (BOP_SAME == bop_type)
            goto res_bool_false; /* see below */
          if (BOP_NSAME == bop_type)
            goto res_bool_true; /* see below */
        }
      /* no break */
     case BOP_EQ: case SPAR_BOP_EQNAMES: case SPAR_BOP_EQ_NONOPT: case BOP_NEQ:
    case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
      {
        caddr_t left_val = (caddr_t)(left->rvrFixedValue);
        caddr_t right_val = (caddr_t)(right->rvrFixedValue);
        int cb = cmp_boxes_safe (left_val, right_val, NULL, NULL);
        switch (cb)
          {
          case DVC_MATCH:
            if ((BOP_EQ == bop_type) || (BOP_LTE == bop_type) || (BOP_GTE == bop_type) || (BOP_SAME == bop_type))
              goto res_bool_true; /* see below */
            goto res_bool_false; /* see below */
          case DVC_LESS:
            if ((BOP_NEQ == bop_type) || (BOP_LT == bop_type) || (BOP_LTE == bop_type) || (BOP_NSAME == bop_type))
              goto res_bool_true; /* see below */
            goto res_bool_false; /* see below */
          case DVC_GREATER:
            if ((BOP_NEQ == bop_type) || (BOP_GT == bop_type) || (BOP_GTE == bop_type) || (BOP_NSAME == bop_type))
              goto res_bool_true; /* see below */
            goto res_bool_false; /* see below */
          case DVC_NOORDER:
            return 1;
          default:
            if ((BOP_NEQ == bop_type) || (BOP_NSAME == bop_type))
              goto res_bool_true; /* see below */
            return 1; /* was goto res_bool_false; , but it might be unsafe for out of range and BOP_LT / BOP_GT. Let SQL compiler worries about that */
          }
      }
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
      {
        caddr_t left_val, right_val;
        if ((NULL != left->rvrLanguage) || (NULL != right->rvrLanguage))
          return 2;
        left_val = (caddr_t)(left->rvrFixedValue);
        right_val = (caddr_t)(right->rvrFixedValue);
        if ((uname_xmlschema_ns_uri_hash_integer == left->rvrDatatype) && (DV_LONG_INT == DV_TYPE_OF (left_val))
          && (uname_xmlschema_ns_uri_hash_integer == right->rvrDatatype) && (DV_LONG_INT == DV_TYPE_OF (right_val)) )
          {
            boxint l_int = unbox (left_val);
            boxint r_int = unbox (right_val);
            boxint res_int = 0;
            switch (bop_type)
              {
              case BOP_PLUS: res_int = l_int + r_int; break;
              case BOP_MINUS: res_int = l_int - r_int; break;
              case BOP_TIMES: res_int = l_int * r_int; break;
              case BOP_DIV: if (0 == r_int) return 3; res_int = l_int / r_int; break;
              case BOP_MOD: if (0 == r_int) return 3; res_int = l_int % r_int; break;
              }
            res_ret[0] = spartlist (sparp, 4, SPAR_LIT, (SPART *)t_box_num_nonull(res_int), uname_xmlschema_ns_uri_hash_integer, NULL);
          }
        return 1; /* !!!TBD add arithmetics for other datatypes and their combinations */
      }
    }
  return 1;
res_bool_true:
  res_ret[0] = SPAR_MAKE_BOOL_LITERAL(sparp, 1);
  return 0;
res_bool_false:
  res_ret[0] = SPAR_MAKE_BOOL_LITERAL(sparp, 0);
  return 0;
}

SPART *
sparp_simplify_builtin (sparp_t *sparp, SPART *tree, int *trouble_ret)
{
  SPART **orig_args = tree->_.builtin.args;
  SPART *arg1;
  int orig_argcount = BOX_ELEMENTS_0 (orig_args);
  if (0 == orig_argcount)
    {
      trouble_ret[0] = 2;
      return NULL;
    }
  arg1 = orig_args[0];
  switch (tree->_.builtin.btype)
    {
    case IN_L:
      {
        int argctr, new_argcount = orig_argcount;
        rdf_val_range_t l_rvr;
        sparp_get_expn_rvr (sparp, arg1, &l_rvr, 0);
        if (l_rvr.rvrRestrictions & (SPART_VARR_CONFLICT | SPART_VARR_ALWAYS_NULL))
          goto res_bool_false; /* see below */
        for (argctr = new_argcount - 1; argctr > 0; argctr--)
          {
            SPART *r_arg = orig_args[argctr];
            rdf_val_range_t r_rvr;
            sparp_get_expn_rvr (sparp, r_arg, &r_rvr, 1);
            sparp_rvr_tighten (sparp, &r_rvr, &l_rvr, ~0);
            if (r_rvr.rvrRestrictions & (SPART_VARR_CONFLICT | SPART_VARR_ALWAYS_NULL))
              {
                if (argctr < new_argcount - 1)
                  orig_args[argctr] = orig_args[new_argcount - 1];
                new_argcount--;
              }
          }
        if (2 > new_argcount)
          goto res_bool_false; /* see below */
        if (2 == new_argcount)
          {
            trouble_ret[0] = 0;
            return spartlist (sparp, 3, BOP_EQ, arg1, orig_args[1]);
          }
        if (new_argcount < orig_argcount)
          {
            tree->_.builtin.args = (SPART **)t_alloc_list (new_argcount);
            memcpy (tree->_.builtin.args, orig_args, new_argcount * sizeof (SPART *));
            trouble_ret[0] = 0;
            return tree;
          }
        goto trouble_now; /* see below */
      }
    case SPAR_BIF_ABS: break;
    case SPAR_BIF_BNODE: break;
    case SPAR_BIF_CEIL: break;
    case SPAR_BIF_COALESCE: break;
    case SPAR_BIF_CONCAT: break;
    case SPAR_BIF_CONTAINS: break;
    case SPAR_BIF_DAY: break;
    case SPAR_BIF_ENCODE_FOR_URI: break;
    case SPAR_BIF_FLOOR: break;
    case SPAR_BIF_HOURS: break;
    case SPAR_BIF_IF:
      {
        sparp_bool4way_t b4w_arg1 = sparp_cast_var_or_lit_to_bool4way (sparp, arg1);
        if ('T' == b4w_arg1)
          { trouble_ret[0] = 0; return orig_args[1]; }
        if ('F' == b4w_arg1)
          { trouble_ret[0] = 0; return orig_args[2]; }
        break;
      }
    case SPAR_BIF_ISBLANK: break;
    case SPAR_BIF_ISIRI: break;
    case SPAR_BIF_ISLITERAL:
      {
        switch (SPART_TYPE (arg1))
          {
          case SPAR_QNAME: goto res_bool_false; /* see below */
          case SPAR_LIT: goto res_bool_true; /* see below */
          case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
            if (arg1->_.var.rvr.rvrRestrictions & SPART_VARR_CONFLICT)
              break;
            if (arg1->_.var.rvr.rvrRestrictions & SPART_VARR_NOT_NULL)
              {
                if (arg1->_.var.rvr.rvrRestrictions & SPART_VARR_IS_LIT)
                  goto res_bool_true; /* see below */
                else if (arg1->_.var.rvr.rvrRestrictions & SPART_VARR_IS_REF)
                  goto res_bool_false; /* see below */
              }
          }
        goto trouble_now; /* see below */
      }
    case SPAR_BIF_ISNUMERIC: break;
    case SPAR_BIF_ISREF:
      {
        switch (SPART_TYPE (arg1))
          {
          case SPAR_QNAME: goto res_bool_true; /* see below */
          case SPAR_LIT: goto res_bool_false; /* see below */
          case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
            if (arg1->_.var.rvr.rvrRestrictions & SPART_VARR_CONFLICT)
              break;
            if (arg1->_.var.rvr.rvrRestrictions & SPART_VARR_NOT_NULL)
              {
                if (arg1->_.var.rvr.rvrRestrictions & SPART_VARR_IS_LIT)
                  goto res_bool_false; /* see below */
                else if (arg1->_.var.rvr.rvrRestrictions & SPART_VARR_IS_REF)
                  goto res_bool_true; /* see below */
              }
          }
        goto trouble_now; /* see below */
      }
    case SPAR_BIF_ISURI: break;
    case SPAR_BIF_LANGMATCHES: break;
    case SPAR_BIF_LCASE: break;
    case SPAR_BIF_MD5: break;
    case SPAR_BIF_MINUTES: break;
    case SPAR_BIF_MONTH: break;
    case SPAR_BIF_NOW: break;
    case SPAR_BIF_RAND: break;
    case SPAR_BIF_REGEX: break;
    case SPAR_BIF_REPLACE: break;
    case SPAR_BIF_ROUND: break;
    case SPAR_BIF_SAMETERM: break;
    case SPAR_BIF_SECONDS: break;
    case SPAR_BIF_SHA1: break;
    case SPAR_BIF_SHA224: break;
    case SPAR_BIF_SHA256: break;
    case SPAR_BIF_SHA384: break;
    case SPAR_BIF_SHA512: break;
    case SPAR_BIF_STR: break;
    case SPAR_BIF_STRAFTER: break;
    case SPAR_BIF_STRBEFORE: break;
    case SPAR_BIF_STRDT: break;
    case SPAR_BIF_STRENDS: break;
    case SPAR_BIF_STRLANG: break;
    case SPAR_BIF_STRLEN: break;
    case SPAR_BIF_STRSTARTS: break;
    case SPAR_BIF_STRUUID: break;
    case SPAR_BIF_SUBSTR: break;
    case SPAR_BIF_TIMEZONE: break;
    case SPAR_BIF_TZ: break;
    case SPAR_BIF_UCASE: break;
    case SPAR_BIF_URI: break;
    case SPAR_BIF_UUID: break;
    case SPAR_BIF_VALID:
      {
        switch (SPART_TYPE (arg1))
          {
          case SPAR_QNAME: goto res_bool_true; /* see below */
          case SPAR_LIT:
            {
              if (sparp_literal_is_xsd_valid (sparp, arg1->_.lit.val, arg1->_.lit.datatype, arg1->_.lit.language))
                goto res_bool_true; /* see below */
              else
                goto res_bool_false; /* see below */
            }
          case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
            if (arg1->_.var.rvr.rvrRestrictions & SPART_VARR_CONFLICT)
              goto res_bool_true; /* see below */
            if (arg1->_.var.rvr.rvrRestrictions & SPART_VARR_ALWAYS_NULL)
              goto res_bool_true; /* see below */
            if (arg1->_.var.rvr.rvrRestrictions & SPART_VARR_IS_REF)
              goto res_bool_true; /* see below */
            if (arg1->_.var.rvr.rvrRestrictions & SPART_VARR_FIXED)
              {
                if (sparp_literal_is_xsd_valid (sparp, arg1->_.var.rvr.rvrFixedValue, arg1->_.var.rvr.rvrDatatype, arg1->_.var.rvr.rvrLanguage))
                  goto res_bool_true; /* see below */
                else
                  goto res_bool_false; /* see below */
              }
            break;
          default: break;
          }
        goto trouble_now; /* see below */
      }
    case SPAR_BIF_YEAR: break;
    default: break;
    }
  trouble_ret[0] = 2;
  return NULL;
trouble_now:
  trouble_ret[0] = 1;
  return NULL;
res_bool_true:
  trouble_ret[0] = 0;
  return SPAR_MAKE_BOOL_LITERAL(sparp, 1);
res_bool_false:
  trouble_ret[0] = 0;
  return SPAR_MAKE_BOOL_LITERAL(sparp, 0);
}

int
sparp_gp_trav_simplify_expn_out (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  ptrlong curr_type = SPART_TYPE (curr);
  sparp_bool4way_t b4w_res;
  SPART *res = (SPART *)BADBEEF_BOX;
  switch (curr_type)
    {
    case SPAR_ALIAS:
    case SPAR_BLANK_NODE_LABEL: case SPAR_VARIABLE:
    case ORDER_L:
      return 0;
    case SPAR_GRAPH:
    case SPAR_GP:
    case SPAR_LIT: case SPAR_QNAME: /* case SPAR_QNAME_NS: */
    case SPAR_TRIPLE:
    case SPAR_REQ_TOP:
    case SPAR_QM_SQL_FUNCALL:
    case SPAR_LIST:
    case SPAR_SERVICE_INV:
    case SPAR_DEFMACRO:
    case SPAR_MACROCALL:
    case SPAR_MACROPU:
      spar_internal_error (sparp, "sparp_" "gp_trav_simplify_expn_out(): the expn_out callback should not get this type of subtree");
      return 0;
    case SPAR_BUILT_IN_CALL:
      {
        SPART *arg1;
        if (0 == BOX_ELEMENTS_0 (curr->_.builtin.args))
          return 0;
        arg1 = curr->_.builtin.args[0];
        if (SPAR_IS_LIT_OR_QNAME (arg1))
          {
            int trouble = 0;
            res = sparp_simplify_builtin (sparp, curr, &trouble);
            if (!trouble)
              goto res_done; /* see below */
          }
        if (SPAR_IS_BLANK_OR_VAR (arg1))
          {
            int trouble = 0;
            res = sparp_simplify_builtin (sparp, curr, &trouble);
            if (!trouble)
              goto res_done; /* see below */
          }
      }
      return 0; /* !!!TBD */
    case SPAR_FUNCALL:
      {
        caddr_t qname = curr->_.funcall.qname;
        bif_metadata_t *bmd = NULL;
        if (!strncmp (qname, "bif:", 4))
          {
            caddr_t iduqname = sqlp_box_id_upcase (qname+4);
            bmd = find_bif_metadata_by_name (iduqname);
            dk_free_box (iduqname);
          }
        else
          bmd = (bif_metadata_t *)gethash (qname, name_to_bif_sparql_only_metadata_hash);
        if (NULL != bmd)
          {
            bif_sparql_optimizer_t *bso;
            if (bmd->bmd_is_pure && !(curr->_.funcall.disabled_optimizations & 0x1))
              {
                int trouble = 0;
                res = spar_run_pure_bif_in_sandbox (sparp, qname, curr->_.funcall.argtrees, BOX_ELEMENTS (curr->_.funcall.argtrees), bmd, &trouble);
                if (!trouble)
                  goto res_done; /* see below */
                if (2 == trouble)
                  curr->_.funcall.disabled_optimizations |= 0x1;
              }
            bso = bmd->bmd_sparql_optimizer_impl;
            if (NULL != bso)
              {
                res = bso (sparp, BIF_OPT_SIMPLIFY, curr, bmd, NULL);
                goto res_done; /* see below */
              }
          }
        return 0;
      }
     case BOP_EQ: case SPAR_BOP_EQNAMES: case SPAR_BOP_EQ_NONOPT: case BOP_NEQ:
    case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
    /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! */
    case BOP_SAME: case BOP_NSAME:
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
      {
        SPART *l_arg = curr->_.bin_exp.left;
        SPART *r_arg = curr->_.bin_exp.right;
        rdf_val_range_t l_rvr;
        rdf_val_range_t r_rvr;
        sparp_get_expn_rvr (sparp, l_arg, &l_rvr, 0);
        if (l_rvr.rvrRestrictions & (SPART_VARR_ALWAYS_NULL | SPART_VARR_CONFLICT))
          {
            res = l_arg;
            goto res_done; /* see below */
          }
        if (!(l_rvr.rvrRestrictions & SPART_VARR_NOT_NULL))
          return 0;
        if (!(l_rvr.rvrRestrictions & (SPART_VARR_TYPED | SPART_VARR_FIXED)))
          return 0;
        sparp_get_expn_rvr (sparp, r_arg, &r_rvr, 0);
        if (r_rvr.rvrRestrictions & (SPART_VARR_ALWAYS_NULL | SPART_VARR_CONFLICT))
          {
            res = r_arg;
            goto res_done; /* see below */
          }
        if (!(l_rvr.rvrRestrictions & SPART_VARR_NOT_NULL))
          return 0;
        if (!(r_rvr.rvrRestrictions & (SPART_VARR_TYPED | SPART_VARR_FIXED)))
          return 0;
        if (l_rvr.rvrRestrictions & r_rvr.rvrRestrictions & SPART_VARR_FIXED)
          {
            int errcode = sparp_calc_bop_of_fixed_vals (sparp, curr_type, &l_rvr, &r_rvr, &res);
            if (0 == errcode)
              goto res_done; /* see below */
          }
        return 0;
      }
    case BOP_NOT:
      {
        SPART *l_arg = curr->_.bin_exp.left;
        rdf_val_range_t l_rvr;
        sparp_get_expn_rvr (sparp, l_arg, &l_rvr, 0);
        b4w_res = sparp_cast_rvr_to_bool4way (sparp, &l_rvr);
        b4w_res = (('T' == b4w_res) ? 'F' : (('F' == b4w_res) ? 'T' : b4w_res));
        goto b4w_res_done; /* see below */
      }
    case BOP_AND:
      {
        SPART *l_arg = curr->_.bin_exp.left;
        rdf_val_range_t l_rvr;
        sparp_get_expn_rvr (sparp, l_arg, &l_rvr, 0);
        b4w_res = sparp_cast_rvr_to_bool4way (sparp, &l_rvr);
        if ('T' == b4w_res)
          {
            res = curr->_.bin_exp.right;
            goto res_done; /* see below */
          }
        if (('F' == b4w_res) || ('U' == b4w_res))
          goto b4w_res_done; /* see below */
        return 0;
      }
    case BOP_OR:
      {
        SPART *l_arg = curr->_.bin_exp.left;
        rdf_val_range_t l_rvr;
        sparp_get_expn_rvr (sparp, l_arg, &l_rvr, 0);
        b4w_res = sparp_cast_rvr_to_bool4way (sparp, &l_rvr);
        if ('F' == b4w_res)
          {
            res = curr->_.bin_exp.right;
            goto res_done; /* see below */
          }
        if (('T' == b4w_res) || ('U' == b4w_res))
          goto b4w_res_done; /* see below */
        return 0;
      }
    }
  spar_internal_error (sparp, "sparp_" "tree_full_copy(): unsupported type of expression");
  return 0; /* to keep C compiler happy */

b4w_res_done:
  if ('T' == b4w_res) res = SPAR_MAKE_BOOL_LITERAL(sparp, 1);
  else if ('F' == b4w_res) res = SPAR_MAKE_BOOL_LITERAL(sparp, 0);
  /*else if ('U' == b4w_res) res = (SPART *)t_NEW_DB_NULL;*/
  else return 0;
  goto res_done; /* see below */

res_done:
  sts_this->sts_curr_array[sts_this->sts_ofs_of_curr_in_array] = res;
  sparp->sparp_rewrite_dirty++;
  return 0;
}

int
sparp_gp_trav_simplify_expn_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_continue_gp_trav_in_sub (sparp, curr, common_env, 1);
  return 0;
}


/* Main rewriting functions */

void
sparp_rewrite_basic (sparp_t *sparp, SPART *req_top)
{
  sparp_audit_mem (sparp);
  sparp_count_usages (sparp, req_top, NULL);
  sparp_audit_mem (sparp);
  sparp_restrict_by_simple_filters (sparp, req_top);
  sparp_audit_mem (sparp);
  sparp_make_common_eqs (sparp, req_top);
  sparp_make_aliases (sparp, req_top);
  sparp_label_external_vars (sparp, req_top, NULL); /* This is now before sparp_eq_restr_from_connected() to prevent wrong SPART_VARR_ALWAYS_NULL for external vars that are used solely in const reads */
  sparp_eq_restr_from_connected (sparp, req_top);
  sparp_eq_restr_to_vars (sparp, req_top);
  sparp_remove_totally_useless_equivs (sparp);
  sparp_remove_redundant_connections (sparp, req_top, 0);
  sparp_audit_mem (sparp);
}

void
sparp_simplify_expns (sparp_t *sparp, SPART *req_top)
{
  int saved_sparp_dirty = sparp->sparp_rewrite_dirty;
  int local_dirty;
  sparp->sparp_rewrite_dirty = 0;
  local_dirty = sparp->sparp_rewrite_dirty;
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    NULL, NULL,
    NULL, sparp_gp_trav_simplify_expn_out, sparp_gp_trav_simplify_expn_subq,
    NULL );
  sparp_trav_out_clauses (sparp, req_top, NULL,
    NULL, NULL,
    NULL, sparp_gp_trav_simplify_expn_out, sparp_gp_trav_simplify_expn_subq,
    NULL );
  sparp->sparp_rewrite_dirty += saved_sparp_dirty;
  if (local_dirty)
    sparp_rewrite_basic (sparp, req_top);
}


/* PART 2. GRAPH PATTERN TERM REWRITING */

void
spar_invalidate_binv_dataset_row (sparp_t *sparp, SPART *binv, int rowno, int reason_col)
{
  int varctr;
  unsigned mask_byte;
  if ('/' != binv->_.binv.data_rows_mask[rowno])
    spar_internal_error (sparp, "double invalidation of a binding");
  mask_byte = (unsigned)'0' + (unsigned)reason_col;
  if (0x7f < mask_byte)
    mask_byte = 0x7f;
  binv->_.binv.data_rows_mask[rowno] = mask_byte;
  DO_BOX_FAST (ptrlong, counter_of_unbound, varctr, binv->_.binv.counters_of_unbound)
    {
      if (NULL != binv->_.binv.data_rows[rowno][varctr])
        continue;
      binv->_.binv.counters_of_unbound[varctr] = counter_of_unbound - 1;
    }
  END_DO_BOX_FAST;
  binv->_.binv.rows_in_use--;
}

void
spar_shorten_binv_dataset (sparp_t *sparp, SPART *binv)
{
  int varcount, rowcount, varctr, rowctr;
  int *fmt_use_counters = NULL;
  int max_sff_count = -1;
  varcount = BOX_ELEMENTS (binv->_.binv.vars);
  if (0 == binv->_.binv.rows_in_use)
    return;
  varcount = BOX_ELEMENTS (binv->_.binv.vars);
  rowcount = BOX_ELEMENTS (binv->_.binv.data_rows);
/* All loops by rows here must be in reverse order. */
  for (varctr = varcount; varctr--; /* no step */)
    {
      SPART *var = binv->_.binv.vars[varctr];
      sparp_equiv_t *eq = SPARP_EQUIV (sparp, var->_.var.equiv_idx);
      if (var->_.var.rvr.rvrRestrictions & (SPART_VARR_CONFLICT | SPART_VARR_ALWAYS_NULL))
        continue;
      if (eq->e_rvr.rvrRestrictions & (SPART_VARR_CONFLICT | SPART_VARR_ALWAYS_NULL))
        {
          for (rowctr = rowcount; rowctr--; /* no step */)
            {
              if ('/' != binv->_.binv.data_rows_mask[rowctr])
                continue;
              if (NULL == binv->_.binv.data_rows[rowctr][varctr])
                continue;
              spar_invalidate_binv_dataset_row (sparp, binv, rowctr, varctr);
            }
          continue;
        }
      if ((eq->e_rvr.rvrRestrictions & SPART_VARR_SPRINTFF) && (eq->e_rvr.rvrSprintffCount > max_sff_count))
        max_sff_count = eq->e_rvr.rvrSprintffCount;
/* The following "if" is needed for case of tightening \c eq with \c var in the next loop.
As a result of tightening, the \c eq->e_rvr.rvrSprintffCount may grow, thus \c max_sff_count should be big enough to reflect this possibility. */
      if ((var->_.var.rvr.rvrRestrictions & SPART_VARR_SPRINTFF) && (var->_.var.rvr.rvrSprintffCount > max_sff_count))
        max_sff_count = var->_.var.rvr.rvrSprintffCount;
    }
  if (0 < max_sff_count)
    fmt_use_counters = (int *)t_alloc (max_sff_count * sizeof (int));
  for (varctr = varcount; varctr--; /* no step */)
    {
      SPART *var = binv->_.binv.vars[varctr];
      sparp_equiv_t *eq = SPARP_EQUIV (sparp, var->_.var.equiv_idx);
      int eq_has_sffs_bit = (eq->e_rvr.rvrRestrictions & SPART_VARR_SPRINTFF);
      int eq_sff_count = eq->e_rvr.rvrSprintffCount;
      if (!rvr_can_be_tightened (sparp, &(eq->e_rvr), &(var->_.var.rvr), 1))
        continue;
      sparp_equiv_tighten (sparp, eq, &(var->_.var.rvr), ~0);
      if (eq->e_rvr.rvrSprintffCount)
        memset (fmt_use_counters, 0, eq->e_rvr.rvrSprintffCount * sizeof (int));
      for (rowctr = rowcount; rowctr--; /* no step */)
        {
          SPART *datum;
          rdf_val_range_t tmp;
          if ('/' != binv->_.binv.data_rows_mask[rowctr])
            continue;
          datum = binv->_.binv.data_rows[rowctr][varctr];
          if (NULL == datum)
            continue;
          sparp_rvr_set_by_constant (sparp, &tmp, NULL, datum);
          eq->e_rvr.rvrRestrictions &= ~SPART_VARR_SPRINTFF;
          eq->e_rvr.rvrSprintffCount = 0;
          sparp_rvr_tighten (sparp, &tmp, &(eq->e_rvr), ~0);
          eq->e_rvr.rvrRestrictions |= eq_has_sffs_bit;
          eq->e_rvr.rvrSprintffCount = eq_sff_count;
          if (tmp.rvrRestrictions & SPART_VARR_CONFLICT)
            {
              spar_invalidate_binv_dataset_row (sparp, binv, rowctr, varctr);
              continue;
            }
          if (eq_has_sffs_bit)
            {
              int sff_ctr;
              int hit = 0;
              caddr_t datum_val = SPAR_LIT_OR_QNAME_VAL (datum);
              dtp_t datum_val_dtp = DV_TYPE_OF (datum_val);
              if ((DV_STRING == datum_val_dtp) || (DV_UNAME == datum_val_dtp))
                {
                  for (sff_ctr = eq->e_rvr.rvrSprintffCount; sff_ctr--; /* no step */)
                    {
                      if (!sprintff_like (datum_val, eq->e_rvr.rvrSprintffs[sff_ctr]))
                        continue;
                      fmt_use_counters[sff_ctr] += 1;
                      hit = 1;
                    }
                }
              if (!hit)
                {
                  spar_invalidate_binv_dataset_row (sparp, binv, rowctr, varctr);
                  continue;
                }
            }
        }
      if (eq_has_sffs_bit && (0 == binv->_.binv.counters_of_unbound[varctr]))
        {
          int sff_ctr;
          for (sff_ctr = eq->e_rvr.rvrSprintffCount; sff_ctr--; /* no step */)
            {
              if (0 != fmt_use_counters[sff_ctr])
                continue;
              if (sff_ctr < (eq->e_rvr.rvrSprintffCount-1))
                eq->e_rvr.rvrSprintffs [sff_ctr] = eq->e_rvr.rvrSprintffs [eq->e_rvr.rvrSprintffCount-1];
              eq->e_rvr.rvrSprintffCount -= 1;
            }
          if (0 == eq->e_rvr.rvrSprintffCount)
            {
              SPARP_DEBUG_WEIRD(sparp,"conflict");
              eq->e_rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
            }
          if (eq->e_rvr.rvrSprintffCount != var->_.var.rvr.rvrSprintffCount)
            sparp_rvr_tighten (sparp, &(var->_.var.rvr), &(eq->e_rvr), ~(SPART_VARR_EXTERNAL | SPART_VARR_GLOBAL));
        }
    }
}

#define BINV_CELL_HASH(hash,cell) do { \
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (cell)) \
    hash = box_hash ((caddr_t)cell); \
  else if (SPAR_LIT == cell->type) \
    hash = 0x1 ^ box_hash (cell->_.lit.val) ^ box_hash (cell->_.lit.datatype) ^ box_hash (cell->_.lit.language); \
  else if (SPAR_QNAME == cell->type) \
    hash = 0x2 ^ box_hash (cell->_.qname.val); \
  } while (0)

int
spar_binv_is_convertible_to_filter (sparp_t *sparp, SPART *parent_gp, SPART *member_gp, SPART *member_binv)
{
  sparp_equiv_t *eq;
  SPART ***rows = member_binv->_.binv.data_rows;
  char *mask = member_binv->_.binv.data_rows_mask;
  int row_idx;
  unsigned char hash_bits[1027];
  unsigned int hash_mod;
  eq = sparp_equiv_get_ro (sparp->sparp_sg->sg_equivs, sparp->sparp_sg->sg_equiv_count, parent_gp, (SPART *)(member_binv->_.binv.vars[0]->_.var.vname), SPARP_EQUIV_GET_NAMESAKES);
  if (NULL == eq)
    return 0;
  if (!((eq->e_rvr.rvrRestrictions & SPART_VARR_GLOBAL) || (0 < eq->e_gspo_uses) || (1 < eq->e_nested_bindings)))
    return 0;
  /* The most boring thing is check for duplicate values. It should be as fast as possible and not memory-consuming, so we're cheating. */
  hash_mod = member_binv->_.binv.rows_in_use;
  hash_mod = ((hash_mod * hash_mod * 5) | 0xf) * 8;
  if (hash_mod > sizeof (hash_bits) * 8)
    hash_mod = sizeof (hash_bits) * 8;
  memset (hash_bits, 0, hash_mod/8);
  DO_BOX_FAST (SPART **, row, row_idx, rows)
    {
      SPART *cell;
      id_hashed_key_t hash, hash_sml;
      int row_idx2;
      if ('/' != mask[row_idx])
        continue;
      cell = row[0];
      BINV_CELL_HASH(hash,cell);
      hash_sml = hash % hash_mod;
      if (!(hash_bits[hash_sml >> 3] & (1 << (hash_sml & 0x7))))
        {
          hash_bits[hash_sml >> 3] |= (1 << (hash_sml & 0x7));
          continue;
        }
      for (row_idx2 = row_idx; row_idx2--; /* no step */)
        {
          SPART *cell2;
          id_hashed_key_t hash2;
          if ('/' != mask[row_idx2])
            continue;
          cell2 = rows[row_idx2][0];
          BINV_CELL_HASH(hash2,cell2);
          if (hash2 == hash)
            return 0;
        }
    }
  END_DO_BOX_FAST;
  return 1;
}

#undef BINV_CELL_HASH

void 
spar_binv_to_filter (sparp_t *sparp, SPART *parent_gp, SPART *member_gp, SPART *member_binv)
{
  SPART ***rows = member_binv->_.binv.data_rows;
  char *mask = member_binv->_.binv.data_rows_mask;
  ptrlong arg_ctr = 0, arg_count = member_binv->_.binv.rows_in_use + 1;
  SPART **args = (SPART **)t_alloc_list (arg_count);
  SPART *var_copy, *filt;
  int row_idx, memb_pos;
  var_copy = sparp_tree_full_copy (sparp, member_binv->_.binv.vars[0], parent_gp);
/* Without equiv_idx reset we will get internal error in sparp_gp_attach_filter_cbk(): attempt to attach a filter with used variable */
  var_copy->_.var.selid = parent_gp->_.gp.selid;
  var_copy->_.var.equiv_idx = SPART_BAD_EQUIV_IDX;
  args[arg_ctr++] = var_copy;
  DO_BOX_FAST (SPART **, row, row_idx, rows)
    {
      SPART *cell;
      id_hashed_key_t hash;
      int row_idx2;
      if ('/' != mask[row_idx])
        continue;
      cell = row[0];
      if (arg_ctr >= arg_count)
        spar_internal_error (sparp, "corrupted counter of rows in use in VALUES() clause (too small)");
      args[arg_ctr++] = cell;
    }
  END_DO_BOX_FAST;
  if (arg_ctr != arg_count)
    spar_internal_error (sparp, "corrupted counter of rows in use in VALUES() clause (too big)");
  filt = sparp_make_builtin_call (sparp, IN_L, args);
  filt->srcline = member_binv->srcline;
  memb_pos = box_position ((caddr_t *)(parent_gp->_.gp.members), (caddr_t)member_gp);
  sparp_gp_detach_member (sparp, parent_gp, memb_pos, NULL);
  sparp_gp_attach_filter (sparp, parent_gp, filt, 0, NULL);
}

void
spar_refresh_binv_var_rvrs (sparp_t *sparp, SPART *binv)
{
  int varcount, rowcount, varctr, rowctr;
  if (binv->_.binv.rows_in_use == binv->_.binv.rows_last_rvr)
    return;
  binv->_.binv.rows_last_rvr = binv->_.binv.rows_in_use;
  varcount = BOX_ELEMENTS (binv->_.binv.vars);
  if (0 == binv->_.binv.rows_in_use)
    {
      for (varctr = varcount; varctr--; /* no step */)
        binv->_.binv.vars[varctr]->_.var.rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
      return;
    }
  rowcount = BOX_ELEMENTS (binv->_.binv.data_rows);
  if (1 == binv->_.binv.rows_in_use)
    {
      rowctr = strchr (binv->_.binv.data_rows_mask, '/') - binv->_.binv.data_rows_mask;
      if (0 > rowctr)
        spar_internal_error (sparp, "No used rows but nonzero counter of them");
      for (varctr = varcount; varctr--; /* no step */)
        {
          SPART *var;
          SPART *datum;
          if (binv->_.binv.counters_of_unbound[varctr])
            continue;
          var = binv->_.binv.vars[varctr];
          datum = binv->_.binv.data_rows[rowctr][varctr];
          sparp_rvr_set_by_constant (sparp, &(var->_.var.rvr), NULL, datum);
        }
      return;
    }
  for (varctr = varcount; varctr--; /* no step */)
    {
      SPART *var;
      int restr_set = SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_IS_BLANK | SPART_VARR_IS_LIT | SPART_VARR_NOT_NULL | SPART_VARR_LONG_EQ_SQL;
      if (binv->_.binv.counters_of_unbound[varctr])
        continue;
      var = binv->_.binv.vars[varctr];
      for (rowctr = rowcount; rowctr--; /* no step */)
        {
          SPART *datum;
          if ('/' != binv->_.binv.data_rows_mask[rowctr])
            continue;
          datum = binv->_.binv.data_rows[rowctr][varctr];
          if (NULL == datum)
            spar_internal_error (sparp, "NULL datum in BINDINGS col without expected unbounds");
          switch (SPART_TYPE (datum))
            {
            case SPAR_QNAME:
              restr_set &= ~(SPART_VARR_IS_LIT | SPART_VARR_LONG_EQ_SQL);
              /*                                 0123456789 */
              if (!strncmp (datum->_.qname.val, "nodeID://", 9))
                restr_set &= ~SPART_VARR_IS_IRI;
              else
                restr_set &= ~SPART_VARR_IS_BLANK;
              break;
            case SPAR_LIT:
              {
                dtp_t datum_dtp = DV_TYPE_OF (datum);
                restr_set &= ~(SPART_VARR_IS_REF | SPART_VARR_IS_IRI | SPART_VARR_IS_BLANK);
                if (restr_set & SPART_VARR_LONG_EQ_SQL)
                  {
                    if (DV_ARRAY_OF_POINTER == datum_dtp)
                      datum_dtp = DV_TYPE_OF (datum->_.lit.val);
                    if (!((DV_LONG_INT == datum_dtp) || (DV_DOUBLE_FLOAT == datum_dtp) || (DV_SINGLE_FLOAT == datum_dtp) || (DV_DATETIME == datum_dtp)))
                      restr_set &= ~SPART_VARR_LONG_EQ_SQL;
                  }
                break;
              }
            }
        }
      var->_.var.rvr.rvrRestrictions |= restr_set;
    }
}

int
sparp_check_field_mapping_of_cvalue (sparp_t *sparp, SPART *cvalue, rdf_val_range_t *qmv_or_fmt_rvr, rdf_val_range_t *rvr)
{
  if ((NULL != rvr) && (SPART_VARR_FIXED & rvr->rvrRestrictions))
    {
      if (!sparp_values_equal (sparp, (ccaddr_t)cvalue, NULL, NULL, rvr->rvrFixedValue, rvr->rvrDatatype, rvr->rvrLanguage))
        return SSG_QM_NO_MATCH;
      return SSG_QM_PROVEN_MATCH;
    }
  if (NULL != qmv_or_fmt_rvr)
    {
      if (SPART_VARR_SPRINTFF & qmv_or_fmt_rvr->rvrRestrictions)
        {
          if (!rvr_sprintffs_like ((caddr_t) cvalue, qmv_or_fmt_rvr))
            return SSG_QM_NO_MATCH;
        }
      if (SPART_VARR_FIXED & qmv_or_fmt_rvr->rvrRestrictions)
        {
          if (!sparp_values_equal (sparp, (ccaddr_t)cvalue, NULL, NULL, qmv_or_fmt_rvr->rvrFixedValue, qmv_or_fmt_rvr->rvrDatatype, qmv_or_fmt_rvr->rvrLanguage))
            return SSG_QM_NO_MATCH;
          return SSG_QM_PROVEN_MATCH;
        }
    }
  return SSG_QM_APPROX_MATCH;
}

int
sparp_check_mapping_of_sources (sparp_t *sparp, tc_context_t *tcc,
  rdf_val_range_t *qmv_or_fmt_rvr, rdf_val_range_t *rvr, int invalidation_level )
{
  int min_match = 0xFFFF;
  int source_ctr;
#ifdef DEBUG
  if (!(tcc->tcc_check_source_graphs))
    GPF_T1("Bad invocation of sparp_check_mapping_of_sources()");
#endif
  DO_BOX_FAST (SPART *, source, source_ctr, tcc->tcc_sources)
    {
      int chk_res;
      if (SPART_GRAPH_MIN_NEGATION < source->_.graph.subtype)
        {
          if (NULL == source->_.graph.iri)
            continue;
          if ((NULL != rvr) && (NULL != rvr->rvrFixedValue) &&
            sparp_values_equal (sparp, source->_.graph.iri, NULL, NULL, rvr->rvrFixedValue, rvr->rvrDatatype, rvr->rvrLanguage) )
            return SSG_QM_NO_MATCH;
          if ((NULL != qmv_or_fmt_rvr) && (SPART_VARR_FIXED & qmv_or_fmt_rvr->rvrRestrictions) &&
            sparp_values_equal (sparp, source->_.graph.iri, NULL, NULL, qmv_or_fmt_rvr->rvrFixedValue, qmv_or_fmt_rvr->rvrDatatype, qmv_or_fmt_rvr->rvrLanguage) )
            return SSG_QM_NO_MATCH;
          continue;
        }
      if (tcc->tcc_source_invalidation_masks[source_ctr])
        continue;
      if (NULL == source->_.graph.iri)
        chk_res = ((NULL != rvr->rvrFixedValue) ? SSG_QM_APPROX_MATCH : SSG_QM_PARTIAL_MATCH);
      else
        chk_res = sparp_check_field_mapping_of_cvalue (sparp, (SPART *)(source->_.graph.iri), qmv_or_fmt_rvr, rvr);
      if (SSG_QM_NO_MATCH != chk_res)
        {
          if (chk_res < min_match)
            min_match = chk_res;
        }
      else
        tcc->tcc_source_invalidation_masks[source_ctr] |= (1 << invalidation_level);
    }
  END_DO_BOX_FAST;
  if (0xFFFF == min_match)
    return SSG_QM_NO_MATCH;
  return min_match;
}

ptrdiff_t qm_field_map_offsets[4] = {
  JSO_FIELD_OFFSET(quad_map_t,qmGraphMap),
  JSO_FIELD_OFFSET(quad_map_t,qmSubjectMap),
  JSO_FIELD_OFFSET(quad_map_t,qmPredicateMap),
  JSO_FIELD_OFFSET(quad_map_t,qmObjectMap) };

ptrdiff_t qm_field_const_rvrs_offsets[4] = {
  JSO_FIELD_OFFSET(quad_map_t,qmGraphRange),
  JSO_FIELD_OFFSET(quad_map_t,qmSubjectRange),
  JSO_FIELD_OFFSET(quad_map_t,qmPredicateRange),
  JSO_FIELD_OFFSET(quad_map_t,qmObjectRange) };

int
sparp_check_field_mapping_g (sparp_t *sparp, tc_context_t *tcc, SPART *field,
  quad_map_t *qm, qm_value_t *qmv, rdf_val_range_t *rvr, int invalidation_level )
{
  int source_ctr;
  rdf_val_range_t *qmv_or_fmt_rvr = NULL;
  ptrlong field_type = SPART_TYPE (field);
  if (NULL != qmv)
    {
      if ((SPART_VARR_SPRINTFF | SPART_VARR_FIXED) & qmv->qmvRange.rvrRestrictions)
        qmv_or_fmt_rvr = &(qmv->qmvRange);
      else if (NULL != qmv->qmvFormat)
        {
          if ((SPART_VARR_SPRINTFF | SPART_VARR_FIXED) & qmv->qmvFormat->qmfValRange.rvrRestrictions)
            qmv_or_fmt_rvr = &(qmv->qmvFormat->qmfValRange);
        }
    }
  for (source_ctr = BOX_ELEMENTS_0 (tcc->tcc_sources); source_ctr--; /* no step */)
    tcc->tcc_source_invalidation_masks[source_ctr] &= (1 << invalidation_level) - 1;
  if (tcc->tcc_check_source_graphs)
    {
      int chk_res = sparp_check_mapping_of_sources (sparp, tcc, qmv_or_fmt_rvr, rvr, invalidation_level);
      if (SSG_QM_NO_MATCH == chk_res)
        return SSG_QM_NO_MATCH;
    }
  if (!tcc->tcc_check_source_graphs && (qm != tcc->tcc_qs->qsDefaultMap) &&
    (tcc->tcc_qs->qsMatchingFlags & SPART_QS_NO_IMPLICIT_USER_QM) &&
    (SPAR_BLANK_NODE_LABEL == SPART_TYPE (field)) )
    return SSG_QM_NO_MATCH;
  if ((SPAR_BLANK_NODE_LABEL == field_type) || (SPAR_VARIABLE == field_type))
    {
      if (tcc->tcc_check_source_graphs)
        {
          int chk_res = sparp_check_mapping_of_sources (sparp, tcc, &(field->_.var.rvr), NULL, invalidation_level);
          if (SSG_QM_NO_MATCH == chk_res)
            return SSG_QM_NO_MATCH;
        }
      if (SPART_VARR_FIXED & field->_.var.rvr.rvrRestrictions)
        {
          /*sparp_equiv_t *eq_g = sparp->sparp_sg->sg_equivs[field->_.var.equiv_idx];*/
          int chk_res;
          if (DV_UNAME != DV_TYPE_OF (field->_.var.rvr.rvrFixedValue))
            { /* This would be very strange failure */
#ifdef DEBUG
              GPF_T1 ("sparp_check_field_mapping_g(): non-UNAME fixed value of variable used as graph of a triple. Legal but strange");
#else
              return SSG_QM_NO_MATCH;
#endif
            }
          chk_res = sparp_check_field_mapping_of_cvalue (sparp, (SPART *)(field->_.var.rvr.rvrFixedValue), qmv_or_fmt_rvr, rvr);
          return chk_res;
        }
      if ((NULL != qmv_or_fmt_rvr) && (SPART_VARR_SPRINTFF & qmv_or_fmt_rvr->rvrRestrictions))
        {
          if (SPART_VARR_FIXED & field->_.var.rvr.rvrRestrictions)
            { /* Check if a fixed value of a field variable matches to one of sffs of the mapping value */
              caddr_t fv = rvr_string_fixedvalue (&(field->_.var.rvr));
              if (NULL != fv)
                {
                  int ctr;
                  for (ctr = qmv_or_fmt_rvr->rvrSprintffCount; ctr--; /* no step */)
                    if (sprintff_like (fv, qmv_or_fmt_rvr->rvrSprintffs[ctr]))
                      goto fixed_field_matches_qmv_sff; /* see below */
                  return SSG_QM_NO_MATCH; /* reached if no match found */

fixed_field_matches_qmv_sff: ;
                }
            }
          if (SPART_VARR_SPRINTFF & field->_.var.rvr.rvrRestrictions)
            { /* Check if either of formats of a field variable matches to one of sffs of the mapping value */
              int fld_ctr, qmv_ctr;
/* First pass is optimistic and tries to find an exact equality */
              for (fld_ctr = field->_.var.rvr.rvrSprintffCount; fld_ctr--; /* no step */)
                for (qmv_ctr = qmv_or_fmt_rvr->rvrSprintffCount; qmv_ctr--; /* no step */)
                   if (!strcmp (
                          field->_.var.rvr.rvrSprintffs [fld_ctr],
                          qmv_or_fmt_rvr->rvrSprintffs [qmv_ctr] ) )
                     goto field_sff_isects_qmv_sff;
/* Second pass checks everything, slowly */
              for (fld_ctr = field->_.var.rvr.rvrSprintffCount; fld_ctr--; /* no step */)
                for (qmv_ctr = qmv_or_fmt_rvr->rvrSprintffCount; qmv_ctr--; /* no step */)
                   if (NULL != sprintff_intersect (
                          field->_.var.rvr.rvrSprintffs [fld_ctr],
                          qmv_or_fmt_rvr->rvrSprintffs [qmv_ctr], 1 ) )
                     goto field_sff_isects_qmv_sff;
              return SSG_QM_NO_MATCH; /* reached if no match found */
field_sff_isects_qmv_sff: ;
            }
        }
      if (NULL == rvr->rvrFixedValue)
        return SSG_QM_APPROX_MATCH; /* This is not quite true, but this is the matching rule for EXCLUSIVE */
      return SSG_QM_PARTIAL_MATCH;
    }
  else if ((SPAR_LIT == field_type) || (SPAR_QNAME == field_type))
    {
      int chk_res;
      caddr_t eff_val = SPAR_LIT_OR_QNAME_VAL (field);
      if (DV_UNAME != DV_TYPE_OF (eff_val))
        { /* This would be very-very strange failure */
#ifdef DEBUG
          GPF_T1 ("sparp_check_field_mapping_g(): non-UNAME constant used as graph of a triple, legal but strange");
#else
          return SSG_QM_NO_MATCH;
#endif
        }
      if (tcc->tcc_check_source_graphs)
        {
          rdf_val_range_t fake_rvr;
          memset (&fake_rvr, 0, sizeof (rdf_val_range_t));
          fake_rvr.rvrRestrictions = SPART_VARR_FIXED | SPART_VARR_IS_REF;
          fake_rvr.rvrFixedValue = eff_val;
          chk_res = sparp_check_mapping_of_sources (sparp, tcc, NULL, &fake_rvr, invalidation_level);
          if (SSG_QM_NO_MATCH == chk_res)
            return SSG_QM_NO_MATCH;
        }
      chk_res = sparp_check_field_mapping_of_cvalue (sparp, (SPART *) eff_val, qmv_or_fmt_rvr, rvr);
      return chk_res;
    }
  GPF_T1("ssg_check_field_mapping_g(): field is neither variable nor literal?");
  return SSG_QM_NO_MATCH;
}

int
sparp_check_field_mapping_spo (sparp_t *sparp, tc_context_t *tcc, SPART *field,
  quad_map_t *qm, qm_value_t *qmv, rdf_val_range_t *rvr)
{
  rdf_val_range_t *qmv_or_fmt_rvr = NULL;
  ptrlong field_type = SPART_TYPE (field);
  if (NULL != qmv)
    {
      if ((SPART_VARR_SPRINTFF | SPART_VARR_FIXED) & qmv->qmvRange.rvrRestrictions)
        qmv_or_fmt_rvr = &(qmv->qmvRange);
      else if (NULL != qmv->qmvFormat)
        {
          if ((SPART_VARR_SPRINTFF | SPART_VARR_FIXED | SPART_VARR_IS_LIT | SPART_VARR_IS_REF) & qmv->qmvFormat->qmfValRange.rvrRestrictions)
            qmv_or_fmt_rvr = &(qmv->qmvFormat->qmfValRange);
        }
    }
  if ((SPAR_BLANK_NODE_LABEL == field_type) || (SPAR_VARIABLE == field_type))
    {
      if ((NULL != rvr->rvrFixedValue) && (SPART_VARR_FIXED & field->_.var.rvr.rvrRestrictions))
        { /* Check if a fixed value of a field variable is equal to the constant field of the mapping */
          if (!sparp_rvrs_have_same_fixedvalue (sparp, &(field->_.var.rvr), rvr))
            return SSG_QM_NO_MATCH;
          return SSG_QM_PROVEN_MATCH;
        }
      if ((NULL != qmv_or_fmt_rvr) && (SPART_VARR_SPRINTFF & qmv_or_fmt_rvr->rvrRestrictions))
        {
          if (SPART_VARR_FIXED & field->_.var.rvr.rvrRestrictions)
            { /* Check if a fixed value of a field variable matches to one of sffs of the mapping value */
              caddr_t fv = rvr_string_fixedvalue (&(field->_.var.rvr));
              if (NULL != fv)
                {
                  int ctr;
                  for (ctr = qmv_or_fmt_rvr->rvrSprintffCount; ctr--; /* no step */)
                    if (sprintff_like (fv, qmv_or_fmt_rvr->rvrSprintffs[ctr]))
                      goto fixed_field_matches_qmv_sff; /* see below */
                  return SSG_QM_NO_MATCH; /* reached if no match found */
fixed_field_matches_qmv_sff: ;
                }
            }
          if (SPART_VARR_SPRINTFF & field->_.var.rvr.rvrRestrictions)
            { /* Check if either of formats of a field variable matches to one of sffs of the mapping value */
              int fld_ctr, qmv_ctr;
/* First pass is optimistic and tries to find an exact equality */
              for (fld_ctr = field->_.var.rvr.rvrSprintffCount; fld_ctr--; /* no step */)
                for (qmv_ctr = qmv_or_fmt_rvr->rvrSprintffCount; qmv_ctr--; /* no step */)
                   if (!strcmp (
                          field->_.var.rvr.rvrSprintffs [fld_ctr],
                          qmv_or_fmt_rvr->rvrSprintffs [qmv_ctr] ) )
                     goto field_sff_isects_qmv_sff;
/* Second pass checks everything, slowly */
              for (fld_ctr = field->_.var.rvr.rvrSprintffCount; fld_ctr--; /* no step */)
                for (qmv_ctr = qmv_or_fmt_rvr->rvrSprintffCount; qmv_ctr--; /* no step */)
                   if (NULL != sprintff_intersect (
                          field->_.var.rvr.rvrSprintffs [fld_ctr],
                          qmv_or_fmt_rvr->rvrSprintffs [qmv_ctr], 1 ) )
                     goto field_sff_isects_qmv_sff;
              return SSG_QM_NO_MATCH; /* reached if no match found */
field_sff_isects_qmv_sff: ;
            }
        }
      if (NULL == rvr->rvrFixedValue)
        return SSG_QM_APPROX_MATCH; /* This is not quite true, but this is the matching rule for EXCLUSIVE */
      return SSG_QM_PARTIAL_MATCH;
    }
  else if ((SPAR_LIT == field_type) || (SPAR_QNAME == field_type))
    {
      rdf_val_range_t *some_map_rvr = ((NULL != qmv_or_fmt_rvr) ? qmv_or_fmt_rvr : rvr);
      if (SPAR_LIT == field_type)
        {
          if (SPART_VARR_IS_REF & some_map_rvr->rvrRestrictions)
            return SSG_QM_NO_MATCH;
        }
      else
        {
          if (SPART_VARR_IS_LIT & some_map_rvr->rvrRestrictions)
            return SSG_QM_NO_MATCH;
        }
      if (NULL != rvr->rvrFixedValue)
        {
          if (!sparp_values_equal (sparp, (ccaddr_t)field, NULL, NULL, rvr->rvrFixedValue, rvr->rvrDatatype, rvr->rvrLanguage))
            return SSG_QM_NO_MATCH;
          return SSG_QM_PROVEN_MATCH;
        }
      if ((NULL != qmv_or_fmt_rvr) && (SPART_VARR_SPRINTFF & qmv_or_fmt_rvr->rvrRestrictions))
        {
          caddr_t fv = SPAR_LIT_OR_QNAME_VAL (field);
          if ((NULL != fv) && IS_STRING_DTP (DV_TYPE_OF (fv)))
            {
              int ctr;
              for (ctr = qmv_or_fmt_rvr->rvrSprintffCount; ctr--; /* no step */)
                if (sprintff_like (fv, qmv_or_fmt_rvr->rvrSprintffs[ctr]))
                  return SSG_QM_PROVEN_MATCH;
              return SSG_QM_NO_MATCH; /* reached if no match found */
            }
        }
      return SSG_QM_PROVEN_MATCH;
    }
  else if (SPAR_PPATH == field_type)
    {
      rdf_val_range_t *some_map_rvr = ((NULL != qmv_or_fmt_rvr) ? qmv_or_fmt_rvr : rvr);
      if (SPART_VARR_IS_LIT & some_map_rvr->rvrRestrictions)
        spar_error (sparp, "Bad quap map: its declaration states that the prodicate is literal");
      if ((SPART_VARR_FIXED | SPART_VARR_SPRINTFF) & some_map_rvr->rvrRestrictions)
        spar_error (sparp, "Property path can not be used if service uses quad map rules for some specific predicates");
      return SSG_QM_APPROX_MATCH; /* This may be true or not, we can't make anything better for a property path on a remote service. Let it be the problem of the service. */
    }
  spar_internal_error (sparp, "sparp_" "check_field_mapping_spo(): field is neither variable nor literal?");
  return SSG_QM_NO_MATCH;
}

int
sparp_check_triple_case (sparp_t *sparp, tc_context_t *tcc, quad_map_t *qm, int invalidation_level)
{
  SPART *src_g = tcc->tcc_triple->_.triple.tr_graph;
  SPART *src_s = tcc->tcc_triple->_.triple.tr_subject;
  SPART *src_p = tcc->tcc_triple->_.triple.tr_predicate;
  SPART *src_o = tcc->tcc_triple->_.triple.tr_object;
  int g_match = SSG_QM_UNSET, s_match = SSG_QM_UNSET,
    p_match = SSG_QM_UNSET, o_match = SSG_QM_UNSET;
  if (NULL == qm)
    return SSG_QM_NO_MATCH;
  /* First of all we perform check for cached matches, esp. for failures. */
  if ((NULL != qm->qmGraphMap) && (tcc->tcc_last_qmvs [SPART_TRIPLE_GRAPH_IDX] == qm->qmGraphMap))
    {
      g_match = tcc->tcc_last_qmv_results [SPART_TRIPLE_GRAPH_IDX];
      if (SSG_QM_NO_MATCH == g_match)
        return SSG_QM_NO_MATCH;
    }
  if ((NULL != qm->qmSubjectMap) && (tcc->tcc_last_qmvs [SPART_TRIPLE_SUBJECT_IDX] == qm->qmSubjectMap))
    {
      s_match = tcc->tcc_last_qmv_results [SPART_TRIPLE_SUBJECT_IDX];
      if (SSG_QM_NO_MATCH == s_match)
        return SSG_QM_NO_MATCH;
    }
  if ((NULL != qm->qmPredicateMap) && (tcc->tcc_last_qmvs [SPART_TRIPLE_PREDICATE_IDX] == qm->qmPredicateMap))
    {
      p_match = tcc->tcc_last_qmv_results [SPART_TRIPLE_PREDICATE_IDX];
      if (SSG_QM_NO_MATCH == p_match)
        return SSG_QM_NO_MATCH;
    }
  if ((NULL != qm->qmObjectMap) && (tcc->tcc_last_qmvs [SPART_TRIPLE_OBJECT_IDX] == qm->qmObjectMap))
    {
      o_match = tcc->tcc_last_qmv_results [SPART_TRIPLE_OBJECT_IDX];
      if (SSG_QM_NO_MATCH == o_match)
        return SSG_QM_NO_MATCH;
    }
  /* Check of predicate first, because it's more selective than other */
  if (SSG_QM_UNSET == p_match)
    {
      p_match = sparp_check_field_mapping_spo (sparp, tcc, src_p, qm, qm->qmPredicateMap, &(qm->qmPredicateRange));
      if (NULL != qm->qmPredicateMap)
        {
          tcc->tcc_last_qmvs [SPART_TRIPLE_PREDICATE_IDX] = qm->qmPredicateMap;
          tcc->tcc_last_qmv_results [SPART_TRIPLE_PREDICATE_IDX] = p_match;
        }
      if (SSG_QM_NO_MATCH == p_match)
        return SSG_QM_NO_MATCH;
    }
  /* Check of graph */
  if (SSG_QM_UNSET == g_match)
    {
      g_match = sparp_check_field_mapping_g (sparp, tcc, src_g, qm, qm->qmGraphMap, &(qm->qmGraphRange), invalidation_level);
      if (NULL != qm->qmGraphMap)
        {
          tcc->tcc_last_qmvs [SPART_TRIPLE_GRAPH_IDX] = qm->qmGraphMap;
          tcc->tcc_last_qmv_results [SPART_TRIPLE_GRAPH_IDX] = g_match;
        }
      if (SSG_QM_NO_MATCH == g_match)
        return SSG_QM_NO_MATCH;
    }
  /* Check of subject */
  if (SSG_QM_UNSET == s_match)
    {
      s_match = sparp_check_field_mapping_spo (sparp, tcc, src_s, qm, qm->qmSubjectMap, &(qm->qmSubjectRange));
      if (NULL != qm->qmSubjectMap)
        {
          tcc->tcc_last_qmvs [SPART_TRIPLE_SUBJECT_IDX] = qm->qmSubjectMap;
          tcc->tcc_last_qmv_results [SPART_TRIPLE_SUBJECT_IDX] = s_match;
        }
      if (SSG_QM_NO_MATCH == s_match)
        return SSG_QM_NO_MATCH;
    }
  /* Check of object */
  if (SSG_QM_UNSET == o_match)
    {
      o_match = sparp_check_field_mapping_spo (sparp, tcc, src_o, qm, qm->qmObjectMap, &(qm->qmObjectRange));
      if (NULL != qm->qmObjectMap)
        {
          tcc->tcc_last_qmvs [SPART_TRIPLE_OBJECT_IDX] = qm->qmObjectMap;
          tcc->tcc_last_qmv_results [SPART_TRIPLE_OBJECT_IDX] = o_match;
        }
      if (SSG_QM_NO_MATCH == o_match)
        return SSG_QM_NO_MATCH;
    }
  /* The conclusion */
  if ((SSG_QM_PROVEN_MATCH == g_match) && (SSG_QM_PROVEN_MATCH == s_match) &&
    (SSG_QM_PROVEN_MATCH == p_match) && (SSG_QM_PROVEN_MATCH == o_match) )
    return SSG_QM_PROVEN_MATCH;
  if ((SSG_QM_APPROX_MATCH <= g_match) && (SSG_QM_APPROX_MATCH <= s_match) &&
    (SSG_QM_APPROX_MATCH <= p_match) && (SSG_QM_APPROX_MATCH <= o_match) )
    return SSG_QM_APPROX_MATCH;
  return SSG_QM_PARTIAL_MATCH;
}

int
sparp_qm_find_triple_cases (sparp_t *sparp, tc_context_t *tcc, quad_map_t *qm, int inside_allowed_qm, int invalidation_level)
{
  int ctr, fld_ctr, single_fixed_fld = -1;
  int qm_is_a_good_case = 0;
  int common_status = sparp_check_triple_case (sparp, tcc, qm, invalidation_level);
  if (SSG_QM_NO_MATCH == common_status)
    return SSG_QM_NO_MATCH;
  if (!inside_allowed_qm)
    {
      if (NULL == tcc->tcc_top_allowed_qms)
        inside_allowed_qm = 1;
      else
        {
          for (ctr = BOX_ELEMENTS (tcc->tcc_top_allowed_qms); ctr--; /* no step */)
            {
              if (qm == tcc->tcc_top_allowed_qms[ctr])
                {
                  inside_allowed_qm = 1;
                  break;
                }
            }
        }
    }
  DO_BOX_FAST (quad_map_t *, sub_qm, ctr, qm->qmUserSubMaps)
    {
      int status = sparp_qm_find_triple_cases (sparp, tcc, sub_qm, inside_allowed_qm, invalidation_level+1);
      if (SSG_QM_MATCH_AND_CUT == status)
        return SSG_QM_MATCH_AND_CUT;
    }
  END_DO_BOX_FAST;
  for (;;)
    {
      caddr_t ft_type;
      if (SPART_QM_EMPTY & qm->qmMatchingFlags)
        break; /* not a good case */
      ft_type = tcc->tcc_triple->_.triple.ft_type;
      if (0 != ft_type)
        {
          qm_ftext_t *qmft;
          if (NULL == qm->qmObjectMap)
            break; /* not a good case for ft */
          qmft = (SPAR_FT_TYPE_IS_GEO(ft_type) ? qm->qmObjectMap->qmvGeo : qm->qmObjectMap->qmvFText);
          if (NULL == qmft)
            break; /* not a good case for ft */
        }
      qm_is_a_good_case = 1;
      break;
    }
  if (qm_is_a_good_case)
    {
      triple_case_t *tc = (triple_case_t *)t_alloc (sizeof (triple_case_t));
      tc->tc_qm = qm;
      for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
        {
          if (NULL != tcc->tcc_cuts [fld_ctr])
            tc->tc_red_cuts [fld_ctr] = (ccaddr_t *)t_revlist_to_array (tcc->tcc_cuts [fld_ctr]);
          else
            tc->tc_red_cuts [fld_ctr] = NULL;
        }
      tcc->tcc_nonfiltered_cases_found += 1;
      if (inside_allowed_qm)
        dk_set_push (&(tcc->tcc_found_cases), tc);
    }
  if (SPART_QM_EXCLUSIVE & qm->qmMatchingFlags)
    {
      for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
        {
          rdf_val_range_t *fld_const_rvr = SPARP_FIELD_CONST_RVR_OF_QM (qm, fld_ctr);
          qm_value_t *qmv = SPARP_FIELD_QMV_OF_QM (qm, fld_ctr);
          if (fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED)
            {
              if (-1 == single_fixed_fld)
                {
                  single_fixed_fld = fld_ctr;
                  continue;
                }
              single_fixed_fld = -2;
              break;
            }
          if (NULL != qmv)
            {
              single_fixed_fld = -3;
              break;
            }
        }
      if (0 <= single_fixed_fld)
        {
          rdf_val_range_t *single_fixed_val_rvr = SPARP_FIELD_CONST_RVR_OF_QM (qm, single_fixed_fld);
          dk_set_push (tcc->tcc_cuts + single_fixed_fld, spar_make_qname_or_literal_from_rvr (sparp, single_fixed_val_rvr, 1));
        }
    }
  if ((SSG_QM_PROVEN_MATCH == common_status) && (SPART_QM_SOFT_EXCLUSIVE & qm->qmMatchingFlags))
    return SSG_QM_MATCH_AND_CUT;
  if ((SSG_QM_APPROX_MATCH <= common_status) && (SPART_QM_EXCLUSIVE & qm->qmMatchingFlags))
    return SSG_QM_MATCH_AND_CUT;
  return common_status;
}

triple_case_t **
sparp_find_triple_cases (sparp_t *sparp, SPART *triple, SPART **sources, int required_source_type)
{
  SPART **sinv_idx_and_qms = triple->_.triple.sinv_idx_and_qms;
  caddr_t triple_storage_iri;
  quad_storage_t *triple_storage;
  int ctr, fld_ctr, source_ctr;
  triple_case_t **res_list;
  tc_context_t tmp_tcc;
  if (NULL != sinv_idx_and_qms[0])
    {
      SPART *sinv = SPARP_SINV (sparp, unbox (((caddr_t *)sinv_idx_and_qms)[0]));
      triple_storage_iri = sinv->_.sinv.storage_uri;
      triple_storage = sparp_find_storage_by_name (triple_storage_iri);
      if (NULL == triple_storage)
        spar_internal_error (sparp, "quad storage metadata are lost");
      if ((SPART **)((ptrlong)(_STAR)) == sources)
        sources = sinv->_.sinv.sources;
    }
  else
    {
      triple_storage_iri = sparp->sparp_env->spare_storage_name;
      triple_storage = sparp->sparp_storage;
      if ((SPART **)((ptrlong)(_STAR)) == sources)
        sources = sparp->sparp_stp->stp_trav_req_top->_.req_top.sources;
    }
  if (NULL == triple_storage)
    {
      triple_case_t **res_list = (triple_case_t **)t_list (1, tc_default);
      mp_box_tag_modify (res_list, DV_ARRAY_OF_LONG);
      return res_list;
    }
  memset (&tmp_tcc, 0, sizeof (tc_context_t));
  tmp_tcc.tcc_triple = triple;
  tmp_tcc.tcc_qs = triple_storage;
  tmp_tcc.tcc_sources = sources;
  tmp_tcc.tcc_source_invalidation_masks = (uint32 *)t_alloc_box (sizeof (uint32) * BOX_ELEMENTS (sources), DV_BIN);
  DO_BOX_FAST (SPART *, source, source_ctr, tmp_tcc.tcc_sources)
    {
      if ((0 == required_source_type) || ((source->_.graph.subtype & ~SPART_GRAPH_GROUP_BIT) == required_source_type))
        {
          tmp_tcc.tcc_check_source_graphs++;
          tmp_tcc.tcc_source_invalidation_masks[source_ctr] = 0;
        }
      else if (!((SPART_GRAPH_NOT_FROM == source->_.graph.subtype) ||
          (SPART_GRAPH_NOT_NAMED == source->_.graph.subtype) ) )
        tmp_tcc.tcc_source_invalidation_masks[source_ctr] = 0x1;
    }
  END_DO_BOX_FAST;
  if ((SPART *)((ptrlong)_STAR) == sinv_idx_and_qms[1])
    tmp_tcc.tcc_top_allowed_qms = NULL;
  else
    {
      tmp_tcc.tcc_top_allowed_qms = (quad_map_t **)t_alloc_list (BOX_ELEMENTS (sinv_idx_and_qms)-1);
      for (ctr = BOX_ELEMENTS(tmp_tcc.tcc_top_allowed_qms); ctr--; /* no step */)
        {
          caddr_t triple_qm_iri = (caddr_t)(sinv_idx_and_qms[ctr + 1]);
          if (((caddr_t)DEFAULT_L) == triple_qm_iri)
            {
              if (NULL == triple_storage->qsDefaultMap)
                spar_error (sparp, "QUAD MAP DEFAULT group pattern is used in RDF storage '%.200s' that has no default quad map", triple_storage_iri);
              tmp_tcc.tcc_top_allowed_qms[ctr] = triple_storage->qsDefaultMap;
            }
          else
            {
              quad_map_t *top_qm = sparp_find_quad_map_by_name (triple_qm_iri);
              if (NULL == top_qm)
                spar_error (sparp, "QUAD MAP '%.200s' group pattern refers to undefined quad map", triple_qm_iri);
              tmp_tcc.tcc_top_allowed_qms[ctr] = top_qm;
            }
        }
    }
  DO_BOX_FAST (quad_map_t *, qm, ctr, triple_storage->qsMjvMaps)
    {
      int status;
      if (0 != BOX_ELEMENTS_0 (qm->qmUserSubMaps))
        spar_error (sparp, "RDF quad mapping metadata are corrupted: MJV has submaps; the quad storage '%.200s' used in the query should be configured again", triple_storage_iri);
      if (SPART_QM_EMPTY & qm->qmMatchingFlags)
        spar_error (sparp, "RDF quad mapping metadata are corrupted: MJV is declared as empty; the quad storage '%.200s' used in the query should be configured again", triple_storage_iri);
      status = sparp_qm_find_triple_cases (sparp, &tmp_tcc, qm, 0, 1);
      if (SSG_QM_MATCH_AND_CUT == status)
        goto full_exclusive_match_detected;
    }
  END_DO_BOX_FAST;
  DO_BOX_FAST (quad_map_t *, qm, ctr, triple_storage->qsUserMaps)
    {
      int status = sparp_qm_find_triple_cases (sparp, &tmp_tcc, qm, 0, 1);
      if (SSG_QM_MATCH_AND_CUT == status)
        goto full_exclusive_match_detected;
    }
  END_DO_BOX_FAST;
  if (NULL != triple_storage->qsDefaultMap)
    sparp_qm_find_triple_cases (sparp, &tmp_tcc, triple_storage->qsDefaultMap, 0, 1);

full_exclusive_match_detected:
#if 0
  if (NULL == tmp_tcc.tcc_found_cases)
    spar_internal_error (sparp, "Empty quad map list :(");
#else
#ifdef DEBUG
  if (NULL == tmp_tcc.tcc_found_cases)
    {
      printf ("Empty quad map list:");
      printf ("\nStorage : "); dbg_print_box (triple_storage_iri, stdout);
      printf ("\nGraph   : "); dbg_print_box ((caddr_t)(triple->_.triple.tr_graph), stdout);
      printf ("\nSubj    : "); dbg_print_box ((caddr_t)(triple->_.triple.tr_subject), stdout);
      printf ("\nPred    : "); dbg_print_box ((caddr_t)(triple->_.triple.tr_predicate), stdout);
      printf ("\nObj     : "); dbg_print_box ((caddr_t)(triple->_.triple.tr_object), stdout);
      printf ("\n");
    }
#endif
#endif
  res_list = (triple_case_t **)t_revlist_to_array (tmp_tcc.tcc_found_cases);
  mp_box_tag_modify (res_list, DV_ARRAY_OF_LONG);
  while (tmp_tcc.tcc_found_cases) dk_set_pop (&(tmp_tcc.tcc_found_cases));
  for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
    {
      dk_set_t cuts = tmp_tcc.tcc_cuts[fld_ctr];
      while (cuts) dk_set_pop (&cuts);
    }
  return res_list;
}

void
sparp_refresh_triple_cases (sparp_t *sparp, SPART **sources, SPART *triple)
{
  /*ssg_valmode_t valmodes[SPART_TRIPLE_FIELDS_COUNT];*/
  triple_case_t **new_cases;
  int old_cases_count, new_cases_count, ctr;
  int field_ctr;
  SPART *graph;
  int graph_type;
  int required_source_type;
  old_cases_count = BOX_ELEMENTS_0 (triple->_.triple.tc_list);
  if ((0 < old_cases_count) && (4 > old_cases_count))
    return;
  graph = triple->_.triple.tr_graph;
  graph_type = SPART_TYPE(graph);
  required_source_type = ((SPAR_VARIABLE == graph_type) ? SPART_GRAPH_NAMED : ((SPAR_BLANK_NODE_LABEL == graph_type) ? SPART_GRAPH_FROM : 0));
  new_cases = sparp_find_triple_cases (sparp, triple, sources, required_source_type);
  new_cases_count = BOX_ELEMENTS (new_cases);
  if ((NULL == triple->_.triple.tc_list) &&
    (0 == new_cases_count) &&
    sparp->sparp_sg->sg_signal_void_variables )
    spar_error (sparp, "No one quad map pattern is suitable for GRAPH %s { %s %s %s } triple at line %ld",
      spar_dbg_string_of_triple_field (sparp, graph),
      spar_dbg_string_of_triple_field (sparp, triple->_.triple.tr_subject),
      spar_dbg_string_of_triple_field (sparp, triple->_.triple.tr_predicate),
      spar_dbg_string_of_triple_field (sparp, triple->_.triple.tr_object),
      (long)unbox (triple->srcline));
  for (field_ctr = SPART_TRIPLE_FIELDS_COUNT; field_ctr--; /*no step*/)
    {
      ssg_valmode_t field_valmode = SSG_VALMODE_AUTO;
      SPART *field_expn = triple->_.triple.tr_fields[field_ctr];
      rdf_val_range_t acc_rvr;
      int all_cases_make_only_refs = 1;
      int sqlval_is_ok_and_cheap = 0x2;
      memset (&acc_rvr, 0, sizeof (rdf_val_range_t));
      acc_rvr.rvrRestrictions = SPART_VARR_CONFLICT;
      for (ctr = 0; ctr < new_cases_count; ctr++)
        {
          triple_case_t *tc = new_cases [ctr];
          qm_value_t *qmv = SPARP_FIELD_QMV_OF_QM (tc->tc_qm, field_ctr);
          rdf_val_range_t *fld_const_rvr = SPARP_FIELD_CONST_RVR_OF_QM (tc->tc_qm, field_ctr);
          ccaddr_t *red_cuts = tc->tc_red_cuts [field_ctr];
          rdf_val_range_t qmv_rvr;
          if (NULL != qmv)
            {
              qm_format_t *qmv_fmt = qmv->qmvFormat;
              if (all_cases_make_only_refs && !(SPART_VARR_IS_REF & qmv_fmt->qmfValRange.rvrRestrictions))
                all_cases_make_only_refs = 0;
              field_valmode = ssg_smallest_union_valmode (field_valmode, qmv_fmt, &sqlval_is_ok_and_cheap);
              sparp_rvr_copy (sparp, &qmv_rvr, &(qmv->qmvRange));
              if (SPART_VARR_SPRINTFF & qmv_fmt->qmfValRange.rvrRestrictions)
                {
                  qmv_rvr.rvrRestrictions |= SPART_VARR_SPRINTFF;
                  sparp_rvr_add_sprintffs (sparp, &qmv_rvr, qmv_fmt->qmfValRange.rvrSprintffs, qmv_fmt->qmfValRange.rvrSprintffCount);
                }
              if ((NULL != qmv->qmvIriClass) &&
                !(SPART_VARR_IRI_CALC & qmv_rvr.rvrRestrictions) &&
                (SPART_VARR_IS_REF & qmv->qmvFormat->qmfValRange.rvrRestrictions) )
                {
                  qmv_rvr.rvrRestrictions |= SPART_VARR_IRI_CALC;
                  sparp_rvr_add_iri_classes (sparp, &qmv_rvr, &(qmv->qmvIriClass), 1);
                }
              sparp_rvr_intersect_red_cuts (sparp, &qmv_rvr, red_cuts, BOX_ELEMENTS_0 (red_cuts));
            }
          else if (fld_const_rvr->rvrRestrictions & SPART_VARR_FIXED)
            {
              if (NULL != qmv)
                spar_internal_error (sparp, "Invalid quad map storage metadata: quad map has set both quad map value and a constant for same field.");
#ifdef DEBUG
              if ((SPART_TRIPLE_GRAPH_IDX == field_ctr) && (DV_UNAME != DV_TYPE_OF (fld_const_rvr->rvrFixedValue)))
                GPF_T1("sparp_" "refresh_triple_cases(): const GRAPH field of qm is not a UNAME");
#endif
              sparp_rvr_copy (sparp, &qmv_rvr, fld_const_rvr);
              if (all_cases_make_only_refs && !(fld_const_rvr->rvrRestrictions & SPART_VARR_IS_REF))
                all_cases_make_only_refs = 0;
            }
          else
            spar_internal_error (sparp, "Invalid quad map storage metadata: neither quad map value nor a constant is set for a field of a quad map.");
          if (NULL != qmv)
            {
              if (qmv->qmvFormat->qmfValRange.rvrSprintffCount)
                {
#ifdef DEBUG
                  if (!(qmv->qmvFormat->qmfValRange.rvrRestrictions & SPART_VARR_SPRINTFF))
                    dbg_printf (("sparp_" "refresh_triple_cases(): qmvFormat %s has rvrSprintffCount but not SPART_VARR_SPRINTFF\n", qmv->qmvFormat->qmfName));
#endif
                  qmv->qmvFormat->qmfValRange.rvrRestrictions |= SPART_VARR_SPRINTFF;
                }
              sparp_rvr_tighten (sparp, &qmv_rvr, &(qmv->qmvFormat->qmfValRange), ~SPART_VARR_IRI_CALC);
            }
          sparp_rvr_loose (sparp, &acc_rvr, &qmv_rvr, ~0);
        }
      if ((all_cases_make_only_refs || sqlval_is_ok_and_cheap) && (SSG_VALMODE_LONG == field_valmode))
        field_valmode = SSG_VALMODE_SQLVAL;
      sparp_jso_validate_format (sparp, field_valmode);
      triple->_.triple.native_formats[field_ctr] = field_valmode;
      if (SPAR_IS_BLANK_OR_VAR (field_expn))
        {
          int restr_of_col_mask = ~(SPART_VARR_EXTERNAL | SPART_VARR_GLOBAL);
          if (OPTIONAL_L == triple->_.triple.subtype)
            restr_of_col_mask &= ~SPART_VARR_NOT_NULL;
          if (acc_rvr.rvrRestrictions & SPART_VARR_CONFLICT)
            {
              SPARP_DEBUG_WEIRD(sparp,"conflict");
            }
          sparp_rvr_tighten (sparp, &(field_expn->_.var.rvr), &acc_rvr, restr_of_col_mask);
/* The specific purpose of the field is a differentiation of what should be tested somewhere in the resulting SQL query
and what is a natural property of the data source.
Before introduction of ASSUME() trick, var.restr_of_col was set with "=", not "|=" or "&=" because it may come from only one qmv or a union of qmvs.
There was no "history" or "derived properties" here.
With ASSUME(), "|=" is needed instead of "=", because some bits can be set by ASSUME() and the initial value is no longer zero */
          field_expn->_.var.restr_of_col |= acc_rvr.rvrRestrictions & restr_of_col_mask;
        }
    }
  triple->_.triple.tc_list = new_cases;
}

int
sparp_detach_conflicts (sparp_t *sparp, SPART *parent_gp)
{
  int memb_ctr;
  DO_BOX_FAST_REV (SPART *, memb, memb_ctr, parent_gp->_.gp.members)
    { /* countdown direction of 'for' is important due to possible removals */
      int eq_ctr;
      if (SPAR_GP != memb->type)
        continue;
      switch (memb->_.gp.subtype)
        {
        case OPTIONAL_L:
          SPARP_FOREACH_GP_EQUIV (sparp, memb, eq_ctr, eq)
            {
              if ((SPART_VARR_CONFLICT & eq->e_rvr.rvrRestrictions) &&
                (SPART_VARR_NOT_NULL & eq->e_rvr.rvrRestrictions) )
                goto do_detach_memb; /* see below */
            }
          END_SPARP_FOREACH_GP_EQUIV;
          continue;
        case UNION_L: case SPAR_UNION_WO_ALL:
          if (0 == BOX_ELEMENTS_0 (memb->_.gp.members))
            goto do_detach_memb; /* see below */
          continue;
        default:
          SPARP_FOREACH_GP_EQUIV (sparp, memb, eq_ctr, eq)
            {
              if (((SPART_VARR_CONFLICT | SPART_VARR_ALWAYS_NULL) & eq->e_rvr.rvrRestrictions) &&
                (SPART_VARR_NOT_NULL & eq->e_rvr.rvrRestrictions) )
                goto do_detach_or_zap; /* see below */
            }
          END_SPARP_FOREACH_GP_EQUIV;
          continue;
        }
do_detach_or_zap:
      if ((UNION_L != parent_gp->_.gp.subtype) && (SPAR_UNION_WO_ALL != parent_gp->_.gp.subtype))
        {
          sparp_gp_produce_nothing (sparp, parent_gp);
          return 1;
        }
do_detach_memb:
      sparp_gp_detach_member (sparp, parent_gp, memb_ctr, NULL);
      sparp_gp_deprecate (sparp, memb, 1);
    }
  END_DO_BOX_FAST_REV;
  return 0;
}

void
sparp_flatten_union (sparp_t *sparp, SPART *parent_gp)
{
  int memb_ctr;
#ifdef DEBUG
  if (SPAR_GP != SPART_TYPE (parent_gp))
    spar_internal_error (sparp, "sparp_" "flatten_union(): parent_gp is not a GP");
  if ((UNION_L != parent_gp->_.gp.subtype) && (SPAR_UNION_WO_ALL != parent_gp->_.gp.subtype))
    spar_internal_error (sparp, "sparp_" "flatten_union(): parent_gp is not a union");
#endif
  for (memb_ctr = BOX_ELEMENTS (parent_gp->_.gp.members); memb_ctr--; /*no step*/)
    {
      SPART *memb = parent_gp->_.gp.members [memb_ctr];
      if ((SPAR_GP == SPART_TYPE (memb)) &&
        (0 == BOX_ELEMENTS_0 (memb->_.gp.filters)) && /* This condition might be commented out if memb_filters and memb_filters_count below are uncommented */
        (NULL == memb->_.gp.options) &&
        ((parent_gp->_.gp.subtype == memb->_.gp.subtype) ||
          ((0 == memb->_.gp.subtype) &&
            (1 == BOX_ELEMENTS (memb->_.gp.members)) &&
            (SPAR_GP == SPART_TYPE (memb->_.gp.members[0])) ) ) )
        {
          int sub_count = BOX_ELEMENTS (memb->_.gp.members);
          int sub_ctr;
          /* SPART **memb_filters = sparp_gp_detach_all_filters (sparp, memb, 1, NULL); */
          /* int memb_filters_count = BOX_ELEMENTS_0 (memb_filters); */
          for (sub_ctr = sub_count; sub_ctr--; /* no step */)
            {
              SPART *sub_memb = sparp_gp_detach_member (sparp, memb, sub_ctr, NULL);
              sparp_gp_attach_member (sparp, parent_gp, sub_memb, memb_ctr, NULL);
              /* if (0 != memb_filters_count)
                sparp_gp_attach_many_filters (sparp, sub_memb, sparp_treelist_full_copy (sparp, memb_filters, NULL), 0, NULL); */
            }
          memb_ctr += sub_count;
          sparp_gp_detach_member (sparp, parent_gp, memb_ctr, NULL);
          sparp_gp_deprecate (sparp, memb, 0);
        }
    }
}


void
sparp_flatten_join (sparp_t *sparp, SPART *parent_gp)
{
  int memb_ctr, eq_ctr;
#ifdef DEBUG
  if (SPAR_GP != SPART_TYPE (parent_gp))
    spar_internal_error (sparp, "sparp_" "flatten_join(): parent_gp is not a GP");
  if ((UNION_L == parent_gp->_.gp.subtype) || (SPAR_UNION_WO_ALL == parent_gp->_.gp.subtype) || (SELECT_L == parent_gp->_.gp.subtype) || (VALUES_L == parent_gp->_.gp.subtype))
    spar_internal_error (sparp, "sparp_" "flatten_join(): parent_gp is not a join");
#endif
  SPARP_FOREACH_GP_EQUIV (sparp, parent_gp, eq_ctr, eq)
    {
      if ((SPART_VARR_NOT_NULL & eq->e_rvr.rvrRestrictions) && !SPARP_EQ_IS_ASSIGNED_BY_CONTEXT(eq)
        && (0 == eq->e_gspo_uses) && (1 == BOX_ELEMENTS_0 (eq->e_subvalue_idxs)) )
        {
          sparp_equiv_t *sub_eq = SPARP_EQUIV (sparp, eq->e_subvalue_idxs[0]);
          if (OPTIONAL_L == sub_eq->e_gp->_.gp.subtype)
            {
              sub_eq->e_gp->_.gp.subtype = 0;
              sparp->sparp_rewrite_dirty++;
            }
        }
    }
  END_SPARP_FOREACH_GP_EQUIV;
  for (memb_ctr = BOX_ELEMENTS (parent_gp->_.gp.members); memb_ctr--; /*no step*/)
    {
      SPART *memb = parent_gp->_.gp.members [memb_ctr];
      SPART **memb_filters;
      int sub_count;
      int sub_ctr;
      int memb_filters_count;
      if (SPAR_GP != SPART_TYPE (memb))
        continue; /* It's plain triple, it can't be simpler than that */
      if (OPTIONAL_L == memb->_.gp.subtype)
        break; /* No optimizations at left of LEFT OUTER JOIN. */
      if (NULL != memb->_.gp.options)
        continue; /* Members with options can not be optimized */
      sub_count = BOX_ELEMENTS (memb->_.gp.members);
      if (((UNION_L == memb->_.gp.subtype) || (SPAR_UNION_WO_ALL == memb->_.gp.subtype)) && (1 == sub_count))
        goto just_remove_braces; /* see below */
      if (0 == memb->_.gp.subtype)
        {
          int memb_equiv_inx;
          int first_conflicting_predecessor_idx;
          int first_optional_sub_memb_pos;
          if (0 == sub_count)
            {
              sparp_gp_produce_nothing (sparp, parent_gp);
              return;
            }
          if (0 == memb_ctr)
            goto just_remove_braces; /* see below */
/* First member can always be flatten. For others, there is an exception.
If a member in question contains OPTIONAL then flattening will change the left member of left outer join.
This may change semantics if an OPTIONAL contains a variable that is nullable in the member but present in members before the current. */
          first_optional_sub_memb_pos = -1;
          for (sub_ctr = 0; sub_ctr < sub_count; sub_ctr++)
            {
              SPART *sub_memb = memb->_.gp.members [sub_ctr];
              if ((SPAR_GP != SPART_TYPE(sub_memb)) || (OPTIONAL_L != sub_memb->_.gp.subtype))
                continue;
              first_optional_sub_memb_pos = sub_ctr;
              break;
            }
          if (-1 == first_optional_sub_memb_pos)
            goto just_remove_braces; /* see below */
          first_conflicting_predecessor_idx = -1; /* No conflicts if there are no OPTIONALs in the member, btw. */
          SPARP_FOREACH_GP_EQUIV (sparp, memb, memb_equiv_inx, memb_eq)
            {
              int parent_conn_ctr;
              if (SPART_VARR_NOT_NULL & memb_eq->e_rvr.rvrRestrictions)
                continue;
              DO_BOX_FAST (ptrlong, parent_equiv_idx, parent_conn_ctr, memb_eq->e_receiver_idxs)
                {
                  sparp_equiv_t *parent_equiv = SPARP_EQUIV (sparp, parent_equiv_idx);
                  int preceding_memb_ctr;
                  for (preceding_memb_ctr = memb_ctr-1; preceding_memb_ctr > first_conflicting_predecessor_idx; preceding_memb_ctr--)
                    {
                      SPART *preceding_memb = parent_gp->_.gp.members [preceding_memb_ctr];
                      if (sparp_tree_uses_var_of_eq (sparp, preceding_memb, parent_equiv))
                        {
                          first_conflicting_predecessor_idx = preceding_memb_ctr;
                          break;
                        }
                    }
                }
              END_DO_BOX_FAST;
            }
          END_SPARP_FOREACH_GP_EQUIV;
          if (-1 == first_conflicting_predecessor_idx)
            goto just_remove_braces; /* see below */
#if 0
/* If there are things between first conflicting predecessor and the  */
          if ((memb_ctr-1) == first_conflicting_predecessor_idx)
            continue;
/*!!! TBD: moving members from first_conflicting_predecessor_idx+1 to memb_ctr-1 inclusive into left part of memb if appropriate */
#endif
        }
      continue;

just_remove_braces:
      if (0 != memb->_.gp.glued_filters_count)
        {
          int glued_last_idx = BOX_ELEMENTS (memb->_.gp.filters);
          int glued_first_idx = glued_last_idx - memb->_.gp.glued_filters_count;
          sparp_equiv_t *suspicious_filt_eq = NULL;
          dk_set_t distint_varnames_of_glued_filters = NULL;
          int glued_idx, memb_equiv_inx;
          if (parent_gp->_.gp.glued_filters_count)
            continue; /* Don't know how to safely mix two lists of glued filters, one already in parent and one from member, hence the sabotage */
          for (glued_idx = glued_first_idx; glued_idx < glued_last_idx; glued_idx++)
            {
              SPART *glued_filt = memb->_.gp.filters[glued_idx];
              sparp_distinct_varnames_of_tree (sparp, glued_filt, &distint_varnames_of_glued_filters);
            }
/* Consider a glued filter in memb that refers to ?x . ?x may present in memb or not, it may also present in parent_gp or not.
?x in memb	| ?x in parent	| Can filter be moved?
Yes & bound	| Yes & bound	| These two are equal due to join so filter can be moved
Yes & bound	| Yes & !bound	| Empty join, filter does not matter, so it can be moved
Yes & bound	| No		| Safe to move, the only occurence will define the value as it was
Yes & !bound	| Yes & bound	| Empty join, filter does not matter, so it can be moved
Yes & !bound	| Yes & !bound	| Empty join, filter does not matter, so it can be moved
Yes & !bound	| No		| Safe to move, the only occurence will define the value as it was
No		| Yes & bound	| !!! Can't move, not bound may become bound
No		| Yes & !bound	| Safe to move, unbound anyway
No		| No		| Safe to move, unbound anyway
So the only unsafe case is a fixed filter on a variable that is missing where the filter resides but present at the parent.
*/
          SPARP_FOREACH_GP_EQUIV (sparp, memb, memb_equiv_inx, memb_eq)
            {
              int parent_conn_ctr;
              if (SPART_VARR_NOT_NULL & memb_eq->e_rvr.rvrRestrictions)
                continue;
              if ((0 == memb_eq->e_const_reads) && (0 == memb_eq->e_optional_reads))
                continue; /* No reads guarantees no uses in glued filters */
              DO_BOX_FAST (ptrlong, parent_equiv_idx, parent_conn_ctr, memb_eq->e_receiver_idxs)
                {
                  sparp_equiv_t *parent_equiv = SPARP_EQUIV (sparp, parent_equiv_idx);
                  int varname_ctr;
                  DO_BOX_FAST (caddr_t, varname, varname_ctr, parent_equiv->e_varnames)
                    {
                      if (dk_set_position_of_string (distint_varnames_of_glued_filters, varname))
                        {
                          suspicious_filt_eq = memb_eq;
                          goto suspicious_filt_eq_found; /* see below */
                        }
                    }
                  END_DO_BOX_FAST;
                }
              END_DO_BOX_FAST;
            }
          END_SPARP_FOREACH_GP_EQUIV;
suspicious_filt_eq_found:
          if (NULL != suspicious_filt_eq)
            continue;
          for (glued_idx = glued_first_idx; glued_idx < glued_last_idx; glued_idx++)
            {
              SPART *filt = sparp_gp_detach_filter (sparp, memb, glued_first_idx, NULL);
              sparp_gp_attach_filter (sparp, parent_gp, filt, BOX_ELEMENTS (parent_gp->_.gp.filters), NULL);
            }
          parent_gp->_.gp.glued_filters_count += (glued_last_idx - glued_first_idx);
        }
      memb_filters = sparp_gp_detach_all_filters (sparp, memb, 1, NULL);
      memb_filters_count = BOX_ELEMENTS_0 (memb_filters);
      for (sub_ctr = sub_count; sub_ctr--; /* no step */)
        {
          SPART *sub_memb = sparp_gp_detach_member (sparp, memb, sub_ctr, NULL);
          sparp_gp_attach_member (sparp, parent_gp, sub_memb, memb_ctr, NULL);
        }
      if (0 != memb_filters_count)
        sparp_gp_attach_many_filters (sparp, parent_gp, memb_filters /*!!! should it be sparp_treelist_full_copy (sparp, memb_filters, NULL) ? */, 0, NULL);
      memb_ctr += sub_count;
      sparp_gp_tighten_by_eq_replaced_filters (sparp, parent_gp, memb, 1);
      sparp_gp_detach_member (sparp, parent_gp, memb_ctr, NULL);
      sparp_gp_deprecate (sparp, memb, 0);
    }
}

void
sparp_set_options_selid_and_tabid (sparp_t *sparp, SPART **options, caddr_t new_selid, caddr_t new_tabid)
{
  int ctr;
  DO_BOX_FAST_REV (SPART *, opt_expn, ctr, options)
    {
      switch (SPART_TYPE (opt_expn))
        {
        case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
          if (strcmp (opt_expn->_.var.selid, new_selid)) /* weird re-location */
            {
              if (SPART_BAD_EQUIV_IDX != opt_expn->_.var.equiv_idx)
                {
                  sparp_equiv_t *eq = SPARP_EQUIV (sparp, opt_expn->_.var.equiv_idx);
                  sparp_equiv_remove_var (sparp, eq, opt_expn);
                }
              opt_expn->_.var.selid = /*t_box_copy*/ (new_selid);
            }
          if (NULL != opt_expn->_.var.tabid)
            opt_expn->_.var.tabid = /*t_box_copy*/ (new_tabid);
          break;
        case SPAR_LIST:
          sparp_set_options_selid_and_tabid (sparp, opt_expn->_.list.items, new_selid, new_tabid);
          break;
        }
    }
  END_DO_BOX_FAST_REV;
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
          fld_expn->_.var.selid = /*t_box_copy*/ (new_selid);
        }
      fld_expn->_.var.tabid = /*t_box_copy*/ (new_tabid);
    }
  if (NULL != triple->_.triple.options)
    sparp_set_options_selid_and_tabid (sparp, triple->_.triple.options, new_selid, new_tabid);
  triple->_.triple.selid = /*t_box_copy*/ (new_selid);
  triple->_.triple.tabid = /*t_box_copy*/ (new_tabid);
}

int
sparp_expns_are_equal (sparp_t *sparp, SPART *one, SPART *two)
{
  ptrlong one_type = SPART_TYPE (one);
  if (one == two)
    return 1;
  if (SPART_TYPE (two) != one_type)
    return 0;
  switch (one_type)
    {
    case SPAR_BLANK_NODE_LABEL: case SPAR_VARIABLE:
      return !strcmp (one->_.var.vname, two->_.var.vname);
    case SPAR_QNAME: /* case SPAR_QNAME_NS: */
      return sparp_expns_are_equal (sparp, (SPART *)(one->_.lit.val), (SPART *)(two->_.lit.val));
    case SPAR_LIT:
      if (DV_TYPE_OF (one) != DV_TYPE_OF (two))
        return 0;
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (one))
        return (DVC_MATCH == cmp_boxes ((caddr_t)one, (caddr_t)two, NULL, NULL));
      else
        return (
          sparp_expns_are_equal (sparp, (SPART *)(one->_.lit.val), (SPART *)(two->_.lit.val)) &&
          sparp_expns_are_equal (sparp, (SPART *)(one->_.lit.datatype), (SPART *)(two->_.lit.datatype)) &&
          sparp_expns_are_equal (sparp, (SPART *)(one->_.lit.language), (SPART *)(two->_.lit.language)) );
    case SPAR_BUILT_IN_CALL:
      return (
        (one->_.builtin.btype == two->_.builtin.btype) &&
        sparp_expn_lists_are_equal (sparp, one->_.builtin.args, two->_.builtin.args) );
    case SPAR_FUNCALL:
      return (
        (one->_.funcall.agg_mode == two->_.funcall.agg_mode) &&
        !strcmp (one->_.funcall.qname, two->_.funcall.qname) &&
        sparp_expn_lists_are_equal (sparp, one->_.funcall.argtrees, two->_.funcall.argtrees) );
    case SPAR_GP:
      return !strcmp (one->_.gp.selid, two->_.gp.selid); /*!!!TBD: this check is good enough for TPC-D Q16. Do we need more accurate check? */
     case BOP_EQ: case SPAR_BOP_EQNAMES: case SPAR_BOP_EQ_NONOPT: case BOP_NEQ:
    case BOP_AND: case BOP_OR:
    case BOP_SAME: case BOP_NSAME:
      return (
        ( sparp_expns_are_equal (sparp, one->_.bin_exp.left, two->_.bin_exp.left) &&
          sparp_expns_are_equal (sparp, one->_.bin_exp.right, two->_.bin_exp.right) ) ||
        ( sparp_expns_are_equal (sparp, one->_.bin_exp.left, two->_.bin_exp.right) &&
          sparp_expns_are_equal (sparp, one->_.bin_exp.right, two->_.bin_exp.left) ) );
    case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
    /*case BOP_LIKE: Like is built-in in SPARQL, not a BOP! */
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
      return (
        sparp_expns_are_equal (sparp, one->_.bin_exp.left, two->_.bin_exp.left) &&
        sparp_expns_are_equal (sparp, one->_.bin_exp.right, two->_.bin_exp.right) );
    case BOP_NOT:
      return sparp_expns_are_equal (sparp, one->_.bin_exp.left, two->_.bin_exp.left);
/* Add more cases right above this line when introducing more SPAR_nnn constants that may appear inside expression */
    default: spar_internal_error (sparp, "sparp_" "expns_are_equal () get expression of unsupported type");
    }
  GPF_T;
  return 0;
}

int
sparp_expn_lists_are_equal (sparp_t *sparp, SPART **one, SPART **two)
{
  int ctr, one_len = BOX_ELEMENTS_0 (one);
  if (BOX_ELEMENTS_0 (two) != one_len)
    return 0;
  for (ctr = 0; ctr < one_len; ctr++)
    {
      if (!sparp_expns_are_equal (sparp, one[ctr], two[ctr]))
        return 0;
    }
  return 1;
}

SPART **
sparp_make_qm_cases (sparp_t *sparp, SPART *triple, SPART *parent_gp, SPART *ft_cond_to_relocate)
{
  triple_case_t **tc_list = triple->_.triple.tc_list;
  SPART **res;
  int tc_idx;
#ifdef DEBUG
  if (1 >= BOX_ELEMENTS (triple->_.triple.tc_list))
    spar_internal_error (sparp, "sparp_" "make_qm_cases(): redundant call");
#endif
  res = (SPART **)t_alloc_box (box_length (tc_list), DV_ARRAY_OF_POINTER);
  DO_BOX_FAST (triple_case_t *, tc, tc_idx, tc_list)
    {
      quad_map_t * qm = tc->tc_qm;
      int field_ctr;
      SPART *qm_case_triple = (SPART *)t_box_copy ((caddr_t)triple);
      SPART *qm_case_gp = sparp_new_empty_gp (sparp, 0, unbox (triple->srcline));
      caddr_t qm_selid = qm_case_gp->_.gp.selid;
      caddr_t qm_tabid = t_box_sprintf (100, "%s-qm%d", triple->_.triple.tabid, tc_idx);
      triple_case_t **one_tc = (triple_case_t **)t_list (1, tc);
      mp_box_tag_modify (one_tc, DV_ARRAY_OF_LONG);
      qm_case_triple->_.triple.tc_list = one_tc;
      qm_case_triple->_.triple.selid = /*t_box_copy*/ (qm_selid);
      qm_case_triple->_.triple.tabid = qm_tabid;
      for (field_ctr = SPART_TRIPLE_FIELDS_COUNT; field_ctr--; /*no step*/)
        {
          SPART *fld_expn = triple->_.triple.tr_fields[field_ctr];
          qm_value_t *fld_qmv = SPARP_FIELD_QMV_OF_QM (qm,field_ctr);
          rdf_val_range_t *fld_const_rvr = SPARP_FIELD_CONST_RVR_OF_QM (qm,field_ctr);
          ccaddr_t *fld_tc_cuts = tc->tc_red_cuts [field_ctr];
          SPART *new_fld_expn;
          qm_format_t *native_fmt;
          if (SPAR_IS_BLANK_OR_VAR (fld_expn))
            {
              sparp_equiv_t *eq;
              new_fld_expn = (SPART *)t_box_copy ((caddr_t)fld_expn);
              new_fld_expn->_.var.selid = /*t_box_copy*/ (qm_selid);
              new_fld_expn->_.var.tabid = /*t_box_copy*/ (qm_tabid);
              new_fld_expn->_.var.vname = /*t_box_copy*/ (fld_expn->_.var.vname);
              new_fld_expn->_.var.equiv_idx = SPART_BAD_EQUIV_IDX;
              sparp_rvr_copy (sparp, &(new_fld_expn->_.var.rvr), &(fld_expn->_.var.rvr));
              eq = sparp_equiv_get (sparp, qm_case_gp, new_fld_expn, SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE | SPARP_EQUIV_ADD_GSPO_USE);
              eq->e_rvr.rvrRestrictions |= (new_fld_expn->_.var.rvr.rvrRestrictions & (SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL));
              if (NULL == fld_qmv)
                sparp_equiv_tighten (sparp, eq, fld_const_rvr, ~0);
              else
                {
                  sparp_equiv_tighten (sparp, eq, &(fld_qmv->qmvRange), ~SPART_VARR_IRI_CALC);
                  sparp_equiv_tighten (sparp, eq, &(fld_qmv->qmvFormat->qmfValRange), ~SPART_VARR_IRI_CALC);
                }
              if (NULL != fld_tc_cuts)
                sparp_rvr_add_red_cuts (sparp, &(eq->e_rvr), fld_tc_cuts, BOX_ELEMENTS (fld_tc_cuts));
#if 0
              sparp_rvr_tighten (sparp, (&new_fld_expn->_.var.rvr), &(eq->e_rvr), ~0 /* not (SPART_VARR_EXTERNAL | SPART_VARR_GLOBAL)*/);
#else
              sparp_rvr_tighten (sparp, (&new_fld_expn->_.var.rvr), &(eq->e_rvr), ~(SPART_VARR_EXTERNAL | SPART_VARR_GLOBAL));
#endif
            }
          else
            new_fld_expn = sparp_tree_full_copy (sparp, fld_expn, NULL);
          qm_case_triple->_.triple.tr_fields[field_ctr] = new_fld_expn;
          native_fmt = ((NULL != fld_qmv) ? fld_qmv->qmvFormat : SSG_VALMODE_AUTO);
          sparp_jso_validate_format (sparp, native_fmt);
          qm_case_triple->_.triple.native_formats[field_ctr] = native_fmt;
        }
      if (NULL != triple->_.triple.options)
        {
          qm_case_triple->_.triple.options = sparp_treelist_full_copy (sparp, triple->_.triple.options, parent_gp);
          sparp_set_options_selid_and_tabid (sparp, qm_case_triple->_.triple.options, qm_selid, qm_tabid);
        }
      sparp_gp_attach_member (sparp, qm_case_gp, qm_case_triple, 0, NULL);
      if (NULL != ft_cond_to_relocate)
        sparp_gp_attach_filter (sparp, qm_case_gp, sparp_tree_full_copy (sparp, ft_cond_to_relocate, parent_gp), 0, NULL);
      res [tc_idx] = qm_case_gp;
    }
  END_DO_BOX_FAST;
  return res;
}

SPART *
sparp_new_empty_gp (sparp_t *sparp, ptrlong subtype, ptrlong srcline)
{
  SPART *res = spartlist (sparp, 10, SPAR_GP, subtype,
    t_list (0),
    t_list (0),
    NULL,
    spar_mkid (sparp, "s"),
    NULL, (ptrlong)(0), (ptrlong)(0), NULL );
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
      if (SPART_VARR_NOT_NULL & eq->e_rvr.rvrRestrictions)
        {
          SPARP_DEBUG_WEIRD(sparp,"conflict");
          eq->e_rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
        }
      else
        eq->e_rvr.rvrRestrictions |= SPART_VARR_ALWAYS_NULL;
      DO_BOX_FAST (ptrlong, recv_eq_idx, recv_eq_ctr, eq->e_receiver_idxs)
        {
          sparp_equiv_t *recv_eq = SPARP_EQUIV (sparp, recv_eq_idx);
          if ((UNION_L != recv_eq->e_gp->_.gp.subtype) && (SPAR_UNION_WO_ALL != recv_eq->e_gp->_.gp.subtype) && (OPTIONAL_L != curr->_.gp.subtype))
            {
              SPARP_DEBUG_WEIRD(sparp,"conflict");
              recv_eq->e_rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
            }
          sparp_equiv_disconnect_outer_from_inner (sparp, recv_eq, eq);
        }
      END_DO_BOX_FAST;
      eq->e_replaces_filter = 0;
    }
  END_SPARP_REVFOREACH_GP_EQUIV;
  curr->_.gp.glued_filters_count = 0; /* The (now redundant) glue may prevent us from detaching some filters */
  sparp_gp_detach_all_filters (sparp, curr, 0, NULL);
  while (0 < BOX_ELEMENTS (curr->_.gp.members))
    {
      SPART *memb = sparp_gp_detach_member (sparp, curr, 0, NULL);
      if (SPAR_GP == memb->type)
        sparp_gp_deprecate (sparp, memb, 1);
    }
}

int sparp_gp_trav_refresh_triple_cases (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  switch (curr->type)
    {
    case SPAR_TRIPLE:
      {
        SPART *sinv = sparp_get_option (sparp, curr->_.gp.options, SPAR_SERVICE_INV);
        SPART **sources;
        if (NULL != sinv)
          {
            sts_this[0].sts_env = sinv;
            sources = sinv->_.sinv.sources;
            sparp_refresh_triple_cases (sparp, sources, curr);
            return SPAR_GPT_ENV_PUSH;
          }
        sinv = (SPART *)(sts_this[-1].sts_env);
        sources = (NULL != sinv) ? sinv->_.sinv.sources : sparp->sparp_stp->stp_trav_req_top->_.req_top.sources;
        sparp_refresh_triple_cases (sparp, sources, curr);
        return SPAR_GPT_NODOWN /*| SPAR_GPT_NOOUT */;
      }
    case SPAR_GP:
      if (SELECT_L == curr->_.gp.subtype)
        {
          sparp_gp_trav_suspend (sparp);
          if (sparp_rewrite_qm_optloop (sparp, curr->_.gp.subquery, (ptrlong)common_env))
            sparp->sparp_rewrite_dirty = 1;
          sparp_gp_trav_resume (sparp);
          return SPAR_GPT_NODOWN /*| SPAR_GPT_NOOUT */;
        }
      break;
    }
  return 0;
}


int sparp_gp_trav_multiqm_to_unions (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  int curr_is_union, memb_ctr;
  if (SPAR_GP != curr->type) /* Not a gp ? -- nothing to do */
    return 0;
  if (sparp_detach_conflicts (sparp, curr))
    return 0;
  curr_is_union = ((UNION_L == curr->_.gp.subtype) || (SPAR_UNION_WO_ALL == curr->_.gp.subtype));
  DO_BOX_FAST_REV (SPART *, memb, memb_ctr, curr->_.gp.members)
    { /* countdown direction of 'for' is important due to possible insertions/removals */
      int tc_count;
      SPART **qm_cases, *ft_cond_to_relocate = NULL;
      int case_ctr;
      if (SPAR_TRIPLE != memb->type)
        continue;
      tc_count = BOX_ELEMENTS (memb->_.triple.tc_list);
      if (1 == tc_count)
        continue;
      if (memb->_.triple.ft_type)
        {
          int filt_ctr;
          DO_BOX_FAST_REV (SPART *, filt, filt_ctr, curr->_.gp.filters)
            {
              if (NULL != spar_filter_is_freetext (sparp, filt, memb))
                {
                  ft_cond_to_relocate = sparp_gp_detach_filter (sparp, curr, filt_ctr, NULL); 
                  break;
                }
            }
          END_DO_BOX_FAST_REV;
          if (NULL == ft_cond_to_relocate)
            spar_error (sparp, "optimizer can not process a combination of quad map patterns and free-text condition for variable ?%.200s",
              curr->_.triple.tr_object->_.var.vname );
        }
      if (0 == tc_count)
        {
          if (!curr_is_union)
            {
              sparp_gp_produce_nothing (sparp, curr);
              return SPAR_GPT_NODOWN;
            }
          sparp_gp_detach_member (sparp, curr, memb_ctr, NULL);
          continue;
        }
      sparp_gp_detach_member (sparp, curr, memb_ctr, NULL);
      qm_cases = sparp_make_qm_cases (sparp, memb, curr, ft_cond_to_relocate);
      if (curr_is_union)
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
  if (curr_is_union)
    sparp_flatten_union (sparp, curr);
  else if ((SELECT_L != curr->_.gp.subtype) && (VALUES_L != curr->_.gp.subtype))
    sparp_flatten_join (sparp, curr);
  return 0;
}


int sparp_gp_trav_detach_conflicts_out (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  if (SPAR_GP != curr->type) /* Not a gp ? -- nothing to do */
    return 0;
  if (sparp_detach_conflicts (sparp, curr))
    return 0;
  if ((UNION_L == curr->_.gp.subtype) || (SPAR_UNION_WO_ALL == curr->_.gp.subtype))
    sparp_flatten_union (sparp, curr);
  else if ((SELECT_L != curr->_.gp.subtype) && (VALUES_L != curr->_.gp.subtype))
    sparp_flatten_join (sparp, curr);
  return 0;
}

int sparp_gp_trav_1var (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  SPART **single_var_ptr = (SPART **)common_env;
  if (!SPAR_IS_BLANK_OR_VAR (curr))
    return 0;
  if (SPART_VARNAME_IS_GLOB (curr->_.var.vname))
    return 0;
  if (NULL != single_var_ptr[0])
    {
      single_var_ptr[0] = (SPART *)(1L);
      return SPAR_GPT_COMPLETED;
    }
  single_var_ptr[0] = curr;
  return SPAR_GPT_NODOWN;
}

#if 0 /*!!!TBD: support of filter localization for services */
typedef struct sparp_filter_relocation_details_s {
  SPART **sfrd_var;		/*!< A non-global non-external variable used in filter */
  ptrlong sfrd_var_count;	/*!< Count of distinct non-global non-external variables found in filter */
  ptrlong sfrd_syntax;		/*!< Syntax features found in filter */
} sparp_filter_relocation_details_t;
#endif

int
sparp_gp_trav_localize_filters (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  int filt_ctr, filt_count;
  if (SPAR_GP != curr->type) /* Not a gp ? -- nothing to do */
    return 0;
  filt_count = BOX_ELEMENTS_0 (curr->_.gp.filters) - curr->_.gp.glued_filters_count; /* Glued filters should not be localized, that's what they're glued for */
  for (filt_ctr = filt_count; filt_ctr--; /* no step */)
    {
      SPART *filt = curr->_.gp.filters[filt_ctr];
      SPART *single_var = NULL;
      sparp_equiv_t *sv_eq;
      int filt_is_detached = 0;
      int subval_ctr, subval_count, subval_unions_count, subval_in_unions_count, localize_in_unions, localizations_left;
      sparp_gp_trav_int (sparp, filt, sts_this, &(single_var),
        NULL, NULL,
        sparp_gp_trav_1var, NULL, NULL,
        NULL );
      if (!IS_BOX_POINTER (single_var))
        continue;
      sv_eq = SPARP_EQUIV(sparp, single_var->_.var.equiv_idx);
      if (0 != sv_eq->e_gspo_uses)
        continue; /* The filter can not be detached here so it may be localized on every loop, resulting in redundant localized filters */
      subval_count = BOX_ELEMENTS_0 (sv_eq->e_subvalue_idxs);
      subval_unions_count = 0;
      subval_in_unions_count = 0;
      localize_in_unions = 1;
      DO_BOX_FAST_REV (ptrlong, subval_eq_idx, subval_ctr, sv_eq->e_subvalue_idxs)
        {
          sparp_equiv_t *sub_eq = SPARP_EQUIV (sparp, subval_eq_idx);
          SPART *sub_gp = sub_eq->e_gp;
          switch (sub_gp->_.gp.subtype)
            {
            case UNION_L: case SPAR_UNION_WO_ALL:
              if (!(SPART_VARR_NOT_NULL & sv_eq->e_rvr.rvrRestrictions))
                subval_count --; /* It's too hard to safely localize a filter on nullable variable in UNION, too many checks for too little effect */
              /* In case of union, we can't place filter right in UNION gp, because nobody expects it there.
              Instead, we place a copy of the filter in each branch of the union. This can be unsafe if there are too many branches */
              subval_unions_count++;
              subval_in_unions_count += BOX_ELEMENTS (sub_gp->_.gp.members);
              break;
            case SELECT_L: subval_count --; break;  /*!!!TBD now HAVING is supported so filter can be moved inside subselect if there's no LIMIT/OFFSET */
            case SERVICE_L: subval_count --; break;
            case VALUES_L: subval_count --; break; /* can't localize inside procedure view */
            case OPTIONAL_L:
              {
                if (!(SPART_VARR_NOT_NULL & sv_eq->e_rvr.rvrRestrictions))
                  subval_count --; /* It's unsafe to localize a filter on nullable variable. Consider { ... optional {<s> <p> ?o} filter (!bound(?o))}} */
                break;
              }
            }
        }
      END_DO_BOX_FAST_REV;
      if (10 < subval_in_unions_count)
        {
          localize_in_unions = 0; /* Too many subvalues in unions -- unsafe to localize there, too many filter conditions may kill SQL compiler */
          subval_count -= subval_unions_count; /* Nevertheless we can try to localize in non-unions */
        }
      if (0 == subval_count)
        continue; /* No subvalues -- can't localize because this either have no effect or drop the filter */
      localizations_left = 5; /* With too many subvalues, only few can be used for localization, too many filter conditions may kill SQL compiler */
      /* Now it's safe to localize the filter in each place where a subvalue comes from */
      DO_BOX_FAST_REV (ptrlong, subval_eq_idx, subval_ctr, sv_eq->e_subvalue_idxs)
        {
          sparp_equiv_t *sub_eq = SPARP_EQUIV (sparp, subval_eq_idx);
          SPART *sub_gp = sub_eq->e_gp;
          SPART *filter_clone;
          switch (sub_gp->_.gp.subtype)
            {
            case UNION_L: case SPAR_UNION_WO_ALL:
              if (!localize_in_unions)
                continue;
              if (!(SPART_VARR_NOT_NULL & sv_eq->e_rvr.rvrRestrictions))
                continue;
              break;
            case SELECT_L: continue; /*!!!TBD see comment above */
            case SERVICE_L: continue;
            case VALUES_L: continue;
            case OPTIONAL_L:
              {
                if (!(SPART_VARR_NOT_NULL & sv_eq->e_rvr.rvrRestrictions))
                  continue;
                break;
              }
            }
          if (0 >= localizations_left--)
            break;
          if ((UNION_L == sub_gp->_.gp.subtype) || (SPAR_UNION_WO_ALL == sub_gp->_.gp.subtype))
            {
              int sub_memb_ctr, bad_subcase_found = 0;
              if (!filt_is_detached)
                {
/* If some branches are inappropriate for that trick then we don't detach the external filter in order to guarantee that results of all branches are filtered somewhere outside. */
                  DO_BOX_FAST_REV (SPART *, sub_memb, sub_memb_ctr, sub_gp->_.gp.members)
                    {
                      if ((SPAR_GP != SPART_TYPE (sub_memb)) || (0 != sub_memb->_.gp.subtype))
                        {
                          bad_subcase_found = 1;
                          break;
                        }
                    }
                  END_DO_BOX_FAST_REV;
                }
              DO_BOX_FAST_REV (SPART *, sub_memb, sub_memb_ctr, sub_gp->_.gp.members)
                {
                  if (!bad_subcase_found && !filt_is_detached)
                    {
                      sparp_gp_detach_filter (sparp, curr, filt_ctr, NULL);
                      filt_is_detached = 1;
                    }
                  filter_clone = sparp_tree_full_copy (sparp, filt, curr);
                  sparp_gp_attach_filter (sparp, sub_memb, filter_clone, 0, NULL);
                }
              END_DO_BOX_FAST_REV;
              continue;
            }
          if (!filt_is_detached)
            {
              sparp_gp_detach_filter (sparp, curr, filt_ctr, NULL);
              filt_is_detached = 1;
            }
          filter_clone = sparp_tree_full_copy (sparp, filt, curr);
          sparp_gp_attach_filter (sparp, sub_gp, filter_clone, 0, NULL);
        }
      END_DO_BOX_FAST_REV;
    }
  return 0;
}

int
sparp_calc_importance_of_eq (sparp_t *sparp, sparp_equiv_t *eq)
{
  int res = 16 * eq->e_subquery_uses +
    4 * eq->e_gspo_uses +
    4 * eq->e_nested_bindings +
    3 * eq->e_optional_reads +
    2 * eq->e_const_reads +
    2 * BOX_ELEMENTS_0 (eq->e_receiver_idxs);
  if (SPARP_EQ_IS_FIXED_AND_NOT_NULL (eq))
    res *= 5;
  else if (SPART_VARR_FIXED & eq->e_rvr.rvrRestrictions)
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
      if ((SPAR_GP != memb->type) || ((UNION_L != memb->_.gp.subtype) && (SPAR_UNION_WO_ALL != memb->_.gp.subtype)))
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
sparp_gp_trav_union_of_joins_in (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  switch (SPART_TYPE(curr))
    {
    case SPAR_GP:
      sts_this[0].sts_env = curr;
      return SPAR_GPT_ENV_PUSH;
    case SPAR_TRIPLE: return SPAR_GPT_NODOWN |  SPAR_GPT_NOOUT;
    default: return 0;
    }
}

int
sparp_gp_trav_union_of_joins_out (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  if (SPAR_GP != curr->type)
    return 0;
  if ((0 == curr->_.gp.subtype) || (WHERE_L == curr->_.gp.subtype))
    {
      int union_idx;
      int case_ctr, case_count;
      int curr_had_one_member = ((1 >= BOX_ELEMENTS (curr->_.gp.members)) ? 1 : 0);
      int join_glued_filters_count, union_glued_filters_count;
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
          SPART *parent = (SPART *)(sts_this[-1].sts_env);
#ifdef DEBUG
          if (SPAR_GP != SPART_TYPE (parent))
            spar_internal_error (sparp, "sparp_" "gp_trav_union_of_joins_out (): parent is not a gp");
#endif
          if ((UNION_L == parent->_.gp.subtype) || (SPAR_UNION_WO_ALL == parent->_.gp.subtype))
            parent_len = BOX_ELEMENTS (parent->_.gp.members);
          if (2000 < (parent_len + case_count))
            return 0; /* This restricts the size of the resulting SQL statement */
        }
      sparp_equiv_audit_all (sparp, 0);
      union_glued_filters_count = sub_union->_.gp.glued_filters_count;
      sub_union->_.gp.glued_filters_count = 0;
      detached_union_filters = sparp_gp_detach_all_filters (sparp, sub_union, 1, NULL);
      detached_union_parts = sparp_gp_detach_all_members (sparp, sub_union, NULL);
      join_glued_filters_count = curr->_.gp.glued_filters_count;
      curr->_.gp.glued_filters_count = 0;
      detached_join_filters = sparp_gp_detach_all_filters (sparp, curr, 1, NULL);
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
          curr->_.gp.subtype = sub_union->_.gp.subtype;
          new_union = curr;
        }
      else
        {
          new_union = sparp_new_empty_gp (sparp, sub_union->_.gp.subtype, unbox (curr->srcline));
          sparp_gp_attach_member (sparp, curr, new_union, 0, NULL);
        }
      sparp_gp_attach_many_members (sparp, new_union, new_union_joins, 0, NULL);
      detached_join_parts [union_idx] = NULL;
      for (case_ctr = 0; case_ctr < case_count; case_ctr++)
        {
          int last_case = 0; /*(((case_count-1) == case_ctr) ? 1 : 0);*/
          SPART *new_join = new_union->_.gp.members [case_ctr]; /* equal to union_part if curr_had_one_member */
          SPART **new_filts_u = (last_case ? detached_union_filters : sparp_treelist_full_clone (sparp, detached_union_filters));
          SPART **new_filts_j = (last_case ? detached_join_filters : sparp_treelist_full_clone (sparp, detached_join_filters));
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
                    new_join_parts [join_part_ctr] = (last_case ? join_part : sparp_tree_full_copy (sparp, join_part, curr));
                }
              END_DO_BOX_FAST;
              sparp_gp_attach_many_members (sparp, new_join, new_join_parts, 0, NULL);
              sparp_equiv_audit_all (sparp, 0);
            }
          sparp_gp_attach_many_filters (sparp, new_join, new_filts_u, BOX_ELEMENTS (new_join->_.gp.filters) - new_join->_.gp.glued_filters_count, NULL);
          new_join->_.gp.glued_filters_count += union_glued_filters_count;
          sparp_gp_attach_many_filters (sparp, new_join, new_filts_j, BOX_ELEMENTS (new_join->_.gp.filters) - new_join->_.gp.glued_filters_count, NULL);
          new_join->_.gp.glued_filters_count += join_glued_filters_count;
          sparp_gp_tighten_by_eq_replaced_filters (sparp, new_join, sub_union, 0);
          sparp_gp_tighten_by_eq_replaced_filters (sparp, new_join, curr, 0);
          sparp_equiv_audit_all (sparp, 0);
        }
      sparp->sparp_rewrite_dirty += 10;
      sparp_gp_tighten_by_eq_replaced_filters (sparp, NULL, sub_union, 1);
      sparp_gp_tighten_by_eq_replaced_filters (sparp, NULL, curr, 1);
      sparp_gp_deprecate (sparp, sub_union, 0);
      sparp_equiv_audit_all (sparp, 0);
    }
  return 0;
}

static void
sparp_collect_single_atable_use (sparp_t *sparp_or_null, ccaddr_t alias, ccaddr_t tablename, qm_atable_use_t *uses, ptrlong *use_count_ptr )
{
  ptrlong old_qmatu_idx = ecm_find_name (alias, uses, use_count_ptr[0], sizeof (qm_atable_use_t));
  if (ECM_MEM_NOT_FOUND == old_qmatu_idx)
    {
      ptrlong use_idx = ecm_add_name (alias, (void **)(&uses), use_count_ptr, sizeof (qm_atable_use_t));
      qm_atable_use_t *use = uses + use_idx;
      use->qmatu_alias = (char *) alias;
      use->qmatu_tablename = tablename;
      use->qmatu_more = NULL;
    }
  else
    {
      qm_atable_use_t *qmatu = uses + old_qmatu_idx;
      if (strcmp (tablename, qmatu->qmatu_tablename))
        {
          if (NULL == sparp_or_null)
            sqlr_new_error ("22023", "SR640", "internal error in processing table \"%.200s\" (alias \"%.200s\") in some RDF View", tablename, alias);
          else
            spar_internal_error (sparp_or_null, "sparp_" "collect_atable_uses(): probable corruption of some quad map");
        }
    }
}

static void
sparp_collect_atable_uses (sparp_t *sparp_or_null, ccaddr_t singletablename, qm_atable_array_t qmatables, qm_atable_use_t *uses, ptrlong *use_count_ptr )
{
  int ata_ctr;
  if ((NULL != singletablename) && ('\0' != singletablename[0]))
    sparp_collect_single_atable_use (sparp_or_null, uname___empty, singletablename, uses, use_count_ptr);
  DO_BOX_FAST (qm_atable_t *, ata, ata_ctr, qmatables)
    {
      sparp_collect_single_atable_use (sparp_or_null, ata->qmvaAlias, ata->qmvaTableName, uses, use_count_ptr);
    }
  END_DO_BOX_FAST;
}

void
sparp_collect_all_atable_uses (sparp_t *sparp_or_null, quad_map_t *qm)
{
  int fld_ctr, max_uses = 0, default_qm_table_used = 0;
  ptrlong use_count = 0;
  qm_atable_use_t *uses;
  for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
    {
      qm_value_t *qmv = SPARP_FIELD_QMV_OF_QM (qm, fld_ctr);
      if (NULL != qmv)
        {
          if (NULL != qmv->qmvTableName)
            max_uses++;
          max_uses += BOX_ELEMENTS_0 (qmv->qmvATables);
        }
    }
  if (NULL != qm->qmTableName)
    max_uses++;
  max_uses += BOX_ELEMENTS_0 (qm->qmATables);
  uses = dk_alloc_box_zero (sizeof (qm_atable_use_t) * max_uses, DV_ARRAY_OF_LONG);
  for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
    {
      int col_ctr, default_qm_val_table_used = 0;
      qm_value_t *qmv = SPARP_FIELD_QMV_OF_QM (qm, fld_ctr);
      if (NULL == qmv)
        continue;
      DO_BOX_FAST (qm_column_t *, col, col_ctr, qmv->qmvColumns)
        {
          if ((NULL == col->qmvcAlias) || ('\0' == col->qmvcAlias[0]))
            {
              if ((NULL != qmv->qmvTableName) && ('\0' != qmv->qmvTableName[0]))
                default_qm_val_table_used++;
              else
                default_qm_table_used++;
            }
        }
      END_DO_BOX_FAST;
      sparp_collect_atable_uses (sparp_or_null,
        (default_qm_val_table_used ? qmv->qmvTableName : NULL),
        qmv->qmvATables, uses, &use_count );
    }
  sparp_collect_atable_uses (sparp_or_null,
    (default_qm_table_used ? qm->qmTableName : NULL),
    qm->qmATables, uses, &use_count );
  qm->qmAllATableUses = (ptrlong *)uses;
  qm->qmAllATableUseCount = use_count;
}

#if 0
static int
sparp_atable_uses_match (
  qm_atable_array_t qmatables,
  qm_atable_use_t *uses, int use_count )
{
  int ata_ctr, use_ctr, found_ctr = 0;
  DO_BOX_FAST (qm_atable_t *, ata, ata_ctr, qmatables)
    {
      qm_atable_use_t *qmatu;
      for (use_ctr = use_count; use_ctr--; /* no step */)
        {
          qmatu = uses + use_ctr;
          if (strcmp (ata->qmvaAlias, qmatu->qmatu_alias))
            continue;
          if (strcmp (ata->qmvaTableName, qmatu->qmatu_ata->qmvaTableName))
            continue;
          if (NULL == qmatu->qmatu_more)
            {
              found_ctr++;
              qmatu->qmatu_more = ata;
            }
          goto qmatu_exists; /* see below */
        }
      return -1; /* No match because qmatables contains an item that is not in \c uses */
qmatu_exists: ;
    }
  END_DO_BOX_FAST;
  return found_ctr;
}
#endif

void
sparp_collect_all_conds (sparp_t *sparp_or_null, quad_map_t *qm)
{
  int fld_ctr, max_conds = 0;
  ptrlong cond_ctr, cond_count = 0;
  ccaddr_t *conds;
  for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
    {
      qm_value_t *qmv = SPARP_FIELD_QMV_OF_QM (qm, fld_ctr);
      if (NULL != qmv)
        max_conds += BOX_ELEMENTS_0 (qmv->qmvConds);
    }
  max_conds += BOX_ELEMENTS_0 (qm->qmConds);
  conds = dk_alloc_box_zero (sizeof (ccaddr_t) * max_conds, DV_ARRAY_OF_LONG);
  for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
    {
      qm_value_t *qmv = SPARP_FIELD_QMV_OF_QM (qm, fld_ctr);
      if (NULL == qmv)
        continue;
      DO_BOX_FAST (ccaddr_t, cond, cond_ctr, qmv->qmvConds)
        {
          ecm_map_name (cond, (void **)(&conds), &cond_count, sizeof (ccaddr_t));
        }
      END_DO_BOX_FAST;
    }
  DO_BOX_FAST (ccaddr_t, cond, cond_ctr, qm->qmConds)
    {
      ecm_map_name (cond, (void **)(&conds), &cond_count, sizeof (ccaddr_t));
    }
  END_DO_BOX_FAST;
  qm->qmAllConds = conds;
  qm->qmAllCondCount = cond_count;
}

int
sparp_quad_maps_eq_for_breakup (sparp_t *sparp, quad_map_t *qm_one, quad_map_t *qm_two)
{
  int use_ctr, use_count, cond_ctr, cond_count;
  qm_atable_use_t *uses_one, *uses_two;
  ccaddr_t *conds_one, *conds_two;
/* First of all we check if sets of atables are equal */
  if (NULL == qm_one->qmAllATableUses)
    sparp_collect_all_atable_uses (sparp, qm_one);
  if (NULL == qm_two->qmAllATableUses)
    sparp_collect_all_atable_uses (sparp, qm_two);
  uses_one = (qm_atable_use_t *)(qm_one->qmAllATableUses);
  uses_two = (qm_atable_use_t *)(qm_two->qmAllATableUses);
  use_count = qm_one->qmAllATableUseCount;
  if (use_count != qm_two->qmAllATableUseCount)
    return 0;
  for (use_ctr = use_count; use_ctr--; /* no step */)
    {
      if (strcmp (uses_one[use_ctr].qmatu_alias, uses_two[use_ctr].qmatu_alias))
        return 0;
      if (strcmp (uses_one[use_ctr].qmatu_tablename, uses_two[use_ctr].qmatu_tablename))
        return 0;
    }
  /* If sets of atables are equal then we compare conditions */
  if (NULL == qm_one->qmAllConds)
    sparp_collect_all_conds (sparp, qm_one);
  if (NULL == qm_two->qmAllConds)
    sparp_collect_all_conds (sparp, qm_two);
  conds_one = qm_one->qmAllConds;
  conds_two = qm_two->qmAllConds;
  cond_count = qm_one->qmAllCondCount;
  if (cond_count != qm_two->qmAllCondCount)
    return 0;
  for (cond_ctr = cond_count; cond_ctr--; /* no step */)
    {
      if (strcmp (conds_one[cond_ctr], conds_two[cond_ctr]))
        return 0;
    }
/*return 0;*/
  return 1;
}

caddr_t *
sparp_gp_may_reuse_tabids_in_union (sparp_t *sparp, SPART *gp, int expected_triples_count)
{
  dk_set_t res = NULL;
  int triple_ctr, triples_count;
  if ((SPAR_GP != gp->type) ||
    (0 != gp->_.gp.subtype) )
    return NULL;
  triples_count = BOX_ELEMENTS (gp->_.gp.members);
  if (((0 <= expected_triples_count) && (triples_count != expected_triples_count)) || (0 == triples_count))
    return NULL;
  for (triple_ctr = 0; triple_ctr < triples_count; triple_ctr++)
    {
      SPART * gp_triple = gp->_.gp.members[triple_ctr];
      if (SPAR_TRIPLE != gp_triple->type)
        return NULL;
      if (1 != BOX_ELEMENTS (gp_triple->_.triple.tc_list))
        return NULL;
      if (NULL != gp_triple->_.triple.options)
        return NULL;
      if (gp_triple->_.triple.ft_type)
        return NULL; /* TBD: support of free-text indexing in breakup */
    }
  for (triple_ctr = 0; triple_ctr < triples_count; triple_ctr++)
    {
      SPART * gp_triple = gp->_.gp.members[triple_ctr];
      t_set_push (&res, gp_triple->_.triple.tabid);
    }
  return t_revlist_to_array (res);
}

int
sparp_bitmask_fields_with_equations (sparp_t *sparp, SPART *triple)
{
  quad_map_t *qm = triple->_.triple.tc_list[0]->tc_qm;
  int fld_ctr;
  int res = 0;
  for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
    {
       SPART *fld = triple->_.triple.tr_fields[fld_ctr];
       sparp_equiv_t *fld_eq;
       qm_value_t *fld_qmv;
       long restr;
       int fld_has_equations;
       if (!SPAR_IS_BLANK_OR_VAR (fld))
         {
           res |= (1 << fld_ctr);
           continue;
         }
       fld_eq = SPARP_EQUIV (sparp, fld->_.var.equiv_idx);
       fld_qmv = SPARP_FIELD_QMV_OF_QM (qm, fld_ctr);
       restr = fld_eq->e_rvr.rvrRestrictions;
       fld_has_equations = ((1 < fld_eq->e_var_count) ||
         (restr & (SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL)) ||
         ((restr & SPART_VARR_FIXED) && (NULL != fld_qmv)) );
       if (fld_has_equations)
         res |= (1 << fld_ctr);
    }
  return res;
}

int
sparp_try_reuse_tabid_in_union (sparp_t *sparp, SPART *curr, int base_idx)
{
  SPART *base = curr->_.gp.members[base_idx];
  /*SPART **base_filters = base->_.gp.filters; !!!TBD: check for filters that may restrict the search by idex */
  SPART **base_triples = base->_.gp.members;
  int bt_ctr, base_triples_count = BOX_ELEMENTS (base_triples);
  int dep_idx, memb_count, breakup_shift = 0, breakup_unictr = -1;
  int base_should_change_tabid = 0;
  memb_count = BOX_ELEMENTS_0 (curr->_.gp.members);
  for (dep_idx = base_idx + 1; /* breakup optimization is symmetrical so the case of two triples should be considered only once, not base_triple...dep then dep...base_triple */
    dep_idx < memb_count; dep_idx++)
    {
      SPART *dep = curr->_.gp.members[dep_idx];
      SPART **dep_triples;
      if (NULL == sparp_gp_may_reuse_tabids_in_union (sparp, dep, base_triples_count))
        continue;
      if (dep_idx == base_idx + 1)
        base_should_change_tabid = 1; /* There's a danger of tabid collision so printer will treat base and dep as breakup even if it is not true */
      dep_triples = dep->_.gp.members;
      if (BOX_ELEMENTS (dep_triples) != base_triples_count)
        goto next_dep; /* see below */
      for (bt_ctr = base_triples_count; bt_ctr--; /* no step */)
        {
          SPART *base_triple = base_triples[bt_ctr];
          SPART *dep_triple = dep_triples[bt_ctr];
          quad_map_t *base_qm, *dep_qm;
          int fld_ctr, base_bitmask_of_equations, dep_bitmask_of_equations;
          if (dep_triple->_.triple.src_serial != base_triple->_.triple.src_serial)
            goto next_dep; /* see below */
          base_qm = base_triple->_.triple.tc_list[0]->tc_qm;
          dep_qm = dep_triple->_.triple.tc_list[0]->tc_qm;
          base_bitmask_of_equations = sparp_bitmask_fields_with_equations (sparp, base_triple);
          if ((base_bitmask_of_equations & (1 << SPART_TRIPLE_OBJECT_IDX)) &&
             !(base_bitmask_of_equations & (1 << SPART_TRIPLE_SUBJECT_IDX)) ) /* If chances on good breakup are low but cost of wrong decision may be high... */
            goto next_dep; /* see below */
          dep_bitmask_of_equations = sparp_bitmask_fields_with_equations (sparp, dep_triple);
          if ((dep_bitmask_of_equations & (1 << SPART_TRIPLE_OBJECT_IDX)) &&
             !(dep_bitmask_of_equations & (1 << SPART_TRIPLE_SUBJECT_IDX)) ) /* If chances on good breakup are low but cost of wrong decision may be high... */
            goto next_dep; /* see below */
          if (!sparp_expn_lists_are_equal (sparp, base->_.gp.filters, dep->_.gp.filters))
            goto next_dep; /* see below */
          if (!sparp_quad_maps_eq_for_breakup (sparp, base_qm, dep_qm))
            goto next_dep; /* see below */
          for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
            { /* For each variable that makes equalities we check that it has identical qmv in base and in dep */
              SPART *base_fld = base_triple->_.triple.tr_fields[fld_ctr];
              SPART *dep_fld = dep_triple->_.triple.tr_fields[fld_ctr];
              sparp_equiv_t *base_fld_eq, *dep_fld_eq;
              qm_value_t *base_fld_qmv, *dep_fld_qmv;
              if (!SPAR_IS_BLANK_OR_VAR (base_fld))
                continue;
              if (!SPAR_IS_BLANK_OR_VAR (dep_fld))
                spar_internal_error (sparp, "sparp_" "try_reuse_tabid_in_union(): different field types in triples with same src_serial");
              base_fld_eq = SPARP_EQUIV (sparp, base_fld->_.var.equiv_idx);
              dep_fld_eq = SPARP_EQUIV (sparp, dep_fld->_.var.equiv_idx);
              base_fld_qmv = SPARP_FIELD_QMV_OF_QM (base_qm, fld_ctr);
              dep_fld_qmv = SPARP_FIELD_QMV_OF_QM (dep_qm, fld_ctr);
              if (!(base_bitmask_of_equations & (1 << fld_ctr)))
                continue;
              if (!(dep_bitmask_of_equations & (1 << fld_ctr)))
                continue;
              if (base_fld_qmv != dep_fld_qmv)
                goto next_dep; /* see below */
              if (NULL == base_fld_qmv)
                {
                  long base_restr = base_fld_eq->e_rvr.rvrRestrictions;
                  long dep_restr = dep_fld_eq->e_rvr.rvrRestrictions;
                  if (((base_restr & SPART_VARR_IS_REF) && (dep_restr & SPART_VARR_IS_LIT)) ||
                    ((base_restr & SPART_VARR_IS_LIT) && (dep_restr & SPART_VARR_IS_REF)) )
                    goto next_dep; /* see below */
/* For a typical RDF View, predicate in
select ?o where { graph ?g { ?s ?:p_param ?o }}
is a strong filter that will disable all or almost all branches of UNION except very few, so UNION is much better than BREAKUP.
In addition, ignoring external connections may result in an error because the connection will be printed as
WHERE (p_param = const_p_from_base_fld)
at the end of the breakup. This is wrong because consts of base_fld and dep_fld may differ. */
                  if (!sparp_equivs_have_same_fixedvalue (sparp, base_fld_eq, dep_fld_eq)
                    && (SPARP_ASSIGNED_EXTERNALLY (base_restr) || SPARP_ASSIGNED_EXTERNALLY (dep_restr)) )
                    goto next_dep; /* see below */
                }
            }
        }
      /* At this point all checks of dep are passed, can adjust selids and tabids */
      sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
      if (0 == breakup_shift)
        breakup_unictr = sparp->sparp_unictr++;
      for (bt_ctr = base_triples_count; bt_ctr--; /* no step */)
        {
          SPART *base_triple = base_triples[bt_ctr];
          SPART *dep_triple = dep_triples[bt_ctr];
          caddr_t new_base_tabid;
          if (0 == breakup_shift)
            {
              new_base_tabid = t_box_sprintf (200, "%s-b%d", base_triple->_.triple.tabid, breakup_unictr);
              sparp_set_triple_selid_and_tabid (sparp, base_triple, base->_.gp.selid, new_base_tabid);
              base_should_change_tabid = 0;
            }
          else
            new_base_tabid = base_triple->_.triple.tabid;
          sparp_set_triple_selid_and_tabid (sparp, dep_triple, dep->_.gp.selid, new_base_tabid);
        }
      if (dep_idx > (base_idx + 1 + breakup_shift)) /* Adjustment to keep reused tabids together. */
        {
          int swap_ctr;
          for (swap_ctr = dep_idx; swap_ctr > (base_idx + 1 + breakup_shift); swap_ctr--)
            curr->_.gp.members[swap_ctr] = curr->_.gp.members[swap_ctr-1];
          curr->_.gp.members[base_idx + 1 + breakup_shift] = dep;
        }
      breakup_shift++;
      sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);

next_dep: ;
    }
#ifdef DEBUG
  if (0 != breakup_shift)
    {
      int chk_idx;
      printf ("sparp_" "try_reuse_tabid_in_union() has found breakup in %s from %d to %d incl.\n",
        curr->_.gp.selid, base_idx, base_idx + breakup_shift);
      for (chk_idx = base_idx + breakup_shift; chk_idx > base_idx; chk_idx--)
        {
          SPART *chk = curr->_.gp.members[chk_idx];
          for (bt_ctr = base_triples_count; bt_ctr--; /* no step */)
            {
              SPART *base_triple = base_triples[bt_ctr];
              SPART *chk_triple = chk->_.gp.members[bt_ctr];
              if (!sparp_quad_maps_eq_for_breakup (sparp, base_triple->_.triple.tc_list[0]->tc_qm, chk_triple->_.triple.tc_list[0]->tc_qm))
                spar_internal_error (sparp, "sparp_" "try_reuse_tabid_in_union() has made breakup on inappropriate pair");
            }
        }
    }
#endif
  if (base_should_change_tabid)
    { /* We rename tabids in base to prevent occasional recognition of breakup in printer */
      breakup_unictr = sparp->sparp_unictr++;
      for (bt_ctr = base_triples_count; bt_ctr--; /* no step */)
        {
          SPART *base_triple = base_triples[bt_ctr];
          if (0 == breakup_shift)
            {
              caddr_t new_base_tabid;
              new_base_tabid = t_box_sprintf (200, "%s-u%d", base_triple->_.triple.tabid, breakup_unictr);
              sparp_set_triple_selid_and_tabid (sparp, base_triple, base->_.gp.selid, new_base_tabid);
            }
        }
    }
  return breakup_shift;
}

static int
sparp_qmv_forms_reusable_key_of_qm (sparp_t *sparp, qm_value_t *key_qmv, quad_map_t *qm)
{
  dk_set_t key_aliases = NULL;
  int ctr, fld_ctr;
  if (NULL == key_qmv) /* Funny case: join on field that is mapped to constant. Thus there's no actual join, only filter (FIELD = CONST) for other triples */
    return 0;
  if (!key_qmv->qmvColumnsFormKey) /* No key -- no reuse */
    return 0;
  if (!key_qmv->qmvFormat->qmfIsBijection)	/* Non-bijection format is unsafe for reuse, different SHORTs may result in same LONG */
    return 0;
  DO_BOX_FAST (qm_atable_t *, at, ctr, key_qmv->qmvATables)
    {
      if (0 > dk_set_position_of_string (key_aliases, at->qmvaAlias))
        t_set_push (&key_aliases, (caddr_t)(at->qmvaAlias));
    }
  END_DO_BOX_FAST;
  DO_BOX_FAST (qm_atable_t *, at, ctr, qm->qmATables)
    { /* If qm uses aliases not 'selected' by key_qmv field then the key value of key_qvm is not a key of whole triple */
      if (0 > dk_set_position_of_string (key_aliases, at->qmvaAlias))
        return 0;
    }
  END_DO_BOX_FAST;
  for (fld_ctr = 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
    { /* If any field of qm uses aliases not 'selected' by key_qmv field then the key value of key_qvm is not a key of whole triple */
      qm_value_t *fld_qmv = SPARP_FIELD_QMV_OF_QM (qm, fld_ctr);
      if (fld_qmv == key_qmv)
        continue; /* No check, key_qmv is a key for itself */
      if (NULL == fld_qmv)
        continue;
      DO_BOX_FAST (qm_atable_t *, at, ctr, fld_qmv->qmvATables)
        {
          if (0 > dk_set_position_of_string (key_aliases, at->qmvaAlias))
            return 0;
        }
      END_DO_BOX_FAST;
    }
  return 1;
}

static void
sparp_try_reuse_tabid_in_join_via_key_qname (sparp_t *sparp, SPART *curr, int base_idx, qm_value_t *key_qmv, ccaddr_t qname)
{
  SPART *base = curr->_.gp.members[base_idx];
  int dep_triple_idx, memb_count = BOX_ELEMENTS (curr->_.gp.members);
  for (dep_triple_idx = base_idx; dep_triple_idx < memb_count; dep_triple_idx++)
    {
      int dep_field_idx;
      SPART *dep_triple = curr->_.gp.members[dep_triple_idx];
      quad_map_t *dep_qm;
      if (SPAR_TRIPLE != SPART_TYPE (dep_triple))
        continue;
      if (1 != BOX_ELEMENTS (dep_triple->_.triple.tc_list))
        continue;
      if (NULL != dep_triple->_.triple.options)
        continue;
      if (!strcmp (base->_.triple.tabid, dep_triple->_.triple.tabid))
        continue; /* tabid is already reused */
      dep_qm = dep_triple->_.triple.tc_list[0]->tc_qm;
      for (dep_field_idx = 0; dep_field_idx < SPART_TRIPLE_FIELDS_COUNT; dep_field_idx++)
        {
          qm_value_t *dep_qmv = SPARP_FIELD_QMV_OF_QM (dep_qm, dep_field_idx);
          SPART *dep_field;
          int dep_field_type;
          if (key_qmv != dep_qmv) /* The key mapping differs in set of source columns or in the IRI serialization (or literal cast) */
            continue;
          dep_field = dep_triple->_.triple.tr_fields[dep_field_idx];
          dep_field_type = SPART_TYPE (dep_field);
          if (SPAR_QNAME == dep_field_type)
            {
              if (strcmp (qname, dep_field->_.lit.val))
                continue;
            }
          else if ((SPAR_VARIABLE == dep_field_type) || (SPAR_BLANK_NODE_LABEL == dep_field_type))
            {
              if (((SPART_VARR_FIXED | SPART_VARR_IS_IRI) != ((SPART_VARR_FIXED | SPART_VARR_IS_IRI) & dep_field->_.var.rvr.rvrRestrictions)) ||
                strcmp (qname, dep_field->_.var.rvr.rvrFixedValue) )
                continue;
            }
          else
            continue;
          /* Glory, glory, hallelujah; we can reuse the tabid so the final SQL query will have one join less. */
          sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
          sparp_set_triple_selid_and_tabid (sparp, dep_triple, curr->_.gp.selid, base->_.triple.tabid);
          if (dep_triple_idx > (base_idx + 1)) /* Adjustment to keep reused tabids together. The old join order of dep_triple is of zero importance because there's no more dep_triple as a separate subtable */
            {
              int swap_ctr;
              for (swap_ctr = dep_triple_idx; swap_ctr > (base_idx + 1); swap_ctr--)
                curr->_.gp.members[swap_ctr] = curr->_.gp.members[swap_ctr-1];
              curr->_.gp.members[base_idx + 1] = dep_triple;
            }
          sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
          break;
        }
    }
}

void
sparp_try_reuse_tabid_in_join (sparp_t *sparp, SPART *curr, int base_idx)
{
  SPART *base = curr->_.gp.members[base_idx];
  quad_map_t *base_qm = base->_.triple.tc_list[0]->tc_qm;
  int key_field_idx;
  for (key_field_idx = 0; key_field_idx < SPART_TRIPLE_FIELDS_COUNT; key_field_idx++)
    {
      SPART *key_field = base->_.triple.tr_fields[key_field_idx];
      ssg_valmode_t key_fmt = base->_.triple.native_formats[key_field_idx];
      qm_value_t *key_qmv;
      sparp_equiv_t *key_eq;
      int dep_ctr;
      int key_field_type;
      sparp_jso_validate_format (sparp, key_fmt);
      key_qmv = SPARP_FIELD_QMV_OF_QM (base_qm,key_field_idx);
      if (NULL == key_qmv)
        continue; /* Const field of mapping can add a filter but can not specify a unique key of row */
      key_qmv = SPARP_FIELD_QMV_OF_QM (base_qm,key_field_idx);
      if (!sparp_qmv_forms_reusable_key_of_qm (sparp, key_qmv, base_qm))
        continue;
      key_field_type = SPART_TYPE (key_field);
      if ((SPAR_BLANK_NODE_LABEL != key_field_type) && (SPAR_VARIABLE != key_field_type))
        {
          if (SPAR_QNAME == key_field_type)
            sparp_try_reuse_tabid_in_join_via_key_qname (sparp, curr, base_idx, key_qmv, key_field->_.lit.val);
          continue;
        }
      if ((SPART_VARR_FIXED | SPART_VARR_IS_IRI) == ((SPART_VARR_FIXED | SPART_VARR_IS_IRI) & key_field->_.var.rvr.rvrRestrictions))
        sparp_try_reuse_tabid_in_join_via_key_qname (sparp, curr, base_idx, key_qmv, key_field->_.var.rvr.rvrFixedValue);
      key_eq = sparp_equiv_get (sparp, curr, key_field, SPARP_EQUIV_GET_ASSERT);
      if (2 > key_eq->e_gspo_uses) /* No reuse of key -- no reuse of triples */
        continue;
      for (dep_ctr = key_eq->e_var_count; dep_ctr--; /* no step */)
        {
          SPART *dep_field = key_eq->e_vars[dep_ctr];
          int dep_triple_idx, dep_field_tr_idx;
          SPART *dep_triple = NULL;
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
            {
              sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
              spar_internal_error (sparp, "sparp_" "gp_trav_reuse_tabids(): dep_field not found in members");
            }
          if (dep_triple_idx <= base_idx) /* Merge is symmetrical, so this pair of key and dep is checked from other end. In that time current dep was base and the current base was dep */
            continue;
          if (OPTIONAL_L == dep_triple->_.triple.subtype) /* Optional is bad candidate for reuse */
            continue;
          if (1 != BOX_ELEMENTS (dep_triple->_.triple.tc_list)) /* Only triples with one allowed quad mapping can be reused, unions can not */
            continue;
          dep_qm = dep_triple->_.triple.tc_list[0]->tc_qm;
#if 0 /* There's no need to check this because if QMVs match then tables are the same, otherwise names does not matter anyway */
          if (strcmp (dep_qm->qmTableName, base_qm->qmTableName)) /* Can not reuse tabid for different tables */
            continue;
#endif
          dep_qmv = SPARP_FIELD_QMV_OF_QM (dep_qm, dep_field_tr_idx);
          if (key_qmv != dep_qmv) /* The key mapping differs in set of source columns or in the IRI serialization (or literal cast) */
            continue;
          if (!sparp_qmv_forms_reusable_key_of_qm (sparp, dep_qmv, dep_qm))
            continue;
          /* Glory, glory, hallelujah; we can reuse the tabid so the final SQL query will have one join less. */
          sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
          sparp_set_triple_selid_and_tabid (sparp, dep_triple, curr->_.gp.selid, base->_.triple.tabid);
          if (dep_triple_idx > (base_idx + 1)) /* Adjustment to keep reused tabids together. The old join order of dep is of zero importance because there's no more dep as a separate subtable */
            {
              int swap_ctr;
              for (swap_ctr = dep_triple_idx; swap_ctr > (base_idx + 1); swap_ctr--)
                curr->_.gp.members[swap_ctr] = curr->_.gp.members[swap_ctr-1];
              curr->_.gp.members[base_idx + 1] = dep_triple;
            }
          sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
        }
    }
}


int
sparp_gp_trav_flatten_and_reuse_tabids (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  int base_idx;
  if (SPAR_GP != curr->type)
    return 0;
  switch (curr->_.gp.subtype)
    {
    case UNION_L: /* no case SPAR_UNION_WO_ALL while we don't have special breakup with union "not all" in SQL */
      DO_BOX_FAST (SPART *, base, base_idx, curr->_.gp.members)
        {
          int breakup_offset;
          if (NULL == sparp_gp_may_reuse_tabids_in_union (sparp, base, -1))
            continue;
          breakup_offset = sparp_try_reuse_tabid_in_union (sparp, curr, base_idx);
          base_idx += breakup_offset;
        }
      END_DO_BOX_FAST;
      break;
    case 0: case WHERE_L:
#if 1 /*!!! remove after debugging */
if (NULL != sparp->sparp_storage) {
#endif
/* First of all, flatten all members of a join that are in turn simple joins and have no filters and no execution options.
It is even OK if some equivs of these joins are conflicting or always NULL, what's important is that no one equiv should replace any filters or contain more than one variable name.
The trick is safe because no equiv-based optimization takes place after any invocation of this function.
*/
      DO_BOX_FAST_REV (SPART *, base, base_idx, curr->_.gp.members)
        {
          int eq_ctr;
          SPART **base_membs;
          sparp_equiv_t *bad_eq = NULL;
          if (SPAR_GP != base->type) /* Only GPs can be flattened to their parent GPs */
            continue;
          if (0 != base->_.gp.subtype) /* Only joins will do */
            continue;
          if (0 != BOX_ELEMENTS_0 (base->_.gp.filters)) /* Can't flatten filters */
            continue;
          if (NULL != base->_.gp.options) /* Can't flatten if that will drop options */
            continue;
          SPARP_FOREACH_GP_EQUIV (sparp, base, eq_ctr, eq)
            {
              if ((eq->e_replaces_filter) || (1 < BOX_ELEMENTS (eq->e_varnames)))
                {
                  bad_eq = eq;
                  break;
                }
              if (eq->e_rvr.rvrRestrictions & (SPART_VARR_CONFLICT | SPART_VARR_ALWAYS_NULL))
                {
                  bad_eq = eq;
                  break;
                }
              if (!(eq->e_rvr.rvrRestrictions & SPART_VARR_NOT_NULL))
                {
                  sparp_equiv_t *outer_eq = sparp_equiv_get (sparp, curr, (SPART *)(eq->e_varnames[0]), SPARP_EQUIV_GET_NAMESAKES);
                  if (NULL == outer_eq)
                    {
#ifdef DEBUG
                      if (eq->e_rvr.rvrRestrictions & SPART_VARR_EXPORTED)
                        spar_internal_error (sparp, "sparp_" "gp_trav_flatten_and_reuse_tabids(): exported eq in base without eq in curr");
#endif
                      continue;
                    }
                  if ((outer_eq->e_rvr.rvrRestrictions & SPART_VARR_NOT_NULL) || (1 < outer_eq->e_nested_bindings))
                    {
                      bad_eq = eq;
                      break;
                    }
                }
            }
          END_SPARP_FOREACH_GP_EQUIV;
          if (NULL != bad_eq) /* Some equiv blocks optimization */
            continue;
          base_membs = sparp_gp_detach_all_members (sparp, base, NULL);
/* It is possible to loose a restriction on a variable that is not used outside the base, such as named graph var of GRAPH ?x { ... } , because
there was no receiver equiv outside and hence no propagation took place. So let's propagate now without running the whole optimization loop. */
          SPARP_FOREACH_GP_EQUIV (sparp, base, eq_ctr, eq)
            {
              if (0 == BOX_ELEMENTS_0 (eq->e_receiver_idxs))
                {
                  sparp_equiv_t *outer_eq = sparp_equiv_get (sparp, curr, (SPART *)(eq->e_varnames[0]), SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_GET_NAMESAKES);
                  sparp_equiv_connect_outer_to_inner (sparp, outer_eq, eq, 1);
                  sparp_restr_of_join_eq_from_connected_subvalue (sparp, outer_eq, eq);
                }
            }
          END_SPARP_FOREACH_GP_EQUIV;
          sparp_gp_detach_member (sparp, curr, base_idx, NULL);
          sparp_gp_attach_many_members (sparp, curr, base_membs, base_idx, NULL);
          base_idx += BOX_ELEMENTS (base_membs);
        }
      END_DO_BOX_FAST;
#if 1 /*!!! remove after debugging */
}
#endif
/* After flattening, we check for possible reuse of tabids for self-joins. */
      DO_BOX_FAST (SPART *, base, base_idx, curr->_.gp.members)
        {
          if (SPAR_TRIPLE != base->type) /* Only triples have tabids to merge */
            continue;
          if (1 != BOX_ELEMENTS (base->_.triple.tc_list)) /* Only triples with one allowed quad map can be reused, unions can not */
            continue;
          if (NULL != base->_.triple.options)
            continue;
          sparp_try_reuse_tabid_in_join (sparp, curr, base_idx);
        }
      END_DO_BOX_FAST;
      break;
    case OPTIONAL_L:
      {
        sparp_equiv_t *eq_as_filter = NULL;
        SPART *base;
        quad_map_t *base_qm;
        int eq_ctr, key_field_idx;
        if ((0 != BOX_ELEMENTS_0 (curr->_.gp.filters)) ||
          (1 != BOX_ELEMENTS_0 (curr->_.gp.members)) ||
          (SPAR_TRIPLE != SPART_TYPE (curr->_.gp.members[0])) )
          break;
        if (NULL != curr->_.gp.options)
          break;
        SPARP_FOREACH_GP_EQUIV (sparp, curr, eq_ctr, eq)
          {
            if (eq->e_replaces_filter)
              {
                eq_as_filter = eq;
                break;
              }
          }
        END_SPARP_FOREACH_GP_EQUIV;
        if (NULL != eq_as_filter)
          break;
        base = curr->_.gp.members[0];
        base_qm = base->_.triple.tc_list[0]->tc_qm;
        for (key_field_idx = 0; key_field_idx < SPART_TRIPLE_FIELDS_COUNT; key_field_idx++)
          {
            SPART *key_field = base->_.triple.tr_fields[key_field_idx];
            ssg_valmode_t key_fmt = base->_.triple.native_formats[key_field_idx];
            qm_value_t *key_qmv;
            sparp_jso_validate_format (sparp, key_fmt);
            if (!SPAR_IS_BLANK_OR_VAR (key_field)) /* Non-variables can not result in tabid reuse atm, !!!TBD: support for { <pk> ?p1 ?o1 . OPTIONAL { <pk> ?p2 ?o2 } } */
              continue;
            key_qmv = SPARP_FIELD_QMV_OF_QM (base_qm,key_field_idx);
            if (!sparp_qmv_forms_reusable_key_of_qm (sparp, key_qmv, base_qm))
              continue;
            t_set_push (((dk_set_t *)(common_env)), curr);
            return 0;
          }
        break;
      }
    }
  return 0;
}

#define SPARP_QM_CONDS_SOME_A_NOT_IN_B 0x1
#define SPARP_QM_CONDS_SOME_B_NOT_IN_A 0x2

int
sparp_qm_conds_cmp (sparp_t *sparp, quad_map_t *qm_a, quad_map_t *qm_b)
{
  int a_ctr, a_count = qm_a->qmAllCondCount;
  int b_ctr, b_count = qm_b->qmAllCondCount;
  int res = 0;
  for (a_ctr = a_count; a_ctr--; /* no step */)
    {
      ccaddr_t a_cond = qm_a->qmAllConds [a_ctr];
      int a_in_b = 0;
      for (b_ctr = b_count; b_ctr--; /* no step */)
        {
          ccaddr_t b_cond = qm_b->qmAllConds [b_ctr];
          if (strcmp (a_cond, b_cond))
            continue;
          a_in_b = 1;
          break;
        }
      if (a_in_b)
        continue;
      res |= SPARP_QM_CONDS_SOME_A_NOT_IN_B;
      break;
    }
  for (b_ctr = b_count; b_ctr--; /* no step */)
    {
      ccaddr_t b_cond = qm_b->qmAllConds [b_ctr];
      int b_in_a = 0;
      for (a_ctr = a_count; a_ctr--; /* no step */)
        {
          ccaddr_t a_cond = qm_a->qmAllConds [a_ctr];
          if (strcmp (b_cond, a_cond))
            continue;
          b_in_a = 1;
          break;
        }
      if (b_in_a)
        continue;
      res |= SPARP_QM_CONDS_SOME_B_NOT_IN_A;
      break;
    }
  return res;
}

static int
sparp_try_reduce_trivial_optional_via_eq (sparp_t *sparp, SPART *opt, SPART *key_field, qm_value_t *key_qmv, sparp_equiv_t *key_recv_eq, SPART *key_asc_or_self)
{ /* \c opt is OPTIONAL_L gp with triple inside, key_field is a "linking" variable in that triple,  */
  int dep_ctr;
  SPART *key_recv_gp = key_recv_eq->e_gp;
  if ((0 != key_recv_gp->_.gp.subtype) && (WHERE_L != key_recv_gp->_.gp.subtype))
    return 0;
  for (dep_ctr = key_recv_eq->e_var_count; dep_ctr--; /* no step */)
    {
      sparp_equiv_t *key_field_eq;
      SPART *opt_triple;
      SPART *opt_parent;
      SPART *dep_field = key_recv_eq->e_vars[dep_ctr];	/*!< Candidate for variable that matches to \c key field but located at the parent gp of the OPTIONAL */
      int dep_triple_idx, dep_field_tr_idx, o_p_idx, field_ctr, optimizable_field_idx = 0;
      int optimization_blocked_by_filters = 0;	/*!< Flags if the OPTIONAL can not be eliminated because it contains conditions that can not be moved to the receiver */
      int recvd_field_count = 0;		/*!< Number of variable fields in OPTIONAL that are connected to something outside and thus the triple pattern is not absolutely redundand */
      int optimizable_field_count = 0;	/*!< Number of variable fields in OPTIONAL that are not known as NOT NULL in the receiving GP */
      int really_nullable_count = 0;	/*!< Number of variable fields in OPTIONAL that can in principle be NULL if key is not null */
      SPART *dep_triple = NULL;		/*!< The triple outside OPTIONAL that contains \c dep_field */
      quad_map_t *dep_qm, *opt_qm;
      qm_value_t *dep_qmv;
      if (NULL == dep_field->_.var.tabid) /* The variable is not a field in a triple (const read, not gspo use) */
        continue;
      dep_field_tr_idx = dep_field->_.var.tr_idx;
      for (dep_triple_idx = BOX_ELEMENTS (key_recv_gp->_.gp.members); dep_triple_idx--; /* no step */)
        {
          dep_triple = key_recv_gp->_.gp.members[dep_triple_idx];
          if (SPAR_TRIPLE != dep_triple->type)
            continue;
          if (dep_triple->_.triple.tr_fields [dep_field_tr_idx] == dep_field)
            break;
        }
      if (0 > dep_triple_idx)
        {
          sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
          spar_internal_error (sparp, "sparp_" "try_reduce_trivial_optional_via_eq(): dep_field not found in member triples");
        }
      if (OPTIONAL_L == dep_triple->_.triple.subtype) /* Optional is bad candidate for reuse */
        continue;
      if (1 != BOX_ELEMENTS (dep_triple->_.triple.tc_list)) /* Only triples with one allowed quad mapping can be reused, unions can not */
        continue;
      dep_qm = dep_triple->_.triple.tc_list[0]->tc_qm;
      dep_qmv = SPARP_FIELD_QMV_OF_QM (dep_qm, dep_field_tr_idx);
      if (key_qmv != dep_qmv) /* The key mapping differs in set of source columns or in the IRI serialization (or literal cast) */
        continue;
      if (!sparp_qmv_forms_reusable_key_of_qm (sparp, dep_qmv, dep_qm))
        continue;
      opt_triple = opt->_.gp.members[0];
      opt_qm = opt_triple->_.triple.tc_list[0]->tc_qm;
      if (SPARP_QM_CONDS_SOME_B_NOT_IN_A & sparp_qm_conds_cmp (sparp, dep_qm, opt_qm))
        continue; /* If some WHERE conditions of optional are not in WHERE list of required then this is true LEFT OUTER */
      /* Now we're looking for a field that may be NOT NULL outside the OPTIONAL but should be NOT NULL inside the optional binding but may be NULL in the data set */
      for (field_ctr = SPART_TRIPLE_FIELDS_COUNT; field_ctr--; /*no step*/)
        {
          SPART *fld_expn = opt_triple->_.triple.tr_fields[field_ctr];	/*!< Non-key field inside the triple of OPTIONAL {...} */
          qm_value_t *fld_qmv;
          sparp_equiv_t *fld_eq;
          int recv_ctr, recv_count, some_recv_is_nullable;
          fld_qmv = SPARP_FIELD_QMV_OF_QM (opt_qm, field_ctr);
          if (!SPAR_IS_BLANK_OR_VAR (fld_expn))
            {
              if (NULL == fld_qmv)
                continue; /* Const is equal to const, otherwise it would be wiped away before as conflict */
              /* constant in triple pattern and a quad map value implies the equality condition in the OPTIONAL, can't optimize under any circumstances */
              return 0;
            }
          fld_eq = sparp_equiv_get (sparp, opt, fld_expn, SPARP_EQUIV_GET_ASSERT);
          if (fld_eq->e_replaces_filter & ~(fld_expn->_.var.restr_of_col))
            return 0; /* if eq replaces "non-redundand" filters then it's as bad as having true FILTERs inside the OPTIONAL */
          if (fld_expn == key_field)
            continue; /* key field can't be NULL inside OPTIONAL and non-NULL outside OPTIONAL */
          if ((NULL != fld_qmv) && !(SPART_VARR_NOT_NULL & fld_qmv->qmvRange.rvrRestrictions))
            really_nullable_count++;
          some_recv_is_nullable = 0;
          if (1 < fld_eq->e_gspo_uses)
            return 0; /* two vars inside equiv implies the equality condition in the OPTIONAL, can't optimize after that */
          if ((NULL != fld_qmv) && (SPART_VARR_FIXED & fld_eq->e_rvr.rvrRestrictions))
            return 0; /* a fixed value for a var implies the equality condition in the OPTIONAL, can't optimize after that */
          recv_count = BOX_ELEMENTS_0 (fld_eq->e_receiver_idxs);
          if (recv_count)
            recvd_field_count++;
          for (recv_ctr = 0; recv_ctr < recv_count; recv_ctr++)
            {
              ptrlong recv_idx = fld_eq->e_receiver_idxs[recv_ctr];
              sparp_equiv_t *recv_eq = SPARP_EQUIV (sparp, recv_idx);
              if (!(recv_eq->e_rvr.rvrRestrictions & SPART_VARR_NOT_NULL))
                some_recv_is_nullable = 1;
/* A non-nullable variable outside should be equal to a variable inside, that implies an equality condition in join, so we can't optimize after that.
There's one exception. If the only use of a variable is in dep_triple and it is made by same quad map value then there's no need in equality condition
because both variable outside and variable inside will produce identical SQL code, hence no need to check the equality at all. */
              if ((1 < recv_eq->e_gspo_uses) || recv_eq->e_subquery_uses || (1 < BOX_ELEMENTS_0 (recv_eq->e_subvalue_idxs)))
                return 0;
              if (1 == recv_eq->e_gspo_uses)
                {
                  int d_fld_ctr;
                  for (d_fld_ctr = SPART_TRIPLE_FIELDS_COUNT; d_fld_ctr--; /* no step */)
                    {
                      SPART *d_fld = dep_triple->_.triple.tr_fields[d_fld_ctr];
                      if (SPAR_IS_BLANK_OR_VAR (d_fld) && (d_fld->_.var.equiv_idx == recv_idx))
                        break;
                    }
                  if (0 > d_fld_ctr)
                    { /* The GSPO use is not found in dep_triple, hence that's not an exception. */
                      optimization_blocked_by_filters = 1;
                      break;
                    }
                  if (SPARP_FIELD_QMV_OF_QM (dep_qm, d_fld_ctr) != fld_qmv)
                    { /* The inner var occurs only in dep_triple, but made by other qmv, hence that's not an exception. */
                      optimization_blocked_by_filters = 1;
                      break;
                    }
                }
            }
          if (some_recv_is_nullable)
            {
              optimizable_field_idx = field_ctr;
              optimizable_field_count++;
            }
        }
      if (optimization_blocked_by_filters || ((0 != really_nullable_count) && (1 < optimizable_field_count)))
        continue; /* If more than one variable is not known outside as NOT_NULL then the optimized variant may produce a solution with one optional variable bound and one NULL */
      /* Glory, glory, hallelujah; we can cut optional triple reuse the tabid so the final SQL query will have one join less. */
      sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
      key_field_eq = SPARP_EQUIV (sparp, key_field->_.var.equiv_idx);
      opt_parent = SPARP_EQUIV (sparp, key_field_eq->e_receiver_idxs[0])->e_gp;
      sparp_gp_detach_member (sparp, opt, 0, NULL);
      o_p_idx = BOX_ELEMENTS(opt_parent->_.gp.members) - 1;
      if (opt_parent->_.gp.members [o_p_idx] != opt)
        spar_internal_error (sparp, "sparp_" "try_reduce_trivial_optional_via_eq(): can not locate OPTIONAL in parent");
      sparp_gp_detach_member (sparp, opt_parent, o_p_idx, NULL);
      if (recvd_field_count) /* If nothing is received from an optimizable OPTIONAL in question then the triple patterns is entirely useless */
        {
          sparp_gp_attach_member (sparp, key_recv_gp, opt_triple, dep_triple_idx+1, NULL);
          sparp_set_triple_selid_and_tabid (sparp, opt_triple, key_recv_gp->_.gp.selid, dep_triple->_.triple.tabid);
          if (0 != really_nullable_count)
            {
              opt_triple->_.triple.subtype = OPTIONAL_L;
              if (optimizable_field_count)
                {
                  SPART *optimizable_field = opt_triple->_.triple.tr_fields [optimizable_field_idx];
                  if (SPAR_IS_BLANK_OR_VAR (optimizable_field))
                    optimizable_field->_.var.rvr.rvrRestrictions &= ~SPART_VARR_NOT_NULL;
                }
            }
        }
      sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
      return 1;
    }
  DO_BOX_FAST (ptrlong, dep_idx, dep_ctr, key_recv_eq->e_subvalue_idxs)
    {
      sparp_equiv_t *dep_eq = SPARP_EQUIV (sparp, dep_idx);
      if (dep_eq->e_gp == key_asc_or_self) /* -- Back to origin? -- No, thanks. */
        continue;
      if (sparp_try_reduce_trivial_optional_via_eq (sparp, opt, key_field, key_qmv, dep_eq, NULL))
        return 1;
    }
  END_DO_BOX_FAST;
  DO_BOX_FAST (ptrlong, dep_idx, dep_ctr, key_recv_eq->e_receiver_idxs)
    {
      sparp_equiv_t *dep_eq = SPARP_EQUIV (sparp, dep_idx);
      if (sparp_try_reduce_trivial_optional_via_eq (sparp, opt, key_field, key_qmv, dep_eq, key_recv_gp))
        return 1;
    }
  END_DO_BOX_FAST;
  return 0;
}

static int
sparp_reduce_trivial_optional (sparp_t *sparp, SPART *opt)
{
  SPART *base = opt->_.gp.members[0];
  quad_map_t *base_qm = base->_.triple.tc_list[0]->tc_qm;
  int key_field_idx, recv_ctr;
  for (key_field_idx = 0; key_field_idx < SPART_TRIPLE_FIELDS_COUNT; key_field_idx++)
    {
      SPART *key_field = base->_.triple.tr_fields[key_field_idx];
      ssg_valmode_t key_fmt = base->_.triple.native_formats[key_field_idx];
      qm_value_t *key_qmv;
      sparp_equiv_t *key_eq;
      sparp_jso_validate_format (sparp, key_fmt);
      if (!SPAR_IS_BLANK_OR_VAR (key_field)) /* Non-variables can not result in tabid reuse atm, !!!TBD: support for { <pk> ?p1 ?o1 . OPTIONAL { <pk> ?p2 ?o2 } } */
        continue;
      key_qmv = SPARP_FIELD_QMV_OF_QM (base_qm,key_field_idx);
      if (!sparp_qmv_forms_reusable_key_of_qm (sparp, key_qmv, base_qm))
        continue;
      key_eq = sparp_equiv_get (sparp, opt, key_field, SPARP_EQUIV_GET_ASSERT);
      DO_BOX_FAST (ptrlong, recv_idx, recv_ctr, key_eq->e_receiver_idxs)
        {
          sparp_equiv_t *recv_eq = SPARP_EQUIV (sparp, recv_idx);
          if (sparp_try_reduce_trivial_optional_via_eq (sparp, opt, key_field, key_qmv, recv_eq, opt))
            return 1;
        }
      END_DO_BOX_FAST;
    }
  return 0;
}


SPART *
sparp_rewrite_all (sparp_t *sparp, SPART *req_top, int safely_copy_retvals)
{
  ptrlong top_type = SPART_TYPE (req_top);
  if ((NULL == sparp->sparp_env->spare_storage_name) && (NULL == sparp->sparp_storage))
    sparp->sparp_storage = sparp_find_storage_by_name (NULL);
  if (SPAR_QM_SQL_FUNCALL == top_type)
    return req_top;
  if (SPAR_CODEGEN == top_type)
    return req_top;
  sparp_rewrite_retvals (sparp, req_top, safely_copy_retvals);
  if ((sparp->sparp_env->spare_src.ssrc_grab.rgc_pview_mode) && (NULL == sparp->sparp_suspended_stps))
    return sparp_rewrite_grab (sparp, req_top);
  return sparp_rewrite_qm (sparp, req_top);
}

/*! This fixes sparql select * where {{ select * where { ?s <knows> ?o }} . filter (?s=<me>)}.
Without the fix, the SQL text lacks s=<me> condition in WHERE because it's converted to SPART_VARR_FIXED of equiv but not printed in any triple pattern */
int
sparp_gp_trav_restore_filters_for_weird_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  int eq_ctr;
  if (SPAR_GP != SPART_TYPE (curr))
    return SPAR_GPT_NODOWN;
  if (SELECT_L != curr->_.gp.subtype)
    {
      SPART *sinv = sparp_get_option (sparp, curr->_.gp.options, SPAR_SERVICE_INV);
      if (NULL != sinv)
        sts_this[0].sts_env = sinv;
      else
        sts_this[0].sts_env = sts_this[-1].sts_env;
      return SPAR_GPT_ENV_PUSH; /* SPAR_GPT_ENV_PUSH is not really required for this callback by itself,
because parent gp can be obtained as an ancestor_gp, but it is required for \c sparp_gp_trav_add_graph_perm_read_filters() that can be
used in one iteration with sparp_gp_trav_restore_filters_for_weird_subq(). Permission processing is a postorder callback whereas
restoring filters is a preorder one, the postorder needs a complete stack of things */
    }
  SPARP_FOREACH_GP_EQUIV (sparp, curr, eq_ctr, eq)
    {
      sparp_equiv_t *subq_eq, *recv_eq;
      SPART *parent_gp;
      ptrlong missing_restrictions;
      subq_eq = sparp_equiv_get (sparp,
        curr->_.gp.subquery->_.req_top.pattern, (SPART *)(eq->e_varnames[0]),
        SPARP_EQUIV_GET_NAMESAKES );
      if (NULL == subq_eq)
        continue;
      missing_restrictions = (eq->e_rvr.rvrRestrictions & ~subq_eq->e_rvr.rvrRestrictions) & SPART_VARR_FIXED;
      if (!missing_restrictions)
        continue;
      parent_gp = sts_this->sts_parent;
      if (0 != BOX_ELEMENTS_0 (eq->e_receiver_idxs))
        {
          recv_eq = SPARP_EQUIV (sparp, eq->e_receiver_idxs[0]);
          if ((0 != recv_eq->e_gspo_uses) && (recv_eq->e_rvr.rvrRestrictions & SPART_VARR_NOT_NULL) &&
            (0 == eq->e_pos1_t_in) && (0 == eq->e_pos1_t_out) )
            continue;
        }
      else
        recv_eq = NULL;
      if (missing_restrictions & SPART_VARR_FIXED)
        {
          SPART *l = NULL, *r, *filt;
          l = spartlist (sparp, 7 + (sizeof (rdf_val_range_t) / sizeof (caddr_t)),
            SPAR_VARIABLE, eq->e_varnames[0],
            parent_gp->_.gp.selid, NULL,
            (ptrlong)(0), SPART_BAD_EQUIV_IDX, SPART_RVR_LIST_OF_NULLS, (ptrlong)(0x0) );
            memcpy (&(l->_.var.rvr.rvrRestrictions), &(subq_eq->e_rvr), sizeof (rdf_val_range_t));
          if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (eq->e_rvr.rvrFixedValue))
            r = (SPART *)eq->e_rvr.rvrFixedValue;
          else if (eq->e_rvr.rvrRestrictions & SPART_VARR_IS_REF)
            r = spartlist (sparp, 2, SPAR_QNAME, eq->e_rvr.rvrFixedValue);
          else
            r = spartlist (sparp, 4, SPAR_LIT, eq->e_rvr.rvrFixedValue, eq->e_rvr.rvrDatatype, eq->e_rvr.rvrLanguage);
          filt = spartlist (sparp, 3, BOP_EQ, l, r);
          sparp_gp_attach_filter (sparp, parent_gp, filt, 0, NULL);
          if (NULL == recv_eq)
            {
              recv_eq = SPARP_EQUIV (sparp, l->_.var.equiv_idx);
              sparp_equiv_connect_outer_to_inner (sparp, recv_eq, eq, 1);
            }
          recv_eq->e_rvr.rvrRestrictions &= ~SPART_VARR_FIXED;
          eq->e_rvr.rvrRestrictions &= ~SPART_VARR_FIXED;
        }
    }
  END_SPARP_FOREACH_GP_EQUIV;
  return SPAR_GPT_NODOWN;
}

int
sparp_gp_trav_add_graph_perm_read_filters (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  SPART **sources;
  int depth, membctr, membcount;
  if (SPAR_GP != SPART_TYPE (curr))
    return 0;
  if (SELECT_L == curr->_.gp.subtype)
    return 0;
  if (sparp->sparp_query_uses_sinvs)
    { /* Bug 14737 fix: No permission filters should be placed inside service invocations */
      if (sparp->sparp_env->spare_storage_name == uname_virtrdf_ns_uri_DefaultServiceStorage)
        return 0;
      if (NULL != sts_this->sts_env)
        return 0;
    }
  sources = sparp->sparp_stp->stp_trav_req_top->_.req_top.sources;
  membcount = BOX_ELEMENTS_0 (curr->_.gp.members);
  for (membctr = 0; membctr < membcount; membctr++)
    {
      SPART *memb = curr->_.gp.members[membctr];
      SPART *g_expn, *g_copy, *filter;
      SPART *g_norm_expn;
      SPART *g_fake_arg_for_side_fx = NULL;
      ccaddr_t fixed_g;
      dtp_t g_norm_expn_dtp;
      int g_norm_is_var;
      SPART *gp_of_cache;
      if (SPAR_TRIPLE != memb->type)
        continue;
      if (NULL != memb->_.triple.sinv_idx_and_qms[0])
        continue; /* New fix for reopened Bug 14737: No permission filters should be placed inside service invocations */
      g_expn = memb->_.triple.tr_graph;
      if (!spar_graph_needs_security_testing (sparp, g_expn, RDF_GRAPH_PERM_READ))
        continue;
      if (spar_plain_const_value_of_tree (g_expn, &fixed_g))
        {
          int ctr;
          g_norm_expn = (SPART *)fixed_g;
          g_norm_expn_dtp = DV_TYPE_OF (g_norm_expn);
          g_norm_is_var = 0;
          DO_BOX_FAST (SPART *, src, ctr, sources)
            {
              if (src->_.graph.use_expn_in_gs_checks && IS_BOX_POINTER (g_norm_expn) && !strcmp (SPAR_LIT_OR_QNAME_VAL (g_norm_expn), src->_.graph.iri))
                {
                  g_fake_arg_for_side_fx = sparp_tree_full_copy (sparp, src->_.graph.expn, curr);
                  break;
                }
            }
          END_DO_BOX_FAST;
        }
      else
        {
          int ctr;
          dk_set_t candidates = NULL;
          g_norm_expn = g_expn;
          if (!SPAR_IS_BLANK_OR_VAR (g_norm_expn))
            continue;
          g_norm_expn_dtp = DV_ARRAY_OF_POINTER;
          g_norm_is_var = 1;
          DO_BOX_FAST (SPART *, src, ctr, sources)
            {
              if (src->_.graph.use_expn_in_gs_checks && ((SPART_IS_DEFAULT_GRAPH_BLANK (g_norm_expn) ? SPART_GRAPH_FROM : SPART_GRAPH_NAMED) == src->_.graph.subtype))
                t_set_push (&candidates, sparp_tree_full_copy (sparp, src->_.graph.expn, curr));
            }
          END_DO_BOX_FAST;
          if (NULL != candidates)
            g_fake_arg_for_side_fx = spar_make_funcall (sparp, 0, "bif:vector", (SPART **)t_revlist_to_array (candidates));
        }
      gp_of_cache = curr;
      for (depth = 0; ; depth--)
        {
          dk_set_t cached_graph_expns;
          cached_graph_expns = sts_this[depth].sts_env;
          DO_SET (SPART *, prev, &cached_graph_expns)
            {
              if (DV_TYPE_OF (prev) != g_norm_expn_dtp)
                continue;
              if (g_norm_is_var)
                {
                  if (prev->_.var.equiv_idx == g_norm_expn->_.var.equiv_idx)
                    goto g_norm_expn_is_dupe; /* see below */
                  if (!strcmp (prev->_.var.vname, g_norm_expn->_.var.vname))
                    goto g_norm_expn_is_dupe; /* see below */
                }
              else if (box_equal (prev, g_norm_expn))
                goto g_norm_expn_is_dupe; /* see below */
            }
          END_DO_SET()
          if ((OPTIONAL_L == gp_of_cache->_.gp.subtype) || (WHERE_L == gp_of_cache->_.gp.subtype))
            break;
          gp_of_cache = sts_this[depth].sts_parent;
          if ((UNION_L == gp_of_cache->_.gp.subtype) || (SPAR_UNION_WO_ALL == gp_of_cache->_.gp.subtype))
            break;
        }
      g_copy = sparp_tree_full_copy (sparp, g_norm_expn, curr);
      if (g_norm_is_var)
        {
          g_copy->_.var.tr_idx = 0;
          g_copy->_.var.tabid = NULL;
          g_copy->_.var.equiv_idx = SPART_BAD_EQUIV_IDX;
        }
      filter = spar_make_funcall (sparp, 0,
        ((NULL != sparp->sparp_gs_app_callback) ? "SPECIAL::bif:__rgs_ack_cbk" : "SPECIAL::bif:__rgs_ack"),
        (NULL == g_fake_arg_for_side_fx) ?
          (SPART **)t_list (3, g_copy, spar_exec_uid_and_gs_cbk (sparp), RDF_GRAPH_PERM_READ) :
          (SPART **)t_list (5, g_copy, spar_exec_uid_and_gs_cbk (sparp), RDF_GRAPH_PERM_READ,
            spartlist (sparp, 4, SPAR_LIT, t_box_dv_short_string ("SPARQL query"), NULL, NULL),
            g_fake_arg_for_side_fx ) );
      sparp_gp_attach_filter (sparp, curr, filter, 0, NULL);
      if (!g_norm_is_var ||
        ((SPART_VARR_NOT_NULL & g_norm_expn->_.var.rvr.rvrRestrictions) &&
          !(SPART_VARR_CONFLICT & g_norm_expn->_.var.rvr.rvrRestrictions) ) )
        t_set_push ((dk_set_t *)(&(sts_this[0].sts_env)), (SPART *)g_norm_expn);
g_norm_expn_is_dupe: ;
    }
  if ((OPTIONAL_L != curr->_.gp.subtype) &&
    (WHERE_L != curr->_.gp.subtype) &&
    (UNION_L != sts_this[0].sts_parent->_.gp.subtype) &&
    (SPAR_UNION_WO_ALL != sts_this[0].sts_parent->_.gp.subtype) )
    {
      dk_set_t curr_graph_expns = (dk_set_t)(sts_this[0].sts_env);
      dk_set_t parent_graph_expns = (dk_set_t)(sts_this[-1].sts_env);
      DO_SET (SPART *, expn, &curr_graph_expns)
        {
          dtp_t expn_dtp = DV_TYPE_OF (expn);
          int expn_is_var = SPAR_IS_BLANK_OR_VAR (expn);
          DO_SET (SPART *, prev, &parent_graph_expns)
            {
              if (DV_TYPE_OF (prev) != expn_dtp)
                continue;
              if (expn_is_var)
                {
                  if (prev->_.var.equiv_idx == expn->_.var.equiv_idx)
                    goto expn_is_dupe; /* see below */
                  if (!strcmp (prev->_.var.vname, expn->_.var.vname))
                    goto expn_is_dupe; /* see below */
                }
              else if (box_equal (prev, expn))
                goto expn_is_dupe; /* see below */
            }
          END_DO_SET ()
          t_set_push (&parent_graph_expns, expn);
          if (expn_is_var)
            {
              sparp_equiv_t *expn_eq = SPARP_EQUIV (sparp, expn->_.var.equiv_idx);
              int recvctr;
              DO_BOX_FAST (ptrlong, recv_idx, recvctr, expn_eq->e_receiver_idxs)
                {
                  sparp_equiv_t *recv_eq = SPARP_EQUIV (sparp, recv_idx);
                  if (recv_eq->e_var_count)
                    t_set_push (&parent_graph_expns, recv_eq->e_vars[0]);
                }
              END_DO_BOX_FAST;
            }
expn_is_dupe: ;
        }
      END_DO_SET ()
    }
  return 0;
}

SPART *
sparp_rewrite_qm (sparp_t *sparp, SPART *req_top)
{
  if (SPAR_CODEGEN == SPART_TYPE (req_top))
    return req_top;
  if (SPAR_QM_SQL_FUNCALL == SPART_TYPE (req_top))
    return req_top;
  sparp_rewrite_qm_preopt (sparp, req_top, 1);
  sparp_rewrite_qm_optloop (sparp, req_top, SPARP_MULTIPLE_OPTLOOPS);
  sparp_rewrite_qm_postopt (sparp, req_top);
  return req_top;
}

int
sparp_dig_and_glue_loj_filter_for_eq (sparp_t *sparp, sparp_equiv_t *eq)
{
  SPART *gp = eq->e_gp;
  sparp_equiv_t *good_recv_eq = NULL;
  SPART *good_recv_gp;
  int recv_ctr, filter_ctr;
  if ((OPTIONAL_L != gp->_.gp.subtype) || (0 == eq->e_const_reads) || (0 == BOX_ELEMENTS_0 (eq->e_receiver_idxs)))
    return 0;
  for (recv_ctr = BOX_ELEMENTS (eq->e_receiver_idxs); recv_ctr--; /* no step */)
    {
      sparp_equiv_t *recv_eq = SPARP_EQUIV(sparp, eq->e_receiver_idxs[recv_ctr]);
      if (SPARP_EQ_IS_ASSIGNED_EXTERNALLY(recv_eq) || SPARP_EQ_IS_ASSIGNED_LOCALLY(recv_eq))
        {
          good_recv_eq = recv_eq;
          break;
        }
    }
  if (good_recv_eq == NULL)
    return 0;
  good_recv_gp = good_recv_eq->e_gp;
  for (filter_ctr = BOX_ELEMENTS_0 (gp->_.gp.filters) - gp->_.gp.glued_filters_count; filter_ctr--; /* no step */)
    {
      SPART *filt = gp->_.gp.filters[filter_ctr];
      if (!sparp_expn_reads_equiv (sparp, filt, eq))
        continue;
      good_recv_gp = good_recv_eq->e_gp;
      if ((UNION_L == good_recv_gp->_.gp.subtype) || (SPAR_UNION_WO_ALL == good_recv_gp->_.gp.subtype))
        spar_error (sparp, "Variable '%.100s' is used in OPTIONAL inside UNION but not assigned in OPTIONAL, please rephrase the query", eq->e_varnames[0]);
      sparp_gp_detach_filter (sparp, gp, filter_ctr, NULL);
      sparp_gp_attach_filter (sparp, good_recv_gp, filt, BOX_ELEMENTS_0 (good_recv_gp->_.gp.filters) - good_recv_gp->_.gp.glued_filters_count, NULL);
      good_recv_gp->_.gp.glued_filters_count += 1;
    }
  return 0;
}

void
sparp_rewrite_qm_preopt (sparp_t *sparp, SPART *req_top, int safely_copy_retvals)
{
  sparp_equiv_t **equivs /* do not set here */;
  int equiv_ctr, equiv_count;
  if (SPAR_CODEGEN == SPART_TYPE (req_top))
    GPF_T1 ("sparp_" "rewrite_qm_preopt () for CODEGEN");
  if (SPAR_QM_SQL_FUNCALL == SPART_TYPE (req_top))
    GPF_T1 ("sparp_" "rewrite_qm_preopt () for SQL_FUNCALL");

retry_preopt:
  sparp_rewrite_basic (sparp, req_top);
  if (sparp->sparp_sg->sg_signal_void_variables)
    sparp_simplify_expns (sparp, req_top);
  equivs = sparp->sparp_sg->sg_equivs;
  equiv_count = sparp->sparp_sg->sg_equiv_count;
  for (equiv_ctr = sparp->sparp_first_equiv_idx; equiv_ctr < equiv_count; equiv_ctr++)
    {
      sparp_equiv_t *eq = equivs[equiv_ctr];
      if (NULL == eq)
        continue;
      if (SPARP_EQ_IS_ASSIGNED_EXTERNALLY(eq) || SPARP_EQ_IS_ASSIGNED_LOCALLY(eq))
        continue;
      if (!SPARP_EQ_IS_USED(eq))
        continue;
      if ((1 == eq->e_var_count) && SPART_VARNAME_IS_SPECIAL (eq->e_varnames[0]))
        continue; /* Special variable is not assigned in SPARQL (by BGPs or externals) but it is assigned in SQL code by codegen. Can't check, just believe in the codegen :) */
      /* At this point we know that some variable is used but not assigned. It may be non-optional variable in FILTER inside OPTIONAL or an error. */
      if (sparp_dig_and_glue_loj_filter_for_eq (sparp, eq))
        goto retry_preopt; /* see above */
      if (sparp->sparp_sg->sg_signal_void_variables)
        {
          if (eq->e_rvr.rvrRestrictions & SPART_VARR_EXPORTED)
            spar_error (sparp, "Variable '%.100s' is used in the query result set but not assigned", eq->e_varnames[0]);
          if ((0 != eq->e_const_reads) || /* note: no check for (0 != eq->e_optional_reads) */
            (0 != BOX_ELEMENTS_0 (eq->e_receiver_idxs)) )
            spar_error (sparp, "Variable '%.100s' is used in subexpressions of the query but not assigned", eq->e_varnames[0]);
        }
    }
/* Building qm_list for every triple in the tree. */
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    sparp_gp_trav_refresh_triple_cases, NULL,
    NULL, NULL, NULL,
    NULL );
  sparp_equiv_audit_all (sparp, 0);
  sparp_rewrite_basic (sparp, req_top);
}

int
sparp_gp_trav_rewrite_qm_optloop (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_gp_trav_suspend (sparp);
  if (sparp_rewrite_qm_optloop (sparp, curr->_.gp.subquery, (ptrlong)common_env))
    sparp->sparp_rewrite_dirty = 1;
  sparp_gp_trav_resume (sparp);
  return 0;
}

int
sparp_rewrite_qm_optloop (sparp_t *sparp, SPART *req_top, int opt_ctr)
{
  int res;
  int saved_sparp_rewrite_dirty = sparp->sparp_rewrite_dirty;
  if (SPAR_CODEGEN == SPART_TYPE (req_top))
    GPF_T1 ("sparp_" "rewrite_qm_postopt () for CODEGEN");
  if (SPAR_QM_SQL_FUNCALL == SPART_TYPE (req_top))
    GPF_T1 ("sparp_" "rewrite_qm_optloop () for SQL_FUNCALL");
  if (SPARP_MULTIPLE_OPTLOOPS == opt_ctr)
    {
      SPART *binv = req_top->_.req_top.binv;
      int old_bindings_len = ((NULL != binv) ? BOX_ELEMENTS (binv->_.binv.data_rows) : -1);
      int optimization_loop_ctr = 0;
      int optimization_loop_count = 10 + ((NULL != binv) ? 2 * BOX_ELEMENTS (binv->_.binv.vars) : 0);
      while (sparp_rewrite_qm_optloop (sparp, req_top, optimization_loop_ctr))
        {
          if (0 < old_bindings_len)
            { /* Shortening BINDINGS table can be arbitrarily long but it can't be infinite so optimization_loop_ctr is left intact */
              int new_bindings_len = BOX_ELEMENTS (binv->_.binv.data_rows);
              if (new_bindings_len < old_bindings_len)
                {
                  old_bindings_len = new_bindings_len;
                  continue;
                }
            }
          if (++optimization_loop_ctr < optimization_loop_count)
            continue;
#if 0
          spar_internal_error (sparp, "SPARQL optimizer performed too many rounds of query rewriting, this looks like endless loop. Please rephrase the query.");
#else
          break; /* Now our public endpoints are protected with timeouts, we can try SQL garbage */
#endif
        }
      return optimization_loop_ctr;
    }
  sparp_equiv_audit_all (sparp, 0);
  sparp->sparp_rewrite_dirty = 0;
/* Converting to GP_UNION of every triple such that many quad maps contains triples that matches the mapping pattern */
  sparp_gp_trav_top_pattern (sparp, req_top, (void *)((ptrlong)opt_ctr),
    sparp_gp_trav_refresh_triple_cases, sparp_gp_trav_multiqm_to_unions,
    NULL, NULL, sparp_gp_trav_rewrite_qm_optloop,
    NULL );
  sparp_trav_out_clauses (sparp, req_top, (void *)((ptrlong)opt_ctr),
    NULL, NULL,
    NULL, NULL, sparp_gp_trav_rewrite_qm_optloop,
    NULL );
  sparp_equiv_audit_all (sparp, 0);
  sparp_rewrite_basic (sparp, req_top);
  sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
/* Converting join with a union into a union of joins with parts of union */
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    sparp_gp_trav_union_of_joins_in, sparp_gp_trav_union_of_joins_out,
    NULL, NULL, NULL,
    NULL );
  sparp_equiv_audit_all (sparp, 0);
  sparp_rewrite_basic (sparp, req_top);
/* Removal of gps that can not produce results */
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    NULL, sparp_gp_trav_detach_conflicts_out,
    NULL, NULL, NULL,
    NULL );
  sparp_equiv_audit_all (sparp, 0);
  sparp_rewrite_basic (sparp, req_top);
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    NULL, sparp_gp_trav_detach_conflicts_out,
    NULL, NULL, NULL,
    NULL );
  sparp_equiv_audit_all (sparp, 0);
  sparp_simplify_expns (sparp, req_top);
  sparp_rewrite_basic (sparp, req_top);
  sparp_equiv_audit_all (sparp, 0);
  if (!(opt_ctr % 2)) /* Do this not in every loop because it's costly and it almost never give a result after first loop */
    {
      sparp_gp_trav_top_pattern (sparp, req_top, NULL,
        sparp_gp_trav_localize_filters, NULL,
        NULL, NULL, NULL,
        NULL );
      sparp_equiv_audit_all (sparp, 0);
      sparp_rewrite_basic (sparp, req_top);
      sparp_equiv_audit_all (sparp, 0);
    }
  sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
  sparp_trav_out_clauses (sparp, req_top, req_top->_.req_top.pattern,
    NULL, NULL,
    NULL, NULL, sparp_gp_trav_rewrite_qm_optloop,
    NULL );
  sparp_equiv_audit_all (sparp, SPARP_EQUIV_AUDIT_NOBAD);
  res = sparp->sparp_rewrite_dirty;
  sparp->sparp_rewrite_dirty = saved_sparp_rewrite_dirty;
  return res;
}

int
sparp_retval_should_wrap_distinct (sparp_t *sparp, SPART *tree, SPART *rv)
{
  ssg_valmode_t rv_valmode = sparp_expn_native_valmode (sparp, rv);
  if (SSG_VALMODE_SQLVAL == rv_valmode)
    return 0;
  if (SSG_VALMODE_LONG == rv_valmode)
    {
      ptrlong rv_restr = sparp_restr_bits_of_expn (sparp, rv);
      if (rv_restr & (SPART_VARR_IS_REF | SPART_VARR_LONG_EQ_SQL))
        return 0;
      return 1;
    }
  if (IS_BOX_POINTER(rv_valmode))
    {
      ptrlong rv_restr;
      if (!rv_valmode->qmfWrapDistinct)
        return 0;
      rv_restr = sparp_restr_bits_of_expn (sparp, rv);
      if (rv_restr & (SPART_VARR_IS_REF | SPART_VARR_LONG_EQ_SQL))
        return 0;
      return 1;
    }
  return 0;
}

int
sparp_some_retvals_should_wrap_distinct (sparp_t *sparp, SPART *tree)
{
  int ctr;
  SPART **retvals = tree->_.req_top.retvals;
#ifndef NDEBUG
  if (DISTINCT_L != tree->_.req_top.subtype)
    spar_internal_error (sparp, "sparp_" "some_retvals_should_wrap_distinct() for non-DISTINCT");
#endif
  DO_BOX_FAST(SPART *, rv, ctr, retvals)
    {
      if (sparp_retval_should_wrap_distinct (sparp, tree, rv))
        return 1;
    }
  END_DO_BOX_FAST;
  return 0;
}

int
sparp_gp_trav_list_external_vars_gp_in (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  if ((SPAR_GP == SPART_TYPE (curr)) && (SELECT_L == curr->_.gp.subtype))
    {
      sparp_gp_trav_suspend (sparp);
      sparp_list_external_vars (sparp, curr->_.gp.subquery, common_env);
      sparp_gp_trav_resume (sparp);
    }
  return 0;
}

int
sparp_gp_trav_list_external_vars_expn_in (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  if (SPAR_IS_BLANK_OR_VAR (curr) && (curr->_.var.rvr.rvrRestrictions & (SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL)))
    t_set_push_new_string (common_env, curr->_.var.vname);
  return 0;
}

int
sparp_gp_trav_list_external_vars_expn_subq (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  sparp_gp_trav_suspend (sparp);
  sparp_list_external_vars (sparp, curr->_.gp.subquery, common_env);
  sparp_gp_trav_resume (sparp);
  return 0;
}

void
sparp_list_external_vars (sparp_t *sparp, SPART *tree, dk_set_t *set_ret)
{
  SPART *top, *top_pattern;
  if (SPAR_REQ_TOP == SPART_TYPE (tree))
    {
      top = tree;
      top_pattern = top->_.req_top.pattern;
    }
  else
    {
      top = NULL;
      top_pattern = tree;
    }
  if (NULL != top)
    sparp_trav_out_clauses (sparp, top, set_ret,
      NULL, NULL,
      sparp_gp_trav_list_external_vars_expn_in, NULL, sparp_gp_trav_list_external_vars_expn_subq,
      NULL );
  sparp_gp_trav (sparp, NULL /* unused */, top_pattern, set_ret,
    sparp_gp_trav_list_external_vars_gp_in, NULL,
    sparp_gp_trav_list_external_vars_expn_in, NULL, sparp_gp_trav_list_external_vars_expn_subq,
    NULL );
}

void
sparp_fill_sinv_varlists (sparp_t *sparp, SPART *root)
{
  int equiv_ctr, equiv_count = sparp->sparp_sg->sg_equiv_count;
  dk_set_t all_sinvs = NULL;
  for (equiv_ctr = equiv_count; equiv_ctr--; /* no step */)
    {
      sparp_equiv_t *eq = sparp->sparp_sg->sg_equivs[equiv_ctr];
      SPART *gp;
      if ((NULL == eq) || !SPARP_EQ_IS_USED(eq))
        continue;
      gp = eq->e_gp;
      if (SERVICE_L == gp->_.gp.subtype)
        t_set_pushnew (&all_sinvs, gp);
    }
  DO_SET (SPART *, gp, &(all_sinvs))
    {
      SPART *sinv = sparp_get_option (sparp, gp->_.gp.options, SPAR_SERVICE_INV);
      int varctr, eqctr;
      caddr_t **param_varnames_ptr = &(sinv->_.sinv.param_varnames);
      dk_set_t used_globals = NULL;
      dk_set_t new_used_globals_as_params = NULL;
      dk_set_t rset_varnames = NULL;
      sparp_list_external_vars (sparp, gp, &used_globals);
      /* Check if all IN variables are adequate (or adequate but disconnected by the optimizer for a good reason).
         Disconnected non-externals are silently removed from the IN list. */
      DO_BOX_FAST_REV (caddr_t, param_var_name, varctr, param_varnames_ptr[0])
        { /* The loop direction is important due to possible removals */
          sparp_equiv_t *param_xfer_equiv = sparp_equiv_get (sparp, gp, (SPART *)param_var_name, SPARP_EQUIV_GET_NAMESAKES);
          if ((NULL == param_xfer_equiv) || (0 == BOX_ELEMENTS_0 (param_xfer_equiv->e_receiver_idxs)))
            {
              if ((NULL != param_xfer_equiv) &&
                ((SPART_VARR_FIXED | SPART_VARR_ALWAYS_NULL | SPART_VARR_CONFLICT) & param_xfer_equiv->e_rvr.rvrRestrictions) )
                {
                  if (!((SPART_VARR_EXTERNAL | SPART_VARR_GLOBAL) & param_xfer_equiv->e_rvr.rvrRestrictions))
                    param_varnames_ptr[0] = t_list_remove_nth ((caddr_t)(param_varnames_ptr[0]), varctr);
                  continue;
                }
              if (0 > dk_set_position_of_string (used_globals, param_var_name))
                {
                  if (!sinv->_.sinv.in_list_implicit)
                    spar_error (sparp, "%.300s declares IN ?%.200s variable but an IN variable should be used both inside and outside the SERVICE clause",
                      spar_sinv_naming (sparp, sinv), param_var_name );
                  param_varnames_ptr[0] = t_list_remove_nth ((caddr_t)(param_varnames_ptr[0]), varctr);
                }
            }
        }
      END_DO_BOX_FAST_REV;
      /* Now we try to extend list of IN vars with externals. Used externals are always passed, even if fixed, because the service can be the only place in the query where equality between external and fixed value is tested */
      DO_SET (caddr_t, globname, &used_globals)
        {
          int found = 0;
          DO_BOX_FAST_REV (caddr_t, param_var_name, varctr, sinv->_.sinv.param_varnames)
            {
              if (strcmp (param_var_name, globname))
                continue;
              found = 1;
              break;
            }
          END_DO_BOX_FAST_REV;
          if (!found)
            t_set_push (&new_used_globals_as_params, globname);
        }
      END_DO_SET()
      if (NULL != new_used_globals_as_params)
        sinv->_.sinv.param_varnames = t_list_concat ((caddr_t)(sinv->_.sinv.param_varnames), (caddr_t)t_revlist_to_array (new_used_globals_as_params));
      /* Finally what's not in extended list of param vars but in equivs of the SERVICE gp and has relations to the parent should become retvals */
      SPARP_FOREACH_GP_EQUIV (sparp, gp, eqctr, eq)
        {
          int eq_varname_ctr;
          caddr_t specimen_varname = NULL;
          if (0 == BOX_ELEMENTS_0 (eq->e_receiver_idxs))
            continue; /* The eq is used only internally, no need to return values */
          DO_BOX_FAST_REV (caddr_t, eq_var_name, eq_varname_ctr, eq->e_varnames)
            {
              DO_BOX_FAST_REV (caddr_t, param_var_name, varctr, sinv->_.sinv.param_varnames)
                {
                  if (!strcmp (param_var_name, eq_var_name))
                    goto name_from_eq_is_found_in_params; /* see below */
                }
              END_DO_BOX_FAST_REV;
              if (SPART_VARNAME_IS_GLOB (eq_var_name))
                continue;
              if (SPART_VARNAME_IS_SPECIAL (eq_var_name))
                continue;
              if (SPART_VARNAME_IS_BNODE (eq_var_name))
                continue;
              specimen_varname = eq_var_name;
            }
          END_DO_BOX_FAST_REV;
          if (NULL != specimen_varname)
            t_set_push (&rset_varnames, specimen_varname);
name_from_eq_is_found_in_params: ;
        }
      END_SPARP_FOREACH_GP_EQUIV;
      sinv->_.sinv.rset_varnames = t_list_to_array (rset_varnames);
    }
  END_DO_SET()
}

void
sparp_tweak_order_of_iter (sparp_t *sparp, SPART *req_top, SPART **obys)
{
  int oby_ctr;
  DO_BOX_FAST (SPART *, oby, oby_ctr, obys)
    {
      caddr_t lit_val;
      int col_idx;
      SPART *tree, *tree_copy;
      if (SPAR_LIT != SPART_TYPE (oby->_.oby.expn))
        continue;
      lit_val = SPAR_LIT_VAL (oby->_.oby.expn);
      if (DV_LONG_INT != DV_TYPE_OF (lit_val))
        continue;
      col_idx = unbox (lit_val);
      if ((0 >= col_idx) && (col_idx > BOX_ELEMENTS (req_top->_.req_top./*orig_*/retvals)))
        continue;
      tree = req_top->_.req_top./*orig_*/retvals [col_idx-1];
      while (SPAR_ALIAS == SPART_TYPE (tree))
        tree = tree->_.alias.arg;
      tree_copy = sparp_tree_full_copy (sparp, tree, req_top->_.req_top.pattern);
      oby->_.oby.expn = tree_copy;
    }
  END_DO_BOX_FAST;
}

int
sparp_gp_trav_rewrite_qm_postopt (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  if ((SPAR_GP != SPART_TYPE (curr)) || (SELECT_L != curr->_.gp.subtype))
    return 0;
  sparp_gp_trav_suspend (sparp);
  sparp_rewrite_qm_postopt (sparp, curr->_.gp.subquery);
  sparp_gp_trav_resume (sparp);
  return 0;
}

int
sparp_req_top_has_limofs (SPART *tree)
{
  if (SPAR_REQ_TOP != SPART_TYPE (tree))
    return 0;
  if ((DV_LONG_INT == DV_TYPE_OF (tree->_.req_top.limit)) && (DV_LONG_INT == DV_TYPE_OF (tree->_.req_top.offset)))
    {
      /*long lim = unbox ((caddr_t)(tree->_.req_top.limit));*/
      long ofs = unbox ((caddr_t)(tree->_.req_top.offset));
      if ((NULL == tree->_.req_top.limit) && (0 == ofs))
        return 0;
      return 1;
    }
  return 2;
}

SPART *
sparp_limit_for_cutting_inner_limits (sparp_t *sparp, SPART *lim, SPART *ofs)
{
  if (NULL == lim)
    return NULL;
  if (NULL == ofs)
    return lim;
  if ((DV_LONG_INT == DV_TYPE_OF (lim)) && (DV_LONG_INT == DV_TYPE_OF (ofs)))
    return (SPART *)t_box_num_nonull (unbox ((caddr_t)lim) + ((0 < unbox ((caddr_t)ofs)) ? unbox ((caddr_t)ofs) : 0));
  return spartlist (sparp, 3, BOP_PLUS, lim,
      spar_make_funcall (sparp, 0, "bif:__max_notnull", (SPART **)t_list (2, ofs, t_box_num_nonull (0))) );
}

SPART *
sparp_cut_inner_limit_with_outer_limit (sparp_t *sparp, SPART *inner_limit, SPART *inner_offset, SPART *outer_limit)
{
  if (NULL == outer_limit)
    return inner_limit;
  if ((DV_LONG_INT == DV_TYPE_OF (outer_limit)) && (DV_LONG_INT == DV_TYPE_OF (inner_offset)) && (DV_LONG_INT == DV_TYPE_OF (inner_limit)))
    {
      boxint val = unbox ((caddr_t)outer_limit) + unbox ((caddr_t)inner_offset);
      return (unbox ((caddr_t)inner_limit) < val) ? inner_limit : (SPART *)t_box_num_nonull (val);
    }
  return spar_make_funcall (sparp, 0, "bif:__min_notnull", (SPART **)t_list (3,
      inner_limit,
      spartlist (sparp, 3, BOP_PLUS, outer_limit,
        spar_make_funcall (sparp, 0, "bif:__max_notnull", (SPART **)t_list (2, inner_offset, t_box_num_nonull (0))) ),
      t_box_num_nonull (0) ) );
}

void
spar_propagate_limit_as_option (sparp_t *sparp, SPART *tree, SPART *outer_limit)
{
  switch (SPART_TYPE (tree))
    {
    case SPAR_REQ_TOP:
      if (0 != BOX_ELEMENTS_0 (tree->_.req_top.order))
        return;
      tree->_.req_top.limit = sparp_cut_inner_limit_with_outer_limit (sparp, tree->_.req_top.limit, tree->_.req_top.offset, outer_limit);
      if ((NULL != tree->_.req_top.limit) && (DISTINCT_L != tree->_.req_top.subtype) && (NULL == tree->_.req_top.groupings) && (NULL == tree->_.req_top.having))
        spar_propagate_limit_as_option (sparp, tree->_.req_top.pattern,
          sparp_limit_for_cutting_inner_limits (sparp, tree->_.req_top.limit, tree->_.req_top.offset) );
      return;
    case SPAR_GP:
      {
        int eq_ctr;
        if (NULL != tree->_.gp.options)
          {
            SPART *lim = sparp_get_option (sparp, tree->_.gp.options, LIMIT_L);
            if (NULL != lim)
              {
                outer_limit = sparp_cut_inner_limit_with_outer_limit (sparp, lim, NULL, outer_limit);
                if (NULL != outer_limit)
                  sparp_set_option (sparp, &(tree->_.gp.options), LIMIT_L, outer_limit, SPARP_SET_OPTION_REPLACING);
              }
          }
        if (NULL == outer_limit)
          return;
        if (0 != BOX_ELEMENTS_0 (tree->_.gp.filters))
          return;
        SPARP_FOREACH_GP_EQUIV (sparp, tree, eq_ctr, eq)
          {
            if (eq->e_replaces_filter) return;
          }
        END_SPARP_FOREACH_GP_EQUIV;
        switch (tree->_.gp.subtype)
          {
          case SELECT_L:
            spar_propagate_limit_as_option (sparp, tree->_.gp.subquery, outer_limit);
            return;
          case VALUES_L:
            if (DV_LONG_INT == DV_TYPE_OF (outer_limit))
              {
                boxint olimit_val = unbox ((caddr_t)outer_limit);
                SPART *subbinv = tree->_.gp.subquery;
                boxint rows_in_use = subbinv->_.binv.rows_in_use;
                if (olimit_val < rows_in_use)
                  {
                    int rowcount = BOX_ELEMENTS (subbinv->_.binv.data_rows);
                    int rowctr;
                    for (rowctr = rowcount; rowctr--; /* no step */)
                      {
                        if ('/' != subbinv->_.binv.data_rows_mask[rowctr])
                          continue;
                        spar_invalidate_binv_dataset_row (sparp, subbinv, rowctr, -2);
                        if (olimit_val >= --rows_in_use)
                          break;
                      }
                  }
              }
            return;
          case UNION_L: case SPAR_UNION_WO_ALL:
            {
              int memb_ctr;
              DO_BOX_FAST (SPART *, memb, memb_ctr, tree->_.gp.members)
                {
                  spar_propagate_limit_as_option (sparp, memb, outer_limit);
                }
              END_DO_BOX_FAST;
              if (NULL != outer_limit)
                sparp_set_option (sparp, &(tree->_.gp.options), LIMIT_L, outer_limit, SPARP_SET_OPTION_REPLACING);
              return;
            }
          case SERVICE_L:
            if (NULL != outer_limit)
              sparp_set_option (sparp, &(tree->_.gp.options), LIMIT_L, outer_limit, SPARP_SET_OPTION_REPLACING);
            if (DV_LONG_INT != DV_TYPE_OF (outer_limit))
              return;
            /* no break */
          case 0: case WHERE_L:
            {
              int memb_ctr, memb_count = BOX_ELEMENTS_0 (tree->_.gp.members);
              int nonoptional_ctr = 0;
              if (0 == memb_count)
                return;
              for (memb_ctr = 0; memb_ctr < memb_count; memb_ctr++)
                {
                  SPART *memb = tree->_.gp.members[memb_ctr];
                  if ((SPAR_GP != SPART_TYPE (memb)) || (OPTIONAL_L != memb->_.gp.subtype))
                    nonoptional_ctr++;
                }
              if (1 == nonoptional_ctr)
                {
                  for (memb_ctr = 0; memb_ctr < memb_count; memb_ctr++)
                    {
                      SPART *memb = tree->_.gp.members[memb_ctr];
                      spar_propagate_limit_as_option (sparp, memb, outer_limit);
                    }
                }
              if ((0 == tree->_.gp.subtype) && (NULL != outer_limit))
                sparp_set_option (sparp, &(tree->_.gp.options), LIMIT_L, outer_limit, SPARP_SET_OPTION_REPLACING);
              return;
            }
          }
        return;
      }
    case SPAR_TRIPLE:
      {
        if (NULL == outer_limit)
          return;
        sparp_set_option (sparp, &(tree->_.triple.options), LIMIT_L, outer_limit, SPARP_SET_OPTION_REPLACING);
        return;
      }
    }
}

void
sparp_rewrite_qm_postopt (sparp_t *sparp, SPART *req_top)
{
  sparp_equiv_t **equivs;
  int equiv_ctr, equiv_count;
  int retval_ctr;
  dk_set_t optionals_to_reduce;
  sparp_gp_trav_cbk_t *security_cbk;
  if (SPAR_CODEGEN == SPART_TYPE (req_top))
    GPF_T1 ("sparp_" "rewrite_qm_postopt () for CODEGEN");
  if (SPAR_QM_SQL_FUNCALL == SPART_TYPE (req_top))
    GPF_T1 ("sparp_" "rewrite_qm_postopt () for SQL_FUNCALL");
  sparp_wpar_retvars_in_max (sparp, req_top);

retry_after_reducing_optionals:
  optionals_to_reduce = NULL;
  sparp_gp_trav_top_pattern (sparp, req_top, &optionals_to_reduce,
    sparp_gp_trav_rewrite_qm_postopt, sparp_gp_trav_flatten_and_reuse_tabids,
    NULL, NULL, sparp_gp_trav_rewrite_qm_postopt,
    NULL );
  while (NULL != optionals_to_reduce)
    {
      SPART *opt = t_set_pop (&optionals_to_reduce);
      if (sparp_reduce_trivial_optional (sparp, opt))
        {
          sparp_rewrite_qm_optloop (sparp, req_top, 1);
          goto retry_after_reducing_optionals; /* see above */
        }
    }
  sparp_remove_redundant_connections (sparp, req_top, SPARP_UNLINK_IF_ASSIGNED_EXTERNALLY);
  sparp_audit_mem (sparp);
  sparp_trav_out_clauses (sparp, req_top, NULL,
    NULL, NULL,
    NULL, NULL, sparp_gp_trav_rewrite_qm_postopt,
    NULL );
  security_cbk = ((spar_graph_static_perms (sparp, NULL, RDF_GRAPH_PERM_READ) & RDF_GRAPH_PERM_READ) ? NULL :
    sparp_gp_trav_add_graph_perm_read_filters );
  sparp_gp_trav_top_pattern (sparp, req_top, NULL,
    sparp_gp_trav_restore_filters_for_weird_subq, security_cbk,
    NULL, NULL, NULL,
    NULL );
/* Final processing: */
  switch (req_top->_.req_top.subtype)
    {
    case DELETE_L:
      if (spar_optimize_delete_of_single_triple_pattern (sparp, req_top))
        break; /* If optimized then there's nothing more to optimize. */
      /* no break here */
    case INSERT_L:
      spar_optimize_retvals_of_insert_or_delete (sparp, req_top);
      break;
    case MODIFY_L:
      spar_optimize_retvals_of_modify (sparp, req_top);
      break;
    }
  spar_propagate_limit_as_option (sparp, req_top, NULL);
  if (NULL != sparp->sparp_suspended_stps)
    goto end_of_equiv_checks; /* see below */
  equivs = sparp->sparp_sg->sg_equivs;
  equiv_count = sparp->sparp_sg->sg_equiv_count;
  for (equiv_ctr = equiv_count; equiv_ctr--; /* no step */)
    {
      sparp_equiv_t *eq = equivs[equiv_ctr];
      if (NULL == eq)
        continue;
      if (eq->e_deprecated)
        continue;
      if (!SPARP_EQ_IS_ASSIGNED_LOCALLY(eq) &&
        ((0 != eq->e_const_reads) || (0 != eq->e_replaces_filter) || /* note: no check for (0 != eq->e_optional_reads) */
          (0 != BOX_ELEMENTS_0 (eq->e_receiver_idxs)) ) &&
        !(eq->e_rvr.rvrRestrictions & (SPART_VARR_FIXED | SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL)) )
        {
          if ((1 == eq->e_var_count) && SPART_VARNAME_IS_SPECIAL (eq->e_varnames[0]))
            continue; /* Special variable can not be bound in SPARQL because they does not exist in SPARQL. Thus no restricitons can be ifrerred from SPARQL context. */
          if (!sparp->sparp_sg->sg_signal_void_variables)
            {
              SPARP_DEBUG_WEIRD(sparp,"conflict");
              eq->e_rvr.rvrRestrictions |= SPART_VARR_CONFLICT;
            }
          else if (eq->e_rvr.rvrRestrictions & SPART_VARR_EXPORTED)
            spar_error (sparp, "Variable '%.100s' can not be bound due to mutually exclusive restrictions on its value", eq->e_varnames[0]);
          else
            spar_error (sparp, "Variable '%.100s' is used in subexpressions of the query but can not be assigned", eq->e_varnames[0]);
        }
#ifdef DEBUG
      equivs[equiv_ctr]->e_dbg_saved_gp = (SPART **)t_box_num ((ptrlong)(equivs[equiv_ctr]->e_gp));
#endif
/*
      equivs[equiv_ctr]->e_gp = NULL;
*/
    }

end_of_equiv_checks:
  DO_BOX_FAST (SPART *, retval, retval_ctr, req_top->_.req_top.retvals)
    {
      caddr_t name;
      int retval_type = SPART_TYPE (retval);
      if (SPAR_VARIABLE == retval_type)
        name = retval->_.var.vname;
      else if (SPAR_ALIAS == retval_type)
        name = retval->_.alias.aname;
      else
        continue;
      if (!strchr (name, '>'))
        continue;
      DO_SET (spar_propvariable_t *, pv, &(sparp->sparp_propvars))
        {
          const char *optext;
          if (strcmp (pv->sparpv_obj_var_name, name))
            continue;
          optext = ((_PLUS_GT == pv->sparpv_op) ? "+>" : "*>");
          if (pv->sparpv_obj_altered)
            spar_error (sparp, "The name of a result-set column for variable ?%.200s %s %s?%.200s%s %s; please specify some alias.",
              pv->sparpv_subj_var->_.var.vname, optext,
              ((Q_IRI_REF == pv->sparpv_verb_lexem_type) ? "<" : ""), pv->sparpv_verb_lexem_text,
              ((Q_IRI_REF == pv->sparpv_verb_lexem_type) ? ">" : ""),
              ((pv->sparpv_obj_altered & 0x2) ? "may cause subtle coding errors" : "is too long") );
          break;
        }
      END_DO_SET();
    }
  END_DO_BOX_FAST;
  if ((NULL == sparp->sparp_suspended_stps) && sparp->sparp_query_uses_sinvs)
    sparp_fill_sinv_varlists (sparp, req_top); /* This is global so can (and should) be made only at top level */
}

SPART *
sparp_rewrite_grab (sparp_t *sparp, SPART *req_top)
{
  SPART *rewritten_req_top;
  sparp_env_t *env = sparp->sparp_env;
  rdf_grab_config_t *rgc = &(env->spare_src.ssrc_grab);
  sparp_t *sparp_of_seed;	/* This will compile the statement that will collect the first set of graphs */
  sparp_t *sparp_of_iter;	/* This will compile the statement that will called while the set of graphs growth */
  sparp_t *sparp_of_final;	/* This will compile the statement that will produce the final result set */
  sparp_t *sub_sparps[3];
  caddr_t sql_texts[3];
  SPART **grab_retvals;
  SPART *ret_limit_expn;
  ptrlong top_subtype;
  dk_set_t new_vars = NULL;
  dk_set_t sa_graphs = NULL;
  dk_set_t grab_params = NULL;
  sql_comp_t sc;
  int sub_sparp_ctr;
  ptrlong rgc_flags = 0;
  int use_plain_return;
  top_subtype = req_top->_.req_top.subtype;
  use_plain_return = (((CONSTRUCT_L == top_subtype) || (DESCRIBE_L == top_subtype)) ? 1 : 0);
  DO_SET (caddr_t, grab_name, &(rgc->rgc_vars))
    {
      t_set_push (&new_vars, spar_make_variable (sparp, grab_name));
    }
  END_DO_SET()
  if (NULL != rgc->rgc_destination)
    t_set_push (&sa_graphs, spar_make_qm_sql (sparp, "iri_to_id", (SPART **)t_list (1, rgc->rgc_destination), NULL));
  if (NULL != rgc->rgc_group_destination)
    t_set_push (&sa_graphs, spar_make_qm_sql (sparp, "iri_to_id", (SPART **)t_list (1, rgc->rgc_group_destination), NULL));
  if (NULL != new_vars)
    grab_retvals = (SPART **)t_revlist_to_array (new_vars);
  else
    grab_retvals = sparp_treelist_full_copy (sparp, req_top->_.req_top.expanded_orig_retvals, NULL);
/* Making subqueries: seed */
  sub_sparps[0] = sparp_of_seed = sparp_clone_for_variant (sparp);
  sparp_of_seed->sparp_entire_query = sparp_tree_full_copy (sparp_of_seed, req_top, NULL);
  sparp_of_seed->sparp_entire_query->_.req_top.shared_spare_box = t_box_num ((ptrlong)(sparp_of_seed->sparp_env));
  sparp_of_seed->sparp_entire_query->_.req_top.subtype = SELECT_L;
  sparp_of_seed->sparp_entire_query->_.req_top.retvals = grab_retvals;
  sparp_of_seed->sparp_entire_query->_.req_top.retvalmode_name = t_box_string ("LONG");
  sparp_of_seed->sparp_entire_query->_.req_top.limit = NULL;
  sparp_of_seed->sparp_entire_query->_.req_top.offset = 0;
  sparp_of_seed->sparp_env->spare_disable_output_formatting = 1;
  sparp_of_seed->sparp_globals_mode = SPARE_GLOBALS_ARE_COLONUMBERED;
  sparp_of_seed->sparp_global_num_offset = 1;
  sparp_of_seed->sparp_env->spare_src.ssrc_grab.rgc_sa_graphs = env->spare_src.ssrc_grab.rgc_sa_graphs;
  sparp_of_seed->sparp_env->spare_src.ssrc_grab.rgc_sa_preds = env->spare_src.ssrc_grab.rgc_sa_preds;
  sparp_of_seed->sparp_env->spare_src.ssrc_grab.rgc_sa_vars = env->spare_src.ssrc_grab.rgc_sa_vars;
  sparp_of_seed->sparp_env->spare_src.ssrc_grab.rgc_vars = env->spare_src.ssrc_grab.rgc_vars;
/* Making subqueries: iter */
  sub_sparps[1] = sparp_of_iter = sparp_clone_for_variant (sparp_of_seed);
  sparp_of_iter->sparp_entire_query = sparp_tree_full_copy (sparp_of_seed, sparp_of_seed->sparp_entire_query, NULL);
  sparp_of_iter->sparp_entire_query->_.req_top.shared_spare_box = t_box_num ((ptrlong)(sparp_of_iter->sparp_env));
  if (NULL != sparp_of_iter->sparp_entire_query->_.req_top.order)
    sparp_tweak_order_of_iter (sparp_of_iter, sparp_of_iter->sparp_entire_query, sparp_of_iter->sparp_entire_query->_.req_top.order);
  sparp_of_iter->sparp_env->spare_disable_output_formatting = 1;
  sparp_of_iter->sparp_globals_mode = SPARE_GLOBALS_ARE_COLONUMBERED;
  sparp_of_iter->sparp_global_num_offset = 1;
  sparp_of_iter->sparp_env->spare_src.ssrc_grab.rgc_sa_graphs = env->spare_src.ssrc_grab.rgc_sa_graphs;
  sparp_of_iter->sparp_env->spare_src.ssrc_grab.rgc_sa_preds = env->spare_src.ssrc_grab.rgc_sa_preds;
  sparp_of_iter->sparp_env->spare_src.ssrc_grab.rgc_sa_vars = env->spare_src.ssrc_grab.rgc_sa_vars;
  sparp_of_iter->sparp_env->spare_src.ssrc_grab.rgc_vars = env->spare_src.ssrc_grab.rgc_vars;
/* Only after making the iter subquery from the seed one, seed may loose its ORDER BY */
  sparp_of_seed->sparp_entire_query->_.req_top.order = NULL;
/*!!! TBD: relax graph conditions in sparp_of_iter */
/* Making subqueries: final */
  sub_sparps[2] = sparp_of_final = sparp_clone_for_variant (sparp);
  sparp_of_final->sparp_entire_query = sparp_tree_full_copy (sparp_of_seed, req_top, NULL);
  sparp_of_final->sparp_entire_query->_.req_top.shared_spare_box = t_box_num ((ptrlong)(sparp_of_final->sparp_env));
  sparp_of_final->sparp_env->spare_disable_output_formatting = 1;
  sparp_of_final->sparp_globals_mode = SPARE_GLOBALS_ARE_COLONUMBERED;
  sparp_of_final->sparp_global_num_offset = 0;
/*!!! TBD: relax graph conditions in sparp_of_final */
  for (sub_sparp_ctr = 3; sub_sparp_ctr--; /* no step */)
    {
      spar_sqlgen_t ssg;
      sparp_t *sub_sparp = sub_sparps [sub_sparp_ctr];
      sub_sparp->sparp_entire_query = sparp_rewrite_qm (sub_sparp, sub_sparp->sparp_entire_query);
      memset (&ssg, 0, sizeof (spar_sqlgen_t));
      memset (&sc, 0, sizeof (sql_comp_t));
      sc.sc_client = sub_sparp->sparp_sparqre->sparqre_cli;
      ssg.ssg_out = strses_allocate ();
      ssg.ssg_sc = &sc;
      ssg.ssg_sparp = sub_sparp;
      ssg.ssg_tree = sub_sparp->sparp_entire_query;
      ssg.ssg_sources = ssg.ssg_tree->_.req_top.sources; /*!!!TBD merge with environment */
      ssg.ssg_seealso_enabled = (sub_sparp_ctr < 2) ? 1 : 0;
      ssg_make_sql_query_text (&ssg, 0);
      ssg.ssg_seealso_enabled = 0;
      sql_texts [sub_sparp_ctr] = t_strses_string (ssg.ssg_out);
      ssg_free_internals (&ssg);
    }
  if (rgc->rgc_intermediate)
    rgc_flags |= 0x0001;
#define PUSH_GRAB_PARAM(n,v) do { t_set_push (&grab_params, t_box_dv_short_string ((n))); t_set_push (&grab_params, (v)); } while (0)
  if (NULL != sa_graphs)
    PUSH_GRAB_PARAM ("sa_graphs", spar_make_vector_qm_sql (sparp, (SPART **)(t_revlist_to_array (sa_graphs))));
  if (NULL != rgc->rgc_sa_preds)
    PUSH_GRAB_PARAM ("sa_preds", spar_make_vector_qm_sql (sparp, (SPART **)(t_revlist_to_array (rgc->rgc_sa_preds))));
  if (NULL != rgc->rgc_limit)
    PUSH_GRAB_PARAM ("doc_limit", t_box_copy (rgc->rgc_limit));
  PUSH_GRAB_PARAM ("base_iri", t_box_copy (rgc->rgc_base));
  PUSH_GRAB_PARAM ("get:destination", t_box_copy (rgc->rgc_destination)); /* NULL should be passed because presense of NULL and absence of value may have different meaning */
  if (NULL != rgc->rgc_group_destination)
    PUSH_GRAB_PARAM ("get:group-destination", t_box_copy (rgc->rgc_group_destination));
  if (NULL != rgc->rgc_resolver_name)
    PUSH_GRAB_PARAM ("resolver", t_box_copy (rgc->rgc_resolver_name));
  if (NULL != rgc->rgc_loader_name)
    PUSH_GRAB_PARAM ("loader", t_box_copy (rgc->rgc_loader_name));
  PUSH_GRAB_PARAM ("refresh_free_text", /* no copy here, pass by ref */ sparp->sparp_env->spare_sql_refresh_free_text);
  PUSH_GRAB_PARAM ("flags", t_box_num_nonull (rgc_flags));
  DO_KEYWORD_SET (optname, SPART *, optvalue, &(sparp->sparp_env->spare_src.ssrc_common_sponge_options))
    {
      if (!strcmp (optname, "get:uri"))
        continue;
      PUSH_GRAB_PARAM (optname, sparp_tree_full_copy (sparp, optvalue, NULL));
    } END_DO_SET()
  ret_limit_expn = req_top->_.req_top.limit;
  ret_limit_expn = ((NULL == ret_limit_expn) ? (SPART *)t_NEW_DB_NULL : sparp_tree_full_copy (sparp, ret_limit_expn, NULL));
  rewritten_req_top = spartlist (sparp, 21, SPAR_CODEGEN,					/* #0 */
    t_box_num ((ptrlong)(ssg_grabber_codegen)),							/* #1 */
    sparp_treelist_full_copy (sparp, sparp->sparp_entire_query->_.req_top.retvals, NULL),		/* #2 */
    t_box_dv_short_string ("sql:RDF_GRAB"),							/* #3 */
    spar_make_vector_qm_sql (sparp, (SPART **)(t_revlist_to_array (grab_params))),		/* #4 */
    sql_texts[0], sql_texts[1], sql_texts[2],							/* #5-#7 */
    ret_limit_expn,										/* #8 */
    ((NULL == rgc->rgc_consts) ? NULL :
      spar_make_vector_qm_sql (sparp, (SPART **)(t_revlist_to_array (rgc->rgc_consts))) ),	/* #9 */
    t_box_copy (rgc->rgc_depth),									/* #10 */
    (ptrlong)use_plain_return );								/* #11 */
    /* Note that the uid is not in the list of codegen arguments! */
  return rewritten_req_top;
}

void
ssg_grabber_codegen (struct spar_sqlgen_s *ssg, struct spar_tree_s *spart, ...)
{
  int argctr = 0;
/* The order of declarations is important: side effect on init */
  SPART **retvals		= (SPART **)(spart->_.codegen.args [argctr++]);	/* #2 */
  caddr_t procedure_name	= (caddr_t)(spart->_.codegen.args [argctr++]);	/* #3 */
  caddr_t grab_prms_vector_expn	= (caddr_t)(spart->_.codegen.args [argctr++]);	/* #4 */
  caddr_t seed_sql_text		= (caddr_t)(spart->_.codegen.args [argctr++]);	/* #5 */
  caddr_t iter_sql_text		= (caddr_t)(spart->_.codegen.args [argctr++]);	/* #6 */
  caddr_t final_sql_text	= (caddr_t)(spart->_.codegen.args [argctr++]);	/* #7 */
  caddr_t ret_limit		= (caddr_t)(spart->_.codegen.args [argctr++]);	/* #8 */
  SPART *const_vector_expn	= (SPART *)(spart->_.codegen.args [argctr++]);	/* #9 */
  caddr_t depth			= (caddr_t)(spart->_.codegen.args [argctr++]);	/* #10 */
  int use_plain_return		= (ptrlong)(spart->_.codegen.args [argctr++]);	/* #11 */
  int varctr, varcount = BOX_ELEMENTS (retvals);
  int need_comma;
  caddr_t call_alias = t_box_sprintf (0x100, "grabber-t%d", ssg->ssg_sparp->sparp_key_gen);
  ssg->ssg_sparp->sparp_key_gen += 1;
  if (NULL == const_vector_expn)
    const_vector_expn = (SPART *)t_NEW_DB_NULL;
  if (NULL == depth)
    depth = (caddr_t)1L;
  if (use_plain_return)
    {
      ssg_puts ("SELECT TOP 1 ");
      ssg_prin_function_name (ssg, procedure_name);
      ssg_puts (" (");
      ssg->ssg_indent += 1;
    }
  else
    {
      ssg_puts ("SELECT ");
      if (0 == varcount) ssg_puts ("TOP 1 1 as __ask_retval "); /* IvAn/Bug12961/071109 Added special case for ASK */
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
      ssg_puts (" (_grabber_app_params, _grabber_params, _grabber_seed, _grabber_iter, _grabber_final, _grabber_ret_limit, _grabber_consts, _grabber_depth, _plain_ret, _uid) (rset any) ");
      ssg_prin_id (ssg, call_alias);
      ssg_newline (0);
      ssg_puts ("WHERE _grabber_app_params = ");
    }
  need_comma = 0;
  ssg_puts ("vector (");
  DO_SET (caddr_t, vname, &(ssg->ssg_sparp->sparp_env->spare_global_var_names))
    {
      if ('@' == vname[1])
        continue;
      if (need_comma)
        ssg_puts (", ");
      else
        need_comma = 1;
      ssg_print_global_param_name (ssg, vname);
    }
  END_DO_SET ();
  ssg_puts (")");
#define PROC_PARAM_EQ_SPART(txt,var) do { \
    if (use_plain_return) \
      { \
        ssg_puts (", "); \
        ssg_newline (0); \
      } \
    else \
      { \
        ssg_newline (0); \
        ssg_puts (" AND "); \
        ssg_puts (txt); \
        ssg_puts (" = "); \
      } \
    ssg_print_scalar_expn (ssg, (SPART *)(var), SSG_VALMODE_SQLVAL, NULL_ASNAME); \
    } while (0)
  PROC_PARAM_EQ_SPART ("_grabber_params", grab_prms_vector_expn);
  PROC_PARAM_EQ_SPART ("_grabber_seed", seed_sql_text);
  PROC_PARAM_EQ_SPART ("_grabber_iter", iter_sql_text);
  PROC_PARAM_EQ_SPART ("_grabber_final", final_sql_text);
  PROC_PARAM_EQ_SPART ("_grabber_ret_limit", ret_limit);
  PROC_PARAM_EQ_SPART ("_grabber_consts", const_vector_expn);
  PROC_PARAM_EQ_SPART ("_grabber_depth", depth);
  PROC_PARAM_EQ_SPART ("_plain_ret", ((ptrlong) use_plain_return));
  PROC_PARAM_EQ_SPART ("_uid", spar_exec_uid_and_gs_cbk (ssg->ssg_sparp)); /* uid is not in the list of passed arguments! */
#undef PROC_PARAM_EQ_SPART
  if (use_plain_return)
    {
      ssg_putchar (')');
      ssg->ssg_indent -= 1;
      ssg_newline (0);
      ssg_puts ("FROM DB.DBA.RDF_QUAD ");
      ssg_prin_id (ssg, call_alias);
    }
}

void
ssg_select_known_graphs_codegen (struct spar_sqlgen_s *ssg, struct spar_tree_s *spart, ...)
{
  int argctr = 0;
/* The order of declarations is important: side effect on init */
  caddr_t valmode_name		= (caddr_t)(spart->_.codegen.args [argctr++]);	/* #2 */
  caddr_t formatmode_name	= (caddr_t)(spart->_.codegen.args [argctr++]);	/* #3 */
  caddr_t retname		= (caddr_t)(spart->_.codegen.args [argctr++]);	/* #4 */
  caddr_t retselid		= (caddr_t)(spart->_.codegen.args [argctr++]);	/* #5 */
  SPART *lim_expn		= spart->_.codegen.args [argctr++];	/* #6 */
  SPART *ofs_expn		= spart->_.codegen.args [argctr++];	/* #7 */
  SPART	*tree = ssg->ssg_tree;
  ptrlong subtype = tree->_.req_top.subtype;
  const char *formatter, *agg_formatter, *agg_meta;
  ssg_valmode_t retvalmode;
  ssg_find_formatter_by_name_and_subtype (formatmode_name, SELECT_L, &formatter, &agg_formatter, &agg_meta);
  if (COUNT_DISTINCT_L == subtype)
    retvalmode = SSG_VALMODE_SQLVAL;
  else
    retvalmode = ssg_find_valmode_by_name (valmode_name);
  if (((NULL != formatter) || (NULL != agg_formatter)) && (NULL != retvalmode) && (SSG_VALMODE_LONG != retvalmode))
    spar_sqlprint_error ("'output:valmode' declaration conflicts with 'output:format'");
  if (NULL == retvalmode)
    retvalmode = ((NULL != formatter) ? SSG_VALMODE_LONG : SSG_VALMODE_SQLVAL);
  if (NULL != formatter)
    {
      ssg_puts ("SELECT "); ssg_puts (formatter); ssg_puts (" (");
      ssg_puts ("vector (");
      ssg_prin_id (ssg, retselid); ssg_putchar ('.'); ssg_prin_id (ssg, retname);
      ssg_puts ("), vector (");
      ssg_print_box_as_sql_atom (ssg, retname, SQL_ATOM_NARROW_ONLY /*???*/);
      ssg_puts (")) AS \"callret-0\" LONG VARCHAR\nFROM (");
      ssg->ssg_indent += 1;
      ssg_newline (0);
    }
  else if (NULL != agg_formatter)
    {
      ssg_puts ("SELECT "); ssg_puts (agg_formatter); ssg_puts (" (");
      if (NULL != agg_meta)
        {
          ssg_puts (agg_meta); ssg_puts (" (");
        }
      ssg_puts ("vector (");
      ssg_print_box_as_sql_atom (ssg, retname, SQL_ATOM_NARROW_ONLY /*???*/);
      if (NULL != agg_meta)
        {
          ssg_puts ("), '");
          ssg_puts (strchr (tree->_.req_top.formatmode_name, ' ')+1);
          ssg_putchar ('\'');
        }
      ssg_puts ("), vector ( __box_flags_tweak (");
      ssg_prin_id (ssg, retselid); ssg_putchar ('.'); ssg_prin_id (ssg, retname);
      ssg_puts (", 1))) AS \"aggret-0\" INTEGER FROM (");
      ssg->ssg_indent += 1;
      ssg_newline (0);
    }
  ssg_puts ("SELECT");
  if ((NULL != lim_expn) || (NULL != ofs_expn))
    ssg_print_limofs_expn (ssg, lim_expn, ofs_expn);
  if (SSG_VALMODE_LONG != retvalmode)
    ssg_puts (" __box_flags_tweak (");
  ssg_prin_id_with_suffix (ssg, retselid, "~pview");
  ssg_puts (".g_enum");
  if (SSG_VALMODE_LONG != retvalmode)
    ssg_puts (", 1)");
  ssg_puts (" AS ");
  ssg_prin_id (ssg, retname);
  ssg_puts (" FROM DB.DBA.SPARQL_SELECT_KNOWN_GRAPHS(return_iris, lim) ");
  ssg_puts ((SSG_VALMODE_LONG == retvalmode) ? "(g_enum IRI_ID) " : "(g_enum varchar) ");
  ssg_prin_id_with_suffix (ssg, retselid, "~pview");
  ssg_puts (" WHERE ");
  ssg_prin_id_with_suffix (ssg, retselid, "~pview");
  ssg_puts ((SSG_VALMODE_LONG == retvalmode) ? ".return_iris=0 " : ".return_iris=1 ");
  ssg_puts (" AND ");
  ssg_prin_id_with_suffix (ssg, retselid, "~pview");
  ssg_puts (".lim=");
  if (NULL != lim_expn)
    ssg_print_scalar_expn (ssg, spartlist (ssg->ssg_sparp, 3, BOP_PLUS, lim_expn, ofs_expn), SSG_VALMODE_SQLVAL, NULL_ASNAME);
  else
    ssg_puts ("NULL");
  if ((NULL != formatter) || (NULL != agg_formatter))
    {
      ssg_puts (") AS ");
      ssg_prin_id (ssg, retselid);
      ssg->ssg_indent--;
    }
}
