/*
 *  xpath.c
 *
 *  $Id$
 *
 *  XPATH to SQL
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

#include "xpathp_impl.h"
#include "libutil.h"
#include "sqlnode.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "xml.h"
#include "xmlgen.h"
#include "xmltree.h"
#include "text.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "langfunc.h"
#ifdef __cplusplus
}
#endif
#include "multibyte.h"
#include "bif_text.h"
#include "xpf.h"
#include "xpathp.h"
#include "sqlcstate.h"
#include "remote.h"
#include "xmlparser_impl.h"
#include "schema.h"
#include "sqlrcomp.h"

#define GM_VALUE	1
#define GM_COND		2
#define GM_KEY		3
#define GM_FILTER	4
#define GM_TOP		5


#define ET_EXP		1
#define ET_PRED		2
#define ET_SELECT	3

xp_query_env_t xqre_default;

#ifdef MALLOC_DEBUG
const char *xtlist_impl_file="???";
int xtlist_impl_line;
#endif

XT*
xtlist_impl (xpp_t *xpp, ptrlong length, ptrlong type, ...)
{
  XT *tree;
  va_list ap;
  int inx;
  va_start (ap, type);
#ifdef DEBUG
  if (IS_POINTER(type))
    GPF_T;
#endif
  length += 1;
#ifdef MALLOC_DEBUG
  tree = (XT *) dbg_dk_alloc_box (xtlist_impl_file, xtlist_impl_line, sizeof (caddr_t) * length, DV_ARRAY_OF_POINTER);
#else
  tree = (XT *) dk_alloc_box (sizeof (caddr_t) * length, DV_ARRAY_OF_POINTER);
#endif
  for (inx = 2; inx < length; inx++)
    {
      caddr_t child = va_arg (ap, caddr_t);
#ifdef MALLOC_DEBUG
      if (IS_BOX_POINTER (child))
	dk_alloc_box_assert (child);
#endif
      ((caddr_t *)(tree))[inx] = child;
    }
  va_end (ap);
  tree->type = type;
  tree->srcline = box_num((NULL != xpp) ? ((NULL != xpp->xpp_curr_lexem) ? xpp->xpp_curr_lexem->xpl_lineno : 0) : 0);
  xt_check (xpp, tree);
  return tree;
}


XT*
xtlist_with_tail_impl (xpp_t *xpp, ptrlong length, caddr_t tail, ptrlong type, ...)
{
  XT *tree;
  va_list ap;
  int inx;
  ptrlong tail_len = BOX_ELEMENTS(tail);
  va_start (ap, type);
#ifdef DEBUG
  if (IS_POINTER(type))
    GPF_T;
#endif
#ifdef MALLOC_DEBUG
  tree = (XT *) dbg_dk_alloc_box (xtlist_impl_file, xtlist_impl_line, sizeof (caddr_t) * (1+length+tail_len), DV_ARRAY_OF_POINTER);
#else
  tree = (XT *) dk_alloc_box (sizeof (caddr_t) * (1+length+tail_len), DV_ARRAY_OF_POINTER);
#endif
  for (inx = 2; inx < length; inx++)
    {
      caddr_t child = va_arg (ap, caddr_t);
#ifdef MALLOC_DEBUG
      if (IS_BOX_POINTER (child))
	dk_alloc_box_assert (child);
#endif
      ((caddr_t *)(tree))[inx] = child;
    }
  va_end (ap);
  tree->type = type;
  tree->srcline = box_num((NULL != xpp) ? ((NULL != xpp->xpp_curr_lexem) ? xpp->xpp_curr_lexem->xpl_lineno : 0) : 0);
  ((ptrlong *)(tree))[length] = tail_len;
  memcpy (((caddr_t *)(tree))+length+1, tail, sizeof(caddr_t) * tail_len);
  dk_free_box (tail);
  xt_check (xpp, tree);
  return tree;
}


#ifdef MALLOC_DEBUG
xtlist_track_t *
xtlist_track (const char *file, int line)
{
  static xtlist_track_t ret = { xtlist_impl, xtlist_with_tail_impl };
  xtlist_impl_file = file;
  xtlist_impl_line = line;
  return &ret;
}
#endif


int
st_type (ST * tree)
{
  if (DV_TYPE_OF (tree) != DV_ARRAY_OF_POINTER)
    return ET_EXP;
  switch (tree->type)
    {
    case SELECT_STMT: return ET_SELECT;
    case BOP_LT: case BOP_LTE:  case BOP_GT: case BOP_GTE: case BOP_EQ: case BOP_NEQ:
      case BOP_LIKE: case EXISTS_PRED: case SOME_PRED:
    case BOP_AND: case BOP_OR: case BOP_NOT:
	return ET_PRED;
    default:
      return ET_EXP;
    }
}


xqst_t
xe_new_xqst (xpp_t *xpp, int is_ref)
{
  if (!xp_env()->xe_for_interp)
    return 0;
  if (XQST_REF == is_ref)
    dk_set_push (&xp_env ()->xe_xqr->xqr_state_map, (void*) (ptrlong) xp_env ()->xe_xqst_ctr);
  return (xp_env ()->xe_xqst_ctr++);
}


int
xp_step_needs_pos_or_size (xpp_t *xpp, XT * step)
{
  int pred_idx;
  DO_BOX_FAST (XT *, pred, pred_idx, step->_.step.preds)
    {
      int predicted = xt_predict_returned_type (pred->_.pred.expr);
      if ((XPDV_BOOL != predicted) && (XPDV_NODESET != predicted))
        return 1;
      if (pred->_.pred.size || pred->_.pred.pos)
        return 1;
    }
  END_DO_BOX_FAST;
  return 0;
}


XT *
xp_step (xpp_t *xpp, XT * in, XT * step, ptrlong axis)
{
  while (XP_BY_MAIN_STEP == axis)
    {
      switch (step->type)
	{
	case XP_STEP:
	  axis = (int) step->_.step.axis;
	  continue;
	}
/*
      if (NULL == in)
	return step;
*/
      xp_error (xpp, "Unsupported combination of steps in the path");
      break;
    }
  if (!xp_env ()->xe_for_interp && XP_SELF == step->_.step.axis)
    {
      dk_free_tree ((caddr_t) step);
      return in;
    }
  if (XP_STEP != step->type)
    xp_error (xpp, "Attempt to use non-axis expression in the middle of path");
  if (XP_SLASH_SLASH == axis)
    {
      if (xp_step_needs_pos_or_size (xpp, step) || (XP_CHILD != step->_.step.axis))
	{
	  XT *middle_step = xp_make_step (xpp, XP_DESCENDANT_OR_SELF, (XT *) XP_ELT_OR_ROOT, NULL);
	  in = xp_step (xpp, in, middle_step, XP_DESCENDANT_OR_SELF);
	  axis = (int) step->_.step.axis;
	}
      else
        axis = XP_DESCENDANT;
    }
  step->_.step.input = in;
  step->_.step.axis = axis;
  if (!xp_env ()->xe_for_interp
      && step->_.step.preds)
    {
      int inx;
      XT **preds = step->_.step.preds;
      XT * res = step;
      step->_.step.preds = NULL;
      DO_BOX (XT *, pred, inx, preds)
	{
	  res = xtlist (xpp, 3, XP_FILTER, res, pred->_.pred.expr);
	  dk_free_box ((caddr_t) pred);
	}
      END_DO_BOX;
      dk_free_box ((caddr_t) preds);
      step = res;
    }
  return step;
}


XT *
xp_first_step (XT * tree)
{
  if (!tree)
    return tree;
  for (;;)
    {
#if 0
      if (XP_STEP != tree->type)
	xp_error (xpp, "Internal error in XQuery compiler [XPC-132-010629]");
#endif
      if (!tree->_.step.input)
	return tree;
      tree = tree->_.step.input;
    }

  /*NOTREACHED*/
  return tree;
}


int
xp_is_join_step  (int axis)
{
  switch (axis)
    {
    case XP_ATTRIBUTE:
    case XP_ATTRIBUTE_WR:
    case XP_SELF:
      return 0;
    default: return 1;
    }
}


caddr_t
xp_recode_literal (xpp_t *xpp, caddr_t literal)
{
  int len = (int) strlen(literal);
  const char *srctail = literal;
  unichar *uni = NULL;
  size_t uni_alloc_len;
  int uni_len, utfeight_buf_len;
  char *utfeight_buf, *utfeight_buf_tail, *utfeight;
  int eh_state = 0;
  if (!len)
    {
      utfeight = dk_alloc_box (1, DV_SHORT_STRING);
      utfeight[0] = '\0';
      return utfeight;
    }
  uni_alloc_len = len*sizeof (unichar);
  uni = (unichar *)dk_alloc (uni_alloc_len);
  uni_len = xpp->xpp_enc->eh_decode_buffer (uni, len, &srctail, literal+len, xpp->xpp_enc, &eh_state);
  if (uni_len < 0)
    {
      dk_free (uni,uni_alloc_len);
      if (uni_len == UNICHAR_NO_DATA)
	{
	  xp_error (xpp, "Encoding error in literal (unexpected truncation of the first character)");
	}
      xp_error (xpp, "Encoding error in literal");
    }
  else
    {
      if (srctail != literal+len)
	{
	  dk_free (uni,uni_alloc_len);
	  xp_error (xpp, "Encoding error in literal (unexpected truncation)");
	}
    }
  utfeight_buf_len = uni_len * MAX_UTF8_CHAR + 1;
  utfeight_buf = (char *) dk_alloc (utfeight_buf_len);
  utfeight_buf_tail = eh_encode_buffer__UTF8 (uni, uni+uni_len, utfeight_buf, utfeight_buf+utfeight_buf_len);
  utfeight_buf_tail[0] = '\0';
  utfeight = box_dv_short_string (utfeight_buf);
  dk_free (uni,uni_alloc_len);
  dk_free (utfeight_buf, utfeight_buf_len);
  return utfeight;
}

caddr_t
xml_view_name (client_connection_t *cli, char *q, char *o, char *n,
    char **err_ret, caddr_t *q_ret, caddr_t *o_ret, caddr_t *n_ret)
{
  dbe_schema_t *newest_schema;
  char temp[MAX_QUAL_NAME_LEN];
  char q_loc [MAX_NAME_LEN], o_loc [MAX_NAME_LEN];
  char *q2;
  char *o2;
  if (q && (strlen (q) > MAX_NAME_LEN))
    { err_ret[0] = "Database qualifier is too long"; return NULL; }
  if (o && (strlen (o) > MAX_NAME_LEN))
    { err_ret[0] = "Owner name is too long"; return NULL; }
  if (o && strchr (o, '.'))
    { err_ret[0] = "Invalid owner name (it contains dot char)"; return NULL; }
  if (n && (strlen (n) > MAX_NAME_LEN))
    { err_ret[0] = "Name is too long"; return NULL; }
  if (n && strchr (n, '.'))
    { err_ret[0] = "Invalid local part of the name (it contains dot char)"; return NULL; }
  if (NULL == o && NULL == n)
    {
      char split[MAX_QUAL_NAME_LEN];
      char *xx = split;
      strcpy_ck (split, q);
      q = part_tok (&xx);
      o = part_tok (&xx);
      n = part_tok (&xx);
      if ((NULL == q) || ('\0' == q[0]))
        { err_ret[0] = "Invalid name (empty string)"; return NULL; }
      if (NULL != part_tok (&xx))
        { err_ret[0] = "Invalid name (too many dots)"; return NULL; }
      while (NULL == n)
        { n = o; o = q; q = NULL; }
      if ('\0' == n[0])
        { err_ret[0] = "Invalid name (no local part after dot)"; return NULL; }
      if ((NULL != o) && ('\0' == o[0]))
        o = NULL;
      if ((NULL != q) && ('\0' == q[0]))
        q = NULL;
      if (NULL != q)
	{
	  strcpy_ck (q_loc, q);
	  q = &(q_loc[0]);
	}
      if (NULL != o)
	{
	  strcpy_ck (o_loc, o);
	  o = &(o_loc[0]);
	}
    }
  else
    {
      if (NULL != q)
	{
	  strcpy_ck (q_loc, q);
	  q = &(q_loc[0]);
	}
      if (NULL != o)
	{
	  strcpy_ck (o_loc, o);
	  o = &(o_loc[0]);
	}
    }
  q2 = q ? q : cli->cli_qualifier;
  o2 = o ? o : CLI_OWNER (cli);
  newest_schema = cli->cli_new_schema;
  if (NULL == newest_schema) newest_schema = wi_inst.wi_schema;
  sch_normalize_new_table_case (newest_schema, q, sizeof (q_loc), o, sizeof (o_loc));
  sprintf (temp, "%s.%s.%s", q2, o2, n);
  if (NULL != q_ret)
    q_ret[0] = box_dv_short_string (q2);
  if (NULL != o_ret)
    o_ret[0] = box_dv_short_string (o2);
  if (NULL != n_ret)
    n_ret[0] = box_dv_short_string (n);
  return box_dv_short_string (temp);
}

caddr_t xp_xml_view_name (xpp_t *xpp, char *q, char *o, char *n)
{
  char *err = NULL;
  caddr_t res = xml_view_name (xpp->xpp_client, q, o, n, &err, NULL, NULL, NULL);
  if (NULL != err)
    xp_error (xpp, err);
  return res;
}


XT *
xp_make_literal_tree (xpp_t *xpp, caddr_t literal, int preserve_literal)
{
  if (IS_STRING_DTP(DV_TYPE_OF(literal)) && (&eh__UTF8 != xpp->xpp_enc))
    {
      char * utfeight = xp_recode_literal(xpp, literal);
      if (!preserve_literal)
        dk_free_box (literal);
      literal = utfeight;
    }
  else if (preserve_literal)
    literal = box_copy (literal);
  if (NULL == literal)
    literal = box_num_nonull(0);
  if (xp_env ()->xe_for_interp)
    return xtlist (xpp, 4, XP_LITERAL, box_num((ptrlong)(xpp->xpp_lang)), literal, xe_new_xqst (xpp, XQST_REF));
  return (XT *)literal;
}


XT *
xp_path (xpp_t *xpp, XT * in, XT * path, ptrlong axis)
{
  XT *first = xp_first_step (path);
/*mapping schema*/
  if (in->type == XP_STEP && in->_.step.ctxbox && IS_BOX_POINTER(in->_.step.xpctx->xc_xj->xj_mp_schema) &&
      in->_.step.xpctx->xc_xj->xj_mp_schema->xj_is_constant)
     in = in->_.step.input;
/*end mapping schema*/
  if (XP_SLASH_SLASH == axis)
    {
      if (xp_step_needs_pos_or_size (xpp, first))
        {
          XT *new_first_step = xp_make_step (xpp, XP_DESCENDANT_OR_SELF, (XT *) XP_ELT_OR_ROOT, NULL);
          first->_.step.input = new_first_step;
          first->_.step.axis = XP_CHILD;
	  new_first_step->_.step.input = in;
	  return path;
        }
      else
        axis = XP_DESCENDANT;
    }
  first->_.step.input = in;
  if (axis)
    first->_.step.axis = axis;
  return path;
}


XT *
xp_absolute (xpp_t *xpp, XT * tree, ptrlong axis)
{
  XT *first = xp_first_step (tree);
  ptrlong first_axis = first->_.step.axis;
  if (!first)
    return NULL;
  if ((XP_ATTRIBUTE == first_axis) || (XP_ATTRIBUTE_WR == first_axis))
    {
      if (XP_ABS_SLASH_SLASH == axis)
        axis = XP_ABS_DESC;
      first->_.step.input = xp_make_step (xpp, axis, (XT *) XP_NODE, NULL);
      return tree;
    }
  if (XP_ABS_SLASH_SLASH == axis)
    {
      if (xp_step_needs_pos_or_size (xpp, first) || (XP_CHILD != first_axis))
        {
          XT *new_first_step = xp_make_step (xpp, XP_ABS_DESC_OR_SELF, (XT *) XP_ELT_OR_ROOT, NULL);
          first->_.step.input = new_first_step;
          return tree;
        }
      axis = XP_ABS_DESC;
      goto patch_step;
    }
    switch (first_axis)
      {
      case XP_CHILD: axis = XP_ABS_CHILD; break;
      case XP_DESCENDANT: axis = XP_ABS_DESC; break;
      case XP_DESCENDANT_OR_SELF: axis = XP_ABS_DESC_OR_SELF; break;
      default:
        {
          XT *new_first_step = xp_make_step (xpp, XP_ROOT, (XT *)XP_NODE, NULL);
          first->_.step.input = new_first_step;
          return tree;
        }
      }
patch_step:
  first->_.step.input = NULL;
  first->_.step.axis = axis;
  return tree;
}

int xp_c_no = 1;

int
xp_new_c_no (void)
{
  if (xp_c_no > 1000000)
    xp_c_no = 1;
  return (xp_c_no++);
}


ST *
st_col_dotted (const char *pref, const char *name)
{
  return (t_stlist (3, COL_DOTTED, t_box_string (pref), t_box_string (name)));
}


xp_ctxbox_t *
box_xc (xp_ctx_t * xc)
{
  xp_ctxbox_t * b = (xp_ctxbox_t *) dk_alloc_box (sizeof (xp_ctxbox_t), DV_ARRAY_OF_LONG);
  b->xcb_xc = xc;
  return b;
}


void
xp_q_name (xpp_t *xpp, char * exp_name, size_t max_exp_name, char * pref, char * name, caddr_t dflt_uri)
{
  caddr_t ns_uri;
  if (NULL == pref)
    {
      if (NULL == dflt_uri)
	strcpy_size_ck (exp_name, name, max_exp_name);
      else
	sprintf (exp_name, "%s:%s", dflt_uri, name);
      return;
    }
  if (XP_STAR == (ptrlong) name)
    name = "%";
  ns_uri = xp_namespace_pref_to_uri (xpp, pref);
  if (BADBEEF_BOX != ns_uri)
    {
      sprintf (exp_name, "%s:%s", ns_uri, name);
      return;
    }
  else
    {
      char err_buf[1000];
      snprintf (err_buf, sizeof(err_buf), "Undeclared namespace prefix '%s' before '%s'", pref, name);
      xp_error (xpp, err_buf);
    }
}

caddr_t *dk_set_assoc (dk_set_t list, ccaddr_t key)
{
  while (list)
    {
      if ((!key && !list->data)
	  || (key && list->data && 0 == strcmp (key, (char*) list->data)))
	{
	  return (caddr_t *)(&(list->next->data));
	}
      list = list->next->next;
    }
  return NULL;
}

caddr_t
xp_namespace_pref_to_uri (xpp_t *xpp, caddr_t pref)
{
  dk_set_t list;
  caddr_t *uri_ptr;
  list = xp_env()->xe_namespace_prefixes;
  uri_ptr = dk_set_assoc (list, pref);
  if (NULL != uri_ptr)
    return box_copy (uri_ptr[0]);
  if (NULL == pref)
    return NULL;
  if (!strncasecmp (pref, "xml", 3))
    return box_dv_uname_string (pref);
/*
  if (!strcmp (pref, XFN_NS_PREFIX))
    return box_dv_short_string (XNF_NS_URI);
*/
  return BADBEEF_BOX;
}

caddr_t
xp_namespace_pref (xpp_t *xpp, caddr_t pref)
{
  caddr_t uri;
  if (!xp_env ()->xe_for_interp)
    return box_copy (pref);
  uri = xp_namespace_pref_to_uri (xpp, pref);
  if (BADBEEF_BOX == uri)
    {
      char err_buf[1000];
      snprintf (err_buf, sizeof(err_buf), "Undeclared namespace prefix '%s'", pref);
      xp_error (xpp, err_buf);
    }
  return uri;
}

caddr_t
xp_namespace_pref_cname (xpp_t *xpp, caddr_t name)
{
  char *colon = strrchr (name, ':');
  caddr_t res;
  caddr_t pref = box_dv_short_nchars (name, colon-name);
  res = xp_namespace_pref (xpp, pref);
  dk_free_box (pref);
  return res;
}


caddr_t
xp_make_expanded_name (xpp_t *xpp, caddr_t qname, int is_special)
{
  char *colon = strrchr (qname, ':');
  caddr_t ns_uri;
  if ('(' == qname[0])
    {
      int len = strlen (qname);
      if ((4 < len) && ('!' == qname [1]) && ('!' == qname [len-2]) && (')' == qname [len-1]))
        return box_dv_short_nchars (qname + 2, len - 4);
    }
  if (NULL != colon)
    {
      caddr_t pref = box_dv_short_nchars (qname, colon-qname);
      ns_uri = xp_namespace_pref_to_uri (xpp, pref);
      dk_free_box (pref);
      if (BADBEEF_BOX == ns_uri)
	{
	  char err_buf[1000];
	  snprintf (err_buf, sizeof(err_buf), "Undeclared namespace prefix in name '%s'", qname);
	  xp_error (xpp, err_buf);
	}
    }
  else
    switch (is_special)
      {
      case 1: /* attribute */
        ns_uri = NULL;
        break;
      case -1: /* function */
        ns_uri = xpp->xpp_xp_env->xe_dflt_fn_namespace;
      default: /* element */
        ns_uri = xpp->xpp_xp_env->xe_dflt_elt_namespace;
      }
  if (NULL == ns_uri)
    return box_dv_short_string (qname);
  else
    {
      char buf[MAX_XML_QNAME_LENGTH];
      sprintf (buf, "%s:%s", ns_uri, ((NULL != colon) ? colon + 1 : qname));
      return box_dv_short_string (buf);
    }
}


caddr_t xp_make_extfunction_name (xpp_t *xpp, caddr_t pref, caddr_t qname)
{
/* The function returns unchanged \c qname or dk_free_box() it.
The \c pref will be deleted. */
  if (NULL != pref)
    {
      caddr_t ns = xp_namespace_pref (xpp, pref);
      int lns = box_length (ns);
      int lqname = box_length (qname);
      caddr_t res = dk_alloc_box (lns + lqname, DV_SHORT_STRING);
      memcpy (res, ns, lns-1); res[lns-1] = ':';
      memcpy (res + lns, qname, lqname);
      dk_free_box (ns);
      return res;
    }
  else
    {
      char *colon = strrchr (qname, ':');
      caddr_t new_pref, new_qname, res;
      if (NULL == colon)
        return box_dv_short_string (qname);
      new_pref = box_dv_short_nchars (qname, colon - qname);
      new_qname = box_dv_short_string (colon + 1);
      res = xp_make_extfunction_name (xpp, new_pref, new_qname);
      dk_free_box (new_pref);
      dk_free_box (new_qname);
      return res;
    }
}


XT *
xp_make_step (xpp_t *xpp, ptrlong axis, XT * node, XT ** preds)
{
  ptrlong preds_use_size = 0;
  if (NULL == node)
    GPF_T;
  if ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (node)) && (XP_PI == node->type))
    { /* This is a special case. PI with a test on PITarget is converted into a plain PI test plus PITarget name equality predicate */
      int pred_idx, pred_count = ((NULL != preds) ? BOX_ELEMENTS (preds) : 0);
      XT *name_call = xp_make_call (xpp, "name", list (0));
      XT *name_eq = xtlist (xpp, 4, (ptrlong)BOP_EQ, name_call, box_copy (node->_.name_test.qname), xe_new_xqst (xpp, XQST_REF));
      XT *name_pred = xtlist (xpp, 5, XP_PREDICATE, name_eq, (ptrlong) 0, NULL, NULL);
      XT **new_preds = dk_alloc_box (sizeof (XT *) * (1 + pred_count), DV_ARRAY_OF_POINTER);
      new_preds [0] = name_pred;
      for (pred_idx = pred_count; pred_idx--; /* no step */)
         new_preds [pred_idx + 1] = preds [pred_idx];
      dk_free_tree ((caddr_t) node);
      node = (XT *)((ptrlong)XP_PI);
      dk_free_box ((caddr_t) preds);
      preds = new_preds;
    }
  if (NULL != preds)
    {
      int inx;
      DO_BOX (XT *, pred, inx, preds)
	{
	  if (pred->_.pred.size)
	    preds_use_size = inx + 1;
	}
      END_DO_BOX;
    }
  if (xp_env ()->xe_for_interp)
    {
      XT * step = xtlist (xpp, 16, XP_STEP,
	NULL,				/* input		*/
        axis,				/* axis			*/
        node,				/* node			*/
	NULL,				/* ctxbox		*/
	preds,				/* preds		*/
	preds_use_size,			/* preds_use_size	*/
	xe_new_xqst (xpp, XQST_INT),	/* iter_idx		*/
	xe_new_xqst (xpp, XQST_REF),	/* iterator		*/
	xe_new_xqst (xpp, XQST_REF),	/* cast_res		*/
	xe_new_xqst (xpp, XQST_REF),	/* init			*/
	xe_new_xqst (xpp, XQST_REF),	/* node_set		*/
	xe_new_xqst (xpp, XQST_INT),	/* node_set_size	*/
	xe_new_xqst (xpp, XQST_INT),	/* node_set_iter	*/
	xe_new_xqst (xpp, XQST_INT),	/* depth		*/
	xe_new_xqst (xpp, XQST_INT)	/* state		*/
	);
      return step;
    }
  else
    {
      XT *step = xtlist (xpp, 7, XP_STEP, NULL, axis, node, NULL, preds, preds_use_size);
      if (xp_is_join_step (axis))
	{
	  xp_ctx_t *xc = (xp_ctx_t *) dk_alloc_box_zero (sizeof (xp_ctx_t), DV_ARRAY_OF_LONG);
	  xc->xc_c_no = xp_new_c_no ();
	  xc->xc_axis = axis;
#ifdef DEBUG
	  if (NULL == node)
	    GPF_T;
#endif
	  if (((XT *) XP_NODE == node) || ((XT *) XP_ELT == node))
	    xc->xc_table = entity_table;
	  else if (ARRAYP (node))
		{
		  char exp_name[MAX_XML_QNAME_LENGTH+1];
		  int pred;
		  dbe_table_t *tb;
		  xp_q_name (xpp, exp_name, sizeof (exp_name), node->_.name_test.nsuri, node->_.name_test.local, NULL /* not xp_env()->xe_dflt_elt_namespace */);
		  pred = strchr (exp_name, '%') ? BOP_LIKE : BOP_EQ;
		  tb = xmls_element_table (exp_name);
		  if (tb)
		    xc->xc_table = tb;
		  else
		    {
		      char cn[30];
		      sprintf (cn, "c__%d", xc->xc_c_no);
		      xc->xc_table = entity_table;
		      xc->xc_node_test = stlist (4,
			  pred,
			  box_copy_tree ((box_t) st_col_dotted (cn, "E_NAME")),
			  box_dv_short_string (exp_name), NULL);
		    }
		}
	  else
	    xp_error (xpp, "PI or unsupported node test");
	  step->_.step.ctxbox = box_xc (xc);
	  dk_set_push (&xp_env ()->xe_ctxs, (void *) xc);
	}
      return step;
    }
}


void
xp_pred_start (xpp_t *xpp)
{
  xp_env_t * xe = xp_env ();
  XT * pred;
  pred = xtlist (xpp, 5, XP_PREDICATE, NULL, NULL, NULL, NULL);
  dk_set_push (&xe->xe_pred_stack, (void*) pred);
}


#if 0
int
xt_is_num_exp (XT * exp)
{
  return (! (xt_is_ret_boolean (exp)
	     || xt_is_ret_node_set (exp)));
}
#endif

XT *
xp_make_pred (xpp_t *xpp, XT * expr)
{
  xp_env_t * xe = xp_env ();
  int predicted;
  XT * pred = (XT *) dk_set_pop (& xe->xe_pred_stack);
  pred->_.pred.expr = expr;
  predicted = xt_predict_returned_type (expr);
  if (!pred->_.pred.pos && (XPDV_BOOL != predicted) && (XPDV_NODESET != predicted))
    pred->_.pred.pos = xe_new_xqst (xpp, XQST_INT);
  return pred;
}


XT * xp_make_flwr (xpp_t *xpp, dk_set_t forlets, XT *where_expn, dk_set_t ordering, XT *return_expn)
{
#ifdef DEBUG
  XT *raw_return_expn = return_expn;
#endif
  XT **ordering_array = NULL;
  ptrlong ordering_type;
  void *last_for_forlet = NULL;
  if (NULL != ordering)
    {
      ordering_type = (ptrlong)dk_set_pop (&ordering);
      DO_SET (dk_set_t, forlet, &forlets)
	{
	  if (XQ_FOR == ((ptrlong)(forlet->data)))
	    last_for_forlet = forlet;
	}
      END_DO_SET ();
      ordering_array = (XT **)revlist_to_array (ordering);
      if (NULL == last_for_forlet)
	{
	  dk_free_tree (ordering_array); /* Nothing to sort */
	  ordering_array = NULL;
	}
    }
  if (NULL != ordering_array)
    {
      XT **arglist = dk_alloc_box (sizeof(XT *) * (1 + BOX_ELEMENTS(ordering_array)), DV_ARRAY_OF_POINTER);
      ptrlong spec_inx;
      DO_BOX_FAST (XT *, spec, spec_inx, ordering_array)
	{
	  arglist[spec_inx] = spec->_.xslt_sort.xs_tree;
	  spec->_.xslt_sort.xs_tree = NULL;
	}
      END_DO_BOX_FAST;
      arglist[BOX_ELEMENTS(ordering_array)] = return_expn;
      return_expn = xp_make_call (xpp, box_dv_uname_string("vector for ORDER BY"), (caddr_t)arglist);
    }
  if (NULL != where_expn)
    {
      XT *false_expn = xp_make_call (xpp, box_dv_uname_string("false"), list (0));
      return_expn = xp_make_call (xpp, box_dv_uname_string("if"),
	list (3, where_expn, return_expn, false_expn) );
    }
  while (NULL != forlets)
    {
      dk_set_t forlet = (dk_set_t)dk_set_pop (&forlets);
      int is_last_for_forlet = (forlet == last_for_forlet);
      ptrlong type = (ptrlong)dk_set_pop (&forlet);
      switch (type)
	{
	case XQ_FOR:
	  {
	    while (NULL != forlet)
	      {
		caddr_t *vardef = (caddr_t *)dk_set_pop (&forlet);
		XT *new_return = xp_make_call ( xpp, box_dv_uname_string("for"),
		    list (3, xp_make_literal_tree (xpp, vardef[XT_HEAD], 1), vardef[XT_HEAD+1], return_expn) );
		dk_free_box ((caddr_t)vardef);
		return_expn = new_return;
	      }
	    if (is_last_for_forlet)
	      {
		return_expn = xp_make_call (xpp, box_dv_uname_string("ORDER BY operator"), list (3, return_expn, ordering_array, xp_make_literal_tree (xpp, box_num (1), 0)));
	      }
	    break;
	  }
	case XQ_LET:
	  {
	    XT *new_return;
	    dk_set_t let_args = NULL;
	    dk_set_push (&let_args, return_expn);
	    while (NULL != forlet)
	      {
		caddr_t *vardef = (caddr_t *)dk_set_pop (&forlet);
		dk_set_push (&let_args, vardef[XT_HEAD+1]);
		dk_set_push (&let_args, xp_make_literal_tree (xpp, vardef[XT_HEAD], 1));
		dk_free_box ((caddr_t)vardef);
		new_return = return_expn;
	      }
	    new_return = xp_make_call (xpp, box_dv_uname_string("let"), list_to_array (let_args));
	    return_expn = new_return;
	    break;
	  }
	default: xp_error (xpp, "internal XQuery error in compilation of FLWR expression");
	}
    }
#ifdef DEBUG
  dk_check_tree (raw_return_expn);
  dk_check_tree (return_expn);
#endif
  return return_expn;
}

XT * xp_make_direct_el_ctor (xpp_t *xpp, XT *el_name, dk_set_t attrs, dk_set_t subel_expns)
{
  /* attrs is a list of form (name1,val1, name2,val2, ... nameN,valN) */
  XT *head_composer;
  XT *res;
  if (NULL != attrs)
    {
      void **items;
      int items_no, item_ctr;
      dk_set_push (&attrs, el_name);
      items = (void **) list_to_array (attrs);
      items_no = (int)BOX_ELEMENTS((caddr_t)items);
      /* Items with indexes 2,4,6... are now lists of strings to be concatenated. */
      for (item_ctr = 2; item_ctr < items_no; item_ctr += 2)
	{
	  dk_set_t substrings = (dk_set_t)(items[item_ctr]);
	  if (NULL == substrings->next)
	    { /* No expressions inside the string => no concatenation */
	      items[item_ctr] = dk_set_pop (&substrings);
	    }
	  else
	    {
	      XT *concat_call = xp_make_call (xpp, box_dv_uname_string("concat"),
		  list_to_array (substrings) );
	      items[item_ctr] = concat_call;
	    }
	}
      head_composer = xp_make_call (xpp, box_dv_uname_string("tuple"), (caddr_t)items);
    }
  else
    head_composer = el_name;
  dk_set_push (&(subel_expns), head_composer);
  res = xp_make_call (xpp, box_dv_uname_string("create-element"), list_to_array (subel_expns));
  return res;
}

XT * xp_make_direct_comment_ctor (xpp_t *xpp, XT *content)
{
  XT *res = xp_make_call (xpp, box_dv_uname_string("create-comment"), list (1, content));
  return res;
}

XT * xp_make_direct_pi_ctor (xpp_t *xpp, XT *name, XT *content)
{
  XT *res = xp_make_call (xpp, box_dv_uname_string("create-pi"), list (2, name, content));
  return res;
}

XT * xp_make_deref (xpp_t *xpp, XT *step, XT * name_test)
{
  XT * nsuri = xp_make_literal_tree (xpp, name_test->_.name_test.nsuri, 1);
  XT * local = xp_make_literal_tree (xpp, name_test->_.name_test.local, 1);
  XT * qname = xp_make_literal_tree (xpp, name_test->_.name_test.qname, 1);
  dk_free_box ((box_t) name_test);
  return xp_make_call (xpp, box_dv_uname_string("deref"), list (4, step, nsuri, local, qname));
}

XT * xp_make_cast (xpp_t *xpp, ptrlong cast_or_treat, XT *type, XT *arg_tree)
{
  xp_error (xpp, "CAST/CASTABLE/TREAT expressions are not yet supported");
  switch (cast_or_treat)
  {
    case XQ_CAST_AS_CNAME: ;
    case XQ_CASTABLE_AS_CNAME: ;
    case TREAT_AS_L: ;
  }
  return arg_tree;
}


XT * xp_make_sortby (xpp_t *xpp, XT *arg_tree, dk_set_t criterions)
{
  int crit_no = dk_set_length (criterions);
  if (0 == crit_no)
    return arg_tree;
  return xp_make_call (xpp, box_dv_uname_string("SORTBY operator"), list (2, arg_tree, revlist_to_array (criterions)));
}


XT *
xp_make_filter (xpp_t *xpp, XT * path, XT * pred)
{
  if ((CALL_STMT == path->type) && (!path->_.xp_func.var))
    {
      path = xp_make_call (xpp, box_dv_uname_string ("iterate"), list (1, path));
    }
  if (xp_env ()->xe_for_interp)
    return xtlist (xpp, 4, XP_FILTER, path, pred, xe_new_xqst (xpp, XQST_INT));
  else
    {
      XT * expr = pred ->_.pred.expr;
      dk_free_box ((caddr_t) pred);
      return xtlist (xpp, 3, XP_FILTER, path, expr);
    }
}

XT *
xp_make_filters (xpp_t *xpp, XT * path, dk_set_t preds)
{
  XT *res = path;
  while (NULL != preds)
    res = xp_make_filter (xpp, res, (XT *) dk_set_pop(&preds));
  return res;
}

void
box_subst (caddr_t box, caddr_t elt, caddr_t repl)
{
  if (IS_BOX_POINTER (box) && DV_ARRAY_OF_POINTER == box_tag (box))
    {
      caddr_t * box2 = (caddr_t*) box;
      int inx;
      DO_BOX (caddr_t, item, inx, box2)
	{
	  if (box_equal (item, elt))
	    {
/*	      dk_free_tree (item);*/
	      box2[inx] = t_full_box_copy_tree (repl);
	    }
	  else
	    box_subst (item, elt, repl);
	}
      END_DO_BOX;
    }
}


ST *
xp_xj_cond (xp_ctx_t * start, xp_ctx_t * next, char * cn1, char * cn2)
{
  caddr_t b1 = t_box_string (cn1);
  caddr_t b2 = t_box_string (cn2);
  caddr_t cond = t_full_box_copy_tree ((caddr_t) next->xc_xj->xj_join_cond);
  if (start->xc_xj)
    box_subst (cond, start->xc_xj->xj_prefix, b1);
  box_subst (cond, next->xc_xj->xj_prefix, b2);
/*  dk_free_box (b1);
  dk_free_box (b2);*/
  return ((ST *) cond);
}


ST *
xp_join_pred (xp_ctx_t * start, xp_ctx_t * next)
{
  char cn1[30];
  char cn2[30];
  ST * p;
  sprintf (cn1, "c__%d", start->xc_c_no);
  sprintf (cn2, "c__%d", next->xc_c_no);
  if (next->xc_xj)
    return (xp_xj_cond (start, next, cn1, cn2));
  p = t_stlist (3, CALL_STMT, t_box_string ("ancestor_of"),
		  t_list (5, st_col_dotted (cn1, "E_ID"), st_col_dotted (cn2, "E_ID"),
		 t_box_num (next->xc_axis), NULL, NULL));
  p = t_stlist (4, BOP_NOT, t_stlist (4, BOP_EQ, t_box_num (0), p, NULL), NULL, NULL);
  if (next->xc_node_test)
    p = sql_tree_and (p, (ST *) t_box_copy_tree ((caddr_t) next->xc_node_test));
  return p;
}


#ifdef OLD_VXML_TABLES
char * fixed_doc_text =
"select 1 from (select _D.E_ID, (select N.E_ID from DB.DBA.VXML_DOCUMENT N where N.E_ID > _D.E_ID) as D_NEXT "
"  from DB.DBA.VXML_DOCUMENT _D where D_URI = ':0' order by D_URI) __D";


char * wildcard_doc_text =
"select 1 from (select _D.E_ID, (select N.E_ID from DB.DBA.VXML_DOCUMENT N where N.E_ID > _D.E_ID) as D_NEXT "
"  from DB.DBA.VXML_DOCUMENT _D where D_URI like ':0'and _D.D_URI >= ':1' and _D.D_URI < ':2' "
"order by D_URI) __D";

caddr_t wildcard_doc = NULL;
caddr_t fixed_doc = NULL;
#endif


void
xp_init_filter (xpp_t *xpp, xp_ctx_t * start_ctx, xp_ret_t * xr)
{
  char cn[30];
#ifdef OLD_VXML_TABLES
  ST *where = NULL;
  ST *texp = t_stlist (9, TABLE_EXP, NULL, NULL, NULL, NULL, NULL, NULL,NULL, NULL);
  ST *sel = t_stlist (5, SELECT_STMT, 0, t_list (0), NULL, texp);
#endif
  memset (xr, 0, sizeof (xp_ret_t));
  sprintf (cn, "c__%d", start_ctx->xc_c_no);
  if (start_ctx->xc_is_generated)
    return;
#ifdef OLD_VXML_TABLES
  start_ctx->xc_is_generated = 1;
  texp->_.table_exp.from =
    (ST**) t_list (1, t_list (3, TABLE_REF, t_list (5, TABLE_DOTTED, t_box_string ("DB.DBA.VXML_DOCUMENT"), t_box_string (cn),
					      t_box_num (SC_U_ID (xp_env ()->xe_sc)), t_box_num (SC_G_ID (xp_env ()->xe_sc))), NULL));

  texp->_.table_exp.where = where;
  sqlp_infoschema_redirect (texp);
  xr->xr_tree = sel;
#else
  GPF_T1("Access to old VXML tables");
#endif
}

/*mapping schema 12.02.03*/
/*
int
xp_is_simple_subelement (XT * xj)
{
  if (xj->type == XP_STEP && xj->_.step.ctxbox && xj->_.step.ctxbox->xcb_xc->xc_xj->xj_mp_schema &&
      xj->_.step.ctxbox->xcb_xc->xc_xj->xj_mp_schema->xj_same_table)
  return 1;
  return 0;
}

int
xp_is_constant_subelement (XT * xj)
{
   if (xj->type == XP_STEP && IS_BOX_POINTER(xj->_.step.ctxbox) &&
                    IS_BOX_POINTER(xj->_.step.ctxbox->xcb_xc->xc_xj->xj_mp_schema) &&
                    xj->_.step.ctxbox->xcb_xc->xc_xj->xj_mp_schema->xj_is_constant)
   return 1;
   return 0;
}
*/
/*end mapping schema*/

#ifdef OLD_VXML_TABLES
ST *
xp_document_select (xpp_t *xpp)
{
  static caddr_t  colon0;
  static caddr_t colon1;
  static  caddr_t colon2;
  xp_env_t * xe = xp_env ();
  ST * _template;
  char * star = strchr (xe->xe_doc_spec, '*');
  int leading = star ? (int) (star - xe->xe_doc_spec) : 0;

  if (!colon0)
    {
      colon0 = box_dv_short_string (":0");
      colon1 = box_dv_short_string (":1");
      colon2 = box_dv_short_string (":2");
    }

  if (star)
    {
      char * lower, * higher;
      if (leading)
	{
	  lower = box_dv_short_substr (xe->xe_doc_spec, 0, leading);
	  higher = box_dv_short_substr (xe->xe_doc_spec, 0, leading);
	  higher [box_length (higher) - 2]++;
	}
      else
	{
	  lower = box_dv_short_string ("");
	  higher = box_dv_short_string ("\377\377");
	}
      _template = (ST*) box_copy_tree (wildcard_doc);
      box_subst ((caddr_t) _template, colon0,  xe->xe_doc_spec);
      box_subst ((caddr_t) _template, colon1, lower);
      box_subst ((caddr_t) _template, colon2, higher);
      dk_free_box (lower);
      dk_free_box (higher);
    }
  else
    {
      _template = (ST*) box_copy_tree ((caddr_t) fixed_doc);
      box_subst ((caddr_t) _template, colon0, xe->xe_doc_spec);
    }
  xe->xe_doc_bounds = 1;
  return ((ST*) _template);
}


ST *
xp_doc_range_pred (xp_ctx_t * stctx)
{
  char cn[30];
  ST *res;
  sprintf (cn, "c__%d", stctx->xc_c_no);
  BIN_OP (res, BOP_AND,
      t_stlist (4, BOP_GTE, st_col_dotted (cn, "E_ID"), st_col_dotted ("__D", "E_ID"), NULL),
      t_stlist (4, BOP_LT, st_col_dotted (cn, "E_ID"), st_col_dotted ("__D", "D_NEXT"), NULL));
  return res;
}


void
xp_init_doc_select (xpp_t *xpp, XT * step, xp_ret_t * xr)
{
  int axs = (int) step->_.step.axis;
  ST * sel = xp_document_select (xpp);
  xp_ctx_t * stctx = step->_.step.xpctx;
  ST *where = NULL;
  ST *texp = sel->_.select_stmt.table_exp;
  ST **from = texp->_.table_exp.from;
  ST *tref;
  char cn[30];
  sprintf (cn, "c__%d", stctx->xc_c_no);
  tref = t_stlist (3, TABLE_REF, t_stlist (5, TABLE_DOTTED,
				       t_box_string (stctx->xc_table->tb_name), t_box_string (cn),
				       t_box_num (SC_U_ID (xp_env ()->xe_sc)),
				       t_box_num (SC_G_ID (xp_env ()->xe_sc))), NULL);
  where = xp_doc_range_pred (stctx);
  texp->_.table_exp.from = (ST**) t_box_append_1 ((caddr_t)from, (caddr_t) tref);
/*  dk_free_box ((caddr_t) from);*/

  if (axs == XP_CHILD || axs == XP_CHILD_WR || axs == XP_ABS_CHILD || axs == XP_ABS_CHILD_WR)
    {
      where = sql_tree_and (where, t_stlist (3, BOP_EQ, st_col_dotted (cn, "E_LEVEL"), t_box_num (1)));
      if (stctx->xc_node_test)
	where = sql_tree_and (where, (ST*) t_full_box_copy_tree ((caddr_t) stctx->xc_node_test));
    }
  else
    {
      if (stctx->xc_node_test)
	where = sql_tree_and (where, (ST*) t_full_box_copy_tree ((caddr_t) stctx->xc_node_test));
    }
  texp->_.table_exp.where = sql_tree_and (texp->_.table_exp.where, where);

  sqlp_infoschema_redirect (texp);
  xr->xr_tree = sel;
  /* dbg_print_box (xr->xr_tree, stdout); printf ("\n"); */

}
#endif

void
xp_init_select (xpp_t *xpp, xp_ctx_t * xc, XT * step, xp_ret_t * xr)
{
  int axs = (int) step->_.step.axis;
  xp_ctx_t *step_ctx = step->_.step.xpctx;
  char cn[30];
  ST *where = NULL;
  ST *texp = t_stlist (9, TABLE_EXP, NULL, NULL, NULL, NULL, NULL, NULL,NULL, NULL);
  ST *sel = t_stlist (5, SELECT_STMT, 0, t_list (0), NULL, texp);
  sprintf (cn, "c__%d", step_ctx->xc_c_no);
  if (step_ctx->xc_is_generated)
    return;
  step_ctx->xc_is_generated = 1;
  if (step_ctx->xc_xj)
    {
      where = xp_join_pred (xc, step_ctx);
    }
  else
    {
#ifdef OLD_VXML_TABLES
      if (!xc->xc_table && xp_env ()->xe_doc_spec)
	{
	  xp_init_doc_select (xpp, step, xr);
	  return;
	}
#endif
      if (axs == XP_CHILD || axs == XP_CHILD_WR || axs == XP_ABS_CHILD || axs == XP_ABS_CHILD_WR)
	where = t_stlist (3, BOP_EQ, st_col_dotted (cn, "E_LEVEL"), t_box_num (1));
      else
	{
	  if (xc->xc_table)
	    where = xp_join_pred (xc, step_ctx);
	}
    }
  texp->_.table_exp.from =
    (ST**) t_list (1, t_list (3, TABLE_REF, t_list (5, TABLE_DOTTED, t_box_string (step_ctx->xc_table->tb_name), t_box_string (cn),
					      t_box_num (SC_U_ID (xp_env ()->xe_sc)), t_box_num (SC_G_ID (xp_env ()->xe_sc))), NULL));

  if (!step_ctx->xc_xj && step_ctx->xc_node_test)
    where = sql_tree_and (where, (ST*) t_full_box_copy_tree ((caddr_t) step_ctx->xc_node_test));

  texp->_.table_exp.where = where;
  sqlp_infoschema_redirect (texp);
  xr->xr_tree = sel;
}



ST *
xp_subq_value (ST ** subq)
{
  ST * vsq = *subq;
  ST * sel = vsq->_.bin_exp.left;
  *subq = sel;
  return ((ST*) t_full_box_copy_tree (sel->_.select_stmt.selection[0]));
}

void
xp_add_as (ST ** selection)
{
  int inx;
  DO_BOX (ST *, col, inx, selection)
    {
      if (!ST_P (col, BOP_AS))
	{
	  caddr_t name;
	  if (ST_COLUMN (col, COL_DOTTED))
	    name = t_box_string (col->_.col_ref.name);
	  else
	    name = t_box_string ("__");
	  selection[inx] = t_stlist (5, BOP_AS, col, NULL, name, NULL);
	}
    }
  END_DO_BOX;
}

void
xp_comparison (xpp_t *xpp, xp_ctx_t * xc, XT * tree, xp_ret_t * xr)
{
  int p1 = 0, p2 = 0;
  xp_ret_t lhs;
  xp_ret_t rhs;

  xp_sql (xpp, xc, tree->_.bin_exp.left, &lhs, GM_VALUE);
  if (lhs.xr_is_empty)
    {
      xr->xr_is_empty = 1;
      return;
    }

  if (ST_P (lhs.xr_tree, SCALAR_SUBQ))
    {
      p1 = 1;
    }
  xp_sql (xpp, xc, tree->_.bin_exp.right, &rhs, GM_VALUE);
  if (rhs.xr_is_empty)
    {
      xr->xr_is_empty = 1;
      return;
    }
  if (ST_P (rhs.xr_tree, SCALAR_SUBQ))
    {
      p2 = 1;
    }

  if (p1 && p2)
    {
      char cn1[30];
      char cn2[30];
      sprintf (cn1, "c__%d", xp_new_c_no ());
      sprintf (cn2, "c__%d", xp_new_c_no ());

      {
	ST *dt1 = t_stlist (3, DERIVED_TABLE, lhs.xr_tree->_.bin_exp.left, t_box_string (cn1));
	ST *dt2 = t_stlist (3, DERIVED_TABLE, rhs.xr_tree->_.bin_exp.left, t_box_string (cn2));
	ST *where = t_stlist (4, tree->type, st_col_dotted (cn1, lhs.xr_value_col),
			    st_col_dotted (cn2, rhs.xr_value_col), NULL);
	ST *texp = sqlp_infoschema_redirect (t_stlist (9, TABLE_EXP, t_list (2, dt1, dt2),
			   where, NULL, NULL, NULL, NULL, NULL, NULL));
	ST *subq = t_stlist (5, SELECT_STMT, 1, t_list (1, t_box_num (1)), NULL, texp);
	xr->xr_tree = SUBQ_PRED (EXISTS_PRED, NULL, subq, NULL, NULL);
	xp_add_as ((ST**) lhs.xr_tree->_.bin_exp.left->_.select_stmt.selection);
	xp_add_as ((ST**) rhs.xr_tree->_.bin_exp.left->_.select_stmt.selection);
      }
    }
  else if (p1)
    {
      ST * op = t_stlist (4, tree->type, xp_subq_value (&lhs.xr_tree), rhs.xr_tree, NULL);
      lhs.xr_tree->_.select_stmt.table_exp->_.table_exp.where =
	sql_tree_and (op, lhs.xr_tree->_.select_stmt.table_exp->_.table_exp.where);
      xr->xr_tree = SUBQ_PRED (EXISTS_PRED, NULL, lhs.xr_tree, 0, NULL);
    }
  else if (p2)
{
      ST * op = t_stlist (4, tree->type, lhs.xr_tree, xp_subq_value (&rhs.xr_tree), NULL);
      rhs.xr_tree->_.select_stmt.table_exp->_.table_exp.where =
	sql_tree_and (op, rhs.xr_tree->_.select_stmt.table_exp->_.table_exp.where);
      xr->xr_tree = SUBQ_PRED (EXISTS_PRED, NULL, rhs.xr_tree, 0, NULL);
    }
  else
    xr->xr_tree = t_stlist (4, tree->type, lhs.xr_tree, rhs.xr_tree, NULL);
}


caddr_t
xt_node_name (xpp_t *xpp, XT * tree)
{
  char exp_name[MAX_XML_QNAME_LENGTH+1];
  xp_q_name (xpp, exp_name, sizeof (exp_name), tree->_.name_test.nsuri, tree->_.name_test.local, NULL /* not xp_env()->xe_dflt_elt_namespace */);
  return (t_box_string (exp_name));
}

/*mapping schema 13.02.03*/
/*
void
xp_simple_subelement_ref (xpp_t *xpp, xp_ctx_t * xc, XT * tree, xp_ret_t * xr)
{
  char cn[30];
/ *  if (tree->_.step.ctxbox)
    xc = tree->_.step.xpctx; * /
  sprintf (cn, "c__%d", xc->xc_c_no);
  xr->xr_tree = st_col_dotted (cn, xt_node_name (xpp, tree->_.step.node));
  DO_SET (caddr_t, ref, &xc->xc_cols)
  {
    if (box_equal (ref, (caddr_t) xr->xr_tree))
      return;
  }
  END_DO_SET ();
  dk_set_push (&xc->xc_cols, (void *) xr->xr_tree);
}
*/
/*end mapping schema 13.02.03*/

void
xp_attr_ref (xpp_t *xpp, xp_ctx_t * xc, XT * tree, xp_ret_t * xr)
{
  char cn[30];
  if (tree->_.step.ctxbox)
    xc = tree->_.step.xpctx;
  sprintf (cn, "c__%d", xc->xc_c_no);
  xr->xr_tree = st_col_dotted (cn, xt_node_name (xpp, tree->_.step.node));
  DO_SET (caddr_t, ref, &xc->xc_cols)
  {
    if (box_equal (ref, (caddr_t) xr->xr_tree))
      return;
  }
  END_DO_SET ();
  dk_set_push (&xc->xc_cols, (void *) xr->xr_tree);
}


xp_ctx_t *
xp_path_end_ctx (xp_ctx_t * start, XT * tree)
{
  if (!tree)
    return start;
  switch (tree->type)
    {
    case XP_FILTER:
      return (xp_path_end_ctx (start, tree->_.filter.path));
      /*    case XP_UNION:
       * return (tree->_.xp_union.ctx); */
    case XP_STEP:
      switch (tree->_.step.axis)
	{
	case XP_SELF:
	  return start;
	case XP_NAMESPACE:
	case XP_ATTRIBUTE:
	case XP_ATTRIBUTE_WR:
	  return (xp_path_end_ctx (start, tree->_.step.input));
/*mapping schema 12.02.03* /
        case XP_CHILD:
          {
            if (xp_is_simple_subelement(tree))
	      return (xp_path_end_ctx (start, tree->_.step.input));
          }
/ *end mapping schema*/
	default:
	  return (tree->_.step.xpctx);
	}
    }
  return start;
}


void
xp_join_step (xpp_t *xpp, xp_ctx_t * xc, XT * tree, xp_ret_t * xr)
{
  xp_ctx_t *left_ctx = xp_path_end_ctx (xc, tree->_.step.input);
  xp_ctx_t * stctx = tree->_.step.xpctx;
  ST *jcond = NULL;
  ST *texp = xr->xr_tree->_.select_stmt.table_exp;
  ST **from = texp->_.table_exp.from;
  ST *tref;
  char cn[30];
  if (stctx->xc_is_generated)
    return;
  stctx->xc_is_generated = 1;
  sprintf (cn, "c__%d", stctx->xc_c_no);
  tref = t_stlist (3, TABLE_REF, t_stlist (5, TABLE_DOTTED,
				       t_box_string (stctx->xc_table->tb_name), t_box_string (cn),
				       t_box_num (SC_U_ID (xp_env ()->xe_sc)),
				       t_box_num (SC_G_ID (xp_env ()->xe_sc))), NULL);
  jcond = xp_join_pred (left_ctx, stctx);
  texp->_.table_exp.where = sql_tree_and (texp->_.table_exp.where, jcond);
  texp->_.table_exp.from = (ST**) t_box_append_1 ((caddr_t)from, (caddr_t) tref);
/*  dk_free_box ((caddr_t) from);*/
}


void
xp_select_value (xpp_t *xpp, ST * attr_ref, xp_ret_t * xr, int mode)
{

  ST *sel = xr->xr_tree;
  if (!ST_P (sel, SELECT_STMT))
    {
      /* in SQL view a .. refers to a generated join and reduces to empty path
       * thus ../@attr -> attr,  with no select */
      xr->xr_tree = attr_ref;
      return;
    }
/*  dk_free_tree ((caddr_t) sel->_.select_stmt.selection);*/
  if (mode == GM_TOP && xp_env ()->xe_is_http)
    attr_ref = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("http_value"),
		       t_list (2, attr_ref, t_box_copy (xp_env ()->xe_result_tag)));
  sel->_.select_stmt.selection = (caddr_t*) t_list (1, attr_ref);
  xr->xr_value_col = t_full_box_copy_tree ((caddr_t) attr_ref->_.col_ref.name);
}



void
xp_select_entity (xpp_t *xpp, XT * tree, xp_ret_t * xr, int mode)
{
  xp_env_t * xe = xp_env ();
  ST * ref;
 char cn[30];
  ST *sel = xr->xr_tree;
  xp_ctx_t * xp = tree->_.step.xpctx;
  if (!ST_P (sel, SELECT_STMT))
    GPF_T1 ("path supposed to be a select");
/*  dk_free_tree ((caddr_t) sel->_.select_stmt.selection);*/
  sprintf (cn, "c__%d", xp->xc_c_no);
  ref = t_stlist (3, COL_DOTTED, t_box_string (cn), t_box_string ("E_ID"));

  if (mode == GM_TOP)
    {
      if (xe->xe_is_http)
	ref = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("http_entity"),
		    t_list (3, ref, t_box_copy (xe->xe_result_tag),
			  t_box_num (xe->xe_is_shallow != 0 ? 4 : 0)));
      else if (xe->xe_is_sax)
	ref = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("DB.DBA.sax_entity"),
		    t_list (3, ref, t_box_copy (xe->xe_result_tag),
			  t_box_num (xe->xe_is_shallow != 0 ? 4 : 0)));
      else if (!xe->xe_is_for_key)
	ref = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("value_of"),
		      t_list (1, ref));
      ref = t_listst (5, BOP_AS, ref, NULL, t_box_string ("ENTITY"), NULL);
      xr->xr_value_col = box_dv_short_string ("ENTITY");
    }
  else if (mode == GM_VALUE)
    {
      ref = t_listst (3, CALL_STMT, t_sqlp_box_id_upcase ("value_of"),
		    t_list (1, ref));
      ref = t_listst (5, BOP_AS, ref, NULL, t_box_string ("ENTITY"), NULL);
      xr->xr_value_col = box_dv_short_string ("ENTITY");
    }
  sel->_.select_stmt.selection = (caddr_t*) t_list (1, ref);
}


void
xr_postprocess (xp_ret_t * xr, int mode)
{
  ST * tree = xr->xr_tree;
  int etype = st_type (tree);
  switch (mode)
    {
    case GM_COND:
      if (ET_SELECT == etype)
	xr->xr_tree = SUBQ_PRED (EXISTS_PRED, NULL, tree, 0, NULL);
      else if (ET_EXP == etype)
	xr->xr_tree = t_stlist (4, BOP_NOT, t_stlist (4, BOP_EQ, t_box_num (0), tree, NULL), NULL, NULL);
      break;
    case GM_TOP:
      if (ET_SELECT == etype)
	return;
      xr_postprocess (xr, GM_VALUE);
      xr->xr_tree = t_stlist (5, SELECT_STMT, 0, t_stlist (1, xr->xr_tree), NULL, NULL);
      break;
    case GM_VALUE:
      if (ET_SELECT == etype)
	xr->xr_tree = t_stlist (2, SCALAR_SUBQ, tree);
      else if (ET_PRED == etype)
	xr->xr_tree = t_stlist (2, SEARCHED_CASE, t_stlist (4, tree, t_box_num (1), t_stlist (2, QUOTE, NULL), t_box_num (0)));
      break;
    }
}


ST *
xp_col_ref (caddr_t sym)
{
  char * dot;
  if ((dot = strchr (sym, '.')))
    {
      long dotp = (long) (dot - sym);
      return (t_stlist (3, COL_DOTTED, t_box_substr (sym, 1, dotp),
		      t_box_substr (sym, dotp + 1, (int) strlen (sym))));
    }

  return (t_stlist (3, COL_DOTTED, NULL, t_box_string (sym + 1)));
}


void
xp_sql (xpp_t *xpp, xp_ctx_t * start_ctx, XT * tree, xp_ret_t * xr, int mode)
{
  memset (xr, 0, sizeof (xp_ret_t));
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    {
      /* literal or parameter */
      if (DV_UNAME == DV_TYPE_OF  (tree) && xp_env ()->xe_inside_sql)
	{
          if (':' == ((caddr_t)tree)[0])
            xr->xr_tree = ((ST *) sym_string ((caddr_t)tree));
	  else
            xr->xr_tree = xp_col_ref ((caddr_t) tree);
	}
      else
	xr->xr_tree = (ST *) t_full_box_copy_tree ((caddr_t) tree);
    }
  else if (ST_P (tree, XP_STEP) &&
	   ((tree->_.step.axis == XP_ATTRIBUTE) || (tree->_.step.axis == XP_ATTRIBUTE_WR))
	   && !tree->_.step.input)
    {
      xp_attr_ref (xpp, start_ctx, tree, xr);
    }
  else
    switch (tree->type)
      {
      case XP_STEP:
	{
          xp_ctx_t * end_ctx;
	  ST *attr_ref = NULL;
          end_ctx = xp_path_end_ctx (start_ctx, tree);
	  if (!tree->_.step.input)
	    {
	      xp_init_select (xpp, start_ctx, tree, xr);
	    }
	  if ((XP_ATTRIBUTE == tree->_.step.axis) || (XP_ATTRIBUTE_WR == tree->_.step.axis))
	    {
	      xp_ret_t atmp;
	      xp_attr_ref (xpp, end_ctx, tree, &atmp);
	      attr_ref = atmp.xr_tree;
	    }
/*mapping schema 12.02.03* /
          if (xp_is_simple_subelement(tree))
            {
	      xp_ret_t atmp;
	      xp_simple_subelement_ref (xpp, end_ctx, tree, &atmp);
	      attr_ref = atmp.xr_tree;
            }
/ *end mapping schema*/
	  if (tree->_.step.input)
	    {
	      xp_sql (xpp, start_ctx, tree->_.step.input, xr, GM_KEY);
	      if (xp_is_join_step ((int) tree->_.step.axis))
/*mapping schema*/
/*                if (!xp_is_constant_subelement (tree))*//* && !xp_is_simple_subelement(tree))*/
/*                     (IS_BOX_POINTER(tree->_.step.ctxbox) &&
                    (!IS_BOX_POINTER(tree->_.step.ctxbox->xcb_xc->xc_xj->xj_mp_schema) ||
                    !tree->_.step.ctxbox->xcb_xc->xc_xj->xj_mp_schema->xj_is_constant))*/
/*end mapping schema*/
     		  xp_join_step (xpp, start_ctx, tree, xr);
	    }
	  if (GM_VALUE == mode || GM_TOP == mode || GM_FILTER == mode)
	    {
	      if (attr_ref)
		xp_select_value (xpp, attr_ref, xr, mode);
	      else
		xp_select_entity (xpp, tree, xr, mode);
	    }
	  break;
	}
      case XP_FILTER:
	{
	  xp_ctx_t *end = xp_path_end_ctx (start_ctx, tree->_.filter.path);
	  xp_ret_t pred;
	  xp_ret_t path;

	  if (!tree->_.filter.path)
	    xp_init_filter (xpp, start_ctx, &path);
	  else
	    xp_sql (xpp, start_ctx, tree->_.filter.path, &path, GM_KEY);
	  if (path.xr_is_empty)
	    {
	      xr->xr_is_empty = 1;
	      return;
	    }
	  xp_sql (xpp, end, tree->_.filter.pred, &pred, GM_COND);
	  if (pred.xr_is_empty)
	    {
	      xr->xr_is_empty = 1;
	      return;
	    }
          if (SELECT_STMT != path.xr_tree->type)
	    xp_error (xpp, "Unsupported use of XPATH filter subexpression, please rewrite the query to avoid filters on attributes");
	  path.xr_tree->_.select_stmt.table_exp->_.table_exp.where =
	    sql_tree_and (path.xr_tree->_.select_stmt.table_exp->_.table_exp.where, pred.xr_tree);
	  *xr = path;
	  break;
	}
      case CALL_STMT:
	{
	  int inx, argcount = (int) tree->_.xp_func.argcount;
	  ST ** args = (ST **) t_alloc_box (sizeof (XT *) * argcount, DV_ARRAY_OF_POINTER);
	  /*ST ** args = (ST**) t_box_copy ((caddr_t) tree->_.xp_func.args);*/
	  for (inx = 0; inx < argcount; inx++)
	    {
	      XT * arg = tree->_.xp_func.argtrees[inx];
	      xp_ret_t arg_xr;
	      xp_sql (xpp, start_ctx, arg, &arg_xr, GM_VALUE);
	      args[inx] = arg_xr.xr_tree;
	    }
	  xr->xr_tree = t_stlist (3, CALL_STMT, t_box_copy (tree->_.xp_func.qname), args);
	  break;
	}

      case BOP_EQ: case BOP_GT: case BOP_LT: case BOP_GTE: case BOP_LTE: case BOP_LIKE:
	xp_comparison (xpp, start_ctx, tree, xr);
	break;
      case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
	{
	  xp_ret_t lhs;
	  xp_ret_t rhs;
	  xp_sql (xpp, start_ctx, tree->_.bin_exp.left, &lhs, GM_VALUE);
	  xp_sql (xpp, start_ctx, tree->_.bin_exp.right, &rhs, GM_VALUE);
	  xr->xr_tree = t_stlist (4, tree->type, lhs.xr_tree, rhs.xr_tree, NULL);
	  break;
	}
      case BOP_AND: case BOP_OR: case BOP_NOT:
	{
	  xp_ret_t lhs;
	  xp_ret_t rhs;
	  xp_sql (xpp, start_ctx, tree->_.bin_exp.left, &lhs, GM_COND);
	  xp_sql (xpp, start_ctx, tree->_.bin_exp.right, &rhs, GM_COND);
	  xr->xr_tree = t_stlist (4, tree->type, lhs.xr_tree, rhs.xr_tree, NULL);
	  break;
	}
      }
  xr_postprocess (xr, mode);
}


int
xt_node_test_match_impl (XT * node_test, caddr_t qname)
{
  int name_len, aux1, aux2;
#ifdef DEBUG
  if (DV_UNAME != DV_TYPE_OF (qname))
    GPF_T;
#endif
  switch ((ptrlong)node_test)
  {
    case XP_NODE: return 1;
    case XP_TEXT: return qname == uname__txt;
    case XP_PI: return qname == uname__pi;
    case XP_COMMENT: return qname == uname__comment;
    case XP_ELT: return (' ' != qname[0]);
    case XP_ELT_OR_ROOT: return (' ' != qname[0]) || (qname == uname__root);
    default:
      if (!ARRAYP(node_test))
	GPF_T;
      switch (node_test->type)
	{
	case XP_NAME_EXACT:
#ifdef DEBUG
	  if (qname == node_test->_.name_test.qname)
	    return 1;
	  if (!strcmp (qname, node_test->_.name_test.qname))
	    GPF_T;
	  return 0;
#else
	  return qname == node_test->_.name_test.qname;
#endif
	case XP_NAME_NSURI:
	  name_len = box_length_inline (qname) - 1;
	  aux1 = box_length_inline (node_test->_.name_test.nsuri) - 1;
	  return (name_len > aux1) && (':' == qname[aux1]) && !memcmp (qname, node_test->_.name_test.nsuri, aux1);
	case XP_NAME_LOCAL:
	  if ((NULL == node_test->_.name_test.nsuri) && qname == node_test->_.name_test.local)
	    return 1;
	  name_len = box_length_inline (qname) - 1;
	  aux1 = box_length_inline (node_test->_.name_test.local) - 1;
	  aux2 = name_len - aux1;
	  return (aux2 > 0) && (':' == qname[aux2 - 1]) && !memcmp (qname + aux2, node_test->_.name_test.local, aux1);
	default: /* no op*/;
	}
    }
  GPF_T1("Bad qname test in xt_node_test_match_impl");
  return 0;
}


int
xt_node_test_match_parts (XT * node_test, char *local, size_t local_len, caddr_t ns)
{
  int aux;
  switch ((ptrlong)node_test)
  {
    case 0: return (local_len && (' ' != local[0]));
    case XP_NODE: return 1;
    case XP_TEXT: return ((4 /* strlen(" txt") */ == local_len) && !memcmp (local, uname__txt, 4));
    case XP_PI: return ((3 /* strlen(" pi") */ == local_len) && !memcmp (local, uname__pi, 3));
    case XP_COMMENT: return ((8 /* strlen(" comment") */ == local_len) && !memcmp (local, uname__comment, 8));
    case XP_ELT: return (local_len && (' ' != local[0]));
    case XP_ELT_OR_ROOT: return ( (local_len && (' ' != local[0])) ||
      ((5 /* strlen(" root") */ == local_len) && !memcmp (local, uname__root, 5)) );
    default:
      if (!ARRAYP(node_test))
	GPF_T;
      switch (node_test->type)
	{
	case XP_NAME_EXACT:
	  if (NULL == ns)
	    { /* This is turned into a special case to support xmlns:XXX XPER attributes */
	      aux = box_length_inline (node_test->_.name_test.qname) - 1;
	      return (aux == local_len) && !memcmp (local, node_test->_.name_test.qname, local_len);
	    }
	  aux = box_length_inline (node_test->_.name_test.local) - 1;
	  return (ns == node_test->_.name_test.nsuri) && (aux == local_len) &&
	    !memcmp (local, node_test->_.name_test.local, local_len);
	case XP_NAME_NSURI:
	  return (ns == node_test->_.name_test.nsuri);
	case XP_NAME_LOCAL:
	  aux = box_length_inline (node_test->_.name_test.local) - 1;
	  return (((NULL == node_test->_.name_test.nsuri) || (NULL != ns)) &&
	    (aux == local_len) && !memcmp (local, node_test->_.name_test.local, local_len) );
	default: /* no op*/;
	}
    }
  GPF_T1("Bad local test in xt_node_test_match_parts");
  return 0;
}


int
xv_is_step_appendable (xv_join_elt_t * xj, XT * step)
{
  ptrlong step_axis = step->_.step.axis;
  int inx;
  if ((XP_ATTRIBUTE == step_axis) || (XP_ATTRIBUTE_WR == step_axis))
    {
      DO_BOX (xj_col_t *, xc, inx, xj->xj_cols)
	{
	  if (!(XV_XC_ATTRIBUTE & xc->xc_usage))
	    continue;
	  if (xt_node_test_match (step->_.step.node, xc->xc_xml_name))
	    return 1;
	}
      END_DO_BOX;
    }
  /*!!! Explicit error here: no check for XV_XC_SUBELEMENT columns */
  if (xp_is_join_step ((int) step_axis))
    {
      DO_BOX (xv_join_elt_t *, child, inx, xj->xj_children)
	{
	  if (xt_node_test_match (step->_.step.node, child->xj_element))
	    return 1;
	}
      END_DO_BOX;
    }
  return 0;
}


typedef struct xv_step_s
{
  xv_join_elt_t *	xs_xj;
  struct xv_step_s *	 xs_prev;
} xv_step_t;




XT *
xl_sub_path (xpp_t *xpp, xv_step_t * st)
{
  XT * input = NULL;
  if (st->xs_prev)
    input = xl_sub_path (xpp, st->xs_prev);
  {
    XT * step;
/*mapping schema 14.02.03* /
    if (IS_BOX_POINTER(st->xs_xj->xj_mp_schema) && st->xs_xj->xj_mp_schema->xj_same_table)
      {
	char * col_name = st->xs_xj->xj_mp_schema->xj_column->_.col_ref.name;
        step = xp_make_step (xpp, XP_CHILD,
			          xp_make_name_test_from_qname (xpp, col_name, 1),
			          NULL);
      }
    else
/ *end mapping schema*/

      step = xp_make_step (xpp, XP_CHILD,
        xp_make_name_test_from_qname (xpp, st->xs_xj->xj_element, 1),
        NULL );
/*mapping schema 05.03.03*/
    if (input && input->type == XP_STEP && input->_.step.ctxbox && IS_BOX_POINTER(input->_.step.xpctx->xc_xj->xj_mp_schema) &&
        input->_.step.xpctx->xc_xj->xj_mp_schema->xj_is_constant)
      step->_.step.input = input->_.step.input;
    else
/*end mapping schema*/
      step->_.step.input = input;
    step->_.step.xpctx->xc_xj = st->xs_xj;
/*mapping schema* /
    if (IS_BOX_POINTER(st->xs_xj->xj_mp_schema) &&
       st->xs_xj->xj_mp_schema->xj_is_constant) / *|| st->xs_xj->xj_mp_schema->xj_same_table)) simple*/
/*      {
         step->_.step.xpctx->xc_table = NULL;
         return step;
      }*/
/*end mapping schema*/
    step->_.step.xpctx->xc_table = sch_name_to_table (xp_env ()->xe_schema, st->xs_xj->xj_table);
    if (!step->_.step.xpctx->xc_table)
      xe_error ("S0002", "No table in XPATH SQL expansion");
    return step;
  }
}


xv_join_elt_t *
xj_top (xv_join_elt_t * xj)
{
  while (xj->xj_parent)
    xj = xj->xj_parent;
  return xj;
}


XT *
xp_parent_step (xpp_t *xpp, xv_join_elt_t * start)
{
  xp_env_t * xe = xp_env ();
  xp_ctx_t * parent_xc = NULL;
  DO_SET (xp_ctx_t *, xc, &xe->xe_ctxs)
    {
      if (xc->xc_xj == start)
	{
	  parent_xc = xc;
	  break;
	}
    }
  END_DO_SET ();
  if (!parent_xc)
    GPF_T1 ("unbalanced parent ref in XPATH compilation");

  return  xtlist (xpp, 6, XP_STEP, NULL, XP_PARENT,
	xp_make_name_test_from_qname (xpp, start->xj_element, 1),
	box_xc (parent_xc), NULL );
}

/*mapping schema*/
/*
XT *
xp_attribute_join_step (xpp_t *xpp, xv_join_elt_t * start)
{
  XT * input = NULL;
  if (start->xj_parent->xj_parent)
    input = xp_attribute_join_step (xpp, start->xj_parent); / * create input step-node * /
  if (IS_BOX_POINTER(start->xj_mp_schema) && start->xj_mp_schema->xj_is_constant) / * if element is a constant (is not mapped to any table) * /
    return input;
  {
    XT * step = xp_make_step (xpp, XP_CHILD,
	xp_make_name_test_from_qname (xpp, start->xj_element, 1),
			      NULL);
    step->_.step.input = input;
    step->_.step.xpctx->xc_xj = start;
    step->_.step.xpctx->xc_table = sch_name_to_table (xp_env ()->xe_schema, start->xj_table);
    if (!step->_.step.xpctx->xc_table)
      xe_error ("S0002", "No table in XPATH SQL expansion (mapping schema)");
    return step;
  }
}
*/
/*end mapping schema*/

void
xv_attr_paths (xpp_t *xpp, xv_join_elt_t * start, XT * step,  dk_set_t * paths)
{
  int inx;
  DO_BOX (xj_col_t *, xc, inx, start->xj_cols)
    {
      if (!(XV_XC_ATTRIBUTE & xc->xc_usage))
        continue;
      if (xt_node_test_match (step->_.step.node, xc->xc_xml_name))
	{
    	  char * col_name;
	  if (!ST_COLUMN (xc->xc_exp, COL_DOTTED))
	    xe_error ("S0002", "The column in an XML view must correspond to a SQL column, not an expression");
	  col_name = xc->xc_exp->_.col_ref.name;
          if (!IS_BOX_POINTER(xc->xc_relationship)) /*mapping schema*/
	    NCONCF1 (*paths, xtlist (xpp, 6, XP_STEP, NULL, XP_ATTRIBUTE,
		xp_make_name_test_from_qname (xpp, col_name, 1),
	  			 NULL, NULL));
/*mapping schema*/
          else
            {
	      step = xp_make_step (xpp, XP_CHILD,
		xp_make_name_test_from_qname (xpp, col_name, 1),
			        NULL);

	      step->_.step.xpctx->xc_table = sch_name_to_table (xp_env ()->xe_schema, xc->xc_relationship->xj_table);
	      if (!step->_.step.xpctx->xc_table)
	        xe_error ("S0002", "No table in XPATH SQL expansion");
	      step->_.step.xpctx->xc_xj = xc->xc_relationship;

	      NCONCF1 (*paths, step);
/*xtlist (xpp, 6, XP_STEP, NULL, XP_CHILD,
				xp_make_name_test_from_qname (xpp, col_name, 1),
	  			 NULL, NULL));
*/
/*	      NCONCF1 (*paths,xp_path(xp_attribute_join_step(xpp, xc->xc_relationship),
	   		              xtlist (xpp, 6, XP_STEP, NULL, XP_ATTRIBUTE,
	  				      xp_make_name_test_from_qname (xpp, col_name, 1),
					      NULL, NULL),
                                          0));
*/
            }
/*end mapping schema*/
	}
    }
  END_DO_BOX;
}


void
xv_paths (xpp_t *xpp, xv_join_elt_t * start, XT * step, XT * end_step, xv_step_t * prev, dk_set_t * paths)
{
  long axs = (int) step->_.step.axis;
  int inx;
  xv_step_t st;
  memset (&st, 0, sizeof (st));
  if (!prev)
    {
      if (XP_ABS_CHILD == axs || XP_ABS_CHILD_WR == axs || XP_ABS_DESC == axs || XP_ABS_DESC_WR == axs || XP_ABS_DESC_OR_SELF == axs || XP_ABS_DESC_OR_SELF_WR == axs)
	{
	  start = xj_top (start);
	  prev = NULL;
	}
      if (XP_PARENT == step->_.step.axis)
	{
	  if (!start->xj_parent->xj_parent)
	    return;
	  start = start->xj_parent;
	  if (xt_node_test_match (step->_.step.node, start->xj_element))
	    {
	      NCONCF1 (*paths, xp_parent_step (xpp, start));
	    }

	  return;
	}
    }
  st.xs_prev = prev;
  if ((XP_ATTRIBUTE == axs) || (XP_ATTRIBUTE_WR == axs))
    {
      xv_attr_paths (xpp, start, step, paths);
      return;
    }
  /*!!! Explicit bug! There is no case of columns that are XV_XC_SUBLEMENT */
  DO_BOX (xv_join_elt_t *, child, inx, start->xj_children)
    {
      st.xs_xj = child;
/*mapping schema* /
      if (!child->xj_mp_schema || !child->xj_mp_schema->xj_same_table)
        {
/ *end mapping schema*/

      if (xt_node_test_match (step->_.step.node, child->xj_element))
	{
	  NCONCF1 (*paths, xl_sub_path (xpp, &st));
	}
      if (XP_DESCENDANT == axs || XP_DESCENDANT_WR == axs || XP_ABS_DESC == axs || XP_ABS_DESC_WR == axs || XP_ABS_DESC_OR_SELF == axs || XP_ABS_DESC_OR_SELF_WR == axs)
	{
	  xv_paths (xpp, child, step, end_step, &st, paths);
	}
/*mapping schema* /
        }
      else / * child is a column of the start table* /
        {
 	  char * col_name;
	  if (!ST_COLUMN (child->xj_mp_schema->xj_column, COL_DOTTED))
	    xe_error ("S0002", "The column in an XML view must correspond to a SQL column, not an expression");
	  col_name = child->xj_mp_schema->xj_column->_.col_ref.name;
	  NCONCF1 (*paths, xtlist (xpp, 6, XP_STEP, NULL, XP_CHILD,
	  			xp_make_name_test_from_qname (xpp, col_name, 1),
	  			NULL, NULL));
        }
/ *end mapping schema*/
    }
  END_DO_BOX;
}

xv_join_elt_t *
xl_end_xj (xv_join_elt_t * start, XT * path)
{
  if (!path)
    return start;
  switch (path->type)
    {
    case XP_STEP:
      if (xp_is_join_step  ((int) path->_.step.axis))
	return (path->_.step.xpctx->xc_xj);
      return NULL;
    case XP_FILTER:
      return xl_end_xj (start, path->_.filter.path);
    }
  return NULL;
}


void
xv_label_pred (xpp_t *xpp, xv_join_elt_t * start, XT * tree, dk_set_t * paths)
{
  XT * res = NULL;
  dk_set_t left = NULL;
  dk_set_t right = NULL;
  xv_label_tree (xpp, start, tree->_.bin_exp.left, &left);

  if (!left)
    {
      *paths = NULL;
      return;
    }
  if (tree->_.bin_exp.right)
    {
      xv_label_tree (xpp, start, tree->_.bin_exp.right, &right);
      if (!right)
	{
	  *paths = NULL;
	  dk_free_tree ((caddr_t) list_to_array (left));
	  return;
	}
      DO_SET (XT *, lhs, &left)
	{
	  DO_SET (XT *, rhs, &right)
	    {
	      XT * exp = xtlist (xpp, 4, tree->type, box_copy_tree((box_t) lhs), box_copy_tree((box_t) rhs), NULL);
	      if (res)
		res = xtlist (xpp, 3, BOP_OR, res, exp);
	      else
		res = exp;
	    }
	  END_DO_SET();
	}
      END_DO_SET ();
      dk_free_tree ((caddr_t) list_to_array (left));
      dk_free_tree ((caddr_t) list_to_array (right));
      *paths = CONS (res, NULL);
      return;
    }
}

void
xv_label_artm (xpp_t *xpp, xv_join_elt_t * start, XT * tree, dk_set_t * paths)
{
  XT * res = NULL;
  dk_set_t left = NULL;
  dk_set_t right = NULL;
  xv_label_tree (xpp, start, tree->_.bin_exp.left, &left);

  if (!left)
    {
      *paths = NULL;
      return;
    }
  if (tree->_.bin_exp.right)
    {
      xv_label_tree (xpp, start, tree->_.bin_exp.right, &right);
      if (!right)
	{
	  *paths = NULL;
	  dk_free_tree ((caddr_t) list_to_array (left));
	  return;
	}
      res = xtlist (xpp, 4, tree->type, left->data, right->data, NULL);
      left->data = NULL;
      right->data= NULL;
      dk_free_tree ((caddr_t) list_to_array (left));
      dk_free_tree ((caddr_t) list_to_array (right));
      *paths = CONS (res, NULL);
    }
}


void
xv_label_call (xpp_t *xpp, xv_join_elt_t * start, XT * tree, dk_set_t * paths)
{
  int inx, argcount = (int) tree->_.xp_func.argcount;
  XT ** args = (XT**) dk_alloc_box_zero (sizeof (XT *) * argcount, DV_ARRAY_OF_POINTER);
  *paths = NULL;
  for (inx = 0; inx < argcount; inx++)
    {
      XT * arg = tree->_.xp_func.argtrees[inx];
      dk_set_t arg_paths = NULL;
      xv_label_tree (xpp, start, arg, &arg_paths);
      if (!arg_paths)
	{
	  dk_free_tree ((caddr_t) args);
	  return;
	}
      args[inx] = (XT*) arg_paths->data;
      dk_free_tree ((caddr_t) list_to_array (arg_paths->next));
      arg_paths->next = NULL;
      dk_set_free (arg_paths);
    }
#if 0
  *paths = CONS (list (3, CALL_STMT, box_copy (tree->_.xp_func.qname), args), NULL);
#else
  *paths = CONS (
    xtlist_with_tail (xpp, 8, (caddr_t) args, CALL_STMT,
      box_copy (tree->_.xp_func.qname),
      NULL,
      (ptrlong)(tree->_.xp_func.res_dtp),
      (ptrlong)0,
      (ptrlong)0,
      NULL ),
    NULL );

#endif
}
/*mapping schema 05.03.03*/
void xv_box_tag_modify (XT * path)
{
  if (!path) return;

  switch (path->type)
    {
    case XP_STEP:
      {
        if (path->_.step.ctxbox)
          {
	    box_tag_modify(path->_.step.ctxbox, DV_ARRAY_OF_POINTER);
	    path->_.step.ctxbox = (xp_ctxbox_t *) box_copy_tree ((caddr_t) path->_.step.ctxbox);
	    box_tag_modify(path->_.step.ctxbox, DV_ARRAY_OF_LONG);
          }
	xv_box_tag_modify (path->_.step.input);
        break;
      }
    case XP_FILTER:
      {
	xv_box_tag_modify (path->_.filter.path);
        break;
      }

    case XP_UNION: case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
         case BOP_EQ: case BOP_GT: case BOP_LT: case BOP_GTE: case BOP_LTE: case BOP_LIKE:
      {
	xv_box_tag_modify (path->_.bin_exp.left);
	xv_box_tag_modify (path->_.bin_exp.right);
	break;
      }
    case CALL_STMT:
      {
	int inx, argcount = (int) path->_.xp_func.argcount;
	for (inx = 0; inx < argcount; inx++)
	  {
            xv_box_tag_modify (path->_.xp_func.argtrees[inx]);
	  }
	break;
      }
    }
}
/*end mapping schema*/

void
xv_label_tree (xpp_t *xpp, xv_join_elt_t * start, XT * tree, dk_set_t * paths)
{
  int first;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    {
      *paths = CONS (box_copy_tree ((caddr_t) tree), NULL);
      return;
    }
  switch (tree->type)
    {
    case XP_STEP:
      {
	dk_set_t new_paths = NULL;
	if (tree->_.step.input)
	  xv_label_tree (xpp, start, tree->_.step.input, paths);
	else
	  {
	    xv_paths (xpp, start, tree, NULL, NULL, paths);
	    return;
	  }
	DO_SET (XT *, path, paths)
	  {
	    xp_ctx_t * end_ctx = xp_path_end_ctx (NULL, path);
	    dk_set_t next = NULL;
	    xv_paths (xpp, end_ctx->xc_xj, tree, NULL, NULL, &next);
	    first = 1;
	    DO_SET (XT *, follow, &next)
	      {
		if (!first)
                  {
		    path = (XT*) box_copy_tree ((caddr_t) path);
/*alex 27.02.03 in order to work queries like '/.../@*' or '/.../ *' with more than one subelements  */
                    xv_box_tag_modify(path);
/*end alex 27.02.03*/
                  }
		NCONCF1 (new_paths, xp_path (xpp, path, follow, 0));
		first = 0;
	      }
	    END_DO_SET();
	    if (!next)
	      dk_free_tree ((caddr_t) path);
            else
              dk_set_free (next);
	  }
	END_DO_SET();
	dk_set_free (*paths);
	*paths = new_paths;
	break;
      }
    case XP_FILTER:
      {
	dk_set_t new_paths = NULL;
	xv_label_tree (xpp, start, tree->_.filter.path, paths);
	DO_SET (XT *, path, paths)
	  {
	    XT * res = NULL;
	    dk_set_t filters = NULL;
	    xv_join_elt_t * end_xj = xl_end_xj (start, path);
	    xv_label_tree (xpp, end_xj, tree->_.filter.pred, &filters);
	    DO_SET (XT *, filter, &filters)
	      {
		if (res)
		  res = xtlist (xpp, 3, BOP_OR, res, filter);
		else
		  res = filter;
	      }
	    END_DO_SET();
	    if (res)
	      {
		NCONCF1 (new_paths, xtlist (xpp, 3, XP_FILTER, path, res));
	      }
	    else
	      dk_free_tree ((caddr_t) path);
	  }
	END_DO_SET ();
	dk_set_free (*paths);
	*paths = new_paths;
	break;
      }
    case XP_UNION:
      {
	dk_set_t lhs = NULL;
	dk_set_t rhs = NULL;
	xv_label_tree (xpp, start, tree->_.bin_exp.left, &lhs);
	xv_label_tree (xpp, start, tree->_.bin_exp.right, &rhs);
	*paths = dk_set_conc (lhs, rhs);
	break;
      }
    case CALL_STMT:
      {
	xv_label_call (xpp, start, tree, paths);
	break;
      }
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
      xv_label_artm (xpp, start, tree, paths);
      break;
    case BOP_EQ: case BOP_GT: case BOP_LT: case BOP_GTE: case BOP_LTE: case BOP_LIKE:
      xv_label_pred (xpp, start, tree, paths);
      break;
    case BOP_AND: case BOP_OR:
      xv_label_artm (xpp, start, tree, paths);
      break;
    }
}


dbe_table_t *
xj_table (xpp_t *xpp, xv_join_elt_t * xj)
{
  dbe_table_t * tb = sch_name_to_table (xp_env ()->xe_schema, xj->xj_table);
  return tb;
}


#define TA_XP_RST  114
#define CATCH_XP 112


void
xe_error (const char * state, const char * str)
{
  caddr_t err = srv_make_new_error (state, "XM010", "%s", str);
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_XP_RST, err);
  lisp_throw (CATCH_XP, RST_ERROR);
}


ST **
xj_pk_cols (xpp_t *xpp, xv_join_elt_t * xj, xp_ctx_t * xc, int all_cols)
{
  ST ** box;
  char cn[30];
  int n, nth = 0;
  dbe_table_t * tb = xj_table (xpp, xj);
  if (!tb)
    xe_error ("S0002", "Nonexistent table in xml view");
  sprintf (cn, "c__%d", xc->xc_c_no);
  if (!all_cols)
    n = BOX_ELEMENTS (xj->xj_pk);
  else
    n = dk_set_length (tb->tb_primary_key->key_parts);
  box = (ST**) t_alloc_box (n * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  if (!all_cols)
    {
      DO_BOX (caddr_t, name, nth, xj->xj_pk)
	{
	  box[nth] = st_col_dotted (cn, name);
	}
      END_DO_BOX;
    }
  else
    {
      DO_SET (dbe_column_t *, part, &tb->tb_primary_key->key_parts)
	{
	  box[nth] = st_col_dotted (cn, part->col_name);
	  nth++;
	  if (nth >= n)
	    break;
	}
      END_DO_SET ();
    }
  return box;
}


XT *
xp_end_step (XT * tree)
{
  if (!tree)
    return NULL;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    return NULL;
  switch (tree->type)
    {
    case XP_FILTER:
      return (xp_end_step (tree->_.filter.path));
    default: return tree;
    }
}


void
xv_sql_top_func (xpp_t *xpp, XT * path, ST * tree)
{
  XT * end_step = xp_end_step (path);
  ST ** sel;
  xp_env_t * xe = xp_env ();
  char tmp[1000];
  xv_join_elt_t * xj;
  xp_ctx_t * xc;
  xml_view_t *xv;
  if (!ST_P (tree, SELECT_STMT))
    return;
  if (XP_STEP != end_step->type)
    return;
  if ((path->_.step.axis == XP_ATTRIBUTE) || (path->_.step.axis == XP_ATTRIBUTE_WR))
    return;
  xc = end_step->_.step.xpctx;
  xj = xc->xc_xj;
  xv = xp_env ()->xe_view;
/*to create xmlview*/
  if (xe->xe_outputxml)
    {
      sprintf (tmp, "%s.%s.xte_%s_%s_%s", xv->xv_schema, xv->xv_user, xv->xv_local_name,
  	   xj->xj_element, xj->xj_prefix);
    }
/*end*/
  else
    sprintf (tmp, "%s.%s.http_%s_%s_%s", xv->xv_schema, xv->xv_user, xv->xv_local_name,
  	   xj->xj_element, xj->xj_prefix);
  if (xe->xe_is_for_attrs)
    sel = xj_pk_cols (xpp, xj, xc, 1);
  else if (xe->xe_is_for_key)
    sel = xj_pk_cols (xpp, xj, xc, 0);
  else
    {
      int out_flag = xe->xe_is_sax ? 2 : ( xe->xe_is_http ? 0 : 1);
      ST ** cols2 = xj_pk_cols (xpp, xj, xc, 0);
      ST ** cols;
      if (xe->xe_outputxml)
	cols = cols2;
      else
 	cols = (ST**) t_box_append_1 ((caddr_t) cols2, t_box_num (out_flag));
      /*dk_free_box ((caddr_t) cols2);*/
      if (xe->xe_outputxml)
        sel = (ST**) t_list (1,
			t_list (5, BOP_AS,
			    t_list (3, CALL_STMT,
				t_sqlp_box_id_upcase ("xml_tree_doc"),
				t_list (1,
				    t_list (3, CALL_STMT,
					t_box_string (tmp), cols ) ) ),
			    NULL, t_box_string ("ENTITY"), NULL ) );
      else
        sel = (ST**) t_list (1,
			t_list (5, BOP_AS,
			    t_list (3, CALL_STMT,
				t_box_string (tmp), cols ),
			    NULL, t_box_string ("ENTITY"), NULL ) );
      xe->xe_nonattribute_output = 1;
    }
  /*dk_free_tree ((caddr_t) tree->_.select_stmt.selection);*/
  tree->_.select_stmt.selection = (caddr_t *) sel;

}


ST *
xv_top_exp (xpp_t *xpp, XT * tree, caddr_t * err_ret)
{
  xp_ctx_t * top_xc;
  ST * sql = NULL;
  xp_env_t * xe = xp_env ();
  dk_set_t paths = NULL;
  xv_label_tree (xpp, xe->xe_view->xv_tree, tree, &paths);
  if (!paths)
    *err_ret = srv_make_new_error ("42S02", "XM011", "The XPATH reduces to empty in the specified SQL view");
  if (*err_ret)
    return NULL;
  top_xc = (xp_ctx_t *) dk_alloc_box_zero (sizeof (xp_ctx_t), DV_ARRAY_OF_LONG);

  DO_SET (XT *, path, &paths)
    {
      XT * end_step = xp_end_step (path);
      xp_ret_t xr;
      if (ST_P (end_step, XP_STEP) && xp_is_join_step ((int) end_step->_.step.axis)
/*mapping schema 12.02.03* /
          && !xp_is_simple_subelement (end_step)
/ *end mapping schema*/
         )
	{
	  xp_sql (xpp, top_xc, path, &xr, GM_KEY);
	  xv_sql_top_func (xpp, path, xr.xr_tree);
	}
      else
	xp_sql (xpp, top_xc, path, &xr, GM_TOP);

      if (!sql)
	sql = xr.xr_tree;
      else
	sql = t_stlist (5, UNION_ALL_ST, sql, xr.xr_tree, NULL, NULL);
    /* dk_free_tree ((caddr_t) path); */
    }
  END_DO_SET ();
  do {
      caddr_t paths_to_kill;
      paths_to_kill = list_to_array (paths);
      dk_check_tree (paths_to_kill);
      dk_free_tree (paths_to_kill);
    } while (0);
  if (*err_ret)
    return NULL;
  return sql;
}


void
xp_error (xpp_t *xpp, const char *strg)
{
  int lineno = ((NULL != xpp->xpp_curr_lexem) ? (int) xpp->xpp_curr_lexem->xpl_lineno : 0);
  char buf[210];
  if (box_length (xpp->xpp_text) > 200)
    {
      memcpy (buf, xpp->xpp_text, 200);
      strcpy_size_ck (buf + 200, "...", sizeof (buf) - 200);
    }
  else
    strcpy_ck (buf, xpp->xpp_text);
  xpp->xpp_err = srv_make_new_error ("37000", "XM028",
      "%.400s, line %d: %.1200s\nin the following expression:\n%.210s",
      xpp->xpp_err_hdr,
      lineno,
      strg, buf);
  longjmp (xpp->xpp_reset, 1);
}

void
xp_error_printf (xpp_t *xpp, const char *format, ...)
{
  char buf[1000];
  va_list tail;
  va_start (tail, format);
  vsnprintf (buf, 1000, format, tail);
  va_end (tail);
  xp_error (xpp, buf);
}

void
xpyyerror_impl (xpp_t *xpp, char *raw_text, const char *strg)
{
  int lineno = ((NULL != xpp->xpp_curr_lexem) ? (int) xpp->xpp_curr_lexem->xpl_lineno : 0);
  if ((NULL == raw_text) && (NULL != xpp->xpp_curr_lexem))
    raw_text = xpp->xpp_curr_lexem->xpl_raw_text;
  xpp->xpp_err = srv_make_new_error ("37000", "XM029",
      "%.400s, line %d: %.500s%.5s%.1000s\n",
      xpp->xpp_err_hdr,
      lineno,
      strg,
      ((NULL == raw_text) ? "" : " at "),
      ((NULL == raw_text) ? "" : raw_text));
  longjmp (xpp->xpp_reset, 1);
}

void
xpyyerror_impl_1 (xpp_t *xpp, char *raw_text, int yystate, short *yyssa, short *yyssp, const char *strg)
{
  int sm2, sm1, sp1;
  int lineno = (int) ((NULL != xpp->xpp_curr_lexem) ? xpp->xpp_curr_lexem->xpl_lineno : 0);
  char *next_text = NULL;
  if ((NULL == raw_text) && (NULL != xpp->xpp_curr_lexem))
    raw_text = xpp->xpp_curr_lexem->xpl_raw_text;
  if ((NULL != raw_text) && (NULL != xpp->xpp_curr_lexem))
    {
      if ((xpp->xpp_curr_lexem_bmk.xplb_offset + 1) < xpp->xpp_lexem_buf_len)
        next_text = xpp->xpp_curr_lexem[1].xpl_raw_text;
    }

  sp1 = yyssp[1];
  sm1 = yyssp[-1];
  sm2 = ((sm1 > 0) ? yyssp[-2] : 0);

  xpp->xpp_err = srv_make_new_error ("37000", "XM030",
     /*errlen,*/ "%.400s, line %d: %.500s [%d-%d-(%d)-%d]%.5s%.1000s%.5s%.15s%.1000s%.5s\n",
      xpp->xpp_err_hdr,
      lineno,
      strg,
      sm2,
      sm1,
      yystate,
      ((sp1 & ~0x7FF) ? -1 : sp1) /* stub to avoid printing random garbage in logs */,
      ((NULL == raw_text) ? "" : " at '"),
      ((NULL == raw_text) ? "" : raw_text),
      ((NULL == raw_text) ? "" : "'"),
      ((NULL == next_text) ? "" : " before '"),
      ((NULL == next_text) ? "" : next_text),
      ((NULL == next_text) ? "" : "'")
      );

  longjmp (xpp->xpp_reset, 1);
}

static int charref_to_unichar (const char **src_tail_ptr, const char *src_end, const char **err_msg_ret)
{
  const char *src_tail = src_tail_ptr[0];
  const char *ent_begin = src_tail;
  src_tail++;
  if ('#' == src_tail[0])
    {
      int ref_val = 0;
      int ref_base = 10;
      int digit_val;
      src_tail++;
      if ('x' == src_tail[0])
	{
	  src_tail++;
	  ref_base = 16;
	}
      while (src_tail < src_end)
	{
	  switch (src_tail[0])
	    {
	      case ';': src_tail_ptr[0] = src_tail + 1; return ref_val;
	      case '0': case '1': case '2': case '3': case '4':
	      case '5': case '6': case '7': case '8': case '9':
		digit_val = ((src_tail++)[0]) - '0';
		break;
	      case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':
	      case 'a': case 'b': case 'c': case 'd': case 'e': case 'f':
		if (10 == ref_base)
		  {
		    err_msg_ret[0] = "Hexadecimal digit in '&#...;', use &#x...; for hex";
		    return -1;
		  }
		digit_val = 10 + (('A' ^ 'a') | ((src_tail++)[0])) - 'a';
		break;
	      default:
	        err_msg_ret[0] = "Syntax error in &#...; character reference";
		return -1;
	    }
	  if (ref_val & ~0x0FFFFFFF)
	    { /* Note that this works for range 0-2G but will not work for range 0-4G! */
	      err_msg_ret[0] = "Numeric value in &#...; character reference is too big";
	      return -1;
	    }
	  ref_val = ref_val * ref_base + digit_val;
	  if (ref_val & ~0x7FFFFFFF)
	    {
	      err_msg_ret[0] = "Numeric value in &#...; character reference is too big";
	      return -1;
	    }
	}
    }
  if (!strncmp ("apos;", src_tail, 5)) { src_tail_ptr[0] += 5; return '\''; }
  if (!strncmp ("quot;", src_tail, 5)) { src_tail_ptr[0] += 5; return '\"'; }
  if (!strncmp ("amp;", src_tail, 4)) { src_tail_ptr[0] += 4; return '&'; }
  if (!strncmp ("lt;", src_tail, 3)) { src_tail_ptr[0] += 3; return '<'; }
  if (!strncmp ("gt;", src_tail, 3)) { src_tail_ptr[0] += 3;  return '>'; }
  /* If the name is unknown, error recovery is possible if this is of form &name= that is common for URIs */
  while (src_tail < src_end)
    {
      if ('=' == src_tail[0])
	break;
      if (!isalnum ((unsigned char) (src_tail[0])) && !(src_tail[0] & 0x80) && (NULL == strchr ("-_%+", src_tail[0])))
        {
          err_msg_ret[0] = "Syntax error in &...; character reference";
	  return -1;
	}
      src_tail++;
    }
  src_tail_ptr[0] = ent_begin+1;
  return '&';
}


caddr_t xp_charref_to_strliteral (xpp_t *xpp, const char *strg)
{
  const char *src_end = strchr(strg, '\0');
  const char *err_msg = NULL;
  int charref_val = charref_to_unichar (&strg, src_end, &err_msg);
  if (0 > charref_val)
    xpyyerror_impl (xpp, NULL, err_msg);
  else
    {
      char tmp[MAX_UTF8_CHAR];
      char *tgt_tail = eh_encode_char__UTF8 (charref_val, tmp, tmp + MAX_UTF8_CHAR);
      return box_dv_short_nchars (tmp, tgt_tail - tmp);
    }
  return box_dv_short_nchars ("\0", 1);
}


caddr_t xp_strliteral (xpp_t *xpp, const char *strg, char delimiter, int attr_cont)
{
  caddr_t tmp_buf;
  caddr_t res;
  const char *err_msg;
  const char *src_tail, *src_end;
  char *tgt_tail;
  int charref_val;
  /* Skip till the left delimiter: */
  src_tail = strg;
  src_end = strg + strlen (strg) - 1;
  while ((src_tail < src_end) && (delimiter != src_tail[0]) && (!attr_cont || ('}' != src_tail[0])))
    src_tail++;
  src_tail++; /* ...to skip starting delimiter */
  if ((src_tail > src_end) || ((delimiter != src_end[0]) && (!attr_cont || ('{' != src_end[0]))))
    xpyyerror_impl (xpp, NULL, "The string literal is not quoted properly");
  tgt_tail = tmp_buf = dk_alloc_box ((src_end - src_tail) + 1, DV_SHORT_STRING);
  while (src_tail < src_end)
    {
      switch (src_tail[0])
	{
	case '&':
	  if ('q' != xpp->xpp_expn_type)
	    {
	      (tgt_tail++)[0] = (src_tail++)[0];
	      continue;
	    }
	  err_msg = NULL;
	  charref_val = charref_to_unichar (&src_tail, src_end, &err_msg);
	  if (charref_val < 0)
	    goto err;
	  tgt_tail = eh_encode_char__UTF8 (charref_val, tgt_tail, tgt_tail + MAX_UTF8_CHAR);
	  continue;
	case '{': case '}':
	  if (attr_cont)
	    {
	      if (((src_tail+1) < src_end) && (src_tail[0] == src_tail[1]))
		{
		  (tgt_tail++)[0] = delimiter;
		  src_tail += 2;
		  continue;
		}
	      err_msg = "Brace should be repeated twice when inside the attribute value";
	      goto err;
	    }
	  else
	    (tgt_tail++)[0] = (src_tail++)[0];
	  continue;
	case '\\':
	  if ((src_tail+1) >= src_end)
	    {
	      if ('q' != xpp->xpp_expn_type)
	        {
		  err_msg = "There is no one character between '\' and the end of string";
		  goto err;
	        }
	      (tgt_tail++)[0] = (src_tail++)[0];
	      continue;
	    }
	  else
	    {
	      const char *bs_src = "abfnrtv\\\'\"";
	      const char *bs_trans = "\a\b\f\n\r\t\v\\\'\"";
	      const char *hit = strchr (bs_src, src_tail[1]);
	      if (NULL != hit)
	        {
	          src_tail += 2;
		  (tgt_tail++)[0] = bs_trans [hit - bs_src];
		  continue;
		}
	      if ('q' != xpp->xpp_expn_type)
	        {
		  err_msg = "Unsupported escape sequence after '\'";
		  goto err;
	        }
	      (tgt_tail++)[0] = (src_tail++)[0];
	      continue;
	    }
	case '\'': case '\"':
	  if (delimiter == src_tail[0])
	    {
	      if (((src_tail+1) < src_end) && (delimiter == src_tail[1]))
		{
		  (tgt_tail++)[0] = delimiter;
		  src_tail += 2;
		  continue;
		}
	      err_msg = "Quoting char should be repeated twice when inside the string";
	      goto err;
	    }
	  /* no break; */
	default: (tgt_tail++)[0] = (src_tail++)[0];
	}
    }
  res = box_dv_short_nchars (tmp_buf, tgt_tail - tmp_buf);
  dk_free_box (tmp_buf);
  return res;

err:
  dk_free_box (tmp_buf);
  xpyyerror_impl (xpp, NULL, err_msg);
  return NULL;
}


void
xe_free (xp_env_t * xe)
{
  xp_env_t *parent;
again:
  if (NULL == xe)
    return;
  DO_SET (xp_ctx_t *, xc, &xe->xe_ctxs)
    {
      dk_free_tree ((caddr_t) xc->xc_node_test);
      dk_free_box ((caddr_t) xc);
    }
  END_DO_SET ();
  dk_set_free (xe->xe_ctxs);
  while (xe->xe_namespace_prefixes_outer != xe->xe_namespace_prefixes)
    dk_free_tree (dk_set_pop (&(xe->xe_namespace_prefixes)));
  while (xe->xe_collation_uris_outer != xe->xe_collation_uris)
    {
      dk_free_tree (dk_set_pop (&(xe->xe_collation_uris)));
      dk_set_pop (&(xe->xe_collation_uris));
    }
  while (xe->xe_schemas_outer != xe->xe_schemas)
    {
      /* dk_free_tree (dk_set_pop (&(xe->xe_schemas))); */
      dk_set_pop (&(xe->xe_schemas));
    }
  while (xe->xe_modules_outer != xe->xe_modules)
    {
      /* dk_free_tree (dk_set_pop (&(xe->xe_modules))); */
      dk_set_pop (&(xe->xe_modules));
    }
  if (xe->xe_fundefs)
    id_hash_free (xe->xe_fundefs);
  parent = xe->xe_parent_env;
  dk_free_tree (xe->xe_base_uri);
  dk_free (xe, sizeof (xp_env_t));
  xe = parent;
  goto again;
}


#ifdef MALLOC_DEBUG
void xt_check (xpp_t * xpp, XT *expn)
{
  dk_set_t acc = NULL;
  caddr_t acc_list;
  if (NULL == xpp)
    {
      dk_check_tree (expn);
      return;
    }
  DO_SET (xp_lexem_t *, buf, &(xpp->xpp_output_lexem_bufs))
    {
      int ctr = box_length (buf) / sizeof (xp_lexem_t);
      while (ctr--)
	{
	  xp_lexem_t *xpl = buf+ctr;
	  dk_set_push (&acc, xpl->xpl_sem_value);
	}
    }
  END_DO_SET();
  DO_SET (XT *, decl, &(xpp->xpp_preamble_decls))
    {
      dk_set_push (&acc, decl);
    }
  END_DO_SET();
  dk_set_push (&acc, expn);
  acc_list = list_to_array (acc);
  dk_check_tree (acc_list);
  dk_free_box (acc_list);
}
#endif

void
xpp_free (xpp_t * xpp)
{
  while (xpp->xpp_output_lexem_bufs)
    {
      xp_lexem_t *buf = (xp_lexem_t *)xpp->xpp_output_lexem_bufs->data;
      int ctr = box_length (buf) / sizeof (xp_lexem_t);
      while (ctr--)
	{
	  xp_lexem_t *xpl = buf+ctr;
	  dk_free_tree (xpl->xpl_sem_value);
	  dk_free_box (xpl->xpl_raw_text);
	}
      dk_free_box ((box_t) buf);
      dk_set_pop (&(xpp->xpp_output_lexem_bufs));
    }
  while (xpp->xpp_xp2sql_params)
    {
/*      free (xpp->xpp_xp2sql_params->data);*/
      dk_set_pop (&(xpp->xpp_xp2sql_params));
    }
  while (xpp->xpp_preamble_decls)
    {
      dk_free_tree (dk_set_pop (&(xpp->xpp_preamble_decls)));
    }
  xe_free (xpp->xpp_xp_env);
#ifdef MALLOC_DEBUG
  dk_check_tree ((caddr_t) xpp->xpp_expr);
#endif
  dk_free_tree ((caddr_t) xpp->xpp_expr);
  while (NULL != xpp->xpp_dtd_config_tmp_set)
    dk_free_tree ((box_t) dk_set_pop (&(xpp->xpp_dtd_config_tmp_set)));
#ifdef MALLOC_DEBUG
  dk_check_tree ((caddr_t) xpp->xpp_text);
#endif
  dk_free_box ((caddr_t) xpp->xpp_text);
  dk_free_tree (xpp->xpp_err);
  dk_free_tree (xpp->xpp_err_hdr);
  dk_free (xpp, sizeof (xpp_t));
}

void xp_reject_option_if_not_allowed (xpp_t *xpp, int type)
  {
    if (xpp->xpp_allowed_options & type)
      return;
    switch (type)
      {
      case XP_XPATH_OPTS: xp_error (xpp, "XPATH-specific option listed in '[' ... ']' list before non-XPATH expression");
      case XP_XQUERY_OPTS: xp_error (xpp, "XQUERY-specific option listed in '[' ... ']' list before non-XQUERY expression");
      case XP_FREETEXT_OPTS: xp_error (xpp, "Freetext-specific option listed in '[' ... ']' list before non-freetext expression");
      default: GPF_T;
      }
  }


void xp_register_default_namespace_prefixes (xpp_t *xpp)
{
  xp_register_namespace_prefix (xpp, XFN_NS_PREFIX	, XFN_NS_URI	);
  xp_register_namespace_prefix (xpp, XXF_NS_PREFIX	, XXF_NS_URI	);
  xp_register_namespace_prefix (xpp, XLOCAL_NS_PREFIX	, XLOCAL_NS_URI	);
  xp_register_namespace_prefix (xpp, XOP_NS_PREFIX	, XOP_NS_URI	);
  xp_register_namespace_prefix (xpp, XDT_NS_PREFIX	, XDT_NS_URI	);
  xp_register_namespace_prefix (xpp, XS_NS_PREFIX	, XS_NS_URI	);
  xp_register_namespace_prefix (xpp, XSI_NS_PREFIX	, XSI_NS_URI	);
  xp_register_namespace_prefix (xpp, "xml"		, "xml"		);
}


void xp_register_namespace_prefix (xpp_t *xpp, ccaddr_t ns_prefix, ccaddr_t ns_uri)
{
  dk_set_t *list_ptr = &(xp_env()->xe_namespace_prefixes);
  caddr_t *uri_ptr = dk_set_assoc (list_ptr[0], ns_prefix);
  if (NULL != uri_ptr)
    {
      if (!strcmp (uri_ptr[0], ns_uri))
        return;
      xp_error (xpp, "Namespace prefix has been used already for other namespace URI");
    }
  dk_set_push (list_ptr, (void*) box_dv_uname_string (ns_uri));
  dk_set_push (list_ptr, (void*) box_dv_uname_string (ns_prefix));
}

void xp_register_namespace_prefix_by_xmlns (xpp_t *xpp, ccaddr_t xmlns_attr_name, ccaddr_t ns_uri)
{
  if (!strcmp (xmlns_attr_name, "xmlns"))
    xp_env()->xe_dflt_elt_namespace = box_dv_uname_string (ns_uri);
  else
  if (!strncmp (xmlns_attr_name, "xmlns:", 6))
    xp_register_namespace_prefix (xpp, xmlns_attr_name+6, ns_uri);
  else
    xp_error (xpp, "Invalid attribute name");
}

dk_set_t xp_bookmark_namespaces (xpp_t *xpp)
{
  dk_set_t *list_ptr = &(xp_env()->xe_namespace_prefixes);
  return list_ptr[0];
}

void xp_unregister_local_namespaces (xpp_t *xpp, dk_set_t start_state)
{
  dk_set_t *list_ptr = &(xp_env()->xe_namespace_prefixes);
  while (start_state != list_ptr[0])
    {
      if (NULL == list_ptr[0])
        GPF_T;
      dk_free_tree (dk_set_pop (list_ptr));
      dk_free_tree (dk_set_pop (list_ptr));
    }
}

void xp_set_encoding_option (xpp_t *xpp, caddr_t enc_name)
{
  encoding_handler_t *eh = eh_get_handler (enc_name);
  if (NULL == eh)
    eh = intl_find_user_charset (enc_name, 0);
  if (NULL == eh)
    xp_error (xpp, "Unsupported encoding specified by __enc option");
  xpp->xpp_enc = eh;
}


void xpyyparse (xpp_t *xpp);
void xpyyrestart (FILE *input_file);


ST *
xp_to_sql_tree (sql_comp_t * sc, char * str, caddr_t * err_ret,
		int is_in_sql)
{
  XT * exp;
  xp_ctx_t * xc;
  xp_ret_t xr;
  wcharset_t *query_charset;
  NEW_VAR (xpp_t, xpp);
  NEW_VARZ (xp_env_t, xe);

  memset (xpp, 0, sizeof (xpp_t));
  xpp->xpp_xp_env = xe;
  xpp->xpp_err_hdr = box_dv_short_string ("Select statement as an XPath expression");
  xpp->xpp_text = box_dv_short_string (str);
  xpp->xpp_expn_type = 'p';
  xpp->xpp_lax_nsuri_test = 1;
  xpp->xpp_client = sc->sc_client;

  xe->xe_inside_sql = is_in_sql;
  xe->xe_schema = sc->sc_cc->cc_schema;
  xe->xe_sc = sc;

  query_charset = ((NULL != sc->sc_client) ? sc->sc_client->cli_charset : NULL);
  if (NULL == query_charset)
    query_charset = default_charset;
  if (NULL == query_charset)
    xpp->xpp_enc = &eh__ISO8859_1;
  else
    {
      xpp->xpp_enc = eh_get_handler (CHARSET_NAME (query_charset, NULL));
      if (NULL == xpp->xpp_enc)
	xpp->xpp_enc = &eh__ISO8859_1;
    }

  xpp->xpp_lang = server_default_lh;

  xp_fill_lexem_bufs (xpp);
  if (xpp->xpp_err)
    {
      err_ret[0] = xpp->xpp_err;
      xpp->xpp_err = NULL;
      xpp_free (xpp);
      return NULL;
    }
  if (0 == setjmp (xpp->xpp_reset))
    {
      /* Bug 4566: xpyyrestart (NULL); */
      xpyyparse (xpp);
    }
  if (xpp->xpp_err)
    {
      err_ret[0] = xpp->xpp_err;
      xpp->xpp_err = NULL;
      xpp_free (xpp);
      return NULL;
    }
  xt_check (xpp, xpp->xpp_expr);
  exp = xpp->xpp_expr;

  CATCH (CATCH_XP)
    {
      if (xe->xe_view)
	{
	  ST * sql = xv_top_exp (xpp, exp, err_ret);
	  POP_CATCH;
	  xpp_free (xpp);
	  return sql;
	}
      xc = (xp_ctx_t *) t_alloc_box (sizeof (xp_ctx_t), DV_ARRAY_OF_LONG);
      memset (xc, 0, sizeof (xp_ctx_t));
      xp_sql (xpp, xc, exp, &xr, GM_TOP);
    }
  THROW_CODE
    {
      *err_ret = (caddr_t) THR_ATTR (THREAD_CURRENT_THREAD, TA_XP_RST);
      POP_CATCH;
      xpp_free (xpp);
      return NULL;
    }
  END_CATCH;

  dk_free_box ((caddr_t) xc);
  xpp_free (xpp);
  return (xr.xr_tree);
}

void yyerror (const char *);

/*1.07.02 Alex*/
/* copy lexems (e.g. xmlview......) from some buffers to the new single buffer */
void xp_copy_lexem_bufs (xpp_t * xpp, xp_lexbmk_t *begin, xp_lexbmk_t * end, int skip_last_n)
{
  s_node_t * current_buf;
  xp_lexem_t * new_buf;
  int new_buf_length, current_buf_length, inx, new_buf_counter;
  current_buf = begin->xplb_lexem_bufs_tail;
  if (current_buf == end->xplb_lexem_bufs_tail)
    new_buf_length = (int) (end->xplb_offset - begin->xplb_offset);
  else
    {
      current_buf_length = box_length (current_buf->data) / sizeof (xp_lexem_t);
      new_buf_length=(int) (current_buf_length - begin->xplb_offset);
      current_buf = current_buf->next;
      while (current_buf != end->xplb_lexem_bufs_tail)
        {
          current_buf_length = box_length (current_buf->data) / sizeof (xp_lexem_t);
          new_buf_length += current_buf_length;
          current_buf = current_buf->next;
        }
      new_buf_length += (int) end->xplb_offset;
    }
  new_buf_length -=skip_last_n;
  new_buf = (xp_lexem_t *)dk_alloc_box_zero (sizeof (xp_lexem_t) * new_buf_length, DV_ARRAY_OF_POINTER);
  current_buf = begin->xplb_lexem_bufs_tail;
  inx = (int) begin->xplb_offset;
  current_buf_length = box_length (current_buf->data) / sizeof (xp_lexem_t);
  for (new_buf_counter = 0; new_buf_counter < new_buf_length; new_buf_counter++)
    {
      xp_lexem_t *src, *tgt;
      if (inx == current_buf_length)
        {
          inx = 0;
          current_buf = current_buf->next;
          current_buf_length = box_length (current_buf->data) / sizeof (xp_lexem_t);
        }
      src = ((xp_lexem_t *)(current_buf->data))+inx;
      tgt = new_buf + new_buf_counter;
      tgt[0] = src[0];
      if (NULL != src->xpl_raw_text)
        tgt->xpl_raw_text = box_copy (src->xpl_raw_text);
      if (NULL != src->xpl_sem_value)
        tgt->xpl_sem_value = box_copy_tree (src->xpl_sem_value);
      inx++;
    }
  dk_set_push (&(xpp->xpp_output_lexem_bufs), new_buf);
  xpp->xpp_curr_lexem_bmk.xplb_lexem_bufs_tail = xpp->xpp_output_lexem_bufs;
  xpp->xpp_lexem_buf_len = new_buf_length;
}


XT *
xp_sql_xp_tree (xpp_t * caller_xpp, xp_lexbmk_t *begin, sql_comp_t * sc, caddr_t viewname, caddr_t * err_ret,
		int is_in_sql)
{
  static xp_lexem_t *xp_wrappers = NULL;
  static dk_set_t xp_wrapper_node = NULL;
  static xp_lexbmk_t xp_wrapper0;
  static xp_lexbmk_t xp_wrapper1;
  static xp_lexbmk_t xp_wrapper2;
  /*xp_ctx_t * xc;*/
  int mp_is_local;
  int nonattribute_output;
/*  xp_ret_t xr;*/
  NEW_VAR (xpp_t, xpp);
  NEW_VARZ (xp_env_t, xe);

  memset (xpp, 0, sizeof (xpp_t));
  xpp->xpp_xp_env = xe;
  xpp->xpp_err_hdr = box_dv_short_string ("Select statement as an XPath expression");
  xpp->xpp_text = box_copy (caller_xpp->xpp_text);

  xe->xe_inside_sql = is_in_sql;
  xe->xe_after_xmlview = 1;
  xe->xe_schema = sc->sc_cc->cc_schema;
  xe->xe_sc = sc;

  xpp->xpp_enc = caller_xpp->xpp_enc;
  xpp->xpp_lang = caller_xpp->xpp_lang;
  xpp->xpp_xp2sql_params = NULL;

  if (NULL == xp_wrappers)
    {
      xp_wrappers = (xp_lexem_t *) dk_alloc_box_zero (2*sizeof(xp_lexem_t), DV_ARRAY_OF_POINTER);
      xp_wrappers[0].xpl_lex_value = START_OF_XP_TEXT;
      xp_wrappers[1].xpl_lex_value = END_OF_XPSCN_TEXT;
      dk_set_push (&xp_wrapper_node, (void *)(xp_wrappers));
      xp_wrapper0.xplb_lexem_bufs_tail = xp_wrapper_node;
      xp_wrapper1.xplb_lexem_bufs_tail = xp_wrapper_node;
      xp_wrapper2.xplb_lexem_bufs_tail = xp_wrapper_node;
      xp_wrapper0.xplb_offset = 0;
      xp_wrapper1.xplb_offset = 1;
      xp_wrapper2.xplb_offset = 2;
    }

  xp_copy_lexem_bufs (xpp, &xp_wrapper1, &xp_wrapper2, 0);
  xp_copy_lexem_bufs (xpp, begin, &(caller_xpp->xpp_curr_lexem_bmk), 1);
  xp_copy_lexem_bufs (xpp, &xp_wrapper0, &xp_wrapper1, 0);

  xe->xe_view = xmls_view_def (viewname);
  xe->xe_outputxml = 1; /* to output xml document from xquery.*/
  if (THR_TMP_POOL == NULL)
    {
      mp_is_local = 1;
      SET_THR_TMP_POOL (mem_pool_alloc ());
    }
  else
    mp_is_local = 0;

  if (0 == setjmp (xpp->xpp_reset))
    {
      /* Bug 4566: xpyyrestart (NULL); */
      xpyyparse (xpp); /* parse of xmlview*/
    }
  xt_check (xpp, xpp->xpp_expr);
  if (xpp->xpp_err)
    {
      err_ret[0] = xpp->xpp_err;
      xpp->xpp_err = NULL;
      xpp_free (xpp);
      if (mp_is_local)
	MP_DONE();
      return NULL;
    }

  CATCH (CATCH_XP)
    {
      caddr_t * xp2sql_params = (caddr_t *) dk_set_to_array (xpp->xpp_xp2sql_params); /*parameters in FLWR expression*/
      query_t *qr;
      dk_mem_wrapper_t *qr_mem_wrapper;
      ST * sql;
      XT* xq_xml;
      XT ** xp_delete = &(xpp->xpp_expr);
      for (;;)
        {
          if ((CALL_STMT == xp_delete[0]->type) && (0 == strcmp (xp_delete[0]->_.xp_func.qname, "xmlview")))
            {
	      if (xp_delete[0] == xpp->xpp_expr)
		{
		  xpp->xpp_expr = xp_make_step (xpp, XP_SELF, (XT *) XP_NODE, (XT **)list(0));
		}
	      else
                xp_delete[0] = NULL;
              break;
            }
#ifdef DEBUG
	  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (xp_delete[0]))
	    GPF_T1("internal error in xp_sql_xp_tree");
#endif
          if (XP_STEP == xp_delete[0]->type)
            xp_delete = &(xp_delete[0]->_.step.input);
          else if (XP_FILTER == xp_delete[0]->type)
            xp_delete = &(xp_delete[0]->_.filter.path);
        }

      sql = xv_top_exp (xpp, xpp->xpp_expr, err_ret);
      if (err_ret[0])
        {
          POP_CATCH;
          xpp_free(xpp);
	  if (mp_is_local)
            MP_DONE();
          goto error;
        }
      nonattribute_output = xe->xe_nonattribute_output;
      POP_CATCH;
      xpp_free (xpp);
      qr = sql_compile_st (&sql, sc->sc_client, err_ret, sc); /*compilation of xquery without xmlview(...)*/
      if (mp_is_local)
	MP_DONE();
      if (err_ret[0]) goto error;
      qr_mem_wrapper = (dk_mem_wrapper_t *)dk_alloc_box_zero (sizeof (dk_mem_wrapper_t), DV_MEM_WRAPPER);
      qr_mem_wrapper->dmw_free = (dk_free_box_trap_cbk_t) qr_free;
      qr_mem_wrapper->dmw_data[0] = qr;
      xq_xml = xtlist (
	caller_xpp, 10, XQ_FOR_SQL,
	qr_mem_wrapper,				/* qr_mem_wrapper		*/
	NULL,					/* qr_for_count_mem_wrapper	*/
        xp2sql_params,				/* xp2sql_params                */
	xe_new_xqst (caller_xpp, XQST_REF),	/* xp2sql_values		*/
	xe_new_xqst (caller_xpp, XQST_INT),	/* lc				*/
	xe_new_xqst (caller_xpp, XQST_REF),	/* lc_mem_wrapper		*/
	xe_new_xqst (caller_xpp, XQST_INT),	/* lc_state			*/
	xe_new_xqst (caller_xpp, XQST_REF),	/* current			*/
	xe_new_xqst (caller_xpp, XQST_INT)	/* inx				*/
	);
      if (nonattribute_output)
	{
#if 0
	  XT * call_stmt = xp_make_call (caller_xpp, box_dv_uname_string("document-literal"), list (3, xq_xml, NULL, (ptrlong)GE_XML));
	  XT * child_step = xp_make_step (caller_xpp, XP_CHILD, (XT *) XP_NODE, NULL);
	  return xp_path (caller_xpp, call_stmt, child_step, 0);
#else
	  XT * child_step = xp_make_step (caller_xpp, XP_CHILD, (XT *) XP_NODE, NULL);
	  return xp_path (caller_xpp, xq_xml, child_step, 0);
#endif
	}
      else
	return xq_xml;
error:
      ;
    }
  THROW_CODE
    {
      *err_ret = (caddr_t) THR_ATTR (THREAD_CURRENT_THREAD, TA_XP_RST);
      POP_CATCH;
      xpp_free (xpp);
      if (mp_is_local)
	MP_DONE();
    }
  END_CATCH;
  return NULL;
}

XT *
xp_embedded_xmlview (xpp_t *caller_xpp, xp_lexbmk_t *begin, XT * xp)
{
  caddr_t err = NULL;
  XT * tree;
  XT * xp_tmp = xp;
  caddr_t viewname;
  caddr_t normalized_viewname;
  /*  check is it xmlview function? */
  while (XP_STEP == xp_tmp->type)
    {
      XT * xp_origin = xp_tmp->_.step.input;
      if (NULL == xp_origin)
	break;
      xp_tmp = xp_origin;
    }
  if (NULL == caller_xpp->xpp_client)
    {
      if (NULL != caller_xpp->xpp_sql_columns)
        {
          caller_xpp->xpp_dry_run = 1; /* Can't precompile a query with xmlview() because it can re-enter SQL compiler. */
          return xp;
        }
      xp_error (caller_xpp, "XML views can not be used in XSLT path");
    }
  if ((CALL_STMT == xp_tmp->type) && (0 == strcmp (xp_tmp ->_.xp_func.qname, "xmlview")))
    {
      comp_context_t cc;
      sql_comp_t sc;
      query_t * volatile qr;
      DK_ALLOC_QUERY (qr);
      memset (&sc, 0, sizeof (sc));
      CC_INIT (cc, caller_xpp->xpp_client);
      sc.sc_cc = &cc;
      sc.sc_store_procs = 0;
      sc.sc_text = "";
      sc.sc_client = caller_xpp->xpp_client;
      cc.cc_query = qr;

      xp_tmp = xp_tmp->_.xp_func.argtrees[0];
      if (XP_LITERAL == xp_tmp->type)
        {
          caddr_t val = xp_tmp->_.literal.val;
          dtp_t val_dtp = DV_TYPE_OF (val);
          if (is_string_type (val_dtp))
             viewname = val;       /* viewname is name of xml view*/
          else return xp;
        }
      else return xp;
      normalized_viewname = xp_xml_view_name (caller_xpp, viewname, NULL, NULL);
      if (NULL == xmls_view_def (normalized_viewname))
	xp_error (caller_xpp, "Unknown view name is passed as argument of xmlview()");
      tree = xp_sql_xp_tree (caller_xpp, begin, &sc, normalized_viewname, &err, 1); /*modification of xquery tree*/

    }
  else
    return xp;
  if (err)
    {
      xp_error (caller_xpp, ERR_MESSAGE (err));
    }
  return tree;
}
/*end 1.07.02 Alex*/

int
xp_debug_col (sql_comp_t * sc, comp_table_t * ct, ST * tree, char * text, size_t tlen, int * fill)
{
  if (DV_UNAME == DV_TYPE_OF (tree))
    {
      sprintf_more (text, tlen, fill, " %s ", (caddr_t) tree);
      return 1;
    }
  if (ST_COLUMN (tree, COL_DOTTED))
    {
      sprintf_more (text, tlen, fill, " %s.%s ", tree->_.col_ref.prefix, tree->_.col_ref.name);
      return 1;
    }
  else if (ST_P (tree, TABLE_DOTTED))
    {
      sprintf_more (text, tlen, fill, " %s %s ", tree->_.table.name, tree->_.table.prefix);
      return 1;
    }
  return 0;
}


void
xp_debug (sql_comp_t * sc, char * str, ST * tree, caddr_t *err_ret)
{
  int f = 0;
  int * fill = &f;
  char text[MAX_REMOTE_TEXT_SZ];
  CATCH (CATCH_LISP_ERROR)
  {
    sqlc_target_rds (local_rds);
    sc->sc_exp_print_hook = xp_debug_col;
    sqlc_exp_print (sc, NULL, tree, text, sizeof (text), fill);
    sc->sc_exp_print_hook = NULL;
    printf ("\n\n%s -> \n   %s\n", str, text);
  }
  THROW_CODE
  {
    *err_ret = (caddr_t) THR_ATTR (THREAD_CURRENT_THREAD, TA_SQLC_ERROR);
    if (!*err_ret)
      *err_ret = srv_make_new_error ("42000", "SQ075", "Unclassified SQL XPATH compilation error.");
  }
  END_CATCH;
}


int
sqlc_xpath (sql_comp_t * sc, char * str, caddr_t * err_ret)
{
  if (
    (strstr (str, "EXEC SQL XPATH") == str) ||
    (strstr (str, "EXEC SQL xpath") == str) ||
    (strstr (str, "EXEC SQL XPath") == str))
    {
      parse_tree = xp_to_sql_tree (sc, str, err_ret, 0);
      if (!err_ret)
	xp_debug (sc, str, parse_tree, err_ret);
      return 1;
    }
  else
    return 0;
}


ST *
sqlc_embedded_xpath (sql_comp_t * sc, char * str, caddr_t * err_ret)
{
  ST * tree;
  tree = xp_to_sql_tree (sc, str, err_ret, 1);
  if (!*err_ret)
    xp_debug (sc, str, tree, err_ret);
  if (!tree)
    yyerror ("syntax error in embedded XPATH");
  return tree;
}


#ifdef OLD_VXML_TABLES
void
xp_comp_init (void)
{
  caddr_t err;
  fixed_doc = (caddr_t) sql_compile_static (fixed_doc_text,
				     bootstrap_cli, &err, SQLC_DEFAULT);
  wildcard_doc = (caddr_t) sql_compile_static (wildcard_doc_text,
					bootstrap_cli, &err, SQLC_DEFAULT);
}
#endif

caddr_t *
xpt_combine (int op, caddr_t *left, caddr_t *right)
{
  if (!left)
    return right;
  if (!right)
    return left;
  else
    {
      ptrlong left_flags = ((ptrlong *)left)[1];
      ptrlong right_flags = ((ptrlong *)right)[1];
      return (caddr_t *)list (4, op, (left_flags|right_flags), left, right);
    }
}

void
xpt_edit_range_flags (caddr_t *tree, ptrlong and_mask, ptrlong or_mask)
{
  ptrlong op = ((ptrlong *)tree)[0];
  ptrlong *range_flags_ptr = ((ptrlong *)tree)+1;
  switch (op)
    {
    case BOP_AND:
    case SRC_NEAR:
    case BOP_OR:
    case SRC_WORD_CHAIN:
    case XP_AND_NOT:
      {
	size_t inx, tree_elems = BOX_ELEMENTS (tree);
	for (inx = 2; inx < tree_elems; inx++)
	  {
	    xpt_edit_range_flags ((caddr_t *) tree[inx], and_mask, or_mask);
	  }
      }
      /* no break */
    case SRC_WORD:
      range_flags_ptr[0] = ((range_flags_ptr[0] & and_mask) | or_mask);
      break;
    default:
      GPF_T1 ("bad text-search operation in sst_from_tree");
    }
}


static caddr_t *
xpt_node_test (XT * node, char intro, ptrlong range_flags)
{
  char tmp[MAX_XML_QNAME_LENGTH+10];
  if (!ARRAYP (node))
    return NULL;
  switch (node->type)
    {
    case XP_NAME_EXACT:
      sprintf (tmp, "%c%s", intro, node->_.name_test.qname);
      return ((caddr_t *)list (3, SRC_WORD, range_flags, box_dv_short_string (tmp)));
    case XP_NAME_NSURI:
      sprintf (tmp, "%c%s:*", intro,  node->_.name_test.nsuri);
      return ((caddr_t *)list (3, SRC_WORD, range_flags, box_dv_short_string (tmp)));
    case XP_NAME_LOCAL:
      return NULL;
    default: GPF_T;
    }
  return NULL;
}


caddr_t *
xpt_add_tag_name (caddr_t * phrase, XT * node)
{
  caddr_t * start = xpt_node_test (node, '<', (SRC_RANGE_MAIN | SRC_RANGE_WITH_NAME_IN));
  if (start)
    {
      caddr_t * end = xpt_node_test (node, '/', (SRC_RANGE_MAIN | SRC_RANGE_WITH_NAME_IN));
      int n_words = ((SRC_WORD == (ptrlong) phrase[0]) ? 1 : (BOX_ELEMENTS (phrase) - 2));
      caddr_t * p2 = (caddr_t *) dk_alloc_box (
	sizeof (caddr_t) * (1/*operation*/+1/*flags*/+1/*<tag>*/+n_words+1/*</tag>*/),
	DV_ARRAY_OF_POINTER);
      p2[0] = (caddr_t) SRC_WORD_CHAIN;
      p2[1] = (caddr_t) (SRC_RANGE_MAIN | SRC_RANGE_WITH_NAME_IN);
      p2[2] = (caddr_t) start;
      p2[2+n_words+1] = (caddr_t) end;
      if (1 == n_words)
	p2[2+1] = (caddr_t) phrase;
      else
	{
	  int inx;
	  for (inx = 0; inx < n_words; inx++)
	    p2[2+1+inx] = phrase[2+inx];
	  dk_free_box ((caddr_t) phrase);
	}
      return p2;
    }
  return phrase;
}

caddr_t *
xpt_add_attr_name (caddr_t * phrase, XT * node)
{
  caddr_t * start = xpt_node_test (node, '{', (SRC_RANGE_ATTR | SRC_RANGE_WITH_NAME_IN));
  if (start)
    {
      caddr_t * end = xpt_node_test (node, '}', (SRC_RANGE_ATTR | SRC_RANGE_WITH_NAME_IN));
      int n_words = ((SRC_WORD == (ptrlong) phrase[0]) ? 1 : (BOX_ELEMENTS (phrase) - 2));
      caddr_t * p2 = (caddr_t *) dk_alloc_box (
	sizeof (caddr_t) * (1/*operation*/+1/*flags*/+1/*<tag>*/+n_words+1/*</tag>*/),
	DV_ARRAY_OF_POINTER);
      p2[0] = (caddr_t) SRC_WORD_CHAIN;
      p2[1] = (caddr_t) (SRC_RANGE_ATTR | SRC_RANGE_WITH_NAME_IN);
      p2[2] = (caddr_t) start;
      p2[2+n_words+1] = (caddr_t) end;
      if (1 == n_words)
	p2[2+1] = (caddr_t) phrase;
      else
	{
	  int inx;
	  for (inx = 0; inx < n_words; inx++)
	    p2[2+1+inx] = phrase[2+inx];
	  dk_free_box ((caddr_t) phrase);
	}
      return p2;
    }
  return phrase;
}

lang_handler_t *
xpt_lhptr (caddr_t lhptr)
{
  ptrlong x = unbox_ptrlong (lhptr);
  return ((lang_handler_t *)x);
}

caddr_t *
xpt_eq (XT * tree, XT * ctx_step)
{
  XT * node = NULL;
  XT * left = tree->_.bin_exp.left;
  XT * right = tree->_.bin_exp.right;
  caddr_t * word_or_phrase;
  if (left->type == XP_LITERAL && DV_STRINGP (left->_.literal.val))
    {
      XT * tmp = right;
      right = left;
      left = tmp;
    }
  if ((right->type != XP_LITERAL) || (!DV_STRINGP (right->_.literal.val))
      || (XP_STEP != left->type))
    return NULL;
  if (left->_.step.axis == XP_SELF)
    node = ctx_step;
  else
    node = left->_.step.node;
  if (XP_ATTRIBUTE == left->_.step.axis)
    {
      word_or_phrase = xp_word_or_phrase_from_string (NULL /* no xp_error */, right->_.literal.val, &eh__UTF8, xpt_lhptr (right->_.literal.lhptr), 0);
      if (NULL == word_or_phrase)
	return NULL;
      xpt_edit_range_flags ((caddr_t *)(word_or_phrase), ~SRC_RANGE_DUMMY, SRC_RANGE_ATTR);
      return (xpt_add_attr_name ((caddr_t *) word_or_phrase, node));
    }
  if (!(ARRAYP(node) || ((XT *)XP_TEXT == node) || ((XT *)XP_STAR == node) || ((XT *)XP_ELT == node) || ((XT *)XP_ELT_OR_ROOT == node)))
    return NULL;
  word_or_phrase = xp_word_or_phrase_from_string (NULL /* no xp_error */, right->_.literal.val, &eh__UTF8, xpt_lhptr (right->_.literal.lhptr), 0);
  if (NULL == word_or_phrase)
    return NULL;
  xpt_edit_range_flags (word_or_phrase, ~SRC_RANGE_DUMMY, SRC_RANGE_MAIN);
  return (xpt_add_tag_name (word_or_phrase, node));
}


ptrlong xpt_range_flags_of_step (XT *tree, XT* ctx_node)
{
  if (! ST_P (tree, XP_STEP))
    return 0;
  switch (tree->_.step.axis)
  {
    case XP_ATTRIBUTE: case XP_ATTRIBUTE_WR:
      return SRC_RANGE_ATTR;
    case XP_SELF:
    case XP_CHILD: case XP_CHILD_WR:
    case XP_DESCENDANT: case XP_DESCENDANT_WR:
    case XP_DESCENDANT_OR_SELF: case XP_DESCENDANT_OR_SELF_WR:
      return SRC_RANGE_MAIN;
    case XP_ABS_DESC: case XP_ABS_DESC_WR:
    case XP_ABS_DESC_OR_SELF: case XP_ABS_DESC_OR_SELF_WR:
    case XP_ABS_CHILD: case XP_ABS_CHILD_WR:
      if (NULL == ctx_node)
	return SRC_RANGE_MAIN;
      return SRC_RANGE_OUTSIDE_WR;
  }
  return 0;
}


caddr_t *
xpt_call (XT * tree)
{
  int inx;
  caddr_t * in = NULL;
/* UNSAFE here!
  DO_BOX (XT *, arg, inx, tree->_.xp_func.args)
    {
      in = xpt_combine (BOP_AND, in, xpt_text_exp (arg, NULL));
    }
  END_DO_BOX;
*/
  if (0 == stricmp (tree->_.xp_func.qname, "text-contains"))
    {
      caddr_t err = NULL;
      int argcount = (int) tree->_.xp_func.argcount;
      XT ** args = tree->_.xp_func.argtrees;
      ptrlong range_type;
      caddr_t * text_tree;
      for (inx = 0; inx < argcount; inx++)
	{
	  XT * arg = args[inx];
	  in = xpt_combine (BOP_AND, in, xpt_text_exp (arg, NULL));
	}
      range_type = xpt_range_flags_of_step (args[0], tree);
      if (range_type & SRC_RANGE_ATTR)
	sqlr_new_error ("XP370", "XT014", "First attribute of text-contains cannot be value of attribute");
      if (0 == range_type)
	return in;
      if (! ST_P (args[1], XP_LITERAL))
	return in; /* literal expected as the second argument */
      if (! DV_STRINGP (args[1]->_.literal.val))
	return in;
      text_tree = xp_text_parse (args[1]->_.literal.val, &eh__UTF8, xpt_lhptr (args[1]->_.literal.lhptr), NULL /* no runtime options */, &err);
      if (err)
	dk_free_tree (err);
      if (NULL != text_tree)
	{
	  xpt_edit_range_flags (text_tree, ~(SRC_RANGE_DUMMY), range_type);
	  in = xpt_combine (BOP_AND, in, text_tree);
	}
    }
  return in;
}


caddr_t *
xpt_text_exp (XT * tree, XT* ctx_node)
{
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    return NULL;
  switch (tree->type)
    {
    case XP_LITERAL:
    case BOP_NOT:
      return NULL;
    case XP_STEP:
      {
	caddr_t * in;
	ptrlong flags = xpt_range_flags_of_step (tree, ctx_node);
	switch (flags & (SRC_RANGE_MAIN | SRC_RANGE_ATTR))
	  {
	  case SRC_RANGE_MAIN:
	    in = xpt_combine (BOP_AND, xpt_node_test (tree->_.step.node, '<', (SRC_RANGE_MAIN | SRC_RANGE_WITH_NAME_IN)),
		xpt_text_exp (tree->_.step.input, NULL));
	    break;
	  case SRC_RANGE_ATTR:
	    in = xpt_combine (BOP_AND, xpt_node_test (tree->_.step.node, '{', (SRC_RANGE_ATTR | SRC_RANGE_WITH_NAME_IN)),
		xpt_text_exp (tree->_.step.input, NULL));
	    break;
	  default:
	    in = NULL;
	    break;
	  }
	if (tree->_.step.preds)
	  {
	    int inx;
	    DO_BOX (XT *, pred, inx, tree->_.step.preds)
	      {
		in = xpt_combine (BOP_AND, in, xpt_text_exp (pred->_.pred.expr, tree->_.step.node));
	      }
	    END_DO_BOX;
	  }
	return in;
      }
    case BOP_OR:
    case XP_UNION:
      return (xpt_combine (BOP_OR, xpt_text_exp (tree->_.xp_union.left, ctx_node),
			   xpt_text_exp (tree->_.xp_union.right, ctx_node)));
    case XP_FILTER:
      return (xpt_combine (BOP_AND, xpt_text_exp (tree->_.filter.path, NULL),
			   xpt_text_exp (tree->_.filter.pred, NULL)));
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
    case BOP_AND: case BOP_GT: case BOP_GTE: case BOP_LT: case BOP_LTE:
    case BOP_NEQ:
      return (xpt_combine (BOP_OR, xpt_text_exp (tree->_.bin_exp.left, ctx_node),
			   xpt_text_exp (tree->_.bin_exp.right, ctx_node)));
    case BOP_EQ:
      return (xpt_eq (tree, ctx_node));
    case CALL_STMT:
      return (xpt_call (tree));
    case XQ_QUERY_MODULE:
      return xpt_text_exp (tree->_.module.body, ctx_node);
    default:
      return NULL;
    }
}


caddr_t *
xp_text_parse (char * str2, encoding_handler_t *enc, lang_handler_t *lang, caddr_t *ret_dtd_config, caddr_t * err_ret)
{
  caddr_t * exp;
  xpp_t *xpp;
  if (NULL == str2)
    {
      err_ret[0] = srv_make_new_error ("22023", "FT041" , "text criteria is NULL, maybe the value is required before it is calculated");
      return NULL;
    }
  if (DV_WIDESTRINGP(str2))
    enc = &eh__WIDE_121;
  else if (DV_STRINGP(str2))
    {
      if (box_flags(str2) & (BF_IRI | BF_UTF8))
        enc = &eh__UTF8;
    }
  else
    {
      err_ret[0] = srv_make_new_error ("22023", "FT042" , "text criteria is not a string");
      return NULL;
    }
  xpp = (xpp_t *)dk_alloc (sizeof (xpp_t));
  memset (xpp, 0, sizeof (xpp_t));
  xpp->xpp_err_hdr = box_dv_short_string ("Free-text expression");
  xpp->xpp_text = box_dv_short_string (str2);
  xpp->xpp_expn_type = 't';
  xpp->xpp_enc = enc;
  xpp->xpp_lang = lang;
  xp_fill_lexem_bufs (xpp);
  if (NULL != xpp->xpp_err)
    {
      err_ret[0] = xpp->xpp_err;
      xpp->xpp_err = NULL;
      xpp_free (xpp);
      return NULL;
    }
  if (0 == setjmp (xpp->xpp_reset))
    {
      /* Bug 4566: xpyyrestart (NULL); */
      xpyyparse (xpp);
    }
  else
    {
      xt_check (xpp, xpp->xpp_expr);
      err_ret[0] = xpp->xpp_err;
      xpp->xpp_err = NULL;
      xpp_free (xpp);
      return NULL;
    }
  xt_check (xpp, xpp->xpp_expr);
  exp = (caddr_t *)xpp->xpp_expr;
  xpp->xpp_expr = NULL;
  if (NULL != ret_dtd_config)
    {
      xpp->xpp_dtd_config_tmp_set = dk_set_nreverse (xpp->xpp_dtd_config_tmp_set);
      ret_dtd_config[0] = list_to_array (xpp->xpp_dtd_config_tmp_set);
      xpp->xpp_dtd_config_tmp_set = NULL;
    }
  xpp_free (xpp);
  return ((caddr_t *) exp);
}


void xp_env_push (xpp_t *xpp, char *context_type, char *obj_name, int copy_static_context)
{
  xp_env_t *parent_xe = xpp->xpp_xp_env;
  NEW_VARZ (xp_env_t, xe);
  xe->xe_for_interp = xp_env()->xe_for_interp;
  xe->xe_xqr = (xp_query_t *) dk_alloc_box_zero (sizeof (xp_query_t), DV_XPATH_QUERY);
  xe->xe_xqst_ctr = (sizeof (xp_instance_t) / sizeof (caddr_t)) + 1;
  xe->xe_parent_env = parent_xe;
  xpp->xpp_xp_env = xe;
  if (copy_static_context)
    {
      xe->xe_namespace_prefixes = xe->xe_namespace_prefixes_outer = parent_xe->xe_namespace_prefixes;
      xe->xe_dflt_elt_namespace = parent_xe->xe_dflt_elt_namespace;
      xe->xe_dflt_fn_namespace = parent_xe->xe_dflt_fn_namespace;
      xe->xe_collation_uris = xe->xe_collation_uris_outer = parent_xe->xe_collation_uris;
      xe->xe_dflt_collation = parent_xe->xe_dflt_collation;
      xe->xe_base_uri = parent_xe->xe_base_uri;
      xe->xe_schemas = xe->xe_schemas_outer = parent_xe->xe_schemas;
      xe->xe_modules = xe->xe_modules_outer = parent_xe->xe_modules;
    }
}


void xp_env_pop (xpp_t *xpp)
{
  xp_env_t *xe = xp_env();
  xp_env_t *parent = xe->xe_parent_env;
  xe->xe_parent_env = NULL;
  xe_free (xe);
  xpp->xpp_xp_env = parent;
}


XT *xp_make_module (xpp_t *xpp, caddr_t ns_prefix, caddr_t ns_uri, XT * expn)
{
  caddr_t context = list (2, box_dv_uname_string ("module-namespace-uri"), ns_uri);
  XT **fundefs = (XT **)list_to_array (xpp->xpp_local_fundefs);
  XT **defglobals = (XT **)list_to_array (NCONC (xpp->xpp_global_vars_external, dk_set_nreverse (xpp->xpp_global_vars_preset)));
  XT *res;
#ifdef MALLOC_DEBUG
  dk_check_tree (fundefs);
#endif
  xpp->xpp_local_fundefs = NULL;
  xpp->xpp_global_vars_preset = NULL;
  xpp->xpp_global_vars_external = NULL;
  res = xtlist (xpp, 7, XQ_QUERY_MODULE,
      context,
      copy_list_to_array (xpp->xpp_xp_env->xe_schemas),
      copy_list_to_array (xpp->xpp_xp_env->xe_modules),
      fundefs,
      defglobals,
      expn );
  return res;
}

void xp_import_schema (xpp_t *xpp, caddr_t ns_prefix, caddr_t ns_uri, caddr_t *at_hints)
{
  caddr_t sch_uri;
  shuric_t *shu;
  caddr_t err = NULL;
  if (0 < BOX_ELEMENTS(at_hints))
    sch_uri = box_copy (at_hints[0]);
  else if (!strncmp (ns_uri, "http://", 7))
    sch_uri = box_sprintf (1000, "%.300s%sdefault.xsd", ns_uri, (('/' == ns_uri[strlen(ns_uri)-1]) ? "" : "/"));
  else
    sch_uri = box_dv_short_string (ns_uri);
  if (NULL == xpp->xpp_qi)
    {
      xpp->xpp_err = srv_make_new_error ("37XQR", "SQ196", "Unable to retrieve '%.1000s' from SQL compiler due to danger of fatal deadlock", sch_uri);
      longjmp (xpp->xpp_reset, 1);
    }
  shu = shuric_load_xml_by_qi (xpp->xpp_qi, xpp->xpp_uri, sch_uri,
    &err, xp_env ()->xe_xqr->xqr_shuric, &shuric_vtable__xmlschema, "XQuery compiler" );
  if (NULL != err)
    {
      char buf[2000];
      snprintf_ck (buf, sizeof(buf), "XML Schema loading has failed: %s", ERR_MESSAGE (err));
      dk_free_tree (err);
      xp_error (xpp, buf);
    }
  dk_set_push (&xp_env ()->xe_schemas, box_num((ptrlong)shu));
  dk_set_push (&xp_env ()->xe_schemas, box_dv_short_string (ns_uri));
  shuric_release (shu);
}


void xp_import_module (xpp_t *xpp, caddr_t ns_prefix, caddr_t ns_uri, caddr_t *at_hints)
{
  caddr_t uri;
  xp_env_t *xe = xpp->xpp_xp_env;
  caddr_t err = NULL;
/* "i_..." stands for "import_..." */
  shuric_t *i_shuric = NULL;
  if (0 < BOX_ELEMENTS(at_hints))
    uri = box_copy (at_hints[0]);
  else if (!strncmp (ns_uri, "http://", 7))
    uri = box_sprintf (1000, "%.300s%sdefault.xq", ns_uri, (('/' == ns_uri[strlen(ns_uri)-1]) ? "" : "/"));
  else
    uri = box_dv_short_string (ns_uri);
  dk_set_push (&(xpp->xpp_preamble_decls), xtlist (xpp, 4, XQ_IMPORT_MODULE, box_dv_short_string (ns_prefix), box_dv_short_string (ns_uri), at_hints));
  if (NULL == xpp->xpp_qi)
    err = srv_make_new_error ("37XQR", "SQ196",
	"Unable to retrieve '%.1000s' from SQL compiler due to danger of fatal deadlock", uri);
  else
    i_shuric = xqr_shuric_retrieve (xpp->xpp_qi, uri, &err, xe->xe_xqr->xqr_shuric);
  if (NULL != err)
    {
      if (NULL != xpp->xpp_sql_columns)
        {
          xpp->xpp_dry_run = 1;
          return;
	}
      /* xp_resignal () :) */
      xpp->xpp_err = err;
      longjmp (xpp->xpp_reset, 1);
    }
  dk_set_push (&xp_env ()->xe_modules, box_num((ptrlong)i_shuric));
  dk_set_push (&xp_env ()->xe_modules, box_dv_short_string (ns_uri));
  shuric_release (i_shuric);
}


void xp_var_decl (xpp_t *xpp, caddr_t var_name, XT *var_type, XT *init_expn)
{
  DO_SET (XT *, decl, &(xpp->xpp_global_vars_external))
    {
      if (!strcmp (decl->_.defglobal.name, var_name))
	xp_error (xpp, "Variable with same name is already declared by 'declare variable ... external'");
    }
  END_DO_SET ()
  DO_SET (XT *, decl, &(xpp->xpp_global_vars_preset))
    {
      if (!strcmp (decl->_.defglobal.name, var_name))
	xp_error (xpp, "Variable with same name is already declared by 'declare variable ... := <expression>'");
    }
  END_DO_SET ()
  dk_set_push (
    ((NULL == init_expn) ? (&(xpp->xpp_global_vars_external)) : (&(xpp->xpp_global_vars_preset))),
    xtlist (xpp, 5, XQ_DEFGLOBAL, var_name, var_type, init_expn, xe_new_xqst (xpp, XQST_REF)) );
}


XT *xp_make_typeswitch (xpp_t *xpp, XT *src, dk_set_t typecases, XT **dflt)
{
  int argctr = 1 + (dk_set_length (typecases) + 1) * 3;
  XT **arglist = dk_alloc_box (argctr * sizeof (XT *), DV_ARRAY_OF_POINTER);
  memcpy (arglist + (argctr - 3), dflt, 3 * sizeof (XT *));
  argctr -= 3;
  DO_SET (XT **, typecase, &typecases)
    {
      memcpy (arglist + (argctr - 3), typecase, 3 * sizeof (XT *));
      argctr -= 3;
    }
  END_DO_SET()
  arglist [--argctr] = src;
#ifdef DEBUG
  if (argctr != 0)
    GPF_T;
#endif
  return xp_make_call (xpp, box_dv_uname_string("TYPESWITCH operator"), (caddr_t)arglist);
}


XT *xp_make_name_test_from_qname (xpp_t *xpp, caddr_t qname, int qname_is_expanded)
{
  char *colon;
  caddr_t ns_uri, lname, fullname;
  ptrlong op;
  if (('(' == qname[0]) && !qname_is_expanded)
    {
      int len = strlen (qname);
      if ((4 < len) && ('!' == qname [1]) && ('!' == qname [len-2]) && (')' == qname [len-1]))
        {
          fullname = box_dv_uname_nchars (qname + 2, len - 4);
	  colon = strrchr (fullname, ':');
	  if (NULL == colon)
            return xtlist (xpp, 4, XP_NAME_EXACT, NULL, box_copy (fullname), fullname);
          else
            return xtlist (xpp, 4, XP_NAME_EXACT,
              box_dv_uname_nchars (qname, colon - fullname),
              box_dv_uname_string (colon + 1), fullname);
	}
    }
  colon = strrchr (qname, ':');
  op = ((NULL == colon) && !qname_is_expanded && xpp->xpp_lax_nsuri_test) ? XP_NAME_LOCAL : XP_NAME_EXACT;
  if (NULL == colon)
      {
        lname = box_copy (qname);
        ns_uri = NULL; /* default namespace has no effect on name tests, so no xp_namespace_pref (xpp_arg, NULL) */
        fullname = box_copy (lname);
      }
  else
      {
        lname = box_dv_uname_string (colon + 1);
        ns_uri = (qname_is_expanded ? box_dv_uname_nchars (qname, colon-qname) : xp_namespace_pref_cname (xpp, qname));
        BOX_DV_UNAME_COLONCONCAT (fullname, ns_uri, lname);
      }
  return xtlist (xpp, 4, op, ns_uri, lname, fullname);
}


XT *xp_make_seq_type (xpp_t *xpp, ptrlong first_token, caddr_t top_name, XT *type, ptrlong is_nilable, ptrlong n_occurrences)
{
  ptrlong mode = -1; /* Fake value */
  caddr_t type_ns_uri = NULL;
  shuric_t *schema_shu = NULL;
  schema_parsed_t *schema = NULL;
  caddr_t component_name = NULL;
  int dict_to_search = XS_SP_TYPES;
  xs_component_t *comp = NULL;
  XT *res;
/*
      ptrlong	mode;
      caddr_t   name;
      xs_component_t **type;
      ptrlong	is_nillable;
      ptrlong	occurrences;
*/
  switch (first_token)
    {
    case XQCNAME:
      component_name = xp_make_expanded_name (xpp, (caddr_t)type, 0);
      mode = 0; break;
    case DOCUMENT_NODE_LPAR_L:
      mode = XQ_SEQTYPE_DOCELEMENT; break;
    case ATTRIBUTE_LPAR_L:
      if (top_name)
        top_name = xp_make_expanded_name (xpp, top_name, 1);
      component_name = ((NULL != type) ? xp_make_expanded_name (xpp, (caddr_t)type, 0) : NULL /* not top_name */);
      mode = XQ_SEQTYPE_ATTRIBUTE; break;
    case SCHEMA_ATTRIBUTE_LPAR_L:
      top_name = xp_make_expanded_name (xpp, top_name, 1);
      dict_to_search = XS_SP_ATTRS;
      component_name = top_name;
      mode = XQ_SEQTYPE_ATTRIBUTE; break;
    case PI_LPAR_L:
      mode = XQ_SEQTYPE_PI; break;
    case COMMENT_LPAR_L:
      mode = XQ_SEQTYPE_NODE; top_name = (caddr_t)XP_COMMENT; break;
    case TEXT_LPAR_L:
      mode = XQ_SEQTYPE_NODE; top_name = (caddr_t)XP_TEXT; break;
    case NODE_LPAR_L:
      mode = XQ_SEQTYPE_NODE; top_name = (caddr_t)XP_NODE; break;
    case ELEMENT_LPAR_L:
      if (top_name)
        top_name = xp_make_expanded_name (xpp, top_name, 0);
      component_name = ((NULL != type) ? xp_make_expanded_name (xpp, (caddr_t)type, 0) : NULL /* not top_name */);
      mode = XQ_SEQTYPE_ELEMENT; break;
    case SCHEMA_ELEMENT_LPAR_L:
      top_name = xp_make_expanded_name (xpp, top_name, 0);
      dict_to_search = XS_SP_ELEMS;
      component_name = top_name;
      mode = XQ_SEQTYPE_ELEMENT; break;
    case ITEM_LPAR_RPAR_L:
      mode = 0; break;
    case EMPTY_LPAR_RPAR_L:
      comp = xs_get_builtinidx (NULL, XMLSCHEMA_NS_URI ":emptyType", NULL, 0);
      mode = 0; break;
    default:
      xp_error (xpp, "Unsupported class of sequence type declaration");
    }
  if (NULL != component_name)
    {
      id_hash_t *dict;
      xs_component_t **dict_entry;
      caddr_t colon = strrchr (component_name, ':');
      caddr_t *schema_shu_addr_ptr;
      if (NULL == colon)
        type_ns_uri = NULL;
      else
        type_ns_uri = box_dv_short_nchars (component_name, colon - component_name);
      schema_shu_addr_ptr = dk_set_assoc (xp_env ()->xe_schemas, type_ns_uri);
      if (NULL == schema_shu_addr_ptr)
        {
          if (NULL == type_ns_uri)
	    xp_error_printf (xpp, "No schema loaded for the default namespace specified by name '%s' in sequence type declaration", component_name);
          if (strcmp (type_ns_uri, XS_NS_URI))
	    xp_error_printf (xpp, "No schema loaded for the namespace '%s' specified by name '%s' in sequence type declaration", type_ns_uri, component_name);
	  if (XS_SP_TYPES != dict_to_search)
	    xp_error_printf (xpp, "No XMLSchema component definition found for name '%s' in sequence type declaration", component_name);
	  comp = xs_get_builtinidx (NULL, component_name, NULL, 0);
	  if ((NULL == comp) && strcmp (component_name + strlen (component_name) - 7, "anyType"))
	    xp_error_printf (xpp, "XMLSchema has no predefined type for name '%s' in sequence type declaration", component_name);
	  goto component_name_resolved;
	}
      schema_shu = (shuric_t *)(unbox_ptrlong (((caddr_t *)schema_shu_addr_ptr)[0]));
      schema = (schema_parsed_t *)(schema_shu->shuric_data);
      dict = schema->sp_hashtables[dict_to_search];
      dict_entry = ((NULL != dict) ? (xs_component_t **) id_hash_get (dict, (caddr_t) &component_name) : NULL);
      if (NULL != dict_entry)
	comp = dict_entry[0];
      else
        {
          if (XS_SP_TYPES == dict_to_search)
	    comp = xs_get_builtinidx (NULL, component_name, NULL, 0);
	}
      if ((NULL == comp) && strcmp (component_name + strlen (component_name) - 7, "anyType"))
	xp_error_printf (xpp, "No XMLSchema component definition found for name '%s' in sequence type declaration", component_name);
    }

component_name_resolved:
  if ((XQ_SEQTYPE_REQ_ONE == n_occurrences) && (NULL == comp))
    { /* Special optimized representations for simple cases */
      if (XQ_SEQTYPE_PI == mode)
        {
	  if (NULL != top_name) return xtlist (xpp, 2, XP_PI, box_copy (top_name));
	  else return (XT *)XP_PI;
	}
      if (XQ_SEQTYPE_NODE == mode)
	{
	  return (XT *)top_name;
	}
      if (XQ_SEQTYPE_ELEMENT == mode)
        if (NULL == top_name)
          return (XT *)XP_ELT;
        return xp_make_name_test_from_qname (xpp, top_name, 1);
    }
  res = xtlist (xpp, 6, XQ_SEQTYPE, mode, box_copy (top_name), box_num ((ptrlong)comp), is_nilable, n_occurrences);
  return res;
}


XT *
xp_make_sqlcolumn_ref (xpp_t *xpp, caddr_t name)
{
  char buf [MAX_QUAL_NAME_LEN + 20];
  if (NULL == xpp->xpp_sql_columns)
    xp_error (xpp, "sql:column() can be used only if the text of the query is the constant string that is the first argument of a direct call of xquery_eval()");
  if (strlen (name) > (MAX_QUAL_NAME_LEN - 2))
    xp_error (xpp, "The column name in sql:column() is too long");
  if (CM_UPPER == case_mode)
    sqlp_upcase (name);
  DO_SET (caddr_t, col, xpp->xpp_sql_columns)
    {
      if (!strcmp (col, name))
        goto xpp_sql_columns_done; /* see below */
    }
  END_DO_SET ()
  dk_set_push (xpp->xpp_sql_columns, box_dv_short_string (name));

xpp_sql_columns_done:
  sprintf (buf, XQ_SQL_COLUMN_FORMAT, name);
  return xp_make_variable_ref (xpp, buf);
}


XT *
xp_make_variable_ref (xpp_t *xpp, caddr_t name)
{

  if (xp_env ()->xe_after_xmlview && ('<' != name[0]))
    {
      char tmp[20];
      dk_set_t * params = &(xpp->xpp_xp2sql_params);
      int parm_inx=1;
      if (xp_env ()->xe_for_interp)
	GPF_T1 ("Must not be XPath interpreter");
      while (params[0])
        {
         if (!strcmp((char *) params[0]->data, name))
           break;
         parm_inx++;
         params = &(params[0]->next);
        }
      if (!params[0])
        dk_set_push(&params[0], box_dv_uname_string(name));
      sprintf (tmp, ":%d", parm_inx);
      return (XT *) box_dv_uname_string(tmp);
    }
  if (!xp_env ()->xe_for_interp)
    return (XT *) box_dv_uname_string(name);
  return xtlist ( xpp, 6,
    XP_VARIABLE, box_dv_uname_string (name), xe_new_xqst (xpp, XQST_INT),
    xe_new_xqst (xpp, XQST_INT), xe_new_xqst (xpp, XQST_REF), xe_new_xqst (xpp, XQST_REF));
}


static caddr_t /* XT ** actually */ xp_make_call_args (xpp_t *xpp, char *name, XT **args)
{
  xp_query_t * xqr;
  xp_env_t * xe = xp_env ();
  xqr = xe->xe_xqr;
  if (0 == stricmp (name, "position"))
    {
      XT * pred = xe->xe_pred_stack ? (XT*) xe->xe_pred_stack->data : NULL;
      if (!pred)
	{
	  if (!xqr)
	    xp_error (xpp, "XPATH position (), last () outside of predicate");
	  if (!xqr->xqr_top_pos)
	    xqr->xqr_top_pos = xe_new_xqst (xpp, XQST_INT);
	  return list (1, xqr->xqr_top_pos);
	}
      if (!pred->_.pred.pos)
	pred->_.pred.pos = xe_new_xqst (xpp, XQST_INT);
      return list (1, pred->_.pred.pos);
    }
  if (0 == stricmp (name, "last"))
    {
      XT * pred = xe->xe_pred_stack ? (XT*) xe->xe_pred_stack->data : NULL;
      if (!pred)
	{
	  if (!xqr)
	    xp_error (xpp, "XPATH position (), last () outside of predicate");
	  if (!xqr->xqr_top_size)
	    xqr->xqr_top_size = xe_new_xqst (xpp, XQST_INT);
	  return list (1, xqr->xqr_top_size);
	}
      if (!pred->_.pred.size)
	pred->_.pred.size = xe_new_xqst (xpp, XQST_INT);
      return list (1, pred->_.pred.size);
    }
  if (0 == stricmp (name, "text-contains"))
    {
      if (!IS_BOX_POINTER (args) || BOX_ELEMENTS ((caddr_t *)args) < 2)
	xp_error (xpp, "text-contains () needs two arguments");

/* Please do not replace box_num((ptrlong)xpp->xpp_lang) with box_copy(xpp->xpp_lang) */
      return list (5, args[0], args[1], NULL, xe_new_xqst (xpp, XQST_REF), box_num((ptrlong)xpp->xpp_lang));
    }
  if (0 == stricmp (name, "function-available"))
    {
      if (!IS_BOX_POINTER (args) || BOX_ELEMENTS ((caddr_t *)args) != 1)
	xp_error (xpp, "function-available () needs a string as argument");
      if ((args[0])->type == XP_LITERAL && DV_STRINGP ((args[0])->_.literal.val))
	{
	  int checked_before = 0;
	  caddr_t ns = (args[0])->_.literal.val;
	  char * nqn = strrchr (ns, ':');
	  if (strlen (ns) > MAX_XML_QNAME_LENGTH)
	    xp_error (xpp, "The string is too long to be a valid argument of function-available () call");
	  if (nqn)
	    {
	      char qname [MAX_XML_QNAME_LENGTH+1];
	      if ((nqn-ns) > MAX_XML_LNAME_LENGTH)
	        xp_error (xpp, "The namespace prefix in the argument of function-available () call is too long");
	      if ((strchr (ns, '\0') - nqn) > MAX_XML_LNAME_LENGTH)
	        xp_error (xpp, "The 'local name' part of the argument of function-available () call is too long");
	      *nqn = 0; nqn++;
	      xp_q_name (xpp, qname, sizeof (qname), ns, nqn, xp_env()->xe_dflt_fn_namespace);
	      dk_free_box (ns);
	      ns = (args[0])->_.literal.val = box_dv_short_string (qname);
	    }
	  if (NULL != xpp->xpp_checked_functions)
	    {
	      DO_SET (caddr_t, checked_name, xpp->xpp_checked_functions)
		{
		  if (!strcmp (ns, checked_name))
		    {
		      checked_before = 1;
		      break;
		    }
		}
	      END_DO_SET()
	      if (!checked_before)
		dk_set_push (xpp->xpp_checked_functions, ns);
	    }
	}
    }
  return (caddr_t)args;
}


#define LOCAL_DAV_HOME "~"

static
caddr_t xp_home_collection (xpp_t * xpp)
{
  if (xpp && xpp->xpp_client && xpp->xpp_client->cli_user)
    {
      char* uname = xpp->xpp_client->cli_user->usr_name;
      char* ptr, *home_path = ptr = dk_alloc_box (strlen (LOCAL_DAV_HOME) + strlen (uname) + 1 /* / sign */ + 1, DV_STRING);
      strcpy (home_path, LOCAL_DAV_HOME);
      ptr += strlen (ptr);
      strcpy (ptr, uname);
      ptr += strlen (ptr);
      ptr[0] = '/'; ptr++; ptr [0] = 0;
      return home_path;
    }
  return NULL;
}

XT *
xp_make_call (xpp_t *xpp, const char *qname, caddr_t arg_array)
{
  char buf[200+MAX_XML_QNAME_LENGTH];
  XT *var = NULL;
  XT *res;
  caddr_t name = box_dv_uname_string (qname);
  xpf_metadata_t **metas_ptr = (xpf_metadata_t **)id_hash_get (xpf_metas, (caddr_t)(&name));
  xpf_metadata_t *metas;
  if ((NULL == metas_ptr) && (NULL == strrchr (name, ':')))
    { /* recovery for dummies that forget 'fn:' or 'xs:' prefix */
      char *buf_as_charptr = buf; /* This is a workaround for gcc 2.96 'feature'. */
      sprintf (buf, "%s:%s", XFN_NS_URI, name);
      metas_ptr = (xpf_metadata_t **)id_hash_get (xpf_metas, (caddr_t)(&buf_as_charptr));
      if (NULL == metas_ptr)
        {
          sprintf (buf, "%s:%s", XS_NS_URI, name);
          metas_ptr = (xpf_metadata_t **)id_hash_get (xpf_metas, (caddr_t)(&buf_as_charptr));
        }
    }
  if (NULL == metas_ptr)
    {
      static char *undef_name = " undefined";
      if (xpp->xpp_dry_run) /* It's possible that the function is defined in module that must be imported but the import is impossible when inside SQL compiler */
        goto substitute_with_undefined;
      if (NULL != xpp->xpp_checked_functions)
	{
	  DO_SET (caddr_t, checked_name, xpp->xpp_checked_functions)
	    {
	      if (!strcmp (name, checked_name))
	        goto substitute_with_undefined;
	    }
	  END_DO_SET()
	}
      sprintf (buf, "Unknown XPATH function '%s'", name);
      xp_error (xpp, buf);

substitute_with_undefined:
      metas_ptr = (xpf_metadata_t **)id_hash_get (xpf_metas, (caddr_t)(&undef_name));
    }
  metas = metas_ptr[0];
  if (NULL == metas->xpfm_executable)
    {
      if (!strcmp ("collection", metas->xpfm_name)
        || !strcmp (XFN_NS_URI ":collection", metas->xpfm_name)
        || !strcmp (XXF_NS_URI ":collection", metas->xpfm_name) )
	{
	  dk_set_t dirlist_args = NULL, doc_args = NULL;
	  int ctr = BOX_ELEMENTS (arg_array);
	  char * home_path;
	  if (ctr == 0 && (home_path = xp_home_collection (xpp)))
	    dk_set_push (&dirlist_args, xp_make_literal_tree (xpp, home_path, 0));
	  while (ctr > 3)
	    dk_set_push (&doc_args, (void *)(((caddr_t *)arg_array)[--ctr]));
	  if (NULL != doc_args)
	    dk_set_push (&doc_args, xp_make_literal_tree (xpp, box_dv_short_string (""), 0));
	  dk_set_push (&doc_args, xp_make_variable_ref(xpp, "reslist$"));
	  while (ctr > 0)
	    dk_set_push (&dirlist_args, (void *)(((caddr_t *)arg_array)[--ctr]));
	  return xp_make_call (xpp, "for",
	    list (3,
	      xp_make_literal_tree (xpp, box_dv_short_string ("reslist$"), 0),
	      xp_make_call_or_funcall (xpp, "collection-dir-list", list_to_array (dirlist_args)),
	      xp_make_call_or_funcall (xpp, "document-lazy-in-coll",	list_to_array (doc_args))
	      ) );
	}
      sprintf (buf, "XPATH function '%s' is not yet supported", name);
      xp_error (xpp, buf);
    }
  if (xp_env ()->xe_for_interp)
    {
      XT **patched_arg_array = (XT **) xp_make_call_args(xpp, name, (XT **)arg_array);
      if (patched_arg_array != (XT **) arg_array)
	{
	  dk_free_box (arg_array);
	  arg_array = (caddr_t)patched_arg_array;
	}
    }
  if (XPDV_NODESET == metas->xpfm_res_dtp)
    {
      sprintf (buf, "<result of %s() at line %d>", name, (int)(xpp->xpp_curr_lexem->xpl_lineno));
      var = xp_make_variable_ref (xpp, buf);
    }
  res = xtlist_with_tail (xpp, 8, arg_array, CALL_STMT,
    name,
    box_num((ptrlong)(metas->xpfm_executable)),
    (ptrlong)(metas->xpfm_res_dtp),
    xe_new_xqst (xpp, XQST_REF),
    xe_new_xqst (xpp, XQST_REF),
    var );
  if (xp_env ()->xe_for_interp)
    {
      int argc = (int) res->_.xp_func.argcount;
      int allctr, iterctr, itercount;
      if (argc < metas->xpfm_min_arg_no)
	{
	  sprintf (buf, "Not enough arguments in call of '%s'", name);
	  xp_error (xpp, buf);
	}
      if (argc > metas->xpfm_main_arg_no)
	{
	  if (0 == metas->xpfm_tail_arg_no)
	    {
	      sprintf (buf, "Too many arguments in call of '%s'", name);
	      xp_error (xpp, buf);
	    }
	  if (0 != ((argc-metas->xpfm_main_arg_no) % metas->xpfm_tail_arg_no))
	    {
	      sprintf(buf, "Incorrect number of arguments in call of '%s'", name);
	      xp_error (xpp, buf);
	    }
	}
      for (itercount = allctr = 0; allctr < argc; allctr++)
	{
	  int descr_idx = allctr;
	  xpfm_arg_descr_t *descr;
	  if (descr_idx > metas->xpfm_main_arg_no)
	    descr_idx = (int) (metas->xpfm_main_arg_no + ((descr_idx-metas->xpfm_main_arg_no) % metas->xpfm_tail_arg_no));
	  descr = metas->xpfm_args+descr_idx;
	  if (descr->xpfma_is_iter)
	    itercount++;
	}
      if (itercount != 0)
	{
	  XT **iter_vars = (XT **) dk_alloc_box_zero ((itercount * 2 + 1) * sizeof (XT *), DV_ARRAY_OF_POINTER);
	  XT *cart_var = NULL;
	  XT *cart;
	  if (NULL != var)
	    {
	      sprintf (buf, "<Cartesian product of %s() at line %d>", name, (int)(xpp->xpp_curr_lexem->xpl_lineno));
	      cart_var = xp_make_variable_ref (xpp, buf);
	    }
	  cart = xtlist_with_tail (xpp, 8, (caddr_t)iter_vars, CALL_STMT,
	    box_dv_uname_string ("(internal) Cartesian product loop"),
	    box_num((ptrlong)(xpf_cartesian_product_loop)),
	    DV_ARRAY_OF_XQVAL,
	    xe_new_xqst (xpp, XQST_REF),
	    xe_new_xqst (xpp, XQST_REF),
	    cart_var );
	  for (iterctr = allctr = 0; allctr < argc; allctr++)
	    {
	      int descr_idx = allctr;
	      xpfm_arg_descr_t *descr;
	      if (descr_idx > metas->xpfm_main_arg_no)
	        descr_idx = (int) (metas->xpfm_main_arg_no + ((descr_idx-metas->xpfm_main_arg_no) % metas->xpfm_tail_arg_no));
	      descr = metas->xpfm_args+descr_idx;
	      if (descr->xpfma_is_iter)
		{
		  sprintf (buf, " %d", xp_env ()->xe_xqst_ctr);
		  cart->_.xp_func.argtrees[iterctr*2] =
		    xtlist (xpp, 4, XP_LITERAL, NULL, box_dv_uname_string(buf), xe_new_xqst (xpp, XQST_REF));
		  cart->_.xp_func.argtrees[iterctr*2+1] =
		    res->_.xp_func.argtrees[allctr];
		  res->_.xp_func.argtrees[allctr] = xp_make_variable_ref(xpp, buf);
	          iterctr++;
		}
	    }
	  cart->_.xp_func.argtrees[itercount*2] = res;
	  res = cart;
	}
    }
  dk_check_tree (res);
  return res;
}


static XT * xp_find_defun_in_includes (shuric_t *shu, caddr_t name, caddr_t *uri_ret)
{
  DO_SET (shuric_t *, incl, &(shu->shuric_includes))
    {
      if (shuric_vtable__xqr.shuric_alloc == incl->_->shuric_alloc)
	{
	  int inx;
	  XT * res;
	  xp_query_t *i_xqr = (xp_query_t *)(incl->shuric_data);
	  XT *i_tree = i_xqr->xqr_tree;
	  XT **i_defuns = i_tree->_.module.defuns;
	  DO_BOX_FAST(XT *, def, inx, i_defuns)
	    {
	      if (!strcmp (def->_.defun.name, name))
		{
		  uri_ret[0] = incl->shuric_uri;
		  return def;
		}
	    }
	  END_DO_BOX_FAST;
	  res = xp_find_defun_in_includes (incl, name, uri_ret);
	  if (NULL != res)
	    return res;
	}
    }
  END_DO_SET ();
  return NULL;
}

XT * xp_make_call_or_funcall (xpp_t *xpp, caddr_t qname, caddr_t arg_array)
{
  xp_env_t *env = xp_env();
  xp_env_t *top_env;
  XT *defun = NULL;
  XT *var, *res;
  caddr_t import_uri = NULL;
  char buf[200+MAX_XML_QNAME_LENGTH+MAX_XML_LNAME_LENGTH];
  caddr_t name = xp_make_expanded_name (xpp, qname, -1);
  for (;;)
    {
      if (NULL != env->xe_fundefs)
	{
	  XT **defun_ptr = (XT **) id_hash_get (env->xe_fundefs, (caddr_t)(&name));
	  if (NULL != defun_ptr)
	    {
	      defun = defun_ptr[0];
	      break;
	    }
	}
      top_env = env;
      env = env->xe_parent_env;
      if (NULL == env)
	{
	  if (NULL != top_env->xe_xqr)
	    defun = xp_find_defun_in_includes (top_env->xe_xqr->xqr_shuric, name, &import_uri);
	  if (NULL != defun)
	    break;
	  if ((NULL == strchr (qname, ':')) && (NULL != id_hash_get (xpf_metas, (caddr_t)(&qname))))
	    {
	      dk_free_box (name);
	      return xp_make_call (xpp, qname, arg_array);
	    }
	  res = xp_make_call (xpp, name, arg_array);
	  dk_free_box (name);
	  return res;
	}
    }
  if (defun->_.defun.argcount != BOX_ELEMENTS(arg_array))
    {
      sprintf (
	buf,
	"Invalid number of arguments in call of %s%s%s, must be %ld, not %ld",
	name,
	((NULL != import_uri) ? " imported from " : ""),
	((NULL != import_uri) ? import_uri : ""),
	(long)(defun->_.defun.argcount), (long)(BOX_ELEMENTS(arg_array)));
      dk_free_box (name);
      xp_error (xpp, buf);
    }
  sprintf (buf, "<result of %s() at line %d>", name, (int)(xpp->xpp_curr_lexem->xpl_lineno));
  var = xp_make_variable_ref (xpp, buf);
  res = xtlist_with_tail (xpp, 8, arg_array, CALL_STMT,
    box_num((ptrlong)defun),
    box_num((ptrlong)(xpf_call_udf)),
    (ptrlong)XPDV_NODESET,
    xe_new_xqst (xpp, XQST_REF),
    xe_new_xqst (xpp, XQST_REF),
    var );
  dk_free_box (name);
  return res;
}


XT * xp_make_defun (xpp_t *xpp, caddr_t name, caddr_t param_array, XT *ret_type, xp_query_t * body_xqr)
{
  ptrlong argctr;
  XT *defun, **defun_ptr;
  xp_env_t *parent = xp_env()->xe_parent_env;
  if (NULL == parent->xe_fundefs)
    parent->xe_fundefs = id_hash_allocate (31, sizeof(caddr_t), sizeof(caddr_t), strhash, strhashcmp);
  defun = xtlist_with_tail (xpp, 5, param_array, XQ_DEFUN, name, ret_type, body_xqr);
  defun_ptr = (XT **) id_hash_get (parent->xe_fundefs, (caddr_t)(&name));
  for (argctr = 0; argctr < defun->_.defun.argcount; argctr++)
    {
      XT *param = defun->_.defun.params[argctr];
      /* XT *ptype = param->_.paramdef.type; */
      ptrlong actr2;
      for (actr2 = 0; actr2 < argctr; actr2++)
	{
	  XT *p2 = defun->_.defun.params[actr2];
	  if (!strcmp (param->_.paramdef.name, p2->_.paramdef.name))
	    {
	      char buf[200+MAX_XML_LNAME_LENGTH];
	      sprintf(buf, "Parameter name '%s' is used twice in the list of parameters", param->_.paramdef.name);
	      xp_error (xpp, buf);
	    }
	}
      param->_.paramdef.is_iter = 1;  /* ((NULL == ptype) || (SDT_LIST != ptype->_.datatype.dim)) ? 1 : 0; */
      param->_.paramdef.is_bool = 0; /* ((NULL != ptype) && (XQ_SDT_ATOM == ptype->_.datatype.dim) && (NULL != ptype->_.datatype.name) && strstr (ptype->_.datatype.name, "Boolean")) ? 1 : 0; */
    }
  if (NULL != defun_ptr)
    {
      if (NULL != defun_ptr[0]->_.defun.body)
	{
	  char buf[200+MAX_XML_QNAME_LENGTH];
	  sprintf(buf, "Function '%s' is already defined", name);
	  xp_error (xpp, buf);
	}
      defun_ptr[0]=defun;
      return defun;
    }
  id_hash_set (parent->xe_fundefs, (caddr_t)(&name), (caddr_t)(&defun));
  dk_set_push (&(xpp->xpp_local_fundefs), defun);
  return defun;
}


dk_set_t
xn_namespace_scope (xp_node_t * nsctx)
{
  dk_set_t res = NULL;
  while (nsctx)
    {
      if (nsctx->xn_namespaces)
	{
	  unsigned inx;
	  for (inx = 0; inx < BOX_ELEMENTS (nsctx->xn_namespaces); inx += 2)
	    {
	      if (uname___empty == nsctx->xn_namespaces[inx])
		continue; /* default namespace not visible in path exp */
	      dk_set_push (&res, (void*) box_copy (nsctx->xn_namespaces[inx]));
	      dk_set_push (&res, (void*) box_copy (nsctx->xn_namespaces[inx + 1]));
	    }
	}
      nsctx = nsctx->xn_parent;
    }
  return (dk_set_nreverse (res));
}


shuric_t * shuric_alloc__xqr (void *env)
{
  NEW_VARZ (shuric_t, shuric);
  return shuric;
}


caddr_t shuric_uri_to_text__xqr (caddr_t uri, query_instance_t *qi, void *env, caddr_t *err_ret)
{
  caddr_t resource_text;
  if (NULL == qi)
    {
      err_ret[0] = srv_make_new_error ("37XQR", "SQ195",
	  "Unable to retrieve '%.1000s' from SQL compiler due to danger of fatal deadlock", uri);
      return NULL;
    }
  resource_text = xml_uri_get (qi, err_ret, NULL, NULL /* = no base uri */, uri, XML_URI_STRING);
  return resource_text;
}


void shuric_parse_text__xqr (shuric_t *shuric, caddr_t uri_text_content, query_instance_t *qi, void *env, caddr_t *err_ret)
{
  ptrlong * map;
  int  n_slots, fill = 0;
  xp_query_t *xqr = (xp_query_t *) dk_alloc_box_zero (sizeof (xp_query_t), DV_XPATH_QUERY);
  xpp_t *xpp = (xpp_t *)env;
  xp_env_t *xe = xpp->xpp_xp_env;
  xpp->xpp_uri = shuric->shuric_uri;
  xpp->xpp_text = box_dv_short_string (uri_text_content);
  xqr->xqr_shuric = shuric;
  xqr->xqr_owned_by_shuric = 1;
  xe->xe_xqst_ctr = (sizeof (xp_instance_t) / sizeof (caddr_t)) + 1;
  xe->xe_xqr = xqr;
  if (NULL != xpp->xpp_err)
    goto abend;
  xp_fill_lexem_bufs (xpp);
  if (NULL != xpp->xpp_err)
    goto abend;
  if (0 == setjmp (xpp->xpp_reset))
    {
      /* Bug 4566: xpyyrestart (NULL); */
      xpyyparse (xpp);
    }
  else
    goto abend; /* see below */
  shuric->shuric_data = xqr;
  xt_check (xpp, xpp->xpp_expr);
  xqr->xqr_tree = xpp->xpp_expr;
  xpp->xpp_expr = NULL;
  xqr->xqr_is_quiet = xpp->xpp_is_quiet;
  xqr->xqr_is_davprop = xpp->xpp_is_davprop;
  xpp->xpp_dtd_config_tmp_set = dk_set_nreverse (xpp->xpp_dtd_config_tmp_set);
  xqr->xqr_xml_parser_cfg = list_to_array (xpp->xpp_dtd_config_tmp_set);
  xpp->xpp_dtd_config_tmp_set = NULL;
  xe->xe_xqr = NULL;
  xqr->xqr_instance_length = sizeof (caddr_t) * xe->xe_xqst_ctr;
  n_slots = dk_set_length (xqr->xqr_state_map);
  map = (ptrlong *) dk_alloc_box (sizeof (ptrlong) * n_slots, DV_SHORT_STRING);
  DO_SET (ptrlong, pos, &xqr->xqr_state_map)
    {
      map[fill++] = (pos);
    }
  END_DO_SET();
  switch (xpp->xpp_key_gen)
    {
    case 2:
      {
        dk_set_t key_set = NULL;
	dk_set_t *list_ptr = &(xp_env()->xe_namespace_prefixes);
        while (list_ptr[0])
        {
          caddr_t prefix = dk_set_pop (list_ptr);
          caddr_t uri = dk_set_pop (list_ptr);
          if (uname_xml == prefix)
            break;
          dk_set_push (&key_set, prefix);
          dk_set_push (&key_set, uri);
        }
        key_set = dk_set_nreverse (key_set);
        dk_set_push (&key_set, box_num ((ptrlong)(xpp->xpp_enc)));
        dk_set_push (&key_set, box_dv_short_string (uri_text_content));
        xqr->xqr_key = list_to_array (key_set);
        break;
      }
    case 1:
    case 0:
      xqr->xqr_key = box_dv_short_string (uri_text_content);
      break;
    }
  xqr->xqr_slots = map;
  xqr->xqr_n_slots = n_slots;
  xqr->xqr_base_uri = box_copy (xpp->xpp_xp_env->xe_base_uri);
  if (xpp->xpp_uri)
    xqr->xqr_xdl.xdl_file = box_copy (xpp->xpp_uri);
  return;

abend:
  xqr->xqr_shuric = NULL;
  shuric->shuric_data = NULL;
  dk_free_box ((box_t) xqr);
  err_ret[0] = xpp->xpp_err;
  xpp->xpp_err = NULL;
}


void shuric_destroy_data__xqr (struct shuric_s *shuric)
{
  xp_query_t *xqr = (xp_query_t *)shuric->shuric_data;
  if (NULL != xqr)
    {
      if (shuric != xqr->xqr_shuric)
        GPF_T;
      if (shuric->shuric_cache)
        shuric->shuric_cache->_->shuric_cache_remove (shuric->shuric_cache, shuric);
      xqr->xqr_shuric = NULL;
      dk_free_box ((box_t) xqr);
    }
  dk_free (shuric, sizeof (shuric_t));
}


caddr_t shuric_get_cache_key__xqr (struct shuric_s *shuric)
{
  xp_query_t *xqr = (xp_query_t *)shuric->shuric_data;
  return xqr->xqr_key;
}

shuric_vtable_t shuric_vtable__xqr = {
  "XQuery module",
  shuric_alloc__xqr,
  shuric_uri_to_text__xqr,
  shuric_parse_text__xqr,
  shuric_destroy_data__xqr,
  shuric_on_stale__cache_remove,
  shuric_get_cache_key__xqr
  };


shuric_t *xqr_shuric_retrieve (query_instance_t *qi, caddr_t uri, caddr_t *err_ret, shuric_t *loaded_by)
{
  shuric_t *res = shuric_get (uri);
  xpp_t *xpp;
  xp_env_t *xe;
  caddr_t resource_text;
  if (NULL != res)
    {
      if (NULL != loaded_by)
        shuric_make_include (loaded_by, res);
      return res;
    }
  resource_text = xml_uri_get (qi, err_ret, NULL, NULL /* = no base uri */, uri, XML_URI_STRING);
  if (NULL != err_ret[0])
    return NULL;
  xpp = (xpp_t *) dk_alloc (sizeof (xpp_t));
  memset (xpp, 0, sizeof (xpp_t));
  xe = (xp_env_t *) dk_alloc (sizeof (xp_env_t));
  memset (xe, 0, sizeof (xp_env_t));
  xpp->xpp_qi = qi;
  xpp->xpp_client = qi->qi_client;
  xpp->xpp_expn_type = 'q'; /* XPath cannot be imported so always 'q' here, no 'p' */
  xpp->xpp_xp_env = xe;
  xpp->xpp_err_hdr = box_dv_short_string (uri);
  xe->xe_for_interp = 1;
  xpp->xpp_enc = &eh__ISO8859_1;
  xpp->xpp_lang = server_default_lh;
  res = shuric_load (&shuric_vtable__xqr, uri, NULL /*loading_time*/, resource_text, loaded_by, qi, xpp, err_ret);
  xpp_free (xpp);
  return res;
}

xp_query_t *
xqr_stub_for_funcall (xpf_metadata_t *metas, int argcount)
{
  int argctr, allctr, iterctr, itercount;
  xp_env_t l_xe;
  xpp_t l_xpp;
  xp_query_t *xqr = (xp_query_t *) dk_alloc_box_zero (sizeof (xp_query_t), DV_XPATH_QUERY);
  int n_slots, fill = 0;
  ptrlong *map;
  XT **arg_array = (XT **)dk_alloc_box (argcount * sizeof (XT *), DV_ARRAY_OF_POINTER);
  XT *var = NULL;
  XT *call;
  memset (&l_xe, 0, sizeof (xp_env_t));
  memset (&l_xpp, 0, sizeof (xpp_t));
  l_xpp.xpp_xp_env = &l_xe;
  l_xe.xe_xqr = xqr;
  l_xe.xe_xqst_ctr = (sizeof (xp_instance_t) / sizeof (caddr_t)) + 1;
  l_xe.xe_for_interp = 1;
  if (XPDV_NODESET == metas->xpfm_res_dtp)
    var = xp_make_variable_ref (&l_xpp, "result of funcall");
  for (argctr = argcount; argctr--; /* no step */)
    {
      char buf[20]; sprintf (buf, "arg%d", argctr);
      arg_array[argctr] = xp_make_variable_ref (&l_xpp, buf);
      arg_array[argctr]->type = XP_FAKE_VAR;
    }
  call = xtlist_with_tail (&l_xpp, 8, (caddr_t)arg_array, CALL_STMT,
    box_dv_uname_string (metas->xpfm_name),
    box_num((ptrlong)(metas->xpfm_executable)),
    (ptrlong)(metas->xpfm_res_dtp),
    xe_new_xqst (&l_xpp, XQST_REF),
    xe_new_xqst (&l_xpp, XQST_REF),
    var );
  for (itercount = allctr = 0; allctr < argcount; allctr++)
    {
      int descr_idx = allctr;
      xpfm_arg_descr_t *descr;
      if (descr_idx > metas->xpfm_main_arg_no)
        descr_idx = (int) (metas->xpfm_main_arg_no + ((descr_idx-metas->xpfm_main_arg_no) % metas->xpfm_tail_arg_no));
      descr = metas->xpfm_args+descr_idx;
      if (descr->xpfma_is_iter)
        itercount++;
    }
  if (itercount != 0)
    {
      XT **iter_vars = (XT **) dk_alloc_box_zero ((itercount * 2 + 1) * sizeof (XT *), DV_ARRAY_OF_POINTER);
      XT *cart_var = NULL;
      XT *cart;
      if (NULL != var)
        {
          cart_var = xp_make_variable_ref (&l_xpp, "Cartesian product");
        }
      cart = xtlist_with_tail (&l_xpp, 8, (caddr_t)iter_vars, CALL_STMT,
        box_dv_uname_string ("(internal) Cartesian product loop"),
        box_num((ptrlong)(xpf_cartesian_product_loop)),
        DV_ARRAY_OF_XQVAL,
        xe_new_xqst (&l_xpp, XQST_REF),
        xe_new_xqst (&l_xpp, XQST_REF),
        cart_var );
      for (iterctr = allctr = 0; allctr < argcount; allctr++)
        {
          int descr_idx = allctr;
          xpfm_arg_descr_t *descr;
          if (descr_idx > metas->xpfm_main_arg_no)
            descr_idx = (int) (metas->xpfm_main_arg_no + ((descr_idx-metas->xpfm_main_arg_no) % metas->xpfm_tail_arg_no));
          descr = metas->xpfm_args+descr_idx;
          if (descr->xpfma_is_iter)
            {
              char buf[30];
              sprintf (buf, " %d", l_xe.xe_xqst_ctr);
              cart->_.xp_func.argtrees[iterctr*2] =
                xtlist (&l_xpp, 4, XP_LITERAL, NULL, box_dv_uname_string(buf), xe_new_xqst (&l_xpp, XQST_REF));
              cart->_.xp_func.argtrees[iterctr*2+1] =
                call->_.xp_func.argtrees[allctr];
              call->_.xp_func.argtrees[allctr] = xp_make_variable_ref(&l_xpp, buf);
              iterctr++;
            }
        }
      cart->_.xp_func.argtrees[itercount*2] = call;
      call = cart;
    }
  xqr->xqr_tree = call;
  xqr->xqr_instance_length = sizeof (caddr_t) * l_xe.xe_xqst_ctr;
  n_slots = dk_set_length (xqr->xqr_state_map);
  map = (ptrlong *) dk_alloc_box (sizeof (ptrlong) * n_slots, DV_SHORT_STRING);
  DO_SET (ptrlong, pos, &xqr->xqr_state_map)
    {
      map[fill++] = (pos);
    }
  END_DO_SET();
  xqr->xqr_slots = map;
  xqr->xqr_n_slots = n_slots;
  xqr->xqr_base_uri = uname___empty;
  return xqr;
}


xp_query_t *xp_query_parse (query_instance_t * qi, char * str, ptrlong predicate_type, caddr_t * err_ret, xp_query_env_t *xqre)
{
  if (NULL == str)
    {
      *err_ret = srv_make_new_error ("37000", "XM012",
	  "XPATH interpreter: input text is not a string, maybe it is not yet calculated");
      return NULL;
    }
  else
    {
      shuric_t *xqr_shuric;
      wcharset_t *query_charset = xqre->xqre_query_charset;
      int dry_run;
      NEW_VAR (xpp_t, xpp);
      NEW_VARZ (xp_env_t, xe);
      memset (xpp, 0, sizeof (xpp_t));
      xpp->xpp_qi = qi;
      xpp->xpp_client = qi ? qi->qi_client : NULL;
      xpp->xpp_uri = xqre->xqre_base_uri;
      xpp->xpp_expn_type = (('q' == predicate_type) ? 'q' : 'p');
      xpp->xpp_lax_nsuri_test = (('p' == predicate_type) ? 1 : 0);
      xpp->xpp_xp_env = xe;
      xpp->xpp_err_hdr = box_dv_short_string (('q' == predicate_type) ? "XQuery interpreter" : "XPath interpreter");
      xpp->xpp_dry_run = 0;
      xpp->xpp_sql_columns = xqre->xqre_sql_columns;
      xpp->xpp_key_gen = xqre->xqre_key_gen;
      if (xqre->xqre_nsctx_xn)
        xe->xe_namespace_prefixes = xn_namespace_scope (xqre->xqre_nsctx_xn);
      else  if (xqre->xqre_nsctx_xe)
        xe->xe_namespace_prefixes = xqre->xqre_nsctx_xe->_->xe_namespace_scope (xqre->xqre_nsctx_xe, 0);
      xe->xe_for_interp = 1;

      if ((NULL == query_charset) && (!xqre->xqre_query_charset_is_set))
        {
	  query_charset = QST_CHARSET(qi);
	  if (NULL == query_charset)
	    query_charset = default_charset;
	}
      if (NULL == query_charset)
	xpp->xpp_enc = &eh__ISO8859_1;
      else
	{
	  xpp->xpp_enc = eh_get_handler (CHARSET_NAME (query_charset, NULL));
	  if (NULL == xpp->xpp_enc)
	    xpp->xpp_enc = &eh__ISO8859_1;
	}
      xpp->xpp_lang = server_default_lh;
      xpp->xpp_checked_functions = xqre->xqre_checked_functions;
      xqr_shuric = shuric_load (&shuric_vtable__xqr, NULL /*uri*/, NULL /*loading_time*/, str, NULL, qi, xpp, err_ret);
      dry_run = xpp->xpp_dry_run;
      xpp_free (xpp);
      if (NULL != err_ret[0])
        return NULL;
      if (dry_run)
        {
          /* Not shuric_release(xqr_shuric) here because free of xqr will release the same shuric again. */
          if (NULL != xqr_shuric)
            dk_free_tree (xqr_shuric->shuric_data);
          return NULL;
        }
      return (xp_query_t *)(xqr_shuric->shuric_data);
    }
}


caddr_t
xp_query_lex_analyze (caddr_t str, char predicate_type, xp_node_t * nsctx, wcharset_t *query_charset)
{
  if (!DV_STRINGP(str))
    {
      return list (1, list (3, (ptrlong)0, (ptrlong)0, box_dv_short_string ("XPATH analyzer: input text is not a string")));
    }
  else
    {
      dk_set_t lexems = NULL;
      caddr_t result_array;
      NEW_VAR (xpp_t, xpp);
      NEW_VARZ (xp_env_t, xe);
      memset (xpp, 0, sizeof (xpp_t));
      xpp->xpp_text = box_copy (str);
      xpp->xpp_xp_env = xe;
      xpp->xpp_synthighlight = 1;
      xe->xe_namespace_prefixes = xn_namespace_scope (nsctx);
      xpp->xpp_err_hdr = box_dv_short_string (('q' == predicate_type) ? "XQuery analyzer" : "XPath analyzer");
      xpp->xpp_expn_type = predicate_type;
      xe->xe_for_interp = 1;
      xe->xe_xqr = NULL;
      xe->xe_xqst_ctr = (sizeof (xp_instance_t) / sizeof (caddr_t)) + 1;
      if (NULL == query_charset)
	query_charset = default_charset;
      if (NULL == query_charset)
	xpp->xpp_enc = &eh__ISO8859_1;
      else
	{
	  xpp->xpp_enc = eh_get_handler (CHARSET_NAME (query_charset, NULL));
	  if (NULL == xpp->xpp_enc)
	    xpp->xpp_enc = &eh__ISO8859_1;
	}
      xpp->xpp_lang = server_default_lh;

      xp_fill_lexem_bufs (xpp);
      DO_SET (xp_lexem_t *, buf, &(xpp->xpp_output_lexem_bufs))
	{
	  int buflen = box_length (buf) / sizeof( xp_lexem_t);
	  int ctr;
	  for (ctr = 0; ctr < buflen; ctr++)
	    {
	      xp_lexem_t *curr = buf+ctr;
	      if (0 == curr->xpl_lex_value)
		break;
#ifdef XPATHP_DEBUG
	      dk_set_push (&lexems, list (5,
		curr->xpl_lineno,
		curr->xpl_depth,
		box_copy (curr->xpl_raw_text),
		curr->xpl_lex_value,
		curr->xpl_state ) );
#else
	      dk_set_push (&lexems, list (4,
		curr->xpl_lineno,
		curr->xpl_depth,
		box_copy (curr->xpl_raw_text),
		curr->xpl_lex_value ) );
#endif
	    }
	}
      END_DO_SET();
      if (NULL != xpp->xpp_err)
	{
	  dk_set_push (&lexems, list (3,
		((NULL != xpp->xpp_curr_lexem) ? xpp->xpp_curr_lexem->xpl_lineno : (ptrlong)0),
		xpp->xpp_lexdepth,
		box_copy (ERR_MESSAGE (xpp->xpp_err)) ) );
	}
      lexems = dk_set_nreverse (lexems);
      xpp_free (xpp);
      result_array = (caddr_t)(dk_set_to_array (lexems));
      dk_set_free (lexems);
      return result_array;
    }
}

static long xp_axis_to_ap_axis_wr(long axs)
{
  switch(axs)
    {
    case XP_ABS_CHILD:		return XP_ABS_CHILD_WR;
    case XP_ABS_DESC:		return XP_ABS_DESC_WR;
    case XP_CHILD:		return XP_CHILD_WR;
    case XP_DESCENDANT:		return XP_DESCENDANT_WR;
    case XP_DESCENDANT_OR_SELF:	return XP_DESCENDANT_OR_SELF_WR;
/* XP_SELF is a special case. It has no iteration, thus no WR applicable locally,
   but XP_SELF's input should treat XP_SELF as optimized node, if SELF's
   target is optimized, or if SELF has optimizable node or predicates. */
    case XP_SELF:		return XP_SELF;
    }
  return 0;
}

/* IvAn/SmartXContains/001025 WR-optimization added */
void
xp_query_enable_wr (xp_query_t * xqr, XT *tree, int target_is_wr)
{
  long axs, axs_wr;
  int idx;	/* unused, only for DO_BOX */
  XT *step_node, *l_exp, *exp_r;

  /*return;*/
#ifdef DEBUG
  switch((ptrlong)tree)
    {
    case XP_TEXT: case XP_PI: case XP_COMMENT:
    case XP_NODE: case XP_ELT: case XP_ELT_OR_ROOT:
      return;
    }
#else
  if (!IS_BOX_POINTER (tree))
    return;
#endif
  switch(tree->type)
    {
    case XP_STEP:
      DO_BOX (XT *, pred, idx, tree->_.step.preds)
	{
	  xp_query_enable_wr (xqr, pred, target_is_wr);
	}
      END_DO_BOX;
      step_node = tree->_.step.node;
      axs = (long) tree->_.step.axis;
      axs_wr = xp_axis_to_ap_axis_wr(axs);
      if (0 == axs_wr)	/* Can't enable WR-optimization if there's no WR-version for step's axis */
	{
	  if (XP_CHILD_WR != axs && XP_DESCENDANT_WR != axs && XP_DESCENDANT_OR_SELF_WR != axs)
	    target_is_wr = 0;
	  goto enable_wr_in_step_input;	/* see below */
	}
      if ( ARRAYP(step_node) &&					/* Case like <CODE>'... / tag_name'</CODE>	*/
	IS_BOX_POINTER(step_node->_.name_test.local) &&		/* but not like <CODE>'... / *'</CODE>		*/
	(' ' != step_node->_.name_test.local[0]) )		/* and not check for e.g. " comment" or " pi"	*/
	{
	  goto enable_wr_here;	/* see below */
	}
      if (NULL != tree->_.step.preds && 1 <= BOX_ELEMENTS(tree->_.step.preds))
	{
	  XT *step_pred = tree->_.step.preds[0];
	  if ((BOP_AND == step_pred->type) || (BOP_LIKE == step_pred->type))
	    {
	      l_exp = step_pred->_.bin_exp.left;
	      exp_r = step_pred->_.bin_exp.right;
	      if (
		(XP_STEP == l_exp->type) && (XP_SELF == l_exp->_.step.axis) &&
		(XP_LITERAL == exp_r->type) )
		{
		  lang_handler_t * lh = xpt_lhptr (exp_r->_.literal.lhptr);
		  int word_count = lh_count_words(
		    &eh__UTF8, lh,
		    exp_r->_.literal.val, box_length(exp_r->_.literal.val),
		    lh->lh_is_vtb_word );
		  if (0 < word_count)
		    {	/* Case like <CODE>... / tag_name [. = "Some words"]</CODE> or like <CODE>... / tag_name [. like "%Some words%"]</CODE> */
		      goto enable_wr_here;	/* see below */
		    }
		}
	    }
	}
      if (target_is_wr && (((XT *) XP_ELT == step_node) || ((XT *) XP_ELT_OR_ROOT == step_node) || (ARRAYP(step_node) && (XP_NAME_EXACT == step_node->type))))
	{
	  goto enable_wr_here;
	}
      goto enable_wr_in_step_input;
enable_wr_here:
      tree->_.step.axis = axs_wr;
      target_is_wr = 1;
enable_wr_in_step_input:
      if (NULL != step_node)
	xp_query_enable_wr (xqr, step_node, target_is_wr);
      if (NULL != tree->_.step.input)
	xp_query_enable_wr (xqr, tree->_.step.input, target_is_wr);
      return;
    case BOP_EQ:
    case BOP_LIKE:
      l_exp = tree->_.bin_exp.left;
      exp_r = tree->_.bin_exp.right;
      if (XP_STEP != l_exp->type)	/* Can't enable WR-optimization on non-step node */
	goto enable_wr_in_l_exp;	/* see below */
      axs = (long) l_exp->_.step.axis;
      axs_wr = xp_axis_to_ap_axis_wr(axs);
      if(0 == axs_wr)	/* Can't enable WR-optimization if there's no WR-version for step's axis */
	goto enable_wr_in_l_exp;	/* see below */
      if (XP_LITERAL == exp_r->type)
	{
	  lang_handler_t * lh = xpt_lhptr (exp_r->_.literal.lhptr);
	  int word_count = lh_count_words(
	    &eh__UTF8, lh,
	    exp_r->_.literal.val, box_length(exp_r->_.literal.val),
	    lh->lh_is_vtb_word );
	  if (0 < word_count)
	    {	/* Case like <CODE>... / tag_name [. = "Some words"]</CODE> or like <CODE>... / tag_name [. like "%Some words%"]</CODE> */
	      l_exp->_.step.axis = axs_wr;
	      goto enable_wr_in_l_exp;	/* see below */
	    }
	}
enable_wr_in_l_exp:
      xp_query_enable_wr (xqr, l_exp, target_is_wr);
      return;
    default:
      return;	/* No GPFs for non-listed cases */
    }
}


int
xp_wordstack_from_string (char * str, encoding_handler_t *eh, lang_handler_t *lh, dk_set_t *wordstack_ptr)
{
  int ret;
  if ((&eh__UTF8 == eh) || (&eh__UTF8_QR == eh))
    {
      ASSERT_NCHARS_UTF8 (str, strlen (str));
    }
  else
    {
      ASSERT_NCHARS_8BIT (str, strlen (str));
    }
  ret = lh_iterate_patched_words(
    eh, lh->lh_ftq_language,
    str, strlen(str),
    lh->lh_ftq_language->lh_is_vtb_word, lh->lh_ftq_language->lh_normalize_word,
    push_string_into_set_callback,
    wordstack_ptr );
  return ret;
}


caddr_t *
xp_word_or_phrase_from_wordstack (xpp_t *xpp, dk_set_t words, int allow_xp_error)
{
  int inx;
  caddr_t * res = NULL;
  if (NULL == words)
    {
      if (allow_xp_error)
	xp_error (xpp, "phrase consists of noise words exclusively");
      else
	return NULL;
    }
  if (!words->next)
    {
      ASSERT_BOX_UTF8 (words->data);
      res = (caddr_t *) list (3, SRC_WORD, (ptrlong)SRC_RANGE_DUMMY, words->data);
      dk_set_free (words);
    }
  else
    {
      words = dk_set_nreverse (words);
      dk_set_push (&words, (void*)((ptrlong)SRC_RANGE_DUMMY));	/* Push flags, will be item with index 1. */
      dk_set_push (&words, (void*)((ptrlong)SRC_WORD_CHAIN));	/* Push opcode, will be item with index 0 */
      res = (caddr_t*) list_to_array (words);
      for (inx = 2; inx < (int) BOX_ELEMENTS (res); inx++)
        {
          ASSERT_BOX_UTF8 (res[inx]);
	  res[inx] = list (3, SRC_WORD, (ptrlong)SRC_RANGE_DUMMY, res[inx]);
        }
    }
  return res;
}


caddr_t *
xp_word_or_phrase_from_string (xpp_t *xpp, char * str, encoding_handler_t *eh, lang_handler_t *lh, int allow_xp_error)
{
  dk_set_t words = NULL;
  int ret_decoder;
  caddr_t *res;
  ret_decoder = xp_wordstack_from_string (str, eh, lh, &words);
  if ((0 != ret_decoder) && allow_xp_error)
    xp_error (xpp, "phrase contains encoding errors");
  res = xp_word_or_phrase_from_wordstack (xpp, words, allow_xp_error);
  return res;
}


caddr_t *
xp_word_from_exact_string (xpp_t *xpp, const char * str, encoding_handler_t *eh, int allow_xp_error)
{
  size_t slen = strlen (str);
  unichar *unidata;
  utf8char *word_buf, *word_end;
  int unidatabuflen, unidatalen, word_buflen;
  const char *tmp;
  int eh_state = 0;
  dk_set_t words = NULL;
  unidatabuflen = (int) ((sizeof (unichar)*slen) / (eh->eh_minsize))|0xFF;
  unidata = dk_alloc (unidatabuflen);
  tmp = str;
  unidatalen = eh->eh_decode_buffer (unidata, unidatabuflen / sizeof (unichar), &tmp, str+slen, eh, &eh_state);
  if ((unidatalen < 0) || ((str+slen) != tmp))
    {
      dk_free (unidata, unidatabuflen);
      goto err;
    }
  word_buflen = unidatalen * MAX_UTF8_CHAR;
  word_buf = dk_alloc (word_buflen);
  word_end = (utf8char *)eh_encode_buffer__UTF8 (unidata, unidata + unidatalen, (char *)(word_buf), (char *)(word_buf + word_buflen));
  dk_set_push (&words, box_dv_short_nchars ((char *)word_buf, word_end - word_buf));
  dk_free (unidata, unidatabuflen);
  dk_free (word_buf, word_buflen);
  goto fine;

err:
  if (allow_xp_error)
    xp_error (xpp, "^-string contains encoding error");

fine:
  return xp_word_or_phrase_from_wordstack (xpp, words, allow_xp_error);
}


caddr_t
sqlr_make_new_error_xdl_base (const char *code, const char *virt_code, xp_debug_location_t *xdl, const char *string, va_list vlst)
{
  char temp[2000];
  int n;
  caddr_t err;
  ASSERT_OUTSIDE_TXN;
  n = vsnprintf (temp, sizeof(temp), string, vlst);
  snprint_xdl (temp+n, sizeof(temp)-n, xdl);
  temp[sizeof(temp)-1] = '\0';
  err = srv_make_new_error (code, virt_code, "%s", temp);
  return err;
}

void
sqlr_new_error_xdl_base (const char *code, const char *virt_code, xp_debug_location_t *xdl, const char *string, va_list vlst)
{
  caddr_t err = sqlr_make_new_error_xdl_base (code, virt_code, xdl, string, vlst);
  du_thread_t *self = THREAD_CURRENT_THREAD;
  thr_set_error_code (self, err);
  longjmp_splice (self->thr_reset_ctx, RST_ERROR);
}


caddr_t
sqlr_make_new_error_xdl (const char *code, const char *virt_code, xp_debug_location_t *xdl, const char *string, ...)
{
  caddr_t err;
  va_list vlst;
  va_start (vlst, string);
  err = sqlr_make_new_error_xdl_base (code, virt_code, xdl, string, vlst);
  va_end (vlst);
  return err;
}

void
sqlr_new_error_xdl (const char *code, const char *virt_code, xp_debug_location_t *xdl, const char *string, ...)
{
  va_list vlst;
  va_start (vlst, string);
  sqlr_new_error_xdl_base (code, virt_code, xdl, string, vlst);
  va_end (vlst);
}

caddr_t
sqlr_make_new_error_xqi_xdl (const char *code, const char *virt_code, xp_instance_t * xqi, const char *string, ...)
{
  caddr_t err;
  va_list vlst;
  va_start (vlst, string);
  err = sqlr_make_new_error_xdl_base (code, virt_code, &(xqi->xqi_xqr->xqr_xdl), string, vlst);
  va_end (vlst);
  return err;
}

void
sqlr_new_error_xqi_xdl (const char *code, const char *virt_code, xp_instance_t * xqi, const char *string, ...)
{
  va_list vlst;
  va_start (vlst, string);
  sqlr_new_error_xdl_base (code, virt_code, &(xqi->xqi_xqr->xqr_xdl), string, vlst);
  va_end (vlst);
}
