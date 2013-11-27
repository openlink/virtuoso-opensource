/*
 *  eqlcomp.c
 *
 *  $Id$
 *
 *  SQL Query Node Constructors.
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

/*
   04-FEB-1997 AK  Added a macro definition colname_or_null as
   given before, and used it in few times, as to avoid
   GPF's in Unix.
 */

#define colname_or_null(N) ((N) ? (N) : ("*NO_NAME*"))

#include "sqlnode.h"
#include "eqlcomp.h"
#include "lisprdr.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "security.h"
#include "sqlpfn.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "libutil.h"
#include "sqlcstate.h"
#include "sqlo.h"
#include "list2.h"
#include "xmlnode.h"
#include "xmltree.h"
#include "arith.h"
#include "rdfinf.h"
#include "ssl.c"

/* #define USE_SYS_CONSTANT */


int
cc_new_instance_slot (comp_context_t * cc)
{
  cc = cc->cc_super_cc;
  if (cc->cc_instance_fill > 0xfffe)
    GPF_T1 ("qi with over 64K state slots.");
  return (cc->cc_instance_fill++);
}


void
ssl_free (state_slot_t * ssl)
{
  if (ssl->ssl_not_freeable)
    return;
  if (SSL_CONSTANT == ssl->ssl_type)
    {
      dk_free_tree (((state_const_slot_t *) ssl)->ssl_const_val);
      dk_free ((caddr_t) ssl, sizeof (state_const_slot_t));
    }
  else if (SSL_REF == ssl->ssl_type)
    {
      QNCAST (state_slot_ref_t, sslr, ssl);
      dk_free ((caddr_t)sslr->sslr_set_nos, sslr->sslr_distance * sizeof (ssl_index_t));
      dk_free ((caddr_t) ssl, sizeof (state_slot_ref_t));
    }
  else
    {
      dk_free_box (ssl->ssl_name);
    dk_free ((caddr_t) ssl, sizeof (state_slot_t));
}
}


void
sp_list_free (dk_set_t sps)
{
  DO_SET (search_spec_t *, sp, &sps)
    {
      if (CMP_HASH_RANGE == sp->sp_min_op)
	{
	  QNCAST (hash_range_spec_t, hrng, sp->sp_min_ssl);
	  dk_free_box ((caddr_t)hrng->hrng_ssls);
	  dk_free ((caddr_t)sp->sp_min_ssl, sizeof (hash_range_spec_t));
	}
      dk_free ((caddr_t)sp, sizeof (search_spec_t));
    }
  END_DO_SET();
  dk_set_free (sps);
}


static dependence_def_t *tb_name_to_qr_dep = NULL;
static dependence_def_t *udt_name_to_qr_dep = NULL;
static dependence_def_t *jso_iri_to_qr_dep = NULL;

#define ALLOC_DEPS	\
  if (!tb_name_to_qr_dep) \
    { \
      tb_name_to_qr_dep = dependence_def_new (101); \
      udt_name_to_qr_dep = dependence_def_new (101); \
      jso_iri_to_qr_dep = dependence_def_new (101); \
    }


/*
id_hash_t * tb_name_to_qr_dep, * udt_name_to_qr_dep;
dk_mutex_t * qr_dep_mtx, * qr_type_dep_mtx;
*/

static int
qr_add_used_object (query_t *qr, const char *tb, dependent_t *dep)
{
  caddr_t new_tb;
  DO_SET (char *, ctb, (dk_set_t *) dep)
    {
      if (!CASEMODESTRCMP (tb, ctb))
	return 0;
    }
  END_DO_SET ();

  new_tb = box_string (tb);
  dk_set_push ((dk_set_t *) dep, new_tb);
  return 1;
}


dependence_def_t *
dependence_def_new (int sz)
{
  NEW_VARZ (dependence_def_t, ddep);
  ddep->ddef_name_to_qr = id_str_hash_create (sz);
  ddep->ddef_mtx = mutex_allocate ();
  return ddep;
}


void
qr_uses_object (query_t * qr, const char *tb, dependent_t *dep, dependence_def_t *ddef)
{
  dk_set_t *place;
  if (!qr)
    return;
  if (!qr_add_used_object (qr, tb, dep))
    return;
  mutex_enter (ddef->ddef_mtx);
  place = (dk_set_t *) id_hash_get (ddef->ddef_name_to_qr, (caddr_t) & tb);
  if (place)
    dk_set_push (place, (void *) qr);
  else
    {
      caddr_t tb_copy = box_string (tb);
      dk_set_t lst = dk_set_cons (qr, NULL);
      id_hash_set (ddef->ddef_name_to_qr, (caddr_t) & tb_copy, (caddr_t) & lst);
    }
  mutex_leave (ddef->ddef_mtx);
}


void
qr_uses_table (query_t * qr, const char *tb)
{
  ALLOC_DEPS;
  qr_uses_object (qr, tb, &qr->qr_used_tables, tb_name_to_qr_dep);
}


void
object_mark_affected (const char *tb, dependence_def_t *ddef, int force_text_reparsing)
{
  dk_set_t *place;
  mutex_enter (ddef->ddef_mtx);
  place = (dk_set_t *) id_hash_get (ddef->ddef_name_to_qr, (char *) &tb);
  if (place)
    {
      DO_SET (query_t *, aqr, place)
	{
          if (force_text_reparsing)
            aqr->qr_parse_tree_to_reparse = 1;
	  aqr->qr_to_recompile = 1;
	}
      END_DO_SET ();
    }
  mutex_leave (ddef->ddef_mtx);
}


void
tb_mark_affected (const char *tb)
{
  ALLOC_DEPS;
  object_mark_affected (tb, tb_name_to_qr_dep, 0);
}


void
qr_drop_obj_dependencies (query_t *qr, dependent_t *dep, dependence_def_t *ddef)
{
  dk_set_t *lp;

  mutex_enter (ddef->ddef_mtx);
  DO_SET (char *, atb, dep)
    {
      lp = (dk_set_t *) id_hash_get (ddef->ddef_name_to_qr, (caddr_t) &atb);
      dk_set_delete (lp, (void *) qr);
    }
  END_DO_SET ();
  mutex_leave (ddef->ddef_mtx);
}


void
qr_drop_dependencies (query_t * qr)
{
  ALLOC_DEPS;
  qr_drop_obj_dependencies (qr, &qr->qr_used_tables, tb_name_to_qr_dep);
  qr_drop_obj_dependencies (qr, &qr->qr_used_udts, udt_name_to_qr_dep);
  qr_drop_obj_dependencies (qr, &qr->qr_used_jsos, jso_iri_to_qr_dep);
}


void
udt_mark_affected (const char *tb)
{
  ALLOC_DEPS;
  object_mark_affected (tb, udt_name_to_qr_dep, 0);
}

void
jso_mark_affected (const char *jso_inst)
{
  ALLOC_DEPS;
  object_mark_affected (jso_inst, jso_iri_to_qr_dep, 1);
}


void
qr_uses_type (query_t * qr, const char *udt)
{
  ALLOC_DEPS;
  qr_uses_object (qr, udt, &qr->qr_used_udts, udt_name_to_qr_dep);
}

void
qr_uses_jso (query_t * qr, const char *jso_iri)
{
  ALLOC_DEPS;
  qr_uses_object (qr, jso_iri, &qr->qr_used_jsos, jso_iri_to_qr_dep);
}

int
object_is_qr_used (char *name, dependence_def_t *ddef)
{
  dk_set_t *place;
  int ret = 0;
  mutex_enter (ddef->ddef_mtx);
  place = (dk_set_t *) id_hash_get (ddef->ddef_name_to_qr, (caddr_t) & name);
  if (place)
    ret = 1;
  mutex_leave (ddef->ddef_mtx);
  return ret;
}


int
udt_is_qr_used (char *name)
{
  ALLOC_DEPS;
  return object_is_qr_used (name, udt_name_to_qr_dep);
}


#define QNSZ(f, t) if (IS_QN (qn, f)) return sizeof (t);


int
qn_size (data_source_t * qn)
{
  QNSZ (table_source_input, table_source_t);
  QNSZ (table_source_input_unique, table_source_t);
  QNSZ (chash_read_input, table_source_t);
  QNSZ (sort_read_input, table_source_t);
  QNSZ (set_ctr_input, set_ctr_node_t);
  QNSZ (setp_node_input, setp_node_t);
  QNSZ (fun_ref_node_input, fun_ref_node_t);
  QNSZ (hash_fill_node_input, fun_ref_node_t);
  QNSZ (end_node_input, end_node_t);
  QNSZ (select_node_input, select_node_t);
  QNSZ (table_source_input, table_source_t);
  QNSZ (table_source_input_unique, table_source_t);
  QNSZ (chash_read_input, table_source_t);
  QNSZ (sort_read_input, table_source_t);
  QNSZ (set_ctr_input, set_ctr_node_t);
  QNSZ (setp_node_input, setp_node_t);
  QNSZ (fun_ref_node_input, fun_ref_node_t);
  QNSZ (hash_fill_node_input, fun_ref_node_t);
  QNSZ (end_node_input, end_node_t);
  QNSZ (select_node_input, select_node_t);
  QNSZ (select_node_input_subq, select_node_t);
  QNSZ (table_source_input, table_source_t);
  QNSZ (table_source_input_unique, table_source_t);
  QNSZ (chash_read_input, table_source_t);
  QNSZ (sort_read_input, table_source_t);
  QNSZ (set_ctr_input, set_ctr_node_t);
  QNSZ (outer_seq_end_input, outer_seq_end_node_t);
  QNSZ (setp_node_input, setp_node_t);
  QNSZ (fun_ref_node_input, fun_ref_node_t);
  QNSZ (hash_fill_node_input, fun_ref_node_t);
  QNSZ (end_node_input, end_node_t);
  QNSZ (hash_source_input, hash_source_t);
  QNSZ (subq_node_input, subq_source_t);
  QNSZ (union_node_input, union_node_t);
  QNSZ (gs_union_node_input, gs_union_node_t);
  QNSZ (insert_node_input, insert_node_t);
  QNSZ (delete_node_input, delete_node_t);
  QNSZ (update_node_input, update_node_t);
  QNSZ (trans_node_input, trans_node_t);
  QNSZ (in_iter_input, in_iter_node_t);
  QNSZ (rdf_inf_pre_input , rdf_inf_pre_node_t);
  QNSZ (skip_node_input, skip_node_t);
  QNSZ (ddl_node_input, ddl_node_t);
  QNSZ (op_node_input, op_node_t);
  QNSZ (breakup_node_input, breakup_node_t);
  return -1;
}


void
dsr_free (data_source_t * x)
{
  cv_free (x->src_pre_code);
  cv_free (x->src_after_test);
  cv_free (x->src_after_code);
  dk_set_free (x->src_continuations);
  dk_free_box ((caddr_t)x->src_pre_reset);
  dk_free_box ((caddr_t)x->src_continue_reset);
  dk_free_box ((caddr_t)x->src_vec_reuse);
  dk_free ((caddr_t) x, qn_size (x));
}

void
qn_free (data_source_t * qn)
{
  if (!qn)
    return;
  if (qn->src_free)
    qn->src_free (qn);
  dsr_free (qn);
}


void
qr_garbage (query_t * qr, caddr_t garbage)
{
  mutex_enter (time_mtx);
  dk_set_pushnew (&qr->qr_unrefd_data, (void*) garbage);
  mutex_leave (time_mtx);
}




void
kpd_free (key_partition_def_t * kpd)
{
  int inx;
  if (!kpd)
    return;
  DO_BOX (col_partition_t *, cp, inx, kpd->kpd_cols)
    {
      dk_free ((caddr_t)cp, sizeof (col_partition_t));
    }
  END_DO_BOX;
  dk_free_box ((caddr_t)kpd->kpd_cols);
  dk_free ((caddr_t)kpd, sizeof (key_partition_def_t));
}


void
qr_free (query_t * qr)
{
  if (!qr)
    return;
  if (!qr->qr_qf_id && !qr->qr_super)
    {
      /* a local qr has parallel branches.  If going, let the last of them free the qr */
      IN_CLL;
      if (qr->qr_ref_count)
	{
	  qr->qr_last_qi_may_free = 1;
	  LEAVE_CLL;
	  return;
	}
      LEAVE_CLL;
    }
  qr_drop_dependencies (qr);
  while (NULL != qr->qr_used_tables) dk_free_tree (dk_set_pop (&(qr->qr_used_tables)));
  while (NULL != qr->qr_used_udts) dk_free_tree (dk_set_pop (&(qr->qr_used_udts)));
  while (NULL != qr->qr_used_jsos) dk_free_tree (dk_set_pop (&(qr->qr_used_jsos)));
  dk_free_tree (qr->qr_parse_tree);
  DO_SET (data_source_t *, sr, &qr->qr_nodes)
  {
    if (sr->src_free)
      sr->src_free (sr);
    dsr_free (sr);
  }
  END_DO_SET ();
  dk_set_free (qr->qr_nodes);
  DO_SET (query_t *, sub_qr, &qr->qr_subq_queries)
  {
    qr_free (sub_qr);
  }
  END_DO_SET ();
  dk_set_free (qr->qr_subq_queries);
  dk_set_free (qr->qr_bunion_reset_nodes);

  DO_SET (state_slot_t *, ssl, &qr->qr_state_map)
  {
    ssl_free (ssl);
  }
  END_DO_SET ();
  dk_set_free (qr->qr_state_map);
  DO_SET (state_slot_t *, ssl, &qr->qr_temp_spaces)
  {
    ssl_free (ssl);
  }
  END_DO_SET ();
  DO_SET (state_slot_t *, ssl, &qr->qr_ssl_refs)
  {
    ssl_free (ssl);
  }
  END_DO_SET ();
  dk_set_free (qr->qr_ssl_refs);

  {
    state_const_slot_t * ssl = qr->qr_const_ssls, *nxt;
    while (ssl)
      {
	nxt = ssl->ssl_next_const;
	dk_free_tree (ssl->ssl_const_val);
	dk_free ((void*) ssl, sizeof (state_const_slot_t));
	ssl = nxt;
      }
  }
  dk_set_free (qr->qr_temp_spaces);

  dk_set_free (qr->qr_parms);
  DO_SET (caddr_t, cr, &qr->qr_used_cursors)
  {
    dk_free_box (cr);
  }
  END_DO_SET ();
  dk_set_free (qr->qr_used_cursors);
  dk_free_box (qr->qr_qualifier);
  dk_free_box (qr->qr_owner);
  if (qr->qr_cursor)
    qc_free (qr->qr_cursor);
  if (qr->qr_unrefd_data)
    dk_free_tree ((caddr_t) list_to_array (qr->qr_unrefd_data));
  if (qr->qr_proc_result_cols)
    dk_free_tree ((caddr_t) list_to_array (qr->qr_proc_result_cols));
  dk_free_box ((caddr_t) qr->qr_freeable_slots);
  dk_free_box ((caddr_t) qr->qr_qp_copy_ssls);
  DO_SET (dbe_key_t *, tkey, &qr->qr_temp_keys)
    {
      kpd_free (tkey->key_partition);
      dbe_key_free (tkey);
    }
  END_DO_SET();
  dk_set_free (qr->qr_temp_keys);
#ifndef ROLLBACK_XQ
  dk_free_tree ((box_t) qr->qr_xp_temp);
#endif
  if (qr->qr_proc_vectored)
    dk_free_box ((box_t) qr->qr_parm_default);
  else
  dk_free_tree ((box_t) qr->qr_parm_default);
  dk_free_tree ((box_t) qr->qr_parm_alt_types);
  dk_free_tree ((box_t) qr->qr_parm_place);
  dk_free_tree ((box_t) qr->qr_parm_soap_opts);
  if (NULL != qr->qr_proc_name)
    {
      dk_free_tree (qr->qr_proc_name);
      dk_free_tree (qr->qr_proc_ret_type);
      dk_free_box (qr->qr_trig_table);
      dk_free_box ((box_t) qr->qr_trig_upd_cols);
      if (qr->qr_pn) qr->qr_pn->pn_query = NULL;
      proc_name_free (qr->qr_pn);
    }
  dk_free_box ((caddr_t) qr->qr_proc_cost);
  dk_free_box ((caddr_t)qr->qr_qf_params);
  dk_free_box ((caddr_t)qr->qr_qf_agg_res);
  dk_free_box ((caddr_t)qr->qr_vec_ssls);
  dk_free_box ((caddr_t)qr->qr_stages);
#ifdef PLDBG
  dk_free_box (qr->qr_source);
  if (qr->qr_line_counts)
    hash_table_free (qr->qr_line_counts);
  if (qr->qr_call_counts)
    {
      id_hash_iterator_t it;
      caddr_t *calle;
      ptrlong *pcnt;

      id_hash_iterator (&it, qr->qr_call_counts);
      while (hit_next (&it, (char**) &calle, (char**) &pcnt))
	{
	  dk_free_tree (calle[0]);
	}
      id_hash_free (qr->qr_call_counts);
    }
#endif
#if defined (MALLOC_DEBUG) || defined (VALGRIND)
  if ((NULL != qr->qr_static_prev) || (NULL != qr->qr_static_next) || (qr == static_qr_dllist))
    static_qr_dllist_remove (qr);
#endif
  if (!qr->qr_text_is_constant)
    dk_free_box (qr->qr_text);
  qr->qr_nodes = (dk_set_t)-1;
  dk_free ((caddr_t) qr, sizeof (query_t));
}


void
sqlc_error (comp_context_t * cc, const char *code, const char *string,...)
{
  static char temp[2000+MAX_QUAL_NAME_LEN*7];
  va_list list;

  va_start (list, string);
  vsnprintf (temp, sizeof (temp), string, list);
  va_end (list);
  cc->cc_error = srv_make_new_error (code, "SQ200", "%s", temp);

  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR, cc->cc_error);
  lisp_throw (CATCH_LISP_ERROR, 1);
}

void
sqlc_resignal_1 (comp_context_t * cc, caddr_t err)
{
  cc->cc_error = err;
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR, cc->cc_error);
  lisp_throw (CATCH_LISP_ERROR, 1);
}

void
sqlc_new_error (comp_context_t * cc, const char *code, const char *virt_code, const char *string,...)
{
  static char temp[2000+MAX_QUAL_NAME_LEN*7];
  va_list list;
  caddr_t err = NULL;

  va_start (list, string);
  vsnprintf (temp, sizeof (temp), string, list);
  va_end (list);
  err = srv_make_new_error (code, virt_code, "%s", temp);
  if (cc)
    cc->cc_error = err;

  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR, err);
  lisp_throw (CATCH_LISP_ERROR, 1);
}


state_slot_t *
ssl_instance (void)
{
  return (NULL);
}


state_slot_t *
ssl_state (int type, dtp_t dtp)
{
  return (NULL);
}

state_slot_t *
ssl_copy (comp_context_t * cc, state_slot_t * org)
{
#if 0
  if (SSL_CONSTANT == org->ssl_type)
    return org;
#endif
  {
    NEW_VARZ (state_slot_t, sl);
    memcpy (sl, org, sizeof (state_slot_t));
    sl->ssl_name = box_copy_tree (sl->ssl_name);
    sl->ssl_constant = box_copy_tree (sl->ssl_constant);
    if (SSL_CONSTANT != sl->ssl_type)
      {
	sl->ssl_is_alias = 1;
	sl->ssl_alias_of = org;
      }
    SSL_ADD_TO_QR (sl);
    return sl;
  }
}

#define SSL_COL_REFC 0

state_slot_t *
ssl_new_column (comp_context_t * cc, const char *cr_name, dbe_column_t * col)
{
  char temp[MAX_QUAL_NAME_LEN];
  NEW_VARZ (state_slot_t, sl);
  if ((ptrlong) col == CI_ROW)
    {
      snprintf (temp, sizeof (temp), "%s._ROW", cr_name);
      sl->ssl_dtp = DV_LONG_STRING;
      sl->ssl_column = NULL;
    }
  else
    {
      sl->ssl_column = col;
      snprintf (temp, sizeof (temp), "%s.%s", cr_name, colname_or_null (col->col_name));
      sl->ssl_sqt = col->col_sqt;
    }
  sl->ssl_index = cc_new_instance_slot (cc);
  sl->ssl_name = box_dv_uname_string (temp);
  sl->ssl_type = SSL_COLUMN;

  SSL_ADD_TO_QR (sl);
  ssl_set_dc_type (sl);
  return sl;
}


state_slot_t *
ssl_new_variable (comp_context_t * cc, const char *name, dtp_t dtp)
{
  NEW_VARZ (state_slot_t, sl);

  sl->ssl_index = cc_new_instance_slot (cc);
  sl->ssl_name = box_dv_uname_string (name);
  sl->ssl_type = SSL_VARIABLE;
  sl->ssl_dtp = dtp;
  SSL_ADD_TO_QR (sl);
  return sl;
}


state_slot_t *
ssl_new_inst_variable (comp_context_t * cc, const char *name, dtp_t dtp)
{
  NEW_VARZ (state_slot_t, sl);

  sl->ssl_index = cc_new_instance_slot (cc);
  sl->ssl_name = box_dv_uname_string (name);
  sl->ssl_type = SSL_VARIABLE;
  sl->ssl_dtp = dtp;

  SSL_ADD_TO_QR (sl);
  return sl;
}


state_slot_t *
ssl_new_tree (comp_context_t * cc, const char *name)
{
  NEW_VARZ (state_slot_t, sl);

  sl->ssl_index = cc_new_instance_slot (cc);
  sl->ssl_name = box_dv_uname_string (name);
  sl->ssl_type = SSL_TREE;
  sl->ssl_dtp = DV_CUSTOM;

  dk_set_push (&cc->cc_super_cc->cc_query->qr_temp_spaces, (void *) sl);
  return sl;
}


id_hash_t * constant_ssl;

void
ssl_sys_constant (caddr_t val)
{
#ifdef USE_SYS_CONSTANT
  NEW_VARZ (state_const_slot_t, sl);
  sl->ssl_type = SSL_CONSTANT;
  sl->ssl_const_val = box_copy_tree (val);
  sl->ssl_dtp = DV_TYPE_OF (val);
  if (sl->ssl_dtp == DV_LONG_STRING)
    sl->ssl_prec = box_length (val) - 1;
  else
    sl->ssl_prec = ddl_dv_default_prec (sl->ssl_dtp);
  id_hash_set (constant_ssl, (caddr_t) &sl->ssl_const_val, (caddr_t) &sl);
#endif
}

state_slot_t *
ssl_new_constant (comp_context_t * cc, caddr_t val)
{
#ifdef USE_SYS_CONSTANT
  state_slot_t ** pre = (state_slot_t **) id_hash_get (constant_ssl, (caddr_t) &val);
  if (pre)
    return *pre;
  {
    state_const_slot_t * cnst = cc->cc_query->qr_const_ssls;
    while (cnst)
      {
	if (box_equal (val, cnst->ssl_const_val))
	  return ((state_slot_t *)cnst);
	cnst = cnst->ssl_next_const;
      }
  }
#else
  DO_SET (state_const_slot_t *, ssl, &cc->cc_query->qr_state_map)
    {
      if (SSL_CONSTANT == ssl->ssl_type
        && (DV_TYPE_OF (val) == DV_TYPE_OF (ssl->ssl_const_val)) /* This check is added due to bug 14773 */
	  && box_equal (val, ssl->ssl_const_val))
	return (state_slot_t *)ssl;
    }
  END_DO_SET();
#endif
  {
    NEW_VARZ (state_const_slot_t, sl);
    sl->ssl_next_const = cc->cc_query->qr_const_ssls;
#ifdef USE_SYS_CONSTANT
    cc->cc_query->qr_const_ssls = sl;
#else
    dk_set_push (&cc->cc_query->qr_state_map, (void *) sl);
#endif
    sl->ssl_type = SSL_CONSTANT;
    sl->ssl_const_val = box_copy_tree (val);
    sl->ssl_dtp = DV_TYPE_OF (val);
    if (sl->ssl_dtp != DV_DB_NULL)
      sl->ssl_sqt.sqt_non_null = 1;
    if (sl->ssl_dtp == DV_LONG_STRING)
      sl->ssl_prec = box_length (val) - 1;
    else
      sl->ssl_prec = ddl_dv_default_prec (sl->ssl_dtp);
    return ((state_slot_t *) sl);
  }
}

state_slot_t *
ssl_new_big_constant (comp_context_t * cc, caddr_t val)
{
#ifdef USE_SYS_CONSTANT
  state_slot_t ** pre = (state_slot_t **) id_hash_get (constant_ssl, (caddr_t) &val);
  if (pre)
    return *pre;
#endif
  {
    NEW_VARZ (state_const_slot_t, sl);
    sl->ssl_next_const = cc->cc_query->qr_const_ssls;
#ifdef USE_SYS_CONSTANT
    cc->cc_query->qr_const_ssls = sl;
#else
    dk_set_push (&cc->cc_query->qr_state_map, (void *) sl);
#endif
    sl->ssl_type = SSL_CONSTANT;
    sl->ssl_const_val = box_copy_tree (val);
    sl->ssl_dtp = DV_TYPE_OF (val);
    if (sl->ssl_dtp == DV_LONG_STRING)
      sl->ssl_prec = box_length (val) - 1;
    else
      sl->ssl_prec = ddl_dv_default_prec (sl->ssl_dtp);
    return ((state_slot_t *) sl);
  }
}

state_slot_t *
ssl_new_parameter (comp_context_t * cc, const char *name)
{
  NEW_VARZ (state_slot_t, sl);

  cc->cc_query->qr_parms =
      dk_set_conc (cc->cc_query->qr_parms,
      dk_set_cons ((caddr_t) sl, NULL));
  /* Keep params in order. ODBC identifies them by index */

  sl->ssl_index = cc_new_instance_slot (cc);
  sl->ssl_name = box_dv_uname_string (name);
  sl->ssl_type = SSL_PARAMETER;
  sl->ssl_dtp = DV_UNKNOWN;
  SSL_ADD_TO_QR (sl);
  return sl;
}


state_slot_t *
ssl_new_placeholder (comp_context_t * cc, const char *name)
{
  NEW_VARZ (state_slot_t, sl);

  sl->ssl_index = cc_new_instance_slot (cc);
  sl->ssl_type = SSL_PLACEHOLDER;
  sl->ssl_sqt.sqt_dtp = DV_ITC;
  sl->ssl_name = box_dv_uname_string (name);
  SSL_ADD_TO_QR (sl);
  return sl;
}


state_slot_t *
ssl_new_itc (comp_context_t * cc)
{
  NEW_VARZ (state_slot_t, sl);
  sl->ssl_index = cc_new_instance_slot (cc);
  sl->ssl_type = SSL_ITC;
  SSL_ADD_TO_QR (sl);
  return sl;
}

int
ssl_is_settable (state_slot_t * ssl)
{
  /* is this a valid output parameter ? */
  if (ssl->ssl_is_observer)
    return 0;
  switch (ssl->ssl_type)
    {
    case SSL_PARAMETER:
    case SSL_REF_PARAMETER:
    case SSL_REF_PARAMETER_OUT:
    case SSL_VARIABLE:
    case SSL_VEC:
      return 1;
    default:
      return 0;
    }
}



/* Given a name return a state slot.
   The name is a tagged something. If it's a constant or parameter
   make a new slot. If it's a bound column look for it */

state_slot_t *
cc_name_to_slot (comp_context_t * cc, char *name, int
    error_if_not)
{
  state_slot_t *slot = NULL;
  dtp_t dtp = lisp_type_of (name);
  if (dtp == DV_SYMBOL)
    {
      /* column, variable, parameter */
      if (name[0] == '?')
	{
	  return (ssl_new_parameter (cc, name));
	}
      DO_SET (state_slot_t *, sl, &cc->cc_super_cc->cc_query->qr_state_map)
      {
	if (sl->ssl_name &&
	    0 == strcmp (sl->ssl_name, name))
	  {
	    slot = sl;
	    break;
	  }
      }
      END_DO_SET ();
      if (slot)
	return slot;
      /* No slot. Make one if you can. */
      if (name[0] == ':')
	{
	  /* a new parameter */
	  slot = ssl_new_parameter (cc, name);
	  return slot;
	}
      if (error_if_not)
	sqlc_new_error (cc, "42S22", "SQ044", "Bad column/variable reference %s.", name);
      else
	return NULL;
    }
  else
    {
      /* It's not a symbol. Must be constant. */
      /* state_slot_t * ssl_new_constant (cc, name); */
      return (ssl_new_constant (cc, name));
    }
  GPF_T;
  return NULL;
}


void
data_source_init (data_source_t * src, comp_context_t * cc, int type)
{
  src->src_in_state = cc_new_instance_slot (cc);
  src->src_query = cc->cc_query;
}


int
sp_is_indexable (search_spec_t * sp)
{
  if (sp->sp_min_op == CMP_LIKE)
    {
      return 0;
    }
  return 1;
}


int
sym_to_op (comp_context_t * cc, char *sym)
{
  if (0 == strcmp (sym, "="))
    return CMP_EQ;
  if (0 == strcmp (sym, ">="))
    return CMP_GTE;
  if (0 == strcmp (sym, ">"))
    return CMP_GT;
  if (0 == strcmp (sym, "<="))
    return CMP_LTE;
  if (0 == strcmp (sym, "<"))
    return CMP_LT;
  if (0 == strcmp (sym, "LIKE"))
    return CMP_LIKE;
  sqlc_new_error (cc, "42000", "SQ045", "Bad compare operator.");
  return 0;
}


search_spec_t *
pred_to_spec (comp_context_t * cc, caddr_t * spec)
{
  int len = (int) BOX_ELEMENTS (spec);
  NEW_VARZ (search_spec_t, sp);
  if (len == 3)
    {
      int op = sym_to_op (cc, spec[1]);
      if (op == CMP_LT || op == CMP_LTE)
	{
	  sp->sp_min_op = CMP_NONE;
	  sp->sp_max_op = op;
	  sp->sp_max_ssl = cc_name_to_slot (cc, spec[2], 1);
	}
      else
	{
	  sp->sp_max_op = CMP_NONE;
	  sp->sp_min_op = op;
	  sp->sp_min_ssl = cc_name_to_slot (cc, spec[2], 1);
	}
    }
  else if (len == 5)
    {
      sp->sp_min_op = sym_to_op (cc, spec[1]);
      sp->sp_min_ssl = cc_name_to_slot (cc, spec[2], 1);
      sp->sp_max_op = sym_to_op (cc, spec[3]);
      sp->sp_max_ssl = cc_name_to_slot (cc, spec[4], 1);
    }
  else
    sqlc_new_error (cc, "42S22", "SQ046", "Bad column predicate.");
  if (sp->sp_next)
    GPF_T;
  return sp;
}


state_slot_t *
ks_out_slot (key_source_t * ks, dbe_column_t * col)
{
  dk_set_t slots = ks->ks_out_slots;
  DO_SET (dbe_column_t *, ocol, &ks->ks_out_cols)
  {
    if (ocol == col)
      {
	return ((state_slot_t *) slots->data);
      }
    slots = slots->next;
  }
  END_DO_SET ();
  return NULL;
}


search_spec_t **
ks_col_specs (key_source_t * ks, dbe_column_t * col,
	      int rm_from_row_specs)
{
  /* if making a misc accelerator, the specs do not apply to the row if they apply to the misc */
  search_spec_t ** prev = &ks->ks_row_spec;
  dk_set_t res = NULL;
  search_spec_t *sp;
  for (sp = ks->ks_row_spec; sp; sp = sp->sp_next)
    {
      if (!sp->sp_col)
	GPF_T1 (" a row search spec is supposed to have a referenced col");
      if (sp->sp_col == col)
	{
	  dk_set_push (&res, (void *) sp);
	  if (rm_from_row_specs)
	    {
	      *prev = sp->sp_next;
	    }
	}
      else
	prev = &sp->sp_next;
    }
  if (res)
    {
      caddr_t *arr;
      dk_set_push (&res, NULL);
      res = dk_set_nreverse (res);
      arr = (caddr_t *) dk_set_to_array (res);
      dk_set_free (res);
      box_tag_modify (arr, DV_ARRAY_OF_LONG);
      return ((search_spec_t **) arr);
    }
  return NULL;
}


void
ks_set_search_params (comp_context_t * cc, comp_table_t * ct, key_source_t * ks)
{
  int inx = 0;
  search_spec_t *sp = ks->ks_spec.ksp_spec_array;

  while (sp)
    {
      if (sp->sp_min_ssl)
	sp->sp_min = inx++;
      if (sp->sp_max_ssl)
	sp->sp_max = inx++;
      sp = sp->sp_next;
    }
  sp = ks->ks_row_spec;
  while (sp)
    {
      if (sp->sp_min_ssl)
	sp->sp_min = inx++;
      if (sp->sp_max_ssl)
	sp->sp_max = inx++;
      sp = sp->sp_next;
    }
  if (cc && inx >= MAX_SEARCH_PARAMS)
    sqlc_error (cc, "42000", "The number of predicates is too high");
}


void
il_init (comp_context_t * cc, inx_locality_t * il)
{
  il->il_n_read= cc_new_instance_slot  (cc);
  il->il_n_hits = cc_new_instance_slot  (cc);
  il->il_last_dp = cc_new_instance_slot  (cc);
}


void
inx_op_set_search_params (comp_context_t * cc, comp_table_t * ct, inx_op_t * iop)
{
  int inx = 0;
  search_spec_t *sp = iop->iop_ks_full_spec.ksp_spec_array;

  while (sp)
    {
      if (sp->sp_min_ssl)
	sp->sp_min = inx++;
      if (sp->sp_max_ssl)
	sp->sp_max = inx++;
      sp = sp->sp_next;
    }
  sp = iop->iop_ks_row_spec;
  while (sp)
    {
      if (sp->sp_min_ssl)
	sp->sp_min = inx++;
      if (sp->sp_max_ssl)
	sp->sp_max = inx++;
      sp = sp->sp_next;
    }
  if (cc && inx >= MAX_SEARCH_PARAMS)
    sqlc_error (cc, "42000", "The number of predicates is too high");
  sp = iop->iop_ks_start_spec.ksp_spec_array;
  inx = 0;
  while (sp)
    {
      if (sp->sp_min_ssl)
	sp->sp_min = inx++;
      if (sp->sp_max_ssl)
	sp->sp_max = inx++;
      sp = sp->sp_next;
    }
  if (cc && inx >= MAX_SEARCH_PARAMS)
    sqlc_error (cc, "42000", "The number of predicates is too high");
  ksp_cmp_func (&iop->iop_ks_start_spec, &iop->iop_ks_start_spec_nth);
  ksp_cmp_func (&iop->iop_ks_full_spec, &iop->iop_ks_full_spec_nth);
  il_init (cc, &iop->iop_il);
}


void
ks_check (key_source_t * ks)
{
  search_spec_t *spec = ks->ks_spec.ksp_spec_array;
  while (spec)
    spec = spec->sp_next;
  spec = ks->ks_row_spec;
  while (spec)
    spec = spec->sp_next;
}


void
ks_spec_add (search_spec_t ** place, search_spec_t * sp)
{
  search_spec_t *temp;
  if (sp->sp_next)
    GPF_T;
  while (1)
    {
      if ((*place) == NULL)
	{
	  *place = sp;
	  return;
	}
      temp = *place;
      place = &temp->sp_next;
    }
}


void
ks_do_dependent_specs (comp_context_t * cc, key_source_t * ks,
    dbe_key_t * key, caddr_t * specs,
    search_spec_t ** sps)
{
  /* Take the specs and put them in the row specs of the key if the key
     has the columns */
  int i;
  for (i = 0; ((uint32) i) < BOX_ELEMENTS (specs); i++)
    {
      caddr_t *spec = (caddr_t *) (specs[i]);
      if (!spec)
	continue;
      DO_SET (dbe_column_t *, col, &key->key_parts)
      {
	if (0 == strcmp (spec[0], col->col_name))
	  {
	    sps[i]->sp_cl = *key_find_cl (key, col->col_id);
	    sps[i]->sp_col = col;
	    ks_spec_add (&ks->ks_row_spec, sps[i]);
	    specs[i] = NULL;
	    dk_free_tree ((box_t) spec);
	    break;
	  }
      }
      END_DO_SET ();
    }
}


key_source_t *
key_source_create (comp_context_t * cc,
    dbe_key_t * key, char *cr_name,
    char **cols, caddr_t * specs,
    search_spec_t ** sps)
{
  int inx = 0;
  int part_no = 0;
  NEW_VARZ (key_source_t, ks);
  ks->ks_key = key;
  ks->ks_row_check = itc_row_check;
  /* Make the index search key */

  if (specs)
    {
      DO_SET (dbe_column_t *, col, &key->key_parts)
      {
	caddr_t *spec = NULL;
	int i;
	if (part_no >= key->key_n_significant)
	  break;
	part_no++;
	for (i = 0; ((uint32) i) < BOX_ELEMENTS (specs); i++)
	  {
	    if (!specs[i])
	      continue;
	    if (0 == strcmp (col->col_name, *((caddr_t *) (specs[i])))
		&& sp_is_indexable (sps[i]))
	      {
		spec = (caddr_t *) (specs[i]);
		break;
	      }
	  }
	if (spec)
	  {
	    sps[i]->sp_cl = *key_find_cl (key, col->col_id);
	    ks_spec_add (&ks->ks_spec.ksp_spec_array, sps[i]);
	    dk_free_tree ((caddr_t) spec);
	    specs[i] = NULL;
	    ks_check (ks);

	  }
	else
	  break;
      }
      END_DO_SET ();
      ks_do_dependent_specs (cc, ks, key, specs, sps);
    }
  ks_check (ks);
  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (cols); inx++)
    {
      if (!cols[inx])
	continue;
      if (key->key_is_primary && 0 == CASEMODESTRCMP (cols[inx], "_ROW"))
	{
	  state_slot_t *slot = ssl_new_column (cc, cr_name,
	      (dbe_column_t *) CI_ROW);
	  dk_set_push (&ks->ks_out_cols, (void *) CI_ROW);
	  dk_set_push (&ks->ks_out_slots, (void *) slot);
	  dk_free_tree (cols[inx]);
	  cols[inx] = NULL;
	  continue;
	}
      ks_check (ks);
      DO_SET (dbe_column_t *, col, &key->key_parts)
      {
	if (0 == CASEMODESTRCMP (col->col_name, cols[inx]))
	  {
	    state_slot_t *slot = ssl_new_column (cc, cr_name, col);
	    dk_set_push (&ks->ks_out_cols, (void *) col);
	    dk_set_push (&ks->ks_out_slots, (void *) slot);
	    dk_free_tree (cols[inx]);
	    cols[inx] = NULL;
	    break;
	  }
      }
      END_DO_SET ();
    }
  ks_check (ks);
  return ks;
}


void
key_free_trail_specs (search_spec_t * sp)
{
  while (sp)
    {
      search_spec_t *next = sp->sp_next;
      dk_free ((caddr_t) sp, sizeof (search_spec_t));
      sp = next;
    }
}


void
clb_free (cl_buffer_t * clb)
{
  dk_free_box (clb->clb_save);
}


void
cl_order_free (clo_comp_t ** ords)
{
  int inx;
  if (!ords)
    return;
  DO_BOX (caddr_t, ord, inx, ords)
    {
      dk_free (ord, sizeof (clo_comp_t));
    }
  END_DO_BOX;
  dk_free_box ((caddr_t)ords);
}


void
ks_free (key_source_t * ks)
{
  if (!ks)
    return;
  key_free_trail_specs (ks->ks_spec.ksp_spec_array);
  key_free_trail_specs (ks->ks_row_spec);
  dk_set_free (ks->ks_out_cols);
  dk_set_free (ks->ks_out_slots);
  cv_free (ks->ks_local_test);
  cv_free (ks->ks_local_code);
  if (ks->ks_out_map || ks->ks_v_out_map)
    dk_free_box ((caddr_t) ks->ks_out_map);
    dk_free_box ((caddr_t) ks->ks_v_out_map);
    dk_free_box ((caddr_t) ks->ks_vec_source);
    dk_free_box ((caddr_t) ks->ks_vec_cast);
    dk_free_box ((caddr_t) ks->ks_dc_val_cast);
    dk_free_box (ks->ks_cast_null);
    dk_free_box ((caddr_t) ks->ks_scalar_partition);
    dk_free_box ((caddr_t) ks->ks_scalar_cp);
    dk_free_box ((caddr_t) ks->ks_vec_cp);

  dk_set_free (ks->ks_always_null);
  dk_free_box ((caddr_t)ks->ks_qf_output);
  if (ks->ks_cl_order)
    cl_order_free (ks->ks_cl_order);
  sp_list_free (ks->ks_hash_spec);
  dk_free ((caddr_t) ks, sizeof (key_source_t));
}


caddr_t
box_any_left (caddr_t * box)
{
  int inx;
  if (!box)
    return NULL;
  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (box); inx++)
    {
      if (box[inx])
	return (box[inx]);
    }
  return NULL;
}


void
ks_add_key_cols (comp_context_t * cc, key_source_t * ks,
    dbe_key_t * key, char *cr_name)
{
  caddr_t name_sym;
  char temp_name[200];
  int part_no = 0;
  DO_SET (dbe_column_t *, col, &key->key_parts)
  {
    if (part_no >= key->key_n_significant)
      return;
    snprintf (temp_name, sizeof (temp_name), "%s.%s", cr_name, colname_or_null (col->col_name));
    name_sym = str_to_sym (temp_name);
    if (!cc_name_to_slot (cc, name_sym, 0))
      {
	state_slot_t *slot = ssl_new_column (cc, cr_name, col);
	dk_set_push (&ks->ks_out_cols, (void *) col);
	dk_set_push (&ks->ks_out_slots, (void *) slot);
      }
    dk_free_box (name_sym);
    part_no++;
  }
  END_DO_SET ();
}


void
ks_make_main_spec (comp_context_t * cc, key_source_t * ks, char *cr_name)
{
  caddr_t name_sym;
  char temp_name[200];
  int part_no = 0;
  search_spec_t **last_spec = &ks->ks_spec.ksp_spec_array;
  if (ks->ks_spec.ksp_spec_array)
    GPF_T;	/* prime key specs left after order key processed */
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
	snprintf (temp_name, sizeof (temp_name), "%s.%s", cr_name, colname_or_null (col->col_name));
	name_sym = str_to_sym (temp_name);
	sp->sp_min_ssl = cc_name_to_slot (cc, name_sym, 1);
	dk_free_box (name_sym);
	sp->sp_cl = *key_find_cl (ks->ks_key, col->col_id);
      }
    part_no++;
  }
  END_DO_SET ();
}


search_spec_t **
ts_preds_to_sps (comp_context_t * cc, caddr_t * preds)
{
  int inx;
  search_spec_t **sps;
  if (!preds)
    return NULL;
  sps = (search_spec_t **) dk_alloc_box (box_length ((caddr_t) preds),
      DV_ARRAY_OF_POINTER);
  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (preds); inx++)
    {
      if (preds[inx])
	sps[inx] = pred_to_spec (cc, (caddr_t *) preds[inx]);
      else
	sps[inx] = NULL;
    }
  return sps;
}



void
inx_op_free (inx_op_t * iop)
{
  int inx;
  switch (iop->iop_op)
    {
    case IOP_AND:
      DO_BOX (inx_op_t *, term, inx, iop->iop_terms)
	{
	  inx_op_free (term);
	}
      END_DO_BOX;
      dk_free_box ((caddr_t) iop->iop_terms);
      break;
    case IOP_KS:
      ks_free (iop->iop_ks);
      break;
    }
  dk_free_box ((caddr_t) iop->iop_out);
  dk_free_box ((caddr_t) iop->iop_max);
  key_free_trail_specs  (iop->iop_ks_start_spec.ksp_spec_array);
  key_free_trail_specs  (iop->iop_ks_full_spec.ksp_spec_array);
  key_free_trail_specs  (iop->iop_ks_row_spec);
  dk_free ((caddr_t) iop, sizeof (inx_op_t));
}


void
ts_free (table_source_t * ts)
{
  if (TS_ALT_POST == ts->ts_is_alternate)
    {
      /* an alternate ts refers to the after tests and code of the primary ts.  Set the refs to nulll */
      ts->src_gen.src_after_test = NULL;
      ts->src_gen.src_after_code = NULL;
      if (ts->ts_order_ks)
	{
	  ts->ts_order_ks->ks_local_test = NULL;
	  ts->ts_order_ks->ks_local_code = NULL;
	}
    }
  if (!ts)
    return;
  if (ts->ts_inx_op)
    {
      inx_op_free (ts->ts_inx_op);
      ts->ts_inx_op = NULL;
    }
  else
    ks_free (ts->ts_order_ks);
  ts->ts_order_ks = NULL;
  clb_free (&ts->clb);
  cv_free (ts->ts_after_join_test);
  ts->ts_after_join_test = NULL;
  if (ts->ts_main_ks)
    {
      ks_free (ts->ts_main_ks);
      ts->ts_main_ks = NULL;
    }
  if (ts->ts_proc_ha)
    ha_free (ts->ts_proc_ha);
  dk_free_box(ts->ts_sort_read_mask);
  dk_free_box ((caddr_t)ts->ts_branch_ssls);
  dk_free_box ((caddr_t)ts->ts_branch_sets);
}


void
sqlc_ts_set_no_blobs (table_source_t * ts)
{
  if (ts->ts_order_ks)
    {
      DO_SET (dbe_column_t *, col, &ts->ts_order_ks->ks_out_cols)
	{
	  if (col != (dbe_column_t *) CI_ROW && IS_BLOB_DTP (col->col_sqt.sqt_dtp))
	    return;
	}
      END_DO_SET ();
    }
  if (ts->ts_main_ks)
    {
      DO_SET (dbe_column_t *, col, &ts->ts_main_ks->ks_out_cols)
      {
	if (col != (dbe_column_t *) CI_ROW && IS_BLOB_DTP (col->col_sqt.sqt_dtp))
	  return;
      }
      END_DO_SET ();
    }
  ts->ts_no_blobs = 1;
}


void
ts_alias_current_of (table_source_t * ts)
{
  if (ts->ts_inx_op
      && !ts->ts_main_ks
      && ts->ts_current_of)
    {
      ssl_alias (ts->ts_current_of, ts->ts_inx_op->iop_terms[0]->iop_itc);
    }
  else if (!ts->ts_is_unique
      && !ts->ts_main_ks
      && ts->ts_current_of)
    ssl_alias (ts->ts_current_of, ts->ts_order_cursor);
}


void
qr_resolve_aliases (query_t * qr)
{
  /* for nth generation aliases, set the ssl_index to be that
   * of the ultimate destination (first non-alias
   */
  DO_SET (state_slot_t *, ssl, &qr->qr_state_map)
  {
    if (ssl->ssl_is_alias)
      {
	int indirection = 0;
	state_slot_t *refd_ssl = ssl->ssl_alias_of;
	while (refd_ssl->ssl_is_alias)
	  {
	    indirection++;
	    if (indirection > 1000)
	      {
		/*was : GPF_T1 ("Circular slot aliases in query"); */
		sqlc_new_error (top_sc->sc_cc, "37000", "SQ185", "Circular assignment in query");
	      }
	    refd_ssl = refd_ssl->ssl_alias_of;
	  }
	ssl->ssl_index = refd_ssl->ssl_index;
#if 0 /* XXX: makes complication */
	if (ssl->ssl_type != refd_ssl->ssl_type) /* can be mark'd as global and no longer vec */
	  ssl->ssl_type = refd_ssl->ssl_type;
#endif
      }
  }
  END_DO_SET ();
}


void
qr_no_copy_ssls (query_t * qr, dk_hash_t * no_copy)
{
  DO_SET (data_source_t *, qn, &qr->qr_nodes)
    {
      if (IS_QN (qn, subq_node_input))
	qr_no_copy_ssls (((subq_source_t*)qn)->sqs_query, no_copy);
      else if (IS_QN (qn, setp_node_input))
	{
	  QNCAST (setp_node_t, setp, qn);
	  hash_area_t * ha = setp->setp_ha;
	  if (ha && (HA_DISTINCT == ha->ha_op || HA_GROUP == ha->ha_op ||HA_ORDER == ha->ha_op))
	    sethash ((void*)ha->ha_tree, no_copy, (void*)1);
	  sethash ((void*)setp->setp_sorted, no_copy, (void*) 1);
	}
    }
  END_DO_SET();
  DO_SET (query_t *, sq, &qr->qr_subq_queries)
    qr_no_copy_ssls (sq, no_copy);
  END_DO_SET();
}


unsigned int
ssl_sort_key (state_slot_t * ssl)
{
  return (unsigned int)ssl->ssl_index;
}


void
ssl_sort_by_index (state_slot_t ** ssls)
{
  buf_sort ((buffer_desc_t**)ssls, BOX_ELEMENTS (ssls), (sort_key_func_t)ssl_sort_key);
}


void
qr_set_freeable (comp_context_t *cc, query_t * qr)
{
  dk_set_t res = NULL;
  dk_set_t  slots = qr->qr_state_map;
  dk_set_t * prev = &qr->qr_state_map;
  dk_set_t copy = NULL;
  dk_hash_t * no_copy = hash_table_allocate (23);
  qr_no_copy_ssls (qr, no_copy);
  if (qr->qr_state_map)
    stssl_query (cc, qr); /* top qr only */
  while (slots)
    {
      dk_set_t next = slots->next;
      state_slot_t * ssl = (state_slot_t *) slots->data;
      state_slot_t * use_ssl = ssl_use_stock (cc, ssl);
      if (!ssl->ssl_is_alias
	  && !IS_SSL_REF_PARAMETER (ssl->ssl_type)
	  && ssl->ssl_type != SSL_CONSTANT)
	{
	  dk_set_push (&res, (void*)use_ssl);
	  if (SSL_ITC != ssl->ssl_type && SSL_PLACEHOLDER != ssl->ssl_type && !gethash ((void*)ssl, no_copy))
	    dk_set_push (&copy, ssl);
	}
      if (use_ssl != ssl)
	{
	  /* preallocated   standard ssl was used instead. */
	  *prev = slots->next;
	  memset (ssl, 0xdd, sizeof (state_slot_t));
	  dk_free (slots, sizeof (s_node_t));
	}
      else
	prev = &slots->next;
      slots = next;
    }
  dk_free_box ((box_t) qr->qr_freeable_slots);
  qr->qr_freeable_slots = (state_slot_t **) list_to_array (res);
  ssl_sort_by_index (qr->qr_freeable_slots);
  qr->qr_qp_copy_ssls = (state_slot_t **) list_to_array (copy);
  hash_table_free (no_copy);
  if (cc->cc_keep_ssl)
    {
      hash_table_free (cc->cc_keep_ssl);
      cc->cc_keep_ssl = NULL;
    }
}


table_source_t *
table_source_create (
    comp_context_t * cc, char *table_name,
    char *orderby, char *cr_name,
    char **cols, char **preds,
    char *from_position)
{
  search_spec_t **sps = ts_preds_to_sps (cc, preds);
  dbe_table_t *table = sch_name_to_table (cc->cc_schema, table_name);
  dbe_key_t *order_key;
  dbe_key_t *main_key;

  NEW_VARZ (table_source_t, ts);
  if (!table)
    sqlc_new_error (cc, "42S02", "SQ047", " No table %s.", table_name);
  order_key = tb_name_to_key (table, orderby, 0);
  if (!order_key)
    sqlc_new_error (cc, "42S12", "SQ048", "No key %s", orderby);
  main_key = table->tb_primary_key;

  if (!order_key)
    sqlc_new_error (cc, "42S12", "SQ049", "No key named %s.", orderby);
  data_source_init ((data_source_t *) ts, cc, QNT_TABLE);

  ts->src_gen.src_input = (qn_input_fn) table_source_input;
  ts->src_gen.src_free = (qn_free_fn) ts_free;
  ts->ts_order_ks = key_source_create (cc, order_key, cr_name, cols,
      preds, sps);
  ts->ts_current_of = ssl_new_placeholder (cc, cr_name);
  ts->ts_order_cursor = ssl_new_itc (cc);

  /* Done? Need the main row? */
  if (order_key != table->tb_primary_key)
    {
      if (box_any_left (preds) || box_any_left (cols))
	{
	  ks_add_key_cols (cc, ts->ts_order_ks, table->tb_primary_key, cr_name);
	  ts->ts_main_ks = key_source_create (cc, table->tb_primary_key,
	      cr_name, cols, preds, sps);
	  ks_make_main_spec (cc, ts->ts_main_ks, cr_name);
	  il_init (cc, &ts->ts_il);
	}
    }
  sqlc_ts_set_no_blobs (ts);
  if (from_position)
    {
      ts->ts_order_ks->ks_init_place = cc_name_to_slot (cc, from_position, 1);
      if (ts->ts_order_ks->ks_init_place->ssl_type != SSL_PLACEHOLDER)
	sqlc_new_error (cc, "42S22", "SQ050", "%s is not the name of a CURRENT OF.");
      ts->ts_order_ks->ks_init_used = cc_new_instance_slot (cc);
    }
  dk_free_box ((caddr_t) sps);
  ks_set_search_params (cc, NULL, ts->ts_order_ks);
  if (ts->ts_main_ks)
    ks_set_search_params (cc, NULL, ts->ts_main_ks);
  ts_alias_current_of (ts);
  table_source_om (cc, ts);
  return ts;
}


void
ik_array_free (ins_key_t ** iks)
{
  int inx;
  if (!iks)
    return;
  DO_BOX (ins_key_t *, ik, inx, iks)
    {
      if (!ik)
	continue;
      dk_free_box ((caddr_t) ik->ik_slots);
      dk_free_box ((caddr_t) ik->ik_cols);
      dk_free_box ((caddr_t) ik->ik_del_slots);
      dk_free_box ((caddr_t) ik->ik_del_cast);
      dk_free_box ((caddr_t) ik->ik_del_cast_func);
      dk_free ((caddr_t) ik, sizeof (ins_key_t));
    }
  END_DO_BOX;
  dk_free_box ((caddr_t)iks);
}


void
ins_free (insert_node_t * ins)
{
  dk_free_box ((caddr_t) ins->ins_col_ids);
  dk_set_free (ins->ins_values);
  dk_free_box ((caddr_t) ins->ins_trigger_args);
  clb_free (&ins->clb);
  dk_free_box ((caddr_t)ins->ins_vec_source);
  dk_free_box ((caddr_t)ins->ins_vec_cast);
  dk_free_box ((caddr_t)ins->ins_vec_cast_cl);
  ik_array_free (ins->ins_keys);
  dk_free_box (ins->ins_key_only);
  qr_free (ins->ins_policy_qr);
}


state_slot_t *
ins_col_slot (comp_context_t * cc, insert_node_t * ins, oid_t col_id)
{
  dbe_column_t * col = NULL;
  int nth;
  DO_BOX (oid_t, cid, nth, ins->ins_col_ids)
    {
      if (cid == col_id)
	{
	  return ((state_slot_t*) dk_set_nth (ins->ins_values, nth));
	}
    }
  END_DO_BOX;
  col = sch_id_to_column (cc->cc_schema, col_id);
  return (ssl_new_constant (cc, col->col_default));
}


ins_key_t *
ins_key (comp_context_t * cc, insert_node_t * ins, dbe_key_t * key)
{
  int inx = 0;
  dk_set_t slots = NULL;
  dk_set_t cols = NULL;
  NEW_VARZ (ins_key_t, ik);
  ik->ik_key = key;
  DO_CL (cl, key->key_key_fixed)
    {
      dk_set_push (&cols, (void*)sch_id_to_column (wi_inst.wi_schema, cl->cl_col_id));
      dk_set_push (&slots, (void*) ins_col_slot (cc, ins, cl->cl_col_id));
    }
  END_DO_CL;
  DO_CL (cl, key->key_key_var)
    {
      dk_set_push (&cols, (void*)sch_id_to_column (wi_inst.wi_schema, cl->cl_col_id));
      dk_set_push (&slots, (void*) ins_col_slot (cc, ins, cl->cl_col_id));
    }
  END_DO_CL;
  if (key->key_is_col)
    {
      dk_set_t parts = key->key_parts;
      int inx;
      for (inx = 0; inx < key->key_n_significant; inx++)
	parts = parts->next;
      DO_SET (dbe_column_t *, col, &parts)
	{
	  dk_set_push (&cols, (void*)col);
	  dk_set_push (&slots, (void*) ins_col_slot (cc, ins, col->col_id));
	}
      END_DO_SET();
    }
  else
    {
  if (key->key_row_fixed)
    {
      for (inx = 0; key->key_row_fixed[inx].cl_col_id; inx++)
	    {
	      dk_set_push (&cols, (void*)sch_id_to_column (wi_inst.wi_schema, key->key_row_fixed[inx].cl_col_id));
	dk_set_push (&slots, (void*) ins_col_slot (cc, ins, key->key_row_fixed[inx].cl_col_id));
    }
	}
  if (key->key_row_var)
    {
      for (inx = 0; key->key_row_var[inx].cl_col_id; inx++)
	{
	      if (CI_BITMAP == key->key_row_var[inx].cl_col_id)
		continue;
	      dk_set_push (&cols, (void*)sch_id_to_column (wi_inst.wi_schema, key->key_row_var[inx].cl_col_id));
	    dk_set_push (&slots, (void*) ins_col_slot (cc, ins, key->key_row_var[inx].cl_col_id));
	}
    }
    }
  ik->ik_slots = (state_slot_t **) list_to_array (dk_set_nreverse (slots));
  ik->ik_cols = (dbe_column_t **) list_to_array (dk_set_nreverse (cols));
  return ik;
}


void
sqlc_ins_keys (comp_context_t * cc, insert_node_t * ins)
{
  dk_set_t keys = NULL;
  if (!ins->ins_key_only && dk_set_length (ins->ins_table->tb_primary_key->key_parts) == ins->ins_table->tb_primary_key->key_n_significant)
    {
      ins->ins_no_deps = 1;
      if (INS_REPLACING == ins->ins_mode)
	ins->ins_mode = INS_SOFT; /* if it's pk parts only, no difference between replace and soft */
    }
  if (ins->ins_key_only)
    {
      DO_SET (dbe_key_t *, key, &ins->ins_table->tb_keys)
	{
	  if (0 == stricmp (key->key_name, ins->ins_key_only))
	    {
	      ins->ins_keys = (ins_key_t **) list (1, ins_key (cc, ins, key));
	      return;
	    }
	}
      END_DO_SET();
      sqlc_new_error (cc, "22000", "INS..", "Explicit index %s in insert does not exist", ins->ins_key_only);
    }
  dk_set_push (&keys, (void*) ins_key (cc, ins, ins->ins_table->tb_primary_key));
  DO_SET (dbe_key_t *, key, &ins->ins_table->tb_keys)
    {
      if (!key->key_is_primary)
	dk_set_push (&keys, (void*) ins_key (cc, ins, key));
    }
  END_DO_SET();
  ins->ins_keys = (ins_key_t **) list_to_array (dk_set_nreverse (keys));
}


insert_node_t *
insert_node_create (comp_context_t * cc, char *tb_name,
    char **col_names, char **values)
{
  int inx;
  oid_t *col_ids = (oid_t *) dk_alloc_box (box_length ((caddr_t) col_names),
      DV_ARRAY_OF_LONG);
  dbe_table_t *table = sch_name_to_table (cc->cc_schema, tb_name);
  NEW_VARZ (insert_node_t, ins);
  if (!table)
    sqlc_new_error (cc, "42S02", "SQ051", "No table %s.", tb_name);
  data_source_init ((data_source_t *) ins, cc, QNT_INSERT);

  ins->ins_table = table;
  ins->ins_policy_qr = sqlc_make_policy_trig (cc, table, TB_RLS_I);
  ins->ins_col_ids = col_ids;
  ins->src_gen.src_input = (qn_input_fn) insert_node_input;
  ins->src_gen.src_free = (qn_free_fn) ins_free;
  if (box_length ((caddr_t) col_names) != box_length ((caddr_t) values))
    sqlc_new_error (cc, "21S01", "SQ052", "Uneven col and value lists in insert.");
  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (col_names); inx++)
    {
      dbe_column_t *col = tb_name_to_column (table, col_names[inx]);
      state_slot_t *slot = cc_name_to_slot (cc, values[inx], 1);
      if (!col)
	sqlc_new_error (cc, "42S22", "SQ053", "No such column %s.", col_names[inx]);
      col_ids[inx] = col->col_id;
      ins->ins_values = dk_set_conc (ins->ins_values,
	  dk_set_cons ((caddr_t) slot, NULL));
    }
  sqlc_ins_keys (cc, ins);
  sqlg_cl_insert (NULL, cc, ins, NULL, NULL);
  return ins;
}


caddr_t
str_to_sym (const char *str)
{
  caddr_t sym = box_string (str);
  box_tag_modify (sym, DV_SYMBOL);
  return sym;
}


caddr_t
box_keyword_get (caddr_t * box, char *kwd, int *found)
{
  int inx;
  if (found)
    *found = 0;
  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (box) - 1; inx++)
    {
      caddr_t elt = box[inx];
      if ((DV_SYMBOL == lisp_type_of (elt) ||
	      DV_LONG_STRING == lisp_type_of (elt) ||
	      DV_SHORT_STRING == lisp_type_of (elt))
	  && 0 == strcmp (elt, kwd))
	{
	  if (found)
	    *found = 1;
	  return (box[inx + 1]);
	}
    }
  return NULL;
}


void
key_source_om (comp_context_t * cc, key_source_t * ks)
{
  int inx = 0;
  int n_out = dk_set_length (ks->ks_out_slots);
  out_map_t * om;
  if (!n_out)
    return;
  om = (out_map_t *) dk_alloc_box (sizeof (out_map_t) * n_out, DV_BIN);
  memset (om, 0, n_out * sizeof (out_map_t));
  DO_SET (dbe_column_t *, col, &ks->ks_out_cols)
    {
      if (ks->ks_key->key_bit_cl && col->col_id == ks->ks_key->key_bit_cl->cl_col_id)
	om[inx++].om_is_null = OM_BM_COL;
      else if (CI_ROW == (ptrlong) col)
	om[inx++].om_is_null = OM_ROW;
      else if (ks->ks_key->key_is_col)
	om[inx++].om_cl = *cl_list_find (ks->ks_key->key_row_var, col->col_id);
      else
	{
	  dbe_col_loc_t * cl = key_find_cl (ks->ks_key, col->col_id);
	  if (cl)
	    om[inx++].om_cl = *cl;
	  else
	    SQL_GPF_T1 (cc, "cannot find column in index");
	}
    }
  END_DO_SET();
  ks->ks_out_map = om;
}


void
table_source_om (comp_context_t * cc, table_source_t * ts)
{
  if (ts->ts_inx_op)
    {
      int inx;
      DO_BOX (inx_op_t *, iop, inx, ts->ts_inx_op->iop_terms)
	{
	  key_source_om (cc, iop->iop_ks);
	}
      END_DO_BOX;
    }
  if (ts->ts_order_ks)
    key_source_om (cc, ts->ts_order_ks);
  if (ts->ts_main_ks)
    key_source_om (cc, ts->ts_main_ks);
}


void
table_source_compile (comp_context_t * cc,
    caddr_t * stmt, data_source_t ** head_ret,
    data_source_t ** tail_ret)
{
  table_source_t *ts;
  caddr_t from_position = box_keyword_get (stmt, "from_position", NULL);
  caddr_t cr_name = box_keyword_get (stmt, "prefix", NULL);
  caddr_t is_unq = box_keyword_get (stmt, "one", NULL);
  caddr_t by = box_keyword_get (stmt, "by", NULL);
  caddr_t spec = box_keyword_get (stmt, "where", 0);
  if (!cr_name)
    cr_name = stmt[1];
  ts = table_source_create (cc, stmt[1], by, cr_name,
      (char **) stmt[2],
      (caddr_t *) spec,
      from_position);
  if (is_unq)
    ts->ts_is_unique = 1;
  dk_set_push (&cc->cc_query->qr_nodes, (void *) ts);
  *head_ret = (data_source_t *) ts;
  *tail_ret = (data_source_t *) ts;
}


int
ins_flag (comp_context_t * cc, caddr_t * stmt, int f_pos)
{
  if (BOX_ELEMENTS (stmt) <= (uint32) f_pos)
    return INS_NORMAL;
  if (0 == strcmp (stmt[f_pos], "soft"))
    return INS_SOFT;
  if (0 == strcmp (stmt[f_pos], "replacing"))
    return INS_REPLACING;
  sqlc_new_error (cc, "42000", "SQ054", "Bad insert mode.");

  /*NOTREACHED*/
  return 0;
}


void
insert_node_compile (comp_context_t * cc, caddr_t * stmt,
    data_source_t ** head_ret,
    data_source_t ** tail_ret)
{
  caddr_t vals = stmt[3];

  insert_node_t *ins = insert_node_create (cc, stmt[1], (caddr_t *) stmt[2],
      (caddr_t *) vals);
  ins->ins_mode = ins_flag (cc, stmt, 4);
  dk_set_push (&cc->cc_query->qr_nodes, (void *) ins);
  *head_ret = (data_source_t *) ins;
  *tail_ret = (data_source_t *) ins;
}


void
sequence_compile (comp_context_t * cc, caddr_t * stmt,
    data_source_t ** head_ret, data_source_t ** tail_ret)
{
  int inx;
  data_source_t *head;
  data_source_t *last;
  eql_stmt_comp (cc, stmt[1], &head, &last);
  for (inx = 2; ((uint32) inx) < BOX_ELEMENTS (stmt); inx++)
    {
      data_source_t *elt_start;
      data_source_t *elt_end;
      eql_stmt_comp (cc, stmt[inx], &elt_start, &elt_end);
      dk_set_push (&last->src_continuations, (void *) elt_start);
      last = elt_end;
    }
  *head_ret = head;
  *tail_ret = last;
}


#define NODE_INIT(type, en, input, del) \
  NEW_VARZ (type, en); \
  data_source_init ((data_source_t *) en, cc, 0);    \
  en -> src_gen.src_input = (qn_input_fn) input;     \
  en -> src_gen.src_free = (qn_free_fn) del;        \
  dk_set_push (& cc->cc_query->qr_nodes, (void *) en); \
  * head_ret = (data_source_t *) en;                 \
  * tail_ret = (data_source_t *) en;


void
end_node_compile (comp_context_t * cc, caddr_t * stmt,
    data_source_t ** head_ret, data_source_t ** tail_ret)
{
  NEW_VARZ (end_node_t, en);
  data_source_init ((data_source_t *) en, cc, 0);
  en->src_gen.src_input = (qn_input_fn) end_node_input;

  dk_set_push (&cc->cc_query->qr_nodes, (void *) en);
  *head_ret = (data_source_t *) en;
  *tail_ret = (data_source_t *) en;
}


/* current_of <local place> <cursor> <place in cursor> */

void
current_of_node_compile (comp_context_t * cc,
    caddr_t * stmt, data_source_t ** head_ret,
    data_source_t ** tail_ret)
{
  char *place_name = stmt[1];
  char *cr_name = stmt[2];
  char *cr_place_name = box_string (stmt[3]);
  NODE_INIT (current_of_node_t, co, current_of_node_input, NULL);

  co->co_place = ssl_new_placeholder (cc, place_name);
  co->co_cursor_name = cc_name_to_slot (cc, cr_name, 1);
  co->co_cursor_place_name = cr_place_name;


  dk_set_push (&cc->cc_query->qr_used_cursors, box_string (cr_name));
}


/* deref <oid in> <row out> <place out> */

void
deref_node_compile (comp_context_t * cc,
    caddr_t * stmt, data_source_t ** head_ret,
    data_source_t ** tail_ret)
{
  char *row = box_keyword_get (stmt, "row", NULL);
  char *place = box_keyword_get (stmt, "place", NULL);
  NODE_INIT (deref_node_t, dn, deref_node_input, NULL);

  dn->dn_ref = cc_name_to_slot (cc, stmt[1], 1);

  if (row)
    dn->dn_row = ssl_new_variable (cc, row, DV_LONG_STRING);
  if (place)
    dn->dn_place = ssl_new_placeholder (cc, place);
  dn->dn_is_oid = 1;
}


void
row_deref_node_compile (comp_context_t * cc,
    caddr_t * stmt, data_source_t ** head_ret,
    data_source_t ** tail_ret)
{
  char *row = box_keyword_get (stmt, "row", NULL);
  char *place = box_keyword_get (stmt, "place", NULL);
  NODE_INIT (deref_node_t, dn, deref_node_input, NULL);

  dn->dn_ref = cc_name_to_slot (cc, stmt[1], 1);

  if (row)
    dn->dn_row = ssl_new_variable (cc, row, DV_LONG_STRING);
  if (place)
    dn->dn_place = ssl_new_placeholder (cc, place);
  dn->dn_is_oid = 0;
}


/*
   update <table> <place> (<col> <value> ...)
 */

void
upd_free (update_node_t * upd)
{
  dk_free_box ((caddr_t) upd->upd_col_ids);
  dk_free_box ((caddr_t) upd->upd_values);
  dk_free_box ((caddr_t) upd->upd_pk_values);
  dk_free_box ((caddr_t) upd->upd_old_blobs);
  dk_free_box ((caddr_t) upd->upd_quick_values);
  dk_free_box ((caddr_t) upd->upd_var_cl);
  dk_free_box ((caddr_t) upd->upd_trigger_args);
  dk_free_box ((caddr_t) upd->upd_fixed_cl);
  ik_array_free (upd->upd_keys);
  qr_free (upd->upd_policy_qr);
}


void
update_node_compile (comp_context_t * cc,
    caddr_t * stmt, data_source_t ** head_ret,
    data_source_t ** tail_ret)
{
  caddr_t table = stmt[1];
  state_slot_t *place = cc_name_to_slot (cc, stmt[2], 1);
  caddr_t *assigns = (caddr_t *) stmt[3];
  state_slot_t **values;
  oid_t *cols;
  int len = BOX_ELEMENTS (assigns), inx;
  int n_vals = len / 2;
  dbe_table_t *tb;
  NODE_INIT (update_node_t, upd, update_node_input, upd_free);
  upd->upd_hi_id = upd_hi_id_ctr++;
  if (len & 1)
    sqlc_new_error (cc, "21S01", "SQ055", "Odd assignment list for update.");

  tb = sch_name_to_table (cc->cc_schema, table);
  if (!tb)
    sqlc_new_error (cc, "42S02", "SQ056", "No table %s in update.", table);

  values = (state_slot_t **) dk_alloc_box (sizeof (oid_t) * n_vals,
      DV_ARRAY_OF_LONG);
  cols = (oid_t *) dk_alloc_box (sizeof (oid_t) * n_vals,
      DV_ARRAY_OF_LONG);
  for (inx = 0; inx < n_vals; inx++)
    {
      state_slot_t *val = cc_name_to_slot (cc, assigns[2 * inx + 1], 1);
      dbe_column_t *col = tb_name_to_column (tb, assigns[inx * 2]);
      if (!col)
	sqlc_new_error (cc, "42S22", "SQ057", "No such column %s in update.",
	    assigns[inx * 2]);
      cols[inx] = col->col_id;
      values[inx] = val;
    }
  upd->upd_col_ids = cols;
  upd->upd_values = values;
  upd->upd_place = place;
  upd->upd_policy_qr = sqlc_make_policy_trig (cc, tb, TB_RLS_U);
}



/*
   (update_ind <place_par> <cols_par> <values_par>)
 */

void
update_ind_node_compile (comp_context_t * cc,
    caddr_t * stmt, data_source_t ** head_ret,
    data_source_t ** tail_ret)
{
  NODE_INIT (update_node_t, upd, update_node_input, NULL);

  upd->upd_place = cc_name_to_slot (cc, stmt[1], 1);
  upd->upd_cols_param = cc_name_to_slot (cc, stmt[2], 1);
  upd->upd_values_param = cc_name_to_slot (cc, stmt[3], 1);
  upd->upd_place->ssl_type = SSL_PLACEHOLDER;	/* May be a parameter */
}



void
key_insert_compile (comp_context_t * cc,
    caddr_t * stmt, data_source_t ** head_ret,
    data_source_t ** tail_ret)
{
  dbe_key_t *key = sch_table_key (cc->cc_schema, stmt[2], stmt[3], 0);
  NODE_INIT (key_insert_node_t, ins, key_insert_node_input, NULL);

  if (!key)
    sqlc_new_error (cc, "42S12", "SQ058", "No key in key_insert.");

  ins->kins_row = cc_name_to_slot (cc, stmt[1], 1);
  ins->kins_key = key;
}


void
row_insert_compile (comp_context_t * cc,
    caddr_t * stmt, data_source_t ** head_ret,
    data_source_t ** tail_ret)
{
  NODE_INIT (row_insert_node_t, ins, row_insert_node_input, NULL);

  ins->rins_mode = ins_flag (cc, stmt, 2);
  ins->rins_row = cc_name_to_slot (cc, stmt[1], 1);
}


void
delete_node_compile (comp_context_t * cc, caddr_t * stmt,
    data_source_t ** head_ret,
    data_source_t ** tail_ret)
{
  NEW_VARZ (delete_node_t, del);
  data_source_init ((data_source_t *) del, cc, 0);
  del->src_gen.src_input = (qn_input_fn) delete_node_input;
  dk_set_push (&cc->cc_query->qr_nodes, (void *) del);
  del->del_place = cc_name_to_slot (cc, stmt[1], 1);
  del->del_place->ssl_type = SSL_PLACEHOLDER;	/* May be a parameter */

  *head_ret = (data_source_t *) del;
  *tail_ret = (data_source_t *) del;
}


void
ddl_free (ddl_node_t * ddl)
{
  dk_free_tree ((caddr_t) ddl->ddl_stmt);
}


void
ddl_compile (comp_context_t * cc, caddr_t * stmt,
    data_source_t ** head_ret,
    data_source_t ** tail_ret)
{
  NEW_VARZ (ddl_node_t, ddl);
  data_source_init ((data_source_t *) ddl, cc, 0);
  ddl->src_gen.src_input = (qn_input_fn) ddl_node_input;
  ddl->src_gen.src_free = (qn_free_fn) ddl_free;
  ddl->ddl_stmt = (caddr_t *) box_copy_tree ((caddr_t) stmt);

  cc->cc_query->qr_is_ddl = 1;
  dk_set_push (&cc->cc_query->qr_nodes, (void *) ddl);
  *head_ret = (data_source_t *) ddl;
  *tail_ret = (data_source_t *) ddl;

  /* dbg_print_box (stmt, stdout); printf ("\n"); */
}


void
sel_free (select_node_t * sel)
{
  dk_free_box ((caddr_t) sel->sel_out_slots);
}


void
qr_add_current_of_output (query_t * qr)
{
  select_node_t *sel = qr->qr_select_node;
  if (sel)
    {
      state_slot_t **new_out;
      dk_set_t tables = NULL;
      int inx, n_tables, n_old_out = BOX_ELEMENTS (sel->sel_out_slots);
      sel->sel_n_value_slots = n_old_out;
      DO_SET (table_source_t *, ts, &sel->src_gen.src_query->qr_nodes)
      {
	if ((qn_input_fn) table_source_input == ts->src_gen.src_input
	    || (qn_input_fn) table_source_input_unique == ts->src_gen.src_input)
	  {
	    if (ts->ts_current_of)
	      dk_set_push (&tables, (void *) ts->ts_current_of);
	  }
      }
      END_DO_SET ();
      n_tables = dk_set_length (tables);
      tables = dk_set_nreverse (tables);
      new_out = (state_slot_t **) dk_alloc_box (
	  sizeof (caddr_t) * (n_tables + n_old_out), DV_ARRAY_OF_LONG);
      memcpy (new_out, sel->sel_out_slots,
	  box_length ((caddr_t) sel->sel_out_slots));
      for (inx = n_old_out; inx < n_tables + n_old_out; inx++)
	{
	  new_out[inx] = (state_slot_t *) dk_set_pop (&tables);
	}
      dk_free_box ((caddr_t) sel->sel_out_slots);
      sel->sel_out_slots = new_out;
    }
}


void
select_node_compile (comp_context_t * cc, caddr_t * stmt,
    data_source_t ** head_ret,
    data_source_t ** tail_ret)
{
  caddr_t *slots = (caddr_t *) (stmt[1]);
  state_slot_t **out_slots = (state_slot_t **)
  dk_alloc_box (box_length ((caddr_t) slots), DV_ARRAY_OF_LONG);
  int inx;
  NEW_VARZ (select_node_t, sel);
  data_source_init ((data_source_t *) sel, cc, 0);
  for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (slots); inx++)
    {
      out_slots[inx] = cc_name_to_slot (cc, slots[inx], 1);
    }
  sel->src_gen.src_input = (qn_input_fn) select_node_input;
  sel->src_gen.src_free = (qn_free_fn) sel_free;

  SEL_NODE_INIT (cc, sel);

  sel->sel_out_slots = out_slots;

  *head_ret = (data_source_t *) sel;
  *tail_ret = (data_source_t *) sel;
}


typedef void (*eql_comp_func_t) (comp_context_t * cc,
    caddr_t * stmt, data_source_t **, data_source_t **);

typedef struct _eqlcfgstruct
  {
    char *cf_name;
    eql_comp_func_t cf_func;
  }
eql_comp_fn_ent_t;

eql_comp_fn_ent_t eql_comp_funs[] =
{
    {"from", table_source_compile},
    {"insert", insert_node_compile},
    {"delete", delete_node_compile},
    {"end", end_node_compile},
    {"seq", sequence_compile},
    {"select", select_node_compile},
    {"create_table", ddl_compile},
    {"create_sub_table", ddl_compile},
    {"create_unique_index", ddl_compile},
    {"create_index", ddl_compile},
    {"update", update_node_compile},
    {"update_ind", update_ind_node_compile},
    {"current_of", current_of_node_compile},
    {"deref", deref_node_compile},
    {"row_deref", row_deref_node_compile},

    {"add_col", ddl_compile},

    {"build_index", ddl_compile},
    {"drop_index", ddl_compile},

    {"key_insert", key_insert_compile},
    {"row_insert", row_insert_compile},

    {NULL, NULL}
};


void
eql_stmt_comp (comp_context_t * cc,
    caddr_t stmt, data_source_t ** head, data_source_t ** tail)
{
  char *name = ((char **) stmt)[0];
  int inx;
  for (inx = 0; eql_comp_funs[inx].cf_name; inx++)

    if (0 == strcmp (name, eql_comp_funs[inx].cf_name))
      {
	eql_comp_funs[inx].cf_func (cc, (caddr_t *) stmt, head, tail);
	return;
      }
  sqlc_new_error (cc, "42000", "SQ059", "No statement %s", name);
}


void
query_free (query_t * query)
{
}

char *
cd_strip_col_name (char *name)
{
  char *dot;
  if (!name)
    return (box_dv_short_string ("Unnamed"));
  for (;;)
    {
      if (prefix_in_result_col_names)
	dot = name [0] == '.' ? name : NULL;
      else
	dot = strchr (name, '.');
      if (!dot)
	return (box_dv_short_string (name));
      name = dot + 1;
    }

  /*NOTREACHED*/
  return NULL;
}

void
qr_describe_param_names (query_t * qr, stmt_compilation_t *sc, caddr_t *err_ret)
{
  /*client_connection_t *cli = sqlc_client ();*/
  dbe_schema_t *sch = isp_schema (NULL);
  code_vec_t vec;
  int found, n_actual, actual_inx, n_marker, marker_inx;
  instruction_t *ins = NULL;
  state_slot_t **actual_params;
  param_desc_t **param_markers;
  char *proc_name, *full_name;
  query_t *proc;

  param_markers = (param_desc_t **) sc->sc_params;
  if (!param_markers || !qr->qr_head_node || !qr->qr_head_node->src_pre_code)
    return;

  vec = qr->qr_head_node->src_pre_code;
  found = 0;
  DO_INSTR (ins2, 0, vec)
    {
      if (ins2->ins_type == INS_CALL)
	{
	  found = 1;
	  ins = ins2;
	}
    }
  END_DO_INSTR
  if (!found)
    return;

  proc_name = ins->_.call.proc;
  actual_params = ins->_.call.params;
  if (!actual_params || !proc_name || bif_find (proc_name))
    return;

  if (QR_IS_MODULE_PROC (qr))
    {
      char rq[MAX_NAME_LEN], ro[MAX_NAME_LEN], rn[MAX_NAME_LEN];
      sch_split_name (qr->qr_qualifier, qr->qr_module->qr_proc_name, rq, ro, rn);
      /*full_name = sch_full_proc_name_1 (sch, proc_name, rq, CLI_OWNER (cli), rn);*/
      full_name = sch_full_proc_name_1 (sch, proc_name, rq, qr->qr_owner, rn);
    }
  else
    /*full_name = sch_full_proc_name (sch, proc_name, qr->qr_qualifier, CLI_OWNER (cli));*/
    full_name = sch_full_proc_name (sch, proc_name, qr->qr_qualifier, qr->qr_owner);
  if (!full_name)
    return;

  proc = sch_proc_def (sch, full_name);
  if (proc == NULL || IS_REMOTE_ROUTINE_QR (proc))
    return;
  if (proc->qr_to_recompile)
    {
      proc = qr_recompile (proc, err_ret);
      if (err_ret && *err_ret)
	return;
    }

  n_actual = BOX_ELEMENTS (actual_params);
  n_marker = BOX_ELEMENTS (param_markers);
  if (qr->qr_is_call == 2)
    actual_inx = marker_inx = 1;
  else
    actual_inx = marker_inx = 0;

  DO_SET (state_slot_t *, formal, &proc->qr_parms)
    {
      state_slot_t *actual;

      if (marker_inx >= n_marker || actual_inx >= n_actual)
	break;

      actual = actual_params[actual_inx];
      if (actual->ssl_type == SSL_PARAMETER
	  || actual->ssl_type == SSL_REF_PARAMETER
	  || actual->ssl_type == SSL_REF_PARAMETER_OUT)
	{
	  param_markers[marker_inx]->pd_name = box_dv_short_string (formal->ssl_name);
	  marker_inx++;
	}
      actual_inx++;
    }
  END_DO_SET();
}

int
qr_describe_key (dbe_column_t *col)
{
  dbe_table_t *table = col->col_defined_in;
  if (table)
    {
      dbe_key_t *pk = table->tb_primary_key;
      if (pk)
	{
	  int nth = 0;
	  DO_SET (dbe_column_t *, key_col, &pk->key_parts)
	    {
	      if (key_col == col)
		return 1;
	      if (++nth >= pk->key_n_significant)
		break;
	    }
	  END_DO_SET ();
	}
    }
  return 0;
}

stmt_compilation_t *
qr_describe_1 (query_t * qr, caddr_t *err_ret, client_connection_t * cli)
{
  int cdef = 0;
  caddr_t *params;
  int n_params, pinx = 0;
  int dupe_idx = 0;
  stmt_compilation_t *sc = (stmt_compilation_t *)
  dk_alloc_box (sizeof (stmt_compilation_t), DV_ARRAY_OF_POINTER);
  memset (sc, 0, sizeof (stmt_compilation_t));
  n_params = dk_set_length (qr->qr_parms);
  params = (caddr_t *) dk_alloc_box (n_params * sizeof (caddr_t),
      DV_ARRAY_OF_POINTER);
  DO_SET (state_slot_t *, ssl, &qr->qr_parms)
  {
    param_desc_t *pd = (param_desc_t *) dk_alloc_box (sizeof (param_desc_t),
	DV_ARRAY_OF_POINTER);
    memset (pd, 0, sizeof (param_desc_t));
    params[pinx++] = (caddr_t) pd;
    if (DV_UNKNOWN == ssl->ssl_dtp)
      {
	ssl->ssl_dtp = DV_LONG_STRING;
	ssl->ssl_prec = 256;
      }
    pd->pd_dtp = box_num (ssl->ssl_dtp);
    pd->pd_prec = box_num (ssl->ssl_prec);
    pd->pd_scale = box_num (ssl->ssl_scale);
    pd->pd_nullable = ssl->ssl_non_null ? NULL : box_num (1);
    /*pd->pd_name = box_dv_short_string (ssl->ssl_name); */
    pd->pd_iotype = box_num (ssl->ssl_type == SSL_REF_PARAMETER_OUT ? SQL_PARAM_OUTPUT
			     : ssl->ssl_type == SSL_REF_PARAMETER ? SQL_PARAM_INPUT_OUTPUT
			       : ssl->ssl_type == SSL_PARAMETER ? SQL_PARAM_INPUT
				 : SQL_PARAM_TYPE_UNKNOWN);
  }
  END_DO_SET ();
  sc->sc_params = params;
  if (qr->qr_used_cursors)
    {
      sc->sc_cursors_used = (caddr_t *) 1L;
    }
  if (qr->qr_select_node)
    {
      select_node_t *sel = qr->qr_select_node;
      int n_out = sel->sel_n_value_slots, inx;
      col_desc_t **cols = (col_desc_t **)
      dk_alloc_box (n_out * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      for (inx = 0; inx < n_out; inx++)
	{
	  long prec = cdef;
	  col_desc_t *desc = (col_desc_t *) dk_alloc_box_zero (sizeof (col_desc_t),
	      DV_ARRAY_OF_POINTER);
	  state_slot_t *sl = sel->sel_out_slots[inx];
	  dtp_t dtp = sl->ssl_dtp;
	  if (SSL_REF == sl->ssl_type)
	    sl = ((state_slot_ref_t*)sl)->sslr_ssl;
	  cols[inx] = desc;
	  /*if (sl->ssl_name)*/
	    {
	      int dupe_check_idx;
	      desc->cd_name = !SSL_HAS_NAME (sl) ?
		  box_dv_short_string ("unnamed") : cd_strip_col_name (sl->ssl_name);
retry_dupe_check:
	      for (dupe_check_idx = 0; dupe_check_idx < inx; dupe_check_idx++)
		{
		  caddr_t dupe_check_name = cols[dupe_check_idx]->cd_name;
		  if (dupe_check_name && (!strcmp (dupe_check_name, desc->cd_name)))
		    {
		      char tmp_buf[20];
		      caddr_t new_name;
		      dupe_idx++;
		      snprintf (tmp_buf, sizeof (tmp_buf), "__%d", dupe_idx);
		      new_name = dk_alloc_box (box_length (desc->cd_name) + strlen (tmp_buf), DV_STRING);
		      snprintf (new_name, box_length (new_name), "%s%s", desc->cd_name, tmp_buf);
		      dk_free_box (desc->cd_name);
		      desc->cd_name = new_name;
		      goto retry_dupe_check;
		    }
		}
	    }
	  if (sl->ssl_sqt.sqt_is_xml)
	    dtp = DV_BLOB_WIDE;
	  if (sl->ssl_dtp == DV_XML_ENTITY)
	    {
	      dtp = DV_BLOB_WIDE;
	      desc->cd_flags = box_num (CDF_XMLTYPE);
	    }
	  if (sl->ssl_dtp == DV_ARRAY_OF_POINTER && sl->ssl_type == SSL_VEC)
	    dtp = DV_ANY;
	  if (cli && DV_INT64 == dtp && cli->cli_version < 3016)
	    dtp = DV_NUMERIC;
	  desc->cd_dtp = dtp;
	  desc->cd_scale = box_num (sl->ssl_scale);
	  if ((IS_STRING_DTP (dtp) || dtp == DV_BIN) && !prec)
	    prec = ROW_MAX_COL_BYTES;
	  if (IS_WIDE_STRING_DTP (dtp) && !prec)
	    prec = ROW_MAX_COL_BYTES;
	  if (sl->ssl_type == SSL_COLUMN)
	    {
	      dbe_column_t *col = sl->ssl_column;
	      long flags = 0;
	      if (col)
		{
		  desc->cd_base_column_name = box_dv_short_string (col->col_name);
		  if (col->col_defined_in)
		    {
		      desc->cd_base_table_name = box_dv_short_string (col->col_defined_in->tb_name_only);
		      desc->cd_base_schema_name = box_dv_short_string (col->col_defined_in->tb_owner);
		      desc->cd_base_catalog_name = box_dv_short_string (col->col_defined_in->tb_qualifier);
		      if (qr->qr_unique_rows && qr_describe_key (col))
			flags |= CDF_KEY;
		    }
		  if (col->col_precision)
		    prec = col->col_precision;
		  if (col->col_is_autoincrement)
		    flags |= CDF_AUTOINCREMENT;
		  if (col->col_sqt.sqt_is_xml)
		    flags |= CDF_XMLTYPE;
		}
	      desc->cd_updatable = box_num (1);
	      desc->cd_flags = box_num (flags);
	    }
	  /* not always, but still this is the best way */
	  desc->cd_searchable = box_num (IS_BLOB_DTP (dtp) ? 0 : 1);
	  desc->cd_nullable = box_num (sl->ssl_non_null ? 0 : 1);
	  if (sl->ssl_prec)
	    prec = sl->ssl_prec;
	  if (desc->cd_dtp == DV_TIMESTAMP)
	    {
	      prec = 10;
	      desc->cd_scale = box_num (6);
	    }
	  if (desc->cd_dtp == DV_ANY)
  	      prec = ROW_MAX_COL_BYTES;
	  if (IS_BLOB_DTP (desc->cd_dtp))
	    prec = 0x7fffffff;
	  desc->cd_precision = box_num (prec);
	}
      sc->sc_columns = (caddr_t *) cols;
      sc->sc_is_select = QT_SELECT;
    }
  if (qr->qr_is_call)
    {
      sc->sc_is_select = QT_PROC_CALL;
      qr_describe_param_names (qr, sc, err_ret);
      if (err_ret && *err_ret)
	{
	  dk_free_tree ((box_t) sc);
	  return NULL;
	}
    }
  sc->sc_hidden_columns = qr->qr_hidden_columns;
  return sc;
}

stmt_compilation_t *
qr_describe (query_t * qr, caddr_t *err_ret)
{
  return qr_describe_1 (qr, err_ret, NULL);
}


query_t *
eql_compile_eql (const char *string, client_connection_t * cli, caddr_t * err)
{
  caddr_t *text;
  lisp_stream_t stream;
  comp_context_t cc;
  data_source_t *head, *tail;
  NEW_VARZ (query_t, qr);

  CC_INIT (cc, cli);
  qr->qr_qualifier = box_string (sqlc_client ()->cli_qualifier);

  lisp_stream_init (&stream, string);
  text = NULL;

  CATCH (CATCH_LISP_ERROR)
  {
    text = (caddr_t *) lisp_read (&stream);

    /* dbg_print_box (text, stdout); printf ("\n"); */

    if (cli->cli_user && !sec_user_has_group (0, cli->cli_user->usr_g_id))
      {
	sqlc_new_error (&cc, "42000", "SQ060", "Must be in dba group to use EQL.");
      }
    eql_stmt_comp (&cc, (caddr_t) text, &head, &tail);

    qr->qr_head_node = head;

    qr_add_current_of_output (qr);
    QR_POST_COMPILE (qr, (&cc));
    dk_free_tree ((caddr_t) text);
  }
  THROW_CODE
  {
    query_free (qr);
    if (err)
      {
	if (cc.cc_error)
	  *err = cc.cc_error;
	else
	  *err = srv_make_new_error ("42000", "SQ061", "Lisp reader error.");
      }
    return NULL;
  }
  END_CATCH;

  return qr;
}



query_t *
eql_compile_2 (const char *string, client_connection_t * cli, caddr_t * err,
	       int mode)
{
  const char *string1 = string;
  while (*string1 == ' ')
    string1++;
  if (0 == strncmp (string1, "(seq", 4))
    {
      query_t *qr;
      client_connection_t *old_cli = sqlc_client ();
      if (!parse_mtx)
	parse_mtx = mutex_allocate ();
      mutex_enter (parse_mtx);
      sqlc_set_client (cli);
      qr = eql_compile_eql (string, cli, err);
      mutex_leave (parse_mtx);
      sqlc_set_client (old_cli);
      return qr;
    }
  else
    return (sql_compile (string, cli, err, mode));
}


query_t *
eql_compile (const char *string, client_connection_t * cli)
{
  return (eql_compile_2 (string, cli, NULL, SQLC_DEFAULT));
}


void
ssl_constant_init ()
{
  int n;
  constant_ssl = id_hash_allocate (101, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
  for (n = -2; n < 11; n++)
    ssl_sys_constant (box_num (n));
  ssl_sys_constant (box_dv_short_string (""));
  ssl_sys_constant (dk_alloc_box (0, DV_DB_NULL));



}
