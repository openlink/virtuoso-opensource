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
#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser.h"
#include "xmlparser_impl.h"
#ifdef __cplusplus
}
#endif
#include "xml_ecm.h"

#define CTOR_NEEDS_LIMOFS_TRICK(top) \
 ((0 != unbox (top->_.req_top.offset)) || \
   ((SPARP_MAXLIMIT != unbox (top->_.req_top.limit)) && \
     ((1 != unbox (top->_.req_top.limit)) || \
       (0 != BOX_ELEMENTS (top->_.req_top.pattern->_.gp.members)) ) ) )

#define CTOR_DISJOIN_WHERE 1
#define CTOR_MAY_INTERSECTS_WHERE 0

caddr_t
spar_compose_report_flag (sparp_t *sparp)
{
  const char *fmtname = sparp->sparp_env->spare_output_format_name;
  return t_box_num (((NULL != fmtname) && !strcmp (fmtname, "_JAVA_")) ? 0 : 1);
}

extern int sparp_ctor_fields_are_disjoin_with_where_fields (sparp_t *sparp, SPART **ctor_fields, SPART **where_fields);
extern int sparp_ctor_fields_are_disjoin_with_data_gathering (sparp_t *sparp, SPART **ctor_fields, SPART *req, int the_query_is_topmost);

int
sparp_ctor_fields_are_disjoin_with_where_fields (sparp_t *sparp, SPART **ctor_fields, SPART **where_fields)
{
  sparp_equiv_t **top_eqs = sparp->sparp_equivs;
  int top_eq_count = sparp->sparp_equiv_count;
  SPART *top_gp = sparp->sparp_expr->_.req_top.pattern;
  int fld_ctr;
  for (fld_ctr = SPART_TRIPLE_FIELDS_COUNT; fld_ctr--; /*no step*/)
    {
      rdf_val_range_t rvr;
      SPART *ctor_fld = ctor_fields[fld_ctr];
      SPART *where_fld = where_fields[fld_ctr];
      ptrlong ctor_fld_type = SPART_TYPE (ctor_fld);
      ptrlong where_fld_type = SPART_TYPE (where_fld);
      memset (&rvr, 0, sizeof (rdf_val_range_t));
      rvr.rvrRestrictions = SPART_VARR_NOT_NULL;
      if (SPART_TRIPLE_OBJECT_IDX != fld_ctr)
        {
          rvr.rvrRestrictions |= SPART_VARR_IS_REF;
          if (SPART_TRIPLE_SUBJECT_IDX != fld_ctr)
            rvr.rvrRestrictions |= SPART_VARR_IS_IRI;
        }
      switch (ctor_fld_type)
        {
        case SPAR_BLANK_NODE_LABEL:
          if (SPART_VARR_IS_IRI & rvr.rvrRestrictions)
            return CTOR_DISJOIN_WHERE;
          rvr.rvrRestrictions |= SPART_VARR_IS_BLANK;
          break;
        case SPAR_VARIABLE:
          {
            sparp_equiv_t *src_equiv = sparp_equiv_get_ro (top_eqs, top_eq_count,
              top_gp, ctor_fld, SPARP_EQUIV_GET_NAMESAKES );
            if (NULL != src_equiv) /* src_equiv may be NULL in subqueries */
            sparp_rvr_tighten (sparp, &rvr, &(src_equiv->e_rvr), ~1); 
            break;
          }
        case SPAR_LIT: case SPAR_QNAME:
          {
            rdf_val_range_t tmp;
            sparp_rvr_set_by_constant (sparp, &tmp, NULL, ctor_fld);
            sparp_rvr_tighten (sparp, &rvr, &tmp, ~1); 
            break;
          }
        default: break;
        }
      if (SPART_VARR_CONFLICT & rvr.rvrRestrictions)
        return CTOR_DISJOIN_WHERE;
      switch (where_fld_type)
        {
        case SPAR_BLANK_NODE_LABEL: case SPAR_VARIABLE:
          sparp_rvr_tighten (sparp, &rvr, &(where_fld->_.var.rvr), ~1);
          break;
        case SPAR_LIT: case SPAR_QNAME:
          {
            rdf_val_range_t tmp;
            sparp_rvr_set_by_constant (sparp, &tmp, NULL, where_fld);
            sparp_rvr_tighten (sparp, &rvr, &tmp, ~1); 
            break;
          }
        default: break;
        }
      if (SPART_VARR_CONFLICT & rvr.rvrRestrictions)
        return CTOR_DISJOIN_WHERE;
    }
  return CTOR_MAY_INTERSECTS_WHERE;
}

int
sparp_gp_trav_find_isect_with_ctor (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{
  switch (curr->type)
    {
    case SPAR_TRIPLE:
      if (CTOR_MAY_INTERSECTS_WHERE ==
        sparp_ctor_fields_are_disjoin_with_where_fields (sparp, (SPART **)common_env, curr->_.triple.tr_fields) )
        return SPAR_GPT_COMPLETED;
      return SPAR_GPT_NODOWN;
    case SPAR_GP:
      if (SELECT_L == curr->_.gp.subtype)
      {
#if 1 /*!!! TBD: implement rewriting of ctor fields so that a field that correspond to an alias of subquery's retval is replaced with the expression of the alias. Then use the branch that is currently not in use */
          return SPAR_GPT_COMPLETED;
#else
          int isect_res;
          sparp_t *sub_sparp = sparp_down_to_sub (sparp, curr);
          isect_res = sparp_ctor_fields_are_disjoin_with_data_gathering (sub_sparp, (SPART **)common_env, curr->_.gp.subquery, 1);
          sparp_up_from_sub (sparp, curr, sub_sparp);
          if (CTOR_MAY_INTERSECTS_WHERE == isect_res)
            return SPAR_GPT_COMPLETED;
          return SPAR_GPT_NODOWN;
#endif
              }
      break;
              }
  return 0;
}


int
sparp_ctor_fields_are_disjoin_with_data_gathering (sparp_t *sparp, SPART **ctor_fields, SPART *req, int the_query_is_topmost)
{
  int res;
  SPART **saved_orig_retvals = NULL;
  SPART **saved_retvals = NULL;
  res = sparp_gp_trav (sparp, req->_.req_top.pattern, ctor_fields,
    sparp_gp_trav_find_isect_with_ctor, NULL,
    NULL, NULL, sparp_gp_trav_find_isect_with_ctor,
    NULL );
  if (res & SPAR_GPT_COMPLETED)
            return CTOR_MAY_INTERSECTS_WHERE;
  if (the_query_is_topmost)
    {
      saved_orig_retvals = req->_.req_top.orig_retvals;
      req->_.req_top.orig_retvals = NULL;
      saved_retvals = req->_.req_top.retvals;
      req->_.req_top.retvals = NULL;
    }
  res = sparp_trav_out_clauses (sparp, req, ctor_fields,
    sparp_gp_trav_find_isect_with_ctor, NULL,
    NULL, NULL, sparp_gp_trav_find_isect_with_ctor,
    NULL );
  if (the_query_is_topmost)
    {
      req->_.req_top.orig_retvals = saved_orig_retvals;
      req->_.req_top.retvals = saved_retvals;
    }
  if (res & SPAR_GPT_COMPLETED)
    return CTOR_MAY_INTERSECTS_WHERE;
  return CTOR_DISJOIN_WHERE;
}

typedef struct ctor_var_enumerator_s
{
  dk_set_t cve_dist_vars_acc;	/*!< Accumulator of variables with distinct names used in triple patterns of constructors */
  int cve_dist_vars_count;		/*!< Length of \c cve_dist_vars_acc */
  int cve_total_vars_count;		/*!< Count of all occurencies of variables */
  int cve_bnodes_are_prohibited;	/*!< Bnodes are not allowed in DELETE ctor gp */
  SPART *cve_limofs_var;	/*!< Variable that is passed from limit-offset subselect */
  caddr_t cve_limofs_var_alias;	/*!< Alias used for cve_limofs_var */
}
ctor_var_enumerator_t;

int
spar_cve_find_or_add_variable (sparp_t *sparp, ctor_var_enumerator_t *haystack_cve, SPART *needle_var)
{
  int var_ctr = haystack_cve->cve_dist_vars_count;
  dk_set_t var_iter;
  haystack_cve->cve_total_vars_count++;
  for (var_iter = haystack_cve->cve_dist_vars_acc; NULL != var_iter; var_iter = var_iter->next)
    {
      SPART *v = (SPART *)(var_iter->data);
      var_ctr--;
      if (!strcmp (needle_var->_.var.vname, v->_.var.vname))
        return var_ctr;
    }
  t_set_push (&(haystack_cve->cve_dist_vars_acc), needle_var);
  var_ctr = haystack_cve->cve_dist_vars_count;
  haystack_cve->cve_dist_vars_count++;
  return var_ctr;
}

int
sparp_gp_trav_ctor_var_to_limofs_aref (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env)
{ /* This rewrites variables that are nested into backquoted expressions in ctor template when the query has limit or offset clause */
  ctor_var_enumerator_t *cve = common_env;
  int curr_type = SPART_TYPE (curr);
  int var_ctr;
  if (SPAR_BLANK_NODE_LABEL == curr_type)
    spar_error (sparp, "Blank nodes can not be used in backquoted expressions of constructor template, consider using variables instead");
  if (SPAR_VARIABLE != curr_type)
    return SPAR_GPT_ENV_PUSH;
  var_ctr = spar_cve_find_or_add_variable (sparp, cve, curr);
  if (NULL != cve->cve_limofs_var_alias)
    {
      SPART *limofs_aref = spar_make_funcall (sparp, 0, "bif:aref",
        (SPART **)t_list (2, cve->cve_limofs_var, t_box_num_nonull (var_ctr)) );
      sts_this->sts_curr_array [sts_this->sts_ofs_of_curr_in_array] = limofs_aref;
    }
  return SPAR_GPT_NODOWN;
}

#define CTOR_OPCODE_VARIABLE 1
#define CTOR_OPCODE_BNODE 2
#define CTOR_OPCODE_CONST_OR_EXPN 3

void
spar_compose_retvals_of_ctor (sparp_t *sparp, SPART *ctor_gp, const char *funname, SPART *arg0, SPART *arglast, SPART ***retvals, ctor_var_enumerator_t *cve, const char *formatter)
{
  int triple_ctr, fld_ctr, var_ctr;
  dk_set_t bnode_iter;
  SPART *ctor_call;
  SPART *var_vector_expn;
  SPART *var_vector_arg;
  SPART *arg1, *arg3;
  dk_set_t const_tvectors = NULL;
  dk_set_t var_tvectors = NULL;
  dk_set_t bnodes_acc = NULL;	/*!< Accumulator of bnodes with distinct names used in triple patterns of constructors */
  int bnode_count = 0;		/*!< Length of bnodes_acc */
/* Making lists of variables, blank nodes, fixed triples, triples with variables and blank nodes. */
  for (triple_ctr = BOX_ELEMENTS_INT (ctor_gp->_.gp.members); triple_ctr--; /* no step */)
    {
      SPART *triple = ctor_gp->_.gp.members[triple_ctr];
      SPART **tvector_args;
      SPART *tvector_call;
      int triple_is_const = 1;
      tvector_args = (SPART **)t_list (6, NULL, NULL, NULL, NULL, NULL, NULL);
      tvector_call = spar_make_funcall (sparp, 0, ((NULL == formatter) ? "LONG::bif:vector" :  "bif:vector"), tvector_args);
      for (fld_ctr = 1; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
        {
          SPART *fld = triple->_.triple.tr_fields[fld_ctr];
          ptrlong fld_type = SPART_TYPE(fld);
          switch (fld_type)
            {
            case SPAR_VARIABLE:
              var_ctr = spar_cve_find_or_add_variable (sparp, cve, fld);
              tvector_args [(fld_ctr-1)*2] = (SPART *)t_box_num_nonull (CTOR_OPCODE_VARIABLE);
              tvector_args [(fld_ctr-1)*2 + 1] = (SPART *)t_box_num_nonull (var_ctr);
              triple_is_const = 0;
              break;
            case SPAR_BLANK_NODE_LABEL:
              if (cve->cve_bnodes_are_prohibited)
                spar_error (sparp, "Blank nodes are not allowed in DELETE constructor patterns");
              var_ctr = bnode_count;
              for (bnode_iter = bnodes_acc; NULL != bnode_iter; bnode_iter = bnode_iter->next)
                {
                  SPART *old_bnode = (SPART *)(bnode_iter->data);
                  var_ctr--;
                  if (!strcmp (fld->_.var.vname, old_bnode->_.var.vname))
                    goto bnode_found_or_added;
                }
              t_set_push (&bnodes_acc, fld);
              var_ctr = bnode_count++;
bnode_found_or_added:
              tvector_args [(fld_ctr-1)*2] = (SPART *)t_box_num_nonull (CTOR_OPCODE_BNODE);
              tvector_args [(fld_ctr-1)*2 + 1] = (SPART *)t_box_num_nonull (var_ctr);
              triple_is_const = 0;
              break;
            case SPAR_LIT: case SPAR_QNAME:
              tvector_args [(fld_ctr-1)*2] = (SPART *)t_box_num_nonull (CTOR_OPCODE_CONST_OR_EXPN);
              tvector_args [(fld_ctr-1)*2 + 1] = fld;
            default:
              {
                int old_total_vars_count = cve->cve_total_vars_count;
                sparp_gp_trav (sparp, fld, cve, NULL, NULL, sparp_gp_trav_ctor_var_to_limofs_aref, NULL, NULL, NULL);
                tvector_args [(fld_ctr-1)*2] = (SPART *)t_box_num_nonull (CTOR_OPCODE_CONST_OR_EXPN);
                tvector_args [(fld_ctr-1)*2 + 1] = fld;
                if (cve->cve_total_vars_count != old_total_vars_count)
                  triple_is_const = 0;
              }
              break;
            }
        }
      if (triple_is_const)
        {
          t_set_push (&const_tvectors, tvector_call);
        }
      else
        {
          t_set_push (&var_tvectors, tvector_call);
        }
    }
  var_vector_expn = spar_make_funcall (sparp, 0, ((NULL == formatter) ? "LONG::bif:vector" :  "bif:vector"),
    (SPART **)t_revlist_to_array (cve->cve_dist_vars_acc) );
  if (cve->cve_limofs_var)
    var_vector_arg = cve->cve_limofs_var;
  else
    var_vector_arg = var_vector_expn;
  arg1 = spar_make_funcall (sparp, 0, "bif:vector", (SPART **)t_list_to_array (var_tvectors));
  arg3 = spar_make_funcall (sparp, 0, "bif:vector", (SPART **)t_list_to_array (const_tvectors));
  if (NULL != arglast)
    ctor_call = spar_make_funcall (sparp, 0, funname,
      (SPART **)t_list (5, arg0, arg1, var_vector_arg, arg3, arglast) );
  else if (NULL != arg0)
    ctor_call = spar_make_funcall (sparp, 0, funname,
      (SPART **)t_list (4, arg0, arg1, var_vector_arg, arg3) );
  else
    ctor_call = spar_make_funcall (sparp, 0, funname,
      (SPART **)t_list (3, arg1, var_vector_arg, arg3) );
  if (cve->cve_limofs_var_alias)
    {
      SPART *alias = spartlist (sparp, 4, SPAR_ALIAS, var_vector_expn, cve->cve_limofs_var_alias, SSG_VALMODE_AUTO);
      retvals[0] = (SPART **)t_list (2, ctor_call, alias);
    }
  else
    {
      retvals[0] = (SPART **)t_list (1, ctor_call);
    }
}

void
spar_compose_retvals_of_construct (sparp_t *sparp, SPART *top, SPART *ctor_gp, const char *formatter)
{
  int need_limofs_trick = CTOR_NEEDS_LIMOFS_TRICK(top);
  ctor_var_enumerator_t cve;
  memset (&cve, 0, sizeof (ctor_var_enumerator_t));
  if (need_limofs_trick)
    {
      caddr_t limofs_name = t_box_dv_short_string (":\"limofs\".\"ctor-1\"");
      cve.cve_limofs_var = spar_make_variable (sparp, limofs_name);
      cve.cve_limofs_var_alias = t_box_dv_short_string ("ctor-1");
    }
  spar_compose_retvals_of_ctor (sparp, ctor_gp, "sql:SPARQL_CONSTRUCT", NULL, NULL,
    &(top->_.req_top.retvals), &cve, formatter );
}

void
spar_compose_retvals_of_insert_or_delete (sparp_t *sparp, SPART *top, SPART *graph_to_patch, SPART *ctor_gp)
{
  int need_limofs_trick = CTOR_NEEDS_LIMOFS_TRICK(top);
  const char *top_fname;
  caddr_t log_mode;
  SPART **rv;
  ctor_var_enumerator_t cve;
  memset (&cve, 0, sizeof (ctor_var_enumerator_t));
  log_mode = sparp->sparp_env->spare_sparul_log_mode;
  if (NULL == log_mode)
    log_mode = t_NEW_DB_NULL;
  if (need_limofs_trick)
    {
      caddr_t limofs_name = t_box_dv_short_string (":\"limofs\".\"ctor-1\"");
      cve.cve_limofs_var = spar_make_variable (sparp, limofs_name);
      cve.cve_limofs_var_alias = t_box_dv_short_string ("ctor-1");
    }
  spar_compose_retvals_of_ctor (sparp, ctor_gp, "sql:SPARQL_CONSTRUCT", NULL, NULL,
    &(top->_.req_top.retvals), &cve, NULL );
  rv = top->_.req_top.retvals;
  if (INSERT_L != top->_.req_top.subtype)
    cve.cve_bnodes_are_prohibited = 1;
  if (NULL != sparp->sparp_env->spare_output_route_name)
    {
      top_fname = t_box_sprintf (200, "sql:SPARQL_ROUTE_DICT_CONTENT_%.100s", sparp->sparp_env->spare_output_route_name);
      rv[0] = spar_make_funcall (sparp, 0, top_fname,
        (SPART **)t_list (10, graph_to_patch,
          t_box_dv_short_string ((INSERT_L == top->_.req_top.subtype) ? "INSERT" : "DELETE"),
          ((NULL == sparp->sparp_env->spare_storage_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_storage_name),
          ((NULL == sparp->sparp_env->spare_output_storage_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_output_storage_name),
          ((NULL == sparp->sparp_env->spare_output_format_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_output_format_name),
          ((INSERT_L == top->_.req_top.subtype) ? t_NEW_DB_NULL : (caddr_t)(rv[0])),
          ((INSERT_L == top->_.req_top.subtype) ? (caddr_t)(rv[0]) : t_NEW_DB_NULL),
          t_NEW_DB_NULL,
          log_mode, spar_compose_report_flag (sparp)) );
    }
  else
    {
  if (INSERT_L == top->_.req_top.subtype)
    top_fname = "sql:SPARQL_INSERT_DICT_CONTENT";
  else
      top_fname = "sql:SPARQL_DELETE_DICT_CONTENT";
  rv[0] = spar_make_funcall (sparp, 0, top_fname,
        (SPART **)t_list (4, graph_to_patch,
          rv[0], log_mode, spar_compose_report_flag (sparp)) );
    }
}

void
spar_compose_retvals_of_modify (sparp_t *sparp, SPART *top, SPART *graph_to_patch, SPART *del_ctor_gp, SPART *ins_ctor_gp)
{
  int need_limofs_trick;
  caddr_t log_mode;
  SPART **ins = NULL;
  SPART **rv;
  ctor_var_enumerator_t cve;
  if (0 == BOX_ELEMENTS (del_ctor_gp->_.gp.members))
    {
      top->_.req_top.subtype = INSERT_L;
      spar_compose_retvals_of_insert_or_delete (sparp, top, graph_to_patch, ins_ctor_gp);
      return;
    }
  if (0 == BOX_ELEMENTS (ins_ctor_gp->_.gp.members))
    {
      top->_.req_top.subtype = DELETE_L;
      spar_compose_retvals_of_insert_or_delete (sparp, top, graph_to_patch, del_ctor_gp);
      return;
    }
  need_limofs_trick = CTOR_NEEDS_LIMOFS_TRICK(top);
  memset (&cve, 0, sizeof (ctor_var_enumerator_t));
  log_mode = sparp->sparp_env->spare_sparul_log_mode;
  if (NULL == log_mode)
    log_mode = t_NEW_DB_NULL;
  if (need_limofs_trick)
    {
      caddr_t limofs_name = t_box_dv_short_string (":\"limofs\".\"ctor-1\"");
      cve.cve_limofs_var = spar_make_variable (sparp, limofs_name);
      cve.cve_limofs_var_alias = t_box_dv_short_string ("ctor-1");
    }
  cve.cve_bnodes_are_prohibited = 1;
  spar_compose_retvals_of_ctor (sparp, del_ctor_gp, "sql:SPARQL_CONSTRUCT", NULL, NULL,
    &(top->_.req_top.retvals), &cve, NULL );
  cve.cve_limofs_var_alias = NULL;
  cve.cve_bnodes_are_prohibited = 0;
  spar_compose_retvals_of_ctor (sparp, ins_ctor_gp, "sql:SPARQL_CONSTRUCT", NULL, NULL,
    &ins, &cve, NULL );
  rv = top->_.req_top.retvals;

  if (NULL != sparp->sparp_env->spare_output_route_name)
    rv[0] = spar_make_funcall (sparp, 0,
      t_box_sprintf (200, "sql:SPARQL_ROUTE_DICT_CONTENT_%.100s", sparp->sparp_env->spare_output_route_name),
      (SPART **)t_list (10, graph_to_patch,
        t_box_dv_short_string ("MODIFY"),
        ((NULL == sparp->sparp_env->spare_storage_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_storage_name),
        ((NULL == sparp->sparp_env->spare_output_storage_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_output_storage_name),
        ((NULL == sparp->sparp_env->spare_output_format_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_output_format_name),
        rv[0], ins[0],
        t_NEW_DB_NULL,
        log_mode, spar_compose_report_flag (sparp)) );
  else
  rv[0] = spar_make_funcall (sparp, 0, "sql:SPARQL_MODIFY_BY_DICT_CONTENTS",
    (SPART **)t_list (5, graph_to_patch, rv[0], ins[0], log_mode, spar_compose_report_flag (sparp)) );
}

SPART *
spar_emulate_ctor_field (sparp_t *sparp, SPART *opcode, SPART *oparg, SPART **vars)
{
  static SPART *bnode_emulation = NULL;
  switch (unbox ((caddr_t)opcode))
    {
    case CTOR_OPCODE_VARIABLE:
      return vars [unbox((caddr_t)oparg)];
    case CTOR_OPCODE_BNODE:
      {
        if (NULL == bnode_emulation)
          bnode_emulation = box_copy_tree (spartlist (sparp, 1, SPAR_BLANK_NODE_LABEL));
        return bnode_emulation;
      }
    case CTOR_OPCODE_CONST_OR_EXPN: return oparg;
    }
  spar_internal_error (sparp, "spar_" "emulate_ctor_field(): bad opcode");
  return NULL; /* never reached */
}

SPART *
spar_find_single_physical_triple_pattern (sparp_t *sparp, SPART *tree)
{
  switch (SPART_TYPE (tree))
    {
    case SPAR_TRIPLE:
      if (1 == BOX_ELEMENTS (tree->_.triple.tc_list))
        {
          quad_map_t *qm = tree->_.triple.tc_list[0]->tc_qm;
          if ((NULL != qm->qmTableName) && !strcmp (qm->qmTableName, "DB.DBA.RDF_QUAD"))
            return tree;
        }
      return NULL;
    case SPAR_GP:
      if ((1 == BOX_ELEMENTS (tree->_.gp.members)) && (NULL == tree->_.gp.subquery))
        return spar_find_single_physical_triple_pattern (sparp, tree->_.gp.members[0]);
      return NULL;
    default:
      spar_internal_error (sparp, "spar_" "find_single_physical_triple_pattern(): unsupported subtree type");
    }
  return NULL;
}

int
spar_tr_fields_are_similar (sparp_t *sparp, SPART *fld1, SPART *fld2)
{
  int fldtype = SPART_TYPE (fld1);
  if (fldtype != SPART_TYPE (fld2))
    return 0;
  switch (fldtype)
    {
    case SPAR_VARIABLE: case SPAR_BLANK_NODE_LABEL:
      return (strcmp (fld1->_.var.vname, fld2->_.var.vname) ? 0 : 1);
    case SPAR_QNAME:
      return (strcmp (fld1->_.lit.val, fld2->_.lit.val) ? 0 : 1);
    case SPAR_LIT:
      {
        caddr_t v1 = SPAR_LIT_OR_QNAME_VAL (fld1);
        caddr_t v2 = SPAR_LIT_OR_QNAME_VAL (fld2);
        if ((DV_TYPE_OF (v1) != DV_TYPE_OF (v2)) ||
          (DVC_MATCH != cmp_boxes_safe (v1, v2, NULL, NULL)) )
          return 0;
        if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (fld1)) ||
          (DV_ARRAY_OF_POINTER != DV_TYPE_OF (fld2)) )
          return 1;
        if ((DV_TYPE_OF (fld1->_.lit.datatype) != DV_TYPE_OF (fld2->_.lit.datatype)) ||
          (DV_TYPE_OF (fld1->_.lit.language) != DV_TYPE_OF (fld2->_.lit.language)) )
          return 0;
        if ((DVC_MATCH != cmp_boxes_safe (fld1->_.lit.datatype, fld2->_.lit.datatype, NULL, NULL)) ||
          (DVC_MATCH != cmp_boxes_safe (fld2->_.lit.language, fld2->_.lit.language, NULL, NULL)) )
          return 0;
        return 1;
      }
    default:
      spar_internal_error (sparp, "spar_" "tr_fields_are_similar(): unsuooprted type");
    }
  return 0; /* to keep compiler happy */
}

int
spar_optimize_delete_of_single_triple_pattern (sparp_t *sparp, SPART *top)
{
  SPART *triple;
  SPART *ctor;
  SPART **known_vars;
  SPART **retvals = top->_.req_top.retvals;
  int retvals_count = BOX_ELEMENTS (retvals);
  SPART **var_triples, **args;
  SPART *graph_expn, *log_mode_expn, *good_ctor_call, *compose_report_expn;
  if (NULL != sparp->sparp_env->spare_output_route_name)
    return 0; /* If an output may go outside the default storage then there's no way of avoiding the complete filling of the result dictionary */
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (retvals[0])) && (4 == BOX_ELEMENTS (retvals[0]->_.funcall.argtrees)));
  triple = spar_find_single_physical_triple_pattern (sparp, top->_.req_top.pattern);
  if (NULL == triple)
    return 0; /* nontrivial pattern, can not be optimized this way */
  graph_expn		= retvals[0]->_.funcall.argtrees[0];
  ctor			= retvals[0]->_.funcall.argtrees[1];
  log_mode_expn		= retvals[0]->_.funcall.argtrees[2];
  compose_report_expn	= retvals[0]->_.funcall.argtrees[3];
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (ctor)) && (3 == BOX_ELEMENTS (ctor->_.funcall.argtrees)));
  dbg_assert (DELETE_L == top->_.req_top.subtype);
  var_triples = ctor->_.funcall.argtrees[0]->_.funcall.argtrees;
  if (1 < retvals_count)
    known_vars = retvals [retvals_count-1]->_.funcall.argtrees;
  else
    known_vars = ctor->_.funcall.argtrees[1]->_.funcall.argtrees;
  if (1 != BOX_ELEMENTS (var_triples))
    return 0; /* nontrivial constructor, can not be optimized this way */
  args = var_triples[0]->_.funcall.argtrees;
  if ((CTOR_OPCODE_BNODE == unbox ((caddr_t)(args[0]))) ||
    (CTOR_OPCODE_BNODE == unbox ((caddr_t)(args[2]))) ||
    (CTOR_OPCODE_BNODE == unbox ((caddr_t)(args[4]))) )
    return 0; /* bnodes in constructor can not be optimized this way (BTW that is blab when inside DELETE) */
  if (!spar_tr_fields_are_similar (sparp, graph_expn,
      triple->_.triple.tr_fields[SPART_TRIPLE_GRAPH_IDX] ) ||
    !spar_tr_fields_are_similar (sparp,
      spar_emulate_ctor_field (sparp, args[0], args[1], known_vars),
      triple->_.triple.tr_fields[SPART_TRIPLE_SUBJECT_IDX] ) ||
    !spar_tr_fields_are_similar (sparp,
      spar_emulate_ctor_field (sparp, args[2], args[3], known_vars),
      triple->_.triple.tr_fields[SPART_TRIPLE_PREDICATE_IDX] ) ||
    !spar_tr_fields_are_similar (sparp,
      spar_emulate_ctor_field (sparp, args[4], args[5], known_vars),
      triple->_.triple.tr_fields[SPART_TRIPLE_OBJECT_IDX] ) )
    return 0;
  good_ctor_call = spar_make_funcall (sparp, 0, "sql:SPARQL_DELETE_CTOR",
    (SPART **)t_list (4,
      graph_expn,
      spar_make_funcall (sparp, 0, "bif:vector", var_triples),
      ctor->_.funcall.argtrees[1],
      log_mode_expn ) );
  ctor->_.funcall.argtrees[0] = spar_make_funcall (sparp, 0, "bif:vector",
        (SPART **)t_list (0) );
  retvals[0]->_.funcall.argtrees[0] = good_ctor_call;
  return 1;
}

void
spar_optimize_retvals_of_insert_or_delete (sparp_t *sparp, SPART *top)
{
  SPART *ctor;
  SPART **known_vars;
  SPART **retvals = top->_.req_top.retvals;
  int retvals_count = BOX_ELEMENTS (retvals);
  SPART **var_triples;
  dk_set_t good_positions = NULL;
  dk_set_t positions_with_bnodes = NULL;
  dk_set_t good_triples = NULL;
  dk_set_t bad_triples = NULL;
  int all_triple_count, bad_triple_count, tctr;
  const char *fname;
  SPART *graph_expn, *log_mode_expn, *good_ctor_call, *compose_report_expn;
  if (NULL != sparp->sparp_env->spare_output_route_name)
    return; /* If an output may go outside the default storage then there's no way of avoiding the complete filling of the result dictionary */
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (retvals[0])) && (4 == BOX_ELEMENTS (retvals[0]->_.funcall.argtrees)));
  graph_expn	= retvals[0]->_.funcall.argtrees[0];
  ctor		= retvals[0]->_.funcall.argtrees[1];
  log_mode_expn	= retvals[0]->_.funcall.argtrees[2];
  compose_report_expn	= retvals[0]->_.funcall.argtrees[3];
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (ctor)) && (3 == BOX_ELEMENTS (ctor->_.funcall.argtrees)));
  var_triples = ctor->_.funcall.argtrees[0]->_.funcall.argtrees;
  if (1 < retvals_count)
    known_vars = retvals [retvals_count-1]->_.funcall.argtrees;
  else
    known_vars = ctor->_.funcall.argtrees[1]->_.funcall.argtrees;
  all_triple_count = bad_triple_count = BOX_ELEMENTS (var_triples);
  for (tctr = all_triple_count; tctr--; /* no step */)
    {
      SPART **args = var_triples[tctr]->_.funcall.argtrees;
      SPART *quad_fields[SPART_TRIPLE_FIELDS_COUNT];
      quad_fields [SPART_TRIPLE_GRAPH_IDX] = graph_expn;
      quad_fields [SPART_TRIPLE_SUBJECT_IDX] = spar_emulate_ctor_field (sparp, args[0], args[1], known_vars);
      quad_fields [SPART_TRIPLE_PREDICATE_IDX] = spar_emulate_ctor_field (sparp, args[2], args[3], known_vars);
      quad_fields [SPART_TRIPLE_OBJECT_IDX] = spar_emulate_ctor_field (sparp, args[4], args[5], known_vars);
      if ((CTOR_OPCODE_BNODE == unbox ((caddr_t)(args[0]))) ||
        (CTOR_OPCODE_BNODE == unbox ((caddr_t)(args[2]))) ||
        (CTOR_OPCODE_BNODE == unbox ((caddr_t)(args[4]))) )
        t_set_push (&positions_with_bnodes, ((void *)((ptrlong)tctr)));
      if (CTOR_DISJOIN_WHERE ==
        sparp_ctor_fields_are_disjoin_with_data_gathering (sparp, quad_fields, top, 1) )
        {
          t_set_push (&good_positions, ((void *)((ptrlong)tctr)));
          bad_triple_count--;
        }
    }
  if (0 != bad_triple_count)
    {
      DO_SET (ptrlong, bnode_pos, &positions_with_bnodes)
        {
          t_set_delete (&good_positions, (void *)bnode_pos);
        }
      END_DO_SET()
    }
  if (NULL == good_positions)
    return;
  for (tctr = all_triple_count; tctr--; /* no step */)
    {
      if (0 <= dk_set_position (good_positions, ((void *)((ptrlong)tctr))))
        t_set_push (&good_triples, var_triples[tctr]);
      else
        t_set_push (&bad_triples, var_triples[tctr]);
    }
  fname = ((INSERT_L == top->_.req_top.subtype) ? "sql:SPARQL_INSERT_CTOR" : "sql:SPARQL_DELETE_CTOR");
  good_ctor_call = spar_make_funcall (sparp, 0, fname,
    (SPART **)t_list (4,
      graph_expn,
      spar_make_funcall (sparp, 0, "bif:vector",
        (SPART **)t_list_to_array (good_triples) ),
      ctor->_.funcall.argtrees[1],
      log_mode_expn ) );
  ctor->_.funcall.argtrees[0] = spar_make_funcall (sparp, 0, "bif:vector",
        (SPART **)t_list_to_array (bad_triples) );
  retvals[0]->_.funcall.argtrees[0] = good_ctor_call;
}

void
spar_optimize_retvals_of_modify (sparp_t *sparp, SPART *top)
{
  SPART *del_ctor, *ins_ctor;
  SPART **known_vars;
  SPART **retvals = top->_.req_top.retvals;
  int retvals_count = BOX_ELEMENTS (retvals);
  SPART **del_var_triples, **del_const_triples, **ins_var_triples;
  dk_set_t good_positions;
  dk_set_t positions_with_bnodes;
  dk_set_t good_del_triples = NULL;
  dk_set_t bad_del_triples = NULL;
  dk_set_t good_ins_triples = NULL;
  dk_set_t bad_ins_triples = NULL;
  int all_del_triple_count, bad_del_triple_count, del_const_count, del_tctr;
  int all_ins_triple_count, bad_ins_triple_count, ins_tctr;
  SPART *graph_expn, *log_mode_expn, *good_ctor_call, *compose_report_expn;
  if (NULL != sparp->sparp_env->spare_output_route_name)
    return; /* If an output may go outside the default storage then there's no way of avoiding the complete filling of the result dictionary */
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (retvals[0])) && (5 == BOX_ELEMENTS (retvals[0]->_.funcall.argtrees)));
  graph_expn	= retvals[0]->_.funcall.argtrees[0];
  del_ctor	= retvals[0]->_.funcall.argtrees[1];
  ins_ctor	= retvals[0]->_.funcall.argtrees[2];
  log_mode_expn	= retvals[0]->_.funcall.argtrees[3];
  compose_report_expn	= retvals[0]->_.funcall.argtrees[4];
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (del_ctor)) && (3 == BOX_ELEMENTS (del_ctor->_.funcall.argtrees)));
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (ins_ctor)) && (3 == BOX_ELEMENTS (ins_ctor->_.funcall.argtrees)));
  del_var_triples = del_ctor->_.funcall.argtrees[0]->_.funcall.argtrees;
  ins_var_triples = ins_ctor->_.funcall.argtrees[0]->_.funcall.argtrees;
  del_const_triples = del_ctor->_.funcall.argtrees[2]->_.funcall.argtrees;
  del_const_count = BOX_ELEMENTS (del_const_triples);
  if (1 < retvals_count)
    known_vars = retvals [retvals_count-1]->_.funcall.argtrees;
  else
    known_vars = ins_ctor->_.funcall.argtrees[1]->_.funcall.argtrees;
/* Part 1. Collecting optimized data for DELETE ctor */
  good_positions = NULL;
  all_del_triple_count = bad_del_triple_count = BOX_ELEMENTS (del_var_triples);
  for (del_tctr = all_del_triple_count; del_tctr--; /* no step */)
    {
      SPART **args = del_var_triples[del_tctr]->_.funcall.argtrees;
      SPART *quad_fields[SPART_TRIPLE_FIELDS_COUNT];
      quad_fields [SPART_TRIPLE_GRAPH_IDX] = graph_expn;
      quad_fields [SPART_TRIPLE_SUBJECT_IDX] = spar_emulate_ctor_field (sparp, args[0], args[1], known_vars);
      quad_fields [SPART_TRIPLE_PREDICATE_IDX] = spar_emulate_ctor_field (sparp, args[2], args[3], known_vars);
      quad_fields [SPART_TRIPLE_OBJECT_IDX] = spar_emulate_ctor_field (sparp, args[4], args[5], known_vars);
      if (CTOR_DISJOIN_WHERE ==
        sparp_ctor_fields_are_disjoin_with_data_gathering (sparp, quad_fields, top, 1) )
        {
          t_set_push (&good_positions, ((void *)((ptrlong)del_tctr)));
          bad_del_triple_count--;
        }
    }
  for (del_tctr = all_del_triple_count; del_tctr--; /* no step */)
    {
      if (0 <= dk_set_position (good_positions, ((void *)((ptrlong)del_tctr))))
        t_set_push (&good_del_triples, del_var_triples[del_tctr]);
      else
        t_set_push (&bad_del_triples, del_var_triples[del_tctr]);
    }
  good_positions = NULL;
  positions_with_bnodes = NULL;
  all_ins_triple_count = bad_ins_triple_count = BOX_ELEMENTS (ins_var_triples);
  for (ins_tctr = all_ins_triple_count; ins_tctr--; /* no step */)
    {
      SPART **args = ins_var_triples[ins_tctr]->_.funcall.argtrees;
      SPART *quad_fields[SPART_TRIPLE_FIELDS_COUNT];
      quad_fields [SPART_TRIPLE_GRAPH_IDX] = graph_expn;
      quad_fields [SPART_TRIPLE_SUBJECT_IDX] = spar_emulate_ctor_field (sparp, args[0], args[1], known_vars);
      quad_fields [SPART_TRIPLE_PREDICATE_IDX] = spar_emulate_ctor_field (sparp, args[2], args[3], known_vars);
      quad_fields [SPART_TRIPLE_OBJECT_IDX] = spar_emulate_ctor_field (sparp, args[4], args[5], known_vars);
      if ((CTOR_OPCODE_BNODE == unbox ((caddr_t)(args[0]))) ||
        (CTOR_OPCODE_BNODE == unbox ((caddr_t)(args[2]))) ||
        (CTOR_OPCODE_BNODE == unbox ((caddr_t)(args[4]))) )
        t_set_push (&positions_with_bnodes, ((void *)((ptrlong)ins_tctr)));
      if (CTOR_DISJOIN_WHERE !=
        sparp_ctor_fields_are_disjoin_with_data_gathering (sparp, quad_fields, top, 1) )
        goto ins_is_bad; /* see below */
      for (del_tctr = all_del_triple_count; del_tctr--; /* no step */)
        {
          SPART **del_args = del_var_triples[del_tctr]->_.funcall.argtrees;
          SPART *del_fields[SPART_TRIPLE_FIELDS_COUNT];
          del_fields [SPART_TRIPLE_GRAPH_IDX] = graph_expn;
          del_fields [SPART_TRIPLE_SUBJECT_IDX] = spar_emulate_ctor_field (sparp, del_args[0], del_args[1], known_vars);
          del_fields [SPART_TRIPLE_PREDICATE_IDX] = spar_emulate_ctor_field (sparp, del_args[2], del_args[3], known_vars);
          del_fields [SPART_TRIPLE_OBJECT_IDX] = spar_emulate_ctor_field (sparp, del_args[4], del_args[5], known_vars);
          if (CTOR_DISJOIN_WHERE !=
            sparp_ctor_fields_are_disjoin_with_where_fields (sparp, quad_fields, del_fields) )
            goto ins_is_bad; /* see below */
        }
      for (del_tctr = del_const_count; del_tctr--; /* no step */)
        {
          SPART **del_args = del_const_triples[del_tctr]->_.funcall.argtrees;
          SPART *del_fields[SPART_TRIPLE_FIELDS_COUNT];
          del_fields [SPART_TRIPLE_GRAPH_IDX] = graph_expn;
          del_fields [SPART_TRIPLE_SUBJECT_IDX] = spar_emulate_ctor_field (sparp, del_args[0], del_args[1], known_vars);
          del_fields [SPART_TRIPLE_PREDICATE_IDX] = spar_emulate_ctor_field (sparp, del_args[2], del_args[3], known_vars);
          del_fields [SPART_TRIPLE_OBJECT_IDX] = spar_emulate_ctor_field (sparp, del_args[4], del_args[5], known_vars);
          if (CTOR_DISJOIN_WHERE !=
            sparp_ctor_fields_are_disjoin_with_where_fields (sparp, quad_fields, del_fields) )
            goto ins_is_bad; /* see below */
        }
      t_set_push (&good_positions, ((void *)((ptrlong)ins_tctr)));
       bad_ins_triple_count--;
ins_is_bad: ;
    }
  if (0 != bad_ins_triple_count)
    {
      DO_SET (ptrlong, bnode_pos, &positions_with_bnodes)
        {
          t_set_delete (&good_positions, (void *)bnode_pos);
        }
      END_DO_SET()
    }
  for (ins_tctr = all_ins_triple_count; ins_tctr--; /* no step */)
    {
      if (0 <= dk_set_position (good_positions, ((void *)((ptrlong)ins_tctr))))
        t_set_push (&good_ins_triples, ins_var_triples[ins_tctr]);
      else
        t_set_push (&bad_ins_triples, ins_var_triples[ins_tctr]);
    }
  if ((NULL == good_del_triples) && (NULL == good_ins_triples))
    return;
  good_ctor_call = spar_make_funcall (sparp, 0, "sql:SPARQL_MODIFY_CTOR",
    (SPART **)t_list (5,
      graph_expn,
      spar_make_funcall (sparp, 0, "bif:vector",
        (SPART **)t_list_to_array (good_del_triples) ),
      spar_make_funcall (sparp, 0, "bif:vector",
        (SPART **)t_list_to_array (good_ins_triples) ),
      ins_ctor->_.funcall.argtrees[1],
      log_mode_expn ) );
  if (NULL == bad_del_triples)
    retvals[0]->_.funcall.argtrees[1] = (SPART *) t_NEW_DB_NULL;
  else
    del_ctor->_.funcall.argtrees[0] = spar_make_funcall (sparp, 0, "bif:vector",
        (SPART **)t_list_to_array (bad_del_triples) );
  if (NULL == bad_ins_triples)
    retvals[0]->_.funcall.argtrees[2] = (SPART *) t_NEW_DB_NULL;
  else
    ins_ctor->_.funcall.argtrees[0] = spar_make_funcall (sparp, 0, "bif:vector",
        (SPART **)t_list_to_array (bad_ins_triples) );
  retvals[0]->_.funcall.argtrees[0] = good_ctor_call;
}
