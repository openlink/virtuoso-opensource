/*
 *  $Id$
 *
 *  RDF funcs for cluster
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

#include "sqlnode.h"
#include "sqlbif.h"
#include "rdf_core.h"
#include "sqlcmps.h"
#include "sqlo.h"
#include "rdfinf.h"
#include "security.h"


char *rdf_label_inf_name;


id_hash_t *
dict_ht (id_hash_iterator_t * dict)
{
  if (DV_DICT_ITERATOR == DV_TYPE_OF (dict))
    return ((id_hash_iterator_t *)dict)->hit_hash;
  return NULL;
}



int
cu_key_is_dup (cucurbit_t * cu, dbe_key_t * key, char **col_names, caddr_t * values)
{
  ptrlong one = 1;
  caddr_t copy;
  caddr_t tmp[5];
  caddr_t *box;
  int fill = 0;
  int inx, sz = sizeof (caddr_t) * key->key_n_significant;
  id_hash_t *ht;
  BOX_AUTO_TYPED (caddr_t *, box, tmp, sz, DV_ARRAY_OF_POINTER);
  DO_SET (dbe_column_t *, col, &key->key_parts)
  {
    for (inx = 0;; inx++)
      {
	if (!col_names[inx])
	  GPF_T1 ("col names and key parts do not match in rdf insert");
	if (col->col_name[0] == col_names[inx][0])
	  {
	    box[fill++] = values[inx];
	    break;
	  }
      }
  }
  END_DO_SET ();
  ht = (id_hash_t *) gethash ((void *) (ptrlong) key->key_id, cu->cu_key_dup);
  if (ht && id_hash_get (ht, (caddr_t) & box))
    return 1;
  SET_THR_TMP_POOL (cu->cu_clrg->clrg_pool);
  copy = mp_full_box_copy_tree (cu->cu_clrg->clrg_pool, (caddr_t) box);
  if (!ht)
    {
      ht = t_id_hash_allocate (10001, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      sethash ((void *) (ptrlong) key->key_id, cu->cu_key_dup, (void *) ht);
    }
  t_id_hash_set (ht, (caddr_t) & copy, (caddr_t) & one);
  SET_THR_TMP_POOL (NULL);
  return 0;
}


void
cu_rdf_del_cb (cucurbit_t * cu, caddr_t * row)
{
  char *g_iid_name = "g_iid";
  dbe_table_t *quad = sch_name_to_table (wi_inst.wi_schema, "DB.DBA.RDF_QUAD");
  client_connection_t *cli = cu->cu_clrg->clrg_lt->lt_client;
  caddr_t *place;
  int inx;
  static char *col_names[] = { "G", "S", "P", "O", NULL };
  caddr_t values[4];
  cl_req_group_t *clrg = cu->cu_clrg;
  if (cu->cu_rdf_load_mode == RDF_LD_DEL_GS)	/* called subscriber hook */
    {
      values[0] = row[2];
      values[1] = row[3];
      values[2] = row[4];
      values[3] = row[5];
    }
  else if (RDF_LD_MULTIGRAPH != (cu->cu_rdf_load_mode & RDF_LD_MASK))
    {
      place = (caddr_t *) id_hash_get (cli->cli_globals, (caddr_t) & g_iid_name);
      if (!place || !quad)
	sqlr_new_error ("42000", "CL...", "rdf ld pipe has no g_iid in the connection or no table rdf_quad.");
      values[0] = *place;
      values[1] = row[2];
      values[2] = row[3];
      values[3] = row[4];
    }
  else
    {
      values[0] = row[0];
      values[1] = row[1];
      values[2] = row[2];
      values[3] = row[3];
    }
  for (inx = 0; inx < 4; inx++)
    {
      dtp_t dtp = DV_TYPE_OF (values[inx]);
      if (DV_DB_NULL == dtp)
	return;
      if (inx < 3 && DV_IRI_ID != dtp)
	return;
    }
  DO_SET (dbe_key_t *, key, &quad->tb_keys)
  {
    cl_op_t *clo;
    if (key->key_no_pk_ref && key->key_distinct)
      continue;
    clo = cl_key_delete_op_vec (cu->cu_qst, key, col_names, values, clrg, clrg->clrg_nth_param_row, clrg->clrg_nth_param_row);
    if (clo)
      mp_array_add (clrg->clrg_pool, &clrg->clrg_param_rows, &clrg->clrg_nth_param_row, (caddr_t) clo);
  }
  END_DO_SET ();
}


caddr_t
cu_rdf_ins_label_normalize (mem_pool_t * mp, caddr_t lbl)
{
  wchar_t tmp[51];
  caddr_t ret;
  int i, j, l;

  l = (size_t) box_utf8_as_wide_char (lbl, (caddr_t) tmp, box_length (lbl) - 1, sizeof (tmp) / sizeof (wchar_t) - 1);
  for (i = 0, j = 0; i < l; i++)
    {
      if (!wcschr (L"\'\",.", tmp[i]))
	tmp[j++] = unicode3_getucase (tmp[i]);
    }
  tmp[j] = L'\x0';
  ret = mp_box_wide_as_utf8_char (mp, (caddr_t) tmp, j, DV_SHORT_STRING);
  return ret;
}

void
cu_rdf_ins_label (cucurbit_t * cu, caddr_t * row)
{
  dbe_table_t *tbl = sch_name_to_table (wi_inst.wi_schema, "DB.DBA.RDF_LABEL");
  static char *col_names[] = { "RL_O", "RL_RO_ID", "RL_TEXT", "RL_LANG", NULL };
  caddr_t oval, values[4];
  cl_req_group_t *clrg = cu->cu_clrg;
  static rdf_inf_ctx_t *ctx;
  static caddr_t err;

  if (!tbl || !virtuoso_server_initialized)
    return;

  if (!ctx && !err)
    {
      caddr_t err = NULL, ctx_name = box_string (rdf_label_inf_name);
      cl_rdf_inf_init (CU_CLI (cu), &err);
      ctx = rdf_inf_ctx (ctx_name);
      dk_free_box (ctx_name);
    }

  if (!ctx)
    return;

  if (DV_DB_NULL == DV_TYPE_OF (row[4]))
    oval = row[5];
  else
    oval = row[4];

  if (DV_RDF == DV_TYPE_OF (oval) && ric_iri_to_sub (ctx, row[3], RI_SUBPROPERTY, 0))
    {
      rdf_box_t *rb = (rdf_box_t *) oval;
      if (!rb->rb_is_complete)
	GPF_T1 ("The rb_box is supposed to be complete in cu_rdf_ins_cb");
      if (!DV_STRINGP (rb->rb_box))	/* labels are supposed to be strings */
	return;
      values[0] = oval;
      values[1] = mp_box_num (clrg->clrg_pool, rb->rb_ro_id);
      values[2] = cu_rdf_ins_label_normalize (clrg->clrg_pool, rb->rb_box);
      values[3] = mp_box_num (clrg->clrg_pool, rb->rb_lang);
      DO_SET (dbe_key_t *, key, &tbl->tb_keys)
      {
	cl_op_t *clo;
	clo = cl_key_insert_op_vec (cu->cu_qst, key, INS_SOFT_QUIET, col_names, values, cu->cu_clrg,
	    cu->cu_clrg->clrg_nth_param_row, cu->cu_clrg->clrg_nth_param_row);
	if (clo)
	  mp_array_add (clrg->clrg_pool, &clrg->clrg_param_rows, &clrg->clrg_nth_param_row, (caddr_t) clo);
      }
      END_DO_SET ();
    }
}


void
cu_rdf_ins_cb (cucurbit_t * cu, caddr_t * row)
{
  /* when the dpipe produces a row, this is called.  This places the insert clo's for the quad table in the dpipe's daq as extra side effects */
  dbe_table_t *quad = sch_name_to_table (wi_inst.wi_schema, "DB.DBA.RDF_QUAD");
  client_connection_t *cli = cu->cu_clrg->clrg_lt->lt_client;
  char *g_iid_name = "g_iid";
  caddr_t *place;
  static char *col_names[] = { "G", "S", "P", "O", NULL };
  caddr_t values[4];
  cl_req_group_t *clrg = cu->cu_clrg;
  if (RDF_LD_INS_GS == cu->cu_rdf_load_mode)
    {
      values[0] = row[2];
      values[1] = row[3];
      values[2] = row[4];
      values[3] = row[5];
      goto exec;
    }
  if ((RDF_LD_DEL_INS | RDF_LD_MULTIGRAPH) == cu->cu_rdf_load_mode)
    {
      values[0] = row[0];
      values[1] = row[1];
      values[2] = row[2];
      values[3] = row[3];
      goto exec;
    }
  if (RDF_LD_MULTIGRAPH != (cu->cu_rdf_load_mode & RDF_LD_MASK))
    {
      place = (caddr_t *) id_hash_get (cli->cli_globals, (caddr_t) & g_iid_name);
      if (!place || !quad)
	sqlr_new_error ("42000", "CL...", "rdf ld pipe has no g_iid in the connection or no table rdf_quad.");
      values[0] = *place;
    }
  else
    {
      values[0] = row[6];
      if (DV_RDF == DV_TYPE_OF (row[5]))
	{
	  QNCAST (rdf_box_t, rb, row[5]);
	  if (rb->rb_is_text_index)
	    {
	      client_connection_t *cli = cu->cu_clrg->clrg_lt->lt_client;
	      char *g_dict_name = "g_dict";
	      id_hash_iterator_t **dict_place = (id_hash_iterator_t **) id_hash_get (cli->cli_globals, (caddr_t) & g_dict_name);
	      id_hash_t *ht;
	      if (dict_place && (ht = dict_ht (*dict_place)))
		{
		  caddr_t g_box = box_copy_tree (row[6]);
		  caddr_t id_box = box_num (rb->rb_ro_id);
		  caddr_t *place = (caddr_t *) id_hash_get (ht, (caddr_t) & id_box);
		  if (!place)
		    id_hash_set (ht, (caddr_t) & id_box, (caddr_t) & g_box);
		  else
		    {
		      caddr_t prev = *place;
		      dk_free_box (id_box);
		      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (prev))
			{
			  int len = BOX_ELEMENTS (prev);
			  caddr_t old_prev = prev;
			  caddr_t last = len > 0 ? ((caddr_t *) prev)[len - 1] : NULL;
			  if (!last || !box_equal (last, g_box))
			    {
			      prev = box_append_1 (prev, g_box);
			      dk_free_box (old_prev);
			    }
			  else
			    dk_free_tree (g_box);
			}
		      else
			{
			  if (!box_equal (prev, g_box))
			    prev = list (2, prev, g_box);
			  else
			    dk_free_tree (g_box);
			}
		      *place = prev;
		    }
		}
	    }
	}
    }

  values[1] = row[2];
  values[2] = row[3];
  if (DV_DB_NULL == DV_TYPE_OF (row[4]))
    values[3] = row[5];
  else
    values[3] = row[4];
exec:
  if (DV_RDF == DV_TYPE_OF (values[3]))
    rdf_box_audit ((rdf_box_t *) values[3]);
  DO_SET (dbe_key_t *, key, &quad->tb_keys)
  {
    cl_op_t *clo;
    if (key->key_no_pk_ref && cu_key_is_dup (cu, key, col_names, values))
      continue;
    clo = cl_key_insert_op_vec (cu->cu_qst, key, INS_SOFT_QUIET, col_names, values, cu->cu_clrg,
	cu->cu_clrg->clrg_nth_param_row, cu->cu_clrg->clrg_nth_param_row);
    if (clo)
      mp_array_add (clrg->clrg_pool, &clrg->clrg_param_rows, &clrg->clrg_nth_param_row, (caddr_t) clo);
  }
  END_DO_SET ();
  /* add here code to get labels */
  if (rdf_label_inf_name)
    cu_rdf_ins_label (cu, row);
}

void cu_clear (cucurbit_t * cu);
caddr_t bif_rollback (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t dpipe_redo (cl_req_group_t * clrg, caddr_t * qst);

caddr_t cu_ld_str (caddr_t * row, int tmp);

caddr_t
lc_t_str4 (srv_stmt_t * lc)
{
  select_node_t *sn = lc->sst_query->qr_select_node;
  state_slot_t **sel = sn->sel_out_slots;
  caddr_t tmp[64];
  caddr_t *out, ret;
  int inx;
  BOX_AUTO_TYPED (caddr_t *, out, tmp, 4 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  if (sn->sel_n_value_slots != 4)
    GPF_T;
  for (inx = 0; inx < sn->sel_n_value_slots; inx++)
    {
      out[inx] = qst_get (lc->sst_qst, sel[inx]);
    }
  ret = cu_ld_str (out, 0);
  return ret;
}


void
gs_read_lc (srv_stmt_t * lc, int rc, caddr_t * err_ret, id_hash_t * res)
{
  ptrlong one = 1;
  if (LC_INIT == rc)
    WITHOUT_TMP_POOL
    {
      rc = lc_exec (lc, NULL, NULL, 0);
    }
  END_WITHOUT_TMP_POOL;
  for (;;)
    {
      if (LC_ERROR == rc)
	{
	  caddr_t err = lc->sst_pl_error;
	  lc->sst_pl_error = NULL;
	  SET_THR_TMP_POOL (NULL);
	  *err_ret = err;
	  return;
	}
      if (LC_ROW == rc)
	{
	  /* set string */
	  caddr_t row = lc_t_str4 (lc);	/* lc_t_row to use array */
	  id_hash_set (res, (caddr_t) & row, (caddr_t) & one);
	}
      if (LC_AT_END == rc)
	{
	  lc_reuse (lc);
	  return;
	}
      WITHOUT_TMP_POOL
      {
	rc = lc_exec (lc, NULL, NULL, 0);
      }
      END_WITHOUT_TMP_POOL;
    }
}


void
rdf_fetch_gs (query_instance_t * qi, caddr_t * gs, caddr_t * err_ret, id_hash_t * res)
{
  caddr_t *empty = (caddr_t *) list (0);
  int rc;
  static query_t *read_qr;
  srv_stmt_t *lc;
  int inx;
  if (!read_qr)
    {
      caddr_t err = NULL;
      read_qr =
	  sql_compile ("select g, s, p, o from DB.DBA.RDF_QUAD table option (index G) where G = ? option (any order)",
	  qi->qi_client, &err, SQLC_DEFAULT);
      if (NULL != err)
	sqlr_resignal (err);
      read_qr->qr_select_node->src_gen.src_input = (qn_input_fn) select_node_input_subq;
    }
  lc = qr_multistate_lc (read_qr, qi, BOX_ELEMENTS (gs));
  lc->sst_qst[read_qr->qr_select_node->sel_out_quota] = 0;	/* make no local out buffer of rows */
  rc = LC_AT_END;
  DO_BOX (caddr_t *, g, inx, gs)
  {
    WITHOUT_TMP_POOL
    {
      rc = lc_exec (lc, empty, g[0], 1);
    }
    END_WITHOUT_TMP_POOL;
    if (LC_INIT == rc)
      continue;
    if (LC_ERROR == rc)
      {
	caddr_t err = lc->sst_pl_error;
	lc->sst_pl_error = NULL;
	*err_ret = err;
	return;
      }
    gs_read_lc (lc, rc, err_ret, res);
  }
  END_DO_BOX;
  if (LC_AT_END != rc)
    gs_read_lc (lc, rc, err_ret, res);
  dk_free_box (empty);
  dk_free_box ((caddr_t) lc);
}

void log_repl_text_array (lock_trx_t * lt, char *srv, char *acct, caddr_t box);

#define PRINT_ERR(err) \
      if (err) \
	{ \
	  log_error ("Error compiling a server init statement : %s: %s -- %s:%d", \
	      ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING], \
		     __FILE__, __LINE__); \
	  dk_free_tree (err); \
	  err = NULL; \
	}

void
rdf_repl_gs_batch (query_instance_t * qi, caddr_t * batch, int ins)
{
  caddr_t reg, err = NULL, *pars;
  static query_t *delqr;
  static query_t *insqr;
  IN_TXN;
  reg = registry_get ("DB.DBA.RDF_REPL");
  LEAVE_TXN;
  if (!reg)
    {
      dk_free_tree (batch);
      return;
    }
  dk_free_box (reg);
  if (!delqr)
    {
      delqr = sql_compile ("DB.DBA.RDF_QUAD_REPL_DEL (?)", qi->qi_client, &err, SQLC_DEFAULT);
      PRINT_ERR (err);
      insqr = sql_compile ("DB.DBA.RDF_QUAD_REPL_INS (?)", qi->qi_client, &err, SQLC_DEFAULT);
      PRINT_ERR (err);
    }
  if (!delqr || !insqr)
    {
      log_error ("RDF replication failed.");
      dk_free_tree (batch);
      return;
    }
  pars = (caddr_t *) list (1, batch);
  err = qr_exec (qi->qi_client, ins ? insqr : delqr, qi, NULL, NULL, NULL, pars, NULL, 0);
  if (err)
    {
      PRINT_ERR (err);
    }
  dk_free_box (pars);
}


long tc_g_replace_ins, tc_g_replace_del;
int rdf_graph_is_in_enabled_repl (caddr_t * qst, iri_id_t q_iid, int *answer_is_one_for_all_ret);
caddr_t *cu_ld_row (caddr_t str);
void clrg_local_ins_del_single (cl_req_group_t * clrg);

void
cu_gr_next (cucurbit_t * cu, query_instance_t * qi, int fin)
{
  cu->cu_clrg->clrg_inst = cu->cu_qst = (caddr_t *) qi;
  if (CL_RUN_LOCAL == cl_run_local_only)
    {
      clrg_local_ins_del_single (cu->cu_clrg);
    }
}

int32 rdf_ld_batch_sz;

void
cu_feed_ins (cucurbit_t * cu, id_hash_t * pre, id_hash_t * ins, int fill_ins, dk_set_t * set, caddr_t * qst)
{
  int inx = 0;
  ptrlong one = 1;
  caddr_t err = NULL;
  mem_pool_t *mp = THR_TMP_POOL;
  DO_SET (caddr_t, img, &cu->cu_ld_rows)
  {
    if (fill_ins)
      {
	id_hash_set (ins, (caddr_t) & img, (caddr_t) & one);
      }
    else if (!id_hash_get (pre, (caddr_t) & img))
      {
	int allg = 0;
	/* compose row */
	caddr_t *row = cu_ld_row (img);
	cu_rdf_ins_cb (cu, (caddr_t *) row);
	if (rdf_graph_is_in_enabled_repl (qst, unbox_iri_id (row[0]), &allg))
	  dk_set_push (set, row);
	else
	  mp_trash (cu->cu_clrg->clrg_pool, (caddr_t) row);
	TC (tc_g_replace_ins);
#if 1
	  inx++;
	if ((inx % rdf_ld_batch_sz) == 0)
	  {
	    cu_gr_next (cu, (query_instance_t *) qst, 1);
	    bif_commit (qst, &err, NULL);
	      rdf_repl_gs_batch ((query_instance_t *)qst, (caddr_t *) list_to_array (dk_set_nreverse (*set)), 1);
	      *set = NULL;
	    cu_clear (cu);
	  }
#endif
      }
    SET_THR_TMP_POOL (mp);
  }
  END_DO_SET ();
}

void
cu_feed_del (cucurbit_t * cu, id_hash_t * pre, id_hash_t * ins, dk_set_t * set, caddr_t * qst)
{
  int inx = 0;
  caddr_t err = NULL;
  DO_IDHASH (caddr_t, img, ptrlong, ign, pre)
  {
    if (!id_hash_get (ins, (caddr_t) & img))
      {
	int allg = 0;
	/* compose row */
	caddr_t *row = cu_ld_row (img);
	cu_rdf_del_cb (cu, row);
	if (rdf_graph_is_in_enabled_repl (qst, unbox_iri_id (row[0]), &allg))
	  dk_set_push (set, row);
	else
	  mp_trash (cu->cu_clrg->clrg_pool, (caddr_t) row);
	TC (tc_g_replace_del);
#if 1
	  inx++;
	if ((inx % rdf_ld_batch_sz) == 0)
	  {
	    cu_gr_next (cu, (query_instance_t *) qst, 1);
	    bif_commit (qst, &err, NULL);
	      rdf_repl_gs_batch ((query_instance_t *)qst, (caddr_t *) list_to_array (dk_set_nreverse (*set)), 0);
	      *set = NULL;
	    cu_clear (cu);
	  }
#endif
      }
  }
  END_DO_IDHASH;
}

size_t
cu_ld_rows_size (cucurbit_t * cu)
{
  size_t ret = 0;
  DO_SET (caddr_t, img, &cu->cu_ld_rows)
  {
    ret += (box_length (img) + sizeof (s_node_t));
  }
  END_DO_SET ();
  return ret;
}


void cu_rl_local_exec (cucurbit_t * cu);

void
cl_rdf_call_insert_cb (cucurbit_t * cu, caddr_t * qst, caddr_t * err_ret)
{
  id_hash_t *pre, *ins;
  query_instance_t *qi = (query_instance_t *) qst;
  int old_ac = qi->qi_client->cli_row_autocommit;
  id_hash_iterator_t hit;
  caddr_t *vp, *kp, **g_iid_to_delete;
  dk_set_t set = NULL, deleted = NULL, inserted = NULL;

  cu->cu_clrg->clrg_inst = cu->cu_qst = (caddr_t *) qi;
  if (cu->cu_ld_graphs)
    {
      id_hash_iterator (&hit, cu->cu_ld_graphs);
      while (hit_next (&hit, (caddr_t *) & kp, (caddr_t *) & vp))
	{
	  boxint g = (boxint) * kp;
	  dk_set_push (&set, list (1, box_iri_id (g)));
	}
      id_hash_free (cu->cu_ld_graphs);
    }
  cu->cu_ld_graphs = NULL;
  qi->qi_client->cli_row_autocommit = 0;
  cu->cu_clrg->clrg_no_txn = 0;
  g_iid_to_delete = (caddr_t **) list_to_array (dk_set_nreverse (set));

  SET_THR_TMP_POOL (cu->cu_clrg->clrg_pool);
  pre = id_hash_allocate (cu->cu_fill, sizeof (caddr_t), 0, treehash, treehashcmp);
  id_hash_set_rehash_pct (pre, 200);
  rdf_fetch_gs (qi, (caddr_t *) g_iid_to_delete, err_ret, pre);
  dk_free_tree (g_iid_to_delete);
  ins = id_hash_allocate (cu->cu_fill, sizeof (caddr_t), 0, treehash, treehashcmp);
  id_hash_set_rehash_pct (ins, 200);
  cu_feed_ins (cu, pre, ins, 1, 0, qst);
  cu_feed_del (cu, pre, ins, &deleted, qst);
  SET_THR_TMP_POOL (NULL);
  cu_gr_next (cu, (query_instance_t *) qst, 1);
  bif_commit (qst, err_ret, NULL);
  rdf_repl_gs_batch ((query_instance_t *) qst, (caddr_t *) list_to_array (dk_set_nreverse (deleted)), 0);
  cu->cu_clrg->clrg_no_txn = old_ac;
  qi->qi_client->cli_row_autocommit = old_ac;
  if (old_ac)
    {
      DO_SET (cll_in_box_t *, clib, &cu->cu_clrg->clrg_clibs) clib->clib_enlist = 0;
      END_DO_SET ();
    }
  cu_feed_ins (cu, pre, ins, 0, &inserted, qst);
  DO_SET (caddr_t *, row, &cu->cu_ld_rows)	/* release memory, not needed anymore */
  {
    dk_free_tree (row);
  }
  END_DO_SET ();
  dk_set_free (cu->cu_ld_rows);
  cu->cu_ld_rows = NULL;
  DO_IDHASH (caddr_t, img, ptrlong, ign, pre) dk_free_box (img);
  END_DO_IDHASH;
  id_hash_free (pre);
  id_hash_free (ins);
  SET_THR_TMP_POOL (NULL);
  cu_gr_next (cu, (query_instance_t *) qst, 1);
  bif_commit (qst, err_ret, NULL);
  rdf_repl_gs_batch ((query_instance_t *) qst, (caddr_t *) list_to_array (dk_set_nreverse (inserted)), 1);

  if (*err_ret)
    {
      /*log_error ("RDF CB COMMIT: %s %s", ERR_STATE (*err_ret), ERR_MESSAGE (*err_ret)); */
      return;
    }
  cu_clear (cu);
}

void cu_ld_store_rows (cucurbit_t * cu, caddr_t * qst, caddr_t * err_ret);

caddr_t
bif_dpipe_exec_rdf_callback (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "dpipe_exec_rdf_callback");
  cucurbit_t *cu = clrg->clrg_cu;
  if (!cu)
    sqlr_new_error ("42000", "CL...", "Not a dpipe daq");
  cu_ld_store_rows (cu, qst, err_ret);
  cl_rdf_call_insert_cb (cu, qst, err_ret);
  return NULL;
}



caddr_t
cl_id_to_iri (query_instance_t * qi, caddr_t id)
{
  GPF_T;
  return NULL;
}



caddr_t
bif_dpipe_rdf_load_mode (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "dpipe_set_rdf_load_mode");
  cucurbit_t *cu = clrg->clrg_cu;
  if (!cu)
    sqlr_new_error ("42000", "CL...", "Not a dpipe daq");
  return box_num (cu->cu_rdf_load_mode);
}


caddr_t
bif_dpipe_set_rdf_load (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "dpipe_set_rdf_load");
  cucurbit_t *cu = clrg->clrg_cu;
  QNCAST (query_instance_t, qi, qst);

  if (!cu)
    sqlr_new_error ("42000", "CL...", "Not a dpipe daq");
  if (!QI_IS_DBA (qi) && !sec_user_has_group_name ("SPARQL_UPDATE", qi->qi_u_id))
    sqlr_new_error ("42000", "CL...:SECURITY", "No SPARQL_UPDATE permission to use RDF loader");
  cu->cu_ready_cb = cu_rdf_ins_cb;
  if (BOX_ELEMENTS (args) > 1)
    cu->cu_rdf_load_mode = bif_long_arg (qst, args, 1, "dpipe_set_rdf_load");
  if (RDF_LD_DELETE == (cu->cu_rdf_load_mode & RDF_LD_MASK))
    cu->cu_ready_cb = cu_rdf_del_cb;
  if ((cu->cu_rdf_load_mode & RDF_LD_MASK) != RDF_LD_DELETE && !cu->cu_key_dup)
    cu->cu_key_dup = hash_table_allocate (5);
  if (cu->cu_rdf_load_mode & RDF_LD_DEL_INS)
    cu->cu_ready_cb = NULL;
  if (cu->cu_rdf_load_mode & RDF_LD_DEL_GS)
    cu->cu_ready_cb = cu_rdf_del_cb;
  if (cu->cu_rdf_load_mode & RDF_LD_INS_GS)
    cu->cu_ready_cb = cu_rdf_ins_cb;
  return NULL;
}


void
cl_rdf_init ()
{
  bif_define ("dpipe_set_rdf_load", bif_dpipe_set_rdf_load);
  bif_define_ex ("dpipe_rdf_load_mode", bif_dpipe_rdf_load_mode, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define ("dpipe_exec_rdf_callback", bif_dpipe_exec_rdf_callback);
  rdf_ld_batch_sz = dc_batch_sz;
  if (CL_RUN_LOCAL == cl_run_local_only)
    return;
}
