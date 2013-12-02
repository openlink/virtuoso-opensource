/*
 *  sqloinv.c
 *
 *  $Id$
 *
 *  sql inverse functions
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

#include "libutil.h"
#include "Dk.h"

#include "sqlnode.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlo.h"
#include "sqloinv.h"
#include "sqlbif.h"
#include "security.h"
#include "xmlnode.h"
static id_hash_t *sinv_func_hash = NULL;

#define REPORT_ERR(err) \
      if ((err)) \
        { \
	  if (IS_BOX_POINTER (err)) \
	    { \
	      log_error ("Internal error reading the SYS_SQL_INVERSE [%.5s] %.1000s", \
		  ERR_STATE (err), ERR_MESSAGE (err)); \
	      dk_free_tree (err); \
	    } \
	  else \
	    log_error ("Internal error reading the SYS_SQL_INVERSE", \
		ERR_STATE (err), ERR_MESSAGE (err)); \
 	  err = NULL; \
	  call_exit (-1); \
	}


static void
sinvm_free (sinv_map_t * map)
{
  dk_free_tree ((box_t) map->sinvm_name);
  dk_free_tree ((box_t) map->sinvm_inverse);
  dk_free (map, sizeof (sinv_map_t));
}


static sinv_map_t *
sinv_find_func_map (const char *function_name, client_connection_t *cli)
{
  sinv_map_t **old_map = NULL;

  if (!sinv_func_hash)
    return NULL;

  old_map =
      (sinv_map_t **) id_hash_get (sinv_func_hash,
				   (caddr_t) & function_name);
  if (old_map)
    return *old_map;

  if (case_mode == CM_MSSQL)
    {
      char nm[3 * MAX_NAME_LEN + 4], *pnm = &nm[0];
      strncpy (nm, function_name, sizeof (nm) - 1);
      nm[sizeof(nm) - 1] = 0;
      strlwr (nm);
      old_map =
	  (sinv_map_t **) id_hash_get (sinv_func_hash,
				       (caddr_t) & pnm);
    }

  if (old_map)
    return *old_map;
  else
    {
      char *proc_name = sch_full_proc_name (isp_schema (NULL), function_name,
	  cli_qual (cli), CLI_OWNER (cli));
      if (proc_name)
	old_map = (sinv_map_t **) id_hash_get (sinv_func_hash,
	    (caddr_t) &proc_name);
    }

  if (old_map)
    return *old_map;
  else
    return NULL;
}


static void
sinv_make_decoy_procs (client_connection_t * cli, sinv_map_t *map)
{
  dk_session_t * ses = strses_allocate ();
  int inx;
  caddr_t str, err = NULL;


  SES_PRINT (ses, "create procedure \"");
  sprintf_escaped_id (map->sinvm_name, NULL, ses);
  SES_PRINT (ses, "\" (");
  _DO_BOX (inx, map->sinvm_inverse)
    {
      char buf[50];
      if (inx > 0)
	SES_PRINT (ses, ", ");

      sprintf (buf, "in P%d any", inx + 1);
      SES_PRINT (ses, buf);
    }
  END_DO_BOX;

  SES_PRINT (ses, ") { signal ('42000', 'INTERNAL error : inverse fwd decoy function'); }");
  str = strses_string (ses);
  sql_compile (str, cli, &err, SQLC_DO_NOT_STORE_PROC);
  dk_free_tree (str);
  if (IS_BOX_POINTER (err))
    {
      log_error ("Internal error making decoys for the SYS_SQL_INVERSE [%.5s] %.1000s",
	  ERR_STATE (err), ERR_MESSAGE (err));
      dk_free_tree (err);
      err = NULL;
    }
  strses_flush (ses);

  DO_BOX (caddr_t, inverse, inx, map->sinvm_inverse)
    {
      SES_PRINT (ses, "create procedure \"");
      sprintf_escaped_id (inverse, NULL, ses);
      SES_PRINT (ses, "\" (in P any) { signal ('42000', 'INTERNAL error : inverse rev decoy function'); }");
      str = strses_string (ses);
      sql_compile (str, cli, &err, SQLC_DO_NOT_STORE_PROC);
      dk_free_tree (str);
      if (err)
	{
	  log_error ("Internal error making rev decoys for the SYS_SQL_INVERSE [%.5s] %.1000s",
	      ERR_STATE (err), ERR_MESSAGE (err));
	  dk_free_tree (err);
	  err = NULL;
	}
      strses_flush (ses);
    }
  END_DO_BOX;
  dk_free_tree ((box_t) ses);
}


void
sinv_read_sql_inverses (const char * function_name, client_connection_t * cli)
{
  query_t *rd;
  caddr_t err = NULL;
  local_cursor_t *lc;
  sinv_map_t *map = NULL;
  dk_set_t inverse_set = NULL;
  caddr_t sinvm_name;
  caddr_t sinvm_inverse;
  unsigned sinvm_flags;

  if (!sinv_func_hash)
    {
      sinv_func_hash = id_str_hash_create (50);
    }

  if (function_name)
    {
      sinv_map_t *old_map = sinv_find_func_map (function_name, cli);
      if (old_map)
	{
	  id_hash_remove (sinv_func_hash, (caddr_t) & old_map->sinvm_name);
	  sinvm_free (old_map);
	}
    }

  if (function_name)
    {
      rd = sql_compile ("select "
	  "  SINV_FUNCTION, "
	  "  SINV_ARGUMENT, "
	  "  SINV_INVERSE, "
	  "  SINV_FLAGS "
	  " from "
	  "  DB.DBA.SYS_SQL_INVERSE "
	  " where SINV_FUNCTION = ? "
	  " order by SINV_FUNCTION, SINV_ARGUMENT", cli, &err, SQLC_DEFAULT);
      REPORT_ERR (err);

      err = qr_quick_exec (rd, cli, "q", &lc, 1,
	  ":0", function_name, QRP_STR);
      REPORT_ERR (err);
    }
  else
    {
      rd = sql_compile ("select "
	  "  SINV_FUNCTION, "
	  "  SINV_ARGUMENT, "
	  "  SINV_INVERSE, "
	  "  SINV_FLAGS "
	  " from "
	  "  DB.DBA.SYS_SQL_INVERSE "
	  " order by SINV_FUNCTION, SINV_ARGUMENT", cli, &err, SQLC_DEFAULT);
      REPORT_ERR (err);

      err = qr_quick_exec (rd, cli, "q", &lc, 0);
      REPORT_ERR (err);
    }

  while (lc_next (lc))
    {
      sinvm_name = lc_nth_col (lc, 0);
      sinvm_inverse = lc_nth_col (lc, 2);
      sinvm_flags = (unsigned) unbox (lc_nth_col (lc, 3));

      if (!map || CASEMODESTRCMP (map->sinvm_name, sinvm_name))
	{
	  if (map)

	    {
	      map->sinvm_inverse =
		  (caddr_t *) list_to_array (dk_set_nreverse (inverse_set));
	      inverse_set = NULL;
#ifndef NDEBUG
	      if (!map->sinvm_inverse
		  || BOX_ELEMENTS (map->sinvm_inverse) < 1)
		GPF_T1 ("no inverse set");
#endif
	      sinv_make_decoy_procs (cli, map);
	    }
	  map = (sinv_map_t *) dk_alloc (sizeof (sinv_map_t));
	  map->sinvm_name = box_dv_short_string (sinvm_name);

	  id_hash_set (sinv_func_hash,
	      (caddr_t) & map->sinvm_name, (caddr_t) & map);
	}

      dk_set_push (&inverse_set,
	  (void *) box_dv_short_string (sinvm_inverse));
      map->sinvm_flags = sinvm_flags;
    }
  if (map)
    {
      map->sinvm_inverse =
	  (caddr_t *) list_to_array (dk_set_nreverse (inverse_set));
      inverse_set = NULL;
#ifndef NDEBUG
      if (!map->sinvm_inverse || BOX_ELEMENTS (map->sinvm_inverse) < 1)
	GPF_T1 ("no inverse set");
#endif
      sinv_make_decoy_procs (cli, map);
    }
#ifndef NDEBUG
  else if (dk_set_length (inverse_set))
    GPF_T1 ("no map have set");
#endif


  REPORT_ERR (lc->lc_error);
  lc_free (lc);
  qr_free (rd);
}

static int
sinv_normalize_func_name (const char *fname, client_connection_t *cli,
    char *nm, int sizeof_nm)
{
  if (!bif_find (fname))
    {
      char *proc_name = sch_full_proc_name (isp_schema (NULL), fname,
	  cli_qual (cli), CLI_OWNER (cli));
      if (!proc_name)
	return 0;
      else
	{
	  strncpy (nm, proc_name, sizeof_nm - 1);
	  nm [sizeof_nm - 1] = 0;
	}
    }
  else
    {
      strncpy (nm, fname, sizeof_nm - 1);
      nm [sizeof_nm - 1] = 0;
      if (case_mode == CM_MSSQL)
	strlwr (nm);
    }
  return 1;
}


static caddr_t
bif_sinv_read_invers_sys (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  caddr_t fname = bif_string_arg (qst, args, 0, "sinv_read_invers_sys");
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t arr = NULL;
  char nm[3 * MAX_NAME_LEN + 3];

  sec_check_dba (qi, "sinv_read_invers_sys");
  if (!sinv_normalize_func_name (fname, qi->qi_client, nm, sizeof (nm)))
      sqlr_new_error ("22023", "SR461", "Procedure %.*s not found in sinv_read_invers_sys",
	3 * MAX_NAME_LEN, fname);

  sinv_read_sql_inverses (&nm[0], qi->qi_client);

  arr =
      list (2, box_dv_short_string ("sinv_read_invers_sys(?)"),
      box_dv_short_string (&nm[0]));
  log_text_array (qi->qi_trx, arr);
  dk_free_tree (arr);
  return NEW_DB_NULL;
}

#define SKIP_AS(x) \
	while (ST_P (x, BOP_AS)) \
	  (x) = (x)->_.as_exp.left

static int
sinv_call_has_col (ST * tree)
{
  int have_col = 0;
  SKIP_AS (tree);
  if (ST_P (tree, CALL_STMT) && SINV_DV_STRINGP (tree->_.call.name))
    {
      int inx;

      DO_BOX (ST *, arg, inx, tree->_.call.params)
      {
	SKIP_AS (arg);
	if (ST_P (arg, COL_DOTTED))
	  {
	    have_col = 1;
	    break;
	  }
      }
      END_DO_BOX;

    }
  return have_col;
}

sinv_map_t *
sinv_call_map (ST * tree, client_connection_t * cli)
{
  SKIP_AS (tree);
  if (ST_P (tree, CALL_STMT) && SINV_DV_STRINGP (tree->_.call.name))
    {
      sinv_map_t *pres = NULL;

      pres = sinv_find_func_map (tree->_.call.name, cli);

      if (pres
	  && BOX_ELEMENTS (pres->sinvm_inverse) ==
	  BOX_ELEMENTS (tree->_.call.params))
	return pres;
    }
  return NULL;
}


ST *
sinv_check_inverses (ST *tree, client_connection_t *cli)
{
  ST *otree = tree;
  sinv_map_t *map;

  SKIP_AS (tree);
  map = sinv_call_map (tree, cli);
  if (map)
    {
      if (BOX_ELEMENTS (tree->_.call.params) == 1)
	{
	  ST *arg;
	  arg = tree->_.call.params[0];
	  SKIP_AS (arg);
	  if (ST_P (arg, CALL_STMT) && SINV_DV_STRINGP (arg->_.call.name) &&
	      BOX_ELEMENTS (arg->_.call.params) == 1)
	    {
	      char nm[3 * MAX_NAME_LEN + 3];
	      if (sinv_normalize_func_name (arg->_.call.name, cli, nm, sizeof (nm)) &&
		  !CASEMODESTRCMP (nm, map->sinvm_inverse[0]))
		return sinv_check_inverses (arg->_.call.params[0], cli);
	    }
	}
    }
  else if (ST_P (tree, CALL_STMT) &&
      SINV_DV_STRINGP (tree->_.call.name) &&
      BOX_ELEMENTS (tree->_.call.params) == 1)
    {
      char nm[3 * MAX_NAME_LEN + 3];

      if (sinv_normalize_func_name (tree->_.call.name, cli, nm, sizeof (nm)))
	{
	  ST *arg = tree->_.call.params[0];
	  SKIP_AS (arg);
	  map = sinv_call_map (arg, cli);

	  if (map)
	    {
	      int iinx;
	      _DO_BOX (iinx, map->sinvm_inverse)
		{
		  if (0 == CASEMODESTRCMP (map->sinvm_inverse[iinx], nm))
		    return sinv_check_inverses (arg->_.call.params[iinx], cli);
		}
	      END_DO_BOX;
	    }
	}
    }
  return otree;
}


ST *
sinv_check_exp (sqlo_t * so, ST * tree)
{
  ST *res = NULL;
  ST *otree = tree;
  client_connection_t *cli = NULL;

  sinv_map_t *lmap, *rmap, *map;
  ST *left, *right;
  ptrlong new_op;
  int inx_inv;
  int do_it = 0;
  int lmap_col = 0, rmap_col = 0, map_col = 0;

  if (!sinv_func_hash)
    return otree;

  if (tree->type != BOP_PLUS &&
      tree->type != BOP_MINUS &&
      tree->type != BOP_TIMES &&
      tree->type != BOP_DIV &&
      tree->type != BOP_EQ &&
      tree->type != BOP_NEQ &&
      tree->type != BOP_LT &&
      tree->type != BOP_LTE &&
      tree->type != BOP_GT &&
      tree->type != BOP_GTE)
    return otree;

  res = NULL;

  cli = sqlc_client();
  lmap = sinv_call_map (tree->_.bin_exp.left, cli);
  if (lmap)
    lmap_col = sinv_call_has_col (tree->_.bin_exp.left);
  rmap = sinv_call_map (tree->_.bin_exp.right, cli);
  if (rmap)
    rmap_col = sinv_call_has_col (tree->_.bin_exp.right);


  map = (lmap && (lmap_col || !rmap)) ? lmap : rmap;
  if (!map)
    return otree;
  /* printf ("\n*** sqloinv: "); sqlo_box_print (tree);
     printf ("\n   becomes:"); */
  map_col = (lmap == map) ? lmap_col : rmap_col;

  left = lmap == map ? tree->_.bin_exp.left : tree->_.bin_exp.right;
  right = lmap == map ? tree->_.bin_exp.right : tree->_.bin_exp.left;
  new_op = lmap == map ? tree->type : cmp_op_inverse (tree->type);
  SKIP_AS (left);
  SKIP_AS (right);

  if (!IS_ORDER_PRESERVING (map) && !ST_P (tree, BOP_EQ))
    return otree;

  if (lmap && rmap && lmap == rmap && lmap_col)
    {
      _DO_BOX (inx_inv, map->sinvm_inverse)
        {
	  ST *clause;
	  ST *new_left, *new_right;
	  new_left =
	      (ST *) t_box_copy_tree ((caddr_t) left->_.call.params[inx_inv]);
	  new_right =
	      (ST *) t_box_copy_tree ((caddr_t) right->_.call.params[inx_inv]);

	  new_left = sinv_check_inverses (new_left, cli);
	  new_right = sinv_check_inverses (new_right, cli);

	  BIN_OP (clause, tree->type, new_left, new_right);
	  clause = sinv_check_exp (so, clause);
	  t_st_and (&res, clause);
	}
      END_DO_BOX;
    }
  else if (map_col)
    {
      if (!ST_P (right, COL_DOTTED))
	do_it = 1;
      else
	{
	  if (!right->_.col_ref.prefix)	/* parameter ? */
	    do_it = 1;
	  else if (so || lmap_col)
	    {
	      int dont_do_it = 0;
	      if (0 /* !so->so_scope || !so->so_scope->sco_tables */)
		dont_do_it = 1;
	      else if (so)
		{
		  DO_SET (op_table_t *, ot, &so->so_this_dt->ot_from_ots)
		    {
		      if (!strcmp (ot->ot_new_prefix, right->_.col_ref.prefix))
			{
			  dont_do_it = 1;
			  break;
			}
		    }
		  END_DO_SET ();
		}
	      if (!dont_do_it)
		do_it = 1;
	    }
	}

      if (do_it)
	{
	  DO_BOX (caddr_t, inverse, inx_inv, map->sinvm_inverse)
	  {
	    ST *clause;
	    ST *new_left, *new_right;
	    new_left =
		(ST *) t_box_copy_tree ((caddr_t) left->_.call.
		params[inx_inv]);
	    new_right =
		t_listst (3, CALL_STMT, t_sqlp_box_id_upcase (inverse),
		t_list (1, right));

	    new_left = sinv_check_inverses (new_left, cli);
	    new_right = sinv_check_inverses (new_right, cli);

	    BIN_OP (clause, new_op, new_left, new_right);
	    clause = sinv_check_exp (so, clause);
	    t_st_and (&res, clause);
	  }
	  END_DO_BOX;
	}
    }
  /* sqlo_box_print (res ? res : otree); */

  return res ? res : otree;
}


void
sinv_sqlo_check_col_val (ST **pcol, ST **pval, dk_set_t *acol, dk_set_t *aval)
{
  ST *op, *res;
  ST *col = *pcol;
  ST *val = *pval;

  BIN_OP (op, BOP_EQ, col, val);
  res = sinv_check_exp (NULL, op);
  if (res != op && ST_P (res, BOP_AND))
    {
      int outs_done = 0;
      dk_set_t and_set = NULL;

      sqlc_make_and_list (res, &and_set);
      DO_SET (predicate_t *, new_tree_pred, &and_set)
	{
	  if (!outs_done)
	    {
	      outs_done = 1;
	      *pcol = new_tree_pred->pred_text->_.bin_exp.left;
	      *pval = new_tree_pred->pred_text->_.bin_exp.right;
	    }
	  else
	    {
	      t_set_push (acol, new_tree_pred->pred_text->_.bin_exp.left);
	      t_set_push (aval, new_tree_pred->pred_text->_.bin_exp.right);
	    }
	}
      END_DO_SET ();
    }
  else
    {
      *pcol = res->_.bin_exp.left;
      *pval = res->_.bin_exp.right;
    }
}


int
dfe_geo_col_of (df_elt_t * dfe, op_table_t * ot, ST ** new_col)
{
  if (dfe->dfe_tables ? (void*)ot == dfe->dfe_tables->data && !dfe->dfe_tables->next : 0)
    {
      if (!stricmp (ot->ot_table->tb_name, "DB.DBA.RDF_QUAD"))
	{
	  if (DFE_CALL == dfe->dfe_type && !stricmp ( "__ro2sq", dfe->dfe_tree->_.call.name))
	    {
	      *new_col = dfe->dfe_tree->_.call.params[0];
	      return 1;
	    }
	}
      return (DFE_COLUMN == dfe->dfe_type && dfe->_.col.col->col_is_geo_index);
    }
  return 0;
}


int
sqlo_geo_f_solve (sqlo_t * so, df_elt_t * tb_dfe, df_elt_t * cond, dk_set_t * cond_ret, dk_set_t * after_preds)
{
  ST * new_col = NULL;
  op_table_t * ot = tb_dfe->_.table.ot;
  int ctype;
  ST ** contains = sqlc_geo_args (cond->dfe_tree, &ctype);
  df_elt_t * left, * right;
  if (tb_dfe->_.table.text_pred)
    return 0;
  if (!contains)
    return 0;
  left = sqlo_df (so, contains[0]);
  right = sqlo_df (so, contains[1]);
  if (dfe_geo_col_of (right, ot, &new_col))
    {
      ST * copy = (ST*)t_box_copy_tree ((caddr_t)cond->dfe_tree);
      ST * call = copy->_.bin_exp.left->_.bin_exp.right;
      ST ** args = sqlc_geo_args (copy, &ctype);
      args[0] = new_col ? new_col : args[1];
      args[1] = contains[0];
      sqlo_place_exp (so, tb_dfe, sqlo_df (so, args[1]));
      if (BOX_ELEMENTS (args) > 2)
	sqlo_place_exp (so, tb_dfe, sqlo_df (so, args[2]));
      tb_dfe->_.table.text_pred = sqlo_df (so, copy);
      if (GSOP_INTERSECTS != ctype)
	call->_.call.name = t_box_string (predicate_name_of_gsop (ctype));
      tb_dfe->_.table.text_pred->dfe_is_placed = DFE_PLACED;
      //t_set_push (cond_ret, (void*)tb_dfe->_.table.text_pred);
      return 1;
    }
  if (dfe_geo_col_of (left, ot, &new_col))
    {
      if (new_col)
	{
	  ST * copy = (ST*)t_box_copy_tree ((caddr_t)cond->dfe_tree);
	  ST ** args = sqlc_geo_args (copy, &ctype);
	  args[0] = new_col;
	  args[1] = contains[1];
	  sqlo_place_exp (so, tb_dfe, sqlo_df (so, args[1]));
	  if (BOX_ELEMENTS (args) > 2)
	    sqlo_place_exp (so, tb_dfe, sqlo_df (so, args[2]));
	  tb_dfe->_.table.text_pred = sqlo_df (so, copy);
	  tb_dfe->_.table.text_pred->dfe_is_placed = DFE_PLACED;
	  //t_set_push (cond_ret, (void*)tb_dfe->_.table.text_pred);
	  return 1;
	}
      else
	{
	  tb_dfe->_.table.text_pred = cond;
	  cond->dfe_is_placed = DFE_PLACED;
	  //t_set_push (cond_ret, (void*)cond);
	  sqlo_place_exp (so, tb_dfe, sqlo_df (so, contains[1]));
	  if (BOX_ELEMENTS (contains) > 2)
	    sqlo_place_exp (so, tb_dfe, sqlo_df (so, contains[2]));
	  return 1;
	}
    }
  return 0;
}


int
sqlo_solve (sqlo_t * so, df_elt_t * tb_dfe, df_elt_t * cond, dk_set_t * cond_ret, dk_set_t * after_preds)
{
  /* put one or more conds into cond ret such that they are equivalent to cond and each has dependent of ot on the left and no dependent of ot on the right.  */
  if (sqlo_geo_f_solve (so, tb_dfe, cond, cond_ret, after_preds))
    return 1;
  /* more cases here */
  return 0;
}


void
sqlo_inv_bif_int (void)
{
  bif_define ("sinv_read_invers_sys", bif_sinv_read_invers_sys);
}
