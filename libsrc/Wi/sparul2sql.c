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

/* The name becomes misleading because "limofs" subquery can now be used for CONSTRUCT {...} WHERE {...} GROUP BY..., not only for LIMIT...OFFSET... */
#define CTOR_NEEDS_LIMOFS_TRICK(top) ( \
 (DV_LONG_INT != DV_TYPE_OF (top->_.req_top.offset)) || \
 (DV_LONG_INT != DV_TYPE_OF (top->_.req_top.limit)) || \
 (0 != unbox ((caddr_t)(top->_.req_top.offset))) || \
 ((NULL != top->_.req_top.limit) && \
     ((1 != unbox ((caddr_t)(top->_.req_top.limit))) || \
       (0 != BOX_ELEMENTS (top->_.req_top.pattern->_.gp.members)) ) ) || \
 (NULL != top->_.req_top.groupings) )

#define CTOR_DISJOIN_WHERE 1
#define CTOR_MAY_INTERSECTS_WHERE 0

caddr_t
spar_compose_report_flag (sparp_t *sparp)
{
  sparp_env_t *spare = sparp->sparp_env;
  const char *fmtname;
  caddr_t res;
  if (NULL != spare->spare_output_compose_report)
    return spare->spare_output_compose_report;
  fmtname = spare->spare_output_format_name; /* Report is always a result-set, so no spare_output_XXX_format name */
  if ((NULL == spare->spare_output_format_name)
    && (NULL == sparp->sparp_env->spare_parent_env)
    && ssg_is_odbc_cli () )
    {
      if (ssg_is_odbc_msaccess_cli ())
        fmtname = spare->spare_output_format_name = t_box_dv_short_string ("_MSACCESS_");
      else
        fmtname = spare->spare_output_format_name = t_box_dv_short_string ("_UDBC_");
    }
  res = t_box_num_nonull (((NULL != fmtname) && (!strcmp (fmtname, "_JAVA_") || !strcmp (fmtname, "_UDBC_") || !strcmp (fmtname, "_MSACCESS_"))) ? 0 : 1);
  spare->spare_output_compose_report = res;
  return res;
}

extern int sparp_ctor_fields_are_disjoin_with_where_fields (sparp_t *sparp, SPART **ctor_fields, SPART **where_fields);
extern int sparp_ctor_fields_are_disjoin_with_data_gathering (sparp_t *sparp, SPART **ctor_fields, SPART *req, int the_query_is_topmost);

int
sparp_ctor_fields_are_disjoin_with_where_fields (sparp_t *sparp, SPART **ctor_fields, SPART **where_fields)
{
  sparp_equiv_t **top_eqs = sparp->sparp_sg->sg_equivs;
  int top_eq_count = sparp->sparp_sg->sg_equiv_count;
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
              sparp_rvr_tighten (sparp, &rvr, &(src_equiv->e_rvr), ~0);
            break;
          }
        case SPAR_LIT: case SPAR_QNAME:
          {
            rdf_val_range_t tmp;
            sparp_rvr_set_by_constant (sparp, &tmp, NULL, ctor_fld);
            sparp_rvr_tighten (sparp, &rvr, &tmp, ~0);
            break;
          }
        default: break;
        }
      if (SPART_VARR_CONFLICT & rvr.rvrRestrictions)
        return CTOR_DISJOIN_WHERE;
      switch (where_fld_type)
        {
        case SPAR_BLANK_NODE_LABEL: case SPAR_VARIABLE:
          sparp_rvr_tighten (sparp, &rvr, &(where_fld->_.var.rvr), ~0);
          break;
        case SPAR_LIT: case SPAR_QNAME:
          {
            rdf_val_range_t tmp;
            sparp_rvr_set_by_constant (sparp, &tmp, NULL, where_fld);
            sparp_rvr_tighten (sparp, &rvr, &tmp, ~0);
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
      switch (curr->_.gp.subtype)
        {
        case SELECT_L:
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
        case SERVICE_L:
          return 0; /* remote triples can not interfere with local data manipulations. This may change in the future if SERVICE group ctor template is added in SPARUL */
        case VALUES_L:
          return 0; /* no variables --- no interference */
        }
      break;
    }
  return 0;
}


int
sparp_ctor_fields_are_disjoin_with_data_gathering (sparp_t *sparp, SPART **ctor_fields, SPART *req, int the_query_is_topmost)
{
  int res;
  /*SPART **saved_orig_retvals = NULL;*/
  SPART **saved_retvals = NULL;
  res = sparp_gp_trav (sparp, req->_.req_top.pattern, ctor_fields,
    sparp_gp_trav_find_isect_with_ctor, NULL,
    NULL, NULL, sparp_gp_trav_find_isect_with_ctor,
    NULL );
  if (res & SPAR_GPT_COMPLETED)
    return CTOR_MAY_INTERSECTS_WHERE;
  if (the_query_is_topmost)
    {
      /*saved_orig_retvals = req->_.req_top.orig_retvals;
      req->_.req_top.orig_retvals = NULL;*/
      saved_retvals = req->_.req_top.retvals;
      req->_.req_top.retvals = NULL;
    }
  res = sparp_trav_out_clauses (sparp, req, ctor_fields,
    sparp_gp_trav_find_isect_with_ctor, NULL,
    NULL, NULL, sparp_gp_trav_find_isect_with_ctor,
    NULL );
  if (the_query_is_topmost)
    {
      /*req->_.req_top.orig_retvals = saved_orig_retvals;*/
      req->_.req_top.retvals = saved_retvals;
    }
  if (res & SPAR_GPT_COMPLETED)
    return CTOR_MAY_INTERSECTS_WHERE;
  return CTOR_DISJOIN_WHERE;
}

typedef struct ctor_var_enumerator_s
{
  dk_set_t cve_dist_vars_acc;		/*!< Accumulator of variables with distinct names used in triple patterns of constructors */
  int cve_dist_vars_count;		/*!< Length of \c cve_dist_vars_acc */
  int cve_total_vars_count;		/*!< Count of all occurrences of variables */
  int cve_bnodes_are_prohibited;	/*!< Bnodes are not allowed in DELETE ctor gp */
  SPART *cve_limofs_var;		/*!< Variable that is passed from limit-offset subselect */
  caddr_t cve_limofs_var_alias;		/*!< Alias used for cve_limofs_var */
  int cve_make_quads;			/*!< Contructor should make quads */
  SPART *cve_default_graph;		/*!< An expression for the default graph. It is not used in the results ATM because we can generate a mix of triples and quads. */
  int cve_graphs_should_be_set;		/*!< If \c cve_default_graph is NULL and \c cve_graphs_should_be_set is true and a ctor tmpl has no explicit graph then an error should be signalled */
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
spar_compose_retvals_of_ctor (sparp_t *sparp, SPART *ctor_gp, const char *funname, sql_comp_t *sc_for_big_ssl_const, SPART *arg0, SPART *arglast, SPART ***retvals, ctor_var_enumerator_t *cve,
  const char *formatter, const char *agg_formatter, const char *agg_mdata, int use_limits )
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
  if (NULL != sc_for_big_ssl_const)
    {
      dk_set_t list_of_triples = NULL;
      caddr_t **ssl_consts_ptr = &(sc_for_big_ssl_const->sc_big_ssl_consts);
      int ssl_count = BOX_ELEMENTS_0 (ssl_consts_ptr[0]);
      for (triple_ctr = BOX_ELEMENTS_INT (ctor_gp->_.gp.members); triple_ctr--; /* no step */)
        {
          SPART *triple = ctor_gp->_.gp.members[triple_ctr];
          SPART *g = triple->_.triple.tr_fields[SPART_TRIPLE_GRAPH_IDX];
          int g_is_default = !cve->cve_make_quads || SPART_IS_DEFAULT_GRAPH_BLANK (g);
          caddr_t *args;
          if (g_is_default && cve->cve_graphs_should_be_set && (NULL == cve->cve_default_graph))
            spar_error (sparp, "The default target graph is not specified and constructor template has some triple without GRAPH ... {...} aroud it");
          args = (g_is_default ?
            (caddr_t *)list (6,
              (ptrlong)CTOR_OPCODE_CONST_OR_EXPN, NULL,
              (ptrlong)CTOR_OPCODE_CONST_OR_EXPN, NULL,
              (ptrlong)CTOR_OPCODE_CONST_OR_EXPN, NULL ) :
            (caddr_t *)list (8,
              (ptrlong)CTOR_OPCODE_CONST_OR_EXPN, NULL,
              (ptrlong)CTOR_OPCODE_CONST_OR_EXPN, NULL,
              (ptrlong)CTOR_OPCODE_CONST_OR_EXPN, NULL,
              (ptrlong)CTOR_OPCODE_CONST_OR_EXPN, NULL ) );
          for (fld_ctr = g_is_default ? 1 : 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
            {
              SPART *fld = triple->_.triple.tr_fields[fld_ctr];
              ptrlong fld_type = SPART_TYPE(fld);
              caddr_t val;
              int arg_ofs = ((fld_ctr + SPART_TRIPLE_FIELDS_COUNT - 1) % SPART_TRIPLE_FIELDS_COUNT) * 2;
              ptrlong *opcode_arg_ptr = (ptrlong *)(args + arg_ofs);
              caddr_t *val_arg_ptr = args + arg_ofs + 1;
              switch (fld_type)
                {
                case SPAR_BLANK_NODE_LABEL:
                  if (cve->cve_bnodes_are_prohibited)
                    spar_error (sparp, "Blank nodes are not allowed in DELETE constructor patterns");
                  var_ctr = bnode_count;
                  for (bnode_iter = bnodes_acc; NULL != bnode_iter; bnode_iter = bnode_iter->next)
                    {
                      SPART *old_bnode = (SPART *)(bnode_iter->data);
                      var_ctr--;
                      if (!strcmp (fld->_.var.vname, old_bnode->_.var.vname))
                        goto bnode_found_or_added_for_big_ssl; /* see below */
                    }
                  t_set_push (&bnodes_acc, fld);
                  var_ctr = bnode_count++;
bnode_found_or_added_for_big_ssl:
                  opcode_arg_ptr[0] = CTOR_OPCODE_BNODE;
                  val_arg_ptr[0] = box_num (var_ctr);
                  break;
                case SPAR_LIT:
                  if ((NULL != fld->_.lit.datatype) || (NULL != fld->_.lit.language))
                    val = list (3, box_copy (fld->_.lit.val), box_copy (fld->_.lit.datatype), box_copy (fld->_.lit.language));
                  else
                    val = box_copy (fld->_.qname.val);
                  val_arg_ptr[0] = val;
                  break;
                case SPAR_QNAME:
                  val = box_copy (fld->_.qname.val);
                  if (DV_STRING == DV_TYPE_OF (val))
                    box_flags (val) = BF_IRI;
                  val_arg_ptr[0] = val;
                  break;
                default: spar_internal_error (sparp, "Non-const in big ssl const mode constructor pattern");
                }
            }
          dk_set_push (&list_of_triples, args);
        }
      if (NULL == ssl_consts_ptr[0])
        ssl_consts_ptr[0] = (caddr_t *)list (1, NULL);
      else
        {
          caddr_t *new_consts = (caddr_t *)dk_alloc_box ((ssl_count + 1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
          memcpy (new_consts, ssl_consts_ptr[0], ssl_count * sizeof (caddr_t));
          dk_free_box ((caddr_t)(ssl_consts_ptr[0]));
          ssl_consts_ptr[0] = new_consts;
        }
      ssl_consts_ptr[0][ssl_count] = (caddr_t)list_to_array (list_of_triples);
      arg1 = spar_make_funcall (sparp, 0, "bif:vector", (SPART **)t_list (0));
      arg3 = spar_make_funcall (sparp, 0, "bif:__ssl_const", (SPART **)t_list (1, t_box_num_nonull (ssl_count)));
      goto args_ready; /* see below */
    }
  for (triple_ctr = BOX_ELEMENTS_INT (ctor_gp->_.gp.members); triple_ctr--; /* no step */)
    {
      SPART *triple = ctor_gp->_.gp.members[triple_ctr];
      SPART *g = triple->_.triple.tr_fields[SPART_TRIPLE_GRAPH_IDX];
      int g_is_default = !cve->cve_make_quads || SPART_IS_DEFAULT_GRAPH_BLANK (g);
      SPART **tvector_args;
      SPART *tvector_call;
      int triple_is_const = 1;
      tvector_args = (g_is_default ?
        (SPART **)t_list (6, NULL, NULL, NULL, NULL, NULL, NULL) :
        (SPART **)t_list (8, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL) );
#if 0
      tvector_call = spar_make_funcall (sparp, 0, ((NULL == formatter) ? "LONG::bif:vector" :  "bif:vector"), tvector_args);
#else /* LONG::bif:vector is needed always, otherwise construct with constant "string"@lang may become plain "string" in a formatted output */
      tvector_call = spar_make_funcall (sparp, 0, "LONG::bif:vector", tvector_args);
#endif
      for (fld_ctr = g_is_default ? 1 : 0; fld_ctr < SPART_TRIPLE_FIELDS_COUNT; fld_ctr++)
        {
          SPART *fld = triple->_.triple.tr_fields[fld_ctr];
          ptrlong fld_type = SPART_TYPE(fld);
          int arg_ofs = ((fld_ctr + SPART_TRIPLE_FIELDS_COUNT - 1) % SPART_TRIPLE_FIELDS_COUNT) * 2;
          caddr_t *opcode_arg_ptr = (caddr_t *)(tvector_args + arg_ofs);
          SPART **val_arg_ptr = tvector_args + arg_ofs + 1;
          switch (fld_type)
            {
            case SPAR_VARIABLE:
              if (SPART_VARNAME_IS_GLOB (fld->_.var.vname))
                {
                  tvector_args [(fld_ctr-1)*2] = (SPART *)t_box_num_nonull (CTOR_OPCODE_CONST_OR_EXPN);
                  tvector_args [(fld_ctr-1)*2 + 1] = fld;
                  break;
                }
              var_ctr = spar_cve_find_or_add_variable (sparp, cve, fld);
              opcode_arg_ptr[0] = t_box_num_nonull (CTOR_OPCODE_VARIABLE);
              val_arg_ptr[0] = (SPART *)t_box_num_nonull (var_ctr);
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
                    goto bnode_found_or_added; /* see below */
                }
              t_set_push (&bnodes_acc, fld);
              var_ctr = bnode_count++;
bnode_found_or_added:
              opcode_arg_ptr[0] = t_box_num_nonull (CTOR_OPCODE_BNODE);
              val_arg_ptr[0] = (SPART *)t_box_num_nonull (var_ctr);
              triple_is_const = 0;
              break;
            case SPAR_LIT: case SPAR_QNAME:
              opcode_arg_ptr[0] = t_box_num_nonull (CTOR_OPCODE_CONST_OR_EXPN);
              val_arg_ptr[0] = fld;
            default:
              {
                int old_total_vars_count = cve->cve_total_vars_count;
                sparp_gp_trav (sparp, fld, cve, NULL, NULL, sparp_gp_trav_ctor_var_to_limofs_aref, NULL, NULL, NULL);
                opcode_arg_ptr[0] = t_box_num_nonull (CTOR_OPCODE_CONST_OR_EXPN);
                val_arg_ptr[0] = fld;
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
  arg1 = spar_make_funcall (sparp, 0, "bif:vector", (SPART **)t_list_to_array (var_tvectors));
  arg3 = spar_make_funcall (sparp, 0, "bif:vector", (SPART **)t_list_to_array (const_tvectors));

args_ready:
  var_vector_expn = spar_make_funcall (sparp, 0, ((NULL == formatter) ? "LONG::bif:vector" :  "bif:vector"),
    (SPART **)t_revlist_to_array (cve->cve_dist_vars_acc) );
  if (cve->cve_limofs_var)
    var_vector_arg = cve->cve_limofs_var;
  else
    var_vector_arg = var_vector_expn;
  if (NULL != arglast)
    ctor_call = spar_make_funcall (sparp, 1, funname,
      (SPART **)t_list (5, arg0, arg1, var_vector_arg, arg3, arglast) );
  else if (NULL != arg0)
    ctor_call = spar_make_funcall (sparp, 1, funname,
      (SPART **)t_list (4, arg0, arg1, var_vector_arg, arg3) );
  else
    ctor_call = spar_make_funcall (sparp, 1, funname,
      /* Names arg1 and arg3 become slightly misleading when arg0 is not provided, e.g., in case of SPARQL_CONSTRUCT */
      (SPART **)t_list (4, arg1, var_vector_arg, arg3, t_box_num_nonull (use_limits)) );
  if (cve->cve_limofs_var_alias)
    {
      SPART *alias = spartlist (sparp, 5, SPAR_ALIAS, var_vector_expn, cve->cve_limofs_var_alias, SSG_VALMODE_AUTO, (ptrlong)0);
      retvals[0] = (SPART **)t_list (2, ctor_call, alias);
    }
  else
    {
      retvals[0] = (SPART **)t_list (1, ctor_call);
    }
}

void
spar_compose_retvals_of_construct (sparp_t *sparp, SPART *top, SPART *ctor_gp,
  const char *formatter, const char *agg_formatter, const char *agg_mdata )
{
  int use_limits = 0;
  int need_limofs_trick = CTOR_NEEDS_LIMOFS_TRICK(top);
  SPART *multigraph = sparp_get_option (sparp, ctor_gp->_.gp.options, QUAD_L);
  int g_may_vary = (NULL != multigraph);
  ctor_var_enumerator_t cve;
  memset (&cve, 0, sizeof (ctor_var_enumerator_t));
  if (!g_may_vary && (0 < BOX_ELEMENTS (ctor_gp->_.gp.members)))
    {
      SPART *g = ctor_gp->_.gp.members[0]->_.triple.tr_graph;
      if (!SPART_IS_DEFAULT_GRAPH_BLANK (g))
        g_may_vary = 1;
    }
  if (need_limofs_trick)
    {
      caddr_t limofs_name = t_box_dv_short_string (":\"limofs\".\"ctor-1\"");
      cve.cve_limofs_var = spar_make_variable (sparp, limofs_name);
      cve.cve_limofs_var_alias = t_box_dv_short_string ("ctor-1");
    }
  if ((NULL == sparp->sparp_env->spare_storage_name) ||
    ('\0' != sparp->sparp_env->spare_storage_name) )
    use_limits = 1;
  cve.cve_make_quads = g_may_vary;
  cve.cve_default_graph = NULL;
  spar_compose_retvals_of_ctor (sparp, ctor_gp, "sql:SPARQL_CONSTRUCT", NULL /* no big ssl const */, NULL, NULL,
    &(top->_.req_top.retvals), &cve, formatter, agg_formatter, agg_mdata, use_limits );

}

SPART *
spar_simplify_graph_to_patch (sparp_t *sparp, SPART *g)
{
  if (SPAR_GRAPH == SPART_TYPE (g))
    {
      if ((SPART_GRAPH_NOT_FROM == g->_.graph.subtype) || (SPART_GRAPH_NOT_NAMED == g->_.graph.subtype))
        spar_internal_error (sparp, "NOT FROM and NOT FROM NAMED are not fully supported by SPARUL operations, sorry");
      if (SPAR_QNAME == SPART_TYPE (g->_.graph.expn))
        return (SPART *)(g->_.graph.iri);
      return g->_.graph.expn;
    }
  if (SPAR_QNAME == SPART_TYPE (g))
    return (SPART *)(g->_.qname.val);
  return g;
}

int
spar_find_sc_for_big_ssl_const (sparp_t *sparp, sql_comp_t **sc_ret)
{
  if (sparp->sparp_disable_big_const)
    {
      sc_ret[0] = NULL;
      return 0;
    }
  sc_ret[0] = sparp->sparp_sparqre->sparqre_super_sc;
  if (NULL == sc_ret[0])
    {
      spar_error (sparp, "The query can be compiled and executed but not translated to an accurate SQL text, add 'define sql:big-data-const 0' for workaround");
    }
  else
    {
      while (NULL != sc_ret[0]->sc_super)
        sc_ret[0]->sc_super = sc_ret[0]->sc_super;
    }
  return 1;
}

void
spar_compose_retvals_of_insert_or_delete (sparp_t *sparp, SPART *top, SPART *graph_to_patch, SPART *ctor_gp)
{
  int need_limofs_trick = CTOR_NEEDS_LIMOFS_TRICK(top);
  int top_subtype = top->_.req_top.subtype;
  int top_subtype_is_insert = ((INSERT_L == top_subtype) || (SPARUL_INSERT_DATA == top_subtype));
  int big_ssl_const_mode = ((SPARUL_INSERT_DATA == top_subtype) || (SPARUL_DELETE_DATA == top_subtype));
  SPART *multigraph = sparp_get_option (sparp, ctor_gp->_.gp.options, QUAD_L);
  const char *top_fname;
  caddr_t log_mode;
  SPART **rv;
  ctor_var_enumerator_t cve;
  sql_comp_t *sc_for_big_ssl_const = NULL;
  if ((NULL == multigraph) && (0 != BOX_ELEMENTS_0 (ctor_gp->_.gp.members)))
    {
      SPART *first_tmpl = ctor_gp->_.gp.members[0];
      if (!SPART_IS_DEFAULT_GRAPH_BLANK (first_tmpl->_.triple.tr_graph))
        graph_to_patch = first_tmpl->_.triple.tr_graph;
    }
  graph_to_patch = spar_simplify_graph_to_patch (sparp, graph_to_patch);
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
  if (big_ssl_const_mode)
    big_ssl_const_mode = spar_find_sc_for_big_ssl_const (sparp, &sc_for_big_ssl_const);
  if ((INSERT_L != top->_.req_top.subtype) && (SPARUL_INSERT_DATA != top->_.req_top.subtype))
    cve.cve_bnodes_are_prohibited = 1;
  cve.cve_make_quads = ((NULL != multigraph) ? 1 : 0);
  cve.cve_default_graph = graph_to_patch;
  cve.cve_graphs_should_be_set = 1;
  spar_compose_retvals_of_ctor (sparp, ctor_gp, "sql:SPARQL_CONSTRUCT", sc_for_big_ssl_const, NULL, NULL,
    &(top->_.req_top.retvals), &cve, NULL, NULL, NULL, 0 );
  rv = top->_.req_top.retvals;
  if (NULL == graph_to_patch)
    graph_to_patch = uname_virtrdf_ns_uri_DefaultSparul11Target;
  if (NULL != sparp->sparp_env->spare_output_route_name)
    {
      top_fname = t_box_sprintf (200, "sql:SPARQL_ROUTE_DICT_CONTENT_%.100s", sparp->sparp_env->spare_output_route_name);
      rv[0] = spar_make_funcall (sparp, 0, top_fname,
        (SPART **)t_list (11, graph_to_patch,
          t_box_dv_short_string ((NULL != multigraph) ? (top_subtype_is_insert ? "INSERT_QUAD" : "DELETE_QUAD") : (top_subtype_is_insert ? "INSERT" : "DELETE")),
          ((NULL == sparp->sparp_env->spare_storage_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_storage_name),
          ((NULL == sparp->sparp_env->spare_output_storage_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_output_storage_name),
          ((NULL == sparp->sparp_env->spare_output_format_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_output_format_name),
          ((INSERT_L == top->_.req_top.subtype) ? t_NEW_DB_NULL : (caddr_t)(rv[0])),
          ((INSERT_L == top->_.req_top.subtype) ? (caddr_t)(rv[0]) : t_NEW_DB_NULL),
          t_NEW_DB_NULL,
          spar_exec_uid_and_gs_cbk (sparp), log_mode, spar_compose_report_flag (sparp) ) );
    }
  else
    {
      top_fname = ((NULL != multigraph) ?
        (top_subtype_is_insert ? "sql:SPARQL_INSERT_QUAD_DICT_CONTENT" : "sql:SPARQL_DELETE_QUAD_DICT_CONTENT") :
        (top_subtype_is_insert ? "sql:SPARQL_INSERT_DICT_CONTENT" : "sql:SPARQL_DELETE_DICT_CONTENT") );
      rv[0] = spar_make_funcall (sparp, 0, top_fname,
        (SPART **)t_list (5, graph_to_patch, rv[0],
          spar_exec_uid_and_gs_cbk (sparp), log_mode, spar_compose_report_flag (sparp) ) );
    }
}

void
spar_compose_retvals_of_modify (sparp_t *sparp, SPART *top, SPART *graph_to_patch, SPART *del_ctor_gp, SPART *ins_ctor_gp)
{
  int need_limofs_trick;
  SPART *del_multigraph = sparp_get_option (sparp, del_ctor_gp->_.gp.options, QUAD_L);
  SPART *ins_multigraph = sparp_get_option (sparp, ins_ctor_gp->_.gp.options, QUAD_L);
  SPART *del_graph_to_patch = graph_to_patch;
  SPART *ins_graph_to_patch = graph_to_patch;
  int g_may_vary = ((NULL != del_multigraph) || (NULL != ins_multigraph));
  caddr_t log_mode;
  SPART **ins = NULL;
  SPART **rv;
  ctor_var_enumerator_t cve;
  if ((NULL == del_multigraph) && (0 != BOX_ELEMENTS_0 (del_ctor_gp->_.gp.members)))
    {
      SPART *first_tmpl = del_ctor_gp->_.gp.members[0];
      if (!SPART_IS_DEFAULT_GRAPH_BLANK (first_tmpl->_.triple.tr_graph))
        del_graph_to_patch = first_tmpl->_.triple.tr_graph;
    }
  del_graph_to_patch = spar_simplify_graph_to_patch (sparp, del_graph_to_patch);
  if ((NULL == ins_multigraph) && (0 != BOX_ELEMENTS_0 (ins_ctor_gp->_.gp.members)))
    {
      SPART *first_tmpl = ins_ctor_gp->_.gp.members[0];
      if (!SPART_IS_DEFAULT_GRAPH_BLANK (first_tmpl->_.triple.tr_graph))
        ins_graph_to_patch = first_tmpl->_.triple.tr_graph;
    }
  ins_graph_to_patch = spar_simplify_graph_to_patch (sparp, ins_graph_to_patch);
  if (DV_STRINGP (del_graph_to_patch) && DV_STRINGP (ins_graph_to_patch)
    && !strcmp ((caddr_t)del_graph_to_patch, (caddr_t)ins_graph_to_patch) )
    {
      graph_to_patch = del_graph_to_patch;
    }
  else
    g_may_vary = 1;
  graph_to_patch = spar_simplify_graph_to_patch (sparp, graph_to_patch);
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
  cve.cve_make_quads = g_may_vary;
  cve.cve_default_graph = graph_to_patch;
  spar_compose_retvals_of_ctor (sparp, del_ctor_gp, "sql:SPARQL_CONSTRUCT", NULL /* no big ssl const */, NULL, NULL,
    &(top->_.req_top.retvals), &cve, NULL, NULL, NULL, 0 );
  cve.cve_limofs_var_alias = NULL;
  cve.cve_bnodes_are_prohibited = 0;
  spar_compose_retvals_of_ctor (sparp, ins_ctor_gp, "sql:SPARQL_CONSTRUCT", NULL /* no big ssl const */, NULL, NULL,
    &ins, &cve, NULL, NULL, NULL, 0 );
  rv = top->_.req_top.retvals;

  if (NULL != sparp->sparp_env->spare_output_route_name)
    rv[0] = spar_make_funcall (sparp, 0,
      t_box_sprintf (200, "sql:SPARQL_ROUTE_DICT_CONTENT_%.100s", sparp->sparp_env->spare_output_route_name),
      (SPART **)t_list (11, graph_to_patch,
        t_box_dv_short_string (g_may_vary ? "MODIFY" : "MODIFY_QUAD"),
        ((NULL == sparp->sparp_env->spare_storage_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_storage_name),
        ((NULL == sparp->sparp_env->spare_output_storage_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_output_storage_name),
        ((NULL == sparp->sparp_env->spare_output_format_name) ? t_NEW_DB_NULL : sparp->sparp_env->spare_output_format_name),
        rv[0], ins[0],
        t_NEW_DB_NULL,
        spar_exec_uid_and_gs_cbk (sparp), log_mode, spar_compose_report_flag (sparp) ) );
  else
    rv[0] = spar_make_funcall (sparp, 0, (g_may_vary ? "sql:SPARQL_MODIFY_BY_QUAD_DICT_CONTENTS" : "sql:SPARQL_MODIFY_BY_DICT_CONTENTS"),
      (SPART **)t_list (6, graph_to_patch, rv[0], ins[0],
        spar_exec_uid_and_gs_cbk (sparp), log_mode, spar_compose_report_flag (sparp) ) );
}

void
spar_compose_ctor_triples_from_where_gp (sparp_t *sparp, SPART *gp, SPART *g, dk_set_t *ret_tmpls)
{
  int memb_ctr;
  if (SPAR_GP != SPART_TYPE (gp))
    spar_error (sparp, "Cannot convert a pattern into constructor template, DELETE WHERE wors only for simple quad templates");
  if ((0 != gp->_.gp.subtype) && (WHERE_L != gp->_.gp.subtype) && (OPTIONAL_L != gp->_.gp.subtype))
    spar_error (sparp, "DELETE WHERE wors only for simple quad templates, only basic group patterns and OPTIONAL are allowed");
  /*if (0 != BOX_ELEMENTS_0 (gp->_.gp.filters))
    spar_error (sparp, "DELETE WHERE does not support FILTER");*/
  DO_BOX_FAST (SPART *, memb, memb_ctr, gp->_.gp.members)
    {
      SPART *tmpl;
      if (SPAR_TRIPLE != SPART_TYPE (memb))
        {
          spar_compose_ctor_triples_from_where_gp (sparp, memb, g, ret_tmpls);
          continue;
        }
      if (0 < BOX_ELEMENTS_0 (memb->_.triple.options))
        spar_error (sparp, "DELETE WHERE does not support OPTION () clauses of triples and related features, such as transitivity");
      if (SPART_IS_DEFAULT_GRAPH_BLANK (memb->_.triple.tr_graph) && (NULL == g))
        spar_error (sparp, "DELETE WHERE requires default graph but it is not provided");
      tmpl = sparp_tree_full_copy (sparp, memb, gp);
      t_set_push (ret_tmpls, tmpl);
    }
  END_DO_BOX_FAST;
}

void
spar_compose_retvals_of_delete_from_wm (sparp_t *sparp, SPART *tree, SPART *graph_to_patch)
{
  SPART *gtp = spar_simplify_graph_to_patch (sparp, graph_to_patch);
  SPART *pat = tree->_.req_top.pattern;
  SPART *tmpl_gp;
  dk_set_t tmpls = NULL;
  caddr_t prev_fixed_graph = NULL;
  int g_grp_count = 0;
  spar_compose_ctor_triples_from_where_gp (sparp, pat, gtp, &tmpls);
  DO_SET (SPART *, triple, &tmpls)
    {
      SPART *g = triple->_.triple.tr_graph;
      if (SPART_IS_DEFAULT_GRAPH_BLANK (g))
        g = gtp;
      if ((SPAR_LIT != SPART_TYPE (g)) && (SPAR_QNAME != SPART_TYPE (g)))
        g_grp_count++;
      else
        {
          caddr_t g_val = SPAR_LIT_OR_QNAME_VAL (g);
          if ((DV_STRING == DV_TYPE_OF (g_val)) || (DV_UNAME == DV_TYPE_OF (g_val)))
            {
              if ((NULL == prev_fixed_graph) || strcmp (prev_fixed_graph, g_val))
                g_grp_count++;
              prev_fixed_graph = g_val;
            }
          else
            g_grp_count++;
        }
    }
  END_DO_SET()
  tmpl_gp = (SPART *)(t_box_copy ((caddr_t)pat)); /* Dirty hack here, indeed, however we need only a box with type and proper length, nothing else */
  tmpl_gp->_.gp.members = (SPART **)t_revlist_to_array (tmpls);
  tmpl_gp->_.gp.options = NULL;
  if (1 < g_grp_count)
    tmpl_gp->_.gp.options = (SPART **)t_list (2, (SPART *)((ptrlong)QUAD_L), t_box_num_nonull (g_grp_count));
  spar_compose_retvals_of_insert_or_delete (sparp, tree, graph_to_patch, tmpl_gp);
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
#ifdef DEBUG
          bnode_emulation = (SPART *)box_copy_tree ((caddr_t)spartlist (sparp, 8 + (sizeof (rdf_val_range_t) / sizeof (caddr_t)), SPAR_BLANK_NODE_LABEL,
            NULL, NULL, NULL, NULL, NULL, SPART_RVR_LIST_OF_NULLS, (ptrlong)(0x0), NULL ) );
#else
          bnode_emulation = box_copy_tree (spartlist (sparp, 1, SPAR_BLANK_NODE_LABEL));
#endif
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
      spar_internal_error (sparp, "spar_" "tr_fields_are_similar(): unsupported type");
    }
  return 0; /* to keep compiler happy */
}

SPART *
spar_dealias (sparp_t *sparp, SPART *expn, int expected_type)
{
  if (SPAR_ALIAS == SPART_TYPE (expn))
    expn = expn->_.alias.arg;
  if ((expected_type > 0) && (expected_type != SPART_TYPE (expn)))
    spar_internal_error (sparp, "spar_" "deailas(): unexpected type of expression");
  return expn;
}

int
spar_optimize_delete_of_single_triple_pattern (sparp_t *sparp, SPART *top)
{
  SPART *triple;
  SPART *emu;
  SPART **known_vars;
  SPART **retvals = top->_.req_top.retvals;
  int retvals_count = BOX_ELEMENTS (retvals);
  SPART **var_triples, **args;
  SPART *arg0, *graph_expn, *ctor, *uid_expn, *log_mode_expn, *good_ctor_call /* unused?? *compose_report_expn */;
  if (NULL != sparp->sparp_env->spare_output_route_name)
    return 0; /* If an output may go outside the default storage then there's no way of avoiding the complete filling of the result dictionary */
  triple = spar_find_single_physical_triple_pattern (sparp, top->_.req_top.pattern);
  if (NULL == triple)
    return 0; /* nontrivial pattern, can not be optimized this way */
  arg0 = spar_dealias (sparp, retvals[0], SPAR_FUNCALL);
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (arg0)) && (5 == BOX_ELEMENTS (arg0->_.funcall.argtrees)));
  if (strcmp ("sql:SPARQL_DELETE_DICT_CONTENT", arg0->_.funcall.qname))
    return 0;
  graph_expn		= arg0->_.funcall.argtrees[0];
  ctor			= arg0->_.funcall.argtrees[1];
  uid_expn		= arg0->_.funcall.argtrees[2];
  log_mode_expn		= arg0->_.funcall.argtrees[3];
  /* unused?? compose_report_expn	= arg0->_.funcall.argtrees[4]; */
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (ctor)) && (4 == BOX_ELEMENTS (ctor->_.funcall.argtrees)));
  dbg_assert (DELETE_L == top->_.req_top.subtype);
  var_triples = ctor->_.funcall.argtrees[0]->_.funcall.argtrees;
  if (1 < retvals_count)
    {
      SPART *known_vars_vector = spar_dealias (sparp, retvals [retvals_count-1], SPAR_FUNCALL);
      known_vars = known_vars_vector->_.funcall.argtrees;
    }
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
      triple->_.triple.tr_fields[SPART_TRIPLE_GRAPH_IDX] ) )
    return 0;
  emu = spar_emulate_ctor_field (sparp, args[0], args[1], known_vars);
  if (!spar_tr_fields_are_similar (sparp, emu,
      triple->_.triple.tr_fields[SPART_TRIPLE_SUBJECT_IDX] ) )
    return 0;
  emu = spar_emulate_ctor_field (sparp, args[2], args[3], known_vars);
  if (!spar_tr_fields_are_similar (sparp, emu,
      triple->_.triple.tr_fields[SPART_TRIPLE_PREDICATE_IDX] ) )
    return 0;
  emu = spar_emulate_ctor_field (sparp, args[4], args[5], known_vars);
  if (!spar_tr_fields_are_similar (sparp, emu,
      triple->_.triple.tr_fields[SPART_TRIPLE_OBJECT_IDX] ) )
    return 0;
  good_ctor_call = spar_make_funcall (sparp, 1, "sql:SPARQL_DELETE_CTOR",
    (SPART **)t_list (5,
      graph_expn,
      spar_make_funcall (sparp, 0, "bif:vector", var_triples),
      ctor->_.funcall.argtrees[1],
      uid_expn, log_mode_expn ) );
  ctor->_.funcall.argtrees[0] = spar_make_funcall (sparp, 0, "bif:vector",
        (SPART **)t_list (0) );
  retvals[0]->_.funcall.argtrees[0] = good_ctor_call;
  return 1;
}

void
spar_optimize_retvals_of_insert_or_delete (sparp_t *sparp, SPART *top)
{
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
  SPART *arg0, *graph_expn, *ctor, *uid_expn, *log_mode_expn, *good_ctor_call /* unused?? *compose_report_expn */;
  if (NULL != sparp->sparp_env->spare_output_route_name)
    return; /* If an output may go outside the default storage then there's no way of avoiding the complete filling of the result dictionary */
  arg0 = spar_dealias (sparp, retvals[0], SPAR_FUNCALL);
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (arg0)) && (5 == BOX_ELEMENTS (arg0->_.funcall.argtrees)));
  if (strcmp ("sql:SPARQL_INSERT_DICT_CONTENT", arg0->_.funcall.qname) && strcmp ("sql:SPARQL_DELETE_DICT_CONTENT", arg0->_.funcall.qname))
    return;
  graph_expn		= arg0->_.funcall.argtrees[0];
  ctor			= arg0->_.funcall.argtrees[1];
  uid_expn		= arg0->_.funcall.argtrees[2];
  log_mode_expn		= arg0->_.funcall.argtrees[3];
  /* unused?? compose_report_expn	= arg0->_.funcall.argtrees[4]; */
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (ctor)) && (4 == BOX_ELEMENTS (ctor->_.funcall.argtrees)));
  var_triples = ctor->_.funcall.argtrees[0]->_.funcall.argtrees;
  all_triple_count = bad_triple_count = BOX_ELEMENTS (var_triples);
  if (1 < retvals_count)
    {
      SPART *known_vars_vector = spar_dealias (sparp, retvals [retvals_count-1], SPAR_FUNCALL);
      known_vars = known_vars_vector->_.funcall.argtrees;
    }
  else
    known_vars = ctor->_.funcall.argtrees[1]->_.funcall.argtrees;
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
  good_ctor_call = spar_make_funcall (sparp, 1, fname,
    (SPART **)t_list (5,
      spar_make_funcall (sparp, 0,
        ((NULL == sparp->sparp_gs_app_callback) ? "SPECIAL::bif:__rgs_assert" :  "SPECIAL::bif:__rgs_assert_cbk"),
        (SPART **)t_list (4, graph_expn, uid_expn, (ptrlong)3,
          t_box_dv_short_string ((INSERT_L == top->_.req_top.subtype) ? "SPARUL INSERT" : "SPARUL DELETE") ) ),
      spar_make_funcall (sparp, 0, "bif:vector",
        (SPART **)t_list_to_array (good_triples) ),
      ctor->_.funcall.argtrees[1],
      uid_expn, log_mode_expn ) );
  ctor->_.funcall.argtrees[0] = spar_make_funcall (sparp, 0, "bif:vector",
        (SPART **)t_list_to_array (bad_triples) );
  retvals[0]->_.funcall.argtrees[0] = good_ctor_call;
}

void
spar_optimize_retvals_of_modify (sparp_t *sparp, SPART *top)
{
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
  SPART *arg0, *graph_expn, *del_ctor, *ins_ctor, *uid_expn, *log_mode_expn, *good_ctor_call /* unused?? *compose_report_expn */;
  if (NULL != sparp->sparp_env->spare_output_route_name)
    return; /* If an output may go outside the default storage then there's no way of avoiding the complete filling of the result dictionary */
  arg0 = spar_dealias (sparp, retvals[0], SPAR_FUNCALL);
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (arg0)) && (6 == BOX_ELEMENTS (arg0->_.funcall.argtrees)));
  if (strcmp ("sql:SPARQL_MODIFY_BY_DICT_CONTENT", arg0->_.funcall.qname))
    return;
  graph_expn		= arg0->_.funcall.argtrees[0];
  del_ctor		= arg0->_.funcall.argtrees[1];
  ins_ctor		= arg0->_.funcall.argtrees[2];
  uid_expn		= arg0->_.funcall.argtrees[3];
  log_mode_expn		= arg0->_.funcall.argtrees[4];
  /* unused?? compose_report_expn	= arg0->_.funcall.argtrees[5]; */
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (del_ctor)) && (4 == BOX_ELEMENTS (del_ctor->_.funcall.argtrees)));
  dbg_assert ((SPAR_FUNCALL == SPART_TYPE (ins_ctor)) && (4 == BOX_ELEMENTS (ins_ctor->_.funcall.argtrees)));
  del_var_triples = del_ctor->_.funcall.argtrees[0]->_.funcall.argtrees;
  ins_var_triples = ins_ctor->_.funcall.argtrees[0]->_.funcall.argtrees;
  del_const_triples = del_ctor->_.funcall.argtrees[2]->_.funcall.argtrees;
  del_const_count = BOX_ELEMENTS (del_const_triples);
  if (1 < retvals_count)
    {
      SPART *known_vars_vector = spar_dealias (sparp, retvals [retvals_count-1], SPAR_FUNCALL);
      known_vars = known_vars_vector->_.funcall.argtrees;
    }
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
  good_ctor_call = spar_make_funcall (sparp, 1, "sql:SPARQL_MODIFY_CTOR",
    (SPART **)t_list (6,
      spar_make_funcall (sparp, 0,
        ((NULL == sparp->sparp_gs_app_callback) ? "SPECIAL::bif:__rgs_assert" :  "SPECIAL::bif:__rgs_assert_cbk"),
        (SPART **)t_list (4, graph_expn, uid_expn, (ptrlong)3,
          t_box_dv_short_string ("SPARUL MODIFY") ) ),
      spar_make_funcall (sparp, 0, "bif:vector",
        (SPART **)t_list_to_array (good_del_triples) ),
      spar_make_funcall (sparp, 0, "bif:vector",
        (SPART **)t_list_to_array (good_ins_triples) ),
      ins_ctor->_.funcall.argtrees[1],
      uid_expn, log_mode_expn ) );
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
