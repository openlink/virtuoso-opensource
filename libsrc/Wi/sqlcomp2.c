/*
 *  sqlcomp2.c
 *
 *  $Id$
 *
 *  Dynamic SQL Compiler, part 2
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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
#include "sqlcomp.h"
#include "eqlcomp.h"
#include "lisprdr.h"
#include "xmlnode.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "statuslog.h"
#include "security.h"
#include "arith.h"
#include "sqlintrp.h"
#include "sqlo.h"
#include "sqlofn.h"
#include "sqltype.h"
#ifndef __SQL3_H
#define __SQL3_H
#include "sql3.h"
#endif
#include "sqlcstate.h"

sql_compile_state_t global_sqlc_st;

void
sqlc_mark_last_ts_in_join (sql_comp_t * sc, comp_table_t * ct)
{
  /* turn off ssl_refc from output cols of the rightmost in join */
#if 0 /* XXX: remove if not needed */
  table_source_t *ts = ct->ct_ts;
#endif
}
#define CT_IS_REMOTE(ct) 0

void
sqlc_opt_last_joins (sql_comp_t * sc)
{
  /* the last table and all tables right of the
     last table generating multiple rows need no
     reference counts for output cols */
  comp_table_t **cts = sc->sc_tables;
  int n_tables = BOX_ELEMENTS (cts);
  int inx = n_tables - 1;
  while (inx >= 0)
    {
      if (CT_IS_REMOTE (cts[inx])
	  || cts[inx]->ct_derived)
	break;
      sqlc_mark_last_ts_in_join (sc, cts[inx]);
      if (!cts[inx]->ct_ts->ts_is_unique)
	break;
      inx--;
    }
}


void
ts_set_local_code (table_source_t * ts, int is_cluster)
{
  key_source_t *ks = ts->ts_main_ks ? ts->ts_main_ks : ts->ts_order_ks;
  if (!ks || ks->ks_key->key_is_col)
    return; /* inx op that does not join main row */
  if (ts->src_gen.src_after_test
      && cv_is_local_1 (ts->src_gen.src_after_test, CV_NO_INDEX))
    {
      ks->ks_local_test = ts->src_gen.src_after_test;
      ts->src_gen.src_after_test = NULL;
    }
  if (ts->src_gen.src_after_code
      && !ts->src_gen.src_after_test
      && !ts->src_gen.src_query->qr_proc_vectored
      && cv_is_local_1 (ts->src_gen.src_after_code, 0)
      && !ts->ts_is_outer)
    {
      ks->ks_local_code = ts->src_gen.src_after_code;
      ts->src_gen.src_after_code = NULL;
    }
}


void
qr_set_local_code_and_funref_flag (query_t * qr)
{
  DO_SET (table_source_t *, ts, &qr->qr_nodes)
  {
    if (IS_TS_NODE (ts))
      {
	ts_set_local_code (ts, 0);

	if (!ts->src_gen.src_continuations
	    && !ts->src_gen.src_after_test
	    && !ts->src_gen.src_after_code)
	  {
	    if (ts->ts_main_ks)
	      ts->ts_main_ks->ks_is_last = 1;
	    else
	      ts->ts_order_ks->ks_is_last = 1;

	  }
      }
  }
  END_DO_SET ();
}


void
fun_ref_free (fun_ref_node_t * fref)
{
  DO_SET (caddr_t, def, &fref->fnr_default_values)
  {
    dk_free_box (def);
  }
  END_DO_SET ();
  dk_set_free (fref->fnr_default_values);
  dk_set_free (fref->fnr_default_ssls);
  dk_set_free (fref->fnr_temp_slots);
  dk_free_tree ((caddr_t) fref->fnr_hi_signature);
  dk_set_free (fref->fnr_distinct_ha);
  dk_set_free (fref->fnr_setps);
  clb_free (&fref->clb);
  dk_set_free (fref->fnr_select_nodes);
  dk_set_free (fref->fnr_prev_hash_fillers);
  dk_set_free (fref->fnr_cl_merge_temps);
}


void
sqlc_ct_derived_cols (sql_comp_t * sc, comp_table_t * ct)
{
  int inx;
  ST **selection;
  ST *query_exp = ct->ct_derived;
  /* the output names are those in the leftmost select of the union tree */
  if (ST_P (query_exp, PROC_TABLE))
    {
      sqlc_proc_table_cols (sc, ct);
      return;
    }
  while (!ST_P (query_exp, SELECT_STMT))
    query_exp = query_exp->_.bin_exp.left;
  selection = (ST **) (query_exp->_.select_stmt.selection);
  DO_BOX (ST *, as_exp, inx, selection)
  {
    if (1 || ST_P (as_exp, BOP_AS))
      {
	t_NEW_VARZ (col_ref_rec_t, crr);
	crr->crr_ct = ct;
	crr->crr_col_ref = (ST *) t_list (3, COL_DOTTED, ct->ct_prefix,
	    t_box_string (as_exp->_.as_exp.name));
	crr->crr_ssl = sqlc_new_temp (sc, as_exp->_.as_exp.name, DV_UNKNOWN);
	t_dk_set_append_1 (&ct->ct_out_crrs, (void *) crr);
	t_set_push (&sc->sc_col_ref_recs, (void *) crr);
      }
  }
  END_DO_BOX;
}


ST *
sqlc_ct_col_ref (comp_table_t * ct, char *col_name)
{
  if (ct->ct_prefix)
    return ((ST *) t_list (3, COL_DOTTED,
	    t_box_string (ct->ct_prefix), t_box_string (col_name)));
  else
    return ((ST *) t_list (3, COL_DOTTED,
	    t_box_string (ct->ct_table->tb_name), t_box_string (col_name)));
}


ST *
sql_tree_and (ST * tree, ST * cond)
{
  if (!cond)
    return tree;
  if (!tree)
    return cond;
  else
    {
      ST *res;
      BIN_OP (res, BOP_AND, cond, tree);
      return res;
    }
}


void
sqlc_natural_join_cond (sql_comp_t * sc, comp_table_t * left_ct,
    comp_table_t * right_ct, ST * tree)
{
  int inx;
  ST *ctree = NULL;
  ST *term;
  if (tree->_.join.is_natural
      || ST_P (tree->_.join.cond, JC_USING))
    {
      if (!tree->_.join.cond)
	{
	  if (!left_ct->ct_table || !right_ct->ct_table)
	    sqlc_new_error (sc->sc_cc, "37000", "SQ066",
		"Natural join only allowed between tables or views. No derived tables or joins.");
	  DO_SET (dbe_column_t *, col, &left_ct->ct_table->tb_primary_key->key_parts)
	    {
	      dbe_column_t * col2 = tb_name_to_column (right_ct->ct_table, col->col_name);
	      if (!IS_BLOB_DTP (col->col_sqt.sqt_dtp)
		  && col2 &&!IS_BLOB_DTP (col2->col_sqt.sqt_dtp))
		{

		  ST *r1 = sqlc_ct_col_ref (left_ct, col->col_name);
		  ST *r2 = sqlc_ct_col_ref (right_ct, col->col_name);
		  BIN_OP (term, BOP_EQ, r1, r2);
		  if (ctree)
		    {
		      ST *res;
		      BIN_OP (res, BOP_AND, term, ctree);
		      ctree = res;
		    }
		  else
		    ctree = term;
		}
	    }
	  END_DO_SET ();
	}
      else if (ST_P (tree->_.join.cond, JC_USING))
	{
	  DO_BOX (caddr_t, col_name, inx, tree->_.join.cond->_.usage.cols)
	    {
	      ST *r1 = sqlc_ct_col_ref (left_ct, col_name);
	      ST *r2 = sqlc_ct_col_ref (right_ct, col_name);
	      BIN_OP (term, BOP_EQ, r1, r2);
	      if (ctree)
		{
		  ST *res;
		  BIN_OP (res, BOP_AND, term, ctree);
		  ctree = res;
		}
	      else
		ctree = term;
	    }
	  END_DO_BOX;
	}
      else
	sqlc_new_error (sc->sc_cc, "37000", "SQ067",
	    "Explicit join condition not allowed in natural join");
      /*dk_free_tree (tree->_.join.cond);*/
      tree->_.join.cond = ctree;
    }
  else
    {
      if (J_CROSS == tree->_.join.type)
	{
	  tree->_.join.cond = NULL;
	}
      else if (!tree->_.join.cond || ST_P (tree->_.join.cond, JC_USING))
	sqlc_new_error (sc->sc_cc, "37000", "SQ068",
	    "Empty or USING join condition not allowed with non-natural join");
    }
}


void
sqlc_add_table_ref (sql_comp_t * sc, ST * tree, dk_set_t * res)
{
  switch (tree->type)
    {
    case TABLE_REF:
      sqlc_add_table_ref (sc, tree->_.table_ref.table, res);
      break;
    case TABLE_DOTTED:
      {
	dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema, tree->_.table.name);
	t_NEW_VARZ (comp_table_t, ct);
	if (!tb)
	  sqlc_new_error (sc->sc_cc, "42S02", "SQ069", "No table %s", tree->_.table.name);
	ct->ct_sc = sc;
	sqlc_table_used (sc, tb);
	ct->ct_name = tree->_.table.name;
	ct->ct_prefix = tree->_.table.prefix;
	ct->ct_table = tb;
	ct->ct_u_id = (oid_t) unbox (tree->_.table.u_id);
	ct->ct_g_id = (oid_t) unbox (tree->_.table.g_id);
	ct->ct_derived = (ST *)
	  t_box_copy_tree (sch_view_def (wi_inst.wi_schema, tb->tb_name));
	if (ct->ct_derived)
	  {
	    if (!sec_tb_check (tb, ct->ct_g_id, ct->ct_u_id, GR_SELECT))
	      sqlc_new_error (sc->sc_cc, "42000", "SQ070:SECURITY",
		  "Must have select privileges on view %s", tb->tb_name);
	    if (ST_P (ct->ct_derived, SELECT_STMT))
	      sqlc_union_constants (ct->ct_derived);
	    sqlc_ct_derived_cols (sc, ct);
	  }
	t_set_push (res, (void *) ct);
	break;
      }
    case JOINED_TABLE:
      {
	comp_table_t *right_ct, *left_ct;
	s_node_t *ptr, *iter;
	ST *j_right;
	if (OJ_RIGHT == tree->_.join.type)
	  {
	    ST * tmp = tree->_.join.left;
	    tree->_.join.left = tree->_.join.right;
	    tree->_.join.right = tmp;
	    tree->_.join.type = OJ_LEFT;
	  }
	sqlc_add_table_ref (sc, tree->_.join.left, res);
	left_ct = (comp_table_t *) (*res)->data;
	ptr = *res;
	sqlc_add_table_ref (sc, tree->_.join.right, res);
	right_ct = (comp_table_t *) (*res)->data;
	sqlc_natural_join_cond (sc, left_ct, right_ct, tree);
	j_right = tree->_.join.right;
	while (ST_P (j_right, TABLE_REF))
	  j_right = j_right->_.table_ref.table;
	if (ST_P (j_right, JOINED_TABLE) && (tree->_.join.type == OJ_LEFT || tree->_.join.type == OJ_FULL))
	  {
	    dk_set_t jt_preds = NULL;
	    sqlc_make_and_list (tree->_.join.cond, &jt_preds);
	    iter = *res;
	    t_set_push (&sc->sc_jt_preds, jt_preds);

	    while (iter != ptr)
	      {
		comp_table_t *ct = (comp_table_t *) iter->data;
		if (ct->ct_jt_tree)
		  sqlc_new_error (sc->sc_cc, "37000", "SQ153",
		      "outer joins in the joined table of another outer join not supported");
		ct->ct_jt_preds = jt_preds;
		ct->ct_jt_tree = tree;
		iter = iter->next;
	      }
	  }
	else
	  {
	    right_ct->ct_join_cond = sql_tree_and (right_ct->ct_join_cond, tree->_.join.cond);
	    sqlc_make_and_list (right_ct->ct_join_cond, &right_ct->ct_join_preds);
	    if (tree->_.join.type == OJ_LEFT || tree->_.join.type == OJ_FULL)
	      right_ct->ct_is_outer = 1;
	  }
	break;
      }
    case DERIVED_TABLE:
      {
	t_NEW_VARZ (comp_table_t, ct);
	ct->ct_sc = sc;
	ct->ct_name = "";
	ct->ct_prefix = tree->_.table_ref.range;
	ct->ct_table = NULL;
	ct->ct_derived =
	  (ST *) t_box_copy_tree ((caddr_t) tree->_.table_ref.table);
	sqlc_ct_derived_cols (sc, ct);
	t_set_push (res, (void *) ct);
	break;
      }
    }
}

void
sqlc_table_ref_list (sql_comp_t * sc, ST ** refs)
{
  int inx;
  dk_set_t cts = NULL;
  DO_BOX (ST *, ref, inx, refs)
  {
    sqlc_add_table_ref (sc, ref, &cts);
  }
  END_DO_BOX;
  sc->sc_tables = (comp_table_t **) t_list_to_array (dk_set_nreverse (cts));
}


void
sqlc_table_ref (sql_comp_t * sc, ST * ref)
{
  dk_set_t cts = NULL;
  sqlc_add_table_ref (sc, ref, &cts);
  sc->sc_tables = (comp_table_t **) t_list_to_array (dk_set_nreverse (cts));
}


void
sqlc_select_strip_as (ST ** selection, caddr_t *** as_list, int keep)
{
  caddr_t **as = (caddr_t **) t_box_copy ((caddr_t) selection);
  int inx;
  memset (as, 0, box_length ((caddr_t) as));
  DO_BOX (ST *, exp, inx, selection)
  {
    if (ST_P (exp, BOP_AS))
      {
	if (!keep)
	  {
	    as[inx] = (caddr_t *) exp;
	    selection[inx] = exp->_.bin_exp.left;
	    exp->_.bin_exp.left = NULL;
	  }
	else
	  as[inx] = (caddr_t *) t_box_copy_tree ((caddr_t) exp);
      }
  }
  END_DO_BOX;
  *as_list = as;
}


void
sqlc_select_unique_ssls (sql_comp_t * sc, select_node_t * sel, dk_set_t *code_set)
{
  /* make sure out slots do not contain duplicates so that each
   * may be separately aliased w/ AS */
  int inx, inx2;
  DO_BOX (state_slot_t *, ssl,  inx, sel->sel_out_slots)
    {
      if (ssl)
	{
	  for (inx2 = 0; inx2 < inx; inx2++)
	    {
	      if (ssl == sel->sel_out_slots[inx2])
		{
		  if (!code_set)
		    sel->sel_out_slots[inx] = ssl_copy (sc->sc_cc, ssl);
		  else
		    {
		      sel->sel_out_slots[inx] = sqlc_new_temp (sc, ssl->ssl_name, ssl->ssl_dtp);
		      sel->sel_out_slots[inx]->ssl_sqt = ssl->ssl_sqt;
		      cv_artm (code_set, (ao_func_t) box_identity, sel->sel_out_slots[inx], ssl, NULL);
		    }
		  break;
		}
	    }
	}
    }
  END_DO_BOX;
}


void
sqlc_select_as (state_slot_t ** sls, caddr_t ** as_list)
{
  int inx;
  DO_BOX (ST *, as, inx, as_list)
  {
    if (inx >= BOX_ELEMENTS (sls))
      break; /* can be less slots than as declas if breakup select */
    if (as && sls[inx])
      {
	dk_free_box (sls[inx]->ssl_name);
	sls[inx]->ssl_name = box_dv_uname_string (as->_.as_exp.name);
	if (as->_.as_exp.type)
	  {
	    caddr_t *type = (caddr_t *) as->_.as_exp.type;
	    ddl_type_to_sqt (&(sls[inx]->ssl_sqt), type);
	  }
      }
  }
  END_DO_BOX;
}

int
qr_has_sort_oby (query_t * qr)
{
  DO_SET (setp_node_t *, setp, &qr->qr_nodes)
    {
      if (IS_QN (setp, setp_node_input) && setp->setp_ha && HA_ORDER == setp->setp_ha->ha_op)
	return 1;
    }
  END_DO_SET();
  return 0;
}


void
sqlc_select_top (sql_comp_t * sc, select_node_t * sel, ST * tree,
		 dk_set_t * code)
{
  ST * top = SEL_TOP (tree);
  ST * texp = tree->_.select_stmt.table_exp;
  if (texp && texp->_.table_exp.order_by && qr_has_sort_oby (sc->sc_cc->cc_query))
    return;
  if (!top || SEL_IS_TRANS (tree))
    return;
  sc->sc_top = top;

  sqlc_mark_pred_deps (sc, NULL, top->_.top.exp);
  sel->sel_top = scalar_exp_generate (sc, top->_.top.exp, code);
  if (top->_.top.skip_exp)
    {
      sqlc_mark_pred_deps (sc, NULL, top->_.top.skip_exp);
      sel->sel_top_skip = scalar_exp_generate (sc, top->_.top.skip_exp, code);
    }
  else
    sel->sel_top_skip = NULL;
  sc->sc_top_sel_node = sel;
  sel->sel_row_ctr = ssl_new_variable (sc->sc_cc, "rowctr", DV_LONG_INT);
}


#ifdef OLD_GOOD_PARSER
void
yy_new_error (const char *s, const char *state, const char *native)
{
  int nlen;
  int is_semi;
  int this_lineno = global_scs->scs_scn3c.lineno;
  char buf_for_next [2000];
  scn3_include_fragment_t *outer;
  if (global_scs->scs_scn3c.inside_error_reporter)
    goto jmp; /* see below */
  nlen = scn3_sprint_curr_line_loc (sql_err_text, sizeof (sql_err_text));
  if (state)
    {
      strncpy (sql_err_state, state, sizeof (sql_err_state));
      sql_err_state[sizeof (sql_err_state) - 1] = 0;
    }
  if (native)
    {
      strncpy (sql_err_native, native, sizeof (sql_err_native));
      sql_err_native[sizeof (sql_err_native) - 1] = 0;
    }
  is_semi = !strcmp (yytext, ";");
  snprintf (sql_err_text + nlen, sizeof (sql_err_text)-nlen, ": %s at '%s'", s, yytext);
  global_scs->scs_scn3c.inside_error_reporter ++;
  if (0 != yylex ())
    if (global_scs->scs_scn3c.lineno != this_lineno)
      strcpy (buf_for_next, " immediately before end of line");
    else
      {
      snprintf (buf_for_next, sizeof (buf_for_next), " before '%s'", yytext);
	buf_for_next [sizeof (buf_for_next) - 1] = 0;
      }
  else
    {
      if (is_semi)
        {
          sql_err_text [sizeof (sql_err_text)-1] = '\0';
          sql_err_text [strlen (sql_err_text)-7] = '\0';
	  buf_for_next[0] = '\0';
        }
      else
        strcpy (buf_for_next, " immediately before end of statement");
    }
  strncat_ck (sql_err_text, buf_for_next, (sizeof (sql_err_text) - 1));
  sql_err_text [sizeof (sql_err_text)-1] = '\0';
jmp:
  outer = scn3_include_stack + scn3_include_depth;
  if (outer->_.sif_skipped_part)
    {
      dk_free_box (outer->_.sif_skipped_part);
      outer->_.sif_skipped_part = NULL;
    }
  longjmp_splice (&(global_scs->parse_reset), 1);
}
#else
void
yy_new_error (const char *s, const char *state, const char *native)
{
  int nlen;
  int is_semi;
  int this_lineno = global_scs->scs_scn3c.lineno;
  char buf_for_next [2000];
  scn3_include_fragment_t *outer;
  if (global_scs->scs_scn3c.inside_error_reporter)
    goto jmp; /* see below */
  nlen = scn3_sprint_curr_line_loc (sql_err_text, sizeof (sql_err_text));
  if (state)
    {
      strncpy (sql_err_state, state, sizeof (sql_err_state));
      sql_err_state[sizeof (sql_err_state) - 1] = 0;
    }
  if (native)
    {
      strncpy (sql_err_native, native, sizeof (sql_err_native));
      sql_err_native[sizeof (sql_err_native) - 1] = 0;
    }
  snprintf (sql_err_text + nlen, sizeof (sql_err_text)-nlen, ": %s", s);
  sql_err_text [sizeof (sql_err_text)-1] = '\0';

jmp:
  outer = global_scs->scs_scn3c.include_stack + global_scs->scs_scn3c.include_depth;
  if (outer->_.sif_skipped_part)
    {
      dk_free_box (outer->_.sif_skipped_part);
      outer->_.sif_skipped_part = NULL;
    }
  longjmp_splice (&(global_scs->parse_reset), 1);
}
#endif


void
yyerror (const char *s)
{
  yy_new_error (s, NULL, NULL);
}

void
yyfatalerror (const char *s)
{
  if (global_scs->scs_scn3c.inside_error_reporter)
    goto jmp; /* see below */
  strcpy_ck (sql_err_text, s);
  sql_err_text [sizeof (sql_err_text)-1] = '\0';

jmp:
  longjmp_splice (&(global_scs->parse_reset), 1);
}

#ifdef OLD_GOOD_PARSER
void
yyerror_1 (int yystate, short *yyssa, short *yyssp, const char *strg)
{
  char buf [2000];
  int this_lineno = global_scs->scs_scn3c.lineno;
  char buf_for_next [2000];
#ifdef DEBUG
  int sm2, sm1, sp1;
  sp1 = yyssp[1];
  sm1 = yyssp[-1];
  sm2 = ((sm1 > 0) ? yyssp[-2] : 0);
  snprintf (buf, sizeof (buf), ": %s [%d-%d-(%d)-%d] at '%s'", strg, sm2, sm1, yystate,
    ((sp1 & ~0x7FF) ? -1 : sp1) /* stub to avoid printing random garbage in logs */,
    yytext );
#else
  snprintf (buf, sizeof (buf), ": %s at '%s'", strg, yytext);
#endif
  if (global_scs->scs_scn3c.inside_error_reporter)
    goto jmp; /* see below */
  scn3_sprint_curr_line_loc (sql_err_text, sizeof (sql_err_text));
  strcat_ck (sql_err_text, buf);
  global_scs->scs_scn3c.inside_error_reporter ++;
  if (0 != yylex ())
    if (global_scs->scs_scn3c.lineno != this_lineno)
      strcpy (buf_for_next, " immediately before end of line");
    else
      snprintf (buf_for_next, sizeof (buf_for_next), " before '%s'", yytext);
  else
    strcpy (buf_for_next, " immediately before end of statement");
  strcat_ck (sql_err_text, buf_for_next);

jmp:
  longjmp_splice (&(global_scs->parse_reset), 1);
}
#else
void
yyerror_1 (int yystate, short *yyssa, short *yyssp, const char *strg)
{
  char buf [2000];
  int this_lineno = global_scs->scs_scn3c.lineno;
  char buf_for_next [2000];
#ifdef DEBUG
  int sm2, sm1, sp1;
  sp1 = yyssp[1];
  sm1 = yyssp[-1];
  sm2 = ((sm1 > 0) ? yyssp[-2] : 0);
  snprintf (buf, sizeof (buf), ": %s [%d-%d-(%d)-%d]", strg, sm2, sm1, yystate,
    ((sp1 & ~0x7FF) ? -1 : sp1) /* stub to avoid printing random garbage in logs */ );
#else
  snprintf (buf, sizeof (buf), ": %s", strg);
#endif
  if (global_scs->scs_scn3c.inside_error_reporter)
    goto jmp; /* see below */
  scn3_sprint_curr_line_loc (sql_err_text, sizeof (sql_err_text));
  strcat_ck (sql_err_text, buf);
  global_scs->scs_scn3c.inside_error_reporter ++;

jmp:
  longjmp_splice (&(global_scs->parse_reset), 1);
}
#endif

#ifdef OLD_GOOD_PARSER
void yyfatalerror_1 (int yystate, short *yyssa, short *yyssp, const char *strg)
{
  char buf [2000];
#ifdef DEBUG
  int sm2, sm1, sp1;
  sp1 = yyssp[1];
  sm1 = yyssp[-1];
  sm2 = ((sm1 > 0) ? yyssp[-2] : 0);
  snprintf (buf, sizeof (buf), ": %s [%d-%d-(%d)-%d] at '%s'", strg, sm2, sm1, yystate,
    ((sp1 & ~0x7FF) ? -1 : sp1) /* stub to avoid printing random garbage in logs */,
    yytext );
#else
  snprintf (buf, sizeof (buf), ": %s at '%s'", strg, yytext);
#endif
  if (global_scs->scs_scn3c.inside_error_reporter)
    goto jmp; /* see below */
  scn3_sprint_curr_line_loc (sql_err_text, sizeof (sql_err_text));
  strcat_ck (sql_err_text, buf);

jmp:
  longjmp_splice (&(global_scs->parse_reset), 1);
}
#else
void yyfatalerror_1 (yyscan_t scanner, int yystate, short *yyssa, short *yyssp, const char *strg)
{
  char buf [2000];
#ifdef DEBUG
  int sm2, sm1, sp1;
  sp1 = yyssp[1];
  sm1 = yyssp[-1];
  sm2 = ((sm1 > 0) ? yyssp[-2] : 0);
  snprintf (buf, sizeof (buf), ": %s [%d-%d-(%d)-%d]", strg, sm2, sm1, yystate,
    ((sp1 & ~0x7FF) ? -1 : sp1) /* stub to avoid printing random garbage in logs */ );
#else
  snprintf (buf, sizeof (buf), ": %s", strg);
#endif
  if (global_scs->scs_scn3c.inside_error_reporter)
    goto jmp; /* see below */
  scn3_sprint_curr_line_loc (sql_err_text, sizeof (sql_err_text));
  strcat_ck (sql_err_text, buf);

jmp:
  longjmp_splice (&(global_scs->parse_reset), 1);
}
#endif

void
scn3yyerror (const char *strg)
{
  char buf [2000];
  int this_lineno = global_scs->scs_scn3c.lineno;
  char buf_for_next [2000];
  snprintf (buf, sizeof (buf), ": %s", strg);
  if (global_scs->scs_scn3c.inside_error_reporter)
    goto jmp; /* see below */
  scn3_sprint_curr_line_loc (sql_err_text, sizeof (sql_err_text));
  strcat_ck (sql_err_text, buf);
  global_scs->scs_scn3c.inside_error_reporter ++;

jmp:
  longjmp_splice (&(global_scs->parse_reset), 1);
}


int
ssl_param_key (state_slot_t * sl)
{
  return (atoi (sl->ssl_name + 1));
}


void
sqlc_make_param_list (sql_comp_t * sc)
{
  /* params :1 :2 :3 ... in numeric order, all other params follow in random order. */
  state_slot_t * arr[1000];
  int fill = 0;
  query_t *qr = sc->sc_cc->cc_query;
  int inx;
  dk_set_free (qr->qr_parms);
  qr->qr_parms = NULL;

  DO_SET (state_slot_t *, sl, &qr->qr_state_map)
    {
      int n;
      if (sl->ssl_type == SSL_PARAMETER
	  && 1 == sscanf (sl->ssl_name, ":%d", &n))
	arr[fill++] = sl;
    }
  END_DO_SET();
  buf_bsort ((buffer_desc_t**) &arr, fill, (sort_key_func_t) ssl_param_key);
  for (inx = fill - 1; inx >= 0; inx--)
    dk_set_push (&qr->qr_parms, (void*) arr[inx]);
  DO_SET (state_slot_t *, param, &qr->qr_state_map)
  {
    if ((param->ssl_type == SSL_PARAMETER
	 || param->ssl_vec_param)
	&& !dk_set_member (qr->qr_parms, (void *) param))
      qr->qr_parms = NCONC (qr->qr_parms,
			    CONS (param, NULL));
  }
  END_DO_SET ();
}


void
sqlc_op_node (sql_comp_t * sc, ST * tree)
{
  dk_set_t code = NULL;
  SQL_NODE_INIT (op_node_t, op, op_node_input, NULL);
  op->op_code = (long) tree->type;
  if (tree->_.op.arg_1)
    {
      sqlc_mark_pred_deps (sc, NULL, (ST *) tree->_.op.arg_1);
      op->op_arg_1 = scalar_exp_generate (sc, (ST *) tree->_.op.arg_1, &code);
    }
  if (tree->_.op.arg_2)
    {
      sqlc_mark_pred_deps (sc, NULL, (ST *) tree->_.op.arg_2);
      op->op_arg_2 = scalar_exp_generate (sc, (ST *) tree->_.op.arg_2, &code);
    }
  sc->sc_cc->cc_query->qr_head_node = (data_source_t *) op;
  op->src_gen.src_pre_code = code_to_cv (sc, code);
}


void
sqlc_literal_op_node (sql_comp_t * sc, ST * tree)
{
  SQL_NODE_INIT (op_node_t, op, op_node_input, NULL);
  op->op_code = (long) tree->type;
  if (tree->_.op.arg_1)
    {
      op->op_arg_1 = ssl_new_constant (sc->sc_cc, tree->_.op.arg_1);
    }
  if (tree->_.op.arg_2)
    {
      op->op_arg_2 = ssl_new_constant (sc->sc_cc, tree->_.op.arg_2);
    }
  sc->sc_cc->cc_query->qr_head_node = (data_source_t *) op;

  if (DO_LOG(LOG_DDL))
    {
      user_t * usr = sc->sc_client->cli_user;
      log_info ("DDLC_9 %s drop trigger %.*s (%.*s)", GET_USER,
	  LOG_PRINT_STR_L, tree->_.trigger.name, LOG_PRINT_STR_L, tree->_.trigger.table);
    }
}


void
sqlc_routine_qr (sql_comp_t * sc)
{
  /* make single end node with the sc_routine_code as pre_code.
     Routine bodies and single call statement compile this way. */

  code_vec_t code = code_to_cv (sc, sc->sc_routine_code);
  SQL_NODE_INIT (end_node_t, node, end_node_input, NULL);
  if (!code)
    sqlc_new_error (sc->sc_cc, "42000", "SQ072", "Goto to undeclared label.");
  node->src_gen.src_pre_code = code;
  sc->sc_cc->cc_query->qr_head_node = (data_source_t *) node;
  sc->sc_cc->cc_query->qr_is_call = 1;
}


void
sqlc_check_mpu_name (caddr_t name, mpu_name_type_t type)
{
  sql_class_t *udt;
  query_t *proc_qr, *module_qr;
  char err_str[300];

  err_str[0] = 0;
  if (NULL != (udt = sch_name_to_type (wi_inst.wi_schema, name)) &&
      (type != MPU_UDT || udt->scl_defined))
    {
      snprintf (err_str, sizeof (err_str),
	  "An user defined type with name %.200s already exists", udt->scl_name);
    }
  else if (NULL != (module_qr = sch_module_def (wi_inst.wi_schema, name)))
    {
      snprintf (err_str, sizeof (err_str),
	  "A SQL module with name %.200s already exists", module_qr->qr_proc_name);
    }
  else if (NULL != (proc_qr = sch_proc_def (wi_inst.wi_schema, name)) &&
      type != MPU_PROC)
    {
      snprintf (err_str, sizeof (err_str),
	  "An SQL stored procedure with name %.200s already exists", proc_qr->qr_proc_name);
    }
  if (err_str[0])
    sqlc_new_error (top_sc->sc_cc, "42000", "SQ171", "%s", err_str);
}

/* returns true if table in the tree has subkeys, if tree is not delete must extend the switch */
int
sqlc_table_has_subtables (sql_comp_t * sc, ST * tree)
{
  const char * tb_name;
  dbe_table_t *super, **tbptr;
  id_casemode_hash_iterator_t hit;

  switch (tree->type)
    {
      case DELETE_SRC:
	  tb_name = tree->_.delete_src.table_exp->_.table_exp.from[0]->_.table.name;
	  break;
      case UPDATE_SRC:
	  tb_name = tree->_.update_src.table->_.table.name;
	  break;
      case INSERT_STMT:
	  tb_name = tree->_.insert.table->_.table.name;
	  break;
      default:
	  return 0;
    }

  super = sch_name_to_table (wi_inst.wi_schema, tb_name);
  if (!super)
    return 0;
  id_casemode_hash_iterator (&hit, wi_inst.wi_schema->sc_name_to_object[sc_to_table]);
  while (id_casemode_hit_next (&hit, (caddr_t *) & tbptr))
    {
      dbe_table_t *the_table = *tbptr;
      if (the_table == super || !the_table->tb_primary_key)
	continue;
      if (dk_set_member (the_table->tb_primary_key->key_supers, (void *) super->tb_primary_key))
	return 1;
    }
  return 0;
}

#if 1
#define TREE_CHECK(tree) box_tree_check ((caddr_t) tree)
#else
#define TREE_CHECK(tree)
#endif

long sqlc_add_views_qualifiers = 0;
int enable_vec_upd = 1;
int ins_vec_always = 1;

void
sql_stmt_comp (sql_comp_t * sc, ST ** ptree)
{
  ST *tree = *ptree;

  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &tree, 8000))
    sqlc_error (sc->sc_cc, ".....", "Stack Overflow");
  if (DK_MEM_RESERVE)
    sqlc_error (sc->sc_cc, ".....", "Out of memory");
    switch (tree->type)
      {
      case SELECT_STMT:
	{
	  if (enable_vec && !(tree->_.select_stmt.table_exp && sqlo_opt_value (tree->_.select_stmt.table_exp->_.table_exp.opts, OPT_NOT_VECTORED)))
	    sc->sc_cc->cc_query->qr_proc_vectored = QR_VEC_STMT;
	  sqlo_top_select (sc, ptree);
	  tree = *ptree;
	  break;
	}
      case UNION_ST:
      case UNION_ALL_ST:
      case EXCEPT_ST:
      case EXCEPT_ALL_ST:
      case INTERSECT_ST:
      case INTERSECT_ALL_ST:
	*ptree = sqlp_view_def (NULL, tree, 1);
	sqlc_union_order (sc, ptree);
	tree = *ptree;
	break;
      case INSERT_STMT:
	if (ins_vec_always  || (enable_vec && (param_inx || ST_P (tree->_.insert.vals, SELECT_STMT) || cluster_enable)
		  && INS_REPLACING != tree->_.insert.mode))
	  sc->sc_cc->cc_query->qr_proc_vectored = QR_VEC_STMT;
	sqlc_insert (sc, tree);
	break;

      case UPDATE_POS:
	sqlc_update_pos (sc, tree, NULL, NULL);
	break;

      case UPDATE_SRC:
	if (enable_vec_upd && !sqlc_table_has_subtables (sc, tree))
	  sc->sc_cc->cc_query->qr_proc_vectored = QR_VEC_STMT;
	sqlc_update_searched (sc, tree);
	break;

      case DELETE_SRC:
	/* if table has subtables can't be vectored */
	if (enable_vec && !sqlc_table_has_subtables (sc, tree))
	  sc->sc_cc->cc_query->qr_proc_vectored = QR_VEC_STMT;
	sqlc_delete_searched (sc, tree);
	break;

      case DELETE_POS:
	sqlc_delete_pos (sc, tree, NULL, NULL);
	break;

      case OP_SHUTDOWN:
      case OP_CHECKPOINT:
      case OP_BACKUP:
      case OP_CHECK:
      case OP_SYNC_REPL:
      case OP_DISC_REPL:
      case OP_LOG_ON:
      case OP_LOG_OFF:
	sqlc_op_node (sc, tree);
	break;

      case SCHEMA_ELEMENT_LIST:
	sqlc_sch_list (sc, tree);
	break;

      case USER_AGGREGATE_DECL:
	sqlc_user_aggregate_decl (sc, tree);
	return;			/* params already in place. */

      case ROUTINE_DECL:
	if (BOX_ELEMENTS (tree) <= 7)
	  sqlc_check_mpu_name (tree->_.routine.name, MPU_PROC);
	sqlc_routine_decl (sc, tree);
	return;			/* params already in place. */

      case MODULE_DECL:
	sqlc_check_mpu_name (tree->_.module.name, MPU_MODULE);
	sqlc_module_decl (sc, tree);
	return;			/* params already in place. */

      case TRIGGER_DEF:
	sqlc_trigger_decl (sc, tree);
	return;			/* params already in place. */

      case OP_DROP_TRIGGER:
	sqlc_literal_op_node (sc, tree);
	break;

      case CALL_STMT:
	if (enable_vec && param_inx)
	  sc->sc_cc->cc_query->qr_proc_vectored = QR_VEC_STMT;
	tree = sqlo_udt_check_method_call (sc->sc_so, sc, tree);
	sqlc_mark_pred_deps (sc, NULL, tree);
	sqlc_call_exp (sc, &sc->sc_routine_code, NULL, tree);
	if (sc->sc_routine_code)
	  {
	    sqlc_routine_qr (sc);
	    if (BOX_ELEMENTS (tree) == 4)
	      sc->sc_cc->cc_query->qr_is_call = 2;
	  }
	break;
      default:
	sqlc_new_error (sc->sc_cc, "37000", "SQ073", "Statement not supported.");
      }
  if (!sc->sc_super)
    {
      sqlc_make_param_list (sc);	/* subquery params done in sqlc_subquery */
    }
}


dk_mutex_t *parse_mtx;
du_thread_t * parse_mtx_owner;
int enable_parse_mtx = 0;

void
parse_enter ()
{
  if (enable_parse_mtx)
    mutex_enter (parse_mtx);
}


void
parse_leave ()
{
  if (enable_parse_mtx)
    mutex_leave (parse_mtx);
}


char *
wrap_sql_string (const char *text)
{
  caddr_t tmp = (caddr_t) t_alloc (16 + strlen (text));
  snprintf (tmp, box_length (tmp), "EXEC SQL %s;", text);
  return tmp;
}


void
sqlc_temp_tree (sql_comp_t * sc, caddr_t tree)
{
  while (sc->sc_super)
    sc = sc->sc_super;
  t_set_push (&sc->sc_temp_trees, (void *) tree);
}

void smp_destroy (tb_sample_t * smp);

void
sc_free (sql_comp_t * sc)
{
  if (sc->sc_name_to_label)
    id_hash_free (sc->sc_name_to_label);
  if (sc->sc_decl_name_to_label)
    id_hash_free (sc->sc_decl_name_to_label);
  if (sc->sc_qn_to_dpipe)
    hash_table_free (sc->sc_qn_to_dpipe);
  if (sc->sc_ssl_eqs)
    {
      DO_HT (state_slot_t *, ssl, dk_set_t, list, sc->sc_ssl_eqs)
	{
	  dk_set_free (list);
	}
      END_DO_HT;
      hash_table_free (sc->sc_ssl_eqs);
    }
  if (sc->sc_sample_cache)
    {
      id_hash_iterator_t hit;
      caddr_t * pid;
      tb_sample_t*pnum;
      id_hash_iterator (&hit, sc->sc_sample_cache);
      while (hit_next (&hit, (caddr_t *)&pid, (caddr_t *)&pnum))
	{
	  dk_free_tree (*pid);
	  smp_destroy (pnum);
	}
      id_hash_free (sc->sc_sample_cache);
    }
  if (NULL != sc->sc_big_ssl_consts)
    {
#if 0 /* This check is no longer valid, because the pointers to big consts are not (erroneously) zeroed anymore */
      int ctr;
      DO_BOX_FAST (caddr_t, itm, ctr, sc->sc_big_ssl_consts)
        {
          if (NULL != itm)
            dbg_printf (("\nUnused big ssl const # %d", ctr));
        }
      END_DO_BOX_FAST;
#endif
      dk_free_tree (sc->sc_big_ssl_consts);
    }
  if (sc->sc_qn_to_dfe)
    hash_table_free (sc->sc_qn_to_dfe);
  /*if left due to error in vec */
  if (sc->sc_vec_ssl_def)
    hash_table_free (sc->sc_vec_ssl_def);
  if (sc->sc_vec_ssl_shadow)
    hash_table_free (sc->sc_vec_ssl_shadow);
  if (sc->sc_vec_no_copy_ssls)
    hash_table_free (sc->sc_vec_no_copy_ssls);
  if (sc->sc_vec_cast_ssls)
    hash_table_free (sc->sc_vec_cast_ssls);
  if (sc->sc_vec_last_ref)
    hash_table_free (sc->sc_vec_last_ref);
  if (sc->sc_vec_save_shadow)
    hash_table_free (sc->sc_vec_save_shadow);
}

query_t *
sqlc_make_proc_store_qr (client_connection_t * cli, query_t * proc_or_trig, const char * text)
{
  comp_context_t cc;
  sql_comp_t scs;
  sql_comp_t *sc = &scs;
  caddr_t text2 = box_dv_short_string (text);
  NEW_VARZ (query_t, qr);
  memset (&scs, 0, sizeof (scs));

  CC_INIT (cc, cli);
  sc->sc_cc = &cc;
  sc->sc_client = cli;

  cc.cc_query = qr;

  {
    SQL_NODE_INIT (op_node_t, op, op_node_input, NULL);
    if (proc_or_trig->qr_trig_table)
      {
	caddr_t trigger_opts = list (2,
	    box_num ((ptrlong) proc_or_trig->qr_trig_event),
	    box_num ((ptrlong) proc_or_trig->qr_trig_time));
	op->op_code = OP_STORE_TRIGGER;
	op->op_arg_1 = ssl_new_constant (sc->sc_cc, proc_or_trig->qr_proc_name);
	op->op_arg_2 = ssl_new_constant (sc->sc_cc, proc_or_trig->qr_trig_table);
	op->op_arg_3 = ssl_new_constant (sc->sc_cc, text2);
	op->op_arg_4 = ssl_new_constant (sc->sc_cc, trigger_opts);
	dk_free_tree (trigger_opts);
      }
    else if (proc_or_trig->qr_udt_mtd_info)
      {
	op->op_code = OP_STORE_METHOD;
	op->op_arg_1 = ssl_new_constant (sc->sc_cc, proc_or_trig->qr_proc_name);
	op->op_arg_2 = ssl_new_constant (sc->sc_cc, text2);
	op->op_arg_3 = ssl_new_constant (sc->sc_cc, (caddr_t) proc_or_trig->qr_udt_mtd_info);
      }
    else
      {
	caddr_t cnull = dk_alloc_box (0, DV_DB_NULL);
	ptrlong type = (ptrlong) cnull;

	if (QR_IS_MODULE (proc_or_trig))
	  type = 3;
	else if (IS_REMOTE_ROUTINE_QR (proc_or_trig))
	  type = 1;
	op->op_code = OP_STORE_PROC;
	op->op_arg_1 = ssl_new_constant (sc->sc_cc, proc_or_trig->qr_proc_name);
	op->op_arg_2 = ssl_new_constant (sc->sc_cc, text2);
	op->op_arg_3 = ssl_new_constant (sc->sc_cc, (caddr_t) type);
	dk_free_box (cnull);
      }
    sc->sc_cc->cc_query->qr_head_node = (data_source_t *) op;
  }

  qr->qr_instance_length = cc.cc_instance_fill * sizeof (caddr_t);
  qr->qr_text = text2;

  qr_set_freeable (&cc, qr);
  sc_free (sc);
#ifdef QUERY_DEBUG
  log_query_event (proc_or_trig, 1, "MAKE_PROC_STORE by sqlc_make_proc_store_qr at %s:%d resulting %p", __FILE__, __LINE__, qr);
  log_query_event (qr, 1, "ALLOC+MAKE_PROC_STORE by sqlc_make_proc_store_qr at %s:%d wrapping %p", __FILE__, __LINE__, proc_or_trig);
#endif
  return qr;
}

void
sqlc_table_used (sql_comp_t * sc, dbe_table_t * tb)
{
  if (tb)
    qr_uses_table (top_sc->sc_cc->cc_query, tb->tb_name);
}


int
st_is_query_exp (ST * tree)
{
  switch (tree->type)
    {
    case SELECT_STMT:
    case UNION_ST:
    case UNION_ALL_ST:
    case EXCEPT_ST:
    case EXCEPT_ALL_ST:
    case INTERSECT_ST:
    case INTERSECT_ALL_ST:
      return 1;
    }
  return 0;
}

#ifndef BIF_XML
#define sqlc_xpath(a, b, c) 0
#endif


int sqlc_hook_enable = 0;

void
sqlc_hook (client_connection_t * cli, caddr_t * real_tree_ret, caddr_t * err_ret)
{
  state_slot_t * p1;
  caddr_t * params;
  caddr_t err = NULL;
  query_t * proc = NULL;
  mem_pool_t *saved_thr_mem_pool = THR_TMP_POOL;
  caddr_t tree, *tree_ret;
  if (!sqlc_hook_enable)
    return;
  proc = sch_proc_def (wi_inst.wi_schema, "DB.DBA.DBEV_PREPARE");
  if (!proc)
    {
      return;
    }
  parse_leave ();
  if (proc->qr_to_recompile)
    proc = qr_recompile (proc, NULL);
  p1 = (state_slot_t *) (proc->qr_parms ? proc->qr_parms->data : NULL);
  if (!p1 || !IS_SSL_REF_PARAMETER (p1->ssl_type))
    {

      log_error ("SQLPrepare hook must take at least 1 reference parameter");
      parse_enter ();
      return;
    }
  tree = box_copy_tree (*real_tree_ret);
  tree_ret = &tree;
  params = (caddr_t *) sc_list (1, tree_ret);
  err = qr_exec (cli, proc, CALLER_LOCAL, NULL,
		 NULL, NULL, params, NULL, 0);
  dk_free_box ((caddr_t) params);
 SET_THR_TMP_POOL (saved_thr_mem_pool);
  parse_enter ();
  sqlc_set_client (cli);
  if (err_ret)
    *err_ret = err;
  TREE_CHECK (*tree_ret);
  *real_tree_ret = t_full_box_copy_tree (*tree_ret);
  dk_free_tree (tree);
}


void
sqlc_compile_hook  (client_connection_t * cli, const char * text, caddr_t * err_ret)
{
  caddr_t * params;
  caddr_t err = NULL;
  query_t * proc = NULL;
  if (!sqlc_hook_enable)
    return;
  proc = sch_proc_def (wi_inst.wi_schema, "DB.DBA.DBEV_COMPILE");
  if (!proc)
    return;
  if (proc->qr_to_recompile)
    proc = qr_recompile (proc, NULL);
  params = (caddr_t *) sc_list (1, box_dv_short_string (text));
  err = qr_exec (cli, proc, CALLER_LOCAL, NULL,
		 NULL, NULL, params, NULL, 0);
  dk_free_box ((caddr_t) params);
  if (err != SQL_SUCCESS)
    {
      if (IS_BOX_POINTER (err))
	log_error ("Error while executing DB.DBA.DBEV_COMPILE : State=%.5s Message=%.100s",
	    ERR_STATE (err), ERR_MESSAGE (err));
      else
	log_error ("Error while executing DB.DBA.DBEV_COMPILE");
      dk_free_tree (err);
    }
}


void
sqlc_meta_data_hook (sql_comp_t * sc, ST * tree)
{
  sqlc_meta_hook_t f = (sqlc_meta_hook_t) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_META);
  if (f)
    {
      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_META, NULL);
      f (sc, tree);
    }
}

long pl_debug_all = 0;

void
sqlc_assign_unknown_dtps (query_t *qr)
{
  if (qr)
    {
      DO_SET (state_slot_t *, ssl, &qr->qr_parms)
	{
	  if (DV_UNKNOWN == ssl->ssl_dtp)
	    {
	      ssl->ssl_dtp = DV_LONG_STRING;
	      ssl->ssl_prec = 256;
	    }
	}
      END_DO_SET ();
      if (qr->qr_select_node)
	{
	  select_node_t *sel = qr->qr_select_node;
	  int n_out = sel->sel_n_value_slots, inx;
	  if (sel->sel_out_slots)
	    {
	      for (inx = 0; inx < n_out; inx++)
		{
		  state_slot_t *sl = sel->sel_out_slots[inx];
		  if (DV_UNKNOWN == sl->ssl_dtp)
		    {
		      sl->ssl_dtp = DV_LONG_STRING;
		      sl->ssl_prec = 256;
		    }
		}
	    }
	}
    }
}



#if 0
static int
sql_is_ddl (sql_tree_t * tree)
{
  switch (tree->type)
    {
      case SCHEMA_ELEMENT_LIST:
      case ROUTINE_DECL:
      case USER_AGGREGATE_DECL:
      case MODULE_DECL:
      case TRIGGER_DEF:
	  return 1;
    }
  return 0;
}
#endif

#ifdef QUERY_DEBUG
extern FILE *query_log;

void
log_query_event (query_t *qr, int print_full_content, const char *fmt, ...)
{
  jmp_buf_splice *ctx;
  va_list ap;
  va_start (ap, fmt);
  if (NULL == qr)
    return;
  fprintf (query_log, "\n{{{%p ", qr);
  vfprintf (query_log, fmt, ap);
  if (print_full_content && qr->qr_text)
    {
      char buf[200];
      char *eol;
      strncpy (buf, qr->qr_text, sizeof (buf)-1);
      buf [sizeof (buf)-1] = '\0';
      for (eol = strchr (buf, '\n'); NULL != eol; eol = strchr (eol+1, '\n')) eol[0] = '\t';
      fprintf (query_log, " {{%s}}", buf);
    }
  for (ctx = THREAD_CURRENT_THREAD->thr_reset_ctx; NULL != ctx; ctx = ctx->j_parent)
    fprintf (query_log, " {%s:%d}", ctx->j_file, ctx->j_line);
  fprintf (query_log, " }}}");
  fflush (query_log);
}
#endif


extern int enable_vec;
int64 sqlc_cum_memory;

query_t *
DBG_NAME(sql_compile_1) (DBG_PARAMS const char *string2, client_connection_t * cli,
	     caddr_t * err, volatile int cr_type, ST *the_parse_tree, char *view_name)
{
  volatile long msecs = prof_on ? get_msec_real_time () : 0;
  db_activity_t da_before;
  caddr_t cc_error;
  char *string = NULL;
  ST *tree;
  SCS_STATE_FRAME;
  comp_context_t cc;
  sql_comp_t sc;
  query_t * volatile qr;
  client_connection_t *old_cli = sqlc_client ();
  int nested_sql_comp = (THR_TMP_POOL ? 1 : 0);
  volatile int inside_sem = 0;
  volatile int is_ddl = 0;
  yyscan_t scanner;
  if (!nested_sql_comp)
    {
      CLI_THREAD_TIME (cli);
      da_before = cli->cli_activity;
    }
  if (DO_LOG_INT (LOG_COMPILE))
    {
      LOG_GET;
      log_info ("COMP_2 %s %s %s Compile %s %s",
	  user, from, peer, the_parse_tree ? "tree" : "text: ", string2);
    }
  DK_ALLOC_QUERY (qr);
  memset (&sc, 0, sizeof (sc));

  CC_INIT (cc, cli);
  sc.sc_cc = &cc;
  if (SQLC_NO_REMOTE == cr_type)
    {
      cr_type = SQLC_DEFAULT;
      sc.sc_no_remote = 1;
    }

  sc.sc_store_procs = (cr_type != SQLC_DO_NOT_STORE_PROC) && (cr_type != SQLC_QR_TEXT_IS_CONSTANT);

  qr->qr_text_is_constant = cr_type == SQLC_QR_TEXT_IS_CONSTANT;

  sc.sc_text = string2;
  sc.sc_client = cli;

  cc.cc_query = qr;

  sqlc_compile_hook (cli, string2, err);
  if (!parse_mtx)
    {
      parse_mtx = mutex_allocate ();
      mutex_option (parse_mtx, "parse_mtx", NULL, NULL);
    }
  if (!nested_sql_comp)
    {
      sql_warnings_clear ();
      MP_START();
      mp_comment (THR_TMP_POOL, "compile ", string2);
    }
  string = wrap_sql_string (string2);
  if (SQLC_PARSE_ONLY_REC == cr_type)
    cr_type = SQLC_PARSE_ONLY;
  else
    {
      parse_enter ();
      inside_sem = 1;
    }
  SCS_STATE_PUSH;
  sqlc_set_client (cli);
  sqlp_in_view (view_name);
  top_sc = &sc;
  sql_err_state[0] = 0;
  sql_err_native[0] = 0;
  sqlp_bin_op_serial = 0;
  parse_not_char_c_escape =  cli->cli_not_char_c_escape;
#ifdef PLDBG
  parse_pldbg = pl_debug_all ? 1 : 0;
#else
  parse_pldbg = 0;
#endif
  pl_file = NULL;
  pl_file_offs = 0;
  sql3_breaks = NULL;
  sql3_pbreaks = NULL;
  sql3_ppbreaks = NULL;
  sqlp_udt_current_type = NULL;
  parse_utf8_execs =  cli->cli_utf8_execs;
  qr->qr_qualifier = box_string (sqlc_client ()->cli_qualifier);
  qr->qr_owner = box_string (CLI_OWNER (sqlc_client ()));
  yy_string_input_init (string);
  if (err)
    *err = NULL;

  scn3yylex_init (&scanner);
  CATCH (CATCH_LISP_ERROR)
  {
      if (!the_parse_tree)
	{
	  if (!sqlc_xpath (&sc, string, err))
	    {
	      if (0 == setjmp_splice (&(global_scs->parse_reset)))
		{
		  sql_yy_reset (scanner);
		  scn3yyrestart (NULL, scanner);
		  scn3yyparse (scanner);
		}
	      else
		parse_tree = NULL;
	    }
	  if (!parse_tree)
	    {
	      qr_free (qr);
	      if (err && !*err)
		*err = srv_make_new_error (sql_err_state[0] ? sql_err_state : "37000",
					   sql_err_native[0] ? sql_err_native : "SQ074", "%s", sql_err_text);
	      sqlc_set_client (old_cli);
	      sql_pop_all_buffers (scanner);
	      scn3yylex_destroy (scanner);
	      SCS_STATE_POP;
	      if (!nested_sql_comp)
		{
		  MP_DONE();
		}
	      if (inside_sem)
		parse_leave ();
	      POP_CATCH;
	      if (*err && strstr ((*(caddr_t**)err)[2], "RDFNI") )
		{
		  if (SQLC_DO_NOT_STORE_PROC == cr_type)
		    return NULL;
		  dk_free_tree (*err);
		  *err = NULL;
		  cl_rdf_inf_init (cli, err);
		  if (*err)
		    return NULL;
		  return DBG_NAME (sql_compile_1) (DBG_ARGS string2, cli, err, cr_type, the_parse_tree, view_name);
		}
	      return NULL;
	    }
	}
      sql_pop_all_buffers (scanner);
      scn3yylex_destroy (scanner);
      tree = the_parse_tree ? (ST *) t_full_box_copy_tree ((caddr_t) the_parse_tree) : parse_tree;
      if (cr_type != SQLC_PARSE_ONLY && cr_type != SQLC_TRY_SQLO && cr_type != SQLC_SQLO_SCORE)
	is_ddl = 0; /*sql_is_ddl (tree);*/
      if (!is_ddl)
	{
          if (inside_sem)
            {
              parse_leave ();
              inside_sem = 0;
            }
	}
      else
	sqlc_inside_sem = 1;
      if (cr_type == SQLC_PARSE_ONLY)
	{
	  caddr_t tree1 = box_copy_tree ((box_t) tree);
	  sqlc_set_client (old_cli);
	  if (!nested_sql_comp)
	    {
	      MP_DONE();
	    }
	  SCS_STATE_POP;
	  qr_free (qr);
	  POP_CATCH;
	  if (inside_sem)
	    parse_leave ();
	  return ((query_t*) tree1);
	}
      if (cr_type == SQLC_TRY_SQLO)
	{
	  caddr_t tree1;
	  ST *ret = (ST *) sqlo_top (&sc, &tree, NULL);
	  tree1 = box_copy_tree ((box_t) (ret ? ret : tree));
	  sqlc_set_client (old_cli);
	  if (!nested_sql_comp)
	    {
	      MP_DONE();
	    }
	  sc_free (&sc);
	  SCS_STATE_POP;
	  qr_free (qr);
	  /*dk_free (string, -1);*/
	  POP_CATCH;
	  return ((query_t*) tree1);
	}
      else if (cr_type == SQLC_SQLO_SCORE)
	{
	  float score = 0;
	  sqlo_top (&sc, &tree, &score);
	  sqlc_set_client (old_cli);
	  if (!nested_sql_comp)
	    {
	      MP_DONE();
	    }
	  sc_free (&sc);
	  SCS_STATE_POP;
	  qr_free (qr);
	  POP_CATCH;
	  return ((query_t*) box_float (score));
	}
      sqlc_hook (cli, (caddr_t *)&tree, err);
      /* TREE_CHECK (tree); */
      /* dbg_print_box ((caddr_t) tree, stdout); */

    /* dbg_print_box (text, stdout); printf ("\n"); */

      if (parse_pldbg)
	{
	  qr->qr_brk = -1; /* set a debug flag */
	}
      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR, NULL);
      if (_SQL_CURSOR_FORWARD_ONLY < cr_type
	&& _SQL_CURSOR_STATIC >= cr_type
	&& st_is_query_exp (tree))
	sqlc_cursor (&sc, &tree, cr_type);
    else
      {
	if (SQLC_UNIQUE_ROWS == cr_type /*&& st_is_query_exp (tree)*/)
	  qr->qr_unique_rows = 1;
	sql_stmt_comp (&sc, &tree);
      }
    qr_set_local_code_and_funref_flag (sc.sc_cc->cc_query);
    if (sc.sc_cc->cc_query->qr_proc_vectored || sc.sc_cc->cc_has_vec_subq)
      sqlg_vector (&sc, sc.sc_cc->cc_query);
    qr_resolve_aliases (qr);
    qr_set_freeable (&cc, qr);
    qr->qr_instance_length = cc.cc_instance_fill * sizeof (caddr_t);
    /* dk_free_tree ((caddr_t) text); */
    if (parse_pldbg && qr->qr_proc_name)
      {
#ifdef PLDBG
	qr->qr_source = pl_file ? box_dv_short_string (pl_file) : NULL; /* set a source file */
	qr->qr_line = pl_file_offs; /* and offset within a file */
	if (0 != (pl_debug_all & 2)) /* these are needed for coverage mode settable in ini */
	  {
	    qr->qr_line_counts = hash_table_allocate (100);
	    qr->qr_call_counts = id_str_hash_create (101);
	    qr->qr_stats_mtx = mutex_allocate ();
	  }
#endif
      }

  }
  THROW_CODE
  {
    if (qr && qr->qr_proc_name)
      query_free (qr);
    else
      qr_free (qr);
    cc_error = (caddr_t) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR);
    if (err)
      {
	if (cc_error)
	  *err = cc_error;
	else
	  *err = srv_make_new_error ("42000", "SQ075", "Unclassified SQL compilation error.");
      }
    else
      {
#ifdef DEBUG
	if (IS_BOX_POINTER (err))
	  {
	    log_error (
		"Error compiling %.500s : %s: %s.",
		string2,
		((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);

	  }
#endif
	dk_free_tree (cc_error);	/* IvAn/010411/LeakOnError */
      }
    qr = NULL;
  }
  END_CATCH;
  if (qr)
    sqlc_assign_unknown_dtps (qr);
  if (err && !(*err))
    sqlc_meta_data_hook (&sc, tree);
  else
    SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_META, NULL);

  sqlc_set_client (old_cli);
  SCS_STATE_POP;
  if (inside_sem)
    parse_leave ();
  if (qr)
    {      if (NULL != qr->qr_text)        GPF_T;
      qr->qr_text = SET_QR_TEXT(qr,sc.sc_text);
      qr->qr_parse_tree = box_copy_tree ((box_t) the_parse_tree);
#ifdef QUERY_DEBUG
      log_query_event (qr, 1, "ALLOC+PARSE by sql_compile_1 at %s:%d", file, line);
#endif
    }
  if (!nested_sql_comp)
    {
      int64 sqlc_mem;
      db_activity_t tmp;
      sqlc_cum_memory += sqlc_mem = THR_TMP_POOL->mp_bytes;
    MP_DONE();
      CLI_THREAD_TIME (cli);
      tmp = cli->cli_activity;
      da_sub (&tmp, &da_before);
      da_add (&cli->cli_compile_activity, &tmp);
      da_sub (&cli->cli_activity, &tmp);
      cli->cli_compile_activity.da_memory = sqlc_mem;
    }
  sc_free (&sc);

  if (qr)
    qr->qr_is_complete = 1;
  if (qr && qr->qr_udt_mtd_info != NULL)
    { /* UDT method */
      qr = sqlc_udt_store_method_def (&sc, cli, cr_type, qr, string2, err);
    }
  else if (qr && qr->qr_proc_name)
    {
/* Procedure's calls published for replication keep old account name*/
      query_t *old_place = qr->qr_module ?
	  sch_module_def (wi_inst.wi_schema, qr->qr_proc_name) :
	      sch_proc_def (wi_inst.wi_schema, qr->qr_proc_name);
      user_t * p_user = cli->cli_user;

      /* Only DBA can create procedures with owner different than creator */
      if (p_user && !sec_user_has_group (0, p_user->usr_g_id))
	{
	  char q[MAX_NAME_LEN], o[MAX_NAME_LEN], n[MAX_NAME_LEN];
	  sch_split_name (NULL, qr->qr_proc_name, q, o, n);
	  if (p_user->usr_name && o[0] != 0 && CASEMODESTRCMP (p_user->usr_name, o))
	    {
	      if (err)
		*err = srv_make_new_error ("42000", "SQ076",
		    "The procedure owner specified is different than the creator.");
	      qr_free (qr);
	      qr = NULL;
	    }
	}
      if (qr && !QR_IS_MODULE (qr) && sch_module_def (wi_inst.wi_schema, qr->qr_proc_name))
	{
	  if (err)
	    *err = srv_make_new_error ("37000", "SQ133",
		"Procedure declaration tries to overwrite a module with the same name");
	  qr_free (qr);
	  qr = NULL;
	}

      if (qr)
	{

	  if (DO_LOG_INT (LOG_COMPILE))
	    {
	      LOG_GET;
	      log_info ("COMP_%i %s %s %s Compiled %s %s",  qr->qr_trig_table ? 0:1,
		  user, from, peer,
		  qr->qr_trig_table ? "trigger" : "procedure", qr->qr_proc_name);
	    }

	  if (QR_IS_MODULE (qr))
	    sch_set_module_def (wi_inst.wi_schema, qr->qr_proc_name, qr);
	  else if (!qr->qr_trig_table)
	    {
	      sch_set_proc_def (wi_inst.wi_schema, qr->qr_proc_name, qr);
	      if (DO_LOG_INT(LOG_DDL))
		{
		  LOG_GET;
		  log_info ("DDLC_2 %s %s %s Create procedure %.*s", user, from, peer,
		      LOG_PRINT_STR_L, qr->qr_proc_name);
		}
	    }
	  if (cli->cli_user) /*always must set the owner of qr not inside of sqlc_make_proc_store_qr */
	    qr->qr_proc_owner = cli->cli_user->usr_id;

	  if ((cr_type != SQLC_DO_NOT_STORE_PROC) && (cr_type != SQLC_QR_TEXT_IS_CONSTANT))
	    {
	      if (qr->qr_aggregate)
		{
		  static char *ua_header = "--#pragma bootstrap user-aggregate\n";
		  caddr_t string3 = dk_alloc_box (strlen (ua_header)+strlen(string2)+1, DV_STRING);
		  snprintf (string3, box_length (string3), "%s%s", ua_header, string2);
		  qr = sqlc_make_proc_store_qr (cli, qr, string3);
	          return qr;
		}
	      qr = sqlc_make_proc_store_qr (cli, qr, string2);
	      return qr;
	    }
	}
    }
  if (prof_on)
    {
      uint32 elapsed = get_msec_real_time () - msecs;
      prof_n_compile++;
      prof_compile_time += elapsed;
      cli->cli_compile_msec += elapsed;
    }
  return qr;
}

query_t *
DBG_NAME (sql_compile) (DBG_PARAMS const char *string2, client_connection_t * cli,
	     caddr_t * err, volatile int cr_type)
{
  return DBG_NAME(sql_compile_1) (DBG_ARGS string2, cli, err, cr_type, NULL, NULL);
}

#if defined (MALLOC_DEBUG) || defined (VALGRIND)
query_t *static_qr_dllist = NULL;

query_t *
dbg_sql_compile_static (const char *file, int line, const char *string2, client_connection_t * cli,
	     caddr_t * err, volatile int cr_type)
{
  caddr_t my_err = NULL;
  query_t *qr = NULL;
  sql_tree_t *tree = NULL;
  if (SQLC_STATIC_PRESERVES_TREE == cr_type)
    {
      int cr_tree_type = ((NULL != parse_mtx) && global_scs && !sqlc_inside_sem) ? SQLC_PARSE_ONLY_REC : SQLC_PARSE_ONLY;
      tree = (sql_tree_t *)DBG_NAME(sql_compile_1) (DBG_ARGS string2, cli, err, cr_tree_type, NULL, NULL);
      if (NULL != err[0])
        return NULL;
      cr_type = SQLC_DEFAULT;
    }
  qr = DBG_NAME(sql_compile_1) (DBG_ARGS string2, cli, err, cr_type, tree, NULL);
  dk_free_tree ((caddr_t *)tree);
  if (NULL != err)
    err[0] = my_err;
  if (NULL == qr)
    {
      log_error ("%s %s -- unable to compile static SQL query at file %s line %d: %.100s", ERR_STATE(my_err), ERR_MESSAGE(my_err), file, line, string2);
      if (NULL == err)
        dk_free_tree (my_err);
      return qr;
    }
  if (NULL != my_err)
    {
      log_error ("%s %s -- static SQL query at file %s line %d: %.100s", ERR_STATE(my_err), ERR_MESSAGE(my_err), file, line, string2);
      if (NULL == err)
        dk_free_tree (my_err);
      return qr;
    }
  static_qr_dllist_append (qr, 1);
  qr->qr_static_source_file = file;
  qr->qr_static_source_line = line;
  return qr;
}

void
static_qr_dllist_append (query_t *qr, int gpf_on_dupe)
{
  query_t *iter;
  if ((NULL != static_qr_dllist) && (NULL != static_qr_dllist->qr_static_next))
    GPF_T;
  for (iter = static_qr_dllist; NULL != iter; iter = iter->qr_static_prev)
    {
      if ((iter != static_qr_dllist) && (iter->qr_static_next->qr_static_prev != iter))
        GPF_T;
      if (iter != qr)
        continue;
      printf ("Attempt to add duplicate qr into static_qr_dllist: %p", qr);
      if (gpf_on_dupe)
        GPF_T;
      if (iter->qr_chkmark != 0x1766beef)
        GPF_T;
    }
  if (qr->qr_chkmark != 0x269beef)
    GPF_T;
  qr->qr_static_prev = static_qr_dllist;
  qr->qr_static_next = NULL;
  if (NULL != static_qr_dllist)
    static_qr_dllist->qr_static_next = qr;
  static_qr_dllist = qr;
  qr->qr_chkmark = 0x1766beef;
}

void
static_qr_dllist_remove (query_t *qr)
{
  query_t *iter = static_qr_dllist;
  query_t *prev_qr;
  int qr_found = 0;
  if ((NULL != static_qr_dllist) && (NULL != static_qr_dllist->qr_static_next))
    GPF_T;
  for (iter = static_qr_dllist; NULL != iter; iter = iter->qr_static_prev)
    {
      if ((iter != static_qr_dllist) && (iter->qr_static_next->qr_static_prev != iter))
        GPF_T;
      if (iter->qr_chkmark != 0x1766beef)
        GPF_T;
      if (iter == qr)
        qr_found = 1;
    }
  if (!qr_found)
    GPF_T;
  prev_qr = qr->qr_static_prev;
  if (NULL != prev_qr)
    {
      if ((prev_qr->qr_static_next != qr) || (prev_qr == qr))
        GPF_T;
      prev_qr->qr_static_next = qr->qr_static_next;
    }
  if (NULL != qr->qr_static_next)
    qr->qr_static_next->qr_static_prev = prev_qr;
  if (qr == static_qr_dllist)
    static_qr_dllist = prev_qr;
  qr->qr_static_prev = qr->qr_static_next = NULL;
  qr->qr_chkmark = 0x269beef;
}

#else
query_t *
sql_compile_static (const char *string2, client_connection_t * cli,
	     caddr_t * err, volatile int cr_type)
{
  query_t *qr = NULL;
  sql_tree_t *tree = NULL;
  if (SQLC_STATIC_PRESERVES_TREE == cr_type)
    {
      int cr_tree_type = ((NULL != parse_mtx) && global_scs && !sqlc_inside_sem) ? SQLC_PARSE_ONLY_REC : SQLC_PARSE_ONLY;
      tree = (sql_tree_t *)DBG_NAME(sql_compile_1) (DBG_ARGS string2, cli, err, cr_tree_type, NULL, NULL);
      if (NULL != err[0])
        return NULL;
      cr_type = SQLC_DEFAULT;
    }
  qr = DBG_NAME(sql_compile_1) (DBG_ARGS string2, cli, err, cr_type, tree, NULL);
  dk_free_tree ((caddr_t *)tree);
  return qr;
}
#endif

int sql_proc_use_recompile = 0;

dtp_t
sqlc_find_dtp (int tok, int tok2)
{
  if (ARRAY == tok2)
    return DV_ARRAY_OF_POINTER;
  switch (tok)
    {
      case NUMERIC:
      case DECIMAL_L:
	  return DV_NUMERIC;
      case INTEGER:
	  return DV_LONG_INT;
      case SMALLINT:
	  return DV_SHORT_INT;
      case BIGINT:
	  return DV_INT64;
      case FLOAT_L:
	  return DV_DOUBLE_FLOAT;
      case REAL:
	  return DV_SINGLE_FLOAT;
      case DOUBLE_L:
	  return DV_DOUBLE_FLOAT;
      case VARCHAR:
	  return DV_STRING;
      case NVARCHAR:
      case NCHAR:
	  return DV_WIDE;
      case BINARY:
      case VARBINARY:
	  return DV_BIN;
      case DATETIME:
	  return DV_DATETIME;
      case TIMESTAMP:
	  return DV_TIMESTAMP;
      case TIME:
	  return DV_TIME;
      case DATE_L:
	  return DV_DATE;
      case ANY:
	return DV_ANY;
      case IRI_ID:
	  return DV_IRI_ID;
      case IRI_ID_8:
	  return DV_IRI_ID_8;
    }
  return 0;
}

query_t *
DBG_NAME(sql_proc_to_recompile) (DBG_PARAMS const char *string2, client_connection_t * cli, caddr_t proc_name, int text_is_constant)
{
  query_t *qr = NULL;
  char proc_name_buffer[MAX_QUAL_NAME_LEN];
  caddr_t **lexems;
  int n_lexems, inx = 0;
  dtp_t ret_dtp = 0;

  if (!sql_proc_use_recompile)
    return NULL;

  lexems = (caddr_t **) sql_lex_analyze (string2, NULL, 0, 1, BEGINX);
  n_lexems = BOX_ELEMENTS (lexems);
  if (!proc_name)
    { /* have to find out one using the parser */
      char *q, *o, *n;
      char qb[MAX_NAME_LEN], ob[MAX_NAME_LEN], nb[MAX_NAME_LEN];
      if (n_lexems < 4)
	{
	  dk_free_tree ((box_t) lexems);
	  return NULL;
	}
      if (unbox (lexems[0][2]) != CREATE ||
	  (unbox (lexems[1][2]) != PROCEDURE && unbox (lexems[1][2]) != FUNCTION))
	{ /* check for create procedure */
	  dk_free_tree ((box_t) lexems);
	  return NULL;
	}
      if (unbox (lexems[2][2]) != NAME)
	{ /* procedure views */
	  dk_free_tree ((box_t) lexems);
	  return NULL;
	}
      q = cli->cli_qualifier;
      o = CLI_OWNER (cli);
      n = lexems[2][1];
      if (unbox (lexems[3][2]) == '.')
	{
	  if (n_lexems > 5 && unbox (lexems[4][2]) == '.' && unbox (lexems[5][2]) == NAME)
	    { /* a..b */
	      q = n;
	      o = CLI_OWNER (cli);
	      n = lexems[5][1];
	    }
	  else if (n_lexems > 4 && (unbox (lexems[4][2])) == NAME)
	    { /* a.b */
	      o = n;
	      n = lexems[4][1];
	      if (n_lexems > 6 && unbox (lexems[5][2]) == '.' && unbox (lexems[6][2]) == NAME)
		{ /* a.b.c */
		  q = o;
		  o = n;
		  n = lexems[6][1];
		}
	    }
	}
      strncpy (qb, q, sizeof (qb));
      strncpy (ob, o, sizeof (ob));
      strncpy (nb, n, sizeof (nb));
      sch_normalize_new_table_case (isp_schema (NULL), qb, sizeof (qb), ob, sizeof (ob));
      snprintf (proc_name_buffer, sizeof (proc_name_buffer), "%s.%s.%s", qb, ob, nb);
      proc_name = &(proc_name_buffer[0]);
    }
  _DO_BOX (inx, lexems)
    {
      if (unbox (lexems[inx][2]) == RETURNS && (inx + 1) < n_lexems)
	{
	  ret_dtp = sqlc_find_dtp (unbox (lexems[inx + 1][2]),
				   inx + 2 < n_lexems ? unbox (lexems[inx + 2][2]) : 0);
	  break;
	}
    }
  END_DO_BOX;

  dk_free_tree ((box_t) lexems);
  DK_ALLOC_QUERY (qr);
  qr->qr_to_recompile = 1;

  qr->qr_proc_name = box_string (proc_name);
  qr->qr_qualifier = box_string (cli->cli_qualifier);
  qr->qr_owner = box_string (CLI_OWNER (cli));
  if (cli->cli_user)
    qr->qr_proc_owner = cli->cli_user->usr_id;
  qr->qr_text_is_constant = text_is_constant;
  if (ret_dtp)
    qr->qr_proc_ret_type = list (2, ret_dtp, 0);
  SET_QR_TEXT(qr,string2);
#ifdef QUERY_DEBUG
  log_query_event (qr, 1, "ALLOC+TEXT by sql_proc_to_recompile at %s:%d", file, line);
#endif
  sch_set_proc_def (wi_inst.wi_schema, qr->qr_proc_name, qr);
  return qr;
}


subq_compilation_t *
sqlc_subq_compilation_1 (sql_comp_t * sc, ST * tree, char *name, int scrollables)
{
  DO_SET (subq_compilation_t *, sqc, &sc->sc_subq_compilations)
  {
    if (scrollables || sqc->sqc_query->qr_cursor_type == _SQL_CURSOR_FORWARD_ONLY)
      {
	if (sqc->sqc_tree == tree)
	  return sqc;
	if (name && sqc->sqc_name && 0 == strcmp (sqc->sqc_name, name))
	  return sqc;
      }
  }
  END_DO_SET ();
  if (!name)
    SQL_GPF_T(sc->sc_cc);			/* No subq compilation */
  sqlc_new_error (sc->sc_cc, "34000", "SQ077", "Bad cursor name %s.", name);
  return NULL;
}


subq_compilation_t *
sqlc_subq_compilation (sql_comp_t * sc, ST * tree, char *name)
{
  return sqlc_subq_compilation_1 (sc, tree, name, 0);
}

subq_compilation_t *
sqlc_subquery_1 (sql_comp_t * super_sc, predicate_t * super_pred, ST ** ptree, int cursor_mode, ST **params)
{
  /* compile the subq, stash result in super's sc_subq_compilations. */

  t_NEW_VAR (subq_compilation_t, subq_comp);
  ST *tree = *ptree;
  comp_context_t cc;
  dk_set_t gen_params_set = NULL;
  caddr_t volatile err_save = NULL;
  int is_scalar_subq = 0;
  sql_comp_t sc;
  NEW_VARZ (query_t, qr);
  if (SCALAR_SUBQ == (ptrlong)params)
    {
      params = NULL;
      is_scalar_subq = 1;
    }
  memset (&sc, 0, sizeof (sc));
  memset (subq_comp, 0, sizeof (subq_compilation_t));

  CC_INIT (cc, super_sc->sc_client);
  sc.sc_cc = &cc;
  if (cursor_mode == _SQL_CURSOR_FORWARD_ONLY)
    {
      cc.cc_super_cc = super_sc->sc_cc->cc_super_cc;
      sc.sc_super = super_sc;
    }
  else
    {
      sc.sc_scroll_super = super_sc;
      sc.sc_scroll_param_cols = &gen_params_set;
    }
  cc.cc_query = qr;
  qr->qr_qualifier = box_string (sqlc_client ()->cli_qualifier);
  sc.sc_check_view_sec = super_sc->sc_check_view_sec;
  sc.sc_in_cursor_def = super_sc->sc_in_cursor_def;
  qr->qr_proc_vectored = super_sc->sc_cc->cc_query->qr_proc_vectored;
  if (super_pred)
    sc.sc_no_current_of = 1;	/* subq condition, e.g. exists */
  sc.sc_client = super_sc->sc_client;

  sc.sc_predicate = super_pred;
  subq_comp->sqc_query = qr;
  t_set_push (&super_sc->sc_subq_compilations, (void *) subq_comp);
  sc.sc_col_ref_recs = super_sc->sc_subq_initial_crrs;

  err_save = (caddr_t) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR);
  CATCH (CATCH_LISP_ERROR)
  {
    SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR, NULL);
    if (cursor_mode != _SQL_CURSOR_FORWARD_ONLY)
      {
	int inx;
	sqlc_cursor (&sc, ptree, cursor_mode);
	tree = *ptree;
	subq_comp->sqc_scroll_params = (state_slot_t **) t_list_to_array (gen_params_set);
	DO_BOX (state_slot_t *, sl, inx, subq_comp->sqc_scroll_params)
	  {
	    subq_comp->sqc_scroll_params[inx] =
		scalar_exp_generate (super_sc, (ST *)sl, &super_sc->sc_routine_code);
	  }
	END_DO_BOX;
      }
    else
      {
	sql_stmt_comp (&sc, ptree);
	if (is_scalar_subq)
	  {
	    state_slot_t * ext_sets = ssl_new_variable (super_sc->sc_cc, "ext_sets", DV_LONG_INT);
	    if (!IS_QN (qr->qr_head_node, set_ctr_input)) GPF_T1 ("scalar subq must start w setc ctr");
	    ((set_ctr_node_t*)qr->qr_head_node)->sctr_ext_set_no = ext_sets;
	    qr->qr_select_node->sel_ext_set_no = ext_sets;
	  }
	if (qr->qr_proc_vectored && !sc.sc_check_view_sec)
	  sqlg_vector_subq (&sc);
	tree = *ptree;
      }
    subq_comp->sqc_tree = tree;

    if (sc.sc_cc->cc_query->qr_select_node)
      {
	/* subq selects have a different output processing, no out box */
	sc.sc_cc->cc_query->qr_select_node->src_gen.src_input = (qn_input_fn) select_node_input_subq;
      }
    qr_set_local_code_and_funref_flag (sc.sc_cc->cc_query);
    QR_POST_COMPILE (sc.sc_cc->cc_query, sc.sc_cc);
  }
  THROW_CODE
  {
    caddr_t cc_error = NULL;
    if (qr && qr->qr_proc_name)
      query_free (qr);
    else
      qr_free (qr);
    cc_error = (caddr_t) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR);
    if (!cc_error)
      {
	if (err_save)
	  cc_error = err_save;
	else
	  cc_error = srv_make_new_error ("42000", "SQ075", "Unclassified SQL compilation error.");
      }
    else if (err_save)
      dk_free_tree (err_save);
    qr = NULL;
    sc_free (&sc);
    POP_CATCH;
    sc.sc_cc->cc_error = cc_error;
    SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR, sc.sc_cc->cc_error);
    lisp_throw (CATCH_LISP_ERROR, 1);
  }
  END_CATCH;
  sc.sc_cc->cc_query->qr_super = super_sc->sc_cc->cc_query;
  sc_free (&sc);
  dk_set_push (&super_sc->sc_cc->cc_query->qr_subq_queries, subq_comp->sqc_query);
  return subq_comp;
}


subq_compilation_t *
sqlc_subquery (sql_comp_t * super_sc, predicate_t * super_pred, ST ** ptree)
{
  return sqlc_subquery_1 (super_sc, super_pred, ptree, _SQL_CURSOR_FORWARD_ONLY, NULL);
}


caddr_t
sqlc_convert_odbc_to_sql_type (caddr_t id)
{
  if (!strcmp (id, "SQL_CHAR") || !strcmp (id, "SQL_VARCHAR"))
    return (caddr_t) t_listst (2, (long) DV_LONG_STRING, (long) 0);
  else if (!strcmp (id, "SQL_NUMERIC") || !strcmp (id, "SQL_DECIMAL"))
    return (caddr_t) sqlp_numeric (0, 0);
  else if (!strcmp (id, "SQL_INTEGER"))
    return (caddr_t) t_listst (2, (long) DV_LONG_INT, (long) 0);
  else if (!strcmp (id, "SQL_SMALLINT"))
    return (caddr_t) t_listst (2, (long) DV_SHORT_INT, (long) 0);
  else if (!strcmp (id, "SQL_FLOAT") || !strcmp (id, "SQL_DOUBLE"))
    return (caddr_t) t_listst (2, (long) DV_DOUBLE_FLOAT, (long) 0);
  else if (!strcmp (id, "SQL_REAL"))
    return (caddr_t) t_listst (2, (long) DV_SINGLE_FLOAT, (long) 0);
  else if (!strcmp (id, "SQL_LONGVARCHAR"))
    return (caddr_t) t_listst (2, (long) DV_BLOB,  t_box_num (0x7fffffff));
  else if (!strcmp (id, "SQL_LONGVARBINARY"))
    return (caddr_t) t_listst (2, (long) DV_BLOB_BIN,  t_box_num (0x7fffffff));
  else if (!strcmp (id, "SQL_BINARY"))
    return (caddr_t) t_listst (2, (long) DV_BIN,  t_box_num (0));
  else if (!strcmp (id, "SQL_TIMESTAMP"))
    return (caddr_t) t_listst (3, (long) DV_TIMESTAMP, (long) 10, (long) 6);
  else if (!strcmp (id, "SQL_DATE"))
    return (caddr_t) t_listst (2, (long) DV_DATE, (long) 10);
  else if (!strcmp (id, "SQL_TIME"))
    return (caddr_t) t_listst (2, (long) DV_TIME, (long) 8);
  else if (!strcmp (id, "SQL_WCHAR") || !strcmp (id, "SQL_WVARCHAR"))
    return (caddr_t) t_listst (2, (long) DV_WIDE, (long) 0);
  else if (!strcmp (id, "SQL_WLONGVARCHAR"))
    return (caddr_t) t_listst (2, (long) DV_BLOB_WIDE, t_box_num (0x7fffffff));

  return NULL;
}


#define TEST

#ifdef TEST


void
sqlc_print_error (caddr_t err)
{
  printf ("Error %s: %s\n", ((caddr_t *) err)[1], ((caddr_t *) err)[2]);
  fflush (stdout);
}


#define QR_TEST(t) \
{ \
  caddr_t err;  \
  query_t * qr = sql_compile (t, bootstrap_cli, &err); \
  if (! qr) sqlc_print_error (err); \
  else { qr_print (qr); qr_free (qr);} \
}

void
sqlc_make_post_group_scope (sql_comp_t * sc, ST ** org_selection)
{
}


void
sqlc_test (void)
{
/*
   QR_TEST ("select KEY_TABLE, KEY_NAME, KEY_ID + 1 from SYS_KEYS where KEY_ID > 19 and KEY_CLUSTER_ON_ID = KEY_ID");

   QR_TEST ("select max (KEY_ID) from SYS_KEYS");

   QR_TEST ("select KP_NTH, KP_KEY_ID from SYS_KEY_PARTS where exists (select KEY_ID from SYS_KEYS where KEY_ID = KP_KEY_ID)");
 */
}

#endif


#ifdef MALLOC_DEBUG
#undef sql_compile
query_t *
sql_compile (const char *string2, client_connection_t * cli, caddr_t * err, int store_procs)
{
  return dbg_sql_compile (__FILE__, __LINE__, string2, cli, err, store_procs);
}
#endif

#if defined (MALLOC_DEBUG) || defined (VALGRIND)
#undef sql_compile_static
query_t *
sql_compile_static (const char *string2, client_connection_t * cli, caddr_t * err, volatile int store_procs)
{
  return  dbg_sql_compile_static (__FILE__, __LINE__, string2, cli, err, store_procs);
}
#endif

void
qr_free_1 (query_t * qr)
{
  qr_free (qr);
}

#ifdef MALLOC_DEBUG
#undef qr_free
void
qr_free (query_t * qr)
{
  dbg_qr_free (__FILE__, __LINE__, qr);
}
#endif
