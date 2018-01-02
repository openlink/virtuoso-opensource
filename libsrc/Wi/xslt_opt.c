/*
 *  xslt.c
 *
 *  $Id$
 *
 *  XSLT translator
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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
#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser_impl.h"
#ifdef __cplusplus
}
#endif
#include "xslt_impl.h"


int
xte_is_xsl_elt (caddr_t * xte, const char * elt)
{
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (xte)
      && DV_ARRAY_OF_POINTER == DV_TYPE_OF (XTE_HEAD (xte)))
    {
      char * name = XTE_HEAD_NAME (XTE_HEAD (xte));
      if (is_xslns (name))
	{
	  char * col = strrchr (name, ':');
	  if (col && 0 == strcmp (col + 1, elt))
	  return 1;
	}

    }
  return 0;
}


int
xte_is_xsl (caddr_t * xte)
{
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (xte))
    {
      caddr_t * head = XTE_HEAD (xte);
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (head)
	  && is_xslns (XTE_HEAD_NAME (head)))
	return 1;
    }
  return 0;
}


int
xsl_is_xpath_attr (char * attr)
{
  if (0 == strcmp (attr, "match")
      ||  0 == strcmp (attr, "select")
      ||  0 == strcmp (attr, "test")
      ||  0 == strcmp (attr, "from")
      ||  0 == strcmp (attr, "count")
      ||  0 == strcmp (attr, "pattern")
      ||  0 == strcmp (attr, "use")
      ||  0 == strcmp (attr, "sparql")
      ||  0 == strcmp (attr, "sql")
      )
    return 1;
  return 0;
}


int
xsl_is_qname_attr (char * attr)
{
  if (0 == strcmp (attr, "namespace")
      ||  0 == strcmp (attr, "name")
      )
    return 1;
  return 0;
}


int
xsl_is_qnames_attr (char * attr)
{
  if (0 == strcmp (attr, "cdata-section-elements") ||
      0 == strcmp (attr, "use-attribute-sets")
      )
    return 1;
  return 0;
}


int
xsl_need_ns_scope (char * name)
{
  if (0 == strcmp (name, "attribute")
      || 0 == strcmp (name, "element"))
    return 0x1;
  if (0 == strcmp (name, "stylesheet")
      || 0 == strcmp (name, "transform"))
    return 0x2;
  return 0;
}


caddr_t
xslt_attr_value (caddr_t * xsltree, const char * name, int reqd)
{
  size_t name_len = strlen (name);
  int inx;
  caddr_t * head = XTE_HEAD (xsltree);
  int attrs = BOX_ELEMENTS (head);
  if (!IS_POINTER (XTE_HEAD(xsltree)[0]))
    sqlr_new_error_xsltree_xdl ("XS370", "XS049", xsltree, "Internal error in XSLT processor");
  for (inx = 1; inx < attrs; inx += 2)
    {
      if ((strlen (head[inx]) >= name_len)
	  && 0 == strcmp (head[inx] + strlen (head[inx]) - name_len, name))
	return (head[inx + 1]);
    }
  if (reqd)
    sqlr_new_error_xsltree_xdl ("XS370", "XS023", xsltree, "Required XSLT attribute %s missing", name);
  return NULL;
}


static int
xslt_avt_find_expression_end (caddr_t value, int i)
{
  /*int value_len = box_length (value) - 1;*/
  int value_len = (int) strlen (value);
  char quote = 0;
  for (; i < value_len; i++)
    {
      char c = value[i];
      switch (c)
	{
	  case '}':
	      if (!quote)
		return i;
	      break;
	  case '{':
	      if (!quote)
		return -1;
	      break;

	  case '\"':
	  case '\'':
	      if (quote == c)
		quote = 0;
	      else if (!quote)
		quote = c;
	      break;
	}
    }
  return -1;
}


static caddr_t
xslt_avt_parse_attribute_value_template (xp_node_t *xn, caddr_t value)
{
  caddr_t xp_qr_text = NULL;
  int fill = 0, n_exprs = 0, concat_done = 0;
  int value_len = (int) strlen (value), i;
  if (!value_len)
    return value;
  xp_qr_text = dk_alloc_box (value_len * 4 + 20, DV_SHORT_STRING);
  memset (xp_qr_text, 0, value_len * 4 + 20);
  /* 11 because of concat, 4 because of the expansion { to [',',] */

  if (value_len < 1 || !(value[0] == '{' && value[1] != '{'))
    {
      tailprintf (xp_qr_text, box_length (xp_qr_text), &fill, "concat ('");
      concat_done = 1;
    }

  for (i = 0; i < value_len; i++)
    {
      char c = value[i];
      switch (c)
	{
	  case '{':
	      if (i + 1 < value_len && value[i + 1] == '{')
		{
		  i++;
		  xp_qr_text[fill++] = '{';
		}
	      else
		{
		  int n;
		  if (0 > (n = xslt_avt_find_expression_end (value, i + 1)))
		    {
		      dk_free_box (xp_qr_text);
		      xn_error (xn, "Missing } in an XSL-T attribute value template");
		    }
		  n_exprs ++;
		  tailprintf (xp_qr_text, box_length (xp_qr_text), &fill,
		      concat_done ? "'," : "concat (");
		  memcpy (&(xp_qr_text[fill]), value + i + 1, n - i - 1);
		  fill += n - i - 1;
		  concat_done = 1;
		  if (n + 1 < value_len)
		    tailprintf (xp_qr_text, box_length (xp_qr_text), &fill, ",'");
		  else
		    tailprintf (xp_qr_text, box_length (xp_qr_text), &fill, ")");
		  i = n;
		}
	      break;
	  case '}':
	      xp_qr_text[fill++] = '}';
	      if (i + 1 < value_len && value[i + 1] == '}')
		i++;
	      break;

	  default:
	      xp_qr_text[fill++] = c;
	      break;
	}
    }
  if (!fill || xp_qr_text[fill - 1] != ')')
    tailprintf (xp_qr_text, box_length (xp_qr_text), &fill, "')");
  xp_qr_text[fill++] = 0;
  if (n_exprs)
    {
      caddr_t err = NULL;
      xp_query_t * xqr;
      xp_query_env_t xqre;
      memset (&xqre, 0, sizeof (xp_query_env_t));
      xqre.xqre_nsctx_xn = xn;
      xqre.xqre_query_charset = CHARSET_UTF8;
      xqre.xqre_checked_functions = &(xn->xn_xp->xp_checked_functions);
      xqr = xp_query_parse (NULL /* no need in qi for XPath */, xp_qr_text, 'p' /* like xpath_contains */, &err, &xqre);
      if (err)
	{
	  char msg[1000];
	  snprintf (msg, sizeof (msg), "Error in XSL-T attribute value template: %s :%s ", value, ERR_STATE (err));
	  msg[sizeof (msg) - 2] = 0;
	  strncat_ck (msg, ERR_MESSAGE (err), (sizeof (msg) - 1) - strlen (msg));
	  dk_free_box (xp_qr_text);
	  xn_error (xn, msg);
	}
      dk_free_box (xp_qr_text);
      return (caddr_t) xqr;
    }
  else
    {
      dk_free_box (xp_qr_text);
      return value;
    }
}

static caddr_t
xslt_qnames_string_to_array (xp_node_t * xn, char *attr_value)
{
  char *name;
#ifndef WIN32
  char *save;
#endif
  dk_set_t qnames = NULL;
  name = strtok_r (attr_value, "\x20\x9\xD\xA", &save);
  while (name)
    {
      caddr_t qname = xn_ns_name (xn, name, 0);
      if (NULL == qname)
	xn_error (xn, "Name contains undefined namespace prefix in the value of attribute");
      dk_set_push (&qnames, qname);
      name = strtok_r (NULL, "\x20\x9\xD\xA", &save);
    }
  return list_to_array (dk_set_nreverse (qnames));
}


void
xn_xslt_attributes (xp_node_t * xn)
{
  char * colon;
  caddr_t * head = xn->xn_attrs;
  int headlen = (int) BOX_ELEMENTS (head);
  int inx;
  int is_xslt_start = 0;
  xp_debug_location_t *elem_xdl = NULL;
  if (!xn->xn_parent->xn_parent)
    {
      for (inx = 1; inx < headlen; inx += 2)
	{
	  if (is_xslns (head[inx]))
	    {
	      colon = strrchr (head[inx], ':');
	      if (!strcmp (colon + 1, "version"))
		{
		  xn->xn_xp->xp_xslt_start = (caddr_t) xn;
		  break;
		}
	    }
	}
    }
  if (is_xslns (XTE_HEAD_NAME (head)))
    {
      vxml_parser_t *parser = xn->xn_xp->xp_parser;
      int is_xslt = parser->cfg.input_is_xslt;
      if (is_xslt)
	{
#ifdef EXTERNAL_XDLS
	  caddr_t * head2 = dk_alloc_box ((headlen + 4) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
          elem_xdl = (xp_debug_location_t *) dk_alloc_box_zero (sizeof (xp_debug_location_t), DV_ARRAY_OF_LONG);
          elem_xdl->xdl_element = head[0];
	  elem_xdl->xdl_line = VXmlGetOuterLineNumber(parser);
#else
	  caddr_t * head2 = (caddr_t *) dk_alloc_box ((headlen + 2) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
          elem_xdl = (xp_debug_location_t *) dk_alloc_box_zero (sizeof (xp_debug_location_t), DV_ARRAY_OF_POINTER);
          elem_xdl->xdl_element = box_copy (head[0]);
	  elem_xdl->xdl_line = box_num (VXmlGetOuterLineNumber(parser));
#endif
          elem_xdl->xdl_file = box_dv_uname_string (VXmlGetOuterFileName (parser));
	  memcpy (head2, head, headlen * sizeof (caddr_t));
	  head2[headlen++] = uname__bang_location;
	  head2[headlen++] = (caddr_t) elem_xdl;
#ifdef EXTERNAL_XDLS
	  head2[headlen++] = uname__bang_file;
	  head2[headlen++] = elem_xdl->xdl_file;
#endif
	  dk_free_box ((caddr_t) head);
	  xn->xn_attrs = head = head2;
	}
      colon = strrchr (head[0], ':');
      is_xslt_start = (!strcmp (colon + 1, "stylesheet") || !strcmp (colon + 1, "transform"));
      if (is_xslt_start)
	xn->xn_xp->xp_xslt_start = (caddr_t) xn;
      for (inx = 1; inx < headlen; inx += 2)
	{
	  if (xsl_is_xpath_attr (head[inx]))
	    {
	      caddr_t err = NULL;
	      xp_query_t * xqr;
	      xp_query_env_t xqre;
	      memset (&xqre, 0, sizeof (xp_query_env_t));
	      xqre.xqre_nsctx_xn = xn;
	      xqre.xqre_query_charset = CHARSET_UTF8;
	      xqre.xqre_checked_functions = &(xn->xn_xp->xp_checked_functions);
	      xqre.xqre_key_gen = 1; /* For profiling */
	      xqr = xp_query_parse (NULL /* no need in qi for XPath */, head[inx + 1], 'p' /* like xpath_contains */, &err, &xqre);
	      if (err)
		{
		  char msg[2000];
		  int item_len;
		  xp_debug_location_t tmp_xdl;
		  item_len = snprintf (msg, sizeof (msg), "%s %s in %s", ERR_STATE (err), ERR_MESSAGE (err), head[inx + 1]);
		  msg[sizeof (msg) - 1] = 0;
		  if (NULL != elem_xdl)
		    {
		      memcpy (&tmp_xdl, elem_xdl, sizeof (xp_debug_location_t));
		      tmp_xdl.xdl_attribute = head[inx];
		      snprint_xdl (msg+item_len, sizeof(msg)-item_len, &tmp_xdl);
		    }
		  xn_error (xn, msg);
		}
	      else
		{
		  if (NULL != elem_xdl)
		    {
#ifdef EXTERNAL_XDLS
		      memcpy (&(xqr->xqr_xdl), elem_xdl, sizeof (xp_debug_location_t));
		      xqr->xqr_xdl.xdl_attribute = head[inx];
#else
		      xqr->xqr_xdl.xdl_attribute = box_copy (head[inx]);
		      xqr->xqr_xdl.xdl_element = box_copy (elem_xdl->xdl_element);
		      xqr->xqr_xdl.xdl_line = box_copy (elem_xdl->xdl_line);
		      xqr->xqr_xdl.xdl_file = box_copy (elem_xdl->xdl_file);
#endif
		    }
		}
	      dk_free_box (head[inx + 1]);
	      head[inx + 1] = (caddr_t) xqr;
	    }
	  if (0 && xsl_is_qname_attr (head[inx]))
	    {
	      caddr_t qname = xn_ns_name (xn, head[inx + 1], 0);
	      if (qname)
		{
		  dk_free_box (head[inx + 1]);
		  head[inx + 1] = qname;
		}
	      else
		xn_error (xn, "Name contains undefined namespace prefix in the value of attribute");
	    }
	  if (xsl_is_qnames_attr (head[inx]))
	    {
	      char name_buf[30];
	      caddr_t arr = xslt_qnames_string_to_array (xn, head[inx + 1]);
	      caddr_t * head2 = (caddr_t *) dk_alloc_box ((headlen + 2) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	      memcpy (head2, head, headlen * sizeof (caddr_t));
	      snprintf (name_buf, sizeof (name_buf), " !%s", head[inx]);
	      head2[headlen++] = box_dv_uname_string (name_buf);
	      head2[headlen++] = arr;
	      dk_free_box ((caddr_t) head);
	      xn->xn_attrs = head = head2;
	    }
          if (is_xslt_start && !strcmp (head[inx], "exclude-result-prefixes"))
            {
              caddr_t val = head[inx + 1], ret = NULL;
	      if (strchr (val, '{'))
                ret = xslt_avt_parse_attribute_value_template (xn, val);
	      if (ret && ret != val)
                xn->xn_xp->xp_top_excl_res_prefx = ret;
              else
                xn->xn_xp->xp_top_excl_res_prefx = box_copy_tree (head[inx+1]);
            }
	}
      colon = strrchr (head[0], ':');
      if (colon && xsl_need_ns_scope (colon + 1))
	{
	  caddr_t scope = list_to_array (xn_namespace_scope (xn));
	  caddr_t * head2 = (caddr_t *) dk_alloc_box ((headlen + 2) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  memcpy (head2, head, headlen * sizeof (caddr_t));
	  head2[headlen++] = uname__bang_xmlns;
	  head2[headlen++] = scope;
	  dk_free_box ((caddr_t) head);
	  xn->xn_attrs = head = head2;
	}
    }
  if (xn->xn_xp->xp_xslt_start)
    {
      for (inx = 1; inx < headlen; inx += 2)
	{
	  if (is_xslns (head[inx]))
	    {
	      char *colon = strrchr (head[inx], ':');
	      if (colon && !strcmp (colon + 1, "use-attribute-sets"))
	        {
		  caddr_t arr = xslt_qnames_string_to_array (xn, head[inx + 1]);
		  caddr_t * head2 = (caddr_t *) dk_alloc_box ((headlen + 2) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
		  memcpy (head2, head, headlen * sizeof (caddr_t));
		  head2[headlen++] = uname__bang_use_attribute_sets;
		  head2[headlen++] = arr;
		  dk_free_box ((caddr_t) head);
		  xn->xn_attrs = head = head2;
		}
	    }
	  if (DV_STRINGP (head[inx + 1]) && strchr (head[inx + 1], '{'))
	    {
	      caddr_t ret = xslt_avt_parse_attribute_value_template (xn, head[inx + 1]);
	      if (ret && ret != head[inx + 1])
		{
		  dk_free_box (head[inx + 1]);
		  head[inx + 1] = ret;
		}
	    }
	}
    }
}


float
xst_rule_default_priority (xp_query_t * xqr)
{
  if (DV_XPATH_QUERY == DV_TYPE_OF (xqr))
    {
      XT * tree = xqr->xqr_tree;
      if (!ST_P (tree, XP_STEP))
	return 0.5;
      switch (tree->_.step.axis)
	{
	case XP_ATTRIBUTE:
	case XP_ATTRIBUTE_WR:
	case XP_CHILD:
	case XP_CHILD_WR:
	  break;
	default:
	  return 0.5;
	}
      if (tree->_.step.input || tree->_.step.preds)
	return 0.5;
      if (!ARRAYP (tree->_.step.node))
	return -0.5;
      switch (tree->_.step.node->type)
	{
	  case XP_NAME_EXACT: return 0;
	  case XP_NAME_NSURI: return -0.25;
	  case XP_NAME_LOCAL: return (float)((((caddr_t)XP_STAR) == tree->_.name_test.nsuri) ? -0.499 :  -0.498);
	  default: GPF_T; return 0;
	}
    }

    return 0;
}


xslt_template_t *
xte_to_template_1 (caddr_t * xte, xp_query_t *match, caddr_t name)
{
  caddr_t mode;
  caddr_t priority;
  NEW_VARZ (xslt_template_t, xst);
  xst->xst_tree = xte = (caddr_t *)box_copy_tree ((caddr_t)xte);
  mode = xslt_attr_value (xte, "mode", 0);
  priority = xslt_attr_value (xte, "priority", 0);
  if (priority)
    xst->xst_priority = (float) atof (priority);
  else
    xst->xst_priority = xst_rule_default_priority (match);
  if (match)
    {
      XT * tree = match->xqr_tree;
      if (ST_P (tree, XP_STEP))
	{
	  if ((XP_ATTRIBUTE == tree->_.step.axis) || (XP_ATTRIBUTE_WR == tree->_.step.axis))
	    xst->xst_match_attributes = 1;
	  else if (!tree->_.step.input && !tree->_.step.preds
		   && tree->_.step.axis != XP_ROOT && ((XT *) XP_ELT != tree->_.step.node))
	    xst->xst_node_test = tree->_.step.node;
	}
    }
  xst->xst_match = match;
  xst->xst_name = name ? box_dv_uname_string (name) : NULL;
  xst->xst_mode = mode ? box_dv_uname_string (mode) : NULL;
  return xst;
}


void
xte_flat_union (XT * tree, caddr_t * xte, dk_set_t * res)
{
  if (XP_UNION != tree->type)
    {
      xp_query_t * orig_xqr = (xp_query_t *) xslt_attr_value (xte, "match", 0);
      XT * orig_xqr_tree = orig_xqr->xqr_tree;
      xp_query_t * clone_xqr;
      xslt_template_t *union_member;
      orig_xqr->xqr_tree = NULL;
      clone_xqr = (xp_query_t *) xqr_clone ((caddr_t)orig_xqr);
      orig_xqr->xqr_tree = orig_xqr_tree;
      clone_xqr->xqr_tree = (XT*) box_copy_tree ((caddr_t) tree);
      union_member = xte_to_template_1 (xte, clone_xqr, NULL);
      dk_set_push (res, (void*)union_member);
      union_member->xst_union_member_idx = dk_set_length (res[0]);
    }
  else
    {
      xte_flat_union (tree->_.bin_exp.left, xte, res);
      xte_flat_union (tree->_.bin_exp.right, xte, res);
    }
}


dk_set_t
xte_to_template (caddr_t * xte)
{
  dk_set_t res = NULL;
  xp_query_t * match = (xp_query_t *) xslt_attr_value (xte, "match", 0);
  caddr_t name = xslt_attr_value (xte, "name", 0);
  if (match && (match->xqr_tree->type == XP_UNION))
    xte_flat_union (match->xqr_tree, xte, &res);
  if ((match && (match->xqr_tree->type != XP_UNION)) || name ||
      !is_xslns (XTE_HEAD_NAME (XTE_HEAD (xte))))
    {
      if (NULL != match)
        {
#ifdef DEBUG
	  if (DV_XPATH_QUERY != DV_TYPE_OF (match))
	    GPF_T;
#endif
          match = (xp_query_t *)xqr_clone ((caddr_t)match);
        }
      dk_set_push (&res, xte_to_template_1 (xte, match, name));
    }
  return res;
}




caddr_t *
xte_insert_inc (caddr_t * arr1, int place, caddr_t * replace)
{
  int new_len = BOX_ELEMENTS (arr1) + BOX_ELEMENTS (replace) - 2;
  caddr_t * target = (caddr_t *) dk_alloc_box (new_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  int fill = 0, inx, inx2;
  for (inx = 0; inx < (int) BOX_ELEMENTS (arr1); inx ++)
    {
      if (inx == place)
	{
	  for (inx2 = 1; inx2 < (int) BOX_ELEMENTS (replace); inx2++)
	    {
	      target[fill++] = replace[inx2];
	      replace [inx2] = NULL;
	    }
	}
      else
	{
	  target[fill++] = arr1[inx];
	  arr1[inx] = NULL;
	}
    }
  return target;
}


void xslt_includes_recursion (xslt_sheet_t *xsh, caddr_t **sheet_tree_ptr, query_instance_t * qi)
{
  caddr_t *sheet_tree = sheet_tree_ptr[0];
  int inx = BOX_ELEMENTS (sheet_tree);
  while (--inx > 1) /* The order is important. Ascending scan will result in problems with growing width of tree on xsl:include-s */
    {
      caddr_t * elt = (caddr_t *) sheet_tree[inx];
      if (xte_is_xsl_elt (elt, "include"))
	{
	  caddr_t name = xslt_attr_value (elt, "href", 1);
	  xslt_sheet_t * inc;
	  caddr_t * inctree, *new_sheet_tree;
	  inc = xslt_sheet (qi, xsh->xsh_shuric.shuric_uri, name, NULL, &(xsh->xsh_shuric));
	  shuric_release (&(inc->xsh_shuric)); /* But data from \c inc are still valid because \c inc is included in \c xsh */
	  inctree = (caddr_t *) box_copy_tree ((box_t) inc->xsh_raw_tree);
	  xslt_includes_recursion (inc, &inctree, qi);
	  new_sheet_tree = xte_insert_inc (sheet_tree, inx, inctree);
#ifdef DK_ALLOC_BOX_DEBUG
	  {
	    dk_hash_t *known = hash_table_allocate (4096);
	    dk_check_tree_iter (sheet_tree, BADBEEF_BOX, known);
	    dk_check_tree_iter (inctree, BADBEEF_BOX, known);
	    dk_check_tree_iter (new_sheet_tree, BADBEEF_BOX, known);
	    hash_table_free (known);
	  }
#endif
	  dk_free_tree ((box_t) sheet_tree);
	  dk_free_tree ((box_t) inctree);
	  sheet_tree = new_sheet_tree;
	  sheet_tree_ptr[0] = sheet_tree;
	  continue;
	}
      if (xte_is_xsl_elt (elt, "import"))
	{ /* No real processing here, just establishing a proper 'included_by' relation between shurics. */
	  caddr_t name = xslt_attr_value (elt, "href", 1);
	  xslt_sheet_t * inc = xslt_sheet (qi, xsh->xsh_shuric.shuric_uri, name, NULL, &(xsh->xsh_shuric));
	  shuric_release (&(inc->xsh_shuric));
	  continue;
	}
    }
}

int
xslt_includes (xslt_sheet_t *xsh, caddr_t * top, query_instance_t * qi)
{
  int inx, sheet_inx = 0;
  caddr_t * sheet_tree = NULL;

  for (inx = 1; inx < (int) BOX_ELEMENTS (top); inx ++)
    {
      caddr_t *elt = (caddr_t *) top[inx];
      if (xte_is_entity (elt))
	{
	  caddr_t *head = XTE_HEAD (elt);
	  caddr_t name = XTE_HEAD_NAME (head);
	  if (xte_is_xsl_elt (elt, "stylesheet") || xte_is_xsl_elt (elt, "transform"))
	    {
	      if (0 != sheet_inx)
		sqlr_new_error_xsltree_xdl ("XS370", "XS054", elt, "redundant 'XSLT stylesheet' element");
	      sheet_tree = elt;
	      sheet_inx = inx;
	      continue;
	    }
	  if (name[0] != ' ' && !is_xslns (name) && xslt_attr_value (elt, "version", 0))
	    {
	      int inx1;
	      if (0 != sheet_inx)
		sqlr_new_error_xsltree_xdl ("XS370", "XS055", elt, "redundant element with 'XSLT version' attribute");
	      for (inx1 = 1; inx1 < (int) BOX_ELEMENTS (head); inx1 += 2)
		{
		  if (is_xslns (head[inx1]))
		    {
		      caddr_t colon = strrchr (head[inx1], ':');
		      if (colon && !strcmp (colon + 1, "version"))
			{
			  caddr_t err = NULL;
			  caddr_t err_msg = NULL;
			  int ns_len =  (int) (colon - head[inx1] + 1);
			  caddr_t new_name = box_dv_ubuf (box_length (head[inx1]) - 3);
			  memset (new_name, 0, box_length (head[inx1]) - 2);
			  memcpy (new_name, head[inx1], ns_len);
			  memcpy (new_name + ns_len, "match", 5);
			  dk_free_box (head[inx1]);
			  dk_free_tree (head[inx1 + 1]);
			  head[inx1] = box_dv_uname_from_ubuf (new_name);
			  head[inx1 + 1] = (caddr_t) xp_query_parse (qi, "/", 'p' /* like xpath_contains */, &err, &xqre_default);
			  if (NULL != err)
			    {
			      err_msg = box_copy (ERR_MESSAGE(err));
			      dk_free_box (err);
			      sqlr_new_error_xsltree_xdl ("XS370", "XS050", elt, "%s", err_msg);
			    }
			}
		    }
		}
	      sheet_tree = elt;
	      sheet_inx = -inx;
	      continue;
	    }
	  if (name[0] != ' ')
	    sqlr_new_error_xsltree_xdl ("XS370", "XS025", elt, "top element '%s' is not a stylesheet", name);
	  continue;
	}
      if (xslt_non_whitespace ((caddr_t) elt))
	sqlr_new_error_xsltree_xdl ("XS370", "XS026", elt, "non-whitespace text at top level of a stylesheet");
    }
  if (!sheet_tree)
    sqlr_new_error ("XS370", "XS027", "no top element is stylesheet");

  if (sheet_inx < 0)
    return sheet_inx;
  xslt_includes_recursion (xsh, (caddr_t **)(top + sheet_inx), qi);
  return sheet_inx;
}


static xslt_metadata_t *xslt_sheet_compile_el (caddr_t *tree, int containsgroups)
{
  caddr_t *head = (caddr_t *)(tree[0]);
  caddr_t name = head[0];
  char * local_name = strrchr (name, ':');
  caddr_t *newhead;
  ptrlong argctr, location_argctr = 0;
  size_t attrctr, location_attrctr = 0;
  xslt_metadata_t **mdataptr = NULL, *mdata;
  if (local_name)
    {
      local_name++;
      mdataptr = (xslt_metadata_t **) id_hash_get (xslt_meta_hash, (caddr_t) &local_name);
    }
  if (!mdataptr)
    sqlr_new_error_xsltree_xdl ("XS370", "XS020", ((caddr_t *)(tree)), "Bad xsl node '%s'", local_name);
  mdata = mdataptr[0];
  if (!(mdata->xsltm_el_memberofgroups & containsgroups))
    {
      if (XSLT_EL_TEMPLATE == mdata->xsltm_el_id)
        sqlr_new_error_xsltree_xdl ("XS370", "XS061", ((caddr_t *)(tree)), "Unlike earlier drafts, XSLT 1.0 W3C Recommendation (16 Nov 1999) prohibits the use of nested templates");
      sqlr_new_error_xsltree_xdl ("XS370", "XS018", ((caddr_t *)(tree)), "Misplaced xsl node '%s'", local_name);
    }
  newhead = (caddr_t *)dk_alloc_box_zero (sizeof (caddr_t) * (1 + mdata->xsltm_arg_no), DV_ARRAY_OF_POINTER);
  newhead[0] = (caddr_t)(mdata->xsltm_idx);
  argctr = mdata->xsltm_arg_no;
  while (argctr--)
    {
      xsltm_arg_descr_t *descr = mdata->xsltm_args + argctr;
      caddr_t arg = NULL;
      if (NULL == descr->xsltma_subelem)
	{
	  for (attrctr = 1; attrctr < BOX_ELEMENTS(head); attrctr += 2)
	    {
	      if (strcmp (head[attrctr], descr->xsltma_uname))
		continue;
	      if (!strcmp (head[attrctr], " !location"))
	        {
	          location_attrctr = attrctr;
		  location_argctr = argctr;
		}
	      arg = head[attrctr+1];
	      head[attrctr+1] = 0;
	      break;
	    }
	}
      if ((NULL == arg) && descr->xsltma_required)
	{
	  dk_free_tree ((box_t) newhead);
	  sqlr_new_error_xsltree_xdl ("XS370", "XS051", ((caddr_t *)(tree)), "Attribute '%s' not specified", descr->xsltma_uname);
	}
      if ((NULL != arg) && (XSLTMA_QNAME == descr->xsltma_type))
	{
	  caddr_t raw_arg = arg;
	  if (!DV_STRINGP (raw_arg))
	    {
	      dk_free_tree (raw_arg);
	      dk_free_tree ((box_t) newhead);
	      sqlr_new_error_xsltree_xdl ("XS370", "XS052", ((caddr_t *)(tree)), "The value of attribute '%s' is not a qualified name", descr->xsltma_uname);
	    }
	  arg = box_dv_uname_string (raw_arg);
	  dk_free_box (raw_arg);
	}
      newhead[argctr+1] = arg;
    }
  for (attrctr = 1; attrctr < BOX_ELEMENTS(head); attrctr += 2)
    {
      if (NULL != head[attrctr+1])
	{
	  if (location_attrctr != 0)
	    {
	      head[location_attrctr+1] = newhead[location_argctr+1];
	      newhead[location_argctr+1] = NULL;
	    }
	  dk_free_tree ((box_t) newhead);
	  sqlr_new_error_xsltree_xdl ("XS370", "XS053", ((caddr_t *)(tree)), "Unsupported attribute '%s'", head[attrctr]);
	}
    }
  dk_free_tree ((box_t) head);
  tree[0] = (caddr_t)newhead;
  return mdata;
}


static caddr_t *xslt_sheet_compile_subtree (caddr_t *tree, int containsgroups)
{
  if (xte_is_entity (tree))
    {
      int childgroups = containsgroups;
      size_t child_idx, el_count, inscount;
      xslt_metadata_t *mdata = NULL;
      caddr_t name = XTE_HEAD_NAME(XTE_HEAD(tree));
      if (is_xslns (name))
        {
	  mdata = xslt_sheet_compile_el (tree, containsgroups);
	  childgroups = (int) mdata->xsltm_el_containsgroups;
        }
      el_count = BOX_ELEMENTS (tree);
      inscount = 1;
      for (child_idx = 1; child_idx < el_count; child_idx++)
	{
	  caddr_t *child = (caddr_t *)(tree[child_idx]);
	  caddr_t child_name;
	  if (!xte_is_entity (child))
	    {
	      if (xslt_non_whitespace ((caddr_t) child))
	        {
	          if (!(XSLT_ELGRP_PCDATA & childgroups))
		    sqlr_new_error_xsltree_xdl ("XS370", "XS059", ((caddr_t *)(tree)), "PCDATA children are no allowed");
		}
	      else if ((NULL == mdata) || (XSLT_EL_TEXT != mdata->xsltm_el_id))
	        { /* whitespaces are dropped */
		  tree[child_idx] = NULL;
		  dk_free_tree ((box_t) child);
		  continue;
		}
	      /* Optimization by concatenation of texts:
After processing 'text1<!--comment-->text2' two string children text1 and text2 are neighbours */
	      if ((inscount > 1) && !xte_is_entity (tree[inscount-1]))
	        {
	          caddr_t newtext = box_dv_short_concat (tree[inscount-1], (caddr_t)child);
	          dk_free_box (tree[inscount-1]);
	          tree[child_idx] = NULL;
		  tree[inscount-1] = newtext;
		  continue;
	        }
	      tree[child_idx] = NULL;
	      tree[inscount++] = (caddr_t)child;
	      continue;
	    }
          child_name = XTE_HEAD_NAME(XTE_HEAD(child));
	  if (child_name == uname__comment)
	    {
	      tree[child_idx] = NULL;
	      dk_free_tree ((box_t) child);
	      continue;
	    }
	  if (!is_xslns (child_name))
            {
	      if (!(XSLT_ELGRP_RESELS & childgroups))
                {
                  if (
		      !(strncmp (child_name, "http://www.w3.org/1999/xhtml:", 29) &&
		        strncmp (child_name, "http://www.w3.org/1999/02/22-rdf-syntax-ns#:", 44)) &&
                      !(strcmp (name, "http://www.w3.org/1999/XSL/Transform:stylesheet") &&
                        strcmp (name, "http://www.w3.org/1999/XSL/Transform:transform"))
		    )
                    { /* Relax syntax for weird comments inside the stylesheet. */
	              tree[child_idx] = NULL;
		      dk_free_tree ((box_t) child);
		      continue;
                    }
	          sqlr_new_error_xsltree_xdl ("XS370", "XS060", ((caddr_t *)(tree)), "Misplaced element '%s'", child_name);
                }
            }
	  { /* The order of assignments here is very important. Memory leaks in other cases */
	    caddr_t newchild = (caddr_t) xslt_sheet_compile_subtree (child, childgroups);
	    tree[child_idx] = NULL;
	    tree[inscount++] = newchild;
	    continue;
	  }
	}
      if (inscount < el_count)
        {
          size_t newlen = sizeof(caddr_t) * inscount;
          caddr_t *newtree = (caddr_t *) dk_alloc_box (newlen, box_tag(tree));
          memcpy (newtree, tree, newlen);
          dk_free_box ((box_t) tree);
          tree = newtree;
        }
      return tree;
    }
  GPF_T;
  return NULL;
}


void
xst_bsort (xslt_template_t ** bs, int n_bufs)
{
  /* Bubble sort n_bufs first buffers in the array. */
  int n, m;
  for (m = n_bufs - 1; m > 0; m--)
    {
      for (n = 0; n < m; n++)
	{
	  xslt_template_t *tmp;
	  if (bs[n]->xst_priority > bs[n + 1]->xst_priority)
	    {
	      tmp = bs[n + 1];
	      bs[n + 1] = bs[n];
	      bs[n] = tmp;
	    }
	}
    }
  for (m = 0; m < n_bufs / 2; m ++)
    {
      if (m != n_bufs - m - 1)
	{
	  xslt_template_t *tmp;
	  tmp = bs[m];
	  bs[m] = bs[n_bufs - m - 1];
	  bs[n_bufs - m - 1] = tmp;
	}
    }
}


#define XOUT_SET_OPTION_VALUE(elt, stru, Elem, Name) \
	val = xslt_attr_value (elt, Name, 0); \
	if (val) \
	  { \
	    dk_free_tree (stru->xout_##Elem); \
	    stru->xout_##Elem = box_dv_short_string (val); \
	  }


#define XOUT_SET_BOOL_VALUE(elt, stru, Elem, Name) \
	val = xslt_attr_value (elt, Name, 0); \
	if (val) \
	  { \
	    if (!strcmp (val, "yes")) \
	      stru->xout_##Elem = 1; \
	    else if (!strcmp (val, "no")) \
	      stru->xout_##Elem = 0; \
	    else \
	      sqlr_new_error_xsltree_xdl ("XS370", "XS029", elt, "\"yes\" or \"no\" required as value of attribute %s", Name); \
	  }

#define XOUT_SET_UPCASE_OPTION_VALUE(elt, stru, Elem, Name) \
	val = xslt_attr_value (elt, Name, 0); \
	if (val) \
	  { \
	    dk_free_tree (stru->xout_##Elem); \
	    stru->xout_##Elem = box_dv_short_string (val); \
	    sqlp_upcase (stru->xout_##Elem); \
	  }

#define NUMBER_FORMAT_SET_CHAR(name, attr_name) \
	memset (&state, 0, sizeof (state)); \
	intermediate = xslt_attr_value (elt, attr_name, 0); \
	if (!intermediate) \
	  intermediate = xsnf_default->xsnf_##name; \
	wchar = 0; \
	len = (int) virt_mbrtowc_z (&wchar, (utf8char *)intermediate, strlen (intermediate), &state); \
	if (len > 0) \
	  { \
	    xn->xsnf_##name = dk_alloc_box (len + 1, DV_SHORT_STRING); \
	    memcpy (xn->xsnf_##name, intermediate, len); \
	    xn->xsnf_##name[len] = 0; \
	  } \
	else \
	  xn->xsnf_##name = box_copy (xsnf_default->xsnf_##name);

#define NUMBER_FORMAT_SET_STRING(name, attr_name) \
	xn->xsnf_##name = box_copy (xslt_attr_value (elt, attr_name, 0)); \
	if (!xn->xsnf_##name) \
	  xn->xsnf_##name = box_copy (xsnf_default->xsnf_##name);

void
xslt_sheet_prepare (xslt_sheet_t *xsh, caddr_t * xstree, query_instance_t * qi,
		    caddr_t * err_ret, xml_ns_2dict_t *ns_2dict)
{
  char * indent;
  caddr_t *root_elt_head;
  int inx, inx2, sheet_inx, is_simple = 0;
  dk_set_t imports = NULL;
  xsh->xsh_all_templates_byname = hash_table_allocate (61);
  xsh->xsh_named_modes = hash_table_allocate (31);
  if (NULL == ns_2dict)
    xsh->xsh_ns_2dict.xn2_size = 0;
  else
    xml_ns_2dict_extend (&(xsh->xsh_ns_2dict), ns_2dict);
  if (!xte_is_entity (xstree) || BOX_ELEMENTS (xstree) < 2)
    {
      *err_ret = srv_make_new_error ("22023", "XS030", "Bad style sheet in xslt_sheet");
      return;
    }
  root_elt_head = ((caddr_t **)(xstree))[0];
  for (inx = BOX_ELEMENTS (root_elt_head) - 2; inx > 0; inx -= 2)
    {
      if (strcmp (root_elt_head[inx], uname__bang_exclude_result_prefixes))
        continue;
      xsh->xsh_top_excl_res_prefx = box_copy_tree (root_elt_head[inx+1]);
      break;
    }
QR_RESET_CTX
  {
  sheet_inx = xslt_includes (xsh, xstree, qi);

  if (sheet_inx < 0)
    {
      is_simple = 1;
      sheet_inx = -sheet_inx;
    }
  xsh->xsh_raw_tree = (caddr_t*) box_copy_tree (xstree[sheet_inx]);
  if (is_simple)
    {
      xsh->xsh_new_templates = dk_set_conc (xsh->xsh_new_templates, xte_to_template (xsh->xsh_raw_tree));
    }
  else
    {
      indent = xslt_attr_value (xsh->xsh_raw_tree, "indent-result", 0);
      if (indent && 0 == stricmp (indent, "yes"))
	xsh->xout_indent = 1;
      for (inx = 1; inx < (int) BOX_ELEMENTS (xsh->xsh_raw_tree); inx++)
	{
	  caddr_t * elt = (caddr_t *) xsh->xsh_raw_tree[inx];
	  if (xte_is_xsl_elt (elt, "template"))
	    xsh->xsh_new_templates = dk_set_conc (xsh->xsh_new_templates, xte_to_template (elt));
	  else if (xte_is_xsl_elt (elt, "import"))
	    {
	      xslt_sheet_t * imp;
	      caddr_t hval = xslt_attr_value (elt, "href", 1);
/* The last (loaded_by) arg of the next call is not &(xsh->xsh_shuric)
because the 'included_by' dependency has been set already in
xslt_includes_recursion(). At the current moment the including hierarchy is flatten by
expanding 'xsl:include' into inlined subtrees. */
	      imp = xslt_sheet (qi, xsh->xsh_shuric.shuric_uri, hval, NULL, NULL /* not &(xsh->xsh_shuric) */);
	      shuric_release (&(imp->xsh_shuric)); /* Imp is not destroyed because is logged as imported into xsh */
	      dk_set_push (&imports, (void*) imp);
	      xml_ns_2dict_extend (&(xsh->xsh_ns_2dict), &(imp->xsh_ns_2dict));
	    }
	  else if (xte_is_xsl_elt (elt, "output"))
	    {
	      caddr_t val;
	      XOUT_SET_OPTION_VALUE (elt, xsh, method, "method");
	      XOUT_SET_OPTION_VALUE (elt, xsh, version, "version");
	      XOUT_SET_UPCASE_OPTION_VALUE (elt, xsh, encoding, "encoding");
	      if (xslt_attr_value (elt, "encoding", 0))
		xsh->xout_encoding_meta = 1;
	      XOUT_SET_BOOL_VALUE (elt, xsh, omit_xml_declaration, "omit-xml-declaration");
	      XOUT_SET_BOOL_VALUE (elt, xsh, standalone, "standalone");
	      XOUT_SET_OPTION_VALUE (elt, xsh, doctype_public, "doctype-public");
	      XOUT_SET_OPTION_VALUE (elt, xsh, doctype_system, "doctype-system");
	      XOUT_SET_BOOL_VALUE (elt, xsh, indent, "indent");
	      XOUT_SET_OPTION_VALUE (elt, xsh, media_type, "media-type");
	      if (xsh->xout_standalone && !(xsh->xout_doctype_system || xsh->xout_doctype_public))
		sqlr_new_error_xsltree_xdl ("XS379", "XS032", elt, "Standalone required but no SYSTEM or PUBLIC doctype");
	      val = xslt_attr_value (elt, " !cdata-section-elements", 0);

	      if (val)
		{
		  int inx;
		  if (!xsh->xout_cdata_section_elements)
		    xsh->xout_cdata_section_elements = id_str_hash_create (10);
		  DO_BOX (caddr_t, qname, inx, (caddr_t *)val)
		    {
		      caddr_t box_name = box_dv_short_string (qname);
		      caddr_t box_val = box_num (1);
		      id_hash_set (xsh->xout_cdata_section_elements, (caddr_t) &box_name, (caddr_t) &box_val);
		    }
		  END_DO_BOX;
		}
	    }
	  else if (xte_is_xsl_elt (elt, "decimal-format"))
	    {
	      virt_mbstate_t state;
	      wchar_t wchar;
	      caddr_t intermediate;
	      int len;

	      xslt_number_format_t *xn = XSNF_NEW;

	      xn->xsnf_name = box_copy (xslt_attr_value (elt, "name", 0));
	      NUMBER_FORMAT_SET_CHAR (decimal_sep, "decimal-separator");
	      NUMBER_FORMAT_SET_CHAR (grouping_sep, "grouping-separator");
	      NUMBER_FORMAT_SET_STRING (infinity, "infinity");
	      NUMBER_FORMAT_SET_CHAR (minus_sign, "minus-sign");
	      NUMBER_FORMAT_SET_STRING (NaN, "NaN");
	      NUMBER_FORMAT_SET_CHAR (percent, "percent");
	      NUMBER_FORMAT_SET_CHAR (per_mille, "per-mille");
	      NUMBER_FORMAT_SET_CHAR (zero_digit, "zero-digit");
	      NUMBER_FORMAT_SET_CHAR (digit, "digit");
	      NUMBER_FORMAT_SET_CHAR (pattern_sep, "pattern-separator");

	      DO_SET (xslt_number_format_t *, xn_set, &xsh->xsh_formats)
		{
		  if (box_equal (xn_set->xsnf_name, xn->xsnf_name))
		    {
		      dk_free_tree ((box_t) xn);
		      if (!box_equal ((box_t) xn_set, (box_t) xn))
			sqlr_new_error_xsltree_xdl ("XS379", "XS035", elt,
			    "XSLT Number format %s redefined with different attributes",
			    xn->xsnf_name ? xn->xsnf_name : "<default>");
		    }
		}
	      END_DO_SET();
	      dk_set_push (&xsh->xsh_formats, xn);
	    }
	}
    }

  xsh->xsh_all_templates = (xslt_template_t **)list_to_array (xsh->xsh_new_templates);
  xsh->xsh_new_templates = NULL;

  DO_BOX (xslt_template_t *, xst, inx, xsh->xsh_all_templates)
    {
      xst->xst_tree = xslt_sheet_compile_subtree (xst->xst_tree, (is_simple ? XSLT_ELGRP_TMPLBODY : XSLT_ELGRP_TOPLEVEL));
      xst->xst_sheet = xsh;
      if (is_simple)
	xst->xst_simple = 1;
    }
  END_DO_BOX;
  xsh->xsh_compiled_tree = (caddr_t *) box_copy_tree ((box_t) xsh->xsh_raw_tree);
  xsh->xsh_compiled_tree = xslt_sheet_compile_subtree (xsh->xsh_compiled_tree, (is_simple ? XSLT_ELGRP_TMPLBODY : XSLT_ELGRP_ROOTLEVEL));
  /* no qsort here, must be stable, i.e. preserve order of equal elements */
  xst_bsort (xsh->xsh_all_templates, BOX_ELEMENTS (xsh->xsh_all_templates));

  DO_BOX (xslt_template_t *, xst, inx, xsh->xsh_all_templates)
    {
      xslt_sheet_mode_t *xstm;
      xslt_template_t ***list_ptr;
      xslt_template_t **new_list;
      if (!xst->xst_match)
	continue;
      if (NULL == xst->xst_mode)
        xstm = &(xsh->xsh_default_mode);
      else
        {
          xstm = (xslt_sheet_mode_t *) gethash (xst->xst_mode, xsh->xsh_named_modes);
	  if (NULL == xstm)
	    {
	      xstm = (xslt_sheet_mode_t *) list (3, box_copy (xst->xst_mode), NULL, NULL);
	      sethash (xst->xst_mode, xsh->xsh_named_modes, xstm);
	    }
	}
      list_ptr = (xst->xst_match_attributes ?
	&(xstm->xstm_attr_templates) :
	&(xstm->xstm_nonattr_templates) );
      if (NULL == list_ptr[0])
	{
	  new_list = (xslt_template_t **) dk_alloc_box (sizeof (ptrlong), DV_ARRAY_OF_LONG);
	}
      else
	{
	  size_t old_bytes = box_length (list_ptr[0]);
	  new_list = (xslt_template_t **) dk_alloc_box (old_bytes + sizeof (ptrlong), DV_ARRAY_OF_LONG);
	  memcpy (new_list, list_ptr[0], old_bytes);
	}
      new_list [BOX_ELEMENTS(new_list)-1] = xst;
      dk_free_box ((caddr_t)(list_ptr[0]));
      list_ptr[0] = new_list;
    }
  END_DO_BOX;

  imports = dk_set_nreverse (imports); /* ... to order imports correctly */
  do
    {
      dk_set_t imps = NULL;
      while (NULL != imports)
	{
	  int inx2;
	  xslt_sheet_t * i2 = (xslt_sheet_t *)dk_set_pop(&imports);
	  if (dk_set_member (imps, (void*) i2))
	    {
	      continue;
	    }
	  DO_BOX (xslt_sheet_t *, imp, inx2, i2->xsh_imported_sheets)
	    {
	      if (!dk_set_member (imps, (void*) imp))
		{
		  dk_set_push (&imps, (void*) imp);
		}
	    }
	  END_DO_BOX;
	}
      imps = dk_set_nreverse (imps); /* ... to order normalized imports correctly */
      imps = dk_set_cons ((caddr_t) xsh, imps);
      xsh->xsh_imported_sheets = (xslt_sheet_t **) list_to_array (imps);
    } while (0);
/* Post-processing */
/* Storing template names in the dictionary */
  DO_BOX (xslt_sheet_t *, xsh1, inx, xsh->xsh_imported_sheets)
    {
      DO_BOX (xslt_template_t *, xst2, inx2, xsh1->xsh_all_templates)
	{
	  caddr_t name = xst2->xst_name;
	  if (!name)
	    continue;
#ifdef DEBUG
	  if (DV_UNAME != DV_TYPE_OF (name))
	    GPF_T;
#endif
	  if (gethash (name, xsh->xsh_all_templates_byname))
	    continue;
	  sethash (name, xsh->xsh_all_templates_byname, xst2);
	}
      END_DO_BOX;
    }
  END_DO_BOX;

  }
QR_RESET_CODE
  {
    du_thread_t * self = THREAD_CURRENT_THREAD;
    caddr_t err = thr_get_error_code (self);
    POP_QR_RESET;
    dk_set_free (imports);
    err_ret[0] = err;
    thr_set_error_code (self, NULL);
  }
END_QR_RESET;
}


shuric_t *shuric_load_xml_by_qi (query_instance_t * qi, caddr_t base, caddr_t ref,
	    caddr_t * err_ret, shuric_t *loaded_by, shuric_vtable_t *vt, const char *caller)
{
  shuric_t *shu;
  caddr_t path_utf8 = NULL, str = NULL, ts = NULL, err = NULL;

  path_utf8 = xml_uri_resolve (qi, &err, base, ref, "UTF-8");
  if (err)
    sqlr_resignal (err);

  if (!strnicmp ("file:", path_utf8, 5) && www_root)
    {
      caddr_t complete_name = dk_alloc_box (strlen (path_utf8 + 5) + strlen (www_root) + 2, DV_SHORT_STRING);
      char *p1 = path_utf8 + 5;

      while (*p1 == '/')
	p1++;
      strcpy_box_ck (complete_name, www_root);
#ifdef WIN32
      strcat_box_ck (complete_name, "\\");
#else
      strcat_box_ck (complete_name, "/");
#endif
      strcat_box_ck (complete_name, p1);
      ts = file_stat (complete_name, 0);
      dk_free_box (complete_name);
    }
  shu = shuric_get_typed (path_utf8, vt, &err);
  if (NULL != err)
    {
      dk_free_box (path_utf8);
      sqlr_resignal (err);
    }
  if (NULL != shu)
    {
      if (ts && (!shu->shuric_loading_time || strcmp (ts, shu->shuric_loading_time)))
	{
          shuric_stale_tree (shu);
	  shuric_release (shu);
	  shu = NULL;
	}
      else
	{
          dk_free_box (path_utf8);
	  dk_free_box (ts);
	  if (loaded_by != NULL)
	    shuric_make_include (loaded_by, shu);
	  return shu;
	}
    }
  str = xml_uri_get (qi, &err, NULL, base, ref, XML_URI_STRING_OR_ENT);
  if (NULL != err)
    {
      dk_free_box (path_utf8);
      sqlr_resignal (err);
    }
  if (DV_XML_ENTITY == DV_TYPE_OF (str))
    {
      dk_free_box (path_utf8);
      sqlr_new_error ("22023", "SR404", "Only a text in XML syntax can be used as a source by %s, not an XML entity.", caller);
    }
  shu = shuric_load (vt, path_utf8, ts, str, loaded_by, qi, NULL, &err);
  dk_free_box (ts);
  if (NULL != err)
    {
#ifdef DEBUG
      if (NULL != shu)
	GPF_T;
#endif
      sqlr_resignal (err);
    }
#ifdef DEBUG
  if (NULL == shu)
    GPF_T;
#endif
  return shu;
}


xslt_sheet_t *
xslt_sheet (query_instance_t * qi, caddr_t base, caddr_t ref,
	    caddr_t * err_ret, shuric_t *loaded_by)
{
  shuric_t *shu = shuric_load_xml_by_qi (qi, base, ref, err_ret, loaded_by, &shuric_vtable__xslt, "XSLT compiler");
  return (xslt_sheet_t *)(shu->shuric_data);
}


/* Metadata */

id_hash_t * xslt_meta_hash;
int xslt_meta_list_length;
xslt_metadata_t xslt_meta_list[XSLTM_MAXID];

xslt_metadata_t *
xslt_define (const char * name, int xslt_el_id, xslt_el_fun_t f, int xslt_el_memberofgroups, int xslt_el_containsgroups, xsltm_arg_descr_t *arg1, ...)
{
  va_list list;
  xsltm_arg_descr_t *args[20];
  xslt_metadata_t *curr = xslt_meta_list + (xslt_meta_list_length++);
  xsltm_arg_descr_t *args_tail;
  int argctr, argc;
  curr->xsltm_uname = box_dv_uname_string (name);
  box_dv_uname_make_immortal (curr->xsltm_uname);
  if (id_hash_get (xslt_meta_hash, (caddr_t) &(curr->xsltm_uname)))
    GPF_T; /* redefinition? */
  curr->xsltm_executable = f;
  curr->xsltm_el_id = xslt_el_id;
  curr->xsltm_el_memberofgroups = xslt_el_memberofgroups;
  curr->xsltm_el_containsgroups = xslt_el_containsgroups;
  curr->xsltm_idx = xslt_meta_list_length - 1;
#ifndef NDEBUG
  if (curr->xsltm_idx != (curr->xsltm_el_id & XSLT_EL__MASK))
    GPF_T;
#endif
  id_hash_set (xslt_meta_hash, (caddr_t) &(curr->xsltm_uname), (caddr_t) (&curr));
  argc = 0;
  args_tail = arg1;
  va_start (list, arg1);
  for (;;)
    {
      args[argc] = args_tail;
      if (NULL == args_tail->xsltma_uname)
	break;
      box_dv_uname_make_immortal (args_tail->xsltma_uname);
      argc++;
      args_tail = va_arg (list, xsltm_arg_descr_t *);
    }
  va_end (list);
  curr->xsltm_arg_no = argc + XSLT_ATTR_FIRST_SPECIAL - 1;
  curr->xsltm_args = (xsltm_arg_descr_t *) dk_alloc_box_zero ((2+argc) * sizeof (xsltm_arg_descr_t), DV_CUSTOM);
  curr->xsltm_args[XSLT_ATTR_ANY_LOCATION-1].xsltma_uname = uname__bang_location;
  curr->xsltm_args[XSLT_ATTR_ANY_LOCATION-1].xsltma_idx = XSLT_ATTR_ANY_LOCATION;
  curr->xsltm_args[XSLT_ATTR_ANY_LOCATION-1].xsltma_type = XSLTMA_LOCATION;
  curr->xsltm_args[XSLT_ATTR_ANY_NS-1].xsltma_uname = uname__bang_ns;
  curr->xsltm_args[XSLT_ATTR_ANY_NS-1].xsltma_idx = XSLT_ATTR_ANY_NS;
  curr->xsltm_args[XSLT_ATTR_ANY_NS-1].xsltma_type = XSLTMA_ANY;
  for (argctr = 0; argctr < argc; argctr++)
    {
      xsltm_arg_descr_t *src = args[argctr];
      xsltm_arg_descr_t *tgt = curr->xsltm_args + argctr + XSLT_ATTR_FIRST_SPECIAL - 1;
      memcpy (tgt, src, sizeof (xsltm_arg_descr_t));
      tgt->xsltma_uname = tgt->xsltma_uname;
      if ((tgt->xsltma_idx != (argctr + XSLT_ATTR_FIRST_SPECIAL)) && (tgt->xsltma_idx != XSLT_ATTR_UNUSED))
	GPF_T;
    }
  return curr;
}

