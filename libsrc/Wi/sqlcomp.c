/*
 *  sqlcomp.c
 *
 *  $Id$
 *
 *  Dynamic SQL Compiler
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

#include "sqlnode.h"
#include "sqlcomp.h"
#include "eqlcomp.h"
#include "xmlnode.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "security.h"
#include "sqlpfn.h"
#include "sqlintrp.h"
#include "sqlo.h"



void
sqlc_make_and_list (sql_tree_t * tree, dk_set_t * res)
{
  if (!tree)
    return;
  if (box_tag ((caddr_t) tree) != DV_ARRAY_OF_POINTER)
    return;
  if (tree->type != BOP_AND)
    {
      t_NEW_VARZ (predicate_t, pred);
      pred->pred_text = tree;
      t_set_push (res, (void *) pred);
    }
  else
    {
      sqlc_make_and_list (tree->_.bin_exp.right, res);
      sqlc_make_and_list (tree->_.bin_exp.left, res);
    }
}


int ct_is_entity (sql_comp_t * sc, comp_table_t * ct);
#include "name.c"


comp_table_t *
sqlc_col_table (sql_comp_t * sc, ST * col_ref, dbe_column_t ** col_ret,
    col_ref_rec_t ** crr_ret, int err_if_not)
{
  comp_table_t *ct =
      sqlc_col_table_1 (sc, col_ref, col_ret, crr_ret, err_if_not);
  if (ct && *col_ret)
    {
      if (!sec_tb_check (ct->ct_table, ct->ct_g_id, ct->ct_u_id, GR_SELECT)
	  && !sec_col_check (*col_ret, ct->ct_g_id, ct->ct_u_id, GR_SELECT))
	sqlc_new_error (sc->sc_cc, "42000", "SQ033", "SELECT access denied for column %s of table %s, user ID %lu",
	    (*col_ret)->col_name, ct->ct_table->tb_name, ct->ct_u_id );
    }
  return ct;
}


#define P_NO_MATCH 0
#define P_EXACT 1
#define P_PARTIAL 2


int
sqlc_pref_match (char * crr_pref, char * ref_pref)
{
  size_t ref_len, crr_len;
  if (!crr_pref && !ref_pref)
    return P_EXACT;
  if (!crr_pref)
    return P_NO_MATCH;
  if (!ref_pref)
    return P_PARTIAL;
  crr_len = strlen (crr_pref);
  ref_len = strlen (ref_pref);
  if (ref_len == crr_len && 0 == CASEMODESTRCMP (crr_pref, ref_pref))
    return P_EXACT;
  if (ref_len >= crr_len)
    return P_NO_MATCH;
  if ('.' == crr_pref [(crr_len - ref_len) - 1])
    {
      if (0 == CASEMODESTRCMP (crr_pref + crr_len - ref_len, ref_pref))
	return P_PARTIAL;
    }
  return P_NO_MATCH;
}


col_ref_rec_t *
sqlc_find_crr (sql_comp_t * sc, ST * ref)
{
  /* the first exact match is returned.  If no exact match exists,
   * a partial match is possible if 1. there are no multiple, different partial matches
   * 2. the crr partially matched is a column, not a proc variable (i.e. crr_ct != NULL). */
  col_ref_rec_t * found = NULL;
  int many_found = 0;
  if (ST_COLUMN (ref, COL_DOTTED) && STAR == ref->_.col_ref.name)
    sqlc_new_error (sc->sc_cc, "37000", ".....", " A * is not allowed in a variable's place in an expression");
  DO_SET (col_ref_rec_t *, crr, &sc->sc_col_ref_recs)
    {
      if (ST_COLUMN (crr->crr_col_ref, COL_DOTTED)
	  && ST_COLUMN (ref, COL_DOTTED))
	{
	  if (0 == CASEMODESTRCMP (ref->_.col_ref.name, crr->crr_col_ref->_.col_ref.name))
	    {
	      int p_match = sqlc_pref_match (crr->crr_col_ref->_.col_ref.prefix, ref->_.col_ref.prefix);
	      if (P_EXACT == p_match)
		return crr;
	      if (P_PARTIAL == p_match
		  && crr->crr_ct)
		{
		  if (found && !box_equal ((box_t) found->crr_col_ref, (box_t) ref))
		    {
		      many_found = 1;
		    }
		  if (! found)
		    found = crr;
		}
	    }
	}
      else
	{
	  if (box_equal ((box_t) crr->crr_col_ref, (box_t) ref))
	    return crr;
	}
    }
  END_DO_SET();
  return NULL;
#if 0
  if (many_found)
    sqlc_new_error (sc->sc_cc, "42S22", "SQ034", "Ambiguous column ref %s", ref->_.col_ref.name);
  return found;
#endif
}


col_ref_rec_t *
sqlc_col_ref_rec (sql_comp_t * sc, ST * col_ref, int err_if_not)
{
  col_ref_rec_t *col_crr = NULL;
  col_crr = sqlc_find_crr (sc, col_ref);
  if (col_crr)
    return col_crr;
  if (ST_P (col_ref, FUN_REF))
    sqlc_new_error (sc->sc_cc, "37000", "SQ035",
	"Bad function reference in expression, "
	"only ones in selection recognized in HAVING / ORDER BY");
  {
    dbe_column_t *col;
    comp_table_t *ct = sqlc_col_table (sc, col_ref, &col, &col_crr, err_if_not);
    if (col_crr)
      return (col_crr);
    if (ct)
      {
	t_NEW_VARZ (col_ref_rec_t, cr);
	if (ct->ct_table)
	  {
	    char * prefix = ct->ct_prefix ? ct->ct_prefix : ct->ct_table->tb_name;
	    cr->crr_col_ref = (ST*) t_list (3, COL_DOTTED, t_box_string (prefix), t_box_copy (col_ref->_.col_ref.name));
	    sqlc_temp_tree (sc, (caddr_t) cr->crr_col_ref);
	  }
	else
	  cr->crr_col_ref = col_ref;
	cr->crr_dbe_col = col;
	cr->crr_ct = ct;
	t_set_push (&ct->ct_out_crrs, (void *) cr);
	t_set_push (&sc->sc_col_ref_recs, (void *) cr);
	return cr;
      }
    else
      {
	if (!err_if_not)
	  return NULL;

	sqlc_new_error (sc->sc_cc, "42S22", "SQ036", "Bad column/variable ref %s",
	    col_ref->_.col_ref.name);
      }
  }
  /*NO RETURN */ return NULL;
}


col_ref_rec_t *
sqlc_virtual_col_crr (sql_comp_t * sc, comp_table_t * ct, char * name, dtp_t dtp)
{
  ST * col_ref = (ST *) t_list (3, COL_DOTTED, t_box_copy (ct->ct_prefix), t_box_string (name));
  t_NEW_VARZ (col_ref_rec_t, cr);
  cr->crr_col_ref = col_ref;
  sqlc_temp_tree (sc, (caddr_t) cr->crr_col_ref);
  cr->crr_ssl = sqlc_new_temp (sc, name, dtp);
  cr->crr_ct = ct;
  t_set_push (&ct->ct_out_crrs, (void *) cr);
  t_set_push (&sc->sc_col_ref_recs, (void *) cr);
  return cr;
}


void
sqlc_mark_super_pred_dep (sql_comp_t * sub_sc, col_ref_rec_t * super_cr)
{
  if (sub_sc->sc_predicate && super_cr->crr_ct)
    {
    /* refers a col, not a parameter in an intermediate qr of the call chain */
      t_set_pushnew (&sub_sc->sc_predicate->pred_tables,
	  (void *) super_cr->crr_ct);
    }
}


state_slot_t *
sqlc_col_ref_ssl (sql_comp_t * sc, ST * col_ref)
{
  col_ref_rec_t *cr = sqlc_col_ref_rec (sc, col_ref, 1);
  if (cr->crr_ssl)
    return cr->crr_ssl;
    /* There's a ssl if this is a ref from subq to superq col/param */

  if (!cr->crr_dbe_col)
    SQL_GPF_T1 (sc->sc_cc, "crr without ssl must have col");

  cr->crr_ssl = ssl_new_column (sc->sc_cc,
      (col_ref->_.col_ref.prefix ? col_ref->_.col_ref.prefix : ""),
      cr->crr_dbe_col);
  t_set_push (&cr->crr_ct->ct_out_cols, (void *) cr);
  return (cr->crr_ssl);
}


state_slot_t *
sqlc_col_ref_rec_ssl (sql_comp_t * sc, col_ref_rec_t * cr)
{
  ST *col_ref = cr->crr_col_ref;
  if (cr->crr_ssl)
    return cr->crr_ssl;
    /* There's a ssl if this is a ref from subq to superq col/param */
  cr->crr_ssl = ssl_new_column (sc->sc_cc,
      (col_ref->_.col_ref.prefix ?  col_ref->_.col_ref.prefix : ""),
      cr->crr_dbe_col);
  t_set_push (&cr->crr_ct->ct_out_cols, (void *) cr);
  return (cr->crr_ssl);
}


col_ref_rec_t *
sqlc_col_or_param (sql_comp_t * sc, ST * tree, int is_recursive)
{
  col_ref_rec_t *cr;
  if (!sc->sc_super)
    {
      if (sc->sc_scroll_super)
	{
	  cr = sqlc_col_ref_rec (sc, tree, 0);
	  if (cr)
	    {
	      if (is_recursive)
		sqlc_col_ref_rec_ssl (sc, cr);
	      return cr;
	    }
	  else
	    {
	      char temp[20];
	      int inx = 0, inx_found = -1;
	      col_ref_rec_t *super_cr;
	      t_NEW_VARZ (col_ref_rec_t, cr);
	      cr->crr_col_ref = tree;
	      t_set_push (&sc->sc_col_ref_recs, (void *) cr);
	      super_cr = sqlc_col_or_param (sc->sc_scroll_super, tree, 1);
	      if (ST_COLUMN (tree, COL_DOTTED))
		{
		  DO_SET (ST *, var, sc->sc_scroll_param_cols)
		    {
		      if (!ST_COLUMN (var, COL_DOTTED))
			goto next;
		      if (var->_.col_ref.prefix && tree->_.col_ref.prefix &&
			  strcmp (var->_.col_ref.prefix, tree->_.col_ref.prefix))
			goto next;
		      if (var->_.col_ref.prefix != tree->_.col_ref.prefix)
			goto next;
		      if (!strcmp (var->_.col_ref.name, tree->_.col_ref.name))
			{
			  inx_found = inx;
			  break;
			}
next:
		      inx++;
		    }
		  END_DO_SET ();
		}
	      else
		inx_found = dk_set_position (*sc->sc_scroll_param_cols, tree);
	      if (-1 == inx_found)
		{
		  dk_set_push (sc->sc_scroll_param_cols, tree);
		  inx_found = 0;
		}
	      snprintf (temp, sizeof (temp), ":%d", inx_found);
	      cr->crr_ssl = ssl_new_parameter (sc->sc_cc, temp);
	      return cr;
	    }
	}
      else
	{
	  cr = sqlc_col_ref_rec (sc, tree, 1);
	  if (is_recursive)
	    sqlc_col_ref_rec_ssl (sc, cr);
	  return cr;
	}
    }
  cr = sqlc_col_ref_rec (sc, tree, 0);
  if (cr)
    {
      if (is_recursive)
	sqlc_col_ref_rec_ssl (sc, cr);
      return cr;
    }

  /* Look in the super and make this a param */
  {
    col_ref_rec_t *super_cr;
    t_NEW_VARZ (col_ref_rec_t, cr);
    cr->crr_col_ref = tree;
    t_set_push (&sc->sc_col_ref_recs, (void *) cr);
    super_cr = sqlc_col_or_param (sc->sc_super, tree, 1);
    sqlc_mark_super_pred_dep (sc, super_cr);
    cr->crr_ssl = super_cr->crr_ssl;
    cr->crr_ct = super_cr->crr_ct;
    return cr;
  }
}


state_slot_t *
sqlc_mark_param_ref (sql_comp_t * sc, ST * param)
{
  col_ref_rec_t *cr1 = sqlc_col_ref_rec (sc, param, 0);
  if (cr1)
    return (cr1->crr_ssl);

  if (!sc->sc_super)
    {
      const char *parm_name = SYMBOLP (param) ? (char *) param : "subg-col-ref";
      t_NEW_VARZ (col_ref_rec_t, cr);
      cr->crr_col_ref = param;
      cr->crr_ssl = ssl_new_parameter (sc->sc_cc, parm_name);
      t_set_push (&sc->sc_col_ref_recs, (void *) cr);
      return (cr->crr_ssl);
    }
  else
    {
      state_slot_t *ssl = sqlc_mark_param_ref (sc->sc_super, param);

      t_NEW_VARZ (col_ref_rec_t, cr);
      cr->crr_col_ref = param;
      cr->crr_ssl = ssl;
      t_set_push (&sc->sc_col_ref_recs, (void *) cr);
      return ssl;
    }
}



/* Mark pred dependencies. Push all ct's referenced in tree into
   the pred's table list.
   Also perform scope inference for parameters and column refs to super-queries.
   This will be run on any expressions for scope. The pred is null if
   the expression is not a test */

void
sqlc_mark_pred_deps (sql_comp_t * sc, predicate_t * pred, sql_tree_t * tree)
{
  if (!tree)
    return;
  if (SYMBOLP (tree))
    {
      sqlc_mark_param_ref (sc, tree);
      return;
    }
  if (ST_P (tree, QUOTE))
    return;
  if (ST_COLUMN (tree, COL_DOTTED))
    {
      ST *new_tree = sqlo_udt_check_observer (sc->sc_so, sc, tree);
      if (new_tree != tree)
	sqlc_mark_pred_deps (sc, pred, tree);
      else
	{
	  col_ref_rec_t *cr = sqlc_col_or_param (sc, tree, 0);
	  if (cr->crr_ct)
	    if (pred)
	      t_set_pushnew (&pred->pred_tables, (void *) cr->crr_ct);
	}
    }
  else if (BIN_EXP_P (tree))
    {
      sqlc_mark_pred_deps (sc, pred, tree->_.bin_exp.left);
      sqlc_mark_pred_deps (sc, pred, tree->_.bin_exp.right);
    }
  else if (SUBQ_P (tree))
    {
      sqlc_mark_pred_deps (sc, pred, tree->_.subq.left);
      sqlc_subquery (sc, pred, &(tree->_.subq.subq));
    }
  else if (ST_P (tree, SCALAR_SUBQ))
    {
      /* this is to prevent assignment of value NULL to ssl constant when sql data not found */
      sqlc_union_constants (tree->_.bin_exp.left);
      sqlc_subquery (sc, pred, &(tree->_.bin_exp.left));
    }
  else if (ST_P (tree, CALL_STMT))
    {
      int inx;
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree->_.call.name) && BOX_ELEMENTS (tree->_.call.name) == 1)
	sqlc_mark_pred_deps (sc, pred, ((ST **) tree->_.call.name)[0]);
      DO_BOX (ST *, arg, inx, tree->_.call.params)
	{
	  sqlc_mark_pred_deps (sc, pred, arg);
	}
      END_DO_BOX;
      if (BOX_ELEMENTS (tree) > 3)
	sqlc_mark_pred_deps (sc, pred, tree->_.call.ret_param);
    }
  else if (ST_P (tree, COMMA_EXP)
	   || ST_P (tree, SIMPLE_CASE)
	   || ST_P (tree, SEARCHED_CASE)
	   || ST_P (tree, COALESCE_EXP))
    {
      int inx;
      DO_BOX (ST *, arg, inx, tree->_.comma_exp.exps)
      {
	sqlc_mark_pred_deps (sc, pred, arg);
      }
      END_DO_BOX;
    }
  else if (ST_P (tree, ASG_STMT))
    {
      ST *new_tree = sqlo_udt_check_mutator (sc->sc_so, sc, tree);
      if (new_tree == tree)
	{
	  sqlc_mark_pred_deps (sc, pred, (ST *) tree->_.op.arg_1);
	  sqlc_mark_pred_deps (sc, pred, (ST *) tree->_.op.arg_2);
	}
      else
	sqlc_mark_pred_deps (sc, pred, new_tree);
    }
  else if (ST_P (tree, KWD_PARAM))
    {
      sqlc_mark_pred_deps (sc, pred, (ST *) tree->_.bin_exp.right);
    }
}


int
ts_predicate_p (ptrlong p)
{
  switch (p)
    {
    case BOP_EQ:
    case BOP_NEQ:
    case BOP_LT:
    case BOP_LTE:
    case BOP_GT:
    case BOP_GTE:
    case BOP_LIKE:
      return 1;
    default:
      return 0;
    }
}


int
indexable_predicate_p (int p)
{
  switch (p)
    {
    case BOP_EQ:
    case BOP_LT:
    case BOP_LTE:
    case BOP_GT:
    case BOP_GTE:
      return 1;
    default:
      return 0;
    }
}


ptrlong
cmp_op_inverse (ptrlong op)
{
  switch (op)
    {
    case BOP_LT:
      return BOP_GT;
    case BOP_LTE:
      return BOP_GTE;
    case BOP_GT:
      return BOP_LT;
    case BOP_GTE:
      return BOP_LTE;
    case BOP_EQ:
      return BOP_EQ;
/*    case BOP_LIKE:
      return BOP_LIKE;*/
    default:
      return -1;
    }
}


int
sqlc_table_refd_p (sql_comp_t * sc, sql_tree_t * tree, comp_table_t * ct)
{
  if (!ARRAYP (tree))
    return 0;
  if (ST_COLUMN (tree, COL_DOTTED))
    {
      col_ref_rec_t *c_ref = sqlc_col_ref_rec (sc, tree, 1);
      if (c_ref->crr_ct == ct)
	return 1;
      else
	return 0;
    }
  if (BIN_EXP_P (tree))
    return (sqlc_table_refd_p (sc, tree->_.bin_exp.left, ct)
	|| sqlc_table_refd_p (sc, tree->_.bin_exp.left, ct));
  else if (ST_P (tree, CALL_STMT))
    {
      int inx;
      DO_BOX (ST *, arg, inx, tree->_.call.params)
      {
	if (sqlc_table_refd_p (sc, arg, ct))
	  return 1;
      }
      END_DO_BOX;
      return 0;
    }
  return 1;			/* do not know means yes */
}


int
crr_col_is_searchable (col_ref_rec_t * crr)
{
  if (crr->crr_ct && ST_P (crr->crr_ct->ct_derived, PROC_TABLE))

    return 1; /* if this is a param of a proc table */
  if (!crr->crr_dbe_col)
    return 0;
  return (!IS_BLOB_DTP (crr->crr_dbe_col->col_sqt.sqt_dtp));
}

ST **
sqlc_ancestor_args (ST * tree)
{
  if (ST_P (tree, BOP_NOT)
      && ST_P (tree->_.bin_exp.left, BOP_EQ))
    {
      ST * call = tree->_.bin_exp.left->_.bin_exp.right;
      if (ST_P (call, CALL_STMT)
	  && 0 == stricmp (call->_.call.name, "ancestor_of"))
	return (call->_.call.params);
    }
  return NULL;
}


char
sqlc_contains_fn_to_char (const char *name)
{
  char c1 = name[0];
  if (! ('x' == c1 || 'X' == c1 || 'c' == c1 || 'C' == c1))
    return 0;
  if (0 == stricmp (name, "contains"))
    return 'c';
  else if (0 == stricmp (name, "xcontains"))
    return 'x';
  else if (0 == stricmp (name, "xpath_contains"))
    return 'p';
  else if (0 == stricmp (name, "xquery_contains"))
    return 'q';
  else
    return 0;
}


char
sqlc_geo_fn_to_char (const char *name)
{
  return 0;
}

ST **
sqlc_contains_args (ST * tree, int * contains_type)
{
  int ct = ' ';
  if (ST_P (tree, BOP_NOT)
      && ST_P (tree->_.bin_exp.left, BOP_EQ))
    {
      ST * call = tree->_.bin_exp.left->_.bin_exp.right;
      if (ST_P (call, CALL_STMT))
	{
	  ct = sqlc_contains_fn_to_char (call->_.call.name);
	  if (!ct)
	    return NULL;
	  if (contains_type)
	    *contains_type = ct;
	  return (call->_.call.params);
	}
    }
  return NULL;
}


ST **
sqlc_geo_args (ST * tree, int * contains_type)
{
  int ct = 0;
  if (ST_P (tree, BOP_NOT)
      && ST_P (tree->_.bin_exp.left, BOP_EQ))
    {
      ST * call = tree->_.bin_exp.left->_.bin_exp.right;
      if (ST_P (call, CALL_STMT))
	{
	  ct = sqlc_geo_fn_to_char (call->_.call.name);
	  if (!ct)
	    return NULL;
	  if (contains_type)
	    *contains_type = ct;
	  return (call->_.call.params);
	}
    }
  return NULL;
}


int
ct_is_entity (sql_comp_t * sc, comp_table_t * ct)
{
  return 0;
#if 0
#ifdef BIF_XML
  return (ct->ct_table
	  && sch_is_subkey_incl (sc->sc_cc->cc_schema, ct->ct_table->tb_primary_key->key_id, entity_key_id));
#else
  return 0;
#endif
#endif
}


unsigned char
bop_to_dvc (int op)
{
  switch (op)
    {
    case BOP_LTE:
      return CMP_LTE;
    case BOP_LT:
      return CMP_LT;
    case BOP_GTE:
      return CMP_GTE;
    case BOP_GT:
      return CMP_GT;
    case BOP_EQ:
      return CMP_EQ;
    case BOP_NEQ:
      return CMP_NEQ;
    case BOP_LIKE:
      return CMP_LIKE;
    case BOP_NULL:
      return CMP_NULL;
    default:
      SQL_GPF_T(NULL);			/* Bad BOP predicate */
    }

  /*NOTREACHED*/
  return 0;
}


void
sql_node_append (data_source_t ** head, data_source_t * node)
{
  if (!*head)
    {
      *head = node;
    }
  else
    {
      data_source_t *h = *head;
      while (h->src_continuations)
	{
	  h = (data_source_t *) h->src_continuations->data;
	}
      dk_set_push (&h->src_continuations, (void *) node);
    }
}
