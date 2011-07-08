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
 *  Copyright (C) 1998-2006 OpenLink Software
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

/* sqlprt.c */
void trset_start (caddr_t *qst);
void trset_printf (const char *str, ...);
void trset_end (void);


extern dk_mutex_t * prof_mtx;
extern id_hash_t * qn_prof;

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
  DO_SET (query_t *, sq, &qr->qr_subq_queries)
    sum += qr_qn_total (sq);
  END_DO_SET();
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
      dk_free_box (name);
      dk_free_box (pref);
      r = box_dv_short_string (local + 4);
      dk_free_box (local);
      return r;
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
	stmt_printf (("<r $%d %s via ", sslr->sslr_index, sslr->sslr_ssl && sslr->sslr_ssl->ssl_name ? sslr->sslr_ssl->ssl_name : ""));
	for (inx = 0; inx < sslr->sslr_distance; inx++)
	  stmt_printf ((" S%d", sslr->sslr_set_nos[inx]));
	stmt_printf ((">"));
	break;
      }
    case SSL_CONSTANT:
	{
	  dtp_t dtp = DV_TYPE_OF (ssl->ssl_constant);
	  caddr_t err_ret = NULL;
	  if (DV_TYPE_OF (ssl->ssl_constant) == DV_DB_NULL)
	    stmt_printf (("<DB_NULL>"));
	  else
	    {
	      dtp_t dtp = DV_TYPE_OF (ssl->ssl_constant);
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
  stmt_printf (("hash partition by %d ", hrng->hrng_min));
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
ks_print_vec_cast (key_source_t * ks)
{
  int first = 1, inx;
  DO_BOX (state_slot_t *, cast, inx, ks->ks_vec_cast)
    {
      if (cast)
	{
	  if (first)
	    {
	      stmt_printf (("vector param casts: "));
	    }
	  else
	    stmt_printf ((", "));
	  ssl_print ((state_slot_t*)ks->ks_vec_source[inx]);
	  stmt_printf (("-> "));
	  ssl_print (ks->ks_vec_cast[inx]);
	  first = 0;
	}
    }
  END_DO_BOX;
  if (!first)
    stmt_printf (("\n"));
}


static void
ks_print (key_source_t * ks)
{
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
    ks_print_vec_cast (ks);
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


int64 qr_total_rdtsc;

void
node_stat (data_source_t * qn)
{
  boxint sets = qn->src_sets;
  src_stat_t * srs;
  if (!qn->src_stat || !prof_on)
    return;
  srs = (src_stat_t*)id_hash_get (qn_prof, (caddr_t)&sets);
  if (!srs)
    return;
  stmt_printf (("time %9.2g%% fanout %9.2g\n",  (float)srs->srs_cum_time * 100 / (float)qr_total_rdtsc, srs->srs_n_in ? srs->srs_n_out / (float)srs->srs_n_in : 0.0));
}


static void
node_print_next (data_source_t * node)
{
  if (node->src_continuations)
    node_print ((data_source_t *) node->src_continuations->data);
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
      if (ts->ts_branch_ssls)
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
}


static void
node_print (data_source_t * node)
{
  qn_input_fn in;
  query_instance_t * qi = (query_instance_t *) THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_QST);
  if (!qi || qi->qi_trx->lt_threads != 1)
    GPF_T;
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
  if (node->src_pre_reset)
    {
      stmt_printf (("  clear: "));
      ssl_array_print (node->src_pre_reset);
      if (node->src_continue_reset)
	{
	  stmt_printf ((" clear on continue: "));
	  ssl_array_print (node->src_continue_reset);
	}
      stmt_printf (("\n"));
    }
  if (node->src_sets)
    stmt_printf (("s# %d ", node->src_sets));
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
      stmt_printf (("    \nsave ctx:"));
      ssl_array_print (qf->clb.clb_save);
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
      stmt_printf (("skip node  \n"));
    }
  else if (in == (qn_input_fn) sort_read_input)
    {
      stmt_printf (("top order by node  \n"));
    }
  else if (in == (qn_input_fn) chash_read_input)
    {
      QNCAST (table_source_t, ts, node);
      key_source_t * ks = ts->ts_order_ks;
      stmt_printf (("group by read node  \n"));
      ssl_array_print (ks->ks_from_setp->setp_keys_box);
      ssl_array_print (ks->ks_from_setp->setp_dependent_box);
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
      char hf[10];
      if (setp->setp_ha && HA_FILL == setp->setp_ha->ha_op)
	snprintf (hf, sizeof (hf), "hf %d", setp->setp_ha->ha_tree->ssl_index);
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
      node_print (fref->fnr_select);
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
	  ssl_list_print (rts->rts_out_slots);
	}
      if (rts->rts_after_join_test)
	{
	  stmt_printf (("\nAfter join test:\n"));
	  code_vec_print (rts->rts_after_join_test);
	}
      if (rts->rts_save_env)
	{
	  stmt_printf ((" save env: "));
	  ssl_array_print (rts->rts_save_env);
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
      stmt_printf (("Update %s %s ", upd->upd_keyset ? "keyset" : "", upd->upd_table->tb_name));
      ssl_print (upd->upd_place);
      ssl_array_print (upd->upd_values);
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
	      stmt_printf (("%s ", ik->ik_key->key_name));
	  END_DO_BOX;
	}
      stmt_printf (("\n"));
    }
  else if (in == (qn_input_fn) insert_node_input)
    {
      insert_node_t *ins = (insert_node_t *) node;
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
      if (hs->hs_ks)
	ks_print_vec_cast (hs->hs_ks);
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
	}
      else
	{
	  stmt_printf (("Transitive dt dir %d, input: ", tn->tn_direction));
	  ssl_array_print (tn->tn_input);
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
	if (txs->txs_xpath_text_exp)
	stmt_printf (("XCONTAINS ("));
      else
	stmt_printf (("CONTAINS ("));
      ssl_print (txs->txs_text_exp);
      stmt_printf ((") node on %s %9.2g rows\n", txs->txs_table->tb_name, txs->txs_card));
      ssl_print (txs->txs_d_id);
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
  query_instance_t * qi = (query_instance_t *) THR_ATTR (THREAD_CURRENT_THREAD, TA_REPORT_QST);
  if (!qi || qi->qi_trx->lt_threads != 1)
    GPF_T;
  QI_CHECK_STACK (qi, &qr, 10000);
  if (prof_on)
    qr_total_rdtsc = qr_qn_total (qr);
  else
    qr_total_rdtsc = 0;
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


caddr_t
sqlc_text_no_semi (caddr_t text)
{
  int l = strlen (text) - 1;
  while (l > 0 && (' ' ==  text[l] || '\n' == text[l] || '\r' == text[l]))
    l--;
  if (l && ';' == text[l])
    l--;
  return box_n_chars (text, l + 1);
}


static caddr_t
bif_explain (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_t * qr;
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t err = NULL;
  caddr_t text = bif_string_arg (qst, args, 0, "explain");
  int cr_type = SQLC_DO_NOT_STORE_PROC;
  int old_debug = -1;
  if (BOX_ELEMENTS (args) > 1)
    cr_type = (int) bif_long_arg (qst, args, 1, "explain");
  if (cr_type == SQLC_SQLO_VERBOSE)
    {
      cr_type = SQLC_DO_NOT_STORE_PROC;
      old_debug = sqlo_print_debug_output;
      sqlo_print_debug_output = 1;
    }
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
    qr_print (qr);
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


void
bif_explain_init (void)
{
  bif_define ("explain", bif_explain);
  bif_define ("procedure_cols", bif_procedure_cols);
  bif_define ("sql_parse", bif_sql_parse);
  bif_define ("sql_text", bif_sql_text);
}

