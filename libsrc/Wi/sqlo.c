/*
 *  sqlo.c
 *
 *  $Id$
 *
 *  sql scope inference
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqlo.h"
#include "remote.h"


#define CHECK_OBSERVER(tree_ptr) \
   if (ST_COLUMN (*(tree_ptr), COL_DOTTED)) \
     { \
       ST *new_tree = sqlo_udt_check_observer (so, NULL, *(tree_ptr)); \
       if (new_tree != *(tree_ptr)) \
	 { \
	   *(tree_ptr) = new_tree; \
	   sqlo_scope (so, tree_ptr); \
	   return; \
	 } \
     }

#define CHECK_MUTATOR(tree_ptr) \
   if (ST_P (*(tree_ptr), ASG_STMT)) \
     { \
       ST *new_tree = sqlo_udt_check_mutator (so, NULL, *(tree_ptr)); \
       if (new_tree != *(tree_ptr)) \
	 { \
	   *(tree_ptr) = new_tree; \
	   sqlo_scope (so, tree_ptr); \
	   return; \
	 } \
     }

#define CHECK_METHOD_CALL(tree_ptr) \
   if (ST_P (*(tree_ptr), CALL_STMT) && ( \
	DV_ARRAY_OF_POINTER != DV_TYPE_OF ((*(tree_ptr))->_.call.name) || \
	BOX_ELEMENTS ((*(tree_ptr))->_.call.name) != 1)) \
     { \
       ST *new_tree = sqlo_udt_check_method_call (so, NULL, *(tree_ptr)); \
       if (new_tree != *(tree_ptr)) \
	 { \
	   *(tree_ptr) = new_tree; \
	   sqlo_scope (so, tree_ptr); \
	   return; \
	 } \
     }


dbe_column_t *
ot_is_defd (op_table_t * ot, ST * col_ref)
{
  dbe_column_t * col;
  DO_SET (op_virt_col_t *, vc, &ot->ot_virtual_cols)
    {
      if (0 == CASEMODESTRCMP (vc->vc_tree->_.col_ref.name, col_ref->_.col_ref.name))
	{
	  col_ref->_.col_ref.name = vc->vc_tree->_.col_ref.name;
	  return (dbe_column_t *) 1;
	}
    }
  END_DO_SET ();
  if (ot->ot_dt)
    {
      int inx;
      ST * left = sqlp_union_tree_select (ot->ot_dt);
      if (ST_P (left, SELECT_STMT))
	{
	  DO_BOX (ST *, as, inx, left->_.select_stmt.selection)
	    {
	      if (0 == CASEMODESTRCMP (as->_.as_exp.name, col_ref->_.col_ref.name))
		{
		  col_ref->_.col_ref.name = as->_.as_exp.name;
		  return (dbe_column_t *) 1;
		}
	    }
	  END_DO_BOX;
	}
      return 0;
    }
  col = tb_name_to_column (ot->ot_table, col_ref->_.col_ref.name);
  if (col &&
      col != (dbe_column_t *) CI_ROW &&
      col != (dbe_column_t *) CI_ANY &&
      col != (dbe_column_t *) CI_INDEX)
    {
      col_ref->_.col_ref.name = col->col_name;
    }
  return col;
}

#define SCO_UNQUALIFIED 0
#define SCO_ANY_QUAL 1
#define SCO_THIS_QUAL 2


char *
sqlo_ot_effective_prefix (op_table_t * ot)
{
  if (ot->ot_prefix)
    return (ot->ot_prefix);
  return (ot->ot_table->tb_name);
}


op_table_t *
sco_is_defd (sql_scope_t * sco, ST * col_ref, int mode, int generate)
{
  op_table_t * def_ot = NULL;
  dbe_column_t *col = NULL;
  int n_found = 0;
  DO_SET (op_table_t *, ot, &sco->sco_tables)
    {
      if (SCO_UNQUALIFIED == mode
	  && NULL != (col = ot_is_defd (ot, col_ref)))
	{
	  if (!def_ot)
	    {
	      n_found++;
	      def_ot = ot;
	    }
	  else
	    {
	      if (!def_ot->ot_prefix && !ot->ot_prefix)
		{
		  n_found++;
		  goto next;
		}
	      if (!def_ot->ot_prefix && ot->ot_prefix)
		goto next;
	      if (def_ot->ot_prefix && !ot->ot_prefix)
		{
		  n_found = 1;
		  def_ot = ot;
		}
	      if (def_ot->ot_prefix && ot->ot_prefix)
		n_found++;
	    }
	}
      if (SCO_THIS_QUAL == mode
	  && sqlc_pref_match (sqlo_ot_effective_prefix (ot), col_ref->_.col_ref.prefix))
	{
	  if (NULL != (col = ot_is_defd (ot, col_ref)))
	    {
	      col_ref->_.col_ref.prefix = ot->ot_new_prefix;
	      ot->ot_has_cols = 1;
	      def_ot = ot;
	      n_found = 1;
	      goto ok;
	    }
	  if (generate)
	    sqlc_error (sco->sco_so->so_sc->sc_cc, "S0022", "No column %s.%s",
		col_ref->_.col_ref.prefix, col_ref->_.col_ref.name);
	  else
	    return NULL;
	}
      if (SCO_ANY_QUAL == mode
	  && NULL != (col = ot_is_defd (ot, col_ref)))
	{
	  if (!def_ot)
	    {
	      def_ot = ot;
	      n_found = 1;
	    }
	  else
	    {
	      if (generate)
		sqlc_error (sco->sco_so->so_sc->sc_cc, "S0022",
		    "Ambiguous col ref %s", col_ref->_.col_ref.name);
	      else
		return NULL;
	    }
	}
    }
next: ;
  END_DO_SET ();
  if (!n_found && SCO_THIS_QUAL == mode && strchr (col_ref->_.col_ref.prefix, '.'))
    {
      dbe_table_t *prefix_table = sch_name_to_table (wi_inst.wi_schema,
	  col_ref->_.col_ref.prefix);
      DO_SET (op_table_t *, ot, &sco->sco_tables)
	{
	  if (!ot->ot_prefix && ot->ot_table == prefix_table &&
	      ot_is_defd (ot, col_ref))
	    {
	      def_ot = ot;
	      n_found++;
	    }
	}
      END_DO_SET();
    }
  if (n_found > 1)
    {
      if (generate)
	sqlc_new_error (sco->sco_so->so_sc->sc_cc, "42S22", "SQ065", "Col ref ambiguous %s.%s.",
	    col_ref->_.col_ref.prefix ? col_ref->_.col_ref.prefix : "",
	    col_ref->_.col_ref.name);
      else
	return NULL;
    }
  if (def_ot)
    {
      col_ref->_.col_ref.prefix = def_ot->ot_new_prefix;
      def_ot->ot_has_cols = 1;
    }
ok:
  if (def_ot && def_ot->ot_table && IS_BOX_POINTER (col) &&
      !sec_tb_check (def_ot->ot_table, def_ot->ot_g_id, def_ot->ot_u_id, GR_SELECT)
      && !sec_col_check (col, def_ot->ot_g_id, def_ot->ot_u_id, GR_SELECT))
    {
      if (generate)
	sqlc_new_error (sco->sco_so->so_sc->sc_cc, "42000", "SQ033", "SELECT access denied for column %s of table %s, user ID %lu",
	    col->col_name, def_ot->ot_table->tb_name, def_ot->ot_u_id );
      else
	return NULL;
    }
  return def_ot;
}


#if 0
void
sqlo_expand_jtc_col (sql_scope_t *sco, ST *col_ref)
{
  DO_SET (jt_mark_t *, jtm, &sco->sco_jts)
    {
      if (jtm)
	{
	  int inx;
	  DO_BOX (ST *, as, inx, jtm->jtm_selection)
	    {
	      if (box_equal (as->_.as_exp.left, col_ref))
		{
		  col_ref->_.col_ref.prefix = t_box_string (jtm->jtm_prefix);
		  col_ref->_.col_ref.name = t_box_string (as->_.as_exp.name);
		  return;
		}
	    }
	  END_DO_BOX;
	}
    }
  END_DO_SET();
}
#else
#define sqlo_expand_jtc_col(sco, col_ref)
#endif

#define UDT_CHECK_NO_COL(cr,generate,tree) \
   if (!generate && cr) \
     { \
       if (cr->crr_dbe_col && NULL == strchr (tree->_.col_ref.prefix, '.')) \
	 cr = NULL; \
       else if (cr->crr_ssl && (cr->crr_ssl->ssl_dc_dtp != DV_OBJECT && cr->crr_ssl->ssl_dtp != DV_OBJECT)) \
	 cr = NULL; \
     }

col_ref_rec_t *
sqlo_find_col_ref (sql_comp_t *sc, ST * tree)
{
  col_ref_rec_t *cr = NULL;

  cr = sqlc_find_crr (sc, tree);
  if (cr)
    return cr;

  if (!sc->sc_super)
    {
      if (sc->sc_scroll_super)
	{
	  cr = sqlo_find_col_ref (sc->sc_scroll_super, tree);
	  if (cr)
	    return cr;
	}
    }

  if (sc->sc_super)
    {
      cr = sqlo_find_col_ref (sc->sc_super, tree);
      if (cr)
	return cr;
    }
  return NULL;
}


col_ref_rec_t *
sqlo_col_or_param_1 (sql_comp_t * sc, ST * tree, int generate)
{
  col_ref_rec_t *cr;
  if (!sc->sc_super)
    {
      if (sc->sc_scroll_super)
	{
	  cr = sqlc_col_ref_rec (sc, tree, 0);
	  UDT_CHECK_NO_COL (cr, generate, tree);
	  if (cr)
	    {
	      if (!cr->crr_ssl)
		SQL_GPF_T1 (sc->sc_cc, "no param of that name generated");
	      return cr;
	    }
	  else if (!sc->sc_so->so_is_rescope)
	    {
	      col_ref_rec_t *super_cr;

	      super_cr = sqlo_col_or_param_1 (sc->sc_scroll_super, tree, generate);
	      if (super_cr || generate)
		{
		  char temp[20];
		  int inx = 0, inx_found = -1;
		  t_NEW_VARZ (col_ref_rec_t, cr);
		  cr->crr_col_ref = tree;
		  t_set_push (&sc->sc_col_ref_recs, (void *) cr);
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
		      t_set_push (sc->sc_scroll_param_cols, tree);
		      inx_found = 0;
		    }
		  snprintf (temp, sizeof (temp), ":%d", inx_found);
		  cr->crr_ssl = ssl_new_parameter (sc->sc_cc, temp);
		  if (super_cr && super_cr->crr_ssl)
		    cr->crr_ssl->ssl_sqt = super_cr->crr_ssl->ssl_sqt;
		  return cr;
		}
	      else
		return NULL;
	    }
	  else
	    return NULL;
	}
      else
	{
	  cr = sqlc_col_ref_rec (sc, tree, 0);
	  UDT_CHECK_NO_COL (cr, generate, tree);
	  if (cr && !cr->crr_ssl)
	    SQL_GPF_T1 (sc->sc_cc, "no param of that name generated");
	  return cr;
	}
    }
  cr = sqlc_col_ref_rec (sc, tree, 0);
  UDT_CHECK_NO_COL (cr, generate, tree);
  if (cr)
    {
      if (!cr->crr_ssl)
	SQL_GPF_T1 (sc->sc_cc, "no param of that name generated");
      return cr;
    }

  /* Look in the super and make this a param */
  {
    col_ref_rec_t *super_cr = sqlo_col_or_param_1 (sc->sc_super, tree, generate);
    if (super_cr)
      {
	t_NEW_VARZ (col_ref_rec_t, cr);
	cr->crr_col_ref = tree;
	t_set_push (&sc->sc_col_ref_recs, (void *) cr);
	cr->crr_ssl = super_cr->crr_ssl;
	cr->crr_ct = super_cr->crr_ct;
	return cr;
      }
    else
      return NULL;
  }
}


int
sqlo_col_scope_1 (sqlo_t * so, ST * col_ref, int generate)
{
  sql_scope_t * sco = so->so_scope;
  if (col_ref->_.col_ref.name == STAR)
    sqlc_new_error (so->so_sc->sc_cc, "42000", "SQ064", "Illegal use of '*'.");
  if (!col_ref->_.col_ref.prefix)
    {
      col_ref_rec_t *cr;

      cr = sqlo_find_col_ref (so->so_sc, col_ref);

      if (generate)
	{
	  while (sco)
	    {
	      if (sco_is_defd (sco, col_ref, SCO_UNQUALIFIED, generate))
		{
		  if (cr)
		    {
		      sqlc_warning ("01V01", "QW002",
			  "The column %.*s in an SQL statement shadows the local variable of the same name."
			  "Either qualify the the column reference or use the AS to rename it",
			  MAX_NAME_LEN, col_ref->_.col_ref.name);
		    }
		  sqlo_expand_jtc_col (sco, col_ref);
		  return 1;
		}
	      sco = sco->sco_super;
	    }
	}
      if (NULL != (cr = sqlo_col_or_param_1 (so->so_sc, col_ref, generate)))
	{
	  if (!generate)
	    {
	      sco = so->so_scope;
	      while (sco)
		{
		  DO_SET (op_table_t *, ot, &sco->sco_tables)
		    {
		      if (P_EXACT == sqlc_pref_match (sqlo_ot_effective_prefix (ot), col_ref->_.col_ref.name))
			sqlc_new_error (sco->sco_so->so_sc->sc_cc, "37000", "UD103",
			    "Ambiguous reference to the prefix \"%.256s\". "
			    "It matches both a variable of user defined type and a table correlation name.",
			    col_ref->_.col_ref.name);
		    }
		  END_DO_SET ();
		  sco = sco->sco_super;
		}
	    }
	  return 1;
	}
      sco = so->so_scope;
      if (generate)
	{
	  while (sco)
	    {
	      if (sco_is_defd (sco, col_ref, SCO_ANY_QUAL, generate))
		{
		  sqlo_expand_jtc_col (sco, col_ref);
		  if (cr)
		    {
		      sqlc_warning ("01V01", "QW003",
			  "The column %.*s in an SQL statement shadows the local variable of the same name."
			  "Either qualify the the column reference or use the AS to rename it",
			  MAX_NAME_LEN, col_ref->_.col_ref.name);
		    }
		  return 1;
		}
	      sco = sco->sco_super;
	    }
	}
    }
  else
    {
      sco = so->so_scope;
      while (sco)
	{
	  if (sco_is_defd (sco, col_ref, SCO_THIS_QUAL, generate))
	    {
	      sqlo_expand_jtc_col (sco, col_ref);
	      return 1;
	    }
	  sco = sco->sco_super;
	}
      if (sqlo_col_or_param_1 (so->so_sc, col_ref, generate))
	return 1;
    }
  if (so->so_is_rescope && generate)
    return 1;
  if (!generate)
    return 0;
    {
      char cn[MAX_NAME_LEN * 5 + 10];
      if (col_ref->_.col_ref.prefix)
	snprintf (cn, sizeof (cn), "%s.%s", col_ref->_.col_ref.prefix, col_ref->_.col_ref.name);
      sqlc_error (so->so_sc->sc_cc, "S0022", "No column %s.", col_ref->_.col_ref.prefix ? cn : col_ref->_.col_ref.name);
    }
  return 0; /* dummy */
}

void
sqlo_union_scope (sqlo_t * so, ST ** ptree, ST * left)
{
  ST *tree = *ptree;
  if (ST_P (tree, SELECT_STMT))
    {
      int inx;
      op_table_t *ot;
      sqlc_top_select_dt (so->so_sc, tree);
      DO_BOX (ST *, as, inx, tree->_.select_stmt.selection)
	{
	  if (!ST_P (as, BOP_AS))
	    SQL_GPF_T (so->so_sc->sc_cc);
	  as->_.as_exp.name = ((ST*)left->_.select_stmt.selection[inx])->_.as_exp.name;
	}
      END_DO_BOX;
      sqlo_scope (so, ptree);
      tree = *ptree;
      ot = (op_table_t *) so->so_tables->data;
      ot->ot_left_sel = left;
    }
  else
    {
      sqlo_union_scope (so, &(tree->_.bin_exp.left), left);
      sqlo_union_scope (so, &(tree->_.bin_exp.right), left);
    }
}


void
sco_add_table (sql_scope_t * sco, op_table_t * ot)
{
  sqlo_t * so = sco->sco_so;
  caddr_t ot_pref = sqlo_ot_effective_prefix (ot);
  DO_SET (op_table_t *, ot_set, &sco->sco_tables)
    {
      if (sqlc_pref_match (sqlo_ot_effective_prefix (ot_set), ot_pref))
	sqlc_new_error (so->so_sc->sc_cc, "37000", "SQ143",
	    "Tables '%s' and '%s' have the same exposed names. Use correlation names to distinguish them.",
	    sqlo_ot_effective_prefix (ot), sqlo_ot_effective_prefix (ot_set));
    }
  END_DO_SET();
  so->so_this_dt->ot_from_ots = dk_set_conc  (so->so_this_dt->ot_from_ots, t_cons ((void*) ot, NULL));
  sco->sco_tables = dk_set_conc (sco->sco_tables, t_cons (ot, NULL));
}


void
sco_merge (sql_scope_t *old_sco, sql_scope_t *sco)
{
  DO_SET (op_table_t *, ot, &old_sco->sco_tables)
    {
      caddr_t ot_pref = sqlo_ot_effective_prefix (ot);
      DO_SET (op_table_t *, ot_set, &sco->sco_tables)
	{
	  if (sqlc_pref_match (sqlo_ot_effective_prefix (ot_set), ot_pref))
	    sqlc_new_error (sco->sco_so->so_sc->sc_cc, "37000", "SQ143",
		"Tables '%s' and '%s' have the same exposed names. Use correlation names to distinguish them.",
		sqlo_ot_effective_prefix (ot), sqlo_ot_effective_prefix (ot_set));
	}
      END_DO_SET ();
    }
  END_DO_SET ();
  old_sco->sco_tables = dk_set_conc (old_sco->sco_tables, sco->sco_tables);
  old_sco->sco_named_vars = dk_set_conc (old_sco->sco_named_vars, sco->sco_named_vars);
  old_sco->sco_jts = dk_set_conc (old_sco->sco_jts, sco->sco_jts);
  old_sco->sco_has_jt += sco->sco_has_jt;
}


caddr_t
sqlo_new_prefix (sqlo_t * so)
{
  char tmp[10];
  snprintf (tmp, sizeof (tmp), "dt%d", so->so_name_ctr++);
  return (t_box_string (tmp));
}


void
sqlo_natural_join_cond (sqlo_t * so, op_table_t * left_ot,
    op_table_t * right_ot, ST * tree)
{
  int inx;
  ST *ctree = NULL;
  ST *term;
  if (tree->_.join.is_natural
      || ST_P (tree->_.join.cond, JC_USING))
    {
      if (!tree->_.join.cond || tree->_.join.cond == (ST *) STAR)
	{
	  if (!left_ot->ot_table || !right_ot->ot_table)
	    sqlc_new_error (so->so_sc->sc_cc, "37000", "SQ066",
		"Natural join only allowed between tables or views. No derived tables or joins.");
	  DO_SET (dbe_column_t *, col, &left_ot->ot_table->tb_primary_key->key_parts)
	    {
	      dbe_column_t * col2 = tb_name_to_column (right_ot->ot_table, col->col_name);
	      if (!IS_BLOB_DTP (col->col_sqt.sqt_dtp)
		  && col2 &&!IS_BLOB_DTP (col2->col_sqt.sqt_dtp))
		{
		  ST *r1 = t_listst (3, COL_DOTTED,
		      t_box_string (sqlo_ot_effective_prefix (left_ot)),
		      t_box_string (col->col_name));
		  ST *r2 = t_listst (3, COL_DOTTED,
		      t_box_string (sqlo_ot_effective_prefix (right_ot)),
		      t_box_string (col->col_name));
		  BIN_OP (term, BOP_EQ, r1, r2);
		  t_st_and (&ctree, term);
		}
	    }
	  END_DO_SET ();
	}
      else if (ST_P (tree->_.join.cond, JC_USING))
	{
	  DO_BOX (caddr_t, col_name, inx, tree->_.join.cond->_.usage.cols)
	    {
	      ST *r1 = t_listst (3, COL_DOTTED,
		  t_box_string (sqlo_ot_effective_prefix (left_ot)),
		  t_box_string (col_name));
	      ST *r2 = t_listst (3, COL_DOTTED,
		  t_box_string (sqlo_ot_effective_prefix (right_ot)),
		  t_box_string (col_name));
	      BIN_OP (term, BOP_EQ, r1, r2);
	      t_st_and (&ctree, term);
	    }
	  END_DO_BOX;
	}
      else
	sqlc_new_error (so->so_sc->sc_cc, "37000", "SQ067",
	    "Explicit join condition not allowed in natural join");
      tree->_.join.is_natural = 0;
      tree->_.join.cond = ctree;
    }
  else
    {
      if (J_CROSS == tree->_.join.type)
	{
	  tree->_.join.cond = NULL;
	}
      else if (!tree->_.join.cond || ST_P (tree->_.join.cond, JC_USING))
	sqlc_new_error (so->so_sc->sc_cc, "37000", "SQ068",
	    "Empty or USING join condition not allowed with non-natural join");
    }
}


op_virt_col_t *
sqlo_virtual_col_crr (sqlo_t * so, op_table_t * ot, const char * name, dtp_t dtp, int is_out)
{
  op_virt_col_t *vc;
  DO_SET (op_virt_col_t *, pre, &ot->ot_virtual_cols)
    {
      if (0 == stricmp (pre->vc_tree->_.col_ref.name, name))
	return pre;
    }
  END_DO_SET();
  vc = (op_virt_col_t *) t_alloc (sizeof (op_virt_col_t));
  vc->vc_tree = t_listst (3, COL_DOTTED, ot->ot_new_prefix, t_box_string (name));
  vc->vc_dtp = dtp;
  vc->vc_is_out = is_out;
/*  if (ot && tb_name_to_column (ot->ot_table, name))
    sqlc_error (so->so_sc->sc_cc, "42S22",
	"Virtual column %s added to table %s when there is a real column with the same name",
	name, ot->ot_table->tb_name);*/
  t_set_push (&ot->ot_virtual_cols, vc);
  return vc;
}


void
sqlo_proc_table_cols (sqlo_t * so, op_table_t * ot)
{
  caddr_t * cols;
  int inx;
  ST *tree = ot->ot_dt;
  /*so->so_this_dt->ot_fixed_order = 1;*/

  DO_BOX (caddr_t, param, inx, tree->_.proc_table.params)
  {
    /*op_virt_col_t *vc = */sqlo_virtual_col_crr (so, ot, param, DV_UNKNOWN, 2);
  }
  END_DO_BOX;
  cols = (caddr_t *) tree->_.proc_table.cols;
  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (tree->_.proc_table.cols); inx += 2)
    {
      if (!cols[inx])
	continue;
      if (!sco_is_defd (so->so_scope,
	    t_listst (3, COL_DOTTED, ot->ot_prefix, t_box_string (cols[inx])),
	    ot->ot_prefix ? SCO_THIS_QUAL : SCO_UNQUALIFIED, 1))
	{
	  /*op_virt_col_t *vc = */sqlo_virtual_col_crr (so, ot, cols[inx], DV_UNKNOWN, 0);
	}
    }
}


ST *
sqlo_wrap_join_dt (sqlo_t *so, ST *tree)
{
  char tmp[30];
  int inx;
  ST **selection, **from;
  ST *texp, *sel, *ret;

  from = (ST **) t_list (1, tree);
  texp = t_listst (9, TABLE_EXP, from, NULL, NULL, NULL, NULL, NULL, NULL, NULL);
  selection = sqlp_stars ( (ST **) t_list (1, t_list (3, COL_DOTTED, NULL, STAR)),
      from);
  DO_BOX (ST *, elt, inx, selection)
    {
      snprintf (tmp, sizeof (tmp), "jtc%d", inx + 1);
      selection[inx] = t_listst (5, BOP_AS, elt, NULL, t_box_string (tmp), NULL);
    }
  END_DO_BOX;
  sel = (ST*) t_list (5, SELECT_STMT, NULL, selection, NULL, sqlp_infoschema_redirect (texp));
  snprintf (tmp, sizeof (tmp), "jt%d", so->so_name_ctr++);
  ret = t_listst (3, DERIVED_TABLE, sel, t_box_string (tmp));
  t_set_push (&so->so_scope->sco_jts, sel);
  return ret;
}


static void
sqlo_rls_add_condition (sqlo_t *so, op_table_t *ot, dk_set_t *res, dbe_table_t *tb)
{
  client_connection_t *cli = sqlc_client();
  if (tb->tb_rls_procs[TB_RLS_S] &&
      cli->cli_user && !sec_user_has_group (G_ID_DBA, cli->cli_user->usr_g_id))
    {
      caddr_t err = NULL;
      caddr_t ret_val = NULL;
      caddr_t sql_text = NULL;
      ST *tree = NULL, *t_tree;
      sql_scope_t sco;
      caddr_t ot_prefix = ot->ot_prefix;
      static char *select_mask =
	  "select 1 from \"%s\".\"%s\".\"%s\" where %s";
      query_t *proc_qr = sch_proc_def (isp_schema (NULL), tb->tb_rls_procs[TB_RLS_S]);


      ret_val = sqlc_rls_get_condition_string (tb, TB_RLS_S, &err);
      if (err)
	goto done;
      if (!DV_STRINGP (ret_val))
	goto done;


      sql_text = dk_alloc_box (strlen (tb->tb_name) * 2 + strlen (ret_val) + 500, DV_SHORT_STRING);
      snprintf (sql_text, box_length (sql_text) - 1, select_mask,
	  tb->tb_qualifier, tb->tb_owner, tb->tb_name_only, ret_val);
      dk_free_box (ret_val);
      ret_val = NULL;

      tree = (ST *) sql_compile_1 (sql_text, cli, &err, SQLC_PARSE_ONLY, NULL, proc_qr->qr_proc_name);
      dk_free_box (sql_text);
      sql_text = NULL;

      if (err)
	goto done;

      t_tree = (ST *) t_full_box_copy_tree ( (caddr_t) tree);
      dk_free_tree ((box_t) tree);
      tree = NULL;

      /* do the scope thing */
      memset (&sco, 0, sizeof (sql_scope_t));
      sco.sco_super = so->so_scope;
      sco.sco_so = so;
      so->so_scope = &sco;
      t_set_push (&(sco.sco_tables), ot);
      ot->ot_prefix = NULL;
      sqlo_scope (so, &(t_tree->_.select_stmt.table_exp->_.table_exp.where));
      so->so_scope = sco.sco_super;
      ot->ot_prefix = ot_prefix;
      t_set_push (res, t_list (6, JOINED_TABLE, NULL, NULL, NULL, NULL,
	    t_tree->_.select_stmt.table_exp->_.table_exp.where));
done:
      if (tree)
	dk_free_tree ((box_t) tree);
      if (sql_text)
	dk_free_tree (sql_text);
      if (ret_val)
	dk_free_tree (ret_val);
      sqlc_set_client (cli);
      if (err)
	{
	  if (DV_TYPE_OF (err) == DV_ARRAY_OF_POINTER)
	    {
	      char temp[1000];
	      char state[10];
	      snprintf (temp, sizeof (temp), "row level security: %.900s", ((char **) err)[2]);
	      strncpy (state, ((char **) err)[1], sizeof (state));
	      dk_free_tree (err);
	      sqlc_new_error (so->so_sc->sc_cc, state, "SQ191", temp);
	    }
	  else
	    sqlc_resignal_1 (so->so_sc->sc_cc, err);
	}
    }
}


void
sqlo_trans_cols (sqlo_t * so, op_table_t * ot)
{
  ST * trans = ot->ot_trans;
  if (trans->_.trans.min)
    sqlo_scope (so, &trans->_.trans.min);
  if (trans->_.trans.max)
    sqlo_scope (so, &trans->_.trans.max);
}


ST*
sqlo_with_decl (sqlo_t * so,  ST * tree)
{
  return NULL;
}


void
sqlo_add_table_ref (sqlo_t * so, ST ** tree_ret, dk_set_t *res)
{
  char tmp[10];
  ST * tree = *tree_ret;
  switch (tree->type)
    {
    case TABLE_REF:
      {
	ST * prev = tree->_.table_ref.table;
	if (ST_P (prev, SELECT_STMT))
	  {
	    tree->type = DERIVED_TABLE;
	    sqlp_view_def (NULL, tree->_.table_ref.table, 0);
	    sqlo_add_table_ref (so, tree_ret, res);
	    return;
	  }
	sqlo_add_table_ref (so, &tree->_.table_ref.table, res);
	if (prev != tree->_.table_ref.table)
	  *tree_ret = tree->_.table_ref.table;
	break;
      }
    case TABLE_DOTTED:
      {
	ST * with_view = sqlo_with_decl (so, tree);
	dbe_table_t *tb = with_view ? NULL : sch_name_to_table (wi_inst.wi_schema, tree->_.table.name);
	ST * view;
	if (!tb && !with_view)
	  sqlc_error (so->so_sc->sc_cc, "S0002", "No table %s", tree->_.table.name);
	if (inside_view)
	  tree->_.table.name = t_box_copy (tb->tb_name);
	if (!with_view)
	  {
	    sqlc_table_used (so->so_sc, tb);
	    view = (ST*) sch_view_def (wi_inst.wi_schema, tb->tb_name);
	  }
	else
	  view = with_view;
	if (!view || inside_view)
	  {
	    remote_table_t * rt = find_remote_table (tb->tb_name, 0);
	    t_NEW_VARZ (op_table_t, ot);
	    ot->ot_opts = ST_OPT (tree, caddr_t *, _.table.opts);
	    ot->ot_prefix = tree->_.table.prefix;
	    snprintf (tmp, sizeof (tmp), "t%d", so->so_name_ctr++);
	    ot->ot_new_prefix = t_box_string (tmp);
	    tree->_.table.prefix = ot->ot_new_prefix;
	    ot->ot_table = tb;
	    ot->ot_rds = rt ? rt->rt_rds : NULL;
	    ot->ot_u_id = (oid_t) unbox (tree->_.table.u_id);
	    ot->ot_g_id = (oid_t) unbox (tree->_.table.g_id);
	    if (ST_P (view, PROC_TABLE))
	      {
		ot->ot_dt = view;
		sqlo_proc_table_cols (so, ot);
		ot->ot_dt = NULL;
		ot->ot_is_proc_view = 1;
	      }
	    sqlo_rls_add_condition (so, ot, res, tb);
	    t_set_push (&so->so_tables, (void*) ot);
	    sco_add_table (so->so_scope, ot);
	  }
	else
	  {
	    op_table_t * ot = NULL;
	    if (!with_view && !sec_tb_check (tb, (oid_t) unbox (tree->_.table.u_id), (oid_t) unbox (tree->_.table.u_id), GR_SELECT))
	      sqlc_new_error (so->so_sc->sc_cc, "42000", "SQ070:SECURITY", "Must have select privileges on view %s", tb->tb_name);
	    view = (ST*) t_box_copy_tree ((caddr_t) view);
	    if (ST_P (view, UNION_ST) ||
		ST_P (view, UNION_ALL_ST) ||
		ST_P (view, EXCEPT_ST) ||
		ST_P (view, EXCEPT_ALL_ST) ||
		ST_P (view, INTERSECT_ST) ||
		ST_P (view, INTERSECT_ALL_ST))
	      {
		view = sqlp_view_def (NULL, view, 1);
		view = sqlc_union_dt_wrap (view);
	      }
	    sqlo_scope (so, &view);
	    if (ST_P (view, SELECT_STMT))
	      {
		ot = (op_table_t *) so->so_tables->data;
		ot->ot_prefix = tree->_.table.prefix ? tree->_.table.prefix :  tb->tb_name;
		sco_add_table (so->so_scope, ot);
	      }
	    else
	      {
		t_NEW_VARZ (op_table_t, ot2);
		memset (ot2, 0, sizeof (op_table_t));
		ot = ot2;
		ot->ot_dt = view;
		ot->ot_prefix = tree->_.table.prefix ? tree->_.table.prefix :  tb->tb_name;
		ot->ot_new_prefix = sqlo_new_prefix (so);
		ot->ot_left_sel = sqlp_union_tree_select (view);
		if (ST_P (view, PROC_TABLE))
		  {
		    sqlo_proc_table_cols (so, ot);
		    ot->ot_opts = ST_OPT (tree, caddr_t *, _.table.opts);
		    ot->ot_is_proc_view = 1;
		  }
		sco_add_table (so->so_scope, ot);
		t_set_push (&so->so_tables, (void*) ot);

	      }
	    sqlo_rls_add_condition (so, ot, res, tb);
	    *tree_ret = (ST*) t_list (3, DERIVED_TABLE, ot->ot_dt, ot->ot_new_prefix);
	  }
	break;
      }
    case JOINED_TABLE:
      {
	sql_scope_t *old_sco = so->so_scope;
	TNEW (sql_scope_t, sco);
	op_table_t *right_ot, *left_ot;
	s_node_t *ptr;
	ST *j_right;
	dk_set_t res_jt = NULL;
	int is_jtc, is_natural = (tree->_.join.is_natural &&
	    (!tree->_.join.cond || tree->_.join.cond == (ST *) STAR));


	memset (sco, 0, sizeof (sql_scope_t));
	sco->sco_so = so;
	sco->sco_fun_refs_allowed = old_sco->sco_fun_refs_allowed;
	sco->sco_super = so->so_scope->sco_super;
	so->so_scope = sco;

	if (OJ_RIGHT == tree->_.join.type)
	  {
	    ST * tmp = tree->_.join.left;
	    tree->_.join.left = tree->_.join.right;
	    tree->_.join.right = tmp;
	    tree->_.join.type = OJ_LEFT;
	  }
	j_right = tree->_.join.left;
	while (ST_P (j_right, TABLE_REF))
	  j_right = j_right->_.table_ref.table;
	is_jtc = ST_P (j_right, JOINED_TABLE);
	if (tree->_.join.type == OJ_FULL)
	  sco->sco_has_jt = 1;
	if (is_jtc && (!is_natural || (tree->_.join.type == OJ_LEFT || tree->_.join.type == OJ_FULL)))
	  sco->sco_has_jt = 1;
	j_right = tree->_.join.right;
	while (ST_P (j_right, TABLE_REF))
	  j_right = j_right->_.table_ref.table;
	is_jtc = ST_P (j_right, JOINED_TABLE);
	if (is_jtc && (!is_natural || (tree->_.join.type == OJ_LEFT || tree->_.join.type == OJ_FULL)))
	  sco->sco_has_jt = 1;
	sqlo_add_table_ref (so, &tree->_.join.left, res);
	left_ot = (op_table_t *) so->so_tables->data;
	sqlo_add_table_ref (so, &tree->_.join.right, is_jtc ? &res_jt : res);
	right_ot = (op_table_t *) so->so_tables->data;
	sqlo_natural_join_cond (so, left_ot, right_ot, tree);
	sqlo_scope (so, &(tree->_.join.cond));
	/* can be that the right subtree in a ij ends with oj in which case the right ot will be flagged outer. The cond in this case goes to to the top where, i.e. res, not to the join cond of the outer (optional) ot */
if (J_INNER == tree->_.join.type && right_ot->ot_is_outer)
  	  t_st_and (&right_ot->ot_enclosing_where_cond, tree->_.join.cond); /*always ste, even if some joins may be made into dts later*/

	else
	  t_st_and (&right_ot->ot_join_cond, tree->_.join.cond); /*always ste, even if some joins may be made into dts later*/
	sco_merge (old_sco, sco);
	so->so_scope = old_sco;
	if (tree->_.join.type == OJ_LEFT || tree->_.join.type == OJ_FULL)
	  right_ot->ot_is_outer = 1;
	else if (!sco->sco_has_jt && tree->_.join.type == J_INNER &&
	    !ST_P (left_ot->ot_dt, PROC_TABLE) &&
	    !ST_P (right_ot->ot_dt, PROC_TABLE))
	  {
	    t_set_push (res, tree);
	    break;
	  }
	break;
      }
    case DERIVED_TABLE:
      {
	op_table_t * ot;
	sqlo_scope (so, &(tree->_.table_ref.table));
	if (ST_P (tree->_.table_ref.table, SELECT_STMT))
	  {
	    ot = (op_table_t *) so->so_tables->data;
	    ot->ot_prefix = tree->_.table_ref.range;
	    tree->_.table_ref.range = ot->ot_new_prefix;
/*	    t_set_push (res, (void *) ot);*/
	    sco_add_table (so->so_scope, ot);
	    if (ot->ot_trans)
	      sqlo_trans_cols (so, ot);
	  }
	else
	  {
	    op_table_t *old_ot = so->so_tables ? (op_table_t *) so->so_tables->data : NULL;
	    t_NEW_VARZ (op_table_t, ot);
	    ot->ot_prefix = tree->_.table_ref.range;
	    ot->ot_dt = tree->_.table_ref.table;
	    ot->ot_new_prefix = sqlo_new_prefix (so);
	    tree->_.table_ref.range = ot->ot_new_prefix;
	    if (old_ot)
	      ot->ot_left_sel = old_ot->ot_left_sel;
	    else
	      ot->ot_left_sel = sqlp_union_tree_select (tree->_.table_ref.table);
	    if (ST_P (tree->_.table_ref.table, PROC_TABLE))
	      sqlo_proc_table_cols (so, ot);
/*	    t_set_push (res, (void *) ot);*/
	    sco_add_table (so->so_scope, ot);
	    t_set_push (&so->so_tables, (void*) ot);
	  }
	break;
      }
    }
}


void
sqlo_scope_array (sqlo_t * so, ST ** arr)
{
  int inx;
  _DO_BOX (inx, arr)
    {
      sqlo_scope (so, &(arr[inx]));
    }
  END_DO_BOX;
}


op_table_t *
sqlo_find_dt (sqlo_t * so, ST * tree)
{
  DO_SET (op_table_t *, ot, &so->so_tables)
    {
      if (ot->ot_dt == tree)
	return ot;
    }
  END_DO_SET();
  SQL_GPF_T1 (so->so_sc->sc_cc, "subq ot was supposed to be found given the tree");
  return NULL;
}


op_table_t *
sqlo_cname_ot_1 (sqlo_t * so, char * cname, int gpf_if_not)
{
  DO_SET (op_table_t *, ot, &so->so_tables)
    {
      if (box_equal (ot->ot_new_prefix, cname))
	return ot;
    }
  END_DO_SET();
  if (gpf_if_not)
    SQL_GPF_T1 (so->so_sc->sc_cc, "dt not found based on cname");
  return NULL;
}


op_table_t *
sqlo_cname_ot (sqlo_t * so, char * cname)
{
  return sqlo_cname_ot_1 (so, cname, 1);
}


void
sqlo_replace_col_refs_prefixes (sqlo_t *so, ST *tree, caddr_t old_prefix,
    ST **selection, int remove_as_decls)
{
  dtp_t dtp = DV_TYPE_OF (tree);
  if (ST_P (tree, ORDER_BY))
    remove_as_decls = 2;

  if (dtp == DV_ARRAY_OF_POINTER)
    {
      int inx;

      DO_BOX (ST *, elt, inx, ((ST **)tree))
	{
	  if (ST_COLUMN (elt, COL_DOTTED))
	    {
	      if (elt->_.col_ref.prefix &&
		  !CASEMODESTRCMP (elt->_.col_ref.prefix, old_prefix))
		{
		  int inx2;
		  ST *real_col = NULL;
		  DO_BOX (ST *, as_exp, inx2, selection)
		    {
		      if (0 == strcmp (as_exp->_.as_exp.name, elt->_.col_ref.name))
			{
			  real_col = as_exp;
			  goto found;
			}
		    }
		  END_DO_BOX;
found:
		  if (!real_col)
		    SQL_GPF_T1 (NULL, " ref in dt expansion to undefined column");
		  if (remove_as_decls)
		    while (ST_P (real_col, BOP_AS))
		      real_col = real_col->_.as_exp.left;
		  if (2 == remove_as_decls && DV_LONG_INT == DV_TYPE_OF (real_col))
		    real_col = listst (5, BOP_PLUS, real_col, 0, 0, 0);
		  ((ST **)tree)[inx] = (ST *) t_box_copy_tree ((caddr_t) real_col);
		}
	    }
	  else
	    {
	      /* the as decls are only kept for top level in select, not inside exps */
	      sqlo_replace_col_refs_prefixes (so, elt, old_prefix, selection, 1);
	    }
	}
      END_DO_BOX;
    }
}


static void
sqlo_replace_fun_refs_prefixes (ST *tree, caddr_t old_prefix, caddr_t new_prefix)
{
  int inx;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    return;
  if (ST_P (tree, FUN_REF) && BOX_ELEMENTS (tree) > 6 && tree->_.fn_ref.fn_name &&
      !CASEMODESTRCMP (tree->_.fn_ref.fn_name, old_prefix))
    {
      tree->_.fn_ref.fn_name = new_prefix;
      return;
    }
  DO_BOX (ST *, exp, inx, ((caddr_t*) tree))
    {
      sqlo_replace_fun_refs_prefixes (exp, old_prefix, new_prefix);
    }
  END_DO_BOX;
}

#ifndef NO_DT_EXPANSION

#define sqlp_is_union_wrap(tree) \
  (ST_P ((tree), SELECT_STMT) && \
      (tree)->_.select_stmt.table_exp && \
      BOX_ELEMENTS ((tree)->_.select_stmt.table_exp->_.table_exp.from) == 1 && \
      !(tree)->_.select_stmt.table_exp->_.table_exp.where && \
      !(tree)->_.select_stmt.table_exp->_.table_exp.group_by && \
      !(tree)->_.select_stmt.table_exp->_.table_exp.having && \
      !(tree)->_.select_stmt.table_exp->_.table_exp.order_by && \
      ST_P ((tree)->_.select_stmt.table_exp->_.table_exp.from[0], DERIVED_TABLE) && \
      IS_UNION_ST ((tree)->_.select_stmt.table_exp->_.table_exp.from[0]->_.table_ref.table))


static int
sqlo_dt_has_vcol_tables (sqlo_t *so, op_table_t *dot)
{
  /* if dot, the dt to be inlined select virtual cols from tables used inside, do not inline.
   * exception for text hit score */
  DO_SET (op_table_t *, ot, &dot->ot_from_ots)
    {
      DO_SET (op_virt_col_t *, vc, &ot->ot_virtual_cols)
	{
	  if (nc_strstr ((dtp_t*)"score", (dtp_t*)vc->vc_tree->_.col_ref.name))
	    continue;
	  if (box_is_subtree ((caddr_t) dot->ot_dt->_.select_stmt.selection, (caddr_t) vc->vc_tree))
	    return 1;
	}
      END_DO_SET();
    }
  END_DO_SET ();
  return 0;
}


int
sqlo_join_exp_inlineable (ST * exp)
{
  /* any join exp that does not have a full oj */
  if (ST_P (exp, JOINED_TABLE)
      && OJ_FULL == exp->_.join.type)
    return 0;
  if (ST_P (exp, UNION_ST) || ST_P (exp, UNION_ALL_ST)
      || ST_P (exp, INTERSECT_ST) || ST_P (exp, INTERSECT_ALL_ST)
      ||ST_P (exp, EXCEPT_ST) || ST_P (exp, EXCEPT_ALL_ST))
    return 0;
  if (ST_P (exp, SELECT_STMT))
    return 1;
  else if (ARRAYP (exp))
    {
      int inx;
      DO_BOX (ST *, s, inx, exp)
	{
	  if (!sqlo_join_exp_inlineable (s))
	    return 0;
	}
      END_DO_BOX;
      return 1;
    }
  else
    return 1;
}


int
sqlo_oj_has_const (ST * tree)
{
  /* if a rhs of left oj is a select with constant exps, this cannot be inlined because the constant must be a variable in order to be null. */ 
  int inx;
  if (!ST_P (tree, SELECT_STMT))
    return 0;
  DO_BOX (ST *, exp, inx, tree->_.select_stmt.selection)
    {
      if (!sqlo_has_node (exp, COL_DOTTED))
	return 1;
    }
  END_DO_BOX;
  return 0;
}


int enable_dt_inline = 1;

int
sqlo_dt_inlineable (sqlo_t *so, ST *tree, ST * from, op_table_t *ot, int single_only)
{
  ST *dtexp = from->_.table_ref.table;
  ST *dt_orig = ST_P (dtexp, SELECT_STMT) ? dtexp->_.select_stmt.table_exp : NULL;
  if (!enable_dt_inline)
    return 0;
  if (ST_P (dtexp, SELECT_STMT) &&
      !dtexp->_.select_stmt.top &&
      dt_orig &&
      !sqlo_opt_value (ST_OPT (dt_orig, caddr_t *, _.table_exp.opts), OPT_ORDER) &&
      !dt_orig->_.table_exp.group_by &&
      !dt_orig->_.table_exp.having &&
      !dt_orig->_.table_exp.order_by &&
      !sqlp_is_union_wrap (dtexp)
      )
    {
      int dt_inx;
      op_table_t *dot = sqlo_find_dt (so, dtexp);
      if (dot->ot_fun_refs)
	return 0;
      if (sqlo_dt_has_vcol_tables (so, dot))
	return 0;
      DO_BOX (ST *, dt_from, dt_inx, dt_orig->_.table_exp.from)
	{
	  if (single_only && dt_inx > 0)
	    return 0;
	  while (ST_P (dt_from, TABLE_REF))
	    dt_from = dt_from->_.table_ref.table;
	  if (single_only && sqlo_oj_has_const (dtexp))
	    return 0;
	  if (single_only && ST_P (dt_from, JOINED_TABLE))
	    return 0;
	  if (ST_P (dt_from, JOINED_TABLE)
	      && !sqlo_join_exp_inlineable (dt_from))
	    return 0;
	}
      END_DO_BOX;
      if (sqlo_print_debug_output)
	{
	  sqlo_print (("Expanding %s(%s) [%s]: \n",
		dot->ot_prefix, dot->ot_new_prefix,
		dot->ot_table ? dot->ot_table->tb_name : "(NONE)"));
	}
      return enable_dt_inline;
    }
  return 0;
}


void
sqlo_expand_dt (sqlo_t *so, ST *tree, ST ** from_ret, op_table_t *ot, int is_in_jt, dk_set_t *new_froms)
{
  /* inline the dt in *from so it is  inlined in the from clause of tree.  The where of the dt merges into the where of the enclosing.  If the dt is inside a joined table, the list of tables becomes a cross join with the where inside the where of the enclosing.  If the inlined dt is in a from commalist, flatten the dt's tables  into the from */
  ST *texp = tree->_.select_stmt.table_exp;
  ST *from = *from_ret;
  ST *dtexp = from->_.table_ref.table;
  op_table_t *dot = sqlo_find_dt (so, dtexp);
  int dot_opts_len;

  sqlo_replace_col_refs_prefixes (so, (ST *) tree->_.select_stmt.selection, dot->ot_new_prefix,
				  (ST **) dtexp->_.select_stmt.selection, 0);
  sqlo_replace_col_refs_prefixes (so, tree->_.select_stmt.table_exp, dot->ot_new_prefix,
				  (ST **) dtexp->_.select_stmt.selection, 1);
  sqlo_replace_fun_refs_prefixes (tree, dot->ot_new_prefix, ot->ot_new_prefix);
  if (dtexp->_.select_stmt.table_exp->_.table_exp.where)
    t_st_and (dot->ot_fun_refs ?
	      &texp->_.table_exp.having :
	      &texp->_.table_exp.where, dtexp->_.select_stmt.table_exp->_.table_exp.where);
  t_set_delete (&so->so_tables, dot);
  t_set_delete (&ot->ot_from_ots, dot);
  ot->ot_from_ots = dk_set_conc (ot->ot_from_ots, dot->ot_from_ots);
  DO_SET (ST *, fn_ref, &dot->ot_fun_refs)
    {
      if (!strcmp (fn_ref->_.fn_ref.fn_name, dot->ot_new_prefix))
	fn_ref->_.fn_ref.fn_name = ot->ot_new_prefix;
    }
  END_DO_SET ();
  ot->ot_fun_refs = dk_set_conc (ot->ot_fun_refs, dot->ot_fun_refs);
  if (dot->ot_join_cond)
    t_st_and (&ot->ot_join_cond, dot->ot_join_cond);

  if (is_in_jt)
    {
      /* make the tables of the dt into a join exp. */
      ST * res_exp = dtexp->_.select_stmt.table_exp->_.table_exp.from[0];
      if (BOX_ELEMENTS (dtexp->_.select_stmt.table_exp->_.table_exp.from) > 1)
	{
	  int n_new = BOX_ELEMENTS (dtexp->_.select_stmt.table_exp->_.table_exp.from);
	  int inx2;

	  for (inx2 = 1; inx2 < n_new; inx2++)
	    {
	      ST *felt = dtexp->_.select_stmt.table_exp->_.table_exp.from[inx2];
	      res_exp = listst (6, JOINED_TABLE, (ptrlong)0, J_CROSS, res_exp, felt, NULL);
	    }
	}
      *from_ret = res_exp;
    }
  else
    {
      t_set_push (new_froms, (void*)dtexp->_.select_stmt.table_exp->_.table_exp.from[0]);
      if (BOX_ELEMENTS (dtexp->_.select_stmt.table_exp->_.table_exp.from) > 1)
	{
	  int n_new = BOX_ELEMENTS (dtexp->_.select_stmt.table_exp->_.table_exp.from);
	  int inx2;
	  for (inx2 = 1; inx2 < n_new; inx2++)
	    {
	      ST *felt = dtexp->_.select_stmt.table_exp->_.table_exp.from[inx2];
	      t_set_push (new_froms, felt);
	    }
	}
    }
  dot_opts_len = BOX_ELEMENTS_0 (dot->ot_opts);
  if (0 != dot_opts_len)
    {
      int ot_opts_len = BOX_ELEMENTS_0 (ot->ot_opts);
      if (0 != ot_opts_len)
        {
#if 1
          ot->ot_opts = t_list_concat ((caddr_t)(ot->ot_opts), (caddr_t)(dot->ot_opts));
#else
          caddr_t *new_ot_opts = (caddr_t *)t_alloc_box ((ot_opts_len + dot_opts_len) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
          memcpy (new_ot_opts, ot->ot_opts, ot_opts_len * sizeof (caddr_t));
          memcpy (new_ot_opts + ot_opts_len, dot->ot_opts, dot_opts_len * sizeof (caddr_t));
          dk_free_tree (ot->ot_opts);
          ot->ot_opts = new_ot_opts;
#endif
        }
      else
        ot->ot_opts = (caddr_t *)t_box_copy_tree ((caddr_t)(dot->ot_opts));
    }
}


int
sqlo_inline_jt (sqlo_t * so, ST * tree, ST * exp, op_table_t * ot)
{
  /* take a tree of joined tables and inline dt's where can.  Ret 1 if anything changed */
  int inx, any = 0;
  if (ST_P (exp, JOINED_TABLE))
    {
      if (OJ_FULL == exp->_.join.type)
	return 0;
      if (sqlo_dt_inlineable (so, tree, exp->_.join.left, ot, 0))
	{
	  sqlo_expand_dt (so, tree, &exp->_.join.left, ot, 1, NULL);
	  any = 1;
	}
      else if (ST_P (exp->_.join.left, TABLE_REF) && ST_P (exp->_.join.left->_.table_ref.table, JOINED_TABLE))
	any += sqlo_inline_jt (so, tree, exp->_.join.left->_.table_ref.table, ot);
      if (OJ_LEFT == exp->_.join.type
	  && sqlo_dt_inlineable (so, tree, exp->_.join.right, ot, 1))
	{
	  /* left oj with single table dt to the right. */
	  ST * texp = exp->_.join.right->_.table_ref.table->_.select_stmt.table_exp;
	  t_st_and (&exp->_.join.cond, texp->_.table_exp.where);
	  texp->_.table_exp.where = NULL;
	  sqlo_expand_dt (so, tree, &exp->_.join.right, ot, 1, NULL);
	  any++;
	}
      if (!any && J_INNER == exp->_.join.type && sqlo_dt_inlineable (so, tree, exp->_.join.right, ot, 0))
	{
	  sqlo_expand_dt (so, tree, &exp->_.join.right, ot, 1, NULL);
	  any = 1;
	}
      return any;
    }
  if (ST_P (exp, SELECT_STMT))
    return 0;
  else  if (ARRAYP (exp))
    {
      DO_BOX (ST *, s, inx, (ST**)exp)
	{
	  any += sqlo_inline_jt (so, tree, s, ot);
	}
      END_DO_BOX;
      return any;
    }
  return 0;
}


int
sqlo_expand_dt_1 (sqlo_t * so, ST * tree, op_table_t * ot)
{
  int inx, has_dt_expanded = 0;
  dk_set_t new_froms = NULL;
  ST * texp = tree->_.select_stmt.table_exp;
  DO_BOX (ST *, from, inx, texp->_.table_exp.from)
    {
      if (ST_P (from, DERIVED_TABLE))
	{
	  if (!sqlo_dt_inlineable (so, tree, from, ot, 0))
	    t_set_push (&new_froms, from);
	  else
	    {
	      sqlo_expand_dt (so, tree, &texp->_.table_exp.from[inx], ot, 0, &new_froms);
	      has_dt_expanded = 1;
	    }
	}
      else if (ST_P (from, TABLE_REF) && ST_P (from->_.table_ref.table, JOINED_TABLE))
	{
	  int is_exp = sqlo_inline_jt (so, tree, from, ot);
	  t_set_push (&new_froms, (void*)from);
	  has_dt_expanded += is_exp;
	}
      else
	t_set_push (&new_froms, (void*)from);
    }
  END_DO_BOX;
  if (has_dt_expanded)
    texp->_.table_exp.from = (ST**)t_list_to_array (dk_set_nreverse (new_froms));
  return has_dt_expanded;
}
#endif

static void
sqlo_replace_as_exps (ST **tree, sql_scope_t *sco)
{
  if (!sco || !sco->sco_named_vars)
    return;
  if (!tree || !*tree)
    return;
  if (DV_TYPE_OF (*tree) != DV_ARRAY_OF_POINTER)
    return;
  if (ST_COLUMN ((*tree), COL_DOTTED) && !(*tree)->_.col_ref.prefix)
    {
      DO_SET (ST **, as_exp, &sco->sco_named_vars)
	{
	  if (!CASEMODESTRCMP (as_exp[0]->_.col_ref.name, (*tree)->_.col_ref.name))
	    {
	      *tree = (ST *) t_box_copy_tree ((caddr_t) as_exp[1]);
	      return;
	    }
	}
      END_DO_SET();
    }
  else
    {
      int inx;
      _DO_BOX (inx, (ST **) (*tree))
	{
	  sqlo_replace_as_exps (&(((ST **) (*tree))[inx]), sco);
	}
      END_DO_BOX;
    }
}


const char *
sqlo_spec_predicate_name (ptrlong pred_type)
{
  switch (pred_type)
    {
    case 'c': return "contains";
    case 'p': return "xpath_contains";
    case 'q': return "xquery_contains";
    case 'x': return "xcontains";
    }
  return "special predicate (e.g. xcontains)";
}

void
sqlo_check_ft_offband (sqlo_t * so, op_table_t * ot, ST ** args, char type)
{
  unsigned inx, argcount = BOX_ELEMENTS(args);
  unsigned surely_option_idx = (('x' == type) ? 4 : (('c' == type) ? 2 : 3));
  dk_set_t off = NULL;
  sql_comp_t *sc = so->so_sc;
  for (inx = 2; inx < argcount; inx++)
    {
      ST *arg = args[inx];
      if (!DV_STRINGP (arg))
        {
	  if (inx >= surely_option_idx)
	    sqlc_error (sc->sc_cc, "37000", "Argument %d of %s should be a keyword, i.e. a symbol", inx + 1, sqlo_spec_predicate_name(type));
	  continue;
	}
      if (0 == stricmp ((char *) arg, "OFFBAND"))
	{
	  ptrlong oinx;
	  dbe_column_t ** ocols = tb_text_key (ot->ot_table)->key_text_col->col_offband_cols;
	  if (BOX_ELEMENTS (args) <= inx + 1 || !ST_COLUMN (args[inx + 1], COL_DOTTED))
	    sqlc_error (sc->sc_cc, "37000", "offband in contains must be a column name");
	  if (!ocols)
	    sqlc_error (sc->sc_cc, "37000", "The table %.300s does not have offband text columns", ot->ot_table->tb_name);
	  DO_BOX (dbe_column_t *, ocol, oinx,ocols)
	    {
	      if (0 == stricmp (ocol->col_name, args[inx + 1]->_.col_ref.name))
		{
		  op_virt_col_t *sc_crr;
		  sc_crr = sqlo_virtual_col_crr (so, ot, ocol->col_name,
		      ocol->col_sqt.sqt_dtp, 1);
		  dk_set_push (&off, (void*) sc_crr);
		  dk_set_push (&off, (void*) oinx);
		  goto offb_done;
		}
	    }
	  END_DO_BOX;
	  sqlc_error (sc->sc_cc, "37000", "No offband column '%.300s' in %.300s", args[inx + 1]->_.col_ref.name, ot->ot_table->tb_name);
	offb_done:
	  inx++;
	  continue;
	}
/* Single keywords arguments */
      if ((0 == stricmp ((char *)arg, "desc")) || (0 == stricmp ((char *)arg, "descending")))
	{
	  ot->ot_text_desc = 1;
	  continue;
	}
/* Keyword - columnname	argument pairs, note 'inx++' before 'continue' */
      if ((0 == stricmp ((char *)arg, "ranges")) || (0 == stricmp ((char *)arg, "main_ranges")))
	{
	  if (BOX_ELEMENTS (args) <= inx + 1 || !ST_COLUMN (args[inx + 1], COL_DOTTED))
	    sqlc_error (sc->sc_cc, "37000",
		"The %s argument of %s must reference a column", (char *)arg, sqlo_spec_predicate_name (type));
	  ot->ot_main_range_out = sqlo_virtual_col_crr (so, ot, args[inx + 1]->_.col_ref.name, DV_ARRAY_OF_POINTER, 1);
	  inx++;
	  continue;
	}
      if (0 == stricmp ((char *)arg, "score"))
	{
	  if (BOX_ELEMENTS (args) <= inx + 1 || !ST_COLUMN (args[inx + 1], COL_DOTTED))
	    sqlc_error (sc->sc_cc, "37000",
		"The SCORE argument of %s must reference a column", (char *)arg, sqlo_spec_predicate_name (type));
	  ot->ot_text_score = sqlo_virtual_col_crr (so, ot, args[inx + 1]->_.col_ref.name, DV_LONG_INT, 1);
	  inx++;
	  continue;
	}
      if (0 == stricmp ((char *)arg, "attr_ranges"))
	{
	  if (BOX_ELEMENTS (args) <= inx + 1 || !ST_COLUMN (args[inx + 1], COL_DOTTED))
	    sqlc_error (sc->sc_cc, "37000",
		"The ATTR_RANGES argument of %s must reference a column", sqlo_spec_predicate_name (type));
	  ot->ot_attr_range_out = sqlo_virtual_col_crr (so, ot, args[inx + 1]->_.col_ref.name, DV_ARRAY_OF_POINTER, 1);
	  inx++;
	  continue;
	}
      if (0 == stricmp ((char *) arg, "start_id"))
	{
	  if (BOX_ELEMENTS (args) <= inx + 1)
	    sqlc_error (sc->sc_cc, "37000", "contains START_ID option must have an argument");
	  ot->ot_text_start = args[inx + 1];
	  inx++;
	  continue;
	}
      if (0 == stricmp ((char *) arg, "end_id"))
	{
	  if (BOX_ELEMENTS (args) <= inx + 1)
	    sqlc_error (sc->sc_cc, "37000", "contains END_ID option must have an argument");
	  ot->ot_text_end = args[inx + 1];
	  inx++;
	  continue;
	}
      if (0 == stricmp ((char *) arg, "score_limit"))
	{
	  if (BOX_ELEMENTS (args) <= inx + 1)
	    sqlc_error (sc->sc_cc, "37000", "contains SCORE_LIMIT option must have an argument");
	  ot->ot_text_score_limit = args[inx + 1];
	  inx++;
	  continue;
	}
      if (0 == stricmp ((char *) arg, "ext_fti"))
	{
	  if (BOX_ELEMENTS (args) <= inx + 1)
	    sqlc_error (sc->sc_cc, "37000", "contains EXT_FTI option must have an argument");
	  ot->ot_ext_fti = args[inx + 1];
	  inx++;
	  continue;
	}
      if (inx >= surely_option_idx)
	sqlc_error (sc->sc_cc, "37000",
          "Argument %d of %s is '%.300s', not a keyword from list OFFBAND, DESCENDING, RANGES, MAIN_RANGES, ATTR_RANGES, SCORE, SCORE_LIMIT, EXT_FTI, GEO, GEO_RDF, PRECISION",
	  inx + 1, sqlo_spec_predicate_name(type), arg );
    }
  if (off)
    ot->ot_text_offband = (op_virt_col_t **) list_to_array (off);
}


void
sqlo_xpath_col (sqlo_t * so, op_table_t * ot, ST ** args, int nth, char ctype)
{
  sql_comp_t *sc = so->so_sc;
  dbe_column_t *text_col;
  op_virt_col_t *crr;
  ot->ot_text = args[0];
  text_col = tb_name_to_column (ot->ot_table, args[0]->_.col_ref.name);
  if (!text_col)
    sqlc_error (sc->sc_cc, "37000", "%s first argument not a column", sqlo_spec_predicate_name (ctype));
  if (text_col->col_xml_base_uri)
    {
      ST *ucol = (ST *) t_list (3, COL_DOTTED, t_box_copy (ot->ot_new_prefix),
	  t_box_copy (text_col->col_xml_base_uri));
      ot->ot_base_uri = ucol;
    }
  if (BOX_ELEMENTS (args) <= 2)
    return;
  if (-1 == nth)
    {
      if (BOX_ELEMENTS (args) >= 3 && ST_COLUMN (args[2], COL_DOTTED))
	nth = 2; /* this is for e.g. xpath_contains (col, pattern, fragment); */
      else if (BOX_ELEMENTS (args) >= 4 && ST_COLUMN (args[3], COL_DOTTED) && !DV_STRINGP(args[2]))
	nth = 3; /* this is for e.g. xcontains (col, pattern, 0, fragment); */
      else
	return;
    }
  if (!ST_COLUMN (args[nth], COL_DOTTED))
    sqlc_error (sc->sc_cc, "37000", "XPATH output must be a column reference in %s", sqlo_spec_predicate_name (ctype));
  crr = sqlo_virtual_col_crr (so, ot, args[nth]->_.col_ref.name, DV_SHORT_STRING, 1);
  ot->ot_xpath_value = crr;
}

static int
sqlo_select_ref_score (ST *tree)
{
  if (!tree || DV_TYPE_OF (tree) != DV_ARRAY_OF_POINTER)
    return 0;
  if (ST_COLUMN ((tree), COL_DOTTED))
    {
      if (tree->_.col_ref.name != STAR && !CASEMODESTRCMP ("SCORE", (tree)->_.col_ref.name))
	return 1;
    }
  else
    {
      int inx;
      _DO_BOX (inx, (ST **) (tree))
	{
	  if (sqlo_select_ref_score (((ST **)tree)[inx]))
	    return 1;
	}
      END_DO_BOX;
    }
  return 0;
}

int
sqlo_implied_columns_of_contains (sqlo_t *so, ST *tree, int add_score)
{
  ST **args;
  int ctype;

  if (DV_TYPE_OF (tree) != DV_ARRAY_OF_POINTER)
    return 0;

  if (BOX_ELEMENTS (tree) > 1 && NULL != (args = sqlc_contains_args (tree, &ctype)))
    {
      op_table_t *ot;
      if (BOX_ELEMENTS(args) < 1 || !ST_COLUMN (args[0], COL_DOTTED))
	sqlc_error (so->so_sc->sc_cc, "37000",
	    "The first argument of %s must be a column", sqlo_spec_predicate_name (ctype));

      ot = sco_is_defd (so->so_scope, args[0],
	  args[0]->_.col_ref.prefix ? SCO_THIS_QUAL : SCO_UNQUALIFIED, 1);
      if (!ot || !ot->ot_table)
	sqlc_error (so->so_sc->sc_cc, "37000",
	    "The first argument of %s must reference a column", sqlo_spec_predicate_name (ctype));
      if (ot->ot_contains_exp)
	sqlc_new_error (so->so_sc->sc_cc, "37000", "SQ040",
	    "Can't have more than 1 %s for table %s", sqlo_spec_predicate_name (ctype), ot->ot_table->tb_name);
      ot->ot_contains_exp = tree;

      args[0]->_.col_ref.prefix = ot->ot_prefix;
      switch (ctype)
        {
        case 'c': case 'x':
	{
	  dbe_key_t *text_key;
	  if (sqlo_is_contains_vdb_tb (so, ot, ctype, args))
	    {
	      if (NULL == ot->ot_text_score)
		ot->ot_text_score = sqlo_virtual_col_crr (so, ot, "SCORE", DV_LONG_INT, 1);
	    }
	  else
	    {
	      if (NULL == (text_key = tb_text_key (ot->ot_table)))
		sqlc_error (so->so_sc->sc_cc, "37000",
		    "Table referenced in %s does not have a text index", sqlo_spec_predicate_name (ctype));
	      if (ctype == 'x' || ctype == 'c')
		sqlo_check_ft_offband (so, ot, args, (char) ctype);
	      if (NULL == ot->ot_text_score && add_score)
		ot->ot_text_score = sqlo_virtual_col_crr (so, ot, "SCORE", DV_LONG_INT, 1);
	      if ((ctype == 'x') || (NULL != ot->ot_main_range_out))
		{
		  sqlo_xpath_col (so, ot, args, -1, ctype);
		  if (NULL == ot->ot_main_range_out)
		    ot->ot_main_range_out = sqlo_virtual_col_crr (so, ot, "xcontains_main_ranges", DV_ARRAY_OF_POINTER, 1);
		  if (NULL == ot->ot_attr_range_out)
		    ot->ot_attr_range_out = sqlo_virtual_col_crr (so, ot, "xcontains_attr_ranges", DV_ARRAY_OF_POINTER, 1);
		}
	    }
	  break;
	}
	case 'p': case 'q':
	  sqlo_xpath_col (so, ot, args, 2, ctype);
	  if (BOX_ELEMENTS(args) > 3)
	    sqlc_error (so->so_sc->sc_cc, "37000",
	      "Too many arguments passed to %s", sqlo_spec_predicate_name (ctype));
	  break;
	default: GPF_T;
	}
      return 1;
    }
  if (ST_P (tree, BOP_AND))
    {
      if (!sqlo_implied_columns_of_contains (so, tree->_.bin_exp.left, add_score))
	return sqlo_implied_columns_of_contains (so, tree->_.bin_exp.right, add_score);
      else
	return 1;
    }
  else
    return 0;
}

void
sqlo_jt_replace_col_refs (ST ** tree, caddr_t new_pref, ST **selection, ST *jt, int do_aliases)
{
  int inx;
  if (*tree == jt)
    return;
  else if (ST_COLUMN ((*tree), COL_DOTTED))
    {
      DO_BOX (ST *, as_exp, inx, selection)
	{
	  ST *sel = as_exp->_.as_exp.left;
	  if ((*tree)->_.col_ref.prefix &&
	      !CASEMODESTRCMP (sel->_.col_ref.prefix, (*tree)->_.col_ref.prefix) &&
	      !CASEMODESTRCMP (sel->_.col_ref.name, (*tree)->_.col_ref.name))
	    {
	      if (do_aliases)
		{
		  *tree = t_listst (5, BOP_AS,
		      t_list (3, COL_DOTTED, new_pref, as_exp->_.as_exp.name), NULL,
		      sel->_.col_ref.name, NULL);
		}
	      else
		{
		  (*tree)->_.col_ref.prefix = new_pref;
		  (*tree)->_.col_ref.name = as_exp->_.as_exp.name;
		}
	      return;
	    }
	}
      END_DO_BOX;
    }
  else if (ARRAYP ((*tree)))
    {
      for (inx = 0; inx < BOX_ELEMENTS_INT ((*tree)); inx++)
	sqlo_jt_replace_col_refs (&(((ST **)(*tree))[inx]), new_pref, selection, jt, do_aliases);
    }
}


static void
sqlo_jt_dt_get_ft_conds (sqlo_t *so, ST **cond, ST *tref)
{
  op_table_t *ot;

  while (ST_P (tref, TABLE_REF))
    tref = tref->_.table_ref.table;
  if (!ST_P (tref, TABLE_DOTTED))
    return;
  ot = sqlo_cname_ot (so, tref->_.table.prefix);

  if (ot->ot_contains_exp)
    {
      ST *new_op;
      t_st_and (cond, (ST *) t_box_copy ((caddr_t) ot->ot_contains_exp));
      BIN_OP (new_op, BOP_EQ, (ST *) t_box_num_and_zero (0), (ST *) t_box_num_and_zero (0));
      memcpy (ot->ot_contains_exp, new_op, sizeof (sql_tree_t));
    }
}


int
sqlo_jt_dt_wrap (sqlo_t *so, ST **jptr, ST *select_stmt, int was_top, int replace_col_refs)
{
  int res = 0;
  while (ST_P (*jptr, TABLE_REF))
    jptr = &(*jptr)->_.table_ref.table;
  if (ST_P (*jptr, JOINED_TABLE))
    {
      int inx;
      char buffer[20];
      caddr_t jtm_prefix;
      ST **sel, *texp, *tb;

      res += 1;
      snprintf (buffer, sizeof (buffer), "jtc%d", so->so_name_ctr++);
      jtm_prefix = t_box_string (buffer);
      if (sqlo_print_debug_output)
	sqlo_box_print (jtm_prefix);
      sel = sqlp_stars ((ST **) t_list(1, t_list (3, COL_DOTTED, NULL, STAR)), (ST **) t_list (1, *jptr));
      texp = t_listst (9, TABLE_EXP,
	  t_list (1,
	    *jptr),
	  NULL, NULL, NULL, NULL, NULL, NULL, NULL);
      sqlo_jt_dt_get_ft_conds (so, &(texp->_.table_exp.where), (*jptr)->_.join.left);
      sqlo_jt_dt_get_ft_conds (so, &(texp->_.table_exp.where), (*jptr)->_.join.right);
      tb = t_listst (3,
	  DERIVED_TABLE,
	  t_listst (5,
	    SELECT_STMT, NULL, sel, NULL, sqlp_infoschema_redirect (texp)),
	  jtm_prefix);
      DO_BOX (ST *, sexp, inx, sel)
	{
	  snprintf (buffer, sizeof (buffer), "jtcol%d", inx + 1);
	  sel[inx] = t_listst (5, BOP_AS, sexp, NULL, t_box_string (buffer), NULL);
	}
      END_DO_BOX;
      if (replace_col_refs)
	{
	  sqlo_jt_replace_col_refs (&select_stmt, jtm_prefix, sel, *jptr, 0);
	  if (was_top)
	    {
	      DO_BOX (ST *, sel_exp, inx, select_stmt->_.select_stmt.selection)
		{
		  if (ST_COLUMN (sel_exp, COL_DOTTED))
		    {
		      if (!CASEMODESTRCMP (sel_exp->_.col_ref.prefix, jtm_prefix))
			{
			  int col_inx = atoi (sel_exp->_.col_ref.name + 5);
			  if (!col_inx || col_inx > BOX_ELEMENTS_INT (sel))
			    SQL_GPF_T1 (so->so_sc->sc_cc, "an unknown column detected in jt");
			  if (!IS_FOR_XML (select_stmt))
			    {
			      ((ST **)select_stmt->_.select_stmt.selection)[inx] =
				  t_listst (5, BOP_AS, sel_exp, NULL,
				      sel[col_inx - 1]->_.as_exp.left->_.col_ref.name, NULL);
			    }
			  else
			    {
			      /* the idea here is the we stick the original column prefix
				 in the as_exp.right and use it in FOR XML AUTO as
				 the original prefix will get overwritten by the
				 second sqlo_scope for nested joins */
			      op_table_t *ot = sqlo_cname_ot (so,
				  sel[col_inx - 1]->_.as_exp.left->_.col_ref.prefix);
			      char *orig_name = ot->ot_prefix ? ot->ot_prefix : ot->ot_table->tb_name_only;

			      ((ST **)select_stmt->_.select_stmt.selection)[inx] =
				  t_listst (5, BOP_AS, sel_exp, t_box_string (orig_name),
				      sel[col_inx - 1]->_.as_exp.left->_.col_ref.name, NULL);
			    }
			}
		      else if (IS_FOR_XML (select_stmt))
			{
			  op_table_t *ot = sqlo_cname_ot (so, sel_exp->_.col_ref.prefix);
			  char *orig_name = ot->ot_prefix ? ot->ot_prefix : ot->ot_table->tb_name_only;

			  ((ST **)select_stmt->_.select_stmt.selection)[inx] =
			      t_listst (5, BOP_AS, sel_exp, t_box_string (orig_name),
				  sel_exp->_.col_ref.name, NULL);
			}
		    }
		  else if (IS_FOR_XML (select_stmt) && ST_P (sel_exp, BOP_AS))
		    {
		      ST *as = sel_exp;
		      caddr_t real_name = NULL;
		      while (ST_P (as, BOP_AS))
			{
			  if (as->_.as_exp.right)
			    real_name = (caddr_t) as->_.as_exp.right;
			  as = as->_.as_exp.left;
			}
		      if (ST_COLUMN (as, COL_DOTTED) && !real_name)
			{
			  if (!strcmp (jtm_prefix, as->_.col_ref.prefix))
			    {
			      int col_inx = atoi (as->_.col_ref.name + 5);
			      op_table_t *ot;

			      if (!col_inx || col_inx > BOX_ELEMENTS_INT (sel))
				SQL_GPF_T1 (so->so_sc->sc_cc, "an unknown column detected in jt");
			      ot = sqlo_cname_ot (so,
				  sel[col_inx - 1]->_.as_exp.left->_.col_ref.prefix);
			      real_name = ot->ot_prefix ? ot->ot_prefix : ot->ot_table->tb_name_only;
			    }
			  else
			    {
			      op_table_t *ot = sqlo_cname_ot (so, as->_.col_ref.prefix);
			      real_name = ot->ot_prefix ? ot->ot_prefix : ot->ot_table->tb_name_only;
			    }
			}
		      if (real_name)
			sel_exp->_.as_exp.right = (ST *) t_box_string (real_name);
		    }
		}
	      END_DO_BOX;
	    }
	}
      *jptr = tb;
    }
  return res;
}


int
sqlo_expand_jts (sqlo_t *so, ST **ptree, ST *select_stmt, int was_top)
{
  int res = 0;
  ST *tree = *ptree;
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &tree, 8000))
    sqlc_error (so->so_sc->sc_cc, ".....", "Stack Overflow");
  if (DK_MEM_RESERVE)
    sqlc_error (so->so_sc->sc_cc, ".....", "Out of memory");
  if (ST_P (tree, SELECT_STMT))
    {
      res += sqlo_expand_jts (so, &tree->_.select_stmt.table_exp, tree, select_stmt ? 0 : 1);
      res += sqlo_expand_jts (so, (ST **) &tree->_.select_stmt.selection, tree, select_stmt ? 0 : 1);
    }
  else if (ST_P (tree, TABLE_REF) &&
      ST_P (tree->_.table_ref.table, JOINED_TABLE) &&
      tree->_.table_ref.table->_.join.type == OJ_FULL &&
      !tree->_.table_ref.range)
    { /* need to add an alias for the table as it'll be changed to select */
      char buffer[20];
      ST *left;
      caddr_t jtm_prefix;

      snprintf (buffer, sizeof (buffer), "fjtc%d", so->so_name_ctr++);
      jtm_prefix = tree->_.table_ref.range = t_box_string (buffer);
      res += sqlo_expand_jts (so, &tree->_.table_ref.table, select_stmt, was_top);
      left = sqlp_union_tree_select (tree->_.table_ref.table->_.select_stmt.table_exp->_.table_exp.from[0]->_.table_ref.table);
      sqlo_jt_replace_col_refs (&select_stmt, jtm_prefix,
	  (ST **)left->_.select_stmt.selection, tree, 0);
      if (was_top)
	{
	  int inx;
	  ST **sel = (ST **)left->_.select_stmt.selection;
	  DO_BOX (ST *, sel_exp, inx, select_stmt->_.select_stmt.selection)
	    {
	      if (ST_COLUMN (sel_exp, COL_DOTTED) &&
		  !CASEMODESTRCMP (sel_exp->_.col_ref.prefix, jtm_prefix))
		{
		  int col_inx = atoi (sel_exp->_.col_ref.name + 5);
		  if (!col_inx || col_inx > BOX_ELEMENTS_INT (sel))
		    GPF_T1 ("an unknown column detected in jt");
		  ((ST **)select_stmt->_.select_stmt.selection)[inx] =
		      t_listst (5, BOP_AS, sel_exp, NULL,
			  sel[col_inx - 1]->_.as_exp.left->_.col_ref.name, NULL);
		}
	    }
	  END_DO_BOX;
	}
    }
  else if (ST_P (tree, JOINED_TABLE) && select_stmt)
    {
      res += sqlo_expand_jts (so, &tree->_.join.left, select_stmt, was_top);
      res += sqlo_expand_jts (so, &tree->_.join.right, select_stmt, was_top);
      if (0 == res && (J_INNER == tree->_.join.type || J_CROSS == tree->_.join.type))
	return res;
      if (OJ_LEFT != tree->_.join.type)
	res += sqlo_jt_dt_wrap (so, &tree->_.join.left, select_stmt, was_top, 1);
      if (OJ_RIGHT != tree->_.join.type)
	res += sqlo_jt_dt_wrap (so, &tree->_.join.right, select_stmt, was_top, 1);

      if (tree->_.join.type == OJ_FULL)
	{
	  ST *left_oj_tree = (ST *) t_box_copy_tree ((caddr_t) tree);
	  ST *right_oj_tree = (ST *) t_box_copy_tree ((caddr_t) tree);

	  left_oj_tree->_.join.type = OJ_LEFT;
	  right_oj_tree->_.join.type = OJ_RIGHT;

	  res += sqlo_jt_dt_wrap (so, &left_oj_tree, select_stmt, 1, 0);
	  res += sqlo_jt_dt_wrap (so, &right_oj_tree, select_stmt, 1, 0);

	  *ptree = t_listst (5, UNION_ST, left_oj_tree->_.table_ref.table,
	      right_oj_tree->_.table_ref.table, NULL, 0);
	  *ptree = sqlc_union_dt_wrap (*ptree);
	  res ++;
	}
    }
  else if (ST_P (tree, CALL_STMT))
    {
      int inx;
      DO_BOX (ST *, par, inx, tree->_.call.params)
	{
	  res += sqlo_expand_jts (so, &par, select_stmt, was_top);
	}
      END_DO_BOX;
    }
  else if (ST_P (tree, COALESCE_EXP) ||
      ST_P (tree, SIMPLE_CASE) ||
      ST_P (tree, SEARCHED_CASE) ||
      ST_P (tree, COMMA_EXP))
    {
      int inx;
      _DO_BOX (inx, tree->_.comma_exp.exps)
	{
	  res += sqlo_expand_jts (so, &(tree->_.comma_exp.exps[inx]), select_stmt, was_top);
	}
      END_DO_BOX;
    }
  else if (ARRAYP (tree))
    {
      int inx;
      for (inx = 0; inx < BOX_ELEMENTS_INT (tree); inx++)
	res += sqlo_expand_jts (so, &(((ST **)tree)[inx]), select_stmt, was_top);
    }
  return res;
}

int
sqlo_join_reffed_outside (ST *tree, ST *stop_at, char *prefix)
{
  if (!IS_BOX_POINTER (tree) || tree == stop_at)
    return 0;
  else if (DV_TYPE_OF (tree) == DV_ARRAY_OF_POINTER)
    {
      if (ST_COLUMN (tree, COL_DOTTED) && box_equal (prefix, tree->_.col_ref.prefix))
	return 1;
      else
	{
	  int inx = 0;
	  DO_BOX (ST *, elt, inx, ((ST **)tree))
	    {
	      if (sqlo_join_reffed_outside (elt, stop_at, prefix))
		return 1;
	    }
	  END_DO_BOX;
	}
    }
  return 0;
}


caddr_t
sqlo_opt_value (caddr_t * opts, int opt)
{
  int inx, len;
  if (!opts)
    return NULL;
  len = BOX_ELEMENTS (opts);
  for (inx = 0; inx < len; inx += 2)
    {
      if ((ptrlong) opts[inx] == opt)
	return (opts[inx + 1]);
    }
  return NULL;
}


dk_set_t
t_set_diff_ordered (dk_set_t s, dk_set_t minus)
{
  return dk_set_nreverse (t_set_diff (s, minus));
}


void
sqlo_expand_distinct_joins (sqlo_t * so, ST *tree, op_table_t *sel_ot, dk_set_t *res)
{
  int inx;
  if (!tree->_.select_stmt.table_exp || !SEL_IS_DISTINCT (tree))
    return;
  _DO_BOX (inx, tree->_.select_stmt.table_exp->_.table_exp.from)
    {
      ST **tbp = & (tree->_.select_stmt.table_exp->_.table_exp.from[inx]);
      if (ST_P (*tbp, TABLE_REF))
	tbp = & (*tbp)->_.table_ref.table;

      if (ST_P (*tbp, JOINED_TABLE) && ((*tbp)->_.join.type == OJ_LEFT || (*tbp)->_.join.type == OJ_FULL))
	{
	  ST *rtb = (*tbp)->_.join.right;
	  op_table_t *ot = NULL;
	  if (ST_P (rtb, TABLE_REF))
	    rtb = rtb->_.table_ref.table;
	  if (ST_P (rtb, TABLE_DOTTED))
	    ot = sqlo_cname_ot (so, rtb->_.table.prefix);
	  else if (ST_P (rtb, DERIVED_TABLE))
	    ot = sqlo_find_dt (so, rtb->_.table_ref.table);
	  if (ot && !sqlo_join_reffed_outside (tree, (*tbp)->_.join.cond, ot->ot_new_prefix))
	    {
	      if (sqlo_print_debug_output)
		{
		  sqlo_print (("Dropping the joined table %s(%s) [%s]\n",
			ot->ot_prefix, ot->ot_new_prefix,
			ot->ot_table ? ot->ot_table->tb_name : "(NONE)"));
		}
	      if (ot->ot_from_ots)
		{
		  so->so_tables = t_set_diff_ordered (so->so_tables, ot->ot_from_ots);
		  so->so_scope->sco_tables = t_set_diff (so->so_tables, ot->ot_from_ots);
		  sel_ot->ot_from_ots = t_set_diff (sel_ot->ot_from_ots, ot->ot_from_ots);
		}
	      t_set_delete (&so->so_tables, ot);
	      t_set_delete (&so->so_scope->sco_tables, ot);
	      t_set_delete (res, (*tbp)->_.join.cond);
	      t_set_delete (&sel_ot->ot_from_ots, ot);
	      *tbp = (*tbp)->_.join.left;
	    }
	}
    }
  END_DO_BOX;
}


void
sqlo_expand_group_by (caddr_t *selection, ST ***p_group_by, ptrlong *p_is_distinct)
{
  int inx, inx2, all_found = 1;
  ST **group_by = *p_group_by;
  if (!selection || !group_by ||
      BOX_ELEMENTS (selection) !=
      BOX_ELEMENTS (group_by) ||
      *p_is_distinct)
    return;
  DO_BOX (ST *, exp, inx, selection)
    {
      while (ST_P (exp, BOP_AS))
	exp = exp->_.as_exp.left;
      DO_BOX (ST *, spec, inx2, group_by)
	{
	  if (box_equal ((box_t) spec->_.o_spec.col, (box_t) exp))
	    goto next_exp;
	}
      END_DO_BOX;
      all_found = 0;
      goto done;
next_exp:;
    }
  END_DO_BOX;
done:
  if (all_found)
    {
      /* if all the columns in the group by are in distinct then make it a distinct */
      *p_is_distinct = 1;
      *p_group_by = NULL;
    }
}


int
sqlo_has_col_ref (ST * tree)
{
  int inx;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    return 0;
  if (ST_COLUMN (tree, COL_DOTTED))
    return 1;
  DO_BOX (ST *, exp, inx, ((caddr_t*) tree))
    {
      if (sqlo_has_col_ref (exp))
	return 1;
    }
  END_DO_BOX;
  return 0;
}


dk_set_t
sqlo_st_connective_list (ST * tree, int op)
{
  if (ST_P (tree, op))
    {
      return (dk_set_conc (sqlo_st_connective_list (tree->_.bin_exp.left, op),
			   sqlo_st_connective_list (tree->_.bin_exp.right, op)));
    }
  else
    return (t_cons (tree, NULL));
}


void
t_st_or (ST ** cond, ST * pred)
{
  if (!*cond)
    *cond = pred;
  else
    {
      ST *res;
      BIN_OP (res, BOP_OR, *cond, pred);
      *cond = res;
    }
}


int
st_equal_no_serial (box_t st1, box_t st2)
{
  /*compare but ignore serial nos for bin preds */
  dtp_t dtp1 = DV_TYPE_OF (st1);
  dtp_t dtp2 = DV_TYPE_OF (st2);
  if (dtp1 == dtp2 && dtp1 == DV_ARRAY_OF_POINTER
      && BIN_EXP_P ((ST*) st1)
      && ((ST*) st1)->type == ((ST*)st2)->type)
    {
      return (box_equal ((box_t) ((ST*)st1)->_.bin_exp.left, (box_t)((ST*)st2)->_.bin_exp.left)
	      && box_equal ((box_t) ((ST*)st1)->_.bin_exp.right, (box_t)((ST*)st2)->_.bin_exp.right));
    }

  return box_equal (st1, st2);
}


ST *
sqlo_bop_expand_or (sqlo_t * so, ST * tree)
{
  /* that will move the repeating parts of an OR predicate outside it */
  dk_set_t or_list = sqlo_st_connective_list (tree, BOP_OR);
  if (dk_set_length (or_list) > 1)
    {
      ST *additional_ands = NULL;
      ST *first_or = (ST *) t_set_pop (&or_list);
      dk_set_t first_and_list = sqlo_st_connective_list (first_or, BOP_AND);
      dk_set_t and_lists = NULL;
      DO_SET (ST *, or_elt, &or_list)
	{
	  dk_set_t and_list = sqlo_st_connective_list (or_elt, BOP_AND);
	  t_set_push (&and_lists, and_list);
	}
      END_DO_SET ();
      and_lists = dk_set_nreverse (and_lists);
      DO_SET (ST *, first_and_elt, &first_and_list)
	{
          int have_it_everywhere = 1;
	  if (!ts_predicate_p (first_and_elt->type) || -1 == cmp_op_inverse (first_and_elt->type) ||
	      !sqlo_has_col_ref (first_and_elt))
	    {
	      have_it_everywhere = 0;
	      goto next_and;
	    }
	  DO_SET (dk_set_t, and_list, &and_lists)
	    {
	      s_node_t *iter;
	      int have_it_here = 0;
	      DO_SET_WRITABLE (ST *, and_elt, iter, &and_list)
		{
		  if (BIN_EXP_P (first_and_elt) && BIN_EXP_P (and_elt) &&
		      first_and_elt->type != and_elt->type &&
		      first_and_elt->type == cmp_op_inverse (and_elt->type))
		    {
		      ST *tmp = and_elt->_.bin_exp.left;
		      and_elt->type = cmp_op_inverse (and_elt->type);
		      and_elt->_.bin_exp.left = and_elt->_.bin_exp.right;
		      and_elt->_.bin_exp.right = tmp;
		    }
		  if (st_equal_no_serial ((box_t) and_elt, (box_t) first_and_elt))
		    {
		      have_it_here = 1;
		      iter->data = first_and_elt;
		      goto next_or;
		    }
		}
	      END_DO_SET ();
	      if (!have_it_here)
		{
		  have_it_everywhere = 0;
		  goto next_and;
		}
next_or:;
	    }
	  END_DO_SET ();
next_and:
	  if (have_it_everywhere)
	    {
	      s_node_t *iter;
	      t_st_and (&additional_ands, first_and_elt);
	      t_set_delete (&first_and_list, first_and_elt);
	      DO_SET_WRITABLE (dk_set_t, and_list, iter, &and_lists)
		{
		  t_set_delete (&and_list, first_and_elt);
		  iter->data = and_list;
		}
	      END_DO_SET ();
	    }
	}
      END_DO_SET ();

      if (additional_ands)
	{
	  ST * right_and = NULL, *right = NULL;
	  DO_SET (ST *, first_and, &first_and_list)
	    {
	      t_st_and (&right_and, first_and);
	    }
	  END_DO_SET ();
	  if (right_and)
	    t_st_or (&right, right_and);

	  DO_SET (dk_set_t, and_list, &and_lists)
	    {
	      right_and = NULL;
	      DO_SET (ST *, and_elt, &and_list)
		{
		  t_st_and (&right_and, and_elt);
		}
	      END_DO_SET ();
	      if (right_and)
		t_st_or (&right, right_and);
	    }
	  END_DO_SET ();
	  if (right)
	    t_st_and (&additional_ands, right);
	  tree = additional_ands;
	}
    }
  return tree;
}


#ifdef SQLO_NO_BOP_EXPAND_OR
int sqlo_bop_expand_or_enabled = 0;
#endif

ST *
sqlo_bop_expand_or_exp (sqlo_t *so, ST *tree)
{
#ifdef SQLO_NO_BOP_EXPAND_OR
  if (sqlo_bop_expand_or_enabled)
    {
#endif
      dk_set_t and_list = sqlo_st_connective_list (tree, BOP_AND);
      ST *new_where = NULL;
      int have_new_ands = 0;
      DO_SET (ST *, and_elt, &and_list)
	{
	  ST * new_and_elt = sqlo_bop_expand_or (so, and_elt);
	  if (and_elt != new_and_elt)
	    have_new_ands = 1;

	  t_st_and (&new_where, new_and_elt);
	}
      END_DO_SET ();
      if (have_new_ands)
	return new_where;
#ifdef SQLO_NO_BOP_EXPAND_OR
    }
#endif
  return tree;
}


static void
sqlo_check_group_by_cols (sqlo_t *so, ST *tree, ST *** group, op_table_t *dt_ot, int is_not_one_gb)
{
  int inx;
  if (DV_TYPE_OF (tree) != DV_ARRAY_OF_POINTER)
    return;
  else if (ST_P (tree, FUN_REF))
    return;
  DO_BOX (ST *, spec, inx, (*group))
    {
      if (box_equal ((box_t) tree, (box_t) spec->_.o_spec.col))
	return;
      if (ST_P (spec->_.o_spec.col, BOP_AS))
	{
	  spec = spec->_.o_spec.col;
	  while (ST_P (spec, BOP_AS))
	    spec = spec->_.as_exp.left;
	  if (box_equal ((box_t) tree, (box_t) spec))
	    return;
	}
    }
  END_DO_BOX;
  if (ST_COLUMN (tree, COL_DOTTED) && tree->_.col_ref.prefix)
    {
      DO_SET (op_table_t *, ot, &dt_ot->ot_from_ots)
	{
	  if (!strcmp (tree->_.col_ref.prefix, ot->ot_new_prefix) && !is_not_one_gb)
	    {
	      ST ** new_group;
#if 0
	      sqlc_new_error (so->so_sc->sc_cc, "37000", "SQ150",
		  "Column '%.100s' is invalid in the select list because it is not contained"
		  " in either an aggregate function or the GROUP BY clause.",
		  tree->_.col_ref.name);
#endif
	      new_group = (ST **) t_alloc_box (((group[0] ? BOX_ELEMENTS (group[0]) : 0) + 1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	      DO_BOX (ST *, spec, inx, group[0])
		{
		  new_group [inx] = spec;
		}
	      END_DO_BOX;
	      new_group [inx] = t_listst (4, ORDER_BY, t_box_copy_tree ((caddr_t) tree), ORDER_ASC, NULL);
	      *group = new_group;
	    }
	}
      END_DO_SET ();
    }
  DO_BOX (ST *, exp, inx, ((ST **)tree))
    {
      sqlo_check_group_by_cols (so, exp, group, dt_ot, is_not_one_gb);
    }
  END_DO_BOX;
}


static void
sqlo_oby_remove_scalar_exps (sqlo_t *so, ST *** oby)
{ /* remove all scalar order by's (as they do not contribute nothing) */
  dk_set_t set = NULL;
  int have_const_obys = 0, inx;

  DO_BOX (ST *, spec, inx, (*oby))
    {
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (spec->_.o_spec.col))
	{
	  t_set_push (&set, spec);
	}
      else
	have_const_obys = 1;
    }
  END_DO_BOX;

  if (have_const_obys)
    *oby = set ? (ST **) t_list_to_array (dk_set_nreverse (set)) : NULL;
}



/* remove identity self join */


int
sqlo_is_col (ST * tree, caddr_t pref, caddr_t col)
{
  return (ST_COLUMN (tree, COL_DOTTED) && tree->_.col_ref.prefix && !strcmp (tree->_.col_ref.prefix, pref) && !strcmp (tree->_.col_ref.name, col));
}


int
sqlo_cols_eq (dk_set_t top_and, caddr_t col, caddr_t pref1, caddr_t pref2)
{
  /* true if inside top_and there is pref1.col = pref2.col or if there is pref1.col = x and pref2.col = x */
  ST * val1 = NULL, * p1 = NULL;
  ST * val2 = NULL, *p2 = NULL;
  DO_SET (ST*, pred, &top_and)
    {
      if (!ST_P (pred, BOP_EQ))
	continue;
      if (sqlo_is_col (pred->_.bin_exp.left, pref1, col))
	{
	  if (sqlo_is_col (pred->_.bin_exp.right, pref2, col))
	    return 1;
	  p1 = pred;
	  val1 = pred->_.bin_exp.right;
	}
      if (sqlo_is_col (pred->_.bin_exp.right, pref1, col))
	{
	  if (sqlo_is_col (pred->_.bin_exp.left, pref2, col))
	    return 1;
	  p1 = pred;
	  val1 = pred->_.bin_exp.left;
	}
      if (sqlo_is_col (pred->_.bin_exp.left, pref2, col))
	{
	  if (sqlo_is_col (pred->_.bin_exp.right, pref1, col))
	    return 1;
	  p2 = pred;
	  val2 = pred->_.bin_exp.right;
	}
      if (sqlo_is_col (pred->_.bin_exp.right, pref2, col))
	{
	  if (sqlo_is_col (pred->_.bin_exp.left, pref1, col))
	    return 1;
	  p2 = pred;
	  val2 = pred->_.bin_exp.left;
	}
    }
  END_DO_SET();
  if (p1 && p2 && box_equal (val1, val2))
    return 1;
  return 0;
}


int
sqlo_is_identity_join (op_table_t * ot1, op_table_t * ot2, dk_set_t top_and)
{
  /* in top and, enough col = same col between ot1 and ot2 to make unique */
  DO_SET (dbe_key_t *, key, &ot1->ot_table->tb_keys)
    {
      int nth_part = 0;
      int unq_limit = key->key_is_unique ? key->key_decl_parts : key->key_n_significant;
      if (!key->key_is_primary && !key->key_is_unique)
	continue;
      DO_SET (dbe_column_t *, col, &key->key_parts)
	{
	  if (!sqlo_cols_eq (top_and, col->col_name, ot1->ot_new_prefix, ot2->ot_new_prefix))
	    goto next_key;
	  if (++nth_part == unq_limit)
	    return 1;
	}
      END_DO_SET();
    next_key: ;
    }
  END_DO_SET();
  return 0;
}


void
sqlo_col_pref_replace (ST * tree, caddr_t old_pref, caddr_t new_pref)
{
  if (ST_COLUMN (tree, COL_DOTTED) && !strcmp (tree->_.col_ref.prefix, old_pref))
    {
      tree->_.col_ref.prefix = new_pref;
      return;
    }
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree))
    {
      int inx;
      DO_BOX (ST *, elt, inx, ((ST**)tree))
	{
	  sqlo_col_pref_replace (elt, old_pref, new_pref);
	}
      END_DO_BOX;
    }
}


void
t_box_rem_at_inx (ST *** place, int inx)
{
  ST ** org = *place;
  int d = 0, s;
  *place = (ST**)t_alloc_box (sizeof (caddr_t) * (BOX_ELEMENTS (org) - 1), DV_ARRAY_OF_POINTER);
  for (s = 0; s  < BOX_ELEMENTS (org); s++)
    {
      if (s != inx)
	(*place)[d++] = org[s];
    }
}

dk_set_t
sqlo_and_list (ST * tree)
{
  if (!ST_P (tree, BOP_AND))
    return t_cons (tree, NULL);
  return dk_set_conc (sqlo_and_list (tree->_.bin_exp.left), sqlo_and_list (tree->_.bin_exp.right));
}


#define tref_table(t) (t)->_.table_ref.table

void
sqlo_identity_self_join (sqlo_t *so, ST ** ptree)
{
  ST * tree = *ptree;
  ST * texp = tree->_.select_stmt.table_exp;
  int inx;
  dk_set_t top_and = NULL;
  if (!texp || !texp->_.table_exp.where)
    return;
  if (!so->so_identity_joins)
    return;
  DO_BOX (ST *, t1, inx, texp->_.table_exp.from)
    {
      int inx2;
      t1 = tref_table (t1);
      if (!ST_P (t1, TABLE_DOTTED))
	continue;
      for (inx2 = inx + 1; inx2 < BOX_ELEMENTS (texp->_.table_exp.from); inx2++)
	{
	  ST * t2 = texp->_.table_exp.from[inx2];
	  t2 = tref_table (t2);
	  if (ST_P  (t2, TABLE_DOTTED)
	      && 0 == strcmp (t1->_.table.name, t2->_.table.name))
	    {
	      op_table_t * ot1 = sqlo_cname_ot_1 (so, t1->_.table.prefix, 1);
	      op_table_t * ot2 = sqlo_cname_ot_1 (so, t2->_.table.prefix, 1);
	      if (!top_and)
		top_and = sqlo_and_list (texp->_.table_exp.where);
	      if (sqlo_is_identity_join (ot1, ot2, top_and))
		{
		  char old_rescope = so->so_is_rescope;
		  sqlo_col_pref_replace (tree, ot2->ot_new_prefix, ot1->ot_new_prefix);
		  t_box_rem_at_inx (&texp->_.table_exp.from, inx2);
		  so->so_is_rescope = 1;
		  /*sqlo_scope (so, ptree); - no need to rescope when only removing.  rescoping will re-rename things and only one rename is desired because must be able to map from org to renamed for hash build side dts */
		  so->so_is_rescope = old_rescope;
		  return;
		}
	    }
	}
    }
  END_DO_BOX;
}

/*
   We check all columns in gb are in select list, if so the distinct is redundant.
   The columns in gb can't be less than selection as in previous step for checking gb, missing columns are added in selection  
*/
static int
sqlo_distinct_redundant (ST * sel, ST * gb)
{
  int inx, inx2, found;
  DO_BOX (ST *, spec, inx, (ST **)gb)
    {
      spec = spec->_.o_spec.col;
      while (ST_P (spec, BOP_AS))
	spec = spec->_.as_exp.left;
      found = 0;
      DO_BOX (ST *, exp, inx2, (ST **) sel)
	{
	  while (ST_P (exp, BOP_AS))
	    exp = exp->_.as_exp.left;
	  while (ST_P (exp, CALL_STMT) && sqlo_is_unq_preserving (exp->_.call.name))
	    exp = exp->_.call.params[0];
	  if (box_equal (exp, spec))
	    {
	      found = 1;
	      break;
	    }
	}
      END_DO_BOX;
      if (!found)
	return 0;
    }
  END_DO_BOX;
  return 1;
}

void
sqlo_select_scope (sqlo_t * so, ST ** ptree)
{
  ST *tree = *ptree;
  char tmp[10];
  ST *texp = tree->_.select_stmt.table_exp;
  ST *top_exp = SEL_TOP (tree);
  int inx;
  op_table_t * old_dt = so->so_this_dt;
  dk_set_t res = NULL;
#ifndef NO_DT_EXPANSION
#endif
  TNEW (op_table_t, ot);
  TNEW (sql_scope_t, sco);
  memset (sco, 0, sizeof (sql_scope_t));
  memset (ot, 0, sizeof (op_table_t));

  if (texp && sqlo_opt_value (ST_OPT (texp, caddr_t *, _.table_exp.opts), OPT_SPARQL))
    so->so_identity_joins = 1;

  so->so_this_dt = ot;
  sco->sco_so = so;
  sco->sco_super = so->so_scope;
  so->so_scope = sco;

  texp = tree->_.select_stmt.table_exp;
  top_exp = SEL_TOP (tree);
  ot->ot_dt = tree;
  ot->ot_left_sel = sqlp_union_tree_select (tree);
  snprintf (tmp, sizeof (tmp), "dt%d", so->so_name_ctr++);
  ot->ot_new_prefix = t_box_string (tmp);

  if (top_exp && box_length ((caddr_t*)top_exp) > (ptrlong)&((ST*)0)->_.top.trans && NULL != top_exp->_.top.trans)
    {
      ot->ot_trans = top_exp->_.top.trans;
      top_exp = NULL;
    }
  if (top_exp)
    {
      ot->ot_is_top = 1;
      if (top_exp->_.top.ties)
	ot->ot_is_top_ties = 1;
      if (DV_LONG_INT != DV_TYPE_OF (top_exp->_.top.exp))
	{
	  top_exp->_.top.exp = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("_cvt"),
	      t_list (2, t_list (2, QUOTE, t_listst (2, (ptrlong)DV_LONG_INT, (ptrlong)0)), top_exp->_.top.exp));
	}
      sqlo_scope (so, &(top_exp->_.top.exp));
      if (DV_LONG_INT != DV_TYPE_OF (top_exp->_.top.skip_exp))
	{
	  top_exp->_.top.skip_exp = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("_cvt"),
	      t_list (2, t_list (2, QUOTE, t_listst (2, (ptrlong)DV_LONG_INT, (ptrlong)0)), top_exp->_.top.skip_exp));
	}
      sqlo_scope (so, &(top_exp->_.top.skip_exp));
    }

  if (texp)
    {
      ot->ot_opts = ST_OPT (texp, caddr_t *, _.table_exp.opts);
      ot->ot_fixed_order = (int)(ptrlong) sqlo_opt_value (ot->ot_opts, OPT_ORDER);
      _DO_BOX (inx, texp->_.table_exp.from)
	{
	  sqlo_add_table_ref (so, &texp->_.table_exp.from[inx], &res);
	}
      END_DO_BOX;
      sqlo_implied_columns_of_contains (so, texp->_.table_exp.where, sqlo_select_ref_score ((ST*) tree));
      sqlo_scope (so, &(texp->_.table_exp.where));
      DO_SET (ST *, jc, &res)
	{
	  t_st_and (&texp->_.table_exp.where, jc->_.join.cond);
	}
      END_DO_SET();
      sco->sco_fun_refs_allowed = 1;
      DO_BOX (ST *, as, inx, tree->_.select_stmt.selection)
	{
	  if (ST_P (as, BOP_AS))
	    {
	      ST *as_value_left = as->_.as_exp.left;
	      ST *as_value = as_value_left;
	      if (INTEGERP (as_value))
		{
		  BIN_OP (as_value, BOP_PLUS, as_value_left, (ST *) t_box_num (0));
		}
	      t_set_push (&sco->sco_named_vars, t_list (2,
		    t_list (3, COL_DOTTED, NULL, t_box_string (as->_.as_exp.name)),
		    t_box_copy_tree ((caddr_t) as_value)));
	    }
	}
      END_DO_BOX;
      sqlo_scope_array  (so, (ST**) tree->_.select_stmt.selection);
      /* if a single row is to be returned the order by really does not matter */
      if (ot->ot_fun_refs && !texp->_.table_exp.group_by)
	texp->_.table_exp.order_by = NULL;
      sqlo_replace_as_exps (&(texp->_.table_exp.having), so->so_scope);
      sqlo_scope (so, &(texp->_.table_exp.having));
      sqlo_replace_as_exps ((ST **) &(texp->_.table_exp.order_by), so->so_scope);
      sqlo_scope_array (so, texp->_.table_exp.order_by);

      sco->sco_fun_refs_allowed = 0;
      sqlo_replace_as_exps ((ST **) &(texp->_.table_exp.group_by), so->so_scope);
      if (texp->_.table_exp.group_by_full)
	{
	  char old_rescope = so->so_is_rescope;
	  so->so_is_rescope = 1;
	  _DO_BOX (inx, texp->_.table_exp.group_by_full)
	    {
	      sqlo_replace_as_exps ((ST **) &(texp->_.table_exp.group_by_full[inx]), so->so_scope);
	      sqlo_scope_array (so, texp->_.table_exp.group_by_full[inx]);
	    }
	  END_DO_BOX;
	  so->so_is_rescope = old_rescope;
	texp->_.table_exp.group_by = texp->_.table_exp.group_by_full[0];
	}
      else
      sqlo_scope_array (so, texp->_.table_exp.group_by);

      if (texp->_.table_exp.order_by)
	sqlo_oby_exp_cols (so, tree, texp->_.table_exp.order_by);
      if (texp->_.table_exp.group_by)
	{
	  sqlo_oby_exp_cols (so, tree, texp->_.table_exp.group_by);
	}
      if (so->so_this_dt->ot_fun_refs || texp->_.table_exp.group_by)
	{
	  int is_not_one_gb = texp->_.table_exp.group_by_full && BOX_ELEMENTS(texp->_.table_exp.group_by_full) > 1;
	  sqlo_check_group_by_cols (so, (ST *) tree->_.select_stmt.selection, &(texp->_.table_exp.group_by), ot, is_not_one_gb);
	  sqlo_replace_as_exps ((ST **) &(texp->_.table_exp.group_by), so->so_scope);
	  if (texp->_.table_exp.group_by)
	    {
	      if (texp->_.table_exp.group_by_full)
		texp->_.table_exp.group_by_full[0] = texp->_.table_exp.group_by;
	      else
		texp->_.table_exp.group_by_full = (ST ***) t_listst (1, texp->_.table_exp.group_by);
	    }
	  sqlo_check_group_by_cols (so, (ST *) texp->_.table_exp.order_by,
	      &(texp->_.table_exp.group_by), ot, is_not_one_gb);
	}
      sqlo_oby_remove_scalar_exps (so, &texp->_.table_exp.order_by);
    }
  else
    sqlo_scope_array (so, (ST**) tree->_.select_stmt.selection);


  if (sco->sco_has_jt && sqlo_expand_jts (so, ptree, NULL, 0))
    {
      char old_rescope = so->so_is_rescope;
      so->so_this_dt = old_dt;
      so->so_is_rescope = 1;
      so->so_scope = so->so_scope->sco_super;
      sqlo_scope (so, ptree);
      so->so_is_rescope = old_rescope;
      return;
    }
#ifndef NO_DT_EXPANSION
  /* do the dt expansion */
    {
      int has_dt_expanded = 0;
      if (texp &&
	  !sqlo_opt_value (ST_OPT (texp, caddr_t *, _.table_exp.opts), OPT_ORDER))
	{
	  has_dt_expanded = sqlo_expand_dt_1 (so, tree, ot);
	}
      if (has_dt_expanded)
	{
	  char old_rescope = so->so_is_rescope;
	  so->so_this_dt = old_dt;
	  so->so_is_rescope = 1;
	  so->so_scope = so->so_scope->sco_super;
	  sqlo_scope (so, ptree);
	  so->so_is_rescope = old_rescope;
	  return;
	}
    }
  /* end dt expansion */
#endif
  if (texp && SEL_IS_DISTINCT (tree))
    sqlo_expand_distinct_joins (so, tree, ot, &res);
  DO_SET (ST *, jc, &res)
    {
      jc->_.join.cond = (ST *) STAR;
    }
  END_DO_SET();
  if (texp && texp->_.table_exp.group_by)
    {
      ptrlong is_distinct = SEL_IS_DISTINCT (tree);
      sqlo_oby_exp_cols (so, tree, texp->_.table_exp.group_by);
      if (!ot->ot_fun_refs)
	sqlo_expand_group_by (tree->_.select_stmt.selection,
	    &tree->_.select_stmt.table_exp->_.table_exp.group_by,
	    &is_distinct);
      SEL_SET_DISTINCT (tree, is_distinct);
      if (texp->_.table_exp.group_by)
	{
	  int is_not_one_gb = texp->_.table_exp.group_by_full && BOX_ELEMENTS(texp->_.table_exp.group_by_full) > 1;
	  sqlo_check_group_by_cols (so, (ST *) tree->_.select_stmt.selection,
	      &(texp->_.table_exp.group_by), ot, is_not_one_gb);
	  sqlo_check_group_by_cols (so, (ST *) texp->_.table_exp.order_by,
	      &(texp->_.table_exp.group_by), ot, is_not_one_gb);
	  if (!is_not_one_gb && SEL_IS_DISTINCT (tree) && sqlo_distinct_redundant ((ST*)tree->_.select_stmt.selection, (ST*)texp->_.table_exp.group_by))
	    SEL_SET_DISTINCT (tree, 0)
	}
    }
  if (SEL_IS_DISTINCT (tree) &&
      texp && !texp->_.table_exp.group_by &&
      dk_set_length (ot->ot_fun_refs) == 1 &&
      ((sql_tree_t *) ot->ot_fun_refs->data)->_.fn_ref.fn_code >= AMMSC_AVG &&
      ((sql_tree_t *) ot->ot_fun_refs->data)->_.fn_ref.fn_code <= AMMSC_COUNTSUM)
    SEL_SET_DISTINCT (tree, 0)

  if (texp && texp->_.table_exp.where)
    texp->_.table_exp.where = sqlo_bop_expand_or_exp (so, texp->_.table_exp.where);
  so->so_scope = so->so_scope->sco_super;
  t_set_push (&so->so_tables, (void*) ot);
  so->so_this_dt = old_dt;
  sqlo_identity_self_join (so, ptree);
}


void
sqlo_exists_record_org (ST * tree, ST * cond)
{
  /* mark the added predicate for exists if it is a single equality */
  if (BOP_EQ == cond->type)
    tree->_.subq.org = cond;
}


void
sqlo_subq_convert_to_exists (sqlo_t * so, ST ** tree_ret)
{
  ST * tree = *tree_ret;
  ST * org_left = tree->_.subq.left;
  ptrlong org_flags = tree->_.subq.flags;
  int to_negate = 0;
  switch (tree->type)
    {
      case ALL_PRED:
	  to_negate = 1;
      case SOME_PRED:
      case ANY_PRED:
      case ONE_PRED:
      case IN_SUBQ_PRED:
	    {
	      ST *select = tree->_.subq.subq;
	      ST * texp = select->_.select_stmt.table_exp;
	      if (SEL_TOP (select))
		sqlc_new_error (so->so_sc->sc_cc, "37000", "SQ148",
		    "TOP not supported in IN, ANY, SOME, ALL, ONE subqueries");
	      if (texp)
		{
		  op_table_t *subq_tbl = sqlo_find_dt (so, select);
		  int aggregates_in_select = subq_tbl->ot_fun_refs != NULL;

		  if (!texp->_.table_exp.group_by)
		    {
		      if (!aggregates_in_select)
			{ /* no aggregates/group by's - make it exists */
			  ST *cond = NULL;
			  int op_negate = 0;

			  if (tree->_.subq.cmp_op == BOP_NEQ)
			    {
			      op_negate = 1;
			      tree->_.subq.cmp_op = BOP_EQ;
			    }

			  if (ST_P (tree->_.subq.left, COMMA_EXP))
			    {
			      int comma_inx;
			      ST *comma = tree->_.subq.left;
			      if (BOX_ELEMENTS (comma->_.comma_exp.exps) !=
				  BOX_ELEMENTS (select->_.select_stmt.selection))
				sqlc_new_error (so->so_sc->sc_cc, "37000", "SQ139",
				    "Different number of subquery output columns for a predicate");
			      DO_BOX (ST *, exp, comma_inx, comma->_.comma_exp.exps)
				{
				  t_st_and (&cond,
				      t_listst (3, tree->_.subq.cmp_op,
					exp,
					(ST *) select->_.select_stmt.selection[comma_inx]));
				}
			      END_DO_BOX;
			    }
			  else
			    {
			      if (so->so_bin_op_is_negate)
				{
				  BIN_OP (cond, BOP_OR,
				      t_listst (3, tree->_.subq.cmp_op,
					tree->_.subq.left,
					(ST *) select->_.select_stmt.selection[0]),
				      t_listst (3, BOP_NULL,
					select->_.select_stmt.selection[0], NULL)
				      );
				}
			      else
				{
				  BIN_OP (cond, tree->_.subq.cmp_op,
				      tree->_.subq.left,
				      (ST *) select->_.select_stmt.selection[0]);
				  sqlo_exists_record_org (tree, cond);
				}
			    }

			  if ((to_negate && !op_negate) ||
			      (!to_negate && op_negate))
			    cond = t_listst (3, BOP_NOT, cond, NULL);
			  sqlo_exists_record_org (tree, cond);
			  t_st_and (&texp->_.table_exp.where, cond);
			  select->_.select_stmt.selection = t_list (1, t_box_num (1));
			  select->_.select_stmt.top = NULL;
			  tree->_.subq.left = NULL;
			  tree->_.subq.flags = 0;
			  tree->type = EXISTS_PRED;
			  if (to_negate)
			    {
			      ST *current = (ST *) t_box_copy ((caddr_t) tree);
			      memset (tree, 0, box_length (tree));
			      tree->type = BOP_NOT;
			      tree->_.bin_exp.left = current;
			    }
			}
		      else
			{ /* aggregates with no group by (a single row) - make it a scalar subq comparison */
			  ptrlong cmp = tree->_.subq.cmp_op;
			  ST *left = tree->_.subq.left;
			  memset (tree, 0, box_length (tree));
			  tree->type = cmp;
			  tree->_.bin_exp.left = left;
			  tree->_.bin_exp.right = t_listst (2, SCALAR_SUBQ, select);
			}
		    }
		  else
		    { /* there is a group by - make it a EXISTS with the condition in having */
		      ST *cond = t_listst (3, tree->_.subq.cmp_op,
			  tree->_.subq.left,
			  (ST *) select->_.select_stmt.selection[0]);

		      if (to_negate)
			cond = t_listst (3, BOP_NOT, cond, NULL);
		      sqlo_exists_record_org (tree, cond);
		      t_st_and (&texp->_.table_exp.having, cond);
		      select->_.select_stmt.selection = t_list (1, t_box_num (1));
		      tree->_.subq.left = NULL;
		      tree->_.subq.flags = 0;
		      tree->type = EXISTS_PRED;
		      if (to_negate)
			{
			  ST *current = (ST *) t_box_copy ((caddr_t) tree);
			  memset (tree, 0, box_length (tree));
			  tree->type = BOP_NOT;
			  tree->_.bin_exp.left = current;
			}
		    }
		  /* the trick with not in and nulls.  If it was a not in, put not null (left) and not (exists ....) in the result */
		  if (SUBQ_F_NOT_IN == org_flags)
		    {
		      ST * nn = t_listst (3, BOP_NOT, t_listst (3, BOP_NULL, org_left, NULL), NULL);
		      ST * ne = t_listst (3, BOP_NOT, tree, NULL);
		      *tree_ret = t_listst (4, BOP_AND, nn, ne, NULL);
		    }
		}
	      else
		{ /* select without from - expand to the value */
		  ptrlong cmp = tree->_.subq.cmp_op;
		  ST *left = tree->_.subq.left;
		  memset (tree, 0, box_length (tree));
		  tree->type = cmp;
		  tree->_.bin_exp.left = left;
		  tree->_.bin_exp.right = (ST *) select->_.select_stmt.selection[0];
		}
	    }
    }
}


int
sqlo_is_unq_preserving (caddr_t name)
{
  return (SINV_DV_STRINGP (name)
	  && (!stricmp (name, "__ID2I") || !stricmp (name, "__RO2SQ") || !stricmp (name, "__ID2IN") ));
}


void
sqlo_count_unq_preserving (ST *tree)
{
  while ST_P (tree->_.fn_ref.fn_arg, CALL_STMT && sqlo_is_unq_preserving (tree->_.fn_ref.fn_arg->_.call.name)
	      && 1 <= BOX_ELEMENTS (tree->_.fn_ref.fn_arg->_.call.params))
    tree->_.fn_ref.fn_arg = tree->_.fn_ref.fn_arg->_.call.params[0];
}


void
sqlo_scalar_subq_scope (sqlo_t * so, ST ** ptree)
{
  ST * tree = *ptree;
  dk_set_t s;
  sql_scope_t * sco = so->so_scope;
  ST * org, * res;
  for (s = sco->sco_scalar_subqs; s; s = s->next->next)
    {
      org = (ST*)s->data;
      if (box_equal (org, tree))
	{
	  *ptree = (ST*)t_box_copy_tree ((caddr_t)s->next->data);
	  return;
	}
    }
  org = (ST*)t_box_copy_tree ((caddr_t)tree);
  sqlo_scope (so, ptree);
  res = (ST*)t_box_copy_tree ((caddr_t)*ptree);
  t_set_push (&sco->sco_scalar_subqs, (void*)res);
  t_set_push (&sco->sco_scalar_subqs, (void*)org);
}

int32 enable_rdf_box_const = 2;

int
sqlo_check_rdf_lit (ST ** ptree)
{
  ST * data = *ptree;
  caddr_t name = NULL, lang = NULL;
  caddr_t vtype;
  if ((name = sqlo_iri_constant_name (data)))
    {
      caddr_t iri = key_name_to_iri_id (NULL, name, 0);
      dtp_t dtp = DV_TYPE_OF (iri);
      if (!iri || DV_DB_NULL == dtp)
	return KS_CAST_UNDEF;
  mp_trash (THR_TMP_POOL, iri);
  *ptree = (ST*)iri;
  return KS_CAST_OK;
    }
  if (enable_rdf_box_const && (vtype = sqlo_rdf_obj_const_value (data, &name, &lang)))
    {
      if (RDF_UNTYPED == vtype)
	{
	  if (!rdf_obj_of_sqlval  (name, (caddr_t*)&data))
	    return KS_CAST_UNDEF;
	}
      else  if (RDF_LANG_STRING == vtype)
	{
	  if (!rdf_obj_of_typed_sqlval  (name, vtype, lang, (caddr_t*)&data))
	    return KS_CAST_UNDEF;

	}
      else
	return KS_CAST_UNDEF;
    }
  else
    return KS_CAST_UNDEF;
  if (DV_RDF != DV_TYPE_OF (data))
    {
      dk_free_tree (data);
      return KS_CAST_UNDEF;
    }
  else
    {
      rdf_box_t * rb = (rdf_box_t*)data;
      dtp_t dtp = DV_TYPE_OF (rb->rb_box);
      if (!IS_NUM_DTP (dtp) && !rb->rb_ro_id)
	{
	  dk_free_tree (data);
	  return KS_CAST_UNDEF;
	}
    }
  mp_trash (THR_TMP_POOL, (caddr_t)data);
  if (2 == enable_rdf_box_const)
    {
      *ptree = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("__rdflit"), t_list (1, data));
    }
  else
    *ptree = data;
  return KS_CAST_OK;
}


extern caddr_t uname_one_of_these;

ST *
sqlo_iri_in_opt (sqlo_t * so, ST * tree)
{
  ST ** params = tree->_.call.params;
  if (st_is_call (params[0], "__ro2lo", 1))
    params[0] = params[0]->_.call.params[0];
  return tree;
}


void
sqlo_scope (sqlo_t * so, ST ** ptree)
{
  ST *tree;
  if (!ptree || !*ptree)
    return;
  tree = *ptree;
  if (SYMBOLP (tree))
    return;
  if (ST_P (tree, QUOTE))
    return;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    return;
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &tree, 8000))
    sqlc_error (so->so_sc->sc_cc, ".....", "Stack Overflow");
  if (DK_MEM_RESERVE)
    sqlc_error (so->so_sc->sc_cc, ".....", "Out of memory");
  switch (tree->type)
    {
    case COL_DOTTED:
      {
	CHECK_OBSERVER(ptree);
	sqlo_col_scope (so, tree);
	break;
      }
    case FUN_REF:
      {
	int old_fun_refs_allowed = so->so_scope ? so->so_scope->sco_fun_refs_allowed : 0;

	if (so->so_scope && !so->so_scope->sco_fun_refs_allowed)
	  sqlc_error (so->so_sc->sc_cc, "37000", "Aggregate function not allowed in context");

	if (AMMSC_AVG == tree->_.fn_ref.fn_code)
	  {
	    ST * arg = tree->_.fn_ref.fn_arg;
	    ptrlong ad = tree->_.fn_ref.all_distinct;
	    ST * arg_copy = (ST*) t_box_copy_tree ((caddr_t) arg);
	    ST * new_tree;
	    if (sizeof (tree->_.bin_exp) > sizeof (tree->_.fn_ref))
	      GPF_T1 ("the parse tree bin exp variant must fit inside the parse tree fun ref ariant");
	    BIN_OP (new_tree, BOP_DIV,
		t_listst (7, FUN_REF, NULL, AMMSC_SUM, NULL, ad, arg, NULL),
		t_listst (7, FUN_REF, NULL, AMMSC_COUNT, NULL, ad, arg_copy, NULL));
	    *ptree = new_tree;
	    tree = new_tree;
	    sqlp_complete_fun_ref (tree->_.bin_exp.right);
	    sqlo_scope (so, ptree);
	    tree = *ptree;
	    return;
	  }

	if (AMMSC_COUNT == tree->_.fn_ref.fn_code)
	  sqlo_count_unq_preserving (tree);
	if (AMMSC_COUNT == tree->_.fn_ref.fn_code
	    && !tree->_.fn_ref.all_distinct
	    && !sqlo_has_col_ref (tree->_.fn_ref.fn_arg))
	  {
	    tree->_.fn_ref.fn_code = AMMSC_COUNTSUM;
	    if (DV_DB_NULL != DV_TYPE_OF (tree->_.fn_ref.fn_arg))
	      tree->_.fn_ref.fn_arg = (ST*) box_num (1);
	    else
	      tree->_.fn_ref.fn_arg = (ST*) box_num (0);
	    tree->_.fn_ref.fn_name = so->so_this_dt->ot_new_prefix;
	  }
	/*if (!sqlo_has_col_ref (tree->_.fn_ref.arg))*/
	tree->_.fn_ref.fn_name = so->so_this_dt->ot_new_prefix;

	if (so->so_scope)
	  so->so_scope->sco_fun_refs_allowed = 0;
	if (NULL != tree->_.fn_ref.fn_arg)
	  sqlo_scope (so, &(tree->_.fn_ref.fn_arg));
	else
	  {
	    int arginx;
	    _DO_BOX_FAST (arginx, tree->_.fn_ref.fn_arglist)
	      {
		sqlo_scope (so, &(tree->_.fn_ref.fn_arglist[arginx]));
	      }
	    END_DO_BOX_FAST;
	  }
	t_set_push (&so->so_this_dt->ot_fun_refs, (void*) tree);
	if (so->so_scope)
	  so->so_scope->sco_fun_refs_allowed = old_fun_refs_allowed;
	break;
      }
    case SCALAR_SUBQ:
      sqlo_scalar_subq_scope (so, &(tree->_.bin_exp.left));
      break;
    case CALL_STMT:
      {
	int inx;
	ST *res;
	char * call_name = tree->_.call.name;
	if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree->_.call.name) && BOX_ELEMENTS (tree->_.call.name) == 1)
	  {
	    sqlo_scope (so, &(((ST **) tree->_.call.name)[0]));
	  }
	else
	  {
	    CHECK_METHOD_CALL (ptree);
	    if (KS_CAST_OK == sqlo_check_rdf_lit  (ptree))
	      return;
	  }
	/* mark qr to do lock if it is for SPARQL insert/delete triples */
	if (DV_STRINGP (call_name) &&
	    (!casemode_strcmp (call_name, "DB.DBA.SPARQL_INSERT_DICT_CONTENT") ||
	     !casemode_strcmp (call_name, "DB.DBA.SPARQL_DELETE_DICT_CONTENT") ||
	     !casemode_strcmp (call_name, "DB.DBA.SPARUL_LOAD") ||
	     !casemode_strcmp (call_name, "DB.DBA.SPARUL_CLEAR")))
	  so->so_sc->sc_cc->cc_query->qr_lock_mode = PL_EXCLUSIVE;
	_DO_BOX (inx, tree->_.call.params)
	  {
	    sqlo_scope (so, &(tree->_.call.params[inx]));
	  }
	END_DO_BOX;
	res = sinv_check_inverses (tree, sqlc_client());
	if (call_name == uname_one_of_these)
	  res = sqlo_iri_in_opt (so, tree);
	if (res != tree)
	  {
	    *ptree = res;
            tree = res;
	  }
	break;
      }
    case COMMA_EXP:
    case SIMPLE_CASE:
    case SEARCHED_CASE:
    case COALESCE_EXP:
      {
	int inx;
	_DO_BOX (inx, tree->_.comma_exp.exps)
	  {
	    sqlo_scope (so, &(tree->_.comma_exp.exps[inx]));
	  }
	END_DO_BOX;
	break;
      }
    case ASG_STMT:
      {
	CHECK_MUTATOR(ptree);
	sqlo_scope (so, (ST **) &(tree->_.op.arg_1));
	sqlo_scope (so, (ST **) &(tree->_.op.arg_2));
	break;
      }
    case KWD_PARAM:
      sqlo_scope (so, &(tree->_.bin_exp.right));
      break;
    case SELECT_STMT:
      sqlo_select_scope (so, ptree);
      break;
    case UNION_ST: case UNION_ALL_ST:
    case EXCEPT_ST: case EXCEPT_ALL_ST:
    case INTERSECT_ST: case INTERSECT_ALL_ST:
	{
	  ST *left;
	  if (IS_UNION_ST (tree->_.set_exp.left))
	    tree->_.set_exp.left = sqlc_union_dt_wrap (tree->_.set_exp.left);
	  if (IS_UNION_ST (tree->_.set_exp.right))
	    tree->_.set_exp.right = sqlc_union_dt_wrap (tree->_.set_exp.right);
	  left = sqlp_union_tree_select (tree);
	  sqlo_union_scope (so, ptree, left);
	  break;
	}
    case ORDER_BY:
      sqlo_scope (so, &(tree->_.o_spec.col));
      break;
    case PROC_TABLE:
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree->_.proc_table.proc))
	{
	  sqlo_scope (so, &(((ST **) tree->_.proc_table.proc)[0]));
	}
      break;
    default:
      if (BIN_EXP_P (tree))
	{
	  ST *res;
 	  so->so_bin_op_is_negate = tree->type == BOP_NOT ? 1 : 0;
	  sqlo_scope (so, &(tree->_.bin_exp.left));
	  sqlo_scope (so, &(tree->_.bin_exp.right));
 	  so->so_bin_op_is_negate = 0;
	  res = sinv_check_exp (so, tree);
	  if (res != tree)
	    {
	      *ptree = res;
	      tree = res;
	      sqlo_check_rdf_lit (&tree->_.bin_exp.left);
	      sqlo_check_rdf_lit (&tree->_.bin_exp.right);
	    }
	  if (ST_P (tree, BOP_OR))
	    sqlo_bop_expand_or (so, tree);
	}
      else if (SUBQ_P (tree))
	{
 	  char so_bin_op_is_negate = so->so_bin_op_is_negate;
	  sqlo_scope (so, &(tree->_.subq.left));
	  sqlo_scope (so, &(tree->_.subq.subq));
 	  so->so_bin_op_is_negate = so_bin_op_is_negate;
	  sqlo_subq_convert_to_exists (so, ptree);
	}

    }
}
