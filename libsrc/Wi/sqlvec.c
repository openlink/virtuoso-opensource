/*
 *  sqlvec.c
 *
 *  $Id$
 *
 *  Vectorize SQL query graph
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2011 OpenLink Software
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


#define VEC_SINGLE_STATE 4

#define SSL_IS_SCALAR(ssl) (SSL_VEC != ssl->ssl_type && SSL_REF != ssl->ssl_type)


int sqlg_vec_debug = 0;
state_slot_ref_t *sqlg_vec_ssl_ref (sql_comp_t * sc, state_slot_t * ssl, int test_only);
search_spec_t *ks_find_eq_sp (key_source_t * ks, oid_t col_id);
void cv_vec_slots (sql_comp_t * sc, code_vec_t cv, dk_hash_t * res, dk_hash_t * all_res, int *non_cl_local);
void sqlg_vec_ts (sql_comp_t * sc, table_source_t * ts);
void sqlg_vec_cast (sql_comp_t * sc, state_slot_ref_t ** refs, state_slot_t ** casts, dc_val_cast_t * val_cast,
    state_slot_t ** ssl_ret, int fill, state_slot_t ** card_ssl, sql_type_t * target_sqt, int copy_always);
int ssl_is_const_card (sql_comp_t * sc, state_slot_t * ssl, sql_type_t * sqt);
void sqlg_ts_add_copy (sql_comp_t * sc, table_source_t * ts, state_slot_t ** ssls);



state_slot_t **
sqlg_continue_reset (data_source_t * qn, dk_set_t except)
{
  dk_set_t res = NULL;
  int inx;
  if (!except)
    {
      return (state_slot_t **) box_copy ((caddr_t) qn->src_pre_reset);
    }
  DO_BOX (state_slot_t *, ssl, inx, qn->src_pre_reset)
  {
    DO_SET (state_slot_t *, x, &except) if (x == ssl)
      goto next;
    END_DO_SET ();
    dk_set_push (&res, (void *) ssl);
  next:;
  }
  END_DO_BOX;
  return (state_slot_t **) list_to_array (res);
}


void
sqlg_hs_no_out_reset (hash_source_t * hs, state_slot_t *** ssls_ret)
{
  /* a hash source can be merged into a ts in which case the ts will do the resets and the hash is a dummy.  This may be decided at run time.  Therefore the hs explicitly resets its outputs when it runs by itself, so the outputs must not be in the automatic reset lists */
  state_slot_t **arr = *ssls_ret;
  int inx, inx2;
  dk_set_t res = NULL;
  DO_BOX (state_slot_t *, ssl, inx, arr)
  {
    DO_BOX (state_slot_t *, out, inx2, hs->hs_out_slots)
    {
      if (out == ssl)
	goto skip;
    }
    END_DO_BOX;
    t_set_push (&res, (void *) ssl);
  skip:;
  }
  END_DO_BOX;
  dk_free_box ((caddr_t) arr);
  *ssls_ret = (state_slot_t **) dk_set_to_array (res);
}


void
sqlg_new_vec_ssls (sql_comp_t * sc, data_source_t * qn)
{
  state_slot_t ***ssls = &qn->src_pre_reset;
  if (IS_QN (qn, fun_ref_node_input))
    {
      QNCAST (fun_ref_node_t, fnr, qn);
      /* a fun ref does not reset its aggregates in pre reset because there can be many inputs for the same aggregation if partitioned hash join.  The fref input resets these on the first partition */
      DO_SET (state_slot_t *, agg, &fnr->fnr_default_ssls)
	t_set_delete (&sc->sc_vec_new_ssls, (void*)agg);
      END_DO_SET ();
    }
  if (!sc->sc_vec_new_ssls)
    return;

  if (!*ssls)
    *ssls = (state_slot_t **) dk_set_to_array (sc->sc_vec_new_ssls);
  else
    {
      DO_SET (state_slot_t *, ssl, &sc->sc_vec_new_ssls)
	  * ssls = (state_slot_t **) box_append_1_free ((caddr_t) * ssls, (caddr_t) ssl);
      END_DO_SET ();
    }
  sc->sc_vec_new_ssls = NULL;
  if (IS_TS (qn) || IS_QN (qn, sort_read_input) || IS_QN (qn, chash_read_input) || IS_QN (qn, trans_node_input)
      || IS_QN (qn, query_frag_input) || IS_QN (qn, cl_fref_read_input) || IS_QN (qn, txs_input)
      || IS_QN (qn, geo_node_input)
      || IS_QN (qn, remote_table_source_input)
      || IS_QN (qn, in_iter_input) || IS_QN (qn, rdf_inf_pre_input))
    {
      dk_free_box ((caddr_t) qn->src_continue_reset);
      qn->src_continue_reset = sqlg_continue_reset (qn, sc->sc_ssl_prereset_only);
    }
  if (IS_QN (qn, hash_source_input))
    {
      dk_free_box ((caddr_t) qn->src_continue_reset);
      qn->src_continue_reset = sqlg_continue_reset (qn, sc->sc_ssl_prereset_only);
      sqlg_hs_no_out_reset ((hash_source_t *) qn, &qn->src_pre_reset);
      sqlg_hs_no_out_reset ((hash_source_t *) qn, &qn->src_continue_reset);
    }
}


dc_val_cast_t
sqlg_dc_cast_func (sql_comp_t * sc, state_slot_t * target, state_slot_t * source)
{
  /* casts between column (target) and value to insert or compare (source).  Use sqt_col_dtp on the target */
  dtp_t target_dtp = target->ssl_sqt.sqt_col_dtp;
  if (!target_dtp)
    target_dtp = target->ssl_sqt.sqt_dtp;
  if (dtp_canonical[target_dtp] == dtp_canonical[source->ssl_sqt.sqt_dtp])
    {
      if (vec_box_dtps[dtp_canonical[target_dtp]])
	return vc_box_copy;
      return NULL;
    }
  if (IS_DT_DTP (target_dtp) && IS_DT_DTP (source->ssl_dtp))
    return NULL;
  if (DV_ANY == target_dtp && IS_IRI_DTP (source->ssl_sqt.sqt_dtp))
    return vc_anynn_iri;
  if (IS_IRI_DTP (target_dtp) && DV_ANY == source->ssl_dc_dtp)
    return vc_irinn_any;
  if (DV_ANY == target->ssl_sqt.sqt_dtp)
    return vc_anynn;
  if (DV_ANY == target->ssl_dc_dtp)
    return vc_anynn_generic;

  return vc_generic;
  sqlc_new_error (sc->sc_cc, "22032", "VEC..", "No cast from %s to %s", dv_type_title (source->ssl_sqt.sqt_dtp),
      dv_type_title (target->ssl_sqt.sqt_dtp));
  return NULL;
}


int ssl_needs_vec_copy (sql_comp_t * sc, state_slot_t * ssl);


void
ssl_set_dc_type (state_slot_t * ssl)
{
  /* if it is not an inlined number/datetime, the dc type will be dv any */
  dtp_t dtp = ssl->ssl_sqt.sqt_dtp;
  if (DV_ANY == ssl->ssl_dc_dtp && !vec_box_dtps[ssl->ssl_dtp])
    return;			/* can be in cond expr or union that a thing is inferred any. If falsely declared as non-any and non-box later, do not change the dc type.  But if declared as box, do change it since box is the most general */
  if (ssl->ssl_sqt.sqt_col_dtp && !vec_box_dtps[ssl->ssl_dtp])
    dtp = ssl->ssl_sqt.sqt_col_dtp;
  dtp = dtp_canonical[dtp];
  if (vec_box_dtps[dtp])
    {
      ssl->ssl_dc_dtp = dtp;
      return;
    }
  switch (dtp)
    {
    case DV_SHORT_INT:
    case DV_LONG_INT:
    case DV_INT64:
    case DV_IRI_ID:
    case DV_IRI_ID_8:
    case DV_DOUBLE_FLOAT:
    case DV_SINGLE_FLOAT:
    case DV_DATETIME:
    case DV_DATE:
    case DV_TIME:
    case DV_TIMESTAMP:
      ssl->ssl_dc_dtp = dtp;
      break;
    default:
      ssl->ssl_dc_dtp = DV_ANY;
    }
}


state_slot_t *
ssl_new_vec (comp_context_t * cc, const char *name, dtp_t dtp)
{
  state_slot_t *ssl = ssl_new_inst_variable (cc, name, dtp);
  ssl->ssl_box_index = cc_new_instance_slot (cc);
  ssl->ssl_type = SSL_VEC;
  if (DV_UNKNOWN != dtp)
    ssl_set_dc_type (ssl);
  return ssl;
}


state_slot_t *
ssl_base_ssl (state_slot_t * ssl)
{
  if (SSL_REF == ssl->ssl_type)
    return ((state_slot_ref_t *) ssl)->sslr_ssl;
  return ssl;
}


void
ssl_vec (sql_comp_t * sc, state_slot_t * ssl, int is_agg)
{
  if (ssl && SSL_REF == ssl->ssl_type)
    GPF_T1 ("not supposed to assign a ssl ref");
  if (!ssl || (ssl->ssl_qr_global && SSL_VEC != ssl->ssl_type && !ssl->ssl_vec_param))
    return;
  ssl->ssl_type = SSL_VEC;
  if (!ssl->ssl_box_index)
    ssl->ssl_box_index = cc_new_instance_slot (sc->sc_cc);
  ssl_set_dc_type (ssl);
  if (!is_agg && !dk_set_member (sc->sc_cc->cc_super_cc->cc_query->qr_parms, ssl))
    t_set_pushnew (&sc->sc_vec_new_ssls, (void *) ssl);
}


void
ssl_vec_if (sql_comp_t * sc, state_slot_t * ssl, state_slot_t * r1, state_slot_t * r2)
{
  if (SSL_VEC == ssl->ssl_type)
    return;
  if ((r1 && (SSL_VEC == r1->ssl_type || SSL_REF == r1->ssl_type)) || (r2 && (SSL_VEC == r2->ssl_type || SSL_REF == r2->ssl_type)))
    ssl_vec (sc, ssl, 0);
}


void
sqlg_branch_copy (sql_comp_t * sc, data_source_t * qn, state_slot_t * ssl)
{
  int inx, place = -1, len;
  state_slot_t **ssls2;
  QNCAST (table_source_t, ts, qn);
  if (!IS_TS (qn))
    return;
  if (!ts->ts_aq)
    return;
  if (!ts->ts_branch_ssls)
    ts->ts_branch_ssls = (state_slot_t **) dk_alloc_box_zero (4 * sizeof (caddr_t), DV_BIN);
  DO_BOX (state_slot_t *, cp, inx, ts->ts_branch_ssls)
  {
    if (!cp && -1 == place)
      place = inx;
    if (cp == ssl)
      return;
  }
  END_DO_BOX;
  if (-1 != place)
    {
      ts->ts_branch_ssls[place] = ssl;
      return;
    }
  len = BOX_ELEMENTS (ts->ts_branch_ssls);
  ssls2 = (state_slot_t **) dk_alloc_box_zero ((4 + len) * sizeof (caddr_t), DV_BIN);
  memcpy (ssls2, ts->ts_branch_ssls, len * sizeof (caddr_t));
  ssls2[len] = ssl;
  dk_free_box ((caddr_t) ts->ts_branch_ssls);
  ts->ts_branch_ssls = ssls2;
}


void
sqlg_all_branch_copy (sql_comp_t * sc, state_slot_t * ssl)
{
  /* if ssl is global and refd, must make sure all branching before the ref keeps a copy */
  DO_SET (data_source_t *, qn, &sc->sc_vec_pred)
    sqlg_branch_copy (sc, qn, ssl);
  END_DO_SET ();
}


typedef struct _sc_prov_cast_s
{
  /* if a ssl is passed to qf or dfg with a cast and is then refd many times, undo the initial cast and let the ks concerned do the cast as a local only cast in ks_cl_local_castp */
  key_source_t *pca_ks;
  state_slot_t *pca_source_ssl;
} sc_prov_cast_t;

#define SSL_SHADOW(ssl) ((state_slot_t*)gethash ((void*)(ptrlong)ssl->ssl_index, sc->sc_vec_ssl_shadow))

void
ks_add_local_cast (sql_comp_t * sc, key_source_t * ks, state_slot_t * cast)
{
  state_slot_t *cpy = ssl_new_vec (sc->sc_cc, "lcast", DV_UNKNOWN);
  cpy->ssl_sqt = cast->ssl_sqt;
  cpy->ssl_dc_dtp = cast->ssl_dc_dtp;
  BOX_CONC_1 (ks->ks_cl_local_cast, cast);
  BOX_CONC_1 (ks->ks_cl_local_cast, cpy);
}


void
sqlg_revert_pca (sql_comp_t * sc, state_slot_t * ssl, sc_prov_cast_t * pca)
{
  int inx;
  key_source_t *ks = pca->pca_ks;
  DO_BOX (state_slot_t *, source, inx, pca->pca_ks->ks_vec_source)
  {
    if (source == pca->pca_source_ssl)
      {
	ks_add_local_cast (sc, ks, ks->ks_vec_cast[inx]);
	ks->ks_vec_cast[inx]->ssl_sqt = source->ssl_sqt;
	ks->ks_vec_cast[inx]->ssl_dc_dtp = source->ssl_dc_dtp;
	ks->ks_dc_val_cast[inx] = NULL;
	remhash ((void *) (ptrlong) ssl->ssl_index, sc->sc_vec_prov_cast);
	return;
      }
  }
  END_DO_BOX;
}


void
sqlg_mark_prov_cast (sql_comp_t * sc, key_source_t * ks, state_slot_t * source, state_slot_t * cast)
{
  /* if this is from typed to any, mark it because this may have to be reverted if somebody else wants the dc in it typed form */
  if (DV_ANY == cast->ssl_sqt.sqt_dtp && DV_ANY != source->ssl_sqt.sqt_dtp)
    {
      t_NEW_VARZ (sc_prov_cast_t, pca);
      if (!sc->sc_vec_prov_cast)
	sc->sc_vec_prov_cast = hash_table_allocate (11);
      sethash ((void *) (ptrlong) source->ssl_index, sc->sc_vec_prov_cast, (void *) pca);
      pca->pca_ks = ks;
      pca->pca_source_ssl = source;
    }
}


state_slot_t *
ssl_new_shadow (sql_comp_t * sc, state_slot_t * org, data_source_t * defd_in)
{
  state_slot_t *s = ssl_new_vec (sc->sc_cc, org->ssl_name ? org->ssl_name : "unnamed", org->ssl_dtp);
  s->ssl_sqt.sqt_non_null = org->ssl_sqt.sqt_non_null;
  sethash ((void *) (ptrlong) org->ssl_index, sc->sc_vec_ssl_shadow, s);
  sethash ((void *) s, sc->sc_vec_ssl_def, (void *) defd_in);
  return s;
}


void
sqlg_ssl_arr_shadow (sql_comp_t * sc, state_slot_t ** ssls)
{
  int inx;
  DO_BOX (state_slot_t *, ssl, inx, ssls)
  {
    state_slot_t *shadow = (state_slot_t *) gethash ((void *) (ptrlong) ssl->ssl_index, sc->sc_vec_ssl_shadow);
    if (shadow)
      ssls[inx] = shadow;
  }
  END_DO_BOX;
}


data_source_t *
sqlg_qn_first_of (sql_comp_t * sc, data_source_t * qn)
{
  if (!sc->sc_vec_qf)
    return NULL;
  if (qn == sc->sc_vec_qf->qf_head_node)
    return (data_source_t *) sc->sc_vec_qf;
  if (IS_QN (sc->sc_vec_qf->qf_head_node, stage_node_input) && qn == qn_next (sc->sc_vec_qf->qf_head_node))
    return sc->sc_vec_qf->qf_head_node;
  return NULL;
}


#if 0
void
sqlg_qf_add_param (data_source_t * qf, state_slot_t * ssl)
{
  int is_stn = IS_QN (qf, stage_node_input);
  state_slot_t ***params = is_stn ? &((stage_node_t *) qf)->stn_params : &((query_frag_t *) qf)->qf_params;
  if (*params)
    {
      int inx;
      DO_BOX (state_slot_t *, p, inx, *params)
	if (ssl == p)
	return;
      END_DO_BOX;
      *params = (state_slot_t **) box_append_1_free ((caddr_t) * params, (caddr_t) ssl);
    }
  else
    *params = (state_slot_t **) list (1, ssl);
}
#endif

void
sqlg_qf_scalar_param (sql_comp_t * sc, state_slot_t * ssl)
{
#if 0
  DO_SET (data_source_t *, qn, &sc->sc_vec_pred)
  {
    if (IS_QN (qn, stage_node_input))
      sqlg_qf_add_param (qn, ssl);
    else if (IS_QN (qn, query_frag_input))
      {
	sqlg_qf_add_param (qn, ssl);
	return;
      }
  }
  END_DO_SET ();
#endif
}


table_source_t *
qn_loc_ts (data_source_t * qn, int must_have)
{
  return NULL;
}


void
ks_add_cast (sql_comp_t * sc, key_source_t * ks, state_slot_ref_t * ref, state_slot_t * shadow)
{
  if (!ks->ks_vec_source)
    {
      ks->ks_vec_source = (state_slot_ref_t **) list (1, ref);
      ks->ks_vec_cast = (state_slot_t **) list (1, shadow);
      ks->ks_dc_val_cast = (dc_val_cast_t *) list (1, NULL);
    }
  else
    {
      ks->ks_vec_source = (state_slot_ref_t **) box_append_1_free ((caddr_t) ks->ks_vec_source, (caddr_t) ref);
      ks->ks_vec_cast = (state_slot_t **) box_append_1_free ((caddr_t) ks->ks_vec_cast, (caddr_t) shadow);
      ks->ks_dc_val_cast = (dc_val_cast_t *) box_append_1_free ((caddr_t) ks->ks_dc_val_cast, NULL);
    }
}


#if 0
state_slot_t *
sqlg_qf_param (sql_comp_t * sc, data_source_t * qn, state_slot_t * ssl)
{
  table_source_t *loc_ts = qn_loc_ts (qn, 1);
  state_slot_t *shadow;
  dk_set_t save_pred = sc->sc_vec_pred;
  state_slot_ref_t *ref;
  shadow = ssl_new_vec (sc->sc_cc, ssl->ssl_name, ssl->ssl_sqt.sqt_dtp);
  sc->sc_vec_pred = dk_set_member (sc->sc_vec_pred, (void *) qn)->next;
  if (IS_QN (sc->sc_vec_pred->data, query_frag_input) && !((query_frag_t *) sc->sc_vec_pred->data)->src_gen.src_sets)
    sc->sc_vec_pred = sc->sc_vec_pred->next;	/* if stn and then unfinished  qf, then means the stn is 1st of qf and ref startes as if before the qf */
  ref = sqlg_vec_ssl_ref (sc, ssl, 0);
  sethash ((void *) (ptrlong) ssl->ssl_index, sc->sc_vec_ssl_shadow, (void *) shadow);
  ks_add_cast (sc, loc_ts->ts_order_ks, ref, shadow);
  sqlg_qf_add_param (qn, shadow);
  sc->sc_vec_pred = save_pred;
  return shadow;
}
#endif


qf_select_node_t *
qf_select_node (query_frag_t * qf)
{
  DO_SET (qf_select_node_t *, qfs, &qf->qf_nodes)
    if (IS_QN (qfs, qf_select_node_input))
    return qfs;
  END_DO_SET ();
  GPF_T1 ("looking to return a value from a qf with no select");
  return NULL;
}


int
sqlg_is_qf_first (sql_comp_t * sc, data_source_t * qn)
{
  /* if doing first ts of qf or stn, the qf or stn is not counted as on the ref path.  Also if first stn of a qf, neither stn or qf is counted */
  if (!sc->sc_vec_first_of_qf)
    return 0;
  if (qn == sc->sc_vec_first_of_qf)
    return 1;
  if (IS_QN (sc->sc_vec_first_of_qf, stage_node_input) && IS_QN (qn, query_frag_input)
      && ((query_frag_t *) qn)->qf_head_node == sc->sc_vec_first_of_qf)
    return 1;
  return 0;
}



int
qn_ssl_ref_steps (sql_comp_t * sc, data_source_t * qn, dk_set_t * steps, state_slot_t * ssl, state_slot_t ** ssl_to_ref)
{
  /* normally put  the src_sets  into steps but if ts with restricting casts, add  this also.  Ret 1 if this node has a solid copy of the ssl being sought and return the copy in ssl to ref */
  if (IS_QN (qn, fun_ref_node_input) || IS_QN (qn, hash_fill_node_input))
    return 0;

#if 0
  if (sc->sc_vec_qf && !sqlg_is_qf_first (sc, qn) && (IS_QN (qn, stage_node_input) || qn == sc->sc_vec_qf->qf_head_node))
    {
      state_slot_t *param = sqlg_qf_param (sc, qn, ssl);
      *ssl_to_ref = param;
      return 1;
    }
#endif
  if (IS_QN (qn, query_frag_input) && qn->src_sets)
    {
	{
	  t_set_push (steps, (void *) (ptrlong) qn->src_sets);
#if 0
	/* the loc ks dropping rows is accounted for by the qf set nos sent so the ref path does not have to include the step of the loc ks */
	  if (ks)
	    {
	      int n = BOX_ELEMENTS (ks->ks_vec_cast), inx;
	      for (inx = n - 1; inx >= 0; inx--)
		{
		  if (ks->ks_vec_cast[inx] && ks->ks_vec_cast[inx]->ssl_sets)
		    t_set_push (steps, (void *) (ptrlong) ks->ks_vec_cast[inx]->ssl_sets);
		}
	    }
#endif
	  return 0;
	}
    }

  if (qn->src_sets)
    t_set_push (steps, (void *) (ptrlong) qn->src_sets);
  if (IS_TS (qn))
    {
      QNCAST (table_source_t, ts, qn);
      key_source_t *ks = ts->ts_order_ks;
      if (ks)
	{
	  int n = BOX_ELEMENTS (ks->ks_vec_cast), inx;
	  /* some of the cast search params can be refd from later nodes, specially in the place of fetching a col that is specified equal to the param.  If so, ref the cast via the sets of the ts but not via the sets that define dropped inputs due to null or bad cast */
	  for (inx = 0; inx < n; inx++)
	    {
	      state_slot_t *cast = ks->ks_vec_cast[inx];
	      if (cast && ssl == cast)
		{
		  *ssl_to_ref = ssl;
		  return 1;
		}
	    }
	  if (ks->ks_is_qf_first)
	    return 0;		/* if qf first in a subq after a dfg stage node, refs via the ts sets but not via casts that may drop values because the card dropping cast part is done by the stage node.  Happens in single table exists/scalar subq in a dfg  */
	  for (inx = n - 1; inx >= 0; inx--)
	    {
	      if (ks->ks_vec_cast[inx] && ks->ks_vec_cast[inx]->ssl_sets)
		t_set_push (steps, (void *) (ptrlong) ks->ks_vec_cast[inx]->ssl_sets);
	    }
	}
    }
  if (IS_QN (qn, hash_source_input))
    {
      QNCAST (hash_source_t, hs, qn);
      key_source_t *ks = hs->hs_ks;
      if (ks)
	{
	  int n = BOX_ELEMENTS (ks->ks_vec_cast), inx;
	  /* some of the cast search params can be refd from later nodes, specially in the place of fetching a col that is specified equal to the param.  If so, ref the cast via the sets of the ts but not via the sets that define dropped inputs due to null or bad cast */
	  for (inx = 0; inx < n; inx++)
	    {
	      state_slot_t *cast = ks->ks_vec_cast[inx];
	      if (cast && ssl == cast)
		{
		  *ssl_to_ref = ssl;
		  return 1;
		}
	    }
	  for (inx = n - 1; inx >= 0; inx--)
	    {
	      if (ks->ks_vec_cast[inx] && ks->ks_vec_cast[inx]->ssl_sets)
		t_set_push (steps, (void *) (ptrlong) ks->ks_vec_cast[inx]->ssl_sets);
	    }
	}
    }
  return 0;
}


void
qn_add_prof (sql_comp_t * sc, data_source_t * qn)
{
  comp_context_t *cc;
  if (!prof_on)
    return;
  if (IS_QN (qn, subq_node_input) || (IS_QN (qn, trans_node_input) && ((trans_node_t*)qn)->tn_inlined_step) || IS_QN (qn, union_node_input))
    return;
  cc = sc->sc_cc->cc_super_cc;
  qn->src_stat = cc->cc_instance_fill;
  cc->cc_super_cc->cc_instance_fill += sizeof (src_stat_t) / sizeof (caddr_t);
}


void
sqlg_vec_after_test (sql_comp_t * sc, data_source_t * qn)
{
  code_vec_t after_test = qn->src_after_test;
  int ign = 0;
  if (after_test)
    {
      SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
      en->src_gen.src_continuations = qn->src_continuations;
      qn->src_continuations = dk_set_cons ((void *) en, NULL);
      en->src_gen.src_after_test = qn->src_after_test;
      qn->src_after_test = NULL;
      en->src_gen.src_after_code = qn->src_after_code;
      qn->src_after_code = NULL;
      if (sc->sc_vec_qf)
	{
	  dk_set_ins_before (&sc->sc_vec_qf->qf_nodes, (void *) qn, (void *) en);
	  dk_set_delete (&sc->sc_cc->cc_query->qr_nodes, (void *) en);
	}
      qn_add_prof (sc, (data_source_t *) en);
    }
  else if (qn->src_after_code)
    {
      int const_card = qn_is_const_card (qn);
      if (!const_card)
      t_set_push (&sc->sc_vec_pred, (void *) qn);
      cv_vec_slots (sc, qn->src_after_code, NULL, NULL, &ign);
      sqlg_new_vec_ssls (sc, qn);
      if (!const_card)
      sc->sc_vec_pred = sc->sc_vec_pred->next;
    }
}


void
sqlg_vec_first_pre_code (sql_comp_t * sc, query_t * qr)
{
  data_source_t *qn = qr->qr_head_node;
  code_vec_t pre_code = qn->src_pre_code;
  if (pre_code && !IS_QN (qn, end_node_input))
    {
      SQL_NODE_INIT (end_node_t, en, end_node_input, NULL);
      en->src_gen.src_continuations = dk_set_cons ((void *) qr->qr_head_node, NULL);
      qr->qr_head_node = (data_source_t *) en;
      en->src_gen.src_after_code = pre_code;
      qn->src_pre_code = NULL;
      qn_add_prof (sc, (data_source_t *) en);
    }
}

col_ref_rec_t *
sqlc_col_ref_rec_by_ssl (sql_comp_t * sc, state_slot_t * ssl)
{
  /* in cases it happens that ssl name is changed after makingf a crr, e.g. when assigning the result of iri to id.  Therefore do not use the name when checking whether the ssl exists in an outer scope */
  sql_comp_t *vec_sc = sc;
  for (sc = sc; sc; sc = sc->sc_super)
    {
      DO_SET (col_ref_rec_t *, crr, &sc->sc_col_ref_recs)
      {
	state_slot_t *sh;
	if (!crr->crr_ssl)
	  continue;
	if (crr->crr_ssl->ssl_index == ssl->ssl_index)
	  return crr;
	sh = (state_slot_t *) gethash ((void *) (ptrlong) crr->crr_ssl->ssl_index, vec_sc->sc_vec_ssl_shadow);
	if (sh && sh->ssl_index == ssl->ssl_index)
	  return crr;
      }
      END_DO_SET ();
    }
  return NULL;
}


state_slot_ref_t *
sqlg_vec_ssl_ref (sql_comp_t * sc, state_slot_t * ssl, int test_only)
{
  /* if the ssl is not set right before, make a ssl ref that finds the right set number  */
  state_slot_t *org_ssl = ssl;
  state_slot_t *shadow;
  data_source_t *defd_in;
  dk_hash_t *def = sc->sc_vec_ssl_def;
  dk_set_t preds = sc->sc_vec_pred;
  dk_set_t steps = NULL;
  int shadow_refd = 0, def_found = 0;
  if (ssl && SSL_REF == ssl->ssl_type)
    ssl = ((state_slot_ref_t *) ssl)->sslr_ssl;
  if (sc->sc_vec_prov_cast)
    {
      sc_prov_cast_t *pca = (sc_prov_cast_t *) gethash ((void *) (ptrlong) ssl->ssl_index, sc->sc_vec_prov_cast);
      if (pca)
	sqlg_revert_pca (sc, ssl, pca);
    }
  if (!ssl || !preds || ssl->ssl_qr_global
      || SSL_CONSTANT == ssl->ssl_type
      || SSL_PARAMETER == ssl->ssl_type
      || SSL_REF_PARAMETER == ssl->ssl_type)
    {
      if (ssl && SSL_REF_PARAMETER == ssl->ssl_type)
	{
	  /* a ref parameter in a caller of a qf or dfg will have a non-ref shadow inside the remote fragment */
	  shadow = SSL_SHADOW (ssl);
	  if (shadow)
	    ssl = shadow;
	}
      if (ssl && SSL_CONSTANT != ssl->ssl_type)
	sqlg_all_branch_copy (sc, ssl);
      return test_only ? NULL : (state_slot_ref_t *) ssl;
    }
  if (ssl->ssl_alias_of)
    {
      ssl = ssl->ssl_alias_of;
      if (ssl && ssl->ssl_qr_global && ssl->ssl_type == SSL_VARIABLE)
	{
	  org_ssl->ssl_type = ssl->ssl_type;
	  ssl = org_ssl;
	  return test_only ? NULL : (state_slot_ref_t *) ssl;
	}
      if (SSL_VEC == ssl->ssl_type)
	{
	  org_ssl->ssl_type = SSL_VEC;
	  org_ssl->ssl_box_index = ssl->ssl_box_index;
	}
    }
  shadow = (state_slot_t *) gethash ((void *) (ptrlong) ssl->ssl_index, sc->sc_vec_ssl_shadow);
  if (shadow && !shadow_refd)
    {
      ssl = shadow;
      shadow_refd = 1;
      /*goto again;*/
    }
  defd_in = (data_source_t *) gethash ((void *) ssl, def);
  if (!defd_in)
    {
      /* can be other ssl w same index that is defd */
      DO_HT (state_slot_t *, ssl2, data_source_t *, def_qn, def)
      {
	if (ssl2->ssl_index == ssl->ssl_index)
	  return sqlg_vec_ssl_ref (sc, ssl2, test_only);
      }
      END_DO_HT;
    }
  if (SSL_IS_VEC_OR_REF (ssl))
    sethash ((void *) (ptrlong) ssl->ssl_index, sc->sc_vec_last_ref, sc->sc_pre_code_of ? sc->sc_pre_code_of : sc->sc_vec_current);	/* for vec reuse, applies to vec ssls only */
  if (defd_in == sc->sc_vec_current)
    return test_only ? NULL : (state_slot_ref_t *) (shadow ? ssl : org_ssl);
  if (!defd_in && !ssl->ssl_vec_param)
    {
      col_ref_rec_t *crr;
      AUTO_POOL (10);
      sqlg_all_branch_copy (sc, ssl);
      crr = sqlc_col_ref_rec_by_ssl (sc, ssl);
      if (!crr)
	{
	  if (SSL_PLACEHOLDER == ssl->ssl_type || SSL_ITC == ssl->ssl_type)	/*garbage ssls left in proc cursors, not even inited at run time so ignore */
	    return test_only ? NULL : (state_slot_ref_t *) ssl;
	  if (sqlg_vec_debug)
	    {
	      char txt[30];
	      snprintf (txt, sizeof (txt), "unset ssl %d", ssl->ssl_index);
	      return (state_slot_ref_t *) ssl_new_constant (sc->sc_cc, box_dv_short_string (txt));
	    }
	  sqlc_new_error (sc->sc_cc, "VECSL", "VECSL", "Internal error, ssl refd before set, please report query to support");
	  GPF_T1 ("ssl refd in vectored comp not set before ref");
	}
      if (SSL_VEC != crr->crr_ssl->ssl_type)
	return test_only ? NULL : (state_slot_ref_t *) crr->crr_ssl;
    }
  def_found = 0;
  DO_SET (data_source_t *, qn, &preds)
  {
      if (qn == defd_in || (defd_in && qn_next (qn) == defd_in))
	{ /* test qn and its next because a subq in a cv can depend on a ssl assigned in the cv, yet the node with the cv is not a pred of the subq because the out sets of the node with the cv do not affect refs from the subq.  Also def_in can be null if ssl is vectored param, so if qn next is also null must not conclude def found.  */
	def_found = 1;
	break;
      }
    if (qn_ssl_ref_steps (sc, qn, &steps, ssl, &shadow))
      {
	ssl = shadow;
	def_found = 1;
	break;
      }
    sqlg_branch_copy (sc, qn, ssl);
  }
  END_DO_SET ();
  if (0 && defd_in && !def_found && !sc->sc_in_ins_replacing && DV_ITC != ssl->ssl_sqt.sqt_dtp)
    {
      col_ref_rec_t *crr;
      AUTO_POOL (10);
      sqlg_all_branch_copy (sc, ssl);
      crr = sqlc_col_ref_rec_by_ssl (sc, ssl);
      if (!crr)
	{
	  if (sqlg_vec_debug)
	    {
	      char txt[30];
	      snprintf (txt, sizeof (txt), "unset ssl %d", ssl->ssl_index);
	      return (state_slot_ref_t *) ssl_new_constant (sc->sc_cc, box_dv_short_string (txt));
	    }
	  sqlc_new_error (sc->sc_cc, "VECSL",  "VECSL",  "Internal error, ssl defined in a node that is not directly before ref. please report query to support");
	}
      if (SSL_VEC != crr->crr_ssl->ssl_type)
	return test_only ? NULL : (state_slot_ref_t *) crr->crr_ssl;
    }
  if (test_only)
    return (state_slot_ref_t *) steps;
  if (steps)
    {
      int dist = dk_set_length (steps), fill = 0;
      ssl_index_t *arr = (ssl_index_t *) dk_alloc (dist * sizeof (ssl_index_t));
      NEW_VARZ (state_slot_ref_t, sslr);
      steps = dk_set_nreverse (steps);
      DO_SET (ptrlong, sinx, &steps)
      {
	arr[fill++] = sinx;
      }
      END_DO_SET ();
      sslr->sslr_distance = dist;
      sslr->sslr_set_nos = arr;
      sslr->sslr_index = ssl->ssl_index;
      sslr->sslr_box_index = ssl->ssl_box_index;
      sslr->ssl_sqt = ssl->ssl_sqt;
      sslr->ssl_dc_dtp = ssl->ssl_dc_dtp;
      sslr->sslr_ssl = org_ssl;
      sslr->ssl_type = SSL_REF;
      dk_set_push (&sc->sc_cc->cc_query->qr_ssl_refs, (void *) sslr);
      return sslr;
    }
  return (state_slot_ref_t *) (shadow ? ssl : org_ssl);
}

#undef REF_SSL

#define REF_SSL(res, ssl) \
  ssl = (state_slot_t*)sqlg_vec_ssl_ref (sc, ssl, 0);


void
sqlg_vec_ref_ssls (sql_comp_t * sc, state_slot_t ** ssls)
{
  int inx;
  DO_BOX (state_slot_t *, ssl, inx, ssls)
  {
    ssls[inx] = (state_slot_t *) sqlg_vec_ssl_ref (sc, ssl, 0);
  }
  END_DO_BOX;
}


void
sqlg_vec_ref_ssl_list (sql_comp_t * sc, dk_set_t ssls)
{
  while (ssls)
    {
      QNCAST (state_slot_t, ssl, ssls->data);
      ssls->data = (void *) sqlg_vec_ssl_ref (sc, ssl, 0);
      ssls = ssls->next;
    }
}


void
sqlg_qn_vec (sql_comp_t * sc, data_source_t * qn, dk_set_t qn_stack, dk_hash_t * refs)
{
  dk_set_t save = sc->sc_vec_pred;
  dk_set_t ssl_save = sc->sc_vec_new_ssls;
  data_source_t *cur = sc->sc_vec_current;
  char save_outer = sc->sc_vec_in_outer;
  dk_hash_t *save_shadow = hash_table_copy (sc->sc_vec_ssl_shadow);
  sc->sc_vec_in_outer = 0;
  sc->sc_vec_new_ssls = NULL;
  sqlg_vec_qns (sc, qn, sc->sc_vec_pred);
  hash_table_free (sc->sc_vec_ssl_shadow);
  sc->sc_vec_ssl_shadow = save_shadow;
  sc->sc_vec_in_outer = save_outer;
  sc->sc_vec_new_ssls = ssl_save;
  sc->sc_vec_current = cur;
  sc->sc_vec_pred = save;
}

void
sqlg_subq_vec (sql_comp_t * sc, query_t * qr, dk_set_t qn_stack, dk_hash_t * refs)
{
  if (!qr->qr_vec_opt_done)
    {
      query_t *save = sc->sc_vec_qr;
      query_frag_t *qf_save = sc->sc_vec_qf;
      data_source_t *pc_save = sc->sc_pre_code_of;
      sc->sc_pre_code_of = NULL;
      qr->qr_vec_opt_done = 1;
      sc->sc_vec_qr = qr;
      sc->sc_vec_qf = NULL;
      sqlg_qn_vec (sc, qr->qr_head_node, qn_stack, refs);
      sc->sc_vec_qr = save;
      sc->sc_vec_qf = qf_save;
      sc->sc_pre_code_of = pc_save;
    }
}


#undef REF_SSLS
#define ref_ssls(ht, arr) \
  sqlg_vec_ref_ssls (sc, arr)

#undef ASG_SSL
#define ASG_SSL(r1, r2, ssl) \
  do {if (ssl) { state_slot_t * ssl2 = ssl->ssl_alias_of ? ssl->ssl_alias_of : ssl; sethash ((void*)ssl2, sc->sc_vec_ssl_def, (void*)sc->sc_vec_current); ssl_vec (sc, ssl2, 0);}} while (0)

#define ASG_SS_SSL(r1, r2, ssl) \
  {if (ssl) { state_slot_t * ssl2 = ssl->ssl_alias_of ? ssl->ssl_alias_of : ssl; sethash ((void*)ssl2, sc->sc_vec_ssl_def, (void*)sc->sc_vec_current); ssl->ssl_type = SSL_VARIABLE; ssl->ssl_qr_global = 1;}}


#define ASG_SSL_AGG(r1, r2, ssl) \
  {sethash ((void*)ssl, sc->sc_vec_ssl_def, (void*)sc->sc_vec_current); ssl_vec (sc, ssl, 1);}

#define ASG_SSL_CAST(cast, org) \
  { sethash ((void*)cast, sc->sc_vec_ssl_def, (void*)sc->sc_vec_pred->data); sethash ((void*)cast, sc->sc_vec_cast_ssls, (void*)org); }


typed_ins_t typed_artm[20];
typed_ins_t typed_cmp[20];

#define SSL_IS_VEC_REF(ssl) (SSL_VEC == ssl->ssl_type || SSL_REF == ssl->ssl_type)

void
ti_define (char op, dtp_t dtp, void *f, void *f1)
{
  typed_ins_t *arr = IN_COMPARE == op ? typed_cmp : typed_artm;
  int inx;
  for (inx = 1; arr[inx].ti_ins_type; inx++);
  arr[inx].ti_ins_type = op;
  arr[inx].ti_sqt1.sqt_dtp = dtp;
  if (IN_COMPARE == op)
    {
      dc_cmp_funcs[inx] = f;
      dc_cmp_1_funcs[inx] = f1;
    }
  else
    {
      dc_artm_funcs[inx] = f;
      dc_artm_1_funcs[inx] = f1;
    }
}


short
ti_func_no (char op, dtp_t dtp)
{
  int inx;
  typed_ins_t *arr = IN_COMPARE == op ? typed_cmp : typed_artm;
  for (inx = 1; arr[inx].ti_ins_type; inx++)
    {
      if (arr[inx].ti_ins_type == op && typed_artm[inx].ti_sqt1.sqt_dtp == dtp)
	return inx;
    }
  return 0;
}

void
ti_func_init ()
{
  ti_define (IN_COMPARE, DV_LONG_INT, (void *) dc_cmp_int, (void *) dc_cmp_int_1);
  ti_define (IN_ARTM_PLUS, DV_LONG_INT, (void *) dc_add_int, (void *) dc_add_int_1);
  ti_define (IN_ARTM_IDENTITY, DV_LONG_INT, (void *) dc_asg_64, (void *) dc_asg_64_1);
}


void
cv_artm_typed (instruction_t * ins)
{
  if (IN_ARTM_IDENTITY == ins->ins_type)
    {
      if (!ins->_.artm.left)
	return;
      if (SSL_IS_VEC_REF (ins->_.artm.left) && SSL_IS_VEC_REF (ins->_.artm.result))
	{
	  dtp_t dtp = ins->_.artm.left->ssl_dtp;
	  if (ins->_.artm.result->ssl_dtp != ins->_.artm.left->ssl_dtp)
	    return;
	  switch (dtp)
	    {
	    case DV_INT64:
	    case DV_SHORT_INT:
	    case DV_IRI_ID:
	    case DV_IRI_ID_8:
	    case DV_DOUBLE_FLOAT:
	      /* all the above copy by copy of 64 bit value in dc_values plus opt null flag.  dv any is not like that because these dcs can change to a more precise type at run time.  */
	      dtp = DV_LONG_INT;
	      break;
	    }
	  ins->_.artm.func = ti_func_no (IN_ARTM_IDENTITY, dtp);
	}
    }
  else if (SSL_IS_VEC_REF (ins->_.artm.left) && SSL_IS_VEC_REF (ins->_.artm.right)
      && ins->_.artm.left->ssl_dtp == ins->_.artm.right->ssl_dtp && ins->_.artm.result->ssl_dtp == ins->_.artm.right->ssl_dtp)
    {
      switch (ins->_.artm.left->ssl_dtp)
	{
	case DV_LONG_INT:
	case DV_INT64:
	case DV_SHORT_INT:
	  ins->_.artm.func = ti_func_no (ins->ins_type, DV_LONG_INT);
	  break;
	}
    }
}


void
cv_cmp_typed (instruction_t * ins)
{
  if (SSL_IS_VEC_REF (ins->_.cmp.left) && SSL_IS_VEC_REF (ins->_.cmp.right)
      && ins->_.cmp.left->ssl_dtp == ins->_.cmp.right->ssl_dtp)
    {
      switch (ins->_.artm.left->ssl_dtp)
	{
	case DV_LONG_INT:
	case DV_INT64:
	case DV_SHORT_INT:
	  ins->_.cmp.func = ti_func_no (ins->ins_type, DV_LONG_INT);
	  break;
	}
    }
}

int enable_const_exp = 1;

#define SSL_ALWAYS_VEC(ssl) \
  ((ssl->ssl_name && nc_strstr ((dtp_t*)ssl->ssl_name, (dtp_t*)"aggr")) || SSL_VEC == ssl->ssl_type   || ssl->ssl_always_vec)

int
ins_is_single_state (instruction_t * ins)
{
  int inx;
  if (!enable_const_exp)
    return 0;
  switch (ins->ins_type)
    {
    case INS_CALL:
    case INS_CALL_BIF:
      if (ins->_.call.ret && SSL_VEC == ins->_.call.ret->ssl_type)
	  return 0;
      if (INS_CALL_BIF == ins->ins_type && 0 == stricmp (ins->_.bif.proc, "__all_eq"))
	{
	  if (ins->_.bif.ret)
	    ins->_.bif.ret->ssl_qr_global = 0;
	  return 0;		/* __all_eq of a const is an idiom used by trans node to make a const inited vector ssl.  This is a vec and is not qr global  */
	}
      DO_BOX (state_slot_t *, ssl, inx, ins->_.call.params)
      {
	if (SSL_IS_VEC_REF (ssl) || SSL_ALWAYS_VEC (ssl))
	  {
	    if (ins->_.bif.ret && IS_REAL_SSL (ins->_.bif.ret))
	      ins->_.bif.ret->ssl_qr_global = 0;
	    return 0;
	  }
      }
      END_DO_BOX;
      if (INS_CALL_BIF == ins->ins_type && 0 == stricmp (ins->_.bif.proc, "sequence_next"))
	return 0;
      return 1;
    case IN_ARTM_FPTR:
    case IN_ARTM_PLUS:
    case IN_ARTM_MINUS:
    case IN_ARTM_TIMES:
    case IN_ARTM_DIV:
      if (SSL_ALWAYS_VEC (ins->_.artm.result))
	return 0;		/*user agg variable are always vectors */
      return !SSL_IS_VEC_REF (ins->_.artm.left) && (!ins->_.artm.right || !SSL_IS_VEC_REF (ins->_.artm.right));
    default:
      return 0;
    }
}


#define QN_SAVE_PRERESET \
      dk_set_t save = sc->sc_vec_new_ssls; \
      dk_set_t save_p = sc->sc_ssl_prereset_only; \
      sc->sc_vec_new_ssls = NULL; \
      sc->sc_ssl_prereset_only = NULL;

#define QN_RESTORE_PRERESET \
      sc->sc_vec_new_ssls = save; \
      sc->sc_ssl_prereset_only = save_p;


void
ins_qnode_asg (sql_comp_t * sc, data_source_t * qn)
{
  DO_HT (state_slot_t *, defd, data_source_t *, defd_in, sc->sc_vec_ssl_def)
  {
    if (defd_in == qn)
      sethash (defd, sc->sc_vec_ssl_def, sc->sc_vec_current);
  }
  END_DO_HT;
}


int
bif_all_vec (instruction_t * ins)
{
  int inx, any = 0;
  DO_BOX (state_slot_t *, arg, inx, ins->_.bif.params)
  {
    if (SSL_CONSTANT == arg->ssl_type)
      continue;
    if (!SSL_IS_VEC_OR_REF (arg))
      return 0;
    any = 1;
  }
  END_DO_BOX;
  return any;
}

void
cv_deduplicate_param_ssls (comp_context_t *cc, state_slot_t **params)
{
  int inx, prev_inx;
  DO_BOX (state_slot_t *, arg, inx, params)
  {
    switch (arg->ssl_type)
      {
      case SSL_CONSTANT:
	continue;
      case SSL_VARIABLE:
	continue;
      }
    for (prev_inx = inx; prev_inx--; /* no step */ )
      {
	if (arg->ssl_index == params[prev_inx]->ssl_index)
	  goto dupe_found;	/* see below */
      }
    continue;
  dupe_found:
    switch (arg->ssl_type)
      {
      case SSL_REF:
	{
	  state_slot_ref_t *copy = (state_slot_ref_t *) dk_alloc (sizeof (state_slot_ref_t));
	  ssl_index_t *nos;
	  memcpy (copy, arg, sizeof (state_slot_ref_t));
	  nos = copy->sslr_set_nos;
	  copy->sslr_set_nos = (ssl_index_t *) dk_alloc ((copy->sslr_distance) * sizeof (ssl_index_t));
	  memcpy (copy->sslr_set_nos, nos, (copy->sslr_distance) * sizeof (ssl_index_t));
	  params[inx] = (state_slot_t *) copy;
	  SSL_ADD_TO_QR (copy);
	  break;
	}
      default:
	{
	  state_slot_t *copy = (state_slot_t *) dk_alloc (sizeof (state_slot_t));
	  memcpy (copy, arg, sizeof (state_slot_t));
	  copy->ssl_name = box_copy (arg->ssl_name);
	  if (arg->ssl_box_index)
	    copy->ssl_box_index = cc_new_instance_slot (cc);
	  params[inx] = copy;
	  SSL_ADD_TO_QR (copy);
	  break;
	}
      }
  }
  END_DO_BOX;
}


void
cv_vec_slots (sql_comp_t * sc, code_vec_t cv, dk_hash_t * res, dk_hash_t * all_res, int *non_cl_local)
{
  if (!cv)
    return;
  DO_INSTR (ins, 0, cv)
  {
    switch (ins->ins_type)
      {
      case INS_CALL:
      case INS_CALL_IND:
	if (ins->_.call.proc_ssl)
	  REF_SSL (res, ins->_.call.proc_ssl);;
	ref_ssls (res, ins->_.call.params);
	if (CV_CALL_PROC_TABLE != ins->_.call.ret && CV_CALL_VOID != ins->_.call.ret)
	  {
	    if (!ins_is_single_state (ins))
	      ASG_SSL (res, all_res, ins->_.call.ret);
	    else
	      ASG_SS_SSL (res, all_res, ins->_.call.ret);
	  }
	if (non_cl_local)
	  *non_cl_local = 1;
	break;

      case INS_CALL_BIF:
	ref_ssls (res, ins->_.bif.params);
	cv_deduplicate_param_ssls (sc->sc_cc, ins->_.bif.params);
	if (!ins_is_single_state (ins))
	  {
	    bif_t vec = VEC_SINGLE_STATE == *non_cl_local ? NULL : (bif_t) bif_vectored (ins->_.bif.bif);
	    /* the result of bif is assigned if there is a ssl for it and it is not the same as 1st arg because some fuck makes x = blob to string (x) inside a query on proc view */
	    if (IS_REAL_SSL (ins->_.bif.ret) && !(BOX_ELEMENTS (ins->_.bif.params) && ins->_.bif.ret == ins->_.bif.params[0]))
	    ASG_SSL (res, all_res, ins->_.bif.ret);
	    if (vec && bif_all_vec (ins))
	      {
		ins->_.bif.bif = vec;
		ins->_.bif.vectored = 1;
	      }
	  }
	else if (IS_REAL_SSL (ins->_.bif.ret))
	  ASG_SS_SSL (res, all_res, ins->_.bif.ret);
	break;
      case IN_ARTM_FPTR:
      case IN_ARTM_IDENTITY:
      case IN_ARTM_PLUS:
      case IN_ARTM_MINUS:
      case IN_ARTM_TIMES:
      case IN_ARTM_DIV:
	REF_SSL (res, ins->_.artm.left);
	REF_SSL (res, ins->_.artm.right);
	if (!ins_is_single_state (ins))
	  ASG_SSL (res, all_res, ins->_.artm.result);
	else
	  ASG_SS_SSL (res, all_res, ins->_.artm.result);
	cv_artm_typed (ins);
	break;
      case IN_AGG:
	REF_SSL (res, ins->_.agg.arg);
	REF_SSL (res, ins->_.agg.set_no);
	ins->_.agg.result->ssl_qr_global = 0;
	ASG_SSL_AGG (res, all_res, ins->_.agg.result);
	if (ins->_.agg.distinct)
	  {
	    hash_area_t *ha = ins->_.agg.distinct;
	    ref_ssls (res, ha->ha_slots);
	    ha->ha_set_no = ins->_.agg.set_no;
	    ASG_SSL_AGG (NULL, NULL, ha->ha_tree);
	  }
	break;
      case IN_PRED:
	ins->_.cmp.next_mask = cc_new_instance_slot (sc->sc_cc);
	if (bop_comp_func == ins->_.pred.func)
	  {
	    bop_comparison_t *bop = (bop_comparison_t *) ins->_.pred.cmp;
	    REF_SSL (res, bop->cmp_left);
	    REF_SSL (res, bop->cmp_right);
	    continue;
	  }
	else
	  *non_cl_local = 1;
	if (distinct_comp_func == ins->_.pred.func)
	  {
	    sqlg_vec_ref_ssls (sc, ((hash_area_t *) ins->_.pred.cmp)->ha_slots);
	  }
	if ((pred_func_t) exists_pred_func == ins->_.pred.func || (pred_func_t) subq_comp_func == ins->_.pred.func)
	  {
	    subq_pred_t *subp = (subq_pred_t *) ins->_.pred.cmp;
	    select_node_t *sel = subp->subp_query->qr_select_node;
	    table_source_t *ts;
	    sqlg_subq_vec (sc, subp->subp_query, NULL, res);	/* XXX: is it so ??? */
	    sel->sel_vec_set_mask = cc_new_instance_slot (sc->sc_cc);
	    sel->sel_vec_role = SEL_VEC_EXISTS;
	    ts = (table_source_t *) sel->src_gen.src_prev;
	    if (IS_TS (ts) && !ts->ts_order_ks->ks_set_no_col_ssl)
	      ts->ts_max_rows = 1;	/* last ts of existence makes max 1 row, except when reading a gb or proc view temp where the set no is a col in the temp */
	  }
	break;
      case INS_SUBQ:
	if (non_cl_local)
	  *non_cl_local = 1;
	sqlg_subq_vec (sc, ins->_.subq.query, NULL, res);
	if (0 && ins->_.subq.query->qr_select_node)
	  ASG_SSL (res, all_res, ins->_.subq.query->qr_select_node->sel_out_slots[0]);
	ASG_SSL (res, all_res, ins->_.subq.scalar_ret);
	break;
      case IN_COMPARE:
	REF_SSL (res, ins->_.cmp.left);
	REF_SSL (res, ins->_.cmp.right);
	ins->_.cmp.next_mask = cc_new_instance_slot (sc->sc_cc);
	cv_cmp_typed (ins);
	break;
      case INS_QNODE:
	{
	  data_source_t *save_cur = sc->sc_vec_current;
	  dk_set_t save_pred = sc->sc_vec_pred;
	  QN_SAVE_PRERESET;
	  if (!sc->sc_vec_current)
	    sc->sc_vec_current = ins->_.qnode.node;
	qn_vec_slots (sc, ins->_.qnode.node, res, all_res, non_cl_local);
	  sc->sc_vec_current = save_cur;
	  sc->sc_vec_pred = save_pred;
	  QN_RESTORE_PRERESET;
	  ins_qnode_asg (sc, ins->_.qnode.node);
	break;
      }
  }
  }
  END_DO_INSTR;
}


int enable_hash_merge = 1;

int
sqlg_is_inline_hash_key (hash_area_t * ha, state_slot_t * ssl, table_source_t * ts)
{
  /* true for single intlike key to hash.  Can merge the hash lookup and partition filter as column condition in a ts */
  dtp_t s_dtp = dtp_canonical[ssl->ssl_sqt.sqt_dtp];
  int is_row_merge = ts && !ts->ts_order_ks->ks_key->key_is_col;
  if (ssl->ssl_column && ha->ha_n_keys == 1
      && ((!is_row_merge && (DV_ANY == ha->ha_key_cols[0].cl_sqt.sqt_dtp || DV_ANY == s_dtp))
	  || (dtp_canonical[ha->ha_key_cols[0].cl_sqt.sqt_dtp] == s_dtp && (DV_LONG_INT == s_dtp || DV_IRI_ID == s_dtp))))
    {
      if (ts)
	{
	  /* a hash ref ref col must be a col of the ts and not a ssl assigned for example from another hash join merged into the ts */
	  if (!dk_set_member (ts->ts_order_ks->ks_out_slots, ssl))
	    return 0;
	}
      return 1;
    }
  return 0;
}

#define HRNG_PROBE 0
#define HRNG_MERGE 1
#define HRNG_BUILD 2
#define HRNG_PROBE_PART_ONLY 3


search_spec_t *
sqlg_hash_spec (sql_comp_t * sc, state_slot_t ** ref_slots, int n_keys, table_source_t * ts, state_slot_t * col_ssl,
    hash_source_t * hs, fun_ref_node_t * filler, int is_merge)
{
  /* make a search_spec_t  that selects hash nos that fall within a hash partition range.  This is added to the last ts in join order that adds a col to the probe cols of the hash source.  This can also be a set ctr if the hash source is outer.  */
  data_source_t *save_cur = sc->sc_vec_current;
  dtp_t dtp;
  int inx;
  dk_set_t save_pred = sc->sc_vec_pred;
  hash_range_spec_t *hrng = (hash_range_spec_t *) dk_alloc (sizeof (hash_range_spec_t));
  NEW_VARZ (search_spec_t, sp);
  memset (hrng, 0, sizeof (hash_range_spec_t));
  sp->sp_min_op = CMP_HASH_RANGE;
  sp->sp_col_filter = ce_op_hash;
  sp->sp_min_ssl = (state_slot_t *) hrng;
  hrng->hrng_part_ssl = filler->fnr_hash_part_ssl;
  hrng->hrng_min = filler->fnr_hash_part_min;
  hrng->hrng_max = filler->fnr_hash_part_max;
  if (HRNG_BUILD != is_merge)
    {
      hrng->hrng_hs = (HRNG_MERGE == is_merge) ? hs : NULL;
      hrng->hrng_ht = hs->hs_ha->ha_tree;
      hrng->hrng_ht_id = hs->hs_cl_id;
      if (HRNG_PROBE_PART_ONLY == is_merge)
	hrng->hrng_flags = HR_RANGE_ONLY;
    }
  else
    hrng->hrng_flags = HR_RANGE_ONLY;
  if (HRNG_MERGE == is_merge)
    {
      hrng->hrng_ssls = (state_slot_t **) list (1, ssl_new_vec (sc->sc_cc, "tmp", hs->hs_ref_slots[0]->ssl_sqt.sqt_dtp));
    }
  if (col_ssl)
    {
      sp->sp_col = col_ssl->ssl_column;
      if (IS_TS (ts))
	{
	  if (ts->ts_order_ks->ks_key->key_is_col)
	    sp->sp_cl = *cl_list_find (ts->ts_order_ks->ks_key->key_row_var, col_ssl->ssl_column->col_id);
	  else
	    sp->sp_cl = *key_find_cl (ts->ts_order_ks->ks_key, col_ssl->ssl_column->col_id);
	}
    }
  if (!col_ssl || n_keys > 1)
    {
      while (sc->sc_vec_pred && ts != (table_source_t *) sc->sc_vec_pred->data)
	sc->sc_vec_pred = sc->sc_vec_pred->next;
      if (sc->sc_vec_pred)
	sc->sc_vec_pred = sc->sc_vec_pred->next;
      sc->sc_vec_current = (data_source_t *) ts;
      hrng->hrng_ssls = (state_slot_t **) dk_alloc_box_zero (sizeof (caddr_t) * n_keys, DV_BIN);
      for (inx = 0; inx < n_keys; inx++)
	{
	  if (ref_slots[inx] != col_ssl)
	    {
	      hrng->hrng_ssls[inx] = ref_slots[inx];
	      REF_SSL (NULL, hrng->hrng_ssls[inx]);
	    }
	}
    }
  dtp = col_ssl ?  col_ssl->ssl_sqt.sqt_dtp : sp->sp_cl.cl_sqt.sqt_col_dtp;
  if (hs)
    dtp = dtp_canonical[hs->hs_ha->ha_key_cols[0].cl_sqt.sqt_dtp];
  hrng->hrng_dc = ssl_new_vec (sc->sc_cc, "hrng_tmp", dtp);
  sc->sc_vec_current = save_cur;
  sc->sc_vec_pred = save_pred;
  return sp;
}

int
ts_col_ordering (table_source_t * ts, state_slot_t * ssl)
{
  /* if ssl is set here and is asc, give FNR_STREAM_DUPS.  If col is unique, but not necessarily asc,, give FNR_STREAM_UNQ */
  key_source_t *ks = ts->ts_order_ks;
  dbe_table_t *tb = ks->ks_key->key_table;
  search_spec_t *sp;
  int nth = 0, only_unq = 0;
  if (!ssl->ssl_column || !dk_set_member (ks->ks_out_slots, (void *) ssl))
    return 0;
  if (1 == tb->tb_primary_key->key_n_significant && ssl->ssl_column == (dbe_column_t *) tb->tb_primary_key->key_parts->data)
    return FNR_STREAM_UNQ;	/* the col is a 1 col pk, always unq no matter which key or which conditions */
  sp = ks->ks_spec.ksp_spec_array;
  DO_SET (dbe_column_t *, col, &ks->ks_key->key_parts)
  {
    if (nth == ks->ks_key->key_n_significant)
      break;
    if (sp && CMP_EQ == sp->sp_min_op)
      {
	sp = sp->sp_next;
	nth++;
	continue;
      }
    if (ssl->ssl_column == col)
      only_unq = FNR_STREAM_DUPS;
    else
      return only_unq;
    if (sp)
      sp = sp->sp_next;
    nth++;
  }
  END_DO_SET ();
  return FNR_STREAM_UNQ;
}


int enable_stream_gb = 0;
int enable_oj_hash_part_merge = 1;


void
sqlg_stream_gb (sql_comp_t * sc, setp_node_t * setp)
{
  /* if a grouping col is unique in its table and the table is the outermost loop this is a stream with no dups.  This means that results can be returned whevever the sources between the outermost and the setp are at end.
   * if the grouping col is the ordering col of the outermost but not unique in the outermost, output can be produced whenever the sources between the outermost and the setp are at end but the last value of the outermost loop must be left out
   * because a continue of the outer loop might produce more of these values */
  int inx;
  table_source_t *outer = NULL;
  if (!enable_stream_gb || !enable_chash_gb)
    return;
  DO_SET (table_source_t *, pred, &sc->sc_vec_pred)
  {
    if (IS_QN (pred, fun_ref_node_input))
      break;
    if (IS_TS (pred))
      {
	if (!pred->ts_is_unique)
	  outer = pred;
      }
  }
  END_DO_SET ();
  if (!outer)
    return;
  DO_BOX (state_slot_t *, ssl, inx, setp->setp_keys_box)
  {
    int unq = ts_col_ordering (outer, ssl);
    if (unq > setp->setp_is_streaming)
      {
	setp->setp_is_streaming = unq;
	if (!setp->setp_streaming_ssl)
	  setp->setp_streaming_ssl = ssl;
      }
  }
  END_DO_BOX;
  if (setp->setp_is_streaming)
    {
      query_t *qr = setp->src_gen.src_query;
      data_source_t *next_qn;
      /* in comtinue order a streaming gb fref is to be continued before the stuff inside it.  The fref decides how to continue its own nodes */
      dk_set_delete (&qr->qr_nodes, (void *) setp->setp_fref);
      dk_set_ins_before (&qr->qr_nodes, (void *) setp, (void *) setp->setp_fref);
      setp->setp_ha->ha_row_count = 3 * dc_batch_sz;	/* card now has a cap, not the whole table in there */
      setp->setp_fref->fnr_current_branch = cc_new_instance_slot (sc->sc_cc);
      setp->setp_fref->fnr_current_branch = cc_new_instance_slot (sc->sc_cc);
      setp->setp_fref->fnr_stream_ts = outer;
      setp->setp_fref->fnr_stream_state = cc_new_instance_slot (sc->sc_cc);
      for (next_qn = qn_next ((data_source_t *) outer); next_qn; next_qn = qn_next (next_qn))
	{
	  /* for streaming gb, the outermost ts splits into threads and ranges but within these there is no further splitting because the control structure deals with a single aq and there is no merge of gb states */
	  if (IS_TS (next_qn))
	    {
	      QNCAST (table_source_t, next_ts, next_qn);
	      next_ts->ts_aq_qis = next_ts->ts_aq = NULL;
	    }
	}
      if (FNR_STREAM_DUPS == setp->setp_is_streaming && !setp->setp_fref->fnr_cha_surviving)
	{
	  setp->setp_fref->fnr_cha_surviving = ssl_new_inst_variable (sc->sc_cc, "chash_stream_survival", DV_ARRAY_OF_POINTER);
	  outer->ts_branch_col = setp->setp_streaming_ssl->ssl_column;
	  outer->ts_branch_by_value = 1;
	}
    }
}


void
sqlg_vec_setp_loc (sql_comp_t * sc, setp_node_t * setp)
{
  key_source_t *ks = setp->setp_loc_ts->ts_order_ks;
  search_spec_t *sp;
  return;
  for (sp = ks->ks_spec.ksp_spec_array; sp; sp = sp->sp_next)
    {
      REF_SSL (NULL, sp->sp_min_ssl);
    }
}


void
sqlg_vec_setp (sql_comp_t * sc, setp_node_t * setp, dk_hash_t * res)
{
  sqlg_vec_ref_ssl_list (sc, setp->setp_keys);
  if (setp->setp_loc_ts)
    sqlg_vec_setp_loc (sc, setp);
  if (setp->setp_ha && HA_GROUP == setp->setp_ha->ha_op && !setp->setp_set_no_in_key)
    sqlg_stream_gb (sc, setp);
  DO_SET (state_slot_t *, ssl, &setp->setp_const_gb_args)
  {
    ASG_SSL_AGG (res, NULL, ssl);
  }
  END_DO_SET ();
  REF_SSL (res, setp->setp_top);
  REF_SSL (res, setp->setp_top_skip);
  REF_SSL (res, setp->setp_ssa.ssa_set_no);
  if (setp->setp_ha)
    {
      hash_area_t *ha = setp->setp_ha;
      char prev_tree_type;
      setp->setp_ha->ha_set_no = setp->setp_ssa.ssa_set_no;
      if (HA_FILL == ha->ha_op)
	{
	  ha->ha_tree->ssl_qr_global = 1;
	  setp->setp_fill_cha = cc_new_instance_slot (sc->sc_cc);
	  REF_SSL (NULL, ha->ha_tree);
	  ASG_SSL_AGG (NULL, NULL, ha->ha_tree);
	  DO_SET (table_source_t *, fill_ts, &sc->sc_vec_pred)
	  {
	    int k;
	    state_slot_t *one_key = NULL;
	    for (k = 0; k < ha->ha_n_keys; k++)
	      {
		state_slot_t *ssl = ha->ha_slots[k];
		data_source_t *defd_in = (data_source_t *) gethash ((void *) ssl, sc->sc_vec_ssl_def);
		if (defd_in == (data_source_t *) fill_ts)
		  {
		    if (one_key || !sqlg_is_inline_hash_key (setp->setp_ha, ssl, NULL))
		      {
			setp->setp_hash_part_filter = (data_source_t *) setp;
			goto filter_done;
		      }
		    one_key = ssl;
		  }
	      }
	    if (one_key)
	      {
		if (IS_TS (fill_ts))
		  {
		    setp->setp_hash_part_filter = (data_source_t *) fill_ts;
		    dk_set_push (&fill_ts->ts_order_ks->ks_hash_spec, (void *)
				   sqlg_hash_spec (sc, ha->ha_slots, ha->ha_n_keys, fill_ts, one_key, NULL, setp->setp_fref, HRNG_BUILD));
		  }
		else
		  setp->setp_hash_part_filter = (data_source_t *) setp;
		goto filter_done;
	      }
	  }
	  END_DO_SET ();
	filter_done:;
	}
      sqlg_vec_ref_ssls (sc, setp->setp_ha->ha_slots);
      prev_tree_type = setp->setp_ha->ha_tree->ssl_type;
      ASG_SSL_AGG (NULL, NULL, setp->setp_ha->ha_tree);
      if (setp->setp_set_no_in_key)
	setp->setp_ha->ha_tree->ssl_type = prev_tree_type;
    }
  DO_SET (gb_op_t *, go, &setp->setp_gb_ops)
  {
    int non_cl_local = 0;
    if (go->go_ua_arglist)
      ref_ssls (res, go->go_ua_arglist);
    cv_vec_slots (sc, go->go_ua_init_setp_call, res, NULL, &non_cl_local);
    cv_vec_slots (sc, go->go_ua_acc_setp_call, res, NULL, &non_cl_local);
    REF_SSL (res, go->go_distinct);
    if (go->go_distinct_ha)
      {
	hash_area_t *ha = go->go_distinct_ha;
	ASG_SSL_AGG (NULL, NULL, ha->ha_tree);
	REF_SSL (res, ha->ha_set_no);
	ref_ssls (res, ha->ha_slots);
      }
  }
  END_DO_SET ();
  sqlg_vec_ref_ssl_list (sc, setp->setp_dependent);
  if (setp->setp_keys_box)
    {
      int inx = 0;
      DO_SET (state_slot_t *, ssl, &setp->setp_keys)
	setp->setp_keys_box[inx++] = ssl;
      END_DO_SET ();
    }
  if (setp->setp_dependent_box)
    {
      int inx = 0;
      DO_SET (state_slot_t *, ssl, &setp->setp_dependent)
	setp->setp_dependent_box[inx++] = ssl;
      END_DO_SET ();
    }
  if (setp->setp_ha && HA_GROUP == setp->setp_ha->ha_op)
    setp->setp_ha->ha_tree->ssl_type = SSL_TREE;	/* not a vector, the set no is in the grouping key if needed */
}


int
ssl_needs_ins_cast (state_slot_t * ssl, dbe_column_t * col)
{
  if (DV_WIDE == col->col_sqt.sqt_dtp && (DV_ANY == ssl->ssl_dc_dtp && DV_WIDE == ssl->ssl_sqt.sqt_dtp))
    return 0;
  if (DV_STRING == col->col_sqt.sqt_dtp && (DV_ANY == ssl->ssl_dc_dtp && DV_STRING == ssl->ssl_sqt.sqt_dtp))
    return 0;
  if (ssl->ssl_dc_dtp == dtp_canonical[col->col_sqt.sqt_dtp])
    {
      switch (dtp_canonical[col->col_sqt.sqt_dtp])
	{
	case DV_LONG_INT:
	case DV_IRI_ID:
	case DV_SINGLE_FLOAT:
	case DV_DOUBLE_FLOAT:
	case DV_NUMERIC:
	case DV_DATETIME:
	case DV_DATE:
	case DV_TIMESTAMP:
	case DV_TIME:
	  return 0;
	}
    }
  return 1;
}


void
sqlg_vec_ins (sql_comp_t * sc, insert_node_t * ins)
{
  /* ins_slots are made to be copies if origin is not immediate predecessor or if there is a cast.  The cast dc is used for search params so the type/representation must be the same as in the physical col */
  dk_set_t casts = NULL;
  dk_hash_t *copies = hash_table_allocate (11);
  int inx, ik_inx;
  DO_BOX (ins_key_t *, ik, ik_inx, ins->ins_keys)
  {
    sqlg_ssl_arr_shadow (sc, ik->ik_slots);
    if (ik->ik_key->key_partition)
      ik->ik_ins_slices = cc_new_instance_slot (sc->sc_cc);
    DO_BOX (state_slot_t *, ssl, inx, ik->ik_slots)
    {
      dbe_column_t *col = ik->ik_cols[inx];
      if (!gethash ((void *) col, copies))
	{
	  state_slot_ref_t *ref = sqlg_vec_ssl_ref (sc, ssl, 0);
	  int need_cast = ssl_needs_ins_cast (ssl, ik->ik_cols[inx]) || !SSL_IS_VEC_OR_REF (ssl);
	  if (SSL_REF == ref->ssl_type || need_cast)
	    {
	      t_set_push (&casts, (void *) t_list_nc (3, col, ref, need_cast));
	    }
	}
    }
    END_DO_BOX;
  }
  END_DO_BOX;
  if (casts)
    {
      int n_casts = dk_set_length (casts);
      casts = dk_set_nreverse (casts);
      ins->ins_vec_cast = (state_slot_t **) dk_alloc_box (sizeof (caddr_t) * n_casts, DV_BIN);
      ins->ins_vec_source = (state_slot_ref_t **) dk_alloc_box (sizeof (caddr_t) * n_casts, DV_BIN);
      ins->ins_vec_cast_cl = (dbe_col_loc_t **) dk_alloc_box (sizeof (caddr_t) * n_casts, DV_BIN);
      inx = 0;
      DO_SET (void **, rec, &casts)
      {
	dbe_column_t *col = (dbe_column_t *) rec[0];
	state_slot_t *ssl = (state_slot_t *) rec[1];
	state_slot_t *cast;
	ins->ins_vec_source[inx] = (state_slot_ref_t *) ssl;
	ins->ins_vec_cast_cl[inx] = key_find_cl (ins->ins_table->tb_primary_key, col->col_id);
	cast = ssl_new_vec (sc->sc_cc, "cast", col->col_sqt.sqt_dtp);
	ins->ins_vec_cast[inx++] = cast;
	cast->ssl_sqt = col->col_sqt;
	if (col->col_sqt.sqt_dtp == DV_OBJECT)
	  cast->ssl_dc_dtp = cast->ssl_sqt.sqt_dtp = DV_ANY;
	ssl_set_dc_type (cast);
	sethash ((void *) col, copies, (void *) cast);
      }
      END_DO_HT;
      DO_BOX (ins_key_t *, ik, ik_inx, ins->ins_keys)
      {
	DO_BOX_0 (state_slot_t *, ssl, inx, ik->ik_slots)
	{
	  state_slot_t *copy = gethash ((void *) ik->ik_cols[inx], copies);
	  if (copy)
	    {
	      ik->ik_slots[inx] = copy;
	    }
	}
	END_DO_BOX;
      }
      END_DO_BOX;
    }
  ref_ssls (NULL, ins->ins_trigger_args);
  ins->ins_vectored = 1;
  if (ins->ins_table->tb_primary_key->key_partition)
    ins->ins_set_mask = cc_new_instance_slot (sc->sc_cc);
  hash_table_free (copies);
}

state_slot_t *
qn_find_col (data_source_t * qn, dbe_column_t * col)
	{
	  int n;
	  QNCAST (table_source_t, ts, qn);
  key_source_t *ks;
	  search_spec_t *sp;
  if (IS_QN (qn, query_frag_input))
    {
      QNCAST (query_frag_t, qf, qn);
      DO_SET (data_source_t *, qn2, &qf->qf_nodes)
      {
	state_slot_t *ssl = qn_find_col (qn2, col);
	if (ssl)
	  return ssl;
      }
      END_DO_SET ();
      return NULL;
    }
  if (!IS_TS (qn))
    return NULL;
  ks = ts->ts_order_ks;
	  if (!ks)
    return NULL;
	  n = dk_set_position (ks->ks_out_cols, (void *) col);
	  if (-1 != n)
	    return (state_slot_t *) dk_set_nth (ks->ks_out_slots, n);
	  sp = ks_find_eq_sp (ks, col->col_id);
	  if (sp)
	    return sp->sp_min_ssl;
  return NULL;
	}

state_slot_t *
sqlg_find_col (sql_comp_t * sc, dbe_column_t * col)
{
  data_source_t *qn;
  for (qn = sc->sc_cc->cc_query->qr_head_node; qn; qn = qn_next (qn))
    {
      state_slot_t *ssl = qn_find_col (qn, col);
      if (ssl)
	return ssl;
    }
  SQL_GPF_T1 (sc->sc_cc, "should have found col ssl for vec dml");
  return NULL;
}


ins_key_t *
sqlg_del_ik (sql_comp_t * sc, delete_node_t * del1, dbe_key_t * key)
{
  int n = 0;
  NEW_VARZ (ins_key_t, ik);
  ik->ik_key = key;
  if (key->key_partition)
    ik->ik_del_slices = cc_new_instance_slot (sc->sc_cc);
  ik->ik_del_slots = (state_slot_t **) dk_alloc_box_zero (sizeof (caddr_t) * key->key_n_significant, DV_BIN);
  ik->ik_del_cast = (state_slot_t **) dk_alloc_box_zero (sizeof (caddr_t) * key->key_n_significant, DV_BIN);
  ik->ik_del_cast_func = (dc_val_cast_t *) dk_alloc_box_zero (sizeof (caddr_t) * key->key_n_significant, DV_BIN);
  DO_SET (dbe_column_t *, col, &key->key_parts)
  {
    state_slot_t *ssl;
    /*state_slot_t col_ssl; */
    dc_val_cast_t f = NULL;
    ssl = sqlg_find_col (sc, col);
    ik->ik_del_slots[n] = (state_slot_t *) sqlg_vec_ssl_ref (sc, ssl, 0);
#if 0
    memset (&col_ssl, 0, sizeof (col_ssl));
    col_ssl.ssl_sqt = col->col_sqt;
    ssl_set_dc_type (&col_ssl);
    f = sqlg_dc_cast_func (sc, &col_ssl, ssl);
#endif
    if (SSL_VEC != ik->ik_del_slots[n]->ssl_type || f || DV_ANY == col->col_sqt.sqt_dtp)
      {
	dtp_t dtp = DV_ANY == col->col_sqt.sqt_col_dtp ? DV_ANY : col->col_sqt.sqt_col_dtp;
	ik->ik_del_cast[n] = ssl_new_vec (sc->sc_cc, "cast", dtp);
	ik->ik_del_cast[n]->ssl_sqt.sqt_non_null = ssl->ssl_sqt.sqt_non_null;
	ik->ik_del_cast[n]->ssl_sqt.sqt_col_dtp = col->col_sqt.sqt_dtp;
	ik->ik_del_cast[n]->ssl_sqt.sqt_non_null = ik->ik_del_slots[n]->ssl_sqt.sqt_non_null;
	ik->ik_del_cast_func[n] = f;
      }
    if (++n == key->key_n_significant)
      break;
  }
  END_DO_SET ();
  return ik;
}


void
sqlg_set_ts_delete (sql_comp_t * sc, table_source_t * ts)
{
  key_source_t *ks = ts->ts_order_ks;
  if (!ks->ks_key->key_is_col)
    {
      v_out_map_t *om = ks->ks_v_out_map;
      int n = box_length (om) / sizeof (v_out_map_t);
      v_out_map_t *om2 = (v_out_map_t *) dk_alloc_box (sizeof (v_out_map_t) * (n + 1), DV_BIN);
      memcpy (om2, om, sizeof (v_out_map_t) * n);
      memset (&om2[n], 0, sizeof (v_out_map_t));
      ks->ks_v_out_map = om2;
      om2[n].om_ref = dc_itc_delete;
      dk_free_box ((caddr_t) om);
    }
  ks->ks_is_deleting = 1;
}


void
sqlg_set_ts_plh (sql_comp_t * sc, table_source_t * ts)
{
  key_source_t *ks = ts->ts_order_ks;
  if (!ks->ks_key->key_is_col)
    {
      v_out_map_t *om = ks->ks_v_out_map;
      int n = box_length (om) / sizeof (v_out_map_t);
      v_out_map_t *om2 = (v_out_map_t *) dk_alloc_box (sizeof (v_out_map_t) * (n + 1), DV_BIN);
      memcpy (om2, om, sizeof (v_out_map_t) * n);
      memset (&om2[n], 0, sizeof (v_out_map_t));
      ks->ks_v_out_map = om2;
      om2[n].om_ref = dc_itc_placeholder;
      om2[n].om_ssl = ts->ts_current_of;
      dk_free_box ((caddr_t) om);
    }
  ks->ks_is_vec_plh = 1;
}

void
sqlg_vec_del (sql_comp_t * sc, delete_node_t * del)
{
  dk_set_t all_keys = del->del_key_only ? t_CONS (del->del_key_only, NULL) : del->del_table->tb_keys;
  dk_set_t keys_done = NULL;
  data_source_t *qn = sc->sc_vec_qf ? sc->sc_vec_qf->qf_head_node : sc->sc_cc->cc_query->qr_head_node;
  int is_first = 1;
  table_source_t *last_no_test = NULL;
  if (sch_view_def (sc->sc_cc->cc_schema, del->del_table->tb_name))
    {
      del->del_is_view = 1;
      return;
    }
  for (qn = qn; qn; qn = qn_next (qn))
    {
      if (IS_TS (qn))
	{
	  QNCAST (table_source_t, ts, qn);
	  key_source_t *ks = ts->ts_order_ks;
	  if (ks->ks_key->key_distinct)
	    ;
	  else if (ks->ks_local_test)
	    last_no_test = NULL;
	  else if (!is_first && ks->ks_row_spec)
	    last_no_test = NULL;
	  else if (!last_no_test)
	    last_no_test = ts;
	  if (!ks->ks_key->key_distinct)
	  is_first = 0;
	}
      else if (IS_QN (qn, delete_node_input))
	{
	  QNCAST (delete_node_t, del, qn);
	  int fill = 0;
	  table_source_t *del_ts;
	  for (del_ts = last_no_test; del_ts; del_ts = (table_source_t *) qn_next ((data_source_t *) del_ts))
	    {
	      if (!IS_TS (del_ts) || del->del_trigger_args)
		break;
	      if (!del_ts->ts_order_ks->ks_key->key_distinct || del->del_key_only)
		sqlg_set_ts_delete (sc, del_ts);
	      t_set_push (&keys_done, (void *) del_ts->ts_order_ks->ks_key);
	    }
	  del->del_param_nos = cc_new_instance_slot (sc->sc_cc);
	  if (del->del_table->tb_primary_key->key_partition)
	    del->del_set_mask = cc_new_instance_slot (sc->sc_cc);
	  if (del->del_key_only)
	    {
	      if (keys_done)
		del->del_keys = dk_alloc_box (0, DV_BIN);
	      else
		del->del_keys = (ins_key_t **) list (1, sqlg_del_ik (sc, del, del->del_key_only));
	      return;
	    }
	  del->del_keys =
	      (ins_key_t **) dk_alloc_box_zero (sizeof (caddr_t) * (dk_set_length (all_keys) - dk_set_length (keys_done)), DV_BIN);
	  ref_ssls (NULL, del->del_trigger_args);
	  DO_SET (dbe_key_t *, key, &all_keys)
	  {
	    if (dk_set_member (keys_done, (void *) key))
	      continue;
	    if (!key->key_distinct || del->del_key_only)
	      del->del_keys[fill++] = sqlg_del_ik (sc, del, key);
	  }
	  END_DO_SET ();
	}
      else
	{
	  last_no_test = NULL;
	}
    }
}






int
upd_key_affected (update_node_t * upd, dbe_key_t * key)
{
  int n_parts = key->key_is_primary ? key->key_n_significant : dk_set_length (key->key_parts);
  int nth = 0, i1;
  DO_SET (dbe_column_t *, col, &key->key_parts)
  {
    DO_BOX (oid_t, u, i1, upd->upd_col_ids)
{
      if (u == col->col_id)
{
	  if (key->key_is_primary)
	    upd->upd_pk_change = 1;
	  return 1;
	}
    }
    END_DO_BOX;
    if (++nth == n_parts)
      break;
  }
  END_DO_SET ();
  return 0;
}

void
sqlg_vec_upd_ins (sql_comp_t * sc, update_node_t * upd)
{
  /* ins_slots are made to be copies if origin is not immediate predecessor or if there is a cast.  The cast dc is used for search params so the type/representation must be the same as in the physical col */
  dk_set_t casts = NULL;
  dk_hash_t *copies = hash_table_allocate (11);
  int inx, ik_inx, iu;
  DO_BOX (ins_key_t *, ik, ik_inx, upd->upd_keys)
    {
    if (!ik)
	continue;
    DO_BOX (state_slot_t *, ssl, inx, ik->ik_slots)
    {
      dbe_column_t *col = ik->ik_cols[inx];
      if (!gethash ((void *) col, copies))
	{
	  state_slot_ref_t *ref = sqlg_vec_ssl_ref (sc, ssl, 0);
	  int need_cast = ssl_needs_ins_cast (ssl, ik->ik_cols[inx]);
	  if (SSL_REF == ref->ssl_type || need_cast)
	    {
	      t_set_push (&casts, (void *) t_list_nc (3, col, ref, need_cast));
	    }
    }
}
    END_DO_BOX;
  }
  END_DO_BOX;
  DO_BOX (ptrlong, col_id, iu, upd->upd_col_ids)
  {
    state_slot_t *ssl = upd->upd_values[iu];
    dbe_column_t *col = sch_id_to_column (wi_inst.wi_schema, col_id);
    if (IS_BLOB_DTP (col->col_sqt.sqt_dtp))
      upd->upd_any_blob = 1;
    if (!gethash ((void *) col, copies))
      {
	state_slot_ref_t *ref = sqlg_vec_ssl_ref (sc, ssl, 0);
	int need_cast = ssl_needs_ins_cast (ssl, col);
	if (SSL_VEC != ref->ssl_type || need_cast)
	  {
	    t_set_push (&casts, (void *) t_list_nc (3, col, ref, need_cast));
	  }
      }
  }
  END_DO_BOX;
  if (casts)
    {
      int n_casts = dk_set_length (casts);
      casts = dk_set_nreverse (casts);
      upd->upd_vec_cast = (state_slot_t **) dk_alloc_box (sizeof (caddr_t) * n_casts, DV_BIN);
      upd->upd_vec_source = (state_slot_ref_t **) dk_alloc_box (sizeof (caddr_t) * n_casts, DV_BIN);
      upd->upd_vec_cast_cl = (dbe_col_loc_t **) dk_alloc_box (sizeof (caddr_t) * n_casts, DV_BIN);
      inx = 0;
      DO_SET (void **, rec, &casts)
      {
	dbe_column_t *col = (dbe_column_t *) rec[0];
	state_slot_t *ssl = (state_slot_t *) rec[1];
	int need_cast = (ptrlong) rec[2];
	state_slot_t *org = SSL_REF == ssl->ssl_type ? ((state_slot_ref_t *) ssl)->sslr_ssl : ssl;
	state_slot_t *cast;
	upd->upd_vec_source[inx] = (state_slot_ref_t *) ssl;
	if (!SSL_IS_VEC_OR_REF (ssl))
	  need_cast = 1;
	upd->upd_vec_cast_cl[inx] = key_find_cl (upd->upd_table->tb_primary_key, col->col_id);
	cast = ssl_new_vec (sc->sc_cc, "cast", col->col_sqt.sqt_dtp);
	ASG_SSL (NULL, NULL, cast);
	upd->upd_vec_cast[inx++] = cast;
	cast->ssl_sqt = col->col_sqt;
	cast->ssl_column = org->ssl_column;
	if (col->col_sqt.sqt_dtp == DV_OBJECT)
	  cast->ssl_dc_dtp = cast->ssl_sqt.sqt_dtp = DV_ANY;
	ssl_set_dc_type (cast);
	sethash ((void *) col, copies, (void *) cast);
      }
      END_DO_HT;
      DO_BOX (ins_key_t *, ik, ik_inx, upd->upd_keys)
      {
	if (!ik)
	  continue;
	DO_BOX_0 (state_slot_t *, ssl, inx, ik->ik_slots)
	{
	  dbe_column_t *col = ik->ik_cols[inx];
	  state_slot_t *copy = gethash ((void *) col, copies);
	  if (copy)
	    {
	      ik->ik_slots[inx] = copy;
	      ASG_SSL (NULL, NULL, copy);
	    }
	}
	END_DO_BOX;
      }
      END_DO_BOX;
    }
  DO_BOX_0 (state_slot_t *, ssl, inx, upd->upd_values)
  {
    dbe_column_t *col;
    state_slot_t *copy;
    if (inx >= BOX_ELEMENTS (upd->upd_col_ids))
      break;
    col = sch_id_to_column (wi_inst.wi_schema, upd->upd_col_ids[inx]);
    copy = gethash ((void *) col, copies);
    if (copy)
      upd->upd_values[inx] = copy;
  }
  END_DO_BOX;
  if (upd->upd_quick_values)
    {
      int n_fixed = 0;
      if (upd->upd_fixed_cl)
	n_fixed = BOX_ELEMENTS (upd->upd_fixed_cl);
      DO_BOX_0 (state_slot_t *, ssl, inx, upd->upd_quick_values)
      {
	dbe_column_t *col =
	    sch_id_to_column (wi_inst.wi_schema,
	    inx < n_fixed ? upd->upd_fixed_cl[inx]->cl_col_id : upd->upd_var_cl[inx - n_fixed]->cl_col_id);
	state_slot_t *copy = gethash ((void *) col, copies);
	if (copy)
	  upd->upd_quick_values[inx] = copy;
	else
	  REF_SSL (NULL, upd->upd_quick_values[inx]);
      }
      END_DO_BOX;
    }
  hash_table_free (copies);
}


int
key_col_layout_pos (dbe_key_t * key, oid_t col_id)
{
  int nth = 0;
  DO_ALL_CL (cl, key)
  {
    if (col_id == cl->cl_col_id)
      {
	if (key->key_is_col && nth > key->key_n_significant)
	  nth -= key->key_n_significant;	/* for col-wise inx if dependent part, subtract n significatnt because the key cols repeat as dependents for the col refs */
	return nth;
    }
    nth++;
  }
  END_DO_ALL_CL;
  GPF_T1 ("looking for a col that is not in the key");
  return nth;
}


void
sqlg_ik_upd_ins (sql_comp_t * sc, update_node_t * upd, ins_key_t * ik)
{
  dbe_key_t *key = ik->ik_key;
  int n_parts = dk_set_length (key->key_parts), inx = 0, i1;
  ik->ik_cols = (dbe_column_t **) dk_alloc_box (sizeof (caddr_t) * n_parts, DV_BIN);
  ik->ik_slots = (state_slot_t **) dk_alloc_box (sizeof (caddr_t) * n_parts, DV_BIN);
  if (key->key_partition)
    {
      ik->ik_ins_slices = cc_new_instance_slot (sc->sc_cc);
      ik->ik_del_slices = cc_new_instance_slot (sc->sc_cc);
    }

  DO_SET (dbe_column_t *, col, &key->key_parts)
  {
    int layout_pos = key_col_layout_pos (key, col->col_id);
    ik->ik_cols[layout_pos] = col;
    DO_BOX (oid_t, cid, i1, upd->upd_col_ids)
    {
      if (cid == col->col_id)
	{
	  ik->ik_slots[layout_pos] = upd->upd_values[i1];
	  goto found;
	}
    }
    END_DO_BOX;
    ik->ik_slots[layout_pos] = sqlg_find_col (sc, col);
  found:
    inx++;
  }
  END_DO_SET ();
}


state_slot_t *
upd_find_col_ssl (update_node_t * upd, oid_t col_id)
{
  /* find one of the extra ssls in upd values based on the col.  Used for getting pk values and old values of updated blobs */
  int n_values = BOX_ELEMENTS (upd->upd_values);
  int inx;
  for (inx = BOX_ELEMENTS (upd->upd_col_ids); inx < n_values; inx++)
    {
      state_slot_t *ssl = upd->upd_values[inx];
      if (SSL_REF == ssl->ssl_type)
	ssl = ((state_slot_ref_t *) ssl)->sslr_ssl;
      if (ssl->ssl_column && col_id == ssl->ssl_column->col_id)
	return upd->upd_values[inx];
    }
  if (sqlg_vec_debug < 3)
    GPF_T1 ("upd of col wise pk does not find pk or old blob ssl");
  return NULL;
}


int dbf_test_col_upd = 0;

void
sqlg_vec_upd_col_pk (sql_comp_t * sc, update_node_t * upd)
{
  /* for column-wise pk, set the pk ssl for logging and the old blob ssls */
  dbe_key_t *key = upd->upd_table->tb_primary_key;
  int inx, n_values = BOX_ELEMENTS (upd->upd_values), pk_fill = 0;
  if (!key->key_is_col && !dbf_test_col_upd)
    return;
  for (inx = BOX_ELEMENTS (upd->upd_col_ids); inx < n_values; inx++)
    {
      REF_SSL (NULL, upd->upd_values[inx]);
    }
  upd->upd_pk_values = (state_slot_t **) dk_alloc_box (sizeof (caddr_t) * key->key_n_significant, DV_BIN);
  DO_CL (cl, key->key_key_fixed)
    upd->upd_pk_values[pk_fill++] = upd_find_col_ssl (upd, cl->cl_col_id);
  END_DO_CL;
  DO_CL (cl, key->key_key_var)
    upd->upd_pk_values[pk_fill++] = upd_find_col_ssl (upd, cl->cl_col_id);
  END_DO_CL;
  upd->upd_old_blobs = (state_slot_t **) dk_alloc_box_zero (sizeof (caddr_t) * BOX_ELEMENTS (upd->upd_col_ids), DV_BIN);
  DO_BOX (oid_t, col_id, inx, upd->upd_col_ids)
  {
    dbe_column_t *col = sch_id_to_col (wi_inst.wi_schema, col_id);
    if (IS_BLOB_DTP (col->col_sqt.sqt_col_dtp))
      upd->upd_old_blobs[inx] = upd_find_col_ssl (upd, col_id);
  }
  END_DO_BOX;
}


void
sqlg_vec_upd (sql_comp_t * sc, update_node_t * upd)
{
  /* follows form of vec del but does not use the deleting ks trick for 2nd keys used for finding row to upd */
  table_source_t *last_ts = NULL;
  dk_set_t all_keys = upd->upd_table->tb_keys;
  data_source_t *qn = sc->sc_vec_qf ? sc->sc_vec_qf->qf_head_node : sc->sc_cc->cc_query->qr_head_node;
  int is_first = 1;
  table_source_t *last_no_test = NULL;
  if (sch_view_def (sc->sc_cc->cc_schema, upd->upd_table->tb_name))
    {
      upd->upd_is_view = 1;
      return;
    }
  for (qn = qn; qn; qn = qn_next (qn))
    {
      if (IS_TS (qn))
	{
	  QNCAST (table_source_t, ts, qn);
	  key_source_t *ks = ts->ts_order_ks;
	  last_ts = ts;
	  if (ks->ks_local_test)
	    last_no_test = NULL;
	  else if (!is_first && ks->ks_row_spec)
	    last_no_test = NULL;
	  else if (!last_no_test)
	    last_no_test = ts;
	  is_first = 0;
	}
      else if (IS_QN (qn, update_node_input))
	{
	  QNCAST (update_node_t, upd, qn);
	  int fill = 0;
	  upd->upd_param_nos = cc_new_instance_slot (sc->sc_cc);
	  upd->upd_keys = (ins_key_t **) dk_alloc_box_zero (sizeof (caddr_t) * (dk_set_length (all_keys)), DV_BIN);
	  DO_SET (dbe_key_t *, key, &all_keys)
	  {
	    if (upd_key_affected (upd, key))
	      {
		upd->upd_keys[fill++] = sqlg_del_ik (sc, NULL, key);
		sqlg_ik_upd_ins (sc, upd, upd->upd_keys[fill - 1]);
	      }
	  }
	  END_DO_SET ();
	  sqlg_vec_upd_ins (sc, upd);
	}
      else
	{
	  last_no_test = NULL;
	}
    }
  ref_ssls (NULL, upd->upd_trigger_args);
  if (!upd->upd_pk_change)
    {
      //state_slot_t * co = ssl_new_placeholder (sc->sc_cc, "co");
      //last_ts->ts_current_of = co;
      //upd->upd_place = last_ts->ts_current_of;
      REF_SSL (NULL, upd->upd_place);
      sqlg_set_ts_plh (sc, last_ts);
      sqlg_vec_upd_col_pk (sc, upd);
    }
  else
    last_ts->ts_current_of = NULL;
  if (upd->cms.cms_clrg)
    upd->upd_set_mask = cc_new_instance_slot (sc->sc_cc);
}


int
sslr_box_position (state_slot_t ** ssls, state_slot_t * ssl)
{
  int inx;
  if (!ssl)
    return -1;
  DO_BOX (state_slot_t *, elt, inx, ssls)
    if (elt->ssl_index == ssl->ssl_index)
    return inx;
  END_DO_BOX;
  return -1;
}

int
dk_set_ssl_position (dk_set_t set, state_slot_t * ssl)
{
  int pos = 0;
  DO_SET (state_slot_t *, m, &set)
  {
    if (m->ssl_index == ssl->ssl_index)
      return pos;
    pos++;
  }
  END_DO_SET ();
  return -1;
}


dk_set_t
sslr_set_member (dk_set_t ssls, state_slot_t * param)
{
  if (!param)
    return NULL;
  DO_SET (state_slot_t *, ssl, &ssls)
    if (ssl && ssl->ssl_index == param->ssl_index)
    return iter;
  END_DO_SET ();
  return NULL;
}

search_spec_t *
ks_find_eq_sp (key_source_t * ks, oid_t col_id)
{
  search_spec_t *sp;
  for (sp = ks->ks_spec.ksp_spec_array; sp; sp = sp->sp_next)
    if (col_id == sp->sp_cl.cl_col_id && CMP_EQ == sp->sp_min_op)
      return sp;
  for (sp = ks->ks_row_spec; sp; sp = sp->sp_next)
    if (col_id == sp->sp_cl.cl_col_id && CMP_EQ == sp->sp_min_op)
      return sp;
  return NULL;
}

#define SP_SHADOW(ssl) \
  if (ssl && (shadow = (state_slot_t*)gethash((void*)(ptrlong)ssl->ssl_index, sc->sc_vec_ssl_shadow))) ssl = shadow;






void sqlg_sqs_qr_pred (sql_comp_t * sc, query_t * qr, data_source_t * prev_with_set_no);


void
sqlg_set_cv_subq_prev (sql_comp_t * sc, code_vec_t cv, data_source_t * prev)
{
  if (!cv)
    return;
  DO_INSTR (ins, 0, cv)
  {
    switch (ins->ins_type)
      {
      case INS_SUBQ:
	sqlg_sqs_qr_pred (sc, ins->_.subq.query, prev);
	break;
      case IN_PRED:
	if ((pred_func_t) exists_pred_func == ins->_.pred.func || (pred_func_t) subq_comp_func == ins->_.pred.func)
      {
	    subq_pred_t *subp = (subq_pred_t *) ins->_.pred.cmp;
	    sqlg_sqs_qr_pred (sc, subp->subp_query, prev);
  }
	break;
    }
    }
  END_DO_INSTR;
}

void
sqlg_qn_code_prev (sql_comp_t * sc, data_source_t * qn, data_source_t * prev_with_set_no)
{
  sqlg_set_cv_subq_prev (sc, qn->src_pre_code, prev_with_set_no);
  if (IS_QN (qn, end_node_input))
  {
      if (qn->src_after_test)
	sqlg_set_cv_subq_prev (sc, qn->src_after_test, prev_with_set_no);
      else if (qn->src_after_code)
	sqlg_set_cv_subq_prev (sc, qn->src_after_test, prev_with_set_no);
  }
}


void
sqlg_sqs_qr_pred (sql_comp_t * sc, query_t * qr, data_source_t * prev_with_set_no)
{
  /* go through any fref or sqs nodes to the first that is neither and set its prev to the prev of the sqs */
  data_source_t *qn = qr->qr_head_node;
  if (!prev_with_set_no)
    {
  DO_SET (data_source_t *, prev, &sc->sc_vec_pred)
  {
    if (prev->src_sets)
      {
	prev_with_set_no = prev;
	goto found;
      }
  }
  END_DO_SET ();
  return;			/* there is no predecessor that sets a set no.  Anomalous since there is at least a set ctr at the head of each dt/subq */
    }
found:
  for (;;)
    {
      while (IS_QN (qn, hash_fill_node_input))
	qn = qn_next (qn);
      if (!qn)
	return;
      qn->src_prev = prev_with_set_no;
      if (IS_QN (qn, subq_node_input))
	{
	  qn = ((subq_source_t *) qn)->sqs_query->qr_head_node;
	  continue;
	}
      sqlg_qn_code_prev (sc, qn, prev_with_set_no);
      if (IS_QN (qn, union_node_input))
	{
	  QNCAST (union_node_t, un, qn);
	  DO_SET (query_t *, term, &un->uni_successors)
	  {
	    sqlg_sqs_qr_pred (sc, term, prev_with_set_no);
	  }
	  END_DO_SET ();
	  return;
	}
      if (IS_QN (qn, fun_ref_node_input))
	{
	  qn = ((fun_ref_node_t *) qn)->fnr_select;
	  continue;
	}
      break;
    }
}



void
sqlg_set_tn_dt_prev (sql_comp_t * sc, trans_node_t * tn, query_t * qr)
{
  /* for an inlined step in trans, the tn itself is the prev of the first in each union branch that is neither fref or hash filler or such */
  if (IS_QN (qr->qr_head_node, union_node_input))
    {
      QNCAST (union_node_t, un, qr->qr_head_node);
      DO_SET (query_t *, term, &un->uni_successors)
      {
	sqlg_set_tn_dt_prev (sc, tn, term);
      }
      END_DO_SET ();
    }
  else
    sqlg_sqs_qr_pred (sc, qr, (data_source_t *) tn);
}


void
sqlg_iter_node (sql_comp_t * sc, iter_node_t * in, dk_hash_t * res, dk_hash_t * all_res)
{
  ASG_SSL (res, all_res, in->in_output);
  in->in_current_set = cc_new_instance_slot (sc->sc_cc);
  in->in_current_value = cc_new_instance_slot (sc->sc_cc);
  in->in_vec_array = ssl_new_vec (sc->sc_cc, "iter_vec", DV_ARRAY_OF_POINTER);
  in->in_output->ssl_dtp = in->in_output->ssl_dc_dtp = DV_ARRAY_OF_POINTER;
}

void
sqlg_rdf_inf_node_v (sql_comp_t * sc, rdf_inf_pre_node_t * ri, dk_hash_t * res, dk_hash_t * all_res)
{
  iter_node_t *in = &(ri->ri_iter);
  REF_SSL (res, ri->ri_o);
  REF_SSL (res, ri->ri_p);
  if (!ri->ri_is_after)
    {
      ASG_SSL (res, all_res, in->in_output);
      in->in_output->ssl_dtp = in->in_output->ssl_dc_dtp = DV_IRI_ID;
      in->in_output->ssl_non_null = 1;
    }
  else
    {
      state_slot_t *ref = in->in_output, *sh;
      dtp_t dtp = ref == ri->ri_o ? DV_ANY : DV_IRI_ID;
      in->in_output = sh = ssl_new_inst_variable (sc->sc_cc, "inferred", dtp);	/* XXX: take the ssl name from o or p */
      in->in_output->ssl_dtp = in->in_output->ssl_dc_dtp = dtp;
      in->in_output->ssl_non_null = 1;
      ASG_SSL (res, all_res, sh);
      sethash ((void *) (ptrlong) ref->ssl_index, sc->sc_vec_ssl_shadow, (void *) sh);
    }
  in->in_current_set = cc_new_instance_slot (sc->sc_cc);
  in->in_current_value = cc_new_instance_slot (sc->sc_cc);
  in->in_vec_array = ssl_new_vec (sc->sc_cc, "iter_vec", DV_ARRAY_OF_POINTER);
}


void
sqlg_vec_hash_filler (sql_comp_t * sc, fun_ref_node_t * fref, hash_source_t * hs)
{
  fref->fnr_no_hash_partition = hs->hs_no_partition;
}


int
sqs_is_first (subq_source_t * sqs, dk_set_t preds)
{
  /* Aggregating sqs not in hash fillers and with no previous card increasing node can use a partitioned hash source */
  dk_set_t point = dk_set_member (preds, (void *) sqs);
  DO_SET (data_source_t *, qn, &point)
  {
    if (IS_QN (qn, table_source_input) || (IS_QN (qn, subq_node_input) && qn->src_sets) || IS_QN (qn, hash_source_input))
      return 0;
  }
  END_DO_SET ();
  return 1;
}


int
sqs_is_agg (subq_source_t * sqs)
{
  DO_SET (data_source_t *, qn, &sqs->sqs_query->qr_nodes)
    if (IS_QN (qn, fun_ref_node_input))
    return 1;
  END_DO_SET ();
  return 0;
}

void sqs_set_fref_hash_fill_deps (sql_comp_t * sc, subq_source_t * sqs, hash_source_t * hs);


int
sqlg_hs_non_partitionable (sql_comp_t * sc, hash_source_t * hs)
{
  /* a hs is not partitionable when its probe is from inside a oj that is notr closed or an exists/scalar subq.  In these cases not being able to distinnguish between no data and out of partition in result make the subq result unknown */
  dk_set_t oses = NULL;
  int probe_found = 0;
  DO_SET (data_source_t *, pred, &sc->sc_vec_pred)
  {
    if (IS_QN (pred, outer_seq_end_input))
      t_set_push (&oses, (void *) pred);
    if (!probe_found && pred == (data_source_t *) hs->hs_probe)
      {
	probe_found = 1;
      }
    if (probe_found && IS_QN (pred, set_ctr_input))
      {
	select_node_t *sel;
	QNCAST (set_ctr_node_t, sctr, pred);
	if (sctr->sctr_ose && !dk_set_member (oses, sctr->sctr_ose))
	  return 1;		/*probe inside non closed oj */
	sel = sctr->src_gen.src_query->qr_select_node;
	if (sel && (SEL_VEC_SCALAR == sel->sel_vec_role || SEL_VEC_EXISTS == sel->sel_vec_role))
	  return 1;
      }
    if (probe_found && IS_QN (pred, subq_node_input) && !pred->src_sets && sqs_is_agg ((subq_source_t *) pred))
      {
	/* inside an aggregating  dt.  Is this had src_sets then the dt would be before and we would be after.  Partitioning is ok regardless of nesting if there is nothing before the dt, i.e. the dt is first and all the rest depends on it.  Dt will have full results after all partitions are accumulated */
	int can_partition = sqs_is_first ((subq_source_t *) pred, sc->sc_vec_pred);
	if (can_partition)
	  sqs_set_fref_hash_fill_deps (sc, (subq_source_t *) pred, hs);
	return !can_partition;
      }
  }
  END_DO_SET ();
  return 0;
}


#define MRG_NONE 0
#define MRG_ALWAYS 1
#define MRG_IF_UNQ 2
#define MRG_PART_AND_BLOOM 3
#define MRG_PART_ONLY 4

int
sqlg_can_merge_hs (sql_comp_t * sc, hash_source_t * hs, table_source_t * ts, state_slot_t * ssl)
{
  if (!enable_hash_merge)
    return MRG_NONE;
  if (hs->hs_ha->ha_n_keys > 1)
    return MRG_NONE;
  DO_SET (search_spec_t *, sp, &ts->ts_order_ks->ks_hash_spec)
  {
    hash_range_spec_t *hrng = (hash_range_spec_t *) sp->sp_min_ssl;
    hash_source_t *hs2 = hrng->hrng_hs;
    if (hs2 && hs2->hs_merged_into_ts && hs2->hs_ha->ha_n_deps)
      {
	if (hs->hs_ha->ha_n_deps)
	  return MRG_PART_AND_BLOOM;
  }
  }
  END_DO_SET ();
  if (hs->hs_ha->ha_n_deps && !hs->hs_is_unique)
    return MRG_PART_AND_BLOOM;	/* a hs with out cols can only be merged always, cannot decide at run time because ref path to the ssls would be different */
  return hs->hs_is_unique ? MRG_ALWAYS : MRG_IF_UNQ;
}


void
sqlg_add_merged_hs (dk_set_t * specs, search_spec_t * sp)
{
  /* if a merged hs has output cols it must be last */
  hash_range_spec_t *hrng = (hash_range_spec_t *) sp->sp_min_ssl;
  hash_source_t *hs = hrng->hrng_hs;
  if (hs->hs_ha->ha_n_deps)
    NCONCF1 (*specs, (void *) sp);
  else
    dk_set_push (specs, (void *) sp);
}


dk_set_t
sqlg_ts_preresets (sql_comp_t * sc, table_source_t * ts)
{
  /* return the ssls that are prereset only, i.e. assigned in pre-code */
  int inx, inx2;
  dk_set_t res = NULL;
  DO_BOX (state_slot_t *, reset, inx, ts->src_gen.src_pre_reset)
  {
    DO_BOX (state_slot_t *, creset, inx2, ts->src_gen.src_continue_reset)
    {
      if (reset == creset)
	goto not;
    }
    END_DO_BOX;
    t_set_push (&res, (void *) reset);
  not:;
  }
  END_DO_BOX;
  return res;
}


void
sqlg_hs_realias_key_out (sql_comp_t * sc, hash_source_t * hs)
{
  /* for a key of a hash source that is outer, use the cast ssl as nullable */
  dk_set_t iter;
  for (iter = hs->hs_out_aliases; iter; iter = iter->next->next)
    {
      int nth = (ptrlong) iter->data;
      state_slot_t *key_out = (state_slot_t *) iter->next->data;
      ssl_alias (key_out, hs->hs_ha->ha_slots[nth]);
    }
  hs->hs_out_aliases = NULL;
}

int enable_unq_non_unq = 1;

void
sqlg_vec_hs (sql_comp_t * sc, hash_source_t * hs)
{
  /* set the casts. Set the refs.  The defs are set at the end. */
  int cast_changes_card = 0, cl_part_crossed = 0, no_bloom_in_probe = 0;
  setp_node_t *setp = NULL;
  data_source_t *save_cur;
  dk_set_t save_pred;
  fun_ref_node_t *filler = NULL;
  key_source_t *ks = NULL;
  int n_k_ssl = BOX_ELEMENTS (hs->hs_ref_slots);
  int fill = 0, inx = 0;
  set_ctr_node_t *last_sctr = NULL;
  if (!hs->hs_loc_ts)
    {
      ks = (key_source_t *) dk_alloc (sizeof (key_source_t));
      memset (ks, 0, sizeof (key_source_t));
      ks->ks_ts = (table_source_t *) hs;
      hs->hs_ks = ks;
      ks->ks_vec_cast = (state_slot_t **) dk_alloc_box_zero (sizeof (caddr_t) * (n_k_ssl), DV_BIN);
      ks->ks_vec_source = (state_slot_ref_t **) dk_alloc_box_zero (sizeof (caddr_t) * (n_k_ssl), DV_BIN);
      ks->ks_dc_val_cast = (dc_val_cast_t *) dk_alloc_box_zero (sizeof (caddr_t) * (n_k_ssl), DV_BIN);
    }
  hs->hs_done_in_probe = cc_new_instance_slot (sc->sc_cc);
  hs->hs_hash_no = ssl_new_vec (sc->sc_cc, "hno", DV_LONG_INT);
  hs->hs_ha->ha_tree->ssl_qr_global = 1;
  REF_SSL (NULL, hs->hs_ha->ha_tree);
  filler = hs->hs_filler;
  setp = filler->fnr_setp;
  if (!setp->setp_hash_fill_partitioned)
    setp->setp_hash_fill_partitioned = cc_new_instance_slot (sc->sc_cc);
  /* if a hash is filled by a join that is not known to be uniquely card reducing then the hs which by itself, if joining to a single table would be unique  may stop being unique.  Affects merging into a ts */
  if (enable_unq_non_unq)
    hs->hs_is_unique = CHA_ALWAYS_UNQ == setp->setp_ha->ha_ch_unique;
  hs->hs_is_partitioned = setp->setp_hash_fill_partitioned;
  DO_SET (data_source_t *, pred, &sc->sc_vec_pred)
  {
    state_slot_t *one_key = NULL;
    int any_key = 0;
    if (IS_QN (pred, set_ctr_input))
      {
	QNCAST (set_ctr_node_t, sctr, pred);
	last_sctr = sctr;
	if (sctr->sctr_ose || sctr->sctr_not_in_top_and)
	  no_bloom_in_probe = 1;
      }
    DO_BOX (state_slot_t *, ref, inx, hs->hs_ref_slots)
    {
      if (pred == gethash ((void *) ref, sc->sc_vec_ssl_def))
	{
	  any_key = 1;
	  if (!hs->hs_probe)
	    hs->hs_probe = (table_source_t *) pred;
	  if (one_key || !IS_TS (pred) || !sqlg_is_inline_hash_key (hs->hs_ha, ref, (table_source_t *) pred))
	    {
	      if (last_sctr)
		dk_set_push (&last_sctr->sctr_hash_spec, (void *)
		    sqlg_hash_spec (sc, hs->hs_ref_slots, BOX_ELEMENTS (hs->hs_ref_slots), (table_source_t *) pred, NULL, hs,
			filler, HRNG_PROBE_PART_ONLY));
	      else
		hs->hs_partition_filter_self = 1;
	      goto ref_found;
	    }
	  one_key = ref;
	}
    }
    END_DO_BOX;
    if ((IS_TS (pred) && ((table_source_t *) pred)->ts_order_ks->ks_is_qf_first) || IS_QN (pred, stage_node_input))
      cl_part_crossed = 1;
    if (!any_key)
      continue;
    if (one_key)
      {
	int can_merge = sqlg_can_merge_hs (sc, hs, (table_source_t *) pred, one_key);
	if (last_sctr)
	  {
	    if (can_merge && enable_oj_hash_part_merge)
	      can_merge = no_bloom_in_probe ? MRG_PART_ONLY : MRG_PART_AND_BLOOM;
	    else
	      {
		dk_set_push (&last_sctr->sctr_hash_spec, (void *)
		    sqlg_hash_spec (sc, hs->hs_ref_slots, BOX_ELEMENTS (hs->hs_ref_slots), (table_source_t *) pred, NULL, hs,
			filler, HRNG_PROBE_PART_ONLY));
		can_merge = MRG_NONE;
	      }
	  }
	if (can_merge && cl_part_crossed && HS_CL_REPLICATED != hs->hs_cl_partition)
	  can_merge = MRG_PART_AND_BLOOM;
	if (can_merge)
	  {
	    hs->hs_probe = (table_source_t *) pred;
	    if (MRG_ALWAYS == can_merge)
	      {
		sqlg_add_merged_hs (&((table_source_t *) pred)->ts_order_ks->ks_hash_spec,
		    sqlg_hash_spec (sc, hs->hs_ref_slots, BOX_ELEMENTS (hs->hs_ref_slots), (table_source_t *) pred, one_key, hs,
			filler, HRNG_MERGE));
		hs->hs_merged_into_ts = (table_source_t *) pred;
	      }
	    else if (MRG_IF_UNQ == can_merge)
	      {
		dk_set_push (&((table_source_t *) pred)->ts_order_ks->ks_hash_spec, (void *)
		    sqlg_hash_spec (sc, hs->hs_ref_slots, BOX_ELEMENTS (hs->hs_ref_slots), (table_source_t *) pred, one_key, hs,
			filler, HRNG_MERGE));
	      }
	    else if (MRG_PART_ONLY == can_merge || MRG_PART_AND_BLOOM == can_merge)
	      {
		dk_set_push (&((table_source_t *) pred)->ts_order_ks->ks_hash_spec, (void *)
		    sqlg_hash_spec (sc, hs->hs_ref_slots, BOX_ELEMENTS (hs->hs_ref_slots), (table_source_t *) pred, one_key, hs,
			filler, MRG_PART_ONLY == can_merge ? HRNG_PROBE_PART_ONLY : HRNG_PROBE));
	      }
	  }
	else
	  hs->hs_partition_filter_self = 1;
      }
    goto ref_found;
  }
  END_DO_SET ();
ref_found:
  DO_BOX (state_slot_t *, ref, inx, hs->hs_ref_slots)
  {
    if (!ssl_is_const_card (sc, ref, &hs->hs_ha->ha_key_cols[inx].cl_sqt))
      cast_changes_card = 1;
  }
  END_DO_BOX;
  if (hs->hs_ks)
    {
      DO_BOX_0 (state_slot_t *, ref, inx, hs->hs_ref_slots)
      {
	sql_type_t sqt = hs->hs_ha->ha_key_cols[inx].cl_sqt;
	sqt.sqt_dtp = cha_dtp (dtp_canonical[sqt.sqt_dtp], 1);
	if (DV_ANY == sqt.sqt_dtp)
	  sqt.sqt_col_dtp = DV_ANY;
	sqlg_vec_cast (sc, ks->ks_vec_source, ks->ks_vec_cast, ks->ks_dc_val_cast, &hs->hs_ref_slots[inx], fill,
	    &ks->ks_last_vec_param, &sqt, cast_changes_card);
	hs->hs_ha->ha_slots[inx] = hs->hs_ref_slots[inx];
	fill++;
      }
      END_DO_BOX;
    }
  else
    {
      ref_ssls (res, hs->hs_ref_slots);
    }
  hs->clb.clb_nth_set = cc_new_instance_slot (sc->sc_cc);
  save_cur = sc->sc_vec_current;
  save_pred = sc->sc_vec_pred;
  if (hs->hs_merged_into_ts)
    {
      /* if merged into a ts, the out slots are assigned in the ts, not the hs */
      while (sc->sc_vec_pred && (void *) hs->hs_merged_into_ts != sc->sc_vec_pred->data)
	{
	  QNCAST (table_source_t, post_ts, sc->sc_vec_pred->data);
	  if (IS_TS (post_ts))
	    sqlg_ts_add_copy (sc, post_ts, hs->hs_out_slots);	/* any ts between recipient of merge and the hs being merged must add the out slots of the hs to its branch copy */
	  sc->sc_vec_pred = sc->sc_vec_pred->next;
	}
      if (sc->sc_vec_pred)
	sc->sc_vec_pred = sc->sc_vec_pred->next;
      sc->sc_vec_current = (data_source_t *) hs->hs_merged_into_ts;
    }
  DO_BOX (state_slot_t *, ssl, inx, hs->hs_out_slots)
  {
    ASG_SSL (res, all_res, ssl);
  }
  END_DO_BOX;
  if (hs->hs_merged_into_ts)
    {
      sc->sc_ssl_prereset_only = sqlg_ts_preresets (sc, hs->hs_merged_into_ts);
      sqlg_new_vec_ssls (sc, (data_source_t *) hs->hs_merged_into_ts);
    }
  sc->sc_vec_pred = save_pred;
  sc->sc_vec_current = save_cur;
  sqlg_hs_realias_key_out (sc, hs);
  if (!hs->hs_no_partition)
    hs->hs_no_partition = sqlg_hs_non_partitionable (sc, hs);
  DO_SET (fun_ref_node_t *, fref, &sc->sc_hash_fillers)
  {
    if (fref->fnr_setp->setp_ha->ha_tree == hs->hs_ha->ha_tree)
      {
	hash_area_t *ha = hs->hs_ha;
	int nth_col = ha->ha_n_keys, to;
	sqlg_vec_hash_filler (sc, fref, hs);
	to = MIN (BOX_ELEMENTS (ha->ha_slots), BOX_ELEMENTS (fref->fnr_setp->setp_ha->ha_slots));
	for (nth_col = nth_col; nth_col < to; nth_col++)
	  {
	    state_slot_t *ssl = ha->ha_slots[nth_col];
	    state_slot_t *fssl = fref->fnr_setp->setp_ha->ha_slots[nth_col];
	    if (vec_box_dtps[fssl->ssl_dtp])
	      ssl->ssl_dtp = fssl->ssl_dtp;
	  }
      }
  }
  END_DO_SET ();
}


void
sqlg_vec_gs_union (sql_comp_t * sc, gs_union_node_t * gs)
{
  data_source_t *first_succ, *last_succ;
  int is_first = 1, sets, fill, ign = 0;
  sqlg_new_vec_ssls (sc, (data_source_t *) gs);
  DO_SET (data_source_t *, succ, &gs->gsu_cont)
  {
    succ->src_prev = (data_source_t *) sc->sc_vec_pred->data;
    qn_vec_slots (sc, succ, NULL, NULL, &ign);
    if (is_first)
      {
	sets = succ->src_sets;
	fill = succ->src_out_fill;
	is_first = 0;
	first_succ = succ;
      }
    else
      {
	succ->src_sets = sets;
	succ->src_out_fill = fill;
      }
    last_succ = succ;
  }
  END_DO_SET ();
  gs->src_gen.src_continuations = dk_set_cons (last_succ, NULL);
}


static void
asg_vec_ssl_array (sql_comp_t * sc, dk_hash_t * res, dk_hash_t * all_res, state_slot_t ** ssls)
{
  int inx;
  if (!ssls)
    return;
  DO_BOX (state_slot_t *, ssl, inx, ssls)
  {
    if (!IS_BOX_POINTER (ssl))
      continue;
    ASG_SSL (res, all_res, ssl);
  }
  END_DO_BOX;
}


void
sqlg_asg_shadows (sql_comp_t * sc, dk_set_t ssls)
{
  DO_SET (state_slot_t *, ssl, &ssls)
  {
    state_slot_t *shadow = (state_slot_t *) gethash ((void *) (ptrlong) ssl->ssl_index, sc->sc_vec_ssl_shadow);
    if (shadow)
      {
	iter->data = (void *) shadow;
	ASG_SSL (NULL, NULL, shadow);
      }
    else
      ASG_SSL (NULL, NULL, ssl);
  }
  END_DO_SET ();
}

int
sqlg_shadow_original (sql_comp_t * sc, state_slot_t * ssl)
{
  /* given an ssl that can be a shadow of another, return the original ssl being shadowed.  If nested trans nodes, innermost will ref to  outermost and must be replaced with the innermost shadow */
  int ssl_inx = ssl->ssl_index;
  int changed = 0;
retry:
  DO_HT (ptrlong, org_inx, state_slot_t *, shadow, sc->sc_vec_ssl_shadow)
  {
    if (ssl_inx == shadow->ssl_index)
      {
	ssl_inx = org_inx;
	changed = 1;
	goto retry;
      }
  }
  END_DO_HT;
  return changed ? ssl_inx : 0;
}


void
qn_vec_slots (sql_comp_t * sc, data_source_t * qn, dk_hash_t * res, dk_hash_t * all_res, int *non_cl_local)
{
  int inx, src_resets_done;
  sc->sc_ssl_prereset_only = NULL;

  if (!IS_QN (qn, fun_ref_node_input) && !IS_QN (qn, hash_fill_node_input))
    {
      sc->sc_pre_code_of = qn;
      cv_vec_slots (sc, qn->src_pre_code, res, all_res, non_cl_local);
      sc->sc_pre_code_of = NULL;
      sc->sc_ssl_prereset_only = sc->sc_vec_new_ssls;
    }
  sc->sc_vec_current = qn;
  qn->src_sets = cc_new_instance_slot (sc->sc_cc);
  qn->src_out_fill = cc_new_instance_slot (sc->sc_cc);
  qn->src_batch_size = cc_new_instance_slot (sc->sc_cc);
  src_resets_done = 0;
  if (IS_TS ((table_source_t *) qn) || IS_QN (qn, sort_read_input) || IS_QN (qn, chash_read_input))
    {
      sqlg_vec_ts (sc, (table_source_t *) qn);
    }
  else if (IS_QN (qn, insert_node_input))
    {
      QNCAST (insert_node_t, ins, qn);
      QN_SAVE_PRERESET;
      src_resets_done = 1;
      sqlg_vec_ins (sc, (insert_node_t *) qn);
      sqlg_new_vec_ssls (sc, qn);
      if (ins->ins_del_node)
	{
	  void *tmp = sc->sc_cc->cc_query->qr_head_node;
	  dk_set_t save_pred = sc->sc_vec_pred;
	  data_source_t *save_cur = sc->sc_vec_current;
	  dk_set_t save_new = sc->sc_vec_new_ssls;
	  sc->sc_vec_pred = t_CONS (ins, NULL);
	  sc->sc_vec_current = (data_source_t *) ins;
	  asg_vec_ssl_array (sc, NULL, NULL, ins->ins_vec_cast);
	  sc->sc_vec_new_ssls = NULL;
	  sc->sc_cc->cc_query->qr_head_node = ins->ins_del_node;
	  sc->sc_in_ins_replacing = 1;
	  sqlg_vec_qns (sc, ins->ins_del_node, NULL);
	  sc->sc_in_ins_replacing = 0;
	  sc->sc_cc->cc_query->qr_head_node = tmp;
	  sc->sc_vec_pred = save_pred;
	  sc->sc_vec_current = save_cur;
	  sc->sc_vec_new_ssls = save_new;
	}
      QN_RESTORE_PRERESET;
      src_resets_done = 0;
    }
  else if (IS_QN (qn, delete_node_input))
    {
      QN_SAVE_PRERESET;
      src_resets_done = 1;
      sqlg_vec_del (sc, (delete_node_t *) qn);
      sqlg_new_vec_ssls (sc, qn);
      QN_RESTORE_PRERESET;
    }
  else if ((qn_input_fn) update_node_input == qn->src_input)
    {
      QN_SAVE_PRERESET;
      src_resets_done = 1;
      sqlg_vec_upd (sc, (update_node_t *) qn);
      sqlg_new_vec_ssls (sc, qn);
      QN_RESTORE_PRERESET;
    }
  else if ((qn_input_fn) setp_node_input == qn->src_input)
    sqlg_vec_setp (sc, (setp_node_t *) qn, res);
  else if ((qn_input_fn) subq_node_input == qn->src_input)
    {
      QNCAST (subq_source_t, sqs, qn);
      dk_set_t save = sc->sc_vec_pred;
      int sets_save = qn->src_sets;
      ASG_SSL (res, all_res, sqs->sqs_set_no);
      t_set_push (&sc->sc_vec_pred, (void *) sqs);
      qn->src_sets = 0;		/* the sqs is transparent for the sets for the inner query */
      sqlg_subq_vec (sc, sqs->sqs_query, NULL, NULL);
      sc->sc_vec_pred = save;
      qn->src_sets = sets_save;
      sqs->sqs_query->qr_select_node->sel_vec_role = SEL_VEC_DT;
      sqs->sqs_query->qr_select_node->src_gen.src_sets = sqs->src_gen.src_sets;
      sqs->sqs_query->qr_select_node->src_gen.src_out_fill = sqs->src_gen.src_out_fill;
      DO_BOX (state_slot_t *, out, inx, sqs->sqs_out_slots)
      {
	state_slot_t *sh = (state_slot_t *) gethash ((void *) (ptrlong) out->ssl_index, sc->sc_vec_ssl_shadow);
	if (sh)
	  out = sqs->sqs_out_slots[inx] = sh;
	ASG_SSL (res, all_res, out);
      }
      END_DO_BOX;
      sqlg_sqs_qr_pred (sc, sqs->sqs_query, NULL);
    }
  else if (IS_QN (qn, union_node_input))
    {
      QNCAST (union_node_t, un, qn);
      dk_set_t save = sc->sc_vec_pred;
      data_source_t *save_cur = sc->sc_vec_current;
      subq_source_t *sqs = (subq_source_t *) save->data;	/*union node is always 1st after a sqs */
      query_t *term1 = NULL;
      int sets_save = qn->src_sets;
      qn->src_sets = 0;		/* the sqs is transparent for the sets for the inner query */
      DO_SET (query_t *, term, &un->uni_successors)
      {
	if (!term1)
	  term1 = term;
	term->qr_select_node->sel_set_no = sqs->sqs_set_no;
	sc->sc_vec_pred = save;
	sc->sc_vec_current = (data_source_t *) sc->sc_vec_pred->data;
	sqlg_subq_vec (sc, term, NULL, NULL);
	term->qr_select_node->sel_vec_role = SEL_VEC_DT;
	term->qr_select_node->src_gen.src_sets = sqs->src_gen.src_sets;
	sc->sc_vec_pred = save;
	sqlg_sqs_qr_pred (sc, term, NULL);
      }
      END_DO_SET ();
      qn->src_sets = sets_save;
      sc->sc_vec_pred = save;
      sc->sc_vec_current = save_cur;
      t_set_push (&sc->sc_vec_pred, (void *) sqs);
      DO_BOX (state_slot_t *, out, inx, term1->qr_select_node->sel_out_slots)
      {
	while (SSL_REF == out->ssl_type)
	  out = ((state_slot_ref_t *) out)->sslr_ssl;
	ASG_SSL (res, all_res, out);
      }
      END_DO_BOX;
      sc->sc_vec_new_ssls = NULL;
    }
  else if (IS_QN (qn, gs_union_node_input))
    {
      sqlg_vec_gs_union (sc, (gs_union_node_t *) qn);
      src_resets_done = 1;
    }
  else if ((qn_input_fn) select_node_input == qn->src_input || (qn_input_fn) select_node_input_subq == qn->src_input)
    {
      select_node_t *sel = (select_node_t *) qn;
      ref_ssls (res, sel->sel_out_slots);
      sel->sel_subq_org_set_no = sel->sel_set_no;
      REF_SSL (res, sel->sel_set_no);
      REF_SSL (res, sel->sel_ext_set_no);
      REF_SSL (res, sel->sel_top);
      REF_SSL (res, sel->sel_top_skip);
      if (IS_QN (sel, select_node_input))
	sel->sel_client_batch_start = cc_new_instance_slot (sc->sc_cc);
    }
  else if ((qn_input_fn) hash_source_input == qn->src_input)
    {
      hash_source_t *hs = (hash_source_t *) qn;
      sqlg_vec_hs (sc, hs);
    }
  else if ((qn_input_fn) outer_seq_end_input == qn->src_input)
    {
      int inx;
      QNCAST (outer_seq_end_node_t, ose, qn);
      REF_SSL (res, ose->ose_set_no);
      ose->ose_bits = ssl_new_variable (sc->sc_cc, "ose_sets", DV_BIN);
      ose->ose_out_shadow = (state_slot_t **) box_copy ((caddr_t) ose->ose_out_slots);
      DO_BOX (state_slot_t *, ssl, inx, ose->ose_out_slots)
      {
	state_slot_t *ref;
	REF_SSL (res, ose->ose_out_slots[inx]);
	ref = ose->ose_out_slots[inx];
	if (!ref)
	  continue;
	if (SSL_REF != ref->ssl_type && !ssl->ssl_sqt.sqt_non_null)
	  {
	    ose->ose_out_shadow[inx] = NULL;
	    sethash ((void *) ref, sc->sc_vec_ssl_def, (void *) ose);
	  }
	else
	  {
	    state_slot_t *base = ssl_base_ssl (ssl);
	    state_slot_t *sh = ssl_new_vec (sc->sc_cc, base->ssl_name, base->ssl_dtp);
	    sh->ssl_column = base->ssl_column;
	    sh->ssl_sqt.sqt_non_null = 0;
	    ose->ose_out_shadow[inx] = sh;
	    sethash ((void *) (ptrlong) ssl->ssl_index, sc->sc_vec_ssl_shadow, (void *) sh);
	    ASG_SSL (NULL, NULL, sh);
	  }
      }
      END_DO_BOX;
      DO_SET (data_source_t *, pred, &sc->sc_vec_pred)
      {
	if (IS_QN (pred, set_ctr_input))
	  {
	    sc->sc_vec_pred = iter->next;
	    break;
	  }
      }
      END_DO_SET ();
      sc->sc_vec_in_outer = 0;
    }
  else if ((qn_input_fn) set_ctr_input == qn->src_input)
    {
      QNCAST (set_ctr_node_t, sctr, qn);
      qn->src_batch_size = cc_new_instance_slot (sc->sc_cc);
      ASG_SSL (res, all_res, sctr->sctr_set_no);
      ASG_SSL (res, all_res, sctr->sctr_ext_set_no);
      if (sctr->sctr_ose)
	sc->sc_vec_in_outer = 1;
    }
  else if (IS_QN (qn, skip_node_input))
    {
      QNCAST (skip_node_t, sk, qn);
      REF_SSL (res, sk->sk_top_skip);
      REF_SSL (res, sk->sk_top);
      REF_SSL (res, sk->sk_set_no);
      ASG_SSL_AGG (NULL, NULL, sk->sk_row_ctr);
    }
  else if ((qn_input_fn) in_iter_input == qn->src_input)
    {
      QNCAST (in_iter_node_t, ii, qn);
      sqlg_iter_node (sc, &ii->ii_iter, res, all_res);
      ii->ii_iter.in_is_const = cc_new_instance_slot (sc->sc_cc);
      ref_ssls (res, ii->ii_values);
    }
  else if ((qn_input_fn) rdf_inf_pre_input == qn->src_input)
    {
      QNCAST (rdf_inf_pre_node_t, ri, qn);
      sqlg_rdf_inf_node_v (sc, ri, res, all_res);
    }
  else if ((qn_input_fn) trans_node_input == qn->src_input)
    {
      QNCAST (trans_node_t, tn, qn);
      if (tn->tn_inlined_step)
	{
	  dk_hash_t *shadow_save = hash_table_allocate (11);
	  dk_set_t pred_save = sc->sc_vec_pred;
	  int sets_save = qn->src_sets;
	  QN_SAVE_PRERESET;
	  dk_hash_copy (shadow_save, sc->sc_vec_ssl_shadow);
	  ASG_SSL (NULL, NULL, tn->tn_step_set_no);
	  if (tn->tn_step_out)
	    asg_vec_ssl_array (sc, res, all_res, tn->tn_step_out);
	  ASG_SSL (NULL, NULL, tn->tn_step_no_ret);
	  ASG_SSL (NULL, NULL, tn->tn_path_no_ret);

	  /* make copy of input ref and put in shadow so outside to see original */
	  tn->tn_input_ref = (state_slot_t **) box_copy ((caddr_t) tn->tn_input);
	  DO_BOX (state_slot_t *, ref, inx, tn->tn_input)
	  {
	    int org_shadowed;
	    state_slot_t *sh;
	    REF_SSL (res, tn->tn_input[inx]);
	    ref = tn->tn_input[inx];
	    sh = ssl_new_vec (sc->sc_cc, ref->ssl_name, ref->ssl_dtp);
	    sh->ssl_column = ssl_base_ssl (ref)->ssl_column;
	    sh->ssl_sqt.sqt_non_null = ref->ssl_sqt.sqt_non_null;
	    tn->tn_input_ref[inx] = sh;
	    sethash ((void *) (ptrlong) ref->ssl_index, sc->sc_vec_ssl_shadow, (void *) sh);
	    ASG_SSL (NULL, NULL, sh);
	    org_shadowed = tn->tn_input_src[inx]->ssl_index;
	    if (org_shadowed)
	      sethash ((void *) (ptrlong) org_shadowed, sc->sc_vec_ssl_shadow, (void *) sh);
	  }
	  END_DO_BOX;

	  t_set_push (&sc->sc_vec_pred, (void *) tn);
	  qn->src_sets = 0;	/* the sqs is transparent for the sets for the inner query */
	  sqlg_subq_vec (sc, tn->tn_inlined_step, NULL, NULL);
	  sqlg_set_tn_dt_prev (sc, tn, tn->tn_inlined_step);
	  sc->sc_vec_pred = pred_save;
	  qn->src_sets = sets_save;
	  QN_RESTORE_PRERESET;
	  hash_table_free (sc->sc_vec_ssl_shadow);
	  sc->sc_vec_ssl_shadow = shadow_save;
	  if (tn->tn_complement && tn->tn_is_primary)
	    {
	      sc->sc_vec_current = (data_source_t *) tn;
	      qn_vec_slots (sc, (data_source_t *) tn->tn_complement, res, all_res, non_cl_local);
	      sc->sc_vec_pred = pred_save;
	      qn->src_sets = sets_save;
	      QN_RESTORE_PRERESET;
	    }
	  sc->sc_vec_current = (data_source_t *) tn;
	}
      else
	{
	  ref_ssls (res, tn->tn_input);
	  ref_ssls (res, tn->tn_sas_g);
	}
      ASG_SSL (res, all_res, tn->tn_state_ssl);
      ASG_SSL (res, all_res, tn->tn_step_no_ret);
      ASG_SSL (res, all_res, tn->tn_path_no_ret);
      asg_vec_ssl_array (sc, res, all_res, tn->tn_data);
      if (tn->tn_lowest_sas)
	{
	  tn->tn_output[0] = ssl_new_shadow (sc, tn->tn_output[0], (data_source_t *) tn);
	}
      asg_vec_ssl_array (sc, res, all_res, tn->tn_output);
      asg_vec_ssl_array (sc, res, all_res, tn->tn_out_slots);
    }
  else if (IS_QN (qn, breakup_node_input))
    {
      QNCAST (breakup_node_t, brk, qn);
      ref_ssls (res, brk->brk_all_output);
      DO_BOX (state_slot_t *, ssl, inx, brk->brk_output)
      {
	state_slot_t *sh;
	dtp_t dtp = ssl->ssl_sqt.sqt_dtp;
	sh = ssl_new_vec (sc->sc_cc, ssl->ssl_name, dtp);
	brk->brk_output[inx] = sh;
	ASG_SSL (res, all_res, sh);
	sethash ((void *) (ptrlong) ssl->ssl_index, sc->sc_vec_ssl_shadow, (void *) sh);
      }
      END_DO_BOX;
    }
  else if ((qn_input_fn) dpipe_node_input == qn->src_input)
    {
      dpipe_node_t *dp = (dpipe_node_t *) qn;
      ref_ssls (res, dp->dp_inputs);
      DO_BOX (state_slot_t *, out, inx, dp->dp_outputs)
      {
	ASG_SSL (res, all_res, out);
      }
      END_DO_BOX;
    }
  else if ((qn_input_fn) txs_input == qn->src_input)
    {
      QNCAST (text_node_t, txs, qn);
      txs->src_gen.src_batch_size = cc_new_instance_slot (sc->sc_cc);
      txs->clb.clb_nth_set = cc_new_instance_slot (sc->sc_cc);
      REF_SSL (res, txs->txs_text_exp);
      REF_SSL (res, txs->txs_score_limit);
      if (!txs->txs_is_driving)
	{
	  REF_SSL (all_res, txs->txs_d_id);
	  REF_SSL (res, txs->txs_d_id);
	}
      else
	ASG_SSL (res, all_res, txs->txs_d_id);
      REF_SSL (res, txs->txs_init_id);
      REF_SSL (res, txs->txs_end_id);
      REF_SSL (res, txs->txs_ext_fti);
      REF_SSL (res, txs->txs_precision);
      ASG_SSL (res, all_res, txs->txs_main_range_out);
      ASG_SSL (res, all_res, txs->txs_attr_range_out);
      ASG_SSL (res, all_res, txs->txs_score);
      asg_vec_ssl_array (sc, res, all_res, txs->txs_offband);
    }
  else if (IS_QN (qn, xn_input))
    {
      QNCAST (xpath_node_t, xn, qn);
      xn->src_gen.src_batch_size = cc_new_instance_slot (sc->sc_cc);
      xn->clb.clb_nth_set = cc_new_instance_slot (sc->sc_cc);
      ASG_SSL (res, all_res, xn->xn_output_val);
      ASG_SSL (res, all_res, xn->xn_output_len);
      ASG_SSL (res, all_res, xn->xn_output_ctr);
      REF_SSL (res, xn->xn_exp_for_xqr_text);
      REF_SSL (res, xn->xn_base_uri);
      REF_SSL (res, xn->xn_text_col);
    }
  else if (IS_QN (qn, end_node_input))
    {
      int ign = 0;
      QNCAST (end_node_t, en, qn);
      cv_vec_slots (sc, en->src_gen.src_after_test, NULL, NULL, &ign);
      if (en->src_gen.src_after_test && en->src_gen.src_after_code)
	{
	  dk_set_t save = sc->sc_vec_pred;
	  t_set_push (&sc->sc_vec_pred, (void *) en);
	  sqlg_new_vec_ssls (sc, (data_source_t *) en);
	  sc->sc_vec_current = (data_source_t *) en;
	  cv_vec_slots (sc, en->src_gen.src_after_code, NULL, NULL, &ign);
	  sqlg_new_vec_ssls (sc, (data_source_t *) en);
	  sc->sc_vec_pred = save;
	}
      else
	cv_vec_slots (sc, en->src_gen.src_after_code, NULL, NULL, &ign);
      sqlg_new_vec_ssls (sc, &en->src_gen);
      return;
    }
  if (!src_resets_done)
    sqlg_new_vec_ssls (sc, qn);
  qn_add_prof (sc, qn);
  sqlg_vec_after_test (sc, qn);
  if (IS_QN (qn, subq_node_input))
    {
      QNCAST (subq_source_t, sqs, qn);
      if (sqs->sqs_after_join_test)
	{
	  sqs->src_gen.src_after_test = sqs->sqs_after_join_test;
	  sqs->sqs_after_join_test = NULL;
	  sqlg_vec_after_test (sc, qn);
	}
    }
  else if (IS_QN (qn, trans_node_input))
    {
      QNCAST (trans_node_t, tn, qn);
      if (tn->tn_after_join_test)
	{
	  tn->src_gen.src_after_test = tn->tn_after_join_test;
	  tn->tn_after_join_test = NULL;
	  sqlg_vec_after_test (sc, qn);
	}
    }
}


int
qn_is_const_card (data_source_t * qn)
{
  /* true if always one row of output for one of input */
  if (IS_QN (qn, dpipe_node_input))
    return 1;
  if (IS_QN (qn, hash_source_input) && ((hash_source_t*)qn)->hs_merged_into_ts)
    return 1;
  return 0;
}


int
sp_ssl_count (sql_comp_t * sc, search_spec_t * sp, unsigned char *n_eq, int *cast_changes_card)
{
  /* set n_eqs to be the count of leading eqs */
  int n = 0, all_eq = 1;
  for (sp = sp; sp; sp = sp->sp_next)
    {
      if (all_eq && sp->sp_min_op != CMP_EQ)
	{
	  if (n_eq)
	    *n_eq = n;
	  all_eq = 0;
	}
      if (sp->sp_min_ssl)
	{
	  if (cast_changes_card && !ssl_is_const_card (sc, sp->sp_min_ssl, &sp->sp_cl.cl_sqt))
	    *cast_changes_card = 1;
	  n++;
	}
      if (sp->sp_max_ssl)
	{
	  if (cast_changes_card && !ssl_is_const_card (sc, sp->sp_max_ssl, &sp->sp_cl.cl_sqt))
	    *cast_changes_card = 1;
	  n++;
	}
    }
  if (all_eq && n_eq)
    *n_eq = n;
  return n;
}


int
ssl_is_const_card (sql_comp_t * sc, state_slot_t * ssl, sql_type_t * sqt)
{
  /* if the refd ssl is not nullable and cast will not filter */
  int quietcast = sc->sc_cc->cc_query->qr_no_cast_error;
  if (!ssl->ssl_sqt.sqt_non_null)
    return 0;
  if (!quietcast)
    return 1;
  return dtp_canonical[ssl->ssl_sqt.sqt_dtp] == dtp_canonical[sqt->sqt_dtp] || DV_ANY == sqt->sqt_dtp;
}


int
ssl_needs_vec_copy (sql_comp_t * sc, state_slot_t * ssl)
{
  /* is ssl assigned right before this node so that the sets match and there are no cardinality changing nodes between the use and the setting of the refd ssl */
  dk_set_t path = (dk_set_t) sqlg_vec_ssl_ref (sc, ssl, 1);
  return path != NULL;
}

void
ks_vec_local_code (sql_comp_t * sc, key_source_t * ks)
{

}


int
box_needs_cast (caddr_t box, sql_type_t * target_sqt)
{
  dtp_t dtp = DV_TYPE_OF (box);
  dtp_t target_dtp = target_sqt->sqt_dtp;
  if (IS_INT_DTP (dtp) && IS_INT_DTP (target_dtp))
    return 0;
  if (target_dtp == dtp)
    return 0;
  return 1;
}


void
sqlg_const_cast (sql_comp_t * sc, state_slot_t ** ssl_ret, sql_type_t * target_sqt)
{
  state_slot_t *ssl = *ssl_ret;
  caddr_t value;
  caddr_t err = NULL;
  dtp_t target_dtp = target_sqt->sqt_dtp;
  if (DV_ANY == target_dtp)
    {
      return;			/* any string make at run time */
      value = box_to_any (ssl->ssl_constant, &err);
    }
  else if (box_needs_cast (ssl->ssl_constant, target_sqt))
    value = box_cast_to (NULL, ssl->ssl_constant, DV_TYPE_OF (ssl->ssl_constant),
	target_dtp, target_sqt->sqt_precision, target_sqt->sqt_scale, &err);
  else
    return;
  if (err)
    {
      caddr_t st = ERR_STATE (err), msg = ERR_MESSAGE (err);
      dk_free_box (err);
      sqlc_new_error (sc->sc_cc, st, "VECDT", msg);
    }
  *ssl_ret = ssl_new_constant (sc->sc_cc, value);
  dk_free_tree (value);
}


caddr_t
ssl_cast_name (state_slot_t * ssl)
{
  if (SSL_REF == ssl->ssl_type)
    return ssl_cast_name (((state_slot_ref_t *) ssl)->sslr_ssl);
  return ssl->ssl_name ? ssl->ssl_name : "cast";
}


void
sqlg_vec_cast (sql_comp_t * sc, state_slot_ref_t ** refs, state_slot_t ** casts, dc_val_cast_t * val_cast, state_slot_t ** ssl_ret,
    int fill, state_slot_t ** card_ssl, sql_type_t * target_sqt, int copy_always)
{
  /* if need cast or can have nulls, or can have to mask in qi then this means that the vector for the itc is a different length than the input vector.  So must copy, maybe filtering maybe casting.  The ref is a ssl ref if there are many card changing steps to the original, else it is the original itself with ssl vec type */
  state_slot_t *ssl = *ssl_ret;
  state_slot_t *shadow = NULL;
  dc_val_cast_t f;
  state_slot_t col_ssl;
  if (SSL_CONSTANT != ssl->ssl_type)
    {
      shadow = (state_slot_t *) gethash ((void *) (ptrlong) ssl->ssl_index, sc->sc_vec_ssl_shadow);
      if (shadow)
	*ssl_ret = ssl = shadow;
    }
  if (SSL_CONSTANT == ssl->ssl_type)
    {
      sqlg_const_cast (sc, ssl_ret, target_sqt);
      return;
    }
  if (ssl->ssl_qr_global
      || (SSL_VEC != ssl->ssl_type && SSL_REF != ssl->ssl_type
	  && !gethash ((void *) (ptrlong) ssl->ssl_index, sc->sc_vec_ssl_shadow)))
    {
      /* can leave a non-vector ssl as is but check there is no shadow as this could be an out col that is replaced by equal search param */
      sqlg_all_branch_copy (sc, ssl);
      sqlg_branch_copy (sc, sc->sc_vec_current, ssl);
      if (sc->sc_vec_qf)
	sqlg_qf_scalar_param (sc, ssl);
      return;
    }
  refs[fill] = (state_slot_ref_t *) ssl;
  memset (&col_ssl, 0, sizeof (col_ssl));
  col_ssl.ssl_sqt = *target_sqt;
  if (col_ssl.ssl_sqt.sqt_col_dtp)
    col_ssl.ssl_sqt.sqt_dtp = col_ssl.ssl_sqt.sqt_col_dtp;
  col_ssl.ssl_sqt.sqt_non_null = 1;
  ssl_set_dc_type (&col_ssl);
  f = sqlg_dc_cast_func (sc, &col_ssl, ssl);
  if (copy_always || ssl_needs_vec_copy (sc, ssl))
    {
      char cname[100];
      snprintf (cname, sizeof (cname), "%s%s", sc->sc_vec_first_of_qf ? "q_" : "k_", ssl_cast_name (ssl));
      refs[fill] = sqlg_vec_ssl_ref (sc, ssl, 0);
      casts[fill] = ssl_new_vec (sc->sc_cc, cname, col_ssl.ssl_sqt.sqt_dtp);
      t_set_push (&sc->sc_ssl_prereset_only, (void *) casts[fill]);
      ASG_SSL_CAST (casts[fill], ssl);
      if (sc->sc_vec_first_of_qf)
	sethash ((void *) casts[fill], sc->sc_vec_ssl_def, (void *) sc->sc_vec_first_of_qf);	/* the qf/stn defines the cast slot, it is before the ks */
      casts[fill]->ssl_sqt = col_ssl.ssl_sqt;
      casts[fill]->ssl_sqt.sqt_non_null = 1;
      ssl_set_dc_type (casts[fill]);
      if (!*card_ssl)
	{
	  state_slot_t *ssl = casts[fill];
	  *card_ssl = ssl;
	  ssl->ssl_sets = cc_new_instance_slot (sc->sc_cc);
	  ssl->ssl_n_values = cc_new_instance_slot (sc->sc_cc);
	}
      *ssl_ret = casts[fill];
      val_cast[fill] = f;
      return;
    }
  if (SSL_IS_SCALAR (ssl))
    {
      sqlg_branch_copy (sc, sc->sc_vec_current, ssl);
      sqlg_all_branch_copy (sc, ssl);
      return;
    }
  if (!f && ssl->ssl_sqt.sqt_non_null && DV_ANY != ssl->ssl_dtp)
    {
      sqlg_branch_copy (sc, sc->sc_vec_current, ssl);
      return;
    }
  /* a copy is needed because cast or nulls can filter rows out */
  {
    state_slot_t *cast = ssl_new_vec (sc->sc_cc, "cast", target_sqt->sqt_dtp);
    casts[fill] = cast;
    casts[fill]->ssl_sqt = *target_sqt;
    val_cast[fill] = f;
    *ssl_ret = cast;
    ASG_SSL_CAST (cast, ssl);
    if (!*card_ssl)
      {
	*card_ssl = cast;
	cast->ssl_sets = cc_new_instance_slot (sc->sc_cc);
	cast->ssl_n_values = cc_new_instance_slot (sc->sc_cc);
      }
  }
}


dbe_column_t *
key_col_by_id (dbe_key_t * key, ptrlong id)
{
  DO_SET (dbe_column_t *, col, &key->key_parts)
  {
    if (col->col_id == id)
      return col;
  }
  END_DO_SET ();
  return NULL;
}


void
sqlg_vec_alt_ts (sql_comp_t * sc, table_source_t * ts)
{
  query_t *qr = sc->sc_vec_qr;
  data_source_t *pred, *en;
  table_source_t *a2;
  dk_set_t save_pred;
  int ign = 0;
  char save_outer = sc->sc_vec_in_outer;
  SQL_NODE_INIT (ts_split_node_t, tssp, ts_split_input, NULL);
  dk_set_delete (&sc->sc_cc->cc_query->qr_nodes, (void *) tssp);
  dk_set_ins_after (&qr->qr_nodes, (void *) ts, (void *) tssp);
  sc->sc_vec_in_outer = 1;	/* no tricks with aliasing cols and search paramm casts */
  tssp->tssp_alt_ts = ts->ts_alternate;
  ts->ts_alternate = NULL;
  tssp->src_gen.src_prev = (data_source_t *) sc->sc_vec_pred->data;
  tssp->src_gen.src_pre_code = ts->src_gen.src_pre_code;
  ts->src_gen.src_pre_code = NULL;
  sqlg_new_vec_ssls (sc, (data_source_t *) tssp);

  qr_replace_node (qr, (data_source_t *) ts, (data_source_t *) tssp, 0);
  tssp->src_gen.src_continuations = dk_set_cons ((void *) ts, NULL);
  pred = (data_source_t *) sc->sc_vec_pred->data;
  tssp->tssp_v1 = ts->ts_alternate_cd;
  t_set_push (&sc->sc_vec_pred, (void *) tssp);
  save_pred = sc->sc_vec_pred;
  tssp->tssp_alt_ts->src_gen.src_prev = (data_source_t *) tssp;
  tssp->src_gen.src_sets = cc_new_instance_slot (sc->sc_cc);
  tssp->src_gen.src_out_fill = cc_new_instance_slot (sc->sc_cc);
  sc->sc_vec_current = (data_source_t *) tssp->tssp_alt_ts;

  sqlg_vec_ts (sc, tssp->tssp_alt_ts);
  sqlg_vec_after_test (sc, (data_source_t *) tssp->tssp_alt_ts);
  tssp->tssp_alt_ts->src_gen.src_sets = cc_new_instance_slot (sc->sc_cc);
  tssp->tssp_alt_ts->src_gen.src_out_fill = cc_new_instance_slot (sc->sc_cc);
  t_set_push (&sc->sc_vec_pred, (void *) tssp->tssp_alt_ts);
  en = qn_next ((data_source_t *) tssp->tssp_alt_ts);
  en->src_prev = (data_source_t *) tssp->tssp_alt_ts;
  sc->sc_vec_current = en;
  qn_vec_slots (sc, en, NULL, NULL, &ign);
  t_set_push (&sc->sc_vec_pred, (void *) en);
  a2 = (table_source_t *) qn_next (qn_next ((data_source_t *) tssp->tssp_alt_ts));
  a2->src_gen.src_prev = en;
  a2->ts_order_ks->ks_is_last = 0;
  sc->sc_vec_current = (data_source_t *) a2;
  sqlg_vec_ts (sc, a2);
  sc->sc_vec_pred = save_pred;
  sc->sc_vec_current = (data_source_t *) ts;
  sqlg_vec_ts (sc, ts);
  a2->src_gen.src_out_fill = ts->src_gen.src_out_fill;
  a2->src_gen.src_sets = ts->src_gen.src_sets;
  sc->sc_vec_in_outer = save_outer;
}

dk_set_t
ssl_list_member (dk_set_t s, int inx)
{
  for (s = s; s; s = s->next)
    if (inx == ((state_slot_t *) s->data)->ssl_index)
      return s;
  return NULL;
}


caddr_t
sqlg_ts_sort_read_mask (table_source_t * ts)
{
  int k_inx = 0, inx;
  key_source_t *ks = ts->ts_order_ks;
  setp_node_t *setp = ks->ks_from_setp;
  int n_cols = BOX_ELEMENTS (setp->setp_keys_box) + BOX_ELEMENTS (setp->setp_dependent_box);
  caddr_t mask = dk_alloc_box_zero (n_cols, DV_BIN);
  DO_BOX (state_slot_t *, ssl, inx, setp->setp_keys_box)
  {
    if (ssl_list_member (ks->ks_out_slots, ssl->ssl_index))
      mask[k_inx] = 1;
    k_inx++;
  }
  END_DO_BOX;
  DO_BOX (state_slot_t *, ssl, inx, setp->setp_dependent_box)
  {
    if (ssl_list_member (ks->ks_out_slots, ssl->ssl_index))
      mask[k_inx] = 1;
    k_inx++;
  }
  END_DO_BOX;
  return mask;
}


void
sqlg_ts_qp_copy (sql_comp_t * sc, table_source_t * ts)
{
  state_slot_t *ign = NULL;
  dk_set_t steps = NULL;
  int inx, n_steps, fill;
  key_source_t *ks = ts->ts_order_ks;
  DO_BOX (state_slot_t *, ssl, inx, ks->ks_vec_cast)
    sqlg_branch_copy (sc, (data_source_t*)ts, ssl);
  END_DO_BOX;
  DO_SET (data_source_t *, qn, &sc->sc_vec_pred)
  {
    if (IS_QN (qn, query_frag_input) || IS_QN (qn, stage_node_input))
      break;
    qn_ssl_ref_steps (sc, qn, &steps, NULL, &ign);
  }
  END_DO_SET ();
  n_steps = dk_set_length (steps);
  ts->ts_branch_sets = (ssl_index_t *) dk_alloc_box (sizeof (ssl_index_t) * n_steps, DV_BIN);
  fill = 0;
  DO_SET (ptrlong, slot, &steps)
  {
    ts->ts_branch_sets[fill++] = slot;
  }
  END_DO_SET ();
}


caddr_t
box_concat (caddr_t b1, caddr_t b2)
{
  int l1 = box_length (b1), l2 = box_length (b2);
  int l = l1 + l2;
  caddr_t b = dk_alloc_box (l, box_tag (b1));
  memcpy (b, b1, l1);
  memcpy (b + l1, b2, l2);
  return b;
}

void
sqlg_ts_add_copy (sql_comp_t * sc, table_source_t * ts, state_slot_t ** ssls)
{
  state_slot_t **old = ts->ts_branch_ssls;
  if (!ssls)
    return;
  if (!old)
    ts->ts_branch_ssls = box_copy ((caddr_t) ssls);
  else
    {
      ts->ts_branch_ssls = (state_slot_t **) box_concat ((caddr_t) ts->ts_branch_ssls, (caddr_t) ssls);
      dk_free_box ((caddr_t) old);
    }
}

int enable_ks_out_alias = 0;

#define IS_DATE_DTP(dtp) \
  (DV_DATETIME == (dtp) || DV_DATE == (dtp) || DV_TIME == (dtp) || DV_TIMESTAMP == (dtp))


int
dtp_aliasable (dtp_t dtp)
{
  /* all bits participate in equlity */
  if (DV_ANY == dtp || IS_DATE_DTP (dtp))
    return 0;
  return 1;
}


int
sqlg_ks_any_col_typed (sql_comp_t * sc, key_source_t * ks, search_spec_t * eq_sp)
{
  /* true if an any type col is restricted by a like for type check or if it is compared by equality to a non-aliasable non-any */
  search_spec_t *sp;
  state_slot_t *org = (state_slot_t *) gethash ((void *) eq_sp->sp_min_ssl, sc->sc_vec_cast_ssls);
  if (org && dtp_aliasable (org->ssl_sqt.sqt_dtp))
    return 1;
  for (sp = ks->ks_row_spec; sp; sp = sp->sp_next)
    if (sp->sp_cl.cl_col_id == eq_sp->sp_cl.cl_col_id && BOP_LIKE == sp->sp_min_op)
      return 1;
  return 0;
}


void
sqlg_vec_ts_out_alias (sql_comp_t * sc, table_source_t * ts)
{
  /* find an out col that is joined with equality to a search param and set the param as shadow of the col, do not fetch the col.  Except if col is any or dt or ts right of left oj */
  int nth = 0;
  state_slot_t *out_ssl;
  key_source_t *ks = ts->ts_order_ks;
  if (!enable_ks_out_alias || sc->sc_vec_in_outer || !ks || ks->ks_from_temp_tree)
    return;
again:
  nth = -1;

  DO_SET (dbe_column_t *, col, &ks->ks_out_cols)
  {
    search_spec_t *eq = ks_find_eq_sp (ks, col->col_id);
    nth++;
    if (!eq)
      continue;
    if (IS_DATE_DTP (col->col_sqt.sqt_dtp))
      continue;
    if (DV_ANY == col->col_sqt.sqt_dtp && !sqlg_ks_any_col_typed (sc, ks, eq))
      continue;
    out_ssl = dk_set_nth (ks->ks_out_slots, nth);
    sethash ((void *) (ptrlong) out_ssl->ssl_index, sc->sc_vec_ssl_shadow, (void *) eq->sp_min_ssl);
    dk_set_delete (&ks->ks_out_slots, (void *) out_ssl);
    dk_set_delete (&ks->ks_out_cols, (void *) col);
    goto again;
  }
  END_DO_SET ();
}


void
sqlg_vec_ts (sql_comp_t * sc, table_source_t * ts)
{
  /* set the casts. Set the refs.  The defs are set at the end. */
  key_source_t *ks = ts->ts_order_ks;
  search_spec_t *sp;
  dk_set_t ssl_list = ks->ks_out_slots;
  int cast_changes_card = 0;
  int n_k_ssl = sp_ssl_count (sc, ks->ks_spec.ksp_spec_array, &ks->ks_n_vec_sort_cols, &cast_changes_card), ign = 0;
  int n_r_ssl = sp_ssl_count (sc, ks->ks_row_spec, NULL, &cast_changes_card);
  int fill = 0, inx = 0, n_out;
  if (ts->ts_alternate)
    {
      sqlg_vec_alt_ts (sc, ts);
      return;
    }
  ts->src_gen.src_batch_size = cc_new_instance_slot (sc->sc_cc);
  ks->ks_ts = ts;
  sc->sc_vec_first_of_qf = sqlg_qn_first_of (sc, (data_source_t *) ts);
  ASG_SSL (res, all_res, ts->ts_current_of);
  if (!ks->ks_is_qf_first)
    {
      ks->ks_vec_cast = (state_slot_t **) dk_alloc_box_zero (sizeof (caddr_t) * (n_r_ssl + n_k_ssl), DV_BIN);
      ks->ks_vec_source = (state_slot_ref_t **) dk_alloc_box_zero (sizeof (caddr_t) * (n_r_ssl + n_k_ssl), DV_BIN);
      ks->ks_dc_val_cast = (dc_val_cast_t *) dk_alloc_box_zero (sizeof (caddr_t) * (n_r_ssl + n_k_ssl), DV_BIN);
      for (sp = ks->ks_spec.ksp_spec_array; sp; sp = sp->sp_next)
	{
	  sc->sc_vec_current_col = sch_id_to_col (wi_inst.wi_schema, sp->sp_cl.cl_col_id);
	  if (sp->sp_min_ssl)
	    {
	      sqlg_vec_cast (sc, ks->ks_vec_source, ks->ks_vec_cast, ks->ks_dc_val_cast, &sp->sp_min_ssl, fill,
		  &ks->ks_last_vec_param, &sp->sp_cl.cl_sqt, cast_changes_card);
	      fill++;
	    }
	  if (sp->sp_max_ssl)
	    {
	      sqlg_vec_cast (sc, ks->ks_vec_source, ks->ks_vec_cast, ks->ks_dc_val_cast, &sp->sp_max_ssl, fill,
		  &ks->ks_last_vec_param, &sp->sp_cl.cl_sqt, cast_changes_card);
	      fill++;
	    }

	}
      for (sp = ks->ks_row_spec; sp; sp = sp->sp_next)
	{
	  sc->sc_vec_current_col = sch_id_to_col (wi_inst.wi_schema, sp->sp_cl.cl_col_id);
	  if (ks->ks_key->key_is_col)
	    {
	      dtp_t min_op = sp->sp_min_op, max_op = sp->sp_max_op;
	      if (!sp->sp_col_filter)
	    sp->sp_col_filter = col_find_op (CE_OP_CODE (sp->sp_min_op, sp->sp_max_op));
	      if (!sp->sp_col_filter && (CMP_GT == min_op || CMP_GTE == min_op || CMP_LT == max_op || CMP_LTE == max_op))
		sp->sp_col_filter = col_find_op (CE_ALL_LTGT);
	    }
	  if (sp->sp_min_ssl)
	    {
	      sql_type_t target_sqt = sp->sp_cl.cl_sqt;
	      if (ks->ks_key->key_is_col)
		target_sqt.sqt_dtp = target_sqt.sqt_col_dtp;
	      sqlg_vec_cast (sc, ks->ks_vec_source, ks->ks_vec_cast, ks->ks_dc_val_cast, &sp->sp_min_ssl, fill,
		  &ks->ks_last_vec_param, &target_sqt, cast_changes_card);
	      if (!ks->ks_first_row_vec_ssl && SSL_IS_VEC_OR_REF (sp->sp_min_ssl))
		ks->ks_first_row_vec_ssl = sp->sp_min_ssl;
	      fill++;
	    }
	  if (sp->sp_max_ssl)
	    {
	      sql_type_t target_sqt = sp->sp_cl.cl_sqt;
	      if (ks->ks_key->key_is_col)
		target_sqt.sqt_dtp = target_sqt.sqt_col_dtp;
	      sqlg_vec_cast (sc, ks->ks_vec_source, ks->ks_vec_cast, ks->ks_dc_val_cast, &sp->sp_max_ssl, fill,
		  &ks->ks_last_vec_param, &target_sqt, cast_changes_card);
	      if (!ks->ks_first_row_vec_ssl && SSL_IS_VEC_OR_REF (sp->sp_max_ssl))
		ks->ks_first_row_vec_ssl = sp->sp_max_ssl;
	      fill++;
	    }
	}
      sc->sc_vec_current_col = NULL;
    }
  sc->sc_vec_first_of_qf = NULL;
  sqlg_vec_ts_out_alias (sc, ts);
  n_out = dk_set_length (ks->ks_out_slots);
  ks->ks_v_out_map = (v_out_map_t *) dk_alloc_box_zero (n_out * sizeof (v_out_map_t), DV_BIN);
  ssl_list = ks->ks_out_slots;
  inx = 0;
  if (ks->ks_is_proc_view)
    ks->ks_out_cols = dk_set_copy (ks->ks_key->key_parts);
  DO_SET (dbe_column_t *, col, &ks->ks_out_cols)
  {
    state_slot_t *ssl = (state_slot_t *) ssl_list->data, *shadow;
    oid_t col_id = IS_BOX_POINTER (col) ? col->col_id : (oid_t) (ptrlong) col;
    if (ssl->ssl_alias_of)
      ssl = ssl->ssl_alias_of;
    shadow = (state_slot_t *) gethash ((void *) (ptrlong) ssl->ssl_index, sc->sc_vec_ssl_shadow);
    if (shadow)
      ssl_list->data = (void *) (ssl = shadow);
    if (!IS_BOX_POINTER (col))
      col = key_col_by_id (ks->ks_key, (ptrlong) col);
    ssl_list = ssl_list->next;
    if (!ks->ks_is_last || ks->ks_key->key_is_col)
      {
	if (ks->ks_key->key_bit_cl && col_id == ks->ks_key->key_bit_cl->cl_col_id)
	  ks->ks_v_out_map[inx].om_is_null = OM_BM_COL;
	else if (CI_ROW == col_id)
	  {
	    if (ks->ks_key->key_is_col)
	      sqlc_new_error (sc->sc_cc, "37000", "COL..", "Can't select _row from a column-wise key");
	    ks->ks_v_out_map[inx].om_ref = dc_itc_append_row;
	    ssl->ssl_dtp = DV_ARRAY_OF_POINTER;
	  }
	else if (ks->ks_key->key_is_col)
	  {
	    ks->ks_v_out_map[inx].om_cl = *cl_list_find (ks->ks_key->key_row_var, col_id);
	    ks->ks_v_out_map[inx].om_ce_op = col_find_op (CE_DECODE);
	  }
	else
	  ks->ks_v_out_map[inx].om_cl = *key_find_cl (ks->ks_key, col_id);
	ks->ks_v_out_map[inx].om_ssl = ssl;
	if (col)
	  ks->ks_v_out_map[inx].om_ref = col_ref_func (ks->ks_key, col, ks->ks_v_out_map[inx].om_ssl);
	ssl->ssl_type = SSL_VEC;
	if (!ssl->ssl_box_index)
	  ssl->ssl_box_index = cc_new_instance_slot (sc->sc_cc);
	ssl_set_dc_type (ssl);
      }
    ASG_SSL (NULL, NULL, ssl);
    t_set_delete (&sc->sc_ssl_prereset_only, (void *) ssl);	/* in a proc view the row ctr is assigned first in precode and then in the ts, must be in the continue reset list, else will overflow */
    inx++;
  }
  END_DO_SET ();
  if (ks->ks_vec_cast)
    {
      int inx;
      DO_BOX (state_slot_t *, ssl, inx, ks->ks_vec_cast)
      {
	if (ssl)
	  sethash ((void *) (ptrlong) ssl->ssl_index, sc->sc_vec_last_ref, (void *) ts);
      }
      END_DO_BOX;
    }
  if (ks->ks_key->key_is_col)
    ks->ks_row_check = itc_col_row_check_dummy;
  else if (!ks->ks_is_last)
    ks->ks_row_check = ks->ks_key->key_is_bitmap ? itc_bm_vec_row_check : itc_vec_row_check;
  ks->ks_param_nos = cc_new_instance_slot (sc->sc_cc);
  DO_SET (state_slot_t *, ssl, &ks->ks_always_null)
    ASG_SSL (NULL, NULL, ssl); /* when reading grouping sets with not all groupnig cols, some are filled in as null on all rows */
  END_DO_SET ();
  t_set_push (&sc->sc_vec_pred, (void *) ts);
  cv_vec_slots (sc, ks->ks_local_test, NULL, NULL, &ign);
  if (ks->ks_local_code && !ks->ks_is_last)
    {
      ks->ks_ts->src_gen.src_after_code = ks->ks_local_code;
      ks->ks_local_code = NULL;
    }
  else
    {
      ign = VEC_SINGLE_STATE;
      cv_vec_slots (sc, ks->ks_local_code, NULL, NULL, &ign);
      sqlg_new_vec_ssls (sc, &ks->ks_ts->src_gen);
    }

  sc->sc_vec_pred = sc->sc_vec_pred->next;
  sqlg_ts_qp_copy (sc, ts);
  REF_SSL (res, ks->ks_set_no);
  if (IS_QN (ts, sort_read_input))
    {
      ts->clb.clb_nth_set = cc_new_instance_slot (sc->sc_cc);
      ts->ts_sort_read_mask = sqlg_ts_sort_read_mask (ts);
    }
}


void
sqs_set_fref_hash_fill_deps (sql_comp_t * sc, subq_source_t * sqs, hash_source_t * hs)
{
  fun_ref_node_t *filler = hs->hs_filler;
  DO_SET (fun_ref_node_t *, fref, &sqs->sqs_query->qr_nodes)
  {
    if (IS_QN (fref, fun_ref_node_input))
      dk_set_pushnew (&fref->fnr_prev_hash_fillers, (void *) filler);
  }
  END_DO_SET ();
}


void
sqlg_fnr_prev_hash_fillers (sql_comp_t * sc, fun_ref_node_t * fref)
{
  /* a fref can be preceded by hash fillers.  If these are going to make more partitions, the fref will not send its output.  This applies only to fillers immediately preceding the fref at the same level of subq
   * so check that the filler in question is in the same qr as the fref.  Also allow the rdf pattern of select exps from a single dt with gb/oby/agg */
  DO_SET (data_source_t *, filler, &sc->sc_hash_fillers)
  {
    if (filler->src_query == fref->src_gen.src_query)
      {
	dk_set_push (&fref->fnr_prev_hash_fillers, (void *) filler);
	goto next_filler;
      }
#if 0
    for (succ = qn_next (filler); succ; succ = qn_next (succ))
      {
	if (succ == (data_source_t *) fref)
	  {
	    dk_set_push (&fref->fnr_prev_hash_fillers, (void *) filler);
	    goto next_filler;
	  }
      }
#endif
  next_filler:;
  }
  END_DO_SET ();
}


void
sqlg_cl_setp_reader (sql_comp_t * sc, fun_ref_node_t * fref)
{
  setp_node_t *setp = fref->fnr_setp;
  table_source_t *reader = (table_source_t *) qn_next ((data_source_t *) fref);
  if (!(IS_TS (reader) || IS_QN (reader, chash_read_input) || IS_QN (reader, sort_read_input)))
    sqlc_new_error (sc->sc_cc, "CLVEC", "CLVEC", "grouping sets in cluster not supported");
  setp->setp_reader = reader;
  setp->setp_qfs_state = cc_new_instance_slot (sc->sc_cc);
}


void
sqlg_const_card_ssl_defs (sql_comp_t * sc, data_source_t * qn)
{
  /* a node that  is constant cardinality is invisible for purposes of ssl ref.  So ssls that are assigned in a node like that 
   * are not found to be assigned because a const card node does not figire in sc_vec_pred.  So move them so they are assigned in the previous non const card node */
  data_source_t * prev = sc->sc_vec_pred ? (data_source_t*)sc->sc_vec_pred->data : NULL;
  dk_set_t ssls = NULL;
  DO_HT (state_slot_t *, ssl, data_source_t *, defd, sc->sc_vec_ssl_def)
    {
      if (defd == qn)
	t_set_push (&ssls, (void*)ssl);
    }
  END_DO_HT;
  DO_SET (state_slot_t *, ssl, &ssls)
    {
      sethash ((void*)ssl, sc->sc_vec_ssl_def, (void*)prev);
    }
  END_DO_SET();
}


void
sqlg_vec_qns (sql_comp_t * sc, data_source_t * qn, dk_set_t prev_nodes)
{
  int ign = 0;
  data_source_t *prev;
  int is_first = 1;
  for (qn = qn; qn; qn = qn_next (qn))
    {
      if (IS_QN (qn, fun_ref_node_input) || IS_QN (qn, hash_fill_node_input))
	{
	  dk_hash_t *shadow_save = NULL;
	  QNCAST (fun_ref_node_t, fref, qn);
	  qn->src_batch_size = cc_new_instance_slot (sc->sc_cc);
	  sc->sc_pre_code_of = qn;
	  cv_vec_slots (sc, qn->src_pre_code, NULL, NULL, &ign);
	  sc->sc_pre_code_of = NULL;
	  sqlg_new_vec_ssls (sc, qn);
	  if (IS_QN (fref, hash_fill_node_input))
	    {
	      ASG_SSL (NULL, NULL, fref->fnr_setp->setp_ht_id);
	      shadow_save = hash_table_allocate (sc->sc_vec_ssl_shadow->ht_actual_size);
	      dk_hash_copy (shadow_save, sc->sc_vec_ssl_shadow);
	    }
	  sqlg_vec_qns (sc, fref->fnr_select, prev_nodes);
	  sc->sc_vec_current = qn;
	  if (fref->fnr_cl_qf && fref->fnr_temp_slots)
	    {
	      dk_set_t mrg = NULL;
	      DO_SET (state_slot_t *, ssl, &fref->fnr_temp_slots)
		  dk_set_push (&mrg, (void *) ssl_new_vec (sc->sc_cc, "mrg_temp", ssl->ssl_sqt.sqt_dtp));
	      END_DO_SET ();
	      fref->fnr_cl_merge_temps = dk_set_nreverse (mrg);
	    }
	  if (fref->fnr_cl_qf && !fref->fnr_temp_slots && fref->fnr_setp && !fref->fnr_setp->setp_partitioned)
	    sqlg_cl_setp_reader (sc, fref);
	  DO_SET (state_slot_t *, ssl, &fref->fnr_default_ssls)
	  {
	    state_slot_t *sh = SSL_SHADOW (ssl);
	    ASG_SSL (NULL, NULL, ssl);
	    dk_set_delete (&fref->fnr_temp_slots, (void *) ssl);
	    if (sh)
	      ASG_SSL (NULL, NULL, sh);
	  }
	  END_DO_SET ();
	  if (IS_QN (fref, hash_fill_node_input))
	    {
	    t_set_push (&sc->sc_hash_fillers, (void *) fref);
	      hash_table_free (sc->sc_vec_ssl_shadow);
	      sc->sc_vec_ssl_shadow = shadow_save;
	    }
	  if (IS_QN (fref, fun_ref_node_input))
	    sqlg_fnr_prev_hash_fillers (sc, fref);
	}
      if (is_first)
	is_first = 0;
      else
	{
	  prev = qn;
	}
      sc->sc_vec_pred = prev_nodes;
      qn_vec_slots (sc, qn, NULL, NULL, &ign);
      qn->src_prev = prev_nodes ? (data_source_t*)prev_nodes->data : NULL;
      if (qn_is_const_card (qn))
	{
	  sqlg_const_card_ssl_defs (sc, qn);
	  continue;
	}
      if (IS_QN (qn, outer_seq_end_input))
	prev_nodes = sc->sc_vec_pred;
      if (IS_QN (qn, gs_union_node_input))
	qn = qn_next (qn);
      t_set_push (&prev_nodes, (void *) qn);
      sc->sc_vec_pred = prev_nodes;
    }
}

int
ssl_array_member (state_slot_t ** ssls, ssl_index_t ssl_inx)
{
  int inx;
  DO_BOX (state_slot_t *, ssl, inx, ssls)
    if (ssl_inx == ssl->ssl_index)
    return inx;
  END_DO_BOX;
  return -1;
}

void
qn_add_reuse (data_source_t * qn, ssl_index_t * steps, int fill)
{
  ssl_index_t *reuse;
  int prev_len = 0;
  if (qn->src_vec_reuse)
    prev_len = box_length (qn->src_vec_reuse);
  reuse = (ssl_index_t *) dk_alloc_box ((fill * sizeof (ssl_index_t)) + prev_len, DV_BIN);
  if (prev_len)
    memcpy (reuse, qn->src_vec_reuse, prev_len);
  steps[1] = fill - 2;
  memcpy ((char *) reuse + prev_len, steps, fill * sizeof (ssl_index_t));
  dk_free_box (qn->src_vec_reuse);
  qn->src_vec_reuse = reuse;
}


state_slot_t **
qn_continue_reset (data_source_t * qn)
{
  if (IS_QN (qn, stage_node_input))
    return ((stage_node_t *) qn)->stn_inner_params;
  return qn->src_continue_reset;
}

state_slot_t *
ssl_by_index (sql_comp_t * sc, int inx)
{
  DO_HT (state_slot_t *, ssl, void *, igm, sc->sc_vec_ssl_def)
  {
    if (inx == ssl->ssl_index)
      return ssl;
  }
  END_DO_HT;
  return NULL;
}



void
sqlg_vec_set_reuse (sql_comp_t * sc)
{
  state_slot_t *ssl;
  DO_HT (ptrlong, ssl_inx, data_source_t *, last_ref, sc->sc_vec_last_ref)
  {
    data_source_t *prev;
    int fill = 2;
    ssl_index_t steps[200];
    steps[0] = ssl_inx;
    for (prev = last_ref->src_prev; prev; prev = prev->src_prev)
      {
	if (-1 != ssl_array_member (qn_continue_reset (prev), ssl_inx))
	  {
	    qn_add_reuse (last_ref, steps, fill);
	    goto next;
	  }
	steps[fill++] = prev->src_in_state;
	if (fill > 100)
	  goto next;
	if (-1 != ssl_array_member (prev->src_pre_reset, ssl_inx))
	  {
	    qn_add_reuse (last_ref, steps, fill);
	    goto next;
	  }
      }
    ssl = ssl_by_index (sc, ssl_inx);
    if (last_ref->src_prev == (data_source_t *) gethash (ssl, sc->sc_vec_ssl_def))
      {
	steps[2] = last_ref->src_in_state;
	qn_add_reuse (last_ref, steps, 3);
	goto next;
      }

  next:;
  }
  END_DO_HT;
  hash_table_free (sc->sc_vec_last_ref);
  sc->sc_vec_last_ref = NULL;
}


void
sqlg_vector_subq (sql_comp_t * sc)
{
  query_t *qr = sc->sc_cc->cc_query;
  qr->qr_vec_opt_done = 1;
  sc->sc_vec_pred = NULL;
  sc->sc_vec_ssl_def = hash_table_allocate (31);
  sc->sc_vec_ssl_shadow = hash_table_allocate (31);
  sc->sc_vec_last_ref = hash_table_allocate (31);
  sc->sc_vec_no_copy_ssls = hash_table_allocate (11);
  sc->sc_vec_cast_ssls = hash_table_allocate (31);
  qr_no_copy_ssls (qr, sc->sc_vec_no_copy_ssls);
  sc->sc_vec_qr = qr;
  sqlg_vec_first_pre_code (sc, qr);
  sqlg_vec_qns (sc, qr->qr_head_node, NULL);
  sqlg_vec_set_reuse (sc);
  hash_table_free (sc->sc_vec_ssl_def);
  hash_table_free (sc->sc_vec_ssl_shadow);
  hash_table_free (sc->sc_vec_no_copy_ssls);
  hash_table_free (sc->sc_vec_cast_ssls);
  if (sc->sc_vec_prov_cast)
    hash_table_free (sc->sc_vec_prov_cast);
  sc->sc_vec_ssl_shadow = NULL;
  sc->sc_vec_ssl_def = NULL;
  sc->sc_vec_no_copy_ssls = NULL;
  sc->sc_vec_cast_ssls = NULL;
  sc->sc_cc->cc_super_cc->cc_has_vec_subq = 1;
  sc->sc_vec_prov_cast = NULL;
}


void
sqlg_vector_params (sql_comp_t * sc, query_t * qr)
{
  DO_SET (state_slot_t *, ssl, &qr->qr_parms)
  {
    if (SSL_VEC == ssl->ssl_type)
      return;			/* do not do this twice */
    if (SSL_PARAMETER == ssl->ssl_type)
      ssl->ssl_vec_param = 1;
    ssl->ssl_type = SSL_VEC;
    ssl->ssl_box_index = cc_new_instance_slot (sc->sc_cc);
    if (DV_STRING == ssl->ssl_sqt.sqt_dtp || DV_WIDE == ssl->ssl_sqt.sqt_dtp || DV_UNKNOWN == ssl->ssl_sqt.sqt_dtp
	|| DV_ANY == ssl->ssl_sqt.sqt_dtp || DV_BIN == ssl->ssl_sqt.sqt_dtp)
      {
	ssl->ssl_dtp = DV_ARRAY_OF_POINTER;
	ssl->ssl_dc_dtp = 0;
	ssl_set_dc_type (ssl);
	ssl->ssl_dtp = DV_ANY;
      }
  }
  END_DO_SET ();
  if (qr->qr_parm_default)
    {
      int inx;
      DO_BOX (caddr_t, def, inx, qr->qr_parm_default)
	qr->qr_parm_default[inx] = (caddr_t)ssl_new_constant (sc->sc_cc, def);
      END_DO_BOX;
    }
}


void
qr_set_vec_ssls (query_t * qr)
{
  dk_set_t ssls = NULL;
  DO_SET (state_slot_t *, ssl, &qr->qr_state_map)
  {
    if (SSL_VEC == ssl->ssl_type && !ssl->ssl_alias_of)
      dk_set_push (&ssls, (void *) ssl);
  }
  END_DO_SET ();
  DO_SET (state_slot_t *, ssl, &qr->qr_temp_spaces)
  {
    if (SSL_VEC == ssl->ssl_type)
      dk_set_push (&ssls, (void *) ssl);
  }
  END_DO_SET ();
  qr->qr_vec_ssls = (state_slot_t **) list_to_array (ssls);

}

void
sqlg_vector (sql_comp_t * sc, query_t * qr)
{
  sc->sc_vec_pred = NULL;
  if (qr->qr_proc_vectored)
    {
      sqlg_vector_params (sc, qr);
      sqlg_vector_subq (sc);
    }
  qr_set_vec_ssls (qr);
}
