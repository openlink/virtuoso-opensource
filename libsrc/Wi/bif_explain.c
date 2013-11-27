/*
 *  bif_explain.c
 *
 *  $Id$
 *
 *  Implements bif 'explain'
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

#include "odbcinc.h"

#include "lisprdr.h"
#include "sqlnode.h"
#include "eqlcomp.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "crsr.h"
#include "security.h"
#include "sqlofn.h"

#include "sqlpfn.h"
#include "remote.h"
#include "sqlrcomp.h"
#include "sqltype.h"
#ifdef BIF_XML
#include "xmlnode.h"
#include "xmltree.h"
#endif
#include "sqlcstate.h"
#include "sqlo.h"
#include "rdfinf.h"
#include "rdf_core.h"
#ifndef WIN32
#include <sys/resource.h>
#endif
#include "http.h"
#include "mhash.h"

int enable_qrc; /* generate query plan comments and warnings */
#define MSG_MAX_LEN 100
#define TA_STAT_COMM 1219

typedef struct qr_comment_s
{
  int qrc_warning; /* a flag for warning if the query has a bad plan */
  int qrc_is_first; /* a flag to indicate whether this is the first node */
  dk_set_t  qrc_wrn_msgs; /* a set of warning messages */
} qr_comment_t;

int dbf_explain_level = 0;

/* sqlprt.c */
void trset_start (caddr_t *qst);
void trset_printf (const char *str, ...);
void trset_end (void);


extern dk_mutex_t * prof_mtx;
extern id_hash_t * qn_prof;

void
qrc_add_wrn_msg(const char *format, ...)
{  
  char buf[MSG_MAX_LEN];
  va_list va;
  du_thread_t * self = THREAD_CURRENT_THREAD;
  qr_comment_t * comm = THR_ATTR (self, TA_STAT_COMM);
  va_start (va, format);
  vsnprintf (buf, sizeof (buf), format, va);
  va_end (va);
  buf[sizeof (buf) - 1] = 0;
  /* milos: add the warning text to the list of warnings */
  if (comm)
  {
    dk_set_push(&comm->qrc_wrn_msgs, (void*)list(1, box_dv_short_string(buf)));
    /* milos: set the warning flag */
    comm->qrc_warning = 1;
  }
}

void
qi_qn_stat_1 (query_instance_t * qi, query_t * qr)
{
  caddr_t * inst = (caddr_t*)qi;
  DO_SET (data_source_t *, qn, &qr->qr_nodes)
    {
      if (qn->src_stat)
	{
	  boxint sets = qn->src_sets;
	  src_stat_t * srs;
	  src_stat_t * qsrs = SRC_STAT (qn, inst);
	  mutex_enter (prof_mtx);
	  srs = (src_stat_t*)id_hash_get (qn_prof, (caddr_t)&sets);
	  if (srs)
	    {
	      srs->srs_cum_time += qsrs->srs_cum_time;
	      srs->srs_n_in += qsrs->srs_n_in;
	      srs->srs_n_out += qsrs->srs_n_out;
	    }
	  else
	    id_hash_set (qn_prof, (caddr_t)&sets, (caddr_t)qsrs);
	  mutex_leave (prof_mtx);
	}
      if (IS_QN (qn, subq_node_input))
	{
	  qi_qn_stat_1 (qi, ((subq_source_t*)qn)->sqs_query);
	}
      else if (IS_QN (qn, trans_node_input))
	{
	  QNCAST (trans_node_t, tn, qn);
	  if (tn->tn_inlined_step)
	    qi_qn_stat_1 (qi, tn->tn_inlined_step);
	  if (tn->tn_complement)
	    qi_qn_stat_1 (qi, tn->tn_complement->tn_inlined_step);
	}
    }
  END_DO_SET();
  DO_SET (query_t *, sq, &qr->qr_subq_queries)
    qi_qn_stat_1 (qi, sq);
  END_DO_SET();
}


void
qi_qn_stat (query_instance_t * qi)
{
  query_t * qr = qi->qi_query;
  qi_qn_stat_1 (qi, qr);
  if (qi->qi_log_stats)
    qi_log_stats (qi, NULL);
}


int64
qr_qn_total (query_t * qr)
{
  int64 sum = 0;
  DO_SET (data_source_t *, qn, &qr->qr_nodes)
    {
      if (qn->src_stat)
	{
	  boxint sets = qn->src_sets;
	  src_stat_t * srs;
	  mutex_enter (prof_mtx);
	  srs = (src_stat_t*)id_hash_get (qn_prof, (caddr_t)&sets);
	  if (srs)
	    {
	      sum += srs->srs_cum_time;
	    }
	  mutex_leave (prof_mtx);
	}
      if (IS_QN (qn, subq_node_input))
	{
	  sum += qr_qn_total (((subq_source_t*)qn)->sqs_query);
	}
      else if (IS_QN (qn, trans_node_input))
	{
	  QNCAST (trans_node_t, tn, qn);
	  if (tn->tn_inlined_step)
	    sum += qr_qn_total (tn->tn_inlined_step);
	  if (tn->tn_complement)
	    sum += qr_qn_total (tn->tn_complement->tn_inlined_step);
	}
    }
  END_DO_SET();
  /* do not add up subqs from scalar/exists, their total figures in the node that has them in code */
#if 0
  DO_SET (query_t *, sq, &qr->qr_subq_queries)
    sum += qr_qn_total (sq);
  END_DO_SET();
#endif
  return sum;
}


#define stmt_printf(a) trset_printf a

static void qr_print (query_t * qr);
static void node_print (data_source_t * node);


void
ssl_type (state_slot_t * ssl, char * str)
{
  str[2] = 0;
  switch (dtp_canonical[ssl->ssl_sqt.sqt_dtp])
    {
    case DV_LONG_INT: str[0] = 'i';  break;
    case DV_IRI_ID: str[0] = 'r';  break;
    case DV_SINGLE_FLOAT: str[0] = 'f';  break;
    case DV_DOUBLE_FLOAT: str[0] = 'd';  break;
    case DV_DATE: case DV_TIME: case DV_TIMESTAMP:
    case DV_DATETIME: str[0] = 't';  break;
    case DV_STRING: str[0] = 's'; break;
    case DV_ANY: str[0] = 'a'; break;
    case DV_WIDE: case DV_LONG_WIDE:
      str[0] = 'N'; break;
    default: str[0] = 'x';
    }
  str[1] = ssl->ssl_sqt.sqt_non_null ? 'n'  : 0;
}



caddr_t
dv_iri_short_name (caddr_t x)
{
  caddr_t pref, local, r;
  iri_id_t iid = unbox_iri_id (x);
  caddr_t name = key_id_to_iri ((query_instance_t*)THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_QST), iid);
  if (!name)
    return NULL;
  if (iri_split (name, &pref, &local))
    {
      int inx;
      caddr_t r;
      dk_free_box (name);
      dk_free_box (pref);
      for (inx = box_length (local) - 1; inx > 3; inx--)
	if (':'== local[inx] || '/' == local[inx] || '#'== local[inx])
	  break;
      if (inx > 4)
	{
	  r = box_dv_short_nchars (local + 4, inx - 4);
	  dk_free_box (local);
	  return r;
	}
      return local;
    }
  dk_free_box (name);
  return NULL;
}


static void
ssl_print (state_slot_t * ssl)
{
  char str[3];
  if (!ssl)
    {
      stmt_printf ((" <none> "));
      return;
    }
  if (CV_CALL_PROC_TABLE == ssl)
    {
      stmt_printf ((" <proc table> "));
      return;
    }
  else if (CV_CALL_VOID == ssl)
    {
      stmt_printf ((" <void proc> "));
      return;
    }
  switch (ssl->ssl_type)
    {
    case SSL_PARAMETER:
    case SSL_COLUMN:
    case SSL_VARIABLE:
      stmt_printf (("$%d \"%s\"", ssl->ssl_index, ssl->ssl_name ? ssl->ssl_name : "-"));
      break;
    case SSL_VEC:
      if (0 == dbf_explain_level)
	{
	  stmt_printf (("%s", ssl->ssl_name ? ssl->ssl_name : (snprintf (str, sizeof (str), "$%d", ssl->ssl_index), str)));
	  break;
	}
      ssl_type (ssl, str);
      if (ssl->ssl_sets)
	stmt_printf (("<v $%d %s S%d %s>", ssl->ssl_index, ssl->ssl_name, ssl->ssl_sets, str));
      else
	stmt_printf (("<V $%d %s %s>", ssl->ssl_index, ssl->ssl_name, str));
      break;
    case SSL_REF:
      {
	QNCAST (state_slot_ref_t, sslr, ssl);
	int inx;
	if (0 == dbf_explain_level)
	  {
	    ssl_print (sslr->sslr_ssl);
	    break;
	  }
	stmt_printf (("<r $%d %s via ", sslr->sslr_index, sslr->sslr_ssl && sslr->sslr_ssl->ssl_name ? sslr->sslr_ssl->ssl_name : ""));
	for (inx = 0; inx < sslr->sslr_distance; inx++)
	  stmt_printf ((" S%d", sslr->sslr_set_nos[inx]));
	stmt_printf ((">"));
	break;
      }
    case SSL_CONSTANT:
	{
	  caddr_t err_ret = NULL;
	  dtp_t dtp = DV_TYPE_OF (ssl->ssl_constant);
	  if (DV_DB_NULL == dtp)
	    stmt_printf (("<DB_NULL>"));
	  else if (DV_RDF == dtp)
	    {
	      rdf_box_t * rb = (rdf_box_t*)ssl->ssl_constant;
	      stmt_printf (("rdflit" BOXINT_FMT, rb->rb_ro_id));
	    }
	  else
	    {
	      caddr_t strval = box_cast_to (NULL, ssl->ssl_constant,
					    dtp, DV_SHORT_STRING,
		  NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE,
		  &err_ret);
	      if (!err_ret && strval)
		{
		  switch (dtp)
		    {
		      case DV_IRI_ID:
			    {
			      caddr_t str = dv_iri_short_name (ssl->ssl_constant);
			      if (str)
				{
				  stmt_printf ((" #" EXPLAIN_LINE_MAX_STR_FORMAT " ", str));
				  dk_free_box (str);
				  break;
				}
			    }
		      case DV_LONG_INT: case DV_NUMERIC: case DV_SINGLE_FLOAT: case DV_DOUBLE_FLOAT:
			  stmt_printf ((" " EXPLAIN_LINE_MAX_STR_FORMAT " ", strval));
			  break;
		      default:
			  stmt_printf (("<c " EXPLAIN_LINE_MAX_STR_FORMAT ">", strval));
		    }
		}
	      else
		stmt_printf (("<constant>"));
	      if (err_ret)
		dk_free_tree (err_ret);
	      if (strval)
		dk_free_box (strval);
	    }
	}
      break;

    default:
      stmt_printf (("<$%d \"%s\" spec %d>", ssl->ssl_index,
	  ssl->ssl_name ? ssl->ssl_name : "-", ssl->ssl_type));
      break;
    }
}


void
ssl_array_print (state_slot_t ** ssls)
{
  int inx, first = 1;
  stmt_printf (("("));
  DO_BOX (state_slot_t *, ssl, inx, ssls)
  {
    if (first)
      first = 0;
    else
      stmt_printf ((", "));
    ssl_print (ssl);
  }
  END_DO_BOX;
  stmt_printf ((")"));
}


static void
ssl_list_print (dk_set_t ssls)
{
  int first = 1;
  stmt_printf (("("));
  DO_SET (state_slot_t *, ssl, &ssls)
  {
    if (first)
      first = 0;
    else
      stmt_printf ((", "));
    ssl_print (ssl);
  }
  END_DO_SET ();
  stmt_printf ((")"));
}


void
code_vec_print (code_vec_t cv)
{
  int comp_inx;
  int compound_level = 0;
  char *strptr;
  DO_INSTR (in, 0, cv)
    {
      if (in->ins_type == INS_COMPOUND_END)
	compound_level--;
      for  (comp_inx = 0; comp_inx < compound_level; comp_inx++)
	stmt_printf (("  "));
      stmt_printf (("      %d: ", (int) INSTR_OFS (in, cv)));
      switch (in->ins_type)
	{
	case IN_ARTM_FPTR: strptr = "<UNKNOWN>"; goto artm_print;
	case IN_ARTM_PLUS: strptr = "+"; goto artm_print;
	case IN_ARTM_MINUS: strptr = "-"; goto artm_print;
	case IN_ARTM_TIMES: strptr = "*"; goto artm_print;
	case IN_ARTM_DIV: strptr = "/"; goto artm_print;
	case IN_ARTM_IDENTITY: strptr = ":=";
artm_print:
	  ssl_print (in->_.artm.result);
	  if (!in->_.artm.right)
	    stmt_printf ((" %s ", strptr));
	  stmt_printf ((" := artm "));
	  ssl_print (in->_.artm.left);
	  if (in->_.artm.right)
	    {
	      stmt_printf ((" %s ", strptr));
	      ssl_print (in->_.artm.right);
	    }
	  break;
	case IN_AGG:
	  {
	    int op = in->_.agg.op;
	    char * name = AMMSC_SUM == op ? "sum": AMMSC_COUNTSUM == op ? "countsum": AMMSC_COUNT == op ? "count": AMMSC_MIN == op ? "min": AMMSC_MAX == op ? "max" : AMMSC_ONE == op ? "subq_value": "unknown ";
	    stmt_printf ((" %s ", name));
	    ssl_print (in->_.agg.result);
	    ssl_print (in->_.agg.arg);
	    if (in->_.agg.set_no)
	      {
		stmt_printf (("set no "));
		ssl_print (in->_.agg.set_no);
	      }
	    if (in->_.agg.distinct)
	      {
		stmt_printf (("distinct "));
		ssl_print (in->_.agg.distinct->ha_tree);
	      }
	    break;
	  }
	case IN_PRED:
	  {
	    stmt_printf (("if ("));
	    if (in->_.pred.func == subq_comp_func)
	      {
		subq_pred_t *subp = (subq_pred_t *) in->_.pred.cmp;
		qr_print (subp->subp_query);
	      }
	    else if (in->_.pred.func == bop_comp_func)
	      {
		bop_comparison_t *bop = (bop_comparison_t *) in->_.pred.cmp;
		ssl_print (bop->cmp_left);
		stmt_printf ((" %s ", bop_text (bop->cmp_op)));
		ssl_print (bop->cmp_right);
	      }
	    else if (in->_.pred.func == distinct_comp_func)
	      {
		stmt_printf ((" DISTINCT "));
		ssl_array_print (((hash_area_t *) in->_.pred.cmp)->ha_slots);
	      }
	    if (in->_.pred.end)
	      stmt_printf ((") then %d else %d unkn %d merge %d",
			    in->_.pred.succ, in->_.pred.fail, in->_.pred.unkn, in->_.pred.end));
	    else
	    stmt_printf ((") then %d else %d unkn %d",
		in->_.pred.succ, in->_.pred.fail, in->_.pred.unkn));
	    break;
	  }

	case IN_COMPARE:
	  {
	    stmt_printf (("if ("));
	    ssl_print (in->_.cmp.left);
	    stmt_printf ((" %s ", cmp_op_text (in->_.cmp.op)));
	    ssl_print (in->_.cmp.right);
	    if (in->_.cmp.end)
	      stmt_printf ((") then %d else %d unkn %d merge %d",
			    in->_.cmp.succ, in->_.cmp.fail, in->_.cmp.unkn, in->_.cmp.end));
	    else
	    stmt_printf ((") then %d else %d unkn %d",
			  in->_.cmp.succ, in->_.cmp.fail, in->_.cmp.unkn));
	    break;
	  }
	case INS_SUBQ:
	  {
	    qr_print (in->_.subq.query);
	    break;
	  }
	case IN_VRET:
	  stmt_printf (("VReturn "));
	  ssl_print (in->_.vret.value);
	  break;

	case IN_BRET:
	  stmt_printf (("BReturn %d", in->_.bret.bool_value));
	  break;

	case INS_CALL:
	case INS_CALL_BIF:
	  if (in->_.call.ret != (state_slot_t *)1)
	    {
	      ssl_print (in->_.call.ret);
	      stmt_printf ((" := Call %s ", in->_.call.proc));
	      ssl_array_print (in->_.call.params);
	    }
	  else
	    {
	      unsigned _inx, _first = 1;
	      state_slot_t **ssls = in->_.call.params;
	      stmt_printf (("{ "));
	      ssl_print (in->_.call.params[0]);
	      stmt_printf ((" := Call %s (", in->_.call.proc));
	      for (_inx = 1; _inx < (ssls ? BOX_ELEMENTS (ssls) : 0); _inx++)
		{
		  state_slot_t *ssl = (state_slot_t *)ssls[_inx];
		  if (_first)
		    _first = 0;
		  else
		    stmt_printf ((", "));
		  ssl_print (ssl);
		}
	      stmt_printf ((") }"));
	    }
	  break;

	case INS_OPEN:
	  stmt_printf (("Open "));
	  ssl_print (in->_.open.cursor);
	  qr_print (in->_.open.query);
	  break;

	case INS_FETCH:
	  stmt_printf (("Fetch "));
	  ssl_print (in->_.fetch.cursor);
	  ssl_array_print (in->_.fetch.targets);
	  break;

	case INS_HANDLER:
	  if (in->_.handler.label != -1)
	    stmt_printf (("declare handler end at %d", in->_.handler.label));
	  else
	    stmt_printf (("declare DEFAULT handler "));
	    {
	      int inx;
	      DO_BOX (caddr_t *, state, inx, in->_.handler.states)
		{
		  if (IS_BOX_POINTER (state))
		    stmt_printf ((" state %s, ", state[0]));
		  else
		    stmt_printf ((" NO DATA_FOUND, "));
		}
	      END_DO_BOX;
	    }
	  break;

	case INS_HANDLER_END:
	  stmt_printf (("end_handler code Type=%s",
		in->_.handler_end.type == HANDT_EXIT ? "EXIT" : "CONTINUE"));
	  break;

	case INS_COMPOUND_START:
	  compound_level++;
	  stmt_printf (("Comp start (level=%d, line=%d, src=%s:%d)",
		compound_level,
		in->_.compound_start.line_no,
		in->_.compound_start.file_name ? in->_.compound_start.file_name : "",
		in->_.compound_start.l_line_no
		));
	  break;

	case INS_COMPOUND_END:
	  /*compound_level--;*/
	  stmt_printf (("Comp end (level=%d)", compound_level));
	  break;

	case IN_JUMP:
	  stmt_printf (("Jump %d (level=%d)", in->_.label.label, in->_.label.nesting_level));
	  break;

	case INS_QNODE:
	    {
	      data_source_t *new_node = (data_source_t *)in->_.qnode.node;
	      dk_set_t conts = new_node->src_continuations;
	      new_node->src_continuations = NULL;
	      stmt_printf (("QNode {\n"));
	      node_print (new_node);
	      stmt_printf (("}\n"));
	      new_node->src_continuations = conts;
	    }
	  break;
	case INS_BREAKPOINT:
	   {
	     stmt_printf (("Brkp #%d", (int) in->_.breakpoint.line_no));
	   }
	 break;
	case INS_FOR_VECT:
	  stmt_printf (("for vectored "));
	  ssl_array_print (in->_.for_vect.in_vars);
	  ssl_array_print (in->_.for_vect.in_values);
	  ssl_array_print (in->_.for_vect.out_vars);
	  ssl_array_print (in->_.for_vect.out_values);
	  stmt_printf (("\n{\n"));
	  code_vec_print (in->_.for_vect.code);
	  stmt_printf (("\n}\n"));
	  break;
	default:;
	}
      stmt_printf (("\n"));
    }
  END_DO_INSTR;
}


const char *
cmp_op_text (int cmp)
{
  switch (cmp)
    {
    case CMP_EQ:
      return ("=");

    case CMP_LT:
      return ("<");

    case CMP_LTE:
      return "<=";

    case CMP_GT:
      return (">");

    case CMP_GTE:
      return (">=");

    case CMP_NULL:
      return ("IS NULL");

    case CMP_LIKE:
      return ("LIKE");
    }

  return ("<unknown op>");
}


void
hrng_print (hash_range_spec_t * hrng, search_spec_t * sp)
{
  hash_source_t * hs;
  stmt_printf (("hash partition%s by %d ", (hrng->hrng_flags & HR_RANGE_ONLY) ? "" : "+bloom", hrng->hrng_min));
  ssl_array_print (hrng->hrng_ssls);
  if ((hs = hrng->hrng_hs))
    {
      stmt_printf (("hash join merged %s card %9.2g", hs->hs_merged_into_ts ? "always": "if unique", hs->hs_cardinality));
      if (sp->sp_col)
	stmt_printf (("% ", sp->sp_col->col_name));
      else
	ssl_array_print (hs->hs_ref_slots);
      stmt_printf ((" -> "));
      ssl_array_print (hs->hs_out_slots);
    }
  stmt_printf (("\n"));
}

static void
sp_list_print (search_spec_t * sp)
{
  while (sp)
    {

      if (sp->sp_col)
	stmt_printf ((" %s", sp->sp_col->col_name));
      else
	stmt_printf (("col#%ld", sp->sp_cl.cl_col_id));
      if (sp->sp_min_op != CMP_NONE)
	{
	  stmt_printf ((" %s ", cmp_op_text (sp->sp_min_op)));
	  ssl_print (sp->sp_min_ssl);
	}
      if (sp->sp_max_op != CMP_NONE)
	{
	  stmt_printf ((" %s ", cmp_op_text (sp->sp_max_op)));
	  ssl_print (sp->sp_max_ssl);
	}

      if (sp->sp_collation)
	{
	  stmt_printf ((" collate : <%s> ", sp->sp_collation->co_name));
	}
      if (sp->sp_next)
	stmt_printf ((" "));

      if ((sp = sp->sp_next))
	stmt_printf ((", "));
    }
}


void
ks_print_vec_cast (state_slot_t ** casts, state_slot_ref_t ** source)
{
  int first = 1, inx;
  DO_BOX (state_slot_t *, cast, inx, casts)
    {
      if (cast)
	{
	  if (first)
	    {
	      stmt_printf (("vector param casts: "));
	    }
	  else
	    stmt_printf ((", "));
	  ssl_print ((state_slot_t*)source[inx]);
	  stmt_printf (("-> "));
	  ssl_print (cast);
	  first = 0;
	}
    }
  END_DO_BOX;
  if (!first)
    stmt_printf (("\n"));
}


static void
ks_print_0 (key_source_t * ks)
{
  int any = 0;
  if (ks->ks_from_temp_tree || !ks->ks_key)
    stmt_printf (("Key from temp "));
  ssl_list_print (ks->ks_out_slots);
  if (ks->ks_v_out_map)
    {
      int inx;
      for (inx = 0; inx < box_length ((caddr_t)ks->ks_v_out_map) / sizeof (v_out_map_t); inx++)
	if (dc_itc_delete == ks->ks_v_out_map[inx].om_ref)
	  stmt_printf (("deleting "));
    }
  stmt_printf (("\n%s", ks->ks_spec.ksp_key_cmp ? " inlined " : ""));

  sp_list_print (ks->ks_spec.ksp_spec_array);
  if (ks->ks_row_spec)
    sp_list_print (ks->ks_row_spec);
  if (ks->ks_hash_spec)
    {
      DO_SET (search_spec_t *, sp, &ks->ks_hash_spec)
	{
	  hash_range_spec_t * hrng = (hash_range_spec_t *)sp->sp_min_ssl;
	  if (hrng->hrng_hs || hrng->hrng_ht_id || hrng->hrng_ht)
	    {
	      if (!any)
		{
		  stmt_printf (("\n"));
		  any = 1;
		}
	      hrng_print (hrng, sp);
	    }
	}
      END_DO_SET();
    }
  if (!any)
    stmt_printf (("\n"));
  if (ks->ks_local_test)
    {
      stmt_printf ((" Local Test\n"));
      code_vec_print (ks->ks_local_test);
    }
  if (ks->ks_local_code)
    {
      stmt_printf ((" Local Code\n"));
      code_vec_print (ks->ks_local_code);
    }
}

/* milos: function which is used to detect a bad plan (possible Cartesian product) and set a warning with appropriate message */
static int
ssl_is_column_derived(state_slot_t * ssl)
{
  return SSL_VEC == ssl->ssl_type && ssl->ssl_column;
}

/* milos: function which is used to detect a bad plan (possible Cartesian product) and set a warning with appropriate message */
static int
ks_is_column_derived(key_source_t * ks)
{
  int inx;
  search_spec_t * sp;

  for(sp = ks->ks_spec.ksp_spec_array; sp; sp=sp->sp_next)
  {
  	if(ssl_is_column_derived(sp->sp_min_ssl) || ssl_is_column_derived(sp->sp_max_ssl)) 
  		return 1;
  }

  for(sp = ks->ks_row_spec; sp; sp=sp->sp_next)
  {
  	if(ssl_is_column_derived(sp->sp_min_ssl) || ssl_is_column_derived(sp->sp_max_ssl)) 
  		return 1;      	
  }

  DO_BOX(state_slot_t *, ssl, inx, ks->ks_vec_source)
	if(ssl_is_column_derived(ssl)) 
		return 1;
  END_DO_BOX;
	
  DO_BOX(state_slot_t *, ssl, inx, ks->ks_vec_cast)
	if(ssl_is_column_derived(ssl)) 
		return 1;
  END_DO_BOX;
  return 0;
}

static void
ks_print (key_source_t * ks)
{  
  /* milos: check if there is a bad plan (a possible Cartesian product), and create a warning */
  du_thread_t * self = THREAD_CURRENT_THREAD;
  qr_comment_t * comm = THR_ATTR (self, TA_STAT_COMM);
  if(comm)
  	if(!(comm->qrc_is_first) && (!ks_is_column_derived(ks)))
  	  qrc_add_wrn_msg("Warning: You might have a Cartesian product.\n");

  if (ks->ks_from_temp_tree || !ks->ks_key)
    stmt_printf (("Key from temp "));
  else

    stmt_printf (("Key %s  %s %s %s", ks->ks_key->key_name,
		  ks->ks_descending ? "DESC" : "ASC", ks->ks_is_deleting ? "deleting" : "", ks->ks_oby_order && !ks->ks_vec_asc_eq ? "no vec sort" : ""));
  ssl_list_print (ks->ks_out_slots);
  if (ks->ks_v_out_map)
    {
      int inx;
      for (inx = 0; inx < box_length ((caddr_t)ks->ks_v_out_map) / sizeof (v_out_map_t); inx++)
	if (dc_itc_delete == ks->ks_v_out_map[inx].om_ref)
	  stmt_printf (("deleting "));
    }
  stmt_printf (("\n%s", ks->ks_spec.ksp_key_cmp ? " inlined " : ""));

  sp_list_print (ks->ks_spec.ksp_spec_array);
  stmt_printf (("%s\n", ks->ks_copy_search_pars ? " [copies params]" : ""));

  if (ks->ks_row_spec)
    {
      stmt_printf (("row specs: "));
      sp_list_print (ks->ks_row_spec);
      stmt_printf (("\n"));
     
    }
  if (ks->ks_hash_spec)
    {
      stmt_printf (("Hash filters: "));
      DO_SET (search_spec_t *, sp, &ks->ks_hash_spec)
	hrng_print ((hash_range_spec_t*)sp->sp_min_ssl, sp);
      END_DO_SET();
      stmt_printf (("\n"));      
    }
  if (ks->ks_vec_cast)
    ks_print_vec_cast (ks->ks_vec_cast, ks->ks_vec_source);
  if (ks->ks_cl_local_cast)
    {
      stmt_printf (("local cast: "));
      ssl_array_print (ks->ks_cl_local_cast);
      stmt_printf (("\n"));
    }
  if (ks->ks_local_test)
    {
      stmt_printf ((" Local Test\n"));
      code_vec_print (ks->ks_local_test);
    }
  if (ks->ks_local_code)
    {
      stmt_printf ((" Local Code\n"));
      code_vec_print (ks->ks_local_code);
    }
  if (ks->ks_setp)
    {
      stmt_printf ((" Local setp:\n"));
      node_print ((data_source_t *) ks->ks_setp);
    }
}

uint64 qi_total_rdtsc (query_instance_t * qi);


void
node_stat (data_source_t * qn)
{
  boxint sets = qn->src_sets;
  int64 total;
  src_stat_t * srs;
  caddr_t * ctx_inst;
  if (!qn->src_stat || !prof_on)
    return;
  ctx_inst = THR_ATTR (THREAD_CURRENT_THREAD, TA_STAT_INST);
  if (ctx_inst)
    srs = (src_stat_t *)&ctx_inst[qn->src_stat];
  else
  srs = (src_stat_t*)id_hash_get (qn_prof, (caddr_t)&sets);
  if (!srs)
    return;
  total = (int64)THR_ATTR (THREAD_CURRENT_THREAD, TA_TOTAL_RDTSC);
  if (IS_QN (qn, query_frag_input) && ctx_inst)
    {
      QNCAST (query_frag_t, qf, qn);
      int64 rt = ((QI*)ctx_inst)->qi_client->cli_run_clocks;
      stmt_printf (("wait time %9.2g%% of exec real time, fanout %9.6g\n",  (float)QST_INT (ctx_inst, qf->qf_wait_clocks) * 100 / (float)rt, srs->srs_n_in ? srs->srs_n_out / (float)srs->srs_n_in : 0.0));
    }
  else
    stmt_printf (("time %9.2g%% fanout %9.6g input %9.6g rows\n",  (float)srs->srs_cum_time * 100 / (float)total, srs->srs_n_in ? srs->srs_n_out / (float)srs->srs_n_in : 0.0, (float)srs->srs_n_in));
  if (IS_TS (qn) || IS_QN (qn, hash_source_input))
    {
  	  float guess = IS_TS (qn) ? ((table_source_t *)qn)->ts_cardinality : ((hash_source_t *)qn)->hs_cardinality;
  	  float fanout = srs->srs_n_in ? srs->srs_n_out / (float)srs->srs_n_in : 0.0;
  	  if(enable_qrc && (guess/fanout >= 10.0 || guess/fanout <= 0.1))
  		stmt_printf (("Warning: the cardinality estimate of the cost model differs greatly from the measured time. Cardinality estimate: %9.2g Fanout: %9.2g\n",  guess, fanout));
    }
}


static void
node_print_next (data_source_t * node)
{
  if (node->src_continuations)
    node_print ((data_source_t *) node->src_continuations->data);
}


void
ts_print_0 (table_source_t * ts)
{
  char card[50];
  char max_rows[30];
  snprintf (card, sizeof (card), "%9.2g rows", ts->ts_cardinality);
  max_rows[0] = 0;
  if (!ts->ts_order_ks->ks_from_temp_tree && ts->ts_order_ks->ks_key)
    {
      char card[50];
      if (ts->ts_is_unique)
	snprintf (card, sizeof (card), "unq %9.2g rows ", ts->ts_cardinality);
      else
	snprintf (card, sizeof (card), "%9.2g rows", ts->ts_cardinality);
      stmt_printf (("%s %s",
		    ts->ts_order_ks->ks_key->key_name, card));
    }
  ks_print_0 (ts->ts_order_ks);
  if (ts->ts_alternate)
    {
      stmt_printf (("Alternate ts {\n"));
      node_print ((data_source_t *) ts->ts_alternate);
      stmt_printf (("\n}\n"));
    }
  {
  /* milos: clear the 'first' flag */
    du_thread_t * self = THREAD_CURRENT_THREAD;
    qr_comment_t * comm = THR_ATTR (self, TA_STAT_COMM);
    if(comm) comm->qrc_is_first = 0;
  }  
}

void
ts_print (table_source_t * ts)
{
  int inx;
  if (ts->ts_inx_op)
    {
      char card[50];
      inx_op_t * iop = ts->ts_inx_op;
      snprintf (card, sizeof (card), "%9.2g rows%s", ts->ts_cardinality, ts->ts_card_measured ? "by sample" : "");
      stmt_printf (("  Index AND %s {\n", card));
      DO_BOX (inx_op_t *, term, inx, iop->iop_terms)
	{
	  stmt_printf (("from %s by %s\n",
			term->iop_ks->ks_key->key_table->tb_name,
			term->iop_ks->ks_key->key_name));

	  ks_print (term->iop_ks);
	  stmt_printf (("\n  start spec: %s ", term->iop_ks_start_spec.ksp_key_cmp ? " inlined " : ""));
	  sp_list_print (term->iop_ks_start_spec.ksp_spec_array);
	  stmt_printf (("\n  full spec: %s ", term->iop_ks_full_spec.ksp_key_cmp ? "inlined " : ""));
	  sp_list_print (term->iop_ks_full_spec.ksp_spec_array);
	  if (iop->iop_ks_row_spec)
	    {
	      stmt_printf (("\n  row spec: "));
	      sp_list_print (term->iop_ks_row_spec);
	    }
	  stmt_printf (("\n"));
	}
      END_DO_BOX;
      stmt_printf ((" }\n"));
    }
  else
    {
      char card[50];
      char max_rows[30];
      snprintf (card, sizeof (card), "%9.2g rows", ts->ts_cardinality);
      if (ts->ts_aq)
	snprintf (&card[strlen (card)], sizeof (card) - strlen (card), " Parallel, tail cost %9.2g", ts->ts_cost_after);
      if (ts->ts_max_rows)
	snprintf (max_rows, sizeof (max_rows), "max %d", ts->ts_max_rows);
      else
	max_rows[0] = 0;
      if (!ts->ts_order_ks->ks_from_temp_tree && ts->ts_order_ks->ks_key)
	{
	  char idstr[20];
	  char card[50];
	  if (ts->ts_is_unique)
	    snprintf (card, sizeof (card), "unq %9.2g rows ", ts->ts_cardinality);
	  else
      snprintf (card, sizeof (card), "%9.2g rows", ts->ts_cardinality);
	  if (ts->ts_aq)
	    snprintf (&card[strlen (card)], sizeof (card) - strlen (card), " Parallel, tail cost %9.2g", ts->ts_cost_after);
	  if (ts->clb.clb_fill)
	    sprintf (idstr, "fill=%d", ts->clb.clb_fill);
	  else
	    idstr[0] = 0;
	  stmt_printf (("from %s by %s %s %s %s %s %s\n",
			ts->ts_order_ks->ks_key->key_table->tb_name,
			ts->ts_order_ks->ks_key->key_name,
			ts->ts_is_outer ? "OUTER" : "",
			card,
			ts->clb.clb_fill ? (ts->ts_order_ks->ks_cl_order ? "cluster" : "cluster  unordered") : "", idstr, max_rows));
	}
      ks_print (ts->ts_order_ks);
      if (ts->clb.clb_fill)
	{
	  stmt_printf (("    Cluster save ctx: "));
	  ssl_array_print (ts->clb.clb_save);
	  stmt_printf (("\n"));
	}
      if (ts->ts_branch_ssls && dbf_explain_level > 2)
	{
	  int inx;
	  stmt_printf (("copy on branch"));
	  DO_BOX (state_slot_t *, ssl, inx, ts->ts_branch_ssls)
	    stmt_printf ((" $%d", ssl ? ssl->ssl_index : 0));
	  END_DO_BOX;
	  stmt_printf ((" sets: "));
	  for (inx = 0; inx < box_length (ts->ts_branch_sets) / sizeof (ssl_index_t); inx++)
	    stmt_printf (("%d ", (int)ts->ts_branch_sets[inx]));
	  stmt_printf (("\n"));
	}
    }
  if (ts->ts_main_ks)
    ks_print (ts->ts_main_ks);
  if (0 && ts->ts_current_of && ts->ts_current_of != ts->ts_order_cursor && !ts->ts_current_of->ssl_is_alias)
    {
      stmt_printf (("\nCurrent of: "));
      ssl_print (ts->ts_current_of);
    }
  if (ts->ts_after_join_test)
    {
      stmt_printf (("After Join Test\n"));
      code_vec_print (ts->ts_after_join_test);
    }
  stmt_printf (("\n"));
  if (ts->ts_alternate)
    {
      stmt_printf (("Alternate ts {\n"));
      node_print ((data_source_t *) ts->ts_alternate);
      stmt_printf (("\n}\n"));
    }
  {
  /* milos: clear the 'first' flag */
    du_thread_t * self = THREAD_CURRENT_THREAD;
    qr_comment_t * comm = THR_ATTR (self, TA_STAT_COMM);
    if(comm) comm->qrc_is_first = 0;
  }  
}


void
ik_print (ins_key_t * ik)
{
  stmt_printf (("key %s ", ik->ik_key->key_name));
  if (ik->ik_del_slots)
    {
      stmt_printf (("delete "));
      ssl_array_print (ik->ik_del_slots);
      stmt_printf (("\n"));
    }
  if (ik->ik_slots)
    {
      stmt_printf (("insert "));
      ssl_array_print (ik->ik_slots);
      stmt_printf (("\n"));
    }
}

void
qn_print_reuse (data_source_t * qn)
{
  if (qn->src_vec_reuse)
    {
      ssl_index_t * reuse = qn->src_vec_reuse;
      int len = box_length (qn->src_vec_reuse) / sizeof (ssl_index_t);
      int inx = 0, inx2;
      while (inx < len)
	{
	  stmt_printf (("$%d (", reuse[inx]));
	  for (inx2 = 0; inx2 < reuse[inx + 1]; inx2++)
	    stmt_printf (("%d ", reuse[inx + inx2 + 2]));
	  stmt_printf ((") "));

	  inx += reuse[inx + 1] + 2;
	}
    }
}

const char *
predicate_name_of_gsop (int gsop)
{
  switch (gsop)
    {
    case GSOP_CONTAINS:		return "st_contains"		; break;
    case GSOP_WITHIN:		return "st_within"		; break;
    case GSOP_INTERSECTS:	return "st_intersects"		; break;
    case GSOP_MAY_INTERSECT:	return "st_may_intersect"	; break;
    default:			return "???"			; break;
    }
}


void
node_print_0 (data_source_t * node)
{
  qn_input_fn in;
  in = node->src_input;
  if (IS_TS (node))
    {
      ts_print_0 ((table_source_t *) node);
    }
  else if (IS_QN (node, ts_split_input))
	{
      QNCAST (ts_split_node_t, tssp, node);
      stmt_printf (("Alternate ts {\n"));
      node_print ((data_source_t *) tssp->tssp_alt_ts);
      stmt_printf (("\n}\n"));
    }
  else if (in == (qn_input_fn) query_frag_input)
	    {
      query_frag_t * qf = (query_frag_t *) node;
      stmt_printf (("QF {\n"));
      node_print (qf->qf_head_node);
      stmt_printf (("}\n"));
    }
  else if (in == (qn_input_fn) skip_node_input)
		{
      QNCAST (skip_node_t, sk, node);
      stmt_printf (("skip node "));
      ssl_print (sk->sk_top);
      ssl_print (sk->sk_top_skip);
      ssl_print (sk->sk_set_no);
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) sort_read_input)
    {
      QNCAST (table_source_t, ts, node);
      stmt_printf (("top order by read "));
      ssl_list_print (ts->ts_order_ks->ks_out_slots);
      stmt_printf (("\n"));
		}
  else if (in == (qn_input_fn) chash_read_input)
    {
      QNCAST (table_source_t, ts, node);
      key_source_t * ks = ts->ts_order_ks;
      stmt_printf (("group by read node  \n"));
      ssl_list_print (ks->ks_out_slots);
      stmt_printf (("\n"));
	    }
  else if (in == (qn_input_fn) select_node_input)
    {
      select_node_t *sel = (select_node_t *) node;
      stmt_printf (("Select "));
      if (sel->sel_top)
	{
	  stmt_printf (("(TOP "));
	  if (sel->sel_top_skip)
	    {
	      ssl_print (sel->sel_top_skip);
	      stmt_printf ((", "));
	    }
	  ssl_print (sel->sel_top);
	  stmt_printf ((") "));
	}
      ssl_array_print (sel->sel_out_slots);
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) setp_node_input)
    {
      setp_node_t *setp = (setp_node_t *) node;
      char hf[40];
      if (setp->setp_ha && HA_FILL == setp->setp_ha->ha_op)
	snprintf (hf, sizeof (hf), "hf %d %s", setp->setp_ha->ha_tree->ssl_index,
		  HS_CL_REPLICATED == setp->setp_cl_partition ? "replicated" : "");
      else
	hf[0] = 0;
      stmt_printf (("%s %s", setp->setp_distinct ? "Distinct" : "Sort", hf));
      if (setp->setp_is_streaming)
	stmt_printf (("%s ", FNR_STREAM_UNQ == setp->setp_is_streaming ? "streaming unique ": "streaming with duplicates"));

      ssl_list_print (setp->setp_keys);
      if (setp->setp_dependent)
	{
	  stmt_printf ((" -> "));
	  ssl_list_print (setp->setp_dependent);
	  if (setp->setp_any_user_aggregate_gos)
	    {
	      DO_SET (gb_op_t *, go, &setp->setp_gb_ops)
		{
		  if (go->go_ua_init_setp_call)
		    {
		      stmt_printf (("\nuser aggr init\n"));
		      code_vec_print (go->go_ua_init_setp_call);
		      stmt_printf ((" user aggr acc\n"));
		      code_vec_print (go->go_ua_acc_setp_call);
		    }
		}
	      END_DO_SET();
	    }
	  stmt_printf (("\n"));
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) fun_ref_node_input
	   || in == (qn_input_fn) hash_fill_node_input)
    {
      fun_ref_node_t *fref = (fun_ref_node_t *) node;
      du_thread_t * self = THREAD_CURRENT_THREAD;
      qr_comment_t * comm = THR_ATTR (self, TA_STAT_COMM);
      stmt_printf (("{ %s\n", IS_QN (node, hash_fill_node_input) ? "hash filler": "fork"));
      /* milos: set the 'first' flag */
      if (comm) comm->qrc_is_first = 1;
      node_print (fref->fnr_select);
      /* milos: set the 'first' flag */
      comm = THR_ATTR (self, TA_STAT_COMM);
      if(comm) comm->qrc_is_first = 1;
      stmt_printf (("}\n"));
    }
  else if (in == (qn_input_fn) remote_table_source_input)
    {
      remote_table_source_t *rts = (remote_table_source_t *) node;
      char *szPtr = rts->rts_text;
      stmt_printf (("Remote %s ", rts->rts_is_outer ? "OUTER" : ""));
      while (*szPtr)
	{
	  int len = (int) strlen (szPtr);
	  char save_c = 0;
	  if (len > EXPLAIN_LINE_MAX)
	    {
	      save_c = szPtr[EXPLAIN_LINE_MAX];
	      szPtr[EXPLAIN_LINE_MAX] = 0;
	    }
	  stmt_printf ((EXPLAIN_LINE_MAX_STR_FORMAT, szPtr));
	  if (len > EXPLAIN_LINE_MAX)
	    szPtr[EXPLAIN_LINE_MAX] = save_c;
	  szPtr += len > EXPLAIN_LINE_MAX ? EXPLAIN_LINE_MAX : len;
	  if (*szPtr)
	    stmt_printf (("\n"));
	}
      if (rts->rts_params)
	{
	  stmt_printf (("\nParams "));
	  ssl_list_print (rts->rts_params);
	}
      if (rts->rts_out_slots)
	{
	  stmt_printf (("\nOutput "));
	  ssl_array_print (rts->rts_out_slots);
	}
      if (rts->rts_after_join_test)
	{
	  stmt_printf (("\nAfter join test:\n"));
	  code_vec_print (rts->rts_after_join_test);
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) breakup_node_input)
    {
      QNCAST (breakup_node_t, brk, node);
      stmt_printf (("Breakup "));
      ssl_array_print (brk->brk_output);
      ssl_array_print (brk->brk_all_output);
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) subq_node_input)
    {
      subq_source_t *sqs = (subq_source_t *) node;
      stmt_printf (("Subquery %d %s\n", node->src_in_state, sqs->sqs_is_outer ? "OUTER" : ""));
      qr_print (sqs->sqs_query);
	}
  else if (in == (qn_input_fn) union_node_input)
    {
      union_node_t *uni = (union_node_t *) node;
      if (((query_t *) uni->uni_successors->data)->qr_is_bunion_term)
	stmt_printf (("BUnion\n"));
      else
	stmt_printf (("Union\n"));
      DO_SET (query_t *, qr, &uni->uni_successors)
      {
	qr_print (qr);
      }
      END_DO_SET ();
    }
  else if (in == (qn_input_fn) gs_union_node_input)
    {
      gs_union_node_t *gsu = (gs_union_node_t *) node;
      stmt_printf (("DataSource_Union\n"));
      DO_SET (data_source_t *, nd, &gsu->gsu_cont)
      {
	stmt_printf (("DSU_Branch\n{  \n"));
	node_print (nd);
	stmt_printf (("}\n"));
      }
      END_DO_SET ();
    }
  else if (in == (qn_input_fn) update_node_input)
    {
      update_node_t *upd = (update_node_t *) node;
      int inx;
      stmt_printf (("Update %s %s ", upd->upd_keyset ? "keyset" : "", upd->upd_table->tb_name));
      ssl_print (upd->upd_place);
      ssl_array_print (upd->upd_values);
      if (upd->upd_vec_source)
	{
	  ks_print_vec_cast (upd->upd_vec_cast, upd->upd_vec_source);
	}
      if (upd->upd_old_blobs)
	{
	  stmt_printf ((" old blobs: "));
	  ssl_array_print (upd->upd_old_blobs);
	  stmt_printf (("\n"));
	}
      if (upd->upd_keys)
	{
	  DO_BOX (ins_key_t *, ik, inx, upd->upd_keys)
	    {
	      if (!ik)
		continue;
	      ik_print (ik);
	    }
	  END_DO_BOX;
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) delete_node_input)
    {
      QNCAST (delete_node_t, del, node);
      stmt_printf (("Delete "));
      ssl_print (del->del_place);
      if (del->del_key_only)
	stmt_printf ((" only key %s ", del->del_key_only->key_name));
      if (del->del_keys)
	{
	  int inx;
	  stmt_printf (("keys: "));
	  DO_BOX (ins_key_t *, ik, inx, del->del_keys)
	    if (ik)
	      ik_print (ik);
	  END_DO_BOX;
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) insert_node_input)
    {
      insert_node_t *ins = (insert_node_t *) node;
      if (ins->ins_del_node)
	{
	  stmt_printf (("Replacing vectored {\n"));
	  node_print (ins->ins_del_node);
	  stmt_printf (("\n}\n"));
	}
      stmt_printf (("Insert %s ", ins->ins_table->tb_name));
      ssl_list_print (ins->ins_values);
      if (ins->ins_vec_source)
	{
	  stmt_printf (("\nvectored "));
	  ssl_array_print ((state_slot_t**)ins->ins_vec_source);
	  ssl_array_print (ins->ins_vec_cast);
	  stmt_printf (("\n"));
	}
      if (ins->ins_key_only)
	stmt_printf ((" only key %s ", ins->ins_key_only));
      if (ins->ins_daq)
	{
	  stmt_printf ((" DAQ ("));
	  ssl_print (ins->ins_daq);
	  stmt_printf ((")"));
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) select_node_input_subq)
    {
      select_node_t *sel = (select_node_t *) node;
      stmt_printf (("Subquery Select"));
      if (sel->sel_top)
	{
	  stmt_printf (("(TOP "));
	  if (sel->sel_top_skip)
	    {
	      ssl_print (sel->sel_top_skip);
	      stmt_printf ((", "));
	    }
	  ssl_print (sel->sel_top);
	  stmt_printf ((") "));
	}
      ssl_array_print (sel->sel_out_slots);
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) hash_source_input)
    {
      hash_source_t *hs = (hash_source_t *) node;
      stmt_printf (("Hash source %d %s %s %9.2g rows", hs->hs_ha->ha_tree->ssl_index, hs->hs_merged_into_ts ? "merged into ts" : hs->hs_is_outer ? "outer" : "",
		    hs->hs_no_partition ? "not partitionable" : "", hs->hs_cardinality));
      ssl_array_print (hs->hs_ref_slots);
      stmt_printf ((" -> "));
      ssl_array_print (hs->hs_out_slots);
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) rdf_inf_pre_input)
    {
      rdf_inf_pre_node_t *ri = (rdf_inf_pre_node_t *) node;
      char * mode = "";
      switch (ri->ri_mode)
	{
	case RI_SUBCLASS: mode = "subclass"; break;
	case RI_SUPERCLASS: mode = "superclass"; break;
	case RI_SUBPROPERTY: mode = "subproperty"; break;
	case RI_SUPERPROPERTY: mode = "superproperty"; break;
	case RI_SAME_AS_O: mode = "same-as-O"; break;
	case RI_SAME_AS_S: mode = "same-as-S"; break;
	case RI_SAME_AS_P: mode = "same-as-P"; break;
	}
      stmt_printf (("RDF Inference %s iterates ", mode));
      ssl_print (ri->ri_output);
      stmt_printf (("  o= "));
      ssl_print (ri->ri_o);
      stmt_printf ((" p= "));
      ssl_print (ri->ri_p);
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) trans_node_input)
    {
      QNCAST (trans_node_t, tn, node);
      if (tn->tn_prepared_step)
	{
	  if (tn->tn_ifp_ctx_name)
	    stmt_printf (("  Multistate transitive canned over ifps of %s,  input ", tn->tn_ifp_ctx_name));
	  else
	    stmt_printf (("  Multistate transitive canned,  input "));
	  ssl_array_print (tn->tn_input);
	  stmt_printf ((" output "));
	  ssl_array_print (tn->tn_output);
	  stmt_printf  ((" %s\n", tn->tn_lowest_sas ? "min same-as id" : ""));
	  if (tn->tn_sas_g)
	    {
	      stmt_printf (("g = "));
	      ssl_array_print (tn->tn_sas_g);
	      stmt_printf (("\n"));
	    }
	}
      else
	{
	  stmt_printf (("Transitive dt dir %d, input: ", tn->tn_direction));
	  ssl_array_print (tn->tn_input);
	  stmt_printf (("\n  input shadow: "));
	  ssl_array_print (tn->tn_input_ref);
	  stmt_printf (("\n  output: "));
	  ssl_array_print (tn->tn_output);
	  if (tn->tn_keep_path)
	    {
	      stmt_printf (("\n  step data: "));
	      ssl_array_print (tn->tn_data);
	      ssl_print (tn->tn_path_no_ret);
	      ssl_print (tn->tn_step_no_ret);
	    }
	  stmt_printf (("\n"));
	  if (tn->tn_target)
	    {
	      stmt_printf ((" Target:  "));
	      ssl_array_print (tn->tn_target);
	      stmt_printf (("\n"));
	    }
	  qr_print (tn->tn_inlined_step);
	  if (tn->tn_complement)
	    {
	      trans_node_t * tn2 = tn->tn_complement;
	      stmt_printf (("Reverse transitive node, input: "));
	      ssl_array_print (tn2->tn_input);
	      stmt_printf (("\n  output: "));
	      ssl_array_print (tn2->tn_output);
	      stmt_printf (("\n"));
	      if (tn2->tn_target)
		{
		  stmt_printf ((" Target:  "));
		  ssl_array_print (tn2->tn_target);
		  stmt_printf (("\n"));
		}
	      qr_print (tn2->tn_inlined_step);
	    }
	}
    }
  else if (in == (qn_input_fn) in_iter_input)
    {
      in_iter_node_t *ii = (in_iter_node_t *) node;
      stmt_printf (("in iterates "));
      ssl_print (ii->ii_output);
      stmt_printf (("  over "));
      ssl_array_print (ii->ii_values);
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) outer_seq_end_input)
    {
      outer_seq_end_node_t * ose = (outer_seq_end_node_t *)node;
      stmt_printf ((" end of outer}\n"));
      ssl_print (ose->ose_set_no);
      stmt_printf (("\n out: "));
      ssl_array_print (ose->ose_out_slots);
      if (ose->ose_out_shadow)
	{
	  stmt_printf (("\n shadow: "));
	  ssl_array_print (ose->ose_out_shadow);
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) set_ctr_input)
    {
      QNCAST (set_ctr_node_t, sctr, node);
      if (sctr->sctr_ose)
	{
	  stmt_printf (("outer {\n"));
	}
    }
#ifdef BIF_XML
  else if (in == (qn_input_fn) txs_input)
    {
      text_node_t *txs = (text_node_t *) node;
      if (txs->txs_geo)
	stmt_printf (("geo %s (", GSOP_INTERSECTS == txs->txs_geo ? "intersects": GSOP_CONTAINS == txs->txs_geo ? "contains": "within"));
      else
	if (txs->txs_xpath_text_exp)
	stmt_printf (("XCONTAINS ("));
      else
	stmt_printf (("CONTAINS ("));
      ssl_print (txs->txs_text_exp);
      stmt_printf ((") node on %s %9.2g rows\n", txs->txs_table->tb_name, txs->txs_card));
      ssl_print (txs->txs_d_id);
      if (txs->txs_precision)
	{
	  stmt_printf ((" geo prec: "));
	  ssl_print (txs->txs_precision);
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) xn_input)
    {
      xpath_node_t *xn = (xpath_node_t *) node;
      if ('q' == xn->xn_predicate_type)
	stmt_printf (("XQUERY_CONTAINS ("));
      else
	stmt_printf (("XPATH_CONTAINS ("));
      ssl_print (xn->xn_text_col);
      if (xn->xn_base_uri)
	{
	  stmt_printf ((" (url col: "));
	  ssl_print (xn->xn_base_uri);
	  stmt_printf ((" )"));
	}
      if (xn->xn_output_len)
	{
	  stmt_printf ((" (result node-set length: "));
	  ssl_print (xn->xn_output_len);
	  stmt_printf ((" )"));
	}
      if (xn->xn_output_ctr)
	{
	  stmt_printf ((" (result counter: "));
	  ssl_print (xn->xn_output_ctr);
	  stmt_printf ((" )"));
	}
      if (xn->xn_output_val)
	{
	  stmt_printf ((" (result value: "));
	  ssl_print (xn->xn_output_val);
	  stmt_printf ((" )"));
	}

      stmt_printf ((") node\n"));
    }
#endif
  else if (in == (qn_input_fn) end_node_input)
    {
      stmt_printf (("END Node\n"));
    }
  else
    {
      stmt_printf (("Node\n"));
    }

  if (node->src_after_test)
    {
      stmt_printf (("After test:\n"));
      code_vec_print (node->src_after_test);
    }
  if (node->src_after_code)
    {
      stmt_printf (("\nAfter code:\n"));
      code_vec_print (node->src_after_code);
    }
  node_print_next (node);
}


void
node_print (data_source_t * node)
{
  qn_input_fn in;
  query_instance_t * qi = (query_instance_t *) THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_QST);
  QI_CHECK_STACK (qi, &node, 10000);
  in = node->src_input;
  if (node->src_stat)
    node_stat (node);
  if (node->src_pre_code)
    {
      stmt_printf (("\nPrecode:\n"));
      if (node->src_query->qr_is_call == 2)
	{
	  code_vec_t vec = (code_vec_t) box_copy ((box_t) node->src_pre_code);
	  instruction_t *ins = NULL;
	  DO_INSTR (in, 0, vec)
	    {
	      if (in->ins_type == INS_CALL)
		{
		  ins = in;
		}
	    }
	  END_DO_INSTR;
	  if (ins && !ins->_.call.ret)
	    ins->_.call.ret = (state_slot_t *) 1;

	  code_vec_print (vec);
	  dk_free_box ((box_t) vec);
	}
      else
	code_vec_print (node->src_pre_code);
    }
  if (0 == dbf_explain_level)
    {
      node_print_0 (node);
      return;
    }
  if (dbf_explain_level > 2)
    {
  if (node->src_pre_reset)
    {
      stmt_printf (("  clear: "));
      ssl_array_print (node->src_pre_reset);
	}
      if (node->src_continue_reset)
	{
	  stmt_printf (("\n  clear on continue: "));
	  ssl_array_print (node->src_continue_reset);
	}
      if (node->src_vec_reuse)
	qn_print_reuse (node);
      stmt_printf (("\n"));
    }
  if (node->src_sets)
    {
      if (dbf_explain_level > 2)
	stmt_printf (("s# %d %d ", node->src_sets, node->src_in_state));
      else
    stmt_printf (("s# %d ", node->src_sets));
    }
  if (in == (qn_input_fn) table_source_input ||
      in == (qn_input_fn) table_source_input_unique)
    {
      ts_print ((table_source_t *) node);
    }
  else if (IS_QN (node, ts_split_input))
    {
      QNCAST (ts_split_node_t, tssp, node);
      stmt_printf (("Alternate ts {\n"));
      node_print ((data_source_t *) tssp->tssp_alt_ts);
      stmt_printf (("\n}\n"));
    }
  else if (in == (qn_input_fn) query_frag_input)
    {
      query_frag_t * qf = (query_frag_t *) node;
      char max_rows[30];
      if (qf->qf_max_rows)
	snprintf (max_rows, sizeof (max_rows), " max %d", qf->qf_max_rows);
      else
	max_rows[0] = 0;
      stmt_printf (("  { Cluster location fragment %d %d %s %s\n   Params: ", node->src_in_state, (int)qf->qf_nth, qf->qf_order ? "" : "unordered", max_rows));
      ssl_array_print (qf->qf_params);
      stmt_printf (("\nOutput: "));
      ssl_array_print (qf->qf_result);
      if (dbf_explain_level > 2)
	{
      stmt_printf (("    \nsave ctx:"));
      ssl_array_print (qf->clb.clb_save);
	}
      stmt_printf (("\n"));
      if (qf->qf_trigger_args)
	{
	  stmt_printf (("  trigger args: "));
	  ssl_array_print (qf->qf_trigger_args);
	  stmt_printf (("\n"));
	}
      if (qf->qf_local_save)
	{
	  stmt_printf (("  qf Local save: "));
	  ssl_array_print (qf->qf_local_save);
	  stmt_printf (("\n"));
	}
      node_print (qf->qf_head_node);
      stmt_printf (("  \n}\n"));
    }
  else if (in == (qn_input_fn) skip_node_input)
    {
      QNCAST (skip_node_t, sk, node);
      stmt_printf (("skip node "));
      ssl_print (sk->sk_top);
      ssl_print (sk->sk_top_skip);
      ssl_print (sk->sk_set_no);
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) sort_read_input)
    {
      QNCAST (table_source_t, ts, node);
      stmt_printf (("top order by node "));
      ssl_list_print (ts->ts_order_ks->ks_out_slots);
      stmt_printf (("\n"));
      if (ts->ts_order_ks->ks_set_no)
	{
	  stmt_printf (("set no "));
	  ssl_print (ts->ts_order_ks->ks_set_no);
	  stmt_printf (("\n"));
	}
    }
  else if (in == (qn_input_fn) chash_read_input)
    {
      QNCAST (table_source_t, ts, node);
      key_source_t * ks = ts->ts_order_ks;
      stmt_printf (("group by read node  \n"));
      ssl_list_print (ks->ks_out_slots);
      if (ks->ks_set_no_col_ssl)
	{
	  stmt_printf (("\nset no returned in "));
	  ssl_print (ks->ks_set_no_col_ssl);
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) select_node_input)
    {
      select_node_t *sel = (select_node_t *) node;
      stmt_printf (("Select "));
      if (sel->sel_top)
	{
	  stmt_printf (("(TOP "));
	  if (sel->sel_top_skip)
	    {
	      ssl_print (sel->sel_top_skip);
	      stmt_printf ((", "));
	    }
	  ssl_print (sel->sel_top);
	  stmt_printf ((") "));
	}
      ssl_array_print (sel->sel_out_slots);
      stmt_printf (("\n"));
      if (sel->sel_set_no)
	{
	  stmt_printf (("  set no: "));
	  ssl_print (sel->sel_set_no);
      stmt_printf (("\n"));
	}
    }
  else if (in == (qn_input_fn) setp_node_input)
    {
      setp_node_t *setp = (setp_node_t *) node;
      char hf[40];
      if (setp->setp_ha && HA_FILL == setp->setp_ha->ha_op)
	snprintf (hf, sizeof (hf), "hf %d %s %s", setp->setp_ha->ha_tree->ssl_index,
		  HS_CL_REPLICATED == setp->setp_cl_partition ? "replicated" : "",
		  setp->setp_no_bloom ? "no bloom" : "");
      else
	hf[0] = 0;
      stmt_printf (("%s %s", setp->setp_distinct ? "Distinct" : "Sort", hf));
      if (setp->setp_ha)
	{
	  stmt_printf (("(HASH) "));
	  if (setp->setp_ha->ha_set_no)
	    {
	      stmt_printf (("set no "));
	      ssl_print (setp->setp_ha->ha_set_no);
	    }
	  if (setp->setp_is_streaming)
	    stmt_printf (("%s ", FNR_STREAM_UNQ == setp->setp_is_streaming ? "streaming unique ": "streaming with duplicates"));
	}
      if (setp->setp_top)
	{
	  stmt_printf (("(TOP "));
	  if (setp->setp_top_skip)
	    {
	      ssl_print (setp->setp_top_skip);
	      stmt_printf ((", "));
	    }
	  ssl_print (setp->setp_top);
	  stmt_printf ((" %s) ",
		setp->setp_sorted ? "" : "WITH TIES"));
	}
      ssl_list_print (setp->setp_keys);
      if (setp->setp_dependent)
	{
	  stmt_printf ((" -> "));
	  ssl_list_print (setp->setp_dependent);
	  if (setp->setp_card)
	    stmt_printf ((" up to %9.2g distinct", setp->setp_card));
	  if (setp->setp_any_user_aggregate_gos)
	    {
	      DO_SET (gb_op_t *, go, &setp->setp_gb_ops)
		{
		  if (go->go_ua_init_setp_call)
		    {
		      stmt_printf (("\nuser aggr init\n"));
		      code_vec_print (go->go_ua_init_setp_call);
		      stmt_printf ((" user aggr acc\n"));
		      code_vec_print (go->go_ua_acc_setp_call);
		    }
		}
	      END_DO_SET();
	    }
	  stmt_printf (("\n"));
	}
      stmt_printf (("\n"));
      if (setp->setp_loc_ts)
	{
	  ks_print_vec_cast (setp->setp_loc_ts->ts_order_ks->ks_vec_cast, setp->setp_loc_ts->ts_order_ks->ks_vec_source);
	  stmt_printf (("\n"));
	}
    }
  else if (in == (qn_input_fn) fun_ref_node_input
	   || in == (qn_input_fn) hash_fill_node_input)
    {
      fun_ref_node_t *fref = (fun_ref_node_t *) node;
      stmt_printf (("Fork %d \n{  %s\n", node->src_in_state,
		    fref->fnr_hi_signature ? " shareable hash fill " : ""));
      if (fref->fnr_hash_part_min)
	stmt_printf ((" Hash filler partition by %d", fref->fnr_hash_part_min));
      if (IS_QN (fref, hash_fill_node_input) && fref->fnr_no_hash_partition)
	stmt_printf ((" hash not partitionable"));
      if (fref->fnr_prev_hash_fillers)
	{
	  stmt_printf (("Result after all partitions of hash fillers "));
	  DO_SET (fun_ref_node_t *, filler, &fref->fnr_prev_hash_fillers)
	    stmt_printf (("hf %d ", filler->fnr_setp->setp_ha->ha_tree->ssl_index));
	  END_DO_SET();
	  stmt_printf (("\n"));
	}
      if (fref->clb.clb_fill)
	{
	  stmt_printf (("    \nsave ctx:"));
	  ssl_array_print (fref->clb.clb_save);
	  stmt_printf (("\n  set no = "));
	  ssl_print (fref->fnr_ssa.ssa_set_no);
	  stmt_printf ((" array "));
	  ssl_print (fref->fnr_ssa.ssa_array);
	  stmt_printf ((" save: "));
	  ssl_array_print (fref->fnr_ssa.ssa_save);
	  stmt_printf (("\n"));
	}
      { 
	  // milos: set the 'first' flag on
	  du_thread_t * self = THREAD_CURRENT_THREAD;
	  qr_comment_t * comm = THR_ATTR (self, TA_STAT_COMM);
	  caddr_t * ctx_inst;
	  src_stat_t * srs;
	  if(comm) comm->qrc_is_first = 1;
	  /* milos: detect a new warning and add the warning text: it is a partition hash join, and it did N passes (N = fref->fnr_select->src_stat.srs_n_in)  	 */
	  ctx_inst = THR_ATTR (THREAD_CURRENT_THREAD, TA_STAT_INST);
	  srs = (src_stat_t *)&ctx_inst[fref->fnr_select->src_stat];
	  if ((fref->fnr_select->src_stat) && (qi != NULL) && (QST_INT(qi, srs->srs_n_in) > 1))	
	    qrc_add_wrn_msg("Warning: There is a partition hash join which did %d passes.\n", srs->srs_n_in);
	  node_print (fref->fnr_select);
	  /* milos: set the 'first' flag on */
	  comm = THR_ATTR (self, TA_STAT_COMM);
	  if(comm) comm->qrc_is_first = 1;
      }
      stmt_printf (("}\n"));
    }
  else if (in == (qn_input_fn) remote_table_source_input)
    {
      remote_table_source_t *rts = (remote_table_source_t *) node;
      char *szPtr = rts->rts_text;
      stmt_printf (("Remote %s ", rts->rts_is_outer ? "OUTER" : ""));
      while (*szPtr)
	{
	  int len = (int) strlen (szPtr);
	  char save_c = 0;
	  if (len > EXPLAIN_LINE_MAX)
	    {
	      save_c = szPtr[EXPLAIN_LINE_MAX];
	      szPtr[EXPLAIN_LINE_MAX] = 0;
	    }
	  stmt_printf ((EXPLAIN_LINE_MAX_STR_FORMAT, szPtr));
	  if (len > EXPLAIN_LINE_MAX)
	    szPtr[EXPLAIN_LINE_MAX] = save_c;
	  szPtr += len > EXPLAIN_LINE_MAX ? EXPLAIN_LINE_MAX : len;
	  if (*szPtr)
	    stmt_printf (("\n"));
	}
      if (rts->rts_params)
	{
	  stmt_printf (("\nParams "));
	  ssl_list_print (rts->rts_params);
	}
      if (rts->rts_out_slots)
	{
	  stmt_printf (("\nOutput "));
	  ssl_array_print (rts->rts_out_slots);
	}
      if (rts->rts_after_join_test)
	{
	  stmt_printf (("\nAfter join test:\n"));
	  code_vec_print (rts->rts_after_join_test);
	}
      stmt_printf (("\n"));
	}
  else if (in == (qn_input_fn) breakup_node_input)
    {
      QNCAST (breakup_node_t, brk, node);
      stmt_printf (("Breakup "));
      ssl_array_print (brk->brk_output);
      ssl_array_print (brk->brk_all_output);
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) subq_node_input)
    {
      subq_source_t *sqs = (subq_source_t *) node;
      stmt_printf (("Subquery %d %s\n", node->src_in_state, sqs->sqs_is_outer ? "OUTER" : ""));
      if (sqs->sqs_set_no)
	{
	  stmt_printf (("  multistate set no = "));
	  ssl_print (sqs->sqs_set_no);
	  stmt_printf (("\n"));
	}
      qr_print (sqs->sqs_query);
      if (sqs->sqs_after_join_test)
	{
	  stmt_printf (("  after join test\n"));
	  code_vec_print (sqs->sqs_after_join_test);
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) union_node_input)
    {
      union_node_t *uni = (union_node_t *) node;
      if (((query_t *) uni->uni_successors->data)->qr_is_bunion_term)
	stmt_printf (("BUnion\n"));
      else
	stmt_printf (("Union\n"));
      DO_SET (query_t *, qr, &uni->uni_successors)
      {
	qr_print (qr);
      }
      END_DO_SET ();
    }
  else if (in == (qn_input_fn) gs_union_node_input)
    {
      gs_union_node_t *gsu = (gs_union_node_t *) node;
      stmt_printf (("DataSource_Union\n"));
      DO_SET (data_source_t *, nd, &gsu->gsu_cont)
      {
	stmt_printf (("DSU_Branch\n{  \n"));
	node_print (nd);
	stmt_printf (("}\n"));
      }
      END_DO_SET ();
    }
  else if (in == (qn_input_fn) update_node_input)
    {
      update_node_t *upd = (update_node_t *) node;
      int inx;
      stmt_printf (("Update %s %s ", upd->upd_keyset ? "keyset" : "", upd->upd_table->tb_name));
      ssl_print (upd->upd_place);
      ssl_array_print (upd->upd_values);
      if (upd->upd_vec_source)
	{
	  ks_print_vec_cast (upd->upd_vec_cast, upd->upd_vec_source);
	}
      if (upd->upd_old_blobs)
	{
	  stmt_printf ((" old blobs: "));
	  ssl_array_print (upd->upd_old_blobs);
	  stmt_printf (("\n"));
	}
      if (upd->upd_keys)
	{
	  DO_BOX (ins_key_t *, ik, inx, upd->upd_keys)
	    {
	      if (!ik)
		continue;
	      ik_print (ik);
	    }
	  END_DO_BOX;
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) delete_node_input)
    {
      QNCAST (delete_node_t, del, node);
      stmt_printf (("Delete "));
      ssl_print (del->del_place);
      if (del->del_key_only)
	stmt_printf ((" only key %s ", del->del_key_only->key_name));
      if (del->del_keys)
	{
	  int inx;
	  stmt_printf (("keys: "));
	  DO_BOX (ins_key_t *, ik, inx, del->del_keys)
	    if (ik)
	      ik_print (ik);
	  END_DO_BOX;
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) insert_node_input)
    {
      insert_node_t *ins = (insert_node_t *) node;
      if (ins->ins_del_node)
	{
	  stmt_printf (("Replacing vectored {\n"));
	  node_print (ins->ins_del_node);
	  stmt_printf (("\n}\n"));
	}
      stmt_printf (("Insert %s ", ins->ins_table->tb_name));
      ssl_list_print (ins->ins_values);
      if (ins->ins_vec_source)
	{
	  stmt_printf (("\nvectored "));
	  ssl_array_print ((state_slot_t**)ins->ins_vec_source);
	  ssl_array_print (ins->ins_vec_cast);
	  stmt_printf (("\n"));
	}
      if (ins->ins_key_only)
	stmt_printf ((" only key %s ", ins->ins_key_only));
      if (ins->ins_daq)
	{
	  stmt_printf ((" DAQ ("));
	  ssl_print (ins->ins_daq);
	  stmt_printf ((")"));
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) select_node_input_subq)
    {
      select_node_t *sel = (select_node_t *) node;
      stmt_printf (("Subquery Select"));
      if (sel->sel_top)
	{
	  stmt_printf (("(TOP "));
	  if (sel->sel_top_skip)
	    {
	      ssl_print (sel->sel_top_skip);
	      stmt_printf ((", "));
	    }
	  ssl_print (sel->sel_top);
	  stmt_printf ((") "));
	}
      ssl_array_print (sel->sel_out_slots);
      stmt_printf (("\n"));
      if (sel->sel_set_no)
	{
	  stmt_printf (("  set no: "));
	  ssl_print (sel->sel_set_no);
      stmt_printf (("\n"));
	}
    }
  else if (in == (qn_input_fn) hash_source_input)
    {
      hash_source_t *hs = (hash_source_t *) node;
      stmt_printf (("Hash source %d %s %s %9.2g rows", hs->hs_ha->ha_tree->ssl_index, hs->hs_merged_into_ts ? "merged into ts" : hs->hs_is_outer ? "outer" : "",
		    hs->hs_no_partition ? "not partitionable" : "", hs->hs_cardinality));
      ssl_array_print (hs->hs_ref_slots);
      stmt_printf ((" -> "));
      ssl_array_print (hs->hs_out_slots);
      stmt_printf (("\n"));
      if (hs->hs_loc_ts)
	ks_print_vec_cast (hs->hs_loc_ts->ts_order_ks->ks_vec_cast, hs->hs_loc_ts->ts_order_ks->ks_vec_source);
      if (hs->hs_ks)
	ks_print_vec_cast (hs->hs_ks->ks_vec_cast, hs->hs_ks->ks_vec_source);
      if (hs->hs_after_join_test)
	{
	  stmt_printf (("  after join test\n"));
	  code_vec_print (hs->hs_after_join_test);
	}
    }
  else if (in == (qn_input_fn) rdf_inf_pre_input)
    {
      rdf_inf_pre_node_t *ri = (rdf_inf_pre_node_t *) node;
      char * mode = "";
      switch (ri->ri_mode)
	{
	case RI_SUBCLASS: mode = "subclass"; break;
	case RI_SUPERCLASS: mode = "superclass"; break;
	case RI_SUBPROPERTY: mode = "subproperty"; break;
	case RI_SUPERPROPERTY: mode = "superproperty"; break;
	case RI_SAME_AS_O: mode = "same-as-O"; break;
	case RI_SAME_AS_S: mode = "same-as-S"; break;
	case RI_SAME_AS_P: mode = "same-as-P"; break;
	}
      stmt_printf (("RDF Inference %s %s iterates ", mode, ri->ri_outer_any_passed ? " outer " : ""));
      ssl_print (ri->ri_output);
      stmt_printf (("\n"));
      if (ri->ri_sas_in)
	{
	  stmt_printf (("  same-as input = "));
	  ssl_print (ri->ri_sas_in);
	}
      stmt_printf (("  o= "));
      ssl_print (ri->ri_o);
      stmt_printf ((" p= "));
      ssl_print (ri->ri_p);
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) trans_node_input)
    {
      QNCAST (trans_node_t, tn, node);
      if (tn->tn_prepared_step)
	{
	  if (tn->tn_ifp_ctx_name)
	    stmt_printf (("  Multistate transitive canned over ifps of %s,  input ", tn->tn_ifp_ctx_name));
	  else
	    stmt_printf (("  Multistate transitive canned,  input "));
	  ssl_array_print (tn->tn_input);
	  stmt_printf ((" output "));
	  ssl_array_print (tn->tn_output);
	  stmt_printf  ((" %s\n", tn->tn_lowest_sas ? "min same-as id" : ""));
	  if (tn->tn_sas_g)
	    {
	      stmt_printf (("g = "));
	      ssl_array_print (tn->tn_sas_g);
	      stmt_printf (("\n"));
	    }
	}
      else
	{
	  stmt_printf (("Transitive dt dir %d, input: ", tn->tn_direction));
	  ssl_array_print (tn->tn_input);
	  stmt_printf (("\n  input shadow: "));
	  ssl_array_print (tn->tn_input_ref);
	  stmt_printf (("\n  output: "));
	  ssl_array_print (tn->tn_output);
	  if (tn->tn_keep_path)
	    {
	      stmt_printf (("\n  step data: "));
	      ssl_array_print (tn->tn_data);
	      ssl_print (tn->tn_path_no_ret);
	      ssl_print (tn->tn_step_no_ret);
	    }
	  stmt_printf (("\n"));
	  if (tn->tn_target)
	    {
	      stmt_printf ((" Target:  "));
	      ssl_array_print (tn->tn_target);
	      stmt_printf (("\n"));
	    }
	  qr_print (tn->tn_inlined_step);
	  if (tn->tn_complement)
	    {
	      trans_node_t * tn2 = tn->tn_complement;
	      stmt_printf (("Reverse transitive node, input: "));
	      ssl_array_print (tn2->tn_input);
	      stmt_printf (("\n  output: "));
	      ssl_array_print (tn2->tn_output);
	      stmt_printf (("\n"));
	      if (tn2->tn_target)
		{
		  stmt_printf ((" Target:  "));
		  ssl_array_print (tn2->tn_target);
		  stmt_printf (("\n"));
		}
	      qr_print (tn2->tn_inlined_step);
	    }
	}
    }
  else if (in == (qn_input_fn) in_iter_input)
    {
      in_iter_node_t *ii = (in_iter_node_t *) node;
      stmt_printf (("in  %s iterates ", ii->ii_outer_any_passed ? " outer " : ""));
      ssl_print (ii->ii_output);
      stmt_printf (("\n  over "));
      ssl_array_print (ii->ii_values);
      stmt_printf (("\n"));

    }
  else if (in == (qn_input_fn) outer_seq_end_input)
    {
      outer_seq_end_node_t * ose = (outer_seq_end_node_t *)node;
      stmt_printf (("end of outer seq "));
      ssl_print (ose->ose_set_no);
      stmt_printf (("\n out: "));
      ssl_array_print (ose->ose_out_slots);
      if (ose->ose_out_shadow)
	{
	  stmt_printf (("\n shadow: "));
	  ssl_array_print (ose->ose_out_shadow);
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) set_ctr_input)
    {
      QNCAST (set_ctr_node_t, sctr, node);
      stmt_printf (("cluster outer seq start, set no "));
      ssl_print (sctr->sctr_set_no);
      stmt_printf (("    \nsave ctx:"));
      ssl_array_print (sctr->clb.clb_save);
      if (sctr->sctr_hash_spec)
	{
	  stmt_printf (("\nHash partition filter: "));
	  DO_SET (search_spec_t *, sp, &sctr->sctr_hash_spec)
	    hrng_print ((hash_range_spec_t*)sp->sp_min_ssl, sp);
	  END_DO_SET();
	  stmt_printf (("\n"));
	}
      stmt_printf (("\n"));
    }
#ifdef BIF_XML
  else if (in == (qn_input_fn) txs_input)
    {
      text_node_t *txs = (text_node_t *) node;
      if (txs->txs_geo)
	stmt_printf (("geo %s ", GSOP_INTERSECTS == txs->txs_geo ? "intersects": GSOP_CONTAINS == txs->txs_geo ? "contains": "within"));
      else
	if (txs->txs_xpath_text_exp)
	stmt_printf (("XCONTAINS ("));
      else
	stmt_printf (("CONTAINS ("));
      ssl_print (txs->txs_text_exp);
      stmt_printf ((") node on %s %9.2g rows\n", txs->txs_table->tb_name, txs->txs_card));
      ssl_print (txs->txs_d_id);
      if (txs->txs_precision)
	{
	  stmt_printf ((" geo prec: "));
	  ssl_print (txs->txs_precision);
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) xn_input)
    {
      xpath_node_t *xn = (xpath_node_t *) node;
      if ('q' == xn->xn_predicate_type)
	stmt_printf (("XQUERY_CONTAINS ("));
      else
	stmt_printf (("XPATH_CONTAINS ("));
      ssl_print (xn->xn_text_col);
      if (xn->xn_base_uri)
	{
	  stmt_printf ((" (url col: "));
	  ssl_print (xn->xn_base_uri);
	  stmt_printf ((" )"));
	}
      if (xn->xn_output_len)
	{
	  stmt_printf ((" (result node-set length: "));
	  ssl_print (xn->xn_output_len);
	  stmt_printf ((" )"));
	}
      if (xn->xn_output_ctr)
	{
	  stmt_printf ((" (result counter: "));
	  ssl_print (xn->xn_output_ctr);
	  stmt_printf ((" )"));
	}
      if (xn->xn_output_val)
	{
	  stmt_printf ((" (result value: "));
	  ssl_print (xn->xn_output_val);
	  stmt_printf ((" )"));
	}
      stmt_printf ((") node\n"));
    }
#endif
  else if (in == (qn_input_fn) end_node_input)
    {
      stmt_printf (("END Node\n"));
    }
  else
    {
      stmt_printf (("Node\n"));
    }

  if (node->src_after_test)
    {
      stmt_printf (("\nAfter test:\n"));
      code_vec_print (node->src_after_test);
    }
  if (node->src_after_code)
    {
      stmt_printf (("\nAfter code:\n"));
      code_vec_print (node->src_after_code);
    }
  node_print_next (node);
}


void
qc_print (query_cursor_t * qc)
{
  int inx;
  stmt_printf (("\nCursor Statements, type %d:\n", qc->qc_cursor_type));
  DO_BOX (query_t *, qr, inx, qc->qc_next)
    {
      stmt_printf (("Forward %d\n", inx));
      qr_print (qr);
      stmt_printf (("Backward %d\n", inx));
      if (qc->qc_prev)
	qr_print (qc->qc_prev[inx]);
    }
  END_DO_BOX;

  if (qc->qc_refresh)
    {
      stmt_printf (("Refresh\n"));
      qr_print (qc->qc_refresh);
    }
  if (qc->qc_update)
    {
      stmt_printf (("Update\n"));
      qr_print (qc->qc_update);
    }
  if (qc->qc_insert)
    {
      stmt_printf (("Insert\n"));
      qr_print (qc->qc_insert);
    }
  if (qc->qc_delete)
    {
      stmt_printf (("Delete\n"));
      qr_print (qc->qc_delete);
    }


}


void
qr_print_params (query_t * qr)
{
  if (qr->qr_parms)
    {
      stmt_printf (("Params: "));
      DO_SET (state_slot_t *, ssl, &qr->qr_parms)
	{
	  stmt_printf (("<$%d dtp %d (%ld, %d) %s> ", ssl->ssl_index, ssl->ssl_dtp,
			ssl->ssl_prec, ssl->ssl_scale, ssl->ssl_class ? ssl->ssl_class->scl_name : ""));
	}
      END_DO_SET ();
      stmt_printf (("\n"));
    }
}

static void
qr_print (query_t * qr)
{
  du_thread_t * self = THREAD_CURRENT_THREAD;
  query_instance_t * qi = (query_instance_t *) THR_ATTR (self, TA_REPORT_QST);
  query_instance_t * stat_qi = (QI*)THR_ATTR (self, TA_STAT_INST);
  if (!qi || (qi->qi_trx->lt_threads != 1&& qi != stat_qi))
    GPF_T;
  QI_CHECK_STACK (qi, &qr, 10000);
  stmt_printf (("{ %s\n", qr->qr_lock_mode == PL_EXCLUSIVE ? "FOR UPDATE" : ""));
  qr_print_params (qr);
  node_print (qr->qr_head_node);
  if (qr->qr_cursor)
    qc_print (qr->qr_cursor);
#if 0
  if (qr->qr_subq_queries)
    {
      stmt_printf (("Subqueries : {\n"));
      DO_SET (query_t *, sub_qr, &qr->qr_subq_queries)
	{
	  qr_print (sub_qr);
	}
      END_DO_SET();
      stmt_printf (("}\n"));
    }
#endif
  stmt_printf (("}\n"));
}


void
qr_print_top (query_t * qr)
{
  du_thread_t * self = THREAD_CURRENT_THREAD;
  query_instance_t * stat_qi = (QI*)THR_ATTR (self, TA_STAT_INST);
  int64 total = 0;
  if (prof_on)
    {
      if (stat_qi)
	total = qi_total_rdtsc (stat_qi);
      else
	total = qr_qn_total (qr);
    }
  SET_THR_ATTR (self, TA_TOTAL_RDTSC, (void*)(ptrlong)total);

  qr_print (qr);
}

void ses_sprintf (dk_session_t *ses, const char *fmt, ...);

/* explain in XML format  */

static void
ssl_print_xml (state_slot_t * ssl, dk_session_t * s)
{
  if (!ssl)
    {
      SES_PRINT(s, "<ssl />");
      return;
    }
  if (CV_CALL_PROC_TABLE == ssl)
    {
      SES_PRINT (s, "<ssl proc-table='1' />");
      return;
    }
  else if (CV_CALL_VOID == ssl)
    {
      SES_PRINT (s, "<ssl void-proc='1' />");
      return;
    }
  switch (ssl->ssl_type)
    {
#if 0
    case SSL_PARAMETER:
    case SSL_COLUMN:
    case SSL_VARIABLE:
    case SSL_VEC:
      ses_sprintf (s, "<ssl index='%d' name='%s' />", ssl->ssl_index, ssl->ssl_name ? ssl->ssl_name : "-");
      break;
#endif
    case SSL_REF:
      {
	QNCAST (state_slot_ref_t, sslr, ssl);
	ssl_print_xml (sslr->sslr_ssl, s);
	break;
      }
    case SSL_CONSTANT:
	{
	  caddr_t err_ret = NULL;
	  dtp_t dtp = DV_TYPE_OF (ssl->ssl_constant);
	  if (DV_DB_NULL == dtp)
	    SES_PRINT (s, "<ssl constant='NULL' />");
	  else if (DV_RDF == dtp)
	    {
	      rdf_box_t * rb = (rdf_box_t*)ssl->ssl_constant;
	      ses_sprintf (s, "<ssl constant='rdflit" BOXINT_FMT "' />", rb->rb_ro_id);
	    }
	  else
	    {
	      caddr_t strval = box_cast_to (NULL, ssl->ssl_constant,
					    dtp, DV_SHORT_STRING,
		  NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE,
		  &err_ret);
	      if (!err_ret && strval)
		{
		  ses_sprintf (s, "<ssl constant='" EXPLAIN_LINE_MAX_STR_FORMAT "' />", strval);
		}
	      else
		SES_PRINT (s, "<ssl constant='' />");
	      if (err_ret)
		dk_free_tree (err_ret);
	      if (strval)
		dk_free_box (strval);
	    }
	}
      break;
    default:
	{
	  char * name = ssl->ssl_name ? ssl->ssl_name : "-";
	  ses_sprintf (s, "<ssl index='%d' name='", ssl->ssl_index);
	  dks_esc_write (s, name, strlen (name), CHARSET_UTF8, CHARSET_UTF8, DKS_ESC_PTEXT);
	  SES_PRINT (s, "' />");
	}
      break;
    }
  SES_PRINT (s, "\n");
}

void
ssl_array_print_xml (state_slot_t ** ssls, dk_session_t * s)
{
  int inx;
  DO_BOX (state_slot_t *, ssl, inx, ssls)
  {
    ssl_print_xml (ssl, s);
  }
  END_DO_BOX;
}

void
ssl_list_print_xml (dk_set_t ssls, dk_session_t * s)
{
  DO_SET (state_slot_t *, ssl, &ssls)
  {
    ssl_print_xml (ssl, s);
  }
  END_DO_SET ();
}

const char *
cmp_op_text_xml (int cmp)
{
  switch (cmp)
    {
    case CMP_EQ:
      return ("=");

    case CMP_LT:
      return ("&lt;");

    case CMP_LTE:
      return "&lt;=";

    case CMP_GT:
      return ("&gt;");

    case CMP_GTE:
      return ("&gt;=");

    case CMP_NULL:
      return ("IS NULL");

    case CMP_LIKE:
      return ("LIKE");
    }
  return ("unknown");
}

static void
sp_list_print_xml (search_spec_t * sp, dk_session_t * s)
{
  while (sp)
    {
      SES_PRINT (s, "<sp");
      if (sp->sp_col)
	ses_sprintf (s, " col='%s'", sp->sp_col->col_name);
      else
	ses_sprintf (s, " col='col#%ld'", sp->sp_cl.cl_col_id);
      SES_PRINT (s, ">\n");
      if (sp->sp_min_op != CMP_NONE)
	{
	  SES_PRINT (s, "<op");
	  ses_sprintf (s, " code='%s' ", cmp_op_text_xml (sp->sp_min_op));
	  SES_PRINT (s, ">\n");
	  ssl_print_xml (sp->sp_min_ssl, s);
	  SES_PRINT (s, "</op>\n");
	}
      if (sp->sp_max_op != CMP_NONE)
	{
	  SES_PRINT (s, "<op");
	  ses_sprintf (s, " code='%s' ", cmp_op_text_xml (sp->sp_max_op));
	  SES_PRINT (s, ">\n");
	  ssl_print_xml (sp->sp_max_ssl, s);
	  SES_PRINT (s, "</op>\n");
	}
      SES_PRINT (s, "</sp>");
      sp = sp->sp_next;
    }
}

void node_print_xml (QI * qi, dk_session_t * s, data_source_t * qn);

static void
qr_print_xml (QI * qi, query_t * qr, dk_session_t * s, const char * tag)
{
  ses_sprintf (s, "<%s>", tag);
  SES_PRINT (s, "<params>");
  ssl_list_print_xml (qr->qr_parms, s);
  SES_PRINT (s, "</params>");
  node_print_xml (qi, s, qr->qr_head_node);
  ses_sprintf (s, "</%s>", tag);
}

static void
code_vec_print_xml (QI * qi, code_vec_t cv, dk_session_t * s)
{
  int compound_level = 0;
  char *strptr;
  DO_INSTR (in, 0, cv)
    {
      if (in->ins_type == INS_COMPOUND_END)
	compound_level--;
      /*stmt_printf (("      %d: ", (int) INSTR_OFS (in, cv)));*/
      switch (in->ins_type)
	{
	case IN_ARTM_FPTR: strptr = "<UNKNOWN>"; goto artm_print;
	case IN_ARTM_PLUS: strptr = "+"; goto artm_print;
	case IN_ARTM_MINUS: strptr = "-"; goto artm_print;
	case IN_ARTM_TIMES: strptr = "*"; goto artm_print;
	case IN_ARTM_DIV: strptr = "/"; goto artm_print;
	case IN_ARTM_IDENTITY: strptr = ":=";
artm_print:
     	  ses_sprintf (s, "<artm op='%s'>", strptr); 
     	  SES_PRINT (s, "<res>"); 
	  ssl_print_xml (in->_.artm.result, s);
     	  SES_PRINT (s, "</res>"); 
     	  SES_PRINT (s, "<left>"); 
	  ssl_print_xml (in->_.artm.left, s);
     	  SES_PRINT (s, "</left>"); 
	  if (in->_.artm.right)
	    {
	      SES_PRINT (s, "<right>"); 
	      ssl_print_xml (in->_.artm.right, s);
	      SES_PRINT (s, "</right>"); 
	    }
     	  SES_PRINT (s, "</artm>");
	  break;
	case IN_AGG:
	  {
	    int op = in->_.agg.op;
	    char * name = AMMSC_SUM == op ? "sum": AMMSC_COUNTSUM == op ? "countsum": AMMSC_COUNT == op ? "count": AMMSC_MIN == op ? "min": AMMSC_MAX == op ? "max" : AMMSC_ONE == op ? "subq_value": "unknown ";

	    ses_sprintf (s, "<agg op='%s'>", name);
	    SES_PRINT (s, "<res>");
	    ssl_print_xml (in->_.agg.result, s);
	    SES_PRINT (s, "</res>");
	    SES_PRINT (s, "<arg>");
	    ssl_print_xml (in->_.agg.arg, s);
	    SES_PRINT (s, "</arg>");
	    if (in->_.agg.set_no)
	      {
		SES_PRINT (s, "<setno>");
		ssl_print_xml (in->_.agg.set_no, s);
		SES_PRINT (s, "</setno>");
	      }
	    if (in->_.agg.distinct)
	      {
		SES_PRINT (s, "<distinct>");
		ssl_print_xml (in->_.agg.distinct->ha_tree, s);
		SES_PRINT (s, "</distinct>");
	      }
	    SES_PRINT (s, "</agg>");
	    break;
	  }
	case IN_PRED:
	  {
	    if (in->_.pred.func == subq_comp_func)
	      {
		subq_pred_t *subp = (subq_pred_t *) in->_.pred.cmp;
		SES_PRINT (s, "<if>");
		qr_print_xml (qi, subp->subp_query, s, "subq");
		SES_PRINT (s, "</if>");
	      }
	    else if (in->_.pred.func == bop_comp_func)
	      {
		bop_comparison_t *bop = (bop_comparison_t *) in->_.pred.cmp;
		ses_sprintf (s, "<if op='%s' succ='%d' else='%d' unkn='%d' merge='%d'>", cmp_op_text_xml (in->_.cmp.op),
		    in->_.cmp.succ, in->_.cmp.fail, in->_.cmp.unkn, in->_.cmp.end);
		SES_PRINT (s, "<left>");
		ssl_print_xml (bop->cmp_left, s);
		SES_PRINT (s, "</left>");
		SES_PRINT (s, "<right>");
		ssl_print_xml (bop->cmp_right, s);
		SES_PRINT (s, "</right>");
		SES_PRINT (s, "</if>");
	      }
	    else if (in->_.pred.func == distinct_comp_func)
	      {
		SES_PRINT (s, "<distinct>");
		ssl_array_print_xml (((hash_area_t *) in->_.pred.cmp)->ha_slots, s);
		SES_PRINT (s, "</distinct>");
	      }
	    break;
	  }

	case IN_COMPARE:
	  {
	    ses_sprintf (s, "<if op='%s' succ='%d' else='%d' unkn='%d' merge='%d'>", cmp_op_text_xml (in->_.cmp.op),
		in->_.cmp.succ, in->_.cmp.fail, in->_.cmp.unkn, in->_.cmp.end);
	    SES_PRINT (s, "<left>");
	    ssl_print_xml (in->_.cmp.left, s);
	    SES_PRINT (s, "</left>");
	    SES_PRINT (s, "<right>");
	    ssl_print_xml (in->_.cmp.right, s);
	    SES_PRINT (s, "</right>");
	    SES_PRINT (s, "</if>");
	    break;
	  }
	case INS_SUBQ:
	  {
	    qr_print_xml (qi, in->_.subq.query, s, "subq");
	    break;
	  }
	case IN_VRET:
	  SES_PRINT (s, "<vret>");
	  ssl_print_xml (in->_.vret.value, s);
	  SES_PRINT (s, "</vret>");
	  break;

	case IN_BRET:
	  ses_sprintf (s, "<bret ret='%d'/>", in->_.bret.bool_value);
	  break;

	case INS_CALL:
	case INS_CALL_BIF:
	  if (in->_.call.ret != (state_slot_t *)1)
	    {
	      ses_sprintf (s, "<call name='%s'>", in->_.call.proc); 
	      SES_PRINT (s, "<params>");
	      ssl_array_print_xml (in->_.call.params, s);
	      SES_PRINT (s, "</params>");
	      SES_PRINT (s, "<ret>");
	      ssl_print_xml (in->_.call.ret, s);
	      SES_PRINT (s, "</ret>");
	      SES_PRINT (s, "</call>");
	    }
	  else
	    {
	      unsigned _inx;
	      state_slot_t **ssls = in->_.call.params;
	      ses_sprintf (s, "<call name='%s'>", in->_.call.proc); 
	      SES_PRINT (s, "<ret>");
	      ssl_print (in->_.call.params[0]);
	      SES_PRINT (s, "</ret>");
	      SES_PRINT (s, "<params>");
	      for (_inx = 1; _inx < (ssls ? BOX_ELEMENTS (ssls) : 0); _inx++)
		{
		  state_slot_t *ssl = (state_slot_t *)ssls[_inx];
		  ssl_print_xml (ssl, s);
		}
	      SES_PRINT (s, "</params>");
	      SES_PRINT (s, "</call>");
	    }
	  break;
	case INS_OPEN:
	  SES_PRINT (s, "<open>");
	  SES_PRINT (s, "<cr>");
	  ssl_print_xml (in->_.open.cursor, s);
	  SES_PRINT (s, "</cr>");
	  qr_print_xml (qi, in->_.open.query, s, "qr");
	  SES_PRINT (s, "</open>");
	  break;

	case INS_FETCH:
	  SES_PRINT (s, "<fetch>");
	  SES_PRINT (s, "<cr>");
	  ssl_print_xml (in->_.fetch.cursor, s);
	  SES_PRINT (s, "</cr>");
	  SES_PRINT (s, "<into>");
	  ssl_array_print_xml (in->_.fetch.targets, s);
	  SES_PRINT (s, "</into>");
	  SES_PRINT (s, "</fetch>");
	  break;
	case INS_HANDLER:
	  ses_sprintf (s, "<handler label='%d'>", in->_.handler.label);
	    {
	      int inx;
	      DO_BOX (caddr_t *, state, inx, in->_.handler.states)
		{
		  ses_sprintf (s, "<state code='%s' />", IS_BOX_POINTER (state) ? state[0] : "not found");
		}
	      END_DO_BOX;
	    }
	  break;
	case INS_HANDLER_END:
	  ses_sprintf (s, "</handler>");
	  break;
	case INS_COMPOUND_START:
	  compound_level++;
	  ses_sprintf (s, "<comp level='%d' line='%d' src='%s'>", compound_level,
		in->_.compound_start.line_no,
		in->_.compound_start.file_name ? in->_.compound_start.file_name : ""
	      ); 
	  break;
	case INS_COMPOUND_END:
	  SES_PRINT (s, "</comp>");
	  break;

	case IN_JUMP:
	  ses_sprintf (s, "<jmp label='%d' lev='%d'/>", in->_.label.label, in->_.label.nesting_level);
	  break;

	case INS_QNODE:
	    {
	      data_source_t *new_node = (data_source_t *)in->_.qnode.node;
	      dk_set_t conts = new_node->src_continuations;
	      new_node->src_continuations = NULL;
	      SES_PRINT (s, "<qnode>");
	      node_print_xml (qi, s, new_node);
	      SES_PRINT (s, "</qnode>");
	      new_node->src_continuations = conts;
	    }
	  break;
	case INS_BREAKPOINT:
	  ses_sprintf (s, "<brk line='%d'/>", (int) in->_.breakpoint.line_no);
	  break;
	case INS_FOR_VECT:
	   {
	     SES_PRINT (s, "<vectored>");
	     SES_PRINT (s, "<in_vars>");
	     ssl_array_print_xml (in->_.for_vect.in_vars, s);
	     SES_PRINT (s, "</in_vars>");
	     SES_PRINT (s, "<in_values>");
	     ssl_array_print_xml (in->_.for_vect.in_values, s);
	     SES_PRINT (s, "</in_values>");
	     SES_PRINT (s, "<out_vars>");
	     ssl_array_print_xml (in->_.for_vect.out_vars, s);
	     SES_PRINT (s, "</out_vars>");
	     SES_PRINT (s, "<out_values>");
	     ssl_array_print_xml (in->_.for_vect.out_values, s);
	     SES_PRINT (s, "</out_values>");
	     SES_PRINT (s, "<code>");
	     code_vec_print_xml (qi, in->_.for_vect.code, s);
	     SES_PRINT (s, "<code>");
	     SES_PRINT (s, "</vectored>");
	   }
	 break;
	default:;
	}
    }
  END_DO_INSTR;
}

static void
node_print_code_xml (QI * qi, dk_session_t * s, data_source_t * qn)
{
  if (qn->src_pre_code)
    {
      SES_PRINT (s, "<pre_code>");
      code_vec_print_xml (qi, qn->src_pre_code, s);
      SES_PRINT (s, "</pre_code>");
    }
  if (qn->src_after_test)
    {
      SES_PRINT (s, "<after_test>");
      code_vec_print_xml (qi, qn->src_after_test, s);
      SES_PRINT (s, "</after_test>");
    }
  if (qn->src_after_code)
    {
      SES_PRINT (s, "<after_code>");
      code_vec_print_xml (qi, qn->src_after_code, s);
      SES_PRINT (s, "</after_code>");
    }
}

static char *
setp_ha_op_name (setp_node_t *setp)
{
  if (!setp->setp_ha)
    return "";
  switch (setp->setp_ha->ha_op)
    {
      case HA_FILL: return "build";
      case HA_DISTINCT: return "distinct";
      case HA_GROUP: return "group";
      case HA_ORDER: return "order";
      default: return "";
    }
}

void
node_print_xml (QI * qi, dk_session_t * s, data_source_t * qn)
{
  char buf[250];
  QI_CHECK_STACK (qi, &qn, 10000);
  if (IS_QN (qn, table_source_input) || IS_QN (qn, table_source_input_unique))
    {
      QNCAST (table_source_t, ts, qn);
      key_source_t * ks = ts->ts_order_ks;
      if (!ts->ts_order_ks->ks_from_temp_tree && ts->ts_order_ks->ks_key)
	snprintf (buf, sizeof (buf), "<ts key='%s' table='%s'>\n", ts->ts_order_ks->ks_key->key_name, ts->ts_order_ks->ks_key->key_table->tb_name);
      else
	snprintf (buf, sizeof (buf), "<ts key='temp'>\n");
      SES_PRINT (s, buf);
      node_print_code_xml (qi, s, qn);
      if (ks->ks_spec.ksp_spec_array)
	{
	  SES_PRINT (s, "<ks_spec>\n");
	  sp_list_print_xml (ks->ks_spec.ksp_spec_array, s);
	  SES_PRINT (s, "</ks_spec>");
	}
      if (ks->ks_row_spec)
	{
	  SES_PRINT (s, "<ks_row_spec>\n");
	  sp_list_print_xml (ks->ks_row_spec, s);
	  SES_PRINT (s, "</ks_row_spec>\n");
	}
      if (ks->ks_hash_spec)
	{
	  SES_PRINT (s, "<ks_hash_spec>\n");
	  DO_SET (search_spec_t *, sp, &ks->ks_hash_spec)
	    {
	      hash_range_spec_t * hrng = (hash_range_spec_t *)sp->sp_min_ssl;
	      if (hrng->hrng_hs || hrng->hrng_ht_id || hrng->hrng_ht)
		{
		  ses_sprintf (s, "<hrng hs='%d' flags='%d' />", hrng->hrng_hs ? hrng->hrng_hs->src_gen.src_sets : 0, hrng->hrng_flags); 
		}
	    }
	  END_DO_SET();
	  SES_PRINT (s, "</ks_hash_spec>\n");
	}
      SES_PRINT (s, "<ks_out_slots>\n");
      ssl_list_print_xml (ks->ks_out_slots, s);
      SES_PRINT (s, "</ks_out_slots>\n");
      SES_PRINT (s, "</ts>");
    }
  else if (IS_QN (qn, ts_split_input))
    {
      QNCAST (ts_split_node_t, tssp, qn);
      SES_PRINT (s, "<alt-ts>\n");
      node_print_code_xml (qi, s, qn);
      node_print_xml (qi, s, (data_source_t *) tssp->tssp_alt_ts);
      SES_PRINT (s, "</alt-ts>");
    }
  else if (IS_QN (qn, query_frag_input))
    {
      QNCAST (query_frag_t, qf, qn);
      ses_sprintf (s, "<qf>");
      node_print_xml (qi, s, qf->qf_head_node);
      SES_PRINT (s, "</qf>");
    }
  else if (IS_QN (qn, dpipe_node_input))
    {
      int inx;
      QNCAST (dpipe_node_t, dp, qn);
      SES_PRINT (s, "<dpipe>");
      DO_BOX (cu_func_t *, cf, inx, dp->dp_funcs)
	{
	  ses_sprintf (s, "<func name='%s'>", cf->cf_name);
	  SES_PRINT (s, "<in>");
	  ssl_print_xml (dp->dp_inputs[inx], s);
	  SES_PRINT (s, "</in>");
	  SES_PRINT (s, "<out>");
	  ssl_print_xml (dp->dp_outputs[inx], s);
	  SES_PRINT (s, "</out>");
	  SES_PRINT (s, "</func>");
	}
      END_DO_BOX;
      SES_PRINT (s, "</dpipe>");
    }
  else if (IS_QN (qn, ssa_iter_input))
    {
      SES_PRINT (s, "<ssi />");
    }
  else if (IS_QN (qn, cl_fref_read_input))
    {
      SES_PRINT (s, "<clf />");
    }
  else if (IS_QN (qn, code_node_input))
    {
      QNCAST (code_node_t, cn, qn);
      SES_PRINT (s, "<cn>");
      code_vec_print_xml (qi, cn->cn_code, s);
      SES_PRINT (s, "</cn>");
    }
  else if (IS_QN (qn, qf_select_node_input))
    {
      QNCAST (qf_select_node_t, qfs, qn);
      SES_PRINT (s, "<qfs>");
      ssl_array_print_xml (qfs->qfs_out_slots, s);
      SES_PRINT (s, "<qfs>");
    }
  else if (IS_QN (qn, skip_node_input))
    {
      QNCAST (skip_node_t, sk, qn);
      SES_PRINT (s, "<skip>");
      ssl_print_xml (sk->sk_top, s);
      ssl_print_xml (sk->sk_top_skip, s);
      ssl_print_xml (sk->sk_set_no, s);
      SES_PRINT (s, "</skip>");
    }
  else if (IS_QN (qn, sort_read_input))
    {
      SES_PRINT (s, "<sr />");
    }
  else if (IS_QN (qn, chash_read_input))
    {
      SES_PRINT (s, "<chash />");
    }
  else if (IS_QN (qn, select_node_input))
    {
      select_node_t *sel = (select_node_t *) qn;
      /* top/skip */
      ses_sprintf (s, "<sel>");
      node_print_code_xml (qi, s, qn);
      ssl_array_print_xml (sel->sel_out_slots, s);
      SES_PRINT (s, "</sel>");
    }
  else if (IS_QN (qn, select_node_input_subq))
    {
      select_node_t *sel = (select_node_t *) qn;
      /* top/skip */
      SES_PRINT (s, "<sel>");
      node_print_code_xml (qi, s, qn);
      SES_PRINT (s, "<out>");
      ssl_array_print_xml (sel->sel_out_slots, s);
      SES_PRINT (s, "</out>");
      SES_PRINT (s, "</sel>");
    }
  else if (IS_QN (qn, setp_node_input))
    {
      setp_node_t *setp = (setp_node_t *) qn;
      ses_sprintf (s, "<setp ha_op='%s' hf='%d' sets='%d'>", 
	  	setp_ha_op_name (setp), 
		setp->setp_ha && setp->setp_ha->ha_op == HA_FILL ? setp->setp_ha->ha_tree->ssl_index : 0,
		qn->src_sets);
      if (setp->setp_ha)
	{
	  int inx;
	  SES_PRINT (s, "<key>");
	  for (inx = 0; inx < setp->setp_ha->ha_n_keys; inx ++)
	    {
	      ssl_print_xml (setp->setp_ha->ha_slots[inx], s);
	    }
	  SES_PRINT (s, "</key>");
	  SES_PRINT (s, "<dep>");
	  for (; inx < setp->setp_ha->ha_n_keys + setp->setp_ha->ha_n_deps; inx ++)
	    {
	      ssl_print_xml (setp->setp_ha->ha_slots[inx], s);
	    }
	  SES_PRINT (s, "</dep>");
	}
      SES_PRINT (s, "</setp>");
    }
  else if (IS_QN (qn, fun_ref_node_input))
    {
      fun_ref_node_t *fref = (fun_ref_node_t *) qn;
      ses_sprintf (s, "<fref sets='%d'>", qn->src_sets);
      node_print_xml (qi, s, fref->fnr_select);
      SES_PRINT (s, "</fref>");
    }
  else if (IS_QN (qn, hash_fill_node_input))
    {
      fun_ref_node_t *fref = (fun_ref_node_t *) qn;
      ses_sprintf (s, "<hf sets='%d'>", qn->src_sets);
      node_print_xml (qi, s, fref->fnr_select);
      SES_PRINT (s, "</hf>");
    }
  else if (IS_QN (qn, remote_table_source_input))
    {
      QNCAST (remote_table_source_t, rts, qn);
      SES_PRINT (s, "<rts>");
      node_print_code_xml (qi, s, qn);
      SES_PRINT (s, "<text><![CDATA[");
      SES_PRINT (s, rts->rts_text);
      SES_PRINT (s, "]]></text>");
      if (rts->rts_params)
	{
	  SES_PRINT (s, "<params>");
	  ssl_list_print_xml (rts->rts_params, s);
	  SES_PRINT (s, "</params>");
	}
      if (rts->rts_out_slots)
	{
	  SES_PRINT (s, "<out>");
	  ssl_array_print_xml (rts->rts_out_slots, s);
	  SES_PRINT (s, "</out>");
	}
      if (rts->rts_after_join_test)
	{
	  SES_PRINT (s, "<after_join_test>");
	  code_vec_print_xml (qi, rts->rts_after_join_test, s);
	  SES_PRINT (s, "</after_join_test>");
	}
      SES_PRINT (s, "</rts>");
    }
  else if (IS_QN (qn, breakup_node_input))
    {
      QNCAST (breakup_node_t, brk, qn);
      SES_PRINT (s, "<brk>");
      ssl_array_print_xml (brk->brk_output, s);
      ssl_array_print_xml (brk->brk_all_output, s);
      SES_PRINT (s, "</brk>");
    }
  else if (IS_QN (qn, subq_node_input))
    {
      subq_source_t *sqs = (subq_source_t *) qn;
      SES_PRINT (s, "<subq>\n");
      node_print_code_xml (qi, s, qn);
      node_print_xml (qi, s, sqs->sqs_query->qr_head_node);
      SES_PRINT (s, "</subq>");
    }
  else if (IS_QN (qn, union_node_input))
    {
      union_node_t *uni = (union_node_t *) qn;
      SES_PRINT (s, "<union>\n");
      node_print_code_xml (qi, s, qn);
      DO_SET (query_t *, qr, &uni->uni_successors)
      {
	node_print_xml (qi, s, qr->qr_head_node);
      }
      END_DO_SET ();
      SES_PRINT (s, "</union>");
    }
  else if (IS_QN (qn, gs_union_node_input))
    {
      QNCAST (gs_union_node_t, gsu, qn);
      SES_PRINT (s, "<gsu>");
      node_print_code_xml (qi, s, qn);
      DO_SET (data_source_t *, nd, &gsu->gsu_cont)
      {
	SES_PRINT (s, "<branch>");
	node_print_xml (qi, s, nd);
	SES_PRINT (s, "</branch>");
      }
      END_DO_SET ();
      SES_PRINT (s, "</gsu>");
    }
  else if (IS_QN (qn, update_node_input))
    {
      int inx;
      QNCAST (update_node_t, upd, qn);
      ses_sprintf (s, "<upd tb='%s'>", upd->upd_table->tb_name);
      node_print_code_xml (qi, s, qn);
      SES_PRINT (s, "<place>");
      ssl_print_xml (upd->upd_place, s);
      SES_PRINT (s, "</place>");
      SES_PRINT (s, "<values>");
      ssl_array_print_xml (upd->upd_values, s);
      SES_PRINT (s, "</values>");
      if (upd->upd_keys)
	{
	  DO_BOX (ins_key_t *, ik, inx, upd->upd_keys)
	    {
	      if (!ik)
		continue;
		ses_sprintf (s, "<key name='%s'>", ik->ik_key->key_name);
		if (ik->ik_slots)
		  ssl_array_print_xml (ik->ik_slots, s);
		SES_PRINT (s, "</key>");
	    }
	  END_DO_BOX;
	}
      SES_PRINT (s, "</upd>");
    }
  else if (IS_QN (qn, delete_node_input))
    {
      QNCAST (delete_node_t, del, qn);
      ses_sprintf (s, "<del tb='%s' key='%s'>", 
	  del->del_table->tb_name, 
	  del->del_key_only ? del->del_key_only->key_name : "");
      node_print_code_xml (qi, s, qn);
      SES_PRINT (s, "<place>");
      ssl_print_xml (del->del_place, s);
      SES_PRINT (s, "</place>");
      if (del->del_keys)
	{
	  int inx;
	  DO_BOX (ins_key_t *, ik, inx, del->del_keys)
	    if (ik)
	      {
		ses_sprintf (s, "<key name='%s'>", ik->ik_key->key_name);
		if (ik->ik_del_slots)
		  ssl_array_print_xml (ik->ik_del_slots, s);
		SES_PRINT (s, "</key>");
	      }
	  END_DO_BOX;
	}
      SES_PRINT (s, "</del>");
    }
  else if (IS_QN (qn, insert_node_input))
    {
      QNCAST (insert_node_t, ins, qn);
      ses_sprintf (s, "<ins tb='%s' key='%s'>", ins->ins_table->tb_name, ins->ins_key_only ? ins->ins_key_only : "");
      node_print_code_xml (qi, s, qn);
      SES_PRINT (s, "</ins>");
    }
  else if (IS_QN (qn, hash_source_input))
    {
      QNCAST (hash_source_t, hs, qn);
      ses_sprintf (s, "<hs hf='%d'>", hs->hs_filler->src_gen.src_sets);
      node_print_code_xml (qi, s, qn);
      SES_PRINT (s, "</hs>");
    }
  else if (IS_QN (qn, rdf_inf_pre_input))
    {
      QNCAST (rdf_inf_pre_node_t, ri, qn);
      char * mode = "";
      switch (ri->ri_mode)
	{
	case RI_SUBCLASS: mode = "subclass"; break;
	case RI_SUPERCLASS: mode = "superclass"; break;
	case RI_SUBPROPERTY: mode = "subproperty"; break;
	case RI_SUPERPROPERTY: mode = "superproperty"; break;
	case RI_SAME_AS_O: mode = "same-as-O"; break;
	case RI_SAME_AS_S: mode = "same-as-S"; break;
	case RI_SAME_AS_P: mode = "same-as-P"; break;
	}
      ses_sprintf (s, "<ri mode='%s'>", mode);
      node_print_code_xml (qi, s, qn);
      SES_PRINT (s, "<p>");
      ssl_print_xml (ri->ri_p, s);
      SES_PRINT (s, "</p>");
      SES_PRINT (s, "<o>");
      ssl_print_xml (ri->ri_o, s);
      SES_PRINT (s, "</o>");
      SES_PRINT (s, "<out>");
      ssl_print_xml (ri->ri_output, s);
      SES_PRINT (s, "</out>");
      SES_PRINT (s, "</ri>");
    }
  else if (IS_QN (qn, trans_node_input))
    {
      QNCAST (trans_node_t, tn, qn);
      ses_sprintf (s, "<trans ctx='%s' dir='%d'>", 
	  tn->tn_prepared_step && tn->tn_ifp_ctx_name ? tn->tn_ifp_ctx_name : "",
	  tn->tn_direction
	  );
      node_print_code_xml (qi, s, qn);
      SES_PRINT (s, "<in>");
      ssl_array_print_xml (tn->tn_input, s);
      SES_PRINT (s, "</in>");
      SES_PRINT (s, "<shadow>");
      ssl_array_print_xml (tn->tn_input_ref, s);
      SES_PRINT (s, "</shadow>");
      SES_PRINT (s, "<out>");
      ssl_array_print_xml (tn->tn_output, s);
      SES_PRINT (s, "</out>");
      /* more to be added */
      SES_PRINT (s, "</trans>");
    }
  else if (IS_QN (qn, stage_node_input))
    {
      QNCAST (stage_node_t, stn, qn);
      ses_sprintf (s, "<stn nth='%d'/>", stn->stn_nth);
    }
  else if (IS_QN (qn, in_iter_input))
    {
      QNCAST (in_iter_node_t, ii, qn);
      SES_PRINT (s, "<iter>");
      node_print_code_xml (qi, s, qn);
      SES_PRINT (s, "<in>");
      ssl_array_print_xml (ii->ii_values, s);
      SES_PRINT (s, "</in>");
      SES_PRINT (s, "<out>");
      ssl_print_xml (ii->ii_output, s);
      SES_PRINT (s, "</out>");
      SES_PRINT (s, "</iter>");
    }
  else if (IS_QN (qn, outer_seq_end_input))
    {
      outer_seq_end_node_t * ose = (outer_seq_end_node_t *)qn;
      ses_sprintf (s, "<ose sets='%d'>", qn->src_sets);
      node_print_code_xml (qi, s, qn);
      SES_PRINT (s, "<out>");
      ssl_array_print_xml (ose->ose_out_slots, s);
      SES_PRINT (s, "</out>");
      SES_PRINT (s, "<shadow>");
      ssl_array_print_xml (ose->ose_out_shadow, s);
      SES_PRINT (s, "</shadow>");
      SES_PRINT (s, "</ose>");
      SES_PRINT (s, "</outer>\n");
    }
  else if (IS_QN (qn, set_ctr_input))
    {
      QNCAST (set_ctr_node_t, sctr, qn);
      outer_seq_end_node_t * ose = sctr->sctr_ose;
      if (ose)
	SES_PRINT (s, "<outer>\n");
      ses_sprintf (s, "<sctr sctr_ose='%d'/>", ose ? ose->src_gen.src_sets : 0);
    }
  else if (IS_QN (qn, txs_input))
    {
      QNCAST (text_node_t, txs, qn);
      ses_sprintf (s, "<txs op='%scontains' tb='%s' card='%.2g' geo='%s'>", 
	  txs->txs_xpath_text_exp ? "x" : "",
	  txs->txs_table->tb_name, txs->txs_card, 
	  txs->txs_geo ? predicate_name_of_gsop (txs->txs_geo) : "");
      node_print_code_xml (qi, s, qn);
      SES_PRINT (s, "<exp>");
      ssl_print_xml (txs->txs_text_exp, s);
      SES_PRINT (s, "</exp>");
      SES_PRINT (s, "<d_id>");
      ssl_print_xml (txs->txs_d_id, s);
      SES_PRINT (s, "</d_id>");
      SES_PRINT (s, "</txs>");
    }
  else if (IS_QN (qn, xn_input))
    {
      QNCAST (xpath_node_t, xn, qn);
      ses_sprintf (s, "<xn op='%s'>", 'q' == xn->xn_predicate_type ? "xquery" : "xpath");
      SES_PRINT (s, "<tcol>");
      ssl_print_xml (xn->xn_text_col, s);
      SES_PRINT (s, "</tcol>");
      SES_PRINT (s, "<out>");
      ssl_print_xml (xn->xn_output_val, s);
      SES_PRINT (s, "</out>");
      SES_PRINT (s, "</xn>");
    }
  else if (IS_QN (qn, end_node_input))
    {
      node_print_code_xml (qi, s, qn);
      SES_PRINT (s, "<end />");
    }
  else
    {
      SES_PRINT (s, "<node>");
      node_print_code_xml (qi, s, qn);
      SES_PRINT (s, "</node>");
    }
  SES_PRINT (s, "\n");
  if (qn->src_continuations)
    node_print_xml (qi, s, (data_source_t *) qn->src_continuations->data);
}

static caddr_t
qr_print_top_xml (QI * qi, query_t * qr)
{
  dk_session_t * s = strses_allocate ();
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_QST, qi);
  SES_PRINT (s, "<report>\n");
  if (qr->qr_parms)
    {
      SES_PRINT (s, "<params>");
      ssl_list_print_xml (qr->qr_parms, s);
      SES_PRINT (s, "</params>");
    }
  node_print_xml (qi, s, qr->qr_head_node);
  SES_PRINT (s, "</report>\n");
  return (caddr_t) s;
} 

caddr_t
sqlc_text_no_semi (caddr_t text)
{
  int l = strlen (text) - 1;
  while (l > 0 && (' ' ==  text[l] || '\n' == text[l] || '\r' == text[l]))
    l--;
  if (l && ';' == text[l])
    l--;
  return box_n_chars ((db_buf_t)text, l + 1);
}


static caddr_t
bif_explain (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_t * qr;
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t err = NULL;
  caddr_t text = bif_string_arg (qst, args, 0, "explain");
  int cr_type = SQLC_DO_NOT_STORE_PROC, xml_out = 0;
  int old_debug = -1;

  if (BOX_ELEMENTS (args) > 1)
    cr_type = (int) bif_long_arg (qst, args, 1, "explain");
  if (cr_type == SQLC_SQLO_VERBOSE)
    {
      cr_type = SQLC_DO_NOT_STORE_PROC;
      old_debug = sqlo_print_debug_output;
      sqlo_print_debug_output = 1;
    }
  if (BOX_ELEMENTS (args) > 2)
    xml_out = (int) bif_long_arg (qst, args, 2, "explain");
  text = sqlc_text_no_semi (text);
  qr = sql_compile (text, qi->qi_client, &err, cr_type);
  dk_free_box (text);
  if (old_debug != -1)
    sqlo_print_debug_output = old_debug;
  if (err)
    {
      if (SQLC_SQLO_SCORE != cr_type && (qr && !qr->qr_proc_name))
	qr_free (qr);
      if (strstr (((caddr_t*)err)[2], "RDFNI"))
	{
	  dk_free_tree (err);
	  err = NULL;
	  cl_rdf_inf_init (bootstrap_cli, &err);
	  if (!err)
	    return bif_explain (qst, err_ret, args);
	}
      sqlr_resignal (err);
    }
  if (SQLC_SQLO_SCORE == cr_type)
    return (caddr_t)qr;
  if (SQLC_TRY_SQLO == cr_type)
    return NULL;
  else if (SQLC_PARSE_ONLY == cr_type)
    return (caddr_t) qr;
  if (xml_out || dbf_explain_level == 4)
    return qr_print_top_xml (qi, qr);
  trset_start (qst);
  if (QR_IS_MODULE (qr))
    {
      dbe_schema_t *sc = isp_schema (qi->qi_space);
      query_t **pproc;
      id_casemode_hash_iterator_t it;

      id_casemode_hash_iterator (&it, sc->sc_name_to_object[sc_to_proc]);
      stmt_printf (("Module %s : {\n", qr->qr_proc_name));
      while (id_casemode_hit_next (&it, (caddr_t *) & pproc))
	{
	  if (!pproc || !*pproc)
	    continue;
	  if ((*pproc)->qr_module == qr)
	    {
	      stmt_printf (("Procedure %s : {\n", (*pproc)->qr_proc_name));
	      qr_print (*pproc);
	      stmt_printf (("}\n"));
	    }
	}
      stmt_printf (("}\n"));
    }
  else
    qr_print_top (qr);
  /* stmt_printf (("\n")); */
  trset_end ();
  if (qr && !qr->qr_proc_name)
    qr_free (qr);
  return NULL;
}


static caddr_t
bif_procedure_cols (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t proc_name = bif_string_or_null_arg (qst, args, 0, "procedure_cols");
  query_t * qr;
  char *full_name = proc_name;
  dk_set_t out_set = NULL;
  caddr_t out;
  char pq[MAX_NAME_LEN];
  char po[MAX_NAME_LEN];
  char pn[MAX_NAME_LEN];
  int inx;

#if 0
  if (qi->qi_client->cli_ws)
    return NULL; /* not for HTTP */
#endif
  if (!proc_name)
    return NULL;
  full_name = sch_full_proc_name (isp_schema (qi->qi_space), proc_name,
      qi->qi_client->cli_qualifier, CLI_OWNER (qi->qi_client));
  if (!full_name)
    return NULL;
  qr = sch_proc_def (isp_schema (qi->qi_space), full_name);
  if (!qr)
    {
      full_name = sch_full_proc_name (isp_schema (qi->qi_space), proc_name,
	  qi->qi_client->cli_qualifier, CLI_OWNER (qi->qi_client));
      if (!full_name)
	return NULL;
      qr = sch_proc_def (isp_schema (qi->qi_space), full_name);
    }
  if (!qr || QR_IS_MODULE (qr))
    return NULL;
  if (!sec_proc_check (qr, qi->qi_client->cli_user->usr_id, qi->qi_client->cli_user->usr_g_id))
    return NULL;
  if (qr->qr_to_recompile)
    qr = qr_recompile (qr, NULL);
  sch_split_name (NULL, full_name, pq, po, pn);

  if (qr->qr_proc_ret_type)
    {
      caddr_t *col = (caddr_t *) dk_alloc_box (10 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      ptrlong *rtype = (ptrlong *) qr->qr_proc_ret_type;
      col[0] = box_dv_short_string (pq);
      col[1] = box_dv_short_string (po);
      col[2] = box_dv_short_string (pn);
      col[3] = box_dv_short_string ("");
      col[4] = box_num (SQL_RETURN_VALUE);
      col[5] = box_num ((dtp_t) rtype[0]);
      col[6] = BOX_ELEMENTS (rtype) > 2 ? box_num (rtype[2]) : dk_alloc_box (0, DV_DB_NULL);
      col[7] = box_num (rtype[1]);
      col[8] = box_num (1);
      col[9] = box_num (0);
      dk_set_push (&out_set, col);
    }

  inx = 1;
  DO_SET (state_slot_t *, ssl, &qr->qr_parms)
    {
      caddr_t *col =
	  proc_result_col_from_ssl (inx++, ssl,
	      (ssl->ssl_type == SSL_REF_PARAMETER_OUT ? SQL_PARAM_OUTPUT :
	       (ssl->ssl_type == SSL_REF_PARAMETER ? SQL_PARAM_INPUT_OUTPUT :
		(ssl->ssl_type == SSL_PARAMETER ? SQL_PARAM_INPUT : SQL_PARAM_TYPE_UNKNOWN))),
	  box_dv_short_string (pq),
	  box_dv_short_string (po),
	  box_dv_short_string (pn));
      dk_set_push (&out_set, col);
    }
  END_DO_SET ();
  if (qr->qr_proc_result_cols)
    {
      dk_set_t out1 = dk_set_copy (qr->qr_proc_result_cols);
      DO_SET (caddr_t *, col, &out1)
	{
	  if (!col[0])
	    {
	      col[0] = box_dv_short_string (pq);
	      col[1] = box_dv_short_string (po);
	      col[2] = box_dv_short_string (pn);
	    }
	}
      END_DO_SET ();
      dk_set_conc (out1, out_set);
      out_set = out1;
    }
  out = list_to_array (dk_set_nreverse (out_set));
  return (out);
}

static caddr_t
bif_sql_parse (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * tree;
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t err = NULL;
  caddr_t text = bif_string_arg (qst, args, 0, "sql_parse");
  int cr_type = SQLC_PARSE_ONLY;
  tree = (caddr_t *) sql_compile (text, qi->qi_client, &err, cr_type);
  if (err)
    sqlr_resignal (err);
  return ((caddr_t)(tree));
}

#define MAX_TEXT_SZ 20000

int
xsql_print_stmt (sql_comp_t * sc, comp_table_t * ct, ST * tree, char * text, size_t tlen, int * fill)
{
  if (DV_SYMBOL == DV_TYPE_OF (tree))
    {
      sprintf_more (text, tlen, fill, " %s ", (caddr_t) tree);
      return 1;
    }
  if (ST_COLUMN (tree, COL_DOTTED))
    {
      caddr_t pref = tree->_.col_ref.prefix;
      sprintf_more (text, tlen, fill, " ");
      if (IS_BOX_POINTER (pref) && ((DV_STRING == box_tag (pref)) || (DV_SYMBOL == box_tag (pref))))
	sprintf_more (text, tlen, fill, "%s.", pref);
      sprintf_more (text, tlen, fill, "%s ", tree->_.col_ref.name);
      return 1;
    }
  else if (ST_P (tree, TABLE_DOTTED))
    {
      sqlc_quote_dotted (text, tlen, fill, tree->_.table.name);
      if (tree->_.table.prefix)
	sprintf_more (text, tlen, fill, " \"%s\" ", tree->_.table.prefix);
      return 1;
    }
  else if (ST_P (tree, INSERT_STMT))
    {
      sprintf_more (text, tlen, fill, "INSERT INTO ");
      sqlc_exp_print (sc, NULL, tree->_.insert.table, text, tlen, fill);
      if (tree->_.insert.cols && BOX_ELEMENTS (tree->_.insert.cols))
	{
	  int first = 1, inx;
	  sprintf_more (text, tlen, fill, " (");
	  DO_BOX (char *, col, inx, tree->_.insert.cols)
	    {
	      if (!first)
		sprintf_more (text, tlen, fill, ", ");
	      else
		first = 0;
	      sqlc_quote_dotted (text, tlen, fill, col);
	      sprintf_more (text, tlen, fill, " ");
	    }
	  END_DO_BOX;
	  sprintf_more (text, tlen, fill, ") ");
	}
      if (ST_P (tree->_.insert.vals, INSERT_VALUES))
	{
	  sprintf_more (text, tlen, fill, " VALUES (");
	  sqlc_insert_commalist (sc, ct,
	      tree, NULL, text, tlen, fill, 0);
	  sprintf_more (text, tlen, fill, ")");
	}
      else
	{
	  sqlc_subquery_text (sc, NULL, tree->_.insert.vals, text, tlen, fill, NULL);
	}
      return 1;
    }
  else if (ST_P (tree, DELETE_SRC))
    {
      sprintf_more (text, tlen, fill, "DELETE FROM  ");
      sqlc_exp_print (sc, NULL, *(tree->_.delete_src.table_exp->_.table_exp.from), text, tlen, fill);
      if (tree->_.delete_src.table_exp->_.table_exp.where)
	{
	  sprintf_more (text, tlen, fill, " WHERE ");
	  sqlc_exp_print (sc, NULL,
	      tree->_.delete_src.table_exp->_.table_exp.where, text, tlen, fill);
	}
      return 1;
    }
  else if (ST_P (tree, UPDATE_SRC))
    {
      {
	int first = 1, inx;
	sprintf_more (text, tlen, fill, "UPDATE ");
	sqlc_exp_print (sc, NULL, tree->_.update_src.table, text, tlen, fill);
	sprintf_more (text, tlen, fill, " SET ");
	DO_BOX (ST *, exp, inx, tree->_.update_src.vals)
	  {
	    if (!first)
	      sprintf_more (text, tlen, fill, ", ");
	    else
	      first = 0;
	    sprintf_more (text, tlen, fill, " ");
	    sqlc_quote_dotted (text, tlen, fill, (char *)tree->_.update_src.cols[inx]);
	    sprintf_more (text, tlen, fill, " = ");
	    sqlc_exp_print (sc, NULL, exp, text, tlen, fill);
	  }
	END_DO_BOX;
	if (tree->_.update_src.table_exp->_.table_exp.where)
	  {
	    sprintf_more (text, tlen, fill, " WHERE ");
	    sqlc_exp_print (sc, NULL,
		tree->_.update_src.table_exp->_.table_exp.where,
		text, tlen, fill);
	  }
      }
      return 1;
    }
  else if (ST_P (tree, CALL_STMT))
    {
      caddr_t *name = (caddr_t *)tree->_.call.name;
      ST ** tmp;
      if (!ARRAYP (name) && !CASEMODESTRCMP ((char *)name, "_cvt"))
	{
	  dtp_t dtp = (dtp_t) ((ST *)(tree->_.call.params[0]->_.op.arg_1))->type;
          sprintf_more (text, tlen, fill, " CAST (");
	  sqlc_exp_print (sc, NULL, tree->_.call.params[1], text, tlen, fill);
	  sprintf_more (text, tlen, fill, " AS %s )", dv_type_title (dtp));
	  return 1;
	}
      else if (!ARRAYP (name) || BOX_ELEMENTS (name) != 2 ||
	  !ARRAYP (tree->_.call.params) || BOX_ELEMENTS (tree->_.call.params) != 1)
	return 0;
      tmp = (ST **) name;
      sprintf_more (text, tlen, fill, " (");
      sqlc_exp_print (sc, NULL, tree->_.call.params[0], text, tlen, fill);
      sprintf_more (text, tlen, fill, " AS ");
      sprintf_more (text, tlen, fill, "%s", (caddr_t)tmp[1]);
      sprintf_more (text, tlen, fill, " ).");
      sqlc_exp_print (sc, NULL, tmp[0], text, tlen, fill);
      return 1;
    }
  else if (ST_P (tree, COALESCE_EXP))
    {
      sprintf_more (text, tlen, fill, "COALESCE (");
      sqlc_exp_commalist_print(sc, ct, (ST **) tree->_.comma_exp.exps, text, tlen, fill, NULL, NULL);
      sprintf_more (text, tlen, fill, ")");
      return 1;
    }
  return 0;
}

static caddr_t
bif_sql_text (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t volatile err = NULL;
  ST * tree = (ST *) bif_array_arg (qst, args, 0, "sql_text");
  SCS_STATE_FRAME;
  sql_comp_t sc;
  comp_context_t cc;
  client_connection_t * cli = qi->qi_client, *old_cli = sqlc_client();
  char text[MAX_TEXT_SZ];
  int f = 0;
  int * fill = &f;
  query_t * qr;
  DK_ALLOC_QUERY (qr);
  memset (&sc, 0, sizeof (sc));
  CC_INIT (cc, cli);
  sc.sc_cc = &cc;
  sc.sc_client = cli;

  sc.sc_exp_print_hook = xsql_print_stmt;

  MP_START();
  semaphore_enter (parse_sem);
  SCS_STATE_PUSH;
  sqlc_target_rds (local_rds);

  top_sc = &sc;
  sqlc_set_client (cli);
  CATCH (CATCH_LISP_ERROR)
    {
      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR, NULL);
      memset (text, 0, sizeof (text));
      sqlc_exp_print (&sc, NULL, tree, text, sizeof (text), fill);
    }
  THROW_CODE
    {
      err = (caddr_t) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR);
      if (!err)
	err = srv_make_new_error ("42000", "SR105", "Unclassified SQL error.");
    }
  END_CATCH;
  sqlc_set_client (old_cli);
  SCS_STATE_POP;
  MP_DONE();
  semaphore_leave (parse_sem);
  sc_free (&sc);
  qr_free (qr);

  if (err)
    sqlr_resignal (err);
  return ((caddr_t)(box_dv_short_string (text)));
}



typedef struct  qnw_mrg_cd_s
{
  query_instance_t * 	qnw_qi_from;
  int64 **		qnw_serial;
  int			qnw_fill;
  int		qnw_read_to;
  int64		qnw_hash;
} qnw_cd_t;


void
qnw_merge_cb (query_instance_t * qi, data_source_t * qn, qnw_cd_t * qnw)
{
  if (qn->src_stat)
    {
      caddr_t * inst = (caddr_t*)qi, * inst2 = (caddr_t*)qnw->qnw_qi_from;
      src_stat_t * srs = (src_stat_t*)&inst[qn->src_stat];
      src_stat_t * srs2 = (src_stat_t*)&inst2[qn->src_stat];
      srs->srs_n_in += srs2->srs_n_in;
      srs->srs_n_out += srs2->srs_n_out;
      srs->srs_cum_time += srs2->srs_cum_time;
      memzero (srs2, sizeof (src_stat_t));
    }
}


int
col_id_is_rdf_p (oid_t id)
{
  dbe_column_t * col = sch_id_to_column (wi_inst.wi_schema, id);
  return col && 'P' == col->col_name[0] && 0 == col->col_name[1];
}


void
qnw_sp_hash (search_spec_t * sp, int64 * hash)
{
  MHASH_STEP (*hash, (sp->sp_cl.cl_col_id * 256 + sp->sp_min_op * 16 + sp->sp_max_op));
  if (sp->sp_min_ssl)
    MHASH_STEP (*hash, sp->sp_min_ssl->ssl_index);
  if (sp->sp_min_ssl)
    {
      MHASH_STEP (*hash, sp->sp_min_ssl->ssl_index);
      if (SSL_CONSTANT == sp->sp_min_ssl->ssl_type && col_id_is_rdf_p (sp->sp_cl.cl_col_id))
	MHASH_STEP (*hash, unbox_iri_int64 (sp->sp_min_ssl->ssl_constant));
    }
  if (sp->sp_max_ssl)
    MHASH_STEP (*hash, sp->sp_max_ssl->ssl_index);
}


void
qnw_hash (query_instance_t * qi, data_source_t * qn, qnw_cd_t * qnw)
{
  int inx;
  if (!qn)
    {
      MHASH_STEP (qnw->qnw_hash, 1);
      return;
    }
  if (IS_TS (((table_source_t*)qn)))
    {
      key_source_t * ks = ((table_source_t *)qn)->ts_order_ks;
      search_spec_t * sp;
      int n_out = ks->ks_v_out_map ? box_length (ks->ks_v_out_map) / sizeof (v_out_map_t) : 0;
      MHASH_STEP (qnw->qnw_hash, ks->ks_key->key_id);
      for (inx = 0; inx < n_out; inx++)
	{
	  v_out_map_t * om = &ks->ks_v_out_map[inx];
	  MHASH_STEP (qnw ->qnw_hash, om->om_cl.cl_col_id);
	  if (om->om_ssl)
	    MHASH_STEP (qnw->qnw_hash, om->om_ssl->ssl_index);
	}
      for (sp = ks->ks_spec.ksp_spec_array; sp; sp = sp->sp_next)
	qnw_sp_hash (sp, &qnw->qnw_hash);
      for (sp = ks->ks_row_spec; sp; sp = sp->sp_next)
	qnw_sp_hash (sp, &qnw->qnw_hash);
    }
  else if ((qn_input_fn) update_node_input == qn->src_input)
    {
      QNCAST (update_node_t, upd, qn);
      if (!upd->upd_table)
	return;
      MHASH_STEP (qnw->qnw_hash, upd->upd_table->tb_primary_key->key_id);
    }
  else if ((qn_input_fn) delete_node_input == qn->src_input)
    {
      QNCAST (delete_node_t, del, qn);
      MHASH_STEP (qnw->qnw_hash, del->del_table->tb_primary_key->key_id);

    }
  else if ((qn_input_fn) deref_node_input == qn->src_input)
    return;
  else if ((qn_input_fn) setp_node_input == qn->src_input)
    {
      QNCAST (setp_node_t, setp, qn);
      if (setp->setp_ha)
	{
	  DO_BOX (state_slot_t *, ssl, inx, setp->setp_keys_box)
	    MHASH_STEP (qnw->qnw_hash, ssl->ssl_index);
	  END_DO_BOX;
	  DO_BOX (state_slot_t *, ssl, inx, setp->setp_dependent_box)
	    MHASH_STEP (qnw->qnw_hash, ssl->ssl_index);
	  END_DO_BOX;
	}
    }
  else if ((qn_input_fn) select_node_input_subq == qn->src_input)
    {
      QNCAST (select_node_t, sel, qn);
      DO_BOX (state_slot_t *, ssl, inx, sel->sel_out_slots)
	if (ssl)
	  MHASH_STEP (qnw->qnw_hash, ssl->ssl_index);
      END_DO_BOX;
    }
  else if ((qn_input_fn) in_iter_input == qn->src_input)
    {
      QNCAST (in_iter_node_t, ii, qn);
      MHASH_STEP (qnw->qnw_hash, ii->ii_output->ssl_index);
    }
  else if ((qn_input_fn) rdf_inf_pre_input == qn->src_input)
    {
      QNCAST (rdf_inf_pre_node_t, ri, qn);
      MHASH_STEP (qnw->qnw_hash, ri->ri_iter.in_output->ssl_index);
    }
  if (IS_CL_TXS (qn))
    {
      QNCAST (text_node_t, txs, qn);
      MHASH_STEP (qnw->qnw_hash, txs->txs_d_id->ssl_index);
    }
  else if ((qn_input_fn)dpipe_node_input == qn->src_input)
    {
      QNCAST (dpipe_node_t, dp, qn);
      DO_BOX_0 (state_slot_t *, ssl, inx, dp->dp_inputs)
	MHASH_STEP (qnw->qnw_hash, dp->dp_inputs[inx]->ssl_index);
      END_DO_BOX;
    }
}


void
qnw_serialize (query_instance_t * qi, data_source_t * qn, qnw_cd_t * qnw)
{
  int64 * ser;
  if (qn->src_stat)
    {
      caddr_t * inst = (caddr_t*)qi;
      int sz = *qnw->qnw_serial ? box_length (*qnw->qnw_serial) : 0;
      src_stat_t * srs = (src_stat_t*) &inst[qn->src_stat];
      if (srs->srs_n_in)
	{
	  if (sz / sizeof (int64) < qnw->qnw_fill + 4)
	    array_extend ((caddr_t**)qnw->qnw_serial,  (qnw->qnw_fill + 40) * (sizeof (int64) / sizeof (caddr_t)));
	  ser = *qnw->qnw_serial;
	  ser[qnw->qnw_fill++] = qn->src_stat;
	  ser[qnw->qnw_fill++] = srs->srs_n_in;
	  ser[qnw->qnw_fill++] = srs->srs_n_out;
	  ser[qnw->qnw_fill++] = srs->srs_cum_time;
	  memzero (srs, sizeof (src_stat_t));
	}
    }
}



typedef void (*qnw_cb_t) (query_instance_t * qi, data_source_t * qn, qnw_cd_t * cd);


void
qn_walk (query_instance_t * qi, query_t * qr, qnw_cb_t cb, qnw_cd_t * cd)
{
  DO_SET (data_source_t *, qn, &qr->qr_nodes)
    {
      cb (qi, qn, cd);
      if (IS_QN (qn, query_frag_input))
	{
	  QNCAST (query_frag_t, qf, qn);
	  DO_SET (data_source_t *, qn2, &qf->qf_nodes)
	    cb (qi, qn2, cd);
	  END_DO_SET();
	}
      else if (IS_QN (qn, subq_node_input))
	{
	  qn_walk (qi, ((subq_source_t*)qn)->sqs_query, cb, cd);
	}
      else if (IS_QN (qn, trans_node_input))
	{
	  QNCAST (trans_node_t, tn, qn);
	  if (tn->tn_inlined_step)
	    qn_walk (qi, tn->tn_inlined_step, cb, cd);
	  if (tn->tn_complement)
	    qn_walk (qi, tn->tn_complement->tn_inlined_step, cb, cd);
	}
    }
  END_DO_SET();
  DO_SET (query_t *, sq, &qr->qr_subq_queries)
    qn_walk (qi, sq, cb, cd);
  END_DO_SET();
}



void
qi_branch_stats (query_instance_t * qi, query_instance_t * branch, query_t * qr)
{
  qnw_cd_t qnw;
  if (!qr->qr_head_node->src_stat)
    {
      data_source_t * qn = qr->qr_head_node;
      data_source_t * qn2 = qn;
      while (qn2 && (IS_QN (qn2, fun_ref_node_input) || IS_QN (qn2, hash_fill_node_input)))
	qn2 = ((fun_ref_node_t*)qn2)->fnr_select;
      if (qn2 && !qn2->src_stat)
	return;
    }
  qnw.qnw_qi_from = branch;
  qn_walk (qi,  qr, qnw_merge_cb, &qnw);
}

void
qnw_total_cb (query_instance_t * qi, data_source_t * qn, qnw_cd_t * qnw)
{
  if (IS_QN (qn, query_frag_input))
    return;
  if (qn->src_stat)
    {
      src_stat_t * srs = (src_stat_t*) &((caddr_t*)qi)[qn->src_stat];
      qnw->qnw_hash += srs->srs_cum_time;
    }
}


uint64
qi_total_rdtsc (query_instance_t * qi)
{
  qnw_cd_t qnw;
  if (!prof_on)
    return 0;
  qnw.qnw_hash = 0;
  qn_walk (qi, qi->qi_query, qnw_total_cb, &qnw);
  return qnw.qnw_hash;
}

uint64 qi_total_mem (QI * qi);

uint64
qi_array_mem (QI ** qis)
{
  uint64 mem = 0;
  int inx;
  DO_BOX (QI *, slice_qi, inx, qis)
    if (slice_qi)
      mem += qi_total_mem (slice_qi);
  END_DO_BOX;
  return mem;
}


int
qn_has_clb (data_source_t * qn)
{
  return IS_QN (qn, query_frag_input) || IS_QN (qn, stage_node_input) || IS_QN (qn, trans_node_input) || IS_QN (qn, cl_fref_read_input);
}

void
qnw_mem_cb (query_instance_t * qi, data_source_t * qn, qnw_cd_t * qnw)
{
  QNCAST (caddr_t, inst, qi);
  if (qn_has_clb (qn))
    {
      QNCAST (query_frag_t, qf, qn);
      if (qf->clb.clb_itcl)
	{
	  cl_op_t * itcl_clo = (cl_op_t*)qst_get (inst, qf->clb.clb_itcl);
	  if (itcl_clo)
	    {
	      itc_cluster_t * itcl = itcl_clo->_.itcl.itcl;
	      if (itcl && itcl->itcl_pool)
		qnw->qnw_hash += itcl->itcl_pool->mp_bytes;
	    }
	}
    }
  if (IS_QN (qn, query_frag_input))
    {
      QNCAST (query_frag_t, qf, qn);
      if (qf->qf_slice_qis)
	qnw->qnw_hash += qi_array_mem ((QI**)qst_get (inst, qf->qf_slice_qis));
    }
  else if (IS_QN (qn, stage_node_input) && 1 == ((stage_node_t*)qn)->stn_nth)
    {
      QNCAST (stage_node_t, stn, qn);
      qnw->qnw_hash += qi_array_mem ((QI**)qst_get (inst, stn->stn_slice_qis));
    }
}


uint64
qi_total_mem (query_instance_t * qi)
{
  qnw_cd_t qnw;
  qnw.qnw_hash = 0;
  qn_walk (qi, qi->qi_query, qnw_mem_cb, &qnw);
  return (qi->qi_mp ? qi->qi_mp->mp_bytes : 0) + qnw.qnw_hash;
}



void
qi_da_stat (query_instance_t * qi, db_activity_t * da, int is_final)
{
  qnw_cd_t qnw;
  if (!qi->qi_query->qr_head_node->src_stat)
    {
      da->da_nodes_fill = 0;
      return;
    }
  memzero (&qnw, sizeof (qnw));
  qnw.qnw_serial = &da->da_nodes;
  qn_walk (qi, qi->qi_query, qnw_serialize, &qnw);
  da->da_nodes_fill = qnw.qnw_fill;
  if (is_final)
    da->da_memory = qi->qi_mp->mp_bytes;
}


void
qi_add_cl_stat  (query_instance_t * qi, int64 * stat, int fill)
{
  caddr_t * inst = (caddr_t*) qi;
  int inx;
  qnw_cd_t qnw;
  memzero (&qnw, sizeof (qnw));
  qnw.qnw_serial = &stat;
  qnw.qnw_fill = fill;
  for (inx = 0; inx < fill; inx += 4)
    {
      int place = stat[inx];
      src_stat_t  * srs = (src_stat_t*)&inst[place];
      srs->srs_n_in += stat[inx + 1];
      srs->srs_n_out += stat[inx + 2];
      srs->srs_cum_time += stat[inx + 3];
    }
}

uint64
qr_plan_hash (query_t * qr)
{
  qnw_cd_t qnw;
  qnw.qnw_hash = 1;
  qn_walk (NULL, qr, qnw_hash, &qnw);
  return qnw.qnw_hash;
}


int64 ql_ctr;
dk_session_t * ql_file;
dk_mutex_t ql_mtx;
char * c_query_log_file = "virtuoso.qrl";
#define QL_N_COLS 43

void
qi_log_stats_1 (query_instance_t * qi, caddr_t err, caddr_t ext_text)
{
  caddr_t * inst = (caddr_t*)qi;
  du_thread_t * self = THREAD_CURRENT_THREAD;
  query_t * qr = qi->qi_query;
  char from[20];
  void * rs_comp = NULL;
  int r_len = 0;
  dk_set_t res = NULL;
#ifdef HAVE_GETRUSAGE
  struct rusage ru;
#endif
  client_connection_t * cli = qi->qi_client;
  dk_session_t * ses;
  uint64 rt;
  uint32 now;
  /* milos: allocate memory for the comment structure */
  qr_comment_t comm;

  memset(&comm, 0, sizeof(comm));
  /* comm.qrc_is_first = 0; */
  if (enable_qrc)
    SET_THR_ATTR (self, TA_STAT_COMM, (void*)&comm);
  if (!qi->qi_log_stats)
    return;

  now = get_msec_real_time ();
  CLI_THREAD_TIME (cli);
  rt = rdtsc ();
  if (!(ses = cli->cli_ql_strses))
    ses = cli->cli_ql_strses = strses_allocate ();
  dks_array_head (ses, QL_N_COLS, DV_ARRAY_OF_POINTER);
  session_buffered_write_char (DV_LONG_INT, ses);
  print_long (0, ses);
  /*0*/
  session_buffered_write_char (DV_DATETIME, ses);
  session_buffered_write (ses, (char*)cli->cli_start_dt, DT_LENGTH);
  /*1*/
  print_int (now - cli->cli_start_time, ses);
  /*2*/
  print_int (cli->cli_run_clocks, ses);
  /*3*/
  if (cli->cli_ws)
    tcpses_print_client_ip (cli->cli_ws->ws_session->dks_session, from, sizeof (from));
  else if (cli->cli_session && cli->cli_session->dks_session)
    tcpses_print_client_ip (cli->cli_session->dks_session, from, sizeof (from));
  else
    strcpy (from, "internal");
  session_buffered_write_char (DV_SHORT_STRING_SERIAL, ses);
  session_buffered_write_char (strlen (from), ses);
  session_buffered_write (ses, from, strlen (from));
  /*4*/
  if (cli->cli_user && cli->cli_user->usr_name)
    print_object (cli->cli_user->usr_name, ses, NULL, NULL);
  else
    session_buffered_write_char (DV_DB_NULL, ses);
  /*5, 6*/
  if (IS_BOX_POINTER (err))
    {
      print_object (((caddr_t*)err)[1], ses, NULL, NULL);
      print_object (((caddr_t*)err)[2], ses, NULL, NULL);
    }
  else
    {
      session_buffered_write_char (DV_DB_NULL, ses);
      session_buffered_write_char (DV_DB_NULL, ses);
    }
#ifdef HAVE_GETRUSAGE
  getrusage (RUSAGE_SELF, &ru);
  /*7*/
  print_int (ru.ru_majflt, ses);
  /*8*/
  print_int (ru.ru_utime.tv_sec * 1000 +  ru.ru_utime.tv_usec / 1000, ses);
  /*9*/
  print_int (ru.ru_stime.tv_sec * 1000 +  ru.ru_stime.tv_usec / 1000, ses);
#else
  print_int (0, ses);
  print_int (0, ses);
  print_int (0, ses);
#endif

  /*10*/
  if (ext_text)
    print_object (ext_text, ses, NULL, NULL);
  else if (qr->qr_text && !qr->qr_text_is_constant)
    print_object (qr->qr_text, ses, NULL, NULL);
  else
    session_buffered_write_char (DV_DB_NULL, ses);
  /*11*/
  session_buffered_write_char (DV_DB_NULL, ses);
  /*12*/
  if (ext_text)
    session_buffered_write_char (DV_DB_NULL, ses);
  else
    print_int (qr_plan_hash (qr), ses);
  /*13*/
  print_int (cli->cli_compile_activity.da_thread_time, ses);
  /*14*/
  /*15*/
  print_int (cli->cli_compile_msec, ses);
  cli->cli_compile_msec = 0;
  /*16*/
  print_int (cli->cli_compile_activity.da_disk_reads, ses);
  /*17*/
  print_int (cli->cli_compile_activity.da_thread_disk_wait, ses);
  /*18*/
  print_int (cli->cli_compile_activity.da_thread_cl_wait, ses);
  /*19*/
  print_int (cli->cli_compile_activity.da_cl_messages, ses);
  /*20*/
  print_int (cli->cli_compile_activity.da_random_rows, ses);
  /*21*/
  print_int (cli->cli_activity.da_random_rows, ses);
  /*22*/
  print_int (cli->cli_activity.da_seq_rows, ses);
  /*23*/
  print_int (cli->cli_activity.da_same_seg, ses);
  /*24*/
  print_int (cli->cli_activity.da_same_page, ses);
  /*25*/
  /*26*/
  print_int (cli->cli_activity.da_same_parent, ses);
  /*27*/
  print_int (cli->cli_activity.da_thread_time, ses);
  /*28*/
  print_int (cli->cli_activity.da_thread_disk_wait, ses);
  /*29*/
  print_int (cli->cli_activity.da_thread_cl_wait, ses);
  /*30*/
  print_int (cli->cli_activity.da_thread_pg_wait, ses);
  /*31*/
  print_int (cli->cli_activity.da_disk_reads, ses);
  /*32*/
  print_int (cli->cli_activity.da_spec_disk_reads, ses);
  /*33*/
  print_int (cli->cli_activity.da_cl_messages, ses);
  /*34*/
  print_int (cli->cli_activity.da_cl_bytes, ses);
  /*35*/
  print_int (cli->cli_activity.da_qp_thread, ses);
  /*36*/
  print_int (cli->cli_activity.da_memory, ses);
  /*37*/
  print_int (cli->cli_activity.da_max_memory, ses);
  /*38*/
  print_int (cli->cli_activity.da_lock_waits, ses);
  /*39*/
  print_int (cli->cli_activity.da_lock_wait_msec, ses);

  /*40*/
  if (!ext_text)
    {
      qr_comment_t * comm;
      cli->cli_resultset_max_rows = -1;
      cli->cli_resultset_comp_ptr = (caddr_t *) &rs_comp;
      cli->cli_resultset_data_ptr = &res;
      SET_THR_ATTR (self, TA_STAT_INST, (void*)qi);
      trset_start (inst);
      QR_RESET_CTX
	{
	  qr_print_top (qr);
	}
      QR_RESET_CODE
	{
	}
      END_QR_RESET;
      trset_end ();
      SET_THR_ATTR (self, TA_STAT_INST, NULL);
	  res = dk_set_nreverse (res);
	  /* milos: Get the list of warnings from the TA_STAT_COMM and print it */
      comm = THR_ATTR (self, TA_STAT_COMM);
      if(comm)
      {
      	dk_set_t msgs = comm->qrc_wrn_msgs;
      	msgs = dk_set_nreverse (msgs);
      	res = dk_set_conc (res, msgs);
      }      
      DO_SET (caddr_t *, r, &res)
	r_len += box_length (r[0]);
      END_DO_SET ();
      session_buffered_write_char (DV_STRING, ses);
      print_long  (r_len, ses);
      DO_SET (caddr_t *, r, &res)
	{
	  session_buffered_write (ses, r[0], box_length (r[0]) - 1);
	  session_buffered_write_char ('\n', ses);
	  dk_free_tree ((caddr_t)r);
	}
      END_DO_SET();
      dk_set_free (res);
      dk_free_tree (rs_comp);
      cli->cli_resultset_data_ptr = NULL;
      cli->cli_resultset_comp_ptr = NULL;
    }
  else
    session_buffered_write_char (DV_DB_NULL, ses);
  /*41*/
  session_buffered_write_char (DV_DB_NULL, ses);
  /*42*/
  print_int (cli->cli_compile_activity.da_memory, ses);
  /*43*/
  print_int (qi->qi_n_affected, ses);
mutex_enter (&ql_mtx);
  strses_set_int32 (ses, 4, ql_ctr++);
  if (!ql_file)
    {
      OFF_T off;
      int fd;
      file_set_rw (QL_NAME);
      fd = fd_open (c_query_log_file, LOG_OPEN_FLAGS);
      off = LSEEK (fd, 0, SEEK_END);
      ql_file = dk_session_allocate (SESCLASS_TCPIP);
      tcpses_set_fd (ql_file->dks_session, fd);
    }
  CATCH_WRITE_FAIL (ql_file)
  {
    strses_write_out (ses, ql_file);
    session_flush (ql_file);
  }
  END_WRITE_FAIL (ql_file);
  mutex_leave (&ql_mtx);
  strses_flush (ses);
  cli->cli_run_clocks = 0;
  da_clear (&cli->cli_activity);
  da_clear (&cli->cli_compile_activity);
  qi->qi_log_stats = 0;
}


void
qi_log_stats (query_instance_t * qi, caddr_t err)
{
  qi_log_stats_1 (qi, err, NULL);
}

caddr_t
bif_log_stats (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  QNCAST (QI, qi, qst);
  caddr_t ext_text;
  if (!prof_on)
    return NULL;
  ext_text = bif_string_arg (qst, args, 0, "log_stats");
  qi_log_stats_1 (qi, NULL, ext_text);
  cli_set_start_times (qi->qi_client);
  return NULL;
}


void
bif_explain_init (void)
{
  bif_define ("explain", bif_explain);
  bif_define ("procedure_cols", bif_procedure_cols);
  bif_define ("sql_parse", bif_sql_parse);
  bif_define ("sql_text", bif_sql_text);
  bif_define ("log_stats", bif_log_stats);
}



