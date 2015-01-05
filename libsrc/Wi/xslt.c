/*
 *  xslt.c
 *
 *  $Id$
 *
 *  XSLT
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

#include <stdlib.h>
#include "libutil.h"

#include "Dk.h"
#include "sqlnode.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "xml.h"
#include "xmlgen.h"

#include "xmltree.h"
#include "arith.h"
#include "sqlbif.h"
#include "srvmultibyte.h"
#include "bif_text.h"
#include "xpf.h"
#include "xmlparser.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser_impl.h"
#ifdef __cplusplus
}
#endif
#include "rdf_core.h"
#include "xslt_impl.h"
#include "bif_xper.h" /* for write_escaped_attvalue */
#include "shcompo.h"

#define xslt_instantiate_children(xp,xstree) \
do { \
  int inst_child_inx; \
  int inst_child_len = (int) BOX_ELEMENTS ((caddr_t)(xstree)); \
  for (inst_child_inx = 1; inst_child_inx < inst_child_len; inst_child_inx++) \
    xslt_instantiate_1 (xp, (caddr_t *)(((caddr_t *)(xstree))[inst_child_inx])); \
} while (0)


caddr_t
xslt_eval_1 (xparse_ctx_t * xp, xp_query_t * xqr, xml_entity_t * xe,
	    int mode, dtp_t dtp);

xslt_number_format_t *xsnf_default = NULL;
int xslt_measure_uses = 0;

#ifdef DEBUG
caddr_t
xslt_arg_value (caddr_t * xsltree, size_t idx)
{
  caddr_t * head = XTE_HEAD (xsltree);
  if (BOX_ELEMENTS(head) <= idx)
    GPF_T;
  if (IS_POINTER (head[0]))
    GPF_T;
  return head[idx];
}
#endif /* otherwise it's a macro that is defined in xslt_impl.h */


caddr_t
xslt_attr_template (xparse_ctx_t * xp, caddr_t attr)
{
  if (DV_XPATH_QUERY == DV_TYPE_OF (attr))
    return (xslt_eval_1 (xp, (xp_query_t *) attr, xp->xp_current_xe, XQ_VALUE, DV_LONG_STRING));
  else
    return (box_copy_tree (attr));
}


#ifdef DEBUG
caddr_t
xslt_arg_value_eval (xparse_ctx_t * xp, caddr_t * xte, size_t name_id)
{
  caddr_t exp = xslt_arg_value (xte, name_id);
  return (xslt_attr_template (xp, exp));
}

#else
#define xslt_arg_value_eval(xp,xte,name_id) (xslt_attr_template(xp,xslt_arg_value((xte),(name_id))))
#endif


void
sqlr_new_error_xsltree_xdl (const char *code, const char *virt_code, caddr_t * xmltree, const char *string, ...)
{
  xp_debug_location_t *xdl;
  va_list list;
  if (!IS_POINTER (XTE_HEAD(xmltree)[0])) /* if compiled XSL element */
    xdl = (xp_debug_location_t *)(xslt_arg_value (xmltree, XSLT_ATTR_ANY_LOCATION));
  else
    xdl = (xp_debug_location_t *)(xslt_attr_value (xmltree, " !location", 0));
  va_start (list, string);
  sqlr_new_error_xdl_base (code, virt_code, xdl, string, list);
  va_end (list);
}


int
xslt_arg_elt (caddr_t * xte)
{
  caddr_t *head;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (xte))
    return 0;
  head = XTE_HEAD (xte);
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (head))
    return 0;
  if (IS_POINTER (XTE_HEAD_NAME (head)))
    return 0;
  return (int)(ptrlong)(XTE_HEAD_NAME (head));
}

caddr_t
list_to_array_of_xqval (dk_set_t l)
{
  caddr_t *arr = (caddr_t *) dk_set_to_array (l);
  dk_set_free (l);
  box_tag_modify (arr, DV_ARRAY_OF_XQVAL);
  return ((caddr_t) arr);
}


void
xp_temp (xparse_ctx_t * xp, caddr_t xx)
{
  if (!xp->xp_temps)
    xp->xp_temps = hash_table_allocate (11);
  sethash ((void*) xx, xp->xp_temps, 0);
}


void
xp_temp_free (xparse_ctx_t * xp, caddr_t xx)
{
  if (! remhash ((void*) xx, xp->xp_temps))
    GPF_T1 ("bad temp data freed in xslt");
  dk_free_tree (xx);
}


void
xslt_element_start (xparse_ctx_t * xp, caddr_t name)
{
  xp_node_t *xn = xp->xp_free_list;
  if (NULL == xn)
    xn = dk_alloc (sizeof (xp_node_t));
  else
    xp->xp_free_list = xn->xn_parent;
  memset (xn, 0, sizeof (xp_node_t));
  XP_STRSES_FLUSH (xp);
  xn->xn_xp = xp;
  xn->xn_parent = xp->xp_current;
  xp->xp_current = xn;
  xn->xn_attrs = (caddr_t*) name;
}


int
xte_is_dyn_attr (caddr_t * xte)
{
  if (DV_XTREE_NODE == DV_TYPE_OF (xte))
    {
      caddr_t * head = XTE_HEAD (xte);
      if (DV_XTREE_HEAD == DV_TYPE_OF (head)
	  && (uname__attr == head[0]))
	return 1;
    }
/* Delete this: */
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (xte))
    {
      caddr_t * head = XTE_HEAD (xte);
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (head)
	  && (uname__attr == head[0]))
	return 1;
    }
  return 0;
}


int
xte_print_length (caddr_t * xte)
{
  int inx, len = 0;
  dtp_t xte_dtp = DV_TYPE_OF (xte);
  if (IS_STRING_DTP (xte_dtp))
    return (box_length ((caddr_t) xte));
  if (IS_NONLEAF_DTP (xte_dtp))
    {
      DO_BOX (caddr_t *, elt, inx, xte)
	{
	  len += xte_print_length (elt);
	}
      END_DO_BOX;
      return len;
    }
  else
    return 0;
}


int
xslt_attr_list_replace (dk_set_t attrs, caddr_t name, caddr_t val)
{
  while (attrs)
    {
      if (box_equal ((caddr_t) attrs->data, name))
	{
	  dk_free_tree ((caddr_t) attrs->next->data);
	  attrs->next->data = val;
	  dk_free_box (name);
	  return 1;
	}
      attrs = attrs->next->next;
    }
  return 0;
}


int xslt_is_no_output_escaping_elt(caddr_t val)
{
  caddr_t *elt, *head;
  if (DV_ARRAY_OF_POINTER /*DV_XTREE_NODE*/ != DV_TYPE_OF(val))
    return 0;
  if (BOX_ELEMENTS(val) != 2)
    return 0;
  elt = (caddr_t *)val;
  if (DV_ARRAY_OF_POINTER /*DV_XTREE_HEAD*/ != DV_TYPE_OF(elt[0]))
    return 0;
  if (BOX_ELEMENTS(elt[0]) != 1)
    return 0;
  head = (caddr_t *)(elt[0]);
  if (!DV_STRINGP (head[0]))
    return 0;
  return uname__disable_output_escaping == head[0];
}


void
xn_indent_elt (xp_node_t * parent, dk_set_t child)
{
  /* if child ends with entity and its previous sibling is an entity or it is the first, then
   * add a prior text sibling to indent start tag and a last text child to indent end tag */
  caddr_t indent;
  xp_node_t * xn = parent;
  int depth = 0;
  caddr_t prev_sibling = parent->xn_children ? (caddr_t)parent->xn_children->data : NULL;
  caddr_t last_child = child->next ? (caddr_t) dk_set_last (child)->data : NULL;
  if (!last_child ||  DV_STRINGP (last_child) || DV_STRINGP (prev_sibling))
    return;
  for (xn = parent; xn; xn = xn->xn_parent)
    depth++;
  if (depth)
    depth--; /* do not count root node since it's not printed */
#if 0
  indent = dk_alloc_box (depth + 3, DV_SHORT_STRING);
  memset (indent, ' ', depth + 2);
  indent[0] = '\r';
  indent[1] = '\n';
  indent[depth + 2] = 0;
#else
  indent = dk_alloc_box (depth + 2, DV_SHORT_STRING);
  memset (indent + 1, ' ', depth);
  indent[0] = '\n';
  indent[depth + 1] = 0;
#endif
  if (depth || prev_sibling)
    dk_set_push (&parent->xn_children, (void*) box_copy (indent));
  dk_set_conc (child, dk_set_cons (indent, NULL));
}


void
xslt_element_end (xparse_ctx_t * xp)
{
  caddr_t new_head;
  dk_set_t attrs = NULL;
  dk_set_t child_list = NULL;
  dk_set_t * last_attr = &attrs;
  dk_set_t * last_child = &child_list;
  dk_set_t children;
  caddr_t * l;
  xp_node_t * current = xp->xp_current;
  xp_node_t * parent = xp->xp_current->xn_parent;
  XP_STRSES_FLUSH (xp);
  children = dk_set_nreverse (current->xn_children);
  while (children)
    {
      dk_set_t next = children->next;
      caddr_t * elt = (caddr_t *) children->data;
      if (xte_is_dyn_attr (elt))
	{
	  caddr_t * head = XTE_HEAD (elt);
	  caddr_t name = head[1];
	  caddr_t val = head[2];
	  head[1] = NULL;
	  head[2] = NULL;
	  dk_free_tree ((caddr_t) elt);
	  if (xslt_attr_list_replace (attrs, name, val))
	    {
	      children->next = NULL;
	      dk_set_free (children);
	    }
	  else
	    {
	      *last_attr = children;
	      children->data = name;
	      children->next = CONS (val, NULL);
	      last_attr = &children->next->next;
	    }
	}
      else
	{
	  *last_child = children;
	  children->next = NULL;
	  last_child = & children ->next;
	}
      children = next;
    }
  new_head = list_to_array (CONS (current->xn_attrs, attrs));
  child_list = CONS (new_head, child_list);
  if (xp->xp_sheet->xout_indent)
    xn_indent_elt (parent, child_list);
  l = (caddr_t *) list_to_array (child_list);
  dk_set_push (&parent->xn_children, (void*) l);
  xp->xp_current = parent;
  current->xn_parent = xp->xp_free_list;
  xp->xp_free_list = current;
}


#define xslt_character(xp,text) \
  session_buffered_write ((xp)->xp_strses, (text), box_length ((text)) - 1)


int
xte_is_comment (caddr_t * xte)
{
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (xte)
      && DV_ARRAY_OF_POINTER == DV_TYPE_OF (XTE_HEAD (xte)))
    {
      char * name = XTE_HEAD_NAME (XTE_HEAD (xte));
      if (name == uname__comment)
	return 1;
    }
  return 0;
}

void
xqi_pred_init_pos (xp_instance_t * xqi, XT * tree, XT * pred, xml_entity_t * xe)
{
  int pos = 1, size = 0;
  XT * node = tree->_.step.node;
  if (pred->_.pred.pos || pred->_.pred.size)
    {
      xml_entity_t * tmp = xe->_->xe_copy (xe);
      while (XI_RESULT == tmp->_->xe_prev_sibling (tmp, node))
	pos++;
      if (pred->_.pred.pos)
	XQI_SET_INT (xqi, pred->_.pred.pos, pos);
      dk_free_box ((caddr_t) tmp);
    }
  if (pred->_.pred.size)
    {
      xml_entity_t * tmp = xe->_->xe_copy (xe);
      while (XI_RESULT == tmp->_->xe_next_sibling (tmp, node))
	size++;
      XQI_SET_INT (xqi, pred->_.pred.size, pos + size);
      dk_free_box ((caddr_t) tmp);
    }
}


int
xqi_match (xp_instance_t * xqi, XT * tree, xml_entity_t * xe /*, long position, long size*/)
{
  int rc;
  int inx;
  ptrlong axis;
  /*
    volatile int stack_top;
    printf("\n0x%lx : xqi_match", (long)(&stack_top));
  */
  QI_CHECK_STACK (xqi->xqi_qi, &inx, 8000);
  if (xqi->xqi_qi->qi_client->cli_terminate_requested)
    sqlr_new_error_xqi_xdl ("37000", "SR366", xqi, "XSLT aborted by client request");
again:
  switch (tree->type)
    {
    case XP_STEP:
      break; /* The whole rest of function is for steps */
    case XP_UNION: /* This should not happen due to XSLT optimization, but it is already written so let it stay here for completeness */
      rc = xqi_match (xqi, tree->_.xp_union.left, xe);
      if (XI_RESULT == rc)
	return XI_RESULT;
    tree = tree->_.xp_union.right;
    goto again; /* instead of: return xqi_match (xqi, tree->_.xp_union.right, xe); */
    default:
      sqlr_new_error_xqi_xdl ("37000", "XS001", xqi, "The expression is not a valid pattern: it is neither a location path nor an union");
    }
  axis = tree->_.step.axis;
  switch (axis)
    {
    case XP_ATTRIBUTE: case XP_ATTRIBUTE_WR:
      if (NULL == xe->xe_attr_name)
        return XI_AT_END;
      if (!xt_node_test_match (tree->_.step.node, xe->xe_attr_name))
        return XI_AT_END;
      if (NULL != tree->_.step.input)
        {
          xml_entity_t *context = xe->_->xe_copy (xe);
	  XQI_SET (xqi, tree->_.step.init, (caddr_t) context);
	  rc = context->_->xe_up (context, (XT *) XP_NODE, XE_UP_MAY_TRANSIT);
#ifdef DEBUG
	  if (XI_RESULT != rc)
	    GPF_T1("attribute node nas no parent in xqi_match");
#endif
	  if (XI_RESULT != xqi_match (xqi, tree->_.step.input, context /*, 0, 0*/))
	    return XI_AT_END;
	}
      break;
    case XP_CHILD: case XP_CHILD_WR:
      if (!xe->_->xe_ent_name_test (xe, tree->_.step.node))
        return XI_AT_END;
      if (NULL != tree->_.step.input)
        {
          xml_entity_t *context = xe->_->xe_copy (xe);
	  XQI_SET (xqi, tree->_.step.init, (caddr_t) context);
	  rc = context->_->xe_up (context, (XT *) XP_NODE, XE_UP_MAY_TRANSIT);
	  if (XI_RESULT != rc)
	    return XI_AT_END;
	  if (XI_RESULT != xqi_match (xqi, tree->_.step.input, context /*, 0, 0*/))
	    return XI_AT_END;
	}
      break;
    case XP_DESCENDANT: case XP_DESCENDANT_WR:
      if (!xe->_->xe_ent_name_test (xe, tree->_.step.node))
        return XI_AT_END;
      if (NULL != tree->_.step.input)
        {
          xml_entity_t *context = xe->_->xe_copy (xe);
	  XQI_SET (xqi, tree->_.step.init, (caddr_t) context);
	  for (;;)
	    {
	      rc = context->_->xe_up (context, (XT *) XP_NODE, XE_UP_MAY_TRANSIT);
	      if (XI_RESULT != rc)
	        return XI_AT_END;
	      if (XI_RESULT == xqi_match (xqi, tree->_.step.input, context /*, 0, 0*/))
	        break;
	    }
	}
      break;
    case XP_ROOT:
      {
        xml_entity_t * tmp = xe->_->xe_copy (xe);
        rc = tmp->_->xe_up (tmp, (XT *) XP_NODE, XE_UP_MAY_TRANSIT);
        dk_free_box ((caddr_t) tmp);
        if (XI_RESULT == rc)
	  return XI_AT_END;
	break;
      }
    case XP_ABS_DESC: case XP_ABS_DESC_WR:
      {
        xml_entity_t * tmp;
        if (!xe->_->xe_ent_name_test (xe, tree->_.step.node))
          return XI_AT_END;
        tmp = xe->_->xe_copy (xe);
        rc = tmp->_->xe_up (tmp, (XT *) XP_NODE, XE_UP_MAY_TRANSIT);
        dk_free_box ((caddr_t) tmp);
        if (XI_AT_END == rc)
	  return XI_AT_END;
	break;
      }
    case XP_ABS_DESC_OR_SELF: case XP_ABS_DESC_OR_SELF_WR:
      {
        if (!xe->_->xe_ent_name_test (xe, tree->_.step.node))
          return XI_AT_END;
	break;
      }
    case XP_ABS_CHILD: case XP_ABS_CHILD_WR:
      {
        xml_entity_t * tmp;
        int parent_is_root;
        if (!xe->_->xe_ent_name_test (xe, tree->_.step.node))
          return XI_AT_END;
        tmp = xe->_->xe_copy (xe);
        rc = tmp->_->xe_up (tmp, (XT *) XP_NODE, XE_UP_MAY_TRANSIT);
        if (XI_AT_END != rc)
          {
            rc = tmp->_->xe_up (tmp, (XT *) XP_NODE, XE_UP_MAY_TRANSIT);
            parent_is_root = (rc == XI_AT_END);
          }
        else
          parent_is_root = 0;
        dk_free_box ((caddr_t) tmp);
        if (!parent_is_root)
	  return XI_AT_END;
	break;
      }
    default:
      sqlr_new_error_xqi_xdl ("37000", "XS001", xqi, "The expression is not a valid pattern: only root::, descendant::, child:: and attribute:: axes are allowed in the location path");
    }
  DO_BOX (XT *, pred, inx, tree->_.step.preds)
    {
      xqi_pred_init_pos (xqi, tree, pred, xe);
      xqi_eval (xqi, pred->_.pred.expr, xe);
      if (!xqi_pred_truth_value (xqi, pred))
    return XI_AT_END;
    }
  END_DO_BOX;
  return XI_RESULT;
}


int
xslt_match (xparse_ctx_t * xp, xp_query_t * xqr, xml_entity_t * xe)
{
  volatile int rc;
  xp_instance_t * volatile xqi = xqr_instance (xqr, xp->xp_qi);
  xqi->xqi_doc_cache = xp->xp_doc_cache;
  xqi->xqi_xp_locals = xp->xp_locals;
  xqi->xqi_xp_globals = xp->xp_globals;
  xqi->xqi_xp_keys = xp->xp_keys;
  xqi_push_internal_binding (xqi, XSLT_CURRENT_ENTITY_INTERNAL_NAME)->xb_value = box_copy((box_t) xe);
  if (xqr->xqr_top_pos)
    XQI_SET_INT (xqi, xqr->xqr_top_pos, xp->xp_position);
  if (xqr->xqr_top_size)
    XQI_SET_INT (xqi, xqr->xqr_top_size, xp->xp_size);
  QR_RESET_CTX
    {
      rc = xqi_match (xqi, xqr->xqr_tree, xe /*, 0, 0*/);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      xqi_free (xqi);
      POP_QR_RESET;
      sqlr_resignal (err);
    }
  END_QR_RESET;
  xqi_free (xqi);
  return rc;
}

xslt_template_t *
xslt_template_find (xparse_ctx_t * xp, xml_entity_t * xe,
		    xslt_sheet_t * first_xsh)
{
  int enable = first_xsh ? 0 : 1;
  int inx, inx2;
  xslt_sheet_t * root_xsh = xp->xp_sheet;
  if (!root_xsh)
    return NULL;
  DO_BOX_FAST (xslt_sheet_t *, xsh, inx, root_xsh->xsh_imported_sheets)
    {
      if (enable)
	{
	  xslt_sheet_mode_t *xstm;
	  xslt_template_t **template_list;
	  if (NULL == xp->xp_mode)
	    xstm = &(xsh->xsh_default_mode);
	  else
	    {
	      xstm = (xslt_sheet_mode_t *) gethash (xp->xp_mode, xsh->xsh_named_modes);
	      if (NULL == xstm)
		continue;
	    }
	  template_list = ((NULL == xe->xe_attr_name) ?
	    xstm->xstm_nonattr_templates :
	    xstm->xstm_attr_templates );
	  if (NULL == template_list)
	    continue;
	  DO_BOX_FAST (xslt_template_t *, xst, inx2, template_list)
	    {
	      /*if (!xst->xst_match)
		continue;*/
	      if (xslt_measure_uses)
		xst->xst_new_uses.xstu_find_calls++;
	      /*if (!box_equal (xp->xp_mode, xst->xst_mode))
		continue;*/
	      /*if (xst->xst_match_attributes && !xe->xe_attr_name)
		continue;*/
	      /*if (!xst->xst_match_attributes && xe->xe_attr_name)
		continue;*/
	      if (xst->xst_node_test)
		{
		  int rc = xe->_->xe_ent_name_test (xe, xst->xst_node_test);
		  if (!rc)
		    continue;
		  if (xslt_measure_uses)
		    xst->xst_new_uses.xstu_find_hits++;
		  return xst;
		}
	      if (xslt_measure_uses)
		xst->xst_new_uses.xstu_find_match_calls++;
	      if (XI_RESULT != xslt_match (xp, xst->xst_match, xe))
		continue;
	      if (xslt_measure_uses)
		{
		  xst->xst_new_uses.xstu_find_hits++;
		  xst->xst_new_uses.xstu_find_match_hits++;
		}
	      return xst;
	    }
	  END_DO_BOX_FAST;
	}
      else if (xsh == first_xsh)
	enable = 1;
    }
  END_DO_BOX_FAST;
  return NULL;
}


#define WITH_TEMPLATE(t) \
{ \
  xslt_template_t * prev = xp->xp_template; \
  xp->xp_template = t; \

#define END_WITH_TEMPLATE \
  xp->xp_template = prev; \
}


void
xp_dyn_attr (xparse_ctx_t * xp, char * name, caddr_t val)
{
  caddr_t * dattr;
  dattr = (caddr_t *) list (1, list (3, uname__attr, box_dv_uname_string (name), val));
  /* There's no need in XP_STRSES_FLUSH (xp); here because dyn attr will not remain in a list of chil */
  dk_set_push (&xp->xp_current->xn_children, (void *) dattr);
}

caddr_t
xslt_try_to_eval_var_fast (xparse_ctx_t * xp, xp_query_t * xqr, xml_entity_t * xe,
	    int mode, dtp_t dtp )
{
  XT * tree = xqr->xqr_tree;
  caddr_t name = tree->_.var.name;
  xqi_binding_t *xb;
  caddr_t val = NULL;
  dtp_t val_dtp;
  for (xb = xp->xp_locals; (NULL != xb) && (NULL != xb->xb_name); xb = xb->xb_next)
    {
      if (!strcmp (name, xb->xb_name))
        {
          val = xb->xb_value;
          goto xb_found; /* see below */
        }
    }
  for (xb = xp->xp_globals; NULL != xb; xb = xb->xb_next)
    {
      if (!strcmp (name, xb->xb_name))
        {
          val = xb->xb_value;
          goto xb_found; /* see below */
        }
    }
  switch (mode)
    {
    case XQ_TRUTH_VALUE:
      return NULL;
    case XQ_VALUE:
      return box_dv_short_string ("");
      break;
    case XQ_NODE_SET:
      return list_to_array_of_xqval (0);
    }
xb_found:
  switch (mode)
    {
    case XQ_TRUTH_VALUE:
      return (caddr_t) (ptrlong) xqi_truth_value_of_box (val);
    case XQ_VALUE:
      val_dtp = DV_TYPE_OF (val);
      if (DV_ARRAY_OF_XQVAL == val_dtp)
        {
          if (0 == BOX_ELEMENTS (val))
            return box_dv_short_string ("");
          val = ((caddr_t *)val)[0];
        }
      if (NULL == val)
        return box_dv_short_string ("");
      if ((DV_UNKNOWN == dtp) || (val_dtp == dtp))
        return box_copy_tree (val);
      return BADBEEF_BOX;
    case XQ_NODE_SET:
      if (DV_ARRAY_OF_XQVAL != DV_TYPE_OF (val))
        {
          caddr_t res = list (1, box_copy_tree (val));
          box_tag_modify (res, DV_ARRAY_OF_XQVAL);
          return res;
        }
      return box_copy_tree (val);
    }
  return BADBEEF_BOX;
}

caddr_t
xslt_eval_1 (xparse_ctx_t * xp, xp_query_t * xqr, xml_entity_t * xe,
	    int mode, dtp_t dtp)
{
  dk_set_t volatile set = NULL;
  int first;
  XT * tree = xqr->xqr_tree;
  caddr_t volatile val;
#ifndef NDEBUG
  caddr_t volatile var_val = BADBEEF_BOX;
#endif
  xp_instance_t * volatile xqi;
  if (XP_VARIABLE == tree->type)
    { /* Fast code for popular case of an expression that is just a variable and no complicated cast of the value */
#ifdef NDEBUG
      caddr_t var_val;
#endif
      var_val = xslt_try_to_eval_var_fast (xp, xqr, xe, mode, dtp);
#ifdef NDEBUG
      if (BADBEEF_BOX != var_val)
        return var_val;
#endif
    }
  xqi = xqr_instance (xqr, xp->xp_qi);
  xqi->xqi_doc_cache = xp->xp_doc_cache;
  xqi->xqi_xp_locals = xp->xp_locals;
  xqi->xqi_xp_globals = xp->xp_globals;
  xqi->xqi_xp_keys = xp->xp_keys;
  xqi->xqi_return_attrs_as_nodes = 1;
  /* This is redundant now, but may be changed in the future:
  xqi->xqi_xpath2_compare_rules = 0;
  */
  xqi_push_internal_binding (xqi, XSLT_CURRENT_ENTITY_INTERNAL_NAME)->xb_value = box_copy((box_t) xe);
  xqi_push_internal_binding (xqi, XSLT_SHEET_INTERNAL_NAME)->xb_value = box_num((ptrlong)(xp->xp_sheet));
  if (xqr->xqr_top_pos)
    XQI_SET_INT (xqi, xqr->xqr_top_pos, xp->xp_position);
  if (xqr->xqr_top_size)
    XQI_SET_INT (xqi, xqr->xqr_top_size, xp->xp_size);
  QR_RESET_CTX
    {
      xqi_eval (xqi, xqr->xqr_tree, xe);
      switch (mode)
	{
	case XQ_TRUTH_VALUE:
	  val = (caddr_t) (ptrlong) xqi_truth_value (xqi, tree);
	  break;
	case XQ_VALUE:
	  first = xqi_is_value (xqi, xqr->xqr_tree);
	  if (first)
	    {
	      val = ((DV_UNKNOWN == dtp) ? xqi_raw_value (xqi, xqr->xqr_tree) : xqi_value (xqi, xqr->xqr_tree, dtp));
	      val = box_copy_tree (val);
	    }
	  else
	    val = box_dv_short_string ("");
	  break;
	case XQ_NODE_SET:
	  first = xqi_is_value (xqi, xqr->xqr_tree);
	  while (first || xqi_is_next_value (xqi, xqr->xqr_tree))
	    {
	      first = 0;
	      val = xqi_raw_value (xqi, xqr->xqr_tree);
	      dk_set_push ((dk_set_t *) &set, box_copy_tree (val));
	    }
	  val = list_to_array_of_xqval (dk_set_nreverse (set));
	  break;
	}
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      dk_free_tree ((caddr_t) list_to_array (set));
      xqi_free (xqi);
      POP_QR_RESET;
      sqlr_resignal (err);
    }
  END_QR_RESET;
  xqi_free (xqi);
#ifndef NDEBUG
  if (BADBEEF_BOX != var_val)
    {
      if (DV_TYPE_OF (var_val) != DV_TYPE_OF (val))
        GPF_T1 ("xslt_eval_1(): failed fast branch for var: wrong type");
      if (box_hash (var_val) != box_hash (val))
        {
          GPF_T1 ("xslt_eval_1(): failed fast branch for var: diff hash");
        }
      dk_free_tree (var_val);
    }
#endif
  return val;
}


int
xslt_non_whitespace (caddr_t elt)
{
  if (DV_STRINGP (elt))
    {
      char c;
      while ((c = *elt))
	{
	  if (c == ' ' || c == '\r' || c == '\n' || c == '\t')
	    elt++;
	  else
	    return 1;
	}
      return 0;
    }
  return 1;
}


static void xslt_add_attributes_from_sets (xparse_ctx_t * xp, caddr_t *attr_sets, int level);

static void
xslt_add_attributes_from_sets_1 (xparse_ctx_t *xp, caddr_t *attr_sets, xslt_sheet_t *xsh, int level)
{
  int inx1, inx2;
  for (inx1 = 1; inx1 < (int) BOX_ELEMENTS (xsh->xsh_compiled_tree); inx1++)
    {
      caddr_t *elt = (caddr_t *)(xsh->xsh_compiled_tree[inx1]);
      if (XSLT_EL_ATTRIBUTE_SET == xslt_arg_elt (elt))
	{
	  char *name = xslt_arg_value_eval (xp, elt, XSLT_ATTR_ATTRIBUTESET_NAME);
	  DO_BOX (caddr_t, set_name, inx2, attr_sets)
	    {
	      if (!strcmp (name, set_name))
		{
		  caddr_t *use_attribute_sets = (caddr_t *) xslt_arg_value (elt, XSLT_ATTR_ATTRIBUTESET_USEASETS);
		  if (use_attribute_sets)
		    xslt_add_attributes_from_sets (xp, use_attribute_sets, level + 1);
		  xslt_instantiate_children (xp, elt);
		  break;
		}
	    }
	  END_DO_BOX;
	  dk_free_box (name); /* IvAn/011115/XsltAttrTemplateLeak */
	}
    }
}


static void
xslt_add_attributes_from_sets (xparse_ctx_t * xp, caddr_t *attr_sets, int level)
{
  int inx;
  if (level > MAX_ATTRIBUTE_SETS_DEPTH)
    sqlr_new_error ("XS370", "XS005",
	"Max nesting (%d) of XSL-T attribute-sets exceeded", MAX_ATTRIBUTE_SETS_DEPTH);
  DO_BOX (xslt_sheet_t *, xsh, inx, xp->xp_sheet->xsh_imported_sheets)
    {
      xslt_add_attributes_from_sets_1 (xp, attr_sets, xsh, level);
    }
  END_DO_BOX;
  xslt_add_attributes_from_sets_1 (xp, attr_sets, xp->xp_sheet, level);
}


void
xslt_copy_1 (xparse_ctx_t * xp, caddr_t * xstree)
{
  /* make the attributes instantiating the value templates as attribute children and
  * make an xp_node_t to collect the children of this */
  int inx, len;
  caddr_t * head = XTE_HEAD (xstree);
  xslt_element_start (xp, box_copy (head[0]));
  len = BOX_ELEMENTS (head);
  for (inx = 1; inx < len; inx += 2)
    {
      if (is_xslns (head[inx]))
	{
	  char *name = head[inx];
	  char *colon = strrchr (name, ':');
	  if (colon && !strcmp (colon + 1, "use-attribute-sets") &&
	      DV_TYPE_OF (head[inx + 1]) == DV_ARRAY_OF_POINTER)
	    xslt_add_attributes_from_sets (xp, (caddr_t *) head[inx + 1], 0);
	}
    }
  for (inx = 1; inx < len; inx += 2)
    {
      if (!is_xslns (head[inx]))
	xp_dyn_attr (xp, box_copy (head[inx]), xslt_attr_template (xp, head[inx + 1]));
    }
  xslt_instantiate_children (xp, xstree);
  xslt_element_end (xp);
}

void
xslt_variable (xparse_ctx_t * xp, caddr_t * xstree)
{
  caddr_t val;
  caddr_t name = xslt_arg_value (xstree, XSLT_ATTR_VARIABLEORPARAM_NAME);
  xp_query_t * sel = (xp_query_t *) xslt_arg_value (xstree, XSLT_ATTR_VARIABLEORPARAM_SELECT);
  xqi_binding_t *saved_xp_locals = xp->xp_locals;
  if (sel)
    {
      if (XPDV_NODESET == xt_predict_returned_type (sel->xqr_tree))
	{
	  val = xslt_eval_1 (xp, sel, xp->xp_current_xe, XQ_NODE_SET, DV_UNKNOWN);
	}
      else
	{
	  val = xslt_eval_1 (xp, sel, xp->xp_current_xe, XQ_VALUE, DV_UNKNOWN /*DV_LONG_STRING*/);
	}
    }
  else if (1 < BOX_ELEMENTS (xstree))
    {
      xml_tree_ent_t *val_xte;
      xslt_element_start (xp, uname__root);
      xslt_instantiate_children (xp, xstree);
      xslt_element_end (xp);
      val = (caddr_t) dk_set_pop (&xp->xp_current->xn_children);
      val_xte = (xml_tree_ent_t *) xte_from_tree (val, xp->xp_qi);
      val_xte->xe_doc.xd->xd_dtd = dtd_alloc();
      dtd_addref (val_xte->xe_doc.xd->xd_dtd, 0);
      val_xte->xe_doc.xtd->xd_uri = box_dv_short_string ("[value of an XSLT variable]");
      val = (caddr_t)val_xte;	/* No free of old value because it's a part of the document */
      while (xp->xp_locals != saved_xp_locals)
	{ /* This is for case <xml:variable name="a"><xml:variable name="b">...</xml:variable>...</xml:variable> */
	  xqi_binding_t * xb = xp->xp_locals;
	  dk_free_tree (xb->xb_value);
	  xp->xp_locals = xb->xb_next;
	  dk_free ((caddr_t) xb, sizeof (xqi_binding_t));
	}
    }
  else
    val = box_dv_short_string ("");
  do {
    NEW_VARZ (xqi_binding_t, xb);
    xb->xb_name = name;
    xb->xb_value = val;
    xb->xb_next = xp->xp_locals;
    xp->xp_locals = xb;
  } while (0);
}


void
xslt_message (xparse_ctx_t * xp, caddr_t * xstree)
{
  caddr_t terminate = xslt_arg_value (xstree, XSLT_ATTR_MESSAGE_TERMINATE);
  caddr_t string;
  dk_session_t * out;
  caddr_t val;
  xslt_element_start (xp, uname__root);
  xslt_instantiate_children (xp, xstree);
  xslt_element_end (xp);
  val = (caddr_t) dk_set_pop (&xp->xp_current->xn_children);
  val = (caddr_t) xte_from_tree (val, xp->xp_qi);
  out = strses_allocate ();
  xte_serialize ((xml_entity_t *) val, out);
  string = strses_string (out);
  if ((NULL != terminate) && (!strcmp (terminate, "yes")))
    {
      char buf[1000];
      strncpy (buf, string, 999);
      buf[999] = '\0';
      dk_free_box (string);
      dk_free_box ((caddr_t) out);
      dk_free_tree (val);
      sqlr_new_error_xsltree_xdl ("XS370", "XS056", xstree,
        "Stylesheet terminated: %s", buf);
    }
  printf ("XSLT: %s\n", string);
  dk_free_box (string);
  dk_free_box ((caddr_t) out);
  dk_free_tree (val);
}

void
xslt_parameter (xparse_ctx_t * xp, caddr_t * xstree)
{
  /* if not bound, do like with variable */
  caddr_t name = xslt_arg_value (xstree, XSLT_ATTR_VARIABLEORPARAM_NAME);
  xqi_binding_t * xb = xp->xp_locals;
  while (xb)
    {
      if (!xb->xb_name)
	break;
      if (xb->xb_name == name)
	return;
      xb = xb->xb_next;
    }
  xb = xp->xp_globals;
  while (xb)
    {
      if (!xb->xb_name)
	break;
      if (xb->xb_name == name)
	return;
      xb = xb->xb_next;
    }
  xslt_variable (xp, xstree);
}


#define WITH_MODE(t) \
{ \
  caddr_t mprev = xp->xp_mode; \
  xp->xp_mode = t; \


#define END_WITH_MODE \
  xp->xp_mode = mprev; \
}


xslt_sheet_t *xslt_copy_sheet = NULL;

void
xp_xe_copy (xparse_ctx_t * xp, xml_entity_t * elt)
{
  xslt_sheet_t * old_xsh = xp->xp_sheet;
  xml_entity_t * old_xe = xp->xp_current_xe;
  xp->xp_sheet = xslt_copy_sheet;
  WITH_MODE (NULL)
    {
      xp->xp_current_xe = elt;
      xslt_traverse_1 (xp);
    }
  END_WITH_MODE;
  xp->xp_current_xe = old_xe;
  xp->xp_sheet = old_xsh;
}


void
xslt_copy_of (xparse_ctx_t * xp, caddr_t * xstree)
{
  int inx, inx2;
  xp_query_t * sel = (xp_query_t *) xslt_arg_value (xstree, XSLT_ATTR_COPYOF_SELECT);
  caddr_t val = xslt_eval_1 (xp, sel, xp->xp_current_xe, XQ_NODE_SET, DV_UNKNOWN);
  caddr_t * set = (caddr_t*) val;
  DO_BOX (caddr_t *, elt, inx2, set)
    {
      dtp_t elt_dtp = DV_TYPE_OF (elt);
      switch (elt_dtp)
	{
	case DV_XML_ENTITY:
	  xp_xe_copy (xp, (xml_entity_t *) elt);
	  continue;
	case DV_ARRAY_OF_POINTER:
	    {
	      int len = BOX_ELEMENTS ((caddr_t)elt);
	      int flush_needed = strses_length ((xp)->xp_strses);
	      for (inx = 1; inx < len; inx++)
		{
		  caddr_t sub = elt[inx];
		  if (DV_STRING != DV_TYPE_OF (sub))
		    {
		      if (flush_needed)
			{
			  XP_STRSES_FLUSH_NOCHECK (xp);
			  flush_needed = 0;
			}
		      dk_set_push (&xp->xp_current->xn_children, (void*) sub);
		      elt[inx] = NULL;
		      continue;
		    }
		  if (!flush_needed && (inx < (len-1)))
		    {
		      dk_set_push (&xp->xp_current->xn_children, (void*) sub);
		      elt[inx] = NULL;
		      continue;
		    }
		  xslt_character (xp, sub);
	        }
	      continue;
	    }
	case DV_STRING:
	    {
	      xslt_character (xp, (caddr_t)(elt));
	      continue;
	    }
	default:
	    {
	      caddr_t strg = xp_string (xp->xp_qi, (caddr_t) elt);
	      xslt_character (xp, strg);
	      dk_free_box (strg);
	    }
	}
    }
  END_DO_BOX;
  dk_free_tree (val);
}


void
xslt_value_of (xparse_ctx_t * xp, caddr_t * xstree)
{
  xp_query_t * sel = (xp_query_t *) xslt_arg_value (xstree, XSLT_ATTR_VALUEOF_SELECT);
  caddr_t out_escaping = xslt_arg_value (xstree, XSLT_ATTR_VALUEOF_DISOESC);
  caddr_t val;
  val = xslt_eval_1 (xp, sel, xp->xp_current_xe, XQ_VALUE, DV_LONG_STRING);
  if (out_escaping && !strcmp (out_escaping, "yes"))
    {
      XP_STRSES_FLUSH (xp);
      dk_set_push (&xp->xp_current->xn_children ,
	list (2,
	  list (1, uname__disable_output_escaping),
	  val ) );
    }
  else
    {
      xslt_character (xp, val);
      dk_free_box (val);
    }
}


void
xslt_text (xparse_ctx_t * xp, caddr_t * xstree)
{
  int ctr, len = BOX_ELEMENTS (xstree);
  caddr_t out_escaping = xslt_arg_value (xstree, XSLT_ATTR_TEXT_DISOESC);
  int disable_esc;
  caddr_t val;
  caddr_t * elt;
  if (len < 2)
    return;
  disable_esc = out_escaping && !strcmp (out_escaping, "yes");
  if ((2 == len) && !disable_esc && DV_STRINGP(xstree[1]))
    {
      xslt_character (xp, xstree[1]);
      return;
    }
  xslt_element_start (xp, box_dv_short_string ("temp"));
  xslt_instantiate_children (xp, xstree);
  xslt_element_end (xp);
  elt =(caddr_t *) dk_set_pop (&xp->xp_current->xn_children);
  if (disable_esc)
    {
      if (BOX_ELEMENTS (elt) == 1)
	val = box_dv_short_string ("");
      else
	{
	  if (BOX_ELEMENTS (elt) > 2 || !DV_STRINGP (elt[1]))
	    sqlr_new_error_xsltree_xdl ("XS370", "XS006", xstree,
		"xsl:text with disable-output-escaping=on has not-a-string content");
	  val = elt[1];
	  elt[1] = NULL;
	}
      dk_free_tree ((caddr_t) elt);
      XP_STRSES_FLUSH (xp);
      dk_set_push (&xp->xp_current->xn_children,
	(void*) list (2,
	  list (1, uname__disable_output_escaping),
	  val ) );
      return;
    }
  len = BOX_ELEMENTS (elt);
  for (ctr = 1; ctr < len; ctr++)
    {
      dtp_t child_dtp;
      val = elt[ctr];
      child_dtp = DV_TYPE_OF (val);
      switch (child_dtp)
	{
	case DV_SHORT_STRING:
	  xslt_character (xp, val);
	  break;
	case DV_XML_ENTITY:
	  {
	    caddr_t res = NULL;
	    xe_string_value_1 ((xml_entity_t *)val, &res, DV_SHORT_STRING);
	    if (NULL != res)
	      xslt_character (xp, res);
	    dk_free_box (res);
	  }
	  break;
	default:
	  break;
	}
    }
}


void
xslt_pass_params (xparse_ctx_t * xp, caddr_t * xstree)
{
  int inx;
  xqi_binding_t *delim_xb, *saved_xp_prepared_parameters;
  NEW_VARZ (xqi_binding_t, xb);
  saved_xp_prepared_parameters = xb->xb_next = xp->xp_prepared_parameters;
  xp->xp_prepared_parameters = delim_xb = xb;
/* While parameter values are calculated, xp_local remains unchanged to allow the use of current local scope. */
  for (inx = 1; inx < (int) BOX_ELEMENTS (xstree); inx++)
    {
      caddr_t * elt = (caddr_t*) xstree[inx];
      if (XSLT_EL_WITH_PARAM == xslt_arg_elt (elt))
	{
#ifdef DEBUG
	  xqi_binding_t *saved_locals = xp->xp_locals;
#endif
	  xslt_variable (xp, elt);
	  xb = xp->xp_locals;
	  xp->xp_locals = xb->xb_next;
#ifdef DEBUG
	  if (xp->xp_locals != saved_locals)
	    GPF_T;
#endif
	  xb->xb_next = xp->xp_prepared_parameters;
	  xp->xp_prepared_parameters = xb;
	}
    }
/* When all parameters are OK, the content of xp_prepared_parameters becomes a new head of xp_locals */
  delim_xb->xb_next = xp->xp_locals;
  xp->xp_locals = xp->xp_prepared_parameters;
  xp->xp_prepared_parameters = saved_xp_prepared_parameters;
}


void
xslt_pop_params (xparse_ctx_t * xp, xqi_binding_t *old_locals)
{
  xqi_binding_t * xb = xp->xp_locals;
#ifdef XPATH_DEBUG
#ifdef MALLOC_DEBUG
  {
    xqi_binding_t * xb1 = xp->xp_locals;
    xqi_binding_t * xb2 = xp->xp_locals;
    int hit = 0;
    while (xb2)
      {
        dk_check_tree (xb2->xb_value);
        if (xb2 == old_locals)
          hit = 1;
        xb2 = xb2->xb_next;
        if (xb2 == old_locals)
          hit = 1;
        if (NULL == xb2)
          break;
        dk_check_tree (xb2->xb_value);
        xb2 = xb2->xb_next;
        xb1 = xb1->xb_next;
        if (xb1 == xb2)
	  GPF_T1 ("Cycle in xp_locals found by xslt_pop_params()");
      }
    if (!hit && (NULL != old_locals))
      GPF_T1 ("Failed xslt_pop_params()");
  }
#endif
#endif
  while (xb != old_locals)
    {
      xqi_binding_t * next = xb->xb_next;
      dk_free_tree (xb->xb_value);
      dk_free ((caddr_t) xb, sizeof (xqi_binding_t));
      xb = next;
    }
  xp->xp_locals = old_locals;
}


int
xslt_elt_cmp (caddr_t * e1, caddr_t * e2, xslt_sort_t * specs)
{
  int len = BOX_ELEMENTS (e1);
  int inx;
  for (inx = 0; inx < len - 1; inx++)
    {
      int rc =
	((specs[inx].xs_is_desc) ?
	  cmp_boxes (e2[inx], e1[inx], NULL, NULL) :
	  cmp_boxes (e1[inx], e2[inx], NULL, NULL) );
      if (rc != DVC_MATCH)
	return rc;
    }
  return DVC_MATCH;
}


void
xslt_bsort (caddr_t ** bs, int n_bufs, xslt_sort_t * specs)
{
  /* Bubble sort n_bufs first buffers in the array. */
  int n, m;
  for (m = n_bufs - 1; m > 0; m--)
    {
      for (n = 0; n < m; n++)
	{
	  caddr_t *tmp;
	  if (DVC_GREATER == xslt_elt_cmp (bs[n], bs[n + 1], specs))
	    {
	      tmp = bs[n + 1];
	      bs[n + 1] = bs[n];
	      bs[n] = tmp;
	    }
	}
    }
}


static void
xslt_qsort_reverse_buffer (caddr_t **in, int n_in)
{
  int inx, end = n_in - 1;
  for (inx = 0; inx < n_in / 2; inx ++)
    if (inx != end - inx)
      {
	caddr_t *temp = in[inx];
	in[inx] = in[end - inx];
	in[end - inx] = temp;
      }
}


void
xslt_qsort (caddr_t ** in, caddr_t ** left,
	    int n_in, int depth, xslt_sort_t * specs)
{
  if (n_in < 2)
    return;
  if (n_in < 3)
    {
      if (DVC_GREATER == xslt_elt_cmp (in[0], in[1], specs))
	{
	  caddr_t *tmp = in[0];
	  in[0] = in[1];
	  in[1] = tmp;
	}
    }
  else
    {
      caddr_t * split;
      caddr_t * mid_buf = NULL;
      int n_left = 0, n_right = n_in - 1;
      int inx, above_is_all_splits = 1;
      if (depth > 60)
	{
	  xslt_bsort (in, n_in, specs);
	  return;
	}

      split = in[n_in / 2];

      for (inx = 0; inx < n_in; inx++)
	{
	  caddr_t * this_pg = in[inx];
	  int rc = xslt_elt_cmp (this_pg, split, specs);
	  if (!mid_buf && DVC_MATCH == rc)
	    {
	      mid_buf = in[inx];
	      continue;
	    }
	  if (DVC_LESS == rc)
	    {
	      left[n_left++] = in[inx];
	    }
	  else
	    {
	      if (above_is_all_splits && rc == DVC_GREATER)
		above_is_all_splits = 0;
	      left[n_right--] = in[inx];
	    }
	}
      xslt_qsort (left, in, n_left, depth + 1, specs);
      xslt_qsort_reverse_buffer (left + n_right + 1, (n_in - n_right) - 1);
      if (!above_is_all_splits)
	xslt_qsort (left + n_right + 1, in + n_right + 1,
	    (n_in - n_right) - 1, depth + 1, specs);
      memcpy (in, left, n_left * sizeof (caddr_t));
      in[n_left] = mid_buf;
      memcpy (in + n_right + 1, left + n_right + 1,
	  ((n_in - n_right) - 1) * sizeof (caddr_t));

    }
}


void
xslt_sort (xparse_ctx_t * xp, caddr_t * elt, caddr_t * ct2)
{
  caddr_t ** content = (caddr_t **) ct2;
  caddr_t ** temp;
  size_t temp_len;
  int inx, fill = 0, ctx_sz = BOX_ELEMENTS (content);
  long save_pos, save_size;
  xslt_sort_t specs[16];
  memset (specs, 0, sizeof (specs));
  for (inx = 1; inx < (int) BOX_ELEMENTS (elt); inx++)
    {
      caddr_t * part = (caddr_t*) elt[inx];
      if (XSLT_EL_SORT == xslt_arg_elt (part))
	{
	  caddr_t tp = xslt_arg_value (part, XSLT_ATTR_SORT_DATATYPE);
	  caddr_t ord = xslt_arg_value (part, XSLT_ATTR_SORT_ORDER);
	  specs[fill].xs_query = (xp_query_t *) xslt_arg_value (part, XSLT_ATTR_SORT_SELECT);
	  if (ord != NULL && strstr (ord, "de"))
	    specs[fill].xs_is_desc = 1;
	  specs[fill].xs_type = (caddr_t) (ptrlong)(
	    ((tp != NULL) && strstr (tp, "nu")) ?
	    DV_NUMERIC : DV_LONG_STRING );
	  fill++;
	  if (fill > sizeof (specs) / sizeof (xslt_sort_t))
	    break;
	}
    }
  if (!fill)
    return;
  XP_CTX_POS_GET (xp, save_size, save_pos);
  DO_BOX (xml_entity_t *, xe, inx, content)
    {
      caddr_t * elt;
      int n;
      if (DV_XML_ENTITY != DV_TYPE_OF (xe))
	sqlr_new_error_xdl ("XS370", "XS007", &(specs[0].xs_query->xqr_xdl), "Element in set to be sorted must be an XML node");
      elt = (caddr_t *) dk_alloc_box ((fill + 1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      memset (elt, 0, box_length ((caddr_t) elt));
      elt[fill] = (caddr_t) content[inx];
      content[inx] = (caddr_t *) elt;
      XP_CTX_POS (xp, ctx_sz, inx + 1);
      for (n = 0; n < fill; n++)
	{
	  caddr_t val = NULL;
	  if (specs[n].xs_query)
	    {
	      val = xslt_eval_1 (xp, specs[n].xs_query, xe, XQ_VALUE, DV_LONG_STRING);
	    }
	  else
	    {
	      xe->_->xe_string_value (xe, &val, DV_SHORT_STRING);
	    }
	  elt[n] = val;
	  if (DV_NUMERIC == (dtp_t)((ptrlong)(specs[n].xs_type)))
	    {
	      elt[n] = xp_box_number (val);
	      dk_free_box (val);
	    }
	}
    }
  END_DO_BOX;
  XP_CTX_POS (xp, save_size, save_pos);
  /* '+1' is to prevent dk_alloc (0) and then dk_free ((), 0) */
  temp_len = box_length ((caddr_t) content)+1;
  temp = (caddr_t**) dk_alloc (temp_len);
#if 1
  xslt_qsort (content, temp, BOX_ELEMENTS (content), 0, specs);
#else
  xslt_bsort (content, BOX_ELEMENTS (content), specs);
#endif
  dk_free ((caddr_t) temp, temp_len);
  DO_BOX (caddr_t *, elt, inx, content)
    {
      content[inx] = (caddr_t *) elt[fill];
      elt[fill] = NULL;
      dk_free_tree ((caddr_t) elt);
      }
  END_DO_BOX;
}


void
xslt_apply_templates (xparse_ctx_t * xp, caddr_t * xstree)
{
  xp_query_t * sel = (xp_query_t *) xslt_arg_value (xstree, XSLT_ATTR_APPLYTEMPLATES_SELECT);
  xml_entity_t * curr_xe = xp->xp_current_xe;
  caddr_t mode = xslt_arg_value (xstree, XSLT_ATTR_APPLYTEMPLATES_MODE);
  long save_pos, save_size;
  WITH_MODE (mode)
    {
      if (!sel)
	{
	  if (NULL == curr_xe->xe_attr_name)
	    {
	      xqi_binding_t * saved_locals = xp->xp_locals;
	      xslt_pass_params (xp, xstree);
	      xslt_process_children (xp, curr_xe);
	      xslt_pop_params (xp, saved_locals);
	    }
	}
      else
	{
	  xqi_binding_t * saved_locals = xp->xp_locals;
	  xml_entity_t * old_xe = xp->xp_current_xe;
	  int inx;
	  caddr_t * set;
	  int ctx_sz;
	  int predicted = xt_predict_returned_type (sel->xqr_tree);
	  if ((XPDV_NODESET != predicted) && (DV_UNKNOWN != predicted))
	    sqlr_new_error_xdl ("XS370", "XS008", &(sel->xqr_xdl), "Non-node-set expression");
	  set = (caddr_t *) xslt_eval_1 (xp, sel, curr_xe, XQ_NODE_SET, DV_UNKNOWN);
	  xslt_pass_params (xp, xstree);
	  xp_temp (xp, (caddr_t) set);
	  xslt_sort (xp, xstree, set);
	  ctx_sz = BOX_ELEMENTS (set);
	  XP_CTX_POS_GET (xp, save_size, save_pos);
	  DO_BOX (xml_entity_t *, xe, inx, set)
	    {
	      dtp_t xe_dtp = DV_TYPE_OF (xe);
	      if (DV_XML_ENTITY != xe_dtp)
		sqlr_new_error_xdl ("XS370", "XS009", &(sel->xqr_xdl), "Not an entity is returned");
	      xp->xp_current_xe = xe;
	      XP_CTX_POS (xp, ctx_sz, inx + 1);
	      xslt_traverse_1 (xp);
	    }
	  END_DO_BOX;
	  XP_CTX_POS (xp, save_size, save_pos);
	  xp_temp_free (xp, (caddr_t) set);
	  xp->xp_current_xe = old_xe;
	  xslt_pop_params (xp, saved_locals);
	}
    }
  END_WITH_MODE;
}


void
xslt_call_template (xparse_ctx_t * xp, caddr_t * xstree)
{
  xqi_binding_t * saved_locals = xp->xp_locals;
  caddr_t name = xslt_arg_value (xstree, XSLT_ATTR_CALLTEMPLATE_NAME);
  xslt_template_t * xst;
  QI_CHECK_STACK (xp->xp_qi, &xst, 8000);
  if (xp->xp_qi->qi_client->cli_terminate_requested)
    sqlr_new_error_xsltree_xdl ("37000", "SR367", xstree, "XSLT aborted by client request");
#ifdef DEBUG
  if ((NULL == name) || (DV_UNAME != DV_TYPE_OF (name)))
    GPF_T;
#endif
  xst = (xslt_template_t *) gethash (name, xp->xp_sheet->xsh_all_templates_byname);
  if (NULL == xst)
    sqlr_new_error_xsltree_xdl ("XS370", "XS010", xstree, "XSLT template '%s' not found", name);
  if (xslt_measure_uses)
    xst->xst_new_uses.xstu_byname_calls++;
  xslt_pass_params (xp, xstree);
  xslt_instantiate (xp, xst, xp->xp_current_xe);
  xslt_pop_params (xp, saved_locals);
}


void
xslt_apply_imports (xparse_ctx_t * xp, caddr_t * xstree)
{
  xslt_traverse_inner (xp, xp->xp_template->xst_sheet);
}


void
xslt_for_each (xparse_ctx_t * xp, caddr_t * xstree)
{
  int inx2, ctx_sz;
  xml_entity_t * old_xe = xp->xp_current_xe;
  xp_query_t * sel = (xp_query_t *) xslt_arg_value (xstree, XSLT_ATTR_FOREACH_SELECT);
  caddr_t * set;
  long save_pos, save_size;
  set = (caddr_t*) xslt_eval_1 (xp, sel, xp->xp_current_xe, XQ_NODE_SET, DV_UNKNOWN);
  xp_temp (xp, (caddr_t) set);
  if (!set || 0 == BOX_ELEMENTS (set))
    return;
  if (DV_ARRAY_OF_XQVAL != DV_TYPE_OF (set))
    sqlr_new_error_xdl ("XS370", "XS011", &(sel->xqr_xdl), "select in for-each must return a node set");
  xslt_sort (xp, xstree, set);
  ctx_sz = BOX_ELEMENTS (set);
  XP_CTX_POS_GET (xp, save_size, save_pos);
  DO_BOX (xml_entity_t *, xe, inx2, set)
    {
      dtp_t xe_dtp = DV_TYPE_OF (xe);
      if (DV_XML_ENTITY != xe_dtp)
	sqlr_new_error_xdl ("XS370", "XS012", &(sel->xqr_xdl), "Not an entity is returned");
      xp->xp_current_xe = xe;
      XP_CTX_POS (xp, ctx_sz, inx2 + 1);
      xslt_instantiate_children (xp, xstree);
    }
  END_DO_BOX;
  XP_CTX_POS (xp, save_size, save_pos);
  xp_temp_free (xp, (caddr_t) set);
  xp->xp_current_xe = old_xe;
}


void
xslt_for_each_row (xparse_ctx_t * xp, caddr_t * xstree)
{
  int query_is_sparql = 0;
  xp_query_t * stmt_text_sel;
  caddr_t *query_texts_set, query_text, query_final_text;
  int proc_parent_is_saved = 0;
  query_instance_t *qi = xp->xp_qi;
  client_connection_t *cli = qi->qi_client;
  shcompo_t *query_shc = NULL;
  query_t *qr = NULL;
  caddr_t err = NULL;
  dk_set_t warnings = NULL;
  caddr_t *params = NULL;
  int param_ofs;
  stmt_compilation_t *comp = NULL, *proc_comp = NULL;
  dk_set_t proc_resultset = NULL;
  local_cursor_t *lc = NULL;
  int cols_count, col_ctr;
  PROC_SAVE_VARS;
  stmt_text_sel = (xp_query_t *) xslt_arg_value (xstree, XSLT_ATTR_FOREACHROW_SPARQL);
  if (NULL != stmt_text_sel)
    query_is_sparql = 1;
  else
    stmt_text_sel = (xp_query_t *) xslt_arg_value (xstree, XSLT_ATTR_FOREACHROW_SQL);
  query_texts_set = (caddr_t*) xslt_eval_1 (xp, stmt_text_sel, xp->xp_current_xe, XQ_NODE_SET, DV_UNKNOWN);
  xp_temp (xp, (caddr_t) query_texts_set);
  if (1 != BOX_ELEMENTS (query_texts_set))
    sqlr_new_error_xdl ("XS370", "XS072", &(stmt_text_sel->xqr_xdl), "sparql or sql attribute in xsl:for-each-row must return exactly one value");
  query_text = query_texts_set[0];
  if (DV_STRING != DV_TYPE_OF (query_text))
    {
      if (DV_XML_ENTITY == DV_TYPE_OF (query_text))
        {
          xml_entity_t *xe = (xml_entity_t *)query_text;
          caddr_t sval = NULL;
          xe->_->xe_string_value (xe, &sval, DV_STRING);
          query_text = sval;
        }
      else
        sqlr_new_error_xdl ("XS370", "XS068", &(stmt_text_sel->xqr_xdl), "sparql or sql attribute in xsl:for-each-row must return a single string");
    }
  if (query_is_sparql)
    {
      caddr_t preamble = xp->xp_sheet->xsh_sparql_preamble;
      if (NULL == preamble)
        {
          dk_session_t *tmp_ses = strses_allocate ();
          xml_ns_2dict_t *ns2d = &(xp->xp_sheet->xsh_ns_2dict);
          int ns_ctr = ns2d->xn2_size;
          SES_PRINT (tmp_ses, "sparql define output:valmode \"AUTO\" define sql:globals-mode \"XSLT\" ");
          while (ns_ctr--)
            {
              SES_PRINT (tmp_ses, "prefix ");
              SES_PRINT (tmp_ses, ns2d->xn2_prefix2uri[ns_ctr].xna_key);
              SES_PRINT (tmp_ses, ": <");
              SES_PRINT (tmp_ses, ns2d->xn2_prefix2uri[ns_ctr].xna_value);
              SES_PRINT (tmp_ses, "> ");
            }
          preamble = xp->xp_sheet->xsh_sparql_preamble = strses_string (tmp_ses);
          dk_free_box (tmp_ses);
        }
      query_final_text = box_dv_short_strconcat (preamble, query_text);
      if (query_text != query_texts_set[0])
        dk_free_box (query_text);
    }
  else
    query_final_text = (query_text != query_texts_set[0]) ? query_text : box_copy (query_text);
  PROC_SAVE_PARENT;
  proc_parent_is_saved = 1;
  warnings = sql_warnings_save (NULL);
  cli->cli_resultset_max_rows = -1;
  cli->cli_resultset_comp_ptr = (caddr_t *) &proc_comp;
  cli->cli_resultset_data_ptr = &proc_resultset;
  query_shc = shcompo_get_or_compile (&shcompo_vtable__qr, list (3, query_final_text, qi->qi_u_id, qi->qi_g_id), 0, qi, NULL, &err);
  if (NULL == err)
    {
      shcompo_recompile_if_needed (&query_shc);
      if (NULL != query_shc->shcompo_error)
        err = box_copy_tree (query_shc->shcompo_error);
    }
  if (NULL != err)
    goto err_generated;
  qr = (query_t *)(query_shc->shcompo_data);
  params = (caddr_t *)dk_alloc_box_zero (dk_set_length (qr->qr_parms) * 2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  xp_temp (xp, (caddr_t) params);
  param_ofs = 0;
  DO_SET (state_slot_t *, ssl, &qr->qr_parms)
    {
      char *name = ssl->ssl_name;
      xqi_binding_t *xb;
      if ((NULL == name) || (':' != name[0]) || alldigits (name+1))
        {
          err = sqlr_make_new_error_xdl ("XS370", "XS069", &(stmt_text_sel->xqr_xdl), "%s parameter of the query can not be bound, only named parameters can be associated with XSLT variables of the context", ((NULL!=name) ? name : "anonymous"));
          goto err_generated; /* see below */
        }
      for (xb = xp->xp_locals; (NULL != xb) && (NULL != xb->xb_name); xb = xb->xb_next)
        {
          if (!strcmp (name+1, xb->xb_name))
            goto xb_found; /* see below */
        }
      for (xb = xp->xp_globals; NULL != xb; xb = xb->xb_next)
        {
          if (!strcmp (name+1, xb->xb_name))
            goto xb_found; /* see below */
        }
      err = sqlr_make_new_error_xdl ("XS370", "XS070", &(stmt_text_sel->xqr_xdl), "%s%.100s parameter of the query can not be bound, there's no corresponding XSLT variable $%.100s",
        query_is_sparql ? "$" : "", name, name+1 );
      goto err_generated; /* see below */
xb_found:
      params[param_ofs++] = box_copy (name);
      params[param_ofs++] = ((NULL == xb->xb_value) ? NEW_DB_NULL : box_copy_tree (xb->xb_value));
    }
  END_DO_SET ()
  err = qr_exec (cli, qr, qi, NULL, NULL, &lc,
      params, NULL, 1);
  memset (params, 0, param_ofs * sizeof (caddr_t));
  xp_temp_free (xp, (caddr_t) params);
  params = NULL;
  if (err)
    goto err_generated; /* see below */
  if ((NULL == lc) || !(qr->qr_select_node))
    {
      err = sqlr_make_new_error_xdl ("XS370", "XS071", &(stmt_text_sel->xqr_xdl), "%s statement did not produce any (even empty) result-set",
        query_is_sparql ? "SPARQL" : "SQL");
      goto err_generated; /* see below */
    }
  PROC_RESTORE_SAVED;
  proc_parent_is_saved = 0;
  if (proc_comp)
    {
      dk_free_tree ((caddr_t) proc_comp);
      proc_comp = NULL;
    }
  if (proc_resultset)
    {
      dk_free_tree (list_to_array (proc_resultset));
      proc_resultset = NULL;
    }
  comp = qr_describe (qr, NULL);
  cols_count = BOX_ELEMENTS (comp->sc_columns);
  for (col_ctr = cols_count; col_ctr--; /* no step */)
    {
      col_desc_t *cd = (col_desc_t *)(comp->sc_columns[col_ctr]);
      NEW_VARZ (xqi_binding_t, xb);
      xb->xb_name = box_dv_uname_string (cd->cd_name);
      xb->xb_value = NULL;
      xb->xb_next = xp->xp_locals;
      xp->xp_locals = xb;
    }
  while (lc_next (lc))
    {
      xqi_binding_t *saved_locals = xp->xp_locals;
      xqi_binding_t *xb = saved_locals;
      for (col_ctr = 0; col_ctr < cols_count; col_ctr++)
        {
          caddr_t new_val = lc_nth_col (lc, col_ctr);
          rb_cast_to_xpath_safe (qi, new_val, &(xb->xb_value));
          xb = xb->xb_next;
	}
      xslt_instantiate_children (xp, xstree);
    }
  for (col_ctr = cols_count; col_ctr--; /* no step */)
    {
      xqi_binding_t *xb = xp->xp_locals;
      dk_free_box (xb->xb_name);
      dk_free_tree (xb->xb_value);
      xp->xp_locals = xb->xb_next;
      dk_free (xb, sizeof (xqi_binding_t));
    }
  err = lc->lc_error;
  lc->lc_error = NULL;
  lc_free (lc);
  if (err)
    goto err_generated; /* see below */
#if 0
    { /* handle procedure resultsets */
      if (n_args > 5 && ssl_is_settable (args[5]) && proc_comp)
	qst_set (qst, args[5], (caddr_t) proc_comp);
      else
	dk_free_tree ((caddr_t) proc_comp);

      if (n_args > 6 && ssl_is_settable (args[6]) && proc_resultset)
        {
          caddr_t ** rset = ((caddr_t **)list_to_array (dk_set_nreverse (proc_resultset)));
#ifdef MALLOC_DEBUG
          dk_check_tree (qst_get (qst, args[6]));
          dk_check_tree (rset);
#endif
	  qst_set (qst, args[6], (caddr_t) rset);
#ifdef MALLOC_DEBUG
          dk_check_tree (qst_get (qst, args[6]));
#endif
        }
      else if (n_args > 6 && ssl_is_settable (args[6]) && lc)
	qst_set (qst, args[6], box_num (lc->lc_row_count));
      else
        {
	  dk_free_tree (list_to_array (proc_resultset));
          if (n_args > 6 && ssl_is_settable (args[6]))
            {
#ifdef MALLOC_DEBUG
              dk_check_tree (qst_get (qst, args[6]));
#endif
	      qst_set (qst, args[6], NEW_DB_NULL);
            }
        }
      if (lc)
	{
	  err = lc->lc_error;
	  lc->lc_error = NULL;
	  lc_free (lc);
	  if (err)
	    {
	      res = bif_exec_error (qst, args, err);
	      goto done;
	    }
	}
    }
#endif

  dk_free_tree (list_to_array (sql_warnings_save (warnings)));
#if 0

  xslt_sort (xp, xstree, set);
  ctx_sz = BOX_ELEMENTS (set);
  XP_CTX_POS_GET (xp, save_size, save_pos);
  DO_BOX (xml_entity_t *, xe, inx2, set)
    {
      dtp_t xe_dtp = DV_TYPE_OF (xe);
      if (DV_XML_ENTITY != xe_dtp)
	sqlr_new_error_xdl ("XS370", "XS012", &(sel->xqr_xdl), "Not an entity is returned");
      xp->xp_current_xe = xe;
      XP_CTX_POS (xp, ctx_sz, inx2 + 1);
      xslt_instantiate_children (xp, xstree);
    }
  END_DO_BOX;
  XP_CTX_POS (xp, save_size, save_pos);
  xp_temp_free (xp, (caddr_t) set);
  xp->xp_current_xe = old_xe;
#endif
  return;
err_generated:
  if (lc)
    lc_free (lc);
  if (params)
    xp_temp_free (xp, (caddr_t) params);
  if (NULL != query_shc)
    shcompo_release (query_shc);
  if (proc_parent_is_saved)
    PROC_RESTORE_SAVED;
  xp_temp_free (xp, (caddr_t) query_texts_set);
  sqlr_resignal (err);
}


caddr_t
xslt_attr_or_element_qname (xparse_ctx_t * xp, caddr_t * elt, int use_deflt)
{
  caddr_t name;
  caddr_t ns = NULL;
  caddr_t ns_arg = NULL;
  caddr_t res;
  char * local;
  int local_boxlen, ns_len = 0x7FFF;
  char tmp[MAX_XML_QNAME_LENGTH+4];
  char * colon;
  ns_arg = ns = xslt_arg_value_eval (xp, elt, XSLT_ATTR_ATTRIBUTEORELEMENT_NAMESPACE);
  if (NULL != ns)
    {
      ns_len = box_length (ns) - 1;
      if ((ns_len+1) > MAX_XML_LNAME_LENGTH)
	{
	  dk_free_box (ns_arg);
	  sqlr_new_error_xsltree_xdl ("XS370", "XS057", elt, "The value of the 'namespace' attribute is too long");
	}
    }
  name = xslt_arg_value_eval (xp, elt, XSLT_ATTR_ATTRIBUTEORELEMENT_NAME);
  colon = strrchr (name, ':');
  if (colon)
    {
      caddr_t * xmlns = (caddr_t *) xslt_arg_value (elt, XSLT_ATTR_GENERIC_XMLNS);
      int inx, len;
      local = colon + 1;
      local_boxlen = (int) (name + box_length (name) - (colon + 1));
      if (local_boxlen > MAX_XML_LNAME_LENGTH)
	{
	  dk_free_box (name);
	  dk_free_box (ns_arg);
	  sqlr_new_error_xsltree_xdl ("XS370", "XS055", elt, "The 'local part' of the value of the 'name' attribute is too long");
	}
      if (NULL != ns_arg)
	goto ns_found;
      ns_len = (int) (colon - name);
      if (NULL == xmlns)
	{
	  strcpy_ck (tmp, name);
	  dk_free_box (name);
	  sqlr_new_error_xsltree_xdl ("XS370", "XS045", elt, "Attribute xmlns required for resolving prefix in qualified name '%.500s'", tmp);
	}
      if (bx_std_ns_pref (name, ns_len))
	{
	  ns = "xml";
	  ns_len = 3;
	  goto ns_found;
	}
      len = BOX_ELEMENTS (xmlns);
      for (inx = 0; inx < len; inx += 2)
	{
	  if (NULL == xmlns[inx])
	    continue;
	  if (strncmp (xmlns[inx], name, ns_len))
	    continue;
	  if (ns_len != (int) strlen (xmlns[inx]))
	    continue;
	  ns = xmlns[inx + 1];
	  ns_len = box_length(ns)-1;
	  if ((ns_len+1) > MAX_XML_LNAME_LENGTH)
	    {
	      strcpy_ck (tmp, name);
	      dk_free_box (name);
	      sqlr_new_error_xsltree_xdl ("XS370", "XS054", elt, "The value of the 'xmlns' attribute specifies abnormally long namespace for qualified name '%.500s'", tmp);
	    }
	  goto ns_found;
	}
      strcpy_ck (tmp, name);
      dk_free_box (name);
      sqlr_new_error_xsltree_xdl ("XS370", "XS013", elt, "Bad namespace prefix in qualified name %.500s", tmp);
    }
  else
    {
      local = name;
      local_boxlen = box_length (name);
      if (local_boxlen > MAX_XML_LNAME_LENGTH)
	{
	  dk_free_box (name);
	  dk_free_box (ns_arg);
	  sqlr_new_error_xsltree_xdl ("XS370", "XS056", elt, "The value of the 'name' attribute is too long");
	}
      if (NULL != ns_arg)
	goto ns_found;
      if (use_deflt)
	{
	  caddr_t * xmlns = (caddr_t *) xslt_arg_value (elt, XSLT_ATTR_GENERIC_XMLNS);
	  int inx, len;
	  if (NULL == xmlns)
	    {
	      strcpy_ck (tmp, name);
	      dk_free_box (name);
	      sqlr_new_error_xsltree_xdl ("XS370", "XS046", elt, "Attribute xmlns required for resolving default namespace of qualified name '%.500s'", tmp);
	    }
	  len = BOX_ELEMENTS (xmlns);
	  for (inx = 0; inx < len; inx += 2)
	    {
	      if (NULL != xmlns[inx])
		continue;
	      ns = xmlns[inx + 1];
	      ns_len = box_length(ns)-1;
	      if ((ns_len+1) > MAX_XML_LNAME_LENGTH)
		{
		  strcpy_ck (tmp, name);
		  dk_free_box (name);
		  sqlr_new_error_xsltree_xdl ("XS370", "XS058", elt, "The value of the 'xmlns' attribute specifies abnormally long default namespace for qualified name '%.500s'", tmp);
		}
	      goto ns_found;
	    }
	}
    }
ns_found:
  if (!ns || !ns[0])
    {
      res = box_dv_uname_string (local);
      dk_free_box (ns_arg);
      dk_free_box (name);
      return res;
    }
  res = box_dv_ubuf (ns_len + local_boxlen);
  memcpy (res, ns, ns_len);
  res[ns_len] = ':';
  memcpy (res+ns_len+1, local, local_boxlen);
  dk_free_box (name);
  dk_free_box (ns_arg);
  return box_dv_uname_from_ubuf (res);
}


void
xslt_attribute (xparse_ctx_t * xp, caddr_t * xstree)
{
  caddr_t val = NULL;
  caddr_t * elt;
  caddr_t qname = xslt_attr_or_element_qname (xp, xstree, 0);
  size_t elt_len;
  char signal_id;
  xslt_element_start (xp, box_dv_short_string ("temp"));
  xslt_instantiate_children (xp, xstree);
  xslt_element_end (xp);
  elt = (caddr_t *) (xp->xp_current->xn_children->data);
  elt_len = BOX_ELEMENTS (elt);
  switch (elt_len)
    {
    case 1:
      val = box_dv_short_string ("");
      break;
    case 2:
      if (!DV_STRINGP (elt[1]))
	{
	  if (xslt_is_no_output_escaping_elt(elt[1]))
	    signal_id = 'O';
	  else
	    signal_id = 'S';
	  goto signal;
	}
      val = elt[1];
      elt[1] = NULL;
      break;
    default:
      {
	size_t ctr;
	size_t val_len = 0;
	char *val_tail;
	for (ctr = 1; ctr < elt_len; ctr++)
	  {
	    caddr_t subval = elt[ctr];
	    if (!DV_STRINGP (subval))
	      {
	        if (xslt_is_no_output_escaping_elt(subval))
		  signal_id = 'o';
		else
		  signal_id = 's';
		goto signal;
	      }
	    val_len += box_length(subval)-1;
	  }
	val_tail = val = dk_alloc_box (val_len+1, DV_SHORT_STRING);
	for (ctr = 1; ctr < elt_len; ctr++)
	  {
	    caddr_t subval = elt[ctr];
	    size_t subval_len = box_length(subval)-1;
	    memcpy (val_tail, subval, subval_len);
	    val_tail += subval_len;
	  }
#ifdef DEBUG
	if (val_tail != val+val_len)
	  GPF_T;
#endif
	val_tail[0] = '\0';
      }
    }
  dk_set_pop (&(xp->xp_current->xn_children));
  dk_free_tree ((caddr_t) elt);
  xp_dyn_attr (xp, qname, val);
  return;
signal:
  {
    char tmp[MAX_XML_QNAME_LENGTH+4];
    strcpy_ck (tmp, qname);
    dk_free_box (qname);
    dk_free_tree (val);
    switch (signal_id)
      {
      case 'O': sqlr_new_error_xsltree_xdl ("XS370", "XS015", xstree, "Attribute value for %s is a text with disabled output escaping (it is prohibited by XSLT standard)", tmp);
      case 'S': sqlr_new_error_xsltree_xdl ("XS370", "XS015", xstree, "Attribute value for %s is not a string", tmp);
      case 'o': sqlr_new_error_xsltree_xdl ("XS370", "XS036", xstree, "Attribute value for %s contains a text with disabled output escaping (it is prohibited by XSLT standard)", tmp);
      case 's': sqlr_new_error_xsltree_xdl ("XS370", "XS036", xstree, "Attribute value for %s contains non-string element", tmp);
      default: GPF_T;
      }
  }
}


void
xslt_element (xparse_ctx_t * xp, caddr_t * xstree)
{
  caddr_t qname = xslt_attr_or_element_qname (xp, xstree, 1);
  caddr_t *use_attribute_sets = (caddr_t *) xslt_arg_value (xstree, XSLT_ATTR_ELEMENT_USEASETS);
  xslt_element_start (xp, qname);
  if (use_attribute_sets)
    xslt_add_attributes_from_sets (xp, use_attribute_sets, 0);
  xslt_instantiate_children (xp, xstree);
  xslt_element_end (xp);
}


void
xslt_element_rdfqname (xparse_ctx_t * xp, caddr_t * xstree)
{
  caddr_t name = xslt_arg_value_eval (xp, xstree, XSLT_ATTR_ATTRIBUTEORELEMENT_NAME);
  int name_boxlen = box_length (name);
  int local_boxlen;
  caddr_t qname;
  /* caddr_t *use_attribute_sets */
  int ns_len = -1;
  char *delim, *local;
  delim = strrchr (name, ':');
  if ((NULL != delim) && ((delim - name) >= ns_len))
    ns_len = (delim - name) + 1;
  delim = strrchr (name, '/');
  if ((NULL != delim) && ((delim - name) >= ns_len))

    ns_len = (delim - name) + 1;
  delim = strrchr (name, '#');
  if ((NULL != delim) && ((delim - name) >= ns_len))
    ns_len = (delim - name) + 1;
  if (ns_len < 0)
    {
      if (name_boxlen >= MAX_XML_LNAME_LENGTH)
	{
	  dk_free_box (name);
	  sqlr_new_error_xsltree_xdl ("XS370", "XS064", xstree, "The value of the 'name' attribute is too long");
	}
      qname = box_dv_uname_nchars (name, name_boxlen - 1);
    }
  else
    {
      local = name + ns_len;
      local_boxlen = name_boxlen - ns_len;
      if (':' == name[ns_len - 1])
        ns_len--;
      if (local_boxlen >= MAX_XML_LNAME_LENGTH)
	{
	  dk_free_box (name);
	  sqlr_new_error_xsltree_xdl ("XS370", "XS065", xstree, "The 'local part' of the value of the 'name' attribute is too long");
	}
      if (ns_len > MAX_XML_LNAME_LENGTH)
	{
	  dk_free_box (name);
	  sqlr_new_error_xsltree_xdl ("XS370", "XS055", xstree, "The 'namespace part' of the value of the 'name' attribute is too long");
	}
      qname = box_dv_ubuf (ns_len + local_boxlen);
      memcpy (qname, name, ns_len);
      qname [ns_len] = ':';
      memcpy (qname + ns_len + 1, local, local_boxlen);
      qname = box_dv_uname_from_ubuf (qname);
    }
  dk_free_box (name);
  xslt_element_start (xp, qname);
  /* use_attribute_sets = (caddr_t *) xslt_arg_value (xstree, XSLT_ATTR_ELEMENT_USEASETS);
  if (use_attribute_sets)
    xslt_add_attributes_from_sets (xp, use_attribute_sets, 0);*/
  xslt_instantiate_children (xp, xstree);
  xslt_element_end (xp);
}


void
xslt_pi (xparse_ctx_t * xp, caddr_t * xstree)
{
  caddr_t val;
  caddr_t * elt;
  caddr_t name = xslt_arg_value_eval (xp, xstree, XSLT_ATTR_PI_NAME);
  caddr_t head;
  xslt_element_start (xp, box_dv_short_string ("temp"));
  xslt_instantiate_children (xp, xstree);
  xslt_element_end (xp);
  elt =(caddr_t *)  dk_set_pop (&xp->xp_current->xn_children);
  if (BOX_ELEMENTS (elt) == 1)
    val = NULL;
  else
    {
      if (BOX_ELEMENTS (elt) > 2 || !DV_STRINGP (elt[1]))
	{
	  dk_free_box (name);
	  dk_free_tree ((box_t) elt);
	  sqlr_new_error_xsltree_xdl ("XS370", "XS016", xstree, "Processing instruction body for %s is not a string", name);
	}
      val = elt[1];
      elt[1] = NULL;
    }
  dk_free_tree ((caddr_t) elt);
  head = (caddr_t) list (3,
    uname__pi,
    uname__bang_name,
    box_copy (name) );
  XP_STRSES_FLUSH (xp);
  dk_set_push (&xp->xp_current->xn_children,
    (void*)(
      (NULL != val) ?
      list (2, head, val) :
      list (1, head) ) );
}


void
xslt_sort_elt (xparse_ctx_t * xp, caddr_t * xstree)
{
  /* no operation */
}


void
xslt_comment (xparse_ctx_t * xp, caddr_t * xstree)
{
  caddr_t val;
  caddr_t * elt;
  xslt_element_start (xp, box_dv_short_string ("temp"));
  xslt_instantiate_children (xp, xstree);
  xslt_element_end (xp);
  elt = (caddr_t *) (xp->xp_current->xn_children->data);
  if (BOX_ELEMENTS (elt) == 1)
    val = box_dv_short_string ("");
  else
    {
      if (BOX_ELEMENTS (elt) > 2 || !DV_STRINGP (elt[1]))
	{
	  caddr_t subval = elt[1];
	  if (xslt_is_no_output_escaping_elt(subval))
	    sqlr_new_error_xsltree_xdl ("XS370", "XS017", xstree, "Comment body is a text with disabled output escaping (it is prohibited by XSLT standard)");
	  sqlr_new_error_xsltree_xdl ("XS370", "XS017", xstree, "Comment body is not a string");
	}
      val = elt[1];
      elt[1] = NULL;
    }
  dk_set_pop (&(xp->xp_current->xn_children));
  dk_free_tree ((caddr_t) elt);
  XP_STRSES_FLUSH (xp);
  if (1 < box_length (val))
    dk_set_push (&xp->xp_current->xn_children,
      (void*) list (2,
	list (1, uname__comment),
	val) );
  else
    dk_set_push (&xp->xp_current->xn_children,
      (void*) list (1, list (1, uname__comment)) );
}


void
xslt_if (xparse_ctx_t * xp, caddr_t * xstree)
{
  xp_query_t * test = (xp_query_t *) xslt_arg_value (xstree, XSLT_ATTR_IFORWHEN_TEST);
  if (xslt_eval_1 (xp, test, xp->xp_current_xe, XQ_TRUTH_VALUE, DV_UNKNOWN))
    xslt_instantiate_children (xp, xstree);
}


void
xslt_choose (xparse_ctx_t * xp, caddr_t * xstree)
{
  int inx;
  xp_query_t * test;
  for (inx = 1; inx < (int) BOX_ELEMENTS (xstree); inx++)
    {
      caddr_t * clause = (caddr_t*) xstree[inx];
      switch (xslt_arg_elt (clause))
        {
        case XSLT_EL_WHEN:
	  test = (xp_query_t *) xslt_arg_value (clause, XSLT_ATTR_IFORWHEN_TEST);
	  if (xslt_eval_1 (xp, test, xp->xp_current_xe, XQ_TRUTH_VALUE, DV_UNKNOWN))
	    {
	      xslt_instantiate_children (xp, clause);
	      return;
	    }
	  break;
	case XSLT_EL_OTHERWISE:
	  xslt_instantiate_children (xp, clause);
	  return;
	}
    }
}


void
xslt_copy (xparse_ctx_t * xp, caddr_t * xstree)
{
  caddr_t *use_attribute_sets = (caddr_t *) xslt_arg_value (xstree, XSLT_ATTR_COPY_USEASETS);
  xml_entity_t * xe = xp->xp_current_xe;
  caddr_t name;
  if (xe->xe_attr_name)
    {
      caddr_t val = NULL;
      xe_string_value_1 (xe, &val, DV_LONG_STRING);
      xp_dyn_attr (xp, box_copy (xe->xe_attr_name), val);
      return;
    }
  name = xe->_->xe_element_name (xe);
  if (' ' == name[0])
    {
      if (uname__txt == name)
	{
	  caddr_t val = NULL;
	  /* useless dk_free_box (name); */
	  xe_string_value_1 (xe, &val, DV_LONG_STRING);
	  xslt_character (xp, val);
	  dk_free_box (val);
	  return;
	}
      if (uname__root == name)
	{
	  /* useless dk_free_box (name); */
	  if (use_attribute_sets)
	    xslt_add_attributes_from_sets (xp, use_attribute_sets, 0);
	  xslt_instantiate_children (xp, xstree);
	  return;
	}
      if (uname__pi == name)
        {
	  /* useless dk_free_box (name); */
	  XP_STRSES_FLUSH (xp);
	  dk_set_push (&xp->xp_current->xn_children,
	    xe->_->xe_copy_to_xte_subtree (xe) );
	  return;
        }
    }
  xslt_element_start (xp, name);
  if (use_attribute_sets)
    xslt_add_attributes_from_sets (xp, use_attribute_sets, 0);
  xslt_instantiate_children (xp, xstree);
  xslt_element_end (xp);
}


int
xslt_count_match (xparse_ctx_t * xp, xp_query_t * xqr, xml_entity_t * xe)
{
  caddr_t name;
  int rc;
  if (DV_XPATH_QUERY == DV_TYPE_OF (xqr))
    {
      int res;
      res = xslt_match (xp, xqr, xe);
      return res;
    }
  name = xe->_->xe_ent_name (xe);
  rc = ((name == (caddr_t) xqr) ? XI_RESULT : XI_AT_END);
  dk_free_box (name);
  return rc;
}


dk_set_t
xslt_count_single (xparse_ctx_t * xp, xp_query_t * count, xp_query_t * from)
{
  int ctr = 1, rc;
  xml_entity_t * xe = xp->xp_current_xe->_->xe_copy (xp->xp_current_xe);
  for (;;)
    {
      if (from && XI_RESULT == xslt_count_match (xp, from, xe))
	{
	  dk_free_box ((caddr_t) xe);
	  return NULL;
	}
      if (XI_RESULT == xslt_count_match (xp, count, xe))
	break;
      if (XI_AT_END == xe->_->xe_up (xe, (XT *) XP_NODE, XE_UP_MAY_TRANSIT))
	{
	  dk_free_box ((caddr_t) xe);
	  return NULL;
	}
    }
  for (;;)
    {
      rc = xe->_->xe_prev_sibling (xe, (XT*) XP_NODE);
      if (XI_AT_END == rc)
	break;
      if (XI_RESULT == xslt_count_match  (xp, count, xe))
	ctr++;
    }
  dk_free_box ((caddr_t) xe);
  return (dk_set_cons (box_num (ctr), NULL));
}


dk_set_t
xslt_count_multiple (xparse_ctx_t * xp, xp_query_t * count, xp_query_t * from)
{
  dk_set_t res = NULL;
  int ctr = 1, rc;
  xml_entity_t * xe = xp->xp_current_xe->_->xe_copy (xp->xp_current_xe);
  for (;;)
    {
      if (from && XI_RESULT == xslt_count_match (xp, from, xe))
        break;
      if (XI_RESULT == xslt_count_match (xp, count, xe))
	{
	  xml_entity_t * lxe = xe->_->xe_copy ((xml_entity_t *) xe);
	  ctr = 1;
	  for (;;)
	    {
	      rc = lxe->_->xe_prev_sibling (lxe, (XT*) XP_NODE);
	      if (XI_AT_END == rc)
		break;
	      if (XI_RESULT == xslt_count_match  (xp, count, lxe))
		ctr++;
	    }
	  dk_free_box ((caddr_t) lxe);
	  dk_set_push (&res, box_num (ctr));
	}
      if (XI_AT_END == xe->_->xe_up (xe, (XT*) XP_NODE, XE_UP_MAY_TRANSIT))
        break;
    }
  dk_free_box ((caddr_t) xe);
  return res;
}


dk_set_t
xslt_count_any (xparse_ctx_t * xp, xp_query_t * count, xp_query_t * from)
{
  dk_set_t res = NULL;
  int ctr = 1;
  xml_entity_t * xe;
  xe = xp->xp_current_xe;
  xe = xe->_->xe_copy (xe);
  /* search for previous */
  for (;;)
    {
      if (from && XI_RESULT == xslt_count_match (xp, from, xe))
	{
	  break;
	}
      if (XI_RESULT == xslt_count_match (xp, count, xe))
	{
	  ctr++;
        }
      if (XI_AT_END == xe->_->xe_prev_sibling (xe, (XT*) XP_NODE))
	{
	  break;
	}
    }
  dk_free_box ((caddr_t) xe);
  xe = xp->xp_current_xe;
  xe = xe->_->xe_copy (xe);
  /* search for parents */
  for (;;)
    {
      if (from && XI_RESULT == xslt_count_match (xp, from, xe))
	{
	  break;
	}
      if (XI_RESULT == xslt_count_match (xp, count, xe))
	{
	  ctr++;
        }
      if (XI_AT_END == xe->_->xe_up (xe, (XT*) XP_NODE, XE_UP_MAY_TRANSIT))
	{
	  break;
	}
    }
  dk_free_box ((caddr_t) xe);
  dk_set_push (&res, box_num (ctr));
  return res;
}


caddr_t
xslt_default_count (xparse_ctx_t * xp)
{
  xml_entity_t * xe = xp->xp_current_xe;
  return (xe->_->xe_ent_name (xe));
}


void
xslt_number (xparse_ctx_t * xp, caddr_t * xstree)
{
  dk_set_t res = NULL;
  caddr_t level = xslt_arg_value (xstree, XSLT_ATTR_NUMBER_LEVEL);
  caddr_t format = xslt_arg_value (xstree, XSLT_ATTR_NUMBER_FORMAT);
  xp_query_t * count = (xp_query_t *) xslt_arg_value (xstree, XSLT_ATTR_NUMBER_COUNT);
  xp_query_t * from = (xp_query_t *) xslt_arg_value (xstree, XSLT_ATTR_NUMBER_FROM);
  int tail_max_fill;
  if (!count)
    count = (xp_query_t *) xslt_default_count (xp);
  if (!level || 0 == strcmp (level, "single"))
    res = xslt_count_single (xp, count, from);
  else if (0 == strcmp (level, "multiple"))
    res = xslt_count_multiple (xp, count, from);
  else if (0 == strcmp (level, "any"))
    res = xslt_count_any (xp, count, from);
  else
    sqlr_new_error_xsltree_xdl ("XS370", "XS019", xstree, "Unsupported numbering level '%s'", level);
  if (!format)
    format = "";
  if (DV_XPATH_QUERY != DV_TYPE_OF (count))
    dk_free_box ((caddr_t) count);
  {
    int res_len = dk_set_length (res);
    unsigned *nums = (unsigned *) dk_alloc (sizeof (unsigned) * res_len);
    unsigned *nums_tail = nums;
    caddr_t tmp_buf, tmp_buf_tail;
    while (res)
      {
	caddr_t n = (caddr_t)dk_set_pop (&res);
	(nums_tail++)[0] = (unsigned) unbox (n);
	dk_free_box (n);
      }
/* The longest printed number is QMMMDCCCLXXXVIII - 16 chars, let's put 18 :) */
    tail_max_fill = (strlen (format)  + 1) * 18 * res_len;
    tmp_buf = (caddr_t) dk_alloc (tail_max_fill);
    tmp_buf_tail = xslt_fmt_print_numbers (tmp_buf, tail_max_fill, nums, res_len, format);
    dk_free (nums, sizeof (unsigned) * res_len);
    session_buffered_write (xp->xp_strses, tmp_buf, tmp_buf_tail - tmp_buf);
    dk_free (tmp_buf, tail_max_fill);
  }
}

void
xslt_key (xparse_ctx_t * xp, caddr_t * xstree)
{
  xml_entity_t * old_xe = xp->xp_current_xe;
  caddr_t name = xslt_arg_value (xstree, XSLT_ATTR_KEY_NAME);
  xp_query_t * pattern_expn = (xp_query_t *) xslt_arg_value (xstree, XSLT_ATTR_KEY_MATCH);
  xp_query_t * use_expn = (xp_query_t *) xslt_arg_value (xstree, XSLT_ATTR_KEY_USE);
  caddr_t * pattern_set;
  caddr_t * use_set_or_item;
  caddr_t * use_set;
  size_t pattern_set_size, use_set_size, use_set_inx;
  long pattern_inx;
  long save_pos, save_size;
  id_hash_t *all_keysets, *curr_keyset;
  all_keysets = (id_hash_t *)xp->xp_keys;
  if (NULL == all_keysets)
    {
      xp->xp_keys = box_dv_dict_hashtable (31);
      all_keysets = (id_hash_t *)xp->xp_keys;
    }
  curr_keyset = (id_hash_t *)id_hash_get (all_keysets, (caddr_t)(&name));
  if (NULL != curr_keyset)
    sqlr_new_error_xsltree_xdl ("XS370", "XS039", xstree, "xsl:key with name '%s' is already created", name);
  pattern_set = (caddr_t*) xslt_eval_1 (xp, pattern_expn, xp->xp_current_xe, XQ_NODE_SET, DV_UNKNOWN);
  pattern_set_size = ((NULL == pattern_set) ? 0 : BOX_ELEMENTS (pattern_set));
  curr_keyset = (id_hash_t *) box_dv_dict_hashtable (hash_nextprime ((uint32) pattern_set_size));
  name = box_copy (name);
  id_hash_set (all_keysets, (caddr_t)(&name), (caddr_t)(&curr_keyset));
  if (0 == pattern_set_size)
    {
      dk_free_tree ((box_t) pattern_set);
      return;
    }
  xp_temp (xp, (caddr_t) pattern_set);
  if (DV_ARRAY_OF_XQVAL != DV_TYPE_OF (pattern_set))
    sqlr_new_error_xsltree_xdl ("XS370", "XS037", xstree, "Pattern in xsl:key must return a node set");
  XP_CTX_POS_GET (xp, save_size, save_pos);
  DO_BOX (xml_entity_t *, pattern_elt, pattern_inx, pattern_set)
    {
      if (DV_XML_ENTITY != DV_TYPE_OF (pattern_elt))
	sqlr_new_error_xsltree_xdl ("XS370", "XS038", xstree, "Element of pattern node-set in xsl:key is not an entity");
      xp->xp_current_xe = pattern_elt;
      XP_CTX_POS (xp, 1, 1);
      use_set_or_item = (caddr_t*) xslt_eval_1 (xp, use_expn, xp->xp_current_xe, XQ_NODE_SET, DV_UNKNOWN);
      if (NULL == use_set_or_item)
        continue;
      xp_temp (xp, (caddr_t) use_set_or_item);
      if (DV_ARRAY_OF_XQVAL != DV_TYPE_OF (pattern_set))
	{
	  use_set = (caddr_t *)(&use_set_or_item);
	  use_set_size = 1;
	}
      else
	{
	  use_set = use_set_or_item;
	  use_set_size = BOX_ELEMENTS(use_set);
	}
      for (use_set_inx = 0; use_set_inx < use_set_size; use_set_inx++)
	{
	  caddr_t val = use_set[use_set_inx];
	  caddr_t val_strg = NULL;
	  caddr_t **val_nodes_ptr, *val_nodes;
	  dtp_t val_dtp;
	  if (NULL == val)
	    continue;
	  val_dtp = DV_TYPE_OF (val);
	  if (DV_XML_ENTITY == val_dtp)
	    {
	      xml_entity_t * val_xe = (xml_entity_t *) val;
	      xe_string_value_1 (val_xe, &val_strg, DV_SHORT_STRING);
	    }
	  else
	    val_strg = box_cast ((caddr_t *) xp->xp_qi, val, (sql_tree_tmp*) st_varchar, val_dtp);
	  val_nodes_ptr = (caddr_t **) id_hash_get (curr_keyset, (caddr_t)(&val_strg));
	  if (NULL == val_nodes_ptr)
	    {
	      val_nodes = (caddr_t *)dk_alloc_box (2 * sizeof(caddr_t), DV_ARRAY_OF_POINTER);
	      val_nodes[0] = (caddr_t)((ptrlong)2);
	      val_nodes[1] = box_copy_tree ((box_t) pattern_elt);
	      id_hash_set (curr_keyset, (caddr_t)(&val_strg), (caddr_t)(&val_nodes));
	    }
	  else
	    {
	      ptrlong buf_len;
              boxint busy_len;
	      dk_free_box (val_strg);
	      val_nodes = val_nodes_ptr[0];
	      buf_len = BOX_ELEMENTS (val_nodes);
	      busy_len = unbox (val_nodes[0]);
	      if (buf_len == busy_len)
		{
		  caddr_t * new_val_nodes;
		  buf_len *= 2;
		  new_val_nodes = (caddr_t *)dk_alloc_box_zero (buf_len * sizeof(caddr_t), DV_ARRAY_OF_POINTER);
		  memcpy (new_val_nodes, val_nodes, (size_t)busy_len * sizeof(caddr_t));
		  dk_free_box ((caddr_t)val_nodes);
		  val_nodes = val_nodes_ptr[0] = new_val_nodes;
		}
	      val_nodes[busy_len] = box_copy_tree ((box_t) pattern_elt);
	      val_nodes[0] = box_num (busy_len+1);
	   }
	}
      xp_temp_free (xp, (caddr_t) use_set);
    }
  END_DO_BOX;
  XP_CTX_POS (xp, save_size, save_pos);
  xp_temp_free (xp, (caddr_t) pattern_set);
  xp->xp_current_xe = old_xe;
}


void
xslt_misplaced (xparse_ctx_t * xp, caddr_t * xstree)
{
  sqlr_new_error_xsltree_xdl ("XS370", "XS047", xstree, "Misplaced element");
}


void
xslt_notyetimplemented (xparse_ctx_t * xp, caddr_t * xstree)
{
  sqlr_new_error_xsltree_xdl ("XS370", "XS048", xstree, "Unsupported type of elements");
}


void
xslt_instantiate_1 (xparse_ctx_t * xp, caddr_t * xstree)
{
  if (xte_is_entity (xstree))
    {
      caddr_t id = XTE_HEAD_NAME (XTE_HEAD (xstree));
      if (!IS_POINTER (id)) /* if compiled XSL element */
	{
	  xslt_metadata_t *meta = xslt_meta_list + ((ptrlong)(id));
	  meta->xsltm_executable (xp, xstree);
	}
      else
	xslt_copy_1 (xp, xstree);
    }
  else
    {
      if (DV_STRINGP (xstree))
	xslt_character (xp, (caddr_t) xstree);
      else
	{
	  XP_STRSES_FLUSH (xp);
	  dk_set_push (&xp->xp_current->xn_children, (void *) box_copy ((box_t) xstree));
	}
    }
}


void
xslt_instantiate (xparse_ctx_t * xp, xslt_template_t * xst, xml_entity_t * xe)
{

  WITH_TEMPLATE (xst)
    {
      if (xst->xst_simple)
	xslt_instantiate_1 (xp, xst->xst_tree);
      else
	xslt_instantiate_children (xp, xst->xst_tree);
    }
  END_WITH_TEMPLATE;
}


void
xslt_traverse_inner (xparse_ctx_t * xp, xslt_sheet_t * first_xsh)
{
  xml_entity_t * xe = xp->xp_current_xe;
  xslt_template_t * xst = xslt_template_find (xp, xe, first_xsh);
  /*
    volatile int stack_top;
    printf("\n0x%lx : xslt_traverse_inner", (long)(&stack_top));
  */
  QI_CHECK_STACK (xp->xp_qi, &xst, 8000);
  if (xp->xp_qi->qi_client->cli_terminate_requested)
    sqlr_new_error ("37000", "SR368", "XSLT aborted by client request");
  if (xst)
    {
      xqi_binding_t * saved_locals = xp->xp_locals;
      xslt_instantiate (xp, xst, xe);
      xslt_pop_params (xp, saved_locals);
      return;
    }
  if (NULL == xe->xe_attr_name)
    {
      /* text is copied, elements are bypassed and children processed recursively */
      caddr_t name = xe->_->xe_element_name (xe);
      if (uname__txt == name)
	{
	  caddr_t tv = NULL;
	  /* useless dk_free_box (name); */
	  xe->_->xe_string_value (xe, &tv, DV_LONG_STRING);
	  xslt_character (xp, tv);
	  dk_free_box (tv);
	  return;
	}
      else if ((uname__comment == name) || (uname__pi == name))
	{ /* input comments & processing instructions are skipped */
	  /* useless dk_free_box (name); */
	  return;
	}
      dk_free_box (name);
      xslt_process_children (xp, xe);
    }
}


void
xslt_process_children (xparse_ctx_t * xp, xml_entity_t * xe)
{
  int len, nth;
  int rc;
  int na = -1;
  long save_pos, save_size;
#ifdef DEBUG
  if (xe->xe_attr_name)
    GPF_T1 ("attribute nodes do not have attributes or children");
#endif
  for (;;)
    {
      na = xe->_->xe_attribute (xe, na, (XT *) XP_NODE, NULL, &(xe->xe_attr_name));
      if (XI_NO_ATTRIBUTE == na)
        {
	  dk_free_box (xe->xe_attr_name);
          xe->xe_attr_name = NULL;
	  break;
	}
      xslt_traverse_1 (xp);
    }
  len = xe->_->xe_get_child_count_any (xe);
  if (0 == len)
    return;
  rc = xe->_->xe_first_child (xe, (XT *) XP_NODE);
  if (XI_RESULT != rc)
    GPF_T;
  XP_CTX_POS_GET (xp, save_size, save_pos);
  for (nth = 0; ; nth++)
    {
      XP_CTX_POS (xp, len, nth + 1);
      xslt_traverse_1 (xp);
      rc = xe->_->xe_next_sibling (xe, (XT *) XP_NODE);
      if (rc != XI_RESULT)
	break;
    }
  XP_CTX_POS (xp, save_size, save_pos);
  xe->_->xe_up (xe, (XT *) XP_NODE, XE_UP_MAY_TRANSIT);
}


void
xslt_globals (xparse_ctx_t * xp, caddr_t * params)
{
  xslt_sheet_t * xsh = xp->xp_sheet;
  int inx, inx2;
/* First of all, keys must be initialized. It is prohibited to use variables in key patterns. */
  for (inx2 = BOX_ELEMENTS (xsh->xsh_imported_sheets) - 1; inx2 >= 0; inx2--)
    {
      xslt_sheet_t * sheet  = xsh->xsh_imported_sheets[inx2];
      caddr_t * xstree = sheet->xsh_compiled_tree;
      for (inx = 1; inx < (int) BOX_ELEMENTS (xstree); inx++)
	{
	  caddr_t * elt = (caddr_t *) xstree[inx];
	  if (XSLT_EL_KEY == xslt_arg_elt (elt))
	    {
	      xslt_key (xp, elt);
	      continue;
	    }
	}
    }
/* External parameters must be pushed first (for low scope priority) */
  if (params)
    {
      int params_count = BOX_ELEMENTS (params);
      dtp_t params_dtp = DV_TYPE_OF (params);
      if (((DV_ARRAY_OF_POINTER != params_dtp) && (DV_ARRAY_OF_LONG != params_dtp))
	  || params_count % 2 != 0)
	sqlr_new_error ("22023", "XS021", "The vector of XSLT parameters must be an even length generic array");
      for (inx = 0; inx < params_count; inx += 2)
	{
	  if (!DV_STRINGP (params[inx]))
	    sqlr_new_error ("22023", "XS022", "The vector of XSLT parameters must have strings for even numbered elements");
	  if (DV_TYPE_OF (params[inx + 1]) != DV_DB_NULL)
	    {
	      NEW_VARZ (xqi_binding_t, xb);
	      xb->xb_name = box_dv_uname_string (params[inx]);
	      if (NULL != params[inx + 1])
		xb->xb_value = box_copy_tree (params[inx + 1]);
	      else
		xb->xb_value = box_num_nonull (0);
	      xb->xb_next = xp->xp_globals;
	      xp->xp_globals = xb;
	    }
	}
    }
/* Top-level xsl:param-s and xsl:variable-s must be pushed with higher priority */
  for (inx2 = BOX_ELEMENTS (xsh->xsh_imported_sheets) - 1; inx2 >= 0; inx2--)
    {
      xslt_sheet_t * sheet  = xsh->xsh_imported_sheets[inx2];
      caddr_t * xstree = sheet->xsh_compiled_tree;
      for (inx = 1; inx < (int) BOX_ELEMENTS (xstree); inx++)
	{
	  caddr_t * elt = (caddr_t *) xstree[inx];
	  xqi_binding_t *new_xb;
	  switch (xslt_arg_elt (elt))
	    {
	    case XSLT_EL_VARIABLE:
	      xslt_variable (xp, elt);
	      break;
	    case XSLT_EL_PARAM:
	      xslt_parameter (xp, elt);
	      break;
	    default: continue;
	    }
	  new_xb = xp->xp_locals;
	  if (new_xb)
	    {
	      new_xb->xb_next = xp->xp_globals;
	      xp->xp_globals = new_xb;
	      xp->xp_locals = NULL;
	    }
	}
    }
}


caddr_t
xslt_top (query_instance_t * qi, xml_entity_t * xe, xslt_sheet_t * xsh, caddr_t * params, caddr_t *err_ret)
{
  caddr_t tree, *root_elt_head = NULL;
  caddr_t excl_val = NULL;
  dk_set_t top;
  xparse_ctx_t context;
  volatile int rc;
  NEW_VARZ (xp_node_t, xn);
  memset (&context, 0, sizeof (context));
  context.xp_qi = qi;
  context.xp_current = xn;
  xn->xn_xp = &context;
  context.xp_strses = strses_allocate ();
  context.xp_top = xn;
  context.xp_sheet = xsh;
  context.xp_current_xe = xe;
  context.xp_namespaces_are_valid = xe->xe_doc.xd->xd_namespaces_are_valid;
  rc = 1;

  QR_RESET_CTX
    {
      caddr_t sh_uri;
      XD_DOM_LOCK (xe->xe_doc.xd);
      xslt_globals (&context, params);
      xslt_traverse_1  (&context);
      if (NULL != xsh->xsh_top_excl_res_prefx)
        excl_val = xslt_attr_template (&context, xsh->xsh_top_excl_res_prefx);
      sh_uri = box_dv_short_string(xsh->xsh_shuric.shuric_uri);
      if (NULL != excl_val)
        root_elt_head = (caddr_t *) list (5, uname__root, uname__xslt, sh_uri, uname__bang_exclude_result_prefixes, excl_val);
      else
        root_elt_head = (caddr_t *) list (3, uname__root, uname__xslt, sh_uri);
      XD_DOM_RELEASE (xe->xe_doc.xd);
    }
  QR_RESET_CODE
    {
      context.xp_error_msg = thr_get_error_code (qi->qi_thread);
      rc = 0;
      dk_free_tree (root_elt_head);
      POP_QR_RESET;
      XD_DOM_RELEASE (xe->xe_doc.xd);
    }
  END_QR_RESET;

  xslt_pop_params (&context, NULL); /* if non-local exit */
  XP_STRSES_FLUSH (&context);
  if (!rc)
    {

      if (err_ret)
	{
	  *err_ret = context.xp_error_msg;
	  context.xp_error_msg = NULL;
	}
      xp_free (&context);
      return NULL;
    }
  if (NULL != excl_val)
    {
      DO_SET (caddr_t **, chld, &(xn->xn_children))
        {
          if ((DV_ARRAY_OF_POINTER == DV_TYPE_OF ((void*)chld)) &&
            (DV_ARRAY_OF_POINTER == DV_TYPE_OF ((void*)(chld[0]))) &&
            (' ' != chld[0][0][0]) )
            {
              caddr_t *head = chld[0];
              caddr_t *new_head;
              int head_len = BOX_ELEMENTS (head);
              int idx;
              for (idx = head_len-2; idx > 0; idx -= 2)
                {
                  if (!strcmp (head[idx], uname__bang_exclude_result_prefixes))
                    goto child_has_excl_attr; /* see below */
                }
              new_head = dk_alloc_box ((2+head_len) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
              memcpy (new_head, head, head_len * sizeof (caddr_t));
              new_head [head_len] = uname__bang_exclude_result_prefixes;
              new_head [head_len+1] = box_copy_tree (excl_val);
              chld[0] = new_head;
              dk_free_box (head);
            }
child_has_excl_attr: ;
        }
      END_DO_SET()
    }
  top = dk_set_nreverse (xn->xn_children);
  dk_set_push (&top, (void *)root_elt_head);
  tree = (caddr_t) list_to_array (top);
  xn->xn_children = NULL;
  xp_free (&context);
  return tree;
}


shuric_t * shuric_alloc__xslt (void *env)
{
  NEW_VARZ (xslt_sheet_t, xsh);
  xsh->xsh_shuric.shuric_data = xsh;
  return &(xsh->xsh_shuric);
}


caddr_t shuric_uri_to_text__xslt (caddr_t uri, query_instance_t *qi, void *env, caddr_t *err_ret)
{
  caddr_t resource_text;
  if (NULL == qi)
    {
      GPF_T;
#if 0
This should never happen.
      err_ret[0] = srv_make_new_error ("37XQR", "SQ195", "Unable to retrieve '%.1000s' from SQL compiler due to danger of fatal deadlock");
      return NULL;
#endif
    }
  resource_text = xml_uri_get (qi, err_ret, NULL, NULL /* = no base uri */, uri, XML_URI_STRING);
  return resource_text;
}


void shuric_parse_text__xslt (shuric_t *shuric, caddr_t uri_text_content, query_instance_t *qi, void *env, caddr_t *err_ret)
{
  xslt_sheet_t * xsh = (xslt_sheet_t *)(shuric->shuric_data);
  caddr_t *tree = NULL;
  xml_ns_2dict_t local_ns_2dict;
  xml_ns_2dict_t *ns_2dict_ptr = NULL;
  int tree_is_local = 0;
  if (DV_XML_ENTITY == DV_TYPE_OF (uri_text_content))
    {
      xml_tree_ent_t *ent = (xml_tree_ent_t *)uri_text_content;
      tree = ent->xte_current;
      ns_2dict_ptr = &(ent->xe_doc.xd->xd_ns_2dict);
    }
  else
    {
      static caddr_t dtd_config = NULL;
      local_ns_2dict.xn2_size = 0;
      ns_2dict_ptr = &local_ns_2dict;
      if (NULL == dtd_config)
        dtd_config = box_dv_short_string ("BuildStandalone=ENABLE");
      tree = (caddr_t *)xml_make_mod_tree (qi, uri_text_content, err_ret, FINE_XSLT, shuric->shuric_uri, NULL, server_default_lh, dtd_config, NULL /* do not save DTD */, NULL /* do not cache IDs */, ns_2dict_ptr);
      tree_is_local = 1;
    }
  if (NULL == err_ret[0])
    xslt_sheet_prepare (xsh, (caddr_t *) tree, qi, err_ret, ns_2dict_ptr);
#ifdef DEBUG
  if (NULL != tree) /* This 'if' is for the case of XML parsing error. */
    xte_tree_check (tree);
#endif
  if (tree_is_local)
    {
      dk_free_tree (tree);
      xml_ns_2dict_clean (ns_2dict_ptr);
    }
/*  shuric->shuric_loading_time = ts; */
}


void
xslt_template_destroy (xslt_template_t *xst)
{
  dk_free_tree (xst->xst_name);
  dk_free_tree (xst->xst_mode);
  dk_free_tree (xst->xst_match);
  dk_free_tree (xst->xst_tree);
  dk_free (xst, sizeof (xslt_template_t));
}


void xslt_release_named_mode (const void *key, void *data)
{
  dk_free_tree ((caddr_t)data);
}

void shuric_destroy_data__xslt (struct shuric_s *shuric)
{
  int inx;
  xslt_sheet_t * xsh = (xslt_sheet_t *)(shuric->shuric_data);
  dk_free_box ((box_t) (xsh->xsh_imported_sheets));
  dk_free_tree ((box_t) (xsh->xsh_raw_tree));
  dk_free_tree ((box_t) (xsh->xsh_compiled_tree));
  dk_free_tree (list_to_array (xsh->xsh_formats));
  while (xsh->xsh_new_templates)
    xslt_template_destroy ((xslt_template_t *)dk_set_pop (&(xsh->xsh_new_templates)));
  DO_BOX (xslt_template_t *, xst, inx, xsh->xsh_all_templates)
    {
      xslt_template_destroy (xst);
    }
  END_DO_BOX;
  dk_free_box ((box_t) xsh->xsh_all_templates);
  dk_free_box ((caddr_t)(xsh->xsh_default_mode.xstm_attr_templates));
  dk_free_box ((caddr_t)(xsh->xsh_default_mode.xstm_nonattr_templates));
  if (NULL != xsh->xsh_all_templates_byname) /* can be NULL if compilation has failed */
    hash_table_free (xsh->xsh_all_templates_byname);
  if (NULL != xsh->xsh_named_modes) /* can be NULL if compilation has failed */
    {
      maphash (xslt_release_named_mode, xsh->xsh_named_modes);
      hash_table_free (xsh->xsh_named_modes);
    }
  dk_free_tree (xsh->xout_method);
  dk_free_tree (xsh->xout_version);
  dk_free_tree (xsh->xout_encoding);
  dk_free_tree (xsh->xout_doctype_public);
  dk_free_tree (xsh->xout_doctype_system);
  dk_free_tree (xsh->xout_media_type);
  if (NULL != xsh->xout_cdata_section_elements) /* can be NULL. It simply can :) */
    {
      id_hash_iterator_t hit;
      char **kp;
      char **dp;
      id_hash_iterator (&hit, xsh->xout_cdata_section_elements);
      while (hit_next (&hit, (char **)&kp, (char **)&dp))
	{
	  if (kp)
	    dk_free_box ((caddr_t)(*kp));
	  if (dp)
	    dk_free_box (*dp);
	}
      id_hash_free (xsh->xout_cdata_section_elements);
    }
  xml_ns_2dict_clean (&(xsh->xsh_ns_2dict));
  dk_free_tree (xsh->xsh_top_excl_res_prefx);
  dk_free_tree (xsh->xsh_sparql_preamble);
  dk_free (xsh, sizeof (xslt_sheet_t));
}


shuric_vtable_t shuric_vtable__xslt = {
  "XSLT stylesheet",
  shuric_alloc__xslt,
  shuric_uri_to_text__xslt,
  shuric_parse_text__xslt,
  shuric_destroy_data__xslt,
  shuric_on_stale__no_op,
  shuric_get_cache_key__stub
  };


caddr_t
bif_xslt_sheet (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t *) qst;
  shuric_t *xsh_shuric;
  caddr_t name = bif_string_arg (qst, args, 0, "xslt_sheet");
  xml_tree_ent_t * ent = bif_tree_ent_arg (qst, args, 1, "xslt_sheet");
  caddr_t err = NULL;
  xsh_shuric = shuric_load (&shuric_vtable__xslt, name, NULL, (caddr_t)ent, NULL, qi, NULL, &err);
  if (err)
    {
#ifdef DEBUG
      if (xsh_shuric)
	GPF_T;
#endif
      sqlr_resignal (err);
    }
#ifdef DEBUG
  if (2 != xsh_shuric->shuric_ref_count)
    GPF_T1 ("Too big refcount of a new XSLT sheet");
#endif
  shuric_release (xsh_shuric);
  return 0;
}


caddr_t
bif_xslt_stale (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t iri = bif_string_arg (qst, args, 0, "xslt_stale");
  caddr_t err = NULL;
  shuric_t *shu = shuric_get_typed (iri, &shuric_vtable__xslt, &err);
  if (NULL != err)
    sqlr_resignal (err);
  shuric_stale_tree (shu);
  shuric_release (shu);
  return 0;
}

caddr_t
bif_xslt_is_sheet (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t name = bif_string_arg (qst, args, 0, "xslt_is_sheet");
  shuric_t *shu = shuric_get_typed (name, &shuric_vtable__xslt, NULL);
  shuric_release (shu);
  return (box_num ((NULL != shu) ? 1 : 0));
}


caddr_t
bif_xslt (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t err = NULL;
  caddr_t res;
  xml_tree_ent_t *res1;
  long start = prof_on ? get_msec_real_time () : 0;
  caddr_t name = bif_string_arg (qst, args, 0, "xslt");
  xml_entity_t * xe = bif_entity_arg (qst, args, 1, "xslt");
  xslt_sheet_t * xsh = xslt_sheet ((query_instance_t *) qst, NULL, name, NULL, NULL);
  caddr_t * params = BOX_ELEMENTS (args) > 2 ? (caddr_t *) bif_array_arg (qst, args, 2, "xslt") : NULL;
#ifdef MALLOC_DEBUG
  int refctr, *refctr_ptr;
  int refctr_internals, new_refctr_internals;
#endif
  if (!xsh)
    sqlr_new_error ("22023", "XS034", "Undefined style sheet '%s'", name);
#ifdef MALLOC_DEBUG
  refctr_ptr = &(xe->xe_doc.xtd->xd_ref_count);
  refctr = refctr_ptr[0];
  refctr_internals = dk_set_length(xe->xe_doc.xd->xd_referenced_entities);
#endif
  if (xslt_measure_uses)
    xsh->xsh_new_uses.xshu_calls++;
  xe = xe->_->xe_copy (xe); /* position in tree will change. copy */
  res = xslt_top ((query_instance_t *) qst, xe, xsh, params, &err);
  if (err)
    {
      dk_free_box ((caddr_t) xe);
      if (xslt_measure_uses)
	xsh->xsh_new_uses.xshu_abends++;
      shuric_release (&(xsh->xsh_shuric));
      sqlr_resignal (err);
    }
  res1 = xte_from_tree (res, (query_instance_t *) qst);
  xte_copy_output_elements (res1, xsh);
  xml_ns_2dict_extend (&(res1->xe_doc.xd->xd_ns_2dict), &(xsh->xsh_ns_2dict));
  xe_ns_2dict_extend (res1, xe);
  shuric_release (&(xsh->xsh_shuric));
#ifdef MALLOC_DEBUG
  new_refctr_internals = dk_set_length(xe->xe_doc.xd->xd_referenced_entities);
  dk_free_box ((caddr_t) xe);
  if ((refctr_ptr[0] - new_refctr_internals) > (refctr - refctr_internals))
    GPF_T1("Critical leak of data XML entities in XSLT engine");
#else
  dk_free_box ((caddr_t) xe);
#endif
  if (prof_on && start)
    prof_exec (NULL, name, get_msec_real_time () - start, PROF_EXEC);
  return (caddr_t)(res1);
}


void
xpf_processXSLT (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t err = NULL;
  caddr_t xslt_rel_uri = xpf_arg (xqi, tree, ctx_xe, DV_STRING, 0);
  char *own_file = ((NULL != xqi->xqi_xqr->xqr_base_uri) ? xqi->xqi_xqr->xqr_base_uri : xqi->xqi_xqr->xqr_xdl.xdl_file);
  caddr_t xslt_base_uri = ((NULL == own_file) ? NULL : box_dv_short_string (own_file));
  int paramcount = ((2 < tree->_.xp_func.argcount) ? (tree->_.xp_func.argcount-2) : 0);
  int paramctr;
  caddr_t *params = (caddr_t *)dk_alloc_box_zero (paramcount * sizeof (caddr_t), DV_ARRAY_OF_LONG);
  caddr_t raw_xe = ((1 < tree->_.xp_func.argcount) ? xpf_raw_arg (xqi, tree, ctx_xe, 1) : (caddr_t)ctx_xe);
  xml_entity_t * xe;
  xslt_sheet_t * xsh;
  caddr_t res;
  xml_tree_ent_t * res_xte;
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
  XQI_SET (xqi, tree->_.xp_func.tmp, list (2, xslt_base_uri, params));
  for (paramctr = 0; paramctr < paramcount-1; paramctr += 2)
    {
      params[paramctr] = xpf_arg (xqi, tree, ctx_xe, DV_STRING, paramctr + 2);
      params[paramctr+1] = xpf_raw_arg (xqi, tree, ctx_xe, paramctr + 3);
    }
  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (raw_xe))
    raw_xe = ((BOX_ELEMENTS (raw_xe)) ? (((caddr_t *)raw_xe)[0]) : NULL);
  if (DV_XML_ENTITY != DV_TYPE_OF (raw_xe))
    sqlr_new_error_xqi_xdl ("XP001", "XP???", xqi, "The argument 2 of XPATH function processXSLT() must be an XML entity");
  xe = (xml_entity_t *)raw_xe;
  xsh = xslt_sheet (xqi->xqi_qi, xslt_base_uri, xslt_rel_uri, &err, NULL /* not xqi->xqi_xqr->xqr_shuric because it's run-time loading, not compile-time */);
  if (xslt_measure_uses)
    xsh->xsh_new_uses.xshu_calls++;
  xe = xe->_->xe_copy (xe); /* position in tree will change. copy */
  res = xslt_top (xqi->xqi_qi, xe, xsh, params, &err);
  if (err)
    {
      dk_free_box ((caddr_t) xe);
      if (xslt_measure_uses)
	xsh->xsh_new_uses.xshu_abends++;
      shuric_release (&(xsh->xsh_shuric));
      sqlr_resignal (err);
    }
  res_xte = xte_from_tree (res, xqi->xqi_qi);
  xte_copy_output_elements (res_xte, xsh);
  xml_ns_2dict_extend (&(res_xte->xe_doc.xd->xd_ns_2dict), &(xsh->xsh_ns_2dict));
  xe_ns_2dict_extend (res_xte, xe);
  shuric_release (&(xsh->xsh_shuric));
  dk_free_box ((caddr_t) xe);
  res = list (1, res_xte);
  box_tag_modify (res, DV_ARRAY_OF_XQVAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, res);
}


caddr_t
bif_xslt_profile_enable (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xslt_measure_uses = 1;
  return NEW_DB_NULL;
}


caddr_t
bif_xslt_profile_disable (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xslt_measure_uses = 0;
  return NEW_DB_NULL;
}


void
xstu_dump_uses (xslt_template_t * xst, xslt_template_uses_t * xstu, const char *type, dk_session_t *res)
{
  char buf[100];
  sprintf (buf, "\n      <template_profile type=\"%s\"", type);
  SES_PRINT (res, buf);
  if (NULL != xst->xst_name)
    {
      sprintf (buf, " bynamecalls=\"%ld\"", xstu->xstu_byname_calls);
      SES_PRINT (res, buf);
    }
  sprintf (buf, " findcalls=\"%ld\" findhits=\"%ld\"",
    xstu->xstu_find_calls,
    xstu->xstu_find_hits );
  SES_PRINT(res, buf);
  if (xst->xst_match)
    {
      sprintf (buf, " matchcalls=\"%ld\" matchhits=\"%ld\"",
	xstu->xstu_find_match_calls, xstu->xstu_find_match_hits );
      SES_PRINT (res, buf);
    }
  SES_PRINT (res, "/>");
}

#define SES_PRINT_ATTR(ses,strg) write_escaped_attvalue ((ses), (utf8char *)(strg), (int) strlen((strg)), default_charset)

void
xslt_dump_uses (xslt_sheet_t *root_xsh, dk_session_t *res)
{
  char buf[100];
  int inx, inx2;
  SES_PRINT (res, "\n  <stylesheet name=\""); SES_PRINT_ATTR (res, root_xsh->xsh_shuric.shuric_uri); SES_PRINT (res, "\">");
  DO_BOX_FAST (xslt_sheet_t *, xsh, inx, root_xsh->xsh_imported_sheets)
    {
      SES_PRINT (res, "\n  <sheet name=\""); SES_PRINT_ATTR (res, xsh->xsh_shuric.shuric_uri);
      sprintf (buf, "\" refcount=\"%d\" />", xsh->xsh_shuric.shuric_ref_count);
      SES_PRINT (res, buf);
      xsh->xsh_total_uses.xshu_calls += xsh->xsh_new_uses.xshu_calls;
      xsh->xsh_total_uses.xshu_abends += xsh->xsh_new_uses.xshu_abends;
      sprintf (buf, "\n    <sheet_profile type=\"total\" calls=\"%ld\" abends=\"%ld\" />",
	xsh->xsh_total_uses.xshu_calls,
	xsh->xsh_total_uses.xshu_abends );
      SES_PRINT (res, buf);
      sprintf (buf, "\n    <sheet_profile type=\"new\" calls=\"%ld\" abends=\"%ld\" />",
	xsh->xsh_total_uses.xshu_calls,
	xsh->xsh_total_uses.xshu_abends );
      SES_PRINT (res, buf);
      xsh->xsh_new_uses.xshu_calls = 0;
      xsh->xsh_new_uses.xshu_abends = 0;
      DO_BOX_FAST (xslt_template_t *, xst, inx2, xsh->xsh_all_templates)
	{
	  SES_PRINT (res, "\n    <template");
	  if (NULL != xst->xst_mode)
	    {
	      SES_PRINT (res, " mode=\""); SES_PRINT_ATTR (res, xst->xst_mode); SES_PRINT (res, "\"");
	    }
	  if (NULL != xst->xst_name)
	    {
	      SES_PRINT (res, " name=\""); SES_PRINT_ATTR (res, xst->xst_name); SES_PRINT (res, "\"");
	    }
	  if (NULL != xst->xst_match)
	    {
	      caddr_t text = xst->xst_match->xqr_key;
	      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (text)) /* If key is not a plain text but text plus namespace decls */
	        text = ((caddr_t *)text)[0];
	      if (NULL == text)
	        text = "(: source text of match is not preserved :)";
	      SES_PRINT (res, " match=\""); SES_PRINT_ATTR (res, text); SES_PRINT (res, "\"");
	    }
	  if (0 != xst->xst_union_member_idx)
	    {
	      sprintf (buf, " variant=\"%d\"", xst->xst_union_member_idx);
	      SES_PRINT (res, buf);
	    }
	  SES_PRINT (res, ">");
	  xst->xst_total_uses.xstu_byname_calls += xst->xst_new_uses.xstu_byname_calls;
	  xst->xst_total_uses.xstu_find_calls += xst->xst_new_uses.xstu_find_calls;
	  xst->xst_total_uses.xstu_find_hits += xst->xst_new_uses.xstu_find_hits;
	  xst->xst_total_uses.xstu_find_match_calls += xst->xst_new_uses.xstu_find_match_calls;
	  xst->xst_total_uses.xstu_find_match_hits += xst->xst_new_uses.xstu_find_match_hits;
	  xstu_dump_uses (xst, &(xst->xst_total_uses), "total", res);
	  xstu_dump_uses (xst, &(xst->xst_new_uses), "new", res);
	  xst->xst_new_uses.xstu_find_calls = 0;
	  xst->xst_new_uses.xstu_find_hits = 0;
	  xst->xst_new_uses.xstu_find_match_calls = 0;
	  xst->xst_new_uses.xstu_find_match_hits = 0;
	  SES_PRINT (res, "\n    </template>");
	}
      END_DO_BOX_FAST;
      SES_PRINT (res, "\n  </sheet>");
    }
  END_DO_BOX_FAST;
  SES_PRINT (res, "\n  </stylesheet>");
}


caddr_t
bif_xslt_profile_list (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xslt_sheet_t *xsh;
  caddr_t name = bif_string_arg (qst, args, 0, "xslt_profile_list");
  dk_session_t *res;
  /* xslt_measure_uses = 0; */
  res = strses_allocate ();
  SES_PRINT(res, "<profiles>");
  xsh = (xslt_sheet_t *)shuric_get_typed (name, &shuric_vtable__xslt, NULL);
  if (NULL != xsh)
    xslt_dump_uses (xsh, res);
  SES_PRINT(res, "\n</profiles>");
  /* xslt_measure_uses = 1; */
  shuric_release ((shuric_t *)xsh);
  return (caddr_t)res;
}


#ifdef DEBUG
caddr_t
bif_xslt_mem_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  shuric_validate_refcounters (1);
  return NULL;
}
#endif


/* Note that no whitespaces should appear in the text of this stylesheet. */
char * xslt_copy_text =
"xslt_sheet ('http://local.virt/xslt_copy', xml_tree_doc (xml_tree ('"
/*--*/ "<xsl:stylesheet xmlns:xsl=''http://www.w3.org/XSL/Transform/1.0''>"
/*----*/ "<xsl:template match=''/''>"
/*------*/ "<xsl:apply-templates />"
/*----*/ "</xsl:template>"
/*----*/ "<xsl:template match=''@*'' priority=''0''>"
/*------*/ "<xsl:copy />"
/*----*/ "</xsl:template>"
/*----*/ "<xsl:template match=''*'' priority=''0''>"
/*------*/ "<xsl:copy>"
/*--------*/ "<xsl:apply-templates />"
/*------*/ "</xsl:copy>"
/*----*/ "</xsl:template>"
/*----*/ "<xsl:template match=''text()'' priority=''0''>"
/*------*/ "<xsl:value-of select=''.''/>"
/*----*/ "</xsl:template>"
/*----*/ "<xsl:template match=''comment()'' priority=''0''>"
/*------*/ "<xsl:comment>"
/*--------*/ "<xsl:value-of select=''.''/>"
/*------*/ "</xsl:comment>"
/*----*/ "</xsl:template>"
/*----*/ "<xsl:template match=''processing-instruction()'' priority=''0''>"
/*------*/ "<xsl:processing-instruction name=''{name(.)}''>"
/*--------*/ "<xsl:value-of select=''.''/>"
/*------*/ "</xsl:processing-instruction>"
/*----*/ "</xsl:template>"
/*--*/ "</xsl:stylesheet>"
"')))";

caddr_t
box_find_mt_unsafe_subtree (caddr_t box)
{
  switch DV_TYPE_OF (box)
    {
    case DV_STRING: case DV_LONG_INT: case DV_SINGLE_FLOAT: case DV_DOUBLE_FLOAT:
    case DV_DB_NULL: case DV_UNAME: case DV_DATETIME: case DV_NUMERIC:
    case DV_IRI_ID: case DV_ASYNC_QUEUE: case DV_WIDE:
    case DV_CLRG:
      return NULL;
    case DV_DICT_ITERATOR:
      {
        id_hash_iterator_t *hit = (id_hash_iterator_t *)box;
        caddr_t *key_ptr, *val_ptr;
        id_hash_iterator_t tmp_hit;
        if (NULL == hit->hit_hash)
          return NULL;
        if (NULL != hit->hit_hash->ht_mutex)
          return NULL;
        id_hash_iterator (&tmp_hit, hit->hit_hash);
        while (hit_next (&tmp_hit, (char **)(&key_ptr), (char **)(&val_ptr)))
          {
            caddr_t res;
            res = box_find_mt_unsafe_subtree (key_ptr[0]);
            if (NULL != res) return res;
            res = box_find_mt_unsafe_subtree (val_ptr[0]);
            if (NULL != res) return res;
          }
        return NULL;
      }
    case DV_ARRAY_OF_POINTER: case DV_ARRAY_OF_XQVAL: case DV_XTREE_HEAD: case DV_XTREE_NODE:
      {
        int ctr;
        DO_BOX_FAST_REV (caddr_t, itm, ctr, box)
          {
            caddr_t res = box_find_mt_unsafe_subtree (itm);
            if (NULL != res) return res;
          }
        END_DO_BOX_FAST_REV;
        return NULL;
      }
    }
  return box;
}

void
box_make_tree_mt_safe (caddr_t box)
{
  switch DV_TYPE_OF (box)
    {
    case DV_STRING: case DV_LONG_INT: case DV_SINGLE_FLOAT: case DV_DOUBLE_FLOAT:
    case DV_DB_NULL: case DV_UNAME: case DV_DATETIME: case DV_NUMERIC:
    case DV_IRI_ID: case DV_ASYNC_QUEUE: case DV_WIDE:
    case DV_CLRG:
      return;
    case DV_DICT_ITERATOR:
      {
        id_hash_iterator_t *hit = (id_hash_iterator_t *)box;
        caddr_t *key_ptr, *val_ptr;
        id_hash_iterator_t tmp_hit;
        if (NULL != hit->hit_hash)
          {
            if (NULL != hit->hit_hash->ht_mutex)
              return;
            hit->hit_hash->ht_mutex = mutex_allocate ();
          }
        id_hash_iterator (&tmp_hit, hit->hit_hash);
        while (hit_next (&tmp_hit, (char **) &key_ptr, (char **) &val_ptr))
          {
            box_make_tree_mt_safe (key_ptr[0]);
            box_make_tree_mt_safe (val_ptr[0]);
          }
        return;
      }
    case DV_ARRAY_OF_POINTER: case DV_ARRAY_OF_XQVAL: case DV_XTREE_HEAD: case DV_XTREE_NODE:
      {
        int ctr;
        DO_BOX_FAST_REV (caddr_t, itm, ctr, box)
          {
            box_make_tree_mt_safe (itm);
          }
        END_DO_BOX_FAST_REV;
        return;
      }
    }
  GPF_T1 ("Thread-unsafe box can not become thread safe");
}

struct id_hash_iterator_s *
bif_dict_iterator_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int chk_version)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  id_hash_iterator_t *res;
  if (dtp != DV_DICT_ITERATOR)
    {
      sqlr_new_error ("22023", "SR090",
	"Function %.300s needs a dictionary reference as argument %d, not an arg of type %s (%d)",
	func, nth + 1, dv_type_title (dtp), dtp );
    }
  res = (id_hash_iterator_t *)arg;
  if (chk_version && (res->hit_dict_version != res->hit_hash->ht_dict_version))
    {
      sqlr_new_error ("22023", "SR091",
	"Function %.300s has received an obsolete dictionary reference as argument %d",
	func, nth + 1 );
    }
  return res;
}

struct id_hash_iterator_s *
bif_dict_iterator_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int chk_version)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (DV_DB_NULL == dtp)
    return NULL;
  if (dtp != DV_DICT_ITERATOR)
    {
      sqlr_new_error ("22023", "SR564",
	"Function %.300s needs a NULL or a dictionary reference as argument %d, not an arg of type %s (%d)",
	func, nth + 1, dv_type_title (dtp), dtp );
    }
  return bif_dict_iterator_arg (qst, args, nth, func, chk_version);
}

caddr_t
bif_dict_new (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t *hit;
  id_hash_t *ht;
  long size = 31, mmem = 0, ment = 0, arg, use_mp = 1;
  switch (BOX_ELEMENTS(args))
    {
    default:
      use_mp = (long) bif_long_arg (qst, args, 3, "dict_new");
    case 3:	
      mmem = (long) bif_long_arg (qst, args, 2, "dict_new");
      /* no break */
    case 2:
      ment = (long) bif_long_arg (qst, args, 1, "dict_new");
      /* no break */
    case 1:
      arg = (long) bif_long_arg (qst, args, 0, "dict_new");
      if (arg > 31)
        size = hash_nextprime (arg);
      /* no break */
    case 0: ;
    }
  ht = (id_hash_t *)box_dv_dict_hashtable (size);
  ht->ht_rehash_threshold = 120;
  if (ment > 0)
    ht->ht_dict_max_entries = ment;
  if (mmem > 0)
    ht->ht_dict_max_mem_in_use = mmem;
  if (use_mp)
    ht->ht_mp = mem_pool_alloc ();
  hit = (id_hash_iterator_t *)box_dv_dict_iterator ((caddr_t)ht);
  return (caddr_t)hit;
}


caddr_t
bif_dict_duplicate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t *orig_hit = bif_dict_iterator_arg (qst, args, 0, "dict_duplicate", 0);
  id_hash_t *new_ht = (id_hash_t *)box_dict_hashtable_copy_hook ((caddr_t)(orig_hit->hit_hash));
  id_hash_iterator_t *new_hit = (id_hash_iterator_t *)box_dv_dict_iterator ((caddr_t)new_ht);
#ifndef NDEBUG
  printf ("Dict duplicate: from %p to %p\n", orig_hit->hit_hash, new_ht);
#endif
  return (caddr_t)new_hit;
}


caddr_t
bif_dict_put (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t *hit = bif_dict_iterator_arg (qst, args, 0, "dict_put", 0);
  id_hash_t *ht = hit->hit_hash;
  caddr_t key = bif_arg (qst, args, 1, "dict_put");
  caddr_t val = bif_arg (qst, args, 2, "dict_put");
  caddr_t *old_val_ptr;
  long res;
  if (ht->ht_mutex)
    {
      caddr_t unsafe_val_subtree;
      unsafe_val_subtree = box_find_mt_unsafe_subtree (val);
      if (NULL != unsafe_val_subtree)
        {
          dtp_t dtp = DV_TYPE_OF (unsafe_val_subtree);
          sqlr_new_error ("42000", "SR565",
            "Argument #3 for dict_put() contain data of type %s (%d) that can not be used as a value in a dictionary that is shared between threads",
            dv_type_title (dtp), dtp );
        }
      mutex_enter (ht->ht_mutex);
    }
  if ((0 < ht->ht_dict_max_entries) &&
      ((ht->ht_inserts - ht->ht_deletes) > ht->ht_dict_max_entries) )
    goto skip_insertion; /* see below */
  if ((0 < ht->ht_dict_max_mem_in_use) &&
      (ht->ht_dict_mem_in_use > ht->ht_dict_max_mem_in_use) )
    goto skip_insertion; /* see below */
  old_val_ptr = (caddr_t *)id_hash_get (ht, (caddr_t)(&key));
  if (NULL != old_val_ptr)
    {
      if (0 < ht->ht_dict_max_mem_in_use)
        ht->ht_dict_mem_in_use += raw_length (val) - raw_length (old_val_ptr[0]);
      if (ht->ht_mp)
	{
	  val = mp_full_box_copy_tree (ht->ht_mp, val);
	}
      else
	{
	  dk_free_tree (old_val_ptr[0]);
	  val = box_copy_tree (val);
	}
      if (ht->ht_mutex)
        box_make_tree_mt_safe (val);
      old_val_ptr[0] = val;
    }
  else
    {
      if (ht->ht_mutex)
        {
          caddr_t unsafe_key_subtree;
          unsafe_key_subtree = box_find_mt_unsafe_subtree (key);
          if (NULL != unsafe_key_subtree)
            {
              dtp_t dtp = DV_TYPE_OF (unsafe_key_subtree);
              mutex_leave (ht->ht_mutex);
              sqlr_new_error ("42000", "SR566",
                "Argument #2 for dict_put() contain data of type %s (%d) that can not be used as a key in a dictionary that is shared between threads",
                dv_type_title (dtp), dtp );
            }
        }
      if (ht->ht_mp)
	{
	  key = mp_full_box_copy_tree (ht->ht_mp, key);
	  val = mp_full_box_copy_tree (ht->ht_mp, val);
	}
      else
	{
	  key = box_copy_tree (key);
	  val = box_copy_tree (val);
	}
      if (ht->ht_mutex)
        {
          box_make_tree_mt_safe (key);
          box_make_tree_mt_safe (val);
        }
      id_hash_set (ht, (caddr_t)(&key), (caddr_t)(&val));
      if (0 < ht->ht_dict_max_mem_in_use)
        ht->ht_dict_mem_in_use += raw_length (val) + raw_length (key) + 3 * sizeof (caddr_t);
    }
  id_hash_iterator (hit, ht);
  ht->ht_dict_version++;
  hit->hit_dict_version++ /* It's incorrect to write hit->hit_dict_version = ht->ht_dict_version because they may be out of sync before the id_hash_put */;
skip_insertion:
  if (ht->ht_mutex)
    mutex_leave (ht->ht_mutex);
  res = ht->ht_inserts - ht->ht_deletes;
  return box_num (res);
}


caddr_t
bif_dict_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t *hit = bif_dict_iterator_arg (qst, args, 0, "dict_get", 0);
  id_hash_t *ht = hit->hit_hash;
  caddr_t key = bif_arg (qst, args, 1, "dict_get");
  caddr_t *valptr;
  caddr_t res;
  if (ht->ht_mutex)
    mutex_enter (ht->ht_mutex);
  valptr = (caddr_t *)id_hash_get (ht, (caddr_t)(&key));
  if (NULL == valptr)
    {
      if (2 < BOX_ELEMENTS (args))
        res = box_copy_tree (bif_arg (qst, args, 2, "dict_get"));
      else
        res = NEW_DB_NULL;
    }
  else
    res = box_copy_tree (valptr[0]);
  if (ht->ht_mutex)
    mutex_leave (ht->ht_mutex);
  return res;
}


caddr_t
bif_dict_contains_key (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t *hit = bif_dict_iterator_arg (qst, args, 0, "dict_contains_key", 0);
  id_hash_t *ht = hit->hit_hash;
  caddr_t key = bif_arg (qst, args, 1, "dict_contains_key");
  caddr_t *valptr;
  if (ht->ht_mutex)
    mutex_enter (ht->ht_mutex);
  valptr = (caddr_t *)id_hash_get (ht, (caddr_t)(&key));
  if (ht->ht_mutex)
    mutex_leave (ht->ht_mutex);
  return (caddr_t)((ptrlong)((NULL != valptr) ? 1 : 0));
}


caddr_t
bif_dict_remove (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t *hit = bif_dict_iterator_arg (qst, args, 0, "dict_remove", 0);
  id_hash_t *ht = hit->hit_hash;
  caddr_t key = bif_arg (qst, args, 1, "dict_remove");
  caddr_t *old_key_ptr, *old_val_ptr;
  caddr_t old_key, old_val;
  int res;
  if (ht->ht_mutex)
    mutex_enter (ht->ht_mutex);
  old_val_ptr = (caddr_t *)id_hash_get (ht, (caddr_t)(&key));
  if (NULL == old_val_ptr)
    res = 0;
  else
    {
      old_key_ptr = (caddr_t *)id_hash_get_key_by_place (ht, (caddr_t)old_val_ptr);
      old_key = old_key_ptr[0];
      old_val = old_val_ptr[0];
      id_hash_remove (ht, (caddr_t)(&key));
      if (ht->ht_dict_max_mem_in_use > 0)
        ht->ht_dict_mem_in_use -= (raw_length (old_key) + raw_length (old_val) + 3 * sizeof (caddr_t));
      if (!ht->ht_mp)
	{
	  dk_free_tree (old_key);
	  dk_free_tree (old_val);
	}
      id_hash_iterator (hit, ht);
      ht->ht_dict_version++;
      if (hit->hit_chilum != (char *)old_key_ptr)
        hit->hit_dict_version++;
      res = 1;
    }
  if (ht->ht_mutex)
    mutex_leave (ht->ht_mutex);
  return box_num (res);
}

caddr_t
bif_dict_inc_or_put (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t *hit = bif_dict_iterator_arg (qst, args, 0, "dict_inc_or_put", 0);
  id_hash_t *ht = hit->hit_hash;
  caddr_t key = bif_arg (qst, args, 1, "dict_inc_or_put");
  boxint inc_val = bif_long_range_arg (qst, args, 2, "dict_inc_or_put", 0, 0xffff);
  boxint res;
  caddr_t *old_val_ptr;
  if (ht->ht_mutex)
    mutex_enter (ht->ht_mutex);
  if ((0 < ht->ht_dict_max_entries) &&
      ((ht->ht_inserts - ht->ht_deletes) > ht->ht_dict_max_entries) )
    goto skip_insertion; /* see below */
  if ((0 < ht->ht_dict_max_mem_in_use) &&
      (ht->ht_dict_mem_in_use > ht->ht_dict_max_mem_in_use) )
    goto skip_insertion; /* see below */
  old_val_ptr = (caddr_t *)id_hash_get (ht, (caddr_t)(&key));
  if (NULL != old_val_ptr)
    {
      boxint old_int;
      if (DV_LONG_INT != DV_TYPE_OF (old_val_ptr[0]))
              sqlr_new_error ("42000", "SR627",
                "dict_inc_or_put() can not increment a noninteger value" );
      old_int = unbox (old_val_ptr[0]);
      if (0 >= old_int)
        sqlr_new_error ("42000", "SR628",
          "dict_inc_or_put() can not increment a value if it is less than or equal to zero" );
      dk_free_tree (old_val_ptr[0]);
      res = old_int + inc_val;
      old_val_ptr[0] = box_num (res);
    }
  else
    {
      caddr_t val = box_num (inc_val);
      key = box_copy_tree (key);
      res = inc_val;
      if (ht->ht_mutex)
        box_make_tree_mt_safe (key);
      id_hash_set (ht, (caddr_t)(&key), (caddr_t)(&val));
      if (0 < ht->ht_dict_max_mem_in_use)
        ht->ht_dict_mem_in_use += raw_length (val) + raw_length (key) + 3 * sizeof (caddr_t);
    }
  id_hash_iterator (hit, ht);
  ht->ht_dict_version++;
  hit->hit_dict_version++ /* It's incorrect to write hit->hit_dict_version = ht->ht_dict_version because they may be out of sync before the id_hash_put */;
skip_insertion:
  if (ht->ht_mutex)
    mutex_leave (ht->ht_mutex);
  res = ht->ht_inserts - ht->ht_deletes;
  return box_num (res);
}

caddr_t
bif_dict_dec_or_remove (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t *hit = bif_dict_iterator_arg (qst, args, 0, "dict_dec_or_remove", 0);
  id_hash_t *ht = hit->hit_hash;
  caddr_t key = bif_arg (qst, args, 1, "dict_dec_or_remove");
  boxint dec_val = bif_long_range_arg (qst, args, 2, "dict_dec_or_remove", 0, 0xffff);
  caddr_t *old_key_ptr, *old_val_ptr;
  boxint res = 0;
  if (ht->ht_mutex)
    mutex_enter (ht->ht_mutex);
  old_val_ptr = (caddr_t *)id_hash_get (ht, (caddr_t)(&key));
  if (NULL == old_val_ptr)
    res = 0;
  else if (DV_LONG_INT != DV_TYPE_OF (old_val_ptr[0]))
    sqlr_new_error ("42000", "SR629",
      "dict_dec_or_remove() can not decrement a noninteger value" );
  else if (unbox (old_val_ptr[0]) > dec_val)
    {
      boxint old_int;
      old_int = unbox (old_val_ptr[0]);
      if (0 >= old_int)
        sqlr_new_error ("42000", "SR631",
          "dict_dec_or_remove() can not decrement a value if it is less than or equal to zero" );
      if (!ht->ht_mp)
	dk_free_tree (old_val_ptr[0]);
      res = old_int - dec_val;
      old_val_ptr[0] = box_num (res);
      ht->ht_dict_version++;
      hit->hit_dict_version++;
    }
  else
    {
      caddr_t old_key, old_val;
      old_key_ptr = (caddr_t *)id_hash_get_key_by_place (ht, (caddr_t)old_val_ptr);
      old_key = old_key_ptr[0];
      old_val = old_val_ptr[0];
      id_hash_remove (ht, (caddr_t)(&key));
      if (ht->ht_dict_max_mem_in_use > 0)
        ht->ht_dict_mem_in_use -= (raw_length (old_key) + raw_length (old_val) + 3 * sizeof (caddr_t));
      if (!ht->ht_mp)
	{
	  dk_free_tree (old_key);
	  dk_free_tree (old_val);
	}
      id_hash_iterator (hit, ht);
      ht->ht_dict_version++;
      if (hit->hit_chilum != (char *)old_key_ptr)
        hit->hit_dict_version++;
      res = 0;
    }
  if (ht->ht_mutex)
    mutex_leave (ht->ht_mutex);
  return box_num (res);
}

caddr_t
bif_dict_bitor_or_put (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t *hit = bif_dict_iterator_arg (qst, args, 0, "dict_bitor_or_put", 0);
  id_hash_t *ht = hit->hit_hash;
  caddr_t key = bif_arg (qst, args, 1, "dict_bitor_or_put");
  boxint bits_to_set = bif_long_arg (qst, args, 2, "dict_bitor_or_put");
  boxint res;
  caddr_t *old_val_ptr;
  if (ht->ht_mutex)
    mutex_enter (ht->ht_mutex);
  if ((0 < ht->ht_dict_max_entries) &&
      ((ht->ht_inserts - ht->ht_deletes) > ht->ht_dict_max_entries) )
    goto skip_insertion; /* see below */
  if ((0 < ht->ht_dict_max_mem_in_use) &&
      (ht->ht_dict_mem_in_use > ht->ht_dict_max_mem_in_use) )
    goto skip_insertion; /* see below */
  old_val_ptr = (caddr_t *)id_hash_get (ht, (caddr_t)(&key));
  if (NULL != old_val_ptr)
    {
      boxint old_int;
      if (DV_LONG_INT != DV_TYPE_OF (old_val_ptr[0]))
              sqlr_new_error ("42000", "SR627",
                "dict_bitor_or_put() can not apply a bitwise OR to a noninteger value" );
      old_int = unbox (old_val_ptr[0]);
      dk_free_tree (old_val_ptr[0]);
      res = old_int | bits_to_set;
      old_val_ptr[0] = box_num (res);
    }
  else
    {
      caddr_t val = box_num (bits_to_set);
      key = box_copy_tree (key);
      res = bits_to_set;
      if (ht->ht_mutex)
        box_make_tree_mt_safe (key);
      id_hash_set (ht, (caddr_t)(&key), (caddr_t)(&val));
      if (0 < ht->ht_dict_max_mem_in_use)
        ht->ht_dict_mem_in_use += raw_length (val) + raw_length (key) + 3 * sizeof (caddr_t);
    }
  id_hash_iterator (hit, ht);
  ht->ht_dict_version++;
  hit->hit_dict_version++ /* It's incorrect to write hit->hit_dict_version = ht->ht_dict_version because they may be out of sync before the id_hash_put */;
skip_insertion:
  if (ht->ht_mutex)
    mutex_leave (ht->ht_mutex);
  res = ht->ht_inserts - ht->ht_deletes;
  return box_num (res);
}

caddr_t
bif_dict_zap (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t hit, *hit1 = bif_dict_iterator_or_null_arg (qst, args, 0, "dict_zap", 0);
  long destructive = bif_long_range_arg (qst, args, 1, "dict_zap", 1, 3);
  id_hash_t *ht;
  caddr_t *keyp, *valp;
  long len;
  if (NULL == hit1)
    return box_num (0);
  ht = hit1->hit_hash;
  if (ht->ht_mutex)
    mutex_enter (ht->ht_mutex);
  len = ht->ht_inserts - ht->ht_deletes;
  id_hash_iterator (&hit, ht);
  if ((1 != ht->ht_dict_refctr) && !(destructive &= ~1))
    {
      if (ht->ht_mutex)
        mutex_leave (ht->ht_mutex);
      sqlr_new_error ("22023", "SR632", "dict_zap() can not zap a dictionary that is used in many places, if second parameter is 0 or 1");
    }
  while (!ht->ht_mp && hit_next (&hit, (char **)&keyp, (char **)&valp))
        {
           dk_free_tree (keyp[0]);
           dk_free_tree (valp[0]);
        }
      id_hash_clear (ht);
  if (ht->ht_mp)
    {
      mp_free (ht->ht_mp);
      ht->ht_mp = mem_pool_alloc ();
    }
  ht->ht_dict_version++;
  ht->ht_dict_mem_in_use = 0;
  if (ht->ht_mutex)
    mutex_leave (ht->ht_mutex);
  return (caddr_t)box_num (len);
}

caddr_t
bif_dict_size (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t *hit1 = bif_dict_iterator_or_null_arg (qst, args, 0, "dict_size", 0);
  id_hash_t *ht;
  if (NULL == hit1)
    return box_num (0);
  ht = hit1->hit_hash;
  return box_num (ht->ht_inserts - ht->ht_deletes);
}


caddr_t
bif_dict_list_keys (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t hit, *hit1 = bif_dict_iterator_or_null_arg (qst, args, 0, "dict_list_keys", 0);
  boxint destructive = bif_long_arg (qst, args, 1, "dict_list_keys");
  id_hash_t *ht;
  caddr_t *res, *tail, *keyp, *valp;
  long len;
  if (NULL == hit1)
    return list (0);
  ht = hit1->hit_hash;
  if (ht->ht_mutex)
    mutex_enter (ht->ht_mutex);
  len = ht->ht_inserts - ht->ht_deletes;
  if ((len * sizeof (caddr_t)) & ~0xffffff)
    {
      if (ht->ht_mutex)
	mutex_leave (ht->ht_mutex);
      sqlr_new_error ("22023", "SR...", "The result vector is too large");
    }
  res = (caddr_t *)dk_alloc_box (len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  tail = res;
  id_hash_iterator (&hit, ht);
  if (1 != ht->ht_dict_refctr)
    destructive &= ~1;
  while (hit_next (&hit, (char **)&keyp, (char **)&valp))
    {
      if (destructive && !ht->ht_mp)
        {
          (tail++)[0] = keyp[0];
	  dk_free_tree (valp[0]);
        }
      else
        {
          (tail++)[0] = box_copy_tree (keyp[0]);
        }
    }
  if (destructive)
    {
      id_hash_clear (ht);
      if (ht->ht_mp)
	{
	  mp_free (ht->ht_mp);
	  ht->ht_mp = mem_pool_alloc ();
	}
      ht->ht_dict_version++;
      ht->ht_dict_mem_in_use = 0;
    }
  if (ht->ht_mutex)
    mutex_leave (ht->ht_mutex);
  return (caddr_t)res;
}

caddr_t
bif_dict_destructive_list_rnd_keys (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t hit, *hit1 = bif_dict_iterator_or_null_arg (qst, args, 0, "dict_destructive_list_rnd_keys", 0);
  long batch_size = bif_long_range_arg (qst, args, 1, "dict_destructive_list_rnd_keys", 0xff, 0xffffff / sizeof (caddr_t));
  id_hash_t *ht;
  caddr_t *res, *tail;
  long len, bucket_rnd;
  if (NULL == hit1)
    return list (0);
  ht = hit1->hit_hash;
  if (ht->ht_mutex)
    mutex_enter (ht->ht_mutex);
  len = ht->ht_inserts - ht->ht_deletes;
  if (len > batch_size)
    len = batch_size;
  if (0 == len)
    {
      res = (caddr_t *)list (0);
      goto res_done; /* see below */
    }
  res = (caddr_t *)dk_alloc_box (len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  tail = res;
  id_hash_iterator (&hit, ht);
/* It is important that \c len is greater than zero before this loop, because check is made after writing key to \c tail, not before */
  for (bucket_rnd = (ht->ht_inserts - ht->ht_deletes) + ht->ht_buckets; bucket_rnd--; /* no step */)
    {
      caddr_t key, val;
      while (id_hash_remove_rnd (ht, bucket_rnd, (caddr_t)&key, (caddr_t)&val))
	{
	  if (!ht->ht_mp)
	    {
	      dk_free_tree (val);
	      (tail++)[0] = key;
	    }
	  else
	    (tail++)[0] = box_copy_tree (key);
          if (!(--len))
            goto res_done; /* see below */
	}
    }
  GPF_T1 ("bif_" "dict_destructive_list_rnd_keys(): corrupted hashtable");
  return NULL; /* never reached */
res_done:
  ht->ht_dict_version++;
  if (ht->ht_mutex)
    mutex_leave (ht->ht_mutex);
  return (caddr_t)res;
}

caddr_t
bif_dict_to_vector (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t hit, *hit1 = bif_dict_iterator_or_null_arg (qst, args, 0, "dict_to_vector", 0);
  boxint destructive = bif_long_arg (qst, args, 1, "dict_to_vector");
  id_hash_t *ht;
  caddr_t *res, *tail, *keyp, *valp;
  size_t box_len;
  if (NULL == hit1)
    return list (0);
  ht = hit1->hit_hash;
  if (ht->ht_mutex)
    mutex_enter (ht->ht_mutex);
  box_len = (ht->ht_inserts - ht->ht_deletes) * 2 * sizeof (caddr_t);
  if (box_len >= MAX_BOX_LENGTH)
    {
      if (ht->ht_mutex)
	mutex_leave (ht->ht_mutex);
      sqlr_new_error ("22023", ".....", "The result array too large");
    }
  res = (caddr_t *)dk_alloc_box (box_len, DV_ARRAY_OF_POINTER);
  tail = res;
  id_hash_iterator (&hit, ht);
  if (1 != ht->ht_dict_refctr)
    destructive &= ~1;
  while (hit_next (&hit, (char **)&keyp, (char **)&valp))
    {
      if (destructive && !ht->ht_mp)
        {
          (tail++)[0] = keyp[0];
          (tail++)[0] = valp[0];
        }
      else
        {
          (tail++)[0] = box_copy_tree (keyp[0]);
          (tail++)[0] = box_copy_tree (valp[0]);
        }
    }
  if (destructive)
    {
      id_hash_clear (ht);
      if (ht->ht_mp)
	{
	  mp_free (ht->ht_mp);
	  ht->ht_mp = mem_pool_alloc ();
	}
      ht->ht_dict_version++;
      ht->ht_dict_mem_in_use = 0;
    }
  if (ht->ht_mutex)
    mutex_leave (ht->ht_mutex);
  return (caddr_t)res;
}

caddr_t
bif_dict_iter_rewind (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t *hit = bif_dict_iterator_or_null_arg (qst, args, 0, "dict_iter_rewind", 0);
  id_hash_t *ht;
  if (NULL == hit)
    return box_num (0);
  ht = hit->hit_hash;
  if (ht->ht_mutex)
    mutex_enter (ht->ht_mutex);
  hit->hit_bucket = 0;
  hit->hit_chilum = NULL;
  hit->hit_dict_version = ht->ht_dict_version;
  if (ht->ht_mutex)
    mutex_leave (ht->ht_mutex);
  return box_num (ht->ht_inserts - ht->ht_deletes);
}

caddr_t
bif_dict_iter_next (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  id_hash_iterator_t *hit = bif_dict_iterator_or_null_arg (qst, args, 0, "dict_iter_next", 0);
  id_hash_t *ht;
  int res = 0;
  if (3 > BOX_ELEMENTS(args))
    sqlr_new_error ("22003", "SR345", "Too few arguments for dict_iter_next ()");
  if (NULL == hit)
    return box_num (0);
  ht = hit->hit_hash;
  if (ht->ht_mutex)
    mutex_enter (ht->ht_mutex);
  if (hit->hit_dict_version == ht->ht_dict_version)
    {
      caddr_t *key, *data;
      res = hit_next (hit, (char **)(&key), (char **)(&data));
      if (res)
        {
          if ((SSL_VARIABLE == args[1]->ssl_type) || (IS_SSL_REF_PARAMETER (args[1]->ssl_type)))
            qst_set (qst, args[1], box_copy_tree (key[0]));
          if ((SSL_VARIABLE == args[2]->ssl_type) || (IS_SSL_REF_PARAMETER (args[2]->ssl_type)))
            qst_set (qst, args[2], box_copy_tree (data[0]));
        }
    }
  else
    {
      if (ht->ht_mutex)
        mutex_leave (ht->ht_mutex);
      sqlr_new_error ("22023", "SR630", "Function dict_iter_next() tries to iterate a volatile dictionary changed after last dict_iter_rewind()");
    }
  return box_num (res);
}

caddr_t
bif_dict_key_hash (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t key = bif_arg (qst, args, 0, "dict_key_hash");
  return box_num (treehash ((char *)&key));
}

caddr_t
bif_dict_key_eq (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t key1 = bif_arg (qst, args, 0, "dict_key_eq");
  caddr_t key2 = bif_arg (qst, args, 1, "dict_key_eq");
  return box_num (treehashcmp ((char *)(&key1), (char *)(&key2)));
}

int
gvector_sort_cmp (caddr_t * e1, caddr_t * e2, vector_sort_t * specs)
{
  caddr_t key1 = e1 [specs->vs_key_ofs];
  caddr_t key2 = e2 [specs->vs_key_ofs];
  int cmp;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (key1))
    {
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (key2))
        {
          int len1 = BOX_ELEMENTS (key1);
          int len2 = BOX_ELEMENTS (key2);
          int idx;
          if (len1 != len2)
            {
              cmp = ((len1 > len2) ? DVC_GREATER : DVC_LESS);
              goto cmp_done;
            }
          for (idx = 0; idx < len1; idx++)
            {
              cmp = cmp_boxes (((caddr_t *)key1)[idx], ((caddr_t *)key2)[idx], NULL, NULL);
              if (DVC_MATCH != cmp)
                goto cmp_done;
            }
          cmp = DVC_MATCH;
          goto cmp_done;
        }
      cmp = DVC_GREATER;
      goto cmp_done;
    }
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (key2))
    {
      cmp = DVC_LESS;
      goto cmp_done;
    }
  cmp = cmp_boxes (key1, key2, NULL, NULL);

cmp_done:
  if ((0 == specs->vs_sort_asc) && (DVC_MATCH != cmp))
    return ((DVC_LESS == cmp) ? DVC_GREATER : DVC_LESS);
  return cmp;
}


#ifdef VECTOR_SORT_DEBUG
#define VECTOR_CHECK_BLOCK(blk,specs) do { \
    int vctchkblk_ctr = specs->vs_block_elts; \
    while (vctchkblk_ctr--) dk_check_tree ((blk)[vctchkblk_ctr]); \
  } while (0)
#else
#define VECTOR_CHECK_BLOCK(blk,specs)
#endif

#define VECTOR_SORT_COPY(a,b,specs) do { \
    int bsize = (specs)->vs_block_size; \
    VECTOR_CHECK_BLOCK(a,specs); \
    VECTOR_CHECK_BLOCK(b,specs); \
    memcpy ((a), (b), bsize); \
  } while (0)


#define VECTOR_SORT_SWAP(a,b,specs) do { \
    caddr_t tmp[MAX_VECTOR_BSORT_BLOCK]; \
    int bsize = (specs)->vs_block_size; \
    VECTOR_CHECK_BLOCK(a,specs); \
    VECTOR_CHECK_BLOCK(b,specs); \
    memcpy (tmp, (a), bsize); \
    memcpy ((a), (b), bsize); \
    memcpy ((b), tmp, bsize); \
  } while (0)


void
vector_bsort (caddr_t *bs, int n_bufs, vector_sort_t * specs)
{
  /* Bubble sort n_bufs first buffers in the array. */
  int bels = specs->vs_block_elts;
  int n, m;
  for (m = n_bufs - 1; m > 0; m--)
    {
      for (n = 0; n < m; n++)
	{
          caddr_t *a = bs + (n * bels);
          caddr_t *b = a + bels;
	  if (DVC_GREATER == specs->vs_cmp_fn (a, b, specs))
	    VECTOR_SORT_SWAP (a, b, specs);
	}
    }
#ifdef VECTOR_SORT_DEBUG
  dk_check_domain_of_connectivity (specs->vs_whole_vector);
#endif
}


static void
vector_sort_reverse_buffer (caddr_t *in, int n_in, vector_sort_t *specs)
{
  int bels = specs->vs_block_elts;
  caddr_t *a = in;
  caddr_t *b = in + (n_in - 1) * bels;
  while (a < b)
    {
      VECTOR_SORT_SWAP (a, b, specs);
      a += bels;
      b -= bels;
    }
#ifdef VECTOR_SORT_DEBUG
  dk_check_domain_of_connectivity (specs->vs_whole_vector);
#endif
}


void
vector_qsort_int (caddr_t * in, caddr_t * left, int n_in, int depth, vector_sort_t * specs)
{
  if (n_in < 3)
    {
      int bels;
      if (n_in < 2)
        return;
      bels = specs->vs_block_elts;
      if (DVC_GREATER == specs->vs_cmp_fn (in, in + bels, specs))
	{
          VECTOR_SORT_SWAP (in, in + bels, specs);
	}
    }
  else
    {
      int bels = specs->vs_block_elts;
      int bsize = specs->vs_block_size;
      caddr_t * split;
      int mid_filled = 0;
      caddr_t mid [MAX_VECTOR_BSORT_BLOCK];
      int n_left = 0, n_right = n_in - 1;
      int inx, above_is_all_splits = 1;
      if (depth > 30)
	{
	  vector_bsort (in, n_in, specs);
	  return;
	}

      split = in + (n_in / 2) * bels;

      for (inx = 0; inx < n_in; inx++)
	{
	  caddr_t * this_pg = in + inx * bels;
	  int rc = specs->vs_cmp_fn (this_pg, split, specs);
	  if (!mid_filled && DVC_MATCH == rc)
	    {
              memcpy (mid, this_pg, bsize);
              mid_filled = 1;
	      continue;
	    }
	  if (DVC_LESS == rc)
            memcpy (left + (n_left++) * bels, this_pg, bsize);
	  else
	    {
	      if (above_is_all_splits && rc == DVC_GREATER)
		above_is_all_splits = 0;
	      memcpy (left + (n_right--) * bels, this_pg, bsize);
	    }
	}
      vector_qsort_int (left, in, n_left, depth + 1, specs);
      vector_sort_reverse_buffer (left + (n_right + 1) * bels, (n_in - n_right) - 1, specs);
      if (!above_is_all_splits)
	vector_qsort_int (left + (n_right + 1) * bels, in + (n_right + 1) * bels,
	    (n_in - n_right) - 1, depth + 1, specs);
      memcpy (in, left, n_left * bsize);
#ifdef DEBUG
      if (!mid_filled)
        GPF_T1("gvector_qsort_int can not find split value in range");
#endif
      memcpy (in + n_left * bels, mid, bsize);
      memcpy (in + (n_right + 1) * bels, left + (n_right + 1) * bels,
	  ((n_in - n_right) - 1) * bsize);
#ifdef VECTOR_SORT_DEBUG
  dk_check_domain_of_connectivity (specs->vs_whole_vector);
  dk_check_domain_of_connectivity (specs->vs_whole_tmp);
#endif
    }
}

void
vector_qsort (caddr_t *vect, int group_count, vector_sort_t *specs)
{
  caddr_t *temp;
  specs->vs_block_size = specs->vs_block_elts * sizeof (caddr_t);
#ifdef VECTOR_SORT_DEBUG
  temp = (caddr_t*) dk_alloc_box_zero (box_length (vect), DV_ARRAY_OF_POINTER);
  specs->vs_whole_vector = vect;
  specs->vs_whole_tmp = temp;
#else
  temp = (caddr_t*) dk_alloc_box (box_length (vect), DV_ARRAY_OF_POINTER);
#endif
  vector_qsort_int (vect, temp, group_count, 0, specs);
#ifdef VECTOR_SORT_DEBUG
  dk_check_tree (vect);
#endif
  dk_free_box ((caddr_t)temp);
}

typedef struct dsort_itm_s {
  boxint di_key;
  int di_pos;
} dsort_itm_t;

caddr_t
bif_gvector_sort_imp (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, const char *funname, char algo)
{
  caddr_t *vect = (caddr_t *)bif_array_of_pointer_arg (qst, args, 0, funname);
  int vect_elems = BOX_ELEMENTS (vect);
  int block_elts = bif_long_range_arg (qst, args, 1, funname, 1, 1024);
  int key_ofs = bif_long_range_arg (qst, args, 2, funname, 0, 1024);
  int sort_asc = bif_long_range_arg (qst, args, 3, funname, 0, 1);
  int group_count;
  vector_sort_t specs;
  if (block_elts <= 0)
    sqlr_new_error ("22023", "SR488", "Second argument of %s() should be positive integer", funname);
  if (block_elts > MAX_VECTOR_BSORT_BLOCK)
    sqlr_new_error ("22023", "SR488", "Second argument of %s() is greater than maximum supported block length %d", funname, MAX_VECTOR_BSORT_BLOCK);
  if (vect_elems % block_elts != 0)
    sqlr_new_error ("22023", "SR489", "In call of %s(), length of vector in argument #1 is not a whole multiple of argument #2", funname);
  if ((0 > key_ofs) || (key_ofs >= block_elts))
    sqlr_new_error ("22023", "SR490", "In call of %s(), argument #3 should be nonnegative integer that is less than argument #2", funname);
  group_count = vect_elems / block_elts;
  if (1 >= group_count)
    return box_num (group_count); /* No need to sort empty or single-element vector */
  if ('Q' == algo)
    {
      specs.vs_block_elts = block_elts;
      specs.vs_key_ofs = key_ofs;
      specs.vs_sort_asc = sort_asc;
      specs.vs_cmp_fn = gvector_sort_cmp;
      vector_qsort (vect, group_count, &specs);
    }
  else /* if ('D' == algo) */
    {
      uint32 *offsets;
      dsort_itm_t *src, *tgt, *swap;
      caddr_t *vect_copy;
      int shift, offsets_count, itm_ctr, twobyte, max_twobyte;
      boxint minv = BOXINT_MAX, maxv = BOXINT_MIN;
      src = (dsort_itm_t *) dk_alloc (group_count * sizeof (dsort_itm_t));
      for (itm_ctr = group_count; itm_ctr--; /* no step */)
        {
          caddr_t key = vect[itm_ctr * block_elts + key_ofs];
          dtp_t key_dtp = DV_TYPE_OF (key);
          boxint key_val = 0;
          if (DV_LONG_INT == key_dtp)
            key_val = unbox (key);
          else if (DV_IRI_ID == key_dtp)
            key_val = unbox_iri_id (key);
          else
            {
              dk_free ((void *)src, group_count * sizeof (dsort_itm_t));
              sqlr_new_error ("22023", "SR572",
	        "Function %s needs IRI_IDs or integers as key elements of array, "
		"not a value type %s (%d); position of bad key in array is %d",
		funname, dv_type_title (key_dtp), key_dtp, itm_ctr * block_elts + key_ofs );
            }
          if (key_val < minv)
            minv = key_val;
          if (key_val > maxv)
            maxv = key_val;
          src[itm_ctr].di_key = key_val;
          src[itm_ctr].di_pos = itm_ctr;
        }
      if ((maxv - minv) < 0L)
        {
          dk_free ((void *)src, group_count * sizeof (dsort_itm_t));
          sqlr_new_error ("22023", "SR573",
	    "Function %s has failed to sort array: the difference between greatest and smallest keys does not fit 63 bit range; consider using gvector_sort()", funname );
        }
      if (sort_asc)
        {
          for (itm_ctr = group_count; itm_ctr--; /* no step */)
            {
              src[itm_ctr].di_key -= minv;
            }
          maxv -= minv;
        }
      else
        {
          for (itm_ctr = group_count; itm_ctr--; /* no step */)
            {
              src[itm_ctr].di_key = maxv - src[itm_ctr].di_key;
            }
          maxv = maxv - minv;
        }
      tgt = (dsort_itm_t *) dk_alloc (group_count * sizeof (dsort_itm_t));
      offsets_count = ((maxv >= 0x10000) ? 0x10000 : (maxv+1));
      offsets = (uint32 *) dk_alloc (offsets_count * sizeof (uint32));
      for (shift = 0; shift < 8 * sizeof (boxint); shift += 16)
        {
          if (0 == (maxv >> shift))
            break;
          max_twobyte = (((maxv >> shift) >= 0x10000L) ? 0x10000 : (int)((maxv >> shift)+1));
          memset (offsets, 0, max_twobyte * sizeof (uint32));
          for (itm_ctr = group_count; itm_ctr--; /* no step */)
            {
              (offsets[(src[itm_ctr].di_key >> shift) & 0xffff])++;
            }
          if (group_count == offsets[0])
            continue; /* Special case to optimize sorting of array of IRI_IDs of bnodes and iri nodes */
          for (twobyte = 1; twobyte < max_twobyte; twobyte++)
            offsets [twobyte] += offsets [twobyte-1];
#ifndef DEBUG
          if (group_count != offsets [max_twobyte - 1])
            GPF_T1 ("Bad offsets in gvector_digit_sort()");
#endif
          for (itm_ctr = group_count; itm_ctr--; /* no step */)
            {
              int ofs = --(offsets[(src[itm_ctr].di_key >> shift) & 0xffff]);
              tgt[ofs] = src[itm_ctr];
            }
          swap = src;
          src = tgt;
          tgt = swap;
        }
      vect_copy = (caddr_t *)dk_alloc (vect_elems * sizeof (caddr_t));
      memcpy (vect_copy, vect, vect_elems * sizeof (caddr_t));
      for (itm_ctr = group_count; itm_ctr--; /* no step */)
        {
          memcpy (vect + itm_ctr * block_elts,
            vect_copy + src[itm_ctr].di_pos * block_elts,
            block_elts * sizeof (caddr_t) );
        }
#ifndef NDEBUG
      dk_check_tree (vect);
#endif
      dk_free (src, group_count * sizeof (dsort_itm_t));
      dk_free (tgt, group_count * sizeof (dsort_itm_t));
      dk_free (offsets, offsets_count * sizeof (uint32));
      dk_free (vect_copy, vect_elems * sizeof (caddr_t));
    }
  return box_num (group_count);
}

caddr_t
bif_gvector_sort (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_gvector_sort_imp (qst, err_ret, args, "gvector_sort", 'Q');
}

caddr_t
bif_gvector_digit_sort (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_gvector_sort_imp (qst, err_ret, args, "gvector_digit_sort", 'D');
}

caddr_t
bif_rowvector_sort_imp (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, const char *funname, char algo, int block_elts, int key_ofs, int sort_asc)
{
  caddr_t *vect = (caddr_t *)bif_array_arg (qst, args, 0, funname);
  int vect_elems = BOX_ELEMENTS (vect);
  int key_item_inx = bif_long_range_arg (qst, args, 1, funname, 0, 1024);
  int group_count;
  vector_sort_t specs;
  if (block_elts <= 0)
    sqlr_new_error ("22023", "SR488", "Number of elements in block should be positive integer in call of %s()", funname);
  if (block_elts > MAX_VECTOR_BSORT_BLOCK)
    sqlr_new_error ("22023", "SR488", "Number of elements in block is greater than maximum block length %d supported by %s()", MAX_VECTOR_BSORT_BLOCK, funname);
  if (vect_elems % block_elts != 0)
    sqlr_new_error ("22023", "SR489", "In call of %s(), length of vector in argument #1 is not a whole multiple of number of elements in block", funname);
  if ((0 > key_ofs) || (key_ofs >= block_elts))
    sqlr_new_error ("22023", "SR490", "In call of %s(), offset of key in block should be nonnegative integer that is less than number of elements in block", funname);
  group_count = vect_elems / block_elts;
  if (1 >= group_count)
    return box_num (group_count); /* No need to sort empty or single-element vector */
  specs.vs_block_elts = block_elts;
  specs.vs_key_ofs = key_ofs;
  specs.vs_sort_asc = sort_asc;
  specs.vs_block_size = specs.vs_block_elts * sizeof (caddr_t);
  if ('Q' == algo)
    {
      GPF_T1("rowvector_qsort_int is not yet implemented");
      /*rowvector_qsort_int (vect, temp, vect_elems, 0, &specs); */
    }
  else /* if (('D' == algo) || ('S' == algo) || ('O' == algo)) */
    {
      uint32 *offsets;
      dsort_itm_t *src, *tgt, *swap;
      caddr_t *vect_copy;
      int shift, offsets_count, itm_ctr, twobyte, max_twobyte;
      boxint minv = BOXINT_MAX, maxv = BOXINT_MIN;
      boxint key_val = 0;
      src = (dsort_itm_t *) dk_alloc (group_count * sizeof (dsort_itm_t));
      for (itm_ctr = group_count; itm_ctr--; /* no step */)
        {
          caddr_t *row = (caddr_t *)(vect[itm_ctr*block_elts + key_ofs]);
          caddr_t key;
          dtp_t key_dtp;
          if (DV_ARRAY_OF_POINTER != DV_TYPE_OF(row))
            {
              dk_free ((void *)src, group_count * sizeof (dsort_itm_t));
              if (1 == block_elts)
                sqlr_new_error ("22023", "SR572",
                  "Function %s needs vector of vectors, "
                  "found a value type %s (%d); index of bad item in array is %d",
                  funname, dv_type_title (key_dtp), key_dtp, itm_ctr );
              else
                sqlr_new_error ("22023", "SR572",
                  "Function %s needs vector of blocks with vectors in key positions, "
                  "found a key type %s (%d) instead; index of bad item in array is %d = %d * %d + %d (block index * no of items per block + key offset)",
                  funname, dv_type_title (key_dtp), key_dtp, itm_ctr*block_elts + key_ofs, itm_ctr, block_elts, key_ofs );
            }
          if (BOX_ELEMENTS(row) > key_item_inx)
            {
              key = row[key_item_inx];
              key_dtp = DV_TYPE_OF (key);
            }
          else if ('G' == algo)
            {
              key = NULL;
              key_dtp = DV_LONG_INT;
            }
          else
            {
              dk_free ((void *)src, group_count * sizeof (dsort_itm_t));
              if (1 == block_elts)
                sqlr_new_error ("22023", "SR572",
                  "Function %s needs vector of vectors, each item should be at least %d values long "
                  "found an item of length %ld; index of bad item in array is %d",
                  funname, key_item_inx+1, (long)(BOX_ELEMENTS(row)), itm_ctr );
              else
                sqlr_new_error ("22023", "SR572",
                  "Function %s needs vector of blocks with vectors in key positions, each key vector should be at least %d values long "
                  "found an item of length %ld; index of bad item in array is %d = %d * %d + %d (block index * no of items per block + key offset)",
                  funname, key_item_inx+1, (long)(BOX_ELEMENTS(row)), itm_ctr*block_elts + key_ofs, itm_ctr, block_elts, key_ofs );
              key = NULL; key_dtp = 0; /* to keep compiler happy */
            }
          if (DV_LONG_INT == key_dtp)
            key_val = unbox (key);
          else if (DV_IRI_ID == key_dtp)
            key_val = unbox_iri_id (key);
          else if (((DV_STRING == key_dtp) || (DV_UNAME == key_dtp)) && (('S' == algo) || (('O' == algo) && (BF_IRI & box_flags (key)))))
            {
              /* caddr_t iid = key_name_to_iri_id (((query_instance_t *)qst)->qi_trx, key, 0); */
              caddr_t iid = iri_to_id (qst, key, IRI_TO_ID_IF_KNOWN, err_ret);
              if (NULL != iid)
                {
                  key_val = unbox_iri_id (iid);
                  dk_free_box (iid);
                }
              else
                {
                  if (DV_UNAME == key_dtp)
                    DV_UNAME_BOX_HASH(key_val,key);
                  else
                    BYTE_BUFFER_HASH(key_val,key,box_length(key)-1);
                  key_val |= 0x84000000L;
                }
            }
          else if ('O' == algo)
            {
              if (DV_RDF == key_dtp)
                {
                  rdf_box_t *rb = (rdf_box_t *)key;
                  if (rb->rb_chksum_tail)
                    {
                      caddr_t cs = ((rdf_bigbox_t *)rb)->rbb_chksum;
                      BYTE_BUFFER_HASH(key_val,cs,box_length(cs)-1);
                    }
                  else if (rb->rb_is_complete)
                    key_val = box_hash (rb->rb_box);
                  else
                    key_val = rb->rb_ro_id;
                }
              else
                key_val = box_hash (key);
              key_val |= 0x88000000L;
            }
          else
            {
              dk_free ((void *)src, group_count * sizeof (dsort_itm_t));
              if (1 == block_elts)
                sqlr_new_error ("22023", "SR572",
                  "Function %s needs IRI_IDs or integers as key elements of array, "
                  "not a value type %s (%d); index of bad item in array is %d",
                  funname, dv_type_title (key_dtp), key_dtp, itm_ctr );
              else
                sqlr_new_error ("22023", "SR572",
                  "Function %s needs IRI_IDs or integers as key elements of array, "
                  "not a value type %s (%d); index of bad item in array is %d = %d * %d + %d (block index * no of items per block + key offset)",
                  funname, dv_type_title (key_dtp), key_dtp, itm_ctr*block_elts + key_ofs, itm_ctr, block_elts, key_ofs );
            }
          if (key_val < minv)
            minv = key_val;
          if (key_val > maxv)
            maxv = key_val;
          src[itm_ctr].di_key = key_val;
          src[itm_ctr].di_pos = itm_ctr;
        }
      if ((maxv - minv) < 0L)
        {
          dk_free ((void *)src, group_count * sizeof (dsort_itm_t));
          sqlr_new_error ("22023", "SR573",
            "Function %s has failed to sort array: the difference between greatest and smallest keys does not fit 63 bit range"
            /*"; consider using rowvector_sort()"*/, funname );
        }
      if (sort_asc)
        {
          for (itm_ctr = group_count; itm_ctr--; /* no step */)
            {
              src[itm_ctr].di_key -= minv;
            }
          maxv -= minv;
        }
      else
        {
          for (itm_ctr = group_count; itm_ctr--; /* no step */)
            {
              src[itm_ctr].di_key = maxv - src[itm_ctr].di_key;
            }
          maxv = maxv - minv;
        }
      tgt = (dsort_itm_t *) dk_alloc (group_count * sizeof (dsort_itm_t));
      offsets_count = ((maxv >= 0x10000) ? 0x10000 : (maxv+1));
      offsets = (uint32 *) dk_alloc (offsets_count * sizeof (uint32));
      for (shift = 0; shift < 8 * sizeof (boxint); shift += 16)
        {
          if (0 == (maxv >> shift))
            break;
          max_twobyte = (((maxv >> shift) >= 0x10000L) ? 0x10000 : (int)((maxv >> shift)+1));
          memset (offsets, 0, max_twobyte * sizeof (uint32));
          for (itm_ctr = group_count; itm_ctr--; /* no step */)
            {
              (offsets[(src[itm_ctr].di_key >> shift) & 0xffff])++;
            }
          if (group_count == offsets[0])
            continue; /* Special case to optimize sorting of array of IRI_IDs of bnodes and iri nodes */
          for (twobyte = 1; twobyte < max_twobyte; twobyte++)
            offsets [twobyte] += offsets [twobyte-1];
#ifndef DEBUG
          if (group_count != offsets [max_twobyte - 1])
            GPF_T1 ("Bad offsets in rowvector_digit_sort()");
#endif
          for (itm_ctr = group_count; itm_ctr--; /* no step */)
            {
              int ofs = --(offsets[(src[itm_ctr].di_key >> shift) & 0xffff]);
              tgt[ofs] = src[itm_ctr];
            }
          swap = src;
          src = tgt;
          tgt = swap;
        }
      vect_copy = (caddr_t *)dk_alloc (vect_elems * sizeof (caddr_t));
      memcpy (vect_copy, vect, vect_elems * sizeof (caddr_t));
      if (1 == block_elts)
        {
          for (itm_ctr = vect_elems; itm_ctr--; /* no step */)
            vect[itm_ctr] = vect_copy[src[itm_ctr].di_pos];
        }
      else
        {
          for (itm_ctr = group_count; itm_ctr--; /* no step */)
            VECTOR_SORT_COPY (vect + itm_ctr * block_elts, vect_copy + src[itm_ctr].di_pos * block_elts, &specs);
        }
#ifndef NDEBUG
      dk_check_tree (vect);
#endif
      dk_free (src, group_count * sizeof (dsort_itm_t));
      dk_free (tgt, group_count * sizeof (dsort_itm_t));
      dk_free (offsets, offsets_count * sizeof (uint32));
      dk_free (vect_copy, vect_elems * sizeof (caddr_t));
    }
  return box_num (group_count);
}

caddr_t
bif_rowvector_digit_sort (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int sort_asc = bif_long_range_arg (qst, args, 2, "rowvector_digit_sort", 0, 1);
  return bif_rowvector_sort_imp (qst, err_ret, args, "rowvector_digit_sort", 'D', 1, 0, sort_asc);
}

caddr_t
bif_rowvector_graph_sort (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int sort_asc = bif_long_range_arg (qst, args, 2, "rowvector_graph_sort", 0, 1);
  return bif_rowvector_sort_imp (qst, err_ret, args, "rowvector_graph_sort", 'G', 1, 0, sort_asc);
}

caddr_t
bif_rowvector_subj_sort (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int sort_asc = bif_long_range_arg (qst, args, 2, "rowvector_subj_sort", 0, 1);
  return bif_rowvector_sort_imp (qst, err_ret, args, "rowvector_subj_sort", 'S', 1, 0, sort_asc);
}

caddr_t
bif_rowvector_obj_sort (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int sort_asc = bif_long_range_arg (qst, args, 2, "rowvector_obj_sort", 0, 1);
  return bif_rowvector_sort_imp (qst, err_ret, args, "rowvector_obj_sort", 'O', 1, 0, sort_asc);
}

caddr_t
bif_rowgvector_subj_sort (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int block_elts = bif_long_range_arg (qst, args, 2, "rowgvector_subj_sort", 1, 1024);
  int key_ofs = bif_long_range_arg (qst, args, 3, "rowgvector_subj_sort", 0, 1024);
  int sort_asc = bif_long_range_arg (qst, args, 4, "rowgvector_subj_sort", 0, 1);
  return bif_rowvector_sort_imp (qst, err_ret, args, "rowgvector_subj_sort", 'S', block_elts, key_ofs, sort_asc);
}

caddr_t
bif_rowvector_graph_partition (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  const char *funname = "rowvector_graph_partition";
  const int block_elts = 1;
  const int key_ofs = 0;
  caddr_t **vect = (caddr_t **)bif_array_arg (qst, args, 0, funname);
  int vect_elems = BOX_ELEMENTS (vect);
  int key_item_inx = bif_long_range_arg (qst, args, 1, funname, 0, 1024);
  int group_count, itm_ctr;
  int partition_ctr = 0, partition_count = 0;
  int prev_g_dtp = 1;
  int start_itm_ctr = 0;
  caddr_t prev_g = NULL;
  caddr_t **res;
#if 0
  vector_sort_t specs;
  if (block_elts <= 0)
    sqlr_new_error ("22023", "SR488", "Number of elements in block should be positive integer in call of %s()", funname);
  if (block_elts > MAX_VECTOR_BSORT_BLOCK)
    sqlr_new_error ("22023", "SR488", "Number of elements in block is greater than maximum block length %d supported by %s()", MAX_VECTOR_BSORT_BLOCK, funname);
  if (vect_elems % block_elts != 0)
    sqlr_new_error ("22023", "SR489", "In call of %s(), length of vector in argument #1 is not a whole multiple of number of elements in block", funname);
  if ((0 > key_ofs) || (key_ofs >= block_elts))
    sqlr_new_error ("22023", "SR490", "In call of %s(), offset of key in block should be nonnegative integer that is less than number of elements in block", funname);
#endif
  group_count = vect_elems / block_elts;
  if (0 >= group_count)
    return dk_alloc_box (0, DV_ARRAY_OF_POINTER);
  for (itm_ctr = 0; itm_ctr < group_count; itm_ctr++)
    {
      caddr_t *row = vect[itm_ctr * block_elts + key_ofs];
      caddr_t key;
      dtp_t key_dtp;
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF(row))
        {
          if (1 == block_elts)
            sqlr_new_error ("22023", "SR572",
              "Function %s needs vector of vectors, "
              "found a value type %s (%d); index of bad item in array is %d",
              funname, dv_type_title (key_dtp), key_dtp, itm_ctr );
          else
            sqlr_new_error ("22023", "SR572",
              "Function %s needs vector of blocks with vectors in key positions, "
              "found a key type %s (%d) instead; index of bad item in array is %d = %d * %d + %d (block index * no of items per block + key offset)",
              funname, dv_type_title (key_dtp), key_dtp, itm_ctr*block_elts + key_ofs, itm_ctr, block_elts, key_ofs );
        }
      if (BOX_ELEMENTS(row) > key_item_inx)
        {
          key = row[key_item_inx];
          key_dtp = DV_TYPE_OF (key);
        }
      else
        {
          key = NULL;
          key_dtp = 0;
        }
      if (key_dtp == prev_g_dtp)
        {
          switch (key_dtp)
            {
              case 0: continue;
              case DV_LONG_INT: if (unbox (key) == unbox (prev_g)) continue; break;
              case DV_IRI_ID: if (unbox_iri_id (key) == unbox_iri_id (prev_g)) continue; break;
              case DV_STRING: case DV_UNAME: if ((box_length (key) == box_length (prev_g)) && !memcmp (key, prev_g, box_length (key)-1)) continue; break;
              default:
                sqlr_new_error ("22023", "SR572",
                 "Function %s needs IRI_IDs or integers or strings as key elements of array, "
                 "not a value type %s (%d); position of bad key in array is %d",
                 funname, dv_type_title (key_dtp), key_dtp, itm_ctr * block_elts + key_ofs );
            }
        }
      partition_count++;
      prev_g = key;
      prev_g_dtp = key_dtp;
    }
  prev_g_dtp = 1;
  res = (caddr_t **)dk_alloc_box_zero (partition_count * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (itm_ctr = 0; itm_ctr < group_count; itm_ctr++)
    {
      caddr_t *row = vect[itm_ctr * block_elts + key_ofs];
      caddr_t key;
      dtp_t key_dtp;
      if (BOX_ELEMENTS(row) > key_item_inx)
        {
          key = row[key_item_inx];
          key_dtp = DV_TYPE_OF (key);
        }
      else
        {
          key = NULL;
          key_dtp = 0;
        }
      if (key_dtp == prev_g_dtp)
        {
          switch (key_dtp)
            {
              case 0: continue;
              case DV_LONG_INT: if (unbox (key) == unbox (prev_g)) continue; break;
              case DV_IRI_ID: if (unbox_iri_id (key) == unbox_iri_id (prev_g)) continue; break;
              case DV_STRING: case DV_UNAME: if ((box_length (key) == box_length (prev_g)) && !memcmp (key, prev_g, box_length (key)-1)) continue; break;
              default: break;
            }
        }
      if (itm_ctr)
        {
          size_t cut_size = (itm_ctr - start_itm_ctr) * block_elts * sizeof (caddr_t);
          caddr_t **src_start = vect + (start_itm_ctr * block_elts);
          caddr_t *cut = (caddr_t *)dk_alloc_box (cut_size, DV_ARRAY_OF_POINTER);
          memcpy (cut, src_start, cut_size);
          memset (src_start, 0, cut_size);
          res[partition_ctr++] = cut;
        }
      start_itm_ctr = itm_ctr;
      prev_g = key;
      prev_g_dtp = key_dtp;
    }
  if (start_itm_ctr < group_count)
    {
      size_t cut_size = (itm_ctr - start_itm_ctr) * block_elts * sizeof (caddr_t);
      caddr_t **src_start = vect + (start_itm_ctr * block_elts);
      caddr_t *cut = (caddr_t *)dk_alloc_box (cut_size, DV_ARRAY_OF_POINTER);
      memcpy (cut, src_start, cut_size);
      memset (src_start, 0, cut_size);
      res[partition_ctr++] = cut;
    }
  return (caddr_t)res;
}

void
box_dict_iterator_serialize (xml_entity_t * xe, dk_session_t * ses)
{
  session_buffered_write_char (DV_SHORT_STRING_SERIAL, ses);
  session_buffered_write_char ((char) 24, ses);
/*                              0         1         2     */
/*                              0123456789012345678901234 */
  session_buffered_write (ses, "{{dictionary_reference}}", 24);
}

caddr_t xsltvar_uname_current;
caddr_t xsltvar_uname_sheet;

void
xslt_init (void)
{
  dk_mem_hooks (DV_DICT_HASHTABLE, box_dict_hashtable_copy_hook, box_dict_hashtable_destr_hook, 0);
  dk_mem_hooks (DV_DICT_ITERATOR, box_dict_iterator_copy_hook, box_dict_iterator_destr_hook, 0);
  PrpcSetWriter (DV_DICT_ITERATOR, (ses_write_func) box_dict_iterator_serialize);

  xslt_meta_hash = id_str_hash_create (101);

  xsltvar_uname_current = box_dv_uname_string ("$current");
  xsltvar_uname_sheet = box_dv_uname_string ("$sheet");
  bif_define ("xslt_sheet", bif_xslt_sheet);
  bif_set_uses_index (bif_xslt_sheet);
  bif_define ("xslt", bif_xslt);
  bif_set_uses_index (bif_xslt);
  bif_define ("xslt_stale", bif_xslt_stale);
  bif_define_ex ("xslt_is_sheet", bif_xslt_is_sheet, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define ("xslt_profile_enable", bif_xslt_profile_enable);
  bif_define ("xslt_profile_disable", bif_xslt_profile_disable);
  bif_define ("xslt_profile_list", bif_xslt_profile_list);
#ifdef DEBUG
  bif_define ("xslt_mem_check", bif_xslt_mem_check);
#endif
  xslt_define (" error"			, XSLT_EL__ERROR		, xslt_misplaced		, 0			, 0			,
	xslt_arg_eol);
  xslt_define ("apply-imports"		, XSLT_EL_APPLY_IMPORTS		, xslt_apply_imports		, XSLT_ELGRP_CHARINS	, 0			,
	xslt_arg_eol);
  xslt_define ("apply-templates"	, XSLT_EL_APPLY_TEMPLATES	, xslt_apply_templates		, XSLT_ELGRP_CHARINS	, XSLT_ELGRP_SORT | XSLT_ELGRP_WITH_PARAM ,
	xslt_arg_define (XSLTMA_XPATH	, 0, NULL, "select"		, XSLT_ATTR_APPLYTEMPLATES_SELECT	),
	xslt_arg_define (XSLTMA_QNAME	, 0, NULL, "mode"		, XSLT_ATTR_APPLYTEMPLATES_MODE		),
	xslt_arg_eol);
  xslt_define ("attribute"		, XSLT_EL_ATTRIBUTE		, xslt_attribute		, XSLT_ELGRP_NONCHARINS | XSLT_ELGRP_ATTRIBUTE	, XSLT_ELGRP_CHARTMPL	,
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, " !xmlns"		, XSLT_ATTR_GENERIC_XMLNS	),
	xslt_arg_define (XSLTMA_ANY	, 1, NULL, "name"		, XSLT_ATTR_ATTRIBUTEORELEMENT_NAME	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "namespace"		, XSLT_ATTR_ATTRIBUTEORELEMENT_NAMESPACE),
	xslt_arg_eol);
  xslt_define ("attribute-set"		, XSLT_EL_ATTRIBUTE_SET		, xslt_misplaced		, XSLT_ELGRP_TOPLEVEL	, XSLT_ELGRP_ATTRIBUTE	,
	xslt_arg_define (XSLTMA_QNAME	, 1, NULL, "name"		, XSLT_ATTR_ATTRIBUTESET_NAME		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, " !use-attribute-sets"	, XSLT_ATTR_ATTRIBUTESET_USEASETS	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "use-attribute-sets"	, XSLT_ATTR_UNUSED	),
	xslt_arg_eol);
  xslt_define ("call-template"		, XSLT_EL_CALL_TEMPLATE		, xslt_call_template		, XSLT_ELGRP_CHARINS	, XSLT_ELGRP_WITH_PARAM ,
	xslt_arg_define (XSLTMA_QNAME	, 1, NULL, "name"		, XSLT_ATTR_CALLTEMPLATE_NAME		),
	xslt_arg_eol);
  xslt_define ("choose"			, XSLT_EL_CHOOSE		, xslt_choose			, XSLT_ELGRP_CHARINS	, XSLT_ELGRP_CHOICES	,
	xslt_arg_eol);
  xslt_define ("comment"		, XSLT_EL_COMMENT		, xslt_comment			, XSLT_ELGRP_NONCHARINS	, XSLT_ELGRP_CHARTMPL	,
	xslt_arg_eol);
  xslt_define ("copy"			, XSLT_EL_COPY			, xslt_copy			, XSLT_ELGRP_CHARINS	, XSLT_ELGRP_TMPL	,
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, " !use-attribute-sets"	, XSLT_ATTR_COPY_USEASETS	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "use-attribute-sets"	, XSLT_ATTR_UNUSED			),
	xslt_arg_eol);
  xslt_define ("copy-of"		, XSLT_EL_COPY_OF		, xslt_copy_of			, XSLT_ELGRP_CHARINS	, 0			,
	xslt_arg_define (XSLTMA_XPATH	, 1, NULL, "select"		, XSLT_ATTR_COPYOF_SELECT		),
	xslt_arg_eol);
  xslt_define ("decimal-format"		, XSLT_EL_DECIMAL_FORMAT	, xslt_misplaced		, XSLT_ELGRP_TOPLEVEL	, 0			,
	xslt_arg_define (XSLTMA_QNAME	, 0, NULL, "name"		, XSLT_ATTR_DECIMALFORMAT_NAME		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "decimal-separator"	, XSLT_ATTR_DECIMALFORMAT_DSEP		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "grouping-separator"	, XSLT_ATTR_DECIMALFORMAT_GSEP		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "infinity"		, XSLT_ATTR_DECIMALFORMAT_INF		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "minus-sign"		, XSLT_ATTR_DECIMALFORMAT_MINUS		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "NaN"		, XSLT_ATTR_DECIMALFORMAT_NAN		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "percent"		, XSLT_ATTR_DECIMALFORMAT_PERCENT	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "per-mille"		, XSLT_ATTR_DECIMALFORMAT_PPM		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "zero-digit"		, XSLT_ATTR_DECIMALFORMAT_ZERO		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "digit"		, XSLT_ATTR_DECIMALFORMAT_DIGIT		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "pattern-separator"	, XSLT_ATTR_DECIMALFORMAT_PSEP		),
	xslt_arg_eol);
  xslt_define ("element"		, XSLT_EL_ELEMENT		, xslt_element			, XSLT_ELGRP_NONCHARINS	, XSLT_ELGRP_TMPL	,
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, " !xmlns"		, XSLT_ATTR_GENERIC_XMLNS	),
	xslt_arg_define (XSLTMA_ANY	, 1, NULL, "name"		, XSLT_ATTR_ATTRIBUTEORELEMENT_NAME	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "namespace"		, XSLT_ATTR_ATTRIBUTEORELEMENT_NAMESPACE),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, " !use-attribute-sets"	, XSLT_ATTR_ELEMENT_USEASETS	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "use-attribute-sets"	, XSLT_ATTR_UNUSED			),
	xslt_arg_eol);
  xslt_define ("element-rdfqname"	, XSLT_EL_ELEMENT_RDFQNAME	, xslt_element_rdfqname		, XSLT_ELGRP_NONCHARINS	, XSLT_ELGRP_TMPL	,
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, " !xmlns"		, XSLT_ATTR_GENERIC_XMLNS	),
	xslt_arg_define (XSLTMA_ANY	, 1, NULL, "name"		, XSLT_ATTR_ATTRIBUTEORELEMENT_NAME	),
/*	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "namespace"		, XSLT_ATTR_ATTRIBUTEORELEMENT_NAMESPACE), */
/*	xslt_arg_define (XSLTMA_ANY	, 0, NULL, " !use-attribute-sets"	, XSLT_ATTR_ELEMENT_USEASETS	), */
/*	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "use-attribute-sets"	, XSLT_ATTR_UNUSED			), */
	xslt_arg_eol);
  xslt_define ("fallback"		, XSLT_EL_FALLBACK		, xslt_notyetimplemented	, XSLT_ELGRP_CHARINS	, XSLT_ELGRP_TMPL	,
	xslt_arg_eol);
  xslt_define ("for-each"		, XSLT_EL_FOR_EACH		, xslt_for_each			, XSLT_ELGRP_CHARINS	, XSLT_ELGRP_PCDATA | XSLT_ELGRP_INS | XSLT_ELGRP_RESELS | XSLT_ELGRP_SORT	,
	xslt_arg_define (XSLTMA_XPATH	, 1, NULL, "select"		, XSLT_ATTR_FOREACH_SELECT		),
	xslt_arg_eol);
  xslt_define ("for-each-row"		, XSLT_EL_FOR_EACH_ROW		, xslt_for_each_row		, XSLT_ELGRP_CHARINS	, XSLT_ELGRP_PCDATA | XSLT_ELGRP_INS | XSLT_ELGRP_RESELS	,
	xslt_arg_define (XSLTMA_XPATH	, 0, NULL, "sparql"		, XSLT_ATTR_FOREACHROW_SPARQL		),
	xslt_arg_define (XSLTMA_XPATH	, 0, NULL, "sql"		, XSLT_ATTR_FOREACHROW_SQL		),
	xslt_arg_eol);
  xslt_define ("if"			, XSLT_EL_IF			, xslt_if			, XSLT_ELGRP_CHARINS	, XSLT_ELGRP_TMPL	,
	xslt_arg_define (XSLTMA_XPATH	, 1, NULL, "test"		, XSLT_ATTR_IFORWHEN_TEST		),
	xslt_arg_eol);
  xslt_define ("import"			, XSLT_EL_IMPORT		, xslt_misplaced		, XSLT_ELGRP_TOPLEVEL	, 0			,
	xslt_arg_define (XSLTMA_ANY	, 1, NULL, "href"		, XSLT_ATTR_IMPORTORINCLUDE_HREF	),
	xslt_arg_eol);
  xslt_define ("include"		, XSLT_EL_INCLUDE		, xslt_misplaced		, XSLT_ELGRP_TOPLEVEL	, 0			,
	xslt_arg_define (XSLTMA_ANY	, 1, NULL, "href"		, XSLT_ATTR_IMPORTORINCLUDE_HREF	),
	xslt_arg_eol);
  xslt_define ("key"			, XSLT_EL_KEY			, xslt_key			, XSLT_ELGRP_TOPLEVEL	, 0			,
	xslt_arg_define (XSLTMA_QNAME	, 1, NULL, "name"		, XSLT_ATTR_KEY_NAME			),
	xslt_arg_define (XSLTMA_XPATH	, 1, NULL, "match"		, XSLT_ATTR_KEY_MATCH			),
	xslt_arg_define (XSLTMA_XPATH	, 1, NULL, "use"		, XSLT_ATTR_KEY_USE			),
	xslt_arg_eol);
  xslt_define ("message"		, XSLT_EL_MESSAGE		, xslt_message			, XSLT_ELGRP_CHARINS	, XSLT_ELGRP_TMPL	,
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "terminate"		, XSLT_ATTR_MESSAGE_TERMINATE		),
	xslt_arg_eol);
  xslt_define ("namespace-alias"	, XSLT_EL_NAMESPACE_ALIAS	, xslt_notyetimplemented	, XSLT_ELGRP_TOPLEVEL	, 0			,
	xslt_arg_define (XSLTMA_ANY	, 1, NULL, "stylesheet-prefix"	, XSLT_ATTR_NAMESPACEALIAS_SPREF	),
	xslt_arg_define (XSLTMA_ANY	, 1, NULL, "result-prefix"	, XSLT_ATTR_NAMESPACEALIAS_RPREF	),
	xslt_arg_eol);
  xslt_define ("number"			, XSLT_EL_NUMBER		, xslt_number			, XSLT_ELGRP_CHARINS	, 0			,
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "level"		, XSLT_ATTR_NUMBER_LEVEL		),
	xslt_arg_define (XSLTMA_XPATH	, 0, NULL, "count"		, XSLT_ATTR_NUMBER_COUNT		),
	xslt_arg_define (XSLTMA_XPATH	, 0, NULL, "from"		, XSLT_ATTR_NUMBER_FROM			),
	xslt_arg_define (XSLTMA_XPATH	, 0, NULL, "value"		, XSLT_ATTR_NUMBER_VALUE		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "format"		, XSLT_ATTR_NUMBER_FORMAT		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "lang"		, XSLT_ATTR_NUMBER_LANG			),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "letter-value"	, XSLT_ATTR_NUMBER_LETTERVALUE		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "grouping-separator"	, XSLT_ATTR_NUMBER_GSEPARATOR		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "grouping-size"	, XSLT_ATTR_NUMBER_GSIZE		),
	xslt_arg_eol);
  xslt_define ("otherwise"		, XSLT_EL_OTHERWISE		, xslt_misplaced		, XSLT_ELGRP_CHOICES	, XSLT_ELGRP_TMPL	,
	xslt_arg_eol);
  xslt_define ("output"			, XSLT_EL_OUTPUT		, xslt_misplaced		, XSLT_ELGRP_TOPLEVEL	, 0			,
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "method"			, XSLT_ATTR_OUTPUT_METHOD	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "version"			, XSLT_ATTR_OUTPUT_VERSION	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "encoding"			, XSLT_ATTR_OUTPUT_ENCODING	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "omit-xml-declaration"	, XSLT_ATTR_OUTPUT_OMITXMLDECL	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "standalone"			, XSLT_ATTR_OUTPUT_STANDALONE	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "doctype-public"		, XSLT_ATTR_OUTPUT_DTDPUBLIC	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "doctype-system"		, XSLT_ATTR_OUTPUT_DTDSYSTEM	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, " !cdata-section-elements"	, XSLT_ATTR_OUTPUT_CDATAELS	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "indent"			, XSLT_ATTR_OUTPUT_INDENT	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "media-type"			, XSLT_ATTR_OUTPUT_MEDIATYPE	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "cdata-section-elements"	, XSLT_ATTR_UNUSED		),
	xslt_arg_eol);
  xslt_define ("param"			, XSLT_EL_PARAM			, xslt_parameter		, XSLT_ELGRP_TOPLEVEL | XSLT_ELGRP_PARAM	, XSLT_ELGRP_TMPL	,
	xslt_arg_define (XSLTMA_QNAME	, 1, NULL, "name"		, XSLT_ATTR_VARIABLEORPARAM_NAME	),
	xslt_arg_define (XSLTMA_XPATH	, 0, NULL, "select"		, XSLT_ATTR_VARIABLEORPARAM_SELECT	),
	xslt_arg_eol);
  xslt_define ("preserve-space"		, XSLT_EL_PRESERVE_SPACE	, xslt_notyetimplemented	, XSLT_ELGRP_TOPLEVEL	, 0			,
	xslt_arg_define (XSLTMA_ANY	, 1, NULL, "elements"		, XSLT_ATTR_STRIPORPRESERVESPACE_ELEMENTS	),
	xslt_arg_eol);
  xslt_define ("processing-instruction"	, XSLT_EL_PROCESSING_INSTRUCTION	, xslt_pi		, XSLT_ELGRP_NONCHARINS	, XSLT_ELGRP_CHARTMPL	,
	xslt_arg_define (XSLTMA_ANY	, 1, NULL, "name"		, XSLT_ATTR_PI_NAME			),
	xslt_arg_eol);
  xslt_define ("sort"			, XSLT_EL_SORT			, xslt_sort_elt			, XSLT_ELGRP_SORT	, 0			,
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "data-type"		, XSLT_ATTR_SORT_DATATYPE		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "order"		, XSLT_ATTR_SORT_ORDER			),
	xslt_arg_define (XSLTMA_XPATH	, 0, NULL, "select"		, XSLT_ATTR_SORT_SELECT			),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "lang"		, XSLT_ATTR_SORT_LANG			),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "case-order"		, XSLT_ATTR_SORT_CASEORDER		),
	xslt_arg_eol);
  xslt_define ("strip-space"		, XSLT_EL_STRIP_SPACE		, xslt_notyetimplemented	, XSLT_ELGRP_TOPLEVEL	, 0			,
	xslt_arg_define (XSLTMA_ANY	, 1, NULL, "elements"		, XSLT_ATTR_STRIPORPRESERVESPACE_ELEMENTS	),
	xslt_arg_eol);
  xslt_define ("stylesheet"		, XSLT_EL_STYLESHEET		, xslt_misplaced		, XSLT_ELGRP_ROOTLEVEL	, XSLT_ELGRP_TOPLEVEL	,
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, " !xmlns"		, XSLT_ATTR_GENERIC_XMLNS	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "version"		, XSLT_ATTR_STYLESHEET_VERSION		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "id"			, XSLT_ATTR_STYLESHEET_ID		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "extension-element-prefixes"		, XSLT_ATTR_STYLESHEET_EXT_EL_PREFS	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "exclude-result-prefixes"		, XSLT_ATTR_STYLESHEET_EXC_RES_PREFS	),
	xslt_arg_eol);
  xslt_define ("template"		, XSLT_EL_TEMPLATE		, xslt_misplaced		, XSLT_ELGRP_TOPLEVEL	, XSLT_ELGRP_TMPLBODY	,
	xslt_arg_define (XSLTMA_XPATH	, 0, NULL, "match"		, XSLT_ATTR_TEMPLATE_MATCH		),
	xslt_arg_define (XSLTMA_QNAME	, 0, NULL, "name"		, XSLT_ATTR_TEMPLATE_NAME		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "priority"		, XSLT_ATTR_TEMPLATE_PRIORITY		),
	xslt_arg_define (XSLTMA_QNAME	, 0, NULL, "mode"		, XSLT_ATTR_TEMPLATE_MODE		),
	xslt_arg_eol);
  xslt_define ("transform"		, XSLT_EL_TRANSFORM		, xslt_misplaced		, XSLT_ELGRP_ROOTLEVEL	, XSLT_ELGRP_TOPLEVEL	,
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, " !xmlns"		, XSLT_ATTR_GENERIC_XMLNS	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "version"		, XSLT_ATTR_STYLESHEET_VERSION		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "id"			, XSLT_ATTR_STYLESHEET_ID		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "extension-element-prefixes"		, XSLT_ATTR_STYLESHEET_EXT_EL_PREFS	),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "exclude-result-prefixes"		, XSLT_ATTR_STYLESHEET_EXC_RES_PREFS	),
	xslt_arg_eol);
  xslt_define ("text"			, XSLT_EL_TEXT			, xslt_text			, XSLT_ELGRP_CHARINS	, XSLT_ELGRP_PCDATA	,
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "disable-output-escaping"	, XSLT_ATTR_TEXT_DISOESC	),
	xslt_arg_eol);
  xslt_define ("value-of"		, XSLT_EL_VALUE_OF		, xslt_value_of			, XSLT_ELGRP_CHARINS	, 0			,
	xslt_arg_define (XSLTMA_XPATH	, 1, NULL, "select"		, XSLT_ATTR_VALUEOF_SELECT		),
	xslt_arg_define (XSLTMA_ANY	, 0, NULL, "disable-output-escaping"	, XSLT_ATTR_VALUEOF_DISOESC	),
	xslt_arg_eol);
  xslt_define ("variable"		, XSLT_EL_VARIABLE		, xslt_variable			, XSLT_ELGRP_CHARINS | XSLT_ELGRP_TOPLEVEL	, XSLT_ELGRP_TMPL	,
	xslt_arg_define (XSLTMA_QNAME	, 1, NULL, "name"		, XSLT_ATTR_VARIABLEORPARAM_NAME	),
	xslt_arg_define (XSLTMA_XPATH	, 0, NULL, "select"		, XSLT_ATTR_VARIABLEORPARAM_SELECT	),
	xslt_arg_eol);
  xslt_define ("when"			, XSLT_EL_WHEN			, xslt_misplaced		, XSLT_ELGRP_CHOICES	, XSLT_ELGRP_TMPL	,
	xslt_arg_define (XSLTMA_XPATH	, 1, NULL, "test"		, XSLT_ATTR_IFORWHEN_TEST		),
	xslt_arg_eol);
  xslt_define ("with-param"		, XSLT_EL_WITH_PARAM		, xslt_parameter		, XSLT_ELGRP_WITH_PARAM	, XSLT_ELGRP_TMPL	,
	xslt_arg_define (XSLTMA_QNAME	, 1, NULL, "name"		, XSLT_ATTR_VARIABLEORPARAM_NAME	),
	xslt_arg_define (XSLTMA_XPATH	, 0, NULL, "select"		, XSLT_ATTR_VARIABLEORPARAM_SELECT	),
	xslt_arg_eol);

  ddl_ensure_table ("do anyway", xslt_copy_text);
  xslt_copy_sheet = (xslt_sheet_t *)shuric_get_typed ("http://local.virt/xslt_copy", &shuric_vtable__xslt, NULL);
  if (NULL == xslt_copy_sheet)
    GPF_T;
  shuric_make_import (&shuric_anchor, (shuric_t *)xslt_copy_sheet);
  shuric_release ((shuric_t *)xslt_copy_sheet); /* The lock is no longer need because shuric_make_import() has increased refcounter. */
  {
    wchar_t permille[2];
    permille[0] = 0x2030;
    permille[1] = 0;

    xsnf_default = XSNF_NEW;
    xsnf_default->xsnf_name = NULL;
    xsnf_default->xsnf_decimal_sep = box_wide_as_utf8_char ((ccaddr_t) L".", 1, DV_SHORT_STRING);
    xsnf_default->xsnf_grouping_sep = box_wide_as_utf8_char ((ccaddr_t) L",", 1, DV_SHORT_STRING);
    xsnf_default->xsnf_infinity = box_wide_as_utf8_char ((ccaddr_t) L"Infinity", wcslen (L"Infinity"), DV_SHORT_STRING);
    xsnf_default->xsnf_NaN = box_wide_as_utf8_char ((ccaddr_t) L"NaN", wcslen (L"NaN"), DV_SHORT_STRING);
    xsnf_default->xsnf_percent = box_wide_as_utf8_char ((ccaddr_t) L"%", 1, DV_SHORT_STRING);
    xsnf_default->xsnf_per_mille = box_wide_as_utf8_char ((ccaddr_t) permille, 1, DV_SHORT_STRING);
    xsnf_default->xsnf_zero_digit = box_wide_as_utf8_char ((ccaddr_t) L"0", 1, DV_SHORT_STRING);
    xsnf_default->xsnf_digit = box_wide_as_utf8_char ((ccaddr_t) L"#", 1, DV_SHORT_STRING);
    xsnf_default->xsnf_pattern_sep = box_wide_as_utf8_char ((ccaddr_t) L";", 1, DV_SHORT_STRING);
    xsnf_default->xsnf_minus_sign = box_wide_as_utf8_char ((ccaddr_t) L"-", 1, DV_SHORT_STRING);
  }

  bif_define ("dict_new", bif_dict_new);
  bif_define ("dict_duplicate", bif_dict_duplicate);
  bif_define ("dict_put", bif_dict_put);
  bif_define ("dict_get", bif_dict_get);
  bif_define_ex ("dict_contains_key", bif_dict_contains_key, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define ("dict_remove", bif_dict_remove);
  bif_define ("dict_inc_or_put", bif_dict_inc_or_put);
  bif_define ("dict_dec_or_remove", bif_dict_dec_or_remove);
  bif_define ("dict_bitor_or_put", bif_dict_bitor_or_put);
  bif_define ("dict_size", bif_dict_size);
  bif_define ("dict_list_keys", bif_dict_list_keys);
  bif_define ("dict_destructive_list_rnd_keys", bif_dict_destructive_list_rnd_keys);
  bif_define ("dict_to_vector", bif_dict_to_vector);
  bif_define ("dict_zap", bif_dict_zap);
  bif_define ("dict_iter_rewind", bif_dict_iter_rewind);
  bif_define ("dict_iter_next", bif_dict_iter_next);
  bif_define ("dict_key_hash", bif_dict_key_hash);
  bif_define ("dict_key_eq", bif_dict_key_eq);
  bif_define ("gvector_sort", bif_gvector_sort);
  bif_define ("gvector_digit_sort", bif_gvector_digit_sort);
  bif_define ("rowvector_digit_sort", bif_rowvector_digit_sort);
  bif_define ("rowvector_subj_sort", bif_rowvector_subj_sort);
  bif_set_uses_index (bif_rowvector_subj_sort);
  bif_define ("rowvector_obj_sort", bif_rowvector_obj_sort);
  bif_set_uses_index (bif_rowvector_obj_sort);
  bif_define ("rowvector_graph_sort", bif_rowvector_graph_sort);
  bif_set_uses_index (bif_rowvector_graph_sort);
  bif_define ("rowgvector_subj_sort", bif_rowgvector_subj_sort);
  bif_set_uses_index (bif_rowgvector_subj_sort);
  bif_define ("rowvector_graph_partition", bif_rowvector_graph_partition);
  bif_set_uses_index (bif_rowvector_graph_partition);
}

