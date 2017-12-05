/*
 *  xpf.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

#include "Dk.h"
#include "xpf.h"
#include "arith.h"
#include "sqlbif.h"
#include "sqlver.h"
#include "xml.h"
#include "xpathp_impl.h"
#include "xml_ecm.h"
#include "bif_text.h"
#include "rdf_core.h"
#include "security.h" /* for sec_proc_check () */
#include "sqltype.h" /* for XMLTYPE_TO_ENTITY */
#include "srvstat.h"
#include "shcompo.h"

#include "xqf.h"

caddr_t default_doc_dtd_config = NULL;


static caddr_t
xqi_atomize_one (xp_instance_t * xqi, caddr_t value)
{
  dtp_t value_dtp = DV_TYPE_OF (value);
  if (DV_ARRAY_OF_XQVAL == value_dtp)
    {
      int els = BOX_ELEMENTS (value);
      if (0 == els)
        return NULL;
      if (1 < els)
	sqlr_new_error_xqi_xdl ("XP001", "XPF??", xqi, "Type error: atomization can not produce a single atom from a sequence of length %d", els);
      value = ((caddr_t *)value)[0];
      value_dtp = DV_TYPE_OF (value);
    }
  if (DV_XML_ENTITY == value_dtp)
    {
      xml_entity_t *xe = (xml_entity_t *)value;
      caddr_t atom = NULL;
      xe->_->xe_string_value (xe, &atom, DV_SHORT_STRING);
      return atom;
    }
  return value;
}


XT *
xpf_arg_tree (XT * tree, int n)
{
  if (tree->_.xp_func.argcount <= n)
    sqlr_new_error ( "42000", "XPF01",
      "Too few arguments (%ld) for XPATH function %s() at line %ld.",
      (long)(tree->_.xp_func.argcount),
      tree->_.xp_func.qname,
      (long) unbox (tree->srcline) );
  return (tree->_.xp_func.argtrees[n]);
}

static caddr_t xpf_arg_stub = NULL;

caddr_t
xpf_arg (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, dtp_t target_dtp, int n)
{
  caddr_t val;
  XT * arg = xpf_arg_tree (tree, n);
  xqi_eval (xqi, arg, ctx_xe);
  switch (target_dtp)
    {
      case DV_C_STRING:
	val = xqi_value (xqi, arg, DV_LONG_STRING);
	if (!DV_STRINGP (val))
	  return xpf_arg_stub;
	return val;
      default:
	val = xqi_value (xqi, arg, target_dtp);
	return val;
    }
}

caddr_t
xpf_raw_arg (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, int n)
{
  caddr_t val;
  XT * arg = xpf_arg_tree (tree, n);
  xqi_eval (xqi, arg, ctx_xe);
  val = xqi_raw_value (xqi, arg);
  return val;
}

static int zbox_is_set = 0;
static caddr_t zbox = NULL;

int
xpf_arg_boolean (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, int n)
{
  XT * arg = xpf_arg_tree (tree, n);
  caddr_t val;
  dtp_t dtp;
  if (!zbox_is_set)
    {
      zbox = box_num_nonull (0);
      zbox_is_set = 1;
    }
  xqi_eval (xqi, arg, ctx_xe);
  val = xqi_raw_value (xqi, arg);
  dtp = DV_TYPE_OF (val);
  if (IS_STRING_DTP (dtp))
    return (box_length (val) > 1);
  if (IS_NUM_DTP (dtp))
    return (DVC_MATCH != cmp_boxes (val, zbox, NULL, NULL));
  if (DV_ARRAY_OF_XQVAL == dtp)
    {
      size_t len = BOX_ELEMENTS(val);
      size_t ctr;
      for (ctr = len; ctr--; /* no step*/)
	{
	  caddr_t subval = ((caddr_t *)(val))[0];
	  dtp = DV_TYPE_OF (subval);
	  if (IS_STRING_DTP (dtp))
	    {
	      if (box_length (subval) > 1)
		return 1;
	      else
		continue;
	    }
	  if (IS_NUM_DTP (dtp))
	    {
	      if (DVC_MATCH != cmp_boxes (subval, zbox, NULL, NULL))
		return 1;
	      else
		continue;
	    }
	  if (NULL != val)
	    return 1;
	  else
	    continue;
	}
      return 0;
    }
  return (NULL != val);
}

void
xpf_arg_list_impl (xp_instance_t * xqi, XT * arg, xml_entity_t * ctx_xe, caddr_t *res)
{
  caddr_t el, lst;
  xqi_eval (xqi, arg, ctx_xe);
  el = xqi_raw_value (xqi, arg);
  if (NULL == el)
    {
      XP_SET (res, dk_alloc_box (0, DV_ARRAY_OF_XQVAL));
    }
  else
    {
      caddr_t *subitems;
      size_t subctr, subcount;
      size_t fill_len = 0, new_fill_len, alloc_len = 15 /* 2^n - 1 */;
      caddr_t *buf = (caddr_t *)dk_alloc_box_zero (alloc_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
      XP_SET (res, (caddr_t)(buf));
next_val:
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(el))
	{
	  subitems = (caddr_t *)el;
	  subcount = BOX_ELEMENTS(el);
	}
      else
	{
	  subitems = (caddr_t *)(&el);
	  subcount = 1;
	}
      new_fill_len = fill_len + subcount;
      if (alloc_len < new_fill_len)
	{
	  caddr_t *buf2;
          while (alloc_len < new_fill_len) alloc_len += (alloc_len + 1);
          if (alloc_len > MAX_BOX_ELEMENTS)
	    sqlr_new_error ("22023", "XS062",
	      "Out of memory allocation limits: the sequence is too long");
	  buf2 = (caddr_t *)dk_alloc_box_zero (alloc_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
	  memcpy (buf2, buf, fill_len * sizeof (caddr_t));
	  box_tag_modify (buf, DV_ARRAY_OF_LONG);
	  buf = buf2;
	  XP_SET (res, (caddr_t)buf);
	}
      for (subctr = 0; subctr < subcount; subctr++)
	buf[fill_len++] = box_copy_tree (subitems[subctr]);
      if (xqi_is_next_value (xqi, arg))
	{
	  el = xqi_raw_value (xqi, arg);
	  goto next_val;
	}
      lst = dk_alloc_box (fill_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
      memcpy (lst, buf, fill_len * sizeof (caddr_t));
      box_tag_modify (buf, DV_ARRAY_OF_LONG);
      XP_SET (res, lst);
    }
}


typedef struct cenpair_s
{
  caddr_t item;
  caddr_t cache;
} cenpair_t;

typedef void (* xpf_list_censor_t)(xp_instance_t * xqi, cenpair_t *seq_head, size_t *seq_head_len, caddr_t candidate, void *user_data);

void
xpf_arg_list_censored (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, int n, caddr_t *res, xpf_list_censor_t censor, void *user_data)
{
  caddr_t el, *lst;
  XT * arg = xpf_arg_tree (tree, n);
  xqi_eval (xqi, arg, ctx_xe);
  el = xqi_raw_value (xqi, arg);
  if (NULL == el)
    {
      XP_SET (res, dk_alloc_box (0, DV_ARRAY_OF_XQVAL));
    }
  else
    {
      caddr_t *subitems;
      size_t subctr, subcount;
      size_t fill_len = 0, alloc_len = 15 /* == 2^n - 1 */ ;
      cenpair_t *buf = (cenpair_t *)dk_alloc_box_zero (alloc_len * sizeof (cenpair_t), DV_ARRAY_OF_XQVAL);
      XP_SET (res, (caddr_t)(buf));
next_val:
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(el))
	{
	  subitems = (caddr_t *)el;
	  subcount = BOX_ELEMENTS(el);
	}
      else
	{
	  subitems = (caddr_t *)(&el);
	  subcount = 1;
	}
      for (subctr = 0; subctr < subcount; subctr++)
	{
	  caddr_t subitem = subitems[subctr];
	  if (alloc_len <= fill_len)
	    {
	      cenpair_t *buf2;
	      while (alloc_len < fill_len) alloc_len += (alloc_len + 1);
	      if (alloc_len > MAX_BOX_ELEMENTS)
	        sqlr_new_error ("22023", "XS063",
		  "Out of memory allocation limits: the sequence is too long");
	      alloc_len *= 2;
	      buf2 = (cenpair_t *)dk_alloc_box_zero (alloc_len * sizeof (cenpair_t), DV_ARRAY_OF_XQVAL);
	      memcpy (buf2, buf, fill_len * sizeof (cenpair_t));
	      box_tag_modify (buf, DV_ARRAY_OF_LONG);
	      buf = buf2;
	      XP_SET (res, (caddr_t)buf);
	    }
	  censor (xqi, buf, &fill_len, subitem, user_data);
	}
      if (xqi_is_next_value (xqi, arg))
	{
	  el = xqi_raw_value (xqi, arg);
	  goto next_val;
	}
      lst = (caddr_t *)dk_alloc_box (fill_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
      while (fill_len--)
	{
	  lst[fill_len] = buf[fill_len].item;
	  buf[fill_len].item = NULL;
	}
      XP_SET (res, (caddr_t)lst);
    }
}


void
xpf_count (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t val, res;
  int ctr = 0;
  XT * arg = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg, ctx_xe);
  val = xqi_raw_value (xqi, arg);
  if (NULL != val)
    {
next_val:
      if (NULL != val)
        ctr += ((DV_ARRAY_OF_XQVAL == DV_TYPE_OF(val)) ? BOX_ELEMENTS(val) : 1);
      if (!xqi_is_next_value (xqi, arg))
	goto no_more_vals;
      val = xqi_raw_value (xqi, arg);
      goto next_val;
no_more_vals: ;
    }
  res = box_num_nonull(ctr);
  if (NULL == res)
    {
      ptrlong * res_1;
      res = dk_alloc_box (sizeof (box_t), DV_LONG_INT);
      res_1 = (ptrlong *)res;
      res_1[0] = 0;
    }
  XQI_SET (xqi, tree->_.xp_func.res, res);
}


void
xpf_empty (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t val;
  XT * arg = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg, ctx_xe);
  val = xqi_raw_value (xqi, arg);
  if (NULL != val)
    {
next_val:
      if ((NULL != val) && ((DV_ARRAY_OF_XQVAL == DV_TYPE_OF(val)) ? BOX_ELEMENTS(val) : 1))
	{
	  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull(0));
	  return;
	}
      if (!xqi_is_next_value (xqi, arg))
	goto no_more_vals;
      val = xqi_raw_value (xqi, arg);
      goto next_val;
no_more_vals: ;
    }
  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull(1));
}


void
xpf_exists (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t val;
  XT * arg = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg, ctx_xe);
  val = xqi_raw_value (xqi, arg);
  if (NULL != val)
    {
next_val:
      if ((NULL != val) && ((DV_ARRAY_OF_XQVAL == DV_TYPE_OF(val)) ? BOX_ELEMENTS(val) : 1))
	{
	  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull(1));
	  return;
	}
      if (!xqi_is_next_value (xqi, arg))
	goto no_more_vals;
      val = xqi_raw_value (xqi, arg);
      goto next_val;
no_more_vals: ;
    }
  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull(0));
}


void
xpf_string (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  dtp_t dtp;
  caddr_t val;
  if (0 != tree->_.xp_func.argcount)
    val = xpf_raw_arg (xqi, tree, ctx_xe, 0);
  else
    val = (caddr_t) ctx_xe;
  if (!val)
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (""));
      return;
    }
  dtp = DV_TYPE_OF (val);
  if (DV_XML_ENTITY == dtp)
    {
      xml_entity_t * xe = (xml_entity_t *) val;
#if 0
      xe->_->xe_string_value (xe,
			      XQI_ADDRESS (xqi, tree->_.xp_func.res), DV_SHORT_STRING);
#else
      xe_string_value_1 (xe, XQI_ADDRESS (xqi, tree->_.xp_func.res), DV_SHORT_STRING);
#endif
    }
  else
    {
      val = box_cast ((caddr_t *) xqi->xqi_qi, val, (sql_tree_tmp*) st_varchar, dtp);
      XQI_SET (xqi, tree->_.xp_func.res, val);
    }
}

void
xpf_serialize (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  dtp_t dtp;
  caddr_t val;
  if (0 != tree->_.xp_func.argcount)
    val = xpf_raw_arg (xqi, tree, ctx_xe, 0);
  else
    val = (caddr_t) ctx_xe;
  if (!val)
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (""));
      return;
    }
  dtp = DV_TYPE_OF (val);
  if (DV_XML_ENTITY == dtp)
    {
      xml_entity_t * xe = (xml_entity_t *) val;
      dk_session_t *ses = strses_allocate ();
      caddr_t res;
      caddr_t saved_encoding = xe->xe_doc.xd->xout_encoding;
      xe->xe_doc.xd->xout_encoding = "UTF-8";
      xe->_->xe_serialize (xe, ses);
      xe->xe_doc.xd->xout_encoding = saved_encoding;
      res = strses_string (ses);
      strses_free (ses);
      XQI_SET (xqi, tree->_.xp_func.res, res);
    }
  else
    {
      val = box_cast ((caddr_t *) xqi->xqi_qi, val, (sql_tree_tmp*) st_varchar, dtp);
      XQI_SET (xqi, tree->_.xp_func.res, val);
    }
}

void
xpf_local_name (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  dtp_t dtp;
  caddr_t val;
  if (0 != tree->_.xp_func.argcount)
    val = xpf_raw_arg (xqi, tree, ctx_xe, 0);
  else
    val = (caddr_t) ctx_xe;
  dtp = DV_TYPE_OF (val);
  if (DV_XML_ENTITY == dtp)
    {
      xml_entity_t * xe = (xml_entity_t *) val;
      caddr_t name = xe->_->xe_ent_name (xe);
      caddr_t local = strrchr (name, ':');
      if (!local)
	local = name;
      else
	local += 1;
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (local));
      dk_free_box (name);
    }
  else
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (""));
    }
}


void
xpf_name (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  dtp_t dtp;
  caddr_t val;
  if (tree->_.xp_func.argcount)
    val = xpf_raw_arg (xqi, tree, ctx_xe, 0);
  else
    val = (caddr_t) ctx_xe;
  dtp = DV_TYPE_OF (val);
  if (DV_XML_ENTITY == dtp)
    {
      xml_entity_t * xe = (xml_entity_t *) val;
      caddr_t name = xe->_->xe_ent_name (xe);
      caddr_t res;
      if (strncmp (name, "xml:", 4))
        res = box_dv_short_nchars (name, box_length (name) - 1);
      else
        {
          res = dk_alloc_box (box_length (name) + XML_NS_URI_LEN - 3, DV_STRING);
          memcpy (res, XML_NS_URI, XML_NS_URI_LEN);
          strcpy (res+XML_NS_URI_LEN, name + 4);
        }
      XQI_SET (xqi, tree->_.xp_func.res, res);
      dk_free_box (name);
    }
  else
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (""));
    }
}


void
xpf_namespace_uri (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  dtp_t dtp;
  caddr_t val, res;
  if (tree->_.xp_func.argcount)
    val = xpf_raw_arg (xqi, tree, ctx_xe, 0);
  else
    val = (caddr_t) ctx_xe;
  dtp = DV_TYPE_OF (val);
  if (DV_XML_ENTITY == dtp)
    {
      xml_entity_t * xe = (xml_entity_t *) val;
      caddr_t name = xe->_->xe_ent_name (xe);
      caddr_t local = strrchr (name, ':');
      if (!local)
	res = box_dv_short_nchars ("", 0);
      else if ((3 == (local-name)) && !memcmp ("xml", name, 3))
        res = box_dv_short_nchars (XML_NS_URI, XML_NS_URI_LEN);
      else
        res = box_dv_short_nchars (name, (int) (local - name));
      dk_free_box (name);
    }
  else
    res = box_dv_short_string ("");
  XQI_SET (xqi, tree->_.xp_func.res, res);
}


void
xpf_number (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t val;
  if (tree->_.xp_func.argcount)
    {
      val = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 0);
      XQI_SET (xqi, tree->_.xp_func.res, xp_box_number (val));
    }
  else
    {
      xpf_string (xqi, tree, ctx_xe);
      XQI_SET (xqi, tree->_.xp_func.res, xp_box_number (XQI_GET (xqi, tree->_.xp_func.res)));
    }
}


void
xpf_boolean (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int res = xpf_arg_boolean (xqi, tree, ctx_xe, 0);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) (ptrlong) (res ? 1L : 0L));
}


void
xpf_and (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int argctr, argno;
  argno = (int) tree->_.xp_func.argcount;
  for (argctr = 0; argctr < argno; argctr++)
    {
      if (xpf_arg_boolean (xqi, tree, ctx_xe, argctr))
	continue;
      XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
      return;
    }
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
}


void
xpf_or (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int argctr, argno;
  argno = (int) tree->_.xp_func.argcount;
  for (argctr = 0; argctr < argno; argctr++)
    {
      if (!xpf_arg_boolean (xqi, tree, ctx_xe, argctr))
	continue;
      XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
      return;
    }
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
}


void
xpf_not (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int res = xpf_arg_boolean (xqi, tree, ctx_xe, 0);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) (ptrlong) (res ? 0L : 1L));
}


void
xpf_true (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 1L);
}


void
xpf_false (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) 0L);
}


static void
xpf_some_or_every (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, int is_every)
{
  xqi_binding_t *internals_top_saved = xqi->xqi_internals;
/* An on-demand binding to handle current value of quantor's variable.
When needed at the first time, it is created and added to local context.
If normal return from function reached, it is removed from context and memory is freed.
If error causes abnormal termination of calculations,
it will be removed with the whole set of locals.
Note that there's no xqi_find_binding (xqi, ...), like in other similar places,
so the quantified variable will temporary hide any existing outer variable with the same name */
  xqi_binding_t *probe_binding;

  caddr_t varname = xpf_arg (xqi, tree, ctx_xe, DV_UNAME, 0);		/* Name of variable under the quantor */
  XT * set = xpf_arg_tree (tree, 1);					/* Expression to be iterated by quantor */
#if 0
  XT * test = xpf_arg_tree (tree, 2);					/* Expression for testing of every item */
#endif
  caddr_t val;								/* Current part of the set of values */
  caddr_t *items;
  int answer = is_every;	/* EVERY on empty set is true, SOME on empty set is false */
  int length_of_val;
  int item_in_val;

  xqi_eval (xqi, set, ctx_xe);
  val = xqi_raw_value (xqi, set);

  if (!val)
    goto done_empty;

  probe_binding = xqi_push_internal_binding (xqi, varname);
  probe_binding->xb_value = NULL;

next_turn:
  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val))
    {
      length_of_val = (int) BOX_ELEMENTS (val);
      items = (caddr_t *)val;
    }
  else
    {
      length_of_val = 1;
      items = &val;
    }
  for (item_in_val = 0; item_in_val < length_of_val; item_in_val++)
    {
      dk_free_tree (probe_binding->xb_value);
      probe_binding->xb_value = dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
      ((caddr_t **)(probe_binding->xb_value))[0] = (caddr_t *) box_copy_tree (items[item_in_val]);
      answer = xpf_arg_boolean (xqi, tree, ctx_xe, 2);	/*  Every call of the expression for testing of every item in changed context :) */
      if (is_every ? (!answer) : answer)
	goto done;
    }
  if (xqi_is_next_value (xqi, set))
    {
      val = xqi_raw_value (xqi, set);
      goto next_turn;
    }

done:
  xqi_pop_internal_bindings (xqi, internals_top_saved);

done_empty:
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) (ptrlong) (answer ? 1L : 0L));
}


void
xpf_some (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_some_or_every (xqi, tree, ctx_xe, 0);
}


void
xpf_every (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_some_or_every (xqi, tree, ctx_xe, 1);
}


void
xpf_for (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqi_binding_t *internals_top_saved = xqi->xqi_internals;
  xqi_binding_t *iter_binding = NULL;					/* Like probe_binding in xpf_some_or_every */
  caddr_t varname = xpf_arg (xqi, tree, ctx_xe, DV_UNAME, 0);		/* Name of iteration variable */
  XT * set = xpf_arg_tree (tree, 1);					/* Expression to be iterated */
  XT * lbody = xpf_arg_tree (tree, 2);					/* Loop body expression */
  caddr_t set_val;
  size_t length_of_set_val;
  size_t item_in_set_val;
  caddr_t *set_items;
  caddr_t lbody_val;
  size_t length_of_lbody_val;
  caddr_t *lbody_items;
  size_t buf_fill_len = 0;
  size_t buf_new_fill_len;
  size_t buf_item_ctr;
  size_t buf_alloc_len = 16;
  caddr_t *buf = NULL;
  caddr_t res_list;

  xqi_eval (xqi, set, ctx_xe);
  set_val = xqi_raw_value (xqi, set);

  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
  if (NULL == set_val)
    {
      XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_AT_END);
      XQI_SET (xqi, tree->_.xp_func.var->_.var.init, NULL);
      return;
    }

  iter_binding = xqi_push_internal_binding (xqi, varname);
  iter_binding->xb_value = NULL;
  buf = (caddr_t *)dk_alloc_box_zero (16 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, (caddr_t)buf);

next_turn:
  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (set_val))
    {
      length_of_set_val = (int) BOX_ELEMENTS (set_val);
      set_items = (caddr_t *)set_val;
    }
  else
    {
      length_of_set_val = 1;
      set_items = &set_val;
    }
  for (item_in_set_val = 0; item_in_set_val < length_of_set_val; item_in_set_val++)
    {
/*
      if (NULL == iter_binding->xb_value)
	iter_binding->xb_value = dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
      ((caddr_t **)(iter_binding->xb_value))[0] = box_copy_tree (set_items[item_in_set_val]);
*/
      dk_free_tree (iter_binding->xb_value);
      iter_binding->xb_value = dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
#ifdef XPATH_DEBUG
      if (xqi_set_odometer >= xqi_set_debug_start)
	dk_check_tree(set_items[item_in_set_val]);
#endif
      ((caddr_t **)(iter_binding->xb_value))[0] = (caddr_t *) box_copy_tree (set_items[item_in_set_val]);

      xqi_eval (xqi, lbody, ctx_xe);
      lbody_val = xqi_raw_value (xqi, lbody);
next_ret:
#ifdef XPATH_DEBUG
      if (xqi_set_odometer >= xqi_set_debug_start)
	dk_check_tree (lbody_val);
#endif
      if (NULL == lbody_val)
	continue;
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (lbody_val))
	{
	  length_of_lbody_val = (int) BOX_ELEMENTS (lbody_val);
	  lbody_items = (caddr_t *)lbody_val;
	}
      else
	{
	  length_of_lbody_val = 1;
	  lbody_items = &lbody_val;
	}
      buf_new_fill_len = buf_fill_len+length_of_lbody_val;
      if (buf_new_fill_len >= buf_alloc_len)
	{
	  caddr_t *buf2;
	  do buf_alloc_len *= 2; while (buf_new_fill_len >= buf_alloc_len);
	  buf2 = (caddr_t *) dk_alloc_box (buf_alloc_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  memcpy (buf2, buf, buf_fill_len * sizeof (caddr_t));
	  memset (buf2+buf_fill_len, 0, (buf_alloc_len - buf_fill_len) * sizeof (caddr_t));
	  box_tag_modify (buf, DV_ARRAY_OF_LONG);
	  buf = buf2;
	  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)buf);
	}
      for (buf_item_ctr = 0; buf_item_ctr < length_of_lbody_val; buf_item_ctr++)
	buf[buf_fill_len+buf_item_ctr] = box_copy_tree (lbody_items[buf_item_ctr]);
      buf_fill_len = buf_new_fill_len;
      if (xqi_is_next_value (xqi, lbody))
	{
	  lbody_val = xqi_raw_value (xqi, lbody);
	  goto next_ret;
	}
    }
  if (xqi_is_next_value (xqi, set))
    {
      set_val = xqi_raw_value (xqi, set);
      goto next_turn;
    }

  res_list = dk_alloc_box (buf_fill_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
  memcpy (res_list, buf, buf_fill_len * sizeof (caddr_t));
  box_tag_modify (buf, DV_ARRAY_OF_LONG);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, res_list);
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (res_list);
#endif
  xqi_pop_internal_bindings (xqi, internals_top_saved);
}


void
xpf_map (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  XT * set = xpf_arg_tree (tree, 0);					/* Expression to be iterated */
  XT * lbody = xpf_arg_tree (tree, 1);					/* Loop body expression */
  caddr_t set_val;
  size_t length_of_set_val;
  size_t item_in_set_val;
  caddr_t *set_items;
  caddr_t lbody_val;
  size_t length_of_lbody_val;
  caddr_t *lbody_items;
  size_t buf_fill_len = 0;
  size_t buf_new_fill_len;
  size_t buf_item_ctr;
  size_t buf_alloc_len = 16;
  caddr_t *buf = NULL;
  caddr_t res_list;

  xqi_eval (xqi, set, ctx_xe);
  set_val = xqi_raw_value (xqi, set);

  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);

  if (NULL == set_val)
    {
      XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_AT_END);
      XQI_SET (xqi, tree->_.xp_func.var->_.var.init, NULL);
      return;
    }

  buf = (caddr_t *)dk_alloc_box_zero (16 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, (caddr_t)buf);

next_turn:
  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (set_val))
    {
      length_of_set_val = (int) BOX_ELEMENTS (set_val);
      set_items = (caddr_t *)set_val;
    }
  else
    {
      length_of_set_val = 1;
      set_items = &set_val;
    }
  for (item_in_set_val = 0; item_in_set_val < length_of_set_val; item_in_set_val++)
    {
      caddr_t inner_ctx = set_items[item_in_set_val];
#ifdef XPATH_DEBUG
      if (xqi_set_odometer >= xqi_set_debug_start)
	dk_check_tree(set_items[item_in_set_val]);
#endif
      if (DV_XML_ENTITY != DV_TYPE_OF (inner_ctx))
        {
	  sqlr_new_error_xqi_xdl ("42000", "XPF??", xqi, "type error: attempt to use not-a-node value as a context node");
        }
      xqi_eval (xqi, lbody, (xml_entity_t *)inner_ctx);
      lbody_val = xqi_raw_value (xqi, lbody);
next_ret:
#ifdef XPATH_DEBUG
      if (xqi_set_odometer >= xqi_set_debug_start)
	dk_check_tree (lbody_val);
#endif
      if (NULL == lbody_val)
	continue;
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (lbody_val))
	{
	  length_of_lbody_val = (int) BOX_ELEMENTS (lbody_val);
	  lbody_items = (caddr_t *)lbody_val;
	}
      else
	{
	  length_of_lbody_val = 1;
	  lbody_items = &lbody_val;
	}
      buf_new_fill_len = buf_fill_len+length_of_lbody_val;
      if (buf_new_fill_len >= buf_alloc_len)
	{
	  caddr_t *buf2;
	  do buf_alloc_len *= 2; while (buf_new_fill_len >= buf_alloc_len);
	  buf2 = (caddr_t *) dk_alloc_box (buf_alloc_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	  memcpy (buf2, buf, buf_fill_len * sizeof (caddr_t));
	  memset (buf2+buf_fill_len, 0, (buf_alloc_len - buf_fill_len) * sizeof (caddr_t));
	  box_tag_modify (buf, DV_ARRAY_OF_LONG);
	  buf = buf2;
	  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)buf);
	}
      for (buf_item_ctr = 0; buf_item_ctr < length_of_lbody_val; buf_item_ctr++)
	buf[buf_fill_len+buf_item_ctr] = box_copy_tree (lbody_items[buf_item_ctr]);
      buf_fill_len = buf_new_fill_len;
      if (xqi_is_next_value (xqi, lbody))
	{
	  lbody_val = xqi_raw_value (xqi, lbody);
	  goto next_ret;
	}
    }
  if (xqi_is_next_value (xqi, set))
    {
      set_val = xqi_raw_value (xqi, set);
      goto next_turn;
    }

  res_list = dk_alloc_box (buf_fill_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
  memcpy (res_list, buf, buf_fill_len * sizeof (caddr_t));
  box_tag_modify (buf, DV_ARRAY_OF_LONG);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, res_list);
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (res_list);
#endif
}


void
xpf_let (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqi_binding_t *internals_top_saved = xqi->xqi_internals;
  int argctr, argno, varctr, varno;
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.res);
  argno = (int) tree->_.xp_func.argcount;
  if (!(argno & 0x1))
    sqlr_new_error_xqi_xdl ("42000", "XPF02", xqi, "Wrong number of arguments for XPATH function let(), maybe internal XQuery error");
  varno = (argno - 1) / 2;
  XQI_SET (xqi, tree->_.xp_func.res, NULL);
  for (argctr = varctr = 0; varctr < varno; varctr++)
    {
      caddr_t varname = xpf_arg (xqi, tree, ctx_xe, DV_UNAME, argctr++);
      xqi_binding_t * xb;
      xpf_arg_list (xqi, tree, ctx_xe, argctr++, res_ptr);
      xb = xqi_push_internal_binding (xqi, varname);
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (res_ptr[0]))
	xb->xb_value = res_ptr[0];
      else
	{
	  xb->xb_value = dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
	  ((caddr_t *)(xb->xb_value))[0] = res_ptr[0];
	}
      res_ptr[0] = NULL;
    }
  xpf_arg_list (xqi, tree, ctx_xe, argctr, res_ptr);
  xqi_pop_internal_bindings (xqi, internals_top_saved);
}


/* This function should not have metadata described in the init. */
void xpf_call_udf (xp_instance_t * top_xqi, XT * tree, xml_entity_t * ctx_xe)
{
  XT *bodytree, *defun = (XT *)(unbox_ptrlong (tree->_.xp_func.qname));
  int argvarctr, stepvar, itervarno, scalarvarno, argvarno = (int) defun->_.defun.argcount;
  ptrlong iteridx;
  caddr_t **bindings = (caddr_t **)dk_alloc_box_zero (argvarno * sizeof (xqi_binding_t *), DV_ARRAY_OF_LONG);
  caddr_t **sets = (caddr_t **)dk_alloc_box_zero (argvarno * sizeof(caddr_t), DV_ARRAY_OF_POINTER);
  ptrlong *setsizes = (ptrlong *)dk_alloc_box_zero (argvarno * sizeof(ptrlong), DV_ARRAY_OF_LONG);
  ptrlong *setiters = (ptrlong *)dk_alloc_box_zero (argvarno * sizeof(ptrlong), DV_ARRAY_OF_LONG);
  caddr_t *res_ptr = XQI_ADDRESS(top_xqi,tree->_.xp_func.res);
  xp_instance_t *call_xqi = xqr_instance (defun->_.defun.body, top_xqi->xqi_qi);
  caddr_t *tmp = (caddr_t *)list (6, NULL, bindings, sets, setsizes, setiters, call_xqi);
  caddr_t lst;
  size_t fill_len = 0, new_fill_len, alloc_len = 16;
  caddr_t *buf = (caddr_t *)dk_alloc_box_zero (16 * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
  if (NULL == top_xqi->xqi_doc_cache)
    top_xqi->xqi_doc_cache = xml_doc_cache_alloc (&(top_xqi->xqi_doc_cache));
  call_xqi->xqi_doc_cache = top_xqi->xqi_doc_cache;
  call_xqi->xqi_return_attrs_as_nodes = top_xqi->xqi_return_attrs_as_nodes;
  call_xqi->xqi_xpath2_compare_rules = top_xqi->xqi_xpath2_compare_rules;
  bodytree = defun->_.defun.body->xqr_tree;
  XQI_SET (top_xqi, tree->_.xp_func.tmp, (caddr_t)tmp);
  XP_SET (res_ptr, (caddr_t)(buf));
/* Initialization */
  for (argvarctr = itervarno = scalarvarno = 0; argvarctr < argvarno; argvarctr++)
    {
      XT *param = defun->_.defun.params[argvarctr];
      caddr_t varname = param->_.paramdef.name;
      xqi_binding_t * xb;
      int varidx;
      if (param->_.paramdef.is_iter)
	varidx = itervarno++;
      else
	varidx = argvarno - (++scalarvarno);
      xpf_arg_list (top_xqi, tree, ctx_xe, argvarctr, (caddr_t *)(sets+varidx));
      xb = xqi_push_internal_binding (call_xqi, varname);
      if (param->_.paramdef.is_iter)
	{
	  xb->xb_value = dk_alloc_box_zero (sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
	  bindings[varidx] = ((caddr_t *)(xb->xb_value));
	  setsizes[varidx] = BOX_ELEMENTS (sets[varidx]);
	  if (0 == setsizes[varidx])
	    {
	      XP_SET (res_ptr, dk_alloc_box(0, DV_ARRAY_OF_XQVAL));
	      return;
	    }
          bindings[varidx][0] = sets[varidx][0];
          sets[varidx][0] = NULL;
	}
      else
	{
	  xb->xb_value = (caddr_t)sets[varidx];
	}
    }
/* Cartesian iteration */
  for (;;)
    {
      caddr_t el;
    /* Calculate one result */
#if 1
      xpf_arg_list_impl (call_xqi, bodytree, ctx_xe, tmp);
      el = tmp[0];
#else
      xqi_eval (call_xqi, bodytree, ctx_xe);
      el = xqi_raw_value (call_xqi, bodytree);
#endif
    /* Append current result to total list of results */
      if (NULL != el)
	{
	  caddr_t *subitems;
	  size_t subctr, subcount;
next_val:
	  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(el))
	    {
	      subitems = (caddr_t *)el;
	      subcount = BOX_ELEMENTS(el);
	    }
	  else
	    {
	      subitems = (caddr_t *)(&el);
	      subcount = 1;
	    }
	  new_fill_len = fill_len + subcount;
	  if (alloc_len < new_fill_len)
	    {
	      caddr_t *buf2;
	      while (alloc_len < new_fill_len) alloc_len *= 2;
	      buf2 = (caddr_t *)dk_alloc_box_zero (alloc_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
	      memcpy (buf2, buf, fill_len * sizeof (caddr_t));
	      box_tag_modify (buf, DV_ARRAY_OF_LONG);
	      buf = buf2;
	      XP_SET (res_ptr, (caddr_t)buf);
	    }
	  for (subctr = 0; subctr < subcount; subctr++)
	    buf[fill_len++] = box_copy_tree (subitems[subctr]);
	  if (xqi_is_next_value (call_xqi, bodytree))
	    {
	      el = xqi_raw_value (call_xqi, bodytree);
	      goto next_val;
	    }
	}
    /* Reassign variables */
    stepvar = itervarno-1;
    for (;;)
      {
	if (stepvar<0)
	  goto done;
	iteridx = setiters[stepvar];
	sets[stepvar][iteridx] = bindings[stepvar][0];
	iteridx++;
	if (iteridx >= setsizes[stepvar])
	  {
	    bindings[stepvar][0] = sets[stepvar][0];
	    sets[stepvar][0] = NULL;
	    setiters[stepvar] = 0;
            stepvar--;
	    continue;
	  }
        bindings[stepvar][0] = sets[stepvar][iteridx];
	setiters[stepvar] = iteridx;
        sets[stepvar][iteridx] = NULL;
	break;
      }
    }
done:
  XQI_SET (top_xqi, tree->_.xp_func.tmp, NULL);
  lst = dk_alloc_box (fill_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
  memcpy (lst, buf, fill_len * sizeof (caddr_t));
  box_tag_modify (buf, DV_ARRAY_OF_LONG);
  if (NULL != tree->_.xp_func.var)
    {
      XQI_SET_INT (top_xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
      XQI_SET (top_xqi, tree->_.xp_func.var->_.var.init, lst);
      XQI_SET (top_xqi, tree->_.xp_func.var->_.var.res, NULL);
      XQI_SET_INT (top_xqi, tree->_.xp_func.var->_.var.inx, 0);
    }
  else
    {
      XP_SET (res_ptr, lst);
    }
}


void
xpf_cartesian_product_loop (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xqi_binding_t *internals_top_saved = xqi->xqi_internals;
  int argctr, varctr, stepvar;
  ptrlong iteridx;
  int argno = (int) tree->_.xp_func.argcount;
  XT * body = xpf_arg_tree (tree, argno-1);
  int varno = (argno - 1) / 2;
  caddr_t **bindings = (caddr_t **)dk_alloc_box_zero (varno * sizeof (xqi_binding_t *), DV_ARRAY_OF_LONG);
  caddr_t **sets = (caddr_t **)dk_alloc_box_zero (varno * sizeof(caddr_t), DV_ARRAY_OF_POINTER);
  ptrlong *setsizes = (ptrlong *)dk_alloc_box_zero (varno * sizeof(ptrlong), DV_ARRAY_OF_LONG);
  ptrlong *setiters = (ptrlong *)dk_alloc_box_zero (varno * sizeof(ptrlong), DV_ARRAY_OF_LONG);
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.res);
  caddr_t lst;
  caddr_t tmp = list (4, bindings, sets, setsizes, setiters);
  caddr_t *buf = (caddr_t *)dk_alloc_box_zero (16 * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
  size_t fill_len = 0, new_fill_len, alloc_len = 16;
  QI_CHECK_STACK (xqi->xqi_qi, &alloc_len, 2000);
  if (xqi->xqi_qi->qi_client->cli_terminate_requested)
    sqlr_new_error_xqi_xdl ("37000", "SR369", xqi, "XSLT aborted by client request");
  XQI_SET (xqi, tree->_.xp_func.tmp, tmp);
  XP_SET (res_ptr, (caddr_t)(buf));
  if (!(argno & 0x1))
    sqlr_new_error_xqi_xdl ("42000", "XPF03", xqi, "Internal error in XQuery compiler: invalid Cartesian product");
/* Initialization */
  for (argctr = varctr = 0; varctr < varno; varctr++)
    {
      caddr_t varname = xpf_arg (xqi, tree, ctx_xe, DV_UNAME, argctr++);
      xqi_binding_t * xb;
      xpf_arg_list (xqi, tree, ctx_xe, argctr++, (caddr_t *)(sets+varctr));
      xb = xqi_push_internal_binding (xqi, varname);
      xb->xb_value = dk_alloc_box_zero (sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
      bindings[varctr] = ((caddr_t *)(xb->xb_value));
      setsizes[varctr] = BOX_ELEMENTS (sets[varctr]);
      if (0 == setsizes[varctr])
	{
	  XP_SET (res_ptr, dk_alloc_box(0, DV_ARRAY_OF_XQVAL));
	  xqi_pop_internal_bindings (xqi, internals_top_saved);
	  return;
	}
      bindings[varctr][0] = sets[varctr][0];
      sets[varctr][0] = NULL;
    }
/* Cartesian iteration */
  for (;;)
    {
      caddr_t el;
    /* Calculate one result */
      xqi_eval (xqi, body, ctx_xe);
      el = xqi_raw_value (xqi, body);
    /* Append current result to total list of results */
      if (NULL != el)
	{
	  caddr_t *subitems;
	  size_t subctr, subcount;
next_val:
	  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(el))
	    {
	      subitems = (caddr_t *)el;
	      subcount = BOX_ELEMENTS(el);
	    }
	  else
	    {
	      subitems = (caddr_t *)(&el);
	      subcount = 1;
	    }
	  new_fill_len = fill_len + subcount;
	  if (alloc_len < new_fill_len)
	    {
	      caddr_t *buf2;
	      while (alloc_len < new_fill_len) alloc_len *= 2;
	      buf2 = (caddr_t *)dk_alloc_box_zero (alloc_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
	      memcpy (buf2, buf, fill_len * sizeof (caddr_t));
	      box_tag_modify (buf, DV_ARRAY_OF_LONG);
	      buf = buf2;
	      XP_SET (res_ptr, (caddr_t)buf);
	    }
	  for (subctr = 0; subctr < subcount; subctr++)
	    buf[fill_len++] = box_copy_tree (subitems[subctr]);
	  if (xqi_is_next_value (xqi, body))
	    {
	      el = xqi_raw_value (xqi, body);
	      goto next_val;
	    }
	}
    /* Reassign variables */
    stepvar = varno-1;
    for (;;)
      {
	if (stepvar<0)
	  goto done;
	iteridx = setiters[stepvar];
	sets[stepvar][iteridx] = bindings[stepvar][0];
	iteridx++;
	if (iteridx >= setsizes[stepvar])
	  {
	    bindings[stepvar][0] = sets[stepvar][0];
	    sets[stepvar][0] = NULL;
	    setiters[stepvar] = 0;
            stepvar--;
	    continue;
	  }
        bindings[stepvar][0] = sets[stepvar][iteridx];
	setiters[stepvar] = iteridx;
        sets[stepvar][iteridx] = NULL;
	break;
      }
    }
done:
  lst = dk_alloc_box (fill_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
  memcpy (lst, buf, fill_len * sizeof (caddr_t));
  box_tag_modify (buf, DV_ARRAY_OF_LONG);
  if (NULL != tree->_.xp_func.var)
    {
      XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
      XQI_SET (xqi, tree->_.xp_func.var->_.var.init, lst);
      XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
      XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
    }
  else
    {
      XP_SET (res_ptr, lst);
    }
  xqi_pop_internal_bindings (xqi, internals_top_saved);
}


void
xpf_if (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int ctrl = xpf_arg_boolean (xqi, tree, ctx_xe, 0);
  xpf_arg_list (xqi, tree, ctx_xe, (ctrl ? 1 : 2), XQI_ADDRESS(xqi,tree->_.xp_func.res));
}


void
xpf_position (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t pos = box_num_nonull (XQI_GET_INT (xqi, unbox ((caddr_t) tree->_.xp_func.argtrees[0])));
  XQI_SET (xqi, tree->_.xp_func.res, pos);
}

void
xpf_last (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int place = (int) unbox ((box_t) tree->_.xp_func.argtrees[0]);
  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (XQI_GET_INT (xqi, place)));
}


void
xpf_sum (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int argcount = (int) tree->_.xp_func.argcount;
  int argctr;
  caddr_t sum;
  sum = box_num (0);
  for (argctr = 0; argctr < argcount; argctr++)
    {
      XT * arg = xpf_arg_tree (tree, argctr);
      caddr_t addon;
      xqi_eval (xqi, arg, ctx_xe);
      addon = xqi_value (xqi, arg, DV_NUMERIC);
      if (!addon)
	continue;
      for (;;)
	{
	  caddr_t sum2 = box_add (sum, addon, NULL, NULL);
	  dk_free_box (sum);
	  sum = sum2;
	  if (!xqi_is_next_value (xqi, arg))
	    break;
	  addon = xqi_value (xqi, arg, DV_NUMERIC);
	}
    }
  XQI_SET (xqi, tree->_.xp_func.res, sum ? sum : box_num_nonull(0));
}


#define GENERAL_COMPARISON_FUNC(name, namestr, comp_op, comp_val) \
caddr_t name (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)\
{\
  caddr_t arg1 = bif_arg (qst, args, 0, namestr);\
  caddr_t arg2 = bif_arg (qst, args, 1, namestr);\
  if (comp_val comp_op cmp_boxes(arg1,arg2,args[0]->ssl_sqt.sqt_collation,args[1]->ssl_sqt.sqt_collation)) \
	return (box_num_nonull(1)); \
  else \
	return (box_num_nonull(0));\
}


void
xpf_min (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int argcount = (int) tree->_.xp_func.argcount;
  int argctr;
  caddr_t res = NULL;
  for (argctr = 0; argctr < argcount; argctr++)
    {
      caddr_t *subelems;
      size_t subelcount, subelctr;
      XT * arg = xpf_arg_tree (tree, argctr);
      caddr_t el;
      xqi_eval (xqi, arg, ctx_xe);
      el = xqi_raw_value (xqi, arg);
      if (NULL == el)
	continue;
next_val:
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(el))
	{
	  subelems = (caddr_t *)el;
	  subelcount = BOX_ELEMENTS(el);
	}
      else
	{
	  subelems = &el;
	  subelcount = 1;
	}
      for (subelctr = 0; subelctr < subelcount; subelctr++)
	{
	  caddr_t try_val = xp_box_number(subelems[subelctr]);
	  if (NULL == res || DVC_LESS == cmp_boxes(try_val, res, NULL, NULL))
	    {
	      res = try_val;
	      XQI_SET (xqi, tree->_.xp_func.res, res);
	    }
	  else
	    dk_free_box (try_val);
	}
      if (xqi_is_next_value (xqi, arg))
	{
	  el = xqi_raw_value (xqi, arg);
	  goto next_val;
	}
    }
  if (NULL == res)
    XQI_SET (xqi, tree->_.xp_func.res, NULL);
}


void
xpf_max (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int argcount = (int) tree->_.xp_func.argcount;
  int argctr;
  caddr_t res = NULL;
  for (argctr = 0; argctr < argcount; argctr++)
    {
      caddr_t *subelems;
      size_t subelcount, subelctr;
      XT * arg = xpf_arg_tree (tree, argctr);
      caddr_t el;
      xqi_eval (xqi, arg, ctx_xe);
      el = xqi_raw_value (xqi, arg);
      if (NULL == el)
	continue;
next_val:
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(el))
	{
	  subelems = (caddr_t *)el;
	  subelcount = BOX_ELEMENTS(el);
	}
      else
	{
	  subelems = &el;
	  subelcount = 1;
	}
      for (subelctr = 0; subelctr < subelcount; subelctr++)
	{
	  caddr_t try_val = xp_box_number(subelems[subelctr]);
	  if (NULL == res || DVC_GREATER == cmp_boxes(try_val, res, NULL, NULL))
	    {
	      res = try_val;
	      XQI_SET (xqi, tree->_.xp_func.res, res);
	    }
	  else
	    dk_free_box (try_val);
	}
      if (xqi_is_next_value (xqi, arg))
	{
	  el = xqi_raw_value (xqi, arg);
	  goto next_val;
	}
    }
  if (NULL == res)
    XQI_SET (xqi, tree->_.xp_func.res, NULL);
}


void
xpf_idiv_operator (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  ptrlong i1 = (ptrlong) xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 0);
  ptrlong i2 = (ptrlong) xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 1);
  if (0 == i2)
    sqlr_new_error_xqi_xdl ("22012", "SR090", xqi, "Division by 0.");
  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (i1 / i2));
}


void
xpf_avg (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int argcount = (int) tree->_.xp_func.argcount;
  int argctr;
  caddr_t sum, avg, ctr_box;
  long ctr = 0;
  sum = box_num (0);
  for (argctr = 0; argctr < argcount; argctr++)
    {
      XT * arg = xpf_arg_tree (tree, argctr);
      caddr_t addon;
      xqi_eval (xqi, arg, ctx_xe);
      addon = xqi_value (xqi, arg, DV_NUMERIC);
      if (!addon)
	continue;
      for (;;)
	{
	  caddr_t sum2 = box_add (sum, addon, NULL, NULL);
	  dk_free_box (sum);
	  sum = sum2;
	  ctr++;
	  if (!xqi_is_next_value (xqi, arg))
	    break;
	  addon = xqi_value (xqi, arg, DV_NUMERIC);
	}
    }
  if (0 == ctr)
    {
      XQI_SET (xqi, tree->_.xp_func.res, NULL);
      return;
    }
  ctr_box = box_num (ctr);
  avg = box_div (sum, ctr_box, NULL, NULL);
  dk_free_box (sum);
  dk_free_box (ctr_box);
  XQI_SET (xqi, tree->_.xp_func.res, avg ? avg : box_num_nonull ((ptrlong)(avg)));
}


void
xpf_concat (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t res;
  int len = 0, fill = 0, inx;
  int n_args = (int) tree->_.xp_func.argcount;
  dk_set_t lst = NULL;
  for (inx = 0; inx < n_args; inx++)
    {
      caddr_t str = xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, inx);
      if (str && box_length (str))
	{
	  len += box_length (str) - 1;
	  dk_set_push (&lst, (void*) str);
	}
    }
  res = dk_alloc_box (len + 1, DV_SHORT_STRING);
  fill = 0;
  lst = dk_set_nreverse (lst);
  DO_SET (caddr_t, str, &lst)
    {
      if (str && box_length (str))
	{
	  memcpy (res + fill, str, box_length (str) - 1);
	  fill += box_length (str) - 1;
	}
    }
  END_DO_SET();
  res[len] = 0;
  dk_set_free (lst);
  XQI_SET (xqi, tree->_.xp_func.res, res);
}


void
xpf_substring_before  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str1 = xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 0);
  caddr_t str2 = xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 1);
  char * pt = NULL;
  if (DV_STRINGP (str1) && DV_STRINGP (str2))
    pt = strstr (str1, str2);
  if (!pt)
    XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (""));
  else
    XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_substr (str1, 0, (int) (pt - str1)));
}


void
xpf_substring_after  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str1 = xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 0);
  caddr_t str2 = xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 1);
  char * pt = NULL;
  if (DV_STRINGP (str1) && DV_STRINGP (str2))
    pt = strstr (str1, str2);
  if (!pt)
    XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (""));
  else
    XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_substr (str1, (int) ((pt - str1) + strlen (str2)), box_length (str1) - 1));
}

#define UTF8_IS_SINGLECHAR(c) (!((c) & 0x80))
#define UTF8_IS_HEADCHAR(c) (UTF8_IS_SINGLECHAR(c) || (0xc0 == (c & 0xc0)))

void
xpf_substring  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str = xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 0);
  long n2, n1 = (long) unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 1));
  long str_utf8len = 0;
  unsigned char *cut_begin = NULL, *cut_end = NULL, *tail = NULL;
  if (!DV_STRINGP (str))
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (""));
      return;
    }
  n2 = (long) (tree->_.xp_func.argcount > 2
    ? n1 + unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 2))
    : 0x7fffffffL);
  if (n1 <= 0)
    cut_begin = (unsigned char *)str;
  if (n2 <= 0)
    cut_end = (unsigned char *)str;
  if ((NULL == cut_begin) || (NULL == cut_end))
    {
      for (tail = (unsigned char *)str; '\0' != tail[0]; tail++)
	{
	  unsigned char c = tail[0];
	  if (UTF8_IS_HEADCHAR(c))
	    {
	      str_utf8len++;
	      if (n1 == str_utf8len)
		cut_begin = tail;
	      if (n2 == str_utf8len)
		cut_end = tail;
	    }
	}
    }
  if (NULL == cut_begin)
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (""));
      return;
    }
  if (NULL == cut_end)
    cut_end = tail;
  if (cut_end < cut_begin)
    cut_end = cut_begin;
  XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_nchars ((char *)cut_begin, cut_end-cut_begin));
}


void
xpf_string_length  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
  long len = 0;
  unsigned char *tail;
  if (!DV_STRINGP (str))
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (0));
      return;
    }
  for (tail = (unsigned char *)str; '\0' != tail[0]; tail++)
    {
      unsigned char c = tail[0];
      if (UTF8_IS_HEADCHAR(c))
	len++;
    }
  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (len));
}


void
xpf_contains  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str1 = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
  caddr_t str2 = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 1);
  ptrlong flag = (NULL != strstr (str1, str2));
  XQI_SET (xqi, tree->_.xp_func.res,  (caddr_t) flag);
}


void
xpf_starts_with  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str1 = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
  caddr_t str2 = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 1);
  size_t l1 = strlen (str1);
  size_t l2 = strlen (str2);
  ptrlong flag = l1 >= l2 && 0 == memcmp (str1, str2, l2);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) flag);
}


void
xpf_ends_with  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str1 = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
  caddr_t str2 = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 1);
  size_t l1 = strlen (str1);
  size_t l2 = strlen (str2);
  ptrlong flag = l1 >= l2 && 0 == memcmp (str1+l1-l2, str2, l2);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) flag);
}

#define XPF_TRANSLATE_DELETE ((caddr_t)(-1))


void
xpf_translate  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  const char *text = (char *) xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
  const char *text_tail, *text_end;
  char *res, *res_tail, *res_end, *res_aux;
  const unsigned char *org, *org_tail;
  const unsigned char *repl, *repl_tail;
  unichar *uniorg;
  unichar *unirepl;
  unichar text_curchr;
  size_t text_strlen, res_strlen;
  size_t org_idx1, org_idx2, org_items, org_strlen;
  size_t repl_items, repl_strlen;
  int qidx;
  unsigned char quickxlat[0x100];
  if ('\0' == text[0])
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_copy (text));
      return;
    }
  /* Translations strings should be retrieved */
  org = (unsigned char *)xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 1);
  if ('\0' == org[0])
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_copy (text));
      return;
    }
  repl = (unsigned char *)xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 2);
  org_strlen = strlen ((const char *)org);
  repl_strlen = strlen ((const char *)repl);
  text_strlen = strlen (text);
  text_end = text + text_strlen;
  /* Trying to run good case xlat algorithm: */
  memset (quickxlat, 0, sizeof(quickxlat));
  for (qidx = 0; qidx < org_strlen; qidx++)
    {
      char org_c = org[qidx];
      if (org_c & ~0x7F)
	goto common_case;
      if ('\0' == quickxlat[(unsigned char)(org_c)])
	{
	  unsigned char repl_c;
	  if (qidx >= repl_strlen)
	    repl_c = 0xFF;
	  else
	    {
	      repl_c = repl[qidx];
  	      if (('\0' == repl_c) || (repl_c & ~0x7F))
	        goto common_case;
	    }
	  quickxlat[(unsigned char)(org_c)] = repl_c;
	}
    }
  /* At this point, we know that we may apply good case xlat. Let's do it */
  {
      int samelength = 1;
      for (qidx = 0; qidx < 0x80; qidx++)
	{
	  switch(quickxlat[qidx])
	    {
	    case 0:
	      quickxlat[qidx] = qidx;
	      break;
	    case 0xFF:
	      samelength = 0;
	      break;
	    }
	}
      for (qidx = 0x80; qidx < 0x100; qidx++)
	quickxlat[qidx] = qidx;
      if (samelength)
	res_strlen = text_strlen;
      else
	{
	  res_strlen = 0;
	  for (text_tail = text; text_tail < text_end; text_tail++)
	    if (0xFF != quickxlat[(unsigned char)(text_tail[0])])
	      res_strlen++;
	}
      res = dk_alloc_box(res_strlen+1, DV_SHORT_STRING);
      res_tail = res;
      for (text_tail = text; text_tail < text_end; text_tail++)
	{
	  unsigned char text_c = text_tail[0];
	  unsigned char res_c = quickxlat[text_c];
	  if (0xFF != res_c)
	    (res_tail++)[0] = res_c;
	}
      res [res_strlen] = '\0';
      XQI_SET (xqi, tree->_.xp_func.res, res);
      return;
   }

common_case:
  /* Translations strings should be decoded */
  uniorg = (unichar *)dk_alloc_box((1+org_strlen)*sizeof(unichar), DV_SHORT_STRING);
  unirepl = (unichar *)dk_alloc_box_zero((1+((org_strlen>repl_strlen)?org_strlen:repl_strlen))*sizeof(unichar), DV_SHORT_STRING);
  org_tail = org;
  repl_tail = repl;
  org_items = eh_decode_buffer__UTF8 (uniorg, (int) (1+org_strlen), (__constcharptr *)(&org_tail), (__constcharptr)(org+org_strlen));
  repl_items = eh_decode_buffer__UTF8 (unirepl, (int) (1+repl_strlen), (__constcharptr *)(&repl_tail), (__constcharptr)(repl+repl_strlen));
  if (repl_items < org_items)
    {
      if (((signed int)repl_items) < 0)
        repl_items = 0;
      memset(unirepl+repl_items, ~0, sizeof(unichar)*(org_items-repl_items));
    }
  /* Poorly written insertion sort with stable removal of dupes */
  org_idx1 = 1;
  while (org_idx1 < org_items)
    {
      if (uniorg[org_idx1-1] < uniorg[org_idx1])
	{
	  org_idx1++;
	  continue;
	}
      if (uniorg[org_idx1-1] == uniorg[org_idx1])
	{
	  uniorg[org_idx1] = uniorg[org_items-1];
	  unirepl[org_idx1] = unirepl[org_items-1];
	  org_items--;
	  continue;
	}
      for (org_idx2 = 0; org_idx2 < org_idx1; org_idx2++)
	{
	  if (uniorg[org_idx2] < uniorg[org_idx1])
	    continue;
	  if (uniorg[org_idx2] > uniorg[org_idx1])
	    {
	      unichar tmp;
	      tmp = uniorg[org_idx2]; uniorg[org_idx2] = uniorg[org_idx1]; uniorg[org_idx1] = tmp;
	      tmp = unirepl[org_idx2]; unirepl[org_idx2] = unirepl[org_idx1]; unirepl[org_idx1] = tmp;
	      org_idx1 = org_idx2+1;
	      break;
	    }
	  uniorg[org_idx1] = uniorg[org_items-1];
	  unirepl[org_idx1] = unirepl[org_items-1];
	  org_items--;
	  break;
	}
    }
  /* Translation */
  res_strlen = text_strlen*MAX_UTF8_CHAR;
  if (res_strlen >= 10000000)
    res_strlen = 10000000-1;
  res = dk_alloc_box(res_strlen+1, DV_SHORT_STRING);
  text_tail = text;
  res_tail = res; res_end = res+res_strlen;
  while (0 < (text_curchr = eh_decode_char__UTF8 (&text_tail, text_end)))
    {
/* The most popular cases are upper/lowercase, with alphabet as 2-nd arg.
   and recollation, with charset interval as 2-nd arg. For them, the first guess will be right */
      int search_pos = text_curchr - uniorg[0];
      if (search_pos < 0)	/* If negative, text_curchr is less than the smallest translatable */
	goto search_complete;
      if (search_pos >= org_items)
        search_pos = org_items - 1;
      if (text_curchr > uniorg[org_items-1])
	goto search_complete;
      if (text_curchr == uniorg[search_pos])
	{
	  text_curchr = unirepl[search_pos];
	  goto search_complete;
	}
      else
	{
	  int step = (int) org_items;
	  search_pos = (int) (org_items >> 1);
	  for (;;)
	    {
	      unichar org_curchr = uniorg[search_pos];
	      if (text_curchr == org_curchr)
		{
		  text_curchr = unirepl[search_pos];
		  break;
		}
	      if (1 == step)
		break;
	      step = (step+1) >> 1;
	      if (text_curchr > org_curchr)
		{
		  int newpos = search_pos + step;
		  if (newpos < org_items)
		    search_pos = newpos;
		}
	      else
		{
		  search_pos -= step;
		  if (search_pos < 0)
		    search_pos = 0;
		}
	    }
	}
search_complete:
      if (~0 == text_curchr)
	continue;
      res_aux = eh_encode_char__UTF8(text_curchr, res_tail, res_end);
      if (NULL == res_aux)
	{
	  dk_free_box ((caddr_t)res);
	  dk_free_box ((caddr_t)uniorg);
	  dk_free_box ((caddr_t)unirepl);
	  sqlr_new_error_xqi_xdl ("XP001", "XPF07", xqi, "Too long string passed as argument 1 to XPATH function translate(), the result of translation is too long");
	}
      res_tail = res_aux;
    }
  res_tail[0] = '\0';
  XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_nchars (res, res_tail - res));
  dk_free_box (res);
  dk_free_box ((caddr_t)uniorg);
  dk_free_box ((caddr_t)unirepl);
}
/*#endif*/


void
xpf_replace (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t str = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
  caddr_t org = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 1);
  caddr_t repl = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 2);
  size_t str_l = strlen(str);
  size_t org_l = strlen(org);
  size_t repl_l = strlen(repl);
  ptrlong repldiff = repl_l - org_l;
  int repl_ctr = 0;
  char *src_ptr;
  char *src_search_stop = str + str_l - org_l;	/* There's no sense to search after this point. */
  char *res, *tail;
  ptrlong res_l;
  if (0 == org_l)
    sqlr_new_error_xqi_xdl ("XP001", "XPF08", xqi, "Empty string passed as argument 2 to XPATH function replace()");
  if (0 != repldiff)
    { /* If length changes, we should know the number of replacements in order to calculate the length of result */
      for (src_ptr = str; src_ptr <= src_search_stop; /* no step */)
	{
	  char *next_occurrence = strstr (src_ptr, org);
	  if (NULL == next_occurrence)
	    break;
	  repl_ctr++;
	  src_ptr = next_occurrence + org_l;
	}
      if (0 == repl_ctr)
	{ /* Plain copying in case of 0 replacements */
	  XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_nchars (str, str_l));
	  return;
	}
      res_l = str_l + (repl_ctr * repldiff);
      tail = res = dk_alloc_box (res_l+1, DV_SHORT_STRING);
      res[res_l] = '\0';
      for (src_ptr = str; src_ptr <= src_search_stop; /* no step */)
	{
	  char *next_occurrence = strstr (src_ptr, org);
	  size_t shift;
	  if (NULL == next_occurrence)
	    break;
	  shift = next_occurrence - src_ptr;
	  memcpy (tail, src_ptr, shift);
	  tail += shift;
	  memcpy (tail, repl, repl_l);
	  tail += repl_l;
#ifdef DEBUG
	  repl_ctr--;
#endif
	  src_ptr = next_occurrence + org_l;
	}
      memcpy (tail, src_ptr, str_l - (src_ptr-str));
#ifdef DEBUG
      tail += str_l - (src_ptr-str);
#endif
#ifdef DEBUG
      if ((0 != repl_ctr) || (tail != res+res_l))
	GPF_T1("Internal error in translate() XPATH function");
#endif
      XQI_SET (xqi, tree->_.xp_func.res, res);
      return;
    }
/* If length is the same, we may "overtype" over exact copy. */
  res =	box_dv_short_nchars (str, str_l);
  for (src_ptr = str; src_ptr <= src_search_stop; /* no step */)
    {
      char *next_occurrence = strstr (src_ptr, org);
      if (NULL == next_occurrence)
	break;
      memcpy (res + (next_occurrence - str), repl, org_l);
      src_ptr = next_occurrence + org_l;
    }
  XQI_SET (xqi, tree->_.xp_func.res, res);
}


#define is_ws(c) \
  (c == ' ' || c == '\t' || c == '\r' || c == '\n')


void
xpf_normalize_space  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int ws_emitted = 1;
  size_t inx, len;
  dk_session_t * string;
  caddr_t str;
  xpf_string (xqi, tree, ctx_xe);
  str = XQI_GET (xqi, tree->_.xp_func.res);
  len = strlen (str);
  string = strses_allocate ();
  for (inx = 0; inx < len; inx++)
    {
      if (is_ws (str[inx]))
	{
	  while (is_ws (str[inx]))
	    inx++;

	  if (inx == len)
	    break;
	  if (!ws_emitted)
	    {
	      session_buffered_write_char (' ', string);
	      ws_emitted = 1;
	    }
	}
      ws_emitted = 0;
      session_buffered_write_char (str[inx], string);
    }
  XQI_SET (xqi, tree->_.xp_func.res, strses_string (string));
  strses_free (string);
}

void
xpf_abs (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t res;
  dtp_t dtp;
  xpf_number (xqi, tree, ctx_xe);
  res = XQI_GET (xqi, tree->_.xp_func.res);
  dtp = DV_TYPE_OF (res);
  switch (dtp)
    {
    case DV_LONG_INT:
      {
        boxint v = unbox (res);
        if (v < 0)
          v = -v;
        XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (v));
        return;
      }
    case DV_DOUBLE_FLOAT:
      {
        double v = unbox_double (res);
        if (v < 0)
          v = -v;
        XQI_SET (xqi, tree->_.xp_func.res, box_double (v));
        return;
      }
    case DV_SINGLE_FLOAT:
      {
        float v = unbox_float (res);
        if (v < 0)
          v = -v;
        XQI_SET (xqi, tree->_.xp_func.res, box_float (v));
        return;
      }
    case DV_NUMERIC:
      {
        caddr_t v = box_copy (res);
        ((numeric_t)v)->n_neg = 0;
	XQI_SET (xqi, tree->_.xp_func.res, v);
	return;
      }
    }
}


#define XPF_ROUND(n, f) \
void  \
n (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe) \
{ \
  caddr_t res; \
  dtp_t dtp; \
  xpf_number (xqi, tree, ctx_xe); \
  res = XQI_GET (xqi, tree->_.xp_func.res); \
  dtp = DV_TYPE_OF (res); \
  switch (dtp) \
    { \
    case DV_LONG_INT: \
      return; \
    case DV_DOUBLE_FLOAT: \
      XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull ((long) (f (unbox_double (res))))); \
      return; \
    case DV_SINGLE_FLOAT: \
      XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull ((long) (f (unbox_float (res))))); \
      return; \
    case DV_NUMERIC: \
      { \
	double dt; \
	numeric_to_double ((numeric_t) res, &dt); \
	XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull ((long) (f (dt)))); \
	return; \
      } \
    } \
}


double
virt_rint (double x)
{
  return floor (x + 0.5L);
}


double
virt_r05to2 (double x)
{
  double flr = floor (x + 0.5L);
  if ((x == (flr + 0.5L)) && (0 != ((long)flr % 2)))
    return flr + 1;
  else if ((x == (flr - 0.5L)) && (0 != ((long)flr % 2)))
    return flr - 1;
  return flr;
}

XPF_ROUND (xpf_round_half_to_even, virt_r05to2)
XPF_ROUND (xpf_round_number, virt_rint)
XPF_ROUND (xpf_ceiling, ceil)
XPF_ROUND (xpf_floor, floor)


#define XPF_IMPL_DOC		0
#define XPF_IMPL_DOCUMENT	1
#define XPF_IMPL_DOCUMENT_LAZY	2
#define XPF_IMPL_DOCUMENT_LAZY_IN_COLL	3

void
xpf_document_impl (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, int call_mode)
{
  static const char *fnames[] = {"doc", "document", "document-lazy", "collection"};
  query_instance_t * qi = xqi->xqi_qi;
  const char *uri = ctx_xe->xe_doc.xd->xd_uri;
  caddr_t rel_uri, abs_uri = NULL;
  dk_set_t documents = NULL;
  XT *doc_arg;
  caddr_t doc_text = NULL;	/* It must be be freed on loading error */
  caddr_t loading_error = NULL;
  char cache_key_place[sizeof (xml_doc_cache_stdkey_t) + BOX_AUTO_OVERHEAD];
  xml_doc_cache_stdkey_t *cache_key;
  BOX_AUTO_TYPED (xml_doc_cache_stdkey_t *, cache_key, cache_key_place, sizeof (xml_doc_cache_stdkey_t), DV_ARRAY_OF_POINTER);
  cache_key->xdcs_type = XDC_DOCUMENT;
  cache_key->xdcs_abs_uri = NULL;
  cache_key->xdcs_parser_mode = 0;
  cache_key->xdcs_enc_name = NULL;
  cache_key->xdcs_lang_ptr = (lang_handler_t **) box_num ((ptrlong)(server_default_lh));
  cache_key->xdcs_dtd_cfg = default_doc_dtd_config;
  doc_arg = xpf_arg_tree (tree, 0);
  if (XPF_IMPL_DOC != call_mode)
    {
      switch (tree->_.xp_func.argcount)
	{
	default:
	  sqlr_new_error_xqi_xdl ("XP001", "XPF09", xqi, "Too many arguments passed to XPATH function %s()", fnames[call_mode]);
	case 6:
	  cache_key->xdcs_dtd_cfg = xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 5);
	case 5:
	  cache_key->xdcs_lang_ptr[0] = lh_get_handler (xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 4));
	case 4:
	  cache_key->xdcs_enc_name = xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 3);
	case 3:
	  cache_key->xdcs_parser_mode = (ptrlong) unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 2));
	case 2:
	  {
	    caddr_t base = (caddr_t)xpf_raw_arg (xqi, tree, ctx_xe, 1);
	    switch (DV_TYPE_OF (base))
	      {
	      case DV_XML_ENTITY:
		uri = xe_get_sysid_base_uri ((xml_entity_t *)base);
		uri = box_utf8_as_wide_char (uri, NULL, strlen (uri), 0);
		break;
	      case DV_STRING:
		uri = base;
		uri = box_utf8_as_wide_char (uri, NULL, strlen (uri), 0);
		break;
	      default:
		sqlr_new_error_xqi_xdl ("XP001", "XPF10", xqi, "XML entity or a string expected as \"base_uri\" argument of XPATH function %s()", fnames[call_mode]);
	      }
	  }
	case 1: ;
	case 0: ;
	}
    }
  xqi_eval (xqi, doc_arg, ctx_xe);
  rel_uri = xqi_value (xqi, doc_arg, DV_WIDE);
  if (NULL != rel_uri)
    {
      xml_entity_t *cached;
/* The loading itself -- begin; */
load_next_rel_uri:
      dk_free_box (abs_uri);
      abs_uri = xml_uri_resolve (xqi->xqi_qi, &loading_error, (caddr_t)uri, rel_uri, "_WIDE_");
      if (loading_error)
	goto loading_error;
      cache_key->xdcs_abs_uri = box_wide_as_utf8_char (abs_uri, box_length (abs_uri) / sizeof (wchar_t) - 1, DV_STRING);
#ifdef DEBUG
      if (NULL == cache_key->xdcs_abs_uri)
	GPF_T;
#endif
      cached = (xml_entity_t *)xml_doc_cache_get_copy (xqi->xqi_doc_cache, (ccaddr_t)cache_key);
      if (NULL != cached)
        {
	  XD_DOM_LOCK(cached->xe_doc.xd);
          dk_free_tree (cache_key->xdcs_abs_uri);
          cache_key->xdcs_abs_uri = NULL;
	  dk_set_push (&documents, (void*)(cached));
	  goto loading_complete;
	}
      if ((XPF_IMPL_DOCUMENT_LAZY == call_mode) || (XPF_IMPL_DOCUMENT_LAZY_IN_COLL == call_mode))
        {
	  xml_entity_t * document = (xml_entity_t *)xlazye_from_cache_key (box_copy_tree (cache_key), qi);
          dk_free_tree (cache_key->xdcs_abs_uri);
          cache_key->xdcs_abs_uri = NULL;
	  dk_set_push (&documents, (void*) (document));
          goto loading_complete;
        }
/* Plain loading starts here */
      {
        xml_ns_2dict_t ns_2dict;
	xml_entity_t * document;
	dtd_t *doc_dtd = NULL;
	id_hash_t *id_cache = NULL;
	caddr_t doc_tree;
        ns_2dict.xn2_size = 0;
	doc_text = xml_uri_get (qi, &loading_error, NULL, NULL /* = no base uri */, abs_uri, XML_URI_STRING_OR_ENT);
	if (DV_XML_ENTITY == DV_TYPE_OF (doc_text)) /* if comes from LONG XML column via virt://... */
	  {
	    document = (xml_entity_t *)doc_text;
	    goto document_is_ready;
	  }
	if (loading_error)
	  goto loading_error;
	doc_tree = xml_make_mod_tree (qi, doc_text, (caddr_t *) &loading_error,
	  cache_key->xdcs_parser_mode, cache_key->xdcs_abs_uri,
	  cache_key->xdcs_enc_name, cache_key->xdcs_lang_ptr[0], cache_key->xdcs_dtd_cfg,
	  &doc_dtd, &id_cache, &ns_2dict );
	if (loading_error)
	  goto loading_error;
	document = (xml_entity_t *)xte_from_tree (doc_tree, qi);
	document->xe_doc.xd->xd_dtd = doc_dtd; /* Refcounter added inside xml_make_tree */
	document->xe_doc.xd->xd_uri = cache_key->xdcs_abs_uri;
	document->xe_doc.xd->xd_id_dict = id_cache;
	document->xe_doc.xd->xd_id_scan = XD_ID_SCAN_COMPLETED;
	document->xe_doc.xd->xd_ns_2dict = ns_2dict;
	dk_free_box (doc_text);

document_is_ready:
        xml_doc_cache_add_copy (&(xqi->xqi_doc_cache), (ccaddr_t)cache_key, (caddr_t)document);
	XD_DOM_LOCK(document->xe_doc.xd);
	dk_set_push (&documents, (void*) (document));
	cache_key->xdcs_abs_uri = NULL;
	goto loading_complete;
      }
/* The loading itself -- end; */
loading_complete:
      if ((XPF_IMPL_DOC != call_mode) && xqi_is_next_value (xqi, doc_arg))
	{
	  rel_uri = xqi_value (xqi, doc_arg, DV_SHORT_STRING);
	  goto load_next_rel_uri;
	}
    }
/* At this point we've loaded all requested documents */
  {
    caddr_t arr = list_to_array_of_xqval (dk_set_nreverse (documents));
    XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
    XQI_SET (xqi, tree->_.xp_func.var->_.var.init, arr);
    XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
    XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
    dk_free_box (cache_key->xdcs_lang_ptr);
    return;
  }
loading_error:
  dk_free_box (doc_text);
  dk_free_box (cache_key->xdcs_abs_uri);
  dk_free_box (cache_key->xdcs_lang_ptr);
  dk_free_box (abs_uri);
  dk_free_tree ((caddr_t) list_to_array (documents));
  sqlr_resignal (loading_error);
}


void
xpf_doc (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_document_impl (xqi, tree, ctx_xe, XPF_IMPL_DOC);
}


void
xpf_document (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_document_impl (xqi, tree, ctx_xe, XPF_IMPL_DOCUMENT);
}


void
xpf_document_lazy (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_document_impl (xqi, tree, ctx_xe, XPF_IMPL_DOCUMENT_LAZY);
}

void
xpf_document_lazy_in_coll (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_document_impl (xqi, tree, ctx_xe, XPF_IMPL_DOCUMENT_LAZY_IN_COLL);
}


void
xpf_document_get_uri (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t base = (caddr_t)xpf_raw_arg (xqi, tree, ctx_xe, 0);
  caddr_t uri;
  if (DV_XML_ENTITY != DV_TYPE_OF (base))
    sqlr_new_error_xqi_xdl ("XP001", "XPF16", xqi, "XML entity expected as an argument of XPATH function document-get-uri()");
  uri = (caddr_t) xe_get_sysid_base_uri ((xml_entity_t *)base);
  XQI_SET (xqi, tree->_.xp_func.res, (NULL != uri) ? box_copy (uri) : box_dv_short_string (""));
}

void
xpf_expand_qname (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int use_default = xpf_arg_boolean (xqi, tree, ctx_xe, 0);
  xml_entity_t *tmp_ctx_xe = NULL;
  caddr_t res, qname = (caddr_t)xpf_raw_arg (xqi, tree, ctx_xe, 1);
  switch (DV_TYPE_OF (qname))
    {
    case DV_STRING:
      break;
    case DV_XML_ENTITY:
      ctx_xe = tmp_ctx_xe = box_copy (qname);
      /* no break */
    default:
      qname = (caddr_t)xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 1);
    }
  if (2 < tree->_.xp_func.argcount)
    {
      ctx_xe = (xml_entity_t *)xpf_raw_arg (xqi, tree, ctx_xe, 2);
      if (DV_XML_ENTITY != DV_TYPE_OF (ctx_xe))
	sqlr_new_error_xqi_xdl ("XP001", "?????", xqi, "XML entity expected as a third argument of XPATH function expand-qname()");
    }
  res = ctx_xe->_->xe_find_expanded_name_by_qname (ctx_xe, qname, use_default);
  dk_free_box (tmp_ctx_xe);
  XQI_SET (xqi, tree->_.xp_func.res, res);
}

void
xpf_document_literal (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  query_instance_t * qi = xqi->xqi_qi;
  dk_set_t documents = NULL;
  XT *doc_text_arg = xpf_arg_tree (tree, 0);
  int parser_mode = 0;
  caddr_t enc = NULL;
  lang_handler_t *lh = server_default_lh;
  caddr_t cache_uri = NULL;	/* It must be be freed on loading error */
  caddr_t doc_text = NULL;	/* It must be be freed on loading error */
  caddr_t parsing_error = NULL;
  caddr_t dtd_cfg = default_doc_dtd_config;
  int use_cache = 0;
  switch (tree->_.xp_func.argcount)
    {
    default:
      sqlr_new_error_xqi_xdl ("XP001", "XPF15", xqi, "Too many arguments passed to XPATH function document-literal()");
    case 6:
      dtd_cfg = xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 5);
    case 5:
      lh = lh_get_handler (xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 4));
    case 4:
      enc = xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 3);
    case 3:
      parser_mode = (int) unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 2));
    case 2:
      cache_uri = (caddr_t)xpf_arg (xqi, tree, ctx_xe, DV_STRING, 1);
      use_cache = ((NULL != cache_uri) && ('\0' != cache_uri[0]));
    case 1: ;
    case 0: ;
    }
  xqi_eval (xqi, doc_text_arg, ctx_xe);
  doc_text = xqi_value (xqi, doc_text_arg, DV_SHORT_STRING);
  if (NULL != doc_text)
    {
/* The parsing itself -- begin; */
parse_next_doc_text:
/*
Maybe no cache here?
      if (use_cache)
	{
          xml_entity_t *cached = xml_doc_cache_get_copy (xqi->xqi_doc_cache, cache_uri);
          if (NULL != cached)
	    {
	      dk_set_push (&documents, (void*)(cached));
	      goto parsing_complete;
	    }
	}
*/
      {
	xml_entity_t * document;
	xml_ns_2dict_t ns_2dict;
	dtd_t *doc_dtd = NULL;
	id_hash_t *id_cache = NULL;
	caddr_t doc_tree;
        ns_2dict.xn2_size = 0;
	doc_tree = xml_make_mod_tree (qi, doc_text, (caddr_t *) &parsing_error, parser_mode, (use_cache ? cache_uri : NULL), enc, lh, dtd_cfg, &doc_dtd, &id_cache, &ns_2dict);
	if (parsing_error)
	  {
	    dk_free_tree ((caddr_t) list_to_array (documents));
	    sqlr_resignal (parsing_error);
	  }
	document = (xml_entity_t *)xte_from_tree (doc_tree, qi);
	document->xe_doc.xd->xd_dtd = doc_dtd; /* Refcounter added inside xml_make_tree */
	if (use_cache)
	  document->xe_doc.xtd->xd_uri = box_copy (cache_uri);
	document->xe_doc.xd->xd_id_dict = id_cache;
	document->xe_doc.xd->xd_id_scan = XD_ID_SCAN_COMPLETED;
	document->xe_doc.xd->xd_ns_2dict = ns_2dict;
	XD_DOM_LOCK(document->xe_doc.xd);
/*
Maybe no cache here?
	dk_set_push (&ctx_xe->xe_doc.xd->xd_top_doc->xd_referenced_documents, (void*)(document->_->xe_copy(document)));
*/
	dk_set_push (&documents, (void*) (document));
	goto parsing_complete;
      }
/* The parsing itself -- end; */
parsing_complete:
      if (!use_cache && xqi_is_next_value (xqi, doc_text_arg))
	{
	  doc_text = xqi_value (xqi, doc_text_arg, DV_SHORT_STRING);
	  goto parse_next_doc_text;
	}
    }
/* At this point we've parsed all documents */
  {
    caddr_t arr = list_to_array_of_xqval (dk_set_nreverse (documents));
    XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
    XQI_SET (xqi, tree->_.xp_func.var->_.var.init, arr);
    XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
    XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
    return;
  }
}


void
xpf_resolve_uri (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  query_instance_t * qi = xqi->xqi_qi;
  const char *uri = ctx_xe->xe_doc.xd->xd_uri;
  caddr_t rel_uri = (caddr_t)xpf_arg (xqi, tree, ctx_xe, DV_STRING, 1);
  caddr_t err = NULL;
  caddr_t abs_uri = NULL;
  caddr_t base = (caddr_t)xpf_raw_arg (xqi, tree, ctx_xe, 0);
  switch (DV_TYPE_OF (base))
    {
    case DV_XML_ENTITY:
      uri = xe_get_sysid_base_uri ((xml_entity_t *)base);
      break;
    case DV_STRING:
      uri = base;
      break;
    default:
      sqlr_new_error_xqi_xdl ("XP001", "XPF17", xqi, "XML entity or a string expected as \"base_uri\" argument of XPATH function resolve_uri()");
    }
  abs_uri = (caddr_t) xml_uri_resolve (qi, &err, (caddr_t) uri, rel_uri, "UTF-8");
  if (NULL != err)
    sqlr_resignal (err);
  XQI_SET (xqi, tree->_.xp_func.res, abs_uri);
}


int
xp_text_contains (xp_instance_t * xqi, XT * tree,  xml_entity_t * ctx_xe, xml_entity_t * xe)
{
  /* args: node-set, text-exp-string, pattern-tree, slot-of-sst, tagged-box-of-language-handler */
  caddr_t * qst = (caddr_t *) xqi->xqi_qi;
  d_id_t d_id;
  text_node_t * txs = xqi->xqi_text_node;
  XT ** args = tree->_.xp_func.argtrees;
  wpos_t start, end;
  search_stream_t * sst = (search_stream_t *) XQI_GET (xqi, (ptrlong) args[3]);
  caddr_t * text_tree = (caddr_t *) args[2];
  ptrlong text_tree_flags;
  if (!txs)
    sqlr_new_error_xqi_xdl ("XP370", "XPF11", xqi, "XPATH function text-contains() is allowed only in special SQL predicate xcontains()");
  if (DV_XML_ENTITY != DV_TYPE_OF (xe))
    return 0;
#if 0
  if (!xe->_->xe_word_range)
    sqlr_new_error_xqi_xdl ("XP001", "XPF12", xqi, "Word index data not associated with entity for XPATH function text-contains()");
#endif
  if (!text_tree)
    {
      caddr_t err = NULL;
      caddr_t str = xpf_arg (xqi, tree, ctx_xe, DV_LONG_STRING, 1);
      text_tree = xp_text_parse (str, &eh__UTF8, ((lang_handler_t *)unbox_ptrlong ((caddr_t)(args[4]))), NULL /* ignore options */, &err);
      if (err)
	sqlr_resignal (err);
      dk_free_tree ((caddr_t) args[2]);
      text_tree_flags = xpt_range_flags_of_step (args[0], tree);
      xpt_edit_range_flags (text_tree, ~SRC_RANGE_DUMMY, text_tree_flags);
      args[2] = (XT *) text_tree;
    }
  text_tree_flags = ((ptrlong *)text_tree)[1];
  switch (text_tree_flags & (SRC_RANGE_MAIN | SRC_RANGE_ATTR | SRC_RANGE_WITH_NAME_IN | SRC_RANGE_DUMMY))
    {
      case SRC_RANGE_MAIN:
	xe->_->xe_word_range (xe, &start, &end);
      break;
      default:
	sqlr_new_error_xqi_xdl ("XP001", "XPF13", xqi, "Unsupported combination of arguments in XPATH function text-contains()");
      break;
    }
  if (!sst)
    {
      sst_tctx_t context;
      context.tctx_qi = xqi->xqi_qi;
      context.tctx_table = txs->txs_table;
      context.tctx_calc_score = 0; /* Never deals with scoring */
      context.tctx_range_flags = text_tree_flags;
      context.tctx_descending = 0;
      context.tctx_end_id = NULL;
      context.tctx_vtb = NULL;
      sst = sst_from_tree (&context, text_tree);
      XQI_SET (xqi, (ptrlong) args[3], (caddr_t) sst);
    }
  d_id_set_box (&d_id, qst_get (qst, txs->txs_d_id));
/* Argument of text-contains cannot contain expressions for starting and ending tags, so
   we remove positions of tags from the scope, by adding 1 to the 'from' and 'not' adding 1 to the right. */
  return sst_ranges (sst, &d_id, start+1, end, 0);
}


void
xpf_text_contains (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t val;
  int ctr = 0;
  XT * arg = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg, ctx_xe);
  val = xqi_raw_value (xqi, arg);
  if (! val)
    ctr = 0;
  else
    {
      if (xp_text_contains (xqi, tree, ctx_xe, (xml_entity_t *) val))
	goto succ;
      while (xqi_is_next_value (xqi, arg))
	{
	  val = xqi_raw_value (xqi, arg);
	  if (xp_text_contains (xqi, tree, ctx_xe, (xml_entity_t *) val))
	    goto succ;

	}
    }
  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull(0));
  return;
 succ:
  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull(1));
}


xml_entity_t * xqi_current (xp_instance_t * xqi, XT * tree);

void
xpf_generate_id (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t res = NULL;
  char buffer[100];
  xml_entity_t * xe = ctx_xe;
  if (tree->_.xp_func.argcount > 0)
    {
      XT *arg = xpf_arg_tree (tree, 0);
      xml_entity_t *_xe = NULL;
      xqi_eval (xqi, arg, ctx_xe);
      if (xqi_is_value (xqi, arg))
	_xe = xqi_current (xqi, arg);
      if (DV_XML_ENTITY == DV_TYPE_OF (_xe))
	xe = _xe;
    }
  if (xe)
    {
      if (XE_IS_TREE (xe))
	{
	  xml_tree_ent_t *xte = (xml_tree_ent_t *)xe;
	  sprintf (buffer, "id%p" , (void *)(xte->xte_current));
	  res = box_dv_short_string (buffer);
	}
      else if (XE_IS_PERSISTENT (xe))
	{
	  xper_entity_t *xpe = (xper_entity_t *)xe;
	  sprintf (buffer, "id%lX", (unsigned long) xpe->xper_pos);
	  res = box_dv_short_string (buffer);
	}
    }

  XQI_SET (xqi, tree->_.xp_func.res, res);
}


void
xpf_lang (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t lang = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
  ptrlong res = 0;
  caddr_t lang_in_effect = NULL;
  switch (DV_TYPE_OF (ctx_xe))
    {
    case DV_XML_ENTITY:
      {
        xml_entity_t *xe = ctx_xe->_->xe_copy (ctx_xe);
        XT *test = xtlist (NULL, 4, XP_NAME_EXACT, uname_xml, uname_lang, uname_xml_colon_lang);
        while (!lang_in_effect)
          {
            if (XI_NO_ATTRIBUTE == xe->_->xe_attribute (xe, -1, test, &lang_in_effect, NULL))
              if (XI_AT_END == xe->_->xe_up (xe, (XT *) XP_NODE, 0 /* no XE_UP_MAY_TRANSIT! */))
                break;
          }
        dk_free_tree ((box_t) xe);
        dk_free_tree ((box_t) test);
        break;
      }
    case DV_RDF:
      {
        rdf_box_t *rb = (rdf_box_t *)ctx_xe;
        if (!rb->rb_is_complete)
          rb_complete (rb, xqi->xqi_qi->qi_trx, xqi->xqi_qi);
        if (RDF_BOX_DEFAULT_LANG != rb->rb_lang)
          lang_in_effect = rdf_lang_twobyte_to_string (rb->rb_lang);
        break;
      }
    }
  if (DV_STRINGP (lang_in_effect))
    {
      char *minus = strchr (lang_in_effect, '-');
      if (minus)
        res = (0 == strnicmp (lang, lang_in_effect, lang_in_effect - minus)) ? 1 : 0;
      else
        res = (0 == stricmp (lang, lang_in_effect)) ? 1 : 0;
    }
  dk_free_tree (lang_in_effect);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t) res);
}

void
xpf_current (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t *arr;
  xqi_binding_t *xb = xqi_find_binding (xqi, XSLT_CURRENT_ENTITY_INTERNAL_NAME);
  arr = (caddr_t *) dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
  if (xb && xb->xb_value && DV_TYPE_OF (xb->xb_value) == DV_XML_ENTITY)
    arr[0] = box_copy_tree (xb->xb_value);
  else
    arr[0] = box_copy_tree ((caddr_t) ctx_xe);

  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, (caddr_t) arr);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
}


void
xpf_format_number (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  NUMERIC_VAR (num_buf);
  numeric_t number = (numeric_t) num_buf;
  caddr_t number_box = xpf_arg (xqi, tree, ctx_xe, DV_NUMERIC, 0);
  caddr_t format = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 1);
  xslt_number_format_t *nf = xsnf_default;
  caddr_t dec_format = (caddr_t) -1;
  xslt_sheet_t *xsh = NULL;
  xqi_binding_t *xb = xqi_find_binding (xqi, XSLT_SHEET_INTERNAL_NAME);
  caddr_t res = NULL, err;

  NUMERIC_INIT (num_buf);

  if (xb && xb->xb_value && DV_TYPE_OF (xb->xb_value) == DV_LONG_INT)
    xsh = (xslt_sheet_t *) unbox_ptrlong (xb->xb_value);
  if (tree->_.xp_func.argcount > 2)
    dec_format = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 2);
  if (xsh && dec_format != (caddr_t) -1)
    {
      DO_SET (xslt_number_format_t *, xn, &xsh->xsh_formats)
	{
	  if (box_equal (xn->xsnf_name, dec_format))
	    nf = xn;
	}
      END_DO_SET();
    }
  if (dec_format != (caddr_t) -1 && nf == xsnf_default)
    sqlr_new_error_xqi_xdl ("XS370", "XS036", xqi, "Number format %s not defined in format-number()",
	dec_format ? dec_format : "<default>");


  if (NULL != (err = numeric_from_x (number, number_box,
	  NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, "format-number",-1, NULL)))
    sqlr_resignal (err);
  res = xslt_format_number (number, format, nf);
  XQI_SET (xqi, tree->_.xp_func.res, res);
}


void
xpf_list (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_arg_list (xqi, tree, ctx_xe, 0, XQI_ADDRESS(xqi,tree->_.xp_func.res));
}


void
xpf_append (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int argcount = (int) tree->_.xp_func.argcount;
  caddr_t *tmp_res = (caddr_t *)dk_alloc_box_zero (argcount * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
  caddr_t *final_res;
  int ctr, final_res_fill, final_res_size;
/* Temporary array is placed into the xqi in order to prevent memory leaks on errors in evaluation of arguments */
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, (caddr_t)(tmp_res));
  final_res_size = 0;
  for (ctr = 0; ctr < argcount; ctr++)
    {
      caddr_t tuple_val;
      xpf_arg_list (xqi, tree, ctx_xe, ctr, tmp_res+ctr);
      tuple_val = tmp_res[ctr];
      if (NULL == tuple_val)
	continue;
      final_res_size += ((DV_ARRAY_OF_XQVAL == DV_TYPE_OF(tuple_val)) ? BOX_ELEMENTS(tuple_val) : 1);
    }
  final_res = (caddr_t *)dk_alloc_box_zero (final_res_size * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
  final_res_fill = 0;
  for (ctr = 0; ctr < argcount; ctr++)
    {
      caddr_t tuple_val = tmp_res[ctr];
      if (NULL == tuple_val)
	continue;
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(tuple_val))
	{
	  int subelem_count = BOX_ELEMENTS(tuple_val);
	  memcpy (final_res+final_res_fill, tuple_val, subelem_count * sizeof(caddr_t*));
	  final_res_fill += subelem_count;
	  dk_free_box(tuple_val);
	}
      else
	final_res[final_res_fill++] = tuple_val;
    }
  box_tag_modify (tmp_res, DV_ARRAY_OF_LONG); /* To prevent erasing of original tuple values in XQI_SET */
#ifdef DEBUG
  if (final_res_fill != final_res_size)
    GPF_T1("internal error in xpf_append");
#endif
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, (caddr_t)(final_res));
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
}


void
xpf_tuple (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  XT ** args = tree->_.xp_func.argtrees;
  int argcount = (int) tree->_.xp_func.argcount;
  caddr_t *res = (caddr_t *)dk_alloc_box_zero (argcount * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
  int ctr;
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)(res));
  for (ctr = 0; ctr < argcount; ctr++)
    {
      XT * arg = args[ctr];
      caddr_t arg_val;
      xqi_eval (xqi, arg, ctx_xe);
      arg_val = xqi_raw_value (xqi, arg);
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(arg_val))
	res[ctr] = (
	  (0 == BOX_ELEMENTS(arg_val)) ?
	  (caddr_t)(box_dv_short_string("")) :
	  (caddr_t)(box_copy_tree (((caddr_t*)(arg_val))[0])) );
      else
	res[ctr] = box_copy_tree(arg_val);
    }
}


void
xpf_assign (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t varname = xpf_arg (xqi, tree, ctx_xe, DV_UNAME, 0);
  XT * varvalue_arg;
  caddr_t varvalue;
  xqi_binding_t * xb;
  varvalue_arg = xpf_arg_tree (tree, 1);
  xqi_eval (xqi, varvalue_arg, ctx_xe);
  varvalue = xqi_raw_value (xqi, varvalue_arg);
  xb = xqi_find_binding (xqi, varname);
  if (!xb)
    return;
  dk_free_tree (xb->xb_value);
  xb->xb_value = box_copy_tree (varvalue);
  XQI_SET (xqi, tree->_.xp_func.res, NULL);
}


#if 0
void
xpf_deass (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t varname = xpf_arg (xqi, tree, ctx_xe, DV_UNAME, 0);
  xqi_binding_t * xb;
  xb = xqi_find_binding (xqi, varname);
  if (NULL != xb)
    {
      caddr_t varvalue = xb->xb_value;
      xb->xb_value = NULL;
      xqi_remove_local_binding (xqi, varname);
      XQI_SET (xqi, tree->_.xp_func.res, varvalue);
      return;
    }
  XQI_SET (xqi, tree->_.xp_func.res, NULL);
  return;
}
#endif


void
xpf_progn (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  XT * nth_arg = NULL;	/* Assigned to make compiler happy ("might be used uninitialized") */
  caddr_t nth_value;
  int n, argc;
  argc = (int) tree->_.xp_func.argcount;
  for (n = 0; n < argc; n++)
    {
      nth_arg = xpf_arg_tree (tree, n);
      xqi_eval (xqi, nth_arg, ctx_xe);
    }
  nth_value = ((0 == n) ? NULL : box_copy_tree (xqi_raw_value (xqi, nth_arg)));
  XQI_SET (xqi, tree->_.xp_func.res, nth_value);
}


void
xpf_iterate (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t arr;
  caddr_t val;
  dk_set_t res = NULL;
  XT * arg = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg, ctx_xe);
  val = xqi_raw_value (xqi, arg);
  if (val)
    {
next_item:
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val))
	{
	  int idx, count = (int) BOX_ELEMENTS (val);
	  for (idx = 0; idx < count; idx++)
	    {
	      dk_set_push (&res, box_copy_tree (((caddr_t *)(val))[idx]));
	    }
	}
      else
	dk_set_push (&res, box_copy_tree (val));
      if (xqi_is_next_value (xqi, arg))
	{
	  val = xqi_raw_value (xqi, arg);
	  goto next_item;
	}
    }
  arr = list_to_array_of_xqval (dk_set_nreverse (res));
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, arr);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
}


void
xpf_iterate_rev (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t arr;
  caddr_t val;
  dk_set_t res = NULL;
  XT * arg = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg, ctx_xe);
  val = xqi_raw_value (xqi, arg);
  if (val)
    {
next_item:
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val))
	{
	  int idx, count = (int) BOX_ELEMENTS (val);
	  for (idx = 0; idx < count; idx++)
	    {
	      dk_set_push (&res, box_copy_tree (((caddr_t *)(val))[idx]));
	    }
	}
      else
	dk_set_push (&res, box_copy_tree (val));
      if (xqi_is_next_value (xqi, arg))
	{
	  val = xqi_raw_value (xqi, arg);
	  goto next_item;
	}
    }
  arr = list_to_array_of_xqval (res);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, arr);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
}


void
xpf_create_attribute (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t attrname = xpf_arg (xqi, tree, ctx_xe, DV_UNAME, 0);
  caddr_t attrvalue = xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 1);
  caddr_t res = list (3,
    uname__attr,
    box_copy(attrname),
    box_copy(attrvalue) );
  XQI_SET (xqi, tree->_.xp_func.res, res);
}


void
xpf_create_comment (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t content = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
  caddr_t el, root_el;
  xml_tree_ent_t *el_xte;
  if (NULL != strstr (content, "--"))
    sqlr_new_error_xqi_xdl ("XP001", "XPFCC", xqi, "The string content of a comment should not contain strings like '--' string");
  if (box_length (content) > 1)
    el = list (2,
	list (1, uname__comment),
	box_copy (content) );
  else
    el = list (1, list (1,uname__comment));
  root_el = list (2, list (1, uname__root), el);
  el_xte = xte_from_tree (root_el, xqi->xqi_qi);
  el_xte->xe_doc.xd->xd_dtd = dtd_alloc();
  dtd_addref (el_xte->xe_doc.xd->xd_dtd, 0);
  XTE_ADD_STACK_POS(el_xte);
  el_xte->xte_current = (caddr_t*) el;
  el_xte->xte_child_no = 1;
  /* No need in xte_down (el_xte, (XT *) XP_NODE); - it a plain element for sure, not refentry */
  el_xte->xe_doc.xtd->xd_uri = box_dv_short_string ("[result of create-comment XPATH function]");
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)el_xte);
}


void
xpf_create_pi (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t name = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
  caddr_t content = ((tree->_.xp_func.argcount > 1) ?  xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 1) : NULL);
  caddr_t head, el, root_el;
  xml_tree_ent_t *el_xte;

  head = (caddr_t) list (3, uname__pi, uname__bang_name, box_copy (name));
  if ((NULL != content) && (box_length (content) > 1))
    el = list (2, head,	box_copy (content));
  else
    el = list (1, head);
  root_el = list (2, list (1, uname__root), el);
  el_xte = xte_from_tree (root_el, xqi->xqi_qi);
  el_xte->xe_doc.xd->xd_dtd = dtd_alloc();
  dtd_addref (el_xte->xe_doc.xd->xd_dtd, 0);
  XTE_ADD_STACK_POS(el_xte);
  el_xte->xte_current = (caddr_t*) el;
  el_xte->xte_child_no = 1;
  /* No need in xte_down (el_xte, (XT *) XP_NODE); - it a plain element for sure, not refentry */
  el_xte->xe_doc.xtd->xd_uri = box_dv_short_string ("[result of create-pi XPATH function]");
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)el_xte);
}


void
xpf_create_element (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int argctr;
  int argcount = (int) tree->_.xp_func.argcount;
  caddr_t *tmp_res;

  dtp_t el_head_dtp;
  dk_set_t res_raw_attrs = NULL;
  dk_set_t res_raw_elems = NULL;
  int res_ready_string_len = 0;
  dk_set_t res_ready_strings = NULL;
  dk_set_t res_ready_elems = NULL;
  caddr_t el, root_el;
  xml_tree_ent_t *el_xte;
  qi_signal_if_trx_error (xqi->xqi_qi);

  if (0 == argcount)
    sqlr_new_error_xqi_xdl ("XP001", "XPFC0", xqi, "At least one argument (name of element to be created) must be passed to XPATH function create-element()");
/* We must eval all arguments and store them in XQI stack, to prevent memory leaks on sqlr_new_error calls */
  tmp_res = (caddr_t *)dk_alloc_box_zero (argcount * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)(tmp_res));
  for (argctr = 0; argctr < argcount; argctr++)
    {
      xpf_arg_list (xqi, tree, ctx_xe, argctr, tmp_res + argctr);
    }
/* Now we can normalize value of header */
  el_head_dtp = DV_TYPE_OF (tmp_res[0]);
  switch (el_head_dtp)
    {
    /* Single symbol must be name of element */
    case DV_SYMBOL:
      box_tag_modify (tmp_res[0], DV_SHORT_STRING);
      /* no break */
    /* Single string must be name of element */
    case DV_STRING:
      {
        caddr_t name = tmp_res[0];
	caddr_t el_head_val = list (1, box_dv_uname_nchars (name, box_length (name) - 1));
	dk_free_box (name);
	tmp_res[0] = el_head_val;
	break;
      }
    case DV_UNAME:
      {
	caddr_t el_head_val = list (1, tmp_res[0]);
	tmp_res[0] = el_head_val;
	break;
      }
    case DV_ARRAY_OF_XQVAL:
    {
      caddr_t el_head_val = tmp_res[0];
      int i,j;
      int attrc = BOX_ELEMENTS (el_head_val);
      box_tag_modify (el_head_val, DV_ARRAY_OF_POINTER);
      if (attrc <1)
	sqlr_new_error_xqi_xdl ("XP001", "XPFC1", xqi, "No name of element in the first argument of XPATH function create-element()");
      if (!(attrc & 0x1))
	sqlr_new_error_xqi_xdl ("XP001", "XPFC2", xqi, "Last attribute has no value specified in the first argument of XPATH function create-element()");
      for (i = attrc; i--; /*no step*/)
	{
	  caddr_t item_i = ((caddr_t *)(el_head_val))[i];
	  caddr_t strval;
	  dtp_t item_i_dtp = DV_TYPE_OF(item_i);
	  switch (item_i_dtp)
	    {
	    case DV_SYMBOL:
	      box_tag_modify (item_i, DV_SHORT_STRING);
	      item_i_dtp = DV_SHORT_STRING;
	      /* no break */
	    case DV_STRING:
	      strval = item_i;
	      break;
	    case DV_UNAME:
	      strval = item_i;
	      break;
	    case DV_XML_ENTITY:
	      {
		xml_entity_t * xe = (xml_entity_t *) item_i;
		strval = NULL;
		/*xe->_->xe_string_value (xe, &strval, DV_SHORT_STRING);*/
		xe_string_value_1 (xe, &strval, DV_SHORT_STRING);
		item_i_dtp = DV_SHORT_STRING;
		break;
	      }
	    case DV_LONG_INT:
	        if (NULL == item_i)
	          { /* xpf_tuple() can place NULL for missing result. This is empty string attribute value, whereas integer zero is made by box_num_nonull(...) */
	            strval = box_dv_short_nchars ("", 0);
		    item_i_dtp = DV_SHORT_STRING;
		    break;
		  }
		/* no break */
	    case DV_SHORT_INT: case DV_SINGLE_FLOAT: case DV_DOUBLE_FLOAT: case DV_NUMERIC:
		strval = box_cast ((caddr_t *) xqi->xqi_qi, item_i, (sql_tree_tmp*) st_varchar, item_i_dtp);
		item_i_dtp = DV_SHORT_STRING;
		break;
	    default:
	      sqlr_new_error_xqi_xdl ("XP001", "XPFC3", xqi, "Unsupported type of element of the first argument of XPATH function create-element()");
	    }
	  if ((0 == i) || (i & 1))
	    {
	      if (DV_UNAME != item_i_dtp)
		{
		  caddr_t uval = box_dv_uname_nchars (strval, box_length (strval) - 1);
		  if (strval != item_i) dk_free_box (strval);
		  strval = uval;
		}
	    }
	  else
	    {
	      if (DV_UNAME == item_i_dtp)
		{
		  caddr_t sval = box_dv_short_nchars (strval, box_length (strval) - 1);
		  if (strval != item_i) dk_free_box (strval);
		  strval = sval;
		}
            }
	  if (strval != item_i)
	    {
	      dk_free_tree (item_i);
	      ((caddr_t *)(el_head_val))[i] = strval;
	    }
        }
      for (i = attrc-4; i>0; i-=2)	/* Loop on attrc-4,...7,5,3,1 */
	{
	  caddr_t item_i = ((caddr_t *)(el_head_val))[i];
	  for (j = i+2; j < attrc; j += 2)
	    if (item_i == ((caddr_t *)(el_head_val))[j])
	      sqlr_new_error_xqi_xdl ("XP001", "XPFC4", xqi, "Duplicate attribute names in first argument of XPATH function create-element()");
	}
      break;
    }
    default:
      sqlr_new_error_xqi_xdl ("XP001", "XPFC5", xqi, "First argument of XPATH function create-element() must be string, symbol or sequence of them");
    }
/* Now we have the header normalized; it's time to flatten the sequence of element-content values and to process all additional attributes */
  for (argctr = 1; argctr < argcount; argctr++)
    {
      caddr_t argvalue = tmp_res[argctr];
      int subval_ctr, subval_count;
      int prev_subval_is_text = 0; /* to add whitespaces according to W3C XQ 041029, 3.7.1.3, item 1.e.i */
      caddr_t *subvals;
#ifdef XPATH_DEBUG
      if (xqi_set_odometer >= xqi_set_debug_start)
	xte_tree_check(argvalue);
#endif
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (argvalue))
	{
	  subval_count = (int) BOX_ELEMENTS (argvalue);
	  subvals = (caddr_t *)(argvalue);
	}
      else
	{
	  subval_count = 1;
	  subvals = tmp_res+argctr;
	}
      for (subval_ctr = 0; subval_ctr < subval_count; subval_ctr++)
	{
	  caddr_t subvalue = subvals[subval_ctr];
	  dtp_t subvalue_dtp;
	  if (NULL == subvalue)
	    continue;
	  subvalue_dtp = DV_TYPE_OF (subvalue);
	  switch (subvalue_dtp)
	    {
	    case DV_STRING:
	      if (prev_subval_is_text)
		dk_set_push (&res_raw_elems, box_dv_short_string (" ")); /* The whitespace occurs even if the string is empty */
              prev_subval_is_text = 1;
	      if (1 < box_length (subvalue))
	        {
	          dk_set_push (&res_raw_elems, subvalue);
	          subvals[subval_ctr] = NULL;
	        }
	      goto subvalue_done;
	    case DV_LONG_INT:
	      {
		char buf[20];
		sprintf(buf, BOXINT_FMT, unbox (subvalue));
	        if (prev_subval_is_text)
		  dk_set_push (&res_raw_elems, box_dv_short_string (" "));
                prev_subval_is_text = 1;
		dk_set_push (&res_raw_elems, box_dv_short_string (buf));
		goto subvalue_done;
	      }
	    case DV_NUMERIC:
	      {
		char buf[NUMERIC_MAX_STRING_BYTES+1];
		numeric_to_string ((numeric_t) subvalue, buf, sizeof (buf));
	        if (prev_subval_is_text)
		  dk_set_push (&res_raw_elems, box_dv_short_string (" "));
                prev_subval_is_text = 1;
		dk_set_push (&res_raw_elems, box_dv_short_string (buf));
		goto subvalue_done;
	      }
	    case DV_XML_ENTITY:
	      {
		xml_tree_ent_t *xte = ((xml_tree_ent_t *)(subvalue));
		if (NULL != xte->xe_attr_name)
		  {
		    caddr_t attr_val = NULL;
		    xe_string_value_1 ((xml_entity_t *)(xte), &attr_val, DV_SHORT_STRING);
		    subvals[subval_ctr] = subvalue = list (3, uname__attr, box_copy(xte->xe_attr_name), attr_val);
		    dk_free_box ((box_t) xte);
		    goto attr_subvalue_ready; /* see below */
		  }
		if (XE_IS_PERSISTENT(subvalue))
		  {
		    caddr_t *subtree = xte->_->xe_copy_to_xte_subtree ((xml_entity_t *)xte);
		    if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (subtree)) || (uname__root != XTE_HEAD_NAME (XTE_HEAD (subtree))))
		      dk_set_push (&res_raw_elems, subtree);
		    else
		      {
		        int child_idx, child_no = BOX_ELEMENTS (subtree);
		        for (child_idx = 1; child_idx < child_no; child_idx++)
			  dk_set_push (&res_raw_elems, subtree[child_idx]);
			dk_free_tree ((box_t) XTE_HEAD (subtree));
			dk_free_box ((box_t) subtree);
		      }

		    goto subvalue_done; /* see below */
		  }
		else
		  {
		    caddr_t *curr;
		    curr = xte->xte_current;
		    if (XTE_HAS_PARENT (xte))
		      dk_set_push (&res_raw_elems, box_copy_tree((box_t) curr));
		    else
		      {
		        int child_idx, child_no = BOX_ELEMENTS (curr);
		        for (child_idx = 1; child_idx < child_no; child_idx++)
			  dk_set_push (&res_raw_elems, box_copy_tree(curr[child_idx]));
		      }
		  }
		goto subvalue_done; /* see below */

attr_subvalue_ready: ;
		/* no break */
	      }
	    case DV_ARRAY_OF_POINTER:
	      {
	      caddr_t newattr_name;
	      caddr_t newattr_value;
	      int attrcount = BOX_ELEMENTS (tmp_res[0]);
	      int attrctr;
	      if ((3 > BOX_ELEMENTS(subvalue)) ||
		(uname__attr != ((caddr_t *)subvalue)[0]) )
		sqlr_new_error_xqi_xdl ("XP001", "XPFC7", xqi, "Invalid special entity found in argument of XPATH function create-element()");
	      newattr_name = ((caddr_t *)subvalue)[1];
	      newattr_value = ((caddr_t *)subvalue)[2];
	      /* First we try to find attribute with same name in array of explicitly specified */
	      for (attrctr = 1; attrctr < attrcount; attrctr += 2)
		{
		  caddr_t *tail = ((caddr_t *)(tmp_res[0])) + attrctr;
		  if (strcmp (newattr_name, tail[0]))
		    continue;
		  dk_free_box (tail[1]);
		  tail[1] = newattr_value;
		  ((caddr_t *)subvalue)[2] = NULL;
		  goto subvalue_done;
		}
	      /* Then we try to find attribute with same name in the set of additional attributes */
	      DO_SET(caddr_t *, oldattr_ptr, &res_raw_attrs)
		{
		  if (!strcmp (newattr_name, oldattr_ptr[1]))
		    {
		      dk_free_box (oldattr_ptr[2]);
		      oldattr_ptr[2] = newattr_value;
		      ((caddr_t *)subvalue)[2] = NULL;
		      goto subvalue_done;
		    }
		}
	      END_DO_SET()
	      dk_set_push (&res_raw_attrs, subvalue);
	      subvals[subval_ctr] = 0;
	      goto subvalue_done;
	      }
	    case DV_SINGLE_FLOAT: case DV_DOUBLE_FLOAT:
	      {
		caddr_t strval = box_cast ((caddr_t *) xqi->xqi_qi, subvalue, (sql_tree_tmp*) st_varchar, subvalue_dtp);
	        if (prev_subval_is_text)
		  dk_set_push (&res_raw_elems, box_dv_short_string (" "));
                prev_subval_is_text = 1;
	        dk_set_push (&res_raw_elems, strval);
		goto subvalue_done;
	      }
	    case DV_ARRAY_OF_XQVAL:
	      sqlr_new_error_xqi_xdl ("XP001", "XPFC6", xqi, "Error in XPATH user extension function or internal error: sequence argument is not flat in XPATH function create-element()");
	    default:
	      sqlr_new_error_xqi_xdl ("XP001", "XPFCB", xqi, "Unsupported type of argument in XPATH function create-element()");
	  }
subvalue_done: ;
	}
    }
/* Now we may write additional attributes into the head. */
  if (NULL != res_raw_attrs)
    {
      int addon_fill = BOX_ELEMENTS(tmp_res[0]);
      int addon_count = 2*dk_set_length(res_raw_attrs);
      caddr_t * new_head = (caddr_t *)dk_alloc_box ((addon_fill + addon_count) * sizeof(caddr_t), DV_ARRAY_OF_POINTER);
      memcpy (new_head, tmp_res[0], addon_fill * sizeof(caddr_t));
      res_raw_attrs = dk_set_nreverse(res_raw_attrs);
      do
	{
	  caddr_t *new_attr = (caddr_t *)dk_set_pop (&res_raw_attrs);
	  new_head[addon_fill++] = new_attr[1]; new_attr[1] = NULL;
	  new_head[addon_fill++] = new_attr[2]; new_attr[2] = NULL;
	  dk_free_tree((box_t) new_attr);
        } while (NULL != res_raw_attrs);
      dk_free_box(tmp_res[0]); /* not dk_free_tree, because pointers to element name and old attributes are copied into \c new_head */
      tmp_res[0] = (caddr_t)new_head;
    }
/* Now we may normalize content, by doing typecasting and concatenation of strings */
  for (;;)
    {
      int flush_strings;
      int terminate;
      caddr_t raw_elem = NULL;
      dtp_t raw_elem_dtp = 0;
      if (NULL == res_raw_elems)
	{
	  terminate = flush_strings = 1;
	}
      else
	{
	  terminate = 0;
	  raw_elem = (caddr_t) dk_set_pop (&(res_raw_elems));
#ifdef XPATH_DEBUG
	  if (xqi_set_odometer >= xqi_set_debug_start)
	    xte_tree_check(raw_elem);
#endif
	  raw_elem_dtp = DV_TYPE_OF(raw_elem);
	  flush_strings = (DV_ARRAY_OF_POINTER == raw_elem_dtp);
	}
      do
	{
	  caddr_t rdy;
	  char *tail;
          if (!flush_strings)
	    break;
	  if (NULL == res_ready_strings)
	    break;
	  if (NULL == res_ready_strings->next)
	    {
	      dk_set_push (&res_ready_elems, dk_set_pop(&res_ready_strings));
	      res_ready_string_len = 0;
	      break;
	    }
	  rdy = tail = dk_alloc_box (res_ready_string_len+1, DV_SHORT_STRING);
	  while (NULL != res_ready_strings)
	    {
	      caddr_t strg = (caddr_t) dk_set_pop (&res_ready_strings);
	      int strg_len = box_length (strg)-1;
	      memcpy (tail, strg, strg_len);
	      tail += strg_len;
	      dk_free_box (strg);
	    }
	  tail[0] = '\0';
	  dk_set_push (&res_ready_elems, rdy);
	  res_ready_string_len = 0;
	} while (0);
      if (terminate)
	break;
      switch (raw_elem_dtp)
	{
	case DV_STRING:
	  res_ready_string_len += box_length (raw_elem)-1;
	  dk_set_push (&res_ready_strings, raw_elem);
	  break;
	case DV_ARRAY_OF_POINTER:
	  {
	    dk_set_push (&res_ready_elems, raw_elem);
	    break;
	  }
	default:
	  GPF_T;
	}
    }
  dk_set_push (&res_ready_elems, tmp_res[0]);
  tmp_res[0] = NULL;
  el = list_to_array (res_ready_elems);
  root_el = list (2, list (1, uname__root), el);
  el_xte = xte_from_tree (root_el, xqi->xqi_qi);
  el_xte->xe_doc.xd->xd_dtd = dtd_alloc();
  dtd_addref (el_xte->xe_doc.xd->xd_dtd, 0);
  XTE_ADD_STACK_POS(el_xte);
  el_xte->xte_current = (caddr_t*) el;
  el_xte->xte_child_no = 1;
  /* No need in xte_down (el_xte, (XT *) XP_NODE); - it a plain element for sure, not refentry */
  el_xte->xe_doc.xtd->xd_uri = box_dv_short_string ("[result of create-element XPATH function]");
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)el_xte);
}


static int
xpf_ordering_1 (xp_instance_t * xqi, xml_entity_t *val_A, xml_entity_t *val_B)
{
  dk_set_t lp_A = NULL, lp_B = NULL;
  xml_doc_t *doc_A, *doc_B;
  int res;
  if (DV_XML_ENTITY != DV_TYPE_OF (val_A))
    {
      if (NULL == val_A)
	return ((NULL == val_B) ? XE_CMP_A_IS_EQUAL_TO_B : XE_CMP_A_NULL_B_VALID);
      sqlr_new_error_xqi_xdl ("XP001", "XPFB0", xqi, "First argument of XPATH function is-before() or is-after() must be XML entity");
    }
  if (DV_XML_ENTITY != DV_TYPE_OF (val_B))
    {
      if (NULL == val_B)
	return XE_CMP_A_VALID_B_NULL;
      sqlr_new_error_xqi_xdl ("XP001", "XPFB1", xqi, "Second argument of XPATH function is-before() or is-after() must be XML entity");
    }
  val_A->_->xe_get_logical_path (val_A, &lp_A);
  val_B->_->xe_get_logical_path (val_B, &lp_B);
  doc_A = (xml_doc_t *)(lp_A->data);
  doc_B = (xml_doc_t *)(lp_B->data);
  if (doc_A != doc_B)
    {
      res = ((doc_A < doc_B) ? XE_CMP_A_DOC_LT_B : XE_CMP_A_DOC_GT_B);
      goto done;
    }
  for (;;)
    {
      ptrlong p_A, p_B;
      dk_set_pop (&lp_A);
      dk_set_pop (&lp_B);
      if (NULL == lp_A)
	{
	  dk_set_free (lp_B);
	  return ((NULL == lp_B) ? XE_CMP_A_IS_EQUAL_TO_B : XE_CMP_A_IS_ANCESTOR_OF_B);
	}
      if (NULL == lp_B)
	{
	  dk_set_free (lp_A);
	  return XE_CMP_A_IS_DESCENDANT_OF_B;
	}
      p_A = ((ptrlong)(lp_A->data));
      p_B = ((ptrlong)(lp_B->data));
      if (p_A < p_B)
	{
	  res = XE_CMP_A_IS_BEFORE_B;
	  goto done;
	}
      if (p_A > p_B)
	{
	  res = XE_CMP_A_IS_AFTER_B;
	  goto done;
	}
    }
done:
  dk_set_free (lp_A);
  dk_set_free (lp_B);
  return res;
}


void
xpf_is_before (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int cmp;
  xml_entity_t *val0, *val1;
  val0 = (xml_entity_t *)(xpf_raw_arg (xqi, tree, ctx_xe, 0));
  val1 = (xml_entity_t *)(xpf_raw_arg (xqi, tree, ctx_xe, 1));
  cmp = xpf_ordering_1 (xqi, val0, val1);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)(ptrlong)((XE_CMP_A_IS_BEFORE_B == cmp) ? 1 : 0));
}


void
xpf_is_after (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int cmp;
  xml_entity_t *val0, *val1;
  val0 = (xml_entity_t *)(xpf_raw_arg (xqi, tree, ctx_xe, 0));
  val1 = (xml_entity_t *)(xpf_raw_arg (xqi, tree, ctx_xe, 1));
  cmp = xpf_ordering_1 (xqi, val0, val1);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)(ptrlong)((XE_CMP_A_IS_AFTER_B == cmp) ? 1 : 0));
}


void
xpf_is_descendant (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int cmp;
  xml_entity_t *val0, *val1;
  val0 = (xml_entity_t *)(xpf_raw_arg (xqi, tree, ctx_xe, 0));
  val1 = (xml_entity_t *)(xpf_raw_arg (xqi, tree, ctx_xe, 1));
  cmp = xpf_ordering_1 (xqi, val0, val1);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)(ptrlong)((XE_CMP_A_IS_DESCENDANT_OF_B == cmp) ? 1 : 0));
}


void
xpf_is_same (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int cmp;
  xml_entity_t *val0, *val1;
  val0 = (xml_entity_t *)(xpf_raw_arg (xqi, tree, ctx_xe, 0));
  val1 = (xml_entity_t *)(xpf_raw_arg (xqi, tree, ctx_xe, 1));
  cmp = xpf_ordering_1 (xqi, val0, val1);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)(ptrlong)((XE_CMP_A_IS_EQUAL_TO_B == cmp) ? 1 : 0));
}


void
xpf_key (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  dk_set_t res_set = NULL;
  caddr_t res;
  id_hash_t *all_keysets, *curr_keyset;
  caddr_t name, values, *dict_val;
  caddr_t *val_set;
  size_t val_set_size, val_set_ctr;
  all_keysets = (id_hash_t *)(xqi->xqi_xp_keys);
  if (NULL == all_keysets)
    goto res_done;
  name = xpf_arg (xqi, tree, ctx_xe, DV_LONG_STRING, 0);
  dict_val = (caddr_t *)id_hash_get (all_keysets, (caddr_t)(&name));
  if (NULL == dict_val)
    goto res_done;
  curr_keyset = (id_hash_t *)(dict_val[0]);
  values = xpf_raw_arg (xqi, tree, ctx_xe, 1);
  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(values))
    {
      val_set = (caddr_t *)values;
      val_set_size = BOX_ELEMENTS(val_set);
    }
  else
    {
      val_set = &values;
      val_set_size = 1;
    }
  for (val_set_ctr = 0; val_set_ctr < val_set_size; val_set_ctr++)
    {
      caddr_t val = val_set[val_set_ctr];
      dtp_t val_dtp;
      caddr_t val_str = NULL;
      if (!val)
	continue;
      val_dtp = DV_TYPE_OF (val);
      if (DV_XML_ENTITY == val_dtp)
	{
	  xml_entity_t * xe = (xml_entity_t *) val;
	  xe_string_value_1 (xe, &val_str, DV_SHORT_STRING);
	}
      else
	{
	  QR_RESET_CTX
	    {
	      val_str = box_cast ((caddr_t *) xqi->xqi_qi, val, (sql_tree_tmp*) st_varchar, val_dtp);
	    }
	  QR_RESET_CODE
	    {
	      du_thread_t * self = THREAD_CURRENT_THREAD;
	      caddr_t err = thr_get_error_code (self);
	      POP_QR_RESET;
	      dk_free_tree (list_to_array_of_xqval (res_set));
	      sqlr_resignal (err);
	    }
	  END_QR_RESET;
	}
      dict_val = (caddr_t *)id_hash_get (curr_keyset, (caddr_t)(&val_str));
      dk_free_box (val_str);
      if (NULL != dict_val)
	{
	  caddr_t *buf = (caddr_t *)(dict_val[0]);
	  ptrlong buf_busy = unbox (buf[0]);
	  ptrlong buf_idx;
	  for (buf_idx = 1 /* not 0*/; buf_idx < buf_busy; buf_idx++)
	    {
	      xml_entity_t * new_node = (xml_entity_t *)(buf[buf_idx]);
	      int found = 0;
	      DO_SET (xml_entity_t *, old_node, &res_set)
		{
		  if (!old_node->_->xe_is_same_as(old_node, new_node))
		    continue;
	          found = 1;
		  break;
		}
	      END_DO_SET ();
	      if (!found)
		dk_set_push (&res_set, box_copy ((box_t) new_node));
	    }
	}
    }
res_done:
  res = list_to_array_of_xqval (dk_set_nreverse (res_set));
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, res);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
}


void
xpf_vector (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int argctr, argcount = tree->_.xp_func.argcount;
  caddr_t *res;
  res = (caddr_t *)dk_alloc_box_zero (argcount * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)res);
  for (argctr = argcount; argctr--; /* no step*/)
    {
      caddr_t *item_ptr = res+argctr;
      xpf_arg_list (xqi, tree, ctx_xe, argctr, item_ptr);
#ifdef DEBUG
      if (DV_ARRAY_OF_XQVAL != DV_TYPE_OF(item_ptr[0]))
        GPF_T;
#endif
      if (1 == BOX_ELEMENTS (item_ptr[0]))
        {
          caddr_t single = ((caddr_t *)(item_ptr[0]))[0];
          dk_free_box (item_ptr[0]);
          item_ptr[0] = single;
        }
    }
}


void
xpf_vector_for_order_by (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int argctr, argcount = tree->_.xp_func.argcount;
  caddr_t *res;
  caddr_t *item_ptr;
  res = (caddr_t *)dk_alloc_box_zero (argcount * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)res);
  for (argctr = argcount - 1; argctr--; /* no step*/)
    {
      caddr_t atom;
      item_ptr = res+argctr;
      xpf_arg_list (xqi, tree, ctx_xe, argctr, item_ptr);
      atom = xqi_atomize_one (xqi, item_ptr[0]);
      dk_free_box (item_ptr[0]);
      item_ptr[0] = atom;
    }
 item_ptr = res + argcount - 1;
 xpf_arg_list (xqi, tree, ctx_xe, argcount - 1, item_ptr);
#ifdef DEBUG
      if (DV_ARRAY_OF_XQVAL != DV_TYPE_OF(item_ptr[0]))
        GPF_T;
#endif
 if (1 == BOX_ELEMENTS (item_ptr[0]))
   {
     caddr_t single = ((caddr_t *)(item_ptr[0]))[0];
     dk_free_box (item_ptr[0]);
     item_ptr[0] = single;
   }
}


void
xpf_order_by_operator (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  XT ** specs = (XT **)xpf_arg_tree (tree, 1);
  int specs_no = BOX_ELEMENTS(specs);
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  caddr_t *res;
  caddr_t ** temp;
  size_t temp_len;
  int items_no, items_ctr;
  int specs_ctr;
  xslt_sort_t tmp_specs[16];
  xpf_arg_list (xqi, tree, ctx_xe, 0, res_ptr);
  res = (caddr_t *)res_ptr[0];
  items_no = ((NULL == res) ? 0 : BOX_ELEMENTS(res));
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
  if (0 == items_no)
    return;
/* Do the sorting here */
  for (specs_ctr = 0; specs_ctr < specs_no; specs_ctr++)
    {
      tmp_specs[specs_ctr].xs_is_desc = specs[specs_ctr]->_.xslt_sort.xs_is_desc;
      tmp_specs[specs_ctr].xs_collation = sch_name_to_collation ((caddr_t)(specs[specs_ctr]->_.xslt_sort.xs_collation));
    }
  temp_len = box_length ((caddr_t) res);
  temp = (caddr_t**) dk_alloc (temp_len);
#if 1
  xslt_qsort ((caddr_t**)res, temp, items_no, 0, tmp_specs);
#else
  xslt_bsort ((caddr_t**)res, items_no, tmp_specs);
#endif
  dk_free ((caddr_t) temp, temp_len);
/* Removal of sorting keys */
  for (items_ctr = 0; items_ctr < items_no; items_ctr++)
    {
      caddr_t *crit_vals = (caddr_t *)(res[items_ctr]);
      caddr_t datum = crit_vals[specs_no];
      crit_vals[specs_no] = NULL;
      dk_free_tree ((caddr_t) crit_vals);
      res[items_ctr] = datum;
    }
  if (NULL != (XT **)xpf_arg_tree (tree, 2))
    {
      int need_flatten = 0;
      int res_len = 0;
      for (items_ctr = 0; items_ctr < items_no; items_ctr++)
	{
	  caddr_t item = res[items_ctr];
	  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (item))
	    {
	      int subitems = BOX_ELEMENTS(item);
	      if (1 == subitems)
	        {
	          res_len++;
	          res[items_ctr] = ((caddr_t *)item)[0];
	          dk_free_box (item);
	        }
	      else
	        {
	          res_len += subitems;
	          need_flatten = 1;
	        }
	    }
	}
      if (need_flatten)
        {
          caddr_t *flat_res = dk_alloc_box (res_len, DV_ARRAY_OF_XQVAL);
          caddr_t *flat_res_tail = flat_res;
	  for (items_ctr = 0; items_ctr < items_no; items_ctr++)
	    {
	      caddr_t item = res[items_ctr];
	      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (item))
		{
		  int subitems = BOX_ELEMENTS(item);
		  memcpy (flat_res_tail, item, subitems * sizeof(caddr_t));
		  box_tag_modify (item, DV_ARRAY_OF_LONG);
		  flat_res_tail += subitems;
		}
	      else
	        {
	          (flat_res_tail++)[0] = item;
	          res[items_ctr] = NULL;
	        }
	    }
	}
    }
}


void
xpf_sortby_operator (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  XT ** specs = (XT **)xpf_arg_tree (tree, 1);
  int specs_no = BOX_ELEMENTS(specs);
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  caddr_t *res;
  caddr_t ** temp;
  size_t temp_len;
  xslt_sort_t tmp_specs[16];
  int items_no, items_ctr;
  int specs_ctr;
  xpf_arg_list (xqi, tree, ctx_xe, 0, res_ptr);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
  res = (caddr_t *)res_ptr[0];
  items_no = ((NULL == res) ? 0 : BOX_ELEMENTS(res));
  if (0 == items_no)
    return;
  for (specs_ctr = 0; specs_ctr < specs_no; specs_ctr++)
    {
      tmp_specs[specs_ctr].xs_tree = specs[specs_ctr]->_.xslt_sort.xs_tree;
      tmp_specs[specs_ctr].xs_is_desc = specs[specs_ctr]->_.xslt_sort.xs_is_desc;
      tmp_specs[specs_ctr].xs_type = specs[specs_ctr]->_.xslt_sort.xs_type;
      tmp_specs[specs_ctr].xs_collation = sch_name_to_collation ((caddr_t)(specs[specs_ctr]->_.xslt_sort.xs_collation));
    }
/* Items must be checked for their type */
  for (items_ctr = 0; items_ctr < items_no; items_ctr++)
    {
      caddr_t item = res[items_ctr];
      if (DV_XML_ENTITY != DV_TYPE_OF (item))
	sqlr_new_error_xqi_xdl ("XP001", "XPFD0", xqi, "Sequence to be sorted contains non-node items; such items cannot be used as context nodes");
    }
/* Every item must be replaced with a list of the item and values of its criteria */
  for (items_ctr = 0; items_ctr < items_no; items_ctr++)
    {
      xml_entity_t *item_xe = (xml_entity_t *)(res[items_ctr]);
      caddr_t *crit_vals = (caddr_t *) dk_alloc_box_zero ((1+specs_no)*sizeof(caddr_t), DV_ARRAY_OF_POINTER);
      crit_vals[specs_no] = (caddr_t)(item_xe);
      res[items_ctr] = (caddr_t)(crit_vals);
    }
  for (specs_ctr = 0; specs_ctr < specs_no; specs_ctr++)
    {
      XT * crit_tree = (XT *)tmp_specs[specs_ctr].xs_tree;
      dtp_t crit_dtp = (dtp_t)((ptrlong)(tmp_specs[specs_ctr].xs_type));
      items_ctr = 0;
      if (DV_UNKNOWN == crit_dtp)
	{
	  caddr_t *crit_vals = (caddr_t *)res[0];
	  xml_entity_t *item_xe = (xml_entity_t *)(crit_vals[specs_no]);
	  caddr_t crit_val;
	  xqi_eval (xqi, crit_tree, item_xe);
	  crit_val = xqi_raw_value (xqi, crit_tree);
	  if (IS_NUM_DTP (DV_TYPE_OF (crit_val)))
	    crit_dtp = DV_NUMERIC;
	  else
	    {
	      crit_dtp = DV_LONG_STRING;
	      crit_val = xqi_value (xqi, crit_tree, crit_dtp); /* cast again */
	    }
	  tmp_specs[specs_ctr].xs_type = (caddr_t)((ptrlong)(crit_dtp));
	  crit_vals[specs_ctr] = box_copy_tree (crit_val);
	  items_ctr = 1;
	}
      for (/*no init*/; items_ctr < items_no; items_ctr++)
	{
	  caddr_t *crit_vals = (caddr_t *)res[items_ctr];
	  xml_entity_t *item_xe = (xml_entity_t *)(crit_vals[specs_no]);
	  xqi_eval (xqi, crit_tree, item_xe);
	  crit_vals[specs_ctr] = box_copy_tree (xqi_value (xqi, crit_tree, crit_dtp));
	}
    }
  temp_len = box_length ((caddr_t) res);
  temp = (caddr_t**) dk_alloc (temp_len);
#if 1
  xslt_qsort ((caddr_t**)res, temp, items_no, 0, tmp_specs);
#else
  xslt_bsort ((caddr_t**)res, items_no, tmp_specs);
#endif
  dk_free ((caddr_t) temp, temp_len);
  for (items_ctr = 0; items_ctr < items_no; items_ctr++)
    {
      caddr_t *crit_vals = (caddr_t *)(res[items_ctr]);
      caddr_t datum = crit_vals[specs_no];
      crit_vals[specs_no] = NULL;
      dk_free_tree ((caddr_t) crit_vals);
      res[items_ctr] = datum;
    }
}


static void
xpf_remove_duplicates (caddr_t *res_ptr, caddr_t *tmp_ptr)
{
  caddr_t *res;
  ptrlong *finprns;
  int items_no, items_ctr, items_c2, items_new_no;
  res = (caddr_t *)res_ptr[0];
  items_no = ((NULL == res) ? 0 : BOX_ELEMENTS(res));
  if (0 == items_no)
    {
      XP_SET(res_ptr, NULL);
      return;
    }
  finprns = (ptrlong *) dk_alloc_box (items_no * sizeof(ptrlong), DV_ARRAY_OF_LONG);
  XP_SET (tmp_ptr, (caddr_t)finprns);
/* Every item must get its comparison value */
  for (items_ctr = 0; items_ctr < items_no; items_ctr++)
    {
      xml_entity_t *item = (xml_entity_t *)(res[items_ctr]);
      if (DV_XML_ENTITY == DV_TYPE_OF (item))
	finprns[items_ctr] = xe_equal_fingerprint((xml_entity_t *)item);
      else
	finprns[items_ctr] = box_hash ((caddr_t)item);
    }
/* Run from the end toward the beginning to remove duplicates. */
  items_new_no = items_no;
  for (items_c2 = items_no; (--items_c2) > 0; /* no step */)
    {
      xml_entity_t *i2 = (xml_entity_t *)(res[items_c2]);
      dtp_t i2_dtp = DV_TYPE_OF (i2);
      ptrlong fp2 = finprns[items_c2];
      for (items_ctr = 0; items_ctr < items_c2; items_ctr++)
	{
	  xml_entity_t *item = (xml_entity_t *)(res[items_ctr]);
	  dtp_t item_dtp = DV_TYPE_OF (item);
	  ptrlong finprn = finprns[items_ctr];
	  if (finprn != fp2)
	    continue;
	  if ((DV_XML_ENTITY == item_dtp) ?
	    ((DV_XML_ENTITY != i2_dtp) || !xe_are_equal (i2, item)) :
	    ((DV_XML_ENTITY == i2_dtp) || (DVC_MATCH != cmp_boxes ((caddr_t)i2, (caddr_t)item, NULL, NULL)))
	    )
	    continue;
	  dk_free_tree ((box_t) item);
	  items_new_no--;
	  if (items_c2 > items_new_no)
	    items_c2 = items_new_no;
	  if (items_ctr < items_new_no)
	    {
	      res[items_ctr] = res[items_new_no];
	      finprns[items_ctr] = finprns[items_new_no];
	    }
	  res[items_new_no] = NULL;
	}
    }
/* Conclusion */
  if (items_new_no != items_no)
    {
      size_t final_res_size = items_new_no * sizeof(caddr_t);
      caddr_t final_res = dk_alloc_box (final_res_size, DV_ARRAY_OF_XQVAL);
      memcpy (final_res, res, final_res_size);
      memset (res, 0, final_res_size);
      XP_SET (res_ptr, final_res);
    }
}


void
xpf_distinct (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  caddr_t *tmp_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.tmp);
  xpf_arg_list (xqi, tree, ctx_xe, 0, res_ptr);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
  xpf_remove_duplicates (res_ptr, tmp_ptr);
}


void
xpf_distinct_values (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.res);
  caddr_t *res;
  caddr_t *tmp_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.tmp);
  int idx;
  xpf_arg_list (xqi, tree, ctx_xe, 0, res_ptr);
  res = (caddr_t *)(res_ptr[0]);
  DO_BOX_FAST (caddr_t, item, idx, res)
    {
      if (DV_XML_ENTITY == DV_TYPE_OF (item))
        {
          caddr_t atom = xqi_atomize_one (xqi, item);
          dk_free_box (item);
          res[idx] = atom;
        }
    }
  END_DO_BOX_FAST;
  xpf_remove_duplicates (res_ptr, tmp_ptr);
}


void
xpf_union (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  caddr_t *tmp_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.tmp);
  xpf_append (xqi, tree, ctx_xe);
  xpf_remove_duplicates (res_ptr, tmp_ptr);
}


void
xpf_to_operator (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t *res;
  ptrlong n1 = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 0));
  ptrlong n2 = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 1));
  ptrlong len = 1 + n2 - n1;
  if (len < 0)
    len = 0;
  res = (caddr_t *)dk_alloc_box(len * sizeof(caddr_t), DV_ARRAY_OF_XQVAL);
  while (len--)
    res[len] = box_num_nonull (n2--);
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)res);
}


void
xpf_instance_of_predicate (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  sqlr_new_error_xqi_xdl ("XP001", "XPF??", xqi, "INSTANCE OF predicate is not yet implemented");
}


void
xpf_to_predicate (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t *res_ptr = XQI_ADDRESS(xqi, tree->_.xp_func.var->_.var.init);
  caddr_t el, lst;
  ptrlong firstok = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 1));
  ptrlong lastok = unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 2));
  ptrlong maxlen;
  ptrlong totalctr = 0;
  XT * arg = xpf_arg_tree (tree, 0);

  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);

  xqi_eval (xqi, arg, ctx_xe);
  el = xqi_raw_value (xqi, arg);
  if (firstok < 1)
    firstok = 1;
  maxlen = lastok + 1 - firstok;
  if ((NULL == el) || (maxlen <= 0))
    {
      XP_SET (res_ptr, dk_alloc_box (0, DV_ARRAY_OF_XQVAL));
    }
  else
    {
      caddr_t *subitems;
      size_t subctr, subcount;
      size_t fill_len = 0, new_fill_len, alloc_len = 16;
      caddr_t *buf = (caddr_t *)dk_alloc_box_zero (16 * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
      XP_SET (res_ptr, (caddr_t)(buf));
next_val:
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(el))
	{
	  subitems = (caddr_t *)el;
	  subcount = BOX_ELEMENTS(el);
	}
      else
	{
	  subitems = (caddr_t *)(&el);
	  subcount = 1;
	}
      if (totalctr + subcount < (size_t)firstok)
	{
	  totalctr += subcount;
	  goto next_value;
	}
      new_fill_len = 1+totalctr+subcount - firstok;
      if (new_fill_len > (size_t) maxlen)
	new_fill_len = maxlen;
      if (alloc_len < new_fill_len)
	{
	  caddr_t *buf2;
          while (alloc_len < new_fill_len) alloc_len *= 2;
	  buf2 = (caddr_t *)dk_alloc_box_zero (alloc_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
	  memcpy (buf2, buf, fill_len * sizeof (caddr_t));
	  box_tag_modify (buf, DV_ARRAY_OF_LONG);
	  buf = buf2;
	  XP_SET (res_ptr, (caddr_t)buf);
	}
      for (subctr = 0; subctr < subcount; subctr++)
	{
	  totalctr++;
	  if (totalctr >= lastok)
	    goto done;
	  if (totalctr >= firstok)
	    buf[fill_len++] = box_copy_tree (subitems[subctr]);
	}
next_value:
      if (xqi_is_next_value (xqi, arg))
	{
	  el = xqi_raw_value (xqi, arg);
	  goto next_val;
	}
done:
      lst = dk_alloc_box (fill_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
      memcpy (lst, buf, fill_len * sizeof (caddr_t));
      box_tag_modify (buf, DV_ARRAY_OF_LONG);
      XP_SET (res_ptr, lst);
    }
}


static void
xpf_before_operator_censor_tmp (xp_instance_t * xqi, cenpair_t *seq_head, size_t *seq_head_len, caddr_t candidate, void *user_data)
{
  size_t iter;
  dk_set_t lp_set = NULL;
  ptrlong * lp_vec;
  size_t lp_vec_size;
  if (DV_XML_ENTITY != DV_TYPE_OF (candidate))
    sqlr_new_error_xqi_xdl ("XP001", "XPFD2", xqi, "The right side of XQuery operator 'before' contains non-node items");
  ((xml_entity_t *)candidate)->_->xe_get_logical_path ((xml_entity_t *)candidate, &lp_set);
  lp_vec = (ptrlong *)dk_set_to_array(lp_set);
  box_tag_modify (lp_vec, DV_ARRAY_OF_LONG);
  dk_set_free (lp_set);
  lp_vec_size = BOX_ELEMENTS(lp_vec);
  for (iter = seq_head_len[0]; iter--; /*no step*/)
    {
      int cmp = xe_compare_logical_paths (
	(ptrlong *)(seq_head[iter].item), unbox(seq_head[iter].cache),
	lp_vec, lp_vec_size );
      switch(cmp)
	{
	case XE_CMP_A_DOC_LT_B:
	case XE_CMP_A_DOC_GT_B:
	  continue;
        case XE_CMP_A_IS_BEFORE_B:
        case XE_CMP_A_IS_ANCESTOR_OF_B:
	  dk_free_box (seq_head[iter].item);
	  dk_free_box (seq_head[iter].cache);
	  seq_head[iter].item = (caddr_t)lp_vec;
	  seq_head[iter].cache = box_num(lp_vec_size);
	  return;
	default:
	  dk_free_box ((box_t) lp_vec);
	  return;
	}
    }
  /* If all xpf_compare... return 0 or if seq_head is empty */
  seq_head[seq_head_len[0]].item = (caddr_t)lp_vec;
  seq_head[seq_head_len[0]].cache = box_num(lp_vec_size);
  seq_head_len[0]++;
}


static void
xpf_before_operator_censor_res (xp_instance_t * xqi, cenpair_t *seq_head, size_t *seq_head_len, caddr_t candidate, void *user_data)
{
  ptrlong **anchor_lps = (ptrlong **)user_data;
  size_t iter;
  dk_set_t lp_set = NULL;
  ptrlong * lp_vec;
  size_t lp_vec_size;
  if (DV_XML_ENTITY != DV_TYPE_OF (candidate))
    sqlr_new_error_xqi_xdl ("XP001", "XPFD3", xqi, "The left side of XQuery operator 'before' contains non-node items");
  ((xml_entity_t *)candidate)->_->xe_get_logical_path ((xml_entity_t *)candidate, &lp_set);
  lp_vec = (ptrlong *)dk_set_to_array(lp_set);
  box_tag_modify (lp_vec, DV_ARRAY_OF_LONG);
  dk_set_free (lp_set);
  lp_vec_size = BOX_ELEMENTS(lp_vec);
  for (iter = BOX_ELEMENTS(anchor_lps); iter--; /*no step*/)
    {
      int cmp = xe_compare_logical_paths (
	lp_vec, lp_vec_size,
	anchor_lps[iter], BOX_ELEMENTS(anchor_lps[iter]) );
      switch(cmp)
	{
	case XE_CMP_A_DOC_LT_B:
	case XE_CMP_A_DOC_GT_B:
	  continue;
        case XE_CMP_A_IS_BEFORE_B:
	  seq_head[seq_head_len[0]].item = (caddr_t)(((xml_entity_t *)candidate)->_->xe_copy ((xml_entity_t *)candidate));
	  seq_head_len[0]++;
	  /* no break */
	default:
	  dk_free_box ((box_t) lp_vec);
	  return;
	}
    }
  dk_free_box ((box_t) lp_vec);
  return;
}


void
xpf_before_operator (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t *tmp_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.tmp);
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  xpf_arg_list_censored (xqi, tree, ctx_xe, 1, tmp_ptr, xpf_before_operator_censor_tmp, NULL);
  xpf_arg_list_censored (xqi, tree, ctx_xe, 0, res_ptr, xpf_before_operator_censor_res, (void *)(tmp_ptr[0]));
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
}


static void
xpf_after_operator_censor_tmp (xp_instance_t * xqi, cenpair_t *seq_head, size_t *seq_head_len, caddr_t candidate, void *user_data)
{
  size_t iter;
  dk_set_t lp_set = NULL;
  ptrlong *lp_vec;
  size_t lp_vec_size;
  if (DV_XML_ENTITY != DV_TYPE_OF (candidate))
    sqlr_new_error_xqi_xdl ("XP001", "XPFD4", xqi, "The right side of XQuery operator 'after' contains non-node items");
  ((xml_entity_t *)candidate)->_->xe_get_logical_path ((xml_entity_t *)candidate, &lp_set);
  lp_vec = (ptrlong *)dk_set_to_array (lp_set);
  box_tag_modify (lp_vec, DV_ARRAY_OF_LONG);
  dk_set_free (lp_set);
  lp_vec_size = BOX_ELEMENTS(lp_vec);
  for (iter = seq_head_len[0]; iter--; /*no step*/)
    {
      int cmp = xe_compare_logical_paths (
	(ptrlong *)(seq_head[iter].item), unbox(seq_head[iter].cache),
	lp_vec, lp_vec_size );
      switch(cmp)
	{
	case XE_CMP_A_DOC_LT_B:
	case XE_CMP_A_DOC_GT_B:
	case XE_CMP_A_IS_ANCESTOR_OF_B:
	case XE_CMP_A_IS_DESCENDANT_OF_B:
	  continue;
        case XE_CMP_A_IS_AFTER_B:
	  dk_free_box (seq_head[iter].item);
	  dk_free_box (seq_head[iter].cache);
	  seq_head[iter].item = (caddr_t)lp_vec;
	  seq_head[iter].cache = box_num(lp_vec_size);
	  return;
	default:
	  dk_free_box ((box_t) lp_vec);
	  return;
	}
    }
  /* If all xpf_compare... return 0 or if seq_head is empty */
  seq_head[seq_head_len[0]].item = (caddr_t)lp_vec;
  seq_head[seq_head_len[0]].cache = box_num(lp_vec_size);
  seq_head_len[0]++;
}


static void
xpf_after_operator_censor_res (xp_instance_t * xqi, cenpair_t *seq_head, size_t *seq_head_len, caddr_t candidate, void *user_data)
{
  ptrlong **anchor_lps = (ptrlong **)user_data;
  size_t iter;
  dk_set_t lp_set = NULL;
  ptrlong * lp_vec;
  size_t lp_vec_size;
  if (DV_XML_ENTITY != DV_TYPE_OF (candidate))
    sqlr_new_error_xqi_xdl ("XP001", "XPFD5", xqi, "The left side of XQuery operator 'after' contains non-node items");
  ((xml_entity_t *)candidate)->_->xe_get_logical_path ((xml_entity_t *)candidate, &lp_set);
  lp_vec = (ptrlong *)dk_set_to_array(lp_set);
  box_tag_modify (lp_vec, DV_ARRAY_OF_LONG);
  dk_set_free (lp_set);
  lp_vec_size = BOX_ELEMENTS(lp_vec);
  for (iter = BOX_ELEMENTS(anchor_lps); iter--; /*no step*/)
    {
      int cmp = xe_compare_logical_paths (
	lp_vec, lp_vec_size,
	anchor_lps[iter], BOX_ELEMENTS(anchor_lps[iter]) );
      switch(cmp)
	{
	case XE_CMP_A_DOC_LT_B:
	case XE_CMP_A_DOC_GT_B:
	  continue;
        case XE_CMP_A_IS_AFTER_B:
	  seq_head[seq_head_len[0]].item = (caddr_t)(((xml_entity_t *)candidate)->_->xe_copy ((xml_entity_t *)candidate));
	  seq_head_len[0]++;
	  /* no break; */
	default:
	  dk_free_box ((box_t) lp_vec);
	  return;
	}
    }
  dk_free_box ((box_t) lp_vec);
  return;
}


void
xpf_after_operator (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t *tmp_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.tmp);
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  xpf_arg_list_censored (xqi, tree, ctx_xe, 1, tmp_ptr, xpf_after_operator_censor_tmp, NULL);
  xpf_arg_list_censored (xqi, tree, ctx_xe, 0, res_ptr, xpf_after_operator_censor_res, tmp_ptr[0]);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
}


void
xpf_unordered (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  xpf_arg_list (xqi, tree, ctx_xe, 0, res_ptr);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
}


void
xpf_shallow (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  caddr_t *subvals, subval, new_el;
  xml_tree_ent_t * new_xte;
  dtp_t dtp;
  size_t subvalno, subvalctr;
  xpf_arg_list (xqi, tree, ctx_xe, 0, res_ptr);
  subvals = (caddr_t *)(res_ptr[0]);
  subvalno = BOX_ELEMENTS(res_ptr[0]);
  for (subvalctr = 0; subvalctr < subvalno; subvalctr++)
    {
      subval = subvals[subvalctr];
      dtp = DV_TYPE_OF (subval);
      if (DV_XML_ENTITY != dtp)
	sqlr_new_error_xqi_xdl ("XP001", "XPFD6", xqi, "The argument of XPATH function shallow() is not an entity");
      if (XE_IS_PERSISTENT(subval))
        {
          xper_entity_t *subval_ent = (xper_entity_t *)subval;
          caddr_t head = (caddr_t) subval_ent->_->xe_copy_to_xte_head ((xml_entity_t *)subval_ent);
	  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF(head))
	    new_el = head;
	  else
	    new_el = list (1, head);
        }
      else
	{
	  caddr_t **el = (caddr_t **)((xml_tree_ent_t *)subval)->xte_current;
	  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF(el))
	    new_el = box_copy_tree ((caddr_t) el);
	  else
	    new_el = list (1, box_copy_tree ((box_t) el[0]));
	}
      new_el = list (2, list (1, uname__root), new_el);
      new_xte = xte_from_tree ((caddr_t)new_el, xqi->xqi_qi);
      new_xte->xe_doc.xd->xd_dtd = dtd_alloc();
      dtd_addref (new_xte->xe_doc.xd->xd_dtd, 0);
      new_xte->xe_doc.xtd->xd_uri = box_dv_short_string ("[result of shallow() XPATH function]");
      XP_SET (subvals+subvalctr, (caddr_t)(new_xte));
    }
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
}


void
xpf_id (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t *tmp_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.tmp);
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.res);
  caddr_t el, lst;
  XT * arg = xpf_arg_tree (tree, 0);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
  xqi_eval (xqi, arg, ctx_xe);
  el = xqi_raw_value (xqi, arg);
  if (NULL == el)
    {
      XQI_SET (xqi, tree->_.xp_func.var->_.var.init, dk_alloc_box (0, DV_ARRAY_OF_XQVAL));
    }
  else
    {
      caddr_t *subitems;
      size_t subctr, subcount;
      size_t fill_len = 0, alloc_len = 16;
      caddr_t *buf = (caddr_t *)dk_alloc_box_zero (16 * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
      XP_SET (res_ptr, (caddr_t)(buf));
next_val:
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(el))
	{
	  subitems = (caddr_t *)el;
	  subcount = BOX_ELEMENTS(el);
	}
      else
	{
	  subitems = (caddr_t *)(&el);
	  subcount = 1;
	}
      for (subctr = 0; subctr < subcount; subctr++)
	{
	  caddr_t subitem = subitems[subctr];
	  dtp_t sub_dtp = DV_TYPE_OF (subitem);
	  caddr_t idrefs = NULL;
	  unsigned char *idbegin, *idtail;
	  if (DV_XML_ENTITY == sub_dtp)
	    {
	      xml_entity_t * xe = (xml_entity_t *) subitem;
	      xe_string_value_1 (xe, &idrefs, DV_SHORT_STRING);
	    }
	  else
	    {
	      idrefs = box_cast ((caddr_t *) xqi->xqi_qi, subitem, (sql_tree_tmp*) st_varchar, sub_dtp);
	    }
	  XP_SET (tmp_ptr, idrefs);
	  for (idbegin = idtail = (unsigned char *)idrefs; /* no step */; /* no step*/)
	    {
	      xml_entity_t *id_owner;
	      while (ecm_utf8props[idbegin[0]] & ECM_ISSPACE)
		idbegin++;
	      if ('\0' == idbegin[0])
		break;
	      idtail = idbegin;
	      while (!(ecm_utf8props[idtail[0]] & (ECM_ISSPACE | ECM_ISZERO)))
		idtail++;
	      /* Process one ID */
	      id_owner = ctx_xe->_->xe_deref_id (ctx_xe, (char *)idbegin, idtail - idbegin);
	      if (NULL != id_owner)
		{
		  if (fill_len == alloc_len)
		    {
		      caddr_t *buf2 = (caddr_t *)dk_alloc_box_zero (alloc_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
		      memcpy (buf2, buf, fill_len * sizeof (caddr_t));
		      box_tag_modify (buf, DV_ARRAY_OF_LONG);
		      buf = buf2;
		      XP_SET (res_ptr, (caddr_t)buf);
		    }
		  buf[fill_len++] = (caddr_t)id_owner;
		}
	      /* Move to the rest of idrefs */
	      if ('\0' == idtail[0])
		break;
	      idbegin = idtail+1;
	    }
	}
      if (xqi_is_next_value (xqi, arg))
	{
	  el = xqi_raw_value (xqi, arg);
	  goto next_val;
	}
      lst = dk_alloc_box (fill_len * sizeof (caddr_t), DV_ARRAY_OF_XQVAL);
      memcpy (lst, buf, fill_len * sizeof (caddr_t));
      box_tag_modify (buf, DV_ARRAY_OF_LONG);
      XQI_SET (xqi, tree->_.xp_func.var->_.var.init, lst);
    }
}


void
xpf_system_property (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t sys_name = xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 0);
  char *lname;
  lname = strrchr(sys_name, ':');
  if (NULL == lname)
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (""));
      return;
    }
  if (!strcmp (lname, ":version"))
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_double (1.0));
      return;
    }
  if (!strcmp (lname, ":vendor"))
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string ("OpenLink Software"));
      return;
    }
  if (!strcmp (lname, ":vendor-url"))
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string ("http://www.openlinksw.com"));
      return;
    }
  if (!strcmp (lname, ":product-name"))
    {
      char buffer[1000];
      sprintf (buffer, "%s%.500s Server", PRODUCT_DBMS, build_special_server_model);
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (buffer));
      return;
    }
  if (!strcmp (lname, ":product-version"))
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (product_version_string ()));
      return;
    }
  if (!strcmp (sys_name, "http://www.openlinksw.com:virtuoso-version"))
    {
      XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (product_version_string ()));
      return;
    }
  XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (""));
  return;
}


void
xpf_unparsed_entity_uri (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t entname = xpf_arg (xqi, tree, ctx_xe, DV_SHORT_STRING, 0);
  char * pt = NULL; /* Note that it may be a non-box string. No box_copy()! */
  if (DV_STRINGP (entname))
    {
      xml_entity_t *xe = ctx_xe;
      while (NULL != xe->xe_referer)
	xe = xe->xe_referer;
      pt = (char *)(xe->_->xe_get_sysid (xe, entname));
    }
  if (!pt)
    XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (""));
  else
    XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string (pt));
}


/* 'A' for %NN, 'B' for '+', others to not encode */
unsigned char url_char_encodes[0x100] = {
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/*     !   "   #   $   %   &   '   (   )   *   +   ,   -   .   /  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A',' ',' ','A',
/* 0   1   2   3   4   5   6   7   8   9   :   ;   <   =   >   ?  */
  ' ',' ',' ',' ',' ',' ',' ',' ',' ',' ','A','A','A','A','A','A',
/* @   A   B   C   D   E   F   G   H   I   J   K   L   M   N   O  */
  'A',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',
/* P   Q   R   S   T   U   V   W   X   Y   Z   [   \   ]   ^   _  */
  ' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ','A','A','A','A',' ',
/* `   a   b   c   d   e   f   g   h   i   j   k   l   m   n   o  */
  'A',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',
/* p   q   r   s   t   u   v   w   x   y   z   {   |   }   ~      */
  ' ',' ',' ',' ',' ',' ',' ',' ',' ',' ',' ','A','A','A',' ','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'A','A','A','A','A','A','A','A','A','A','A','A','A','A','A','A' };


void
xpf_urlify (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  unsigned char * src = (unsigned char *)xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
  int src_len = box_length(src)-1;
  caddr_t tgt = NULL;
  int src_ctr, tgt_len;
  unsigned char * tgt_tail;
  tgt_len = src_len;
  for (src_ctr = 0; src_ctr < src_len; src_ctr++)
    {
      if ('A' == url_char_encodes[src[src_ctr]])
	tgt_len += 2;
    }
  tgt = dk_alloc_box (tgt_len+1, DV_SHORT_STRING);
  tgt_tail = (unsigned char *)tgt;
  for (src_ctr = 0; src_ctr < src_len; src_ctr++)
    {
      unsigned char c = src[src_ctr];
      switch (url_char_encodes[c])
	{
	  case 'A':
	    (tgt_tail++)[0] = '%';
	    (tgt_tail++)[0] = "0123456789ABCDEF"[c>>4];
	    (tgt_tail++)[0] = "0123456789ABCDEF"[c&0xF];
	    break;
	  case 'B':
	    (tgt_tail++)[0] = '+';
	    break;
	  default:
	    (tgt_tail++)[0] = c;
	}
    }
  tgt_tail[0] = '\0';
#ifdef DEBUG
  if (((char *)(tgt_tail) - tgt) != tgt_len)
    GPF_T;
#endif
  XQI_SET (xqi,tree->_.xp_func.res,tgt);
}


void
xpf_function_available (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_metadata_t **metas_ptr = NULL;
  xp_func_t executable = NULL;
  caddr_t fn = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
  metas_ptr = (xpf_metadata_t **) id_hash_get (xpf_metas, (caddr_t)&fn);
  if (NULL != metas_ptr)
    executable = metas_ptr[0]->xpfm_executable;
  XQI_SET (xqi, tree->_.xp_func.res, (caddr_t)(ptrlong)(metas_ptr ? 1 : 0));
}


/* Enumeration of XPath functions */
id_hash_t * xpf_metas;
id_hash_t * xpf_reveng;
id_hash_t * xp_ext_funcs;


void
xpf_extension (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t *res_ptr = XQI_ADDRESS(xqi,tree->_.xp_func.var->_.var.init);
  int call_arg_ctr, decl_arg_ctr, sys_arg_no, min_call_arg_no, decl_arg_no, call_arg_no = (int) tree->_.xp_func.argcount;
  caddr_t query_text = NULL;
  caddr_t * arr = NULL;
  caddr_t val = NULL, qp = NULL, err = NULL, *pname = NULL;
  query_t * qr = NULL, *proc;
  local_cursor_t * lc = NULL;
  client_connection_t * cli = xqi->xqi_qi->qi_client;

  pname = (caddr_t *)id_hash_get (xp_ext_funcs, (caddr_t)&(tree->_.xp_func.qname));
  if (!pname || !(*pname))
    {
      err = srv_make_new_error ("22023","XPE04","The XPATH extension function '%.200s' is not defined", tree->_.xp_func.qname);
      goto err_end;
    }

  proc = sch_proc_def (wi_inst.wi_schema, *pname);
  if (proc && proc->qr_to_recompile)
    proc = qr_recompile (proc, NULL);
  if (!proc)
    {
      err = srv_make_new_error ("22023","XPE05",
	  "XPATH extension function '%.200s' refers to undefined Virtuoso/PL procedure '%.200s'",
	  tree->_.xp_func.qname, *pname );
      goto err_end;
    }
  /* count the parameters plus default ones */
  sys_arg_no = min_call_arg_no = decl_arg_ctr = 0;
  decl_arg_no = dk_set_length (proc->qr_parms);
  DO_SET (state_slot_t *, formal, &proc->qr_parms)
    {
      if ('!' == formal->ssl_name[0])
        {
          min_call_arg_no = decl_arg_ctr + 1;
          sys_arg_no++;
        }
      else if (proc->qr_parm_default && !proc->qr_parm_default[decl_arg_ctr])
        min_call_arg_no = decl_arg_ctr + 1;
      decl_arg_ctr++;
    }
  END_DO_SET ();
  min_call_arg_no -= sys_arg_no;
  if (call_arg_no < min_call_arg_no || call_arg_no > (decl_arg_no - sys_arg_no))
    {
      err = srv_make_new_error ("22023","XPE06",
	  "XPATH extension function '%.200s' refers to Virtuoso/PL procedure '%.200s' that needs %lu parameters but %d parameters passed",
	  tree->_.xp_func.qname, *pname, (unsigned long)(decl_arg_no - sys_arg_no), call_arg_no );
      goto err_end;
    }
  if (!sec_proc_check (proc, G_ID_PUBLIC, U_ID_PUBLIC))
    {
      err = srv_make_new_error ("42001", "XPE07",
	  "XPATH extension function '%.200s' refers to the Virtuoso/PL procedure '%.200s' that is is not granted to public",
	  tree->_.xp_func.qname, *pname );
      goto err_end;
    }
  arr = decl_arg_no ? (caddr_t *) dk_alloc_box_zero (decl_arg_no * sizeof (caddr_t) , DV_ARRAY_OF_POINTER) : NULL;
  query_text = dk_alloc_box_zero (strlen (*pname) + (2 * decl_arg_no) + 3, DV_SHORT_STRING);
  qp = query_text;
  snprintf (query_text, box_length (query_text) - 1, "%s(", *pname);
  qp = qp + (strlen (query_text) - 1);

  decl_arg_ctr = call_arg_ctr = 0;
  DO_SET (state_slot_t *, ssl, &proc->qr_parms)
    {
      char *argname = ssl->ssl_name;
      if ('!' == argname[0])
        {
          if (!strcmp (argname, "!ctx"))
            arr [decl_arg_ctr] = box_copy_tree (ctx_xe);
          else if (!strcmp (argname, "!debug-xslt-srcfile"))
	    {
	      char *file = xqi->xqi_xqr->xqr_xdl.xdl_file;
	      arr [decl_arg_ctr] = box_dv_short_string ((NULL == file) ? "" : file);
            }
        }
      else if (call_arg_ctr < call_arg_no)
	{
	  switch (ssl->ssl_sqt.sqt_dtp)
	    {
	    case DV_UNKNOWN: case DV_ANY:
	      val = xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, call_arg_ctr);
	      arr [decl_arg_ctr] = val ? box_copy_tree (val) : NEW_DB_NULL;
	      break;
	    default:
	      val = xpf_arg (xqi, tree, ctx_xe, DV_LONG_STRING, call_arg_ctr);
	      arr [decl_arg_ctr] = val ? (box_cast_to ((caddr_t *) xqi->xqi_qi, val, DV_LONG_STRING, ssl->ssl_dtp,
		  NUMERIC_MAX_PRECISION, NUMERIC_MAX_SCALE, &err)) : NEW_DB_NULL;
	      if (err)
		goto err_end;
	    }
	  call_arg_ctr++;
	}
      else
	{
	  val = proc->qr_parm_default[decl_arg_ctr];
	  arr [decl_arg_ctr] = box_copy_tree (val);
	}
      strcat_box_ck (query_text, "?,");
      qp += 2;
      decl_arg_ctr++;
    }
  END_DO_SET();

  if (decl_arg_ctr > 0)
    *qp = ')';
  else
    strcat_box_ck (query_text, ")");

#if !defined (NO_XPF_EXT_CALL_CACHE)
  qr = cli_cached_sql_compile (query_text, cli, &err, "xpf-extension");
#else
  qr = sql_compile (query_text, cli, &err, SQLC_DEFAULT);
#endif
  if (err)
    goto err_end;
  err = qr_exec (cli, qr, xqi->xqi_qi, NULL, NULL, &lc, arr, NULL, 0);
  if (err)
    goto err_end;
  if (lc && DV_ARRAY_OF_POINTER == DV_TYPE_OF (lc->lc_proc_ret)
      && BOX_ELEMENTS ((caddr_t *)lc->lc_proc_ret) > 1)
    {
      caddr_t retc = (((caddr_t *)lc->lc_proc_ret)[1]);
      caddr_t ent;
#ifdef XPATH_DEBUG
      dk_check_tree (retc);
#endif
      switch (DV_TYPE_OF(retc))
        {
	case DV_DB_NULL:
	  XP_SET (res_ptr, NULL);
	  break;
	case DV_OBJECT:
	  ent = (caddr_t)(XMLTYPE_TO_ENTITY (retc));
	  XP_SET (res_ptr,
	    (ent ? box_copy_tree(ent) : box_copy_tree(retc)) );
	  break;
	default:
	  XP_SET (res_ptr, box_copy_tree (retc));
	}
    }
  else
    XP_SET (res_ptr, box_dv_short_string (""));
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, ((NULL == res_ptr[0]) ? XI_AT_END : XI_INITIAL));
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);

err_end:
  dk_free_box (query_text);
  dk_free_box ((box_t) arr);
  if (lc)
    lc_free(lc);
#if defined (NO_XPF_EXT_CALL_CACHE)
  qr_free (qr);
#endif
#ifdef XPATH_DEBUG
  dk_check_tree (XQI_GET (xqi, tree->_.xp_func.var->_.var.init));
#endif
  if (err)
    sqlr_resignal (err);
}


static char * xpf_extensions_tb =
  "CREATE TABLE DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME VARCHAR PRIMARY KEY, XPE_PNAME VARCHAR)";

static caddr_t
bif_xpf_extension (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t f;
  caddr_t pname;
  caddr_t * place;
  xpf_metadata_t **metas_ptr = NULL;
  query_t *proc;
  static query_t *xpf_store_query = NULL;
  int is_define = (BOX_ELEMENTS (args) > 2);

  if (!is_define)
    {
      f = bif_string_arg (qst, args, 0, "xpf_extension");
      pname = bif_string_arg (qst, args, 1, "xpf_extension");
    }
  else
    {
      f = bif_arg (qst, args, 0, "xpf_extension");
      pname = bif_arg (qst, args, 1, "xpf_extension");
      if (DV_TYPE_OF (f) != DV_SHORT_STRING && DV_TYPE_OF (f) != DV_LONG_STRING)
	{
	  log_error ("There's a row in DB.DBA.SYS_XPF_EXTENSION that has invalid XPE_NAME. "
	      "Please check, delete the row and restart the server");
	  return box_num (1);
	}
      if (DV_TYPE_OF (pname) != DV_SHORT_STRING && DV_TYPE_OF (f) != DV_LONG_STRING)
	{
	  log_error ("There's a row in DB.DBA.SYS_XPF_EXTENSION that has invalid XPE_PNAME. "
	      "Please check, delete the row and restart the server");
	  return box_num (1);
	}
    }

  if (NULL == (proc = sch_proc_def (wi_inst.wi_schema, pname)))
    {
      if (is_define)
	{
	  log_error ("The xpf extension function %s->%s does not exist. "
	      "Please delete the corresponding row from DB.DBA.SYS_XPF_EXTENSIONS and restart the server.",
	      f, pname);
	  return box_num (1);
	}
      else
	sqlr_new_error ("42001", "XPE01", "The function %s does not exist", pname);
    }

  if (!sec_proc_check (proc, G_ID_PUBLIC, U_ID_PUBLIC))
    {
      if (is_define)
	{
	  log_error ("The xpf extension function %s is not granted to public. "
	      "Either grant it or delete the corresponding row "
	      "from DB.DBA.SYS_XPF_EXTENSIONS and restart the server.", pname);
	  return box_num (1);
	}
      else
	sqlr_new_error ("42001", "XPE06", "The function %s is not granted to public", pname);
    }

  metas_ptr = (xpf_metadata_t **) id_hash_get (xpf_metas, (caddr_t) &f);
  if (metas_ptr && metas_ptr[0]->xpfm_executable != xpf_extension)
    {
      if (is_define)
	{
	  log_error ("The xpf extension %s function \"%s\" cannot be re-defined. "
	      "Delete the duplicate rows from DB.DBA.SYS_XPF_EXTENSIONS and restart the server.",
	      ((XPF_BUILTIN == metas_ptr[0]->xpfm_type) ? "built-in XPATH" : "XQuery"), f);
	  return box_num (1);
	}
      else
	sqlr_new_error ("42001", "XPE02",
	    "The %s function \"%s\" cannot be re-defined",
	    ((XPF_BUILTIN == metas_ptr[0]->xpfm_type) ? "built-in XPATH" : "XQuery"),
	  f);
    }

  place = (caddr_t *) id_hash_get (xp_ext_funcs, (caddr_t) &f);
  if (!place)
    {
      caddr_t f1, n1;
      f1 = box_copy (f); n1 = box_copy (pname);
      id_hash_set (xp_ext_funcs, (caddr_t) &f1, (caddr_t) &n1);
      xpf_define_builtin (f, xpf_extension /* ??? */, XPDV_NODESET, 0, NULL, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
    }
  else
    {
      dk_free_tree (*place);
      *place = box_copy (pname);
    }

  if (!is_define)
    {
      caddr_t err;
      query_instance_t *qi = (query_instance_t *)qst;
      if (!xpf_store_query)
	xpf_store_query = sql_compile (
                          "INSERT REPLACING DB.DBA.SYS_XPF_EXTENSIONS (XPE_NAME, XPE_PNAME) VALUES (?, ?)",
			  bootstrap_cli, NULL, SQLC_DEFAULT);
      err = qr_rec_exec (xpf_store_query, qi->qi_client, NULL, qi, NULL, 2,
	  ":0", f, QRP_STR,
	  ":1", pname, QRP_STR);
      if (NULL != err)
        sqlr_resignal (err);
    }

  return (box_num (0));
}


static caddr_t
bif_xpf_extension_remove (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t f = bif_string_arg (qst, args, 0, "xpf_extension_remove");
  caddr_t * place;
  xpf_metadata_t **metas_ptr = NULL;
  static query_t *xpf_remove_query = NULL;

  metas_ptr = (xpf_metadata_t **) id_hash_get (xpf_metas, (caddr_t) &f);
  if (metas_ptr && metas_ptr[0]->xpfm_executable != xpf_extension)
    sqlr_new_error ("42001", "XPE03",
      "The %s function \"%s\" cannot be removed",
      ((XPF_BUILTIN == metas_ptr[0]->xpfm_type) ? "built-in XPATH" : "XQuery"),
      f);

  place = (caddr_t *) id_hash_get (xp_ext_funcs, (caddr_t) &f);
  if (place)
    {
      caddr_t err;
      query_instance_t *qi = (query_instance_t *)qst;

      id_hash_remove (xp_ext_funcs, (caddr_t) &f);
      id_hash_remove (xpf_metas, (caddr_t) &f);

      if (!xpf_remove_query)
	xpf_remove_query = sql_compile ("DELETE FROM DB.DBA.SYS_XPF_EXTENSIONS WHERE XPE_NAME = ?",
	    bootstrap_cli, NULL, SQLC_DEFAULT);
      err = qr_rec_exec (xpf_remove_query, qi->qi_client, NULL, qi, NULL, 1, ":0", f, QRP_STR);
      if (NULL != err)
        sqlr_resignal (err);
    }

  return (box_num (0));
}

static void
xpf_sql_compare_int (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, int less, int eq, int greater)
{
  XT *arg1, *arg2;
  caddr_t val1, val2, res;
  dtp_t val1_dtp, val2_dtp, common_dtp;
  int cmp;
  arg1 = xpf_arg_tree (tree, 0);
  xqi_eval (xqi, arg1, ctx_xe);
  val1 = xqi_raw_value (xqi, arg1);
  val1_dtp = DV_TYPE_OF (val1);
  arg2 = xpf_arg_tree (tree, 1);
  xqi_eval (xqi, arg2, ctx_xe);
  val2 = xqi_raw_value (xqi, arg2);
  val2_dtp = DV_TYPE_OF (val2);
  if (IS_NUM_DTP (val1_dtp) || IS_NUM_DTP (val2_dtp))
    common_dtp = DV_NUMERIC;
  else
    common_dtp = DV_STRING;
  if (val1_dtp != common_dtp)
    val1 = xqi_value (xqi, arg1, common_dtp);
  if (val2_dtp != common_dtp)
    val2 = xqi_value (xqi, arg2, common_dtp);
  cmp = cmp_boxes (val1, val2, NULL, NULL);
  switch (cmp)
    {
    case DVC_LESS: res = box_num_nonull (less); break;
    case DVC_GREATER: res = box_num_nonull (greater); break;
    case DVC_MATCH: res = box_num_nonull (eq); break;
    default: res = NULL; break;
    }
  XQI_SET (xqi, tree->_.xp_func.res, res);
}


void
xpf_sql_equ (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_sql_compare_int (xqi, tree, ctx_xe, 0, 1, 0);
}

void
xpf_sql_ge (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_sql_compare_int (xqi, tree, ctx_xe, 0, 1, 1);
}

void
xpf_sql_gt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_sql_compare_int (xqi, tree, ctx_xe, 0, 0, 1);
}

void
xpf_sql_le (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_sql_compare_int (xqi, tree, ctx_xe, 1, 1, 0);
}

void
xpf_sql_lt (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_sql_compare_int (xqi, tree, ctx_xe, 1, 0, 0);
}

void
xpf_sql_neq (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_sql_compare_int (xqi, tree, ctx_xe, 1, 0, 1);
}

void
xpfm_create_and_store_builtin (
  const char *xpfm_name,
  xp_func_t xpfm_executable,
  ptrlong xpfm_res_dtp,
  ptrlong xpfm_min_arg_no,
  xpfm_arg_descr_t **xpfm_main_args,
  xpfm_arg_descr_t **xpfm_tail_args,
  const char* nmspace )
{
  caddr_t key_qname;
  size_t ctr, main_arg_no, tail_arg_no;
  xpf_metadata_t ** metas_ptr;
  xpf_metadata_t * metas;
  if (NULL != nmspace)
    {
      char buf[200];
      sprintf (buf, "%.100s:%.50s", nmspace, xpfm_name);
      key_qname = box_dv_uname_string (buf);
    }
  else
    key_qname = box_dv_uname_string (xpfm_name);
  box_dv_uname_make_immortal (key_qname);
  metas_ptr = (xpf_metadata_t **)id_hash_get (xpf_metas, (caddr_t)(&key_qname));
  if (NULL != metas_ptr)
    {
      int defs_match = (
        (metas_ptr[0]->xpfm_executable == xpfm_executable) &&
        (metas_ptr[0]->xpfm_defun == NULL) &&
        (metas_ptr[0]->xpfm_res_dtp == xpfm_res_dtp) &&
        (metas_ptr[0]->xpfm_min_arg_no == xpfm_min_arg_no) );
      log_info ("XPATH function %s is defined twice, %s", key_qname, (defs_match ? "relatively safe" : "totally wrong"));
      return;
    }
  main_arg_no = ((NULL == xpfm_main_args) ? 0 : BOX_ELEMENTS(xpfm_main_args));
  tail_arg_no = ((NULL == xpfm_tail_args) ? 0 : BOX_ELEMENTS(xpfm_tail_args));
  metas = (xpf_metadata_t *)dk_alloc_box_zero (
    sizeof(xpf_metadata_t) + (main_arg_no+tail_arg_no)*sizeof(xpfm_arg_descr_t),
    DV_ARRAY_OF_LONG );
  metas->xpfm_name = key_qname; /* No copying because it's been made immortal above */
  metas->xpfm_type = XPF_BUILTIN;
  metas->xpfm_executable = xpfm_executable;
  metas->xpfm_defun = NULL;
  metas->xpfm_res_dtp = xpfm_res_dtp;
  metas->xpfm_min_arg_no = xpfm_min_arg_no;
  metas->xpfm_main_arg_no = main_arg_no;
  metas->xpfm_tail_arg_no = tail_arg_no;
  for (ctr = 0; ctr < main_arg_no; ctr++)
    {
      memcpy (metas->xpfm_args+ctr, xpfm_main_args[ctr], sizeof (xpfm_arg_descr_t));
      dk_free_box ((caddr_t)(xpfm_main_args[ctr]));
    }
  dk_free_box ((caddr_t)(xpfm_main_args));
  for (ctr = 0; ctr < tail_arg_no; ctr++)
    {
      memcpy (metas->xpfm_args+main_arg_no+ctr, xpfm_tail_args[ctr], sizeof (xpfm_arg_descr_t));
      dk_free_box ((caddr_t)(xpfm_tail_args[ctr]));
    }
  dk_free_box ((caddr_t)(xpfm_tail_args));
  for (ctr = 0; ctr < main_arg_no + tail_arg_no; ctr++)
    box_dv_uname_make_immortal (metas->xpfm_args[ctr].xpfma_name);
  id_hash_set (xpf_metas, (caddr_t)(&key_qname), (caddr_t)(&metas));
  if ((NULL != xpfm_executable) && (xpf_extension != xpfm_executable))
    {
      caddr_t *old_rev_name_ptr = (caddr_t *)id_hash_get (xpf_reveng, (caddr_t)(&xpfm_executable));
      if (NULL != old_rev_name_ptr)
        log_info ("XPATH function %s can be declared as an alias of %s, but it does not", key_qname, old_rev_name_ptr[0]);
      else
        id_hash_set (xpf_reveng, (caddr_t)(&xpfm_executable), (caddr_t)(&(metas->xpfm_name)));
    }
  dk_check_tree (metas);
}

void
xpf_define_builtin (
  const char *xpfm_name,
  xp_func_t xpfm_executable,
  ptrlong xpfm_res_dtp,
  ptrlong xpfm_min_arg_no,
  xpfm_arg_descr_t **xpfm_main_args,
  xpfm_arg_descr_t **xpfm_tail_args )
{
/* The order of these declarations is important because the first one is used for reverse searches */
  xpfm_create_and_store_builtin (xpfm_name, xpfm_executable, xpfm_res_dtp, xpfm_min_arg_no, xpfm_main_args, xpfm_tail_args, NULL);
  xpfm_store_alias (xpfm_name, XXF_NS_URI, xpfm_name, NULL, "/#", 0);
  xpfm_store_alias (xpfm_name, XXF_NS_URI, xpfm_name, NULL, "#", 0);
  xpfm_store_alias (xpfm_name, XXF_NS_URI, xpfm_name, NULL, "", 0);
}

void
x2f_define_builtin (
  const char *xpfm_name,
  xp_func_t xpfm_executable,
  ptrlong xpfm_res_dtp,
  ptrlong xpfm_min_arg_no,
  xpfm_arg_descr_t **xpfm_main_args,
  xpfm_arg_descr_t **xpfm_tail_args )
{
/* The order of these declarations is important because the first one is used for reverse searches */
  xpf_define_builtin (xpfm_name, xpfm_executable, xpfm_res_dtp, xpfm_min_arg_no, xpfm_main_args, xpfm_tail_args);
  xpfm_store_alias (xpfm_name, XFN_NS_URI, xpfm_name, NULL, "/#", 0);
  xpfm_store_alias (xpfm_name, XFN_NS_URI, xpfm_name, NULL, "#", 0);
  xpfm_store_alias (xpfm_name, XFN_NS_URI, xpfm_name, NULL, "", 0);
}

void
xpfm_store_alias (const char *alias_local_name, const char *alias_ns, const char *main_local_name, const char *main_ns, const char *alias_mid_chars, int insert_soft)
{
  caddr_t alias_n = (alias_ns ? box_sprintf (200, "%.100s%.10s:%.50s", alias_ns, alias_mid_chars, alias_local_name) : box_dv_short_string (alias_local_name));
  caddr_t main_n = (main_ns ? box_sprintf (200, "%.100s:%s", main_ns, main_local_name) : box_dv_short_string (main_local_name));
  xpf_metadata_t ** main_metas_ptr, **alias_metas_ptr;
  alias_n = box_dv_uname_string (alias_n);
  box_dv_uname_make_immortal (alias_n);
  main_n = box_dv_uname_string (main_n);
  box_dv_uname_make_immortal (main_n);
  alias_metas_ptr = (xpf_metadata_t **)id_hash_get (xpf_metas, (caddr_t)(&alias_n));
  main_metas_ptr = (xpf_metadata_t **)id_hash_get (xpf_metas, (caddr_t)(&main_n));
  if (NULL == main_metas_ptr)
    {
      log_info ("XPATH function %s is not defined so it can not be aliased as %s", main_n, alias_n);
      return;
    }
  if (NULL != alias_metas_ptr)
    {
      int defs_match;
      if (insert_soft)
        return;
      defs_match = (
        (main_metas_ptr[0]->xpfm_executable == alias_metas_ptr[0]->xpfm_executable) &&
        (main_metas_ptr[0]->xpfm_defun == alias_metas_ptr[0]->xpfm_defun) &&
        (main_metas_ptr[0]->xpfm_res_dtp == alias_metas_ptr[0]->xpfm_res_dtp) &&
        (main_metas_ptr[0]->xpfm_min_arg_no == alias_metas_ptr[0]->xpfm_min_arg_no) );
#ifndef DEBUG
      if (!defs_match)
#endif
      log_info ("XPATH function %s is defined but redefind as alias of %s, %s", alias_n, main_n, (defs_match ? "relatively safe" : "totally wrong"));
      return;
    }
  id_hash_set (xpf_metas, (caddr_t)(&alias_n), (caddr_t)(main_metas_ptr));
}

void
xpf_define_alias (const char *alias_local_name, const char *alias_ns, const char *main_local_name, const char *main_ns)
{
  xpfm_store_alias (alias_local_name, alias_ns, main_local_name, main_ns, "/#", 0);
  if (NULL != alias_ns)
    {
      xpfm_store_alias (alias_local_name, alias_ns, main_local_name, main_ns, "/", 0);
      xpfm_store_alias (alias_local_name, alias_ns, main_local_name, main_ns, "", 0);
    }
}

typedef struct xp_addr_ent_s {
  ptrlong *xae_addr;
  union
    {
      xml_entity_t *xae_ent;
      caddr_t *xae_subtree;
    } _;
} xp_addr_ent_t;


static int xpf_compare_aes ( const xp_addr_ent_t *arg_A, const xp_addr_ent_t *arg_B)
{
  ptrlong *lp_A = arg_A->xae_addr;
  ptrlong *lp_B = arg_B->xae_addr;
  int num_elements_A = BOX_ELEMENTS(lp_A);
  int num_elements_B = BOX_ELEMENTS(lp_B);
  int i = 0;
  if (lp_A[i] < lp_B[i]) return XE_CMP_A_DOC_LT_B;
  if (lp_A[i] > lp_B[i]) return XE_CMP_A_DOC_GT_B;
  for (;;)
    {
      i++;
      if (i == num_elements_A)
        return ((i == num_elements_B) ? XE_CMP_A_IS_EQUAL_TO_B : XE_CMP_A_IS_ANCESTOR_OF_B);
      if (i == num_elements_B)
        return XE_CMP_A_IS_DESCENDANT_OF_B;
      if (lp_A[i] < lp_B[i]) return XE_CMP_A_IS_BEFORE_B;
      if (lp_A[i] > lp_B[i]) return XE_CMP_A_IS_AFTER_B;
    }
}


static caddr_t *
xpf_filter_shallow_copy (xp_instance_t * xqi, xml_entity_t *xe, size_t no_of_children)
{
#ifdef DEBUG
  if (DV_XML_ENTITY != DV_TYPE_OF (xe))
    GPF_T1("Internal type checking error in xpf_filter");
#endif
  if (XE_IS_PERSISTENT(xe))
    sqlr_new_error_xqi_xdl ("XP001", "XPFF0", xqi, "Persistent XML entities are not supported in XQuery function filter()");
  else
    {
      xml_tree_ent_t *xte = (xml_tree_ent_t *)xe;
      caddr_t *res;
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF(xte->xte_current))
        return (caddr_t *)(box_copy_tree ((box_t) xte->xte_current));
      res = (caddr_t *) dk_alloc_box_zero ((1+no_of_children) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      res[0] = box_copy_tree(((caddr_t *)(xte->xte_current))[0]);
      return res;
    }
  GPF_T;
  return NULL; /* never happens */
}


void xpf_create_filter_sequence (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, int ae_count)
{
  dk_set_t documents = NULL;
  caddr_t documents_array;
  query_instance_t * qi = xqi->xqi_qi;
  int stack_len, child_cnt, child_idx;
  void **func_tmp = (void **)(XQI_GET(xqi,tree->_.xp_func.tmp));
  xp_addr_ent_t *aes = (xp_addr_ent_t *)(func_tmp[0]);
  xp_addr_ent_t **stack;
  int ae_idx = ae_count - 1;
  caddr_t * node_subtree;	/*new box for last node in document*/
  xml_entity_t *xe;
  int cmp_res;
  stack = (xp_addr_ent_t **)dk_alloc_box_zero (ae_count * sizeof (xp_addr_ent_t *), DV_ARRAY_OF_LONG); /* not DV_ARRAY_OF_POINTER to avoid double free. */
  func_tmp[1] = stack;
  stack_len = 0;

  /* Decision making */

make_next_decision:
  if (0 > ae_idx)
    {
      if (stack_len > 0)
        goto do_flushing;
      goto do_exit;
    }
  if (0 == stack_len)
    goto do_shift;
  cmp_res = xpf_compare_aes (stack[stack_len-1], aes + ae_idx);
  switch (cmp_res)
    {
    case XE_CMP_A_DOC_LT_B:
    case XE_CMP_A_DOC_GT_B:
      goto do_flushing;
    case XE_CMP_A_IS_DESCENDANT_OF_B:
      goto do_reduce;
    case XE_CMP_A_IS_EQUAL_TO_B:
      goto do_skip;
    default:
      goto do_shift;
    }

  /* Decision implementation */

do_flushing:
  while (stack_len > 0)
    {
      xml_entity_t * document;
      dtd_t *doc_dtd = NULL;
      stack_len--;
      node_subtree = stack[stack_len]->_.xae_subtree;
#ifdef DEBUG
      if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF(node_subtree)) && (DV_STRING != DV_TYPE_OF(node_subtree)))
	GPF_T1("Invalid input for xte_from_tree in xpf_filter");
#endif
      if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (node_subtree)) || (uname__root != (XTE_HEAD_NAME (XTE_HEAD (node_subtree)))))
        node_subtree = (caddr_t *) list (2, list (1, uname__root), node_subtree);
      document = (xml_entity_t *)xte_from_tree ((caddr_t)node_subtree, qi);
      stack[stack_len]->_.xae_subtree = NULL;
      document->xe_doc.xd->xd_dtd = doc_dtd; /* Refcounter added inside xml_make_tree */
      XD_DOM_LOCK(document->xe_doc.xd);
/*
No need now?
      dk_set_push (&ctx_xe->xe_doc.xd->xd_top_doc->xd_referenced_documents, (void*) document->_->xe_copy(document));
*/
      dk_set_push (&documents, (void*) (document));
#ifdef DEBUG
      stack[stack_len] = NULL;
#endif
    }
  goto make_next_decision;

do_shift:
  xe = aes[ae_idx]._.xae_ent;
  node_subtree = xpf_filter_shallow_copy (xqi, xe, 0);
  goto do_push;

do_reduce:
  xe = aes[ae_idx]._.xae_ent;
  child_cnt = 1; /* we have at least one */
  while ((child_cnt < stack_len) &&
    (XE_CMP_A_IS_DESCENDANT_OF_B == xpf_compare_aes (stack[stack_len-(1+child_cnt)], aes + ae_idx)))
    child_cnt++;
  node_subtree = xpf_filter_shallow_copy (xqi, xe, child_cnt);
  for (child_idx = 1; child_idx <= child_cnt; child_idx++)
    {
      xp_addr_ent_t *child_ae = stack[stack_len-child_idx];
      node_subtree[child_idx] = (caddr_t)(child_ae->_.xae_subtree);
      child_ae->_.xae_subtree = NULL;
#ifdef DEBUG
      stack[stack_len-child_idx] = NULL; /* to get an error */
#endif
    }
  stack_len -= child_cnt;
  goto do_push;

do_push:
  dk_free_tree ((box_t) xe);
  aes[ae_idx]._.xae_subtree = node_subtree;
  stack[stack_len] = aes + ae_idx;
  ae_idx--;
  stack_len++;
  xqi_check_slots (xqi);
  goto make_next_decision;

do_skip:
  ae_idx--;
  goto make_next_decision;

do_exit:
  documents_array = list_to_array_of_xqval (dk_set_nreverse (documents));
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, documents_array );
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
  xqi_check_slots (xqi);
  return;
}


void xpf_filter (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xp_addr_ent_t *aes;
  caddr_t* nodes;
  size_t nodes_length;
  int i;
  xml_entity_t * point;
  qi_signal_if_trx_error (xqi->xqi_qi);
  xqi_check_slots (xqi);
  xpf_arg_list (xqi, tree, ctx_xe, 0, XQI_ADDRESS(xqi,tree->_.xp_func.res));
  nodes = (caddr_t *) XQI_GET(xqi,tree->_.xp_func.res);
  nodes_length = BOX_ELEMENTS (nodes);
  for (i=0; i < (int)nodes_length; i++)
    {
      point=(xml_entity_t *)nodes[i];
      if (DV_XML_ENTITY != DV_TYPE_OF (point))
	{
          sqlr_new_error_xqi_xdl ("XP001", "XPFB0", xqi, "The argument of XQuery function filter() must be a sequence of XML entities");
	}
    }
  aes = (xp_addr_ent_t *) dk_alloc_box (nodes_length * sizeof (xp_addr_ent_t), DV_ARRAY_OF_POINTER);
  XQI_SET(xqi,tree->_.xp_func.tmp, list (2, aes, NULL /* for stack in xpf_create_filter_sequence */));
  for (i = 0; i < (int)nodes_length; i++)
    {
      dk_set_t lp = NULL;
      point = (xml_entity_t *)nodes[i];
      point->_->xe_get_logical_path (point, &lp);
      aes[i]._.xae_ent = point;
      nodes[i] = NULL;
      aes[i].xae_addr = (ptrlong *)list_to_array (lp);
      box_tag_modify (aes[i].xae_addr, DV_ARRAY_OF_LONG);
    }
  qsort (aes, BOX_ELEMENTS(nodes), 2*sizeof(caddr_t), (int (*)(const void *, const void *)) xpf_compare_aes);
  xqi_check_slots (xqi);
  xpf_create_filter_sequence( xqi, tree, ctx_xe, (int) nodes_length);
}

void xpf_sql_column_select (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  sqlr_new_error_xqi_xdl ("XP001", "XPF14", xqi, "The special XQuery function sql_column_select() is used outside 'for ... in ...' statement.");
}

void xpf_sql_scalar_select (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int query_is_sparql = 0;
  caddr_t query_raw_text, query_text, query_final_text;
  int proc_parent_is_saved = 0;
  query_instance_t *qi = xqi->xqi_qi;
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
  int cols_count;
  PROC_SAVE_VARS;
  query_raw_text = query_text = xpf_arg (xqi, tree, ctx_xe, DV_C_STRING, 0);
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
        sqlr_new_error_xqi_xdl ("XS370", "XPFXX", xqi, "sparql or sql query should be a string");
    }
  if (query_is_sparql)
    {
      caddr_t preamble = NULL;
      caddr_t preamble_to_free = NULL;
      xqi_binding_t *xb;
      static caddr_t sparql_preamble_global_var_name = NULL;
      if (NULL == sparql_preamble_global_var_name)
        sparql_preamble_global_var_name = box_dv_uname_string ("__sparql_preamble");
      for (xb = xqi->xqi_xp_globals; NULL != xb; xb = xb->xb_next)
        {
          if (!xb->xb_name)
            break;
          if (xb->xb_name == sparql_preamble_global_var_name)
            preamble = xb->xb_value;
        }
      if (NULL == preamble)
        {
          dk_session_t *tmp_ses = strses_allocate ();
          /*xml_ns_2dict_t *ns2d = &(xqi->xp->xp_sheet->xsh_ns_2dict);
          int ns_ctr = ns2d->xn2_size;*/
          SES_PRINT (tmp_ses, "sparql define output:valmode \"AUTO\" define sql:globals-mode \"XSLT\" ");
          /*while (ns_ctr--)
            {
              SES_PRINT (tmp_ses, "prefix ");
              SES_PRINT (tmp_ses, ns2d->xn2_prefix2uri[ns_ctr].xna_key);
              SES_PRINT (tmp_ses, ": <");
              SES_PRINT (tmp_ses, ns2d->xn2_prefix2uri[ns_ctr].xna_value);
              SES_PRINT (tmp_ses, "> ");
            }*/
          preamble = preamble_to_free = strses_string (tmp_ses);
          dk_free_box (tmp_ses);
        }
      query_final_text = box_dv_short_strconcat (preamble, query_text);
      if (query_text != query_raw_text)
        dk_free_box (query_text);
      dk_free_tree (preamble_to_free);
    }
  else
    query_final_text = (query_text != query_raw_text) ? query_text : box_copy (query_text);
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
  XQI_SET (xqi, tree->_.xp_func.tmp, (caddr_t)params);
  param_ofs = 0;
  DO_SET (state_slot_t *, ssl, &qr->qr_parms)
    {
      char *name = ssl->ssl_name;
      caddr_t val;
      xqi_binding_t *xb;
      if ((NULL == name) || (':' != name[0]) || alldigits (name+1))
        {
          err = sqlr_make_new_error_xqi_xdl ("XS370", "XP???", xqi, "%s parameter of the query can not be bound, only named parameters can be associated with XPATH/XSLT variables of the context", ((NULL!=name) ? name : "anonymous"));
          goto err_generated; /* see below */
        }
      xb = xqi_find_binding (xqi, box_dv_uname_string (name+1));
      if (NULL == xb)
        {
          err = sqlr_make_new_error_xqi_xdl ("XS370", "XP???", xqi, "%s%.100s parameter of the query can not be bound, there's no corresponding XSLT variable $%.100s",
            query_is_sparql ? "$" : "", name, name+1 );
          goto err_generated; /* see below */
        }
      params[param_ofs++] = box_copy (name);
      val = xb->xb_value;
      if (NULL == val)
        val = NEW_DB_NULL;
      else if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val))
        {
          if (0 == BOX_ELEMENTS (val))
            val = NEW_DB_NULL;
          else
            val = box_copy_tree (((caddr_t **)val)[0]);
        }
      else
        val = box_copy_tree (val);
      params[param_ofs++] = val;
    }
  END_DO_SET ()
  err = qr_exec (cli, qr, qi, NULL, NULL, &lc,
      params, NULL, 1);
  memset (params, 0, param_ofs * sizeof (caddr_t));
  XQI_SET (xqi, tree->_.xp_func.tmp, NULL);
  params = NULL;
  if (err)
    goto err_generated; /* see below */
  if ((NULL == lc) || !(qr->qr_select_node))
    {
      err = sqlr_make_new_error_xqi_xdl ("XS370", "XP???", xqi, "An SQL statement did not produce any (even empty) result-set");
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
  if (1 != cols_count)
    {
      err = sqlr_make_new_error_xqi_xdl ("XS370", "XP???", xqi, "A scalar SQL statement should produce a result-set with only one column");
      goto err_generated; /* see below */
    }
  if (lc_next (lc))
    {
      caddr_t new_val = lc_nth_col (lc, 0);
      rb_cast_to_xpath_safe (qi, new_val, XQI_ADDRESS(xqi, tree->_.xp_func.res));
    }
  else if (1 < tree->_.xp_func.argcount)
    XQI_SET (xqi, tree->_.xp_func.res, box_copy_tree (xpf_arg (xqi, tree, ctx_xe, DV_UNKNOWN, 1)));
  else
    XQI_SET (xqi, tree->_.xp_func.res, NULL);
  err = lc->lc_error;
  lc->lc_error = NULL;
  lc_free (lc);
  if (err)
    goto err_generated; /* see below */

  dk_free_tree (list_to_array (sql_warnings_save (warnings)));
  return;
err_generated:
  if (lc)
    lc_free (lc);
  if (params)
    XQI_SET (xqi, tree->_.xp_func.tmp, NULL);
  if (NULL != query_shc)
    shcompo_release (query_shc);
  if (proc_parent_is_saved)
    PROC_RESTORE_SAVED;
  sqlr_resignal (err);

}

void xpf_xmlview (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  sqlr_new_error_xqi_xdl ("XP001", "XPF14", xqi, "The special XQuery function xmlview() is used outside 'for ... in ...' statement.");
}

void xpf_xpath_debug_srcfile (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xml_entity_t *xe = (xml_entity_t *)xpf_raw_arg (xqi, tree, ctx_xe, 0);
  caddr_t file = ((DV_XML_ENTITY == DV_TYPE_OF (xe)) ? xe->_->xe_attrvalue (xe, uname__srcfile) : NULL);
  XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string ((NULL == file) ? "" : file));
  dk_free_box (file);
}

void xpf_xpath_debug_srcline (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xml_entity_t *xe = (xml_entity_t *)xpf_raw_arg (xqi, tree, ctx_xe, 0);
  caddr_t line = ((DV_XML_ENTITY == DV_TYPE_OF (xe)) ? xe->_->xe_attrvalue (xe, uname__srcline) : NULL);
  XQI_SET (xqi, tree->_.xp_func.res, ((NULL == line) ? box_dv_short_string ("0") : line));
}

void xpf_xpath_debug_xslfile (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  char *file = xqi->xqi_xqr->xqr_xdl.xdl_file;
  XQI_SET (xqi, tree->_.xp_func.res, box_dv_short_string ((NULL == file) ? "" : file));
}

void xpf_xpath_debug_xslline (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t line = xqi->xqi_xqr->xqr_xdl.xdl_line;
  XQI_SET (xqi, tree->_.xp_func.res, ((NULL == line) ? box_dv_short_string ("0") : box_copy (line)));
}

static void
xpf_intersect_except (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, int is_intersect)
{
  caddr_t *tmp, *seq1, *seq2, *seq3 = 0;
  int inx;
  dk_set_t set = 0;
  caddr_t* arr;
  tmp = (caddr_t *)list (2, NULL, NULL);
  XQI_SET (xqi, tree->_.xp_func.tmp, (caddr_t) tmp);
  xpf_arg_list (xqi, tree, ctx_xe, 0, tmp);
  xpf_arg_list (xqi, tree, ctx_xe, 1, tmp+1);
  seq1 = (caddr_t*) tmp[0];
  seq2 = (caddr_t*) tmp[1];

  if ((DV_ARRAY_OF_XQVAL != DV_TYPE_OF (seq1)) ||
      (DV_ARRAY_OF_XQVAL != DV_TYPE_OF (seq2)))
    sqlr_new_error ("42001", "XQR??", "The both arguments of %s must be sequences", tree->_.xp_func.qname);

  /* bad algo, must be rewritten */
 again:
  DO_BOX (xml_entity_t*, elt1, inx, seq1)
    {
      int inx2;
      if (DV_XML_ENTITY != DV_TYPE_OF(elt1))
	continue;
      for (inx2=0;inx2<BOX_ELEMENTS(seq2);inx2++)
	{
	  xml_entity_t * elt2 = (xml_entity_t*)seq2[inx2];
	  if (DV_XML_ENTITY != DV_TYPE_OF (elt2))
	    continue;
	  if (elt1->_->xe_is_same_as (elt1, elt2))
	    {
	      if (is_intersect)
		{
		  dk_set_push (&set, box_copy(elt1));
		  goto next;
		}
	      else
		goto next;
	    }
	}
      if (!is_intersect)
	{
	  dk_set_push (&set, box_copy(elt1));
	}
    next:
      ;
    }
  END_DO_BOX;
  if (!is_intersect && !seq3) /* first round */
    {
      seq3 = seq1;
      seq1 = seq2;
      seq2 = seq3;
      goto again;
    }
  arr = (caddr_t*) list_to_array_of_xqval (dk_set_nreverse(set));
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, (caddr_t) arr);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
}

void
xpf_intersect (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_intersect_except (xqi, tree, ctx_xe, 1);
}

void
xpf_except (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  xpf_intersect_except (xqi, tree, ctx_xe, 0);
}


static int
xpf_deep_equal_eq (caddr_t left, caddr_t right)
{
  dtp_t left_dtp = DV_TYPE_OF (left);
  if (DV_TYPE_OF(right) != left_dtp)
    return 0;
  switch (left_dtp)
    {
    case DV_XML_ENTITY:
      {
        xml_entity_t *left_xe = (xml_entity_t *)left;
        return xe_are_equal (left_xe, (xml_entity_t *)right);
      }
    case DV_ARRAY_OF_POINTER:
      {
        int ctr = BOX_ELEMENTS (left);
        if (BOX_ELEMENTS (right) != ctr)
          return 0;
        while (ctr--)
          if (!xpf_deep_equal_eq (((caddr_t *)left)[ctr], ((caddr_t *)right)[ctr]))
            return 0;
        return 1;
      }
    default:
      return box_equal (left, right);
    }
}


static void
xpf_deep_equal (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  XT *left_arg = xpf_arg_tree (tree, 0);
  XT *right_arg = xpf_arg_tree (tree, 1);
  caddr_t left_raw, right_raw;
  caddr_t *left_seq = NULL, *right_seq = NULL;
  int left_start = 0, right_start = 0, left_len = 0, right_len = 0, curr_idx = 0, left_end = 0, right_end = 0, loop_end;
  xqi_eval (xqi, left_arg, ctx_xe);
  left_raw = xqi_raw_value (xqi, left_arg);
  xqi_eval (xqi, right_arg, ctx_xe);
  right_raw = xqi_raw_value (xqi, right_arg);

again:
  if ((left_raw == NULL) && (right_raw == NULL))
    {
      if (left_end == right_end)
        goto full_match;
      goto mismatch;
    }
  if ((left_raw == right_raw) && (left_end == right_end))
    {
      left_raw = (xqi_is_next_value (xqi, left_arg) ? xqi_raw_value (xqi, left_arg) : NULL);
      right_raw = (xqi_is_next_value (xqi, right_arg) ? xqi_raw_value (xqi, right_arg) : NULL);
      goto again;
    }
  if (curr_idx >= left_end)
    {
      left_start = left_end;
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(left_raw))
	{
	  left_seq = (caddr_t *)left_raw;
	  left_len = BOX_ELEMENTS(left_seq);
        }
      else if (NULL != left_raw)
	{
	  left_seq = &left_raw;
	  left_len = 1;
	}
      else
	{
	  left_seq = NULL;
	  left_len = 0;
	}
      left_end = left_start + left_len;
    }
  if (curr_idx >= right_end)
    {
      right_start = right_end;
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(right_raw))
	{
	  right_seq = (caddr_t *)right_raw;
	  right_len = BOX_ELEMENTS(right_seq);
	}
      else if (NULL != right_raw)
	{
	  right_seq = &right_raw;
	  right_len = 1;
	}
      else
	{
	  right_seq = NULL;
	  right_len = 0;
	}
      right_end = right_start + right_len;
    }
  loop_end = left_end;
  if (right_end < loop_end)
    loop_end = right_end;
  while (curr_idx < loop_end)
    {
      if (!xpf_deep_equal_eq (left_seq[curr_idx - left_start], right_seq[curr_idx - right_start]))
	goto mismatch;
      curr_idx++;
    }
  if (curr_idx >= left_end)
    {
      left_raw = (((NULL != left_raw) && xqi_is_next_value (xqi, left_arg)) ? xqi_raw_value (xqi, left_arg) : NULL);
      if ((NULL == left_raw) && (curr_idx < right_end))
        goto mismatch;
    }
  if (curr_idx >= right_end)
    {
      right_raw = (((NULL != right_raw) && xqi_is_next_value (xqi, right_arg)) ? xqi_raw_value (xqi, right_arg) : NULL);
      if ((NULL == right_raw) && (curr_idx < left_end))
        goto mismatch;
    }
  goto again;

full_match:
  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (1));
  return;

mismatch:
  XQI_SET (xqi, tree->_.xp_func.res, box_num_nonull (0));
}


#define XQI_HALFFREE_XP_GLOBALS(xqi) \
  do { \
        xqi_binding_t *xb = xqi->xqi_xp_globals; \
	while (NULL != xb) \
	  { \
	    xqi_binding_t *next = xb->xb_next; \
	    dk_free (xb, sizeof (xqi_binding_t)); \
	    xb = next; \
	  } \
      } while (0)

void
xpf_processXQuery (xp_instance_t * outer_xqi, XT * tree, xml_entity_t * ctx_xe)
{
  caddr_t err = NULL;
  caddr_t xq_rel_uri = xpf_arg (outer_xqi, tree, ctx_xe, DV_STRING, 0);
  char *own_file = ((NULL != outer_xqi->xqi_xqr->xqr_base_uri) ? outer_xqi->xqi_xqr->xqr_base_uri : outer_xqi->xqi_xqr->xqr_xdl.xdl_file);
  caddr_t xq_base_uri = ((NULL == own_file) ? box_dv_short_string ("") : box_dv_short_string (own_file));
  caddr_t xq_uri = NULL;
  caddr_t raw_xe = ((1 < tree->_.xp_func.argcount) ? xpf_raw_arg (outer_xqi, tree, ctx_xe, 1) : (caddr_t)ctx_xe);
  ptrlong nth_res = ((2 < tree->_.xp_func.argcount) ? unbox (xpf_arg (outer_xqi, tree, ctx_xe, DV_LONG_INT, 2)) : (ptrlong)1);
  ptrlong v_inx = 1;
  xml_entity_t * xe;
  shuric_t *xqr_shu = NULL;
  xp_query_t *xqr = NULL;
  xp_instance_t *inner_xqi = NULL;
  dk_set_t res_acc = NULL;
  caddr_t res = NULL;
  XQI_SET_INT (outer_xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (outer_xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (outer_xqi, tree->_.xp_func.var->_.var.inx, 0);
  XQI_SET (outer_xqi, tree->_.xp_func.tmp, list (2, xq_base_uri, NULL));
  if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (raw_xe))
    raw_xe = ((BOX_ELEMENTS (raw_xe)) ? (((caddr_t *)raw_xe)[0]) : NULL);
  if (DV_XML_ENTITY != DV_TYPE_OF (raw_xe))
    sqlr_new_error_xqi_xdl ("XP001", "XP???", outer_xqi, "The argument 2 of XPATH function processXQuery() must be an XML entity");
  xe = (xml_entity_t *)raw_xe;
  QR_RESET_CTX
    {
      int paramcount = ((3 < tree->_.xp_func.argcount) ? (tree->_.xp_func.argcount - 3) : 0);
      int paramctr;
      xq_uri = xml_uri_resolve_like_get (outer_xqi->xqi_qi, &err, xq_base_uri, xq_rel_uri, "UTF-8");
      ((caddr_t *)(XQI_GET (outer_xqi, tree->_.xp_func.tmp)))[1] = xq_uri;
      if (err)
	sqlr_resignal (err);
      xqr_shu = xqr_shuric_retrieve (outer_xqi->xqi_qi, xq_uri, &err, NULL);
      if (err)
	sqlr_resignal (err);
      xqr = (xp_query_t *)(xqr_shu->shuric_data);
      inner_xqi = xqr_instance (xqr, outer_xqi->xqi_qi);
      for (paramctr = 0; paramctr < paramcount-1; paramctr += 2)
	{
	  caddr_t name = xpf_arg (outer_xqi, tree, ctx_xe, DV_STRING, paramctr + 3);
	  NEW_VARZ (xqi_binding_t, xb);
	  xb->xb_next = inner_xqi->xqi_xp_globals;
	  inner_xqi->xqi_xp_globals = xb;
	  if (!DV_STRINGP (name))
	    sqlr_new_error_xqi_xdl ("22023", "XI033", outer_xqi, "XQuery parameter name is not a string");
	  xb->xb_name = box_dv_uname_string (name);
	  xb->xb_value = xpf_raw_arg (outer_xqi, tree, ctx_xe, paramctr + 4);
	}
      if (NULL == outer_xqi->xqi_doc_cache)
	outer_xqi->xqi_doc_cache = xml_doc_cache_alloc (&(outer_xqi->xqi_doc_cache));
      inner_xqi->xqi_doc_cache = outer_xqi->xqi_doc_cache;
      inner_xqi->xqi_return_attrs_as_nodes = 1;
      inner_xqi->xqi_xpath2_compare_rules = 1;
      xqi_eval (inner_xqi, xqr->xqr_tree, xe);
      if (!xqi_is_value (inner_xqi, xqr->xqr_tree))
        goto no_more_results;
      do {
	  caddr_t val;
	  if (0 == nth_res)
	    {
	      val = xqi_raw_value (inner_xqi, xqr->xqr_tree);
	      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val))
	        {
	          size_t sz = BOX_ELEMENTS (val);
	          size_t ctr;
	          for (ctr = 0; ctr < sz; ctr++)
	            dk_set_push (&res_acc, box_copy_tree (((caddr_t *)val)[ctr]));
		}
	      else
		dk_set_push (&res_acc, box_copy_tree (val));
	    }
	  else if (v_inx == nth_res)
	    {
	      val = xqi_raw_value (inner_xqi, xqr->xqr_tree);
	      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val))
	        res = box_copy_tree (val);
	      else
	        dk_set_push (&res_acc, box_copy_tree (val));
	      break;
	    }
	  v_inx++;
	} while (xqi_is_next_value (inner_xqi, xqr->xqr_tree));

no_more_results:
      ;
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      if (inner_xqi)
        {
	  XQI_HALFFREE_XP_GLOBALS (inner_xqi);
	  xqi_free (inner_xqi);
	}
      POP_QR_RESET;
      shuric_release (xqr_shu);
      while (NULL != res_acc) dk_free_tree (dk_set_pop (&res_acc));
      if (err)
	sqlr_resignal (err);
    }
  END_QR_RESET;
  XQI_HALFFREE_XP_GLOBALS (inner_xqi);
  xqi_free (inner_xqi);
  shuric_release (xqr_shu);
  if (NULL == res)
    res = list_to_array_of_xqval (dk_set_nreverse (res_acc));
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (res);
#endif
  XQI_SET (outer_xqi, tree->_.xp_func.var->_.var.init, res);
}

void
xpf_collection_dir_list (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  query_instance_t * qi = xqi->xqi_qi;
  client_connection_t * cli = qi->qi_trx->lt_client;
  const char *uri = ctx_xe->xe_doc.xd->xd_uri;
  caddr_t *cache_key = (caddr_t *)list (2, (ptrlong)XDC_COLLECTION, NULL);
  caddr_t rel_uri;
  XT *doc_arg = xpf_arg_tree (tree, 0);
  static query_t * proc = NULL;
  caddr_t *res = NULL;
  caddr_t err = NULL;
  local_cursor_t * lc = NULL;
  ptrlong recursive = 1;
  if (NULL == proc)
    {
      proc = sql_compile ("select DB.DBA.XML_COLLECTION_DIR_LIST (?, ?)", cli, &err, SQLC_DEFAULT);
      if (err)
	sqlr_resignal (err);
    }

  switch (tree->_.xp_func.argcount)
    {
    default:
      sqlr_new_error_xqi_xdl ("XP001", "XPF09", xqi, "Too many arguments passed to XPATH function collection()");
    case 3:
      recursive = (ptrlong) unbox (xpf_arg (xqi, tree, ctx_xe, DV_LONG_INT, 2)) ;
    case 2:
      {
	caddr_t base = (caddr_t)xpf_raw_arg (xqi, tree, ctx_xe, 1);
        switch (DV_TYPE_OF (base))
	  {
	  case DV_XML_ENTITY:
	    uri = xe_get_sysid_base_uri ((xml_entity_t *)base);
	    break;
	  case DV_STRING:
	    uri = base;
	    break;
	  default:
	    sqlr_new_error_xqi_xdl ("XP001", "XPF10", xqi, "XML entity or a string expected as \"base_uri\" argument of XPATH function document()");
	  }
      }
    case 1:
    case 0: ;
    }

  xqi_eval (xqi, doc_arg, ctx_xe);
  rel_uri = xqi_value (xqi, doc_arg, DV_SHORT_STRING);
  if (NULL == rel_uri)
    {
      res = NULL;
      goto scan_complete;
    }
  cache_key[1] = (caddr_t) xml_uri_resolve (xqi->xqi_qi, &err, (caddr_t) uri, rel_uri, NULL); /* TODO: Must be UTF8*/
  res = (caddr_t*)xml_doc_cache_get_copy (xqi->xqi_doc_cache, (caddr_t)cache_key);
  if (NULL != res)
    {
      goto scan_complete;
    }
  if (err)
    goto scan_error;
#ifdef DEBUG
  if (NULL == cache_key[1])
    GPF_T;
#endif
  err = qr_rec_exec (proc, cli, &lc, qi, NULL, 2, ":0", cache_key[1], QRP_STR, ":1", recursive, QRP_INT);
  if (err)
    {
      LC_FREE (lc);
      goto scan_error;
    }
  if (lc_next (lc))
    {
      res = (caddr_t*) box_copy_tree (lc_nth_col (lc, 0));
      xml_doc_cache_add_copy (&(xqi->xqi_doc_cache), (caddr_t)cache_key, (caddr_t)res);
    }
  LC_FREE (lc);

scan_complete:
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.state, XI_INITIAL);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.init, (caddr_t)res);
  XQI_SET (xqi, tree->_.xp_func.var->_.var.res, NULL);
  XQI_SET_INT (xqi, tree->_.xp_func.var->_.var.inx, 0);
  dk_free_tree (cache_key);
  return;

scan_error:
  dk_free_tree (cache_key);
  sqlr_resignal (err);
}

void xpf_init(void)
{
  default_doc_dtd_config = box_dv_short_string ("Include=ERROR IdCache=ENABLE");
  xpf_arg_stub = box_dv_short_string("");
  xpf_metas = id_str_hash_create (101);
  xpf_reveng = id_hash_allocate (101, sizeof(caddr_t), sizeof(caddr_t), voidptrhash, voidptrhashcmp);
  xp_ext_funcs = id_str_hash_create (101);

  xpf_define_builtin (" undefined"		, xpf_extension			/* ??? */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));

  x2f_define_builtin ("AFTER operator"		, xpf_after_operator		/* Virt 3.0 */	, XPDV_NODESET	, 2	, xpfmalist(2, xpfma("set1",XPDV_NODESET,0), xpfma("set2",XPDV_NODESET,0))	, NULL );
  x2f_define_builtin ("BEFORE operator"		, xpf_before_operator		/* Virt 3.0 */	, XPDV_NODESET	, 2	, xpfmalist(2, xpfma("set1",XPDV_NODESET,0), xpfma("set2",XPDV_NODESET,0))	, NULL );
  x2f_define_builtin ("IDIV operator"		, xpf_idiv_operator		/* Virt 4.0 */	, DV_UNKNOWN	, 2	, xpfmalist(2, xpfma("i1",DV_LONG_INT,0), xpfma("i2",DV_LONG_INT,0))	, NULL );
  x2f_define_builtin ("INSTANCE OF predicate"	, xpf_instance_of_predicate	/* Virt 3.0 */	, XPDV_BOOL	, 0	, xpfmalist(2, xpfma("input",XPDV_NODESET,0), xpfma("seqtype",DV_UNKNOWN,0)), NULL );
  x2f_define_builtin ("ORDER BY operator"	, xpf_order_by_operator		/* Virt 3.0 */	, XPDV_NODESET	, 2	, xpfmalist(3, xpfma("input",XPDV_NODESET,0), xpfma("criterions",DV_UNKNOWN,0), xpfma("flatten-result",DV_LONG_INT,0)), NULL );
  x2f_define_builtin ("SORTBY operator"		, xpf_sortby_operator		/* Virt 3.0 */	, XPDV_NODESET	, 2	, xpfmalist(2, xpfma("input",XPDV_NODESET,0), xpfma("criterions",DV_UNKNOWN,0)), NULL );
  x2f_define_builtin ("TO operator"		, xpf_to_operator		/* Virt 3.0 */	, DV_UNKNOWN	, 2	, xpfmalist(2, xpfma("from",DV_LONG_INT,0), xpfma("to",DV_LONG_INT,0))	, NULL );
  x2f_define_builtin ("TO predicate"		, xpf_to_predicate		/* Virt 3.0 */	, XPDV_NODESET	, 0	, xpfmalist(3, xpfma("input",XPDV_NODESET,0), xpfma("from",DV_LONG_INT,0), xpfma("to",DV_LONG_INT,0))	, NULL );
  x2f_define_builtin ("abs"			, xpf_abs			/* XPath 2.0 */	, DV_NUMERIC	, 1	, xpfmalist(1, xpfma("arg",DV_NUMERIC,0))	, NULL );
  x2f_define_builtin ("and"			, xpf_and			/* XPath 1.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma("arg",XPDV_BOOL,0)));
  x2f_define_builtin ("append"			, xpf_append			/* XPath 1.0 */	, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma("seq",DV_UNKNOWN,0)));
  x2f_define_builtin ("assign"			, xpf_assign			/* Virt 3.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("avg"			, xpf_avg			/* XPath 1.0 */	, DV_NUMERIC	, 0	, NULL	, xpfmalist(1, xpfma("num",DV_NUMERIC,0)));
  x2f_define_builtin ("boolean"			, xpf_boolean			/* XPath 1.0 */	, XPDV_BOOL	, 1	, xpfmalist(1, xpfma("arg",DV_UNKNOWN,0))	, NULL );
  x2f_define_builtin ("ceiling"			, xpf_ceiling			/* XPath 1.0 */	, DV_NUMERIC	, 1	, xpfmalist(1, xpfma("num",DV_NUMERIC,0))	, NULL );
  x2f_define_builtin ("collection"		, NULL				/* Virt 3.5 */	, XPDV_NODESET	, 0	, xpfmalist(7, xpfma("rel_uri",XPDV_NODESET,0), xpfma("base_uri",DV_UNKNOWN,0), xpfma ("recursive", DV_LONG_INT, 0), xpfma("parse_mode",DV_NUMERIC,0), xpfma("encoding",DV_STRING,0), xpfma("language",DV_STRING,0), xpfma("dtd_config",DV_STRING,0) )	, NULL	);
  x2f_define_builtin ("collection-dir-list"	, xpf_collection_dir_list	/* Virt 3.5 */	, XPDV_NODESET	, 0	, xpfmalist(3, xpfma("rel_uri",XPDV_NODESET,0), xpfma("base_uri",DV_UNKNOWN,0), xpfma ("recursive", DV_LONG_INT, 0)), NULL);
  x2f_define_builtin ("concat"			, xpf_concat			/* XPath 1.0 */	, DV_STRING	, 0	, NULL	, xpfmalist(1, xpfma("strg",DV_STRING,0)));
  xpf_define_builtin ("contains"		, xpf_contains			/* XPath 1.0 */	, XPDV_BOOL	, 2	, xpfmalist(2, xpfma("string",DV_STRING,0), xpfma("substring",DV_STRING,0))	, NULL );
  x2f_define_builtin ("count"			, xpf_count			/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("create-attribute"		, xpf_create_attribute		/* Virt 3.0 */	, DV_UNKNOWN	, 1	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("create-comment"		, xpf_create_comment		/* Virt 3.0 */	, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma("content",DV_STRING,0))	, NULL	);
  x2f_define_builtin ("create-element"		, xpf_create_element		/* Virt 3.0 */	, DV_UNKNOWN	, 1	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("create-pi"		, xpf_create_pi			/* Virt 3.0 */	, DV_UNKNOWN	, 1	, xpfmalist(2, xpfma("name",DV_STRING,0), xpfma("content",DV_STRING,0))	, NULL	);
  x2f_define_builtin ("current"			, xpf_current			/* XPath 1.0 */	, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("deass"			, NULL/*xpf_deass*/		/* Virt 3.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("deep-equal"		, xpf_deep_equal		/* XQuery 1.0 */, XPDV_BOOL	, 2	, xpfmalist(3, xpfma(NULL,DV_UNKNOWN,0), xpfma(NULL,DV_UNKNOWN,0), xpfma(NULL,DV_STRING,0)), NULL);
  x2f_define_builtin ("distinct"		, xpf_distinct			/* XPath 1.0 */	, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  xpf_define_builtin ("distinct-values"		, xpf_distinct_values		/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("doc"			, xpf_doc			/* XPath 1.0 */	, XPDV_NODESET	, 0	, xpfmalist(1, xpfma("uri",DV_STRING,0)), NULL);
  x2f_define_builtin ("document"		, xpf_document			/* XPath 1.0 */	, XPDV_NODESET	, 1	, xpfmalist(6, xpfma("rel_uri",XPDV_NODESET,0), xpfma("base_uri",DV_UNKNOWN,0), xpfma("parse_mode",DV_NUMERIC,0), xpfma("encoding",DV_STRING,0), xpfma("language",DV_STRING,0), xpfma("dtd_config",DV_STRING,0) )	, NULL	);
  x2f_define_builtin ("document-lazy"		, xpf_document_lazy		/* Virt 6.0 */	, XPDV_NODESET	, 1	, xpfmalist(6, xpfma("rel_uri",XPDV_NODESET,0), xpfma("base_uri",DV_UNKNOWN,0), xpfma("parse_mode",DV_NUMERIC,0), xpfma("encoding",DV_STRING,0), xpfma("language",DV_STRING,0), xpfma("dtd_config",DV_STRING,0) )	, NULL	);
  x2f_define_builtin ("document-lazy-in-coll"	, xpf_document_lazy_in_coll	/* Virt 6.0 */	, XPDV_NODESET	, 1	, xpfmalist(6, xpfma("rel_uri",XPDV_NODESET,0), xpfma("base_uri",DV_UNKNOWN,0), xpfma("parse_mode",DV_NUMERIC,0), xpfma("encoding",DV_STRING,0), xpfma("language",DV_STRING,0), xpfma("dtd_config",DV_STRING,0) )	, NULL	);
  x2f_define_builtin ("document-get-uri"		, xpf_document_get_uri		/* Virt 3.0 */	, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma("ent",DV_XML_ENTITY,0))	, NULL	);
  x2f_define_builtin ("document-literal"		, xpf_document_literal		/* XPath 1.0 */	, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  xpf_define_alias   ("document-uri", NULL, "document-get-uri", NULL);
  x2f_define_builtin ("empty"			, xpf_empty			/* XPath 1.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  xpf_define_builtin ("ends-with"		, xpf_ends_with			/* XPath 1.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("every"			, xpf_every			/* Virt 3.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("except"			, xpf_except			/* XQuery 2.0 */, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("exists"			, xpf_exists			/* XQuery 2.0 */, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("expand-qname"		, xpf_expand_qname		/* Virt 3.5 */	, DV_STRING	, 1	, xpfmalist(3, xpfma("use_default",XPDV_BOOL,0), xpfma("qname",DV_STRING,0), xpfma("context",DV_XML_ENTITY,0))	, NULL	);
  xpf_define_builtin ("false"			, xpf_false			/* XPath 1.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("filter"			, xpf_filter			/* XQ 1.0 */	, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("floor"			, xpf_floor			/* XPath 1.0 */	, DV_NUMERIC	, 1	, xpfmalist(1, xpfma("num",DV_UNKNOWN,0))	, NULL	);
  x2f_define_builtin ("for"			, xpf_for			/* Virt 3.0 */	, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("format-number"		, xpf_format_number		/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("function-available"	, xpf_function_available	/* XPath 1.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("generate-id"		, xpf_generate_id		/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("id"			, xpf_id			/* XPath 1.0 */	, XPDV_NODESET	, 1	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0))	, NULL	);
  x2f_define_builtin ("if"			, xpf_if			/* Virt 3.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("is-after"			, xpf_is_after			/* Virt 3.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("is-before"		, xpf_is_before			/* Virt 3.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("is-descendant"		, xpf_is_descendant		/* Virt 3.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("is-same"			, xpf_is_same			/* Virt 3.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("intersect"		, xpf_intersect			/* XQuery 2.0 */, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("iterate-rev"		, xpf_iterate_rev		/* XPath 1.0 */	, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("iterate"			, xpf_iterate			/* XPath 1.0 */	, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("key"			, xpf_key			/* XPath 1.0 */	, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("lang"			, xpf_lang			/* XPath 1.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("last"			, xpf_last			/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("let"			, xpf_let			/* Virt 3.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("list"			, xpf_list			/* Virt 3.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("local-name"		, xpf_local_name		/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("map"			, xpf_map			/* Virt 3.0 */	, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("max"			, xpf_max			/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("min"			, xpf_min			/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("name"			, xpf_name			/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("namespace-uri"		, xpf_namespace_uri		/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("normalize-space"		, xpf_normalize_space		/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("not"			, xpf_not			/* XPath 1.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("number"			, xpf_number			/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("or"			, xpf_or			/* XPath 1.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("position"		, xpf_position			/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("progn"			, xpf_progn			/* Virt 3.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("processXQuery"		, xpf_processXQuery		/* BPEL */	, XPDV_NODESET	, 1	, xpfmalist(3, xpfma("module_uri",DV_STRING,0), xpfma("source",DV_XML_ENTITY,0), xpfma("nth_result",DV_LONG_INT,0))	, xpfmalist(2, xpfma("param_name",DV_STRING,0), xpfma("param_value",DV_UNKNOWN,0)));
  x2f_define_builtin ("processXSLT"		, xpf_processXSLT		/* BPEL */	, XPDV_NODESET	, 1	, xpfmalist(2, xpfma("stylesheet_uri",DV_STRING,0), xpfma("source",DV_XML_ENTITY,0))	, xpfmalist(2, xpfma("param_name",DV_STRING,0), xpfma("param_value",DV_UNKNOWN,0)));
  xpf_define_builtin ("replace"			, xpf_replace			/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("resolve-uri"		, xpf_resolve_uri		/* Virt 3.5 */	, DV_STRING	, 2	, xpfmalist(2, xpfma("base_uri",DV_STRING,0), xpfma("relative_uri",DV_STRING,0))	, NULL);
  x2f_define_builtin ("round-half-to-even"	, xpf_round_half_to_even	/* XPath 2.0 */	, DV_NUMERIC	, 1	, xpfmalist(1, xpfma("num",DV_UNKNOWN,0))	, NULL	);
  x2f_define_builtin ("round-number"		, xpf_round_number		/* XPath 1.0 */	, DV_NUMERIC	, 1	, xpfmalist(1, xpfma("num",DV_UNKNOWN,0))	, NULL	);
  xpf_define_alias   ("round" , NULL, "round-number", NULL);
  x2f_define_builtin ("sql-column-select"	, xpf_sql_column_select		/* Virt 6.2 */	, XPDV_NODESET	, 1	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("sql-scalar-select"	, xpf_sql_scalar_select		/* Virt 6.2 */	, DV_UNKNOWN	, 1	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("serialize"		, xpf_serialize			/* Virt 3.0 */	, DV_STRING	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("shallow"			, xpf_shallow			/* XQuery 1.0 */ , XPDV_NODESET , 1	, xpfmalist(1, xpfma(NULL,DV_XML_ENTITY,0))	, NULL);
  x2f_define_builtin ("some"			, xpf_some			/* Virt 3.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("sql-equ"			, xpf_sql_equ			/* Virt 4.0 */	, XPDV_BOOL	, 2	, xpfmalist(2, xpfma("val1",DV_UNKNOWN,0), xpfma("val2",DV_UNKNOWN,0)),	 NULL);
  x2f_define_builtin ("sql-ge"			, xpf_sql_ge			/* Virt 4.0 */	, XPDV_BOOL	, 2	, xpfmalist(2, xpfma("val1",DV_UNKNOWN,0), xpfma("val2",DV_UNKNOWN,0)),	 NULL);
  x2f_define_builtin ("sql-gt"			, xpf_sql_gt			/* Virt 4.0 */	, XPDV_BOOL	, 2	, xpfmalist(2, xpfma("val1",DV_UNKNOWN,0), xpfma("val2",DV_UNKNOWN,0)),	 NULL);
  x2f_define_builtin ("sql-le"			, xpf_sql_le			/* Virt 4.0 */	, XPDV_BOOL	, 2	, xpfmalist(2, xpfma("val1",DV_UNKNOWN,0), xpfma("val2",DV_UNKNOWN,0)),	 NULL);
  x2f_define_builtin ("sql-lt"			, xpf_sql_lt			/* Virt 4.0 */	, XPDV_BOOL	, 2	, xpfmalist(2, xpfma("val1",DV_UNKNOWN,0), xpfma("val2",DV_UNKNOWN,0)),	 NULL);
  x2f_define_builtin ("sql-neq"			, xpf_sql_neq			/* Virt 4.0 */	, XPDV_BOOL	, 2	, xpfmalist(2, xpfma("val1",DV_UNKNOWN,0), xpfma("val2",DV_UNKNOWN,0)),	 NULL);
  xpf_define_builtin ("starts-with"		, xpf_starts_with		/* XPath 1.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  xpf_define_builtin ("string-length"		, xpf_string_length		/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  xpf_define_builtin ("string"			, xpf_string			/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  xpf_define_builtin ("substring"		, xpf_substring			/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  xpf_define_builtin ("substring-after"		, xpf_substring_after		/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  xpf_define_builtin ("substring-before"	, xpf_substring_before		/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("sum"			, xpf_sum			/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("system-property"		, xpf_system_property		/* XXLT 1.0 */	, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma("property_qname",DV_STRING,0))	, NULL);
  x2f_define_builtin ("text-contains"		, xpf_text_contains		/* Virt 2.5 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  xpf_define_builtin ("translate"		, xpf_translate			/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  xpf_define_builtin ("true"			, xpf_true			/* XPath 1.0 */	, XPDV_BOOL	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("tuple"			, xpf_tuple			/* Virt 3.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("union"			, xpf_union			/* Virt 3.0 */	, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("unordered"		, xpf_unordered			/* XQ 1.0 */	, XPDV_NODESET	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("unparsed-entity-uri"	, xpf_unparsed_entity_uri	/* XPath 1.0 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("urlify"			, xpf_urlify			/* Virt 2.5 */	, DV_UNKNOWN	, 1	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0))	, NULL);
  x2f_define_builtin ("vector"			, xpf_vector			/* Virt 3.5 */	, DV_UNKNOWN	, 0	, NULL	, xpfmalist(1, xpfma("item",DV_UNKNOWN,0)));
  x2f_define_builtin ("vector for ORDER BY"	, xpf_vector_for_order_by	/* Virt 3.5 */	, DV_UNKNOWN	, 2	, xpfmalist(1, xpfma("item",DV_UNKNOWN,0))	, xpfmalist(1, xpfma("key",DV_UNKNOWN,0)));
  x2f_define_builtin ("xmlview"			, xpf_xmlview			/* XQuery  */	, XPDV_NODESET	, 1	, NULL	, xpfmalist(1, xpfma(NULL,DV_UNKNOWN,0)));
  x2f_define_builtin ("xpath-debug-srcline"	, xpf_xpath_debug_srcline	/* Virt 3.0 */	, DV_STRING	, 1	, xpfmalist(1, xpfma(NULL,DV_XML_ENTITY,0))	, NULL);
  x2f_define_builtin ("xpath-debug-srcfile"	, xpf_xpath_debug_srcfile	/* Virt 3.0 */	, DV_STRING	, 1	, xpfmalist(1, xpfma(NULL,DV_XML_ENTITY,0))	, NULL);
  x2f_define_builtin ("xpath-debug-xslline"	, xpf_xpath_debug_xslline	/* Virt 3.0 */	, DV_STRING	, 0	, NULL	, NULL);
  x2f_define_builtin ("xpath-debug-xslfile"	, xpf_xpath_debug_xslfile	/* Virt 3.0 */	, DV_STRING	, 0	, NULL	, NULL);
  bif_define ("xpf_extension", bif_xpf_extension);
  bif_define ("xpf_extension_remove", bif_xpf_extension_remove);

  xqf_init();

  ddl_ensure_table ("DB.DBA.SYS_XPF_EXTENSIONS", xpf_extensions_tb);

  /* These fake definitions should be placed after all plain definitions */
#define XPF_ADD_REVENG(name,fn) \
  do { \
    caddr_t n = box_dv_short_string((name)); \
    xp_func_t f = (fn); \
    id_hash_set (xpf_reveng, (caddr_t)(&f), (caddr_t)(&n)); \
    } while (0)

  XPF_ADD_REVENG("XPath-to-SQL bridge"			, xpf_extension);
  XPF_ADD_REVENG("XQuery Cartesian product processor"	, xpf_cartesian_product_loop);
  XPF_ADD_REVENG("XQuery UDF processor"			, xpf_call_udf);
}
