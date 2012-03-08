/*
 *  sqlview.c
 *
 *  $Id$
 *
 *  SQL Compiler, view, derived table, union
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
#include "eqlcomp.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "sqlintrp.h"
#include "arith.h"
#include "sqlo.h"
#include "sqltype.h"


int
sqlc_view_is_updatable (ST * exp)
{
  if (!ST_P (exp, SELECT_STMT) || !exp->_.select_stmt.table_exp)
    return 0;
  else
    {
      ST **from = exp->_.select_stmt.table_exp->_.table_exp.from;
      ptrlong all_distinct = SEL_IS_DISTINCT (exp);
      if (all_distinct || BOX_ELEMENTS (from) != 1)
	return 0;
      if (!ST_P (from[0], TABLE_REF) || !ST_P (from[0]->_.table_ref.table, TABLE_DOTTED))
	return 0;
    }
  return 1;
}


/* expanding an updatable view:

   Substitute all refs to view out cols with the
   exp left of the AS.  A col refers to the view if: 1) it has the same correlation name
   2) it is equal to one of the view AS right sides.

   Each view gets a correlation nam,e _v<n>.  The table is replaced with the
   view's table. The containing expression is traversed and names to the right of AS
   are replaced with the expression to the left.
   In the case of an update there is no correlation name.


   The expansion is: take original exp. Replace col refs referring to view with
   the left side of as. Replace the view name with the table name in the view. Take the where part of the view and
   connect it with an AND to the condition in the containing expression.
 */

ST *
sqlc_strip_as (ST * tree)
{
  while (ST_P (tree, BOP_AS))
    tree = tree->_.as_exp.left;
  return tree;
}


ST *
sqlc_expand_col_ref (sql_comp_t * sc, ST * ref, comp_table_t * view_ct)
{
  ST *view_exp = view_ct->ct_derived;
  ST **selection = (ST **) view_exp->_.select_stmt.selection;
  int inx;
  DO_BOX (ST *, as_exp, inx, selection)
  {
    if (0 == CASEMODESTRCMP ((caddr_t) as_exp->_.as_exp.name,
	(caddr_t) ref->_.col_ref.name))
      {
	return ((ST *) t_box_copy_tree ((caddr_t) sqlc_strip_as (as_exp->_.as_exp.left)));
      }
  }
  END_DO_BOX;
  return ref;
}


void
sqlc_alias_non_view_ref (sql_comp_t * sc, ST * ref, col_ref_rec_t * crr,
    dk_set_t * aliases)
{
  static int alias_ctr;
  state_slot_t *ssl = sqlc_col_ref_rec_ssl (sc, crr);
  DO_SET (col_ref_rec_t *, alias, aliases)
  {
    if (alias->crr_ssl == ssl)
      {
	/*dk_free_tree (ref->_.col_ref.name);
	dk_free_tree (ref->_.col_ref.prefix);*/
	ref->_.col_ref.name =
	    t_box_copy_tree (alias->crr_col_ref->_.col_ref.name);
	ref->_.col_ref.prefix =
	    t_box_copy_tree (alias->crr_col_ref->_.col_ref.prefix);
	return;
      }
  }
  END_DO_SET ();
  {
    char temp[20];
    t_NEW_VARZ (col_ref_rec_t, alias);
    t_set_push (aliases, (void *) alias);
    snprintf (temp, sizeof (temp), "_a%d", alias_ctr++);
    alias->crr_col_ref = (ST *) t_list (3, COL_DOTTED, NULL, t_box_string (temp));
/*    dk_free_box (ref->_.col_ref.name);
    dk_free_box (ref->_.col_ref.prefix);*/
    ref->_.col_ref.name = t_box_string (temp);
    ref->_.col_ref.prefix = NULL;
    alias->crr_ssl = crr->crr_ssl;
    alias->crr_ct = crr->crr_ct;
  }
}


void
sqlc_alias_update_non_view_ref (sql_comp_t * sc, ST ** ref_place,
    dk_set_t * aliases)
{
  ST *ref = *ref_place;
  static int alias_ctr;
  state_slot_t *ssl = sqlc_col_ref_ssl (sc, ref);
  DO_SET (col_ref_rec_t *, alias, aliases)
  {
    if (alias->crr_ssl == ssl)
      {
	/* dk_free_tree (*ref_place);*/
	*ref_place = (ST *) t_box_copy_tree ((caddr_t) alias->crr_col_ref);
	return;
      }
  }
  END_DO_SET ();
  {
    char temp[20];
    t_NEW_VARZ (col_ref_rec_t, alias);
    t_set_push (aliases, (void *) alias);
    snprintf (temp, sizeof (temp), "_a%d", alias_ctr++);
    alias->crr_col_ref = (ST *) t_list (3, COL_DOTTED, NULL, t_box_string (temp));
    ref->_.col_ref.name = t_box_string (temp);
    ref->_.col_ref.prefix = NULL;
    alias->crr_ssl = ssl;
  }
}


void
sqlc_col_to_view_scope (sql_comp_t * sc, ST ** tree_place, ST * view_exp,
    dk_set_t * aliases)
{
  /* In update / delete substitute in view name for external name.
     No correlation names and joins here */
  int inx;
  ST *tree = *tree_place;
  char *name = ST_COLUMN (tree, COL_DOTTED) ? tree->_.col_ref.name : (caddr_t) tree;
  ST **sel = (ST **) view_exp->_.select_stmt.selection;
  ST *repl = NULL;
  DO_BOX (ST *, as_exp, inx, sel)
  {
    if (0 == CASEMODESTRCMP (name, as_exp->_.as_exp.name))
      {
	repl = as_exp;
	while (ST_P (repl, BOP_AS))
	  repl = repl->_.as_exp.left;
	break;
      }
  }
  END_DO_BOX;
  if (repl)
    {
      /*dk_free_tree ((caddr_t) tree);*/
      *tree_place = (ST *) t_box_copy_tree ((caddr_t) repl);
    }
  else
    {
      if (!ST_COLUMN (tree, COL_DOTTED))
	sqlc_new_error (sc->sc_cc, "37000", "SQ113", "Non-view column set in view update");
      /*sqlc_alias_update_non_view_ref (sc, tree_place, aliases);*/
    }
}


void
sqlc_exp_to_view_scope (sql_comp_t * sc, ST ** tree_place,
    comp_table_t * view_ct, ST * view_exp, dk_set_t * aliases)
{
  ST *tree = *tree_place;
  if (!tree)
    return;
  if (SYMBOLP (tree))
    return;
  if (ST_P (tree, QUOTE))
    return;
  if (ST_COLUMN (tree, COL_DOTTED))
    {
      if (!view_ct)
	{
	  sqlc_col_to_view_scope (sc, tree_place, view_exp, aliases);
	}
      else
	{
	  col_ref_rec_t *cr = sqlc_col_or_param (sc, tree, 0);
	  if (cr->crr_ct == view_ct)
	    {
	      ST *expansion = sqlc_expand_col_ref (sc, tree, view_ct);
	      if (!expansion)
		SQL_GPF_T1 (sc->sc_cc, "Derived renamed with no internal name");
	      /*dk_free_tree ((caddr_t) tree);*/
	      *tree_place = expansion;
	    }
	  else
	    {
	      sqlc_alias_non_view_ref (sc, tree, cr, aliases);
	    }
	}
    }
  else if (BIN_EXP_P (tree))
    {
      sqlc_exp_to_view_scope (sc, &tree->_.bin_exp.left, view_ct, view_exp,
	  aliases);
      sqlc_exp_to_view_scope (sc, &tree->_.bin_exp.right, view_ct, view_exp,
	  aliases);
    }
  else if (SUBQ_P (tree))
    return;
  else if (ST_P (tree, CALL_STMT))
    {
      int inx;
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree->_.call.name))
	sqlc_exp_to_view_scope (sc, ((ST ***) &tree->_.call.name)[0],
	    view_ct, view_exp, aliases);
      _DO_BOX (inx, tree->_.call.params)
      {
	sqlc_exp_to_view_scope (sc, &tree->_.call.params[inx], view_ct, view_exp, aliases);
      }
      END_DO_BOX;
    }
  else if (ST_P (tree, COMMA_EXP))
    {
      int inx;
      _DO_BOX (inx, tree->_.comma_exp.exps)
      {
	sqlc_exp_to_view_scope (sc, &tree->_.comma_exp.exps[inx], view_ct, view_exp, aliases);
      }
      END_DO_BOX;
    }
  else if (ST_P (tree, ASG_STMT))
    {
      sqlc_exp_to_view_scope (sc, (ST **) &tree->_.op.arg_1,
	  view_ct, view_exp, aliases);
      sqlc_exp_to_view_scope (sc, (ST **) &tree->_.op.arg_2,
	  view_ct, view_exp, aliases);
    }
}


void
subq_node_free (subq_source_t * sqs)
{
  qr_free (sqs->sqs_query);
  dk_free_box ((caddr_t) sqs->sqs_out_slots);
}


void
sqlc_proc_table_cols (sql_comp_t * sc, comp_table_t * ct)
{
  caddr_t * cols;
  int inx;
  ST * tree = ct->ct_derived;

  DO_BOX (caddr_t, param, inx, tree->_.proc_table.params)
  {
    t_NEW_VARZ (col_ref_rec_t, crr);
    crr->crr_ct = ct;
    crr->crr_col_ref = (ST *) t_list (3, COL_DOTTED, ct->ct_prefix,
				    t_box_string (param));
    crr->crr_proc_table_mode = CRR_PT_IN_EQU;
    crr->crr_ssl = sqlc_new_temp (sc, param, DV_UNKNOWN);
    t_dk_set_append_1 (&ct->ct_out_crrs, (void *) crr);
    t_set_push (&sc->sc_col_ref_recs, (void *) crr);
  }
  END_DO_BOX;
  cols = (caddr_t *) ct->ct_derived->_.proc_table.cols;
  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (tree->_.proc_table.cols); inx += 2)
    {
      state_slot_t * ssl = NULL;
      if (!cols[inx])
	continue;
      DO_SET(col_ref_rec_t *, crr, &ct->ct_out_crrs)
	{
	  dtp_t name_dtp = DV_TYPE_OF (crr->crr_col_ref->_.col_ref.name);
	  dtp_t cols_dtp = DV_TYPE_OF (cols[inx]);
	  if (((IS_STRING_DTP (name_dtp) || name_dtp == DV_SYMBOL) &&
	      (IS_STRING_DTP (cols_dtp) || cols_dtp == DV_SYMBOL) &&
	      0 == CASEMODESTRCMP (crr->crr_col_ref->_.col_ref.name, cols[inx])) ||
	      box_equal (crr->crr_col_ref->_.col_ref.name, cols[inx]))
	    {
	      ssl = crr->crr_ssl;
	      goto already_in;
	    }
	}
      END_DO_SET();

      {
	t_NEW_VARZ (col_ref_rec_t, crr);
	crr->crr_ct = ct;
	crr->crr_col_ref = (ST *) t_list (3, COL_DOTTED, ct->ct_prefix,
					t_box_string (cols[inx]));
	crr->crr_ssl = sqlc_new_temp (sc, cols[inx], DV_UNKNOWN);
	ssl = crr->crr_ssl;
	t_dk_set_append_1 (&ct->ct_out_crrs, (void *) crr);
	t_set_push (&sc->sc_col_ref_recs, (void *) crr);
      }
    already_in: ;
      ddl_type_to_sqt (&(ssl->ssl_sqt), ((caddr_t ***) cols)[inx + 1][0]);
    }
}


void
sqlc_insert_view (sql_comp_t * sc, ST * view, ST * tree, dbe_table_t * tb)
{
  /*oid_t ref_g_id = unbox (tree->_.insert.table->_.table.g_id);
  oid_t ref_u_id = unbox (tree->_.insert.table->_.table.u_id);*/

  int inx;
  ST **cols = tree->_.insert.cols;
  dk_set_t aliases = NULL;
  dk_set_t new_cols = NULL, new_vals = NULL;

  if (!sqlc_view_is_updatable (view))
    sqlc_new_error (sc->sc_cc, "37000", "SQ114",
	"View %s is not updatable in insert.", tb->tb_name);

  /*dk_free_tree ((caddr_t) tree->_.insert.table);*/
  tree->_.insert.table = (ST *) t_box_copy_tree (
      (caddr_t) view->_.select_stmt.table_exp->_.table_exp.from[0]->_.table_ref.table);

  _DO_BOX (inx, tree->_.insert.cols)
    {
      sqlc_col_to_view_scope (sc, &cols[inx], view, &aliases);
      if (!ST_P (tree->_.insert.vals, SELECT_STMT))
	sinv_sqlo_check_col_val (&cols[inx],
	    &(tree->_.insert.vals->_.ins_vals.vals[inx]),
	    &new_cols, &new_vals);
    }
  END_DO_BOX;

  if (new_cols)
    {
      ST ** new_cols_box = (ST **) t_alloc_box (
	  (BOX_ELEMENTS (cols) + dk_set_length (new_cols)) * sizeof (caddr_t),
	  DV_ARRAY_OF_POINTER);
      ST ** new_vals_box = (ST **) t_alloc_box (
	  (BOX_ELEMENTS (cols) + dk_set_length (new_cols)) * sizeof (caddr_t),
	  DV_ARRAY_OF_POINTER);
      memcpy (new_cols_box, cols, box_length (cols));
      memcpy (new_vals_box, tree->_.insert.vals->_.ins_vals.vals, box_length (cols));
      inx = BOX_ELEMENTS (cols);
      DO_SET (ST *, new_col, &new_cols)
	{
	  new_cols_box[inx] = new_col;
	  new_vals_box[inx] = (ST *) new_vals->data;
	  new_vals = new_vals->next;
	  inx ++;
	}
      END_DO_SET ();
      tree->_.insert.cols = cols = new_cols_box;
      tree->_.insert.vals->_.ins_vals.vals = new_vals_box;
    }

  _DO_BOX (inx, tree->_.insert.cols)
    {
      if (ST_COLUMN (cols[inx], COL_DOTTED))
	{
	  ST *c = (ST *) t_box_copy_tree (cols[inx]->_.col_ref.name);
	  /*dk_free_tree (cols[inx]);*/
	  cols[inx] = c;
	}
      else
	{
	  sqlc_new_error (sc->sc_cc, "37000", "SQ115",
	      "Non-updatable column in view %s (expression or constant)",
	      tb->tb_name);
	}
    }
  END_DO_BOX;


  sc->sc_col_ref_recs = t_NCONC (aliases, sc->sc_col_ref_recs);
  sqlc_insert (sc, tree);
}


void
sqlc_update_view (sql_comp_t * sc, ST * view, ST * tree, dbe_table_t * tb)
{
  oid_t ref_g_id = (oid_t) unbox (tree->_.update_src.table->_.table.g_id);
  oid_t ref_u_id = (oid_t) unbox (tree->_.update_src.table->_.table.u_id);

  int sec_checked = 0;
  int inx;
  ST **cols = tree->_.update_src.cols;
  ST *texp = tree->_.update_src.table_exp;
  dk_set_t aliases = NULL;
  dk_set_t new_cols = NULL, new_vals = NULL;

  if (!sqlc_view_is_updatable (view))
    sqlc_new_error (sc->sc_cc, "37000", "SQ116",
	"View %.300s is not updatable.", tb->tb_name);

  if (sec_tb_check (tb, SC_G_ID (sc), SC_U_ID (sc), GR_UPDATE))
    sec_checked = 1;
  /*dk_free_tree ((caddr_t) tree->_.update_src.table);*/
  tree->_.update_src.table = (ST *)
      t_box_copy_tree ((caddr_t) view->_.select_stmt.table_exp->_.table_exp.from[0]->_.table_ref.table);
  /*dk_free_tree ((caddr_t) tree->_.update_src.table_exp->_.table_exp.from[0]);*/
  tree->_.update_src.table_exp->_.table_exp.from[0]
      = (ST *) t_box_copy_tree ((caddr_t) tree->_.update_src.table);

  _DO_BOX (inx, tree->_.update_src.cols)
    {
      dbe_column_t * v_col = tb_name_to_column (tb, (caddr_t) cols[inx]);
      if (!sec_checked
	  && (!v_col || !sec_col_check (v_col, ref_g_id, ref_u_id, GR_UPDATE)))
	sqlc_new_error (sc->sc_cc, "42000", "SQ117",
	    "No column update privilege for %.100s in view %.300s (user ID = %lu)",
	    v_col ? v_col->col_name : "<bad column>", tb->tb_name, ref_u_id );
      sqlc_col_to_view_scope (sc, &cols[inx], view, &aliases);
      sqlc_exp_to_view_scope (sc, &tree->_.update_src.vals[inx], NULL, view,
	  &aliases);
      sinv_sqlo_check_col_val (&cols[inx], &tree->_.update_src.vals[inx],
	  &new_cols, &new_vals);
    }
  END_DO_BOX;
  if (new_cols)
    {
      ST ** new_cols_box = (ST **) t_alloc_box (
	  (BOX_ELEMENTS (cols) + dk_set_length (new_cols)) * sizeof (caddr_t),
	  DV_ARRAY_OF_POINTER);
      ST ** new_vals_box = (ST **) t_alloc_box (
	  (BOX_ELEMENTS (cols) + dk_set_length (new_cols)) * sizeof (caddr_t),
	  DV_ARRAY_OF_POINTER);
      memcpy (new_cols_box, cols, box_length (cols));
      memcpy (new_vals_box, tree->_.update_src.vals, box_length (cols));
      inx = BOX_ELEMENTS (cols);
      DO_SET (ST *, new_col, &new_cols)
	{
	  new_cols_box[inx] = new_col;
	  new_vals_box[inx] = (ST *) new_vals->data;
	  new_vals = new_vals->next;
	  inx ++;
	}
      END_DO_SET ();
      tree->_.update_src.cols = cols = new_cols_box;
      tree->_.update_src.vals = new_vals_box;
    }

  _DO_BOX (inx, tree->_.update_src.cols)
    {
      if (ST_COLUMN (cols[inx], COL_DOTTED))
	{
	  ST *c = (ST *) t_box_copy_tree (cols[inx]->_.col_ref.name);
	  cols[inx] = c;
	}
      else
	{
	  sqlc_new_error (sc->sc_cc, "37000", "SQ118",
	      "Non-updatable column in view %s (expression or constant)",
	      tb->tb_name);
	}
    }
  END_DO_BOX;
  sqlc_exp_to_view_scope (sc, &texp->_.table_exp.where, NULL, view, &aliases);
  t_st_and (&texp->_.table_exp.where,
      (ST *) t_box_copy_tree ((caddr_t) view->_.select_stmt.table_exp->_.table_exp.where));

  sc->sc_col_ref_recs = t_NCONC (aliases, sc->sc_col_ref_recs);
  sqlc_update_searched (sc, tree);
}


void
sqlc_delete_view (sql_comp_t * sc, ST * view, ST * tree)
{
  ST *texp = tree->_.delete_src.table_exp;
  dk_set_t aliases = NULL;

  if (!sqlc_view_is_updatable (view))
    sqlc_new_error (sc->sc_cc, "37000", "SQ119", "View %s is not updatable.",
	texp && texp->_.table_exp.from[0] && texp->_.table_exp.from[0]->_.table_ref.table ?
	(char *) texp->_.table_exp.from[0]->_.table_ref.table : "<unknown>");

  /*dk_free_tree ((caddr_t) tree->_.delete_src.table_exp->_.table_exp.from[0]);*/
  tree->_.delete_src.table_exp->_.table_exp.from[0] = (ST *)
      t_box_copy_tree ((caddr_t) view->_.select_stmt.table_exp->_.table_exp.from[0]->_.table_ref.table);

  sqlc_exp_to_view_scope (sc, &texp->_.table_exp.where, NULL, view, &aliases);
  t_st_and (&texp->_.table_exp.where,
      (ST *) t_box_copy_tree ((caddr_t) view->_.select_stmt.table_exp->_.table_exp.where));

  sc->sc_col_ref_recs = t_NCONC (aliases, sc->sc_col_ref_recs);
  sqlc_delete_searched (sc, tree);
}


#define SQLC_IS_LIT(x) (DV_ARRAY_OF_POINTER != DV_TYPE_OF (x))

void
sqlc_union_constants (ST * sel)
{
  int inx;
  DO_BOX (ST *, tree, inx, sel->_.select_stmt.selection)
    {
      if (ST_P (tree, BOP_AS) && SQLC_IS_LIT (tree->_.as_exp.left))
	tree->_.as_exp.left = (ST*) t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("__copy"), t_list (1, tree->_.as_exp.left));
      else if (SQLC_IS_LIT (tree))
	sel->_.select_stmt.selection[inx] = t_listbox (3, CALL_STMT, t_sqlp_box_id_upcase ("__copy"), t_list (1, tree));
    }
  END_DO_BOX;
}


void
sqlc_union_tree (sql_comp_t * sc, ST ** ptree, dk_set_t * selects)
{
  ST *tree = *ptree;
  if (ST_P (tree, SELECT_STMT))
    {
      sqlc_top_select_dt (sc, *ptree);
      sqlc_union_constants (tree);
      dk_set_append_1 (selects, (void *) ptree);
    }
  else if (ST_P (tree, UNION_ALL_ST)
      || ST_P (tree, UNION_ST))
    {
      sqlc_union_tree (sc, &(tree->_.bin_exp.left), selects);
      sqlc_union_tree (sc, &(tree->_.bin_exp.right), selects);
    }
}


int
sqlc_is_all_unions (ST * tree)
{
  if (tree->_.set_exp.cols)
    return 0;
  if (ST_P (tree, SELECT_STMT))
    return 1;
  if (ST_P (tree, UNION_ST) || ST_P (tree, UNION_ALL_ST))
    return (sqlc_is_all_unions (tree->_.set_exp.left)
	&& sqlc_is_all_unions (tree->_.set_exp.right));
  return 0;
}


void
sqlc_union_all_tree (sql_comp_t * sc, ST ** ptree)
{
  ST *tree = *ptree;
  if (ST_P (tree, SELECT_STMT))
    {
      sqlc_union_constants (tree);
      sqlc_top_select_dt (sc, tree);
      t_dk_set_append_1 (&sc->sc_union_lists,
	  (void *) t_CONS (ptree, NULL));
    }
  else if (ST_P (tree, UNION_ALL_ST))
    {
      sqlc_union_all_tree (sc, &(tree->_.bin_exp.left));
      sqlc_union_all_tree (sc, &(tree->_.bin_exp.right));
    }
  else if (ST_P (tree, UNION_ST))
    {
      dk_set_t selects = NULL;
      sqlc_union_tree (sc, &(tree->_.bin_exp.left), &selects);
      sqlc_union_tree (sc, &(tree->_.bin_exp.right), &selects);
      t_dk_set_append_1 (&sc->sc_union_lists, (void *) selects);
    }
}


int
ssl_is_special (state_slot_t * ssl)
{
  if (ssl->ssl_type == SSL_COLUMN || ssl->ssl_type == SSL_VARIABLE)
    return 0;
  return 1;
}


void
sqt_max_desc (sql_type_t * res, sql_type_t * arg)
{
  if (res->sqt_dtp == DV_DB_NULL || res->sqt_dtp == DV_UNKNOWN)
    *res = *arg;
  else if (arg->sqt_dtp == DV_DB_NULL || arg->sqt_dtp == DV_UNKNOWN)
    return;
  else
    {
      if (IS_NUM_DTP (res->sqt_dtp) && IS_NUM_DTP (arg->sqt_dtp))
	res->sqt_dtp = MAX (res->sqt_dtp, arg->sqt_dtp);
      res->sqt_precision = MAX (res->sqt_precision, arg->sqt_precision);
      res->sqt_scale = (char) MAX (res->sqt_precision, ((uint32) arg->sqt_scale));
    }
}


void
qr_alias_out_cols (sql_comp_t * sc, query_t * qr, select_node_t * target_sel)
{
  /* do not require equal no of out cols because there may
     be extras such as 'current of' */
  int inx, n1 = BOX_ELEMENTS (target_sel->sel_out_slots);
  int n2 = BOX_ELEMENTS (qr->qr_select_node->sel_out_slots);
  n1 = MIN (n1, n2);
  for (inx = 0; inx < n1; inx++)
    {
      state_slot_t *target = target_sel->sel_out_slots[inx];
      state_slot_t *src = qr->qr_select_node->sel_out_slots[inx];
      if (!ssl_is_special (target) && !ssl_is_special (src))
	{
	  if (SQW_DTP_COLIDE (src->ssl_dtp, src->ssl_class, target->ssl_dtp, target->ssl_class))
	    {
	      sqlc_warning ("01V01", "QW006",
		  "Incompatible types %.*s (%d) and %.*s (%d) in UNION branches for %.*s and %.*s",
		  MAX_NAME_LEN, dv_type_title (src->ssl_dtp), (int) src->ssl_dtp,
		  MAX_NAME_LEN, dv_type_title (target->ssl_dtp), (int) target->ssl_dtp,
		  MAX_NAME_LEN, src->ssl_name ? src->ssl_name : ssl_type_to_name (src->ssl_type),
		  MAX_NAME_LEN, target->ssl_name ? target->ssl_name : ssl_type_to_name (target->ssl_type));
	    }
	  sqt_max_desc (&(target->ssl_sqt), &(qr->qr_select_node->sel_out_slots[inx]->ssl_sqt));
	  ssl_alias (qr->qr_select_node->sel_out_slots[inx], target);
	}
    }
}


void
qr_replace_node (query_t * qr, data_source_t * to_replace,
    data_source_t * replace_with)
{
  /* replace query's select node  with given */
  if (to_replace == qr->qr_head_node)
    qr->qr_head_node = replace_with;
  DO_SET (data_source_t *, ds, &qr->qr_nodes)
  {
    if ((qn_input_fn)fun_ref_node_input == ds->src_input)
      {
	fun_ref_node_t * fref = (fun_ref_node_t  *)ds;
	if (fref->fnr_select == to_replace)
	  fref->fnr_select = replace_with;
      }
    if (ds->src_continuations
	&& ds->src_continuations->data == (caddr_t) to_replace)
      ds->src_continuations->data = (caddr_t) replace_with;
  }
  END_DO_SET ();
}


data_source_t *
qr_ensure_distinct_node (sql_comp_t * sc, query_t * qr)
{
  /* the first select of each UNION has a DISTINCT.
     EXCEPT when it's a pass through remote. If so, make a distinct */
  DO_SET (data_source_t *, ds, &qr->qr_nodes)
  {
    if (ds->src_input == (qn_input_fn) setp_node_input)
      return ds;
  }
  END_DO_SET ();
  if (QR_PASS_THROUGH == qr->qr_remote_mode)
    {
      select_node_t *sel = qr->qr_select_node;
      data_source_t *rts = qr->qr_head_node, *distinct;
      dk_set_free (rts->src_continuations);
      rts->src_continuations = NULL;
      sqlc_add_distinct_node (sc, &qr->qr_head_node, sel->sel_out_slots, 0);
      sql_node_append (&qr->qr_head_node, (data_source_t *) sel);
      distinct = (data_source_t *) rts->src_continuations->data;
      return distinct;
    }
  SQL_GPF_T1 (sc->sc_cc, "Must be a select with distinct in UNION");
  return NULL;
}


void
union_node_free (union_node_t * un)
{
  dk_set_free (un->uni_successors);
}


char *
ssl_name_last_dot (char *name)
{
  int len = (int) strlen (name);
  int inx;
  if (len > 0)
    {
      for (inx = len - 1; inx >= 0; inx--)
	if (name[inx] == '.')
	  return (&name[inx + 1]);
    }
  return name;
}


setp_node_t *
setp_node_keys (sql_comp_t * sc, select_node_t * sel, caddr_t * cols)
{
  int inx, sinx;
  SQL_NODE_INIT (setp_node_t, setp, setp_node_input, setp_node_free);
  setp->setp_distinct = 1;
  if (cols)
    {
      DO_BOX (caddr_t, name, inx, cols)
      {
	DO_BOX (state_slot_t *, ssl, sinx, sel->sel_out_slots)
	{
	  if (0 == CASEMODESTRCMP (name, ssl_name_last_dot (ssl->ssl_name)))
	    {
	      dk_set_push (&setp->setp_keys, (void *) ssl);
	      goto next_name;
	    }
	}
	END_DO_BOX;
	sqlc_new_error (sc->sc_cc, "S0022", "SQ120", "Bad CORRESPONDING BY column %s", name);
      next_name:;
      }
      END_DO_BOX;
    }
  else
    {
      DO_BOX (state_slot_t *, ssl, inx, sel->sel_out_slots)
      {
	int type = ssl->ssl_type;
	if (type == SSL_ITC || type == SSL_PLACEHOLDER)
	  break;
	dk_set_push (&setp->setp_keys, (void *) ssl);
      }
      END_DO_BOX;
    }
  return setp;
}


void
sqlc_set_stmt (sql_comp_t * sc, ST * tree)
{
  setp_node_t *setp_left, *setp_right;
  subq_compilation_t *left;
  subq_compilation_t *right;
  select_node_t *sel = NULL;
  caddr_t *cols = tree->_.set_exp.cols;
  comp_context_t *cc = sc->sc_cc;
  SQL_NODE_INIT (union_node_t, un, union_node_input, union_node_free);

  sqlc_top_select_dt (sc, tree->_.set_exp.left);
  sqlc_top_select_dt (sc, tree->_.set_exp.right);
  left = sqlc_subquery (sc, NULL, &(tree->_.set_exp.left));
  right = sqlc_subquery (sc, NULL, &(tree->_.set_exp.right));
  sel = left->sqc_query->qr_select_node;
  if (!ST_P (tree, UNION_ST) && !ST_P (tree, UNION_ALL_ST))
    {
      dk_set_push (&un->uni_successors, (void *) left->sqc_query);
      dk_set_push (&un->uni_successors, (void *) right->sqc_query);
    }
  else
    {
      dk_set_push (&un->uni_successors, (void *) right->sqc_query);
      dk_set_push (&un->uni_successors, (void *) left->sqc_query);
    }
  qr_alias_out_cols (sc, right->sqc_query, sel);
  if (ST_P (tree, UNION_ALL_ST))
    {
      qr_replace_node (right->sqc_query,
	  (data_source_t *) right->sqc_query->qr_select_node,
	  (data_source_t *) sel);

    }
  else
    {
      setp_left = setp_node_keys (sc, sel, cols);
      setp_left->setp_temp_key = sqlc_new_temp_key_id (sc);
      setp_left->src_gen.src_continuations = CONS (sel, NULL);
      qr_replace_node (left->sqc_query,
	  (data_source_t *) sel, (data_source_t *) setp_left);

      if (ST_P (tree, UNION_ST))
	{
	  qr_replace_node (right->sqc_query,
	      (data_source_t *) right->sqc_query->qr_select_node,
	      (data_source_t *) setp_left);
	}
      else
	{
	  setp_right = setp_node_keys (sc, sel, cols);
	  setp_right->setp_temp_key = setp_left->setp_temp_key;
	  qr_replace_node (right->sqc_query,
	      (data_source_t *) right->sqc_query->qr_select_node,
	      (data_source_t *) setp_right);
	  setp_left->setp_set_op = (int) tree->type;
	}
    }
  cc->cc_query->qr_head_node = (data_source_t *) un;
  un->uni_nth_output = ssl_new_inst_variable (sc->sc_cc, "nth", DV_LONG_INT);
  cc->cc_query->qr_select_node = sel;
  DO_SET (query_t *, u_qr, &un->uni_successors)
  {
    cc->cc_query->qr_nodes = dk_set_conc (u_qr->qr_nodes,
	cc->cc_query->qr_nodes);
    u_qr->qr_nodes = NULL;
  }
  END_DO_SET ();
  if (!sc->sc_super)
    sel->src_gen.src_input = (qn_input_fn) select_node_input;
}


ST*
sqlc_copy_union_as (ST * exp, ST * as, int inx)
{
  /* copy the as and replace the exp w/ the given. Note that AS can be5 or 6 long
   * depending on xml_col declaration element */
  ST * copy = (ST*) t_box_copy_tree ((caddr_t) as);
  /*dk_free_tree ((caddr_t) copy->_.as_exp.left);*/
  copy->_.as_exp.left = exp;
  return copy;
}

ST **
sqlc_selection_names (ST * tree, int only_edit_tree)
{
  int inx;
  ST ** sel = (only_edit_tree ? (ST **)(tree->_.select_stmt.selection) : (ST **) t_box_copy ((caddr_t)(tree->_.select_stmt.selection)));
  dk_set_t double_set = NULL;
  dk_set_t names_set = NULL;

  /*if (SQLO_ENABLE (sqlc_client()))*/
    {
      DO_BOX (ST *, exp, inx, sel)
	{
	  if (ST_P (exp, BOP_AS))
	    {
	      DO_SET (caddr_t, name, &names_set)
		{
		  if (!strcmp (name, exp->_.as_exp.name))
		    {
		      t_set_push (&double_set, (caddr_t) (ptrlong) inx);
		      goto next;
		    }
		}
	      END_DO_SET();
	      t_set_push (&names_set, exp->_.as_exp.name);
next:;
	    }
	}
      END_DO_BOX;
    }

  DO_BOX (ST *, exp, inx, sel)
    {
      if (ST_P (exp, BOP_AS))
	{
	  if (dk_set_member (double_set, (caddr_t) (ptrlong) inx))
	    {
	      char tname[100];
	      snprintf (tname, sizeof (tname), "computed%d", inx);
	      if (!only_edit_tree)
	      sel[inx] = sqlc_copy_union_as (
		  (ST*) t_list (3, COL_DOTTED, NULL, t_box_string (tname)),
		  exp, inx);
	      exp->_.as_exp.name = t_box_string (tname);
	    }
	  else if (!only_edit_tree)
	    {
	      sel[inx] = sqlc_copy_union_as (
		  (ST*) t_list (3, COL_DOTTED,
				NULL, t_box_copy_tree (exp->_.as_exp.name)),
		  exp, inx);
	    }
	}
      else if (ST_COLUMN (exp, COL_DOTTED))
	{
	  tree->_.select_stmt.selection[inx] = (caddr_t) t_list (5,
	      BOP_AS, exp, NULL, t_box_string (exp->_.col_ref.name), NULL);
	  if (!only_edit_tree)
	  sel[inx] = (ST*) t_list (3, COL_DOTTED, NULL, t_box_copy_tree (exp->_.col_ref.name));
	}
      else
	{
	  char tname[100];
	  snprintf (tname, sizeof (tname), "computed%d", inx);
	  tree->_.select_stmt.selection[inx] = (caddr_t) t_list (5, BOP_AS, tree->_.select_stmt.selection[inx], NULL, t_box_string (tname), NULL);
	  if (!only_edit_tree)
	  sel[inx] = (ST*) t_list (3, COL_DOTTED, NULL, t_box_string (tname));
	}
    }
  END_DO_BOX;
  return sel;
}

ST *
sqlc_union_dt_wrap (ST * tree)
{
  ST * left = sqlp_union_tree_select (tree);
  ST * right = sqlp_union_tree_right (tree);
  if (left != right)
    {
      ST * texp, * sel;
      ST ** order =right->_.select_stmt.table_exp->_.table_exp.order_by;
      ptrlong flags = right->_.select_stmt.table_exp->_.table_exp.flags;
      caddr_t * opts = right->_.select_stmt.table_exp->_.table_exp.opts;
      right->_.select_stmt.table_exp->_.table_exp.order_by = NULL;
      right->_.select_stmt.table_exp->_.table_exp.opts = NULL;
      texp = sqlp_infoschema_redirect (t_listst (9,
	    TABLE_EXP, t_list (1, t_list (3, DERIVED_TABLE, tree, t_box_string ("__"))),
		   NULL, NULL, NULL, order, flags,opts, NULL));
      sel = (ST*) t_list (5, SELECT_STMT, NULL, sqlc_selection_names (left, 0), NULL,
			texp);
      return sel;
    }
  else
    return tree;
}


void
sqlc_union_order (sql_comp_t * sc, ST ** ptree)
{
  ST * out = sqlc_union_dt_wrap (*ptree);
  if (out != *ptree)
    {
      *ptree = out;
      sql_stmt_comp (sc, ptree);
    }
  else
    sqlc_union_stmt (sc, ptree);
}


void
sqlc_top_select_dt (sql_comp_t * sc, ST * tree)
{
  /* given select top xx ...) splices it to be select ... from (select top xx... ) __ */
  ST * top, * texp, * sel;
  if (!ST_P (tree, SELECT_STMT))
    return;
  top = SEL_TOP (tree);
  if (top)
    {
      ST * out_names = (ST *) sqlc_selection_names (tree, 0);
      sel = (ST*) /*list*/ t_list (5, SELECT_STMT, top, tree->_.select_stmt.selection, NULL,
			tree->_.select_stmt.table_exp);
      texp = (ST*) /*list*/ t_list (9, TABLE_EXP,
	  /*list*/ t_list (1, /*list*/ t_list (3, DERIVED_TABLE, sel, t_box_string ("__"))),
			 NULL, NULL, NULL, NULL, NULL,NULL, NULL);
      tree->_.select_stmt.table_exp = sqlp_infoschema_redirect (texp);
      tree->_.select_stmt.selection = (caddr_t *) out_names;
      tree->_.select_stmt.top = NULL;
    }
}


void
sqlc_union_stmt (sql_comp_t * sc, ST ** ptree)
{
  query_t *first_qr;
  ST *tree = *ptree;
  select_node_t *sel_node = NULL;
  dk_set_t all_qrs = NULL;
  ST **selection;
  ST **pleft_select;
  comp_context_t *cc = sc->sc_cc;
  SQL_NODE_INIT (union_node_t, un, union_node_input, union_node_free);

  if (!sqlc_is_all_unions (tree))
    {
      sqlc_set_stmt (sc, tree);
      return;
    }
  sqlc_union_all_tree (sc, ptree);
  pleft_select = (ST **) ((dk_set_t) (sc->sc_union_lists->data))->data;
  selection = (ST **) (*pleft_select)->_.select_stmt.selection;

  DO_SET (dk_set_t, u_terms, &sc->sc_union_lists)
  {
    subq_compilation_t *sqc;
    int n_u_terms = dk_set_length (u_terms);
    data_source_t *distinct_node = NULL;
    ST **pfirst_sel = (ST **) u_terms->data;
    ST *first_sel = *pfirst_sel;
    if (1 != n_u_terms)
      {
	SEL_SET_DISTINCT (first_sel, 1);
      }
    else
      SEL_SET_DISTINCT (first_sel, 0);
    sqc = sqlc_subquery (sc, NULL, pfirst_sel);
    first_sel = *pfirst_sel;
    dk_set_append_1 (&all_qrs, (void *) sqc->sqc_query);
    first_qr = sqc->sqc_query;
    if (sel_node)
      {
	qr_alias_out_cols (sc, sqc->sqc_query, sel_node);
	qr_replace_node (sqc->sqc_query,
	    (data_source_t *) sqc->sqc_query->qr_select_node,
	    (data_source_t *) sel_node);
      }
    else
      {
	sel_node = sqc->sqc_query->qr_select_node;
	/* if we're doing a union run from called from client it must
	   have a real select node, not a subq_select_node */
	if (!sc->sc_super)
	  sel_node->src_gen.src_input = (qn_input_fn) select_node_input;
      }
    u_terms = u_terms->next;
    DO_SET (ST **, psel, &u_terms)
    {
      ST *sel = *psel;
      if (!distinct_node)
	distinct_node = qr_ensure_distinct_node (sc, sqc->sqc_query);

      SEL_SET_DISTINCT (sel, 0);
      sqc = sqlc_subquery (sc, NULL, psel);
      sel = *psel;
      dk_set_append_1 (&all_qrs, (void *) sqc->sqc_query);
      qr_alias_out_cols (sc, sqc->sqc_query, sel_node);
      qr_replace_node (sqc->sqc_query,
	  (data_source_t *) sqc->sqc_query->qr_select_node,
	  (data_source_t *) distinct_node);
    }
    END_DO_SET ();
  }
  END_DO_SET ();
  /*dk_set_free (sc->sc_union_lists);*/
  /*sc->sc_union_lists = NULL;*/

  cc->cc_query->qr_head_node = (data_source_t *) un;
  un->uni_successors = all_qrs;
  un->uni_nth_output = ssl_new_inst_variable (sc->sc_cc, "nth", DV_LONG_INT);
  cc->cc_query->qr_select_node = sel_node;
  cc->cc_query->qr_bunion_node = tree->_.set_exp.is_best ? un : NULL;
  DO_SET (query_t *, u_qr, &all_qrs)
  {
    cc->cc_query->qr_nodes = dk_set_conc (u_qr->qr_nodes,
	cc->cc_query->qr_nodes);
    u_qr->qr_bunion_reset_nodes = u_qr->qr_bunion_reset_nodes;
    u_qr->qr_nodes = NULL;
    u_qr->qr_is_bunion_term = (char) tree->_.set_exp.is_best;
  }
  END_DO_SET ();
}


