/*
 *  rdfinf.c
 *
 *  $Id$
 *
 *  RDF Inference
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

#include "sqlnode.h"
#include "sqlbif.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlo.h"
#include "list2.h"
#include "xmlnode.h"
#include "xmltree.h"
#include "arith.h"
#include "rdfinf.h"
#include "rdf_core.h"
#include "security.h"


caddr_t *
ht_keys_to_array (dk_hash_t * ht)
{
  caddr_t * arr = (caddr_t*) dk_alloc_box (ht->ht_count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  int fill = 0;
  DO_HT (caddr_t, key, caddr_t, d, ht)
    {
      arr[fill++] = key;
    }
  END_DO_HT;
  return arr;
}


dk_set_t
rs_first_sub (rdf_sub_t * rs, int mode, char * is_eq_ret)
{
  dk_set_t sub = (mode == RI_SUBCLASS || mode == RI_SUBPROPERTY)
    ?  rs->rs_sub : rs->rs_super;
  if (sub)
    {
      is_eq_ret = 0;
      return sub;
    }
  if (!rs->rs_equiv)
    return NULL;
  *is_eq_ret = 1;
  return rs->rs_equiv;
}


int
rit_down (ri_iterator_t * rit)
{
  ri_state_t * ris = rit->rit_state;
  char is_equiv = 0;
  dk_set_t sub = rs_first_sub (rit->rit_value, rit->rit_mode, &is_equiv);
  if (!sub)
    return 0;
  if (ris && ris->ris_position && !ris->ris_position->next
      && (ris->ris_is_equiv || !rit->rit_value->rs_equiv))
    {
      ris->ris_node = rit->rit_value;
      rit->rit_value = (rdf_sub_t*) sub->data;
      ris->ris_position = sub;
      ris->ris_is_equiv = is_equiv;
      return 1;
    }
  {
    NEW_VARZ (ri_state_t, ris);
    ris->ris_prev = rit->rit_state;
    rit->rit_state = ris;
    ris->ris_node = rit->rit_value;
    rit->rit_value = (rdf_sub_t*)sub->data;
    ris->ris_position = sub;
    ris->ris_is_equiv = is_equiv;
    return 1;
  }
}


int
rit_right (ri_iterator_t * rit)
{
  ri_state_t * ris = rit->rit_state;
  if (!ris  || !ris->ris_position)
    return 0;
  ris->ris_position = ris->ris_position->next;
  if (!ris->ris_position)
    {
      if (ris->ris_is_equiv || !ris->ris_node->rs_equiv)
	return 0;
      ris->ris_is_equiv = 1;
      ris->ris_position = ris->ris_node->rs_equiv;
    }
  rit->rit_value = (rdf_sub_t*)ris->ris_position->data;
  return 1;
}

int
rit_up (ri_iterator_t * rit)
{
  ri_state_t * ris = rit->rit_state;
  if (!ris || !ris->ris_prev)
    return 0;
  rit->rit_state = ris->ris_prev;
  dk_free ((caddr_t)ris, sizeof (ri_state_t));
  return 1;
}


rdf_sub_t *
rit_next (ri_iterator_t * rit)
{
  rdf_sub_t * val;
  if (rit->rit_at_start)
    {
      rit->rit_at_start = 0;
      goto end;
    }
 again:
  if (rit->rit_next_sibling)
    {
      rit->rit_next_sibling = 0;
      goto right;
    }
  if (rit->rit_at_end)
    return NULL;
  if (!rit_down (rit))
    {
    right:
      if (!rit_right (rit))
	{
	up_again:
	  if (!rit_up (rit))
	    {
	      rit->rit_at_end = 1;
	      return NULL;
	    }
	  else
	    {
	      if (!rit_right (rit))
		goto up_again;
	      else
		goto end;
	    }
	}
    }
 end:
  val = rit->rit_value;
  if (rit->rit_visited)
    {
      if (id_hash_get (rit->rit_visited, (caddr_t)&val->rs_iri))
	{
	  rit->rit_next_sibling = 1;
	  goto again;
	}
      id_hash_set (rit->rit_visited, (caddr_t)&val->rs_iri, (caddr_t)&val->rs_iri);
    }
  return val;
}


ri_iterator_t *
ri_iterator (rdf_sub_t * rs, int mode, int distinct)
{
  ri_iterator_t * rit = (ri_iterator_t*) dk_alloc_box_zero (sizeof (ri_iterator_t), DV_RI_ITERATOR);
  rit->rit_at_start = 1;
  rit->rit_value = rs;
  rit->rit_mode = mode;
  if (distinct)
    {
      rit->rit_visited = id_hash_allocate (22, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      id_hash_set_rehash_pct (rit->rit_visited, 200);
    }
  return rit;
}


int
rit_free (caddr_t x)
{
  QNCAST (ri_iterator_t, rit, x);
  ri_state_t * ris = rit->rit_state;
  while (ris)
    {
      ri_state_t * next = ris->ris_prev;
      dk_free ((caddr_t)ris, sizeof (ri_state_t));
      ris = next;
    }
  if (rit->rit_visited)
    id_hash_free (rit->rit_visited);
  return 0;
}


void  cl_rdf_inf_init_1 (caddr_t * qst);


#define RI_INIT_NEEDED(qst)			\
  if (!cl_rdf_inf_inited) cl_rdf_inf_init_1 (qst);


dk_set_t
ri_list (rdf_inf_pre_node_t * ri, caddr_t iri, rdf_sub_t ** sub_ret)
{
  rdf_sub_t * sub = ric_iri_to_sub (ri->ri_ctx, iri, ri->ri_mode, 0);
  *sub_ret = sub;
  if (sub)
    {
      switch (ri->ri_mode)
	{
	  case RI_SUBCLASS: return sub->rs_sub ? sub->rs_sub : sub->rs_equiv;
	case RI_SUPERCLASS: return sub->rs_super;
	  case RI_SUBPROPERTY: return sub->rs_sub ? sub->rs_sub : sub->rs_equiv;
	case RI_SUPERPROPERTY: return sub->rs_super;
	}
    }
  return NULL;
}


caddr_t rdfs_type;



void
ri_outer_output (rdf_inf_pre_node_t * ri, state_slot_t * any_flag, caddr_t * inst)
{
  data_source_t *qn = (data_source_t *) ri;
  data_source_t *next_qn = NULL;
  table_source_t *ts = NULL;
  hash_source_t *hs = NULL;
  data_source_t *en = NULL;
  code_vec_t after = NULL;
  if (!any_flag || qst_get (inst, any_flag))
    return;
  /* the ts or hs after ri is outer.  Must call the appropriate outer output.  */
  while ((qn = qn_next ((data_source_t *) qn)))
    {
      if (IS_TS ((table_source_t *) qn) || IS_HS ((table_source_t *) qn))
	{
	  ts = (table_source_t *) qn;
	  next_qn = qn_next (en = qn_next ((data_source_t *) ts));
	  break;
	}
    }

  if ((qn_input_fn) end_node_input == en->src_input && en->src_after_code)
    after = en->src_after_code;
  if (!next_qn && !after)
    return;
  if (IS_TS (ts))
    {
      DO_SET (state_slot_t *, sl, &ts->ts_order_ks->ks_out_slots)
	{
	  qst_set_bin_string (inst, sl, (db_buf_t) "", 0, DV_DB_NULL);
	}
      END_DO_SET ();
      if (ts->ts_main_ks)
	{
	  DO_SET (state_slot_t *, sl, &ts->ts_main_ks->ks_out_slots)
	    {
	      qst_set_bin_string (inst, sl, (db_buf_t) "", 0, DV_DB_NULL);
	    }
	  END_DO_SET ();
	}
    }
  else
    {
      int inx;
      hs = (hash_source_t *) ts;
      DO_BOX (state_slot_t *, out, inx, hs->hs_out_slots)
	{
	  qst_set_bin_string (inst, out, (db_buf_t) "", 0, DV_DB_NULL);
	}
      END_DO_BOX;
    }
  if (after)
    code_vec_run (after, inst);
  if (next_qn)
    qn_input (next_qn, inst, inst);
  /* the join test for this is in the 2nd end node after */
}


caddr_t
iri_ensure (caddr_t * qst, caddr_t name, int flag, caddr_t * err_ret)
{
  /* see if stock iri exists with read only.  Will work in fault tolerant mode when can't write.  Only then try to write */
  caddr_t iri = iri_to_id (qst, name, 0, err_ret);
  if (iri && DV_DB_NULL != DV_TYPE_OF (iri))
    return iri;
  return iri_to_id (qst, name, flag, err_ret);
}


char * sas_1_text = "select S from DB.DBA.RDF_QUAD where G = ? and O = ? and P = ? option (quietcast)";
char * sas_2_text = "select O from DB.DBA.RDF_QUAD where G = ? and S = ? and P = ? option (quietcast)";
char * sas_tn_text = "select O from DB.DBA.RDF_QUAD where S = :0 and P = rdf_sas_iri () and G in (:1) and isiri_id (O) union all select S from DB.DBA.RDF_QUAD where O = :0 and P = rdf_sas_iri () and G in (:1) option (quietcast, array)";
char * sas_tn_no_graph_text = "select O from DB.DBA.RDF_QUAD where S = :0 and P = rdf_sas_iri () union all select S from DB.DBA.RDF_QUAD where O = :0 and P = rdf_sas_iri () option (quietcast, array)";
char * tn_ifp_text =
  " select S from DB.DBA.RDF_QUAD table option (index RDF_QUAD_POGS)"
  " where P in (rdf_inf_ifp_list (:1)) and O = :0 and not isiri_id (:0) and G in (:2) and not rdf_inf_ifp_is_excluded (:1, P, :0) "
  " union all select syn.S from DB.DBA.RDF_QUAD org table option (index RDF_QUAD), DB.DBA.RDF_QUAD syn table option (index RDF_QUAD_POGS)"
  " where org.P in (rdf_inf_ifp_list (:1)) and syn.P = org.P and org.S = :0 and isiri_id (:0) and syn.O = org.O and org.G in (:2) and syn.G in (:2) and not rdf_inf_ifp_is_excluded (:1, org.P, org.O)"
  " union all select rsyn.S from DB.DBA.RDF_QUAD rorg table option (index RDF_QUAD), DB.DBA.RDF_QUAD rsyn table option (index RDF_QUAD_POGS)"
  " where rorg.P in (rdf_inf_ifp_rel_list (:1)) and rsyn.P in (rdf_inf_ifp_rel_list (:1, rorg.P)) and rorg.S = :0 and isiri_id (:0) and rsyn.O = rorg.O and rorg.G in (:2) and rsyn.G in (:2) and not rdf_inf_ifp_is_excluded (:1, rorg.P, rorg.O) "
  " option (any order)";
char * tn_ifp_no_graph_text =
  "select S from DB.DBA.RDF_QUAD "
  " where P in (rdf_inf_ifp_list (:1)) and o = :0 and not isiri_id (:0) and not rdf_inf_ifp_is_excluded (:1, P, :0) "
  " union all select syn.s from DB.DBA.RDF_QUAD org, DB.DBA.RDF_QUAD syn "
  " where org.P in (rdf_inf_ifp_list (:1)) and syn.P = org.P and org.S = :0 and isiri_id (:0) and syn.o = org.O and not rdf_inf_ifp_is_excluded (:1, org.P, org.O) "
  " union all select rsyn.s from DB.DBA.RDF_QUAD rorg table option (index RDF_QUAD), DB.DBA.RDF_QUAD rsyn table option (index RDF_QUAD_POGS)"
  " where rorg.P in (rdf_inf_ifp_rel_list (:1)) and rsyn.P in (rdf_inf_ifp_rel_list (:1, rorg.P)) and rorg.S = :0 and isiri_id (:0) and rsyn.o = rorg.O and not rdf_inf_ifp_is_excluded (:1, rorg.P, rorg.O) "
  " option (any order)";
char * tn_ifp_dist_text =
  " select syn.s from DB.DBA.RDF_QUAD org, DB.DBA.RDF_QUAD syn "
  " where org.P in (rdf_inf_ifp_list (:1)) and syn.P = org.P and org.s = :0 and isiri_id (:0) and syn.O = org.O and org.G in (:2) and syn.G in (:2) and not rdf_inf_ifp_is_excluded (:1, org.P, org.O) "
  " union all select rsyn.S from DB.DBA.RDF_QUAD rorg, DB.DBA.RDF_QUAD rsyn "
  " where rorg.P in (rdf_inf_ifp_rel_list (:1)) and rsyn.P in (rdf_inf_ifp_rel_list (:1, rorg.P)) and rorg.S = :0 and isiri_id (:0) and rsyn.O = rorg.O and rorg.G in (:2) and rsyn.G in (:2) and not rdf_inf_ifp_is_excluded (:1, rorg.P, rorg.O) "
  " option (any order)";
char * tn_ifp_dist_no_graph_text =
  " select syn.s from DB.DBA.RDF_QUAD org, DB.DBA.RDF_QUAD syn where org.p in (rdf_inf_ifp_list (:1)) and syn.p = org.p and org.s = :0 and isiri_id (:0) and syn.o = org.o and not rdf_inf_ifp_is_excluded (:1, org.P, org.O) "
  " union all select rsyn.s from DB.DBA.RDF_QUAD rorg, DB.DBA.RDF_QUAD rsyn "
  " where rorg.P in (rdf_inf_ifp_rel_list (:1)) and rsyn.P in (rdf_inf_ifp_rel_list (:1, rorg.P)) and rorg.S = :0 and isiri_id (:0) and rsyn.o = rorg.O and not rdf_inf_ifp_is_excluded (:1, rorg.P, rorg.O) "
  " option (any order)";

query_t * sas_1_qr;
query_t * sas_2_qr;
query_t * sas_tn_qr;
query_t * sas_tn_no_graph_qr;
query_t * tn_ifp_qr;
query_t * tn_ifp_no_graph_qr;
query_t * tn_ifp_dist_qr;
query_t * tn_ifp_dist_no_graph_qr;

id_hash_t * sas_tn_ht;
id_hash_t * sas_tn_no_graph_ht;
id_hash_t * tn_ifp_ht;
id_hash_t * tn_ifp_no_graph_ht;
dk_mutex_t * tn_cache_mtx;

void
sas_ensure ()
{
  caddr_t err;
  if (!sas_1_qr)
    {
      sas_1_qr = sql_compile (sas_1_text, bootstrap_cli, &err, SQLC_DEFAULT);
      sas_2_qr = sql_compile (sas_2_text, bootstrap_cli, &err, SQLC_DEFAULT);
      sas_tn_qr = sql_compile (sas_tn_text, bootstrap_cli, &err, SQLC_DEFAULT);
      sas_tn_no_graph_qr = sql_compile (sas_tn_no_graph_text, bootstrap_cli, &err, SQLC_DEFAULT);
      tn_ifp_qr = sql_compile (tn_ifp_text, bootstrap_cli, &err, SQLC_DEFAULT);
      tn_ifp_no_graph_qr = sql_compile (tn_ifp_no_graph_text, bootstrap_cli, &err, SQLC_DEFAULT);
      tn_ifp_dist_qr = sql_compile (tn_ifp_dist_text, bootstrap_cli, &err, SQLC_DEFAULT);
      tn_ifp_dist_no_graph_qr = sql_compile (tn_ifp_dist_no_graph_text, bootstrap_cli, &err, SQLC_DEFAULT);

      sas_tn_ht = id_hash_allocate (31, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      sas_tn_no_graph_ht = id_hash_allocate (31, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      tn_ifp_ht = id_hash_allocate (31, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      tn_ifp_no_graph_ht = id_hash_allocate (31, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      tn_cache_mtx = mutex_allocate ();
      cl_dcf_id ((col_ref_t)sas_1_qr);
      cl_dcf_id ((col_ref_t)sas_2_qr);
      cl_dcf_id ((col_ref_t)sas_tn_qr);
      cl_dcf_id ((col_ref_t)sas_tn_no_graph_qr);
      cl_dcf_id ((col_ref_t)tn_ifp_qr);
      cl_dcf_id ((col_ref_t)tn_ifp_no_graph_qr);
      cl_dcf_id ((col_ref_t)tn_ifp_dist_qr);
      cl_dcf_id ((col_ref_t)tn_ifp_dist_no_graph_qr);
    }
}

id_hash_t *
tn_hash_table_get (trans_node_t * tn)
{
  if (sas_tn_qr == tn->tn_prepared_step) return sas_tn_ht;
  if (sas_tn_no_graph_qr == tn->tn_prepared_step) return sas_tn_no_graph_ht;
  if (tn_ifp_qr == tn->tn_prepared_step) return tn_ifp_ht;
  if (tn_ifp_no_graph_qr == tn->tn_prepared_step) return tn_ifp_no_graph_ht;
  return NULL;
}

caddr_t same_as_iri;
caddr_t owl_sub_class_iri = NULL;
caddr_t owl_sub_property_iri = NULL;
caddr_t owl_equiv_class_iri = NULL;
caddr_t owl_equiv_property_iri = NULL;


void
hash_queue_add (id_hash_t * ht, query_instance_t * qi, int last, caddr_t item)
{
  caddr_t n_box;
  ptrlong n = QST_INT (qi, last);
  n_box = box_num (n);
  /*item = box_copy_tree (item);*/
  id_hash_set (ht, (caddr_t)&n_box, (caddr_t) &item);
  QST_INT (qi, last) = n + 1;
}


caddr_t
hash_queue_get (id_hash_t * ht, query_instance_t * qi, int next, int last)
{
  ptrlong n = QST_INT (qi, next);
  ptrlong max = QST_INT (qi, last);
  caddr_t n_box;
  caddr_t * place;
  if (n >= max)
    return NULL;
  n_box = box_num (n);
  place = (caddr_t *) id_hash_get (ht, (caddr_t)&n_box);
  if (place)
    {
      caddr_t res = *place;
      caddr_t k = place[-1]; /* the num box that is the key of the ht.  Free after removing the ht entry */
      id_hash_remove (ht, (caddr_t)&n_box);
      dk_free_box (n_box);
      dk_free_box (k);
      QST_INT (qi, next) = n + 1;
      return res;
    }
  dk_free_box (n_box);
  return NULL;
}


void rdf_sas_ensure (caddr_t * qst, caddr_t * err_ret);

void
ri_same_as_iri (rdf_inf_pre_node_t * ri, query_instance_t * qi, caddr_t iri, query_t * qr)
{
  caddr_t * qst = (caddr_t *)qi;
  ptrlong one = 1;
  caddr_t err = NULL;
  local_cursor_t * lc;
  id_hash_t * reached = (id_hash_t *) QST_GET (qst, ri->ri_sas_reached);
  id_hash_t * out = (id_hash_t *) QST_GET (qst, ri->ri_sas_out);
  id_hash_t * follow = (id_hash_t *) QST_GET (qst, ri->ri_sas_follow);
  int ginx;
  rdf_sas_ensure (qst, &err);
  if (err)
    sqlr_resignal (err);
  DO_BOX (state_slot_t *, g_ssl, ginx, ri->ri_sas_g)
    {
      caddr_t g = qst_get (qst, g_ssl);
      err = qr_rec_exec (qr, qi->qi_client, &lc, qi, NULL, 3,
			 ":0", box_copy (g), QRP_RAW,
			 ":1", box_copy (iri), QRP_RAW,
			 ":2", box_copy (same_as_iri), QRP_RAW);
      if (err)
	sqlr_resignal (err);
      while (lc_next (lc))
	{
	  caddr_t iri = lc_nth_col (lc, 0);
	  if (DV_IRI_ID != DV_TYPE_OF (iri))
	    continue;
	  if (id_hash_get (reached,  (caddr_t)&iri))
	    continue;
	  iri = box_copy (iri);
	  id_hash_set (reached, (caddr_t)&iri, (caddr_t)&one);
	  iri = box_copy_tree (iri);
	  hash_queue_add (follow, qi, ri->ri_sas_last_follow, iri);
	  iri = box_copy_tree (iri);
	  hash_queue_add (out, qi, ri->ri_sas_last_out, iri);
	}
      if (lc->lc_error != SQL_SUCCESS)
	err = lc->lc_error;
      lc_free (lc);
      if (err)
	sqlr_resignal (err);
    }
  END_DO_BOX;
}


void
ri_follow_sas (rdf_inf_pre_node_t * ri, query_instance_t * qi, caddr_t iri)
{
  if (!sas_1_qr || !sas_2_qr)
    {
      log_error ("internal error: same-as inference disabled because same-as queries not compiled");
      return;
    }
  ri_same_as_iri (ri, qi, iri, sas_1_qr);
  ri_same_as_iri (ri, qi, iri, sas_2_qr);
}


void
ri_same_as_input (rdf_inf_pre_node_t * ri, caddr_t * inst,
		  caddr_t * volatile state)
{
  caddr_t start, next;
  query_instance_t * qi = (query_instance_t *) inst;
  ptrlong one = 1;
  caddr_t next_out;
  id_hash_t * reached = NULL, *follow = NULL, *out = NULL;
  sas_ensure ();
  for (;;)
    {
      if (state)
	{
	  if (ri->ri_outer_any_passed)
	    qst_set (inst, ri->ri_outer_any_passed, NULL);
	  qst_set (inst, ri->ri_sas_out, (caddr_t) (out = (id_hash_t *)box_dv_dict_hashtable (31)));
	  qst_set (inst, ri->ri_sas_reached, (caddr_t) (reached = (id_hash_t *)box_dv_dict_hashtable (31)));
	  qst_set (inst, ri->ri_sas_follow, (caddr_t) (follow = (id_hash_t *)box_dv_dict_hashtable (31)));
	  QST_INT (inst, ri->ri_sas_last_out) = 0;
	  QST_INT (inst, ri->ri_sas_next_out) = 0;
	  QST_INT (inst, ri->ri_sas_last_follow) = 0;
	  QST_INT (inst, ri->ri_sas_next_follow) = 0;

	  start = box_copy_tree (qst_get (inst, ri->ri_sas_in));
	  hash_queue_add (follow, qi, ri->ri_sas_last_follow, start);
	  start = box_copy_tree (start);
	  id_hash_set (reached, (caddr_t)&start, (caddr_t)&one);
	  if (DV_TYPE_OF (start) != DV_IRI_ID && DV_TYPE_OF (start) != DV_IRI_ID_8)
	    SRC_IN_STATE ((data_source_t *)ri, inst) = NULL;
	  else
	    SRC_IN_STATE ((data_source_t *)ri, inst) = inst;
	  qst_set (inst, ri->ri_output, box_copy_tree (start));
	  qn_send_output ((data_source_t*)ri, inst);
	  if (DV_TYPE_OF (start) != DV_IRI_ID && DV_TYPE_OF (start) != DV_IRI_ID_8)
	    return;
	  state = NULL;
	  continue;
	}
      out = (id_hash_t *) qst_get (inst, ri->ri_sas_out);
      follow = (id_hash_t *) qst_get (inst, ri->ri_sas_follow);
      reached = (id_hash_t *) qst_get (inst, ri->ri_sas_reached);
      next_out = hash_queue_get (out, qi, ri->ri_sas_next_out, ri->ri_sas_last_out);
      if (next_out)
	{
	  qst_set (inst, ri->ri_output, next_out);
	  qn_send_output ((data_source_t *)ri, inst);
	  continue;
	}
      /* no queued outputs, follow the follow set until there is at least one new output */
      next = hash_queue_get (follow, qi, ri->ri_sas_next_follow, ri->ri_sas_last_follow);
      if (!next)
	{
	  SRC_IN_STATE ((data_source_t *)ri, inst) = NULL;
	  ri_outer_output (ri, ri->ri_outer_any_passed, inst);
	  return;
	}
      ri_follow_sas (ri, qi, next);
      dk_free_tree (next);
      continue;
    }
}

void
rdf_inf_vec_input (rdf_inf_pre_node_t * ri, caddr_t * inst, caddr_t * volatile state)
{
  QNCAST (data_source_t, qn, ri);
  QNCAST (query_instance_t, qi, inst);
  int nth_val, nth_set, n_sets = QST_INT (inst, qn->src_prev->src_out_fill), batch_sz;
  data_col_t * out_dc = NULL;
  caddr_t * array;

  if (state)
    {
      nth_val = QST_INT (inst, ri->ri_current_value) = 0;
      nth_set = QST_INT (inst, ri->ri_current_set) = 0;
    }
  else
    {
      nth_val = QST_INT (inst, ri->ri_current_value);
      nth_set = QST_INT (inst, ri->ri_current_set);
    }
again:
  batch_sz = qn->src_batch_size ? QST_INT (inst, qn->src_batch_size) : dc_batch_sz;
  if (!batch_sz)
    batch_sz = dc_batch_sz;
  QST_INT (inst, qn->src_out_fill) = 0;
  dc_reset_array (inst, qn, qn->src_continue_reset, -1);
  for (; nth_set < n_sets; nth_set ++)
    {
      qi->qi_set = nth_set;
      out_dc = QST_BOX (data_col_t *, inst, ri->ri_output->ssl_index);
      if (!nth_val)
	{
	  rdf_sub_t *x, *sub = NULL;
	  dk_set_t res = NULL;
	  ri_iterator_t * rit;
	  caddr_t iri = NULL;

	  if (ri->ri_given)
	    {
	      iri = ri->ri_given;
	      sub = ric_iri_to_sub (ri->ri_ctx, iri, ri->ri_mode, 0);
	    }
	  else
	    {
	      if ((RI_SUPERCLASS == ri->ri_mode  || RI_SUBCLASS == ri->ri_mode) && (!ri->ri_p || box_equal (rdfs_type, qst_get (inst, ri->ri_p))))
		{
		  iri = qst_get (inst, ri->ri_o);
		  sub = ric_iri_to_sub (ri->ri_ctx, iri, ri->ri_mode, 0);
		}
	      if (!sub && (RI_SUPERPROPERTY == ri->ri_mode || RI_SUBPROPERTY == ri->ri_mode))
		{
		  iri = qst_get (inst, ri->ri_p);
		  sub = ric_iri_to_sub (ri->ri_ctx, iri, ri->ri_mode, 0);
		}
	    }

	  if (!sub)
	    {
	      if (ri->ri_given)
		{
		  dc_append_box (out_dc, ri->ri_given);
		  qn_result (qn, inst, nth_set);
		}
	      else if (RI_SUBCLASS == ri->ri_mode || RI_SUPERCLASS == ri->ri_mode)
		{
		  dc_append_box (out_dc, qst_get (inst, ri->ri_o));
		  qn_result (qn, inst, nth_set);
		}
	      else if (RI_SUBPROPERTY == ri->ri_mode || RI_SUPERPROPERTY == ri->ri_mode)
		{
		  dc_append_box (out_dc, qst_get (inst, ri->ri_p));
		  qn_result (qn, inst, nth_set);
		}
	      if (QST_INT (inst, qn->src_out_fill) >= batch_sz)
		{
		  QST_INT (inst, ri->ri_current_value) = 0;
		  nth_set++;
		  QST_INT (inst, ri->ri_current_set) = nth_set;
		  if (nth_set < n_sets)
		    SRC_IN_STATE (qn, inst) = inst;
		  else
		    		    SRC_IN_STATE (qn, inst) = NULL;


		  qn_send_output (qn, inst);
		  state = NULL;
		  nth_val = 0;
		  goto again;
		}
	      continue;
	    }
	  rit = ri_iterator (sub, ri->ri_mode, 1);
	  while ((x = rit_next (rit)))
	    dk_set_push (&res, (void*)box_copy_tree (x->rs_iri));
	  dk_free_box ((caddr_t)rit);
	  array = (caddr_t *) list_to_array (dk_set_nreverse (res));
	  qst_set (inst, ri->ri_vec_array, (caddr_t) array);
	}
      else
	{
	  state = SRC_IN_STATE (qn, inst);
	  array = (caddr_t *) qst_get (inst, ri->ri_vec_array);
	}
      for (;nth_val < BOX_ELEMENTS (array); nth_val++)
	{
	  dc_append_box (out_dc, array[nth_val]);
	  qn_result (qn, inst, nth_set);
	  if (QST_INT (inst, qn->src_out_fill) >= batch_sz)
	    {
	      SRC_IN_STATE (qn, inst) = inst;
	      nth_val++;
	      QST_INT (inst, ri->ri_current_value) = nth_val;
	      QST_INT (inst, ri->ri_current_set) = nth_set;
	      qn_send_output (qn, inst);
	      state = NULL;
	      goto again;
	    }
	}
      nth_val = 0;
    }
  SRC_IN_STATE (qn, inst) = NULL;
  if (QST_INT (inst, qn->src_out_fill))
    qn_send_output (qn, inst);
}

void
rdf_inf_pre_input (rdf_inf_pre_node_t * ri, caddr_t * inst,
		   caddr_t * volatile state)
{
  ri_iterator_t  * rit;
  rdf_sub_t * sub;
  dk_set_t list;
  RI_INIT_NEEDED (inst);
  if (!ri->ri_ctx)
    {
      ri->ri_ctx = rdf_name_to_ctx (ri->ri_ctx_name);
      if (!ri->ri_ctx)
	sqlr_new_error ("42000", "RDFI.", "No rdf inf ctx %s", ri->ri_ctx_name);
    }
  if (ri->src_gen.src_sets)
    {
      rdf_inf_vec_input (ri, inst, state);
      return;
    }
  /* XXX: must delete */
  if (ri->ri_sas_follow)
    {
      ri_same_as_input (ri, inst, state);
      return;
    }
  for (;;)
    {
      if (state)
	{
	  if (ri->ri_outer_any_passed)
	    qst_set (inst, ri->ri_outer_any_passed, NULL);
	  if (ri->ri_given)
	    {
	      list = ri_list (ri, ri->ri_given, &sub);
	      if (!list)
		{
		  qst_set (inst, ri->ri_iterator, NULL);
		  qst_set (inst, ri->ri_output, box_copy_tree (ri->ri_given));
		  qn_send_output ((data_source_t *) ri, inst);
		  ri_outer_output (ri, ri->ri_outer_any_passed, inst);
		  return;
		}
	      qst_set (inst, ri->ri_output, box_copy_tree ((caddr_t) sub->rs_iri));
	      rit = ri_iterator (sub, ri->ri_mode, 1);
	      rit_next (rit); /* pop off the initial value */
	      if (rit_next (rit))
		{
		  SRC_IN_STATE ((data_source_t*)ri, inst) = inst;
		  qst_set (inst, ri->ri_iterator, (caddr_t)rit);
		  qn_send_output ((data_source_t *)ri, inst);
		  state = NULL;
		  continue;
		    }
	      else
		{
		  SRC_IN_STATE ((data_source_t *)ri, inst) = NULL;;
		  dk_free_box ((caddr_t)rit);
		  qn_send_output ((data_source_t *) ri, inst);
		  ri_outer_output (ri, ri->ri_outer_any_passed, inst);
		  return;
		}
	    }
	  else
	    {
	      /* see if the passing o/p has supers and generate the list of them if so */
	      if (((RI_SUPERCLASS == ri->ri_mode  || RI_SUBCLASS == ri->ri_mode)
		   && (!ri->ri_p || box_equal (rdfs_type, qst_get (inst, ri->ri_p)))
		   && (list = ri_list (ri, qst_get (inst, ri->ri_o), &sub)))
		  || ((RI_SUPERPROPERTY == ri->ri_mode || RI_SUBPROPERTY == ri->ri_mode)
		      && (list = ri_list (ri, qst_get (inst, ri->ri_p), &sub))))
		{
		  rit = ri_iterator (sub, ri->ri_mode, 1);
		  rit_next (rit); /* pop off initial value */
		  if (rit_next (rit))
		    {
		      qst_set (inst, ri->ri_iterator, (caddr_t)rit);
		      SRC_IN_STATE ((data_source_t*) ri, inst) = inst;
		      qst_set (inst, ri->ri_output, box_copy_tree (sub->rs_iri));
		      qn_send_output ((data_source_t *)ri, inst);
		      state = NULL;
		      continue;
		    }
		  else
		    {
		      /* nothing to add.  output is the original o or p */
		      dk_free_box ((caddr_t)rit);
		      rit = NULL;
		      SRC_IN_STATE ((data_source_t *)ri, inst) = NULL;
		      if (RI_SUBCLASS == ri->ri_mode)
			qst_set (inst, ri->ri_output, box_copy_tree (qst_get (inst, ri->ri_o)));
		      else if (RI_SUBPROPERTY == ri->ri_mode)
			qst_set (inst, ri->ri_output, box_copy_tree (qst_get (inst, ri->ri_p)));
		      qn_send_output ((data_source_t *)ri, inst);
		      ri_outer_output (ri, ri->ri_outer_any_passed, inst);
		      return;
		    }
		}
	      else
		{
		  if (RI_SUBCLASS == ri->ri_mode)
		    qst_set (inst, ri->ri_output, box_copy_tree (qst_get (inst, ri->ri_o)));
		  else if (RI_SUBPROPERTY == ri->ri_mode)
		    qst_set (inst, ri->ri_output, box_copy_tree (qst_get (inst, ri->ri_p)));
		  qn_send_output ((data_source_t *) ri, inst);
		  ri_outer_output (ri, ri->ri_outer_any_passed, inst);
		  return;
		}
	    }
	}
      rit = (ri_iterator_t *)qst_get (inst, ri->ri_iterator);
      if (rit->rit_at_end)
	{
	  SRC_IN_STATE ((data_source_t *) ri, inst) = NULL;
	  ri_outer_output (ri, ri->ri_outer_any_passed, inst);
	  return;
	}

      qst_set (inst, ri->ri_output, box_copy_tree (rit->rit_value->rs_iri));
      if (!rit_next (rit))
	{
	  SRC_IN_STATE ((data_source_t*)ri, inst) = NULL;
	  qn_send_output ((data_source_t *)ri, inst);
	  ri_outer_output (ri, ri->ri_outer_any_passed, inst);
	  return;
	}
      SRC_IN_STATE ((data_source_t*)ri, inst) = inst;
      qn_send_output ((data_source_t *)ri, inst);
    }
}


id_hash_t * rdf_name_to_ric;

rdf_inf_ctx_t *
rdf_name_to_ctx (caddr_t name)
{
  rdf_inf_ctx_t ** place;
  if (!name)
    return NULL;
  place = (rdf_inf_ctx_t **) id_hash_get (rdf_name_to_ric, (caddr_t) &name);
  return place ? *place : NULL;
}


rdf_sub_t *
ric_iri_to_sub (rdf_inf_ctx_t * ctx, caddr_t iri, int mode, int create)
{
  id_hash_t * ht = (RI_SUBCLASS == mode || RI_SUPERCLASS == mode) ? ctx->ric_iri_to_subclass :  ctx->ric_iri_to_subproperty;
  rdf_sub_t ** place = (rdf_sub_t **) id_hash_get (ht, (caddr_t)&iri);
  if (place)
    return *place;
  if (create)
    {
      NEW_VARZ (rdf_sub_t, rs);
      rs->rs_iri = box_copy (iri);
      id_hash_set (ht, (caddr_t)&rs->rs_iri, (caddr_t)&rs);
      return rs;
    }
  return NULL;
}


int
dk_set_pushnew_equal (dk_set_t * s, id_hash_t * ht, caddr_t box, int check_exists)
{
  caddr_t place;
  caddr_t new_box;
  ptrlong one = 1;
  if (check_exists)
    {
      place = id_hash_get (ht, (caddr_t)&box);
      if (place)
	return 0;
      new_box = box_copy (box);
      id_hash_set (ht, (caddr_t)&new_box, (caddr_t)&one);
    }
  else
    new_box = box_copy (box);
  dk_set_push (s, new_box);
  return 1;
}

rdf_inf_ctx_t *
rdf_inf_ctx (char * name)
{
  rdf_inf_ctx_t ** place;
  if (!name)
    return NULL;
  place = (rdf_inf_ctx_t **)id_hash_get (rdf_name_to_ric, (caddr_t)&name);
  return place ? *place : NULL;
}


rdf_inf_ctx_t *
ric_allocate (caddr_t n2)
    {
  NEW_VARZ (rdf_inf_ctx_t, ctx);
  ctx->ric_name = n2;
  id_hash_set (rdf_name_to_ric, (caddr_t)&n2, (caddr_t)&ctx);
      ctx->ric_iri_to_subclass = id_hash_allocate (61, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      ctx->ric_iri_to_subproperty = id_hash_allocate (61, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      ctx->ric_iid_to_rel_ifp = id_hash_allocate (61, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      ctx->ric_samples = id_hash_allocate (601, sizeof (caddr_t), sizeof (tb_sample_t), treehash, treehashcmp);
      /*ctx->ric_prop_props = id_hash_allocate (61, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);*/
      ctx->ric_ifp_exclude = id_hash_allocate (61, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      id_hash_set_rehash_pct (ctx->ric_iri_to_subclass, 200);
      id_hash_set_rehash_pct (ctx->ric_iri_to_subproperty, 200);
      id_hash_set_rehash_pct (ctx->ric_iid_to_rel_ifp, 200);
      id_hash_set_rehash_pct (ctx->ric_samples, 200);
      id_hash_set_rehash_pct (ctx->ric_ifp_exclude, 200);
  ctx->ric_ifp_exclude = id_hash_allocate (61, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);;
      ctx->ric_mtx = mutex_allocate ();
      ctx->ric_samples = id_hash_allocate (601, sizeof (caddr_t), sizeof (tb_sample_t), treehash, treehashcmp);
  id_hash_set_rehash_pct (ctx->ric_samples, 200);
      return ctx;
    }

rdf_inf_ctx_t *
bif_ctx_arg (caddr_t * qst, state_slot_t ** args, int nth, char * name, int create)
{
  caddr_t ctx_name = bif_string_arg (qst, args, nth, name);
  rdf_inf_ctx_t ** place = (rdf_inf_ctx_t **) id_hash_get (rdf_name_to_ric, (caddr_t)&ctx_name);
  if (!place && !create)
    sqlr_new_error ("42000", "RDFI.", "No RDF inference rule set '%.200s' specified as argument #%d of %.200s()", ctx_name, nth, name);
  if (!place)
    {
      caddr_t n2 = box_copy (ctx_name);
      return ric_allocate (n2);
    }
  else
    return * place;
}

caddr_t
bif_rdf_super_sub_list (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t iri = bif_arg (qst, args, 1, "rdf_super_sub_list");
  int mode = bif_long_arg (qst, args, 2, "rdf_super_sub_list");
  rdf_inf_ctx_t * ctx = bif_ctx_arg (qst, args, 0, "rdf_super_sub_list", 0);
  rdf_sub_t * sub;
  if (mode < RI_SUBCLASS || mode > RI_SUPERPROPERTY)
    sqlr_new_error ("42000", "RDF..", "RDF inference type must be between 1 and 4");
  sub = ric_iri_to_sub (ctx, iri, mode, 0);
  if (sub)
    {
      rdf_sub_t * x;
      dk_set_t res = NULL;
      ri_iterator_t * rit = ri_iterator (sub, mode, 1);
      while ((x = rit_next (rit)))
	dk_set_push (&res, (void*)box_copy_tree (x->rs_iri));
      dk_free_box ((caddr_t)rit);
      return list_to_array (dk_set_nreverse (res));
    }
  return list  (0);
}


caddr_t
bif_rdf_is_sub (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_sub_t * s;
  ri_iterator_t * rit;
  caddr_t sub_iri = bif_arg (qst, args, 1, "rdf_is_sub");
  caddr_t iri = bif_arg (qst, args, 2, "rdf_is_sub");
  int mode = bif_long_arg (qst, args, 3, "rdf_is_sub");
  rdf_inf_ctx_t * ctx = bif_ctx_arg (qst, args, 0, "rdf_is_sub", 0);
  rdf_sub_t * sub;
  if (mode != RI_SUBCLASS && mode != RI_SUBPROPERTY)
    sqlr_new_error ("42000", "RDF..", "RDF inference type for rdf_is_sub() must be 1 for subclass  or 3 for subproperty");
  mode = mode == RI_SUBCLASS ? RI_SUPERCLASS : RI_SUPERPROPERTY;
  sub = ric_iri_to_sub (ctx, sub_iri, mode, 0);
  if (sub)
    {
      rit = ri_iterator (sub, mode, 1);
      while ((s = rit_next (rit)))
	{
	  if (box_equal (s->rs_iri, iri))
	    {
	      dk_free_box ((caddr_t)rit);
	      return box_num (1);
	    }
	}
      dk_free_box ((caddr_t)rit);
    }
  return 0;
}


caddr_t
bif_rdf_inf_dir (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* in mode, bit 0 is 1 for class and 0 for prop.  Bit 1 is 0 for super and 1 for equiv */
  rdf_inf_ctx_t * ctx = bif_ctx_arg (qst, args, 0, "rdf_inf_dir", 1);
  caddr_t super = bif_arg (qst, args, 1, "rdf_inf_dir");
  caddr_t sub = bif_arg (qst, args, 2, "rdf_inf_dir");
  int is_cl = bif_long_arg (qst, args, 3, "rdf_inf_dir");
  rdf_sub_t * super_rs, * sub_rs;
  int mode  = (is_cl & 1) ? RI_SUPERCLASS : RI_SUPERPROPERTY;
  sub_rs = ric_iri_to_sub (ctx, sub, mode, 1);
  super_rs = ric_iri_to_sub (ctx, super, mode, 1);
  if ((2 & is_cl))
    {
      if (!dk_set_member (sub_rs->rs_equiv, (void*)super_rs))
	{
	  dk_set_push (&sub_rs->rs_equiv, (void*)super_rs);
	  dk_set_push (&super_rs->rs_equiv, (void*)sub_rs);
	}
      return NULL;
    }
  if (dk_set_member (super_rs->rs_sub, (void*)sub_rs))
    return box_num (1);
  dk_set_push (&super_rs->rs_sub, sub_rs);
  dk_set_push (&sub_rs->rs_super, super_rs);
  return box_num (0);
}

caddr_t
bif_rdf_inf_dump (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_inf_ctx_t * ctx = bif_ctx_arg (qst, args, 0, "rdf_inf_dump", 0);
  int ctr;
  dk_set_t res_triples = NULL;
  id_hash_iterator_t hiter;
  caddr_t *key_ptr, *data_ptr;
  rdf_sub_t **rsub_ptr;
  iri_id_t **rels_ptr;
  id_hash_iterator (&hiter, ctx->ric_iri_to_subclass);
  while (hit_next (&hiter, (char **)(&key_ptr), (char **)(&rsub_ptr)))
    {
      rdf_sub_t *rsub = rsub_ptr[0];
      DO_SET (rdf_sub_t *, sub_rs, &(rsub->rs_sub))
        {
          dk_set_push (&res_triples, list (3, box_copy_tree (sub_rs->rs_iri), box_dv_uname_string ("http://www.w3.org/2000/01/rdf-schema#subClassOf"), box_copy_tree(key_ptr[0])));
        }
      END_DO_SET ()
      DO_SET (rdf_sub_t *, equiv_rs, &(rsub->rs_equiv))
        {
          dk_set_push (&res_triples, list (3, box_copy_tree (equiv_rs->rs_iri), box_dv_uname_string ("http://www.w3.org/2002/07/owl#equivalentClass"), box_copy_tree(key_ptr[0])));
        }
      END_DO_SET ()
    }
  id_hash_iterator (&hiter, ctx->ric_iri_to_subproperty);
  while (hit_next (&hiter, (char **)(&key_ptr), (char **)(&rsub_ptr)))
    {
      rdf_sub_t *rsub = rsub_ptr[0];
      DO_SET (rdf_sub_t *, sub_rs, &(rsub->rs_sub))
        {
          dk_set_push (&res_triples, list (3, box_copy_tree (sub_rs->rs_iri), box_dv_uname_string ("http://www.w3.org/2000/01/rdf-schema#subPropertyOf"), box_copy_tree(key_ptr[0])));
        }
      END_DO_SET ()
      DO_SET (rdf_sub_t *, equiv_rs, &(rsub->rs_equiv))
        {
          dk_set_push (&res_triples, list (3, box_copy_tree (equiv_rs->rs_iri), box_dv_uname_string ("http://www.w3.org/2002/07/owl#equivalentProperty"), box_copy_tree(key_ptr[0])));
        }
      END_DO_SET ()
    }
  DO_BOX_FAST_REV (caddr_t, iid, ctr, ctx->ric_ifp_list)
    {
      dk_set_push (&res_triples, list (3, box_copy_tree(iid), uname_rdf_ns_uri_type, box_dv_uname_string ("http://www.w3.org/2002/07/owl#InverseFunctionalProperty"), box_dv_uname_string ("http://www.w3.org/2002/07/owl#InverseFunctionalProperty")));
    }
  END_DO_BOX_FAST;
  data_ptr = ctx->ric_inverse_prop_pair_sortedalist;
  for (ctr = BOX_ELEMENTS_0 (data_ptr) - 2; ctr >= 0; ctr -= 2)
    {
      dk_set_push (&res_triples, list (3, box_copy_tree (data_ptr[ctr]), box_dv_uname_string ("http://www.w3.org/2002/07/owl#inverseOf"), box_copy_tree (data_ptr[ctr+1])));
    }
  data_ptr = ctx->ric_prop_props;
  for (ctr = BOX_ELEMENTS_0 (data_ptr) - 2; ctr >= 0; ctr -= 2)
    {
      if (0x1 & (ptrlong)(data_ptr[ctr+1]))
        dk_set_push (&res_triples, list (3, box_copy_tree (data_ptr[ctr]), uname_rdf_ns_uri_type, box_dv_uname_string ("http://www.w3.org/2002/07/owl#InverseFunctionalProperty"), box_dv_uname_string ("http://www.w3.org/2002/07/owl#TransitiveProperty")));
    }
  id_hash_iterator (&hiter, ctx->ric_ifp_exclude);
  while (hit_next (&hiter, (char **)(&key_ptr), (char **)(&data_ptr)))
    {
      caddr_t *data = (caddr_t *)data_ptr;
      DO_BOX_FAST_REV (caddr_t, iid, ctr, data)
        {
          dk_set_push (&res_triples, list (3, box_copy_tree(key_ptr[0]), box_dv_uname_string ("http://www.openlinksw.com/schemas/virtrdf#nullIFPValue"), box_copy_tree (iid)));
        }
      END_DO_BOX_FAST;
    }
#ifndef NDEBUG
  id_hash_iterator (&hiter, ctx->ric_iid_to_rel_ifp);
  while (hit_next (&hiter, (char **)(&key_ptr), (char **)(&rels_ptr)))
    {
      iri_id_t *rels = rels_ptr[0];
      int rel_ctr, rels_count = box_length (rels) / sizeof (iri_id_t);
      for (rel_ctr = rels_count; rel_ctr--; /*no step*/)
        dk_set_push (&res_triples, list (3, box_copy_tree(key_ptr[0]), box_dv_uname_string ("http://www.openlinksw.com/schemas/virtrdf#relatedIFP"), box_iri_id (rels[rel_ctr])));
    }
#endif
  return list_to_array (res_triples);
}

caddr_t
bif_rdf_inf_ifp_list (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_inf_ctx_t * ctx;
  RI_INIT_NEEDED_REC (qst);
  ctx = bif_ctx_arg (qst, args, 0, "rdf_inf_ifp_list", 0);
  if (NULL == ctx->ric_ifp_list)
  return list (0);
  return box_copy_tree (ctx->ric_ifp_list);
}

caddr_t
bif_rdf_inf_ifp_rel_list (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_inf_ctx_t * ctx;
  ctx = bif_ctx_arg (qst, args, 0, "rdf_inf_ifp_rel_list", 0);
  if (NULL == ctx->ric_ifp_rel_list)
    return NULL;
  if (1 == BOX_ELEMENTS (args))
    return box_copy_tree (ctx->ric_ifp_rel_list);
  else
    {
      caddr_t arg = bif_arg (qst, args, 1, "rdf_inf_ifp_rel_list");
      iri_id_t arg_iid, **rels_ptr, *rels;
      caddr_t *res_boxes;
      int rel_ctr, rels_count, res_boxes_ctr;
      if (DV_IRI_ID != DV_TYPE_OF (arg))
        return NEW_DB_NULL;
      rels_ptr = (iri_id_t **)id_hash_get (ctx->ric_iid_to_rel_ifp, (caddr_t)(&arg));
      if (NULL == rels_ptr)
        return NEW_DB_NULL;
      rels = rels_ptr[0];
      rels_count = box_length (rels) / sizeof (iri_id_t);
      arg_iid = unbox_iri_int64 (arg);
      res_boxes = dk_alloc_box ((rels_count-1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (rel_ctr = res_boxes_ctr = 0; rel_ctr < rels_count; rel_ctr++)
        {
          if (rels[rel_ctr] != arg_iid)
            res_boxes [res_boxes_ctr++] = box_iri_id (rels[rel_ctr]);
        }
      if (res_boxes_ctr != (rels_count-1))
        sqlr_new_error ("22023", "SR634", "Corrupted inference rule set '%.200s', please report the ontology and the query", ctx->ric_name);
      return (caddr_t)res_boxes;
    }
}

caddr_t
bif_rdf_inf_set_ifp_list (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
#ifdef RDFINF_DEBUG
  query_instance_t *qi = (query_instance_t *)qst;
#endif
  int ifp_count, ifp_ctr;
  rdf_inf_ctx_t * ctx = bif_ctx_arg (qst, args, 0, "rdf_inf_set_ifp_list", 1);
  caddr_t * arr = bif_array_of_pointer_arg (qst, args, 1, "rdf_inf_set_ifp_list");
  int dirt;
  caddr_t * grps;
  dk_set_t ifp_rel_acc = NULL;

  sec_check_dba ((query_instance_t *)qst, "rdf_inf_set_ifp_list");
  grps = box_copy /*_tree*/ (arr);
  ctx->ric_ifp_list = box_copy_tree ((caddr_t)arr);
  ifp_count = BOX_ELEMENTS_0 (arr);
  if (ctx->ric_iid_to_rel_ifp->ht_inserts != ctx->ric_iid_to_rel_ifp->ht_deletes)
    {
      caddr_t *keyp, *valp;
      id_hash_iterator_t hit;
      id_hash_iterator (&hit, ctx->ric_iid_to_rel_ifp);
      while (hit_next (&hit, (char **)&keyp, (char **)&valp))
        {
           dk_free_tree (keyp[0]);
           /*dk_free_tree (valp[0]);*/
        }
      id_hash_clear (ctx->ric_iid_to_rel_ifp);
    }
  do {
      dirt = 0;
      for (ifp_ctr = ifp_count; ifp_ctr--; /*no step*/)
        {
          rdf_sub_t **rsub_ptr;
          caddr_t ifp_boxed_iid = arr[ifp_ctr];
          iri_id_t grp_iid = unbox_iri_int64 (grps[ifp_ctr]);
          dk_set_t subs;
          rsub_ptr = (rdf_sub_t **)id_hash_get (ctx->ric_iri_to_subproperty, (char *)(&ifp_boxed_iid));
          if (NULL == rsub_ptr)
            continue;
          subs = rsub_ptr[0]->rs_sub;
          DO_SET (rdf_sub_t *, sub_rsub, &subs)
            {
              int sub_ifp_pos;
              iri_id_t sub_iid, sub_grp_iid;
              sub_iid = unbox_iri_int64 (sub_rsub->rs_iri);
              for (sub_ifp_pos = ifp_count; sub_ifp_pos--; /*no step*/)
                {
                  if (unbox_iri_int64 (arr[sub_ifp_pos]) == sub_iid)
                    break;
                }
              if (0 > sub_ifp_pos)
                sqlr_new_error ("22023", "SR633", "Inconsistent inference rule set '%.200s' in rdf_inf_set_ifp_list(), loading is aborted, please report the ontology", ctx->ric_name);
              sub_grp_iid = unbox_iri_int64 (grps[sub_ifp_pos]);
              if (sub_grp_iid != grp_iid)
                {
                  int ctr;
                  dirt = 1;
                  for (ctr = ifp_count; ctr--; /*no step*/)
                    {
                      if (unbox_iri_int64 (grps[ctr]) == sub_grp_iid)
                        {
#ifdef RDFINF_DEBUG
                          query_instance_t *qi = (query_instance_t *)qst;
                          caddr_t main_iri = key_id_to_iri (qi, ifp_iid);
                          caddr_t sub_iri = key_id_to_iri (qi, ifp_iid);
                          caddr_t attach_iri = key_id_to_iri (qi, unbox_iri_int64 (arr[ctr]));
                          printf ("INF '%s' loading: IFP <%s> is attached to <%s> via <%s>\n", ctx->ric_name, attach_iri, main_iri, sub_iri);
                          dk_free_box (main_iri);
                          dk_free_box (sub_iri);
                          dk_free_box (attach_iri);

#endif
                          grps[ctr] = grps[ifp_ctr];
                        }
                    }
                }
            }
          END_DO_SET()
        }
    } while (dirt);
#ifdef RDFINF_DEBUG
  for (ifp_ctr = ifp_count; ifp_ctr--; /*no step*/)
    {
      caddr_t ifp_iri = key_id_to_iri (qi, unbox_iri_int64 (arr[ifp_ctr]));
      caddr_t grp_iri = key_id_to_iri (qi, unbox_iri_int64 (grps[ifp_ctr]));
      printf ("INF '%s' loading: IFP <%s> belongs to <%s> group\n", ctx->ric_name, ifp_iri, grp_iri);
    }
#endif

/* At this point, every group in grps[ctr] is labeled by exactly one its representative. Now it's easy to fill in the hashtable */
  for (ifp_ctr = ifp_count; ifp_ctr--; /*no step*/)
    {
      caddr_t ifp_boxed_iid = arr[ifp_ctr];
      dk_set_t acc;
      int grpsize, ctr;
      iri_id_t *val;
      iri_id_t ifp_iid = unbox_iri_int64 (ifp_boxed_iid);
      iri_id_t grp_iid = unbox_iri_int64 (grps[ifp_ctr]);
      if (ifp_iid != grp_iid)
        continue; /* This is not a canonical rep of the group */
      acc = NULL;
      grpsize = 0;
      for (ctr = ifp_count; ctr--; /*no step*/)
        if (unbox_iri_int64 (grps[ctr]) == grp_iid)
          {
            dk_set_push (&acc, arr[ctr]);
            grpsize++;
          }
      if (1 == grpsize)
        {
          dk_set_pop (&acc);
          continue;
        }
      val = dk_alloc_box (grpsize * sizeof (iri_id_t), DV_ARRAY_OF_LONG);
      for (ctr = 0; ctr < grpsize; ctr++)
        {
          caddr_t member_boxed_iid = box_copy_tree (dk_set_pop (&acc));
          dk_set_push (&ifp_rel_acc, member_boxed_iid);
          val[ctr] = unbox_iri_int64 (member_boxed_iid);
          id_hash_set (ctx->ric_iid_to_rel_ifp, (caddr_t)(&member_boxed_iid), (caddr_t)(&val));
        }
    }
  ctx->ric_ifp_rel_list = (caddr_t *) revlist_to_array (ifp_rel_acc);
  return NULL;
}

caddr_t
bif_rdf_inf_ifp_exclude_list (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_inf_ctx_t * ctx = bif_ctx_arg (qst, args, 0, "rdf_inf_ifp_exclude_list", 0);
  iri_id_t ifp = bif_iri_id_arg (qst, args, 1, "rdf_inf_ifp_exclude_list");
  caddr_t box = box_iri_id (ifp);
  caddr_t *place = (caddr_t *)id_hash_get (ctx->ric_ifp_exclude, (void *)(&box));
  dk_free_tree (box);
  if (NULL == place)
    return list (0);
  return box_copy_tree (place[0]);
}


caddr_t
bif_rdf_inf_set_ifp_exclude_list (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_inf_ctx_t * ctx = bif_ctx_arg (qst, args, 0, "rdf_inf_set_ifp_exclude_list", 1);
  iri_id_t ifp = bif_iri_id_arg (qst, args, 1, "rdf_inf_set_ifp_exclude_list");
  caddr_t * arr = bif_array_of_pointer_arg (qst, args, 2, "rdf_inf_set_ifp_exclude_list");
  caddr_t box, copy;
  sec_check_dba ((query_instance_t *)qst, "rdf_inf_set_ifp_exclude_list");
  box = box_iri_id (ifp);
  copy = box_copy_tree (arr);
  id_hash_set (ctx->ric_ifp_exclude, (caddr_t)&box, (caddr_t)&copy);
  return NULL;
}


caddr_t
bif_rdf_inf_ifp_is_excluded (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  rdf_inf_ctx_t * ctx;
  caddr_t ifp = bif_arg (qst, args, 1, "rdf_inf_ifp_excluded");
  caddr_t value = bif_arg (qst, args, 2, "rdf_inf_ifp_excluded");
  caddr_t ** place, * arr;
  int inx;
  ctx = bif_ctx_arg (qst, args, 0, "rdf_inf_ifp_excluded", 1);
  place = (caddr_t**) id_hash_get (ctx->ric_ifp_exclude, (caddr_t)&ifp);
  if (!place)
    return NULL;
  arr = *place;
  DO_BOX (caddr_t, elt, inx, arr)
    {
      if (box_equal (elt, value))
	return (caddr_t)1;
    }
  END_DO_BOX;
  return NULL;
}

caddr_t
bif_rdf_inf_set_inverses (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *lst = bif_array_of_pointer_arg (qst, args, 1, "rdf_inf_set_inverses");
  rdf_inf_ctx_t * ctx = bif_ctx_arg (qst, args, 0, "rdf_inf_set_inverses", 1);
  int ctr, len = BOX_ELEMENTS_0 (lst);
  caddr_t *uname_lst;
  sec_check_dba ((query_instance_t *)qst, "rdf_inf_set_inverses");
  uname_lst = dk_alloc_list (len);
  for (ctr = len; ctr--; /* no step */)
    uname_lst[ctr] = box_dv_uname_string (lst[ctr]);
  dk_free_tree ((caddr_t)(ctx->ric_inverse_prop_pair_sortedalist));
  ctx->ric_inverse_prop_pair_sortedalist = uname_lst;
  return NULL;
}

caddr_t
bif_rdf_inf_set_prop_props (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *lst = bif_array_of_pointer_arg (qst, args, 1, "rdf_inf_set_prop_props");
  rdf_inf_ctx_t * ctx = bif_ctx_arg (qst, args, 0, "rdf_inf_set_prop_props", 1);
  int ctr, len = BOX_ELEMENTS_0 (lst);
  caddr_t *uname_flags_lst;
  sec_check_dba ((query_instance_t *)qst, "rdf_inf_set_prop_props");
  uname_flags_lst = dk_alloc_list (len);
  for (ctr = len - 2; ctr >= 0; ctr -= 2)
    {
      uname_flags_lst[ctr] = box_dv_uname_string (lst[ctr]);
      uname_flags_lst[ctr+1] = (caddr_t)((ptrlong)(unbox (lst[ctr+1])));
    }
  dk_free_tree ((caddr_t)(ctx->ric_prop_props));
  ctx->ric_prop_props = uname_flags_lst;
  return NULL;
}

caddr_t
bif_rdf_inf_clear (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ctx_name = bif_string_arg (qst, args, 0, "rdf_inf_clear");
  sec_check_dba ((query_instance_t *)qst, "rdf_inf_clear");
  id_hash_remove (rdf_name_to_ric, (caddr_t)&ctx_name);
  return 0;
}

caddr_t
bif_rdf_inf_is_loaded (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ctx_name = bif_string_arg (qst, args, 0, "rdf_inf_is_loaded");
  return box_num ((NULL != id_hash_get (rdf_name_to_ric, (caddr_t)&ctx_name)) ? 1 : 0);
}


caddr_t
bif_rdf_inf_const_init (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t tn;
  if (2 == cl_run_local_only)
    return NULL;
  tn = box_dv_short_string ("http://www.w3.org/1999/02/22-rdf-syntax-ns#type");
  rdfs_type = key_name_to_iri_id (bootstrap_cli->cli_trx, tn, 1);
  dk_free_box (tn);
  return 0;
}

caddr_t
bif_rdf_owl_iri_2 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int flag = bif_long_arg (qst, args, 0, "rdf_owl_iri");
  caddr_t err = NULL;
  if (!owl_sub_class_iri)
    {
      caddr_t name;
      /* owl:subClass */
      name = box_dv_short_string ("http://www.w3.org/2000/01/rdf-schema#subClassOf");
      owl_sub_class_iri = iri_ensure (qst, name, IRI_TO_ID_WITH_CREATE, &err);
      dk_free_box (name);
      if (err) goto err;
      /* owl:subProperty */
      name = box_dv_short_string ("http://www.w3.org/2000/01/rdf-schema#subPropertyOf");
      owl_sub_property_iri = iri_ensure (qst, name, IRI_TO_ID_WITH_CREATE, &err);
      dk_free_box (name);
      if (err) goto err;
      /* owl:equivalentClass */
      name = box_dv_short_string ("http://www.w3.org/2002/07/owl#equivalentClass");
      owl_equiv_class_iri = iri_ensure (qst, name, IRI_TO_ID_WITH_CREATE, &err);
      dk_free_box (name);
      if (err) goto err;
      /* owl:equivalentProperty */
      name = box_dv_short_string ("http://www.w3.org/2002/07/owl#equivalentProperty");
      owl_equiv_property_iri = iri_ensure (qst, name, IRI_TO_ID_WITH_CREATE, &err);
      dk_free_box (name);
      if (err) sqlr_resignal (err);
    }
  if (flag == 0)
    return box_copy_tree (owl_sub_property_iri);
  else if (flag == 1)
    return box_copy_tree (owl_sub_class_iri);
  else if (flag == 2)
    return box_copy_tree (owl_equiv_property_iri);
  else if (flag == 3)
    return box_copy_tree (owl_equiv_class_iri);
  sqlr_new_error ("22023", "OWL01",  "The function rdf_owl_iri supports 0-3 as argument.");
  return NULL;
 err:
  owl_sub_class_iri = NULL;
  sqlr_resignal (err);
  return NULL;
}


caddr_t
bif_rdf_owl_iri (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* if null try to reinit */
  caddr_t res = bif_rdf_owl_iri_2 (qst, err_ret, args);
  if (!res)
    {
      owl_sub_class_iri = NULL;
      return bif_rdf_owl_iri_2 (qst, err_ret, args);
    }
  return res;
}


void
rdf_sas_ensure (caddr_t * qst, caddr_t * err_ret)
{
}


caddr_t
bif_rdf_sas_iri (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* if from sas node, do the init on other thread so no locks in this txn ctx.  If inside rdf inf init then init the fucking iri here */
  RI_INIT_NEEDED(qst);
  rdf_sas_ensure (qst, err_ret);
  return box_copy_tree (same_as_iri);
}


void
sas_init ()
{
  local_cursor_t * lc;
  caddr_t err;
  query_t * sas_id;
  if (1 != cl_run_local_only)
    return;
  sas_ensure ();
  sas_id = sql_compile_static ("select iri_to_id ('http://www.w3.org/2002/07/owl#sameAs', 1)", bootstrap_cli, &err, SQLC_DEFAULT);
  err = qr_quick_exec (sas_id, bootstrap_cli, "", &lc, 0);
  if (lc_next (lc))
    same_as_iri = box_copy_tree (lc_nth_col (lc, 0));
  lc_free (lc);
}


int cl_rdf_inf_inited = 0;
du_thread_t * cl_rdf_inf_init_thread; /* during init, only this thread is allowed sparql */


caddr_t
bif_rdf_init_thread (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int f = bif_long_arg (qst, args, 0, "rdf_init_thread");
  if (f)
    cl_rdf_inf_init_thread = THREAD_CURRENT_THREAD;
  else
    cl_rdf_inf_init_thread = NULL;
  return NULL;
}


caddr_t
bif_rdf_check_init (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  if (1 != cl_rdf_inf_inited)
    cl_rdf_inf_init_1 (qst);
  return 0;
}


char * cl_rdf_init_proc =
"create procedure DB.DBA.CL_RDF_INF_INIT ()\n"
"{ declare aq any; aq := async_queue (1, 4); aq_request (aq, 'DB.DBA.CL_RDF_INF_INIT_SRV', vector ()); aq_wait_all (aq, 1); }";

char * cl_rdf_init_srv =
"create procedure DB.DBA.CL_RDF_INF_INIT_SRV ()\n"
" { \n"
"   declare c int;\n"
"   set isolation = 'committed'; \n"
"   set result_timeout = 0; \n"
"   set transaction_timeout = 0; \n"
"  cl_detach_thread ();\n"
"   rdf_init_thread (1); \n"
"   rdf_sas_iri (); \n"
"   if (1 <> sys_stat ('cl_run_local_only')) { \n"
"  { -- ensure that the procs are compiled.  Ignore errors since elastic will signal errors since the calling context does not specify the slice  \n"
"    declare	exit handler for sqlstate '*'{;}; "
"    DB.DBA     .II_P_LOOK ('unknown prefix', null, 0); "
"  } "
"  { "
"    declare	exit handler for sqlstate '*'{;}; "
"    DB.DBA.II_I_LOOK (null, 0); 	   "
"  } "
"   } \n"
"   DB.DBA.RDF_MAKE_IID_OF_QNAME_SAFE (null); \n"
"   DB.DBA.RDF_QNAME_OF_IID (null); \n"
"   rdf_inf_const_init (); \n"
"   select count (*) into c from (select distinct s.RS_NAME from sys_rdf_schema s) sub where 0 = rdfs_load_schema (sub.RS_NAME); \n"
"   JSO_LOAD_AND_PIN_SYS_GRAPH_RO  (); \n"
"   commit work; \n"
"   rdf_init_thread (0); \n"
" } \n";

dk_set_t rdf_inf_init_queue;
user_t * cl_rdf_inf_init_user;

void
cl_rdf_inf_init_done (client_connection_t * cli, int flag)
{
  cli->cli_user = cl_rdf_inf_init_user;
  IN_TXN;
  cl_rdf_inf_inited = flag;
  DO_SET (du_thread_t *, thr, &rdf_inf_init_queue)
    {
      semaphore_leave (thr->thr_sem);
    }
  END_DO_SET();
  dk_set_free (rdf_inf_init_queue);
  rdf_inf_init_queue = NULL;
  LEAVE_TXN;
}


void
cl_rdf_inf_init (client_connection_t * cli, caddr_t * err_ret)
{
  /* called from compiler when an inf ctx is found in the parse tree. Must complete before the compilation can proceed.  For cluster only */
  int lt_threads = cli->cli_trx->lt_threads;
  static query_t * qr;
  caddr_t err = NULL;
  IN_TXN;
  if (1 == cl_rdf_inf_inited)
    {
      LEAVE_TXN;
      return;
    }
  if (2 == cl_rdf_inf_inited)
    {
      int is_in = cli->cli_trx->lt_threads && !cli->cli_trx->lt_vdb_threads;
      du_thread_t * self = THREAD_CURRENT_THREAD;
      dk_set_push (&rdf_inf_init_queue, (void*)self);
      LEAVE_TXN;
      if (is_in)
      vdb_enter_lt (cli->cli_trx);
      semaphore_enter (self->thr_sem);
      if (is_in)
      vdb_leave_lt (cli->cli_trx, err_ret);
      if (1 != cl_rdf_inf_inited)
	*err_ret = srv_make_new_error ("42000", "CLRI1", "Rdf inf init failed while waiting for other thread to do the rdf inf init");
      return;
    }
  cl_rdf_inf_init_user = cli->cli_user;
  cl_rdf_inf_inited = 2;
  LEAVE_TXN;
  cli->cli_user = sec_name_to_user ("dba");
  ddl_std_proc (cl_rdf_init_proc, 0);
  ddl_std_proc (cl_rdf_init_srv, 0);
  if (!qr)
    qr = sql_compile ("DB.DBA.CL_RDF_INF_INIT ()", bootstrap_cli, err_ret, SQLC_DEFAULT);
  if (*err_ret)
    goto init_error;
  if (!lt_threads)
    {
      int rc;
      rc = lt_enter (cli->cli_trx);
      if (LTE_OK != rc)
	{
	  *err_ret = srv_make_new_error ("42000", "CLRI2", "Cluster rdf inf init failed because bad transaction state.  Rollback and retry.");
	  goto init_error;
	}
    }
  *err_ret = qr_quick_exec (qr, cli, "", NULL, 0);
  sas_ensure ();
  if (!lt_threads)
    {
      IN_TXN;
      lt_leave (cli->cli_trx);
      LEAVE_TXN;
    }
  if (*err_ret)
    goto init_error;
  cl_rdf_inf_init_done (cli, 1);
  return;
 init_error:
  err = *err_ret;
  log_error ("Error executing a cluster RDF inf init: %s: %s", ((caddr_t *) err)[QC_ERRNO], ((caddr_t *) err)[QC_ERROR_STRING]);
  cl_rdf_inf_init_done (cli, 0);
}


void
cl_rdf_inf_init_1 (caddr_t * qst)
{
  QNCAST (query_instance_t, qi, qst);
  caddr_t err = NULL;
  if (CL_RUN_LOCAL == cl_run_local_only)
    {
      cl_rdf_inf_inited = 1;
      return;
    }
  cl_rdf_inf_init (qi->qi_client, &err);
  if (err)
    sqlr_resignal (err);
}

#define TN_HASH_CLEANUP(ht) \
      DO_IDHASH (caddr_t, k, caddr_t, d, ht) \
	{ \
	  dk_free_tree (k); \
	  dk_free_tree (d); \
	} \
      END_DO_IDHASH; \
      id_hash_clear (ht)

caddr_t
bif_tn_cache_clear (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  mutex_enter (tn_cache_mtx);
  TN_HASH_CLEANUP (sas_tn_ht);
  TN_HASH_CLEANUP (sas_tn_no_graph_ht);
  TN_HASH_CLEANUP (tn_ifp_ht);
  TN_HASH_CLEANUP (tn_ifp_no_graph_ht);
  mutex_leave (tn_cache_mtx);
  return NULL;
}

void
cl_rdf_bif_check_init (bif_t bif)
{
  if (1 == cl_rdf_inf_inited)
    return;
  if  (bif_rdf_inf_ifp_list == bif || bif_rdf_inf_ifp_is_excluded == bif
       || bif_rdf_is_sub == bif || bif_rdf_super_sub_list == bif)
    {
      caddr_t err = NULL;
      client_connection_t * cli =sqlc_client ();
      if (!cli || !cli->cli_trx || 1 != cli->cli_trx->lt_threads) GPF_T1 ("reading a qf with a bif needing rdf inf init.  The cli does not have the right lt settings");
      cl_rdf_inf_init (cli, &err);
      if (err)
	{
	  log_error ("Error in rdf inf init when reading a qf needing such init: %s %s", ERR_MESSAGE (err));
	  dk_free_tree (err);
	}
    }
}
rdf_inf_ctx_t * empty_ric;

void
rdf_inf_init ()
{
  rdf_name_to_ric = id_hash_allocate (61, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
  id_hash_set_rehash_pct (rdf_name_to_ric, 200);
  bif_define ("rdf_init_thread", bif_rdf_init_thread);
  bif_define ("rdf_inf_dir", bif_rdf_inf_dir);
  bif_define ("rdf_inf_const_init", bif_rdf_inf_const_init);
  bif_define ("rdf_inf_clear", bif_rdf_inf_clear);
  bif_define ("rdf_inf_is_loaded", bif_rdf_inf_is_loaded);
  bif_define ("rdf_sas_iri", bif_rdf_sas_iri);
  bif_set_uses_index (bif_rdf_sas_iri);
  bif_define ("rdf_owl_iri", bif_rdf_owl_iri);
  bif_set_uses_index (bif_rdf_owl_iri);
  bif_define ("rdf_inf_ifp_list", bif_rdf_inf_ifp_list);
  bif_define ("rdf_inf_ifp_rel_list", bif_rdf_inf_ifp_rel_list);
  bif_define ("rdf_inf_set_ifp_list", bif_rdf_inf_set_ifp_list);
  bif_define ("rdf_inf_set_ifp_exclude_list", bif_rdf_inf_set_ifp_exclude_list);
  bif_define ("rdf_inf_ifp_is_excluded", bif_rdf_inf_ifp_is_excluded);
  bif_define ("rdf_inf_set_inverses", bif_rdf_inf_set_inverses);
  bif_define ("rdf_inf_set_prop_props", bif_rdf_inf_set_prop_props);
  bif_define ("rdf_check_init" , bif_rdf_check_init);
  bif_set_uses_index (bif_rdf_check_init);
  bif_define ("rdf_super_sub_list", bif_rdf_super_sub_list);
  bif_define ("rdf_is_sub", bif_rdf_is_sub);
  bif_define ("rdf_inf_dump", bif_rdf_inf_dump);
  bif_define ("tn_cache_clear", bif_tn_cache_clear);
  dk_mem_hooks (DV_RI_ITERATOR, box_non_copiable, rit_free, 0);
  empty_ric = ric_allocate (box_dv_short_string ("__ empty"));
  sas_init ();
}


void
dk_set_ins_after (dk_set_t * s, void* point, void* new_elt)
{
  dk_set_t elt = *s;
  while (elt)
    {
      if (elt->data == point)
	{
	  elt->next = dk_set_cons (new_elt, elt->next);
	  return;
	}
      elt = elt->next;
    }
}


void
dk_set_ins_before (dk_set_t * s, void* point, void* new_elt)
{
  dk_set_t elt = *s;
  dk_set_t * prev = s;
  while (elt)
    {
      if (elt->data == point)
	{
	  *prev = dk_set_cons (new_elt, *prev);
	  return;
	}
      prev = &elt->next;
      elt = elt->next;
    }
}


void
qn_ins_before (sql_comp_t * sc, data_source_t ** head, data_source_t * ins_before, data_source_t * new_qn)
{
  data_source_t * qn = *head;
  data_source_t * prev = NULL;
  dk_set_delete (&sc->sc_cc->cc_query->qr_nodes, (void*) new_qn);
  dk_set_ins_after (&sc->sc_cc->cc_query->qr_nodes, (void*) ins_before, (void*) new_qn);
  while (qn)
    {
      if (qn == ins_before)
	{
	  if (!prev)
	    *head = new_qn;
	  else
	    prev->src_continuations->data = (void *) new_qn;
	  new_qn->src_continuations = dk_set_cons ((void*) ins_before, NULL);
	  new_qn->src_pre_code = ins_before->src_pre_code;
	  ins_before->src_pre_code = NULL;
	  return;
	}
      prev = qn;
      qn = qn_next (qn);
    }
}


void
rdf_inf_pre_free (rdf_inf_pre_node_t * ri)
{
  dk_free_tree (ri->ri_given);
  dk_free_box (ri->ri_ctx_name);
  dk_free_box ((caddr_t) ri->ri_sas_g);
}


rdf_inf_pre_node_t *
sqlg_rdf_inf_node (sql_comp_t *sc)
{
  SQL_NODE_INIT (rdf_inf_pre_node_t, ri, rdf_inf_pre_input, rdf_inf_pre_free);
  ri->ri_iterator = ssl_new_variable (sc->sc_cc, "iter", DV_ANY);
  return ri;
}


void
sp_list_replace_ssl (search_spec_t * sp, state_slot_t * old, state_slot_t * new, int col_id)
{
  for (sp = sp; sp; sp = sp->sp_next)
    if (CMP_EQ == sp->sp_min_op && sp->sp_min_ssl == old && (!col_id || sp->sp_cl.cl_col_id == col_id))
      sp->sp_min_ssl = new;
}


void
sqlg_rdf_ts_replace_ssl (table_source_t * ts, state_slot_t * old, state_slot_t * new, int col_id, int inxop_inx)
{
  if (IS_TS (ts))
    {
      key_source_t * ks = ts->ts_order_ks;
      if (ts->ts_inx_op)
	{
	  inx_op_t * iop = ts->ts_inx_op->iop_terms[inxop_inx];
	  sp_list_replace_ssl (iop->iop_ks_start_spec.ksp_spec_array, old, new, col_id);
	  sp_list_replace_ssl (iop->iop_ks_full_spec.ksp_spec_array, old, new, col_id);
	  sp_list_replace_ssl (iop->iop_ks_row_spec, old, new, col_id);
	}
      else
	{
	  sp_list_replace_ssl  (ks->ks_spec.ksp_spec_array, old, new, col_id);
	  sp_list_replace_ssl  (ks->ks_row_spec, old, new, col_id);
	  if (ks->ks_key->key_no_pk_ref)
	    {
	      table_source_t * next = (table_source_t*) qn_next ((data_source_t*)ts);
	      if (next && IS_TS (next))
		sqlg_rdf_ts_replace_ssl (next, old, new, col_id, inxop_inx);
	    }
	}
    }
  else if (IS_QN (ts, hash_source_input))
    {
      hash_source_t * hs = (hash_source_t *) ts;
      int inx;
      DO_BOX (state_slot_t *, ref, inx, hs->hs_ref_slots)
	{
	  if (ref == old)
	    hs->hs_ref_slots[inx] = new;
	}
      END_DO_BOX;
    }
}


state_slot_t *
sqlg_col_ssl (df_elt_t * tb_dfe, char * name)
{
  DO_SET (df_elt_t *, out, &tb_dfe->_.table.out_cols)
    {
      if (0 == stricmp (out->_.col.col->col_name, name))
	return out->dfe_ssl;
    }
  END_DO_SET();
  return NULL;
}


void
sqlg_ri_post_filter (table_source_t * ts, df_elt_t * tb_dfe, rdf_inf_pre_node_t * ri, int p_check)
{
  /* this makes a follow up node to 1. gs fp go to check that fp is rdfs_type.
   * the end node will also record the fact of a result existing for an oj.  The post join test for an oj will also go here. */
  code_vec_t ajt;
  sql_comp_t * sc = tb_dfe->dfe_sqlo->so_sc;
  dk_set_t code = NULL;
  SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
  sql_node_append ((data_source_t**)&ts, (data_source_t*) en);
  if (p_check)
    {
      state_slot_t * p_ssl = sqlg_col_ssl (tb_dfe, "P");
      jmp_label_t is_p = sqlc_new_label (sc);
      jmp_label_t is_not_p = sqlc_new_label (sc);
      jmp_label_t bad_o = sqlc_new_label (sc);
      cv_compare (&code, BOP_EQ, p_ssl, ssl_new_constant (sc->sc_cc, box_copy_tree (rdfs_type)), is_p, is_not_p, is_not_p);
      cv_label (&code, is_not_p);
      cv_compare (&code, BOP_EQ, ri->ri_output, ri->ri_o, is_p, bad_o, bad_o);
      cv_label (&code, bad_o);
      cv_bret (&code, 0);
      cv_label (&code, is_p);
    }
  if (ri->ri_outer_any_passed)
    {
      cv_artm (&code, (ao_func_t)box_identity, ri->ri_outer_any_passed,  ssl_new_constant (sc->sc_cc, box_num (1)), NULL);
    }
  cv_bret (&code, 1);
  en->src_gen.src_after_test = code_to_cv (sc, code);
  if (ri->ri_outer_any_passed
      && (ajt = IS_TS (ts) ? ts->ts_after_join_test : ((hash_source_t *)ts)->hs_after_join_test))
    {
      SQL_NODE_INIT (end_node_t, en2, end_node_input, NULL);
      sql_node_append ((data_source_t **)&en, (data_source_t *)en2);
      en2->src_gen.src_after_test = ajt;
      if (IS_TS (ts))
	ts->ts_after_join_test = NULL;
      else
	((hash_source_t *) ts)->hs_after_join_test = NULL;
    }
}

#define IS_POST_TEST(qn) \
  ((qn_input_fn) end_node_input == (qn)->src_input)


data_source_t *
qn_last_post_iter (data_source_t * qn)
{
  for (;;)
    {
      data_source_t * next = qn_next (qn);

      if (!next)
	return qn;
      if (!IS_POST_TEST (next))
	return qn;
      qn = next;
    }
}


void
sqlg_outer_post_filter (table_source_t * ts, df_elt_t * tb_dfe, state_slot_t * any_flag)
{
  /* if a node has iters in front and is outer, this makes a node to record that there was at least one joined.  Also do the post join test here. */
  code_vec_t ajt;
  sql_comp_t * sc = tb_dfe->dfe_sqlo->so_sc;
  dk_set_t code = NULL;
  data_source_t * last_post_node = qn_last_post_iter ((data_source_t*) ts);
  SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
  sql_node_append ((data_source_t**)&last_post_node, (data_source_t*) en);
  cv_artm (&code, (ao_func_t)box_identity, any_flag,  ssl_new_constant (sc->sc_cc, box_num (1)), NULL);
  cv_bret (&code, 1);
  en->src_gen.src_after_test = code_to_cv (sc, code);
  if ((ajt = IS_TS (ts) ? ts->ts_after_join_test : ((hash_source_t *)ts)->hs_after_join_test))
    {
      SQL_NODE_INIT (end_node_t, en2, end_node_input, NULL);
      sql_node_append ((data_source_t **)&en, (data_source_t *)en2);
      en2->src_gen.src_after_test = ajt;
      if (IS_TS (ts))
	ts->ts_after_join_test = NULL;
      else
	((hash_source_t *) ts)->hs_after_join_test = NULL;
    }
  if (IS_TS (ts))
    ts->ts_is_outer = 0;
  else
    ((hash_source_t *)ts)->hs_is_outer = 0;
}


char *
ssl_inf_name (df_elt_t * dfe)
{
  static char name[30];
  state_slot_t * ssl = dfe ? dfe->dfe_ssl : NULL;
  if (!ssl || !ssl->ssl_name)
    return "inferred";
  snprintf (name, sizeof (name), "i-%s", ssl->ssl_name);
  name[sizeof (name) - 1] = 0;
  return name;
}


rdf_inf_ctx_t * sas_dummy_ctx;


void
sqlg_leading_subclass_inf (sqlo_t * so, data_source_t ** q_head, data_source_t * ts, df_elt_t * p_dfe, caddr_t p_const, df_elt_t * o_dfe, caddr_t o_iri,
			   rdf_inf_ctx_t * ctx, df_elt_t * tb_dfe, int inxop_inx, rdf_inf_pre_node_t * sas_o)
{
  rdf_inf_pre_node_t * ri;
  if (sas_dummy_ctx == ctx)
    return;
  if (p_const && !box_equal (rdfs_type, p_const))
    return;
  if (!p_const && !p_dfe && !sqlg_col_ssl (tb_dfe, "P"))
    return; /* if p is neither specified nor extracted, then do nothing.  P must ve specified or extracted if a dfe is for inference */
  ri = sqlg_rdf_inf_node (so->so_sc);
  qn_ins_before (tb_dfe->dfe_sqlo->so_sc, q_head, (data_source_t *)ts, (data_source_t *)ri);
  ri->ri_mode = RI_SUBCLASS;
  ri->ri_output = ssl_new_variable (o_dfe->dfe_sqlo->so_sc->sc_cc, ssl_inf_name (o_dfe), DV_IRI_ID);
  if (sas_o)
    {
      if ((qn_input_fn) trans_node_input == sas_o->src_gen.src_input)
	ri->ri_o = ((trans_node_t*)sas_o)->tn_output[0];
      else
	ri->ri_o = sas_o->ri_output;
    }
  else
    {
      if (o_iri)
	ri->ri_given = box_copy_tree (o_iri);
      ri->ri_o = o_dfe->dfe_ssl;
    }
  if (!p_const)
    {
      ri->ri_p = p_dfe ? p_dfe->dfe_ssl : sqlg_col_ssl (tb_dfe, "P");
      sqlg_ri_post_filter ((table_source_t *)ts, tb_dfe, ri, p_dfe ? 0 : 1);
      /* if the p is not fixed but still generating alternate O's, add node for filtering out hits with p != rdf:type */
    }
  sqlg_rdf_ts_replace_ssl ((table_source_t*) ts, ri->ri_o, ri->ri_output, 0, inxop_inx);
  if (!p_dfe)
    ri->ri_p = NULL; /* if P is open, all o's get expanded but the non-rdfs:type p's are filtered out afterwards */
  ri->ri_ctx = ctx;
}


void
sqlg_trailing_subclass_inf (sqlo_t * so, data_source_t ** q_head, data_source_t * ts, df_elt_t * p_dfe, caddr_t p_const, df_elt_t * o_dfe, caddr_t o_iri,
			    rdf_inf_ctx_t * ctx, df_elt_t * tb_dfe, int inxop_inx)
{
  state_slot_t * o_slot;
  rdf_inf_pre_node_t * ri;
  if (sas_dummy_ctx == ctx
      || tb_dfe->_.table.is_inf_col_given)
    return;
  if (p_const && !box_equal (rdfs_type, p_const))
    return;
  o_slot = sqlg_col_ssl (tb_dfe, "O");
  if (!o_slot)
    return; /* o is unspecified and but is not accessed */
  ri = sqlg_rdf_inf_node (so->so_sc);
  ri->ri_is_after = 1;
  sql_node_append (q_head, (data_source_t *)ri);
  ri->ri_mode = RI_SUPERCLASS;
  ri->ri_output = o_slot;
  ri->ri_o = o_slot;
  if (p_dfe)
    ri->ri_p = p_dfe->dfe_ssl;
  else
    ri->ri_p = sqlg_col_ssl (tb_dfe, "P");
  ri->ri_ctx = ctx;
}


void
sqlg_leading_subproperty_inf (sqlo_t * so, data_source_t ** q_head, data_source_t * ts, df_elt_t * p_dfe,
    caddr_t p_const, df_elt_t * o_dfe, caddr_t o_iri,
    rdf_inf_ctx_t * ctx, df_elt_t * tb_dfe, int inxop_inx, rdf_inf_pre_node_t * sas_p)
{
  rdf_inf_pre_node_t * ri;
  if (sas_dummy_ctx == ctx)
    return;
  if (!p_const && !p_dfe && !sqlg_col_ssl (tb_dfe, "P"))
    return; /* if p is neither specified nor extracted, then do nothing.  P must ve specified or extracted if a dfe is for inference */
  ri = sqlg_rdf_inf_node (so->so_sc);
  qn_ins_before (tb_dfe->dfe_sqlo->so_sc, q_head, (data_source_t *)ts, (data_source_t *)ri);
  ri->ri_mode = RI_SUBPROPERTY;
  ri->ri_output = ssl_new_variable (tb_dfe->dfe_sqlo->so_sc->sc_cc, ssl_inf_name (p_dfe), DV_IRI_ID);

  if (sas_p)
    {
      if ((qn_input_fn) trans_node_input == sas_p->src_gen.src_input)
	ri->ri_p = ((trans_node_t*)sas_p)->tn_output[0];
      else
	ri->ri_p = sas_p->ri_output;
    }
  else if (p_const)
    ri->ri_given = box_copy_tree (p_const);
  else
    {
      ri->ri_p = p_dfe ? p_dfe->dfe_ssl : sqlg_col_ssl (tb_dfe, "P");
    }
  if (ri->ri_outer_any_passed)
    sqlg_ri_post_filter ((table_source_t *)ts, tb_dfe, ri, 0);
  if (sas_p)
    {
      if ((qn_input_fn) trans_node_input == sas_p->src_gen.src_input)
	ri->ri_p = ((trans_node_t*)sas_p)->tn_output[0];
      else
	ri->ri_p = sas_p->ri_output;
    }
  else
    ri->ri_p = p_dfe->dfe_ssl;
  sqlg_rdf_ts_replace_ssl ((table_source_t*) ts, ri->ri_p, ri->ri_output, 0, inxop_inx);
  ri->ri_ctx = ctx;
}


void
sqlg_trailing_subproperty_inf (sqlo_t * so, data_source_t ** q_head, data_source_t * ts, df_elt_t * p_dfe, caddr_t p_const, df_elt_t * o_dfe, caddr_t o_iri,
			    rdf_inf_ctx_t * ctx, df_elt_t * tb_dfe, int inxop_inx)
{
  state_slot_t * p_slot;
  rdf_inf_pre_node_t * ri;
  if (sas_dummy_ctx == ctx
      || tb_dfe->_.table.is_inf_col_given)
    return;

  p_slot = sqlg_col_ssl (tb_dfe, "P");
  if (!p_slot)
    return; /* P is unspecified and but is not accessed */
  ri = sqlg_rdf_inf_node (so->so_sc);
  ri->ri_is_after = 1;
  sql_node_append (q_head, (data_source_t *)ri);
  ri->ri_mode = RI_SUPERPROPERTY;
  ri->ri_output = p_slot;
  ri->ri_p = p_slot;
  ri->ri_ctx = ctx;
}


rdf_inf_ctx_t *
sqlg_rdf_inf_same_as_opt (df_elt_t * tb_dfe)
{
  df_elt_t * dfe = tb_dfe;
  static rdf_inf_ctx_t * ctx;
  if (!ctx)
    {
      ctx = (rdf_inf_ctx_t *) dk_alloc (sizeof (rdf_inf_ctx_t));
      memset (ctx, 0, sizeof (rdf_inf_ctx_t));
      sas_dummy_ctx = ctx;
      ctx->ric_name = box_dv_short_string ("dummy");
      ctx->ric_iri_to_subclass = id_hash_allocate (3, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
      id_hash_set_rehash_pct (ctx->ric_iri_to_subclass, 200);
    }
  do
    {
      if (dfe->dfe_type == DFE_DT && sqlo_opt_value (dfe->_.table.ot->ot_opts, OPT_SAME_AS))
	{
	  return ctx;
	}
      dfe = dfe->dfe_super;
    }
  while (dfe);
  return NULL;
}

static void
sqlg_ts_copies_search_pars (table_source_t * ts)
{
  if (ts->ts_inx_op)
    {
      inx_op_t *iop = ts->ts_inx_op;
      int inx;
      DO_BOX (inx_op_t *, term, inx, iop->iop_terms)
        {
          term->iop_ks->ks_copy_search_pars = 1;
        }
      END_DO_BOX
    }
  if (ts->ts_order_ks)
    ts->ts_order_ks->ks_copy_search_pars = 1;
  if (ts->ts_main_ks)
    ts->ts_main_ks->ks_copy_search_pars = 1;
}

#define TS_COPIES_SEARCH_PARS do { \
    sqlg_ts_copies_search_pars ((table_source_t *)(ts)); \
    if (NULL != q_head[0]) \
      { \
        data_source_t *h = q_head[0]; \
        if (IS_TS (h)) \
          sqlg_ts_copies_search_pars ((table_source_t *)h); \
        while (h->src_continuations) \
          { \
            h = (data_source_t *) h->src_continuations->data; \
            if (h && IS_TS (h)) \
              sqlg_ts_copies_search_pars ((table_source_t *)h); \
          } \
      } \
  } while (0);

#define LEADING_SUBCLASS \
  sqlg_leading_subclass_inf (tb_dfe->dfe_sqlo, q_head, ts, p_dfe, const_p, o_dfe, const_o, ctx, tb_dfe, inxop_inx, sas_o)

#define TRAILING_SUBCLASS \
  sqlg_trailing_subclass_inf (tb_dfe->dfe_sqlo, q_head, ts, p_dfe, const_p, o_dfe, const_o, ctx, tb_dfe, inxop_inx)

#define LEADING_SUBP \
  sqlg_leading_subproperty_inf (tb_dfe->dfe_sqlo, q_head, ts, p_dfe, const_p, o_dfe, const_o, ctx, tb_dfe, inxop_inx, sas_p)

#define TRAILING_SUBP \
  sqlg_trailing_subproperty_inf (tb_dfe->dfe_sqlo, q_head, ts, p_dfe, const_p, o_dfe, const_o, ctx, tb_dfe, inxop_inx)


void
sqlg_leading_same_as (sqlo_t * so, data_source_t ** q_head, data_source_t * ts,
    df_elt_t * g_dfe, df_elt_t * s_dfe, df_elt_t * p_dfe,  df_elt_t * o_dfe, int mode,
    rdf_inf_ctx_t * ctx, df_elt_t * tb_dfe, int inxop_inx, rdf_inf_pre_node_t ** ri_ret)
{
  df_elt_t ** in_list;
  rdf_inf_pre_node_t * ri;
  if (1 /*!= cl_run_local_only */)
    {
      sqlg_leading_multistate_same_as (so, q_head, ts,
				       g_dfe,  s_dfe,  p_dfe,  o_dfe,  mode,
				       ctx, tb_dfe, inxop_inx, ri_ret);
      return;
    }
  if (!sqlg_rdf_inf_same_as_opt (tb_dfe))
    return;
  if (!g_dfe)
    sqlc_new_error (so->so_sc->sc_cc, "42000", "RDFSA", "Same-as expansion not allowed if graph not specified");
  ri = sqlg_rdf_inf_node (so->so_sc);
  *ri_ret = ri;
  qn_ins_before (tb_dfe->dfe_sqlo->so_sc, q_head, (data_source_t *)ts, (data_source_t *)ri);
  ri->ri_mode = mode;
  ri->ri_output = ssl_new_variable (tb_dfe->dfe_sqlo->so_sc->sc_cc, ssl_inf_name (/*RI_SAME_AS_P == mode ? p_dfe : */ RI_SAME_AS_O == mode ? o_dfe : s_dfe), DV_IRI_ID);
  if ((in_list = sqlo_in_list (g_dfe, NULL, NULL)))
    {
      int n = BOX_ELEMENTS (in_list) - 1, ginx;
      state_slot_t ** gs = (state_slot_t **) dk_alloc_box (sizeof (caddr_t) * n, DV_BIN);
      for (ginx = 1; ginx <= n; ginx++)
	{
	  gs[ginx - 1] = in_list[ginx]->dfe_ssl;
	}
      ri->ri_sas_g = gs;
    }
  else
    ri->ri_sas_g = (state_slot_t **) list (1, g_dfe->_.bin.right->dfe_ssl);

  if (RI_SAME_AS_O == mode)
    ri->ri_sas_in = o_dfe->dfe_ssl;
  else if (RI_SAME_AS_S == mode)
    ri->ri_sas_in = s_dfe->dfe_ssl;
  else if (RI_SAME_AS_P == mode)
    ri->ri_sas_in = p_dfe->dfe_ssl;
  sqlg_rdf_ts_replace_ssl ((table_source_t*) ts, ri->ri_sas_in, ri->ri_output, 0, inxop_inx);
  ri->ri_sas_out = ssl_new_variable (tb_dfe->dfe_sqlo->so_sc->sc_cc, "out", DV_UNKNOWN);
  ri->ri_sas_reached = ssl_new_variable (tb_dfe->dfe_sqlo->so_sc->sc_cc, "reached", DV_UNKNOWN);
  ri->ri_sas_follow = ssl_new_variable (tb_dfe->dfe_sqlo->so_sc->sc_cc, "follow", DV_UNKNOWN);
  ri->ri_sas_next_out = cc_new_instance_slot (so->so_sc->sc_cc);
  ri->ri_sas_last_out = cc_new_instance_slot (so->so_sc->sc_cc);
  ri->ri_sas_next_follow = cc_new_instance_slot (so->so_sc->sc_cc);
  ri->ri_sas_last_follow = cc_new_instance_slot (so->so_sc->sc_cc);
  ri->ri_ctx = ctx;
}


#define LEADING_SAME_AS_S \
  sqlg_leading_same_as (tb_dfe->dfe_sqlo, q_head, ts, g_dfe, s_dfe, p_dfe, o_dfe, RI_SAME_AS_S, \
			ctx, tb_dfe, inxop_inx, &sas_s)

#define LEADING_SAME_AS_O \
  sqlg_leading_same_as (tb_dfe->dfe_sqlo, q_head, ts, g_dfe, s_dfe, p_dfe, o_dfe, RI_SAME_AS_O, \
			ctx, tb_dfe, inxop_inx, &sas_o)

#define LEADING_SAME_AS_P \
  sqlg_leading_same_as (tb_dfe->dfe_sqlo, q_head, ts, g_dfe, s_dfe, p_dfe, o_dfe, RI_SAME_AS_P, \
			ctx, tb_dfe, inxop_inx, &sas_p)

#define LEADING_IFP_S \
  sqlg_leading_same_as (tb_dfe->dfe_sqlo, q_head, ts, g_dfe, s_dfe, p_dfe, o_dfe, RI_SAME_AS_IFP | RI_SAME_AS_S, \
			ctx, tb_dfe, inxop_inx, &sas_s)

#define LEADING_IFP_O \
  sqlg_leading_same_as (tb_dfe->dfe_sqlo, q_head, ts, g_dfe, s_dfe, p_dfe, o_dfe, RI_SAME_AS_IFP | RI_SAME_AS_O, \
			ctx, tb_dfe, inxop_inx, &sas_o)


caddr_t
dfe_iri_const (df_elt_t * dfe)
{
  caddr_t name;
  if (!dfe)
    return NULL;
  name = sqlo_iri_constant_name (dfe->dfe_tree);
  if (name)
    return key_name_to_iri_id (NULL, name, 0);
  return NULL;
}


void
sqlg_rdf_inf_1 (df_elt_t * tb_dfe, data_source_t * ts, data_source_t ** q_head, int inxop_inx)
{
  /* if the dfe is from rdf_quad and inference si on, recognize which combination of spo is fixed and add the inf nodes before or after.  Works for table source and hash source  */
  rdf_inf_slots_t ris;
  sql_comp_t * sc = tb_dfe->dfe_sqlo->so_sc;
  dk_set_t col_preds;
  caddr_t ctx_name = sqlo_opt_value (tb_dfe->_.table.ot->ot_opts, OPT_RDF_INFERENCE);
  rdf_inf_ctx_t * ctx, **place, *sas_ctx;
  rdf_inf_pre_node_t * sas_s = NULL, * sas_o = NULL, * sas_p = NULL;
  caddr_t /*const_s = NULL,*/ const_p = NULL, const_o = NULL;
  df_elt_t * g_dfe = NULL, * s_dfe = NULL, * p_dfe = NULL, * o_dfe = NULL;
  if (!IS_TS (((table_source_t*)ts))
      && (qn_input_fn)hash_source_input != ts->src_input)
    return;
  if (-1 != inxop_inx)
    {
      df_inx_op_t * dio = (df_inx_op_t *)
	dk_set_nth (tb_dfe->_.table.inx_op->dio_terms, inxop_inx);
      tb_dfe = dio->dio_table;
    }
  if (stricmp (tb_dfe->_.table.ot->ot_table->tb_name, "DB.DBA.RDF_QUAD"))
    return;
  ctx_name = sqlo_opt_value (tb_dfe->_.table.ot->ot_opts, OPT_RDF_INFERENCE);
  place = ctx_name ? (rdf_inf_ctx_t**)id_hash_get (rdf_name_to_ric, (caddr_t)&ctx_name) : NULL;
  sas_ctx = sqlg_rdf_inf_same_as_opt (tb_dfe);
  if (!ctx_name && !sas_ctx)
    return;
  if (ctx_name && !place)
    {
      sqlc_new_error (tb_dfe->dfe_sqlo->so_sc->sc_cc, "42000", "RDF..", "Inference context %s does not exist", ctx_name);
    }
  ctx = place ? *place : sas_ctx;
  col_preds = tb_dfe->_.table.col_preds;
  DO_SET (df_elt_t *, cp, &col_preds)
    {
      df_elt_t ** g_in_list = sqlo_in_list (cp, NULL, NULL);
      dbe_column_t * col = g_in_list ? g_in_list[0]->_.col.col : cp->_.bin.left->_.col.col;
      if (BOP_EQ != cp->_.bin.op)
	continue;
      if (cp->_.bin.left == cp->_.bin.right)
	continue;
      if (g_in_list && col->col_name[0] != 'G')
	continue;
      switch (col->col_name[0])
	{
	case 'G': g_dfe = cp; break;
	case 'S': s_dfe = cp->_.bin.right; break;
	case 'P': p_dfe = cp->_.bin.right; break;
	case 'O': o_dfe = cp->_.bin.right; break;
	}
    }
  END_DO_SET();
  /*const_s = dfe_iri_const (s_dfe);*/
  const_p = dfe_iri_const (p_dfe);
  const_o = dfe_iri_const (o_dfe);
  memset (&ris, 0, sizeof (ris));
  sc->sc_rdf_inf_slots = &ris;
  if (!s_dfe && !p_dfe && !o_dfe)
    {
      TS_COPIES_SEARCH_PARS;
      TRAILING_SUBCLASS;
      TRAILING_SUBP;
    }
  else if (!s_dfe && !p_dfe && o_dfe)
    {
      LEADING_IFP_O;
      LEADING_SAME_AS_O;
      LEADING_SUBCLASS;
      TS_COPIES_SEARCH_PARS;
      TRAILING_SUBP;
    }
  else if (!s_dfe && p_dfe && !o_dfe)
    {
      LEADING_SAME_AS_P;
      LEADING_SUBP;
      TS_COPIES_SEARCH_PARS;
      TRAILING_SUBCLASS;
    }
  else if (!s_dfe && p_dfe && o_dfe)
    {
      LEADING_IFP_O;
      LEADING_SAME_AS_O;
      LEADING_SAME_AS_P;
      LEADING_SUBP;
      LEADING_SUBCLASS;
    }
  else if (s_dfe && !p_dfe && !o_dfe)
    {
      LEADING_IFP_S;
      LEADING_SAME_AS_S;
      TS_COPIES_SEARCH_PARS;
      TRAILING_SUBCLASS;
      TRAILING_SUBP;
    }
  else if (s_dfe && !p_dfe && o_dfe)
    {
      LEADING_IFP_S;
      LEADING_IFP_O;
      LEADING_SAME_AS_O;
      LEADING_SAME_AS_S;
      LEADING_SUBCLASS;
      TS_COPIES_SEARCH_PARS;
      TRAILING_SUBP;
    }
  else if (s_dfe && p_dfe && !o_dfe)
    {
      LEADING_IFP_S;
      LEADING_SAME_AS_S;
      LEADING_SAME_AS_P;
      LEADING_SUBP;
      TS_COPIES_SEARCH_PARS;
      TRAILING_SUBCLASS;
    }
  else if (s_dfe && p_dfe && o_dfe)
    {
      LEADING_IFP_S;
      LEADING_IFP_O;
      LEADING_SAME_AS_S;
      LEADING_SAME_AS_O;
      LEADING_SAME_AS_P;
      LEADING_SUBP;
      LEADING_SUBCLASS;
    }
  else
    GPF_T1 (" all possibilities of spo already covered");
  dk_free_box (const_p);
  dk_free_box (const_o);
  sc->sc_rdf_inf_slots = NULL;
}

void
sqlg_rdf_inf (df_elt_t * tb_dfe, data_source_t * qn, data_source_t ** q_head)
{
  if (IS_TS ((table_source_t *)qn) && ((table_source_t *)qn)->ts_inx_op)
    {
      table_source_t * ts = (table_source_t *)qn;
      int inx;
      DO_BOX (inx_op_t *, iop, inx, ts->ts_inx_op->iop_terms)
	{
	  sqlg_rdf_inf_1 (tb_dfe, qn, q_head, inx);
	}
      END_DO_BOX;
    }
  else
    sqlg_rdf_inf_1 (tb_dfe, qn, q_head, -1);
}

data_source_t *
qn_prev (data_source_t ** head , data_source_t * qn)
{
  data_source_t * it, *prev = NULL;
  for (it = *head; it; it = qn_next (it))
    {
      if (qn == it)
	return prev;
      prev = it;
    }
  return NULL;
}


data_source_t *
qn_ensure_prev (sql_comp_t * sc, data_source_t ** head , data_source_t * qn)
{
  data_source_t * prev = qn_prev (head, qn);
  if (prev)
    return prev;
  {
    SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
    dk_set_push (&en->src_gen.src_continuations, (void*)*head);
    *head = (data_source_t *) en;
    return (data_source_t *) en;
  }
}


#define IS_ITER(qn) \
  (((qn_input_fn) rdf_inf_pre_input == (qn)->src_input && !((rdf_inf_pre_node_t *)(qn))->ri_is_after) \
    || (qn_input_fn)in_iter_input  == (qn)->src_input)


void
sqlc_asg_mark (state_slot_t * ssl)
{
  dk_hash_t * ht = (dk_hash_t *) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ASG_SET);
  if (ht && ssl)
    sethash ((void*)ssl, ht, (void*)(ptrlong) 1);
}

code_vec_t
qn_after_join_test (data_source_t * qn)
{
  if (IS_TS (qn))
    return ((table_source_t*)qn)->ts_after_join_test;
  if (IS_QN (qn, hash_source_input))
    return ((hash_source_t*)qn)->hs_after_join_test;
  if (IS_QN (qn, subq_node_input))
    return ((subq_source_t*)qn)->sqs_after_join_test;
  return NULL;
}

void
qn_set_after_join_test (data_source_t * qn, code_vec_t tst)
{
  if (IS_TS (qn))
    ((table_source_t*)qn)->ts_after_join_test = tst;
  if (IS_QN (qn, hash_source_input))
    ((hash_source_t*)qn)->hs_after_join_test = tst;
  if (IS_QN (qn, subq_node_input))
    ((subq_source_t*)qn)->sqs_after_join_test = tst;
}


outer_seq_end_node_t *
sqlg_cl_bracket_outer (sqlo_t * so, data_source_t * first)
{
  /* brackets the space between the successor of first and the end of the generated query seq between a set ctr and outer seq end node
   * Each set that comes in either produces an output or an output is filled with nulls and inserted in the right place in the sequence no matter how complicated the nodes in between are */
  /* first find what nodes are assigned in the bracketed space. */
  sql_comp_t * sc = so->so_sc;
  outer_seq_end_node_t * ose;
  dk_hash_t * res = hash_table_allocate (11);
  data_source_t * first1 = first ? qn_next (first) : NULL;
  data_source_t * org_first = first1;
  void * dp;
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ASG_SET, res);
  sc->sc_any_clb = 1;
  while (first1)
    {
      int is_sc;
      code_vec_t ajt = qn_after_join_test (first1);
      /* an after join test of an outer ts/hs/subq does not have its ssls assigned inside the outer section. */
      qn_set_after_join_test (first1, NULL);
      qn_refd_slots (so->so_sc, first1, NULL, NULL, &is_sc);
      qn_set_after_join_test (first1, ajt);
      first1 = qn_next (first1);
    }
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ASG_SET, NULL);
  {
    int inx;
    SQL_NODE_INIT (outer_seq_end_node_t, ose2, outer_seq_end_input, ose_free);
    ose = ose2;
    ose->ose_out_slots = (state_slot_t **) ht_keys_to_array (res);
    DO_BOX (state_slot_t *, ssl, inx, ose->ose_out_slots)
      {
	ssl->ssl_always_vec = 1;
      }
    END_DO_BOX;
    ose->ose_set_no = ssl_new_inst_variable (so->so_sc->sc_cc, "set_ctr", DV_LONG_INT);
    ose->ose_prev_set_no = ssl_new_inst_variable (so->so_sc->sc_cc, "prev_set_ctr", DV_LONG_INT);
    ose->ose_buffered_row = ssl_new_inst_variable (so->so_sc->sc_cc, "buf_row", DV_ARRAY_OF_POINTER);
    ose->ose_last_outer_set = cc_new_instance_slot (so->so_sc->sc_cc);
    hash_table_free (res);
    sql_node_append (&first, (data_source_t*)ose);
  }
  {
    data_source_t * qn;
    SQL_NODE_INIT (set_ctr_node_t, sctr, set_ctr_input, set_ctr_free);
    qn_ins_before (sc, &first, qn_next (first), (data_source_t *) sctr);
    clb_init (sc->sc_cc, &sctr->clb, 1);
    sctr->sctr_role = SCTR_OJ;
    sctr->sctr_itcl = ssl_new_inst_variable (so->so_sc->sc_cc, "buf_row", DV_ARRAY_OF_POINTER);
    sctr->sctr_ose = ose;
    sctr->sctr_set_no = ose->ose_set_no;
    ose->ose_sctr = sctr;
    for (qn = qn_next ((data_source_t*)sctr); qn != (data_source_t*)ose && qn; qn = qn_next (qn))
      dk_set_push (&sctr->sctr_continuable, (void*)qn);
    if (sc->sc_qn_to_dpipe && (dp = (data_source_t*)gethash ((void*)org_first, sc->sc_qn_to_dpipe)))
      {
	remhash ((void*)org_first, sc->sc_qn_to_dpipe);
	sethash ((void*)sctr, sc->sc_qn_to_dpipe, (void*)dp);
      }
  }
  return ose;
}


#define IS_IN_ITER(qn) \
  ((qn_input_fn)in_iter_input  == (qn)->src_input)


void
sqlg_cl_outer_with_iters (df_elt_t * tb_dfe, data_source_t * ts, data_source_t ** head)
{
  /* if the ts has in iters or rdf inf iters before it bracket the whole
   * leading iters + driving ts + main key ts + post iters inside a set_ctr - outer seq end node pair */
  sql_comp_t * sc = tb_dfe->dfe_sqlo->so_sc;
  code_vec_t ojt = NULL;
  data_source_t * first_iter = NULL;
  data_source_t * qn = *head;
  outer_seq_end_node_t * ose = NULL;
  while (qn)
    {
      if (IS_ITER (qn))
	{
	  if (!first_iter)
	    first_iter = qn;
    }
      else if (ts == qn)
	{
	  data_source_t * before;
	  if (!first_iter && !qn_next (ts) && !sqlg_is_vector)
	    return; /* if the ts is not  rapped in iters before or after, use its own outer flag */
	  if (!first_iter)
	    first_iter = qn;
	  before = qn_prev (head, first_iter);
	  ose = sqlg_cl_bracket_outer (tb_dfe->dfe_sqlo, before);
	  for (ts = ts; ts; ts = qn_next (ts))
	    {
	      if (IS_TS (((table_source_t*)ts)))
		{
		  QNCAST (table_source_t, ts2, ts);
		  if (ts2->ts_after_join_test)
		    {
		      ojt = ts2->ts_after_join_test;
		      ts2->ts_after_join_test = NULL;
		    }
		  ts2->ts_is_outer = 0;
		}
	      else if (IS_HS (ts))
		{
		  QNCAST (hash_source_t, hs, ts);
		  if (hs->hs_after_join_test)
		    {
		      ojt = hs->hs_after_join_test;
		      hs->hs_after_join_test = NULL;
		    }
		  hs->hs_is_outer = 0;
		}
	    }
	}
      else
	first_iter = NULL;
      qn = qn_next (qn);
    }
  if (!ose) SQL_GPF_T1 (tb_dfe->dfe_sqlo->so_sc->sc_cc, "supposed to have ose in bracket outer");
  if (ojt)
    ose->src_gen.src_after_test = ojt;
}


void
sqlg_outer_with_iters (df_elt_t * tb_dfe, data_source_t * ts, data_source_t ** head)
{
  /* if the ts has in iters or rdf inf iters before it, make the outermost iter node handle the outer output and add a node after the ts to set the any passed flag */
  sql_comp_t * sc = tb_dfe->dfe_sqlo->so_sc;
  data_source_t * first_iter = NULL;
  data_source_t * qn = *head;
  if (1 != cl_run_local_only || tb_dfe->_.table.index_path || sqlg_is_vector)
    {
      sqlg_cl_outer_with_iters (tb_dfe, ts, head);
      return;
    }
  while (qn)
    {
      if (IS_ITER (qn))
	{
	  if (!first_iter)
	    first_iter = qn;
    }
      else if (ts == qn)
	{
	  if (first_iter)
	    {
	      if (IS_IN_ITER (first_iter))
		{
		  in_iter_node_t * ii = (in_iter_node_t *) first_iter;
		  ii->ii_outer_any_passed = ssl_new_variable (tb_dfe->dfe_sqlo->so_sc->sc_cc, "any_passed", DV_LONG_INT);
		  sqlg_outer_post_filter ((table_source_t *) ts, tb_dfe, ii->ii_outer_any_passed);
		}
	      else
		{
		  rdf_inf_pre_node_t * ri = (rdf_inf_pre_node_t *) first_iter;
		  ri->ri_outer_any_passed = ssl_new_variable (tb_dfe->dfe_sqlo->so_sc->sc_cc, "any_passed", DV_LONG_INT);
		  sqlg_outer_post_filter ((table_source_t *) ts, tb_dfe, ri->ri_outer_any_passed);
		}

	    }
	}
      else
	first_iter = NULL;
      qn = qn_next (qn);
    }
}
