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

void sqlg_setp_keys (sqlo_t * so, setp_node_t * setp, int force_gb, long n_rows);

void sqlg_setp_append (data_source_t ** head, setp_node_t * setp);

void dfe_unit_col_loci (df_elt_t * dfe);

void sqlg_pred_1 (sqlo_t * so, df_elt_t ** body, dk_set_t * code, int succ, int fail, int unk);

static int
make_grouping_bitmap_set (ST ** sel_cols, ST * col, ST **etalon, ptrlong * bitmap);

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
	      /* test also thet the out col is actually from this table since out cols can be overlapped in case of inxop between tables, all mentioned on the top table */
	      out->dfe_is_placed = DFE_GEN;
	      sqlg_dfe_ssl (so, out);
	    dk_set_push (&ks->ks_out_slots, (void *) out->dfe_ssl);
	    dk_set_push (&ks->ks_out_cols, (void *) out->_.col.col);
	  }
      }
      if (ks->ks_key->key_is_primary &&
	  (ptrlong) out->_.col.col == CI_ROW)
	{
	  if (!sec_tb_check (tb_dfe->_.table.ot->ot_table, SC_G_ID (sc), SC_U_ID (sc), GR_SELECT))
	    sqlc_new_error (sc->sc_cc, "42000", "SQ043",
			    "_ROW requires select permission on the entire table.");
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
  if (ST_P (tree, COL_DOTTED))
    {
      if (dfe != sqlo_df (so, dfe->dfe_tree))
	SQL_GPF_T1 (so->so_sc->sc_cc, "There are 2 different dfes for the same col ref. Not really supposed to");
      if (dfe->_.col.vc)
	{
	  dfe->dfe_ssl = sqlc_new_temp (so->so_sc,
	      dfe->dfe_tree->_.col_ref.name, dfe->_.col.vc->vc_dtp);
	}
      else if (dfe->_.col.col)
	{
	  char *prefix = NULL;
	  op_table_t * ot = sqlo_cname_ot (so, tree->_.col_ref.prefix);
	  if (ot)
	    prefix = ot->ot_prefix;
	  else
            prefix = tree->_.col_ref.prefix;

	  dfe->dfe_ssl = ssl_new_column (so->so_sc->sc_cc,
	      prefix ? prefix : "", dfe->_.col.col);
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


search_spec_t *
dfe_to_spec (df_elt_t * lower, df_elt_t * upper, dbe_key_t * key)
{
  sqlo_t * so = lower->dfe_sqlo;
  NEW_VARZ (search_spec_t, sp);
  sp->sp_is_boxed = 1;
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
	  sp->sp_max_ssl = sqlg_dfe_ssl (so, lower->_.bin.right);
	  if (SSL_IS_UNTYPED_PARAM (sp->sp_max_ssl))
	    {
	      sp->sp_max_ssl->ssl_sqt = sp->sp_col->col_sqt;
	    }
	}
      else
	{
	  sp->sp_max_op = CMP_NONE;
	  sp->sp_min_op = op;
	  sp->sp_min_ssl = sqlg_dfe_ssl (so, lower->_.bin.right);
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
      sp->sp_min_ssl = sqlg_dfe_ssl (so, lower->_.bin.right);
      if (SSL_IS_UNTYPED_PARAM (sp->sp_min_ssl))
	{
	  sp->sp_min_ssl->ssl_sqt = sp->sp_col->col_sqt;
	}
      sp->sp_max_op = bop_to_dvc (upper->_.bin.op);
      sp->sp_max_ssl = sqlg_dfe_ssl (so, upper->_.bin.right);
      if (SSL_IS_UNTYPED_PARAM (sp->sp_max_ssl))
	{
	  sp->sp_max_ssl->ssl_sqt = sp->sp_col->col_sqt;
	}
    }
  return sp;
}


key_source_t *
sqlg_key_source_create (sqlo_t * so, df_elt_t * tb_dfe, dbe_key_t * key)
{
  search_spec_t *spec;
  int part_no = 0;
  NEW_VARZ (key_source_t, ks);
  ks->ks_key = key;

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
	      spec->sp_is_boxed = 1;
	      spec->sp_col = cp->_.text.col;
	      spec->sp_collation = spec->sp_col->col_sqt.sqt_collation;
	      spec->sp_max_op = CMP_NONE;
	      spec->sp_min_op = CMP_EQ;
	      spec->sp_min_ssl = cp->_.text.ssl;
	      cl = key_find_cl (key, spec->sp_col->col_id);
	      memcpy (&(spec->sp_cl), cl, sizeof (dbe_col_loc_t));
	    }
	  else
	    {
	      if (dfe_is_lower (cp))
		{
		  upper = sqlo_key_part_best (col, tb_dfe->_.table.col_preds, 1);
		  if (upper)
		    upper->dfe_is_placed = DFE_GEN;
		}
	      spec = dfe_to_spec (cp, upper, key);
	    }
	  ks_spec_add (&ks->ks_spec, spec);
	  /* Only 0-n equalities plus 0-1 ordinal relations allowed here.  Rest go to row specs. */
	  if (spec->sp_min_op != CMP_EQ)
	    break;
	  part_no++;
	  if (part_no >= key->key_n_significant)
	    break;

    }
  END_DO_SET ();

  DO_SET (df_elt_t *, cp, &tb_dfe->_.table.col_preds)
  {
    if (DFE_GEN != cp->dfe_is_placed
	&& (
	  (cp->dfe_type == DFE_TEXT_PRED &&
	   dk_set_member (ks->ks_key->key_parts, (void *) cp->_.text.col)) ||
	   dk_set_member (ks->ks_key->key_parts, (void *) cp->_.bin.left->_.col.col)))
      {
	cp->dfe_is_placed = DFE_GEN;
	if (cp->dfe_type == DFE_TEXT_PRED)
	  {
	    dbe_col_loc_t * cl;
	    spec = (search_spec_t *) dk_alloc (sizeof (search_spec_t));
	    memset (spec, 0, sizeof (search_spec_t));
	    spec->sp_is_boxed = 1;
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
  }
  END_DO_SET ();
  sqlg_ks_out_cols (so, tb_dfe, ks);
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
sqlg_ks_out_col (sqlo_t * so, df_elt_t * tb_dfe, key_source_t * ks,
		 dbe_column_t * col)
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
sqlg_ks_make_main_spec (sqlo_t * so, df_elt_t * tb_dfe, key_source_t * ks,
			key_source_t * order_ks)
{
  int part_no = 0;
  search_spec_t **last_spec = &ks->ks_spec;
  if (ks->ks_spec)
    SQL_GPF_T(so->so_sc->sc_cc);		/* prime key specs left after order key processed */

  DO_SET (dbe_column_t *, col, &ks->ks_key->key_parts)
  {
    if (part_no >= ks->ks_key->key_n_significant)
      return;
    else
      {
	NEW_VARZ (search_spec_t, sp);
	*last_spec = sp;
	last_spec = &sp->sp_next;
	sp->sp_min_op = CMP_EQ;
	sp->sp_max_op = CMP_NONE;
	sp->sp_min_ssl = sqlg_ks_out_col (so, tb_dfe, order_ks, col);
	sp->sp_is_boxed = 1;
	sp->sp_cl = *key_find_cl (ks->ks_key, col->col_id);
      }
    part_no++;
  }
  END_DO_SET ();
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


void
sqlg_text_node (sqlo_t * so, df_elt_t * tb_dfe)
{
  int ctype = tb_dfe->_.table.text_pred->_.text.type, inx;
  op_table_t *ot = dfe_ot (tb_dfe);
  sql_comp_t *sc = so->so_sc;
  ST **args = tb_dfe->_.table.text_pred->_.text.args;
  state_slot_t *text_id = NULL;
  dk_set_t code = NULL;
  SQL_NODE_INIT (text_node_t, txs, txs_input, txs_free);
  /* make a col predicate to drive the ts, then generate a text node that will instantiate the variable  */
  if (tb_dfe->_.table.is_text_order)
    {
      df_elt_t *text_pred = tb_dfe->_.table.text_pred;
      text_id = sqlc_new_temp (sc, "text_id", DV_LONG_INT);
      tb_dfe->_.table.key = tb_text_key (ot->ot_table);
      text_pred->_.text.col = (dbe_column_t *) tb_dfe->_.table.key->key_parts->data;
      text_pred->_.text.ssl = text_id;
      t_set_push (&tb_dfe->_.table.col_preds, (void *) text_pred);
    }
  else
    {
      dbe_column_t *col = (dbe_column_t *) tb_text_key (ot->ot_table)->key_parts->data;
      df_elt_t *col_dfe = sqlo_df (so, t_listst (3, COL_DOTTED, ot->ot_new_prefix, col->col_name));
      text_id = sqlg_dfe_ssl (so, col_dfe);
    }
  txs->txs_cached_string = sqlc_new_temp (sc, "text_search_cached_exp_string", DV_SHORT_STRING);
  txs->txs_cached_compiled_tree = sqlc_new_temp (sc, "text_search_cached_tree", DV_ARRAY_OF_POINTER);
  txs->txs_cached_dtd_config = sqlc_new_temp (sc, "text_search_dtd_config", DV_ARRAY_OF_POINTER);
  txs->txs_table = tb_text_key (ot->ot_table)->key_text_table;
  txs->txs_d_id = text_id;
  txs->txs_is_driving = tb_dfe->_.table.is_text_order;
  if (ctype == 'x')
    {
      txs->txs_xpath_text_exp = sqlc_new_temp (sc, "xpath_text_exp", DV_SHORT_STRING);
      tb_dfe->_.table.is_xcontains = 1;
    }
  txs->txs_text_exp = scalar_exp_generate (sc, args[1], &code);
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
	  SQL_GPF_T1(so->so_sc->sc_cc, "internal error during compilation of text node");
    }
  txs->txs_sst = sqlc_new_temp (sc, "text search", DV_TEXT_SEARCH);
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
  ST **args = tb_dfe->_.table.text_pred
  ? tb_dfe->_.table.text_pred->_.text.args : NULL;
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
  xn->xn_xqi = sqlc_new_temp (so->so_sc, "text search", DV_XQI);
  xn->xn_compiled_xqr_text = sqlc_new_temp (so->so_sc, "xp_text", DV_SHORT_STRING);
  xn->xn_compiled_xqr = sqlc_new_temp (so->so_sc, "xp_xqr", DV_XPATH_QUERY);
  xn->src_gen.src_pre_code = code_to_cv (sc, code);
  tb_dfe->_.table.xpath_node = (data_source_t *) xn;
  if (tb_dfe->_.table.text_node && tb_dfe->_.table.is_xcontains)
    {
      ((text_node_t *) tb_dfe->_.table.text_node)->txs_xpath_node = xn;
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
      && !ts->ts_order_ks->ks_row_spec && !tb_dfe->_.table.xpath_node)
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
sqlg_inx_op_and_ks (sqlo_t * so, inx_op_t * and_iop, inx_op_t * iop,
		    df_inx_op_t * and_dio, df_inx_op_t * dio)
{
  key_source_t * ks = iop->iop_ks;
  search_spec_t ** last_spec = &iop->iop_ks_full_spec ;
  search_spec_t * sp;
  dk_set_t max_ssls = NULL;
  int nth = 0, nth_free = 0;
  int is_first = NULL == and_iop->iop_max;
  int n_eqs;
  nth = 0;
  sp = ks->ks_spec;
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
	  sp2->sp_is_boxed = 1;
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
	      /* this also sets what it compares with. This can be col of oter table.  So gen also the ssl asg of the col ssl from this table */
	      dk_set_push (&ks->ks_out_cols, (void*) col);
	      dk_set_push (&ks->ks_out_slots, (void*) sp2->sp_min_ssl);
	      sqlg_ks_out_col (so, dio->dio_table, ks, col);
	      if (dio->dio_table != first_table)
		{
		  /* merge between two tables. The out must be the same as the out of the first term.  But if hit, the value must also be assigned to the right ssl */
		}
	    }
	  sp2->sp_is_boxed = 1;
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
  ks->ks_spec = NULL;
  inx_op_set_search_params (so->so_sc, NULL, iop);
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
	int inx = 0;
	iop->iop_terms = (inx_op_t **) dk_set_to_array ((dk_set_t) dio->dio_terms);
	DO_SET (df_inx_op_t *, term, &dio->dio_terms)
	  {
	    iop->iop_terms[inx] = sqlg_inx_op (so, tb_dfe, term, iop);
	    inx++;
	  }
	END_DO_SET();
	DO_BOX (inx_op_t *, term, inx, iop->iop_terms)
	  {
	    sqlg_inx_op_and_ks (so, iop, term, dio, (df_inx_op_t*) dk_set_nth (dio->dio_terms, inx));
	  }
	END_DO_BOX;

	break;
      }
    case IOP_KS:
      iop->iop_ks = sqlg_key_source_create (so, dio->dio_table, dio->dio_key);
      sqlg_inx_op_ks_out_cols (so, iop->iop_ks, dio->dio_table, tb_dfe);
      iop->iop_itc = ssl_new_itc (so->so_sc->sc_cc);
      if (iop->iop_ks->ks_key->key_is_bitmap)
	iop->iop_bitmap = ssl_new_variable  (so->so_sc->sc_cc, "inxop f", DV_STRING);
      break;
    }
    return iop;
}



data_source_t *
sqlg_make_ts (sqlo_t * so, df_elt_t * tb_dfe)
{
  sql_comp_t * sc = so->so_sc;
  comp_context_t *cc = so->so_sc->sc_cc;
  key_source_t * order_ks;
  op_table_t * ot = tb_dfe->_.table.ot;
  dbe_table_t *table = ot->ot_table;
  dbe_key_t *order_key = tb_dfe->_.table.key;
  dbe_key_t *main_key;

  SQL_NODE_INIT (table_source_t, ts, table_source_input, ts_free);

  main_key = table->tb_primary_key;
  DO_SET (op_virt_col_t *, vc, &ot->ot_virtual_cols)
    {
      df_elt_t *vc_dfe =  sqlo_df_virt_col (so, vc);
      vc_dfe->dfe_ssl = sqlg_dfe_ssl (so, vc_dfe);
    }
  END_DO_SET ();
#ifdef BIF_XML
  if (ot->ot_text_score)
    {
      if (!tb_dfe->_.table.text_pred)
	SQL_GPF_T1 (cc, "The contains pred present and not placed");
      sqlg_text_node (so, tb_dfe);
      order_key = tb_dfe->_.table.key;
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
      ts->ts_current_of = ssl_new_placeholder (cc, ct_id);
    }
  ts->ts_order_cursor = ssl_new_itc (cc);

  /* Done? Need the main row? */

  if (order_key != table->tb_primary_key || ts->ts_inx_op)
    {
      if (tb_undone_specs (tb_dfe) || tb_undone_cols (tb_dfe))
	{
	  ts->ts_main_ks = sqlg_key_source_create (so, tb_dfe, main_key);
	  order_ks = ts->ts_order_ks ? ts->ts_order_ks : ts->ts_inx_op->iop_terms[0]->iop_ks;
	  sqlg_ks_make_main_spec (so, tb_dfe, ts->ts_main_ks, order_ks);
	  il_init (so->so_sc->sc_cc, &ts->ts_il);
	}
    }

  ts->ts_is_outer = tb_dfe->_.table.ot->ot_is_outer;
  order_ks = ts->ts_order_ks;
  if (order_ks && order_ks->ks_spec)
    ts->ts_is_unique = tb_dfe->_.table.is_unique;
  /* if the order key has no spec then this can't be a full match of the key.  The situation is a contradiction, can happen if there is a unique pred but the wrong key.  Aberration of score function is possible cause.*/

  if (order_ks)
    ks_set_search_params (NULL, NULL, order_ks);
  if (ts->ts_main_ks)
    ks_set_search_params (sc, NULL, ts->ts_main_ks);
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
  ts->src_gen.src_after_test = sqlg_pred_body (so, tb_dfe->_.table.join_test);
  ts->ts_after_join_test = sqlg_pred_body (so, tb_dfe->_.table.after_join_test);
  if (tb_dfe->_.table.is_unique && !ts->ts_main_ks)
    ts->src_gen.src_input = (qn_input_fn) table_source_input_unique;

  sqlc_ts_set_no_blobs (ts);
  ts_alias_current_of (ts);
  table_source_om (sc->sc_cc, ts);

  if (ot->ot_opts && sqlo_opt_value (ot->ot_opts, OPT_RANDOM_FETCH))
    {
      caddr_t res = sqlo_opt_value (ot->ot_opts, OPT_RANDOM_FETCH);
      ts->ts_is_random = 1;
      ts->ts_rnd_pcnt = res;
    }
  if (ts->ts_order_ks && ot->ot_opts && sqlo_opt_value (ot->ot_opts, OPT_VACUUM))
    {
      caddr_t res = sqlo_opt_value (ot->ot_opts, OPT_VACUUM);
      ts->ts_order_ks->ks_is_vacuum = 1;
    }
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
sqlg_hash_filler (sqlo_t * so, df_elt_t * tb_dfe, data_source_t * ts_src)
{
  dk_set_t fill_code = NULL;
  op_table_t * ot = tb_dfe->_.table.ot;
  hash_area_t * ha;
  sql_comp_t * sc = so->so_sc;
#ifdef NEW_HASH
  table_source_t *ts = (table_source_t *) ts_src;
  key_source_t * ks = ts->ts_main_ks ? ts->ts_main_ks : ts->ts_order_ks;
#endif
  int shareable = !tb_dfe->_.table.all_preds;
  SQL_NODE_INIT (setp_node_t, setp, setp_node_input, setp_node_free);
  if (IS_BOX_POINTER (tb_dfe->dfe_locus))
    shareable = 0;
  ot->ot_hash_filler = setp;

  sqlg_pred_1 (so, tb_dfe->_.table.hash_filler_after_code, &fill_code, 0, 0, 0);

  DO_SET (df_elt_t *, out_dfe, &tb_dfe->_.table.hash_keys)
    {
      state_slot_t * ssl = scalar_exp_generate (so->so_sc, out_dfe->dfe_tree, &fill_code);
      NCONCF1 (setp->setp_keys, ssl);
      if (DFE_COLUMN != out_dfe->dfe_type)
	shareable = 0; /* a hash inx w/ exps for keys is not shareable */
    }
  END_DO_SET();
  ts_src->src_after_code = code_to_cv (so->so_sc, fill_code);
  DO_SET (df_elt_t *, out_dfe, &tb_dfe->_.table.out_cols)
    {
      state_slot_t * ssl = sqlg_dfe_ssl (so, out_dfe);
      if (!dk_set_member (setp->setp_keys, (void*)ssl))
	NCONCF1 (setp->setp_dependent, ssl);
    }
  END_DO_SET();
  setp_distinct_hash (so->so_sc, setp, dbe_key_count (tb_dfe->_.table.key));
  ha = setp->setp_ha;
  ha->ha_allow_nulls = 0;
  ha->ha_op = HA_FILL;
  sqlg_setp_append (&ts_src, setp);

#ifdef NEW_HASH
  if (shareable)
    ks->ks_ha = ha;
#endif
  {
    SQL_NODE_INIT (fun_ref_node_t, fref, (shareable ? hash_fill_node_input : fun_ref_node_input) , fun_ref_free);
    fref->fnr_select = ts_src;
    fref->fnr_setp = setp;
    if (shareable)
      fref->fnr_hi_signature = hs_make_signature (setp, tb_dfe->_.table.ot->ot_table);
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


data_source_t *
sqlg_hash_source (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t * pre_code)
{
  hash_area_t * ha_copy = (hash_area_t *) dk_alloc (sizeof (hash_area_t));
  sql_comp_t * sc = so->so_sc;
  int inx = 0;
  dk_set_t ref_slots = NULL, out_slots = NULL;
  op_table_t * ot = tb_dfe->_.table.ot;
  setp_node_t * setp = ot->ot_hash_filler;
  hash_area_t * ha = setp->setp_ha;
  SQL_NODE_INIT (hash_source_t, hs, hash_source_input, hash_source_free);
  hs->hs_current_inx = cc_new_instance_slot (so->so_sc->sc_cc);
  DO_SET (df_elt_t *, ref, &tb_dfe->_.table.hash_refs)
    {
      state_slot_t * ssl = scalar_exp_generate (so->so_sc,  ref->dfe_tree, pre_code);
      if (ssl->ssl_type == SSL_CONSTANT)
	{
	  state_slot_t *ssl1 = ssl_new_variable (sc->sc_cc, "", DV_UNKNOWN);
	  ssl_copy_types (ssl1, ssl);
	  cv_artm (pre_code, box_identity, ssl1, ssl, NULL);
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
  hs->hs_out_cols = (dbe_col_loc_t *) dk_alloc (sizeof (dbe_col_loc_t) * (1 + dk_set_length (tb_dfe->_.table.out_cols)));
  hs->hs_out_cols_indexes = (ptrlong *) dk_alloc (sizeof (ptrlong) * (1 + dk_set_length (tb_dfe->_.table.out_cols)));

  DO_SET (df_elt_t *, out, &tb_dfe->_.table.out_cols)
    {
      state_slot_t * ssl = sqlg_dfe_ssl (so, out);
      dk_set_push (&out_slots, (void*) ssl);
      setp_ha_find_col (setp, out->_.col.col, hs->hs_out_cols+inx, hs->hs_out_cols_indexes+inx);
      inx++;
    }
  END_DO_SET();
  hs->hs_out_cols[inx].cl_col_id = 0;
  hs->hs_out_cols_indexes[inx] = -1;
  hs->hs_out_slots = (state_slot_t **) list_to_array (dk_set_nreverse (out_slots));
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
	      if (ST_P (colp_dfe->dfe_tree->_.bin_exp.left, COL_DOTTED) &&
		  (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)
		   || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)))
		{
		  params[inx] = scalar_exp_generate (so->so_sc, colp_dfe->_.bin.right->dfe_tree, precompute);
		  colp_dfe->dfe_is_placed = DFE_GEN;
		  goto next_arg;
		}
	      else if (ST_P (colp_dfe->dfe_tree->_.bin_exp.right, COL_DOTTED) &&
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
	      if (ST_P (colp_dfe->dfe_tree->_.bin_exp.left, COL_DOTTED) &&
		  (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)
		   || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)))
		{
		  params[inx] = scalar_exp_generate (so->so_sc, colp_dfe->_.bin.right->dfe_tree, precompute);
		  colp_dfe->dfe_is_placed = DFE_GEN;
		  goto next_arg;
		}
	      else if (ST_P (colp_dfe->dfe_tree->_.bin_exp.right, COL_DOTTED) &&
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
	      if (ST_P (colp_dfe->dfe_tree->_.bin_exp.left, COL_DOTTED) &&
		  (!CASEMODESTRCMP (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)
		   || box_equal (name, colp_dfe->dfe_tree->_.bin_exp.left->_.col_ref.name)))
		{
		  params[inx] = scalar_exp_generate (so->so_sc, colp_dfe->_.bin.right->dfe_tree, precompute);
		  colp_dfe->dfe_is_placed = DFE_GEN;
		  goto next_arg;
		}
	      else if (ST_P (colp_dfe->dfe_tree->_.bin_exp.right, COL_DOTTED) &&
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
	cv_call (&blob_to_string_code, NULL, blob_to_string_func, ssl,
	  (state_slot_t **) /*list*/ sc_list (2, ssl, ssl_1));
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
	  cv_artm (precompute, box_identity, ssl, params[inx], NULL);
	  ssl->ssl_sqt = params[inx]->ssl_sqt;
	}
    }
  END_DO_BOX;

  setp_distinct_hash (sc, &setp, 0);
  setp.setp_ha->ha_op = HA_FILL;

  ts->ts_is_outer = ot->ot_is_outer;
  ts->ts_order_cursor = ssl_new_itc (sc->sc_cc);
    {
      NEW_VARZ (key_source_t, ks);
      ts->ts_order_ks = ks;
      ks->ks_key = setp.setp_ha->ha_key;
      ks->ks_out_slots = out_slots;
      ks->ks_out_cols = ks->ks_key->key_parts;
      ks->ks_from_temp_tree = setp.setp_ha->ha_tree;
      table_source_om (sc->sc_cc, ts);
      ks->ks_out_cols = out_cols;
    }
  cv_artm (precompute,box_identity,
      (state_slot_t *) setp.setp_keys->data,
      ssl_new_constant (sc->sc_cc, t_box_num (0)), NULL);
  cv_call (precompute, NULL, t_sqlp_box_id_upcase ("__reset_temp"), NULL,
      (state_slot_t **) sc_list (1, ssl_new_constant (sc->sc_cc, t_box_num ((ptrlong) setp.setp_ha))));
  cv_call (precompute,
      ssl_new_constant (sc->sc_cc,
	t_box_num ((ptrlong) setp.setp_ha)),
      tree->_.proc_table.proc, CV_CALL_PROC_TABLE,
      params);
  DO_BOX (state_slot_t *, ssl, inx, setp.setp_ha->ha_slots)
    {
      ssl_with_info (so->so_sc->sc_cc, ssl);
    }
  END_DO_BOX;
  setp.setp_reserve_ha = NULL;
  setp_node_free (&setp);

  ts->src_gen.src_after_test = sqlg_pred_body_1 (so, dt_dfe->_.sub.after_join_test, blob_to_string_code);
  return (data_source_t *) ts;
}

data_source_t *
sqlg_make_dt  (sqlo_t * so, df_elt_t * dt_dfe, ST **target_names, dk_set_t *pre_code)
{
  sql_comp_t * sc = so->so_sc;
  op_table_t * ot = dt_dfe->_.sub.ot;
  int n_values;
  int inx;
  query_t * qr;

  if (ST_P (ot->ot_dt, PROC_TABLE))
    {
      return sqlg_generate_proc_ts (so, dt_dfe, pre_code);
    }

  {
    SQL_NODE_INIT (subq_source_t, sqs, subq_node_input, subq_node_free);
    sqs->sqs_is_outer = ot->ot_is_outer;
    if (!target_names)
      target_names = sqlc_sel_names ((ST**) sqlp_union_tree_select (dt_dfe->_.sub.ot->ot_dt)->_.select_stmt.selection, dt_dfe->_.sub.ot->ot_new_prefix);
    n_values = BOX_ELEMENTS (target_names);
    sqs->sqs_out_slots = (state_slot_t **) dk_alloc_box (n_values * sizeof (caddr_t),
							 DV_ARRAY_OF_LONG);
    DO_BOX (ST *, target_name, inx, target_names)
      {
	if (target_name)
	  {
	    sqs->sqs_out_slots[inx] = sqlg_dfe_ssl (so, sqlo_df (so, target_name));
	  }
      }
    END_DO_BOX;
    qr = sqlg_dt_query (so, dt_dfe, NULL, target_names);
    sqs->sqs_query = qr;
    qr->qr_select_node->src_gen.src_input = (qn_input_fn) select_node_input_subq;
    sqs->sqs_after_join_test = sqlg_pred_body (so, dt_dfe->_.sub.after_join_test);
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


data_source_t *
sqlg_set_stmt (sqlo_t * so, df_elt_t * qexp, ST ** target_names)
{
  ST * tree = qexp->dfe_tree;
  sql_comp_t * sc = so->so_sc;
  setp_node_t *setp_left, *setp_right;
  query_t *left_qr, *right_qr;
  char is_best = 0;

  select_node_t *sel = NULL;
  caddr_t *cols = tree->_.set_exp.cols;
  comp_context_t *cc = sc->sc_cc;
  SQL_NODE_INIT (union_node_t, un, union_node_input, union_node_free);

  if (BOX_ELEMENTS (tree) > 4)
    is_best = (char) tree->_.set_exp.is_best;

  sqlg_qexp_target_corresponding (so, target_names, qexp);
  /* XXX: if the left or right are unions again then it causes a GPF because it isn't a DT */
  left_qr = sqlg_dt_query (so, qexp->_.qexp.terms[0], NULL, target_names);
  right_qr = sqlg_dt_query (so, qexp->_.qexp.terms[1], NULL, target_names);
  dk_set_push (&sc->sc_cc->cc_query->qr_subq_queries, left_qr);
  dk_set_push (&sc->sc_cc->cc_query->qr_subq_queries, right_qr);

  sel = left_qr->qr_select_node;
  if (!ST_P (tree, UNION_ST) && !ST_P (tree, UNION_ALL_ST))
    {
      dk_set_push (&un->uni_successors, (void *) left_qr);
      dk_set_push (&un->uni_successors, (void *) right_qr);
    }
  else
    {
      dk_set_push (&un->uni_successors, (void *) right_qr);
      dk_set_push (&un->uni_successors, (void *) left_qr);
    }
  if (ST_P (tree, UNION_ALL_ST))
    {
      qr_replace_node (right_qr,
	  (data_source_t *) right_qr->qr_select_node,
	  (data_source_t *) sel);
    }
  else
    {
      setp_left = setp_node_keys (sc, sel, cols);
      sqlg_setp_keys (so, setp_left, 0, (long) qexp->dfe_arity);
      setp_left->setp_temp_key = sqlc_new_temp_key_id (sc);
      setp_left->src_gen.src_continuations = CONS (sel, NULL);
      qr_replace_node (left_qr,
	  (data_source_t *) sel, (data_source_t *) setp_left);

      if (ST_P (tree, UNION_ST))
	{
	  qr_replace_node (right_qr,
	      (data_source_t *) right_qr->qr_select_node,
	      (data_source_t *) setp_left);
	}
      else
	{
	  setp_right = setp_node_keys (sc, sel, cols);
	  sqlg_setp_keys (so, setp_right, 0, (long) qexp->dfe_arity);
	  setp_right->setp_temp_key = setp_left->setp_temp_key;
	  setp_right->setp_ha = setp_left->setp_ha;
	  qr_replace_node (right_qr,
	      (data_source_t *) right_qr->qr_select_node,
	      (data_source_t *) setp_right);
	  setp_left->setp_set_op = (int) tree->type;
	}
    }
  cc->cc_query->qr_head_node = (data_source_t *) un;
  un->uni_nth_output = ssl_new_inst_variable (sc->sc_cc, "nth", DV_LONG_INT);
  cc->cc_query->qr_select_node = sel;
  cc->cc_query->qr_bunion_node = is_best ? un : NULL;
  DO_SET (query_t *, u_qr, &un->uni_successors)
  {
    cc->cc_query->qr_nodes = dk_set_conc (dk_set_copy (u_qr->qr_nodes),
	cc->cc_query->qr_nodes);
    u_qr->qr_bunion_reset_nodes = u_qr->qr_nodes;
    u_qr->qr_nodes = NULL;

    u_qr->qr_is_bunion_term = is_best;
  }
  END_DO_SET ();
#if 0
  if (!sc->sc_super)
    sel->src_gen.src_input = (qn_input_fn) select_node_input;
#endif
#if UNIVERSE
  /* The union may have acquired remote queries so make it always mixed. */
  if (cc->cc_query->qr_remote_mode == QR_LOCAL)
    cc->cc_query->qr_remote_mode = QR_MIXED;
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
	  NEW_VARZ (subq_pred_t, subp);
	  dfe_unit_col_loci (dfe);
	  subp->subp_query = sqlg_dt_query (so, dfe, NULL, NULL);
	  dk_set_push (&sc->sc_cc->cc_query->qr_subq_queries, subp->subp_query);
	  subp->subp_query->qr_select_node->src_gen.src_input = (qn_input_fn) select_node_input_subq;
	  subp->subp_type = EXISTS_PRED;
	  ins->_.pred.cmp =subp;

	}
	break;
      }
    case DFE_VALUE_SUBQ:
      {
	query_t * qr = sqlg_dt_query (so, dfe, NULL, (ST **) t_list (1, dfe->dfe_tree)); /* this is to prevent
									  assigment of NULL to constant ssl*/
	state_slot_t * ssl = qr->qr_select_node->sel_out_slots[0];
	df_elt_t * org_dfe = sqlo_df (so, dfe->dfe_tree); /* the org one, not a layout copy is used to associate the ssl to the code */
	org_dfe->dfe_ssl = ssl;
	qr->qr_select_node->src_gen.src_input = (qn_input_fn) select_node_input_subq;
	dk_set_push (&sc->sc_cc->cc_query->qr_subq_queries, qr);
	cv_subq_qr (code, qr);
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
	  sqlg_dfe_code (so, body[inx], code, succ, fail, unk);
	}
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
  return (code_to_cv (so->so_sc, code));
}


code_vec_t
sqlg_pred_body (sqlo_t * so, df_elt_t **  body)
{
  return sqlg_pred_body_1 (so, body, NULL);
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
  if (res && !out && (
	dfe->dfe_type == DFE_BOP ||
	dfe->dfe_type == DFE_CALL
	))
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
  search_spec_t **next_spec = &setp->setp_insert_specs;


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
}


void
sqlg_setp_keys (sqlo_t * so, setp_node_t * setp, int force_gb, long n_rows)
{
  sql_comp_t * sc = so->so_sc;
  hash_area_t * ha;
  setp_distinct_hash (sc, setp, n_rows);
  ha = setp->setp_ha;
  ha->ha_allow_nulls = 1;
  ha->ha_op = (force_gb || setp->setp_gb_ops) ? HA_GROUP : HA_ORDER;
  if (force_gb || !setp->setp_gb_ops)
    setp_key_insert_spec (setp);
}


void
sqlg_setp_append (data_source_t ** head, setp_node_t * setp)
{
  table_source_t * last = (table_source_t *) sql_node_last (*head);
  if (IS_TS_NODE (last)
      && !last->src_gen.src_after_code
      && !last->ts_inx_op
      && !last->src_gen.src_after_test
      && !setp->src_gen.src_pre_code
      && !last->ts_is_outer
      && !setp->setp_any_user_aggregate_gos)
    {
      key_source_t * ks = last->ts_main_ks ? last->ts_main_ks : last->ts_order_ks;
      ks->ks_setp = setp;
    }
  else
    sql_node_append (head, (data_source_t *) setp);
}


hash_area_t *
sqlg_distinct_fun_ref_col (sql_comp_t * sc, state_slot_t * data, dk_set_t prev_keys, long n_rows)
{
  setp_node_t setp;
  memset (&setp, 0, sizeof (setp));
  setp.src_gen.src_query = sc->sc_cc->cc_query;
  setp.setp_keys = dk_set_copy (prev_keys);
  dk_set_push (&setp.setp_keys, (void*) data);
  setp_distinct_hash (sc, &setp, n_rows);
  return (setp.setp_ha);
}


void sqlg_find_aggregate_sqt (dbe_schema_t *schema, sql_type_t *arg_sqt, ST *fref, sql_type_t *res_sqt)
{
  user_aggregate_t *ua;
  switch (fref->_.fn_ref.fn_code)
    {
    case AMMSC_COUNT: case AMMSC_COUNTSUM:
      res_sqt->sqt_dtp = DV_LONG_INT;
      res_sqt->sqt_non_null = 1;
      break;
    case AMMSC_USER:
      ua = (user_aggregate_t *)(unbox(fref->_.fn_ref.user_aggr_addr));
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
    default: GPF_T;
    }
}

dk_set_t always_null_arr_gen (sql_comp_t* sc, dk_set_t code, ST ** etalon, ST ** subseq)
{
    int inx;
    dk_set_t ns = 0;
    DO_BOX (ST *, item, inx, etalon)
      {
	int inx2;
        state_slot_t *ssl;
	DO_BOX (ST *, item2, inx2, subseq)
	  {
	    if (item == item2)
	      break;
	  }
	END_DO_BOX;
	if (inx2 != BOX_ELEMENTS (subseq))
	  continue;
        ssl = scalar_exp_generate (sc, item->_.o_spec.col, &code);
	dk_set_push (&ns, ssl);
      }
    END_DO_BOX;
    return ns;
}

state_slot_t *
sqlg_alias_or_assign (sqlo_t * so, state_slot_t * ext, state_slot_t * source, dk_set_t * code);

void
sqlg_make_sort_nodes (sqlo_t * so, data_source_t ** head, ST ** order_by,
    state_slot_t ** ssl_out, df_elt_t * tb_dfe, int is_gb, dk_set_t o_code, df_elt_t *oby)
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
  int is_not_one_gb = (is_gb && (BOX_ELEMENTS(group_by)>1));
  NEW_VARZ (fun_ref_node_t, fref_node);

  SQL_NODE_INIT_NO_ALLOC (fun_ref_node_t, fref_node, fun_ref_node_input, fun_ref_free);

  if (is_not_one_gb)
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
      order_by = group_by[ginx++];
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
  nth_part = 0;
  if (is_not_one_gb)
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
	  bitmap_index = ssl_new_constant (so->so_sc->sc_cc,
bitmap_index_box);
	  reader_code = 0;
	  dk_free_box (one);
	  dk_free_box (bitmap_index_box);
	  cv_call (&reader_code, NULL, "__GROUPING_SET_BITMAP", NULL,
	      (state_slot_t**) /*list*/ sc_list (2, bitmap_index, bitmap));
	}
      always_null = always_null_arr_gen (sc, code, group_by[0], order_by);
    }


  /* memset (fref_node, 0, sizeof (fun_ref_node_t)); */
  setp->setp_temp_key = sqlc_new_temp_key_id (sc);
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
	      sqlc_copy_ssl_if_constant (sc, &ssl);
	      col_dfe->dfe_ssl = ssl;
	    }
	  else
	    sqlc_copy_ssl_if_constant (sc, &ssl);
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
	  state_slot_t * arg;
	  state_slot_t ** ua_arglist;
	  state_slot_t ** acc_args;
	  user_aggregate_t *ua = (user_aggregate_t *)(unbox(fref->_.fn_ref.user_aggr_addr));
          int arglist_len;
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
	  sqlg_find_aggregate_sqt (sc->sc_cc->cc_schema, &(arg->ssl_sqt), fref, &(aggregate->ssl_sqt));
	  if (!dk_set_member (out_slots, aggregate))
	    {
	      go = (gb_op_t *) dk_alloc (sizeof (gb_op_t));
	      memset (go, 0, sizeof (gb_op_t));
	      go->go_op = (int) fref->_.fn_ref.fn_code;
	      go->go_old_val = sqlc_new_temp (sc, "gb_tmp", aggregate->ssl_sqt.sqt_dtp);
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
		      go->go_ua_arglist_len = arglist_len;
		      go->go_ua_arglist = ua_arglist;
		      arg = go->go_old_val;
		      acc_args[0] = go->go_old_val;
		      cv_call (&code, NULL, t_box_copy (ua->ua_init.uaf_name), ret, (state_slot_t **) /*list*/ sc_list (1, go->go_old_val));
		      go->go_ua_init_setp_call = (instruction_t *)box_copy_tree((box_t) code->data);
		      cv_call (&code, NULL, t_box_copy (ua->ua_acc.uaf_name), ret, acc_args);
		      go->go_ua_acc_setp_call = (instruction_t *)box_copy_tree((box_t) code->data);
		      break;
		    }
		  default: ;
		    arg->ssl_sqt = aggregate->ssl_sqt;
		}
	      if (fref->_.fn_ref.all_distinct)
		{
		  go->go_distinct = arg;	/* It's not AMMSC_USER because 1 == fn_ref.all_distinct */
		  go->go_distinct_ha = sqlg_distinct_fun_ref_col (sc, arg, setp->setp_keys, (long) tb_dfe->dfe_arity);
		  setp->setp_any_distinct_gos = 1;
		  dk_set_push (&fref_node->fnr_distinct_ha, (caddr_t) go->go_distinct_ha);
		  if (go->go_op == AMMSC_COUNT)
		    arg = ssl_new_constant (sc->sc_cc, box_num (1));
		}
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
	      sqlc_copy_ssl_if_constant (sc, &ssl_out[inx]);
	      if (-1 == nth_key)
		{
		  if (!dk_set_member (out_slots, ssl_out[inx]))
		    {
		      NCONCF1 (out_cols, nth_part);
		      NCONCF1 (out_slots, ssl_out[inx]);
		      NCONCF1 (setp->setp_dependent, out);
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

	  term_found = 0;
	  exp_dfe = sqlo_df_elt (so, exp);
	  if (exp_dfe && tb_dfe->_.sub.dt_out && tb_dfe->_.sub.dt_out[inx])
	    dfe_list_gb_dependant (so, exp_dfe, NULL, oby->dfe_super, &pre, &out1, &term_found);
	}
      END_DO_BOX;
    }
  DO_SET (df_elt_t *, dep_dfe, &out1)
    {
      state_slot_t *out = dep_dfe->dfe_ssl;
      sqlc_copy_ssl_if_constant (sc, &dep_dfe->dfe_ssl);
      if (out)
	{
	  ptrlong nth_key = dk_set_position (setp->setp_keys, (caddr_t) out);
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
  sqlg_setp_keys (so, setp, (group_by && !setp->setp_gb_ops) ? 1 : 0, (long) tb_dfe->dfe_arity);
  read_node = sqlc_make_sort_out_node (sc, out_cols, out_slots, always_null);
  dk_set_free (out_cols);
#if 1
  out_cols = 0;
  /* setp->src_gen.src_pre_code = code_to_cv (sc, code); */
#endif
  if (!is_gb && SEL_TOP (dt) && !dfe_ot(tb_dfe)->ot_oby_dfe->dfe_next)
    {
      ST * top = SEL_TOP (dt);
      int inx;
      setp->setp_top = scalar_exp_generate (sc, top->_.top.exp, &code);
      if (top->_.top.skip_exp)
	{
	  setp->setp_top_skip = scalar_exp_generate (sc, top->_.top.skip_exp, &code);
	}
      else
	setp->setp_top_skip = NULL;
      setp->setp_row_ctr = ssl_new_variable (sc->sc_cc, "rowctr", DV_LONG_INT);
      setp->setp_last_vals = (state_slot_t **) dk_set_to_array (setp->setp_keys);
      _DO_BOX (inx, setp->setp_last_vals)
	{
	  setp->setp_last_vals[inx] = sqlc_new_temp (sc, "top_last", DV_UNKNOWN);
	}
      END_DO_BOX;
      setp->setp_last = ssl_new_itc (sc->sc_cc);
      setp->setp_ties = (int) top->_.top.ties;
      if (!top->_.top.ties)
	{
	  setp->setp_sorted = sqlc_new_temp (sc, "sorted", DV_UNKNOWN);
	  DO_SET (state_slot_t *, setp_ssl, &setp->setp_keys)
	    {
	      if (SSL_CONSTANT == setp_ssl->ssl_type)
		{
		  setp_ssl = ssl_new_variable (sc->sc_cc, "__sort_data", DV_UNKNOWN);
		  sqlg_alias_or_assign (so, setp_ssl, ((state_slot_t *)(iter->data)), &code);
		  iter->data = setp_ssl;
		}
	    }
	  END_DO_SET ();
	  DO_SET (state_slot_t *, setp_ssl, &setp->setp_dependent)
	    {
	      if (SSL_CONSTANT == setp_ssl->ssl_type)
		{
		  setp_ssl = ssl_new_variable (sc->sc_cc, "__sort_data", DV_UNKNOWN);
		  sqlg_alias_or_assign (so, setp_ssl, ((state_slot_t *)(iter->data)), &code);
		  iter->data = setp_ssl;
		}
	    }
	  END_DO_SET ();
	}
      if (SEL_IS_DISTINCT (dt))
	sqlc_add_distinct_node (sc, head, (state_slot_t **) t_list_to_array (out_slots), (long) tb_dfe->dfe_arity);
      dt->_.select_stmt.top = NULL;
    }
  setp->src_gen.src_pre_code = code_to_cv (sc, code);
  setp->setp_flushing_mem_sort = sqlc_new_temp (sc, "flush", DV_UNKNOWN);
  setp->setp_keys_box = (state_slot_t **) dk_set_to_array (setp->setp_keys);
  setp->setp_dependent_box = (state_slot_t **) dk_set_to_array (setp->setp_dependent);
  if (is_not_one_gb)
    {
      SQL_NODE_INIT (end_node_t, e, end_node_input, NULL);
      dk_set_push(&setps->gsu_cont, setp);
      dk_set_push(&setps_set, setp);
      dk_set_push(&readers->gsu_cont, read_node);
      sql_node_append ( (data_source_t**) &e, (data_source_t*) e_last);
      sql_node_append ( &read_node, (data_source_t*) e);
      read_node->src_pre_code = code_to_cv (sc, reader_code);
    }
  else
    {
      sqlg_setp_append (head, setp);
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
  if(is_not_one_gb)
    readers->gsu_cont = dk_set_nreverse (readers->gsu_cont);
  fref_node->fnr_setps = setps_set;
  fref_node->fnr_select = * head;
  *head = (data_source_t *) fref_node;
}

caddr_t bif_grouping (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong curr_bitmap = bif_long_arg (qst, args, 1, GROUPING_FUNC);
  ptrlong et_bitmap_idx = bif_long_arg (qst, args, 2, GROUPING_FUNC);

  if (!et_bitmap_idx)
    return box_num (0);

  return box_num (!(QST_INT(qst,et_bitmap_idx) & curr_bitmap));
}

caddr_t bif_grouping_set_bitmap (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
    ptrlong bitmap_idx = bif_long_arg (qst, args, 0, GROUPING_SET_FUNC);
    ptrlong curr_bitmap = bif_long_arg (qst, args, 1, GROUPING_SET_FUNC);
    if (!IS_POINTER (QST_INT (qst, bitmap_idx)))
      QST_INT (qst, bitmap_idx) = curr_bitmap;
    return 0;
}

static
int st_compare (const void * _st1, const void * _st2)
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

static
void st_sort (ST ** arr)
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
      if (!ST_P (col, COL_DOTTED))
        GPF_T;
      DO_BOX (ST *, st, inx, sorted_etalon)
        {
	  ST * c = st->_.o_spec.col;
	  if ( (c->_.col_ref.prefix && !col->_.col_ref.prefix) ||
               (!c->_.col_ref.prefix && col->_.col_ref.prefix) ||
	       strcmp (c->_.col_ref.prefix, col->_.col_ref.prefix) )
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
sqlg_simple_fun_ref (sqlo_t * so, data_source_t ** head, df_elt_t * tb_dfe,
		     dk_set_t cum_code)
{
  dk_set_t post_fref_code = NULL;

  sql_comp_t * sc = so->so_sc;
  op_table_t * ot = tb_dfe->_.sub.ot;

  sc->sc_fun_ref_temps = NULL;
  sc->sc_fun_ref_defaults = NULL;
  sc->sc_fun_ref_default_ssls = NULL;
  sc->sc_cc->cc_any_result_ind = 0;

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

    last->src_count = sc->sc_cc->cc_any_result_ind;
    last->src_after_code = code_to_cv (so->so_sc, cum_code);
    fref->fnr_select = * head;
    fref->src_gen.src_after_code = code_to_cv (sc, post_fref_code);
    fref->fnr_is_any = sc->sc_cc->cc_any_result_ind;
    fref->fnr_default_values = dk_set_nreverse (sc->sc_fun_ref_defaults);
    fref->fnr_default_ssls = dk_set_nreverse (sc->sc_fun_ref_default_ssls);
    fref->fnr_temp_slots = sc->sc_fun_ref_temps;
    *head = (data_source_t *) fref;
  }
}


data_source_t *
sqlg_oby_node (sqlo_t * so, data_source_t ** head, df_elt_t * oby, df_elt_t * dt_dfe,
	       dk_set_t pre_code)
{
  sql_comp_t * sc = so->so_sc;
  ST * tree = dt_dfe->dfe_tree;
  state_slot_t ** ssl_out = (state_slot_t **) t_box_copy ((caddr_t) tree->_.select_stmt.selection);
  int inx;
  DO_BOX (ST *, exp, inx, tree->_.select_stmt.selection)
    {
      if (dt_dfe->_.sub.dt_out && dt_dfe->_.sub.dt_out[inx])
	ssl_out[inx] = scalar_exp_generate (sc, exp, &pre_code);
      else
	ssl_out[inx] = NULL;
    }
  END_DO_BOX;
  sqlg_make_sort_nodes (so, head, tree->_.select_stmt.table_exp->_.table_exp.order_by,
			ssl_out,  dt_dfe, 0, pre_code, oby);
  return sql_node_last (*head);
}


data_source_t *
sqlg_group_node (sqlo_t * so, data_source_t ** head, df_elt_t * group, df_elt_t * dt_dfe,
	       dk_set_t pre_code)
{
  data_source_t * read_node;
  op_table_t * ot = dt_dfe->_.sub.ot;
  ST * tree = dt_dfe->_.sub.ot->ot_dt;
  ST * texp = tree->_.select_stmt.table_exp;
  if (ot->ot_fun_refs && ! texp->_.table_exp.group_by)
    sqlg_simple_fun_ref (so, head,
			 dt_dfe, pre_code);
  else
    sqlg_make_sort_nodes (so, head, (ST**) tree->_.select_stmt.table_exp->_.table_exp.group_by_full,
			  NULL,  dt_dfe, 1, pre_code, group);
  read_node = sql_node_last (*head);
  read_node->src_after_test = sqlg_pred_body (so, group->_.setp.after_test);
  return read_node;
}


int
sqlg_dtp_coerce (sql_type_t *res_sqt, sql_type_t *arg_sqt)
{
  if (arg_sqt->sqt_dtp == DV_UNKNOWN)
    return 0;
  if (res_sqt->sqt_dtp == DV_UNKNOWN)
    {
      memcpy (res_sqt, arg_sqt, sizeof (sql_type_t));
      return 1;
    }

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
		      if (arg_sqt->sqt_scale || arg_sqt->sqt_precision >
			  res_sqt->sqt_precision ? res_sqt->sqt_precision : 5)
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
		      if (arg_sqt->sqt_scale || arg_sqt->sqt_precision >
			  res_sqt->sqt_precision ? res_sqt->sqt_precision : 9)
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
		  	  if (res_sqt->sqt_precision <
			      arg_sqt->sqt_precision ? arg_sqt->sqt_precision : 4)
			    {
			      res_sqt->sqt_precision = NUMERIC_MAX_PRECISION;
			      return 1;
			    }
			}
		      else if (res_sqt->sqt_precision <
			  arg_sqt->sqt_precision ? arg_sqt->sqt_precision : 4)
			{
			  memset (res_sqt, 0, sizeof (sql_type_t));
			  res_sqt->sqt_dtp = DV_SHORT_INT;
			  return 1;
			}
		      return 0;
		  case DV_LONG_INT:
		      if (res_sqt->sqt_scale)
			{
		  	  if (res_sqt->sqt_precision <
			      arg_sqt->sqt_precision ? arg_sqt->sqt_precision : 8)
			    {
			      res_sqt->sqt_precision = NUMERIC_MAX_PRECISION;
			      return 1;
			    }
			}
		      else if (res_sqt->sqt_precision <
			  arg_sqt->sqt_precision ? arg_sqt->sqt_precision : 8)
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
		      if (res_sqt->sqt_precision < arg_sqt->sqt_precision ||
			  res_sqt->sqt_scale < arg_sqt->sqt_scale)
			{
			  res_sqt->sqt_precision = res_sqt->sqt_precision < arg_sqt->sqt_precision ?
			      arg_sqt->sqt_precision : res_sqt->sqt_precision;
			  res_sqt->sqt_precision = res_sqt->sqt_scale < arg_sqt->sqt_scale ?
			      arg_sqt->sqt_scale : res_sqt->sqt_scale;
			  return 1;
			}
		      else
			return 0;
	          case DV_WIDE:
	          case DV_LONG_WIDE:
		  case DV_STRING:
		      if (!arg_sqt->sqt_precision || arg_sqt->sqt_precision >
			  res_sqt->sqt_precision + res_sqt->sqt_scale + 1)
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
      default:
	  return 0;
    }
}


state_slot_t *
sqlg_alias_or_assign (sqlo_t * so, state_slot_t * ext, state_slot_t * source, dk_set_t * code)
{
  /* all slots referencing the inside position become aliased to reference the outside position.
   * in this way an arbitrary depth of subqs get referred to the desired output.  If not possible,
   * due to constants or ref params, then an assignment is generated */
  /* this will always copy the ssls instead of aliasing them because of some UNIONS with constant
     columns in their select list. That may be fine-tuned later  */
  if (0
      && !ssl_is_special (ext)
      && !ssl_is_special (source))
    {
      DO_SET (state_slot_t *, any_ssl,  &so->so_sc->sc_cc->cc_super_cc->cc_query->qr_state_map)
	{
	  if (any_ssl->ssl_index == source->ssl_index)
	    {
	      ext->ssl_sqt = source->ssl_sqt;
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
      cv_artm (code, box_identity, ext, source, NULL);
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
	  if (target_names)
	    {
	      state_slot_t * target_ssl = sqlg_dfe_ssl (so, sqlo_df (so, target_names[inx]));
	      res[inx] = sqlg_alias_or_assign (so, target_ssl, res[inx], &code);
	    }
	}
      else
	res[inx] = NULL;
    }
  END_DO_BOX;
  if (code)
    {
      if (last_qn && !last_qn->src_after_code)
	last_qn->src_after_code = code_to_cv (sc, code);
      else
	{
	  SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
	  en->src_gen.src_pre_code = code_to_cv (sc, code);
	  sql_node_append (head, (data_source_t*) en);
	}
    }
  if (SEL_IS_DISTINCT (tree))
    sqlc_add_distinct_node (sc, head, res, (long) dfe->dfe_arity);
  return res;
}


void
sqlg_select_node (sqlo_t * so, df_elt_t * dfe, data_source_t ** head,
		  dk_set_t code, ST ** target_names, data_source_t *last_qn)
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
  sc->sc_cc->cc_query->qr_lock_mode = sel->sel_lock_mode;
  sqlc_select_top (sc, sel, tree, &code);

  sel->sel_out_slots = sqlg_handle_select_list (so, dfe, head, code, last_qn, target_names);

  sc->sc_cc->cc_query->qr_no_co_if_no_cr_name = 1;

/*  dk_free_tree ((caddr_t) new_sel);*/
  sql_node_append (head, (data_source_t *) sel);

  sqlc_select_unique_ssls (sc, sel, NULL);
  sqlc_select_as (sel->sel_out_slots, (caddr_t **) sc->sc_select_as_list);
  qr_add_current_of_output (sc->sc_cc->cc_query);
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


query_t *
sqlg_dt_query_1 (sqlo_t * so, df_elt_t * dt_dfe, query_t * ext_query,
	       ST ** target_names, state_slot_t ***sel_out_ret)
{
  dk_set_t generated_loci = NULL;
  data_source_t * qn = NULL, *last_qn = NULL;
  dk_set_t pre_code = NULL;
  df_elt_t * group_dfe = NULL, * order_dfe = NULL, * dfe;
  data_source_t * head = NULL;
  sql_comp_t * sc = so->so_sc;
  query_t * old_qr = sc->sc_cc->cc_query;
  query_t * qr = ext_query;
  int was_setp = 0;
  if (!qr)
    {
      qr = (query_t*) dk_alloc (sizeof (query_t));
      memset (qr, 0, sizeof (query_t));
    }
  sc->sc_cc->cc_query = qr;
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &sel_out_ret, 1000))
    sqlc_error (so->so_sc->sc_cc, ".....", "Stack Overflow");
  if (DK_MEM_RESERVE)
    sqlc_error (so->so_sc->sc_cc, ".....", "Out of memory");

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
	  if (IS_BOX_POINTER (dfe->dfe_locus))
	    {
	      if (dk_set_member (generated_loci, (void*)dfe->dfe_locus))
		continue;
	      if (DFE_TABLE == dfe->dfe_type || DFE_DT == dfe->dfe_type)
		{
		  data_source_t * rts = sqlg_locus_rts (so, dfe, pre_code);
		  t_set_push (&generated_loci, (void*) dfe->dfe_locus);
		  pre_code = NULL;
		  if (DFE_TABLE == dfe->dfe_type && HR_FILL == dfe->_.table.hash_role)
		    rts = sqlg_hash_filler (so, dfe, rts);
		  last_qn = rts;
		  sql_node_append (&head, rts);
		}
	      else if (DFE_VALUE_SUBQ == dfe->dfe_type)
		{
		  /* a value subq on a remote generates only if there is nothing else in the same locus. Otherwise it is assumed that the subq will generate as a rresult of reference from the locus top */
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
		    if (IS_POINTER (name) && !stricmp (name, GROUPING_FUNC) &&
    		        so->so_sc->sc_grouping )
		      {
		        ptrlong bitmap = 0;
			dfe->dfe_tree->_.call.params[2] = (ST*) t_box_num (so->so_sc->sc_grouping->ssl_index);
                        make_grouping_bitmap_set (NULL, dfe->dfe_tree->_.call.params[0],
			    so->so_sc->sc_groupby_set, &bitmap);
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
		      last_qn = qn = sqlg_make_ts (so, dfe);
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
		}
	      else
		{
		  last_qn = qn = sqlg_set_stmt (so, dfe, target_names);
		  was_setp = 1;
		}
	      if (DFE_TABLE == dfe->dfe_type && HR_FILL == dfe->_.table.hash_role)
		qn = sqlg_hash_filler (so, dfe, qn);
	      qn->src_pre_code = code_to_cv (so->so_sc, pre_code);
	      pre_code = NULL;
	      sql_node_append (&head, qn);
	      break;
	    case DFE_GROUP:
	      group_dfe = dfe;
	      last_qn = sqlg_group_node (so, &head, dfe, dt_dfe, pre_code);
	      pre_code = NULL;
	      break;
	    case DFE_ORDER:
	      order_dfe = dfe;
	      last_qn = sqlg_oby_node (so, &head, order_dfe, dt_dfe, pre_code);
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
	  *sel_out_ret = sqlg_handle_select_list (so, dt_dfe, &head,
	      pre_code, last_qn, target_names);
	}
      else if (!was_setp)
	sqlg_select_node (so, dt_dfe, &head, pre_code, target_names, last_qn);
      pre_code = NULL;
      break;

    default:
      SQL_GPF_T1 (so->so_sc->sc_cc, "only a dfe_dt is allowed at top for sqlg");
    }
  qr->qr_head_node = head;
  sc->sc_cc->cc_query = old_qr;
  if (!ext_query)
    qr_set_local_code_and_funref_flag (qr);
  return qr;
}


query_t *
sqlg_dt_query (sqlo_t * so, df_elt_t * dt_dfe, query_t * ext_query,
	       ST ** target_names)
{
  return sqlg_dt_query_1 (so, dt_dfe, ext_query, target_names, NULL);
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
  df_elt_t * org_dfe;
  int inx;
  df_elt_t * col_dfe;
  caddr_t tmp[7];
  caddr_t ref;
  ST * ref_box;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (dfe))
    {
      dfe_list_col_loci (dfe);
      return;
    }
  if (!IS_BOX_POINTER (dfe))
    return;
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
      dfe_list_col_loci ((df_elt_t *)dfe->_.table.join_test);
      dfe_list_col_loci ((df_elt_t *)dfe->_.table.after_join_test);
      dfe_list_col_loci ((df_elt_t *)dfe->_.table.vdb_join_test);
      if (dfe->_.table.hash_filler)
	{
	  if (IS_BOX_POINTER (dfe->dfe_locus))
	    dfe_filler_outputs (dfe);
	  dfe_unit_col_loci (dfe->_.table.hash_filler);
	  dfe->dfe_locus = LOC_LOCAL; /* remote table hash joined has the ref bnode as local and the filler as remote */
	}
      if (HR_FILL == dfe->_.table.hash_role)
	t_set_push (&dfe->dfe_sqlo->so_hash_fillers, (void*) dfe);
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
  dfe_unit_col_loci (dfe);
  DO_SET (df_elt_t *, filler, &so->so_hash_fillers)
    {
      sqlo_place_hash_filler (so, dfe, filler);
    }
  END_DO_SET();
  sqlg_dt_query_1 (so, dfe, so->so_sc->sc_cc->cc_query, NULL, sel_out_ret);
  if (IS_BOX_POINTER (dfe->dfe_locus))
    so->so_sc->sc_cc->cc_query->qr_remote_mode = QR_PASS_THROUGH;
  so->so_sc->sc_cc = outer_cc;
}

void
sqlg_top (sqlo_t * so, df_elt_t * dfe)
{
  sqlg_top_1 (so, dfe, NULL);
}


