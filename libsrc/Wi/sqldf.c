/*
 *  sqldf.c
 *
 *  $Id$
 *
 *  sql expression dependencies and code layout
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

#include <string.h>
#include "Dk.h"
#include "Dk/Dkpool.h"
#include "libutil.h"
#include "sqlnode.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "lisprdr.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqlpfn.h"
#include "sqlo.h"
#include "list2.h"
#include "remote.h"
#include "sqlrcomp.h"
#include "sqloinv.h"



df_elt_t **df_body_to_array (df_elt_t * body);

id_hashed_key_t
sql_tree_hash_1 (ST * st)
{
  dtp_t dtp = DV_TYPE_OF (st);
  switch (dtp)
    {
    case DV_LONG_INT:
      return (uint32)(ptrlong) unbox ((caddr_t)st);
    case DV_STRING:
    case DV_C_STRING:
    case DV_SYMBOL:
    case DV_UNAME:
      {
	char * str = (char *)st;
	int len = box_length ((caddr_t)st) - 1;
	uint32 hash = 1234567;
	if (len > 10)
	  {
	    int d = len / 2;
	    d &= ~7L;
	    len -= d;
	    str += d;
	  }
	BYTE_BUFFER_HASH (hash, str, len);
	return hash;
      }
    case DV_ARRAY_OF_POINTER:
      {
	int len = BOX_ELEMENTS (st);
	uptrlong first;
	uint32 hash, inx;
	if (!len)
	  return 1;
	first = st->type;
	if (first < 10000)
	  hash = first;
	else
	  hash = sql_tree_hash_1 ((ST*)first);
	if (SELECT_STMT == first && len > 4 && DV_ARRAY_OF_POINTER == DV_TYPE_OF (st->_.select_stmt.selection))
	  {
	    return sql_tree_hash_1 ((ST*)st->_.select_stmt.selection);
	  }
	if (len > 3)
	  len = 3;
	for (inx = 1; inx < len; inx++)
	  hash =  ((hash >> 2) | ((hash & 3 << 30)) ) ^ sql_tree_hash_1 (((ST**)st)[inx]);
	return hash;
      }
    default: return box_hash ((caddr_t)st);
    }
}


id_hashed_key_t
sql_tree_hash (char *strp)
{
  char *str = *(char **) strp;
  return ID_HASHED_KEY_MASK & sql_tree_hash_1 ((ST*)str);
}


static id_hash_t *
sqlo_allocate_df_elts (int size)
{
  return t_id_hash_allocate (size,
      sizeof (caddr_t), sizeof (caddr_t),
      sql_tree_hash, treehashcmp);
}


int
sqlo_has_node (ST * tree, int type)
{
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree))
    {
      int inx;
      if (ST_P (tree, type))
	return 1;
      DO_BOX (ST*, st, inx, tree)
	{
	  if (sqlo_has_node (st, type))
	    return 1;
	}
      END_DO_BOX;
    }
  return 0;
}


df_elt_t *
sqlo_df_elt (sqlo_t * so, ST * tree)
{
  df_elt_t ** place = NULL;
  id_hashed_key_t hash = sql_tree_hash ((caddr_t) &tree);
  if (so->so_df_private_elts)
    {
      place = (df_elt_t **) id_hash_get_with_hash_number (so->so_df_private_elts, (caddr_t) &tree, hash);
      /* if this is not a leaf like col, literal or param, then do not use the global one even if there is one.  Except when there is an aggregate, they must be shared over the whole tree.
      * If this is a dt being refd, must use the global, else will screw up the ot's by adding the froms many times.  */
      if (! (ST_COLUMN (tree, COL_DOTTED) || DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree) || sqlo_has_node (tree, FUN_REF) || ST_P (tree, SELECT_STMT)))
	return place ? *place : NULL;
    }
  if (!place)
    place = (df_elt_t **) id_hash_get_with_hash_number (so->so_df_elts, (caddr_t) &tree, hash);

  if (place)
    return (*place);
  return NULL;
}

size_t
sqlo_df_size (int type)
{
#define df_elt_head ((df_elt_t*)0)->_
  size_t len = (size_t) &df_elt_head;
  switch (type)
    {
      case DFE_CONST:
	  break;
      case DFE_COLUMN:
	  len += sizeof (df_elt_head.col);
	  break;
      case DFE_BOP:
      case DFE_BOP_PRED:
	  len += sizeof (df_elt_head.bin);
	  break;
      case DFE_CALL:
	  len += sizeof (df_elt_head.call);
	  break;
      default:
	  len = sizeof (df_elt_t);
    }
  return len;
}

df_elt_t *
sqlo_new_dfe (sqlo_t * so, int type, ST * tree)
{
#if 0
  TNEW (df_elt_t, dfe);
  memset (dfe, 0, sizeof (df_elt_t));
#else  /* dfe_size */
  df_elt_t * dfe;
  size_t dfe_len = sqlo_df_size (type);

  dfe = (df_elt_t *) t_alloc (dfe_len);
  memset (dfe, 0, dfe_len);
#endif

  dfe->dfe_type = type;
  dfe->dfe_sqlo = so;
  dfe->dfe_tree = tree;
  if (tree)
    {
      id_hashed_key_t hash = sql_tree_hash ((caddr_t)&tree);
      dfe->dfe_hash = hash;
      if (so->so_df_private_elts && type != DFE_COLUMN && type != DFE_CONST && type != DFE_FUN_REF)
	t_id_hash_set_with_hash_number (so->so_df_private_elts, (caddr_t)(&tree), (caddr_t)(&dfe), hash);
      else
	t_id_hash_set_with_hash_number (so->so_df_elts, (caddr_t)(&tree), (caddr_t)(&dfe), hash);
    }
  return dfe;
}

void
sqlo_df_from (sqlo_t * so, df_elt_t * tb_dfe, ST ** from)
{
  /* will do the df graphs of dt's and will add join conds to predicates and will inline suitable dts */
  op_table_t * top_ot = so->so_this_dt;
  DO_SET (op_table_t *, ot, &so->so_this_dt->ot_from_ots)
    {
      df_elt_t * dfe;
      if (ot->ot_dt)
	{
	  dfe = sqlo_new_dfe (so, DFE_DT, NULL);
	  dfe->_.sub.ot = ot;
	  ot->ot_dfe = dfe;
	  top_ot->ot_from_dfes = dk_set_conc (top_ot->ot_from_dfes, t_cons ((void *) dfe, NULL));
	  DO_SET (op_virt_col_t *, vc, &ot->ot_virtual_cols)
	    {
	      sqlo_df_virt_col (so, vc);
	    }
	  END_DO_SET ();
	  sqlo_df (so, ot->ot_dt);
	}
      else
	{
	  dfe = sqlo_new_dfe (so, DFE_TABLE, NULL);
	  dfe->_.table.ot = ot;
	  ot->ot_dfe = dfe;
	  top_ot->ot_from_dfes = dk_set_conc (top_ot->ot_from_dfes, t_cons ((void *) dfe, NULL));
#if 0
	  DO_SET (op_virt_col_t *, vc, &ot->ot_virtual_cols)
	    {
	      sqlo_df_virt_col (so, vc);
	    }
	  END_DO_SET ();
	  if (ot->ot_text_score_limit)
	    sqlo_df (so, ot->ot_text_score_limit);
	  if (ot->ot_text_start)
	    sqlo_df (so, ot->ot_text_start);
	  if (ot->ot_text_end)
	    sqlo_df (so, ot->ot_text_end);
#endif
	}
      if (ot->ot_join_cond)
	{
	  if (ot->ot_is_outer || ot->ot_is_proc_view)
	    {
	      dk_set_t saved_preds = top_ot->ot_preds;
	      so->so_is_top_and = 1;
	      top_ot->ot_preds = NULL;
	      sqlo_df (so, ot->ot_join_cond);
	      ot->ot_join_preds = top_ot->ot_preds;
	      top_ot->ot_preds = saved_preds;
	    }
	  else
	    {
	      so->so_is_top_and = 1;
	      sqlo_df (so, ot->ot_join_cond);
	      ot->ot_join_cond = NULL;
	    }
	  so->so_is_top_and = 0;
	}
    }
  END_DO_SET();
}


void
sqlo_df_array (sqlo_t * so, ST ** arr)
{
  int inx;
  DO_BOX (ST *, elt, inx, arr)
    {
      sqlo_df (so, elt);
    }
  END_DO_BOX;
}


dk_set_t
sqlo_array_deps (sqlo_t * so, ST ** arr)
{
  dk_set_t set = NULL;
  int inx;
  DO_BOX (ST *, elt, inx, arr)
    {
      df_elt_t * dfe = sqlo_df (so, elt);
      if (dfe)
	set = t_set_union (set, dfe->dfe_tables);
    }
  END_DO_BOX;
  return set;
}


void
sqlo_select_deps (sqlo_t * so, df_elt_t * from_dfe)
{
  ST * dt = from_dfe->_.sub.ot->ot_dt;
  ST * top_exp = SEL_TOP (dt);
  dk_set_t set = NULL;
  op_table_t * ot = from_dfe->_.sub.ot;
  set = sqlo_array_deps (so, (ST**) dt->_.select_stmt.selection);
  if (NULL != top_exp)
    {
      df_elt_t *dfe;
      dfe = sqlo_df (so, top_exp->_.top.exp);
      set = t_set_union (set, dfe->dfe_tables);
      dfe = sqlo_df (so, top_exp->_.top.skip_exp);
      set = t_set_union (set, dfe->dfe_tables);
    }

  DO_SET (df_elt_t *, pred, &ot->ot_preds)
    {
      if ((DFE_TRUE != pred) && (DFE_FALSE != pred))
        set = t_set_union (pred->dfe_tables, set);
    }
  END_DO_SET();
  DO_SET (op_table_t *, ot, &from_dfe->_.sub.ot->ot_from_ots)
    {
      if (ot->ot_dt && (
	  ST_P (ot->ot_dt, SELECT_STMT) ||
	  IS_UNION_ST (ot->ot_dt)))
	{
	  df_elt_t *dt_dfe = sqlo_df (so, ot->ot_dt);
	  set = t_set_union (dt_dfe->dfe_tables, set);
	}
    }
  END_DO_SET();
  set = t_set_diff (set, ot->ot_from_ots);
  if (ot->ot_group_ot)
    set = t_set_diff (set, t_cons ((void*) ot->ot_group_ot, NULL));
  DO_SET (op_table_t *, ot, &from_dfe->_.sub.ot->ot_from_ots)
    {
      if (ot->ot_contains_exp)
	set = t_set_diff (set, t_cons ((void *) sqlo_df (so, ot->ot_contains_exp)->_.text.ot, NULL));
    }
  END_DO_SET ();
  from_dfe->dfe_tables = set;
}


sql_type_t
box_sqt (caddr_t xx)
{
  sql_type_t sqt;
  memset (&sqt, 0, sizeof (sqt));
  sqt.sqt_dtp = DV_TYPE_OF (xx);
  if (sqt.sqt_dtp == DV_SYMBOL)
    sqt.sqt_dtp = DV_UNKNOWN;
  if (DV_SHORT_STRING == sqt.sqt_dtp || DV_LONG_STRING == sqt.sqt_dtp)
    sqt.sqt_precision = box_length (xx) - 1;
  else if (DV_NUMERIC == sqt.sqt_dtp)
    {
      sqt.sqt_scale = NUMERIC_MAX_SCALE;
      sqt.sqt_precision = NUMERIC_MAX_PRECISION;
    }
  return sqt;
}


df_elt_t *
sqlo_df_virt_col (sqlo_t * so, op_virt_col_t * vc)
{
  df_elt_t * df = sqlo_df_elt (so, vc->vc_tree);
  if (NULL != df)
    return df;
  df = sqlo_df (so, vc->vc_tree);
  if (DV_UNKNOWN == df->dfe_sqt.sqt_dtp)
    df->dfe_sqt.sqt_dtp = vc->vc_dtp;
  df->_.col.vc = vc;
  return df;
}

int32 sql_const_cond_opt = 1;

df_elt_t *
sqlo_const_cond (sqlo_t * so, df_elt_t * dfe)
{
  /* if the dfe is a cond known at compile time return DFE_TRUE or DFE_FALSE and if not known return the dfe */
  df_elt_t * op, * left, * right;
  if (DFE_FALSE == dfe || DFE_TRUE == dfe || so->so_in_cond_exp || 0 == sql_const_cond_opt)
    return dfe;
  switch (dfe->dfe_type)
    {
    case DFE_BOP_PRED:
    case DFE_BOP:
      switch (dfe->_.bin.op)
	{
	case BOP_NOT:
	  op = sqlo_const_cond (so, dfe->_.bin.left);
	  if (DFE_TRUE == op)
	    return DFE_FALSE;
	  if (DFE_FALSE == op)
	    return DFE_TRUE;
	  else return dfe;
	case BOP_EQ:
	  if (dfe->_.bin.left == dfe->_.bin.right)
	    return DFE_TRUE;
	  return dfe;

	case BOP_NULL:
	  op = dfe->_.bin.left;
	  if (DFE_CONST == op->dfe_type)
	    {
	      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (op->dfe_tree) || DV_SYMBOL == DV_TYPE_OF (op->dfe_tree))
		return dfe; /* in fact a col ref to outside proc scope */
	      return DV_DB_NULL == DV_TYPE_OF (op->dfe_tree) ? DFE_TRUE : DFE_FALSE;
	    }
	  if (DFE_COLUMN == op->dfe_type)
	    {
	      op_table_t * defd = (op_table_t *) op->dfe_tables->data;
	      remote_table_t * rt = defd->ot_table ? find_remote_table (defd->ot_table->tb_name, 0) : NULL;
	      if (defd->ot_table && !defd->ot_is_outer && op->_.col.col && op->_.col.col->col_sqt.sqt_non_null && !rt)
		return DFE_FALSE;
	    }
	  return dfe;
	case BOP_OR:
	  left = sqlo_const_cond (so, dfe->_.bin.left);
	  right = sqlo_const_cond (so, dfe->_.bin.right);
	  if (DFE_TRUE == left || DFE_TRUE == right)
	    return DFE_TRUE;
	  if (DFE_FALSE == left && DFE_FALSE == right)
	    return DFE_FALSE;
	  return dfe;
	case BOP_AND:
	  left = sqlo_const_cond (so, dfe->_.bin.left);
	  right = sqlo_const_cond (so, dfe->_.bin.right);
	  if (DFE_FALSE == left || DFE_FALSE == right)
	    return DFE_FALSE;
	  if (DFE_TRUE == left && DFE_TRUE == right)
	    return DFE_TRUE;
	  return dfe;

	default: return dfe;
	}
    default: return dfe;
    }
}

df_elt_t *
sqlo_wrap_dfe_true_or_false (sqlo_t *so, df_elt_t *const_dfe)
{
  ST *eq = NULL;
  df_elt_t *res;
  if (DFE_TRUE == const_dfe)
    eq = (ST *) t_list (3, BOP_EQ, (ptrlong)1, (ptrlong)1);
  else if (DFE_FALSE == const_dfe)
    eq = (ST *) t_list (3, BOP_EQ, (ptrlong)1, (ptrlong)2);
  else
    GPF_T1 ("sqlo_wrap_dfe_true_or_false for not a const cond");
  res = sqlo_new_dfe (so, DFE_BOP_PRED, eq);
  res->_.bin.op = (int) BOP_EQ;
  res->_.bin.left = sqlo_df (so, eq->_.bin_exp.left);
  res->_.bin.right = sqlo_df (so, eq->_.bin_exp.right);
  return res;
}

void
sqlo_push_pred (sqlo_t *so, df_elt_t *dfe)
{
  df_elt_t * c = sqlo_const_cond (so, dfe);
  if (DFE_TRUE == c)
    return;
  if (DFE_FALSE == c)
    {
      so->so_this_dt->ot_is_contradiction = 1;
      so->so_this_dt->ot_preds = NULL;
      dfe = sqlo_wrap_dfe_true_or_false (so, c);
    }
  t_set_push (&so->so_this_dt->ot_preds, (void*) dfe);
}


static int
sqlo_is_contains_out_col (sqlo_t *so, df_elt_t *dfe, op_table_t *ot)
{
  int inx;
  if (dfe->_.col.vc &&
      (ot->ot_xpath_value == dfe->_.col.vc ||
       ot->ot_text_score == dfe->_.col.vc ||
       ot->ot_attr_range_out == dfe->_.col.vc ||
       ot->ot_main_range_out == dfe->_.col.vc))
    return 1;
  DO_BOX (op_virt_col_t *, vc, inx, ot->ot_text_offband)
    {
      if (dfe->_.col.vc == vc)
	return 1;
    }
  END_DO_BOX;
  return 0;
}

#ifdef MALLOC_DEBUG
#define DBG_SQLO_MP
int32 sqlo_pick_mp_size = 0;
#define SQLO_MP_SAMPLE if (virtuoso_server_initialized && (THR_TMP_POOL)->mp_bytes > sqlo_pick_mp_size) \
    			 sqlo_pick_mp_size = (THR_TMP_POOL)->mp_bytes;
#else
#define SQLO_MP_SAMPLE
#endif


dk_set_t
dfe_tables (df_elt_t * dfe)
{
  if (DFE_FALSE == dfe || DFE_TRUE == dfe)
    return NULL;
  return dfe->dfe_tables;
}


df_elt_t *
sqlo_df (sqlo_t * so, ST * tree)
{
  df_elt_t * dfe = sqlo_df_elt (so, tree);

  if (dfe)
    return dfe;
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &dfe, 8000))
    sqlc_error (so->so_sc->sc_cc, "42000", "Stack Overflow");
  if (DK_MEM_RESERVE)
    sqlc_error (so->so_sc->sc_cc, "42000", "Out of memory");
  SQLO_MP_SAMPLE;
  if (sqlo_max_mp_size > 0 && (THR_TMP_POOL)->mp_bytes > sqlo_max_mp_size)
    {
      sqlc_error (so->so_sc->sc_cc, "42000",
	  "The memory pool size %d reached the limit %d bytes, try to increase the MaxMemPoolSize ini setting",
	  (THR_TMP_POOL)->mp_bytes, sqlo_max_mp_size);
    }
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    {
      dfe = sqlo_new_dfe (so, DFE_CONST, tree);
      dfe->dfe_sqt = box_sqt ((caddr_t) tree);
      return dfe;
    }

  switch (tree->type)
    {
    case SELECT_STMT:
      {
	int old_top_and = so->so_is_top_and;
	op_table_t * prev_dt = so->so_this_dt;
	ST * texp = tree->_.select_stmt.table_exp;
	ST *top_exp = SEL_TOP (tree);
	df_elt_t * head;
	dfe = sqlo_new_dfe (so, DFE_DT, tree);
	head = sqlo_new_dfe (so, DFE_HEAD, NULL);
	so->so_this_dt = sqlo_find_dt (so, tree);
	dfe->_.sub.ot = so->so_this_dt;
	if (NULL != texp)
	  {
	    sqlo_df_from (so, dfe, texp->_.table_exp.from);
	    so->so_is_top_and = 1;
	    sqlo_df (so, texp->_.table_exp.where);
	    sqlo_df (so, texp->_.table_exp.having);
	    so->so_is_top_and = 0;
	  }
	if (NULL != top_exp)
	  {
	    sqlo_df (so, top_exp->_.top.exp);
	    sqlo_df (so, top_exp->_.top.skip_exp);
	  }
	sqlo_df_array (so, (ST **) tree->_.select_stmt.selection);
	if (NULL != texp)
	  sqlo_ot_oby_seq (so, so->so_this_dt);
	so->so_this_dt->ot_preds = dk_set_nreverse (so->so_this_dt->ot_preds);
	so->so_this_dt = prev_dt;
	so->so_is_top_and = old_top_and;
	head->dfe_super = dfe;
	dfe->_.sub.first = head;
	dfe->_.sub.last = head;
	sqlo_select_deps (so, dfe);
	return dfe;
      }
    case SCALAR_SUBQ:
      {
	df_elt_t * dfe = sqlo_df (so, tree->_.bin_exp.left);
	dfe->dfe_type = DFE_VALUE_SUBQ;
	return (dfe);
      }
    case EXISTS_PRED:
      {
	df_elt_t * dfe = sqlo_df (so, tree->_.subq.subq);
	dfe->_.sub.org_in = tree->_.subq.org;
	dfe->dfe_type = DFE_EXISTS;
	if (so->so_is_top_and)
	  sqlo_push_pred (so, dfe);
	return (dfe);
      }
    case COALESCE_EXP:
    case SIMPLE_CASE:
    case SEARCHED_CASE:
    case COMMA_EXP:
      {
	df_elt_t * dfe;
	int was_top, in_cond_exp = so->so_in_cond_exp;
	id_hash_t *old_private_elts;
	int inx;
	dk_set_t set = NULL;

	dfe = sqlo_new_dfe (so, DFE_CONTROL_EXP, tree);
	was_top = so->so_is_top_and;
	so->so_is_top_and = 0;
	so->so_in_cond_exp = 1;
	dfe->_.control.private_elts = (id_hash_t **) t_box_copy ((caddr_t) tree->_.comma_exp.exps);

	DO_BOX (ST *, elt, inx, tree->_.comma_exp.exps)
	  {
	    df_elt_t *elt_dfe;
	    old_private_elts = so->so_df_private_elts;
	    so->so_df_private_elts = dfe->_.control.private_elts[inx] = sqlo_allocate_df_elts (101);
	    elt_dfe = sqlo_df (so, elt);
	    so->so_df_private_elts = old_private_elts;
	    if (elt_dfe && DFE_FALSE != elt_dfe)
	      set = t_set_union (set, elt_dfe->dfe_tables);
	  }
	END_DO_BOX;
	dfe->dfe_tables = set;
	so->so_is_top_and = was_top;
	so->so_in_cond_exp = in_cond_exp;
	return dfe;
      }
    case COL_DOTTED:
      {
	op_table_t * ot;
	df_elt_t * dfe;

	ot = sqlo_cname_ot_1 (so, tree->_.col_ref.prefix, 0);
	if (!ot)
	  {
	    col_ref_rec_t *crr = sqlo_col_or_param (so->so_sc, tree);
	    if (!crr)
	      SQL_GPF_T1 (so->so_sc->sc_cc, "No param found");
	    dfe = sqlo_new_dfe (so, DFE_CONST, tree);
	    dfe->dfe_ssl = crr->crr_ssl;
	    dfe->dfe_sqt = dfe->dfe_ssl->ssl_sqt;
	    return dfe;
	  }
	dfe = sqlo_new_dfe (so, DFE_COLUMN,  tree);
	dfe->dfe_tables = t_cons (ot, NULL);
	if (!dfe->_.col.vc)
	  {
	    DO_SET (op_virt_col_t *, vc, &ot->ot_virtual_cols)
	      {
		if (box_equal ((box_t) tree, (box_t) vc->vc_tree))
		  dfe->_.col.vc = vc;
	      }
	    END_DO_SET();
	  }
	/* GK: the vc takes precedence over the real col
	   this is because of the OFFBAND contains columns */
	if (ot->ot_table && !dfe->_.col.vc)
	  {
	    dfe->_.col.col = tb_name_to_column (ot->ot_table, tree->_.col_ref.name);
	    if (IS_BOX_POINTER (dfe->_.col.col))
	      {
		t_set_pushnew (&ot->ot_table_refd_cols,  dfe->_.col.col);
		dfe->dfe_sqt = dfe->_.col.col->col_sqt;
		return dfe;
	      }
	  }
	if (sqlo_is_contains_out_col (so, dfe, ot))
	  {
	    df_elt_t *cont_dfe;
	    int old_top_and = so->so_is_top_and;
	    so->so_is_top_and = 1;
	    cont_dfe = sqlo_df (so, ot->ot_contains_exp);
	    so->so_is_top_and = old_top_and;
	    dfe->dfe_tables = t_cons (cont_dfe->_.text.ot, dfe->dfe_tables);
	  }

	return dfe;
      }
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case ASG_STMT:
      {
	int was_top = so->so_is_top_and;
	so->so_is_top_and = 0;
	dfe = sqlo_new_dfe (so, DFE_BOP, tree);
	dfe->_.bin.op = (int) tree->type;
	dfe->_.bin.left = sqlo_df (so, tree->_.bin_exp.left);
	dfe->_.bin.right = sqlo_df (so, tree->_.bin_exp.right);
	dfe->dfe_tables = t_set_union (dfe->_.bin.left->dfe_tables, dfe->_.bin.right->dfe_tables);
	so->so_is_top_and = was_top;
	return dfe;
      }
    case BOP_EQ: case BOP_LT: case BOP_LTE:
    case BOP_GT: case BOP_GTE: case BOP_LIKE:
    case BOP_NEQ: case BOP_NULL:
      {
	dfe = sqlo_new_dfe (so, DFE_BOP_PRED, tree);
	dfe->_.bin.op = (int) tree->type;
	dfe->_.bin.left = sqlo_df (so, tree->_.bin_exp.left);
	dfe->_.bin.right = sqlo_df (so, tree->_.bin_exp.right);
	if (dfe->_.bin.right)
	  dfe->dfe_tables = t_set_union (dfe->_.bin.left->dfe_tables, dfe->_.bin.right->dfe_tables);
	else
	  dfe->dfe_tables = dfe->_.bin.left->dfe_tables;
	if (so->so_is_top_and)
	  sqlo_push_pred (so, dfe);
	if (tree->type == BOP_LIKE && tree->_.bin_exp.more)
	  dfe->_.bin.escape = tree->_.bin_exp.more[0];
	return dfe;
      }
    case BOP_AND:
      if (so->so_is_top_and)
	{
	  sqlo_df (so, tree->_.bin_exp.left);
	  sqlo_df (so, tree->_.bin_exp.right);
	  return NULL;
	}
      else
	{
	  dfe = sqlo_new_dfe (so, DFE_BOP, tree);
	  dfe->_.bin.op = (int) tree->type;
	  dfe->_.bin.left = sqlo_df (so, tree->_.bin_exp.left);
	  dfe->_.bin.right = sqlo_df (so, tree->_.bin_exp.right);
	  {
	    df_elt_t * c1 = sqlo_const_cond (so, dfe->_.bin.left);
	    df_elt_t * c2 = sqlo_const_cond (so, dfe->_.bin.right);
	    if ((DFE_FALSE == c1 && DFE_FALSE == c2)
		|| (DFE_TRUE == c1 && DFE_TRUE == c2))
	      dfe = c1;
	    else if (DFE_TRUE == c1)
	      dfe = c2;
	    else if (DFE_TRUE == c2)
	      dfe = c1;
	    if (DFE_FALSE != dfe && DFE_TRUE != dfe)
	      dfe->dfe_tables = t_set_union (dfe_tables (c1), dfe_tables (c2));
	  }
	  return dfe;
	}

    case BOP_OR:
    case BOP_NOT:
      {
	ST **args;
	op_table_t *ot;
	int ctype;
	int was_top = so->so_is_top_and;
	so->so_is_top_and = 0;

 	if (NULL != (args = sqlc_contains_args (tree, &ctype)) &&
	    !sqlo_is_contains_vdb_tb (so,
	      ot = sqlo_cname_ot (so, args[0]->_.col_ref.prefix),
	      ctype, args))
	  {
	    int inx;
	    TNEW (op_table_t, tot);

	    tot->ot_is_group_dummy = 1;
	    tot->ot_dfe = dfe = sqlo_new_dfe (so, DFE_TEXT_PRED, tree);
	    dfe->_.text.type = ctype;
	    dfe->_.text.args = args;
	    dfe->_.text.ot = tot;

	    DO_BOX (ST *, arg, inx, args)
	      {
		df_elt_t *arg_dfe = sqlo_df (so, arg);
		if (arg_dfe->dfe_tables)
		  dfe->dfe_tables = t_set_union (dfe->dfe_tables, arg_dfe->dfe_tables);
	      }
	    END_DO_BOX;
	    /* GK: some of the arguments are really out cols, so they'll have the
	       text ot as dependency */
	    t_set_delete (&dfe->dfe_tables, tot);
	  }
	else if (!so->so_no_text_preds && NULL != (args = sqlc_geo_args (tree, &ctype)))
	  {
	    int inx;
	    TNEW (op_table_t, tot);
	    tot->ot_is_group_dummy = 1;
	    tot->ot_dfe = dfe = sqlo_new_dfe (so, DFE_TEXT_PRED, tree);
	    dfe->_.text.type = ctype;
	    dfe->_.text.args = args;
	    dfe->_.text.geo = ctype;
	    dfe->_.text.ot = tot;
	    DO_BOX (ST *, arg, inx, args)
	      {
		df_elt_t *arg_dfe = sqlo_df (so, arg);
		if (arg_dfe->dfe_tables)
		  dfe->dfe_tables = t_set_union (dfe->dfe_tables, arg_dfe->dfe_tables);
	      }
	    END_DO_BOX;
	  }
	else
	  {
	    dfe = sqlo_new_dfe (so, DFE_BOP, tree);
	    dfe->_.bin.op = (int) tree->type;
	    dfe->_.bin.left = sqlo_df (so, tree->_.bin_exp.left);
	    dfe->_.bin.right = sqlo_df (so, tree->_.bin_exp.right);
	    dfe->dfe_tables = t_set_union (dfe_tables (dfe->_.bin.left), dfe_tables (dfe->_.bin.right));
	  }
	if (BOP_OR == tree->type)
	  {
	    df_elt_t * c1 = sqlo_const_cond (so, dfe->_.bin.left);
	    df_elt_t * c2 = sqlo_const_cond (so, dfe->_.bin.right);
	    if ((DFE_FALSE == c1 && DFE_FALSE == c2)
		|| (DFE_TRUE == c1 && DFE_TRUE == c2))
	      dfe = c1;
	    else if (DFE_FALSE == c1)
	      dfe = c2;
	    else if (DFE_FALSE == c2)
	      dfe = c1;
	    if (DFE_FALSE != dfe && DFE_TRUE != dfe)
	      dfe->dfe_tables = t_set_union (dfe_tables (c1), dfe_tables (c2));
	  }
	else if (BOP_NOT == tree->type && DFE_TEXT_PRED != dfe->dfe_type) /* a text pred tree starts with a not but this branch is not for it */
	  {
	    df_elt_t * c1 = sqlo_const_cond (so, dfe->_.bin.left);
	    if (DFE_FALSE == c1)
	      dfe = DFE_TRUE;
	    else if (DFE_TRUE == c1)
	      dfe = DFE_FALSE;
	  }
	if (was_top)
	  sqlo_push_pred (so, dfe);
	so->so_is_top_and = was_top;
	return dfe;
      }
    case UNION_ST: case UNION_ALL_ST:
    case INTERSECT_ST: case INTERSECT_ALL_ST:
    case EXCEPT_ST: case EXCEPT_ALL_ST:
      {
	int was_top = so->so_is_top_and;
	so->so_is_top_and = 0;
	dfe = sqlo_new_dfe (so, DFE_QEXP, tree);
	dfe->_.qexp.op = (int) tree->type;
	dfe->_.qexp.terms = (df_elt_t **) t_list (2, sqlo_df (so, tree->_.set_exp.left),
						  sqlo_df (so, tree->_.set_exp.right));
	so->so_is_top_and = was_top;
	dfe->dfe_tables = t_set_union (
	    dfe->_.qexp.terms[0]->dfe_tables,
	    dfe->_.qexp.terms[1]->dfe_tables);
	return dfe;
      }
    case BOP_AS:
      return (sqlo_df (so, tree->_.as_exp.left));
    case FUN_REF:
      {
	op_table_t * ot = sqlo_cname_ot (so, tree->_.fn_ref.fn_name);
	df_elt_t * res = sqlo_new_dfe (so, DFE_FUN_REF, tree);
	int saved_top_and = so->so_is_top_and;
	so->so_is_top_and = 0;
	if (NULL != tree->_.fn_ref.fn_arg)
	  sqlo_df (so, tree->_.fn_ref.fn_arg);
	else
	  {
	    int arginx;
	    _DO_BOX_FAST (arginx, tree->_.fn_ref.fn_arglist)
	      sqlo_df (so, tree->_.fn_ref.fn_arg);
	    END_DO_BOX_FAST;
	  }
	so->so_is_top_and = saved_top_and;
	if (!ot->ot_group_ot)
	  {
	    ST *dt = ot->ot_dt;
	    t_NEW_VARZ (op_table_t, got);
	    ot->ot_group_ot = got;
	    got->ot_is_group_dummy = 1;
	    ot->ot_group_dfe = sqlo_new_dfe (so, DFE_GROUP, NULL);
	    ot->ot_group_dfe->_.setp.specs = dt->_.select_stmt.table_exp->_.table_exp.group_by;
	    ot->ot_group_dfe->_.setp.top_cnt = sqlo_select_top_cnt (so, SEL_TOP (dt));
	    ot->ot_group_dfe->_.setp.ot = got;
	    got->ot_dfe = ot->ot_group_dfe;
	  }
	res->dfe_tables = t_cons (ot->ot_group_ot, NULL);
	return res;
      }
    case CALL_STMT:
      {
	df_elt_t * f = NULL;
	df_elt_t * dfe = sqlo_new_dfe (so, DFE_CALL, tree);
	dk_set_t deps = NULL;
	int inx;
	int was_top = so->so_is_top_and;
	so->so_is_top_and = 0;
	if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree->_.call.name) && BOX_ELEMENTS (tree->_.call.name) == 1)
	  f = sqlo_df (so, ((ST **) tree->_.call.name)[0]);
	else
	  dfe->_.call.func_name =
	      (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree->_.call.name)) ?
	      t_box_copy (((caddr_t *) tree->_.call.name)[0]) : t_box_copy (tree->_.call.name);
	if (f)
	  deps = f->dfe_tables;
	deps = t_set_union (deps, sqlo_array_deps (so, tree->_.call.params));
	dfe->dfe_tables = deps;
	dfe->_.call.args = (df_elt_t **) t_box_copy ((caddr_t) tree->_.call.params);
	DO_BOX (ST *, elt, inx, tree->_.call.params)
	  {
	    dfe->_.call.args[inx] = sqlo_df (so, elt);
	  }
	END_DO_BOX;
	so->so_is_top_and = was_top;
	return dfe;
      }
    case PROC_TABLE:
      return NULL; /* XXX for now */
    case QUOTE:
      return (sqlo_new_dfe (so, DFE_CONST, tree));
    case KWD_PARAM:
      {
	int was_top = so->so_is_top_and;
	so->so_is_top_and = 0;
        dfe = sqlo_new_dfe (so, DFE_BOP, tree);
	dfe->_.bin.op = KWD_PARAM;
	dfe->_.bin.left = sqlo_df (so, (ST *) tree->_.bin_exp.right);
	dfe->_.bin.right = sqlo_new_dfe (so, DFE_CONST, 0);
	if (dfe->_.bin.left)
          {
	    dfe->dfe_sqt = dfe->_.bin.left->dfe_sqt;
	    dfe->dfe_tables = dfe->_.bin.left->dfe_tables;
	  }
        else
	  SQL_GPF_T1 (so->so_sc->sc_cc, "Bad value for a keyword parameter");
	so->so_is_top_and = was_top;
        return dfe;
      }
    }
  SQL_GPF_T1 (so->so_sc->sc_cc, "Bad tree in sqlo_df");
  return NULL;
}

df_elt_t *
dfe_container (sqlo_t * so, int type, df_elt_t * super)
{
  df_elt_t * top = sqlo_new_dfe (so, type, NULL);
  df_elt_t * head = sqlo_new_dfe (so, DFE_HEAD, NULL);
  top->dfe_super = super;
  head->dfe_super = top;
  top->_.sub.first = head;
  top->_.sub.last = head;
  return top;
}


void
sqlo_place_dfe_after (sqlo_t * so, locus_t * loc, df_elt_t * after_this, df_elt_t * dfe)
{
  df_elt_t * super = after_this->dfe_super;
  /*
  if (so->so_place_code_forr_cond && dfe->dfe_is_placed)
    return;
    */
#ifdef L2_DEBUG
  {
    if (dfe->dfe_next || dfe->dfe_prev)
      /*GPF_T1 ("placing already placed")*/;
  }
#endif
  dfe->dfe_next = NULL;
  dfe->dfe_prev = NULL;
  L2_INSERT_AFTER (super->_.sub.first, super->_.sub.last, after_this, dfe, dfe_);
  if (DFE_TABLE == dfe->dfe_type)
    dfe->_.table.ot->ot_locus = loc;
  if (DFE_DT == dfe->dfe_type)
    dfe->_.sub.ot->ot_locus = loc;
  dfe->dfe_sqlo = so;
  dfe->dfe_super = super;
  dfe->dfe_locus = loc;
  dfe->dfe_is_placed = DFE_PLACED;
  if (so->so_gen_pt == after_this)
    so->so_gen_pt = dfe;
  sqlo_dfe_type (so, dfe);
}


void
sqlo_dfe_type (sqlo_t * so, df_elt_t * dfe)
{
  switch (dfe->dfe_type)
    {
    case DFE_BOP:
      if (!dfe->_.bin.right)
	dfe->dfe_sqt = dfe->_.bin.left->dfe_sqt;
      else
	{
	  dfe->dfe_sqt.sqt_dtp = MAX (dfe->_.bin.left->dfe_sqt.sqt_dtp, dfe->_.bin.right->dfe_sqt.sqt_dtp);
	  if (DV_NUMERIC == dfe->dfe_sqt.sqt_dtp)
	    {
	      dfe->dfe_sqt.sqt_precision = NUMERIC_MAX_PRECISION;
	      dfe->dfe_sqt.sqt_scale = NUMERIC_MAX_SCALE;
	    }
	}
      break;
    }
}


int
st_col_index (sqlo_t *so, op_table_t *dt_ot, caddr_t name)
{
  ST *tree = dt_ot->ot_dt;
  int inx, inx_found = -1;
  ST * left = sqlp_union_tree_select (tree);
  DO_BOX (ST *, sel, inx, left->_.select_stmt.selection)
    {
      if (!ST_P (sel, BOP_AS))
	SQL_GPF_T1 (so->so_sc->sc_cc, "left select of set exp must consist of AS decls");
      if (0 == strcmp (sel->_.as_exp.name, name))
	{
	  if (inx_found != -1)
	    sqlc_new_error (so->so_sc->sc_cc, "42S22", "SQ149",
		"The column '%.100s' was specified multiple times for '%.100s'",
		name,
		dt_ot->ot_prefix ? dt_ot->ot_prefix : "<unnamed>");
	  else
	    inx_found = inx;
	}
    }
  END_DO_BOX;
  if (inx_found != -1)
    return inx_found;
  SQL_GPF_T1 (so->so_sc->sc_cc, "column not found in dt AS list");
  return 0;
}


void
sqlo_dfe_set_dt_exps_is_placed (sqlo_t *so, op_table_t *ot, int flag)
{
  DO_SET (op_table_t *, sot, &ot->ot_from_ots)
    {
      if (sot->ot_dfe)
	sot->ot_dfe->dfe_is_placed = flag;
    }
  END_DO_SET ();
}

void
sqlo_mark_oby_crossed (sqlo_t * so, df_elt_t * dfe)
{
  /* an exp is refd from the other side of an oby and thus must be added to the deps of the oby if not key of oby */
  df_elt_t * oby = so->so_crossed_oby;
  if (!oby)
    return;
  if (so->so_nth_select_col >= BOX_ELEMENTS (oby->_.setp.oby_dep_cols)) GPF_T1 ("oby dep col outside the range of the select");
  t_set_pushnew (&oby->_.setp.oby_dep_cols[so->so_nth_select_col], (void*)dfe);
}


void
sqlo_dt_col_card (sqlo_t * so, df_elt_t * col_dfe, df_elt_t * exp)
{
  col_dfe->_.col.card += dfe_exp_card (so, exp);
}


df_elt_t *
sqlo_dt_nth_col (sqlo_t * so, df_elt_t * super, df_elt_t * dt_dfe, int inx, df_elt_t * col_dfe, int is_qexp_term)
{
  char * col_alias;
  df_elt_t * exp_alias;
  so->so_nth_select_col = inx;
  if (DFE_DT == dt_dfe->dfe_type)
    {
      if (dt_dfe->_.sub.generated_dfe)
	{
	  return (sqlo_dt_nth_col (so, super, dt_dfe->_.sub.generated_dfe, inx, col_dfe, is_qexp_term));
	}
      if (DFE_QEXP == sqlo_df (so, dt_dfe->_.sub.ot->ot_dt)->dfe_type)
        {
	  /* basically the same as the generated_dfe case, but the generated_dfe comes here after a layout_copy */
	  return sqlo_dt_nth_col (so, dt_dfe, dt_dfe->_.sub.first->dfe_next, inx, col_dfe, is_qexp_term);
	}
      if (!dt_dfe->_.sub.dt_out)
	{
	  dt_dfe->_.sub.dt_out = (df_elt_t **) t_alloc_box (box_length ((caddr_t) dt_dfe->_.sub.ot->ot_dt->_.select_stmt.selection), DV_ARRAY_OF_POINTER);
	  memset (dt_dfe->_.sub.dt_out, 0, box_length ((caddr_t) dt_dfe->_.sub.ot->ot_dt->_.select_stmt.selection));
	}
      if (dt_dfe->_.sub.dt_out[inx])
	{
	  df_elt_t * exp = sqlo_df (so, (ST*) dt_dfe->_.sub.ot->ot_dt->_.select_stmt.selection[inx]);
	  if (exp)
	    {
	      if (!col_dfe->_.col.card)
		sqlo_dt_col_card (so, col_dfe, exp);
	      sqt_max_desc (&col_dfe->dfe_sqt, &exp->dfe_sqt);
	    }
	  col_dfe->dfe_locus = dt_dfe->dfe_locus;
	  col_alias = ((ST**)(dt_dfe->_.sub.ot->ot_left_sel->_.select_stmt.selection))[inx]->_.as_exp.name;
	  exp_alias = sqlo_df (so, (ST*) t_list (3, COL_DOTTED, dt_dfe->_.sub.ot->ot_new_prefix, col_alias));
	  if (is_qexp_term &&
	      IS_BOX_POINTER (dt_dfe->dfe_locus) && dt_dfe->dfe_locus != super->dfe_locus)
	    dfe_loc_result (dt_dfe->dfe_locus, super, exp);
	  else
	    dfe_loc_result (dt_dfe->dfe_locus, super, exp_alias);
	}
      else
	{
	  df_elt_t *pt = so->so_gen_pt;
	  df_elt_t * exp = sqlo_df (so, (ST*) dt_dfe->_.sub.ot->ot_dt->_.select_stmt.selection[inx]);
	  so->so_gen_pt = dt_dfe->_.sub.last;
	  dt_dfe->_.sub.dt_out[inx] = exp;
	  /* GK: done because the dts are already unplaced, but may be in the deps part of the exp */
	  sqlo_dfe_set_dt_exps_is_placed (so, dt_dfe->_.sub.ot, 1);
	  sqlo_place_exp (so, dt_dfe, exp);
	  sqlo_dfe_set_dt_exps_is_placed (so, dt_dfe->_.sub.ot, 0);
	  if (exp)
	    {
	      sqlo_dt_col_card (so, col_dfe, exp);
	      sqt_max_desc (&col_dfe->dfe_sqt, &exp->dfe_sqt);
	    }
	  if (so->so_place_code_forr_cond)
	    sqlo_post_oby_ref (so, dt_dfe, exp, inx);

	  col_alias = ((ST**)(dt_dfe->_.sub.ot->ot_left_sel->_.select_stmt.selection))[inx]->_.as_exp.name;
	  exp_alias = sqlo_df (so, (ST*) t_list (3, COL_DOTTED, dt_dfe->_.sub.ot->ot_new_prefix, col_alias));

	  so->so_gen_pt = pt;
	  col_dfe->dfe_locus = dt_dfe->dfe_locus;
	  if (is_qexp_term &&
	      IS_BOX_POINTER (dt_dfe->dfe_locus) && dt_dfe->dfe_locus != super->dfe_locus)
	    dfe_loc_result (dt_dfe->dfe_locus, super, exp);
	  else
	    dfe_loc_result (dt_dfe->dfe_locus, super, exp_alias);
	}
    }
  else if (DFE_QEXP == dt_dfe->dfe_type)
    {
      int tinx;
      DO_BOX (df_elt_t *, term, tinx, dt_dfe->_.qexp.terms)
	{
	  sqlo_dt_nth_col (so, super, term, inx, col_dfe, 1);
	}
      END_DO_BOX;
      col_dfe->dfe_locus = LOC_LOCAL; /* a union will not be passed through. A result of union is local */
    }
  return NULL;
}


void
dfe_loc_result (locus_t * loc_from, df_elt_t * requiring, df_elt_t * required)
{
  if (!IS_BOX_POINTER (loc_from)
      || (requiring->dfe_locus == required->dfe_locus && required->dfe_type != DFE_CALL) /* can happen it's a standard function in same scope but result required */
      || required->dfe_type == DFE_CONST)
    return;
  {
    TNEW (locus_result_t, ref);
    ref->lr_requiring = requiring;
    ref->lr_required = required;
    ref->lr_locus = loc_from;
    t_set_push (&loc_from->loc_results, (void*) ref);
    t_set_push (&requiring->dfe_remote_locus_refs, (void*) ref);
  }
}


df_elt_t *
dfe_inx_op_col_def_table (df_inx_op_t * dio, df_elt_t * col_dfe, df_elt_t * except_tb)
{
  /* if the iop contains the table defining the col, return the defining table dfe */
  if (dio->dio_table == except_tb)
    return NULL;
  if (dio->dio_table
      && dfe_defines (dio->dio_table, col_dfe))
    return dio->dio_table;
  DO_SET  (df_inx_op_t *, term, &dio->dio_terms)
    {
      df_elt_t *def_dfe = dfe_inx_op_col_def_table (term, col_dfe, except_tb);
      if (def_dfe)
	return def_dfe;
    }
  END_DO_SET();
  return NULL;
}


df_elt_t *
sqlo_place_col (sqlo_t * so, df_elt_t * super, df_elt_t * dfe)
{
  locus_t * loc = super->dfe_locus;
  op_table_t * ot = (op_table_t *) dfe->dfe_tables->data;
  df_elt_t * tb_dfe;
  tb_dfe = dfe_col_def_dfe (so, dfe);
  if (!tb_dfe)
    SQL_GPF_T1 (so->so_sc->sc_cc, "unknown table for a column dfe");
  switch (tb_dfe->dfe_type)
    {
    case DFE_TABLE:
      if (!dk_set_member (tb_dfe->_.table.out_cols, (void*) dfe))
	{
	  dfe->_.col.card = 0;
	  dfe->_.col.is_fixed = 0;
	  if (!dfe->_.col.vc)
	    t_set_push (&tb_dfe->_.table.out_cols, (void*) dfe);
	  sqlo_rdf_col_card (so, tb_dfe, dfe);
	  if (HR_REF == tb_dfe->_.table.hash_role)
	    {
	      df_elt_t * old_pt = so->so_gen_pt;
	      so->so_gen_pt = tb_dfe->_.table.hash_filler;
	      sqlo_place_col (so, super, dfe);
	      so->so_gen_pt = old_pt;
	    }
	}
      dfe->dfe_locus = tb_dfe->dfe_locus;
      if (IS_BOX_POINTER (tb_dfe->dfe_locus) && loc != tb_dfe->dfe_locus)
	dfe_loc_result (tb_dfe->dfe_locus, super, dfe);
      return tb_dfe;
    case DFE_DT:
      if (ST_P (ot->ot_dt, PROC_TABLE))
	return tb_dfe;
      else
	{
	  int inx = st_col_index (so, ot, dfe->dfe_tree->_.col_ref.name);
	  if (!tb_dfe->_.sub.dt_out)
	    tb_dfe->_.sub.dt_out = (df_elt_t **) t_alloc_box (
		box_length ((caddr_t) ot->ot_left_sel->_.select_stmt.selection),
		DV_ARRAY_OF_POINTER);
	  sqlo_dt_nth_col (so, super, tb_dfe, inx, dfe, 0);
	  dfe->dfe_is_placed = DFE_PLACED;
	  /* XXX: this confuses the already set correct value from sqlo_dt_nth_col
	     tb_dfe->_.sub.dt_out[inx] = dfe;*/
	  return tb_dfe;
	}

    default:
      SQL_GPF_T1 (so->so_sc->sc_cc, "not a possible col def dfe");
    }
  return NULL;
}


dk_set_t
sqlo_connective_list (df_elt_t * dfe, int op)
{
  if ((DFE_TRUE == dfe) || (DFE_FALSE == dfe))
    return (t_cons (dfe, NULL));
  if ((DFE_BOP_PRED == dfe->dfe_type
       || DFE_BOP == dfe->dfe_type)
      && dfe->_.bin.op == op)
    {
      if (op == BOP_NOT)
	return (t_cons ((void *) dfe->_.bin.left, NULL));
      return (dk_set_conc (sqlo_connective_list (dfe->_.bin.left, op),
			   sqlo_connective_list (dfe->_.bin.right, op)));
    }
  else
    return (t_cons (dfe, NULL));
}


int
box_is_subtree (caddr_t box, caddr_t subtree)
{
  if (box_equal (box, subtree))
    return 1;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (box))
    {
      int inx;
      DO_BOX (caddr_t, elt, inx, ((caddr_t*)box))
	{
	  if (box_is_subtree (elt, subtree))
	    return 1;
	}
      END_DO_BOX;
    }
  return 0;
}


df_elt_t *
dfe_skip_exp_dfes (df_elt_t * dfe, df_elt_t ** placing_value_subqs, int n_subqs)
{
  /* skip all exp dfe's, returning the last dfe of the exp dfe's starting at dfe.
  * The point is that when placing invariants x and y where y contains x the thing goes circular unless y sees x as computed before it
  * Exception when value subqs are nested.  The inner subq goes before the containing subq */
  while (dfe->dfe_next)
    {
      df_elt_t * next = dfe->dfe_next;
      switch (next->dfe_type)
	{
	case DFE_BOP:
	case DFE_CALL:
	case DFE_CONTROL_EXP:
	  break;
	case DFE_VALUE_SUBQ:
	  if (placing_value_subqs)
	    {
	      int inx;
	      for (inx = 0; inx < n_subqs; inx++)
		{
		  if (next &&
		      placing_value_subqs[inx] &&
		      box_is_subtree ((caddr_t) next->dfe_tree,
			(caddr_t) placing_value_subqs[inx]->dfe_tree))
		      return dfe;
		}
	    }
	  break;
	default:
	  return dfe;
	}
      dfe = next;
    }
  return dfe;
}


int enable_min_card = 1;

df_elt_t *
dfe_super_or_prev (df_elt_t * dfe)
{
  while (dfe)
    {
      if (dfe->dfe_super)
	return dfe->dfe_super;
      dfe = dfe->dfe_prev;
    }
  return NULL;
}

int
dfe_is_super (df_elt_t *super, df_elt_t * sub)
{
  for (sub = sub; sub; sub = dfe_super_or_prev (sub))
    {
      if (super == sub)
	return 1;
    }
  return 0;
}


df_elt_t *
dfe_skip_to_min_card (df_elt_t * place, df_elt_t * super, df_elt_t * dfe)
{
  /* when placing a func, see if some place later in the query has lower card */
  df_elt_t * best = place;
  float best_arity = 1, arity = 1;
  if (!enable_min_card)
    return place;
  if (!dfe->dfe_tables)
    return place;
  while (place)
    {
      if (dfe_is_super (place, super))
	break;
      switch (place->dfe_type)
	{
	case DFE_TABLE:
	  if (place->_.table.is_being_placed)
	    goto over;
	  break;
	case DFE_DT:
	case DFE_VALUE_SUBQ:
	case DFE_EXISTS:
	  if (place->_.sub.is_being_placed)
	    goto over;
	  break;
	case DFE_QEXP:
	    goto over;
	}
      if (DFE_TABLE == place->dfe_type || DFE_DT == place->dfe_type)
	{
	  arity *= place->dfe_arity * 0.99;
	  /* .99 so that this will prefer placing after a unique rather than before it, a unique might always not hit */
	  if (arity < best_arity)
	    {
	      best_arity = arity;
	      best = place;
	    }
	}
      place = place->dfe_next;
    }
 over:
  return best;
}


int
dfe_defines (df_elt_t * defining, df_elt_t * defd)
{
  if (!defd)
    return 0;
  if (defd == defining)
    return 1;
  if (defining->dfe_tree
      /*&& defining->dfe_hash == defd->dfe_hash */
      && box_equal ((box_t) defining->dfe_tree, (box_t) defd->dfe_tree))
    return 1;
  if (DFE_COLUMN == defd->dfe_type)
    {
      if (DFE_TABLE == defining->dfe_type)
	{
	  if (0 == strcmp (defining->_.table.ot->ot_new_prefix, defd->dfe_tree->_.col_ref.prefix))
	    return 1;
	  if (defining->_.table.inx_op
	      && dfe_inx_op_col_def_table (defining->_.table.inx_op, defd, defining))
	    return 1;
	    {
	    }
	}
      if (DFE_DT == defining->dfe_type)
	{
	  if (0 == strcmp (defining->_.sub.ot->ot_new_prefix, defd->dfe_tree->_.col_ref.prefix))
	    return 1;
	}
    }
  if (DFE_GROUP == defining->dfe_type && DFE_FUN_REF == defd->dfe_type)
    {
      DO_SET (ST *, fref, &defining->_.setp.fun_refs)
	{
	  if (box_equal ((box_t) fref, (box_t) defd->dfe_tree))
	    return 1;
	}
      END_DO_SET();
    }

  return 0;
}


int
dfe_defines_any (df_elt_t * pt, int n, df_elt_t ** dfes)
{
  int inx;
  for (inx = 0; inx < n; inx++)
    if (dfe_defines (pt, dfes[inx]))
      return 1;
  return 0;
}


#define DFE_DEFD_IN_SUPER ((df_elt_t *) -1)

df_elt_t *
dfe_latest_up (df_elt_t * pt, int n, df_elt_t ** dfes)
{
  while (pt)
    {
      if (dfe_defines_any (pt, n, dfes))
	return DFE_DEFD_IN_SUPER;
      if (pt->dfe_prev)
	return (pt->dfe_prev);
      pt = pt->dfe_super;
      if (pt)
	pt = dfe_skip_exp_dfes (pt, dfes, n);
    }
  return NULL;
}


df_elt_t *
dfe_latest (sqlo_t * so, int n_dfes, df_elt_t ** dfes, int default_to_top)
{
  df_elt_t * pt;

  if (so->so_place_code_forr_cond)
    {
      if (default_to_top)
	return so->so_gen_pt;
      else
	return NULL;
    }

  if (!n_dfes)
    {
      if (default_to_top)
	return (so->so_dfe->_.sub.first);
      return NULL;
    }

  pt = so->so_gen_pt;

  while (pt)
    {
      if (dfe_defines_any (pt, n_dfes, dfes))
	return pt;
      if (DFE_ORDER == pt->dfe_type)
	so->so_crossed_oby = pt;
      if (pt->dfe_prev)
	pt = pt->dfe_prev;
      else
	{
	  df_elt_t * sup = dfe_latest_up (pt, n_dfes, dfes);
	  if (!sup)
	    break;
	  if (DFE_DEFD_IN_SUPER == sup)
	    return pt;
	  pt = sup;
	}
    }
  if (default_to_top)
    return (so->so_dfe->_.sub.first);
  return NULL;
}


df_elt_t *
dfe_col_def_dfe (sqlo_t * so, df_elt_t * col_dfe)
{
  df_elt_t * pt;
  pt = so->so_gen_pt;

  while (pt)
    {
      if (dfe_defines (pt, col_dfe))
	{
	  if (DFE_TABLE == pt->dfe_type && pt->_.table.inx_op)
	    {
	      df_elt_t * tb_in_inx_op = dfe_inx_op_col_def_table (pt->_.table.inx_op, col_dfe, pt);
	      if (tb_in_inx_op)
		return tb_in_inx_op;
	    }
	  return pt;
	}
      if (DFE_ORDER == pt->dfe_type)
	so->so_crossed_oby = pt;
      if (pt->dfe_prev)
	pt = pt->dfe_prev;
      else
	{
	  df_elt_t * sup = pt->dfe_super;
	  if (!sup)
	    return NULL;
	  if (DFE_PRED_BODY == sup->dfe_type)
	    sup = sup->dfe_super;
	  if (dfe_defines (sup, col_dfe))
	    return sup;
	  pt = sup;
	}
    }
  return NULL;
}

int
dfe_inx_op_defines_ot (df_inx_op_t * dio, op_table_t * ot, df_elt_t * except)
{
  /* True if iop contains the table of the ot */
  if (dio->dio_table == except)
    return 0;
  if (dio->dio_table && dio->dio_table->_.table.ot == ot)
    return 1;
  DO_SET  (df_inx_op_t *, term, &dio->dio_terms)
    {
      if (dfe_inx_op_defines_ot  (term, ot, except))
	return 1;
    }
  END_DO_SET();
  return 0;
}


int
dfe_defines_ot (df_elt_t * defining, op_table_t * ot)
{
  if (DFE_TABLE == defining->dfe_type)
    {
      if(ot == defining->_.table.ot)
	return 1;
      if (defining->_.table.inx_op && dfe_inx_op_defines_ot (defining->_.table.inx_op, ot, defining))
	return 1;
      return 0;
    }
  if (DFE_DT == defining->dfe_type && ot == defining->_.sub.ot)
    return 1;
  if (DFE_GROUP == defining->dfe_type && ot == defining->_.setp.ot)
    return 1;
  return 0;
}



int
dfe_defines_any_ot (df_elt_t * pt, int n, op_table_t ** ots)
{
  int inx;
  for (inx = 0; inx < n; inx++)
    if (dfe_defines_ot (pt, ots[inx]))
      return 1;
  return 0;
}


#define DFE_DEFD_IN_SUPER ((df_elt_t *) -1)

df_elt_t *
dfe_latest_up_by_ot (df_elt_t * pt, int n, op_table_t ** ots)
{
  while (pt)
    {
      if (dfe_defines_any_ot (pt, n, ots))
	return DFE_DEFD_IN_SUPER;
      if (pt->dfe_prev)
	return (pt->dfe_prev);
      pt = pt->dfe_super;
    }
  return NULL;
}


df_elt_t *
dfe_latest_by_ot (sqlo_t * so, int n_ots, op_table_t ** ots, int default_to_top)
{
  df_elt_t * pt;

  if (so->so_place_code_forr_cond)
    {
      if (default_to_top)
	return so->so_gen_pt;
      else
	return NULL;
    }

  if (!n_ots)
    {
      if (default_to_top)
	return (so->so_dfe->_.sub.first);
      return NULL;
    }

  pt = so->so_gen_pt;

  while (pt)
    {
      if (dfe_defines_any_ot (pt, n_ots, ots))
	return pt;
      if (pt->dfe_prev)
	pt = pt->dfe_prev;
      else
	{
	  df_elt_t * sup = dfe_latest_up_by_ot (pt, n_ots, ots);
	  if (!sup)
	    break;
	  if (DFE_DEFD_IN_SUPER == sup)
	    return pt;
	  pt = sup;
	}
    }
  if (default_to_top)
    return (so->so_dfe->_.sub.first);
  return NULL;
}


void
sqlo_place_control_cols (sqlo_t * so, df_elt_t * super, ST * tree)
{
  if (ST_COLUMN (tree, COL_DOTTED))
    sqlo_place_exp (so, super, sqlo_df (so, tree));
  else if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree))
    {
      int inx;
      DO_BOX (ST *, sub, inx, (ST**)tree)
	{
	  sqlo_place_control_cols (so, super, sub);
	}
      END_DO_BOX;
    }
}

int
sqlo_is_const_call (ST * tree)
{
  if (!ARRAYP (tree))
    return 1;
  switch (tree->type)
    {
      case CALL_STMT:
	    {
	      caddr_t * pars = (caddr_t *) tree->_.call.params;
	      int inx;
	      DO_BOX (ST *, exp, inx, pars)
		{
		  if (!stricmp (tree->_.call.name, "_cvt") && !inx)
		    continue;
		  if (!sqlo_is_const_call (exp))
		    return 0;
		}
	      END_DO_BOX;
	      return 1;
	    }
      default:
	  return 0;
    }
  return 1;
}

int
sqlo_is_dt_state_func (char * name)
{
  return (!stricmp (name, "T_STEP") || !stricmp (name, "__TN_IN"));
}


df_elt_t *
sqlo_place_exp (sqlo_t * so, df_elt_t * super, df_elt_t * dfe)
{
  /* regq tables are placed, so place the exp */
  locus_t * pref_loc;
  int inx;
  df_elt_t * placed = NULL;
  /* check if equal exp already placed */
  locus_t * loc = super->dfe_locus;
  if (!IS_BOX_POINTER (dfe))
    return dfe; /*true and falsecond markers */
  so->so_crossed_oby = NULL;
  if (1 /*!loc || LOC_LOCAL == loc */)
    {
      switch (dfe->dfe_type)
	{
	case DFE_COLUMN:
	case DFE_DT:
	case DFE_CONST:
	  break;
	default:
	  if (dfe->dfe_tree)
	    {
	      char prev = so->so_place_code_forr_cond;
	      so->so_place_code_forr_cond = 0;
	      /* even if doing a conditional exp and the subexp is already
	       * placed in the directly preceding code sequence, return the placed one instead of repeating */
	      placed = dfe_latest (so, 1, &dfe, 0);
	      so->so_place_code_forr_cond = prev;
	    }
	  if (placed && placed->dfe_type != DFE_DT)
	    {
	      if (IS_BOX_POINTER (placed->dfe_locus)
		  && placed->dfe_locus != loc)
		{
		  dfe_loc_result (placed->dfe_locus, super, dfe);
		}
	      return placed;
	    }
	}
    }
  pref_loc = sqlo_dfe_preferred_locus (so, super, dfe);
  switch (dfe->dfe_type)
    {
    case DFE_CONST:
      /* GK: set the locus of the params */
      if (ST_COLUMN (dfe->dfe_tree, COL_DOTTED))
	dfe->dfe_locus = pref_loc;
      return NULL;
    case DFE_COLUMN:
      return (sqlo_place_col (so, super, dfe));
    case DFE_BOP:
      {
	df_elt_t * lr[2];
	dfe->dfe_super = super;
	dfe->dfe_locus = pref_loc;
	lr[0] = sqlo_place_exp (so, dfe, dfe->_.bin.left);
	lr[1] = sqlo_place_exp (so, dfe, dfe->_.bin.right);
	placed = dfe_latest (so, 2, lr, 1);
	placed = dfe_skip_exp_dfes (placed, &dfe, 1);
	if (!ST_P (dfe->dfe_tree, BOP_NOT) && !ST_P (dfe->dfe_tree, BOP_OR) &&
	    !ST_P (dfe->dfe_tree, BOP_AND) && !ST_P (dfe->dfe_tree, KWD_PARAM))
	  {
	    /* DFE_BOP's w/ a predicate meaning can appear in conditional expressions.  Place args but no code, since the code is made by pred_gen_1 */
	    sqlo_place_dfe_after (so, pref_loc, placed, dfe);
	  }
	return dfe;

      }
    case DFE_BOP_PRED:
      {
	dfe->dfe_locus = pref_loc;
	sqlo_place_exp (so, dfe, dfe->_.bin.left);
	sqlo_place_exp (so, dfe, dfe->_.bin.right);
	return dfe;

      }
    case DFE_EXISTS:
      {
	int n_deps = dk_set_length (dfe->dfe_tables);
	op_table_t ** deps = (op_table_t **) t_list_to_array (dfe->dfe_tables);
	df_elt_t * copy;
	op_table_t * ot = dfe->_.sub.ot;

	placed = dfe_latest_by_ot (so, n_deps, deps, 1);
	placed = dfe_skip_exp_dfes (placed, &dfe, 1);
	ot->ot_work_dfe = dfe_container (so, DFE_EXISTS, placed);
	ot->ot_work_dfe->_.sub.in_arity = dfe_arity_with_supers (placed->dfe_prev);
	copy = sqlo_layout (so, ot, SQLO_LAY_EXISTS, placed);
	copy->dfe_type = DFE_EXISTS;
	dfe->_.sub.generated_dfe = copy;
	break;
      }
    case DFE_VALUE_SUBQ:
      {
	ST * sel;
	df_elt_t * best, * subq_out;
	int n_deps = dk_set_length (dfe->dfe_tables);
	op_table_t ** deps = (op_table_t **) t_list_to_array (dfe->dfe_tables);
	placed = dfe_latest_by_ot (so, n_deps, deps, 1);
	placed = dfe_skip_exp_dfes (placed, &dfe, 1);
	sqlo_place_dfe_after (so, pref_loc, placed, dfe);
	dfe->_.sub.ot->ot_work_dfe = dfe_container (so, DFE_VALUE_SUBQ, placed);
	dfe->_.sub.ot->ot_work_dfe->_.sub.in_arity = dfe_arity_with_supers (dfe->dfe_prev);
	best = sqlo_layout (so, dfe->_.sub.ot, SQLO_LAY_VALUES, super);
	dfe->_.sub.generated_dfe = best;
	if (super->dfe_locus != best->dfe_locus)
	  {
	    sel = sqlp_union_tree_select (best->_.sub.ot->ot_dt);
	    subq_out = sqlo_df (so, (ST*) sel->_.select_stmt.selection[0]);
	    dfe_loc_result (best->dfe_locus, super, subq_out);
	  }
	return dfe;
      }
    case DFE_CONTROL_EXP:
      {
	int n_deps = dk_set_length (dfe->dfe_tables);
	op_table_t ** deps = (op_table_t **) t_list_to_array (dfe->dfe_tables);
	df_elt_t * old_pt;
	int old_mode;
	int n_exps = BOX_ELEMENTS (dfe->dfe_tree->_.comma_exp.exps);
	id_hash_t *old_private_elts;

	dfe->dfe_locus = pref_loc;
	placed = dfe_latest_by_ot (so, n_deps, deps, 1);
	placed = dfe_skip_exp_dfes (placed, &dfe, 1);
	dfe->_.control.terms = (df_elt_t ***) t_box_copy ((caddr_t) dfe->dfe_tree->_.comma_exp.exps);
	DO_BOX (ST *, elt, inx, dfe->dfe_tree->_.comma_exp.exps)
	  {
	    df_elt_t *pred;
	    df_elt_t *elt_dfe;

	    old_private_elts = so->so_df_private_elts;
	    so->so_df_private_elts = dfe->_.control.private_elts[inx];

	    pred = sqlo_df (so, elt);
	    elt_dfe = dfe_container (so, DFE_PRED_BODY, placed);

	    elt_dfe->dfe_locus = pref_loc;
	    pred->dfe_locus = pref_loc;
	    old_pt = so->so_gen_pt;
	    old_mode = so->so_place_code_forr_cond;

	    so->so_gen_pt = elt_dfe->_.sub.first;
	    so->so_place_code_forr_cond = 1;
	    if (ST_P (dfe->dfe_tree, SEARCHED_CASE) && inx % 2 == 0)
	      {
		if (ST_P (elt, QUOTE))
		  {
		    if (inx != n_exps - 2 || n_exps == 3)
		      sqlc_new_error (so->so_sc->sc_cc, "37000", "SQ081", "ELSE must be last clause in CASE.");
		  }
		else if (pred->dfe_type == DFE_EXISTS)
		  {
		    sqlo_place_exp (so, elt_dfe, pred);
		  }
		else
		  {
		    sqlo_place_exp (so, pred, pred->_.bin.left);
		    sqlo_place_exp (so, pred, pred->_.bin.right);
		  }
	      }
	    else
		sqlo_place_exp (so, elt_dfe, pred);
	    so->so_gen_pt = old_pt;
	    so->so_place_code_forr_cond = old_mode;
	    dfe->_.control.terms[inx] = df_body_to_array (elt_dfe);
	    so->so_df_private_elts = old_private_elts;
	  }
	END_DO_BOX;
	sqlo_place_dfe_after (so, pref_loc, placed, dfe);
	return dfe;
      }
    case DFE_CALL:
      {
	int n_args = BOX_ELEMENTS (dfe->dfe_tree->_.call.params);
	df_elt_t ** args = (df_elt_t **) t_box_copy ((caddr_t) dfe->dfe_tree->_.call.params);
	locus_t *arg_max_loc = NULL;

	dfe->dfe_locus = pref_loc;
	DO_BOX (ST *, arg, inx, dfe->dfe_tree->_.call.params)
	  {
	    args[inx] = sqlo_df (so, arg);
	    sqlo_place_exp (so, dfe, args[inx]);
	    if (pref_loc && pref_loc != LOC_LOCAL && args[inx]->dfe_locus)
	      { /* the call is a pass-through candidate */
		locus_t *arg_loc = args[inx]->dfe_locus;
		if (!arg_max_loc)
		  arg_max_loc = arg_loc;
		else if (arg_max_loc == LOC_LOCAL && arg_loc != LOC_LOCAL)
		  arg_max_loc = arg_loc;
	      }
	  }
	END_DO_BOX;

	if (pref_loc && pref_loc != LOC_LOCAL &&
	    sqlc_is_proc_available (pref_loc->loc_rds, dfe->dfe_tree->_.call.name) &&
	    arg_max_loc == LOC_LOCAL)
	  { /* if this is a remote virtuoso do not pass through scalar functions on proc vars */
	    pref_loc = LOC_LOCAL;
	  }
	if (sqlo_is_const_call (dfe->dfe_tree)) /* call with constant, do it locally and pass as parameter */
	  pref_loc = LOC_LOCAL;

	if (sqlo_is_dt_state_func (dfe->dfe_tree->_.call.name))
	  {
	    placed = so->so_gen_pt;
	    while (placed->dfe_prev)
	      placed = placed->dfe_prev;
	  }
	else if (!stricmp (dfe->dfe_tree->_.call.name, GROUPING_FUNC))
  {
	    int cond = so->so_place_code_forr_cond;
            so->so_place_code_forr_cond = 1;
	    placed = dfe_latest (so, n_args, args, 1);
            so->so_place_code_forr_cond = cond;
	    while (placed->dfe_prev && placed->dfe_type != DFE_GROUP)
	      placed = placed->dfe_prev;
	    if (placed->dfe_type != DFE_GROUP)
	      SQL_GPF_T1 (so->so_sc->sc_cc, GROUPING_FUNC " func without group by");
	  }
	else
	  {
	    placed = dfe_latest (so, n_args, args, 1);
	    placed = dfe_skip_exp_dfes (placed, &dfe, 1);
	    placed = dfe_skip_to_min_card (placed, super, dfe);
	  }
	sqlo_place_dfe_after (so, pref_loc, placed, dfe);
	return dfe;
      }
    default:
      SQL_GPF_T1 (so->so_sc->sc_cc, "Bad dfe in sqlo_place_exp");
    }
  return NULL;
}


int
dfe_reqd_placed (df_elt_t * dfe)
{
  DO_SET (op_table_t *, req, &dfe->dfe_tables)
    {
      if (!req->ot_dfe
	  || !req->ot_dfe->dfe_is_placed)
	return 0;
    }
  END_DO_SET();
  return 1;
}


int32
sqlo_pred_unit_key (df_elt_t * dfe)
{
  /* float collates like int32 */
  return *(int32*)&dfe->dfe_unit;
}


void
sqlo_pred_sort (sqlo_t * so, int op, df_elt_t ** terms)
{
}


df_elt_t ** df_body_to_array (df_elt_t * dfe);


void
dfe_geo_after_test (sqlo_t * so, df_elt_t ** pred_ret)
{
  /* take the geo text pred in pred and make a bop pred suitable for use as an after test */
  df_elt_t * pred = *pred_ret;
  ST * tree = pred->dfe_tree;
  ST * copy = t_listst (5, tree->type, tree->_.bin_exp.left, tree->_.bin_exp.right, NULL, t_box_num ((ptrlong)tree));
  so->so_no_text_preds = 1;
  *pred_ret = sqlo_df (so, copy);
  so->so_no_text_preds = 0;
}

df_elt_t **
sqlo_pred_body (sqlo_t * so, locus_t * loc, df_elt_t * tb_dfe, df_elt_t * pred)
{
  if ((DFE_TRUE == pred) || (DFE_FALSE == pred))
    pred = sqlo_wrap_dfe_true_or_false (so, pred);
  if (DFE_TEXT_PRED == pred->dfe_type && pred->_.text.geo)
    dfe_geo_after_test (so, &pred);
  switch (pred->dfe_type)
    {
    case DFE_BOP_PRED:
      {
        df_elt_t * l, * r;
	df_elt_t * old_pt = so->so_gen_pt;
	df_elt_t * body = dfe_container (so, DFE_PRED_BODY, tb_dfe);
	char prev = so->so_place_code_forr_cond;
	/* so->so_place_code_forr_cond = 1; -- Commented out as recommended by Orri */
	so->so_gen_pt = body->_.sub.first;
	pred->dfe_locus = loc;
	l = sqlo_place_exp (so, pred, pred->_.bin.left);
	r = sqlo_place_exp (so, pred, pred->_.bin.right);
	sqlo_place_dfe_after (so, loc, body->_.sub.last, pred);
	so->so_gen_pt = old_pt;
	so->so_place_code_forr_cond = prev;
	return (df_body_to_array (body));

      }
    case DFE_BOP:
      {
	dk_set_t list = sqlo_connective_list (pred, pred->_.bin.op);
	df_elt_t ** terms = (df_elt_t **) t_alloc_box (sizeof (caddr_t) * (1 + dk_set_length (list)),
						       DV_ARRAY_OF_POINTER);
	int inx = 1;
	terms[0] = (df_elt_t *) (ptrlong) pred->_.bin.op;
	DO_SET (df_elt_t *, term, &list)
	  {
	    terms[inx++] = (df_elt_t *) sqlo_pred_body (so, loc, tb_dfe, term);
	  }
	END_DO_SET();
	sqlo_pred_sort (so, pred->_.bin.op, terms);
	return terms;
      }
    case DFE_EXISTS:
      {
	df_elt_t * copy;
	op_table_t * ot = pred->_.sub.ot;
	ot->ot_work_dfe = dfe_container (so, DFE_DT, tb_dfe);
	ot->ot_work_dfe->_.sub.in_arity = dfe_arity_with_supers (tb_dfe->dfe_prev);
	copy = sqlo_layout (so, ot, SQLO_LAY_EXISTS, tb_dfe);
	copy->dfe_type = DFE_EXISTS;
	copy->_.sub.org_in = pred->_.sub.org_in;
	return ((df_elt_t **) t_list (2, (ptrlong)DFE_PRED_BODY, copy));
      }
    case DFE_TEXT_PRED:
    sqlc_new_error (so->so_sc->sc_cc, "42000", "FT042",
	"contains/xcontains/xpath_contains may only be specified as top level AND predicate");
    default: SQL_GPF_T1 (so->so_sc->sc_cc, "cannot place this type of predicate");
    }
  return NULL; /* dummy*/
}


df_elt_t **
sqlo_and_list_body (sqlo_t * so, locus_t * loc, df_elt_t * tb, dk_set_t pred_dfes)
{
  int len = dk_set_length (pred_dfes);
  if (len)
    {
      int inx = 1;
      df_elt_t ** terms = (df_elt_t **) t_alloc_box (sizeof (caddr_t) * (1 + len), DV_ARRAY_OF_POINTER);
      terms[0] = (df_elt_t*) BOP_AND;
      DO_SET (df_elt_t *, pred, &pred_dfes)
	{
	  pred->dfe_is_placed = DFE_PLACED;
	  terms[inx++] = (df_elt_t *) sqlo_pred_body (so, loc, tb, pred);
	}
      END_DO_SET();
      sqlo_pred_sort (so, BOP_AND, terms);
      return terms;
    }
  else
    return NULL;
}


ST *
dfe_nth_selection (df_elt_t * tb_dfe, int inx)
{
  ST * exp = (ST *) tb_dfe->_.sub.ot->ot_dt->_.select_stmt.selection[inx];
  while (ST_P (exp, BOP_AS))
    exp = exp->_.as_exp.left;
  return exp;
}


ST *
sqlo_import (ST * tree, df_elt_t * tb_dfe, df_elt_t * target_dfe)
{
  int inx;
  ST ** copy;
  dtp_t dtp = DV_TYPE_OF (tree);
  if (DV_ARRAY_OF_POINTER != dtp)
    return tree;
  if (ST_COLUMN (tree, COL_DOTTED))
    {
      if (!ST_P (tb_dfe->_.sub.ot->ot_dt, PROC_TABLE) &&
	  tree->_.col_ref.prefix && 0 == strcmp (tree->_.col_ref.prefix, tb_dfe->_.sub.ot->ot_new_prefix))
	{
	  /* col of the dt, return the definition instead */
	  ST * left_sel = tb_dfe->_.sub.ot->ot_left_sel;
	  DO_BOX (ST *, as_exp, inx, left_sel->_.select_stmt.selection)
	    {
	      if (0 == strcmp (as_exp->_.as_exp.name, tree->_.col_ref.name))
		goto found;
	    }
	  END_DO_BOX;
	  SQL_GPF_T1 (NULL, " ref in set exp pred to undef d col");
	found:
	  return ((ST*) t_box_copy_tree ((caddr_t) dfe_nth_selection (target_dfe, inx)));
	}
      else
	return ((ST*) t_box_copy_tree ((caddr_t) tree));
    }
  copy = (ST **) t_box_copy ((caddr_t) tree);
  /* touch the serial for the imported preds as well */
  if (BIN_EXP_P ((ST *) copy) &&
      !IS_ARITM_BOP (((ST *)copy)->type) &&
      !ST_P ((ST *) copy, BOP_AS) &&
      BOX_ELEMENTS (copy) > 4)
    ((ST *)copy)->_.bin_exp.serial = t_box_num (sqlp_bin_op_serial++);
  DO_BOX (ST *, elt, inx, copy)
    {
      copy[inx] = sqlo_import (elt, tb_dfe, target_dfe);
    }
  END_DO_BOX;
  return ((ST*) copy);
}


dk_set_t
sqlo_import_preds (sqlo_t * so, df_elt_t * tb_dfe, df_elt_t * dt_dfe, dk_set_t preds)
{
  op_table_t * prev_dt = so->so_this_dt;
  dk_set_t res = NULL;
  sql_scope_t sco, *old_sco;

  memset (&sco, 0, sizeof (sql_scope_t));
  sco.sco_so = so;
#if 0
  sco.sco_tables = dt_dfe->_.sub.ot->ot_from_ots;
#endif
  sco.sco_fun_refs_allowed = 1;

  DO_SET (df_elt_t *, pred, &preds)
    {
      int pred_type;
      df_elt_t * new_dfe;
      ST * all_new_tree;
      dk_set_t and_set = NULL;

      pred_type = pred->dfe_type; /* in existence pred, not inferable from dfe_tree */
      all_new_tree = sqlo_import (pred->dfe_tree, tb_dfe, dt_dfe);
      so->so_is_rescope = 1;
      old_sco = so->so_scope;
      so->so_scope = &sco;
      if (dt_dfe)
	so->so_this_dt = dt_dfe->_.sub.ot;
      sqlo_scope (so, &all_new_tree);
      so->so_is_top_and = 0;
      so->so_scope = old_sco;

      sqlc_make_and_list (all_new_tree, &and_set);
      DO_SET (predicate_t *, new_tree_pred, &and_set)
	{
	  ST *new_tree = new_tree_pred->pred_text;

	  new_dfe = sqlo_df (so, new_tree);
	  if (DFE_TRUE == new_dfe)
	    continue;
	  if (DFE_FALSE == new_dfe)
	    new_dfe = sqlo_wrap_dfe_true_or_false (so, new_dfe);
	  if (DFE_DT == new_dfe->dfe_type || DFE_VALUE_SUBQ == new_dfe->dfe_type)
	    new_dfe->dfe_type = DFE_EXISTS;
	  if (new_dfe == pred)
	    new_dfe->dfe_is_placed = 0;
	  t_set_push (&res, (void*) new_dfe);
	}
      END_DO_SET();
    }
  END_DO_SET();
  so->so_this_dt = prev_dt;
  return res;
}


int
sel_has_top (ST * sel)
{
  ST * top = SEL_TOP (sel);
  if (!top)
    return 0;
  return top->_.top.exp != NULL;
}


df_elt_t *
sqlo_place_dt_leaf (sqlo_t * so, df_elt_t * tb_dfe, df_elt_t * dt_dfe, dk_set_t preds)
{
  df_elt_t * copy;
  op_table_t * ot = dt_dfe->_.sub.ot;
  dk_set_t old_preds = ot->ot_preds;
  if (ST_P (ot->ot_dt, PROC_TABLE))
    {
      dk_set_t joined_preds = t_set_union (ot->ot_join_preds, preds);
      dk_set_t proc_param_preds = NULL, proc_col_preds = NULL;
      int inx;

      ot->ot_imported_preds = NULL;
      ot->ot_work_dfe = dfe_container (so, DFE_DT, tb_dfe);
      /*MI: here is a duplicate */
      ot->ot_work_dfe->_.sub.in_arity = dfe_arity_with_supers (tb_dfe->dfe_prev);
      ot->ot_work_dfe->_.sub.in_arity = dfe_arity_with_supers (tb_dfe->dfe_prev);
      copy = sqlo_layout (so, ot, SQLO_LAY_EXISTS, tb_dfe->dfe_super);
      copy->_.sub.dt_imp_preds = ot->ot_imported_preds;
      copy->dfe_super = tb_dfe;
      ot->ot_work_dfe = copy;
      ot->ot_imported_preds = NULL;
      ot->ot_preds = old_preds;
      copy->_.sub.dt_preds = preds;	/* the org ones, for vdb printout if needed */
      DO_SET (df_elt_t *, pred, &joined_preds)
	{
	  caddr_t col_name = NULL;
	  if (ST_COLUMN (pred->dfe_tree->_.bin_exp.left, COL_DOTTED))
	     col_name = pred->dfe_tree->_.bin_exp.left->_.col_ref.name;
	  else if (ST_COLUMN (pred->dfe_tree->_.bin_exp.right, COL_DOTTED))
	     col_name = pred->dfe_tree->_.bin_exp.right->_.col_ref.name;
	  if (col_name)
	    {
	      DO_BOX (caddr_t, name, inx, ((caddr_t *) ot->ot_dt->_.proc_table.params))
		{
		  dtp_t name_dtp = DV_TYPE_OF (name);
		  if ((IS_STRING_DTP (name_dtp) || name_dtp == DV_SYMBOL) &&
		      (!CASEMODESTRCMP (name, col_name)
		       || box_equal (name, col_name)))
		    {
		      if (!dk_set_member (proc_col_preds, pred))
			t_set_pushnew (&proc_param_preds, pred);
		      goto next_pred;
		    }
		}
	      END_DO_BOX;
	    }
	  if (!dk_set_member (proc_param_preds, pred))
	    t_set_pushnew (&proc_col_preds, pred);
next_pred:;
	}
      END_DO_SET ();

      copy->_.sub.vdb_join_test = sqlo_and_list_body (so, tb_dfe->dfe_locus, tb_dfe, proc_param_preds);
      copy->_.sub.after_join_test = sqlo_and_list_body (so, tb_dfe->dfe_locus, tb_dfe, proc_col_preds);
      return copy;
    }
  if (!IS_BOX_POINTER (tb_dfe->dfe_super->dfe_locus)
      && !(ST_P (ot->ot_dt, SELECT_STMT) && sel_has_top (ot->ot_dt)))
    {
      dk_set_t imp_preds = sqlo_import_preds (so, tb_dfe, dt_dfe, preds);
      ot->ot_imported_preds = t_set_copy (imp_preds);
      ot->ot_preds = dk_set_conc (imp_preds, ot->ot_preds);
      ot->ot_work_dfe = dfe_container (so, DFE_DT, tb_dfe);
      ot->ot_work_dfe->_.sub.in_arity  = dfe_arity_with_supers (tb_dfe->dfe_prev);
      copy = sqlo_layout (so, ot, SQLO_LAY_VALUES /*SQLO_LAY_EXISTS*/, tb_dfe->dfe_super);
      copy->_.sub.dt_imp_preds = ot->ot_imported_preds;
      copy->dfe_super = tb_dfe;
      ot->ot_work_dfe = copy;
      ot->ot_imported_preds = NULL;
      ot->ot_preds = old_preds;
      copy->_.sub.dt_preds = preds;	/* the org ones, for vdb printout if needed */
      return copy;
    }
  else
    {
      ot->ot_work_dfe = dfe_container (so, DFE_DT, tb_dfe);
      ot->ot_work_dfe->_.sub.in_arity = dfe_arity_with_supers (tb_dfe->dfe_prev);
      copy = sqlo_layout (so, ot, SQLO_LAY_EXISTS, tb_dfe->dfe_super);
      copy->_.sub.dt_imp_preds = ot->ot_imported_preds;
      copy->dfe_super = tb_dfe;
      ot->ot_work_dfe = copy;
      copy->_.sub.dt_preds = preds;	/* the org ones, for vdb printout if needed */
      if (!IS_BOX_POINTER (tb_dfe->dfe_super->dfe_locus))
	{
	  tb_dfe->_.sub.generated_dfe = copy;
	  copy->_.sub.after_join_test = sqlo_and_list_body (so, tb_dfe->dfe_locus, tb_dfe, preds);
	}
      return copy;
    }
}


int
sqlc_is_all_union_alls (ST * tree)
{
  if (ST_P (tree, SELECT_STMT))
    return 1;
  if (ST_P (tree, UNION_ALL_ST))
    return (sqlc_is_all_union_alls (tree->_.set_exp.left)
	&& sqlc_is_all_union_alls (tree->_.set_exp.right));
  return 0;
}


void
sqlo_add_union_reqd_outs (sqlo_t * so, df_elt_t * dt_dfe)
{
  int inx;
  if (! sqlc_is_all_union_alls (dt_dfe->_.sub.ot->ot_dt))
    {
      op_table_t * ot = dt_dfe->_.sub.ot;
      ST * sel = dt_dfe->_.sub.ot->ot_left_sel;
      DO_BOX (ST *, as_exp, inx, sel->_.select_stmt.selection)
	{
	  sqlo_place_exp (so, dt_dfe->_.sub.generated_dfe,
			  sqlo_df (so, (ST*) t_list (3, COL_DOTTED, ot->ot_new_prefix, as_exp->_.as_exp.name)));
	}
      END_DO_BOX;
    }
}


df_elt_t *
sqlo_place_dt_set (sqlo_t * so, df_elt_t * tb_dfe, df_elt_t * dt_dfe, dk_set_t preds)
{
  int inx;
  if  (DFE_DT == dt_dfe->dfe_type)
    return (sqlo_place_dt_leaf (so, tb_dfe, dt_dfe, preds));
  else
    {
      df_elt_t * copy = (df_elt_t *) t_box_copy ((caddr_t) dt_dfe);
      copy->_.qexp.terms = (df_elt_t **)  t_box_copy ((caddr_t) dt_dfe->_.qexp.terms);
      DO_BOX (df_elt_t *, term, inx, copy->_.qexp.terms)
	{
	  copy->_.qexp.terms[inx] = sqlo_place_dt_set (so, tb_dfe, term, preds);
	}
      END_DO_BOX;
      return copy;
    }
}


void
sqlo_dt_imp_pred_cols (sqlo_t * so, df_elt_t * tb_dfe, ST * tree)
{
  /* make sure that all refd cols of the dt_dfe appear at its output */
  int inx;
  dtp_t dtp = DV_TYPE_OF (tree);
  if (DV_ARRAY_OF_POINTER != dtp || BOX_ELEMENTS (tree) < 1)
    return;
  if (ST_COLUMN (tree, COL_DOTTED))
    {
      if (tree->_.col_ref.prefix && 0 == strcmp (tree->_.col_ref.prefix, tb_dfe->_.sub.ot->ot_new_prefix))
	{
	  sqlo_place_col (so, tb_dfe, sqlo_df (so, tree));
	}
      return;
    }
  DO_BOX (ST *, elt, inx, (ST**)tree)
    {
      sqlo_dt_imp_pred_cols (so, tb_dfe, elt);
    }
  END_DO_BOX;
}




/* transitive dt */



dk_set_t
sqlo_cols_by_pos (sqlo_t *so, df_elt_t * dfe, ptrlong * list)
{
  ST * tree = dfe->dfe_tree;
  int inx, n_sel;
  dk_set_t res = NULL;
  ST ** sel;
  if (!tree)
    tree = dfe->_.sub.ot->ot_dt;
  sel = (ST**)sqlp_union_tree_select (tree)->_.select_stmt.selection;
  n_sel = BOX_ELEMENTS (sel);
  DO_BOX (caddr_t, pos_box, inx, list)
    {
      int pos = unbox (pos_box);
      if (pos >= n_sel)
	sqlc_new_error (so->so_sc->sc_cc, "37000", "TR...", "transitive input or output column index out of range");
      t_set_push (&res, t_list (3, COL_DOTTED, dfe->_.sub.ot->ot_new_prefix, sel[pos]->_.as_exp.name));
    }
  END_DO_BOX;
  res = t_set_nreverse (res);
  return res;
}


void
sqlo_rm_if_eq (dk_set_t * cols, df_elt_t * pred)
{
  /* the cols for which pred is an equality are removed from the list */
  if (DFE_BOP_PRED != pred->dfe_type && DFE_BOP != pred->dfe_type)
    return;
  if (BOP_EQ != pred->_.bin.op)
    return;
 again:
  DO_SET (ST *, col, cols)
    {
      if (box_equal (col, pred->_.bin.left->dfe_tree))
	{
	  t_set_delete (cols, col);
	  goto again;
	}
      if (box_equal (col, pred->_.bin.right->dfe_tree))
	{
	  t_set_delete (cols, col);
	  goto again;
	}
    }
  END_DO_SET();
}


void
sqlo_trans_preds (dk_set_t * cols, dk_set_t preds, dk_set_t * pred_rhs_ret, dk_set_t * unused_preds_ret)
{
  /* take a list of trans dt input cols.  Produce a list of initial values plus importable preds for these.
   * the preds which are not giving the starting values are returned in unused_preds_ret */
  int nth_col = 0;
  dk_set_t used_preds = NULL;
  *pred_rhs_ret = NULL;
 again:
  DO_SET (ST *, col, cols)
    {
      dk_set_t rhs_list = NULL;
      ST * importable_pred = NULL;
      DO_SET (df_elt_t *, pred, &preds)
	{
	  if (DFE_BOP_PRED != pred->dfe_type && DFE_BOP != pred->dfe_type)
	    continue;
	  if (BOP_EQ != pred->_.bin.op)
	    continue;
	  if (dk_set_member (used_preds, pred))
	    continue;
	  if (box_equal (col, pred->_.bin.left->dfe_tree))
	    {
	      t_set_push (&rhs_list, pred->_.bin.right->dfe_tree);
	      if (!importable_pred)
		{
		  importable_pred = t_listst (3, BOP_EQ, pred->_.bin.left->dfe_tree, t_list (3, CALL_STMT, t_box_dv_short_string ("__TN_IN"), t_list (1, t_box_num (nth_col))));
		  nth_col++;
		}
	      t_set_push (&used_preds, (void*)pred);
	      t_set_delete (unused_preds_ret, (void*)pred);
	    }
	  else if (box_equal (col, pred->_.bin.right->dfe_tree))
	    {
	      t_set_push (&rhs_list, pred->_.bin.left->dfe_tree);
	      if (!importable_pred)
		{
		  importable_pred = t_listst (3, BOP_EQ, pred->_.bin.right->dfe_tree, list (3, CALL_STMT, t_box_dv_short_string ("__TN_IN"), t_list (1, t_box_num (nth_col))));
		  nth_col++;
		}
	      t_set_push (&used_preds, (void*)pred);
	      t_set_delete (unused_preds_ret, (void*)pred);
	    }
	}
      END_DO_SET();
      if (importable_pred)
	{
      	  t_set_delete (cols, col);
	  t_set_push (pred_rhs_ret, t_CONS (importable_pred, rhs_list));
	  goto again;
	}
    }
  END_DO_SET();
  *unused_preds_ret = t_set_union (*unused_preds_ret, t_set_diff (preds, used_preds));
  pred_rhs_ret[0] = t_set_nreverse (pred_rhs_ret[0]);
}


void sqlo_place_dt (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t preds);


void
sqlo_dt_place_all_cols (sqlo_t * so, df_elt_t * dfe)
{
  /* for a transitive dt, all the selected columns must actually be placed even if not refd outside of the dt */
  int inx;
  ST ** selection = (ST**)dfe->_.sub.ot->ot_left_sel->_.select_stmt.selection;
  DO_BOX (ST *, as, inx, selection)
    {
      df_elt_t * col_dfe = sqlo_df (so, t_listst (3, COL_DOTTED, dfe->_.sub.ot->ot_new_prefix, as->_.as_exp.name));
      sqlo_place_exp (so, dfe->dfe_super, col_dfe);
    }
  END_DO_BOX;
}


df_elt_t *
sqlo_dt_renamed_copy (sqlo_t * so, df_elt_t * dt_dfe)
{
  df_elt_t * copy;
  ST * tree = (ST*)t_box_copy_tree ((caddr_t)dt_dfe->_.sub.ot->ot_dt);
  so->so_is_rescope = 1;
  sqlo_scope (so, &tree);
  so->so_is_rescope = 0;
  copy = sqlo_df (so, tree);
  copy->dfe_super = dt_dfe->dfe_super;
  copy->_.sub.ot->ot_new_prefix = dt_dfe->_.sub.ot->ot_new_prefix;
  return copy;
}


void
sqlo_trans_dt_1_way (sqlo_t * so, df_elt_t * dfe, dk_set_t preds, ptrlong * in_pos, ptrlong * out_pos)
{
  /* in and out are given.  From in to out */
  ST * save;
  dk_set_t after_join = NULL, importable = NULL;
  dk_set_t in_cols, out_cols, in, out;
  df_elt_t * copy_dfe;
  t_NEW_VARZ (trans_layout_t, tl);
  in_cols = sqlo_cols_by_pos (so, dfe, in_pos);
  sqlo_trans_preds (&in_cols, preds, &in, &after_join);
  out_cols = sqlo_cols_by_pos (so, dfe, out_pos);
  sqlo_trans_preds (&out_cols, preds, &out, &after_join);
  DO_SET (dk_set_t, in_pair, &in)
    {
      dk_set_t rhs = in_pair->next;
      ST * pred;
      df_elt_t * rhs_dfe, *pred_dfe;
      ST * all_eq = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase  ("__all_eq"), t_list_to_array (rhs));
      rhs_dfe = sqlo_df (so, all_eq);
      sqlo_place_exp (so, dfe->dfe_super, rhs_dfe);
      t_set_push (&tl->tl_params, rhs_dfe);
      pred = (ST*)in_pair->data;
      pred_dfe = sqlo_df (so, pred);
      t_set_push (&importable, (void*)pred_dfe);
    }
  END_DO_SET();
  tl->tl_params = t_set_nreverse (tl->tl_params);
  importable = t_set_nreverse (importable);
  DO_SET (dk_set_t, out_pair, &out)
    {
      dk_set_t rhs = out_pair->next;
      df_elt_t * rhs_dfe;
      ST * all_eq = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase  ("__all_eq"), t_list_to_array (rhs));
      rhs_dfe = sqlo_df (so, all_eq);
      sqlo_place_exp (so, dfe->dfe_super, rhs_dfe);
      t_set_push (&tl->tl_target, rhs_dfe);
    }
  END_DO_SET();
  tl->tl_target = t_set_nreverse (tl->tl_target);
  save = dfe->_.sub.ot->ot_trans;
  dfe->_.sub.ot->ot_trans = NULL;
  copy_dfe = sqlo_dt_renamed_copy (so, dfe);
  copy_dfe->dfe_super = dfe;
  copy_dfe->_.sub.ot->ot_trans = NULL;
  sqlo_place_dt (so, copy_dfe, importable);
  dfe->_.sub.generated_dfe = copy_dfe->_.sub.generated_dfe;
  dfe->_.sub.ot->ot_trans = save;
  copy_dfe->_.sub.ot->ot_trans = save;
  dfe->_.sub.generated_dfe->_.sub.trans = tl;
  sqlo_dt_place_all_cols (so, dfe);
  dfe->_.sub.generated_dfe->_.sub.after_join_test =
    sqlo_and_list_body (so, dfe->dfe_super->dfe_locus, dfe, after_join);
}


int
sqlo_trans_direction (df_elt_t * gen1, df_elt_t * gen2)
{
  float c1 = gen1->dfe_unit + gen1->dfe_unit * gen1->dfe_arity;
  float c2 = gen2->dfe_unit + gen2->dfe_unit * gen2->dfe_arity;
  float r = gen1->dfe_unit / gen2->dfe_unit;
  if (r > 0.25 && r < 4
      && gen1->dfe_arity > 1  && gen2->dfe_arity > 1)
    return TRANS_LRRL;
  if (c1 < c2)
    return TRANS_LR;
  return TRANS_RL;
}


void
sqlo_trans_dt_2_way (sqlo_t * so, df_elt_t * dfe, dk_set_t preds, ptrlong * in_pos, ptrlong * out_pos)
{
  /* both ends given, compile from left to right and right to left. */
  ST * trans = dfe->_.sub.ot->ot_trans;
  int dir = trans->_.trans.direction;
  trans_layout_t *tl1 = NULL, *tl2 = NULL;
  df_elt_t * gen1 = NULL, *gen2 = NULL;
  if (TRANS_LR == dir || TRANS_LRRL == dir || TRANS_ANY == dir)
    {
      sqlo_trans_dt_1_way (so, dfe, preds, in_pos, out_pos);
      gen1 = dfe->_.sub.generated_dfe;
      tl1 = gen1->_.sub.trans;
      tl1->tl_direction = TRANS_LR;
      if (TRANS_LRRL == dir || TRANS_ANY == dir)
	{
	  gen1 = sqlo_layout_copy (so, gen1, NULL);
	  so->so_gen_pt = dfe->dfe_prev;
	  sqlo_dt_unplace (so, dfe);
	  sqlo_place_dfe_after (so, dfe->dfe_locus, so->so_gen_pt, dfe);
	}
    }
  if (TRANS_RL == dir || TRANS_LRRL == dir || TRANS_ANY == dir)
    {
      dfe->dfe_is_placed = DFE_PLACED;
      sqlo_trans_dt_1_way (so, dfe, preds, out_pos, in_pos);
      gen2 = dfe->_.sub.generated_dfe;
      tl2 = gen2->_.sub.trans;
      tl2->tl_direction = TRANS_RL;
    }
  if (TRANS_ANY == dir)
    dir = sqlo_trans_direction (gen1, gen2);
  if (TRANS_LRRL == dir)
      tl2->tl_complement = gen1;
  else if (TRANS_LR == dir)
    {
      dfe->_.sub.generated_dfe = gen1;
      tl1->tl_direction = dir;
    }
}


void
sqlo_place_trans_dt (sqlo_t * so, df_elt_t * dfe, dk_set_t preds)
{
  /* see whether in given, out given or both.  Make importable pred lists for both.  Fill in trans_layout */
  dk_set_t in_cols, out_cols;
  dk_set_t in = NULL;
  ST * trans, * save;
  trans = dfe->_.sub.ot->ot_trans;
  in_cols = sqlo_cols_by_pos (so, dfe, trans->_.trans.in);
  out_cols = sqlo_cols_by_pos (so, dfe, trans->_.trans.out);
  DO_SET (df_elt_t *, join, &preds)
    {
      sqlo_rm_if_eq (&in_cols, join);
      sqlo_rm_if_eq (&out_cols, join);
    }
  END_DO_SET();
  if (!in_cols && !out_cols)
    {
      sqlo_trans_dt_2_way (so, dfe, preds, trans->_.trans.in, trans->_.trans.out);
    }
  else if (!in_cols)
    {
      /* the input side is given.  place from in to out */
      dk_set_t after_join = NULL, importable = NULL;
      t_NEW_VARZ (trans_layout_t, tl);
      in_cols = sqlo_cols_by_pos (so, dfe, trans->_.trans.in);
      tl->tl_direction = TRANS_LR;
      sqlo_trans_preds (&in_cols, preds, &in, &after_join);
      DO_SET (dk_set_t, in_pair, &in)
	{
	  dk_set_t rhs = in_pair->next;
	  ST * pred;
	  df_elt_t * rhs_dfe, *pred_dfe;
	  ST * all_eq = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase  ("__all_eq"), t_list_to_array (rhs));
	  rhs_dfe = sqlo_df (so, all_eq);
	  sqlo_place_exp (so, dfe->dfe_super, rhs_dfe);
	  t_set_push (&tl->tl_params, rhs_dfe);
	  pred = (ST*)in_pair->data;
	  pred_dfe = sqlo_df (so, pred);
	  t_set_push (&importable, (void*)pred_dfe);
	}
      END_DO_SET();
      tl->tl_params = t_set_nreverse (tl->tl_params);
      importable = t_set_nreverse (importable);
      save = dfe->_.sub.ot->ot_trans;
      dfe->_.sub.ot->ot_trans = NULL;
      sqlo_place_dt (so, dfe, importable);
      dfe->_.sub.ot->ot_trans = save;
      dfe->_.sub.generated_dfe->_.sub.trans = tl;
      sqlo_dt_place_all_cols (so, dfe);
      dfe->_.sub.generated_dfe->_.sub.after_join_test =
	sqlo_and_list_body (so, dfe->dfe_super->dfe_locus, dfe, after_join);
    }
  else if (!out_cols)
    {
      /* the output side is given.  place from in to out */
      dk_set_t after_join = NULL, importable = NULL;
      t_NEW_VARZ (trans_layout_t, tl);
      in_cols = sqlo_cols_by_pos (so, dfe, trans->_.trans.out);
      tl->tl_direction = TRANS_RL;
      sqlo_trans_preds (&in_cols, preds, &in, &after_join);
      DO_SET (dk_set_t, in_pair, &in)
	{
	  dk_set_t rhs = in_pair->next;
	  ST * pred;
	  df_elt_t * rhs_dfe, *pred_dfe;
	  ST * all_eq = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase  ("__all_eq"), t_list_to_array (rhs));
	  rhs_dfe = sqlo_df (so, all_eq);
	  sqlo_place_exp (so, dfe->dfe_super, rhs_dfe);
	  t_set_push (&tl->tl_params, rhs_dfe);
	  pred = (ST*)in_pair->data;
	  pred_dfe = sqlo_df (so, pred);
	  t_set_push (&importable, (void*)pred_dfe);
	}
      END_DO_SET();
      tl->tl_params = t_set_nreverse (tl->tl_params);
      importable = t_set_nreverse (importable);
      save = dfe->_.sub.ot->ot_trans;
      dfe->_.sub.ot->ot_trans = NULL;
      sqlo_place_dt (so, dfe, importable);
      dfe->_.sub.ot->ot_trans = save;
      dfe->_.sub.generated_dfe->_.sub.trans = tl;
      sqlo_dt_place_all_cols (so, dfe);
      dfe->_.sub.generated_dfe->_.sub.after_join_test =
	sqlo_and_list_body (so, dfe->dfe_super->dfe_locus, dfe, after_join);
    }
  else
    sqlc_new_error (so->so_sc->sc_cc, "37000", "TR...", "transitive start not given");
  /* record the preds used in the process for unplacing */
  dfe->_.sub.dt_preds = dk_set_conc (t_set_copy (preds), dfe->_.sub.dt_preds);
}


void
sqlo_place_dt (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t preds)
{
  df_elt_t * gen_dt;
  op_table_t * ot = tb_dfe->_.sub.ot;
  tb_dfe->_.sub.dt_preds = preds;
  if (ot->ot_trans)
    {
      sqlo_place_trans_dt (so, tb_dfe, preds);
      return;
    }
  if (ST_P (ot->ot_dt, SELECT_STMT) || ST_P (ot->ot_dt, PROC_TABLE))
    {
      tb_dfe->_.sub.generated_dfe = sqlo_place_dt_leaf (so, tb_dfe, tb_dfe, preds);
    }
  else
    {
      df_elt_t * dt_dfe = sqlo_df (so, ot->ot_dt);
      tb_dfe->_.sub.generated_dfe = sqlo_place_dt_set (so, tb_dfe, dt_dfe, preds);
      sqlo_add_union_reqd_outs (so, tb_dfe);
    }
  gen_dt = tb_dfe->_.sub.generated_dfe;
  if (IS_BOX_POINTER (gen_dt->dfe_locus) && gen_dt->dfe_locus == tb_dfe->dfe_super->dfe_locus)
    {
      /* a pass through dt was placed inside a pass through dt.  All the cols refd in imported preds must be on the selection of the freshly placed dt */
      gen_dt->_.sub.dt_imp_preds = preds;
      gen_dt->_.sub.vdb_join_test = sqlo_and_list_body (so, gen_dt->dfe_locus, tb_dfe, preds);
      DO_SET (df_elt_t *, pred, &preds)
	{
	  sqlo_dt_imp_pred_cols (so, gen_dt, pred->dfe_tree);
	}
      END_DO_SET();
    }
}


#define MERGE_CONTRADICTION ((dk_set_t) -1)


int
dfe_const_equal (df_elt_t * pred, df_elt_t * l, df_elt_t * r)
{
  if (pred->_.bin.left->_.col.col != (dbe_column_t *) CI_ROW)
    {
      collation_t * coll = pred->_.bin.left->_.col.col->col_sqt.sqt_collation;
      return (DVC_MATCH == cmp_boxes ((caddr_t) l->dfe_tree, (caddr_t) r->dfe_tree, coll, coll));
    }
  else
    return 0;
}


caddr_t
cmp_max_func (int op)
{
  char * name;
  if (BOP_EQ == op)
    name = "__all_eq";
  else if (BOP_LT == op || BOP_LTE == op)
    name = "__min";
  else
    name = "__max";
  return (t_sqlp_box_id_upcase (name));
}


int
sqlo_not_eq_with_any (sqlo_t * so, dk_set_t args, df_elt_t *right)
{
  /* if the arg is a col and it is not known eq with any of the args */
  if (DFE_COLUMN != right->dfe_type)
    return 1;
  DO_SET (df_elt_t *, other, &args)
    {
      if (DFE_COLUMN == other->dfe_type
	  && sqlo_is_col_eq  (so->so_this_dt, other, right))
	return 0;
    }
  END_DO_SET();
  return 1;
}


df_elt_t *
sqlo_merge_dfe (sqlo_t *so, df_elt_t * pred, dk_set_t merge_with, int allow_contr)
{
  int inx;
  /* return max, min, eq of the right sides of pred and of the preds in merge_with *
   * if impossible equality, return MERGE_CONTRADICTION */
  ST ** arg_tree;
  dk_set_t args = NULL;
  df_elt_t * cnst = NULL;
  df_elt_t * dfe = NULL;
  merge_with = t_cons ((void*) pred, merge_with);
  DO_SET (df_elt_t *, merge, &merge_with)
    {
      df_elt_t * right = merge->_.bin.right;
      if (allow_contr && pred->_.bin.op == BOP_EQ)
	{
	  if (DFE_IS_CONST (right))
	    {
	      if (cnst && !dfe_const_equal (pred, cnst, right))
		return ((df_elt_t*) MERGE_CONTRADICTION);
	      else if (DFE_IS_CONST (right))
		cnst = right;
	    }
	}
      if (!dk_set_member (args, (void*)right)
	  && sqlo_not_eq_with_any (so, args, right))
	{
	  t_set_push (&args, right);
	}
    }
  END_DO_SET();
  if (!args->next)
    return NULL;
  arg_tree = (ST**)  t_list_to_array (args);
  DO_BOX (df_elt_t *, arg, inx, arg_tree)
    {
      arg_tree[inx] = arg->dfe_tree;
    }
  END_DO_BOX;
  dfe = sqlo_df (so, (ST *) t_list (3, CALL_STMT, cmp_max_func (pred->_.bin.op), arg_tree));
  return dfe;
}

dk_set_t
sqlo_merge_col_preds (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t col_preds, dk_set_t *to_place)
{
  /* equalities of same col */
  df_elt_t * merge_dfe;
    dk_set_t res = NULL;
  dk_set_t merged = NULL;
  DO_SET (df_elt_t *, pred, &col_preds)
    {
      int already_done =NULL !=  dk_set_member (merged, (void*) pred);
      dk_set_t merged_with = NULL;

      if (!already_done)
	{
	  DO_SET (df_elt_t *, pred2, &col_preds)
	    {
	      if (!dk_set_member (merged, (void*) pred)
		  && !dk_set_member (merged, (void*) pred2)
		  && pred != pred2
		  && pred->_.bin.op == pred2->_.bin.op
		  && pred->_.bin.op != BOP_LIKE
		  && pred->_.bin.left->dfe_type == DFE_COLUMN
		  && pred->_.bin.left == pred2->_.bin.left)
		{
		  t_set_push (&merged_with, (void*) pred2);
		  t_set_push (&merged, (void*) pred2);
		}
	    }
	  END_DO_SET();
	}
      if (merged_with
	  && (merge_dfe = sqlo_merge_dfe (so, pred, merged_with, !tb_dfe->_.table.ot->ot_is_outer)))
	{
	  df_elt_t * new_pred = sqlo_new_dfe (so, DFE_BOP_PRED, NULL);
	  t_set_push (&merged, (void*) pred);
	  if (merge_dfe == (df_elt_t *) MERGE_CONTRADICTION)
	    return ((dk_set_t) MERGE_CONTRADICTION);
	  new_pred->dfe_is_placed = DFE_PLACED;
	  new_pred->_.bin.op = pred->_.bin.op;
	  new_pred->_.bin.left = pred->_.bin.left;
	  t_set_push (to_place, merge_dfe);
	  new_pred->_.bin.right = merge_dfe;
	  t_set_push (&res, (void*) new_pred);
	  t_set_push (&tb_dfe->_.table.col_pred_merges, (void*) merge_dfe);
	}
      else if (!already_done)
	t_set_push (&res, pred);
    }
  END_DO_SET ();
  return res;
}



#define dfe_is_upper(dfe) (dfe->_.bin.op == BOP_LT || dfe->_.bin.op == BOP_LTE)

int do_sqlo_in_list = 1;

df_elt_t **
sqlo_in_list (df_elt_t * pred, df_elt_t *tb_dfe, caddr_t name)
{
  if (!do_sqlo_in_list)
    return NULL;
  if (DFE_BOP_PRED == pred->dfe_type && BOP_LT == pred->_.bin.op &&
    DFE_CONST == pred->_.bin.left->dfe_type && !unbox ((ccaddr_t)(pred->_.bin.left->dfe_tree)) &&
    DFE_CALL == pred->_.bin.right->dfe_type && pred->_.bin.right->_.call.func_name &&
    0 == stricmp (pred->_.bin.right->_.call.func_name, "one_of_these") )
    {
      df_elt_t ** args = pred->_.bin.right->_.call.args;
      if (args[0] && DFE_COLUMN == args[0]->dfe_type
	  && (!tb_dfe || 0 == stricmp (args[0]->dfe_tree->_.col_ref.prefix, tb_dfe->_.table.ot->ot_new_prefix))
	  && (!name || 0 == stricmp (args[0]->dfe_tree->_.col_ref.name, name)))
	{
	  int inx;
	  if (tb_dfe)
	    {
	      for (inx = 1; inx < BOX_ELEMENTS (args); inx++)
		{
		  if (dk_set_member (args[inx]->dfe_tables, (void*)tb_dfe->_.table.ot))
		    return NULL;
		}
	    }
	  /* it found something that look like as a col but it's not a column */
	  if (NULL == args[0]->_.col.col)
	    return NULL;
	  return args;
	}
    }
  return NULL;
}


dbe_column_t *
cp_left_col (df_elt_t * cp)
{
  df_elt_t ** in_list;
  if (DFE_BOP_PRED != cp->dfe_type
      && DFE_BOP != cp->dfe_type)
    return NULL;
  if (cp->_.bin.op != BOP_LT)
    return cp->_.bin.left->_.col.col;
  in_list = sqlo_in_list (cp, NULL, NULL);
  if (in_list)
    return in_list[0]->_.col.col;
  return cp->_.bin.left->_.col.col;
}


df_elt_t *
sqlo_key_part_best (dbe_column_t * col, dk_set_t col_preds, int upper_only)
{
  /* equal is best, in next, lower bound second, upper bound third others rejected. */

  df_elt_t *best = NULL;
  int best_score = 0;
  DO_SET (df_elt_t *, cp, &col_preds)
  {
    df_elt_t ** in_list =  sqlo_in_list (cp, NULL, col->col_name);
    if (in_list && in_list[0]->_.col.col != col)
      continue;
    if (in_list && upper_only)
      continue;
    if (cp->dfe_type == DFE_TEXT_PRED)
      {
	if (cp->_.text.col == col && cp->dfe_is_placed < DFE_GEN && !upper_only)
	  return cp;
      }
    else if (!upper_only && in_list)
      {
	if (cp->dfe_is_placed < DFE_GEN)
	  {
	    best = cp;
	    best_score = 5;
	  }
      }
    else if (!sqlo_in_list (cp, NULL, NULL) && DFE_COLUMN == cp->_.bin.left->dfe_type && cp->_.bin.left->_.col.col == col)
      {
	if (cp->dfe_is_placed < DFE_GEN
	    && (!upper_only || dfe_is_upper (cp)))
	  {
	    if (BOP_EQ == cp->_.bin.op)
	      return cp;
	    if (indexable_predicate_p (cp->_.bin.op))
	      {
		if (best)
		  {
		    if (dfe_is_upper (best) && dfe_is_lower (cp)
			&& !best_score)
		      best = cp;
		  }
		else
		  best = cp;
	      }
	  }
      }
  }
  END_DO_SET ();
  return best;
}


int
sqlo_is_text_order (sqlo_t * so, df_elt_t * dfe)
{
  /* decide if text inx is the most selective.  For rdf, do not make text inx driving if there is a match of ro_digest */
  if (0 == stricmp ("DB.DBA.RDF_OBJ",  dfe->_.table.ot->ot_table->tb_name ))
    {
      DO_SET (df_elt_t *, cp, &dfe->_.table.col_preds)
	{
	  if ((DFE_BOP == cp->dfe_type  || DFE_BOP_PRED == cp->dfe_type )
	      && BOP_EQ == cp->_.bin.op && 0 == stricmp (cp->_.bin.left->_.col.col->col_name, "RO_FLAGS"))
	    return 0;
	}
      END_DO_SET();
      return 1;
    }
  if (0 == stricmp ("DB.DBA.RDF_QUAD",  dfe->_.table.ot->ot_table->tb_name ))
    {
      /* geo cond on rdf quad.  If there is an eq on the leading part then geo is not driving */
      df_elt_t * key_part_best = sqlo_key_part_best ((dbe_column_t*)dfe->_.table.key->key_parts->data, dfe->_.table.col_preds, 0);
      if (key_part_best && DFE_BOP_PRED == key_part_best->dfe_type && BOP_EQ == key_part_best->_.bin.op)
	return 0;
    }
  return 1;
}


void
dfe_table_set_by_best (df_elt_t * tb_dfe, index_choice_t * ic, float true_arity, dk_set_t * col_preds, dk_set_t * after_preds)
{
  tb_dfe->_.table.key = ic->ic_key;
  tb_dfe->_.table.is_unique = ic->ic_is_unique;
  tb_dfe->dfe_unit = ic->ic_unit;
  tb_dfe->dfe_arity = true_arity != -1 ? true_arity : ic->ic_arity;
  if (ic->ic_altered_col_pred)
    {
      tb_dfe->_.table.col_preds = ic->ic_altered_col_pred;
      tb_dfe->_.table.is_inf_col_given = 1;
      *col_preds = ic->ic_altered_col_pred;
      *after_preds = dk_set_conc (ic->ic_after_test, *after_preds);
      if (ic->ic_after_test)
	((df_elt_t*)ic->ic_after_test->data)->dfe_arity = ic->ic_after_test_arity;
    }
}

int enable_index_path = 1;

int
sqlo_need_index_path (df_elt_t * tb_dfe)
{
  /* rdf quad with text/geo and no p needs a potentially multi-index access path if partial distinct inxes are used.  Other cases are done with regular inx choice */
  char * tn = tb_dfe->_.table.ot->ot_table->tb_name;
  if (!stricmp (tn, "DB.DBA.RDF_QUAD") || !stricmp (tn, "DB.DBA.R2"))
    {
      dbe_column_t * p_col = tb_name_to_column (tb_dfe->_.table.ot->ot_table, "P");
      df_elt_t * pred;
      if (2 == enable_index_path)
	return 1;
      if (tb_dfe->_.table.text_pred)
	return 1;
      DO_SET (df_elt_t *, pred, &tb_dfe->_.table.all_preds)
	{
	  df_elt_t * r, * l;
	  int op;
	  if (dfe_is_o_ro2sq_range (pred, tb_dfe, &l, &r, &op))
	    return 1;
#if 0
	  if (sqlo_in_list (pred, NULL, NULL))
	    return 0;
#endif
	}
      END_DO_SET();
      pred = sqlo_key_part_best ( p_col, tb_dfe->_.table.col_preds, 0);
      return !dfe_is_eq_pred (pred);
    }
  return 0;
}


void
sqlo_choose_index (sqlo_t * so, df_elt_t * tb_dfe,
		   dk_set_t * col_preds, dk_set_t * after_preds)
{
  float ov;
  float true_arity = -1;
  int true_arity_n_parts = 0;
  index_choice_t best_ic;
  index_choice_t ic;
  int best_unq = 0;
  caddr_t opt_inx_name;
  op_table_t *ot = dfe_ot (tb_dfe);
  int is_pk_inx = 0, is_txt_inx = 0;
  dk_set_t group = NULL;
  float best_group;
  if (tb_dfe->_.table.key)
    return;
  if (enable_index_path && sqlo_need_index_path (tb_dfe))
    {
      sqlo_choose_index_path (so, tb_dfe, col_preds, after_preds);
      return;
    }
  memset (&best_ic, 0, sizeof (best_ic));
  sqlo_prepare_inx_int_preds (so);
  tb_dfe->_.table.is_unique = 0;
  opt_inx_name = sqlo_opt_value (ot->ot_opts, OPT_INDEX);

  if (opt_inx_name && !strcmp (opt_inx_name, "PRIMARY KEY"))
    is_pk_inx = 1;
  else if (opt_inx_name && !strcmp (opt_inx_name, "TEXT KEY"))
    is_txt_inx = 1;

  if (is_pk_inx)
    {
      tb_dfe->_.table.key = ot->ot_table->tb_primary_key;
      tb_dfe->dfe_unit = 0;
      dfe_table_cost_ic (tb_dfe, &best_ic, 0);
      best_unq = tb_dfe->_.table.is_unique;
    }
  else if (is_txt_inx)
    {
      if (!tb_dfe->_.table.text_pred)
	sqlc_new_error (so->so_sc->sc_cc, "22022", "SQ190",
	    "TABLE OPTION INDEX requires the usage of free-text index for table %s, but there's no free-text search condition.",
	    tb_dfe->_.table.ot->ot_table->tb_name);

      tb_dfe->_.table.is_text_order = 1;
      tb_dfe->_.table.key = tb_text_key (tb_dfe->_.table.ot->ot_table);
      tb_dfe->dfe_unit = 0;
      dfe_table_cost_ic (tb_dfe, &best_ic, 0);
      best_unq = 0;
    }
  else
    {
      DO_SET (dbe_key_t *, key, &ot->ot_table->tb_keys)
	{
	  if (key->key_no_pk_ref && !opt_inx_name)
	    continue;
	  memset (&ic, 0, sizeof (ic));
	  if (opt_inx_name)
	    {
	      if (!CASEMODESTRCMP (opt_inx_name, key->key_name))
		{
		  tb_dfe->_.table.key = key;
		  dfe_table_cost_ic (tb_dfe, &best_ic, 0);
		  break;
		}
	    }
	  else
	    {
	      tb_dfe->_.table.key = key;
	      tb_dfe->dfe_unit = 0;
	      dfe_table_cost_ic (tb_dfe, &ic, 0);
	      if (tb_dfe->_.table.is_unique)
		true_arity = ic.ic_arity; /* reliable if unique but if many key parts with many distinct vals arity can be reported as less than 1. */
	      else if (tb_dfe->_.table.is_arity_sure)
		{
		  if (true_arity_n_parts < tb_dfe->_.table.is_arity_sure)
		    {
		      true_arity = ic.ic_arity;
		      true_arity_n_parts = tb_dfe->_.table.is_arity_sure;
		    }
		  if (true_arity_n_parts == tb_dfe->_.table.is_arity_sure)
		    true_arity = MIN (true_arity, ic.ic_arity);
		}
	      if (!best_ic.ic_key || ic.ic_unit < best_ic.ic_unit)
		{
		  best_ic = ic;
		}
	    }
	}
      END_DO_SET ();

      if (opt_inx_name && !best_ic.ic_key)
	sqlc_new_error (so->so_sc->sc_cc, "22023", "SQ188", "TABLE OPTION index %s not defined for table %s",
	    opt_inx_name, ot->ot_table->tb_name);

      if (tb_dfe->_.table.text_pred)
	{
	  if (!opt_inx_name && !best_ic.ic_is_unique
	      && sqlo_is_text_order (so, tb_dfe))
	    {
	      tb_dfe->_.table.is_text_order = 1;
	      tb_dfe->_.table.key = tb_text_key (tb_dfe->_.table.ot->ot_table);
	      tb_dfe->dfe_unit = 0;
	      dfe_table_cost (tb_dfe, &tb_dfe->dfe_unit, &tb_dfe->dfe_arity, &ov, 0);
	      return;
	    }
	  else
	    {
	      dbe_column_t *col = (dbe_column_t *) tb_text_key (dfe_ot(tb_dfe)->ot_table)->key_parts->data;
	      df_elt_t *col_dfe = sqlo_df (so, t_listst (3, COL_DOTTED, dfe_ot(tb_dfe)->ot_new_prefix, col->col_name));
	      sqlo_place_exp (so, tb_dfe->dfe_super, col_dfe);
	    }
	}
    }
  if (!best_ic.ic_key)
    SQL_GPF_T1 (so->so_sc->sc_cc, "sqlo table has no index");
  dfe_table_set_by_best (tb_dfe, &best_ic, true_arity, col_preds, after_preds);
  if (tb_dfe->_.table.hash_role != HR_FILL && !tb_dfe->_.table.is_text_order)
    sqlo_try_inx_int_joins (so, tb_dfe, &group, &best_group);
  if (group)
    {
      sqlo_place_inx_int_join  (so, tb_dfe, group, after_preds);
    }
  else if (!opt_inx_name && !best_unq && !tb_dfe->_.table.is_text_order
	   && HR_FILL != tb_dfe->_.table.hash_role)
    {
      float best_cost = best_ic.ic_unit;
      if (OPT_INTERSECT == (ptrlong) sqlo_opt_value (ot->ot_opts, OPT_JOIN))
	best_cost = 1e30;
      sqlo_find_inx_intersect (so, tb_dfe, *col_preds, best_cost);
    }
}


void
sqlo_tb_order (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t col_preds)
{
  /* pick the oby index and the index based on conditions */
  op_table_t *ot = dfe_ot (tb_dfe);

#if 0
  DO_SET (df_elt_t *, pred, &col_preds)
    {
      /* all col preds that will resolve with cols on the inx, incl ones implicit from pk */
      dbe_column_t * col;
      col = pred->_.bin.left->_.col.col;
      if (dk_set_member (tb_dfe->_.table.key->key_parts, (void*) col))
	t_set_push (&tb_dfe->_.table.inx_preds, (void*) pred);
    }
  END_DO_SET();
#endif
  tb_dfe->_.table.col_preds = col_preds;
  tb_dfe->_.table.inx_preds = dk_set_nreverse (tb_dfe->_.table.inx_preds);
  if (ot->ot_text)
    sqlo_place_exp (so, tb_dfe->dfe_super, sqlo_df (so, ot->ot_text));
  if (ot->ot_base_uri)
    sqlo_place_exp (so, tb_dfe->dfe_super, sqlo_df (so, ot->ot_base_uri));
}


static void
sqlo_tb_place_contains_cols (sqlo_t *so, df_elt_t *tb_dfe, df_elt_t *pred)
{
  unsigned inx, argcount = BOX_ELEMENTS(pred->_.text.args);
  unsigned surely_option_idx = (('x' == pred->_.text.type) ?
      4 : (('c' == pred->_.text.type) ? 2 : 3));
  sql_comp_t *sc = so->so_sc;

  /* place the query expression */
  sqlo_place_exp (so, tb_dfe, sqlo_df (so, pred->_.text.args[1]));

  for (inx = 2; inx < argcount; inx++)
    {
      ST *arg = pred->_.text.args[inx];
      if (!DV_STRINGP (arg))
        {
	  if (inx >= surely_option_idx)
	    SQL_GPF_T1 (sc->sc_cc,
		"Argument of contains should be a keyword, i.e. a symbol");
	}
      else if (0 == stricmp ((char *) arg, "OFFBAND") ||
	  0 == stricmp ((char *) arg, "RANGES") ||
	  0 == stricmp ((char *) arg, "MAIN_RANGES") ||
	  0 == stricmp ((char *) arg, "ATTR_RANGES") ||
	  0 == stricmp ((char *) arg, "SCORE"))
	{ /* output col(s) : do nothing */
	  inx ++;
	}
      else if ((0 == stricmp ((char *)arg, "DESC")) ||
	  (0 == stricmp ((char *)arg, "DESCENDING")))
	{ /* single arg col(s) : nothing */
	  ;
	}
      else if (
	  0 == stricmp ((char *) arg, "START_ID") ||
	  0 == stricmp ((char *) arg, "END_ID") ||
	  0 == stricmp ((char *) arg, "SCORE_LIMIT")
        )
	{ /* input parameters : place */
	  inx ++;
	  sqlo_place_exp (so, tb_dfe, sqlo_df (so, pred->_.text.args[inx]));
	}
      else if (inx >= surely_option_idx)
	SQL_GPF_T1 (sc->sc_cc, "Argument not a keyword from list "
	    "OFFBAND, DESCENDING, RANGES, MAIN_RANGES, ATTR_RANGES, SCORE, START_ID, END_ID, SCORE, SCORE_LIMIT");
    }
  if (pred->_.text.type == 'c' || pred->_.text.type == 'x')
    {
      dbe_key_t *text_key = tb_text_key (tb_dfe->_.table.ot->ot_table);
      sqlo_place_exp (so, tb_dfe,
	  sqlo_df (so,
	    t_listst (3,
	      COL_DOTTED,
	      tb_dfe->_.table.ot->ot_new_prefix,
	      t_box_string (((dbe_column_t *) text_key->key_parts->data)->col_name))));
    }
}


int
is_call_only_dep_on (df_elt_t * dfe, op_table_t * ot, int skip_first_n)
{
  ST **args;
  int argctr, argcount;
#ifndef NDEBUG
  if (!ST_P (dfe->dfe_tree, CALL_STMT))
    GPF_T;
#endif
  if (!(dfe->dfe_tables && !dfe->dfe_tables->next && dfe->dfe_tables->data == (void*) ot))
    return 0;
  args = dfe->dfe_tree->_.call.params;
  argcount = BOX_ELEMENTS (args);
  for (argctr = skip_first_n; argctr < argcount; argctr++)
    {
      if (!ST_COLUMN (args[argctr], COL_DOTTED))
	return 0;
    }
  return 1;
}

void
sqlo_make_inv_pred (sqlo_t * so, sinv_map_t * map, df_elt_t * left, df_elt_t * right, dk_set_t * preds_ret)
{
  /* left is an invertible  function call with columns as args, right is an exp.  map describes the fun in left */
  client_connection_t * cli = sqlc_client ();
  dk_set_t res = NULL;
  int inx_inv;
  int old_top_and = so->so_is_top_and;
  ST * left_tree = left->dfe_tree;
  ST * right_tree = right->dfe_tree;
  so->so_is_top_and = 0;
  DO_BOX (caddr_t, inverse, inx_inv, map->sinvm_inverse)
    {
      ST *clause;
      ST *new_left, *new_right;
      new_left =
	(ST *) t_box_copy_tree ((caddr_t) left_tree->_.call.
				params[inx_inv]);
      new_right =
	t_listst (3, CALL_STMT, t_sqlp_box_id_upcase (inverse),
		  t_list (1, right_tree));

      new_left = sinv_check_inverses (new_left, cli);
      new_right = sinv_check_inverses (new_right, cli);

      BIN_OP (clause, BOP_EQ, new_left, new_right);
      clause = sinv_check_exp (so, clause);
      t_set_push (&res, (void*) sqlo_df (so, clause));
    }
  END_DO_BOX;
  so->so_is_top_and = old_top_and;

  *preds_ret = dk_set_conc (res, *preds_ret);
}

void
sqlo_make_inv_sprintf (sqlo_t * so, const char *inv_name, df_elt_t * left, df_elt_t * right, dk_set_t * preds_ret)
{
  /* left is an invertible sprintf function call with columns as args, right is an exp. */
  client_connection_t * cli = sqlc_client ();
  dk_set_t res = NULL;
  int inx_inv;
  int col_ctr, col_count;
  int old_top_and = so->so_is_top_and;
  ST * left_tree = left->dfe_tree;
  ST * right_tree = right->dfe_tree;
  ST ** left_params = left_tree->_.call.params;
  so->so_is_top_and = 0;
  col_count = BOX_ELEMENTS (left_tree->_.call.params) - 1;
  for (col_ctr = 0; col_ctr < col_count; col_ctr++)
    {
      ST *clause;
      ST *new_left, *new_right;
      new_left =
	(ST *) t_box_copy_tree ((caddr_t)(left_params[col_ctr+1]));
      new_right =
	t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("aref"),
	  t_listst (2,
	    t_listst (3, CALL_STMT, t_sqlp_box_id_upcase (inv_name),
	      t_list (3,
		right_tree,
		t_box_copy_tree ((caddr_t)(left_params[0])),
		t_box_num (2) ) ),
	    t_box_num_nonull (col_ctr) ) );
      new_left = sinv_check_inverses (new_left, cli);
      new_right = sinv_check_inverses (new_right, cli);
      BIN_OP (clause, BOP_EQ, new_left, new_right);
      clause = sinv_check_exp (so, clause);
      t_set_push (&res, (void*) sqlo_df (so, clause));
    }
  so->so_is_top_and = old_top_and;
  *preds_ret = dk_set_conc (res, *preds_ret);
}

int sprintff_is_proven_bijection (const char *f);

static const char *
sqlo_is_call_invertible_sprintf (ST *st)
{
  const char *ret = NULL;
  caddr_t arg1;
  if (casemode_strncmp (st->_.call.name, "__spf", 5))
    return NULL;
  if (!casemode_strcmp (st->_.call.name, "__spf"))
    ret = "__spfinv";
  else if (!casemode_strcmp (st->_.call.name, "__spfn"))
    ret = "__spfinv";
  else if (!casemode_strcmp (st->_.call.name, "__spfin"))
    ret = "__spfinv";
  if (NULL == ret)
    return NULL;
  if (2 > BOX_ELEMENTS (st->_.call.params))
    return NULL;
  arg1 = (caddr_t) st->_.call.params[0];
  if (DV_STRING != DV_TYPE_OF (arg1))
    return NULL;
  if (!sprintff_is_proven_bijection (arg1))
    return NULL;
  return ret;
}

int
sqlo_col_inverse_eq_1 (sqlo_t *so, df_elt_t * tb_dfe, df_elt_t *left, df_elt_t *right, dk_set_t * col_preds, dk_set_t * after_preds)
{
  sinv_map_t * map;
  const char *inv;
  if (is_call_only_dep_on (left, tb_dfe->_.table.ot, 0)
      && !dk_set_member (right->dfe_tables, (void*) tb_dfe->_.table.ot)
      && (map = sinv_call_map (left->dfe_tree, sqlc_client ())))
    {
      sqlo_make_inv_pred  (so, map, left, right, col_preds);
      return 1;
    }
  inv = sqlo_is_call_invertible_sprintf (left->dfe_tree);
  if ((NULL != inv) && is_call_only_dep_on (left, tb_dfe->_.table.ot, 1)
      && !dk_set_member (right->dfe_tables, (void*) tb_dfe->_.table.ot) )
    {
      sqlo_make_inv_sprintf (so, inv, left, right, col_preds);
      return 1;
    }
  return 0;
}

int
sqlo_col_inverse  (sqlo_t *so, df_elt_t * tb_dfe, df_elt_t * pred, dk_set_t * col_preds, dk_set_t * after_preds)
{
  /* if pred is f (c1,...cn) = exp independent of tb_dfe and inverse of f exists and c1...cn are cols of tb_dfe
  * then generate AND of inverses of f app,lied to exp, equated to each of c1...cn */
  if (sqlo_solve (so, tb_dfe, pred, col_preds, after_preds))
    return 1;
  if (BOP_EQ != pred->_.bin.op)
    return 0;

  /* left if func of table and right is not of table ? */
  if (ST_P (pred->_.bin.left->dfe_tree, CALL_STMT))
    {
      if (sqlo_col_inverse_eq_1 (so, tb_dfe, pred->_.bin.left, pred->_.bin.right, col_preds, after_preds))
        return 1;
    }
  if (ST_P (pred->_.bin.right->dfe_tree, CALL_STMT))
    {
      if (sqlo_col_inverse_eq_1 (so, tb_dfe, pred->_.bin.right, pred->_.bin.left, col_preds, after_preds))
        return 1;
    }
  return 0;
}


int
st_is_call (ST * tree, char * f, int n_args)
{
  if (ST_P (tree, CALL_STMT) && DV_STRINGP (tree->_.call.name) && 0 == stricmp (f, tree->_.call.name)
      && BOX_ELEMENTS (tree->_.call.params) == n_args)
    return 1;
  return 0;
}

int enable_iri_like = 1;

int
sqlo_col_dtp_func  (sqlo_t *so, df_elt_t * tb_dfe, df_elt_t * pred, dk_set_t * col_preds)
{
  /* if 1 = isiri_id (col) and col is an any, then make this into a like */
  static char iri_like[] = {'T', DV_IRI_ID, 0};
  df_elt_t * col;
  ST * tree;
  if ((DFE_TRUE == pred) || (DFE_FALSE == pred))
    return 0;
  if (!enable_iri_like || DFE_BOP != pred->dfe_type || BOP_NOT != pred->_.bin.op)
    return 0;
  pred = pred->_.bin.left;
  if (DFE_BOP_PRED != pred->dfe_type || BOP_EQ != pred->_.bin.op
      || 0 != unbox ((ccaddr_t) pred->_.bin.left->dfe_tree) || !st_is_call (pred->_.bin.right->dfe_tree, "isiri_id", 1))
    return 0;
  col = pred->_.bin.right->_.call.args[0];
  if (DFE_COLUMN != col->dfe_type || DV_ANY != col->_.col.col->col_sqt.sqt_dtp)
    return 0;
  BIN_OP (tree, BOP_LIKE, col->dfe_tree, (ST *) t_box_dv_short_string (iri_like));
  t_set_push (col_preds, sqlo_df (so, tree));
  return 1;
}


void
sqlo_like_range (sqlo_t *so, df_elt_t * tb_dfe, df_elt_t * pred, dk_set_t * col_preds)
{
  ST * tree;
  dbe_table_t * tb = tb_dfe->_.table.ot->ot_table;
  /* if there is a like of a key part of a local table, then add the range conds implied by the like */
  dbe_column_t * col = pred->_.bin.left->_.col.col;
  if (tb_dfe->_.table.ot->ot_rds
      || col->col_sqt.sqt_dtp != DV_LONG_STRING)
    return;
  if (DFE_CONST == pred->_.bin.right->dfe_type
      && DV_STRINGP (pred->_.bin.right->dfe_tree)
      && strchr ("_?*%[", ((char*)pred->_.bin.right->dfe_tree)[0]))
    return;
  DO_SET (dbe_key_t *, key, &tb->tb_keys)
    {
      int pos = dk_set_position (key->key_parts, (void*) col);
      if (pos > -1 && pos < key->key_n_significant)
	goto is_key;
    }
  END_DO_SET();
  return;
 is_key:
  tree = (ST*) t_list (4, BOP_LTE, pred->_.bin.left->dfe_tree,
		     t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("__like_max"), t_list (2, pred->_.bin.right->dfe_tree, pred->_.bin.escape)),
		     NULL);
  t_set_push (col_preds, (void*) sqlo_df (so, tree));
  tree = (ST*) t_list (4, BOP_GTE, pred->_.bin.left->dfe_tree,
		     t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("__like_min"), t_list (2, pred->_.bin.right->dfe_tree, pred->_.bin.escape)),
		     NULL);
  t_set_push (col_preds, (void*) sqlo_df (so, tree));
}

void
sqlo_in_place_in_pred (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t *col_preds, dk_set_t *after_preds)
{
  dbe_key_t * key = tb_dfe->_.table.key;
  int part_no = 0;
  df_elt_t ** in_list;
  dk_set_t to_move = NULL;

  if (!key)
    return;
  DO_SET (df_elt_t *, pred, col_preds)
    {
      if (NULL == (in_list = sqlo_in_list (pred, NULL, NULL)))
	continue;
      part_no = 0;
      DO_SET (dbe_column_t *, col, &key->key_parts)
	{
	  if (in_list[0]->_.col.col == col)
	    goto next_pred;
	  part_no++;
	  if (part_no >= key->key_n_significant)
	    break;
	}
      END_DO_SET ();
      t_set_push (&to_move, (void*) pred);
next_pred:;
    }
  END_DO_SET ();
  DO_SET (df_elt_t *, pred, &to_move)
    {
      t_set_push (after_preds, (void*) pred);
      t_set_delete (col_preds, (void*) pred);
    }
  END_DO_SET ();
}

void
sqlo_tb_col_preds (sqlo_t * so, df_elt_t * tb_dfe, dk_set_t preds,
		   dk_set_t nj_preds)
{
  dk_set_t merged_col_preds = NULL, vdb_preds = NULL;
  dk_set_t col_preds = NULL;
  dk_set_t after_preds = NULL;
  dk_set_t to_place = NULL;
  df_elt_t *text_pred = NULL;
  df_elt_t ** in_list;
  int old_cond;
  DO_SET (df_elt_t *, pred, &preds)
    {
      if (text_pred && dk_set_member (text_pred->_.text.after_preds, pred))
	{ /*GK : this is already placed */
	  continue;
	}
      else if (DFE_TEXT_PRED == pred->dfe_type && !pred->_.text.geo)
	{
	  dk_set_t text_after_preds = NULL;
	  if (pred->_.text.type == 'c' || pred->_.text.type == 'x')
	    {
	      if (tb_dfe->_.table.text_pred)
		sqlc_new_error (so->so_sc->sc_cc, "37000", "SQ040",
		    "Can't have more than 1 contains/xcontains per table");
	      tb_dfe->_.table.text_pred = pred;

	    }
	  else
	    {
	      if (tb_dfe->_.table.xpath_pred)
		sqlc_new_error (so->so_sc->sc_cc, "37000", "SQ041",
		    "Can't have more than one xpath_contains/xquery_contains per table");
	      tb_dfe->_.table.xpath_pred = pred;
	    }
	  sqlo_tb_place_contains_cols (so, tb_dfe, pred);
	  DO_SET (df_elt_t *, _pred, &so->so_this_dt->ot_preds)
	    {
	      if (!_pred->dfe_is_placed && dfe_reqd_placed (_pred))
		{
		  _pred->dfe_is_placed = DFE_PLACED;
		  t_set_push (&text_after_preds, _pred);
		}
	    }
	  END_DO_SET ();
	  pred->_.text.after_test = sqlo_and_list_body (so, tb_dfe->dfe_locus, tb_dfe, text_after_preds);
	  pred->_.text.after_preds = text_after_preds;
	  text_pred = pred;
	}
      else if ((in_list = sqlo_in_list (pred, tb_dfe, NULL)))
	{
	  t_set_push (&col_preds, pred);

	}
      else if (DFE_BOP_PRED == pred->dfe_type)
	{
	  if (pred->_.bin.left->dfe_type == DFE_COLUMN
	      && ts_predicate_p (pred->_.bin.op)
	      && (op_table_t *) pred->_.bin.left->dfe_tables->data == tb_dfe->_.table.ot
	      && !dk_set_member (pred->_.bin.right->dfe_tables, (void*) tb_dfe->_.table.ot))
	    {
	      t_set_push (&col_preds, pred);
	      if (BOP_LIKE == pred->_.bin.op)
		sqlo_like_range (so, tb_dfe, pred, &col_preds);
	    }
	  else if (pred->_.bin.right->dfe_type == DFE_COLUMN
	      && ts_predicate_p (pred->_.bin.op)
	      && (op_table_t *) pred->_.bin.right->dfe_tables->data == tb_dfe->_.table.ot
	      && -1 != cmp_op_inverse (pred->_.bin.op)
	      && !dk_set_member (pred->_.bin.left->dfe_tables, (void*) tb_dfe->_.table.ot))
	    {
	      ptrlong op = cmp_op_inverse (pred->_.bin.op);
	      ST * inv_tree = (ST *) t_list (4, op, pred->_.bin.right->dfe_tree, pred->_.bin.left->dfe_tree, NULL);
	      df_elt_t * inv_pred = sqlo_df (so, inv_tree);
	      /* make the inv pred with a real tree for use in vdb locality analysis etc. */
	      pred->dfe_is_placed = DFE_PLACED;
	      inv_pred->_.bin.left = pred->_.bin.right;
	      inv_pred->_.bin.right = pred->_.bin.left;
	      inv_pred->_.bin.op = (int) cmp_op_inverse (pred->_.bin.op);
	      t_set_push (&col_preds, inv_pred);
	    }
	  else if (sqlo_col_inverse (so, tb_dfe, pred, &col_preds, &after_preds))
	    ; /* no action, preds added by func if true */
	  else
	    {
	      t_set_push (&after_preds, pred);
	    }
	}
      else if (sqlo_col_dtp_func (so, tb_dfe, pred, &col_preds))
	; /* no action, preds added by func if true */
      else if (sqlo_col_inverse (so, tb_dfe, pred, &col_preds, &after_preds))
	; /* no action, preds added by func if true */
      else
	t_set_push (&after_preds, pred);
      pred->dfe_is_placed = DFE_PLACED;
    }
  END_DO_SET();
  sqlo_table_locus (so, tb_dfe, col_preds, &after_preds, nj_preds, &vdb_preds);

  tb_dfe->_.table.col_preds = col_preds;
  /* save and reset the cond exp flag.  If you do col preds with this flag on, you get the expression calculated AFTER the col is fetched, not before */
  old_cond = so->so_place_code_forr_cond;
  so->so_place_code_forr_cond = 0;
  DO_SET (df_elt_t *, col_pred, &col_preds)
    {
      col_pred->dfe_locus = tb_dfe->dfe_locus;
      if ((in_list = sqlo_in_list (col_pred, NULL, NULL)))
	{
	  int inx;
	  for (inx = 1; inx < BOX_ELEMENTS (in_list); inx++)
	    {
	      sqlo_place_exp (so, tb_dfe, in_list[inx]);
	    }
	}
      else
	sqlo_place_exp (so, tb_dfe, col_pred->_.bin.right);
    }
  END_DO_SET();
  so->so_place_code_forr_cond = old_cond;
  merged_col_preds = sqlo_merge_col_preds (so, tb_dfe, col_preds, &to_place);
  if (MERGE_CONTRADICTION == merged_col_preds)
    {
      so->so_this_dt->ot_is_contradiction = 1;
      merged_col_preds = col_preds;
      to_place = NULL;
    }
  if (LOC_LOCAL != tb_dfe->dfe_locus)
    {
      merged_col_preds = col_preds; /* do not send the merged text to a remote, let it optimize it by itself */
      to_place = NULL;
    }
  DO_SET (df_elt_t *, merge_dfe, &to_place)
    {
      sqlo_place_exp (so, tb_dfe, merge_dfe);
    }
  END_DO_SET ();
  sqlo_choose_index (so, tb_dfe, &merged_col_preds, &after_preds);
  sqlo_in_place_in_pred (so, tb_dfe, &merged_col_preds, &after_preds);
  sqlo_tb_order (so, tb_dfe, merged_col_preds);
  if (after_preds)
    {
      tb_dfe->_.table.join_test = sqlo_and_list_body (so, tb_dfe->dfe_locus, tb_dfe, after_preds);
    }
  if (vdb_preds)
    {
      tb_dfe->_.table.vdb_join_test = sqlo_and_list_body (so, LOC_LOCAL, tb_dfe, vdb_preds);
    }
  if ((after_preds || vdb_preds) && !tb_dfe->_.table.index_path)
    tb_dfe->dfe_unit = 0; /* recalc the cost if more preds were added */
}

int
sqlo_is_constant_in_pred (sqlo_t *so, df_elt_t *pred)
{
  if (pred->dfe_type == DFE_BOP_PRED
      && DFE_IS_CONST (pred->_.bin.left)
      && pred->_.bin.right->dfe_type == DFE_CALL
      && pred->_.bin.right->dfe_tree->_.call.name
      && !strcmp (pred->_.bin.right->dfe_tree->_.call.name, t_sqlp_box_id_upcase ("one_of_these")))
    {
      unsigned inx;
      for (inx = 1; inx < BOX_ELEMENTS (pred->_.bin.right->_.call.args); inx++)
	{
	  df_elt_t *arg = pred->_.bin.right->_.call.args[inx];
	  if (!DFE_IS_CONST (arg))
	    return 0;
	}
      return 1;
    }
  return 0;
}


int
sqlo_is_constant_pred_arg (sqlo_t *so, df_elt_t *pred, df_elt_t *cmp, int cmp_to_find)
{
  unsigned inx;
  df_elt_t *col = pred->_.bin.right->_.call.args[0];
  collation_t * coll = DFE_COLUMN == col->dfe_type ? col->_.col.col->col_sqt.sqt_collation : NULL;
  for (inx = 1; inx < BOX_ELEMENTS (pred->_.bin.right->_.call.args); inx++)
    {
      if (cmp_to_find == cmp_boxes ((caddr_t) pred->_.bin.right->_.call.args[inx]->dfe_tree,
	    (caddr_t) cmp->dfe_tree, coll, coll))
	return 1;
    }
  return 0;
}


#define IS_NOT_IN(pred) ((pred)->_.bin.op == BOP_EQ)

int
sqlo_pred_contradiction (sqlo_t *so, df_elt_t *pred, int do_constant_check)
{
  if (DFE_TRUE == pred)
    return 0;
  if (DFE_FALSE == pred)
    return 1;
  if (DFE_BOP_PRED == pred->dfe_type)
    {
      if (sqlo_is_constant_in_pred (so, pred)
	  && DFE_IS_CONST (pred->_.bin.right->_.call.args[0]))
	{
	  int inx;
	  df_elt_t *left = pred->_.bin.right->_.call.args[0];
	  if (do_constant_check)
	    return 1;
	  DO_BOX (df_elt_t *, in_part, inx, pred->_.bin.right->_.call.args)
	    {
	      if (inx && DVC_MATCH == cmp_boxes (
			(caddr_t) in_part->dfe_tree, (caddr_t) left->dfe_tree, NULL, NULL))
		return IS_NOT_IN (pred) ? 1 : 0;
	    }
	  END_DO_BOX;
	  if (!IS_NOT_IN (pred))
	    return 1;
	}
      else if (DFE_IS_CONST (pred->_.bin.left) && DFE_IS_CONST (pred->_.bin.right))
	{
	  int res;
	  if (do_constant_check)
	    return 1;
	  res = cmp_boxes ((caddr_t)  pred->_.bin.left->dfe_tree,
	      (caddr_t) pred->_.bin.right->dfe_tree, NULL, NULL);
	  switch (res)
	    {
	      case DVC_UNKNOWN:
		  switch (pred->_.bin.op)
		    {
		      case BOP_EQ:
		      case BOP_LT:
		      case BOP_LTE:
		      case BOP_GT:
		      case BOP_GTE:
			  return 1;
		    }
		  break;
	      case DVC_LESS:
		  switch (pred->_.bin.op)
		    {
		      case BOP_EQ:
		      case BOP_GT:
		      case BOP_GTE:
			  return 1;
		    }
		  break;
	      case DVC_GREATER:
		  switch (pred->_.bin.op)
		    {
		      case BOP_EQ:
		      case BOP_LT:
		      case BOP_LTE:
			  return 1;
		    }
		  break;
	      case DVC_MATCH:
		  switch (pred->_.bin.op)
		    {
		      case BOP_LT:
		      case BOP_GT:
		      case BOP_NEQ:
			  return 1;
		    }
		  break;
	    }
	}
    }
  else if (DFE_BOP == pred->dfe_type)
    {
      if (ST_P (pred->dfe_tree, BOP_NOT))
        {
          df_elt_t *left = sqlo_const_cond (so, pred->_.bin.left);
          pred->_.bin.left = left;
          if (DFE_TRUE == left)
            return 1;
          if (DFE_FALSE == left)
            return 0;
          if (DFE_BOP == left->dfe_type &&
	    ST_P (left->dfe_tree, BOP_NOT)) /* NOT (NOT (x)) -> x */
	    return sqlo_pred_contradiction (so, left->_.bin.left, do_constant_check);
        }
      else if (ST_P (pred->dfe_tree, BOP_OR))
	{ /* contr OR contr -> cont */
	  if (sqlo_pred_contradiction (so, pred->_.bin.left, do_constant_check) &&
	      sqlo_pred_contradiction (so, pred->_.bin.right, do_constant_check))
	    return 1;
	}
    }
  return 0;
}


#define CONST_TO_IN_CONTRAD(so, op, inpred, constdfe) \
	      switch (op) \
		{ \
		  case BOP_EQ: \
		      return sqlo_is_constant_pred_arg (so, inpred, constdfe, DVC_MATCH) ? 0 : 1; \
		  case BOP_NEQ: \
		      return sqlo_is_constant_pred_arg (so, inpred, constdfe, DVC_MATCH); \
		  case BOP_LT: \
		      return sqlo_is_constant_pred_arg (so, inpred, constdfe, DVC_LESS) ? 0 : 1; \
		  case BOP_GT: \
		      return sqlo_is_constant_pred_arg (so, inpred, constdfe, DVC_GREATER) ? 0 : 1; \
		  case BOP_LTE: \
		      return ((sqlo_is_constant_pred_arg (so, inpred, constdfe, DVC_LESS) || \
			  sqlo_is_constant_pred_arg (so, inpred, constdfe, DVC_MATCH)) ? 0 : 1); \
		  case BOP_GTE: \
		      return ((sqlo_is_constant_pred_arg (so, inpred, constdfe, DVC_GREATER) || \
			  sqlo_is_constant_pred_arg (so, inpred, constdfe, DVC_MATCH)) ? 0 : 1); \
		}

#define CONST_TO_CONST_CONTRAD(res,op1,op2) \
	      switch (res) \
		{ \
		  case DVC_MATCH: \
		      return ( \
			  (op1 == BOP_EQ  && op2 == BOP_NEQ) || \
			  (op1 == BOP_NEQ && op2 == BOP_EQ) || \
			  (op1 == BOP_LT  && op2 == BOP_GT) || \
			  ((op1 == BOP_GT  && op2 == BOP_LT) ? 1 : 0)); \
		  case DVC_LESS: \
		      return ( \
			  (op1 == BOP_EQ && op2 == BOP_EQ) || \
			  (op1 == BOP_NEQ && op2 == BOP_EQ) || \
			  (op1 == BOP_LTE && op2 == BOP_GTE) || \
			  (op1 == BOP_LT && op2 == BOP_GTE) || \
			  (op1 == BOP_LTE && op2 == BOP_GT) || \
			  (op1 == BOP_LT  && op2 == BOP_GT)); \
		  case DVC_GREATER: \
		      return ( \
			  (op1 == BOP_EQ && op2 == BOP_EQ) || \
			  (op1 == BOP_NEQ && op2 == BOP_EQ) || \
			  (op1 == BOP_GT  && op2 == BOP_LT) || \
			  (op1 == BOP_GTE  && op2 == BOP_LT) || \
			  (op1 == BOP_GT  && op2 == BOP_LTE) || \
			  (op1 == BOP_GTE  && op2 == BOP_LTE)); \
		}

int
sqlo_preds_contradiction (sqlo_t *so, df_elt_t *tb_dfe, df_elt_t *pred1, df_elt_t *pred2)
{
  if (DFE_BOP_PRED == pred1->dfe_type && DFE_BOP_PRED == pred2->dfe_type)
    {
      df_elt_t *left_col = NULL, *right_col = NULL;
      if (sqlo_is_constant_in_pred (so, pred1) && !IS_NOT_IN (pred1))
	{
	  left_col = pred1->_.bin.right->_.call.args[0];
	  if (!left_col->dfe_tables ||
	      (op_table_t *) left_col->dfe_tables->data != tb_dfe->_.table.ot)
	    return 0;
	  if (sqlo_is_constant_in_pred (so, pred2) && !IS_NOT_IN (pred2))
	    {
	      unsigned inx;
	      right_col = pred2->_.bin.right->_.call.args[0];
	      if (right_col != left_col)
		return 0;

	      for (inx = 1; inx < BOX_ELEMENTS (pred1->_.bin.right->_.call.args); inx++)
		{
		  df_elt_t *elt1 = pred1->_.bin.right->_.call.args[inx];
		  if (sqlo_is_constant_pred_arg (so, pred2, elt1, DVC_MATCH))
		    return 0;
		}
	      return 1;
	    }
	  else if (pred2->_.bin.left->dfe_type == DFE_COLUMN
	      && DFE_IS_CONST (pred2->_.bin.right)
	      && pred2->_.bin.left == left_col)
	    {
	      CONST_TO_IN_CONTRAD (so, pred2->_.bin.op, pred1, pred2->_.bin.right);
	    }
	  else if (pred2->_.bin.right->dfe_type == DFE_COLUMN
	      && DFE_IS_CONST (pred2->_.bin.left)
	      &&  -1 != cmp_op_inverse (pred2->_.bin.op)
	      && pred2->_.bin.left == left_col)
	    {
	      CONST_TO_IN_CONTRAD (so, cmp_op_inverse (pred2->_.bin.op), pred1, pred2->_.bin.left);
	    }
	}
      else if (pred1->_.bin.left->dfe_type == DFE_COLUMN
	  && (op_table_t *) pred1->_.bin.left->dfe_tables->data == tb_dfe->_.table.ot
	  && DFE_IS_CONST (pred1->_.bin.right))
	{
	  left_col = pred1->_.bin.left;
	  if (sqlo_is_constant_in_pred (so, pred2) && !IS_NOT_IN (pred2)
	      && pred2->_.bin.right->_.call.args[0] == left_col)
	    {
	      CONST_TO_IN_CONTRAD (so, pred1->_.bin.op, pred2, pred1->_.bin.right);
	    }
	  else if (pred2->_.bin.left->dfe_type == DFE_COLUMN
	      && DFE_IS_CONST (pred2->_.bin.right)
	      && pred2->_.bin.left == left_col)
	    {
	      int res, op1 = pred1->_.bin.op;
	      int op2 = pred2->_.bin.op;
	      res = cmp_boxes ((caddr_t)  pred1->_.bin.right->dfe_tree,
		  (caddr_t) pred2->_.bin.right->dfe_tree, NULL, NULL);
	      CONST_TO_CONST_CONTRAD (res, op1, op2);
	    }
	  else if (pred2->_.bin.right->dfe_type == DFE_COLUMN
	      && DFE_IS_CONST (pred2->_.bin.left)
	      && -1 != cmp_op_inverse (pred2->_.bin.op)
	      && pred2->_.bin.right == left_col)
	    {
	      int res, op1 = pred1->_.bin.op;
	      ptrlong op2 = cmp_op_inverse (pred2->_.bin.op);
	      res = cmp_boxes ((caddr_t) pred1->_.bin.right->dfe_tree,
		  (caddr_t) pred2->_.bin.left->dfe_tree, NULL, NULL);
	      CONST_TO_CONST_CONTRAD (res, op1, op2);
	    }
	}
      else if (pred1->_.bin.right->dfe_type == DFE_COLUMN
	  && (op_table_t *) pred1->_.bin.right->dfe_tables->data == tb_dfe->_.table.ot
	  && -1 != cmp_op_inverse (pred1->_.bin.op)
	  && DFE_IS_CONST (pred1->_.bin.left))
	{
	  left_col = pred1->_.bin.right;
	  if (sqlo_is_constant_in_pred (so, pred2) && !IS_NOT_IN (pred2)
	      && pred2->_.bin.right->_.call.args[0] == left_col)
	    {
	      CONST_TO_IN_CONTRAD (so, cmp_op_inverse (pred1->_.bin.op), pred2, pred1->_.bin.left);
	    }
	  else if (pred2->_.bin.left->dfe_type == DFE_COLUMN
	      && DFE_IS_CONST (pred2->_.bin.right)
	      && pred2->_.bin.left == left_col)
	    {
	      int res;
	      ptrlong op1 = cmp_op_inverse (pred1->_.bin.op);
	      int op2 = pred2->_.bin.op;
	      res = cmp_boxes ((caddr_t) pred1->_.bin.left->dfe_tree,
		  (caddr_t) pred2->_.bin.right->dfe_tree, NULL, NULL);
	      CONST_TO_CONST_CONTRAD (res, op1, op2);
	    }
	  else if (pred2->_.bin.right->dfe_type == DFE_COLUMN
	      && DFE_IS_CONST (pred2->_.bin.left)
	      && -1 != cmp_op_inverse (pred2->_.bin.op)
	      && pred2->_.bin.right == left_col)
	    {
	      int res;
	      ptrlong op1 = cmp_op_inverse (pred1->_.bin.op);
	      ptrlong op2 = cmp_op_inverse (pred2->_.bin.op);
	      res = cmp_boxes ((caddr_t) pred1->_.bin.left->dfe_tree,
		  (caddr_t) pred2->_.bin.left->dfe_tree, NULL, NULL);
	      CONST_TO_CONST_CONTRAD (res, op1, op2);
	    }
	}
    }
  return 0;
}


int
sqlo_or_pred_table_accel_preds (sqlo_t *so, df_elt_t *term, op_table_t *ot, dk_set_t *out_set)
{
  df_elt_t *and_pred = NULL;
  if (dk_set_length (term->dfe_tables) == 1 && ((op_table_t *)term->dfe_tables->data == ot))
    {
      and_pred = sqlo_layout_copy_1 (so, term, NULL);
    }
  else if (DFE_BOP == term->dfe_type && BOP_AND == term->_.bin.op)
    {
      dk_set_t and_list = sqlo_connective_list (term, term->_.bin.op);
      DO_SET (df_elt_t *, elt, &and_list)
	{
	  if (dk_set_length (elt->dfe_tables) == 1 && ((op_table_t *)elt->dfe_tables->data == ot))
	    {
	      elt = sqlo_layout_copy_1 (so, elt, NULL);
	      if (!and_pred)
		and_pred = elt;
	      else
		{
		  ST *new_tree;
		  df_elt_t *new_and_pred;

		  BIN_OP (new_tree, BOP_AND, elt->dfe_tree, and_pred->dfe_tree);
		  new_and_pred = sqlo_new_dfe (so, DFE_BOP, new_tree);

		  new_and_pred->_.bin.right = and_pred;
		  new_and_pred->_.bin.left = elt;
		  new_and_pred->_.bin.op = BOP_AND;
		  new_and_pred->dfe_tables = t_cons (ot, NULL);
		  and_pred = new_and_pred;
		}
	    }
	}
      END_DO_SET ();
    }
  if (and_pred)
    {
      if (out_set)
	t_set_push (out_set, and_pred);
      return 1;
    }
  else
    return 0;
}


void
sqlo_tb_check_contradiction (sqlo_t *so, df_elt_t *tb_dfe, dk_set_t preds)
{
  if (!so->so_this_dt->ot_is_contradiction && !tb_dfe->_.table.ot->ot_is_outer)
    {
      s_node_t *iter;
      DO_SET_WRITABLE (df_elt_t *, pred, iter, &preds)
	{
	  if (sqlo_pred_contradiction (so, pred, 0))
	    {
	      so->so_this_dt->ot_is_contradiction = 1;
	      break;
	    }
	  else
	    {
	      s_node_t *up_to = iter->next;
	      DO_SET (df_elt_t *, pred2, &up_to)
		{
		  if (sqlo_preds_contradiction (so, tb_dfe, pred, pred2))
		    {
		      so->so_this_dt->ot_is_contradiction = 1;
		      break;
		    }
		}
	      END_DO_SET ();
	      if (so->so_this_dt->ot_is_contradiction == 1)
		break;
	    }
	}
      END_DO_SET ();
    }
}


static int
sqlo_is_invariant_in_pred (sqlo_t *so, df_elt_t *pred)
{
  if (pred->dfe_type == DFE_BOP_PRED
      && DFE_IS_CONST (pred->_.bin.left)
      && pred->_.bin.right->dfe_type == DFE_CALL
      && pred->_.bin.right->dfe_tree->_.call.name
      && !strcmp (pred->_.bin.right->dfe_tree->_.call.name, t_sqlp_box_id_upcase ("one_of_these")))
    {
      unsigned inx;
      for (inx = 1; inx < BOX_ELEMENTS (pred->_.bin.right->_.call.args); inx++)
	{
	  df_elt_t *arg = pred->_.bin.right->_.call.args[inx];
	  if (arg->dfe_tables)
	    return 0;
	}
      return 1;
    }
  return 0;
}


static ST *
sqlo_const_to_const_invariant (sqlo_t *so, int op1, int op2, ST *arg1, ST *arg2, caddr_t arg2_more)
{
  ST *ret = NULL;

  switch (op1)
    {
      case BOP_EQ:
	  BIN_OP (ret, op2, (ST *) t_box_copy_tree ((caddr_t) arg1),
	      (ST *) t_box_copy_tree ((caddr_t) arg2));
	  if (op2 == BOP_LIKE)
	    ret->_.bin_exp.more = t_box_copy_tree (arg2_more);
	  break;

      case BOP_LT:
	  if (BOP_GT == op2 || BOP_GTE == op2 || BOP_EQ == op2)
	    {
	      BIN_OP (ret, BOP_GT, (ST *) t_box_copy_tree ((caddr_t) arg1),
		  (ST *) t_box_copy_tree ((caddr_t) arg2));
	    }
	  break;

      case BOP_LTE:
	  if (BOP_GTE == op2 || BOP_GT == op2)
	    {
	      BIN_OP (ret, op2, (ST *) t_box_copy_tree ((caddr_t) arg1),
		  (ST *) t_box_copy_tree ((caddr_t) arg2));
	    }
	  else if (BOP_EQ == op2)
	    {
	      BIN_OP (ret, BOP_GTE, (ST *) t_box_copy_tree ((caddr_t) arg1),
		  (ST *) t_box_copy_tree ((caddr_t) arg2));
	    }
	  break;

      case BOP_GT:
	  if (BOP_LT == op2 || BOP_LTE == op2 || BOP_EQ == op2)
	    {
	      BIN_OP (ret, BOP_LT, (ST *) t_box_copy_tree ((caddr_t) arg1),
		  (ST *) t_box_copy_tree ((caddr_t) arg2));
	    }
	  break;

      case BOP_GTE:
	  if (BOP_LTE == op2 || BOP_LT == op2)
	    {
	      BIN_OP (ret, op2, (ST *) t_box_copy_tree ((caddr_t) arg1),
		  (ST *) t_box_copy_tree ((caddr_t) arg2));
	    }
	  else if (BOP_EQ == op2)
	    {
	      BIN_OP (ret, BOP_LTE, (ST *) t_box_copy_tree ((caddr_t) arg1),
		  (ST *) t_box_copy_tree ((caddr_t) arg2));
	    }
	  break;

      case BOP_NEQ:
	  if (BOP_EQ == op2 || BOP_LTE == op2 || BOP_GTE == op2)
	    {
	      BIN_OP (ret, BOP_NEQ, (ST *) t_box_copy_tree ((caddr_t) arg1),
		  (ST *) t_box_copy_tree ((caddr_t) arg2));
	    }
	  break;
    }
  return ret;
}


#define DFE_IS_INVARIANT(dfe) (dfe->dfe_tables == NULL)

static df_elt_t *
sqlo_preds_make_invariant (sqlo_t *so, df_elt_t *tb_dfe, df_elt_t *pred1, df_elt_t * pred2)
{
  ST *tree = NULL;

  if (DFE_BOP_PRED == pred1->dfe_type && DFE_BOP_PRED == pred2->dfe_type)
    {
      df_elt_t *left_col = NULL, *right_col = NULL;
      if (sqlo_is_invariant_in_pred (so, pred1) && !IS_NOT_IN (pred1))
	{
	  left_col = pred1->_.bin.right->_.call.args[0];
	  if (left_col->dfe_type == DFE_COLUMN &&
	      (!tb_dfe || (op_table_t *) left_col->dfe_tables->data == tb_dfe->_.table.ot))
	    {
	      if (sqlo_is_invariant_in_pred (so, pred2) && !IS_NOT_IN (pred2) &&
		  (!sqlo_is_constant_in_pred (so, pred2) || !sqlo_is_constant_in_pred (so, pred1)))
		{
		  unsigned inx;
		  right_col = pred2->_.bin.right->_.call.args[0];
		  if (right_col == left_col)
		    for (inx = 1; inx < BOX_ELEMENTS (pred1->_.bin.right->_.call.args); inx++)
		      {
			ST *in_cond;
			BIN_OP (in_cond, BOP_EQ, (ST *) t_box_num (0),
			    t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("one_of_these"),
			      t_box_copy_tree ((caddr_t) pred2->_.bin.right->dfe_tree->_.call.params)));
			in_cond->_.bin_exp.right->_.call.params[0] =
			    (ST *) t_box_copy_tree ((caddr_t) pred1->_.bin.right->_.call.args[inx]->dfe_tree);
			in_cond = t_listst (3, BOP_NOT, in_cond, NULL);
			tree = in_cond;
		      }
		}
	      else if (pred2->_.bin.left->dfe_type == DFE_COLUMN
		      && DFE_IS_INVARIANT (pred2->_.bin.right)
		  && pred2->_.bin.left == left_col
		  && pred2->_.bin.op == BOP_EQ
		  && (!sqlo_is_constant_in_pred (so, pred1) || !DFE_IS_CONST (pred2->_.bin.right)))
		{
		  ST *res;
		  BIN_OP (res, BOP_EQ, (ST *) t_box_num (0),
		      t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("one_of_these"),
			t_box_copy_tree ((caddr_t) pred1->_.bin.right->dfe_tree->_.call.params)));
		  tree = res;
		  tree->_.bin_exp.right->_.call.params[0] =
		      (ST *) t_box_copy_tree ((caddr_t) pred2->_.bin.right->dfe_tree);
		  tree = t_listst (3, BOP_NOT, tree, NULL);
		}
	      else if (pred2->_.bin.right->dfe_type == DFE_COLUMN
		  && DFE_IS_INVARIANT (pred2->_.bin.left)
		  && BOP_EQ == cmp_op_inverse (pred2->_.bin.op)
		  && pred2->_.bin.right == left_col
		  && (!sqlo_is_constant_in_pred (so, pred1) || !DFE_IS_CONST (pred2->_.bin.left)))
		{
		  ST *res;
		  BIN_OP (res, BOP_EQ, (ST *) t_box_num (0),
		      t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("one_of_these"),
			t_box_copy_tree ((caddr_t) pred1->_.bin.right->dfe_tree->_.call.params)));
		  tree = res;
		  tree->_.bin_exp.right->_.call.params[0] =
		      (ST *) t_box_copy_tree ((caddr_t) pred1->_.bin.left->dfe_tree);
		  tree = t_listst (3, BOP_NOT, tree, NULL);
		}
	    }
	}
      else if (pred1->_.bin.left->dfe_type == DFE_COLUMN
	  && (!tb_dfe || (op_table_t *) pred1->_.bin.left->dfe_tables->data == tb_dfe->_.table.ot)
	  && DFE_IS_INVARIANT (pred1->_.bin.right))
	{
	  left_col = pred1->_.bin.left;
	  if (sqlo_is_invariant_in_pred (so, pred2) && !IS_NOT_IN (pred2)
	      && pred2->_.bin.right->_.call.args[0] == left_col
	      && (!DFE_IS_CONST (pred1->_.bin.right) || !sqlo_is_constant_in_pred (so, pred2)))
	    {
	      ST *res;
	      BIN_OP (res, BOP_EQ, (ST *) t_box_num (0),
		  t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("one_of_these"),
		    t_box_copy_tree ((caddr_t) pred2->_.bin.right->dfe_tree->_.call.params)));
	      tree = res;
	      tree->_.bin_exp.right->_.call.params[0] =
		  (ST *) t_box_copy_tree ((caddr_t) pred1->_.bin.right->dfe_tree);
	      tree = t_listst (3, BOP_NOT, tree, NULL);
	    }
	  else if (pred2->_.bin.left->dfe_type == DFE_COLUMN
	      && DFE_IS_INVARIANT (pred2->_.bin.right)
	      && pred2->_.bin.left == left_col
	      && (!DFE_IS_CONST (pred2->_.bin.right) || !DFE_IS_CONST (pred1->_.bin.right)))
	    {
	      tree = sqlo_const_to_const_invariant (so, pred1->_.bin.op, pred2->_.bin.op,
		  pred1->_.bin.right->dfe_tree, pred2->_.bin.right->dfe_tree,
		  pred2->_.bin.op == BOP_LIKE ? pred2->dfe_tree->_.bin_exp.more : NULL
		  );
	    }
	  else if (pred2->_.bin.right->dfe_type == DFE_COLUMN
	      && DFE_IS_INVARIANT (pred2->_.bin.left)
	      && -1 != cmp_op_inverse (pred2->_.bin.op)
	      && pred2->_.bin.right == left_col
	      && (!DFE_IS_CONST (pred2->_.bin.left) || !DFE_IS_CONST (pred1->_.bin.right)))
	    {
	      tree = sqlo_const_to_const_invariant (so, pred1->_.bin.op, (int) cmp_op_inverse (pred2->_.bin.op),
		  pred1->_.bin.right->dfe_tree, pred2->_.bin.left->dfe_tree,
		  pred2->_.bin.op == BOP_LIKE ? pred2->dfe_tree->_.bin_exp.more : NULL
		  );
	    }
	}
      else if (pred1->_.bin.right->dfe_type == DFE_COLUMN
	  && (!tb_dfe || (op_table_t *) pred1->_.bin.right->dfe_tables->data == tb_dfe->_.table.ot)
	  && -1 != cmp_op_inverse (pred1->_.bin.op)
	  && DFE_IS_INVARIANT (pred1->_.bin.left))
	{
	  int op1 = (int) cmp_op_inverse (pred1->_.bin.op);
	  left_col = pred1->_.bin.right;
	  if (sqlo_is_invariant_in_pred (so, pred2) && !IS_NOT_IN (pred2)
	      && pred2->_.bin.right->_.call.args[0] == left_col
	      && op1 == BOP_EQ
	      && (!DFE_IS_CONST (pred1->_.bin.left) || !sqlo_is_constant_in_pred (so, pred2)))
	    {
	      ST *res;
	      BIN_OP (res, BOP_EQ, (ST *) t_box_num (0),
		  t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("one_of_these"),
		    t_box_copy_tree ((caddr_t) pred2->_.bin.right->dfe_tree->_.call.params)));
	      tree = res;
	      tree->_.bin_exp.right->_.call.params[0] =
		  (ST *) t_box_copy_tree ((caddr_t) pred1->_.bin.left->dfe_tree);
	      tree = t_listst (3, BOP_NOT, tree, NULL);
	    }
	  else if (pred2->_.bin.left->dfe_type == DFE_COLUMN
	      && DFE_IS_INVARIANT (pred2->_.bin.right)
	      && pred2->_.bin.left == left_col
	      && (!DFE_IS_CONST (pred2->_.bin.right) || !DFE_IS_CONST (pred1->_.bin.left)))
	    {
	      tree = sqlo_const_to_const_invariant (so, op1, pred2->_.bin.op,
		  pred1->_.bin.left->dfe_tree, pred2->_.bin.right->dfe_tree,
		  pred2->_.bin.op == BOP_LIKE ? pred2->dfe_tree->_.bin_exp.more : NULL
		  );
	    }
	  else if (pred2->_.bin.right->dfe_type == DFE_COLUMN
	      && DFE_IS_INVARIANT (pred2->_.bin.left)
	      && -1 != cmp_op_inverse (pred2->_.bin.op)
	      && pred2->_.bin.right == left_col
	      && (!DFE_IS_CONST (pred2->_.bin.left) || !DFE_IS_CONST (pred1->_.bin.left)))
	    {
	      tree = sqlo_const_to_const_invariant (so, op1, (int) cmp_op_inverse (pred2->_.bin.op),
		  pred1->_.bin.left->dfe_tree, pred2->_.bin.left->dfe_tree,
		  pred2->_.bin.op == BOP_LIKE ? pred2->dfe_tree->_.bin_exp.more : NULL
		  );
	    }
	}
    }
  return tree ? sqlo_df (so, tree) : NULL;
}


int
sqlo_parse_tree_has_node (ST *tree, long node)
{
  if (ST_P (tree, node))
    return 1;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree))
    {
      int inx;
      DO_BOX (ST *, elt, inx, ((ST **)tree))
	{
	  if (sqlo_parse_tree_has_node (elt, node))
	    return 1;
	}
      END_DO_BOX;
    }
  return 0;
}


int
sqlo_parse_tree_count_node (ST *tree, long *nodes, int n_nodes)
{
  int n_found_nodes = 0;
  int inx;

  for (inx = 0; inx < n_nodes; inx++)
    {
      if (ST_P (tree, nodes[inx]))
	return 1;
    }
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree))
    {
      DO_BOX (ST *, elt, inx, ((ST **)tree))
	{
	  n_found_nodes += sqlo_parse_tree_count_node (elt, nodes, n_nodes);
	}
      END_DO_BOX;
    }
  return n_found_nodes;
}


void
sqlo_tb_check_invariant_preds (sqlo_t *so, df_elt_t *tb_dfe, dk_set_t preds)
{
  s_node_t *iter;
  DO_SET_WRITABLE (df_elt_t *, pred, iter, &preds)
    {
      if (DFE_IS_INVARIANT (pred) &&
	  (DFE_BOP_PRED == pred->dfe_type || DFE_BOP == pred->dfe_type) &&
	  !sqlo_pred_contradiction (so, pred, 1) &&
	  !sqlo_parse_tree_has_node (pred->dfe_tree, SELECT_STMT))
	{
	  t_set_push (&so->so_this_dt->ot_invariant_preds, pred);
	}
      else if (!sqlo_parse_tree_has_node (pred->dfe_tree, SELECT_STMT))
	{
	  s_node_t *up_to = iter->next;
	  DO_SET (df_elt_t *, pred2, &up_to)
	    {
	      df_elt_t *pred_invariant;
	      if (!sqlo_parse_tree_has_node (pred2->dfe_tree, SELECT_STMT) &&
		  NULL != (pred_invariant = sqlo_preds_make_invariant (so, tb_dfe, pred, pred2)))

		{
		  df_elt_t * val = sqlo_const_cond (so, pred_invariant);
		  if (DFE_TRUE != val)
		    t_set_push (&so->so_this_dt->ot_invariant_preds, pred_invariant);
		}
	    }
	  END_DO_SET ();
	}
    }
  END_DO_SET ();
}


#define SET_BEING_PLACED(tb, f) \
{\
  if (DFE_TABLE == tb->dfe_type)  \
    tb->_.table.is_being_placed = f;\
  else if (DFE_DT == tb->dfe_type || DFE_EXISTS == tb->dfe_type || DFE_VALUE_SUBQ == tb->dfe_type)\
    tb->_.sub.is_being_placed = f;\
}

void
sqlo_place_table (sqlo_t * so, df_elt_t * tb_dfe)
{
  op_table_t * ot = dfe_ot (tb_dfe);
  dk_set_t nj_preds = NULL;
  dk_set_t preds = NULL, large_preds = NULL;
  df_elt_t *text_pred = NULL;
  tb_dfe->dfe_is_placed = DFE_PLACED;
  if (DFE_TABLE == tb_dfe->dfe_type && tb_dfe->_.table.is_leaf)
    {
      sqlo_place_dfe_after (so, tb_dfe->dfe_locus, so->so_gen_pt, tb_dfe);
      return;
    }
  SET_BEING_PLACED (tb_dfe, 1);

  /*GK: locate the text pred */
  if (DFE_DT != tb_dfe->dfe_type)
    {
      DO_SET (df_elt_t *, pred, &so->so_this_dt->ot_preds)
	{
	  if (pred->dfe_type == DFE_TEXT_PRED &&
	      !pred->dfe_is_placed &&
	      dfe_reqd_placed (pred))
	    {
	      text_pred = pred;
	      break;
	    }
	}
      END_DO_SET ();
    }

  DO_SET (df_elt_t *, pred, &so->so_this_dt->ot_preds)
    {
      if (!pred->dfe_is_placed && DFE_TABLE == tb_dfe->dfe_type &&
	  pred->dfe_type == DFE_BOP && pred->_.bin.op == BOP_OR &&
	  dk_set_length (pred->dfe_tables) > 1 && dk_set_member (pred->dfe_tables, ot) &&
	  !dfe_reqd_placed (pred))
	{ /* if it's an OR with ANDs place some additional after_code for the table */
	  dk_set_t or_list = sqlo_connective_list (pred, pred->_.bin.op);
	  dk_set_t cond_list = NULL;
	  df_elt_t *or_pred = NULL;
	  DO_SET (df_elt_t *, term, &or_list)
	    {
	      if (!sqlo_or_pred_table_accel_preds (so, term, ot, &cond_list))
		goto next_pred;
	    }
	  END_DO_SET ();
	  DO_SET (df_elt_t *, cond, &cond_list)
	    {
	      cond = sqlo_layout_copy_1 (so, cond, NULL);
              if (DFE_TRUE == cond)
                cond = sqlo_wrap_dfe_true_or_false (so, DFE_TRUE);
	      if (!or_pred)
		or_pred = cond;
	      else
		{
		  ST *new_tree;
		  df_elt_t *new_or_pred;

		  BIN_OP (new_tree, BOP_OR, cond->dfe_tree, or_pred->dfe_tree);
		  new_or_pred = sqlo_new_dfe (so, DFE_BOP, new_tree);
		  new_or_pred->_.bin.right = or_pred;
		  new_or_pred->_.bin.left = cond;
		  new_or_pred->_.bin.op = BOP_OR;
		  new_or_pred->dfe_tables = t_cons (ot, NULL);
		  or_pred = new_or_pred;
		}
	    }
	  END_DO_SET ();
	  if (or_pred)
	    t_set_push (&preds, or_pred);
	}

next_pred:

      if (!pred->dfe_is_placed && dfe_reqd_placed (pred))
	{
	  if (DFE_DT == tb_dfe->dfe_type)
	    {
	      long n_nodes[] = { TABLE_DOTTED, PROC_TABLE };
	      int n_tbs;

	      n_tbs = sqlo_parse_tree_count_node (pred->dfe_tree, n_nodes, sizeof (n_nodes) / sizeof (long));
	      if (n_tbs > 4)
		t_set_push (&large_preds, pred);
	      else
		t_set_push (&preds, pred);
	    }
	  else if (pred->dfe_type != DFE_TEXT_PRED)
	    { /*GK: place and push only the non-text dependent preds */
	      pred->dfe_is_placed = DFE_PLACED;
	      t_set_push (&preds, pred);
	    }
	}
    }
  END_DO_SET ();
  if (text_pred)
    { /*GK: now push all the preds that were not placed because of the text pred */
      text_pred->dfe_is_placed = DFE_PLACED;
      DO_SET (df_elt_t *, pred, &so->so_this_dt->ot_preds)
	{
	  if (!pred->dfe_is_placed && dfe_reqd_placed (pred))
	    t_set_push (&preds, pred);
	}
      END_DO_SET ();
      /*GK: it's important to push the text pred last, so it's found first by sqlo_tb_col_preds */
      t_set_push (&preds, text_pred);
    }
  sqlo_place_dfe_after (so, tb_dfe->dfe_locus, so->so_gen_pt, tb_dfe);
    {
      dk_set_t contr_preds = preds;
      if (ot->ot_join_preds && !ot->ot_is_outer)
	{
	  contr_preds = t_NCONC (t_set_copy (contr_preds), t_set_copy (ot->ot_join_preds));
	}
      if (large_preds)
	{
	  contr_preds = t_NCONC (t_set_copy (contr_preds), t_set_copy (large_preds));
	}
      sqlo_tb_check_contradiction (so, tb_dfe, contr_preds);
      if (!so->so_this_dt->ot_is_contradiction)
	sqlo_tb_check_invariant_preds (so, tb_dfe, contr_preds);
    }

  if (ot->ot_join_preds && !ST_P (ot->ot_dt, PROC_TABLE))
    {
      if (ot->ot_is_outer)
	{
	  nj_preds = preds;
	  preds = ot->ot_join_preds;
	}
      else
	{
	  /* for a qualified inner join the join preds and applicable where preds go into the same list. */
	  preds = dk_set_conc (preds, ot->ot_join_preds);
	}
    }
  if (DFE_DT == tb_dfe->dfe_type)
    {
      sqlo_place_dt (so, tb_dfe, preds);
      DO_SET (df_elt_t *, pred, &preds)
	{
	  pred->dfe_is_placed = DFE_PLACED;
	}
      END_DO_SET ();
      if (large_preds)
	nj_preds = dk_set_conc (nj_preds, large_preds);

      DO_SET (df_elt_t *, pred, &nj_preds)
	{
	  pred->dfe_is_placed = DFE_PLACED;
	}
      END_DO_SET ();
      if (nj_preds)
	{
	  df_elt_t * dt_dfe;
	  dt_dfe = so->so_this_dt->ot_work_dfe; /* the after join test is in the loc of the enclosing dt, not of the outer table */
	  /*if (tb_dfe->_.sub.generated_dfe->dfe_type != DFE_DT)
	    SQL_GPF_T1 (so->so_sc->sc_cc,
		"an outer union must be wrapped into a dt in order to have an after join test");*/
	  if (tb_dfe->_.sub.generated_dfe->dfe_type == DFE_DT)
	    {
	      tb_dfe->_.sub.generated_dfe->_.sub.after_join_test =
		  sqlo_and_list_body (so, dt_dfe->dfe_locus, tb_dfe, nj_preds);
	      tb_dfe->_.sub.dt_preds = dk_set_conc (nj_preds, tb_dfe->_.sub.dt_preds);
	    }
	  else
	    {
	      tb_dfe->_.sub.after_join_test =
		  sqlo_and_list_body (so, dt_dfe->dfe_locus, tb_dfe, nj_preds);
	      tb_dfe->_.sub.dt_preds = dk_set_conc (nj_preds, tb_dfe->_.sub.dt_preds);
	    }
	}
    }
  else
    {
      tb_dfe->_.table.all_preds = preds;
      so->so_gen_pt = tb_dfe;
#if 0 /*GK: no need to */
      DO_SET (op_virt_col_t *, vc, &ot->ot_virtual_cols)
	{
	  df_elt_t *vc_dfe = sqlo_df_virt_col (so, vc);
	  if (vc->vc_is_out)
	    sqlo_place_exp (so, tb_dfe->dfe_super, vc_dfe);
	}
      END_DO_SET ();
#endif
      sqlo_tb_col_preds (so, tb_dfe, preds, nj_preds);
      if (nj_preds)
	{
	  df_elt_t * dt_dfe = so->so_this_dt->ot_work_dfe; /* the after join test is in the loc of the enclosing dt, not of the outer table */
	  tb_dfe->_.table.after_join_test = sqlo_and_list_body (so, dt_dfe->dfe_locus, tb_dfe, nj_preds);
	  tb_dfe->_.table.all_preds = dk_set_conc (nj_preds, tb_dfe->_.table.all_preds);
	}
    }
  SET_BEING_PLACED (tb_dfe, 0);
}



df_elt_t *
sqlo_top_dfe (df_elt_t * dfe)
{
  while (dfe->dfe_super)
    dfe = dfe->dfe_super;
  return dfe;
}


void
sqlo_place_hash_filler (sqlo_t * so, df_elt_t * dfe, df_elt_t * filler)
{
  df_elt_t * top = sqlo_top_dfe (dfe);
  df_elt_t * cr = top->_.sub.first;
  while (cr)
    {
      if (DFE_TABLE == cr->dfe_type)
	{
	  if (HR_FILL == cr->_.table.hash_role
	      && filler->_.table.ot == cr->_.table.ot)
	    return; /* placed */
	}
      if (DFE_TABLE == cr->dfe_type && HR_FILL != cr->_.table.hash_role)
	break;
      if (DFE_DT == cr->dfe_type ||
	  DFE_CONTROL_EXP == cr->dfe_type ||
	  DFE_VALUE_SUBQ == cr->dfe_type)
	break;
      cr = cr->dfe_next;
    }
  sqlo_place_dfe_after (so, filler->dfe_locus, cr->dfe_prev, filler);
}


int
dfe_is_tb_only (df_elt_t * dfe, op_table_t * ot)
{
  if (dfe->dfe_tables && !dfe->dfe_tables->next
      && (void*) ot == dfe->dfe_tables->data)
    return 1;
  else
    return 0;
}


float
dfe_arity_with_supers (df_elt_t * dfe)
{
  float sub_arity = 1;
  if (!dfe)
    return 1;
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &sub_arity, 8000))
    sqlc_error (dfe->dfe_sqlo->so_sc->sc_cc, "42000", "Stack Overflow");
  while (dfe->dfe_prev)
    {
      if (DFE_TABLE == dfe->dfe_type)
	{
	  if (0 == dfe->dfe_unit)
	    {
	      /* not scored yet */
	      sqlo_score (dfe->dfe_super, dfe->dfe_super->_.sub.in_arity);
	    }
	  sub_arity *= dfe->dfe_arity;
	}
      dfe = dfe->dfe_prev;
    }
  while (dfe->dfe_prev)
    dfe = dfe->dfe_prev;
  return (sub_arity * dfe_arity_with_supers (dfe->dfe_super));
}


int hash_join_enable = 0;
int hash_join_full_table = 1;


void
sqlo_outer_hash (sqlo_t * so, df_elt_t * dfe)
{
  dk_set_t after = t_set_diff (dfe->_.table.all_preds, dfe->_.table.ot->ot_join_preds);
  dfe->_.table.after_join_test = sqlo_and_list_body (so, LOC_LOCAL, dfe, after);
}


void
sqt_types_set (sql_type_t *left, sql_type_t *right)
{
  if (DV_UNKNOWN == right->sqt_dtp)
    {
      *right = *left;
    }
  else if (DV_UNKNOWN == left->sqt_dtp)
    {
      *left = *right;
    }
}


void
sqlo_hash_filler (sqlo_t * so, df_elt_t * fill_dfe, dk_set_t preds, float * fill_unit, float * fill_arity, float * ov)
{
  fill_dfe->_.table.is_unique = 0; /* the filler is not unique even if the ref is */
  fill_dfe->_.table.inx_preds = NULL;
  fill_dfe->_.table.col_preds = NULL;
  fill_dfe->_.table.col_pred_merges = NULL;
  fill_dfe->_.table.all_preds = preds;
  fill_dfe->_.table.join_test = NULL;
  fill_dfe->_.table.after_join_test = NULL;
  fill_dfe->_.table.vdb_join_test = NULL;
  fill_dfe->dfe_next = NULL;
  fill_dfe->_.table.key = NULL;
  sqlo_tb_col_preds (so, fill_dfe, preds, NULL);
  dfe_unit_cost (fill_dfe, 1, fill_unit, fill_arity, ov);
}


int enable_hash_fill_preds = 1;


void
sqlo_best_hash_filler (sqlo_t * so, df_elt_t * fill_dfe, int remote, dk_set_t * org_preds, dk_set_t * post_preds, float * fill_unit, float * fill_arity, float * ov)
{
  float best, ov1 = 0, ov2 = 0;
  if (remote != RHJ_LOCAL)
    {
      sqlo_hash_filler (so, fill_dfe, *org_preds, fill_unit, fill_arity, &ov1);
      *fill_unit += ov1;
      return;
    }
  sqlo_hash_filler (so, fill_dfe, NULL, fill_unit, fill_arity, &ov1);
  best = *fill_unit;
  if (enable_hash_fill_preds && *org_preds
      && (sqlo_max_mp_size == 0 || (THR_TMP_POOL)->mp_bytes < sqlo_max_mp_size / 2))
    {
      sqlo_hash_filler (so, fill_dfe, *org_preds, fill_unit, fill_arity, &ov2);
      *fill_unit += ov2;
      if (*fill_unit < 0.7 * best)
	{
	  return;
	}
      sqlo_hash_filler (so, fill_dfe, NULL, fill_unit, fill_arity, ov);
      *post_preds = dk_set_conc (t_set_copy (*org_preds), *post_preds);
    }
}


int
sqlo_try_hash (sqlo_t * so, df_elt_t * dfe, op_table_t * super_ot, float * score_ret)
{
  dk_set_t hash_pred_locus_refs = NULL;
  int remote = sqlo_try_remote_hash (so, dfe);
  float ov = 0;
  dk_set_t preds = dfe->_.table.ot->ot_is_outer ? dfe->_.table.ot->ot_join_preds :  dfe->_.table.all_preds;
  float fill_unit, fill_arity, ref_arity;
  dk_set_t hash_refs = NULL, hash_keys = NULL;
  df_elt_t * fill_dfe;
  dk_set_t org_preds = NULL, post_preds = NULL;
  int mode, has_non_inv_key = 0, dt_mode;
  op_table_t * ot = dfe->_.table.ot;
  if (DFE_TABLE != dfe->dfe_type)
    return 0;
  if (ot && ot->ot_table && ot->ot_table->tb_name && 0 == stricmp (ot->ot_table->tb_name, "DB.DBA.RDF_QUAD"))
    return 0;
  if (RHJ_NONE == remote)
    return 0;
  if (dfe->_.table.inx_op && dfe->_.table.inx_op->dio_is_join)
    return 0; /* an inx op that joins tables is preferred over hash of one table.  Also if hash won, would have to unplace the joined table(s) of the inx op.  */
  mode = (int) (ptrlong) sqlo_opt_value (ot->ot_opts, OPT_JOIN);
  dt_mode = (int) (ptrlong) sqlo_opt_value (super_ot->ot_opts, OPT_JOIN);
  if (!mode)
    mode = dt_mode;
  if (0 && !mode && 100 > dbe_key_count (dfe->_.table.ot->ot_table->tb_primary_key))
    return 0; /* temp patch to avoid hash joins of lookups breaking colocation in tpch */
  ref_arity = dfe_arity_with_supers (dfe->dfe_prev);
  if (!hash_join_enable || (mode && OPT_HASH != mode))
    return 0;
  if (DFE_TABLE != dfe->dfe_type || dfe_ot (dfe)->ot_is_proc_view)
    return 0;
  DO_SET (df_elt_t *, pred, &preds)
    {
      if (pred->dfe_type == DFE_TEXT_PRED)
	return 0;
      if (!pred->dfe_tables)
	t_set_push (&org_preds, (void*)pred);
      else if (!pred->dfe_tables->next
	       /*&& remote != RHJ_LOCAL*/)
	{
	  /* a remote hash temp is never shared hence can have max preds at the filling */
	  t_set_push (&org_preds, (void*)pred);
	}
      else if (DFE_BOP_PRED == pred->dfe_type
	  && BOP_EQ == pred->_.bin.op)
	{
	  df_elt_t * left = pred->_.bin.left;
	  df_elt_t * right = pred->_.bin.right;
	  if (dfe_is_tb_only (left, ot)
	      && !dk_set_member (right->dfe_tables, (void*) ot))
	    {
	      if (right->dfe_tables)
		has_non_inv_key = 1;
	      t_set_push (&hash_keys, (void*) left);
	      t_set_push (&hash_refs, (void*) right);
	      sqt_types_set (&(left->dfe_sqt), &(right->dfe_sqt));
	      hash_pred_locus_refs = t_set_union (pred->dfe_remote_locus_refs, hash_pred_locus_refs);
	    }
	  else if (dfe_is_tb_only (right, ot)
	      && !dk_set_member (left->dfe_tables, (void*) ot))
	    {
	      if (left->dfe_tables)
		has_non_inv_key = 1;
	      t_set_push (&hash_keys, (void*) right);
	      t_set_push (&hash_refs, (void*) left);
	      sqt_types_set (&(left->dfe_sqt), &(right->dfe_sqt));
	      hash_pred_locus_refs = t_set_union (pred->dfe_remote_locus_refs, hash_pred_locus_refs);
	    }
	  else
	    t_set_push (&post_preds, (void*) pred);
	}
      else
	t_set_push (&post_preds, (void*) pred);
    }
  END_DO_SET();
  if (!hash_keys || !has_non_inv_key)
    return 0;


  fill_dfe = (df_elt_t *) t_box_copy ((caddr_t) dfe);
  fill_dfe->_.table.inx_op = NULL;
  fill_dfe->_.table.hash_role = HR_FILL;
  sqlo_best_hash_filler (so, fill_dfe, remote, &org_preds, &post_preds, &fill_unit, &fill_arity, &ov);
  if (!mode)
    {
      if (super_ot && ST_P (super_ot->ot_dt, SELECT_STMT) &&
	   !sqlo_is_postprocess (so, dfe->dfe_super, dfe))
	{ /*GK: TODO: make a better model to account for TOP */
	  ST *top_exp = SEL_TOP (super_ot->ot_dt);
	  ptrlong top_cnt = sqlo_select_top_cnt (so, top_exp);
	  if (top_cnt)
	    {
	      if (dfe->dfe_arity > 1)
		{
		  ref_arity = top_cnt;
		}
	      else if (dfe->dfe_arity < 1)
		{
		  ref_arity = top_cnt / dfe->dfe_arity;
		}
	    }
	}
      if (ref_arity < 1)
	return 0;
      if (dfe->dfe_unit * ref_arity < fill_unit + ref_arity * HASH_LOOKUP_COST + ref_arity * HASH_ROW_COST * MAX (0, dfe->dfe_arity -1))
	{
	  /* hash us not better */
	  return 0;
	}
    }
  if (RHJ_REMOTE == remote)
    {
      if (!sqlo_remote_hash_filler (so, fill_dfe, dfe))
	return 0;
      /* one more time to get the predicates' locus right */
      sqlo_tb_col_preds (so, fill_dfe, org_preds, NULL);
      dfe->_.table.single_locus = 1;
    }
  dfe->_.table.inx_op = NULL; /* if hash is better, no inx op */
  dfe->_.table.hash_role = HR_REF;
  dfe->_.table.hash_filler = fill_dfe;
  dfe->dfe_unit = HASH_LOOKUP_COST + HASH_ROW_COST * MAX (0, dfe->dfe_arity - 1);
  fill_dfe->dfe_unit = fill_unit;
  {
    int old_mode = so->so_place_code_forr_cond;
    s_node_t *iter;
    df_elt_t * old_pt = so->so_gen_pt;
    df_elt_t * fill_container = dfe_container (so, DFE_PRED_BODY, dfe);
    so->so_gen_pt = fill_container->_.sub.first;
    so->so_place_code_forr_cond = 1;
    DO_SET_WRITABLE (df_elt_t *, h_key, iter, &hash_keys)
      {
	/* expression hash temp keys must be copied.  The same can be placed elsewhere. Unplacing an exp placed in many places is a consistency problem */
	if (DFE_COLUMN != h_key->dfe_type && DFE_CONST != h_key->dfe_type)
	  h_key = sqlo_layout_copy (so, h_key, fill_container);
	iter->data = (void*) h_key;
	sqlo_place_exp (so, fill_container, h_key);
      }
    END_DO_SET();
    so->so_gen_pt = old_pt;
    so->so_place_code_forr_cond = old_mode;
    fill_dfe->_.table.hash_filler_after_code = df_body_to_array (fill_container);
  }
  fill_dfe->_.table.hash_keys = hash_keys;
  dfe->_.table.hash_refs = hash_refs;
  dfe->dfe_remote_locus_refs = hash_pred_locus_refs;/* Bug 1500 */
  dfe->_.table.join_test = sqlo_and_list_body (so, LOC_LOCAL, dfe, post_preds);
  *score_ret = sqlo_score (super_ot->ot_work_dfe, super_ot->ot_work_dfe->_.sub.in_arity);
  if (!dfe->_.table.is_unique)
    dfe->_.table.is_oby_order = 0;
  if (dfe->_.table.ot->ot_is_outer)
    sqlo_outer_hash (so, dfe);
  return 1;
}


void
sqlo_strip_in_join (ST* tree, caddr_t joined_table_prefix, caddr_t * joined_col_ret, ST** subq_col_ret)
{
  int inx;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    return;
  if (ST_P (tree, BOP_EQ)
      && ST_COLUMN (tree->_.bin_exp.left, COL_DOTTED) && ST_COLUMN (tree->_.bin_exp.right, COL_DOTTED)
      && tree->_.bin_exp.left->_.col_ref.prefix && tree->_.bin_exp.right->_.col_ref.prefix)
    {
      if (0 == strcmp (tree->_.bin_exp.left->_.col_ref.prefix, joined_table_prefix))
	{
	  if (*joined_col_ret)
	    {
	      *joined_col_ret= (caddr_t) -1;
	      return;
	    }
	  *joined_col_ret = tree->_.bin_exp.left->_.col_ref.name;
	  *subq_col_ret = tree->_.bin_exp.right;
	  tree->_.bin_exp.left = (ST*) t_box_num (1);
	  tree->_.bin_exp.right = (ST*) t_box_num (1);
	}
      else if (0 == strcmp (tree->_.bin_exp.right->_.col_ref.prefix, joined_table_prefix))
	{
	  if (*joined_col_ret)
	    {
	      *joined_col_ret= (caddr_t) -1;
	      return;
	    }
	  *joined_col_ret = tree->_.bin_exp.right->_.col_ref.name;
	  *subq_col_ret = tree->_.bin_exp.left;
	  tree->_.bin_exp.left = (ST*) t_box_num (1);
	  tree->_.bin_exp.right = (ST*) t_box_num (1);
	}
    }
  DO_BOX (ST *, sub, inx, tree)
    {
      sqlo_strip_in_join (sub, joined_table_prefix, joined_col_ret, subq_col_ret);
    }
  END_DO_BOX;
}


int
sqlo_all_refs_stripped (ST* tree, caddr_t joined_table_prefix)
{
  int inx;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    return 1;
  if (ST_COLUMN (tree, COL_DOTTED))
    return (tree->_.col_ref.prefix ? 0 != strcmp (tree->_.col_ref.prefix, joined_table_prefix) : 1);
  DO_BOX (ST *, sub, inx, tree)
    {
      if (!sqlo_all_refs_stripped (sub, joined_table_prefix))
	return 0;
    }
  END_DO_BOX;
  return 1;
}


void
sqlo_try_in_loop (sqlo_t *so, op_table_t * ot, df_elt_t * tb_dfe, df_elt_t ** subq_to_unplace, float * prev_score)
{
  int flag = (int)(ptrlong) sqlo_opt_value (ot->ot_opts, OPT_SUBQ_LOOP);
  if (SUBQ_NO_LOOP == flag)
    return;
  if (sqlo_max_mp_size > 0 && (THR_TMP_POOL)->mp_bytes > (sqlo_max_mp_size / 3 * 2))
    return;
  if (DFE_TABLE != tb_dfe->dfe_type
      || IS_BOX_POINTER (tb_dfe->dfe_super->dfe_locus))
    return; /* if not a table or a table in a pss through dt.  For pass through ,let the remote decide */
  DO_SET (df_elt_t *, pred, &tb_dfe->_.table.all_preds)
    {
      if (DFE_EXISTS == pred->dfe_type
	  && 1 == dk_set_length (pred->dfe_tables ) && tb_dfe->_.table.ot == (op_table_t *)pred->dfe_tables->data
	  && (pred->dfe_locus != tb_dfe->dfe_locus || (LOC_LOCAL == tb_dfe->dfe_locus && LOC_LOCAL == pred->dfe_locus ))
	  && SUBQ_NO_LOOP != (int)(ptrlong) sqlo_opt_value (pred->_.sub.ot->ot_opts, OPT_SUBQ_LOOP))
	{
	  /* existence depending on this table alone.  Now what col is the joined col? */
	  caddr_t joined_col_name = NULL;
	  ST * subq_out_col = NULL;
	  ST * copy = (ST*) t_box_copy_tree ((caddr_t) pred->dfe_tree);
	  sqlo_strip_in_join (copy, tb_dfe->_.table.ot->ot_new_prefix, &joined_col_name, &subq_out_col);
	  if (joined_col_name && (caddr_t)-1 != joined_col_name
	      && sqlo_all_refs_stripped (copy, tb_dfe->_.table.ot->ot_new_prefix))
	    {
	      df_elt_t * subq_dfe, * subq_join;
	      caddr_t subq_prefix;
	      float in_loop_score;
	      dk_set_t old_ot_preds;
	      /* we try making the existence into an outer loop */
	      copy->_.select_stmt.selection =
		t_list (1, t_list (5, BOP_AS, t_box_copy_tree ((caddr_t) subq_out_col),
				   NULL, subq_out_col->_.col_ref.name, NULL));
	      if (!copy->_.select_stmt.table_exp->_.table_exp.group_by)
		{
		  /* if the looped subq has a group by, the distinct is implicit, otherwise turn it on */
		  if (IS_BOX_POINTER (copy->_.select_stmt.top))
		    copy->_.select_stmt.top->_.top.all_distinct = 1;
		  else
		    copy->_.select_stmt.top = (ST*)(ptrlong)1; /*distinct */
		}
	      sqlo_scope (so, &copy);
	      subq_dfe = sqlo_df (so, copy);
	      subq_prefix = subq_dfe->_.sub.ot->ot_new_prefix;
	      so->so_gen_pt = tb_dfe->dfe_prev;
	      sqlo_dt_unplace (so, tb_dfe);
	      subq_dfe->_.sub.ot->ot_dfe = subq_dfe;
	      sqlo_place_table (so, subq_dfe);
	      /* remove the subq pred and put the join equality there */
	      old_ot_preds = t_set_copy (ot->ot_preds);
	      t_set_delete (&ot->ot_preds, (void*) pred);
	      subq_join = sqlo_df (so, (ST*) t_list (5, BOP_EQ,
						     t_list (3, COL_DOTTED, subq_prefix, subq_out_col->_.col_ref.name),
						     t_list (3, COL_DOTTED, tb_dfe->_.table.ot->ot_new_prefix, joined_col_name),
						     NULL, NULL));
	      t_set_push (&ot->ot_preds, (void*) subq_join);
	      sqlo_place_table (so, tb_dfe);
	      in_loop_score = sqlo_score (ot->ot_work_dfe, ot->ot_work_dfe->_.sub.in_arity);
	      if (in_loop_score > *prev_score && SUBQ_LOOP != flag)
		{
		  so->so_gen_pt = subq_dfe->dfe_prev;
		  sqlo_dt_unplace (so, tb_dfe);
		  sqlo_dt_unplace (so, subq_dfe);
		  ot->ot_preds = old_ot_preds;
		  sqlo_place_table (so, tb_dfe); /*put it back */
		  sqlo_try_hash (so, tb_dfe, ot, prev_score);
		  return;
		}
	      /* the opt choice is made. */
	      *prev_score = in_loop_score;
	      /* for the unplacing, put the org exists pred in all_preds so it gets  unplaced for future use in other scenarios */
	      t_set_push (&tb_dfe->_.table.all_preds, (void*) pred);
	      pred->dfe_is_placed = DFE_PLACED;
	      ot->ot_preds = old_ot_preds;
	      *subq_to_unplace = subq_dfe;
	      return;
	    }
	}
    }
  END_DO_SET();
}



void
sqlo_dfe_array_unplace (sqlo_t * so, df_elt_t ** arr)
{
  int inx;
  DO_BOX (df_elt_t *, dfe, inx, arr)
    {
      sqlo_dfe_unplace (so, dfe);
    }
  END_DO_BOX;
}


void
sqlo_locus_dfe_unplace (df_elt_t * dfe)
{
  DO_SET (locus_result_t *, lr, &dfe->dfe_remote_locus_refs)
    {
      locus_t * src = lr->lr_locus;
      if (lr->lr_requiring == dfe ||
	  (lr->lr_requiring->dfe_type == DFE_TABLE &&
	   lr->lr_requiring->_.table.hash_filler == dfe))
	t_set_delete (&src->loc_results, (void*) lr);
    }
  END_DO_SET ();
  dfe->dfe_remote_locus_refs = NULL;
}


void
dfe_unplace_in_middle (df_elt_t * dfe)
{
  df_elt_t * super = dfe->dfe_super;
  if (DFE_DT != super->dfe_type)
    GPF_T1 ("non-dt super for a hash filler");
  L2_DELETE (super->_.sub.first, super->_.sub.last, dfe, dfe_);
}


void
sqlo_inx_op_unplace  (sqlo_t * so, df_inx_op_t * dio)
{
  /* unplace the tables that are ni the inx op, except the head table which refers to the inx_op.  */
  if (dio->dio_table && dio->dio_table->_.table.inx_op)
    return;
  else if (dio->dio_table)
    {
      sqlo_dfe_unplace (so, dio->dio_table);
    }
  else if (dio->dio_terms)
    {
      DO_SET (df_inx_op_t *, term, & dio->dio_terms)
	{
	  sqlo_inx_op_unplace  (so, term);
	}
      END_DO_SET();
    }
}


void
sqlo_dfe_unplace (sqlo_t * so, df_elt_t * dfe)
{
  if (!IS_BOX_POINTER (dfe))
    return;

  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (dfe))
    {
      int inx;
      df_elt_t ** arr = (df_elt_t **) dfe;
      DO_BOX (df_elt_t *, dfe, inx, arr)
	{
	  sqlo_dfe_unplace (so, dfe);
	}
      END_DO_BOX;
      return;
    }
#ifdef NEVERNDEBUG
  if (!so->so_dfe_unplace_pass && dfe->dfe_tree)
    {
      df_elt_t *orig_dfe = sqlo_df_elt (so, dfe->dfe_tree);
      if (orig_dfe != dfe)
	SQL_GPF_T1 (so->so_sc->sc_cc, "dfe different");
    }
#endif
  dfe->dfe_is_placed = 0;
  sqlo_locus_dfe_unplace (dfe);
  if (dfe->dfe_type != DFE_TABLE || !dfe->_.table.is_leaf)
    {
      /* when unplacing a local leaf table, do not reset,m this just unlinks it */
      dfe->dfe_locus = NULL;
      dfe->dfe_unit = 0;
      dfe->dfe_unit_includes_vdb = 0;
    }
  switch (dfe->dfe_type)
    {
    case DFE_DT:
    case DFE_VALUE_SUBQ:
    case DFE_PRED_BODY:
      if (dfe->_.sub.ot)
	dfe->_.sub.ot->ot_locus = NULL;
      dfe->_.sub.trans = NULL;
      if (dfe->_.sub.first && dfe->_.sub.first->dfe_next)
	sqlo_dt_unplace (so, dfe->_.sub.first->dfe_next);
      dfe->_.sub.dt_out = NULL;
      DO_SET (df_elt_t *, pred, &dfe->_.sub.dt_preds)
	{
	  sqlo_dfe_unplace (so, pred);
	}
      END_DO_SET();
      if (dfe->_.sub.generated_dfe)
	{
#ifndef NDEBUG
	  int old_unplace_it = so->so_dfe_unplace_pass;
	  so->so_dfe_unplace_pass = 1;
#endif
	  sqlo_dfe_unplace (so, dfe->_.sub.generated_dfe);
#ifndef NDEBUG
	  so->so_dfe_unplace_pass = old_unplace_it;
#endif
	}
      dfe->_.sub.generated_dfe = NULL;
      if (dfe->_.sub.invariant_test)
	{
	  sqlo_dfe_unplace (so, (df_elt_t *) dfe->_.sub.invariant_test);
	}
      dfe->_.sub.invariant_test = NULL;
      break;
    case DFE_QEXP:
      {
	int inx;
	DO_BOX  (df_elt_t *, term, inx, dfe->_.qexp.terms)
	  {
	    sqlo_dfe_unplace (so, term);
	  }
	END_DO_BOX;
	break;
      }
    case DFE_TABLE:
      {
	op_table_t * ot = dfe->_.table.ot;
	if (dfe->_.table.is_leaf)
	  break;
	ot->ot_locus = NULL;
	DO_SET (df_elt_t *, pred, &dfe->_.table.all_preds)
	  {
	    sqlo_dfe_unplace (so, pred);
	  }
	END_DO_SET();
	if (dfe->_.table.hash_filler)
	  {
	    sqlo_dfe_unplace (so, dfe->_.table.hash_filler);
	  }
	DO_SET (df_elt_t *, key, &dfe->_.table.hash_keys)
	  {
	    sqlo_dfe_unplace (so, key);
	  }
	END_DO_SET();
	if (dfe->_.table.text_pred)
	  {
	    sqlo_dfe_unplace (so, (df_elt_t *) dfe->_.table.text_pred);
	  }
	if (dfe->_.table.xpath_pred)
	  {
	    sqlo_dfe_unplace (so, (df_elt_t *) dfe->_.table.xpath_pred);
	  }
	sqlo_dfe_unplace (so, (df_elt_t *)dfe->_.table.join_test);
	sqlo_dfe_unplace (so, (df_elt_t *)dfe->_.table.after_join_test);
	sqlo_dfe_unplace (so, (df_elt_t *)dfe->_.table.vdb_join_test);
	if (dfe->_.table.inx_op)
	  sqlo_inx_op_unplace (so, dfe->_.table.inx_op);
	memset (&dfe->_, 0, sizeof (dfe->_.table));
	dfe->_.table.ot = ot;
	break;
      }
    case DFE_ORDER:
    case DFE_GROUP:
      {
	ptrlong top_cnt = dfe->_.setp.top_cnt;
	ST ** specs = dfe->_.setp.specs;
	/*sqlo_dfe_unplace (so, (df_elt_t *) dfe->_.setp.after_test);*/
	DO_SET (df_elt_t *, pred, &dfe->_.setp.having_preds)
	  {
	    sqlo_dfe_unplace (so, pred);
	  }
	END_DO_SET ();
	memset (&dfe->_, 0, sizeof (dfe->_.setp));
	dfe->_.setp.specs = specs;
	dfe->_.setp.top_cnt = top_cnt;
	break;
      }
    case DFE_TEXT_PRED:
      {
	DO_SET (df_elt_t *, pred, &dfe->_.text.after_preds)
	  {
	    sqlo_dfe_unplace (so, pred);
	  }
	END_DO_SET();
	dfe->_.text.after_test = NULL;
	dfe->_.text.after_preds = NULL;
	break;
      }

    default:
      break;
    }
#ifdef L2_DEBUG
  dfe->dfe_next = NULL;
  dfe->dfe_prev = NULL;
/* Note matching '#ifndef L2_DEBUG' in sqlo_dt_unplace */
#endif
}

void
sqlo_dt_unplace (sqlo_t * so, df_elt_t * start_dfe)
{
  df_elt_t * dfe, * next = NULL;
  L2_ASSERT_PROPER_ENDS(start_dfe->dfe_super->_.sub.first, start_dfe->dfe_super->_.sub.last, dfe_)
  L2_ASSERT_CONNECTION(start_dfe->dfe_super->_.sub.first, start_dfe, dfe_)
  L2_ASSERT_CONNECTION(start_dfe, start_dfe->dfe_super->_.sub.last, dfe_)
#ifndef L2_DEBUG
  start_dfe->dfe_prev->dfe_next = NULL;
  start_dfe->dfe_super->_.sub.last = start_dfe->dfe_prev;
/* Note '#ifdef L2_DEBUG' in sqlo_dfe_unplace */
#endif
  for (dfe = start_dfe; dfe; dfe = next)
    {
      df_elt_t * super = dfe->dfe_super;
      next = dfe->dfe_next;
      if (DFE_DT != super->dfe_type && DFE_EXISTS != super->dfe_type
	  && DFE_VALUE_SUBQ != super->dfe_type)
	SQL_GPF_T1 (so->so_sc->sc_cc, "unplace dfe without dt as super.   As work around, can try to eliminate common subexpressions between the query in general and control expressions like coalesce or case.");
      L2_DELETE (super->_.sub.first, super->_.sub.last, dfe, dfe_);
      sqlo_dfe_unplace (so, dfe);
    }
}

#define dfe_is_outer(dfe) (DFE_TABLE == dfe->dfe_type ? dfe->_.table.ot->ot_is_outer : dfe->_.sub.ot->ot_is_outer)
#define dfe_is_join(dfe) (DFE_TABLE == dfe->dfe_type ? \
    (dfe->_.table.ot->ot_is_outer || dfe->_.table.ot->ot_join_cond) : \
    (dfe->_.sub.ot->ot_is_outer || dfe->_.sub.ot->ot_join_cond))


int
dfe_suitable_for_next (df_elt_t * dfe, df_elt_t * must_be_next)
{
  if (must_be_next)
    return (dfe == must_be_next);
  return ((DFE_TABLE == dfe->dfe_type || DFE_DT == dfe->dfe_type)
	  && !dfe->dfe_is_placed
	  && !dfe_is_join (dfe));
}


df_elt_t *
sqlo_next_joined (sqlo_t * so, df_elt_t * dt_dfe)
{
  /* if there is an outer that must come at this point, return it */
  op_table_t * ot = dt_dfe->_.sub.ot;
  df_elt_t * last = NULL, * placed;
  dk_set_t from;
  for (placed = dt_dfe->_.sub.first; placed; placed = placed->dfe_next)
    {
      if (DFE_TABLE == placed->dfe_type || DFE_DT == placed->dfe_type)
	last = placed;
    }
  for (from = ot->ot_from_dfes; from && from->next; from = from->next)
    {
      if ((df_elt_t *) from->data == last)
	{
	  df_elt_t * next_from = (df_elt_t *) from->next->data;
	  int next_outer = dfe_is_join (next_from);
	  remote_table_t * rt = DFE_TABLE == next_from->dfe_type ? find_remote_table (next_from->_.table.ot->ot_table->tb_name, 0) : NULL ;
	  if (!next_from->dfe_is_placed && next_outer && rt)
	    {
	      df_elt_t * preds = sqlo_df_elt (so, next_from->_.table.ot->ot_join_cond);
	      char old = next_from->dfe_is_placed;
	      next_from->dfe_is_placed = DFE_PLACED;
	      if (preds && dfe_reqd_placed (preds))
		{
		  next_from->dfe_is_placed = old;
		  return next_from;
		}
	      next_from->dfe_is_placed = old;
	    }
	}
    }
  return NULL;
}


#ifdef NOT_CURRENTLY_USED
static void
sqlo_dt_imp_pred_list_cols (sqlo_t *so, df_elt_t *tb_dfe, df_elt_t *dfe)
{
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (dfe))
    {
      int inx;
      df_elt_t ** dfe_arr = (df_elt_t **) dfe;
      DO_BOX (df_elt_t *, elt, inx, dfe_arr)
	{
	  if (IS_BOX_POINTER (elt))
	    sqlo_dt_imp_pred_list_cols (so, tb_dfe, elt);
	}
      END_DO_BOX;
    }
  else if (IS_BOX_POINTER (dfe))
    {
      sqlo_dt_imp_pred_cols (so, tb_dfe, dfe->dfe_tree);
    }
}
#endif


void
sqlo_set_select_mode (sqlo_t * so, op_table_t * ot, df_elt_t * sel_dfe, ST * top_exp)
{
  so->so_place_code_forr_cond = 0;
  if (IS_BOX_POINTER (top_exp) && top_exp->_.top.skip_exp)
    {
      if (ot->ot_group_dfe || ot->ot_fun_refs)
	return;
      if (ot->ot_oby_dfe && ot->ot_oby_dfe->dfe_is_placed)
	return;
      so->so_place_code_forr_cond = 1;
      return;
    }
  if (1 == cl_run_local_only)
    return;
  if (ST_P (sel_dfe->dfe_tree, CALL_STMT)
      && DV_STRINGP (sel_dfe->dfe_tree->_.call.name)
      && cu_func (sel_dfe->dfe_tree->_.call.name, 0))
    so->so_place_code_forr_cond = 1;
}


int sqlo_max_layouts = 1000;
int32 sqlo_max_mp_size = 10485760;



float
dfe_join_score (sqlo_t * so, op_table_t * ot,  df_elt_t *tb_dfe)
{
  /* every non-join pred of tb_dfe counts for 2, ever join pred of tb_dfe with a placed table counts for 5,
  * equality added 2 points. A join pred to a non-placed table is 0. */
  float score = 0;
  tb_dfe->dfe_is_placed = 1; /* to fool dfe_reqd_placed*/
  DO_SET (df_elt_t *, pred, &ot->ot_preds)
    {
      if (dk_set_length (pred->dfe_tables) == 1
	  && tb_dfe->_.table.ot == (op_table_t *) pred->dfe_tables->data)
	{
	  score += 2;
	  if (DFE_TEXT_PRED == pred->dfe_type)
	    score += 5;
	}
      else if (dfe_reqd_placed (pred) && dk_set_member (pred->dfe_tables, (void*) tb_dfe->_.table.ot))
	score += 5;
      else
	goto next;
      if (DFE_BOP_PRED == pred->dfe_type && pred->_.bin.op == BOP_EQ)
	score += 2;
    next: ;
    }
  END_DO_SET();
  tb_dfe->dfe_is_placed = 0;
  return score;
}


int
dfe_list_reqd_placed (dk_set_t list)
{
  DO_SET (df_elt_t *, dfe, &list)
    {
      if (!dfe_reqd_placed (dfe))
	return 0;
    }
  END_DO_SET();
  return 1;
}

int
sqlo_dfe_is_leaf (sqlo_t * so, op_table_t * ot, df_elt_t * dfe)
{
  /* depends on a single placed and no unplaced depends on this.  Also no existences cause looping exists will interfere with this. */
  int old = dfe->dfe_is_placed;
  dfe->dfe_is_placed = DFE_PLACED;
  DO_SET (df_elt_t *, pred, &ot->ot_preds)
    {
      if (DFE_EXISTS == pred->dfe_type)
	{
	  dfe->dfe_is_placed = old;
	  return 0;
	}
      if (dk_set_member (pred->dfe_tables, (void*)dfe->_.table.ot))
	{
	  if (!dfe_reqd_placed (pred))
	    {
	      dfe->dfe_is_placed = old;
	      return 0;
	    }
	}
    }
  END_DO_SET();
  DO_SET (df_elt_t *, join, &dfe->_.table.ot->ot_join_preds)
    {
      if (DFE_EXISTS == join->dfe_type)
	{
	  dfe->dfe_is_placed = old;
	  return 0;
	}
    }
  END_DO_SET();
  if (!dfe_list_reqd_placed (dfe->_.table.ot->ot_join_preds))
    {
      dfe->dfe_is_placed = old;
      return 0;
    }
  DO_SET (df_elt_t *, other, &ot->ot_from_dfes)
    {
      dk_set_t join_preds = other->_.table.ot->ot_join_preds;
      if (other == dfe || !join_preds || other->dfe_is_placed)
	continue;
      DO_SET (df_elt_t *, join, &join_preds)
	{
	  if (dk_set_member (join->dfe_tables, (void*) dfe->_.table.ot))
	    goto join_depends;
	}
      END_DO_SET();
      continue; /* the other ot does not depend on the dfe being tested */
    join_depends:
      if (!dfe_list_reqd_placed (join_preds))
	{
	  dfe->dfe_is_placed = old;
	  return 0;
	}
    }
  END_DO_SET();

  dfe->dfe_is_placed = old;
  return 1;
}


void
sqlo_new_leaves (sqlo_t * so, op_table_t * ot, dk_set_t * all_leaves, dk_set_t * new_leaves)
{
  DO_SET (df_elt_t *, dfe, &ot->ot_from_dfes)
    {
      if (!dfe->dfe_is_placed && DFE_TABLE == dfe->dfe_type
	  && sqlo_dfe_is_leaf (so, ot, dfe)
	  && !dfe->_.table.ot->ot_table->tb_remote_ds)
	{
	  if (!dfe->_.table.is_leaf)
	    t_set_push (new_leaves, (void*)dfe);
	  t_set_push (all_leaves, (void*) dfe);
	}
    }
  END_DO_SET();
}


void
sqlo_restore_leaves (sqlo_t * so, dk_set_t new_leaves)
{
  /* in the process of unplacing, the leaves stop being leaves */
  DO_SET (df_elt_t *, leaf, &new_leaves)
    {
      leaf->_.table.is_leaf = 0;
      sqlo_dfe_unplace (so, leaf);
    }
  END_DO_SET();
}

int32
df_pred_score_key (dk_set_t first)
{
  df_elt_t * dfe = (df_elt_t*)first->data;
  if (dfe->dfe_arity)
    return -3;
  return ((int32) dfe->dfe_unit);
}


int32
df_leaf_score_key (df_elt_t * dfe)
{
  return *((int32*) &dfe->dfe_arity);
}



void
sqlo_leaves  (sqlo_t * so, op_table_t * ot, dk_set_t * all_leaves, dk_set_t * new_leaves)
{
  dk_set_t res = NULL;
  df_elt_t ** arr;
  int inx;
  *all_leaves = NULL;
  *new_leaves = NULL;
  sqlo_new_leaves (so, ot, all_leaves, new_leaves);
  DO_SET (df_elt_t *, leaf, new_leaves)
    {
      if (!leaf->_.table.is_leaf)
	{
	  float this_score;
	  sqlo_place_table (so, leaf);
	  this_score = sqlo_score (ot->ot_work_dfe, ot->ot_work_dfe->_.sub.in_arity);
	  sqlo_try_hash (so, leaf, ot, &this_score);
	  leaf->_.table.is_leaf = 1;
	  so->so_gen_pt = leaf->dfe_prev;
	  sqlo_dt_unplace (so, leaf);
	}
    }
  END_DO_SET();
  arr = (df_elt_t **) dk_set_to_array (*all_leaves);
  buf_bsort ((buffer_desc_t**) arr, BOX_ELEMENTS (arr), (sort_key_func_t) df_leaf_score_key);
  res = NULL;
  DO_BOX (df_elt_t *, dfe, inx, arr)
    {
      t_set_push (&res, (void*) dfe);
    }
  END_DO_BOX;
  dk_free_box ((caddr_t) arr);
  *all_leaves = dk_set_nreverse (res);
}


int
sqlo_outer_placeable (sqlo_t * so, op_table_t * ot, df_elt_t * dfe)
{
  /* if the items needed to place join cond are in, the outer can go. */
  dk_set_t join_preds;
  int is_placed = 1, old = dfe->dfe_is_placed;
  int is_outer = DFE_TABLE == dfe->dfe_type ? dfe->_.table.ot->ot_is_outer
    : dfe->_.sub.ot->ot_is_outer;
  join_preds = DFE_TABLE == dfe->dfe_type ? dfe->_.table.ot->ot_join_preds
    : dfe->_.sub.ot->ot_join_preds;
  if (!is_outer && !join_preds)
    return 1;
  dfe->dfe_is_placed = DFE_PLACED;
  DO_SET (df_elt_t *, join, &join_preds)
    {
      is_placed = dfe_reqd_placed (join);
      if (!is_placed)
	break;
    }
  END_DO_SET();
  dfe->dfe_is_placed = old;
  return is_placed;
}


int
sqlo_trans_placeable (sqlo_t * so, op_table_t * ot, df_elt_t * dfe, int * any_trans)
{
  /* for a transitive dt, full eq on in or out is needed before placing */
  int flag = 0;
  dk_set_t join_preds, in_cols, out_cols;
  ST * trans;
  int old = dfe->dfe_is_placed;
  if (DFE_DT != dfe->dfe_type)
    return 1;
  trans = dfe->_.sub.ot->ot_trans;
  if (!trans)
    return 1;
  *any_trans = 1;
  join_preds = dfe->_.sub.ot->ot_join_preds;
  join_preds = dk_set_conc (t_set_copy (join_preds), so->so_this_dt->ot_preds);
  in_cols = sqlo_cols_by_pos (so, dfe, trans->_.trans.in);
  out_cols = sqlo_cols_by_pos (so, dfe, trans->_.trans.out);
  dfe->dfe_is_placed = DFE_PLACED;
  DO_SET (df_elt_t *, join, &join_preds)
    {
      if (join->dfe_is_placed || !dfe_reqd_placed (join))
	continue;
      sqlo_rm_if_eq (&in_cols, join);
      sqlo_rm_if_eq (&out_cols, join);
    }
  END_DO_SET();
  dfe->dfe_is_placed = old;
  if (!in_cols)
    flag |= TN_FWD;
  if (!out_cols)
    flag |= TN_FWD;
  return flag;
}


int enable_leaves = 1;

#define SQLO_BACKTRACK ((dk_set_t)-1)

dk_set_t
sqlo_layout_sort_tables (sqlo_t *so, op_table_t * ot, dk_set_t from_dfes, dk_set_t * new_leaves)
{
  int any_trans = 0;
  dk_set_t all_leaves = NULL;
  int inx;
  dk_set_t res = NULL;
  df_elt_t ** arr;
  if (ot->ot_fixed_order || IS_FOR_XML (sqlp_union_tree_right (ot->ot_dt)))
    {
      DO_SET (df_elt_t *, dfe, &ot->ot_from_dfes)
	{
	  if (!dfe->dfe_is_placed)
	    return t_cons ((void*)t_cons ((void*) dfe, NULL), NULL);
	}
      END_DO_SET();
    }
  if (!from_dfes)
    return NULL;
  if (!from_dfes->next)
    {
      if (!((df_elt_t*)(ot->ot_from_dfes->data))->dfe_is_placed)
	return t_cons (from_dfes, NULL);
      else
	return NULL;
    }
  if (enable_leaves && !ot->ot_oby_ots) /* no leaf trick if potential indexed oby */
    sqlo_leaves (so, ot, &all_leaves, new_leaves);
  DO_SET (df_elt_t *, tb_dfe, &from_dfes )
    {
      if (!tb_dfe->dfe_is_placed
	  && !dk_set_member (all_leaves, (void*)tb_dfe)
	  && sqlo_outer_placeable (so, ot, tb_dfe)
	  && sqlo_trans_placeable (so, ot, tb_dfe, &any_trans))
	{
	  tb_dfe->dfe_arity = 0;
	  tb_dfe->dfe_unit = dfe_join_score (so, ot, tb_dfe);
	  t_set_push (&res, (void*) t_cons (tb_dfe, NULL));
	}
    }
  END_DO_SET();
  if (all_leaves)
    t_set_push (&res, (void*) all_leaves);
  if (!res && any_trans)
    {
      if (!so->so_best)
	sqlc_new_error (so->so_sc->sc_cc, "37000", "TR...", "Query contains a transitive derived table but neither end of it is bound by equality to other columns or parameters");
      else
	return SQLO_BACKTRACK;
    }
  if (!res || !res->next)
    return res;
  arr = (df_elt_t **) dk_set_to_array (dk_set_nreverse (res)); /* reverse to preserve order among items of equal score, stable sort */
  buf_bsort ((buffer_desc_t**) arr, BOX_ELEMENTS (arr), (sort_key_func_t) df_pred_score_key);
  res = NULL;
  DO_BOX (dk_set_t, elt, inx, arr)
    {
      df_elt_t * dfe = (df_elt_t *)elt->data;
      dfe->dfe_unit = 0;
      t_set_push (&res, (void*) elt);
    }
  END_DO_BOX;
  dk_free_box ((caddr_t) arr);
  return ( res);
}


void
ot_print_unplaced (op_table_t * ot)
{
  DO_SET (df_elt_t*, dfe, &ot->ot_preds)
    {
      if (!dfe->dfe_is_placed)
	sqlo_dfe_print (dfe, 0);
    }
  END_DO_SET();
}





void
sqlo_untry (sqlo_t * so, df_elt_t * dfe, df_elt_t * in_loop_dfe)
{
  so->so_gen_pt = dfe->dfe_prev;
  sqlo_dt_unplace (so, dfe);
  if (in_loop_dfe)
    {
      so->so_gen_pt = in_loop_dfe->dfe_prev;
      sqlo_dt_unplace (so, in_loop_dfe);
    }
}

void
sqlo_try (sqlo_t * so, op_table_t * ot, dk_set_t dfes, df_elt_t ** in_loop_ret, float * score_ret)
{
  int score_set = 0;
  float this_score;
  DO_SET (df_elt_t *, dfe, &dfes)
    {
      sqlo_place_table (so, dfe);

      if (DFE_TABLE != dfe->dfe_type || !dfe->_.table.is_leaf)
	{
	  this_score = sqlo_score (ot->ot_work_dfe, ot->ot_work_dfe->_.sub.in_arity);
	  sqlo_try_hash (so, dfe, ot, &this_score);
	  if (!dfes->next)
	    sqlo_try_in_loop (so, ot, dfe, in_loop_ret, &this_score);
	  score_set = 1;
	}
    }
  END_DO_SET();
  if (!score_set)
    this_score = sqlo_score (ot->ot_work_dfe, ot->ot_work_dfe->_.sub.in_arity);
  *score_ret = this_score;
}


/* meters */
int32 sqlo_n_layout_steps;
int32 sqlo_n_full_layouts;
int32 sqlo_n_best_layouts;
int32 sqlo_compiler_exceeds_run_factor;

int
sqlo_no_more_time (sqlo_t * so, op_table_t * ot)
{
  /* every so often, see if the best plan's time is less than the time to compile so far. If so, no point in further scenarios */
  uint32 now;
  static int ctr;
  if (sqlo_compiler_exceeds_run_factor /*&& 0 == ++ctr % 2 */)
    {
      if (!so->so_best)
	return 0;
      now = get_msec_real_time ();
      if (!so->so_last_sample_time)
	so->so_last_sample_time = now;
      if (so->so_best_score * compiler_unit_msecs * ot->ot_work_dfe->_.sub.in_arity
	  < sqlo_compiler_exceeds_run_factor * (now - so->so_last_sample_time ))
	{
	  if (sqlo_print_debug_output)
	    {
	      sqlo_print (("Compilation time longer than query time after %ld layouts, elapsed %ld msec\n", (long)(ot->ot_layouts_tried), (long)(now - so->so_last_sample_time)));
	    }
	  return 1;
	}
    }
  return 0;
}


#define LAYOUT_ABORT \
{ \
  sqlo_untry (so, dfe, in_loop_dfe); \
    sqlo_restore_leaves (so, new_leaves); \
    return; \
}



void
sqlo_layout_1 (sqlo_t * so, op_table_t * ot, int is_top)
{
  /* take an ungenerated table and put it and its stuff into the pipeline */
  df_elt_t * must_be_next;
  dk_set_t sort_set = NULL, new_leaves = NULL;
  float this_score;
  int any_tried = 0;
  must_be_next = sqlo_next_joined (so, ot->ot_work_dfe);
  if (THR_IS_STACK_OVERFLOW (THREAD_CURRENT_THREAD, &any_tried, 8000))
    sqlc_error (so->so_sc->sc_cc, "42000", "Stack Overflow");
  if (DK_MEM_RESERVE)
    sqlc_error (so->so_sc->sc_cc, "42000", "Out of memory");
  SQLO_MP_SAMPLE;
  if (sqlo_max_mp_size > 0 && (THR_TMP_POOL)->mp_bytes > sqlo_max_mp_size)
    {
      if (so->so_best) /* log a error */
	{
	  log_error ("The memory pool size %d reached the limit %d bytes, using the last best score.",
	      (THR_TMP_POOL)->mp_bytes, sqlo_max_mp_size);
	  return;
	}
      else
	sqlc_error (so->so_sc->sc_cc, "42000",
	    "The memory pool size %d reached the limit %d bytes, try to increase the MaxMemPoolSize ini setting.",
	    (THR_TMP_POOL)->mp_bytes, sqlo_max_mp_size);
    }
  if (must_be_next)
    sort_set = t_cons ((void*)t_cons ((void*) must_be_next, NULL), NULL);
  else
    sort_set = sqlo_layout_sort_tables (so, ot, ot->ot_from_dfes, &new_leaves);
  if (SQLO_BACKTRACK == sort_set)
    return;
  DO_SET (dk_set_t, dfes, &sort_set)
    {
      df_elt_t * dfe = (df_elt_t*)dfes->data;
      df_elt_t * in_loop_dfe = NULL;
      any_tried = 1;
      sqlo_try (so, ot, dfes, &in_loop_dfe, &this_score);
      if (-1 == so->so_best_score || this_score < so->so_best_score)
	{
	  sqlo_layout_1 (so, ot, is_top);
	  if (ot->ot_layouts_tried == -1)
	    {
	      so->so_gen_pt = dfe->dfe_prev;
	      sqlo_dt_unplace (so, dfe);
	      return;
	    }
	}
      else
	{
	  if (ot->ot_layouts_tried >= 0)
	    {
	      ot->ot_layouts_tried += 1;
	      if ((sqlo_max_layouts && so->so_best && ot->ot_layouts_tried >= sqlo_max_layouts)
		  || sqlo_no_more_time (so, ot))
		{
		  if (sqlo_print_debug_output)
		    sqlo_print (("Max layouts (%d) exceeded. Taking the best so far\n", sqlo_max_layouts));
		  ot->ot_layouts_tried = -1;
		  LAYOUT_ABORT;
		}
	    }
	  if (sqlo_print_debug_output)
	    {
	      if (compiler_unit_msecs)
		sqlo_print (("best exceeded on %s, best = %7.2g\n",
			     ot->ot_new_prefix, so->so_best_score));
	      else
		sqlo_print (("best exceeded on %s, best = %7.2g (%g msec)\n",
			     ot->ot_new_prefix, so->so_best_score, so->so_best_score * compiler_unit_msecs));
	      sqlo_scenario_summary (ot->ot_work_dfe, this_score);
	    }
	}

      if (!ot->ot_is_top_ties && sqlo_try_oby_order (so, dfe))
	{
	  /* clear the previous guess' oby nodes and other garbage before eval */
	  if (ot->ot_layouts_tried == -2)
	    ot->ot_layouts_tried = MAX (0, sqlo_max_layouts - 1);
	  this_score = sqlo_score (ot->ot_work_dfe, ot->ot_work_dfe->_.sub.in_arity);
	  if (-1 == so->so_best_score || this_score < so->so_best_score)
	    {
	      sqlo_layout_1 (so, ot, is_top);
	      if (ot->ot_layouts_tried == -1)
		{
		  LAYOUT_ABORT;
		}
	    }
	  else
	    {
	      if (sqlo_print_debug_output)
		{
		  if (compiler_unit_msecs)
		    sqlo_print (("best exceeded on %s, best = %7.2g (%g msec)\n",
				 ot->ot_new_prefix, so->so_best_score, so->so_best_score * compiler_unit_msecs));
		  else
		    sqlo_print (("best exceeded on %s, best = %7.2g\n",
				 ot->ot_new_prefix, so->so_best_score));
		  sqlo_scenario_summary (ot->ot_work_dfe, this_score);
		}
	      ot->ot_layouts_tried += 1;
	      if ((sqlo_max_layouts && so->so_best && ot->ot_layouts_tried >= sqlo_max_layouts)
		  || sqlo_no_more_time (so, ot))
		{
		  if (sqlo_print_debug_output)
		    sqlo_print (("Max layouts (%d) exceeded. Taking the best so far\n", sqlo_max_layouts));
		  ot->ot_layouts_tried = -1;
		  LAYOUT_ABORT;
		}
	    }
	}
      else if (ot->ot_layouts_tried == -2)
	{
	  ot->ot_layouts_tried = -1;
	  if (sqlo_print_debug_output)
	    sqlo_print ((
			 "Max layouts (%d) exceeded and index ORDER BY not applicable.\n"
			 "Taking the best so far\n", sqlo_max_layouts));
	  LAYOUT_ABORT;
	}
      sqlo_untry (so, dfe, in_loop_dfe);
    }
  END_DO_SET ();
  if (!any_tried)
    {
      /* all tables in sequence, now groups and top select and what else */
      if (ST_P (ot->ot_dt, SELECT_STMT))
	{
	  sqlo_fun_ref_epilogue (so, ot);
	  if (is_top || SEL_IS_DISTINCT (ot->ot_dt) || sel_n_breakup (ot->ot_dt))
	    {
	      int inx;
	      ST *top_exp = !SEL_IS_TRANS (ot->ot_dt) ? SEL_TOP (ot->ot_dt) : NULL;
	      df_elt_t * select_super = SQLO_LAY_TOP == is_top ? so->so_vdb_top : ot->ot_work_dfe;
	      so->so_gen_pt = ot->ot_work_dfe->_.sub.last;
	      ot->ot_work_dfe->_.sub.dt_out = (df_elt_t **) t_box_copy ((caddr_t) ot->ot_dt->_.select_stmt.selection);
	      DO_BOX (ST *, exp, inx, ot->ot_dt->_.select_stmt.selection)
		{
		  df_elt_t * sel_dfe = sqlo_df (so, exp);
		  so->so_nth_select_col = inx;
		  ot->ot_work_dfe->_.sub.dt_out[inx] = sel_dfe;
		  if (IS_BOX_POINTER (ot->ot_work_dfe->dfe_locus) &&
		      sqlo_fits_in_locus (so, ot->ot_work_dfe->dfe_locus, sel_dfe))
		    {
		      sqlo_place_exp (so, ot->ot_work_dfe, sel_dfe);
		      dfe_loc_result (ot->ot_work_dfe->dfe_locus, select_super, sel_dfe);
		    }
		  else
		    {
		      int old_mode = so->so_place_code_forr_cond;
		      sqlo_set_select_mode (so, ot, sel_dfe, top_exp);
		      sqlo_place_exp (so, select_super, sel_dfe);
		      if (so->so_place_code_forr_cond)
			sqlo_post_oby_ref (so, ot->ot_work_dfe, sel_dfe, inx);
		      so->so_place_code_forr_cond = old_mode;
		    }
		}
	      END_DO_BOX;
	      if (NULL != top_exp)
		{
		  df_elt_t * top_dfe = sqlo_df (so, top_exp->_.top.exp);
		  if (IS_BOX_POINTER (ot->ot_work_dfe->dfe_locus) &&
		      sqlo_fits_in_locus (so, ot->ot_work_dfe->dfe_locus, top_dfe))
		    {
		      sqlo_place_exp (so, ot->ot_work_dfe, top_dfe);
		      dfe_loc_result (ot->ot_work_dfe->dfe_locus, select_super, top_dfe);
		    }
		  else
		    sqlo_place_exp (so, select_super, top_dfe);

		  top_dfe = sqlo_df (so, top_exp->_.top.skip_exp);
		  if (IS_BOX_POINTER (ot->ot_work_dfe->dfe_locus) &&
		      sqlo_fits_in_locus (so, ot->ot_work_dfe->dfe_locus, top_dfe))
		    {
		      sqlo_place_exp (so, ot->ot_work_dfe, top_dfe);
		      dfe_loc_result (ot->ot_work_dfe->dfe_locus, select_super, top_dfe);
		    }
		  else
		    sqlo_place_exp (so, select_super, top_dfe);
		}
	    }
	}
      /* GK: all the predicates should be placed by now */
      if (so->so_this_dt->ot_from_dfes)
	{
	  DO_SET (df_elt_t *, pred, &so->so_this_dt->ot_preds)
	    {
	      if (!pred->dfe_is_placed)
		SQL_GPF_T1 (so->so_sc->sc_cc, "Unplaced predicate in select layout");
	    }
	  END_DO_SET ();
	}

      sqlo_n_full_layouts++;
      this_score = sqlo_score (ot->ot_work_dfe, ot->ot_work_dfe->_.sub.in_arity);
      if (-1 == so->so_best_score ||  this_score < so->so_best_score)
	{
	  sqlo_n_best_layouts++;
	  if (sqlo_print_debug_output)
	    {
	      sqlo_print (("New best %s is:\n", ot->ot_new_prefix));
	      sqlo_scenario_summary (ot->ot_work_dfe, this_score);
	    }
	  so->so_best = sqlo_layout_copy (so, ot->ot_work_dfe, NULL);
	  so->so_best_score = this_score;
	}
      else
	{
	  if (sqlo_print_debug_output)
	    {
	      if (compiler_unit_msecs)
		sqlo_print (("best exceeded on %s, best = %f (%g msecs)\n",
		      ot->ot_new_prefix, so->so_best_score, so->so_best_score * compiler_unit_msecs));
	      else
		sqlo_print (("best exceeded on %s, best = %f\n", ot->ot_new_prefix, so->so_best_score));
	      sqlo_scenario_summary (ot->ot_work_dfe, this_score);
	    }
	}
      if (ST_P (ot->ot_dt, SELECT_STMT) && (is_top || SEL_IS_DISTINCT (ot->ot_dt)))
	{
	  if (SQLO_LAY_TOP == is_top)
	    sqlo_locus_dfe_unplace (so->so_vdb_top);
	  sqlo_locus_dfe_unplace (ot->ot_work_dfe);
	}
      ot->ot_layouts_tried += 1;
      if (sqlo_max_layouts && so->so_best && ot->ot_layouts_tried >= sqlo_max_layouts)
	{
	  if (ot->ot_oby_dfe && ot->ot_oby_dfe->dfe_is_placed == DFE_PLACED)
	    {
	      if (sqlo_print_debug_output)
		sqlo_print (("Max layouts (%d) exceeded, but there's a sorted ORDER BY. Will try index\n",
		      sqlo_max_layouts));
	      ot->ot_layouts_tried = -2;
	    }
	  else
	    {
	      if (sqlo_print_debug_output)
		sqlo_print (("Max layouts (%d) exceeded. Taking the best so far\n", sqlo_max_layouts));
	      ot->ot_layouts_tried = -1;
	      return;
	    }
	}
    }
  else
    sqlo_restore_leaves (so, new_leaves);
}


void
sqlo_restore_loci (df_elt_t * dt_dfe)
{
  DO_SET (locus_t *, copy, &dt_dfe->locus_content)
    {
      copy->loc_copy_of->loc_results = copy->loc_results;
    }
  END_DO_SET();
}

df_elt_t *
sqlo_layout (sqlo_t * so, op_table_t * ot, int is_top, df_elt_t * super)
{
  df_elt_t * ret;
  df_elt_t * so_dfe = so->so_dfe;
  op_table_t * prev_dt = so->so_this_dt;
  float sc1= so->so_best_score;
  df_elt_t * containing_dt = super;
  int is_in_pass_through = 0;
  df_elt_t * best1 = so->so_best;
  df_elt_t * pt = so->so_gen_pt;
  so->so_this_dt = ot;
  so->so_gen_pt = ot->ot_work_dfe->_.sub.first;
  ot->ot_work_dfe->_.sub.ot = ot;
  while (containing_dt)
    {
      if (DFE_DT == containing_dt->dfe_type)
	{
	  if (LOC_LOCAL != containing_dt->dfe_locus)
	    is_in_pass_through = 1;
	  break;
	}
      containing_dt = containing_dt->dfe_super;
    }
  if (SQLO_LAY_EXISTS == is_top
      && !is_in_pass_through)
    {
      /* we do a subq and the whole top query is not pass through.
       * if super is remote and the subq fits in same loc, pass through into the same loc as its super
       * if the super is local or another vdb place, then do not apply pass through to the subq so as to allow virt side hash join etc. */
      locus_t * suggested_locus = sqlo_dt_locus (so, ot, super ? super->dfe_locus : LOC_LOCAL);
      if (suggested_locus == super->dfe_locus && LOC_LOCAL != super->dfe_locus)
	ot->ot_work_dfe->dfe_locus = suggested_locus;
      else
	ot->ot_work_dfe->dfe_locus = LOC_LOCAL; /* if exists subq, do not dopass through so as to be able to use hash join locally etc. */
    }
  else
    ot->ot_work_dfe->dfe_locus = sqlo_dt_locus (so, ot, super ? super->dfe_locus : LOC_LOCAL);
  ot->ot_eq_hash = NULL;
  sqlo_init_eqs (so, ot);
  if (SQLO_LAY_TOP == is_top)
    so->so_vdb_top = dfe_container (so, DFE_DT, NULL);
  so->so_best_score = -1;
  so->so_best = NULL;
  ot->ot_is_contradiction = 0;
  ot->ot_invariant_preds = NULL;
  ot->ot_layouts_tried = 0;
  sqlo_layout_1 (so, ot, is_top);

  ret = so->so_best;
  ret->_.sub.is_contradiction = ot->ot_is_contradiction;
  ret->_.sub.is_complete = 1;
  dfe_top_discount (ret, &ret->dfe_unit, &ret->dfe_arity); /* if top or value/exists subq, not all rows are produced. Consider this only after layout is done */
  if (!ret->dfe_tree)
    ret->dfe_tree = ot->ot_dt;
  ret->dfe_hash = sql_tree_hash ((char*)&ret->dfe_tree);
  ret->dfe_unit = so->so_best_score;
  so->so_this_dt = prev_dt;
  so->so_best = best1;
  so->so_best_score = sc1;
  so->so_gen_pt = pt;
  so->so_dfe = so_dfe;
  sqlo_restore_loci (ret);
  return ret;
}


int
dfe_body_len (df_elt_t * body)
{
  int ctr = 0;
  df_elt_t * elt = body->_.sub.first;
  while (elt)
    {
      ctr++;
      elt = elt->dfe_next;
    }
  return ctr;
}


void
dfe_save_locus (sqlo_t * so, locus_t * loc)
{
  DO_SET (locus_t *, saved_loc, &so->so_copy_root->locus_content)
    {
      if (saved_loc->loc_name == loc->loc_name)
	return;
    }
  END_DO_SET();
  {
    locus_t * copy_loc = (locus_t*) t_box_copy ((caddr_t) loc);
    copy_loc->loc_copy_of = loc;
    copy_loc->loc_results = t_set_copy (copy_loc->loc_results);
    t_set_push (&so->so_copy_root->locus_content, (void*) copy_loc);
  }
}


void
dfe_locus_copy (sqlo_t * so, df_elt_t * copy)
{
  if (IS_BOX_POINTER (copy->dfe_locus))
    dfe_save_locus (so, copy->dfe_locus);
  DO_SET (locus_result_t *, lr, &copy->dfe_remote_locus_refs)
    {
      dfe_save_locus (so, lr->lr_locus);
    }
  END_DO_SET();
}

df_elt_t *
dfe_copy (sqlo_t * so, df_elt_t * dfe)
{
  df_elt_t * copy = (df_elt_t *) t_box_copy ((caddr_t) dfe);
  if (!so->so_copy_root)
    so->so_copy_root = copy;
  dfe_locus_copy (so, copy);
  return copy;
}


df_elt_t **
df_body_to_array (df_elt_t * body)
{
  df_elt_t * next = NULL;
  int len = dfe_body_len (body);
  df_elt_t ** copy = (df_elt_t **) t_alloc_box (sizeof (caddr_t) * len, DV_ARRAY_OF_POINTER);
  df_elt_t * elt;
  int fill = 1;
  copy[0] = (df_elt_t *) (ptrlong) body->dfe_type;
  for (elt = body->_.sub.first->dfe_next; elt; elt = next)
    {
      next = elt->dfe_next;
    copy[fill++] = sqlo_layout_copy_1 (elt->dfe_sqlo, elt, NULL);
      elt->dfe_next = elt->dfe_prev = NULL;
    }
  return ((df_elt_t **) copy);
}


df_elt_t ** dfe_pred_body_copy (sqlo_t * so, df_elt_t ** body, df_elt_t * parent);


df_elt_t *
dfe_body_copy (sqlo_t * so, df_elt_t * super, df_elt_t * parent)
{
  df_elt_t * copy_super = dfe_container (super->dfe_sqlo, super->dfe_type, parent);
  df_elt_t * elt;
  if (!so->so_copy_root)
    so->so_copy_root = copy_super;
  copy_super->dfe_locus = super->dfe_locus;
  copy_super->dfe_remote_locus_refs = super->dfe_remote_locus_refs;
  copy_super->_.sub.dt_out = (df_elt_t **) t_box_copy ((caddr_t) super->_.sub.dt_out);
  copy_super->_.sub.dt_imp_preds = super->_.sub.dt_imp_preds;
  copy_super->_.sub.dt_preds = super->_.sub.dt_preds;
  copy_super->_.sub.is_contradiction = super->_.sub.is_contradiction;
  copy_super->_.sub.invariant_test = dfe_pred_body_copy (so, super->_.sub.invariant_test, copy_super);
  copy_super->_.sub.trans = super->_.sub.trans;
  if (copy_super->_.sub.trans && copy_super->_.sub.trans->tl_complement)
    {
      copy_super->_.sub.trans->tl_complement = dfe_body_copy (so, copy_super->_.sub.trans->tl_complement, parent);
    }
  dfe_locus_copy (so, copy_super);
  copy_super->_.sub.ot = super->_.sub.ot;
  copy_super->dfe_tree = super->dfe_tree;
  copy_super->dfe_hash = super->dfe_hash;
  copy_super->_.sub.org_in = super->_.sub.org_in;
  copy_super->_.sub.after_join_test = dfe_pred_body_copy (so, super->_.sub.after_join_test, copy_super);
  copy_super->_.sub.vdb_join_test = dfe_pred_body_copy (so, super->_.sub.vdb_join_test, copy_super);
  copy_super->dfe_unit = super->dfe_unit;
  copy_super->dfe_arity = super->dfe_arity;
  copy_super->_.sub.in_arity = super->_.sub.in_arity;
  if (super->_.sub.generated_dfe)
    {
      /* the dt of a union dt has no subs but has the top qexp as generated_dfe.  This will become the only sub in the copied structure */
      df_elt_t * copy_elt = sqlo_layout_copy_1 (copy_super->dfe_sqlo, super->_.sub.generated_dfe, copy_super);
      L2_INSERT_AFTER (copy_super->_.sub.first, copy_super->_.sub.last, copy_super->_.sub.last, copy_elt, dfe_);
    }
  else
    {
      for (elt = super->_.sub.first->dfe_next; elt; elt = elt->dfe_next)
	{
	  df_elt_t * copy_elt = sqlo_layout_copy_1 (copy_super->dfe_sqlo, elt, copy_super);
	  L2_INSERT_AFTER (copy_super->_.sub.first, copy_super->_.sub.last, copy_super->_.sub.last, copy_elt, dfe_);
	}
    }
  return copy_super;
}


df_elt_t **
dfe_pred_body_copy (sqlo_t * so, df_elt_t ** body, df_elt_t * parent)
{
  df_elt_t ** copy;
  int inx;
  int first;
  if (!body)
    return NULL;
  first = (int) (ptrlong) body[0];
  copy = (df_elt_t **) t_box_copy ((caddr_t) body);
  DO_BOX (df_elt_t **, elt, inx, body)
    {
      if (!IS_BOX_POINTER (elt))
	continue;
      if (DFE_PRED_BODY == first)
	copy[inx] = sqlo_layout_copy_1 (so, body[inx], parent);
      else
	copy[inx] = (df_elt_t *) dfe_pred_body_copy (so, elt, parent);
    }
  END_DO_BOX;
  return copy;
}


df_inx_op_t *
inx_op_copy (sqlo_t * so, df_inx_op_t * dio,
	     df_elt_t * org_tb_dfe, df_elt_t * tb_dfe)
{
  t_NEW_VARZ (df_inx_op_t, copy);
  memcpy (copy, dio, sizeof (df_inx_op_t));
  if (dio->dio_table == org_tb_dfe)
    copy->dio_table = tb_dfe;
  else if (dio->dio_table)
    {
      copy->dio_table = sqlo_layout_copy_1 (so, dio->dio_table, NULL);
    }
  else if (dio->dio_terms)
    {
      s_node_t *iter;
      copy->dio_terms = t_set_copy (dio->dio_terms);
      DO_SET_WRITABLE (df_inx_op_t *, term, iter, &copy->dio_terms)
	{
	  iter->data = (void*) inx_op_copy (so, term, org_tb_dfe, tb_dfe);
	}
      END_DO_SET();
    }
  return copy;
}


df_elt_t *
sqlo_layout_copy_1 (sqlo_t * so, df_elt_t * dfe, df_elt_t * parent)
{
  if (!dfe)
    return NULL;
  switch (dfe->dfe_type)
    {
    case DFE_DT:
    case DFE_PRED_BODY:
    case DFE_VALUE_SUBQ:
    case DFE_EXISTS:
      if (dfe->_.sub.generated_dfe
	  && (DFE_DT == dfe->_.sub.generated_dfe->dfe_type ||
	   DFE_VALUE_SUBQ == dfe->_.sub.generated_dfe->dfe_type))
	return (sqlo_layout_copy_1 (so, dfe->_.sub.generated_dfe, parent));
      else
	return (dfe_body_copy (so, dfe, parent));
    case DFE_QEXP:
      {
	int inx;
	df_elt_t * copy = (df_elt_t *) t_box_copy ((caddr_t) dfe);
	df_elt_t ** terms = (df_elt_t **) t_box_copy ((caddr_t) dfe->_.qexp.terms);
	copy->_.qexp.terms = terms;
	DO_BOX (df_elt_t *, term, inx, terms)
	  {
	    terms[inx] = sqlo_layout_copy_1 (so, term, parent);
	  }
	END_DO_BOX;
	copy->dfe_super = parent;
	return copy;
      }

    case DFE_TABLE:
      {
	df_elt_t * copy = dfe_copy (so, dfe);
	copy->dfe_super = parent;
	copy->_.table.join_test = dfe_pred_body_copy (so, copy->_.table.join_test, copy);
	copy->_.table.after_join_test = dfe_pred_body_copy (so, copy->_.table.after_join_test, copy);
	copy->_.table.vdb_join_test = dfe_pred_body_copy (so, copy->_.table.vdb_join_test, copy);
	if (dfe->_.table.hash_filler)
	  copy->_.table.hash_filler = sqlo_layout_copy_1 (so, dfe->_.table.hash_filler, parent);
	if (dfe->_.table.hash_filler_after_code)
	  copy->_.table.hash_filler_after_code = dfe_pred_body_copy (so,
	      copy->_.table.hash_filler_after_code, copy);
	if (dfe->_.table.text_pred)
	  copy->_.table.text_pred = sqlo_layout_copy_1 (so, dfe->_.table.text_pred, parent);
	if (dfe->_.table.xpath_pred)
	  copy->_.table.xpath_pred = sqlo_layout_copy_1 (so, dfe->_.table.xpath_pred, parent);
	if (dfe->_.table.inx_op)
	  copy->_.table.inx_op = inx_op_copy (so, copy->_.table.inx_op, dfe, copy);
	return ((df_elt_t *) copy);
      }
    case DFE_BOP:
    case DFE_BOP_PRED:
    case DFE_CALL:
      {
	df_elt_t * copy = dfe_copy (so, dfe);
	copy->dfe_super = parent;
	return copy;
      }
    case DFE_GROUP:
    case DFE_ORDER:
      {
	df_elt_t * copy = dfe_copy (so, dfe);
	copy->_.setp.after_test = dfe_pred_body_copy (so, copy->_.setp.after_test, copy);
	copy->dfe_super = parent;
	return copy;
      }
    case DFE_CONTROL_EXP:
      {
	int inx;
	df_elt_t * copy = dfe_copy (so, dfe);
	copy->dfe_super = parent;
	copy->_.control.terms = (df_elt_t ***) t_box_copy ((caddr_t) dfe->_.control.terms);
	DO_BOX (df_elt_t **, elt, inx, dfe->_.control.terms)
	  {
	    copy->_.control.terms[inx] = dfe_pred_body_copy (so, elt, copy);
	  }
	END_DO_BOX;
	return copy;
      }

    case DFE_TEXT_PRED:
      {
	df_elt_t * copy = dfe_copy (so, dfe);
	copy->dfe_super = parent;
	copy->_.text.after_test = dfe_pred_body_copy (so, dfe->_.text.after_test, copy);
	return copy;
      }

    default: SQL_GPF_T1 (so->so_sc->sc_cc, "Bad top level dfe body");
    }
  return NULL; /*dummy*/
}


df_elt_t *
sqlo_layout_copy (sqlo_t * so, df_elt_t * dfe, df_elt_t * parent)
{
  so->so_copy_root = NULL;
  return (sqlo_layout_copy_1 (so, dfe, parent));
}

void
sqlo_unique_rows (sql_comp_t * sc, op_table_t * top_ot, ST * tree)
{
  /*sqlo_t *so = sc->sc_so;*/
  /*df_elt_t *dfe = so->so_copy_root;*/
  int nth, hidden_cols;
  ST **new_sel = NULL, **old_sel = NULL;
  dk_set_t id_refs = NULL;

  sc->sc_cc->cc_query->qr_unique_rows = 0;

  /*if (!sqlo_cr_is_identifiable (so, tree))
    return;
  df_elt_t *dfe = so->so_copy_root;
  if (!dfe || !dfe->dfe_type == DFE_DT)
    return 0;*/
  if (!ST_P (tree, SELECT_STMT))
    return;
  if (tree->_.select_stmt.table_exp->_.table_exp.group_by)
    return;
  /*if (so->so_sc->sc_fun_ref_defaults)
    return 0;*/
  if (SEL_IS_DISTINCT (tree))
    return;
  DO_SET (op_table_t *, ot, &top_ot->ot_from_ots)
  {
    if (ot->ot_dt)
      return;
  }
  END_DO_SET ();

  hidden_cols = 0;
  DO_SET (op_table_t *, ot, &top_ot->ot_from_ots)
  {
    dbe_key_t *pk = ot->ot_table->tb_primary_key;

    nth = 0;
    hidden_cols += pk->key_n_significant;
    DO_SET (dbe_column_t *, col, &pk->key_parts)
    {
      ST *ref = t_listst (3, COL_DOTTED, ot->ot_new_prefix, col->col_name);
      t_NCONCF1 (id_refs, ref);
      if (++nth >= pk->key_n_significant)
	break;
    }
    END_DO_SET ();
  }
  END_DO_SET ();

  new_sel = (ST **) t_list_to_array (id_refs);
  old_sel = (ST **) tree->_.select_stmt.selection;

  tree->_.select_stmt.selection = (caddr_t *) t_box_conc ((caddr_t) old_sel, (caddr_t) new_sel);

  sc->sc_cc->cc_query->qr_unique_rows = 1;
  sc->sc_cc->cc_query->qr_hidden_columns = hidden_cols;
}


int sqlo_print_debug_output = 0;

static df_elt_t *
sqlo_top_2 (sqlo_t * so, sql_comp_t * sc, ST ** ptree)
{
  ST *tree;
  df_elt_t * best;
  op_table_t * top_ot;
  so->so_sc = sc;
  sc->sc_so = so;
  sqlo_scope (so, ptree);
  tree = *ptree;
  if (so->so_is_select)
    {
      DO_SET (op_table_t *, ot, &so->so_tables)
	{
	  if (ot->ot_table && !ot->ot_has_cols &&
	      !sec_tb_check (ot->ot_table, ot->ot_g_id, ot->ot_u_id, GR_SELECT))
	    sqlc_new_error (sc->sc_cc, "42000", "SQ160",
		"No Select permission on the table %s.", ot->ot_table->tb_name);
	}
      END_DO_SET();
    }
  if (sqlo_print_debug_output)
    {
      sqlo_box_print ((caddr_t) tree);
      sqlo_print (("\n"));
    }
  top_ot = sqlo_find_dt (so, tree);
  if (sc->sc_cc && sc->sc_cc->cc_query && sc->sc_cc->cc_query->qr_unique_rows)
    sqlo_unique_rows(sc, top_ot, tree);
  so->so_df_elts = sqlo_allocate_df_elts (201);
  sqlo_df (so, top_ot->ot_dt);
  top_ot->ot_work_dfe = dfe_container (so, DFE_DT, NULL);
  top_ot->ot_work_dfe->dfe_tree = top_ot->ot_dt;
  top_ot->ot_work_dfe->_.sub.in_arity = 1;
  so->so_dfe = top_ot->ot_work_dfe;
  best = sqlo_layout (so, top_ot, SQLO_LAY_TOP, NULL);
  if (sqlo_print_debug_output)
    sqlo_dfe_print (best, 0);
  return best;
}


static void
sqlc_make_or_list (sql_tree_t * tree, dk_set_t * res)
{
  if (!tree)
    return;
  if (box_tag ((caddr_t) tree) != DV_ARRAY_OF_POINTER)
    return;
  if (tree->type != BOP_OR)
    {
      t_set_push (res, (void *) tree);
    }
  else
    {
      sqlc_make_or_list (tree->_.bin_exp.right, res);
      sqlc_make_or_list (tree->_.bin_exp.left, res);
    }
}


int
sqlp_tree_has_fun_ref (ST *tree)
{
  int res = 0;

  if (!ARRAYP (tree))
    res = 0;
  else if (ST_P (tree, FUN_REF))
    res = 1;
  else
    {
      int inx;
      DO_BOX (ST *, elt, inx, ((ST **)tree))
	{
	  if (sqlp_tree_has_fun_ref (elt))
	    {
	      res = 1;
	      break;
	    }
	}
      END_DO_BOX;
    }
  return res;
}

static ST*
sqlp_collect_from_pkeys (sqlo_t * so, ST* tree)
{
  int inx;
  dk_set_t pk_set = NULL;
  ST *texp = tree->_.select_stmt.table_exp;
  ST **from = texp->_.table_exp.from;


  DO_BOX (ST*, tb, inx, from)
    {
      ST *view;
      dbe_table_t *tb_found;
      dk_set_t ptr;
      int inx2;

      while (ST_P (tb, TABLE_REF))
	tb = tb->_.table_ref.table;
      if (!ST_P (tb, TABLE_DOTTED))
	return NULL;

      tb_found = sch_name_to_table (so->so_sc->sc_cc->cc_schema, tb->_.table.name);
      view = (ST*) sch_view_def (so->so_sc->sc_cc->cc_schema, tb_found->tb_name);

      if (view)
	return NULL;

      for (inx2 = 0, ptr = tb_found->tb_primary_key->key_parts;
	  inx2 < tb_found->tb_primary_key->key_n_significant;
	  inx2++, ptr = tb_found->tb_primary_key->key_parts->next)
	{
	  dbe_column_t * col = (dbe_column_t *) ptr->data;
	  DO_SET (caddr_t, col1, &pk_set)
	    {
	      if (!CASEMODESTRCMP (col1, col->col_name)) /* A column with same name already in the list from another table */
		return NULL;
	    }
	  END_DO_SET();
	  t_set_push (&pk_set, t_sym_string (col->col_name));
	}

    }
  END_DO_BOX;
  return (ST *) t_list_to_array (dk_set_nreverse (pk_set));
}

void
sqlo_unor_replace_col_refs (sqlo_t *so, ST ** orig_sel, ST * new_sel, ST * left)
{
  int inx;
  ST * left_sel = (ST *) left->_.select_stmt.selection;
  if (DV_TYPE_OF (*orig_sel) != DV_ARRAY_OF_POINTER)
    return;
  else if (ST_COLUMN (*orig_sel, COL_DOTTED))
    {
      DO_BOX (ST *, elt, inx, left_sel)
	{
	  if (ST_COLUMN (elt, COL_DOTTED))
	    {
	      if (!(*orig_sel)->_.col_ref.prefix)
		SQL_GPF_T (so->so_sc->sc_cc);
	      if (!elt->_.col_ref.prefix)
		SQL_GPF_T (so->so_sc->sc_cc);

	      if (!CASEMODESTRCMP ((*orig_sel)->_.col_ref.name, elt->_.col_ref.name)
		  && !CASEMODESTRCMP ((*orig_sel)->_.col_ref.prefix, elt->_.col_ref.prefix))
		{
		  ST * new_place = (((ST **)new_sel)[inx]);
		  while (ST_P (new_place, BOP_AS))
		    new_place = new_place->_.as_exp.left;
		  if (ST_COLUMN (new_place, COL_DOTTED))
		    *orig_sel = (ST *) t_box_copy_tree ((caddr_t) new_place);
		  else
		    SQL_GPF_T (so->so_sc->sc_cc);
		  return;
		}
	    }
	}
      END_DO_BOX;
      SQL_GPF_T (so->so_sc->sc_cc);
    }
  else if (ARRAYP ((*orig_sel)))
    {
      for (inx = 0; inx < BOX_ELEMENTS_INT ((*orig_sel)); inx++)
	sqlo_unor_replace_col_refs (so, &(((ST **)(*orig_sel))[inx]), new_sel, left);
    }
}

static int
sqlp_convert_or_to_union (sqlo_t * so, ST **ptree)
{
  ST *tree = *ptree;
  if (ST_P (tree, SELECT_STMT) && BOX_ELEMENTS (tree) >= 5 &&
      ST_P (tree->_.select_stmt.table_exp, TABLE_EXP) &&
      ST_P (tree->_.select_stmt.table_exp->_.table_exp.where, BOP_OR) &&
      !sqlp_tree_has_fun_ref (tree) &&
      !tree->_.select_stmt.table_exp->_.table_exp.group_by &&
      !tree->_.select_stmt.table_exp->_.table_exp.order_by)
    {
      ST *where = tree->_.select_stmt.table_exp->_.table_exp.where;
      dk_set_t or_list = NULL;
      ST *new_tree = NULL;
      ST *orig_sel = (ST *) t_box_copy_tree ((caddr_t) tree->_.select_stmt.selection);
      ST *corresponding_list = sqlp_collect_from_pkeys (so, tree);

      if (!corresponding_list)
	return 0;

      tree->_.select_stmt.selection = (caddr_t *) sqlp_stars (
	        sqlp_wrapper_sqlxml ((ST **) t_listst (1, t_listst (3, COL_DOTTED, (long) 0, STAR))),
	  	tree->_.select_stmt.table_exp->_.table_exp.from);

      sqlc_make_or_list (where, &or_list);

      DO_SET (ST *, clause, &or_list)
	{
	  ST *new_leaf = (ST *) t_box_copy_tree ( (caddr_t) tree);

	  new_leaf->_.select_stmt.table_exp->_.table_exp.where = clause;

	  if (new_tree)
	    new_tree = t_listst (5, UNION_ST,
		new_leaf, new_tree, corresponding_list, NULL);
	  else
	    new_tree = new_leaf;
	}
      END_DO_SET ();
      new_tree = sqlp_view_def (NULL, new_tree, 1);
      new_tree = sqlc_union_dt_wrap (new_tree);
      sqlo_unor_replace_col_refs (so, &orig_sel, (ST *)new_tree->_.select_stmt.selection, sqlp_union_tree_select (tree));
      new_tree->_.select_stmt.selection = (caddr_t *) orig_sel;
      *ptree = new_tree;
      return 1;
    }
  else if (DV_TYPE_OF (tree) == DV_ARRAY_OF_POINTER)
    {
      int inx, res = 0;
      _DO_BOX (inx, ((caddr_t *)tree))
	{
	  res = res || sqlp_convert_or_to_union (so, &(((ST **)tree)[inx]));
	}
      END_DO_BOX;
      return res;
    }
  else
    return 0;
}

long sql_max_tree_depth = 1000;

static void
sqlo_tree_depth_check (sql_comp_t * sc, ST * tree, int level)
{
  int inx;

  if (0 == sql_max_tree_depth)
    return;

  level++;
  if (level > sql_max_tree_depth)
    sqlc_error (sc->sc_cc, "42000", "Expression recursion is too deep");
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    return;
  DO_BOX (ST *, elt, inx, tree)
    {
      sqlo_tree_depth_check (sc, elt, level);
    }
  END_DO_BOX;
}

df_elt_t *
sqlo_top_1 (sqlo_t * so, sql_comp_t * sc, ST ** ptree)
{
  ST *tree = *ptree;
  df_elt_t *best1, *best2;
  sqlo_t so_save_orig, so_save_1;
  sql_comp_t sc_save_orig, sc_save_1;
  ST *tree_copy;
  int in_cursor_def = 0;
  sql_comp_t *sc_tmp = sc;

  do
    {
      if (sc_tmp->sc_in_cursor_def)
	in_cursor_def = 1;
      sc_tmp = sc_tmp->sc_scroll_super ? sc_tmp->sc_scroll_super : sc_tmp->sc_super;
    }
  while (!in_cursor_def && sc_tmp);

  sqlo_tree_depth_check (sc, tree, 0);
  if (in_cursor_def)
    {
      best1 = sqlo_top_2 (so, sc, ptree);
      tree = *ptree;
    }
  else
    {
      memcpy (&sc_save_orig, sc, sizeof (sql_comp_t));
      memcpy (&so_save_orig, so, sizeof (sqlo_t));

      best1 = sqlo_top_2 (so, sc, ptree);
      tree = *ptree;
      tree_copy = (ST *) t_box_copy_tree ((caddr_t) tree);

      if (!inside_view && sqlp_convert_or_to_union (so, &tree_copy))
	{
	  memcpy (&sc_save_1, sc, sizeof (sql_comp_t));
	  memcpy (&so_save_1, so, sizeof (sqlo_t));
	  memcpy (sc, &sc_save_orig, sizeof (sql_comp_t));
	  memcpy (so, &so_save_orig, sizeof (sqlo_t));

	  if (sqlo_print_debug_output)
	    sqlo_print (("**** Found top level ORs\n"));

	  best2 = sqlo_top_2 (so, sc, &tree_copy);

	  if (sqlo_print_debug_output)
	    sqlo_print (("Score with ORs %9.2g, with UNION all %9.2g\n", best1->dfe_unit, best2->dfe_unit));

	  if (best1->dfe_unit < best2->dfe_unit)
	    {
	      memcpy (sc, &sc_save_1, sizeof (sql_comp_t));
	      memcpy (so, &so_save_1, sizeof (sqlo_t));
	    }
	  else
	    {
	      *ptree = tree_copy;
	      tree = *ptree;
	      best1 = best2;
	    }
	}
    }
  return best1;
}


caddr_t
sqlo_top (sql_comp_t * sc, ST ** volatile ptree, float * volatile score_ptr)
{
  ST * volatile tree = *ptree;
  df_elt_t * volatile ret = NULL;
  if (score_ptr)
    *score_ptr = 0;
  CATCH (CATCH_LISP_ERROR)
    {
      t_NEW_VARZ (sqlo_t, so);
      so->so_is_select = 1;

      if (ST_P (tree, UNION_ST) ||
	   ST_P (tree, UNION_ALL_ST) ||
	   ST_P (tree, EXCEPT_ST) ||
	   ST_P (tree, EXCEPT_ALL_ST) ||
	   ST_P (tree, INTERSECT_ST) ||
	   ST_P (tree, INTERSECT_ALL_ST))
	{
	  tree = sqlp_view_def (NULL, tree, 1);
	  tree = sqlc_union_dt_wrap (tree);
	  *ptree = tree;
	}
      ret = sqlo_top_1 (so, sc, ptree);
      tree = *ptree;
      if (score_ptr)
	*score_ptr = ret->dfe_unit;
    }
  THROW_CODE
    {
      caddr_t * err = (caddr_t*) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR);

      if (sqlo_print_debug_output)
	{
	  sqlo_print (("sql opt error%s: %s\n",
		ERR_STATE (err), ERR_MESSAGE (err)));
	}
      dk_free_tree ((box_t) err);	/* IvAn/010801/LeakOnError */
    }
  END_CATCH;
  return (caddr_t) (ret && ret->dfe_tree ? ret->dfe_tree : NULL);
}


void
sqlo_calculate_view_scope (query_instance_t *qi, ST **tree, char *view_name)
{
  if (!ST_P (*tree, PROC_TABLE))
    {
      caddr_t err = NULL;
      ST *tree1;

      if (sqlo_print_debug_output)
	{
	  fprintf (stderr, "Before view expand :\n");
	  dbg_print_box ((caddr_t) *tree, stderr);
	  fprintf (stderr, "\n");
	}

      tree1 = (ST *) sql_compile_1 ("", qi->qi_client, &err, SQLC_TRY_SQLO, *tree, view_name);
      dk_free_tree ((box_t) *tree);
      *tree = tree1;

      if (sqlo_print_debug_output)
	{
	  fprintf (stderr, "After view expand :\n");
	  dbg_print_box ((caddr_t) tree1, stderr);
	  fprintf (stderr, "\n");
	}
    }
}


void
sqlo_calculate_subq_view_scope (sql_comp_t *super_sc, ST **tree)
{
  if (!ST_P (*tree, PROC_TABLE))
    {
      ST *tree1 = (ST *) t_full_box_copy_tree ((caddr_t) *tree);
      ST *tree2;
      sql_comp_t sc;
      comp_context_t cc;
      query_t *qr = NULL;
      memset (&sc, 0, sizeof (sc));
      CC_INIT (cc, super_sc->sc_client);
      sc.sc_cc = &cc;
      cc.cc_super_cc = super_sc->sc_cc;
      sc.sc_super = super_sc;
      sc.sc_check_view_sec = super_sc->sc_check_view_sec;
      sc.sc_client = super_sc->sc_client;
      sc.sc_col_ref_recs = super_sc->sc_subq_initial_crrs;

      tree2 = (ST *) sqlo_top (&sc, &tree1, NULL);
      if (tree2)
	tree1 = tree2;
      *tree = tree1;
    }
}


void
sqlo_top_select (sql_comp_t * sc, ST ** ptree)
{
  CATCH (CATCH_LISP_ERROR)
    {
      df_elt_t * dfe;
      t_NEW_VARZ (sqlo_t, so);
      so->so_is_select = 1;
      dfe = sqlo_top_1 (so, sc, ptree);
      sqlg_top (so, dfe);
      SQLO_MP_SAMPLE;
#ifdef noDBG_SQLO_MP
      if (virtuoso_server_initialized)
	fprintf (stderr, "sqlo_top_select %s %d mp_bytes=%d, max=%d\n", __FILE__, __LINE__,
	    (THR_TMP_POOL)->mp_bytes, sqlo_pick_mp_size);
#endif
      so->so_copy_root = dfe;
    }
  THROW_CODE
    {
      caddr_t * err = (caddr_t*) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR);
      POP_CATCH;
      if (sqlo_print_debug_output)
	{
	  sqlo_print (("sql opt error%s: %s\n",
		ERR_STATE (err), ERR_MESSAGE (err)));
	}
      lisp_throw (CATCH_LISP_ERROR, reset_code);
    }
  END_CATCH;
}


void
sqlo_query_spec (sql_comp_t *sc, ptrlong is_distinct, caddr_t * selection,
    sql_tree_t * table_exp, data_source_t ** head_ret, state_slot_t *** sel_out_ret)
{
  ST *sel = t_listst (5, SELECT_STMT, is_distinct,
      sqlp_stars ((ST **) selection, table_exp->_.table_exp.from),
      NULL,
      table_exp);
  data_source_t *head = NULL;
  query_t *qr;
  state_slot_t **sel_out = NULL;

  CATCH (CATCH_LISP_ERROR)
    {
      df_elt_t * dfe;
      t_NEW_VARZ (sqlo_t, so);
      dfe = sqlo_top_1 (so, sc, &sel);
      sqlg_top_1 (so, dfe, &sel_out);
    }
  THROW_CODE
    {
      caddr_t * err = (caddr_t*) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR);
      POP_CATCH;
      if (sqlo_print_debug_output)
	{
	  sqlo_print (("sql opt error%s: %s\n",
	      ERR_STATE (err), ERR_MESSAGE (err)));
	}
      lisp_throw (CATCH_LISP_ERROR, reset_code);
    }
  END_CATCH;
  sc->sc_so = NULL;
  qr = sc->sc_cc->cc_query;
  head = qr->qr_head_node;
  *sel_out_ret = sel_out;
  *head_ret = qr->qr_head_node;
}


state_slot_t *
sqlo_co_place (sql_comp_t * sc)
{
  /* in searched update / delete, there's one table source.
     Get its current of */
  data_source_t *head = sc->sc_cc->cc_query->qr_head_node;
  state_slot_t * ret = NULL;
  while (head)
    {
      if (IS_TS (head))
        ret = ((table_source_t *)head)->ts_current_of;
      head = head->src_continuations ? (data_source_t *) head->src_continuations->data : NULL;
    }
  return ret;
}


