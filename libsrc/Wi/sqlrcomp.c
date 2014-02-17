/*
 *  sqlrcomp.c
 *
 *  $Id$
 *
 *  SQL Compiler, VDB remote database access
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

#include "libutil.h"
#include "sqlnode.h"
#include "odbcinc.h"
#include "eqlcomp.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "remote.h"
#include "sqlrcomp.h"
#include "sqlbif.h"
#include "security.h"
#include "sqlintrp.h"
#include "sqlo.h"
#include "sqlcstate.h"
#include "date.h"



/* the rds for which the stmt is being generated.
  use for ds specific info. Serialized by parse_mtx */



void
sqlc_target_rds (remote_ds_t * rds)
{
  SET_TARGET_RDS (rds);
  rds->rds_quote = rds_get_info (rds, SQL_IDENTIFIER_QUOTE_CHAR);
  rds->rds_dbms_name = rds_get_info (rds, SQL_DBMS_NAME);
  rds->rds_correlation_name = (int) (ptrlong) rds_get_info (rds, SQL_CORRELATION_NAME);
  if (!rds->rds_quote)
    rds->rds_quote = "\"";
  rds->rds_identifier_case = (short)unbox(rds_get_info (rds, SQL_IDENTIFIER_CASE));
}


void
sprintf_more (char *text, size_t len, int *fill, const char *string, ...)
{
  va_list list;
  char temp[2000];
  int ret, rest_sz, copybytes;
  va_start (list, string);
  ret = vsnprintf (temp, sizeof (temp), string, list);
#ifndef NDEBUG
  if (ret >= sizeof (temp))
    GPF_T1 ("overflow in temp");
#endif
  va_end (list);
#ifndef NDEBUG
  if (*fill + strlen (temp) > len - 1)
    GPF_T1 ("overflow in memcpy");
#endif
  rest_sz = (len - fill[0]);
  if (ret >= rest_sz)
    copybytes = ((rest_sz > 0) ? rest_sz : 0);
  else
    copybytes = ret+1;
  memcpy (text+fill[0], temp, copybytes);
  text[len - 1] = 0;
  fill[0] += ret;
}


void
tailprintf (char *text, size_t tlen, int *fill, const char *string, ...)	/* IvAn/AutoDTD/000919 Added */
{
  int len;
  va_list list;
  va_start (list, string);
  len = vsnprintf (text + fill[0], tlen - *fill, string, list);
  va_end (list);
#ifndef DEBUG
  if (len >= (int) (tlen - *fill))
    GPF_T1 ("overflow in tailprintf");
#endif
  if (len < 0)
    return;
  fill[0] += len;
}


void
sqlc_quote_dotted (char *text, size_t tlen, int *fill, char *name)
{
  sqlc_quote_dotted_quote (text, tlen, fill, name, SQL_QUOTE);
}


int
sqlc_is_proc_available (remote_ds_t * rds, char *p_name)
{
  if (rds->rds_dbms_name && (strstr (rds->rds_dbms_name, "Kubl") || strstr (rds->rds_dbms_name, "Virtuoso")))
    {
      bif_t bif = bif_find (p_name);
      if (bif && bif_is_relocatable (bif))
	return 1;
    }
  return 0;
}


void
sqlc_print_literal_proc (char *text, size_t tlen, int *fill, char *name, ST ** params, sql_comp_t * sc, comp_table_t * ct)
{
  bif_type_t *bt;
  state_slot_t **pargs = NULL;
  state_slot_t *args;
  int inx;
  if (0 == stricmp ("__copy", name))
    {
      /* __copy (x) is x on any remote. Calls introduced to compensate for bugs in constants or duplicate col refs in unions */
      sqlc_exp_print (sc, ct, params[0], text, tlen, fill);
      return;
    }

  bt = bif_type (name);
  if (bt)
    {
      args = (state_slot_t *) t_alloc (BOX_ELEMENTS (params) * sizeof (state_slot_t));
      pargs = (state_slot_t **) box_copy ((box_t) params);
      _DO_BOX (inx, pargs)
	{
	  pargs[inx] = &args[inx];
	}
      END_DO_BOX;
    }
  sprintf_more (text, tlen, fill, "{ %s ", name);
  sqlc_exp_commalist_print (sc, ct, params, text, tlen, fill, NULL, pargs);
  sprintf_more (text, tlen, fill, "}");

  if (NULL != bt && (bt->bt_dtp != DV_UNKNOWN || bt->bt_func))
    {
      state_slot_t ret;
      memset (&ret, 0, sizeof (state_slot_t));
      bif_type_set (bt, &ret, pargs);
      sc->sc_exp_sqt = ret.ssl_sqt;
    }
  else
    {
      query_t *qr = sch_proc_def (sc->sc_cc->cc_schema, name);
      if (!qr || IS_REMOTE_ROUTINE_QR (qr) || !qr->qr_proc_ret_type)
	return;
      else
	{
	  ptrlong *rtype = (ptrlong *) qr->qr_proc_ret_type;
	  if (rtype && ((dtp_t) rtype[0]) != DV_UNKNOWN)
	    {
	      sc->sc_exp_sqt.sqt_dtp = (dtp_t) rtype[0];
	      sc->sc_exp_sqt.sqt_precision = (uint32) rtype[1];
	      sc->sc_exp_sqt.sqt_col_dtp = 0;
	    }
	}
    }
}

int
sqlc_is_literal_proc (char *p_name)
{
  if (0 == stricmp (p_name, "ts") ||
      0 == stricmp (p_name, "d") ||
      0 == stricmp (p_name, "t") ||
      0 == stricmp (p_name, "__copy"))
    return 1;
  return 0;
}

char *
sqlc_sql_type_name (int sql_type)
{
  switch (sql_type)
    {
    default:
    case SQL_CHAR:
      return "SQL_CHAR";
    case SQL_VARCHAR:
      return "SQL_VARCHAR";
    case SQL_LONGVARCHAR:
      return "SQL_LONGVARCHAR";
    case SQL_WCHAR:
      return "SQL_WCHAR";
    case SQL_WVARCHAR:
      return "SQL_WVARCHAR";
    case SQL_WLONGVARCHAR:
      return "SQL_WLONGVARCHAR";
    case SQL_DECIMAL:
      return "SQL_DECIMAL";
    case SQL_NUMERIC:
      return "SQL_NUMERIC";
    case SQL_SMALLINT:
      return "SQL_SMALLINT";
    case SQL_INTEGER:
      return "SQL_INTEGER";
    case SQL_REAL:
      return "SQL_REAL";
    case SQL_FLOAT:
      return "SQL_FLOAT";
    case SQL_DOUBLE:
      return "SQL_DOUBLE";
    case SQL_BINARY:
      return "SQL_BINARY";
    case SQL_VARBINARY:
      return "SQL_VARBINARY";
    case SQL_LONGVARBINARY:
      return "SQL_LONGVARBINARY";
    case SQL_DATE:
      return "SQL_DATE";
    case SQL_TIME:
      return "SQL_TIME";
    case SQL_TIMESTAMP:
      return "SQL_TIMESTAMP";
    }
}


void
sqlc_print_standard_proc (char *text, size_t tlen, int *fill, char *name, ST ** params, sql_comp_t * sc, comp_table_t * ct)
{
  if (!strnicmp (name, "timestamp", 9))
    {				/* timestampadd & timestampdiff has first argument interpreted differently */
      int inx;
      sprintf_more (text, tlen, fill, "{fn %s (", name);
      DO_BOX (ST *, exp, inx, params)
	{
	  if (inx)
	    {
	      sprintf_more (text, tlen, fill, ", ");
	      sqlc_exp_print (sc, ct, exp, text, tlen, fill);
	    }
	  else
	    {
	      char *func = NULL;
	      switch (unbox ((box_t) exp))
		{
		case SQL_TSI_SECOND:
		  func = "SQL_TSI_SECOND";
		  break;

		case SQL_TSI_MINUTE:
		  func = "SQL_TSI_MINUTE";
		  break;

		case SQL_TSI_HOUR:
		  func = "SQL_TSI_HOUR";
		  break;

		case SQL_TSI_DAY:
		  func = "SQL_TSI_DAY";
		  break;

		case SQL_TSI_MONTH:
		  func = "SQL_TSI_MONTH";
		  break;

		case SQL_TSI_YEAR:
		  func = "SQL_TSI_YEAR";
		  break;
		}
	      sprintf_more (text, tlen, fill, "%s", func);
	    }
	}
      END_DO_BOX;
      sc->sc_exp_sqt.sqt_dtp = DV_DATETIME;
      sc->sc_exp_sqt.sqt_col_dtp = 0;
    }
  else if (!stricmp (name, "_cvt"))
    {				/* convert needs SQL_xxx instead of datatype xxx for second arg */
      dtp_t dtp = (dtp_t) ((ST *) (params[0]->_.op.arg_1))->type;

      sprintf_more (text, tlen, fill, "{fn convert (");
      sqlc_exp_print (sc, ct, params[1], text, tlen, fill);
      sprintf_more (text, tlen, fill, ", %s", sqlc_sql_type_name (vd_dv_to_sql_type (dtp)));
      sc->sc_exp_sqt.sqt_dtp = dtp;
      sc->sc_exp_sqt.sqt_col_dtp = 0;
    }
  else if (!stricmp (name, "__extract"))
    {				/* extract needs a special parameter layout */
      sprintf_more (text, tlen, fill, "{fn extract (");
      sqlc_exp_print (sc, ct, params[1], text, tlen, fill);
      sprintf_more (text, tlen, fill, " FROM ");
      sqlc_exp_print (sc, ct, params[2], text, tlen, fill);
      sc->sc_exp_sqt.sqt_dtp = DV_LONG_INT;
      sc->sc_exp_sqt.sqt_col_dtp = 0;
    }
  else if (!stricmp (name, "position"))
    {				/* extract needs a special parameter layout */
      sprintf_more (text, tlen, fill, "{fn position (");
      sqlc_exp_print (sc, ct, params[1], text, tlen, fill);
      sprintf_more (text, tlen, fill, " IN ");
      sqlc_exp_print (sc, ct, params[2], text, tlen, fill);
      sc->sc_exp_sqt.sqt_dtp = DV_LONG_INT;
      sc->sc_exp_sqt.sqt_col_dtp = 0;
    }
  else
    {
      bif_type_t *bt = bif_type (name);
      state_slot_t *args;
      state_slot_t **pargs = NULL;
      int inx;

      if (bt)
	{
	  args = (state_slot_t *) t_alloc (BOX_ELEMENTS (params) * sizeof (state_slot_t));
	  pargs = (state_slot_t **) t_box_copy ((caddr_t) params);
	  _DO_BOX (inx, pargs)
	    {
	      pargs[inx] = &args[inx];
	    }
	  END_DO_BOX;
	}
      sprintf_more (text, tlen, fill, "{fn %s (", name);
      sqlc_exp_commalist_print (sc, ct, params, text, tlen, fill, NULL, pargs);
      if (NULL != bt && (bt->bt_dtp != DV_UNKNOWN || bt->bt_func))
	{
	  state_slot_t ret;

	  memset (&ret, 0, sizeof (state_slot_t));
	  bif_type_set (bt, &ret, pargs);
	  sc->sc_exp_sqt = ret.ssl_sqt;
	}
      else
	{
	  query_t *qr = sch_proc_def (sc->sc_cc->cc_schema, name);
	  if (qr && !IS_REMOTE_ROUTINE_QR (qr) && qr->qr_proc_ret_type)
	    {
	      ptrlong *rtype = (ptrlong *) qr->qr_proc_ret_type;
	      if (((dtp_t) rtype[0]) != DV_UNKNOWN)
		{
		  sc->sc_exp_sqt.sqt_dtp = (dtp_t) rtype[0];
		  sc->sc_exp_sqt.sqt_col_dtp = 0;
		  sc->sc_exp_sqt.sqt_precision = (uint32) rtype[1];
		}
	    }
	}
    }
  sprintf_more (text, tlen, fill, ") }");
}


int
sqlc_is_standard_proc (remote_ds_t * rds, char *name, ST ** params)
{
  return 0;
}


int
sqlc_is_contains_proc (remote_ds_t * rds, char ct, ST ** params, comp_context_t * cc)
{
  return 0;
}


void
sqlc_print_masked_proc (char *text, size_t tlen, int *fill, char *name, ST ** params, sql_comp_t * sc, comp_table_t * ct, ptrlong exp_type)
{
  int inx;
  if (!stricmp (name, "one_of_these"))
    {
      DO_BOX (ST *, param, inx, params)
	{
	  if (inx - 1 > 0)
	    sprintf_more (text, tlen, fill, ", ");
	  sqlc_exp_print (sc, ct, param, text, tlen, fill);
	  if (!inx)
	    sprintf_more (text, tlen, fill, exp_type == BOP_EQ ? " NOT IN (" : " IN (");
	}
      END_DO_BOX;
      sprintf_more (text, tlen, fill, " ) ");
    }
  else if (!stricmp (name, "XMLATTRIBUTES") || !stricmp (name, "XMLFOREST"))
    {
      sprintf_more (text, tlen, fill, "%s (", name);

      for (inx = 0; inx < (long) ((params) ? BOX_ELEMENTS (params) : 0); inx += 2)
	{
	  if (inx > 0)
	    sprintf_more (text, tlen, fill, ", ");
	  sqlc_exp_print (sc, ct, params[inx + 1], text, tlen, fill);
	  sprintf_more (text, tlen, fill, " AS \"%s\"", params[inx]);
	}
      sprintf_more (text, tlen, fill, " ) ", name);
    }
  else if (!stricmp (name, "DB.DBA.XMLAGG"))
    {
      sprintf_more (text, tlen, fill, "XMLAGG (");
      if (params && BOX_ELEMENTS (params) > 0)
	sqlc_exp_commalist_print (sc, ct, params, text, tlen, fill, NULL, NULL);
      sprintf_more (text, tlen, fill, " ) ");
    }
  else
    SQL_GPF_T1 (sc->sc_cc, "Unknown function in sqlc_print_masked_proc");
}


int
sqlc_is_masked_proc (char *p_name)
{
  if (0 == stricmp (p_name, "one_of_these") ||
      0 == stricmp (p_name, "DB.DBA.XMLAGG") ||
      0 == stricmp (p_name, "XMLATTRIBUTES") ||
      0 == stricmp (p_name, "XMLFOREST"))
    return 1;
  return 0;
}


void
sqlc_print_remote_proc (char *text, size_t tlen, int *fill, char *name, ST ** params, sql_comp_t * sc, comp_table_t * ct)
{
}


int
sqlc_is_remote_proc (remote_ds_t * rds, char *p_name)
{
  return 0;
}


int
sqlc_is_pass_through_function (remote_ds_t * rds, char *p_name)
{
  return 0;
}


void
sqlc_print_pass_through_function (char *text, size_t tlen, int *fill, remote_ds_t * rds, char *name, ST ** params, sql_comp_t * sc, comp_table_t * ct)
{
}

remote_ds_t *
sqlc_table_remote_ds (sql_comp_t * sc, char *name)
{
  return NULL;
}



int
sqlc_is_local_array (sql_comp_t * sc, remote_ds_t * rds, ST ** exps, int only_eq_comps)
{
  return 0;
}









int
sqlc_is_local (sql_comp_t * sc, remote_ds_t * rds, ST * tree, int only_eq_comps)
{
  return 0;
}



const char *
ammsc_name (int c)
{
  switch (c)
    {
    case AMMSC_MIN:
      return ("MIN");
    case AMMSC_MAX:
      return ("MAX");
    case AMMSC_AVG:
      return ("AVG");
    case AMMSC_COUNT:
      return ("COUNT");
    case AMMSC_SUM:
    case AMMSC_COUNTSUM:
      return ("SUM");
    case AMMSC_USER:
      return ("AGGREGATE ");
    default:
      GPF_T1 ("Bad AMMSC No in sqlc_exp_print/sqlo_dfe_print");
    }
  return NULL;			/*dummy */
}


const char *
bop_text (int bop)
{
  switch (bop)
    {
    case BOP_NOT:
      return "not";
    case BOP_EQ:
      return "=";
    case BOP_GT:
      return ">";
    case BOP_LT:
      return "<";
    case BOP_GTE:
      return ">=";
    case BOP_LTE:
      return "<=";
    case BOP_NEQ:
      return "<>";
    case BOP_PLUS:
      return "+";
    case BOP_MINUS:
      return "-";
    case BOP_DIV:
      return "/";
    case BOP_TIMES:
      return "*";
    case BOP_AND:
      return "AND";
    case BOP_OR:
      return "OR";
    case UNION_ST:
      return (" UNION ");
    case UNION_ALL_ST:
      return (" UNION ALL ");
    case BOP_LIKE:
      return (" LIKE ");
    case BOP_NULL:
      return (" IS NULL ");
    }
  SQL_GPF_T (top_sc->sc_cc);
  return "";
}


int
bop_weight (int bop)
{
  switch (bop)
    {
    case BOP_TIMES:
      return 6;
    case BOP_DIV:
      return 7;
    case BOP_PLUS:
      return 5;
    case BOP_MINUS:
      return 5;
    case BOP_EQ:
      return 4;
    case BOP_NEQ:
      return 4;
    case BOP_GT:
      return 4;
    case BOP_LT:
      return 4;
    case BOP_GTE:
      return 4;
    case BOP_LTE:
      return 4;
    case BOP_LIKE:
      return 4;
    case BOP_AND:
      return 3;
    case BOP_OR:
      return 2;
    case UNION_ST:
      return 1;
    case UNION_ALL_ST:
      return 1;
    }
  GPF_T;
  return 0;
}


int
sc_is_remote_rts_sc (sql_comp_t * sc)
{
  query_t *qr = sc->sc_cc->cc_query;
  if (!qr)
    return 1;
  if (!qr->qr_head_node)
    return 0;			/* half done ain't rts query */
  if (qr->qr_head_node->src_input == (qn_input_fn) remote_table_source_input)
    return 1;
  else
    return 0;
}


int
col_ref_is_local (sql_comp_t * sc, comp_table_t * ct, col_ref_rec_t * cr)
{
  if (!ct)
    {
      /* if the corresponding sc is made in sqlc_subquery_text */
      if (cr->crr_is_as_alias)
	return 1;
      if (cr->crr_ct && sc_is_remote_rts_sc (cr->crr_ct->ct_sc))
	return 1;
      if (cr->crr_ct && cr->crr_ct == sc->sc_super_ct)
	return 1;
      return 0;
    }
  if (cr->crr_ct == ct || dk_set_member (ct->ct_fused_cts, (void *) cr->crr_ct))
    return 1;
  return 0;
}





char *
tb_remote_name (dbe_table_t * tb)
{
  remote_table_t *rt = find_remote_table (tb->tb_name, 0);
  if (!rt)
    return ("\"No remote table\"");
  else
    return (rt->rt_remote_name);
}


void
sqlc_order_by_print (sql_comp_t * sc, char *title, ST ** orderby, char *text, size_t tlen, int *fill, caddr_t * box, dk_set_t set)
{
  int inx, first = 1;
  sprintf_more (text, tlen, fill, " %s ", title);
  DO_BOX (ST *, spec, inx, orderby)
    {
      ST *exp = spec->_.o_spec.col;
      if (!first)
	sprintf_more (text, tlen, fill, ", ");
      else
	first = 0;

      if (box)
	{
	  int inx1;
	  DO_BOX (ST *, sel, inx1, box)
	    {
	      if (box_equal ((box_t) sel, (box_t) exp))
		{
		  sprintf_more (text, tlen, fill, " %d ", inx1 + 1);
		  goto column_done;
		}
	    }
	  END_DO_BOX;
	}
      else if (set)
	{
	  int inx1 = 0;
	  DO_SET (ST *, sel, &set)
	    {
	      if (box_equal ((box_t) sel, (box_t) exp))
		{
		  sprintf_more (text, tlen, fill, " %d ", inx1 + 1);
		  goto column_done;
		}
	      inx1 += 1;
	    }
	  END_DO_SET ();
	}

      while (ST_P (exp, BOP_AS))
	exp = exp->_.as_exp.left;
      sqlc_exp_print (sc, NULL, exp, text, tlen, fill);
    column_done:
      if (spec->_.o_spec.order == ORDER_DESC)
	sprintf_more (text, tlen, fill, " DESC");
    }
  END_DO_BOX;
}


void
dk_set_append_1 (dk_set_t * res, void *item)
{
  *res = NCONC (*res, CONS (item, NULL));
}



void
sqlc_string_virtuoso_literal (char *text, size_t tlen, int *fill, const char *exp)
{
  int inx, len = box_length (exp) - 1;
  sprintf_more (text, tlen, fill, "\'");
  for (inx = 0; inx < len; inx++)
    {
      unsigned char c = exp[inx];
      if (c == '\'')
	sprintf_more (text, tlen, fill, "\\\'");
      else if (c == '\\')
	sprintf_more (text, tlen, fill, "\\\\");
      else if (c < (unsigned)' ')
        {
          char buf[5];
          buf[0] = '\\';
          buf[1] = '0';
          buf[2] = '0' | (c >> 3);
          buf[3] = '0' | (c & 0x7);
          buf[4] = '\0';
	  sprintf_more (text, tlen, fill, buf);
        }
      else
	sprintf_more (text, tlen, fill, "%c", c);
    }
  sprintf_more (text, tlen, fill, "\' ");
}


void
sqlc_string_literal (char *text, size_t tlen, int *fill, const char *exp)
{
  int inx, len = box_length (exp) - 1;
  sprintf_more (text, tlen, fill, "\'");
  for (inx = 0; inx < len; inx++)
    {
      char c = exp[inx];
      if (c == '\'')
	sprintf_more (text, tlen, fill, "\'\'");
      else
	sprintf_more (text, tlen, fill, "%c", c);
    }
  sprintf_more (text, tlen, fill, "\' ");
}


void
sqlc_wide_string_literal (char *text, size_t tlen, int *fill, wchar_t * exp)
{
  int inx, len = (box_length (exp) / sizeof (wchar_t)) - 1;
  sprintf_more (text, tlen, fill, "\'");
  for (inx = 0; inx < len; inx++)
    {
      wchar_t c = exp[inx];
      if (c == '\'')
	sprintf_more (text, tlen, fill, "\'\'");
      else if (c & ~0x7F)
	sprintf_more (text, tlen, fill, "\\x%04x", (unsigned int) c);
      else
	sprintf_more (text, tlen, fill, "%c", c);
    }
  sprintf_more (text, tlen, fill, "\' ");
}


char *
sqlc_ct_vdb_prefix (sql_comp_t * sc, comp_table_t * ct)
{
  char tmp[20];
  if (!ct)
    return NULL;
  if (ct->ct_is_vdb_dml)
    return NULL;
  if (ct->ct_prefix)
    return (ct->ct_prefix);
  if (ct->ct_vdb_prefix)
    return (ct->ct_vdb_prefix);
  if (target_rds->rds_correlation_name != SQL_CN_ANY)
    return NULL;
  snprintf (tmp, sizeof (tmp), "C__%d", sc->sc_last_cn_no++);
  ct->ct_vdb_prefix = t_box_string (tmp);
  return (ct->ct_vdb_prefix);
}


comp_table_t *
sqlc_table_ct (sql_comp_t * sc, dbe_table_t * tb, ST * tree)
{
  int inx;
  DO_BOX (comp_table_t *, ct, inx, sc->sc_tables)
    {
      if (ct->ct_table == tb)
	{
	  if (ct->ct_prefix && tree->_.table.prefix && 0 == strcmp (ct->ct_prefix, tree->_.table.prefix))
	    return ct;
	  if (!ct->ct_prefix && !tree->_.table.prefix)
	    return ct;
	}
    }
  END_DO_BOX;
  sqlc_new_error (sc->sc_cc, "42000", "VD026", "Inconsistent vdb subquery compilation");
  return NULL;			/* keep cc happy */
}


void
sqlc_remote_bop_params (sql_type_t * lsqt, state_slot_t * lpar, sql_type_t * rsqt, state_slot_t * rpar)
{
  if (lpar && lpar->ssl_dtp == DV_UNKNOWN)
    lpar->ssl_sqt = *rsqt;
  else if (rpar && rpar->ssl_dtp == DV_UNKNOWN)
    rpar->ssl_sqt = *lsqt;
}


void
sqlc_remote_assign_param_type (sql_comp_t * sc, char *tb_name, char *col_name)
{
  if (sc->sc_exp_param && sc->sc_exp_param->ssl_dtp == DV_UNKNOWN)
    {
      dbe_table_t *tb = sch_name_to_table (sc->sc_cc->cc_schema, tb_name);
      dbe_column_t *col = tb_name_to_column (tb, col_name);
      sc->sc_exp_param->ssl_sqt = col->col_sqt;
    }
}




void
sqlc_insert_commalist (sql_comp_t * sc, comp_table_t * ct, ST * tree, dbe_table_t * tb, char *text, size_t tlen, int *fill, int in_vdb)
{
  int first = 1, inx;
  remote_table_t *rtable = NULL;

  if (tree->_.insert.cols && BOX_ELEMENTS (tree->_.insert.vals->_.ins_vals.vals) != BOX_ELEMENTS (tree->_.insert.cols))
    sqlc_new_error (sc->sc_cc, "21S01", "SQ144", "different number of cols and values in insert.");

  if (in_vdb && tb)
    {
      rtable = find_remote_table (tb->tb_name, 0);
    }
  DO_BOX (ST *, exp, inx, tree->_.insert.vals->_.ins_vals.vals)
    {
      dbe_column_t *col = tb_name_to_column (tb, (char *) tree->_.insert.cols[inx]);

      if (!first)
	sprintf_more (text, tlen, fill, ", ");
      else
	first = 0;


      sqlc_exp_print (sc, ct, exp, text, tlen, fill);


      if (sc->sc_exp_param && DV_UNKNOWN == sc->sc_exp_param->ssl_type)
	{
	  sc->sc_exp_param->ssl_sqt = *sqlc_stmt_nth_col_type (sc, tb, tree, inx);
	}
    }
  END_DO_BOX;
}


static void
sqlc_exp_print_overflow (sql_comp_t * sc)
{
  if (sc && sc->sc_cc)
    sqlc_new_error (sc->sc_cc, "HY090", "VD027", "Remote statement text over 19K");
  else
    sqlr_new_error ("HY090", "VD028", "Remote statement text over 19K");
}


void
sqlc_bop_exp_print (sql_comp_t * sc, comp_table_t * ct, ST * exp, char *text, size_t tlen, int *fill, int curr_weight)
{
  ST *tree = exp;

  dtp_t dtp = DV_TYPE_OF (exp);
  SQLT_UNKNOWN (sc);
  sc->sc_exp_param = NULL;
  if (*fill > MAX_REMOTE_TEXT_SZ - 500)
    sqlc_exp_print_overflow (sc);
  if (sc->sc_exp_print_hook && sc->sc_exp_print_hook (sc, ct, exp, text, tlen, fill))
    return;

  switch (dtp)
    {
    case DV_LIST_OF_POINTER:
    case DV_ARRAY_OF_POINTER:
      switch (exp->type)
	{
	case BOP_EQ:
	case BOP_NEQ:
	case BOP_GT:
	case BOP_LT:
	case BOP_GTE:
	case BOP_LTE:
	case BOP_PLUS:
	case BOP_MINUS:
	case BOP_DIV:
	case BOP_TIMES:
	case BOP_AND:
	case BOP_OR:
	case UNION_ST:
	case UNION_ALL_ST:
	case BOP_LIKE:
	  {
	    sql_type_t sqt1;
	    state_slot_t *par1;
	    ST *call = NULL;
	    int op_weight = bop_weight ((int) exp->type);

	    if (ST_P (tree->_.bin_exp.left, CALL_STMT) && sqlc_is_masked_proc (tree->_.bin_exp.left->_.call.name))
	      call = tree->_.bin_exp.left;
	    else if (ST_P (tree->_.bin_exp.right, CALL_STMT) && sqlc_is_masked_proc (tree->_.bin_exp.right->_.call.name))
	      call = tree->_.bin_exp.right;

	    if (call)
	      {
		sqlc_print_masked_proc (text, tlen, fill, call->_.call.name, call->_.call.params, sc, ct, exp->type);
		break;
	      }

	    if (exp->type == BOP_MINUS && DV_TYPE_OF (tree->_.bin_exp.left) == DV_LONG_INT &&
		unbox ((box_t) tree->_.bin_exp.left) == 0)
	      {			/* handle the case of (0 - x) - do it as (-x) */
		op_weight = 10;
		if (op_weight < curr_weight)
		  sprintf_more (text, tlen, fill, "(");
		sprintf_more (text, tlen, fill, " -");
		sqlc_bop_exp_print (sc, ct, exp->_.bin_exp.right, text, tlen, fill, op_weight);
		if (op_weight < curr_weight)
		  sprintf_more (text, tlen, fill, " ) ");
		break;
	      }
	    if (op_weight < curr_weight)
	      sprintf_more (text, tlen, fill, "(");
	    sqlc_bop_exp_print (sc, ct, exp->_.bin_exp.left, text, tlen, fill, op_weight);
	    sqt1 = sc->sc_exp_sqt;
	    par1 = sc->sc_exp_param;
	    sprintf_more (text, tlen, fill, " %s ", bop_text ((int) exp->type));
	    if ((exp->type == BOP_MINUS || (exp->type == BOP_NOT)) && BIN_EXP_P (exp->_.bin_exp.right))
	      sprintf_more (text, tlen, fill, "(");
	    sqlc_bop_exp_print (sc, ct, exp->_.bin_exp.right, text, tlen, fill, op_weight);
	    if (exp->type == BOP_LIKE && exp->_.bin_exp.more)
	      {
		sprintf_more (text, tlen, fill, " ESCAPE ");
		sqlc_bop_exp_print (sc, ct, (ST *) exp->_.bin_exp.more, text, tlen, fill, op_weight);
	      }
	    if ((exp->type == BOP_MINUS || (exp->type == BOP_NOT)) && BIN_EXP_P (exp->_.bin_exp.right))
	      sprintf_more (text, tlen, fill, ")");

	    if (op_weight < curr_weight)
	      sprintf_more (text, tlen, fill, ")");
	    sqlc_remote_bop_params (&sqt1, par1, &sc->sc_exp_sqt, sc->sc_exp_param);
	  }
	  break;
	default:
	  sqlc_exp_print (sc, ct, exp, text, tlen, fill);
	}
      break;
    default:
      sqlc_exp_print (sc, ct, exp, text, tlen, fill);
    }
}


int
sqlc_print_count_exp (sql_comp_t * sc, comp_table_t * ct, ST * exp, char *text, size_t tlen, int *fill)
{
  ST *tree = exp;
  ST *arg_st;

  if (AMMSC_COUNTSUM == tree->_.fn_ref.fn_code)
    {
      arg_st = tree->_.fn_ref.fn_arg;
      if (ST_P (arg_st, SEARCHED_CASE))
	{
	  if ((4 == BOX_ELEMENTS (arg_st->_.comma_exp.exps)) &&
	      ST_P (arg_st->_.comma_exp.exps[0], BOP_NULL) &&
	      ST_P (arg_st->_.comma_exp.exps[2], QUOTE) &&
	      (0 == unbox ((box_t) arg_st->_.comma_exp.exps[1])) && (1 == unbox ((box_t) arg_st->_.comma_exp.exps[3])))
	    {
	      sprintf_more (text, tlen, fill, "%s (%s ", ammsc_name (AMMSC_COUNT), tree->_.fn_ref.all_distinct ? "distinct" : "");

	      sqlc_exp_print (sc, ct, arg_st->_.comma_exp.exps[0]->_.bin_exp.left, text, tlen, fill);
	      sprintf_more (text, tlen, fill, ")");
	      sc->sc_exp_sqt.sqt_dtp = DV_LONG_INT;
	      sc->sc_exp_sqt.sqt_col_dtp = 0;
	      return 1;
	    }
	}
      else
	{
	  sprintf_more (text, tlen, fill, "%s (%s ", ammsc_name (AMMSC_COUNT), tree->_.fn_ref.all_distinct ? "distinct" : "");
	  if (sc->sc_so && DV_TYPE_OF (arg_st) == DV_LONG_INT)
	    {
	      if (!unbox ((box_t) arg_st))
		sprintf_more (text, tlen, fill, "NULL");
	      else
		sprintf_more (text, tlen, fill, "*");
	    }
	  else
	    sqlc_exp_print (sc, ct, arg_st, text, tlen, fill);
	  sprintf_more (text, tlen, fill, ")");
	  sc->sc_exp_sqt.sqt_dtp = DV_LONG_INT;
	  sc->sc_exp_sqt.sqt_col_dtp = 0;
	  return 1;
	}
    }
  return 0;
}


#ifndef MAP_DIRECT_BIN_CHAR
void
sqlc_bin_dv_print (ST * it, char *text, size_t tlen, int *fill)
{
  unsigned char *ptr = (unsigned char *) it;

  if (*fill < (int) (tlen - box_length (it) * 2))
    {
      for (ptr = (unsigned char *) it; (uint32) (ptr - ((unsigned char *) it)) < box_length (it); ptr++, *fill += 2)
	{
	  text[*fill] = ((*ptr & 0xF0) >> 4) + ((((*ptr & 0xF0) >> 4) < 10) ? '0' : 'A' - 10);
	  text[*fill + 1] = (*ptr & 0x0F) + (((*ptr & 0x0F) < 10) ? '0' : 'A' - 10);
	}
    }
#ifndef NDEBUG
  else
    GPF_T1 ("overflow in sqlc_bin_dv_print");
#endif
}
#endif


void
sqlc_dt_corr_name (char *text, size_t tlen, int *fill, char *prefix)
{
  /* when a view is inlined as a dt it will have the qualified name of the view as corr name. Quote and replace the dots with _ */
  int inx;
  caddr_t copy = box_string (prefix);
  for (inx = 0; copy[inx]; inx++)
    if (copy[inx] == '.')
      copy[inx] = '_';
  sqlc_quote_dotted (text, tlen, fill, copy);
  dk_free_box (copy);
}


void
sqlc_dt_col_ref (sql_comp_t * sc, comp_table_t * ct, ST * exp, char *text, size_t tlen, int *fill)
{
  sqlc_dt_corr_name (text, tlen, fill, ct->ct_prefix);
  sprintf_more (text, tlen, fill, ".");
  sqlc_quote_dotted (text, tlen, fill, exp->_.col_ref.name);
}


#define sc_pass_through_rts_node(sc) (GPF_T, NULL)


void
sqlc_exp_print (sql_comp_t * sc, comp_table_t * ct, ST * exp, char *text, size_t tlen, int *fill)
{
  ST *tree = exp;

  dtp_t dtp = DV_TYPE_OF (exp);
  SQLT_UNKNOWN (sc);
  sc->sc_exp_param = NULL;
  if ((unsigned) *fill > MAX_REMOTE_TEXT_SZ - 500)
    sqlc_exp_print_overflow (sc);
  if (sc->sc_exp_print_hook && sc->sc_exp_print_hook (sc, ct, exp, text, tlen, fill))
    return;

  switch (dtp)
    {
    case DV_LONG_INT:
      sprintf_more (text, tlen, fill, BOXINT_FMT, unbox ((caddr_t) exp));
      sc->sc_exp_sqt.sqt_dtp = dtp;
      break;

    case DV_DB_NULL:
      sprintf_more (text, tlen, fill, "NULL");
      break;
    case DV_STRING:
      if (*fill + box_length (exp) > MAX_REMOTE_TEXT_SZ - 500)
	sqlc_exp_print_overflow (sc);
      sqlc_string_literal (text, tlen, fill, (char *) exp);
      sc->sc_exp_sqt.sqt_dtp = dtp;
      break;

    case DV_UNAME:
      {
	caddr_t bin_uname_prefix = "UNAME" /* rds_get_info (target_rds, ???) */ ;
	if (bin_uname_prefix)
	  sprintf_more (text, tlen, fill, "%s", bin_uname_prefix);
	if (*fill + box_length (exp) > MAX_REMOTE_TEXT_SZ - 500)
	  sqlc_exp_print_overflow (sc);
	sqlc_string_literal (text, tlen, fill, (char *) exp);
	sc->sc_exp_sqt.sqt_dtp = dtp;
	break;
      }

    case DV_WIDE:
      {
	break;
      }

    case DV_DOUBLE_FLOAT:
      sprintf_more (text, tlen, fill, "%lg", unbox_double ((caddr_t) exp));
      sc->sc_exp_sqt.sqt_dtp = dtp;
      break;

    case DV_NUMERIC:
      numeric_to_string ((numeric_t) exp, text + *fill, tlen - *fill);
      *fill += (int) strlen (text + *fill);
      sprintf_more (text, tlen, fill, " ");
      sc->sc_exp_sqt.sqt_dtp = dtp;
      break;

    case DV_SYMBOL:
      {
	break;
      }

#ifndef MAP_DIRECT_BIN_CHAR
    case DV_BIN:
      {
	caddr_t bin_literal_prefix = rds_get_info (target_rds, -4);
	caddr_t bin_literal_suffix = rds_get_info (target_rds, -5);
	if (bin_literal_prefix)
	  sprintf_more (text, tlen, fill, "%s", bin_literal_prefix);
	sqlc_bin_dv_print (exp, text, tlen, fill);
	if (bin_literal_suffix)
	  sprintf_more (text, tlen, fill, "%s", bin_literal_suffix);
	sc->sc_exp_sqt.sqt_dtp = dtp;
      }
      break;
#endif
    case DV_DATETIME:
    case DV_DATE:
    case DV_TIME:
	{
	  char temp[100];
	  int dt_type = DT_DT_TYPE (exp);
	  dt_to_string ((char *) exp, temp, sizeof (temp));
	  sprintf_more (text, tlen, fill, "{%s '%s'}", dt_type == DT_TYPE_DATE ? "d" : dt_type == DT_TYPE_TIME ? "t" : "ts",  temp);
	  break;
	}

    case DV_LIST_OF_POINTER:
    case DV_ARRAY_OF_POINTER:
      switch (exp->type)
	{
	case BOP_EQ:
	case BOP_NEQ:
	case BOP_GT:
	case BOP_LT:
	case BOP_GTE:
	case BOP_LTE:
	case BOP_PLUS:
	case BOP_MINUS:
	case BOP_DIV:
	case BOP_TIMES:
	case BOP_AND:
	case BOP_OR:
	case UNION_ST:
	case UNION_ALL_ST:
	case BOP_LIKE:
	  sqlc_bop_exp_print (sc, ct, exp, text, tlen, fill, 0);
	  break;

	case BOP_NOT:
	  sprintf_more (text, tlen, fill, "NOT (");
	  sqlc_exp_print (sc, ct, exp->_.bin_exp.left, text, tlen, fill);
	  sprintf_more (text, tlen, fill, " )");
	  break;

	case BOP_NULL:
	  sqlc_exp_print (sc, ct, tree->_.bin_exp.left, text, tlen, fill);
	  sprintf_more (text, tlen, fill, " IS NULL");
	  break;

	case BOP_AS:
	  {
	    caddr_t col_alias = rds_get_info (target_rds, SQL_COLUMN_ALIAS);
	    sqlc_exp_print (sc, ct, tree->_.as_exp.left, text, tlen, fill);
	    if (ST_P (tree->_.as_exp.left, COL_DOTTED) && !tree->_.as_exp.left->_.col_ref.prefix &&
		!CASEMODESTRCMP (tree->_.as_exp.left->_.col_ref.name, tree->_.as_exp.name))
	      break;
	    if (DV_STRINGP (col_alias) && box_length (col_alias) > 1 && toupper (col_alias[0]) == 'Y')
	      {
		sprintf_more (text, tlen, fill, " AS ");
		sqlc_quote_dotted (text, tlen, fill, tree->_.as_exp.name);
	      }
	    break;
	  }

	case SEARCHED_CASE:
	  {
	    int inx;
	    sprintf_more (text, tlen, fill, "CASE ");
	    for (inx = 0; ((uint32) inx) < BOX_ELEMENTS (tree->_.comma_exp.exps); inx += 2)
	      {
		if (ST_P (tree->_.comma_exp.exps[inx], QUOTE))
		  {
		    sprintf_more (text, tlen, fill, " ELSE ");
		    sqlc_exp_print (sc, ct, tree->_.comma_exp.exps[inx + 1], text, tlen, fill);
		  }
		else
		  {
		    sprintf_more (text, tlen, fill, " WHEN ");
		    sqlc_exp_print (sc, ct, tree->_.comma_exp.exps[inx], text, tlen, fill);
		    sprintf_more (text, tlen, fill, " THEN ");
		    sqlc_exp_print (sc, ct, tree->_.comma_exp.exps[inx + 1], text, tlen, fill);
		  }
	      }
	    sprintf_more (text, tlen, fill, " END ");
	  }

	  break;
	case FUN_REF:
	  {
	    if (sqlc_print_count_exp (sc, ct, exp, text, tlen, fill))
	      break;
	    if (AMMSC_USER == tree->_.fn_ref.fn_code)
	      {
		int argctr;
		user_aggregate_t *ua = (user_aggregate_t *) unbox_ptrlong (tree->_.fn_ref.user_aggr_addr);
		sprintf_more (text, tlen, fill, "AGGREGATE %s (", ua->ua_name);
		DO_BOX_FAST (ST *, arg, argctr, tree->_.fn_ref.fn_arglist)
		  {
		    if (argctr > 0)
		      sprintf_more (text, tlen, fill, ", ");
		    sqlc_exp_print (sc, ct, arg, text, tlen, fill);
		  }
		END_DO_BOX_FAST;
	      }
	    else
	      {
		sprintf_more (text, tlen, fill, "%s (%s ", ammsc_name ((int) tree->_.fn_ref.fn_code), tree->_.fn_ref.all_distinct ? "distinct" : "");
		if (tree->_.fn_ref.fn_arg)
		  sqlc_exp_print (sc, ct, tree->_.fn_ref.fn_arg, text, tlen, fill);
		else
		  sprintf_more (text, tlen, fill, "*");
		sprintf_more (text, tlen, fill, ") ");
		if (tree->_.fn_ref.fn_code == AMMSC_COUNT)
		  sc->sc_exp_sqt.sqt_dtp = DV_LONG_INT;
	      }
	    break;
	  }
	case COL_DOTTED:
	  {
	    col_ref_rec_t *crr = NULL;
	    if (sc->sc_super && sc->sc_super->sc_derived_opt)
	      {
		ST *texp = sc->sc_super->sc_derived_opt->_.select_stmt.table_exp;
		ST *derived_table = texp->_.table_exp.from[0];
		ST *der_select = derived_table->_.table_ref.table;
		int inx;
		if (!exp->_.col_ref.prefix || !CASEMODESTRCMP (exp->_.col_ref.prefix, derived_table->_.table_ref.range))
		  {
		    DO_BOX (ST *, sel, inx, der_select->_.select_stmt.selection)
		      {
			if (ST_P (sel, BOP_AS) && !CASEMODESTRCMP (exp->_.col_ref.name, sel->_.as_exp.name))
			  {
			    crr = sqlc_col_or_param (sc, sel->_.as_exp.left, 0);
			  }
		      }
		    END_DO_BOX;
		  }
		if (!crr)
		  crr = sqlc_col_or_param (sc, exp, 0);
	      }
	    else
	      crr = sqlc_col_or_param (sc, exp, 0);
	    if (col_ref_is_local (sc, ct, crr))
	      {
		char *c_prefix;

		if (crr && crr->crr_ct && crr->crr_ct->ct_derived)
		  {
		    /* a ref to a col of a derived table is always with the dt's correlation name */
		    sqlc_dt_col_ref (sc, crr->crr_ct, exp, text, tlen, fill);
		    return;
		  }
		/* if prefix is table name, use remote tb name.
		 * If not table name, use org prefix */
		if (exp->_.col_ref.prefix)
		  {
		    c_prefix = sqlc_ct_vdb_prefix (sc, crr->crr_ct);
		    if (c_prefix)
		      {
			sqlc_quote_dotted (text, tlen, fill, c_prefix);
			sprintf_more (text, tlen, fill, ".");
		      }
		    else
		      {
			dbe_table_t *tb = crr->crr_ct->ct_table;
			if (!tb)
			  sqlc_new_error (sc->sc_cc, "42S02", "VD029", "Cannot generate remote ref to col w/ no table %s", exp->_.col_ref.name);
			sqlc_quote_dotted (text, tlen, fill, tb_remote_name (tb));
			sprintf_more (text, tlen, fill, ".");
		      }
		  }
		if (crr->crr_dbe_col)
		  {
		    if ((dbe_column_t *) CI_ROW == crr->crr_dbe_col)
		      sqlc_new_error (sc->sc_cc, "37000", "VD030", "The _ROW virtual column cannot be referenced for remote tables.");
		    sqlc_quote_dotted (text, tlen, fill, crr->crr_dbe_col->col_name);
		  }
		else
		  sqlc_quote_dotted (text, tlen, fill, exp->_.col_ref.name);
		if (crr->crr_dbe_col)
		  {
		    SQLT_COL (sc, crr->crr_dbe_col);
		  }
	      }
	    else
	      {
		remote_table_source_t *rts = ct ? ct->ct_rts : sc_pass_through_rts_node (sc);
		dk_set_append_1 (&rts->rts_params, (void *) sqlc_col_ref_rec_ssl (sc, crr));
		sprintf_more (text, tlen, fill, "?");
	      }
	  }
	  break;

	case SELECT_STMT:
	  if (!tree->_.select_stmt.table_exp)
	    {
	      sprintf_more (text, tlen, fill, "SELECT (");
	      sqlc_exp_commalist_print (sc, ct, (ST **) tree->_.select_stmt.selection, text, tlen, fill, NULL, NULL);
	      sprintf_more (text, tlen, fill, ")");
	      break;
	    }
	  sqlc_subquery_text (sc, ct, tree, text, tlen, fill, NULL);
	  break;

	case TABLE_REF:
	  sqlc_exp_print (sc, ct, tree->_.table_ref.table, text, tlen, fill);
	  break;

	case TABLE_DOTTED:
	  {
	    dbe_table_t *tb = sch_name_to_table (sc->sc_cc->cc_schema, tree->_.table.name);
	    comp_table_t *ct = sqlc_table_ct (sc, tb, tree);
	    char *c_prefix = sqlc_ct_vdb_prefix (sc, ct);
	    remote_table_t *rt = find_remote_table (tb->tb_name, 0);

	    if (top_sc->sc_cc->cc_query->qr_select_node && !ct->ct_out_crrs &&
		!sec_tb_check (ct->ct_table, SC_G_ID (sc), SC_U_ID (sc), GR_SELECT))
	      sqlc_new_error (sc->sc_cc, "42000", "SQ161", "No select permission on the table %s.", ct->ct_table->tb_name);
	    sprintf_more (text, tlen, fill, " ");
	    sqlc_quote_dotted (text, tlen, fill, rt->rt_remote_name);
	    if (c_prefix)
	      sprintf_more (text, tlen, fill, " %s%s%s ", SQL_QUOTE, c_prefix, SQL_QUOTE);
	    else
	      sprintf_more (text, tlen, fill, " ");
	    break;
	  }

	case JOINED_TABLE:
	  if (J_INNER == tree->_.join.type)
	    {
	      sqlc_exp_print (sc, NULL, tree->_.join.left, text, tlen, fill);
	      sprintf_more (text, tlen, fill, " INNER join ");
	      sqlc_exp_print (sc, NULL, tree->_.join.right, text, tlen, fill);
	      sprintf_more (text, tlen, fill, " on ");
	      sqlc_exp_print (sc, NULL, tree->_.join.cond, text, tlen, fill);
	      sprintf_more (text, tlen, fill, " ");
	      break;
	    }
	  sprintf_more (text, tlen, fill, "{oj ");
	  sqlc_exp_print (sc, NULL, tree->_.join.left, text, tlen, fill);
	  sprintf_more (text, tlen, fill, " %s outer join ", tree->_.join.type == OJ_LEFT ? "LEFT" : "FULL");
	  sqlc_exp_print (sc, NULL, tree->_.join.right, text, tlen, fill);
	  sprintf_more (text, tlen, fill, " on ");
	  sqlc_exp_print (sc, NULL, tree->_.join.cond, text, tlen, fill);
	  sprintf_more (text, tlen, fill, "}");
	  break;

	case DERIVED_TABLE:
	  sprintf_more (text, tlen, fill, "(");
	  sqlc_exp_print (sc, NULL, tree->_.table_ref.table, text, tlen, fill);
	  sprintf_more (text, tlen, fill, ") ");
	  sqlc_dt_corr_name (text, tlen, fill, tree->_.table_ref.range);
	  sprintf_more (text, tlen, fill, " ");
	  break;

	case ALL_PRED:
	case SOME_PRED:
	case ANY_PRED:
	case ONE_PRED:
	case EXISTS_PRED:
	case IN_SUBQ_PRED:
	  {
	    char *quant = "";
	    const char *op = tree->_.subq.cmp_op ? bop_text ((int) tree->_.subq.cmp_op) : "";
	    if (tree->type == IN_SUBQ_PRED)
	      quant = "IN";
	    else if (tree->type == SOME_PRED)
	      quant = "SOME";
	    else if (tree->type == ANY_PRED)
	      quant = "ANY";
	    else if (tree->type == ALL_PRED)
	      quant = "ALL";
	    switch (tree->type)
	      {
	      case EXISTS_PRED:
		sprintf_more (text, tlen, fill, " EXISTS (");
		break;
	      default:
		if (tree->_.subq.left)
		  sqlc_exp_print (sc, ct, tree->_.subq.left, text, tlen, fill);
		sprintf_more (text, tlen, fill, " %s %s (", op, quant);
	      }
	    sqlc_subquery_text (sc, ct, tree->_.subq.subq, text, tlen, fill, NULL);
	    sprintf_more (text, tlen, fill, ")");
	    break;
	  }
	case SCALAR_SUBQ:
	  sprintf_more (text, tlen, fill, "(");
	  sqlc_subquery_text (sc, ct, tree->_.bin_exp.left, text, tlen, fill, NULL);
	  sprintf_more (text, tlen, fill, ")");
	  break;

	case INSERT_STMT:
	  {
	    ST *tb_ref = tree->_.insert.table;
	    dbe_table_t *tb = sch_name_to_table (sc->sc_cc->cc_schema, tb_ref->_.table.name);
	    sprintf_more (text, tlen, fill, "INSERT INTO ");
	    sqlc_quote_dotted (text, tlen, fill, tb_remote_name (tb));
	    if (!sec_tb_check (tb, (oid_t) unbox (tb_ref->_.table.g_id), (oid_t) unbox (tb_ref->_.table.u_id), GR_INSERT) ||
		(tree->_.insert.mode == INS_REPLACING && !sec_tb_check (tb, SC_G_ID (sc), SC_U_ID (sc), GR_DELETE)))
	      sqlc_new_error (sc->sc_cc, "42000", "SQ162", "No insert or insert/delete permission for insert / insert replacing in table %.300s", tb->tb_name);

	    if (tree->_.insert.cols && BOX_ELEMENTS (tree->_.insert.cols))
	      {
		int first = 1, inx;
		sprintf_more (text, tlen, fill, " (");
		DO_BOX (char *, col, inx, tree->_.insert.cols)
		  {
		    dbe_column_t *col_obj = tb_name_to_column (tb, col);
		    if (!first)
		      sprintf_more (text, tlen, fill, ", ");
		    else
		      first = 0;
		    sqlc_quote_dotted (text, tlen, fill, col_obj ? col_obj->col_name : col);
		    sprintf_more (text, tlen, fill, " ");
		  }
		END_DO_BOX;
		sprintf_more (text, tlen, fill, ") ");
	      }
	    if (ST_P (tree->_.insert.vals, INSERT_VALUES))
	      {
		sprintf_more (text, tlen, fill, " values (");
		sqlc_insert_commalist (sc, ct, tree, tb, text, tlen, fill, 1);
		sprintf_more (text, tlen, fill, ")");
	      }
	    else
	      {
		sqlc_subquery_text (sc, NULL, tree->_.insert.vals, text, tlen, fill, NULL);
	      }
	  }
	  break;

	case DELETE_SRC:
	  {
	    dbe_table_t *tb = sc->sc_tables[0]->ct_table;
	    if (tb && !sec_tb_check (tb, sc->sc_tables[0]->ct_g_id, sc->sc_tables[0]->ct_u_id, GR_DELETE))
	      sqlc_new_error (sc->sc_cc, "42000", "SQ110", "Permission denied for delete from table %.300s", tb->tb_name);
	    sprintf_more (text, tlen, fill, "DELETE FROM ");
	    sqlc_quote_dotted (text, tlen, fill, tb_remote_name (sc->sc_tables[0]->ct_table));
	    if (tree->_.delete_src.table_exp->_.table_exp.where)
	      {
		sprintf_more (text, tlen, fill, " WHERE ");
		sqlc_exp_print (sc, NULL, tree->_.delete_src.table_exp->_.table_exp.where, text, tlen, fill);
	      }
	  }
	  break;

	case UPDATE_SRC:
	  {
	    int first = 1, inx, sec_checked;
	    dbe_table_t *tb = sc->sc_tables[0]->ct_table;
	    sprintf_more (text, tlen, fill, "UPDATE ");
	    sqlc_quote_dotted (text, tlen, fill, tb_remote_name (sc->sc_tables[0]->ct_table));
	    sprintf_more (text, tlen, fill, " set ");
	    sec_checked = sec_tb_check (tb, sc->sc_tables[0]->ct_g_id, sc->sc_tables[0]->ct_u_id, GR_UPDATE);
	    DO_BOX (ST *, exp, inx, tree->_.update_src.vals)
	      {
		dbe_column_t *col_obj = tb_name_to_column (sc->sc_tables[0]->ct_table, (char *) tree->_.update_src.cols[inx]);
		if (!first)
		  sprintf_more (text, tlen, fill, ", ");
		else
		  first = 0;
		if (col_obj)
		  {
		    if (!sec_checked && !sec_col_check (col_obj, sc->sc_tables[0]->ct_g_id, sc->sc_tables[0]->ct_u_id, GR_UPDATE))
		      sqlc_new_error (sc->sc_cc, "42000", "SQ164", "Update of column %s of table %.300s not allowed (user ID = %lu)",
			  col_obj->col_name, sc->sc_tables[0]->ct_table->tb_name, sc->sc_tables[0]->ct_u_id);
		  }
		sprintf_more (text, tlen, fill, " ");
		sqlc_quote_dotted (text, tlen, fill, col_obj ? col_obj->col_name : (char *) tree->_.update_src.cols[inx]);
		sprintf_more (text, tlen, fill, " = ");
		sqlc_exp_print (sc, NULL, exp, text, tlen, fill);
		sqlc_remote_assign_param_type (sc, tree->_.update_src.table->_.table.name, (char *) tree->_.update_src.cols[inx]);
	      }
	    END_DO_BOX;
	    if (tree->_.update_src.table_exp->_.table_exp.where)
	      {
		sprintf_more (text, tlen, fill, " WHERE ");
		sqlc_exp_print (sc, NULL, tree->_.update_src.table_exp->_.table_exp.where, text, tlen, fill);
	      }
	    break;
	  }

	case CALL_STMT:
	  if (sqlc_is_literal_proc (tree->_.call.name))
	    sqlc_print_literal_proc (text, tlen, fill, tree->_.call.name, tree->_.call.params, sc, ct);
	  else if (sqlc_is_standard_proc (target_rds, tree->_.call.name, tree->_.call.params))
	    sqlc_print_standard_proc (text, tlen, fill, tree->_.call.name, tree->_.call.params, sc, ct);
	  else if (sqlc_is_masked_proc (tree->_.call.name))
	    sqlc_print_masked_proc (text, tlen, fill, tree->_.call.name, tree->_.call.params, sc, ct, 0);
	  else if (sqlc_is_remote_proc (target_rds, tree->_.call.name))
	    sqlc_print_remote_proc (text, tlen, fill, tree->_.call.name, tree->_.call.params, sc, ct);
	  else if (sqlc_is_pass_through_function (target_rds, tree->_.call.name))
	    sqlc_print_pass_through_function (text, tlen, fill, target_rds, tree->_.call.name, tree->_.call.params, sc, ct);
/*	  else if (sqlc_is_contains_proc (target_rds, tree->_.call.name, tree->_.call.params))
	    sqlc_print_contains_proc (text, tlen, fill, tree->_.call.name, tree->_.call.params, sc, ct);*/
	  else
	    {
	      state_slot_t *args;
	      state_slot_t **pargs = NULL;
	      int inx;
	      bif_type_t *bt = tree->_.call.name ? bif_type (tree->_.call.name) : NULL;

	      if (bt)
		{
		  args = (state_slot_t *) t_alloc (BOX_ELEMENTS (tree->_.call.params) * sizeof (state_slot_t));
		  pargs = (state_slot_t **) t_box_copy ((caddr_t) tree->_.call.params);
		  _DO_BOX (inx, pargs)
		    {
		      pargs[inx] = &args[inx];
		    }
		  END_DO_BOX;
		}
	      sprintf_more (text, tlen, fill, "%s (", tree->_.call.name);
	      sqlc_exp_commalist_print (sc, ct, tree->_.call.params, text, tlen, fill, NULL, pargs);
	      sprintf_more (text, tlen, fill, ")");
	      if (tree->_.call.name)
		{
		  if (NULL != bt && (bt->bt_dtp != DV_UNKNOWN || bt->bt_func))
		    {
		      state_slot_t ret;
		      memset (&ret, 0, sizeof (ret));
		      bif_type_set (bt, &ret, pargs);
		      sc->sc_exp_sqt = ret.ssl_sqt;
		    }
		  else
		    {
		      query_t *qr = sch_proc_def (sc->sc_cc->cc_schema, tree->_.call.name);
		      if (qr && !IS_REMOTE_ROUTINE_QR (qr) && qr->qr_proc_ret_type)
			{
			  ptrlong *rtype = (ptrlong *) qr->qr_proc_ret_type;
			  if (((dtp_t) rtype[0]) != DV_UNKNOWN)
			    {
			      sc->sc_exp_sqt.sqt_dtp = (dtp_t) rtype[0];
			      sc->sc_exp_sqt.sqt_col_dtp = 0;
			      sc->sc_exp_sqt.sqt_precision = (uint32) rtype[1];
			    }
			}
		    }
		}
	    }
	  break;

	default:
	  sqlc_new_error (sc->sc_cc, "37000", "VD031", "Cannot reprint node %ld for remote text", tree->type);
	  break;
	}
    }
}


void
ssl_set_by_st (state_slot_t * sl, char *col_name, sql_type_t * sqt)
{
  dk_free_box (sl->ssl_name);
  sl->ssl_name = box_dv_uname_string (col_name);
  sl->ssl_sqt = *sqt;
}


void
sqlc_exp_commalist_print (sql_comp_t * sc, comp_table_t * ct, ST ** exps, char *text, size_t tlen, int *fill, select_node_t * sel, state_slot_t ** ssls)
{
  int first = 1, inx;
  DO_BOX (ST *, exp, inx, exps)
    {
      if (!first)
	sprintf_more (text, tlen, fill, ", ");
      else
	first = 0;
      sqlc_exp_print (sc, ct, exp, text, tlen, fill);
      if (sel)
	{
	  ssl_set_by_st (sel->sel_out_slots[inx], sc->sc_exp_col_name, &sc->sc_exp_sqt);
	}
      if (ssls)
	{
	  ssls[inx]->ssl_sqt = sc->sc_exp_sqt;
	}
    }
  END_DO_BOX;
}




void
sqlc_make_remote_after_group_scope (sql_comp_t * sc, ST ** selection)
{
  int inx;

  DO_BOX (ST *, sel, inx, selection)
    {
      if (ST_P (sel, BOP_AS))
	{
	  t_NEW_VARZ (col_ref_rec_t, crr);
	  crr->crr_col_ref = (ST *) t_list (3, COL_DOTTED, NULL, t_box_string (sel->_.as_exp.name));
	  crr->crr_is_as_alias = 1;
	  t_set_push (&sc->sc_col_ref_recs, (void *) crr);
	  t_set_push (&sc->sc_temp_trees, (void *) crr->crr_col_ref);
	}
    }
  END_DO_BOX;
}


void
sqlc_subquery_text (sql_comp_t * super_sc, comp_table_t * subq_for_pred_in_ct, ST * tree, char *text, size_t tlen, int *fill, select_node_t * sel)
{
  query_t *qr = NULL;		/*dummy for CC_INIT */
  comp_context_t cc;
  sql_comp_t sc;

  memset (&sc, 0, sizeof (sc));
  CC_INIT (cc, super_sc->sc_client);

  sc.sc_cc = &cc;
  cc.cc_super_cc = super_sc->sc_cc->cc_super_cc;

  sc.sc_super = super_sc;
  sc.sc_so = super_sc->sc_so;
  sc.sc_super_ct = subq_for_pred_in_ct ? subq_for_pred_in_ct : super_sc->sc_super_ct;
  sc.sc_client = super_sc->sc_client;
  sc.sc_exp_print_hook = super_sc->sc_exp_print_hook;
  sc.sc_exp_print_cd = super_sc->sc_exp_print_cd;

  sqlc_table_ref_list (&sc, ((ST *) tree->_.select_stmt.table_exp)->_.table_exp.from);

  {
    ST *selection = (ST *) tree->_.select_stmt.selection;
    ST *texp = tree->_.select_stmt.table_exp;
    ST *top = SEL_TOP (tree);

    if (IS_BOX_POINTER (texp->_.table_exp.from) &&
	BOX_ELEMENTS (texp->_.table_exp.from) == 1 &&
	!top &&
	!SEL_IS_DISTINCT (tree) &&
	!texp->_.table_exp.group_by &&
	!texp->_.table_exp.having &&
	!texp->_.table_exp.order_by &&
	ST_P (texp->_.table_exp.from[0], DERIVED_TABLE) &&
	ST_P (texp->_.table_exp.from[0]->_.table_ref.table, SELECT_STMT) &&
	BOX_ELEMENTS (texp->_.table_exp.from[0]->_.table_ref.table->_.select_stmt.selection) == BOX_ELEMENTS (selection))
      {
	int has_fun_ref = 0;
	int inx;
	DO_BOX (ST *, _sel, inx, (ST **) selection)
	  {
	    if (ST_P (_sel, FUN_REF))
	      {
		has_fun_ref = 1;
		break;
	      }
	  }
	END_DO_BOX;
	if (!has_fun_ref)
	  {
	    sc.sc_derived_opt = tree;
	    sqlc_subquery_text (&sc, NULL, texp->_.table_exp.from[0]->_.table_ref.table, text, tlen, fill, sel);
	    sc_free (&sc);
	    return;
	  }
      }

    if (top && (IS_SQLSERVER_RDS (target_rds) || IS_VIRTUOSO_RDS (target_rds)))
      {
	sprintf_more (text, tlen, fill, "SELECT TOP ");
	sqlc_exp_print (&sc, NULL, top->_.top.exp, text, tlen, fill);
	if (top->_.top.percent)
	  sprintf_more (text, tlen, fill, " PERCENT");
	if (top->_.top.ties)
	  sprintf_more (text, tlen, fill, " WITH TIES");
	if (SEL_IS_DISTINCT (tree))
	  sprintf_more (text, tlen, fill, " DISTINCT");
	sprintf_more (text, tlen, fill, " ");
      }
    else
      sprintf_more (text, tlen, fill, "SELECT %s ", SEL_IS_DISTINCT (tree) ? "DISTINCT" : "");

    sqlc_exp_commalist_print (&sc, NULL, (ST **) selection, text, tlen, fill, sel, NULL);

    sprintf_more (text, tlen, fill, " FROM ");
    sqlc_exp_commalist_print (&sc, NULL, texp->_.table_exp.from, text, tlen, fill, NULL, NULL);

    if (texp->_.table_exp.where ||
	(sc.sc_super && sc.sc_super->sc_derived_opt && sc.sc_super->sc_derived_opt->_.select_stmt.table_exp->_.table_exp.where))
      /* we must check if the topmost where */
      {
	sprintf_more (text, tlen, fill, " WHERE ");
	if (sc.sc_super && sc.sc_super->sc_derived_opt && sc.sc_super->sc_derived_opt->_.select_stmt.table_exp->_.table_exp.where)
	  {
	    ST *_and = NULL;
	    if (texp->_.table_exp.where)
	      {
		BIN_OP (_and, BOP_AND, texp->_.table_exp.where, sc.sc_super->sc_derived_opt->_.select_stmt.table_exp->_.table_exp.where);
		sqlc_exp_print (&sc, NULL, _and, text, tlen, fill);
		dk_free_box ((box_t) _and);
	      }
	    else
	      {
		sqlc_exp_print (&sc, NULL, sc.sc_super->sc_derived_opt->_.select_stmt.table_exp->_.table_exp.where, text, tlen, fill);
	      }
	  }
	else
	  sqlc_exp_print (&sc, NULL, texp->_.table_exp.where, text, tlen, fill);
      }
    sqlc_make_remote_after_group_scope (&sc, (ST **) selection);
    if (texp->_.table_exp.group_by)
      {
	sqlc_order_by_print (&sc, "GROUP BY", (ST **) texp->_.table_exp.group_by, text, tlen, fill, NULL, NULL);
      }
    if (texp->_.table_exp.having)
      {
	sprintf_more (text, tlen, fill, " HAVING ");
	sqlc_exp_print (&sc, NULL, texp->_.table_exp.having, text, tlen, fill);
      }
    if (texp->_.table_exp.order_by)
      {
	sqlc_order_by_print (&sc, "ORDER BY", (ST **) texp->_.table_exp.order_by, text, tlen, fill, (caddr_t *) selection, NULL);
      }
  }

  sc_free (&sc);
}

















remote_ds_t *
sqlc_first_location (sql_comp_t * sc, ST * tree)
{
      return NULL;
}


void
sqlc_resignal (sql_comp_t * sc, caddr_t err)
{
  char state[10];
  char temp[1000];
  snprintf (temp, sizeof (temp), "remote prepare: %.900s", ((char **) err)[2]);
  strncpy (state, ((char **) err)[1], sizeof (state));
  dk_free_tree (err);
  sqlc_new_error (sc->sc_cc, state, "VD032", temp);
}



ST **box_add_prime_keys (ST ** selection, dbe_table_t * tb);


dbe_table_t *
sqlc_expand_remote_cursor (sql_comp_t * sc, ST * tree)
{
  /* single table select of remote/cluster/col-wise table, add prime key cols */
  ST **n_sel;
  ST **from = tree->_.select_stmt.table_exp->_.table_exp.from;
  ST *t1 = from[0]->_.table_ref.table;
  if (1 == BOX_ELEMENTS (from) && ST_P (t1, TABLE_DOTTED) && !tree->_.select_stmt.table_exp->_.table_exp.group_by)
    {
      dbe_table_t *tb = sch_name_to_table (sc->sc_cc->cc_schema, t1->_.table.name);
      remote_table_t *rt;
      if (!tb)
	return 0;
      if (sqlo_opt_value (t1->_.table.opts, OPT_INDEX_ONLY))
	return 0;
      rt = find_remote_table (tb->tb_name, 0);
      if (!rt && !tb->tb_primary_key->key_partition && !tb->tb_primary_key->key_is_col)
	return 0;
      n_sel = box_add_prime_keys ((ST **) tree->_.select_stmt.selection, tb);
      /*dk_free_tree ((caddr_t) tree->_.select_stmt.selection); */
      tree->_.select_stmt.selection = (caddr_t *) n_sel;
      return tb;
    }
  return 0;
}


ST *
sqlc_co_ref (sql_comp_t * sc, subq_compilation_t * sqc, state_slot_t * sl, dbe_column_t * col, caddr_t prefix)
{
  ST * ref = (ST *) t_list (3, COL_DOTTED, t_box_string (prefix), t_box_string (col->col_name));
  col_ref_rec_t * pre_crr = sqlc_col_ref_rec (sc, ref, 0);
  if (!pre_crr)
    {
      state_slot_t * copy_ssl = ssl_new_variable (sc->sc_cc, sl->ssl_name, sl->ssl_sqt.sqt_dtp);
      t_NEW_VARZ (col_ref_rec_t, crr);
      crr->crr_ssl = copy_ssl;
      crr->crr_col_ref = ref;
      t_set_push (&sc->sc_col_ref_recs, (void *) crr);
      pre_crr = crr;
    }
  DO_SET (instruction_t *, ins, &sqc->sqc_fetches)
    {
      int pos = box_position_no_tag ((caddr_t*)ins->_.fetch.targets, (caddr_t)pre_crr->crr_ssl);
      if (-1 == pos)
	ins->_.fetch.targets = (state_slot_t **) box_append_1_free ((caddr_t)ins->_.fetch.targets, (caddr_t)pre_crr->crr_ssl);
    }
  END_DO_SET();
  return ref;
}


ST *
sqlc_pos_to_searched_where (sql_comp_t * sc, subq_compilation_t * sqc, char *cr_name, dbe_table_t * tb)
{
  int inx;
  ST *tree = NULL;
  if (sqc)
    {
      /*add pk cols of cr to scope, then generate where referencing these */
      ST *pred;
      char prefix[11];
      static int cr_ctr;
      state_slot_t **out = sqc->sqc_query->qr_select_node->sel_out_slots;
      int n_out = BOX_ELEMENTS (out);
      int n_parts = tb->tb_primary_key->key_n_significant;
      dk_set_t pk_cols = tb->tb_primary_key->key_parts;

      /* for local cr in cluster, n_out may include co placeholders which will be ignored here */
      while (n_out &&
	     DV_ITC == out[n_out - 1]-> ssl_sqt.sqt_dtp)
	n_out--;
      if (!sqc->sqc_cr_pref_no)
	sqc->sqc_cr_pref_no = ++cr_ctr;
      snprintf (prefix, sizeof (prefix), "C%d", sqc->sqc_cr_pref_no);

      for (inx = 0; inx < n_parts; inx++)
	{
	  dbe_column_t *col = (dbe_column_t *) pk_cols->data;
	  state_slot_t *sl = out[(n_out - n_parts) + inx];
	  ST * cr_ref = sqlc_co_ref (sc, sqc, sl, col, prefix);
	  pred = (ST *) t_list (4, BOP_EQ, t_list (3, COL_DOTTED, NULL, t_box_string (col->col_name)), cr_ref, NULL);
	  if (tree)
	    {
	      ST *res;
	      BIN_OP (res, BOP_AND, tree, pred);
	      tree = res;
	    }
	  else
	    tree = pred;
	  pk_cols = pk_cols->next;
	}

      return tree;
    }
  else
    {
      int inx = 0;
      DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
	{
	  t_st_and (&tree, (ST *)
	      t_list (4, BOP_EQ, t_list (3, COL_DOTTED, NULL, t_box_string (col->col_name)),
		  t_list (3, CALL_STMT, t_sqlp_box_id_upcase ("__cr_id_part"),
		      t_list (3, t_box_string (cr_name), t_box_string (tb->tb_name), t_box_num (inx))), NULL));

	  inx++;
	  if (inx >= tb->tb_primary_key->key_n_significant)
	    break;
	}
      END_DO_SET ();
      return tree;
    }
}

