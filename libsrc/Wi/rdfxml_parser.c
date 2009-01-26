/*
 *  rdfxml_parser.c
 *
 *  $Id$
 *
 *  RDF/XML parser
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
 *  
 */

#include "Dk.h"
#include "rdf_core.h"
#include "sqlnode.h"
#include "xml.h"
#include "xmltree.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser.h"
#include "xmlparser_impl.h"
#ifdef __cplusplus
}
#endif

#ifdef RDFXML_DEBUG
#define rdfxml_dbg_printf(x) dbg_printf (x)
#else
#define rdfxml_dbg_printf(x)
#endif

#define XRL_SET_INHERITABLE(xrl,name,value,errmsg) do { \
    if (xrl->name##_set) \
    { \
      dk_free_tree ((value)); \
        xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 200, errmsg); \
        return ;\
    } \
  xrl->name = (value); \
  xrl->name##_set = 1; \
  } while (0)

#define XRL_SET_NONINHERITABLE(xrl,name,value,errmsg) do { \
    if (NULL != xrl->name) \
      { \
        dk_free_tree ((value)); \
        xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 200, errmsg); \
        return ;\
      } \
    xrl->name = (value); \
  } while (0)

void
xp_rdfxml_get_name_parts (xp_node_t * xn, char * name, int use_default, caddr_t *nsuri_ret, char **local_ret)
{
  xp_node_t * ctx_xn;
  size_t ns_len = 0, nsinx;
  char * local = strrchr (name, ':');
  if (!local && !use_default)
    {
      nsuri_ret[0] = uname___empty;
      local_ret[0] = name;
      return;
    }
  if (local)
    {
      ns_len = local - name;
      if (bx_std_ns_pref (name, ns_len))
        {
          nsuri_ret[0] = uname_xml;
          local_ret[0] = local + 1;
	  return;
        }
      local++;
    }
  else
    {
      ns_len = 0;
    local = name;
    }
  ctx_xn = xn;
  while (ctx_xn)
    {
      size_t n_ns = BOX_ELEMENTS_0 (ctx_xn->xn_namespaces);
      for (nsinx = 0; nsinx < n_ns; nsinx += 2)
	{
	  char *ctxname = ctx_xn->xn_namespaces[nsinx];
	  if ((box_length (ctxname) == (ns_len + 1)) && !memcmp (ctxname, name, ns_len))
	    {
	      char * ns_uri = ctx_xn->xn_namespaces[nsinx + 1];
              nsuri_ret[0] = ns_uri;
              local_ret[0] = local;
              return;
            }
	}
      ctx_xn = ctx_xn->xn_parent;
    }
  nsuri_ret[0] = uname___empty;
  local_ret[0] = name;
  if (0 != ns_len)
    xmlparser_logprintf (xn->xn_xp->xp_parser, XCFG_FATAL, 100+strlen (name), "Name '%.1000s' contains undefined namespace prefix", name);
}


void xp_pop_rdf_locals (xparse_ctx_t *xp)
{
  xp_rdf_locals_t *inner = xp->xp_rdf_locals;
  if (inner->xrl_base_set)
    dk_free_tree (inner->xrl_base);
  if (NULL != inner->xrl_datatype)
    dk_free_tree (inner->xrl_datatype);
  if (inner->xrl_language_set)
    dk_free_tree (inner->xrl_language);
  dk_free_box (inner->xrl_predicate);
  if (NULL != inner->xrl_subject)
    dk_free_tree (inner->xrl_subject);
  if (NULL != inner->xrl_reification_id)
    dk_free_tree (inner->xrl_reification_id);
  while (NULL != inner->xrl_seq_items)
    dk_free_tree (dk_set_pop (&(inner->xrl_seq_items)));
  xp->xp_rdf_locals = inner->xrl_parent;
  memset (inner, -1, sizeof (xp_rdf_locals_t));
  inner->xrl_parent = xp->xp_rdf_free_list;
  xp->xp_rdf_free_list = inner;
}


xp_rdf_locals_t *xp_push_rdf_locals (xparse_ctx_t *xp)
{
  xp_rdf_locals_t *outer = xp->xp_rdf_locals;
  xp_rdf_locals_t *inner;
  if (NULL != xp->xp_rdf_free_list)
    {
      inner = xp->xp_rdf_free_list;
      xp->xp_rdf_free_list = inner->xrl_parent;
    }
  else
    inner = dk_alloc (sizeof (xp_rdf_locals_t));
  memset (inner, 0, sizeof (xp_rdf_locals_t));
  inner->xrl_base = outer->xrl_base;
  inner->xrl_language = outer->xrl_language;
  inner->xrl_parent = outer;
  xp->xp_rdf_locals = inner;
  return inner;
}


caddr_t
xp_rdfxml_resolved_iid (xparse_ctx_t *xp, const char *avalue, int is_id_attr)
{
  caddr_t err = NULL;
  caddr_t local, res;
  if (is_id_attr)
    {
      local = dk_alloc_box (2 + strlen (avalue), DV_STRING);
      local[0] = '#';
      strcpy (local+1, avalue);
    }
  else
    local = box_dv_short_string (avalue);
  res = xml_uri_resolve_like_get (xp->xp_qi, &err, xp->xp_rdf_locals->xrl_base, local, "UTF-8");
  dk_free_box (local);
  if (NULL != err)
    sqlr_resignal (err);
#ifdef MALLOC_DEBUG
  dk_check_tree (res);
#endif
  return res;
}


caddr_t
xp_rdfxml_bnode_iid (xparse_ctx_t *xp, caddr_t avalue)
{
  caddr_t res;
  rdfxml_dbg_printf (("\nxp_rdfxml_bnode_iid (\"%s\")", avalue));
  res = tf_bnode_iid (xp->xp_tf, avalue);
#ifdef MALLOC_DEBUG
  dk_check_tree (res);
#endif
  return res;
}


void
xp_rdfxml_triple (xparse_ctx_t *xp, caddr_t s, caddr_t p, caddr_t o)
{
#ifdef MALLOC_DEBUG
  dk_check_tree (s);
  dk_check_tree (p);
  dk_check_tree (o);
#endif
  rdfxml_dbg_printf (("\nxp_rdfxml_triple (\"%s\", \"%s\", \"%s\")", s, p, o));
  tf_triple (xp->xp_tf, s, p, o);
}


void
xp_rdfxml_triple_l (xparse_ctx_t *xp, caddr_t s, caddr_t p, caddr_t o, caddr_t dt, caddr_t lang)
{
#ifdef MALLOC_DEBUG
  dk_check_tree (s);
  dk_check_tree (p);
  dk_check_tree (o);
  dk_check_tree (dt);
  dk_check_tree (lang);
#endif
  rdfxml_dbg_printf (("\nxp_rdfxml_triple (\"%s\", \"%s\", \"%s\", \"%s\", \"%s\")", s, p, o, dt, lang));
  tf_triple_l (xp->xp_tf, s, p, o, dt, lang);
}


/*#define RECOVER_RDF_VALUE 1*/

void
xp_rdfxml_element (void *userdata, char * name, vxml_parser_attrdata_t *attrdata)
{
  xparse_ctx_t * xp = (xparse_ctx_t*) userdata;
  xp_rdf_locals_t *outer = xp->xp_rdf_locals;
  xp_rdf_locals_t *inner;
  xp_node_t *xn;
  caddr_t subj_type = NULL;
  int inx, fill, n_attrs, n_ns;
  dk_set_t inner_attr_props = NULL;
  caddr_t tmp_nsuri;
  char * tmp_local;
#ifdef RECOVER_RDF_VALUE
  caddr_t rdf_val = NULL;
#endif
  if (XRL_PARSETYPE_LITERAL == outer->xrl_parsetype)
    {
      xp_element (userdata, name, attrdata);
      return;
    }
  else if (XRL_PARSETYPE_EMPTYPROP == outer->xrl_parsetype)
    xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Sub-element in a predicate element with object node attribute");
  inner = xp_push_rdf_locals (xp);
  xn = xp->xp_free_list;
  if (NULL == xn)
    xn = dk_alloc (sizeof (xp_node_t));
  else
    xp->xp_free_list = xn->xn_parent;
  memset (xn, 0, sizeof (xp_node_t));
  xn->xn_xp = xp;
  xn->xn_parent = xp->xp_current;
  xp->xp_current = xn;
#ifdef DEBUG
  if (NULL != xp->xp_boxed_name)
    GPF_T1("Memory leak in xp->xp_boxed_name");
#endif
  inner->xrl_xn = xn;
  n_ns = attrdata->local_nsdecls_count;
  if (n_ns)
    {
      caddr_t *save_ns = (caddr_t*) dk_alloc_box (2 * n_ns * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      /* Trick here: xn->xn_attrs is set to xn->xn_namespaces in order to free memory on errors or element end. */
      xn->xn_attrs = xn->xn_namespaces = save_ns;
      fill = 0;
      for (inx = 0; inx < n_ns; inx++)
        {
          save_ns[fill++] = box_dv_uname_string (attrdata->local_nsdecls[inx].nsd_prefix);
          save_ns[fill++] = box_dv_uname_string (attrdata->local_nsdecls[inx].nsd_uri);
        }
    }
  xp_rdfxml_get_name_parts (xn, name, 1, &tmp_nsuri, &tmp_local);
  if (!strcmp ("http://www.w3.org/1999/02/22-rdf-syntax-ns#", tmp_nsuri))
    {
      if (!strcmp ("RDF", tmp_local))
        {
          if (XRL_PARSETYPE_TOP_LEVEL != outer->xrl_parsetype)
            xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 200, "Element rdf:RDF can appear only at top level");
          inner->xrl_parsetype = XRL_PARSETYPE_RESOURCE;
        }
      else if (!strcmp ("Description", tmp_local))
        {
          if (XRL_PARSETYPE_PROPLIST == outer->xrl_parsetype)
            xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 200, "Element rdf:Description can not appear in list of properties");
          inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
        }
      else if (XRL_PARSETYPE_PROPLIST == outer->xrl_parsetype)
        {
          caddr_t full_element_name;
          if (!strcmp ("li", tmp_local))
            {
              int li_count = ++(outer->xrl_li_count);
              full_element_name = box_sprintf (100, "http://www.w3.org/1999/02/22-rdf-syntax-ns#_%d", li_count);
            }
          else
            {
              size_t l1 = strlen (tmp_nsuri), l2 = strlen (tmp_local);
              full_element_name = dk_alloc_box (l1 + l2 + 1, DV_STRING);
              memcpy (full_element_name, tmp_nsuri, l1);
              strcpy (full_element_name + l1, tmp_local);
            }
          dk_free_tree (inner->xrl_predicate);
          inner->xrl_predicate = full_element_name;
          inner->xrl_parsetype = XRL_PARSETYPE_RES_OR_LIT;
        }
#if 0
      else if (!strcmp ("Seq", tmp_local))
        {
          xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 200, "RDF/XML parser of Virtuoso does not support rdf:Seq syntax");
          return;
        }
#endif
      else if (
        !strcmp ("Property", tmp_local) ||
        !strcmp ("Bag", tmp_local) ||
        !strcmp ("Seq", tmp_local) ||
        !strcmp ("Alt", tmp_local)  ||
        !strcmp ("List", tmp_local) ||
        !strcmp ("Statement", tmp_local) )
        {
          size_t l1 = strlen (tmp_nsuri), l2 = strlen (tmp_local);
          caddr_t full_element_name = dk_alloc_box (l1 + l2 + 1, DV_STRING);
          memcpy (full_element_name, tmp_nsuri, l1);
          strcpy (full_element_name + l1, tmp_local);
          subj_type = xp->xp_boxed_name = full_element_name;
          inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
        }
      else
        {
        xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 200, "Unknown element in RDF namespace");
          return;
        }
    }
  else
    {
      size_t l1 = strlen (tmp_nsuri), l2 = strlen (tmp_local);
      caddr_t full_element_name = dk_alloc_box (l1 + l2 + 1, DV_STRING);
      memcpy (full_element_name, tmp_nsuri, l1);
      strcpy (full_element_name + l1, tmp_local);
      if (XRL_PARSETYPE_PROPLIST == outer->xrl_parsetype)
        {
          dk_free_tree (inner->xrl_predicate);
          inner->xrl_predicate = full_element_name;
          inner->xrl_parsetype = XRL_PARSETYPE_RES_OR_LIT;
        }
      else
        {
          subj_type = xp->xp_boxed_name = full_element_name;
          inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
        }
    }
  n_attrs = attrdata->local_attrs_count;
  /* we do one loop first to see if there a xml:base, then rest */
  for (inx = 0; inx < n_attrs; inx ++)
    {
      char *raw_aname = attrdata->local_attrs[inx].ta_raw_name.lm_memblock;
      caddr_t avalue = attrdata->local_attrs[inx].ta_value;
      xp_rdfxml_get_name_parts (xn, raw_aname, 0, &tmp_nsuri, &tmp_local);
      if (!stricmp (tmp_nsuri, "xml"))
        {
          if (!strcmp (tmp_local, "lang"))
            XRL_SET_INHERITABLE (inner, xrl_language, box_dv_short_string (avalue), "Attribute 'xml:lang' is used twice");
          else if (!strcmp (tmp_local, "base"))
            XRL_SET_INHERITABLE (inner, xrl_base, box_dv_short_string (avalue), "Attribute 'xml:base' is used twice");
          else if (0 != strcmp (tmp_local, "space"))
            xmlparser_logprintf (xp->xp_parser, XCFG_WARNING, 200,
              "Unsupported 'xml:...' attribute, only 'xml:lang', 'xml:base' and 'xml:space' are supported" );
	}
    }
  for (inx = 0; inx < n_attrs; inx ++)
    {
      char *raw_aname = attrdata->local_attrs[inx].ta_raw_name.lm_memblock;
      caddr_t avalue = attrdata->local_attrs[inx].ta_value;
      xp_rdfxml_get_name_parts (xn, raw_aname, 0, &tmp_nsuri, &tmp_local);
      if (!strcmp (tmp_nsuri, "http://www.w3.org/1999/02/22-rdf-syntax-ns#"))
        {
          if (!strcmp (tmp_local, "about"))
            {
              caddr_t inner_subj;
              if (XRL_PARSETYPE_PROPLIST == outer->xrl_parsetype)
                {
                xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Attribute 'rdf:about' can not appear in element that is supposed to be property name");
                  return;
                }
              inner_subj = xp_rdfxml_resolved_iid (xp, avalue, 0);
              XRL_SET_NONINHERITABLE (inner, xrl_subject, inner_subj, "Attribute 'rdf:about' conflicts with other attribute that set the subject");
              inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
            }
          else if (!strcmp (tmp_local, "resource"))
            {
              caddr_t inner_subj;
              if (XRL_PARSETYPE_PROPLIST != outer->xrl_parsetype)
                {
                xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Attribute 'rdf:resource' can appear only in element that is supposed to be property name");
                  return;
                }
              inner_subj = xp_rdfxml_resolved_iid (xp, avalue, 0);
              XRL_SET_NONINHERITABLE (inner, xrl_subject, inner_subj, "Attribute 'rdf:resource' conflicts with other attribute that set the subject");
              inner->xrl_parsetype = XRL_PARSETYPE_EMPTYPROP;
            }
          else if (!strcmp (tmp_local, "nodeID"))
            {
              caddr_t inner_subj = xp_rdfxml_bnode_iid (xp, box_dv_short_string (avalue));
              XRL_SET_NONINHERITABLE (inner, xrl_subject, inner_subj, "Attribute 'rdf:nodeID' conflicts with other attribute that set the subject");
              if (XRL_PARSETYPE_PROPLIST == outer->xrl_parsetype)
                {
                  inner->xrl_parsetype = XRL_PARSETYPE_EMPTYPROP;
                }
              else
                {
                  inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
                }
            }
          else if (!strcmp (tmp_local, "ID"))
            {
              if (XRL_PARSETYPE_PROPLIST == outer->xrl_parsetype)
                {
                  caddr_t reif_subj = xp_rdfxml_resolved_iid (xp, avalue, 1);
                  XRL_SET_NONINHERITABLE (inner, xrl_reification_id, reif_subj, "Reification ID of the statement is set twice by 'rdf:ID' attribute of a property element");
                }
              else
                {
                  caddr_t inner_subj = xp_rdfxml_resolved_iid (xp, avalue, 1);
                  XRL_SET_NONINHERITABLE (inner, xrl_subject, inner_subj, "Attribute 'rdf:ID' conflicts with other attribute that set node ID");
                  inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
                }
            }
          else if (!strcmp (tmp_local, "datatype"))
            {
              if (XRL_PARSETYPE_PROPLIST != outer->xrl_parsetype)
                {
                xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Attribute 'rdf:datatype' can appear only in property elements");
                  return;
                }
              XRL_SET_NONINHERITABLE (inner, xrl_datatype, xp_rdfxml_resolved_iid (xp, avalue, 0),  "Attribute 'rdf:datatype' us used twice");
              inner->xrl_parsetype = XRL_PARSETYPE_LITERAL;
            }
          else if (!strcmp (tmp_local, "parseType"))
            {
              if (XRL_PARSETYPE_PROPLIST != outer->xrl_parsetype)
                {
                xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Attribute 'rdf:parseType' can appear only in property elements");
                  return;
                }
              if (!strcmp (avalue, "Resource"))
                {
                  caddr_t inner_subj = xp_rdfxml_bnode_iid (xp, NULL);
                  XRL_SET_NONINHERITABLE (inner, xrl_subject, inner_subj, "Attribute parseType='Resource' can not be used if object is set by other attribute");
                  inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
                }
              else if (!strcmp (avalue, "Literal"))
                {
                  inner->xrl_parsetype = XRL_PARSETYPE_LITERAL;
                }
              else if (!strcmp (avalue, "Collection"))
                {
                  inner->xrl_parsetype = XRL_PARSETYPE_COLLECTION;
                  return;
                }
              else
                {
                xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Unknown parseType");
                  return;
                }
            }
	  else if (!strcmp (tmp_local, "value"))
	    {
#ifdef RECOVER_RDF_VALUE
	      rdf_val = avalue;
#else
              goto push_inner_attr_prop;
#endif
	    }
          else
            xmlparser_logprintf (xp->xp_parser, XCFG_WARNING, 200,
              "Unsupported 'rdf:...' attribute" );
          continue;
        }
      else if (!stricmp (tmp_nsuri, "xml"))
        {
/* 
   	  XXX: moved above	  
          if (!strcmp (tmp_local, "lang"))
            XRL_SET_INHERITABLE (inner, xrl_language, box_dv_short_string (avalue), "Attribute 'xml:lang' is used twice");
          else if (!strcmp (tmp_local, "base"))
            XRL_SET_INHERITABLE (inner, xrl_base, box_dv_short_string (avalue), "Attribute 'xml:base' is used twice");
          else if (0 != strcmp (tmp_local, "space"))
            xmlparser_logprintf (xp->xp_parser, XCFG_WARNING, 200,
              "Unsupported 'xml:...' attribute, only 'xml:lang', 'xml:base' and 'xml:space' are supported" );
*/	      
          continue;
        }
push_inner_attr_prop:
          dk_set_push (&inner_attr_props, avalue);
          dk_set_push (&inner_attr_props, tmp_local);
          dk_set_push (&inner_attr_props, tmp_nsuri);
          inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
        }
  if ((NULL != inner->xrl_subject) || (NULL != inner_attr_props))
    {
      if (XRL_PARSETYPE_LITERAL == inner->xrl_parsetype)
        {
        xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 200,
          "Conflicting attributes: property value can not be a node and a literal simultaneously" );
           return;
        }
    }
/*  if ((XRL_PARSETYPE_PROPLIST == outer->xrl_parsetype) && (NULL != outer->xrl_subject))
    XRL_SET_NONINHERITABLE (inner, xrl_subject, box_copy_tree (outer->xrl_subject));
*/
  if (NULL == inner->xrl_subject)
    {
      if ((NULL != inner_attr_props) || (NULL != subj_type) ||
#ifdef RECOVER_RDF_VALUE
        (NULL != rdf_val) ||
#endif
        (XRL_PARSETYPE_PROPLIST == inner->xrl_parsetype) )
        {
          caddr_t inner_subj = xp_rdfxml_bnode_iid (xp, NULL);
          XRL_SET_NONINHERITABLE (inner, xrl_subject, inner_subj, "Blank node object can not be defined here");
          inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
        }
    }
  if ((XRL_PARSETYPE_PROPLIST == inner->xrl_parsetype) && (NULL != outer->xrl_predicate))
    XRL_SET_NONINHERITABLE (outer, xrl_subject, box_copy_tree (inner->xrl_subject), "A property can not have two object values");
  if (NULL != subj_type)
    xp_rdfxml_triple (xp, inner->xrl_subject, uname_rdf_ns_uri_type, subj_type);
#ifdef RECOVER_RDF_VALUE
  if (NULL != rdf_val)
    { /* This preserves semantics */
      caddr_t resolved_rdf_val = xp_rdfxml_resolved_iid (xp, rdf_val, 0);
      xp_rdfxml_triple (xp, inner->xrl_subject, uname_rdf_ns_uri_value, resolved_rdf_val);
      dk_free_box (resolved_rdf_val);
    }
#endif
  if (NULL != xp->xp_boxed_name)
    {
      dk_free_box (xp->xp_boxed_name);
      xp->xp_boxed_name = NULL;
    }
  while (NULL != inner_attr_props)
    {
      size_t l1, l2;
      caddr_t aname, avalue;
      tmp_nsuri = dk_set_pop (&inner_attr_props);
      tmp_local = dk_set_pop (&inner_attr_props);
      avalue = dk_set_pop (&inner_attr_props);
      l1 = strlen (tmp_nsuri);
      l2 = strlen (tmp_local);
      xp->xp_boxed_name = aname = dk_alloc_box (l1 + l2 + 1, DV_STRING);
      memcpy (aname, tmp_nsuri, l1);
      strcpy (aname + l1, tmp_local);
      xp_rdfxml_triple_l (xp, inner->xrl_subject, aname, avalue, NULL, NULL);
      dk_free_box (aname);
      xp->xp_boxed_name = NULL;
    }
  if ((XRL_PARSETYPE_PROPLIST == inner->xrl_parsetype) && (XRL_PARSETYPE_PROPLIST == outer->xrl_parsetype))
    { /* This means parseType="Resource". It should be handled immediately to prevent error in case of pasrseType="Resource" nested inside inner. */
      xp_rdfxml_triple (xp, outer->xrl_subject, inner->xrl_predicate, inner->xrl_subject);
      if (NULL != inner->xrl_reification_id)
        {
          xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_subject, outer->xrl_subject);
          xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_predicate, inner->xrl_predicate);
          xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_object, inner->xrl_subject);
          xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_type, uname_rdf_ns_uri_Statement);
        }
      dk_free_tree (inner->xrl_predicate);
      inner->xrl_predicate = NULL;
    }
}


void
xp_rdfxml_element_end (void *userdata, const char * name)
{
  xparse_ctx_t *xp = (xparse_ctx_t*) userdata;
  xp_rdf_locals_t *inner = xp->xp_rdf_locals;
  if (XRL_PARSETYPE_LITERAL != inner->xrl_parsetype)
    {
      xp_node_t *current_node = xp->xp_current;
      xp_node_t *parent_node = xp->xp_current->xn_parent;
      xp_rdf_locals_t *outer = inner->xrl_parent;
      if ((NULL != outer) && (XRL_PARSETYPE_COLLECTION == outer->xrl_parsetype))
        {
          xp_rdf_locals_t *outer = inner->xrl_parent;
          caddr_t subj;
          if (NULL == outer->xrl_subject)
            subj = xp_rdfxml_bnode_iid (xp, NULL);
          else
            {
              subj = outer->xrl_subject;
              outer->xrl_subject = NULL; /* To avoid double free, because subj will go to xrl_seq_items */
            }
          dk_set_push (&(outer->xrl_seq_items), subj);
        }
      else if (XRL_PARSETYPE_COLLECTION == inner->xrl_parsetype)
        {
          caddr_t tail = uname_rdf_ns_uri_nil;
          while (NULL != inner->xrl_seq_items)
            {
              caddr_t val = (caddr_t)(inner->xrl_seq_items->data);
              caddr_t node = xp_rdfxml_bnode_iid (xp, NULL);
              xp_rdfxml_triple (xp, node, uname_rdf_ns_uri_first, val);
              xp_rdfxml_triple (xp, node, uname_rdf_ns_uri_rest, tail);
              dk_free_tree (dk_set_pop (&(inner->xrl_seq_items)));
              tail = node;
            }
          xp_rdfxml_triple (xp, outer->xrl_subject, inner->xrl_predicate, tail);
        }
      else if (NULL != inner->xrl_predicate)
        {
          xp_rdf_locals_t *outer = inner->xrl_parent;
          if (NULL == inner->xrl_subject)
            inner->xrl_subject = xp_rdfxml_bnode_iid (xp, NULL);
          xp_rdfxml_triple (xp, outer->xrl_subject, inner->xrl_predicate, inner->xrl_subject);
          if (NULL != inner->xrl_reification_id)
            {
              xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_subject, outer->xrl_subject);
              xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_predicate, inner->xrl_predicate);
              xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_object, inner->xrl_subject);
              xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_type, uname_rdf_ns_uri_Statement);
            }
        }
      if (0 != strses_length (xp->xp_strses))
        GPF_T1("xp_rdfxml_element_end(): non-empty xp_strses outside XRL_PARSETYPE_LITERAL");
      if (NULL != current_node->xn_children)
        GPF_T1("xp_rdfxml_element_end(): non-empty xn_children outside XRL_PARSETYPE_LITERAL");
      dk_free_tree (current_node->xn_attrs);
      xp->xp_current = parent_node;
      current_node->xn_parent = xp->xp_free_list;
      xp->xp_free_list = current_node;
      xp_pop_rdf_locals (xp);
      return;
    }
  if (inner->xrl_xn == xp->xp_current)
    {
      xp_node_t * current_node = xp->xp_current;
      xp_node_t * parent_node = xp->xp_current->xn_parent;
      caddr_t obj;
      xml_tree_ent_t *literal_xte;
      if (NULL == xp->xp_current->xn_children)
        {
          obj = strses_string (xp->xp_strses);
          strses_flush (xp->xp_strses);
        }
      else
        {
          dk_set_t children;
          caddr_t *literal_head;
          caddr_t literal_tree;
          XP_STRSES_FLUSH (xp);
          children = dk_set_nreverse (current_node->xn_children);
          literal_head = (caddr_t *)list (1, uname__root);
          children = CONS (literal_head, children);
          literal_tree = list_to_array (children);
          literal_xte = xte_from_tree (literal_tree, xp->xp_qi);
          obj = (caddr_t) literal_xte;
        }
      dk_free_tree (current_node->xn_attrs);
      xp->xp_current = parent_node;
      current_node->xn_parent = xp->xp_free_list;
      xp->xp_free_list = current_node;
      xp_rdfxml_triple_l (xp, inner->xrl_parent->xrl_subject, inner->xrl_predicate, obj, inner->xrl_datatype, inner->xrl_language);
      dk_free_tree (obj);
      xp_pop_rdf_locals (xp);
      return;
    }
  xp_element_end (userdata, name);
}


void
xp_rdfxml_id (void *userdata, char * name)
{
  xparse_ctx_t * xp = (xparse_ctx_t*) userdata;
  if (XRL_PARSETYPE_LITERAL == xp->xp_rdf_locals->xrl_parsetype)
    xp_id (userdata, name);
}


void
xp_rdfxml_character (vxml_parser_t * parser,  char * s, int len)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) parser;
  switch (xp->xp_rdf_locals->xrl_parsetype)
    {
    case XRL_PARSETYPE_LITERAL:
      session_buffered_write (xp->xp_strses, s, len);
      break;
    case XRL_PARSETYPE_RES_OR_LIT:
      {
        char *tail = s+len;
        while ((--tail) >= s)
          if (NULL == strchr (" \t\r\n", tail[0]))
            {
              xp->xp_rdf_locals->xrl_parsetype = XRL_PARSETYPE_LITERAL;
              session_buffered_write (xp->xp_strses, s, len);
              break;
            }
        break;
      }
    default:
      {
        char *tail = s+len;
        while ((--tail) >= s)
          if (NULL == strchr (" \t\r\n", tail[0]))
            {
            xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Non-whitespace character found instead of XML element");
              return;
            }
        break;
      }
    }
}

void
xp_rdfxml_entity (vxml_parser_t * parser, const char * refname, int reflen, int isparam, const xml_def_4_entity_t *edef)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) parser;
  switch (xp->xp_rdf_locals->xrl_parsetype)
    {
    case XRL_PARSETYPE_LITERAL:
      xp_entity (parser, refname, reflen, isparam, edef);
      break;
    case XRL_PARSETYPE_RES_OR_LIT:
      xp->xp_rdf_locals->xrl_parsetype = XRL_PARSETYPE_LITERAL;
      xp_entity (parser, refname, reflen, isparam, edef);
      break;
    default:
      xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Entity found instead of XML element");
      break;
    }
}

void
xp_rdfxml_pi (vxml_parser_t * parser, const char *target, const char *data)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) parser;
  switch (xp->xp_rdf_locals->xrl_parsetype)
    {
    case XRL_PARSETYPE_LITERAL:
      xp_pi (parser, target, data);
      break;
    case XRL_PARSETYPE_TOP_LEVEL:
      break;
    case XRL_PARSETYPE_RES_OR_LIT:
      xp->xp_rdf_locals->xrl_parsetype = XRL_PARSETYPE_LITERAL;
      xp_pi (parser, target, data);
      break;
    default:
      xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Processing instruction found instead of XML element");
      break;
    }
}

void
xp_rdfxml_comment (vxml_parser_t * parser, const char *text)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) parser;
  switch (xp->xp_rdf_locals->xrl_parsetype)
    {
    case XRL_PARSETYPE_LITERAL:
      xp_comment (parser, text);
      break;
    }
}

caddr_t default_rdf_dtd_config = NULL;

void
rdfxml_parse (query_instance_t * qi, caddr_t text, caddr_t *err_ret,
  int omit_top_rdf, const char *source_name, caddr_t base_uri, caddr_t graph_uri,
  ccaddr_t *cbk_names, caddr_t app_env,
  const char *enc, lang_handler_t *lh
   /*, caddr_t dtd_config, dtd_t **ret_dtd,
   id_hash_t **ret_id_cache, xml_ns_2dict_t *ret_ns_2dict*/ )
{
  int dtp_of_text = box_tag (text);
  vxml_parser_config_t config;
  vxml_parser_t * parser;
  xparse_ctx_t context;
  triple_feed_t *tf;
  int rc;
  xp_node_t *xn;
  xp_rdf_locals_t *root_xrl;
  xml_read_iter_env_t xrie;
  static caddr_t default_dtd_config = NULL;
  memset (&xrie, 0, sizeof (xml_read_iter_env_t));
  if (DV_BLOB_XPER_HANDLE == dtp_of_text)
    sqlr_new_error ("42000", "XM031", "Unable to parse RDF/XML from a persistent XML object");
  if (!xml_set_xml_read_iter (qi, text, &xrie, &enc))
    sqlr_new_error ("42000", "XM032",
      "Unable to parse RDF/XML from data of type %s (%d)", dv_type_title (dtp_of_text), dtp_of_text);
  xn = (xp_node_t *) dk_alloc (sizeof (xp_node_t));
  memset (xn, 0, sizeof(xp_node_t));
  memset (&context, 0, sizeof (context));
  context.xp_current = xn;
  xn->xn_xp = &context;
  root_xrl = (xp_rdf_locals_t *) dk_alloc (sizeof (xp_rdf_locals_t));
  memset (root_xrl, 0, sizeof (xp_rdf_locals_t));
  root_xrl->xrl_base = base_uri;
  root_xrl->xrl_parsetype = XRL_PARSETYPE_TOP_LEVEL;
  root_xrl->xrl_xn = xn;
  context.xp_strses = strses_allocate ();
  context.xp_top = xn;
  context.xp_rdf_locals = root_xrl;
  context.xp_qi = qi;
  memset (&config, 0, sizeof(config));
  config.input_is_wide = xrie.xrie_text_is_wide;
  config.input_is_ge = (omit_top_rdf ? GE_XML : 0);
  config.input_is_html = 0;
  config.input_is_xslt = 0;
  config.user_encoding_handler = intl_find_user_charset;
  config.initial_src_enc_name = enc;
  config.uri_resolver = (VXmlUriResolver)(xml_uri_resolve_like_get);
  config.uri_reader = (VXmlUriReader)(xml_uri_get);
  config.uri_appdata = qi; /* Both xml_uri_resolve_like_get and xml_uri_get uses qi as first argument */
  config.error_reporter = (VXmlErrorReporter)(sqlr_error);
  config.uri = ((NULL == base_uri) ? uname___empty : base_uri);
  if (NULL == default_rdf_dtd_config)
    default_rdf_dtd_config = box_dv_short_string ("Validation=DISABLE SchemaDecl=DISABLE IdCache=DISABLE");
  config.dtd_config = default_dtd_config;
  config.root_lang_handler = lh;
  parser = VXmlParserCreate (&config);
  parser->fill_ns_2dict = 0;
  context.xp_parser = parser;
  VXmlSetUserData (parser, &context);
  VXmlSetElementHandler (parser, (VXmlStartElementHandler) xp_rdfxml_element, xp_rdfxml_element_end);
  VXmlSetIdHandler (parser, (VXmlIdHandler)xp_rdfxml_id);
  VXmlSetCharacterDataHandler (parser, (VXmlCharacterDataHandler) xp_rdfxml_character);
  VXmlSetEntityRefHandler (parser, (VXmlEntityRefHandler) xp_rdfxml_entity);
  VXmlSetProcessingInstructionHandler (parser, (VXmlProcessingInstructionHandler) xp_rdfxml_pi);
  VXmlSetCommentHandler (parser, (VXmlCommentHandler) xp_rdfxml_comment);
  if (NULL != xrie.xrie_iter)
    {
      rdfxml_dbg_printf(("\n\n rdfxml_parse() will parse text input"));
      VXmlParserInput (parser, xrie.xrie_iter, xrie.xrie_iter_data);
    }
  else
    {
      rdfxml_dbg_printf(("\n\n rdfxml_parse() will parse the following text:\n%s\n\n", text));
    }
  tf = tf_alloc ();
  tf->tf_qi = qi;
  tf->tf_graph_uri = graph_uri;
  tf->tf_app_env = app_env;
  tf->tf_creator = "rdf_load_rdfxml";
  tf->tf_input_name = source_name;
  tf->tf_line_no_ptr = &(parser->curr_pos.line_num);
  context.xp_tf = tf;
  QR_RESET_CTX
    {
      tf_set_cbk_names (tf, cbk_names);
      tf->tf_graph_iid = tf_get_iid (tf, tf->tf_graph_uri);
      tf_commit (tf);
      tf_new_graph (tf, tf->tf_graph_uri);
      if (0 == setjmp (context.xp_error_ctx))
        rc = VXmlParse (parser, text, xrie.xrie_text_len);
      else
	rc = 0;
      tf_commit (tf);
    }
  QR_RESET_CODE
    {
      du_thread_t * self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      POP_QR_RESET;
      VXmlParserDestroy (parser);
      xp_free (&context);
      if (NULL != xrie.xrie_iter_abend)
        xrie.xrie_iter_abend (xrie.xrie_iter_data);
      tf_free (tf);
      if (err_ret)
	*err_ret = err;
      else
	dk_free_tree (err);
      return;
    }
  END_QR_RESET;
  if (!rc)
    {
      caddr_t rc_msg = VXmlFullErrorMessage (parser);
      VXmlParserDestroy (parser);
      xp_free (&context);
      if (NULL != xrie.xrie_iter_abend)
        xrie.xrie_iter_abend (xrie.xrie_iter_data);
      tf_free (tf);
      if (err_ret)
	*err_ret = srv_make_new_error ("22007", "XM033", "%.1500s", rc_msg);
      dk_free_box (rc_msg);
      return;
    }
  XP_STRSES_FLUSH (&context);
/*
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
*/
  VXmlParserDestroy (parser);
  xp_free (&context);
  tf_free (tf);
  return;
}
