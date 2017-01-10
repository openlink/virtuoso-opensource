/*
 *  sqlstmts.c
 *
 *  $Id$
 *
 *  Dynamic SQL Statement Compilations
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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
#include "xmltree.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "security.h"
#include "sqlpfn.h"
#include "sqlintrp.h"
#include "arith.h"
#include "sqlo.h"
#include "sqltype_c.h"
#include "xpathp_impl.h" /* for xml_view_name() */
#include "sqlbif.h"


ST**
tc_trig_selection (dbe_table_t * tb, caddr_t * cols, ST ** vals)
{
  int fill = 0, cinx;
  ST **sel;
  int n_cols = dk_set_length (tb->tb_primary_key->key_parts);
  int n_total;
  if (cols)
    {
      n_total = n_cols * 2;
    }
  else
    n_total = n_cols;
  sel = (ST **) t_alloc_box (sizeof (caddr_t) * n_total, DV_ARRAY_OF_POINTER);
  DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
  {
    sel[fill++] = (ST *) t_list (3, COL_DOTTED, NULL, t_box_string (col->col_name));
  }
  END_DO_SET ();
  if (cols)
    {
      DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
      {
	DO_BOX (caddr_t, cname, cinx, cols)
	{
	  if (0 == CASEMODESTRCMP (cname, col->col_name))
	    {
	      sel[fill++] = (ST *) t_box_copy_tree ((caddr_t) (vals[cinx]));
	      goto next_sel;
	    }
	}
	END_DO_BOX;
	sel[fill++] = (ST *) t_list (3, COL_DOTTED, NULL,
	    t_box_string (col->col_name));
      next_sel:;
      }
      END_DO_SET ();
    }
  return sel;
}


void
sqlc_trig_const_params (sql_comp_t * sc, state_slot_t ** params, dk_set_t * code)
{
  int inx;
  DO_BOX (state_slot_t *, sl, inx, params)
  {
    if (!SSL_IS_REFERENCEABLE (sl))
      {
	state_slot_t *temp = sqlc_new_temp (sc, "trig_temp", DV_UNKNOWN);
	cv_artm (code, (ao_func_t)box_identity, temp, sl, NULL);
	params[inx] = temp;
      }
  }
  END_DO_BOX;
}


ST **
box_add_prime_keys (ST ** selection, dbe_table_t * tb)
{
  int inx;
  int len = selection ? BOX_ELEMENTS (selection) : 0;
  int n_new = tb->tb_primary_key->key_n_significant;
  ST **n_sel = (ST **) t_alloc_box (sizeof (caddr_t) * (len + n_new),
      DV_ARRAY_OF_POINTER);
  if (selection)
    {
      DO_BOX (ST *, ref, inx, selection)
      {
	n_sel[inx] = (ST *) t_box_copy_tree ((caddr_t) ref);
      }
      END_DO_BOX;
    }
  inx = 0;
  DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
  {
    char tmp[MAX_NAME_LEN];
    snprintf (tmp, sizeof (tmp), "PKCOL__%d", inx);
    n_sel[len + inx] = (ST *) t_list (5, BOP_AS, t_list (3, COL_DOTTED, NULL,
	t_box_string (col->col_name)), NULL, t_sqlp_box_id_upcase (tmp), NULL);
    inx++;
    if (inx == n_new)
      break;
  }
  END_DO_SET ();
  return (n_sel);
}

#define TC_ALL_KEYS ((dbe_key_t*)2)
extern int enable_vec_upd;


ST **
box_add_keys (ST ** selection, dbe_table_t * tb, dbe_key_t * key_only, caddr_t * upd_cols)
{
  int inx, need_pk = 0, n = 0;
  int len = selection ? BOX_ELEMENTS (selection) : 0;
  int n_new;
  dk_set_t cols = NULL;
  ST **n_sel;
  DO_SET (dbe_key_t *, key, &tb->tb_keys)
    {
      n = 0;
      if (!upd_cols && !(TC_ALL_KEYS == key_only || key_only == key))
	continue;
      if (upd_cols && tb->tb_primary_key->key_is_col)
	need_pk = 1; /* a col-wise pk update always needs pk for logging */
      if (upd_cols && enable_vec_upd)
	{
	  int n_sens = key->key_is_primary ? key->key_n_significant : -1;
	  int nth_part = 0;
	  DO_SET (dbe_column_t *, part, &key->key_parts)
	    {
	      int i2;
	      DO_BOX (caddr_t, upd_col_name, i2, upd_cols)
		{
		  if (0 == stricmp (upd_col_name, part->col_name))
		    {
		      if (key != tb->tb_primary_key)
			need_pk = 1;
		      goto key_affected;
		    }
		}
	      END_DO_BOX;
	      if (++nth_part == n_sens)
		break;
	    }
	  END_DO_SET();
	continue;
	    key_affected: ;
	}

      DO_SET (dbe_column_t *, col, &key->key_parts)
	{
	  t_set_pushnew (&cols, (void*)col);
	  if (((key->key_is_primary && !upd_cols)|| (upd_cols && !key->key_is_primary))
	      && ++n == key->key_n_significant)
	    break;
	}
      END_DO_SET();
    }
  END_DO_SET();
  if (upd_cols && enable_vec_upd)
    {
      int iu;
      need_pk = 1; /* always needs pk values for logging */
      DO_BOX (caddr_t, col_name, iu, upd_cols)
	{
	  dbe_column_t * col = tb_name_to_column (tb, col_name);
	  if (IS_BLOB_DTP (col->col_sqt.sqt_col_dtp))
	    t_set_pushnew (&cols, (void*)col);
	}
      END_DO_BOX;
    }
  if (need_pk)
    {
      n = 0;
      DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
	{
	  t_set_pushnew (&cols, (void*)col);
	  if (++n == tb->tb_primary_key->key_n_significant)
	    break;
	}
      END_DO_SET();
    }
  n_new = dk_set_length (cols);
  n_sel = (ST **) t_alloc_box (sizeof (caddr_t) * (len + n_new),
			       DV_ARRAY_OF_POINTER);
  if (selection)
    {
      DO_BOX (ST *, ref, inx, selection)
      {
	n_sel[inx] = (ST *) t_box_copy_tree ((caddr_t) ref);
      }
      END_DO_BOX;
    }
  inx = 0;

  DO_SET (dbe_column_t *, col, &cols)
    {
      char tmp[MAX_NAME_LEN];
      snprintf (tmp, sizeof (tmp), "PKCOL__%d", inx);
      n_sel[len + inx] = (ST *) t_list (5, BOP_AS, t_list (3, COL_DOTTED, NULL,
							   t_box_string (col->col_name)), NULL, t_sqlp_box_id_upcase (tmp), NULL);
      inx++;
    }
  END_DO_SET ();
  return (n_sel);
}


void
tc_init (trig_cols_t * tc, int event, dbe_table_t * tb, caddr_t * cols, ST ** vals, dbe_key_t * add_pk)
{
  memset (tc, 0, sizeof (trig_cols_t));
  tc->tc_table = tb;
  if (-1 == event)
    ;
  else if (cols)
    event = TRIG_UPDATE;
  else
    event = TRIG_DELETE;
  tc->tc_cols = cols;
  tc->tc_vals = vals;
  if (tb_is_trig (tb, event, cols))
    {
      tc->tc_is_trigger = 1;
      tc->tc_selection = tc_trig_selection (tb, cols, vals);
    }
  else
    {
      tc->tc_cols = cols,
	  tc->tc_vals = vals;
      if (add_pk || (enable_vec_upd && cols))
	{
	  if (1 == (ptrlong)add_pk)
	  tc->tc_selection = box_add_prime_keys (vals, tb);
	  else
	    tc->tc_selection = box_add_keys (vals, tb, add_pk, cols);
	  tc->tc_n_before_pk = cols ? BOX_ELEMENTS (cols) : 0;
	  tc->tc_pk_added = 1;
	}
      else
	tc->tc_selection = vals ? (ST **) t_box_copy_tree ((caddr_t) vals) : (ST **) t_list (0);
    }
}


void
tc_free (trig_cols_t * tc)
{
  /*dk_free_tree ((caddr_t) tc->tc_selection);*/
}


#define IS_THIS_COL(col, name) \
  (0 == CASEMODESTRCMP (col->col_name, name))

int
tc_new_value_inx (trig_cols_t *tc, char *col_name)
{
  int inx;
  int n_in_sel = BOX_ELEMENTS (tc->tc_selection);
  if (tc->tc_is_trigger)
    {
      dk_set_t parts = tc->tc_table->tb_primary_key->key_parts;
      for (inx = n_in_sel / 2; inx < n_in_sel; inx++)
	{
	  dbe_column_t * col = (dbe_column_t*) parts->data;
	  if (IS_THIS_COL (col, col_name))
	    return inx;
	  parts = parts->next;
	}
    }
  else
    {
      DO_BOX (caddr_t, cname, inx, tc->tc_cols)
	{
	  if (0 == CASEMODESTRCMP (cname, col_name))
	    return inx;
	}
      END_DO_BOX;
    }
  GPF_T1 ("Inconsistent update /delete node compilation");
  return 0; /* keep cc happy */
}

int
tc_pk_value_inx (trig_cols_t *tc, char *col_name)
{
  /* get a pk col from 'old values' */
  int inx;
  dk_set_t parts = tc->tc_table->tb_primary_key->key_parts;
  if (tc->tc_is_trigger)
    {
      int n_old = BOX_ELEMENTS (tc->tc_selection);
      if (tc->tc_vals)
	n_old = n_old / 2;
      for (inx = 0; inx < n_old; inx++)
	{
	  dbe_column_t *col = (dbe_column_t*) parts->data;
	  if (IS_THIS_COL (col, col_name))
	    return inx;
	  parts = parts->next;
	}
    }
  else
    {
      if (!tc->tc_pk_added)
	GPF_T;
      for (inx = tc->tc_n_before_pk; ((uint32) inx) < BOX_ELEMENTS (tc->tc_selection); inx++)
	{
	  dbe_column_t *col = (dbe_column_t*) parts->data;
	  if (IS_THIS_COL (col, col_name))
	    return inx;
	  parts = parts->next;
	}
    }
  GPF_T1 ("Inconsistent update / delete compilation");
  return 0; /* keep cc happy */
}


caddr_t *
ins_tb_all_cols (dbe_table_t * tb)
{
  dbe_column_t **cols;
  long n_cols, inx;

  cols = (dbe_column_t **) t_list_to_array (
      key_ensure_visible_parts (tb->tb_primary_key));
  n_cols = BOX_ELEMENTS (cols);
  DO_BOX (dbe_column_t *, col, inx, cols)
  {
    cols[inx] = (dbe_column_t *) t_box_string (col->col_name);
  }
  END_DO_BOX;
  return ((caddr_t *) cols);
}


caddr_t
box_append_1 (caddr_t box, caddr_t elt)
{
  caddr_t b2;
  if (!box)
    {
      box = dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      ((caddr_t*)box)[0] = elt;
      return box;
    }
  b2 = dk_alloc_box (box_length (box) + sizeof (caddr_t), box_tag (box));
  memcpy (b2, box, box_length (box));
  *((caddr_t *) (b2 + box_length (box))) = elt;
  return b2;
}

caddr_t
box_append_1_free (caddr_t box, caddr_t elt)
{
  caddr_t b2;
  if (!box)
    return list (1, elt);
  b2 = dk_alloc_box (box_length (box) + sizeof (caddr_t),
      box_tag (box));
  memcpy (b2, box, box_length (box));
  *((caddr_t *) (b2 + box_length (box))) = elt;
  dk_free_box (box);
  return b2;
}


caddr_t
t_box_append_1 (caddr_t box, caddr_t elt)
{
  caddr_t b2;
  if (!box)
    return (caddr_t)t_list (1, elt);
  b2 = t_alloc_box (box_length (box) + sizeof (caddr_t),
      box_tag (box));
  memcpy (b2, box, box_length (box));
  *((caddr_t *) (b2 + box_length (box))) = elt;
  return b2;
}


void
sqlc_insert_autoincrements (sql_comp_t * sc, insert_node_t * ins,
    dk_set_t * code)
{
  dbe_table_t *tb = ins->ins_table;
  caddr_t snext;
  caddr_t seq_name;
  state_slot_t **args;
  char temp[1000];
  DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
  {
    if (col->col_is_autoincrement || (col->col_sqt.sqt_col_dtp == DV_TIMESTAMP && !in_log_replay))
      {
	int inx;
	state_slot_t *sl = NULL, *old_sl = NULL, *sl1 = NULL;

	DO_BOX (oid_t, col_id, inx, ins->ins_col_ids)
	{
	  if (col->col_id == col_id)
	    {
	      old_sl = (state_slot_t *) dk_set_nth (ins->ins_values, inx);
	      break;
	    }
	}
	END_DO_BOX;
	if (col->col_sqt.sqt_col_dtp != DV_TIMESTAMP)
	  sl1 = sqlc_new_temp (sc, "ainc_tmp", DV_LONG_INT);
	sl = sqlc_new_temp (sc, "ainc", col->col_sqt.sqt_col_dtp);
	if (old_sl)
	  {
	    if (col->col_sqt.sqt_col_dtp != DV_TIMESTAMP)
	      {
		caddr_t inc_by = col->col_options ? get_keyword_int (col->col_options, "increment_by", NULL) : NULL;

		snprintf (temp, sizeof (temp), "%s.%s.%s.%s", tb->tb_qualifier, tb->tb_owner,
		    col->col_defined_in->tb_name, col->col_name);
		seq_name = box_dv_short_string (temp);
		args = (state_slot_t **) sc_list (3, ssl_new_constant (sc->sc_cc, seq_name), old_sl,
		    ssl_new_constant (sc->sc_cc, (caddr_t) (ptrlong) 1));
		snext = t_sqlp_box_id_upcase ("sequence_set");
		cv_bif_call (code, bif_sequence_set_no_check, snext, NULL, args);
		if (inc_by)
		  {
		    args = (state_slot_t **) sc_list (2, ssl_new_constant (sc->sc_cc, seq_name),
			ssl_new_constant (sc->sc_cc, inc_by));
		    dk_free_tree (inc_by);
		  }
		else
		  {
		    args = (state_slot_t **) dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_POINTER);
		    args[0] = ssl_new_constant (sc->sc_cc, seq_name);
		  }
		dk_free_box (seq_name);
		snext = t_sqlp_box_id_upcase ("sequence_next");
		cv_bif_call (code, bif_sequence_next_no_check, snext, NULL, args);
		goto next_col;  /* given value overrides automatic if identity column. */
	      }
	    /* replace the slot in values with the autoinc value */
	    dk_set_member (ins->ins_values, old_sl)->data = (caddr_t) sl;
	  }
	else
	  {
	    ins->ins_col_ids = (oid_t *) box_append_1_free (
		(caddr_t) ins->ins_col_ids, (caddr_t) (ptrlong) col->col_id);
	    ins->ins_values = NCONC (ins->ins_values, CONS (sl, NULL));
	  }
	if (col->col_sqt.sqt_col_dtp != DV_TIMESTAMP)
	  {
	    caddr_t inc_by = col->col_options ? get_keyword_int (col->col_options, "increment_by", NULL) : NULL;

	    snprintf (temp, sizeof (temp), "%s.%s.%s.%s", tb->tb_qualifier, tb->tb_owner,
		col->col_defined_in->tb_name, col->col_name);
	    seq_name = box_dv_short_string (temp);
	    if (inc_by)
	      {
		args = (state_slot_t **) /*list*/ sc_list (2, ssl_new_constant (sc->sc_cc, seq_name),
		    ssl_new_constant (sc->sc_cc, inc_by));
		dk_free_tree (inc_by);
	      }
	    else
	      {
		args = (state_slot_t **) dk_alloc_box (sizeof (caddr_t),
		    DV_ARRAY_OF_POINTER);
		args[0] = ssl_new_constant (sc->sc_cc, seq_name);
	      }
	    dk_free_box (seq_name);
	    snext = t_sqlp_box_id_upcase ("sequence_next");
	    cv_bif_call (code, bif_sequence_next_no_check, snext, sl1, args);

	    args = (state_slot_t **) dk_alloc_box (sizeof (caddr_t),
		DV_ARRAY_OF_POINTER);
	    args[0] = sl1;
	    snext = t_sqlp_box_id_upcase ("__set_identity");
	  }
	else
	  {
	    snext = t_sqlp_box_id_upcase ("now");
	    args = (state_slot_t **) dk_alloc_box (0,
		DV_ARRAY_OF_POINTER);
	  }
	cv_call (code, NULL, snext, sl, args);
      }
  next_col: ;
  }
  END_DO_SET ();
}


state_slot_t **
sqlc_ins_triggers_1 (sql_comp_t * sc, dbe_table_t * tb, oid_t * col_ids,
    dk_set_t values, dk_set_t * code)
{
  if (tb_is_trig (tb, TRIG_INSERT, NULL))
    {
      int fill = 0, cinx;
      int n_cols = dk_set_length (tb->tb_primary_key->key_parts);
      state_slot_t **args = (state_slot_t **) dk_alloc_box (
	  n_cols * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
      {
	DO_BOX (oid_t, cid, cinx, col_ids)
	{
	  if (col->col_id == cid)
	    {
	      state_slot_t *sl = (state_slot_t *) dk_set_nth (values, cinx);
	      state_slot_t *sl2 = sl;
	      if (!sl)
		sqlc_new_error (sc->sc_cc, "21S01", "SQ093",
		    "Mismatched columns and values in insert.");
	      if (!SSL_IS_REFERENCEABLE (sl))
		{
		  sl2 = sqlc_new_temp (sc, "const_tmp", DV_UNKNOWN);
		  cv_artm (code, (ao_func_t)box_identity, sl2, sl, NULL);
		  sl = sl2;
		}
	      args[fill++] = sl2;
	      goto next_col;
	    }
	}
	END_DO_BOX;
	if (col->col_sqt.sqt_col_dtp == DV_TIMESTAMP)
	  {
	    caddr_t now = t_sqlp_box_id_upcase ("get_timestamp");
	    state_slot_t *tmp = sqlc_new_temp (sc, "ins_ts", DV_DATETIME);
	    args[fill++] = tmp;
	    cv_call (code, NULL, now, tmp, (state_slot_t **) /*list*/ sc_list (0));
	    /*dk_free_box (now);*/
	  }
	else
	  {
	    caddr_t deflt = col->col_default;
	    state_slot_t *tmp = sqlc_new_temp (sc, "ins_def", DV_UNKNOWN);
	    args[fill++] = tmp;
	    cv_artm (code, (ao_func_t) box_identity, tmp, ssl_new_constant (
		sc->sc_cc, deflt), NULL);
	  }
      next_col:;
      }
      END_DO_SET ();
      return args;
    }
  else
    return NULL;
}


void
sqlc_ins_triggers (sql_comp_t * sc, insert_node_t * ins, dk_set_t * code)
{
  ins->ins_trigger_args = sqlc_ins_triggers_1 (sc,
      ins->ins_table, ins->ins_col_ids, ins->ins_values, code);
}


sql_type_t *
sqlc_stmt_nth_col_type (sql_comp_t * sc, dbe_table_t * tb, ST * tree, int nth)
{
  /* in ins ( ipd, the type expected for the nth col */
  dbe_column_t * db_col = NULL;
  caddr_t col = 0;
  if (!tb)
    {
      char * tb_name = NULL;
      switch (tree->type)
	{
	case INSERT_STMT:
	  tb_name = tree->_.insert.table->_.table.name;
	  break;
	case UPDATE_SRC:
	  tb_name = tree->_.update_src.table->_.table.name;
	  break;
	case UPDATE_POS:
	  tb_name = tree->_.update_pos.table->_.table.name;
	  break;
	}
      tb = sch_name_to_table (wi_inst.wi_schema, tb_name);
      if (!tb)
	SQL_GPF_T1 (sc->sc_cc, "no table, although should already be checked");
    }
  switch (tree->type)
    {
    case UPDATE_SRC:
      col = (char *) tree->_.update_src.cols[nth];
      break;
    case UPDATE_POS:
      col = (char *) tree->_.update_pos.cols[nth];
      break;
    case INSERT_STMT:
      if (tree->_.insert.cols)
	col = (char *) tree->_.insert.cols[nth];
      else
	{
	  db_col = (dbe_column_t *) dk_set_nth (tb->tb_primary_key->key_parts, nth);
	  if (!col)
	    sqlc_new_error (sc->sc_cc, "21S01", "SQ094",
		"Too many (%d) values in insert into %s", nth + 1, tb->tb_name);
	  return (&db_col->col_sqt);
	}
      break;
    default:
      SQL_GPF_T (sc->sc_cc);
    }
  db_col = tb_name_to_column (tb, col);
  if (!db_col)
    sqlc_new_error (sc->sc_cc, "42S22", "SQ095", "No column %s", col);
  return (&db_col->col_sqt);
}


void
sqlc_ins_param_types (sql_comp_t * sc, insert_node_t * ins)
{
  int inx = 0;
  DO_SET (state_slot_t *, ssl,  &ins->ins_values)
    {
      state_slot_t lsl;
      dbe_column_t * col = sch_id_to_col (wi_inst.wi_schema,
	  ins->ins_col_ids[inx]);
      memset (&lsl, 0, sizeof (state_slot_t));
      lsl.ssl_name = col->col_name;
      lsl.ssl_column = col;
      lsl.ssl_type = SSL_COLUMN;
      lsl.ssl_sqt = col->col_sqt;

      cv_bop_params (&lsl, ssl, "INSERT");
      inx++;
    }
  END_DO_SET ();
}


caddr_t
sqlc_rls_get_condition_string (dbe_table_t *tb, int op, caddr_t *err)
{
  static char *action_names[] = {
    "U",
    "I",
    "D",
    "S"
  };
  static query_t *call_qr = NULL;
  client_connection_t *cli = sqlc_client();
  caddr_t ret_val = NULL;
  local_cursor_t *lc = NULL;

  if (!call_qr)
    {
      call_qr = sql_compile ("call (?) (?,?)", cli, err, SQLC_DEFAULT);
      if (*err)
	goto done;
    }

  *err = qr_quick_exec (call_qr, cli, NULL, &lc, 3,
      ":0", tb->tb_rls_procs[op], QRP_STR,
      ":1", tb->tb_name, QRP_STR,
      ":2", action_names[op], QRP_STR);

  if (*err)
    goto done;

  while (lc_next (lc));

  if (!lc)
    goto done;

  if (lc->lc_error)
    {
      *err = box_copy_tree (lc->lc_error);
      lc_free (lc);
      goto done;
    }

  if (IS_BOX_POINTER (lc->lc_proc_ret) && BOX_ELEMENTS (lc->lc_proc_ret) > 1)
    {
      ret_val = box_copy_tree (((caddr_t *) lc->lc_proc_ret)[1]);
    }
  lc_free (lc);
  lc = NULL;

  if (!DV_STRINGP (ret_val))
    {
      dk_free_tree (ret_val);
      goto done;
    }

done:
  if (*err)
    {
      dk_free_box (ret_val);
      ret_val = NULL;
    }

  return ret_val;
}


query_t *
sqlc_make_policy_trig (comp_context_t *cc, dbe_table_t *tb, int op)
{
  query_t *qr = NULL;
  caddr_t err = NULL;
  client_connection_t *cli = sqlc_client();
  static char *create_trigger_mask[] = {
      "create trigger \"__%s_PI\" before update on \"%s\".\"%s\".\"%s\" referencing OLD as __oo {\n"
      "if (not (%s))\n"
      "  signal ('42000', 'Update of %s prevented by policy', 'SR379');\n"
      "}",
      "create trigger \"__%s_PU\" before insert on \"%s\".\"%s\".\"%s\" {\n"
      "if (not (%s))\n"
      "  signal ('42000', 'Insert in %s prevented by policy', 'SR380');\n"
      "}",
      "create trigger \"__%s_PD\" before delete on \"%s\".\"%s\".\"%s\" {\n"
      "if (not (%s))\n"
      "  signal ('42000', 'Delete from %s prevented by policy', 'SR381');\n"
      "}"
  };

  if (op != TB_RLS_U && op != TB_RLS_I && op != TB_RLS_D)
    return NULL;

  if (tb->tb_rls_procs[op] &&
      cli->cli_user && !sec_user_has_group (0, cli->cli_user->usr_g_id))
    {
      caddr_t ret_val;
      caddr_t sql = NULL;
      query_t *proc_qr = sch_proc_def (isp_schema (NULL), tb->tb_rls_procs[op]);

      ret_val = sqlc_rls_get_condition_string (tb, op, &err);
      if (!err)
	{
	  sql = dk_alloc_box (strlen (create_trigger_mask[op]) +
	      3 * strlen (tb->tb_name) +
	      strlen (ret_val) + 1, DV_SHORT_STRING);
	  snprintf (sql, box_length (sql) - 1, create_trigger_mask[op],
	      tb->tb_name, tb->tb_qualifier, tb->tb_owner, tb->tb_name_only,
	      ret_val, tb->tb_name);
	  dk_free_tree (ret_val);

	  qr = sql_compile_1 (sql, cli, &err, SQLC_DO_NOT_STORE_PROC, NULL, proc_qr->qr_proc_name);
	  dk_free_box (sql);

	  dk_set_delete (&tb->tb_triggers->trig_list, qr);
	}

      sqlc_set_client (cli);
    }

  if (err)
    {
      if (DV_TYPE_OF (err) == DV_ARRAY_OF_POINTER)
	{
	  char temp[1000];
	  char state[10];
	  snprintf (temp, sizeof (temp), "row level security: %.900s", ((char **) err)[2]);
	  strncpy (state, ((char **) err)[1], sizeof (state));
	  dk_free_tree (err);
	  sqlc_new_error (cc, state, "SQ192", temp);
	}
      else
	sqlc_resignal_1 (cc, err);
    }
/* not in subq, free in xx_free
  if (qr)
    dk_set_push (&cc->cc_query->qr_subq_queries, qr);
*/
  return qr;
}


void
sqlc_ins_fetch (sql_comp_t * sc, insert_node_t * ins, ST * fetch, dk_set_t * code)
{
  ins_key_t * ik;
  int inx;
  ST * col = (ST*)fetch->_.op.arg_1;
  ST * seq = (ST*)fetch->_.op.arg_2;
  ST * flag = (ST*)fetch->_.op.arg_3;
  ins->ins_seq_val = scalar_exp_generate (sc, col, code);
  ins->ins_seq_name = scalar_exp_generate (sc, seq, code);
  ins->ins_fetch_flag = scalar_exp_generate (sc, flag, code);
  ik = ins->ins_keys[0];
  DO_BOX (state_slot_t *, ssl, inx, ik->ik_slots)
    {
      if (IS_BLOB_DTP (ik->ik_cols[inx]->col_sqt.sqt_col_dtp))
	sqlc_new_error (sc->sc_cc, "42000", "FNBLO", "Insert - fetch not applicable with a key with blobs");
      if (ssl == ins->ins_seq_val)
	ins->ins_seq_col = ik->ik_cols[inx];
    }
  END_DO_BOX;
  if (!ins->ins_seq_col)
    sqlc_new_error (sc->sc_cc, "42000", ".....", "insert with fetch option has no fetch column in values");
}


ST *
sqlc_ins_del_val (sql_comp_t * sc, insert_node_t * ins, int inx)
{
  char str[20];
  t_NEW_VARZ (col_ref_rec_t, crr);
  crr->crr_ssl = (state_slot_t*)dk_set_nth (ins->ins_values, inx);
  snprintf (str, sizeof (str),  "del %d", inx);
  t_set_push (&sc->sc_col_ref_recs, (void *) crr);
  return crr->crr_col_ref = (ST *) t_list (3, COL_DOTTED, NULL, t_box_string (str));
}


void
sqlc_insert (sql_comp_t * sc, ST * tree)
{
  ST * fetch;
  caddr_t * opts;
  ST * tb_ref = tree->_.insert.table;
  ST * vd;
  dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema,
      tb_ref->_.table.name);
  sqlc_table_used (sc, tb);
  if (tb && find_remote_table (tb->tb_name, 0))
    {
    }
  if (!tb)
    sqlc_new_error (sc->sc_cc, "42S02", "SQ096", "No table %.300s.",
		tree->_.insert.table->_.table.name);

  if (!sec_tb_check (tb, (oid_t) unbox (tb_ref->_.table.g_id), (oid_t) unbox (tb_ref->_.table.u_id), GR_INSERT)
      || (tree->_.insert.mode == INS_REPLACING &&
	  !sec_tb_check (tb, SC_G_ID (sc), SC_U_ID (sc), GR_DELETE)))
    sqlc_new_error (sc->sc_cc, "42000", "SQ097",
	"No insert or insert/delete permission for insert / insert replacing in table %.300s (user ID = %lu)",
        tb->tb_name, SC_U_ID (sc) );

  if (INS_REPLACING == tree->_.insert.mode)
    {
      /* if no dependent part, ins replacing becomes ins soft */
      dbe_key_t * key = tree->_.insert.key ? tb_find_key (tb, tree->_.insert.key, 0) : tb->tb_primary_key;
      if (key && key->key_n_significant == dk_set_length (key->key_parts))
	tree->_.insert.mode = INS_SOFT;
    }

  if (!tree->_.insert.cols)
    tree->_.insert.cols = (ST **) ins_tb_all_cols (tb);
  if ((vd = (ST *)sch_view_def (wi_inst.wi_schema, tb->tb_name)) &&
      !tb_is_trig_at (tb, TRIG_INSERT, TRIG_INSTEAD, NULL))
    {
      sqlc_insert_view (sc, vd, tree, tb);
      return;
    }

  {
      dk_set_t slots = NULL;
      int inx;
      state_slot_t **slots_ret;
      dk_set_t code = NULL;
      oid_t *col_ids;
      SQL_NODE_INIT (insert_node_t, ins, insert_node_input, ins_free);

      col_ids = (oid_t *) box_copy ((caddr_t) tree->_.insert.cols);
      ins->ins_mode = (int) tree->_.insert.mode;
      ins->ins_table = tb;
      ins->ins_policy_qr = sqlc_make_policy_trig (sc->sc_cc, tb, TB_RLS_I);
      ins->ins_key_only = box_copy (tree->_.insert.key);
      DO_BOX (caddr_t, col_name, inx, tree->_.insert.cols)
      {
	dbe_column_t *col = tb_name_to_column_misc (tb, col_name);
	if (!col)
	  sqlc_new_error (sc->sc_cc, "42S22", "SQ098", "No column %s.", col_name);

	col_ids[inx] = col->col_id;
      }
      END_DO_BOX;
      ins->ins_col_ids = col_ids;

      if (ST_P (tree->_.insert.vals, SELECT_STMT))
	{
	  ST *sel = tree->_.insert.vals;
	  if (sc->sc_client->cli_row_autocommit || enable_mt_txn)
	    sc->sc_parallel_dml = 1;
	  sc->sc_cc->cc_query->qr_is_mt_insert = 1;
	  sqlc_top_select_dt (sc, sel);
	  sc->sc_is_update = SC_UPD_INS;
	  sc->sc_no_current_of = 1;
	    sqlo_query_spec (sc, SEL_IS_DISTINCT (sel),
		sel->_.select_stmt.selection,
		sel->_.select_stmt.table_exp,
		&sc->sc_cc->cc_query->qr_head_node,
		&slots_ret);
	  sql_node_append (&sc->sc_cc->cc_query->qr_head_node,
	      (data_source_t *) ins);
	  DO_BOX (state_slot_t *, sl, inx, slots_ret)
	  {
	    slots = NCONC (slots, CONS (sl, NULL));
	  }
	  END_DO_BOX;
	  dk_free_box ((caddr_t) slots_ret);
	}
      else
	{
	  ST **vals = tree->_.insert.vals->_.ins_vals.vals;
	  SC_NO_EXCEPT (sc);
	  DO_BOX (ST *, exp, inx, vals)
	  {
	    sqlc_mark_pred_deps (sc, NULL, exp);
	    slots = NCONC (slots, CONS (scalar_exp_generate (sc, exp, &code),
		NULL));
	  }
	  END_DO_BOX;
	  SC_OLD_EXCEPT (sc);
	  sc->sc_cc->cc_query->qr_head_node = (data_source_t *) ins;
	}
      ins->ins_values = slots;
      opts = tree ? tree->_.insert.opts : NULL;
      if (!sqlo_opt_value (opts, OPT_NO_IDENTITY))
      sqlc_insert_autoincrements (sc, ins, &code);
      if (!sqlo_opt_value (opts, OPT_NO_TRIGGER))
	sqlc_ins_triggers (sc, ins, &code);
      if (dk_set_length (ins->ins_values) != BOX_ELEMENTS (ins->ins_col_ids))
	sqlc_new_error (sc->sc_cc, "21S01", "SQ099",
	    "different number of cols and values in insert.");
      if (TB_MAX_COLS <= dk_set_length (ins->ins_table->tb_primary_key->key_parts))
	sqlc_new_error (sc->sc_cc, "42000", "SQ100",
	    "A local table of over maximum columns may not be inserted");
      sqlc_ins_param_types (sc, ins);
      sqlc_ins_keys (sc->sc_cc, ins);
      sqlg_cl_insert (sc, sc->sc_cc, ins, tree, &code);
      if (sqlo_opt_value (opts, OPT_VECTORED)
	  && !sc->sc_cc->cc_query->qr_proc_vectored)
	sc->sc_cc->cc_query->qr_proc_vectored = QR_VEC_STMT;

      fetch = (ST*)sqlo_opt_value (opts, OPT_INS_FETCH);
      if (fetch)
	sqlc_ins_fetch (sc, ins, fetch, &code);
      sqlc_code_dpipe (sc, &code);
      ins->src_gen.src_pre_code = code_to_cv (sc, code);
      if (INS_REPLACING == ins->ins_mode && sc->sc_cc->cc_query->qr_proc_vectored)
	{
	  /* make a delete node */
	  dk_set_t save_crr = sc->sc_col_ref_recs;
	  static int del_inx;
	  char tmp[MAX_NAME_LEN];
	  state_slot_t * save_set_no = sc->sc_set_no_ssl;
	  ST * delete, * where = NULL;
          dbe_key_t * key = ins->ins_key_only ? ins->ins_keys[0]->ik_key : ins->ins_table->tb_primary_key;
	  data_source_t * top = sc->sc_cc->cc_query->qr_head_node;
	  dk_set_t pars, del_pars;
	  snprintf (tmp, sizeof (tmp), "del__%d", del_inx++);
	  DO_BOX (caddr_t, col_name, inx, tree->_.insert.cols)
	    {
	      dbe_column_t *col = tb_name_to_column_misc (tb, col_name);
	      if (cl_list_find (key->key_key_fixed, col->col_id) || cl_list_find (key->key_key_var, col->col_id))
		{
		  ST * test;
		  ST * val = sqlc_ins_del_val (sc, ins,  inx);
		  BIN_OP (test, BOP_EQ,
			  (ST *) t_list (3, COL_DOTTED, t_sqlp_box_id_upcase (tmp), t_box_string (col->col_name)), val);
		  if (!where)
		    where = test;
		  else
		    {
		      ST * tmp = where;
		      BIN_OP (where, BOP_AND, tmp, test);
		    }
		}
	    }
	  END_DO_BOX;

	  delete = t_listst (2, DELETE_SRC, sqlp_infoschema_redirect (t_listst (9, TABLE_EXP,
		  t_list (1,
		    t_listbox (6, TABLE_DOTTED, t_box_string (ins->ins_table->tb_name), t_sqlp_box_id_upcase (tmp),
		      sqlp_view_u_id (), sqlp_view_g_id (), ins->ins_key_only ? t_list (2, OPT_INDEX, t_box_string (ins->ins_key_only)) : NULL /* table opt */) /* table */),
		  where, NULL, NULL, NULL, NULL,
		  ins->ins_key_only ? t_list (2, OPT_INDEX, t_box_string (ins->ins_key_only)) : NULL /* sql opt */, NULL)));
	  sc->sc_cc->cc_query->qr_head_node = NULL;
	  pars = sc->sc_cc->cc_query->qr_parms;
	  sc->sc_cc->cc_query->qr_parms = NULL;
	  sc->sc_set_no_ssl = NULL;
	  sqlc_delete_searched (sc, delete);
	  sc->sc_set_no_ssl = save_set_no;
	  ins->ins_del_node = sc->sc_cc->cc_query->qr_head_node;
	  sc->sc_cc->cc_query->qr_head_node = top;
	  del_pars = sc->sc_cc->cc_query->qr_parms;
	  sc->sc_cc->cc_query->qr_parms = pars;
	  sc->sc_col_ref_recs = save_crr;
	}
  }
}


state_slot_t *
sqlc_make_co_node (sql_comp_t * sc, char *cr_name, dbe_table_t * tb)
{
  if (!sc->sc_super)
    {
      SQL_NODE_INIT (current_of_node_t, co, current_of_node_input, NULL);
      co->co_cursor_name = ssl_new_constant (sc->sc_cc, cr_name);
      co->co_place = ssl_new_placeholder (sc->sc_cc, "place");
      co->co_table = tb;
      sc->sc_cc->cc_query->qr_head_node = (data_source_t *) co;
      dk_set_push (&sc->sc_cc->cc_query->qr_used_cursors, box_string (cr_name));
      return (co->co_place);
    }
  else
    SQL_GPF_T (sc->sc_cc);			/* current of in procs not done yet */
  return NULL;
}


void
upd_add_auto_updates (dbe_table_t * tb, ST * tree)
{
  dk_set_t ts_cols = NULL;
  dk_set_t ts_cols_pos = NULL;
  ptrlong inx;
  int in_list;

  DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
  {
    if (col->col_sqt.sqt_col_dtp == DV_TIMESTAMP)
      {
	in_list = 0;
	DO_BOX (caddr_t, col_name, inx, tree->_.update_src.cols)
	  {
	    dbe_column_t *col1 = tb_name_to_column_misc (tb, col_name);
	    if (col1 == col)
	      {
		in_list = 1;
		t_set_push (&ts_cols_pos, (void *) inx);
		break;
	      }
	  }
	END_DO_BOX;
	if (!in_list)
	  t_set_push (&ts_cols, (caddr_t) col);
      }
  }
  END_DO_SET ();
  if (ts_cols || ts_cols_pos)
    {
      int n_ts_cols = dk_set_length (ts_cols);
      int n_cols = BOX_ELEMENTS (tree->_.update_pos.cols);

      ST **new_vals =
	  (ST **) t_alloc_box ((n_cols + n_ts_cols) * sizeof (caddr_t),
				DV_ARRAY_OF_POINTER);
      ST **new_cols =
	  (ST **) t_alloc_box ((n_cols + n_ts_cols) * sizeof (caddr_t),
				DV_ARRAY_OF_POINTER);
      memcpy (new_cols, tree->_.update_pos.cols,
	  box_length ((caddr_t) tree->_.update_pos.cols));
      memcpy (new_vals, tree->_.update_pos.vals,
	  box_length ((caddr_t) tree->_.update_pos.vals));
      DO_SET (ptrlong, col_pos, &ts_cols_pos)
	{
	  new_vals[col_pos] = (ST *) t_list (3, CALL_STMT,
	    t_sqlp_box_id_upcase ("get_timestamp"), t_list (0));
	}
      END_DO_SET ();
      DO_SET (dbe_column_t *, col, &ts_cols)
      {
	new_vals[n_cols] = (ST *) t_list (3, CALL_STMT,
	    t_sqlp_box_id_upcase ("get_timestamp"), t_list (0));
	new_cols[n_cols++] = (ST *) t_box_string (col->col_name);
      }
      END_DO_SET ();
/*      dk_free_box ((caddr_t) tree->_.update_pos.cols);
      dk_free_box ((caddr_t) tree->_.update_pos.vals);*/
      tree->_.update_pos.cols = new_cols;
      tree->_.update_pos.vals = new_vals;
    }
}

int dtp_is_fixed (dtp_t dtp);
int dtp_is_var (dtp_t dtp);

void
upd_optimize (sql_comp_t *sc, update_node_t * upd)
{
  dk_set_t fixed_cls = NULL, fixed_vals = NULL;
  dk_set_t var_cls = NULL, var_vals = NULL;
  dbe_schema_t * sch = wi_inst.wi_schema;
  dbe_key_t *key = upd->upd_table->tb_primary_key;
  /*dbe_column_t * col;*/
  int inx = 0;
  if (UPD_MAX_QUICK_COLS < dk_set_length (upd->upd_table->tb_primary_key->key_parts))
    return;
  DO_BOX (ptrlong, cid, inx, upd->upd_col_ids)
    {
      dbe_column_t * col = sch_id_to_column (sch, (oid_t) cid);
      if (CC_NONE != key_find_cl (upd->upd_table->tb_primary_key, col->col_id)->cl_compression
	  || col->col_is_key_part
	  || (upd->upd_table->tb_any_blobs && dtp_is_var (col->col_sqt.sqt_dtp)))
	{
	  dk_set_free (fixed_cls);
	  dk_set_free (var_cls);
	  dk_set_free (fixed_vals);
	  dk_set_free (var_vals);
	  return;
	}
      if (dtp_is_fixed (col->col_sqt.sqt_dtp))
	{
	  dk_set_push (&fixed_cls, (void*) key_find_cl (key, (oid_t) cid));
	  dk_set_push (&fixed_vals, upd->upd_values[inx]);
	}
      else
	{
	  dk_set_push (&var_cls, (void*) key_find_cl (key, (oid_t) cid));
	  dk_set_push (&var_vals, upd->upd_values[inx]);
	}
    }
  END_DO_BOX;
  upd->upd_exact_key = key->key_id;
  upd->upd_fixed_cl = (dbe_col_loc_t **) list_to_array (dk_set_nreverse (fixed_cls));
  upd->upd_var_cl = (dbe_col_loc_t **) list_to_array (dk_set_nreverse (var_cls));
  upd->upd_quick_values = (state_slot_t**) list_to_array (dk_set_conc (dk_set_nreverse (fixed_vals), dk_set_nreverse (var_vals)));
}


void
pl_source_free (pl_source_t * pls)
{
  dk_free_box ((caddr_t) pls->pls_values);
}


void
sqlc_pl_selection (sql_comp_t * sc, dbe_table_t * tb, state_slot_t * place,
    ST ** exps, state_slot_t *** slots_ret)
{
  /* like sqlc_query_exp is for searched upd / del, this is for positioned */
  int inx;
  dk_set_t local_crr;
  dk_set_t code = NULL;
  int n_out = BOX_ELEMENTS (exps);
  state_slot_t **slots;
  dk_set_t org_scope = sc->sc_col_ref_recs;
  DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
  {
    state_slot_t *sl = ssl_new_column (sc->sc_cc, col->col_name, col);
    t_NEW_VARZ (col_ref_rec_t, crr);
    crr->crr_ssl = sl;
    crr->crr_col_ref = (ST *) t_list (3, COL_DOTTED, NULL,
	t_box_string (col->col_name));
    sqlc_temp_tree (sc, (caddr_t) crr->crr_col_ref);
    t_set_push (&sc->sc_col_ref_recs, (void *) crr);
  }
  END_DO_SET ();

  slots = (state_slot_t **) dk_alloc_box (
      sizeof (caddr_t) * n_out, DV_ARRAY_OF_POINTER);
  DO_BOX (ST *, exp, inx, exps)
  {
    slots[inx] = scalar_exp_generate (sc, exp, &code);
  }
  END_DO_BOX;
  *slots_ret = slots;
  {
    SQL_NODE_INIT (pl_source_t, pls, pl_source_input, pl_source_free);
    pls->pls_place = place;
    pls->pls_values = (state_slot_t **) box_copy ((caddr_t) slots);
    pls->pls_table = tb;

    local_crr = sc->sc_col_ref_recs;
/*    while (local_crr != org_scope)
      {
	dk_set_t next = local_crr->next;
	dk_free (local_crr->data, -1);
	dk_free ((void *) local_crr, -1);
	local_crr = next;
      }*/
    sc->sc_col_ref_recs = org_scope;

    pls->src_gen.src_after_code = code_to_cv (sc, code);
    sql_node_append (&sc->sc_cc->cc_query->qr_head_node,
	(data_source_t *) pls);
  }
}


void
sqlc_update_pos_selection (sql_comp_t * sc, trig_cols_t * tc,
    state_slot_t *** slots_ret, state_slot_t * place, dk_set_t * code)
{
  int inx;
  if (tc->tc_is_trigger)
    {
      sqlc_pl_selection (sc, tc->tc_table, place, tc->tc_selection, slots_ret);
    }
  else
    {
      state_slot_t **slots = (state_slot_t **) box_copy ((caddr_t) tc->tc_vals);
      *slots_ret = slots;
      DO_BOX (ST *, exp, inx, tc->tc_vals)
      {
	slots[inx] = scalar_exp_generate (sc, exp, code);
      }
      END_DO_BOX;
    }
}


void
sqlc_upd_param_types (sql_comp_t * sc, update_node_t * upd)
{
  int inx;
  if (!upd->upd_values)
    return;
  DO_BOX (oid_t, col_id, inx, upd->upd_col_ids)
    {
      state_slot_t * ssl = upd->upd_values[inx];
      state_slot_t lsl;
      dbe_column_t * col = sch_id_to_col (wi_inst.wi_schema, col_id);
      memset (&lsl, 0, sizeof (state_slot_t));
      lsl.ssl_name = col->col_name;
      lsl.ssl_column = col;
      lsl.ssl_type = SSL_COLUMN;
      lsl.ssl_sqt = col->col_sqt;

      cv_bop_params (&lsl, ssl, "UPDATE");
    }
  END_DO_BOX;
}


int
tb_is_key (dbe_table_t * tb, dbe_column_t * col)
{
  DO_SET (dbe_key_t *, key, &tb->tb_keys)
    {
      if (!key->key_is_primary && dk_set_member (key->key_parts, (void*)col))
	return 1;
    }
  END_DO_SET ();
  return 0;
}


state_slot_t **
upd_value_slots (trig_cols_t * tc, state_slot_t ** slots)
{
  dbe_key_t * pk = tc->tc_table->tb_primary_key;
  int nth = 0;
  int inx;
  state_slot_t **vslots = (state_slot_t **) box_copy ((caddr_t) tc->tc_vals);
  DO_BOX (caddr_t, cname, inx, tc->tc_cols)
  {
    vslots[inx] = slots[tc_new_value_inx (tc, cname)];
  }
  END_DO_BOX;
  DO_SET (dbe_column_t *, col, &pk->key_parts)
    {
      if (nth < pk->key_n_significant
	  || IS_BLOB_DTP (col->col_sqt.sqt_dtp)
	  || tb_is_key (tc->tc_table, col))
	vslots = (state_slot_t**) box_append_1_free ((caddr_t)vslots, (caddr_t)slots[tc_pk_value_inx (tc, col->col_name)]);
      nth++;
    }
  END_DO_SET();
  return vslots;
}


int upd_hi_id_ctr = 0; /* running no of update nodes.  More unique than the pointer. Must be unique for all distinct update nodes of a transaction */


ST *
sqlc_update_cl_pos (sql_comp_t * sc, ST * tree, subq_compilation_t * sqc)
{
  ST * texp, * stree;
  dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema,
				       tree->_.update_pos.table->_.table.name);

  if (!sqc)
    sqlc_new_error (sc->sc_cc, "37000", "CL...", "current of ref allowed only in PL with partitioned tables");
  if (sqc && tb != sqc->sqc_remote_co_table)
    sqlc_new_error (sc->sc_cc, "42S02", "VD040", "Ref to wrong table in remote current of ");
  texp = sqlp_infoschema_redirect (t_listst (9, TABLE_EXP,
						 t_list (1, t_box_copy_tree ((caddr_t) tree->_.update_pos.table)),
						 sqlc_pos_to_searched_where (sc, sqc, tree->_.update_pos.cursor, tb), NULL, NULL, NULL, NULL,NULL, NULL));
  stree = (ST *) t_list (5, UPDATE_SRC,
			     t_box_copy_tree ((caddr_t) tree->_.update_pos.table),
			     t_box_copy_tree ((caddr_t) tree->_.update_pos.cols),
			     t_box_copy_tree ((caddr_t) tree->_.update_pos.vals),
			     texp);

  return stree;
}


void
sqlc_update_pos (sql_comp_t * sc, ST * tree, subq_compilation_t * cursor_sqc, ST ** src_ret)
{
  dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema,
      tree->_.update_pos.table->_.table.name);
  sqlc_table_used (sc, tb);
  if (tb && (tb->tb_primary_key->key_is_col || find_remote_table (tb->tb_name, 0) || (tb->tb_primary_key->key_partition && !sqlo_opt_value (tree->_.update_pos.opts, OPT_NO_CLUSTER))))
    {
      if (!src_ret)
	sqlc_new_error (sc->sc_cc, "37000", "NOPOS", "Positioned statement not allowed only in procedures");
      *src_ret = sqlc_update_cl_pos (sc, tree, cursor_sqc);
      return;
    }
  else
    {
      trig_cols_t tc;
      int sec_checked = 0;
      dk_set_t code = NULL;
      int inx;
      oid_t *col_ids;
      state_slot_t **vals;
      SQL_NODE_INIT (update_node_t, upd, update_node_input, upd_free);
      upd->upd_hi_id = upd_hi_id_ctr++;
      if (!tb)
	sqlc_new_error (sc->sc_cc, "42S02", "SQ101", "No table %s.", tree->_.insert.table);

      upd->upd_table = tb;
      sec_checked = sec_tb_check (tb, SC_G_ID (sc), SC_U_ID (sc), GR_UPDATE);
      upd->upd_policy_qr = sqlc_make_policy_trig (sc->sc_cc, tb, TB_RLS_U);
      upd_add_auto_updates (tb, tree);
      col_ids = (oid_t *) box_copy ((caddr_t) tree->_.update_pos.cols);
      box_tag_modify (col_ids, DV_ARRAY_OF_LONG);
      DO_BOX (caddr_t, col_name, inx, tree->_.update_pos.cols)
      {
	dbe_column_t *col = tb_name_to_column_misc (tb, col_name);
	if (!col)
	  sqlc_new_error (sc->sc_cc, "42S22", "SQ102", "No column %.100s in table %.300s", col_name, tb->tb_name);

	if (!sec_checked &&
	    !sec_col_check (col, SC_G_ID (sc), SC_U_ID (sc), GR_UPDATE))
	  sqlc_new_error (sc->sc_cc,
	      "42000", "SQ103:SECURITY", "Update of column %.100s of table %.300s is not allowed (user ID = %lu)",
              col->col_name, tb->tb_name, (long)(SC_U_ID (sc)) );
	col_ids[inx] = col->col_id;
      }
      END_DO_BOX;
      upd->upd_col_ids = col_ids;

      upd->upd_place = cursor_sqc
	  ? cursor_sqc->sqc_ssl
	  : sqlc_make_co_node (sc, tree->_.update_pos.cursor, tb);

      if (!upd->upd_place)
	sqlc_new_error (sc->sc_cc, "09000", "SQ104",
	    "Cursor with a sorted order by, distinct, grouping etc. "
	    "is not referenceable in 'update %.200s ... where current of ...'", tb->tb_name );
      SC_NO_EXCEPT (sc);

      tc_init (&tc, TRIG_UPDATE, tb,
	  (caddr_t *) tree->_.update_pos.cols, tree->_.update_pos.vals, NULL);
      sqlc_update_pos_selection (sc, &tc, &vals, upd->upd_place, &code);
      if (tc.tc_is_trigger)
	{
	  sqlc_trig_const_params (sc, vals, &code);
	  upd->upd_values = upd_value_slots (&tc, vals);
	  upd->upd_trigger_args = vals;
	}
      else
	{
	  upd->upd_values = vals;
	}

      SC_OLD_EXCEPT (sc);
      sql_node_append (&sc->sc_cc->cc_query->qr_head_node,
	  (data_source_t *) upd);
      upd->src_gen.src_pre_code = code_to_cv (sc, code);
      sqlc_upd_param_types (sc, upd);
      upd_optimize (sc, upd);
      tc_free (&tc);
    }
}


state_slot_t *
sqlc_co_place (sql_comp_t * sc)
{
  /* in searched update / delete, there's one table source.
     Get its current of */
  comp_table_t *ct = sc->sc_tables[0];
  return (ct->ct_ts->ts_current_of);
}


int sqlc_no_remote_pk = 0;
#define SUITABLE_FOR_NO_PK(tb,event) \
  (!tb_is_trig (tb, event, NULL))

#define LOG_FOR_NO_PK(tb,event) \
    log_warning ("Tried compiling remote %s on attached table %s, but %s. Reverting to the normal compilation. " \
	"Disable the parameter SkipDMLPrimaryKey or avoid the above action.", \
	event, tb, \
	  "there are local triggers defined on the table")


void
sqlc_update_set_keyset (sql_comp_t * sc, table_source_t * ts)
{
  /* in searched update / delete, there's one table source. */
  update_node_t * upd = sc->sc_update_keyset;
  int part_no = 0, inx;
  dbe_key_t * key = ts->ts_order_ks ? ts->ts_order_ks->ks_key : NULL;
  if (IS_QN (ts, table_source_input_unique))
    {
      sc->sc_update_keyset = NULL;
      return;
    }
  if (!key || !upd || key->key_no_pk_ref)
    {
      sc->sc_update_keyset = NULL;
      return;
    }
  DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      DO_BOX (ptrlong, cid, inx, upd->upd_col_ids)
	{
	  if (cid == col->col_id)
	    {
	      upd->upd_keyset = 1;
	      return;
	    }
	}
      END_DO_BOX;
      part_no++;
      if (part_no >= key->key_n_significant)
	break;
    }
  END_DO_SET ();
  sc->sc_update_keyset = NULL;
}


void
sqlc_update_searched (sql_comp_t * sc, ST * tree)
{
  state_slot_t **slots;
  trig_cols_t tc;
  ST *vd;
  caddr_t * opts = tree->_.update_src.table_exp->_.table_exp.opts;
  int trig_event = sqlo_opt_value (opts, OPT_NO_TRIGGER) ? -1 : TRIG_UPDATE;
  int inx, sec_checked, env_done = 0;
  ST * tb_ref = tree->_.update_src.table;
  dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema,
      tree->_.update_src.table->_.table.name);
  sqlc_table_used (sc, tb);
  if (tb && find_remote_table (tb->tb_name, 0))
    {
    }
  else if (tb && (vd = (ST *) sch_view_def (wi_inst.wi_schema, tb->tb_name)) &&
      !tb_is_trig_at (tb, TRIG_UPDATE, TRIG_INSTEAD, NULL))
    {
      sqlc_update_view (sc, vd, tree, tb);
    }
  else
    {
      oid_t *col_ids;
      dk_set_t col_set = NULL;
      SQL_NODE_INIT (update_node_t, upd, update_node_input, upd_free);
      upd->upd_hi_id = upd_hi_id_ctr++;
      if (!tb)
	sqlc_new_error (sc->sc_cc, "42S02", "SQ105",
	    "No table %.300s.", tree->_.update_src.table->_.table.name);

      upd->upd_table = tb;

      sec_checked = sec_tb_check (tb, (oid_t) unbox (tb_ref->_.table.g_id),
				  (oid_t) unbox (tb_ref->_.table.u_id), GR_UPDATE);
      upd->upd_policy_qr = sqlc_make_policy_trig (sc->sc_cc, tb, TB_RLS_U);
      if (!sqlo_opt_value (opts, OPT_NO_IDENTITY))
      upd_add_auto_updates (tb, tree);
      col_ids = (oid_t *) box_copy ((caddr_t) tree->_.update_src.cols);
      box_tag_modify (col_ids, DV_ARRAY_OF_LONG);
      DO_BOX (caddr_t, col_name, inx, tree->_.update_src.cols)
      {
	dbe_column_t *col = tb_name_to_column_misc (tb, col_name);
	if (!col)
	  {
	    dk_free_box ((caddr_t) col_ids);
	    sqlc_new_error (sc->sc_cc, "42S22", "SQ106", "No column %.100s in table %.300s", col_name, tb->tb_name);
	  }
	if (dk_set_member (col_set, col))
	  {
	    dk_free_box ((caddr_t) col_ids);
	    sqlc_new_error (sc->sc_cc, "42S22", "SQ174",
		"Column %.100s specified more than once in the update statement on table %.300s", col_name, tb->tb_name);
	  }
	else
	  t_set_push (&col_set, col);
	if (!sec_checked &&
	    !sec_col_check (col, (oid_t) unbox (tb_ref->_.table.g_id),
			    (oid_t) unbox (tb_ref->_.table.u_id), GR_UPDATE))
	  {
	    dk_free_box ((caddr_t) col_ids);
	    sqlc_new_error (sc->sc_cc,
		"42000", "SQ107:SECURITY", "Update of column %.100s of table %.300s not allowed (user ID = %lu)",
                col->col_name, tb->tb_name, (long) unbox (tb_ref->_.table.u_id) );
	  }
	col_ids[inx] = col->col_id;
      }
      END_DO_BOX;
      upd->upd_col_ids = col_ids;

      sc->sc_in_cursor_def = 1;
      /*
	 Note that the ssl of the upd_place is the alias ssl of the order_itc

	 This must not be.  Make it so that the ts_current_of is not aliased to the
	 ts_order_itc if we have this kind of update. Sqlcomp2.c.  Put a flag for
	 this in sql_comp_t, set it in sqlc_update_searched.  Like this you  know
	 when not to alias this.
       */
      tc_init (&tc, trig_event, tb,
	  (caddr_t*) tree->_.update_src.cols, tree->_.update_src.vals, NULL);
      sc->sc_cc->cc_query->qr_lock_mode = PL_EXCLUSIVE;
      sc->sc_is_update = SC_UPD_PLACE;
      sc->sc_parallel_dml = enable_mt_txn;
      sc->sc_need_pk = 1;
      sc->sc_update_keyset = upd;
      sqlo_query_spec (sc, 0,
	  (caddr_t *) tc.tc_selection,
	  tree->_.update_src.table_exp,
	  &sc->sc_cc->cc_query->qr_head_node,
	  &slots);
      sc->sc_is_update = 0;
      sc->sc_need_pk = 0;
      sc->sc_in_cursor_def = 0;
      if (!tc.tc_is_trigger)
	upd->upd_values = slots;
      else
	{
	  dk_set_t code = NULL;
	  sqlc_trig_const_params (sc, slots, &code);
	  upd->upd_values = upd_value_slots (&tc, slots);
	  upd->upd_trigger_args = slots;
	  upd->src_gen.src_pre_code = code_to_cv (sc, code);
       }
      tc_free (&tc);

      if (upd->upd_keyset)
	upd->upd_keyset_state = ssl_new_variable (sc->sc_cc, "keyset_state", DV_ARRAY_OF_POINTER);
      upd->upd_place = sqlo_co_place (sc);
	sql_node_append (&sc->sc_cc->cc_query->qr_head_node,
			 (data_source_t *) upd);
      sqlc_upd_param_types (sc, upd);
      upd_optimize (sc, upd);
      if (!env_done)
	sqlg_qr_env (sc, sc->sc_cc->cc_query);
    }
}


void
del_free (delete_node_t * del)
{
  dk_free_box ((caddr_t) del->del_trigger_args);
  dk_free_box ((caddr_t)del->del_key_vals);
  ik_array_free (del->del_keys);
  qr_free (del->del_policy_qr);
}



ST *
sqlc_delete_cl_pos (sql_comp_t * sc, ST * tree, subq_compilation_t * sqc)
{
  ST * texp, * stree;
  dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema,
				       tree->_.delete_pos.table->_.table.name);
  if (!sqc)
    sqlc_new_error (sc->sc_cc, "37000", "CL...", "current of ref allowed only in PL with partitioned tables");
  if (sqc && tb != sqc->sqc_remote_co_table)
    sqlc_new_error (sc->sc_cc, "42S02", "VD043", "Ref to wrong table in remote current of ");
  texp = sqlp_infoschema_redirect (t_listst (9, TABLE_EXP,
					     t_list (1, t_box_copy_tree ((caddr_t) tree->_.delete_pos.table)),
						 sqlc_pos_to_searched_where (sc, sqc, tree->_.delete_pos.cursor, tb),
						 NULL, NULL, NULL, NULL,NULL, NULL));
  stree = (ST *) t_list (2, DELETE_SRC, texp);
  return stree;
}


void
sqlc_delete_pos (sql_comp_t * sc, ST * tree, subq_compilation_t * cursor_sqc, ST ** src_ret)
{
  dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema,
      tree->_.delete_pos.table->_.table.name);
  sqlc_table_used (sc, tb);
  if (tb && (tb->tb_primary_key->key_is_col || find_remote_table (tb->tb_name, 0) || (tb->tb_primary_key->key_partition && !sqlo_opt_value (tree->_.delete_pos.opts, OPT_NO_CLUSTER))))
    {
      if (!src_ret)
	sqlc_new_error (sc->sc_cc, "37000", "NOPOS", "Positioned statement is allowed only in procedures");
      *src_ret = sqlc_delete_cl_pos (sc, tree, cursor_sqc);
      return;
    }
  else
    {
      trig_cols_t tc;
      SQL_NODE_INIT (delete_node_t, del, delete_node_input, del_free);
      if (tb && !sec_tb_check (tb, SC_G_ID (sc), SC_U_ID (sc), GR_DELETE))
	sqlc_new_error (sc->sc_cc, "43000", "SQ108:SECURITY", "Permission denied for delete from %.300s (user ID = %lu)", tb->tb_name, SC_U_ID (sc));

      del->del_table = tb;
      del->del_policy_qr = sqlc_make_policy_trig (sc->sc_cc, tb, TB_RLS_D);
      del->del_place = cursor_sqc
	? cursor_sqc->sqc_ssl
	  : sqlc_make_co_node (sc, tree->_.delete_pos.cursor, tb);
      if (!del->del_place)
	sqlc_new_error (sc->sc_cc, "09000", "SQ109",
	    "Cursor with a sorted order by, distinct, grouping etc. "
	    "is not referenceable in 'delete from %.200s where current of ...'", tb->tb_name );
      tc_init (&tc, TRIG_DELETE, tb, NULL, NULL, NULL);
      if (tc.tc_is_trigger)
	{
	  dk_set_t code = NULL;
	  state_slot_t ** slots;
	  sqlc_pl_selection (sc, tb, del->del_place, tc.tc_selection, &slots);
	  sqlc_trig_const_params (sc, slots, &code);
	  del->del_trigger_args = slots;
	  del->src_gen.src_pre_code = code_to_cv (sc, code);
	}
      tc_free (&tc);
      sql_node_append (&sc->sc_cc->cc_query->qr_head_node,
	  (data_source_t *) del);
    }
}


dbe_key_t *
sqlc_del_key_only (sql_comp_t * sc, dbe_table_t * tb, ST * texp)
{
  caddr_t kn = sqlo_opt_value (texp->_.table_exp.opts, OPT_INDEX);
  if (kn)
    {
      dbe_key_t * key = tb_key_by_index_opt (tb, kn);
      if (!key)
	sqlc_new_error (sc->sc_cc, "42000", "SR...", "No index %s for single key delete", kn);
      return key;
    }
  return NULL;
}


void
sqlc_delete_searched (sql_comp_t * sc, ST * tree)
{
  trig_cols_t tc;
  ST *vd;
  ST *from = tree->_.delete_src.table_exp->_.table_exp.from[0];
  caddr_t * opts = tree->_.delete_src.table_exp->_.table_exp.opts;
  dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema,
      from->_.table.name);
  int key_trig_event = sqlo_opt_value (opts, OPT_TRIGGER) ? TRIG_DELETE : -1, env_done = 0;
  sqlc_table_used (sc, tb);
  if (tb
      && !sec_tb_check (tb, (oid_t) unbox (from->_.table.g_id), (oid_t) unbox (from->_.table.u_id), GR_DELETE))
    sqlc_new_error (sc->sc_cc, "42000", "SQ110:SECURITY", "Permission denied for delete from %.300s (user ID = %lu)",
        tb->tb_name, (oid_t) unbox (from->_.table.u_id) );

  if (tb && find_remote_table (tb->tb_name, 0))
    {
    }
  else if (tb && (vd = (ST *) sch_view_def (wi_inst.wi_schema, tb->tb_name)) &&
      !tb_is_trig_at (tb, TRIG_DELETE, TRIG_INSTEAD, NULL))
    {
      sqlc_delete_view (sc, vd, tree);
    }
  else
    {
      state_slot_t **slot_array;

      SQL_NODE_INIT (delete_node_t, del, delete_node_input, del_free);
      if (!tb)
	sqlc_new_error (sc->sc_cc, "42S02", "SQ111", "No table %s.", from->_.table.name);

      del->del_table = tb;
      del->del_policy_qr = sqlc_make_policy_trig (sc->sc_cc, tb, TB_RLS_D);
      del->del_key_only = sqlc_del_key_only (sc, del->del_table, tree->_.delete_src.table_exp);
      tc_init (&tc, del->del_key_only ? key_trig_event : TRIG_DELETE, tb, NULL, NULL, sqlg_is_vector ? (del->del_key_only ? del->del_key_only : TC_ALL_KEYS) : 0);
      sc->sc_in_cursor_def = 1;
      sc->sc_cc->cc_query->qr_lock_mode = PL_EXCLUSIVE;
      sc->sc_parallel_dml = enable_mt_txn;
      sc->sc_is_update = SC_UPD_PLACE;
      sqlo_query_spec (sc, 0, (caddr_t *) tc.tc_selection, tree->_.delete_src.table_exp,
	      &sc->sc_cc->cc_query->qr_head_node,
	      &slot_array);
      sc->sc_is_update = 0;
      sc->sc_in_cursor_def = 0;
      del->del_place = sqlo_co_place (sc);
      if (tc.tc_is_trigger)
	{
	  dk_set_t code = NULL;
	  sqlc_trig_const_params (sc, slot_array, &code);
	  del->del_trigger_args = slot_array;
	  del->src_gen.src_pre_code = code_to_cv (sc, code);
	}
      else
	{
	  del->del_key_vals = slot_array;
	}
	sql_node_append (&sc->sc_cc->cc_query->qr_head_node,
			 (data_source_t *) del);
      tc_free (&tc);
      if (!env_done)
	sqlg_qr_env (sc, sc->sc_cc->cc_query);
    }
}


int
ddl_need_schema_reload (ptrlong type)
{
  if (TABLE_DEF == type
      || INDEX_DEF == type
      || TABLE_DROP == type
      || ADD_COLUMN == type
      || TABLE_RENAME == type
      || INDEX_DROP == type
      || VIEW_DEF == type)
    return 1;
  else
    return 0;
}


ST *
sqlc_table_from_select_view (query_t * view_qr, ST * view_def)
{
  int inx;
  /* make a create table with the view's out cols and data types */
  state_slot_t **sel_out = view_qr->qr_select_node->sel_out_slots;
  int n_out = BOX_ELEMENTS (sqlp_union_tree_select (view_def->_.view_def.exp)->_.select_stmt.selection);
  /* length of select list, not out box cause out bpx may have co and extras */
  dk_set_t cols = NULL;
  dk_set_t key_parts = NULL;

  DO_BOX (state_slot_t *, ssl, inx, sel_out)
  {
    dtp_t sl_dtp;
    uint32 sl_prec;
    char sl_scale;
    int col_is_indexable;
    if (inx >= n_out)
      break;			/* only as many as in selection */
    if (SSL_REF == ssl->ssl_type)
      ssl = ((state_slot_ref_t*)ssl)->sslr_ssl;
    sl_dtp = ssl->ssl_dtp;
    sl_prec = ssl->ssl_prec;
    sl_scale = ssl->ssl_scale;

    if (!sl_dtp || !dtp_is_column_compatible (sl_dtp))
      {
	sl_dtp = DV_LONG_STRING;
	sl_prec = 0;
	sl_scale = 0;
      }
    col_is_indexable = !(
      (DV_BLOB == sl_dtp) || (DV_BLOB_WIDE == sl_dtp) ||
      (DV_BLOB_BIN == sl_dtp) || (DV_BLOB_XPER == sl_dtp) );
    t_dk_set_append_1 (&cols, (void *) t_box_string (ssl->ssl_name));
    t_dk_set_append_1 (&cols,
	t_list (2, t_list (3, t_box_num (sl_dtp),
	    t_box_num (sl_prec),
	    t_box_num (sl_scale)),
	    NULL));
    if (col_is_indexable)
      t_dk_set_append_1 (&key_parts, (void *) t_box_string (ssl->ssl_name));
  }
  END_DO_BOX;
  t_dk_set_append_1 (&cols, NULL);
  t_dk_set_append_1 (&cols,
      t_list (5, INDEX_DEF, NULL, NULL, t_list_to_array (key_parts), NULL));

  return ((ST *) t_list (3,
      TABLE_DEF,
      t_box_string (view_def->_.view_def.name),
      t_list_to_array (cols)));
}


ST *
sqlc_table_from_view (query_t * view_qr, ST * view_def)
{
  if (view_qr)
    return (sqlc_table_from_select_view  (view_qr, view_def));
  else
    {
/*GK: enable that if proc view params to participate in 'select *' */
#if 0
      caddr_t *col_defs;
      int inx;
      int n_cols = BOX_ELEMENTS (view_def->_.view_def.exp->_.proc_table.cols);

      col_defs = (caddr_t *) t_alloc_box (
	  n_cols * sizeof (caddr_t) +
	  + 2 * box_length (view_def->_.view_def.exp->_.proc_table.params),
	  DV_ARRAY_OF_POINTER);

      for (inx = 0; inx < n_cols; inx++)
	col_defs[inx] = t_box_copy_tree ((caddr_t) view_def->_.view_def.exp->_.proc_table.cols[inx]);

      DO_BOX (caddr_t, param, inx, view_def->_.view_def.exp->_.proc_table.params)
	{
	  col_defs [n_cols + inx * 2] = t_box_copy_tree (param);
	  /* GK : = ANY */
	  col_defs [n_cols + inx * 2 + 1] =
	      (caddr_t) t_list (2,
		  t_list (2, (long) DV_ANY, (long) 0),
		  NULL);
	}
      END_DO_BOX;
      return ((ST*) t_list (3, TABLE_DEF, t_box_copy_tree (view_def->_.view_def.name),
		    (caddr_t) col_defs));
#else
      return ((ST*) t_list (3, TABLE_DEF, t_box_copy_tree (view_def->_.view_def.name),
		    t_box_copy_tree ((caddr_t) view_def->_.view_def.exp->_.proc_table.cols)));
#endif
    }
}


/********************
 *
 * sqlc_sch_list
 *
 * Make a succession of ddl_node_t's, one from each schema element.
 * The view-def is a special case. It is always alone
 * and it generates 2 nodes: A CREATE_TABLE and a VIEW_DEF.
 */

void
sqlc_sch_list (sql_comp_t * sc, ST * tree)
{
  query_t *view_qr = NULL;
  ST **list = (ST **) tree->_.op.arg_1;
  int inx;
  int n_elts = BOX_ELEMENTS (list);
  if (n_elts == 1 && list[0]->type == VIEW_DEF)
    {
      ST *elt = list[0];
      subq_compilation_t *sqc;
      /* compile the view just for the sake of checking */
      if (!sc->sc_store_procs)
	{
	  dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema,
	      elt->_.view_def.name);
	  if (!tb)
	    sqlc_new_error (sc->sc_cc, "42S02", "SQ112",
		"View without table %s", elt->_.view_def.name);
          sqlo_calculate_subq_view_scope (sc, &elt->_.view_def.exp);
	      sch_set_view_def (wi_inst.wi_schema, elt->_.view_def.name,
	      (caddr_t) elt->_.view_def.exp);
	  return;
	}
      if (!ST_P (elt->_.view_def.exp, PROC_TABLE))
	{
	  ST * copy_exp;
	  /* compile view for checking. Use a copy
	   * because compilation is destructive and you store the source form */
	  copy_exp = (ST *) t_box_copy_tree ((caddr_t) elt->_.view_def.exp);
	  sc->sc_check_view_sec = 1;
	  sqc = sqlc_subquery (sc, NULL, & copy_exp);
	  /*dk_free_tree (copy_exp);*/
	  view_qr = sqc->sqc_query;
	}
    }
#ifdef BIF_XML
  if (XML_VIEW == list[0]->type)
    {
      xml_view_t *xv = (xml_view_t *) list[0];
        char *err = NULL;
        caddr_t schema, user, local_name, full_name;
	full_name = xml_view_name (sc->sc_client, xv->xv_full_name, NULL, NULL, &err, &schema, &user, &local_name);
	if (NULL != err)
	  sqlc_new_error (sc->sc_cc, "42000", "SQ177", "The name '%s' can not be used for an XML view: %s.", xv->xv_full_name, err);
	xv->xv_full_name = full_name;
	xv->xv_schema = schema;
	xv->xv_user = user;
	xv->xv_local_name = local_name;
        mpschema_set_view_def (full_name, box_copy_tree ((caddr_t)xv));
      xmls_set_view_def ((void*) sc, (xml_view_t *) xv);
      if (!sc->sc_store_procs)
	return;
    }
#endif
  DO_BOX (ST *, elt, inx, list)
  {
    SQL_NODE_INIT (ddl_node_t, ddl, ddl_node_input, ddl_free);
    if (elt->type == VIEW_DEF)
      {
	SQL_NODE_INIT (ddl_node_t, tcreate, ddl_node_input, ddl_free);
	tcreate->ddl_stmt = (caddr_t *) box_copy_tree ((box_t) sqlc_table_from_view (view_qr, elt));

	elt->_.view_def.text = t_box_string (sc->sc_text);
	sql_node_append (&sc->sc_cc->cc_query->qr_head_node,
	    (data_source_t *) tcreate);
	ddl->ddl_stmt = (caddr_t *) box_copy_tree ((caddr_t) elt);
      }
    else     if (elt->type == XML_VIEW)
      {
	SQL_NODE_INIT (ddl_node_t, tcreate, ddl_node_input, ddl_free);

	elt->_.view_def.text = t_box_string (sc->sc_text);
	ddl->ddl_stmt = (caddr_t *) box_copy_tree ((caddr_t) elt);
      }
    else if (elt->type == UDT_DEF)
      {
	UST *tree = (UST *) elt;
	sqlc_check_mpu_name (tree->_.type.name, MPU_UDT);

	ddl->ddl_stmt = (caddr_t *) box_copy_tree ((caddr_t) elt);
      }
    else
      ddl->ddl_stmt = (caddr_t *) box_copy_tree ((caddr_t) elt);

    sql_node_append (&sc->sc_cc->cc_query->qr_head_node, (data_source_t *) ddl);
    if (ddl_need_schema_reload (elt->type))
      sc->sc_cc->cc_query->qr_is_ddl = 1;

  }
  END_DO_BOX;
}

