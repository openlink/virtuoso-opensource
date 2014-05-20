/*
 *  sqlgen.c
 *
 *  $Id$
 *
 *  sql executable graph generation
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqlo.h"
#include "list2.h"
#include "xmlnode.h"
#include "xmltree.h"
#include "rdfinf.h"
#include "sqlintrp.h"

void sqlg_setp_keys (sqlo_t * so, setp_node_t * setp, int force_gb, long n_rows);


void
sqlg_qn_has_dfe (data_source_t * qn, df_elt_t * dfe)
{
  sql_comp_t * sc = top_sc;
  if  (!sc->sc_qn_to_dfe)
    sc->sc_qn_to_dfe = hash_table_allocate (33);
  sethash ((void*)qn, sc->sc_qn_to_dfe, (void*)dfe);
  sethash ((void*)dfe, sc->sc_qn_to_dfe, (void*)qn);
}


df_elt_t *
sqlg_qn_dfe (data_source_t * qn)
{
  sql_comp_t * sc = top_sc;
  if (sc->sc_qn_to_dfe)
    return (df_elt_t *)gethash ((void*)qn, sc->sc_qn_to_dfe);
  return NULL;
}


void sqlg_setp_append (sqlo_t * so, data_source_t ** head, setp_node_t * setp);

void dfe_unit_col_loci (df_elt_t * dfe);

void sqlg_pred_1 (sqlo_t * so, df_elt_t ** body, dk_set_t * code, int succ, int fail, int unk);

static int make_grouping_bitmap_set (ST ** sel_cols, ST * col, ST ** etalon, ptrlong * bitmap);

void
sqlg_ks_out_cols (sqlo_t * so, df_elt_t * tb_dfe, key_source_t * ks)
{
  sql_comp_t * sc = so->so_sc;
  DO_SET (df_elt_t *, out, &tb_dfe->_.table.out_cols)
    {
      if (DFE_GEN != out->dfe_is_placed)
	{
	  if (dk_set_member (ks->ks_key->key_parts, (void *) out->_.col.col)
	      && 0 == strcmp (out->dfe_tree->_.col_ref.prefix, tb_dfe->_.table.ot->ot_new_prefix))
	    {
	      /* test also that the out col is actually from this table since out cols can be overlapped in case of inxop between tables, all mentioned on the top table */
	      out->dfe_is_placed = DFE_GEN;
	      sqlg_dfe_ssl (so, out);
	    dk_set_push (&ks->ks_out_slots, (void *) out->dfe_ssl);
	    dk_set_push (&ks->ks_out_cols, (void *) out->_.col.col);
	  }
      }
    if (ks->ks_key->key_is_primary && (ptrlong) out->_.col.col == CI_ROW)
	{
	  if (!sec_tb_check (tb_dfe->_.table.ot->ot_table, SC_G_ID (sc), SC_U_ID (sc), GR_SELECT))
	  sqlc_new_error (sc->sc_cc, "42000", "SQ043", "_ROW requires select permission on the entire table.");
	  out->dfe_is_placed = DFE_GEN;
	  sqlg_dfe_ssl (so, out);
	  dk_set_push (&ks->ks_out_slots, (void *) out->dfe_ssl);
	  dk_set_push (&ks->ks_out_cols, (void *) out->_.col.col);
	}
    }
  END_DO_SET ();
}


state_slot_t *
sqlg_dfe_ssl (sqlo_t * so, df_elt_t * dfe)
{
  ST * tree = dfe->dfe_tree;
  if (dfe->dfe_ssl)
    goto done;
  if (SYMBOLP (tree))
    {
      const char *parm_name = SYMBOLP (tree) ? (const char *) tree : "subg-col-ref";
      sql_comp_t *sc = so->so_sc;
      while (sc->sc_super)
	sc = sc->sc_super;
      dfe->dfe_ssl = ssl_new_parameter (sc->sc_cc, parm_name);
      goto done;
    }
  if (DFE_CONST == dfe->dfe_type)
    {
      dfe->dfe_ssl = ssl_new_constant (so->so_sc->sc_cc, (caddr_t) dfe->dfe_tree);
      goto done;
    }
  if (DFE_CALL == dfe->dfe_type)
    {
      char * fname = "fnpass";
      bif_type_t *bt = bif_type (dfe->dfe_tree->_.call.name);
      dfe->dfe_ssl = ssl_new_variable (so->so_sc->sc_cc, fname, DV_UNKNOWN);
      if (bt)
	{
	  state_slot_t **args = (state_slot_t **) t_box_copy ((caddr_t) dfe->_.call.args);
	  state_slot_t dummy_arg;
	  int inx;

	  memset (args, 0, box_length (args));
	  memset (&dummy_arg, 0, sizeof (state_slot_t));
	  DO_BOX (df_elt_t *, dfe_arg, inx, dfe->_.call.args)
	    {
	      args[inx] = dfe_arg->dfe_ssl ? dfe_arg->dfe_ssl : &dummy_arg;
	    }
	  END_DO_BOX;
	  bif_type_set (bt, dfe->dfe_ssl, args);
	}
    }
  if (ST_COLUMN (tree, COL_DOTTED))
    {
      if (dfe != sqlo_df (so, dfe->dfe_tree))
	SQL_GPF_T1 (so->so_sc->sc_cc, "There are 2 different dfes for the same col ref. Not really supposed to");
      if (dfe->_.col.vc)
	{
	  dfe->dfe_ssl = sqlc_new_temp (so->so_sc, dfe->dfe_tree->_.col_ref.name, dfe->_.col.vc->vc_dtp);
	}
      else if (dfe->_.col.col)
	{
	  char *prefix = NULL;
	  op_table_t * ot = sqlo_cname_ot (so, tree->_.col_ref.prefix);
	  if (ot)
	    prefix = ot->ot_prefix;
	  else
            prefix = tree->_.col_ref.prefix;

	  dfe->dfe_ssl = ssl_new_column (so->so_sc->sc_cc, prefix ? prefix : "", dfe->_.col.col);
	}
      else
	dfe->dfe_ssl = ssl_new_variable (so->so_sc->sc_cc, tree->_.col_ref.name, DV_UNKNOWN);
    }
  else
    {
      char * fname = "aggregate";
      dfe->dfe_ssl = ssl_new_variable (so->so_sc->sc_cc, fname, DV_UNKNOWN);
    }
done:
  if (dfe->dfe_ssl->ssl_dtp == DV_UNKNOWN)
    dfe->dfe_ssl->ssl_sqt = dfe->dfe_sqt;
  return (dfe->dfe_ssl);
}


state_slot_t *
sqlg_sp_ssl (sqlo_t * so, df_elt_t * dfe)
{
  caddr_t val;
  if (DFE_CALL == dfe->dfe_type && (val = sqlo_rdf_lit_const (dfe->dfe_tree)))
    return ssl_new_constant (so->so_sc->sc_cc, val);
  return sqlg_dfe_ssl (so, dfe);
}
search_spec_t *
dfe_to_spec (df_elt_t * lower, df_elt_t * upper, dbe_key_t * key)
{
  sqlo_t * so = lower->dfe_sqlo;
  NEW_VARZ (search_spec_t, sp);
  if (lower->_.bin.left->_.col.col == (dbe_column_t *) CI_ROW)
    SQL_GPF_T(NULL);
  sp->sp_cl = *key_find_cl (key, lower->_.bin.left->_.col.col->col_id);
  sp->sp_col = lower->_.bin.left->_.col.col;
  sp->sp_collation = sp->sp_col->col_sqt.sqt_collation;

  if (!upper)
    {
      int op = bop_to_dvc (lower->_.bin.op);

      if (op == CMP_LT || op == CMP_LTE)
	{
	  sp->sp_min_op = CMP_NONE;
	  sp->sp_max_op = op;
	  sp->sp_max_ssl = sqlg_sp_ssl (so, lower->_.bin.right);
	  if (SSL_IS_UNTYPED_PARAM (sp->sp_max_ssl))
	    {
	      sp->sp_max_ssl->ssl_sqt = sp->sp_col->col_sqt;
	    }
	}
      else
	{
	  sp->sp_max_op = CMP_NONE;
	  sp->sp_min_op = op;
	  sp->sp_min_ssl = sqlg_sp_ssl (so, lower->_.bin.right);
	  if (SSL_IS_UNTYPED_PARAM (sp->sp_min_ssl))
	    {
	      sp->sp_min_ssl->ssl_sqt = sp->sp_col->col_sqt;
	    }
	}
      if (op == CMP_LIKE)
	sp->sp_like_escape = (char) (lower->_.bin.escape);
    }
  else
    {
      sp->sp_min_op = bop_to_dvc (lower->_.bin.op);
      sp->sp_min_ssl = sqlg_sp_ssl (so, lower->_.bin.right);
      if (SSL_IS_UNTYPED_PARAM (sp->sp_min_ssl))
	{
	  sp->sp_min_ssl->ssl_sqt = sp->sp_col->col_sqt;
	}
      sp->sp_max_op = bop_to_dvc (upper->_.bin.op);
      sp->sp_max_ssl = sqlg_sp_ssl (so, upper->_.bin.right);
      if (SSL_IS_UNTYPED_PARAM (sp->sp_max_ssl))
	{
	  sp->sp_max_ssl->ssl_sqt = sp->sp_col->col_sqt;
	}
    }
  return sp;
}


void
sqlg_in_list (sqlo_t * so, key_source_t * ks, dbe_column_t * col, df_elt_t ** in_list, df_elt_t * pred)
{
  sql_comp_t *sc = so->so_sc;
  dk_set_t code = NULL;
  dbe_col_loc_t *cl;
  search_spec_t *spec = (search_spec_t *) dk_alloc (sizeof (search_spec_t));
  int inx;
  in_iter_node_t *ii_found = NULL;
  DO_SET (in_iter_node_t *, ii_prev, &so->so_all_list_nodes)
  {
    if (ii_prev->ii_dfe == pred)
      {
	ii_found = ii_prev;
	break;
      }
  }
  END_DO_SET ();
  memset (spec, 0, sizeof (search_spec_t));
  spec->sp_col = col;
  spec->sp_collation = spec->sp_col->col_sqt.sqt_collation;
  spec->sp_max_op = CMP_NONE;
  spec->sp_min_op = CMP_EQ;
  spec->sp_min_ssl = (ii_found ? ii_found->ii_output : ssl_new_inst_variable (so->so_sc->sc_cc, "in_iter", col->col_sqt.sqt_dtp));
  cl = key_find_cl (ks->ks_key, spec->sp_col->col_id);
  memcpy (&(spec->sp_cl), cl, sizeof (dbe_col_loc_t));
  ks_spec_add (&ks->ks_spec.ksp_spec_array, spec);

  if (!ii_found)
    {
      SQL_NODE_INIT (in_iter_node_t, ii, in_iter_input, in_iter_free);
      ii->ii_output = spec->sp_min_ssl;
      ii->ii_nth_value = cc_new_instance_slot (so->so_sc->sc_cc);
      ii->ii_values_array = ssl_new_inst_variable (so->so_sc->sc_cc, "values_list", DV_ARRAY_OF_POINTER);
      ii->ii_values = (state_slot_t **) dk_alloc_box_zero (sizeof (caddr_t) * (BOX_ELEMENTS (in_list) - 1), DV_BIN);
      ii->ii_dfe = pred;
      for (inx = 1; inx < BOX_ELEMENTS (in_list); inx++)
	{
	  ii->ii_values[inx - 1] = scalar_exp_generate (so->so_sc, in_list[inx]->dfe_tree, &code);
	}
      sqlg_pre_code_dpipe (so, &code, (data_source_t *) ii);
      ii->src_gen.src_pre_code = code_to_cv (so->so_sc, code);
      t_set_push (&so->so_all_list_nodes, (void *) ii);
      t_set_push (&so->so_in_list_nodes, (void *) ii);
    }
}


void
sqlg_in_iter_nodes (sqlo_t * so, data_source_t * ts, data_source_t ** head)
{
  DO_SET (data_source_t *, in, &so->so_in_list_nodes)
    {
      qn_ins_before (so->so_sc, head, (data_source_t *) ts, (data_source_t *)in);
    }
  END_DO_SET ();
  so->so_in_list_nodes = NULL;
}


void
sqlg_non_index_ins (df_elt_t * tb_dfe)
{
  /* put the in preds that are not indexed in the after test */
  DO_SET (df_elt_t *, cp, &tb_dfe->_.table.col_preds)
    {
    if (DFE_GEN != cp->dfe_is_placed && sqlo_in_list (cp, NULL, NULL))
	{
	  sqlo_t * so = tb_dfe->dfe_sqlo;
	  df_elt_t ** pred;
	  so->so_place_code_forr_cond = 1;
	  so->so_gen_pt = tb_dfe;
	  pred = sqlo_pred_body (tb_dfe->dfe_sqlo, LOC_LOCAL, tb_dfe, cp);
	  so->so_place_code_forr_cond = 0;
	  if (tb_dfe->_.table.join_test)
	  tb_dfe->_.table.join_test = (df_elt_t **) t_list (3, BOP_AND, pred, tb_dfe->_.table.join_test);
	  else
	    tb_dfe->_.table.join_test = pred;
	  cp->dfe_is_placed = DFE_GEN;
	}
    }
  END_DO_SET();
}


void
sqlg_ks_col_alter  (key_source_t * ks)
{
  search_spec_t * sp;
  if (!ks->ks_key || !ks->ks_key->key_is_col)
    return;
  for (sp = ks->ks_row_spec; sp; sp = sp->sp_next)
    sp->sp_cl = *cl_list_find (ks->ks_key->key_row_var, sp->sp_cl.cl_col_id);
}


int
sqlg_any_oby_order (df_elt_t * dfe)
{
  for (dfe = dfe; dfe; dfe = dfe->dfe_prev)
    if (DFE_TABLE == dfe->dfe_type && dfe->_.table.is_oby_order)
      return 1;
  return 0;
}


void
sqlg_ks_vec (sqlo_t * so, df_elt_t * tb_dfe, key_source_t * ks)
{
  /* set whether sorted and whether for value or effect */
  search_spec_t * sp = ks->ks_spec.ksp_spec_array;
  int all_eqs = 1;
  sqlg_ks_col_alter (ks);
  if (sqlg_any_oby_order (tb_dfe))
    {
      ks->ks_oby_order = 1;
      return;
    }
  for (sp = sp; sp; sp = sp->sp_next)
    if (CMP_EQ != sp->sp_min_op)
      all_eqs = 0;
  ks->ks_vec_asc_eq = all_eqs;
}


int enable_cl_fref_union = 1;
int enable_row_ranges = 1;

#define SP_IS_LOWER(sp) (CMP_GT == sp->sp_min_op || CMP_GTE == sp->sp_min_op)
#define SP_IS_UPPER(sp) (CMP_LT == sp->sp_max_op || CMP_LTE == sp->sp_max_op)

void
sqlg_ks_row_ranges (key_source_t * ks)
{
  search_spec_t * sp, *next, **prev;
  if (!enable_row_ranges)
    return;
  for (sp = ks->ks_row_spec; sp && sp->sp_next; sp = sp->sp_next)
    {
      prev = &sp->sp_next;
      for (next = sp->sp_next; next; next = next->sp_next)
	{
	  if (next->sp_col == sp->sp_col)
	    {
	      if ((SP_IS_LOWER (sp) && SP_IS_UPPER (next)) || (SP_IS_UPPER (sp) && SP_IS_LOWER (next)))
		{
		  if (SP_IS_UPPER (next))
		    {
		      sp->sp_max_op = next->sp_max_op;
		      sp->sp_max_ssl = next->sp_max_ssl;
		      sp->sp_max = next->sp_max;
		    }
		  else
		    {
		      sp->sp_min_op = next->sp_min_op;
		      sp->sp_min_ssl = next->sp_min_ssl;
		      sp->sp_min = next->sp_min;
		    }

		  *prev = next->sp_next;
		  dk_free ((caddr_t)next, sizeof (search_spec_t));
		  break;
		}
	    }
	  prev = &next->sp_next;
	}
    }
}

key_source_t *
sqlg_key_source_create (sqlo_t * so, df_elt_t * tb_dfe, dbe_key_t * key)
{
  search_spec_t *spec, *col_key_range_sp = NULL;
  int part_no = 0;
  df_elt_t ** in_list;
  caddr_t iso = sqlo_opt_value (tb_dfe->_.table.ot->ot_opts, OPT_ISOLATION);
  int lock_mode = (ptrlong)sqlo_opt_value (tb_dfe->_.table.ot->ot_opts, OPT_NO_LOCK);
  NEW_VARZ (key_source_t, ks);
  ks->ks_key = key;
  if (iso)
    ks->ks_isolation = iso_string_to_code  (iso);
  if (lock_mode)
    ks->ks_lock_mode = 1 == lock_mode ? 0 : 2 == lock_mode ? PL_EXCLUSIVE : 3 == lock_mode ? PL_SHARED : 0;
  ks->ks_check =  NULL != sqlo_opt_value (tb_dfe->_.table.ot->ot_opts, OPT_CHECK);
  if (key->key_is_col)
    ks->ks_row_check = itc_col_row_check_dummy;
  else
    ks->ks_row_check = itc_row_check;
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      df_elt_t *cp = sqlo_key_part_best (col, tb_dfe->_.table.col_preds, 0);
      df_elt_t *upper = NULL;
      if (!cp)
	break;
      cp->dfe_is_placed = DFE_GEN;

      if (cp->dfe_type == DFE_TEXT_PRED)
	{
	  dbe_col_loc_t * cl;
	  spec = (search_spec_t *) dk_alloc (sizeof (search_spec_t));
	  memset (spec, 0, sizeof (search_spec_t));
	  spec->sp_col = cp->_.text.col;
	  spec->sp_collation = spec->sp_col->col_sqt.sqt_collation;
	  spec->sp_max_op = CMP_NONE;
	  spec->sp_min_op = CMP_EQ;
	  spec->sp_min_ssl = cp->_.text.ssl;
	  cl = key_find_cl (key, spec->sp_col->col_id);
	  memcpy (&(spec->sp_cl), cl, sizeof (dbe_col_loc_t));
	}
      else if ((in_list = sqlo_in_list (cp, NULL, NULL)))
	{
	  sqlg_in_list (so, ks, col, in_list, cp);
	  goto next_part;
	}
      else
	{
	if (0 && ks->ks_key->key_is_col && !((DFE_BOP == cp->dfe_type || DFE_BOP_PRED == cp->dfe_type) && BOP_EQ == cp->_.bin.op))
	    {
	      cp->dfe_is_placed = DFE_PLACED;
	      break;
	    }
	  if (dfe_is_lower (cp))
	    {
	      upper = sqlo_key_part_best (col, tb_dfe->_.table.col_preds, 1);
	      if (upper)
		upper->dfe_is_placed = DFE_GEN;
	    }
	  spec = dfe_to_spec (cp, upper, key);
	}
      ks_spec_add (&ks->ks_spec.ksp_spec_array, spec);
      /* Only 0-n equalities plus 0-1 ordinal relations allowed here.  Rest go to row specs. */
      if (spec->sp_min_op != CMP_EQ)
	{
	  if (key->key_is_col)
	    col_key_range_sp = spec;
	break;
	}
next_part:
      part_no++;
      if (part_no >= key->key_n_significant)
	break;

    }
  END_DO_SET ();

  if (col_key_range_sp)
    ks_spec_add (&ks->ks_row_spec, sp_copy (col_key_range_sp));
  DO_SET (df_elt_t *, cp, &tb_dfe->_.table.col_preds)
  {
    if (DFE_GEN != cp->dfe_is_placed
	&& ((cp->dfe_type == DFE_TEXT_PRED &&
	   dk_set_member (ks->ks_key->key_parts, (void *) cp->_.text.col))
	  || (!sqlo_in_list (cp, NULL, NULL) && dk_set_member (ks->ks_key->key_parts, (void *) cp->_.bin.left->_.col.col))))
      {
	cp->dfe_is_placed = DFE_GEN;
	if (cp->dfe_type == DFE_TEXT_PRED)
	  {
	    dbe_col_loc_t * cl;
	    spec = (search_spec_t *) dk_alloc (sizeof (search_spec_t));
	    memset (spec, 0, sizeof (search_spec_t));
	    spec->sp_col = cp->_.text.col;
	    spec->sp_collation = spec->sp_col->col_sqt.sqt_collation;
	    spec->sp_max_op = CMP_NONE;
	    spec->sp_min_op = CMP_EQ;
	    spec->sp_min_ssl = cp->_.text.ssl;
	    cl = key_find_cl (key, spec->sp_col->col_id);
	    memcpy (&(spec->sp_cl), cl, sizeof (dbe_col_loc_t));
	  }
	else
	  spec = dfe_to_spec (cp, NULL, key);
	ks_spec_add (&ks->ks_row_spec, spec);
      }
    if (DFE_GEN != cp->dfe_is_placed && (in_list = sqlo_in_list (cp, NULL, NULL)))
      {
	t_set_pushnew (&tb_dfe->_.table.out_cols, in_list[0]);
      }
  }
  END_DO_SET ();
  sqlg_ks_row_ranges (ks);
  sqlg_ks_out_cols (so, tb_dfe, ks);
  ksp_cmp_func (&ks->ks_spec, &ks->ks_spec_nth);
  sqlg_ks_vec (so, tb_dfe, ks);
  return ks;
}


int
tb_undone_specs (df_elt_t * tb_dfe)
{
  DO_SET (df_elt_t *, cp, &tb_dfe->_.table.col_preds)
    {
      if (DFE_GEN != cp->dfe_is_placed)
	return 1;
    }
  END_DO_SET ();
  return 0;
}


int
tb_undone_cols (df_elt_t * tb_dfe)
{
  DO_SET (df_elt_t *, col_dfe, &tb_dfe->_.table.out_cols)
    {
      if (col_dfe->dfe_is_placed != DFE_GEN)
	return 1;
    }
  END_DO_SET ();
  return 0;
}


state_slot_t *
sqlg_ks_out_col (sqlo_t * so, df_elt_t * tb_dfe, key_source_t * ks, dbe_column_t * col)
{
  df_elt_t * col_dfe = sqlo_df (so, (ST*) t_list (3, COL_DOTTED, tb_dfe->_.table.ot->ot_new_prefix, col->col_name));
  state_slot_t *sl = sqlg_dfe_ssl (so, col_dfe);
  if (!dk_set_member (ks->ks_out_slots, (void *) sl))
    {
      dk_set_push (&ks->ks_out_cols, (void *) col);
      dk_set_push (&ks->ks_out_slots, (void *) sl);
      col_dfe->dfe_is_placed = DFE_GEN;
    }
  return sl;
}


void
sqlg_ks_make_main_spec (sqlo_t * so, df_elt_t * tb_dfe, key_source_t * ks, key_source_t * order_ks)
{
  int part_no = 0;
  search_spec_t **last_spec = &ks->ks_spec.ksp_spec_array;
  if (ks->ks_spec.ksp_spec_array)
    SQL_GPF_T(so->so_sc->sc_cc);		/* prime key specs left after order key processed */

  DO_SET (dbe_column_t *, col, &ks->ks_key->key_parts)
  {
    if (part_no >= ks->ks_key->key_n_significant)
      break;
    else
      {
	NEW_VARZ (search_spec_t, sp);
	*last_spec = sp;
	last_spec = &sp->sp_next;
	sp->sp_min_op = CMP_EQ;
	sp->sp_max_op = CMP_NONE;
	sp->sp_min_ssl = sqlg_ks_out_col (so, tb_dfe, order_ks, col);
	sp->sp_cl = *key_find_cl (ks->ks_key, col->col_id);
      }
    part_no++;
  }
  END_DO_SET ();
  ksp_cmp_func (&ks->ks_spec, &ks->ks_spec_nth);
}

void
sqlg_pred_merge (sqlo_t * so, df_elt_t * dfe, dk_set_t * pre_code)
{
  DO_SET (df_elt_t *, mrg, &dfe->_.table.col_pred_merges)
    {
      sqlg_dfe_code (so, mrg, pre_code, 0, 0, 0);
    }
  END_DO_SET();
}


state_slot_t *
sqlg_virtual_col_ssl (sqlo_t *so, op_virt_col_t *vc)
{
  if (vc)
    {
      df_elt_t *vc_dfe = sqlo_df_virt_col (so, vc);
      return vc_dfe->dfe_ssl;
    }
  else
    return NULL;
}


state_slot_t *
sqlg_rdf_text_check (df_elt_t * tb_dfe, text_node_t * txs, df_elt_t * col_dfe, state_slot_t * id_ssl, dk_set_t * code)
{
  sql_comp_t * sc = tb_dfe->dfe_sqlo->so_sc;
  if (tb_is_rdf_quad (tb_dfe->_.table.ot->ot_table))
    {
      if (id_ssl->ssl_column && 0 == stricmp (id_ssl->ssl_column->col_name, "O"))
	{
	  state_slot_t * id2 = sqlc_new_temp (sc, "ro_id", DV_LONG_INT);
	  cv_call (code, NULL, t_sqlp_box_id_upcase  ("ro_digest_id"), id2, (state_slot_t **) sc_list (1, id_ssl));
	  t_set_pushnew (&tb_dfe->_.table.out_cols, (void*)col_dfe);
	  return id2;
	}
    }
  return id_ssl;
}




char
sqlc_geo_op (sql_comp_t * sc, ST * op)
{
  char * str = (char *) op;
  if (DV_STRING == DV_TYPE_OF (op))
    {
      if (0 == stricmp (str, "intersects"))
	return GSOP_INTERSECTS;
      if (0 == stricmp (str, "within"))
	return GSOP_WITHIN;
      if (0 == stricmp (str, "contains"))
	return GSOP_CONTAINS;
      if (0 == stricmp (str, "may_intersects"))
	return GSOP_MAY_INTERSECT;
    }
  sqlc_new_error (sc->sc_cc, "37000", "GEO..", "Geo operation is one of intersects, within, contains or may_intersect");
  return 0;
}


dbe_table_t *
sqlg_geo_index_table (dbe_key_t * text_key, ST ** geo_args)
{
  int inx, n = BOX_ELEMENTS (geo_args);
  for (inx = 2; inx < n; inx++)
    {
      ST * arg = geo_args[inx];
      if (DV_STRINGP (arg) && !stricmp (arg, "index") && inx + 1 < n && DV_STRINGP (geo_args[inx + 1]))
	{
	  caddr_t inx_name = geo_args[inx + 1];
	  dbe_table_t * tb = sch_name_to_table (wi_inst.wi_schema, inx_name);
	  if (!tb)
	    sqlc_new_error (top_sc->sc_cc, "28008", "GEOTB", "No geo index table %s", inx_name);
	}
    }
  return text_key->key_geo_table;
}


void
sqlg_text_node (sqlo_t * so, df_elt_t * tb_dfe, index_choice_t * ic)
{
  ST ** geo_args;
  int gtype;
  df_elt_t * text_pred = tb_dfe->_.table.text_pred;
  int ctype = text_pred->_.text.type, inx;
  op_table_t *ot = dfe_ot (tb_dfe);
  sql_comp_t *sc = so->so_sc;
  ST **args = tb_dfe->_.table.text_pred->_.text.args;
  state_slot_t *text_id = NULL;
  dk_set_t code = NULL;
  dbe_key_t * text_key = tb_text_key (ot->ot_table);
  SQL_NODE_INIT (text_node_t, txs, txs_input, txs_free);
  /* make a col predicate to drive the ts, then generate a text node that will instantiate the variable  */
  if ((geo_args = sqlc_geo_args (text_pred->dfe_tree, &gtype)) && BOX_ELEMENTS (geo_args) > 2)
    ot->ot_geo_prec = geo_args[2];
  if (geo_args)
    txs->txs_geo = gtype;
  txs->txs_card = text_pred->dfe_arity;
  if (tb_dfe->_.table.is_text_order && !ic)
    {
      df_elt_t *text_pred = tb_dfe->_.table.text_pred;
      text_id = sqlc_new_temp (sc, "text_id", DV_LONG_INT);
      tb_dfe->_.table.key = text_key;
      text_pred->_.text.col = (dbe_column_t *) tb_dfe->_.table.key->key_parts->data;
      text_pred->_.text.ssl = text_id;
      t_set_push (&tb_dfe->_.table.col_preds, (void *) text_pred);
    }
  else
    {
      dbe_column_t *col = (dbe_column_t *) text_key->key_parts->data;
      df_elt_t *col_dfe = sqlo_df (so, t_listst (3, COL_DOTTED, ot->ot_new_prefix, col->col_name));
      if (geo_args && !tb_is_rdf_quad (tb_dfe->_.table.ot->ot_table))
	return; /* After test in a sql table geo pred is a function call, no text node */
      text_id = sqlg_dfe_ssl (so, col_dfe);
      if (!tb_dfe->_.table.is_text_order)
	text_id = sqlg_rdf_text_check (tb_dfe, txs, col_dfe, text_id, &code);
      if (tb_dfe->_.table.is_text_order)
	col_dfe->dfe_is_placed = DFE_GEN;
    }
  txs->txs_cached_string = ssl_new_variable (sc->sc_cc, "text_search_cached_exp_string", DV_SHORT_STRING);
  txs->txs_cached_compiled_tree = ssl_new_variable (sc->sc_cc, "text_search_cached_tree", DV_ARRAY_OF_POINTER);
  txs->txs_cached_dtd_config = ssl_new_variable (sc->sc_cc, "text_search_dtd_config", DV_ARRAY_OF_POINTER);
  if (text_pred->_.text.geo)
    txs->txs_table = sqlg_geo_index_table (text_key, geo_args);
  else
    txs->txs_table =text_key->key_text_table;
  txs->txs_d_id = text_id;
  txs->txs_is_driving = tb_dfe->_.table.is_text_order;
  if (ot->ot_table && (0 == stricmp (ot->ot_table->tb_name, "DB.DBA.RDF_QUAD")
	  || 0 == stricmp (ot->ot_table->tb_name, "DB.DBA.R2")))
    txs->txs_is_rdf = 1;
  if (ot->ot_geo)
    txs->txs_geo = sqlc_geo_op (sc, ot->ot_geo);
  if (ctype == 'x')
    {
      txs->txs_xpath_text_exp = ssl_new_variable (sc->sc_cc, "xpath_text_exp", DV_SHORT_STRING);
      tb_dfe->_.table.is_xcontains = 1;
    }
  txs->txs_text_exp = scalar_exp_generate (sc, args[1], &code);
  txs->txs_qcr = ssl_new_inst_variable (sc->sc_cc, "qcr", DV_UNKNOWN);
  txs->txs_pos_in_dc = cc_new_instance_slot (sc->sc_cc);
  txs->txs_pos_in_qcr = cc_new_instance_slot (sc->sc_cc);
  txs->txs_main_range_out = sqlg_virtual_col_ssl (so, ot->ot_main_range_out);
  txs->txs_attr_range_out = sqlg_virtual_col_ssl (so, ot->ot_attr_range_out);
  txs->txs_score = sqlg_virtual_col_ssl (so, ot->ot_text_score);
  txs->txs_offband = (state_slot_t **) box_copy ((box_t) ot->ot_text_offband);
  DO_BOX (op_virt_col_t *, vc, inx, ot->ot_text_offband)
    {
      if (inx % 2)
	txs->txs_offband[inx] = sqlg_virtual_col_ssl (so, vc);
      else
	txs->txs_offband[inx] = (state_slot_t *) vc;
    }
  END_DO_BOX;
  if (ot->ot_text_desc)
    txs->txs_desc = sqlg_dfe_ssl (so, sqlo_df (so, (ST *) (ptrlong) ot->ot_text_desc));
  if (ot->ot_text_score_limit)
    txs->txs_score_limit = scalar_exp_generate (sc, ot->ot_text_score_limit, &code);
  if (ot->ot_ext_fti)
    txs->txs_ext_fti = scalar_exp_generate (sc, ot->ot_ext_fti, &code);
  if (ot->ot_geo_prec)
    txs->txs_precision = scalar_exp_generate (sc, ot->ot_geo_prec, &code);
  if (ot->ot_text_start)
    txs->txs_init_id = scalar_exp_generate (sc, ot->ot_text_start, &code);
  if (ot->ot_text_end)
    txs->txs_end_id = scalar_exp_generate (sc, ot->ot_text_end, &code);
  /* IvAn/SmartXContains/001025 Added text_node_t::txs_why_ranges member */
  switch (ctype)
    {
      case 'c':
	  if(ot->ot_main_range_out)
	    txs->txs_why_ranges = TXS_RANGES4OUTPUT /* | TXS_RANGES4DEBUG */;
	  break;
      case 'x':
	  txs->txs_why_ranges = TXS_RANGES4XCONTAINS /* | TXS_RANGES4DEBUG */;
	  break;
      default:
	if (!txs->txs_geo)
	  SQL_GPF_T1(so->so_sc->sc_cc, "internal error during compilation of text node");
    }
  txs->txs_sst = ssl_new_variable (sc->sc_cc, "text search", DV_TEXT_SEARCH);
  txs->src_gen.src_pre_code = code_to_cv (sc, code);
  if (tb_dfe->_.table.text_pred->_.text.after_test)
    txs->src_gen.src_after_test = sqlg_pred_body (so, tb_dfe->_.table.text_pred->_.text.after_test);

  tb_dfe->_.table.text_node = (data_source_t *) txs;
}


void
sqlg_xpath_node (sqlo_t * so, df_elt_t * tb_dfe)
{
  df_elt_t *text_pred = tb_dfe->_.table.xpath_pred ? tb_dfe->_.table.xpath_pred : tb_dfe->_.table.text_pred;
  int ctype = tb_dfe->_.table.text_pred ? tb_dfe->_.table.text_pred->_.text.type : 0;
  sql_comp_t * sc = so->so_sc;
  op_table_t *ot = dfe_ot (tb_dfe);
  ST **args = tb_dfe->_.table.text_pred ? tb_dfe->_.table.text_pred->_.text.args : NULL;
  dk_set_t code = NULL;
  SQL_NODE_INIT (xpath_node_t, xn, xn_input, xn_free);
  if (!args || ctype == 'c')
    {
      args = tb_dfe->_.table.xpath_pred ? tb_dfe->_.table.xpath_pred->_.text.args : NULL;
      ctype = tb_dfe->_.table.xpath_pred ? tb_dfe->_.table.xpath_pred->_.text.type : 0;
    }
  if (!args)
    sqlc_error (sc->sc_cc, "37000", "%s misplaced", (('q' == ctype) ? "xquery_contains" : "xpath_contains"));
  if (ot->ot_xpath_value)
    {
      xn->xn_output_val = sqlg_virtual_col_ssl (so, ot->ot_xpath_value);
      xn->xn_output_val->ssl_dtp = xn->xn_output_val->ssl_dc_dtp = DV_XML_ENTITY;
      if ('q' == ctype)
	{
	  xn->xn_output_len = ssl_new_variable (sc->sc_cc, "xquery_contains result length", DV_LONG_INT);
	  xn->xn_output_ctr = ssl_new_variable (sc->sc_cc, "xquery_contains result iterator", DV_LONG_INT);
	}
    }
  xn->xn_text_col = sqlg_dfe_ssl (so, sqlo_df (so, ot->ot_text));
  if (ot->ot_base_uri)
    xn->xn_base_uri = sqlg_dfe_ssl (so, sqlo_df (so, ot->ot_base_uri));
  xn->xn_predicate_type = ctype;
  if ((ctype == 'p') || (ctype == 'q'))
    {
      xn->xn_exp_for_xqr_text = scalar_exp_generate (so->so_sc, args[1], &code);
    }
  xn->xn_xqi = ssl_new_variable (so->so_sc->sc_cc, "text search", DV_XQI);
  xn->xn_compiled_xqr_text = ssl_new_variable (so->so_sc->sc_cc, "xp_text", DV_SHORT_STRING);
  xn->xn_compiled_xqr = ssl_new_variable (so->so_sc->sc_cc, "xp_xqr", DV_XPATH_QUERY);
  sqlg_pre_code_dpipe (so, &code, (data_source_t *)xn);
  xn->src_gen.src_pre_code = code_to_cv (sc, code);
  tb_dfe->_.table.xpath_node = (data_source_t *) xn;
  if (tb_dfe->_.table.text_node && tb_dfe->_.table.is_xcontains)
    {
      QNCAST (text_node_t, txs, tb_dfe->_.table.text_node);
	txs->txs_xn_pred_type = xn->xn_predicate_type;
      txs->txs_xn_xq_compiled = xn->xn_compiled_xqr;
      txs->txs_xn_xq_source = xn->xn_compiled_xqr_text;
      xn->xn_text_node = (text_node_t *) tb_dfe->_.table.text_node;
      xn->src_gen.src_after_test = tb_dfe->_.table.text_node->src_after_test;
      tb_dfe->_.table.text_node->src_after_test = NULL;
    }
  else if (text_pred->_.text.after_test)
    xn->src_gen.src_after_test = sqlg_pred_body (so, text_pred->_.text.after_test);
}


void
sqlg_is_text_only (sqlo_t * so, df_elt_t *tb_dfe, table_source_t *ts)
{
  op_table_t *ot = dfe_ot (tb_dfe);

  text_node_t * txs = (text_node_t *) tb_dfe->_.table.text_node;
  key_source_t * order_ks = ts->ts_order_ks;
  if (!ts->ts_main_ks
      && !ts->ts_order_ks->ks_row_spec && !tb_dfe->_.table.xpath_node && !order_ks->ks_key->key_distinct && !txs->txs_is_rdf)
    {
      dbe_column_t * col;
      dk_set_t cols = order_ks->ks_out_cols;
      /* no other cols except for the text id */
      if (!tb_dfe->_.table.is_text_order)
	return;
      if (!cols)
	{
	  tb_dfe->_.table.text_only = 1;
	  return;
	}
      if (cols && cols->next)
	return;
      col = (dbe_column_t *) cols->data;
      if (col == (dbe_column_t *) tb_text_key (ot->ot_table)->key_parts->data)
	{
	  tb_dfe->_.table.text_only = 1;
	  if (tb_dfe->_.table.is_text_order)
	    txs->txs_d_id = (state_slot_t *) order_ks->ks_out_slots->data;
	}
    }
}


/*
   Ensure out cols for all non-eq parts
   Make the eq spec for all significant parts
   Set the max ssls of the AND node if not set.
   If this is from different ot than the 1st argument, copy the out slot of 1st arg to the appropriate out sot for this ot.
*/


void
sqlg_inx_op_and_ks (sqlo_t * so, inx_op_t * and_iop, inx_op_t * iop, df_inx_op_t * and_dio, df_inx_op_t * dio)
{
  key_source_t * ks = iop->iop_ks;
  search_spec_t ** last_spec = &iop->iop_ks_full_spec.ksp_spec_array;
  search_spec_t * sp;
  dk_set_t max_ssls = NULL;
  int nth = 0, nth_free = 0;
  int is_first = NULL == and_iop->iop_max;
  int n_eqs = 0;
  nth = 0;
  sp = ks->ks_spec.ksp_spec_array;
  DO_SET (dbe_column_t *, col, &iop->iop_ks->ks_key->key_parts)
    {
      if (sp && sp->sp_min_op == CMP_EQ)
	{
	  NEW_VARZ (search_spec_t, sp2);
	  n_eqs++;
	  *last_spec = sp2;
	  last_spec = &sp2->sp_next;
	  sp2->sp_min_op = CMP_EQ;
	  sp2->sp_max_op = CMP_NONE;
	  sp2->sp_min_ssl = sp->sp_min_ssl;
	  sp2->sp_cl = sp->sp_cl;
	}
      else
	{
	  NEW_VARZ (search_spec_t, sp2);
	  *last_spec = sp2;
	  last_spec = &sp2->sp_next;
	  sp2->sp_min_op = CMP_EQ;
	  sp2->sp_max_op = CMP_NONE;
	  if (is_first)
	    {
	      sp2->sp_min_ssl = sqlg_ks_out_col (so, dio->dio_table, ks, col);
	      dk_set_push (&max_ssls, (void*) sp2->sp_min_ssl);
	    }
	  else
	    {
	      df_elt_t * first_table = ((df_inx_op_t *)and_dio->dio_terms->data)->dio_table;
	      sp2->sp_min_ssl = and_iop->iop_max[nth_free];
	      /* this also sets what it compares with. This can be col of other table.  So gen also the ssl asg of the col ssl from this table */
	      dk_set_push (&ks->ks_out_cols, (void*) col);
	      dk_set_push (&ks->ks_out_slots, (void*) sp2->sp_min_ssl);
	      sqlg_ks_out_col (so, dio->dio_table, ks, col);
	      if (dio->dio_table != first_table)
		{
		  /* merge between two tables. The out must be the same as the out of the first term.  But if hit, the value must also be assigned to the right ssl */
		}
	    }
	  sp2->sp_cl = *key_find_cl (iop->iop_ks->ks_key, col->col_id);
      nth_free++;
      	}
      nth++;
      if (nth >= dio->dio_key->key_n_significant)
	break;
      if (sp)
	sp = sp->sp_next;
    }
  END_DO_SET();
  if (is_first)
    {
      and_iop->iop_max = (state_slot_t **) list_to_array (dk_set_nreverse (max_ssls));
    }
  iop->iop_ks_row_spec = ks->ks_row_spec;
  ks->ks_row_spec = NULL;
  iop->iop_ks_start_spec = ks->ks_spec;
  ks->ks_spec.ksp_spec_array = NULL;
  inx_op_set_search_params (so->so_sc->sc_cc, NULL, iop);
}


void
sqlg_inx_op_ks_out_cols (sqlo_t * so, key_source_t * ks, df_elt_t * ks_tb_dfe, df_elt_t * top_tb_dfe)
{
  DO_SET (df_elt_t *, col_dfe, &top_tb_dfe->_.table.out_cols)
    {
      if (col_dfe->dfe_is_placed != DFE_GEN)
	{
	  if (0 == strcmp (col_dfe->dfe_tree->_.col_ref.prefix, ks_tb_dfe->_.table.ot->ot_new_prefix)
	      && dk_set_member (ks->ks_key->key_parts, (void*)col_dfe->_.col.col))
	    {
	      col_dfe->dfe_is_placed = DFE_GEN;
	      sqlg_ks_out_col (so, ks_tb_dfe, ks, col_dfe->_.col.col);
	    }
	}
  }
  END_DO_SET ();
}

void
sqlg_inx_op_ssls (sqlo_t * so, inx_op_t * iop)
{
  search_spec_t * sp = iop->iop_ks_full_spec.ksp_spec_array;
  while (sp->sp_next)
    sp = sp->sp_next;
  iop->iop_target_ssl = sp->sp_min_ssl;
  iop->iop_target_dtp = sp->sp_cl.cl_sqt.sqt_dtp;
  if (iop->iop_ks->ks_key->key_is_bitmap)
    {
      iop->iop_bitmap = ssl_new_variable  (so->so_sc->sc_cc, "inxop f", DV_STRING);
    }
}


int
iop_one_col_free (inx_op_t * iop)
{
  /* the full spec is one longer than the start spec
  * The iop_other trick is applicable only if all except the last key part are fixed in the inx int */
  int n_start = 0, n_full = 0;
  search_spec_t * sp1, *sp2;
  for (sp1 = iop->iop_ks_start_spec.ksp_spec_array; sp1; sp1 = sp1->sp_next)
    n_start++;
  for (sp2 = iop->iop_ks_full_spec.ksp_spec_array; sp2; sp2 = sp2->sp_next)
    n_full++;
  return n_start == n_full - 1;
}


inx_op_t *
sqlg_inx_op (sqlo_t * so, df_elt_t * tb_dfe, df_inx_op_t * dio, inx_op_t * parent_iop)
{
  NEW_VARZ (inx_op_t, iop);
  iop->iop_op = dio->dio_op;
  iop->iop_parent = parent_iop;
  iop->iop_state = ssl_new_variable  (so->so_sc->sc_cc, "inxop f", DV_LONG_INT);

  switch (dio->dio_op)
    {
    case IOP_AND:
      {
	int inx = 0, n_terms;
	iop->iop_terms = (inx_op_t **) dk_set_to_array ((dk_set_t) dio->dio_terms);
	n_terms = BOX_ELEMENTS (iop->iop_terms);
	DO_SET (df_inx_op_t *, term, &dio->dio_terms)
	  {
	    iop->iop_terms[inx] = sqlg_inx_op (so, tb_dfe, term, iop);
	    inx++;
	  }
	END_DO_SET();
	DO_BOX (inx_op_t *, term, inx, iop->iop_terms)
	  {
	    sqlg_inx_op_and_ks (so, iop, term, dio, (df_inx_op_t*) dk_set_nth (dio->dio_terms, inx));
	    sqlg_inx_op_ssls (so, term);
	  if (0 != inx && 2 == n_terms && iop_one_col_free (term))
	      term->iop_other = iop->iop_terms[0]; /* Most inx ands are with 2.  If more, the iop_other trick for looking in the other's state while advancing will cause advances to be missed */
	  }
	END_DO_BOX;
	if (2 == n_terms && iop_one_col_free (iop->iop_terms[0]))
	  iop->iop_terms[0]->iop_other = iop->iop_terms[1];
	break;
      }
    case IOP_KS:
      iop->iop_ks = sqlg_key_source_create (so, dio->dio_table, dio->dio_key);
      sqlg_inx_op_ks_out_cols (so, iop->iop_ks, dio->dio_table, tb_dfe);
      iop->iop_itc = ssl_new_itc (so->so_sc->sc_cc);
      break;
    }
    return iop;
}

extern int enable_vec_upd;

data_source_t *
sqlg_make_np_ts (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t * pre_code)
{
  sql_comp_t * sc = so->so_sc;
  comp_context_t *cc = so->so_sc->sc_cc;
  char ord =so->so_sc->sc_order;
  key_source_t * order_ks;
  op_table_t * ot = tb_dfe->_.table.ot;
  dbe_table_t *table = ot->ot_table;
  dbe_key_t *order_key = tb_dfe->_.table.key;
  dbe_key_t *main_key;

  SQL_NODE_INIT (table_source_t, ts, table_source_input, ts_free);
  if (HR_FILL == tb_dfe->_.table.hash_role)
    so->so_sc->sc_order = TS_ORDER_NONE;
  so->so_in_list_nodes = NULL;
  main_key = table->tb_primary_key;
  DO_SET (op_virt_col_t *, vc, &ot->ot_virtual_cols)
    {
      df_elt_t *vc_dfe =  sqlo_df_virt_col (so, vc);
      vc_dfe->dfe_ssl = sqlg_dfe_ssl (so, vc_dfe);
    }
  END_DO_SET ();
  ts->ts_order = sc->sc_order;
#ifdef BIF_XML
  if (tb_dfe->_.table.text_pred || ot->ot_text_score)
    {
      if (!tb_dfe->_.table.text_pred)
	SQL_GPF_T1 (cc, "The contains pred present and not placed");
      sqlg_text_node (so, tb_dfe, NULL);
      order_key = tb_dfe->_.table.key;
      if (tb_dfe->_.table.is_text_order)
	{
	  /* the ts is after the text node.  Set the order in qr_nodes to reflect this */
	  dk_set_delete (&sc->sc_cc->cc_query->qr_nodes, (void*)ts);
	  dk_set_push (&sc->sc_cc->cc_query->qr_nodes, (void*)ts);
	}
    }
  if (tb_dfe->_.table.xpath_pred || tb_dfe->_.table.is_xcontains)
    sqlg_xpath_node (so, tb_dfe);

#endif

  if (tb_dfe->_.table.inx_op)
    {
      ts->ts_inx_op = sqlg_inx_op (so, tb_dfe, tb_dfe->_.table.inx_op, NULL);
    }
  else
    {
      ts->ts_order_ks = sqlg_key_source_create (so, tb_dfe, order_key);
      ts->ts_order_ks->ks_descending = ot->ot_order_dir == ORDER_DESC && tb_dfe->_.table.is_oby_order;
    }
  if (!sc->sc_no_current_of)
    {
      char ct_id[MAX_NAME_LEN * 2 + 10];
      OT_ID (ot, ct_id);
      if (SC_UPD_PLACE == sc->sc_is_update || sc->sc_in_cursor_def)
      ts->ts_current_of = ssl_new_placeholder (cc, ct_id);
    }
  ts->ts_order_cursor = ssl_new_itc (cc);

  /* Done? Need the main row? */

  sqlg_non_index_ins (tb_dfe);
  if (order_key != table->tb_primary_key || ts->ts_inx_op)
    {
      if (tb_undone_specs (tb_dfe) || tb_undone_cols (tb_dfe)
	  || (sc->sc_is_update && sc->sc_need_pk && enable_vec_upd && 0 == strcmp (tb_dfe->_.table.ot->ot_new_prefix, "t1")))
	{
	  /* vectored update needs the placeholder to be on the mail key */
	  ts->ts_main_ks = sqlg_key_source_create (so, tb_dfe, main_key);
	  order_ks = ts->ts_order_ks ? ts->ts_order_ks : ts->ts_inx_op->iop_terms[0]->iop_ks;
	  sqlg_ks_make_main_spec (so, tb_dfe, ts->ts_main_ks, order_ks);
	  il_init (so->so_sc->sc_cc, &ts->ts_il);
	}
    }

  ts->ts_is_outer = tb_dfe->_.table.ot->ot_is_outer;
  order_ks = ts->ts_order_ks;
  if (order_ks && order_ks->ks_spec.ksp_spec_array)
    ts->ts_is_unique = tb_dfe->_.table.is_unique;
  /* if the order key has no spec then this can't be a full match of the key.  The situation is a contradiction, can happen if there is a unique pred but the wrong key.  Aberration of score function is possible cause.*/

  if (order_ks)
    ks_set_search_params (cc, NULL, order_ks);
  if (ts->ts_main_ks)
    ks_set_search_params (cc, NULL, ts->ts_main_ks);
#ifdef BIF_XML
  if (tb_dfe->_.table.text_node)
    {
      sqlg_is_text_only (so, tb_dfe, ts);
      /* if in text order put the text node first, otherwise second */
      if (tb_dfe->_.table.is_text_order && !tb_dfe->_.table.text_only)
	sql_node_append (&tb_dfe->_.table.text_node, (data_source_t*) ts);
      else if (!tb_dfe->_.table.text_only)
	sql_node_append ((data_source_t**) &ts, tb_dfe->_.table.text_node);
    }
  if (tb_dfe->_.table.xpath_node)
    sql_node_append ((data_source_t**) &ts, tb_dfe->_.table.xpath_node);
#endif
  sqlg_non_index_ins (tb_dfe);
  ts->src_gen.src_after_test = sqlg_pred_body (so, tb_dfe->_.table.join_test);
  ts->ts_after_join_test = sqlg_pred_body (so, tb_dfe->_.table.after_join_test);
  if (tb_dfe->_.table.is_unique && !ts->ts_main_ks)
    ts->src_gen.src_input = (qn_input_fn) table_source_input_unique;

  sqlc_update_set_keyset (sc, ts);
  sqlc_ts_set_no_blobs (ts);
  if (SC_UPD_PLACE != sc->sc_is_update && !sc->sc_in_cursor_def)
    ts->ts_current_of = NULL;
  if (!sc->sc_update_keyset && !sqlg_is_vector)
    ts_alias_current_of (ts);
  else if (!ts->ts_main_ks)
    ts->ts_need_placeholder = 1;
  table_source_om (sc->sc_cc, ts);

  if (ot->ot_opts && sqlo_opt_value (ot->ot_opts, OPT_RANDOM_FETCH))
    {
      caddr_t res = sqlo_opt_value (ot->ot_opts, OPT_RANDOM_FETCH);
      ts->ts_is_random = 1;
      ts->ts_rnd_pcnt = res;
    }
  if (ts->ts_order_ks && ot->ot_opts && sqlo_opt_value (ot->ot_opts, OPT_VACUUM))
    {
      sqlo_opt_value (ot->ot_opts, OPT_VACUUM);
      ts->ts_order_ks->ks_is_vacuum = 1;
    }
  if (sqlg_is_vector && ts->ts_main_ks)
    sqlg_cl_ts_split (so, tb_dfe, ts);
  ts->ts_cardinality = tb_dfe->dfe_arity;
  ts->ts_cost = tb_dfe->dfe_unit;
  ts->ts_card_measured = 0 != tb_dfe->_.table.is_arity_sure;
  ts->ts_inx_cardinality = tb_dfe->_.table.inx_card;
  so->so_sc->sc_order = ord;
  return (data_source_t *) ts;
}


hi_signature_t *
hs_make_signature (setp_node_t * setp, dbe_table_t * tb)
{
  hash_area_t * ha = setp->setp_ha;
  hi_signature_t * hsi = (hi_signature_t *) dk_alloc_box (sizeof (hi_signature_t), DV_ARRAY_OF_POINTER);
  int inx = 0, n_keys = dk_set_length (setp->setp_keys);
  int n_deps = dk_set_length (setp->setp_dependent);
  hsi->hsi_col_ids = (oid_t*) dk_alloc_box (sizeof (oid_t) * (n_keys + n_deps), DV_BIN);
  DO_SET (state_slot_t *, ssl, &setp->setp_keys)
    {
      hsi->hsi_col_ids[inx++] = ssl->ssl_column->col_id;
    }
  END_DO_SET ();
  DO_SET (state_slot_t *, ssl, &setp->setp_dependent)
    {
      hsi->hsi_col_ids[inx++] = ssl->ssl_column->col_id;
    }
  END_DO_SET ();
  hsi->hsi_super_key = box_num (tb->tb_primary_key->key_super_id);
  hsi->hsi_n_keys = box_num (ha->ha_n_keys);
#ifdef NEW_HASH
  hsi->hsi_isolation = NULL;
#endif
  return hsi;
}


data_source_t *
sqlg_make_ts (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t * pre_code)
{
  if (tb_dfe->_.table.index_path)
    return sqlg_make_path_ts (so, tb_dfe);
  else
    return sqlg_make_np_ts (so, tb_dfe, pre_code);
}


void
sqlg_unplace_pred_body_ssl (sqlo_t * so, df_elt_t ** body)
{
  int inx;
  if (!body)
    return;
  switch ((ptrlong)body[0])
    {
    case BOP_AND:
    case BOP_OR:
      for (inx = 1; inx < BOX_ELEMENTS (body); inx++)
	sqlg_unplace_pred_body_ssl (so, (df_elt_t**)body[inx]);
      break;
    case DFE_PRED_BODY:
      for (inx = 1; inx < BOX_ELEMENTS (body); inx++)
	sqlg_unplace_ssl (so, body[inx]->dfe_tree);
    }
}


int
sqlg_is_hj_result_col (sql_comp_t * sc, df_elt_t * fill_dfe, df_elt_t * out_dfe)
{
  df_elt_t * ref_dfe = DFE_DT == fill_dfe->dfe_type ? fill_dfe->_.sub.hash_filler_of : fill_dfe->_.table.hash_filler_of;
  DO_SET (df_elt_t *, refd_col, &ref_dfe->_.table.out_cols)
    {
      if (out_dfe->_.col.col == refd_col->_.col.col)
	return 1;
    }
  END_DO_SET();
  return 0;
}

void sqlg_fref_qp (sql_comp_t * sc, fun_ref_node_t * fref, df_elt_t * dt_dfe);
void sqlg_parallel_ts_seq (sql_comp_t * sc, df_elt_t * dt_dfe, table_source_t * ts, fun_ref_node_t * fref, select_node_t *sel);
int enable_par_fill = 2;
int  qn_is_hash_fill (data_source_t * qn);

void
sqlg_set_no_bloom (fun_ref_node_t * fref)
{
  /* if a a hash filler is a single table with no conditions or rdf quad with only p givem we expect no selectivity, so no bloom filter */
  key_source_t * ks;
  table_source_t * ts = (table_source_t *)fref->fnr_select;
  if (!IS_TS (ts))
    return;
  if (ts->src_gen.src_after_test || ts->src_gen.src_after_code)
    return;
  if (qn_next ((data_source_t*)ts) != (data_source_t*)fref->fnr_setp)
    return;
  ks = ts->ts_order_ks;
  if (!ks->ks_spec.ksp_spec_array && !ks->ks_row_spec)
    fref->fnr_setp->setp_no_bloom = 1;
  if (tb_is_rdf_quad (ks->ks_key->key_table))
    {
      search_spec_t * sp = ks->ks_spec.ksp_spec_array;
      if (sp && !sp->sp_next && sp->sp_col && 'P'== sp->sp_col->col_name[0])
	fref->fnr_setp->setp_no_bloom = 1;
    }
}


data_source_t *
sqlg_hash_filler (sqlo_t * so, df_elt_t * tb_dfe, data_source_t * ts_src)
{
  dk_set_t fill_code = NULL;
  op_table_t * ot = tb_dfe->_.table.ot;
  hash_area_t * ha;
  sql_comp_t * sc = so->so_sc;
  table_source_t *ts = (table_source_t *) ts_src;
  data_source_t * ts_post = ts_src, * head = ts_src;
  key_source_t * ks = ts->ts_main_ks ? ts->ts_main_ks : ts->ts_order_ks;
  int shareable = !tb_dfe->_.table.all_preds && !enable_chash_join;
  SQL_NODE_INIT (setp_node_t, setp, setp_node_input, setp_node_free);

  if (IS_TS (ts))
    ts->ts_is_outer = 0; /* filler is not outer even if the hash source is */
  if ( so->so_in_list_nodes)
    sqlg_in_iter_nodes (so, ts_src, &head);
  while (qn_next (ts_post))
    ts_post = qn_next (ts_post);
  if (IS_BOX_POINTER (tb_dfe->dfe_locus) || (tb_dfe->_.table.key && tb_dfe->_.table.key->key_partition))
    shareable = 0; /* source is remote or cluster  */
  ot->ot_hash_filler = setp;

  sqlg_pred_1 (so, tb_dfe->_.table.hash_filler_after_code, &fill_code, 0, 0, 0);

  DO_SET (df_elt_t *, out_dfe, &tb_dfe->_.table.hash_keys)
    {
      state_slot_t * ssl = scalar_exp_generate (so->so_sc, out_dfe->dfe_tree, &fill_code);
      sqlg_unplace_ssl  (so, out_dfe->dfe_tree);
      NCONCF1 (setp->setp_keys, ssl);
      if (DFE_COLUMN != out_dfe->dfe_type)
	shareable = 0; /* a hash inx w/ exps for keys is not shareable */
    }
  END_DO_SET();
  ts_src->src_after_code = code_to_cv (so->so_sc, fill_code);
  sqlg_unplace_pred_body_ssl (so, tb_dfe->_.table.join_test);
  DO_SET (df_elt_t *, out_dfe, &tb_dfe->_.table.out_cols)
    {
      state_slot_t * ssl = sqlg_dfe_ssl (so, out_dfe);
    if (!dk_set_member (setp->setp_keys, (void *) ssl) && sqlg_is_hj_result_col (sc, tb_dfe, out_dfe))
	NCONCF1 (setp->setp_dependent, ssl);
    }
  END_DO_SET();
  setp_distinct_hash (so->so_sc, setp, tb_dfe->dfe_arity, HA_FILL);
  ha = setp->setp_ha;
  if (enable_chash_join)
    {
      if (tb_dfe->_.table.is_hash_filler_unique)
	ha->ha_ch_unique = CHA_ALWAYS_UNQ;
      else
	ha->ha_ch_len += sizeof (int64);
    }
  ha->ha_allow_nulls = 0;
  ha->ha_op = HA_FILL;
  ha->ha_memcache_only = 0;
  sqlg_setp_append (so, &ts_post, setp);

#ifdef NEW_HASH
  if (shareable)
    ks->ks_ha = ha;
#endif
  {
    SQL_NODE_INIT (fun_ref_node_t, fref, (shareable
	    || enable_chash_join ? hash_fill_node_input : fun_ref_node_input), fun_ref_free);
    fref->fnr_select = head;
    fref->fnr_select_nodes = sqlg_continue_list (head);
    fref->fnr_setp = setp;
    setp->setp_fref = fref;
    if (enable_par_fill && enable_par_fill < 3 && enable_chash_join && ha->ha_row_count > chash_min_parallel_fill_rows
	&& enable_qp > 1)
      {
	fref->fnr_parallel_hash_fill = 1;
	sqlg_fref_qp (sc, fref, tb_dfe);
      }
    fref->fnr_n_part = cc_new_instance_slot (sc->sc_cc);
    fref->fnr_nth_part = cc_new_instance_slot (sc->sc_cc);
    fref->fnr_hash_part_min = cc_new_instance_slot (sc->sc_cc);
    fref->fnr_hash_part_max = cc_new_instance_slot (sc->sc_cc);
    sqlg_set_no_bloom (fref);
    if (shareable)
      fref->fnr_hi_signature = hs_make_signature (setp, tb_dfe->_.table.ot->ot_table);
    return ((data_source_t *) fref);
  }
}


data_source_t *
sqlg_hash_filler_dt (sqlo_t * so, df_elt_t * dt_dfe, subq_source_t * sqs)
{
  hash_area_t * ha;
  data_source_t * head = (data_source_t*)sqs;
  sql_comp_t * sc = so->so_sc;
  select_node_t * sel = sqs->sqs_query->qr_select_node;
  int inx, nth = 0;
  SQL_NODE_INIT (setp_node_t, setp, setp_node_input, setp_node_free);
  dt_dfe->_.sub.hash_filler_of->_.table.ot->ot_hash_filler = setp;
  DO_BOX (state_slot_t *, ssl, inx, sel->sel_out_slots)
    {
      if (inx >= sel->sel_n_value_slots)
	break;
      NCONCF1 (setp->setp_keys, ssl);
      if (++nth >= dt_dfe->_.sub.n_hash_fill_keys)
	break;
    }
  END_DO_BOX;
  for (inx = nth; inx < BOX_ELEMENTS (sel->sel_out_slots); inx++)
    {
      state_slot_t * ssl = sel->sel_out_slots[inx];
      if (inx >= sel->sel_n_value_slots)
	break;
      if (!dk_set_member (setp->setp_keys, (void*)ssl))
	NCONCF1 (setp->setp_dependent, ssl);
    }
  setp_distinct_hash (so->so_sc, setp, dt_dfe->dfe_arity, HA_FILL);
  ha = setp->setp_ha;
  if (enable_chash_join)
    {
      if (dt_dfe->_.sub.is_hash_filler_unique)
	ha->ha_ch_unique = CHA_ALWAYS_UNQ;
      else
	ha->ha_ch_len += sizeof (int64);
    }
  ha->ha_allow_nulls = 0;
  ha->ha_op = HA_FILL;
  ha->ha_memcache_only = 0;
  {
    SQL_NODE_INIT (fun_ref_node_t, fref, hash_fill_node_input, fun_ref_free);
    fref->fnr_select = head;
    fref->fnr_select_nodes = sqlg_continue_list (head);
    fref->fnr_setp = setp;
    setp->setp_fref = fref;
    if (enable_par_fill && enable_chash_join && enable_qp > 1)
      {
	fref->fnr_parallel_hash_fill = 1;
	sqlg_parallel_ts_seq (sc, dt_dfe, (table_source_t*)sqs->sqs_query->qr_head_node, fref, NULL);
      }
    fref->fnr_n_part = cc_new_instance_slot (sc->sc_cc);
    fref->fnr_nth_part = cc_new_instance_slot (sc->sc_cc);
    fref->fnr_hash_part_min = cc_new_instance_slot (sc->sc_cc);
    fref->fnr_hash_part_max = cc_new_instance_slot (sc->sc_cc);
    setp->src_gen.src_pre_code = sel->src_gen.src_pre_code;
    sel->src_gen.src_pre_code = NULL;
    qr_replace_node (sqs->sqs_query, (data_source_t*)sel, (data_source_t*)setp, 0);
    dk_set_delete (&sc->sc_cc->cc_query->qr_nodes, (void*)setp);
    dk_set_push (&sqs->sqs_query->qr_nodes, (void*)setp); /* for src stats, must be counted in the nodes of the containing subq */
    return ((data_source_t *) fref);
  }
}


void
hash_source_free (hash_source_t * hs)
{
  if (hs->hs_out_cols)
    dk_free ((caddr_t) hs->hs_out_cols, -1);
  if (hs->hs_out_cols_indexes)
    dk_free ((caddr_t) hs->hs_out_cols_indexes, -1);
  dk_free_box ((caddr_t) hs->hs_ref_slots);
  dk_free_box ((caddr_t) hs->hs_out_slots);
  ha_free (hs->hs_ha);
  cv_free (hs->hs_after_join_test);
  if (hs->hs_ks)
    ks_free (hs->hs_ks);
}


static void
setp_ha_find_col (setp_node_t * setp, dbe_column_t * col, dbe_col_loc_t *ret_loc, ptrlong *ret_idx)
{
  /* get the col loc in the hash temp which corresponds to this col of the table */
  int nth = 0;
  int n_keys = dk_set_length (setp->setp_keys);
  DO_SET (state_slot_t *, ssl, &setp->setp_keys)
    {
      if (ssl->ssl_column == col)
	{
	  ret_loc[0] = setp->setp_ha->ha_key_cols[nth];
	  ret_idx[0] = nth;
	  return;
	}
      nth++;
    }
  END_DO_SET();
  nth = 0;
  DO_SET (state_slot_t *, ssl, &setp->setp_dependent)
    {
      if (ssl->ssl_column == col)
	{
	  ret_loc[0] = setp->setp_ha->ha_key_cols[nth + n_keys];
	  ret_idx[0] = nth + n_keys;
	  return;
	}
      nth++;
    }
  END_DO_SET();
  GPF_T1 ("hash join col ref not in the hash out cols");
}

static void
setp_ha_find_col_ref (setp_node_t * setp, char * cname, dbe_col_loc_t *ret_loc, ptrlong *ret_idx)
{
  /* get the col loc in the hash temp which corresponds to this col of the table */
  int nth = 0;
  int n_keys = dk_set_length (setp->setp_keys);
  DO_SET (state_slot_t *, ssl, &setp->setp_keys)
    {
      if (ssl->ssl_name && 0 == strcmp (ssl->ssl_name, cname))
	{
	  ret_loc[0] = setp->setp_ha->ha_key_cols[nth];
	  ret_idx[0] = nth;
	  return;
	}
      nth++;
    }
  END_DO_SET();
  nth = 0;
  DO_SET (state_slot_t *, ssl, &setp->setp_dependent)
    {
      if (ssl->ssl_name && 0 == strcmp (ssl->ssl_name, cname))
	{
	  ret_loc[0] = setp->setp_ha->ha_key_cols[nth + n_keys];
	  ret_idx[0] = nth + n_keys;
	  return;
	}
      nth++;
    }
  END_DO_SET();
  GPF_T1 ("hash join col ref not in the hash out cols");
}


void
box_set_nth (caddr_t ** box_ret, int inx, caddr_t elt)
{
  if (!*box_ret)
    *box_ret = dk_alloc_box_zero (sizeof (caddr_t) * (inx + 1), DV_BIN);
  else if (BOX_ELEMENTS (*box_ret) <= inx)
    {
      caddr_t * n = (caddr_t*)dk_alloc_box_zero (sizeof (caddr_t) * (inx + 1), DV_BIN);
      memcpy (n, *box_ret, BOX_ELEMENTS (*box_ret) * sizeof (caddr_t));
      dk_free_box (*box_ret);
      *box_ret = n;
    }
  (*box_ret)[inx] = elt;
}


int
dfe_is_in_hash_filler (df_elt_t * dfe)
{
  for (dfe = dfe->dfe_super; dfe; dfe = dfe->dfe_super)
    {
      if ((DFE_TABLE == dfe->dfe_type && dfe->_.table.hash_role) || (DFE_DT == dfe->dfe_type && dfe->_.sub.hash_filler_of))
	return 1;
    }
  return 0;
}


data_source_t *
sqlg_hash_source (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t * pre_code)
{
  hash_area_t * ha_copy = (hash_area_t *) dk_alloc (sizeof (hash_area_t));
  char ref_name[MAX_QUAL_NAME_LEN];
  sql_comp_t * sc = so->so_sc;
  int inx = 0;
  dk_set_t col_refs = NULL;
  dk_set_t ref_slots = NULL, out_slots = NULL;
  int is_fill_dt = DFE_DT == tb_dfe->_.table.hash_filler->dfe_type;
  op_table_t * ot = tb_dfe->_.table.ot;
  setp_node_t * setp = ot->ot_hash_filler;
  hash_area_t * ha = setp->setp_ha;
  SQL_NODE_INIT (hash_source_t, hs, hash_source_input, hash_source_free);
  hs->hs_cardinality = tb_dfe->dfe_arity;
  hs->hs_filler = setp->setp_fref;
  hs->hs_part_min = hs->hs_filler->fnr_hash_part_min;
  hs->hs_part_max = hs->hs_filler->fnr_hash_part_max;
  hs->hs_no_partition = dfe_is_in_hash_filler (tb_dfe);
  hs->hs_cl_part_opt = sqlo_opt_value (ot->ot_opts, OPT_HASH_REPLICATION) ? HS_CL_REPLICATED 
    : sqlo_opt_value (ot->ot_opts, OPT_HASH_PARTITION) ? HS_CL_PART : 0;
  hs->clb.clb_fill = cc_new_instance_slot (so->so_sc->sc_cc);
  hs->hs_current_inx = cc_new_instance_slot (so->so_sc->sc_cc);
  hs->hs_saved_hmk = cc_new_instance_slot (so->so_sc->sc_cc);
  hs->hs_is_unique = tb_dfe->_.table.is_unique;
  DO_SET (df_elt_t *, ref, &tb_dfe->_.table.hash_refs)
    {
      state_slot_t * ssl = scalar_exp_generate (so->so_sc,  ref->dfe_tree, pre_code);
      if (ssl->ssl_type == SSL_CONSTANT)
	{
	  state_slot_t *ssl1 = ssl_new_variable (sc->sc_cc, "", DV_UNKNOWN);
	  ssl_copy_types (ssl1, ssl);
	  cv_artm (pre_code, (ao_func_t) box_identity, ssl1, ssl, NULL);
	  ssl = ssl1;
	}
      dk_set_push (&ref_slots, (void*) ssl);
    }
  END_DO_SET();
  ref_slots = dk_set_nreverse (ref_slots);
  memcpy (ha_copy, ha, sizeof (hash_area_t));
  ha_copy->ha_slots = (state_slot_t **) dk_set_to_array (ref_slots);
  ha_copy->ha_key_cols = (dbe_col_loc_t *) box_copy ((caddr_t) ha->ha_key_cols);
  ha_copy->ha_cols = NULL;
  hs->hs_ref_slots = (state_slot_t **) list_to_array (ref_slots);
  hs->hs_ha = ha_copy;
  if (enable_chash_join)
    {
      /* if selecting a col that is a key of the hash, alias the out col to the input col.  But not if outer join.  OK if inside outer dt cause out slots are then copies at end of dt */
      DO_SET (df_elt_t *, out, &tb_dfe->_.table.out_cols)
	{
	  state_slot_t * ssl = sqlg_dfe_ssl (so, out);
	  dbe_col_loc_t cl;
	  ptrlong nth;
	  if (is_fill_dt)
	    {
	      snprintf (ref_name, sizeof (ref_name), "%s.%s", out->dfe_tree->_.col_ref.prefix, out->dfe_tree->_.col_ref.name);
	      setp_ha_find_col_ref (setp, ref_name, &cl, &nth);
	    }
	  else
	    setp_ha_find_col (setp, out->_.col.col, &cl, &nth);
	  if (nth < ha->ha_n_keys)
	    {
	      if (!tb_dfe->_.table.ot->ot_is_outer /* ssl->ssl_sqt.sqt_dtp != hs->hs_ref_slots[nth]->ssl_sqt.sqt_dtp */)
		{
		  cv_artm (pre_code, (ao_func_t) box_identity, ssl, hs->hs_ref_slots[nth], NULL);
		  if (DV_ANY == ssl->ssl_sqt.sqt_dtp)
		    ssl->ssl_sqt.sqt_col_dtp = DV_ANY;
		}
	      else
		{
		  hs->hs_ref_slots[nth]->ssl_sqt.sqt_col_dtp = ssl->ssl_sqt.sqt_col_dtp; /* hash filler col must have this set */
		  if (!tb_dfe->_.table.ot->ot_is_outer)
	    ssl_alias (ssl, hs->hs_ref_slots[nth]);
	  else
		    {
		      t_set_push (&hs->hs_out_aliases, (void*)ssl);
		      t_set_push (&hs->hs_out_aliases, (void*)(ptrlong)nth);
		    }
		}
	    }
	  else
	    box_set_nth ((caddr_t**)&hs->hs_out_slots, nth - ha->ha_n_keys, (caddr_t)ssl);
	}
      END_DO_SET();
    }
  else
    {
  hs->hs_out_cols = (dbe_col_loc_t *) dk_alloc (sizeof (dbe_col_loc_t) * (1 + dk_set_length (tb_dfe->_.table.out_cols)));
  hs->hs_out_cols_indexes = (ptrlong *) dk_alloc (sizeof (ptrlong) * (1 + dk_set_length (tb_dfe->_.table.out_cols)));

  DO_SET (df_elt_t *, out, &tb_dfe->_.table.out_cols)
    {
      state_slot_t * ssl = sqlg_dfe_ssl (so, out);
      dk_set_push (&out_slots, (void*) ssl);
	  dk_set_push (&col_refs, col_ref_func (ha->ha_key, out->_.col.col, ssl));
	  if (is_fill_dt)
	    {
	      snprintf (ref_name, sizeof (ref_name), "%s.%s", out->dfe_tree->_.col_ref.prefix, out->dfe_tree->_.col_ref.name);
	      setp_ha_find_col_ref (setp, ref_name, hs->hs_out_cols+inx, hs->hs_out_cols_indexes+inx);
	    }
	  else
      setp_ha_find_col (setp, out->_.col.col, hs->hs_out_cols+inx, hs->hs_out_cols_indexes+inx);
      inx++;
    }
  END_DO_SET();
  hs->hs_out_cols[inx].cl_col_id = 0;
  hs->hs_out_cols_indexes[inx] = -1;
  hs->hs_out_slots = (state_slot_t **) list_to_array (dk_set_nreverse (out_slots));
      hs->hs_col_ref = (col_ref_t*)list_to_array (dk_set_nreverse (col_refs));
    }
  hs->src_gen.src_after_test = sqlg_pred_body (so, tb_dfe->_.table.join_test);
  hs->hs_is_outer = tb_dfe->_.table.ot->ot_is_outer;
  hs->hs_after_join_test = sqlg_pred_body (so, tb_dfe->_.table.after_join_test);
  return ((data_source_t*) hs);
}


ST **
sqlc_sel_names (ST** sel, char * pref)
{
  ST ** names = (ST**) t_box_copy ((caddr_t) sel);
  int inx;
  DO_BOX (ST *, exp, inx, sel)
    {
      names[inx] = (ST*) t_list (3, COL_DOTTED, pref, exp->_.as_exp.name);
    }
  END_DO_BOX;
  return names;
}


state_slot_t **
sqlg_proc_table_params (sqlo_t * so, df_elt_t * dt_dfe, dk_set_t *precompute)
{
  /* get the col preds belonging to each parameter into
   * arg ssl list */
  op_table_t *ot = dfe_ot (dt_dfe);
  caddr_t * formal = (caddr_t *) ot->ot_dt->_.proc_table.params;
  state_slot_t ** params = (state_slot_t **) box_copy ((caddr_t) formal);
  int inx;
  DO_BOX (caddr_t, name, inx, formal)
    {
      dtp_t name_dtp = DV_TYPE_OF (name);
      DO_SET (df_elt_t *, colp_dfe, &dt_dfe->_.sub.dt_preds)
	{
	  if (IS_STRING_DTP (name_dtp) || name_dtp == DV_SYMBOL)
	    {
	      if (ST_COLUMN (colp_dfe->dfe_tree->_.bin_exp.left, COL_DOTTED) &&
		  (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)
		   || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)))
		{
		  params[inx] = scalar_exp_generate (so->so_sc, colp_dfe->_.bin.right->dfe_tree, precompute);
		  colp_dfe->dfe_is_placed = DFE_GEN;
		  goto next_arg;
		}
	      else if (ST_COLUMN (colp_dfe->dfe_tree->_.bin_exp.right, COL_DOTTED) &&
		  (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)
		   || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)))
		{
		  params[inx] = scalar_exp_generate (so->so_sc, colp_dfe->_.bin.left->dfe_tree, precompute);
		  colp_dfe->dfe_is_placed = DFE_GEN;
		  goto next_arg;
		}
	    }
	}
      END_DO_SET();
      DO_SET (df_elt_t *, colp_dfe, &dt_dfe->_.sub.dt_imp_preds)
	{
	  if (IS_STRING_DTP (name_dtp) || name_dtp == DV_SYMBOL)
	    {
	      if (ST_COLUMN (colp_dfe->dfe_tree->_.bin_exp.left, COL_DOTTED) &&
		  (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)
		   || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)))
		{
		  params[inx] = scalar_exp_generate (so->so_sc, colp_dfe->_.bin.right->dfe_tree, precompute);
		  colp_dfe->dfe_is_placed = DFE_GEN;
		  goto next_arg;
		}
	      else if (ST_COLUMN (colp_dfe->dfe_tree->_.bin_exp.right, COL_DOTTED) &&
		  (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)
		   || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)))
		{
		  params[inx] = scalar_exp_generate (so->so_sc, colp_dfe->_.bin.left->dfe_tree, precompute);
		  colp_dfe->dfe_is_placed = DFE_GEN;
		  goto next_arg;
		}
	    }
	}
      END_DO_SET();
      DO_SET (df_elt_t *, colp_dfe, &dt_dfe->_.sub.ot->ot_join_preds)
	{
	  if (IS_STRING_DTP (name_dtp) || name_dtp == DV_SYMBOL)
	    {
	      if (ST_COLUMN (colp_dfe->dfe_tree->_.bin_exp.left, COL_DOTTED) &&
		  (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)
		   || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)))
		{
		  params[inx] = scalar_exp_generate (so->so_sc, colp_dfe->_.bin.right->dfe_tree, precompute);
		  colp_dfe->dfe_is_placed = DFE_GEN;
		  goto next_arg;
		}
	      else if (ST_COLUMN (colp_dfe->dfe_tree->_.bin_exp.right, COL_DOTTED) &&
		  (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)
		   || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.right->_.col_ref.name)))
		{
		  params[inx] = scalar_exp_generate (so->so_sc, colp_dfe->_.bin.left->dfe_tree, precompute);
		  colp_dfe->dfe_is_placed = DFE_GEN;
		  goto next_arg;
		}
	    }
	}
      END_DO_SET();
      params[inx] = sqlg_dfe_ssl (so, sqlo_df (so, (ST *) t_alloc_box (0, DV_DB_NULL)));
    next_arg: ;
    }
  END_DO_BOX;
  return params;
}


data_source_t *
sqlg_generate_proc_ts (sqlo_t * so, df_elt_t * dt_dfe, dk_set_t *precompute)
{
  ptrlong out_ctr = 3;
  state_slot_t ** params = NULL;
  int inx;
  op_table_t *ot = dfe_ot (dt_dfe);
  ST * tree = dt_dfe->_.sub.ot->ot_dt;
  sql_comp_t * sc = so->so_sc;
  dk_set_t out_slots = NULL, out_cols = NULL, blob_to_string_code = NULL;
  caddr_t blob_to_string_func = t_sqlp_box_id_upcase ("blob_to_string");
  state_slot_t *ssl_1 = ssl_new_constant (sc->sc_cc, t_box_num (1));
  setp_node_t setp;
  SQL_NODE_INIT (table_source_t, ts, table_source_input, ts_free);

  memset (&setp, 0, sizeof (setp_node_t));
  setp.src_gen.src_query = sc->sc_cc->cc_query;

  setp.setp_keys = CONS (sqlc_new_temp (sc, "proc_ctr", DV_LONG_INT), NULL);
  out_slots = dk_set_copy (setp.setp_keys);

  for (inx = 0; inx < (int) BOX_ELEMENTS (tree->_.proc_table.cols); inx += 2)
    {
      df_elt_t *col_df;
      state_slot_t *ssl;
      if (!tree->_.proc_table.cols[inx])
	continue;
      if (0 == strcmp ((caddr_t) tree->_.proc_table.cols[inx], "_IDN"))
	continue;
      col_df = sqlo_df (so, t_listst (3, COL_DOTTED, ot->ot_new_prefix, tree->_.proc_table.cols[inx]));
      ssl = sqlg_dfe_ssl (so, col_df);
      ddl_type_to_sqt (&(ssl->ssl_sqt),  ((caddr_t ***) tree->_.proc_table.cols)[inx + 1][0]);
      NCONCF1 (setp.setp_dependent, ssl);
      NCONCF1 (out_cols, out_ctr);
      NCONCF1 (out_slots, ssl);
      out_ctr++;
      if (ssl && IS_BLOB_DTP (ssl->ssl_dtp) && !ssl->ssl_sqt.sqt_is_xml)
	cv_call (&blob_to_string_code, NULL, blob_to_string_func, ssl, (state_slot_t **) /*list */ sc_list (2, ssl, ssl_1));
    }
  params = sqlg_proc_table_params (so, dt_dfe, precompute);
  DO_BOX (caddr_t, param, inx, tree->_.proc_table.params)
    {
      df_elt_t *col_df;
      state_slot_t *ssl;
      col_df = sqlo_df (so, t_listst (3, COL_DOTTED, ot->ot_new_prefix, param));
      ssl = sqlg_dfe_ssl (so, col_df);
      if (ssl && params[inx])
	{
	  cv_artm (precompute, (ao_func_t) box_identity, ssl, params[inx], NULL);
	  ssl->ssl_sqt = params[inx]->ssl_sqt;
	}
    }
  END_DO_BOX;

  setp_distinct_hash (sc, &setp, 0, HA_PROC_FILL);
  setp.setp_ha->ha_op = HA_PROC_FILL;
  setp.setp_ha->ha_memcache_only = 0;
  ts->ts_is_outer = ot->ot_is_outer;
  ts->ts_order_cursor = ssl_new_itc (sc->sc_cc);
    {
      NEW_VARZ (key_source_t, ks);
      ts->ts_order_ks = ks;
      ks->ks_key = setp.setp_ha->ha_key;
      ks->ks_row_check = itc_row_check;
      ks->ks_out_slots = out_slots;
      ks->ks_out_cols = ks->ks_key->key_parts;
      ks->ks_set_no_col_ssl = (state_slot_t *)ks->ks_out_slots->data;
      ks->ks_is_proc_view = 1;
      ks->ks_from_temp_tree = setp.setp_ha->ha_tree;
      table_source_om (sc->sc_cc, ts);
      ks->ks_out_cols = out_cols;
    }
  cv_artm (precompute, (ao_func_t) box_identity,
      (state_slot_t *) setp.setp_keys->data, ssl_new_constant (sc->sc_cc, t_box_num (0)), NULL);
  cv_bif_call (precompute, bif_clear_temp, t_sqlp_box_id_upcase ("__reset_temp"), NULL,
      (state_slot_t **) sc_list (1, ssl_new_constant (sc->sc_cc, t_box_num ((ptrlong) setp.setp_ha))));
  cv_call (precompute,
      ssl_new_constant (sc->sc_cc, t_box_num ((ptrlong) setp.setp_ha)), tree->_.proc_table.proc, CV_CALL_PROC_TABLE, params);
  DO_BOX (state_slot_t *, ssl, inx, setp.setp_ha->ha_slots)
    {
      ssl_with_info (so->so_sc->sc_cc, ssl);
    }
  END_DO_BOX;
  ts->ts_proc_ha = setp.setp_ha;
  setp.setp_reserve_ha = NULL;
  setp_node_free (&setp);

  ts->src_gen.src_after_test = sqlg_pred_body_1 (so, dt_dfe->_.sub.after_join_test, blob_to_string_code);
  return (data_source_t *) ts;
}

data_source_t *
qn_next_qn (data_source_t * ts, qn_input_fn in)
{
  for (ts = ts; ts; ts = qn_next (ts))
    if (IS_QN (ts, in))
      return ts;
  return NULL;
}


int enable_inline_sqs = 1;

data_source_t *
sqlg_pop_sqs (sql_comp_t * sc, subq_source_t * sqs, data_source_t ** head, dk_set_t * pre_code)
{
  /* Remove the sqs, flag the subq select to be inline, put a set ctr for the sets. */
  dk_set_t qns = NULL;
  data_source_t *last = NULL;
  query_t *sqr = sqs->sqs_query;
  query_t *qr = sc->sc_cc->cc_query;
  data_source_t *qn;
  state_slot_t *set_no = sqs->sqs_set_no;
  SQL_NODE_INIT (set_ctr_node_t, sctr, set_ctr_input, set_ctr_free);
  sctr->sctr_set_no = set_no;
  sql_node_append (head, (data_source_t *) sctr);
  if (*pre_code)
    {
      sqlg_pre_code_dpipe (sc->sc_so, pre_code, NULL);
      sctr->src_gen.src_pre_code = code_to_cv (sc, *pre_code);
      *pre_code = NULL;
    }
  for (qn = sqr->qr_head_node; qn; qn = qn_next (qn))
    {
      t_set_push (&qns, (void *) qn);
      last = qn;
    }
  DO_SET (data_source_t *, qn, &sqr->qr_nodes) qn->src_query = qr;
  END_DO_SET ();
  qns = dk_set_nreverse (qns);
  DO_SET (data_source_t *, qn, &qns)
  {
    dk_set_free (qn->src_continuations);
    qn->src_continuations = NULL;
    if (qn != last)
      sql_node_append (head, qn);
      if (IS_QN (qn, select_node_input_subq) && !((select_node_t*)qn)->sel_subq_inlined)
      {
	QNCAST (select_node_t, sel, qn);
	sel->sel_set_ctr = sctr;
	sel->sel_subq_inlined = 1;
	  sel->src_gen.src_after_test = sqs->sqs_after_join_test;
	  sqs->sqs_after_join_test = NULL;
	break;
      }
  }
  END_DO_SET ();
  qr->qr_nodes = dk_set_conc (sqr->qr_nodes, qr->qr_nodes);
  sqr->qr_nodes = NULL;
  return last;
}

int
sqlg_in_inlined_subq (data_source_t * qn)
{
  for (qn = qn; qn; qn = qn_next (qn))
    {
      if (IS_QN (qn, select_node_input_subq))
	return ((select_node_t*)qn)->sel_subq_inlined;
    }
  return 0;
}

int setp_is_high_card (setp_node_t * setp);

data_source_t *
sqlg_inline_sqs (sql_comp_t * sc, df_elt_t * dfe, subq_source_t * sqs, data_source_t ** head, dk_set_t * pre_code)
{
  query_t *sqr = sqs->sqs_query;
  data_source_t *qn;
  if (!IS_QN (sqs, subq_node_input) || !sqs->sqs_query ||
      !enable_inline_sqs || sqr->qr_select_node->sel_top || dfe->_.sub.ot->ot_is_outer)
    return (data_source_t *) sqs;
  for (qn = sqr->qr_head_node; qn; qn = qn_next (qn))
    {
      if (IS_QN (qn, fun_ref_node_input) && !IS_QN (((fun_ref_node_t *) qn)->fnr_select, fun_ref_node_input))
	{
	  QNCAST (fun_ref_node_t, fref, qn);
	  table_source_t *rdr = (table_source_t *) qn_next (qn);
	  if (IS_QN (rdr, chash_read_input) && (fref->fnr_setp->setp_partitioned || setp_is_high_card (fref->fnr_setp))
	      && qn_next_qn ((data_source_t *) rdr, (qn_input_fn) select_node_input_subq))
	    {
	      return sqlg_pop_sqs (sc, sqs, head, pre_code);
	    }
	}
      if (IS_QN (qn, setp_node_input) && ((setp_node_t*)qn)->setp_is_streaming)
	{
	  return sqlg_pop_sqs (sc, sqs, head, pre_code);
	}
      if (IS_QN (qn, breakup_node_input) && !sqlg_in_inlined_subq (qn))
	{
	  return sqlg_pop_sqs (sc, sqs, head, pre_code);
	}
      if (IS_QN (qn, setp_node_input) && ((setp_node_t*)qn)->setp_distinct && !sqlg_in_inlined_subq (qn))
	{
	  if (qn_next_qn (qn, (qn_input_fn)skip_node_input))
	    break;
	  return sqlg_pop_sqs (sc, sqs, head, pre_code);
	}
    }
  return (data_source_t *) sqs;
}


extern int enable_multistate_code;


int
box_position (caddr_t * box, caddr_t elt)
{
  int inx;
  DO_BOX (caddr_t, x, inx, box)
    {
      if (unbox (elt) == unbox (x))
	return inx;
    }
  END_DO_BOX;
  return -1;
}


int
box_position_no_tag (caddr_t * box, caddr_t elt)
{
  int inx;
  DO_BOX (caddr_t, x, inx, box)
    {
      if (elt ==  x)
	return inx;
    }
  END_DO_BOX;
  return -1;
}


state_slot_t *
tn_nth_col (sql_comp_t *sc, trans_node_t * tn, int inx)
{
  state_slot_t ** sel = tn->tn_inlined_step->qr_select_node->sel_out_slots;
  int n = tn->tn_inlined_step->qr_select_node->sel_n_value_slots;
  if (inx >= n)
    sqlc_new_error (sc->sc_cc, "37000", "TR...", "column index out of range in transitive dt");
  return sel[inx];
}

void
sqlg_trans_rename (sql_comp_t * sc, state_slot_t * org, state_slot_t * target)
{
  /* out cols of a dt get assigned to the properly named slots in the outer ctx.  So update the trans node special output cols so the node refs to the right ones in the outer ctx */
  trans_node_t * tn = sc->sc_trans;
  if (org == tn->tn_step_no_ret)
    tn->tn_step_no_ret = target;
  else if (org == tn->tn_path_no_ret)
    tn->tn_path_no_ret = target;
  else  if (tn->tn_step_out)
    {
      int inx;
      DO_BOX (state_slot_t *, s, inx, tn->tn_step_out)
	{
	  if (s == org)
	    tn->tn_step_out[inx] = target;
	}
      END_DO_BOX;
    }
}



data_source_t *
sqlg_make_trans_dt  (sqlo_t * so, df_elt_t * dt_dfe, ST **target_names, dk_set_t *pre_code)
{
  dk_set_t data_ssls = NULL;
  sql_comp_t * sc = so->so_sc;
  trans_node_t * prev_trans = sc->sc_trans;
  trans_layout_t * tl = dt_dfe->_.sub.trans;
  op_table_t * ot = dt_dfe->_.sub.ot;
  ST * trans = ot->ot_trans;
  int n_values;
  int inx;
  char old_order = sc->sc_order;
  SQL_NODE_INIT (trans_node_t, tn, trans_node_input, tn_free);
  tn->tn_max_memory = TN_DEFAULT_MAX_MEMORY;
  if (!target_names)
    target_names =
	sqlc_sel_names ((ST **) sqlp_union_tree_select (dt_dfe->_.sub.ot->ot_dt)->_.select_stmt.selection,
	dt_dfe->_.sub.ot->ot_new_prefix);
  n_values = BOX_ELEMENTS (target_names);
  tn->tn_out_slots = (state_slot_t **) dk_alloc_box (n_values * sizeof (caddr_t), DV_ARRAY_OF_LONG);
  DO_BOX (ST *, target_name, inx, target_names)
    {
      if (target_name)
	{
	  tn->tn_out_slots[inx] = sqlg_dfe_ssl (so, sqlo_df (so, target_name));
	}
    }
  END_DO_BOX;
  tn->tn_input = (state_slot_t**)box_copy ((caddr_t)(trans->_.trans.in));
  tn->tn_input_src = (state_slot_t**)box_copy ((caddr_t)(trans->_.trans.in));
  inx = 0;
  DO_SET (df_elt_t *, in, &tl->tl_params)
    {
      tn->tn_input_src[inx] = scalar_exp_generate (sc, in->dfe_tree->_.call.params[0], pre_code);
      tn->tn_input[inx] = scalar_exp_generate (sc, in->dfe_tree, pre_code);
      inx++;
    }
  END_DO_SET();
  if (!sqlg_is_vector)
    tn->tn_input_ref = tn->tn_input; /* if not vector are same */
  if (tl->tl_target)
    {
      tn->tn_target = (state_slot_t **)dk_alloc_box_zero (sizeof (caddr_t) * dk_set_length (tl->tl_target), DV_BIN);
      inx = 0;
      DO_SET (df_elt_t *, in, &tl->tl_target)
	{
	  tn->tn_target[inx++] = scalar_exp_generate (sc, in->dfe_tree, pre_code);
	}
      END_DO_SET();
    }
  sc->sc_trans = tn;
  tn->tn_distinct = trans->_.trans.distinct;
  tn->tn_direction = tl->tl_direction;
  tn->tn_is_second_in_direction3 = tl->tl_is_second_in_direction3;
  tn->tn_no_cycles = trans->_.trans.no_cycles;
  tn->tn_cycles_only = trans->_.trans.cycles_only;
  tn->tn_exists = trans->_.trans.exists;
  tn->tn_ordered = !trans->_.trans.no_order;
  tn->tn_shortest_only = trans->_.trans.shortest_only;
  tn->tn_step_set_no = ssl_new_variable (sc->sc_cc, "step_set", DV_LONG_INT);
  tn->tn_input_pos = (caddr_t*)box_copy_tree ((caddr_t) (TRANS_LR == tl->tl_direction ? trans->_.trans.in : trans->_.trans.out));
  tn->tn_output_pos = (caddr_t*)box_copy_tree ((caddr_t) (TRANS_LR == tl->tl_direction ? trans->_.trans.out : trans->_.trans.in));
  tn->tn_output = (state_slot_t **) box_copy ((caddr_t)(trans->_.trans.out));
  tn->tn_inlined_step = sqlg_dt_subquery (so, dt_dfe, NULL, target_names, tn->tn_step_set_no);
  dk_set_push (&sc->sc_cc->cc_query->qr_subq_queries, tn->tn_inlined_step);
  tn->tn_inlined_step->qr_select_node->src_gen.src_input = (qn_input_fn) select_node_input_subq;
  tn->tn_current_set = cc_new_instance_slot (sc->sc_cc);
  DO_BOX (caddr_t, n, inx, tn->tn_output_pos)
    {
      tn->tn_output[inx] = tn_nth_col (sc, tn, unbox (n));
    }
  END_DO_BOX;
  if (trans->_.trans.end_flag)
    tn->tn_end_flag = tn_nth_col (sc, tn, trans->_.trans.end_flag);
  for (inx = 0; inx < tn->tn_inlined_step->qr_select_node->sel_n_value_slots; inx++)
    {
      /* the cols that are neither calls to t_step, inputs or outputs or end flags are data columns to be returned from each step */
      state_slot_t * ssl = tn->tn_inlined_step->qr_select_node->sel_out_slots[inx];
      if (ssl != tn->tn_end_flag
	  && -1 == box_position ((caddr_t*)trans->_.trans.in, (caddr_t)(ptrlong)inx)
	  && -1 == box_position ((caddr_t*)trans->_.trans.out, (caddr_t)(ptrlong)inx)
	  && -1 == box_position_no_tag ((caddr_t*)tn->tn_step_out, (caddr_t)ssl)
	  && ssl != tn->tn_step_no_ret && ssl != tn->tn_path_no_ret)
	dk_set_push (&data_ssls, (void*)ssl);
    }
  if (data_ssls)
    tn->tn_data = (state_slot_t**) list_to_array (data_ssls);
  if (tn->tn_step_out || tn->tn_path_no_ret || tn->tn_data)
    {
      tn->tn_path_ctr = cc_new_instance_slot (sc->sc_cc);
      tn->tn_keep_path = 1;
    }
  tn->tn_after_join_test = sqlg_pred_body (so, dt_dfe->_.sub.after_join_test);
  if (trans->_.trans.min)
    tn->tn_min_depth = scalar_exp_generate (sc, trans->_.trans.min, pre_code);
  if (trans->_.trans.max)
    tn->tn_max_depth = scalar_exp_generate (sc, trans->_.trans.max, pre_code);
  clb_init (sc->sc_cc, &tn->clb, 1);
  sc->sc_any_clb = 1;
  tn->clb.clb_itcl = ssl_new_variable (sc->sc_cc, "itcl", DV_ANY);
  tn->tn_state = cc_new_instance_slot (sc->sc_cc);
  tn->tn_nth_cache_result = cc_new_instance_slot (sc->sc_cc);
  tn->tn_relation = ssl_new_variable (sc->sc_cc, "rel", DV_ANY);
  tn->tn_input_sets = cc_new_instance_slot (sc->sc_cc);
  tn->tn_to_fetch = ssl_new_variable (sc->sc_cc, "to_fetch", DV_ANY);

  tn->tn_is_primary = 1;
  if (tl->tl_complement)
    {
      tl->tl_complement->dfe_super = dt_dfe;
      tn->tn_complement = (trans_node_t*)sqlg_make_trans_dt (so, tl->tl_complement, target_names, pre_code);
      tn->tn_complement->tn_is_primary = 0;
      tn->tn_complement->tn_complement = tn;
    }
  if (dt_dfe->_.sub.after_join_test)
    tn->src_gen.src_after_test = sqlg_pred_body (so, dt_dfe->_.sub.after_join_test);
  sc->sc_order = old_order;
  sc->sc_trans = prev_trans;
  return ((data_source_t *) tn);
}


data_source_t *
sqlg_make_dt  (sqlo_t * so, df_elt_t * dt_dfe, ST **target_names, dk_set_t *pre_code)
{
  sql_comp_t * sc = so->so_sc;
  op_table_t * ot = dt_dfe->_.sub.ot;
  int n_values;
  int inx;
  query_t * qr;

  if (ot->ot_trans)
    {
      return sqlg_make_trans_dt (so, dt_dfe, target_names, pre_code);
    }
  if (ST_P (ot->ot_dt, PROC_TABLE))
    {
      return sqlg_generate_proc_ts (so, dt_dfe, pre_code);
    }

  {
    char old_order = sc->sc_order;
    SQL_NODE_INIT (subq_source_t, sqs, subq_node_input, subq_node_free);
    sqs->sqs_is_outer = ot->ot_is_outer;
    if (sqs->sqs_is_outer)
      sc->sc_order = TS_ORDER_KEY;
    if (!target_names)
      target_names =
	  sqlc_sel_names ((ST **) sqlp_union_tree_select (dt_dfe->_.sub.ot->ot_dt)->_.select_stmt.selection,
	  dt_dfe->_.sub.ot->ot_new_prefix);
    n_values = BOX_ELEMENTS (target_names);
    sqs->sqs_out_slots = (state_slot_t **) dk_alloc_box (n_values * sizeof (caddr_t), DV_ARRAY_OF_LONG);
    DO_BOX (ST *, target_name, inx, target_names)
      {
	if (target_name)
	  {
	    sqs->sqs_out_slots[inx] = sqlg_dfe_ssl (so, sqlo_df (so, target_name));
	  }
      }
    END_DO_BOX;
	sqs->sqs_set_no = ssl_new_variable (sc->sc_cc, "set_no", DV_LONG_INT);
	sqs->sqs_batch_size = cl_req_batch_size;
    qr = sqlg_dt_subquery (so, dt_dfe, NULL, target_names, sqs->sqs_set_no);
    sqs->sqs_query = qr;
    qr->qr_select_node->src_gen.src_input = (qn_input_fn) select_node_input_subq;
    sqs->sqs_after_join_test = sqlg_pred_body (so, dt_dfe->_.sub.after_join_test);
    if (qr->qr_cl_run_started )
      sc->sc_cc->cc_query->qr_cl_run_started = qr->qr_cl_run_started;
    sc->sc_order = old_order;
    return ((data_source_t *) sqs);
  }
}


df_elt_t *
dfe_super_dt (df_elt_t * dfe)
{
  /* immediately enclosing dt */
  while  (DFE_DT != dfe->dfe_type)
    dfe = dfe->dfe_super;
  return dfe;
}


ptrlong *
sqlg_qexp_corresponding_pos (sqlo_t * so, ST ** target_names, df_elt_t * qexp)
{
  /* return  list of positions of the corresponding by cols in the selection */
  dk_set_t res = NULL;
  /*ST * set_tree = set_exp_dt->_.sub.ot->ot_dt;*/
  int cinx, tinx;
  if (!target_names || !qexp->_.qexp.corresponding)
    return NULL;
  DO_BOX (ST *, target_ref, tinx, target_names)
    {
      DO_BOX (caddr_t, cname, cinx, qexp->_.qexp.corresponding)
	{
	  if (0 == strcmp (cname, target_ref->_.col_ref.name))
	    {
	      t_set_push (&res, (void*)(ptrlong)tinx);
	      goto next;
	    }
	}
      END_DO_BOX;
    next: ;
    }
  END_DO_BOX;
  return (ptrlong*)t_list_to_array (res);
}

void
sqlg_qexp_target_corresponding (sqlo_t * so, ST ** target_names, df_elt_t * qexp)
{
  /* add the corresponding by cols to the target if they are not there already.
   * Loop over the holes in target_names and fill if the item is in the corresponding by names. */
  df_elt_t * set_exp_dt = dfe_super_dt (qexp);
  caddr_t top_pref = set_exp_dt->_.sub.ot->ot_new_prefix;
  ST * set_tree = set_exp_dt->_.sub.ot->ot_dt;
  int cinx, tinx;
  ST * union_sel = sqlp_union_tree_select (set_tree);
  if (!target_names)
    return;
  DO_BOX (ST *, target_ref, tinx, target_names)
    {
      if (!target_ref)
	{
	  caddr_t col_name = ((ST*) union_sel->_.select_stmt.selection[tinx])->_.as_exp.name;
	  DO_BOX (caddr_t, cname, cinx, qexp->_.qexp.corresponding)
	    {
	      if (0 == strcmp (cname, target_ref->_.col_ref.name))
		goto next;
	    }
	  END_DO_BOX;
	  target_names[tinx] = (ST*) t_list (3, COL_DOTTED, top_pref, col_name);
	next: ;
	}
    }
  END_DO_BOX;
}


setp_node_t *
qr_find_distinct (query_t * qr)
{
  DO_SET (setp_node_t *, setp, &qr->qr_nodes)
    {
      if (IS_QN (setp, setp_node_input)
	  && setp->src_gen.src_continuations && setp->src_gen.src_continuations->data == (void*)qr->qr_select_node)
	return setp;
    }
  END_DO_SET();
  GPF_T1 ("expecting to find a distinct node in a union etc term");
  return NULL;
}


int
dfe_qexp_list (df_elt_t * dfe, int op, dk_set_t * res)
{
  if (DFE_DT == dfe->dfe_type)
    {
      df_elt_t * first = dfe->_.sub.first->dfe_next;
      if (DFE_QEXP == first->dfe_type)
	dfe = first;
      else if (DFE_DT == first->dfe_type)
	{
	  first = first->_.sub.first->dfe_next;
	  if (first && DFE_QEXP == first->dfe_type)
	    dfe = first;
	}
    }
  if (DFE_DT == dfe->dfe_type)
    {
      t_set_push (res, (void*)dfe);
      return 1;
    }
  if (DFE_QEXP == dfe->dfe_type && op == dfe->_.qexp.op)
    {
      if (!dfe_qexp_list (dfe->_.qexp.terms[0], op, res) || !dfe_qexp_list (dfe->_.qexp.terms[1], op, res))
	return 0;
      return 1;
    }
  else
    return 0;
}


data_source_t *
sqlg_set_stmt (sqlo_t * so, df_elt_t * qexp, ST ** target_names)
{
  dk_set_t terms = NULL;
  ST * tree = qexp->dfe_tree;
  sql_comp_t * sc = so->so_sc;
  setp_node_t *setp_left, *setp_right;
  query_t *left_qr, *right_qr;
  char save_co = sc->sc_no_distinct_colocate;
  char is_best = 0;

  select_node_t *sel = NULL;
  ptrlong * corr_pos;
  comp_context_t *cc = sc->sc_cc;
  SQL_NODE_INIT (union_node_t, un, union_node_input, union_node_free);

  sc->sc_is_union = 1;
  if (BOX_ELEMENTS (tree) > 4)
    is_best = (char) tree->_.set_exp.is_best;
  if (qexp->_.qexp.is_in_fref && ST_P (tree, UNION_ALL_ST) && dfe_qexp_list (qexp, UNION_ALL_ST, &terms) && terms)
    {
      int first = 1;
      terms = dk_set_nreverse (terms);
      DO_SET (df_elt_t *, dt, &terms)
	{
	  query_t * qr;
	  sc->sc_delay_colocate = qexp->_.qexp.is_in_fref;
	  qr = sqlg_dt_subquery (so, dt, NULL, target_names, sc->sc_set_no_ssl);
	  if (first)
	    left_qr = qr;
	  else 
	    first = 0;
	  qr->qr_select_node->src_gen.src_input = (qn_input_fn)select_node_input_subq;
	  qr->qr_super = cc->cc_query;
	  dk_set_push (&un->uni_successors, (void*)qr);
	  dk_set_push (&sc->sc_cc->cc_query->qr_subq_queries, qr);
	}
      END_DO_SET();
      un->uni_cl_colocate_delayed = 1;
      un->uni_successors = dk_set_nreverse (un->uni_successors);
      sel = left_qr->qr_select_node;
      un->uni_op = tree->type;
      sc->sc_no_distinct_colocate = save_co;
      goto fin;
    }
  sqlg_qexp_target_corresponding (so, target_names, qexp);
  corr_pos = sqlg_qexp_corresponding_pos (so, target_names, qexp);
  if (!ST_P (tree, UNION_ALL_ST))
    {
      if (!corr_pos)
	corr_pos = (ptrlong*)1;
      qexp->_.qexp.terms[0]->_.sub.dist_pos = corr_pos;
      qexp->_.qexp.terms[1]->_.sub.dist_pos = corr_pos;
    }
  sc->sc_no_distinct_colocate = 1;
  left_qr = sqlg_dt_subquery (so, qexp->_.qexp.terms[0], NULL, target_names, sc->sc_set_no_ssl);
  right_qr = sqlg_dt_subquery (so, qexp->_.qexp.terms[1], NULL, target_names, sc->sc_set_no_ssl);
  sc->sc_no_distinct_colocate = save_co;
  right_qr->qr_select_node->src_gen.src_input = (qn_input_fn)select_node_input_subq;
  dk_set_push (&sc->sc_cc->cc_query->qr_subq_queries, left_qr);
  dk_set_push (&sc->sc_cc->cc_query->qr_subq_queries, right_qr);

  sel = left_qr->qr_select_node;
  un->uni_op = tree->type;
  if (!ST_P (tree, UNION_ST) && !ST_P (tree, UNION_ALL_ST))
    {
      un->uni_sequential = 1;
      dk_set_push (&un->uni_successors, (void *) left_qr);
      dk_set_push (&un->uni_successors, (void *) right_qr);
    }
  else
    {
      dk_set_push (&un->uni_successors, (void *) right_qr);
      dk_set_push (&un->uni_successors, (void *) left_qr);
    }
  left_qr->qr_super = cc->cc_query;
  right_qr->qr_super = cc->cc_query;
  if (!ST_P (tree, UNION_ALL_ST))
    {
      setp_left = qr_find_distinct (left_qr);
      setp_right = qr_find_distinct (right_qr);
      setp_left->setp_ssa.ssa_set_no = sc->sc_set_no_ssl;
      setp_right->setp_ha->ha_tree = setp_left->setp_ha->ha_tree;
      setp_right->setp_ha->ha_set_no = setp_right->setp_ssa.ssa_set_no =  setp_left->setp_ssa.ssa_set_no;
      setp_right->setp_ha->ha_ref_itc = setp_left->setp_ha->ha_ref_itc;
      setp_right->setp_ha->ha_insert_itc = setp_left->setp_ha->ha_insert_itc;
      setp_right->setp_ha->ha_bp_ref_itc = setp_left->setp_ha->ha_bp_ref_itc;
      if (!ST_P (tree, UNION_ST))
	setp_right->src_gen.src_continuations = NULL;
	  setp_left->setp_set_op = (int) tree->type;
	}
 fin:
  cc->cc_query->qr_head_node = (data_source_t *) un;
  un->uni_nth_output = ssl_new_inst_variable (sc->sc_cc, "nth", DV_LONG_INT);
  cc->cc_query->qr_select_node = sel;
  cc->cc_query->qr_bunion_node = is_best ? un : NULL;
  DO_SET (query_t *, u_qr, &un->uni_successors)
  {
    cc->cc_query->qr_nodes = dk_set_conc (dk_set_copy (u_qr->qr_nodes), cc->cc_query->qr_nodes);
    u_qr->qr_bunion_reset_nodes = u_qr->qr_nodes;
    u_qr->qr_nodes = NULL;

    u_qr->qr_is_bunion_term = is_best;
    if (cc->cc_query->qr_cl_run_started)
      u_qr->qr_cl_run_started = cc->cc_query->qr_cl_run_started;
    else if (u_qr->qr_cl_run_started)
      cc->cc_query->qr_cl_run_started = u_qr->qr_cl_run_started;
  }
  END_DO_SET ();
#if 0
  if (!sc->sc_super)
    sel->src_gen.src_input = (qn_input_fn) select_node_input;
#endif
  return ((data_source_t*) un);
}


void
sqlg_dfe_code (sqlo_t * so, df_elt_t * dfe, dk_set_t * code, int succ, int fail, int unk)
{
  sql_comp_t * sc = so->so_sc;
  ST * tree = dfe->dfe_tree;
  switch (dfe->dfe_type)
    {
    case DFE_BOP_PRED:
      {
	state_slot_t *left_ssl;
	state_slot_t *right_ssl;
	left_ssl = scalar_exp_generate (sc, tree->_.bin_exp.left, code);
	right_ssl = scalar_exp_generate (sc, tree->_.bin_exp.right, code);
	cv_compare (code, (int) tree->type, left_ssl, right_ssl, succ, fail, unk);
	if (ST_P (tree, BOP_LIKE))
	  {
	    instruction_t *ins = (instruction_t *)(*code)->data;
	    bop_comparison_t *pred = ins ? (bop_comparison_t *) ins->_.pred.cmp : NULL;
	    if (pred)
	      pred->cmp_like_escape = dfe->_.bin.escape;
	  }
	break;
      }
    case DFE_BOP:
    case DFE_CALL:
    case DFE_CONTROL_EXP:
      {
	scalar_exp_generate (sc, tree, code);
	break;
      }
    case DFE_EXISTS:
      {
	NEW_INSTR (ins, IN_PRED, code);
	ins->_.pred.fail = fail;
	ins->_.pred.succ = succ;
	ins->_.pred.unkn = unk;
	ins->_.pred.func = subq_comp_func;
	{
	  char ord = sc->sc_order;
	  query_t * qr;
	  NEW_VARZ (subq_pred_t, subp);
	  dfe_unit_col_loci (dfe);
	  sc->sc_order = TS_ORDER_NONE;
	  qr = subp->subp_query = sqlg_dt_query (so, dfe, NULL, NULL);
	  sc->sc_order = ord;
	  dk_set_push (&sc->sc_cc->cc_query->qr_subq_queries, subp->subp_query);
	  qr->qr_select_node->src_gen.src_input = (qn_input_fn) select_node_input_subq;
	  qr->qr_select_node->sel_vec_role = SEL_VEC_EXISTS;
	  ((set_ctr_node_t*)qr->qr_head_node)->sctr_not_in_top_and = dfe->_.sub.not_in_top_and;
	  sqlg_parallel_ts_seq (sc, dfe, (table_source_t*)qr->qr_head_node, NULL, qr->qr_select_node);
	  subp->subp_type = EXISTS_PRED;
	  ins->_.pred.cmp =subp;

	}
	break;
      }
    case DFE_VALUE_SUBQ:
      {
	int old_ord = so->so_sc->sc_order;
	query_t * qr;
	state_slot_t * ssl, *ext_sets;
	df_elt_t * org_dfe;
	so->so_sc->sc_order = TS_ORDER_NONE;
	qr  = sqlg_dt_query (so, dfe, NULL, (ST **) t_list (1, dfe->dfe_tree)); /* this is to prevent assignment of NULL to constant ssl*/
	ssl  = 	cv_subq_qr (sc, code, qr);
	so->so_sc->sc_order = old_ord;
	org_dfe  = sqlo_df (so, dfe->dfe_tree); /* the org one, not a layout copy is used to associate the ssl to the code */
	org_dfe->dfe_ssl = ssl;
	ext_sets = ssl_new_variable (sc->sc_cc, "ext_sets", DV_LONG_INT);
	((set_ctr_node_t*)qr->qr_head_node)->sctr_ext_set_no = ext_sets;
	((set_ctr_node_t*)qr->qr_head_node)->sctr_not_in_top_and = 1;
	qr->qr_select_node->sel_ext_set_no = ext_sets;
	qr->qr_select_node->src_gen.src_input = (qn_input_fn) select_node_input_subq;
	qr->qr_select_node->sel_vec_role = SEL_VEC_SCALAR;
	qr->qr_select_node->sel_is_scalar_agg = sc->sc_is_scalar_agg;
	qr->qr_select_node->sel_vec_set_mask = cc_new_instance_slot (sc->sc_cc);
	sqlg_parallel_ts_seq (sc, dfe, (table_source_t*)qr->qr_head_node, NULL, qr->qr_select_node);
	dk_set_push (&sc->sc_cc->cc_query->qr_subq_queries, qr);
	break;
      }
    default:
      {
	sqlc_new_error (sc->sc_cc, "42000", "SQ084", "Subquery predicate not supported.");
      }
    }
}


void
sqlg_pred_1 (sqlo_t * so, df_elt_t ** body, dk_set_t * code, int succ, int fail, int unk)
{
  sql_comp_t * sc = so->so_sc;
  int inx;
  ptrlong op = (ptrlong) body[0];
  int n_terms = BOX_ELEMENTS (body);
  if (BOP_NOT == op)
    {
      sqlg_pred_1 (so, (df_elt_t **) body[1], code, fail, succ, unk);
      return;
    }
  if (BOP_OR == op)
    {
      for (inx = 1; inx < n_terms; inx++)
	{
	  if (inx != n_terms - 1)
	    {
	      jmp_label_t temp_fail = sqlc_new_label (sc);
	      sqlg_pred_1 (so, (df_elt_t **) body[inx], code, succ, temp_fail, temp_fail);
	      cv_label (code, temp_fail);
	    }
	  else
	    {
	      sqlg_pred_1 (so, (df_elt_t **) body[inx], code, succ, fail, unk);
	    }
	}
      return;
    }
  if (BOP_AND == op)
    {
      for (inx = 1; inx < n_terms; inx++)
	{
	  if (inx < n_terms - 1)
	    {
	      jmp_label_t temp_succ = sqlc_new_label (sc);
	      sqlg_pred_1 (so, (df_elt_t **) body[inx], code, temp_succ, fail, unk);
	      cv_label (code, temp_succ);
	    }
	  else
	    sqlg_pred_1 (so, (df_elt_t **) body[inx], code, succ, fail, unk);
	}
      return;
    }
  else
    {
      for (inx = 1; inx < n_terms; inx++)
	{
	  char save = sc->sc_re_emit_code;
	  sc->sc_re_emit_code = !sc->sc_is_first_cond;
	  sqlg_dfe_code (so, body[inx], code, succ, fail, unk);
	  sc->sc_re_emit_code = save;
	}
      sc->sc_is_first_cond = 0;
    }
}


static void
sqlg_pred_find_duplicates (sqlo_t *so, df_elt_t **body, dk_set_t *dfe_set, dk_set_t *dup_set)
{
  int inx;
  if (DV_TYPE_OF (body) == DV_ARRAY_OF_POINTER)
    {
      int n_terms = BOX_ELEMENTS (body);
      for (inx = 1; inx < n_terms; inx++)
	sqlg_pred_find_duplicates (so, (df_elt_t **) body[inx], dfe_set, dup_set);
    }
  else if (IS_BOX_POINTER (body))
    {
      df_elt_t *pred;
      int is_dup = 0;
      pred = (df_elt_t *) body;

      if (pred->dfe_tree)
	pred = sqlo_df_elt (so, pred->dfe_tree);
      if (!pred)
	pred = (df_elt_t *) body;
      if (pred->dfe_type != DFE_BOP_PRED)
	{
	  if (dk_set_member (*dfe_set, pred))
	    {
	      is_dup = 1;
	      t_set_push (dup_set, pred);
	    }
	  else
	    t_set_push (dfe_set, pred);
	}
      if (!is_dup && pred->dfe_type == DFE_CONTROL_EXP)
	{ /* GK: handles the case when an subexp is already df-ed at top level dfe_elts
	    and is again found in a control_exp branch. */
	  dk_set_t control_dfe_set = NULL, control_dup_set = NULL;
	  int inx;

	  /* GK: looks for all the subexps in a control exp */
	  DO_BOX (df_elt_t *, term, inx, pred->_.control.terms)
	    {
	      id_hash_t *private_elts = so->so_df_private_elts;

	      so->so_df_private_elts = pred->_.control.private_elts[inx];
	      sqlg_pred_find_duplicates (so, (df_elt_t **) term, &control_dfe_set, &control_dup_set);
	      so->so_df_private_elts = private_elts;
	    }
	  END_DO_BOX;
	  /* GK: and if any of the above is found so far make it a dup.
	     Note that it won't make a dup if two subexps are found in
	     the control_exp : this is handled by the private_elts code */
	  DO_SET (ST *, elt, &control_dfe_set)
	    {
	      if (dk_set_member (*dfe_set, elt))
		t_set_push (dup_set, elt);
	      else
		t_set_push (dfe_set, elt);
	    }
	  END_DO_SET ();
	}
    }
}


code_vec_t
sqlg_pred_body_1 (sqlo_t * so, df_elt_t **  body, dk_set_t append)
{
  dk_set_t code = NULL;
  dk_set_t dfe_set = NULL, dup_set = NULL;
  sql_comp_t * sc = so->so_sc;
  jmp_label_t succ = sqlc_new_label (sc);
  jmp_label_t fail = sqlc_new_label (sc);
  if (!body || 1 >= BOX_ELEMENTS (body))
    {
      if (append)
	{
	  cv_bret (&append, 1);
	  return code_to_cv (so->so_sc, append);
	}
      else
	return NULL;
    }
  sqlg_pred_find_duplicates (so, body, &dfe_set, &dup_set);
  if (dup_set)
    {
      df_elt_t **body1, **cond, **dup_arr;

      body1 = (df_elt_t **) t_alloc_box (box_length (body) + sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memset (body1, 0, box_length (body1));
      memcpy (&(body1[1]), body, box_length (body));

      dup_arr = (df_elt_t **) t_list_to_array (dup_set);
      cond = (df_elt_t **) t_alloc_box (box_length (dup_arr) + sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memset (cond, 0, box_length (cond));
      memcpy (&(cond[1]), dup_arr, box_length (dup_arr));
      cond[0] = (df_elt_t *) (ptrlong) DFE_PRED_BODY;

      body1[0] = body[0];
      body1[1] = (df_elt_t *) cond;

      body = body1;
    }
  sqlg_pred_1 (so, body, &code, succ, fail, fail);
  cv_label (&code, succ);
  cv_bret (&code, 1);
  cv_label (&code, fail);
  cv_bret (&code, 0);
  if (append)
    code = NCONC (append, code);
  sqlg_pre_code_dpipe (so, &code, NULL);
  return (code_to_cv (so->so_sc, code));
}


code_vec_t
sqlg_pred_body (sqlo_t * so, df_elt_t **  body)
{
  code_vec_t cv;
  dk_set_t save = so->so_sc->sc_re_emitted_dfes;
  so->so_sc->sc_re_emitted_dfes = NULL;
  so->so_sc->sc_is_first_cond = 1;
  cv = sqlg_pred_body_1 (so, body, NULL);
  DO_SET (df_elt_t *, dfe, &so->so_sc->sc_re_emitted_dfes)
    {
      dfe->dfe_ssl = NULL;
    }
  END_DO_SET();
  so->so_sc->sc_re_emitted_dfes = save;
  return cv;
}

data_source_t *
sql_node_last (data_source_t * src)
{
  while (src->src_continuations)
    src = (data_source_t *) src->src_continuations->data;
  return src;
}


void dfe_list_gb_dependant (sqlo_t *so, df_elt_t * dfe,
    df_elt_t *terminal, df_elt_t *super, dk_set_t *res, dk_set_t *out, int *term_found);

void dfe_set_gb_dependant (sqlo_t *so, dk_set_t dfe,
    df_elt_t *terminal, df_elt_t *super, dk_set_t *res, dk_set_t *out, int *term_found);

#define DFE_SET_MEMBER(set,dfe) \
	(dk_set_member (set, (IS_BOX_POINTER (dfe) && (dfe)->dfe_tree) ? sqlo_df (so, (dfe)->dfe_tree) : (dfe)))
void
dfe_unit_gb_dependant (sqlo_t *so, df_elt_t * dfe,
    df_elt_t *terminal, df_elt_t *super, dk_set_t *res, dk_set_t *out, int *term_found)
{
  int inx;
  df_elt_t *dfe_super;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (dfe))
    {
      dfe_list_gb_dependant (so, dfe, terminal, super, res, out, term_found);
      return;
    }
  if (!IS_BOX_POINTER (dfe))
    return;
  if (terminal && dfe == terminal)
    {
      *term_found = 1;
      return;
    }
  if (dfe->dfe_super)
    {
      for (dfe_super = dfe->dfe_super; dfe_super; dfe_super = dfe_super->dfe_super)
	if (dfe_super->dfe_tree == super->dfe_tree)
	  break;
      if (!dfe_super)
	return;
    }
  if (res && !out && (dfe->dfe_type == DFE_BOP || dfe->dfe_type == DFE_CALL))
    t_set_pushnew (res, sqlo_df (so, dfe->dfe_tree));

  switch (dfe->dfe_type)
    {
    case DFE_TABLE:
      dfe_set_gb_dependant (so, dfe->_.table.all_preds, terminal, super, res, out, term_found);
      if (*term_found)
	return;
      break;
    case DFE_EXISTS:
    case DFE_VALUE_SUBQ:
    case DFE_DT:
      if (dfe->_.sub.generated_dfe)
	{
	  if (out && res && DFE_SET_MEMBER (*res, dfe->_.sub.generated_dfe))
	    t_set_pushnew (out, dfe->_.sub.generated_dfe);
	  else
	    dfe_unit_gb_dependant (so, dfe->_.sub.generated_dfe, terminal, super, res, out, term_found);
	  if (*term_found)
	    return;
	}
      else
	{
	  op_table_t * ot = dfe->_.sub.ot;
	  if (ST_P (ot->ot_dt, SELECT_STMT))
	    {
	      DO_BOX (ST *, as_exp, inx, ot->ot_dt->_.select_stmt.selection)
		{
		  df_elt_t * dfe1 = sqlo_df_elt (so, as_exp);
		  if (dfe1)
		    {
		      if (out && res && DFE_SET_MEMBER (*res, dfe1))
			t_set_pushnew (out, dfe1);
		      else
			dfe_unit_gb_dependant (so, dfe1, terminal, super, res, out, term_found);
		      if (*term_found)
			return;
		    }
		}
	      END_DO_BOX;
	    }
	  dfe_list_gb_dependant (so, (df_elt_t *) dfe->_.sub.after_join_test, terminal, super, res, out, term_found);
	  if (*term_found)
	    return;
	  DO_SET (df_elt_t *, pred, &dfe->_.sub.dt_preds)
	    {
	      if (out && res && DFE_SET_MEMBER (*res, pred))
		t_set_pushnew (out, pred);
	      else
		dfe_unit_gb_dependant (so, pred, terminal, super, res, out, term_found);
	      if (*term_found)
		return;
	    }
	  END_DO_SET();
	  DO_SET (df_elt_t *, pred, &dfe->_.sub.dt_imp_preds)
	    {
	      if (out && res && DFE_SET_MEMBER (*res, pred))
		t_set_pushnew (out, pred);
	      else
		dfe_unit_gb_dependant (so, pred, terminal, super, res, out, term_found);
	      if (*term_found)
		return;
	    }
	  END_DO_SET();
	}

      break;
    case DFE_QEXP:
      DO_BOX (df_elt_t *, elt, inx, dfe->_.qexp.terms)
	{
	  if (out && res && DFE_SET_MEMBER (*res, elt))
	    t_set_pushnew (out, elt);
	  else
	    dfe_unit_gb_dependant (so, elt, terminal, super, res, out, term_found);
	  if (*term_found)
	    return;
	}
      END_DO_BOX;
      break;
    case DFE_GROUP:
      DO_SET (ST *, fref, &dfe->_.setp.fun_refs)
	{
	  df_elt_t * dfe1 = sqlo_df_elt (so, fref);
	  if (dfe1)
	    {
	      if (out && res && DFE_SET_MEMBER (*res, dfe1))
		t_set_pushnew (out, dfe1);
	      else
		dfe_unit_gb_dependant (so, dfe1, terminal, super, res, out, term_found);
	      if (*term_found)
		return;
	    }
	}
      END_DO_SET();
      dfe_list_gb_dependant (so, (df_elt_t *)dfe->_.setp.after_test, terminal, super, res, out, term_found);
      if (*term_found)
	return;
      break;
    case DFE_BOP:
    case DFE_BOP_PRED:
      if (out && res && DFE_SET_MEMBER (*res, dfe->_.bin.left))
	t_set_pushnew (out, dfe->_.bin.left);
      else
	dfe_unit_gb_dependant (so, dfe->_.bin.left, terminal, super, res, out, term_found);
      if (*term_found)
	return;

      if (out && res && DFE_SET_MEMBER (*res, dfe->_.bin.right))
	t_set_pushnew (out, dfe->_.bin.right);
      else
	dfe_unit_gb_dependant (so, dfe->_.bin.right, terminal, super, res, out, term_found);
      if (*term_found)
	return;
      break;

    case DFE_CALL:
      dfe_list_gb_dependant (so, (df_elt_t *)dfe->_.call.args, terminal, super, res, out, term_found);
      if (*term_found)
	return;
      if (out && res && DFE_SET_MEMBER (*res, dfe->_.call.func_exp))
	t_set_pushnew (out, dfe->_.call.func_exp);
      else
	dfe_unit_gb_dependant (so, dfe->_.call.func_exp, terminal, super, res, out, term_found);
      if (*term_found)
	return;
      break;

    case DFE_ORDER:
      dfe_list_gb_dependant (so, (df_elt_t *) dfe->_.setp.after_test, terminal, super, res, out, term_found);
      if (*term_found)
	return;
      DO_BOX (ST *, spec, inx, dfe->_.setp.specs)
	{
	  df_elt_t * exp = sqlo_df (so, dfe->_.setp.is_distinct ? (ST*)spec : spec->_.o_spec.col);
	  dfe_list_gb_dependant (so, exp, terminal, super, res, out, term_found);
	  if (*term_found)
	    return;
	}
      END_DO_BOX;
      break;

    default:
      break;
    }
}


void
dfe_list_gb_dependant (sqlo_t *so, df_elt_t * dfe,
    df_elt_t *terminal, df_elt_t *super, dk_set_t *res, dk_set_t *out, int *term_found)
{
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (dfe))
    {
      int inx;
      df_elt_t ** dfe_arr = (df_elt_t **) dfe;
      DO_BOX (df_elt_t *, elt, inx, dfe_arr)
	{
	  if (out && res && DFE_SET_MEMBER (*res, elt))
	    t_set_pushnew (out, elt);
	  else
	    dfe_unit_gb_dependant (so, elt, terminal, super, res, out, term_found);
	  if (*term_found)
	    return;
	}
      END_DO_BOX;
    }
  else
    {
      while (dfe)
	{
	  if (out && res && DFE_SET_MEMBER (*res, dfe))
	    t_set_pushnew (out, dfe);
	  else
	    dfe_unit_gb_dependant (so, dfe, terminal, super, res, out, term_found);
	  if (*term_found)
	    return;
	  dfe = dfe->dfe_next;
	}
    }
}


void
dfe_set_gb_dependant (sqlo_t *so, dk_set_t set,
    df_elt_t *terminal, df_elt_t *super, dk_set_t *res, dk_set_t *out, int *term_found)
{
  DO_SET (df_elt_t *, elt, &set)
    {
      if (elt)
	{
	  if (out && res && DFE_SET_MEMBER (*res, elt))
	    t_set_pushnew (out, elt);
	  else
	    dfe_unit_gb_dependant (so, elt, terminal, super, res, out, term_found);
	  if (*term_found)
	    return;
	}
    }
  END_DO_SET ();
}


void
setp_key_insert_spec (setp_node_t * setp)
{
  dbe_key_t * key = setp->setp_ha->ha_key;
  int inx = 0, n;
  search_spec_t **next_spec = &setp->setp_insert_spec.ksp_spec_array;


  for (n = 0; n < key->key_n_significant; n++)
    {
      dbe_column_t *col = (dbe_column_t *) dk_set_nth(key->key_parts, n);
      NEW_VARZ (search_spec_t, sp);

      sp->sp_min = inx;
      sp->sp_min_op = CMP_EQ;
      sp->sp_max_op = CMP_NONE;

      sp->sp_next = NULL;
      *next_spec = sp;
      next_spec = &sp->sp_next;
      sp->sp_is_reverse = ORDER_DESC == (ptrlong) dk_set_nth (setp->setp_key_is_desc, inx);
      sp->sp_cl = *key_find_cl (key, col->col_id);
      if (col)
	{
	  sp->sp_collation = col->col_sqt.sqt_collation;
	}
      inx++;
    }
  ksp_cmp_func (&setp->setp_insert_spec, NULL);
}


int
sqlg_is_multistate_gb (sqlo_t * so)
{
  /* a gby in a dt that is not the first will have multiple rows of input and must prefix the grouping cols with set no */
  /* Same for a query with parameters, may get run on an array */
  dk_set_t pars;
  sql_comp_t * sc = so->so_sc;
  query_t * qr;
  for (qr = sc->sc_cc->cc_query->qr_super; qr; qr = qr->qr_super)
    {
      DO_SET (data_source_t *, qn, &qr->qr_nodes)
	{
	  /* a derived table with gby/oby is multistate and will have the set no in the setp  if in the enclosing there is a ts or dt before it.  But  a dt w no qr   does not count because this is the immediately enclosing, not a previous one */
	  if (IS_TS (qn) || (IS_QN (qn, subq_node_input) && ((subq_source_t*)qn)->sqs_query))
	    return 1;
	}
      END_DO_SET();
    }
  if ((pars = sc->sc_cc->cc_query->qr_parms))
    {
      state_slot_t * ssl = (state_slot_t *)pars->data;
      if (ssl->ssl_name && ':'== ssl->ssl_name[0])
	return 1;
    }
  return 0;
}


void
sqlg_setp_keys (sqlo_t * so, setp_node_t * setp, int force_gb, long n_rows)
{
  sql_comp_t * sc = so->so_sc;
  hash_area_t * ha;
  int op = (force_gb || setp->setp_gb_ops) ? HA_GROUP : HA_ORDER;
  if (HA_GROUP == op)
    setp->setp_set_no_in_key = sqlg_is_multistate_gb (so);
  if (setp->setp_set_no_in_key)
    {
      dk_set_push (&setp->setp_keys, (void*) so->so_sc->sc_set_no_ssl);
    }
  setp_distinct_hash (sc, setp, n_rows, op);
  ha = setp->setp_ha;
  ha->ha_allow_nulls = 1;
  ha->ha_op = op;
  if (force_gb || !setp->setp_gb_ops)
    setp_key_insert_spec (setp);
}


void
sqlg_setp_append (sqlo_t * so, data_source_t ** head, setp_node_t * setp)
{
  sql_comp_t * sc = so->so_sc;
  table_source_t * last = (table_source_t *) sql_node_last (*head);
  if (IS_TS_NODE (last)
      && !last->src_gen.src_after_code
      && !last->ts_inx_op && !last->src_gen.src_after_test && !last->ts_is_outer && !setp->setp_any_user_aggregate_gos)
    {
      key_source_t * ks = last->ts_main_ks ? last->ts_main_ks : last->ts_order_ks;
      if (setp->src_gen.src_pre_code
	  && cv_is_local (setp->src_gen.src_pre_code)
	  && !ks->ks_local_code && (!sc->sc_qn_to_dpipe || !gethash ((void *) setp, sc->sc_qn_to_dpipe)))
	{
	  ks->ks_local_code = setp->src_gen.src_pre_code;
	  setp->src_gen.src_pre_code = NULL;
	}
      if (!setp->src_gen.src_pre_code && !(sc->sc_qn_to_dpipe && gethash ((void *) setp, sc->sc_qn_to_dpipe)) && !sqlg_is_vector)
	{
	  ks->ks_setp = setp;
	  return;
	}
    }
  sql_node_append (head, (data_source_t *) setp);
}


hash_area_t *
sqlg_distinct_fun_ref_col (sql_comp_t * sc, state_slot_t * data, dk_set_t prev_keys, long n_rows, state_slot_t * set_no)
{
  setp_node_t setp;
  memset (&setp, 0, sizeof (setp));
  setp.src_gen.src_query = sc->sc_cc->cc_query;
  setp.setp_ssa.ssa_set_no = set_no;
  setp.setp_keys = dk_set_copy (prev_keys);
  if (dk_set_position (setp.setp_keys, (void*) data) < 0)
    dk_set_push (&setp.setp_keys, (void*) data);
  setp_distinct_hash (sc, &setp, n_rows, HA_DISTINCT);
  setp.setp_ha->ha_set_no = set_no;
  dk_set_free (setp.setp_keys);
  return (setp.setp_ha);
}


void
sqlg_find_aggregate_sqt (dbe_schema_t *schema, sql_type_t *arg_sqt, ST *fref, sql_type_t *res_sqt)
{
  user_aggregate_t *ua;
  switch (fref->_.fn_ref.fn_code)
    {
    case AMMSC_COUNT:
    case AMMSC_COUNTSUM:
      res_sqt->sqt_dtp = DV_LONG_INT;
      res_sqt->sqt_non_null = 1;
      break;
    case AMMSC_USER:
      ua = (user_aggregate_t *)(unbox_ptrlong (fref->_.fn_ref.user_aggr_addr));
      if (!ua->ua_init.uaf_bif)
	{
	  query_t * proc = sch_proc_def (schema, ua->ua_init.uaf_name);
	  if (proc && (NULL != proc->qr_parms))
	    {
	      state_slot_t * sl1 = (state_slot_t *)(proc->qr_parms->data);
	      res_sqt[0] = sl1->ssl_sqt;
	      res_sqt->sqt_non_null = 0;
	      break;
	    }
	}
      res_sqt->sqt_dtp = DV_ANY;
      break;
    case AMMSC_MIN:
    case AMMSC_MAX:
      res_sqt[0] = arg_sqt[0];
      break;
    case AMMSC_SUM:
    case AMMSC_AVG:
      res_sqt[0] = arg_sqt[0];
      if (DV_NUMERIC == res_sqt->sqt_dtp)
	{
	  res_sqt->sqt_precision = NUMERIC_MAX_PRECISION;
	  res_sqt->sqt_scale = NUMERIC_MAX_SCALE;
	}
      break;
    default:
      GPF_T;
    }
}

#define IS_AGGREGATE(op) ((op) > AMMSC_NONE && (op) <= AMMSC_USER)

int
sqlg_tree_has_aggregate (ST *tree)
{
  int res = 0;

  if (!ARRAYP (tree))
    res = 0;
  else if (ST_P (tree, FUN_REF) && IS_AGGREGATE (tree->_.fn_ref.fn_code))
    res = 1;
  else
    {
      int inx;
      DO_BOX (ST *, elt, inx, ((ST **)tree))
	{
	  if (sqlg_tree_has_aggregate (elt))
	    {
	      res = 1;
	      break;
	    }
	}
      END_DO_BOX;
    }
  return res;
}

dk_set_t
always_null_agg_arr_gen (sql_comp_t* sc, dk_set_t code, ST ** etalon)
{
    int inx;
    dk_set_t ns = 0;
    DO_BOX (ST *, item, inx, etalon)
      {
        state_slot_t *ssl;
	if (!sqlg_tree_has_aggregate (item))
	  continue;
        ssl = scalar_exp_generate (sc, item, &code);
	dk_set_push (&ns, ssl);
      }
    END_DO_BOX;
    return ns;
}

dk_set_t
always_null_arr_gen (sql_comp_t* sc, dk_set_t code, ST ** etalon, ST ** subseq)
{
    int inx;
    dk_set_t ns = 0;
    DO_BOX (ST *, item, inx, etalon)
      {
	int inx2;
        state_slot_t *ssl;
	if (sqlg_tree_has_aggregate (item))
	  continue;
	DO_BOX (ST *, item2, inx2, subseq)
	  {
	    df_elt_t *col1 = sqlo_df (sc->sc_so, item), *col2 =  sqlo_df (sc->sc_so, item2->_.o_spec.col);
	    if (col1 == col2)
	      break;
	  }
	END_DO_BOX;
	if (inx2 != BOX_ELEMENTS (subseq))
	  continue;
        ssl = scalar_exp_generate (sc, item, &code);
	dk_set_push (&ns, ssl);
      }
    END_DO_BOX;
    return ns;
}


state_slot_t *
setp_copy_if_constant (sql_comp_t * sc, setp_node_t * setp, state_slot_t * ssl)
{
  if (SSL_CONSTANT == ssl->ssl_type)
    {
      state_slot_t * ssl2 = ssl_new_variable (sc->sc_cc, "inc", ssl->ssl_sqt.sqt_dtp);
      dk_set_push (&setp->setp_const_gb_args, (void*)ssl2);
      dk_set_push (&setp->setp_const_gb_values, (void*)ssl);
      return ssl2;
    }
  return ssl;
}


state_slot_t *sqlg_alias_or_assign (sqlo_t * so, state_slot_t * ext, state_slot_t * source, dk_set_t * code, int is_value_subq);


#define fref_is_hash(f) (f->fnr_setp && f->fnr_setp->setp_ha && f->fnr_setp->setp_ha->ha_op == HA_FILL)

dk_set_t
sqlg_continue_list (data_source_t * qn)
{
  /* return list of qn and successors in continue order, i.e. inner loop first */
  dk_set_t res = NULL;
  while (qn)
    {
      dk_set_push (&res, (void*)qn);
      if ((qn_input_fn)fun_ref_node_input == qn->src_input)
	break;
      qn = qn_next (qn);
    }
  return res;
}


int32 enable_qp = 8;
int32 enable_mt_txn = 0;

int
sqlg_may_parallelize (sql_comp_t * sc, data_source_t * qn)
{
  int txf = !enable_mt_txn;
  table_source_t * ts;
  sql_comp_t * select_sc = sc_top_select_sc (sc);
  int old_enl = select_sc->sc_cc->cc_query->qr_need_enlist;
  select_sc->sc_cc->cc_query->qr_need_enlist = 0;
  sqlc_current_sc = sc;
  for (ts = (table_source_t*)qn; ts; ts = (table_source_t*)qn_next ((data_source_t*)ts))
    {
      if (!cv_is_local_1 (ts->src_gen.src_pre_code, txf)
	  || !cv_is_local_1 (ts->src_gen.src_after_test, txf) || !cv_is_local_1 (ts->src_gen.src_after_code, txf))
	goto no;
      if (IS_QN (ts, end_node_input) || qn_is_hash_fill ((data_source_t *) ts) || qn_is_iter ((data_source_t *) ts))
	continue;
      if (IS_QN (ts, subq_node_input) && !qr_is_local (((subq_source_t *) ts)->sqs_query, txf))
	goto no;
      if (IS_TS (ts))
	{
	  if (ts->ts_inx_op || !ts->ts_order_ks)
	    goto no;
	  if (KI_TEMP == ts->ts_order_ks->ks_key->key_id)
	    goto no;
	}
      if (IS_QN (ts, setp_node_input) && ((setp_node_t *)ts)->setp_distinct)
	goto no;
    }
  if (!enable_mt_txn && select_sc->sc_cc->cc_query->qr_need_enlist)
    goto no;
  sqlc_current_sc = NULL;
  return 1;
 no:
  sqlc_current_sc = NULL;
  select_sc->sc_cc->cc_query->qr_need_enlist |= old_enl;
  return 0;
}


float
cv_cost (code_vec_t cv)
{
  /* add cost for function calls after a ts, else some calls for side effect get too little cost and do not get mt.  */
  float cost = 0;
  if (!cv)
    return 0;
  DO_INSTR (ins, 0, cv)
  {
    switch (ins->ins_type)
      {
      case INS_CALL:
	cost += 100;
	break;
      case INS_CALL_BIF:
	cost += 10;
      }
  }
  END_DO_INSTR return cost;
}



float
dfe_cost_before_agg (df_elt_t * dt_dfe, table_source_t * ts, int from_nth_ts)
{
  float p_card = 1, p_cost = 0;
  data_source_t *qn;
  int ts_ctr = 0;
  float cost = 0, card = 1;
  df_elt_t * dfe;
  if (DFE_TABLE == dt_dfe->dfe_type)
    cost = dt_dfe->dfe_unit;
  if (DFE_DT != dt_dfe->dfe_type && DFE_VALUE_SUBQ != dt_dfe->dfe_type)
    cost = 10;
  else
    {
  for (dfe = dt_dfe->_.sub.first; dfe; dfe = dfe->dfe_next)
    {
      if (DFE_TABLE == dfe->dfe_type)
	ts_ctr++;
      if (from_nth_ts >= ts_ctr)
	continue;
      cost += dfe->dfe_unit * card;
      if (dfe->dfe_arity != 0)
	card *= dfe->dfe_arity;
      if (DFE_GROUP == dfe->dfe_type || DFE_ORDER == dfe->dfe_type)
	break;
    }
    }
  for (qn = (data_source_t *) ts; qn; qn = qn_next (qn))
    {
      if (qn != (data_source_t *) ts)
	p_cost += p_card * cv_cost (qn->src_pre_code);
      if (IS_TS (qn))
	p_card *= ((table_source_t *) ts)->ts_cardinality;
      p_cost += p_card * cv_cost (qn->src_after_test);
      p_cost += p_card * cv_cost (qn->src_after_code);
    }
  return cost + p_cost;
}


int
qn_is_iter (data_source_t  * qn)
{
  /* colocatable iter like in, subclass, subproperty, location insensitive and no index access */
  if ((qn_input_fn)in_iter_input == qn->src_input)
    return 1;
  if ((qn_input_fn)rdf_inf_pre_input == qn->src_input)
    return 1;
  return 0;
}


int
qn_is_hash_fill (data_source_t * qn)
{
  if (IS_QN (qn, hash_fill_node_input))
    return 1;
  if (!IS_QN (qn, fun_ref_node_input))
    return 0;
  {
    QNCAST (fun_ref_node_t, fref, qn);
    if (fref->fnr_setp && fref->fnr_setp->setp_ha && HA_FILL == fref->fnr_setp->setp_ha->ha_op)
      return 1;
  }
  return 0;
}


void
sqlg_top_distinct (sql_comp_t * sc, table_source_t * ts)
{
  setp_node_t * distinct = NULL;
  for (ts = ts; ts; ts = (table_source_t*)qn_next ((data_source_t*)ts))
    {
      if (IS_QN (ts, setp_node_input))
	{
	  QNCAST (setp_node_t, setp, ts);
	  if (setp->setp_distinct)
	    distinct = setp;
	  if (setp->setp_sorted && distinct)
	    {
	      setp->setp_top_distinct = 1;
	      distinct->setp_distinct = SETP_DISTINCT_NO_OP;
	    }
	}
    }
}


void
sqlg_parallel_ts_seq (sql_comp_t * sc, df_elt_t * dt_dfe, table_source_t * ts, fun_ref_node_t * fref, select_node_t *sel)
{
  int ts_ctr = 0;
  if (CL_RUN_LOCAL != cl_run_local_only)
    return;
  if (!sqlg_may_parallelize (sc, (data_source_t*)ts))
    return;
  for (ts = ts; ts; ts = (table_source_t*)qn_next ((data_source_t*)ts))
    {
      if (IS_QN (ts, set_ctr_input))
	{
	  QNCAST (set_ctr_node_t, sctr, ts);
	  if (sctr->sctr_ose)
	    {
	      for (ts = ts; ts; ts = (table_source_t*)qn_next ((data_source_t*)ts))
		{
		  if (IS_TS (ts) && !ts->ts_in_index_path)
		    ts_ctr++;
		  if (IS_QN (ts, outer_seq_end_input))
		    break;
		}
	    }
	  continue;
	}
      if (IS_TS (ts))
	{
	  if (ts->ts_in_index_path)
	    ts_ctr--;
	  if (ts->ts_inx_op || !ts->ts_order_ks || KI_TEMP == ts->ts_order_ks->ks_key->key_id)
	    {
	      ts_ctr++;
	      continue;
	    }
	  ts->ts_aq_state = cc_new_instance_slot (sc->sc_cc);
	  if (SC_UPD_PLACE == sc->sc_is_update)
	    ts->ts_no_mt_in_row_ac = 1;
	  ts->ts_aq = ssl_new_variable (sc->sc_cc, "aq", DV_ANY);
	  ts->ts_aq_qis = ssl_new_variable (sc->sc_cc, "branch_qis", DV_ANY);
	  ts->ts_cost_after = dfe_cost_before_agg (dt_dfe, ts, ts_ctr);
	  ts_ctr++;
	  ts->ts_agg_node = fref ? (data_source_t*)fref : (data_source_t *)sel;
	}
    }
}



#define BOXC(b) \
  *((caddr_t*)&b) = box_copy ((caddr_t)b)


#define CVC(c) c = cv_copy (c)
code_vec_t cv_copy (code_vec_t * cv);



hash_area_t * 
ha_copy (hash_area_t * ha)
{
  NEW_VARZ (hash_area_t, ha_copy);
  memcpy (ha_copy, ha, sizeof (hash_area_t));
  BOXC (ha_copy->ha_slots);
  BOXC (ha_copy->ha_key_cols);
  ha_copy->ha_cols = NULL;
  return ha_copy;
}


gb_op_t *
go_copy (gb_op_t * org)
{
  NEW_VARZ (gb_op_t, go);
  *go = *org;
  BOXC (go->go_ua_arglist);
  if (go->go_distinct_ha)
    go->go_distinct_ha = ha_copy (go->go_distinct_ha);
  CVC (go->go_ua_init_setp_call);
  CVC (go->go_ua_acc_setp_call);
  return go;
}


setp_node_t *
setp_copy (sql_comp_t * sc, setp_node_t * org)
{
  dk_set_t iter;
  SQL_NODE_INIT (setp_node_t, setp, setp_node_input, setp_node_free);
  memcpy (setp, org, sizeof (setp_node_t));
  org->setp_in_union = 1;
  CVC (setp->src_gen.src_pre_code);
  setp->setp_ha = ha_copy (setp->setp_ha);
  setp->setp_reserve_ha = setp->setp_ha;
  setp->setp_keys = dk_set_copy (setp->setp_keys);
  setp->setp_dependent = dk_set_copy (setp->setp_dependent);
  setp->setp_key_is_desc = dk_set_copy (setp->setp_key_is_desc);
  setp->setp_const_gb_args = dk_set_copy (setp->setp_const_gb_args);
  setp->setp_const_gb_values = dk_set_copy (setp->setp_const_gb_values);
  BOXC (setp->setp_keys_box);
  BOXC (setp->setp_dependent_box);
  BOXC (setp->setp_merge_temps);
  BOXC (setp->setp_ordered_gb_out);
  BOXC (setp->setp_last_vals);
  setp->setp_gb_ops = dk_set_copy (setp->setp_gb_ops);
  for (iter = setp->setp_gb_ops; iter; iter = iter->next)
    iter->data = (void*)go_copy ((gb_op_t*)iter->data);

  setp->setp_in_union = 1;
  setp->setp_loc_ts = NULL;
  setp->setp_hash_part_spec = NULL;
  setp->setp_insert_spec.ksp_spec_array = sp_list_copy (setp->setp_insert_spec.ksp_spec_array);
  return setp;
}


int
cv_is_copiable (code_vec_t cv)
{
  instruction_t * last = NULL;
  if (!cv)
    return 1;
  DO_INSTR (ins, 0, cv)
    {
      switch (ins->ins_type)
	{
	case INS_SUBQ:
      case IN_PRED:
	return 0;
	}
      last = ins;
    }
  END_DO_INSTR;
  return 1;
}



code_vec_t
cv_copy (code_vec_t * cv)
{
  int len;
  code_vec_t copy;
  if (!cv)
    return NULL;
  copy = (code_vec_t) box_copy ((caddr_t)cv);
  DO_INSTR (ins, 0, copy)
    {
      switch (ins->ins_type)
	{
	case INS_CALL:
	  BOXC (ins->_.call.params);
	  BOXC (ins->_.call.proc);
	  BOXC (ins->_.call.kwds);
	  break;
	case INS_CALL_BIF:
	  BOXC (ins->_.bif.params);
	  BOXC (ins->_.bif.proc);
	  break;
      case IN_AGG:
	if (ins->_.agg.distinct)
	  ins->_.agg.distinct = ha_copy (ins->_.agg.distinct);
	break;
	case INS_QNODE:
	  {
	    int inx;
	    sql_comp_t * sc = top_sc;
	    SQL_NODE_INIT (dpipe_node_t, dp, dpipe_node_input, dpipe_node_free);
	    if (!IS_QN (ins->_.qnode.node, dpipe_node_input))
	      GPF_T1 ("in a union with aggregation inlined in the branches, there may not be other qnode instructions than dpipes");
	    memcpy (dp, ins->_.qnode.node, sizeof (dpipe_node_t));
	    ins->_.qnode.node = (data_source_t*)dp;
	    BOXC (dp->dp_inputs);
	    BOXC (dp->dp_funcs);
	    BOXC (dp->dp_outputs);
	    BOXC (dp->dp_input_args);
	    DO_BOX (caddr_t, ia, inx, dp->dp_input_args)
	      BOXC (dp->dp_input_args[inx]);
	    END_DO_BOX;
	    break;
	  }
	}
    }
  END_DO_INSTR;
  return copy;
}


end_node_t *
en_copy (sql_comp_t * sc, end_node_t * org)
{
  SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
  memcpy (en, org, sizeof (end_node_t));
  CVC (en->src_gen.src_pre_code);
  CVC (en->src_gen.src_after_test);
  CVC (en->src_gen.src_after_code);
  return en;
}


data_source_t * 
qn_copy  (sql_comp_t * sc, data_source_t * qn)
{
  if (IS_QN (qn, setp_node_input))
    return (data_source_t*)setp_copy (sc, (setp_node_t*)qn);
  if (IS_QN (qn, end_node_input))
    return (data_source_t*)en_copy (sc, (end_node_t*)qn);
  return NULL;
}


data_source_t * 
qn_tail_copy (sql_comp_t * sc, data_source_t * qn)
{
  data_source_t * head = qn_copy (sc, qn), *next, * last = NULL;
  last = head;
  while ((next = qn_next (qn)))
    {
      data_source_t * n = qn_copy (sc, next);
      last->src_continuations = dk_set_cons (n, NULL);
      last = n;
      qn = next;
    }
  return head;
}

int
qn_tail_is_copiable (data_source_t * qn)
{
  for (qn = qn; qn; qn = qn_next (qn))
    {
      if (!cv_is_copiable (qn->src_pre_code) || !cv_is_copiable (qn->src_after_code) || !cv_is_copiable (qn->src_after_test))
	return 0;
      if (!IS_QN (qn, end_node_input) && !IS_QN (qn, setp_node_input))
	return 0;
    }
  return 1;
}


int
sqlg_union_all_list (subq_source_t * sqs, dk_set_t * res)
{
  union_node_t * uni = (union_node_t*)sqs->sqs_query->qr_head_node;
  if (!IS_QN (uni, union_node_input))
    return 0;
  if (!uni->uni_cl_colocate_delayed)
    return 0;
  DO_SET (query_t *, qr, &uni->uni_successors)
    {
	t_set_push (res, (void*)qr->qr_head_node);
    }
  END_DO_SET();
  return 1;
}

int
sqlg_is_subq_sel (data_source_t * qn)
{
  return IS_QN (qn, select_node_input_subq) && !((select_node_t *) qn)->sel_subq_inlined;
}


int
sqlg_union_fref (sql_comp_t * sc, fun_ref_node_t * fref, df_elt_t * dt_dfe, dk_set_t * terms_ret)
{
  /* if the body of the fref is a  union subq followed by setp or an aggregate code vec, put the setp or cv in the branches */
  data_source_t * next;
  query_t * save_qr = sc->sc_cc->cc_query;
  subq_source_t * uni_sqs = NULL;
  dk_set_t terms = NULL;
  code_vec_t post = NULL;
  subq_source_t * sqs = (subq_source_t*)fref->fnr_select;
  int first = 1;
  if (!IS_QN (sqs, subq_node_input))
    return 0;
  if (CL_RUN_LOCAL != cl_run_local_only && !enable_cl_fref_union)
    return 0;
  if (IS_QN (sqs->sqs_query->qr_head_node, subq_node_input))
    {
      data_source_t * succ = qn_next (sqs->sqs_query->qr_head_node);
      if (sqs->src_gen.src_after_test || !IS_QN (succ, select_node_input_subq) || succ->src_pre_code)
	return 0;
      uni_sqs = (subq_source_t*)sqs->sqs_query->qr_head_node;
      post = uni_sqs->src_gen.src_after_code;
    }
  else
    {
    uni_sqs = sqs;
      post = sqs->src_gen.src_after_code;
    }
  if (!sqlg_union_all_list (uni_sqs, &terms) || !terms)
    return 0;
  *terms_ret = terms;
  next = qn_next ((data_source_t*)sqs);
  if (next && !qn_tail_is_copiable (next))
    return 0;
  if (!cv_is_copiable  (sqs->src_gen.src_after_code) || !cv_is_copiable (sqs->src_gen.src_pre_code) || !cv_is_copiable (post))
    return 0;
  sc->sc_cc->cc_query = uni_sqs->sqs_query;
  if (post)
    uni_sqs->src_gen.src_after_code = NULL;
  if (!next)
    {
      SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
      en->src_gen.src_continuations = sqs->src_gen.src_continuations;
      sqs->src_gen.src_continuations = dk_set_cons ((void*)en, NULL);
      en->src_gen.src_after_test = sqs->src_gen.src_after_test;
      sqs->src_gen.src_after_test = NULL;
      en->src_gen.src_after_code = sqs->src_gen.src_after_code;
      sqs->src_gen.src_after_code = NULL;
      en->src_gen.src_pre_code = post;
      next = (data_source_t*)en;
    }
  else 
    {
      dk_set_free (sqs->src_gen.src_continuations);
      sqs->src_gen.src_continuations = NULL;
      if (post)
	{
	  SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
	  en->src_gen.src_continuations = dk_set_cons ((void*)next, NULL);
	  if (uni_sqs != sqs && sqs->src_gen.src_after_code)
	    {
	      en->src_gen.src_pre_code = post;
	      en->src_gen.src_after_code = sqs->src_gen.src_after_code;
	      sqs->src_gen.src_after_code = NULL;
	    }
	  else
	  en->src_gen.src_after_code = post;
      next = (data_source_t*)en;
	}
    }
  if (uni_sqs != sqs)
    {
      dk_set_free (uni_sqs->src_gen.src_continuations);
      uni_sqs->src_gen.src_continuations = NULL;
    }
  DO_SET (data_source_t *, qn, &terms)
    {
      data_source_t * first_ts = qn;
      data_source_t * prev = NULL;
    while (qn && !sqlg_is_subq_sel (qn))
	{
	  prev = qn;
	  qn = qn_next (qn);
	}
      if (!qn || !prev)
	sqlc_new_error (sc->sc_cc, "37000", "UNIAG",  "union all aggregate does not end with a select of the subq, internal, support");
      prev->src_continuations->data = qn_tail_copy (sc, next);
      first = 0;
      if (CL_RUN_LOCAL == cl_run_local_only)
	sqlg_parallel_ts_seq (sc, sqlg_qn_dfe ((data_source_t*)first_ts->src_query), (table_source_t*)first_ts, fref, NULL);
    }
  END_DO_SET();
  sc->sc_cc->cc_query = save_qr;
  return 1;
}


void
sqlg_cl_colocate_union (sql_comp_t * sc, fun_ref_node_t * fref, dk_set_t terms)
{
  return;
}


void
sqlg_fref_qp (sql_comp_t * sc, fun_ref_node_t * fref, df_elt_t * dt_dfe)
{
  QNCAST (table_source_t, ts, fref->fnr_select);
  table_source_t * first_ts = ts;
  int fl;
  dk_set_t terms = NULL;
  sqlg_top_distinct (sc, ts);
  if (fref->fnr_setp && !fref->fnr_setps)
    dk_set_push (&fref->fnr_setps, (void*)fref->fnr_setp);
  DO_SET (setp_node_t *, setp, &fref->fnr_setps) if (setp->setp_any_user_aggregate_gos || setp->setp_any_distinct_gos)
      return;
  END_DO_SET();
  
  fl = sqlg_union_fref  (sc, fref, dt_dfe, &terms);
  if (terms)
    sqlg_cl_colocate_union (sc, fref, terms);
  if (fl)
    return;
  if (CL_RUN_LOCAL != cl_run_local_only)
    return;
  if (!enable_qp)
    return;
  for (ts = ts; ts; ts = (table_source_t*)qn_next ((data_source_t*)ts))
    {
      if (IS_QN (ts, end_node_input)
	  || qn_is_hash_fill ((data_source_t*)ts)
	  || qn_is_iter ((data_source_t *) ts) || IS_QN (ts, subq_node_input) || IS_QN (ts, txs_input))
	continue;
      if (IS_TS (ts))
	{
	  if (ts->ts_inx_op || !ts->ts_order_ks)
	    return;
	  if (KI_TEMP == ts->ts_order_ks->ks_key->key_id)
	    return;
	  sqlg_parallel_ts_seq (sc, dt_dfe, first_ts, fref, NULL);
	  return;
	}
      else
	continue;
    }
}


void
sqlg_place_fref (sql_comp_t * sc, data_source_t ** head, fun_ref_node_t * fref, df_elt_t * dt_dfe)
{
  /* A fref goes after all inits and end nodes and dpipes.  If there are hash filler frefs, goes after these. */
  data_source_t * qn, *prev = NULL;
  void * dp;
  if (!fref->fnr_ssa.ssa_set_no)
    {
      fref->fnr_ssa.ssa_set_no = sqlg_set_no_if_needed (sc, head);
    }
  for (qn = *head; qn; (prev = qn, qn = qn_next (qn)))
    {
      if (IS_QN (qn, hash_fill_node_input) || IS_QN (qn, set_ctr_input))
	continue;
      if ((qn_input_fn)fun_ref_node_input == qn->src_input)
	{
	  QNCAST (fun_ref_node_t, fref, qn);
	  if (fref_is_hash (fref))
	    continue;
	  break;
	}
      break;
    }
  if (sc->sc_qn_to_dpipe && (dp = gethash ((void*)qn, sc->sc_qn_to_dpipe)))
    {
      remhash ((void*)qn, sc->sc_qn_to_dpipe);
      sethash ((void*)fref, sc->sc_qn_to_dpipe, dp);
    }
  fref->src_gen.src_pre_code = qn->src_pre_code;
  qn->src_pre_code = NULL;
  fref->fnr_select = qn;
  fref->fnr_select_nodes = sqlg_continue_list (qn);
  sqlg_fref_qp (sc, fref, dt_dfe);
  if (!prev)
    *head = (data_source_t*)fref;
  else
    prev->src_continuations->data = (void*)fref;
  dk_set_delete (&sc->sc_cc->cc_query->qr_nodes, (void*)fref);
  /* if 2 frefs nested like in gb+oby, then the first to continue is the outermost (the oby).  It will continue the inner */
  if ((qn_input_fn)fun_ref_node_input == qn->src_input)
    dk_set_ins_before (&sc->sc_cc->cc_query->qr_nodes, (void*)qn, (void*)fref);
  else
    dk_set_ins_after (&sc->sc_cc->cc_query->qr_nodes, (void*)qn, (void*)fref);
}

void
sqlg_oby_dep_cols (sqlo_t * so, setp_node_t * setp, df_elt_t * oby, int inx, dk_set_t * out_slots, dk_set_t * out_cols,
    ptrlong * nth_part)
{
  /* when an exp is laid out after an oby, the cols on which the exp depends must be added to the oby dep if not in */
  DO_SET (df_elt_t *, col_dfe, &oby->_.setp.oby_dep_cols[inx])
    {
      dk_set_t dummy = NULL;
      state_slot_t * ssl = scalar_exp_generate (so->so_sc, col_dfe->dfe_tree, &dummy);
      ptrlong nth_key = dk_set_position (setp->setp_keys, (caddr_t) ssl);
      if (-1 == nth_key)
	{
	  if (!dk_set_member (*out_slots, ssl))
	    {
	      NCONCF1 (*out_cols, *nth_part);
	      NCONCF1 (*out_slots, ssl);
	      NCONCF1 (setp->setp_dependent, ssl);
	      (*nth_part)++;
	    }
	}
      else
	{
	  if (!dk_set_member (*out_slots, ssl))
	    {
	      NCONCF1 (*out_cols, (nth_key));
	      NCONCF1 (*out_slots, ssl);
	    }
	}
    }
  END_DO_SET();
}


void
setp_set_part_opt (setp_node_t * setp, df_elt_t * tb_dfe)
{
  df_elt_t * super = tb_dfe->dfe_super;
  if (super && DFE_DT == super->dfe_type)
    {
      int part = NULL != sqlo_opt_value (super->_.sub.ot->ot_opts, OPT_PART_GBY);
      int no_part = NULL != sqlo_opt_value (super->_.sub.ot->ot_opts, OPT_NO_PART_GBY);
      if (part)
	setp->setp_part_opt = 1;
      if (no_part)
	setp->setp_part_opt = 2;
    }
}


void
sqlg_make_sort_nodes (sqlo_t * so, data_source_t ** head, ST ** order_by,
    state_slot_t ** ssl_out, df_elt_t * tb_dfe, int is_gb, dk_set_t o_code, df_elt_t *oby, ST ** selection)
{
  data_source_t * read_node;
  ST * dt = dfe_ot (tb_dfe)->ot_dt;
  sql_comp_t * sc = so->so_sc;
  dk_set_t out_cols = NULL;
  dk_set_t out_slots = NULL;
  int inx;
  ptrlong nth_part = 0;
  dk_set_t pre = NULL, out1 = NULL;
  int term_found;
  gs_union_node_t * setps = 0, * readers = 0;
  dk_set_t setps_set = 0;
  end_node_t * e_last = 0;
  ST *** group_by = (ST ***) (is_gb ? order_by : 0);
  dk_set_t always_null = 0;
  int ginx = 0;
  dk_set_t code = o_code;
  dk_set_t reader_code = 0;
  int first = 1;
  int is_grouping_sets = (is_gb && (BOX_ELEMENTS(group_by)>1));
  ST * gs_top = 0;
  NEW_VARZ (fun_ref_node_t, fref_node);
  sc->sc_fref = fref_node;
  SQL_NODE_INIT_NO_ALLOC (fun_ref_node_t, fref_node, fun_ref_node_input, fun_ref_free);

  if (is_grouping_sets)
    {
      e_last = (end_node_t *) dk_alloc (sizeof (end_node_t));
      memset (e_last, 0, sizeof (end_node_t));
      SQL_NODE_INIT_NO_ALLOC (end_node_t, e_last, end_node_input, NULL);
      setps = (gs_union_node_t *) dk_alloc (sizeof (gs_union_node_t));
      readers = (gs_union_node_t *) dk_alloc (sizeof (gs_union_node_t));
      memset (setps, 0, sizeof (gs_union_node_t));
      memset (readers, 0, sizeof (gs_union_node_t));
      SQL_NODE_INIT_NO_ALLOC (gs_union_node_t, setps, gs_union_node_input, gs_union_free);
      SQL_NODE_INIT_NO_ALLOC (gs_union_node_t, readers, gs_union_node_input, gs_union_free);
      setps->gsu_nth = ssl_new_inst_variable (sc->sc_cc, "nth", DV_LONG_INT);
      readers->gsu_nth = ssl_new_inst_variable (sc->sc_cc, "nth", DV_LONG_INT);
      sql_node_append ((data_source_t**) &readers, (data_source_t*) e_last);
      sql_node_append (head, (data_source_t*) setps);
      sql_node_append ((data_source_t**) &fref_node, (data_source_t*) readers);
      if (!so->so_sc->sc_grouping)
        {
	  so->so_sc->sc_grouping = ssl_new_inst_variable (so->so_sc->sc_cc, "grouping", DV_LONG_INT);
	  so->so_sc->sc_groupby_set = group_by[0];
	}
    }

  for (;;)
  {
  if (group_by)
    {
	  ST * first_ospec = NULL;
      order_by = group_by[ginx++];
	  if (BOX_ELEMENTS (order_by) > 0)
	    first_ospec = order_by[0];
	  if (first_ospec && first_ospec->_.o_spec.gsopt)
	    {
	      is_gb = 0;
	      gs_top = (first_ospec->_.o_spec.gsopt != (ST *)1 ? first_ospec->_.o_spec.gsopt : NULL);
	    }
	  else
	    {
	      is_gb = 1;
	      gs_top = NULL;
	    }
      if (first)
        {
	  code = o_code;
	  first = 0;
	}
      else
        {
	  code = 0;
	}
    }
  {
  SQL_NODE_INIT (setp_node_t, setp, setp_node_input, setp_node_free);
  setp->setp_fref = fref_node;
  setp->setp_ssa.ssa_set_no = sqlg_set_no_if_needed (sc, head);
  nth_part = 0;
	  if (is_grouping_sets)
    {
      if (so->so_sc->sc_grouping)
        {
	  caddr_t one, bitmap_index_box;
	  state_slot_t *bitmap, *bitmap_index;
	  ptrlong bm = 0;

	  make_grouping_bitmap_set (order_by, 0, group_by[0], &bm);
	  one = box_num (bm);

	  bitmap_index_box = box_num (so->so_sc->sc_grouping->ssl_index);
	  bitmap = ssl_new_constant (so->so_sc->sc_cc, one);
		  bitmap_index = ssl_new_constant (so->so_sc->sc_cc, bitmap_index_box);
	  reader_code = 0;
	  dk_free_box (one);
	  dk_free_box (bitmap_index_box);
	  cv_call (&reader_code, NULL, "__GROUPING_SET_BITMAP", NULL,
	      (state_slot_t**) /*list*/ sc_list (2, bitmap_index, bitmap));
	}
	      if (is_gb)
		always_null = always_null_arr_gen (sc, code, selection, order_by);
	      else
		always_null = always_null_agg_arr_gen (sc, code, selection);
    }


  /* memset (fref_node, 0, sizeof (fun_ref_node_t)); */
  DO_BOX (ST *, spec, inx, order_by)
    {
      state_slot_t *ssl;
      ssl = scalar_exp_generate (sc, spec->_.o_spec.col, &code);
      NCONCF1 (setp->setp_keys, ssl);
      NCONCF1 (setp->setp_key_is_desc, spec->_.o_spec.order);
      if (is_gb)
	{
	  df_elt_t *col_dfe = sqlo_df (so, spec->_.o_spec.col);
	  if (ssl == col_dfe->dfe_ssl)
	    {
		      sqlc_copy_ssl_if_constant (sc, &ssl, &code, setp);
	      col_dfe->dfe_ssl = ssl;
	    }
	  else
		    sqlc_copy_ssl_if_constant (sc, &ssl, &code, setp);
	  NCONCF1 (out_slots, ssl);
	  NCONCF1 (out_cols, nth_part);
	}
      nth_part++;
    }
  END_DO_BOX;

  if (is_gb)
    {
      DO_SET (ST *, fref, &tb_dfe->_.table.ot->ot_fun_refs)
	{
	  state_slot_t * aggregate;
	  gb_op_t *go;
	  state_slot_t * arg = NULL;
	  state_slot_t ** ua_arglist = NULL;
	  state_slot_t ** acc_args = NULL;
	  user_aggregate_t *ua = (user_aggregate_t *)(unbox_ptrlong (fref->_.fn_ref.user_aggr_addr));
          int arglist_len = 0;
	  if (AMMSC_USER != fref->_.fn_ref.fn_code)
	    arg = scalar_exp_generate (sc, fref->_.fn_ref.fn_arg, &code);
	  else
	    {
	      int argidx;
	      arglist_len = BOX_ELEMENTS(fref->_.fn_ref.fn_arglist);
	      ua_arglist = (state_slot_t **) dk_alloc_box_zero (sizeof (state_slot_t *) * arglist_len, DV_ARRAY_OF_POINTER);
	      acc_args = (state_slot_t **) dk_alloc_box_zero (sizeof (state_slot_t *) * (1 + arglist_len), DV_ARRAY_OF_POINTER);
	      DO_BOX_FAST (ST *, arg_st, argidx, fref->_.fn_ref.fn_arglist)
		{
		  state_slot_t *arg_sst = scalar_exp_generate (sc, arg_st, &code);
		  ua_arglist [argidx] = arg_sst;
		  acc_args [argidx+1] = arg_sst;
		}
	      END_DO_BOX_FAST;
	    }
	  aggregate = sqlg_dfe_ssl (so, sqlo_df (so, fref));
		  if (AMMSC_USER != fref->_.fn_ref.fn_code)
	  sqlg_find_aggregate_sqt (sc->sc_cc->cc_schema, &(arg->ssl_sqt), fref, &(aggregate->ssl_sqt));
		  else
		    aggregate->ssl_sqt.sqt_dtp = DV_ARRAY_OF_POINTER;
	  if (!dk_set_member (out_slots, aggregate))
	    {
	      go = (gb_op_t *) dk_alloc (sizeof (gb_op_t));
	      memset (go, 0, sizeof (gb_op_t));
	      go->go_op = (int) fref->_.fn_ref.fn_code;
	      go->go_old_val = ssl_new_variable (sc->sc_cc, "gb_tmp", aggregate->ssl_sqt.sqt_dtp);
	      go->go_old_val->ssl_qr_global = 1; /* not to be vectored, one value at a time */
	      go->go_old_val->ssl_sqt = aggregate->ssl_sqt;
	      switch (go->go_op)
		{
		  case AMMSC_AVG:
		    GPF_T1("AVG() is not reduced to SUM()/COUNT()?");
		    break;
		  case AMMSC_USER:
		    {
		      dk_set_t code = NULL;
		      state_slot_t *ret = ssl_new_inst_variable (sc->sc_cc, "ua_ret", DV_UNKNOWN);
		      go->go_user_aggr = ua;
				  go->go_old_val->ssl_sqt.sqt_dtp = DV_ARRAY_OF_POINTER;
				  ret->ssl_sqt.sqt_dtp = DV_ARRAY_OF_POINTER;
		      go->go_ua_arglist_len = arglist_len;
		      go->go_ua_arglist = ua_arglist;
		      arg = go->go_old_val;
		      acc_args[0] = go->go_old_val;
			cv_call (&code, NULL, t_box_copy (ua->ua_init.uaf_name), ret, (state_slot_t **) /*list */ sc_list (1,
				go->go_old_val));
		      go->go_ua_init_setp_call = code_to_cv (so->so_sc, code);
		      code = NULL;
		      cv_call (&code, NULL, t_box_copy (ua->ua_acc.uaf_name), ret, acc_args);
		      go->go_ua_acc_setp_call = code_to_cv (so->so_sc, code);
		      break;
		    }
		case AMMSC_COUNT:
		  aggregate->ssl_sqt.sqt_non_null = 1;
                    break; /* Orri's patch for cast problem with count(distinct string-expn) ... group by other-expn  */
		case AMMSC_COUNTSUM:
		  aggregate->ssl_sqt.sqt_non_null = 1;
		  /* no break, continue with default */
		  default:
		    arg->ssl_sqt = aggregate->ssl_sqt;
		}
	      if (fref->_.fn_ref.all_distinct)
		{
		  go->go_distinct = arg;	/* It's not AMMSC_USER because 1 == fn_ref.all_distinct */
		      go->go_distinct_ha =
			  sqlg_distinct_fun_ref_col (sc, arg, setp->setp_keys, (long) tb_dfe->dfe_arity, setp->setp_ssa.ssa_set_no);
		  setp->setp_any_distinct_gos = 1;
		  dk_set_push (&fref_node->fnr_distinct_ha, (caddr_t) go->go_distinct_ha);
		  if (go->go_op == AMMSC_COUNT)
		    arg = ssl_new_constant (sc->sc_cc, box_num (1));
		}
	      arg = setp_copy_if_constant (sc, setp, arg);
	      NCONCF1 (out_cols, nth_part);
	      NCONCF1 (out_slots, aggregate);
	      NCONCF1 (setp->setp_dependent, arg);
	      NCONCF1 (setp->setp_gb_ops, go);
	      nth_part++;
	      if (AMMSC_USER == go->go_op)
		setp->setp_any_user_aggregate_gos = 1;
	    }
	}
      END_DO_SET();
    }
  else
    {
      /* add out cols not used in sort key as dependent part of temp row */
      DO_BOX (state_slot_t *, out, inx, ssl_out)
	{
	  if (out)
	    {
	      ptrlong nth_key = dk_set_position (setp->setp_keys, (caddr_t) out);
		      sqlc_copy_ssl_if_constant (sc, &ssl_out[inx], &code, setp);
	      if (-1 == nth_key)
		{
		  if (!dk_set_member (out_slots, ssl_out[inx]))
		    {
		      NCONCF1 (out_cols, nth_part);
		      NCONCF1 (out_slots, ssl_out[inx]);
			      NCONCF1 (setp->setp_dependent, ssl_out[inx]);
		      nth_part++;
		    }
		}
	      else
		{
		  if (!dk_set_member (out_slots, ssl_out[inx]))
		    {
		      NCONCF1 (out_cols, (nth_key));
		      NCONCF1 (out_slots, ssl_out[inx]);
		    }
		}
	    }
	  else if (oby->_.setp.oby_dep_cols && oby->_.setp.oby_dep_cols[inx])
	    sqlg_oby_dep_cols (so, setp, oby, inx, &out_slots, &out_cols, &nth_part);
	}
      END_DO_BOX;
    }
  /* do add all the same level temps set before the group by & used after the group by to the setp_dependent */
  term_found = 0;
  dfe_list_gb_dependant (so, oby->dfe_super->_.sub.first, oby, oby->dfe_super, &pre, NULL, &term_found);
  term_found = 0;
  dfe_list_gb_dependant (so, oby->dfe_next, NULL, oby->dfe_super, &pre, &out1, &term_found);
  if (dt)
    { /* for all the columns in the select list that will be placed at the end */
      DO_BOX (ST *, exp, inx, dt->_.select_stmt.selection)
	{
	  df_elt_t *exp_dfe;
	  exp = sqlc_strip_as (exp);
	  term_found = 0;
	  exp_dfe = sqlo_df_elt (so, exp);
	  if (exp_dfe && tb_dfe->_.sub.dt_out && tb_dfe->_.sub.dt_out[inx])
	    dfe_list_gb_dependant (so, exp_dfe, NULL, oby->dfe_super, &pre, &out1, &term_found);
	}
      END_DO_BOX;
    }
	  out1 = dk_set_conc (out1, t_set_copy (oby->_.setp.gb_dependent));
  DO_SET (df_elt_t *, dep_dfe, &out1)
    {
      state_slot_t *out = dep_dfe->dfe_ssl;
      if (out)
	{
	  ptrlong nth_key = dk_set_position (setp->setp_keys, (caddr_t) out);
		  sqlc_copy_ssl_if_constant (sc, &dep_dfe->dfe_ssl, &code, setp);
	  if (SSL_CONSTANT == out->ssl_type)
	    continue;
	  if (-1 == nth_key)
	    {

	      if (!dk_set_member (out_slots, out))
		{
		  NCONCF1 (out_cols, nth_part);
		  NCONCF1 (out_slots, dep_dfe->dfe_ssl);
		  NCONCF1 (setp->setp_dependent, out);
		  nth_part++;
		}
	    }
	  else
	    {
	      if (!dk_set_member (out_slots, out))
		{
		  NCONCF1 (out_cols, (nth_key));
		  NCONCF1 (out_slots, dep_dfe->dfe_ssl);
		}
	    }
	}
    }
  END_DO_SET();

  sc->sc_sort_insert_node = setp;
	  sqlg_setp_keys (so, setp, (is_gb && !setp->setp_gb_ops) ? 1 : 0, (long) tb_dfe->dfe_arity);
  read_node = sqlc_make_sort_out_node (sc, out_cols, out_slots, always_null, is_gb);
  dk_set_free (out_cols);
#if 1
  out_cols = 0;
  /* setp->src_gen.src_pre_code = code_to_cv (sc, code); */
#endif
	  if (!is_gb && (gs_top || (SEL_TOP (dt) && !dfe_ot(tb_dfe)->ot_oby_dfe->dfe_next)))
    {
	      ST * top = gs_top ? gs_top : SEL_TOP (dt);
      setp->setp_top = scalar_exp_generate (sc, top->_.top.exp, &code);
      if (top->_.top.skip_exp)
	{
	  setp->setp_top_skip = scalar_exp_generate (sc, top->_.top.skip_exp, &code);
	}
      else
	setp->setp_top_skip = NULL;
      ((table_source_t*)read_node)->ts_order_ks->ks_pos_in_temp = cc_new_instance_slot (sc->sc_cc);
      ((table_source_t*)read_node)->ts_order_ks->ks_set_no = sc->sc_set_no_ssl;
      read_node->src_input = (qn_input_fn) sort_read_input;
	      setp->setp_row_ctr = sqlc_new_temp (sc, "rowctr", DV_LONG_INT);
#if 0 /* with ties is not supported */
      setp->setp_last_vals = (state_slot_t **) dk_set_to_array (setp->setp_keys);
      _DO_BOX (inx, setp->setp_last_vals)
	{
	  setp->setp_last_vals[inx] = sqlc_new_temp (sc, "top_last", DV_UNKNOWN);
	}
      END_DO_BOX;
#endif
      setp->setp_last = ssl_new_itc (sc->sc_cc);
      setp->setp_ties = (int) top->_.top.ties;
      if (!top->_.top.ties)
	{
	  s_node_t *iter;
	  setp->setp_sorted = sqlc_new_temp (sc, "sorted", DV_ARRAY_OF_POINTER);
	  DO_SET_WRITABLE (state_slot_t *, setp_ssl, iter, &setp->setp_keys)
	    {
	      if (SSL_CONSTANT == setp_ssl->ssl_type)
		{
		  setp_ssl = ssl_new_variable (sc->sc_cc, "__sort_data", DV_UNKNOWN);
		  sqlg_alias_or_assign (so, setp_ssl, ((state_slot_t *)(iter->data)), &code, 0);
		  iter->data = setp_ssl;
		}
	    }
	  END_DO_SET ();
	  DO_SET_WRITABLE (state_slot_t *, setp_ssl, iter, &setp->setp_dependent)
	    {
	      if (SSL_CONSTANT == setp_ssl->ssl_type)
		{
		  setp_ssl = ssl_new_variable (sc->sc_cc, "__sort_data", DV_UNKNOWN);
		  sqlg_alias_or_assign (so, setp_ssl, ((state_slot_t *)(iter->data)), &code, 0);
		  iter->data = setp_ssl;
		}
	    }
	  END_DO_SET ();
	}
      if (SEL_IS_DISTINCT (dt))
	{
		sqlc_add_distinct_node (sc, head, (state_slot_t **) t_list_to_array (out_slots), (long) tb_dfe->dfe_arity, &code,
		    NULL);
	}
	    /*dt->_.select_stmt.top = NULL; */
    }
	  if (!is_grouping_sets || !setps->gsu_cont)
    {
	      sqlg_pre_code_dpipe (so, &code, NULL);
  setp->src_gen.src_pre_code = code_to_cv (sc, code);
    }
  setp->setp_flushing_mem_sort = ssl_new_variable (sc->sc_cc, "flush", DV_LONG_INT);
  setp->setp_keys_box = (state_slot_t **) dk_set_to_array (setp->setp_keys);
  setp->setp_dependent_box = (state_slot_t **) dk_set_to_array (setp->setp_dependent);
	  if (is_grouping_sets)
    {
      if (!setps->gsu_cont)
	{
	  setps->src_gen.src_pre_code = setp->src_gen.src_pre_code;
	}
      setp->src_gen.src_pre_code = NULL;
      dk_set_push(&setps->gsu_cont, setp);
      dk_set_push(&setps_set, setp);
      dk_set_push(&readers->gsu_cont, read_node);
      sql_node_append ( &read_node, (data_source_t*) e_last);
	      sqlg_pre_code_dpipe (so, &reader_code, NULL);
      read_node->src_pre_code = code_to_cv (sc, reader_code);
    }
  else
    {
	      setp_set_part_opt (setp, tb_dfe);
      sqlg_setp_append (so, head, setp);
      fref_node->fnr_setp = setp;
      sql_node_append ((data_source_t**) &fref_node, read_node);
    }
  if (!group_by || ginx == BOX_ELEMENTS (group_by))
    {
      break;
    }
  out_slots = 0;
  } /* */
  } /* end of for (;;) */
  /* more beauty output */
  if (is_grouping_sets)
    readers->gsu_cont = dk_set_nreverse (readers->gsu_cont);
  fref_node->fnr_setps = setps_set;
  sqlg_place_fref (sc, head, fref_node, tb_dfe);
}


caddr_t
bif_grouping (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong curr_bitmap = bif_long_arg (qst, args, 1, GROUPING_FUNC);
  ptrlong et_bitmap_idx = bif_long_arg (qst, args, 2, GROUPING_FUNC);

  if (!et_bitmap_idx)
    return box_num (0);

  return box_num (!(QST_INT(qst,et_bitmap_idx) & curr_bitmap));
}


caddr_t
bif_grouping_set_bitmap (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
    ptrlong bitmap_idx = bif_long_arg (qst, args, 0, GROUPING_SET_FUNC);
    ptrlong curr_bitmap = bif_long_arg (qst, args, 1, GROUPING_SET_FUNC);
    if (!IS_POINTER (QST_INT (qst, bitmap_idx)))
      QST_INT (qst, bitmap_idx) = curr_bitmap;
    return 0;
}

static int
st_compare (const void *_st1, const void *_st2)
{
  ST * st1 = (*((ST**) _st1))->_.o_spec.col;
  ST * st2 = (*((ST**) _st2))->_.o_spec.col;

  if (!st1->_.col_ref.prefix)
    {
      if (!st2->_.col_ref.prefix)
        {
	  return strcmp (st1->_.col_ref.name, st2->_.col_ref.name);
	}
      else
        return 1;
    }
  else
    {
      if (st2->_.col_ref.prefix)
        {
	  int cmp = strcmp (st1->_.col_ref.prefix, st2->_.col_ref.prefix);
	  if (!cmp)
	    return strcmp (st1->_.col_ref.name, st2->_.col_ref.name);
	  return cmp;
	}
      else
        return -1;
    }
}

static void
st_sort (ST ** arr)
{
  qsort ((void*) arr, BOX_ELEMENTS (arr), sizeof (ST*), st_compare);
}

/* if col is NULL sel_cols are ignored */
static int
make_grouping_bitmap_set (ST ** sel_cols, ST * col, ST **etalon, ptrlong * bitmap)
{
  ST ** sorted_etalon;
  int inx;

  if (BOX_ELEMENTS (etalon) > MAX_GROUPBY_ELS)
    return -1;

  sorted_etalon = (ST **) dk_alloc_box (box_length (etalon), DV_ARRAY_OF_POINTER);
  memcpy (sorted_etalon, etalon, box_length (etalon));

  st_sort (sorted_etalon);

  if (col)
    {
      if (!ST_COLUMN (col, COL_DOTTED))
        GPF_T;
      DO_BOX (ST *, st, inx, sorted_etalon)
        {
	  ST * c = st->_.o_spec.col;
	  if ( (c->_.col_ref.prefix && !col->_.col_ref.prefix) ||
	    (!c->_.col_ref.prefix && col->_.col_ref.prefix) || strcmp (c->_.col_ref.prefix, col->_.col_ref.prefix))
	    continue;
	  if (!strcmp (c->_.col_ref.name, col->_.col_ref.name))
	    {
	      *bitmap |= 1 << inx;
	      break;
	    }
	}
      END_DO_BOX;
      dk_free_box ((box_t) sorted_etalon);
      return 0;
    }

  /* since groupby arrays are always small,
  this algo is used. */
  DO_BOX (ST*, st, inx, sel_cols)
    {
      int inx2;
      DO_BOX (ST*, st2, inx2, sorted_etalon)
        {
	  if (st == st2)
	    break;
	}
      END_DO_BOX;
      *bitmap |= 1 << inx2;
    }
  END_DO_BOX;

  dk_free_box ((box_t) sorted_etalon);
  return 0;
}


void
sqlg_simple_fun_ref (sqlo_t * so, data_source_t ** head, df_elt_t * tb_dfe, dk_set_t cum_code)
{
  dpipe_node_t * dp = NULL;
  dk_set_t post_fref_code = NULL;

  sql_comp_t * sc = so->so_sc;
  op_table_t * ot = tb_dfe->_.sub.ot;

  sc->sc_fun_ref_temps = NULL;
  sc->sc_fun_ref_defaults = NULL;
  sc->sc_fun_ref_default_ssls = NULL;

  {
    data_source_t * last = sql_node_last (*head);
    SQL_NODE_INIT (fun_ref_node_t, fref, fun_ref_node_input, fun_ref_free);
    sc->sc_fref = fref;
    DO_SET (ST *, fref, &ot->ot_fun_refs)
      {
	int ign;
	state_slot_t * ssl = select_ref_generate (sc, fref, &post_fref_code, &cum_code, &ign);
	df_elt_t * fref_dfe = sqlo_df (so, fref);
	fref_dfe->dfe_ssl = ssl;
      }
    END_DO_SET();
    dp = sqlg_pre_code_dpipe (so, &cum_code, NULL);
    if (dp)
      {
	last->src_continuations = dk_set_cons ((void*)dp, NULL);
	dp->src_gen.src_after_code = code_to_cv (so->so_sc, cum_code);
	dk_set_delete (&last->src_query->qr_nodes, (void*)dp);
	dk_set_ins_before (&last->src_query->qr_nodes, (void*)last, (void*)dp);
      }
    else
      {
	last->src_after_code = code_to_cv (so->so_sc, cum_code);
      }
    fref->src_gen.src_after_code = code_to_cv (sc, post_fref_code);
    fref->fnr_default_values = dk_set_nreverse (sc->sc_fun_ref_defaults);
    fref->fnr_default_ssls = dk_set_nreverse (sc->sc_fun_ref_default_ssls);
    fref->fnr_temp_slots = sc->sc_fun_ref_temps;
    sqlg_place_fref (sc, head, fref, tb_dfe);
  }
}


data_source_t *
sqlg_oby_node (sqlo_t * so, data_source_t ** head, df_elt_t * oby, df_elt_t * dt_dfe, dk_set_t pre_code)
{
  sql_comp_t * sc = so->so_sc;
  ST * tree = dt_dfe->dfe_tree;
  state_slot_t ** ssl_out = (state_slot_t **) t_box_copy ((caddr_t) tree->_.select_stmt.selection);
  int inx;
  memset (ssl_out, 0, box_length ((caddr_t)ssl_out));
  DO_BOX (ST *, exp, inx, tree->_.select_stmt.selection)
    {
      if (dt_dfe->_.sub.dt_out && dt_dfe->_.sub.dt_out[inx])
	{
	  if (oby->_.setp.oby_dep_cols && oby->_.setp.oby_dep_cols[inx])
	    ;
	  else
	    ssl_out[inx] = scalar_exp_generate (sc, exp, &pre_code);
	}
      else
	ssl_out[inx] = NULL;
    }
  END_DO_BOX;
  sqlg_make_sort_nodes (so, head, tree->_.select_stmt.table_exp->_.table_exp.order_by, ssl_out, dt_dfe, 0, pre_code, oby, NULL);
  sqlg_cl_multistate_group (sc);
  return sql_node_last (*head);
}


data_source_t *
sqlg_middle_distinct (sqlo_t * so, data_source_t ** head, df_elt_t * group, df_elt_t * dt_dfe, dk_set_t pre_code)
{
  /* put a distinct node in the middle, as in before oby or before id to iri exps with rdf */
  sql_comp_t * sc = so->so_sc;
  ST * tree = dt_dfe->_.sub.ot->ot_dt;
  ST * top = tree->_.select_stmt.top;
  data_source_t * last_qn = *head, *l;
  dpipe_node_t * dpipe;
  setp_node_t * dn;
  state_slot_t ** dist = (state_slot_t**)t_box_copy ((caddr_t)group->_.setp.specs);
  int inx;
  if (IS_BOX_POINTER (top))
    top->_.top.all_distinct = 0;
  else
    tree->_.select_stmt.top = NULL;
  while ((l = qn_next (last_qn)))
    last_qn = l;
  DO_BOX (ST *, exp, inx, group->_.setp.specs)
    {
      dist[inx] = scalar_exp_generate (so->so_sc, exp, &pre_code);
    }
  END_DO_BOX;
  dpipe = sqlg_pre_code_dpipe (so, &pre_code, NULL);
  if (!dpipe && last_qn && !last_qn->src_after_code)
    last_qn->src_after_code = code_to_cv (sc, pre_code);
  else
    {
      SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
      en->src_gen.src_pre_code = code_to_cv (sc, pre_code);
      if (dpipe)
	sql_node_append (head, (data_source_t*) dpipe);
      sql_node_append (head, (data_source_t*) en);
    }
  dn = sqlc_add_distinct_node (so->so_sc, head, dist, dt_dfe->dfe_arity, NULL, NULL);
  return (data_source_t *)dn;
}

int
sqlo_exp_in_gby (ST * exp, ST ** specs)
{
  int inx;
  DO_BOX (ST *, spec, inx, specs)
    {
      if (box_equal ((caddr_t)exp, (caddr_t)spec->_.o_spec.col))
	return 1;
    }
  END_DO_BOX;
  return 0;
}

data_source_t *
sqlg_group_node (sqlo_t * so, data_source_t ** head, df_elt_t * group, df_elt_t * dt_dfe, dk_set_t pre_code)
{
  sql_comp_t * sc = so->so_sc;
  data_source_t * read_node;
  op_table_t * ot = dt_dfe->_.sub.ot;
  ST * tree = dt_dfe->_.sub.ot->ot_dt;
  ST * texp = tree->_.select_stmt.table_exp;
  sqlg_set_no_if_needed (so->so_sc, head);
  switch (group->_.setp.is_distinct)
    {
    case DFE_S_DISTINCT:
      if (sqlg_distinct_same_as (so, head, group->_.setp.specs, dt_dfe, pre_code))
	pre_code = NULL;
      return sqlg_middle_distinct (so, head, group, dt_dfe, pre_code);
    case DFE_S_SAS_DISTINCT:
      return sqlg_distinct_same_as (so, head, group->_.setp.specs, dt_dfe, pre_code);
    }
  if (ot->ot_fun_refs && ! texp->_.table_exp.group_by)
    sqlg_simple_fun_ref (so, head, dt_dfe, pre_code);
  else
    {
      state_slot_t ** ssl_out = (state_slot_t **) t_box_copy ((caddr_t) tree->_.select_stmt.selection);
      int inx;
      memset (ssl_out, 0, box_length ((caddr_t)ssl_out));
      DO_BOX (ST *, exp, inx, tree->_.select_stmt.selection)
	{
	  if (dt_dfe->_.sub.dt_out && dt_dfe->_.sub.dt_out[inx] && !sqlg_tree_has_aggregate (exp)
	      && sqlo_exp_in_gby (exp, group->_.setp.specs))
	    ssl_out[inx] = scalar_exp_generate (sc, exp, &pre_code);
	  else
	    ssl_out[inx] = NULL;
	}
      END_DO_BOX;
      if (sqlg_distinct_same_as (so, head, group->_.setp.specs,  dt_dfe, pre_code))
	pre_code = NULL;
      sqlg_make_sort_nodes (so, head, (ST**) tree->_.select_stmt.table_exp->_.table_exp.group_by_full,
			    ssl_out,  dt_dfe, 1, pre_code, group, (ST **)tree->_.select_stmt.selection);
      so->so_sc->sc_sort_insert_node->setp_card = group->_.setp.gb_card;
      sqlg_cl_multistate_group (so->so_sc);
    }
  read_node = sql_node_last (*head);
  read_node->src_after_test = sqlg_pred_body (so, group->_.setp.after_test);
  return read_node;
}


int
sqlg_dtp_coerce (sql_type_t *res_sqt, sql_type_t *arg_sqt)
{
  char non_null;
  dtp_t res_dtp = res_sqt->sqt_dtp, arg_dtp = arg_sqt->sqt_dtp;
  if (arg_sqt->sqt_dtp == DV_UNKNOWN)
    return 0;
  if (res_sqt->sqt_dtp == DV_UNKNOWN)
    {
      memcpy (res_sqt, arg_sqt, sizeof (sql_type_t));
      return 1;
    }
  non_null = res_sqt->sqt_non_null & arg_sqt->sqt_non_null;
  if (dtp_canonical[res_dtp] == dtp_canonical[arg_dtp])
    {
      res_sqt->sqt_dtp = MAX (res_dtp, arg_dtp);
      res_sqt->sqt_non_null = non_null;
      switch (dtp_canonical[arg_dtp])
	{
	  case DV_STRING:
	  case DV_BIN:
	  case DV_LONG_WIDE:
	     res_sqt->sqt_precision = arg_sqt->sqt_precision && res_sqt->sqt_precision ? 
		 MAX (res_sqt->sqt_precision, arg_sqt->sqt_precision) : 0;
	     break;
	  case DV_LONG_INT:
	  case DV_SINGLE_FLOAT:
	  case DV_DOUBLE_FLOAT:
	     break;
	  case DV_NUMERIC:
	     res_sqt->sqt_precision = MAX (res_sqt->sqt_precision, arg_sqt->sqt_precision);
	     res_sqt->sqt_scale = MAX (res_sqt->sqt_scale, arg_sqt->sqt_scale);
	     break;
	  case DV_OBJECT:
	     if (res_sqt->sqt_class == arg_sqt->sqt_class)
	       return 0;
	     goto any;
	}
      return 1;
    }
  else if (IS_NUM_DTP (res_dtp) && IS_NUM_DTP (arg_dtp))
    {
      res_sqt->sqt_dtp = MAX (res_dtp, arg_dtp);
      res_sqt->sqt_col_dtp = res_sqt->sqt_dtp;
      res_sqt->sqt_non_null = non_null;
      res_sqt->sqt_precision = MAX (res_sqt->sqt_precision, arg_sqt->sqt_precision);
      res_sqt->sqt_scale = MAX (res_sqt->sqt_scale, arg_sqt->sqt_scale);
      return 1;
    }
  else
    {
any:
      memset (res_sqt, 0, sizeof (sql_type_t));
      res_sqt->sqt_dtp = DV_ANY;
      res_sqt->sqt_non_null = non_null;
      return 1;
    }
#if 0
  switch (res_sqt->sqt_dtp)
    {
      case DV_SHORT_INT:
	    {
	      switch (arg_sqt->sqt_dtp)
		{
		  case DV_SHORT_INT:
		      return 0;
		  case DV_LONG_INT:
		      memset (res_sqt, 0, sizeof (sql_type_t));
		      res_sqt->sqt_dtp = DV_LONG_INT;
		      return 0;
		  case DV_SINGLE_FLOAT:
		      memset (res_sqt, 0, sizeof (sql_type_t));
		      res_sqt->sqt_dtp = DV_SINGLE_FLOAT;
		      return 1;
		  case DV_DOUBLE_FLOAT:
		      memset (res_sqt, 0, sizeof (sql_type_t));
		      res_sqt->sqt_dtp = DV_DOUBLE_FLOAT;
		      return 1;
		  case DV_NUMERIC:
	    if (arg_sqt->sqt_scale || arg_sqt->sqt_precision > res_sqt->sqt_precision ? res_sqt->sqt_precision : 5)
			{
			  memset (res_sqt, 0, sizeof (sql_type_t));
			  res_sqt->sqt_dtp = DV_NUMERIC;
			  res_sqt->sqt_scale = arg_sqt->sqt_scale;
			  res_sqt->sqt_precision = arg_sqt->sqt_precision;
			  return 1;
			}
		      else
			return 0;
	          case DV_STRING:
	          case DV_WIDE:
	          case DV_LONG_WIDE:
		      if (!arg_sqt->sqt_precision || arg_sqt->sqt_precision > 4)
			{
			  memset (res_sqt, 0, sizeof (sql_type_t));
			  res_sqt->sqt_dtp = DV_STRING;
			  res_sqt->sqt_precision = arg_sqt->sqt_precision;
			  return 1;
			}
		      else
			return 0;

		  default:
		      return 0;
		}
	    }
      case DV_LONG_INT:
	    {
	      switch (arg_sqt->sqt_dtp)
		{
		  case DV_LONG_INT:
		  case DV_SHORT_INT:
		      memset (res_sqt, 0, sizeof (sql_type_t));
		      res_sqt->sqt_dtp = DV_LONG_INT;
		      return 0;
		  case DV_SINGLE_FLOAT:
		      memset (res_sqt, 0, sizeof (sql_type_t));
		      res_sqt->sqt_dtp = DV_SINGLE_FLOAT;
		      return 1;
		  case DV_DOUBLE_FLOAT:
		      memset (res_sqt, 0, sizeof (sql_type_t));
		      res_sqt->sqt_dtp = DV_DOUBLE_FLOAT;
		      return 1;
		  case DV_NUMERIC:
	    if (arg_sqt->sqt_scale || arg_sqt->sqt_precision > res_sqt->sqt_precision ? res_sqt->sqt_precision : 9)
			{
			  memset (res_sqt, 0, sizeof (sql_type_t));
			  res_sqt->sqt_dtp = DV_NUMERIC;
			  res_sqt->sqt_scale = arg_sqt->sqt_scale;
			  res_sqt->sqt_precision = arg_sqt->sqt_precision;
			  return 1;
			}
		      else
			return 0;
	          case DV_WIDE:
	          case DV_LONG_WIDE:
	          case DV_STRING:
		      if (!arg_sqt->sqt_precision || arg_sqt->sqt_precision > 9)
			{
			  memset (res_sqt, 0, sizeof (sql_type_t));
			  res_sqt->sqt_dtp = DV_STRING;
			  res_sqt->sqt_precision = arg_sqt->sqt_precision;
			  return 1;
			}
		      else
			return 0;
		  default:
		      return 0;
		}
	    }
      case DV_SINGLE_FLOAT:
	    {
	      switch (arg_sqt->sqt_dtp)
		{
		  case DV_SHORT_INT:
		  case DV_LONG_INT:
		  case DV_SINGLE_FLOAT:
		      return 0;
		  case DV_DOUBLE_FLOAT:
		      memset (res_sqt, 0, sizeof (sql_type_t));
		      res_sqt->sqt_dtp = DV_DOUBLE_FLOAT;
		      return 1;
		  case DV_NUMERIC:
		      if (arg_sqt->sqt_scale + arg_sqt->sqt_precision > FLT_DIG)
			{
			  memset (res_sqt, 0, sizeof (sql_type_t));
			  res_sqt->sqt_dtp = DV_NUMERIC;
			  res_sqt->sqt_scale = arg_sqt->sqt_scale;
			  res_sqt->sqt_precision = arg_sqt->sqt_precision;
			  return 1;
			}
		      else
			return 0;
	          case DV_WIDE:
	          case DV_LONG_WIDE:
	          case DV_STRING:
		      if (!arg_sqt->sqt_precision || arg_sqt->sqt_precision > 25)
			{
			  memset (res_sqt, 0, sizeof (sql_type_t));
			  res_sqt->sqt_dtp = DV_STRING;
			  res_sqt->sqt_precision = arg_sqt->sqt_precision;
			  return 1;
			}
		      else
			return 0;
		  default:
		      return 0;
		}
	    }
      case DV_DOUBLE_FLOAT:
	    {
	      switch (arg_sqt->sqt_dtp)
		{
		  case DV_SHORT_INT:
		  case DV_LONG_INT:
		  case DV_SINGLE_FLOAT:
		  case DV_DOUBLE_FLOAT:
		      return 0;
		  case DV_NUMERIC:
		      if (arg_sqt->sqt_scale + arg_sqt->sqt_precision > DBL_DIG)
			{
			  memset (res_sqt, 0, sizeof (sql_type_t));
			  res_sqt->sqt_dtp = DV_NUMERIC;
			  res_sqt->sqt_scale = arg_sqt->sqt_scale;
			  res_sqt->sqt_precision = arg_sqt->sqt_precision;
			  return 1;
			}
		      else
			return 0;
	          case DV_WIDE:
	          case DV_LONG_WIDE:
		  case DV_STRING:
		      if (!arg_sqt->sqt_precision || arg_sqt->sqt_precision > 30)
			{
			  memset (res_sqt, 0, sizeof (sql_type_t));
			  res_sqt->sqt_dtp = DV_STRING;
			  res_sqt->sqt_precision = arg_sqt->sqt_precision;
			  return 1;
			}
		      else
			return 0;
		  default:
		      return 0;
		}
	    }
      case DV_NUMERIC:
	    {
	      switch (arg_sqt->sqt_dtp)
		{
		  case DV_SHORT_INT:
		      if (res_sqt->sqt_scale)
			{
		if (res_sqt->sqt_precision < arg_sqt->sqt_precision ? arg_sqt->sqt_precision : 4)
			    {
			      res_sqt->sqt_precision = NUMERIC_MAX_PRECISION;
			      return 1;
			    }
			}
	    else if (res_sqt->sqt_precision < arg_sqt->sqt_precision ? arg_sqt->sqt_precision : 4)
			{
			  memset (res_sqt, 0, sizeof (sql_type_t));
			  res_sqt->sqt_dtp = DV_SHORT_INT;
			  return 1;
			}
		      return 0;
		  case DV_LONG_INT:
		      if (res_sqt->sqt_scale)
			{
		if (res_sqt->sqt_precision < arg_sqt->sqt_precision ? arg_sqt->sqt_precision : 8)
			    {
			      res_sqt->sqt_precision = NUMERIC_MAX_PRECISION;
			      return 1;
			    }
			}
	    else if (res_sqt->sqt_precision < arg_sqt->sqt_precision ? arg_sqt->sqt_precision : 8)
			{
			  memset (res_sqt, 0, sizeof (sql_type_t));
			  res_sqt->sqt_dtp = DV_LONG_INT;
			  return 1;
			}
		      return 0;
		  case DV_DOUBLE_FLOAT:
		  case DV_SINGLE_FLOAT:
		      res_sqt->sqt_scale = NUMERIC_MAX_SCALE;
		      res_sqt->sqt_precision = NUMERIC_MAX_PRECISION;
		      return 1;
		  case DV_NUMERIC:
	    if (res_sqt->sqt_precision < arg_sqt->sqt_precision || res_sqt->sqt_scale < arg_sqt->sqt_scale)
			{
			  res_sqt->sqt_precision = res_sqt->sqt_precision < arg_sqt->sqt_precision ?
			      arg_sqt->sqt_precision : res_sqt->sqt_precision;
		res_sqt->sqt_precision = res_sqt->sqt_scale < arg_sqt->sqt_scale ? arg_sqt->sqt_scale : res_sqt->sqt_scale;
			  return 1;
			}
		      else
			return 0;
	          case DV_WIDE:
	          case DV_LONG_WIDE:
		  case DV_STRING:
	    if (!arg_sqt->sqt_precision || arg_sqt->sqt_precision > res_sqt->sqt_precision + res_sqt->sqt_scale + 1)
			{
			  memset (res_sqt, 0, sizeof (sql_type_t));
			  res_sqt->sqt_dtp = DV_STRING;
			  res_sqt->sqt_precision = arg_sqt->sqt_precision;
			  return 1;
			}
		      else
			return 0;
		  default:
		      return 0;
		}
	    }
      case DV_IRI_ID:
      case DV_IRI_ID_8:
	    {
	      if (arg_sqt->sqt_dtp == DV_ANY)
		{
		  memset (res_sqt, 0, sizeof (sql_type_t));
		  res_sqt->sqt_dtp = DV_ANY;
		  res_sqt->sqt_non_null = arg_sqt->sqt_non_null;
		  return 1;
		}
	    }
      default:
	  return 0;
    }
#endif
}


int enable_dt_alias = 0;

state_slot_t *
sqlg_alias_or_assign (sqlo_t * so, state_slot_t * ext, state_slot_t * source, dk_set_t * code, int is_value_subq)
{
  /* all slots referencing the inside position become aliased to reference the outside position.
   * in this way an arbitrary depth of subqs get referred to the desired output.  If not possible,
   * due to constants or ref params, then an assignment is generated */
  /* if no union above, aliasing can be used */
  if (!so->so_sc->sc_is_union && enable_dt_alias && !ssl_is_special (ext) && !ssl_is_special (source) && !(is_value_subq))
    {
      int src_index = source->ssl_index;
      ext->ssl_sqt = source->ssl_sqt;
      DO_SET (state_slot_t *, any_ssl,  &so->so_sc->sc_cc->cc_super_cc->cc_query->qr_state_map)
	{
	  if (any_ssl->ssl_index == src_index)
	    {
	      any_ssl->ssl_index = ext->ssl_index;
	      any_ssl->ssl_is_alias = (ext != any_ssl);
	      if (any_ssl->ssl_is_alias)
		any_ssl->ssl_alias_of = ext;
	    }
	}
      END_DO_SET ();
      return source;
    }
  else
    {
      sqlg_dtp_coerce (&ext->ssl_sqt, &source->ssl_sqt);
      cv_artm (code, (ao_func_t) box_identity, ext, source, NULL);
      return ext;
    }
}


void
sqlg_add_fail_stub (sqlo_t * so, data_source_t ** head)
{
  sql_comp_t * sc = so->so_sc;
  dk_set_t code = NULL;
  SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
  cv_bret (&code, 0);
  en->src_gen.src_after_test = code_to_cv_1 (sc, code, 0);
  sql_node_append (head, (data_source_t*) en);
}


data_source_t *
sqlg_add_breakup_node (sql_comp_t * sc, data_source_t ** head, state_slot_t *** ssl_ret, int n_per_set, dk_set_t * code)
{
  state_slot_t ** ssl_out = *ssl_ret;
  int inx;
  SQL_NODE_INIT (breakup_node_t, brk, breakup_node_input, breakup_node_free);
  brk->brk_all_output = ssl_out;
  DO_BOX (state_slot_t *, ssl, inx, ssl_out)
    {
      if (SSL_CONSTANT == ssl->ssl_type)
	{
	  state_slot_t * v = ssl_new_inst_variable (sc->sc_cc, "brkc", ssl->ssl_sqt.sqt_dtp);
	  cv_artm (code, (ao_func_t) box_identity, v, ssl, NULL);
	  ssl_out[inx] = v;
	}
      if (inx >= n_per_set)
	{
	  state_slot_t * prev = ssl_out[inx % n_per_set];
	  if (prev->ssl_dtp != DV_ANY && dtp_canonical[ssl->ssl_dtp] != dtp_canonical[prev->ssl_dtp])
	    prev->ssl_dtp = DV_ANY;
	}
    }
  END_DO_BOX;
  if (*code)
    {
      sqlg_pre_code_dpipe (sc->sc_so, code, (data_source_t*)brk);
	      brk->src_gen.src_pre_code = code_to_cv (sc, *code);
	      *code = NULL;
    }
  brk->brk_output = dk_alloc_box (sizeof (caddr_t) * n_per_set, DV_BIN);
  brk->brk_current_slot = cc_new_instance_slot  (sc->sc_cc);
  for (inx = 0; inx < n_per_set; inx++)
    brk->brk_output[inx] = brk->brk_all_output[inx];
  sql_node_append (head, (data_source_t *) brk);
  *ssl_ret = (state_slot_t**) box_copy ((caddr_t) brk->brk_output);
  return (data_source_t*)brk;
}


static state_slot_t **
sqlg_handle_select_list (sqlo_t *so, df_elt_t * dfe, data_source_t ** head,
    dk_set_t code, data_source_t *last_qn, ST ** target_names)
{
  ST ** as_temp;
  sql_comp_t * sc = so->so_sc;
  state_slot_t ** res;
  ST * tree = dfe->_.sub.ot->ot_dt;
  caddr_t * selection = (caddr_t *) t_box_copy_tree ((caddr_t) tree->_.select_stmt.selection);
  int inx;
  ST * top = tree->_.select_stmt.top;
  res = (state_slot_t **) dk_alloc_box_zero (box_length ((caddr_t) selection), DV_ARRAY_OF_POINTER);
  sqlc_select_strip_as ((ST **) selection, (caddr_t***) &as_temp, 0);
  sc->sc_select_as_list = (ST**) t_box_copy_tree ((caddr_t) as_temp);
  if (target_names && BOX_ELEMENTS (selection) != BOX_ELEMENTS (target_names))
    sqlc_new_error (so->so_sc->sc_cc, "37000", "SQ142", "Different number of expected and generated columns in a select");

  DO_BOX (ST *, exp, inx, tree->_.select_stmt.selection)
    {
      if (target_names && !target_names[inx])
	continue; /* non refd col of dt */
      if (dfe->_.sub.dt_out && dfe->_.sub.dt_out[inx])
	{
	  res[inx] = scalar_exp_generate (sc, exp, &code);
	}
    }
  END_DO_BOX;

  if (IS_BOX_POINTER (top) && top->_.top.trans && top->_.top.trans->_.trans.distinct)
    {
      /* step of a distinct trans.  Normalize same as */
      data_source_t * lst;
      if ((lst = sqlg_distinct_same_as  (so, head, (ST**)selection, dfe, code)))
	{
	  code = NULL;
	  last_qn = lst;
	}
    }
  else if (sel_n_breakup (tree) && (SEL_IS_DISTINCT (tree) || dfe->_.sub.dist_pos))
    {
      sqlg_add_breakup_node (sc, head, &res, sel_n_breakup (tree), &code);
      last_qn = (data_source_t*)sqlc_add_distinct_node (sc, head, res, (long) dfe->dfe_arity, &code, dfe->_.sub.dist_pos);
    }
  else if (SEL_IS_DISTINCT (tree) || dfe->_.sub.dist_pos)
    last_qn = (data_source_t*)sqlc_add_distinct_node (sc, head, res, (long) dfe->dfe_arity, &code, dfe->_.sub.dist_pos);
  else if (sel_n_breakup (tree))
    {
      last_qn = sqlg_add_breakup_node (sc, head, &res, sel_n_breakup (tree), &code);
    }
  if (sel_n_breakup (tree))
    {
      DO_BOX (state_slot_t *, out, inx, res)
	{
	  if (target_names && !target_names[inx])
	    continue; /* non refd col of dt */
	  if (target_names)
	    {
	      state_slot_t * target_ssl = sqlg_dfe_ssl (so, sqlo_df (so, target_names[inx]));
	      res[inx] = sqlg_alias_or_assign (so, target_ssl, res[inx], &code, sqlg_is_vector && DFE_VALUE_SUBQ == dfe->dfe_type);
	    }
	}
      END_DO_BOX;
    }
  else
    {
  DO_BOX (ST *, exp, inx, tree->_.select_stmt.selection)
    {
      if (target_names && !target_names[inx])
	continue; /* non refd col of dt */
      if (dfe->_.sub.dt_out && dfe->_.sub.dt_out[inx])
	{
	  if (target_names)
	    {
	      state_slot_t * target_ssl = sqlg_dfe_ssl (so, sqlo_df (so, target_names[inx]));
	      if (sc->sc_trans)
		sqlg_trans_rename (sc, res[inx], target_ssl);
		res[inx] = sqlg_alias_or_assign (so, target_ssl, res[inx], &code, sqlg_is_vector
		    && DFE_VALUE_SUBQ == dfe->dfe_type);
	    }
	}
    }
  END_DO_BOX;
    }
  if (code)
    {
      sqlg_pre_code_dpipe (so, &code, NULL);
      if (last_qn && !last_qn->src_after_code)
	last_qn->src_after_code = code_to_cv (sc, code);
      else
	{
	  SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
	  en->src_gen.src_pre_code = code_to_cv (sc, code);
	    sql_node_append (head, (data_source_t*) en);
	}
    }
  return res;
}


void
sqlg_select_node (sqlo_t * so, df_elt_t * dfe, data_source_t ** head, dk_set_t code, ST ** target_names, data_source_t * last_qn)
{
  sql_comp_t * sc = so->so_sc;
  comp_context_t * cc = so->so_sc->sc_cc;
  /*dk_set_t top_code = NULL;*/
  ST * tree = dfe->_.sub.ot->ot_dt;
  ST * table_exp = tree->_.select_stmt.table_exp;
/*  caddr_t *new_sel = NULL;*/
  SQL_NODE_INIT (select_node_t, sel, select_node_input, sel_free);
  SEL_NODE_INIT (cc, sel);

  if (table_exp)
    sel->sel_lock_mode = (char) TEXP_LOCK (table_exp);
  /* if already set as exclusive don't change it */
  if (sc->sc_cc->cc_query->qr_lock_mode != PL_EXCLUSIVE)
  sc->sc_cc->cc_query->qr_lock_mode = sel->sel_lock_mode;
  sel->sel_set_no = sqlg_set_no_if_needed (sc, head); /* XXX: should be so ??? */
  sqlc_select_top (sc, sel, tree, &code);

  sel->sel_out_slots = sqlg_handle_select_list (so, dfe, head, code, last_qn, target_names);

  sc->sc_cc->cc_query->qr_no_co_if_no_cr_name = 1;

/*  dk_free_tree ((caddr_t) new_sel);*/
  sql_node_append (head, (data_source_t *) sel);

  sqlc_select_unique_ssls (sc, sel, NULL);
  sqlc_select_as (sel->sel_out_slots, (caddr_t **) sc->sc_select_as_list);
  qr_add_current_of_output (sc->sc_cc->cc_query);
  if (sel->sel_set_no)
    sel->sel_prev_set_no = ssl_new_variable (sc->sc_cc, "prev_set", DV_LONG_INT);
}


int
sqlg_any_in_locus (sqlo_t * so, df_elt_t * start_dfe, locus_t * loc)
{
  df_elt_t * elt;
  for (elt = start_dfe; elt; elt = elt->dfe_next)
    {
      if (elt->dfe_locus == loc)
	return 1;
      if (DFE_DT == elt->dfe_type)
	{
	  if (sqlg_any_in_locus  (so, elt->_.sub.first, loc))
	    return 1;
	}
    }
  return 0;
}


data_source_t *
qn_next (data_source_t * qn)
{
  if (qn->src_continuations)
    return (data_source_t *) qn->src_continuations->data;
  return NULL;
}

data_source_t *
qn_last (data_source_t * qn)
{
  data_source_t * next;
  while ((next = qn_next (qn)))
    qn = next;
  return qn;
}


extern char qf_ctr;

void
qr_skip_node (sqlo_t * so, query_t * qr)
{
  /* if the query is a select with a top with skip, put a skip node before the last after code */
  sql_comp_t * sc = so->so_sc;
  table_source_t * last_ts = NULL;
  int is_vec = sqlg_is_vector;
  int post_nodes = 0;
  select_node_t * sel = NULL;
  data_source_t * prev = NULL, * qn = qr->qr_head_node;
  if (IS_QN (qn, select_node_input) && !qn_next (qn))
    return;
  for (qn = qr->qr_head_node; qn; qn = qn_next (qn))
    {
      qn_input_fn f = qn->src_input;
      if ((qn_input_fn) select_node_input_subq  == f || (qn_input_fn)select_node_input == f)
	{
	  sel = (select_node_t *) qn;
	  break;
	}
      if (IS_TS (qn))
	last_ts = (table_source_t *)qn;
      else
	last_ts = NULL;
      if (((qn_input_fn)end_node_input == f && !qn->src_after_test)
#ifdef KEYCOMP
	  || (qn_input_fn)dpipe_node_input == f
#endif
	  )
	{
	  post_nodes = 1;
	  continue;
	}
      post_nodes = 0;
      prev = qn;
    }
  if (sel && (sel->sel_top_skip || (is_vec && sel->sel_top)) && (is_vec || (prev->src_after_code || post_nodes)))
    {
      SQL_NODE_INIT (skip_node_t, sk, skip_node_input, NULL);
      sk->sk_top_skip = sel->sel_top_skip;
      sel->sel_top_skip = NULL;
      if (is_vec)
	{
	  sk->sk_row_ctr = ssl_new_inst_variable (sc->sc_cc, "ctr", DV_LONG_INT);
	  sk->sk_top = sel->sel_top;
	  sel->sel_top = NULL;
	  sk->sk_set_no = sel->sel_set_no;
	  if (last_ts && !sk->sk_top_skip && sk->sk_top && SSL_CONSTANT == sk->sk_top->ssl_type
	      && 1 == unbox (sk->sk_top->ssl_constant))
	    last_ts->ts_max_rows = 1;
	}
      else
      sk->sk_row_ctr = ssl_new_inst_variable (sc->sc_cc, "ctr", DV_LONG_INT);
      sk->src_gen.src_continuations = prev->src_continuations;
      prev->src_continuations = dk_set_cons ((void*)sk, NULL);
      sk->src_gen.src_after_code = prev->src_after_code;
      prev->src_after_code = NULL;
    }
}


void
dfe_loc_ensure_out_cols (df_elt_t * dfe)
{
  /* if a remote table is a hash filler, it can be that its out cols are not out cols of the locus but they must be. */
  if (DFE_TABLE != dfe->dfe_type || HR_FILL != dfe->_.table.hash_role)
    return;
  DO_SET (df_elt_t *, out, &dfe->_.table.out_cols)
    {
      DO_SET (locus_result_t *, lr, &dfe->dfe_locus->loc_results)
	{
	  if (box_equal (lr->lr_required->dfe_tree, out->dfe_tree))
	    goto found;
	}
      END_DO_SET();
      /* the out col was not in the results */
      dfe_loc_result (dfe->dfe_locus, dfe->dfe_super, out);
    found: ;
    }
  END_DO_SET();
}


query_t *
sqlg_dt_query_1 (sqlo_t * so, df_elt_t * dt_dfe, query_t * ext_query, ST ** target_names, state_slot_t *** sel_out_ret)
{
  end_node_t * inv_cond = NULL;
  dk_set_t generated_loci = NULL;
  data_source_t * qn = NULL, *last_qn = NULL;
  dk_set_t pre_code = NULL;
  df_elt_t * group_dfe = NULL, * order_dfe = NULL, * dfe;
  data_source_t * head = NULL;
  sql_comp_t * sc = so->so_sc;
  query_t * old_qr = sc->sc_cc->cc_query;
  query_t * qr = ext_query;
  int was_setp = 0;
  char delay_colo = sc->sc_delay_colocate;
  if (!qr)
    {
    DK_ALLOC_QUERY (qr);
      qr->qr_super = old_qr;
    }
  else if (ext_query != old_qr)
    ext_query->qr_super = old_qr;
  sc->sc_cc->cc_query = qr;
  if (old_qr && old_qr->qr_no_cast_error)
    qr->qr_no_cast_error = 1;
  if (old_qr)
    qr->qr_proc_vectored = old_qr->qr_proc_vectored;
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &generated_loci, 8000))
    sqlc_error (so->so_sc->sc_cc, ".....", "Stack Overflow");
  if (DK_MEM_RESERVE)
    sqlc_error (so->so_sc->sc_cc, ".....", "Out of memory");
  sc->sc_delay_colocate = 0;
  sc->sc_re_emit_code = 0;
  sqlg_qn_has_dfe ((data_source_t*)qr, dt_dfe);
  switch (dt_dfe->dfe_type)
    {
    case DFE_DT:
    case DFE_VALUE_SUBQ:
    case DFE_EXISTS:
      if (dt_dfe->_.sub.generated_dfe)
	dt_dfe = dt_dfe->_.sub.generated_dfe;
      if (sqlo_opt_value (dt_dfe->_.sub.ot->ot_opts, OPT_SPARQL))
	qr->qr_no_cast_error = 1;
      if (dt_dfe->_.sub.is_contradiction)
        {
	  sqlg_add_fail_stub (so, &head);
	}
      else if (dt_dfe->_.sub.invariant_test)
	{
	  SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
	  en->src_gen.src_after_test = sqlg_pred_body (so, dt_dfe->_.sub.invariant_test);
	  inv_cond = en;
	  sql_node_append (&head, (data_source_t*) en);
	}
      if (0 && IS_BOX_POINTER (dt_dfe->dfe_locus))
	{
	  data_source_t * rts = sqlg_locus_rts (so, dt_dfe, pre_code);
	  t_set_push (&generated_loci, (void*) dt_dfe->dfe_locus);
	  pre_code = NULL;
	  sql_node_append (&head, rts);
	  last_qn = rts;
	  goto make_select;
	}
      for (dfe = dt_dfe->_.sub.first; dfe; dfe = dfe->dfe_next)
	{
	  if (sc->sc_cc->cc_super_cc->cc_instance_fill >= STATE_SLOT_LIMIT)
	    sqlc_error (so->so_sc->sc_cc, ".....", "Query too large, variables in state over the limit");

	  if (IS_BOX_POINTER (dfe->dfe_locus))
	    {
	      if (dk_set_member (generated_loci, (void*)dfe->dfe_locus))
		continue;
	      if (DFE_TABLE == dfe->dfe_type || DFE_DT == dfe->dfe_type)
		{
		  data_source_t * rts;
		  dfe_loc_ensure_out_cols (dfe);
		  rts = sqlg_locus_rts (so, dfe, pre_code);
		  t_set_push (&generated_loci, (void*) dfe->dfe_locus);
		  pre_code = NULL;
		  if (DFE_TABLE == dfe->dfe_type && HR_FILL == dfe->_.table.hash_role)
		    rts = sqlg_hash_filler (so, dfe, rts);
		  else if (DFE_DT == dfe->dfe_type && dfe->_.sub.hash_filler_of)
		    rts = sqlg_hash_filler_dt (so, dfe, (subq_source_t*)qn);

		  last_qn = rts;
		  sql_node_append (&head, rts);
		}
	      else if (DFE_VALUE_SUBQ == dfe->dfe_type)
		{
		  /* a value subq on a remote generates only if there is nothing else in the same locus. Otherwise it is assumed that the subq will generate as a result of reference from the locus top */
		  if (!sqlg_any_in_locus (so, dfe->dfe_next, dfe->dfe_locus))
		    sqlg_dfe_code (so, dfe, &pre_code, 0, 0, 0);
		}
	      continue;
	    }
	  switch (dfe->dfe_type)
	    {
	    case DFE_BOP:
	    case DFE_CALL:
#if 1
		if (dfe->dfe_tree)
		  {
		    caddr_t name = dfe->dfe_tree->_.call.name;
		  if (IS_POINTER (name) && !stricmp (name, GROUPING_FUNC) && so->so_sc->sc_grouping)
		      {
		        ptrlong bitmap = 0;
			dfe->dfe_tree->_.call.params[2] = (ST*) t_box_num (so->so_sc->sc_grouping->ssl_index);
		      make_grouping_bitmap_set (NULL, dfe->dfe_tree->_.call.params[0], so->so_sc->sc_groupby_set, &bitmap);
			dfe->dfe_tree->_.call.params[1] = (ST*) t_box_num (bitmap);
		      }
		  }
#endif
	    case DFE_VALUE_SUBQ:
	    case DFE_CONTROL_EXP:
		  {
		    if (dfe->dfe_tree)
		      {
			df_elt_t *defd_dfe = sqlo_df_elt (so, dfe->dfe_tree);
			if (defd_dfe)
			  defd_dfe->dfe_ssl = NULL;
		      }
		    dfe->dfe_ssl = NULL;
		    sqlg_dfe_code (so, dfe, &pre_code, 0, 0, 0);
		    break;
		  }
	    case DFE_FILTER:
	      {
		SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
		sqlg_pre_code_dpipe (so, &pre_code, qn);
		en->src_gen.src_pre_code = code_to_cv (so->so_sc, pre_code);
		pre_code = NULL;
		en->src_gen.src_after_test = sqlg_pred_body (so, dfe->_.filter.body);
		sql_node_append (&head, (data_source_t*) en);
		last_qn = (data_source_t *) en;
		break;
	      }
	    case DFE_DT:
	    case DFE_QEXP:
	    case DFE_TABLE:
	      if (DFE_TABLE == dfe->dfe_type)
		{
		  if (HR_REF == dfe->_.table.hash_role)
		    {
		      sqlg_pred_merge (so, dfe, &pre_code);
		      last_qn = qn = sqlg_hash_source (so, dfe, &pre_code);
		    }
		  else
		    {
		      sqlg_pred_merge (so, dfe, &pre_code);
		      last_qn = qn = sqlg_make_ts (so, dfe, &pre_code);
		    }
		  if (dfe->_.table.text_node && (dfe->_.table.is_text_order || dfe->_.table.text_only))
		    qn = dfe->_.table.text_node;
		  if (dfe->_.table.text_only)
		    last_qn = dfe->_.table.text_node;
		  else if (dfe->_.table.xpath_node)
		    last_qn = dfe->_.table.xpath_node;
		  else if (dfe->_.table.text_node && !dfe->_.table.is_text_order)
		    last_qn = dfe->_.table.text_node;
		}
	      else if (DFE_DT == dfe->dfe_type)
		{
		  last_qn = qn = sqlg_make_dt (so, dfe, NULL, &pre_code);
		  if (dfe->_.sub.hash_filler_of)
		    last_qn = qn = sqlg_hash_filler_dt (so, dfe, (subq_source_t*)qn);
		  else
		    {
		      last_qn = qn = sqlg_inline_sqs (sc, dfe, (subq_source_t *) qn, &head, &pre_code);
		    }
		}
	      else
		{
		  last_qn = qn = sqlg_set_stmt (so, dfe, target_names);
		  was_setp = 1;
		}
	      if (DFE_TABLE == dfe->dfe_type && HR_FILL == dfe->_.table.hash_role)
		qn = sqlg_hash_filler (so, dfe, qn);
	      sqlg_pre_code_dpipe (so, &pre_code, qn);
	      qn->src_pre_code = code_to_cv (so->so_sc, pre_code);
	      pre_code = NULL;
	      sql_node_append (&head, qn);
	      if (DFE_TABLE== dfe->dfe_type && so->so_in_list_nodes)
		sqlg_in_iter_nodes (so, qn, &head);
	      if (DFE_TABLE == dfe->dfe_type && HR_FILL != dfe->_.table.hash_role)
		  sqlg_rdf_inf (dfe, qn, &head);
	      if (DFE_TABLE== dfe->dfe_type && dfe->_.table.ot->ot_is_outer && HR_FILL != dfe->_.table.hash_role)
		{
		  sqlg_set_no_if_needed (sc, &head);
		    qn_ensure_prev (sc, &head, qn);
		  sqlg_outer_with_iters (dfe, qn, &head);
		}
	      else if (DFE_DT== dfe->dfe_type && dfe->_.table.ot->ot_is_outer && dfe->_.sub.ot->ot_is_proc_view)
		{
		  sqlg_set_no_if_needed (sc, &head);
		  qn_ensure_prev (sc, &head, qn);
		  sqlg_outer_with_iters (dfe, qn, &head);
		}
	      else if (DFE_DT== dfe->dfe_type
		  && dfe->_.sub.ot->ot_is_outer && (1 != cl_run_local_only || sqlg_is_vector) && IS_QN (qn, subq_node_input))
		{
		  subq_source_t * sqs = (subq_source_t *)qn;
		  outer_seq_end_node_t * ose;
		  data_source_t * prev = qn_ensure_prev (sc, &head, qn);
		  sqlg_cl_bracket_outer (so, prev);
		  sqs->sqs_is_outer = 0;
		  ose = (outer_seq_end_node_t*)qn_next (qn);
		  ose->src_gen.src_after_test = sqs->sqs_after_join_test;
		  sqs->sqs_after_join_test = NULL;
		}
	      while (qn_next (last_qn))
		last_qn = qn_next (last_qn);
	      break;
	    case DFE_GROUP:
	      group_dfe = dfe;
	      last_qn = sqlg_group_node (so, &head, dfe, dt_dfe, pre_code);
	      pre_code = NULL;
	      if (inv_cond)
		{
		  /* when there is aggregate and data independent condition, put the first precode as the precode of the data independent condition because the aggregate that is evaluated anyhow also for false cond may ref data independent things assigned there. */
		  data_source_t * nxt = qn_next ((data_source_t *) inv_cond);
		  if (nxt)
		    {
		      dpipe_node_t * dp = sc->sc_qn_to_dpipe
			? (dpipe_node_t *) gethash ((void*)nxt, so->so_sc->sc_qn_to_dpipe) : NULL;
		      inv_cond->src_gen.src_pre_code = nxt->src_pre_code;
		      nxt->src_pre_code = NULL;
		      if (dp)
			{
			  sethash ((void*)inv_cond, sc->sc_qn_to_dpipe, (void*)dp);
			  sethash ((void*)nxt, sc->sc_qn_to_dpipe, NULL);
			}
		    }
		}
	      break;
	    case DFE_ORDER:
	      order_dfe = dfe;
	      last_qn = sqlg_oby_node (so, &head, order_dfe, dt_dfe, pre_code);
	      sc->sc_order = TS_ORDER_KEY; /* what is generated after oby must preserve the order from the oby */
	      pre_code = NULL;
	      break;
	    case DFE_HEAD:
	      break;
	    default:
	      SQL_GPF_T1 (so->so_sc->sc_cc, "Bad dfe to generate");
	    }
	}
    make_select:
      if (sel_out_ret)
	{
	  *sel_out_ret = sqlg_handle_select_list (so, dt_dfe, &head, pre_code, last_qn, target_names);
	}
      else if (!was_setp)
	sqlg_select_node (so, dt_dfe, &head, pre_code, target_names, last_qn);
      pre_code = NULL;
      break;

    default:
      SQL_GPF_T1 (so->so_sc->sc_cc, "only a dfe_dt is allowed at top for sqlg");
    }
  qr->qr_head_node = head;
  sqlg_place_dpipes (so, &qr->qr_head_node);
  sqlg_multistate_code (so->so_sc, &qr->qr_head_node, so->so_sc->sc_order == TS_ORDER_KEY);
  if (!ext_query)
    qr_set_local_code_and_funref_flag (qr);
  qr_skip_node (so, qr);
  sc->sc_cc->cc_query = old_qr;
  return qr;
}


int
sqlg_agg_needs_order (ST * st)
{
  if (st->_.fn_ref.user_aggr_addr)
    {
      user_aggregate_t * ua = (user_aggregate_t *)((ptrlong) unbox (st->_.fn_ref.user_aggr_addr));
      if (ua->ua_need_order)
        return 1;
      if (0 == stricmp (ua->ua_name, "db.dba.vector_agg") || 0 == stricmp (ua->ua_name, "db.dba.xmlagg"))
	return 1;
    }
  return 0;
}

int 
dfe_is_union_all (df_elt_t * dfe)
{
  dk_set_t parts = NULL;
  if (NULL == dfe)
    return 1;
  if (DFE_QEXP == dfe->dfe_type && UNION_ALL_ST == dfe->_.qexp.op && dfe_qexp_list (dfe, UNION_ALL_ST, &parts))
    return 1;
  return 0;
}


df_elt_t *
dfe_union_dfe (df_elt_t * dt_dfe)
{
  /* true if dfe  is a dt with a single union inside */
  df_elt_t * dfe, *uni_cand = NULL;
  char not_alone = 0;
  if (!dt_dfe || DFE_DT != dt_dfe->dfe_type
      || dt_dfe->_.sub.trans)
    return NULL;
  for (dfe = dt_dfe->_.sub.first->dfe_next; dfe; dfe = dfe->dfe_next)
    {
      if (dfe_is_union_all (dfe))
	return dfe;
      if (DFE_DT == dfe->dfe_type)
	{
	  
	  if (dfe_is_union_all (dfe->_.sub.first->dfe_next))
	    {
	      if (!uni_cand)
		uni_cand = dfe->_.sub.first->dfe_next;
	      else
		not_alone = 1;
	    }
	  if (DFE_TABLE == dfe->dfe_type)
	    not_alone = 1;
	}
    }
  return (uni_cand && !not_alone) ? uni_cand : NULL;
}


void
sqlg_set_ts_order (sqlo_t * so, df_elt_t * dt)
{
  /* set ordering off if aggregate, group or order by */
  df_elt_t * uni_dfe = NULL, *f;
 df_elt_t * dfe;
  char not_alone = 0, has_fref = 0;
  if (dt->_.sub.generated_dfe)
    {
      sqlg_set_ts_order (so, dt->_.sub.generated_dfe);
      return;
    }
  if (so->so_sc->sc_is_update || sqlo_opt_value (dt->_.sub.ot->ot_opts, OPT_ANY_ORDER) || dt->_.sub.hash_filler_of)
    {
      so->so_sc->sc_order = TS_ORDER_NONE;
      return;
    }
  for (dfe = dt->_.sub.first; dfe; dfe = dfe->dfe_next)
    {
      if (DFE_TABLE == dfe->dfe_type && HR_FILL == dfe->_.table.hash_role)
	continue;
      if (DFE_DT == dfe->dfe_type && dfe->_.sub.hash_filler_of)
	continue;
      if ((f = dfe_union_dfe (dfe)))
	{
	  if (!uni_dfe)
	    uni_dfe = f;
	  else 
	    not_alone = 1;
	}
      else if (DFE_TABLE == dfe->dfe_type || DFE_DT == dfe->dfe_type)
	not_alone = 1;
      if ((DFE_GROUP == dfe->dfe_type && !dfe->_.setp.is_distinct) || DFE_ORDER == dfe->dfe_type)
	{
	  has_fref = 1;
	  if (DFE_GROUP == dfe->dfe_type && !dfe->_.setp.specs)
	    {
	      DO_SET (ST *, fref, &dfe->_.setp.fun_refs)
		{
		  if (sqlg_agg_needs_order (fref))
		    return;
		}
	      END_DO_SET();
	    }
	  so->so_sc->sc_order = TS_ORDER_NONE;
	}
    }
  if (uni_dfe && has_fref && !not_alone && (CL_RUN_LOCAL == cl_run_local_only || enable_cl_fref_union))
    uni_dfe->_.qexp.is_in_fref = 1;
}


query_t *
sqlg_dt_subquery (sqlo_t * so, df_elt_t * dt_dfe, query_t * ext_query, ST ** target_names, state_slot_t * new_set_no)
{
  sql_comp_t * sc = so->so_sc;
  query_t * qr;
  char ord = so->so_sc->sc_order;
  update_node_t * kset = sc->sc_update_keyset;
  state_slot_t * set_no = sc->sc_set_no_ssl;
  sc->sc_update_keyset = NULL;
  sc->sc_set_no_ssl = new_set_no;
  sqlg_set_ts_order (so, dt_dfe);
  qr = sqlg_dt_query_1 (so, dt_dfe, ext_query, target_names, NULL);
  sc->sc_update_keyset = kset;
  sc->sc_set_no_ssl = set_no;
  so->so_sc->sc_order = ord;
  return qr;
}

void dfe_list_col_loci (df_elt_t * dfe);


void
dfe_filler_outputs (df_elt_t * tb_dfe)
{
  /* the locus of the hash joined table may have results which are not results of the hash filler. */
  df_elt_t * filler = tb_dfe->_.table.hash_filler;
  DO_SET (locus_result_t *, lr, &tb_dfe->dfe_locus->loc_results)
    {
      df_elt_t * out = lr->lr_required;
      DO_SET (locus_result_t *, res_lr, &filler->dfe_locus->loc_results)
	{
	  if (box_equal ((box_t) out->dfe_tree, (box_t) res_lr->lr_required->dfe_tree))
	    goto next;
	}
      END_DO_SET();
      dfe_loc_result (filler->dfe_locus, sqlo_top_dfe (tb_dfe), out);
    next: ;
    }
  END_DO_SET();
}


void
dfe_unit_col_loci (df_elt_t * dfe)
{
  df_elt_t * org_dfe = NULL;
  int inx;
  df_elt_t * col_dfe;
  caddr_t tmp[7];
  caddr_t ref;
  ST * ref_box;
  if (!IS_BOX_POINTER (dfe) || DFE_FALSE == dfe)
    return;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (dfe))
    {
      dfe_list_col_loci (dfe);
      return;
    }
  if (dfe->dfe_tree)
    {
      org_dfe = sqlo_df_elt (dfe->dfe_sqlo, dfe->dfe_tree);
      if (org_dfe)
	org_dfe->dfe_locus = dfe->dfe_locus;
    }
  BOX_AUTO (ref, tmp, 3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  ref_box = (ST*) ref;
  ref_box->type = COL_DOTTED;
  switch (dfe->dfe_type)
    {
    case DFE_TABLE:
      DO_SET (dbe_column_t *, col, &dfe->_.table.ot->ot_table->tb_primary_key->key_parts)
	{
	  ref_box->_.col_ref.prefix = dfe->_.table.ot->ot_new_prefix;
	  ref_box->_.col_ref.name = col->col_name;
	  col_dfe = sqlo_df_elt (dfe->dfe_sqlo, ref_box);
	  if (col_dfe)
	    col_dfe->dfe_locus = dfe->dfe_locus;
	}
      END_DO_SET();
      if (HR_REF == dfe->_.table.hash_role && dfe->_.table.hash_filler)
	{
	  if (IS_BOX_POINTER (dfe->dfe_locus))
	    dfe_filler_outputs (dfe);
	  dfe_unit_col_loci (dfe->_.table.hash_filler);
	  dfe->dfe_locus = LOC_LOCAL; /* remote table hash joined has the ref bnode as local and the filler as remote */
	}
      if (HR_FILL == dfe->_.table.hash_role)
	t_set_push (&dfe->dfe_sqlo->so_hash_fillers, (void*) dfe);
      dfe_list_col_loci ((df_elt_t *)dfe->_.table.join_test);
      dfe_list_col_loci ((df_elt_t *)dfe->_.table.after_join_test);
      dfe_list_col_loci ((df_elt_t *)dfe->_.table.vdb_join_test);
      break;
    case DFE_EXISTS:
    case DFE_VALUE_SUBQ:
    case DFE_DT:
	{
	  if (dfe->_.sub.generated_dfe)
	    dfe_unit_col_loci (dfe->_.sub.generated_dfe);
	  else
	    {
	      op_table_t * ot = dfe->_.sub.ot;
	      if (ST_P (ot->ot_dt, SELECT_STMT))
		{
		  if (org_dfe && org_dfe != dfe)
		    org_dfe->_.sub.generated_dfe = dfe;
		  DO_BOX (ST *, as_exp, inx, ot->ot_dt->_.select_stmt.selection)
		    {
		      if (ST_P (as_exp, BOP_AS))
			{
			  /* columns of a top select are not always AS declared. */
			  ref_box->_.col_ref.prefix = ot->ot_new_prefix;
			  ref_box->_.col_ref.name = as_exp->_.as_exp.name;
			  col_dfe = sqlo_df_elt (dfe->dfe_sqlo, ref_box);
			  if (col_dfe)
			    col_dfe->dfe_locus = dfe->dfe_locus;
			}
		    }
		  END_DO_BOX;
		}
	      if (dfe->_.sub.hash_filler_of)
		t_set_push (&dfe->dfe_sqlo->so_hash_fillers, (void*) dfe);
	      dfe_list_col_loci (dfe->_.sub.first);
	      dfe_list_col_loci ((df_elt_t *) dfe->_.sub.after_join_test);
	      dfe_list_col_loci ((df_elt_t *) dfe->_.sub.vdb_join_test);
	      DO_SET (df_elt_t *, pred, &dfe->_.sub.dt_preds)
		{
		  dfe_unit_col_loci (pred);
		}
	      END_DO_SET();
	      DO_SET (df_elt_t *, pred, &dfe->_.sub.dt_imp_preds)
		{
		  dfe_unit_col_loci (pred);
		}
	      END_DO_SET();
	      if (dfe->dfe_type == DFE_VALUE_SUBQ)
		org_dfe->_.sub = dfe->_.sub; /* find the copy with layout in sqlo_df, not the bare original */
	    }
	  break;
	}
    case DFE_QEXP:
      DO_BOX (df_elt_t *, elt, inx, dfe->_.qexp.terms)
	{
	  dfe_unit_col_loci (elt);
	}
      END_DO_BOX;
      break;
    case DFE_CONTROL_EXP:
	{
	  id_hash_t *old_private_elts = dfe->dfe_sqlo->so_df_private_elts;

	  DO_BOX (df_elt_t *, elt, inx, dfe->_.control.terms)
	    {
	      dfe->dfe_sqlo->so_df_private_elts = dfe->_.control.private_elts[inx];
	      dfe_unit_col_loci (elt);
	      dfe->dfe_sqlo->so_df_private_elts = old_private_elts;
	    }
 	  END_DO_BOX;
          if (ST_P (dfe->dfe_tree, SEARCHED_CASE))
	    {
	      DO_BOX (ST *, elt, inx, dfe->dfe_tree->_.comma_exp.exps)
		{
		  if (inx % 2 == 0)
		    {
		      df_elt_t *pred;
		      dfe->dfe_sqlo->so_df_private_elts = dfe->_.control.private_elts[inx];
		      pred = sqlo_df (dfe->dfe_sqlo, elt);
		      dfe_unit_col_loci (pred);
		      dfe->dfe_sqlo->so_df_private_elts = old_private_elts;
		    }
		}
	      END_DO_BOX;
	    }
	  break;
	}
    case DFE_GROUP:
      /* mark the fun ref loci.  The loc is that of the group dfe  */
      DO_SET (ST *, fref, &dfe->_.setp.fun_refs)
	{
	  df_elt_t * org_fref = sqlo_df (dfe->dfe_sqlo, fref);
	  org_fref->dfe_locus = dfe->dfe_locus;
	}
      END_DO_SET();
      dfe_list_col_loci ((df_elt_t *)dfe->_.setp.after_test);
      break;
    case DFE_FILTER:
      dfe_list_col_loci ((df_elt_t *)dfe->_.filter.body);
      break;
    case DFE_BOP:
    case DFE_BOP_PRED:
      dfe_unit_col_loci (dfe->_.bin.left);
      dfe_unit_col_loci (dfe->_.bin.right);
      break;

    default:
      break;
    }
}


void
dfe_list_col_loci (df_elt_t * dfe)
{
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (dfe))
    {
      int inx;
      df_elt_t ** dfe_arr = (df_elt_t **) dfe;
      DO_BOX (df_elt_t *, elt, inx, dfe_arr)
	{
	  dfe_unit_col_loci (elt);
	}
      END_DO_BOX;
    }
  else
    {
      while (dfe)
	{
	  dfe_unit_col_loci (dfe);
	  dfe = dfe->dfe_next;
	}
    }
}

int enable_vec = 1;

void
sqlg_top_1 (sqlo_t * so, df_elt_t * dfe, state_slot_t ***sel_out_ret)
{
  comp_context_t * outer_cc = so->so_sc->sc_cc;
  comp_context_t inner_cc;
  memset (&inner_cc, 0, sizeof (inner_cc));
  inner_cc.cc_schema = outer_cc->cc_schema;
  inner_cc.cc_super_cc = outer_cc->cc_super_cc;
  inner_cc.cc_query = outer_cc->cc_query;
  so->so_sc->sc_cc = &inner_cc;
  so->so_sc->sc_any_clb = 0;
  dfe_unit_col_loci (dfe);
  DO_SET (df_elt_t *, filler, &so->so_hash_fillers)
    {
      sqlo_place_hash_filler (so, dfe, filler);
    }
  END_DO_SET();
  sqlg_set_ts_order (so, dfe);
  sqlg_dt_query_1 (so, dfe, so->so_sc->sc_cc->cc_query, NULL, sel_out_ret);
  if (so->so_sc->sc_parallel_dml)
    sqlg_parallel_ts_seq (so->so_sc, dfe, (table_source_t*)so->so_sc->sc_cc->cc_query->qr_head_node, NULL, NULL);
  sqlg_set_no_if_needed (so->so_sc, &so->so_sc->sc_cc->cc_query->qr_head_node);
  if (so->so_sc->sc_any_clb)
    {
      so->so_sc->sc_sel_out = sel_out_ret ? *sel_out_ret : NULL;
      if (SC_UPD_PLACE != so->so_sc->sc_is_update && SC_UPD_INS != so->so_sc->sc_is_update)
	sqlg_qr_env (so->so_sc, so->so_sc->sc_cc->cc_query); /* upd/del will do this after the dml node is added */
    }
  if (IS_BOX_POINTER (dfe->dfe_locus))
    so->so_sc->sc_cc->cc_query->qr_remote_mode = QR_PASS_THROUGH;
  so->so_sc->sc_cc = outer_cc;
}

void
sqlg_top (sqlo_t * so, df_elt_t * dfe)
{
  sqlg_top_1 (so, dfe, NULL);
}


void
qr_print_ssl (query_t * qr, ssl_index_t i)
{
  DO_SET (state_slot_t *, ssl, &qr->qr_state_map)
    if (i == ssl->ssl_index)
      printf ("%p\n", ssl);
  END_DO_SET ();
}


