/*
 *  xmltree.c
 *
 *  $Id$
 *
 *  XPATH interpreter
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
#include "lisprdr.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "xml.h"
#include "xmlgen.h"

#include "xmltree.h"
#include "xpf.h"
#include "arith.h"
#include "sqlbif.h"
#include "math.h"
#include "text.h"
#include "bif_xper.h"
#include "security.h"
#include "srvmultibyte.h"
#include "xml_ecm.h"
#include "http.h"
#include "sqltype.h" /* for XMLTYPE_TO_ENTITY */
#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser_impl.h"
#ifdef __cplusplus
}
#endif
#include "xpathp_impl.h"
#include "xpathp.h"
#include "date.h" /* for DT_DT_TYPE */
#include "rdf_core.h" /* for rdf_type_twobyte_to_iri */
#include "uname_const_decl.h"

#define REF_REL_URI(xte,head) \
 ((BOX_ELEMENTS (head) > 4) ? \
  head[4] : \
  xe_get_sysid ((xml_entity_t *)(xte), head[2]) )

struct xe_class_s xec_tree_xe;

static void xte_destroy (xml_entity_t * xe);
char * xte_output_method (xml_tree_ent_t * xte);
int xte_ent_name_test (xml_entity_t * xe, XT * node);
int xte_string_value_of_tree_is_nonempty (caddr_t *current);

dk_mutex_t * xqr_mtx;

#ifdef XPATH_DEBUG
ptrlong xqi_set_debug_start = 0;
#ifdef MALLOC_DEBUG
/* You may set it to zero (check all slot operations) or to -1 (do not spend time for checks) */
ptrlong xqi_set_odometer = -1;
#else
/* Do not change this line, you will slow down the testing for nothing */
ptrlong xqi_set_odometer = -1;
#endif
#endif

#ifdef MALLOC_DEBUG
#define XP_EVAL_CACHE_SIZE 1
#else
#ifndef NDEBUG
#define XP_EVAL_CACHE_SIZE 13
#else
#define XP_EVAL_CACHE_SIZE 1021
#endif
#endif

#ifdef XPATH_DEBUG
void
xqi_check_slots (xp_instance_t * xqi)
{
  int inx;
  int inx2;
  ptrlong * map = (ptrlong *) ((ptrlong) xqi + xqi->xqi_slot_map_offset);
  for (inx = 0; inx < xqi->xqi_n_slots; inx++)
    {
      caddr_t val = XQI_GET (xqi, map[inx]);
      if (IS_BOX_POINTER(val))
	{
	  for (inx2 = inx+1; inx2 < xqi->xqi_n_slots; inx2++)
	    {
	      if (XQI_GET (xqi, map[inx2]) == val)
		GPF_T;
	    }
	}
    }
}
#else
#define xqi_check_slots(xqi)
#endif


#ifdef XTREE_DEBUG

void
xte_tree_check_iter (box_t box, box_t parent, dk_hash_t *known)
{
  dtp_t tag;
  if (!IS_BOX_POINTER (box))
    GPF_T1 ("XML Tree contains a non box pointer");
  dk_alloc_box_assert (box);
  tag = box_tag (box);
  if (DV_UNAME != tag)
    {
      if (gethash (box, known))
	GPF_T1 ("Diamond at XML Tree");
      sethash (box, known, parent);
    }
  switch (tag)
    {
    case DV_ARRAY_OF_POINTER:
    {
      caddr_t *head, *obj = (caddr_t *) box;
      uint32 head_len, idx, count = box_length (box);
      if (count % sizeof (box_t))
        GPF_T1 ("Inaccurate box length in XML Tree");
      count /= sizeof (box_t);
      if (0 == count)
        GPF_T1 ("XML Tree does not contain a head");
      head = ((caddr_t **)(box))[0];
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (head))
        {
	  if (TAG_FREE == DV_TYPE_OF (head))
	    GPF_T1 ("XML Tree contains a pointer to a freed box");
	  GPF_T1 ("XML Tree contains a head that is not an DV_ARRAY_OF_POINTER");
	}
      if (gethash (head, known))
	GPF_T1 ("Diamond at XML Tree head");
      sethash (head, known, parent);
      head_len = box_length (head);
      if (head_len % sizeof (box_t))
        GPF_T1 ("Inaccurate box length of head in XML Tree");
      head_len /= sizeof (box_t);
      if (0 == head_len)
        GPF_T1 ("XML Tree contains an empty head");
      if (0 == (head_len % 2))
        GPF_T1 ("XML Tree contains a head of wrong length");
      for (idx = 0; idx < head_len; idx++)
        {
          caddr_t strg = head[idx];
	  uint32 len;
	  dtp_t strg_type = DV_TYPE_OF (strg);
	  dtp_t expected_type = (idx && !(idx % 2)) ? DV_STRING : DV_UNAME;
	  if (expected_type != strg_type)
	    {
	      if (TAG_FREE == strg_type)
		GPF_T1 ("XML Tree head contains a pointer to a freed box");
	      if ((DV_STRING == expected_type) &&
	        ((DV_XPATH_QUERY == strg_type) || (DV_UNAME == strg_type) || (' ' == head[idx-1][0])) )
	        {
	          dk_check_tree_iter (strg, parent, known);
	          continue;
	        }
	      GPF_T1 ("XML Tree head contains an item of wrong type");
	    }
	  if (DV_UNAME != strg_type)
	    {
	      if (gethash (strg, known))
		GPF_T1 ("Diamond at XML Tree head string");
	      sethash (strg, known, parent);
	    }
	  len = box_length (strg);
	  if (2 > len)
	    {
	      if ((1 > len) || (DV_UNAME == expected_type))
	        GPF_T1 ("Abnormally short string in head of XML Tree");
	    }
	  if ('\0' != strg[len-1])
	    GPF_T1 ("A string in head of XML Tree is not zero-terminated");
        }
      if (uname__pi == head[0])
	{
	  uint32 len;
	  if (2 < BOX_ELEMENTS(obj))
	    GPF_T1 ("pi has too many children");
	  if (2 > BOX_ELEMENTS(obj))
	    break;
	  if (DV_STRING != DV_TYPE_OF (obj[1]))
	    GPF_T1 ("pi data must be DV_STRING");
	  len = box_length (obj[1]);
	  if (1 > len)
	    GPF_T1 ("Abnormally short string in XML Tree");
	  if ('\0' != (obj[1])[len-1])
	    GPF_T1 ("A string in XML Tree is not zero-terminated");
	  break;
	}
      while (--count /* not 'count--' */)
	xte_tree_check_iter ((++obj)[0], parent, known);
      break;
    }
    case DV_STRING:
      {
        uint32 len = box_length (box);
      if (2 > len)
        GPF_T1 ("Abnormally short string in XML Tree");
      if ('\0' != ((char *)box)[len-1])
        GPF_T1 ("A string in XML Tree is not zero-terminated");
      break;
      }
    case DV_UNAME:
      GPF_T1 ("XML Tree contains a DV_UNAME");
    case TAG_FREE:
      GPF_T1 ("Tree contains a pointer to a freed box");
    default:
      GPF_T1 ("A child in XML Tree is neither subtree nor text");
    }
}


void
xte_tree_check (box_t box)
{
  dk_hash_t *known = hash_table_allocate (4096);
  xte_tree_check_iter (box, box, known);
  hash_table_free (known);
}
#endif

#if 0
caddr_t
xqi_set (xp_instance_t * xqi, int n, caddr_t v)
{
  caddr_t *cell = ((caddr_t*) xqi)+n;
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= 0)
    xqi_set_odometer++;
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (cell[0]);
#endif
#if DEBUG
  if (IS_BOX_POINTER (v) && (v == cell[0]))
    GPF_T1 ("Self-assignment in xq_set()");
#endif
  dk_free_tree (cell[0]);
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (v);
#endif
  cell[0] = v;
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    xqi_check_slots (xqi);
#endif
  return v;
}
#endif


void
xp_res_slot (xp_instance_t * xqi, state_slot_t * ssl,  caddr_t * res)
{
  unsigned ptrlong distance;
  memset (ssl, 0, sizeof (state_slot_t));
  ssl->ssl_type = SSL_VARIABLE;
  distance = ((ptrlong) res - (ptrlong) xqi) / sizeof (caddr_t);
  if (distance > 0xffff)
    GPF_T1 ("distance of res slot in xpath arithmetic would be over 64K");
  ssl->ssl_index = (unsigned short)distance;
  /* distance between xqi and slot in xqi, the xqi is passed instead of the qi to vox_add* */
}


sql_tree_tmp * st_integer;


caddr_t
xqi_cast_via_bool (xp_instance_t * xqi, int slot, dtp_t dtp)
{
  caddr_t val = XQI_GET (xqi, slot);
#ifdef DEBUG
  if (DV_LONG_INT != DV_TYPE_OF (val))
    GPF_T;
#endif
  switch (dtp)
    {
    case DV_UNKNOWN:
      return (val);
    case DV_NUMERIC: case DV_LONG_INT:
      val = box_num_nonull (unbox(val) ? 1 : 0);
      XQI_SET (xqi, slot, val);
      return val;
    case DV_LONG_STRING:
      val = box_dv_short_nchars ((unbox(val) ? "1" : "0"), 1);
      XQI_SET (xqi, slot, val);
      return val;
    case DV_LONG_WIDE: case DV_WIDE:
      val = box_wide_string (unbox(val) ? L"1" : L"0");
      XQI_SET (xqi, slot, val);
      return val;
    }
  GPF_T1 ("Bad target type in xqi_cast_via_bool");
  return NULL;
}


caddr_t
xqi_cast (xp_instance_t * xqi, int slot, dtp_t dtp)
{
  caddr_t val = XQI_GET (xqi, slot);
  dtp_t val_dtp;
  if (DV_UNKNOWN == dtp)
    return (val);
  val_dtp = DV_TYPE_OF (val);
  if (val_dtp == dtp)
    return val;
  if (DV_NUMERIC == dtp)
    {
      if (IS_NUM_DTP (val_dtp))
	return val;
      XQI_SET (xqi, slot, xp_box_number (val));
      return (XQI_GET (xqi, slot));
    }
  if (is_string_type (dtp))
    {
      /* No need: this is checked above, because now there's only one string dtp:
      if (is_string_type (val_dtp))
	return val; */
      if (DV_ARRAY_OF_POINTER == val_dtp
	  && DV_ARRAY_OF_POINTER == DV_TYPE_OF (XTE_HEAD (val)))
	xte_string_value_from_tree ((caddr_t*) val, XQI_ADDRESS (xqi, slot), DV_LONG_STRING);
      else if (DV_XML_ENTITY == val_dtp)
	xe_string_value_1 ((xml_entity_t *)val, XQI_ADDRESS (xqi, slot), DV_LONG_STRING);
      else if (DV_NUMERIC == val_dtp)
	{
	  numeric_t nval = (numeric_t) val;
	  char tmp[NUMERIC_MAX_STRING_BYTES + 500];
	  int res = numeric_to_string (nval, tmp, sizeof (tmp));

	  if (res == NUMERIC_STS_OVERFLOW)
	    XQI_SET (xqi, slot, box_dv_short_string (numeric_sign (nval) ? "-Infinity" : "Infinity"));
	  else
	    XQI_SET (xqi, slot, box_dv_short_string (tmp));
	}
      else
	XQI_SET (xqi, slot, box_cast ((caddr_t *) xqi->xqi_qi, val, st_varchar, val_dtp));
      return (XQI_GET (xqi, slot));
    }
  if (DV_LONG_INT == dtp)
    {
      caddr_t val2;
      /* No need: this is checked above:
      if (DV_LONG_INT == val_dtp)
	return val; */
      if (DV_ARRAY_OF_POINTER == val_dtp
	  && DV_ARRAY_OF_POINTER == DV_TYPE_OF (XTE_HEAD (val)))
	xte_string_value_from_tree ((caddr_t*) val, XQI_ADDRESS (xqi, slot), DV_LONG_STRING);
      else if (DV_XML_ENTITY == val_dtp)
	xe_string_value_1 ((xml_entity_t *)val, XQI_ADDRESS (xqi, slot), DV_LONG_STRING);
      val2 = XQI_GET (xqi, slot);
      /* !!!TBD cast DV_DATETIME to xsd:dateTime syntax etc. */
      XQI_SET (xqi, slot, box_cast ((caddr_t *) xqi->xqi_qi, val2, st_integer, DV_TYPE_OF(val2)));
      return (XQI_GET (xqi, slot));
    }
  if (DV_UNAME == dtp)
    {
      if (is_string_type (val_dtp))
        {
	  val = box_dv_uname_string (val);
	  XQI_SET (xqi, slot, val);
	  return val;
	}
      sqlr_new_error ("42000", "XI026", "Cannot convert non-string value to an 'variable name' object.");
    }
  if ((DV_WIDE == dtp) || (DV_LONG_WIDE == dtp))
    {
      /* There's a need, combinations like DV_WIDE dtp and DV_LONG_WIDE val_dtp are possible but not checked before */
      if ((DV_WIDE == val_dtp) || (DV_LONG_WIDE == val_dtp))
	return val;
      if (DV_ARRAY_OF_POINTER == val_dtp
	  && DV_ARRAY_OF_POINTER == DV_TYPE_OF (XTE_HEAD (val)))
	{
	  xte_string_value_from_tree ((caddr_t*) val, XQI_ADDRESS (xqi, slot), DV_LONG_STRING);
	  val = XQI_GET (xqi, slot);
	  XQI_SET (xqi, slot, box_utf8_as_wide_char (val, NULL, strlen (val), 0, dtp));
	}
      else if (DV_XML_ENTITY == val_dtp)
	{
	  xe_string_value_1 ((xml_entity_t *)val, XQI_ADDRESS (xqi, slot), DV_LONG_STRING);
	  val = XQI_GET (xqi, slot);
	  XQI_SET (xqi, slot, box_utf8_as_wide_char (val, NULL, strlen (val), 0, dtp));
	}
      else if (DV_NUMERIC == val_dtp)
	{
	  numeric_t nval = (numeric_t) val;
	  char tmp[NUMERIC_MAX_STRING_BYTES + 500];
	  int res = numeric_to_string (nval, tmp, sizeof (tmp));

	  if (res == NUMERIC_STS_OVERFLOW)
	    XQI_SET (xqi, slot, box_wide_string (numeric_sign (nval) ? L"-Infinity" : L"Infinity"));
	  else
	    XQI_SET (xqi, slot, box_narrow_string_as_wide ((unsigned char *) tmp, NULL, -1, NULL, NULL, 0));
	}
      else
	XQI_SET (xqi, slot, box_utf8_as_wide_char (val, NULL, strlen (val), 0, dtp));
      return (XQI_GET (xqi, slot));
    }
  GPF_T1 ("Bad target type in xqi_cast");
  return NULL;
}


caddr_t
xqi_value (xp_instance_t * xqi, XT * tree, dtp_t target_dtp)
{
  int state;
  dtp_t dtp = DV_TYPE_OF (tree);
  if (DV_SYMBOL == dtp)
    {
      return NULL;
    }
  if (DV_ARRAY_OF_POINTER != dtp)
    return ((caddr_t) tree);
  switch (tree->type)
    {
    case XP_LITERAL:
      {
	caddr_t val = tree->_.literal.val;
	caddr_t res;
	dtp_t val_dtp = DV_TYPE_OF (val);
	switch (target_dtp)
	  {
	  case DV_NUMERIC:
	    if (IS_NUM_DTP (val_dtp))
	      return val;
	    break;
	  case DV_LONG_INT:
	    if (val && DV_LONG_INT == val_dtp)
	      return val;
	    /* not a default case because 0 is DV_LONG_INT :) */
	    XQI_SET (xqi, tree->_.literal.res, box_copy_tree(val));
	    return xqi_cast (xqi, (int) tree->_.literal.res, target_dtp);
	  case DV_STRING:
	    if (is_string_type (val_dtp))
	      return val;
	    break;
	  case DV_UNAME:
	    if (DV_UNAME == val_dtp)
	      return val;
	    if (is_string_type (val_dtp))
	      {
		res = XQI_GET (xqi, tree->_.literal.res);
		if (NULL == res)
		  {
		    res = box_dv_uname_string (val);
		    XQI_SET (xqi, tree->_.literal.res, res);
		  }
	        return res;
	      }
	    sqlr_new_error ("42000", "XI025", "Non-string literal used as 'variable name' argument of XQUERY function.");
	    return NULL;
	  case DV_UNKNOWN:
	    return val;
	  }
	res = XQI_GET (xqi, tree->_.literal.res);
	if (DV_TYPE_OF (res) == target_dtp)
	  return res;
	XQI_SET (xqi, tree->_.literal.res, box_copy_tree(val));
	return xqi_cast (xqi, (int) tree->_.literal.res, target_dtp);
      }
    case XP_VARIABLE:
    case XP_FAKE_VAR:
      state = (int) XQI_GET_INT (xqi, tree->_.var.state);
      if (state == XI_AT_END)
	return NULL;
      if (XI_INITIAL == state)
	{
	  xqi_next (xqi, tree);
	  state = (int) XQI_GET_INT (xqi, tree->_.var.state);
	}
      if (XI_RESULT == state)
	return (xqi_cast (xqi, (int) tree->_.var.res, target_dtp));
      else
	return NULL;

    case BOP_EQ: case BOP_NEQ:
    case BOP_LTE: case BOP_LT: case BOP_GTE: case BOP_GT:
    case BOP_LIKE:
    case BOP_SAME: case BOP_NSAME:
    case BOP_AND: case BOP_OR: case BOP_NOT:
      return xqi_cast_via_bool (xqi, (int) tree->_.bin_exp.res, target_dtp);

    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
      return (xqi_cast (xqi, (int) tree->_.bin_exp.res, target_dtp));

    case XP_STEP:
      {
	state = (int) XQI_GET_INT (xqi, tree->_.step.state);
	if (XI_INITIAL == state)
	  {
	    xqi_next (xqi, tree);
	    state = (int) XQI_GET_INT (xqi, tree->_.step.state);
	  }
	if (XI_RESULT == state)
	  {
	    XQI_SET (xqi, tree->_.step.cast_res, box_copy_tree (XQI_GET (xqi, tree->_.step.iterator)));
	    return (xqi_cast (xqi, (int) tree->_.step.cast_res, target_dtp));
	  }
	if (XI_AT_END == state)
	  return NULL;
      }
    case XP_UNION:
      {
	int state = (int) XQI_GET_INT (xqi, tree->_.xp_union.state);
	if (XI_INITIAL == state)
	  {
	    xqi_next (xqi, tree);
	    state = (int) XQI_GET_INT (xqi, tree->_.xp_union.state);
	  }
	if (XI_RESULT == state)
	  return (xqi_cast (xqi, (int) tree->_.xp_union.res, target_dtp));
	if (XI_AT_END == state)
	  return NULL;
      }
    case CALL_STMT:
      if (XPDV_BOOL == xt_predict_returned_type (tree))
	return xqi_cast_via_bool (xqi, (int) tree->_.xp_func.res, target_dtp);
      else if (tree->_.xp_func.var)
	return (xqi_value (xqi, tree->_.xp_func.var, target_dtp));
      else
	return (xqi_cast (xqi, (int) tree->_.xp_func.res, target_dtp));
    case XP_FILTER:
      {
	state = (int) XQI_GET_INT (xqi, tree->_.filter.state);
	if (XI_INITIAL == state)
	  {
	    xqi_next (xqi, tree);
	    state = (int) XQI_GET_INT (xqi, tree->_.filter.state);
	  }
	if (XI_AT_END == state)
	  return NULL;
	return (xqi_value (xqi, tree->_.filter.path, target_dtp));
      }
/* this was:
      if (XI_INITIAL == state)
	xqi_next (xqi, tree);
      return (xqi_value (xqi, tree->_.filter.path, target_dtp));
*/
    case XQ_QUERY_MODULE:
      return (xqi_value (xqi, tree->_.module.body, target_dtp));
    case XQ_FOR_SQL:
      {
        state = (int) XQI_GET_INT (xqi, tree->_.xq_for_sql.lc_state);
        if (state == XI_AT_END)
	  return NULL;
        if (XI_INITIAL == state)
	  {
	    xqi_next (xqi, tree);
	    state = (int) XQI_GET_INT (xqi, tree->_.xq_for_sql.lc_state);
	  }
        if (XI_RESULT == state)
	  return (xqi_cast (xqi, (int) tree->_.xq_for_sql.current, target_dtp));
        else
	  return NULL;
      }
    }
  GPF_T; return NULL;
}


caddr_t
xqi_raw_value (xp_instance_t * xqi, XT * tree)
{
  int state;
  dtp_t dtp = DV_TYPE_OF (tree);
  if (DV_SYMBOL == dtp)
    {
      return NULL;
    }
  if (DV_ARRAY_OF_POINTER != dtp)
    return ((caddr_t) tree);
  switch (tree->type)
    {
    case XP_LITERAL:
	return tree->_.literal.val;
    case XP_VARIABLE:
    case XP_FAKE_VAR:
      state = (int) XQI_GET_INT (xqi, tree->_.var.state);
      if (state == XI_AT_END)
	return NULL;
      if (XI_INITIAL == state)
	{
	  xqi_next (xqi, tree);
	  state = (int) XQI_GET_INT (xqi, tree->_.var.state);
	}
      if (XI_RESULT == state)
	return XQI_GET (xqi, tree->_.var.res);
      else
	return NULL;

    case BOP_EQ: case BOP_NEQ:
    case BOP_LTE: case BOP_LT: case BOP_GTE: case BOP_GT:
    case BOP_LIKE:
    case BOP_SAME: case BOP_NSAME:
    case BOP_AND: case BOP_OR: case BOP_NOT:
    case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
    return XQI_GET (xqi, tree->_.bin_exp.res);

    case XP_STEP:
      {
	state = (int) XQI_GET_INT (xqi, tree->_.step.state);
	if (XI_INITIAL == state)
	  {
	    xqi_next (xqi, tree);
	    state = (int) XQI_GET_INT (xqi, tree->_.step.state);
	  }
	if (XI_RESULT == state)
	  {
	    return XQI_GET (xqi, tree->_.step.iterator);
	  }
	if (XI_AT_END == state)
	  return NULL;
      }
    case XP_UNION:
      {
	int state = (int) XQI_GET_INT (xqi, tree->_.xp_union.state);
	if (XI_INITIAL == state)
	  {
	    xqi_next (xqi, tree);
	    state = (int) XQI_GET_INT (xqi, tree->_.xp_union.state);
	  }
	if (XI_RESULT == state)
	  return XQI_GET (xqi, tree->_.xp_union.res);
	if (XI_AT_END == state)
	  return NULL;
      }
    case CALL_STMT:
      if (XPDV_BOOL == xt_predict_returned_type (tree))
	return XQI_GET (xqi, tree->_.xp_func.res);
      else if (tree->_.xp_func.var)
	return xqi_raw_value (xqi, tree->_.xp_func.var);
      else
	return XQI_GET (xqi, tree->_.xp_func.res);
    case XP_FILTER:
      {
	state = (int) XQI_GET_INT (xqi, tree->_.filter.state);
	if (XI_INITIAL == state)
	  {
	    xqi_next (xqi, tree);
	    state = (int) XQI_GET_INT (xqi, tree->_.filter.state);
	  }
	if (XI_AT_END == state)
	  return NULL;
	return xqi_raw_value (xqi, tree->_.filter.path);
      }
/* this was:
      if (XI_INITIAL == state)
	xqi_next (xqi, tree);
      return (xqi_value (xqi, tree->_.filter.path, target_dtp));
*/
    case XQ_QUERY_MODULE:
      return (xqi_raw_value (xqi, tree->_.module.body));
    case XQ_FOR_SQL:
      {
        state = (int) XQI_GET_INT (xqi, tree->_.xq_for_sql.lc_state);
        if (state == XI_AT_END)
	  return NULL;
        if (XI_INITIAL == state)
	  {
	    xqi_next (xqi, tree);
	    state = (int) XQI_GET_INT (xqi, tree->_.xq_for_sql.lc_state);
	  }
        if (XI_RESULT == state)
	  return XQI_GET (xqi, tree->_.xq_for_sql.current);
        else
	  return NULL;
      }
    }
  GPF_T; return NULL;
}

int
xqi_truth_value_of_box (caddr_t val)
{
  switch (DV_TYPE_OF (val))
    {
    case DV_STRING: case DV_UNAME: return (1 < box_length (val));
    case DV_WIDE: return (sizeof (wchar_t) < box_length (val));
    case DV_LONG_INT: return unbox (val);
    case DV_DOUBLE_FLOAT: return (0 != unbox_double (val));
    case DV_SINGLE_FLOAT: return (0 != unbox_float (val));
    case DV_NUMERIC: return !num_is_zero ((numeric_t)val);
    case DV_XML_ENTITY:
      {
        xml_entity_t *xe = (xml_entity_t *)val;
        return xe->_->xe_string_value_is_nonempty (xe);
      }
    case DV_ARRAY_OF_XQVAL:
      if (0 == box_length (val))
        return 0;
      return xqi_truth_value_of_box (((caddr_t *)val)[0]);
    case DV_ARRAY_OF_POINTER:
      return xte_string_value_of_tree_is_nonempty ((caddr_t *)val);
    default: return 1;
    }
}


int
xqi_truth_value (xp_instance_t * xqi, XT * tree)
{
  caddr_t val;
  int predicted = xt_predict_returned_type (tree);
  switch (predicted)
    {
    case XPDV_BOOL:
      val = xqi_raw_value (xqi, tree);
      if (NULL == val)
	return 0;
      switch (DV_TYPE_OF (val))
	{
	  case DV_LONG_INT:
	    return (0 != unbox (val));
	  case DV_ARRAY_OF_XQVAL:
	    return BOX_ELEMENTS (val) > 0;
	  default: ;
	}
      return 1;
    case XPDV_NODESET:
      val = xqi_raw_value (xqi, tree);
      return (NULL != val);
    default:
#if 1
      val = xqi_raw_value (xqi, tree);
      return xqi_truth_value_of_box (val);
#else
      val = xqi_value (xqi, tree, DV_SHORT_STRING);
      return val && (box_length (val) > 1);
#endif
    }
}


int
xqi_is_value (xp_instance_t * xqi, XT * tree)
{
  switch (tree->type)
    {
    case XP_STEP:
    {
      int state = (int) XQI_GET_INT (xqi, tree->_.step.state);
      if (XI_INITIAL == state)
	{
	  xqi_raw_value (xqi, tree);
	  state = (int) XQI_GET_INT (xqi, tree->_.step.state);
	}
      return (XI_RESULT == state);
    }
    case XP_VARIABLE:
    case XP_FAKE_VAR:
    {
      int state = (int) XQI_GET_INT (xqi, tree->_.var.state);
      if (XI_INITIAL == state)
	return (xqi_is_next_value (xqi, tree));
      return (XI_RESULT == state);
    }
    case XP_UNION:
    {
      int state = (int) XQI_GET_INT (xqi, tree->_.xp_union.state);
      if (XI_INITIAL == state)
	{
	  xqi_next (xqi, tree);
	  state = (int) XQI_GET_INT (xqi, tree->_.xp_union.state);
	}
      if (XI_AT_END == state)
	return 0;
      return 1;
    }
    case XP_FILTER:
      {
	int state = (int) XQI_GET_INT (xqi, tree->_.filter.state);
	if (XI_INITIAL == state)
	  {
	    xqi_raw_value (xqi, tree);
	    state = (int) XQI_GET_INT (xqi, tree->_.filter.state);
	  }
	return (XI_RESULT == state);
      }
    case CALL_STMT:
      if (NULL == tree->_.xp_func.var)
	return 1;
      return (xqi_is_value (xqi, tree->_.xp_func.var));
    case XQ_QUERY_MODULE:
      {
        XT *body = tree->_.module.body;
	if (NULL == body)
	  sqlr_new_error ("42000", "XI???", "The XQuery text passed to XQuery processor is a library module, not an XQuery expression");
        return xqi_is_value (xqi, body);
      }
    case XP_LITERAL:
      return 1;
    case XQ_FOR_SQL:
      {
	int state = (int) XQI_GET_INT (xqi, tree->_.xq_for_sql.lc_state);
	if (XI_INITIAL == state)
	  return (xqi_is_next_value (xqi, tree));
	return (XI_RESULT == state);
      }
    }
  return 1;
}


#if 0
int
xt_is_ret_node_set (XT * tree)
{
  switch (tree->type)
  {
  case XP_STEP: case XP_FILTER: case XP_UNION:
    return 1;
  case CALL_STMT:
    return (XPDV_NODESET == tree->_.xp_func.res_dtp) ? 1 : 0;
  case XQ_QUERY_MODULE:
    return xt_is_ret_node_set (tree->_.module.body);
  case XP_VARIABLE:
  case XP_FAKE_VAR:
    return 1;
#if 0
    {
      caddr_t * set = (caddr_t *) XQI_GET (xqi, tree->_.var.init);
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(set))
	return 1;
      else
	return 0;
    }
#endif
  }
  return 0;
}


int
xt_is_ret_boolean (XT * tree)
{
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree))
    {
      switch (tree->type)
	{
	case BOP_EQ: case BOP_NEQ:
	case BOP_LTE: case BOP_LT: case BOP_GTE: case BOP_GT:
	case BOP_LIKE:
	case BOP_SAME: case BOP_NSAME:
	case BOP_AND: case BOP_OR: case BOP_NOT:
	  return 1;
	case CALL_STMT:
	  return ((XPDV_BOOL == tree->_.xp_func.res_dtp) ? 1 : 0);
	case XQ_QUERY_MODULE:
	  return xt_is_ret_boolean (tree->_.module.body);
	default:
	  return 0;
	}
    }
  return 0;
}
#endif

int xt_predict_returned_type (XT * tree)
{
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
    return (dtp_t)DV_UNKNOWN;
  switch (tree->type)
    {
    case BOP_EQ: case BOP_NEQ:
    case BOP_LTE: case BOP_LT: case BOP_GTE: case BOP_GT:
    case BOP_LIKE:
    case BOP_SAME: case BOP_NSAME:
    case BOP_AND: case BOP_OR: case BOP_NOT:
      return XPDV_BOOL;
    case CALL_STMT:
      return (int) tree->_.xp_func.res_dtp;
    case XQ_QUERY_MODULE:
      return xt_predict_returned_type (tree->_.module.body);
    case XP_STEP: case XP_FILTER: case XP_UNION:
      return XPDV_NODESET;
    case XP_VARIABLE:
    case XP_FAKE_VAR:
      return DV_UNKNOWN;
    case XP_LITERAL:
      return DV_TYPE_OF (tree->_.literal.val);
    case XQ_FOR_SQL:
      return XPDV_NODESET;
    default: ; /* see after switch; */
    }
  return DV_UNKNOWN;
}


int
xqi_is_next_value (xp_instance_t * xqi, XT * tree)
{
  switch (tree->type)
    {
    case XP_STEP:
      xqi_next (xqi, tree);
      return (XI_RESULT == XQI_GET_INT (xqi, tree->_.step.state));
    case XP_VARIABLE:
    case XP_FAKE_VAR:
      xqi_next (xqi, tree);
      return (XI_RESULT == XQI_GET_INT (xqi, tree->_.var.state));
    case XP_FILTER:
      xqi_next (xqi, tree);
      return (XI_RESULT == XQI_GET_INT (xqi, tree->_.filter.state));
    case XP_UNION:
      xqi_next (xqi, tree);
      return (XI_RESULT == XQI_GET_INT (xqi, tree->_.xp_union.state));
    case CALL_STMT:
      return ((NULL != tree->_.xp_func.var) ?
        xqi_is_next_value (xqi, tree->_.xp_func.var) : 0 );
    case XQ_QUERY_MODULE:
      return (xqi_is_next_value (xqi, tree->_.module.body));
    case XQ_FOR_SQL:
      xqi_next (xqi, tree);
      return (XI_RESULT == XQI_GET_INT (xqi, tree->_.xq_for_sql.lc_state));
    }
  return 0;
}


int
xp_compare_like (xp_instance_t * xqi, caddr_t x, caddr_t y)
{
  int st = LIKE_ARG_CHAR, pt = LIKE_ARG_CHAR;
  dtp_t ltype = DV_TYPE_OF (x);
  dtp_t rtype = DV_TYPE_OF (y);
  if (DV_WIDE == rtype || DV_LONG_WIDE == rtype)
    pt = LIKE_ARG_WCHAR;
  if (DV_WIDE == ltype || DV_LONG_WIDE == ltype)
    st = LIKE_ARG_WCHAR;

  if (DV_STRINGP (x) && DV_STRINGP (y)
    && DVC_MATCH == cmp_like (x, y, NULL, 0, st, pt))
    return DVC_MATCH;
  return DVC_LESS;
}


int
xp_compare_plain (xp_instance_t * xqi, caddr_t x, caddr_t y)
{
  return (cmp_boxes (x, y, NULL, NULL));
}


int
xp_compare_same (xp_instance_t * xqi, caddr_t x, caddr_t y)
{
  if (
    (DV_XML_ENTITY == DV_TYPE_OF(x)) &&
    (DV_XML_ENTITY == DV_TYPE_OF(y)) )
    {
      xml_entity_t *xe_x = (xml_entity_t *)x;
      xml_entity_t *xe_y = (xml_entity_t *)y;
      if (xe_x->_->xe_is_same_as (xe_x, xe_y))
	return DVC_MATCH;
    }
  return DVC_LESS;
}


int
xp_compare_xpath2 (xp_instance_t * xqi, caddr_t x, caddr_t y)
{
  dtp_t x_dtp = DV_TYPE_OF(x), y_dtp = DV_TYPE_OF(y);
  caddr_t x_cmp, y_cmp;
  int res;
  dtp_t optype = DV_SHORT_STRING;
  do
    {
      if (IS_NUM_DTP (x_dtp) || IS_NUM_DTP (y_dtp))
	{
	  optype = DV_NUMERIC;
	  break;
	}
      if (IS_STRING_DTP (x_dtp) || IS_STRING_DTP (y_dtp))
	{
	  optype = DV_SHORT_STRING;
	  break;
	}
      if (DV_XML_ENTITY == x_dtp)
	{
	  optype = (dtp_t)((DV_XML_ENTITY == y_dtp) ? DV_SHORT_STRING : y_dtp);
	  break;
	}
      if (DV_XML_ENTITY == y_dtp)
	{
	  optype = x_dtp;
	  break;
	}
      optype = x_dtp;
    } while (0);
/* Normalization as a temporary stub for dates etc: */
  if (!IS_NUM_DTP (optype))
    optype = DV_SHORT_STRING;
/* Casting */
  if (DV_XML_ENTITY == x_dtp)
    {
      xml_entity_t * x_xe = (xml_entity_t *) x;
      x_cmp = NULL;
      xe_string_value_1 (x_xe, &(x_cmp), optype);
    }
  else
    {
      if (DV_SHORT_STRING == optype)
        x_cmp = box_cast ((caddr_t *) xqi->xqi_qi, x, (sql_tree_tmp*) st_varchar, DV_SHORT_STRING);
      else
	x_cmp = xp_box_number (x);
    }
  if (DV_XML_ENTITY == y_dtp)
    {
      xml_entity_t * y_xe = (xml_entity_t *) y;
      y_cmp = NULL;
      xe_string_value_1 (y_xe, &(y_cmp), optype);
    }
  else
    {
      if (DV_SHORT_STRING == optype)
        y_cmp = box_cast ((caddr_t *) xqi->xqi_qi, y, (sql_tree_tmp*) st_varchar, DV_SHORT_STRING);
      else
	y_cmp = xp_box_number (y);
    }
/* Comparison */
  res = cmp_boxes (x_cmp, y_cmp, NULL, NULL);
  dk_free_box (x_cmp);
  dk_free_box (y_cmp);
  return res;
}


int
xqi_comparison (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int op = (int) tree->type;
  int (* xp_compare_fun) (xp_instance_t * xqi, caddr_t x, caddr_t y) = xp_compare_plain;
  dtp_t target_dtp;
  switch (op)
    {
      case BOP_LIKE:
	target_dtp = DV_SHORT_STRING;
	xp_compare_fun = xp_compare_like;
	break;
      case BOP_EQ: case BOP_NEQ:
	target_dtp = DV_SHORT_STRING;
	break;
      case BOP_LT:
      case BOP_LTE:
      case BOP_GT:
      case BOP_GTE:
	if (xqi->xqi_xpath2_compare_rules)
	  {
	    target_dtp = DV_UNKNOWN;
	    xp_compare_fun = xp_compare_xpath2;
	    break;
	  }
	target_dtp = DV_NUMERIC;
	break;
      case BOP_SAME:
      case BOP_NSAME:
	target_dtp = DV_UNKNOWN;
	xp_compare_fun = xp_compare_same;
	break;
      default:
	target_dtp = DV_SHORT_STRING; /* to make compiler happy. */
	GPF_T;
    }
  xqi_eval (xqi, tree->_.bin_exp.left, ctx_xe);
  while (xqi_is_value (xqi, tree->_.bin_exp.left))
    {
      caddr_t lv = xqi_value (xqi, tree->_.bin_exp.left, target_dtp);
      caddr_t *lv_items;
      size_t lv_idx;
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(lv))
	{
	  lv_items = (caddr_t *)lv;
	  lv_idx = BOX_ELEMENTS(lv);
	}
      else
	{
	  lv_items = &lv;
	  lv_idx = 1;
	}
      while (lv_idx--)
	{
	  xqi_eval (xqi, tree->_.bin_exp.right, ctx_xe);
	  while (xqi_is_value (xqi, tree->_.bin_exp.right))
	    {
	      caddr_t rv = xqi_value (xqi, tree->_.bin_exp.right, target_dtp);
	      caddr_t *rv_items;
	      size_t rv_idx;
	      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(rv))
		{
		  rv_items = (caddr_t *)rv;
		  rv_idx = BOX_ELEMENTS(rv);
		}
	      else
		{
		  rv_items = &rv;
		  rv_idx = 1;
		}
	      while(rv_idx--)
		{
		  int rc = xp_compare_fun (xqi, lv_items[lv_idx], rv_items[rv_idx]);
		  switch (rc)
		    {
		    case DVC_MATCH:
		      if (op == BOP_EQ || op == BOP_LTE || op == BOP_GTE || op == BOP_LIKE || op == BOP_SAME)
			return 1;
		      break;
		    case DVC_LESS:
		      if (op == BOP_NEQ || op == BOP_LT || op == BOP_LTE || op == BOP_NSAME)
			return 1;
		      break;
		    case DVC_GREATER:
		      if (op == BOP_NEQ || op == BOP_GT || op == BOP_GTE)
			return 1;
		      break;
		    }
		}
	      if (!xqi_is_next_value (xqi, tree->_.bin_exp.right))
		break;
	    }
	}
      if (!xqi_is_next_value (xqi, tree->_.bin_exp.left))
	break;
    }
  return 0;
}


caddr_t
xp_string (query_instance_t * qi, caddr_t val)
{
  caddr_t res = NULL;
  dtp_t dtp;
  dtp = DV_TYPE_OF (val);
  if (DV_XML_ENTITY == dtp)
    {
      xml_entity_t * xe = (xml_entity_t *) val;
      xe->_->xe_string_value (xe,
			      &res, DV_SHORT_STRING);
      return res;
    }
  else
    {
      val = box_cast ((caddr_t *) qi, val, (sql_tree_tmp*) st_varchar, dtp);
      return val;
    }
}


#define FN_QUOTE L'\''
#define CURRENCY_SIGN L'\xA4'
#define INTL_CURRENCY_SYMBOL	L'$'
#define CURRENCY_SYMBOL		L'$'

caddr_t
xslt_format_number (numeric_t value, caddr_t format,
    xslt_number_format_t * nf)
{
  int currency_format = 0;

  wchar_t *pattern =
      (wchar_t *) box_utf8_as_wide_char (format, NULL, strlen (format), 0,
      DV_WIDE);

  caddr_t res = NULL, res1;
  caddr_t res_prefix, res_suffix;
  caddr_t positive_prefix = NULL;
  caddr_t positive_suffix = NULL;
  caddr_t negative_prefix = NULL;
  caddr_t negative_suffix = NULL;

  wchar_t digit, zero_digit, grouping_sep, decimal_sep, percent, per_mille,
      separator, minus_sign;
  virt_mbstate_t c_state;

  NUMERIC_VAR (_value_buf);
  numeric_t _value;

  int min_int_digits = 0;
  int max_int_digits = 0;
  int max_frac_digits = 0;
  int min_frac_digits = 0;
  int grouping_used = 0;
  int grouping_size = 0;
  int multiplier = 0;
  int decimal_sep_always_shown = 0;

  int got_negative = 0, j;

  /* Two variables are used to record the subrange of the pattern
     occupied by phase 1.  This is used during the processing of the
     second pattern (the one representing negative numbers) to ensure
     that no deviation exists in phase 1 between the two patterns. */
  int phase_one_start = 0;
  int phase_one_length = 0;

  int pattern_length = (int) wcslen (pattern);

  int start = 0;

  currency_format = 0;

#define LOAD_FROM_XSNF(varname,field_name) \
  memset (&c_state, 0, sizeof (c_state)); \
  virt_mbrtowc (&varname, (utf8char *)nf->field_name, strlen (nf->field_name), &c_state);

  LOAD_FROM_XSNF(digit, xsnf_digit);
  LOAD_FROM_XSNF(zero_digit, xsnf_zero_digit);
  LOAD_FROM_XSNF(grouping_sep, xsnf_grouping_sep);
  LOAD_FROM_XSNF(decimal_sep, xsnf_decimal_sep);
  LOAD_FROM_XSNF(percent, xsnf_percent);
  LOAD_FROM_XSNF(per_mille, xsnf_per_mille);
  LOAD_FROM_XSNF(separator, xsnf_pattern_sep);
  LOAD_FROM_XSNF(minus_sign, xsnf_minus_sign);

  NUMERIC_INIT (_value_buf);
  _value = (numeric_t) _value_buf;
  for (j = 1; j >= 0 && start < pattern_length; --j)
    {
      int in_quote = 0;
      size_t pref_suf_size = (pattern_length + 1) * sizeof (wchar_t);
      wchar_t *prefix =
	  (wchar_t *) dk_alloc (pref_suf_size);
      wchar_t *suffix =
	  (wchar_t *) dk_alloc (pref_suf_size);
      int decimal_pos = -1;
      int digit_left_count = 0, zero_digit_count = 0, digit_right_count = 0;
      int grouping_count = -1;

      /* The phase ranges from 0 to 2.  Phase 0 is the prefix.  Phase 1 is
	 the section of the pattern with digits, decimal separator,
	 grouping characters.  Phase 2 is the suffix.  In phases 0 and 2,
	 percent, permille, and currency symbols are recognized and
	 translated.  The separation of the characters into phases is
	 strictly enforced; if phase 1 characters are to appear in the
	 suffix, for example, they must be quoted. */
      int phase = 0;
      int pos;

      /* The affix is either the prefix or the suffix. */
      wchar_t *affix = prefix, *affix_ptr = prefix;

      multiplier = 1;
      memset (prefix, 0, (pattern_length + 1) * sizeof (wchar_t));
      memset (suffix, 0, (pattern_length + 1) * sizeof (wchar_t));

      for (pos = start; pos < pattern_length; ++pos)
	{
	  wchar_t ch = pattern[pos];
	  switch (phase)
	    {
	    case 0:
	    case 2:
	      /* Process the prefix / suffix characters */
	      if (in_quote)
		{
		  /* A quote within quotes indicates either the closing
		     quote or two quotes, which is a quote literal.  That is,
		     we have the second quote in 'do' or 'don''t'. */
		  if (ch == FN_QUOTE)
		    {
		      if ((pos + 1) < pattern_length &&
			  pattern[pos + 1] == FN_QUOTE)
			{
			  ++pos;
			  *affix_ptr++ = ch;	/* 'don''t' */
			}
		      else
			{
			  in_quote = 0;	/* 'do' */
			}
		      continue;
		    }
		}
	      else
		{
		  /* Process unquoted characters seen in prefix or suffix
		     phase. */
		  if (ch == digit ||
		      ch == zero_digit ||
		      ch == grouping_sep || ch == decimal_sep)
		    {
		      if (phase == 2 && affix_ptr - affix > 0)
			{
			  dk_free (prefix, pref_suf_size);
			  dk_free (suffix, pref_suf_size);
			  dk_free_box ((box_t) pattern);
			  sqlr_new_error ("XS037", "22023", "Unquoted special character in format-number()");
			}
		      phase = 1;
		      if (j == 1)
			phase_one_start = pos;
		      --pos;	/* Reprocess this character */
		      continue;
		    }
		  else if (ch == CURRENCY_SIGN)
		    {
		      /* Use lookahead to determine if the currency sign is
			 doubled or not. */
		      int doubled = (pos + 1) < pattern_length &&
			  pattern[pos + 1] == CURRENCY_SIGN;
		      *affix_ptr++ = doubled ?
			  INTL_CURRENCY_SYMBOL : CURRENCY_SYMBOL;
		      if (doubled)
			++pos;	/* Skip over the doubled character */
		      currency_format = 1;
		      continue;
		    }
		  else if (ch == FN_QUOTE)
		    {
		      /* A quote outside quotes indicates either the opening
			 quote or two quotes, which is a quote literal.  That is,
			 we have the first quote in 'do' or o''clock. */
		      if (ch == FN_QUOTE)
			{
			  if ((pos + 1) < pattern_length &&
			      pattern[pos + 1] == FN_QUOTE)
			    {
			      ++pos;
			      *affix_ptr++ = ch;	/* o''clock */
			    }
			  else
			    {
			      in_quote = 1;	/* 'do' */
			    }
			  continue;
			}
		    }
		  else if (ch == separator)
		    {
		      /* Don't allow separators before we see digit characters of phase
			 1, and do not allow separators in the second pattern (j == 0). */
		      if (phase == 0 || j == 0)
			{
			  dk_free (prefix, pref_suf_size);
			  dk_free (suffix, pref_suf_size);
			  dk_free_box ((box_t) pattern);
			  sqlr_new_error ("XS038", "22023", "Unquoted special character in format-number()");
			}
		      start = pos + 1;
		      pos = pattern_length;
		      continue;
		    }

		  /* Next handle characters which are appended directly. */
		  else if (ch == percent)
		    {
		      if (multiplier != 1)
			{
			  dk_free (prefix, pref_suf_size);
			  dk_free (suffix, pref_suf_size);
			  dk_free_box ((box_t) pattern);
			  sqlr_new_error ("22023", "XS039",
			      "Too many percent/permille characters in format-number() pattern");
			}
		      multiplier = 100;
		    }
		  else if (ch == per_mille)
		    {
		      if (multiplier != 1)
			{
			  dk_free (prefix, pref_suf_size);
			  dk_free (suffix, pref_suf_size);
			  dk_free_box ((box_t) pattern);
			  sqlr_new_error ("22023", "XS040",
			      "Too many percent/permille characters in format-number() pattern");
			}
		      multiplier = 1000;
		    }
		}
	      /* Note that if we are within quotes, or if this is an unquoted,
		 non-special character, then we usually fall through to here. */
	      *affix_ptr++ = ch;
	      break;
	    case 1:
	      /* Phase one must be identical in the two sub-patterns.  We
		 enforce this by doing a direct comparison.  While
		 processing the first sub-pattern, we just record its
		 length.  While processing the second, we compare
		 characters. */
	      if (j == 1)
		++phase_one_length;
	      else
		{
		  if (--phase_one_length == 0)
		    {
		      phase = 2;
		      affix_ptr = affix = suffix;
		    }
		  continue;
		}

	      /* Process the digits, decimal, and grouping characters.  We
		 record five pieces of information.  We expect the digits
		 to occur in the pattern ####0000.####, and we record the
		 number of left digits, zero (central) digits, and right
		 digits.  The position of the last grouping character is
		 recorded (should be somewhere within the first two blocks
		 of characters), as is the position of the decimal point,
		 if any (should be in the zero digits).  If there is no
		 decimal point, then there should be no right digits. */
	      if (ch == digit)
		{
		  if (zero_digit_count > 0)
		    ++digit_right_count;
		  else
		    ++digit_left_count;
		  if (grouping_count >= 0 && decimal_pos < 0)
		    ++grouping_count;
		}
	      else if (ch == zero_digit)
		{
		  if (digit_right_count > 0)
		    {
		      dk_free (prefix, pref_suf_size);
		      dk_free (suffix, pref_suf_size);
		      dk_free_box ((box_t) pattern);
		      sqlr_new_error ("22023", "XS041",
			  "Unexpected '0' in format-number() pattern");
		    }
		  ++zero_digit_count;
		  if (grouping_count >= 0 && decimal_pos < 0)
		    ++grouping_count;
		}
	      else if (ch == grouping_sep)
		{
		  grouping_count = 0;
		}
	      else if (ch == decimal_sep)
		{
		  if (decimal_pos >= 0)
		    {
		      dk_free (prefix, pref_suf_size);
		      dk_free (suffix, pref_suf_size);
		      dk_free_box ((box_t) pattern);
		      sqlr_new_error ("22023", "XS042",
			  "Multiple decimal separators in format-number() pattern");
		    }
		  decimal_pos =
		      digit_left_count + zero_digit_count + digit_right_count;
		}
	      else
		{
		  phase = 2;
		  affix_ptr = affix = suffix;
		  --pos;
		  --phase_one_length;
		  continue;
		}
	      break;
	    }
	}

      /* Handle patterns with no '0' pattern character.  These patterns
	 are legal, but must be interpreted.  "##.###" -> "#0.###".
	 ".###" -> ".0##". */
      if (zero_digit_count == 0 && digit_left_count > 0)
	{
	  if (decimal_pos >= 0)	/* Handle "###.###" and "###." and ".###" */
	    {
	      int n = decimal_pos;
	      if (n == 0)
		++n;		/* Handle ".###" */
	      digit_right_count = digit_left_count - n;
	      digit_left_count = n - 1;
	    }
	  else
	    --digit_left_count;	/* Handle "###" */
	  zero_digit_count = 1;
	}

      /* Do syntax checking on the digits. */
      if ((decimal_pos < 0 && digit_right_count > 0) ||
	  (decimal_pos >= 0 &&
	      (decimal_pos < digit_left_count ||
		  decimal_pos > (digit_left_count + zero_digit_count))) ||
	  grouping_count == 0 || in_quote)
	{
	  dk_free (prefix, pref_suf_size);
	  dk_free (suffix, pref_suf_size);
	  dk_free_box ((box_t) pattern);
	  sqlr_new_error ("22023", "XS043", "Malformed format-number() pattern");
	}

      if (j == 1)
	{
	  int digit_total_count, effective_decimal_pos;

	  positive_prefix =
	      box_wide_as_utf8_char ((ccaddr_t)prefix, wcslen (prefix),
	      DV_SHORT_STRING);
	  positive_suffix =
	      box_wide_as_utf8_char ((ccaddr_t)suffix, wcslen (suffix),
	      DV_SHORT_STRING);
	  negative_prefix = positive_prefix;	/* assume these for now */
	  negative_suffix = positive_suffix;
	  digit_total_count =
	      digit_left_count + zero_digit_count + digit_right_count;
	  /* The effective_decimal_pos is the position the decimal is at or
	   * would be at if there is no decimal.  Note that if decimal_pos<0,
	   * then digit_total_count == digit_left_count + zero_digit_count.  */
	  effective_decimal_pos =
	      decimal_pos >= 0 ? decimal_pos : digit_total_count;
	  min_int_digits = effective_decimal_pos - digit_left_count;
	  max_int_digits = 127;
	  max_frac_digits =
	      decimal_pos >= 0 ? (digit_total_count - decimal_pos) : 0;
	  min_frac_digits =
	      decimal_pos >=
	      0 ? (digit_left_count + zero_digit_count - decimal_pos) : 0;
	  grouping_used = grouping_count > 0;
	  grouping_size = (grouping_count > 0) ? grouping_count : 0;
	  decimal_sep_always_shown = decimal_pos == 0
	      || decimal_pos == digit_total_count;
	}
      else
	{
	  negative_prefix =
	      box_wide_as_utf8_char ((ccaddr_t)prefix, wcslen (prefix),
	      DV_SHORT_STRING);
	  negative_suffix =
	      box_wide_as_utf8_char ((ccaddr_t)suffix, wcslen (suffix),
	      DV_SHORT_STRING);
	  got_negative = 1;
	}
      dk_free (prefix, pref_suf_size);
      dk_free (suffix, pref_suf_size);
    }

  if (!positive_prefix)
    positive_prefix = box_dv_short_string ("");
  if (!positive_suffix)
    positive_suffix = box_dv_short_string ("");
  if (!negative_prefix)
    negative_prefix = box_dv_short_string ("");
  if (!negative_suffix)
    negative_suffix = box_dv_short_string ("");
  dk_free_box ((box_t) pattern);
  /* If there was no negative pattern, or if the negative pattern is identical
     to the positive pattern, then prepend the minus sign to the positive
     pattern to form the negative pattern. */
  if (!got_negative ||
      (!strcmp (negative_prefix, positive_prefix)
	  && !strcmp (negative_suffix, positive_suffix)))
    {
      caddr_t new_prefix;

      dk_free_box (negative_suffix);
      negative_suffix = box_copy (positive_suffix);

      dk_free_box (negative_prefix);
      new_prefix =
	  dk_alloc_box (box_length (positive_prefix) +
	  box_length (nf->xsnf_minus_sign) - 1, DV_SHORT_STRING);
      strcpy_box_ck (new_prefix, nf->xsnf_minus_sign);
      strcat_box_ck (new_prefix, positive_prefix);

      negative_prefix = new_prefix;
    }

  /* do the conversion */

  if (numeric_sign (value))
    {
      res_prefix = negative_prefix;
      res_suffix = negative_suffix;
    }
  else
    {
      res_prefix = positive_prefix;
      res_suffix = positive_suffix;
    }

  res = NULL;
  switch (numeric_rescale (_value, value, max_int_digits + max_frac_digits,
	  max_frac_digits))
    {
    case NUMERIC_STS_UNDERFLOW:
    do_underflow:
      res =
	  dk_alloc_box (box_length (nf->xsnf_minus_sign) +
	  box_length (nf->xsnf_infinity) - 1, DV_SHORT_STRING);
      strcpy_box_ck (res, nf->xsnf_minus_sign);
      strcat_box_ck (res, nf->xsnf_infinity);
      break;

    case NUMERIC_STS_OVERFLOW:
    do_overflow:
      res = box_copy (nf->xsnf_infinity);
      break;

    case NUMERIC_STS_SUCCESS:
      {
	char buffer[100];
	switch (numeric_to_string (_value, buffer, sizeof (buffer)))
	  {
	  case NUMERIC_STS_OVERFLOW:
	    goto do_overflow;
	  case NUMERIC_STS_UNDERFLOW:
	    goto do_underflow;
	  case NUMERIC_STS_INVALID_NUM:
	    res = box_copy (nf->xsnf_NaN);
	  default:
	    {
	      char *out_ptr, *in_ptr;
	      int grouping_symbols;
	      int padding_zero_count =
		  min_int_digits - numeric_raw_precision (_value) +
		  numeric_scale (_value);
	      int right_padding_zero_count =
		  min_frac_digits - numeric_scale (_value);
	      int n_digits = 0;
	      int total_digits;

	      if (padding_zero_count < 0)
		padding_zero_count = 0;
	      if (right_padding_zero_count < 0)
		right_padding_zero_count = 0;
	      total_digits =
		  numeric_raw_precision (_value) - numeric_scale (_value) +
		  padding_zero_count;
	      grouping_symbols =
		  !grouping_used ? 0 : (int) ((box_length (nf->
			  xsnf_grouping_sep) -
		      1) * ((double) (min_int_digits +
			  padding_zero_count)) / grouping_size + 1);

	      out_ptr = res = dk_alloc_box_zero (box_length (res_prefix) - 1 +
		  ((5+total_digits)*(2+grouping_symbols)) +
		  box_length (nf->xsnf_decimal_sep) - 1 +
		  max_frac_digits +
		  padding_zero_count +
		  right_padding_zero_count +
		  box_length (res_suffix) + 1, DV_SHORT_STRING);
	      in_ptr = buffer;
	      memcpy (out_ptr, res_prefix, box_length (res_prefix));
	      out_ptr += box_length (res_prefix) - 1;
	      if (*in_ptr == '-')
		in_ptr++;
	      if (padding_zero_count > 0 && *in_ptr == '0') /* if number begins with zero we will remove it */
		padding_zero_count--;
	      while (padding_zero_count > 0)
		{
		  if (grouping_used && n_digits && total_digits
		      && (total_digits % grouping_size) == 0)
		    {
		      memcpy (out_ptr, nf->xsnf_grouping_sep,
			  box_length (nf->xsnf_grouping_sep));
		      out_ptr += box_length (nf->xsnf_grouping_sep) - 1;
		    }
		  *out_ptr++ = '0';
		  n_digits++;
		  total_digits--;
		  padding_zero_count--;
		}
	      while (isdigit (*in_ptr) && *in_ptr != '.')
		{
		  if (grouping_used && n_digits && total_digits
		      && (total_digits % grouping_size) == 0)
		    {
		      memcpy (out_ptr, nf->xsnf_grouping_sep,
			  box_length (nf->xsnf_grouping_sep));
		      out_ptr += box_length (nf->xsnf_grouping_sep) - 1;
		    }
		  *out_ptr++ = *in_ptr++;
		  n_digits++;
		  total_digits--;
		}

	      if (max_frac_digits)
		{
		  int scale = numeric_scale (_value);

		  if (*in_ptr == '.' || right_padding_zero_count)
		    {
		      memcpy (out_ptr, nf->xsnf_decimal_sep,
			  box_length (nf->xsnf_decimal_sep));
		      out_ptr += box_length (nf->xsnf_decimal_sep) - 1;
		    }

		  if (*in_ptr == '.')
		    in_ptr++;

		  if (scale)
		    {
		      while (scale)
			{
			  *out_ptr++ = *in_ptr++;
			  n_digits++;
			  scale--;
			}
		    }
		  while (right_padding_zero_count > 0)
		    {
		      *out_ptr++ = '0';
		      n_digits++;
		      right_padding_zero_count--;
		    }
		}
	      memcpy (out_ptr, res_suffix, box_length (res_suffix));
	    }
	  }
      }
      break;
    }
  dk_free_box (negative_prefix);
  dk_free_box (negative_suffix);
  dk_free_box (positive_prefix);
  dk_free_box (positive_suffix);
  res1 = box_dv_short_string (res);
  dk_free_box (res);
  return res1;
}


static caddr_t
bif_xslt_format_number (caddr_t *qst, caddr_t *err_ret, state_slot_t **args)
{
  caddr_t val = bif_arg (qst, args, 0, "xslt_format_number");
  caddr_t format = bif_string_arg (qst, args, 1, "xslt_format_number");
  NUMERIC_VAR (value_buf);
  numeric_t value;
  caddr_t res, err;

  NUMERIC_INIT (value_buf);
  value = (numeric_t) value_buf;
  if (NULL != (err = numeric_from_x (value, val, NUMERIC_MAX_PRECISION,
	  NUMERIC_MAX_SCALE, "xslt_format_number", -1, NULL)))
    sqlr_resignal (err);

  res = xslt_format_number (value, format, xsnf_default);
  return res;
}


xqi_binding_t *
xqi_find_binding (xp_instance_t * xqi, caddr_t name)
{
  xqi_binding_t * xb = xqi->xqi_internals;
  while (xb)
    {
      if (name == xb->xb_name)
	return xb;
      xb = xb->xb_next;
    }
  xb = xqi->xqi_xp_locals;
  while (xb)
    {
      if (!xb->xb_name)
	break;
      if (name == xb->xb_name)
	return xb;
      xb = xb->xb_next;
    }
  xb = xqi->xqi_xp_globals;
  while (xb)
    {
      if (name == xb->xb_name)
	return xb;
      xb = xb->xb_next;
    }
  return NULL;
}

xqi_binding_t *
xqi_push_internal_binding (xp_instance_t * xqi, caddr_t name)
{
  NEW_VARZ (xqi_binding_t, xb);
  xb->xb_name = name;
  xb->xb_next = xqi->xqi_internals;
  xqi->xqi_internals = xb;
  return xb;
}


void
xqi_pop_internal_binding (xp_instance_t * xqi)
{
  xqi_binding_t *xb = xqi->xqi_internals;
  if (NULL == xb)
    return;
  xqi->xqi_internals = xb->xb_next;
  dk_free_tree (xb->xb_value);
  dk_free (xb, sizeof (xqi_binding_t));
}


void
xqi_pop_internal_bindings (xp_instance_t * xqi, xqi_binding_t *bottom_xb)
{
  xqi_binding_t *xb;
  for (;;)
    {
      xb = xqi->xqi_internals;
      if ((bottom_xb == xb) || (NULL == xb))
	return;
      xqi->xqi_internals = xb->xb_next;
      dk_free_tree (xb->xb_value);
      dk_free (xb, sizeof (xqi_binding_t));
    }
}


void
xqi_remove_internal_binding (xp_instance_t * xqi, caddr_t name)
{
  xqi_binding_t ** xbptr = &(xqi->xqi_internals);
  while (NULL != xbptr[0])
    {
      xqi_binding_t * xb = xbptr[0];
      if (name == xb->xb_name)
	{
	  dk_free_tree (xb->xb_value);
	  xbptr[0] = xb->xb_next;
	  dk_free (xb, sizeof (xqi_binding_t));
	  return;
	}
      xbptr = &(xb->xb_next);
    }
}


/* IvAn/XqVal/010628 You should check for DV_ARRAY_OF_XQVAL instead */
#if 0
int
dv_is_node_set (caddr_t x)
{
  /* a node set is an array that is 1. empty 2. has a non array as first.
   * an array that has an array as first is a result tree fragment */
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (x))
    {
      int len = BOX_ELEMENTS (x);
      if (len == 0)
	return 1;
      return (DV_ARRAY_OF_POINTER != DV_TYPE_OF (((caddr_t*)x)[0]));
    }
  return 0;
}
#endif


void
xqi_eval_var (xp_instance_t * xqi, XT * tree)
{
  dtp_t dtp;
  caddr_t val;
  xqi_binding_t * xb = xqi_find_binding (xqi, tree->_.var.name);
  if (!xb)
    sqlr_new_error_xqi_xdl ("XP220", "XI001", xqi, "Unbound XPATH parameter '%.300s'", tree->_.var.name);
  val = xb->xb_value;
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (val);
#endif
  dtp = DV_TYPE_OF (val);
  XQI_SET (xqi, tree->_.var.res, NULL);
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (val);
#endif
  XQI_SET (xqi, tree->_.var.init, NULL);
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (val);
#endif
  if (!val || (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val) && 0 == BOX_ELEMENTS (val)))
    {
      XQI_SET_INT (xqi, tree->_.var.state, XI_AT_END);
      return;
    }
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (val);
#endif
  XQI_SET (xqi, tree->_.var.init, box_copy_tree (val));
  XQI_SET_INT (xqi, tree->_.var.state, XI_INITIAL);
  XQI_SET_INT (xqi, tree->_.var.inx, 0);
}


void
xqi_eval_fake_var (xp_instance_t * xqi, XT * tree)
{
  dtp_t dtp;
  caddr_t val;
  val = XQI_GET (xqi, tree->_.var.init);
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (val);
#endif
  dtp = DV_TYPE_OF (val);
  XQI_SET (xqi, tree->_.var.res, NULL);
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (val);
#endif
  if (!val)
    {
      XQI_SET_INT (xqi, tree->_.var.state, XI_AT_END);
      return;
    }
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (val);
#endif
  XQI_SET_INT (xqi, tree->_.var.state, XI_INITIAL);
  XQI_SET_INT (xqi, tree->_.var.inx, 0);
}


void
xqi_eval (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int rc;
  state_slot_t res_slot;
  dtp_t dtp = DV_TYPE_OF (tree);
  if (dtp != DV_ARRAY_OF_POINTER)
    {
      return;
    }
  switch (tree->type)
    {
    case XP_LITERAL:
      return;
    case XP_VARIABLE:
      xqi_eval_var (xqi, tree);
      return;
    case XP_FAKE_VAR:
      xqi_eval_fake_var (xqi, tree);
      return;
    case XP_STEP:
      {
	if (!tree->_.step.input)
	  {
	    XQI_SET_INT (xqi, tree->_.step.state, XI_INITIAL);
	    XQI_SET (xqi, tree->_.step.init, box_copy_tree ((caddr_t) ctx_xe));
	    /* may not be an entity if current is an attr or text */
	    return;
	  }
	XQI_SET_INT (xqi, tree->_.step.state, XI_INITIAL);
	xqi_eval (xqi, tree->_.step.input, ctx_xe);
	return;
      }

    case XP_UNION:
      {
	xqi_eval (xqi, tree->_.xp_union.left, ctx_xe);
	xqi_eval (xqi, tree->_.xp_union.right, ctx_xe);
	XQI_SET (xqi, tree->_.xp_union.left_lpath, NULL);
	XQI_SET (xqi, tree->_.xp_union.right_lpath, NULL);
	XQI_SET_INT (xqi, tree->_.xp_union.state, XI_INITIAL);
	return;
      }
    case XP_FILTER:
      {
	XQI_SET_INT (xqi, tree->_.filter.state, XI_INITIAL);
	if (tree->_.filter.pred->_.pred.pos)
	  XQI_SET_INT (xqi, tree->_.filter.pred->_.pred.pos, 0);
	xqi_eval (xqi, tree->_.filter.path, ctx_xe);
	return;
      }
    case BOP_PLUS:
    case BOP_TIMES:
    case BOP_MINUS:
    case BOP_DIV:
    case BOP_MOD:
      {
	caddr_t left, right;
	xqi_eval (xqi, tree->_.bin_exp.left, ctx_xe);
	xqi_eval (xqi, tree->_.bin_exp.right, ctx_xe);
	xp_res_slot (xqi, &res_slot, XQI_ADDRESS (xqi, tree->_.bin_exp.res));
	left = xqi_value (xqi, tree->_.bin_exp.left, DV_NUMERIC);
	right = xqi_value (xqi, tree->_.bin_exp.right, DV_NUMERIC);
	if (!left || !right)
	  {
	    numeric_t n = numeric_allocate();
	    numeric_from_string (n, "NaN");
	    XQI_SET (xqi, tree->_.bin_exp.res, (caddr_t) n);
	    return;
	  }
	QR_RESET_CTX
	  {
	    switch (tree->type)
	      {
		case BOP_PLUS:	box_add (left, right, (caddr_t *) xqi, &res_slot); break;
		case BOP_MINUS:	box_sub (left, right, (caddr_t *) xqi, &res_slot); break;
		case BOP_TIMES:	box_mpy (left, right, (caddr_t *) xqi, &res_slot); break;
		case BOP_DIV:
/* IvAn/Bug3413/021004 Right argument should be made double if it is integer */
#if 0
	box_div (left, right, (caddr_t *) xqi, &res_slot); break;
#else
		  {
		    ptrlong rval;

		    if (DV_LONG_INT == DV_TYPE_OF (right))
		      {
			rval = unbox (right);
			if (0 != rval)
			  goto div_by_int;
		      }
		    box_div (left, right, (caddr_t *) xqi, &res_slot);
		    break;
div_by_int:
		    {
		      caddr_t tmp_right = box_double ((double) rval);
		      box_div (left, tmp_right, (caddr_t *) xqi, &res_slot);
		      dk_free_box (tmp_right);
		      break;
		    }
		  }
#endif
		case BOP_MOD:	box_mod (left, right, (caddr_t *) xqi, &res_slot); break;
	      }
	    if (NULL == XQI_GET (xqi, tree->_.bin_exp.res))
	      XQI_SET (xqi, tree->_.bin_exp.res, box_num_nonull (0));
	  }
	QR_RESET_CODE
	  {
	    du_thread_t * self = THREAD_CURRENT_THREAD;
	    caddr_t err = thr_get_error_code (self);
	    char *state;
	    state = ERR_STATE (err);
	    POP_QR_RESET;
	    if (!strcmp (state, "22012") &&
		DV_TYPE_OF (left) != DV_NUMERIC && DV_TYPE_OF (right) != DV_NUMERIC)
	      {
		dtp_t left_dtp = DV_TYPE_OF (left);
		numeric_t n = numeric_allocate();
		numeric_from_string (n,
		    left_dtp == DV_LONG_INT ? ((unbox (left) < 0 ? "-Inf" : "Inf")) :
		    (left_dtp == DV_SINGLE_FLOAT ? (unbox_float (left) < 0.0 ? "-Inf" : "Inf") :
		    (left_dtp == DV_DOUBLE_FLOAT ? (unbox_double (left) < 0.0 ? "-Inf" : "Inf") :
		    (left_dtp == DV_NUMERIC ? (numeric_sign ((numeric_t)left) ? "-Inf" : "Inf") : "Inf"))));
		XQI_SET (xqi, tree->_.bin_exp.res, (caddr_t) n);
		dk_free_tree (err);
	      }
	    else if (!strcmp (state, "22003"))
	      {
		dk_free_tree (err);
	      }
	    else
	      sqlr_resignal (err);
	  }
	END_QR_RESET;
	return;
      }
    case BOP_EQ: case BOP_NEQ:
    case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
    case BOP_LIKE:
    case BOP_SAME: case BOP_NSAME:
      rc = xqi_comparison (xqi, tree, ctx_xe);
      XQI_SET (xqi, tree->_.bin_exp.res, box_num_nonull(rc));
      break;
    case BOP_AND:
      xqi_eval (xqi, tree->_.bin_exp.left, ctx_xe);
      if (!xqi_truth_value (xqi, tree->_.bin_exp.left))
	{
	  XQI_SET (xqi, tree->_.bin_exp.res, box_num_nonull(0));
	  return;
	}
      xqi_eval (xqi, tree->_.bin_exp.right, ctx_xe);
      if (!xqi_truth_value (xqi, tree->_.bin_exp.right))
	{
	  XQI_SET (xqi, tree->_.bin_exp.res, box_num_nonull(0));
	  return;
	}
      XQI_SET (xqi, tree->_.bin_exp.res, box_num_nonull(1));
      return;
    case BOP_OR:
      xqi_eval (xqi, tree->_.bin_exp.left, ctx_xe);
      if (xqi_truth_value (xqi, tree->_.bin_exp.left))
	{
	  XQI_SET (xqi, tree->_.bin_exp.res, box_num_nonull(1));
	  return;
	}
      xqi_eval (xqi, tree->_.bin_exp.right, ctx_xe);
      if (xqi_truth_value (xqi, tree->_.bin_exp.right))
	{
	  XQI_SET (xqi, tree->_.bin_exp.res, box_num_nonull(1));
	  return;
	}
      XQI_SET (xqi, tree->_.bin_exp.res, box_num_nonull(0));
      return;
    case BOP_NOT:
      xqi_eval (xqi, tree->_.bin_exp.left, ctx_xe);
      if (!xqi_truth_value (xqi, tree->_.bin_exp.left))
	XQI_SET (xqi, tree->_.bin_exp.res, box_num_nonull(1));
      else
	XQI_SET (xqi, tree->_.bin_exp.res, box_num_nonull(0));
      return;
    case CALL_STMT:
      {
	xp_func_t fp = (xp_func_t) unbox_ptrlong (tree->_.xp_func.executable);
	if (!fp)
	  {
	    sqlr_new_error_xqi_xdl ("XP420", "XI002", xqi, "Undefined XPATH function '%.300s'",
		tree->_.xp_func.qname);
	  }
	fp (xqi, tree, ctx_xe);
	return;
      }
    case XQ_FOR_SQL:
      {
        caddr_t err = NULL;
        local_cursor_t * lc = (local_cursor_t *) XQI_GET_INT (xqi, tree->_.xq_for_sql.lc);
	dk_mem_wrapper_t * lc_mem_wrapper = (dk_mem_wrapper_t *) XQI_GET (xqi, tree->_.xq_for_sql.lc_mem_wrapper);
	query_t *qr = (query_t *)(tree->_.xq_for_sql.qr_mem_wrapper->dmw_data[0]);
	caddr_t *param_names = tree->_.xq_for_sql.xp2sql_params;
	if (NULL != lc)
          lc_free (lc);
        if (param_names)
          { /*create vector of pairs - (index, value) from tree->_.xq_for_sql.flwr_params*/
            int length = BOX_ELEMENTS(param_names);
	    size_t parms_boxlen = 2 * length * sizeof (caddr_t);
            caddr_t *parms = (caddr_t *) dk_alloc_box_zero (parms_boxlen, DV_ARRAY_OF_POINTER);
            int inx;
	    XQI_SET (xqi, tree->_.xq_for_sql.xp2sql_values, (caddr_t)parms);
            for (inx = 0; inx < length; inx ++)
              {
		caddr_t val;
		char tmp[20];
		xqi_binding_t * xb = xqi_find_binding (xqi, param_names[inx]);
		if (!xb)
		  sqlr_new_error_xqi_xdl ("XP220", "XI...", xqi, "Unbound XPATH parameter '%.300s' used in SQL subquery", param_names[inx]);
		sprintf(tmp,":%d", inx+1);
                parms[inx*2] = box_dv_uname_string (tmp);
		val = xb->xb_value;
		if (DV_ARRAY_OF_XQVAL != DV_TYPE_OF (val))
		  val = box_copy_tree (val);
		else
		  {
		    switch (BOX_ELEMENTS (val))
		      {
			case 0: val = NEW_DB_NULL; break;
			case 1: val = box_copy_tree(((caddr_t *)val)[0]); break;
			default:
			  sqlr_new_error_xqi_xdl ("XP220", "XI...", xqi, "Sequence is passed as a value of XPATH parameter '%.300s' used in SQL subquery", param_names[inx]);
		      }
		  }
		parms[inx*2 + 1] = val;
              }
            err = qr_exec (xqi->xqi_qi->qi_client, qr, xqi->xqi_qi, NULL, NULL, &lc, parms, NULL, 1);
            memset (parms, 0, parms_boxlen); /* To prevent double free of data that are passed to qr_exec */
          }
        else
          err = qr_exec (xqi->xqi_qi->qi_client, qr, xqi->xqi_qi, NULL, NULL, &lc, NULL, NULL, 0);
        if (err)
          sqlr_resignal (err);
        XQI_SET_INT (xqi, tree->_.xq_for_sql.lc, (ptrlong)(lc));
	if (NULL == lc_mem_wrapper)
	  {
	    lc_mem_wrapper = (dk_mem_wrapper_t *) dk_alloc_box (sizeof (dk_mem_wrapper_t), DV_MEM_WRAPPER);
	    lc_mem_wrapper->dmw_free = (dk_free_box_trap_cbk_t) lc_free;
	    lc_mem_wrapper->dmw_copy = NULL;
	    XQI_SET (xqi, tree->_.xq_for_sql.lc_mem_wrapper, (caddr_t)(lc_mem_wrapper));
	  }
	lc_mem_wrapper->dmw_data[0] = lc;
        XQI_SET_INT (xqi, tree->_.xq_for_sql.inx, 0);
        XQI_SET_INT (xqi, tree->_.xq_for_sql.lc_state, XI_INITIAL);
        return;
      }
    case XQ_QUERY_MODULE:
      {
        int inx;
        DO_BOX_FAST (XT *, def, inx, tree->_.module.defglobals)
          {
            XT *init_expn = def->_.defglobal.init_expn;
            caddr_t name = def->_.defglobal.name;
            caddr_t *res_ptr = XQI_ADDRESS (xqi, def->_.defglobal.res);
            xqi_binding_t *xb;
            if (NULL == init_expn)
              {
		for (xb = xqi->xqi_xp_globals; NULL != xb; xb = xb->xb_next)
		  {
		    if (!xb->xb_name)
		      sqlr_new_error_xqi_xdl ("XP220", "XI035", xqi, "Variable $%.300s is declared as extern but has no value passed to the query interpreter", name);
		    if (xb->xb_name == name)
		      break;
		  }
              }
            else
              {
		for (xb = xqi->xqi_xp_globals; NULL != xb; xb = xb->xb_next)
		  {
		    if (!xb->xb_name)
		      break;
		    if (xb->xb_name == name)
		      sqlr_new_error_xqi_xdl ("XP220", "XI036", xqi, "non-external variable $%.300s is initialized by external parameter passed to the query interpreter", name);
		  }
		do {
		  NEW_VARZ (xqi_binding_t, new_xb);
		  new_xb->xb_name = uname___empty;
		  new_xb->xb_next = xqi->xqi_xp_globals;
		  xqi->xqi_xp_globals = new_xb;
		  new_xb->xb_name = name;
		  xpf_arg_list_impl (xqi, init_expn, ctx_xe, res_ptr);
		  new_xb->xb_value = res_ptr[0];
		  } while (0);
              }
          }
        END_DO_BOX_FAST;
        xqi_eval (xqi, tree->_.module.body, ctx_xe);
        return;
      }
    default:
      sqlr_new_error_xqi_xdl ("XP420", "XI003", xqi, "Unsupported XPATH operation");
    }
}


int
xi_next_descendant (xp_instance_t * xqi, XT * tree)
{
  int depth = (int) XQI_GET_INT (xqi, tree->_.step.depth);
  xml_entity_t * xe = (xml_entity_t *) XQI_GET (xqi, tree->_.step.iterator);
try_go_down:
  if (XI_RESULT == xe->_->xe_first_child (xe, (XT *) XP_NODE))
    {
      depth++;
      goto test_result;
    }
  if (0 == depth)
    {
      XQI_SET_INT (xqi, tree->_.step.depth, depth);
      return XI_AT_END;
    }
  if (XI_RESULT == xe->_->xe_next_sibling (xe, (XT *) XP_NODE))
    goto test_result;
try_go_up:
  if (XI_AT_END == xe->_->xe_up (xe, (XT *) XP_NODE, XE_UP_MAY_TRANSIT))
    {
      XQI_SET_INT (xqi, tree->_.step.depth, depth);
      return XI_AT_END;
    }
  depth--;
  if (0 == depth)
    {
      XQI_SET_INT (xqi, tree->_.step.depth, depth);
      return XI_AT_END;
    }
  if (XI_AT_END == xe->_->xe_next_sibling (xe, (XT *) XP_NODE))
    goto try_go_up;
test_result:
  if (xe->_->xe_element_name_test (xe, tree->_.step.node))
    {
      XQI_SET_INT (xqi, tree->_.step.depth, depth);
      return XI_RESULT;
    }
  goto try_go_down;
}


int
xi_next_descendant_wr (xp_instance_t * xqi, XT * tree)
{
  int depth = (int) XQI_GET_INT (xqi, tree->_.step.depth);
  xml_entity_t * xe = (xml_entity_t *) XQI_GET (xqi, tree->_.step.iterator);
  xe->xe_doc.xd->xd_top_doc->xd_xqi = xqi;
try_go_down:
  if (XI_RESULT == xe->_->xe_first_child (xe, (XT *) XP_NODE))
    {
      depth++;
      goto test_result;
    }
  if (0 == depth)
    {
      XQI_SET_INT (xqi, tree->_.step.depth, depth);
      return XI_AT_END;
    }
  if (XI_RESULT == xe->_->xe_next_sibling_wr (xe, (XT *) XP_NODE))
    goto test_result;
try_go_up:
  if (XI_AT_END == xe->_->xe_up (xe, (XT *) XP_NODE, XE_UP_MAY_TRANSIT))
    {
      XQI_SET_INT (xqi, tree->_.step.depth, depth);
      return XI_AT_END;
    }
  depth--;
  if (0 == depth)
    {
      XQI_SET_INT (xqi, tree->_.step.depth, depth);
      return XI_AT_END;
    }
  if (XI_AT_END == xe->_->xe_next_sibling_wr (xe, (XT *) XP_NODE))
    goto try_go_up;
test_result:
  if (xe->_->xe_element_name_test (xe, tree->_.step.node))
    {
      XQI_SET_INT (xqi, tree->_.step.depth, depth);
      return XI_RESULT;
    }
  goto try_go_down;
}


void
xe_root (xml_entity_t * xe)
{
  while(XI_AT_END != xe->_->xe_up (xe, (XT *) XP_NODE, XE_UP_MAY_TRANSIT));
}


int
xi_init (xp_instance_t * xqi, XT * tree, xml_entity_t * init)
{
  xml_entity_t * current = NULL;
  int rc;
  ptrlong step_axis = tree->_.step.axis;
  if (DV_XML_ENTITY != DV_TYPE_OF (init)
      && step_axis != XP_SELF)
    {
      if ((IS_STRING_DTP(DV_TYPE_OF (init))) && (1 == box_length (init)))
	return XI_AT_END;	/* an error recovery case for old XSLTs */
      sqlr_new_error_xqi_xdl ("XP001", "XI004", xqi, "Context node is not an entity");
    }
  switch (step_axis)
    {
    case XP_ABS_CHILD:
    case XP_ABS_CHILD_WR:
    case XP_CHILD:
    case XP_CHILD_WR:
      current = init->_->xe_copy (init);
      if (XP_ABS_CHILD == step_axis || XP_ABS_CHILD_WR == step_axis)
	xe_root (current);
      rc = current->_->xe_first_child (current, tree->_.step.node);
      if (XI_AT_END == rc)
	{
	  dk_free_box ((caddr_t) current);
	  return rc;
	}
      XQI_SET (xqi, tree->_.step.iterator, (caddr_t) current);
      return XI_RESULT;
    case XP_ABS_DESC:
    case XP_ABS_DESC_OR_SELF:
    case XP_DESCENDANT:
    case XP_DESCENDANT_OR_SELF:
      current = init->_->xe_copy (init);
      if ((XP_ABS_DESC == step_axis) || (XP_ABS_DESC_OR_SELF == step_axis))
	xe_root (current);
      XQI_SET (xqi, tree->_.step.iterator, (caddr_t) current);
      XQI_SET_INT (xqi, tree->_.step.depth, 0);
      if (((XP_DESCENDANT_OR_SELF == step_axis) || (XP_ABS_DESC_OR_SELF == step_axis)) && (NULL == current->xe_attr_name))
	{
	  if(current->_->xe_ent_name_test (current, tree->_.step.node))
	    {
	      return XI_RESULT;
	    }
	}
      return xi_next_descendant (xqi, tree);
/* IvAn/SmartXContains/001025 Cases added */
    case XP_ABS_DESC_WR:
    case XP_ABS_DESC_OR_SELF_WR:
    case XP_DESCENDANT_WR:
    case XP_DESCENDANT_OR_SELF_WR:
      current = init->_->xe_copy (init);
      if ((XP_ABS_DESC_WR == step_axis) || (XP_ABS_DESC_OR_SELF_WR == step_axis))
	xe_root (current);
      XQI_SET (xqi, tree->_.step.iterator, (caddr_t) current);
      XQI_SET_INT (xqi, tree->_.step.depth, 0);
      if (((XP_DESCENDANT_OR_SELF_WR == step_axis) || (XP_ABS_DESC_OR_SELF_WR == step_axis)) && (NULL == current->xe_attr_name))
	{
	  if(current->_->xe_ent_name_test (current, tree->_.step.node))
	    {
	      return XI_RESULT;
	    }
	}
      return xi_next_descendant_wr (xqi, tree);
    case XP_ROOT:
      current = init->_->xe_copy (init);
      xe_root (current);
      XQI_SET (xqi, tree->_.step.iterator, (caddr_t) current);
      return XI_RESULT;
    case XP_SELF:
      if (DV_TYPE_OF (init) == DV_XML_ENTITY)
	{
	  if (!init->_->xe_ent_name_test (init, tree->_.step.node))
	    return XI_AT_END;
	}

      XQI_SET (xqi, tree->_.step.iterator, box_copy_tree ((caddr_t) init));
      return XI_RESULT;
    case XP_PARENT:
      current = init->_->xe_copy (init);
      rc = current->_->xe_up (current, tree->_.step.node, XE_UP_MAY_TRANSIT);
      if (XI_AT_END == rc)
	{
	  dk_free_box ((caddr_t) current);
	  return rc;
	}
      XQI_SET (xqi, tree->_.step.iterator, (caddr_t) current);
      return XI_RESULT;

    case XP_ANCESTOR:
    case XP_ANCESTOR_OR_SELF:
      XQI_SET (xqi, tree->_.step.iterator, (caddr_t) init->_->xe_copy (init));
      if ((XP_ANCESTOR_OR_SELF == step_axis) && (NULL == init->xe_attr_name))
	{
	  rc = init->_->xe_ent_name_test (init, tree->_.step.node);
          if (rc)
            return XI_RESULT;
	}
      return (xi_next (xqi, tree));
    case XP_ATTRIBUTE:
    case XP_ATTRIBUTE_WR:
      if (xqi->xqi_return_attrs_as_nodes)
	{
	  xml_entity_t *ret = NULL;
	  caddr_t name = NULL;
	  caddr_t value = NULL;
	  rc = init->_->xe_attribute (init, -1, tree->_.step.node, &value, &name);
	  dk_free_tree (value);
	  if (XI_NO_ATTRIBUTE == rc)
	    {
	      dk_free_tree (name);
	      return XI_AT_END;
	    }
	  ret = init->_->xe_copy (init);
	  dk_free_tree (ret->xe_attr_name);
	  ret->xe_attr_name = name;
	  XQI_SET (xqi, tree->_.step.iterator, (caddr_t) ret);
	}
      else
	{
	  rc = init->_->xe_attribute (init, -1,
	      tree->_.step.node, XQI_ADDRESS (xqi, tree->_.step.iterator), NULL);
	  if (XI_NO_ATTRIBUTE == rc)
	    return XI_AT_END;
	}
      XQI_SET (xqi, tree->_.step.init, (caddr_t) init->_->xe_copy (init));
      XQI_SET_INT (xqi, tree->_.step.iter_idx, rc);
      return XI_RESULT;

    case XP_FOLLOWING_SIBLING:
    case XP_PRECEDING_SIBLING:
      current = init->_->xe_copy (init);
      if (XP_FOLLOWING_SIBLING == step_axis)
	rc = current->_->xe_next_sibling (current, tree->_.step.node);
      else
	rc = current->_->xe_prev_sibling (current, tree->_.step.node);
      if (XI_AT_END == rc)
	{
	  dk_free_box ((caddr_t) current);
	  return rc;
	}
      XQI_SET (xqi, tree->_.step.iterator, (caddr_t) current);
      return XI_RESULT;
    case XP_FOLLOWING:
    case XP_PRECEDING:
      current = init->_->xe_copy (init);
      if (XP_FOLLOWING == step_axis)
	rc = current->_->xe_next_sibling (current, tree->_.step.node);
      else
	rc = current->_->xe_prev_sibling (current, tree->_.step.node);
      if (XI_AT_END == rc)
        rc = current->_->xe_up (current, tree->_.step.node,
          (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY |
	    ((XP_FOLLOWING == step_axis) ? XE_UP_SIDEWAY_FWD : 0) ) );
      if (XI_AT_END == rc)
	{
	  dk_free_box ((caddr_t) current);
	  return rc;
	}
      XQI_SET (xqi, tree->_.step.iterator, (caddr_t) current);
      return XI_RESULT;
    case XP_DEREF:
      if (NULL != init->xe_attr_name)
	{

	  unsigned char *idrefs = NULL, *idbegin, *idtail;
	  xe_string_value_1 (init, (caddr_t *)(&idrefs), DV_SHORT_STRING);
	  for (idbegin = idtail = idrefs; /* no step */; /* no step*/)
	    {
	      xml_entity_t *id_owner;
	      while (ecm_utf8props[idbegin[0]] & ECM_ISSPACE)
		idbegin++;
	      if ('\0' == idbegin[0])
		break;
	      idtail = idbegin;
	      while (!(ecm_utf8props[idtail[0]] & (ECM_ISSPACE | ECM_ISZERO)))
		idtail++;
	      id_owner = init->_->xe_deref_id (init, (char *)idbegin, idtail - idbegin);
	      if (NULL != id_owner)
		{
		  XQI_SET (xqi, tree->_.step.iterator, (caddr_t) id_owner);
		  XQI_SET (xqi, tree->_.step.init, (caddr_t) init->_->xe_copy (init));
		  XQI_SET_INT (xqi, tree->_.step.iter_idx, idtail - idrefs);
		  dk_free_box ((caddr_t)idrefs);
		  return XI_RESULT;
		}
	      if ('\0' == idtail[0])
		break;
	      idbegin = idtail;
	    }
	  dk_free_box ((caddr_t)idrefs);
	}
      return XI_AT_END;
    default:
      sqlr_new_error_xqi_xdl ("XP370", "XI005", xqi, "Unsupported XPATH axis");
    }
  return XI_AT_END; /*dummy*/
}


int
xi_next (xp_instance_t * xqi, XT * tree)
{
  int rc;
  ptrlong step_axis = tree->_.step.axis;
  xml_entity_t *init, * xe = NULL;
  switch (step_axis)
    {
    case XP_ROOT:
    case XP_SELF:
    case XP_PARENT:
      return XI_AT_END;
    case XP_ATTRIBUTE:
    case XP_ATTRIBUTE_WR:
    case XP_DEREF:
      break;
    default:
      xe = (xml_entity_t *) XQI_GET (xqi, tree->_.step.iterator);
      if (DV_XML_ENTITY != DV_TYPE_OF (xe))
        sqlr_new_error_xqi_xdl ("XP420", "XI006", xqi, "The value of XPATH step iterator is not an entity");
    }
  switch (step_axis)
    {
    case XP_ABS_CHILD:
    case XP_CHILD:
    case XP_FOLLOWING_SIBLING:
    case XP_PRECEDING_SIBLING:
      if (step_axis == XP_PRECEDING_SIBLING)
	rc = xe->_->xe_prev_sibling (xe, tree->_.step.node);
      else
	rc = xe->_->xe_next_sibling (xe, tree->_.step.node);
      XQI_SET_INT (xqi, tree->_.step.state, rc);
      if (XI_RESULT == rc)
	return rc;
      XQI_SET (xqi, tree->_.step.iterator, NULL);
      return rc;
    case XP_FOLLOWING:
    case XP_PRECEDING:
      if (step_axis == XP_PRECEDING)
	rc = xe->_->xe_prev_sibling (xe, tree->_.step.node);
      else
	rc = xe->_->xe_next_sibling (xe, tree->_.step.node);
      if (XI_AT_END == rc)
        rc = xe->_->xe_up (xe, tree->_.step.node,
          (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY |
	    ((XP_FOLLOWING == step_axis) ? XE_UP_SIDEWAY_FWD : 0) ) );
      XQI_SET_INT (xqi, tree->_.step.state, rc);
      if (XI_RESULT == rc)
	return rc;
      XQI_SET (xqi, tree->_.step.iterator, NULL);
      return rc;

/* IvAn/SmartXContains/001025 Cases added */
    case XP_ABS_CHILD_WR:
    case XP_CHILD_WR:
      xe->xe_doc.xd->xd_top_doc->xd_xqi = xqi;
      rc = xe->_->xe_next_sibling_wr (xe, tree->_.step.node);
      XQI_SET_INT (xqi, tree->_.step.state, rc);
      if (XI_RESULT == rc)
	return rc;
      XQI_SET (xqi, tree->_.step.iterator, NULL);
      return rc;
    case XP_ABS_DESC:
    case XP_ABS_DESC_OR_SELF:
    case XP_DESCENDANT:
    case XP_DESCENDANT_OR_SELF:
      return xi_next_descendant (xqi, tree);
/* IvAn/SmartXContains/001025 Cases added */
    case XP_ABS_DESC_WR:
    case XP_ABS_DESC_OR_SELF_WR:
    case XP_DESCENDANT_WR:
    case XP_DESCENDANT_OR_SELF_WR:
      return (xi_next_descendant_wr (xqi, tree));
/* Never happen
    case XP_ROOT:
    case XP_SELF:
    case XP_PARENT:
      return XI_AT_END;
*/
    case XP_ANCESTOR:
    case XP_ANCESTOR_OR_SELF:
      {
	for (;;)
	  {
	    rc = xe->_->xe_up (xe, (XT *) XP_NODE, XE_UP_MAY_TRANSIT);
	    if (XI_AT_END == rc)
              {
		XQI_SET (xqi, tree->_.step.iterator, NULL);
	        return rc;
	      }
	    if (xe->_->xe_element_name_test (xe, tree->_.step.node))
	      return XI_RESULT;
	  }
      }
    case XP_ATTRIBUTE:
    case XP_ATTRIBUTE_WR:
      {
	init = (xml_entity_t *) XQI_GET (xqi, tree->_.step.init);
	if (xqi->xqi_return_attrs_as_nodes)
	  {
	    xml_entity_t *ret = NULL;
	    caddr_t name = NULL;
	    caddr_t value = NULL;
	    int rc = init->_->xe_attribute (init, (int) XQI_GET_INT (xqi, tree->_.step.iter_idx),
		tree->_.step.node, &value, &name);
	    dk_free_tree (value);
	    if (XI_NO_ATTRIBUTE == rc)
	      {
		dk_free_tree (name);
		return XI_AT_END;
	      }
	    ret = init->_->xe_copy (init);
	    dk_free_tree (ret->xe_attr_name);
	    ret->xe_attr_name = name;
	    XQI_SET (xqi, tree->_.step.iterator, (caddr_t) ret);
	    XQI_SET_INT (xqi, tree->_.step.iter_idx, rc);
	  }
	else
	  {
	    int rc = init->_->xe_attribute (init, (int) XQI_GET_INT (xqi, tree->_.step.iter_idx),
		tree->_.step.node, XQI_ADDRESS (xqi, tree->_.step.iterator), NULL);
	    if (XI_NO_ATTRIBUTE == rc)
	      return XI_AT_END;
	    XQI_SET_INT (xqi, tree->_.step.iter_idx, rc);
	  }
	return XI_RESULT;
      }
    case XP_DEREF:
      init = (xml_entity_t *) XQI_GET (xqi, tree->_.step.init);
      if (NULL != init->xe_attr_name)
	{
	  unsigned char *idrefs = NULL, *idbegin, *idtail;
	  xe_string_value_1 (init, (caddr_t *)(&idrefs), DV_SHORT_STRING);
	  for (idbegin = idtail = idrefs + XQI_GET_INT (xqi, tree->_.step.iter_idx); /* no step */; /* no step*/)
	    {
	      xml_entity_t *id_owner;
	      while (ecm_utf8props[idbegin[0]] & ECM_ISSPACE)
		idbegin++;
	      if ('\0' == idbegin[0])
		break;
	      idtail = idbegin;
	      while (!(ecm_utf8props[idtail[0]] & (ECM_ISSPACE | ECM_ISZERO)))
		idtail++;
	      id_owner = init->_->xe_deref_id (init, (char *)idbegin, idtail - idbegin);
	      if (NULL != id_owner)
		{
		  XQI_SET (xqi, tree->_.step.iterator, (caddr_t) id_owner);
		  XQI_SET_INT (xqi, tree->_.step.iter_idx, idtail - idrefs);
		  dk_free_box ((caddr_t)idrefs);
		  return XI_RESULT;
		}
	      if ('\0' == idtail[0])
		break;
	      idbegin = idtail;
	    }
	  dk_free_box ((caddr_t)idrefs);
	}
      return XI_AT_END;	/* Stub */
    default:
      sqlr_new_error_xqi_xdl ("XP420", "XI007", xqi, "Unsupported XPATH axis");
    }
  return XI_AT_END; /*dummy*/
}


long
box_long_value (caddr_t box)
{
  switch (DV_TYPE_OF (box))
    {
    case DV_LONG_INT:
      return ((long) unbox (box));
    case DV_SINGLE_FLOAT:
      return ((long) unbox_float (box));
    case DV_DOUBLE_FLOAT:
      return ((long) unbox_double (box));
    case DV_NUMERIC:
      {
	int32 n;
	numeric_to_int32 ((numeric_t) box, &n);
	return n;
      }
    case DV_STRING:
      return (atoi (box));
    default:
      return 0;
    }
}


int
xqi_pred_truth_value (xp_instance_t * xqi, XT * pred)
{
  int predicted = xt_predict_returned_type (pred->_.pred.expr);
  switch (predicted)
    {
    case XPDV_BOOL:
    case XPDV_NODESET:
      return (xqi_truth_value (xqi, pred->_.pred.expr));
    default:
      {
	long n = box_long_value (xqi_value (xqi, pred->_.pred.expr, DV_NUMERIC));
	return (XQI_GET_INT (xqi, pred->_.pred.pos) == n);
      }
    }
}


int
xqi_step_next_with_node_set (xp_instance_t * xqi, XT * tree)
{
  xml_entity_t ** node_set = (xml_entity_t **) XQI_GET (xqi, tree->_.step.node_set);
  int node_set_size = (int) XQI_GET_INT (xqi, tree->_.step.node_set_size);
  int node_set_iter = (int) XQI_GET_INT (xqi, tree->_.step.node_set_iter);
  if (node_set_iter < node_set_size)
    {
      XQI_SET (xqi, tree->_.step.iterator, (caddr_t) (node_set [node_set_iter]));
      node_set [node_set_iter] = NULL;
      XQI_SET_INT (xqi, tree->_.step.node_set_iter, node_set_iter + 1);
      XQI_SET_INT (xqi, tree->_.step.state, XI_RESULT);
      return XI_RESULT;
    }
  XQI_SET_INT (xqi, tree->_.step.state, XI_AT_END);
  XQI_SET (xqi, tree->_.step.iterator, NULL);
  return XI_AT_END;
}


int
xqi_step_init_with_node_set (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe)
{
  int node_set_size = 0, inx;
  xml_entity_t * cur;
  xml_entity_t ** node_set = NULL;
  int alloc_size = 8;
  int state = xi_init (xqi, tree, ctx_xe);
  XQI_SET (xqi, tree->_.step.node_set, NULL);
  if (XI_AT_END == state)
    {
      XQI_SET_INT (xqi, tree->_.step.state, state);
      return state;
    }
  node_set = (xml_entity_t **) dk_alloc_box_zero (alloc_size * sizeof (xml_entity_t *), DV_ARRAY_OF_POINTER);
  XQI_SET (xqi, tree->_.step.node_set, (caddr_t)(node_set));
  cur = (xml_entity_t *) XQI_GET (xqi, tree->_.step.iterator);
  node_set[node_set_size++] = cur->_->xe_copy (cur);
  for (;;)
    {
      state = xi_next (xqi, tree);
      if (XI_AT_END == state)
	break;
      if (node_set_size == alloc_size)
	{
	  xml_entity_t ** new_node_set = (xml_entity_t **) dk_alloc_box_zero (2 * alloc_size * sizeof (xml_entity_t *), DV_ARRAY_OF_POINTER);
	  memcpy (new_node_set, node_set, alloc_size * sizeof (xml_entity_t *));
	  XQI_SET_INT (xqi, tree->_.step.node_set, (ptrlong)(new_node_set));
	  dk_free_box ((box_t) node_set);
	  node_set = new_node_set;
	  alloc_size = 2 * alloc_size;
	}
      cur = (xml_entity_t *) XQI_GET (xqi, tree->_.step.iterator);
      node_set[node_set_size++] = cur->_->xe_copy (cur);
    }
  XQI_SET_INT (xqi, tree->_.step.node_set_size, node_set_size);
  XQI_SET_INT (xqi, tree->_.step.node_set_iter, 0);
/* At this point we have a node-set of candidate nodes and we can filter out some of them */
  DO_BOX (XT *, pred, inx, tree->_.step.preds)
    {
      int inx, last_non_filled;
      XQI_SET_INT (xqi, pred->_.pred.size, node_set_size);
      last_non_filled = 0;
      for (inx = 0; inx < node_set_size; inx++)
	{
	  xml_entity_t * cur = node_set [inx];
	  if (pred->_.pred.pos)
	XQI_SET_INT (xqi, pred->_.pred.pos, inx+1);
	  xqi_eval (xqi, pred->_.pred.expr, cur);
	  if (xqi_pred_truth_value (xqi, pred))
	    {
	      if (inx > last_non_filled)
		{
		  node_set [last_non_filled] = cur;
		  node_set [inx] = NULL;
		}
	      last_non_filled++;
	    }
	  else
	    {
	      dk_free_tree ((caddr_t) cur);
	      node_set [inx] = NULL;
	    }
	}
      node_set_size = last_non_filled;
      XQI_SET_INT (xqi, tree->_.step.node_set_size, node_set_size);
      if (0 == node_set_size)
	break;
    }
  END_DO_BOX;
  if (0 == node_set_size)
    return XI_AT_END;
  return (xqi_step_next_with_node_set (xqi, tree));
}


/* 0 = passed
   1 = failed
   2 = failed and all next tries will fail
*/
int xqi_pred_failed (xp_instance_t * xqi, XT * pred, xml_entity_t * current)
{
  int predicted;
  XT *pred_expr = pred->_.pred.expr;
  if (pred->_.pred.pos)
    XQI_SET_INT (xqi, pred->_.pred.pos, XQI_GET_INT (xqi, pred->_.pred.pos) + 1);
  xqi_eval (xqi, pred_expr, current);
  predicted = xt_predict_returned_type (pred_expr);
  if ((XPDV_BOOL == predicted) || (XPDV_NODESET == predicted))
    {
      if (!xqi_truth_value (xqi, pred_expr))
	return 1;
    }
  else
    {
      int pos_slot = (int) pred->_.pred.pos;
      caddr_t val;
      long pos;
      if (!pos_slot)
	return 0;
      pos = (long) XQI_GET_INT (xqi, pos_slot);
      val = xqi_raw_value (xqi, pred_expr);
      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val))
	{
	  long maxpos = -1;
	  size_t subvalctr = BOX_ELEMENTS(val);
	  while (subvalctr--)
	    {
	      long n = box_long_value (((caddr_t *)val)[subvalctr]);
	      if (n > maxpos)
	        maxpos = n;
	      if (pos == n)
		return 0;
	    }
	if (pos < maxpos)
          return 1;
	return 2;
	}
      else
	{
	  long n = box_long_value (xqi_value (xqi, pred_expr, DV_NUMERIC));
	  if (pos < n)
            return 1;
	  if (pos > n)
	    return 2;
        }
    }
  return 0;
}

int
xqi_step_next (xp_instance_t * xqi, XT * tree, int is_initial)
{
  int inx;
  if (tree->_.step.preds_use_size)
    {
      return (xqi_step_next_with_node_set (xqi, tree));
    }
 next:
  {
    xml_entity_t * current = NULL;
    int rc = is_initial ? XI_RESULT : xi_next (xqi, tree);
    is_initial = 0;
    XQI_SET_INT (xqi, tree->_.step.state, rc);
    if (XI_AT_END == rc)
      return rc;
    current = (xml_entity_t *) XQI_GET (xqi, tree->_.step.iterator);
    DO_BOX (XT *, pred, inx, tree->_.step.preds)
      {
	int res = xqi_pred_failed (xqi, pred, current);
	switch (res)
	  {
	  case 1:
	    goto next;
	  case 2:
	    XQI_SET_INT (xqi, tree->_.step.state, XI_AT_END);
	    return XI_AT_END;
	  }
      }
    END_DO_BOX;
    XQI_SET_INT (xqi, tree->_.step.state, XI_RESULT);
    return XI_RESULT;
  }
}


int
xqi_step_init (xp_instance_t * xqi, XT * tree, xml_entity_t * init)
{
  int inx;
  if (tree->_.step.preds_use_size)
    return (xqi_step_init_with_node_set (xqi, tree, init));
  DO_BOX (XT *, pred, inx, tree->_.step.preds)
    {
      if (pred->_.pred.pos)
	XQI_SET_INT (xqi, pred->_.pred.pos, 0);
    }
  END_DO_BOX;
  XQI_SET_INT (xqi, tree->_.step.state, xi_init (xqi, tree, init));
  if (XI_RESULT == XQI_GET_INT (xqi, tree->_.step.state))
    XQI_SET_INT (xqi, tree->_.step.state, xqi_step_next (xqi, tree, 1));
  return ((int) XQI_GET_INT (xqi, tree->_.step.state));
}


xml_entity_t *
xqi_current (xp_instance_t * xqi, XT * tree)
{
  switch (tree->type)
    {
    case XP_STEP:
      return ((xml_entity_t *) XQI_GET (xqi, tree->_.step.iterator));
    case XP_FILTER:
      return (xqi_current (xqi, tree->_.filter.path));
    case XP_UNION:
      return ((xml_entity_t *) XQI_GET (xqi, tree->_.xp_union.res));
    case XP_VARIABLE:
    case XP_FAKE_VAR:
      {
	int state = (int) XQI_GET_INT (xqi, tree->_.var.state);
	caddr_t init = XQI_GET (xqi, tree->_.var.init);
	if (DV_ARRAY_OF_XQVAL != DV_TYPE_OF(init))
	  return (xml_entity_t *) init;
	if (XI_RESULT == state)
	  return ((xml_entity_t *) XQI_GET (xqi, tree->_.var.res));
	return NULL;
      }
    case CALL_STMT:
      if (tree->_.xp_func.var)
	return (xqi_current (xqi, tree->_.xp_func.var));
      return NULL;
    case XQ_FOR_SQL:
      return ((xml_entity_t *) XQI_GET (xqi, tree->_.xq_for_sql.current));
    }
  return NULL; /*dummy */
}


int
xe_compare_logical_paths (ptrlong *lp_A, size_t lp_A_len, ptrlong *lp_B, size_t lp_B_len)
{
  size_t idx;
  ptrlong p_A, p_B;
  if (lp_A[0] != lp_B[0])
    return ((lp_A[0] < lp_B[0]) ? XE_CMP_A_DOC_LT_B : XE_CMP_A_DOC_GT_B);
  for (idx = 1; /*no check*/ ;idx++)
    {
      if (idx >= lp_A_len)
	return ((idx >= lp_B_len) ? XE_CMP_A_IS_EQUAL_TO_B : XE_CMP_A_IS_ANCESTOR_OF_B);
      if (idx >= lp_B_len)
	return XE_CMP_A_IS_DESCENDANT_OF_B;
      p_A = lp_A[idx];
      p_B = lp_B[idx];
      if (p_A < p_B)
	return XE_CMP_A_IS_BEFORE_B;
      if (p_A > p_B)
	return XE_CMP_A_IS_AFTER_B;
    }
}


int
xqi_next (xp_instance_t * xqi, XT * tree)
{
  int rc;
  switch (tree->type)
    {
    case XP_VARIABLE:
    case XP_FAKE_VAR:
      {
	int state = (int) XQI_GET_INT (xqi, tree->_.var.state);
	caddr_t * set = (caddr_t *) XQI_GET (xqi, tree->_.var.init);
	if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF(set))
	  {
	    int len = BOX_ELEMENTS (set);
	    int inx = (int) XQI_GET_INT (xqi, tree->_.var.inx);
	    if (inx >= len)
	      {
		XQI_SET_INT (xqi, tree->_.var.state, XI_AT_END);
		return XI_AT_END;
	      }
	    XQI_SET (xqi, tree->_.var.res, box_copy_tree (set[inx]));
	    XQI_SET_INT (xqi, tree->_.var.inx, inx + 1);
	    XQI_SET_INT (xqi, tree->_.var.state, XI_RESULT);
	    return XI_RESULT;
	  }
	else
	  {
	    if (XI_INITIAL == state)
	      {
		XQI_SET (xqi, tree->_.var.res, box_copy_tree (XQI_GET (xqi, tree->_.var.init)));
		XQI_SET_INT (xqi, tree->_.var.state, XI_RESULT);
	      }
	    else
	      XQI_SET_INT (xqi, tree->_.var.state, XI_AT_END);
	    return ((int) XQI_GET_INT (xqi, tree->_.var.state));
	  }
      }
    case CALL_STMT:
      if (!tree->_.xp_func.var)
	return XI_AT_END;
      return (xqi_next (xqi, tree->_.xp_func.var));
    case XP_STEP:
      {
	int state = (int) XQI_GET_INT (xqi, tree->_.step.state);
	xml_entity_t * init = (xml_entity_t *) XQI_GET (xqi, tree->_.step.init);
	if (XI_AT_END == state)
	  return XI_AT_END;
	if (XI_INITIAL == state)
	  {
	    if (!tree->_.step.input)
	      return (xqi_step_init (xqi, tree, init));
	    else
	      {
		rc = xqi_next (xqi, tree->_.step.input);

		if (XI_AT_END == rc)
		  {
		    XQI_SET_INT (xqi, tree->_.step.state, rc);
		    return rc;
		  }
	      }
	    rc = xqi_step_init (xqi, tree, xqi_current (xqi, tree->_.step.input));
	    if (XI_RESULT == rc)
	      return rc;
	    if (tree->_.step.input)
	      {
		for (;;)
		  {
		    rc = xqi_next (xqi, tree->_.step.input);
		    if (XI_AT_END == rc)
		      return rc;
		    rc = xqi_step_init (xqi, tree, xqi_current (xqi, tree->_.step.input));
		    if (XI_RESULT == rc)
		      return rc;
		  }
	      }
	  }
	if (XI_RESULT == state)
	  {
	    rc = xqi_step_next (xqi, tree, 0);
	    if (XI_RESULT == rc)
	      return rc;
	    if (!tree->_.step.input)
	      return XI_AT_END;

	    for (;;)
	      {
		rc = xqi_next (xqi, tree->_.step.input);
		if (XI_AT_END == rc)
		  return rc;
		rc = xqi_step_init (xqi, tree, xqi_current (xqi, tree->_.step.input));
		if (XI_RESULT == rc)
		  return rc;
	      }
	  }
      }
    case XP_FILTER:
      for (;;)
	{
	  xml_entity_t * current;
	  XT * pred = tree->_.filter.pred;
	  int rc = xqi_next (xqi, tree->_.filter.path);
	  int pred_res;
	  if (XI_AT_END == rc)
	    {
	      XQI_SET_INT (xqi, tree->_.filter.state, rc);
	      return rc;
	    }
	  current = xqi_current (xqi, tree->_.filter.path);
	  pred_res = xqi_pred_failed (xqi, pred, current);
	  switch (pred_res)
	    {
	    case 1: continue;
	    case 0: break;
	    case 2:
	      XQI_SET_INT (xqi, tree->_.filter.state, XI_AT_END);
	      return XI_AT_END;
	    }
	  break;
	}
      XQI_SET_INT (xqi, tree->_.filter.state, XI_RESULT);
      return XI_RESULT;
    case XP_UNION:
      {
	xml_entity_t *left_node, *right_node;
	caddr_t left_lp, right_lp;
	caddr_t new_left_lp, new_right_lp;
	int rc;

	XQI_SET_INT (xqi, tree->_.xp_union.state, XI_RESULT);
	if (!xqi_is_value (xqi, tree->_.xp_union.left))
	  {
	    if (!xqi_is_value (xqi, tree->_.xp_union.right))
	      XQI_SET_INT (xqi, tree->_.xp_union.state, XI_AT_END);
	    else
	      XQI_SET (xqi, tree->_.xp_union.res, box_copy_tree (xqi_raw_value (xqi, tree->_.xp_union.right)));
	    XQI_SET (xqi, tree->_.xp_union.right_lpath, NULL);
	    xqi_is_next_value (xqi, tree->_.xp_union.right);
	    return (int) XQI_GET_INT (xqi, tree->_.xp_union.state);
	  }
	if (!xqi_is_value (xqi, tree->_.xp_union.right))
	  {
	    XQI_SET (xqi, tree->_.xp_union.res, box_copy_tree (xqi_raw_value (xqi, tree->_.xp_union.left)));
	    XQI_SET (xqi, tree->_.xp_union.left_lpath, NULL);
	    xqi_is_next_value (xqi, tree->_.xp_union.left);
	    return (int) XQI_GET_INT (xqi, tree->_.xp_union.state);
	  }
	left_node = (xml_entity_t *)xqi_raw_value (xqi, tree->_.xp_union.left);
	right_node = (xml_entity_t *)xqi_raw_value (xqi, tree->_.xp_union.right);
	if (DV_TYPE_OF (left_node) != DV_XML_ENTITY)
	  sqlr_new_error_xqi_xdl ("42000", "XI008", xqi, "The value of the left argument of union operator is not a node-set");
	if (DV_TYPE_OF (left_node) != DV_XML_ENTITY || DV_TYPE_OF (right_node) != DV_XML_ENTITY)
	  sqlr_new_error_xqi_xdl ("42000", "XI008", xqi, "The value of the right argument of union operator is not a node-set");
	left_lp = XQI_GET (xqi, tree->_.xp_union.left_lpath);
	if (NULL == left_lp)
	  {
	    dk_set_t path = NULL;
	    left_node->_->xe_get_logical_path (left_node, &path);
	    new_left_lp = left_lp = (caddr_t)dk_set_to_array (path);
	    dk_set_free (path);
	    box_tag_modify (left_lp, DV_ARRAY_OF_LONG);
	  }
	else
	  new_left_lp = NULL;
	right_lp = XQI_GET (xqi, tree->_.xp_union.right_lpath);
	if (NULL == right_lp)
	  {
	    dk_set_t path = NULL;
	    right_node->_->xe_get_logical_path (right_node, &path);
	    new_right_lp = right_lp = (caddr_t)dk_set_to_array (path);
	    dk_set_free (path);
	    box_tag_modify (right_lp, DV_ARRAY_OF_LONG);
	  }
	else
	  new_right_lp = NULL;
        rc = xe_compare_logical_paths ((ptrlong *)left_lp, BOX_ELEMENTS(left_lp), (ptrlong *)right_lp, BOX_ELEMENTS(right_lp));
	if (!rc)
	  {
	    caddr_t lattr = left_node->xe_attr_name;
	    caddr_t rattr = right_node->xe_attr_name;
	    rc = ((NULL == lattr) ?
	     ((NULL == rattr) ? 0 : -1) :
	     ((NULL == rattr) ? 1 : strcmp (lattr, rattr)) );
	  }
	if (!rc)
	  {
	    dk_free_box (new_left_lp);
	    dk_free_box (new_right_lp);
	    XQI_SET (xqi, tree->_.xp_union.res, box_copy_tree ((box_t) left_node));
	    XQI_SET (xqi, tree->_.xp_union.left_lpath, NULL);
	    XQI_SET (xqi, tree->_.xp_union.right_lpath, NULL);
	    xqi_is_next_value (xqi, tree->_.xp_union.left);
	    xqi_is_next_value (xqi, tree->_.xp_union.right);
	    return (int) XQI_GET_INT (xqi, tree->_.xp_union.state);
	  }
	else if (rc < 0)
	  {
	    dk_free_box (new_left_lp);
	    if (NULL != new_right_lp)
	      XQI_SET (xqi, tree->_.xp_union.right_lpath, new_right_lp);
	    XQI_SET (xqi, tree->_.xp_union.res, box_copy_tree ((box_t) left_node));
	    XQI_SET (xqi, tree->_.xp_union.left_lpath, NULL);
	    xqi_is_next_value (xqi, tree->_.xp_union.left);
	    return (int) XQI_GET_INT (xqi, tree->_.xp_union.state);
	  }
	else
	  {
	    dk_free_box (new_right_lp);
	    if (NULL != new_left_lp)
	      XQI_SET (xqi, tree->_.xp_union.left_lpath, new_left_lp);
	    XQI_SET (xqi, tree->_.xp_union.res, box_copy_tree ((box_t) right_node));
	    XQI_SET (xqi, tree->_.xp_union.right_lpath, NULL);
	    xqi_is_next_value (xqi, tree->_.xp_union.right);
	    return (int) XQI_GET_INT (xqi, tree->_.xp_union.state);
	  }
      }
    case XQ_FOR_SQL:
      {
        caddr_t xml_tree = NULL;
        local_cursor_t * lc = (local_cursor_t *) XQI_GET_INT (xqi, tree->_.xq_for_sql.lc);
        if (lc_next (lc))
          {
            int inx = (int) XQI_GET_INT (xqi, tree->_.xq_for_sql.inx);
	    xml_tree = lc_nth_col (lc, 0); /*  ??*/
	    XQI_SET (xqi, tree->_.xq_for_sql.current, box_copy_tree (xml_tree));
	    XQI_SET_INT (xqi, tree->_.xq_for_sql.inx, inx + 1);
	    XQI_SET_INT (xqi, tree->_.xq_for_sql.lc_state, XI_RESULT);
	    return XI_RESULT;
          }
        else
          {
            XQI_SET_INT (xqi, tree->_.xq_for_sql.lc_state, XI_AT_END);
	    return XI_AT_END;
          }
      }
    }
  return XI_AT_END; /* dummy */
}


int xe_are_equal (xml_entity_t *this_xe, xml_entity_t *that_xe)
{
  xml_entity_t * this_iter, *that_iter;
  int this_rc, that_rc;
  int res;
  if (!xe_have_equal_heads (this_xe, that_xe))
    return 0;
  this_iter = this_xe->_->xe_copy (this_xe);
  that_iter = that_xe->_->xe_copy (that_xe);
  this_rc = this_iter->_->xe_first_child (this_iter, (XT *) XP_NODE);
  that_rc = that_iter->_->xe_first_child (that_iter, (XT *) XP_NODE);
  while ((XI_AT_END != this_rc) && (XI_AT_END != that_rc))
    {
      if (!xe_are_equal (this_iter, that_iter))
	break;
      this_rc = this_iter->_->xe_next_sibling (this_iter, (XT *) XP_NODE);
      that_rc = that_iter->_->xe_next_sibling (that_iter, (XT *) XP_NODE);
    }
  res = ((XI_AT_END == this_rc) && (XI_AT_END == that_rc));
  dk_free_box ((box_t) this_iter);
  dk_free_box ((box_t) that_iter);
  return res;
}


ptrlong xe_equal_fingerprint (xml_entity_t *xe)
{
  ptrlong res = 5 * xe_equal_heads_fingerprint(xe);
  xml_entity_t *iter = xe->_->xe_copy (xe);
  int rc = iter->_->xe_first_child (iter, (XT *) XP_NODE);
  while (XI_AT_END != rc)
    {
      res *= 3;
      res += xe_equal_fingerprint (iter);
      rc = iter->_->xe_next_sibling (iter, (XT *) XP_NODE);
    }
  dk_free_box ((box_t) iter);
  return res;
}


int xe_have_equal_heads (xml_entity_t *this_xe, xml_entity_t *that_xe)
{
  int res;
  if (NULL != this_xe->xe_attr_name)
    {
      caddr_t name, this_val, that_val;
      if (NULL == that_xe->xe_attr_name)
	return 0;
      name = this_xe->xe_attr_name;
      if (name != that_xe->xe_attr_name)
	return 0;
      this_val = this_xe->_->xe_currattrvalue (this_xe);
      that_val = that_xe->_->xe_currattrvalue (that_xe);
      res = (0 == strcmp (this_val, that_val));
      dk_free_box (this_val);
      dk_free_box (that_val);
    }
  else
    {
      int that_attr_ctr;
      int rc;
      int is_text;
      caddr_t this_name, that_name, this_value, that_value;
      id_hash_t *attrs;
      if (NULL != that_xe->xe_attr_name)
	return 0;
      this_name = this_xe->_->xe_element_name(this_xe);
      that_name = that_xe->_->xe_element_name(that_xe);
      if (this_name != that_name)
	{
	  dk_free_box (this_name);
	  dk_free_box (that_name);
	  return 0;
	}
      is_text = (uname__txt == this_name);
      dk_free_box (this_name);
      dk_free_box (that_name);
      if (is_text)
	{
	  this_value = that_value = NULL;
	  this_xe->_->xe_string_value (this_xe, &this_value, DV_LONG_STRING);
	  that_xe->_->xe_string_value (that_xe, &that_value, DV_LONG_STRING);
	  res = !strcmp (this_value, that_value);
	  dk_free_box (this_value);
	  dk_free_box (that_value);
	  return res;
	}
      attrs = (id_hash_t *) box_dv_dict_hashtable(31);
/* First we should populate the hashtable by attributes from this_xe */
      for (rc = -1; /* no check*/; /*no step*/)
	{
	  this_name = this_value = NULL;
	  rc = this_xe->_->xe_attribute (this_xe, rc, (XT *) XP_NODE, &this_value, &this_name);
	  if (XI_NO_ATTRIBUTE == rc)
	    break;
	  id_hash_set (attrs, (caddr_t)(&this_name), (caddr_t)(&this_value));
	}
/* Now we should compare the content of the hashtable with attributes from that_xe */
      that_attr_ctr = 0;
      for (rc = -1; /* no check*/; /*no step*/)
	{
	  caddr_t *prev_value;
	  that_name = that_value = NULL;
	  rc = that_xe->_->xe_attribute (that_xe, rc, (XT *) XP_NODE, &that_value, &that_name);
	  if (XI_NO_ATTRIBUTE == rc)
	    break;
	  that_attr_ctr++;
	  prev_value = (caddr_t *)id_hash_get (attrs, (caddr_t)(&that_name));
	  dk_free_box (that_name);
	  if ((NULL == prev_value) || strcmp (prev_value[0], that_value))
	    {
	      res = 0;
	      dk_free_box (that_value);
	      goto cleanup;
	    }
	  dk_free_box (that_value);
	}
      res = (attrs->ht_inserts == that_attr_ctr);
cleanup:
      dk_free_box ((box_t) attrs);
    }
  return res;
}


ptrlong xe_equal_heads_fingerprint (xml_entity_t *xe)
{
  ptrlong res;
  if (NULL != xe->xe_attr_name)
    {
      caddr_t val = xe->_->xe_currattrvalue(xe);
      res = 0x11111111;
      res += (ptrlong)(xe->xe_attr_name);
      res *= 5;
      res += strhash ((caddr_t)(&val));
      dk_free_box (val);
    }
  else
    {
      int rc;
      int is_text;
      caddr_t name, value;
      res = 0x22222222;
      name = xe->_->xe_element_name(xe);
      res += (ptrlong)name;
      res *= 5;
      is_text = (uname__txt == name);
      dk_free_box (name);
      if (is_text)
	{
	  value = NULL;
	  xe->_->xe_string_value (xe, &value, DV_LONG_STRING);
	  res += strhash ((caddr_t)(&value));
	  dk_free_box (value);
	  return res;
	}
      for (rc = -1; /* no check*/; /*no step*/)
	{
	  name = value = NULL;
	  rc = xe->_->xe_attribute (xe, rc, (XT *) XP_NODE, &value, &name);
	  if (XI_NO_ATTRIBUTE == rc)
	    return res;
	  res += 3*strhash((caddr_t)(&name)) + strhash((caddr_t)(&value));
	  dk_free_box (name);
	  dk_free_box (value);
	}
   }
  return res;
}


xp_instance_t *
xqr_instance (xp_query_t * xqr, query_instance_t * qi)
{
  int n_slots = xqr->xqr_n_slots;
  xp_instance_t * xqi = (xp_instance_t *)
      dk_alloc_box (xqr->xqr_instance_length + sizeof (ptrlong) * n_slots, DV_XQI);
  memset (xqi, 0, xqr->xqr_instance_length);
  xqi->xqi_qi = qi;
  xqi->xqi_xqr = xqr;
  memcpy (((caddr_t) xqi) + xqr->xqr_instance_length, xqr->xqr_slots, sizeof (ptrlong) * n_slots);
  xqi->xqi_n_slots = n_slots;
  xqi->xqi_slot_map_offset = xqr->xqr_instance_length;
  return xqi;
}


int
xqi_destroy (caddr_t xx)
{
  int inx;
#ifdef XPATH_DEBUG
  int inx2;
#endif
  xp_instance_t * xqi = (xp_instance_t *) xx;
  xqi_binding_t *xb = xqi->xqi_internals;
  ptrlong * map = (ptrlong *) ((ptrlong) xqi + xqi->xqi_slot_map_offset);
  for (inx = 0; inx < xqi->xqi_n_slots; inx++)
    {
      caddr_t val = XQI_GET (xqi, map[inx]);
#ifdef XPATH_DEBUG
      if (IS_BOX_POINTER(val) && (DV_UNAME != DV_TYPE_OF (val)))
	{
	  for (inx2 = inx+1; inx2 < xqi->xqi_n_slots; inx2++)
	    {
	      if (XQI_GET (xqi, map[inx2]) == val)
		GPF_T;
	    }
	}
#endif
      dk_free_tree (val);
    }
  while (NULL != xb)
    {
      xqi_binding_t *next = xb->xb_next;
      dk_free_tree (xb->xb_value);
      dk_free (xb, sizeof (xqi_binding_t));
      xb = next;
    }
  if ((NULL != xqi->xqi_doc_cache) && (&(xqi->xqi_doc_cache) == xqi->xqi_doc_cache->xdc_owner))
    xml_doc_cache_free (xqi->xqi_doc_cache);
  return 0;
}


int
xqr_release (caddr_t xx)
{
  xp_query_t * xqr = (xp_query_t *) xx;
  if (NULL != xqr->xqr_shuric)
    {
      shuric_release (xqr->xqr_shuric);
      return 1;
    }
  dk_set_free (xqr->xqr_state_map);
  dk_free_box ((caddr_t) xqr->xqr_slots);
#ifndef NDEBUG
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree ((caddr_t) xqr->xqr_tree);
#endif
#if 0
  if (stdout)
    dk_debug_dump_box (stdout, (caddr_t) xqr->xqr_tree, 20);
#endif
#endif
#ifdef DEBUG
  dk_check_tree ((caddr_t) xqr->xqr_tree);
#endif
  dk_free_tree ((caddr_t) xqr->xqr_tree);
  dk_free_tree ((caddr_t) xqr->xqr_key);
  dk_free_tree ((caddr_t) xqr->xqr_xml_parser_cfg);
  dk_free_tree ((caddr_t) xqr->xqr_base_uri);
#ifndef EXTERNAL_XDLS
  dk_free_box (xqr->xqr_xdl.xdl_attribute);
  dk_free_box (xqr->xqr_xdl.xdl_element);
  dk_free_box (xqr->xqr_xdl.xdl_line);
  dk_free_box (xqr->xqr_xdl.xdl_file);
#endif
  box_tag_modify (xqr, DV_NULL);
  return 0;
}


caddr_t
xqr_addref (caddr_t xx)
{
  xp_query_t * xqr = (xp_query_t *) xx;
  if (NULL == xqr->xqr_shuric)
    {
      NEW_VARZ (shuric_t, shu);
      shu->_ = &shuric_vtable__xqr;
      shu->shuric_data = xqr;
      shu->shuric_ref_count = 2;
    }
  else
    shuric_lock (xqr->xqr_shuric);
  return xx;
}


caddr_t
xqr_clone (caddr_t xx)
{
  xp_query_t * xqr = (xp_query_t *) xx;
  xp_query_t * copy = (xp_query_t*) dk_alloc_box (sizeof (xp_query_t), DV_XPATH_QUERY);
  memcpy (copy, xqr, sizeof (xp_query_t));
  copy->xqr_shuric = NULL;
  copy->xqr_state_map = dk_set_copy (xqr->xqr_state_map);
  copy->xqr_tree = (XT*) box_copy_tree ((caddr_t) xqr->xqr_tree);
  copy->xqr_slots = (ptrlong *) box_copy ((box_t) xqr->xqr_slots);
  copy->xqr_key = box_copy_tree (xqr->xqr_key);
  copy->xqr_xml_parser_cfg = box_copy_tree (xqr->xqr_xml_parser_cfg);
  copy->xqr_base_uri = box_copy (xqr->xqr_base_uri);
#ifdef EXTERNAL_XDLS
  memset (&(copy->xqr_xdl), 0, sizeof (xp_debug_location_t));	/* Location is not copied for safety */
#else
  copy->xqr_xdl.xdl_attribute = box_copy (xqr->xqr_xdl.xdl_attribute);
  copy->xqr_xdl.xdl_element = box_copy (xqr->xqr_xdl.xdl_element);
  copy->xqr_xdl.xdl_line = box_copy (xqr->xqr_xdl.xdl_line);
  copy->xqr_xdl.xdl_file = box_copy (xqr->xqr_xdl.xdl_file);
#endif
  return ((caddr_t) copy);
}


void
xqr_serialize (xp_query_t * xqr, dk_session_t * ses)
{
  caddr_t text = xqr->xqr_key;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (text)) /* If key is not a plain text but text plus namespace decls */
    text = ((caddr_t *)text)[0];
  if (text)
    print_string (text, ses);
  else
    print_int (0, ses);
}


caddr_t
bif_xpath_text (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xp_query_t * xqr = NULL;
  caddr_t str = bif_string_arg (qst, args, 0, "xpath_text");
  caddr_t err = NULL;
  caddr_t * text_xp = NULL;
  xqr = xp_query_parse (((query_instance_t *) qst), str, 'x' /* like xcontains */, &err, &xqre_default);
  if (err)
    sqlr_resignal (err);
  text_xp = xpt_text_exp (xqr->xqr_tree, NULL);
  dk_free_box ((caddr_t)xqr);
  return ((caddr_t)text_xp);
}


int
snprint_xdl (char *buffer, size_t buflength, xp_debug_location_t *xdl)
{
  int res = 0;
  int item_len;
  if (NULL == xdl)
    return res;
  if (0 == buflength)
    return res;
  if (NULL != xdl->xdl_attribute)
    {
      item_len = snprintf (buffer, buflength, " in attribute %.300s",
	xdl->xdl_attribute );
      res += item_len;
      buffer += item_len;
      buflength -= item_len;
    }
  if (0 == buflength)
    return res;
  if (NULL != xdl->xdl_element)
    {
      item_len = snprintf (buffer, buflength, " %.10s tag %.300s",
	((NULL != xdl->xdl_attribute) ? "of" : "in"),
	xdl->xdl_element );
      res += item_len;
      buffer += item_len;
      buflength -= item_len;
    }
  if (0 == buflength)
    return res;
  if (0 != xdl->xdl_line)
    {
      item_len = snprintf (buffer, buflength, " in line " BOXINT_FMT,
#ifdef EXTERNAL_XDLS
	(boxint)(xdl->xdl_line)
#else
	unbox (xdl->xdl_line)
#endif
 );
      res += item_len;
      buffer += item_len;
      buflength -= item_len;
    }
  if (0 == buflength)
    return res;
  if (NULL != xdl->xdl_file)
    {
      item_len = snprintf (buffer, buflength, " %.10s file %.300s",
	((0 != xdl->xdl_line) ? "of" : "in"),
	xdl->xdl_file );
      res += item_len;
      buffer += item_len;
      buflength -= item_len;
    }
  return res;
}


void
bif_xquery_arg (caddr_t * qst, state_slot_t ** args, int main_arg_inx, int cache_ssl_inx, int key2, const char *func, const char *keyname, caddr_t *str_ret, int *str_is_temp_ret, xml_entity_t **ent_ret, xp_query_t **xqr_ret)
{
  caddr_t arg = bif_arg (qst, args, main_arg_inx, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  xml_entity_t *xe;
  str_ret[0] = NULL;
  str_is_temp_ret[0] = 0;
  ent_ret[0] = NULL;
  xqr_ret[0] = NULL;
  switch (dtp)
    {
    case DV_XPATH_QUERY:
      xqr_ret[0] = (xp_query_t *)arg;
      return;
    case DV_STRING:
      str_ret[0] = arg;
      break;
    case DV_XML_ENTITY:
      ent_ret[0] = xe = (xml_entity_t *)arg;
      if (NULL != xe->xe_attr_name)
        {
          caddr_t attrvalue = xe->_->xe_currattrvalue (xe);
          dtp_t valdtp = DV_TYPE_OF (attrvalue);
          if (DV_XPATH_QUERY == valdtp)
            {
              xqr_ret[0] = (xp_query_t *)attrvalue;
              return;
            }
          if (DV_STRING == valdtp)
            {
              str_ret[0] = attrvalue;
              return;
            }
	  sqlr_new_error ("22023", "SR014",
            "Function %.200s needs %.200s as argument %d, not a special attribute XML entity '%s'", func, keyname, main_arg_inx + 1, xe->xe_attr_name);
        }
      xe->_->xe_string_value (xe, str_ret, DV_STRING);
      str_is_temp_ret[0] = 1;
      break;
    default:
      sqlr_new_error ("22023", "SR014",
        "Function %.200s needs %.200s (either source or compiled, string or an XML entity) as argument %d, not an arg of type %s (%d)",
        func, keyname, main_arg_inx + 1, dv_type_title (dtp), dtp);
    }
  if (cache_ssl_inx)
    {
      caddr_t *cached_pair = (caddr_t *)(qst[cache_ssl_inx]);
      xp_query_t *cached_xqr;
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (cached_pair))
        return;
      if (key2 >= 0)
        {
          if (3 != BOX_ELEMENTS (cached_pair))
            return;
          if (DV_LONG_INT != DV_TYPE_OF (cached_pair[2]))
            return;
          if (key2 != unbox (cached_pair[2]))
      return;
    }
      else
    {
          if (2 != BOX_ELEMENTS (cached_pair))
            return;
        }
      if (DV_XPATH_QUERY != DV_TYPE_OF (cached_pair[0]))
        return;
      if (DV_STRING != DV_TYPE_OF (cached_pair[1]))
        return;
      if (strcmp (str_ret[0], cached_pair[1]))
        return;
      cached_xqr = (xp_query_t *)(cached_pair[0]);
      if ((NULL != cached_xqr->xqr_shuric) && cached_xqr->xqr_shuric->shuric_is_stale)
        return;
      str_ret[0] = NULL;
      str_is_temp_ret[0] = 0;
      xqr_ret[0] = cached_xqr;
      return;
    }
}


#define XQI_FREE_XP_GLOBALS(xqi) \
  do { \
        xqi_binding_t *xb = xqi->xqi_xp_globals; \
	while (NULL != xb) \
	  { \
	    xqi_binding_t *next = xb->xb_next; \
	    dk_free_tree (xb->xb_value); \
	    dk_free (xb, sizeof (xqi_binding_t)); \
	    xb = next; \
	  } \
      } while (0)

long
bif_var_ssl_idx_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *funname)
{
  query_instance_t *qi = (query_instance_t *)qst;
  long ssl_idx = bif_long_arg (qst, args, nth, funname);
  if (((ssl_idx * sizeof (caddr_t)) >= qi->qi_query->qr_instance_length) ||
    (ssl_idx < (sizeof (query_instance_t) / sizeof (caddr_t))) )
    sqlr_new_error ("22023", "SR643", "Incorrect state slot number argument, probably internal SQL compiler error");
  return ssl_idx;
}

caddr_t
xpath_or_xquery_eval (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, const char *funname, ptrlong predicate_type, int with_cache)
{
  volatile int v_inx = 1;
  int first;
  dk_set_t set = NULL;
  volatile caddr_t val = NULL;
  caddr_t str;
  int str_is_temp;
  xml_entity_t *xqr_text_ent;
  shuric_cache_t *shu_cache;
  xp_query_env_t xqre;
  xp_query_t * xqr, *xqr_to_release = NULL;
  query_instance_t * qi = (query_instance_t *) qst;
  xml_entity_t * ent = bif_entity_arg (qst, args, 1, funname);
  size_t argcount = BOX_ELEMENTS (args);
  long cache_ssl_idx = (with_cache ? bif_var_ssl_idx_arg (qst, args, --argcount, funname) : 0);
  volatile long nth_res = (argcount > 2) ? (long) bif_long_arg (qst, args, 2, funname) : 1;
  caddr_t * params = (argcount > 3) ? (caddr_t *) bif_array_or_null_arg (qst, args, 3, funname) : NULL;
  caddr_t err = NULL;
  xp_instance_t * xqi;
  bif_xquery_arg (qst, args, 0, cache_ssl_idx, -1, funname, "an expression", &str, &str_is_temp, &xqr_text_ent, &xqr);
  if (xqr)
    goto xqr_ready; /* see below */
  if (NULL != xqr_text_ent)
    cache_ssl_idx = 0; /* Can't use cache for query that is specified by an entity */
  shu_cache = (('q' == predicate_type) ? xquery_eval_cache : xpath_eval_cache);
  if (NULL == xqr_text_ent)
    {
      encoding_handler_t *eh;
      caddr_t key;
      shuric_t *shu;
      wcharset_t *query_charset = QST_CHARSET(qi);
      if (NULL == query_charset)
	query_charset = default_charset;
      if (NULL == query_charset)
	eh = &eh__ISO8859_1;
      else
	{
	  eh = eh_get_handler (CHARSET_NAME (query_charset, NULL));
	  if (NULL == eh)
	    eh = &eh__ISO8859_1;
	}
      key = list (2, str, box_num ((ptrlong)(eh)));
      shu = shu_cache->_->shuric_cache_get (shu_cache, key);
      dk_free_box (((caddr_t *)key)[1]);
      dk_free_box (key);
      if (NULL != shu)
        {
          xqr_to_release = xqr = (xp_query_t *)(shu->shuric_data);
          goto xqr_put_to_arg_cache;
        }
    }
  memset (&xqre, 0, sizeof (xp_query_env_t));
  xqre.xqre_key_gen = 2;
  if (NULL != xqr_text_ent)
    {
      xqre.xqre_nsctx_xe = xqr_text_ent;
      xqre.xqre_query_charset = CHARSET_UTF8;
    }
  xqr_to_release = xqr = xp_query_parse (qi, str, predicate_type, &err, &xqre);
  if (err)
    {
      if (str_is_temp) dk_free_box (str);
      sqlr_resignal (err);
    }
  if (NULL == xqr_text_ent)
    {
      shu_cache->_->shuric_cache_put (shu_cache, xqr->xqr_shuric);
    }

xqr_put_to_arg_cache:
  if (0 != cache_ssl_idx)
    {
      dk_free_tree ((box_t) (qst[cache_ssl_idx]));
      qst[cache_ssl_idx] = list (2, xqr, box_copy (str));
      xqr_to_release = NULL;
    }

xqr_ready:
  xqi = xqr_instance (xqr, qi);
  QR_RESET_CTX
    {
      int params_count = 0;
      int inx;
      if (NULL == params)
        goto params_ready; /* see below */
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (params) || ((params_count = BOX_ELEMENTS (params)) % 2 != 0))
	sqlr_new_error ("22023", "XI034", "The vector of XPath parameters must be an even length generic array");
      for (inx = 0; inx < params_count; inx += 2)
	{
	  NEW_VARZ (xqi_binding_t, xb);
	  if (!DV_STRINGP (params[inx]))
	    sqlr_new_error ("22023", "XI033", "The vector of XPath parameters must have strings for even numbered elements");
	  xb->xb_name = box_dv_uname_string (params[inx]);
	  xb->xb_next = xqi->xqi_xp_globals;
	  xqi->xqi_xp_globals = xb;
	  if (DV_TYPE_OF (params[inx + 1]) != DV_DB_NULL)
	    xb->xb_value = box_copy_tree (params[inx + 1]);
	  else
	    xb->xb_value = dk_alloc_box (0, DV_ARRAY_OF_XQVAL);
	}

params_ready:
      xqi->xqi_return_attrs_as_nodes = (('q' == predicate_type) ? 1 : 0);
      xqi->xqi_xpath2_compare_rules = (('q' == predicate_type) ? 1 : 0);
      xqi_eval (xqi, xqr->xqr_tree, ent);
      first = xqi_is_value (xqi, xqr->xqr_tree);
      while (first || xqi_is_next_value (xqi, xqr->xqr_tree))
	{
	  int cvt = ((0 == nth_res) || (v_inx == nth_res));
	  first = 0;
	  val = xqi_raw_value (xqi, xqr->xqr_tree);
	  if (cvt)
	    {
	      if (DV_STRINGP (val))
	        {
		  val = box_utf8_as_wide_char (val, NULL, box_length (val), 0, DV_WIDE);
		  if (NULL == val)
		    sqlr_new_error ("22003", "SR476", "Out of memory allocation limits: %s() tries to return an abnormally long NVARCHAR", funname);
		}
	      else
		val = box_copy_tree (val);
	    }
	  if (v_inx == nth_res)
	    {
	      goto found;
	    }
	  v_inx++;
	  if (0 == nth_res)
	    dk_set_push (&set, val);
	}
      if (0 != nth_res)
	val = dk_alloc_box (0, DV_DB_NULL);
    found: ;
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      XQI_FREE_XP_GLOBALS (xqi);
      xqi_free (xqi);
      POP_QR_RESET;
      dk_free_box ((caddr_t)xqr_to_release);
      if (str_is_temp) dk_free_box (str);
      if (err)
	sqlr_resignal (err);
      return NULL;  /* not supposed to */
    }
  END_QR_RESET;
  XQI_FREE_XP_GLOBALS (xqi);
  xqi_free (xqi);
  dk_free_box ((caddr_t)xqr_to_release);
  if (str_is_temp) dk_free_box (str);
  if (0 == nth_res)
    val = list_to_array (dk_set_nreverse (set));
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (val);
#endif
  return val;
}


const char *xt_dump_opname (ptrlong opname, int is_op)
{

  if (is_op)
    switch (opname)
    {
    case BOP_EQ: return "boolean operation '='";
    case BOP_NEQ: return "boolean operation '!='";
    case BOP_LT: return "boolean operation '<'";
    case BOP_LTE: return "boolean operation '<='";
    case BOP_GT: return "boolean operation '>'";
    case BOP_GTE: return "boolean operation '>='";
    case BOP_LIKE: return "boolean operation 'like'";
    case BOP_SAME: return "boolean operation '=='";
    case BOP_NSAME: return "boolean operation '!=='";
    case BOP_PLUS: return "arithmetic operation '+'";
    case BOP_MINUS: return "arithmetic operation '-'";
    case BOP_TIMES: return "arithmetic operation '*'";
    case BOP_DIV: return "arithmetic operation 'div'";
    case BOP_MOD: return "arithmetic operation 'mod'";
    }

  switch (opname)
    {
    case XP_UNION: return "union operator";
    case XP_ABS_DESC: return "descendant:: axis, from root, plain";
    case XP_ABS_DESC_WR: return "descendant:: axis, from root, free-text optimization";
    case XP_ABS_DESC_OR_SELF: return "descendant-or-self:: axis, from root, plain";
    case XP_ABS_DESC_OR_SELF_WR: return "descendant-or-self:: axis, from root, free-text optimization";
    case XP_ABS_CHILD: return "child:: axis, from root, plain";
    case XP_ABS_CHILD_WR: return "child:: axis, from root, free-text optimization";
    case XP_STEP: return "XPath step";
    case XP_FILTER: return "XPath filter";
    case XP_ANCESTOR: return "ancestor:: axis, from current node, plain";
    case XP_ANCESTOR_OR_SELF: return "ancestor-or-self:: axis, from current node, plain";
    case XP_ATTRIBUTE: return "attribute:: axis, from current node, plain";
    case XP_ATTRIBUTE_WR: return "ancestor:: axis, from current node, free-text optimization";
    case XP_CHILD: return "child:: axis, from current node, plain";
    case XP_CHILD_WR: return "child:: axis, from current node, free-text optimization";
    case XP_DESCENDANT: return "descendant:: axis, from current node, plain";
    case XP_DESCENDANT_WR: return "descendant:: axis, from current node, free-text optimization";
    case XP_DESCENDANT_OR_SELF: return "descendant-or-self:: axis, from current node, plain";
    case XP_DESCENDANT_OR_SELF_WR: return "descendant-or-self:: axis, from current node, free-text optimization";
    case XP_FOLLOWING: return "following:: axis, from current node, plain";
    case XP_FOLLOWING_SIBLING: return "following-sibling:: axis, from current node, plain";
    case XP_NAMESPACE: return "namespace:: axis, from current node, plain";
    case XP_PARENT: return "parent:: axis, from current node, plain";
    case XP_PRECEDING: return "preceding:: axis, from current node, plain";
    case XP_PRECEDING_SIBLING: return "preceding-sibling:: axis, from current node, plain";
    case XP_SELF: return "self:: axis, from current node, plain";
    case XP_NODE: return "node() test";
    case XP_NAME_EXACT: return "exact name check, free-text optimization";
    case XP_NAME_LOCAL: return "local-name check, partial free-text optimization";
    case XP_NAME_NSURI: return "namespace check";
    case XP_ROOT: return "root:: axis, plain";
    case XP_DEREF: return "pointer operator as pseudo-axis, from current node, plain";
    case XP_BY_MAIN_STEP: return "child:: axis, from current node, plain";
    case XP_TEXT: return "text() test";
    case XP_PI: return "processing-instruction() test";
    case XP_COMMENT: return "comment() test";
    case XP_VARIABLE: return "input from named variable on stack";
    case XP_LITERAL: return "input from constant value";
    case XP_ELT: return "element() test";
    case XP_ELT_OR_ROOT: return "element() or document-node() test";
    case XP_FAKE_VAR: return "input from a special or fake variable";
/*
    case XP_HTTP: return "__http option";
    case XP_SHALLOW: return "__shallow option";
    case XP_DOC: return "__doc option";
    case XP_KEY: return "__key option";
    case XP_TAG: return "__tag option";
    case XP_VIEW: return "__view option";
    case XP__STAR: return "__* option";
    case XP_SAX: return "__sax option";
    case XP_XMLNS: return "namespace declaration option";
*/
    case XP_NEAR: return "'near' free-text condition";
    case XP_WORD_CHAIN: return "'phrase' free-text condition";
    case XP_AND_NOT: return "'and not' free-text condition";
/*
    case XP_QUIET: return "__quiet option";
    case XP_DTD_CONFIG: return "XML parser configuration parameter";
    case XP_LANG: return "__lang option";
    case XP_ENC: return "__enc option";
*/
    /* case XQ_QUERY_MODULE_LIST: return "List of XQuery modules"; */
    case XQ_QUERY_MODULE: return "XQuery module";
    case XQ_NS_DECL: return "XQuery namespace declaration";
    /*case XQ_SCHEMA_DECL: return "XQuery schema declaration";*/
    case XQ_DEFPARAM: return "Definition of parameter of user-defined XQuery function";
    case XQ_DEFGLOBAL: return "Definition of global variable";
    case XQ_DEFUN: return "User-defined XQuery function";
    case XQ_SEQTYPE: return "XQuery sequence type";
    case XQ_SEQTYPE_OPT_ONE: return "Sequence length: zero or one item";
    case XQ_SEQTYPE_REQ_ONE: return "Sequence length: exactly one item";
    case XQ_SEQTYPE_OPT_MANY: return "Sequence length: zero or more items";
    case XQ_SEQTYPE_REQ_MANY: return "Sequence length: one or more items";
    case XQ_SEQTYPE_DOCELEMENT: return "Sequence should consist of document nodes";
    case XQ_SEQTYPE_ELEMENT: return "Sequence should consist of elements";
    case XQ_SEQTYPE_ATTRIBUTE: return "Sequence should consist of attributes";
    case XQ_SEQTYPE_NODE: return "Sequence should consist of XML nodes";
    case XQ_NCNAME: return "Name without colon (NcName)";
    case XQ_QNAME: return "Name with colon (Qname)";
    case XQ_INSERT: return "XQuery DML command 'insert'";
    case XQ_MOVE: return "XQuery DML command 'move'";
    case XQ_UPSERT: return "XQuery DML command 'upsert'";
    case XQ_DELETE: return "XQuery DML command 'delete'";
    case XQ_RENAME: return "XQuery DML command 'rename'";
    case XQ_REPLACE: return "XQuery DML command 'replace'";
    case XQ_NOT: return "XQuery boolean operation 'not'";
    case XQ_INSTANCEOF: return "XQuery boolean operation 'instanceof'";
    case XQ_IN: return "XQuery operation 'in'";
    case XQ_ASSIGN: return "XQuery operation 'assign'";
    case XQ_BEFORE: return "XQuery boolean operation 'before'";
    case XQ_AFTER: return "XQuery boolean operation 'after'";
    case XQ_ASCENDING: return "XQuery sort specifier 'ascending'";
    case XQ_DESCENDING: return "XQuery sort specifier 'descending'";
    case XQ_CAST: return "XQuery operator 'cast'";
    case XQ_TREAT: return "XQuery operator 'treat'";
    case XQ_FOR: return "XQuery operator 'for'";
    case XQ_LET: return "XQuery operator 'let'";
    case XQ_IMPORT_MODULE: return "XQuery 'import module'";
    case XQ_IMPORT_SCHEMA: return "XQuery 'import schema'";
  }
  return NULL;
}


char *xt_dump_addr (void *addr)
{
  return NULL;
}


void xt_dump_long (void *addr, dk_session_t *ses, int is_op)
{
  if (!IS_BOX_POINTER(addr))
    {
      const char *op_descr = xt_dump_opname((ptrlong)(addr), is_op);
      if (NULL != op_descr)
	{
	  SES_PRINT (ses, op_descr);
	  return;
	}
    }
  else
    {
      char *addr_descr = xt_dump_addr(addr);
      if (NULL != addr_descr)
	{
	  SES_PRINT (ses, addr_descr);
	  return;
	}
    }
  {
    char buf[30];
    sprintf (buf, "LONG %ld", (ptrlong)(addr));
    SES_PRINT (ses, buf);
    return;
  }
}


void
xt_dump (void *tree_arg, dk_session_t *ses, int indent, const char *title, int hint)
{
  XT *tree = (XT *) tree_arg;
  int ctr;
  if ((NULL == tree) && (hint < 0))
    return;
  if (indent > 0)
    {
      session_buffered_write_char ('\n', ses);
      for (ctr = indent; ctr--; /*no step*/ )
        session_buffered_write_char (' ', ses);
    }
  if (title)
    {
      SES_PRINT (ses, title);
      SES_PRINT (ses, ": ");
    }
  if ((-1 == hint) && IS_BOX_POINTER(tree))
    {
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree))
        {
          SES_PRINT (ses, "special: ");
          hint = 0;
        }
      else if ((XT_HEAD >= BOX_ELEMENTS(tree)) || IS_BOX_POINTER (tree->type))
        {
          SES_PRINT (ses, "special: ");
          hint = -2;
        }
    }
  if (!hint)
    hint = DV_TYPE_OF (tree);
  switch (hint)
    {
    case -1:
      {
	int childrens;
	char buf[50];
	if (!IS_BOX_POINTER(tree))
	  {
	    SES_PRINT (ses, "[");
	    xt_dump_long (tree, ses, 0);
	    SES_PRINT (ses, "]");
	    goto printed;
	  }
        sprintf (buf, "(line %ld) ", (long) unbox(tree->srcline));
        SES_PRINT (ses, buf);
	childrens = BOX_ELEMENTS (tree);
	switch (tree->type)
	  {
	  case XP_STEP:
	    {
	      sprintf (buf, "STEP:");
	      SES_PRINT (ses, buf);
	      xt_dump_long ((void *)(tree->_.step.axis), ses, 0);
	      xt_dump (tree->_.step.input, ses, indent+2, "INPUT", -1);
	      xt_dump (tree->_.step.node, ses, indent+2, "CHECK FOR NODE PROPERTIES", -1);
	      xt_dump (tree->_.step.preds, ses, indent+2, "PREDICATES", -2);
	      break;
	    }
	  case XP_VARIABLE:
	    {
	      sprintf (buf, "VARIABLE:");
	      SES_PRINT (ses, buf);
	      xt_dump (tree->_.var.name, ses, indent+2, "NAME", 0);
	      break;
	    }
	  case XP_FAKE_VAR:
	    {
	      sprintf (buf, "FAKE VARIABLE:");
	      SES_PRINT (ses, buf);
	      xt_dump (tree->_.var.name, ses, indent+2, "NAME", 0);
	      break;
	    }
	  case XP_LITERAL:
	    {
	      sprintf (buf, "LITERAL:");
	      SES_PRINT (ses, buf);
	      xt_dump (tree->_.literal.val, ses, indent+2, "VALUE", 0);
	      break;
	    }
	  case XP_PREDICATE:
	    {
	      sprintf (buf, "PREDICATE:");
	      SES_PRINT (ses, buf);
	      xt_dump (tree->_.pred.expr, ses, indent+2, "EXPRESSION", -1);
	      break;
	    }
	  case XP_FILTER:
	    {
	      sprintf (buf, "FILTER:");
	      SES_PRINT (ses, buf);
	      xt_dump (tree->_.filter.path, ses, indent+2, "INPUT PATH", -1);
	      xt_dump (tree->_.filter.pred, ses, indent+2, "CONDITION", -1);
	      break;
	    }
	  case CALL_STMT:
	    {
	      ptrlong exec = unbox (tree->_.xp_func.executable);
	      sprintf (buf, "FUNCTION CALL:");
	      SES_PRINT (ses, buf);
	      if (((xp_func_t)(xpf_call_udf)) == (xp_func_t)(exec))
		{
		  XT *defun = (XT *)(unbox_ptrlong (tree->_.xp_func.qname));
		  xt_dump (defun->_.defun.name, ses, indent+2, "UDF NAME", 0);
		}
	      else
		xt_dump (tree->_.xp_func.qname, ses, indent+2, "FUNCTION NAME", 0);
	      xt_dump ((void *)(exec), ses, indent+2, "FUNCTION BODY", -3);
	      for (ctr = 0; ctr < tree->_.xp_func.argcount; ctr++)
		{
		  xt_dump (tree->_.xp_func.argtrees[ctr], ses, indent+2, "ARGUMENT", -1);
		}
	      xt_dump (tree->_.xp_func.var, ses, indent+2, "OUTPUT", -1);
	      break;
	    }
	  case XP_UNION:
	    {
	      sprintf (buf, "UNION:");
	      SES_PRINT (ses, buf);
	      xt_dump (tree->_.xp_union.left, ses, indent+2, "LEFT INPUT", -1);
	      xt_dump (tree->_.xp_union.right, ses, indent+2, "RIGHT INPUT", -1);
	      break;
	    }
	  case XP_NAME_EXACT:
	  case XP_NAME_LOCAL:
	  case XP_NAME_NSURI:
	    {
	      switch (tree->type)
		{
		case XP_NAME_EXACT: sprintf (buf, "EXACT NAME TEST: "); break;
		case XP_NAME_LOCAL: sprintf (buf, "LOCAL-NAME TEST: "); break;
		case XP_NAME_NSURI: sprintf (buf, "NAMESPACE TEST: "); break;
	        }
	      SES_PRINT (ses, buf);
	      xt_dump (tree->_.name_test.nsuri, ses, -1, "NS URI", 0);
	      SES_PRINT (ses, ", ");
	      xt_dump (tree->_.name_test.local, ses, -1, "LOCAL", 0);
	      SES_PRINT (ses, ", ");
	      xt_dump (tree->_.name_test.qname, ses, -1, "QNAME", 0);
	      break;
	    }
	  case BOP_EQ: case BOP_NEQ:
	  case BOP_LT: case BOP_LTE: case BOP_GT: case BOP_GTE:
	  case BOP_LIKE:
	  case BOP_SAME: case BOP_NSAME:
	  case BOP_PLUS: case BOP_MINUS: case BOP_TIMES: case BOP_DIV: case BOP_MOD:
	    {
	      sprintf (buf, "OPERATOR EXPRESSION of type %ld (", tree->type);
	      SES_PRINT (ses, buf);
	      xt_dump_long ((void *)(tree->type), ses, 1);
	      SES_PRINT (ses, "):");
	      xt_dump (tree->_.bin_exp.left, ses, indent+2, "LEFT", -1);
	      xt_dump (tree->_.bin_exp.right, ses, indent+2, "RIGHT", -1);
	      break;
	    }
	  case XQ_DEFPARAM:
	    {
	      sprintf (buf, "PARAMETER '");
	      SES_PRINT (ses, buf);
	      SES_PRINT (ses, tree->_.paramdef.name);
	      sprintf (buf, "', %.20s, %.20s",
		(tree->_.paramdef.is_bool ? "boolean" : "generic"),
		(tree->_.paramdef.is_iter ? "iterator" : "sequence") );
	      SES_PRINT (ses, buf);
	      /* xt_dump (tree->_.paramdef.type, ses, indent+2, "VALUE TYPE", -1); */
	      break;
	    }
	  case XQ_DEFGLOBAL:
	    {
	      sprintf (buf, "GLOBAL VARIABLE '");
	      SES_PRINT (ses, buf);
	      SES_PRINT (ses, tree->_.defglobal.name);
	      sprintf (buf, "'");
	      SES_PRINT (ses, buf);
	      /* xt_dump (tree->_.defparam.type, ses, indent+2, "VALUE TYPE", -1); */
	      if (NULL != tree->_.defglobal.init_expn)
	        xt_dump (tree->_.defglobal.init_expn, ses, indent+2, "INITIALIZATION EXPN", -1);
	      break;
	    }
	  case XQ_DEFUN:
	    {
	      sprintf (buf, "XQUERY USER-DEFINED FUNCTION:");
	      SES_PRINT (ses, buf);
	      xt_dump (tree->_.defun.name, ses, indent+2, "UDF NAME", 0);
	      for (ctr = 0; ctr < tree->_.defun.argcount; ctr++)
	        xt_dump (tree->_.defun.params[ctr], ses, indent+2, "UDF ARGUMENT", -1);
	      xt_dump (tree->_.defun.ret_type, ses, indent+2, "UDF RETURN TYPE", -1);
	      xt_dump (tree->_.defun.body->xqr_tree, ses, indent+2, "UDF BODY", -1);
	      break;
	    }
	  case XQ_QUERY_MODULE:
	    {
	      sprintf (buf, "XQUERY MODULE:");
	      SES_PRINT (ses, buf);
	      xt_dump (tree->_.module.context, ses, indent+2, "CONTEXT", 0);
	      xt_dump (tree->_.module.defglobals, ses, indent+2, "DEFGLOBALS", -2);
	      xt_dump (tree->_.module.defuns, ses, indent+2, "DEFUNS", -2);
	      xt_dump (tree->_.module.body, ses, indent+2, NULL, -1);
	      break;
	    }
          case XQ_FOR_SQL:
            {
              sprintf (buf, "XQUERY FOR-LOOP:");
              SES_PRINT (ses, buf);
              /*xt_dump (tree->_.xq_for_sql.qr, ses, indent+2, "XMLVIEW", -1);*/
              break;
            }
          case XQ_ASCENDING:
          case XQ_DESCENDING:
            {
              sprintf (buf, "SORT KEY (%s):", ((XQ_ASCENDING == tree->type) ? "asc" : "desc"));
              SES_PRINT (ses, buf);
              break;
            }
	  default:
	    {
	      sprintf (buf, "NODE OF TYPE %ld (", (ptrlong)(tree->type));
	      SES_PRINT (ses, buf);
	      xt_dump_long ((void *)(tree->type), ses, 0);
	      sprintf (buf, ") with %d children:\n", childrens-XT_HEAD);
	      SES_PRINT (ses, buf);
	      for (ctr = XT_HEAD; ctr < childrens; ctr++)
		xt_dump (((void **)(tree))[ctr], ses, indent+2, NULL, 0);
	      break;
	    }
	  }
	break;
      }
    case DV_ARRAY_OF_POINTER:
      {
	int childrens = BOX_ELEMENTS (tree);
	char buf[50];
	sprintf (buf, "ARRAY with %d children: {", childrens);
	SES_PRINT (ses,	buf);
	for (ctr = 0; ctr < childrens; ctr++)
	  xt_dump (((void **)(tree))[ctr], ses, indent+2, NULL, 0);
	if (indent > 0)
	  {
	    session_buffered_write_char ('\n', ses);
	    for (ctr = indent; ctr--; /*no step*/ )
	      session_buffered_write_char (' ', ses);
	  }
	SES_PRINT (ses,	" }");
	break;
      }
    case -2:
      {
	int childrens = BOX_ELEMENTS (tree);
	char buf[50];
	if (0 == childrens)
	  {
	    SES_PRINT (ses, "EMPTY ARRAY");
	    break;
	  }
	sprintf (buf, "ARRAY OF NODES with %d children: {", childrens);
	SES_PRINT (ses,	buf);
	for (ctr = 0; ctr < childrens; ctr++)
	  xt_dump (((void **)(tree))[ctr], ses, indent+2, NULL, -1);
	if (indent > 0)
	  {
	    session_buffered_write_char ('\n', ses);
	    for (ctr = indent; ctr--; /*no step*/ )
	    session_buffered_write_char (' ', ses);
	  }
	SES_PRINT (ses,	" }");
	break;
      }
    case -3:
      {
	char **execname = (char **)id_hash_get (xpf_reveng, (caddr_t)(&tree));
	SES_PRINT (ses, "native code started at ");
	if (NULL == execname)
	  {
	    char buf[30];
	    sprintf (buf, "0x%p", (void *)tree);
	    SES_PRINT (ses, buf);
	  }
	else
	  {
	    SES_PRINT (ses, "label '");
	    SES_PRINT (ses, execname[0]);
	    SES_PRINT (ses, "'");
	  }
	break;
      }
    case DV_LONG_INT:
      {
	char buf[30];
	sprintf (buf, "LONG %ld", (ptrlong)(tree));
	SES_PRINT (ses,	buf);
	break;
      }
    case DV_STRING:
      {
	SES_PRINT (ses,	"STRING `");
	SES_PRINT (ses,	(char *)(tree));
	SES_PRINT (ses,	"'");
	break;
      }
    case DV_UNAME:
      {
	SES_PRINT (ses,	"UNAME `");
	SES_PRINT (ses,	(char *)(tree));
	SES_PRINT (ses,	"'");
	break;
      }
    case DV_SYMBOL:
      {
	SES_PRINT (ses,	"SYMBOL `");
	SES_PRINT (ses,	(char *)(tree));
	SES_PRINT (ses,	"'");
	break;
      }
    default:
      {
	char buf[30];
	sprintf (buf, "UNEXPECTED TYPE (%u)", (unsigned)(DV_TYPE_OF (tree)));
	SES_PRINT (ses,	buf);
	break;
      }
    }
printed:
  if (0 == indent)
    session_buffered_write_char ('\n', ses);
}


caddr_t
xpath_or_xquery_explain (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, const char *funname, ptrlong predicate_type)
{
  xp_query_t * xqr = NULL;
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t str = bif_string_arg (qst, args, 0, funname);
  caddr_t err = NULL;
  dk_session_t *res;
  xqr = xp_query_parse (qi, str, predicate_type, &err, &xqre_default);
  if (err)
    sqlr_resignal (err);
  res = strses_allocate ();
  xt_dump (xqr->xqr_tree, res, 0, "QUERY", -1);
  dk_free_box ((caddr_t)xqr);
  return (caddr_t)res;
}


caddr_t
bif_xpath_eval (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return xpath_or_xquery_eval (qst, err_ret, args, "xpath_eval", 'p', 0);
}


caddr_t
bif_xquery_eval (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return xpath_or_xquery_eval (qst, err_ret, args, "xquery_eval", 'q', 0);
}


caddr_t
bif_xpath_eval_w_cache (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return xpath_or_xquery_eval (qst, err_ret, args, "xpath_eval", 'p', 1);
}


caddr_t
bif_xquery_eval_w_cache (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return xpath_or_xquery_eval (qst, err_ret, args, "xquery_eval", 'q', 1);
}


caddr_t
bif_xpath_explain (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return xpath_or_xquery_explain (qst, err_ret, args, "xpath_explain", 'p');
}


caddr_t
bif_xquery_explain (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return xpath_or_xquery_explain (qst, err_ret, args, "xquery_explain", 'q');
}


caddr_t
bif_xpath_lex_analyze (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "xpath_lex_analyze");
  return xp_query_lex_analyze (str, 'p' /* like xpath */, NULL, QST_CHARSET(qst));
}


caddr_t
bif_xquery_lex_analyze (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "xquery_lex_analyze");
  return xp_query_lex_analyze (str, 'q' /* like xquery */, NULL, QST_CHARSET(qst));
}


caddr_t
xpath_funcall_or_apply (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, const char *funname, ptrlong predicate_type, int with_cache)
{
  int first;
  dk_set_t set = NULL;
  volatile caddr_t val = NULL;
  caddr_t str;
  int str_is_temp;
  xml_entity_t *xqr_text_ent;
  xp_query_t * xqr, *xqr_to_release = NULL;
  query_instance_t * qi = (query_instance_t *) qst;
/*
  xml_entity_t * ent = bif_entity_arg (qst, args, 1, funname);
*/
  caddr_t ent = bif_arg (qst, args, 1, funname);
  size_t argcount = BOX_ELEMENTS (args);
  long cache_ssl_idx = (with_cache ? bif_var_ssl_idx_arg (qst, args, --argcount, funname) : 0);
  caddr_t * params = (('f' == predicate_type) ? NULL : (caddr_t *)bif_array_or_null_arg (qst, args, 2, funname));
  int param_count = ('f' == predicate_type) ? argcount - 2 : BOX_ELEMENTS (params);
  /*caddr_t err = NULL;*/
  xp_instance_t * xqi;
  XT *funcall;
  xp_func_t fn;
  bif_xquery_arg (qst, args, 0, cache_ssl_idx, param_count, funname, "function name", &str, &str_is_temp, &xqr_text_ent, &xqr);
  if (NULL == xqr)
    {
      xpf_metadata_t *metas = NULL;
      xpf_metadata_t ** metas_ptr = (xpf_metadata_t **)id_hash_get (xpf_metas, (caddr_t)(&str));
      if (NULL == metas_ptr)
        sqlr_new_error ("22023", "XI039", "Unknown XPath function name %.200s is used as first argument of %.200s function", str, funname);
      metas = metas_ptr[0];
      if (metas->xpfm_min_arg_no > param_count)
        sqlr_new_error ("22023", "XI040", "The XPATH function %.200s() mentioned in %.200s() requires %d arguments but the call contains only %d",
          str, funname, (int)(metas->xpfm_min_arg_no), param_count );
      if (metas->xpfm_main_arg_no < param_count)
        {
          if (0 == metas->xpfm_tail_arg_no)
            sqlr_new_error ("22023", "XI041", "The XPATH function %.200s() mentioned in %.200s() can handle only %d arguments but the call provides %d",
              str, funname, (int)(metas->xpfm_main_arg_no), param_count );
          else
            {
              int tail_mod = (param_count - metas->xpfm_main_arg_no) % metas->xpfm_tail_arg_no;
              if (tail_mod)
                sqlr_new_error ("22023", "XI042", "The XPATH function %.200s() mentioned in %.200s() can handle %d, %d, %d etc. arguments but the call provides %d",
                  str, funname, (int)(metas->xpfm_main_arg_no), (int)(metas->xpfm_main_arg_no + metas->xpfm_tail_arg_no), (int)(metas->xpfm_main_arg_no + 2 * metas->xpfm_tail_arg_no),
                  param_count );
            }
        }
      xqr = xqr_stub_for_funcall (metas, param_count);
      if (0 != cache_ssl_idx)
        {
          dk_free_tree ((box_t) (qst[cache_ssl_idx]));
          qst[cache_ssl_idx] = list (3, xqr, box_copy (str), box_num (param_count));
        }
      else
        xqr_to_release = xqr;
    }
  xqi = xqr_instance (xqr, qi);
  QR_RESET_CTX
    {
      int inx, param_ofs, param_step;
      funcall = xqr->xqr_tree;
      fn = (void *)unbox (funcall->_.xp_func.executable);
      param_ofs = ((xpf_cartesian_product_loop == fn) ? 1 : 0);
      param_step = ((xpf_cartesian_product_loop == fn) ? 2 : 1);
      for (inx = 0; inx < param_count; inx ++)
        {
          XT *fake_var = funcall->_.xp_func.argtrees[inx * param_step + param_ofs];
          caddr_t param_val = (('f' == predicate_type) ? bif_arg (qst, args, 2+inx, funname) : params[inx]);
          XQI_SET (xqi, fake_var->_.var.res, NULL);
#ifdef XPATH_DEBUG
          if (xqi_set_odometer >= xqi_set_debug_start)
            dk_check_fake_var (param_val);
#endif
          XQI_SET (xqi, fake_var->_.var.init, NULL);
#ifdef XPATH_DEBUG
          if (xqi_set_odometer >= xqi_set_debug_start)
            dk_check_fake_var (param_val);
#endif
          if ((DV_DB_NULL == DV_TYPE_OF (param_val)) || (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (param_val) && 0 == BOX_ELEMENTS (param_val)))
            {
              XQI_SET (xqi, fake_var->_.var.init, dk_alloc_box (0, DV_ARRAY_OF_XQVAL));
              XQI_SET_INT (xqi, fake_var->_.var.state, XI_AT_END);
            }
          else
            {
#ifdef XPATH_DEBUG
              if (xqi_set_odometer >= xqi_set_debug_start)
                dk_check_fake_var (param_val);
#endif
              caddr_t converted_copy;
              switch (DV_TYPE_OF (param_val))
                {
                case DV_LONG_INT: converted_copy = box_num_nonull (unbox (param_val)); break;
                case DV_ARRAY_OF_POINTER:
                  {
                    int ctr;
                    converted_copy = box_copy_tree (param_val);
                    box_tag_modify (param_val, DV_ARRAY_OF_XQVAL);
                    DO_BOX_FAST (caddr_t, v, ctr, converted_copy)
                      {
                        if (NULL == v) converted_copy = box_num_nonull (0);
                      }
                    END_DO_BOX_FAST;
                    break;
                  }
                default: converted_copy = box_copy_tree (param_val); break;
                }
              XQI_SET (xqi, fake_var->_.var.init, converted_copy);
              XQI_SET_INT (xqi, fake_var->_.var.state, XI_INITIAL);
              XQI_SET_INT (xqi, fake_var->_.var.inx, 0);
            }
        }
      xqi->xqi_return_attrs_as_nodes = 1;
      xqi->xqi_xpath2_compare_rules = 0;
      xqi_eval (xqi, xqr->xqr_tree, (xml_entity_t *)ent); /* At this point the actual type of ent is nto known, we just hope that if it's not an entity it will not be used */
      first = xqi_is_value (xqi, xqr->xqr_tree);
      while (first || xqi_is_next_value (xqi, xqr->xqr_tree))
        {
          first = 0;
          val = xqi_raw_value (xqi, xqr->xqr_tree);
          dk_set_push (&set, box_copy_tree (val));
        }
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      XQI_FREE_XP_GLOBALS (xqi);
      xqi_free (xqi);
      POP_QR_RESET;
      dk_free_box ((caddr_t)xqr_to_release);
      if (str_is_temp) dk_free_box (str);
      if (err)
        sqlr_resignal (err);
      return NULL;  /* not supposed to */
    }
  END_QR_RESET;
  XQI_FREE_XP_GLOBALS (xqi);
  xqi_free (xqi);
  dk_free_box ((caddr_t)xqr_to_release);
  if (str_is_temp) dk_free_box (str);
  if (NULL == set)
    val = NEW_DB_NULL;
  else if (NULL == set->next)
    val = dk_set_pop (&set);
  else
    val = list_to_array (dk_set_nreverse (set));
#ifdef XPATH_DEBUG
  if (xqi_set_odometer >= xqi_set_debug_start)
    dk_check_tree (val);
#endif
  if ((xpf_cartesian_product_loop == fn) && (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val)))
    {
      caddr_t val0;
      if (0 == BOX_ELEMENTS (val))
        {
          dk_free_tree (val); return NEW_DB_NULL;
        }
      val0 = ((caddr_t *)val)[0];
      ((caddr_t *)val)[0] = NULL;
      dk_free_tree (val);
      return val0;
    }
  return val;
}


caddr_t
bif_xpath_funcall (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return xpath_funcall_or_apply (qst, err_ret, args, "xpath_funcall", 'f', 0);
}


caddr_t
bif_xpath_apply (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return xpath_funcall_or_apply (qst, err_ret, args, "xpath_apply", 'a', 0);
}


caddr_t
bif_xpath_funcall_w_cache (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return xpath_funcall_or_apply (qst, err_ret, args, "xpath_funcall", 'f', 1);
}


caddr_t
bif_xpath_apply_w_cache (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return xpath_funcall_or_apply (qst, err_ret, args, "xpath_apply", 'a', 1);
}


#ifdef XPATHP_DEBUG

typedef struct lexem_descr_s
{
  int ld_val;
  const char *ld_yname;
  char ld_fmttype;
  const char * ld_fmt;
  caddr_t *ld_tests;
} lexem_descr_t;

lexem_descr_t xp_lexem_descrs[__NONPUNCT_END+1];

#define LEX_PROPS xpathp_lex_props
#define PUNCT(x) 'P', (x)
#define LITERAL(x) 'L', (x)
#define FAKE(x) 'F', (x)
#define XP "p"
#define XQ "q"
#define FT "t"

#define LAST(x) "L", (x)
#define LAST1(x) "K", (x)
#define MISS(x) "M", (x)
#define ERR(x)  "E", (x)

static void xpathp_lex_props (int val, const char *yname, char fmttype, const char *fmt, ...)
{
  va_list tail;
  const char *cmd;
  dk_set_t tests = NULL;
  lexem_descr_t *ld = xp_lexem_descrs + val;
  if (0 != ld->ld_val)
    GPF_T;
  ld->ld_val = val;
  ld->ld_yname = yname;
  ld->ld_fmttype = fmttype;
  ld->ld_fmt = fmt;
  va_start (tail, fmt);
  for (;;)
    {
      cmd = va_arg (tail, const char *);
      if (NULL == cmd)
	break;
      dk_set_push (&tests, box_dv_short_string (cmd));
    }
  va_end (tail);
  ld->ld_tests = (caddr_t *)revlist_to_array (tests);
}

static void xp_lexem_descrs_fill (void)
{
  static int first_run = 1;
  if (!first_run)
    return;
  first_run = 0;
#include "xpathp_lex_props.c"
}

caddr_t
bif_xpathp_test (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_set_t report = NULL;
  int tested_lex_val = 0;
  xp_lexem_descrs_fill ();
  for (tested_lex_val = 0; tested_lex_val < __NONPUNCT_END; tested_lex_val++)
    {
      char parser_mode = '\0';
      char cmd;
      caddr_t **lexems;
      unsigned lex_count;
      unsigned cmd_idx = 0;
      int last_lval, last1_lval;
      lexem_descr_t *ld = xp_lexem_descrs + tested_lex_val;
      if (0 == ld->ld_val)
	continue;
      dk_set_push (&report, box_dv_short_string (""));
      dk_set_push (&report,
        box_sprintf (0x100, "#define % 25s %d /* '%s' (%c) */",
	  ld->ld_yname, ld->ld_val, ld->ld_fmt, ld->ld_fmttype ) );
      for (cmd_idx = 0; cmd_idx < BOX_ELEMENTS(ld->ld_tests); cmd_idx++)
	{
	  cmd = ld->ld_tests[cmd_idx][0];
	  switch (cmd)
	    {
	    case 'p': case 'q': case 't': parser_mode = cmd; break;
	    case 'K': case 'L': case 'M': case 'E':
	      cmd_idx++;
	      lexems = (caddr_t **) xp_query_lex_analyze (ld->ld_tests[cmd_idx], parser_mode, NULL, QST_CHARSET(qst));
	      dk_set_push (&report, box_dv_short_string (ld->ld_tests[cmd_idx]));
	      lex_count = BOX_ELEMENTS (lexems);
	      if (0 == lex_count)
		{
		  dk_set_push (&report, box_dv_short_string ("FAILED: no lexems parsed and no error reported!"));
		  break;
		}
	      { char buf[0x1000]; char *buf_tail = buf;
	        unsigned lctr = 0;
		for (lctr = 0; lctr < lex_count && (5 == BOX_ELEMENTS(lexems[lctr])); lctr++)
		  {
		    ptrlong *ldata = ((ptrlong *)(lexems[lctr]));
		    int lval = ldata[3];
		    lexem_descr_t *ld = xp_lexem_descrs + lval;
		    if (ld->ld_val)
		      buf_tail += sprintf (buf_tail, "%s", ld->ld_yname);
		    else if (lval < 0x100)
		      buf_tail += sprintf (buf_tail, "'%c'", lval);
		    else GPF_T;
		    buf_tail += sprintf (buf_tail, " %ld ", (long)(ldata[4]));
		  }
	        buf_tail[0] = '\0';
		dk_set_push (&report, box_dv_short_string (buf));
	      }
	      if (3 == BOX_ELEMENTS(lexems[lex_count-1])) /* lexical error */
		{
		  dk_set_push (&report,
		    box_sprintf (0x1000, "%s: ERROR %s",
		      ('E' == cmd) ? "PASSED": "FAILED", lexems[lex_count-1][2] ) );
		  break;
		}
	      if (END_OF_XPSCN_TEXT != ((ptrlong *)(lexems[lex_count-1]))[3])
		{
		  dk_set_push (&report, box_dv_short_string ("FAILED: end of source is not reached and no error reported!"));
		  break;
		}
	      if (1 == lex_count)
		{
		  dk_set_push (&report, box_dv_short_string ("FAILED: no lexems parsed and only end of source has found!"));
		  break;
		}
	      last_lval = ((ptrlong *)(lexems[lex_count-2]))[3];
	      if ('E' == cmd)
		{
		  dk_set_push (&report,
		    box_sprintf (0x1000, "FAILED: last lexem is %d, must be error",
		  last_lval) );
		  break;
		}
	      if ('K' == cmd)
		{
		  if (4 > lex_count)
		    {
		      dk_set_push (&report, box_dv_short_string ("FAILED: The number of actual lexems is less than two"));
		      break;
		    }
		  last1_lval = ((ptrlong *)(lexems[lex_count-3]))[3];
		  dk_set_push (&report,
		    box_sprintf (0x1000, "%s: one-before-last lexem is %d, must be %d",
		      (last1_lval == tested_lex_val) ? "PASSED": "FAILED", last1_lval, tested_lex_val) );
		  break;
		}
	      if ('L' == cmd)
		{
		  dk_set_push (&report,
		    box_sprintf (0x1000, "%s: last lexem is %d, must be %d",
		      (last_lval == tested_lex_val) ? "PASSED": "FAILED", last_lval, tested_lex_val) );
		  break;
		}
	      if ('M' == cmd)
		{
		  unsigned lctr;
		  for (lctr = 0; lctr < lex_count; lctr++)
		    {
		      int lval = ((ptrlong *)(lexems[lctr]))[3];
		      if (lval == tested_lex_val)
			{
			  dk_set_push (&report,
			    box_sprintf (0x1000, "FAILED: lexem %d is found but it should not occur",
			      tested_lex_val) );
			  goto end_of_test_m;
			}
		    }
		  dk_set_push (&report,
		    box_sprintf (0x1000, "PASSED: lexem %d is not found and it should not occur",
		      tested_lex_val) );
end_of_test_m:
		  break;
		}
	      GPF_T;
	      break;
	    default: GPF_T;
	    }
	}
    }
  return revlist_to_array (report);
}
#endif


void xe_insert_external_dtd (xml_entity_t *xe)
{
  dtd_t *dtd = xe->xe_doc.xd->xd_dtd;
  if ((NULL != dtd) && (NULL != dtd->ed_sysuri))
    {
      caddr_t err = NULL;
      caddr_t sysid_base_uri = (char *) xe_get_sysid_base_uri (xe);
      xml_entity_t *refd = xe->_->xe_reference (xe->xe_doc.xd->xd_qi, sysid_base_uri, dtd->ed_sysuri, xe->xe_doc.xd, &err);
      if (NULL == refd)
	dk_free_tree (err);
      else
        {
	  int id_attrs_changed = dtd_insert_soft (dtd, refd->xe_doc.xd->xd_dtd);
	  if (id_attrs_changed)
	    {
	      xe->xe_doc.xd->xd_id_scan = 0;
	      dk_free_box ((box_t) xe->xe_doc.xd->xd_id_dict);
	      xe->xe_doc.xd->xd_id_dict = NULL;
	    }
	}
      dk_free_box (dtd->ed_sysuri);
      dtd->ed_sysuri = NULL;
    }
}


xml_entity_t *
xte_reference (query_instance_t * qi, caddr_t base, caddr_t ref,
	      xml_doc_t * from_doc, caddr_t *err_ret)
{
  xml_tree_ent_t * xte;
  dtd_t **xte_dtd_ptr;
  caddr_t str;
  caddr_t tree;
  caddr_t err = NULL;
  xml_doc_t * top_doc = from_doc->xd_top_doc;
  caddr_t path_utf8;
  lt_check_error (qi->qi_trx);
  path_utf8 = xml_uri_resolve (qi, &err, base, ref, "UTF-8");
/*  dbg_printf (("Resolving %s (base %s)\n", ref, base); */
  if (NULL != err)
    {
      if (NULL == err_ret)
	sqlr_resignal (err);
      err_ret[0] = err;
      return NULL;
    }
  DO_SET (xml_entity_t *, ref, &top_doc->xd_referenced_entities)
    {
      if (NULL != ref->xe_doc.xd->xd_uri
	  && 0 == strcmp (ref->xe_doc.xtd->xd_uri, path_utf8))
	{
	  dk_free_box (path_utf8);
	  return (ref);
	}
    }
  END_DO_SET();
  str = xml_uri_get (qi, &err, NULL, base, ref, XML_URI_STRING_OR_ENT);
  if (DV_XML_ENTITY == DV_TYPE_OF (str))
    {
      xte = (xml_tree_ent_t *)str; /* This is actually not quite correct, it can be XPER but no XMLTree-specific things are used */
      goto xte_is_ready;
    }

  if (NULL != err)
    goto error_cleanup;
  tree = xml_make_mod_tree (qi, str, &err, GE_XML, path_utf8, NULL /* no enc */, server_default_lh, NULL/* no config*/, NULL /* no DTD */, NULL /* no ID cache */, NULL /* no namespace 2dict */);
  if (NULL != err)
    goto error_cleanup;
  xte = xte_from_tree (tree, qi);
  xte_dtd_ptr = &(xte->xe_doc.xd->xd_dtd);
  if (NULL != from_doc->xd_dtd)
    {
      dtd_addref (from_doc->xd_dtd, 0);
      if (NULL != xte_dtd_ptr[0])
	dtd_release (xte_dtd_ptr[0]);
      xte_dtd_ptr[0] = from_doc->xd_dtd;
      dk_free_box ((caddr_t)(xte->xe_doc.xd->xd_id_dict));
      dk_free_box (xte->xe_doc.xd->xd_id_scan);
      xte->xe_doc.xd->xd_id_dict = NULL;
      xte->xe_doc.xd->xd_id_scan = NULL;
    }
  xte->xe_doc.xtd->xd_uri = path_utf8;
  dk_free_box (str);

xte_is_ready:
  XD_DOM_LOCK(xte->xe_doc.xd);
  dk_set_push (&top_doc->xd_referenced_entities, (void*) xte);
  xte->xe_doc.xtd->xd_top_doc = top_doc;
  top_doc->xd_weight += xte->xe_doc.xd->xd_weight;
  top_doc->xd_cost += xte->xe_doc.xd->xd_cost;
  if (top_doc->xd_cost > XML_MAX_DOC_COST)
    top_doc->xd_cost = XML_MAX_DOC_COST;
  return ((xml_entity_t *) xte);

error_cleanup:
  dk_free_box (path_utf8);
  dk_free_box (str);
  if (NULL == err_ret)
    sqlr_resignal (err);
  err_ret[0] = err;
  return NULL;
}

#define XE_NAME(xe) (xe->xe_doc.xd->xd_uri ? xe->xe_doc.xd->xd_uri : "<no URI>")

void
xe_cycle_check (xml_entity_t * xe)
{
  xml_entity_t * parent = xe->xe_referer;
  while (parent)
    {
      if (box_equal (parent->xe_doc.xd->xd_uri, xe->xe_doc.xd->xd_uri))
	sqlr_new_error ("42000", "XI010", "XML external entity references for a cycle from %.300s to %.300s",
		    XE_NAME (parent), XE_NAME (xe));
      parent = parent->xe_referer;
    }
}


const char * xe_get_sysid (xml_entity_t *xe, const char *ref_name)
{
  while (NULL != xe->xe_referer)
    xe = xe->xe_referer;
  return (xe->_->xe_get_sysid (xe, ref_name));
}


const char *xe_get_sysid_base_uri(xml_entity_t *xe)
{
  while (NULL != xe->xe_referer)
    xe = xe->xe_referer;
  return xe->xe_doc.xd->xd_uri;
}


/* Note that top-level logic of xte_down() functionality is duplicated
   in xte_next_sibling. They should be changed synchronously, if needed */
int
xte_down (xml_entity_t * xe, XT * node)
{
  xml_tree_ent_t *xte = (xml_tree_ent_t *) xe;
  caddr_t * current = xte->xte_current;
  if (xte_is_entity (current) && (NULL == xte->xe_attr_name))
    {
      caddr_t * head = XTE_HEAD (current);
      caddr_t name = XTE_HEAD_NAME (head);
      if (uname__ref == name)
	{
	  caddr_t rel_uri = (caddr_t) REF_REL_URI(xte,head);
	  char *sysid_base_uri;
	  xml_entity_t * ref_copy;
	  xml_entity_t * old_back = xte->xe_referer;
	  xml_entity_t * new_back;
	  xml_entity_t * refd;
	  sysid_base_uri = (char *)((const char *)xe_get_sysid_base_uri((xml_entity_t *)(xte)));
	  if (NULL != rel_uri)
	    {
	      refd = xte_reference (xte->xe_doc.xtd->xd_qi, sysid_base_uri, rel_uri, xte->xe_doc.xd, NULL);
	    }
	  else
	    {
	      caddr_t err = NULL;
	      refd = xte_reference (xte->xe_doc.xtd->xd_qi, sysid_base_uri, head[2], xte->xe_doc.xd, &err);
	      if (NULL == refd)
		{
		  dk_free_tree (err);
		  return XI_AT_END;
		}
	    }
/*	  fprintf (stderr, "resolving %s\n", head[2]);*/
	  xte->xe_referer = NULL;
	  new_back = xte->_->xe_copy ((xml_entity_t *) xte);
	  new_back->xe_referer = old_back;
	  ref_copy = refd->_->xe_copy ((xml_entity_t *) refd);
	  xte_destroy ((xml_entity_t *) xte);
	  memcpy (xte, ref_copy, sizeof (xml_entity_un_t));
	  box_tag_modify (ref_copy, DV_ARRAY_OF_LONG); /* no recursive destr etc.
							* the tag is not a string tag because of string alignment being to 16 whereas other boxes to 8 */
	  dk_free_box ((box_t) ref_copy);
	  xte->xe_referer = new_back;
	  if (XI_RESULT == ((xml_entity_t *) xte)->_->xe_first_child(((xml_entity_t *) xte), node))
	    return XI_RESULT;
	  xte->_->xe_up ((xml_entity_t *) xte, (XT *) XP_NODE, (XE_UP_MAY_TRANSIT | XE_UP_MAY_TRANSIT_ONCE));
	  return XI_AT_END;
	}
    }
  if (!xte_ent_name_test ((xml_entity_t *)xte, node))
    return XI_AT_END;
  return XI_RESULT;
}


int
xte_down_rev (xml_entity_t * xe, XT * node)
{
  xml_tree_ent_t *xte = (xml_tree_ent_t *) xe;
  caddr_t * current = xte->xte_current;
  if (xte_is_entity (current) && (NULL == xte->xe_attr_name))
    {
      caddr_t * head = XTE_HEAD (current);
      caddr_t name = XTE_HEAD_NAME (head);
      if (uname__ref == name)
	{
	  volatile xml_entity_t * save_referer, *topmost;
	  volatile xml_entity_t * last_good = NULL;
	  int res;
	  if (XI_AT_END == xte_down (xe, (XT *) XP_NODE))
	    return XI_AT_END;
	  /* This catch implements some tricky thing. We set xe_referer to
	     prevent xe_next_sibling from running outside current subdocument:
	     xe_up will not know that it's a subdocument (will think that it's a whole doc)
	     Then we restore the status quo. */
	  save_referer = xe->xe_referer;
	  xe->xe_referer = NULL;
	  QR_RESET_CTX
	    {
	      if (xe->_->xe_ent_name_test (xe, node))
		last_good = xe->_->xe_copy(xe);
	      while (XI_RESULT == xe->_->xe_next_sibling(xe, node))
		{
		  dk_free_box ((caddr_t)last_good);
		  last_good = xe->_->xe_copy(xe);
		}
	      if ((NULL != last_good) && !xe->_->xe_is_same_as (xe, (const xml_entity_t *) last_good))
		{
		  /* No need in xe->xe_referer = NULL here because it's done above */
		  xte_destroy (xe);
		  memcpy (xe, (const void *) last_good, sizeof (xml_entity_un_t));
		  box_tag_modify (last_good, DV_ARRAY_OF_LONG);
		  dk_free_box ((caddr_t)last_good);
		}
	      else
		dk_free_box ((caddr_t)last_good);
	      res = (NULL != last_good) ? XI_RESULT : XI_AT_END;
	      topmost = xe;
	      while (NULL != topmost->xe_referer)
		topmost = topmost->xe_referer;
	      topmost->xe_referer = (xml_entity_t *) save_referer;
	    }
	  QR_RESET_CODE
	    {
	      du_thread_t * self = THREAD_CURRENT_THREAD;
	      caddr_t err = thr_get_error_code (self);
	      POP_QR_RESET;
	      dk_free_box ((box_t) last_good);
	      topmost = xe;
	      while (NULL != topmost->xe_referer)
		topmost = topmost->xe_referer;
	      topmost->xe_referer = (xml_entity_t *) save_referer;
	      sqlr_resignal (err);
	      return XI_AT_END; /* never reached */
	    }
	  END_QR_RESET;
	  if (XI_RESULT == res)
	    return XI_RESULT;
	  xe->_->xe_up (xe, (XT *) XP_NODE, (XE_UP_MAY_TRANSIT | XE_UP_MAY_TRANSIT_ONCE));
	  return XI_AT_END;
	}
    }
  if (xe->_->xe_ent_name_test (xe, node))
    return XI_RESULT;
  return XI_AT_END;
}


int
xte_ent_node_test (xml_tree_ent_t * xte, XT * node)
{
  caddr_t * current = xte->xte_current;
  caddr_t * head, name;
  dtp_t dtp;
  if ((XT*) XP_NODE == node)
    return 1;
  dtp = DV_TYPE_OF (current);
  if (DV_ARRAY_OF_POINTER != dtp)
    {
      if ((XT*) XP_TEXT == node)
	return 1;
      else
	return 0;
    }
  if (BOX_ELEMENTS (current) < 1)
    sqlr_new_error ("XT001", "XI011", "Bad xml tree doc");
  head = XTE_HEAD (current);
  dtp = DV_TYPE_OF ((caddr_t)head);
  if (DV_ARRAY_OF_POINTER != dtp)
    sqlr_new_error ("XT001", "XI011", "Bad xml tree doc");
  name = head[0];
  if (uname__ref == name)
    {
#ifdef DEBUG
      GPF_T;
#endif
      return 0;
    }
  return xt_node_test_match (node, name);
}


int
xte_node_test (caddr_t * current, XT * node)
{
  caddr_t * first;
  dtp_t dtp;
  if ((XT*) XP_NODE == node)
    return 1;
  dtp = DV_TYPE_OF (current);
  if (DV_ARRAY_OF_POINTER != dtp)
    {
      if ((XT*) XP_TEXT == node)
	return 1;
      else
	return 0;
    }
  if (BOX_ELEMENTS (current) < 1)
    sqlr_new_error ("XT001", "XI012", "Bad xml tree doc");
  first = ((caddr_t **) current)[0];
  dtp = DV_TYPE_OF (first);
  if (DV_ARRAY_OF_POINTER != dtp)
    sqlr_new_error ("XT001", "XI012", "Bad xml tree doc");
  return xt_node_test_match (node, first[0]);
}


caddr_t
xte_element_name (xml_entity_t * xe)
{
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * current = xte->xte_current;
  caddr_t * first;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (current))
    return uname__txt;
  /* sqlr_error (".....", "XPATH Name() of non-entity"); */
  first = (caddr_t*) current[0];
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (first))
    return uname__txt;
  /* sqlr_error (".....", "XPATH Name() of non-entity"); */
  return (box_copy_tree (first[0]));
}


caddr_t
xte_element_name_nocopy (xml_entity_t * xe)
{
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * current = xte->xte_current;
  caddr_t * first;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (current))
    return uname__txt;
  /* sqlr_error (".....", "XPATH Name() of non-entity"); */
  first = (caddr_t*) current[0];
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (first))
    return uname__txt;
  /* sqlr_error (".....", "XPATH Name() of non-entity"); */
  return first[0];
}


caddr_t
xte_ent_name (xml_entity_t * xe)
{
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * current;
  caddr_t * first;
  if (NULL != xe->xe_attr_name)
    return (box_copy (xe->xe_attr_name));
  current = xte->xte_current;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (current))
    return uname___empty;
  first = (caddr_t*) current[0];
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (first))
    return uname___empty;
  if (' ' != first[0][0])
    return (box_copy_tree (first[0]));
  if (uname__pi == first[0])
    {
      if (3 <= BOX_ELEMENTS (first))
      return (box_copy_tree (first[2]));
    }
  return uname___empty;
}


static caddr_t
xte_ent_name_for_test (xml_entity_t * xe)
{
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * current;
  caddr_t * first;
  if (NULL != xe->xe_attr_name)
    return (xe->xe_attr_name);
  current = xte->xte_current;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (current))
    return uname__txt;
  /* sqlr_error (".....", "XPATH Name() of non-entity"); */
  first = (caddr_t*) current[0];
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (first))
    return uname__txt;
  /* sqlr_error (".....", "XPATH Name() of non-entity"); */
  return first[0];
}


int
xte_element_name_test (xml_entity_t * xe, XT * node)
{
  caddr_t name = xte_element_name_nocopy (xe);
  int res = xt_node_test_match (node, name);
  return res;
}


int
xte_ent_name_test (xml_entity_t * xe, XT * node)
{
  caddr_t name = xte_ent_name_for_test(xe);
  int res = xt_node_test_match (node, name);
  return res;
}

/*
int
xte_equal  (xml_entity_t * xe, xml_entity_t * xe2)
{
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  xml_tree_ent_t * xte2 = (xml_tree_ent_t *) xe2;
  if (xte->_ != xte2->_)
    return 0;
  if (xte->xte_current == xte2->xte_current)
    return 1;
  return 0;
}
*/


int xte_is_same_as (const xml_entity_t *this_xe, const xml_entity_t *that_xe)
{
  if (XE_IS_TREE(that_xe))
    {
      const xml_tree_ent_t *this_xte = (const xml_tree_ent_t *)(this_xe);
      const xml_tree_ent_t *that_xte = (const xml_tree_ent_t *)(that_xe);
      if (this_xte->xe_doc.xtd != that_xte->xe_doc.xtd)
	return 0;
      if (this_xte->xte_current != that_xte->xte_current)
	return 0;
      if (this_xte->xe_attr_name != that_xte->xe_attr_name)
        return 0;
      return 1;
    }
  return 0;
}


int
xte_up (xml_entity_t * xe, XT * node, int up_flags)
{
  xml_tree_ent_t *xte = (xml_tree_ent_t *) xe;
  int rc;
/*
Attributes are not children of its element.
But the element is parent of its attributes.
See XPATH, 5.3 "Attribute Nodes"
*/
  if (NULL != xe->xe_attr_name)
    {
/* If no sideway then element's name should match the test */
      if (!(up_flags & XE_UP_SIDEWAY) && !xte_element_name_test (xe, node))
	return XI_AT_END;
      dk_free_box (xe->xe_attr_name);
      xe->xe_attr_name = NULL;
      if (!(up_flags & XE_UP_SIDEWAY))
	return XI_RESULT;
      goto go_sideway;
    }
/* Top of the (sub)document */
  if (!XTE_HAS_PARENT(xte) ||
      (!XTE_HAS_2PARENTS(xte) && (NULL != xte->xe_referer)) )
    {
      xml_entity_t *up = xte->xe_referer;
      if ((NULL == up) || !(up_flags & XE_UP_MAY_TRANSIT))
	return XI_AT_END;
      /* No xte->xe_doc.xtd->xd_ref_count++; before this destroy */
      xte->xe_referer = NULL;
      xte_destroy ((xml_entity_t *) xte);
      memcpy (xte, up, sizeof (xml_entity_un_t));
      box_tag_modify (up, DV_ARRAY_OF_LONG);	/* do not call destructor, content still referenced due to copy *
						* set tag to array, not string cause strings aligned differently */
      dk_free_box ((box_t) up);
      if (up_flags & XE_UP_SIDEWAY)
        goto go_sideway;
      if (up_flags & XE_UP_MAY_TRANSIT_ONCE)
	return XI_RESULT;
      return (xte->_->xe_up ((xml_entity_t *) xte, node, up_flags));
    }
/* Plain non-attribute entity */
  /* At this point we know that there's a parent */
  if (up_flags & XE_UP_SIDEWAY)
    {
      XTE_SUB_STACK_POS(xte);
      goto go_sideway;
    }
  if (!xte_node_test (XTE_PARENT_SUBTREE(xte), node))
    return XI_AT_END;
  XTE_SUB_STACK_POS(xte);
  return XI_RESULT;

go_sideway:
/* in-place check or sideway go */
  if (up_flags & XE_UP_SIDEWAY_FWD)
    {
      if (up_flags & XE_UP_SIDEWAY_WR)
	rc = (xte->_->xe_next_sibling_wr ((xml_entity_t *) xte, node));
      else
	rc = (xte->_->xe_next_sibling ((xml_entity_t *) xte, node));
    }
  else
    {
      if (up_flags & XE_UP_SIDEWAY_WR)
	rc = (xte->_->xe_prev_sibling_wr ((xml_entity_t *) xte, node));
      else
        rc = (xte->_->xe_prev_sibling ((xml_entity_t *) xte, node));
    }
  return rc;
}


int
xte_first_child (xml_entity_t * xe, XT * node)
{
  int len, inx, res;
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * current = xte->xte_current;
  caddr_t head_name;
  if (NULL != xte->xe_attr_name)
    return XI_AT_END;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (current))
    return XI_AT_END;
  len = BOX_ELEMENTS (current);
  if (len <= 1)
    return XI_AT_END;
  head_name = XTE_HEAD_NAME (XTE_HEAD (current));
  if ((uname__comment == head_name) || (uname__pi == head_name))
    return XI_AT_END;
  XTE_ADD_STACK_POS(xte);
  for (inx = 1; inx < len; inx ++)
    {
      xte->xte_current = (caddr_t*) current[inx];
      xte->xte_child_no = inx;
      res = xte_down (xe, node);
      if (XI_RESULT == res)
	{
	  return XI_RESULT;
	}
    }
  XTE_SUB_STACK_POS(xte);
  return XI_AT_END;
}


int
xte_last_child (xml_entity_t * xe, XT * node)
{
  int len, inx, res;
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * current = xte->xte_current;
  caddr_t head_name;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (current))
    return XI_AT_END;
  len = BOX_ELEMENTS (current);
  if (len <= 1)
    return XI_AT_END;
  head_name = XTE_HEAD_NAME (XTE_HEAD (current));
  if ((uname__comment == head_name) || (uname__pi == head_name))
    return XI_AT_END;
  XTE_ADD_STACK_POS(xte);
  for (inx = len; inx > 0; inx --)
    {
      xte->xte_current = (caddr_t*) current[inx];
      xte->xte_child_no = inx;
      res = xte_down_rev (xe, node);
      if (XI_RESULT == res)
	return XI_RESULT;
    }
  XTE_SUB_STACK_POS(xte);
  return XI_AT_END;
}


int
xte_get_child_count_any (xml_entity_t * xe)
{
  int start;
  xml_tree_ent_t * xte = (xml_tree_ent_t *) (xe);
  int len;
  caddr_t * current;
  caddr_t head_name;
  current = xte->xte_current;
  if (NULL != xte->xe_attr_name)
    return 0;
  if (!xte_is_entity(current))
    return 0;
  head_name = XTE_HEAD_NAME (XTE_HEAD (current));
  if ((uname__comment == head_name) || (uname__pi == head_name))
    return 0;
  len = BOX_ELEMENTS (current)-1;
  for (start = 1; start <= len; start++)
    {
      caddr_t *chld = (caddr_t *)current[start];
      if (xte_is_entity(chld) && (uname__ref == XTE_HEAD_NAME(XTE_HEAD(chld))))
	{
	  int res = 0;
	  int rc = xe->_->xe_first_child (xe, (XT *) XP_NODE);
	  if (XI_RESULT != rc)
	    return 0;
	  res++;
	  while (XI_RESULT == xe->_->xe_next_sibling (xe, (XT *) XP_NODE))
	    res++;
	  xe->_->xe_up (xe, (XT *) XP_NODE, XE_UP_MAY_TRANSIT);
	  return res;
	}
    }
  return len;
}


int
xte_next_sibling (xml_entity_t * xe, XT * node)
{
  size_t old_child_no, new_child_no;
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  size_t len;
  caddr_t * current, * parent;
  if (NULL != xte->xe_attr_name)
    return XI_AT_END;
  if (!XTE_HAS_PARENT(xte))
    return xte_up ((xml_entity_t *) xte, node, (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY | XE_UP_SIDEWAY_FWD));
  current = xte->xte_current;
  parent = XTE_PARENT_SUBTREE(xte);
  len = BOX_ELEMENTS (parent);
  new_child_no = old_child_no = xte->xte_child_no;
#ifdef DEBUG
  if (BOX_ELEMENTS(parent) <= old_child_no)
    GPF_T1("Past-the-end child no in xte_next_sibling()");
  if ((parent[old_child_no] != (caddr_t) current) && !xte->xe_doc.xtd->xd_dom_mutation)
    GPF_T1("Corrupted child no in xte_next_sibling()");
#endif
  while (++new_child_no < len)
    {
      int down_res;
      caddr_t *curr = (caddr_t *) parent[new_child_no];
      xte->xte_child_no = (int) new_child_no;
      xte->xte_current = curr;
      if (xte_is_entity (curr))
	{
	  caddr_t * head = XTE_HEAD (curr);
	  caddr_t name = XTE_HEAD_NAME (head);
	  if (uname__ref == name)
	    {
	      down_res = xte_down ((xml_entity_t *)xte, node);
	      goto down_emulated;
	    }
	}
      down_res = xte_ent_name_test ((xml_entity_t *)xte, node) ? XI_RESULT : XI_AT_END;
down_emulated:
      if (XI_RESULT == down_res)
	return XI_RESULT;
    }
  xte->xte_current = current;
  xte->xte_child_no = (int) old_child_no;
  if (!XTE_HAS_2PARENTS(xte))
    return xte_up ((xml_entity_t *) xte, node, (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY | XE_UP_SIDEWAY_FWD));
  return XI_AT_END;
}


int
xte_next_sibling_wr (xml_entity_t * xe, XT * node)
{
  size_t old_child_no, new_child_no;
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  xp_instance_t * xqi = xe->xe_doc.xd->xd_top_doc->xd_xqi;
  size_t len;
  caddr_t * current, * parent;
  if (NULL != xte->xe_attr_name)
    return XI_AT_END;
  if (!XTE_HAS_PARENT(xte))
    return xte_up ((xml_entity_t *) xte, node, (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY | XE_UP_SIDEWAY_FWD | XE_UP_SIDEWAY_WR));
  current = xte->xte_current;
  parent = XTE_PARENT_SUBTREE(xte);
  len = BOX_ELEMENTS (parent);
  new_child_no = old_child_no = xte->xte_child_no;
#ifdef DEBUG
  if (BOX_ELEMENTS(parent) <= old_child_no)
    GPF_T1("Past-the-end child no in xte_next_sibling_wr()");
  if ((parent[old_child_no] != (caddr_t) current) && !xte->xe_doc.xtd->xd_dom_mutation)
    GPF_T1("Corrupted child no in xte_next_sibling_wr()");
#endif
  while (++new_child_no < len)
    {
      caddr_t *curr = (caddr_t *) parent[new_child_no];
      xte->xte_child_no = (int) new_child_no;
      xte->xte_current = curr;
      if (!txs_is_hit_in (xqi->xqi_text_node, (caddr_t *) xqi->xqi_qi, (xml_entity_t *) xte))
	continue;
      if (XI_RESULT == xte_down ((xml_entity_t *)xte, node))
	return XI_RESULT;
    }
  xte->xte_current = current;
  xte->xte_child_no = (int) old_child_no;
  if (!XTE_HAS_2PARENTS(xte))
    return xte_up ((xml_entity_t *) xte, node, (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY | XE_UP_SIDEWAY_FWD | XE_UP_SIDEWAY_WR));
  return XI_AT_END;
}


int
xte_prev_sibling (xml_entity_t * xe, XT * node)
{
  size_t old_child_no, new_child_no;
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * current, * parent;
  if (NULL != xte->xe_attr_name)
    return XI_AT_END;
  if (!XTE_HAS_PARENT(xte))
    return xte_up ((xml_entity_t *) xte, node, (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY /*| XE_UP_SIDEWAY_FWD*/));
  current = xte->xte_current;
  parent = XTE_PARENT_SUBTREE(xte);
  new_child_no = old_child_no = xte->xte_child_no;
#ifdef DEBUG
  if (BOX_ELEMENTS(parent) <= old_child_no)
    GPF_T1("Past-the-end child no in xte_prev_sibling()");
  if ((parent[old_child_no] != (caddr_t) current) && !xte->xe_doc.xtd->xd_dom_mutation)
    GPF_T1("Corrupted child no in xte_prev_sibling()");
#endif
  while (--new_child_no > 0)
    {
      int down_res;
      caddr_t *curr = (caddr_t *) parent[new_child_no];
      xte->xte_child_no = (int) new_child_no;
      xte->xte_current = curr;
      if (xte_is_entity (curr))
	{
	  caddr_t * head = XTE_HEAD (curr);
	  caddr_t name = XTE_HEAD_NAME (head);
	  if (uname__ref == name)
	    {
	      down_res = xte_down_rev ((xml_entity_t *)xte, node);
	      goto down_emulated;
	    }
	}
      down_res = xte_ent_name_test ((xml_entity_t *)xte, node) ? XI_RESULT : XI_AT_END;
down_emulated:
      if (XI_RESULT == down_res)
	return XI_RESULT;
    }
  xte->xte_current = current;
  xte->xte_child_no = (int) old_child_no;
  if (!XTE_HAS_2PARENTS(xte))
    return xte_up ((xml_entity_t *) xte, node, (XE_UP_MAY_TRANSIT | XE_UP_SIDEWAY /*| XE_UP_SIDEWAY_FWD*/));
  return XI_AT_END;
}


int
DBG_NAME(xte_attribute) (DBG_PARAMS xml_entity_t * xe, int nth, XT * node, caddr_t * res, caddr_t * name_ret)
{
  int inx, len;
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * current = xte->xte_current;
  caddr_t * first;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (current))
    return XI_NO_ATTRIBUTE;
  first = (caddr_t*) current[0];
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (first))
    return XI_NO_ATTRIBUTE;
  if (' ' == first[0][0])
    return XI_NO_ATTRIBUTE;
  if (-1 == nth)
    nth = 1;
  else
    nth = nth + 2;
  len = BOX_ELEMENTS (first);
  for (inx = nth; inx < len; inx += 2)
    {
      if (xt_node_test_match (node, first[inx]))
	{
	  if (name_ret)
	    XP_SET (name_ret, DBG_NAME(box_copy_tree) (DBG_ARGS first[inx]));
	  if (res)
	    XP_SET (res, DBG_NAME(box_copy_tree) (DBG_ARGS first[inx + 1]));
	  return inx;
	}
    }
  return XI_NO_ATTRIBUTE;
}


caddr_t xte_attrvalue (xml_entity_t * xe, caddr_t qname)
{
  int inx, len;
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * current = xte->xte_current;
  caddr_t * first;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (current))
    return NULL;
  first = (caddr_t*) current[0];
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (first))
    return NULL;
  if (' ' == first[0][0])
    return NULL;
  len = BOX_ELEMENTS (first);
  for (inx = 1; inx < len; inx += 2)
    {
      if (qname == first[inx])
	{
	  return box_copy_tree (first[inx + 1]);
	}
    }
  return NULL;
}


caddr_t xte_currattrvalue (xml_entity_t * xe)
{
  int inx, len;
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * current = xte->xte_current;
  caddr_t qname = xte->xe_attr_name;
  caddr_t * first;
  if (NULL == qname)
    GPF_T;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (current))
    GPF_T;
  first = (caddr_t*) current[0];
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (first))
    GPF_T;
  if (' ' == first[0][0])
    GPF_T;
  len = BOX_ELEMENTS (first);
  for (inx = 1; inx < len; inx += 2)
    {
      if (qname == first[inx])
	{
	  return box_copy_tree (first[inx + 1]);
	}
    }
#ifndef NDEBUG
  GPF_T;
#endif
  return box_dv_short_string("");
}


int
xte_data_attribute_count (xml_entity_t * xe)
{
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * current = xte->xte_current;
  caddr_t * first;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (current))
    return 0;
  first = (caddr_t*) current[0];
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (first))
    return 0;
  if (' ' == first[0][0])
    return 0;
/* XML tree entity contains only data attributes:
   1) namespace definitions are not stored at all and
   2) attribute indexing is in document's hashtables.
*/
  return (BOX_ELEMENTS (first) - 1)/2;
}


xml_entity_t *
DBG_NAME(xte_copy) (DBG_PARAMS xml_entity_t * xe)
{
  xml_tree_ent_t * copy = (xml_tree_ent_t *)dk_alloc_box (sizeof (xml_entity_un_t), DV_XML_ENTITY);
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  size_t stack_elems = (xte->xte_stack_max - xte->xte_stack_buf);
  size_t stack_sz = stack_elems * sizeof (xte_bmk_t);
  xte_bmk_t * newstack = (xte_bmk_t *) dk_alloc (stack_sz);
  memcpy (copy, xte, sizeof (xml_entity_un_t));
  xte->xe_doc.xtd->xd_ref_count++;
  memcpy (newstack, xte->xte_stack_buf, stack_sz);
  copy->xte_stack_buf = newstack;
  copy->xte_stack_top = newstack + (xte->xte_stack_top - xte->xte_stack_buf);
  copy->xte_stack_max = newstack + stack_elems;
  if (NULL != xte->xe_referer)
    xte->xe_referer = xte->xe_referer->_->xe_copy(xte->xe_referer);
  copy->xe_attr_name = box_copy_tree (xte->xe_attr_name);
  return ((xml_entity_t *) copy);
}


caddr_t
xp_box_number (caddr_t n)
{
  double d;
  dtp_t dtp = DV_TYPE_OF (n);
  if (dtp == DV_LONG_INT)
    return (n ? box_copy(n) : box_num_nonull(0));
  if (dtp == DV_SINGLE_FLOAT
      || dtp == DV_DOUBLE_FLOAT
      || dtp == DV_NUMERIC)
    return (box_copy (n));
  if (DV_STRINGP (n))
    {
      if (strlen (n) < 10
	  && !strchr (n, '.')
	  && !strchr (n, 'e'))
	return (box_num_nonull (atol (n)));
      {
	numeric_t num = numeric_allocate ();
	int rc = numeric_from_string (num, n);
	if (NUMERIC_STS_SUCCESS == rc)
	  return ((caddr_t) num);
      }
      if (1 == sscanf (n, "%lf", &d))
	return (box_double (d));
      sqlr_new_error ("XP420", "XI013", "can't convert string to number in number ()");
    }
  if (DV_ARRAY_OF_POINTER == dtp
      && DV_ARRAY_OF_POINTER == DV_TYPE_OF (XTE_HEAD (n)))
    {
      caddr_t res = NULL;
      xte_string_value_from_tree ((caddr_t *)n, &res, DV_NUMERIC);
      return res;
    }
  if (DV_XML_ENTITY == dtp)
     {
       caddr_t res = NULL;
      xe_string_value_1 ((xml_entity_t*) n, &res, DV_NUMERIC);
      return res;
    }
  sqlr_new_error ("XP420", "XI014", "not a string or number for number ()");
  return NULL; /*dummy*/
}


static void
xte_string_subvalue (caddr_t * current, dk_session_t *ses)
{
  int inx;
  dtp_t dtp = DV_TYPE_OF (current);
  if (DV_ARRAY_OF_POINTER == dtp)
    {
      int len;
      if (' ' == XTE_HEAD_NAME (XTE_HEAD (current))[0])
        return;
      len = BOX_ELEMENTS (current);
      for (inx = 1; inx < len; inx++)
	xte_string_subvalue ((caddr_t *) current[inx], ses);
      return;
    }
#ifdef DEBUG
  if (!DV_STRINGP (current))
    GPF_T;
#endif
  session_buffered_write (ses, (char *) current, box_length ((caddr_t) current) - 1);
}


void
DBG_NAME (xe_string_value_1) (DBG_PARAMS xml_entity_t * xe, caddr_t * ret, dtp_t dtp)
{
  if (xe->xe_attr_name)
    {
      caddr_t val = xe->_->xe_currattrvalue (xe);
      if (DV_NUMERIC == dtp)
	{
	  caddr_t n = xp_box_number (val);
	  dk_free_tree (val);
	  XP_SET (ret, n);
	  return;
	}
      XP_SET (ret, val);
    }
  else
    xe->_->DBG_NAME(xe_string_value) (DBG_ARGS xe, ret, dtp);
}

void
xe_sqlnarrow_string_value (xml_entity_t * xe, caddr_t * ret, dtp_t dtp)
{
  wcharset_t *charset = QST_CHARSET (xe->xe_doc.xd->xd_qi);

  xe_string_value_1 (xe, ret, dtp);
  if (IS_STRING_DTP (dtp) && ret)
    {
      unsigned char *ret0 = (unsigned char *) (ret[0]);
      uint32 inx, len;
      len = box_length (ret0);
      for (inx = 0; inx < len; inx++)
	{
	  if (ret0[inx] & ~0x7F)
	    {
	      caddr_t out = box_utf8_string_as_narrow ((char *)ret0, NULL, 0, charset);
	      XP_SET (ret, out);
	      break;
	    }
	}
    }
}

void
DBG_NAME (xte_string_value_from_tree) (DBG_PARAMS caddr_t * current, caddr_t * ret, dtp_t dtp)
{
  caddr_t str = NULL;
  dk_session_t * ses = NULL;
  caddr_t val = NULL;
  dtp_t cur_dtp = DV_TYPE_OF (current);
  if (DV_ARRAY_OF_POINTER == cur_dtp)
    {
      int len = BOX_ELEMENTS (current);
      switch (len)
        {
        case 1:
	  if (DV_NUMERIC == dtp)
	    XP_SET (ret, box_num_nonull (0));
	  else
	    XP_SET (ret, box_dv_short_string (""));
	  return;
	case 2:
	  {
	    caddr_t child = current[1];
	    if (DV_STRINGP (child))
	      str = child;
	    else
	      {
		ses = strses_allocate ();
		xte_string_subvalue ((caddr_t *)child, ses);
	      }
	    break;
	  }
	default:
	  {
	    int inx;
	    ses = strses_allocate ();
	    for (inx = 1; inx < len; inx++)
	       xte_string_subvalue ((caddr_t *)(current[inx]), ses);
	    break;
	  }
	}
    }
  else
    {
#ifdef DEBUG
      if (!DV_STRINGP (current))
	GPF_T;
#endif
      str = ((caddr_t) current);
    }
  if (ses)
    {
      if (strses_length (ses) >= MAX_BOX_LENGTH)
	{
	  strses_free (ses);
	  sqlr_new_error ("HT002", "XI038", "Text entity too long");
	}
      str = strses_string (ses);
      strses_free (ses);
    }
  if (IS_STRING_DTP (dtp) || (DV_UNKNOWN == dtp))
    {
      if (!ses)
	{
	  /* direct ref to tree, not the string of the cession */
	  str = DBG_NAME(box_copy) (DBG_ARGS str);
	  XP_SET (ret, str);
	}
      else
	{
	  XP_SET (ret, str);
	}
      return;
    }
  if (DV_NUMERIC == dtp)
    {
      val = xp_box_number (str);
      XP_SET (ret, val);
    }
  if (ses)
    dk_free_box (str);
  return;
}


void
DBG_NAME(xte_string_value) (DBG_PARAMS xml_tree_ent_t * xte, caddr_t * ret, dtp_t dtp)
{
  DBG_NAME(xte_string_value_from_tree) (DBG_ARGS xte->xte_current, ret, dtp);
}

int
xte_string_value_of_tree_is_nonempty (caddr_t *current)
{
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (current))
    {
      int inx, len = BOX_ELEMENTS (current);
      for (inx = 1; inx < len; inx++)
        {
          caddr_t child = current[inx];
          if (DV_STRINGP (child))
            {
              if (1 < box_length (child))
                return 1;
            }
          else if (xte_string_value_of_tree_is_nonempty ((caddr_t *)child))
            return 1;
        }
      return 0;
    }
  return (1 < box_length (current));
}


int
xte_string_value_is_nonempty (xml_tree_ent_t * xte)
{
  return xte_string_value_of_tree_is_nonempty (xte->xte_current);
}

#define XTE_IS_XSLT_OUTPUT(xte) \
  ((xte) && \
      IS_BOX_POINTER ((xte)->xte_current) && \
      DV_TYPE_OF ((xte)->xte_current) == DV_ARRAY_OF_POINTER && \
      BOX_ELEMENTS ((xte)->xte_current) > 0 && \
      DV_TYPE_OF (((caddr_t *) (xte)->xte_current)[0]) == DV_ARRAY_OF_POINTER && \
      (((caddr_t **) (xte)->xte_current)[0][0] == uname__root) && \
      ((NULL != xte->xe_doc.xtd->xout_doctype_system) || \
        (0 != xte->xe_doc.xtd->xout_omit_xml_declaration) || \
        (0 != xte->xe_doc.xtd->xout_standalone) || \
        (BOX_ELEMENTS (((caddr_t *) (xte)->xte_current)[0]) > 1)) \
      )

void
xte_serialize (xml_entity_t * xe, dk_session_t * ses)
{
  char *char_out_method;
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  xte_serialize_state_t xsst;
  xsst.xsst_entity = xte;
  xsst.xsst_cdata_names= xe->xe_doc.xd->xout_cdata_section_elements;
  xsst.xsst_ns_2dict = xe->xe_doc.xd->xd_ns_2dict;
  xsst.xsst_ct = NULL;
  xsst.xsst_qst = (caddr_t *)xe->xe_doc.xd->xd_qi;
  xsst.xsst_out_method = OUT_METHOD_OTHER;
  xsst.xsst_charset = NULL;
  xsst.xsst_do_indent = 0;
  xsst.xsst_indent_depth = 0;
  xsst.xsst_in_block = 0;
  xsst.xsst_dks_esc_mode = DKS_ESC_PTEXT;
  xsst.xsst_default_ns = xe->xe_doc.xd->xout_default_ns;
  xsst.xsst_hook = NULL;
  xsst.xsst_data = NULL;

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
      xsst.xsst_do_indent = xte->xe_doc.xtd->xout_indent;
      break;
    }

  xsst.xsst_charset = wcharset_by_name_or_dflt (xte->xe_doc.xd->xout_encoding, xte->xe_doc.xd->xd_qi);
  xsst.xsst_charset_meta = xte->xe_doc.xtd->xout_encoding_meta;
  if (XTE_IS_XSLT_OUTPUT (xte))
    {
      if (OUT_METHOD_XML == xsst.xsst_out_method)
	{
	  if (!xte->xe_doc.xtd->xout_omit_xml_declaration)
	    {
	      SES_PRINT (ses, "<?xml version=\"1.0\" encoding=\"");
	      SES_PRINT (ses, CHARSET_NAME (xsst.xsst_charset, "ISO-8859-1"));
	      SES_PRINT (ses, "\"");
	      if (xte->xe_doc.xtd->xout_standalone)
		SES_PRINT (ses, " standalone=\"yes\"");
	      SES_PRINT (ses, " ?>");
	      if (xsst.xsst_do_indent)
		SES_PRINT (ses, "\n");
	    }
	}
      if ((xte->xe_doc.xtd->xout_doctype_system) &&
	(
	  (OUT_METHOD_XML == xsst.xsst_out_method) ||
	  (OUT_METHOD_HTML == xsst.xsst_out_method) ||
	  (OUT_METHOD_XHTML == xsst.xsst_out_method) ) )
	{
	  caddr_t **first_child = NULL;
	  caddr_t **current = (caddr_t **) xte->xte_current;
	  int inx;
          int curr_len;
	  if (	(DV_ARRAY_OF_POINTER == DV_TYPE_OF (current)) &&
	    (' ' != current[0][0][0]) )
	    {
	      first_child = current;
	      goto doctype_may_be_printed;
	    }
          curr_len = ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (current)) ?
		(int) BOX_ELEMENTS (current) : 0);
	  for (inx = 1; inx < curr_len; inx ++)
	    {
	      caddr_t **chld = (caddr_t **)(current[inx]);
	      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (chld))
	        continue;
	      if (' ' != chld[0][0][0])
	        {
		  first_child = chld;
		  while (++inx < curr_len)
		    {
		      chld = (caddr_t **)(current[inx]);
		      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (chld))
			continue;
		      if (' ' != chld[0][0][0])
			goto doctype_may_not_be_printed;
		    }
		  goto doctype_may_be_printed;
		}
	    }
	  goto doctype_may_not_be_printed;
doctype_may_be_printed:
	  SES_PRINT (ses, "<!DOCTYPE ");
	  SES_PRINT (ses, first_child[0][0]);
	  if (xte->xe_doc.xtd->xout_doctype_public)
	    {
	      SES_PRINT (ses, " PUBLIC \"");
	      SES_PRINT (ses, xte->xe_doc.xtd->xout_doctype_public);
	      SES_PRINT (ses, "\" \"");
	    }
	  else
	    SES_PRINT (ses, " SYSTEM \"");
	  SES_PRINT (ses, xte->xe_doc.xtd->xout_doctype_system);
	  SES_PRINT (ses, "\">");
	  if (xsst.xsst_do_indent)
	    SES_PRINT (ses, "\n");
doctype_may_not_be_printed:
	  ;
	}
    }

  QR_RESET_CTX
    {
      xte_serialize_1 (xte->xte_current, ses, &xsst);
    }
  QR_RESET_CODE
    {
      caddr_t err;
      POP_QR_RESET;
      err = thr_get_error_code (THREAD_CURRENT_THREAD);
      if (SESSION_IS_STRING (ses))
	{
	  strses_flush (ses);
	  if (ARRAYP(err))
	    {
	      SES_PRINT (ses, "<error>");
	      SES_PRINT (ses, "<code>");
	      SES_PRINT (ses, ERR_STATE(err));
	      SES_PRINT (ses, "</code>");
	      SES_PRINT (ses, "<message>");
	      SES_PRINT (ses, ERR_MESSAGE(err));
	      SES_PRINT (ses, "</message>");
	      SES_PRINT (ses, "</error>");
	    }
	}
      dk_free_tree (err);
    }
  END_QR_RESET;
}


/* A special serialization format for uint32 values that are probably very small.
This format is slightly more compact than UTF-8 and allow faster processing and
also preserves sorting but it does not provide error trapping/recovery and
it can contain zero bytes in the middle.

This is the layout of the first byte of the encoded sequence:

      When zero, the rest is 7 significant bits of a values that is less than 0x80.
      When one, two next bits indicate the number of bytes in the sequence:
     /
    / __ 0x00 - one more byte, 0x20 - two more bytes, 0x40 - three more, 0x60 - four.
   / / /
  / / / __________ These are bits of the most significant nonzero byte of the value.
 / / / /   / / / /
8 4 2 1 : 8 4 2 0

Other bytes of the sequence contain less significant bits of the value:
If value is less than 0x80 then there is only one byte in the sequence - the unchanged value.
If value is less than 0x2000 then one more byte contains right 8 bits of the value.
If value is less than 0x200000 then two more bytes contain right 16 bits of the value.
If value is less than 0x20000000 then three more bytes contain right 24 bits of the value.
Otherwise four more bytes contain the whole value so the first byte is 0xE0.
If the first byte is greater than 0xE0 then it is an encoding error. Application that forms
a stream may use such values for delimiters, special tags etc.
*/

#define SES_PRINT_UINT32_PACKED(val,ses) \
  do { \
      uint32 _print_packed_aux = (uint32) (val); \
      if (_print_packed_aux & ~0x7f) \
	ses_print_uint32_packed__aux (_print_packed_aux, ses); \
      else \
	session_buffered_write_char ((unsigned char)_print_packed_aux, ses); \
     } while (0)


void ses_print_uint32_packed__aux (uint32 len, dk_session_t * ses)
{
  unsigned char buf[5];
#ifdef DEBUG
  if (!(len & ~0x7F))
    GPF_T;
#endif
  if (!(len & ~0x1Fff))
    {
      buf[0] = (unsigned char) ((len >> 8) | 0x80);
      buf[1] = (unsigned char) len; /* intentional overflow here. */
      session_buffered_write (ses, (caddr_t)buf, 2);
      return;
    }
  if (!(len & ~0x1Fffff))
    {
      buf[0] = (unsigned char) ((len >> 16) | 0xA0);
      buf[1] = (unsigned char) (len >> 8); /* intentional overflow here. */
      buf[2] = (unsigned char) len; /* intentional overflow here. */
      session_buffered_write (ses, (caddr_t)buf, 3);
      return;
    }
  if (!(len & ~0x1Fffffff))
    {
      buf[0] = (unsigned char) ((len >> 24) | 0xC0);
      buf[1] = (unsigned char) (len >> 16); /* intentional overflow here. */
      buf[2] = (unsigned char) (len >> 8); /* intentional overflow here. */
      buf[3] = (unsigned char) len; /* intentional overflow here. */
      session_buffered_write (ses, (caddr_t)buf, 4);
      return;
    }
  buf[0] = 0xE0;
  buf[1] = (unsigned char) (len >> 24); /* intentional overflow here. */
  buf[2] = (unsigned char) (len >> 16); /* intentional overflow here. */
  buf[3] = (unsigned char) (len >> 8); /* intentional overflow here. */
  buf[4] = (unsigned char) len; /* intentional overflow here. */
  session_buffered_write (ses, (caddr_t)buf, 5);
  return;
}


uint32 ses_read_uint32_packed (dk_session_t * ses)
{
  unsigned char hdr = session_buffered_read_char (ses);
  if (!(hdr & 0x80))
    return hdr;
  switch (hdr >> 5)
    {
    case 0x80 >> 5:
      return (((uint32)(hdr & 0x1f)) << 8) | session_buffered_read_char (ses);
    case 0xA0 >> 5:
      {
        unsigned char buf[2];
        session_buffered_read (ses, (char *)buf, 2);
        return (((uint32)(hdr & 0x1f)) << 16) | (((uint32)(buf[0])) << 8) | buf[1];
      }
    case 0xC0 >> 5:
      {
        unsigned char buf[3];
        session_buffered_read (ses, (char *)buf, 3);
        return (((uint32)(hdr & 0x1f)) << 24) | (((uint32)(buf[0])) << 16) | (((uint32)(buf[1])) << 8) | buf[2];
      }
    default:
      {
        unsigned char buf[4];
        if (hdr > 0xE0)
          return 0xffffff00 | hdr;
        session_buffered_read (ses, (char *)buf, 4);
        return (((uint32)(buf[0])) << 24) | (((uint32)(buf[1])) << 16) | (((uint32)(buf[2])) << 8) | buf[3];
      }
    }
}


void
xte_serialize_packed_elt (caddr_t *elt, id_hash_t *elt_names, id_hash_t *attr_names, dk_session_t * ses)
{
  int elt_len = BOX_ELEMENTS (elt);
  caddr_t *head = (caddr_t *)(elt[0]);
  int head_len = BOX_ELEMENTS (head);
  int ctr;
  uint32 len;
  SES_PRINT_UINT32_PACKED (((elt_len << 1) - 1), ses); /* (number of children w/o the head) * 2 + 1 */
  SES_PRINT_UINT32_PACKED (head_len / 2, ses); /* number of attributes with no changes */
  {
    caddr_t name = head[0];
    ptrlong *hit = (ptrlong *)id_hash_get (elt_names, (caddr_t)(&name));
    if (NULL == hit)
      {
	ptrlong name_idx = elt_names->ht_count;
	len = box_length (name) - 1;
	SES_PRINT_UINT32_PACKED ((len << 1), ses);
	session_buffered_write (ses, name, len);
        id_hash_set (elt_names, (caddr_t)(&name), (caddr_t)(&name_idx));
      }
    else
      SES_PRINT_UINT32_PACKED ((hit[0] << 1) | 1, ses);
  }
  for (ctr = 1; ctr < head_len; ctr += 2)
    {
      caddr_t name = head [ctr];
      caddr_t attr_value = head [ctr + 1];
      ptrlong *hit = (ptrlong *)id_hash_get (attr_names, (caddr_t)(&name));
      if (NULL == hit)
        {
	  ptrlong name_idx = attr_names->ht_count;
	  len = box_length (name) - 1;
	  SES_PRINT_UINT32_PACKED ((len << 1), ses);
	  session_buffered_write (ses, name, len);
          id_hash_set (attr_names, (caddr_t)(&name), (caddr_t)(&name_idx));
        }
      else
        SES_PRINT_UINT32_PACKED ((hit[0] << 1) | 1, ses);
      len = box_length (attr_value) - 1;
      SES_PRINT_UINT32_PACKED (len, ses);
      session_buffered_write (ses, attr_value, len);
    }
  for (ctr = 1; ctr < elt_len; ctr++)
    {
      caddr_t *child = (caddr_t *)(elt[ctr]);
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (child))
        xte_serialize_packed_elt (child, elt_names, attr_names, ses);
      else
        {
	  len = box_length (child) - 1;
	  SES_PRINT_UINT32_PACKED ((len << 1), ses);
	  session_buffered_write (ses, (caddr_t)child, len);
	}
    }
}


void
xte_serialize_packed (caddr_t *src_tree, dtd_t *dtd, dk_session_t * ses)
{
/* First of all write magic bytes */
  session_buffered_write (ses, XPACK_PREFIX, XPACK_PREFIX_LEN);
/* If there's a nonempty DTD, write it */
  if (NULL != dtd)
    {
      unsigned char *buf;
      int len = dtd->ed_xper_text_length;
      if (0 == len)
        len = dtd_get_buffer_length (dtd);
      if (0 < len)
        {
	  buf = (unsigned char *) dk_alloc (len);
	  dtd_save_to_buffer (dtd, buf, len);
	  session_buffered_write_char (XPACK_START_DTD, ses);
	  SES_PRINT_UINT32_PACKED (len, ses);
	  session_buffered_write (ses, (char *)buf, len);
	  dk_free (buf, len);
        }
    }
/* Go write the tree */
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (src_tree))
    {
      id_hash_t *elt_names = id_hash_allocate (1021, sizeof (caddr_t), sizeof (ptrlong), strhash, strhashcmp);
      id_hash_t *attr_names = id_hash_allocate (1021, sizeof (caddr_t), sizeof (ptrlong), strhash, strhashcmp);
      xte_serialize_packed_elt (src_tree, elt_names, attr_names, ses);
      id_hash_free (elt_names);
      id_hash_free (attr_names);
    }
  else
    {
      uint32 len = box_length (src_tree) - 1;
      SES_PRINT_UINT32_PACKED ((len << 1), ses);
      session_buffered_write (ses, (caddr_t)src_tree, len);
    }
}


/* Please do not tell me that this function is hard to read and understand, that it should be
divided into smaller functions etc. I need _speed_ */
void
xte_deserialize_packed (dk_session_t *ses, caddr_t **ret_tree, dtd_t **ret_dtd)
{
#ifdef DEBUG /* When in debug, I should test the growth of stacks and dictionaries */
#define INIT_STACK_SIZE 4
#define INIT_DICT_SIZE 4
#else /* In release, i prefer to never see them growing :) */
#define INIT_STACK_SIZE XML_PARSER_MAX_DEPTH
#define INIT_DICT_SIZE 0x800
#endif
  size_t stack_use = 0;
  size_t elt_names_use = 0;
  size_t attr_names_use = 0;
  size_t stack_size = INIT_STACK_SIZE;
  size_t elt_names_size = INIT_DICT_SIZE;
  size_t attr_names_size = INIT_DICT_SIZE;
  caddr_t **tree_stack = (caddr_t **)dk_alloc_box_zero (stack_size * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  size_t *pos_stack = (size_t *)dk_alloc (stack_size * 2 * sizeof (size_t));
  caddr_t *elt_names = (caddr_t *)dk_alloc (elt_names_size * sizeof (caddr_t));
  caddr_t *attr_names = (caddr_t *)dk_alloc (attr_names_size * sizeof (caddr_t));
  uint32 descr, strg_len;
  caddr_t strg;
  size_t child_idx, elt_len;
  size_t attr_idx, head_len;
  caddr_t *elt = NULL, *head;
  CATCH_READ_FAIL (ses)
  {
      {
        char buf[XPACK_PREFIX_LEN];
        session_buffered_read (ses, buf, XPACK_PREFIX_LEN);
	if (memcmp (buf, XPACK_PREFIX, XPACK_PREFIX_LEN))
	  goto data_corrupted;
      }

read_new_elt:
    descr = ses_read_uint32_packed (ses);
    if ((0xffffff00 | XPACK_START_DTD) == descr)
      {
        int dtd_len = (int) ses_read_uint32_packed (ses);
        caddr_t dtd_string;
	if (dtd_len >= 0x1000000)
	  {
	    goto data_corrupted; /* see below */
	  }
        dtd_string = dk_alloc_box (dtd_len, DV_STRING);
        session_buffered_read (ses, dtd_string, dtd_len);
        if (NULL != ret_dtd)
          {
	    if (NULL == ret_dtd[0])
	      ret_dtd[0] = dtd_alloc ();
	    dtd_load_from_buffer (ret_dtd[0], dtd_string);
	  }
	dk_free_box (dtd_string);
	goto read_new_elt; /* see above */
      }
    /* no goto */

    if (!(descr & 1)) /* a string */
      {
        strg_len = (descr >> 1);
        strg = dk_alloc_box (strg_len + 1, DV_STRING);
        session_buffered_read (ses, strg, strg_len);
        strg [strg_len] = '\0';
        elt = (caddr_t *)strg;
        goto reduce; /* see below */
      }
/* If we're here then it's an element */
    elt_len = (descr >> 1) + 1;
    head_len = ses_read_uint32_packed (ses) * 2 + 1;
    child_idx = 1;
    if ((elt_len >= (0x1000000 / sizeof (caddr_t))) || (head_len >= (0x1000000 / sizeof (caddr_t))))
      {
        goto data_corrupted; /* see below */
      }
    tree_stack [stack_use] = elt = (caddr_t *) dk_alloc_box_zero (elt_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
    head = (caddr_t *) dk_alloc_box_zero (head_len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
    elt[0] = (caddr_t)head;
/* Reading the name of the element: */
    descr = ses_read_uint32_packed (ses);
    if (!(descr & 1))
      {
        strg_len = (descr >> 1);
        strg = box_dv_ubuf (strg_len);
        session_buffered_read (ses, strg, strg_len);
        strg [strg_len] = '\0';

        if (elt_names_use == elt_names_size)
          {
            caddr_t *new_elt_names = (caddr_t *)dk_alloc (elt_names_size * 4 * sizeof (caddr_t));
            memcpy (new_elt_names, elt_names, elt_names_size * sizeof (caddr_t));
            dk_free (elt_names, elt_names_size * sizeof (caddr_t));
            elt_names = new_elt_names;
            elt_names_size *= 4;
          }
	strg = box_dv_uname_from_ubuf (strg);
        elt_names [elt_names_use++] = strg;
      }
    else
      {
        descr = descr >> 1;
        if (descr >= elt_names_use)
          goto data_corrupted; /* see below */
        strg = box_copy (elt_names[descr]);
      }
    head[0] = strg;
/* Reading all attributes of the element: */
    for (attr_idx = 1; attr_idx < head_len; attr_idx += 2)
      {
/* Reading the name of the attribute: */
	descr = ses_read_uint32_packed (ses);
	if (!(descr & 1))
	  {
	    strg_len = (descr >> 1);
	    strg = box_dv_ubuf (strg_len);
	    session_buffered_read (ses, strg, strg_len);
	    strg [strg_len] = '\0';
	    if (attr_names_use == attr_names_size)
	      {
		caddr_t *new_attr_names = (caddr_t *)dk_alloc (attr_names_size * 4 * sizeof (caddr_t));
		memcpy (new_attr_names, attr_names, attr_names_size * sizeof (caddr_t));
		dk_free (attr_names, attr_names_size * sizeof (caddr_t));
		attr_names = new_attr_names;
		attr_names_size *= 4;
	      }
	    strg = box_dv_uname_from_ubuf (strg);
	    attr_names [attr_names_use++] = strg;
	  }
	else
	  {
	    descr = descr >> 1;
	    if (descr >= attr_names_use)
	      goto data_corrupted; /* see below */
	    strg = box_copy (attr_names[descr]);
	  }
	head [attr_idx] = strg;
/* Reading the value of the attribute: */
	strg_len = ses_read_uint32_packed (ses);
	strg = dk_alloc_box (strg_len + 1, DV_STRING);
	session_buffered_read (ses, strg, strg_len);
	strg [strg_len] = '\0';
	head [attr_idx + 1] = strg;
      }
/* Now the head is complete. */
    if (child_idx == elt_len)
      goto reduce; /* see below */
/* Preparing to read children: */
    pos_stack [stack_use * 2 + 1] = elt_len;
    pos_stack [stack_use * 2] = child_idx;
    stack_use ++;
    if (stack_use == stack_size)
      {
	caddr_t **new_tree_stack = (caddr_t **)dk_alloc_box_zero (stack_size * 4 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	size_t *new_pos_stack = (size_t *)dk_alloc (stack_size * 2 * 4 * sizeof (size_t));
	memcpy (new_tree_stack, tree_stack, stack_size * sizeof (caddr_t));
	memcpy (new_pos_stack, pos_stack, stack_size * 2 * sizeof (size_t));
	dk_free_box ((box_t) tree_stack);
	dk_free (pos_stack, stack_size * 2 * sizeof (size_t));
	tree_stack = new_tree_stack;
	pos_stack = new_pos_stack;
	stack_size *= 4;
      }
    goto read_new_elt; /* see above */

reduce: /* We come here when an element is complete and stack should be shortened */
    while (stack_use--)
      {
	caddr_t *parent = tree_stack [stack_use];
	child_idx = pos_stack [stack_use * 2];
	elt_len = pos_stack [stack_use * 2 + 1];
	parent [child_idx++] = (caddr_t)elt;
	tree_stack [stack_use+1] = NULL; /* This is to prevent double free on error */
	if (child_idx != elt_len)
	  {
	    pos_stack [stack_use * 2] = child_idx;
	    stack_use++;
            goto read_new_elt; /* see above */
	  }
	elt = parent;
      }
    goto complete; /* see below */

data_corrupted: /* We come here if there's a reference to an undefined name index */
#ifdef DEBUG
    GPF_T;
#endif
    dk_free_tree ((box_t) tree_stack);
    tree_stack = NULL;
    elt = NULL;
    /* no goto */

complete: /* We come here from reduce if the top level element is complete or from data_corrupted */
    dk_free_box ((box_t) tree_stack);
  }
  FAILED
  {
    dk_free_tree ((box_t) tree_stack);
    tree_stack = NULL;
    elt = NULL;
  }
  END_READ_FAIL (ses);
  xte_tree_check ((caddr_t) elt);
  dk_free (pos_stack, stack_size * 2 * sizeof (size_t));
  dk_free (elt_names, elt_names_size * sizeof (caddr_t));
  dk_free (attr_names, attr_names_size * sizeof (caddr_t));
  xte_tree_check ((caddr_t) elt);
  ret_tree[0] = elt;
}


int
xte_serialization_len (db_buf_t str)
{
  scheduler_io_data_t iod;
  dk_session_t ses;
  caddr_t x;
  memset (&ses, 0, sizeof (ses));
  memset (&iod, 0, sizeof (iod));
  ses.dks_in_buffer = (char *) str;
  ses.dks_in_fill = INT32_MAX;
  SESSION_SCH_DATA ((&ses)) = &iod;
  ses.dks_cluster_flags = DKS_LEN_ONLY;
  x = (caddr_t) read_object (&ses);
  dk_free_tree (x);
  return ses.dks_in_read;
}


#if 0
void
xe_box_serialize (caddr_t xe, dk_session_t * ses)
{
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  close_tag_t * ct = NULL;
  xte_serialize_1 (xte->xte_current, ses, &ct);
}
#endif

void
xte_log_update (xml_entity_t * xe, dk_session_t * log)
{
  dk_session_t * xml_ses = strses_allocate ();
  xe->_->xe_serialize (xe, xml_ses);
  strses_serialize ((caddr_t)(xml_ses), log);
  dk_free_box ((box_t) xml_ses);
}

void
xte_destroy (xml_entity_t * xe)
{
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  xml_tree_doc_t * xtd = xte->xe_doc.xtd;
#ifdef MALLOC_DEBUG
  if (xte->xe_doc.xd->xd_top_doc)
    {
      dk_set_t refs = xte->xe_doc.xd->xd_top_doc->xd_referenced_entities;
      caddr_t item;
      DO_SET (xml_entity_t *, ref_ent, &refs)
	{
	  dk_alloc_box_assert(ref_ent);
	  if (ref_ent==xe)
	    GPF_T1("attempt of destroying of an referenced entity");
	}
      END_DO_SET();
      while (NULL != (item = dk_set_pop (&(xtd->xtd_garbage_boxes))))
        dk_free_box (item);
      while (NULL != (item = dk_set_pop (&(xtd->xtd_garbage_trees))))
        dk_free_tree (item);
    }
#endif
  dk_free_box ((box_t) xte->xe_referer);
  dk_free (xte->xte_stack_buf, (xte->xte_stack_max - xte->xte_stack_buf) * sizeof (xte_bmk_t));
  dk_free_tree (xte->xe_attr_name);
  xtd->xd_ref_count--;
  if (0 >= xtd->xd_ref_count)
    {
#if 0 /* This is no longer valid because document cache can release the last entity on the document
and the document will stay locked in that time */
#ifdef DEBUG
      if (0 != xtd->xd_dom_lock_count)
        GPF_T1("attempt of destroying of a DOM-locked entity");
#endif
#endif
      if (NULL != xtd->xd_dtd)
	dtd_release (xtd->xd_dtd);
      dk_free_box ((caddr_t)(xtd->xd_id_dict));
      dk_free_box (xtd->xd_id_scan);
      xte_tree_check (xtd->xtd_tree);
      dk_free_tree ((caddr_t) xtd->xtd_tree);
      dk_free_box (xtd->xd_uri);
      if (NULL != xtd->xtd_wrs)
	{
	  id_hash_free (xtd->xtd_wrs);
	}
      DO_SET (xml_entity_t *, refd, &xtd->xd_referenced_entities)
	{
	  XD_DOM_RELEASE (refd->xe_doc.xd);
#ifdef MALLOC_DEBUG
	  refd->xe_doc.xd->xd_top_doc = NULL;
#endif
	  dk_free_box ((caddr_t) refd);
	}
      END_DO_SET();
      dk_set_free (xtd->xd_referenced_entities);
      dk_free_tree (xtd->xout_method);
      dk_free_tree (xtd->xout_version);
      dk_free_tree (xtd->xout_encoding);
      dk_free_tree (xtd->xout_doctype_public);
      dk_free_tree (xtd->xout_doctype_system);
      if (xtd->xout_cdata_section_elements)
	{
	  id_hash_iterator_t hit;
	  char **kp;
	  char **dp;
	  id_hash_iterator (&hit, xtd->xout_cdata_section_elements);
	  while (hit_next (&hit, (char **)&kp, (char **)&dp))
	    {
	      if (kp)
		dk_free_box ((box_t) *kp);
	      if (dp)
		dk_free_box (*dp);
	    }
	  id_hash_free (xtd->xout_cdata_section_elements);
	}
      dk_free_tree (xtd->xout_media_type);
      xml_ns_2dict_clean (&(xtd->xd_ns_2dict));
      dk_free_box ((caddr_t) xtd);
    }
}


query_instance_t *
qi_top_qi (query_instance_t * qi)
{
  if ((-1 == (ptrlong)qi) || (NULL == qi))
    return NULL;
  while (IS_POINTER (qi->qi_caller))
    qi = qi->qi_caller;
  return qi;
}


xml_tree_ent_t *
DBG_NAME(xte_from_tree) (DBG_PARAMS caddr_t tree, query_instance_t * qi)
{
  size_t stack_elems = 0x10;
  size_t stack_sz = stack_elems * sizeof (xte_bmk_t);
  xte_bmk_t * newstack = (xte_bmk_t *) dk_alloc (stack_sz);
  xml_tree_ent_t * xte = (xml_tree_ent_t*) dk_alloc_box_zero (sizeof (xml_entity_un_t), DV_XML_ENTITY);
  NEW_BOX_VARZ (xml_tree_doc_t, xtd);
  xte->_ = &xec_tree_xe;
#ifdef MALLOC_DEBUG
  xtd->xd_dbg_file = (char *) file;
  xtd->xd_dbg_line = line;
#endif
  xtd->xd_qi = qi_top_qi (qi);
  xtd->xd_top_doc = (xml_doc_t *) xtd;
  xtd->xd_ref_count = 1;
  xtd->xtd_tree = (caddr_t *) tree;
  xtd->xd_default_lh = server_default_lh;
  xtd->xd_cost = XML_BIG_DOC_COST;
  xtd->xd_weight = 0; /* Unknown */
  xte->xe_doc.xtd = xtd;
  xte->xte_stack_top = xte->xte_stack_buf = newstack;
  xte->xte_stack_max = newstack + stack_elems;
  xte->xte_current = (caddr_t *) tree;
  xte->xte_child_no = 0;
  return xte;
}

void
xte_set_qi (caddr_t xte, query_instance_t * qi)
{
  dtp_t dtp = DV_TYPE_OF (xte);
  if (DV_ARRAY_OF_POINTER == dtp)
    {
      int inx;
      DO_BOX (caddr_t, elt, inx, (caddr_t*)xte)
	{
	  xte_set_qi (elt, qi);
	}
      END_DO_BOX;
    }
  else if (DV_XML_ENTITY == dtp && XE_IS_TREE ((xml_tree_ent_t*)xte))
    ((xml_tree_ent_t*)xte)->xe_doc.xtd->xd_qi = qi;
}


#define B_SET(x, y) dk_free_tree (x); x = box_copy_tree (y)
void
xte_copy_output_elements (struct xml_tree_ent_s *xte, struct xslt_sheet_s *sheet)
{
  id_hash_iterator_t hit;
  char **kp;
  caddr_t *dp;

  B_SET (xte->xe_doc.xd->xout_method, sheet->xout_method);
  B_SET (xte->xe_doc.xd->xout_version, sheet->xout_version);
  B_SET (xte->xe_doc.xd->xout_encoding, sheet->xout_encoding);
  xte->xe_doc.xd->xout_encoding_meta = sheet->xout_encoding_meta;
  xte->xe_doc.xd->xout_omit_xml_declaration = sheet->xout_omit_xml_declaration;
  xte->xe_doc.xd->xout_standalone = sheet->xout_standalone;
  B_SET (xte->xe_doc.xd->xout_doctype_public, sheet->xout_doctype_public);
  B_SET (xte->xe_doc.xd->xout_doctype_system, sheet->xout_doctype_system);
  xte->xe_doc.xd->xout_indent = sheet->xout_indent;
  B_SET (xte->xe_doc.xd->xout_media_type, sheet->xout_media_type);

  if (xte->xe_doc.xd->xout_cdata_section_elements)
    {
      id_hash_iterator (&hit, (id_hash_t *)xte->xe_doc.xd->xout_cdata_section_elements);
      while (hit_next (&hit, (char **) &kp, (char **)&dp))
	{
	  if (kp)
	    dk_free_box (*kp);
	  if (dp)
	    dk_free_box (*dp);
	}
      id_hash_clear ((id_hash_t *)xte->xe_doc.xd->xout_cdata_section_elements);
    }
  if (sheet->xout_cdata_section_elements)
    {
      if (!xte->xe_doc.xd->xout_cdata_section_elements)
	xte->xe_doc.xd->xout_cdata_section_elements = id_str_hash_create (10);

      id_hash_iterator (&hit, sheet->xout_cdata_section_elements);
      while (hit_next (&hit, (char **)&kp, (char **)&dp))
	{
	  caddr_t kp1 = *kp ? box_dv_short_string (*kp) : NULL;
	  caddr_t dp1 = *dp ? box_num ((ptrlong)*dp) : NULL;
	  id_hash_set ((id_hash_t *)xte->xe_doc.xd->xout_cdata_section_elements, (caddr_t) &kp1, (caddr_t) &dp1);
	}
    }
  else if (xte->xe_doc.xd->xout_cdata_section_elements)
    {
      id_hash_free ((id_hash_t *)xte->xe_doc.xd->xout_cdata_section_elements);
      xte->xe_doc.xd->xout_cdata_section_elements = NULL;
    }
}

char
xte_word_count_1 (caddr_t * tree, xml_tree_doc_t * xtd, wpos_t *poss, lang_handler_t *lh, char hider)
{
  xe_word_ranges_t locals;
  wpos_t word_count;
  int inx;
  dtp_t dtp = DV_TYPE_OF (tree);
  locals.xewr_main_beg = poss[0];
  locals.xewr_attr_tree_end = locals.xewr_attr_this_end = locals.xewr_attr_beg = poss[1];
  if (is_string_type (dtp))
    {
      word_count = lh_count_words(
	&eh__UTF8, lh,
	(const char *)tree, box_length((caddr_t)tree),
	lh->lh_is_vtb_word );
      if (0 != word_count)
	hider = XML_MKUP_TEXT;
      poss[0] = locals.xewr_main_end = locals.xewr_main_beg + word_count;
      goto store_positions; /* see below */
    }
  if (DV_ARRAY_OF_POINTER == dtp)
    {
      caddr_t * head = ((caddr_t**) tree)[0];
      int attr_idx, attr_idx_max;
      caddr_t name;
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (head))
	sqlr_new_error ("42000", "XI015", "Bad XML entity tree in word counting routine");
	name = head[0];
	if (!DV_STRINGP (name))
	  sqlr_new_error ("42000", "XI016", "Bad XML entity tree in word counting routine");
	if (' ' == name[0])
	  {
	    if (uname__root == name)
	      goto process_tag; /* see below */
	    return hider;
	  }
	if(box_length(name)>(XML_MAX_EXP_NAME-2))
	  sqlr_new_error ("42000", "XI017", "Bad XML entity tree in word counting routine");
process_tag:
      attr_idx_max = BOX_ELEMENTS(head) - 1;
      for (attr_idx = 1; attr_idx < attr_idx_max; attr_idx += 2)
	{
	  if (!strcmp(head[attr_idx], "xml:lang"))
	    {
	      lh = lh_get_handler(head[attr_idx+1]);
	      break;
	    }
	}
      for (attr_idx = 1; attr_idx < attr_idx_max; attr_idx += 2)
	{
	  char *attr_value;
	  if (' ' == head[attr_idx][0])
	    continue;
	  attr_value = head[attr_idx+1];
	  word_count = lh_count_words(
	    &eh__UTF8, lh,
	    (const char *)attr_value, box_length((caddr_t)attr_value),
	    lh->lh_is_vtb_word );
	  locals.xewr_attr_this_end += 2+word_count;	/* 1 opening name mark + word_count of value's words + 1 closing name mark */
	}
      poss[1] = locals.xewr_attr_this_end;
      if((XML_MKUP_ETAG != hider) && (locals.xewr_main_beg>0))
	locals.xewr_main_beg--;
      else
	poss[0] += 1;
      hider = XML_MKUP_STAG;
      for (inx = 1; inx < (int) BOX_ELEMENTS (tree); inx++)
	hider = xte_word_count_1 ((caddr_t*) tree[inx], xtd, poss, lh, hider);
      locals.xewr_main_end = poss[0] + 1;
      locals.xewr_attr_tree_end = poss[1];
      hider = XML_MKUP_ETAG;
      goto store_positions; /* see below */
    }
  return hider;
store_positions:
  if ((locals.xewr_main_end != locals.xewr_main_beg) || (locals.xewr_attr_tree_end != locals.xewr_attr_beg))
    {
      if (NULL == xtd->xtd_wrs)
	xtd->xtd_wrs = id_hash_allocate (1001, sizeof (void *), sizeof (xe_word_ranges_t), voidptrhash, voidptrhashcmp);
      id_hash_set (xtd->xtd_wrs, (caddr_t)(&tree), (caddr_t) (&locals));
    }
  return hider;
}


void
xte_word_range (xml_entity_t * xe, wpos_t * start, wpos_t * end)
{
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * ent = xte->xte_current;
  xml_tree_doc_t * xtd = xte->xe_doc.xtd;
  xe_word_ranges_t *locals;
  if (NULL == xtd->xtd_wrs)
    {
      char hider = '\0';
      wpos_t poss[2];
      poss[0] = 0;
      poss[1] = FIRST_ATTR_WORD_POS;
      xte_word_count_1 ((caddr_t *)(xtd->xtd_tree), xtd, poss, xtd->xd_default_lh, hider);
    }
  locals = ((NULL == xtd->xtd_wrs) ? NULL : (xe_word_ranges_t *) id_hash_get (xtd->xtd_wrs, (caddr_t)(&ent)));
  if (NULL == locals)
    start[0] = end[0] = BAD_WORD_POS;
  else
    {
      start[0] = locals->xewr_main_beg;
      end[0] = locals->xewr_main_end;
    }
  dbg_printf(("xte_word_range (%p:%s) => (%lu,%lu)\n",
      (void *)xe,
      ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (ent)) ?
        XTE_HEAD_NAME (XTE_HEAD (ent)) :
        ((DV_STRING == DV_TYPE_OF (ent)) ? (caddr_t)ent : "<weird>") ),
      (unsigned long)(start[0]), (unsigned long)(end[0]) ));
}


void
xte_attr_word_range (xml_entity_t *xe, wpos_t *start, wpos_t *this_end, wpos_t *tree_end)
{
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * ent = xte->xte_current;
  xml_tree_doc_t * xtd = xte->xe_doc.xtd;
  xe_word_ranges_t *locals;
  if (NULL == xtd->xtd_wrs)
    {
      char hider = '\0';
      wpos_t poss[2];
      poss[0] = 0;
      poss[1] = FIRST_ATTR_WORD_POS;
      xte_word_count_1 ((caddr_t *)(xtd->xtd_tree), xtd, poss, xtd->xd_default_lh, hider);
    }
  locals = ((NULL == xtd->xtd_wrs) ? NULL : (xe_word_ranges_t *) id_hash_get (xtd->xtd_wrs, (caddr_t) (&ent)));
  if (NULL == locals)
    start[0] = this_end[0] = tree_end[0] = BAD_WORD_POS;
  else
    {
      start[0] = locals->xewr_attr_beg;
      this_end[0] = locals->xewr_attr_this_end;
      tree_end[0] = locals->xewr_attr_tree_end;
    }
}


int xte_get_logical_path (xml_entity_t *xe, dk_set_t *path)
{
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  int res = 1;
  xte_bmk_t *xbmk;
  for (xbmk = xte->xte_stack_top; xbmk > xte->xte_stack_buf; xbmk--)
    {
      int chld = xbmk->xteb_child_no;
      if (xbmk[-1].xteb_current[chld] != (caddr_t)(xbmk->xteb_current))
        res = 0;
      dk_set_push (path, (void *)((ptrlong)(chld)));
    }
  if (NULL != xte->xe_referer)
    return res & /* not && */ xte->xe_referer->_->xe_get_logical_path(xte->xe_referer, path);
  dk_set_push (path, xe->xe_doc.xtd); /* There's no xe->xe_doc.xtd->xd_ref_count += 1 here. It's done intentionally. */
  return res;
}

void xte_rescan_id_dict_subtree (caddr_t **tree, id_hash_t *id_dict, ptrlong *scan, dtd_t *dtd)
{
  int len, ctr;
  ptrlong depth = scan[0] + 1;
  if (depth >= (ECM_MAX_DEPTH-1))
    return;
  len = BOX_ELEMENTS (tree);
  scan[0] = depth;
  for (ctr = 1; ctr < len; ctr++)
    {
      caddr_t chld = (caddr_t) tree[ctr];
      caddr_t **head;
      char *key_name;
      int head_len, attr_ctr;
      ecm_el_idx_t el_idx;
      ecm_el_t *el;
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (chld))
        continue;
      scan [depth] = ctr;
      xte_rescan_id_dict_subtree ((caddr_t **) chld, id_dict, scan, dtd);
      head = (caddr_t **) XTE_HEAD(chld);
      el_idx = ecm_find_name (XTE_HEAD_NAME(head), dtd->ed_els, dtd->ed_el_no, sizeof (ecm_el_t));
      if (ECM_MEM_NOT_FOUND == el_idx)
        continue;
      el = dtd->ed_els + el_idx;
      if (el->ee_has_id_attr)
        key_name = el->ee_attrs[el->ee_id_attr_idx].da_name;
      else
        continue;
      head_len = BOX_ELEMENTS (head);
      for (attr_ctr = 1; attr_ctr < head_len; attr_ctr += 2)
        {
          if (!strcmp ((const char *) (head[attr_ctr]), key_name))
            {
              caddr_t boxed_id = (caddr_t) head [attr_ctr+1];
              ptrlong ** id_hit = (ptrlong **)id_hash_get (id_dict, (caddr_t)(&boxed_id));
	      if (NULL == id_hit)
	        {
		  ptrlong *lpath = (ptrlong *) dk_alloc_box (sizeof (ptrlong) * depth, DV_ARRAY_OF_LONG);
		  memcpy (lpath, scan+1, depth * sizeof (ptrlong));
		  boxed_id = box_copy (boxed_id);
		  id_hash_set (id_dict, (caddr_t)(&boxed_id), (caddr_t)(&lpath));
                }
	      break;
            }
        }
    }
  scan[0] = depth - 1;
}

void xte_rescan_id_dict (xml_tree_ent_t *xe)
{
  ptrlong *scan = (ptrlong *)xe->xe_doc.xd->xd_id_scan;
  dtd_t *dtd = xe->xe_doc.xd->xd_dtd;
  id_hash_t *id_dict = xe->xe_doc.xd->xd_id_dict;
  if ((NULL == dtd) || (0 == dtd->ed_el_no))
    {
      xe->xe_doc.xd->xd_id_scan = XD_ID_SCAN_COMPLETED;
      dk_free_box ((box_t) id_dict);
      id_dict = xe->xe_doc.xd->xd_id_dict = NULL;
      return;
    }
  dk_free_box ((box_t) scan);
  xe->xe_doc.xd->xd_id_scan = (caddr_t) (scan = (ptrlong *)dk_alloc_box(sizeof(ptrlong)*(ECM_MAX_DEPTH+1), DV_ARRAY_OF_LONG));
  scan[0] = 0;
  if (NULL == id_dict)
    id_dict = xe->xe_doc.xd->xd_id_dict = (id_hash_t *)box_dv_dict_hashtable (509);
  xte_rescan_id_dict_subtree ((caddr_t **) xe->xe_doc.xtd->xtd_tree, id_dict, scan, dtd);
  dk_free_box ((box_t) scan);
  xe->xe_doc.xd->xd_id_scan = XD_ID_SCAN_COMPLETED;
}

xml_entity_t * xte_deref_id (xml_entity_t *xe, const char * idbegin, size_t idlength)
{
  id_hash_t *id_dict;
  caddr_t boxed_id = NULL;
  if (0 != xe->xe_doc.xd->xd_dom_mutation)
    sqlr_new_error ("42000", "XI030", "ID dereferencing can not process an entity that is modified by DOM operations");
  if (xe->xe_doc.xd->xd_top_doc != xe->xe_doc.xd)
    return NULL; /* Compound documents are not yet supported */
  xe_insert_external_dtd (xe);
  if (xe->xe_doc.xd->xd_id_scan != XD_ID_SCAN_COMPLETED)
    xte_rescan_id_dict ((xml_tree_ent_t *) xe);
  id_dict = xe->xe_doc.xd->xd_id_dict;
  if (NULL != id_dict)
    {
      ptrlong **path_ptr;
      boxed_id = box_dv_short_nchars (idbegin, idlength);
      path_ptr = (ptrlong **)id_hash_get (id_dict, (caddr_t)(&boxed_id));
      if (NULL != path_ptr)
	{
	  xml_entity_t *res, *cursor = xe->_->xe_copy(xe);
	  xe_root (cursor);
	  res = cursor->_->xe_follow_path (cursor, path_ptr[0], BOX_ELEMENTS(path_ptr[0]));
	  if (NULL == res)
	    dk_free_box ((box_t) cursor);
	  dk_free_box (boxed_id);
	  return res;
	}
    }
  dk_free_box (boxed_id);
  return NULL;
}


xml_entity_t * xte_follow_path (xml_entity_t *xe, ptrlong *path, size_t path_depth)
{
  int len, res;
  xml_tree_ent_t * xte = (xml_tree_ent_t *) xe;
  caddr_t * current = xte->xte_current;
  xml_doc_t *xd = xe->xe_doc.xd;
  while (0 != path_depth)
    {
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (current))
	return NULL;
      len = BOX_ELEMENTS (current);
      if (path[0] >= len)
	return NULL;
      XTE_ADD_STACK_POS(xte);
      xte->xte_current = (caddr_t*) current[path[0]];
      xte->xte_child_no = (int) path[0];
      res = xte_down (xe, (XT *) XP_NODE);
      if (XI_RESULT != res)
	return NULL;
      path++;
      path_depth--;
      if (xe->xe_doc.xd != xd)
	return xe->_->xe_follow_path (xe, path, path_depth);
      current = xte->xte_current;
    }
  return xe;
}


dtd_t *xte_get_addon_dtd (xml_entity_t *xe)
{
  return NULL;
}


const char * xte_get_sysid (xml_entity_t *xe, const char *ent_name)
{
  dtd_t *xe_dtd;
  xe_insert_external_dtd (xe);
  xe_dtd = xe->xe_doc.xd->xd_top_doc->xd_dtd;
  if (NULL != xe_dtd)
    {
      id_hash_t *dict = xe_dtd->ed_generics;
      if (NULL != dict)
	{
	  caddr_t hash_val = id_hash_get (dict, (caddr_t)(&(ent_name)));
	  if (NULL != hash_val)
	    {
	      xml_def_4_entity_t *edef = ((xml_def_4_entity_t **)(void **)(hash_val))[0];
	      return edef->xd4e_systemId;
	    }
	}
    }
  xe_dtd = xe->xe_doc.xd->xd_top_doc->xd_dtd;
  if (NULL != xe_dtd)
    {
      id_hash_t *dict = xe_dtd->ed_generics;
      if (NULL != dict)
	{
	  caddr_t hash_val = id_hash_get (dict, (caddr_t)(&(ent_name)));
	  if (NULL != hash_val)
	    {
	      xml_def_4_entity_t *edef = ((xml_def_4_entity_t **)(void **)(hash_val))[0];
	      return edef->xd4e_systemId;
	    }
	}
    }
  return NULL;
}


xml_entity_t *
DBG_NAME(xte_cut) (DBG_PARAMS xml_entity_t * xe, query_instance_t *qi)
{
  size_t stack_elems = 0x10;
  size_t stack_sz = stack_elems * sizeof (xte_bmk_t);
  xte_bmk_t * newstack = (xte_bmk_t *) dk_alloc (stack_sz);
  xml_tree_ent_t * src_xte = (xml_tree_ent_t *) xe;
  xml_tree_doc_t * src_xtd = src_xte->xe_doc.xtd;
  xml_tree_ent_t * tgt_xte = (xml_tree_ent_t*) dk_alloc_box_zero (sizeof (xml_entity_un_t), DV_XML_ENTITY);
  caddr_t *tree_copy;
  int add_new_root;
  NEW_BOX_VARZ (xml_tree_doc_t, tgt_xtd);
  tree_copy = (caddr_t *) (box_copy_tree ((caddr_t)(src_xte->xte_current)));
  add_new_root = ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree_copy)) ||
    (uname__root != ((caddr_t *)(tree_copy[0]))[0]) );
  if (add_new_root)
    tree_copy = (caddr_t *)list (2, list (1, uname__root), tree_copy);
  tgt_xte->_ = &xec_tree_xe;
  tgt_xte->xe_doc.xtd = tgt_xtd;
  tgt_xte->xte_stack_top = tgt_xte->xte_stack_buf = newstack;
  tgt_xte->xte_stack_max = newstack + stack_elems;
  tgt_xte->xte_current = tgt_xtd->xtd_tree = tree_copy;
  tgt_xte->xte_child_no = 0;
  tgt_xtd->xd_qi = qi_top_qi (qi);
  tgt_xtd->xd_top_doc = (xml_doc_t *) tgt_xtd;
  tgt_xtd->xd_ref_count = 1;
  tgt_xtd->xd_default_lh = src_xtd->xd_default_lh;
  tgt_xtd->xd_cost = XML_BIG_DOC_COST;
  tgt_xtd->xd_weight = 0; /* Unknown */
  if (NULL != src_xtd->xd_dtd)
    {
      dtd_addref (src_xtd->xd_dtd, 0);
      tgt_xtd->xd_dtd = src_xtd->xd_dtd;
    }
  xe_ns_2dict_extend (tgt_xte, xe);
  if (add_new_root)
    tgt_xte->_->xe_first_child ((xml_entity_t *)tgt_xte, (XT *) XP_NODE);
  if (NULL != xe->xe_attr_name)
    tgt_xte->xe_attr_name = box_copy (xe->xe_attr_name);
  return (xml_entity_t *)(tgt_xte);
}


xml_entity_t *
DBG_NAME(xte_clone) (DBG_PARAMS xml_entity_t * xe, query_instance_t *qi)
{
  caddr_t doc_tree_copy = (caddr_t) box_copy_tree ((box_t) xe->xe_doc.xtd->xtd_tree);
  xml_entity_t *res = (xml_entity_t *)xte_from_tree (doc_tree_copy, qi);
  dk_set_t path = NULL;
  ptrlong *path_array;
  res->xe_doc.xd->xd_uri = box_copy_tree (xe->xe_doc.xd->xd_uri);
  xe->_->xe_get_logical_path (xe, &path);
  dk_set_pop (&path); /* To remove pointer to node */
  path_array = (ptrlong *)list_to_array (path);
  res->_->xe_follow_path (res, path_array, BOX_ELEMENTS (path_array));
  dk_free_box ((box_t) path_array);
  if (NULL != xe->xe_doc.xd->xd_dtd)
    {
      dtd_addref (xe->xe_doc.xd->xd_dtd, 0);
      res->xe_doc.xd->xd_dtd = xe->xe_doc.xd->xd_dtd;
    }
  return res;
}


caddr_t *xte_copy_to_xte_head (xml_entity_t *xe)
{
  caddr_t *res;
  int ctr;
  xml_tree_ent_t *xte = (xml_tree_ent_t *)xe;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (xte->xte_current))
    sqlr_new_error ("37000", "XI027", "XML node entity is expected, not a PCDATA entity");
  res = (caddr_t *)box_copy ((box_t) XTE_HEAD(xte->xte_current));
  for (ctr = BOX_ELEMENTS(res); ctr--; /*no step*/)
    res [ctr] = box_copy_tree(res[ctr]);
  return res;
}


caddr_t *xte_copy_to_xte_subtree (xml_entity_t *xe)
{
  caddr_t *res;
  xml_tree_ent_t *xte = (xml_tree_ent_t *)xe;
  res = (caddr_t *)box_copy_tree ((box_t) xte->xte_current);
  return res;
}


caddr_t **xte_copy_to_xte_forest (xml_entity_t *xe)
{
#if 1
  GPF_T;
  return NULL;
#else
  caddr_t *res;
  caddr_t name;
  int ctr;
  xml_tree_ent_t *xte = (xml_tree_ent_t *)xe;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (xte->xte_current))
    return list (1, box_copy (xte->xte_current));
  name = XTE_NAME (XTE_HEAD (xte->xte_current));
  if (' ' == name[0])
    {
      if (uname_ref != name)
	{
	  caddr_t rel_uri = REF_REL_URI(xte,head);
	  char *sysid_base_uri;
	  xml_entity_t * refd;
	  sysid_base_uri = (char *)((const char *)xe_get_sysid_base_uri((xml_entity_t *)(xte)));
	  if (NULL != rel_uri)
	    {
	      refd = xte_reference (xte->xe_doc.xtd->xd_qi, sysid_base_uri, rel_uri, xte->xe_doc.xd, NULL);
	    }
	  else
	    {
	      caddr_t err = NULL;
	      refd = xte_reference (xte->xe_doc.xtd->xd_qi, sysid_base_uri, head[2], xte->xe_doc.xd, &err);
	      if (NULL == refd)
		{
		  dk_free_tree (err);
		  res = (caddr_t *)box_copy_tree (xte->xte_current);
		  return res;
		}
	    }
	  res = refd->_.xe_copy_to_xte_forest (refd);
	  dk_free_box (refd);
	  return res;
	}
      if (uname_root != name)
	{
	  caddr_t *topitems = xte->xte_current;
	  size_t src_len = BOX_ELEMENTS (topitems);
	  size_t res_len = src_len - 1;
	  size_t res_fill = 0, src_idx = 1;
	  caddr_t *draft_res = dk_alloc_box_zero (res_len * sizeof(caddr_t), DV_ARRAY_OF_POINTER);
	}
    }
  res = (caddr_t *)box_copy_tree (xte->xte_current);
  return res;
#endif
}


void xte_emulate_input (xml_entity_t *xe, struct vxml_parser_s *parser)
{
  caddr_t *current;
  caddr_t *head;
  size_t head_len;
  caddr_t name;
  xml_tree_ent_t *xte = (xml_tree_ent_t *)xe;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (xte->xte_current))
    {
      caddr_t text = (caddr_t)(xte->xte_current);
      if (NULL == parser->masters.char_data_handler)
	return;
      parser->masters.char_data_handler (parser->masters.user_data, text, box_length (text) - 1);
      return;
    }
  current = xte->xte_current;
  head = XTE_HEAD (current);
  head_len = BOX_ELEMENTS (head);
  name = XTE_HEAD_NAME (head);
  if (' ' == name[0])
    {
      if (uname__pi == name)
	{
	  if (NULL == parser->masters.pi_handler)
	    return;
	  parser->masters.pi_handler (
	    parser->masters.user_data,
	    ((head_len > 2) ? head[2] : NULL),
	    ((BOX_ELEMENTS (current) > 1) ? current[1] : NULL) );
	  return;
	}
      if (uname__comment == name)
	{
	  if (NULL == parser->masters.comment_handler)
	    return;
	  parser->masters.comment_handler (
	    parser->masters.user_data,
	    ((BOX_ELEMENTS (current) > 1) ? current[1] : "") );
	  return;
	}
      if (uname__ref == name)
	{
	  caddr_t rel_uri = (caddr_t) REF_REL_URI(xte,head);
	  char *sysid_base_uri;
	  xml_entity_t * refd;
	  sysid_base_uri = (char *)((const char *)xe_get_sysid_base_uri((xml_entity_t *)(xte)));
	  if (NULL != rel_uri)
	    {
	      refd = xte_reference (xte->xe_doc.xtd->xd_qi, sysid_base_uri, rel_uri, xte->xe_doc.xd, NULL);
	    }
	  else
	    {
	      caddr_t err = NULL;
	      refd = xte_reference (xte->xe_doc.xtd->xd_qi, sysid_base_uri, head[2], xte->xe_doc.xd, &err);
	      if (NULL == refd)
		{
		  dk_free_tree (err);
		  if (NULL != parser->masters.entity_ref_handler)
		    parser->masters.entity_ref_handler (parser->masters.user_data,
		      head[2], strlen (head[2]),
		      0, /* = not parameter entity ref */
		      NULL); /* = no dictionary item because of no dictionary at all */
		  return;
		}
	    }
	  refd->_->xe_emulate_input (refd, parser);
	  dk_free_box ((box_t) refd);
	  return;
	}
      if (uname__root == name)
	{
	  if (XI_RESULT != xe->_->xe_first_child (xe, (XT *) XP_NODE))
	    return;
	  do {
	      xe->_->xe_emulate_input (xe, parser);
	    } while (XI_RESULT == xe->_->xe_next_sibling (xe, (XT *) XP_NODE));
	  xe->_->xe_up (xe, (XT *) XP_NODE, XE_UP_MAY_TRANSIT);
	  return;
	}
      sqlr_new_error ("37000", "XI030", "Unable to validate an XML tree entity: unsupported special element '%.300s'", name);
    }
  if (parser->masters.start_element_handler)
    {
      int ctr = (head_len - 1) / 2;
      parser->attrdata.local_attrs_count = 0;
      while (ctr--)
        {
          caddr_t attrname = head[ctr * 2 + 1];
          tag_attr_t *curr = parser->tmp.attr_array + parser->attrdata.local_attrs_count;
          if (' ' == attrname[0])
            continue;
          curr->ta_raw_name.lm_memblock = attrname;
          curr->ta_raw_name.lm_length = box_length (attrname) - 1;
          curr->ta_value = head[ctr * 2 + 2];
          parser->attrdata.local_attrs_count++;
	  if (parser->attrdata.local_attrs_count > XML_PARSER_MAX_ATTRS)
	    sqlr_new_error ("37000", "XI030", "Unable to validate an XML tree entity: too many attributes in element '%.300s'", name);
        }
      parser->masters.start_element_handler (parser->masters.user_data, name, &(parser->attrdata));
    }
  if (XI_RESULT == xe->_->xe_first_child (xe, (XT *) XP_NODE))
    {
      do {
	  xe->_->xe_emulate_input (xe, parser);
	} while (XI_RESULT == xe->_->xe_next_sibling (xe, (XT *) XP_NODE));
      xe->_->xe_up (xe, (XT *) XP_NODE, XE_UP_MAY_TRANSIT);
    }
  if (parser->masters.end_element_handler)
    parser->masters.end_element_handler (parser->masters.user_data, name);
}


caddr_t xte_find_expanded_name_by_qname (xml_entity_t *xe, const char *qname, int use_default)
{
  xml_tree_ent_t *xte = (xml_tree_ent_t *)xe;
  xte_bmk_t *iter;
  char *colon = strrchr (qname, ':');
  int prefix_sz = 0;
  if (NULL == colon)
    {
      if (!use_default)
	return box_dv_short_string (qname);
    }
  else
    {
      prefix_sz = colon - qname;
      if (bx_std_ns_pref (qname, prefix_sz))
        return box_dv_short_string (qname);
    }
  for (iter = xte->xte_stack_top; iter >= xte->xte_stack_buf; iter--)
    {
      caddr_t *ns_array = NULL;
      caddr_t *head;
      int head_len, ctr;
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (iter->xteb_current))
        continue;
      head = XTE_HEAD(iter->xteb_current);
      head_len = BOX_ELEMENTS (head);
      for (ctr = head_len - 2; ctr > 0; ctr -= 2)
        {
          if (uname__bang_ns != head[ctr])
            {
	      if (' ' != head[ctr][0])
	        break;
              continue;
            }
          ns_array = (caddr_t *)(head[ctr + 1]);
	  break;
        }
      if (ns_array)
	{
	  unsigned inx;
	  for (inx = 0; inx < BOX_ELEMENTS (ns_array); inx += 2)
	    {
	      if (uname___empty == ns_array[inx])
	        {
	          if (NULL == colon)
		    {
		      caddr_t uri = ns_array [inx+1];
		      size_t uri_sz = box_length (uri);
		      caddr_t res = dk_alloc_box (uri_sz + strlen (qname) + 1, DV_SHORT_STRING);
		      memcpy (res, uri, uri_sz - 1);
		      res [uri_sz - 1] = ':';
		      strcpy (res + uri_sz, qname);
		      return res;
		    }
		}
	      else
	        {
		  if ((box_length (ns_array[inx]) == prefix_sz+1) &&
		    !memcmp (qname, ns_array[inx], prefix_sz) )
		    {
		      caddr_t uri = ns_array [inx+1];
		      size_t uri_sz = box_length (uri);
		      caddr_t res = dk_alloc_box (uri_sz + strlen (colon), DV_SHORT_STRING);
		      memcpy (res, uri, uri_sz - 1);
		      strcpy (res + uri_sz - 1, colon);
		      return res;
		    }
	        }
	    }
	}
    }
  return NULL;
}


dk_set_t xte_namespace_scope (xml_entity_t *xe, int use_default)
{
  xml_tree_ent_t *xte = (xml_tree_ent_t *)xe;
  dk_set_t res = NULL;
  xte_bmk_t *iter;
  for (iter = xte->xte_stack_top; iter >= xte->xte_stack_buf; iter--)
    {
      caddr_t *ns_array = NULL;
      caddr_t *head;
      int head_len, ctr;
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (iter->xteb_current))
        continue;
      head = XTE_HEAD(iter->xteb_current);
      head_len = BOX_ELEMENTS (head);
      for (ctr = head_len - 2; ctr > 0; ctr -= 2)
        {
          if (uname__bang_ns != head[ctr])
            {
	      if (' ' != head[ctr][0])
	        break;
              continue;
            }
          ns_array = (caddr_t *)(head[ctr + 1]);
	  break;
        }
      if (ns_array)
	{
	  unsigned inx;
	  for (inx = 0; inx < BOX_ELEMENTS (ns_array); inx += 2)
	    {
	      if ((uname___empty == ns_array[inx]) && !use_default)
		continue;
	      dk_set_push (&res, (void*) box_copy (ns_array[inx]));
	      dk_set_push (&res, (void*) box_copy (ns_array[inx + 1]));
	    }
	}
    }
  return (dk_set_nreverse (res));
}

void
xte_replace_strings_with_unames (caddr_t **tree)
{
  int idx, len;
  caddr_t *head = XTE_HEAD (tree);
  caddr_t strg = head[0];
  if (DV_UNAME != DV_TYPE_OF (strg))
    {
      caddr_t name = box_dv_uname_nchars (strg, box_length (strg) - 1);
      dk_free_box (strg);
      head[0] = name;
    }
  len = BOX_ELEMENTS (head);
  for (idx = 1; idx < len; idx += 2)
    {
      strg = head[idx];
      if (DV_UNAME != DV_TYPE_OF (strg))
        {
          caddr_t name = box_dv_uname_nchars (strg, box_length (strg) - 1);
          dk_free_box (strg);
          head[idx] = name;
        }
    }
  len = BOX_ELEMENTS (tree);
  for (idx = 1; idx < len; idx ++)
    {
      caddr_t *child = tree[idx];
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (child))
        xte_replace_strings_with_unames ((caddr_t **) child);
    }
}


caddr_t
bif_xml_tree_doc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_tree_ent_t * xte;
  /* test only : long l1,l2; */
  caddr_t tree = bif_arg (qst, args, 0, "xml_tree_doc");
  caddr_t volatile uri = BOX_ELEMENTS (args) > 1 ? bif_string_arg (qst, args, 1, "xml_tree_doc") : NULL;
  int ssl_type = args[0]->ssl_type;
  caddr_t volatile err, tree1 = NULL;
  dtd_t *dtd = NULL; /* set always to NULL to be sure that assigned element is valid */
  dtp_t dtp = DV_TYPE_OF (tree);
  if (DV_OBJECT == dtp)
    {
      xml_entity_t *xe = XMLTYPE_TO_ENTITY(tree);
      if (NULL != xe)
        {
	  tree = (caddr_t)xe;
	  dtp = DV_TYPE_OF (tree);
	}
    }
  if (DV_XML_ENTITY == dtp)
    {
      if (XE_IS_TREE (tree))
        {
	  xml_tree_ent_t *xte = (xml_tree_ent_t *)(box_copy_tree (tree));
	  if (NULL != uri)
	    {
	      dk_free_tree (xte->xe_doc.xd->xd_uri);
	      xte->xe_doc.xd->xd_uri = box_copy_tree (uri);
	    }
          return (caddr_t)(xte);
	}
      sqlr_new_error ("37000", "XI029", "Persistent XML can not be used as an argument of xml_tree_doc()");
    }
  if (DV_DB_NULL == dtp)
    {
      tree1 = list (1, list (1, uname__root));
      goto tree1_is_ok;
    }
  if (!IS_STRING_DTP (dtp) && DV_BLOB_HANDLE != dtp && DV_ARRAY_OF_POINTER != dtp)
    sqlr_new_error ("37000", "XI020", "Argument of xml_tree_doc must be an array not arg of type %.300s (%d)", dv_type_title (dtp), dtp);
  if (!IS_STRING_DTP (dtp) && DV_BLOB_HANDLE != dtp && ssl_type != SSL_VARIABLE && ssl_type != SSL_PARAMETER && ssl_type != SSL_VEC)
    sqlr_new_error ("37000", "XI021", "Argument of xml_tree_doc must be a variable or function call");
  if (dtp == DV_ARRAY_OF_POINTER && (
	BOX_ELEMENTS (tree) < 1 ||
	DV_ARRAY_OF_POINTER != DV_TYPE_OF (((caddr_t *)tree)[0]) ||
	BOX_ELEMENTS (((caddr_t *)tree)[0]) < 1))
    sqlr_new_error ("37000", "XI027", "Argument of xml_tree_doc must be valid xml entity. There is no root tag");
  if (DV_ARRAY_OF_POINTER == dtp)
    {
      if (args[0]->ssl_is_callret && ssl_type != SSL_VEC)
	qst[args[0]->ssl_index] = NULL;
      else
	tree = box_copy_tree (tree);
      if (DV_UNAME != DV_TYPE_OF (XTE_HEAD_NAME (XTE_HEAD (tree))))
        {
          xte_replace_strings_with_unames ((caddr_t **)tree);
        }
      if (uname__root != XTE_HEAD_NAME (XTE_HEAD (tree)))
	tree1 = list (2, list (1, uname__root), tree);
      else
        tree1 = tree;
    }
  else
    {
      wcharset_t *volatile charset = QST_CHARSET (qst) ? QST_CHARSET (qst) : default_charset;
      QR_RESET_CTX
	{
	  tree1 = xml_make_tree ((query_instance_t *)qst, tree, (caddr_t *) &err,
	      CHARSET_NAME (charset, NULL), server_default_lh, &dtd);
	  if (NULL == tree1)
	    sqlr_resignal (err);
	}
      QR_RESET_CODE
	{
	  du_thread_t *self = THREAD_CURRENT_THREAD;
	  caddr_t err = thr_get_error_code (self);
	  POP_QR_RESET;
	  sqlr_resignal (err);
	}
      END_QR_RESET;
    }

tree1_is_ok:
  xte = xte_from_tree (tree1, (query_instance_t*) qst);
  xte->xe_doc.xd->xd_uri = box_copy_tree (uri);
  xte->xe_doc.xd->xd_dtd = dtd; /* The refcounter is incremented inside xml_make_tree */
  /* test only : xte_word_range(xte,&l1,&l2); */
  return ((caddr_t) xte);
}


caddr_t
bif_xml_doc_get_base_uri (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t *ent = bif_entity_arg (qst, args, 0, "xml_doc_get_base_uri");
  caddr_t uri = (caddr_t) xe_get_sysid_base_uri ((xml_entity_t *)ent);
  return ((NULL == uri) ? NEW_DB_NULL : box_copy (uri));
}


caddr_t
bif_xml_doc_assign_base_uri (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t * ent = bif_entity_arg (qst, args, 0, "xml_doc_assign_base_uri");
  caddr_t uri = bif_string_arg (qst, args, 1, "xml_doc_assign_base_uri");
  caddr_t old_base_uri = (caddr_t) xe_get_sysid_base_uri ((xml_entity_t *)ent);
  if ((NULL != old_base_uri) && ('\0' != old_base_uri[0]))
    return box_num(0);
  while (NULL != ent->xe_referer)
    ent = ent->xe_referer;
  ent->xe_doc.xd->xd_uri = box_copy (uri);
  return box_num(1);
}

caddr_t
bif_xml_doc_output_option (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t * xe = bif_entity_arg (qst, args, 0, "xml_doc_output_option");
  xml_doc_t *xd = xe->xe_doc.xd;
  caddr_t option_name = bif_string_arg (qst, args, 1, "xml_doc_output_option");
  int is_set = (BOX_ELEMENTS (args) > 2);
  caddr_t val = is_set ? bif_string_or_null_arg (qst, args, 2, "xml_doc_output_option") : NULL;

#define XD_SET_STRING_VALUE(Elem, Name) \
  if (!strcmp (option_name, Name)) \
    { \
      if (is_set) \
        { \
          dk_free_tree (xd->xout_##Elem); \
          xd->xout_##Elem = ((NULL == val) ? NULL : box_dv_short_string (val)); \
        } \
      return ((NULL == xd->xout_##Elem) ? NEW_DB_NULL : box_copy (xd->xout_##Elem)); \
    }

#define XD_SET_UPCASE_VALUE(Elem, Name, setmeta) \
  if (!strcmp (option_name, Name)) \
    { \
      if (is_set) \
        { \
          dk_free_tree (xd->xout_##Elem); \
          xd->xout_##Elem = ((NULL == val) ? NULL : box_dv_short_string (val)); \
          if (NULL != val) \
            sqlp_upcase (xd->xout_##Elem); \
	  if (setmeta) \
	    xd->xout_encoding_meta = ((NULL == val) ? 0 : 1); \
        } \
      return ((NULL == xd->xout_##Elem) ? NEW_DB_NULL : box_copy (xd->xout_##Elem)); \
    }

#define XD_SET_BOOL_VALUE(Elem, Name) \
  if (!strcmp (option_name, Name)) \
    { \
      if (is_set) \
        { \
          if ((NULL != val) && !strcmp (val, "yes")) \
            xd->xout_##Elem = 1; \
          else if ((NULL != val) && !strcmp (val, "no")) \
            xd->xout_##Elem = 0; \
          else \
            sqlr_new_error ("XS370", "XS029", "\"yes\" or \"no\" required as value of output option %s", option_name); \
        } \
      return box_dv_short_string ((xd->xout_##Elem) ? "yes" : "no"); \
    }

  XD_SET_STRING_VALUE (method, "method");
  XD_SET_STRING_VALUE (version, "version");
  XD_SET_UPCASE_VALUE (encoding, "encoding", 1);
  XD_SET_BOOL_VALUE (omit_xml_declaration, "omit-xml-declaration");
  XD_SET_BOOL_VALUE (standalone, "standalone");
  XD_SET_STRING_VALUE (doctype_public, "doctype-public");
  XD_SET_STRING_VALUE (doctype_system, "doctype-system");
  XD_SET_BOOL_VALUE (indent, "indent");
  XD_SET_STRING_VALUE (media_type, "media-type");
  if (!strcmp (option_name, "cdata-section-elements"))
    sqlr_new_error ("XS370", "XS066", "Output option '%.200s' can be set only by xsl:output element of a stylesheet, xml_doc_output_option() can not set it", option_name);
  sqlr_new_error ("XS370", "XS067", "Unknown output option name '%.200s' is specified as argument #2 of xml_doc_output_option()", option_name);
  return NULL; /* never reached */
}

char *
xte_output_method (xml_tree_ent_t * xte)
{
  if (xte->xe_doc.xtd->xout_method)
    return xte->xe_doc.xtd->xout_method;
  else if (!XE_IS_TREE (xte))
    return "xml";
  else
    {
      caddr_t *elem = xte->xte_current;
      caddr_t name = NULL;
      int n_non_empty = 0;
      if (!XTE_HAS_PARENT(xte))
	{
	  size_t inx;
	  for (inx = 1; inx < BOX_ELEMENTS (elem); inx++)
	    {
	      if (xte_is_entity ((caddr_t *)elem[inx]))
		{
		  name = XTE_HEAD_NAME (XTE_HEAD (elem[inx]));
		  n_non_empty++;
		}
	      else if (xslt_non_whitespace (elem[inx]))
		{
		  name = NULL;
		  break;
		}
	    }
	}
      else if (DV_TYPE_OF (elem) == DV_ARRAY_OF_POINTER)
        {
	  name = XTE_HEAD_NAME (XTE_HEAD (elem));
          n_non_empty = 1;
        }
      if (n_non_empty == 1 && name)
	{
	  char *colon = strchr (name, ':');
	  if (!colon)
	    colon = name;
	  else
	    colon += 1;
	  if (!stricmp (colon, "html"))
	    return "html";
	}
    }
  return "xml";
}

static caddr_t
bif_xml_tree_doc_media_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t * xe = bif_entity_arg (qst, args, 0, "xml_tree_doc_media_type");
  xml_doc_t *xd = xe->xe_doc.xd;
  if (xd->xout_media_type)
    return (box_dv_short_string (xd->xout_media_type));
  else
    {
      char *method = xte_output_method ((xml_tree_ent_t *)xe);
      if (!strcmp (method, "html"))
	return box_dv_short_string ("text/html");
      else if (!strcmp (method, "xml"))
	return box_dv_short_string ("text/xml");
      else if (!strcmp (method, "text"))
	return box_dv_short_string ("text/plain");
      else if (!strcmp (method, "xhtml"))
	return box_dv_short_string ("text/html");
    }
  return NULL;
}

static caddr_t
bif_xml_tree_doc_set_output (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t * xe = bif_entity_arg (qst, args, 0, "xml_tree_doc_set_output");
  xml_doc_t *xd = xe->xe_doc.xd;
  caddr_t output = bif_string_arg (qst, args, 1, "xml_tree_doc_set_output");
  if (strcmp (output, "html") && strcmp (output, "xml") &&
      strcmp (output, "text") && strcmp (output, "xhtml"))
    sqlr_new_error ("22023", "XS044",
	"Function xml_tree_doc_set_output accepts html, xhtml, xml or text as second argument");
  B_SET (xd->xout_method, output);
  return NULL;
}


static caddr_t
bif_xml_tree_doc_set_ns_output (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t * xe = bif_entity_arg (qst, args, 0, "xml_tree_doc_set_ns_output");
  xml_doc_t *xd = xe->xe_doc.xd;
  ptrlong fmt = bif_long_arg (qst, args, 1, "xml_tree_doc_set_ns_output");
  int flag = fmt ? 1 : 0;

  xd->xout_default_ns = flag;
  return NULL;
}


static caddr_t
bif_xml_namespace_scope (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t * xe = bif_entity_arg (qst, args, 0, "xml_namespace_scope");
  ptrlong use_default = bif_long_arg (qst, args, 1, "xml_namespace_scope");
  dk_set_t scope = xe->_->xe_namespace_scope (xe, use_default);
  caddr_t *res = (caddr_t *)list_to_array (scope);
  int idx = BOX_ELEMENTS (res);
  while (idx--)
    {
      caddr_t item = res[idx];
      if (DV_UNAME == DV_TYPE_OF (item))
        {
          res[idx] = box_dv_short_nchars (item, box_length (item)-1);
          dk_free_box (item);
        }
    }
  return (caddr_t)res;
}


static caddr_t
bif_xml_tree_doc_encoding (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t * xe = bif_entity_arg (qst, args, 0, "xml_tree_doc_encoding");
  xml_doc_t *xd = xe->xe_doc.xd;
  caddr_t ret = NULL;
  if (BOX_ELEMENTS (args) > 1)
    { /* set case */
      caddr_t enc = bif_string_arg (qst, args, 1, "xml_tree_doc_encoding");
      if (stricmp (enc, "UTF-8") &&
	  !sch_name_to_charset (enc))
	sqlr_new_error ("22023", "SR361", "Invalid encoding name '%.300s' in xml_tree_doc_encoding", enc);
      ret = box_dv_short_string (xd->xout_encoding);
      B_SET (xd->xout_encoding, enc);
    }

  if (xd->xout_encoding)
    {
      if (!stricmp (xd->xout_encoding, "UTF-8")
	  || sch_name_to_charset (xd->xout_encoding))
	ret = box_dv_short_string (xd->xout_encoding);
    }
  return ret;
}

static caddr_t
bif_xtree_doc_get_dtd (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t * xe = bif_entity_arg (qst, args, 0, "xtree_doc_get_dtd");
  long what = bif_long_arg (qst, args, 1, "xtree_doc_get_dtd");
  xml_doc_t *xd = xe->xe_doc.xd;
  caddr_t ret = NULL;
  if (xd->xd_dtd)
    {
      switch (what)
	{
	  case 1:
	      ret = xd->xd_dtd->ed_sysuri ? box_dv_short_string (xd->xd_dtd->ed_sysuri) : NULL;
	      break;
	  case 2:
	      ret = xd->xd_dtd->ed_puburi ? box_dv_short_string (xd->xd_dtd->ed_puburi) : NULL;
	      break;
	}
    }
  return ret ? ret : NEW_DB_NULL;
}

int
xe_destroy (caddr_t box)
{
  xml_entity_t * xe = (xml_entity_t *) box;
  xe->_->xe_destroy (xe);
  return 0;
}


caddr_t
xe_make_copy (caddr_t box)
{
  xml_entity_t * xe = (xml_entity_t *) box;
  return (caddr_t) (xe->_->xe_copy (xe));
}


caddr_t
xe_mp_copy (mem_pool_t * mp, caddr_t box)
{
  caddr_t cp = xe_make_copy (box);
  dk_set_push (&mp->mp_trash, (void*)cp);
  return cp;
}


int
xe_strses_serialize_utf8 (xml_entity_t * xe, dk_session_t * strses, int set_encoding)
{
  caddr_t enc_saved = xe->xe_doc.xtd->xout_encoding;
  int enc_decl_saved = xe->xe_doc.xtd->xout_omit_xml_declaration;
  caddr_t buffer[20];
  caddr_t bptr = NULL;
  volatile int retval = 1;

  if (1 || set_encoding) /* GK: all the clients - even the old ones && cli->cli_version > 2723*/
    { /* if it's outputting data to the client of a supporting version */
      BOX_AUTO (bptr, buffer, sizeof ("UTF-8") + 1, DV_SHORT_STRING);
      strcpy_box_ck (bptr, "UTF-8");

      xe->xe_doc.xtd->xout_encoding = bptr;
      xe->xe_doc.xtd->xout_omit_xml_declaration = 1;
      strses_set_utf8 (strses, 1);
    }

  CATCH_WRITE_FAIL (strses)
    {
      xe->_->xe_serialize (xe, strses);
    }
  FAILED
    {
      retval = 0;
    }
  END_WRITE_FAIL (strses);

  if (bptr)
    {
      BOX_DONE (bptr, buffer);
      xe->xe_doc.xtd->xout_encoding = enc_saved;
      xe->xe_doc.xtd->xout_omit_xml_declaration = enc_decl_saved;
    }
  return retval;
}


void
xe_serialize (xml_entity_t * xe, dk_session_t * ses)
{
  client_connection_t *cli = DKS_DB_DATA (ses);
  dk_session_t * strses;
  dtp_t out_dtp = DV_LONG_STRING;

  strses = strses_allocate ();
  if ((DKS_TO_CLUSTER & ses->dks_cluster_flags) && XE_IS_TREE (xe))
    {
      xml_tree_ent_t * xte = (xml_tree_ent_t *)xe;
      out_dtp = DV_XML_ENTITY;
      xte_serialize_packed (xte->xte_current, xte->xe_doc.xd->xd_dtd, strses);
    }
  else if (cli)
    { /* GK: if this is a top level serialization to the client session force UTF-8 */
      out_dtp = DV_LONG_WIDE;
      if (!xe_strses_serialize_utf8 (xe, strses, 1))
	{
	  SESSTAT_CLR (ses->dks_session, SST_OK);
	  SESSTAT_SET (ses->dks_session, SST_DISK_ERROR);
	  strses_free (strses);
	  longjmp_splice (&SESSION_SCH_DATA (ses)->sio_write_broken_context, 1);
	}
    }
  else
    { /* GK: otherwise serialize it using the charset in effect at the moment.
	 This is kind of rough but prevents problems.
       */
      xe->_->xe_serialize (xe, strses);
    }

  if (cli && !(DKS_TO_CLUSTER & ses->dks_cluster_flags) && cli->cli_version >= 2724)
    print_object (strses, ses, NULL, NULL);
  else
    {
      session_buffered_write_char (out_dtp, ses);
      print_long (strses_length (strses), ses);
      strses_write_out (strses, ses);
    }
  strses_free (strses);
}

caddr_t
xe_deserialize (dk_session_t * ses)
{
  xml_entity_t * xe = NULL;
  caddr_t *tree = NULL;
  dtd_t *dtd = NULL;
  long len = read_long (ses);
  query_instance_t * qi = DKS_QI_DATA (ses);

  if (!qi && !ses->dks_cluster_data && !(DKS_LEN_ONLY & ses->dks_cluster_flags))
    return NEW_DB_NULL;

  SAVE_READ_FAIL(ses)
    {
      xte_deserialize_packed (ses, &tree, &dtd);
    }
  RESTORE_READ_FAIL (ses);
  xe = (xml_entity_t *) xte_from_tree ((caddr_t) tree, qi ? qi : (query_instance_t*)(ptrlong)-1);
  if (NULL != dtd)
    dtd_addref (dtd, 0);
  xe->xe_doc.xd->xd_dtd = dtd;
  return (caddr_t) xe;
}

xml_entity_t *
xn_xe_from_text (xpath_node_t * xn, query_instance_t * qi)
{
  xml_entity_t * xe = NULL; /* Dummy assignment to make compiler happy */
  caddr_t *tree, err = NULL;
  caddr_t str = NULL;
  dk_session_t *ses = NULL;
  caddr_t * qst = (caddr_t *) qi;
  caddr_t val = qst_get (qst, xn->xn_text_col);
#ifdef DEBUG
  caddr_t orig_val = val;
#endif
  xp_query_t *xqr = (xp_query_t *) qst_get (qst, xn->xn_compiled_xqr);
  xml_entity_t *res = NULL;
  dtp_t dtp = DV_TYPE_OF (val);
  int val_sort;
  char *charset;
  dtd_t *dtd = NULL; /* make sure that assigned value is valid */
  char abs_uri[3000];
  abs_uri[0] = '\0';
  switch (dtp)
    {
    case DV_XML_ENTITY:
      res = (xml_entity_t *)val;
      break;
    case DV_OBJECT:
      res = XMLTYPE_TO_ENTITY(val);
      break;
    }
  if ((NULL == res || NULL == res->xe_doc.xd->xd_uri) && (xn->xn_base_uri))
    {
      dbe_column_t * text_col = xn->xn_text_col->ssl_column;
      dbe_table_t * tb = ((NULL != text_col) ? text_col->col_defined_in : NULL);
      caddr_t path = qst_get ((caddr_t *)qi, xn->xn_base_uri);
      if (DV_STRINGP (path) && (NULL != tb))
	{
	  if (strlen (path) > 2000)
	    sqlr_new_error ("HT001", "XI023", "URI path for document from %.300s.%.300s is not a string or is over 2K long", tb->tb_name, text_col->col_name);
	  snprintf_ck (abs_uri, sizeof(abs_uri), "virt://%s.%s.%s:%s", tb->tb_name,
	    text_col->col_xml_base_uri, text_col->col_name, path);
	}
    }
  if (NULL != res)
    {
      res = (xml_entity_t *)(box_copy ((box_t) res));
      if ('\0' != abs_uri[0])
        {
	  dk_free_box (res->xe_doc.xd->xd_uri);
	  res->xe_doc.xd->xd_uri = box_dv_short_string (abs_uri);
	}
      return res;
    }

  val_sort = looks_like_serialized_xml (qi, val);
  charset = CHARSET_NAME (default_charset, "ISO-8859-1");

  switch (val_sort)
    {
    case XE_PLAIN_TEXT_OR_SERIALIZED_VECTOR:
      if (xqr->xqr_is_davprop)
        {
	  if (DV_STRINGP (val))
	    {
	      ses = strses_allocate();
	      ses->dks_in_buffer = val;
	      ses->dks_in_read = 0;
	      ses->dks_in_fill = box_length (val) - 1;
	    }
	  else if (DV_DB_NULL == dtp)
	    return NULL;
	  else if ((DV_BLOB_HANDLE == dtp) || (DV_BLOB_WIDE_HANDLE == dtp))
	    ses = blob_to_string_output (qi->qi_trx, val);
          else
            {
	      strses_free (ses);
	      sqlr_new_error ("HT002", "XI037", "Can't deserialize XML tree vector from datum of type %d", (int) dtp);
	    }
	  tree = (caddr_t *) read_object (ses);
	  ses->dks_in_buffer = NULL;
	  if (NULL == tree)
	    {
	      strses_free (ses);
	      sqlr_new_error ("HT002", "XI038", "Can't deserialize a serialized XML tree vector: data corrupted");
	    }
          xte_replace_strings_with_unames ((caddr_t **)tree);
          if (uname__root != XTE_HEAD_NAME (XTE_HEAD (tree))) /* No check for non-array because non-array can't come from serialized vector */
	    tree = (caddr_t *)list (2, list (1, uname__root), (caddr_t)tree);
	  xe = (xml_entity_t *) xte_from_tree ((caddr_t) tree, qi);
/* No DTD from serialized vector :(
	  if (NULL != dtd)
	    dtd_addref (dtd, 0);
	  xe->xe_doc.xd->xd_dtd = dtd;
*/
	  if ('\0' != abs_uri[0])
	    xe->xe_doc.xd->xd_uri = box_dv_short_string (abs_uri);
          strses_free (ses);
	  break;
	}
      /* No break. If we're not sure that this is a serialized vector that this is a text */
    case XE_PLAIN_TEXT:
      if (DV_STRING == dtp || DV_UNAME == dtp || DV_BIN == dtp)
	str = val;
      else if (DV_WIDESTRINGP (val))
	{
	  str = box_wide_as_utf8_char (val, box_length (val) / sizeof (wchar_t) - 1, DV_LONG_STRING);
	  charset = NULL;
	}
      else if (DV_DB_NULL == dtp)
	return NULL;
      else if (IS_BLOB_HANDLE (val))
	{
	  str = blob_to_string (qi->qi_trx, val);
	  if (DV_WIDESTRINGP (str))
	    {
	      caddr_t str1 = box_wide_as_utf8_char (str, box_length (str) / sizeof (wchar_t) - 1, DV_LONG_STRING);
	      dk_free_box (str);
	      str = str1;
	      charset = NULL;
	    }
	}
      else if (DV_RDF == dtp)
        {
          rdf_bigbox_t *rbb = (rdf_bigbox_t *)val;
          if (!rbb->rbb_base.rb_chksum_tail)
            return NULL;
          if (DV_XML_ENTITY != rbb->rbb_box_dtp)
            return NULL;
          if (! rbb->rbb_base.rb_is_complete)
            rb_complete (&(rbb->rbb_base), qi->qi_trx, qi);
          if (DV_XML_ENTITY == DV_TYPE_OF (rbb->rbb_base.rb_box))
            return box_copy_tree (rbb->rbb_base.rb_box);
          val = rbb->rbb_base.rb_box;
          dtp = DV_TYPE_OF (val);
          goto val_is_xpack_serialization; /* see below */
        }
      else
        {
	  if (xqr->xqr_is_quiet)
	    return NULL;
	  sqlr_new_error ("HT002", "XI022", "Can't make XML tree from datum of type %d", (int) dtp);
        }
      if (xqr->xqr_xml_parser_cfg)
        {
	  caddr_t boxed_abs_uri = (('\0' != abs_uri[0]) ? box_dv_short_string (abs_uri) : NULL);
          tree = (caddr_t *) xml_make_mod_tree (qi, str, &err, GE_XML, boxed_abs_uri, charset, server_default_lh, xqr->xqr_xml_parser_cfg, &dtd, NULL, NULL);
          dk_free_box (boxed_abs_uri);
        }
      else
        tree = (caddr_t *) xml_make_tree (qi, str, &err, charset, server_default_lh, &dtd);
      if (str != val)
	dk_free_box (str);
      if (!tree)
	{
	  if (xqr->xqr_is_quiet)
	    {
	      dk_free_tree (err);
	      return NULL;
	    }
	  else
	    sqlr_resignal (err);
	}
      xe = (xml_entity_t *) xte_from_tree ((caddr_t) tree, qi);
      xe->xe_doc.xd->xd_dtd = dtd; /* Refcounter added inside xml_make_tree */
      if ('\0' != abs_uri[0])
        xe->xe_doc.xd->xd_uri = box_dv_short_string (abs_uri);
      break;
    case XE_XPER_SERIALIZATION:
      {
	caddr_t boxed_abs_uri = (('\0' != abs_uri[0]) ? box_dv_short_string (abs_uri) : NULL);
        xe = (xml_entity_t *) xper_entity (qi, val, NULL, 0, boxed_abs_uri, NULL /* no encoding */, server_default_lh, NULL /* DTD config */, 1);
      }
      break;
    case XE_XPACK_SERIALIZATION:
val_is_xpack_serialization:
      if (DV_STRINGP (val))
        {
	  ses = strses_allocate();
	  ses->dks_in_buffer = val;
	  ses->dks_in_read = 0;
	  ses->dks_in_fill = box_length (val) - 1;
	}
      else if (DV_DB_NULL == dtp)
	return NULL;
      else if (IS_BLOB_HANDLE (val))
	{
	  if (1 || DV_BLOB_WIDE_HANDLE == dtp)
	    ses = blob_to_string_output (qi->qi_trx, val);
	}
      else
	sqlr_new_error ("HT002", "XI022", "Can't deserialize XML tree from datum of type %d", (int) dtp);
      xte_deserialize_packed (ses, &tree, &dtd);
      ses->dks_in_buffer = NULL;
      if (NULL == tree)
        {
          strses_free (ses);
	  sqlr_new_error ("HT002", "XI034", "Can't deserialize a packed XML tree: data corrupted");
	}
      xe = (xml_entity_t *) xte_from_tree ((caddr_t) tree, qi);
      if (NULL != dtd)
	dtd_addref (dtd, 0);
      xe->xe_doc.xd->xd_dtd = dtd;
      if ('\0' != abs_uri[0])
        xe->xe_doc.xd->xd_uri = box_dv_short_string (abs_uri);
      strses_free (ses);
      break;
    default:
      GPF_T;
    }
  return  (xe);
}

#define XN_QST_SET(xn, qst, ssl, v) \
   do { \
      if ((xn)->src_gen.src_sets) \
	{ \
	  data_col_t * dc = QST_BOX (data_col_t *, qst, (ssl)->ssl_index); \
	  dc_append_box (dc, v); \
	} \
      else \
	qst_set ((qst), (ssl), (v)); \
   } while (0)

caddr_t
xn_init (xpath_node_t * xn, query_instance_t * qi)
{
  volatile SQLRETURN rc = SQL_NO_DATA_FOUND;
  xml_entity_t * ctx_xe;
  xp_instance_t * xqi = NULL;
  int save_xqi = 0;
  caddr_t * qst = (caddr_t*) qi;
  xp_query_t * volatile xqr = NULL;
  caddr_t val = NULL;
  caddr_t err = NULL;
  qst_set (qst, xn->xn_xqi, NULL);
  if (xn->xn_exp_for_xqr_text)
    {
      caddr_t str = qst_get (qst, xn->xn_exp_for_xqr_text);
      caddr_t prev_str = qst_get (qst, xn->xn_compiled_xqr_text);
      if (!prev_str || !box_equal (prev_str, str))
	{
	  caddr_t _str = DV_WIDESTRINGP (str) ?
	      box_wide_as_utf8_char (str, box_length (str) / sizeof (wchar_t) - 1, DV_SHORT_STRING) :
	      NULL;
	  caddr_t str_to_parse = (_str ? _str : str);
	  if (!DV_STRINGP(str_to_parse) && (NULL != str_to_parse))
	    {
	      dk_free_box (_str);
	      return srv_make_new_error ("37000", "XM009", "XPATH interpreter: input text is not a string");
	    }
	  xqr = xp_query_parse (qi, str_to_parse, xn->xn_predicate_type, &err, &xqre_default);
	  dk_free_box (_str);
	  if (err)
	    return err;
	  if (qi->qi_query->qr_no_cast_error)
            xqr->xqr_is_quiet = 1;
	  qst_set (qst, xn->xn_compiled_xqr, (caddr_t) xqr);
	  qst_set (qst, xn->xn_compiled_xqr_text, box_copy_tree (str));
	  xqr->xqr_wr_enabled = 0;
	}
      else
	xqr = (xp_query_t *) qst_get (qst, xn->xn_compiled_xqr);
    }
  else if (!xqr)
    {
      xqr = (xp_query_t *) qst_get (qst, xn->xn_compiled_xqr);
      if (!xqr)
	sqlr_new_error ("42000", "XI024", "XPATH node with no precompiled xqr but with preceding txs node");
    }
  if (!xqr->xqr_is_quiet)
    ctx_xe = xn_xe_from_text (xn, qi);
  else
    {
      QR_RESET_CTX_T (qi->qi_thread)
	{
	  ctx_xe = xn_xe_from_text (xn, qi);
	}
      QR_RESET_CODE
	{
	  du_thread_t *self = THREAD_CURRENT_THREAD;
	  caddr_t err = thr_get_error_code (self);
	  POP_QR_RESET;
	  dk_free_tree (err);
	  return ((caddr_t) SQL_NO_DATA_FOUND);
	}
      END_QR_RESET;
    }
  if (!ctx_xe)
    return ((caddr_t) SQL_NO_DATA_FOUND);
  xqi = xqr_instance (xqr, qi);
  /* IvAn/SmartXContains/001025 WR-Optimization added */
  if (xqi->xqi_text_node != xn->xn_text_node)
    {
      if (!xqr->xqr_wr_enabled)
	{
	  xp_query_enable_wr (xqr, xqr->xqr_tree, 0);
	  xqr->xqr_wr_enabled = 1;
	}
      xqi->xqi_text_node = xn->xn_text_node;
    }
  if ('q' == xn->xn_predicate_type)
    {
      xqi->xqi_return_attrs_as_nodes = 1;
      xqi->xqi_xpath2_compare_rules = 1;
    }
  if (xn->xn_output_ctr)
    qst_set (qst, xn->xn_output_ctr, box_num(0));
  QR_RESET_CTX_T (qi->qi_thread)
    {
      int predicted = xt_predict_returned_type (xqr->xqr_tree);
      xqi_eval (xqi, xqr->xqr_tree, ctx_xe);
      dk_free_box ((caddr_t) ctx_xe);
      if (!xn->xn_output_val)
	{
	  int has_hit = xqi_truth_value (xqi, xqr->xqr_tree);
	  xqi_free (xqi);
	  POP_QR_RESET;
	  return ((caddr_t) (ptrlong) (has_hit ? SQL_SUCCESS : SQL_NO_DATA_FOUND));
	}
      if (XPDV_BOOL == predicted)
	{
	  int has_hit = xqi_truth_value (xqi, xqr->xqr_tree);
	  XN_QST_SET (xn, qst, xn->xn_output_val, box_num (has_hit ? 1 : 0));
	  xqi_free (xqi);
	  POP_QR_RESET;
	  return ((caddr_t) SQL_SUCCESS);
	}

      val = xqi_raw_value (xqi, xqr->xqr_tree);

      if (NULL == val)
	{
	  xqi_free (xqi);
	  POP_QR_RESET;
	  return ((caddr_t) SQL_NO_DATA_FOUND);
	}
try_next_val:
      if (xn->xn_output_ctr && (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val)))
	{
	  ptrlong len;
	  len = BOX_ELEMENTS (val);
	  qst_set (qst, xn->xn_output_len, box_num (len));
	  qst_set (qst, xn->xn_output_ctr, box_num (1));
	  save_xqi = 1;
	  if (0 == len)
	    {
	      if (!xqi_is_next_value (xqi, xqi->xqi_xqr->xqr_tree))
		{
		  xqi_free (xqi);
		  POP_QR_RESET;
		  return ((caddr_t) SQL_NO_DATA_FOUND);
		}
	      val = xqi_raw_value (xqi, xqr->xqr_tree);
	      goto try_next_val;
	    }
	  val = ((caddr_t *)(val))[0];
	}
      rc = SQL_SUCCESS;
      if (XPDV_NODESET == predicted)
	{
	  XN_QST_SET (xn, qst, xn->xn_output_val, DV_STRINGP (val) ?
	    box_utf8_as_wide_char (val, NULL, box_length (val), 0, DV_WIDE) :
	    box_copy_tree (val) );
	  save_xqi = 1;
	}
      else
	{
	  rc = SQL_SUCCESS;
	  XN_QST_SET (xn, qst, xn->xn_output_val, DV_STRINGP (val) ?
	    box_utf8_as_wide_char (val, NULL, box_length (val), 0, DV_WIDE) :
	    box_copy_tree (val));
	}
      if (save_xqi)
	qst_set (qst, xn->xn_xqi, (caddr_t) xqi);
      else
	xqi_free (xqi);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      if (xqi)
	xqi_free (xqi);
      POP_QR_RESET;
      if (err)
	sqlr_resignal (err);
      return ((caddr_t) SQL_NO_DATA_FOUND);
    }
  END_QR_RESET;
  return ((caddr_t) (ptrlong) rc);
}


caddr_t
xn_next (xpath_node_t * xn, caddr_t * qst)
{
  query_instance_t * qi = (query_instance_t *) qst;
  xp_instance_t * xqi = (xp_instance_t *) qst_get (qst, xn->xn_xqi);
  QR_RESET_CTX_T (qi->qi_thread)
    {
      caddr_t val;
      if (xn->xn_output_ctr)
	{
	  ptrlong ctr = unbox (QST_GET (qst, xn->xn_output_ctr));
	  ptrlong len = unbox (QST_GET (qst, xn->xn_output_len));
	  if (ctr < len)
	    {
	      val = xqi_raw_value (xqi, xqi->xqi_xqr->xqr_tree);
	      val = ((caddr_t *)(val))[ctr];
	      qst_set (qst, xn->xn_output_ctr, box_num(1+ctr));
	    }
	  else
	    {
try_next_val:
	      if (!xqi_is_next_value (xqi, xqi->xqi_xqr->xqr_tree))
		{
		  qst_set (qst, xn->xn_xqi, NULL);
		  POP_QR_RESET;
		  return ((caddr_t) SQL_NO_DATA_FOUND);
		}
	      qst_set (qst, xn->xn_output_len, box_num(0));
	      qst_set (qst, xn->xn_output_ctr, box_num(0));
	      val = xqi_raw_value (xqi, xqi->xqi_xqr->xqr_tree);
	      if (DV_ARRAY_OF_XQVAL == DV_TYPE_OF (val))
		{
		  ptrlong len;
		  len = BOX_ELEMENTS (val);
		  qst_set (qst, xn->xn_output_len, box_num(len));
		  qst_set (qst, xn->xn_output_ctr, box_num(1));
		  if (0 == len)
		    goto try_next_val;
		  val = ((caddr_t *)(val))[0];
		}
	    }
	}
      else
	{
	  if (xqi_is_next_value (xqi, xqi->xqi_xqr->xqr_tree))
	    val = xqi_raw_value (xqi, xqi->xqi_xqr->xqr_tree);
	  else
	    {
	      qst_set (qst, xn->xn_xqi, NULL);
	      POP_QR_RESET;
	      return ((caddr_t) SQL_NO_DATA_FOUND);
	    }
	}
      if (NULL != xn->xn_output_val)
	XN_QST_SET (xn, qst, xn->xn_output_val, DV_STRINGP (val) ?
	  box_utf8_as_wide_char (val, NULL, box_length (val), 0, DV_WIDE) :
	  box_copy_tree (val));
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      qst_set (qst, xn->xn_xqi, NULL);
      POP_QR_RESET;
      if (err)
	sqlr_resignal (err);
      return ((caddr_t) SQL_NO_DATA_FOUND);
    }
  END_QR_RESET;
  return ((caddr_t) (ptrlong) SQL_SUCCESS);
}


void
xn_free (xpath_node_t * xn)
{
}

void
xn_vec_input (xpath_node_t * xn, caddr_t * inst, caddr_t *state)
{
  int n_sets = QST_INT (inst, xn->src_gen.src_prev->src_out_fill);
  int nth_set, first_time = 0, batch_sz;
  QNCAST (data_source_t, qn, xn);
  caddr_t err = NULL;

  if (state)
    nth_set = QST_INT (inst, xn->clb.clb_nth_set) = 0;
  else /* continue */
    {
      nth_set = QST_INT (inst, xn->clb.clb_nth_set);
      if (!xn->xn_output_val || !qst_get (inst, xn->xn_xqi))
	state = SRC_IN_STATE (qn, inst);
    }

again:
  batch_sz = QST_INT (inst, xn->src_gen.src_batch_size);
  QST_INT (inst, qn->src_out_fill) = 0;
  dc_reset_array (inst, qn, qn->src_continue_reset, -1);
  for (; nth_set < n_sets; nth_set ++)
    {
      QNCAST (query_instance_t, qi, inst);
      qi->qi_set = nth_set;
      for (;;)
	{
	  if (!state)
	    {
	      state = SRC_IN_STATE (qn, inst);
	      err = xn_next (xn, state);
	    }
	  else
	    {
	      err = xn_init (xn, (query_instance_t *) state);
	    }
	  first_time = 0;
	  if (err != SQL_SUCCESS)
	    {
	      SRC_IN_STATE (qn, inst) = NULL;
	      if (err != (caddr_t) SQL_NO_DATA_FOUND)
		sqlr_resignal (err);
	      break;
	    }
	  qn_result (qn, inst, nth_set);
	  SRC_IN_STATE (qn, inst) = state;
	  if (!xn->xn_output_val || !qst_get (inst, xn->xn_xqi))
	    {
	      nth_set ++;
	      QST_INT (inst, xn->clb.clb_nth_set) = nth_set;
	      qn_send_output (qn, inst);
	      goto again;
	    }
	  state = NULL;
	  if (QST_INT (inst, qn->src_out_fill) >= batch_sz)
	    {
	      nth_set ++;
	      QST_INT (inst, xn->clb.clb_nth_set) = nth_set;
	      qn_send_output (qn, inst);
	      goto again;
	    }
	}
    }

  SRC_IN_STATE (qn, inst) = NULL;
  if (QST_INT (inst, qn->src_out_fill))
    qn_send_output (qn, inst);
}

void
xn_input (xpath_node_t * xn, caddr_t * inst, caddr_t *state)
{
  caddr_t err;
  if (xn->src_gen.src_sets)
    {
      xn_vec_input (xn, inst, state);
      return;
    }
  for (;;)
    {
      if (!state)
	{
	  state = qn_get_in_state ((data_source_t *) xn, inst);
	  err = xn_next (xn, state);
	}
      else
	{
	  err = xn_init (xn, (query_instance_t *) state);
	}

      if (err == SQL_SUCCESS)
	{
	  if (!xn->src_gen.src_after_test
	      || code_vec_run (xn->src_gen.src_after_test, inst))
	    {
	      if (qst_get (inst, xn->xn_xqi))
		{
		  qn_record_in_state ((data_source_t *) xn, inst, state);
		  qn_send_output ((data_source_t *) xn, inst);
		}
	      else
		{
		  qn_record_in_state ((data_source_t *) xn, inst, NULL);
		  qn_send_output ((data_source_t *) xn, inst);
		  return;
		}
	    }
	  else if (xn->src_gen.src_after_test && xn->xn_output_val)
	    {
	      qn_record_in_state ((data_source_t *) xn, inst, state);
	    }
	  else
	    {
	      qn_record_in_state ((data_source_t *) xn, inst, NULL);
	      return;
	    }
	}
      else
	{
	  qn_record_in_state ((data_source_t *) xn, inst, NULL);
	  if (err != (caddr_t) SQL_NO_DATA_FOUND)
	    sqlr_resignal (err);
	  return;
	}
      state = NULL;
    }
}


caddr_t
xn_text_query (xpath_node_t * xn, query_instance_t * qi, caddr_t xp_str)
{
  /* with a combination of text_node, table_source, xp_node
   * the txs calls this to get the text part of the query */
  caddr_t * qst = (caddr_t *) qi;
  caddr_t err = NULL;
  xp_query_t * xqr;
  caddr_t prev_text = qst_get (qst, xn->xn_compiled_xqr_text);
  if (prev_text && 0 == strcmp (prev_text, xp_str))
    xqr = (xp_query_t *) qst_get (qst, xn->xn_compiled_xqr);
  else
    {
      caddr_t _str = DV_WIDESTRINGP (xp_str) ?
	      box_wide_as_utf8_char (xp_str, box_length (xp_str) / sizeof (wchar_t) - 1, DV_SHORT_STRING) :
	      NULL;
      caddr_t str_to_parse = (_str ? _str : xp_str);
      if (!DV_STRINGP(str_to_parse) && (NULL != str_to_parse))
        {
          dk_free_box (_str);
          sqlr_error ("37000", "XPATH interpreter: input text is not a string");
        }
      xqr = xp_query_parse (qi, str_to_parse, xn->xn_predicate_type, &err, &xqre_default);
      dk_free_box (_str);
      if (err)
	sqlr_resignal (err);
      if (qi->qi_query->qr_no_cast_error)
	xqr->xqr_is_quiet = 1;
      qst_set (qst, xn->xn_compiled_xqr, (caddr_t) xqr);
      qst_set (qst, xn->xn_compiled_xqr_text, box_copy_tree (xp_str));
    }
  return ((caddr_t) xpt_text_exp (xqr->xqr_tree, NULL));
}


caddr_t
txs_xn_text_query (text_node_t * txs, query_instance_t * qi, caddr_t xp_str)
{
  /* with a combination of text_node, table_source, xp_node
   * the txs calls this to get the text part of the query */
  caddr_t * qst = (caddr_t *) qi;
  caddr_t err = NULL;
  xp_query_t * xqr;
  caddr_t prev_text = qst_get (qst, txs->txs_xn_xq_source);
  if (prev_text && 0 == strcmp (prev_text, xp_str))
    xqr = (xp_query_t *) qst_get (qst, txs->txs_xn_xq_compiled);
  else
    {
      caddr_t _str = DV_WIDESTRINGP (xp_str) ?
	      box_wide_as_utf8_char (xp_str, box_length (xp_str) / sizeof (wchar_t) - 1, DV_SHORT_STRING) :
	      NULL;
      caddr_t str_to_parse = (_str ? _str : xp_str);
      if (!DV_STRINGP(str_to_parse) && (NULL != str_to_parse))
        {
          dk_free_box (_str);
          sqlr_error ("37000", "XPATH interpreter: input text is not a string");
        }
      xqr = xp_query_parse (qi, str_to_parse, txs->txs_xn_pred_type, &err, &xqre_default);
      dk_free_box (_str);
      if (err)
	sqlr_resignal (err);
      if (qi->qi_query->qr_no_cast_error)
	xqr->xqr_is_quiet = 1;
      qst_set (qst, txs->txs_xn_xq_compiled, (caddr_t) xqr);
      qst_set (qst, txs->txs_xn_xq_source, box_copy_tree (xp_str));
    }
  return ((caddr_t) xpt_text_exp (xqr->xqr_tree, NULL));
}


caddr_t
xml_deserialize_from_blob (caddr_t bh, lock_trx_t *lt, caddr_t *qst, caddr_t uri)
{
  int bh_sort;
  caddr_t *tree1 = NULL;
  xml_tree_ent_t * xte;
  dtd_t *dtd = NULL; /* set always to NULL to be sure that assigned element is valid */
  id_hash_t *id_cache = NULL; /* this too */
  xml_ns_2dict_t ns_2dict;
  ns_2dict.xn2_size = 0; /* this too */
  if (!qst)
    {
      dk_free_box (uri);
      return bh;
    }
  if (DV_XML_ENTITY == DV_TYPE_OF (bh))
    {
      dk_free_box (uri);
      return bh;
    }
  bh_sort = looks_like_serialized_xml ((query_instance_t *)qst, bh);
  switch (bh_sort)
    {
    case XE_PLAIN_TEXT:
    case XE_PLAIN_TEXT_OR_SERIALIZED_VECTOR:	/* This means that the bh can contain either plain text or serialization. Serialization is not supported here so let's hope that this is plain text :) */
    {
      caddr_t volatile charset = (caddr_t) (QST_CHARSET (qst) ? QST_CHARSET (qst) : default_charset);
      caddr_t volatile err;
      QR_RESET_CTX
	{
          static caddr_t dtd_config = NULL;
	  if (NULL == dtd_config)
	    dtd_config = box_dv_short_string ("Validation=DISABLE Include=IGNORE IdCache=ENABLE");
	  tree1 = (caddr_t *) xml_make_mod_tree ((query_instance_t *)qst, bh, (caddr_t *) &err,
	      GE_XML, uri, CHARSET_NAME (charset, NULL),
	      server_default_lh,
	      dtd_config,
	      &dtd, &id_cache, &ns_2dict);
	  if (NULL == tree1)
	    {
	      dk_free_box (uri);
	      sqlr_resignal (err);
	    }
	}
      QR_RESET_CODE
	{
	  du_thread_t *self = THREAD_CURRENT_THREAD;
	  caddr_t err = thr_get_error_code (self);
	  POP_QR_RESET;
	  dk_free_tree (err);
	  dk_free_box (uri);
	  return NEW_DB_NULL;
	}
      END_QR_RESET;
      break;
    }
    case XE_XPER_SERIALIZATION:
      {
        static caddr_t dtd_config = NULL;
        if (NULL == dtd_config)
          dtd_config = box_dv_short_string ("Validation=OFF Include=IGNORE IdCache=ENABLE");
        return (caddr_t) xper_entity (NULL, bh, NULL, GE_XML, uri, NULL /* no enc */, &lh__xany, dtd_config, 1);
      }
    case XE_XPACK_SERIALIZATION:
    {
      if (IS_BLOB_HANDLE (bh))
        {
          dk_session_t *ses = blob_to_string_output (lt, bh);
          xte_deserialize_packed (ses, &tree1, &dtd);
          dk_free_box ((box_t) ses);
          if (NULL != dtd)
            dtd_addref (dtd, 0);
        }
      else
        {
	  dk_session_t ses;
	  scheduler_io_data_t sio;
	  size_t len = box_length (bh);
	  memset (&ses, 0, sizeof (dk_session_t));
	  memset (&sio, 0, sizeof (scheduler_io_data_t));
	  SESSION_SCH_DATA (&ses) = &sio;
	  ses.dks_in_buffer = bh;
	  ses.dks_in_fill = (int) (len - 1);
          xte_deserialize_packed (&ses, &tree1, &dtd);
          if (NULL != dtd)
	    dtd_addref (dtd, 0);
        }
      if (NULL == tree1)
        {
          dk_free_box (uri);
	  return NEW_DB_NULL;
	}
      break;
    }
    default:
      GPF_T;
  }
  xte = xte_from_tree ((caddr_t) tree1, (query_instance_t*) qst);
  xte->xe_doc.xd->xd_uri = uri;
  xte->xe_doc.xd->xd_dtd = dtd; /* The refcounter is incremented either inside xml_make_mod_tree or after xte_deserialize_packed */
  xte->xe_doc.xd->xd_id_dict = id_cache;
  xte->xe_doc.xd->xd_id_scan = XD_ID_SCAN_COMPLETED;
  xte->xe_doc.xd->xd_ns_2dict = ns_2dict;
  return ((caddr_t) xte);
}


#define XU_OP_REPLACE	1
#define XU_OP_INSERTBEFORE	2
#define XU_OP_INSERTAFTER	3


typedef struct xmlupdate_item_s {
  ptrlong *xu_src_pos;
  caddr_t xu_src_attr_name;
  caddr_t xu_repl_value;
  ptrlong xu_value_is_owned_by_caller;
  ptrlong xu_value_is_constant;
  ptrlong xu_operation;
} xmlupdate_item_t;


int xu_are_items_neighbour (ptrlong *pos1, ptrlong *pos2)
{
  int pos1len = BOX_ELEMENTS ((caddr_t)(pos1));
  if (BOX_ELEMENTS ((caddr_t)(pos2)) != pos1len)
    return 0;
  if (memcmp (pos1, pos2, (pos1len - 1) * sizeof(ptrlong)))
    return 0;
  return ((pos1[pos1len - 1] + 1) == pos2[pos1len - 1]);
}


/*! Bubble sort \c size first buffers in the \c items array. */
void
xu_bsort (xmlupdate_item_t *items, int size)
{
  int left, right;
  for (right = size; right--; /* no step*/)
    {
      for (left = 0; left < right; left++)
	{
	  xmlupdate_item_t tmp;
	  xmlupdate_item_t *i1 = items+left;
	  xmlupdate_item_t *i2 = i1 + 1;
	  ptrlong *pos1 = i1->xu_src_pos;
	  ptrlong *pos2 = i2->xu_src_pos;
	  int cmp = xe_compare_logical_paths (pos1, BOX_ELEMENTS(pos1), pos2, BOX_ELEMENTS(pos2));
	  if (XE_CMP_A_IS_EQUAL_TO_B == cmp)
	    {
	      caddr_t attr1 = i1->xu_src_attr_name;
	      caddr_t attr2 = i2->xu_src_attr_name;
	      cmp = strcmp ((attr1 ? attr1 : ""), (attr2 ? attr2 : ""));
	    }
	  if (0 < cmp)
	    {
	      tmp = i1[0];
	      i1[0] = i2[0];
	      i2[0] = tmp;
	    }
	}
    }
}


int xu_remove_redundant (xmlupdate_item_t *xu_list, int old_size, ptrlong doc, dk_set_t *garbage)
{
  int res_size = 0;
  int xu_ctr;
  xmlupdate_item_t *prev_any = NULL;
  xmlupdate_item_t *prev_nonattr = NULL;
  for (xu_ctr = 0; xu_ctr < old_size; xu_ctr++)
    {
      xmlupdate_item_t *curr = xu_list + xu_ctr;
      ptrlong *path = curr->xu_src_pos;
      int cmp;
      if (path[0] != doc)
        goto kill_curr;	/* See below */
      if (NULL == curr->xu_src_attr_name)
	{
	  if (NULL == prev_nonattr)
            goto preserve_curr; /* First nonattr from our doc is always OK. */
          cmp = xe_compare_logical_paths (prev_nonattr->xu_src_pos, BOX_ELEMENTS(prev_nonattr->xu_src_pos), path, BOX_ELEMENTS(path));
	  switch (cmp)
	    {
	    case XE_CMP_A_IS_BEFORE_B: goto preserve_curr;	/* See below */
	    case XE_CMP_A_IS_ANCESTOR_OF_B: goto kill_curr;	/* See below */
	    case XE_CMP_A_IS_EQUAL_TO_B: goto overwrite_prev;	/* See below */
            default: GPF_T;
	    }
	}
      else
	{
	  if (NULL == prev_any)
            goto preserve_curr; /* First any from our doc is always OK. */
	  if (NULL != prev_nonattr)
	    {
              cmp = xe_compare_logical_paths (prev_nonattr->xu_src_pos, BOX_ELEMENTS(prev_nonattr->xu_src_pos), path, BOX_ELEMENTS(path));
	      switch (cmp)
		{
		case XE_CMP_A_IS_BEFORE_B: break;	/* See below */
		case XE_CMP_A_IS_ANCESTOR_OF_B: goto kill_curr;	/* See below */
		case XE_CMP_A_IS_EQUAL_TO_B: goto kill_curr;	/* See below */
		default: GPF_T;
		}
	    }
	  if (prev_nonattr != prev_any)
	    {
	      caddr_t prev_attr = prev_any->xu_src_attr_name;
	      caddr_t curr_attr = curr->xu_src_attr_name;
	      if (strcmp (prev_attr, curr_attr))
		goto preserve_curr;	/* See below */
	      goto overwrite_prev;	/* See below */
	    }
	  goto preserve_curr;	/* See below */
        }
preserve_curr:
      if (xu_ctr > res_size)
        {
          xu_list[res_size] = curr[0];
          curr->xu_repl_value = NULL;
          curr->xu_src_pos = NULL;
        }
      prev_any = xu_list + res_size;
      if (NULL == prev_any->xu_src_attr_name)
	prev_nonattr = prev_any;
      res_size++;
      continue;
kill_curr:
      if (!curr->xu_value_is_owned_by_caller)
        {
          dk_set_push (garbage, curr->xu_repl_value);
          curr->xu_repl_value = NULL;
        }
      dk_free_box ((box_t) curr->xu_src_pos);
      curr->xu_src_pos = NULL;
      dk_free_box (curr->xu_src_attr_name);
      curr->xu_src_attr_name = NULL;
      continue;
overwrite_prev:
      if (!prev_any->xu_value_is_owned_by_caller)
        {
          dk_set_push (garbage, prev_any->xu_repl_value);
          prev_any->xu_repl_value = NULL;
        }
      dk_free_box ((box_t) prev_any->xu_src_pos);
      dk_free_box (prev_any->xu_src_attr_name);
      if (((prev_any->xu_src_attr_name == NULL) ? 1 : 0) != ((curr->xu_src_attr_name == NULL) ? 1 : 0))
	GPF_T;
      prev_any[0] = curr[0];
      continue;
    }
  return res_size;
}

#define XE_REPLACE_CONCAT_BEFORE	0x01
#define XE_REPLACE_CONCAT_AFTER		0x02

#define XTE_REPLACE_GC_BOX(gc,box) if (NULL == (gc)) dk_free_box ((box_t) box); else dk_set_push (&(gc->xtd_garbage_boxes), (box))
#define XTE_REPLACE_GC_TREE(gc,box) if (NULL == (gc)) dk_free_tree ((box_t) box); else dk_set_push (&(gc->xtd_garbage_trees), (box))


void xu_list_subtrees_of_repl (caddr_t repl, caddr_t *repl_current, caddr_t **subtrees_ret, ptrlong *subtrees_ctr_ret)
{
  switch (DV_TYPE_OF (repl))
    {
    case DV_XML_ENTITY:
      repl_current[0] = (caddr_t)(((xml_tree_ent_t *)(repl))->xte_current);
      if ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (repl_current[0])) &&
        (uname__root == XTE_HEAD_NAME(XTE_HEAD(repl_current[0]))) )
        {
          subtrees_ret[0] = ((caddr_t *)(repl_current[0])) + 1;
          subtrees_ctr_ret[0] = BOX_ELEMENTS (repl_current[0]) - 1;
        }
      else
        {
          subtrees_ret[0] = repl_current;
          subtrees_ctr_ret[0] = 1;
        }
      break;
    case DV_STRING:
      if (1 < box_length (repl))
        {
          repl_current[0] = repl;
          subtrees_ret[0] = repl_current;
          subtrees_ctr_ret[0] = 1;
        }
      else
        {  /* Empty string can not be placed into the tree */
	  subtrees_ret[0] = NULL;
	  subtrees_ctr_ret[0] = 0;
        }
      break;
    case DV_DB_NULL:
      subtrees_ret[0] = NULL;
      subtrees_ctr_ret[0] = 0;
      break;
    default: GPF_T;
    }
}


caddr_t xte_replace (xml_tree_ent_t *xte, caddr_t repl, int flags, xml_tree_doc_t *gc)
{
  if (xte->xe_attr_name)
    {
      caddr_t *head = XTE_HEAD (xte->xte_current);
      int headlen = BOX_ELEMENTS (head);
      int attrctr;
      for (attrctr = 1; attrctr < headlen; attrctr += 2)
        {
	  if (strcmp (head[attrctr], xte->xe_attr_name))
	    continue;
	  if (NULL != gc)
	    {
	      caddr_t *old_current = xte->xte_current;
              dk_set_push (&(gc->xtd_garbage_boxes), (void *)old_current);
              old_current = xte->xte_current = (caddr_t *) box_copy ((box_t) old_current);
              if (XTE_HAS_PARENT(xte))
		XTE_PARENT_SUBTREE(xte)[xte->xte_child_no] = (caddr_t)old_current;
	      else
		{
		  xte->xe_doc.xtd->xtd_tree = old_current;
		  xte->xte_stack_buf->xteb_current = xte->xe_doc.xtd->xtd_tree;
		}
	      dk_set_push (&(gc->xtd_garbage_boxes), (void *)head);
	      head = XTE_HEAD (xte->xte_current) = (caddr_t *) box_copy ((box_t) head);
	    }
	  switch (DV_TYPE_OF (repl))
	    {
	    case DV_STRING:
	      XTE_REPLACE_GC_BOX (gc, head[attrctr+1]);
	      head[attrctr+1] = box_copy (repl);
	      return (caddr_t)(xte);
	    case DV_DB_NULL:
	      {
		caddr_t *newhead = (caddr_t *) dk_alloc_box ((headlen - 2) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
		memcpy (newhead, head, attrctr * sizeof (caddr_t));
		memcpy (newhead + attrctr, head + attrctr + 2, (headlen - (attrctr + 2)) * sizeof (caddr_t));
		XTE_REPLACE_GC_BOX (gc, head[attrctr]);
		XTE_REPLACE_GC_BOX (gc, head[attrctr + 1]);
		XTE_REPLACE_GC_BOX (gc, head);
		XTE_HEAD (xte->xte_current) = newhead;
		dk_free_box (xte->xe_attr_name);
		xte->xe_attr_name = NULL;
	        return (caddr_t)(xte);
	      }
	    default: GPF_T;
	    }
        }
      /* return (caddr_t)(xte); */
      GPF_T;
    }
  if (XTE_HAS_PARENT(xte))
    {
      caddr_t *old_children = XTE_PARENT_SUBTREE(xte);
      ptrlong old_children_no = BOX_ELEMENTS (old_children);
      ptrlong old_begin_len = xte->xte_stack_top[0].xteb_child_no;
      ptrlong old_tail_ofs = old_begin_len + 1; /* Skip the item to replace */
      caddr_t repl_current = NULL; /* A temporary placeholder for the value of \c subtrees */
      caddr_t *subtrees = NULL;
      ptrlong subtrees_ctr = 0;
      int might_concat_before;
      int might_concat_after;
      ptrlong new_children_no;
      ptrlong idx;
      if (NULL != gc)
        {
          dk_set_push (&(gc->xtd_garbage_boxes), (void *)old_children);
          old_children = XTE_PARENT_SUBTREE(xte) = (caddr_t *) box_copy ((box_t) old_children);
          if (XTE_HAS_2PARENTS(xte))
	    xte->xte_stack_top[-2].xteb_current[xte->xte_stack_top[-1].xteb_child_no] = (caddr_t) old_children;
	  else
	    {
	      xte->xe_doc.xtd->xtd_tree = old_children;
	      xte->xte_stack_buf->xteb_current = xte->xe_doc.xtd->xtd_tree;
	    }
        }
      xu_list_subtrees_of_repl (repl, &repl_current, &subtrees, &subtrees_ctr); /* The \c subtrees is valid while \c repl_current is defined. */
/* Normalizations: */
normalize_again:
      might_concat_before = (
        (XE_REPLACE_CONCAT_BEFORE & flags) &&
        (1 < old_begin_len) &&
        (DV_STRING == DV_TYPE_OF (old_children[old_begin_len - 1])) );
      might_concat_after = (
        (XE_REPLACE_CONCAT_AFTER & flags) &&
        (old_tail_ofs < old_children_no) &&
        (DV_STRING == DV_TYPE_OF (old_children[old_tail_ofs])) );
      if (might_concat_after)
	{
	  if (0 == subtrees_ctr)
	    {
	      if (might_concat_before)
	        {
	          caddr_t tmp = box_dv_short_concat (old_children[old_begin_len - 1], old_children[old_tail_ofs]);
	          XTE_REPLACE_GC_BOX (gc, old_children[old_tail_ofs]);
	          old_children[old_tail_ofs] = tmp;
	          old_begin_len--;
	          goto normalize_again;
	        }
	    }
	  else
	    {
	      if (DV_STRING == DV_TYPE_OF (subtrees[subtrees_ctr - 1]))
	        {
	          caddr_t tmp = box_dv_short_concat (subtrees[subtrees_ctr - 1], old_children[old_tail_ofs]);
	          XTE_REPLACE_GC_BOX (gc, old_children[old_tail_ofs]);
	          old_children[old_tail_ofs] = tmp;
	          subtrees_ctr -= 1;
	          goto normalize_again;
	        }
	    }
	}
      if (might_concat_before)
        {
          if ((0 < subtrees_ctr) && DV_STRING == DV_TYPE_OF (subtrees[0]))
	    {
	      caddr_t tmp = box_dv_short_concat (old_children[old_begin_len - 1], subtrees[0]);
	      XTE_REPLACE_GC_BOX (gc, old_children[old_begin_len - 1]);
	      old_children[old_begin_len - 1] = tmp;
	      subtrees++;
	      subtrees_ctr -= 1;
	      goto normalize_again;
	    }
        }
/* Now we know how many children we will have under parent of the subtree to replace, counting head as a child */
      new_children_no = old_begin_len + subtrees_ctr + old_children_no - old_tail_ofs;
/* Shit happens if we're about to delete the only child of the root (besides the root head of course) */
      if (!XTE_HAS_2PARENTS(xte) && (1 >= new_children_no))
        return NEW_DB_NULL;
/* Composing new array of children and return */
      for (idx = old_begin_len; idx < old_tail_ofs; idx++)
	XTE_REPLACE_GC_TREE (gc, old_children[idx]);
      if (old_begin_len + subtrees_ctr == old_tail_ofs) /* If length is unchanged then patch an old one */
        {
          for (idx = subtrees_ctr; idx--; /* no step*/ )
	    old_children [old_begin_len + idx] = box_copy_tree (subtrees [idx]);
          xte->xte_current = (caddr_t *) old_children [old_begin_len];
        }
      else	/* if the length changes, make a patched copy */
        {
          int new_child_idx = (int) ((old_begin_len >= new_children_no) ? (new_children_no - 1) : old_begin_len);
          caddr_t *new_children = (caddr_t *) dk_alloc_box (sizeof(caddr_t) * new_children_no, DV_ARRAY_OF_POINTER);
          memcpy (new_children, old_children, sizeof(caddr_t) * old_begin_len);
          for (idx = subtrees_ctr; idx--; /* no step*/ )
            new_children [old_begin_len + idx] = box_copy_tree (subtrees [idx]);
          memcpy (new_children + old_begin_len + subtrees_ctr, old_children + old_tail_ofs, sizeof(caddr_t) * (old_children_no - old_tail_ofs));
          if (XTE_HAS_2PARENTS(xte))
            {
              xte->xte_stack_top[-2].xteb_current[xte->xte_stack_top[-1].xteb_child_no] = (caddr_t) new_children;
              XTE_PARENT_SUBTREE(xte) = new_children;
              if (0 == new_child_idx)
                xte->xte_stack_top -= 1;
              else
                {
                  xte->xte_child_no = new_child_idx;
                  xte->xte_current = (caddr_t *)new_children [new_child_idx];
                }
            }
          else /* We've just patched the root element */
            {
              xte->xe_doc.xtd->xtd_tree = new_children;
              xte->xte_stack_buf->xteb_current = xte->xe_doc.xtd->xtd_tree;
              xte->xte_stack_buf->xteb_child_no = 0;
              xte->xte_stack_top->xteb_child_no = new_child_idx;
              xte->xte_stack_top->xteb_current = new_children + new_child_idx;
            }
	  XTE_REPLACE_GC_BOX (gc, old_children);
        }
    }
  else
    {
      switch (DV_TYPE_OF (repl))
        {
        case DV_XML_ENTITY:
          XTE_REPLACE_GC_TREE (gc, xte->xe_doc.xtd->xtd_tree);
          xte->xe_doc.xtd->xtd_tree = (caddr_t *) box_copy_tree ((box_t) ((xml_tree_ent_t *)(repl))->xe_doc.xtd->xtd_tree);
          xte->xte_current = xte->xe_doc.xtd->xtd_tree;
          return (caddr_t) xte;
        case DV_STRING:
          XTE_REPLACE_GC_TREE (gc, xte->xe_doc.xtd->xtd_tree);
          if (1 < box_length (repl))
            xte->xe_doc.xtd->xtd_tree = (caddr_t *) list (2, list (1, uname__root), box_copy (repl));
          else
            xte->xe_doc.xtd->xtd_tree = (caddr_t *) list (1, list (1, uname__root));
          xte->xte_current = xte->xe_doc.xtd->xtd_tree;
          return (caddr_t)xte;
        case DV_DB_NULL:
          return NEW_DB_NULL;
        default: GPF_T;
        }
    }
  return (caddr_t)xte;
}


caddr_t xu_replace (xmlupdate_item_t *xu_list, int xu_count, xml_tree_ent_t *tgt, xml_tree_doc_t *gc)
{
  int xu_ctr;
  for (xu_ctr = xu_count; xu_ctr --; /* no step */)
    {
      xml_tree_ent_t *hit;
      xmlupdate_item_t *curr = xu_list + xu_ctr;
      ptrlong *path_ptr = curr->xu_src_pos;
      int flags = XE_REPLACE_CONCAT_AFTER;
      xe_root ((xml_entity_t *)tgt);
      hit = (xml_tree_ent_t *)tgt->_->xe_follow_path ((xml_entity_t *)tgt, path_ptr + 1, BOX_ELEMENTS(path_ptr) - 1);
      if (NULL == hit)
        GPF_T;
      if (NULL != curr->xu_src_attr_name)
        tgt->xe_attr_name = box_copy (curr->xu_src_attr_name);
      if ((0 == xu_ctr) || !xu_are_items_neighbour (curr[-1].xu_src_pos, path_ptr))
        flags |= XE_REPLACE_CONCAT_BEFORE;
      xte_tree_check (tgt->xe_doc.xtd->xtd_tree);
      hit = (xml_tree_ent_t *)xte_replace (tgt, curr->xu_repl_value, flags, gc);
      xte_tree_check (tgt->xe_doc.xtd->xtd_tree);
      if (DV_DB_NULL == DV_TYPE_OF (hit))
        return (caddr_t) hit;
      tgt = hit;
    }
  return (caddr_t) tgt;
}


void xu_free_items (xmlupdate_item_t *xu_list, int xu_count)
{
  int xu_ctr;
  for (xu_ctr = xu_count; xu_ctr--; /* no step */)
    {
      if (!xu_list[xu_ctr].xu_value_is_owned_by_caller)
        dk_free_tree (xu_list[xu_ctr].xu_repl_value);
      dk_free_box ((box_t) xu_list[xu_ctr].xu_src_pos);
      dk_free_box (xu_list[xu_ctr].xu_src_attr_name);
    }
  dk_free_box ((caddr_t)xu_list);
}


caddr_t xmlupdate_impl (caddr_t * qst, xml_tree_ent_t * src, xml_tree_ent_t * tgt, xmlupdate_item_t *xu_list)
{
  int xu_ctr, xu_ctr2;
  int xu_count;
  caddr_t res;
  dk_set_t garbage = NULL;
  xu_count = box_length ((caddr_t)(xu_list)) / sizeof (xmlupdate_item_t);
  for (xu_ctr = 0; xu_ctr < xu_count; xu_ctr++)
    {
      caddr_t orig_repl = xu_list[xu_ctr].xu_repl_value;
      caddr_t repl = orig_repl;
      dtp_t repl_dtp = DV_TYPE_OF (repl);
      if (DV_OBJECT == repl_dtp)
	{
          xml_entity_t *xe = XMLTYPE_TO_ENTITY(repl);
	  if (NULL != xe)
	    {
	      xe = xe->_->xe_copy (xe);
	      if (!xu_list[xu_ctr].xu_value_is_owned_by_caller)
		dk_free_tree (repl);
	      else
	        xu_list[xu_ctr].xu_value_is_owned_by_caller = 0;
	      xu_list[xu_ctr].xu_value_is_constant = 0;
    	      xu_list[xu_ctr].xu_repl_value = repl = ((caddr_t)xe);
	      repl_dtp = DV_TYPE_OF (repl);
	    }
	}
      switch (repl_dtp)
        {
          case DV_DB_NULL:
            break;
          case DV_XML_ENTITY:
            {
	      int plain_src_count = 0;
	      int attr_src_count = 0;
	      caddr_t attr_val;
	      for (xu_ctr2 = xu_ctr; xu_ctr2 < xu_count; xu_ctr2++)
		{
	          if ((xu_ctr2 > xu_ctr) && (xu_list[xu_ctr2].xu_repl_value != orig_repl))
		    break;
		  if (NULL != xu_list[xu_ctr2].xu_src_attr_name)
		    attr_src_count++;
		  else
		    plain_src_count++;
		}
	      attr_val = attr_src_count ? box_cast_to_UTF8 (qst, repl) : NULL;
	      if (!plain_src_count && !xu_list[xu_ctr].xu_value_is_owned_by_caller)
		dk_free_tree (repl);
	      for (xu_ctr2 = xu_ctr; xu_ctr2 < xu_count; xu_ctr2++)
	        {
	          if ((xu_ctr2 > xu_ctr) && (xu_list[xu_ctr2].xu_repl_value != orig_repl))
		    break;
		  if (NULL != xu_list[xu_ctr2].xu_src_attr_name)
		    {
		      xu_list[xu_ctr2].xu_repl_value = attr_val;
		      xu_list[xu_ctr2].xu_value_is_owned_by_caller = ((1 < attr_src_count) ? 1 : 0);
		      xu_list[xu_ctr2].xu_value_is_constant = ((0 < attr_src_count) ? 1 : 0);
		      attr_src_count--;
		    }
		  else
		    {
		      xu_list[xu_ctr2].xu_repl_value = repl;
		      if (1 < plain_src_count)
		        xu_list[xu_ctr2].xu_value_is_constant = 1;
		    }
		}
	      xu_ctr = xu_ctr2 - 1;
	      continue;
	    }
	  default:
	    xu_list[xu_ctr].xu_repl_value = box_cast_to_UTF8 (qst, repl);
	    if (!xu_list[xu_ctr].xu_value_is_owned_by_caller)
	      dk_free_tree (repl);
	    else
	      xu_list[xu_ctr].xu_value_is_owned_by_caller = 0;
	    xu_list[xu_ctr].xu_value_is_constant = 0;
	    break;
	}
      for (xu_ctr2 = xu_ctr + 1; xu_ctr2 < xu_count; xu_ctr2++)
        {
          if (xu_list[xu_ctr2].xu_repl_value != orig_repl)
            break;
          xu_list[xu_ctr2].xu_repl_value = xu_list[xu_ctr].xu_repl_value;
          xu_list[xu_ctr2].xu_value_is_owned_by_caller = 1;
          xu_list[xu_ctr2].xu_value_is_constant = 1;
          xu_list[xu_ctr].xu_value_is_constant = 1;
        }
      xu_ctr = xu_ctr2;
    }
  xu_bsort (xu_list, xu_count);
  xu_count = xu_remove_redundant (xu_list, xu_count, (ptrlong)(src->xe_doc.xtd), &garbage);
  res = xu_replace (xu_list, xu_count, tgt, ((tgt == src) ? tgt->xe_doc.xtd : NULL));
  if ((res != (caddr_t)tgt) && (tgt != src))
    dk_free_box ((box_t) tgt);
  xu_free_items (xu_list, xu_count);
  dk_free_tree (list_to_array (garbage));
#ifdef DEBUG
  if (DV_XML_ENTITY == DV_TYPE_OF (res))
    {
      xml_tree_ent_t *res_ent = (xml_tree_ent_t *)res;
      if (XE_IS_TREE (res_ent))
        {
	  xte_tree_check (res_ent->xe_doc.xtd->xtd_tree);
	  /* xte_tree_check (res_ent->xte_current); */
	}
    }
#endif
  return res;
}


caddr_t
bif_updateXML_ent (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t raw_src = bif_arg (qst, args, 0, "updateXML_ent");
  xml_tree_ent_t * src = bif_tree_ent_arg (qst, args, 0, "updateXML_ent");
  xml_tree_ent_t * tgt;
  dk_set_t item_parts = NULL;
  int arg_pair_ctr;
  int arg_pair_count;
  if (NULL != src->xe_referer)
    sqlr_new_error ("22023", "SR357", "Function updateXML_ent can not update non-standalone XML entity.");
  if (1 != BOX_ELEMENTS (args) % 2)
    sqlr_new_error ("22023", "SR356", "Function updateXML_ent needs odd number of arguments.");
  arg_pair_count = ((BOX_ELEMENTS (args) - 1) / 2);
  for (arg_pair_ctr = arg_pair_count; arg_pair_ctr--; /* no step */)
    if (DV_DB_NULL != DV_TYPE_OF (bif_arg (qst, args, arg_pair_ctr * 2 + 1, "updateXML_ent")))
      {
        xml_tree_ent_t *pos_ent = bif_tree_ent_arg (qst, args, arg_pair_ctr * 2 + 1, "updateXML_ent");
        if (NULL != pos_ent->xe_referer)
	  sqlr_new_error ("22023", "SR358", "Function updateXML_ent can not search for non-standalone XML entity passed as argument %d", arg_pair_ctr * 2 + 1);
      }
  for (arg_pair_ctr = arg_pair_count; arg_pair_ctr--; /* no step */)
    {
      xml_tree_ent_t * pos_ent = (xml_tree_ent_t *) bif_arg (qst, args, arg_pair_ctr * 2 + 1, "updateXML_ent");
      caddr_t repl = bif_arg (qst, args, arg_pair_ctr * 2 + 2, "updateXML_ent");
      dk_set_t path = NULL;
      switch (DV_TYPE_OF (pos_ent))
        {
	case DV_DB_NULL: continue;
	case DV_XML_ENTITY: break;
	default:
	  pos_ent = bif_tree_ent_arg (qst, args, arg_pair_ctr * 2 + 1, "updateXML_ent");
	  break;
	}
      if (0 == pos_ent->_->xe_get_logical_path ((xml_entity_t *)(pos_ent), &path))
	{
	  sqlr_new_error ("22023", "SR474",
	    "Function updateXML_ent can not search for outdated XML entity passed as argument %d",
	    arg_pair_ctr * 2 + 1 );
	}
      dk_set_push (&item_parts, (caddr_t)(XU_OP_REPLACE));
      dk_set_push (&item_parts, (caddr_t)(1));	/* is constant */
      dk_set_push (&item_parts, (caddr_t)(1));	/* is owned by caller */
      dk_set_push (&item_parts, repl);
      dk_set_push (&item_parts, box_copy (pos_ent->xe_attr_name));
      dk_set_push (&item_parts, list_to_array (path));
    }
  tgt = (xml_tree_ent_t *)(src->_->xe_clone((xml_entity_t *)(src), (query_instance_t *)(qst)));
  tgt = (xml_tree_ent_t *) xmlupdate_impl ( qst, src, tgt,
    (xmlupdate_item_t *)(list_to_array (item_parts)) );
  if (DV_XML_ENTITY == DV_TYPE_OF (tgt))
    {
      xe_root ((xml_entity_t *)tgt);
      if ((DV_XML_ENTITY == DV_TYPE_OF (raw_src)) && (NULL != XMLTYPE_TO_ENTITY(raw_src)))
	{
          tgt = (xml_tree_ent_t *)list (4, XMLTYPE_CLASS, tgt, (ptrlong)0, (ptrlong)0);
        }
    }
#ifdef DEBUG
  xte_tree_check (src->xe_doc.xtd->xtd_tree);
#endif
  return (caddr_t)(tgt);
}


caddr_t
bif_updateXML (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t raw_src = bif_arg (qst, args, 0, "updateXML");
  xml_tree_ent_t * src = bif_tree_ent_arg (qst, args, 0, "updateXML");
  xml_tree_ent_t * tgt;
  dk_set_t item_parts = NULL;
  int arg_pair_ctr;
  int arg_pair_count;
  if (NULL != src->xe_referer)
    sqlr_new_error ("22023", "SR357", "Function updateXML can not update non-standalone XML entity.");
  if (1 != BOX_ELEMENTS (args) % 2)
    sqlr_new_error ("22023", "SR356", "Function updateXML needs odd number of arguments.");
  arg_pair_count = ((BOX_ELEMENTS (args) - 1) / 2);
  for (arg_pair_ctr = arg_pair_count; arg_pair_ctr--; /* no step */)
    bif_string_or_null_arg (qst, args, arg_pair_ctr * 2 + 1, "updateXML");
  for (arg_pair_ctr = arg_pair_count; arg_pair_ctr--; /* no step */)
    {
      caddr_t pos_expn_arg = bif_string_arg (qst, args, arg_pair_ctr * 2 + 1, "updateXML");
      caddr_t repl = bif_arg (qst, args, arg_pair_ctr * 2 + 2, "updateXML");
      xml_entity_t *pos_ent = NULL;
      {
        xp_query_t * xqr = NULL;
        query_instance_t * qi = (query_instance_t *) qst;
        caddr_t err = NULL;
        xp_instance_t * xqi;
        xqr = xp_query_parse (qi, pos_expn_arg, 'p', &err, &xqre_default);
	if (err)
	  sqlr_resignal (err);
	xqi = xqr_instance (xqr, qi);
	xqi->xqi_return_attrs_as_nodes = 1;
        xqi->xqi_xpath2_compare_rules = 0;
        QR_RESET_CTX
          {
            int hit;
	    xqi_eval (xqi, xqr->xqr_tree, (xml_entity_t *)src);
	    hit = xqi_is_value (xqi, xqr->xqr_tree);
	    while (hit)
	      {
		pos_ent = (xml_entity_t *) xqi_raw_value (xqi, xqr->xqr_tree);
		if (DV_XML_ENTITY == DV_TYPE_OF (pos_ent))
		  {
		    dk_set_t path = NULL;
		    if (NULL != pos_ent->xe_referer)
		      sqlr_new_error ("22023", "SR358", "Function updateXML can not search for non-standalone XML entity found by %s (argument %d).", pos_expn_arg, arg_pair_ctr * 2 + 1);
		    if (0 == pos_ent->_->xe_get_logical_path ((xml_entity_t *)(pos_ent), &path))
		      sqlr_new_error ("22023", "SR473",
			"Function updateXML can not search for outdated XML entity found by %s (argument %d).", pos_expn_arg, arg_pair_ctr * 2 + 1);
		    dk_set_push (&item_parts, (caddr_t)(XU_OP_REPLACE));
		    dk_set_push (&item_parts, (caddr_t)(1));	/* is constant */
		    dk_set_push (&item_parts, (caddr_t)(1));	/* is owned by caller */
		    dk_set_push (&item_parts, repl);
		    dk_set_push (&item_parts, box_copy (pos_ent->xe_attr_name));
		    dk_set_push (&item_parts, list_to_array (path));
		  }
	        hit = xqi_is_next_value (xqi, xqr->xqr_tree);
	      }
	  }
	QR_RESET_CODE
	  {
	    du_thread_t *self = THREAD_CURRENT_THREAD;
	    caddr_t err = thr_get_error_code (self);
	    xmlupdate_item_t *items = (xmlupdate_item_t *)(list_to_array (item_parts));
	    xu_free_items (items, box_length (items) / sizeof (xmlupdate_item_t));
	    xqi_free (xqi);
	    POP_QR_RESET;
	    dk_free_box ((caddr_t)xqr);
	    if (err)
	      sqlr_resignal (err);
	    return NULL;  /* not supposed to */
	  }
	END_QR_RESET;
	xqi_free (xqi);
	dk_free_box ((caddr_t)xqr);
      }
    }
  tgt = (xml_tree_ent_t *)(src->_->xe_clone((xml_entity_t *)(src), (query_instance_t *)(qst)));
  tgt = (xml_tree_ent_t *)xmlupdate_impl ( qst, src, tgt,
    (xmlupdate_item_t *)(list_to_array (item_parts)) );
  if (DV_XML_ENTITY == DV_TYPE_OF (tgt))
    {
      xe_root ((xml_entity_t *)tgt);
      if ((DV_XML_ENTITY == DV_TYPE_OF (raw_src)) && (NULL != XMLTYPE_TO_ENTITY(raw_src)))
	{
          tgt = (xml_tree_ent_t *)list (4, XMLTYPE_CLASS, tgt, (ptrlong)0, (ptrlong)0);
        }
    }
  return (caddr_t)(tgt);
}


caddr_t bif_XMLReplace (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t raw_src = bif_arg (qst, args, 0, "XMLReplace");
  xml_tree_ent_t * src = bif_tree_ent_arg (qst, args, 0, "XMLReplace");
  xml_tree_ent_t * tgt;
  dk_set_t item_parts = NULL;
  int arg_pair_ctr;
  int arg_pair_count;
  if (NULL != src->xe_referer)
    sqlr_new_error ("22023", "SR378", "Function XMLReplace can not edit non-standalone XML entity.");
  if (0 != src->xe_doc.xtd->xd_dom_lock_count)
    sqlr_new_error ("22023", "SR381", "Function XMLReplace can not modify an locked XML entity.");
  if (1 != BOX_ELEMENTS (args) % 2)
    sqlr_new_error ("22023", "SR379", "Function XMLReplace needs odd number of arguments.");
  arg_pair_count = ((BOX_ELEMENTS (args) - 1) / 2);
  for (arg_pair_ctr = arg_pair_count; arg_pair_ctr--; /* no step */)
    if (DV_DB_NULL != DV_TYPE_OF (bif_arg (qst, args, arg_pair_ctr * 2 + 1, "XMLReplace")))
      {
        xml_tree_ent_t *pos_ent = bif_tree_ent_arg (qst, args, arg_pair_ctr * 2 + 1, "XMLReplace");
        if (NULL != pos_ent->xe_referer)
	  sqlr_new_error ("22023", "SR380", "Function XMLReplace can not search for non-standalone XML entity passed as argument %d", arg_pair_ctr * 2 + 1);
      }
  for (arg_pair_ctr = arg_pair_count; arg_pair_ctr--; /* no step */)
    {
      xml_tree_ent_t * pos_ent = (xml_tree_ent_t *) bif_arg (qst, args, arg_pair_ctr * 2 + 1, "XMLReplace");
      caddr_t repl = bif_arg (qst, args, arg_pair_ctr * 2 + 2, "XMLReplace");
      dk_set_t path = NULL;
      switch (DV_TYPE_OF (pos_ent))
        {
	case DV_DB_NULL: continue;
	case DV_XML_ENTITY: break;
	default:
	  pos_ent = bif_tree_ent_arg (qst, args, arg_pair_ctr * 2 + 1, "XMLReplace");
	  break;
	}
      if (0 == pos_ent->_->xe_get_logical_path ((xml_entity_t *)(pos_ent), &path))
	{
	  sqlr_new_error ("22023", "SR472",
	    "Argument %d of function XMLReplace is an outdated XML entity that can not point to the node that should be replaced",
	    arg_pair_ctr * 2 + 1 );
	}
      dk_set_push (&item_parts, (caddr_t)(XU_OP_REPLACE));
      if ((DV_XML_ENTITY == DV_TYPE_OF (repl)) && (((xml_entity_t *)repl)->xe_doc.xd == src->xe_doc.xd))
        { /* If danger of self-assignment then use a copy of replacing value */
	  dk_set_push (&item_parts, (caddr_t)(0));	/* is not a constant */
	  dk_set_push (&item_parts, (caddr_t)(0));	/* is owned by a routine, not by caller */
	  dk_set_push (&item_parts, ((xml_entity_t *)repl)->_->xe_cut(((xml_entity_t *)repl), (query_instance_t *)qst));
	}
      else
        { /* Otherwise use an original of replacing value */
	  dk_set_push (&item_parts, (caddr_t)(1));	/* is constant */
	  dk_set_push (&item_parts, (caddr_t)(1));	/* is owned by caller */
	  dk_set_push (&item_parts, repl);
	}
      dk_set_push (&item_parts, box_copy (pos_ent->xe_attr_name));
      dk_set_push (&item_parts, list_to_array (path));
    }
  XTD_DOM_MUTATE (src->xe_doc.xtd);
  if (NULL != XMLTYPE_TO_ENTITY(raw_src))
    {
      dk_free_box (UDT_I_VAL(raw_src, XMLTYPE_I_VALIDATED));
      UDT_I_VAL(raw_src, XMLTYPE_I_VALIDATED) = 0;
    }
  tgt = (xml_tree_ent_t *)xmlupdate_impl ( qst, src, src,
    (xmlupdate_item_t *)(list_to_array (item_parts)) );
  xe_root ((xml_entity_t *)src);
  if (tgt == src)
    return NEW_DB_NULL;
  if (DV_XML_ENTITY == DV_TYPE_OF (tgt))
    {
      xe_root ((xml_entity_t *)tgt);
      if ((DV_XML_ENTITY == DV_TYPE_OF (raw_src)) && (NULL != XMLTYPE_TO_ENTITY(raw_src)))
	{
          tgt = (xml_tree_ent_t *)list (4, XMLTYPE_CLASS, tgt, (ptrlong)0, (ptrlong)0);
        }
    }
  return (caddr_t)(tgt);
}


#define XU_BIF_INSERT_BEFORE 1
#define XU_BIF_INSERT_AFTER 2
#define XU_BIF_APPEND_CHILDREN 3

caddr_t xu_insert_impl (caddr_t * qst, state_slot_t ** args, const char *funname, int bif_code)
{
  caddr_t raw_src = bif_arg (qst, args, 0, funname);
  xml_tree_ent_t * src = bif_tree_ent_arg (qst, args, 0, funname);
  dk_set_t local_items = NULL;
  dk_set_t items = NULL;
  caddr_t err;
  int arg_ctr;
  int arg_count = BOX_ELEMENTS(args) - 1;
  int saved_pos = 0;
  int ins_before_pos = 0;
  if (NULL != src->xe_referer)
    sqlr_new_error ("22023", "SR381", "Function %s can not edit non-standalone XML entity.", funname);
  if (0 != src->xe_doc.xtd->xd_dom_lock_count)
    sqlr_new_error ("22023", "SR382", "Function %s can not modify an locked XML entity.", funname);
  if (NULL != src->xe_attr_name)
    sqlr_new_error ("22023", "SR386", "Function %s can not modify an attribute entity.", funname);
  for (arg_ctr = 0; arg_ctr < arg_count; arg_ctr++)
    {
      caddr_t repl = bif_arg (qst, args, arg_ctr + 1, funname);
      dtp_t repl_dtp = DV_TYPE_OF (repl);
      if (DV_OBJECT == repl_dtp)
	repl = (caddr_t)(XMLTYPE_TO_ENTITY(repl));
      switch (DV_TYPE_OF (repl))
        {
	case DV_DB_NULL:
	  continue;
	case DV_XML_ENTITY:
          dk_set_push (&items, repl);
	  break;
	default:
	  {
	    caddr_t local_repl = box_cast_to_UTF8 (qst, repl);
	    dk_set_push (&items, local_repl);
	    dk_set_push (&local_items, local_repl);
	  }
	}
    }
  if (NULL == items)
    return NEW_DB_NULL; /* Nothing to change */
  switch (bif_code)
    {
    case XU_BIF_INSERT_BEFORE:
      if (!XTE_HAS_PARENT (src))
        {
	  err = srv_make_new_error ("22023", "SR383", "Function %s can not modify a root entity.", funname);
	  goto err_exit; /* see below */
	}
      saved_pos = BOX_ELEMENTS (XTE_PARENT_SUBTREE(src)) - src->xte_child_no; /* We're counting from right */
      ins_before_pos = src->xte_child_no;
      src->_->xe_up ((xml_entity_t *)src, (XT *) XP_NODE, 0);
      break;
    case XU_BIF_INSERT_AFTER:
      if (!XTE_HAS_PARENT (src))
        {
	  err = srv_make_new_error ("22023", "SR384", "Function %s can not modify a root entity.", funname);
	  goto err_exit; /* see below */
	}
      saved_pos = src->xte_child_no; /* We're counting from left */
      ins_before_pos = src->xte_child_no + 1;
      src->_->xe_up ((xml_entity_t *)src, (XT *) XP_NODE, 0);
      break;
    case XU_BIF_APPEND_CHILDREN:
      {
        const char *parentname = (
          (DV_ARRAY_OF_POINTER != DV_TYPE_OF (src->xte_current)) ? " text" :
          XTE_HEAD_NAME(XTE_HEAD (src->xte_current)) );
        if ((' ' == parentname[0]) && (uname__root != parentname))
	  {
	    err = srv_make_new_error ("22023", "SR385", "Function %s can modify only element entities, not one of type '%s'", funname, parentname + 1);
	    goto err_exit; /* see below */
	  }
	ins_before_pos = BOX_ELEMENTS (src->xte_current);
        break;
      }
    default: GPF_T;
    }
/* At this point the tree is about to be modified */
  {
    dk_set_t repl_list = NULL;
    caddr_t repl;
    caddr_t *old_children = (caddr_t *) box_copy ((box_t) src->xte_current);
    int old_children_len = BOX_ELEMENTS (old_children);
    while (NULL != items)
      {
        caddr_t repl_current = NULL;
	caddr_t left_text;
	caddr_t *subtrees = NULL;
	ptrlong subtrees_count = 0;
	repl = (caddr_t) dk_set_pop (&items);
        xu_list_subtrees_of_repl (repl, &repl_current, &subtrees, &subtrees_count);
	if (0 == subtrees_count)
	  continue;
	left_text = subtrees[subtrees_count - 1];
	if (DV_STRING == DV_TYPE_OF (left_text))
	  {
	    if (NULL == repl_list)
	      {	/* Trying to concatenate the last text in insertion and the first text after insertion point */
		if (ins_before_pos < old_children_len)
		  {
		    caddr_t right_text = old_children [ins_before_pos];
		    if (DV_STRING == DV_TYPE_OF (right_text))
		      {
			dk_set_push (&(src->xe_doc.xtd->xtd_garbage_boxes), right_text);
			old_children [ins_before_pos] = box_dv_short_concat (left_text, right_text);
			subtrees_count--;
		      }
		  }
	      }
	    else
	      { /* Trying to concatenate the last text in new item with the leftmost text in repl_list */
		caddr_t right_text = (caddr_t) repl_list->data;
		if (DV_STRING == DV_TYPE_OF (right_text))
		  {
		    caddr_t text_conc = box_dv_short_concat (left_text, right_text);
		    dk_set_pop (&repl_list);
		    dk_set_push (&repl_list, text_conc);
		    dk_free_box (right_text);
		    subtrees_count--;
		  }
	      }
	  }
	while (subtrees_count > 0)
	  dk_set_push (&repl_list, box_copy_tree (subtrees[--subtrees_count]));
      }
    if ((NULL != repl_list) && (ins_before_pos > 1))
      { /* Trying to concatenate the last text before insertion point and the first text in insertion */
        caddr_t left_text = old_children [ins_before_pos - 1];
        caddr_t right_text = (caddr_t) repl_list->data;
	if ((DV_STRING == DV_TYPE_OF (left_text)) && (DV_STRING == DV_TYPE_OF (right_text)))
	  {
	    dk_set_push (&(src->xe_doc.xtd->xtd_garbage_boxes), left_text);
	    old_children [ins_before_pos - 1] = box_dv_short_concat (left_text, right_text);
	    dk_free_box ((caddr_t) dk_set_pop (&repl_list));
	  }
      }
    if (NULL != repl_list)
      {
	int ins_len = dk_set_length (repl_list);
	int ins_idx = 0;
	caddr_t *new_children = (caddr_t *) dk_alloc_box ((ins_len + old_children_len) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	memcpy (new_children, old_children, ins_before_pos * sizeof (caddr_t));
	while (NULL != repl_list)
	  new_children [ins_before_pos + ins_idx++] = (caddr_t) /*box_copy_tree (*/dk_set_pop (&repl_list)/*)*/;
	memcpy (new_children + ins_before_pos + ins_len, old_children + ins_before_pos, (old_children_len - ins_before_pos) * sizeof (caddr_t));
	dk_free_box ((box_t) old_children);
	old_children = new_children;
      }
    XTD_DOM_MUTATE (src->xe_doc.xtd);
    dk_set_push (&(src->xe_doc.xtd->xtd_garbage_boxes), (void *)(src->xte_current));
    src->xte_current = old_children;
    if (XTE_HAS_PARENT(src))
      XTE_PARENT_SUBTREE(src)[src->xte_child_no] = (caddr_t) old_children;
    else
      src->xe_doc.xtd->xtd_tree = old_children;
    xte_tree_check (src->xe_doc.xtd->xtd_tree);
  }
/* At this point the tree is stable again */
  switch (bif_code)
    {
    case XU_BIF_INSERT_BEFORE:
      saved_pos = BOX_ELEMENTS (src->xte_current) - saved_pos; /* We're counting from right */
      /* no break */
    case XU_BIF_INSERT_AFTER:
      src->_->xe_first_child ((xml_entity_t *)src, (XT *) XP_NODE);
      src->xte_current = (caddr_t *)(XTE_PARENT_SUBTREE(src)[saved_pos]);
      xte_tree_check (src->xte_current);
      src->xte_child_no = saved_pos;
      break;
    case XU_BIF_APPEND_CHILDREN:
      break;
    default: GPF_T;
    }
  if (NULL != XMLTYPE_TO_ENTITY(raw_src))
    {
      dk_free_box (UDT_I_VAL(raw_src, XMLTYPE_I_VALIDATED));
      UDT_I_VAL(raw_src, XMLTYPE_I_VALIDATED) = 0;
    }
  while (NULL != local_items) dk_free_tree ((caddr_t) dk_set_pop (&local_items));
  xte_tree_check (src->xe_doc.xtd->xtd_tree);
  xte_tree_check (src->xte_current);
  return NEW_DB_NULL;

err_exit:
  dk_set_free (items);
  while (NULL != local_items) dk_free_tree ((caddr_t) dk_set_pop (&local_items));
  sqlr_resignal (err);
  return NULL; /* Never reached */
}


caddr_t bif_XMLInsertBefore (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return xu_insert_impl (qst, args, "XMLInsertBefore", XU_BIF_INSERT_BEFORE);
}


caddr_t bif_XMLInsertAfter (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return xu_insert_impl (qst, args, "XMLInsertAfter", XU_BIF_INSERT_AFTER);
}


caddr_t bif_XMLAppendChildren (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return xu_insert_impl (qst, args, "XMLAppendChildren", XU_BIF_APPEND_CHILDREN);
}


#define XU_ADD_ATTR_INTO 0
#define XU_ADD_ATTR_SOFT 1
#define XU_ADD_ATTR_REPLACING 2

caddr_t bif_XMLAddAttribute (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t raw_src = bif_arg (qst, args, 0, "XMLAddAttribute");
  xml_tree_ent_t * src = bif_tree_ent_arg (qst, args, 0, "XMLAddAttribute");
  int mode = (int) bif_long_arg (qst, args, 1, "XMLAddAttribute");
  caddr_t raw_attr_name = bif_arg (qst, args, 2, "XMLAddAttribute");
  xml_entity_t *attr_xe;
  char *attr_xe_elemname;
  caddr_t attr_name = NULL, attr_value = NULL;
  caddr_t *old_head, *new_head;
  int attr_idx, head_len, old_attr_idx = 0, ins_before, res;
  if (NULL != src->xe_referer)
    sqlr_new_error ("22023", "SR387", "Function XMLAddAttribute can not edit non-standalone XML entity.");
  if (0 != src->xe_doc.xtd->xd_dom_lock_count)
    sqlr_new_error ("22023", "SR388", "Function XMLAddAttribute can not modify an locked XML entity.");
  if (NULL != src->xe_attr_name)
    sqlr_new_error ("22023", "SR389", "Function XMLAddAttribute can not modify an attribute entity.");
  if (!XTE_HAS_PARENT (src))
    sqlr_new_error ("22023", "SR392", "Function XMLAddAttribute can not modify a root entity.");
  attr_xe_elemname = (char *) (
    (DV_ARRAY_OF_POINTER != DV_TYPE_OF (src->xte_current)) ? " text" :
          XTE_HEAD_NAME(XTE_HEAD (src->xte_current)) );
  if (' ' == attr_xe_elemname[0])
    sqlr_new_error ("22023", "SR393", "Function XMLAddAttribute can modify only element entities, not entity of type '%s'", attr_xe_elemname + 1);

  switch (DV_TYPE_OF (raw_attr_name))
    {
    case DV_DB_NULL: return box_num (0);
    case DV_OBJECT:
      attr_xe = XMLTYPE_TO_ENTITY (raw_attr_name);
      if (NULL == attr_xe)
	  sqlr_new_error ("22023", "SR390", "Function XMLAddAttribute can not accept object of type '%s' as argument 3", UDT_I_CLASS(raw_attr_name)->scl_name);
      raw_attr_name = (caddr_t)attr_xe;
      /* no break */
    case DV_XML_ENTITY:
      if (BOX_ELEMENTS (args) > 3)
	sqlr_new_error ("22023", "SR394", "The function XMLAddAttribute() does not need argument 4 if argument 3 is an entity");
      attr_xe = ((xml_entity_t *)raw_attr_name);
      if (NULL == attr_xe->xe_attr_name)
	sqlr_new_error ("22023", "SR395", "The XML entity passed as argument 3 to function XMLAddAttribute() is not an attribute entity");
      attr_name = box_copy (attr_xe->xe_attr_name);
      attr_value = attr_xe->_->xe_currattrvalue (attr_xe);
      break;
    default:
      attr_name = box_dv_uname_string (box_cast_to_UTF8 (qst, raw_attr_name));
	  attr_value = bif_arg (qst, args, 3, "XMLAddAttribute");
	  if (DV_DB_NULL == DV_TYPE_OF (attr_value))
	    return box_num (0);
	  attr_value = box_cast_to_UTF8 (qst, attr_value);
      break;
    }
  if (('\0' == attr_name[0]) || (' ' == attr_name[0]) || !strncmp (attr_name, "xmlns", 5))
    {
      dk_free_box (attr_name);
      dk_free_box (attr_value);
      sqlr_new_error ("22023", "SR396", "Invalid attribute name passed to function XMLAddAttribute()");
    }
  old_head = XTE_HEAD (src->xte_current);
  head_len = BOX_ELEMENTS (old_head);
  for (attr_idx = 1; attr_idx < head_len; attr_idx += 2)
    {
      if (old_head [attr_idx] != attr_name)
        continue;
      old_attr_idx = attr_idx;
      break;
    }
  if (old_attr_idx)
    {
      dk_free_box (attr_name);
      switch (mode)
        {
	case XU_ADD_ATTR_INTO:
	  dk_free_box (attr_value);
	  sqlr_new_error ("22023", "SR397", "Attribute '%s' already exists in entity passed to function XMLAddAttribute()", old_head [old_attr_idx]);
	case XU_ADD_ATTR_SOFT:
	  dk_free_box (attr_value);
	  return box_num (0);
	case XU_ADD_ATTR_REPLACING:
	  dk_set_push (&(src->xe_doc.xtd->xtd_garbage_trees), (void *)(old_head[old_attr_idx+1]));
	  old_head[old_attr_idx+1] = attr_value;
	  res = 2;
	  goto completed; /* see below */
        }
    }
  ins_before = head_len;
  /* This loop skips trailing special attributes */
  while ((ins_before > 2) && ('\0' == old_head [ins_before - 2][0])) ins_before -= 2;
/* Note that unlike xte_replace there is no need to put the whole element to xtd_garbage_boxes
because the indexing of existing data attributes remains unchanged */
  new_head = (caddr_t *) dk_alloc_box ((head_len + 2) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  memcpy (new_head, old_head, ins_before * sizeof (caddr_t));
  new_head [ins_before] = attr_name;
  new_head [ins_before + 1] = attr_value;
  memcpy (new_head + ins_before + 2, old_head + ins_before, (head_len - ins_before) * sizeof (caddr_t));
  dk_set_push (&(src->xe_doc.xtd->xtd_garbage_boxes), (void *)(old_head));
  XTE_HEAD (src->xte_current) = new_head;
  res = 1;

completed:
  XTD_DOM_MUTATE (src->xe_doc.xtd);
  if (NULL != XMLTYPE_TO_ENTITY(raw_src))
    {
      dk_free_box (UDT_I_VAL(raw_src, XMLTYPE_I_VALIDATED));
      UDT_I_VAL(raw_src, XMLTYPE_I_VALIDATED) = 0;
    }
  return box_num (res);
}


caddr_t bif_xml_serialize_packed (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_tree_ent_t * src = bif_tree_ent_arg (qst, args, 0, "__xml_serialize_packed");
  caddr_t res;
  dk_session_t * ses = strses_allocate();
  xte_serialize_packed (src->xte_current, src->xe_doc.xd->xd_dtd, ses);
  if (!STRSES_CAN_BE_STRING (ses))
    {
      *err_ret = STRSES_LENGTH_ERROR ("__xml_serialize_packed");
      res = NULL;
    }
  else
    res = strses_string (ses);
  strses_free (ses);
  return res;
}


caddr_t
xml_deserialize_packed (caddr_t * qst, caddr_t strg)
{
  caddr_t * res = NULL;
  dtp_t strg_dtp = DV_TYPE_OF (strg);
  if (DV_STRING == strg_dtp)
    {
      scheduler_io_data_t iod;
      dk_session_t ses;
      memset (&ses, 0, sizeof (ses));
      memset (&iod, 0, sizeof (iod));
      ses.dks_in_buffer = strg;
      ses.dks_in_fill = box_length (strg) - 1;
      SESSION_SCH_DATA ((&ses)) = &iod;
      DKS_QI_DATA (&ses) = (query_instance_t *)qst;
      xte_deserialize_packed (&ses, &res, NULL);
    }
  else
    {
      blob_handle_t *bh;
      dk_session_t *tmp_ses;
      if (!IS_BLOB_HANDLE_DTP(strg_dtp))
        sqlr_new_error ("22023", "SR560",
	  "__xml_deserialize_packed() requires a blob or string argument");
      bh = (blob_handle_t *) strg;
      if (bh->bh_ask_from_client)
        sqlr_new_error ("22023", "SR561",
	  "Blob argument to __xml_deserialize_packed() must be a non-interactive blob");
      tmp_ses = blob_to_string_output (((query_instance_t *)qst)->qi_trx, (caddr_t)bh);
      DKS_QI_DATA (tmp_ses) = (query_instance_t *)qst;
      xte_deserialize_packed (tmp_ses, &res, NULL);
      dk_free_box (tmp_ses);
    }
  if (NULL == res)
    return NEW_DB_NULL;
  return (caddr_t)res;
}


caddr_t
bif_xml_deserialize_packed (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t strg = bif_arg (qst, args, 0, "__xml_deserialize_packed");
  return xml_deserialize_packed (qst, strg);
}


caddr_t bif_xml_get_logical_path (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t * src = bif_entity_arg (qst, args, 0, "xml_get_logical_path");
  dk_set_t path = NULL;
  caddr_t res;
  src->_->xe_get_logical_path (src, &path);
  dk_set_pop (&path);
  res = list_to_array (path);
  box_tag_modify (res, DV_ARRAY_OF_LONG);
  return res;
}

caddr_t bif_xml_follow_logical_path (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t * src = bif_entity_arg (qst, args, 0, "xml_get_logical_path");
  xml_entity_t * tgt;
  caddr_t path = bif_arg (qst, args, 1, "xml_get_logical_path");
  dtp_t path_dtp = DV_TYPE_OF (path);
  if (DV_ARRAY_OF_LONG != path_dtp)
    sqlr_new_error ("22023", "SR288",
      "Function xml_follow_logical_path() needs an bookmark made by xml_get_logical_path() as argument 2, not an arg of type %s (%d)",
      dv_type_title (path_dtp), path_dtp );
  tgt = src->_->xe_copy (src);
  tgt->_->xe_follow_path (tgt, (ptrlong *)path, BOX_ELEMENTS (path));
  return (caddr_t)tgt;
}

#if 0
static void
xtree_tridgell32_iter (caddr_t *tree, unsigned *lo_ptr, unsigned *hi_ptr)
{
  unsigned lo = lo_ptr[0], hi = hi_ptr[0], loxor, hixor, lon, hin;
  unsigned char *data;
  size_t len;
  unsigned char *tail;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree))
    {
      int attrctr, head_len, cctr, ccount = BOX_ELEMENTS_INT (tree);
      caddr_t * head = XTE_HEAD (tree);
      data = (unsigned char *)(XTE_HEAD_NAME (head));
      head_len = BOX_ELEMENTS_INT (head);
      len = box_length_inline (data) - 1;
      for (tail = data + len - 1; tail >= data; tail--)
        { lo += tail[0]; hi += lo; }
      loxor = hixor = 0;
      for (attrctr = 2; attrctr < head_len; attrctr += 2)
        {
          lon = hin = 0;
          data = (unsigned char *)(head[attrctr-1]);
          len = box_length_inline (data) - 1;
          for (tail = data + len - 1; tail >= data; tail--)
            { lon += tail[0]; hin += lon; }
          data = (unsigned char *)(head[attrctr]);
          len = box_length_inline (data) - 1;
          for (tail = data + len - 1; tail >= data; tail--)
            { lon += tail[0]; hin += lon; }
          loxor ^= lon;
          hixor ^= hin;
        }
      lo += loxor; hi += lo;
      for (cctr = 1; cctr < ccount; cctr++)
        xtree_tridgell32_iter ((caddr_t *)(tree[cctr]), &lo, &hi);
    }
  else
    {
      data = (unsigned char *)(tree);
      len = box_length_inline (data) - 1;
      for (tail = data + len - 1; tail >= data; tail--)
        { lo += tail[0]; hi += lo; }
    }
  lo_ptr[0] = lo;
  hi_ptr[0] = hi;
}


caddr_t bif_xtree_tridgell32 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_tree_ent_t * src = bif_tree_ent_arg (qst, args, 0, "xtree_tridgell32");
  long make_num = ((1 < BOX_ELEMENTS (args)) ? bif_long_arg (qst, args, 1, "xtree_tridgell32") : 0);
  unsigned lo = 0, hi = 0, res;
  caddr_t *curr = src->xte_current;
  xtree_tridgell32_iter (curr, &lo, &hi);
  res = (hi << 16) | (lo & 0xFFFF);
  if (!make_num)
    {
      unsigned char *buf = (unsigned char *)dk_alloc_box (7, DV_STRING);
      buf[6] = '\0';
      buf[5] = 64 + (res & 0x3F);
      buf[4] = 64 + ((res >> 2) & 0x3F);
      buf[3] = 64 + ((res >> 8) & 0x3F);
      buf[2] = 64 + ((res >> 14) & 0x3F);
      buf[1] = 64 + ((res >> 20) & 0x3F);
      buf[0] = 64 + ((res >> 26) & 0x3F);
      return (void *)buf;
    }
  return box_num (res);
}
#endif

#define SUM64(data,lo,med,hi) \
      end = (data) + box_length_inline ((data)) - 1; \
      for (tail = (data); tail < end; tail++) \
        { lo += tail[0]; med += lo; hi += med; }

static void
xte_sum64_iter (caddr_t *tree, unsigned *lo_ptr, unsigned *med_ptr, unsigned *hi_ptr)
{
  unsigned lo = lo_ptr[0], med = med_ptr[0], hi = hi_ptr[0], loxor, medxor, hixor, lon, medn, hin;
  unsigned char *data;
  unsigned char *tail, *end;
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree))
    {
      int attrctr, head_len, cctr, ccount = BOX_ELEMENTS_INT (tree);
      caddr_t * head = XTE_HEAD (tree);
      data = (unsigned char *)(XTE_HEAD_NAME (head));
      head_len = BOX_ELEMENTS_INT (head);
      SUM64(data,lo,med,hi)
      loxor = medxor = hixor = 0;
      for (attrctr = 2; attrctr < head_len; attrctr += 2)
        {
          lon = medn = hin = 0;
          data = (unsigned char *)(head[attrctr-1]);
          SUM64(data,lon,medn,hin)
          data = (unsigned char *)(head[attrctr]);
          if (DV_ARRAY_OF_POINTER == DV_TYPE_OF(data))
            {
              int item_ctr;
              caddr_t *items = (caddr_t *)data;
              DO_BOX_FAST (caddr_t, item, item_ctr, items)
                {
                  SUM64((unsigned char *)(item),lon,medn,hin)
                }
              END_DO_BOX_FAST;
            }
          else
            {
              SUM64(data,lon,medn,hin)
            }
          loxor ^= lon; medxor ^= medn; hixor ^= hin;
        }
      lo += loxor; med += lo; hi += med;
      for (cctr = 1; cctr < ccount; cctr++)
        xte_sum64_iter ((caddr_t *)(tree[cctr]), &lo, &med, &hi);
    }
  else
    {
      data = (unsigned char *)(tree);
      SUM64(data,lo,med,hi)
    }
  lo_ptr[0] = lo; med_ptr[0] = med; hi_ptr[0] = hi;
}

#undef SUM64

caddr_t xte_sum64 (caddr_t *curr)
{
  unsigned lo = 0, med = 0, hi = 0, aux;
  unsigned char *buf;
  xte_sum64_iter (curr, &lo, &med, &hi);
  buf = (unsigned char *)dk_alloc_box (13, DV_STRING);
  buf[12] = '\0';
  aux = (med << 16) | (lo & 0xFFFF);
  buf[11] = 64 + (aux & 0x3F);
  buf[10] = 64 + ((aux >> 2) & 0x3F);
  buf[9] = 64 + ((aux >> 8) & 0x3F);
  buf[8] = 64 + ((aux >> 14) & 0x3F);
  buf[7] = 64 + ((aux >> 20) & 0x3F);
  buf[6] = 64 + ((aux >> 26) & 0x3F);
  aux = (hi << 6) | ((med >> 16) & 0x3F);
  buf[5] = 64 + (aux & 0x3F);
  buf[4] = 64 + ((aux >> 2) & 0x3F);
  buf[3] = 64 + ((aux >> 8) & 0x3F);
  buf[2] = 64 + ((aux >> 14) & 0x3F);
  buf[1] = 64 + ((aux >> 20) & 0x3F);
  buf[0] = 64 + ((aux >> 26) & 0x3F);
  return (void *)buf;
}

caddr_t bif_xtree_sum64 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_tree_ent_t * src = bif_tree_ent_arg (qst, args, 0, "xtree_sum64");
  return xte_sum64 (src->xte_current);
}

/*! \returns NULL for string, (caddr_t)((ptrlong)1) for unsupported, 2 for NULL, UNAME for others */
caddr_t
xsd_type_of_box (caddr_t arg)
{
  dtp_t dtp = DV_TYPE_OF (arg);
again:
  switch (dtp)
    {
    case DV_DATETIME:
      switch (DT_DT_TYPE(arg))
        {
        case DT_TYPE_DATE: return uname_xmlschema_ns_uri_hash_date;
        case DT_TYPE_TIME: return uname_xmlschema_ns_uri_hash_time;
        default : return uname_xmlschema_ns_uri_hash_dateTime;
        }
    case DV_STRING: case DV_BLOB_HANDLE: case DV_WIDE: case DV_LONG_WIDE:
      return NULL;
    case DV_LONG_INT: return uname_xmlschema_ns_uri_hash_integer;
    case DV_NUMERIC: return uname_xmlschema_ns_uri_hash_decimal;
    case DV_DOUBLE_FLOAT: return uname_xmlschema_ns_uri_hash_double;
    case DV_SINGLE_FLOAT: return uname_xmlschema_ns_uri_hash_float;
    case DV_DB_NULL:
      return (caddr_t)((ptrlong)2);
    case DV_RDF:
      {
        rdf_box_t *rb = (rdf_box_t *)arg;
        if (RDF_BOX_DEFAULT_TYPE != rb->rb_type)
          {
            caddr_t res = rdf_type_twobyte_to_iri (rb->rb_type);
            if (NULL == res)
              return (caddr_t)((ptrlong)2);
            box_flags (res) |= BF_IRI;
            return res;
          }
        dtp = ((rb->rb_is_outlined) ? ((rdf_bigbox_t *)rb)->rbb_box_dtp : DV_TYPE_OF (rb->rb_box));
        goto again; /* see above */
      }
    case DV_XML_ENTITY:
      return uname_rdf_ns_uri_XMLLiteral;
    case DV_GEO:
      return uname_virtrdf_ns_uri_Geometry;
    default:
      return (caddr_t)((ptrlong)1);
    }
}


caddr_t
bif_xsd_type (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_arg (qst, args, 0, "__xsd_type");
  caddr_t res = xsd_type_of_box (arg);
  if (IS_BOX_POINTER (res))
    return res;
  switch ((ptrlong)(res))
    {
    case 0: /* string */
      if (1 < BOX_ELEMENTS (args))
        {
          caddr_t dflt = bif_arg (qst, args, 1, "__xsd_type");
          if (0 == unbox (dflt))
            return NEW_DB_NULL;
          return box_copy_tree (dflt);
        }
      return uname_xmlschema_ns_uri_hash_string;
    case 2: /* NULL */
      return NEW_DB_NULL;
    case 1:
      if (2 >= BOX_ELEMENTS (args))
        {
          dtp_t dtp = DV_TYPE_OF (arg);
          sqlr_new_error ("22023", "SR544",
            "Function __xsd_type() can not find XML Schema datatype that matches SQL datatype %s (%d)",
            dv_type_title (dtp), (int)dtp );
        }
      return box_copy_tree (bif_arg (qst, args, 2, "__xsd_type"));
    }
  GPF_T1 ("__xsd_type: bad ret");
  return NULL;
}

int
xte_subtrees_are_equal (caddr_t *node1, caddr_t *node2)
{
  dtp_t dtp = DV_TYPE_OF (node1);
  int len, ctr;
  if (DV_TYPE_OF (node2) != dtp)
    return 0;
  switch (dtp)
    {
    case DV_LONG_INT: return (unbox ((caddr_t)(node1)) == unbox ((caddr_t)(node2)));
    case DV_SHORT_STRING: len = box_length (node1); return ((len == box_length (node2)) && !memcmp (node1, node2, len));
    case DV_UNAME: return node1 == node2;
    case DV_ARRAY_OF_POINTER:
      {
         len = BOX_ELEMENTS (node1);
         if (len != BOX_ELEMENTS (node2))
           return 0;
         for (ctr = len; ctr--; /* no step */)
           {
             if (!xte_subtrees_are_equal ((caddr_t *)(node1[ctr]), (caddr_t *)(node2[ctr])))
               return 0;
           }
         return 1;
      }
    }
  return 0;
}

int
xe_compare_content (xml_entity_t *xe1, xml_entity_t *xe2, int compare_uris_and_dtds)
{
  xml_tree_ent_t *xte1, *xte2;
  caddr_t val1, val2;
  if (!XE_IS_TREE (xe1) || !XE_IS_TREE (xe2))
    return DVC_NOORDER;
  xte1 = (xml_tree_ent_t *)xe1;
  xte2 = (xml_tree_ent_t *)xe2;
  if (xte1->xte_current == xte2->xte_current)
    return DVC_MATCH;
  val1 = xte1->xe_attr_name;
  val2 = xte1->xe_attr_name;
  if ((val1 || val2) && !strcmp (val1 ? val1 : "", val2 ? val2 : ""))
    return DVC_NOORDER;
  if (compare_uris_and_dtds && (xte1->xe_doc.xtd != xte2->xe_doc.xtd))
    {
      const char *uri1 = xte1->xe_doc.xd->xd_uri;
      const char *uri2 = xte2->xe_doc.xd->xd_uri;
      if (!strcmp (uri1 ? uri1 : "", uri2 ? uri2 : ""))
        return DVC_NOORDER;
      if (((NULL != xte1->xe_doc.xd->xd_dtd) && (0 != xte1->xe_doc.xd->xd_dtd->ed_is_filled)) ||
        ((NULL != xte2->xe_doc.xd->xd_dtd) && (0 != xte2->xe_doc.xd->xd_dtd->ed_is_filled)) )
        return DVC_NOORDER; /* we don't try to compare filled DTDs or a filled and non-filled */
    }
  return (xte_subtrees_are_equal ((caddr_t *)(xte1->xte_current), (caddr_t *)(xte2->xte_current)) ? DVC_MATCH : DVC_NOORDER);
}

int32
xml_ent_hash (caddr_t box)
{
  xml_entity_t *xe = (xml_entity_t *)box;
  int32 chld_hash = 0;
  if (XE_IS_TREE (xe))
    chld_hash = (int32)((ptrlong)(((xml_tree_ent_t *)(xe))->xte_stack_top->xteb_current));
  else if (XE_IS_PERSISTENT (xe))
    chld_hash = (int32)(((xper_entity_t *)(xe))->xper_pos);
/* No need in "if (XE_IS_LAZY (xe))", because there's no position in not-yet-loaded doc */
  return 17 * (ptrlong)(xe->_) +
    13 * (ptrlong)(xe->xe_doc.xd) +
    11 * (ptrlong)(xe->xe_nth_attr) +
    9 * (ptrlong)(xe->xe_referer) +
    chld_hash;
}

int
xml_ent_hash_cmp (ccaddr_t a1, ccaddr_t a2)
{
  xml_entity_t *xe1 = (xml_entity_t *)a1;
  xml_entity_t *xe2 = (xml_entity_t *)a2;
  if (xe1->_ != xe2->_) return 0;
  if (XE_IS_TREE (xe1))
    {
      if (((xml_tree_ent_t *)(xe1))->xte_stack_top->xteb_current != ((xml_tree_ent_t *)(xe2))->xte_stack_top->xteb_current)
        return 0;
    }
  else if (XE_IS_PERSISTENT (xe1))
    {
      if (((xper_entity_t *)(xe1))->xper_pos != ((xper_entity_t *)(xe2))->xper_pos)
        return 0;
    }
  if (xe1->xe_doc.xd != xe2->xe_doc.xd)
    return 0;
  if (xe1->xe_nth_attr != xe2->xe_nth_attr)
    return 0;
  if (xe1->xe_referer != xe2->xe_referer)
    return 0;
  return 1;
}

xml_ns_2dict_t *xml_global_ns_2dict = NULL;
dk_mutex_t *xml_global_ns_2dict_mutex = NULL;

xml_ns_2dict_t *
xml_global_ns_2dict_get (caddr_t *qst, const char *fname)
{
  if ((NULL != fname) && !sec_bif_caller_is_dba ((query_instance_t *)qst))
    sqlr_new_error ("42000", "SR585", "Function %.300s() is restricted to dba group when it tries to access to the global namespace dictionary.", fname);
  if (NULL == xml_global_ns_2dict)
    {
      xml_global_ns_2dict_mutex = mutex_allocate ();
      mutex_enter (xml_global_ns_2dict_mutex);
      xml_global_ns_2dict = dk_alloc (sizeof (xml_ns_2dict_t));
      memset (xml_global_ns_2dict, 0, sizeof (xml_ns_2dict_t));
    }
  else
    mutex_enter (xml_global_ns_2dict_mutex);
  return xml_global_ns_2dict;
}

void
xml_global_ns_2dict_release (xml_ns_2dict_t *ns_2dict)
{
  mutex_leave (xml_global_ns_2dict_mutex);
}

xml_ns_2dict_t *
xml_cli_ns_2dict (client_connection_t *cli)
{
  if (NULL == cli->cli_ns_2dict)
    {
      cli->cli_ns_2dict = dk_alloc (sizeof (xml_ns_2dict_t));
      memset (cli->cli_ns_2dict, 0, sizeof (xml_ns_2dict_t));
    }
  return cli->cli_ns_2dict;
}


caddr_t
bif_xml_set_ns_decl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t pref = bif_string_or_uname_arg (qst, args, 0, "__xml_set_ns_decl");
  caddr_t uri = bif_string_or_uname_arg (qst, args, 1, "__xml_set_ns_decl");
  ptrlong persistent = bif_long_arg (qst, args, 2, "__xml_set_ns_decl");
  int res = 0;
  nsdecl_t decl;
  if (('n' == pref[0]) && isdigit (pref[1]))
    return 0; /* We never remember namespaces that are too similar to our namespace prefixes */
  decl.nsd_prefix = pref;
  decl.nsd_uri = uri;
  if (persistent & 0x1)
    {
      xml_ns_2dict_t *xn2 = xml_cli_ns_2dict (((query_instance_t *)qst)->qi_client);
      if (xml_ns_2dict_add (xn2, &decl))
        res |= 0x1;
    }
  if (persistent & 0x2)
    {
      xml_ns_2dict_t *xn2;
      xn2 = xml_global_ns_2dict_get (qst, "__xml_set_ns_decl");
      if (xml_ns_2dict_add (xn2, &decl))
        res |= 0x2;
      xml_global_ns_2dict_release (xn2);
    }
  return box_num (res);
}

caddr_t
xml_get_cli_or_global_ns_prefix (caddr_t * qst, const char *uri, ptrlong persistent)
{
  /* return NULL; until crash is fixed */
  if ((NULL != qst) && (persistent & 0x1))
    {
      xml_ns_2dict_t *xn2 = xml_cli_ns_2dict (((query_instance_t *)qst)->qi_client);
      long iri_idx = ecm_find_name (uri, xn2->xn2_uri2prefix, xn2->xn2_size, sizeof (xml_name_assoc_t));
      if (ECM_MEM_NOT_FOUND != iri_idx)
        return box_copy (xn2->xn2_uri2prefix[iri_idx].xna_value);
    }
  if (persistent & 0x2)
    {
      caddr_t res = NULL;
      xml_ns_2dict_t *xn2 = xml_global_ns_2dict_get (NULL, NULL);
      long iri_idx = ecm_find_name (uri, xn2->xn2_uri2prefix, xn2->xn2_size, sizeof (xml_name_assoc_t));
      if (ECM_MEM_NOT_FOUND != iri_idx)
        res = box_copy (xn2->xn2_uri2prefix[iri_idx].xna_value);
      xml_global_ns_2dict_release (xn2);
      return res;
    }
  return NULL;
}

caddr_t
bif_xml_get_ns_prefix (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t uri = bif_string_or_uname_arg (qst, args, 0, "__xml_get_ns_prefix");
  ptrlong persistent = bif_long_arg (qst, args, 1, "__xml_get_ns_prefix");
  caddr_t res = xml_get_cli_or_global_ns_prefix (qst, uri, persistent);
  if (NULL == res)
    return NEW_DB_NULL;
  return res;
}

caddr_t
xml_get_ns_uri (client_connection_t *cli, caddr_t pref, ptrlong persistent, int ret_in_mp_box)
{
  caddr_t res = NULL;
  if ((NULL != cli) && (persistent & 0x1))
    {
      xml_ns_2dict_t *xn2 = xml_cli_ns_2dict (cli);
      long pref_idx = ecm_find_name (pref, xn2->xn2_prefix2uri, xn2->xn2_size, sizeof (xml_name_assoc_t));
      if (ECM_MEM_NOT_FOUND != pref_idx)
        {
          res = xn2->xn2_prefix2uri[pref_idx].xna_value;
          res = (ret_in_mp_box ? t_box_copy(res) : box_copy(res));
        }
    }
  if ((NULL == res) && (persistent & 0x2))
    {
      xml_ns_2dict_t *xn2 = xml_global_ns_2dict_get (NULL, NULL);
      long pref_idx = ecm_find_name (pref, xn2->xn2_prefix2uri, xn2->xn2_size, sizeof (xml_name_assoc_t));
      if (ECM_MEM_NOT_FOUND != pref_idx)
        {
          res = xn2->xn2_prefix2uri[pref_idx].xna_value;
          res = (ret_in_mp_box ? t_box_copy(res) : box_copy(res));
        }
      xml_global_ns_2dict_release (xn2);
    }
  return res;
}

caddr_t
bif_xml_get_ns_uri (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t pref = bif_string_or_uname_arg (qst, args, 0, "__xml_get_ns_uri");
  ptrlong persistent = bif_long_arg (qst, args, 1, "__xml_get_ns_uri");
  caddr_t res = xml_get_ns_uri (((query_instance_t *)qst)->qi_client, pref, persistent, 0);
  return ((NULL == res) ? NEW_DB_NULL : res);
}

caddr_t
bif_xml_ns_uname (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t pref = bif_string_or_uname_arg (qst, args, 0, "__xml_ns_uname");
  caddr_t local = bif_string_or_uname_arg (qst, args, 1, "__xml_ns_uname");
  caddr_t ns_uri = xml_get_ns_uri (((query_instance_t *)qst)->qi_client, pref, 0xffff, 0);
  caddr_t res;
  if (NULL == ns_uri)
    sqlr_new_error ("22023", "SR648", "Unknown XML namespace prefix \"%.50s\"", pref);
  BOX_DV_UNAME_CONCAT (res, ns_uri, local);
  dk_free_box (ns_uri);
  return res;
}

caddr_t
bif_xml_ns_iristr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t pref = bif_string_or_uname_arg (qst, args, 0, "__xml_ns_iristr");
  caddr_t local = bif_string_or_uname_arg (qst, args, 1, "__xml_ns_iristr");
  caddr_t ns_uri = xml_get_ns_uri (((query_instance_t *)qst)->qi_client, pref, 0xffff, 0);
  caddr_t res;
  if (NULL == ns_uri)
    sqlr_new_error ("22023", "SR648", "Unknown XML namespace prefix \"%.50s\"", pref);
  res = box_dv_short_concat (ns_uri, local);
  dk_free_box (ns_uri);
  box_flags (res) = BF_IRI;
  return res;
}

caddr_t
bif_xml_nsexpand_iristr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t src = bif_string_or_uname_arg (qst, args, 0, "__xml_nsexpand_iristr");
  const char *colon = strchr (src, ':');
  caddr_t ns_pref, ns_uri;
  caddr_t res;
  if (NULL == colon)
    sqlr_new_error ("22023", "SR649", "No XML namespace prefix in string \"%.200s\"", src);
  ns_pref = box_dv_short_nchars (src, colon - src);
  ns_uri = xml_get_ns_uri (((query_instance_t *)qst)->qi_client, ns_pref, 0xffff, 0);
  dk_free_box (ns_pref);
  if (NULL == ns_uri)
    sqlr_new_error ("22023", "SR648", "Unknown XML namespace prefix in IRI \"%.200s\"", src);
  res = box_dv_short_strconcat (ns_uri, colon+1);
  dk_free_box (ns_uri);
  box_flags (res) = BF_IRI;
  return res;
}

caddr_t
bif_xml_get_all_ns_decls (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong persistent = bif_long_arg (qst, args, 0, "__xml_get_all_ns_decls");
  dk_set_t acc = NULL;
  int size, ctr;
  if (persistent & 0x2)
    {
      xml_ns_2dict_t *xn2 = xml_global_ns_2dict_get (NULL, NULL);
      size = xn2->xn2_size;
      for (ctr = 0; ctr < size; ctr++)
        {
          xml_name_assoc_t *xna = xn2->xn2_prefix2uri + ctr;
          dk_set_push (&acc, box_copy (xna->xna_key));
          dk_set_push (&acc, box_copy (xna->xna_value));
        }
      xml_global_ns_2dict_release (xn2);
    }
  if (persistent & 0x1)
    {
      xml_ns_2dict_t *xn2 = xml_cli_ns_2dict (((query_instance_t *)qst)->qi_client);
      size = xn2->xn2_size;
      for (ctr = 0; ctr < size; ctr++)
        {
          xml_name_assoc_t *xna = xn2->xn2_prefix2uri + ctr;
          dk_set_push (&acc, box_copy (xna->xna_key));
          dk_set_push (&acc, box_copy (xna->xna_value));
        }
    }
  return revlist_to_array (acc);
}

caddr_t
bif_xml_remove_ns_by_prefix (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t pref = bif_string_or_uname_arg (qst, args, 0, "__xml_remove_ns_by_prefix");
  ptrlong persistent = bif_long_arg (qst, args, 1, "__xml_remove_ns_by_prefix");
  if (persistent & 0x2)
    {
      xml_ns_2dict_t *xn2;
      xn2 = xml_global_ns_2dict_get (qst, "__xml_remove_ns_by_prefix");
      xml_ns_2dict_del (xn2, pref);
      xml_global_ns_2dict_release (xn2);
    }
  if (persistent & 0x1)
    {
      xml_ns_2dict_t *xn2 = xml_cli_ns_2dict (((query_instance_t *)qst)->qi_client);
      xml_ns_2dict_del (xn2, pref);
    }
  return NEW_DB_NULL;
}

caddr_t
bif_xml_clear_all_ns_decls (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  ptrlong persistent = bif_long_arg (qst, args, 0, "__xml_clear_all_ns_decls");
  if (persistent & 0x2)
    {
      xml_ns_2dict_t *xn2;
      xn2 = xml_global_ns_2dict_get (qst, "__xml_clear_all_ns_decls");
      xml_ns_2dict_clean (xn2);
      xml_global_ns_2dict_release (xn2);
    }
  if (persistent & 0x1)
    {
      xml_ns_2dict_t *xn2 = xml_cli_ns_2dict (((query_instance_t *)qst)->qi_client);
      xml_ns_2dict_clean (xn2);
    }
  return NEW_DB_NULL;
}

xml_doc_cache_t *
xml_doc_cache_alloc (void *owner)
{
  NEW_VARZ (xml_doc_cache_t, xdc);
  xdc->xdc_owner = owner;
  xdc->xdc_yellow_weight = 20000; /* Shrink if greater than 20 Mb */
  xdc->xdc_red_weight = 100000; /* Clean if greater than 100 Mb */
  xdc->xdc_res_cache = id_hash_allocate (61, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
  return xdc;
}


void xml_doc_cache_free (xml_doc_cache_t *xdc)
{
  if (NULL != xdc)
    {
      id_hash_t *hash = xdc->xdc_res_cache;
      id_hash_iterator_t hit;
      caddr_t *key_ptr, *doc_ptr;
      id_hash_iterator (&hit, hash);
      while (hit_next (&hit, (char **)&key_ptr, (char **)&doc_ptr))
        {
	  ptrlong type = ((ptrlong **) key_ptr)[0][0];
	  if (XDC_DOCUMENT == type)
	    XD_DOM_RELEASE (((xml_entity_t **)doc_ptr)[0]->xe_doc.xd);
	  dk_free_tree (doc_ptr[0]);
	  dk_free_tree (key_ptr[0]);
        }
      id_hash_free (hash);
      dk_free (xdc, sizeof (xml_doc_cache_t));
    }
}


caddr_t xml_doc_cache_get_copy (xml_doc_cache_t *xdc, ccaddr_t key)
{
  id_hash_t *hash;
  caddr_t *doc_ptr;
  /* ptrlong type = ((ptrlong *) key)[0];*/
  if (NULL == xdc)
    return NULL;
  hash = xdc->xdc_res_cache;
  doc_ptr = (caddr_t *)id_hash_get (hash, (caddr_t)(&key));
  if (NULL == doc_ptr)
    return NULL;
  return box_copy_tree (doc_ptr[0]);
}


void xml_doc_cache_add_copy (xml_doc_cache_t **xdc_ptr, ccaddr_t key, caddr_t doc)
{
  id_hash_t *hash;
  ptrlong type = ((ptrlong *) key)[0];
  xml_entity_t **old_doc_ptr;
  if (NULL == xdc_ptr[0])
    xdc_ptr[0] = xml_doc_cache_alloc (xdc_ptr);
  hash = xdc_ptr[0]->xdc_res_cache;
  if ((XDC_DOCUMENT == type) && ((xml_tree_ent_t *)doc)->xe_doc.xd->xd_dom_mutation)
    {
#ifdef DEBUG
      GPF_T1 ("xml_doc_cache_add_copy on mutated doc");
#endif
      return;
    }
  old_doc_ptr = (xml_entity_t **)id_hash_get (hash, (caddr_t)(&key));
  if (NULL != old_doc_ptr)
    {
#ifdef DEBUG
      GPF_T1 ("xml_doc_cache_add_copy on already cached document");
#endif
      return;
    }
  if (XDC_DOCUMENT == type)
    XD_DOM_LOCK (((xml_entity_t *)doc)->xe_doc.xd);
  doc = box_copy_tree (doc);
  key = box_copy_tree ((caddr_t)key);
  id_hash_set (hash, (caddr_t)(&key), (caddr_t)(&doc));
}


void xml_doc_cache_shrink (xml_doc_cache_t *xdc, size_t weight_limit)
{
/* TBD */
}


shuric_cache_t *xquery_eval_cache;
shuric_cache_t *xpath_eval_cache;

caddr_t xmltype_class_name = NULL;

bif_type_t bt_xml_entity = {NULL, DV_XML_ENTITY, 0, 0};

void
xml_tree_init (void)
{
  macro_char_func *rt;
  dk_dtp_register_hash (DV_XML_ENTITY, xml_ent_hash, xml_ent_hash_cmp, xml_ent_hash_cmp);
#ifdef MALLOC_DEBUG
  xec_tree_xe.dbg_xe_copy = dbg_xte_copy;
  xec_tree_xe.dbg_xe_cut = dbg_xte_cut;
  xec_tree_xe.dbg_xe_clone = dbg_xte_clone;
  xec_tree_xe.dbg_xe_attribute = dbg_xte_attribute;
  xec_tree_xe.dbg_xe_string_value = (void (*) (DBG_PARAMS xml_entity_t * xe, caddr_t * ret, dtp_t dtp)) dbg_xte_string_value;
#else
  xec_tree_xe.xe_copy = xte_copy;
  xec_tree_xe.xe_cut = xte_cut;
  xec_tree_xe.xe_clone = xte_clone;
  xec_tree_xe.xe_attribute = xte_attribute;
  xec_tree_xe.xe_string_value = (void (*) (xml_entity_t * xe, caddr_t * ret, dtp_t dtp)) xte_string_value;
#endif
  xec_tree_xe.xe_string_value_is_nonempty = (int (*) (xml_entity_t * xe)) xte_string_value_is_nonempty;
  xec_tree_xe.xe_first_child = xte_first_child;
  xec_tree_xe.xe_last_child = xte_last_child;
  xec_tree_xe.xe_get_child_count_any = xte_get_child_count_any;
  xec_tree_xe.xe_next_sibling = xte_next_sibling;
/* IvAn/SmartXContains/001025 WR-optimized iteration function added */
  xec_tree_xe.xe_next_sibling_wr = xte_next_sibling_wr;
  xec_tree_xe.xe_prev_sibling = xte_prev_sibling;
  xec_tree_xe.xe_prev_sibling_wr = xte_prev_sibling; /* There's no optimized function */
  xec_tree_xe.xe_element_name = xte_element_name;
  xec_tree_xe.xe_ent_name = xte_ent_name;
  xec_tree_xe.xe_is_same_as = xte_is_same_as;

  xec_tree_xe.xe_destroy = xte_destroy;
  xec_tree_xe.xe_serialize = xte_serialize;
  xec_tree_xe.xe_attrvalue = xte_attrvalue;
  xec_tree_xe.xe_currattrvalue = xte_currattrvalue;
  xec_tree_xe.xe_data_attribute_count = (size_t (*) (xml_entity_t *)) xte_data_attribute_count;
  xec_tree_xe.xe_up = xte_up;
  xec_tree_xe.xe_down = xte_down;
  xec_tree_xe.xe_down_rev = xte_down_rev;
  xec_tree_xe.xe_word_range = xte_word_range;
  xec_tree_xe.xe_attr_word_range = xte_attr_word_range;
/* IvAn/XperUpdate/000804
    For trees, log update uses plain serialization.
    For Xper, special handler is needed: it's necessary to record only the blob itself. */
  xec_tree_xe.xe_log_update = xte_log_update;
  xec_tree_xe.xe_get_logical_path = xte_get_logical_path;
  xec_tree_xe.xe_get_addon_dtd = xte_get_addon_dtd;
  xec_tree_xe.xe_get_sysid = xte_get_sysid;
  xec_tree_xe.xe_element_name_test = xte_element_name_test;
  xec_tree_xe.xe_ent_name_test = xte_ent_name_test;
  xec_tree_xe.xe_ent_node_test = (int (*) (xml_entity_t *, XT *))xte_ent_node_test;
  xec_tree_xe.xe_deref_id = xte_deref_id;
  xec_tree_xe.xe_follow_path = xte_follow_path;
  xec_tree_xe.xe_copy_to_xte_head = xte_copy_to_xte_head;
  xec_tree_xe.xe_copy_to_xte_subtree = xte_copy_to_xte_subtree;
  xec_tree_xe.xe_copy_to_xte_forest = xte_copy_to_xte_forest;
  xec_tree_xe.xe_emulate_input = xte_emulate_input;
  xec_tree_xe.xe_reference = xte_reference;
  xec_tree_xe.xe_find_expanded_name_by_qname = xte_find_expanded_name_by_qname;
  xec_tree_xe.xe_namespace_scope = xte_namespace_scope;

  xquery_eval_cache = shuric_cache__LRU.shuric_cache_alloc (XP_EVAL_CACHE_SIZE, NULL);
  xpath_eval_cache = shuric_cache__LRU.shuric_cache_alloc (XP_EVAL_CACHE_SIZE, NULL);

  bif_define_ex ("xml_tree_doc", bif_xml_tree_doc, BMD_RET_TYPE, &bt_xml_entity, BMD_DONE);
  bif_define ("xml_doc_get_base_uri", bif_xml_doc_get_base_uri);
  bif_define ("xml_doc_assign_base_uri", bif_xml_doc_assign_base_uri);
  bif_define ("xml_doc_output_option", bif_xml_doc_output_option);
  bif_define ("xml_tree_doc_media_type", bif_xml_tree_doc_media_type);
  bif_define ("xml_tree_doc_encoding", bif_xml_tree_doc_encoding);
  bif_define ("xml_tree_doc_set_output", bif_xml_tree_doc_set_output);
  bif_define ("xml_tree_doc_set_ns_output", bif_xml_tree_doc_set_ns_output);
  bif_define ("xml_namespace_scope", bif_xml_namespace_scope);
  bif_define ("xtree_doc_get_dtd", bif_xtree_doc_get_dtd);
  bif_define ("xpath_eval", bif_xpath_eval); /* not bif_define_ex ("xpath_eval", bif_xpath_eval, BMD_RET_TYPE, &bt_xml_entity, BMD_DONE); */
  bif_set_uses_index (bif_xpath_eval);
  bif_define ("xquery_eval", bif_xquery_eval);
  bif_set_uses_index (bif_xquery_eval);
  bif_define ("xpath_eval__w_cache", bif_xpath_eval_w_cache);
  bif_set_uses_index (bif_xpath_eval_w_cache);
  bif_define ("xquery_eval__w_cache", bif_xquery_eval_w_cache);
  bif_set_uses_index (bif_xquery_eval_w_cache);
  bif_define ("xpath_explain", bif_xpath_explain);
  bif_define ("xquery_explain", bif_xquery_explain);
  bif_define ("xpath_text", bif_xpath_text);
  bif_define ("xpath_lex_analyze", bif_xpath_lex_analyze);
  bif_define ("xquery_lex_analyze", bif_xquery_lex_analyze);
  bif_define ("xpath_funcall", bif_xpath_funcall);
  bif_set_uses_index (bif_xpath_funcall);
  bif_define ("xpath_apply", bif_xpath_apply);
  bif_set_uses_index (bif_xpath_apply);
  bif_define ("xpath_funcall__w_cache", bif_xpath_funcall_w_cache);
  bif_set_uses_index (bif_xpath_funcall_w_cache);
  bif_define ("xpath_apply__w_cache", bif_xpath_apply_w_cache);
  bif_set_uses_index (bif_xpath_apply_w_cache);
#ifdef XPATHP_DEBUG
  bif_define ("xpathp_test", bif_xpathp_test);
#endif
  bif_define_ex ("xslt_format_number", bif_xslt_format_number, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("updateXML", bif_updateXML, BMD_ALIAS, "XMLUpdate", BMD_DONE);
  bif_define_ex ("updateXML_ent", bif_updateXML_ent, BMD_ALIAS, "XMLUpdate_ent", BMD_DONE);
  bif_define ("XMLReplace", bif_XMLReplace);
  bif_define ("XMLInsertBefore", bif_XMLInsertBefore);
  bif_define ("XMLInsertAfter", bif_XMLInsertAfter);
  bif_define ("XMLAppendChildren", bif_XMLAppendChildren);
  bif_define ("XMLAddAttribute", bif_XMLAddAttribute);
  bif_define ("__xml_serialize_packed", bif_xml_serialize_packed);
  bif_define ("__xml_deserialize_packed", bif_xml_deserialize_packed);
  bif_define ("xml_get_logical_path", bif_xml_get_logical_path);
  bif_define ("xml_follow_logical_path", bif_xml_follow_logical_path);
#if 0
  bif_define ("xtree_tridgell32", bif_xtree_tridgell32);
#endif
  bif_define ("xtree_sum64", bif_xtree_sum64);
  bif_define ("__xsd_type", bif_xsd_type);
  bif_define ("__xml_set_ns_decl", bif_xml_set_ns_decl);
  bif_define ("__xml_get_ns_prefix", bif_xml_get_ns_prefix);
  bif_define ("__xml_get_ns_uri", bif_xml_get_ns_uri);
  bif_define ("__xml_ns_uname", bif_xml_ns_uname);
  bif_define ("__xml_ns_iristr", bif_xml_ns_iristr);
  bif_define ("__xml_nsexpand_iristr", bif_xml_nsexpand_iristr);
  bif_define ("__xml_get_all_ns_decls", bif_xml_get_all_ns_decls);
  bif_define ("__xml_remove_ns_by_prefix", bif_xml_remove_ns_by_prefix);
  bif_define ("__xml_clear_all_ns_decls", bif_xml_clear_all_ns_decls);
  dk_mem_hooks (DV_XML_ENTITY, xe_make_copy, xe_destroy, 0);
  box_tmp_copier[DV_XML_ENTITY] = xe_mp_copy;
  dk_mem_hooks (DV_XQI, box_non_copiable, xqi_destroy, 0);
  dk_mem_hooks (DV_XPATH_QUERY, xqr_addref, xqr_release, 1);
  PrpcSetWriter (DV_XML_ENTITY, (ses_write_func) xe_serialize);
  PrpcSetWriter (DV_XPATH_QUERY, (ses_write_func) xqr_serialize);
  rt = get_readtable ();
  rt[DV_XML_ENTITY] = (macro_char_func) xe_deserialize;
  xpf_init();
  xslt_init ();
  bif_tidy_init();
  st_integer = (sql_tree_tmp *) list (3, (ptrlong)DV_LONG_INT, (ptrlong)0, (ptrlong)0);
  xmltype_class_name = sqlp_box_id_upcase ("DB.DBA.XMLType");
}
