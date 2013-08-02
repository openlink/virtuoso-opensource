/*
 *  xmlsql.c
 *
 *  $Id$
 *
 *  Dynamic SQL Compiler, part 2
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
#include "sqlnode.h"
#include "eqlcomp.h"
#include "lisprdr.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "xmlgen.h"
#include "remote.h"
#include "sqlrcomp.h"
#include "sqlbif.h"

/* IvAn/ViewDTD/000718 Added */
#include "Dk/Dkhash.h"
#include "Dk/Dksets.h"
#include "Wi/widv.h"
#include "xmlres.h"
#include "http.h"
/* IvAn/ViewDTD/000718 Added */
#include "xmltree.h"
#include "sqlo.h"
#include "xml.h"
#include "multibyte.h"

#if 0
#define dbg_xmlsql(s)	 printf s
#else
#define dbg_xmlsql(s)
#endif



void
ks_rm_misc_specs (key_source_t * ks)
{
  /* drop all that are in the misc accelerator */
  search_spec_t **prev = &ks->ks_row_spec;
  search_spec_t *sp = *prev;
  while (sp)
    {

    }
}

#define MAX_MISC_REFS 1000


dp_addr_t
misc_crr_key (col_ref_rec_t * crr)
{
  return (dp_addr_t) (crr->crr_dbe_col->col_id);
}



dp_addr_t
asg_key (misc_asg_t * asg)
{
  return (dp_addr_t) (asg->asg_col_id);
}


void
upd_arrange_misc (sql_comp_t * sc, update_node_t * upd)
{
  int inx;
  int fill;
  int any_misc = 0;
  misc_asg_t asg[UPD_MAX_COLS];
  misc_asg_t *asgp[UPD_MAX_COLS];
  if (BOX_ELEMENTS (upd->upd_col_ids) > UPD_MAX_COLS)
    sqlc_error (sc->sc_cc, "37000", "Too many columns in update");

  DO_BOX (oid_t, id, inx, upd->upd_col_ids)
  {
    asg[inx].asg_col_id = id;
    asg[inx].asg_ssl = upd->upd_values[inx];
    asgp[inx] = &asg[inx];
    if (IS_MISC_ID (id))
      any_misc = 1;
  }
  END_DO_BOX;
  if (!any_misc)
    return;
  fill = inx;
  buf_bsort ((buffer_desc_t **) & asgp, fill, (sort_key_func_t) asg_key);
  for (inx = 0; inx < fill; inx++)
    {
      upd->upd_values[inx] = asgp[inx]->asg_ssl;
      upd->upd_col_ids[inx] = asgp[inx]->asg_col_id;
    }
}


void
dk_set_set_nth (dk_set_t set, int n, void *v)
{
  int inx;
  for (inx = 0; inx < n; inx++)
    {
      if (!set)
	return;
      set = set->next;
    }
  if (!set)
    return;
  set->data = v;
}




int
qi_ensure_attr (query_instance_t * qi, char *name)
{
  xml_attr_t *attr = lt_xml_attr (NULL, name);
  if (!attr)
    {
      oid_t id = qi_new_attr (qi, name);
      caddr_t arr = (caddr_t) list (3, box_dv_short_string ("xml_attr_replay (?, ?)"), box_dv_short_string (name), box_num (id));
      log_text_array (qi->qi_trx, arr);
      dk_free_tree (arr);

      return 1;
    }
  return 0;
}


static ST *
sqlc_xj_cond (sql_comp_t * sc, comp_table_t * ct, dk_set_t *join_preds)
{
  ST *res = NULL;
  DO_SET (predicate_t *, jpred, join_preds)
  {
    res = sql_tree_and (res, jpred->pred_text);
  }
  END_DO_SET ();
  DO_SET (predicate_t *, pred, &sc->sc_preds)
  {
    if (!pred->pred_generated)
      {
	/* go to next pred if all the needed tables are not generated yet. */
	DO_SET (comp_table_t *, req_ct, &pred->pred_tables)
	{
	  if (req_ct->ct_sc == sc
	      && !req_ct->ct_generated
	      && req_ct != ct)
	    goto next_pred;
	}
	END_DO_SET ();

	pred->pred_generated = 1;
	res = sql_tree_and (res, pred->pred_text);
	/* Generate this predicate for this table */
      }
  next_pred:;
  }
  END_DO_SET ();
  ct->ct_generated = 1;
  return res;
}


void
sqlc_xj_prefixes (sql_comp_t * sc, ST * tree)
{
  if (!tree)
    return;
  if (SYMBOLP (tree))
    {
      sqlr_error ("37000", "Parameters not allowed in xml view");
    }
  if (ST_P (tree, QUOTE))
    return;
  if (ST_COLUMN (tree, COL_DOTTED))
    {
      col_ref_rec_t *cr = sqlc_col_or_param (sc, tree, 0);
      if (!cr->crr_ct)
	sqlr_error ("37000", "Column reference not to a column in xml view");
      tree->_.col_ref.prefix = box_dv_short_string
	  (cr->crr_ct->ct_prefix ? cr->crr_ct->ct_prefix : cr->crr_ct->ct_table->tb_name_only);
    }
  else if (BIN_EXP_P (tree))
    {
      sqlc_xj_prefixes (sc, tree->_.bin_exp.left);
      sqlc_xj_prefixes (sc, tree->_.bin_exp.right);
    }
  else if (SUBQ_P (tree))
    {
      sqlr_error ("37000", "subquery not allowed in xml view");
    }
  else if (ST_P (tree, SCALAR_SUBQ))
    {

    }
  else if (ST_P (tree, CALL_STMT))
    {
      int inx;
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree->_.call.name))
	sqlc_xj_prefixes (sc, ((ST **) tree->_.call.name)[0]);
      DO_BOX (ST *, arg, inx, tree->_.call.params)
      {
	sqlc_xj_prefixes (sc, arg);
      }
      END_DO_BOX;
    }
  else if (ST_P (tree, COMMA_EXP)
	|| ST_P (tree, SIMPLE_CASE)
	|| ST_P (tree, SEARCHED_CASE)
      || ST_P (tree, COALESCE_EXP))
    {
      int inx;
      DO_BOX (ST *, arg, inx, tree->_.comma_exp.exps)
      {
	sqlc_xj_prefixes (sc, arg);
      }
      END_DO_BOX;
    }
}


void
sqlc_xj_cols (sql_comp_t * sc, comp_table_t * ct, xv_join_elt_t * xj)
{
  dk_set_t res = NULL;
  DO_SET (col_ref_rec_t *, crr, &sc->sc_col_ref_recs)
  {
    if (crr->crr_ct != ct)
      continue;				/* If it is not the table we need */
    if (crr->crr_dbe_col)
      {				/* If it is plain column */
	t_set_push (&res, t_list (5,
	    t_list (3, COL_DOTTED, NULL, t_box_copy (crr->crr_dbe_col->col_name)),
	    t_box_copy (crr->crr_dbe_col->col_name),
	    XV_XC_ATTRIBUTE, NULL, NULL));
	continue;
      }
    if (crr->crr_col_ref && (COL_DOTTED == crr->crr_col_ref->type))
      {				/* Something not so plain, but it has a name :) */
	t_set_push (&res, t_list (5,
	    t_list (3, COL_DOTTED, NULL, t_box_copy (crr->crr_col_ref->_.col_ref.name)),
	    t_box_copy (crr->crr_col_ref->_.col_ref.name),
	    XV_XC_ATTRIBUTE, NULL, NULL));
      }
  }
  END_DO_SET ();
  list_nappend ((caddr_t *)(&(xj->xj_cols)), list_to_array (res));
}


xv_join_elt_t *
sqlc_xml_view_from_select (sql_comp_t * sc)
{
  int inx;
  xv_join_elt_t *prev = (xv_join_elt_t *)
  dk_alloc_box (sizeof (xv_join_elt_t), DV_ARRAY_OF_POINTER);
  xv_join_elt_t *top = prev;
  memset (prev, 0, box_length ((caddr_t) prev));
  DO_SET (predicate_t *, pred, &sc->sc_preds)
  {
    pred->pred_generated = 0;
  }
  END_DO_SET ();
  DO_BOX (comp_table_t *, ct, inx, sc->sc_tables)
  {
    ct->ct_generated = 0;
  }
  END_DO_BOX;
  DO_BOX (comp_table_t *, ct, inx, sc->sc_tables)
  {
    xv_join_elt_t *xj = (xv_join_elt_t *)
    dk_alloc_box (sizeof (xv_join_elt_t), DV_ARRAY_OF_POINTER);
    memset (xj, 0, box_length ((caddr_t) xj));
    prev->xj_children = (xv_join_elt_t **) list (1, xj);
    prev = xj;
    if (!ct->ct_table)
      sqlr_error ("42000", "The select in an XML view must be from tables, named views and/or their joins");
    xj->xj_table = box_copy (ct->ct_table->tb_name);
    if (ct->ct_prefix)
      xj->xj_prefix = box_copy (ct->ct_prefix);
    else
      xj->xj_prefix = box_dv_short_string (ct->ct_table->tb_name_only);
    xj->xj_element = box_dv_uname_string (xj->xj_prefix);
    xj->xj_join_cond = sqlc_xj_cond (sc, ct, &(ct->ct_join_preds));
    xj->xj_join_is_outer = ct->ct_is_outer;
    sqlc_xj_prefixes (sc, xj->xj_join_cond);
    sqlc_xj_cols (sc, ct, xj);
    if (!BOX_ELEMENTS(xj->xj_cols))
      sqlr_error ("42000", "Unable to create XML view for \"%s\" automatically", ct->ct_table->tb_name);
  }
  END_DO_BOX;
  return top;
}


static caddr_t
xv_check_from_expn_of_select_stmt (ST *from_expn, int is_in_left_join, int is_last)
{
  caddr_t res;
  switch(from_expn->type)
    {
    case TABLE_REF:
      return xv_check_from_expn_of_select_stmt (from_expn->_.table_ref.table, is_in_left_join, is_last);
    case JOINED_TABLE:
      if(1 == is_in_left_join)
	return srv_make_new_error ("42000", "SX001",
	    "Unable to create XML view: left argument of JOIN may not be JOIN again");
      switch(from_expn->_.join.type)
	{
	case OJ_LEFT:
	  if(!is_last)
	    return srv_make_new_error ("42000", "SX002",
		"Unable to create XML view from SELECT statement: "
		"LEFT OUTER JOIN should be the last expression of FROM clause");
	  break;
	case J_INNER:
	case J_CROSS:
	  if(2 == is_in_left_join)
	    return srv_make_new_error ("42000", "SX003",
		"Unable to create XML view: right argument of LEFT OUTER JOIN "
		"may be only a table or a nested LEFT OUTER JOIN");
	  break;
	case OJ_FULL:
	  return srv_make_new_error ("42000", "SX004",
	      "Unable to create XML view: FULL JOIN may not be grouped by left "
	      "table to compose a tree");
	case OJ_RIGHT:
	  return srv_make_new_error ("42000", "SX005",
	      "Unable to create XML view: RIGHT JOIN may not be grouped by left "
	      "table to compose a tree");
	default:
	  return srv_make_new_error ("42000", "SX006",
	      "Unable to create XML view: unsupported type of JOIN expression in FROM clause");
	}
      res = xv_check_from_expn_of_select_stmt(from_expn->_.join.left, 1, is_last);
      return ((NULL != res) ? res : xv_check_from_expn_of_select_stmt(from_expn->_.join.right, 2, is_last));
    case TABLE_DOTTED:
      return NULL;
    default:
      return srv_make_new_error ("42000", "SX007",
	  "Unable to create XML view: unsupported table expression in FROM clause");
    }
}


static caddr_t
xv_check_select_stmt (ST *sel_stmt)
{
  caddr_t res;
  int inx;
  int is_last_inx;
  if(SEL_IS_DISTINCT (sel_stmt))
    return srv_make_new_error ("42000", "SX008",
	"Unable to create XML view from SELECT statement: DISTINCT is not supported");
  if(NULL == sel_stmt->_.select_stmt.table_exp)
    return srv_make_new_error ("42000", "SX009",
	"Unable to create XML view from SELECT statement: FROM clause is missing or empty");
  if(sel_stmt->_.select_stmt.table_exp->type != TABLE_EXP)
    return srv_make_new_error ("42000", "SX010",
	"Unable to create XML view from SELECT statement: unsupported type of FROM clause");
  if(NULL != sel_stmt->_.select_stmt.table_exp->_.table_exp.group_by)
    return srv_make_new_error ("42000", "SX011",
	"Unable to create XML view from SELECT statement: GROUP BY clause is not supported");
  if(NULL != sel_stmt->_.select_stmt.table_exp->_.table_exp.order_by)
    return srv_make_new_error ("42000", "SX012",
	"ORDER BY may not work for XML view from SELECT statement");
  DO_BOX (ST *, from_expn, inx, sel_stmt->_.select_stmt.table_exp->_.table_exp.from)
  {
    is_last_inx = (inx == (int) (BOX_ELEMENTS (sel_stmt->_.select_stmt.table_exp->_.table_exp.from) - 1));
    res = xv_check_from_expn_of_select_stmt(from_expn, 0, is_last_inx);
    if (NULL != res)
      return res;
  }
  END_DO_BOX;
  return NULL;
}


void
xv_select_view (sql_comp_t * sc, xml_view_t * tree)
{
  ST *sel = (ST *) tree->xv_tree;
  caddr_t check_res = NULL;
  if (ST_P (sel, SELECT_STMT))
    {
      sc->sc_no_remote = 1;
/* SELECT statement should be checked before sql_stmt_comp() -- it may rewrite joins -- but
   any error found should be reported only if sql_stmt_comp throws no "fat" errors, so error
   should be saved and thrown later. */
      check_res = xv_check_select_stmt(sel);
      sql_stmt_comp (sc, (ST **) &tree->xv_tree);
      if (NULL != check_res)
	{
	  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR, check_res);
	  lisp_throw (CATCH_LISP_ERROR, 1);
	}
      tree->xv_tree = sqlc_xml_view_from_select (sc);
      sc->sc_cc->cc_query->qr_head_node = NULL;
    }
}



void
xj_tree_prepare (xv_join_elt_t * xj, xv_join_elt_t * parent,
    query_instance_t * qi, int all_cols_as_subelements)
{
  int inx, inx2;
  xj->xj_parent = parent;
  if (all_cols_as_subelements)
    xj->xj_all_cols_as_subelements = 1;
  if (xj->xj_all_cols_as_subelements)
    {
      DO_BOX (xj_col_t *, xc, inx2, xj->xj_cols)
      {
	xc->xc_usage &= ~XV_XC_ATTRIBUTE;
	xc->xc_usage |= XV_XC_SUBELEMENT;
      }
      END_DO_BOX;
    }
#ifdef DEBUG
  DO_BOX (xj_col_t *, xc, inx2, xj->xj_cols)
    {
      if (!xc->xc_usage)
        GPF_T;
      if ((XV_XC_ATTRIBUTE & xc->xc_usage) && (XV_XC_SUBELEMENT & xc->xc_usage))
        GPF_T;
    }
  END_DO_BOX;
#endif
  if (xj->xj_table)
    {
      dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema, xj->xj_table);
      if (!tb)
	{
	  if (qi)
	    sqlr_error ("S0002", "No table %s in create xml", xj->xj_table);
	  else
	    return;
	}
      if (!xj->xj_pk)
	{
	  int fill = 0;
	  dbe_key_t *pk = tb->tb_primary_key;
	  xj->xj_pk = (caddr_t *) dk_alloc_box (pk->key_n_significant * sizeof (caddr_t),
	      DV_ARRAY_OF_POINTER);
	  DO_SET (dbe_column_t *, col, &pk->key_parts)
	  {
	    xj->xj_pk[fill++] = box_dv_short_string (col->col_name);
	    if (fill >= pk->key_n_significant)
	      break;
	  }
	  END_DO_SET ();
	}
      DO_BOX (xj_col_t *, xc, inx2, xj->xj_cols)
      {
	if (qi && (XV_XC_ATTRIBUTE & xc->xc_usage))
	  qi_ensure_attr (qi, xc->xc_xml_name);
      }
      END_DO_BOX;
    }
  if (xj->xj_children)
    {
      DO_BOX (xv_join_elt_t *, c, inx, xj->xj_children)
      {
	xj_tree_prepare (c, xj, qi, all_cols_as_subelements);
      }
      END_DO_BOX;
    }
}

void
xmls_set_view_def (void *sc2, xml_view_t * xv)
{
  sql_comp_t *sc = (sql_comp_t *) sc2;
  xv = (xml_view_t *) box_copy_tree ((caddr_t) xv);
  xv_select_view (sc, xv);
  xj_tree_prepare (xv->xv_tree, NULL, NULL, xv->xv_all_cols_as_subelements);
  mpschema_set_view_def (xv->xv_full_name, (caddr_t) xv);/*mapping schema*/
}


xml_view_t *
xmls_view_def (char *name)
{
  char buf[MAX_QUAL_NAME_LEN+20];
  char *bufptr = buf;
  xml_view_t **place;
  place = (xml_view_t **) id_hash_get (xml_global->xs_views, (caddr_t)(&name));
  if (place)
    return *place;
  snprintf (buf, sizeof (buf), "DB.DBA.%s", name);
  place = (xml_view_t **) id_hash_get (xml_global->xs_views, (caddr_t)(&bufptr));
  if (place)
    return *place;
  return NULL;
}


int
xmlg_join_col (sql_comp_t * sc, comp_table_t * ct, ST * tree, char *text, size_t tlen, int *fill)
{
  if (ST_COLUMN (tree, COL_DOTTED))
    {
      dk_set_t map = (dk_set_t) sc->sc_exp_print_cd;
      while (map)
	{
	  if (box_equal ((caddr_t) map->data, (caddr_t) tree))
	    {
	      tailprintf (text, tlen, fill, "%s", map->next->data);
	      return 1;
	    }
	  map = map->next->next;
	}
      if (tree->_.col_ref.prefix)
	tailprintf (text, tlen, fill, "\"%s\".\"%s\"", tree->_.col_ref.prefix, tree->_.col_ref.name);
      else
	tailprintf (text, tlen, fill, "\"%s\"", tree->_.col_ref.name);
      return 1;
    }
  else
    return 0;
}


static char *tag_indents[] = {
 "",
 "\\n",
 "\\n ",
 "\\n  ",
 "\\n   ",
 "\\n    ",
 "\\n     ",
 "\\n      ",
 "\\n       ",
 "\\n\\t",
 "\\n\\t ",
 "\\n\\t  ",
 };

#define NUMBEROF_tag_indents (sizeof(tag_indents)/sizeof(tag_indents[0]))

typedef struct xv_context_s
{
  query_instance_t *xvc_qi;
  sql_comp_t * xvc_sc;
  xml_view_t * xvc_tree;
  char *xvc_schema;
  char *xvc_user;
  char *xvc_local_name;
  int xvc_mode;
  char *xvc_text;
  int xvc_text_fill;
  size_t xvc_text_len;
  dk_set_t xvc_proc_errors;
} xv_context_t;

#define XVC_COMMA(xvc,first) COMMA (xvc->xvc_text, xvc->xvc_text_len, &(xvc->xvc_text_fill), (first))

caddr_t xv_get_default_namespace (xv_context_t * xvc)
{
/*  char * def_name = "xmlns";*/
  caddr_t ns_name = NULL;
  xml_view_nsdef_t ** namespaces;
  xml_view_t * tree = xvc->xvc_tree;
  int nsidx, nsidx1, length;
  namespaces = tree->xv_namespaces;
  if (!IS_BOX_POINTER (namespaces))
      return NULL;
  length = BOX_ELEMENTS(namespaces);
  for (nsidx = 0; nsidx < length - 1; nsidx ++)
    {
      xml_view_nsdef_t * nsdef = namespaces[nsidx];
      for (nsidx1 = nsidx + 1; nsidx1 < length; nsidx1 ++)
        {
          xml_view_nsdef_t * nsdef1 = namespaces[nsidx1];
          if (!strcmp (nsdef->xvns_prefix, nsdef1->xvns_prefix))
            sqlr_new_error ("37000", "SQ167", "The namespace name '%s' is declared more than once in create xml view %s.", nsdef->xvns_prefix, xvc->xvc_tree->xv_full_name);
        }
    }

  DO_BOX (xml_view_nsdef_t *, nsdef, nsidx, namespaces)
    {
      char * prefix = unbox_string (nsdef->xvns_prefix);
      if (!strcmp(prefix,""))
        sqlr_new_error ("37000", "SQ165", "Empty namespace name is not valid in create xml view %s.", xvc->xvc_tree->xv_full_name);
      if (!strcmp(nsdef->xvns_uri,""))
        sqlr_new_error ("37000", "SQ166", "Empty namespace local part is not valid in create xml view %s.", xvc->xvc_tree->xv_full_name);
      if (!strcmp (prefix, "xmlns"))
        {
          size_t length = strlen(nsdef->xvns_uri);
          ns_name = dk_alloc_box (length+2, DV_SHORT_STRING); /*to add ':' and \0*/
          memcpy (ns_name, nsdef->xvns_uri, length);
          memcpy (ns_name+length, ":\0", 2);
        }
      else if (!strnicmp (prefix, "xml", 3))
        sqlr_new_error ("37000", "SQ169", "The first three letters of namespace name '%s' must not be 'xml' in create xml view %s.", nsdef->xvns_prefix, xvc->xvc_tree->xv_full_name);
    }
  END_DO_BOX;
  return ns_name;
}


caddr_t xv_get_name_with_nsprefix (xv_context_t * xvc, caddr_t name, int is_attr, caddr_t default_namespace)
{
  caddr_t  prefix;
  caddr_t  postfix;
  caddr_t  full_name;
  char *   last_colon;
  xml_view_nsdef_t ** namespaces;
  xml_view_t * tree = xvc->xvc_tree;
  int inx;
  int nsidx;
  char * small_name = unbox_string(name);
  last_colon = strrchr(small_name, ':');
  if (last_colon == NULL)
    {
      if ((is_attr) || (!default_namespace))
	return name;
      else
	{ /* add default_namespace */
	  size_t length = strlen(default_namespace);
	  full_name = dk_alloc_box (length + strlen(name) + 1, DV_SHORT_STRING);
	  memcpy (full_name, default_namespace, length);
	  memcpy (full_name+length, name, strlen(name)+1);
	  return full_name;
	}
    }
  inx = (int) (last_colon - small_name + 1); /* length of prefix (until last ':') */
  postfix = box_string (last_colon+1);
  prefix = dk_alloc_box (inx, DV_SHORT_STRING);
  memcpy (prefix, small_name, inx-1);
  prefix[inx-1] = '\0';
  namespaces = tree->xv_namespaces;
  DO_BOX (xml_view_nsdef_t *, nsdef, nsidx, namespaces)
    {
      if (!strcmp (nsdef->xvns_prefix, prefix))
        {
          int length = (int) strlen(nsdef->xvns_uri);
          full_name = dk_alloc_box (length + strlen(last_colon) + 1, DV_SHORT_STRING); /*to add ':' and '\0'*/
          memcpy (full_name, nsdef->xvns_uri, length);
          memcpy (full_name+length, last_colon, strlen(last_colon)+1);
          dk_free_box (prefix);
          dk_free_box (postfix);
          return full_name;
        }
    }
  END_DO_BOX
  sqlr_new_error ("37000", "SQ168", "Unknown namespace name '%s' in create xml view %s.", prefix, xvc->xvc_tree->xv_full_name);
  dk_free_box (prefix);
  return postfix;
}


void xmlg_printf (xv_context_t * xvc, const char *string, ...) /* IvAn/AutoDTD/000919 Added */
{
  int len;
  char *text_tail = xvc->xvc_text + xvc->xvc_text_fill;
  va_list list;
  va_start (list, string);
  len = vsnprintf (text_tail, xvc->xvc_text_len - xvc->xvc_text_fill, string, list);
  va_end (list);
  if (len < 0)
    return;
  xvc->xvc_text_fill += len;
}


static void
xmlg_exp_print (xv_context_t * xvc, ST *exp)
{
  int fill = 0;
  caddr_t volatile err = NULL;

  if (NULL == sqlc_client())
    sqlc_set_client (xvc->xvc_qi->qi_client);
/* The trick with passing shifted xvc_text and zero fill is made
in order to relax the check for expression length inside sqlc_exp_print. */

  CATCH (CATCH_LISP_ERROR)
    {
      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR, NULL);
      sqlc_exp_print (xvc->xvc_sc, NULL, exp, xvc->xvc_text + xvc->xvc_text_fill,
	  xvc->xvc_text_len - xvc->xvc_text_fill, &fill);
    }
  THROW_CODE
    {
      err = (caddr_t) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR);
    }
  END_CATCH;
  if (err)
    sqlr_resignal (err);
  xvc->xvc_text_fill += fill;
}


void xmlg_quote_dotted (xv_context_t * xvc, caddr_t name)
{
  int fill = 0;
/* The trick with passing shifted xvc_text and zero fill is made
in order to relax the check for expression length inside sqlc_exp_print. */
  sqlc_quote_dotted (xvc->xvc_text + xvc->xvc_text_fill, xvc->xvc_text_len - xvc->xvc_text_fill,
      &fill, name);
  xvc->xvc_text_fill += fill;
}


void
xmlg_pk_args_where (xv_context_t * xvc, xv_join_elt_t * xj)
{
  int nth = 0, n_parts;
  dbe_table_t *tb = sch_name_to_table (isp_schema (xvc->xvc_qi->qi_space), xj->xj_table);
  if (!tb)
    return;
  xmlg_printf (xvc, " where ");
  n_parts = BOX_ELEMENTS (xj->xj_pk);
  DO_BOX (caddr_t, col_name, nth, xj->xj_pk)
  {
    if (nth > 0)
      xmlg_printf (xvc, " and ");
/* IvAn/CreateXmlView/000904 */
    xmlg_printf (xvc, "((\"%s\" = pk_%u) or (\"%s\" is null and pk_%u is null))", col_name, nth, col_name, nth);
  }
  END_DO_BOX;
}


void
xmlg_join_attribute (xv_context_t * xvc, xj_col_t * xc, int nth, dk_set_t map,
		int pk_args, int depth, int inx, int make_xte, caddr_t full_name)
{
  ST *exp = (ST *) t_box_copy_tree ((caddr_t) xc->xc_exp);
  char name[20];

  xv_join_elt_t * xj = xc->xc_relationship;
  xmlg_printf (xvc, "\ndeclare cr_attr%u_%u cursor for\n  select ", nth, inx);
  xmlg_exp_print (xvc, xc->xc_exp);
  xmlg_printf (xvc, " from ");
  xmlg_quote_dotted (xvc, xj->xj_table);
  xmlg_printf (xvc, " \"%s\" ", xj->xj_prefix);
/* it's necessary to adopt it for attribute
        if (pk_args) / *if creation of the procedure to fetch attribute's value* /
          {
            inx = 0;
	    DO_BOX (xj_col_t *, xc, inx, xj->xj_mp_schema->xj_parent_cols) / *inserting in the map* /
	    {
	      ST *exp = (ST *) t_box_copy_tree ((caddr_t) xc);
	      char name[20];
	      sprintf (name, "pk_%u", inx++);
	      t_set_push (&map, (void *) t_box_string (name));
	      t_set_push (&map, exp);
	    }
	    END_DO_BOX;
          }
*/
  if (pk_args)
    xmlg_pk_args_where (xvc, xj);
  else if (xj->xj_filter || xj->xj_join_cond)
    {
      xmlg_printf (xvc, " where (");
      if (xj->xj_filter)
	xmlg_exp_print (xvc, xj->xj_filter);
      if (xj->xj_join_cond)
	{
	  if (xj->xj_filter)
	    xmlg_printf (xvc, ") and (");
	  xvc->xvc_sc->sc_exp_print_cd = (void *) map;
	  xmlg_exp_print (xvc, xj->xj_join_cond);
	}
      xmlg_printf (xvc, ")");
    }
/*declare*/
  xmlg_printf (xvc, ";\n  declare ");
  snprintf (name, sizeof (name), "v_attr%u_%u", nth, inx);
  xmlg_printf (xvc, "%s varchar;", name);
  if (ST_COLUMN (exp, COL_DOTTED) && !exp->_.col_ref.prefix)
    exp->_.col_ref.prefix = t_box_copy (xj->xj_prefix);
  t_set_push (&map, (void *) t_box_string (name));
  t_set_push (&map, exp);

/*fetch*/
  if (make_xte)
    {
      xmlg_printf (xvc, "\n  declare  _out varchar;");
      xmlg_printf (xvc, "\n  _out := string_output();");
      if (!pk_args)
        xmlg_printf (xvc, "\n  declare v_%s varchar;", full_name);
    }

  xmlg_printf (xvc, "\n  declare i integer; i:=1; whenever not found goto done_attr%u;"
      "\n  open cr_attr%u_%u;"
      "\n  while (i) {"
      "\n    fetch cr_attr%u_%u into ", nth, nth, inx, nth, inx);
  xmlg_printf (xvc, "v_attr%u_%u;\n ", nth, inx);
/*values*/
  xmlg_printf (xvc, " if (i>1) { http (' ', _out);} ");
  if (xc->xc_prefix)
    xmlg_printf (xvc, " http ('%s', _out);", xc->xc_prefix);
  if (make_xte)
    {
      xmlg_printf (xvc, "\n http_value (cast (v_attr%u_%u as varchar), 0,  _out);", nth, inx);
    }
  else
    {
      xmlg_printf (xvc, " http_value (v_attr%u_%u, 0, _out);", nth, inx);
    }

  xmlg_printf (xvc, " i:=i+1;");
  xmlg_printf (xvc, "\n  }"
	"\n  done_attr%u: ;\n", nth);
  if (make_xte && !pk_args)
/*    xmlg_printf (xvc, " xte_node (xte_head (UNAME'%s'), string_output_string (_out));", full_name, nth, inx);*/
    xmlg_printf (xvc, " v_%s := string_output_string (_out);\n", full_name);

  if (!pk_args && !make_xte)
    xmlg_printf (xvc, "http ('\"', _out);");
}


void
xmlg_start_tag (xv_context_t * xvc, xv_join_elt_t * xj, int nth, dk_set_t map, int depth)
{
  int nsidx;
  int first = 1;
  int inx;
  xml_view_nsdef_t ** namespaces;
  xml_view_t * tree = xvc->xvc_tree;
  namespaces = tree->xv_namespaces;

  xmlg_printf (xvc, "\n--(Begin xmlg_start_tag %s nth=%u depth=%u)\n", xj->xj_element, nth, depth);
  if(depth>=NUMBEROF_tag_indents)
    depth=NUMBEROF_tag_indents-1;

  xmlg_printf (xvc, "  if (_out = 2) {");
  xmlg_printf (xvc, " result (vector(null, %u, '%s', 0, null, null, vector(", nth, xj->xj_element);
  DO_BOX (xj_col_t *, xc, inx, xj->xj_cols)
  {
    if (!(XV_XC_ATTRIBUTE & xc->xc_usage))
      continue;
    if (NULL != xc->xc_relationship) /*!!! Explicit bug here: should be a separate code for such attrs */
      continue;
    XVC_COMMA (xvc, first);
    xmlg_printf (xvc, "UNAME'%s', v%u_%u", xc->xc_xml_name, nth, inx);
  }
      END_DO_BOX;
  xmlg_printf (xvc, ")));");
  xmlg_printf (xvc, "}\n else {\n");
  /* Opening a tag */
  xmlg_printf (xvc, " http ('<%s', _out);", xj->xj_element);
  if (nth==0)
    {
      DO_BOX (xml_view_nsdef_t *, nsdef, nsidx, namespaces)
      {
	if (nsdef)
          {
	    if (strcmp (nsdef->xvns_prefix, "xmlns"))
	      xmlg_printf (xvc, " http (' xmlns:%s=\"%s\"', _out); ", nsdef->xvns_prefix, nsdef->xvns_uri);
	    else
	      xmlg_printf (xvc, " http (' xmlns=\"%s\"', _out); ", nsdef->xvns_uri);
	  }
      }
      END_DO_BOX;
      xmlg_printf (xvc, " http (' xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\"', _out); ");
    }
  DO_BOX (xj_col_t *, xc, inx, xj->xj_cols)
  {
    if (!(XV_XC_ATTRIBUTE & xc->xc_usage))
      continue;
    xmlg_printf (xvc, " http (' %s=\"', _out);", xc->xc_xml_name);
    if (!xc->xc_relationship)
      {
	if (xc->xc_prefix)
	  xmlg_printf (xvc, " http ('%s', _out);", xc->xc_prefix);
        xmlg_printf (xvc, " http_value (v%u_%u, 0, _out); http ('\"', _out);", nth, inx);
      }
    else /*attribute from another table*/
      xmlg_join_attribute (xvc, xc, nth, map, 0, depth, inx, 0, NULL);
  }
  END_DO_BOX;
  xmlg_printf (xvc, " http ('>', _out);");
  DO_BOX (xj_col_t *, xc, inx, xj->xj_cols)
  {
    if (!(XV_XC_SUBELEMENT & xc->xc_usage))
      continue;
    xmlg_printf (xvc, " if (v%u_%u is NULL) { http ('<%s xsi:nil=\"true\"/>', _out); } \n"
      " else { http ('<%s>', _out); http_value (v%u_%u, 0, _out); http ('</%s>', _out);}\n",
      nth, inx, xc->xc_xml_name, xc->xc_xml_name, nth, inx, xc->xc_xml_name);
  }
  END_DO_BOX;
  xmlg_printf (xvc, "\n  }");
  xmlg_printf (xvc, "\n--(End xmlg_start_tag %s nth=%u depth=%u)\n", xj->xj_element, nth, depth);
}


void
xmlg_end_tag (xv_context_t * xvc, xv_join_elt_t * xj, int depth)
{
  xmlg_printf (xvc, "\n--(Begin xmlg_end_tag %s depth=%u)\n", xj->xj_element, depth);
  if(depth>=NUMBEROF_tag_indents)
    depth=NUMBEROF_tag_indents-1;
  xmlg_printf (xvc, " if (_out <> 2) { http ('</%s>', _out); }", xj->xj_element);
  xmlg_printf (xvc, "\n--(End xmlg_end_tag %s depth=%u)\n", xj->xj_element, depth);
}


void
xmlg_start_tag_xmlview (xv_context_t * xvc, xv_join_elt_t * xj, int nth, dk_set_t map, int acc_nth, int depth)
{
  int inx;
  int child_count = 0;
  caddr_t default_namespace = xv_get_default_namespace (xvc);
  caddr_t full_name = xv_get_name_with_nsprefix (xvc, xj->xj_element, 0, default_namespace);
  xmlg_printf (xvc, "\n--(Begin xmlg_start_tag_xmlview %s nth=%u depth=%u)\n", xj->xj_element, nth, depth);

      if (xj->xj_mp_schema && xj->xj_mp_schema->xj_is_constant)
	{
	  xmlg_printf (xvc, "\n  declare head_%s any;", xj->xj_element);
	  xmlg_printf (xvc, "\n  head_%s := xte_head (UNAME'%s'); ", xj->xj_element, xj->xj_element);
	  goto print_ending_comment; /* see below */
	}
      DO_BOX (xj_col_t *, xc, inx, xj->xj_cols)
      {
	if (!(XV_XC_ATTRIBUTE & xc->xc_usage))
	  continue;
	if (xc->xc_relationship)
          {
	    caddr_t col_full_name = xv_get_name_with_nsprefix (xvc, xc->xc_xml_name, 1, default_namespace);
            xmlg_join_attribute (xvc, xc, nth, map, 0, depth, inx, 1, col_full_name);
	  }
      }
      END_DO_BOX;
      xmlg_printf (xvc, "\n  head_%u := xte_head (UNAME'%s' ", nth+1, full_name);
      DO_BOX (xj_col_t *, xc, inx, xj->xj_cols)
      {
	caddr_t col_full_name;
	if (!(XV_XC_ATTRIBUTE & xc->xc_usage))
	  continue;
	col_full_name = xv_get_name_with_nsprefix (xvc, xc->xc_xml_name, 1, default_namespace);
	if (!xc->xc_relationship)
          {
            if (xc->xc_prefix)
	      {
		xmlg_printf (xvc, ", UNAME'%s', concat('%s', cast (v%u_%u as varchar))", col_full_name, xc->xc_prefix, nth, inx);
	      }
            else
   	      xmlg_printf (xvc, ", UNAME'%s', cast (v%u_%u as varchar)", col_full_name, nth, inx);
	  }
	else /*attribute from another table*/
	  {
	    xmlg_printf (xvc, ", UNAME'%s', v_%s", col_full_name, col_full_name);
          }
      }
      END_DO_BOX;
      xmlg_printf (xvc, ");");
      DO_BOX (xj_col_t *, xc, inx, xj->xj_cols)
      {
        caddr_t col_full_name;
	if (!(XV_XC_SUBELEMENT & xc->xc_usage))
	  continue;
        col_full_name = xv_get_name_with_nsprefix (xvc, xc->xc_xml_name, 0, default_namespace);
        child_count++;
       	xmlg_printf (xvc, "\n  declare node_%u_%u_%u any;\n"
                "\n  if (v%u_%u is NULL)\n    {\n      node_%u_%u_%u := xte_node (xte_head (UNAME'%s', UNAME'http://www.w3.org/2001/XMLSchema-instance:nil', 'true'));\n    }"
		"\n  else\n    {\n      node_%u_%u_%u := xte_node (xte_head (UNAME'%s'), cast (v%u_%u as varchar));\n    }\n",
		nth+1, nth, inx,
		nth, inx, nth+1, nth, inx, col_full_name,
		nth+1, nth, inx, col_full_name, nth, inx);
      }
      END_DO_BOX;

      for (inx = 0; inx < child_count; inx ++)
	{
          xmlg_printf (xvc, "\n  xte_nodebld_acc (acc_%u, node_%u_%u_%u);", nth+1, nth+1, nth, inx);
	}

print_ending_comment:
  xmlg_printf (xvc, "\n--(End xmlg_start_tag_xmlview %s nth=%u depth=%u)\n", xj->xj_element, nth, depth);
}


void
xmlg_end_tag_xmlview (xv_context_t * xvc, xv_join_elt_t * xj, int nth, int acc_nth, int depth, int simple_subelement)
{
  xmlg_printf (xvc, "\n--(Begin xmlg_end_tag_xmlview %s nth=%u acc_nth=%u depth=%u, simple_subelement=%u)\n", xj->xj_element, nth, acc_nth, depth, simple_subelement);
    if (simple_subelement)
      {
	xmlg_printf (xvc, "\n  declare acc_%s any;\n  xte_nodebld_init(acc_%s);\n"
		" xte_nodebld_acc (acc_%s, cast (string_output_string (_out) as varchar));",
		xj->xj_element, xj->xj_element, xj->xj_element);
	xmlg_printf (xvc, "\n  xte_nodebld_final (acc_%s, head_%u);", xj->xj_element, nth+1);
	xmlg_printf (xvc, " xte_nodebld_acc (acc_%u, acc_%s);\n", acc_nth, xj->xj_element);
	goto print_ending_comment; /* see below */
      }
    if (xj->xj_mp_schema && xj->xj_mp_schema->xj_is_constant)
      {
	xmlg_printf (xvc, " acc_%s := acc_%u;", xj->xj_element, acc_nth);
	xmlg_printf (xvc, " xte_nodebld_final (acc_%s, head_%s);\n", xj->xj_element, xj->xj_element);
	xmlg_printf (xvc, " xte_nodebld_init (acc_%u);", acc_nth);
	xmlg_printf (xvc, " xte_nodebld_acc (acc_%u, acc_%s);\n", acc_nth, xj->xj_element);
	goto print_ending_comment; /* see below */
      }

      xmlg_printf (xvc, " xte_nodebld_final (acc_%u, head_%u);\n", nth+1, nth+1);
      xmlg_printf (xvc, " xte_nodebld_acc (acc_%u, acc_%u); ", acc_nth, nth+1);

print_ending_comment:
  xmlg_printf (xvc, "\n--(End xmlg_end_tag_xmlview %s nth=%u acc_nth=%u depth=%u, simple_subelement=%u)\n", xj->xj_element, nth, acc_nth, depth, simple_subelement);
}


void xmlg_join_loop (xv_context_t * xvc, xv_join_elt_t * xj, int nth, dk_set_t map,
    int pk_args, int http_out,
    int depth, int head_nth, int make_xte);

/*mapping schema*/
void
xmlg_join_simple_loop (xv_context_t * xvc, xv_join_elt_t * xj, int nth, dk_set_t map,
    int pk_args, int http_out,
    int depth, int *count_addition, int head_nth, int make_xte, int simple_subelement)
{
  int inx;
  caddr_t full_name = NULL;
  xmlg_printf (xvc, "\n--(Begin xmlg_join_simple_loop %s nth=%u pk_args=%u http_out=%u depth=%u head_nth=%u)\n",
     xj->xj_element, nth, pk_args, http_out, depth, head_nth );
  if (make_xte) /*xquery. tag*/
    {
      caddr_t default_namespace = xv_get_default_namespace (xvc);
      full_name = xv_get_name_with_nsprefix (xvc, xj->xj_element, 0, default_namespace);
      if (simple_subelement)
	{
	  xmlg_printf (xvc, " xte_nodebld_acc (acc_%u, cast (string_output_string (_out) as varchar));\n", head_nth);
        }
      DO_BOX (xj_col_t *, xc, inx, xj->xj_cols)
      {
	if (!(XV_XC_ATTRIBUTE & xc->xc_usage))
	  continue;
	if (xc->xc_relationship)
          {
	    caddr_t full_name = xv_get_name_with_nsprefix (xvc, xc->xc_xml_name, 1, default_namespace);
            xmlg_join_attribute (xvc, xc, nth, map, 0, depth, inx, make_xte, full_name);
	  }
      }
      END_DO_BOX;

      xmlg_printf (xvc, " declare head_%s any;\n", full_name);
      xmlg_printf (xvc, " head_%s := xte_head (UNAME'%s' ", full_name, full_name);

      DO_BOX (xj_col_t *, xc, inx, xj->xj_cols)
      {
        caddr_t full_name;
	if (!(XV_XC_ATTRIBUTE & xc->xc_usage))
	  continue;
	full_name = xv_get_name_with_nsprefix (xvc, xc->xc_xml_name, 1, default_namespace);
	if (!xc->xc_relationship)
          {
   	    xmlg_printf (xvc, ", UNAME'%s', cast (v%u_%u as varchar)", full_name, nth, (*count_addition)++);
	  }
	else /*attribute from another table*/
	  {
	    xmlg_printf (xvc, ", UNAME'%s', v_%s", full_name, full_name);
          }
      }
      END_DO_BOX;
      xmlg_printf (xvc, ");\n");
    }
/*namespaces!!!!*/
  else
    {
      xmlg_printf (xvc, " http ('<%s', _out); ", xj->xj_element);
      DO_BOX (xj_col_t *, xc, inx, xj->xj_cols)
      {
	if (!(XV_XC_ATTRIBUTE & xc->xc_usage))
	  continue;
	xmlg_printf (xvc, " http (' %s=\"', _out);", xc->xc_xml_name);
	if (!xc->xc_relationship)
	  {
	    if (xc->xc_prefix)
	      xmlg_printf (xvc, " http ('%s', _out);", xc->xc_prefix);
	    xmlg_printf (xvc, " http_value (v%u_%u, 0, _out); http ('\"', _out);\n", nth, (*count_addition)++);
	  }
	else /*attribute from another table*/
	  {
	    xmlg_join_attribute (xvc, xc, nth, map, 0, depth, inx, 0, NULL);
	  }
      }
      END_DO_BOX;
      xmlg_printf (xvc, " http ('>', _out);");
      xmlg_printf (xvc, " http_value (v%u_%u, 0, _out);", nth, (*count_addition)++);/*simple subelement value*/
    }


  if (NULL != xj->xj_children)
    {
      if (make_xte) /*xquery*/
	{
          xmlg_printf (xvc, "\n  declare acc_%u any;"
                              "  xte_nodebld_init(acc_%u);", (int) (ptrlong) xj->xj_prefix, (int) (ptrlong) xj->xj_prefix);
/*                              "\n  xte_nodebld_init(acc_%u);", nth+1, nth+1);*/
/*simple subelement value*/
          xmlg_printf (xvc, "\n xte_nodebld_acc (acc_%u, cast (v%u_%u as varchar)); ", (int) (ptrlong) xj->xj_prefix, nth, (*count_addition)++);
        }
      DO_BOX (xv_join_elt_t *, xc, inx, xj->xj_children)
      {
	if (xc->xj_mp_schema->xj_same_table)
	  xmlg_join_simple_loop (xvc, xc, nth, map, 0, http_out, depth, count_addition,
                                 (int) (ptrlong) xj->xj_prefix, make_xte, 0);
	else
	  {
	    inx = 0;
	    DO_BOX (ST *, c, inx, xj->xj_mp_schema->xj_parent_cols) /*inserting in the map*/
	    {
	      dk_set_t  map_tmp = map;
	      while (map_tmp)
		{
		  if (box_equal ((caddr_t) map_tmp->data, (caddr_t) c))
		    {
		      ST * data = (ST*) map_tmp->data;
		      caddr_t name = (caddr_t) (data->_.col_ref.name);
		      ST * exp = (ST *) t_list (3, COL_DOTTED, t_box_copy(xj->xj_prefix), name);
		      t_set_push (&map, (void *) t_box_string ((char *) map_tmp->next->data));
		      t_set_push (&map, exp);
		    }
		  map_tmp = map_tmp->next->next;
		}
	    }
	    END_DO_BOX;
	    xmlg_join_loop (xvc, xc, nth + 1 + inx * 1000, map, 0, http_out, depth+1, (int) (ptrlong) xj->xj_prefix, make_xte);
	  }
      }
      END_DO_BOX;
      if (make_xte) /*xquery*/
	{
	  xmlg_printf (xvc, "\n  xte_nodebld_final(acc_%u, head_%s);\n",
          xj->xj_prefix, full_name);
          xmlg_printf (xvc, "  xte_nodebld_acc (acc_%u, acc_%u); ", head_nth, (int) (ptrlong) xj->xj_prefix);
	}
    }

  if (!make_xte)
    xmlg_printf (xvc, " http ('</%s>', _out);\n", xj->xj_element);
  else if (NULL == xj->xj_children)/*xquery*/
    {
      xmlg_printf (xvc, " declare acc_%s any;\n xte_nodebld_init(acc_%s);\n"
		" xte_nodebld_acc (acc_%s, cast (v%u_%u as varchar));\n",
                  full_name, full_name, full_name, nth, (*count_addition)++);
      xmlg_printf (xvc, " xte_nodebld_final (acc_%s, head_%s);\n", full_name, full_name);
      xmlg_printf (xvc, " xte_nodebld_acc (acc_%u, acc_%s);\n", head_nth, full_name);
    }
  xmlg_printf (xvc, "\n--(End xmlg_join_simple_loop %s nth=%u pk_args=%u http_out=%u depth=%u head_nth=%u)\n",
     xj->xj_element, nth, pk_args, http_out, depth, head_nth );
}

/*end mapping schema*/

void
xmlg_join_loop (xv_context_t * xvc, xv_join_elt_t * xj, int nth, dk_set_t map,
    int pk_args, int http_out, int depth, int head_nth, int make_xte)
{
  dbe_table_t *elt_tb;
  char *target_tb;
  int xjinx, first = 1, inx;
  int count = 0; /*mapping schema. Counter of the columns to fetch*/
  int count_addition = 0; /*mapping schema. Counter of the columns to fetch for subelement from the same table and others*/
  int *ref_count_addition = &count_addition; /*mapping schema*/
  dk_set_t map_select = NULL;/*11.03.03 fields in select*/
  dk_set_t key_fields_map = NULL;/*11.03.03 Key fields  if they would be absent in select*/
  int simple_subelement = 0;
  int following_join = 0;
  /*DELME: int only_outer_children = 1;*/

   xmlg_printf (xvc, "\n--(Begin xmlg_join_loop %s nth=%u pk_args=%u http_out=%u depth=%u head_nth=%u)\n",
     xj->xj_element, nth, pk_args, http_out, depth, head_nth );
  /* For functions like sqlc_is_pass_through_function, called from sqlc_exp_print */
  if (NULL == sqlc_client())
    {
      sqlc_set_client(xvc->xvc_qi->qi_client);
    }

/*mapping schema ????*/
  if (xj->xj_mp_schema && xj->xj_mp_schema->xj_is_constant)
    {
      /*open the tag of the constant element*/
      if (make_xte) /*xquery*/
	{
          xmlg_printf (xvc, "\n  declare acc_%s any;"
                              "  xte_nodebld_init(acc_%s);", xj->xj_element, xj->xj_element);
	  xmlg_start_tag_xmlview (xvc, xj, nth, map, head_nth, depth);
	}
      else
	xmlg_start_tag (xvc, xj, nth, map, depth); /*tag*/
      DO_BOX (xv_join_elt_t *, c, xjinx, xj->xj_children)
      {
        if (pk_args && xj->xj_table) /*if xj is a subelement, not a root*/
          {
            inx = 0;
	    DO_BOX (xj_col_t *, xc, inx, xj->xj_mp_schema->xj_parent_cols) /*inserting in the map*/
	    {
	      ST *exp = (ST *) t_box_copy_tree ((caddr_t) xc);
	      char name[20];
	      snprintf (name, sizeof (name), "pk_%u", inx++);
	      t_set_push (&map, (void *) t_box_string (name));
	      t_set_push (&map, exp);
	    }
	    END_DO_BOX;
          }
        if (xj->xj_table) /* if xj is not a root*/
	  xmlg_join_loop (xvc, c, nth, map, 0, http_out, depth, head_nth, make_xte);
        else /*if xj is a root*/
	  xmlg_join_loop (xvc, c, nth, map, 1, http_out, depth, head_nth, make_xte);
      }
      END_DO_BOX;
      /*close the tag of the constant element*/
      if (make_xte) /*xquery*/
	{
          /* if (NULL == xj->xj_children)/ *xquery*/
            xmlg_end_tag_xmlview (xvc, xj, nth, head_nth, ((NULL != xj->xj_children) ? (depth) : 0), simple_subelement);
	}
      else
	xmlg_end_tag (xvc, xj, ((NULL != xj->xj_children) ? (depth) : 0));
      return;
    }
/*end mapping schema*/

  if (!xj->xj_table)
    {
      DO_BOX (xv_join_elt_t *, c, xjinx, xj->xj_children)
      {
	xmlg_join_loop (xvc, c, nth + 1 + xjinx * 1000, map, 0, http_out, depth, nth+1, make_xte);
      }
      END_DO_BOX;
      return;
    }
  xvc->xvc_sc->sc_exp_print_hook = xmlg_join_col;
  xvc->xvc_sc->sc_exp_print_cd = NULL;

  xmlg_printf (xvc, "declare cr_%u cursor for\n  select ", nth); /*Print column names  in the 'select statement (attributes) */
  DO_BOX (xj_col_t *, xc, inx, xj->xj_cols)
  {
/*mapping schema*/
    if (!xc->xc_relationship)
      {
/*end mp*/
	XVC_COMMA (xvc, first);
	xmlg_exp_print (xvc, xc->xc_exp);
	/*add to the list of fields*/
	dk_set_push (&map_select, (void *) box_string (xc->xc_exp->_.col_ref.name));
      }/*mapping schema*/
    else
      following_join = 1;
  }
  END_DO_BOX;

/*mapping schema.*/ /*Print in the 'select statement'*/
  if (xj->xj_mp_schema)
    {
      /*Print column name (element mapped to column from the parent table) in the 'select statement'*/
      if (xj->xj_mp_schema->xj_same_table)
        {
	  XVC_COMMA (xvc, first);
	  xmlg_exp_print (xvc, xj->xj_mp_schema->xj_column);
 	  /* add to the list of the fields*/
	  if (NULL != xj->xj_children)
	   {
	     dk_set_push (&map_select, (void *) box_string (xj->xj_mp_schema->xj_column->_.col_ref.name));
	   }
	}

      /* element annotated by sql:limit-field. Print column names in the 'select statement'
	(element annotated by sql:limit-field)*/
      if (xj->xj_mp_schema->xj_limit_field)
	{
	  XVC_COMMA (xvc, first);
	  xmlg_exp_print (xvc, xj->xj_mp_schema->xj_column);
	  xmlg_printf (xvc, ", ");
	  xmlg_exp_print (xvc, xj->xj_mp_schema->xj_limit_field);
	  /* add to the list of fields*/
	  if (NULL != xj->xj_children)
	    {
	      dk_set_push (&map_select, (void *) box_string (xj->xj_mp_schema->xj_column->_.col_ref.name));
	      dk_set_push (&map_select, (void *) box_string (xj->xj_mp_schema->xj_limit_field->_.col_ref.name));
	    }
	}

	/*subelements form the same table.
	  Print column names  in the 'select statement (subelements of the simple subelements)*/
      DO_SET (ST *, xc, &xj->xj_mp_schema->xj_child_cols)
      {
	XVC_COMMA (xvc, first);
	xmlg_exp_print (xvc, xc);
        /*add to the list of fields*/
	if (NULL != xj->xj_children)
	  {
	    dk_set_push (&map_select, (void *) box_string (xc->_.col_ref.name));
	  }
      }
      END_DO_SET();
    }

/* Key fields addition if it's necessary*/
  if (xj->xj_children || following_join)
    {
      _DO_BOX (inx, xj->xj_pk)
	{
    int isnot_in_select = 1;

    dk_set_t map_tmp = map_select;
    while (map_tmp && isnot_in_select)
     {
       if (box_equal ((caddr_t) xj->xj_pk[inx], (caddr_t) (map_tmp->data)))
         {
 	   isnot_in_select = 0;
         }
       map_tmp = map_tmp->next;
     }
/*
	DO_SET (caddr_t, xc, &map_select)
        {
	  if (box_equal ((caddr_t) xj->xj_pk[inx], (caddr_t) xc))
            isnot_in_select = 0;
        }
        END_DO_SET ();
*/
    if (isnot_in_select)
      {
        ST * col_ref = (ST *) list (3, COL_DOTTED, NULL, box_string (xj->xj_pk[inx]));
	XVC_COMMA (xvc, first);
	xmlg_exp_print (xvc, col_ref);
	if (ST_COLUMN (col_ref, COL_DOTTED) && !col_ref->_.col_ref.prefix)
	  col_ref->_.col_ref.prefix = box_copy (xj->xj_prefix);
	dk_set_push (&key_fields_map, col_ref);
      }
  }
  END_DO_BOX;
    }
/*clear map_select*/
  {
    caddr_t st;
    while (NULL != (st = (caddr_t) dk_set_pop (&map_select)))
      {
	dk_free_tree (st);
      }
  }

/*end mapping schema*/

  xmlg_printf (xvc, " from ");
  xmlg_quote_dotted (xvc, xj->xj_table);
  xmlg_printf (xvc, " \"%s\"", xj->xj_prefix);
  if (pk_args)
    xmlg_pk_args_where (xvc, xj);
  else if (xj->xj_filter || xj->xj_join_cond)
    {
      xmlg_printf (xvc, " where (");
      if (xj->xj_filter)
	xmlg_exp_print (xvc, xj->xj_filter);
      if (xj->xj_join_cond)
	{
	  if (xj->xj_filter)
	    xmlg_printf (xvc, ") and (");
	  xvc->xvc_sc->sc_exp_print_cd = (void *) map;
	  xmlg_exp_print (xvc, xj->xj_join_cond);
	}
      xmlg_printf (xvc, ")");
    }
  xmlg_printf (xvc, ";\n  declare ");
  first = 1;
  DO_BOX (xj_col_t *, xc, inx, xj->xj_cols) /*Declare variables (attributes)*/
  {
/*mapping schema*/
    if (!xc->xc_relationship)
      {
/*end mp*/
	ST *exp = (ST *) t_box_copy_tree ((caddr_t) xc->xc_exp);
	char name[20];
	XVC_COMMA (xvc, first);
	snprintf (name, sizeof (name), "v%u_%u", nth, inx);
	xmlg_printf (xvc, "%s", name);
	if (ST_COLUMN (exp, COL_DOTTED) && !exp->_.col_ref.prefix)
	  exp->_.col_ref.prefix = t_box_copy (xj->xj_prefix);
	t_set_push (&map, (void *) t_box_string (name));
	t_set_push (&map, exp);
	count++; /*mapping schema. Evaluate a number of the attributes*/
      }/*mapping schema*/
  }
  END_DO_BOX;

/*mapping schema*/
  count_addition = count;
/* subelements form the same table. Declare variables (simple subelements).*/
  if (xj->xj_mp_schema)
    {
      if (xj->xj_mp_schema->xj_same_table)
	{
          ST *exp = (ST *) t_box_copy_tree ((caddr_t) xj->xj_mp_schema->xj_column);
          char name[20];
          XVC_COMMA (xvc, first);
          snprintf (name, sizeof (name), "v%u_%u", nth,   count_addition++);
          xmlg_printf (xvc, " %s ", name);
          if (ST_COLUMN (exp, COL_DOTTED) && !exp->_.col_ref.prefix)
            exp->_.col_ref.prefix = t_box_copy (xj->xj_prefix);
          t_set_push (&map, (void *) t_box_string (name));
          t_set_push (&map, exp);
	}

/*element annotated by sql:limit-field. Declare variables (element annotated by sql:limit-field)*/
      if (xj->xj_mp_schema->xj_limit_field)
	{
	  /* column name*/
	  ST *col = (ST *) t_box_copy_tree ((caddr_t) xj->xj_mp_schema->xj_column);
	  ST *limit_field = (ST *) t_box_copy_tree ((caddr_t) xj->xj_mp_schema->xj_limit_field);
	  char name[20];
	  XVC_COMMA (xvc, first);
	  snprintf (name, sizeof (name), "v%u_%u", nth, count_addition);
	  xmlg_printf (xvc, " %s ", name);
	  if (ST_COLUMN (col, COL_DOTTED) && !col->_.col_ref.prefix)
	    col->_.col_ref.prefix = t_box_copy (xj->xj_prefix);
	  t_set_push (&map, (void *) t_box_string (name));
	  t_set_push (&map, col);
	  count_addition++;
	  /*limit-field name*/
	  xmlg_printf (xvc, ", ");
	  snprintf (name, sizeof (name), "v%u_%u", nth,   count_addition);
	  xmlg_printf (xvc, " %s ", name);
	  if (ST_COLUMN (limit_field, COL_DOTTED) && !limit_field->_.col_ref.prefix)
	    limit_field->_.col_ref.prefix = t_box_copy (xj->xj_prefix);
	  t_set_push (&map, (void *) t_box_string (name));
	  t_set_push (&map, limit_field);
	  count_addition++;
	}
/*Declare variables (attributes) of the subelement from the same table (subelements of the simple subelements)*/
      DO_SET (ST *, xc, &xj->xj_mp_schema->xj_child_cols)
      {
	ST *exp = (ST *) t_box_copy_tree ((caddr_t) xc);
	char name[20];
	XVC_COMMA (xvc, first);
	snprintf (name, sizeof (name), "v%u_%u", nth, count_addition++);
	xmlg_printf (xvc, " %s ", name);
	if (ST_COLUMN (exp, COL_DOTTED) && !exp->_.col_ref.prefix)
	  exp->_.col_ref.prefix = t_box_copy (xj->xj_prefix);
	t_set_push (&map, (void *) t_box_string (name));
	t_set_push (&map, exp);
      }
      END_DO_SET ();
    }
/*key fields addition*/
if (xj->xj_children || following_join)
  {

  DO_SET (ST *, xc, &key_fields_map)
  {
    ST *exp = (ST *) box_copy_tree ((box_t) xc);
    char name[20];
    XVC_COMMA (xvc, first);
    snprintf (name, sizeof (name), "v%u_%u", nth, count_addition++);
    xmlg_printf (xvc, "%s", name);
    t_set_push (&map, (void *) t_box_string (name));
    t_set_push (&map, exp);
  }
  END_DO_SET ();
  }
/*end mapping schema*/

  xmlg_printf (xvc, " varchar;\n  whenever not found goto done_%u;"
      "\n  open cr_%u;"
      "\n  while (1) {", nth, nth);
  if (make_xte)/*xquery*/
    {
      xmlg_printf (xvc, "\n  declare node_%u, head_%u any;", nth+1, nth+1);
      xmlg_printf (xvc, "\n declare acc_%u any; xte_nodebld_init(acc_%u);", nth+1, nth+1);
/*      xmlg_printf (xvc, "\n declare acc_t_%u any; xte_nodebld_init(acc_t_%u);", nth+1, nth+1);*/
    }
  xmlg_printf (xvc,"\n    fetch cr_%u into ", nth);

  first = 1;
  _DO_BOX (inx, xj->xj_cols) /*Print variables in 'fetch' (attributes)*/
  {
/*mapping schema*/
    if (!xj->xj_cols[inx]->xc_relationship)
      {
/*end mp*/
	XVC_COMMA (xvc, first);
	xmlg_printf (xvc, "v%u_%u", nth, inx);
      }
  }
  END_DO_BOX;

/*mapping schema*/
  count_addition = count;
/* subelements form the same table. Print variables in 'fetch' (simple subelements).*/
  if (xj->xj_mp_schema)
    {
      if (xj->xj_mp_schema->xj_same_table)
	{
	  XVC_COMMA (xvc, first);
	  xmlg_printf (xvc, "v%u_%u", nth, count_addition++);
        }

/* element annotated by sql:limit-field. Print variables in 'fetch' (annotated by sql:limit-field)*/
      if (xj->xj_mp_schema && xj->xj_mp_schema->xj_limit_field)
	{
	  XVC_COMMA (xvc, first);
	  xmlg_printf (xvc, "v%u_%u", nth, count_addition++);

	  xmlg_printf (xvc, ", ");
	  xmlg_printf (xvc, "v%u_%u", nth, count_addition++);
	}
     /*Print variables (attributes) of the subelement from the same table (subelements of the simple subelements)*/
      DO_SET (ST *, xc, &xj->xj_mp_schema->xj_child_cols)
      {
	XVC_COMMA (xvc, first);
	xmlg_printf (xvc, "v%u_%u", nth, count_addition++);
      }
      END_DO_SET ();
    }
  if (xj->xj_children || following_join)
    {
  DO_SET (ST *, xc, &key_fields_map)
  {
    XVC_COMMA (xvc, first);
    xmlg_printf (xvc, "v%u_%u", nth, count_addition++);
  }
  END_DO_SET ();

/* free key_fields_map*/
  {
    ST * st;
    while (NULL != (st = (ST *) dk_set_pop (&key_fields_map)))
      {
	dk_free_tree ((box_t) st);
      }
  }
    }
/*end mapping schema*/

  xmlg_printf (xvc, ";\n");
  elt_tb = xmls_element_table (xj->xj_element);
  if (elt_tb)
    target_tb = elt_tb->tb_name;
  else
    target_tb = "DB.DBA.VXML_ENTITY";
  if (http_out)
    {
      if (!make_xte)
	xmlg_start_tag (xvc, xj, nth, map, depth); /*head*/
      else /*xquery*/
	xmlg_start_tag_xmlview (xvc, xj, nth, map, head_nth, depth);
    }
  else
    {
      xmlg_printf (xvc, "    insert into %s (E_ID, E_LEVEL, E_NAME ",
	  target_tb);
      first = 0;
      DO_BOX (xj_col_t *, xc, inx, xj->xj_cols)
      {
	XVC_COMMA (xvc, first);
	xmlg_printf (xvc, " \"%s\" ", xc->xc_xml_name);
      }
      END_DO_BOX;
      xmlg_printf (xvc, ")\n      values (_id := xml_eid (_id, _bound, 0), _lev + %u, '%s'",
	  nth, xj->xj_element);
      _DO_BOX (inx, xj->xj_cols)
      {
	XVC_COMMA (xvc, first);
	xmlg_printf (xvc, "v%u_%u ", nth, inx);
      }
      END_DO_BOX;
      xmlg_printf (xvc, ");\n    ");
    }
/*mapping schema new. Print element value (subelement from the parent table)*/
  count_addition = count;

  if (xj->xj_mp_schema)
    {
      if (xj->xj_mp_schema->xj_same_table)
	{
	  if (make_xte) /*xquery*/
	    {
	      xmlg_printf (xvc, "\n declare _out varchar;\n  _out := string_output();\n");
              simple_subelement = 1;
            }
          xmlg_printf (xvc, " http_value (v%u_%u, 0, _out);", nth, count_addition++);
	}
/* element annotated by sql:limit-field. Print element value*/
      if (xj->xj_mp_schema->xj_limit_field)
	{
/*      xmlg_printf (xvc, " http_value (v%u_%u, 0, _out);", nth, 0);*/
          if (make_xte) /*xquery*/
	    {
	      xmlg_printf (xvc, "\n declare _out varchar;\n  _out := string_output();\n");
              simple_subelement = 1;
	    }
	  xmlg_printf (xvc, " http_value (v%u_%u, 0, _out);", nth, count_addition++);
	  if (xj->xj_children)
	    sqlr_error ("S0002", "It's not supported subelements of the element %s annotated by sql:limit-field in mapping schema", xj->xj_element);
	}
    }
/*end mapping schema*/

/* !!!  count_addition = count;*/
  if (NULL != xj->xj_children)
    {
/*
      if (make_xte) / *xquery* /
	{
          xmlg_printf (xvc, "\n  declare acc_t_%u any;"
                              "\n  xte_nodebld_init(acc_t_%u);\n", nth+1, nth+1);
        }
*/
      DO_BOX (xv_join_elt_t *, c, xjinx, xj->xj_children)
      {
/*mapping schema. subelement from the same table. Print subelement and its value*/
        if (c->xj_mp_schema && c->xj_mp_schema->xj_same_table)
	  xmlg_join_simple_loop (xvc, c, nth, map, 0, http_out, depth,
                                 ref_count_addition, nth+1, make_xte, simple_subelement);
        else
/* end mapping schema*/
	  xmlg_join_loop (xvc, c, nth + 1 + xjinx * 1000, map, 0, http_out, depth+1, nth+1, make_xte);
      }
      END_DO_BOX;
      if (make_xte) /*xquery*/
	{
	  xmlg_printf (xvc, "\n  xte_nodebld_final(acc_%u, head_%u);", nth+1, nth+1);
          xmlg_printf (xvc, "\n  xte_nodebld_acc (acc_%u, acc_%u);", head_nth, nth+1);
	}
    }

  if (http_out)
    {
      if (!make_xte)
	xmlg_end_tag (xvc, xj, ((NULL != xj->xj_children) ? (depth) : 0));
      else if (NULL == xj->xj_children)/*xquery*/
	xmlg_end_tag_xmlview (xvc, xj, nth, head_nth, ((NULL != xj->xj_children) ? (depth) : 0), simple_subelement);
    }
  xmlg_printf (xvc, "\n  }\n  done_%u: ;\n", nth);
   xmlg_printf (xvc, "\n--(End xmlg_join_loop %s nth=%u pk_args=%u http_out=%u depth=%u head_nth=%u)\n",
     xj->xj_element, nth, pk_args, http_out, depth, head_nth );
}

void
xmlg_store_proc (xv_context_t * xvc)
{
  char procname[MAX_QUAL_NAME_LEN];
  char *proc_name_start, *name_src, *name_tgt;
#ifdef XMLVIEW_DEBUG
  FILE *stream;
  char filename[MAX_QUAL_NAME_LEN+20];
#endif
  query_t *qr;
  char *tstr = box_dv_short_string (xvc->xvc_text);
  caddr_t err = NULL;
  dbg_xmlsql(("xmlg_store_proc(...,\n%s\n)", xvc->xvc_text));

  proc_name_start = strstr (xvc->xvc_text, "procedure") + strlen("procedure");
  while (proc_name_start[0] <= ' ') proc_name_start++;
  name_tgt = procname;
  for (name_src = proc_name_start; name_src[0] > ' '; name_src++)
    if ('"' != name_src[0])
      (name_tgt++)[0] = name_src[0];
  name_tgt[0] = '\0';
#ifdef XMLVIEW_DEBUG
  strcpy_ck (filename, "xmlgen/__");
  strcat_ck (filename, procname);
  strcat_ck (filename, ".sql");
  stream = fopen (filename, "wt");
  if (stream)
    {
      fwrite (xvc->xvc_text, strlen (xvc->xvc_text), 1, stream);
      fclose (stream);
    }
#endif

  qr = sql_compile (tstr, xvc->xvc_qi->qi_client, &err, SQLC_DEFAULT);

  if (!qr)
    {
#ifdef XMLVIEW_DEBUG
      stream = fopen(filename, "at");
      if (stream)
	{
	  fprintf (stream, "\n\n--Compilation has failed: %s %s\n", ERR_STATE (err), ERR_MESSAGE (err));
	  fclose (stream);
	}
#endif
      dk_free_box (tstr);
      dk_set_push (&(xvc->xvc_proc_errors), err);
      dk_set_push (&(xvc->xvc_proc_errors), box_dv_short_string (procname));
      return;
    }
  err = qr_rec_exec (qr, xvc->xvc_qi->qi_client, NULL, xvc->xvc_qi, NULL, 0);
  if (err)
    {
#ifdef XMLVIEW_DEBUG
      stream = fopen(filename, "at");
      if (stream)
	{
	  fprintf (stream, "\n\n--Execution has failed: %s %s\n", ERR_STATE (err), ERR_MESSAGE (err));
	  fclose (stream);
	}
#endif
      dk_set_push (&(xvc->xvc_proc_errors), err);
      dk_set_push (&(xvc->xvc_proc_errors), box_dv_short_string (procname));
    }
  qr_free (qr);
  dk_free_box (tstr);
}
#undef XMLVIEW_DEBUG

/*#define XMLVIEW_DEBUG  / * mapping schema*/
void
xmlg_xj_http_func_attr (xv_context_t * xvc, xj_col_t * xc, int make_xte)
{
  xv_join_elt_t * xj = xc->xc_relationship;
  int n;
  int first = 1;
  dbe_table_t *tb = sch_name_to_table (isp_schema (xvc->xvc_qi->qi_space), xj->xj_table);
#ifdef DEBUG
  memset (xvc->xvc_text, 0, xvc->xvc_text_fill);
#endif
  xvc->xvc_text_fill = 0;
  if (!tb)
    sqlr_error ("S0002", "No table %s when generating XML view procs", xj->xj_table);
  if (make_xte) /*xquery*/
    {
      xmlg_printf (xvc, "\ncreate procedure \"%s\".\"%s\".\"xte_%s_%s_%s\" (", xvc->xvc_schema, xvc->xvc_user, xvc->xvc_local_name, xj->xj_element, xj->xj_prefix);
    }
  else
    xmlg_printf (xvc, "\ncreate procedure \"%s\".\"%s\".\"http_%s_%s_%s\" (",  xvc->xvc_schema, xvc->xvc_user, xvc->xvc_local_name, xj->xj_element, xj->xj_prefix);
  for (n = 0; n < (int) BOX_ELEMENTS (xj->xj_pk); n++)
    {
      XVC_COMMA (xvc, first);
      xmlg_printf (xvc, "in pk_%u varchar ", n);
    }
  if (make_xte)/*xquery*/
    xmlg_printf (xvc, ")\n{" );
  else
    xmlg_printf (xvc, ", in _out varchar)\n{\n--no_c_escapes-\n"
		"  if (_out = 1 ) _out := string_output ();\n");
  MP_START();
  /* For functions like sqlc_is_pass_through_function, called from sqlc_exp_print */
  if (NULL == sqlc_client())
    {
      sqlc_set_client(xvc->xvc_qi->qi_client);
    }
  xvc->xvc_sc->sc_exp_print_hook = xmlg_join_col;
  xvc->xvc_sc->sc_exp_print_cd = NULL;

  xmlg_join_attribute (xvc, xc, 0, NULL, 1, 1, 0, make_xte, NULL);
  MP_DONE();
  if (make_xte) /*xquery*/
    {
      xmlg_printf (xvc, " return (string_output_string (_out)); }\n"); /*improve!!!!*/
/*
      xmlg_printf (xvc, "\n  xte_nodebld_final(acc_0, head_0);" );
      xmlg_printf (xvc, "\n  return (acc_0); }");
*/
    }
  else
    {
      xmlg_printf (xvc, "\n"
              " if (not isinteger (_out)) return (string_output_string (_out)); else return 0; }");
    }
  xmlg_store_proc (xvc);
}


void
xmlg_xj_http_func (xv_context_t * xvc, xv_join_elt_t * xj, int make_xte)
{
  int inx, n;
  int first = 1;
  dbe_table_t *tb = sch_name_to_table (isp_schema (xvc->xvc_qi->qi_space), xj->xj_table);
#ifdef DEBUG
  memset (xvc->xvc_text, 0, xvc->xvc_text_fill);
#endif
  xvc->xvc_text_fill = 0;
  if (!tb)
    sqlr_error ("S0002", "No table %s when generating XML view procs", xj->xj_table);
      if (make_xte)
        {
          xmlg_printf (xvc, "\ncreate procedure \"%s\".\"%s\".\"xte_%s_%s_%s\" (", xvc->xvc_schema, xvc->xvc_user, xvc->xvc_local_name, xj->xj_element, xj->xj_prefix);
          for (n = 0; n < (int) BOX_ELEMENTS (xj->xj_pk); n++)
            {
              XVC_COMMA (xvc, first);
              xmlg_printf (xvc, "in pk_%u varchar ", n);
            }
          xmlg_printf (xvc, ")\n{"
              "\n  declare head_0 any;"
              "\n  head_0:= xte_head (UNAME' root');\n"
                 );
#ifdef XMLVIEW_DEBUG
          xmlg_printf (xvc, "dbg_obj_print(\'%s.%s.%s_%s_%s\');\n", xvc->xvc_schema, xvc->xvc_user, xvc->xvc_local_name, xj->xj_element, xj->xj_prefix);
          for (n = 0; n < (int) BOX_ELEMENTS (xj->xj_pk); n++)
            {
              xmlg_printf (xvc, " dbg_obj_print(pk_%u);\n", n);
            }
#endif
          xmlg_printf (xvc, "\n  declare acc_0 any;\n  xte_nodebld_init(acc_0);");
          MP_START();
          xmlg_join_loop (xvc, xj, 0, NULL, 1, 1, 1, 0, make_xte);
          MP_DONE();
          xmlg_printf (xvc,
            "\n  xte_nodebld_final(acc_0, head_0);" );
#ifdef XMLVIEW_DEBUG
          xmlg_printf (xvc, " dbg_obj_print(acc_0);\n");
#endif
          xmlg_printf (xvc, "\n  return (acc_0); }");
        }
      else
        {
          xmlg_printf (xvc, "\ncreate procedure \"%s\".\"%s\".\"http_%s_%s_%s\" (", xvc->xvc_schema, xvc->xvc_user, xvc->xvc_local_name, xj->xj_element, xj->xj_prefix);
              for (n = 0; n < (int) BOX_ELEMENTS (xj->xj_pk); n++)
                {
                  XVC_COMMA (xvc, first);
                  xmlg_printf (xvc, "in pk_%u varchar ", n);
                }
              xmlg_printf (xvc, ", in _out varchar)\n{\n--no_c_escapes-\n"
                  "  if (_out = 1 ) _out := string_output ();\n");
              MP_START();
              xmlg_join_loop (xvc, xj, 0, NULL, 1, 1, 1, 0, make_xte);
              MP_DONE();
/*            }/ *mapping schema*/
          xmlg_printf (xvc, "\n"
              " if (not isinteger (_out) )return (string_output_string (_out)); else return 0; }");
        }

      xmlg_store_proc (xvc);

  if (xj->xj_children)
    {
      DO_BOX (xv_join_elt_t *, c, inx, xj->xj_children)
      {
	xmlg_xj_http_func (xvc, c, make_xte);
      }
      END_DO_BOX;
    }
/*mapping schema. Create stored procedures for attributes with join*/
  if (xj->xj_cols)
    {
      DO_BOX (xj_col_t *, c, inx, xj->xj_cols)
      {
	if (!(XV_XC_ATTRIBUTE & c->xc_usage))
	  continue;
	if (c->xc_relationship)
 	  xmlg_xj_http_func_attr (xvc, c, make_xte);
      }
      END_DO_BOX;
    }
}


void
xmlg_xj_http_func_1 (xv_context_t * xvc, xv_join_elt_t * xj, int make_xte)
{
  dbe_table_t *tb = sch_name_to_table (isp_schema (xvc->xvc_qi->qi_space), xj->xj_table);
  if (!tb)
    sqlr_error ("S0002", "No table %s when generating XML view procs", xj->xj_table);
#ifdef DEBUG
  memset (xvc->xvc_text, 0, xvc->xvc_text_fill);
#endif
  xvc->xvc_text_fill = 0;
  if (make_xte)
    {
      xmlg_printf (xvc, "\ncreate procedure \"%s\".\"%s\".\"xte_view_%s\" (", xvc->xvc_schema, xvc->xvc_user, xvc->xvc_local_name);
      xmlg_printf (xvc,")\n{\n"
          "  declare head_0 any;"
          "\n  head_0:= xte_head (UNAME' root');"
                 );
      xmlg_printf (xvc, "\n  declare acc_0 any;"
                              "\n  xte_nodebld_init(acc_0);");
      MP_START();
      xmlg_join_loop (xvc, xj, 0, NULL, 0, 1, 1, 0, make_xte);
      MP_DONE();
      xmlg_printf (xvc,
        "\n  xte_nodebld_final(acc_0, head_0);" );
      xmlg_printf (xvc, "\n  return (acc_0); }");
      xmlg_store_proc (xvc);
    }
  else
/* end alex/to generate xte_.../21.08.02 */
    {
      xmlg_printf (xvc, "\ncreate procedure \"%s\".\"%s\".\"http_view_%s\" (", xvc->xvc_schema, xvc->xvc_user, xvc->xvc_local_name);
      xmlg_printf (xvc, "inout _out varchar)\n{\n"
          "  if (_out = 1 ) _out := string_output ();\n");
      MP_START();
      xmlg_join_loop (xvc, xj, 0, NULL, 0, 1, 1, 0, make_xte);
      MP_DONE();
      xmlg_printf (xvc, "\n  if (not isinteger (_out))\n    return (string_output_string (_out)); else return 0; }");
      xmlg_store_proc (xvc);
    }
}


/* IvAn/XmlView/000810 Call of xml_view_publish() has changed. */
void
xmls_publish (query_instance_t * qi, xml_view_t * xv)
{
  xv_pub_t *xp = xv->xv_pub_opts;
  xv_metas_t *metas = (xv_metas_t *) xp->xpub_metas;
  caddr_t err = NULL;
  query_t *qr;
  qr = sql_compile_static ("DB.DBA.xml_view_publish (?, ?, ?, ?, ?, ?, ?)", qi->qi_client, &err, SQLC_DEFAULT);
  if (err)
    sqlr_resignal (err);
  err = qr_rec_exec (qr, qi->qi_client, NULL, qi, NULL, 7,
      ":0", xv->xv_full_name, QRP_STR,
      ":1", xp->xpub_path, QRP_STR,
      ":2", xp->xpub_owner, QRP_STR,
      ":3", (ptrlong) unbox (xp->xpub_persistent), QRP_INT,
      ":4", (ptrlong) unbox (xp->xpub_interval), QRP_INT,
      ":5", (ptrlong) unbox (metas->xmetas_mode), QRP_INT,
      ":6", metas->xmetas_custom_text, QRP_STR
      );
  if (err)
    {
      TRX_POISON (qi->qi_trx);
      sqlr_resignal (err);
    }
}


#define XMLS_MAX_PROC_SIZE (MAX_REMOTE_TEXT_SZ * 10)


void
xmls_proc (query_instance_t * qi, caddr_t name)
{
  int inx;
  xml_view_t *xv;
  sql_comp_t sc;
  query_t * qr = NULL;
  comp_context_t cc;
  xv_context_t xvc;
  memset (&sc, 0, sizeof (sc));
  memset (&xvc, 0, sizeof (xv_context_t));
  CC_INIT (cc, qi->qi_client);
  sc.sc_cc = &cc;
  sc.sc_store_procs = 1;
  sc.sc_client = qi->qi_client;

  xv = xmls_view_def (name);
  if (!xv)
    sqlr_new_error ("42000", "SQ178", "No XML view '%s'", name);
  xvc.xvc_qi = qi;
  xvc.xvc_sc = &sc;
  xvc.xvc_tree = xv;
  xvc.xvc_schema = xv->xv_schema;
  xvc.xvc_user = xv->xv_user;
  xvc.xvc_local_name = xv->xv_local_name;
  if (!xvc.xvc_schema || !xvc.xvc_user || !xvc.xvc_local_name)
    GPF_T;

  xj_tree_prepare (xv->xv_tree, NULL, qi, xv->xv_all_cols_as_subelements);

  ddl_commit (qi);

  semaphore_enter (parse_sem);
  sqlc_target_rds (local_rds);
  semaphore_leave (parse_sem);

  {
    static query_t *xml_view_drop_proc_qr = NULL;
    caddr_t err;
    if (NULL == xml_view_drop_proc_qr)
      xml_view_drop_proc_qr = sql_compile_static ("DB.DBA.XML_VIEW_DROP_PROCS (concat (?, '.', ?, '.', ?), 1)", bootstrap_cli, &err, SQLC_DEFAULT);
    err = qr_rec_exec (xml_view_drop_proc_qr, xvc.xvc_qi->qi_client, NULL, xvc.xvc_qi, NULL, 3,
		     ":0", xvc.xvc_schema, QRP_STR,
		     ":1", xvc.xvc_user, QRP_STR,
		     ":2", xvc.xvc_local_name, QRP_STR);
    if (NULL != err)
      sqlr_resignal (err);
  }

  xvc.xvc_text = (char *) dk_alloc (XMLS_MAX_PROC_SIZE);
  xvc.xvc_text_len = XMLS_MAX_PROC_SIZE;
  xvc.xvc_text_fill = 0;
  QR_RESET_CTX
    {
      DO_BOX (xv_join_elt_t *, c, inx, xv->xv_tree->xj_children)
	{
	  xmlg_xj_http_func (&xvc, c, 0); /*create http_...*/
	  xmlg_xj_http_func (&xvc, c, 1); /*create xte_...*/
	  if (inx == 0)
	    {
	      xmlg_xj_http_func_1 (&xvc, c, 0); /*create http_view*/
	      xmlg_xj_http_func_1 (&xvc, c, 1); /*create xte_view*/
    	    }
	}
      END_DO_BOX;
      if (NULL != xvc.xvc_proc_errors)
        {
          caddr_t proc_name, err, msg;
          while (NULL != xvc.xvc_proc_errors->next->next)
            dk_free_tree ((box_t) dk_set_pop (&(xvc.xvc_proc_errors)));
          proc_name = (caddr_t) dk_set_pop (&(xvc.xvc_proc_errors));
          err = (caddr_t) dk_set_pop (&(xvc.xvc_proc_errors));
          msg = ERR_MESSAGE (err);
          ERR_MESSAGE (err) = box_sprintf (2000,
            "Failed to create internal stored procedure '%.200s' of XML view '%.200s': %.1000s",
            proc_name, name, msg);
          dk_free_box (msg);
          dk_free_box (proc_name);
          sqlr_resignal (err);
        }
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      POP_QR_RESET;
      /* It is possible that sqlr_error is signaled when memory pool is allocated. */
      if (THR_TMP_POOL)
        MP_DONE();
      dk_free (xvc.xvc_text, XMLS_MAX_PROC_SIZE);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  dk_free (xvc.xvc_text, XMLS_MAX_PROC_SIZE);
  if (xv->xv_pub_opts)
    xmls_publish (qi, xv);
  return;
}


caddr_t
bif_xmls_proc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "xmls_proc");
  query_instance_t *qi = (query_instance_t *) qst;
  xmls_proc (qi, name);
  return 0;
}

caddr_t
bif_xmls_viewremove (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "xmls_viewremove");
  caddr_t *old_tree = (caddr_t *) id_hash_get (xml_global->xs_views, (caddr_t) &name);
  if (old_tree)
    {
      caddr_t *key_ptr = (caddr_t *)id_hash_get_key (xml_global->xs_views, (caddr_t) &name);
      caddr_t key = key_ptr[0];
      if (*old_tree)
	dk_set_push (xml_global->xs_old_views, *old_tree);
      id_hash_remove (xml_global->xs_views, (caddr_t) & name);
      dk_free_box (key); /* Was dk_free_box (key_ptr[0]); this was wrong because id_hash_remove can fill key_ptr with 0xdddddddd when in MALLOC_DEBUG */
    }
  return 0;
}

/* IvAn/ViewDTD/000718 Added */

static xv_dtd_builder_t *
xv_dtd_builder_allocate (char *view_name, char *top_el_name)
{
  xv_dtd_builder_t *res = (xv_dtd_builder_t *) dk_alloc (sizeof (xv_dtd_builder_t));
  res->xd_view_name = view_name;
  res->xd_top_el_name = top_el_name;
  res->xd_dict = NULL;
  res->xd_dict_lookup = hash_table_allocate (31);
  res->xd_output_len = 20;
  res->xd_countof_names = 0;
  return res;
}

static void
xv_dtd_builder_free (xv_dtd_builder_t * bld)
{
  hash_table_free (bld->xd_dict_lookup);
  DO_SET (xv_dtd_id_t *, id, (&bld->xd_dict))
  {
    dk_set_free (id->xdi_elements);
    dk_set_free (id->xdi_attributes);
  }
  END_DO_SET ();
  dk_set_free (bld->xd_dict);
  dk_free (bld, sizeof (xv_dtd_builder_t));
}

static xv_dtd_id_t *
xv_dtd_id_find (xv_dtd_builder_t * bld, char *new_name, int ins_allowed)
{
  xv_dtd_id_t *res_id;
  if (NULL == new_name)
    new_name = bld->xd_top_el_name;
  DO_SET (xv_dtd_id_t *, id, (&bld->xd_dict))
  {
    if (!strcmp (id->xdi_name, new_name))
      return id;
  }
  END_DO_SET ();
  if (!ins_allowed)
    GPF_T1 ("Unknown name of XML item found");
  res_id = (xv_dtd_id_t *) dk_alloc (sizeof (xv_dtd_id_t));
  res_id->xdi_name = new_name;
  res_id->xdi_elements = NULL;
  res_id->xdi_attributes = NULL;
  res_id->xdi_used_as_element = 0;
  res_id->xdi_mixed_content = 0;
  res_id->xdi_is_masked = 0;
  dk_set_push (&(bld->xd_dict), res_id);
  sethash (new_name, bld->xd_dict_lookup, res_id);
  bld->xd_countof_names++;
  return res_id;
}

static int			/* error code */
xv_dtd_load_builder (xv_dtd_builder_t * bld, xv_join_elt_t * tree)
{
  char *el_name;		/* Name of root element in \c tree */
  int col_idx;			/* index of current column in the box of all columns */
  int chld_idx;			/* index of current child in the box of all children */
  xv_dtd_id_t *tree_id = NULL;
  xv_dtd_id_t *col_id = NULL;
  el_name = (char *) (tree->xj_element);
  if (NULL == el_name)
    el_name = bld->xd_top_el_name;
  if (NULL != el_name)
    {
      tree_id = xv_dtd_id_find (bld, tree->xj_element, 1 /*=ins_allowed*/ );
      tree_id->xdi_used_as_element = 1;
      dk_set_pushnew (&(tree_id->xdi_elements), tree);
      bld->xd_output_len += (40 + 2 * (long) strlen (el_name));
    }
  DO_BOX (xj_col_t *, column, col_idx, tree->xj_cols)
  {
    if (!((XV_XC_ATTRIBUTE | XV_XC_SUBELEMENT) & column->xc_usage))
      continue;
    col_id = xv_dtd_id_find (bld, column->xc_xml_name, 1 /*=ins_allowed*/ );
    if (dk_set_member (col_id->xdi_attributes, tree))
      {
	if (XV_XC_ATTRIBUTE & column->xc_usage)
	  {
	    sqlr_error ("42001", "Can't create DTD of XML view %s: duplicate attribute name %s in element %s",
		bld->xd_view_name, col_id->xdi_name, tree_id->xdi_name);
	    return 1 /*=error*/ ;
	  }
      }
    else
      {
	dk_set_pushnew (&(col_id->xdi_attributes), tree);
      }
    if (XV_XC_SUBELEMENT & column->xc_usage)
      {
	col_id->xdi_used_as_element = 1;	/* Column is dumped as element */
	col_id->xdi_mixed_content = 1;	/* Column dump is #PCDATA element */
	bld->xd_output_len += (80 + 2 * (long) strlen (col_id->xdi_name));
      } else {
	bld->xd_output_len += (40 + (long) strlen (col_id->xdi_name));
      }
  }
  END_DO_BOX;
  DO_BOX (xv_join_elt_t *, chld, chld_idx, tree->xj_children)
  {
    xv_dtd_load_builder (bld, chld);
  }
  END_DO_BOX;
  return 0 /*=OK*/ ;
}

/*#define XV_DTD_DEBUG */

#ifdef XV_DTD_DEBUG
static void
xv_dtd_debug (xv_join_elt_t * tree, char *res, size_t tlen, int *fill)
{
  int col_idx;			/* index of current column in the box of all columns */
  int chld_idx;			/* index of current column in the box of all children */
  tailprintf (res, tlen, fill,
      "xv_join_elt_dtd(%x): xj_table=%s, xj_prefix=%s, xj_element=%s xj_all_cols_as_subelements=%u\n",
      (long) (void *) (tree),
      tree->xj_table, tree->xj_prefix, tree->xj_element, tree->xj_all_cols_as_subelements);
  DO_BOX (xj_col_t *, column, col_idx, tree->xj_cols)
  {
    if (!((XV_XC_ATTRIBUTE | XV_XC_SUBELEMENT) & xc->xc_usage))
      continue;
    tailprintf (res, tlen, fill,
	"xv_join_elt_dtd(%x)[%u]: xc_xml_name=%s, xc_usage=%x\n",
	(long) (void *) (tree), col_idx,
	column->xc_xml_name, column->xc_usage);
  }
  END_DO_BOX;
  DO_BOX (xv_join_elt_t *, chld, chld_idx, tree->xj_children)
  {
    xv_dtd_debug (chld, res, tlen, fill);
  }
  END_DO_BOX;
}
#endif

static void
xv_dtd_emit_mixed_element (xv_dtd_builder_t * bld, xv_dtd_id_t * curr_id, char *res, size_t tlen, int *fill)
{
  xv_dtd_id_t *sub_id;
  int sub_idx;			/* Unused, only for DO_BOX(...) call */
  int only_pcdata_reported;
  /* Masking of all nested elements from children ... */
  DO_SET (xv_join_elt_t *, head, &(curr_id->xdi_elements))
  {
    DO_BOX (xv_join_elt_t *, chld, sub_idx, head->xj_children)
    {
      if (NULL != (char *) (chld->xj_element))
	{
	  sub_id = xv_dtd_id_find (bld, chld->xj_element, 0 /*=!ins_allowed*/ );
	  sub_id->xdi_is_masked = 1;
	}
    }
    END_DO_BOX;
  }
  END_DO_SET ();
  /* Masking of all nested columns published as sub-elements */
  DO_SET (xv_join_elt_t *, head, &(curr_id->xdi_elements))
  {
    DO_BOX (xj_col_t *, column, sub_idx, head->xj_cols)
    {
      if (!((XV_XC_ATTRIBUTE | XV_XC_SUBELEMENT) & column->xc_usage))
        continue;
      sub_id = xv_dtd_id_find (bld, column->xc_xml_name, 0 /*=!ins_allowed*/ );
      if (XV_XC_SUBELEMENT & column->xc_usage)
	{
	  sub_id->xdi_is_masked = 1;
	}
    }
    END_DO_BOX;
  }
  END_DO_SET ();
  /* No more nested tags */
  tailprintf (res, tlen, fill, "<!ELEMENT %s (#PCDATA", curr_id->xdi_name);
  only_pcdata_reported = 1;
  DO_SET (xv_dtd_id_t *, sub_id, (&bld->xd_dict))
  {
    if (sub_id->xdi_is_masked)
      {
	tailprintf (res, tlen, fill, " | %s", sub_id->xdi_name);
	sub_id->xdi_is_masked = 0;
	only_pcdata_reported = 0;
      }
  }
  END_DO_SET ();
  tailprintf (res, tlen, fill, (only_pcdata_reported ? ") >\n" : ")* >\n"));
}

static void
xv_dtd_emit_pure_element (xv_dtd_builder_t * bld, xv_dtd_id_t * curr_id, char *res, size_t tlen, int *fill)
{
  int top_ctr = 0;
  int is_content_empty = 1;
  xv_dtd_id_t *sub_id;
  int sub_idx;			/* Unused, only for DO_BOX(...) call */
  /* Masking of all nested elements from children ... */
  DO_SET (xv_join_elt_t *, head, &(curr_id->xdi_elements))
  {
    DO_BOX (xv_join_elt_t *, chld, sub_idx, head->xj_children)
    {
      if (NULL != (char *) (chld->xj_element))
	{
	  sub_id = xv_dtd_id_find (bld, chld->xj_element, 0 /*=!ins_allowed*/ );
	  sub_id->xdi_is_masked = 1;
	  is_content_empty = 0;
	}
    }
    END_DO_BOX;
  }
  END_DO_SET ();
  /* Masking of all nested columns published as sub-elements */
  DO_SET (xv_join_elt_t *, head, &(curr_id->xdi_elements))
  {
    DO_BOX (xj_col_t *, column, sub_idx, head->xj_cols)
    {
      if (!((XV_XC_ATTRIBUTE | XV_XC_SUBELEMENT) & column->xc_usage))
        continue;
      sub_id = xv_dtd_id_find (bld, column->xc_xml_name, 0 /*=!ins_allowed*/ );
      if (XV_XC_SUBELEMENT & column->xc_usage)
	{
	  sub_id->xdi_is_masked = 1;
	  is_content_empty = 0;
	}
    }
    END_DO_BOX;
  }
  END_DO_SET ();
  /* No more nested tags */
  if (is_content_empty)
    {
      tailprintf (res, tlen, fill, "<!ELEMENT %s EMPTY>\n", curr_id->xdi_name);
    }
  else
    {
      tailprintf (res, tlen, fill, "<!ELEMENT %s ((", curr_id->xdi_name);
      DO_SET (xv_dtd_id_t *, sub_id, (&bld->xd_dict))
      {
	if (sub_id->xdi_is_masked)
	  {
	    if (top_ctr++)
	      tailprintf (res, tlen, fill, " | ");
	    tailprintf (res, tlen, fill, "%s", sub_id->xdi_name);
	    sub_id->xdi_is_masked = 0;
	  }
      }
      END_DO_SET ();
      tailprintf (res, tlen, fill, ")*) >\n");
    }
}

static void
xv_dtd_emit_attlist (xv_dtd_builder_t * bld, xv_dtd_id_t * curr_id, char *res, size_t tlen, int *fill)
{
  xv_dtd_id_t *sub_id;
  int sub_idx;			/* Unused, only for DO_BOX(...) call */
  /* Masking of all nested columns published as attributes */
  DO_SET (xv_join_elt_t *, head, &(curr_id->xdi_elements))
  {
    DO_BOX (xj_col_t *, column, sub_idx, head->xj_cols)
    {
      if (!((XV_XC_ATTRIBUTE | XV_XC_SUBELEMENT) & column->xc_usage))
        continue;
      sub_id = xv_dtd_id_find (bld, column->xc_xml_name, 0 /*=!ins_allowed*/ );
      if (XV_XC_ATTRIBUTE & column->xc_usage)
	{
	  sub_id->xdi_is_masked = 1;
	}
    }
    END_DO_BOX;
  }
  END_DO_SET ();
  /* No more attributes */
  tailprintf (res, tlen, fill, "<!ATTLIST %s", curr_id->xdi_name);
  DO_SET (xv_dtd_id_t *, sub_id, (&bld->xd_dict))
    {
      if (sub_id->xdi_is_masked)
	{
	  tailprintf (res, tlen, fill, "\n\t%s\tCDATA\t#IMPLIED", sub_id->xdi_name);
	  sub_id->xdi_is_masked = 0;
	}
    }
  END_DO_SET ();
  tailprintf (res, tlen, fill, "\t>\n");
}

caddr_t
bif_xml_view_dtd (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t view_name;
  caddr_t top_el_name = NULL;
  xml_view_t *xv;		/* view view_named as 'view_name' */
  char * res;			/* output buffer */
  caddr_t boxed_res;		/* box for long string result of function */
  int fill = 0;			/* offset of unfilled tail of res */
  xv_dtd_builder_t *bld = NULL;	/* builder of DTD, with all temporary data inside */
  view_name = bif_string_arg (qst, args, 0, "xml_view_dtd");
  if (BOX_ELEMENTS (args) > 1)
    {
      top_el_name = bif_string_arg (qst, args, 1, "xml_view_dtd");
    }
  xv = xmls_view_def (view_name);
  if (!xv)
    sqlr_new_error ("42000", "SQ179", "No XML view '%s'", view_name);
  bld = xv_dtd_builder_allocate (view_name, top_el_name);
  if (xv_dtd_load_builder (bld, xv->xv_tree) != 0 /*=OK*/ )
    {
      GPF_T1 ("Can't create DTD for a view");
    }

#ifdef XV_DTD_DEBUG
  bld->xd_output_len *= 5;
  bld->xd_output_len += 10000;
#endif
  res = (char *) dk_alloc (bld->xd_output_len);
#ifdef XV_DTD_DEBUG
  tailprintf (res, bld->xd_output_len, &fill, "<!--\n");
  xv_dtd_debug (xv->xv_tree, res, bld->xd_output_len, &fill);
  tailprintf (res, bld->xd_output_len, &fill, "-->\n");
#endif
  /* All ELEMENTs */
  DO_SET (xv_dtd_id_t *, curr_id, (&bld->xd_dict))
  {
    if (curr_id->xdi_used_as_element)
      {
	if (curr_id->xdi_mixed_content)
	  {
	    xv_dtd_emit_mixed_element (bld, curr_id, res, bld->xd_output_len, &fill);
	  }
	else
	  {
	    xv_dtd_emit_pure_element (bld, curr_id, res, bld->xd_output_len, &fill);
	  }
      }
  }
  END_DO_SET ();
  /* All ATTLISTs */
  DO_SET (xv_dtd_id_t *, curr_id, (&bld->xd_dict))
  {
    if (curr_id->xdi_used_as_element)
      {
	xv_dtd_emit_attlist (bld, curr_id, res, bld->xd_output_len, &fill);
      }
  }
  END_DO_SET ();
  /* Finalization */
  boxed_res = dk_alloc_box (strlen(res)+1, DV_LONG_STRING);
  strcpy_box_ck (boxed_res,res);
  dk_free(res,bld->xd_output_len);
  xv_dtd_builder_free (bld);
  return boxed_res;

}

/* IvAn/ViewSchema/000728 XML Schema */

static xv_schema_builder_t *
xv_schema_builder_allocate (char *view_name, char *top_el_name)
{
  xv_schema_builder_t *res = (xv_schema_builder_t *) dk_alloc (sizeof (xv_schema_builder_t));
  res->xs_dd = NULL;		/* invalid value, to cause 100% crash if used */
  res->xs_view_name = view_name;
  res->xs_top_el_name = top_el_name;
  res->xs_output_len = 0;	/* invalid value, to cause 100% crash if used */
  res->xs_typenames = id_hash_allocate (61, sizeof (char *), sizeof (int),
      strhash, strhashcmp);
  return res;
}

static void
xv_schema_builder_free (xv_schema_builder_t * bld)
{
  id_hash_iterator_t dict_hit;	/* Iterator to zap dictionary */
  char **dict_key;		/* Current key to zap */
  char **dict_val;		/* Current value to zap, unused */
  /* do not free bld->xa_dd -- it's pointer to data of query instance */
  /* do not free bld->xa_view_name -- it's pointer to argument of bif_xml_view_schema */
  /* do not free bld->xa_top_el_name -- it's pointer to NULL or argument of bif_xml_view_schema */
  for (id_hash_iterator (&dict_hit, bld->xs_typenames);
      hit_next (&dict_hit, (char **) (&dict_key), (char **) (&dict_val));
  /*no step */ )
    {
      dk_free (dict_key[0], -1);
    }
  id_hash_free (bld->xs_typenames);
  dk_free (bld, sizeof (xv_schema_builder_t));
}

static int
xv_schema_eval_output_len (xv_schema_builder_t * bld, const xv_join_elt_t * curr_join_elt)
{
  int res = 300;		/* accumulated length, initial value is for header etc. */
  char *el_name;		/* Name of current join element */
  int sub_idx;			/* Unused, only for DO_BOX(...) call */
  int chld_idx;			/* Unused, only for DO_BOX(...) call */
  el_name = (char *) (curr_join_elt->xj_element);
  if (NULL == el_name)
    el_name = bld->xs_top_el_name;
  if (NULL != el_name)
    res += (int) (strlen (el_name) * 2 * (1 + BOX_ELEMENTS_0 (curr_join_elt->xj_cols) + BOX_ELEMENTS_0 (curr_join_elt->xj_children)));
  DO_BOX (xj_col_t *, column, sub_idx, curr_join_elt->xj_cols)
  {
    if (!((XV_XC_ATTRIBUTE | XV_XC_SUBELEMENT) & column->xc_usage))
      continue;
    res += (int) (160 + strlen (column->xc_xml_name) * 2);
  }
  END_DO_BOX;
  DO_BOX (xv_join_elt_t *, chld, chld_idx, curr_join_elt->xj_children)
  {
    res += xv_schema_eval_output_len (bld, chld);
  }
  END_DO_BOX;
  return res;
}

static char *
xv_schema_type_name (xv_schema_builder_t * bld, const xv_join_elt_t * curr_join_elt, const char *sub)
{
  int res_len;			/* Length of the resulting name */
  char *lookup;			/* The beginning of the name of type, to scan the table */
  char *res;			/* Resulting name of type */
  char *el_name;		/* Name of current join element */
  int *name_usages_ptr;		/* Pointer to counter in hashtable */
  int name_usages;		/* Just a value of counter in hashtable */
  el_name = (char *) (curr_join_elt->xj_element);
  if (NULL == el_name)
    el_name = bld->xs_top_el_name;
  if (NULL == el_name)
    el_name = "TopLevel";
  res_len = (int) (strlen (el_name) + strlen (sub) + 11);
  lookup = (char *) dk_alloc (res_len);
  snprintf (lookup, res_len, "%s_%s", el_name, sub);
  name_usages_ptr = (int *) id_hash_get (bld->xs_typenames, (caddr_t) (&lookup));
  if (NULL == name_usages_ptr)
    {
      name_usages = 1;
      id_hash_set (bld->xs_typenames, (caddr_t) (&lookup), (caddr_t) (&name_usages));
      res = (char *) dk_alloc (res_len);
      snprintf (res, res_len, "%s_Type", lookup);
      return res;
    }
  name_usages = (++(name_usages_ptr[0]));
  snprintf (lookup + strlen (lookup), res_len - strlen (lookup), "_Type%u", name_usages);
  return lookup;
}

# if 0
/* This function is not used now. It may become useful again later. */
static int
xv_schema_check_element_attrs (const xv_join_elt_t * curr_join_elt)
{
  int sub_idx;			/* Unused, only for DO_BOX(...) call */
  DO_BOX (xj_col_t *, column, sub_idx, curr_join_elt->xj_cols)
  {
    if (XV_XC_SUBELEMENT & column->xc_usage)
      return 1;
  }
  END_DO_BOX;
  return 0;
}
#endif

static void
xv_schema_xsdtype_default (int directives, xv_schema_xsdtype_t *res)
{
  res->xsd_type = NULL;		/* by default, returned type is the most generic 'xsd:string' */
  res->xsd_comment = NULL;	/* by default, no comment needed */
  res->xsd_maxLength = -1;	/* by default, length is undefined */
  res->xsd_precision = -1;	/* by default, precision is undefined */
  res->xsd_scale = -1;		/* by default, scale is undefined */
  res->xsd_may_be_null = 1;	/* by default, NULL value is possible */
  res->xsd_directives = directives;
}


static void
xv_schema_xsdtype_sqt (sql_type_t *col_type, int directives, xv_schema_xsdtype_t *res)
{
  res->xsd_directives = directives;
  if (col_type->sqt_non_null)
    res->xsd_may_be_null = 0;
  if (col_type->sqt_scale > 0)
    res->xsd_scale = col_type->sqt_scale;
  switch (col_type->sqt_dtp)
    {
    case DV_C_SHORT:
      res->xsd_type = "xsd:short";
      if (col_type->sqt_precision > 0)
	  res->xsd_precision = col_type->sqt_precision;
      return;
    case DV_SHORT_INT:
      res->xsd_type = "xsd:byte";
      if (col_type->sqt_precision > 0)
	  res->xsd_precision = col_type->sqt_precision;
      return;
    case DV_LONG_INT:
      res->xsd_type = "xsd:int";
      if (col_type->sqt_precision > 0)
	  res->xsd_precision = col_type->sqt_precision;
      return;
    case DV_SINGLE_FLOAT:
      res->xsd_type = "xsd:float";
      if (col_type->sqt_precision > 0)
	  res->xsd_precision = col_type->sqt_precision;
      return;
    case DV_DOUBLE_FLOAT:
      res->xsd_type = "xsd:double";
      if (col_type->sqt_precision > 0)
	  res->xsd_precision = col_type->sqt_precision;
      return;
    case DV_C_INT:
      res->xsd_type = "xsd:int";
      if (col_type->sqt_precision > 0)
	  res->xsd_precision = col_type->sqt_precision;
      return;
    case DV_NUMERIC:
      res->xsd_type = "xsd:decimal";
      if (col_type->sqt_precision > 0)
	  res->xsd_precision = col_type->sqt_precision;
      return;
    case DV_DATE:
      res->xsd_comment = "Date";
      return;
    case DV_TIME:
      res->xsd_comment = "Time";
      return;
    case DV_DATETIME:
      res->xsd_comment = "Datetime";
      res->xsd_scale = -1;
      return;
    case DV_STRING: case DV_BLOB:
      if ((col_type->sqt_precision > 0) && (col_type->sqt_precision != 24) && (col_type->sqt_precision < 2048))
	res->xsd_maxLength = col_type->sqt_precision;
      return;
    case DV_BIN: case DV_BLOB_BIN:
      res->xsd_comment = "Binary data";
      if ((col_type->sqt_precision > 0) && (col_type->sqt_precision != 12) && (col_type->sqt_precision < 2048))
	res->xsd_maxLength = col_type->sqt_precision;
      return;
    }
  if (col_type->sqt_precision > 0)
    res->xsd_maxLength = col_type->sqt_precision;
}


/* This code was placed in separate function intentionally, to be extended
   in future by type processing for expressions of types other that COL_DOTTED */
static void
xv_schema_xsdtype (const dbe_schema_t *dd, const char *tablename, const ST *exp, int directives, xv_schema_xsdtype_t *res)
{
  dbe_table_t *ddtable;		/* Current table */
  dbe_column_t **ddcolumn;	/* Column, referred by exp */
  sql_type_t *col_type;		/* SQL type of column */
  xv_schema_xsdtype_default (directives, res);
  if (NULL == tablename)
    return;
  /* ddtable = (dbe_table_t **) (void *) id_hash_get (dd->sc_name_to_table, (caddr_t) (&tablename)); */
  ddtable = sch_name_to_table ((dbe_schema_t *) dd, (char *) tablename);
  if (NULL == ddtable)
    return;
  if (exp->type != COL_DOTTED)
    return;
  ddcolumn = (dbe_column_t **) (void *) id_hash_get (ddtable->tb_name_to_col, (caddr_t) (&exp->_.col_ref.name));
  if (NULL == ddcolumn)
    return;
  col_type = &(ddcolumn[0]->col_sqt);
  xv_schema_xsdtype_sqt (col_type, directives, res);
}

static void
xv_schema_sprintf_xsdtype (char *col_xml_name, xv_schema_xsdtype_t *xsd, char *res, size_t tlen, int *fill)
{
  int xsd_ok;			/* 1 if xv_schema_xsdtype_t xsd may be used directly */
  const char *title;
  char *type;
  int isattr = (XML_COL_ATTR == (xsd->xsd_directives & XML_COL__FORMAT));
  title = (isattr ? "attribute" : "element");
  type = (char *) xsd->xsd_type;
  switch (xsd->xsd_directives & XML_COL__SCHEMA)
    {
    case XML_COL_ID: type = "xsd:ID"; break;
    case XML_COL_IDREF: type = "xsd:IDREF"; break;
    }
#if 0 /* No need because xsi:nul is now supported */
  xsd_ok = ((NULL==xsd->xsd_type) || !xsd->xsd_may_be_null);
#else
  xsd_ok = 1;
#endif
  if (NULL == xsd->xsd_type)
    type = "xsd:string";
  if(xsd_ok)
    {
      tailprintf (res, tlen, fill, "\n  <xsd:%s name=\"%s\" type=\"%s\"",
	title, col_xml_name, type, (xsd->xsd_may_be_null ? "true" : "false") );
      if (isattr)
        tailprintf (res, tlen, fill, " use=\"%s\"", (xsd->xsd_may_be_null ? "optional" : "required"));
      else
        tailprintf (res, tlen, fill, " nillable=\"%s\"", (xsd->xsd_may_be_null ? "true" : "false"));
    } else {	/* When in trouble, use xsd:string and add an comment with hard type */
      tailprintf (res, tlen, fill, "\n  <xsd:%s name=\"%s\" type=\"xsd:string\"", title, col_xml_name);
      if (xsd->xsd_maxLength > 0)
	tailprintf (res, tlen, fill, " maxLength=\"%u\"", xsd->xsd_maxLength);
      tailprintf (res, tlen, fill, "/> \t<!-- <xsd:%s name=\"%s\" type=\"%s\"", title, col_xml_name, type);
    }
#if 0
  if (xsd->xsd_maxLength > 0)
    tailprintf (res, tlen, fill, " maxLength=\"%u\"", xsd->xsd_maxLength);
  if (xsd->xsd_precision > 0)
    tailprintf (res, tlen, fill, " precision=\"%u\"", xsd->xsd_precision);
  if (xsd->xsd_scale > 0)
    tailprintf (res, tlen, fill, " scale=\"%u\"", xsd->xsd_scale);
#endif
  tailprintf (res, tlen, fill, (xsd_ok ? "/>" : "/> -->"));
  if (NULL != xsd->xsd_comment)
    tailprintf (res, tlen, fill, " \t<!-- %s -->", xsd->xsd_comment);
}

static void
xv_schema_emit_el_type (xv_schema_builder_t * bld, const xv_join_elt_t * curr_join_elt, char *type_name, char *res, size_t tlen, int *fill)
{
  char *el_name;		/* Name of current join element */
  int chld_idx;			/* Index of current child among all children */
  int sub_idx;			/* Unused, only for DO_BOX(...) call */
  int no_of_child_els;		/* Number of sub-elements created from curr_join_elt->xj_children */
  char **child_types;		/* Names of types for all children of curr_join_elt */
  char *prev_el_name = NULL;	/* Name of previous child element, to produce warnings */
  int col_is_elem;		/* Flags if current column is element, not attribute */
  xv_schema_xsdtype_t xsd;	/* Description of 'xsd:...' type  */
  el_name = (char *) (curr_join_elt->xj_element);
  if (NULL == el_name)
    el_name = bld->xs_top_el_name;
  if (NULL == curr_join_elt->xj_parent)
    {				/* Top-level element should be reported, if named */
      if (NULL != el_name)
	tailprintf (res, tlen, fill,
	    "\n\n <xsd:element name=\"%s\" type=\"%s\"/>",
	    el_name, type_name);
    }
  no_of_child_els = BOX_ELEMENTS_0 (curr_join_elt->xj_children);
  /* Element's type is simple if it has no sub-elements or attributes, so check was
     initially written as
     if ((no_of_child_els == 0) && !xv_schema_check_element_attrs (curr_join_elt))
     But new variant is a bit more paranoid. It may produce longer text, but
     the result will be human-readable */
   if ((no_of_child_els == 0) && (BOX_ELEMENTS_0 (curr_join_elt->xj_cols) == 0))
    {
      tailprintf (res, tlen, fill,
	  "\n\n <xsd:simpleType name=\"%s\" base=\"%\"/>",
	  type_name, "xsd:string");
      return;
    }
  tailprintf (res, tlen, fill,
      "\n\n <xsd:complexType name=\"%s\">", type_name);
  DO_BOX (xj_col_t *, column, sub_idx, curr_join_elt->xj_cols)
  {
    if (!((XV_XC_ATTRIBUTE | XV_XC_SUBELEMENT) & column->xc_usage))
      continue;
    col_is_elem = ((XV_XC_SUBELEMENT & column->xc_usage) ? XML_COL_ELEMENT : XML_COL_ATTR);
    xv_schema_xsdtype (bld->xs_dd, curr_join_elt->xj_table, column->xc_exp, col_is_elem, &xsd);
    xv_schema_sprintf_xsdtype (column->xc_xml_name, &xsd, res, tlen, fill);
  }
  END_DO_BOX;
  child_types = (char **) dk_alloc (no_of_child_els * sizeof (char *) + 1); /* +1 is a stub for case of 0 children, to avoid allocation of 0 bytes */
  DO_BOX (xv_join_elt_t *, chld, chld_idx, curr_join_elt->xj_children)
  {
    if ((NULL != prev_el_name) && (!strcmp (prev_el_name, chld->xj_element)))
      {
	tailprintf (res, tlen, fill,
	    "\n<!--\n Schema is ambiguous at this point.\n To fix it, remove the following xsd:element and/or\n change maxOccurs in previous xsd:element from \"unbounded\" to some fixed value.\n -->");
      }
    prev_el_name = chld->xj_element;
    /* if ((BOX_ELEMENTS_0 (chld->xj_children) == 0) && !xv_schema_check_element_attrs (chld)) */
    /* This new variant is a bit more paranoid */
    if ((BOX_ELEMENTS_0 (chld->xj_children) == 0) && (BOX_ELEMENTS_0 (chld->xj_cols) == 0))
      {
	child_types[chld_idx] = NULL;
	tailprintf (res, tlen, fill,
	    "\n  <xsd:element name=\"%s\" type=\"%s\" minOccurs=\"0\" maxOccurs=\"unbounded\"/>",
	    chld->xj_element, "xsd:string");
      }
    else
      {
	child_types[chld_idx] = xv_schema_type_name (bld, curr_join_elt, chld->xj_element);
	tailprintf (res, tlen, fill,
	    "\n  <xsd:element name=\"%s\" type=\"%s\" minOccurs=\"0\" maxOccurs=\"unbounded\"/>",
	    chld->xj_element, child_types[chld_idx]);
      }
  }
  END_DO_BOX;
  tailprintf (res, tlen, fill, "\n </xsd:complexType>");
  DO_BOX (xv_join_elt_t *, chld, chld_idx, curr_join_elt->xj_children)
  {
    if (NULL != child_types[chld_idx])
      {
	xv_schema_emit_el_type (bld, chld, child_types[chld_idx], res, tlen, fill);
	dk_free (child_types[chld_idx], -1);
      }
  }
  END_DO_BOX;
  dk_free (child_types, -1);
}

caddr_t
bif_xml_view_schema (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t view_name;
  caddr_t top_el_name = NULL;
  xml_view_t *xv;		/* view view_named as 'view_name' */
  char * res;			/* output buffer */
  caddr_t boxed_res;		/* box for long string result of function */
  int fill = 0;			/* offset of unfilled tail of res */
  xv_schema_builder_t *bld = NULL;	/* builder of schema, with all temporary data inside */
  char *toplevel_type_name;	/* Type name for outermost item */
  view_name = bif_string_arg (qst, args, 0, "xml_view_schema");
  if (BOX_ELEMENTS (args) > 1)
    {
      top_el_name = bif_string_arg (qst, args, 1, "xml_view_schema");
    }
  xv = xmls_view_def (view_name);
  if (!xv)
    sqlr_new_error ("42000", "SQ180", "No XML view '%s'", view_name);
  bld = xv_schema_builder_allocate (view_name, top_el_name);
  bld->xs_dd = isp_schema (((query_instance_t *) (QST_INSTANCE (qst)))->qi_space);
  bld->xs_output_len = xv_schema_eval_output_len (bld, xv->xv_tree) + 300 + (int) strlen (bld->xs_view_name);
  res = (char *) dk_alloc (bld->xs_output_len);
  tailprintf (res, bld->xs_output_len, &fill,
      "<xsd:schema xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\">");
  tailprintf (res, bld->xs_output_len, &fill,
      "\n\n <xsd:annotation>\n  <xsd:documentation>\n    Schema of XML view '%s'\n  </xsd:documentation>\n </xsd:annotation>",
      bld->xs_view_name);

#ifdef XV_SCHEMA_DEBUG
  tailprintf (res, bld->xs_output_len, &fill, "<!--\n");
  xv_schema_debug (xv->xv_tree, res, bld->xs_output_len, &fill);
  tailprintf (res, bld->xs_output_len, &fill, "-->\n");
#endif
  toplevel_type_name = xv_schema_type_name (bld, xv->xv_tree, "");
  xv_schema_emit_el_type (bld, xv->xv_tree, toplevel_type_name, res, bld->xs_output_len, &fill);
  dk_free (toplevel_type_name, -1);
  /* Finalization */
  tailprintf (res, bld->xs_output_len, &fill, "\n</xsd:schema>");
  boxed_res = dk_alloc_box (strlen(res)+1, DV_LONG_STRING);
  strcpy_box_ck (boxed_res,res);
  dk_free (res, bld->xs_output_len);
  xv_schema_builder_free (bld);
  return boxed_res;
}


void
xr_close_tag_and_children_of (xr_element_t * elt, xr_state_t * state, dk_session_t * stream)
{
  for (;;)
    {
      xr_element_t * open = (xr_element_t *) dk_set_pop (&state->xr_open);
      if (!open)
	return;
      SES_PRINT (stream, "</");
      SES_PRINT (stream, open->xre_element);
      SES_PRINT (stream, ">");
      if (open == elt)
	return;
    }
}

void
xr_close_children_of (xr_element_t * elt, xr_state_t * state, dk_session_t * stream)
{
  for (;;)
    {
      xr_element_t * open;
      if (!state->xr_open)
	return;
      open = (xr_element_t *) state->xr_open->data;
      if (open == elt)
	return;
      dk_set_pop (&state->xr_open);
      SES_PRINT (stream, "</");
      SES_PRINT (stream, open->xre_element);
      SES_PRINT (stream, ">");
    }
}


void
xre_attrs (local_cursor_t * lc, xr_element_t * elt, dk_session_t * stream, caddr_t * prev)
{
  int inx;
  DO_BOX (xre_col_t *, col, inx, elt->xre_cols)
    {
      if (XML_COL_ATTR == col->xrc_format)
	{
	  caddr_t val = lc_nth_col (lc, col->xrc_no);
	  SES_PRINT (stream, " ");
	  SES_PRINT (stream, col->xrc_name);
	  SES_PRINT (stream, "=\"");
	  bx_out_value (lc->lc_inst, stream, (db_buf_t) val, QST_CHARSET(lc->lc_inst), default_charset, DKS_ESC_DQATTR);
	  SES_PRINT (stream, "\"");
	  if (prev)
	    {
	      dk_free_tree (prev[col->xrc_no]);
	      prev[col->xrc_no] = box_copy_tree (val);
	    }
	}
    }
  END_DO_BOX;
}

void
xre_attr_elts (local_cursor_t * lc, xr_element_t * elt, dk_session_t * stream, caddr_t * prev)
{
  wcharset_t *lc_charset = QST_CHARSET(lc->lc_inst);
  int inx;
  DO_BOX (xre_col_t *, col, inx, elt->xre_cols)
    {
      if (XML_COL_ATTR != col->xrc_format)
	{
	  caddr_t val = lc_nth_col (lc, col->xrc_no);
	  switch (col->xrc_format)
	    {
	    case XML_COL_ELEMENT:
	      SES_PRINT (stream, "<");
	      SES_PRINT (stream, col->xrc_name);
	      SES_PRINT (stream, ">");
	      bx_out_value (lc->lc_inst, stream, (db_buf_t) val, lc_charset, default_charset, DKS_ESC_PTEXT);
	      SES_PRINT (stream, "</");
	      SES_PRINT (stream, col->xrc_name);
	      SES_PRINT (stream, ">");
	      break;
	    case XML_COL_HIDE:
	      break;
	    case XML_COL_XML:
	      SES_PRINT (stream, "<");
	      SES_PRINT (stream, col->xrc_name);
	      SES_PRINT (stream, ">");
	      bx_out_value (lc->lc_inst, stream, (db_buf_t) val, lc_charset, default_charset, DKS_ESC_NONE);
	      SES_PRINT (stream, "</");
	      SES_PRINT (stream, col->xrc_name);
	      SES_PRINT (stream, ">");
	      break;
	    case XML_COL_XMLTEXT:
	      bx_out_value (lc->lc_inst, stream, (db_buf_t) val, lc_charset, default_charset, DKS_ESC_NONE);
	      break;
	    case XML_COL_CDATA:
	      if ('\0' != col->xrc_name[0])
		{
	          SES_PRINT (stream, "<");
		  SES_PRINT (stream, col->xrc_name);
		  SES_PRINT (stream, ">");
		}
	      SES_PRINT (stream, "<![CDATA[");
	      bx_out_value (lc->lc_inst, stream, (db_buf_t) val, lc_charset, default_charset, DKS_ESC_CDATA);
	      SES_PRINT (stream, "]]>");
	      if ('\0' != col->xrc_name[0])
		{
	          SES_PRINT (stream, "</");
		  SES_PRINT (stream, col->xrc_name);
		  SES_PRINT (stream, ">");
		}
	      break;
	    }
	  if (prev)
	    {
	      dk_free_tree (prev[col->xrc_no]);
	      prev[col->xrc_no] = box_copy_tree (val);
	    }
	}
    }
  END_DO_BOX;
}


int
xr_all_null (local_cursor_t * lc, xr_element_t * elt)
{

  int inx;
  DO_BOX (xre_col_t *, col, inx, elt->xre_cols)
    {
      if (DV_DB_NULL != DV_TYPE_OF (lc_nth_col (lc, col->xrc_no)))
	return 0;
    }
  END_DO_BOX;
  return 1;
}


void
xr_open (xr_state_t * state, local_cursor_t * lc, caddr_t * prev, xr_element_t * elt,
  dk_session_t * stream)
{
  if (xr_all_null (lc, elt))
    return;
  SES_PRINT (stream, "<");
  SES_PRINT (stream, elt->xre_element);
  xre_attrs (lc, elt, stream, prev);
  SES_PRINT (stream, ">");
  xre_attr_elts (lc, elt, stream, prev);

  dk_set_push (&state->xr_open, (void*) elt);
}


int
xr_is_elt_same (local_cursor_t * lc, xr_element_t * elt, caddr_t * prev)
{
  int inx;
  if (!prev)
    return 0;
  DO_BOX (xre_col_t *, col, inx, elt->xre_cols)
    {
      if (!box_equal (lc_nth_col (lc, col->xrc_no), prev[col->xrc_no]))
	return 0;
    }
  END_DO_BOX;
  return 1;
}


void
xr_auto_row (local_cursor_t * lc, xr_state_t * state, dk_session_t * stream, long mode)
{
  int inx, inx2;
  query_t * qr = ((query_instance_t *)lc->lc_inst)->qi_query;
  int n_cols = qr->qr_select_node->sel_n_value_slots;
  caddr_t * prev = state->xr_row;
  if (!prev && mode & XR_AUTO)
    {
      prev = (caddr_t *) dk_alloc_box_zero (n_cols * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      state->xr_row = prev;
    }
  DO_BOX (xr_element_t *, elt, inx, state->xr_elements)
    {
      if (! xr_is_elt_same (lc, elt, prev))
	{
	  xr_close_tag_and_children_of (elt, state, stream);
	  for (inx2 = inx; inx2 < (int) BOX_ELEMENTS (state->xr_elements); inx2++)
	    {
	      xr_open (state, lc, prev, state->xr_elements[inx2], stream);
	    }
	  break;
	}
    }
  END_DO_BOX;
}


xr_element_t *
xr_find_elt (xr_state_t * state, int tag){
  int inx;
  DO_BOX (xr_element_t *, elt, inx, state->xr_elements)
    {
      if (elt->xre_tag_no == tag)
	return elt;
    }
  END_DO_BOX;
  return NULL;
}


void
xr_explicit_row (local_cursor_t * lc, xr_state_t * state, dk_session_t * stream)
{
  query_t * qr = ((query_instance_t *)lc->lc_inst)->qi_query;
  xr_element_t * elt, * parent_elt;
  int n_cols = qr->qr_select_node->sel_n_value_slots;
  caddr_t tag_box, parent_box;
  int tag, parent;
  if (n_cols < 3)
    sqlr_error ("42000", "There must be at least 2 leading columns in an explicit SQL");
  tag_box = lc_nth_col (lc, 0);
  parent_box = lc_nth_col (lc, 1);
  switch (DV_TYPE_OF(tag_box))
    {
    case DV_LONG_INT:
      tag = (int) unbox(tag_box);
      break;
    case DV_STRING:
      tag = atoi (tag_box);
      break;
    case DV_DB_NULL:
      tag = 0;
      break;
    default:
      sqlr_error ("42000", "Column 1 of the result set of the select statement should be of INTEGER type when FOR XML EXPLICIT clause is used");
      tag = 0; /* To keep compiler happy - never reached */
      break;
    }
  switch (DV_TYPE_OF(parent_box))
    {
    case DV_LONG_INT:
      parent = (int) unbox(parent_box);
      break;
    case DV_STRING:
      parent = atoi (parent_box);
      break;
    case DV_DB_NULL:
      parent = 0;
      break;
    default:
      sqlr_error ("42000", "Column 2 of the result set of the select statement should be of INTEGER type when FOR XML EXPLICIT clause is used");
      parent = 0; /* To keep compiler happy - never reached */
      break;
    }

  elt = xr_find_elt (state, tag);
  parent_elt = xr_find_elt (state, parent);
  if (!elt)
    sqlr_error ("42000", "explicit xml select returns an undefined tag number");

  xr_close_children_of (parent_elt, state, stream);
  xr_open (state, lc, NULL, elt, stream);
}


void
xr_result_auto (query_instance_t * qi,
		query_t * qr, caddr_t * params, xr_element_t ** cols,
		dk_session_t * stream, int mode, int named_params)
{
  xr_state_t state;
  caddr_t err = NULL;
  local_cursor_t * lc = NULL;
  memset (&state, 0, sizeof (state));
  state.xr_elements = cols;
  err = qr_exec (qi->qi_client, qr, qi, NULL, NULL, &lc, params, NULL, named_params);
  if (err)
    {
      qr_free (qr);
      sqlr_resignal (err);
    }
  while (lc_next (lc))
    {
      if (XR_AUTO & mode || XR_ROW & mode )
	xr_auto_row (lc, &state, stream, mode);
      else if (XR_EXPLICIT == mode)
	xr_explicit_row (lc, &state, stream);
    }
  err = lc->lc_error;
  lc->lc_error = NULL;
  lc_free (lc);
  qr_free (qr);
  dk_free_box ((caddr_t) params);
  xr_close_tag_and_children_of (NULL, &state, stream);
  dk_free_tree ((box_t) state.xr_row);
  if (err)
    sqlr_resignal (err);
}


xre_col_t *
xre_col_from_ssl (state_slot_t * ssl, int no, long directives)
{
  char buf[0x20];
  xre_col_t * col = (xre_col_t *) dk_alloc_box_zero (sizeof (xre_col_t), DV_ARRAY_OF_POINTER);
  col->xrc_xsdtype = (xv_schema_xsdtype_t *) dk_alloc_box (sizeof (xv_schema_xsdtype_t), DV_ARRAY_OF_LONG);
  xv_schema_xsdtype_default (directives, col->xrc_xsdtype);
  if (ssl->ssl_type == SSL_REF)
    ssl = ((state_slot_ref_t *) ssl)->sslr_ssl;
  if (NULL != ssl->ssl_name)
    col->xrc_name = cd_strip_col_name (ssl->ssl_name);
  else
    {
      snprintf (buf, sizeof (buf),"Computed%u", no);
      col->xrc_name = box_dv_short_string (buf);
    }
  xv_schema_xsdtype_sqt(&(ssl->ssl_sqt), directives, col->xrc_xsdtype);
  col->xrc_no = no;
  col->xrc_format = directives & XML_COL__FORMAT;
  return col;
}


#define TA_XR_META 1007
#define TA_XR_MODE 1008

void
xr_explicit_meta_data (sql_comp_t * sc, ST * tree, long mode)
{
  /* get the grouping in the top AS */
  int directives = ((XR_ELEMENT & mode) ? XML_COL_ELEMENT : XML_COL_ATTR);
  query_t * qr = sc->sc_cc->cc_query;
  int inx, expinx;
  xr_element_t ** elements;
  dk_set_t col_list = NULL, nos = NULL;
  DO_BOX (ST *, exp, inx, sc->sc_select_as_list)
    {
      if (ST_P (exp, BOP_AS) && BOX_ELEMENTS (exp) >= 6)
	{
	  ptrlong no = unbox (exp->_.as_exp.xml_col->_.xml_col.tag);
	  dk_set_pushnew (&nos, (void*) no);
	}
    }
  END_DO_BOX;
  elements = (xr_element_t **) list_to_array (dk_set_nreverse (nos));
  DO_BOX (ptrlong, tag, inx, elements)
    {
      xr_element_t * elt = (xr_element_t *) dk_alloc_box_zero (sizeof (xre_col_t), DV_ARRAY_OF_POINTER);
      elements[inx] = elt;
      elt->xre_tag_no = (long) tag;
      col_list = NULL;
      DO_BOX (ST *, exp, expinx, sc->sc_select_as_list)
	{
	  if (ST_P (exp, BOP_AS) && BOX_ELEMENTS (exp) >= 6)
	    {
	      ST * xc = exp->_.as_exp.xml_col;
	      if (unbox (xc->_.xml_col.tag) == elt->xre_tag_no)
		{
		  xre_col_t * col =  xre_col_from_ssl (qr->qr_select_node->sel_out_slots[expinx], expinx, directives);
		  if (XML_COL_DEFAULT != (xc->_.xml_col.directive & XML_COL__FORMAT))
		    col->xrc_format = (long) (xc->_.xml_col.directive & XML_COL__FORMAT);
		  if (xc->_.xml_col.attr_name)
		    {
		      dk_free_box (col->xrc_name);
		      col->xrc_name = box_copy (xc->_.xml_col.attr_name);
		    }
		  dk_set_push (&col_list, (void*)col);
		  if (!elt->xre_element)
		    elt->xre_element = box_dv_short_string (xc->_.xml_col.element);
		}
	    }
	}
      END_DO_BOX;
      elt->xre_cols =(xre_col_t **)  list_to_array (dk_set_nreverse (col_list));
    }
  END_DO_BOX;
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_XR_META, (void*) elements);
}


void
xr_row_meta_data (sql_comp_t * sc, ST * tree, long mode)
{
  int directives = ((XR_ELEMENT & mode) ? XML_COL_ELEMENT : XML_COL_ATTR);
  query_t * qr = sc->sc_cc->cc_query;
  int expinx;
  xr_element_t ** elements;
  dk_set_t col_list = NULL;

  tree = sqlp_union_tree_select (tree);
  {
    xr_element_t * elt = (xr_element_t *) dk_alloc_box_zero (sizeof (xre_col_t), DV_ARRAY_OF_POINTER);
    elements = (xr_element_t **) list (1, elt);
    elt->xre_element = box_dv_short_string ("ROW");
    col_list = NULL;
    _DO_BOX (expinx, tree->_.select_stmt.selection)
      {
	dk_set_push (&col_list, (void*) xre_col_from_ssl (qr->qr_select_node->sel_out_slots[expinx], expinx, directives));
      }
    END_DO_BOX;
    elt->xre_cols =(xre_col_t **)  list_to_array (dk_set_nreverse (col_list));
  }
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_XR_META, (void*) elements);
}


static int
sqlo_xr_name_exists (dk_set_t set, char *name)
{
  DO_SET (char *, stored_name, &set)
    {
      if (!strcmp (stored_name, name))
	return 1;
    }
  END_DO_SET();
  return 0;
}


void
sqlo_xr_auto_meta_data (sqlo_t * so, ST * tree)
{
  int directives;
  /* get the columns grouped by table */
  ST * sel = sqlp_union_tree_right (tree);
  query_t * qr = so->so_sc->sc_cc->cc_query;
  dk_set_t cts = NULL;
  int inx, expinx;
  long mode;
  xr_element_t ** elements;
  dk_set_t col_list = NULL;
  df_elt_t *dfe = so->so_copy_root;
  op_table_t *ot = dfe_ot (dfe);

  if (!ST_P (sel, SELECT_STMT) || !sel->_.select_stmt.table_exp)
    return;
  mode = (long) sel->_.select_stmt.table_exp->_.table_exp.flags;
  if (0 == (mode & (XR_ROW | XR_AUTO | XR_EXPLICIT)))
    mode |= XR_AUTO;
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_XR_MODE, (void*) (ptrlong) mode);
  directives = ((XR_ELEMENT & mode) ? XML_COL_ELEMENT : XML_COL_ATTR);
  if (XR_EXPLICIT & mode)
    {
      xr_explicit_meta_data (so->so_sc, tree, mode);
      return;
    }
  if (XR_ROW & mode)
    {
      xr_row_meta_data (so->so_sc, tree, mode);
      return;
    }
  if (sel != tree)
    return;	/* query exps not allowed for auto */
  if (!ot->ot_from_dfes)
    return;
  DO_BOX (ST *, exp, inx, tree->_.select_stmt.selection)
    {
      caddr_t real_name = NULL;
      while (ST_P (exp, BOP_AS))
	{
	  if (exp->_.as_exp.right)
	    real_name = (caddr_t) exp->_.as_exp.right;
	  exp = exp->_.as_exp.left;
	}
      if (ST_COLUMN (exp, COL_DOTTED))
	{
	  op_table_t * ot = sqlo_cname_ot (so, exp->_.col_ref.prefix);
	  if (!real_name)
	    real_name = ot->ot_prefix ? ot->ot_prefix : ot->ot_table->tb_name_only;
	  if (!sqlo_xr_name_exists (cts, real_name))
	    dk_set_push (&cts, (void*) real_name);
	}
    }
  END_DO_BOX;
  elements = (xr_element_t **) list_to_array (dk_set_nreverse (cts));
  DO_BOX (caddr_t, tb_name, inx, elements)
    {
      xr_element_t * elt = (xr_element_t *) dk_alloc_box_zero (sizeof (xre_col_t), DV_ARRAY_OF_POINTER);

      elements[inx] = elt;

      elt->xre_element = box_dv_short_string (tb_name);
      col_list = NULL;
      DO_BOX (ST *, exp, expinx, tree->_.select_stmt.selection)
	{
	  caddr_t real_name = NULL;
	  while (ST_P (exp, BOP_AS))
	    {
	      if (exp->_.as_exp.right)
		real_name = (caddr_t) exp->_.as_exp.right;
	      exp = exp->_.as_exp.left;
	    }
	  if (ST_COLUMN (exp, COL_DOTTED))
	    {
	      op_table_t *ot_found = sqlo_cname_ot (so, exp->_.col_ref.prefix);
	      if (!real_name)
		real_name = ot_found->ot_prefix ? ot_found->ot_prefix : ot_found->ot_table->tb_name_only;

	      if (!strcmp (real_name, tb_name))
		{
		  dk_set_push (&col_list, (void*)
		      xre_col_from_ssl (qr->qr_select_node->sel_out_slots[expinx],
			expinx, directives));
		}
	    }
	  else
	    {
	      if (0 == inx)
		dk_set_push (&col_list,
		    (void*) xre_col_from_ssl (qr->qr_select_node->sel_out_slots[expinx],
					      expinx, directives));
	    }
	}
      END_DO_BOX;
      elt->xre_cols =(xre_col_t **)  list_to_array (dk_set_nreverse (col_list));
    }
  END_DO_BOX;
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_XR_META, (void*) elements);
}


void
xr_auto_meta_data (sql_comp_t * sc, ST * tree)
{
  /* get the columns grouped by table */
  ST * sel = sqlp_union_tree_right (tree);
  query_t * qr = sc->sc_cc->cc_query;
  dk_set_t cts = NULL;
  int inx, expinx;
  long mode;
  int directives;
  xr_element_t ** elements;
  dk_set_t col_list = NULL;
  if (sc->sc_so)
    {
      sqlo_xr_auto_meta_data (sc->sc_so, tree);
      return;
    }
  if (!ST_P (sel, SELECT_STMT))
    return;
  mode = (long) sel->_.select_stmt.table_exp->_.table_exp.flags;
  if (0 == (mode & (XR_ROW | XR_AUTO | XR_EXPLICIT)))
    mode |= XR_AUTO;
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_XR_MODE, (void*) (ptrlong) mode);
  directives = ((XR_ELEMENT & mode) ? XML_COL_ELEMENT : XML_COL_ATTR);
  if (XR_EXPLICIT & mode)
    {
      xr_explicit_meta_data (sc, tree, mode);
      return;
    }
  if (XR_ROW & mode)
    {
      xr_row_meta_data (sc, tree, mode);
      return;
    }
  if (sel != tree)
    return;	/* query exps not allowed for auto */
  if (!sc->sc_tables)
    return;
  DO_BOX (ST *, exp, inx, tree->_.select_stmt.selection)
    {
      if (ST_COLUMN (exp, COL_DOTTED))
	{
	  col_ref_rec_t * crr = sqlc_col_ref_rec (sc, exp, 0);
	  comp_table_t * ct = crr->crr_ct;
	  dk_set_pushnew (&cts, (void*) ct);
	}
    }
  END_DO_BOX;
  elements = (xr_element_t **) list_to_array (dk_set_nreverse (cts));
  DO_BOX (comp_table_t *, ct, inx, elements)
    {
      xr_element_t * elt = (xr_element_t *) dk_alloc_box_zero (sizeof (xre_col_t), DV_ARRAY_OF_POINTER);
      elements[inx] = elt;
      elt->xre_element =
	((NULL == ct) ?
	  box_dv_short_string ("JOIN") :
	  ((NULL == ct->ct_prefix) ?
	    box_dv_short_string (ct->ct_table->tb_name_only) :
	    box_dv_short_string (ct->ct_prefix) ) );
      col_list = NULL;
      DO_BOX (ST *, exp, expinx, tree->_.select_stmt.selection)
	{
	  if (ST_COLUMN (exp, COL_DOTTED))
	    {
	      col_ref_rec_t * crr = sqlc_col_ref_rec (sc, exp, 0);
	      if (crr->crr_ct == ct)
		{
		  dk_set_push (&col_list, (void*) xre_col_from_ssl (qr->qr_select_node->sel_out_slots[expinx], expinx, directives));
		}
	    }
	  else
	    {
	      if (0 == inx)
		dk_set_push (&col_list, (void*) xre_col_from_ssl (qr->qr_select_node->sel_out_slots[expinx], expinx, directives));
	    }
	}
      END_DO_BOX;
      elt->xre_cols =(xre_col_t **)  list_to_array (dk_set_nreverse (col_list));
    }
  END_DO_BOX;
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_XR_META, (void*) elements);
}


/*! \brief Result of compilation of XML auto query */
struct xr_compilation_res_s
{
  xr_element_t **xrcr_elements;	/*! \brief DV_ARRAY_OF_POINTER of XML elements */
  query_t *xrcr_qr;		/*! \brief Compiled query */
  long xrcr_mode;		/*! \brief Bitmask of mode */
};

typedef struct xr_compilation_res_s xr_compilation_res_t;

static void xr_compile (query_instance_t * qi, xr_compilation_res_t *res, caddr_t sql)
{
  caddr_t err = NULL;
  res->xrcr_elements = NULL;
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_XR_MODE, 0);
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_XR_META, NULL);
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_META, (void*) xr_auto_meta_data);
  res->xrcr_qr = sql_compile (sql, qi->qi_client, &err, SQLC_DEFAULT);
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_META, NULL);
  if (err)
    sqlr_resignal (err);
  res->xrcr_elements = (xr_element_t **) THR_ATTR (THREAD_CURRENT_THREAD, TA_XR_META);
  if (QR_PASS_THROUGH == res->xrcr_qr->qr_remote_mode)
    {
      query_t * qr2;
      dk_free_tree ((caddr_t) (res->xrcr_elements));
      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_META, (void*) xr_auto_meta_data);
      qr2 = sql_compile (sql, qi->qi_client, &err, SQLC_NO_REMOTE);
      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_META, NULL);
      res->xrcr_elements = (xr_element_t **) THR_ATTR (THREAD_CURRENT_THREAD, TA_XR_META);
      qr_free (qr2);
    }
  if (NULL == res->xrcr_elements)
    sqlr_error ("42000", "No columns in the selection for XML auto");
  res->xrcr_mode = (long) (ptrlong) THR_ATTR (THREAD_CURRENT_THREAD, TA_XR_MODE);
}

caddr_t
bif_xml_auto (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t sql = bif_string_arg (qst, args, 0, "xml_auto");
  caddr_t params = bif_array_arg (qst, args, 1, "xml_auto");
  dk_session_t * stream = http_session_no_catch_arg (qst, args, 2, "xml_auto");
  xr_compilation_res_t xrcr;
  xr_compile (qi, &xrcr, sql);
  xr_result_auto (qi, xrcr.xrcr_qr, (caddr_t *) box_copy_tree (params), xrcr.xrcr_elements,
      stream, xrcr.xrcr_mode, 0);
  dk_free_tree ((caddr_t) xrcr.xrcr_elements);
  /* No need to do this, freed before: qr_free (res.xrcr_qr); */
  return NULL;
}

static int
xr_meta_eval_output_len (xr_element_t ** elements, char *toplev)
{
  int el_idx;			/* Unused, only for DO_BOX(...) call */
  int col_idx;			/* Unused, only for DO_BOX(...) call */
  int res = 300;		/* accumulated length, initial value is for header etc. */
  res += 3* (int) strlen (toplev);
  DO_BOX (xr_element_t *, el, el_idx, elements)
    {
      res += 100;
      res += (3+BOX_ELEMENTS(elements)) * (int) strlen(el->xre_element);
      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  res +=160;
	  res += 2 * (int) strlen(col->xrc_name);
	}
      END_DO_BOX;
    }
  END_DO_BOX;
  return res;
}

static void
xr_xml_row_dtd (xr_compilation_res_t *xrcr, char *toplev, char *res, size_t tlen, int *fill)
{
  int el_idx;	/* Unused, only for DO_BOX */
  int col_idx;	/* Unused, only for DO_BOX */
  int is_subel_before;	/* Flags if there is any sub-element of ROW already listed */
  tailprintf (res, tlen, fill, "\n<!ELEMENT %s (#PCDATA | ROW)* >", toplev);
  is_subel_before = 0;
  tailprintf (res, tlen, fill, "\n<!ELEMENT ROW ");
  DO_BOX (xr_element_t *, el, el_idx, xrcr->xrcr_elements)
    {
      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  if ((XML_COL_ATTR != col->xrc_format) && (XML_COL_HIDE != col->xrc_format))
	    {
	      tailprintf (
		  res, tlen, fill, "%c%s",
		  (is_subel_before ? ' ' : '('), col->xrc_name );
	      is_subel_before = 1;
	    }
	}
      END_DO_BOX;
    }
  END_DO_BOX;
  tailprintf (res, tlen, fill, "%s >\n", (is_subel_before ? ")" : "EMPTY"));
  tailprintf (res, tlen, fill, "\n<!ATTLIST ROW");
  DO_BOX (xr_element_t *, el, el_idx, xrcr->xrcr_elements)
    {
      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  if (XML_COL_ATTR == col->xrc_format)
	    {
	      tailprintf (res, tlen, fill, "\n\t%s\tCDATA\t#IMPLIED", col->xrc_name);
	    }
	}
      END_DO_BOX;
    }
  END_DO_BOX;
  tailprintf (res, tlen, fill, "\t>");
}

static void
xr_xml_explicit_dtd (xr_compilation_res_t *xrcr, char *toplev, char *res, size_t tlen, int *fill)
{
  int el_idx;	/* Unused, only for DO_BOX */
  int el_idx_2;	/* Unused, only for DO_BOX */
  int col_idx;	/* Unused, only for DO_BOX */
  tailprintf (res, tlen, fill, "\n<!ELEMENT %s (#PCDATA", toplev);
  DO_BOX (xr_element_t *, el, el_idx, xrcr->xrcr_elements)
    {
      tailprintf (res, tlen, fill, " | %s", el->xre_element);
    }
  END_DO_BOX;
  tailprintf (res, tlen, fill, ")* >");
  DO_BOX (xr_element_t *, el, el_idx, xrcr->xrcr_elements)
    {
      tailprintf (res, tlen, fill, "\n<!ELEMENT %s (#PCDATA", el->xre_element);
      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  if ((XML_COL_ATTR != col->xrc_format) && (XML_COL_HIDE != col->xrc_format) && ('\0' != col->xrc_name))
	    tailprintf (res, tlen, fill, " | %s", col->xrc_name);
	}
      END_DO_BOX;
      DO_BOX (xr_element_t *, el_2, el_idx_2, xrcr->xrcr_elements)
	{
	  tailprintf (res, tlen, fill, " | %s", el_2->xre_element);
	}
      END_DO_BOX;
      tailprintf (res, tlen, fill, ")* >");
    }
  END_DO_BOX;
  DO_BOX (xr_element_t *, el, el_idx, xrcr->xrcr_elements)
    {
      tailprintf (res, tlen, fill, "\n<!ATTLIST %s", el->xre_element);
      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  char *dtdtype = "CDATA";
	  if (XML_COL_ATTR != col->xrc_format)
	    continue;
	  switch (XML_COL__SCHEMA & col->xrc_xsdtype->xsd_directives)
	    {
	      case XML_COL_ID: dtdtype = "ID"; break;
	      case XML_COL_IDREF: dtdtype = "IDREF"; break;
	      case XML_COL_IDREFS: dtdtype = "IDREFS"; break;
	    }
	  tailprintf (res, tlen, fill, "\n\t%s\t%s\t#IMPLIED", dtdtype, col->xrc_name);
	}
      END_DO_BOX;
      tailprintf (res, tlen, fill, "\t>");
    }
  END_DO_BOX;
}

static void
xr_xml_auto_dtd (xr_compilation_res_t *xrcr, char *toplev, char *res, size_t tlen, int *fill)
{
  int el_idx;	/* Unused, only for DO_BOX */
  int col_idx;	/* Unused, only for DO_BOX */
/* The idea is every pass through the loop closes previously started
   !ELEMENT and opens new one for current element.
   After exit from the loop !ElEMENT record of the last \c xr_element_t
   will be closed, thus "submarine criterion" will be OK. */
  tailprintf (res, tlen, fill, "\n<!ELEMENT %s (#PCDATA", toplev);
  DO_BOX (xr_element_t *, el, el_idx, xrcr->xrcr_elements)
    {
      tailprintf (res, tlen, fill, " | %s)* >", el->xre_element);
      tailprintf (res, tlen, fill, "\n<!ELEMENT %s (#PCDATA", el->xre_element);
      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  if ((XML_COL_ATTR != col->xrc_format) && (XML_COL_HIDE != col->xrc_format))
	    tailprintf (res, tlen, fill, " | %s", col->xrc_name);
	}
      END_DO_BOX;
    }
  END_DO_BOX;
  tailprintf (res, tlen, fill, ")* >");
  DO_BOX (xr_element_t *, el, el_idx, xrcr->xrcr_elements)
    {
      tailprintf (res, tlen, fill, "\n<!ATTLIST %s", el->xre_element);
      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  if (XML_COL_ATTR == col->xrc_format)
	    {
	      tailprintf (res, tlen, fill, "\n\t%s\tCDATA\t#IMPLIED", col->xrc_name);
	    }
	}
      END_DO_BOX;
      tailprintf (res, tlen, fill, "\t>");
    }
  END_DO_BOX;
}

static void
xr_xml_common_dtd (xr_compilation_res_t *xrcr, char *toplev, char *res, size_t tlen, int *fill)
{
  int el_idx;	/* Unused, only for DO_BOX */
  int col_idx;	/* Unused, only for DO_BOX */
  DO_BOX (xr_element_t *, el, el_idx, xrcr->xrcr_elements)
    {
      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  if ((XML_COL_ATTR != col->xrc_format) && (XML_COL_HIDE != col->xrc_format))
	    tailprintf (res, tlen, fill, "\n<!ELEMENT %s (#PCDATA)>\n", col->xrc_name);
	}
      END_DO_BOX;
    }
  END_DO_BOX;
}

caddr_t
bif_xml_auto_dtd (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  int buf_size;
  char *buf;
  int fill = 0;
  caddr_t box_res;
  caddr_t sql = bif_string_arg (qst, args, 0, "xml_auto_dtd");
  caddr_t toplev = bif_string_arg (qst, args, 1, "xml_auto_dtd");
  xr_compilation_res_t xrcr;
  xr_compile (qi, &xrcr, sql);
  buf_size = xr_meta_eval_output_len (xrcr.xrcr_elements, toplev);
  buf_size += 100+(int) strlen (sql);
  buf = (char *) dk_alloc(buf_size);
  tailprintf (
      buf, buf_size, &fill,
      "<!-- dtd for output of the following SQL statement:\n%s\n-->",
      sql );
  ( /* Apply one of functions... */
    ( (xrcr.xrcr_mode & XR_ROW) ? xr_xml_row_dtd :
      ( (xrcr.xrcr_mode & XR_EXPLICIT) ? xr_xml_explicit_dtd :
	xr_xml_auto_dtd ) )
    /* ... to the following arguments: */
    (&xrcr, toplev, buf, buf_size, &fill) );
  /* In addition to mode-specific things all element columns should be
     declared as #PCDATA !ELEMENTs with empty !ATTRLISTs */
  xr_xml_common_dtd(&xrcr, toplev, buf, buf_size, &fill);
  dk_free_tree ((caddr_t) xrcr.xrcr_elements);
  /* No need to do this, freed before: qr_free (res.xrcr_qr); */
  box_res = box_dv_short_string(buf);
  dk_free (buf, buf_size);
  return box_res;
}

static void
xr_xml_row_schema (xr_compilation_res_t *xrcr, char *toplev, char *res, size_t tlen, int *fill)
{
  int el_idx;	/* Unused, only for DO_BOX */
  int col_idx;	/* Unused, only for DO_BOX */
  int is_nested = 0;
  tailprintf (res, tlen, fill, "\n <xsd:element name=\"%s\" type=\"%s__Type\"/>\n", toplev, toplev);
  tailprintf (res, tlen, fill, "\n <xsd:complexType name=\"%s__Type\">", toplev);
  tailprintf (res, tlen, fill, "\n  <xsd:sequence>");
  tailprintf (res, tlen, fill, "\n  <xsd:element name=\"ROW\" type=\"ROW_Type\" minOccurs=\"0\" maxOccurs=\"unbounded\"/>");
  tailprintf (res, tlen, fill, "\n  </xsd:sequence>");
  tailprintf (res, tlen, fill, "\n </xsd:complexType>\n");
  tailprintf (res, tlen, fill, "\n <xsd:complexType name=\"ROW_Type\">");
  DO_BOX (xr_element_t *, el, el_idx, xrcr->xrcr_elements)
    {
      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  if (XML_COL_ATTR == col->xrc_format)
	    xv_schema_sprintf_xsdtype (col->xrc_name, col->xrc_xsdtype, res, tlen, fill);
	}
      END_DO_BOX;
      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  if ((XML_COL_ATTR != col->xrc_format) && (XML_COL_HIDE != col->xrc_format))
	    {
	      if (!is_nested)
		{
		  tailprintf (res, tlen, fill, "\n  <xsd:sequence>"); /* only when have elements */
		  is_nested ++;
		}
	      xv_schema_sprintf_xsdtype (col->xrc_name, col->xrc_xsdtype, res, tlen, fill);
	    }
	}
      END_DO_BOX;
    }
  END_DO_BOX;
  if (is_nested)
    {
      tailprintf (res, tlen, fill, "\n  </xsd:sequence>");
      is_nested = 0;
    }
  tailprintf (res, tlen, fill, "\n </xsd:complexType>\n");
}

#define XU_ELEM 1
#define XU_COL  2

typedef struct xr_union_s
{
  int type;
  union
    {
      xr_element_t * el;
      xre_col_t *    col;
    } _;
} xr_union_t ;

static void
xr_xml_elem_push (id_hash_t * ht, void * data, int type)
{
  xr_union_t *xu = (xr_union_t *) dk_alloc (sizeof (xr_union_t));
  caddr_t name;
  dk_set_t *place = NULL;

  switch (type)
    {
      case XU_ELEM:
	  xu->type = type;
	  xu->_.el = (xr_element_t *) data;
	  name = xu->_.el->xre_element;
	  break;
      case XU_COL:
	  xu->type = type;
	  xu->_.col = (xre_col_t *) data;
	  name = xu->_.col->xrc_name;
	  break;
      default:
	  GPF_T;
    }
  place = (dk_set_t *) id_hash_get (ht, (caddr_t) &name);
  if (!place)
    {
      dk_set_t _new = NULL;
      dk_set_push (&_new, (void*) xu);
      id_hash_set (ht, (caddr_t) &name, (caddr_t) &_new);
    }
  else
    {
      dk_set_t old = *place;
      dk_set_push (&old, (void*) xu);
      id_hash_set (ht, (caddr_t) &name, (caddr_t) &old);
    }
}

static void
xr_xml_explicit_schema (xr_compilation_res_t *xrcr, char *toplev, char *res, size_t tlen, int *fill)
{
  int el_idx;	/* Unused, only for DO_BOX */
  int col_idx;	/* Unused, only for DO_BOX */
  id_hash_t * ht = id_str_hash_create (10);
  id_hash_iterator_t it;
  dk_set_t * set;
  caddr_t * name;

  /* fill-up an union of elements */
  DO_BOX (xr_element_t *, el, el_idx, xrcr->xrcr_elements)
    {
      xr_xml_elem_push (ht, el, XU_ELEM);
      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  if ((XML_COL_ATTR != col->xrc_format) && (XML_COL_HIDE != col->xrc_format))
	    xr_xml_elem_push (ht, col, XU_COL);
	}
      END_DO_BOX;
    }
  END_DO_BOX;

  tailprintf (res, tlen, fill, "\n <xsd:element name=\"%s\" type=\"Mix__Tree\"/>\n", toplev);
  tailprintf (res, tlen, fill, "\n <xsd:complexType name=\"Mix__Tree\">");
  tailprintf (res, tlen, fill, "\n  <xsd:group ref=\"Mix__Group\" />");
  tailprintf (res, tlen, fill, "\n </xsd:complexType>\n");

  tailprintf (res, tlen, fill, "\n <xsd:group name=\"Mix__Group\" >");
  tailprintf (res, tlen, fill, "\n  <xsd:choice minOccurs=\"0\" maxOccurs=\"unbounded\">");

  /* DO_SET over collected elements ; make mixed group where if more ref to another group */
  id_hash_iterator (&it, ht);
  while (hit_next (&it, (caddr_t *) & name, (caddr_t *) & set))
    {
      int len = dk_set_length (*set);
      if (len == 1)
	{
	  xr_union_t * u = (xr_union_t *)((*set)->data);
          if (u->type == XU_ELEM)
	    tailprintf (res, tlen, fill, "\n   <xsd:element name=\"%s\" type=\"%s_Type\"/>", *name, *name);
	  else
	    xv_schema_sprintf_xsdtype (u->_.col->xrc_name, u->_.col->xrc_xsdtype, res, tlen, fill);

	}
      else
        tailprintf (res, tlen, fill, "\n   <xsd:element name=\"%s\" type=\"%s_Type\"/>", *name, *name);

    }


  tailprintf (res, tlen, fill, "\n  </xsd:choice>");
  tailprintf (res, tlen, fill, "\n </xsd:group>\n");
  DO_BOX (xr_element_t *, el, el_idx, xrcr->xrcr_elements)
    {
      int len;
      dk_set_t * set = (dk_set_t *) id_hash_get (ht, (caddr_t) & (el->xre_element));
      len = dk_set_length (*set);

      tailprintf (res, tlen, fill, "\n <xsd:complexType name=\"%s_Type\" %s>",
	  el->xre_element, len == 1 ? "" : "mixed='true'");
      if (len == 1)
	tailprintf (res, tlen, fill, "\n  <xsd:group ref=\"Mix__Group\" />");
      else
	{
	  tailprintf (res, tlen, fill, "\n    <xsd:sequence>");
	  tailprintf (res, tlen, fill, "\n      <xsd:any minOccurs='1' maxOccurs='unbounded' processContents='lax' />");
	  tailprintf (res, tlen, fill, "\n    </xsd:sequence>");
	}

      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  /* The elements must be excluded, as they are exposed in the group */
	  if (XML_COL_ATTR == col->xrc_format)
	    xv_schema_sprintf_xsdtype (col->xrc_name, col->xrc_xsdtype, res, tlen, fill);
	}
      END_DO_BOX;
      tailprintf (res, tlen, fill, "\n </xsd:complexType>\n");
    }
  END_DO_BOX;

  /* free the hash and sets */
  id_hash_iterator (&it, ht);
  while (hit_next (&it, (caddr_t *) & name, (caddr_t *) & set))
    {
      xr_union_t * u;
      while (NULL != (u = (xr_union_t *) dk_set_pop (set)))
	dk_free (u, sizeof (xr_union_t));
    }
  id_hash_free (ht);
}

static void
xr_xml_auto_schema (xr_compilation_res_t *xrcr, char *toplev, char *res, size_t tlen, int *fill)
{
  int el_idx;	/* Unused, only for DO_BOX */
  int col_idx;	/* Unused, only for DO_BOX */
  int is_nested = 0;
/* The idea is every pass through the loop closes previously opened
   xsd:complexType element and opens new one for current element.
   After exit from the loop xsd:complexType element of the last \c xr_element_t
   will be closed, thus "submarine criterion" will be OK. */
  tailprintf (res, tlen, fill, "\n <xsd:element name=\"%s\" type=\"%s__Type\"/>\n", toplev, toplev);
  tailprintf (res, tlen, fill, "\n <xsd:complexType name=\"%s__Type\">", toplev);
  DO_BOX (xr_element_t *, el, el_idx, xrcr->xrcr_elements)
    {
      tailprintf (res, tlen, fill, "\n  <xsd:sequence>");
      tailprintf (res, tlen, fill, "\n   <xsd:element name=\"%s\" type=\"%s_Type\" minOccurs=\"0\" maxOccurs=\"unbounded\"/>", el->xre_element, el->xre_element);
      tailprintf (res, tlen, fill, "\n  </xsd:sequence>");

      if (is_nested)
	{
	  tailprintf (res, tlen, fill, "\n  </xsd:sequence>");
	  is_nested = 0;
	}

      tailprintf (res, tlen, fill, "\n </xsd:complexType>\n");
      tailprintf (res, tlen, fill, "\n <xsd:complexType name=\"%s_Type\">", el->xre_element);

      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  if (XML_COL_ATTR == col->xrc_format)
	    xv_schema_sprintf_xsdtype (col->xrc_name, col->xrc_xsdtype, res, tlen, fill);
	}
      END_DO_BOX;

      DO_BOX (xre_col_t *, col, col_idx, el->xre_cols)
	{
	  if ((XML_COL_ATTR != col->xrc_format) && (XML_COL_HIDE != col->xrc_format))
	    {
	      if (!is_nested)
		{
		  tailprintf (res, tlen, fill, "\n  <xsd:sequence>"); /* only when have elements */
		  is_nested ++;
		}
	      xv_schema_sprintf_xsdtype (col->xrc_name, col->xrc_xsdtype, res, tlen, fill);
	    }
	}
      END_DO_BOX;

    }
  END_DO_BOX;
  if (is_nested)
    {
      tailprintf (res, tlen, fill, "\n  </xsd:sequence>");
      is_nested = 0;
    }
  tailprintf (res, tlen, fill, "\n </xsd:complexType>\n");
}

caddr_t
bif_xml_auto_schema (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  int buf_size;
  char *buf;
  int fill = 0;
  caddr_t box_res;
  caddr_t sql = bif_string_arg (qst, args, 0, "xml_auto_schema");
  caddr_t toplev = bif_string_arg (qst, args, 1, "xml_auto_schema");
  xr_compilation_res_t xrcr;
  xr_compile (qi, &xrcr, sql);
  buf_size = xr_meta_eval_output_len (xrcr.xrcr_elements, toplev);
  buf_size += 300+(int) strlen (sql);
  buf = (char *) dk_alloc(buf_size);
  tailprintf (buf, buf_size, &fill, "<xsd:schema xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\n");
/*  tailprintf (buf, &fill,	"<!DOCTYPE xsd:schema SYSTEM \"XMLSchema.dtd\" [\n"
				"<!ENTITY %% p \'xsd:\'>\n"
				"<!ENTITY %% s \':xsd\'> ]>\n"
				"<xsd:schema xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\">\n"); */
  tailprintf (
      buf, buf_size, &fill,
      "\n <xsd:annotation>"
      "\n  <xsd:documentation>"
      "\n   Schema for output of the following SQL statement:"
      "\n   <![CDATA[%s]]>"
      "\n  </xsd:documentation>"
      "\n </xsd:annotation>\n",
      sql );
  ( /* Apply one of functions... */
    ( (xrcr.xrcr_mode & XR_ROW) ? xr_xml_row_schema :
      ( (xrcr.xrcr_mode & XR_EXPLICIT) ? xr_xml_explicit_schema :
	xr_xml_auto_schema ) )
    /* ... to the following arguments: */
    (&xrcr, toplev, buf, buf_size, &fill) );
  tailprintf (buf, buf_size, &fill, "\n</xsd:schema>");
  dk_free_tree ((caddr_t) xrcr.xrcr_elements);
  /* No need to do this, freed before: qr_free (res.xrcr_qr); */
  box_res = box_dv_short_string(buf);
  dk_free (buf, buf_size);
  return box_res;
}



/* XMLSQL Update Grams support */
#define NO_WHERE	 0  /* some where in the XML tree */
#define SYNC_TAG	  1  /* sync tag found we are at children */
#define BEFORE_TAG	 2  /* sync & before tags found we are at children */
#define AFTER_TAG	 4  /* sync & after tags found we are at children */
#define HDR_TAG		8  /* header tag found we are at children */
#define PARAM_TAG	16 /* header & param tags found we are at children */

/* Some macros to determinate witch tag is current */
#define IS_SYNC_TAG(t)	  ((t != NULL) && (0 == stricmp (t, ":sync")))
#define IS_AFTER_TAG(t)	 ((t != NULL) && (0 == stricmp (t, ":after")))
#define IS_BEFORE_TAG(t) ((t != NULL) && (0 == stricmp (t, ":before")))
#define IS_HDR_TAG(t)    ((t != NULL) && (0 == stricmp (t, ":header")))
#define IS_PARAM_TAG(t)  ((t != NULL) && (0 == stricmp (t, ":param")))
#define IS_ID_TAG(t)     ((t != NULL) && (0 == stricmp ((char *)(t), ":id")))
#define IS_IDENTITY_TAG(t) ((t != NULL) && (0 == stricmp ((char *)(t), ":at-identity")))
#define IS_NULLVALUE_TAG(t)     ((t != NULL) && (0 == stricmp ((char *)(t), ":nullvalue")))

#define IN_SYNC_TAG(t)   (SYNC_TAG == (t & SYNC_TAG))
#define IN_BEFORE_TAG(t) (BEFORE_TAG == (t & BEFORE_TAG))
#define IN_AFTER_TAG(t)  (AFTER_TAG == (t & AFTER_TAG))
#define IN_HDR_TAG(t)    (HDR_TAG == (t & HDR_TAG))
#define IN_PARAM_TAG(t)  (PARAM_TAG == (t & PARAM_TAG))

/* One element of XMLSQL Gram */
typedef struct xmlsql_ugram_s xmlsql_ugram_t;
struct xmlsql_ugram_s
  {
    caddr_t		 table_name;   /* Affected table */
    caddr_t		sql_id;       /* ID of element*/
    caddr_t		sql_identity; /* an identity parameter */
    caddr_t *		 before_cvp;   /* array of columns&values for where clause */
    long		bf_len;       /* length of column names in before condition */
    long		bf_cnt;       /* number of elements in before condition */
    caddr_t *		 after_cvp;    /* array of columns&values for insert&update values */
    long		af_len;       /* length of column names in after array */
    long		af_cnt;       /* number of elements in after condition */
    xmlsql_ugram_t *	next;	      /* down link to next element in list */
  };

xmlsql_ugram_t *
xs_find_id (xmlsql_ugram_t * xs, caddr_t table, caddr_t id)
{
  /* find record by sql:id value */
  xmlsql_ugram_t * elm = xs;
  while (elm)
    {
      if ( elm
	  && elm->table_name
	  && elm->sql_id
	  && (0 == strcmp (elm->table_name, table))
	  && (0 == strcmp (elm->sql_id, id)))
	return elm;
      elm = elm->next;
    }
  return NULL;
}

#define PUSH_XMLVAL(val)	\
	dk_set_push (&pars, box_copy_tree (val))

#define PUSH_XMLNAME(val)	\
	dk_set_push (&pars, box_copy_tree (val))

/* fill an list with grammas */
caddr_t
xs_fill (caddr_t * current, xmlsql_ugram_t ** xs, int where, caddr_t * err_ret, dk_set_t * vars,
    caddr_t nullvalue)
{
  int inx;
  dtp_t dtp = DV_TYPE_OF (current);
  if (DV_ARRAY_OF_POINTER == dtp)
    {
      caddr_t name = ((caddr_t**)current)[0][0];
      int is_root;
      int len = BOX_ELEMENTS (current);
      is_root = (uname__root == name);
      if (!is_root)
	{
	  caddr_t * tag = (caddr_t *) current[0];
	  int ix, tlen = BOX_ELEMENTS (tag);
	  caddr_t tname = tag[0];
	  caddr_t scol = NULL;

	  scol = strrchr (tname, ':');
	  if (!scol)
	    scol = tname;

	  for (ix = 1; ix < tlen; ix += 2)
	    {
	      caddr_t ename = tag[ix], evalue = tag[ix + 1];
	      caddr_t sename;

	      sename = strrchr (ename, ':');
	      if (!sename)
		sename = ename;
	      if (IS_NULLVALUE_TAG (sename))
		{
		  nullvalue = evalue;
		  break;
		}
	    }

	  if (!IN_HDR_TAG (where) && IS_HDR_TAG (scol))
	    where = HDR_TAG;
	  else if (IN_HDR_TAG (where) && IS_PARAM_TAG (scol) && tlen > 1)
	    {
	      caddr_t deflt = NULL;
	      dbg_xmlsql (("> TAG: %s (%s) in: (%u)\n", tname, scol, where));
	      for (ix = 1; ix < tlen; ix +=2 )
		{
		  if (tag [ix] && 0 == stricmp (tag [ix], "name"))
		    dk_set_push (vars, box_copy (tag [ix + 1]));
		  else if (tag [ix] && 0 == stricmp (tag [ix], "default"))
		    deflt = box_copy (tag [ix + 1]);
		  dbg_xmlsql (("\t\tVAL: %s %s\n", tag [ix], tag [ix + 1]));
		}
	      if (!deflt)
		deflt = NEW_DB_NULL;
	      dk_set_push (vars, deflt);
	    }
	  else if (!IN_SYNC_TAG (where) && IS_SYNC_TAG (scol))
	    where = SYNC_TAG;
	  else if (IN_SYNC_TAG (where) && (IS_BEFORE_TAG (scol)))
	    {
	      where &= ~(AFTER_TAG);
	      where |= BEFORE_TAG;
	    }
	  else if (IN_SYNC_TAG (where) && (IS_AFTER_TAG (scol)))
	    {
	      where &= ~(BEFORE_TAG);
	      where |= AFTER_TAG;
	    }
	  else
	    {
	      dbg_xmlsql (("> TAG: %s (%s) in: (%u)\n", tname, scol, where));
	      if (IN_SYNC_TAG (where) && (IN_BEFORE_TAG(where) || IN_AFTER_TAG (where)))
		{
		  int before = IN_BEFORE_TAG(where);
		  int found = 0;
		  long attr_len = 0, attr_cnt = 0;
		  caddr_t _this, sct, copy_id = NULL, copy_identity = NULL;
		  xmlsql_ugram_t * place = NULL;
		  caddr_t * cvd = NULL;
		  dk_set_t pars = NULL;
		  if (tlen > 1 && len == 1)
		    {
		      for (ix = 1; ix < tlen; ix += 2)
			{
			  _this = tag [ix];
			  sct = strrchr (_this, ':');
			  if (!sct)
			    sct = _this;
			  if (IS_ID_TAG (sct))
			    {
			      place = xs_find_id (*xs, tname, tag [ix + 1]);
			      if (place)
				found = 1;
			      else
				copy_id = box_copy (tag [ix + 1]);
			    }
			  else if (IS_IDENTITY_TAG (sct))
			    copy_identity = box_copy (tag [ix + 1]);
			  else
			    {
			      PUSH_XMLNAME (_this);
			      if (nullvalue && box_equal (nullvalue, tag [ix + 1]))
				dk_set_push (&pars, NEW_DB_NULL);
			      else
				PUSH_XMLVAL (tag [ix + 1]);
			      attr_len += box_length (_this) - 1;
			      attr_cnt ++;
			    }
			  dbg_xmlsql (("\t\tVAL: %s (%s) %s\n", _this, sct, tag [ix + 1]));
			}
		    }
		  else if (tlen >= 1 && len > 1)
		    {
		      int lem;
		      caddr_t ename = NULL, evalue = NULL;
		      /* Try to find an identity or id value */
		      for (ix = 1; ix < tlen; ix += 2)
			{
			  _this = tag [ix];
			  sct = strrchr (_this, ':');
			  if (!sct)
			    sct = _this;
			  if (IS_ID_TAG (sct))
			    {
			      place = xs_find_id (*xs, tname, tag [ix + 1]);
			      if (place)
				found = 1;
			      else
				copy_id = box_copy (tag [ix + 1]);
			    }
			  else if (IS_IDENTITY_TAG (sct))
			    copy_identity = box_copy (tag [ix + 1]);
			  dbg_xmlsql (("\t\tVAL: %s (%s) %s\n", _this, sct, tag [ix + 1]));
			}
		      /* Elements */
		      for (ix = 1; ix < len; ix++)
			{
			  if (193 ==  DV_TYPE_OF((caddr_t *)current[ix]))
			    {
			      lem = BOX_ELEMENTS ((caddr_t *)current[ix]);
			      if (lem > 0
				  && 193 == DV_TYPE_OF((((caddr_t *)current[ix])[0]))
				  /*&& ((caddr_t *)current[ix])[1]*/)
				{
				  ename = ((caddr_t *)((caddr_t *)current[ix])[0])[0];
				  evalue = lem > 1 ? ((caddr_t *)current[ix])[1] : box_dv_short_string ("");
				  sct = strrchr (ename, ':');
				  if (!sct)
				    sct = ename;
				  if (IS_IDENTITY_TAG (sct) && !copy_identity)
				    copy_identity = box_copy (evalue);
				  else if (IS_ID_TAG (sct) && !copy_id)
				    {
				      place = xs_find_id (*xs, tname, evalue);
				      if (place)
					found = 1;
				      else
					copy_id = box_copy (evalue);
				    }
				  else
				    {
				      PUSH_XMLNAME (ename);
				      if (nullvalue && box_equal (nullvalue, evalue))
					dk_set_push (&pars, NEW_DB_NULL);
				      else
					PUSH_XMLVAL (evalue);
				      attr_len += box_length (ename) - 1;
				      attr_cnt ++;
				    }
				  dbg_xmlsql (("\t\tVAL: %s (%s) %s\n", ename, sct, evalue));
				  /* the top rule is > 0 ; also rule for evalue is > 1
				   * then only == 1 is allocated; just in this case free it */
				  if (lem == 1)
				    dk_free_box (evalue);
				}
			    }
			}
		      len = 1; /* prevent go to next iteration of this node */
		    }
		  if (pars)
		    {
		      if (!place)
			{
			  place = (xmlsql_ugram_t *) dk_alloc (sizeof (xmlsql_ugram_t));
			  memset (place, '\x0', sizeof (xmlsql_ugram_t));
			}

		      if (!found)
			{
			  place->sql_id = copy_id;
			  place->sql_identity = copy_identity;
			  place->table_name = box_copy (tname);
			}
		      else
			{
			  dk_free_box (copy_id);
			  dk_free_box (copy_identity);
			}
		      cvd = (caddr_t *) list_to_array (dk_set_nreverse (pars));
		      pars = NULL;
		    }
		  if (place)
		    {
		      /* Only one id can place in after and before with the sam value */
		      if (before && !(place->before_cvp))
			{
			  place->before_cvp = cvd;
			  place->bf_len = attr_len;
			  place->bf_cnt = attr_cnt;
			}
		      else if (before && (place->before_cvp))
			{
			  *err_ret = srv_make_new_error ("42000", "SX013",
			      "Duplicated value of sql:id attribute in before");
			  dk_free_tree ((box_t) cvd);
			  return NULL;
			}
		      else if (!before && (place->after_cvp))
			{
			  *err_ret = srv_make_new_error ("42000", "SX014",
			      "Duplicated value of sql:id attribute in after");
			  dk_free_tree ((box_t) cvd);
			  return NULL;
			}
		      else if (!before && !(place->after_cvp))
			{
			  if (cvd)
			    {
			      place->after_cvp = cvd;
			      place->af_len = attr_len;
			      place->af_cnt = attr_cnt;
			    }
			  else
			    {
			      /*data has no changes*/
			      dk_free_tree ((box_t) place->before_cvp);
			      dk_free_box (place->table_name);
			      dk_free_box (place->sql_id);
			      dk_free_box (place->sql_identity);
			      place->table_name = NULL;
			      place->before_cvp = NULL;
			      place->sql_id = NULL;
			      place->sql_identity = NULL;
			    }
			}

		      if (!found)
			{
			  place->next = *xs;
			  *xs = place;
			}
		    }
		}
	    }
	}
      for (inx = 1; inx < len; inx++)
	{
	  xs_fill ((caddr_t *) current[inx], xs, where, err_ret, vars, nullvalue);
	  if (*err_ret)
	    return NULL;
	}
    }
  return NULL;
}

/* Templates for insert, update & delete */
static char * szInsert = "INSERT INTO \"%s\" (%s) VALUES (%s)";
static char * szUpdate = "UPDATE \"%s\" SET %s WHERE %s";
static char * szDelete = "DELETE FROM \"%s\" WHERE %s";

/* get last identity value of first found column in given table */
boxint
xs_get_identity (query_instance_t * qi, char * table)
{
  char temp[4 * MAX_NAME_LEN + 4];
  boxint *place, ret = 0;
  dbe_column_t **ptc;
  char **pk;
  caddr_t seq_name;
  id_hash_iterator_t it;
  dbe_table_t *tb = sch_name_to_table (isp_schema (qi->qi_space), table);
  id_hash_iterator (&it, tb->tb_name_to_col);
  while (hit_next (&it, (caddr_t *) & pk, (caddr_t *) & ptc))
    {
      dbe_column_t *col = *ptc;

      if (col->col_is_autoincrement)
	{
	  snprintf (temp, sizeof (temp), "%s.%s.%s.%s", tb->tb_qualifier, tb->tb_owner,
	      col->col_defined_in->tb_name, col->col_name);
	  seq_name = box_string (temp);
	  place = (boxint *) id_hash_get (sequences, (caddr_t) & seq_name);
	  ret = *place;
	  ret--;
	  dk_free_box (seq_name);
	  break;
	}
    }
  return ret;
}


/* find an identity value or parameter from array of parameters */
box_t
xs_idnval (id_hash_t * idn, id_hash_t * var, caddr_t val)
{
  boxint * place;
  caddr_t * parm = NULL;
  if (DV_STRINGP(val))
    place = (boxint *) id_hash_get (idn, (caddr_t) &val);
  else
    place = NULL;
  if (!place)
    {
      caddr_t res;
      caddr_t val1 = val + 1;
      if (val && box_length (val) > 2 && val[0] == '$')
	parm = (caddr_t *) id_hash_get (var, (caddr_t) &(val1));
      else if (val && box_length (val) > 1 && val[0] == ':')
	parm = (caddr_t *) id_hash_get (var, (caddr_t) &(val));
      res = (parm ? *parm : val);

      if (DV_STRINGP (res) && box_length (res) > 0)
	return box_utf8_as_wide_char (res, NULL, box_length (res), 0, DV_WIDE);
      else
	return box_copy (res);
    }
  else
    return  box_num (*place);
}

id_hash_t *
xs_parms (caddr_t * var, caddr_t * parms)
{
  id_hash_t *xs_var = NULL;
  int ix, ix1, found, vlen = 0, plen = 0;
  xs_var = id_str_hash_create (101);
  if (var && parms && DV_TYPE_OF (var) == 193 && DV_TYPE_OF (parms) == 193)
    {
      vlen = BOX_ELEMENTS (var);
      plen = BOX_ELEMENTS (parms);
    }
  for (ix = 0; ix < vlen; ix += 2)
    {
      found = 0;
      if (is_string_type (DV_TYPE_OF (var [ix])))
	{
	  for (ix1 = 0; ix1 < plen; ix1 += 2)
	    {
	      if (is_string_type (DV_TYPE_OF (parms [ix1])) &&
		  0 == strcmp (parms [ix1], var [ix]))
		{
		  id_hash_set (xs_var, (caddr_t) &(var [ix]), (caddr_t) & (parms [ix1 + 1]));
		  found = 1;
		  break;
		}
	    }
	  if (!found)
	    id_hash_set (xs_var, (caddr_t) &(var [ix]), (caddr_t) & (var [ix + 1]));
	}
    }
  return xs_var;
}

/*#define XS_DEBUG*/

void
xs_stmts_exec (query_instance_t * qi, caddr_t *err_ret, xmlsql_ugram_t * xs,
    caddr_t * var, caddr_t * parms, id_hash_t *variables, int debug)
{
  int nparsa = 0, nparsb = 0, ix, ix1, is_insert;
  caddr_t stmt = NULL, cols = NULL, vals = NULL, where = NULL;
  int where_len, cols_len, vals_len, stmt_len, old_log_val;
  caddr_t err = NULL;
  query_t * qr = NULL;
  caddr_t * arr = NULL, * pairsa = NULL, * pairsb = NULL;
  caddr_t table, ins_val;
  id_hash_t *xs_idn = NULL;
  id_hash_t *xs_var = NULL;
  xmlsql_ugram_t * elm;
  sql_tree_tmp *proposed;
  caddr_t stmt_id;
  srv_stmt_t * sst;

  xs_idn = id_hash_allocate  (101, sizeof (void *), sizeof (boxint), strhash, strhashcmp);
  if (!variables)
    xs_var = xs_parms (var, parms);
  else
    xs_var = variables;
  while (xs)
    {
      is_insert = 0;
      elm = xs;
      table = elm->table_name;
      if (table)
	{
	  /* Go thru data & build statements */
	  if (elm->before_cvp && elm->after_cvp)
	    {
	      /* UPDATE */
	      pairsa = elm->after_cvp;
	      pairsb = elm->before_cvp;
	      nparsa = box_length (pairsa) / sizeof (void *);
	      nparsb = box_length (pairsb) / sizeof (void *);

	      where_len = elm->bf_len + (elm->bf_cnt * 10) + ((elm->bf_cnt - 1) * 5);
	      cols_len  = elm->af_len + (elm->af_cnt * 6) + ((elm->af_cnt - 1) * 2);
	      stmt_len = (int) (strlen (szUpdate) - 6 + box_length (table) + where_len + cols_len);

	      cols = dk_alloc_box (cols_len + 1, DV_SHORT_STRING);
	      where = dk_alloc_box (where_len + 1, DV_SHORT_STRING);
	      stmt = dk_alloc_box (stmt_len, DV_SHORT_STRING);

	      cols[0] = 0;
	      where[0] = 0;

	      for (ix = 0; ix < nparsb; ix += 2)
		{
		  strcat_box_ck (where, "\""); strcat_box_ck (where, pairsb [ix]); strcat_box_ck (where, "\"");
		  if (DV_TYPE_OF (pairsb [ix + 1]) == DV_DB_NULL)
		    strcat_box_ck (where, " IS NULL");
		  else
		    strcat_box_ck (where, " = ?");
		  if (ix < (nparsb - 2))
		    strcat_box_ck (where, " AND ");
		}

	      for (ix = 0; ix < nparsa; ix += 2)
		{
		  strcat_box_ck (cols, "\""); strcat_box_ck (cols, pairsa [ix]); strcat_box_ck (cols, "\"");
		  strcat_box_ck (cols, " = ?");
		  if (ix < (nparsa - 2))
		    {
		      strcat_box_ck (cols, ", ");
		    }
		}

	      snprintf (stmt, stmt_len, szUpdate, table, cols, where);
	    }
	  else if (elm->after_cvp || elm->before_cvp)
	    {
	      /* INSERT & DELETE */
	      pairsa = elm->after_cvp ? elm->after_cvp : elm->before_cvp;
	      nparsa = box_length (pairsa) / sizeof (void *);
	      nparsb = 0;
	      is_insert = elm->after_cvp ? 1 : 0;

	      if (is_insert)
		{
		  cols_len  = elm->af_len + (elm->af_cnt * 2) + ((elm->af_cnt - 1) * 2);
		  vals_len  = (elm->af_cnt) + ((elm->af_cnt - 1) * 2);
		  where_len = 0;
		  cols = dk_alloc_box (cols_len + 1, DV_SHORT_STRING);
		  vals = dk_alloc_box (vals_len + 1, DV_SHORT_STRING);
		  cols[0] = 0;
		  vals[0] = 0;
		  stmt_len = (int) (strlen (szInsert) - 6 + box_length (table) + vals_len + cols_len);
		}
	      else
		{
		  cols_len = 0;
		  vals_len = 0;
		  where_len = elm->bf_len + (elm->bf_cnt * 10) + ((elm->bf_cnt - 1) * 5);
		  where = dk_alloc_box (where_len + 1, DV_SHORT_STRING);
		  where[0] = 0;
		  stmt_len = (int) (strlen (szDelete) - 4 + box_length (table) + where_len);
		}

	      stmt = dk_alloc_box (stmt_len, DV_SHORT_STRING);

	      for (ix = 0; ix < nparsa; ix += 2)
		{
		  if (is_insert)
		    {
		      strcat_box_ck (cols, "\""); strcat_box_ck (cols, pairsa [ix]); strcat_box_ck (cols, "\"");
		      strcat_box_ck (vals, "?");
		    }
		  else
		    {
		      strcat_box_ck (where, "\""); strcat_box_ck (where, pairsa [ix]); strcat_box_ck (where, "\"");
		      if (DV_TYPE_OF (pairsa [ix + 1]) == DV_DB_NULL)
			strcat_box_ck (where, " IS NULL");
		      else
			strcat_box_ck (where, " = ?");
		    }
		  if (ix < (nparsa - 2))
		    {
		      if (is_insert)
			{
			  strcat_box_ck (cols, ", ");
			  strcat_box_ck (vals, ", ");
			}
		      else
			strcat_box_ck (where, " AND ");
		    }
		}
	      if (is_insert)
		snprintf (stmt, stmt_len, szInsert, table, cols, vals);
	      else
		snprintf (stmt, stmt_len, szDelete, table, where);
	    }
	  dk_free_box (cols);  cols = NULL;
	  dk_free_box (vals);  vals = NULL;
	  dk_free_box (where); where = NULL;
	  if (debug)
	    printf ("XML SQL STATEMENT: %s\n", stmt);
	  if (!stmt)
	    {
	      *err_ret = srv_make_new_error ("42000", "SX015",
		  "No columns specified in update gram");
	      goto error;
	    }
	  /* Compilation & values */
#ifndef XS_DEBUG
	  /*    qr = sql_compile (stmt, qi->qi_client, &err, SQLC_DEFAULT);  */
	  stmt_id = box_dv_short_string ("xmlsql-updg");
	  sst = cli_get_stmt_access (qi->qi_client, stmt_id, GET_EXCLUSIVE, NULL);
	  /* get the old value of is_cli_log */
	  old_log_val = qi->qi_client->cli_is_log;
	  /*  set the cli_is_log to tru this will avoid PrpcAddAnswer and set_query will return a error */
	  qi->qi_client->cli_is_log = 1;
	  err = stmt_set_query (sst, qi->qi_client, stmt, NULL);
	  /* put back the cli_is_log value */
	  qi->qi_client->cli_is_log = old_log_val;
	  LEAVE_CLIENT (qi->qi_client);
#else
	  dk_free_box (stmt);
#endif
	  if (err != NULL)
	    {
	      *err_ret = err;
	      goto error;
	    }
	  stmt = NULL;
#ifndef XS_DEBUG
	  qr = sst->sst_query;
#endif
	  arr = (caddr_t *) dk_alloc_box (((nparsa + nparsb) / 2) * sizeof (void *), DV_ARRAY_OF_POINTER);
	  memset (arr, 0, ((nparsa + nparsb) / 2) * sizeof (void *));
#ifndef XS_DEBUG
	  ix = 0; ix1 = 0;
	  DO_SET (state_slot_t *, ss, &qr->qr_parms)
	    {
	      int is_null = 0;
	      if (ix >= nparsa + nparsb)
		{
		  *err_ret = srv_make_new_error ("42000", "SX016",
		      "Too many values for query");
		  dk_free_tree ((box_t) arr); arr = NULL;
		  goto error;
		}


	      if (ix < nparsa)
		{
		  is_null = DV_TYPE_OF (pairsa [ix + 1]) == DV_DB_NULL ? 1 : 0;
		  ins_val = (caddr_t) xs_idnval (xs_idn, xs_var, pairsa [ix + 1]);
		}
	      else
		{
		  is_null = DV_TYPE_OF (pairsb [ix - nparsa + 1]) == DV_DB_NULL ? 1 : 0;
		  ins_val = (caddr_t) xs_idnval (xs_idn, xs_var, pairsb [ix - nparsa + 1]);
		}

	      if (elm->before_cvp && elm->after_cvp)
		{ /* skip update where NULL params */
		  if (ix >= nparsa && is_null)
		    continue;
		}
	      else if (!elm->after_cvp)
		{ /* skip delete where NULL params */
		  if (is_null)
		    continue;
		}

	      if (ss->ssl_sqt.sqt_dtp && !IS_BLOB_DTP(ss->ssl_sqt.sqt_dtp))
		{
		  proposed = (sql_tree_tmp *) list (3,
		      box_num (ss->ssl_sqt.sqt_dtp),
		      box_num (ss->ssl_sqt.sqt_precision),
		      box_num (ss->ssl_sqt.sqt_scale));
		  arr [ix1] = box_cast (NULL, ins_val, proposed, (dtp_t) DV_TYPE_OF (ins_val));
		  dk_free_box (ins_val);
		  dk_free_tree ((box_t) proposed);
		}
	      else
		arr [ix1] = ins_val;
	      ix1 ++; ix += 2;
	    }
	  END_DO_SET ();
#else
	  for (ix = 0, ix1 = 0; ix < nparsa + nparsb; ix1++, ix += 2)
	    {
	      if (ix < nparsa)
		{
		  is_null = DV_TYPE_OF (pairsa [ix + 1]) == DV_DB_NULL ? 1 : 0;
		  ins_val = (caddr_t) xs_idnval (xs_idn, xs_var, pairsa [ix + 1]);
		}
	      else
		{
		  is_null = DV_TYPE_OF (pairsb [ix - nparsa + 1]) == DV_DB_NULL ? 1 : 0;
		  ins_val = (caddr_t) xs_idnval (xs_idn, xs_var, pairsb [ix - nparsa + 1]);
		}
	      if (!is_null)
		arr [ix1] = ins_val;
	    }
#endif

	  /* Execution */
#ifndef XS_DEBUG
	  if (qr && arr)
	    {
	      err = qr_exec (qi->qi_client, qr, qi, NULL, NULL, NULL, arr, NULL, 0);
	      dk_free_box ((box_t) arr); arr = NULL;
#else
	  if (arr)
	    {
	      dk_free_tree (arr); arr = NULL;
#endif
	      if (err != (caddr_t) SQL_SUCCESS)
		{
		  *err_ret = err;
		  goto error;
		}
	    }
	  else
	    {
	      *err_ret = srv_make_new_error ("42000", "SX017", "Empty parameters list");
	      goto error;
	    }
	  /* if have identity reference & insert */
	  if (is_insert && elm->sql_identity)
	    {
	      boxint idn_val, *place;
	      idn_val = xs_get_identity (qi, table);
	      place = (boxint *)  id_hash_get (xs_idn, (caddr_t) &(elm->sql_identity));
	      if (!place)
		id_hash_set (xs_idn, (caddr_t) &(elm->sql_identity), (caddr_t) & idn_val);
	      else
		*place = idn_val;

	    }
	}
      xs = xs->next;
    }

error:
  if (arr)
    dk_free_tree ((box_t) arr);
  id_hash_free (xs_idn);
  if (!variables)
    id_hash_free (xs_var);
}

void
xs_free (xmlsql_ugram_t * xs)
{
  xmlsql_ugram_t * elm;
  while (xs)
    {
      elm = xs;
      xs = xs->next;
      dk_free_tree ((box_t) elm->before_cvp);
      dk_free_tree ((box_t) elm->after_cvp);
      dk_free_box (elm->table_name);
      dk_free_box (elm->sql_id);
      dk_free_box (elm->sql_identity);
      dk_free (elm, sizeof (xmlsql_ugram_t));
    }
}

xmlsql_ugram_t *
xs_reverse (xmlsql_ugram_t * xs)
{
   xmlsql_ugram_t * next;
   xmlsql_ugram_t * next2;

  if (!xs)
    return NULL;

  next = xs->next;
  xs->next = NULL;

  for (;;)
    {
      if (!next)
	return xs;

      next2 = next->next;
      next->next = xs;
      xs = next;
      next = next2;
    }
}

caddr_t
bif_xmlsql_update (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  xml_tree_ent_t * xe = bif_tree_ent_arg (qst, args, 0, "xmlsql_update");
  caddr_t * parms = NULL, * var = NULL;
  xmlsql_ugram_t * xs = NULL;
  int where = NO_WHERE;
  caddr_t err = NULL;
  dk_set_t vars = NULL;
  int debug = 0;

  xs_fill (xe->xte_current, &xs, where, &err, &vars, NULL);
  if (vars)
    var = (caddr_t *) list_to_array (dk_set_nreverse (vars));
  if (err)
    goto err_ret;

  xs = xs_reverse (xs);
  if (BOX_ELEMENTS (args) > 1)
    {
      parms = (caddr_t *) bif_array_or_null_arg (qst, args, 1, "xmlsql_update");
      if (IS_BOX_POINTER (parms) && BOX_ELEMENTS (parms) % 2 != 0)
	{
	  sqlr_error ("42000", "xmlsql_update expects a vector of even length as second argument");
	  goto err_ret;
	}
    }

  if (BOX_ELEMENTS (args) > 2)
    {
      debug = bif_long_arg (qst, args, 2, "xmlsql_update") ? 1 : 0;
    }

  xs_stmts_exec (qi, &err, xs, var, parms, NULL, debug);
err_ret:
  xs_free (xs);
  dk_free_tree ((box_t) var);
  if (err)
    sqlr_resignal (err);
  return NULL;
}

/* end of XMLSQL Update Grams support */

#define XMLSQL_NS "urn:schemas-openlink-com:xml-sql"

typedef struct xml_template_state_s xml_template_state_t;
struct xml_template_state_s
{
  id_hash_t * xts_pars;
  caddr_t *   xts_act_pars;
  caddr_t     xts_xsl_template;
};

static caddr_t
xml_template_find_param (caddr_t * pars, caddr_t name)
{
  int inx, len = pars ? BOX_ELEMENTS (pars) : 0;
  for (inx = 0; inx < len; inx += 2)
    {
      if (0 == strcmp (name, pars[inx]))
	return pars[inx+1];
    }
  return NULL;
}

static caddr_t *
xml_template_set_parms (query_t * qr, id_hash_t * pars)
{
  caddr_t * ret = (caddr_t *) dk_alloc_box_zero (dk_set_length (qr->qr_parms) * 2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  caddr_t *place;
  int inx = 0;
  DO_SET (state_slot_t *, ssl, &qr->qr_parms)
    {
      caddr_t name = ssl->ssl_name;
      place = (caddr_t *)id_hash_get (pars, (caddr_t) &name);
      ret[inx] = box_copy (name);
      if (place)
	{
	  ret [inx+1] = box_cast_to (NULL, *place, DV_TYPE_OF (*place), ssl->ssl_dtp,
	      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, NULL);
	}
      else
	ret [inx+1] = NEW_DB_NULL;
      inx += 2;
    }
  END_DO_SET ();
  /*dbg_print_box ((caddr_t)ret, stderr);*/
  return ret;
}

static caddr_t *
xml_template_get_sqlx_parms (client_connection_t * cli, const caddr_t text, id_hash_t * pars, caddr_t * err)
{
  query_t * qr = NULL;
  caddr_t * ret = NULL;
  caddr_t *place;
  int inx = 0, named_params = 0;

  qr = sql_compile (text, cli, err, SQLC_NO_REMOTE);

  if (*err || !qr)
    goto err_end;

  DO_SET (state_slot_t *, ssl, &qr->qr_parms)
    {
      char *name = ssl->ssl_name;
      if (NULL != name && name[0] == ':')
	{
	  name++;
	  if (alldigits (name))
	    {
	      named_params = 0;
	      break;
	    }
	  else
	    named_params = 1;
	}
    }
  END_DO_SET ();

  ret = (caddr_t *) dk_alloc_box_zero ((1 + named_params) * dk_set_length (qr->qr_parms) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);

  DO_SET (state_slot_t *, ssl, &qr->qr_parms)
    {
      caddr_t name = ssl->ssl_name;
      place = (caddr_t *)id_hash_get (pars, (caddr_t) &name);
      /* put name only if named parameters */
      if (named_params)
        ret [inx] = box_dv_short_string (name);
      if (place)
	{
	  ret [inx+named_params] = box_cast_to (NULL, *place, DV_TYPE_OF (*place), ssl->ssl_dtp,
	      NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, NULL);
	}
      else
	ret [inx+named_params] = NEW_DB_NULL;
      /* if named_params + 2 else + 1 */
      inx = inx + named_params + 1;
    }
  END_DO_SET ();
err_end:
  qr_free (qr);
  return ret;
}

static char *
xml_template_ft_str = "SELECT 1 AS TAG, NULL AS PARENT, "
                      " RES_FULL_PATH AS [\"resource\"!1!\"name\"], "
		      " RES_MOD_TIME AS [\"resource\"!1!\"modified\"], RES_OWNER AS [\"resource\"!1!\"owner\"], "
		      " RES_GROUP AS [\"resource\"!1!\"group\"], "
		      " length (RES_CONTENT) as [\"resource\"!1!\"length\"]"
/* 		      " RES_CONTENT AS [\"resource\"!1!\"content\"!\"element\"] " */
		      " FROM WS.WS.SYS_DAV_RES WHERE CONTAINS (RES_CONTENT, '%s') FOR XML EXPLICIT";

static char *
xml_template_xp_str = "SELECT 1 AS TAG, NULL AS PARENT, "
                      " RES_FULL_PATH AS [\"resource\"!1!\"name\"], "
		      " RES_MOD_TIME AS [\"resource\"!1!\"modified\"], RES_OWNER AS [\"resource\"!1!\"owner\"], "
		      " RES_GROUP AS [\"resource\"!1!\"group\"], "
		      " length (RES_CONTENT) as [\"resource\"!1!\"length\"]"
/*		      " RES_CONTENT AS [\"resource\"!1!\"content\"!\"element\"] " */
		      " FROM WS.WS.SYS_DAV_RES WHERE RES_FULL_PATH like '%s%%' AND "
		      " XPATH_CONTAINS (RES_CONTENT, '%s') FOR XML EXPLICIT";

int
xml_template_node_serialize (caddr_t * current, dk_session_t * ses, void * xsst1)
{
  static query_t * xq = NULL;
  static query_t * sqlx_qr = NULL;
  if (ARRAYP (current) && BOX_ELEMENTS (current) > 1)
    {
      caddr_t err = NULL;
      caddr_t name = ((caddr_t**)current)[0][0];
      xte_serialize_state_t * xsst = (xte_serialize_state_t *) xsst1;
      xml_template_state_t *xts = ((xml_template_state_t *) xsst->xsst_data);
      query_instance_t * qi = (query_instance_t *)(xsst->xsst_qst);
      id_hash_t * pars = ((id_hash_t *) xts->xts_pars);
      caddr_t xslt = xml_find_attribute (current, "xsl", XMLSQL_NS);

      if (xslt && !xts->xts_xsl_template)
	xts->xts_xsl_template = xslt;

      if (0 == strcmp (name, XMLSQL_NS ":query") ||
	  0 == strcmp (name, XMLSQL_NS ":text") ||
	  0 == strcmp (name, XMLSQL_NS ":xpath"))
	{
	  caddr_t sql = current[1], tsql;
	  caddr_t * parms = NULL;
	  xr_compilation_res_t xrcr;
	  tsql = NULL;
	  if (0 == strcmp (name, XMLSQL_NS ":text"))
	    {
	      tsql = dk_alloc_box_zero (strlen (xml_template_ft_str) + box_length (sql), DV_LONG_STRING);
	      snprintf (tsql, box_length (tsql), xml_template_ft_str, sql);
	      sql = tsql;
	    }
	  else if (0 == strcmp (name, XMLSQL_NS ":xpath"))
	    {
	      caddr_t scope = xml_find_attribute (current, "scope", XMLSQL_NS);
	      tsql = dk_alloc_box_zero (strlen (xml_template_xp_str) + box_length (sql) +
		  (scope ? strlen (scope) : 0), DV_LONG_STRING);
	      snprintf (tsql, box_length (tsql), xml_template_xp_str, (scope ? scope : ""), sql);
	      sql = tsql;
	    }
	  QR_RESET_CTX
	    {
	      xr_compile (qi, &xrcr, sql);
	      parms = xml_template_set_parms (xrcr.xrcr_qr, pars);
	      xr_result_auto (qi, xrcr.xrcr_qr, parms, xrcr.xrcr_elements, ses, xrcr.xrcr_mode, 1);
	    }
	  QR_RESET_CODE
	    {
	      du_thread_t * self = THREAD_CURRENT_THREAD;
	      err = thr_get_error_code (self);
	      POP_QR_RESET;
	    }
	  END_QR_RESET;
	  dk_free_box (tsql);
	  if (err && ARRAYP (err))
	    {
	      SES_PRINT (ses, "<!-- ERROR SQLState: "); SES_PRINT (ses, ERR_STATE(err));
	      SES_PRINT (ses, " SQLMessage: "); SES_PRINT (ses, ERR_MESSAGE(err));
	      SES_PRINT (ses, " -->");
	    }
	  dk_free_tree (err);
	  dk_free_tree ((caddr_t) xrcr.xrcr_elements);
	  return 1;
	}
      else if (0 == strcmp (name, XMLSQL_NS ":xquery"))
	{
	  client_connection_t *cli = qi->qi_client;

	  if (!xq)
	    xq = sch_proc_def (isp_schema (NULL), "DB.DBA.XQ_TEMPLATE");

	  if (xq && xq->qr_to_recompile)
	    xq = qr_recompile (xq, NULL);

	  if (xq)
	    {
	      caddr_t *exec_pars = (caddr_t *) dk_alloc_box (4 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
              caddr_t context = xml_find_attribute (current, "context", XMLSQL_NS);
	      caddr_t map_schema = xml_find_attribute (current, "mapping-schema", XMLSQL_NS);
	      caddr_t xq_query = current[1];

	      exec_pars [0] = (caddr_t) &xq_query;
	      exec_pars [1] = (caddr_t) &context;
	      exec_pars [2] = (caddr_t) &ses;
	      exec_pars [3] = (caddr_t) &map_schema;
	      err = qr_exec (cli, xq, CALLER_LOCAL, NULL, NULL, NULL, exec_pars, NULL, 0);
	      dk_free_box ((box_t) exec_pars);
	    }
	  else
	    {
	      err = srv_make_new_error ("42001", "HT004", "No DB.DBA.XQ_TEMPLATE defined");
	    }

	  if (err && ARRAYP (err))
	    {
	      SES_PRINT (ses, "<!-- ERROR SQLState: "); SES_PRINT (ses, ERR_STATE(err));
	      SES_PRINT (ses, " SQLMessage: "); SES_PRINT (ses, ERR_MESSAGE(err));
	      SES_PRINT (ses, " -->");
	    }
	  dk_free_tree (err);
	  return 1;
	}
      else if (0 == strcmp (name, XMLSQL_NS ":sqlx") || 0 == strcmp (name, XMLSQL_NS ":sparql"))
	{
	  client_connection_t *cli = qi->qi_client;
	  caddr_t *params = NULL;
	  ptrlong flag = (0 == strcmp (name, XMLSQL_NS ":sparql") ? 1 : 0);
	  caddr_t q_type = box_num (flag);

	  if (!sqlx_qr)
	    sqlx_qr = sch_proc_def (isp_schema (NULL), "DB.DBA.SQLX_OR_SPARQL_TEMPLATE");

	  if (sqlx_qr && sqlx_qr->qr_to_recompile)
	    sqlx_qr = qr_recompile (sqlx_qr, NULL);

	  if (sqlx_qr)
	    {
	      caddr_t *exec_pars = (caddr_t *) dk_alloc_box (4 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	      caddr_t sqlx_query = current[1];
	      caddr_t _text = sqlx_query;

	      if (flag)
		{
		  caddr_t def_graph_uri = xml_find_attribute (current, "default-graph-uri", XMLSQL_NS);
		  /* SPARQL define input:default-graph-uri ""(space) */
		  size_t q_len = box_length (_text) + 7 + (def_graph_uri != NULL ? box_length (def_graph_uri) + 34 : 0);

		  sqlx_query = dk_alloc_box (q_len, DV_STRING);
		  if (def_graph_uri != NULL)
		    snprintf (sqlx_query, q_len, "SPARQL define input:default-graph-uri \"%s\" %s",
			def_graph_uri, _text);
		  else
		    snprintf (sqlx_query, q_len, "SPARQL %s", _text);
		}

	      params = xml_template_get_sqlx_parms (cli, sqlx_query, pars, &err);

	      if (!err)
		{
		  exec_pars [0] = (caddr_t) &sqlx_query;
		  exec_pars [1] = (caddr_t) &params;
		  exec_pars [2] = (caddr_t) &ses;
		  exec_pars [3] = (caddr_t) &q_type;
		  err = qr_exec (cli, sqlx_qr, CALLER_LOCAL, NULL, NULL, NULL, exec_pars, NULL, 0);
	        }
	      dk_free_box ((box_t) exec_pars);
	      dk_free_box (q_type);
	      if (flag)
		dk_free_box (sqlx_query);
	    }
	  else
	    {
	      err = srv_make_new_error ("42001", "HT004", "No DB.DBA.SQLX_OR_SPARQL_TEMPLATE defined");
	    }

	  if (err && ARRAYP (err))
	    {
	      SES_PRINT (ses, "<!-- ERROR SQLState: "); SES_PRINT (ses, ERR_STATE(err));
	      SES_PRINT (ses, " SQLMessage: "); SES_PRINT (ses, ERR_MESSAGE(err));
	      SES_PRINT (ses, " -->");
	    }
	  dk_free_tree (err);
	  dk_free_box ((caddr_t) params);
	  return 1;
	}
      else if (0 == strcmp (name, XMLSQL_NS ":header"))
	{
	  int inx;
	  for (inx = 1; inx < BOX_ELEMENTS_INT (current); inx++)
	    {
	      if (ARRAYP (current[inx]) && BOX_ELEMENTS (current[inx]) > 1)
		{
		  caddr_t * param = (caddr_t *)(((caddr_t **)current)[inx][0]);
		  if (0 == strcmp (param[0], XMLSQL_NS ":param"))
		    {
		      caddr_t name = xml_find_attribute ((caddr_t *)(current[inx]), "name", NULL);
		      caddr_t val;
		      if (NULL == (val = xml_template_find_param (xts->xts_act_pars, name)))
			val = ((caddr_t **)current)[inx][1];
		      id_hash_set (pars, (caddr_t) &name, (caddr_t) &val);
		    }
		}
	    }
	  return 1;
	}
      else if (0 == strcmp (name, XMLSQL_NS ":sync"))
	{
	  xmlsql_ugram_t * xs = NULL;
	  int where = NO_WHERE;
	  dk_set_t vars = NULL;
	  xs_fill (current, &xs, where, &err, &vars, NULL);
	  if (!err)
	    {
	      xs = xs_reverse (xs);
	      xs_stmts_exec (qi, &err, xs, NULL, NULL, pars, 0 /*TODO: add debug support here */);
	    }
	  if (err && ARRAYP (err))
	    {
	      SES_PRINT (ses, "<!-- ERROR SQLState: ");
	      SES_PRINT (ses, ERR_STATE(err));
	      SES_PRINT (ses, " SQLMessage: ");
	      SES_PRINT (ses, ERR_MESSAGE(err));
	      SES_PRINT (ses, " -->");
	    }
	  dk_free_tree (err);
	  xs_free (xs);
	  dk_free_tree (list_to_array(dk_set_nreverse(vars)));
	  return 1;
	}
    }
  return 0;
}


caddr_t
bif_xml_template (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  xml_tree_ent_t * xte = bif_tree_ent_arg (qst, args, 0, "xml_template");
  caddr_t * params = (caddr_t *) bif_strict_array_or_null_arg (qst, args, 1, "xml_template");
  dk_session_t *ses = http_session_no_catch_arg (qst, args, 2, "xml_auto");
  id_hash_t * pars = id_str_hash_create (128);
  char *char_out_method;
  caddr_t old_enc;
  xte_serialize_state_t xsst;
  xml_template_state_t xts;

  xts.xts_pars = pars;
  xts.xts_act_pars = params;
  xts.xts_xsl_template = NULL;

  xsst.xsst_entity = xte;
  xsst.xsst_cdata_names= xte->xe_doc.xd->xout_cdata_section_elements;
  xsst.xsst_ns_2dict = xte->xe_doc.xd->xd_ns_2dict;
  xsst.xsst_ct = NULL;
  xsst.xsst_qst = (caddr_t *)xte->xe_doc.xd->xd_qi;
  xsst.xsst_out_method = OUT_METHOD_OTHER;
  xsst.xsst_charset = NULL;
  xsst.xsst_do_indent = 0;
  xsst.xsst_indent_depth = 0;
  xsst.xsst_in_block = 0;
  xsst.xsst_dks_esc_mode = DKS_ESC_PTEXT;
  xsst.xsst_hook = xml_template_node_serialize;
  xsst.xsst_data = (void *) &xts;

  char_out_method = xte_output_method (xte);
  if (char_out_method)
    {
      if (!strcmp (char_out_method, "xml"))
	xsst.xsst_out_method = OUT_METHOD_XML;
      else if (!strcmp (char_out_method, "html"))
	xsst.xsst_out_method = OUT_METHOD_HTML;
      else if (!strcmp (char_out_method, "text"))
	xsst.xsst_out_method = OUT_METHOD_TEXT;
      else if (!strcmp (char_out_method, "xhtml"))
	xsst.xsst_out_method = OUT_METHOD_XHTML;
    }

  switch(xsst.xsst_out_method)
    {
    case OUT_METHOD_OTHER:
      break;
    case OUT_METHOD_TEXT:
      xsst.xsst_dks_esc_mode = DKS_ESC_NONE;
      break;
    default:
      xsst.xsst_do_indent = xte->xe_doc.xd->xout_indent;
      break;
    }

  old_enc = xte->xe_doc.xd->xout_encoding;
  if (!xte->xe_doc.xd->xout_encoding && qi->qi_client->cli_ws)
    xte->xe_doc.xd->xout_encoding = CHARSET_NAME (WS_CHARSET (qi->qi_client->cli_ws, NULL), NULL);
  xsst.xsst_charset = wcharset_by_name_or_dflt (xte->xe_doc.xd->xout_encoding, xte->xe_doc.xd->xd_qi);
  xsst.xsst_charset_meta = xte->xe_doc.xd->xout_encoding_meta;
  if (!xte->xe_doc.xd->xout_omit_xml_declaration)
    {
      SES_PRINT (ses, "<?xml version=\"1.0\" encoding=\"");
      SES_PRINT (ses, CHARSET_NAME (xsst.xsst_charset, "ISO-8859-1"));
      SES_PRINT (ses, "\"");
      if (xte->xe_doc.xtd->xout_standalone)
	SES_PRINT (ses, " standalone=\"yes\"");
      SES_PRINT (ses, " ?>\n");
    }
  xte_serialize_1 (xte->xte_current, ses, &xsst);
  xte->xe_doc.xd->xout_encoding = old_enc;
  id_hash_free (pars);
  return (caddr_t) (xts.xts_xsl_template ? box_copy_tree (xts.xts_xsl_template) : NEW_DB_NULL);
}
