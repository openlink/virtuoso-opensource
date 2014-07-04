/*
 *  rdfld.c
 *
 *  $Id$
 *
 *  Local rdf bulk load
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

#include "sqlnode.h"
#include "sqlbif.h"
#include "rdf_core.h"
#include "aqueue.h"
#include "sqlbif.h"
#include "security.h"


query_t *rl_queries[10];
query_t * rl_del_qrs[10];
query_t *rl_all_keys_qr;
query_t *rl_graph_words_qr;
state_slot_t ssl_set_no_dummy;
state_slot_t ssl_iri_dummy;
state_slot_t ssl_any_dummy;
extern resource_t *clib_rc;


cll_in_box_t *
clrg_ensure_single_clib (cl_req_group_t * clrg)
{
  cll_in_box_t *clib;
  if (!clrg->clrg_clibs)
    {
      clib = (cll_in_box_t *) resource_get (clib_rc);
      dk_set_push (&clrg->clrg_clibs, (void *) clib);
    }
  else
    clib = (cll_in_box_t *) clrg->clrg_clibs->data;
  return clib;
}


void
cu_local_dispatch (cucurbit_t * cu, value_state_t * vs, cu_func_t * cf, caddr_t val)
{
  int seq = 0;
  caddr_t *args = (caddr_t *) val;
  int inx;
  cl_op_t *clo = NULL;
  cll_in_box_t *clib;
  cl_req_group_t *clrg = cu->cu_clrg;
  clib = clrg_ensure_single_clib (clrg);
  DO_SET (cl_op_t *, clo2, &clib->clib_vec_clos)
  {
    if (CLO_CALL == clo2->clo_op && clo2->_.call.func == cf->cf_proc)
      {
	clo = clo2;
	break;
      }
  }
  END_DO_SET ();
  if (!clo)
    {
      state_slot_t ssl_dummy;
      int is_ro = NULL != strstr (cf->cf_proc, "O_LOOK");
      int init_sz = is_ro ? dc_batch_sz : dc_batch_sz + (dc_batch_sz / 3);
      memset (&ssl_dummy, 0, sizeof (ssl_dummy));
      clo = mp_clo_allocate (clrg->clrg_pool, CLO_CALL);
      mp_set_push (clrg->clrg_pool, &clib->clib_vec_clos, (void *) clo);
      clo->clo_set_no = mp_data_col (clrg->clrg_pool, &ssl_set_no_dummy, init_sz);
      clo->_.call.func = cf->cf_proc;
      clo->_.call.params = (caddr_t *) mp_box_copy (clrg->clrg_pool, val);
      DO_BOX (caddr_t, arg, inx, args)
      {
	ssl_dummy.ssl_sqt = cf->cf_arg_sqt[inx];
	ssl_dummy.ssl_dc_dtp = sqt_dc_dtp (&ssl_dummy.ssl_sqt);
	clo->_.call.params[inx] = (caddr_t) mp_data_col (clrg->clrg_pool, &ssl_dummy, init_sz);
      }
      END_DO_BOX;
    }
  seq = ~CL_DA_FOLLOWS & (clrg->clrg_clo_seq_no++);
  sethash ((void *) (ptrlong) seq, cu->cu_seq_no_to_vs, (void *) vs);
  dc_append_int64 (clo->clo_set_no, seq);
  DO_BOX (caddr_t, arg, inx, args)
  {
    data_col_t *dc = (data_col_t *) clo->_.call.params[inx];
    dc_append_box (dc, arg);
    if (dc->dc_buffer && dc->dc_buf_fill > dc->dc_buf_len)
      GPF_T1 ("write past dc end");
  }
  END_DO_BOX;
}


void
cu_rl_local_exec (cucurbit_t * cu)
{
  /* vectored call of each clo func */
  cl_req_group_t *clrg = cu->cu_clrg;
  QNCAST (query_instance_t, qi, cu->cu_qst);
  cll_in_box_t *clib;
  if (!clrg->clrg_clibs)
    return;			/* this is possible if all rows in dpipe are without lits with id  and all iris came from cache, so iriu resolutions or literals with id */
  clib = (cll_in_box_t *) clrg->clrg_clibs->data;
  DO_SET (cl_op_t *, clo, &clib->clib_vec_clos)
  {
    client_connection_t *cli = qi->qi_client;
    query_t *proc = sch_proc_def (wi_inst.wi_schema, clo->_.call.func);
    caddr_t save_pars[10];
    caddr_t err = NULL;
    if (!proc)
      sqlr_new_error ("42001", "DP...", "Undefined procedure %s in local dpipe", clo->_.call.func);
    if (proc->qr_to_recompile)
      {
	proc = qr_recompile (proc, &err);
	if (err)
	  sqlr_resignal (err);
      }
    if (!cli->cli_user || !sec_proc_check (proc, cli->cli_user->usr_id, cli->cli_user->usr_g_id))
      {
	user_t *usr = cli->cli_user;
	sqlr_new_error ("42000", "SR186", "No permission to execute dpipe %s with user ID %d, group ID %d",
	    clo->_.call.func, (int) (usr ? usr->usr_id : 0), (int) (usr ? usr->usr_g_id : 0));
      }
    memcpy (save_pars, clo->_.call.params, box_length ((caddr_t) clo->_.call.params));
    qi->qi_client->cli_non_txn_insert = qi->qi_non_txn_insert;
    err = qr_exec (qi->qi_client, proc, CALLER_LOCAL, "", NULL, NULL, clo->_.call.params, NULL, 0);
    qi->qi_client->cli_non_txn_insert = 0;
    memcpy (clo->_.call.params, save_pars, box_length ((caddr_t) clo->_.call.params));
    if (err)
      sqlr_resignal (err);
  }
  END_DO_SET ();
  DO_SET (cl_op_t *, clo, &clib->clib_vec_clos)
  {
    int is_ro = NULL != strstr (clo->_.call.func, "L_O_LOOK");
    int n_pars = BOX_ELEMENTS (clo->_.call.params);
    int inx;
    data_col_t *res = (data_col_t *) clo->_.call.params[n_pars - 1];
    data_col_t *sets = clo->clo_set_no;
    for (inx = 0; inx < sets->dc_n_values; inx++)
      {
	ptrlong nth = dc_any_value (sets, inx);
	int64 id = dc_any_value (res, inx);
	value_state_t *vs = gethash ((void *) nth, cu->cu_seq_no_to_vs);
	if (is_ro)
	  {
	    if (DV_RDF == DV_TYPE_OF (vs->vs_org_value))
	      {
		rdf_box_t *rb = (rdf_box_t *) vs->vs_org_value;
		rb->rb_ro_id = id;
		if (rb->rb_is_text_index && cu->cu_rdf_load_mode != RDF_LD_MULTIGRAPH)
		  {
		    client_connection_t *cli = qi->qi_client;
		    char *g_dict_name = "g_dict";
		    id_hash_iterator_t **dict_place =
			(id_hash_iterator_t **) id_hash_get (cli->cli_globals, (caddr_t) & g_dict_name);
		    id_hash_t *ht;
		    if (dict_place && (ht = dict_ht (*dict_place)))
		      {
			caddr_t one = (caddr_t) 1, id_box = box_num (id);
			id_hash_set (ht, (caddr_t) & id_box, (caddr_t) & one);
		      }
		  }
		cu_set_value (cu, vs, box_copy_tree ((caddr_t) rb));
	      }
	    else if (DV_STRING == DV_TYPE_OF (vs->vs_org_value))
	      {
		rdf_box_t *rb = rb_allocate ();
		rb->rb_ro_id = id;
		rb->rb_type = RDF_BOX_DEFAULT_TYPE;
		rb->rb_lang = RDF_BOX_DEFAULT_LANG;
		if (cu->cu_rdf_load_mode != RDF_LD_MULTIGRAPH)
		  {
		    client_connection_t *cli = qi->qi_client;
		    char *g_dict_name = "g_dict";
		    id_hash_iterator_t **dict_place =
			(id_hash_iterator_t **) id_hash_get (cli->cli_globals, (caddr_t) & g_dict_name);
		    id_hash_t *ht;
		    if (dict_place && (ht = dict_ht (*dict_place)))
		      {
			caddr_t one = (caddr_t) 1, id_box = box_num (id);
			id_hash_set (ht, (caddr_t) & id_box, (caddr_t) & one);
		      }
		  }
		cu_set_value (cu, vs, (caddr_t) rb);
	      }
	  }
	else
	  {
	    caddr_t iid = box_iri_id (id);
	    cu_set_value (cu, vs, iid);
	  }
      }
  }
  END_DO_SET ();
}

caddr_t
aq_rl_key_func_1 (caddr_t av, caddr_t * err_ret, int ins)
{
  caddr_t *args = (caddr_t *) av;
  cl_req_group_t *clrg = (cl_req_group_t *) args[0];
  cucurbit_t *cu = clrg->clrg_cu;
  int nth_key = unbox (args[1]);
  client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  caddr_t *params = ((caddr_t **) cu->cu_cd)[nth_key];
  query_t *qr = ins ? rl_queries[nth_key] : rl_del_qrs[nth_key];
  dk_free_box (args[1]);
  dk_free_box (av);
  if (0 == ((data_col_t **) params)[0]->dc_n_values)
    *err_ret = NULL;
  else
    *err_ret = qr_exec (cli, qr, CALLER_LOCAL, "", NULL, NULL, params, NULL, 0);
  dk_free_box ((caddr_t) clrg);
  return NULL;
}

caddr_t
aq_rl_key_func (caddr_t av, caddr_t * err_ret)
{
  return aq_rl_key_func_1 (av, err_ret, 1);
}

caddr_t
aq_rl_del_key_func (caddr_t av, caddr_t * err_ret)
{
  return aq_rl_key_func_1 (av, err_ret, 0);
}

int rl_query_inited;

void
rl_query_init (dbe_table_t * quad_tb)
{
  caddr_t err = NULL;
  int nth_key = 0;
  char txt[200];
  char pars[20];
  if (rl_query_inited == quad_tb->tb_primary_key->key_id && !rl_queries[0]->qr_to_recompile)
    return;
  if (rl_queries[0] && rl_queries[0]->qr_to_recompile)
    {
      int inx;
      for (inx = 0; NULL != rl_queries[inx] && inx < sizeof (rl_queries) / sizeof (void*); inx ++)
	qr_free (rl_queries[inx]);
      memset (&rl_queries[0], 0, sizeof (rl_queries)); 
    }
  pars[0] = 0;
  nth_key = 0;
  DO_SET (dbe_key_t *, key, &quad_tb->tb_keys)
  {
    int first = 1;
    sprintf (txt, "insert soft DB.DBA.RDF_QUAD index %s option (vectored) (", key->key_name);
    pars[0] = 0;
    DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      sprintf (txt + strlen (txt), "%s %s", first ? "" : ", ", col->col_name);
      sprintf (pars + strlen (pars), "%s ?", first ? "" : ", ");
      first = 0;
    }
    END_DO_SET ();
    sprintf (txt + strlen (txt), ") values (%s)", pars);
    rl_queries[nth_key] = sql_compile (txt, bootstrap_cli, &err, SQLC_DEFAULT);
    nth_key++;
    if (err)
      sqlr_resignal (err);
  }
  END_DO_SET ();
  nth_key = 0;
  DO_SET (dbe_key_t *, key, &quad_tb->tb_keys)
    {
      int first = 1;
      if (key->key_distinct)
	continue;
      sprintf (txt, "delete from DB.DBA.RDF_QUAD table option (index %s, vectored) where ", key->key_name);
      DO_SET (dbe_column_t *, col, &key->key_parts)
	{
	  sprintf (txt + strlen (txt), "%s %s = ? ", first ? "" : "AND", col->col_name);
	  first = 0;
	}
      END_DO_SET();
      sprintf (txt + strlen (txt), "option (index %s, vectored)", key->key_name);
      rl_del_qrs[nth_key] = sql_compile (txt, bootstrap_cli, &err, SQLC_DEFAULT);
      nth_key++;
      if (err)
	sqlr_resignal (err);
    }
  END_DO_SET();
  rl_all_keys_qr = sql_compile ("insert soft DB.DBA.RDF_QUAD option (vectored) (G, S, P, O) values (?, ?, ?, ?)", bootstrap_cli, &err, SQLC_DEFAULT);
  if (err)
    sqlr_resignal (err);
  rl_graph_words_qr = sql_compile ("DB.DBA.RDF_OBJ_ADD_KEYWORD_FOR_GRAPH  (?, ?)", bootstrap_cli, &err, SQLC_DEFAULT);
  if (err)
    sqlr_resignal (err);
  rl_query_inited = quad_tb->tb_primary_key->key_id;
}


void
cu_rl_graph_words (cucurbit_t * cu, caddr_t g_iid)
{
  QNCAST (query_instance_t, qi, cu->cu_qst);
  caddr_t err;
  client_connection_t *cli = GET_IMMEDIATE_CLIENT_OR_NULL;
  char *g_dict_name = "g_dict";
  caddr_t *pars, *save_repl;
  int save_ac;
  id_hash_iterator_t *hit;
  id_hash_iterator_t **dict_place = (id_hash_iterator_t **) id_hash_get (cli->cli_globals, (caddr_t) & g_dict_name);
  if (!dict_place)
    return;
  hit = *dict_place;
  pars = (caddr_t *) list (2, box_copy_tree (g_iid), box_copy_tree ((caddr_t) hit));
  save_repl = box_copy_tree (qi->qi_trx->lt_replicate);
  save_ac = qi->qi_client->cli_row_autocommit;
  err = qr_exec (cli, rl_graph_words_qr, CALLER_LOCAL, "", NULL, NULL, pars, NULL, 0);
  qi->qi_trx->lt_replicate = save_repl;
  qi->qi_client->cli_row_autocommit = save_ac;
  if (IS_BOX_POINTER (err))
    {
      log_error ("Error in insert of graph keywords in vectored rdf load: %s %s", ERR_STATE (err), ERR_MESSAGE (err));
      IN_TXN;
      lt_rollback (cli->cli_trx, TRX_CONT);
      LEAVE_TXN;
    }
  dk_free_box ((caddr_t) pars);
}

void rdf_repl_gs_batch (query_instance_t * qi, caddr_t * batch, int ins);

void
cu_rl_cols (cucurbit_t * cu, caddr_t g_iid)
{
  QNCAST (query_instance_t, qi, cu->cu_qst);
  caddr_t *inst = cu->cu_qst;
  async_queue_t *aq;
  dbe_table_t *quad_tb = sch_name_to_table (wi_inst.wi_schema, "DB.DBA.RDF_QUAD");
  caddr_t err1 = NULL, err2 = NULL;
  int nth_key = 0, inx, n_keys;
  cl_req_group_t *clrg = cu->cu_clrg;
  data_col_t *g_dc = mp_data_col (clrg->clrg_pool, &ssl_iri_dummy, dc_batch_sz);
  data_col_t *s_dc = mp_data_col (clrg->clrg_pool, &ssl_iri_dummy, dc_batch_sz);
  data_col_t *p_dc = mp_data_col (clrg->clrg_pool, &ssl_iri_dummy, dc_batch_sz);
  data_col_t *o_dc = mp_data_col (clrg->clrg_pool, &ssl_any_dummy, dc_batch_sz);
  int is_gs = BOX_ELEMENTS (cu->cu_input_funcs) == 5;
  int is_del = cu->cu_rdf_load_mode == RDF_LD_DEL_GS, allg;
  dk_set_t set = NULL;
  caddr_t tmp[5], * quad;
  BOX_AUTO_TYPED (caddr_t *, quad, tmp, 4 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);

  rl_query_init (quad_tb);
  for (inx = 0; inx < cu->cu_fill; inx++)
    {
      caddr_t *row = (caddr_t *) cu->cu_rows[inx];
      caddr_t gx;
      /* dpipe from replication cb  */
      if (cu->cu_rdf_load_mode == RDF_LD_INS_GS || cu->cu_rdf_load_mode == RDF_LD_DEL_GS)
	{
	  caddr_t x = row[5];
	  dc_append_box (g_dc, row[2]); /* G */
	  dc_append_box (s_dc, row[3]); /* S */
	  dc_append_box (p_dc, row[4]); /* P */
	  if (DV_RDF == DV_TYPE_OF (x)) /* O */
	    {
	      QNCAST (rdf_box_t, rb, x);
	      int is_rb = rb->rb_is_complete && rb->rb_ro_id;
	      if (is_rb) rb->rb_is_complete = 0;
	      dc_append_box (o_dc, x);
	      if (is_rb) rb->rb_is_complete = 1;
	    }
	  else
	    dc_append_box (o_dc, row[5]);
	  continue;
	}
      /* ttlpv loader */
      if (is_gs)
	gx = row[6];
      else
	gx = g_iid;
      dc_append_box (g_dc, gx);
      dc_append_box (s_dc, row[2]);
      dc_append_box (p_dc, row[3]);
      quad[0] = gx;
      quad[1] = row[2];
      quad[2] = row[3];
      if (DV_DB_NULL == DV_TYPE_OF (row[4]))
	{
	  caddr_t x = row[5];
	  QNCAST (rdf_box_t, rb, x);
	  int is_rb = DV_RDF == DV_TYPE_OF (x) && rb->rb_is_complete && rb->rb_ro_id;
	  if (DV_DB_NULL == DV_TYPE_OF (x) || DV_STRING == DV_TYPE_OF (x))
	    sqlr_new_error ("42000",  "CL...",  "NULL and string not allowed for O column value");
	  if (is_rb)
	    rb->rb_is_complete = 0;
	  dc_append_box (o_dc, x);
	  if (is_rb)
	    rb->rb_is_complete = 1;
	  quad[3] = x;
	}
      else
	{
	dc_append_box (o_dc, row[4]);
	  quad[3] = row[4];
	}
      if (rdf_graph_is_in_enabled_repl ((caddr_t *)qi, unbox_iri_id (quad[0]), &allg))
	dk_set_push (&set, box_copy_tree (quad));
    }
  BOX_DONE (quad, tmp);
  if (set)
    rdf_repl_gs_batch (qi, (caddr_t *) list_to_array (dk_set_nreverse (set)), 1);

  cu->cu_cd = (caddr_t *) mp_alloc_box (clrg->clrg_pool, sizeof (caddr_t) * dk_set_length (quad_tb->tb_keys), DV_BIN);
  DO_SET (dbe_key_t *, key, &quad_tb->tb_keys)
  {
    int n_parts = dk_set_length (key->key_parts);
    int nth_part = 0;
      caddr_t * box;
      if (is_del && key->key_distinct) /* delete is on full inxes */
	continue;
      box = (caddr_t*)mp_alloc_box (clrg->clrg_pool, sizeof (caddr_t) * n_parts, DV_BIN);
    cu->cu_cd[nth_key] = (caddr_t) box;
    DO_SET (dbe_column_t *, col, &key->key_parts)
    {
      data_col_t *dc = NULL;
      switch (col->col_name[0])
	{
	    case 'G': case 'g':  dc = g_dc; break;
	    case 'S': case 's':  dc = s_dc; break;
	    case 'P': case 'p':  dc = p_dc; break;
	    case 'O': case 'o':  dc = o_dc; break;
	}
      box[nth_part++] = (caddr_t) dc;
    }
    END_DO_SET ();
    nth_key++;
  }
  END_DO_SET ();
  n_keys = dk_set_length (quad_tb->tb_keys);
  if (qi->qi_trx->lt_replicate != REPL_NO_LOG)
    n_keys = 0;
  aq = aq_allocate (qi->qi_client, qi->qi_non_txn_insert ? n_keys : 0);
  aq->aq_non_txn_insert = qi->qi_non_txn_insert;
  aq->aq_do_self_if_would_wait = 1;
  nth_key = 0;
  DO_SET (dbe_key_t *, key, &quad_tb->tb_keys)
  {
      if (is_del && key->key_distinct) /* delete is on full inxes */
	continue;
      aq_request  (aq, is_del ? aq_rl_del_key_func : aq_rl_key_func, list (2, box_copy ((caddr_t)clrg), box_num (nth_key++)));
  }
  END_DO_SET ();
  /*cu_rl_graph_words (cu, g_iid);*/
  IO_SECT (inst);
  aq->aq_wait_qi = qi;
  aq_wait_all (aq, &err1);
  aq->aq_wait_qi = NULL;
  END_IO_SECT (&err2);
  if (err1)
    {
      dk_free_tree (err2);
      sqlr_resignal (err1);
    }
  if (err2)
    sqlr_resignal (err2);
  dk_free_box ((caddr_t) aq);
}


caddr_t l_iri_id_disp (cucurbit_t * cu, caddr_t name, value_state_t * vs);


caddr_t
l_make_ro_disp (cucurbit_t * cu, caddr_t * args, value_state_t * vs)
{
  /* gets a rdf obj and decides what to do */
  caddr_t allocd_content = NULL;
  uint32 dt_lang;
  caddr_t box = (caddr_t) args;
  dtp_t dtp = DV_TYPE_OF (box);
  int len = 0, is_text = 0;
  static caddr_t l_null;
  static cu_func_t *cf;
  AUTO_POOL (12);
  if (!cf)
    {
      l_null = dk_alloc_box (0, DV_DB_NULL);
      cf = cu_func ("L_O_LOOK", 1);
    }
  if (DV_RDF == dtp)
    {
      rdf_box_t *rb = (rdf_box_t *) box;
      caddr_t content = rb->rb_box;
      dtp_t cdtp = DV_TYPE_OF (content);
      if (rb->rb_ro_id)
	{
	  cu_set_value (cu, vs, box_copy_tree (box));
	  return NULL;
	}
      dt_lang = rb->rb_type << 16 | rb->rb_lang;
      if (DV_XML_ENTITY == cdtp && rb->rb_chksum_tail)
	{
	  QNCAST (rdf_bigbox_t, rbb, rb);
	  if (!rb->rb_ro_id)
	    cu_local_dispatch (cu, vs, cf, (caddr_t) ap_list (&ap, 5, rbb->rbb_chksum, ap_box_num (&ap, dt_lang), content, (caddr_t)(ptrlong)rb->rb_is_text_index, ap_box_num (&ap, 0)));
	  else
	    cu_set_value (cu, vs, box_copy_tree (box));
	  return NULL;
	}
      if (DV_GEO != cdtp
	  && (DV_STRING != cdtp
	      || (!rdf_no_string_inline && (box_length (content) - 1 < RB_MAX_INLINED_CHARS && !rb->rb_is_text_index))))
	{
	  rb->rb_is_text_index = 0;	/* not a string and not xml */
	  cu_set_value (cu, vs, box_copy_tree (box));
	  return NULL;
	}
      if ((DV_STRING == cdtp || DV_GEO == cdtp) && rb->rb_ro_id)
	{
	  cu_set_value (cu, vs, box_copy_tree (box));
	  return NULL;
	}
      rb->rb_is_outlined = 1;
      if (DV_GEO == cdtp)
	{
	  caddr_t err = NULL;
	  content = box_to_any_1 (content, &err, NULL, DKS_TO_DC);
	  allocd_content = content;
	  is_text = 2;
	}
      else
	is_text = rb->rb_is_text_index;
      len = box_length (content) - 1;
      if (len > RB_BOX_HASH_MIN_LEN)
	{
	  caddr_t trid = mdigest5 (content);
	  cu_local_dispatch (cu, vs, cf, (caddr_t) ap_list (&ap, 5, trid, ap_box_num (&ap, dt_lang), content, (caddr_t)(ptrlong)is_text, NULL));
	  dk_free_box (trid);
	  dk_free_box (allocd_content);
	  return NULL;
	}
      cu_local_dispatch (cu, vs, cf, (caddr_t) ap_list (&ap, 5, content, ap_box_num (&ap, dt_lang), l_null, (caddr_t)(ptrlong)is_text, NULL));
      dk_free_box (allocd_content);
      return NULL;
    }
  if (DV_GEO == dtp)
    {
      /* A trick instead of sqlr_new_error ("22023", "CLGEO", "A geometry without rdf box is not allowed as object of quad"); */
      caddr_t err = NULL;
      caddr_t content = box_to_any_1 (box, &err, NULL, DKS_TO_DC);
      dt_lang = RDF_BOX_GEO << 16 | RDF_BOX_DEFAULT_LANG;
      allocd_content = content;
      len = box_length (content) - 1;
      is_text = 2;
      if (len > RB_BOX_HASH_MIN_LEN)
        {
          caddr_t trid = mdigest5 (content);
          cu_local_dispatch (cu, vs, cf, (caddr_t) ap_list (&ap, 5, trid, ap_box_num (&ap, dt_lang), content, (caddr_t)(ptrlong)is_text, NULL));
          dk_free_box (trid);
        }
      else
        cu_local_dispatch (cu, vs, cf, (caddr_t) ap_list (&ap, 5, content, ap_box_num (&ap, dt_lang), l_null, (caddr_t)(ptrlong)is_text, NULL));
      dk_free_box (allocd_content);
      return NULL;
    }
  else if (DV_STRING == dtp)
    len = box_length (box) - 1;
  if (DV_STRING != dtp || (!rdf_no_string_inline && len < RB_MAX_INLINED_CHARS))
    {
      cu_set_value (cu, vs, box_copy_tree (box));
      return NULL;
    }
  if (BF_IRI == box_flags (box))
    return l_iri_id_disp (cu, box, vs);

  dt_lang = (RDF_BOX_DEFAULT_TYPE << 16) | RDF_BOX_DEFAULT_LANG;
  if (len > RB_BOX_HASH_MIN_LEN)
    {
      caddr_t trid = mdigest5 (box);
      cu_local_dispatch (cu, vs, cf, (caddr_t) ap_list (&ap, 5, trid, ap_box_num (&ap, dt_lang), vs->vs_org_value, (caddr_t) 1, NULL));
      dk_free_box (trid);
      return NULL;
    }
  cu_local_dispatch (cu, vs, cf, (caddr_t) ap_list (&ap, 5, box, ap_box_num (&ap, dt_lang), l_null, (caddr_t) 1, NULL));
  return NULL;
}


caddr_t
l_iri_id_disp (cucurbit_t * cu, caddr_t name, value_state_t * vs)
{
  static cu_func_t *cf;
  static cu_func_t *cf_np;
  boxint pref_id_no, iri_id_no;
  caddr_t prefix, local;
  dtp_t dtp = DV_TYPE_OF (name);
  caddr_t box_to_delete = NULL, name_to_delete = NULL;
  if (!cf)
    {
      cf = cu_func ("L_I_LOOK", 1);
      cf_np = cu_func ("L_I_LOOK_NP", 1);
    }

  switch (dtp)
    {
    case DV_IRI_ID:
    case DV_DB_NULL:
      {
	cu_set_value (cu, vs, box_copy (name));
	return NULL;
      }
    case DV_WIDE:
      box_to_delete = name = box_wide_as_utf8_char (name, (box_length (name) / sizeof (wchar_t)) - 1, DV_STRING);
    case DV_STRING:
    case DV_UNAME:
      break;
    default:
      sqlr_new_error ("42000", "CL...", "expected string for arg of disp fn");
    }
  if (!strncmp (name, "nodeID://", 9))
    {
      unsigned char *tail = (unsigned char *) (name + 9);
      int64 acc = 0;
      int b_first = 0;
      if ('b' == tail[0])
	{
	  b_first = 1;
	  tail++;
	}
      while (isdigit (tail[0]))
	acc = acc * 10 + ((tail++)[0] - '0');
      if ('\0' != tail[0])
	{
	  if (NULL != box_to_delete)
	    dk_free_box (box_to_delete);
	  sqlr_new_error ("42000", "CL...", "Invalid tail of nodeID:// IRI");
	}
      if (b_first)
	acc += MIN_64BIT_BNODE_IRI_ID;
      if ((acc > (2 * min_bnode_iri_id ())) || (acc < min_bnode_iri_id ()))
	{
	  if (NULL != box_to_delete)
	    dk_free_box (box_to_delete);
	  sqlr_new_error ("42000", "CL...", "Invalid numeric value in the tail of nodeID:// IRI");
	}
      cu_set_value (cu, vs, box_iri_id (acc));
      return NULL;
    }
  /* dynamic local  */
  if (uriqa_dynamic_local)
    {
      int ofs = uriqa_iri_is_local (NULL, name);
      if (0 != ofs)
        {
          int name_box_len = box_length (name);
/*  0123456 */
/* "local:" */
          caddr_t localized_name = dk_alloc_box (6 + name_box_len - ofs, DV_STRING);
          memcpy (localized_name, "local:", 6);
          memcpy (localized_name + 6, name + ofs, name_box_len - ofs);
          name_to_delete = name = localized_name;
        }
    }
  if (!iri_split (name, &prefix, &local))
    goto return_error;		/* see below */
  dk_free_box (box_to_delete);
  dk_free_box (name_to_delete);
  pref_id_no = nic_name_id (iri_prefix_cache, prefix);
  if (!pref_id_no)
    {
      AUTO_POOL (8);
      cu_local_dispatch (cu, vs, cf_np, (caddr_t) ap_list (&ap, 3, prefix, local, ap_box_num (&ap, 0)));
      dk_free_box (local);
      dk_free_box (prefix);
      return NULL;
    }
  dk_free_box (prefix);
  LONG_SET_NA (local, pref_id_no);
  iri_id_no = 0;		/*nic_name_id (iri_name_cache, local); */
  if (iri_id_no)
    {
      dk_free_box (local);
      cu_set_value (cu, vs, box_iri_id (iri_id_no));
      return NULL;
    }
  {
    AUTO_POOL (8);
    cu_local_dispatch (cu, vs, cf, (caddr_t) ap_list (&ap, 2, local, NULL));
    dk_free_box (local);
  }
  return NULL;

return_error:
      dk_free_box (name_to_delete);
  dk_free_box (box_to_delete);
  return list (2, NULL, box_num (1));
}


caddr_t
bif_rl_set_pref_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx;
  QNCAST (query_instance_t, qi, qst);
  data_col_t *names = bif_dc_arg (qst, args, 0, "__rl_set_pref_id");
  data_col_t *ids = bif_dc_arg (qst, args, 1, "__rl_set_pref_id");
  for (inx = 0; inx < names->dc_n_values; inx++)
    {
      caddr_t str;
      int64 id;
      if (!QI_IS_SET (qi, inx))
	continue;
      str = (caddr_t) (ptrlong) dc_any_value (names, inx);
      id = dc_any_value (ids, inx);
      if (DV_ANY == names->dc_dtp)
	{
	  long l, hl;
	  db_buf_length ((db_buf_t) str, &hl, &l);
	  if (l < 4)
	    sqlr_new_error ("42000", ".....", "Must have a string of at least 4 chars to set prefix");
	  str[hl] = id >> 24;
	  str[hl + 1] = id >> 16;
	  str[hl + 2] = id >> 8;
	  str[hl + 3] = id;
	}
      else
	sqlr_new_error ("42000", ".....", "__rl_set_pref_id expects a any type column");
    }
  return NULL;
}


caddr_t
bif_rl_dp_ids (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cl_req_group_t *clrg = bif_clrg_arg (qst, args, 0, "rl_ids");
  caddr_t g_iid = bif_arg (qst, args, 1, "rl_ids");
  cucurbit_t *cu = clrg->clrg_cu;
  void * save;
  if (!cu)
    sqlr_new_error ("42000", "CL...", "Not a dpipe daq");
  cu->cu_qst = qst;
  save = cu->cu_ready_cb;
  cu->cu_ready_cb = NULL; /* local exec, CBs are for clustered operation */
  cu_rl_local_exec (cu);
  cu_rl_cols (cu, g_iid);
  cu->cu_ready_cb = save;
  return NULL;
}



caddr_t
bif_dc_batch_sz (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return box_num (dc_batch_sz);
}


void
bif_rld_init ()
{
  bif_define_ex ("dc_batch_sz", bif_dc_batch_sz, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define ("rl_dp_ids", bif_rl_dp_ids);
  bif_define ("__rl_set_pref_id", bif_rl_set_pref_id);
  bif_set_vectored (bif_rl_set_pref_id, (bif_vec_t) bif_rl_set_pref_id);
  dpipe_define ("L_IRI_TO_ID", NULL, "", (cu_op_func_t) l_iri_id_disp, CF_1_ARG);
  dpipe_define ("L_I_LOOK", NULL, "DB.DBA.RL_I2ID", (cu_op_func_t) NULL, 0);
  dpipe_signature ("L_I_LOOK", 2, DV_STRING, DV_IRI_ID_8);
  dpipe_define ("L_I_LOOK_NP", NULL, "DB.DBA.RL_I2ID_NP", (cu_op_func_t) NULL, 0);
  dpipe_signature ("L_I_LOOK_NP", 3, DV_STRING, DV_STRING, DV_IRI_ID_8);


  dpipe_define ("L_MAKE_RO", NULL, "", (cu_op_func_t) l_make_ro_disp, CF_1_ARG);
  dpipe_define ("L_O_LOOK", NULL, "DB.DBA.L_O_LOOK", (cu_op_func_t) NULL, 0);
  dpipe_signature ("L_O_LOOK", 5, DV_STRING, DV_LONG_INT, DV_STRING, DV_LONG_INT, DV_LONG_INT);
  ssl_set_no_dummy.ssl_dc_dtp = ssl_set_no_dummy.ssl_sqt.sqt_dtp = DV_LONG_INT;
  ssl_iri_dummy.ssl_dc_dtp = ssl_iri_dummy.ssl_sqt.sqt_dtp = DV_IRI_ID;
  ssl_any_dummy.ssl_dc_dtp = ssl_any_dummy.ssl_sqt.sqt_dtp = DV_ANY;
}
