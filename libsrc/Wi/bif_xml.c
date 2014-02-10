/*
 *  bif_xml.c
 *
 *  $Id$
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

#include "Dk.h"
#include "odbcinc.h"
#include "sqlnode.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "lisprdr.h"
#include "sqlpar.h"
#include "map_schema.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "remote.h"
#include "sqlrcomp.h"
#include "arith.h"
#include "security.h"
#include "libutil.h"
#include "srvmultibyte.h"
#include "multibyte.h"

#include "xml.h"
#include "http.h"
#include "xmltree.h"
#include "bif_xper.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser.h"
#include "xmlparser_impl.h"
#ifdef __cplusplus
}
#endif
#include "xslt_impl.h"
#include "soap.h"
#include "sqltype.h" /* for XMLTYPE_TO_ENTITY */
#include "shuric.h"

#define XMLATTRIBUTE_FLAG (caddr_t)(SMALLEST_POSSIBLE_POINTER - 20)

#define xn_source_is_dead(xn) \
  ((NULL != (xn)->xn_xp->xp_parser) && \
   (DEAD_HTML & ((xn)->xn_xp->xp_parser->cfg.input_is_html)) )

void
bif_to_xml_array_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func,
    dk_set_t *ret_set, dk_set_t *head_set);


void
eid_append (uint32 * eid, int l1, int * len_ret)
{
  if (l1 > EID_MAX_WORDS)
    sqlr_new_error ("XP002", "EID01", "No space between eid's in xml_eid()");
  *len_ret = l1 + 1;
  eid[l1] = 0x80000000;
}


void
eid_fill_to_len (uint32 * id1, int l1, uint32 * id2, int l2, int * len_ret)
{
  int inx;
  for (inx = l1; inx < l2; inx++)
    {
      if (id2[inx] > DELTA)
	{
	  id1[inx] = DELTA;
	  *len_ret = inx + 1;
	  return;
	}
      id1[inx] = 0;
    }
  eid_append (id1, l2, len_ret);
  return;
}


void
eid_inc_at (uint32 * id1, int l1, int l2, int * len_ret)
{
  for (;;)
    {
      if (l2 == l1)
	{
	  eid_append (id1, l1, len_ret);
	  return;
	}
      if (id1[l2] < 0xfffffff8)
	{
	  id1[l2] += DELTA;
	  *len_ret = l2 + 1;
	  return;
	}
      l2++;
    }
}



void
eid_next (uint32 * id1, int l1,  uint32 * id2, int l2,  int * len_ret, int tight)
{
  int shorter = MIN (l1, l2);
  int firstdiff;
  uint32 diff;
  for (firstdiff = 0; firstdiff < shorter; firstdiff ++)
    {
      if (id1[firstdiff] != id2[firstdiff])
	break;
    }

  if (firstdiff == shorter)
    {
      if (l1 >= l2)
	sqlr_new_error ("XP002", "EID02", "eid1 >= id2 in xml_eid()");

      eid_fill_to_len (id1, l1, id2, l2, len_ret);
      return;
    }


  if (id1[firstdiff] > id2[firstdiff])
    sqlr_new_error ("XP002", "EID03", "id1 > id2 in xml_eid()");
  diff = id2[firstdiff] - id1[firstdiff];
  if (diff < DELTA)
    {
      if (diff == 1 || !tight)
	{
	  if (l1 == l2)
	    eid_append (id1, firstdiff + 1, len_ret);
	  else if (l1 > l2)
	    eid_inc_at (id1, l1, l2, len_ret);
	  else
	    eid_fill_to_len (id1, l1, id2, l2, len_ret);
	  return;
	}
    }
  id1[firstdiff] += tight ? 1 : DELTA;
  *len_ret = firstdiff + 1;
}



void
eid_to_temp (caddr_t idb, uint32 * temp, int * len_ret)
{
  int inx;
  int l = box_length (idb);
  if (l & 3)
    sqlr_new_error ("XP002", "EID04", "eid's length is incorrect, must be a multiply of 4");
  l = l / 4;
  for (inx = 0; inx < l; inx++)
    {
      temp[inx] = LONG_TO_EXT (((uint32*)idb)[inx]);
    }
  *len_ret = l;
}


caddr_t
bx_xml_eid (caddr_t right, caddr_t left, int is_tight)
{
  int l1, l2, i;
  uint32 id1 [EID_MAX_WORDS];
  uint32 id2 [EID_MAX_WORDS];
  caddr_t res;

  eid_to_temp (right, id1, &l1);
  eid_to_temp (left,  id2, &l2);
  eid_next (id1, l1, id2, l2, &l1, 0);

  res = dk_alloc_box (l1 * sizeof(uint32), DV_BIN);
  for (i = 0; i < l1; i++)
    {
      uint32* tmp = (uint32*)res;
      tmp[i] = LONG_TO_EXT (id1[i]);
    }
  return res;
}



caddr_t
bif_xml_eid (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t idb1 = bif_bin_arg (qst, args, 0, XMLEID);
  caddr_t idb2 = bif_bin_arg (qst, args, 1, XMLEID);
  int is_tight = (int) bif_long_arg (qst, args, 2, XMLEID);
  return (bx_xml_eid (idb1, idb2, is_tight));
}


void
bx_elt_ins_qr (char * elt)
{

}


void
xn_error (xp_node_t * xn, const char * msg)
{
  vxml_parser_t *vxml_parser;
  xn->xn_xp->xp_error_msg = box_dv_short_string (msg);
  vxml_parser = xn->xn_xp->xp_parser;
  if (NULL != vxml_parser)
    xmlparser_logprintf (vxml_parser, XCFG_ERROR, strlen (msg), "%s", msg);
  longjmp (xn->xn_xp->xp_error_ctx, 1);
}


caddr_t
xn_ns_name (xp_node_t * xn, char * name, int use_default)
{
  xp_node_t * ctx_xn;
  size_t ns_len = 0, nsinx;
  char * local = strrchr (name, ':');
  if (!local && !use_default)
    return box_dv_uname_string (name);
  if (local)
    {
      ns_len = local - name;
      if (bx_std_ns_pref (name, ns_len))
	return box_dv_uname_string (name);
      local++;
    }
  else
    local = name;
  ctx_xn = xn;
  while (ctx_xn)
    {
      size_t n_ns = BOX_ELEMENTS_0 (ctx_xn->xn_namespaces);
      for (nsinx = 0; nsinx < n_ns; nsinx += 2)
	{
	  char *ctxname = ctx_xn->xn_namespaces[nsinx];
	  if ((box_length (ctxname) == (ns_len + 1)) && !memcmp (ctxname, name, ns_len))
	    {
	      char *res;
	      size_t local_len = strlen (local);
	      char * ns_uri = ctx_xn->xn_namespaces[nsinx + 1];
	      size_t ns_uri_len, res_len;
	      ns_uri_len = strlen (ns_uri);
              if (0 == ns_uri_len) /* this is for xmlns="" */
                return box_dv_uname_nchars (local, local_len);
	      res_len = ns_uri_len + local_len + 1;
	      res = box_dv_ubuf (res_len);
	      memcpy (res, ns_uri, ns_uri_len);
	      res[ns_uri_len] = ':';
	      memcpy (res+ns_uri_len+1, local, local_len);
	      res[res_len] = '\0';
	      return box_dv_uname_from_ubuf (res);
	    }
	}
      ctx_xn = ctx_xn->xn_parent;
    }
  if (0 == ns_len)
    return box_dv_uname_string (name);
  return NULL; /* dummy */
}


int
xn_box_attrs (xp_node_t * xn, caddr_t name, vxml_parser_attrdata_t *attrdata, int reserve_attrs)
{
  int namespaces_are_valid = 1;
  int fill, n_attrs = attrdata->local_attrs_count, n_ns = attrdata->local_nsdecls_count;
  caddr_t * box;
  caddr_t * save_ns;
  int inx;
  if (n_ns)
    {
      save_ns = xn->xn_namespaces = (caddr_t*) dk_alloc_box (2 * n_ns * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      fill = 0;
      for (inx = 0; inx < n_ns; inx++)
        {
          save_ns[fill++] = box_dv_uname_string (attrdata->local_nsdecls[inx].nsd_prefix);
          save_ns[fill++] = box_dv_uname_string (attrdata->local_nsdecls[inx].nsd_uri);
        }
    }
  else
    save_ns = xn->xn_namespaces = NULL;
  fill = 0;
  xn->xn_attrs = box = (caddr_t *) dk_alloc_box (((n_attrs + ((NULL != save_ns) ? 1 : 0) + reserve_attrs) * 2 + 1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  box[0] = xn_ns_name (xn, name, 1);
  if (NULL == box[0])
    {
      namespaces_are_valid = 0;
      box[0] = box_dv_uname_string (name);
    }
  for (inx = 0; inx < n_attrs; inx ++)
    {
	  /* Is the attribute value to be expanded as QName:
	     we w'll do only if attribute is prefixed or
	     element is from the XMLSchema
	   */
	  char *name = attrdata->local_attrs[inx].ta_raw_name.lm_memblock;
	  caddr_t *value_ptr = &(attrdata->local_attrs[inx].ta_value);
	  caddr_t nsname = xn_ns_name (xn, name, 0);
	  caddr_t nsname1 = NULL;
	  if (xml_is_sch_qname (box[0], nsname) ||
	      xml_is_soap_qname (box[0], nsname) ||
	      xml_is_wsdl_qname (box[0], nsname))
	    nsname1 = xn_ns_name (xn, value_ptr[0], 0);
	  if (NULL != nsname)
	    box[fill + 1] = nsname;
	  else
	    {
              namespaces_are_valid = 0;
              box[fill + 1] = box_dv_uname_string (name);
            }
	  if (NULL == nsname1)
	    {
	      box[fill + 2] = value_ptr[0];
	      value_ptr[0] = NULL;
	    }
	  else
	    {
	      box[fill + 2] = box_dv_short_string(nsname1);
	      dk_free_box (nsname1);
	    }
	  fill += 2;
    }
  if (NULL != save_ns)
    {
      box [++fill] = uname__bang_ns;
      box [++fill] = (caddr_t)save_ns;
    }
  return namespaces_are_valid;
}

void *xmlap_xpath (void *userData, const char *elname, const char *attrname, const char *attrvalue) { GPF_T; return NULL; }
void *xmlap_qname (void *userData, const char *elname, const char *attrname, const char *attrvalue) { GPF_T; return NULL; }

void
xp_element (void *userdata, char * name, vxml_parser_attrdata_t *attrdata)
{
  xparse_ctx_t * xp = (xparse_ctx_t*) userdata;
  caddr_t boxed_name;
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
  boxed_name = xp->xp_boxed_name = box_dv_uname_string (name);
  xp->xp_namespaces_are_valid &= xn_box_attrs (xn, boxed_name, attrdata, 0);
  xp->xp_boxed_name = NULL;
  dk_free_box (boxed_name);
}


void
xp_element_end (void *userdata, const char * name)
{
  xparse_ctx_t * xp = (xparse_ctx_t*) userdata;
  dk_set_t children;
  caddr_t * l;
  xp_node_t * current = xp->xp_current;
  xp_node_t * parent = xp->xp_current->xn_parent;
  XP_STRSES_FLUSH (xp);
  children = dk_set_nreverse (current->xn_children);
  children = CONS (current->xn_attrs, children);
  l = (caddr_t *) list_to_array (children);
  dk_set_push (&parent->xn_children, (void*) l);
  parent->xn_n_children++;
  if (parent->xn_n_children >= MAX_BOX_ELEMENTS)
    xn_error (current, "The number of children elements is over the limits");
  xp->xp_current = parent;
  current->xn_parent = xp->xp_free_list;
  xp->xp_free_list = current;
}


void
xp_xslt_element (void *userdata,  char * name, vxml_parser_attrdata_t *attrdata)
{
  xparse_ctx_t * xp = (xparse_ctx_t*) userdata;
/* copy from xp_element - start */
  caddr_t boxed_name;
  xp_node_t *xn = xp->xp_free_list;
  XP_STRSES_FLUSH (xp);
  if (NULL == xn)
    xn = dk_alloc (sizeof (xp_node_t));
  else
    xp->xp_free_list = xn->xn_parent;
  memset (xn, 0, sizeof (xp_node_t));
  xn->xn_xp = xp;
  xn->xn_parent = xp->xp_current;
  xp->xp_current = xn;
  boxed_name = xp->xp_boxed_name = box_dv_uname_string (name);
  xp->xp_namespaces_are_valid &= xn_box_attrs (xn, boxed_name, attrdata, 0);
  xp->xp_boxed_name = NULL;
  dk_free_box (boxed_name);
/* copy from xp_element - end */
  xn_xslt_attributes (xp->xp_current);
}

void
xp_element_srcpos (void *userdata,  char * name, vxml_parser_attrdata_t *attrdata)
{
  xparse_ctx_t * xp = (xparse_ctx_t*) userdata;
  caddr_t *tail;
  char buf[20];
/* copy from xp_element - start */
  caddr_t boxed_name;
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
  boxed_name = xp->xp_boxed_name = box_dv_uname_string (name);
  xp->xp_namespaces_are_valid &= xn_box_attrs (xn, boxed_name, attrdata, 2);
  xp->xp_boxed_name = NULL;
  dk_free_box (boxed_name);
/* copy from xp_element - end */
  tail = xn->xn_attrs + BOX_ELEMENTS (xn->xn_attrs) - 4;
  (tail++)[0] = uname__srcfile;
  (tail++)[0] = box_dv_short_string (VXmlGetCurrentFileName (xp->xp_parser));
  (tail++)[0] = uname__srcline;
  snprintf(buf, sizeof (buf), "%d", VXmlGetCurrentLineNumber (xp->xp_parser));
  (tail++)[0] = box_dv_short_string (buf);
}

void nss_free (id_hash_t * nss)
{
  id_hash_iterator_t hit;
  caddr_t ** curr;
  caddr_t ** namespaces;
  if (!nss)
    return;
  for (id_hash_iterator (&hit, nss);
       hit_next (&hit, (caddr_t*) &curr, (caddr_t*) & namespaces);
       /* */)
    {
      if (namespaces) dk_free_tree ((box_t) namespaces[0]);
    }
  id_hash_free (nss);
}

void
xp_xslt_element_end (void *userdata, const char * name)
{
  xparse_ctx_t * xp = (xparse_ctx_t*) userdata;
/* copy from xp_element_end - start */
  dk_set_t children;
  caddr_t * l;
  xp_node_t * current = xp->xp_current;
  xp_node_t * parent = xp->xp_current->xn_parent;
/* copy from xp_element_end - end */
  if (((caddr_t) xp->xp_current) == xp->xp_xslt_start)
    xp->xp_xslt_start = NULL;
/* copy from xp_element_end - start */
  XP_STRSES_FLUSH (xp);
  children = dk_set_nreverse (current->xn_children);
  children = CONS (current->xn_attrs, children);
  l = (caddr_t *) list_to_array (children);
  dk_set_push (&parent->xn_children, (void*) l);
  parent->xn_n_children++;
  if (parent->xn_n_children >= MAX_BOX_ELEMENTS)
    xn_error (current, "The number of children elements is over the limits");
  xp->xp_current = parent;
  if (current->xn_namespaces && xp->xp_namespaces)
    {
      caddr_t copy = box_copy_tree (current->xn_namespaces);
      id_hash_set (xp->xp_namespaces, (caddr_t) &l, (caddr_t) &copy);
    }
  current->xn_parent = xp->xp_free_list;
  xp->xp_free_list = current;
/* copy from xp_element_end - end */
}


void
xp_id (void *userdata, char * name)
{
  xparse_ctx_t * xp = (xparse_ctx_t*) userdata;
  caddr_t boxed_name = box_dv_short_string (name);
  id_hash_t *dict = xp->xp_id_dict;
  ptrlong **id_hit, *lpath;
  xp_node_t *current, *parent;
  size_t depth, levelctr;
  if (NULL == dict)
    {
      xp->xp_id_dict = dict = (id_hash_t *)box_dv_dict_hashtable (509);
    }
  id_hit = (ptrlong **)id_hash_get (dict, (caddr_t)(&boxed_name));
  if (NULL != id_hit)
    {
      dk_free_box (boxed_name);
      return;
    }
/* Calculate a path to current element. */
  depth = 1;
  current = xp->xp_current;
  for (;;)
    {
      parent = current->xn_parent;
      if (NULL == parent)
	break;
      depth++;
      current = parent;
    }
  lpath = (ptrlong *) dk_alloc_box (sizeof (ptrlong) * depth, DV_ARRAY_OF_LONG);
  current = xp->xp_current;
  levelctr = depth-1;
  lpath[levelctr] = 1 /* for head */ + dk_set_length (current->xn_children) + 1 /* for element to be built */;
  while (levelctr--)
    {
      current = current->xn_parent;
      lpath[levelctr] = 1 /* for head */ + dk_set_length (current->xn_children);
    }
/* Save the result. */
  id_hash_set (dict, (caddr_t)(&boxed_name), (caddr_t)(&lpath));
}


void
xp_character (vxml_parser_t * parser,  char * s, int len)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) parser;
#if 0
  int inx;
  for (inx = 0; inx < len; inx++)
    session_buffered_write_char ((char) s[inx], xp->xp_strses);
#else
  session_buffered_write (xp->xp_strses, s, len);
#endif
}

void
xp_entity (vxml_parser_t * parser, const char * refname, int reflen, int isparam, const xml_def_4_entity_t *edef)
{
  char *uri;
  xparse_ctx_t *xp = (xparse_ctx_t *) parser;
  caddr_t head;
  XP_STRSES_FLUSH (xp);
  uri = ((NULL!=edef) ? edef->xd4e_systemId : NULL);
  head = ((NULL != uri) ?
      list (5,
	uname__ref,
	uname__bang_name,
	box_dv_short_nchars (refname, reflen),
	uname__bang_uri,
	box_dv_short_string (uri) )
      :
      list (3,
	uname__ref,
	uname__bang_name,
	box_dv_short_nchars (refname, reflen) )
      );
  dk_set_push (&xp->xp_current->xn_children, (void*)list (1, head));
  xp->xp_current->xn_n_children++;
  if (xp->xp_current->xn_n_children >= MAX_BOX_ELEMENTS)
    xn_error (xp->xp_current, "The number of children elements is over the limits");
}

void
xp_pi (vxml_parser_t * parser, const char *target, const char *data)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) parser;
  caddr_t head = (caddr_t) list (3,
    uname__pi,
    uname__bang_name,
    box_dv_short_string (target) );
  XP_STRSES_FLUSH (xp);
  dk_set_push (&xp->xp_current->xn_children,
    (void*)(
      (NULL != data) ?
      list (2, head, box_dv_short_string (data)) :
      list (1, head) ) );
  xp->xp_current->xn_n_children++;
  if (xp->xp_current->xn_n_children >= MAX_BOX_ELEMENTS)
    xn_error (xp->xp_current, "The number of children elements is over the limits");
}

void
xp_comment (vxml_parser_t * parser, const char *text)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) parser;
  XP_STRSES_FLUSH (xp);
  if ('\0' != text[0])
    dk_set_push (&xp->xp_current->xn_children, (void*)
      list (2,
	list (1, uname__comment),
	box_dv_short_string (text) ) );
  else
    dk_set_push (&xp->xp_current->xn_children, (void*)
      list (1, list (1, uname__comment)) );
  xp->xp_current->xn_n_children++;
  if (xp->xp_current->xn_n_children >= MAX_BOX_ELEMENTS)
    xn_error (xp->xp_current, "The number of children elements is over the limits");
}


void
xp_free (xparse_ctx_t * xp)
{
  dk_hash_iterator_t hit;
  caddr_t it, k;
  xp_node_t * xn;
  dk_free_box (xp->xp_id);
  dk_free_box (xp->xp_error_msg);
#ifdef XP_TRANSLATE_HOST
  dk_free_box (xp->xp_schema);
  dk_free_box (xp->xp_net_loc);
  dk_free_box (xp->xp_path);
#endif
  dk_set_free (xp->xp_checked_functions);

  strses_free (xp->xp_strses);
  xn = xp->xp_current;
  while (xn)
    {
      xp_node_t * next = xn->xn_parent;
#ifdef XTREE_DEBUG
      dk_check_tree ((caddr_t) xn->xn_attrs);
#endif
      dk_free_tree ((caddr_t) xn->xn_attrs);
      dk_free_tree ((caddr_t) list_to_array (xn->xn_children));
      dk_free ((caddr_t) xn, sizeof (xp_node_t));
      xn = next;
    }
  xn = xp->xp_free_list;
  while (xn)
    {
      xp_node_t * next = xn->xn_parent;
      dk_free ((caddr_t) xn, sizeof (xp_node_t));
      xn = next;
    }
  if (xp->xp_temps)
    {
      dk_hash_iterator (&hit, xp->xp_temps);
      while (dk_hit_next (&hit, (void**) &it, (void**) &k))
	dk_free_tree (it);
      hash_table_free (xp->xp_temps);
    }
  while (xp->xp_globals)
    {
      xqi_binding_t * xb = xp->xp_globals;
      dk_free_tree (xb->xb_value);
      xp->xp_globals = xb->xb_next;
      dk_free ((caddr_t) xb, sizeof (xqi_binding_t));
    }
  while (xp->xp_locals)
    {
      xqi_binding_t * xb = xp->xp_locals;
      dk_free_tree (xb->xb_value);
      xp->xp_locals = xb->xb_next;
      dk_free ((caddr_t) xb, sizeof (xqi_binding_t));
    }
  while (xp->xp_prepared_parameters)
    {
      xqi_binding_t * xb = xp->xp_prepared_parameters;
      dk_free_tree (xb->xb_value);
      xp->xp_prepared_parameters = xb->xb_next;
      dk_free ((caddr_t) xb, sizeof (xqi_binding_t));
    }
  if (xp->xp_namespaces)
    {
      id_hash_iterator_t iter;
      caddr_t * tag;
      caddr_t * nss;
      for (id_hash_iterator (&iter, xp->xp_namespaces);
	   hit_next (&iter, (caddr_t *) &tag, (caddr_t *) &nss);
	   /* */)
	{
	  dk_free_tree (nss[0]);
	}
      id_hash_free (xp->xp_namespaces);
    }

  dk_free_box (xp->xp_keys);
  dk_free_box (xp->xp_boxed_name);
  if ((NULL != xp->xp_doc_cache) && (&(xp->xp_doc_cache) == xp->xp_doc_cache->xdc_owner))
    xml_doc_cache_free (xp->xp_doc_cache);
  dk_free_box (xp->xp_top_excl_res_prefx);
  if (NULL != xp->xp_tf)
    xp_free_rdf_parser_fields (xp);
}


caddr_t
xml_make_tree (query_instance_t * qi, caddr_t text, caddr_t *err_ret, const char *enc, lang_handler_t *lh, struct dtd_s **ret_dtd)
{
  int dtp_of_text = box_tag(text);
  int text_strg_is_wide = 0;
  dk_set_t top;
  caddr_t tree;
  vxml_parser_config_t config;
  vxml_parser_t * parser;
  xparse_ctx_t context;
  volatile s_size_t text_len = 0;
  int rc;
  bh_from_client_fwd_iter_t bcfi;
  bh_from_disk_fwd_iter_t bdfi;
  dk_session_fwd_iter_t dsfi;
  xml_read_func_t iter = NULL;
  xml_read_abend_func_t iter_abend = NULL;
  void *iter_data = NULL;
  xp_node_t *xn;
  if (DV_BLOB_XPER_HANDLE == dtp_of_text)
    sqlr_new_error ("42000", "XM013", "Unable to create XML tree from persistent XML object");
  if ((DV_BLOB_HANDLE == dtp_of_text) || (DV_BLOB_WIDE_HANDLE == dtp_of_text))
    {
      blob_handle_t *bh = (blob_handle_t *) text;
      text_strg_is_wide = ((DV_BLOB_WIDE_HANDLE == dtp_of_text) ? 1 : 0);
      if (bh->bh_ask_from_client)
        {
          bcfi_reset (&bcfi, bh, qi->qi_client);
          iter = bcfi_read;
          iter_abend = bcfi_abend;
          iter_data = &bcfi;
	  goto make_tree;
        }
      bdfi_reset (&bdfi, bh, qi);
      iter = bdfi_read;
      iter_data = &bdfi;
      goto make_tree;
    }
  if (DV_STRING_SESSION == dtp_of_text)
    {
      dk_session_t *ses = (dk_session_t *) text;
      dsfi_reset (&dsfi, ses);
      iter = dsfi_read;
      iter_data = &dsfi;
      goto make_tree;
    }
   if (IS_WIDE_STRING_DTP (dtp_of_text))
    {
      text_len = (s_size_t) (box_length(text)-sizeof(wchar_t));
      text_strg_is_wide = 1;
      goto make_tree;
    }
  if (IS_STRING_DTP (dtp_of_text))
    {
      text_len = (s_size_t) (box_length(text)-1);
      goto make_tree;
    }
  sqlr_new_error ("42000", "XM016",
      "Unable to create XML tree from data of type %s (%d)", dv_type_title (dtp_of_text), dtp_of_text);
make_tree:
  xn = (xp_node_t *) dk_alloc (sizeof (xp_node_t));
  memset (xn, 0, sizeof(xp_node_t));
  memset (&context, 0, sizeof (context));
  context.xp_current = xn;
  xn->xn_xp = &context;
  context.xp_strses = strses_allocate ();
  context.xp_top = xn;
  context.xp_namespaces_are_valid = 1;
  memset (&config, 0, sizeof(config));
  config.input_is_wide = text_strg_is_wide;
  config.input_is_html = 0;
  config.user_encoding_handler = intl_find_user_charset;
  config.initial_src_enc_name = enc;
  config.uri_resolver = (VXmlUriResolver)(xml_uri_resolve_like_get);
  config.uri_reader = (VXmlUriReader)(xml_uri_get);
  config.uri_appdata = qi; /* Both xml_uri_resolve_like_get and xml_uri_get uses qi as first argument */
  config.error_reporter = (VXmlErrorReporter)(sqlr_error);
  config.uri = uname___empty;
  config.root_lang_handler = lh;
  parser = VXmlParserCreate (&config);
  context.xp_parser = parser;
  VXmlSetUserData (parser, &context);

/* !!! FixMe!!! Edit xslt.c in order to process attributes inside preparing the sheet! Not here! */
#if 1
  VXmlSetElementHandler (parser, (VXmlStartElementHandler) xp_xslt_element, xp_xslt_element_end);
#else
  VXmlSetElementHandler (parser, (VXmlStartElementHandler) xp_element, xp_element_end);
#endif
  VXmlSetIdHandler (parser, (VXmlIdHandler)xp_id);
  VXmlSetCharacterDataHandler (parser, (VXmlCharacterDataHandler) xp_character);
  VXmlSetEntityRefHandler (parser, (VXmlEntityRefHandler) xp_entity);
  VXmlSetProcessingInstructionHandler (parser, (VXmlProcessingInstructionHandler) xp_pi);
  VXmlSetCommentHandler (parser, (VXmlCommentHandler) xp_comment);
  if (NULL != iter)
    {
      VXmlParserInput (parser, iter, iter_data);
    }
  QR_RESET_CTX
    {
      if (0 == setjmp (context.xp_error_ctx))
        rc = VXmlParse (parser, text, text_len);
      else
	rc = 0;
    }
  QR_RESET_CODE
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      POP_QR_RESET;
      xp_free (&context);
      VXmlParserDestroy (parser);
      if (NULL != iter_abend)
        iter_abend (iter_data);
      if (err_ret)
	*err_ret = err;
      else
	dk_free_tree (err);
      return NULL;
    }
  END_QR_RESET;
  if (!rc)
    {
      caddr_t rc_msg = VXmlFullErrorMessage (parser);
      xp_free (&context);
      VXmlParserDestroy (parser);
      if (NULL != iter_abend)
        iter_abend (iter_data);
      if (err_ret)
	*err_ret = srv_make_new_error ("22007", "XM001", "%.1500s", rc_msg);
      dk_free_box (rc_msg);
      return NULL;
    }
  XP_STRSES_FLUSH (&context);
  if (NULL != ret_dtd)
    {
      ret_dtd[0] = VXmlGetDtd(parser);
      dtd_addref (ret_dtd[0], 0);
    }
  VXmlParserDestroy (parser);
  top = dk_set_nreverse (xn->xn_children);
  dk_set_push (&top, (void*) list (1, uname__root));
  tree = (caddr_t) list_to_array (top);
  xn->xn_children = NULL;
  xp_free (&context);
  return tree;
}


caddr_t
xml_make_tree_with_ns (query_instance_t * qi, caddr_t text, caddr_t *err_ret, const char *enc, lang_handler_t *lh, id_hash_t ** nss, id_hash_t ** id_cache)
{
  int dtp_of_text = box_tag(text);
  int text_strg_is_wide = 0;
  dk_set_t top;
  caddr_t tree;
  struct dtd_s * dtd;
  vxml_parser_config_t config;
  vxml_parser_t * parser;
  xparse_ctx_t context;
  volatile s_size_t text_len = 0;
  int rc;
  bh_from_client_fwd_iter_t bcfi;
  bh_from_disk_fwd_iter_t bdfi;
  dk_session_fwd_iter_t dsfi;
  xml_read_func_t iter = NULL;
  xml_read_abend_func_t iter_abend = NULL;
  void *iter_data = NULL;
  xp_node_t *xn;
  xml_tree_ent_t * xte;
  if (DV_BLOB_XPER_HANDLE == dtp_of_text)
    sqlr_new_error ("42000", "XM017", "Unable to create XML tree from persistent XML object");
  if ((DV_BLOB_HANDLE == dtp_of_text) || (DV_BLOB_WIDE_HANDLE == dtp_of_text))
    {
      blob_handle_t *bh = (blob_handle_t *) text;
      text_strg_is_wide = ((DV_BLOB_WIDE_HANDLE == dtp_of_text) ? 1 : 0);
      if (bh->bh_ask_from_client)
        {
          bcfi_reset (&bcfi, bh, qi->qi_client);
          iter = bcfi_read;
          iter_abend = bcfi_abend;
          iter_data = &bcfi;
	  goto make_tree;
        }
      bdfi_reset (&bdfi, bh, qi);
      iter = bdfi_read;
      iter_data = &bdfi;
      goto make_tree;
    }
  if (DV_STRING_SESSION == dtp_of_text)
    {
      dk_session_t *ses = (dk_session_t *) text;
      dsfi_reset (&dsfi, ses);
      iter = dsfi_read;
      iter_data = &dsfi;
      goto make_tree;
    }
   if (IS_WIDE_STRING_DTP (dtp_of_text))
    {
      text_len = (s_size_t) (box_length(text)-sizeof(wchar_t));
      text_strg_is_wide = 1;
      goto make_tree;
    }
  if (IS_STRING_DTP (dtp_of_text))
    {
      text_len = (s_size_t) (box_length(text)-1);
      goto make_tree;
    }
  sqlr_new_error ("42000", "XM020",
      "Unable to create XML tree from data of type %s (%d)", dv_type_title (dtp_of_text), dtp_of_text);
make_tree:
  xn = (xp_node_t *) dk_alloc (sizeof (xp_node_t));
  memset (xn, 0, sizeof(xp_node_t));
  memset (&context, 0, sizeof (context));
  context.xp_current = xn;
  xn->xn_xp = &context;
  context.xp_strses = strses_allocate ();
  context.xp_top = xn;
  context.xp_namespaces = id_hash_allocate (31, sizeof (caddr_t*), sizeof (caddr_t*),
	voidptrhash, voidptrhashcmp);
  context.xp_namespaces_are_valid = 1;

  memset (&config, 0, sizeof(config));
  config.input_is_wide = text_strg_is_wide;
  config.input_is_html = 0;
  config.user_encoding_handler = intl_find_user_charset;
  config.initial_src_enc_name = enc;
  config.uri_resolver = (VXmlUriResolver)(xml_uri_resolve_like_get);
  config.uri_reader = (VXmlUriReader)(xml_uri_get);
  config.uri_appdata = qi; /* Both xml_uri_resolve_like_get and xml_uri_get uses qi as first argument */
  config.error_reporter = (VXmlErrorReporter)(sqlr_error);
  config.uri = uname___empty;
  config.root_lang_handler = lh;
  parser = VXmlParserCreate (&config);
  parser->fill_ns_2dict = 1;
  context.xp_parser = parser;
  VXmlSetUserData (parser, &context);

/* !!! FixMe!!! Edit xslt.c in order to process attributes inside preparing the sheet! Not here! */
#if 1
  VXmlSetElementHandler (parser, (VXmlStartElementHandler) xp_xslt_element, xp_xslt_element_end);
#else
  VXmlSetElementHandler (parser, (VXmlStartElementHandler) xp_element, xp_element_end);
#endif
  if (id_cache)
    VXmlSetIdHandler (parser, (VXmlIdHandler)xp_id);
  VXmlSetCharacterDataHandler (parser, (VXmlCharacterDataHandler) xp_character);
  VXmlSetEntityRefHandler (parser, (VXmlEntityRefHandler) xp_entity);
  VXmlSetProcessingInstructionHandler (parser, (VXmlProcessingInstructionHandler) xp_pi);
  VXmlSetCommentHandler (parser, (VXmlCommentHandler) xp_comment);
  if (NULL != iter)
    {
      VXmlParserInput (parser, iter, iter_data);
    }
  QR_RESET_CTX
    {
      if (0 == setjmp (context.xp_error_ctx))
        rc = VXmlParse (parser, text, text_len);
      else
	rc = 0;
    }
  QR_RESET_CODE
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      POP_QR_RESET;
      xp_free (&context);
      VXmlParserDestroy (parser);
      if (NULL != iter_abend)
        iter_abend (iter_data);
      if (err_ret)
	*err_ret = err;
      else
	dk_free_tree (err);
      return NULL;
    }
  END_QR_RESET;
  if (!rc)
    {
      caddr_t rc_msg = VXmlFullErrorMessage (parser);
      xp_free (&context);
      VXmlParserDestroy (parser);
      if (NULL != iter_abend)
        iter_abend (iter_data);
      if (err_ret)
	*err_ret = srv_make_new_error ("22007", "XM002", "%.1500s", rc_msg);
      dk_free_box (rc_msg);
      return NULL;
    }
  XP_STRSES_FLUSH (&context);
  if (context.xp_namespaces)
    {
      if (nss)
	{
	  nss[0] = context.xp_namespaces;
	  context.xp_namespaces = 0;
	}
    }
  if (id_cache)
    id_cache[0] = context.xp_id_dict;
  dtd = VXmlGetDtd(parser);
  dtd_addref (dtd, 0);
  top = dk_set_nreverse (xn->xn_children);
  dk_set_push (&top, (void*) list (1, uname__root));
  tree = (caddr_t) list_to_array (top);
  xn->xn_children = NULL;
  xp_free (&context);
  xte = xte_from_tree (tree, qi);
  xte->xe_doc.xd->xd_uri = box_dv_short_string ("{not specified}");
  xte->xe_doc.xd->xd_dtd = dtd; /* The refcounter is incremented inside xml_make_tree */
  xte->xe_doc.xd->xd_id_dict = NULL;
  xte->xe_doc.xd->xd_id_scan = XD_ID_SCAN_COMPLETED;
  xte->xe_doc.xd->xd_ns_2dict = parser->ns_2dict;
  parser->ns_2dict.xn2_size = 0;	/* This prevents parser->ns_2dict from being freed by VXmlParserDestroy() */
  VXmlParserDestroy (parser);
  /* test only : xte_word_range(xte,&l1,&l2); */
  return ((caddr_t) xte);
}

typedef struct sqlgetdata_fwd_iter_s {
   SQLHSTMT sgdfi_hstmt;
   SQLUSMALLINT sgdfi_inx;
   SQLSMALLINT sgdfi_c_type;
 } sqlgetdata_fwd_iter_t;


static int
xml_get_ids_recurse (caddr_t *tree, dk_set_t *ids, caddr_t *err_ret)
{
  dtp_t tree_type = DV_TYPE_OF (tree);
  caddr_t *attrs = NULL;
  caddr_t id = NULL;
  int id_inx, child_inx, n_hrefs = 0;

  if (IS_STRING_DTP (tree_type))
    return 0;

  attrs = (caddr_t *)((caddr_t *)tree)[0];
  DO_BOX (char *, attr, id_inx, attrs)
    {
      if (id_inx > 0 && (id_inx - 1) % 2 == 0 && (id_inx + 1) < (int) BOX_ELEMENTS (attrs))
	{
	  if (!strcmp (attr, "id") || !strcmp (attr, SOAP_ENC_SCHEMA12 ":id"))
	    {
	      dk_set_push (ids, box_copy_tree ((box_t) tree));
	      dk_set_push (ids, box_copy (attrs[id_inx + 1]));
	      id = attrs[id_inx + 1];
	    }
	  else if (!strcmp (attr, "href") || !strcmp (attr, SOAP_ENC_SCHEMA12 ":ref"))
	    {
	      if (id != NULL)
		{
		  caddr_t value = attrs[id_inx + 1];

		  if (value[0] == '#')
		    value++;

		  if (!strcmp (value, id) && !*err_ret)
		    {
		          *err_ret = srv_make_new_error ("22023",
			      "A ref attribute item and an id item on the same element", "SR363");
		    }
		}
	      n_hrefs++;
	    }
	}
    }
  END_DO_BOX;

  DO_BOX (caddr_t, child, child_inx, tree)
    {
      if (child_inx > 0)
	n_hrefs += xml_get_ids_recurse ((caddr_t *)child, ids, err_ret);
    }
  END_DO_BOX;
  return n_hrefs;
}


static void
xml_expand_refs_recurse (caddr_t *tree, dk_set_t *ids, caddr_t *err_ret)
{
  dtp_t tree_type = 0, child_type = DV_TYPE_OF (tree);
  caddr_t *attrs = NULL;

  int href_inx, child_inx;

  if (IS_STRING_DTP (tree_type))
    return;

  DO_BOX (caddr_t *, child, child_inx, tree)
    {
      if (child_inx > 0)
	{
	  child_type = DV_TYPE_OF (child);
	  if (!IS_STRING_DTP (child_type))
	    {
	      attrs = (caddr_t *) child[0];

	      DO_BOX (char *, attr, href_inx, attrs)
		{
		  if (href_inx > 0 && (href_inx - 1) % 2 == 0 && (href_inx + 1) < (int) BOX_ELEMENTS (attrs))
		    {
		      if (!strcmp (attr, "href") || !strcmp (attr, SOAP_ENC_SCHEMA12 ":ref"))
			break;
		    }
		}
	      END_DO_BOX;
	      if (href_inx + 1 < (int) BOX_ELEMENTS (attrs))
		{
		  s_node_t *iter, *nxt;
		  char * value = (char *)((caddr_t *)attrs)[href_inx + 1];
		  int val_inx, found = 0;
		  if (value[0] == '#')
		    value++;

		  val_inx = 0;
		  DO_SET_WRITABLE2 (char *, id, iter, nxt, ids)
		    {
		      if (val_inx % 2 == 0 && nxt && nxt->data && !strcmp (value, id))
			{

			  int old_child_len = BOX_ELEMENTS (tree[child_inx]);
			  int new_child_len = BOX_ELEMENTS (nxt->data);
			  int new_attr_len = BOX_ELEMENTS (((caddr_t *)nxt->data)[0]);
			  int inx, new_tree_pos = 0, new_attr_pos = 0;
			  caddr_t *new_tree = (caddr_t *)
			      dk_alloc_box_zero (
				  (old_child_len + new_child_len - 1) * sizeof (caddr_t),
				  DV_ARRAY_OF_POINTER);
			  caddr_t *new_attrs = (caddr_t *)
			      dk_alloc_box_zero ((new_attr_len - 2) * sizeof (caddr_t),
			      DV_ARRAY_OF_POINTER);

			  new_attrs[new_attr_pos++] = box_copy_tree (((caddr_t **)tree[child_inx])[0][0]);

			  for (inx = 1; inx < new_attr_len; inx++)
			    {
			      caddr_t child_attr = ((caddr_t **)nxt->data)[0][inx];
			      if ((inx - 1) % 2 == 0 && inx + 1 < new_attr_len &&
				  (!strcmp ("id", child_attr) || !strcmp (child_attr, SOAP_ENC_SCHEMA12 ":id"))
				   )
				inx += 1;
			      else
				new_attrs[new_attr_pos++] = box_copy_tree (((caddr_t **)nxt->data)[0][inx]);
			    }
			  new_tree[new_tree_pos++] = (caddr_t)(new_attrs);

			  for (inx = 1; inx < new_child_len; inx++)
			    new_tree[new_tree_pos++] = box_copy_tree (((caddr_t *)nxt->data)[inx]);
			  for (inx = 1; inx < old_child_len; inx++)
			    {
			      new_tree[new_tree_pos++] = ((caddr_t *)tree[child_inx])[inx];
			      ((caddr_t *)tree[child_inx])[inx] = NULL;
			    }
			  xml_expand_refs_recurse (new_tree, ids, err_ret);
			  dk_free_tree (tree[child_inx]);
			  tree[child_inx] = (caddr_t)(new_tree);
			  found = 1;
			  break;
			}
		      val_inx++;
		    }
		  END_DO_SET ();
		  if (!found)
		    {
		      if (!*err_ret)
			{
		          *err_ret = srv_make_new_error ("22023",
			      "Missing reference in source XML tree", "SR362");
			}
		    }
		}
	      else
		{
		  xml_expand_refs_recurse (child, ids, err_ret);
		}
	    }
	}
    }
  END_DO_BOX;
}


void
xml_expand_refs (caddr_t *tree, caddr_t *err_ret)
{
  dk_set_t ids_set = NULL;
  int n_refs;

  if (!tree)
    return;
  n_refs = xml_get_ids_recurse ((caddr_t *) tree, &ids_set, err_ret);
  if (n_refs)
    {
      xml_expand_refs_recurse ((caddr_t *) tree, &ids_set, err_ret);
    }
  dk_free_tree ((caddr_t)(list_to_array (ids_set)));
}

/* html modifications of tree */
#if 0
caddr_t
full_to_relative (caddr_t src, caddr_t base)
{
  int inx, b_len, b_sl;
  char tmp [1000];
  b_len = box_length (base);
  memset (tmp, '\x0', sizeof (tmp));
  b_sl = 0;
  for (inx = 0; inx < b_len; inx++)
    if (base [inx] == '/')
      {
	if (inx > 0)
	  strcat_ck (tmp, "../");
	b_sl ++;
      }
  if (b_sl == 1)
    strcpy_ck (tmp, src);
  else
    strcat_ck (tmp, src);
  return box_dv_short_string (tmp);
}
#else
/*! \brief Converts local (host-range) URI \c src into relative RFC-1808 URI, using \c base as an "link origin"
*/

caddr_t
local_to_relative (char *src, caddr_t base)
{
  char res_auto_buf[500];
  size_t src_len = strlen (src);
  int base_len = box_length(base)-1;
  size_t max_res_len = 2 * (src_len + base_len + 10);
  char *res_buf = (char *) ((max_res_len > sizeof (res_auto_buf)) ? dk_alloc (max_res_len) : res_auto_buf);
  size_t res_buf_len = (max_res_len > sizeof (res_auto_buf)) ? max_res_len : sizeof (res_auto_buf);
  char *src_tail, *base_tail, *res_tail, *src_active_end, *tmp;
  caddr_t ret_val;
  src_tail = src;
  base_tail = base;
  res_tail = res_buf;
  /* First of all, not the whole \c src should be processed: query and anchor should not. */
  src_active_end = src + src_len;
  tmp = (char *) memchr (src, '?', src_len);
  if (NULL != tmp)
    src_active_end = tmp;
  tmp = (char *) memchr (src, '#', src_active_end - src);
  if (NULL != tmp)
    src_active_end = tmp;
  if (src == src_active_end) /* The string consists of query and/or anchor, solely */
    {
      strcpy_size_ck (res_buf, src, res_buf_len);
      goto res_buf_done;
    }
  if ('/' == src_tail[0])
    { /* Case of local URI that starts from the root of the network location */
      /* First loop should find the deepest common root */
      for (;;)
	{
	  char *src_dir_name_end = (char *) memchr (src_tail+1, '/', src_active_end - (src_tail+1));
	  if (NULL == src_dir_name_end)
	    break;
	  if (memcmp (src_tail, base_tail, src_dir_name_end - src_tail))
	    break;
	  base_tail = base_tail + (src_dir_name_end - src_tail) - 1;
	  src_tail = src_dir_name_end;
	}
      /* Second loop should add an appropriate number of .. - s in front of the \c res_buf */
      for (;;)
	{
	  char *base_dir_name_end = strchr (base_tail+1, '/');
	  if (NULL == base_dir_name_end)
	    break;
	  memcpy (res_tail, "../", 3);
	  res_tail += 3;
	  base_tail = base_dir_name_end;
	}
      /* The final concatenation */
      strcpy_size_ck (res_tail, (('/' == src_tail[0]) ? src_tail+1 : src_tail), res_buf_len - (res_tail - res_buf));
    }
  else
    { /* Case of local URI that starts from \c base */
      strcpy_size_ck (res_tail, src_tail, res_buf_len - (res_tail - res_buf));
    }
  /* completion */
res_buf_done:
  ret_val = box_dv_short_string (res_buf);
  if (res_buf != res_auto_buf)
    dk_free (res_buf, max_res_len);
  return ret_val;
}
#endif


#ifdef XP_TRANSLATE_HOST
static int
att_is_uri (char * name)
{
  int inx, uri_len;
  char * uri[] = {"href", "src", "longdesc", "classid", "codebase", "data", "archive", "usemap",
		"cite", "action", "profile", "for", "datasrc", '\x0'};
  uri_len = sizeof (uri);
  for (inx = 0; uri [inx]; inx++)
    {
       if (0 == strnicmp (name, uri [inx], strlen (uri [inx])))
	 return 1;
    }
  return 0;
}
#endif


void
str_lcase (char *str)
{
  while (*str)
    {
      char c = *str;
      if (c >= 'A' && c <= 'Z')
	*str += 32;
      str++;
    }
}


caddr_t
box_lcase (char *str)
{
  caddr_t s = box_dv_short_string (str);
  str_lcase (s);
  return s;
}

void
xn_box_attrs_change (xp_node_t * xn, caddr_t name, vxml_parser_attrdata_t *attrdata)
{
  int fill, n_attrs = attrdata->local_attrs_count, n_ns = attrdata->local_nsdecls_count;
  caddr_t * box;
  caddr_t * save_ns;
  caddr_t tmp;
  caddr_t nsname;
#ifdef XP_TRANSLATE_HOST
  caddr_t schema = xn->xn_xp->xp_schema;
  caddr_t net_loc = xn->xn_xp->xp_net_loc;
  int translate_uris = (net_loc != NULL);
  caddr_t path = xn->xn_xp->xp_path;
#endif
  int inx;

  if (n_ns)
    {
      save_ns = xn->xn_namespaces = (caddr_t*) dk_alloc_box (2 * n_ns * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      fill = 0;
      for (inx = 0; inx < n_ns; inx++)
        {
          save_ns[fill++] = box_dv_uname_string (attrdata->local_nsdecls[inx].nsd_prefix);
          save_ns[fill++] = box_dv_uname_string (attrdata->local_nsdecls[inx].nsd_uri);
        }
    }
  else
    save_ns = xn->xn_namespaces = NULL;
  fill = 0;
  box = (caddr_t *) dk_alloc_box (((n_attrs + ((NULL != save_ns) ? 1 : 0)) * 2 + 1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  nsname = xn_ns_name (xn, name, 1);
  if (NULL == nsname)
    {
      if (xn_source_is_dead(xn))
	nsname = box_dv_uname_string (name);
      else
	xn_error (xn, "Tag name contains undefined namespace prefix");
    }
  box[0] = nsname;
  for (inx = 0; inx < n_attrs; inx++)
    {
	  char *name = attrdata->local_attrs[inx].ta_raw_name.lm_memblock;
	  caddr_t *value_ptr = &(attrdata->local_attrs[inx].ta_value);
	  caddr_t value = value_ptr[0];
	  str_lcase (name);
	  nsname = xn_ns_name (xn, name, 0);
	  if (NULL == nsname)
	    {
	      if (xn_source_is_dead(xn))
		nsname = box_dv_uname_string (name);
	      else
		xn_error (xn, "Attribute name contains undefined namespace prefix");
	    }
	  box[fill + 1] = nsname;
	  tmp = box[fill + 1];
#ifdef XP_TRANSLATE_HOST
	  if (!translate_uris || !att_is_uri (tmp))
	    box[fill + 2] = box_dv_short_string (value);
	  else
	    {
	      size_t schema_len = box_length (schema) - 1;
	      size_t net_loc_len = box_length (net_loc) - 1;

#define IS_NET_LOC_MATCHES(strg) \
  ( !strncmp ((strg), net_loc, net_loc_len) && \
   (('/' == (strg)[net_loc_len]) || ('\0' == (strg)[net_loc_len])) )

	      tmp = value;
	      if (tmp[0] == '/')
		{
		  if (tmp[1] == '/') /* '//' indicates relative URI with new network address */
		    {
		      if (IS_NET_LOC_MATCHES(tmp + 2))
			box[fill + 2] = local_to_relative (tmp + 2 + net_loc_len, path);
		      else
			{
			  box[fill + 2] = dk_alloc_box ((strlen(tmp) - 2) + schema_len + 1, DV_STRING);
			  memcpy (box[fill + 2], schema, schema_len);
			  strcpy_size_ck (box[fill + 2] + schema_len, tmp + 2,
			      box_length (box[fill + 2]) - schema_len);
			}
		    }
		  else /* '/' indicates relative URI inside the host, from the root */
		    box[fill + 2] = local_to_relative (tmp, path);
		}
	      else if (tmp[0] == '.') /* '.' or '..' */
		box[fill + 2] = local_to_relative (tmp, path);
	      else if (
		(0 == strncasecmp (tmp, schema, schema_len)) && IS_NET_LOC_MATCHES(tmp+schema_len) )
		box[fill + 2] = local_to_relative (tmp+schema_len + net_loc_len, path);
	      else
		{
		  box[fill + 2] = value;
		  value_ptr[0] = NULL;
		}
	    }
#else
	    box[fill + 2] = value;
	    value_ptr[0] = NULL;
#endif
	  fill += 2;
    }
  if (NULL != save_ns)
    {
      box [++fill] = uname__bang_ns;
      box [++fill] = (caddr_t)save_ns;
    }
  xn->xn_attrs = box;
}


void
xp_element_change (void *userdata, char * name, vxml_parser_attrdata_t *attrdata)
{
  xparse_ctx_t * xp = (xparse_ctx_t*) userdata;
  caddr_t boxed_name;
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
  boxed_name = xp->xp_boxed_name = box_dv_uname_string (name);
  xn_box_attrs_change (xn, boxed_name, attrdata);
  dk_free_box (boxed_name);
  xp->xp_boxed_name = NULL;
}
/* URI is the current uri on host */

int
xml_set_xml_read_iter (query_instance_t * qi, caddr_t text, xml_read_iter_env_t *xrie, const char **enc_ret)
{
  int dtp_of_text = box_tag (text);
  if ((DV_BLOB_HANDLE == dtp_of_text) || (DV_BLOB_WIDE_HANDLE == dtp_of_text))
    {
      blob_handle_t *bh = (blob_handle_t *) text;
      if (bh->bh_ask_from_client)
        {
          bcfi_reset (&(xrie->xrie_bcfi), bh, qi->qi_client);
          xrie->xrie_iter = bcfi_read;
          xrie->xrie_iter_abend = bcfi_abend;
          xrie->xrie_iter_data = &(xrie->xrie_bcfi);
	  if (DV_BLOB_WIDE_HANDLE == dtp_of_text)
	    enc_ret[0] = "UTF-8"; /* the bh_get_data_from_user() does not get wchar_t *, it's UTF-8 */
	  return 1;
        }
      else
        {
	  /* There's no support of double encoding like UTF-8 -ed KOI.
	    Hence LONG NVARCHAR disk iterator should convert such data to wide and use wide versions of narrow encodings */
          xrie->xrie_text_is_wide = ((DV_BLOB_WIDE_HANDLE == dtp_of_text) ? 1 : 0);
        }
      bdfi_reset (&(xrie->xrie_bdfi), bh, qi);
      xrie->xrie_iter = bdfi_read;
      xrie->xrie_iter_data = &(xrie->xrie_bdfi);
      return 1;
    }
  if (DV_STRING_SESSION == dtp_of_text)
    {
      dk_session_t *ses = (dk_session_t *) text;
      dsfi_reset (&(xrie->xrie_dsfi), ses);
      xrie->xrie_iter = dsfi_read;
      xrie->xrie_iter_data = &(xrie->xrie_dsfi);
      return 1;
    }
   if (IS_WIDE_STRING_DTP (dtp_of_text))
    {
      xrie->xrie_text_len = (s_size_t) (box_length(text)-sizeof(wchar_t));
      xrie->xrie_text_is_wide = 1;
      return 1;
    }
  if (IS_STRING_DTP (dtp_of_text))
    {
      xrie->xrie_text_len = (s_size_t) (box_length(text)-1);
      return 1;
    }
  if (dtp_of_text == DV_BIN)
    {
      xrie->xrie_text_len = (s_size_t) box_length(text);
      return 1;
    }
  return 0;
}

caddr_t
xml_make_mod_tree (query_instance_t * qi, caddr_t text, caddr_t *err_ret, long html_mode, caddr_t uri, const char *enc, lang_handler_t *lh, caddr_t dtd_config, dtd_t **ret_dtd, id_hash_t **ret_id_cache, xml_ns_2dict_t *ret_ns_2dict)
{
  int dtp_of_text = box_tag (text);
  dk_set_t top;
  caddr_t *root_elt_head, tree;
  vxml_parser_config_t config;
  vxml_parser_t * parser;
  xparse_ctx_t context;
  int rc;
  xp_node_t *xn;
  xml_read_iter_env_t xrie;
  memset (&xrie, 0, sizeof (xml_read_iter_env_t));
  if (DV_BLOB_XPER_HANDLE == dtp_of_text)
    sqlr_new_error ("42000", "XM021", "Unable to create XML tree from persistent XML object");
  if (!xml_set_xml_read_iter (qi, text, &xrie, &enc))
    sqlr_new_error ("42000", "XM024",
      "Unable to create XML tree from data of type %s (%d)", dv_type_title (dtp_of_text), dtp_of_text);
  xn = (xp_node_t *) dk_alloc (sizeof (xp_node_t));
  memset (xn, 0, sizeof(xp_node_t));
  memset (&context, 0, sizeof (context));
  context.xp_current = xn;
  xn->xn_xp = &context;
  context.xp_strses = strses_allocate ();
  context.xp_top = xn;
#ifdef XP_TRANSLATE_HOST
  if ((html_mode & WEBIMPORT_HTML) && (uri != NULL))
    {
      char * slash, *tmp, *uri_path_end;
      if (strncasecmp (uri, "http://", 7))
	sqlr_new_error("42000", "HT077", "no http protocol identifier in URI");
      slash = strchr (uri + 7, '/');
      if (!slash)
	slash = uri + strlen (uri);
      context.xp_schema = box_dv_short_nchars (uri, 7);
      context.xp_net_loc = box_dv_short_nchars (uri + 7, slash - (uri + 7));

      uri_path_end = uri + strlen (uri);
      tmp = (char *) memchr (uri, '?', uri_path_end - uri);
      if (NULL != tmp)
	uri_path_end = tmp;
      tmp = (char *) memchr (uri, '#', uri_path_end - uri);
      if (NULL != tmp)
	uri_path_end = tmp;
      context.xp_path = (slash < uri_path_end) ? box_dv_short_nchars (slash, uri_path_end - slash) : box_dv_short_string("/");
    }
#endif
  html_mode &= ~WEBIMPORT_HTML;
  memset (&config, 0, sizeof(config));
  config.input_is_wide = xrie.xrie_text_is_wide;
  config.input_is_ge = html_mode & GE_XML;
  config.input_is_html = html_mode & ~(FINE_XSLT | GE_XML | WEBIMPORT_HTML | FINE_XML_SRCPOS);
  config.input_is_xslt = html_mode & FINE_XSLT;
  config.user_encoding_handler = intl_find_user_charset;
  config.initial_src_enc_name = enc;
  config.uri_resolver = (VXmlUriResolver)(xml_uri_resolve_like_get);
  config.uri_reader = (VXmlUriReader)(xml_uri_get);
  config.uri_appdata = qi; /* Both xml_uri_resolve_like_get and xml_uri_get uses qi as first argument */
  config.error_reporter = (VXmlErrorReporter)(sqlr_error);
  config.uri = ((NULL == uri) ? uname___empty : uri);
  config.dtd_config = dtd_config;
  config.root_lang_handler = lh;
  parser = VXmlParserCreate (&config);
  parser->fill_ns_2dict = (NULL != ret_ns_2dict);
  context.xp_parser = parser;
  VXmlSetUserData (parser, &context);
  switch (html_mode & ~GE_XML)
    {
    case FINE_XML:
/* !!! FixMe!!! Edit xslt.c in order to process attributes inside preparing the sheet! Not here! */
#if 1
      VXmlSetElementHandler (parser, (VXmlStartElementHandler) xp_xslt_element, xp_xslt_element_end);
#else
      VXmlSetElementHandler (parser, (VXmlStartElementHandler) xp_element, xp_element_end);
#endif
      break;
    case FINE_HTML:
    case DEAD_HTML:
      VXmlSetElementHandler (parser, (VXmlStartElementHandler) xp_element_change, xp_element_end);
      break;
    case FINE_XSLT:
      VXmlSetElementHandler (parser, (VXmlStartElementHandler) xp_xslt_element, xp_xslt_element_end);
      break;
    case FINE_XML_SRCPOS:
      VXmlSetElementHandler (parser, (VXmlStartElementHandler) xp_element_srcpos, xp_element_end);
      break;
    default:
      sqlr_new_error ("42000", "XM025", "Unsupported mode '%ld' specified for XML parser", (long)html_mode);
    }
  VXmlSetIdHandler (parser, (VXmlIdHandler)xp_id);
  VXmlSetCharacterDataHandler (parser, (VXmlCharacterDataHandler) xp_character);
  VXmlSetEntityRefHandler (parser, (VXmlEntityRefHandler) xp_entity);
  VXmlSetProcessingInstructionHandler (parser, (VXmlProcessingInstructionHandler) xp_pi);
  VXmlSetCommentHandler (parser, (VXmlCommentHandler) xp_comment);
  if (NULL != xrie.xrie_iter)
    {
      VXmlParserInput (parser, xrie.xrie_iter, xrie.xrie_iter_data);
    }
  QR_RESET_CTX
    {
      if (0 == setjmp (context.xp_error_ctx))
        rc = VXmlParse (parser, text, xrie.xrie_text_len);
      else
	rc = 0;
    }
  QR_RESET_CODE
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      POP_QR_RESET;
      xp_free (&context);
      VXmlParserDestroy (parser);
      if (NULL != xrie.xrie_iter_abend)
        xrie.xrie_iter_abend (xrie.xrie_iter_data);
      if (err_ret)
	*err_ret = err;
      else
	dk_free_tree (err);
      return NULL;
    }
  END_QR_RESET;
  if (!rc)
    {
      caddr_t rc_msg = VXmlFullErrorMessage (parser);
      xp_free (&context);
      VXmlParserDestroy (parser);
      if (NULL != xrie.xrie_iter_abend)
        xrie.xrie_iter_abend (xrie.xrie_iter_data);
      if (err_ret)
	*err_ret = srv_make_new_error ("22007", "XM003", "%.1500s", rc_msg);
      dk_free_box (rc_msg);
      return NULL;
    }
  XP_STRSES_FLUSH (&context);
  if (NULL != ret_dtd)
    {
      ret_dtd[0] = VXmlGetDtd(parser);
      dtd_addref (ret_dtd[0], 0);
    }
  if (NULL != ret_id_cache)
    {
      ret_id_cache[0] = context.xp_id_dict;
      context.xp_id_dict = NULL;
    }
  if (NULL != ret_ns_2dict)
    {
      ret_ns_2dict[0] = parser->ns_2dict;
      parser->ns_2dict.xn2_size = 0;
    }
  VXmlParserDestroy (parser);
  top = dk_set_nreverse (xn->xn_children);
  if (NULL == context.xp_top_excl_res_prefx)
    root_elt_head = (void*) list (1, uname__root);
  else
    {
      root_elt_head = (void*) list (3, uname__root, uname__bang_exclude_result_prefixes, context.xp_top_excl_res_prefx);
      context.xp_top_excl_res_prefx = NULL;
    }
  dk_set_push (&top, root_elt_head);
  tree = (caddr_t) list_to_array (top);
  xn->xn_children = NULL;
  xp_free (&context);
  return tree;
}

#define XML_TREE_IMPL 0		/* make only a tree, not a tree document, for bif_xml_tree() */
#define XTREE_DOC_IMPL 1	/* make a tree document, not only the tree, for bif_xtree_doc() */
#define XTREE_DOC_VDB_IMPL 2	/* Like XTREE_DOC_IMPL but handle wide sources as required by VDB */

static caddr_t
_bif_xml_tree_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, int mode)
{
  static const char *bif_names[] = {"xml_tree", "xtree_doc", "xtree_doc_vdb"};
  const char *bif_name = bif_names[mode];
  caddr_t text_arg;
  dtp_t dtp_of_text_arg;
  int arg_is_wide = 0;
  char * volatile enc = NULL;
  lang_handler_t *volatile lh = server_default_lh;
  caddr_t volatile dtd_config = NULL;
  caddr_t volatile uri = NULL;
  caddr_t err = NULL;
  caddr_t volatile tree = NULL;
  xml_ns_2dict_t ns_2dict;
  long parser_mode = 0;
  dtd_t *dtd = NULL;
  dtd_t **dtd_ptr = ((XML_TREE_IMPL != mode) ? &dtd : NULL);
  id_hash_t *id_cache = NULL;
  id_hash_t **id_cache_ptr = ((XML_TREE_IMPL != mode) ? &id_cache : NULL);
  int n_args = BOX_ELEMENTS (args);
  wcharset_t * volatile charset = QST_CHARSET (qst) ? QST_CHARSET (qst) : default_charset;
  text_arg = bif_arg (qst, args, 0, bif_name);
  dtp_of_text_arg = DV_TYPE_OF (text_arg);
  ns_2dict.xn2_size = 0;
  do
    {
      if ((dtp_of_text_arg == DV_SHORT_STRING) ||
	  (dtp_of_text_arg == DV_LONG_STRING) ||
	  (dtp_of_text_arg == DV_C_STRING) ||
	  (dtp_of_text_arg == DV_BIN))
	{ /* Note DV_TIMESTAMP_OBJ is not enumerated in if(...), unlike bif_string_arg)_ */
	  break;
	}
      if (IS_WIDE_STRING_DTP (dtp_of_text_arg))
	{
	  arg_is_wide = 1;
	  break;
	}
      if (dtp_of_text_arg == DV_STRING_SESSION)
	{
	  int ses_sort = looks_like_serialized_xml (((query_instance_t *)(qst)), text_arg);
	  if (XE_XPER_SERIALIZATION == ses_sort)
	    sqlr_error ("42000",
	      "A string session with persistent XML data passed to function %s() as argument 1; try xml_persistent function instead", bif_name);
	  if (XE_XPACK_SERIALIZATION == ses_sort)
	    {
	      caddr_t *tree_tmp = NULL; /* Solely to avoid dummy warning C4090: 'function' : different 'volatile' qualifiers */
	      xte_deserialize_packed ((dk_session_t *)text_arg, &tree_tmp, dtd_ptr);
	      tree = (caddr_t)tree_tmp;
	      if (NULL != dtd)
	        dtd_addref (dtd, 0);
	      if ((NULL == tree) && (DEAD_HTML != (parser_mode & ~(FINE_XSLT | GE_XML | WEBIMPORT_HTML | FINE_XML_SRCPOS))))
		sqlr_error ("42000", "The BLOB passed to a function %s() contains corrupted packed XML serialization data", bif_name);
	      goto tree_complete; /* see below */
	    }
	  break;
	}
      if (dtp_of_text_arg == DV_BLOB_XPER_HANDLE)
	sqlr_new_error ("42000", "XM027",
	  "Persistent XML data passed to function %s() as argument 1; try xml_persistent function instead", bif_name);
      if ((DV_BLOB_HANDLE == dtp_of_text_arg) || (DV_BLOB_WIDE_HANDLE == dtp_of_text_arg))
	{
	  int blob_sort = looks_like_serialized_xml (((query_instance_t *)(qst)), text_arg);
	  if (XE_XPER_SERIALIZATION == blob_sort)
	    sqlr_error ("42000",
	      "A BLOB with persistent XML data passed to function %s() as argument 1; try xper_doc() function instead", bif_name);
	  if (XE_XPACK_SERIALIZATION == blob_sort)
	    {
	      caddr_t *tree_tmp = NULL; /* Solely to avoid dummy warning C4090: 'function' : different 'volatile' qualifiers */
	      dk_session_t *ses = blob_to_string_output (((query_instance_t *)(qst))->qi_trx, text_arg);
	      xte_deserialize_packed (ses, &tree_tmp, dtd_ptr);
	      tree = (caddr_t)tree_tmp;
	      if (NULL != dtd)
	        dtd_addref (dtd, 0);
	      strses_free (ses);
	      if ((NULL == tree) && (DEAD_HTML != (parser_mode & ~(FINE_XSLT | GE_XML | WEBIMPORT_HTML | FINE_XML_SRCPOS))))
		sqlr_error ("42000", "The BLOB passed to a function %s() contains corrupted packed XML serialization data", bif_name );
	      goto tree_complete; /* see below */
	    }
	  arg_is_wide = (DV_BLOB_WIDE_HANDLE == dtp_of_text_arg) ? 1 : 0;
	  break;
	}
      sqlr_error ("42000",
	"Function %s() needs a string or BLOB as argument 1, not an arg of type %s (%d)", bif_name,
	dv_type_title (dtp_of_text_arg), dtp_of_text_arg);
    } while (0);
  /* Now we have \c text ready to process */

  if (XTREE_DOC_VDB_IMPL == mode)
    enc = (arg_is_wide ? "!identity" : "!WIDE identity"); /* Note '!' in front of name to set parser->enc_flag to XML_EF_FORCE. */
  else if (n_args < 2)
    enc = CHARSET_NAME (charset, NULL);

  switch (n_args)
    {
    default:
    case 6:
      dtd_config = bif_array_or_null_arg (qst, args, 5, bif_name);
    case 5:
      lh = lh_get_handler (bif_string_arg (qst, args, 4, bif_name));
    case 4:
      enc = bif_string_arg (qst, args, 3, bif_name);
    case 3:
      uri = bif_string_arg (qst, args, 2, bif_name);
    case 2:
      parser_mode = (long) bif_long_arg (qst, args, 1, bif_name);
    case 1:
	  ;
    }
  tree = xml_make_mod_tree ((query_instance_t *)qst, text_arg, (caddr_t *) &err, parser_mode, uri, enc, lh, dtd_config, dtd_ptr, id_cache_ptr, &ns_2dict);
  if (NULL == tree)
    {
      if (DEAD_HTML != (parser_mode & ~(FINE_XSLT | GE_XML | WEBIMPORT_HTML | FINE_XML_SRCPOS)))
        sqlr_resignal (err);
      dk_free_tree (err);
    }

tree_complete:
  if (NULL == tree)
    return (NEW_DB_NULL);
  if (XML_TREE_IMPL != mode)
    {
      xml_tree_ent_t *xte = xte_from_tree (tree, (query_instance_t*) qst);
      xte->xe_doc.xd->xd_uri = box_copy_tree (uri);
      xte->xe_doc.xd->xd_dtd = dtd; /* The refcounter is incremented inside xml_make_tree */
      xte->xe_doc.xd->xd_id_dict = id_cache;
      xte->xe_doc.xd->xd_id_scan = XD_ID_SCAN_COMPLETED;
      xte->xe_doc.xd->xd_ns_2dict = ns_2dict;
      xte->xe_doc.xd->xd_namespaces_are_valid = 0;
      /* test only : xte_word_range(xte,&l1,&l2); */
      return ((caddr_t) xte);
    }
  else
    {
      xml_ns_2dict_clean (&ns_2dict);
      return tree;
    }
}


caddr_t
bif_xml_tree (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return _bif_xml_tree_impl(qst,err_ret,args, XML_TREE_IMPL);
}

caddr_t
bif_xtree_doc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return _bif_xml_tree_impl(qst,err_ret,args, XTREE_DOC_IMPL);
}

caddr_t
bif_xtree_doc_vdb (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return _bif_xml_tree_impl(qst,err_ret,args, XTREE_DOC_VDB_IMPL);
}


caddr_t
bif_xml_expand_refs (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t tree = box_copy_tree (bif_array_arg (qst, args, 0, "expand_refs"));
  caddr_t err = NULL;

  xml_expand_refs ((caddr_t *) tree, &err);
  if (err)
    sqlr_resignal (err);
  return tree;
}


caddr_t
xp_new_eid (xparse_ctx_t * xp)
{
  caddr_t id = bx_xml_eid (xp->xp_id, xp->xp_id_limit, 0);
  dk_free_box (xp->xp_id);
  xp->xp_id = box_copy (id);
  return id;
}


void
xp_insert_text (xparse_ctx_t * xp,  caddr_t text, int level,
	       caddr_t * err_ret)
{
  GPF_T;
}


xml_insert_qr_t *
tb_make_iq (dbe_table_t * tb, query_instance_t * qi)
{
  caddr_t err = NULL;
  if (tb->tb_xml_ins)
    return (tb->tb_xml_ins);

  {
    ptrlong mid, cid;
    dk_hash_iterator_t hit;
    char tail[1000];
    char text [4000];
    char tmp [4000];
    int fill = 0;
    oid_t * cols;
    NEW_VARZ (xml_insert_qr_t, iq);
    tail[0] = 0;
    cols = (oid_t*) dk_alloc_box (tb->tb_misc_id_to_col_id->ht_count * sizeof (ptrlong), DV_ARRAY_OF_LONG);
    snprintf (text, sizeof (text), "insert into \"%s\" (E_ID, E_LEVEL, E_NAME, E_MISC, E_WHITESPACE, E_LEADING, E_TRAILING ", tb->tb_name);
    dk_hash_iterator (&hit, tb->tb_misc_id_to_col_id);

    while (dk_hit_next (&hit, (void**) &mid, (void**)&cid))
      {
	dbe_column_t * col = sch_id_to_column (isp_schema (qi->qi_space), cid);
	cols[fill++] = mid;
	snprintf (tmp, sizeof (tmp), ", \"%s\" ", col->col_name);
	strcat_ck (text, tmp);
	strcat_ck (tail, ", ?");
      }
    snprintf (tmp, sizeof (tmp), ") values (?, ?, ?, ?, ?, ?, ? %s)", tail);
    strcat_ck (text, tmp);
    iq->iq_qr = sql_compile (text, qi->qi_client, &err, SQLC_DEFAULT);
    if (err)
      sqlr_resignal (err);
    iq->iq_cols = cols;
    tb->tb_xml_ins = iq;
    return iq;
  }
}




void
xp_insert_elt (xparse_ctx_t * xp,  caddr_t * tree, int level,
	       caddr_t * err_ret)
{
  GPF_T;
}


caddr_t
bif_xml_store_tree (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int inx;
  caddr_t err = NULL;
  caddr_t * tree = (caddr_t*) bif_array_arg (qst, args, 0, "xml_store_tree");
  caddr_t id1 = bif_bin_arg (qst, args, 1, "xml_store_tree");
  caddr_t id2 = bif_bin_arg (qst, args, 2, "xml_store_tree");
  long level = (long) bif_long_arg (qst, args, 3, "xml_store_tree");
  xparse_ctx_t xp;
  memset (&xp, 0, sizeof (xp));
  xp.xp_strses = strses_allocate ();
  xp.xp_qi = (query_instance_t *) qst;
  xp.xp_id = box_copy (id1);
  xp.xp_id_limit = id2;
  DO_BOX (caddr_t *, elt, inx, tree)
    {
      xp_insert_elt (&xp, elt, level, &err);
      if (err)
	break;
    }
  END_DO_BOX;
  xp_free (&xp);
  *err_ret = err;
  return 0;
}


/* Function used to return the value of a hex char */
/* Input : char - the hex character to convert     */
/* Output: char - the value or -1 if not a hex     */
char
bx_char_to_digit (char c)
{
  if ( c >= '0' && c <= '9' )
    return c - '0';
  if ( c >= 'a' && c <= 'f' )
    return 10 + c - 'a';
  if ( c >= 'A' && c <= 'F' )
    return 10 + c - 'a';

  return -1;
}

/* Function used to return the char of a hex digit */
/* Input : uint8 - the hex character to convert    */
/* Output: char  - the character		   */
char
bx_digit_to_char (unsigned char d)
{
  if ( d < 10 )
    return d + '0';
  return d - 10 + 'a';
}

/* Function used to convert a hex string to varbinary */
/* Input : caddr_t - the string to use		*/
/* Output: caddr_t - the varbinary		    */
caddr_t
bx_string_to_binary (caddr_t string)
{
  uint32 i, len = box_length(string) - 1;
  caddr_t bin = dk_alloc_box ((len >> 1) + (len & 0x1), DV_BIN);
  char c0, c1;

  if (len & 0x1)
    {
      c0 = bx_char_to_digit (string[0]);
      if (c0 != -1)
	bin[0] = c0;
      else
	{
	  dk_free_box (bin);
	  return dk_alloc_box (0, DV_DB_NULL);
	}
    }

  for (i = (len & 0x1) ? 1 : 0; i < len ; i+=2)
    {
      c0 = bx_char_to_digit (string[i]) ;
      c1 = bx_char_to_digit (string[i+1]);
      if (c0 != -1 && c1 != -1)
	bin[(i>>1) + (i & 0x1)] = (c0 << 4) | c1;
      else
	{
	  dk_free_box (bin);
	  return dk_alloc_box (0, DV_DB_NULL);
	}
    }

  return bin;
}


caddr_t
bif_row_vector (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return 0; /*dummy */
}


void
bx_out_dv (caddr_t * qst, dk_session_t * out, db_buf_t dv, wcharset_t *src_charset)
{
  dtp_t dtp = dv[0];
  if (DV_DB_NULL == dtp)
    {
      SES_PRINT (out, "NULL");
      return;
    }
  if (dtp == DV_SHORT_STRING || dtp == DV_LONG_STRING)
    {
      long hl, l;
      db_buf_length (dv, &hl, &l);
      dks_esc_write (out, (char *) (dv + hl), l, QST_CHARSET (qst), src_charset, DKS_ESC_PTEXT);
    }
  else if (DV_DB_NULL == dtp)
    {
      ;
    }
  else
    {
      caddr_t string, val;
      static caddr_t varchar = NULL;
      if (!varchar)
	varchar = (caddr_t) list (3, (ptrlong)DV_LONG_STRING, 0, 0);

      val = itc_box_column (NULL, NULL, 0, ((dbe_col_loc_t *)dv));
      string = box_cast (qst, val, (sql_tree_tmp*) varchar, (dtp_t) DV_TYPE_OF (val));
      dks_esc_write (out, string, box_length (string) - 1, QST_CHARSET (qst), src_charset, DKS_ESC_PTEXT);
      dk_free_tree (val);
      dk_free_box (string);
    }
}

void
bx_out_nsdecls_of_2dict (caddr_t * qst, dk_session_t * out, close_tag_t * ct, xml_ns_2dict_t *xd_ns_2dict, caddr_t excl_res_prefx)
{
  caddr_t token_buf = box_copy (excl_res_prefx);
  char *tail = token_buf;
  char *token_buf_end = token_buf + box_length (token_buf) - 1;
  int ctr, dict_size = xd_ns_2dict->xn2_size;
  int default_is_excluded = 0;
  char *excluded_decls = dk_alloc (dict_size);
  memset (excluded_decls, 0, dict_size);
  while (tail < token_buf_end)
    {
      char *pfx;
      while (((unsigned char)(' ') >= (unsigned char)(tail[0])) && (tail < token_buf_end)) tail++;
      pfx = tail;
      while (((unsigned char)(' ') < (unsigned char)(tail[0])) && (tail < token_buf_end)) tail++;
      if (pfx == tail)
        break;
      tail[0] = '\0';
      for (ctr = dict_size; ctr--; /* no step */)
        {
          if (!strcmp (pfx, xd_ns_2dict->xn2_prefix2uri[ctr].xna_key))
            {
              excluded_decls[ctr] = 1;
              break;
            }
          if (!strcmp (pfx, "#default"))
            {
              default_is_excluded = 1;
              break;
            }
        }
    }
  for (ctr = dict_size; ctr--; /* no step */)
    {
      s_node_t *ns_list;
      caddr_t dict_ns, dict_pref;
      if (excluded_decls[ctr])
        continue;
      dict_pref = xd_ns_2dict->xn2_prefix2uri[ctr].xna_key;
      dict_ns = xd_ns_2dict->xn2_prefix2uri[ctr].xna_value;
      for (ns_list = ct->ct_all_explicit_ns; NULL != ns_list; ns_list = ns_list->next->next)
        {
          caddr_t cached_ns = (caddr_t) ns_list->data;
          caddr_t cached_pref = (caddr_t) ns_list->next->data;
          if (strcmp (cached_ns, dict_ns))
            {
              if (strcmp (cached_pref, dict_pref))
                continue; /* Cached has nothing common with dict, try next cached */
/* Here we have different namespace for same prefix, seems to be impossible now, if happens then don't redeclare */
#ifndef NDEBUG
              GPF_T1("bx_" "out_nsdecls_of_2dict(): cached namespace differs from one in ns dict");
#endif
            }
          else
            {
              if (!strcmp (cached_pref, dict_pref)) /* If the ns and prefix pair is cached already then no need to print */
                goto skip_ns_decl; /* see below */
/* Here we have different prefix for same namespace, seems to be impossible now, if happens then don't redeclare */
#ifndef NDEBUG
              GPF_T1("bx_" "out_nsdecls_of_2dict(): cached prefix differs from one in ns dict");
#endif
            }
          goto skip_ns_decl; /* see below */

        }
      dk_set_push (&ct->ct_all_explicit_ns, box_copy (dict_pref));
      dk_set_push (&ct->ct_all_explicit_ns, box_copy (dict_ns));
      SES_PRINT (out, " xmlns:");
      SES_PRINT (out, dict_pref);
      SES_PRINT (out, "=\"");
      bx_out_value (qst, out, (db_buf_t) dict_ns, QST_CHARSET(qst), CHARSET_UTF8, DKS_ESC_DQATTR);
      SES_PRINT (out, "\"");
skip_ns_decl: ;
    }
  dk_free_box (token_buf);
  dk_free (excluded_decls, dict_size);
}

void
bx_out_value (caddr_t * qst, dk_session_t * out, db_buf_t val, wcharset_t * tgt_charset, wcharset_t * src_charset, int dks_esc_mode)
{
  if (DV_STRINGP (val))
    dks_esc_write (out, (char *) val, box_length (val) - 1, tgt_charset, src_charset, dks_esc_mode);
  else if (DV_WIDESTRINGP(val))
    dks_wide_esc_write (out, (wchar_t *) val, box_length (val) / sizeof (wchar_t) - 1, tgt_charset, dks_esc_mode);
  else if (DV_TYPE_OF (val) == DV_XPATH_QUERY)
    {
      xp_query_t *xqr = (xp_query_t *) val;
      caddr_t text = xqr->xqr_key;
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (text)) /* If key is not a plain text but text plus namespace decls */
        text = ((caddr_t *)text)[0];
      dks_esc_write (out, text, box_length (text) - 1,
	tgt_charset, src_charset, dks_esc_mode);
    }
  else if (DV_TYPE_OF (val) == DV_DB_NULL)
    {
      ; /* no output for NULL */
    }
  else
    {
      caddr_t string;
      static caddr_t varchar = NULL;
      if (!varchar)
	varchar = (caddr_t) list (3, (ptrlong)DV_LONG_STRING, 0, 0);

      string = box_cast (qst, (caddr_t) val, (sql_tree_tmp*) varchar, (dtp_t) DV_TYPE_OF (val));
      dks_esc_write (out, string, box_length (string) - 1,
	  tgt_charset, src_charset, dks_esc_mode);
      dk_free_box (string);
    }
}


void
bx_push_ct (close_tag_t ** ct_ret, int e_level,  caddr_t e_name, caddr_t e_trailing)
{
  close_tag_t * ct = (close_tag_t *) dk_alloc (sizeof (close_tag_t));
  /*char * local = strrchr (e_name, ':');*/

  ct->ct_level = e_level;
  ct->ct_trailing = e_trailing;
  ct->ct_name = e_name;
  ct->ct_prev = ct_ret[0];
  if (NULL != ct_ret[0])
    {
      ct->ct_all_explicit_ns = ct_ret[0]->ct_all_explicit_ns;
      ct->ct_all_default_ns = ct_ret[0]->ct_all_default_ns;
    }
  else
    {
      ct->ct_all_explicit_ns = ct->ct_all_default_ns = NULL;
    }
  *ct_ret = ct;
}


static void
bx_out_q_name (xte_serialize_state_t *xsst, dk_session_t * out, caddr_t name, int is_attr, wcharset_t *src_charset)
{
  caddr_t *qst = xsst->xsst_qst;
  close_tag_t * ct = xsst->xsst_ct;
  caddr_t uri = NULL;
  int n_ns = 0, is_new_pref = 0;
  caddr_t pref = NULL;
  size_t ns_len;
  dk_set_t ns_list;
  char ns[10];
  char * local = strrchr (name, ':');
  if (NULL == local)
    {
      bx_out_value (qst, out, (db_buf_t) name, CHARSET_UTF8, src_charset, DKS_ESC_PTEXT);
      if (!is_attr && (NULL != ct->ct_all_default_ns) && (NULL != ct->ct_all_default_ns->data))
	{
	  SES_PRINT (out, " xmlns=\"\"");
          dk_set_push (&(ct->ct_all_default_ns), NULL);
	}
      return;
    }
/* Now we know we have a namespace and we need a prefix */
  ns_len = local - name;
  if (bx_std_ns_pref (name, ns_len))
    {
      pref = uname_xml;
      goto pref_is_set; /* see below */
    }
  if (!is_attr && (NULL != ct->ct_all_default_ns))
    {
      caddr_t dflt_ns = ct->ct_all_default_ns->data;
      if ((NULL != dflt_ns) && (strlen (dflt_ns) == (size_t)ns_len)
        && 0 == memcmp (dflt_ns, name, ns_len) )
        {
          pref = NULL;
          goto pref_is_set; /* see below */
        }
    }
  for (ns_list = ct->ct_all_explicit_ns; NULL != ns_list; ns_list = ns_list->next->next)
    {
      caddr_t ns = (caddr_t) ns_list->data;
      n_ns += 2; /* ++ would be enough but is used for compatibility with an old error */
      if (strlen (ns) != (size_t) ns_len || memcmp (ns, name, ns_len))
        continue;
      pref = (caddr_t) ns_list->next->data;
      goto pref_is_set; /* see below */
    }
  uri = box_dv_short_nchars (name, ns_len);
  if (0 != xsst->xsst_ns_2dict.xn2_size)
    {
      ptrlong idx = ecm_find_name (uri, xsst->xsst_ns_2dict.xn2_uri2prefix, xsst->xsst_ns_2dict.xn2_size, sizeof (xml_name_assoc_t));
      if (ECM_MEM_NOT_FOUND != idx)
        {
          pref = xsst->xsst_ns_2dict.xn2_uri2prefix[idx].xna_value;
          if ('\0' != pref[0])
            {
              pref = box_copy (pref);
              goto new_explicit_pref_is_set; /* see below */
            }
          if (is_attr)
            pref = NULL;
          else
            {
              dk_set_push (&ct->ct_all_default_ns, (void *)(box_copy (pref)));
              dk_set_push (&ct->ct_all_default_ns, (void *)uri);
              is_new_pref = 1;
              goto pref_is_set; /* see below */
            }
       }
    }
#ifdef DEBUG
  if (NULL != pref)
    GPF_T1("bx_out_q_name: non-NULL pref before making a new one");
#endif
  pref = xml_get_cli_or_global_ns_prefix (qst, uri, ~0 /* get any appropriate, it can't be worse than nothing */);
  if (NULL != pref)
    goto new_explicit_pref_is_set; /* see below */
  if (xsst->xsst_default_ns && !is_attr)
    {
      dk_set_push (&ct->ct_all_default_ns, NULL);
      dk_set_push (&ct->ct_all_default_ns, (void *)uri);
      pref = "";
      is_new_pref = 1;
      goto pref_is_set; /* see below */
    }
  snprintf (ns, sizeof (ns), "n%d", n_ns);
  pref = box_dv_short_string (ns);

new_explicit_pref_is_set:
  dk_set_push (&ct->ct_all_explicit_ns, (void*) pref);
  dk_set_push (&ct->ct_all_explicit_ns, (void*) uri);
  is_new_pref = 1;

pref_is_set:
  if ((is_attr & 1) && is_new_pref)
    goto dump_new_pref; /* see below */
  if (pref && ('\0' != pref[0]))
    {
      dks_esc_write (out, pref, strlen (pref), QST_CHARSET (qst), CHARSET_UTF8, DKS_ESC_PTEXT);
      session_buffered_write_char (':', out);
    }
  dks_esc_write (out, local + 1, strlen (local + 1), QST_CHARSET (qst), CHARSET_UTF8, DKS_ESC_PTEXT);

dump_new_pref:
  if (is_new_pref)
    {
      if (is_attr & 2)
        SES_PRINT (out, "\" ");
      else if (!is_attr)
        SES_PRINT (out, " ");
      if ('\0' == pref[0])
        SES_PRINT (out, "xmlns");
      else
        {
          SES_PRINT (out, "xmlns:");
          SES_PRINT (out, pref);
        }
      SES_PRINT (out, "=\"");
      bx_out_value (qst, out, (db_buf_t) uri, QST_CHARSET(qst), src_charset, DKS_ESC_DQATTR);
      if (!(is_attr & 2))
        SES_PRINT (out, "\"");
      if (is_attr & 1)
        {
          is_new_pref = 0;
          SES_PRINT (out, " ");
          goto pref_is_set; /* see above */
        }
    }
}


close_tag_t *
bx_pop_ct (xte_serialize_state_t *xsst, dk_session_t * out, wcharset_t *src_charset, int child_num)
{
  caddr_t *qst = xsst->xsst_qst;
  close_tag_t * ct = xsst->xsst_ct;
  close_tag_t * tmp = ct->ct_prev;
  dk_set_t explicit_bottom, default_bottom;
  if (DV_STRINGP (ct->ct_trailing))
    bx_out_value (NULL, out, (db_buf_t) ct->ct_trailing, QST_CHARSET(qst), src_charset, DKS_ESC_PTEXT);
  if (ct->ct_name && child_num)
    {
      SES_PRINT (out, "</");
      bx_out_q_name (xsst, out, ct->ct_name, 0, src_charset);
      SES_PRINT (out, ">");
    }
  dk_free_box (ct->ct_name);
  dk_free_box (ct->ct_trailing);
  if (NULL == tmp)
    explicit_bottom = default_bottom = NULL;
  else
    {
      explicit_bottom = tmp->ct_all_explicit_ns;
      default_bottom = tmp->ct_all_default_ns;
    }
  while (ct->ct_all_explicit_ns != explicit_bottom)
    dk_free_box (dk_set_pop (&(ct->ct_all_explicit_ns)));
  while (ct->ct_all_default_ns != default_bottom)
    dk_free_box (dk_set_pop (&(ct->ct_all_default_ns)));
  dk_free ((caddr_t) ct, sizeof (close_tag_t));
  return tmp;
}




void
bx_tree_serialize (caddr_t * tree, dk_session_t * out, close_tag_t ** ct_ret)
{

}

/* TBD somewhere...
   Empty-element tags (i.e. tags of syntax <tag ... />) may be used for any
   element which has no content, whether or not it is declared using the
   keyword EMPTY, but for interoperability, the empty-element tag _must_ be
   used, and _can_only_ be used, for elements which are declared EMPTY.
 */

void
bx_tree_start_tag (xte_serialize_state_t *xsst, dk_session_t * ses, caddr_t * tag,
  int child_num, html_tag_descr_t *tag_descr, int is_xsl)
{
  int inx, len = BOX_ELEMENTS (tag);
  caddr_t name = tag[0];
  bx_push_ct (&(xsst->xsst_ct), 0, box_copy (name), NULL);
  SES_PRINT (ses, "<");
  bx_out_q_name (xsst, ses, name, 0, CHARSET_UTF8);
  for (inx = 1; inx < len; inx += 2)
    {
      if (' ' == tag[inx][0])
        {
          if (!strcmp (tag[inx], uname__bang_exclude_result_prefixes))
            bx_out_nsdecls_of_2dict (xsst->xsst_qst, ses, xsst->xsst_ct, &(xsst->xsst_entity->xe_doc.xtd->xd_ns_2dict), tag[inx+1]);
	  continue;
        }
      SES_PRINT (ses, " ");
      if (xsst->xsst_out_method == OUT_METHOD_HTML && tag[inx] && tag[inx+1] && DV_STRINGP (tag[inx + 1]) &&
	  !stricmp (tag[inx], tag[inx + 1]))
	{
	  html_attr_descr_t *attr_descr = (html_attr_descr_t *)id_hash_get (html_attr_hash, (caddr_t) &(tag[inx]));
	  if ((NULL != attr_descr) && attr_descr->htmlad_is_boolean)
	    {
	      bx_out_value (xsst->xsst_qst, ses, (db_buf_t) tag[inx], xsst->xsst_charset, CHARSET_UTF8, DKS_ESC_PTEXT);
	    }
	  else
	    {
	      goto normal_attr_out;
	    }
	}
      else
	{
normal_attr_out:
	  bx_out_q_name (xsst, ses, tag[inx], 1, CHARSET_UTF8);
	  SES_PRINT (ses, "=\"");
#if 0
	  if (is_xsl && xsl_is_qnames_attr (tag[inx]))
	    {
	      int qnames_inx;
	      DO_BOX (caddr_t, qname, qnames_inx, ((caddr_t *)tag[inx + 1]))
		{
		  if (qnames_inx)
		    session_buffered_write_char (' ', ses);
		  bx_out_value (xsst->xsst_qst, ses, (db_buf_t) qname, xsst->xsst_charset, CHARSET_UTF8,
		      DKS_ESC_DQATTR | (IS_HTML_OUT(xsst->xsst_out_method) ? DKS_ESC_COMPAT_HTML : 0) );
		}
	      END_DO_BOX;
	    }
	  else
#endif
	  if (xml_is_sch_qname (tag[0], tag[inx]) ||
		xml_is_soap_qname (tag[0], tag[inx]) ||
		xml_is_wsdl_qname (tag[0], tag[inx]))
	      bx_out_q_name (xsst, ses, tag[inx + 1], 2, CHARSET_UTF8);
	  else
	    bx_out_value (xsst->xsst_qst, ses, (db_buf_t) tag[inx + 1], xsst->xsst_charset, CHARSET_UTF8,
		DKS_ESC_DQATTR | (OUT_METHOD_HTML == xsst->xsst_out_method ? DKS_ESC_COMPAT_HTML : 0) );
	  SES_PRINT (ses, "\"");
	}

    }
  if ((OUT_METHOD_HTML == xsst->xsst_out_method) && tag_descr->htmltd_is_empty)
    SES_PRINT (ses, ">");
  else if (child_num || xsst->xsst_out_method == OUT_METHOD_HTML)
    SES_PRINT (ses, ">");
  else
    {
      if ((OUT_METHOD_XHTML == xsst->xsst_out_method) && !tag_descr->htmltd_is_empty)
	{
	  SES_PRINT (ses, "></");
	  bx_out_q_name (xsst, ses, name, 0, CHARSET_UTF8);
	  SES_PRINT (ses, ">");
	}
      else
	SES_PRINT (ses, " />");
    }
  if (IS_HTML_OUT(xsst->xsst_out_method) && tag_descr->htmltd_is_head && xsst->xsst_charset_meta)
    {
      SES_PRINT (ses, "<META http-equiv=\"Content-Type\" content=\"text/html; charset=");
      SES_PRINT (ses, CHARSET_NAME(xsst->xsst_charset, "ISO-8859-1"));
      SES_PRINT (ses, xsst->xsst_out_method == OUT_METHOD_HTML ? "\">" : "\" />");
    }
}


#define WSP_EXPLICIT 1
#define WSP_COND     2
#define WSP_NOT	     0


static char xte_serialize_xmlspace[] = "\
\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\
\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\
\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\
\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\
\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\
\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\
\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\
\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\
\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\
\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\040\
";

#define PRINT_SPACE(ses, n) \
  session_buffered_write ( \
    ses, \
    xte_serialize_xmlspace, \
    ((n > 0) ? (((n - 1) * 2) % 200) : 0) )

void
xte_serialize_1 (caddr_t * current, dk_session_t * ses, xte_serialize_state_t *xsst)
{
  size_t inx;
  char *data;
  dtp_t dtp = DV_TYPE_OF (current);
  int is_root = 0;
  xml_elm_serialize_t f = xsst->xsst_hook;
  thread_t *thr = THREAD_CURRENT_THREAD;

  if (THR_IS_STACK_OVERFLOW (thr, &f, 8000))
    sqlr_new_error ("42000", "SR178", "Stack overflow (stack size is %ld, more than %ld is in use)",
	(long)(thr->thr_stack_size), (long)(thr->thr_stack_size - 8000));

  if (f && f (current, ses, xsst))
    return;
  if (DV_STRINGP (current))
    {
      if (DKS_ESC_CDATA == xsst->xsst_dks_esc_mode)
	SES_PRINT (ses, "<![CDATA[");
      dks_esc_write (ses, (char *) current,
	  box_length ((caddr_t) current) - 1, xsst->xsst_charset, CHARSET_UTF8, xsst->xsst_dks_esc_mode);
      if (DKS_ESC_CDATA == xsst->xsst_dks_esc_mode)
	SES_PRINT (ses, "]]>");
      if (xsst->xsst_do_indent) /* the content of element explicitly disables the WS printing */
	xsst->xsst_in_block = WSP_NOT;
    }
  if (DV_ARRAY_OF_POINTER == dtp)
    {
      int save_do_indent = xsst->xsst_do_indent;
      int save_indent_depth = xsst->xsst_indent_depth;
      int save_dks_esc_mode = xsst->xsst_dks_esc_mode;
      caddr_t *head = XTE_HEAD(current);
      caddr_t name = XTE_HEAD_NAME(head);
      size_t len = BOX_ELEMENTS (current);
      html_tag_descr_t curr_tag;
      memset (&curr_tag, 0, sizeof(html_tag_descr_t));
      if (' ' == name[0])
	{
	  size_t head_len = BOX_ELEMENTS (head);
	  if (uname__pi == name)
	    {
	      SES_PRINT (ses, "<?");
	      if (head_len > 2)
	        SES_PRINT (ses, head[2]);
	      else
	        session_buffered_write_char (' ', ses);
	      data = (len > 1) ? current[1] : NULL;
	      if ((NULL != data) && data[0])
	        {
	          SES_PRINT (ses, " ");
	          SES_PRINT (ses, data);
	        }
	      SES_PRINT (ses, xsst->xsst_out_method == OUT_METHOD_HTML ? ">" : "?>");
	      return;
	    }
	  if (uname__comment == name)
	    {
	      SES_PRINT (ses, "<!--");
	      if (len > 1)
		SES_PRINT (ses, ((caddr_t *) current)[1]);
	      else
		session_buffered_write_char (' ', ses);
	      SES_PRINT (ses, "-->");
	      return;
	    }
	  if (uname__ref == name)
	    {
	      SES_PRINT (ses, "&");
	      if (BOX_ELEMENTS (((caddr_t *) current)[0]) > 2)
		dks_esc_write  (ses, ((caddr_t **) current)[0][2],
		    strlen (((caddr_t **) current)[0][2]), xsst->xsst_charset, CHARSET_UTF8, DKS_ESC_NONE);
	      SES_PRINT (ses, ";");
	      return;
	    }
	  if (uname__disable_output_escaping == name)
	    {
	      if (len > 1)
		dks_esc_write (ses,
		    (char *) current[1],
		    box_length ((caddr_t) current[1]) - 1,
		    xsst->xsst_charset, CHARSET_UTF8, DKS_ESC_NONE);
	      return;
	    }
	  if (uname__attr == name)
	    return;
	  is_root = (uname__root == name);
	}
      if (IS_HTML_OUT(xsst->xsst_out_method))
	{
	  html_tag_descr_t *tag_descr;
	  char * local = strrchr (name, ':');
	  caddr_t local_name = name;

	  if (local && (XHTML_NS_LEN == local - name) && 0 == strncmp (name, XHTML_NS, XHTML_NS_LEN))
	    local_name = local+1;

	  tag_descr = (html_tag_descr_t *)id_hash_get (html_tag_hash, (caddr_t) &local_name);
	  if (NULL != tag_descr)
	    memcpy (&curr_tag, tag_descr, sizeof(html_tag_descr_t));
	}
      else if (xsst->xsst_out_method == OUT_METHOD_XML)
	curr_tag.htmltd_is_block = 1;
      if (!is_root)
	{
	  if (xsst->xsst_do_indent)
	    {
	      if (xsst->xsst_in_block == WSP_EXPLICIT ||
		  (curr_tag.htmltd_is_block && xsst->xsst_in_block == WSP_COND))
		/* if it's a block element then tag must be indented,
		   or if we already closed non-block then indent it
		 */
		{
		  SES_PRINT (ses, "\n");
		  PRINT_SPACE(ses, xsst->xsst_indent_depth);
		}
	      /* Now let's make a decision about */
	      if (curr_tag.htmltd_is_script)
		{
		  xsst->xsst_do_indent = 0; /* No indentation for a while */
		  xsst->xsst_in_block = WSP_NOT; /* if it's a not block element then next must not be indented */
		}
	      else if (curr_tag.htmltd_is_block && !curr_tag.htmltd_is_ws_sensitive)
		{
		  xsst->xsst_in_block = WSP_EXPLICIT; /* the next tag must be indented unless it is a not a in text */
		  xsst->xsst_indent_depth++;
		}
	      else
		xsst->xsst_in_block = WSP_NOT; /* if it's a not block element then next must not be indented */
	    }

	  bx_tree_start_tag (xsst, ses, (caddr_t *) current[0], (int) (len - 1), &curr_tag, xte_is_xsl (current));
	}
      if (len > 1) /*&& !(curr_tag.htmltd_is_empty && IS_HTML_OUT(xsst->xsst_out_method))) */
	{
	  int save_dks_esc_mode = xsst->xsst_dks_esc_mode;
	  switch (xsst->xsst_out_method)
	    {
	    case OUT_METHOD_HTML:
	      if (curr_tag.htmltd_is_ptext)
		xsst->xsst_dks_esc_mode = DKS_ESC_NONE;
	      xsst->xsst_dks_esc_mode |= DKS_ESC_COMPAT_HTML;
	      break;
	    case OUT_METHOD_XML:
	      if (xsst->xsst_cdata_names && id_hash_get (xsst->xsst_cdata_names, (caddr_t) (current[0])))
		xsst->xsst_dks_esc_mode = DKS_ESC_CDATA;
	      break;
	    case OUT_METHOD_XHTML:
	      if (curr_tag.htmltd_is_ptext)
		xsst->xsst_dks_esc_mode = DKS_ESC_NONE;
	      break;
	    default:
	      break;
	    }
	  for (inx = 1; inx < len; inx++)
	    {
	      xte_serialize_1 ((caddr_t *) current[inx], ses, xsst);
	    }
	  xsst->xsst_dks_esc_mode = save_dks_esc_mode;
	}
      if (!is_root)
	{
	  int childs = ((xsst->xsst_out_method == OUT_METHOD_HTML) && !curr_tag.htmltd_is_empty) ? 1 : (int) (len - 1);
	  if (xsst->xsst_do_indent) /* xsl:output indent=yes */
	    {
	      if (curr_tag.htmltd_is_block) /* indentation space count prematurely should be decreased */
		xsst->xsst_indent_depth--;
	      if (childs &&
		   (0 == curr_tag.htmltd_is_ws_sensitive) &&
		   (xsst->xsst_in_block == WSP_EXPLICIT ||
		    (curr_tag.htmltd_is_block && xsst->xsst_in_block == WSP_COND)))
		/* if we have a child elms and we 're in block or
		   we have a closing tag of block element after non-block item */
		{
		  SES_PRINT (ses, "\n");
		  PRINT_SPACE(ses, xsst->xsst_indent_depth);
		}

	      if (curr_tag.htmltd_is_block)
		xsst->xsst_in_block = WSP_EXPLICIT; /* if we closing a block the next must be indented */
	      else
		xsst->xsst_in_block = WSP_COND;     /* if not the indent should be printed only if we closing a block */
	    }
	  xsst->xsst_ct = bx_pop_ct (xsst, ses, CHARSET_UTF8, childs);
	}
      xsst->xsst_indent_depth = save_indent_depth;
      xsst->xsst_do_indent = save_do_indent;
      xsst->xsst_dks_esc_mode = save_dks_esc_mode;
    }
  return;
}


#ifdef OLD_VXML_TABLES
const char * add_entity_with_param =
"insert into %s (" CN_ENT_ID "," CN_ENT_LEVEL "," CN_ENT_NAME "," CN_ENT_MISC "," CN_ENT_WSPACE
 "," CN_ENT_LEAD "," CN_ENT_TRAIL "%s) values(?,?,?,?,?,?,?%s)";
#endif

caddr_t
bif_number (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  double d;
  caddr_t n = bif_arg (qst, args, 0, "number");
  dtp_t dtp = DV_TYPE_OF (n);
  if (dtp == DV_LONG_INT
      || dtp == DV_SINGLE_FLOAT
      || dtp == DV_DOUBLE_FLOAT
      || dtp == DV_NUMERIC)
    return (box_copy (n));

  if (DV_STRINGP (n))
    {
      if (strlen (n) < 10
	  && !strchr (n, '.')
	  && !strchr (n, 'e'))
	return (box_num (atol (n)));
      {
	numeric_t num = numeric_allocate ();
	int rc = numeric_from_string (num, n);
	if (NUMERIC_STS_SUCCESS == rc)
	  return ((caddr_t) num);
      }
      if (1 == sscanf (n, "%lf", &d))
	return (box_double (d));
      sqlr_error ("XM001", "can't convert string to number in number ()");
    }
  sqlr_error ("XM001", "not a string or number for number ()");
  return NULL; /*dummy*/
}


#ifndef NDEBUG
#define CHECK_URI_TYPES(base_uri,rel_uri) \
  do { \
    dtp_t b_dt, r_dt; \
    b_dt = DV_TYPE_OF (base_uri); \
    if ((NULL != base_uri) && (DV_STRING != b_dt) && (DV_WIDE != b_dt) && (DV_LONG_WIDE != b_dt) && (DV_UNAME != b_dt)) \
      GPF_T; \
    r_dt = DV_TYPE_OF (rel_uri); \
    if ((DV_STRING != r_dt) && (DV_WIDE != r_dt) && (DV_LONG_WIDE != r_dt) && (DV_UNAME != r_dt)) \
      GPF_T; \
    } while (0)
#else
#define CHECK_URI_TYPES(base_uri,rel_uri)
#endif

caddr_t
xml_uri_get (query_instance_t * qi, caddr_t *err_ret, caddr_t *options, ccaddr_t base_uri, ccaddr_t rel_uri, int mode)
{
  int query_idx = mode;
  static query_t *qr[3] = { NULL, NULL, NULL };
  local_cursor_t *lc = NULL;
  static const char *pl_call_text[3] = { "DB.DBA.XML_URI_GET (?, ?)", "DB.DBA.XML_URI_GET_STRING (?, ?)", "DB.DBA.XML_URI_GET_STRING_OR_ENT (?, ?)" };
  caddr_t err = NULL;

  if (NULL == qr[query_idx])
    {
      qr[query_idx] = sql_compile (pl_call_text[query_idx], qi->qi_client, &err, SQLC_DEFAULT);
      if (SQL_SUCCESS != err)
	{
	  qr[query_idx] = NULL;
	  if (err_ret)
	    *err_ret = err;
	  return NULL;
	}
    }
  CHECK_URI_TYPES(base_uri,rel_uri);
  err = qr_rec_exec (qr[query_idx], qi->qi_client, &lc, qi, NULL, 2,
      ":0", ((NULL == base_uri) ? box_dv_short_nchars ("", 0) : box_copy (base_uri)), QRP_RAW,
      ":1", box_copy (rel_uri), QRP_RAW);
  if (SQL_SUCCESS != err)
    {
      LC_FREE(lc);
      if (err_ret)
	*err_ret = err;
      return NULL;
    }
  if (lc)
    {
      caddr_t ret = NULL;
      while (lc_next (lc));
      if (SQL_SUCCESS != lc->lc_error)
	{
	  if (err_ret)
	    *err_ret = lc->lc_error;
	  lc_free (lc);
	  return NULL;
	}
      ret = ((caddr_t *) lc->lc_proc_ret) [1];
      ((caddr_t *) lc->lc_proc_ret) [1] = NULL;
      lc_free (lc);
      if (err_ret)
	*err_ret = err;
      return ret;
    }
  if (err_ret)
    *err_ret = err;
  return NULL;
}

/* xml_uri_resolve receives URI of directory and relative URI of document placed in that directory */
caddr_t
xml_uri_resolve (query_instance_t * qi, caddr_t *err_ret, ccaddr_t base_uri, ccaddr_t rel_uri, const char *output_charset)
{
  static query_t *qr = NULL;
  local_cursor_t *lc = NULL;
  static const char *pl_call_text = "WS.WS.EXPAND_URL (?, ?, ?)";
  caddr_t err = NULL;
  client_connection_t *cli;
  if (CALLER_LOCAL == qi)
    cli = bootstrap_cli;
  else
    cli = qi->qi_client;
  if (!qr)
    {
      qr = sql_compile_static (pl_call_text, cli, &err, SQLC_DEFAULT);
      if (SQL_SUCCESS != err)
	{
	  qr = NULL;
	  if (err_ret)
	    *err_ret = err;
	  return NULL;
	}
    }
  CHECK_URI_TYPES(base_uri,rel_uri);
  err = qr_rec_exec (qr, cli, &lc, qi, NULL, 3,
      ":0", ((NULL == base_uri) ? box_dv_short_nchars ("", 0) : box_copy (base_uri)), QRP_RAW,
      ":1", box_copy (rel_uri), QRP_RAW,
      ":2", ((NULL == output_charset) ? NEW_DB_NULL : box_dv_short_string (output_charset)), QRP_RAW );
  if (SQL_SUCCESS != err)
    {
      LC_FREE(lc);
      if (err_ret)
	*err_ret = err;
      return NULL;
    }
  if (lc)
    {
      caddr_t ret = NULL;
      while (lc_next (lc));
      if (SQL_SUCCESS != lc->lc_error)
	{
	  if (err_ret)
	    *err_ret = lc->lc_error;
	  lc_free (lc);
	  return NULL;
	}
      ret = ((caddr_t *) lc->lc_proc_ret) [1];
      ((caddr_t *) lc->lc_proc_ret)[1] = NULL;
      lc_free (lc);
      return ret;
    }
  return NULL;
}


/* xml_uri_resolve_like_get receives URI of base document (not URI of directory where base document is resides where directory and relative URI of document placed in that directory */
caddr_t
xml_uri_resolve_like_get (query_instance_t * qi, caddr_t *err_ret, ccaddr_t base_uri, ccaddr_t rel_uri, const char *output_charset)
{
  static query_t *qr = NULL;
  local_cursor_t *lc = NULL;
  static const char *pl_call_text = "DB.DBA.XML_URI_RESOLVE_LIKE_GET (?, ?, ?)";
  caddr_t err = NULL;

  if (NULL == base_uri)
    return box_copy (rel_uri);
  switch (DV_TYPE_OF (base_uri))
    {
    case DV_STRING:
      if ('\0' == base_uri[0])
        return box_copy (rel_uri);
      break;
    case DV_WIDE: case DV_LONG_WIDE:
      if (L'\0' == ((wchar_t *)base_uri)[0])
        return box_copy (rel_uri);
      break;
    case DV_DB_NULL:
      return box_copy (rel_uri);
    }

  if (!qr)
    {
      qr = sql_compile_static (pl_call_text, qi->qi_client, &err, SQLC_DEFAULT);
      if (SQL_SUCCESS != err)
	{
	  qr = NULL;
	  if (err_ret)
	    *err_ret = err;
	  return NULL;
	}
    }
  if (DV_STRINGP (base_uri) && DV_STRINGP (rel_uri))
    {
      caddr_t err = NULL;
      caddr_t res =  rfc1808_expand_uri (/*qi,*/ base_uri, rel_uri,
					 output_charset, 0,
					 NULL, /* Encoding used for base_uri IFF it is a narrow string, neither DV_UNAME nor WIDE */
					 NULL, /* Encoding used for rel_uri IFF it is a narrow string, neither DV_UNAME nor WIDE */
					 &err);
      if (err)
	{
	  if (err_ret)
	    *err_ret = err;
	  else
	    dk_free_tree (err);
	  return NULL;
	}
      return res;
    }

  CHECK_URI_TYPES(base_uri,rel_uri);
  err = qr_rec_exec (qr, qi->qi_client, &lc, qi, NULL, 3,
      ":0", box_copy (base_uri), QRP_RAW,
      ":1", box_copy (rel_uri), QRP_RAW,
      ":2", ((NULL == output_charset) ? NEW_DB_NULL : box_dv_short_string (output_charset)), QRP_RAW );
  if (SQL_SUCCESS != err)
    {
      LC_FREE(lc);
      if (err_ret)
	*err_ret = err;
      return NULL;
    }
  if (lc)
    {
      caddr_t ret = NULL;
      while (lc_next (lc));
      if (SQL_SUCCESS != lc->lc_error)
	{
	  if (err_ret)
	    *err_ret = lc->lc_error;
	  lc_free (lc);
	  return NULL;
	}
      ret = ((caddr_t *) lc->lc_proc_ret) [1];
      ((caddr_t *) lc->lc_proc_ret)[1] = NULL;
      lc_free (lc);
      return ret;
    }
  return NULL;
}


caddr_t
bif_xml_cut (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t *xe = bif_entity_arg (qst, args, 0, "xml_cut");
  query_instance_t *qi = (query_instance_t *) QST_INSTANCE (qst);
  return (caddr_t)(xe->_->xe_cut(xe, qi));
}


caddr_t
bif_xml_validate_dtd (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t text_arg = bif_arg (qst, args, 0, "xml_validate_dtd");
  long parser_mode = (long) bif_long_arg (qst, args, 1, "xml_validate_dtd");
  caddr_t uri = bif_string_arg (qst, args, 2, "xml_validate_dtd");
  caddr_t enc = bif_string_arg (qst, args, 3, "xml_validate_dtd");
  lang_handler_t *lh = lh_get_handler (bif_string_arg (qst, args, 4, "xml_validate_dtd"));
  caddr_t dtd_config = bif_array_or_null_arg (qst, args, 5, "xml_validate_dtd");
  caddr_t volatile text = NULL;
  caddr_t volatile log = NULL;
  volatile int text_is_temporary = 0;
  int blob_sort;
  size_t blob_arg_len;
  dtp_t dtp_of_text_arg;
  volatile int arg_is_wide = 0;
  caddr_t volatile err = NULL;
  dtp_of_text_arg = DV_TYPE_OF (text_arg);
  do
    {
      if ((dtp_of_text_arg == DV_SHORT_STRING) ||
	  (dtp_of_text_arg == DV_LONG_STRING) ||
	  (dtp_of_text_arg == DV_C_STRING) )
	{ /* Note DV_TIMESTAMP_OBJ is not enumerated in if(...), unlike bif_string_arg)_ */
	  text=text_arg;
	  break;
	}
      if (IS_WIDE_STRING_DTP (dtp_of_text_arg))
	{
	  text=text_arg;
	  arg_is_wide = 1;
	  break;
	}
      if (dtp_of_text_arg == DV_STRING_SESSION)
	{
	  dk_session_t *ses_arg = (dk_session_t *) text_arg;
	  long len = strses_length (ses_arg);
	  if (MAX_XML_STRING_LENGTH < len)
	    sqlr_error ("42000", "Unable to process STRING SESSION by function xml_validate_dtd, it's length (%ld) is too long", (long)len);
	  text = strses_string (ses_arg);
	  text_is_temporary = 1;
	  break;
	}
      if (dtp_of_text_arg == DV_BLOB_XPER_HANDLE)
	sqlr_error ("42000", "Unable to validate persistent XML data via DTD.");
      if (! ((DV_BLOB_HANDLE == dtp_of_text_arg) || (DV_BLOB_WIDE_HANDLE == dtp_of_text_arg)))
	{
	  sqlr_error ("42000",
	      "Function xml_validate_dtd needs a string or BLOB as argument 1, not an arg of type %s (%d)",
	      dv_type_title (dtp_of_text_arg), dtp_of_text_arg);
	}
      blob_sort = looks_like_serialized_xml (((query_instance_t *)(qst)), text_arg);
      if (XE_XPER_SERIALIZATION == blob_sort)
	sqlr_error ("42000", "Unable to validate BLOB with persistent XML data via DTD.");
      if (XE_XPACK_SERIALIZATION == blob_sort)
	sqlr_error ("42000", "Unable to validate BLOB with packed XML serialization data via DTD.");
      arg_is_wide = (DV_BLOB_WIDE_HANDLE == dtp_of_text_arg);
      blob_arg_len = (((blob_handle_t *) text_arg)->bh_length);
      blob_arg_len *= (arg_is_wide ? sizeof (wchar_t) : sizeof (char));
      if( MAX_XML_STRING_LENGTH < blob_arg_len)
	sqlr_error ("42000", "Unable to validate BLOB of length %ld bytes", (long)blob_arg_len);
      text = blob_to_string (((query_instance_t *)(qst))->qi_trx, text_arg);
      text_is_temporary = 1;
    } while (0);
  /* Now we have \c text ready to process */

  QR_RESET_CTX
    {
      vxml_parser_config_t config;
      vxml_parser_t * parser;
      memset (&config, 0, sizeof(config));
      config.input_is_wide = arg_is_wide;
      config.input_is_html = parser_mode;
      config.user_encoding_handler = intl_find_user_charset;
      config.uri_resolver = (VXmlUriResolver) xml_uri_resolve_like_get;
      config.uri_reader = (VXmlUriReader) xml_uri_get;
      config.uri_appdata = (query_instance_t *)(qst); /* Both xml_uri_resolve_like_get and xml_uri_get uses qi as first argument */
      config.error_reporter = (VXmlErrorReporter)(sqlr_error);
      config.initial_src_enc_name = enc;
      config.dtd_config = dtd_config;
      config.uri = ((NULL == uri) ? uname___empty : uri);
      config.root_lang_handler = lh;
      parser = VXmlParserCreate (&config);
      VXmlSetUserData (parser, NULL);
      VXmlParse (parser, text, box_length(text) - (arg_is_wide ? sizeof (wchar_t) : sizeof (char)));
      log = VXmlValidationLog (parser);
      VXmlParserDestroy (parser);
      dk_free_tree (err);
    }
  QR_RESET_CODE
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      err = thr_get_error_code (self);
      if (text_is_temporary)
	dk_free_box (text);
      POP_QR_RESET;
      sqlr_resignal (err);
    }
  END_QR_RESET;
  if (text_is_temporary)
    dk_free_box (text);
  return log;
}


extern void xml_schema_init();
extern caddr_t xml_add_system_path(caddr_t);
extern void ddl_store_mapping_schema (query_instance_t * qi, caddr_t view_name, caddr_t reload_text);

shuric_t * shuric_alloc__xmlschema (void *env)
{
  NEW_VARZ (shuric_t, sch);
  return sch;
}

caddr_t shuric_uri_to_text__xmlschema (caddr_t uri, query_instance_t *qi, void *env, caddr_t *err_ret)
{
  caddr_t resource_text;
  if (NULL == qi)
    {
      err_ret[0] = srv_make_new_error ("37XQR", "SQ197", "Unable to retrieve '%.1000s' from SQL compiler due to danger of fatal deadlock", uri);
    }
  resource_text = xml_uri_get (qi, err_ret, NULL, NULL /* = no base uri */, uri, XML_URI_STRING);
  return resource_text;
}

static caddr_t xmlschema_dflt_config = NULL;

void shuric_parse_text__xmlschema (shuric_t *shuric, caddr_t uri_text_content, query_instance_t *qi, void *env, caddr_t *err_ret)
{
  vxml_parser_t * parser = NULL;
  QR_RESET_CTX
    {
      vxml_parser_config_t config;
      vxml_parser_config_t *config_ptr;
      if (NULL != env)
        config_ptr = (vxml_parser_config_t *)env;
      else
        {
	  memset (&config, 0, sizeof(config));
	  config.input_is_wide = 0;
	  config.input_is_html = 0;
	  config.user_encoding_handler = intl_find_user_charset;
	  config.uri_resolver = (VXmlUriResolver) xml_uri_resolve_like_get;
	  config.uri_reader = (VXmlUriReader) xml_uri_get;
	  config.uri_appdata = qi; /* Both xml_uri_resolve_like_get and xml_uri_get uses qi as first argument */
	  config.error_reporter = (VXmlErrorReporter)(sqlr_error);
	  config.initial_src_enc_name = "UTF-8";
	  config.dtd_config = xmlschema_dflt_config;
	  config.uri = shuric->shuric_uri;
	  config.root_lang_handler = lh_get_handler ("x-any");
	  config.dc_namespaces = XCFG_ENABLE;
	  /* no auto_load_xmlschema_dtd */
	  config_ptr = &config;
	}
      parser = VXmlParserCreate (config_ptr);
      VXmlSetUserData (parser, parser);
      VXmlParse (parser, uri_text_content, box_length (uri_text_content) - 1);
      if (!xmlparser_is_ok (parser))
        {
	  caddr_t msg = VXmlFullErrorMessage (parser);
          err_ret[0] = srv_make_new_error ("42000", "SQ199", "Unable to compile schema '%.300s'.\n%.1000s\nFunction xml_load_schema_decl() can return full list of these errors.", shuric->shuric_uri, msg);
	  dk_free_box (msg);
	}
      else
	{
	  parser->processor.sp_schema->sp_schema_is_loaded = 1;
	  xs_addref_schema (parser->processor.sp_schema);
	  shuric->shuric_data = parser->processor.sp_schema;
	}
      if (NULL != config_ptr->log_ret)
        config_ptr->log_ret[0] = VXmlValidationLog (parser);
      VXmlParserDestroy (parser);
    }
  QR_RESET_CODE
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      err_ret[0] = thr_get_error_code (self);
      POP_QR_RESET;
      VXmlParserDestroy (parser);
    }
  END_QR_RESET;
}

void shuric_destroy_data__xmlschema (shuric_t *shuric)
{
  if (NULL != shuric->shuric_data)
    xs_release_schema ((schema_parsed_t*)(shuric->shuric_data));
  dk_free (shuric, sizeof (shuric_t));
}

shuric_vtable_t shuric_vtable__xmlschema = {
  "XML Schema",
  shuric_alloc__xmlschema,
  shuric_uri_to_text__xmlschema,
  shuric_parse_text__xmlschema,
  shuric_destroy_data__xmlschema,
  shuric_on_stale__no_op,
  shuric_get_cache_key__stub
  };

#define LOAD_SCHEMA_DECL	    0
#define RELOAD_SCHEMA_DECL	    1
#define LOAD_MAPPING_SCHEMA_DECL    2
#define RELOAD_MAPPING_SCHEMA_DECL  3
#define TABLES_FROM_MAPPING_SCHEMA_DECL  4

caddr_t
bif_xml_load_schema_decl_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, const char *fname, int mode)
{
  query_instance_t *qi = (query_instance_t *)qst;
  caddr_t tables_ms = NULL;
  caddr_t schema_decl_base = bif_string_arg (qst, args, 0, fname);
  caddr_t schema_decl_uri = bif_string_arg (qst, args, 1, fname);
  caddr_t enc = bif_string_arg (qst, args, 2, fname);
  caddr_t lang = bif_string_arg (qst, args, 3, fname);
  lang_handler_t *lh = lh_get_handler (lang);
  caddr_t dtd_config = NULL;
  caddr_t schema_decl_text = NULL;
  caddr_t err = 0;
  caddr_t volatile log = NULL;
  xml_view_t * xml_mapping_view = NULL;
  caddr_t xsd_prefix = NULL;
  caddr_t xsd_postfix = NULL;
  size_t argctr = 4;
  caddr_t schema_decl_path;
  caddr_t view_name = NULL;
  caddr_t raw_view_name = NULL;
#if 0
  vxml_parser_t * parser = NULL;
#endif
  shuric_t *sch_shu = NULL;
  schema_parsed_t *sch;
  qi_signal_if_trx_error ((query_instance_t *)qst);
  if ((RELOAD_SCHEMA_DECL == mode) || (RELOAD_MAPPING_SCHEMA_DECL == mode))
    {
      sec_check_dba ((query_instance_t *)qst, fname);
      schema_decl_text = bif_string_arg (qst, args, argctr, fname);
      argctr++;
    }
  if (BOX_ELEMENTS(args) >= (argctr+2))
    {
      xsd_prefix = bif_string_arg (qst, args, argctr, fname);
      xsd_postfix = bif_string_arg (qst, args, argctr+1, fname);
      argctr += 2;
    }
  schema_decl_path = xml_uri_resolve_like_get ((query_instance_t*)qst, &err, schema_decl_base, schema_decl_uri, "UTF-8");
  if (err && ((RELOAD_SCHEMA_DECL == mode) || (RELOAD_MAPPING_SCHEMA_DECL == mode)))
    {
      dk_free_tree (err);
      err = NULL;
      schema_decl_path = box_copy (schema_decl_uri);
    }
  if (err)
    {
      size_t restmp_len = strlen(schema_decl_base) + strlen (schema_decl_uri) + 100;
      char* restmp = (char *) dk_alloc (restmp_len);
      caddr_t res;
      snprintf (restmp, restmp_len, "Unable to resolve reference URI '%.300s' with base URI '%.300s'", schema_decl_uri, schema_decl_base);
      res = box_dv_short_string (restmp);
      dk_free (restmp, restmp_len);
      dk_free_tree (err);
      return res;
    }
  if ((RELOAD_SCHEMA_DECL != mode) && (RELOAD_MAPPING_SCHEMA_DECL != mode))
    {
      schema_decl_text = xml_uri_get((query_instance_t*)qst , &err, NULL,
	schema_decl_base , schema_decl_uri, 1);
    }
  if (err)
    {
      size_t restmp_len = strlen(schema_decl_base) + strlen (schema_decl_uri) + 100;
      char* restmp = (char *) dk_alloc (restmp_len);
      caddr_t res;
      snprintf (restmp, restmp_len, "Could not get text from \"%s\" (base=\"%s\")\n",schema_decl_uri, schema_decl_base);
      res = box_dv_short_string(restmp);
      dk_free (restmp, restmp_len);
      dk_free_box (schema_decl_path);
      dk_free_tree (err);
      return res;
    }

  QR_RESET_CTX
    {
      vxml_parser_config_t config;
      memset (&config, 0, sizeof(config));
      config.input_is_wide = 0;
      config.input_is_html = 0;
      config.user_encoding_handler = intl_find_user_charset;
      config.uri_resolver = (VXmlUriResolver) xml_uri_resolve_like_get;
      config.uri_reader = (VXmlUriReader) xml_uri_get;
      config.uri_appdata = (query_instance_t *)(qst); /* Both xml_uri_resolve_like_get and xml_uri_get uses qi as first argument */
      config.error_reporter = (VXmlErrorReporter)(sqlr_error);
      config.initial_src_enc_name = enc;
      if (NULL == dtd_config)
        dtd_config = xmlschema_dflt_config;
      config.dtd_config = dtd_config;
      config.uri = schema_decl_path;
      config.root_lang_handler = lh;
      config.dc_namespaces = XCFG_ENABLE;
      config.log_ret = (caddr_t *)(&log);
      if (xsd_prefix && xsd_postfix)
	{
	  config.auto_load_xmlschema_dtd = 1;
	  config.auto_load_xmlschema_dtd_p = xsd_prefix;
	  config.auto_load_xmlschema_dtd_s = xsd_postfix;
	}
#if 1
      sch_shu = shuric_load (&shuric_vtable__xmlschema, schema_decl_path, NULL, schema_decl_text, NULL, qi, &config, &err);
      if (NULL != err)
        {
	  if ((LOAD_SCHEMA_DECL != mode) && (RELOAD_SCHEMA_DECL != mode))
	    sqlr_resignal (err);
	}
      else
        {
	  sch = (schema_parsed_t *)(sch_shu->shuric_data);
	  if ((LOAD_SCHEMA_DECL != mode) && (RELOAD_SCHEMA_DECL != mode) && (TABLES_FROM_MAPPING_SCHEMA_DECL != mode))
	    {
	      xml_mapping_view = mapping_schema_to_xml_view (sch);
	      if (NULL == xml_mapping_view)
		sqlr_new_error ("42000", "SQ202", "The XML schema '%s' is valid but can not be used as a mapping schema.", schema_decl_path);
	    }
	  if (TABLES_FROM_MAPPING_SCHEMA_DECL == mode)
	    tables_ms = tables_from_mapping_schema (sch, ((query_instance_t *)(qst))->qi_client);
	  shuric_release (sch_shu);
	  sch_shu = NULL;
	}
#else
      parser = VXmlParserCreate (&config);
      VXmlSetUserData (parser, parser);
      VXmlParse (parser, schema_decl_text, box_length(schema_decl_text) - 1);
      if ((LOAD_SCHEMA_DECL != mode) && (RELOAD_SCHEMA_DECL != mode) && !xmlparser_is_ok(parser))
	sqlr_new_error ("42000", "SQ176", "Unable to compile mapping schema '%s'. Function xml_load_schema_decl() can return full list of these errors.", schema_decl_path);
      if (err)
	sqlr_resignal (err);
      log = VXmlValidationLog (parser);
      if ((LOAD_SCHEMA_DECL != mode) && (RELOAD_SCHEMA_DECL != mode) && (TABLES_FROM_MAPPING_SCHEMA_DECL != mode))
        xml_mapping_view = mapping_schema_to_xml_view (parser->processor.sp_schema);
      if (TABLES_FROM_MAPPING_SCHEMA_DECL == mode)
        tables_ms = tables_from_mapping_schema (parser->processor.sp_schema, ((query_instance_t *)(qst))->qi_client);
      VXmlParserDestroy (parser);
#endif
    }
  QR_RESET_CODE
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      err = thr_get_error_code (self);
      if ((RELOAD_SCHEMA_DECL != mode) && (RELOAD_MAPPING_SCHEMA_DECL != mode))
        dk_free_box (schema_decl_text);
      dk_free_box (schema_decl_path);
      POP_QR_RESET;
      shuric_release (sch_shu);
      sch_shu = NULL;
#if 0
      VXmlParserDestroy (parser);
#endif
      sqlr_resignal (err);
    }
  END_QR_RESET;
  if ((LOAD_SCHEMA_DECL != mode) && (RELOAD_SCHEMA_DECL != mode) && (TABLES_FROM_MAPPING_SCHEMA_DECL != mode))
    {
      char *err = NULL;
      char _db[] = "DB";
      char _dba[] = "DBA";
      raw_view_name = get_view_name ((utf8char *)schema_decl_path, XS_VIEW_DELIMETER);
      view_name = xml_view_name (((query_instance_t *)(qst))->qi_client, _db, _dba, raw_view_name, &err, NULL, NULL, NULL);
      if (NULL != err)
	{
	  sqlr_new_error ("42000", "SQ176", "Unable to declare an XML view '%s' from '%s': %s", raw_view_name, schema_decl_path, err);
	}
    }
  if (LOAD_MAPPING_SCHEMA_DECL == mode)
    {
      caddr_t reload_text;
      int buf_len = 100 + 2 * (
          box_length (schema_decl_base) + box_length (schema_decl_uri) +
          box_length (enc) + box_length (lang) +
          box_length (schema_decl_text) +
          ((xsd_prefix && xsd_postfix) ?
            (box_length (xsd_prefix) + box_length (xsd_prefix)) : 0) );
      caddr_t buf = dk_alloc_box (buf_len, DV_STRING);
      int buf_fill = 0;
      sprintf_more (buf, box_length (buf), &buf_fill, "xml_reload_mapping_schema_decl ('', ");
      sqlc_string_literal (buf, box_length (buf), &buf_fill, schema_decl_path);
      sprintf_more (buf, box_length (buf), &buf_fill, ", ");
      sqlc_string_literal (buf, box_length (buf), &buf_fill, enc);
      sprintf_more (buf, box_length (buf), &buf_fill, ", ");
      sqlc_string_literal (buf, box_length (buf), &buf_fill, lang);
      sprintf_more (buf, box_length (buf), &buf_fill, ", ");
      sqlc_string_literal (buf, box_length (buf), &buf_fill, schema_decl_text);
      if (xsd_prefix && xsd_postfix)
        {
	  sprintf_more (buf, box_length (buf), &buf_fill, ", ");
	  sqlc_string_literal (buf, box_length (buf), &buf_fill, xsd_prefix);
	  sprintf_more (buf, box_length (buf), &buf_fill, ", ");
	  sqlc_string_literal (buf, box_length (buf), &buf_fill, xsd_postfix);
	}
      sprintf_more (buf, box_length (buf), &buf_fill, ")");
      reload_text = box_dv_short_string (buf);
      dk_free_box (buf);
      ddl_store_mapping_schema ((query_instance_t *)qst, view_name, reload_text);
      dk_free_box (reload_text);
    }
  if ((LOAD_SCHEMA_DECL != mode) && (RELOAD_SCHEMA_DECL != mode) && (TABLES_FROM_MAPPING_SCHEMA_DECL != mode))
  {
    xml_mapping_view->xv_schema = box_dv_short_string ("DB");
    xml_mapping_view->xv_user = box_dv_short_string ("DBA");
    xml_mapping_view->xv_local_name = raw_view_name;
    xml_mapping_view->xv_full_name = view_name;
    mpschema_set_view_def (view_name, (caddr_t) xml_mapping_view);
    sch_set_view_def (wi_inst.wi_schema, view_name, NULL);
/*creation of the stored procedures*/
/*     xmls_proc_mpschema ((query_instance_t*)qst, view_name);*/
     xmls_proc ((query_instance_t*)qst, view_name);
/*     dk_free_tree (xml_mapping_view);*/
  }
  dk_free_box (schema_decl_path);
  if (TABLES_FROM_MAPPING_SCHEMA_DECL == mode)
    return tables_ms;
  return log;
}


caddr_t
bif_xml_load_schema_decl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_xml_load_schema_decl_impl (qst, err_ret, args, "xml_load_schema_decl", LOAD_SCHEMA_DECL);
}


caddr_t
bif_xml_reload_schema_decl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_xml_load_schema_decl_impl (qst, err_ret, args, "xml_reload_schema_decl", RELOAD_SCHEMA_DECL);
}


caddr_t
bif_xml_load_mapping_schema_decl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_xml_load_schema_decl_impl (qst, err_ret, args, "xml_load_mapping_schema_decl", LOAD_MAPPING_SCHEMA_DECL);
}


caddr_t
bif_xml_reload_mapping_schema_decl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_xml_load_schema_decl_impl (qst, err_ret, args, "xml_reload_mapping_schema_decl", RELOAD_MAPPING_SCHEMA_DECL);
}


caddr_t
bif_xml_create_tables_from_mapping_schema_decl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_xml_load_schema_decl_impl (qst, err_ret, args, "xml_reload_mapping_schema_decl", TABLES_FROM_MAPPING_SCHEMA_DECL);
}


#undef LOAD_SCHEMA_DECL
#undef RELOAD_SCHEMA_DECL
#undef LOAD_MAPPING_SCHEMA_DECL
#undef RELOAD_MAPPING_SCHEMA_DECL
#undef TABLES_FROM_MAPPING_SCHEMA_DECL



static caddr_t
bif_xml_add_system_path(caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t path_uri = bif_string_arg (qst, args, 0, "xml_set_systempath");
  xml_add_system_path(path_uri);
  return NEW_DB_NULL;
}

static caddr_t
bif_xml_get_system_paths(caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  struct xml_iter_syspath_s* iter = xml_iter_system_path();
  caddr_t *res;
  ptrlong i, res_len = 0;
  res_len = xml_iter_syspath_length(iter);
  res = (caddr_t*) dk_alloc_box (res_len*sizeof(caddr_t),DV_ARRAY_OF_POINTER);
  for (i=0;i<res_len;i++)
    res[i] = box_dv_short_string(xml_iter_syspath_hitnext(iter));
  xml_free_iter_system_path(iter);
  return (caddr_t)res;
}

/* load xml document, if there is "xsi:schemaLocation" parameter in root element loads
xml schema declaration and performs schema validation
parameters:
  in text varchar - xml document,
  in parser_mode integer - is html mode,
  in uri varchar - base uri of document,
  in enc varchar - encoding string, for instance 'UTF-8',
  in lang varchar - language string, for instance 'x-any',
  in schema_config varchar - DTD like configuration string;
  in xsd_prefix varchar - schema prefix like 'xs:'
  in xsd_suffix varchar - schema suffix like ':xs'
  in xsd_uri varchar - URI of schema to be loaded automatically;
*/
caddr_t
bif_xml_validate_schema (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t text_arg = bif_arg (qst, args, 0, "xml_validate_schema");
  xml_entity_t *ent = NULL;
  long parser_mode = (long) bif_long_arg (qst, args, 1, "xml_validate_schema");
  caddr_t uri = bif_string_arg (qst, args, 2, "xml_validate_schema");
  caddr_t enc = bif_string_arg (qst, args, 3, "xml_validate_schema");
  lang_handler_t *lh = lh_get_handler (bif_string_arg (qst, args, 4, "xml_validate_schema"));
  caddr_t dtd_config = bif_array_or_null_arg (qst, args, 5, "xml_validate_schema");
  caddr_t text = NULL;
  caddr_t log = NULL;
  int text_is_temporary = 0;
  size_t blob_arg_len;
  int blob_sort;
  dtp_t dtp_of_text_arg;
  int arg_is_wide = 0;
  caddr_t err = NULL;
  caddr_t xsd_prefix = 0;
  caddr_t xsd_postfix = 0;
  int xsd_owns = 0;
  caddr_t xsd_uri = 0;
  shuric_t *xsd_shu = NULL;
  vxml_parser_t * parser = NULL;
  dtp_of_text_arg = DV_TYPE_OF (text_arg);
  if (BOX_ELEMENTS(args) > 7)
    {
      xsd_prefix = bif_string_arg (qst, args, 6, "xml_validate_schema");
      xsd_postfix = bif_string_arg (qst, args, 7, "xml_validate_schema");
    }
  if (BOX_ELEMENTS(args) > 8)
    {
      xsd_uri = bif_string_arg (qst, args, 8, "xml_validate_schema");
      xsd_shu = shuric_get_typed (xsd_uri, &shuric_vtable__xmlschema, &err);
      if (NULL != err)
        sqlr_resignal (err);
    }
  do
    {
      if ((dtp_of_text_arg == DV_SHORT_STRING) ||
	  (dtp_of_text_arg == DV_LONG_STRING) ||
	  (dtp_of_text_arg == DV_C_STRING) )
	{ /* Note DV_TIMESTAMP_OBJ is not enumerated in if(...), unlike bif_string_arg)_ */
	  text=text_arg;
	  break;
	}
      if (IS_WIDE_STRING_DTP (dtp_of_text_arg))
	{
	  text=text_arg;
	  arg_is_wide = 1;
	  break;
	}
      if (dtp_of_text_arg == DV_STRING_SESSION)
	{
	  dk_session_t *ses_arg = (dk_session_t *) text_arg;
	  long len = strses_length (ses_arg);
	  if (MAX_XML_STRING_LENGTH < len)
	    sqlr_error ("42000", "Unable to process STRING SESSION by function xml_validate_schema, it's length (%ld) is too long", (long)len);
	  text = strses_string (ses_arg);
	  text_is_temporary = 1;
	  break;
	}
      if (DV_XML_ENTITY == dtp_of_text_arg)
	{
	  ent = (xml_entity_t *)text_arg;
	  break;
	}
      if (DV_OBJECT == dtp_of_text_arg)
	{
	  ent = XMLTYPE_TO_ENTITY(text_arg);
	  if (NULL != ent)
	    sqlr_error ("42000", "Unsupported type of UDT instance is passed as argument 1 to function xml_validate_schema");
	  break;
	}
      if (dtp_of_text_arg == DV_BLOB_XPER_HANDLE)
	sqlr_error ("42000", "Unable to validate persistent XML data via XML Schema.");
      if (! ((DV_BLOB_HANDLE == dtp_of_text_arg) || (DV_BLOB_WIDE_HANDLE == dtp_of_text_arg)))
	{
	  sqlr_error ("42000",
	      "Function xml_validate_schema needs a string or BLOB as argument 1, not an arg of type %s (%d)",
	      dv_type_title (dtp_of_text_arg), dtp_of_text_arg);
	}
      blob_sort = looks_like_serialized_xml (((query_instance_t *)(qst)), text_arg);
      if (XE_XPER_SERIALIZATION == blob_sort)
	sqlr_error ("42000", "Unable to validate BLOB with persistent XML data via XML Schema.");
      if (XE_XPACK_SERIALIZATION == blob_sort)
	sqlr_error ("42000", "Unable to validate BLOB with packed XML serialization data via XML Schema.");
      arg_is_wide = (DV_BLOB_WIDE_HANDLE == dtp_of_text_arg);
      blob_arg_len = (((blob_handle_t *) text_arg)->bh_length);
      blob_arg_len *= (arg_is_wide ? sizeof (wchar_t) : sizeof (char));
      if( MAX_XML_STRING_LENGTH < blob_arg_len)
	sqlr_error ("42000", "Unable to validate BLOB of length %ld bytes", (long)blob_arg_len);
      text = blob_to_string (((query_instance_t *)(qst))->qi_trx, text_arg);
      text_is_temporary = 1;
    } while (0);
  /* Now we have \c text ready to process */

  QR_RESET_CTX
    {
      vxml_parser_config_t config;
      memset (&config, 0, sizeof(config));
      config.input_is_wide = arg_is_wide;
      config.input_is_html = parser_mode;
      if (NULL != ent)
        config.input_source_type = XML_SOURCE_TYPE_XTREE_DOC;
      config.user_encoding_handler = intl_find_user_charset;
      config.uri_resolver = (VXmlUriResolver) xml_uri_resolve_like_get;
      config.uri_reader = (VXmlUriReader) xml_uri_get;
      config.uri_appdata = (query_instance_t *)(qst); /* Both xml_uri_resolve_like_get and xml_uri_get uses qi as first argument */
      config.error_reporter = (VXmlErrorReporter)(sqlr_error);
      config.initial_src_enc_name = enc;
      config.dtd_config = dtd_config;
      config.uri = ((NULL == uri) ? uname___empty : uri);
      config.root_lang_handler = lh;
      config.validation_mode = XML_SCHEMA; /* ...unlike default XML_DTD */
      if (!xsd_prefix && !xsd_postfix)
	{
	  xsd_prefix = box_dv_short_string ("xs:");
	  xsd_postfix = box_dv_short_string (":xs");
	  xsd_owns = 1;
	}
      config.auto_load_xmlschema_dtd = 0;
      config.auto_load_xmlschema_dtd_p = xsd_prefix;
      config.auto_load_xmlschema_dtd_s = xsd_postfix;
      config.auto_load_xmlschema_uri = xsd_uri;
      config.dc_namespaces = XCFG_ENABLE;
      parser = VXmlParserCreate (&config);
      VXmlSetUserData (parser, NULL);
      if (NULL != xsd_shu)
        {
          parser->processor.sp_schema = ((schema_parsed_t *)(xsd_shu->shuric_data));
          xs_addref_schema (parser->processor.sp_schema);
        }
      if (NULL != ent)
        {
          parser->curr_pos.line_num = -1; /* .. to prevent from printing fake line numbers. */
	  ent->_->xe_emulate_input (ent, parser);
	  parser->attrdata.local_attrs_count = 0; /* Attributes should not be freed if input is emulated */
	}
      else
        VXmlParse (parser, text, box_length(text) - (arg_is_wide ? sizeof (wchar_t) : sizeof (char)));
      log = VXmlValidationLog (parser);
      VXmlParserDestroy (parser);
      shuric_release (xsd_shu);
      dk_free_tree (err);

      if (xsd_owns)
	{
	  dk_free_box (xsd_prefix);
	  dk_free_box (xsd_postfix);
	}
    }
  QR_RESET_CODE
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      err = thr_get_error_code (self);

      if (text_is_temporary)
	dk_free_box (text);
      if ((NULL != ent) && (NULL != parser)) /* Attributes should not be freed if input is emulated */
	parser->attrdata.local_attrs_count = 0;
      POP_QR_RESET;
      VXmlParserDestroy (parser);
      shuric_release (xsd_shu);
      sqlr_resignal (err);
    }
  END_QR_RESET;
  if (text_is_temporary)
    dk_free_box (text);
  if (NULL == log)
    GPF_T;
  return log;
}


caddr_t
bif_xml_schema_debug (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t base_uri = bif_string_arg (qst, args, 0, "xml_schema_debug");
  caddr_t rel_uri = bif_string_arg (qst, args, 1, "xml_schema_debug");
  caddr_t op = bif_string_arg (qst, args, 2, "xml_schema_debug");
  caddr_t name = ((3 >= BOX_ELEMENTS (args)) ? NULL : bif_string_arg (qst, args, 3, "xml_schema_debug"));
  caddr_t err = NULL;
  shuric_t *shu = shuric_load_xml_by_qi ((query_instance_t *)qst, base_uri, rel_uri,
    &err, NULL, &shuric_vtable__xmlschema, "XMLSchema debugger" );
  schema_parsed_t *sch;
  if (NULL != err)
    sqlr_resignal (err);
  sch = (schema_parsed_t *)(shu->shuric_data);
  if (!strcmp (op, "xecm_list"))
    {
      int idx = sch->sp_xecm_el_no;
      caddr_t *ret = (caddr_t *)dk_alloc_box_zero (idx * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      while (idx-- > 0)
        {
          ret[idx] = box_copy (sch->sp_xecm_els[idx].xee_component->cm_longname);
        }
      return (caddr_t)ret;
    }
  if (!strcmp (op, "xecm") || !strcmp (op, "raw_xecm"))
    {
      xs_component_t **dict_entry;
      xecm_el_idx_t idx;
      xecm_el_t *xel;
      caddr_t ret;
      if (NULL == name)
        {
          shuric_release (shu);
          sqlr_new_error ("22003", "SR???", "Too few arguments for xml_schema_debug(), 'xecm' mode");
        }
      dict_entry = (xs_component_t **) ((NULL == sch->sp_elems) ? NULL : id_hash_get (sch->sp_elems, (caddr_t) &name));
      if (NULL == dict_entry)
        {
	  shuric_release (shu);
          sqlr_new_error ("22003", "SR???", "No element '%s' found by xml_schema_debug() in '%s'", name, shu->shuric_uri);
        }
      idx = dict_entry[0]->cm_xecm_idx;
      xel = sch->sp_xecm_els + idx;
#ifdef DEBUG
      ret = xecm_print_fsm (idx, sch, !strcmp (op, "raw_xecm"));
#else
      ret = box_dv_short_string ("FSM can be printed only by debug build of the server");
#endif
      shuric_release (shu);
      return ret;
    }
  shuric_release (shu);
  sqlr_new_error ("22003", "SR???", "Unknown mode '%s' for xml_schema_debug()", op);
  return NULL;
}


caddr_t
DBG_NAME(box_cast_to_UTF8) (DBG_PARAMS caddr_t * qst, caddr_t data)
{
  dtp_t dtp = DV_TYPE_OF (data);
  caddr_t result;
  caddr_t err = NULL;
  static caddr_t varchar = NULL;
  if (dtp == DV_BLOB_XPER_HANDLE)
    sqlr_error ("42000", "Unable to convert a persistent XML object into a node of an XML tree entity");
  if (!varchar)
    varchar = (caddr_t) list (3, (ptrlong)DV_LONG_STRING, 0, 0);
  switch (dtp)
    {
    case DV_WIDE: case DV_LONG_WIDE:
	return box_wide_as_utf8_char (data, wcslen ((wchar_t *) data), DV_LONG_STRING);
    case DV_BLOB_WIDE_HANDLE:
      {
	caddr_t res;
	result = blob_to_string (((query_instance_t *) qst)->qi_trx, data);
	res = box_wide_as_utf8_char (result, wcslen ((wchar_t *) result), DV_LONG_STRING);
	dk_free_tree (result);
	return res;
      }
    case DV_XML_ENTITY:
      {
	xml_entity_t *ent = (xml_entity_t *)data;
	caddr_t res = NULL;
	if (ent->xe_attr_name)
	  {
	    res = ent->_->xe_currattrvalue (ent);
	    return DBG_NAME(box_copy) (DBG_ARGS res);
	  }
	else
	  {
	    ent->_->DBG_NAME(xe_string_value) (DBG_ARGS ent, &res, DV_STRING);
	    return res;
	  }
      }
    case DV_STRING:
    case DV_UNAME:
      {
        /* Bug 5763: No need:
        encoding_handler_t * eh = eh_get_handler (CHARSET_NAME(QST_CHARSET (qst), "ISO-8859-1"));
	if (eh)
	  return literal_as_utf8 (eh, data, box_length (data) - 1);
	else
	*/
	  result = DBG_NAME (box_narrow_string_as_utf8) (DBG_ARGS NULL, data, 0, QST_CHARSET (qst), &err, 1);
	  if (err)
	    sqlr_resignal (err);
	  return result;
      }
    case DV_DB_NULL:
      return NEW_DB_NULL;
    default:
      {
        /* Bug 5763: No need:
	encoding_handler_t * eh = eh_get_handler (CHARSET_NAME(QST_CHARSET (qst), "ISO-8859-1"));
	*/
	caddr_t res;
	result = box_cast (qst, data, (sql_tree_tmp*) varchar, dtp);
        /* Bug 5763: No need:
	if (eh)
	  res = literal_as_utf8 (eh, result, box_length (result) - 1);
	else
	*/
	res = box_narrow_string_as_utf8 (NULL, result, 0, QST_CHARSET (qst), &err, 1);
	if (err)
	  sqlr_resignal (err);
	dk_free_tree (result);
	return res;
      }
    }
}


caddr_t
box_cast_to_UTF8_xsd (caddr_t *qst, caddr_t data)
{
  char tmpbuf[50];
  int buffill;
  double boxdbl;
  switch (DV_TYPE_OF (data))
    {
    case DV_SINGLE_FLOAT: boxdbl = (double)(unbox_float (data)); goto make_double; /* see below */
    case DV_DOUBLE_FLOAT: boxdbl = unbox_double (data); goto make_double; /* see below */
    default: return box_cast_to_UTF8 (qst, data);
    }
make_double:
  buffill = sprintf (tmpbuf, "%lg", boxdbl);
  if ((NULL == strchr (tmpbuf, '.')) && (NULL == strchr (tmpbuf, 'E')) && (NULL == strchr (tmpbuf, 'e')))
    {
      if (isalpha(tmpbuf[1+1]))
        {
	  double myZERO = 0.0;
          double myPOSINF_d = 1.0/myZERO;
          double myNEGINF_d = -1.0/myZERO;
          if (myPOSINF_d == boxdbl) return box_dv_short_string ("INF");
          else if (myNEGINF_d == boxdbl) return box_dv_short_string ("-INF");
          else return box_dv_short_string ("NAN");
        }
      else
        {
          strcpy (tmpbuf+buffill, ".0");
          buffill += 2;
        }
    }
  return box_dv_short_nchars (tmpbuf, buffill);
}

caddr_t
box_cast_to_UTF8_uname (caddr_t *qst, caddr_t raw_name)
{
  switch (DV_TYPE_OF (raw_name))
    {
    case DV_UNAME: return box_copy (raw_name);
    case DV_STRING: return box_dv_uname_nchars (raw_name, box_length (raw_name) - 1);
    case DV_WIDE: case DV_LONG_WIDE:
      {
        caddr_t tmp_strg = box_cast_to_UTF8 (qst, raw_name);
        caddr_t res = box_dv_uname_nchars (tmp_strg, box_length (tmp_strg) - 1);
        dk_free_box (tmp_strg);
        return res;
      }
    default: GPF_T;
    }
  return NULL; /* never reached */
}


caddr_t
bif_xte_head (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int args_length = BOX_ELEMENTS (args);
  int inx, box_inx = args_length;
  caddr_t name, *box;
  static caddr_t varchar = NULL;
  if (!varchar)
    varchar = (caddr_t) list (3, (ptrlong)DV_LONG_STRING, 0, 0);
  if (args_length%2 == 0)
    sqlr_new_error ("42000", "XTE01", "Function xte_head() should have an odd number of parameters");
  box = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * args_length, DV_ARRAY_OF_POINTER);
  for (inx = args_length; inx >= 3; inx -= 2)
    {
      caddr_t raw_value = bif_arg (qst, args, inx - 1, "xte_head");
      dtp_t raw_value_dtp = DV_TYPE_OF (raw_value);
      int inx2, do_insert = 1;
      name = bif_string_or_wide_or_uname_arg (qst, args, inx - 2, "xte_head");
      if (DV_DB_NULL == raw_value_dtp)
	continue;
      for (inx2 = box_inx; inx2 < args_length; inx2 += 2)
	{
	  if (!strcmp(name, box [inx2]))
	    {
	      do_insert = 0;
	      break;
	    }
	}
      if (!do_insert)
	{
	  continue;
	}
      box [--box_inx] = box_cast_to_UTF8 (qst, raw_value);
      box [--box_inx] = box_cast_to_UTF8_uname (qst, name);
    }
  name = bif_string_or_wide_or_uname_arg (qst, args, 0, "xte_head");
  box [--box_inx] = box_cast_to_UTF8_uname (qst, name);
#ifdef DEBUG
  if (box_inx < 0)
    GPF_T;
#endif
  if (box_inx != 0)
    {
      ptrlong new_size = sizeof (caddr_t) * (args_length - box_inx);
      caddr_t new_box = dk_alloc_box (new_size, DV_ARRAY_OF_POINTER);
      memcpy (new_box, box + box_inx, new_size);
      dk_free_box /* not dk_free_tree */ ((caddr_t)box);
      box = (caddr_t *)new_box;
    }
  return (caddr_t)box;
}

caddr_t string_concat (caddr_t first, caddr_t second)
{
  caddr_t result;
  int first_length = box_length(first) - 1;
  int second_length = box_length (second);
  int result_length =  first_length + second_length;
  result = dk_alloc_box (result_length, DV_STRING);
  memcpy (result, first, first_length);
  memcpy (result+first_length, second, second_length);
  return result;
}


#define NODEBLD_ACC_IS_BAD(acc) \
  ( \
    (DV_ARRAY_OF_POINTER != DV_TYPE_OF(acc)) || \
    (1 > (int)(BOX_ELEMENTS(acc))) || \
    (DV_LONG_INT != DV_TYPE_OF(acc[0])) || \
    (unbox (acc[0]) >=  (ptrlong)(BOX_ELEMENTS(acc))) )


#ifdef XTREE_DEBUG

void dk_check_xte_nodebld_acc (caddr_t *acc)
{
  dk_hash_t *known = hash_table_allocate (4096);
  int idx, len, used;
  if (NODEBLD_ACC_IS_BAD(acc))
    GPF_T1 ("dk_check_xte_nodebld_acc(): bad acc");
  len = BOX_ELEMENTS (acc);
  used = unbox (acc[0]);
  sethash (acc, known, NULL);
  for (idx = 1; idx <= used; idx++)
    xte_tree_check_iter (acc [idx], acc, known);
  for (idx = len; idx > used; idx--)
    if (NULL != acc [idx])
      GPF_T1 ("dk_check_xte_nodebld_acc(): non-zero in an unused part");
}

#define dk_check_vectorbld_acc(acc) dk_check_tree((acc))

#define dk_check_xq_seqbld_acc(acc) dk_check_tree((acc))

#else

#define dk_check_xte_nodebld_acc(acc)

#define dk_check_vectorbld_acc(acc)

#define dk_check_xq_seqbld_acc(acc)

#endif


caddr_t
bif_xte_nodebld_init (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * acc = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * 15 /*  2^n - 1 */, DV_ARRAY_OF_POINTER);
  if (1 > BOX_ELEMENTS(args))
    sqlr_new_error ("22003", "SR344", "Too few arguments for xte_nodebld_init");
  dk_check_xte_nodebld_acc (acc);
  qst_set (qst, args[0], (caddr_t) acc);
  return NULL;
}


caddr_t
bif_xte_nodebld_acc_impl (caddr_t * qst, state_slot_t ** args, int preserve_args, caddr_t **acc_ptr)
{
  int acc_length, new_acc_length;
  int filled_count;	/* number of non-null elements in the first argument, excluding the counter */
  int argcount;		/* number of arguments in the call */
  int arg_inx;		/* index of current argument */
  int tail_inx;		/* index of the first unprocessed children */
  int new_filled_count;  /* the maximum possible value of filled_count at the end of the procedure */
  caddr_t *acc = acc_ptr[0];
  caddr_t *dst;
  qi_signal_if_trx_error ((query_instance_t *)qst);
  if (1 > BOX_ELEMENTS(args))
    sqlr_new_error ("22003", "SR345", "Too few arguments for xte_nodebld_acc");
  argcount = BOX_ELEMENTS (args);
/* The following 'if' must not appear here, but this is a workaround for a weird error in aggr in nested select. */
  if (NULL == acc)
    {
      acc = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * 15 /*  2^n - 1 */, DV_ARRAY_OF_POINTER);
      acc_ptr[0] = acc; /* No free before because it was NULL */
    }
  dk_check_xte_nodebld_acc (acc);
  if (NODEBLD_ACC_IS_BAD(acc))
    sqlr_new_error ("22003", "SR346", "The first argument of xte_nodebld_acc is not made by xte_nodebld_init() function");
  filled_count = (int) unbox (acc[0]);
  acc_length = BOX_ELEMENTS (acc);
  new_filled_count = filled_count + argcount - 1; /* This is an estimate for the most common case. It can be adjusted in the future */
  for (new_acc_length = acc_length; (new_filled_count) >= new_acc_length; new_acc_length += (new_acc_length + 1)); /* do nothing */;
  if (new_acc_length > MAX_BOX_ELEMENTS)
    sqlr_new_error ("22003", "SR346", "Out of memory allocation limits: the composed XML contains a node that have too many children");
  if (acc_length != new_acc_length)
    {
      caddr_t new_acc;
      if (NULL == (new_acc = dk_try_alloc_box (sizeof (caddr_t) * new_acc_length, DV_ARRAY_OF_POINTER)))
	qi_signal_if_trx_error ((query_instance_t *)qst);
      memset (new_acc, 0, sizeof (caddr_t) * new_acc_length);
      memcpy (new_acc, acc, sizeof (caddr_t) * acc_length);
      dk_free_box (acc);
      acc_ptr[0] = acc = (caddr_t *)new_acc;
      acc_length = new_acc_length;
      dk_check_xte_nodebld_acc (acc);
    }
  dst = acc + filled_count + 1;
  for (arg_inx = 1; arg_inx < argcount; arg_inx++)
    {
      dtp_t dst_dtp;
      dst[0] = QST_GET (qst, args[arg_inx]);
      dst_dtp = DV_TYPE_OF (dst[0]);
      switch (dst_dtp)
	{
          case DV_ARRAY_OF_POINTER:
	    if (preserve_args)
    	      dst[0] = box_try_copy_tree (dst[0], NULL);
	    else
	      {
	        dst[0] = NULL;
	        qst_swap_or_get_copy (qst, args[arg_inx], dst);
	      }
	    dst++;
	    break;
	  case DV_DB_NULL:
	    dst[0] = NULL;
	    /* no dst++ */
	    break;
	  case DV_XML_ENTITY:
	  case DV_OBJECT:
	    {
	      dk_set_t elt_set = NULL;
	      dk_set_t head_set = NULL;
	      size_t elt_count;
	      dst[0] = NULL;
	      bif_to_xml_array_arg (qst, args, arg_inx, "XMLAGG or xte_nodebld_acc", &elt_set, &head_set);
	      if (NULL != head_set)
	        {
		  while (elt_set != NULL)
		    dk_free_tree ((box_t) dk_set_pop (&elt_set));
		  while (head_set != NULL)
		    dk_free_tree ((box_t) dk_set_pop (&head_set));
	          sqlr_new_error ("22023", "SR444", "An attribute entity can not be an argument of XMLAGG or xte_nodebld_acc");
	        }
	      elt_count = dk_set_length (elt_set);
	      switch (elt_count)
	        {
	        case 0:
	          break;
	        case 1:
		  (dst++)[0] = (caddr_t) dk_set_pop (&elt_set);
		  break;
		default:
		  new_filled_count += (elt_count - 1);
		  for (new_acc_length = acc_length; (new_filled_count) >= new_acc_length; new_acc_length += (new_acc_length + 1)) /* do nothing */;
		  if (acc_length != new_acc_length)
		    {
		      caddr_t new_acc;
		      if (new_acc_length > MAX_BOX_ELEMENTS)
		        {
		          while (elt_set != NULL)
		            dk_free_tree ((box_t) dk_set_pop (&elt_set));
			  sqlr_new_error ("22003", "SR346", "Out of memory allocation limits: the composed XML contains a node that have too many children");
			}
		      if (NULL == (new_acc = dk_try_alloc_box (sizeof (caddr_t) * new_acc_length, DV_ARRAY_OF_POINTER)))
		        {
		          while (elt_set != NULL)
		            dk_free_tree ((box_t) dk_set_pop (&elt_set));
			  qi_signal_if_trx_error ((query_instance_t *)qst);
			}
		      memset (new_acc, 0, sizeof (caddr_t) * new_acc_length);
		      memcpy (new_acc, acc, sizeof (caddr_t) * acc_length);
		      dk_check_xte_nodebld_acc (acc);
		      dst = ((caddr_t *)new_acc) + (dst - acc);
		      dk_free_box (acc);
		      acc_ptr[0] = acc = (caddr_t *)new_acc;
		      acc_length = new_acc_length;
		      dk_check_xte_nodebld_acc (acc);
		    }
		  elt_set = dk_set_nreverse (elt_set);
		  while (elt_set != NULL)
		    (dst++)[0] = (caddr_t) dk_set_pop (&elt_set);
		  dk_check_xte_nodebld_acc (acc);
		}
	    }
	    break;
	  default:
	    {
	      caddr_t strg = box_cast_to_UTF8 (qst, dst[0]);
	      dst[0] = strg;
	      dst++;
	      break;
	    }
	}
    }
  dk_check_xte_nodebld_acc (acc);
#ifdef AGG_DEBUG
  for (arg_inx = 1; arg_inx < argcount; arg_inx++)
    {
      int tmp_inx;
      DO_BOX_FAST (caddr_t, el, tmp_inx, acc)
        {
          if (IS_BOX_POINTER(el) && (el == QST_GET (qst, args[arg_inx])))
            GPF_T;
        }
      END_DO_BOX_FAST;
    }
#endif
  if (0 < filled_count)
    filled_count--;
  tail_inx = 1 + filled_count;
  /* Now we know what's the precise value of new_filled_count */
  new_filled_count = (dst - acc) - 1;
  while (tail_inx <= new_filled_count)
    {
      int strg_ctr = 0;
      int res_strg_len = 0;
      caddr_t tail_begin = acc [tail_inx];
      int old_tail_inx = tail_inx;
      while (DV_STRING == DV_TYPE_OF (tail_begin))
	{
	  strg_ctr++;
	  res_strg_len += (box_length (tail_begin) - 1);
	  tail_inx++;
	  if (tail_inx > new_filled_count)
	    break;
	  tail_begin = acc [tail_inx];
	}
      /* Concatenation with a previous string. This is possible only for the first args, hence the trick is OK */
      if ((res_strg_len > 0) && (filled_count > 0) && (DV_STRING == DV_TYPE_OF (acc [filled_count])))
        {
          res_strg_len += (box_length (acc [filled_count]) - 1);
          filled_count--;
          strg_ctr++;
        }
      switch (strg_ctr)
	{
	  default:
	    {
	      caddr_t res, res_tail, aux_strg;
	      int aux_strg_len;
	      if (0 == res_strg_len)
	        break;
	      res_tail = res = dk_alloc_box (res_strg_len + 1, DV_STRING);
	      while (strg_ctr-- > 0)
		{
		  aux_strg = acc [old_tail_inx];
		  aux_strg_len = box_length (aux_strg) - 1;
		  memcpy (res_tail, aux_strg, aux_strg_len);
		  res_tail += aux_strg_len;
		  dk_free_box (aux_strg);
		  acc [old_tail_inx++] = NULL;
		}
	      res_tail[0] = '\0';
#ifdef DEBUG
	      if (res_strg_len != (res_tail - res))
		GPF_T;
#endif
	      acc [++filled_count] = res;
	      break;
	    }
	  case 1:
	    if (0 == res_strg_len)
	      {
	        dk_free_box (acc [old_tail_inx]);
	        acc [old_tail_inx] = NULL;
	        break;
	      }
	    acc [++filled_count] = acc [old_tail_inx];
	    if (filled_count != old_tail_inx)
	      acc [old_tail_inx] = NULL;
	  case 0: ;/* do nothing */
	}
      if (tail_inx > new_filled_count)
	break;
      acc [++filled_count] = tail_begin;
      if (filled_count != tail_inx)
        acc [tail_inx] = NULL;
      tail_inx++;
    }
#ifdef DEBUG
  if (filled_count > new_filled_count)
    GPF_T;
  if (filled_count > (int)(BOX_ELEMENTS((caddr_t)acc)))
    GPF_T;
#endif
  if (filled_count != new_filled_count)
    memset (acc + 1 + filled_count, 0, sizeof (caddr_t) * (new_filled_count - filled_count));

  dk_free_box (acc[0]);
  acc[0] = box_num (filled_count);
  dk_check_xte_nodebld_acc (acc);
  return NULL;
}


caddr_t
bif_xte_nodebld_final_impl (caddr_t * qst, state_slot_t ** args, int plain_return)
{
  caddr_t *acc = NULL;
  caddr_t *head = NULL;
  size_t idx, filled_size;
  int arg_ctr = BOX_ELEMENTS(args);
  if (1 > arg_ctr)
    sqlr_new_error ("22003", "SR444", "Too few arguments for xte_nodebld_final");
  if (2 <= arg_ctr)
    {
      qst_swap_or_get_copy (qst, args[1], (caddr_t *)(&head));
      if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (head)) || (1 != (BOX_ELEMENTS (head) % 2)) || (DV_UNAME != DV_TYPE_OF (((caddr_t *)head)[0])))
	{
	  dk_free_tree ((caddr_t)head);
	  sqlr_new_error ("42000", "XTE04", "The second argument of function xte_nodebld_final() should be a value returned by xte_head()");
	}
    }
  qst_swap_or_get_copy (qst, args[0], (caddr_t *)(&acc));
  if (NODEBLD_ACC_IS_BAD(acc))
    {
      dtp_t acc_dtp = DV_TYPE_OF(acc);
      if ((DV_DB_NULL == acc_dtp) || ((DV_LONG_INT == acc_dtp) && (0 == unbox ((box_t) acc))))
        {
          dk_free_tree ((caddr_t)acc);
	  acc = (caddr_t *) list (1, box_num(0));
	}
      else
        {
	  dk_free_tree ((caddr_t)head);
          dk_free_tree ((caddr_t)acc);
          sqlr_new_error ("22003", "SR348", "The first argument of xte_nodebld_final is not made by xte_nodebld_init() function");
	}
    }
  filled_size = sizeof (caddr_t) * (unbox (acc[0]) + 1);
  dk_check_xte_nodebld_acc (acc);
  if (filled_size != box_length (acc))
    {
      caddr_t new_box = dk_alloc_box (filled_size, DV_ARRAY_OF_POINTER);
      memcpy (new_box, acc, filled_size);
      dk_free_box /*not ..._tree*/ ((caddr_t)acc);
      acc = (caddr_t *)new_box;
    }

/* This loop is to fix the case when the accumulated value is saved to the temp table. */
  for (idx = filled_size / sizeof (caddr_t); --idx > 0; /* no step*/ )
    {
      caddr_t **item = ((caddr_t **)(acc[idx]));
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (item))
        {
          caddr_t *head = XTE_HEAD (item);
          if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (head))
            {
              if (DV_UNAME != DV_TYPE_OF (XTE_HEAD_NAME (head)))
                xte_replace_strings_with_unames (item);
            }
          else if ((XMLATTRIBUTE_FLAG == (caddr_t)(head)) && (3 == BOX_ELEMENTS (item)))
            {
              dk_free_tree ((caddr_t)acc);
              sqlr_new_error ("22003", "SR621", "Attribute can not appear directly in an XML entity aggregate, it should be part of an XML element");
            }
/*
            {
              if (DV_STRING == DV_TYPE_OF (item[1]))
                item[1] = (void *)box_dv_uname_string ((caddr_t)(item[1]));
            }
*/
          else
            {
              dk_free_tree ((caddr_t)acc);
              sqlr_new_error ("22003", "SR620", "Inappropriate value is found in XML entity aggregate (neither vector of XML data nor a literal)");
            }
        }
    }

  if (2 <= arg_ctr)
    {
      dk_free_tree (acc[0]);
      acc[0] = (caddr_t)(head);
      if (plain_return)
	return (caddr_t) acc;
      qst_set (qst, args[0], (caddr_t) acc);
      return NULL;
    }
  return (caddr_t)acc;
}


caddr_t
bif_xte_nodebld_acc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_xte_nodebld_acc_impl (qst, args, 0, ((caddr_t **)(QST_GET_ADDR (qst, args[0]))));
}


caddr_t
bif_xte_nodebld_xmlagg_acc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_xte_nodebld_acc_impl (qst, args, 1, ((caddr_t **)(QST_GET_ADDR (qst, args[0]))));
}


caddr_t
bif_xte_nodebld_final (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_xte_nodebld_final_impl (qst, args, 0);
}


caddr_t
bif_xte_nodebld_xmlagg_final (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_xte_nodebld_final_impl (qst, args, 1);
}


caddr_t
bif_int_vectorbld_init (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *acc = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * 15 /*  2^n - 1 */ , DV_ARRAY_OF_LONG);
  if (1 > BOX_ELEMENTS (args))
    sqlr_new_error ("22003", "SR344", "Too few arguments for vectorbld_init");
  qst_set (qst, args[0], (caddr_t) acc);
  return NULL;
}


caddr_t
bif_int_vectorbld_acc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int acc_length, new_acc_length;
  int filled_count;		/* number of non-null elements in the first argument, excluding the counter */
  int argcount;			/* number of arguments in the call */
  int arg_inx;			/* index of current argument */
  int new_filled_count;		/* value of filled_count at the end of the procedure */
  int64 *acc = bif_array_arg (qst, args, 0, "int_vector_agg");
  caddr_t *dst;
  qi_signal_if_trx_error ((query_instance_t *) qst);
  if (1 > BOX_ELEMENTS (args))
    sqlr_new_error ("22003", "SR345", "Too few arguments for vectorbld_acc");
  argcount = BOX_ELEMENTS (args);
/* The following 'if' must not appear here, but this is a workaround for a weird error in aggr in nested select. */
  if (NULL == acc)
    {
      acc = (int64 *) dk_alloc_box_zero (sizeof (int64) * 15 /*  2^n - 1 */ , DV_ARRAY_OF_LONG);
      qst_set (qst, args[0], acc);
    }
  filled_count = acc[0];
  acc_length = BOX_ELEMENTS (acc);
  new_filled_count = filled_count;
  for (arg_inx = 1; arg_inx < argcount; arg_inx++)
    {
      if (DV_DB_NULL != DV_TYPE_OF (QST_GET (qst, args[arg_inx])))
	new_filled_count++;
    }

  for (new_acc_length = acc_length; (new_filled_count) >= new_acc_length; new_acc_length += (new_acc_length + 1));
      /* do nothing */ ;
  if (new_acc_length > MAX_BOX_ELEMENTS)
    sqlr_new_error ("22003", "SR346", "Out of memory allocation limits: the composed vector contains too many items");
  if (acc_length != new_acc_length)
    {
      caddr_t new_acc;
      if (NULL == (new_acc = dk_try_alloc_box (sizeof (int64) * new_acc_length, DV_ARRAY_OF_LONG)))
	qi_signal_if_trx_error ((query_instance_t *) qst);
      memset (new_acc, 0, sizeof (int64) * new_acc_length);
      memcpy (new_acc, acc, sizeof (int64) * acc_length);
      qst_set (qst, args[0], new_acc);
      acc = new_acc;
      acc_length = new_acc_length;
    }
  dst = acc + filled_count + 1;
  for (arg_inx = 1; arg_inx < argcount; arg_inx++)
    {
      caddr_t arg = QST_GET (qst, args[arg_inx]);
      if (DV_DB_NULL == DV_TYPE_OF (arg))
	continue;
      dst[0] = unbox_iri_int64 (arg);
      dst++;
    }
  /* Now we know what's the precise value of new_filled_count */
  acc[0] = new_filled_count;
  return NULL;
}


caddr_t
bif_int_vectorbld_final (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int64 *acc = NULL, new_box;
  size_t filled_size;
  int arg_ctr = BOX_ELEMENTS (args);
  if (1 > arg_ctr)
    sqlr_new_error ("22003", "SR444", "Too few arguments for vectorbld_final");
  qst_swap_or_get_copy (qst, args[0], (int64 *) (&acc));
  filled_size = sizeof (int64) * acc[0];
  new_box = dk_alloc_box (filled_size, DV_ARRAY_OF_LONG);
  memcpy (new_box, acc + 1, filled_size);
  return new_box;
}


caddr_t
bif_vectorbld_init (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * acc = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * 15 /*  2^n - 1 */, DV_ARRAY_OF_POINTER);
  if (1 > BOX_ELEMENTS(args))
    sqlr_new_error ("22003", "SR344", "Too few arguments for vectorbld_init");
  dk_check_vectorbld_acc (acc);
  qst_set (qst, args[0], (caddr_t) acc);
  return NULL;
}

#define bif_vectorbld_acc_impl_BIT_PRESERVE_ARGS 1
#define bif_vectorbld_acc_impl_BIT_IGNORE_NULLS 2

caddr_t
bif_vectorbld_acc_impl (caddr_t * qst, state_slot_t ** args, int flags, caddr_t **acc_ptr)
{
  int acc_length, new_acc_length;
  int filled_count;	/* number of non-null elements in the first argument, excluding the counter */
  int argcount;		/* number of arguments in the call */
  int arg_inx;		/* index of current argument */
  int new_filled_count;  /* value of filled_count at the end of the procedure */
  caddr_t *acc = acc_ptr[0];
  caddr_t *dst;
  qi_signal_if_trx_error ((query_instance_t *)qst);
  if (1 > BOX_ELEMENTS(args))
    sqlr_new_error ("22003", "SR345", "Too few arguments for vectorbld_acc");
  argcount = BOX_ELEMENTS (args);
/* The following 'if' must not appear here, but this is a workaround for a weird error in aggr in nested select. */
  if (NULL == acc)
    {
      acc = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * 15 /*  2^n - 1 */, DV_ARRAY_OF_POINTER);
      acc_ptr[0] = acc; /* No free before because it was NULL */
    }
  dk_check_vectorbld_acc (acc);
  if (NODEBLD_ACC_IS_BAD(acc))
    sqlr_new_error ("22003", "SR346", "The first argument of vectorbld_acc is not made by vectorbld_init() function");
  filled_count = (int) unbox (acc[0]);
  acc_length = BOX_ELEMENTS (acc);
  if (flags & bif_vectorbld_acc_impl_BIT_IGNORE_NULLS)
    {
      new_filled_count = filled_count;
      for (arg_inx = 1; arg_inx < argcount; arg_inx++)
        {
          if (DV_DB_NULL != DV_TYPE_OF (QST_GET (qst, args[arg_inx])))
            new_filled_count++;
        }
    }
  else
  new_filled_count = filled_count + argcount - 1;
  for (new_acc_length = acc_length; (new_filled_count) >= new_acc_length; new_acc_length += (new_acc_length + 1)); /* do nothing */;
  if (new_acc_length > MAX_BOX_ELEMENTS)
    sqlr_new_error ("22003", "SR346", "Out of memory allocation limits: the composed vector contains too many items");
  if (acc_length != new_acc_length)
    {
      caddr_t new_acc;
      if (NULL == (new_acc = dk_try_alloc_box (sizeof (caddr_t) * new_acc_length, DV_ARRAY_OF_POINTER)))
	qi_signal_if_trx_error ((query_instance_t *)qst);
      memset (new_acc, 0, sizeof (caddr_t) * new_acc_length);
      memcpy (new_acc, acc, sizeof (caddr_t) * acc_length);
      dk_free_box (acc);
      acc_ptr[0] = acc = (caddr_t *)new_acc;
      acc_length = new_acc_length;
      dk_check_vectorbld_acc (acc);
    }
  dst = acc + filled_count + 1;
  for (arg_inx = 1; arg_inx < argcount; arg_inx++)
    {
      caddr_t arg = QST_GET (qst, args[arg_inx]);
      if ((flags & bif_vectorbld_acc_impl_BIT_IGNORE_NULLS) && (DV_DB_NULL == DV_TYPE_OF (arg)))
        continue;
      dst[0] = arg;
      if (flags & bif_vectorbld_acc_impl_BIT_PRESERVE_ARGS)
    	dst[0] = box_try_copy_tree (dst[0], NULL);
      else
	{
	  dst[0] = NULL;
	  qst_swap_or_get_copy (qst, args[arg_inx], dst);
	}
      dst++;
    }
  dk_check_vectorbld_acc (acc);
#ifdef AGG_DEBUG
  for (arg_inx = 1; arg_inx < argcount; arg_inx++)
    {
      int tmp_inx;
      DO_BOX_FAST (caddr_t, el, tmp_inx, acc)
        {
          if (IS_BOX_POINTER(el) && (el == QST_GET (qst, args[arg_inx])))
            GPF_T;
        }
      END_DO_BOX_FAST;
    }
#endif
  /* Now we know what's the precise value of new_filled_count */
#ifdef DEBUG
  if (new_filled_count > (int)(BOX_ELEMENTS((caddr_t)acc)))
    GPF_T;
#endif
  dk_free_box (acc[0]);
  acc[0] = box_num (new_filled_count);
  dk_check_vectorbld_acc (acc);
  return NULL;
}


caddr_t
bif_vectorbld_concat_acc_impl (caddr_t * qst, state_slot_t ** args, int preserve_args, caddr_t **acc_ptr)
{
  int acc_length, new_acc_length;
  int filled_count;	/* number of non-null elements in the first argument, excluding the counter */
  int argcount;		/* number of arguments in the call */
  int arg_inx;		/* index of current argument */
  int new_filled_count;  /* value of filled_count at the end of the procedure */
  caddr_t *acc = acc_ptr[0];
  caddr_t *dst;
  qi_signal_if_trx_error ((query_instance_t *)qst);
  if (1 > BOX_ELEMENTS(args))
    sqlr_new_error ("22003", "SR345", "Too few arguments for vectorbld_concat_acc()");
  argcount = BOX_ELEMENTS (args);
  new_filled_count = 0;
  for (arg_inx = 1; arg_inx < argcount; arg_inx++)
    {
      caddr_t addon = QST_GET (qst, args[arg_inx]);
      dtp_t addon_dtp = DV_TYPE_OF (addon);
      switch (addon_dtp)
        {
        case DV_ARRAY_OF_POINTER:
          new_filled_count += BOX_ELEMENTS (addon);
          break;
        case DV_DB_NULL:
          break;
        default:
          sqlr_new_error ("22003", "SR475", "The argument %d of vectorbld_concat_acc() is of type %d (%s), should be array or null", arg_inx+1, addon_dtp, dv_type_title (addon_dtp));
        }
    }
/* The following 'if' must not appear here, but this is a workaround for a weird error in aggr in nested select. */
  if (NULL == acc)
    {
      acc = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * 15 /*  2^n - 1 */, DV_ARRAY_OF_POINTER);
      acc_ptr[0] = acc; /* No free before because it was NULL */
    }
  dk_check_vectorbld_acc (acc);
  if (NODEBLD_ACC_IS_BAD(acc))
    sqlr_new_error ("22003", "SR346", "The first argument of vectorbld_acc is not made by vectorbld_init() function");
  filled_count = (int) unbox (acc[0]);
  acc_length = BOX_ELEMENTS (acc);
  new_filled_count += filled_count;
  for (new_acc_length = acc_length; (new_filled_count) >= new_acc_length; new_acc_length += (new_acc_length + 1)); /* do nothing */;
  if (new_acc_length > MAX_BOX_ELEMENTS)
    sqlr_new_error ("22003", "SR346", "Out of memory allocation limits: the composed vector contains too many items");
  if (acc_length != new_acc_length)
    {
      caddr_t new_acc;
      if (NULL == (new_acc = dk_try_alloc_box (sizeof (caddr_t) * new_acc_length, DV_ARRAY_OF_POINTER)))
	qi_signal_if_trx_error ((query_instance_t *)qst);
      memset (new_acc, 0, sizeof (caddr_t) * new_acc_length);
      memcpy (new_acc, acc, sizeof (caddr_t) * acc_length);
      dk_free_box (acc);
      acc_ptr[0] = acc = (caddr_t *)new_acc;
      acc_length = new_acc_length;
      dk_check_vectorbld_acc (acc);
    }
  dst = acc + filled_count + 1;
  for (arg_inx = 1; arg_inx < argcount; arg_inx++)
    {
      caddr_t addon = QST_GET (qst, args[arg_inx]);
      size_t addon_len;
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (addon))
        continue;
      if (preserve_args)
    	addon = box_try_copy_tree (addon, NULL);
      else
	{
	  addon = NULL;
	  qst_swap_or_get_copy (qst, args[arg_inx], &addon);
	}
      addon_len = BOX_ELEMENTS (addon);
      memcpy (dst, addon, sizeof (caddr_t) * addon_len);
      dst += addon_len;
      dk_free_box /* not ..._tree */ (addon);
    }
  dk_check_vectorbld_acc (acc);
#ifdef AGG_DEBUG
  for (arg_inx = 1; arg_inx < argcount; arg_inx++)
    {
      int tmp_inx;
      DO_BOX_FAST (caddr_t, el, tmp_inx, acc)
        {
          if (IS_BOX_POINTER(el) && (el == QST_GET (qst, args[arg_inx])))
            GPF_T;
        }
      END_DO_BOX_FAST;
    }
#endif
#ifdef DEBUG
  if (new_filled_count > (int)(BOX_ELEMENTS((caddr_t)acc)))
    GPF_T;
#endif
  dk_free_box (acc[0]);
  acc[0] = box_num (new_filled_count);
  dk_check_vectorbld_acc (acc);
  return NULL;
}

caddr_t
bif_vectorbld_final_impl (caddr_t * qst, state_slot_t ** args, int return_bits)
{
  caddr_t *acc = NULL, new_box;
  size_t filled_size;
  int arg_ctr = BOX_ELEMENTS(args);
  if (1 > arg_ctr)
    sqlr_new_error ("22003", "SR444", "Too few arguments for vectorbld_final");
  qst_swap_or_get_copy (qst, args[0], (caddr_t *)(&acc));
  if (NODEBLD_ACC_IS_BAD(acc))
    {
      dtp_t acc_dtp = DV_TYPE_OF(acc);
      if ((DV_DB_NULL == acc_dtp) || ((DV_LONG_INT == acc_dtp) && (0 == unbox ((box_t) acc))))
        {
          dk_free_tree ((caddr_t)acc);
	  acc = (caddr_t *) list (1, box_num(0));
	}
      else
        {
          dk_free_tree ((caddr_t)acc);
          sqlr_new_error ("22003", "SR348", "The first argument of vectorbld_final is not made by vectorbld_init() function");
	}
    }
  filled_size = sizeof (caddr_t) * (unbox (acc[0]));
  dk_check_vectorbld_acc (acc);
  dk_free_box (acc[0]);
  if ((0 == filled_size) && (2 & return_bits))
    {
      new_box = NEW_DB_NULL;
      acc[0] = NULL;
      dk_free_tree ((caddr_t)acc);
    }
  else
    {
      new_box = dk_alloc_box (filled_size, DV_ARRAY_OF_POINTER);
  memcpy (new_box, acc + 1, filled_size);
  dk_free_box /*not ..._tree*/ ((caddr_t)acc);
    }
  acc = (caddr_t *)new_box;
  if (1 & return_bits)
    return (caddr_t) acc;
  qst_set (qst, args[0], (caddr_t) acc);
  return NULL;
}


caddr_t
bif_vectorbld_length (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *acc = NULL;
  acc = (caddr_t *)bif_arg (qst, args, 0, "vectorbld_length");
  if (NODEBLD_ACC_IS_BAD(acc))
    return box_num (0);
  return box_copy (acc[0]);
}


caddr_t
bif_vectorbld_crop (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *acc = NULL;
  ptrlong from = bif_long_arg (qst, args, 1, "vectorbld_crop");
  ptrlong to = bif_long_arg (qst, args, 2, "vectorbld_crop");
  ptrlong do_copy = bif_long_arg (qst, args, 3, "vectorbld_crop");
  ptrlong old_len;
  caddr_t *res;
  if (from > to)
    sqlr_new_error ("22003", "SR477", "Argument #2 (value %ld) is greater than argument #3 (value %ld) in call of vectorbld_crop ()", from, to);
  if (from < 0)
    sqlr_new_error ("22003", "SR477", "Argument #2 (value %ld) is negative in call of vectorbld_crop()", from);
  acc = (caddr_t *)qst_get (qst, args[0]);
  old_len = (NODEBLD_ACC_IS_BAD(acc) ? 0 : unbox (acc[0]));
  if (to > old_len)
    sqlr_new_error ("22003", "SR477", "Argument #3 (value %ld) is greater than the length of vector in call of vectorbld_crop ()", to);
  if (from == to)
    {
      res = (caddr_t *)list (1, 0);
      if (do_copy)
        return (caddr_t) res;
      qst_set (qst, args[0], (caddr_t) res);
      return NULL;
    }
  if (do_copy)
    {
      ptrlong src, tgt;
      res = (caddr_t *) dk_alloc_box_zero ((1 + to - from) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      tgt = 1;
      for (src = from; src < to; src++)
        res [tgt++] = box_copy_tree (acc [1 + src]);
      res [0] = box_num (to - from);
      return (caddr_t) res;
    }
  else
    {
      ptrlong src, tgt;
      int swapped = qst_swap_or_get_copy (qst, args[0], (caddr_t *)(&acc));
      if (0 < from)
        {
          for (tgt = 1; tgt <= from; tgt++)
            {
              dk_free_tree (acc [tgt]);
              acc [tgt] = NULL;
            }
          tgt = 1;
          for (src = from + 1; src <= to; src++) /* shifts like '+1' and '<=' is because acc [0] is size */
            {
              acc [tgt] = acc [src];
              acc [src] = NULL;
            }
        }
      for (src = to + 1; src <= old_len; src++) /* shifts like '+1' and '<=' is because acc [0] is size */
        {
          dk_free_tree (acc [src]);
          acc [src] = NULL;
        }
      dk_free_box (acc [0]);
      acc [0] = box_num (to - from);
      if (!swapped)
        qst_set (qst, args[0], (caddr_t) acc);
    }
  return NULL;
}


caddr_t
bif_vectorbld_acc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_vectorbld_acc_impl (qst, args, 0, ((caddr_t **)(QST_GET_ADDR (qst, args[0]))));
}


caddr_t
bif_vectorbld_agg_acc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_vectorbld_acc_impl (qst, args, bif_vectorbld_acc_impl_BIT_PRESERVE_ARGS, ((caddr_t **)(QST_GET_ADDR (qst, args[0]))));
}


caddr_t
bif_vector_of_nonnulls_bld_agg_acc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_vectorbld_acc_impl (qst, args, bif_vectorbld_acc_impl_BIT_PRESERVE_ARGS | bif_vectorbld_acc_impl_BIT_IGNORE_NULLS, ((caddr_t **)(QST_GET_ADDR (qst, args[0]))));
}


caddr_t
bif_vectorbld_concat_acc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_vectorbld_concat_acc_impl (qst, args, 0, ((caddr_t **)(QST_GET_ADDR (qst, args[0]))));
}


caddr_t
bif_vectorbld_concat_agg_acc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_vectorbld_concat_acc_impl (qst, args, 1, ((caddr_t **)(QST_GET_ADDR (qst, args[0]))));
}


caddr_t
bif_vectorbld_final (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_vectorbld_final_impl (qst, args, 0);
}


caddr_t
bif_vectorbld_agg_final (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_vectorbld_final_impl (qst, args, 1);
}


caddr_t
bif_vector_or_null_bld_agg_final (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_vectorbld_final_impl (qst, args, 3);
}


caddr_t
bif_xq_sequencebld_init (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * acc = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * 15 /*  2^n - 1 */, DV_ARRAY_OF_POINTER);
  if (1 > BOX_ELEMENTS(args))
    sqlr_new_error ("22003", "SR344", "Too few arguments for xq_sequencebld_init");
  dk_check_vectorbld_acc (acc);
  qst_set (qst, args[0], (caddr_t) acc);
  return NULL;
}


static int xq_box_recursive_length (caddr_t box)
{
  switch (DV_TYPE_OF (box))
    {
    case DV_DB_NULL: return 0;
    case DV_ARRAY_OF_XQVAL: return BOX_ELEMENTS (box);
    case DV_ARRAY_OF_POINTER:
      {
	int ctr, len, res;
	len = BOX_ELEMENTS (box);
	res = 0;
	for (ctr = 0; ctr < len; ctr++)
          {
	    caddr_t itm = ((caddr_t *)box)[ctr];
            switch (DV_TYPE_OF (itm))
	      {
	      case DV_DB_NULL: continue;
              case DV_ARRAY_OF_XQVAL: res += len; continue;
              case DV_ARRAY_OF_POINTER: res += xq_box_recursive_length (((caddr_t *)box)[ctr]); continue;
              default: res++;
              }
	  }
        return res;
      }
    default: return 1;
    }
}


static void xq_box_flatten (caddr_t * qst, caddr_t **box_ptr, caddr_t **dst_ptr, int boxes_are_utf8)
{
  int ctr, len;
  switch (DV_TYPE_OF (box_ptr[0]))
    {
    case DV_DB_NULL: return;
    case DV_ARRAY_OF_XQVAL:
      {
        len = BOX_ELEMENTS (box_ptr[0]);
        for (ctr = 0; ctr < len; ctr++)
          {
            dst_ptr[0][ctr] = box_ptr[0][ctr];
            box_ptr[0][ctr] = NULL;
          }
        dst_ptr[0] += len;
        return;
      }
    case DV_ARRAY_OF_POINTER:
      {
        len = BOX_ELEMENTS (box_ptr[0]);
	for (ctr = 0; ctr < len; ctr++)
          {
	    caddr_t itm = box_ptr[0][ctr];
            switch (DV_TYPE_OF (itm))
	      {
	      case DV_DB_NULL: continue;
              case DV_ARRAY_OF_XQVAL:
                xq_box_flatten (qst, (caddr_t **)(box_ptr[0] + ctr), dst_ptr, 1); continue;
              case DV_ARRAY_OF_POINTER:
                xq_box_flatten (qst, (caddr_t **)(box_ptr[0] + ctr), dst_ptr, 0); continue;
	      case DV_WIDE: case DV_LONG_WIDE:
		dst_ptr[0][0] = box_cast_to_UTF8 (qst, itm);
		dst_ptr[0] += 1;
		break;
	      case DV_SHORT_STRING:
		if (!boxes_are_utf8)
		  {
		    dst_ptr[0][0] = box_cast_to_UTF8 (qst, itm);
		    dst_ptr[0] += 1;
		    break;
		  }
		/* no break */
              default:
	        dst_ptr[0][0] = itm;
		box_ptr[0][ctr] = NULL;
	        dst_ptr[0] += 1;
	        continue;
              }
	  }
        return;
      }
    case DV_WIDE: case DV_LONG_WIDE:
      dst_ptr[0][0] = box_cast_to_UTF8 (qst, (caddr_t)(box_ptr[0]));
      dst_ptr[0] += 1;
      break;
    case DV_SHORT_STRING:
      if (!boxes_are_utf8)
        {
	  dst_ptr[0][0] = box_cast_to_UTF8 (qst, (caddr_t)(box_ptr[0]));
	  dst_ptr[0] += 1;
	  break;
        }
      /* no break */
    default:
      dst_ptr[0][0] = (caddr_t)(box_ptr[0]);
      box_ptr[0] = NULL;
      dst_ptr[0] += 1;
      return;
    }
}


caddr_t
bif_xq_sequencebld_acc_impl (caddr_t * qst, state_slot_t ** args, int preserve_args, caddr_t **acc_ptr)
{
  int acc_length, new_acc_length;
  int filled_count;	/* number of non-null elements in the first argument, excluding the counter */
  int argcount;		/* number of arguments in the call */
  int arg_inx;		/* index of current argument */
  int new_filled_count;  /* value of filled_count at the end of the procedure */
  caddr_t *acc = acc_ptr[0];
  caddr_t *dst;
  qi_signal_if_trx_error ((query_instance_t *)qst);
  if (1 > BOX_ELEMENTS(args))
    sqlr_new_error ("22003", "SR345", "Too few arguments for xq_sequencebld_concat_acc()");
  argcount = BOX_ELEMENTS (args);
  new_filled_count = 0;
  for (arg_inx = 1; arg_inx < argcount; arg_inx++)
    new_filled_count += xq_box_recursive_length (QST_GET (qst, args[arg_inx]));
/* The following 'if' must not appear here, but this is a workaround for a weird error in aggr in nested select. */
  if (NULL == acc)
    {
      acc = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * 15 /*  2^n - 1 */, DV_ARRAY_OF_POINTER);
      acc_ptr[0] = acc; /* No free before because it was NULL */
    }
  dk_check_vectorbld_acc (acc);
  if (NODEBLD_ACC_IS_BAD(acc))
    sqlr_new_error ("22003", "SR346", "The first argument of xq_sequencebld_acc is not made by xq_sequencebld_init() function");
  filled_count = (int) unbox (acc[0]);
  acc_length = BOX_ELEMENTS (acc);
  new_filled_count += filled_count;
  for (new_acc_length = acc_length; (new_filled_count) >= new_acc_length; new_acc_length += (new_acc_length + 1)); /* do nothing */;
  if (new_acc_length > MAX_BOX_ELEMENTS)
    sqlr_new_error ("22003", "SR346", "Out of memory allocation limits: the composed vector contains too many items");
  if (acc_length != new_acc_length)
    {
      caddr_t new_acc;
      if (NULL == (new_acc = dk_try_alloc_box (sizeof (caddr_t) * new_acc_length, DV_ARRAY_OF_POINTER)))
	qi_signal_if_trx_error ((query_instance_t *)qst);
      memset (new_acc, 0, sizeof (caddr_t) * new_acc_length);
      memcpy (new_acc, acc, sizeof (caddr_t) * acc_length);
      dk_free_box (acc);
      acc_ptr[0] = acc = (caddr_t *)new_acc;
      acc_length = new_acc_length;
      dk_check_vectorbld_acc (acc);
    }
  dst = acc + filled_count + 1;
  for (arg_inx = 1; arg_inx < argcount; arg_inx++)
    {
      caddr_t addon;
      if (preserve_args)
        addon = box_try_copy_tree (QST_GET (qst, args[arg_inx]), NULL);
      else
        {
          addon = NULL;
          qst_swap_or_get_copy (qst, args[arg_inx], &addon);
        }
      xq_box_flatten (qst, (caddr_t **)(&addon), &dst, 0);
      dk_free_tree (addon);
    }
  dk_check_vectorbld_acc (acc);
#ifdef AGG_DEBUG
  for (arg_inx = 1; arg_inx < argcount; arg_inx++)
    {
      int tmp_inx;
      DO_BOX_FAST (caddr_t, el, tmp_inx, acc)
        {
          if (IS_BOX_POINTER(el) && (el == QST_GET (qst, args[arg_inx])))
            GPF_T;
        }
      END_DO_BOX_FAST;
    }
#endif
#ifdef DEBUG
  if (new_filled_count > (int)(BOX_ELEMENTS((caddr_t)acc)))
    GPF_T;
#endif
  dk_free_box (acc[0]);
  acc[0] = box_num (new_filled_count);
  dk_check_vectorbld_acc (acc);
  return NULL;
}


caddr_t
bif_xq_sequencebld_final_impl (caddr_t * qst, state_slot_t ** args, int plain_return)
{
  caddr_t *acc = NULL, new_box;
  size_t filled_size;
  int arg_ctr = BOX_ELEMENTS(args);
  if (1 > arg_ctr)
    sqlr_new_error ("22003", "SR444", "Too few arguments for xq_sequencebld_final");
  qst_swap_or_get_copy (qst, args[0], (caddr_t *)(&acc));
  if (NODEBLD_ACC_IS_BAD(acc))
    {
      dtp_t acc_dtp = DV_TYPE_OF(acc);
      if ((DV_DB_NULL == acc_dtp) || ((DV_LONG_INT == acc_dtp) && (0 == unbox ((box_t) acc))))
        {
          dk_free_tree ((caddr_t)acc);
	  acc = (caddr_t *) list (1, box_num(0));
	}
      else
        {
          dk_free_tree ((caddr_t)acc);
          sqlr_new_error ("22003", "SR348", "The first argument of xq_sequencebld_final is not made by xq_sequencebld_init() function");
	}
    }
  filled_size = sizeof (caddr_t) * (unbox (acc[0]));
  dk_check_vectorbld_acc (acc);
  new_box = dk_alloc_box (filled_size, DV_ARRAY_OF_XQVAL);
  dk_free_box (acc[0]);
  memcpy (new_box, acc + 1, filled_size);
  dk_free_box /*not ..._tree*/ ((caddr_t)acc);
  acc = (caddr_t *)new_box;
  if (plain_return)
    return (caddr_t) acc;
  qst_set (qst, args[0], (caddr_t) acc);
  return NULL;
}


caddr_t
bif_xq_sequencebld_acc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_xq_sequencebld_acc_impl (qst, args, 0, ((caddr_t **)(QST_GET_ADDR (qst, args[0]))));
}


caddr_t
bif_xq_sequencebld_agg_acc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_xq_sequencebld_acc_impl (qst, args, 1, ((caddr_t **)(QST_GET_ADDR (qst, args[0]))));
}


caddr_t
bif_xq_sequencebld_final (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_xq_sequencebld_final_impl (qst, args, 0);
}


caddr_t
bif_xq_sequencebld_agg_final (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_xq_sequencebld_final_impl (qst, args, 1);
}


caddr_t
bif_xte_node (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int args_length = BOX_ELEMENTS (args), filled_size = 0;
  caddr_t *acc = NULL;
  if (args_length == 0)
    sqlr_new_error ("42000", "XTE02", "Function xte_node() should have at least one parameter");
#if 1
  acc = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * 15 /*  2^n - 1 */, DV_ARRAY_OF_POINTER);
  QR_RESET_CTX
    {
      caddr_t head = bif_arg (qst, args, 0, "xte_node");
      if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (head)) || (1 != (BOX_ELEMENTS (head) % 2)) || (DV_UNAME != DV_TYPE_OF (((caddr_t *)head)[0])))
	sqlr_new_error ("42000", "XTE03", "The first argument of function xte_node() should be a value returned by xte_head()");
      bif_xte_nodebld_acc_impl (qst, args, 0, &acc);
      filled_size = sizeof (caddr_t) * (unbox (acc[0]) + 1);
      dk_check_xte_nodebld_acc (acc);
      acc [0] = box_copy_tree (head);
    }
  QR_RESET_CODE
    {

      du_thread_t * self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      dk_free_tree ((caddr_t)acc);
      POP_QR_RESET;
      sqlr_resignal (err);
    }
  END_QR_RESET;
  if (filled_size != box_length (acc))
    {
      caddr_t new_box = dk_alloc_box (filled_size, DV_ARRAY_OF_POINTER);
      memcpy (new_box, acc, filled_size);
      dk_free_box /*not ..._tree*/ ((caddr_t)acc);
      acc = (caddr_t *)new_box;
    }
  return (caddr_t)(acc);
#else
  acc = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * args_length, DV_ARRAY_OF_POINTER);
  for (inx = 1; inx < args_length; inx++)
    {
      caddr_t current = bif_arg (qst, args, inx, "xte_node");
      caddr_t next = NULL;
      if (DV_STRING == DV_TYPE_OF (current))
	{
	  for ( ; ++inx < args_length; )
	    {
	      next = bif_arg (qst, args, inx, "xte_node");
	      if (DV_STRING == DV_TYPE_OF (next))
		{
		  current = string_concat (current, next);
		  next = NULL;
		}
	      else break;
	    }
	}
      if ((DV_STRING != DV_TYPE_OF (current)) || (1 < box_length (current)))
        {
	  acc [box_inx++] = box_copy_tree (current);
	}
      if (next)
	acc [box_inx++] = box_copy_tree (next);
    }
  acc [0] = box_copy_tree (bif_arg (qst, args, 0, "xte_node"));
  if (box_inx != args_length)
    {
      ptrlong new_size = sizeof (caddr_t) * (box_inx);
      caddr_t new_box = dk_alloc_box (new_size, DV_ARRAY_OF_POINTER);
      memcpy (new_box, acc, new_size);
      dk_free_box /* not dk_free_tree */ ((caddr_t)acc);
      acc = (caddr_t *)new_box;
    }
  return (caddr_t)(acc);
#endif
}


caddr_t
bif_xte_node_from_nodebld (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t tag = NULL;
  caddr_t * acc = NULL;
  int len, ctr;
  if (2 > BOX_ELEMENTS(args))
    sqlr_new_error ("22003", "SR349", "Too few arguments for xte_node_from_nodebld()");
  qst_swap_or_get_copy (qst, args[0], &tag);
  qst_swap_or_get_copy (qst, args[1], (caddr_t *)(&acc));
  if (NODEBLD_ACC_IS_BAD(acc))
    {
      dk_free_tree (tag);
      dk_free_tree ((caddr_t)acc);
      sqlr_new_error ("22003", "SR350", "The second argument of xte_node_from_nodebld() is not made by xte_nodebld_init() function");
    }
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (tag))
    goto bad_tag; /* see below */
  len = BOX_ELEMENTS(tag);
  if (!(len % 2))
    goto bad_tag; /* see below */
  for (ctr = len; ctr--; /* no step */)
    {
      caddr_t item = ((caddr_t *)tag)[ctr];
      dtp_t item_dtp = DV_TYPE_OF (item);
      if (ctr && !(ctr % 2)) /* if value */
        {
          switch (item_dtp)
            {
            case DV_UNAME:
            {
              caddr_t str = box_dv_short_nchars (item, box_length (item) - 1);
              dk_free_box (item);
              ((caddr_t *)tag)[ctr] = str;
              break;
            }
            case DV_STRING:
              break;
            default: goto bad_tag;
            }
        }
      else
        {
          switch (item_dtp)
            {
            case DV_STRING:
            {
              caddr_t name = box_dv_uname_nchars (item, box_length (item) - 1);
              dk_free_box (item);
              ((caddr_t *)tag)[ctr] = name;
            }
            case DV_UNAME:
              break;
            default: goto bad_tag;
            }
        }
    }
  dk_free_tree (acc[0]);
  acc[0] = tag;
  return (caddr_t) acc;

bad_tag:
  dk_free_tree (tag);
  dk_free_tree ((caddr_t)acc);
  sqlr_new_error ("22003", "SR468", "The first argument of xte_node_from_nodebld() is not an appropriate vector");
  return NULL;
}


caddr_t sql_xml_var_transform (caddr_t box)
{
  int lastcolon = -1, inx;
  int length;
  int new_length;
  unsigned char *narrow_box = (unsigned char *)box;
  wchar_t *wide_box = NULL;
  caddr_t new_box;
  unsigned char *tail;
  if (DV_UNAME == box_tag (box))
    return box_copy (box);
  if (DV_WIDE == box_tag (box))
    {
      wide_box = (wchar_t *)box;
      length = (box_length (box) / sizeof (wchar_t)) - 1;
    }
  else
    length = box_length (box) - 1;
#ifdef DEBUG
  if (DV_STRING != box_tag (box))
     GPF_T;
#endif
  new_length = length;
  inx = length;
  while (inx-- > 0)
    {
      unsigned int curr = ((NULL != wide_box) ? (unsigned)(wide_box[inx]) : (unsigned)(narrow_box[inx]));
      if (':' == curr) /* The rightmost colon */
        {
          lastcolon = inx;
          break;
        }
      if ((curr & ~0x7f) || !(isalnum (curr) || ('-' == curr) || ('.' == curr) || ('_' == curr)))
	new_length += 6; /* 7 in total hence 6 extra + 1 of normal length */
    }
  if ((NULL == wide_box) && (new_length == length)) return box_dv_uname_nchars (box, length);
  new_box = box_dv_ubuf (new_length);
  tail = (unsigned char *)new_box;
  for (inx = 0; inx < length; inx++)
    {
      static char hexes[] = "0123456789ABCDEF";
      unsigned int curr = ((NULL != wide_box) ? (unsigned)(wide_box[inx]) : (unsigned)(narrow_box[inx]));
      if ((inx > lastcolon) && ((curr & ~0x7f) || !(isalnum (curr) || ('-' == curr) || ('.' == curr) || ('_' == curr))))
	{
	  (tail++)[0] = '_';
	  (tail++)[0] = 'x';
	  (tail++)[0] = hexes[(curr & 0xF000) >> 12];
	  (tail++)[0] = hexes[(curr & 0x0F00) >> 8];
	  (tail++)[0] = hexes[(curr & 0x00F0) >> 4];
	  (tail++)[0] = hexes[(curr & 0x000F)];
	  (tail++)[0] = '_';
	}
      else
	(tail++)[0] = curr;
    }
  (tail++)[0] = '\0';
  return box_dv_uname_from_ubuf (new_box);
}


static int
bif_to_xml_array_push_new_attr (dk_set_t *head_set, caddr_t attr_name,
    int copy_name, caddr_t attr_value)
{
  s_node_t *iter = *head_set;
  if (DV_STRING == DV_TYPE_OF (attr_name))
    {
      caddr_t uname = box_dv_uname_nchars (attr_name, box_length (attr_name) - 1);
      if (copy_name)
        copy_name = 0;
      else
        dk_free_box (attr_name);
      attr_name = uname;
    }
  while (iter && iter->next)
    {
      char *name = (char *) iter->next->data;
      if (name == attr_name)
	{
	  if (((char *) iter->data)[0] != ' ')
	    {
	      dk_free_tree ((box_t) iter->data);
	      iter->data = attr_value;
	      return 0;
	    }
	}
      iter = iter->next->next;
    }
  dk_set_push (head_set, copy_name ? box_copy (attr_name) : attr_name);
  dk_set_push (head_set, attr_value);
  return 1;
}

void
bif_to_xml_array_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func,
    dk_set_t *ret_set, dk_set_t *head_set)
{
  caddr_t elem = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (elem);
  int elem_is_writeable;
  caddr_t to_be_deleted;
  switch (dtp)
    {
      case DV_ARRAY_OF_POINTER:
#if 0 /* To fix bug 8802 */
        elem_is_writeable = args[nth]->ssl_is_callret;
        if (elem_is_writeable)
	  {
	    QST_GET_V(qst,args[nth]) = NULL;
            to_be_deleted = elem;
	  }
        else
          to_be_deleted = NULL;
#else
	elem_is_writeable = 0;
        to_be_deleted = NULL;
#endif
	if (BOX_ELEMENTS (elem) < 1)
	  sqlr_new_error ("37000", "XI027", "Argument of %s must be valid xml entity.", func);

	  if ((((caddr_t *) elem)[0]) == XMLATTRIBUTE_FLAG)
	    { /* XMLATTRIBUTES */
	      int inx, attr_length = BOX_ELEMENTS (elem);

	      for (inx = 1; inx < attr_length; inx += 2)
		{
		  if (elem_is_writeable)
		    {
		      if (bif_to_xml_array_push_new_attr (head_set, ((caddr_t *) elem)[inx], 0,
			  ((caddr_t *) elem)[inx + 1]))
			((caddr_t *) elem)[inx] = NULL;
		      ((caddr_t *) elem)[inx + 1] = NULL;
		    }
		  else
		    bif_to_xml_array_push_new_attr (head_set, ((caddr_t *) elem)[inx], 1,
			box_copy_tree (((caddr_t *) elem)[inx + 1]));
		}
              goto array_arg_done;
	    }
	if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (((caddr_t *)elem)[0]) || BOX_ELEMENTS (((caddr_t *)elem)[0]) < 1)
	  sqlr_new_error ("37000", "XI027", "Argument of %s must be valid xml entity.", func);
        if (DV_UNAME != DV_TYPE_OF (XTE_HEAD_NAME (XTE_HEAD (elem))))
          {
            if (!elem_is_writeable)
              {
                to_be_deleted = elem = box_copy_tree (elem);
                elem_is_writeable = 1;
              }
            xte_replace_strings_with_unames ((caddr_t **)elem);
          }
	if (uname__root == XTE_HEAD_NAME(XTE_HEAD (elem)))
	    { /* root elem */
	      int inx;
	      int length = BOX_ELEMENTS (elem);
	      for (inx = 1; inx < length; inx++)
		{
		  if (elem_is_writeable)
		    {
		      dk_set_push (ret_set, ((caddr_t *) elem)[inx]);
		      ((caddr_t *) elem)[inx] = NULL;
		    }
		  else
		    dk_set_push (ret_set, box_copy_tree (((caddr_t *) elem)[inx]));
		}
	    }
	  else
	    {
	      if (!elem_is_writeable)
		elem = box_copy_tree (elem);
	      dk_set_push (ret_set, elem);
	    }

array_arg_done:
          if (NULL != to_be_deleted)
            dk_free_tree (to_be_deleted);
	  break;
      case DV_OBJECT:
        {
          xml_entity_t *xe = XMLTYPE_TO_ENTITY(elem);
          if (NULL == xe)
            {
	      dk_free_tree (list_to_array (*ret_set));
	      dk_free_tree (list_to_array (*head_set));
	      *ret_set = NULL;
	      *head_set = NULL;
	      sqlr_new_error ("22023", "SR400",
		"The argument %d of %s is an UDT instance of a type that is neither XMLType nor derived from XMLType.",
		nth + 1, func );
	    }
	  elem = (caddr_t)(xe);
	}
        /* no break */
      case DV_XML_ENTITY:
        {
	  xml_tree_ent_t * xte = (xml_tree_ent_t *) elem;
	  if (xte->xe_attr_name) /*attribute*/
	    {
	      bif_to_xml_array_push_new_attr (head_set, xte->xe_attr_name, 1,
	       xte->_->xe_currattrvalue ((xml_entity_t *) xte) );
	    }
	  else if (XE_IS_TREE (elem))
	    {
	      caddr_t *curr = xte->xte_current;
	      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (curr))
		{
		  dk_set_push (ret_set, (caddr_t) box_copy_tree ((caddr_t)curr));
		}
	      else if (uname__root == XTE_HEAD_NAME(XTE_HEAD (curr))) /*there is " root"*/
		{
		  int inx;
		  int length = BOX_ELEMENTS (curr);
		  for (inx = 1; inx < length; inx++)
		    dk_set_push (ret_set, box_copy_tree (curr[inx]));
		}
	      else
		{
		  dk_set_push (ret_set, (caddr_t) box_copy_tree ((caddr_t)curr));
		}
	    }
	  else
	    {
	      caddr_t *curr = xte->_->xe_copy_to_xte_subtree ((xml_entity_t *)xte);
	      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (curr))
		{
		  dk_set_push (ret_set, (caddr_t) curr);
		}
	      else if (uname__root == XTE_HEAD_NAME(XTE_HEAD (curr))) /*there is " root"*/
		{
		  int inx;
		  int length = BOX_ELEMENTS (curr);
		  for (inx = 1; inx < length; inx++)
		    dk_set_push (ret_set, curr[inx]);
		  /* Partial delete of curr instead of single dk_free_tree (curr); */
		  dk_free_tree (curr[0]);
		  dk_free_box (curr);
		}
	      else
		{
		  dk_set_push (ret_set, (caddr_t)curr);
		}
	    }
	  break;
        }
      case DV_DB_NULL:
	  break; /* null means skip */

      default:
	  dk_free_tree (list_to_array (*ret_set));
	  dk_free_tree (list_to_array (*head_set));
	  *ret_set = NULL;
	  *head_set = NULL;
	  sqlr_new_error ("22023", "SR359",
	      "Invalid argument type %s (%d) for arg %d to %s",
	      dv_type_title (dtp), (int) dtp,
	      nth + 1, func);
	  break;
    }
}


caddr_t
bif_xmlelement (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int argcount = BOX_ELEMENTS (args);	/* number of arguments in the call */
  int arg_inx;		/* index of current argument */
  caddr_t name, ret, head;
  dk_set_t head_set = NULL, elt_set = NULL;

  if (1 > BOX_ELEMENTS(args))
    sqlr_new_error ("22003", "SR354", "Too few arguments for XMLELEMENT");

  dk_set_push (&elt_set, NULL);
  name = bif_string_or_wide_or_uname_arg (qst, args, 0, "XMLELEMENT");
  dk_set_push (&head_set, box_cast_to_UTF8_uname (qst, name));

  for (arg_inx = 1; arg_inx < argcount; arg_inx++)
    {
      caddr_t raw_value = bif_arg (qst, args, arg_inx, "XMLELEMENT");
      dtp_t raw_value_dtp = DV_TYPE_OF (raw_value);
      if (DV_DB_NULL == raw_value_dtp || (DV_STRING == raw_value_dtp && raw_value[0] == '\0') || (uname___empty == raw_value))
	continue;

      if (DV_ARRAY_OF_POINTER != raw_value_dtp && DV_XML_ENTITY != raw_value_dtp && DV_XML_ENTITY != raw_value_dtp)
	{
	  caddr_t current = box_cast_to_UTF8 (qst, raw_value);
	  if ('\0' == current[0])
	    dk_free_box (current);
	  else
	    dk_set_push (&elt_set, current);
	}
      else if (DV_ARRAY_OF_POINTER == raw_value_dtp
	  && (((caddr_t *) raw_value)[0]) == XMLATTRIBUTE_FLAG && arg_inx > 1)
	{
	  sqlr_new_error ("22003", "SR345",
	      "XMLATTRIBUTES() must be the second argument of XMLELEMENT()");
	}
      else
	bif_to_xml_array_arg (qst, args, arg_inx, "XMLELEMENT", &elt_set, &head_set);
    }
  head = list_to_array (dk_set_nreverse (head_set));
  ret = list_to_array (dk_set_nreverse (elt_set));
  ((caddr_t *) ret)[0] = head;
  xte_tree_check (ret);
  return ret;
}


caddr_t
bif_xmlattributes (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int args_length = BOX_ELEMENTS (args);
  int inx;
  dk_set_t set = NULL;

  if (args_length % 2 != 0)
    sqlr_new_error ("42000", "XTE01", "Function xmlattributes() should have an even number of parameters");
  for (inx = 0; inx < args_length; inx += 2)
    {
      caddr_t name;
      caddr_t raw_value = bif_arg (qst, args, inx + 1, "XMLATTRIBUTES");
      dtp_t raw_value_dtp = DV_TYPE_OF (raw_value);
      dk_set_t iter = set;

      if (DV_DB_NULL == raw_value_dtp)
	continue;
      name = sql_xml_var_transform (bif_string_or_wide_or_uname_arg (qst, args, inx, "XMLATTRIBUTES"));
      while (iter && iter->next)
	{
	  char *attr_name = (char *) iter->next->data;
	  if (name == attr_name)
	    {
	      dk_free_box (name);
	      break;
	    }
	  iter = iter->next->next;
	}
      if (iter && iter->next)
	{
	  continue;
	}
      dk_set_push (&set, name);
      dk_set_push (&set, box_cast_to_UTF8 (qst, raw_value));
    }

  if (!set)
    return NEW_DB_NULL;
  set = dk_set_nreverse (set);
  dk_set_push (&set, XMLATTRIBUTE_FLAG);
  return list_to_array (set);
}


caddr_t
bif_xmlforest (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * acc;
  caddr_t * head;
  int arg_inx;		/* index of current argument */
  int args_length = BOX_ELEMENTS (args);
  int filled_count = 1; /*tag*/
  int filled_size;
  int acc_length = filled_count + args_length / 2;  /* the maximum possible value of filled_count at the end of the procedure */
  static caddr_t varchar = NULL;
  if (!varchar)
    varchar = (caddr_t) list (3, (ptrlong)DV_LONG_STRING, 0, 0);
  if (args_length%2 != 0)
    sqlr_new_error ("42000", "XTE01", "Function xmlforest() should have an even number of parameters");

  acc = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * acc_length, DV_ARRAY_OF_POINTER);

  for (arg_inx = 0; arg_inx < args_length; arg_inx +=2)
    {
      caddr_t raw_value = bif_arg (qst, args, arg_inx + 1, "XMLFOREST");
      dtp_t raw_value_dtp = DV_TYPE_OF (raw_value);
      caddr_t * elem;
      caddr_t * tag;
      if (DV_DB_NULL == raw_value_dtp)
	continue;
      elem = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * 2, DV_ARRAY_OF_POINTER);
      tag = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      tag[0] = sql_xml_var_transform (bif_string_or_wide_or_uname_arg (qst, args, arg_inx, "XMLFOREST"));
      elem[0] = (caddr_t) tag;
      elem [1] = box_cast_to_UTF8 (qst, raw_value);
      acc[filled_count++] = (caddr_t) elem;
    }
  if (filled_count == 1) /*no element was created*/
    {
      dk_free_box ((box_t) acc);
      return NEW_DB_NULL;
    }
  filled_size = sizeof (caddr_t) * filled_count;
  if (filled_size != acc_length)
    {
      caddr_t new_box = dk_alloc_box (filled_size, DV_ARRAY_OF_POINTER);
      memcpy (new_box, acc, filled_size);
      dk_free_box /*not ..._tree*/ ((caddr_t) acc);
      acc = (caddr_t *) new_box;
    }
  head = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  head[0] = uname__root;
  acc[0] = (caddr_t) head;
  dk_check_xte_nodebld_acc (acc);
  return (caddr_t) acc;
}


caddr_t
bif_xmlconcat (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t head, ret = NULL;
  int arg_inx;
  int args_length = BOX_ELEMENTS (args);
  dk_set_t ret_set = NULL, head_set = NULL;
  qi_signal_if_trx_error ((query_instance_t *)qst);

  if (args_length == 0)
    sqlr_new_error ("22003", "SR355", "Too few arguments for XMLCONCAT");
  dk_set_push (&ret_set, NULL);
  dk_set_push (&head_set, uname__root);

  for (arg_inx = 0; arg_inx < args_length; arg_inx ++)
    bif_to_xml_array_arg (qst, args, arg_inx, "XMLCONCAT", &ret_set, &head_set);

#if 0
  if (dk_set_length (ret_set) == 1 && dk_set_length (head_set) == 1)
    { /* empty root elem */
      dk_free_tree (list_to_array (ret_set));
      dk_free_tree (list_to_array (head_set));
      return NEW_DB_NULL;
    }
#endif

  if (dk_set_length (head_set) > 1)
    { /* some attributes concatenated */
      dk_free_tree (list_to_array (ret_set));
      dk_free_tree (list_to_array (head_set));
      sqlr_new_error ("22003", "SR360", "XMLCONCAT does not concatenate attributes");
    }
  head = list_to_array (dk_set_nreverse (head_set));
  ret = list_to_array (dk_set_nreverse (ret_set));
  ((caddr_t *) ret)[0] = head;
  return ret;
}


caddr_t
bif_serialize_to_UTF8_xml (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t value = bif_arg (qst, args, 0, "serialize_to_UTF8_xml");
  switch (DV_TYPE_OF (value))
    {
    case DV_DB_NULL:
      return NEW_DB_NULL;
    case DV_XML_ENTITY:
      {
        xml_entity_t *xe = (xml_entity_t *)(value);
        dk_session_t *ses = strses_allocate();
	caddr_t res;
	client_connection_t *cli = ((query_instance_t *)(qst))->qi_client;
        wcharset_t *saved_charset = cli->cli_charset;
	cli->cli_charset = CHARSET_UTF8;
        xe->_->xe_serialize (xe, ses);
	cli->cli_charset = saved_charset;
	if (!STRSES_CAN_BE_STRING (ses))
	  {
	    res = NULL;
	    *err_ret = STRSES_LENGTH_ERROR ("serialize_to_UTF8_xml");
	  }
	else
	  res = strses_string (ses);
	strses_free (ses);
	return res;
      }
    }
  return box_cast_to_UTF8 (qst, value);
}

/* returns a copy of xmlns URI */
static caddr_t
xte_find_ns (caddr_t * tag, char * ns)
{
  int inx, len = BOX_ELEMENTS (tag);
  for (inx = 1; inx < len; inx += 2)
    {
      if (!strcmp (tag[inx], "xmlns"))
	{
	  if ('\0' == tag[inx+1][0])
	    return NULL;
	  return box_copy_tree (tag[inx+1]);
	}
    }
  return box_copy_tree (ns);
}

/*
   re-compose the element head, xmlns should be taken out
   and name have to be expanded.
 */
static caddr_t *
xte_expand_ns (caddr_t * tag, caddr_t ns)
{
  int inx, len = BOX_ELEMENTS (tag);
  caddr_t new_name, name = tag[0];
  dk_set_t set = NULL;

  if (NULL != ns && NULL == strchr (name, ':') && ' ' != name[0])
    {
      new_name = dk_alloc_box (box_length (name) + strlen (ns) + 1, DV_STRING);
      snprintf (new_name, box_length (new_name), "%s:%s", ns, name);
    }
  else
    {
      new_name = box_copy_tree (name);
    }

  dk_set_push (&set, new_name);

  for (inx = 1; inx < len; inx += 2)
    {
      if (!strcmp (tag[inx], "xmlns"))
	continue;
      dk_set_push (&set, box_copy_tree (tag[inx]));
      dk_set_push (&set, box_copy_tree (tag[inx+1]));
    }

  return (caddr_t *)list_to_array (dk_set_nreverse (set));
}

static void
xte_make_ns (caddr_t * current, char * in_ns, caddr_t * err_ret)
{
  dtp_t dtp = DV_TYPE_OF (current);
  if (DV_ARRAY_OF_POINTER == dtp)
    {
      caddr_t *head, *new_head, ns;
      int inx, len, hlen;

      len = BOX_ELEMENTS (current);

      if (!len)
	{
          *err_ret = srv_make_new_error ("22023", "The input is not an xml tree", "XTE00");
	  return;
	}

      head = ((caddr_t**)current)[0];
      hlen = BOX_ELEMENTS (head);

      if (!hlen || ((hlen - 1) % 2) != 0)
	{
          *err_ret = srv_make_new_error ("22023", "The input is not an xml tree", "XTE01");
	  return;
	}

      /* get a copy of xmlns URI and free when loop finished */
      ns = xte_find_ns ((caddr_t *) current[0], in_ns);
      if (NULL != (new_head = xte_expand_ns ((caddr_t *) current[0], ns)))
	{
	  dk_free_tree ((box_t) head);
	  ((caddr_t**)current)[0] = new_head;
	}

      for (inx = 1; inx < len; inx++)
	{
	  xte_make_ns ((caddr_t *) current[inx], ns, err_ret);
	  if (*err_ret)
	    {
	      dk_free_tree (ns);
	      return;
	    }
	}
      dk_free_tree (ns);
    }
}

caddr_t
bif_xte_expand_xmlns (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t value = bif_arg (qst, args, 0, "xte_expand_xmlns");
  switch (DV_TYPE_OF (value))
    {
    case DV_DB_NULL:
      return NEW_DB_NULL;
    case DV_ARRAY_OF_POINTER:
      {
	caddr_t * box = (caddr_t *) box_copy_tree (value);
	xte_make_ns (box, NULL, err_ret);
	if (*err_ret)
	  {
	    dk_free_tree ((box_t) box);
	    return NULL;
	  }
	return (caddr_t) box;
      }
    }
  return box_copy_tree (value);
}

caddr_t
bif_xmlnss_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t * ent = bif_entity_arg (qst, args, 0, "xmlnss_get");
  ptrlong idx = ent->xe_doc.xd->xd_ns_2dict.xn2_size;
  caddr_t * res = dk_alloc_box (sizeof (caddr_t) * idx * 2, DV_ARRAY_OF_POINTER);

  while (idx-- > 0)
    {
      res[idx*2] = box_copy (ent->xe_doc.xd->xd_ns_2dict.xn2_prefix2uri[idx].xna_key);
      res[idx*2+1] = box_copy (ent->xe_doc.xd->xd_ns_2dict.xn2_prefix2uri[idx].xna_value);
    }

  return (caddr_t)res;
}

/*
  xmlnss_xpath_pre returns string
   '[ xmlns:PREFIX1="NS1" xmlns:RPEFIX2="NS2" ... xmlns:RPEFIX2="NS2" ]'
*/

#define FILL_STR_AND_MOVE(p,str) \
  do { \
	memcpy ((p), (str), strlen ((str)));\
	while ((p)[0]) (p)++;\
    } while (0)

caddr_t
bif_xmlnss_xpath_pre (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  xml_entity_t * ent = bif_entity_arg (qst, args, 0, "xmlnss_xpath_pre");

  caddr_t bpws_ns = 0;
  int bpws_ns_in_list = 0;
  size_t res_str_len = 0;
  caddr_t res_str, ptr;
  caddr_t * bpws_def_prefs = 0;

  dk_set_t scope;
  caddr_t *prefix2uri;
  ptrlong idx;


  if (BOX_ELEMENTS (args) > 1)
    bpws_ns = bif_string_arg (qst, args, 1, "xmlnss_xpath_pre");
  if (BOX_ELEMENTS (args) > 2)
    bpws_def_prefs = (caddr_t*) bif_array_arg (qst, args, 2, "xmlnss_xpath_pre");

  scope = ent->_->xe_namespace_scope (ent, 1);
  prefix2uri = (caddr_t *)list_to_array (scope);
  idx = BOX_ELEMENTS (prefix2uri)/2;
  while (idx--)
    {
      caddr_t item = prefix2uri[idx];
      if (DV_UNAME == DV_TYPE_OF (item))
        {
          prefix2uri[idx] = box_dv_short_nchars (item, box_length (item)-1);
          dk_free_box (item);
        }
    }
  idx = BOX_ELEMENTS (prefix2uri)/2;
/*
3=  12                                                                3
10=   123456       78   90
   '[ xmlns:PREFIX1="NS1" xmlns:RPEFIX2="NS2" ... xmlns:RPEFIX2="NS2" ]'
*/
  res_str_len += 3 + 10 * idx; /* see digits above */
  while (idx-- > 0)
    {
      res_str_len += box_length (prefix2uri[idx*2])-1;
      res_str_len += box_length (prefix2uri[idx*2+1])-1;
      if (bpws_ns && !strcmp (prefix2uri[idx*2+1], bpws_ns))
	bpws_ns_in_list = 1;
      if (prefix2uri[idx*2][0] == 0) /* default ns, not ':' sign */
	res_str_len--;
    }
  if (bpws_ns && !bpws_ns_in_list)
    res_str_len += strlen (bpws_ns) + 9 /* xmlns= has no ':' char */;
  if (bpws_def_prefs)
    {
      int inx = 0;
      DO_BOX (char *, pref, inx, bpws_def_prefs)
	{
	  res_str_len += strlen (bpws_ns) + 10 + strlen (pref);
	}
      END_DO_BOX;
    }

  res_str = ptr = dk_alloc_box_zero (res_str_len + 1, DV_STRING);
  idx = BOX_ELEMENTS (prefix2uri)/2 ;

  FILL_STR_AND_MOVE (ptr, "[ ");
  while (idx--)
    {
      if (prefix2uri[idx*2][0] == 0)
	FILL_STR_AND_MOVE (ptr, "xmlns");
      else
	{
	  FILL_STR_AND_MOVE (ptr, "xmlns:");
          FILL_STR_AND_MOVE (ptr, prefix2uri[idx*2]);
	}
      FILL_STR_AND_MOVE (ptr, "=\"");
      FILL_STR_AND_MOVE (ptr, prefix2uri[idx*2+1]);
      FILL_STR_AND_MOVE (ptr, "\" ");
    }
  if (bpws_def_prefs)
    {
      int inx;
      DO_BOX (char *, pref, inx, bpws_def_prefs)
	{
          if ('\0' == pref[0])
            FILL_STR_AND_MOVE (ptr, "xmlns");
          else
            {
	      FILL_STR_AND_MOVE (ptr, "xmlns:");
              FILL_STR_AND_MOVE (ptr, pref);
            }
	  FILL_STR_AND_MOVE (ptr, "=\"");
	  FILL_STR_AND_MOVE (ptr, bpws_ns);
	  FILL_STR_AND_MOVE (ptr, "\" ");
	}
      END_DO_BOX;
    }
  if (bpws_ns && !bpws_ns_in_list)
    {
      FILL_STR_AND_MOVE (ptr, "xmlns");
      FILL_STR_AND_MOVE (ptr, "=\"");
      FILL_STR_AND_MOVE (ptr, bpws_ns);
      FILL_STR_AND_MOVE (ptr, "\" ");
    }
  FILL_STR_AND_MOVE (ptr, "]");
  ptr[0] = 0;
  dk_free_tree (prefix2uri);
  return res_str;
}


void
bif_xml_init (void)
{
  xmlschema_dflt_config = box_dv_short_string ("Validation=RIGOROUS FsaBadWs=IGNORE Fsa=ERROR BuildStandalone=ENABLE SchemaDecl=ENABLE MaxErrors=2000 MaxWarnings=10000");
  /* XML escapes definition */
  XML_CHAR_ESCAPE ('<', "&#38;#60;");
  XML_CHAR_ESCAPE ('>', "&#62;");
  XML_CHAR_ESCAPE ('&', "&#38;#38;");
  XML_CHAR_ESCAPE ('"', "&#34;");
  XML_CHAR_ESCAPE ('\'',"&#39;");

  /* Bif definitions */
  bif_define (XMLROWVECT, bif_row_vector);
  bif_define_typed (XMLATTR, bif_xml_attr, &bt_integer);
  bif_define (XMLATTRREPLAY, bif_xml_attr_replay);
  bif_define (XMLSELEMENTTABLE, bif_xmls_element_table);
  bif_define (XMLSELEMENTCOL, bif_xmls_element_col);
  bif_define_typed (XMLEID, bif_xml_eid, &bt_bin);
  bif_define (XMLSPROC, bif_xmls_proc);

  /* bif_define (TREETOXML, bif_tree_to_xml); */
  bif_define_ex ("xml_tree", bif_xml_tree, BMD_RET_TYPE, &bt_xml_entity, BMD_DONE);
  bif_set_uses_index (bif_xml_tree);
  bif_define_ex ("xtree_doc", bif_xtree_doc, BMD_RET_TYPE, &bt_xml_entity, BMD_DONE);
  bif_set_uses_index (bif_xtree_doc);
  bif_define_ex ("xtree_doc_vdb", bif_xtree_doc_vdb, BMD_RET_TYPE, &bt_xml_entity, BMD_DONE);
  bif_set_uses_index (bif_xtree_doc_vdb);
  bif_define ("xml_expand_refs", bif_xml_expand_refs);
#if 0
  bif_define ("xml_store_tree", bif_xml_store_tree);
  bif_set_uses_index (bif_xml_store_tree);
#endif
  bif_define_ex ("number", bif_number, BMD_RET_TYPE, &bt_numeric, BMD_DONE);
  bif_define_ex ("xml_cut", bif_xml_cut, BMD_RET_TYPE, &bt_xml_entity, BMD_DONE);
  bif_define ("__vt_index", bif_vt_index);
  bif_define ("xmls_viewremove", bif_xmls_viewremove);
  bif_define ("xml_view_dtd", bif_xml_view_dtd);
  bif_define ("xml_view_schema", bif_xml_view_schema);
  bif_define ("xml_auto", bif_xml_auto);
  bif_define ("xmlsql_update", bif_xmlsql_update);
  bif_define ("xml_template", bif_xml_template);
  bif_define ("xml_auto_dtd", bif_xml_auto_dtd);
  bif_define ("xml_auto_schema", bif_xml_auto_schema);
  bif_define ("xml_validate_dtd", bif_xml_validate_dtd);
  bif_set_uses_index (bif_xml_validate_dtd);
  bif_define ("xml_validate_schema", bif_xml_validate_schema);
  bif_set_uses_index (bif_xml_validate_schema);
  bif_define ("xml_schema_debug", bif_xml_schema_debug);
  bif_define ("xml_load_schema_decl", bif_xml_load_schema_decl);
  bif_set_uses_index (bif_xml_load_schema_decl);
  bif_define ("xml_reload_schema_decl", bif_xml_reload_schema_decl);
  bif_set_uses_index (bif_xml_reload_schema_decl);
  bif_define ("xml_load_mapping_schema_decl", bif_xml_load_mapping_schema_decl);/*mapping schema*/
  bif_set_uses_index (bif_xml_load_mapping_schema_decl);
  bif_define ("xml_reload_mapping_schema_decl", bif_xml_reload_mapping_schema_decl);/*mapping schema*/
  bif_set_uses_index (bif_xml_reload_mapping_schema_decl);
  bif_define ("xml_create_tables_from_mapping_schema_decl", bif_xml_create_tables_from_mapping_schema_decl);/*mapping schema*/
  bif_set_uses_index (bif_xml_reload_mapping_schema_decl);
  bif_define ("xml_add_system_path", bif_xml_add_system_path);
  bif_define ("xml_get_system_paths", bif_xml_get_system_paths);

  bif_define ("xte_head", bif_xte_head);
  bif_define ("xte_node", bif_xte_node);
  bif_define ("xte_nodebld_init", bif_xte_nodebld_init);
  bif_define ("xte_nodebld_acc", bif_xte_nodebld_acc);
  bif_define ("xte_nodebld_xmlagg_acc", bif_xte_nodebld_xmlagg_acc);
  bif_define ("xte_nodebld_final", bif_xte_nodebld_final);
  bif_define ("xte_nodebld_xmlagg_final", bif_xte_nodebld_xmlagg_final);
  bif_define ("xte_node_from_nodebld", bif_xte_node_from_nodebld);

  bif_define ("int_vectorbld_init", bif_int_vectorbld_init);
  bif_define ("int_vectorbld_acc", bif_int_vectorbld_acc);
  bif_define ("int_vectorbld_final", bif_int_vectorbld_final);

  bif_define ("vectorbld_init", bif_vectorbld_init);
  bif_define ("vectorbld_acc", bif_vectorbld_acc);
  bif_define ("vectorbld_agg_acc", bif_vectorbld_agg_acc);
  bif_define ("vector_of_nonnulls_bld_agg_acc", bif_vector_of_nonnulls_bld_agg_acc);
  bif_define ("vectorbld_concat_acc", bif_vectorbld_concat_acc);
  bif_define ("vectorbld_concat_agg_acc", bif_vectorbld_concat_agg_acc);
  bif_define ("vectorbld_final", bif_vectorbld_final);
  bif_define ("vectorbld_agg_final", bif_vectorbld_agg_final);
  bif_define ("vector_or_null_bld_agg_final", bif_vector_or_null_bld_agg_final);
  bif_define ("vectorbld_length", bif_vectorbld_length);
  bif_define ("vectorbld_crop", bif_vectorbld_crop);

  bif_define ("xq_sequencebld_init", bif_xq_sequencebld_init);
  bif_define ("xq_sequencebld_acc", bif_xq_sequencebld_acc);
  bif_define ("xq_sequencebld_agg_acc", bif_xq_sequencebld_agg_acc);
  bif_define ("xq_sequencebld_final", bif_xq_sequencebld_final);
  bif_define ("xq_sequencebld_agg_final", bif_xq_sequencebld_agg_final);

  bif_define_ex ("xmlelement", bif_xmlelement, BMD_RET_TYPE, &bt_xml_entity, BMD_DONE);
  bif_define_ex ("xmlattributes", bif_xmlattributes, BMD_ALIAS, "xmlattributes_2", BMD_RET_TYPE, &bt_xml_entity, BMD_DONE);
  bif_define_ex ("xmlforest", bif_xmlforest, BMD_ALIAS, "xmlforest_2", BMD_RET_TYPE, &bt_xml_entity, BMD_DONE);
  bif_define_ex ("xmlconcat", bif_xmlconcat, BMD_RET_TYPE, &bt_xml_entity, BMD_DONE);
  bif_define_ex ("serialize_to_UTF8_xml", bif_serialize_to_UTF8_xml, BMD_RET_TYPE, &bt_varchar, BMD_DONE);
  bif_define_ex ("xte_expand_xmlns", bif_xte_expand_xmlns, BMD_RET_TYPE, &bt_xml_entity, BMD_DONE);
  bif_define_ex ("xmlnss_get", bif_xmlnss_get, BMD_RET_TYPE, &bt_xml_entity, BMD_DONE);
  bif_define_ex ("xmlnss_xpath_pre", bif_xmlnss_xpath_pre, BMD_RET_TYPE, &bt_varchar, BMD_DONE);

  bif_text_init ();
  bif_ap_init ();
  xml_schema_init ();
}
