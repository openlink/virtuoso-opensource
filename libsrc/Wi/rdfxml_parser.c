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

#ifdef NDEBUG
#undef RDFXML_DEBUG
#endif

#ifdef RDFXML_DEBUG
#define rdfxml_dbg_printf(x) dbg_printf (x)
#else
#define rdfxml_dbg_printf(x)
#endif

/*!< RDF/XML parser mode, i.e. what does the parser expect to read */
#define XRL_PARSETYPE_TOP_LEVEL		0x01	/*!< Top-level element (rdf:RDF) */
#define XRL_PARSETYPE_RESOURCE		0x02	/*!< Resource description */
#define XRL_PARSETYPE_LITERAL		0x04	/*!< Literal value */
#define XRL_PARSETYPE_RES_OR_LIT	0x08	/*!< Either resource description or a literal */
#define XRL_PARSETYPE_PROPLIST		0x10	/*!< Sequence of properties of a resource */
#define XRL_PARSETYPE_EMPTYPROP		0x20	/*!< Nothing but ending tag of property */
#define XRL_PARSETYPE_COLLECTION	0x40	/*!< First resource inside collection, other resources are recognized by */
#define XRL_PARSETYPE_SET_EXPLICITLY	0x80	/*!< The parser mode is set explicitly by rdf:parseType attribute */

/*! Stack part of RDF/XML-specific context of XML parser.
These are fields of quad to be created.
"Inheritable" fields are propagated from the parent. Pointers are copied, strings are not copied. */
typedef struct xp_rdfxml_locals_s
{
  struct xp_rdfxml_locals_s *xrl_parent;	/*!< Pointer to parent context */
  xp_node_t *	xrl_xn;			/*!< Node whose not-yet-closed element corresponds to the given context */
  caddr_t	xrl_subject;		/*!< Subject (IRI of named node or blank node IRI_ID); subject is used for nested predicates */
  caddr_t	xrl_predicate;		/*!< Predicate (IRI of named node or blank node IRI_ID) */
  caddr_t	xrl_base;		/*!< Base to resolve relative URIs, inheritable */
  caddr_t	xrl_language;		/*!< Language tag as string or NULL, inheritable */
  caddr_t	xrl_datatype;		/*!< Object data type (named node IRI_ID), not inheritable */
  caddr_t	xrl_reification_id;	/*!< ID used to reify a statement as four quads for S,P,O and rdf:type rdfs:Statement. */
  int		xrl_li_count;		/*!< Counter of used LI, not inheritable */
  dk_set_t	xrl_seq_items;		/*!< Backstack of "Sequence" parseType subjects */
  unsigned char	xrl_parsetype;		/*!< Parse type (one of XRL_DATATYPE_NNN), not inheritable */
  char		xrl_base_set;
  char		xrl_language_set;
} xp_rdfxml_locals_t;

#define RDFA_ICT_PRED_REL_OR_TYPEOF	200	/*!< Forward with ref object */
#define RDFA_ICT_PRED_REV		201	/*!< Reverse predicate */
#define RDFA_ICT_PRED_PROPERTY		202	/*!< Forward predicate with literal object */

/*! [I]n[C]omplete [T]riple.
We should keep subject instead of use of innermost xrdfal_subj.
This is for incomplete triples inside HEAD, they may wait for BASE definition and contain different "about" attributes. */
typedef struct rdfa_ict_s
{
  ptrlong ict_pred_type;	/*!< Predicate type, one of RDFA_ICT_PRED_xxx values */
  caddr_t ict_left;		/*!< Subject by default and object if \c ict_pred_type == RDFA_ICT_PRED_REV */
  caddr_t ict_pred;		/*!< Predicate */
  caddr_t ict_right;		/*!< Object by default and subject if \c ict_pred_type == RDFA_ICT_PRED_REV */
  caddr_t ict_datatype;		/*!< Datatype of a literal object */
  caddr_t ict_language;		/*!< Language of a literal object */
  ptrlong ict_used_as_template;	/*!< The ICT itself was used as a template for cases like <X rel="p"><Y typeof="t" /></X> (even if was not completed) */
} rdfa_ict_t;

#define RDFA_IN_HTML		0x01	/*!< The current tag is XHTML top (or nested), respect <HEAD> and <BODY> if found inside */
#define RDFA_IN_HEAD		0x02	/*!< The current tag is HEAD in XHTML (or nested), the doc is now default subject, do not feed triples immediately to handle <BASE> */
#define RDFA_IN_BASE		0x04	/*!< The current tag is BASE in HEAD in XHTML (or nested), the content will go to all \c xrdfal_base throughout the stack. */
#define RDFA_IN_BODY		0x08	/*!< The current tag is BODY in XHTML (or nested), the doc is now default subject, do feed triples as soon as they're complete */
#define RDFA_IN_LITERAL		0x10	/*!< The parser runs inside an XML literal or a string literal or an unused subtree, because there was a "property" attribute */
#define RDFA_IN_UNUSED		0x20	/*!< The parser runs inside an element with "content" attribute. The attribute is used as a string literal already so there's nothing to do in a subtree. Similarly, it is used for internals of <base href="...">...</base> */
#define RDFA_IN_STRLITERAL	0x40	/*!< The parser runs inside an element with explicit datatype other than rdf:XMLLiteral, so all non-text items should be ignored, only texts are important. */
#define RDFA_IN_XMLLITERAL	0x80	/*!< The parser runs inside an element with explicit rdf:XMLLiteral datatype or datatype is not present but non-text nodes were found. */

/*! Stack part of RDFa-specific context of XML parser.
Unlike RDF/XML, not every opened tag gets its own stack item, because many of them lacks RDFa-specific data at all.
RDFa locals are popped only when an XML element to close corresponds to xrdfal_xn of the innermost local context */

typedef struct xp_rdfa_locals_s
{
  struct xp_rdfa_locals_s *xrdfal_parent;	/*!< Pointer to parent context */
  xp_node_t *	xrdfal_xn;		/*!< Node whose not-yet-closed element corresponds to the given context */
  int		xrdfal_place_bits;	/*!< A combination of RDFA_IN_... bits */
  caddr_t	xrdfal_subj;		/*!< A [new subject] as set at the end of parsing the opening tag. It can be NULL, look up */
  caddr_t	xrdfal_obj_res;		/*!< A [current object resource] as set at the end of parsing the opening tag or created as bnode after that */
  caddr_t	xrdfal_datatype;	/*!< Datatype IRI */
  caddr_t	xrdfal_base;		/*!< Base to resolve relative links as set by <BASE> now in XSLT+RDFa and may be set by xml:base in other XML docs. Automatically inherited from parent */
  caddr_t	xrdfal_language;	/*!< Language label. Automatically inherited from parent */
  caddr_t	xrdfal_vocab;		/*!< Vocabulary URI. Automatically inherited from parent */
  caddr_t *	xrdfal_profile_terms;	/*!< Definitions of terms from an external RDFa profile resource, get-keyword style, sorted by terms for \c ecm_find_name(). Automatically inherited from parent */
  rdfa_ict_t *	xrdfal_ict_buffer;	/*!< Storage for incomplete triples, may contain NULLs at the end */
  int		xrdfal_ict_count;	/*!< Count of stored incomplete triples */
  int		xrdfal_boring_opened_elts;	/*!< Number of opened but not yet closed elements inside RDFA_IN_STRLITERAL or RDFA_IN_UNUSED or "uninteresting" elements between \c xrdfal_xn and next nested \c xp_rdfa_locals_t in chain */
} xp_rdfa_locals_t;

#define RDFA_ATTR_ABOUT		0
#define RDFA_ATTR_CONTENT	1
#define RDFA_ATTR_DATATYPE	2
#define RDFA_ATTR_HREF		3
#define RDFA_ATTR_PREFIX	4
#define RDFA_ATTR_PROFILE	5
#define RDFA_ATTR_PROPERTY	6
#define RDFA_ATTR_REL		7
#define RDFA_ATTR_RESOURCE	8
#define RDFA_ATTR_REV		9
#define RDFA_ATTR_SRC		10
#define RDFA_ATTR_TYPEOF	11
#define RDFA_ATTR_VOCAB		12
#define RDFA_ATTR_XML_BASE	13
#define RDFA_ATTR_XML_LANG	14
#define COUNTOF__RDFA_ATTR	15

#define MDATA_IN_UNUSED		0x01	/*!< The parser runs inside an "blocking" element. This is not used ATM, but can be used later for tags like XMP */
#define MDATA_IN_STRLITERAL	0x02	/*!< The parser runs inside an element with explicit datatype other than rdf:XMLLiteral, so all non-text items should be ignored, only texts are important. */
#define MDATA_IN_XMLLITERAL	0x04	/*!< The parser runs inside an element with explicit rdf:XMLLiteral datatype or datatype is not present but non-text nodes were found. */

/*! Stack part of Microdata-specific context of XML parser.
Unlike RDF/XML, not every opened tag gets its own stack item, because many of them lacks Microdata-specific data at all.
Microdata locals are popped only when an XML element to close corresponds to xmdatal_xn of the innermost local context */

typedef struct xp_mdata_locals_s
{
  struct xp_mdata_locals_s *xmdatal_parent;	/*!< Pointer to parent context */
  xp_node_t *	xmdatal_xn;		/*!< Node whose not-yet-closed element corresponds to the given context */
  int		xmdatal_place_bits;	/*!< A combination of MDATA_IN_... bits */
  caddr_t	xmdatal_subj;		/*!< An [item] as set at the end of parsing the opening tag. It can be NULL inside MDATA_IN_UNUSED, it can be set to Id instead of ITEMID. Automatically inherited from parent */
  int		xmdatal_subj_is_id;	/*!< Flags if \c xmldatal_subj is set by document-wide id, not by a global itemid or a "blank node" itemscope. Automatically inherited from parent */
  int		xmdatal_prop_count;	/*!< Count of predicates set above the current element, they're listed at the beginning of \c xmdatal_preds. Automatically inherited from parent */
  caddr_t *	xmdatal_props;		/*!< Buffer for predicates set above the current element. Automatically inherited from parent */
  caddr_t	xmdatal_datatype;	/*!< Datatype IRI. Automatically inherited from parent */
  int		xmdatal_datatype_is_local;	/*!< Datatype can be removed from \c xpt_subj2type at closing this tag. NOT inherited from parent! */
  caddr_t	xmdatal_base;		/*!< Base to resolve relative links as set by <BASE> now in XSLT+RDFa and may be set by xml:base in other XML docs. Automatically inherited from parent */
  caddr_t	xmdatal_language;	/*!< Language label. Automatically inherited from parent */
  int		xmdatal_boring_opened_elts;	/*!< Number of opened but not yet closed elements inside MDATA_IN_STRLITERAL or MDATA_IN_UNUSED or "uninteresting" elements between \c xmdatal_xn and next nested \c xp_mdata_locals_t in chain */
} xp_mdata_locals_t;

#define MDATA_ATTR_OBJ_CONTENT_STRLIT	0
#define MDATA_ATTR_OBJ_DATETIME		1
#define MDATA_ATTR_OBJ_STRLIT		2
#define MDATA_ATTR_OBJ_CITE_REF		3
#define MDATA_ATTR_OBJ_REF		4
#define MDATA_ATTR_OBJ_NAME		5
#define MDATA_ATTR_ID			6
#define MDATA_ATTR_ITEMID		7
#define MDATA_ATTR_ITEMPROP		8
#define MDATA_ATTR_ITEMREF		9
#define MDATA_ATTR_ITEMSCOPE		10
#define MDATA_ATTR_ITEMTYPE		11
#define MDATA_ATTR_REL			12
#define MDATA_ATTR_XML_BASE		13
#define MDATA_ATTR_XML_LANG		14
#define COUNTOF__MDATA_ATTR		15


/*! This structure is kept in RDFa and Microdata parsers as a DV_ARRAY_OF_POINTER and freed in case of error, to avoid memleaks.
It is allocated once and only partially cleaned by callback calls. */
typedef struct xp_tmp_s
{
/* Common part: */
  caddr_t xpt_base;		/*!< Readed but not saved xml:base */
  caddr_t xpt_lang;		/*!< Readed but not saved xml:lang */
/* RDFa part: */
  caddr_t xpt_dt;		/*!< Readed, not expanded and not saved datatype */
  caddr_t xpt_src;		/*!< Readed, not expanded and not saved subj (obj for reverse preds) */
  caddr_t xpt_href;		/*!< Readed, not expanded and not saved obj (subj for reverse preds or triple from element w/o "rel" or "rev") */
  caddr_t *xpt_rel_preds;	/*!< Readed, not expanded and not saved "rel" predicates */
  caddr_t *xpt_rev_preds;	/*!< Readed, not expanded and not saved "rev" predicates */
  caddr_t *xpt_prop_preds;	/*!< Readed, not expanded and not saved "property" predicates */
  caddr_t *xpt_typeofs;		/*!< Readed, not expanded and not saved "typeof" types */
  caddr_t xpt_obj_res;		/*!< Readed, not expanded and not saved object resource OR composed and not saved bnode object */
  caddr_t xpt_obj_content;	/*!< Readed but not saved content of literal object */
/* Microdata part: */
  id_hash_t *xpt_subj2type;	/*!< Hashtable that maps subjects to type IRIs. itemscopes with itemtype are added here and removed at end of document (if itemscope has itemrefs) or at closing tag (otherwise) */
  id_hash_t *xpt_id2desc;	/*!< Hashtable that maps ids to \c mdata_id_desc_t (i.e., to validation data + accumulators of subjects that itemref-s to that ids) */
  id_hash_t *xpt_dangling_triples;	/*!< Hashtable with triples as keys, values are bitmasks about replacing ids to IRIs in the key triple: 1 = no replaces, 2 = replace S, 4 = replace O, 8 = replace both */
} xp_tmp_t;

#define MDATA_DANGLING_TRIPLE_CVT_BITS(cvt_s,cvt_o) (1 << (((cvt_s) ? 1 : 0) + ((cvt_o) ? 2 : 0)))


extern void xp_pop_rdf_locals (xparse_ctx_t *xp);
extern void xp_pop_rdfa_locals (xparse_ctx_t *xp);
extern xp_rdfxml_locals_t *xp_push_rdf_locals (xparse_ctx_t *xp);


/* Part 1. RDF/XML-specific functions */

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
  xp_rdfxml_locals_t *inner = xp->xp_rdfxml_locals;
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
  xp->xp_rdfxml_locals = inner->xrl_parent;
  memset (inner, -1, sizeof (xp_rdfxml_locals_t));
  inner->xrl_parent = xp->xp_rdfxml_free_list;
  xp->xp_rdfxml_free_list = inner;
}


xp_rdfxml_locals_t *xp_push_rdf_locals (xparse_ctx_t *xp)
{
  xp_rdfxml_locals_t *outer = xp->xp_rdfxml_locals;
  xp_rdfxml_locals_t *inner;
  if (NULL != xp->xp_rdfxml_free_list)
    {
      inner = xp->xp_rdfxml_free_list;
      xp->xp_rdfxml_free_list = inner->xrl_parent;
    }
  else
    inner = dk_alloc (sizeof (xp_rdfxml_locals_t));
  memset (inner, 0, sizeof (xp_rdfxml_locals_t));
  inner->xrl_base = outer->xrl_base;
  inner->xrl_language = outer->xrl_language;
  inner->xrl_parent = outer;
  xp->xp_rdfxml_locals = inner;
  return inner;
}


caddr_t
xp_rdfxml_resolve_iri_avalue (xparse_ctx_t *xp, const char *avalue, int is_id_attr)
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
    {
      local = box_dv_short_string (avalue);
      if (('_' == local[0]) && (':' == local[1]))
        return local;
    }
#if 1
  res = rfc1808_expand_uri (xp->xp_rdfxml_locals->xrl_base, local,
    NULL /*output_cs_name*/, 0, NULL /*base_string_cs_name*/, NULL /*rel_string_cs_name*/, &err);
#else
  res = xml_uri_resolve_like_get (xp->xp_qi, &err, xp->xp_rdfxml_locals->xrl_base, local, NULL /* No need to convert into "UTF-8" because it's UTF-8 already */);
#endif
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
  xparse_ctx_t *xp = (xparse_ctx_t*) userdata;
  xp_rdfxml_locals_t *outer = xp->xp_rdfxml_locals;
  xp_rdfxml_locals_t *inner;
  xp_node_t *xn;
  caddr_t subj_type = NULL;
  int inx, fill, n_attrs, n_ns;
  dk_set_t inner_attr_props = NULL;
  caddr_t tmp_nsuri;
  char * tmp_local;
#ifdef RECOVER_RDF_VALUE
  caddr_t rdf_val = NULL;
#endif
  if (XRL_PARSETYPE_LITERAL & outer->xrl_parsetype)
    {
      xp_element (userdata, name, attrdata);
      return;
    }
  else if (XRL_PARSETYPE_EMPTYPROP & outer->xrl_parsetype)
    xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Sub-element in a predicate element with object node attribute");
  inner = xp_push_rdf_locals (xp);
  xn = xp->xp_free_list;
  if (NULL == xn)
    xn = (xp_node_t *)dk_alloc (sizeof (xp_node_t));
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
          if (!(XRL_PARSETYPE_TOP_LEVEL & outer->xrl_parsetype))
            xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 200, "Element rdf:RDF can appear only at top level");
          inner->xrl_parsetype = XRL_PARSETYPE_RESOURCE;
        }
      else if (!strcmp ("Description", tmp_local))
        {
          if (XRL_PARSETYPE_PROPLIST & outer->xrl_parsetype)
            xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 200, "Element rdf:Description can not appear in list of properties");
          inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
        }
      else if (XRL_PARSETYPE_PROPLIST & outer->xrl_parsetype)
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
      else
        {
          size_t l1, l2;
          caddr_t full_element_name;
          if (
            !strcmp ("Property", tmp_local) ||
            !strcmp ("Bag", tmp_local) ||
            !strcmp ("Seq", tmp_local) ||
            !strcmp ("Alt", tmp_local)  ||
            !strcmp ("List", tmp_local) ||
            !strcmp ("Statement", tmp_local) ||
            !strcmp ("nil", tmp_local) )
            { ; }
          else if (
            !strcmp ("subject", tmp_local) ||
            !strcmp ("predicate", tmp_local) ||
            !strcmp ("object", tmp_local) ||
            !strcmp ("type", tmp_local) ||
            !strcmp ("value", tmp_local) ||
            !strcmp ("first", tmp_local) ||
            !strcmp ("rest", tmp_local) ||
            '_' == tmp_local[0] )
            {
              xmlparser_logprintf (xp->xp_parser, XCFG_WARNING, 200, "Name rdf:%.200s is used for node, not for property (legal, but strange)", tmp_local);
            }
          else if (
            !strcmp ("ID", tmp_local) ||
            !strcmp ("about", tmp_local) ||
            !strcmp ("bagID", tmp_local) ||
            !strcmp ("parseType", tmp_local) ||
            !strcmp ("resource", tmp_local) ||
            !strcmp ("nodeID", tmp_local) ||
            !strcmp ("li", tmp_local) ||
            !strcmp ("aboutEach", tmp_local) ||
            !strcmp ("aboutEachPrefix", tmp_local) )
            {
              xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 200, "Name rdf:%.200s is used for node", tmp_local);
            }
          else
            {
              xmlparser_logprintf (xp->xp_parser, XCFG_WARNING, 200, "Unknown name rdf:%.200s is used (legal, but strange)", tmp_local);
            }
          l1 = strlen (tmp_nsuri);
          l2 = strlen (tmp_local);
          full_element_name = dk_alloc_box (l1 + l2 + 1, DV_STRING);
          memcpy (full_element_name, tmp_nsuri, l1);
          strcpy (full_element_name + l1, tmp_local);
          subj_type = xp->xp_boxed_name = full_element_name;
          inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
        }
    }
  else
    {
      size_t l1 = strlen (tmp_nsuri), l2 = strlen (tmp_local);
      caddr_t full_element_name = dk_alloc_box (l1 + l2 + 1, DV_STRING);
      memcpy (full_element_name, tmp_nsuri, l1);
      strcpy (full_element_name + l1, tmp_local);
      if (XRL_PARSETYPE_PROPLIST & outer->xrl_parsetype)
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
  /* we do one loop first to see if there are xml:base, xml:lang or xml:space then rest */
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
            {
              caddr_t local_base;
              if ((NULL != inner->xrl_base) && ('\0' != inner->xrl_base))
                local_base = xp_rdfxml_resolve_iri_avalue (xp, avalue, 0);
              else
                local_base = box_dv_short_string (avalue);
              XRL_SET_INHERITABLE (inner, xrl_base, local_base, "Attribute 'xml:base' is used twice");
              TF_CHANGE_BASE_AND_DEFAULT_GRAPH(xp->xp_tf, box_copy (local_base));
            }
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
              if (XRL_PARSETYPE_PROPLIST & outer->xrl_parsetype)
                {
                  xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Attribute 'rdf:about' can not appear in element that is supposed to be property name");
                  return;
                }
              inner_subj = xp_rdfxml_resolve_iri_avalue (xp, avalue, 0);
              XRL_SET_NONINHERITABLE (inner, xrl_subject, inner_subj, "Attribute 'rdf:about' conflicts with other attribute that set the subject");
              inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
            }
          else if (!strcmp (tmp_local, "resource"))
            {
              caddr_t inner_subj;
              if (!(XRL_PARSETYPE_PROPLIST & outer->xrl_parsetype))
                {
                  xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Attribute 'rdf:resource' can appear only in element that is supposed to be property name");
                  return;
                }
              inner_subj = xp_rdfxml_resolve_iri_avalue (xp, avalue, 0);
              XRL_SET_NONINHERITABLE (inner, xrl_subject, inner_subj, "Attribute 'rdf:resource' conflicts with other attribute that set the subject");
              inner->xrl_parsetype = XRL_PARSETYPE_EMPTYPROP;
            }
          else if (!strcmp (tmp_local, "nodeID"))
            {
              caddr_t inner_subj = xp_rdfxml_bnode_iid (xp, box_dv_short_string (avalue));
              XRL_SET_NONINHERITABLE (inner, xrl_subject, inner_subj, "Attribute 'rdf:nodeID' conflicts with other attribute that set the subject");
              if (XRL_PARSETYPE_PROPLIST & outer->xrl_parsetype)
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
              if (XRL_PARSETYPE_PROPLIST & outer->xrl_parsetype)
                {
                  caddr_t reif_subj = xp_rdfxml_resolve_iri_avalue (xp, avalue, 1);
                  XRL_SET_NONINHERITABLE (inner, xrl_reification_id, reif_subj, "Reification ID of the statement is set twice by 'rdf:ID' attribute of a property element");
                }
              else
                {
                  caddr_t inner_subj = xp_rdfxml_resolve_iri_avalue (xp, avalue, 1);
                  XRL_SET_NONINHERITABLE (inner, xrl_subject, inner_subj, "Attribute 'rdf:ID' conflicts with other attribute that set node ID");
                  inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
                }
            }
          else if (!strcmp (tmp_local, "datatype"))
            {
              if (!(XRL_PARSETYPE_PROPLIST & outer->xrl_parsetype))
                {
                  xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Attribute 'rdf:datatype' can appear only in property elements");
                  return;
                }
              XRL_SET_NONINHERITABLE (inner, xrl_datatype, xp_rdfxml_resolve_iri_avalue (xp, avalue, 0),  "Attribute 'rdf:datatype' is used twice");
              inner->xrl_parsetype = XRL_PARSETYPE_LITERAL;
            }
          else if (!strcmp (tmp_local, "parseType"))
            {
              if (!(XRL_PARSETYPE_PROPLIST & outer->xrl_parsetype))
                {
                  xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Attribute 'rdf:parseType' can appear only in property elements");
                  return;
                }
              if (!strcmp (avalue, "Resource"))
                {
                  caddr_t inner_subj = xp_rdfxml_bnode_iid (xp, NULL);
                  XRL_SET_NONINHERITABLE (inner, xrl_subject, inner_subj, "Attribute parseType='Resource' can not be used if object is set by other attribute");
                  inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST | XRL_PARSETYPE_SET_EXPLICITLY;
                }
              else if (!strcmp (avalue, "Literal"))
                {
                  inner->xrl_parsetype = XRL_PARSETYPE_LITERAL | XRL_PARSETYPE_SET_EXPLICITLY;
                }
              else if (!strcmp (avalue, "Collection"))
                {
                  inner->xrl_parsetype = XRL_PARSETYPE_COLLECTION | XRL_PARSETYPE_SET_EXPLICITLY;
                  return;
                }
              else
                {
                  xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Unknown parseType");
                  return;
                }
            }
          else if (!strcmp (tmp_local, "type"))
            {
              dk_set_push (&inner_attr_props, avalue);
              dk_set_push (&inner_attr_props, ((caddr_t)((ptrlong)'T')));
              inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
              continue;
            }
          else if (!strcmp (tmp_local, "value"))
            {
#ifdef RECOVER_RDF_VALUE
              rdf_val = avalue;
#else
              goto push_inner_attr_prop; /* see below */
#endif
            }
          else
            {
              xmlparser_logprintf (xp->xp_parser, XCFG_WARNING, 200,
                "Unsupported 'rdf:...' attribute" );
                goto push_inner_attr_prop; /* see below */
            }
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
      if (XRL_PARSETYPE_LITERAL & inner->xrl_parsetype)
        {
          xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 200,
            "Conflicting attributes: property value can not be a node and a literal simultaneously" );
          return;
        }
    }
  if (NULL == inner->xrl_subject)
    {
      if ((NULL != inner_attr_props) || (NULL != subj_type) ||
#ifdef RECOVER_RDF_VALUE
        (NULL != rdf_val) ||
#endif
        (XRL_PARSETYPE_PROPLIST & inner->xrl_parsetype) )
        {
          caddr_t inner_subj = xp_rdfxml_bnode_iid (xp, NULL);
          XRL_SET_NONINHERITABLE (inner, xrl_subject, inner_subj, "Blank node object can not be defined here");
          inner->xrl_parsetype = XRL_PARSETYPE_PROPLIST;
        }
    }
  if ((XRL_PARSETYPE_PROPLIST & inner->xrl_parsetype) && (NULL != outer->xrl_predicate))
    XRL_SET_NONINHERITABLE (outer, xrl_subject, box_copy_tree (inner->xrl_subject), "A property can not have two object values");
  if (NULL != subj_type)
    xp_rdfxml_triple (xp, inner->xrl_subject, uname_rdf_ns_uri_type, subj_type);
#ifdef RECOVER_RDF_VALUE
  if (NULL != rdf_val)
    { /* This preserves semantics */
      caddr_t resolved_rdf_val = xp_rdfxml_resolve_iri_avalue (xp, rdf_val, 0);
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
      if (!IS_BOX_POINTER (tmp_nsuri))
        {
          avalue = dk_set_pop (&inner_attr_props);
          xp_rdfxml_triple (xp, inner->xrl_subject, uname_rdf_ns_uri_type, avalue);
          continue;
        }
      tmp_local = dk_set_pop (&inner_attr_props);
      avalue = dk_set_pop (&inner_attr_props);
      l1 = strlen (tmp_nsuri);
      l2 = strlen (tmp_local);
      xp->xp_boxed_name = aname = dk_alloc_box (l1 + l2 + 1, DV_STRING);
      memcpy (aname, tmp_nsuri, l1);
      strcpy (aname + l1, tmp_local);
      xp_rdfxml_triple_l (xp, inner->xrl_subject, aname, avalue, NULL, inner->xrl_language);
      dk_free_box (aname);
      xp->xp_boxed_name = NULL;
    }
  if ((XRL_PARSETYPE_PROPLIST & inner->xrl_parsetype) && (XRL_PARSETYPE_PROPLIST & outer->xrl_parsetype))
    { /* This means parseType="Resource". It should be handled immediately to prevent error in case of parseType="Resource" nested inside inner. */
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
  xp_rdfxml_locals_t *inner = xp->xp_rdfxml_locals;
  if (!(XRL_PARSETYPE_LITERAL & inner->xrl_parsetype))
    {
      xp_node_t *current_node = xp->xp_current;
      xp_node_t *parent_node = xp->xp_current->xn_parent;
      xp_rdfxml_locals_t *outer = inner->xrl_parent;
      if ((NULL != outer) && (XRL_PARSETYPE_COLLECTION & outer->xrl_parsetype))
        {
          xp_rdfxml_locals_t *outer = inner->xrl_parent;
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
      else if (XRL_PARSETYPE_COLLECTION & inner->xrl_parsetype)
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
          xp_rdfxml_locals_t *outer = inner->xrl_parent;
          if ((NULL == inner->xrl_subject) && (XRL_PARSETYPE_RES_OR_LIT & inner->xrl_parsetype))
            {
              caddr_t obj = box_dv_short_string ("");
              xp_rdfxml_triple_l (xp, inner->xrl_parent->xrl_subject, inner->xrl_predicate, obj, inner->xrl_datatype, inner->xrl_language);
              if (NULL != inner->xrl_reification_id)
                {
                  xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_subject, outer->xrl_subject);
                  xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_predicate, inner->xrl_predicate);
                  xp_rdfxml_triple_l (xp, inner->xrl_reification_id, uname_rdf_ns_uri_object, obj, inner->xrl_datatype, inner->xrl_language);
                  xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_type, uname_rdf_ns_uri_Statement);
                }
              dk_free_tree (obj);
            }
          else
            {
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
      xp_rdfxml_locals_t *outer = inner->xrl_parent;
      caddr_t lang_in_effect;
      caddr_t obj;
      xml_tree_ent_t *literal_xte;
      if ((NULL == xp->xp_current->xn_children) && !(XRL_PARSETYPE_SET_EXPLICITLY & inner->xrl_parsetype))
        {
          obj = strses_string (xp->xp_strses);
          strses_flush (xp->xp_strses);
          lang_in_effect = inner->xrl_language;
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
	  literal_xte->xe_doc.xd->xout_encoding = box_dv_short_string ("UTF-8");
          obj = (caddr_t) literal_xte;
          lang_in_effect = NULL;
        }
      dk_free_tree (current_node->xn_attrs);
      xp->xp_current = parent_node;
      current_node->xn_parent = xp->xp_free_list;
      xp->xp_free_list = current_node;
      xp_rdfxml_triple_l (xp, outer->xrl_subject, inner->xrl_predicate, obj, inner->xrl_datatype, lang_in_effect);
      if (NULL != inner->xrl_reification_id)
        {
          xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_subject, outer->xrl_subject);
          xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_predicate, inner->xrl_predicate);
          xp_rdfxml_triple_l (xp, inner->xrl_reification_id, uname_rdf_ns_uri_object, obj, inner->xrl_datatype, lang_in_effect);
          xp_rdfxml_triple (xp, inner->xrl_reification_id, uname_rdf_ns_uri_type, uname_rdf_ns_uri_Statement);
        }
      dk_free_tree (obj);
      xp_pop_rdf_locals (xp);
      return;
    }
  xp_element_end (userdata, name);
}


void
xp_rdfxml_id (void *userdata, char * name)
{
  xparse_ctx_t *xp = (xparse_ctx_t*) userdata;
  if (XRL_PARSETYPE_LITERAL & xp->xp_rdfxml_locals->xrl_parsetype)
    xp_id (userdata, name);
}


void
xp_rdfxml_character (vxml_parser_t * parser,  char * s, int len)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) parser;
  switch (xp->xp_rdfxml_locals->xrl_parsetype & (XRL_PARSETYPE_LITERAL | XRL_PARSETYPE_RES_OR_LIT))
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
              xp->xp_rdfxml_locals->xrl_parsetype = XRL_PARSETYPE_LITERAL;
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
  switch (xp->xp_rdfxml_locals->xrl_parsetype & (XRL_PARSETYPE_LITERAL | XRL_PARSETYPE_RES_OR_LIT))
    {
    case XRL_PARSETYPE_LITERAL:
      xp_entity (parser, refname, reflen, isparam, edef);
      break;
    case XRL_PARSETYPE_RES_OR_LIT:
      xp->xp_rdfxml_locals->xrl_parsetype = XRL_PARSETYPE_LITERAL;
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
  switch (xp->xp_rdfxml_locals->xrl_parsetype & (XRL_PARSETYPE_LITERAL | XRL_PARSETYPE_TOP_LEVEL | XRL_PARSETYPE_RES_OR_LIT))
    {
    case XRL_PARSETYPE_LITERAL:
      xp_pi (parser, target, data);
      break;
    case XRL_PARSETYPE_TOP_LEVEL:
      break;
    case XRL_PARSETYPE_RES_OR_LIT:
      xp->xp_rdfxml_locals->xrl_parsetype = XRL_PARSETYPE_LITERAL;
      xp_pi (parser, target, data);
      break;
    default:
      xmlparser_logprintf (xp->xp_parser, XCFG_WARNING, 100, "Processing instruction found instead of XML element");
      break;
    }
}

void
xp_rdfxml_comment (vxml_parser_t * parser, const char *text)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) parser;
  switch (xp->xp_rdfxml_locals->xrl_parsetype)
    {
    case XRL_PARSETYPE_LITERAL:
      xp_comment (parser, text);
      break;
    }
}

caddr_t default_rdf_dtd_config = NULL;

/* Part 2. RDFa-specific functions */

void
xp_expand_relative_uri (caddr_t base, caddr_t *relative_ptr)
{
  caddr_t relative = relative_ptr[0];
  caddr_t expanded;
  caddr_t err = NULL;
  if ((NULL == base) || ('\0' == base[0])
    || (NULL == relative) || (DV_IRI_ID == DV_TYPE_OF (relative)) || !strncmp (relative, "http://", 7)
    || !strncmp (relative, "_:", 2) )
    return;
  expanded = rfc1808_expand_uri (/*xn->xn_xp->xp_qi,*/ base, relative, "UTF-8", 0, "UTF-8", "UTF-8", &err);
  if (NULL != err)
    {
#ifdef RDFXML_DEBUG
      GPF_T1("xp_" "expand_relative_uri(): expand_uri failed");
#else
      expanded = NULL;
#endif
    }
  if (expanded == base)
    expanded = box_copy (expanded);
  else if (expanded != relative)
    dk_free_box (relative);
  relative_ptr[0] = expanded;
}


caddr_t
xp_rdfa_expand_name (xp_node_t * xn, const char *name, const char *colon, int use_default_ns/*, caddr_t base*/)
{
  xp_node_t * ctx_xn;
  size_t ns_len = 0, nsinx;
  const char *local;
  caddr_t relative = NULL;
  if (!colon && !use_default_ns)
    {
      relative = box_dv_short_string (name);
      goto relative_is_set; /* see below */
    }
  if (NULL != colon)
    {
      ns_len = colon - name;
      local = colon + 1;
      if (bx_std_ns_pref (name, ns_len))
        return box_dv_short_strconcat (uname_xml, local);
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
              relative = box_dv_short_strconcat (ns_uri, local);
              goto relative_is_set; /* see below */
            }
	}
      ctx_xn = ctx_xn->xn_parent;
    }
  if (0 != ns_len)
    {
      if (NULL != colon)
        {
          caddr_t pref = box_dv_short_nchars (name, ns_len);
          caddr_t ns_uri = xml_get_ns_uri (xn->xn_xp->xp_qi->qi_client, pref, ~0, 0);
          dk_free_box (pref);
          if (NULL != ns_uri)
            {
              relative = box_dv_short_strconcat (ns_uri, local);
              dk_free_box (ns_uri);
              goto relative_is_set; /* see below */
            }
          dk_free_box (ns_uri);
        }
      return NULL; /* error: undefined namespace prefix */
    }
  relative = box_dv_short_string (name);

relative_is_set:
  /*xp_expand_relative_uri (base, &relative);*/
  return relative;
}


const char *rdfa_attribute_names[COUNTOF__RDFA_ATTR] = {
    "about"	,
    "content"	,
    "datatype"	,
    "href"	,
    "prefix"	,
    "profile"	,
    "property"	,
    "rel"	,
    "resource"	,
    "rev"	,
    "src"	,
    "typeof"	,
    "vocab"	,
    "xml:base"	,
    "xml:lang"	};


caddr_t
rdfa_rel_rev_value_is_reserved (const char *val)
{
  char buf[15];
  int ctr, pos;
  static void *vals[] = {
    "alternate"		, &uname_xhv_ns_uri_alternate	,
    "appendix"		, &uname_xhv_ns_uri_appendix	,
    "bookmark"		, &uname_xhv_ns_uri_bookmark	,
    "chapter"		, &uname_xhv_ns_uri_chapter	,
    "cite"		, &uname_xhv_ns_uri_cite	,
    "contents"		, &uname_xhv_ns_uri_contents	,
    "copyright"		, &uname_xhv_ns_uri_copyright	,
    "first"		, &uname_xhv_ns_uri_first	,
    "glossary"		, &uname_xhv_ns_uri_glossary	,
    "help"		, &uname_xhv_ns_uri_help	,
    "icon"		, &uname_xhv_ns_uri_icon	,
    "index"		, &uname_xhv_ns_uri_index	,
    "last"		, &uname_xhv_ns_uri_last	,
    "license"		, &uname_xhv_ns_uri_license	,
    "meta"		, &uname_xhv_ns_uri_meta	,
    "next"		, &uname_xhv_ns_uri_next	,
    "p3pv1"		, &uname_xhv_ns_uri_p3pv1	,
    "prev"		, &uname_xhv_ns_uri_prev	,
    "role"		, &uname_xhv_ns_uri_role	,
    "section"		, &uname_xhv_ns_uri_section	,
    "start"		, &uname_xhv_ns_uri_start	,
    "stylesheet"	, &uname_xhv_ns_uri_stylesheet	,
    "subsection"	, &uname_xhv_ns_uri_subsection	,
    "top"		, &uname_xhv_ns_uri_start	, /* NOT uname_xhv_ns_uri_top, because "top" is synonym for "start", see sect. 9.3. of "RDFa in XHTML:Syntax and Processing" */
    "up"		, &uname_xhv_ns_uri_up		};
  for (ctr = 0; '\0' != val[ctr]; ctr++)
    {
      if ((sizeof (buf)-1) <= ctr)
        return NULL; /* The buffer is long enough to fit all known strings, overflow means mismatch */
      buf[ctr] = tolower (val[ctr]);
    }
  buf[ctr] = '\0';
  pos = ecm_find_name (buf, vals, sizeof (vals)/(2 * sizeof(void *)), 2 * sizeof(void *));
  if (ECM_MEM_NOT_FOUND == pos)
    return NULL;
  return ((caddr_t **)vals) [2 * pos + 1][0];
}

#define RDFA_ATTRSYNTAX_TERM			0x0001
#define RDFA_ATTRSYNTAX_URI			0x0002
#define RDFA_ATTRSYNTAX_SAFECURIE		0x0004
#define RDFA_ATTRSYNTAX_CURIE			0x0008
#define RDFA_ATTRSYNTAX_REL_REV_RESERVED	0x0010
#define RDFA_ATTRSYNTAX_WS_LIST			0x0020
#define RDFA_ATTRSYNTAX_EMPTY_ACCEPTABLE	0x0040
#define RDFA_ATTRSYNTAX_EMPTY_MEANS_XSD_STRING	0x0080
#define RDFA_ATTRSYNTAX_DIRTY_HREF		0x0100

caddr_t
xp_rdfa_parse_attr_value (xparse_ctx_t *xp, xp_node_t * xn, int attr_id, char **attrvalues, int allowed_syntax, caddr_t **values_ret, int *values_count_ret)
{
  char *attrvalue = attrvalues[attr_id];
  char *tail = attrvalue;
  char *token_start, *token_end;
  int token_syntax;
  char *curie_colon;
  caddr_t /*base = NULL,*/ expanded_token = NULL;
  int values_count, expanded_token_not_saved = 0;
#define free_unsaved_token() do { \
  if (expanded_token_not_saved) { \
      dk_free_box (expanded_token); \
      expanded_token = NULL; \
      expanded_token_not_saved = 0; } \
  } while (0)
#ifdef RDFXML_DEBUG
  if (((NULL != values_ret) ? 1 : 0) != ((NULL != values_count_ret) ? 1 : 0))
    GPF_T1 ("xp_" "rdfa_parse_attr_value(): bad call (1)");
  if (((NULL != values_ret) ? 1 : 0) != ((RDFA_ATTRSYNTAX_WS_LIST & allowed_syntax) ? 1 : 0))
    GPF_T1 ("xp_" "rdfa_parse_attr_value(): bad call (2)");
#endif
  if (NULL != values_ret)
    {
      if (NULL == values_ret[0])
        values_ret[0] = dk_alloc_box_zero (sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      values_count = values_count_ret[0];
    }
  else
    values_count = 0;

next_token:
  if (RDFA_ATTRSYNTAX_WS_LIST & allowed_syntax)
    while (('\0' != tail[0]) && isspace (tail[0])) tail++;
  else if (isspace (tail[0]))
    {
      free_unsaved_token();
      xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "Whitespaces are not allowed for attribute %.20s", rdfa_attribute_names[attr_id]);
      return expanded_token;
    }
  if ('\0' == tail[0])
    {
      if (0 == values_count)
        {
          if (RDFA_ATTRSYNTAX_WS_LIST & allowed_syntax)
            return NULL;
          if (!((RDFA_ATTRSYNTAX_EMPTY_ACCEPTABLE | RDFA_ATTRSYNTAX_EMPTY_MEANS_XSD_STRING) & allowed_syntax))
            xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "Empty value is not allowed for attribute %.20s", rdfa_attribute_names[attr_id]);
          expanded_token = (RDFA_ATTRSYNTAX_EMPTY_MEANS_XSD_STRING & allowed_syntax) ? uname_xmlschema_ns_uri_hash_string : uname___empty;
          if (NULL != values_ret)
            { /* I expect that zero length buffer is never passed */
              if (NULL != values_ret[0][values_count]) /* There's some old garbage to delete */
                dk_free_tree (values_ret[0][values_count]);
              values_ret[0][values_count++] = expanded_token;
              expanded_token_not_saved = 0;
              values_count_ret[0] = values_count;
            }
        }
      if (NULL != values_count_ret)
        values_count_ret[0] = values_count;
      return expanded_token;
    }
  if ((1 == values_count) && !(RDFA_ATTRSYNTAX_WS_LIST & allowed_syntax))
    {
      free_unsaved_token();
      xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "Multiple values are not allowed for attribute %.20s", rdfa_attribute_names[attr_id]);
      if (NULL != values_count_ret)
        values_count_ret[0] = values_count;
      return NULL;
    }
  token_syntax = allowed_syntax & (RDFA_ATTRSYNTAX_TERM | RDFA_ATTRSYNTAX_SAFECURIE | RDFA_ATTRSYNTAX_CURIE | RDFA_ATTRSYNTAX_URI);
  if ('[' == tail[0])
    {
      if (!(RDFA_ATTRSYNTAX_SAFECURIE & allowed_syntax))
        {
          free_unsaved_token();
          xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "\"Safe CURIE\" syntax is not allowed for attribute \"%.20s\", ignored", rdfa_attribute_names[attr_id]);
          return NULL;
        }
      token_syntax = RDFA_ATTRSYNTAX_SAFECURIE;
      tail++;
    }
  else if (':' == tail[0])
    {
      token_syntax &= ~(RDFA_ATTRSYNTAX_SAFECURIE | RDFA_ATTRSYNTAX_TERM);
      if (0 == token_syntax)
        {
          free_unsaved_token();
          xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "The token value should start with a letter or underscore in attribute \"%.20s\", ignored", rdfa_attribute_names[attr_id]);
          return NULL;
        }
    }
  else if (!(isalpha (tail[0]) || ('_' == tail[0]) || (tail[0] & ~0x7F) || (':' == tail[0])))
    {
      token_syntax &= ~(RDFA_ATTRSYNTAX_SAFECURIE | RDFA_ATTRSYNTAX_CURIE | RDFA_ATTRSYNTAX_TERM);
      if (0 == token_syntax)
        {
          free_unsaved_token();
          xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "The token value should start with a letter, colon or underscore in attribute \"%.20s\", ignored", rdfa_attribute_names[attr_id]);
          return NULL;
        }
    }
  else
    token_syntax &= ~RDFA_ATTRSYNTAX_SAFECURIE;
  token_start = tail;
  curie_colon = NULL;
  if ((RDFA_ATTRSYNTAX_SAFECURIE | RDFA_ATTRSYNTAX_CURIE | RDFA_ATTRSYNTAX_TERM) & token_syntax)
    {
      while (isalnum (tail[0]) || ('_' == tail[0]) || (tail[0] & ~0x7F)) tail++;
      if (':' == tail[0])
        {
          curie_colon = tail;
          tail++;
          token_syntax &= ~RDFA_ATTRSYNTAX_TERM;
          if (0 == token_syntax)
            {
              free_unsaved_token();
              xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "The value of attribute \"%.20s\" contains a token that is not a valid NCName, ignored", rdfa_attribute_names[attr_id]);
              return NULL;
            }
        }
      if (token_syntax & (RDFA_ATTRSYNTAX_SAFECURIE | RDFA_ATTRSYNTAX_CURIE | RDFA_ATTRSYNTAX_URI))
        while (('\0' != tail[0]) && (']' != tail[0]) && !isspace(tail[0])) tail++;
    }
  else if (RDFA_ATTRSYNTAX_DIRTY_HREF & token_syntax)
    {
      int lpar_found = 0;
      int qmark_found = 0;
      while ('\0' != tail[0])
        {
          if ('?' == tail[0])
            qmark_found = 1;
          else if (('[' == tail[0]) || (']' == tail[0]))
            {
              if (!lpar_found && strchr (tail, '('))
                lpar_found = 1;                         /* 012345678901 */
              if (!qmark_found && !lpar_found && strncmp ("javascript:", attrvalue, 11))
                break;
              else
                allowed_syntax |= ~RDFA_ATTRSYNTAX_WS_LIST;
            }
          else if ('(' == tail[0])
            lpar_found = 1;
          else if (isspace(tail[0]))
            {
              if (RDFA_ATTRSYNTAX_WS_LIST & allowed_syntax)
                break;
              if (!lpar_found && strchr (tail, '('))
                lpar_found = 1;         /* 012345678901 */
              if (!lpar_found && strncmp ("javascript:", attrvalue, 11))
                break;
            }
          tail++;
        }
    }
  else
    {
      while (('\0' != tail[0]) && ('[' != tail[0]) && (']' != tail[0]) && !isspace(tail[0]))
        tail++;
    }
  token_end = tail;
  switch (tail[0])
    {
    case '[':
      free_unsaved_token();
      xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100,
        ((RDFA_ATTRSYNTAX_SAFECURIE & token_syntax) ?
          "Unterminated \"safe CURIE\" before '[' in the value of attribute \"%.20s\"" :
          "Character '[' is not allowed inside token in the value of attribute \"%.20s\"" ),
        rdfa_attribute_names[attr_id] );
      tail = "";
      break;
    case ']':
      if (RDFA_ATTRSYNTAX_SAFECURIE & token_syntax)
        tail++;
      else
        {
          free_unsaved_token();
          xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100,
            "Unexpected character ']' in the value of attribute \"%.20s\"",
            rdfa_attribute_names[attr_id] );
          tail = "";
        }
      break;
    default:
      if (RDFA_ATTRSYNTAX_SAFECURIE & token_syntax)
        {
          free_unsaved_token();
          xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100,
            "No closing ']' found at the end of \"safe CURIE\" in the value of attribute \"%.20s\"",
            rdfa_attribute_names[attr_id] );
          tail = "";
        }
      break;
    }
  if (NULL != values_ret)
    {
      if (values_count == BOX_ELEMENTS (values_ret[0]))
        {
          caddr_t new_buf = dk_alloc_box_zero (sizeof (caddr_t) * values_count * 2, DV_ARRAY_OF_POINTER);
          memcpy (new_buf, values_ret[0], box_length (values_ret[0]));
          dk_free_box (values_ret[0]);
          values_ret[0] = (caddr_t *)new_buf;
        }
      else if (NULL != values_ret[0][values_count]) /* There's some old garbage to delete */
        {
#ifdef RDFXML_DEBUG
          GPF_T1 ("xp_" "rdfa_parse_attr_value(): garbage?");
#endif
          dk_free_tree (values_ret[0][values_count]);
          values_ret[0][values_count] = NULL;
        }
    }
  /*base = xn->xn_xp->xp_rdfa_locals->xrdfal_base;*/
  if ((NULL != curie_colon) /*|| ((NULL != base) && ('\0' != base[0]))*/)
    {
      char saved_token_delim = token_end[0];
      token_end[0] = '\0';
      if (('_' == token_start[0]) && (curie_colon == token_start + 1))
        expanded_token = tf_bnode_iid (xp->xp_tf, box_dv_short_nchars (token_start+2, token_end-(token_start+2)));
      else if (curie_colon == token_start)
        { /* Note that the default prefix mapping may differ from usage to usage, it is xhtml vocab namespace only for RDFa */
          expanded_token = box_dv_short_strconcat (uname_xhv_ns_uri, curie_colon+1);
        }
      else
        expanded_token = xp_rdfa_expand_name (xn, token_start, curie_colon, 1/*, base*/);
      token_end[0] = saved_token_delim;
      if (NULL == expanded_token)
        {
          if (RDFA_ATTRSYNTAX_URI & token_syntax)
            expanded_token = box_dv_short_nchars (token_start, token_end-token_start);
          else
            {
#ifndef NDEBUG
              token_end[0] = '\0';
              if (('_' == token_start[0]) && (curie_colon == token_start + 1))
                expanded_token = tf_bnode_iid (xp->xp_tf, box_dv_short_nchars (token_start+2, token_end-(token_start+2)));
              else if (curie_colon == token_start)
                { /* Note that the default prefix mapping may differ from usage to usage, it is xhtml vocab namespace only for RDFa */
                  expanded_token = box_dv_short_strconcat (uname_xhv_ns_uri, curie_colon+1);
                }
              else
                expanded_token = xp_rdfa_expand_name (xn, token_start, curie_colon, 1/*, base*/);
              token_end[0] = saved_token_delim;
#endif
              xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100,
                "Bad token in the value of attribute \"%.20s\" (undeclared namespace?)",
                rdfa_attribute_names[attr_id] );
            }
        }
    }
  else if (RDFA_ATTRSYNTAX_TERM & allowed_syntax)
    {
      xp_rdfa_locals_t *ancestor;
      char saved_token_delim = token_end[0];
      token_end[0] = '\0';
      expanded_token = NULL;
      for (ancestor = xp->xp_rdfa_locals; NULL != ancestor; ancestor = ancestor->xrdfal_parent)
        {
          caddr_t *pterms = ancestor->xrdfal_profile_terms;
          int pos;
          if (NULL == pterms)
            break;
          pos = ecm_find_name (token_start, pterms, BOX_ELEMENTS (pterms) / 2, 2*sizeof (caddr_t));
          if (ECM_MEM_NOT_FOUND == pos)
            continue;
          expanded_token = box_copy (pterms[pos * 2 + 1]);
          break;
        }
      if (NULL == expanded_token)
        {
          if ((RDFA_ATTRSYNTAX_REL_REV_RESERVED & allowed_syntax) ||
            ((NULL != xp->xp_rdfa_locals) && (RDFA_IN_HTML & xp->xp_rdfa_locals->xrdfal_place_bits)) )
            expanded_token = rdfa_rel_rev_value_is_reserved (token_start);
        }
      if (NULL == expanded_token)
        {
          if ((NULL != xp->xp_rdfa_locals) && (NULL != xp->xp_rdfa_locals->xrdfal_vocab))
            expanded_token = box_dv_short_strconcat (xp->xp_rdfa_locals->xrdfal_vocab, token_start);
        }
      token_end[0] = saved_token_delim;
      if (NULL == expanded_token)
        {
#if 1
          goto next_token; /* see above */
#else
          expanded_token = box_dv_short_nchars (token_start, token_end-token_start);
#endif
        }
    }
  else if ((RDFA_ATTRSYNTAX_SAFECURIE & token_syntax) && (token_end == token_start))
    {
      xp_rdfa_locals_t *ancestor = xp->xp_rdfa_locals;
      while ((NULL != ancestor) && (NULL == ancestor->xrdfal_subj))
        ancestor = ancestor->xrdfal_parent;
      expanded_token = box_copy ((NULL != ancestor->xrdfal_subj) ? ancestor->xrdfal_subj : uname___empty);
    }
  else
    expanded_token = box_dv_short_nchars (token_start, token_end-token_start);
  if (NULL == expanded_token)
    goto next_token; /* see above */
  expanded_token_not_saved = 1;
  if (NULL != values_ret)
    {
      values_ret[0][values_count] = expanded_token;
      expanded_token_not_saved = 0;
    }
  values_count++;
  goto next_token; /* see above */
}


void
xp_rdfa_parse_prefix (xparse_ctx_t *xp, char *attrvalue, caddr_t **values_ret, int *values_count_ret)
{
  dk_set_t res = NULL;
  int res_count = 0;
  char *prefix_begin, *prefix_end, *nsuri_begin, *tail = attrvalue;
  while ('\0' != tail[0])
    {
      while (('\0' != tail[0]) && isspace (tail[0])) tail++;
      prefix_begin = tail;
      if (!(isalpha (tail[0]) || ('_' == tail[0]) || (tail[0] & ~0x7F) || (':' == tail[0])))
        goto err; /* see below */
      while (isalnum (tail[0]) || ('_' == tail[0]) || (tail[0] & ~0x7F)) tail++;
      prefix_end = tail;
      if (':' != tail[0])
        goto err; /* see below */
      tail++;
      while (('\0' != tail[0]) && isspace (tail[0])) tail++;
      if ('\0' == tail[0])
        goto err; /* see below */
      nsuri_begin = tail;
      while (('\0' != tail[0]) && !isspace (tail[0])) tail++;
      dk_set_push (&res, box_dv_uname_nchars (prefix_begin, prefix_end - prefix_begin));
      dk_set_push (&res, box_dv_uname_nchars (nsuri_begin, tail - nsuri_begin));
      res_count += 2;
    }
  values_ret[0] = (caddr_t *)revlist_to_array (res);
  values_count_ret[0] = res_count;
  return;
err:
  while (NULL != res) dk_free_box (dk_set_pop (&res));
  xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "Attribute \"prefix\" should be well-formed list of namespace prefixe and URI pairs");
}

void
xp_rdfa_parse_profile (xparse_ctx_t *xp, caddr_t *parsed_attrvalue, caddr_t **ns_dict_ret, caddr_t **term_dict_ret, caddr_t *vocab_ret, caddr_t *err_ret)
{
  client_connection_t *cli = xp->xp_qi->qi_client;
  caddr_t full_profile_proc_name = NULL;
  query_t *fetch_profile_qr = NULL;
  caddr_t err = NULL;
  char  params_buf [BOX_AUTO_OVERHEAD + sizeof (caddr_t) * 4];
  caddr_t * params;
  BOX_AUTO_TYPED (caddr_t *, params, params_buf, sizeof (caddr_t) * 4, DV_ARRAY_OF_POINTER);
  ns_dict_ret[0] = NULL;
  term_dict_ret[0] = NULL;
  vocab_ret[0] = NULL;
  err_ret[0] = NULL;
  if (NULL == full_profile_proc_name)
    full_profile_proc_name = sch_full_proc_name (wi_inst.wi_schema, "DB.DBA.RDF_RDFA11_FETCH_PROFILES", cli_qual (cli), CLI_OWNER (cli));
  if (NULL == fetch_profile_qr)
    fetch_profile_qr = sch_proc_def (wi_inst.wi_schema, full_profile_proc_name);
  if (NULL == fetch_profile_qr)
    sqlr_new_error ("42001", "SRxxx",
        "RDFa 1.1 parser needs a procedure named \"%.100s\"", full_profile_proc_name);
  if (fetch_profile_qr->qr_to_recompile)
    {
      fetch_profile_qr = qr_recompile (fetch_profile_qr, &err);
      if (NULL != err)
        sqlr_resignal (err);
    }
  params[0] = (caddr_t)parsed_attrvalue;
  params[1] = (caddr_t)ns_dict_ret;
  params[2] = (caddr_t)term_dict_ret;
  params[3] = (caddr_t)vocab_ret;
  err = qr_exec (cli, fetch_profile_qr, xp->xp_qi, NULL, NULL, NULL, (caddr_t *)params, NULL, 0);
  BOX_DONE (params, params_buf);
  if (NULL != err)
    err_ret[0] = err;
}
;


void
xp_pop_rdfa_locals (xparse_ctx_t *xp)
{
  xp_rdfa_locals_t *inner = xp->xp_rdfa_locals;
  xp_rdfa_locals_t *parent = inner->xrdfal_parent;
  if ((NULL != inner->xrdfal_base) &&
    ((NULL == parent) || (inner->xrdfal_base != parent->xrdfal_base)) )
    dk_free_tree (inner->xrdfal_base);
  if ((NULL != inner->xrdfal_language) &&
    ((NULL == parent) || (inner->xrdfal_language != parent->xrdfal_language)) )
    dk_free_tree (inner->xrdfal_language);
  if ((NULL != inner->xrdfal_vocab) &&
    ((NULL == parent) || (inner->xrdfal_vocab != parent->xrdfal_vocab)) )
    dk_free_tree (inner->xrdfal_vocab);
  if ((NULL != inner->xrdfal_profile_terms) &&
    ((NULL == parent) || (inner->xrdfal_profile_terms != parent->xrdfal_profile_terms)) )
    dk_free_tree ((caddr_t)(inner->xrdfal_profile_terms));
  if ((NULL != inner->xrdfal_subj) &&
    ((NULL == parent) || ((inner->xrdfal_subj != parent->xrdfal_subj) && (inner->xrdfal_subj != parent->xrdfal_obj_res))) )
    dk_free_tree (inner->xrdfal_subj);
  if ((NULL != inner->xrdfal_obj_res) && (inner->xrdfal_obj_res != inner->xrdfal_subj) &&
    ((NULL == parent) || (inner->xrdfal_obj_res != parent->xrdfal_obj_res)) )
    dk_free_tree (inner->xrdfal_obj_res);
  if (NULL != inner->xrdfal_datatype)
    dk_free_tree (inner->xrdfal_datatype);
#ifdef RDFXML_DEBUG
  if (NULL != inner->xrdfal_ict_buffer)
    {
      int ofs;
      for (ofs = BOX_ELEMENTS (inner->xrdfal_ict_buffer); ofs--; /* no step */)
        {
          if (NULL != ((caddr_t *)(inner->xrdfal_ict_buffer))[ofs])
            GPF_T1 ("xp_" "pop_rdfa_locals(): lost data");
        }
    }
#endif
  xp->xp_rdfa_locals = parent;
  inner->xrdfal_parent = xp->xp_rdfa_free_list;
  xp->xp_rdfa_free_list = inner;
}


xp_rdfa_locals_t *
xp_push_rdfa_locals (xparse_ctx_t *xp)
{
  xp_rdfa_locals_t *outer = xp->xp_rdfa_locals;
  xp_rdfa_locals_t *inner;
  rdfa_ict_t *reused_buf;
  if (NULL != xp->xp_rdfa_free_list)
    {
      inner = xp->xp_rdfa_free_list;
      reused_buf = inner->xrdfal_ict_buffer;
      xp->xp_rdfa_free_list = inner->xrdfal_parent;
    }
  else
    {
      inner = dk_alloc (sizeof (xp_rdfa_locals_t));
      reused_buf = NULL;
    }
  memset (inner, 0, sizeof (xp_rdfa_locals_t));
  inner->xrdfal_ict_buffer = reused_buf;
  inner->xrdfal_parent = outer;
  if (outer)
    {
      inner->xrdfal_base = outer->xrdfal_base;
      inner->xrdfal_language = outer->xrdfal_language;
      inner->xrdfal_vocab = outer->xrdfal_vocab;
      inner->xrdfal_profile_terms = outer->xrdfal_profile_terms;
    }
  xp->xp_rdfa_locals = inner;
  return inner;
}

void
xp_rdfa_set_base (xparse_ctx_t *xp, xp_rdfa_locals_t *inner, caddr_t new_base)
{
  xp_rdfa_locals_t *ancestor;
  caddr_t old_base_inside = NULL;
  for (ancestor = inner; (NULL != ancestor) && (RDFA_IN_HTML & ancestor->xrdfal_place_bits); ancestor = ancestor->xrdfal_parent)
    {
      caddr_t old_base = ancestor->xrdfal_base;
      if (old_base_inside != old_base)
        dk_free_box (old_base_inside);
      ancestor->xrdfal_base = new_base;
      old_base_inside = old_base;
    }
}

#define RDFA_ICT_FEED_OK	300
#define RDFA_ICT_IN_HEAD	301
#define RDFA_ICT_NO_OBJ		302
#define RDFA_ICT_INTERNAL_ERR	303

int
rdfa_ict_feed_or_leave (xparse_ctx_t *xp, xp_rdfa_locals_t *xrdfal, int ctr)
{
  rdfa_ict_t *ict;
  int last;
  static caddr_t stub_null = NULL;
  if (xrdfal->xrdfal_place_bits & RDFA_IN_HEAD)
    return RDFA_ICT_IN_HEAD;
  ict = xrdfal->xrdfal_ict_buffer + ctr;
  if (NULL == ict->ict_left)
#ifdef RDFXML_DEBUG
    GPF_T1("rdfa_" "ict_feed_or_leave(): NULL ict->ict_left");
#else
    return RDFA_ICT_INTERNAL_ERR;
#endif
  if (NULL == ict->ict_pred)
#ifdef RDFXML_DEBUG
    GPF_T1("rdfa_" "ict_feed_or_leave(): NULL ict->ict_pred");
#else
    return RDFA_ICT_INTERNAL_ERR;
#endif
  if (NULL == ict->ict_right)
    return RDFA_ICT_NO_OBJ;
  ict = xrdfal->xrdfal_ict_buffer + ctr;
  switch (ict->ict_pred_type)
    {
    case RDFA_ICT_PRED_REL_OR_TYPEOF:
      tf_triple (xp->xp_tf, ict->ict_left, ict->ict_pred, ict->ict_right);
      break;
    case RDFA_ICT_PRED_REV:
      tf_triple (xp->xp_tf, ict->ict_right, ict->ict_pred, ict->ict_left);
      break;
    case RDFA_ICT_PRED_PROPERTY:
      if (NULL == stub_null)
        stub_null = NEW_DB_NULL;
      tf_triple_l (xp->xp_tf, ict->ict_left, ict->ict_pred, ict->ict_right,
        (((NULL != ict->ict_datatype) && (uname___empty != ict->ict_datatype)) ? ict->ict_datatype : stub_null),
        ((NULL != ict->ict_language) ? ict->ict_language : stub_null) );
      break;
#ifdef RDFXML_DEBUG
    default:
      GPF_T1("rdfa_" "ict_feed_or_leave(): bad ict->ict_pred_type");
#endif
    }
  dk_free_box (ict->ict_left);
  dk_free_box (ict->ict_pred);
  dk_free_box (ict->ict_right);
  dk_free_box (ict->ict_datatype);
  dk_free_box (ict->ict_language);
  last = --(xrdfal->xrdfal_ict_count);
  if (last > ctr)
    memcpy (ict, xrdfal->xrdfal_ict_buffer + last, sizeof (rdfa_ict_t));
  memset (xrdfal->xrdfal_ict_buffer + last, 0, sizeof (rdfa_ict_t));
  return RDFA_ICT_FEED_OK;
}

void
rdfa_feed_or_make_ict (xparse_ctx_t *xp, xp_rdfa_locals_t *xrdfal, caddr_t left, caddr_t pred, caddr_t right, int pred_type, caddr_t dt, caddr_t lang)
{
  int ict_is_needed = 0;
  static caddr_t stub_null = NULL;
  if ((xrdfal->xrdfal_place_bits & RDFA_IN_BODY) || !(xrdfal->xrdfal_place_bits & RDFA_IN_HTML))
    {
      xp_expand_relative_uri (xrdfal->xrdfal_base, &left);
      xp_expand_relative_uri (xrdfal->xrdfal_base, &pred);
      if (RDFA_ICT_PRED_PROPERTY == pred_type)
        {
          if (uname___empty != dt)
            xp_expand_relative_uri (xrdfal->xrdfal_base, &dt);
        }
      else
        xp_expand_relative_uri (xrdfal->xrdfal_base, &right);
    }
  else
    ict_is_needed = 1;
#ifdef RDFXML_DEBUG
  if (NULL == left)
    GPF_T1("rdfa_" "feed_or_make_ict(): NULL left");
  if (NULL == pred)
    GPF_T1("rdfa_" "feed_or_make_ict(): NULL pred");
#endif
  if (NULL == right)
    ict_is_needed = 1;
  if (ict_is_needed)
    {
      rdfa_ict_t *ict;
      int buf_in_use = xrdfal->xrdfal_ict_count * sizeof (rdfa_ict_t);
      if (NULL == xrdfal->xrdfal_ict_buffer)
        xrdfal->xrdfal_ict_buffer = dk_alloc_box_zero (sizeof (rdfa_ict_t), DV_ARRAY_OF_POINTER);
      if (box_length (xrdfal->xrdfal_ict_buffer) <= buf_in_use)
        {
          rdfa_ict_t *new_buf;
#ifdef RDFXML_DEBUG
          if (box_length (xrdfal->xrdfal_ict_buffer) < buf_in_use)
            GPF_T1("rdfa_" "feed_or_make_ict(): corrupted buffer allocation");
#endif
          new_buf = (rdfa_ict_t *)dk_alloc_box_zero (buf_in_use * 2, DV_ARRAY_OF_POINTER);
          memcpy (new_buf, xrdfal->xrdfal_ict_buffer, buf_in_use);
          dk_free_box ((caddr_t)(xrdfal->xrdfal_ict_buffer));
          xrdfal->xrdfal_ict_buffer = new_buf;
        }
      ict = xrdfal->xrdfal_ict_buffer + (xrdfal->xrdfal_ict_count)++;
      ict->ict_left = left;
      ict->ict_pred = pred;
      ict->ict_right = right;
      ict->ict_pred_type = pred_type;
      ict->ict_datatype = dt;
      ict->ict_language = lang;
    }
  else
    {
      switch (pred_type)
        {
        case RDFA_ICT_PRED_REL_OR_TYPEOF:
          tf_triple (xp->xp_tf, left, pred, right);
          break;
        case RDFA_ICT_PRED_REV:
          tf_triple (xp->xp_tf, right, pred, left);
          break;
        case RDFA_ICT_PRED_PROPERTY:
          if (NULL == stub_null)
            stub_null = NEW_DB_NULL;
          tf_triple_l (xp->xp_tf, left, pred, right,
            (((NULL != dt) && (uname___empty != dt)) ? dt : stub_null),
            ((NULL != lang) ? lang : stub_null) );
          break;
#ifdef RDFXML_DEBUG
        default:
          GPF_T1("rdfa_" "ict_feed_or_leave(): bad ict->ict_pred_type");
#endif
        }
      dk_free_box (left);
      dk_free_box (pred);
      dk_free_box (right);
      dk_free_box (dt);
      dk_free_box (lang);
    }
}

void
xp_rdfa_element (void *userdata, char * name, vxml_parser_attrdata_t *attrdata)
{
  xparse_ctx_t *xp = (xparse_ctx_t*) userdata;
  xp_rdfa_locals_t *outer = xp->xp_rdfa_locals;
  xp_rdfa_locals_t *inner = NULL; /* This is not allocated at all if there's nothing "interesting" in the tag */
  xp_tmp_t *xpt = xp->xp_tmp;
  xp_node_t *xn = xp->xp_current;
  caddr_t avalues[COUNTOF__RDFA_ATTR];
  int acode, inx, fill, n_attrs, n_ns, xn_is_allocated = 0, inner_is_allocated = 0;
  char *local_name;
  int rel_rev_attrcount = 0, rel_pred_count = 0, rev_pred_count = 0, prop_pred_count = 0, typeof_count = 0;
  int src_prio = 0xff; /* 1 for "about", 2 for "src" */
  int href_prio = 0xff; /* 3 for "resource", 4 for "href" */
  int outer_place_bits = outer->xrdfal_place_bits;
  int inner_place_bits = outer_place_bits; /* Place bits are first inherited, then changed (OR-ed) */
  int need_rdfa_local = 0, parent_obj_should_be_set = 0;
  int ctr;
  caddr_t subj, bnode_subj = NULL;
#ifdef RDFXML_DEBUG
  if (xpt->xpt_base || xpt->xpt_dt || xpt->xpt_lang || xpt->xpt_obj_content || xpt->xpt_obj_res || xpt->xpt_src || xpt->xpt_href)
    GPF_T1("xp_" "rdfa_element(): nonempty xpt");
#endif
#ifdef RECOVER_RDF_VALUE
  caddr_t rdf_val = NULL;
#endif
  if (RDFA_IN_LITERAL & outer_place_bits)
    {
      if (!((RDFA_IN_STRLITERAL | RDFA_IN_XMLLITERAL) & outer_place_bits))
        {
          outer->xrdfal_place_bits |= RDFA_IN_XMLLITERAL;
          outer_place_bits = outer->xrdfal_place_bits;
          outer->xrdfal_datatype = uname_rdf_ns_uri_XMLLiteral;
        }
      if ((RDFA_IN_UNUSED | RDFA_IN_STRLITERAL) & outer_place_bits)
        outer->xrdfal_boring_opened_elts++;
      else
        xp_element (userdata, name, attrdata);
      return;
    }
/* Let's make xp->xp_free_list nonempty just to not duplicate this code in few places below */
  if (NULL == xp->xp_free_list)
    {
      xp->xp_free_list = dk_alloc (sizeof (xp_node_t));
      xp->xp_free_list->xn_parent = NULL;
    }
  n_ns = attrdata->local_nsdecls_count;
  if (n_ns)
    {
      caddr_t *save_ns;
      xn = xp->xp_free_list;
      xp->xp_free_list = xn->xn_parent;
      memset (xn, 0, sizeof (xp_node_t));
      xn->xn_xp = xp;
      xn->xn_parent = xp->xp_current;
      xp->xp_current = xn;
      xn_is_allocated = 1;
      need_rdfa_local = 1;
      save_ns = (caddr_t*) dk_alloc_box (2 * n_ns * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      /* Trick here: xn->xn_attrs is set to xn->xn_namespaces in order to free memory on errors or element end. */
      xn->xn_attrs = xn->xn_namespaces = save_ns;
      fill = 0;
      for (inx = 0; inx < n_ns; inx++)
        {
          save_ns[fill++] = box_dv_uname_string (attrdata->local_nsdecls[inx].nsd_prefix);
          save_ns[fill++] = box_dv_uname_string (attrdata->local_nsdecls[inx].nsd_uri);
        }
    }
/* Setting place bits */
  local_name = strchr (name, ':');
  if (NULL == local_name)
    local_name = name;
  if (RDFA_IN_HEAD & outer_place_bits)
    {
      if (!strcmp (local_name, "base"))
        {
          if (RDFA_IN_BASE & outer_place_bits)
            xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "Element \"base\" can not appear inside other \"base\" element");
          inner_place_bits |= RDFA_IN_BASE;
          need_rdfa_local = 1;
        }
    }
  if (RDFA_IN_HTML & outer_place_bits)
    {
      if (!strcmp (local_name, "head"))
        {
          if ((RDFA_IN_HEAD | RDFA_IN_BODY) & outer_place_bits)
            xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "Element \"head\" can not appear inside %s element", (RDFA_IN_HEAD & outer_place_bits) ? "other \"head\"" : "\"body\"");
          else
            inner_place_bits |= RDFA_IN_HEAD;
          need_rdfa_local = 1;
        }
      else if (!strcmp (local_name, "body"))
        {
          if ((RDFA_IN_HEAD | RDFA_IN_BODY) & outer_place_bits)
            xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "Element \"body\" can not appear inside %s element", (RDFA_IN_BODY & outer_place_bits) ? "other \"body\"" : "\"head\"");
          else
            inner_place_bits |= RDFA_IN_BODY;
          need_rdfa_local = 1;
        }
    }
  if (!strcmp (local_name, "html") || !strcmp (local_name, "xhtml"))
    {
      if (RDFA_IN_HTML & outer_place_bits)
        xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "Element \"html\" can not appear inside other \"html\" element");
      else
        inner_place_bits |= RDFA_IN_HTML;
      need_rdfa_local = 1;
    }
  n_attrs = attrdata->local_attrs_count;
  memset (avalues, 0, sizeof (avalues));
  if (0 == n_attrs)
    goto all_attributes_are_retrieved; /* see below */
  for (inx = 0; inx < n_attrs; inx ++)
    {
      char *raw_aname = attrdata->local_attrs[inx].ta_raw_name.lm_memblock;
      acode = ecm_find_name (raw_aname, rdfa_attribute_names, sizeof (rdfa_attribute_names)/sizeof(char *), sizeof(char *));
      if (0 > acode)
        continue;
      need_rdfa_local = 1;
      if (NULL != avalues[acode])
        xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Duplicate attribute names in one element head");
      avalues[acode] = attrdata->local_attrs[inx].ta_value;
    }
  if ((NULL != avalues[RDFA_ATTR_VOCAB]) || (NULL != avalues[RDFA_ATTR_PROFILE]) || (NULL != avalues[RDFA_ATTR_PREFIX]))
    {
      if (!xn_is_allocated)
        {
          xn = xp->xp_free_list;
          xp->xp_free_list = xn->xn_parent;
          memset (xn, 0, sizeof (xp_node_t));
          xn->xn_xp = xp;
          xn->xn_parent = xp->xp_current;
          xp->xp_current = xn;
          xn_is_allocated = 1;
        }
      if (!inner_is_allocated)
        {
          inner = xp_push_rdfa_locals (xp);
          inner_is_allocated = 1;
        }
      if (NULL != avalues[RDFA_ATTR_VOCAB])
        {
          caddr_t vocab;
          if ('\0' == avalues[RDFA_ATTR_VOCAB][0])
            vocab = uname_xhv_ns_uri;
          else
            vocab = xp_rdfa_parse_attr_value (xp, xn, RDFA_ATTR_VOCAB, avalues, RDFA_ATTRSYNTAX_URI, NULL, NULL);
          inner->xrdfal_vocab = vocab;
        }
      if (NULL != avalues[RDFA_ATTR_PROFILE])
        {
          caddr_t *profile_uris = NULL;
          int profile_uri_count = 0;
          caddr_t *ns_tokens;
          caddr_t *term_tokens;
          caddr_t vocab;
          caddr_t err;
          int ns_token_count;
          caddr_t *new_ns;
          int old_ns_boxlen;
          xp_rdfa_parse_attr_value (xp, xn, RDFA_ATTR_PROFILE, avalues,
            RDFA_ATTRSYNTAX_URI | RDFA_ATTRSYNTAX_EMPTY_ACCEPTABLE | RDFA_ATTRSYNTAX_WS_LIST,
            &profile_uris, &profile_uri_count );
          xp_rdfa_parse_profile (xp, profile_uris, &ns_tokens, &term_tokens, &vocab, &err);
          old_ns_boxlen = ((NULL != xn->xn_namespaces) ? box_length (xn->xn_namespaces) : 0);
          ns_token_count = BOX_ELEMENTS_0 (ns_tokens);
          new_ns = (caddr_t*) dk_alloc_box (ns_token_count * sizeof (caddr_t) + old_ns_boxlen, DV_ARRAY_OF_POINTER);
          memcpy (new_ns, ns_tokens, ns_token_count * sizeof (caddr_t));
          if (old_ns_boxlen)
            {
              memcpy (new_ns + ns_token_count, xn->xn_namespaces, old_ns_boxlen);
              dk_free_box ((caddr_t)(xn->xn_namespaces));
            }
          xn->xn_attrs = xn->xn_namespaces = new_ns;
          if (BOX_ELEMENTS_0 (term_tokens))
            inner->xrdfal_profile_terms = term_tokens;
          if ((DV_STRING == DV_TYPE_OF (vocab)) && (NULL == inner->xrdfal_vocab))
            inner->xrdfal_vocab = vocab;
          else
            dk_free_box (vocab);
          if (NULL != err)
            {
              dk_free_tree (err);
              inner->xrdfal_place_bits |= RDFA_IN_UNUSED;
              return;
            }
        }
      if (NULL != avalues[RDFA_ATTR_PREFIX])
        {
          caddr_t *ns_tokens = NULL;
          int ns_token_count = 0;
          caddr_t *new_ns;
          int old_ns_boxlen;
          xp_rdfa_parse_prefix (xp, avalues[RDFA_ATTR_PREFIX], &ns_tokens, &ns_token_count);
          old_ns_boxlen = ((NULL != xn->xn_namespaces) ? box_length (xn->xn_namespaces) : 0);
          new_ns = (caddr_t*) dk_alloc_box (ns_token_count * sizeof (caddr_t) + old_ns_boxlen, DV_ARRAY_OF_POINTER);
          memcpy (new_ns, ns_tokens, ns_token_count * sizeof (caddr_t));
          if (old_ns_boxlen)
            {
              memcpy (new_ns + ns_token_count, xn->xn_namespaces, old_ns_boxlen);
              dk_free_box ((caddr_t)(xn->xn_namespaces));
            }
          xn->xn_attrs = xn->xn_namespaces = new_ns;
        }
    }
  if (NULL != avalues[RDFA_ATTR_ABOUT])
    {
      if (1 <= src_prio)
        {
          dk_free_tree (xpt->xpt_src);
          xpt->xpt_src = NULL; /* to avoid second delete of freed value in case of error inside xp_rdfa_parse_attr_value() */
          xpt->xpt_src = xp_rdfa_parse_attr_value (xp, xn, RDFA_ATTR_ABOUT, avalues,
            RDFA_ATTRSYNTAX_SAFECURIE | RDFA_ATTRSYNTAX_CURIE | RDFA_ATTRSYNTAX_URI | RDFA_ATTRSYNTAX_EMPTY_ACCEPTABLE,
            NULL, NULL );
          src_prio = 1;
        }
    }
  if (NULL != avalues[RDFA_ATTR_CONTENT])
    {
      xpt->xpt_obj_content = box_dv_short_string (avalues[RDFA_ATTR_CONTENT]);
    }
  if (NULL != avalues[RDFA_ATTR_DATATYPE])
    {
      xpt->xpt_dt = xp_rdfa_parse_attr_value (xp, xn, RDFA_ATTR_DATATYPE, avalues,
        RDFA_ATTRSYNTAX_TERM | RDFA_ATTRSYNTAX_CURIE | RDFA_ATTRSYNTAX_URI | RDFA_ATTRSYNTAX_EMPTY_ACCEPTABLE,
        NULL, NULL );
    }
  if (NULL != avalues[RDFA_ATTR_HREF])
    {
      if (RDFA_IN_BASE & inner_place_bits)
        {
          dk_free_tree (xpt->xpt_href);
          xpt->xpt_href = NULL; /* to avoid second delete of freed value in case of error inside xp_rdfa_parse_attr_value() */
          xpt->xpt_href = xp_rdfa_parse_attr_value (xp, xn, RDFA_ATTR_HREF, avalues,
            RDFA_ATTRSYNTAX_URI | RDFA_ATTRSYNTAX_EMPTY_ACCEPTABLE | RDFA_ATTRSYNTAX_DIRTY_HREF,
            NULL, NULL );
          xp_rdfa_set_base (xp, outer, xpt->xpt_href);
          xpt->xpt_href = NULL;
          inner_place_bits |= RDFA_IN_UNUSED;
        }
      else if (4 <= href_prio)
        {
          dk_free_tree (xpt->xpt_href);
          xpt->xpt_href = NULL; /* to avoid second delete of freed value in case of error inside xp_rdfa_parse_attr_value() */
          xpt->xpt_href = xp_rdfa_parse_attr_value (xp, xn, RDFA_ATTR_HREF, avalues,
            RDFA_ATTRSYNTAX_URI | RDFA_ATTRSYNTAX_EMPTY_ACCEPTABLE | RDFA_ATTRSYNTAX_DIRTY_HREF,
            NULL, NULL );
          href_prio = 4;
        }
    }
  if (NULL != avalues[RDFA_ATTR_PROPERTY])
    {
      xp_rdfa_parse_attr_value (xp, xn, RDFA_ATTR_PROPERTY, avalues,
        RDFA_ATTRSYNTAX_TERM | RDFA_ATTRSYNTAX_CURIE | RDFA_ATTRSYNTAX_URI | RDFA_ATTRSYNTAX_WS_LIST,
        &(xpt->xpt_prop_preds), &prop_pred_count );
    }
  if (NULL != avalues[RDFA_ATTR_REL])
    {
      xp_rdfa_parse_attr_value (xp, xn, RDFA_ATTR_REL, avalues,
        RDFA_ATTRSYNTAX_TERM | RDFA_ATTRSYNTAX_CURIE | RDFA_ATTRSYNTAX_URI | RDFA_ATTRSYNTAX_REL_REV_RESERVED | RDFA_ATTRSYNTAX_WS_LIST,
        &(xpt->xpt_rel_preds), &rel_pred_count );
      rel_rev_attrcount++;
    }
  if (NULL != avalues[RDFA_ATTR_RESOURCE])
    {
      if (3 <= href_prio)
        {
          dk_free_tree (xpt->xpt_href);
          xpt->xpt_href = NULL; /* to avoid second delete of freed value in case of error inside xp_rdfa_parse_attr_value() */
          xpt->xpt_href = xp_rdfa_parse_attr_value (xp, xn, RDFA_ATTR_RESOURCE, avalues,
            RDFA_ATTRSYNTAX_SAFECURIE | RDFA_ATTRSYNTAX_CURIE | RDFA_ATTRSYNTAX_URI | RDFA_ATTRSYNTAX_EMPTY_ACCEPTABLE,
            NULL, NULL );
          href_prio = 3;
        }
    }
  if (NULL != avalues[RDFA_ATTR_REV])
    {
      xp_rdfa_parse_attr_value (xp, xn, RDFA_ATTR_REV, avalues,
        RDFA_ATTRSYNTAX_TERM | RDFA_ATTRSYNTAX_CURIE | RDFA_ATTRSYNTAX_URI | RDFA_ATTRSYNTAX_REL_REV_RESERVED | RDFA_ATTRSYNTAX_WS_LIST,
        &(xpt->xpt_rev_preds), &rev_pred_count );
      rel_rev_attrcount++;
    }
  if (NULL != avalues[RDFA_ATTR_SRC])
    {
      if (2 <= src_prio)
        {
          dk_free_tree (xpt->xpt_src);
          xpt->xpt_src = NULL; /* to avoid second delete of freed value in case of error inside xp_rdfa_parse_attr_value() */
          xpt->xpt_src = xp_rdfa_parse_attr_value (xp, xn, RDFA_ATTR_SRC, avalues,
            RDFA_ATTRSYNTAX_URI | RDFA_ATTRSYNTAX_EMPTY_ACCEPTABLE,
            NULL, NULL );
          src_prio = 2;
        }
    }
  if (NULL != avalues[RDFA_ATTR_TYPEOF])
    {
      xp_rdfa_parse_attr_value (xp, xn, RDFA_ATTR_TYPEOF, avalues,
        RDFA_ATTRSYNTAX_TERM | RDFA_ATTRSYNTAX_CURIE | RDFA_ATTRSYNTAX_URI | RDFA_ATTRSYNTAX_WS_LIST,
        &(xpt->xpt_typeofs), &typeof_count );
    }
  if (NULL != avalues[RDFA_ATTR_XML_BASE])
    {
      if (!(RDFA_IN_HTML & inner_place_bits))
        {
          if (NULL != xpt->xpt_base)
            dk_free_tree (xpt->xpt_base);
          xpt->xpt_base = box_dv_short_string (avalues[RDFA_ATTR_XML_BASE]);
        }
    }
  if (NULL != avalues[RDFA_ATTR_XML_LANG])
    {
      if (NULL != xpt->xpt_lang)
        dk_free_tree (xpt->xpt_lang);
      xpt->xpt_lang = box_dv_short_string (avalues[RDFA_ATTR_XML_LANG]);
    }

all_attributes_are_retrieved:
/* At this point, all attributes are retrieved. The rest is straightforward implementation of "Processing model" */
/* Setting the [new subject] */
  for (;;)
    {
      subj = xpt->xpt_src;
      if (NULL != subj)
        break;
      if (!rel_rev_attrcount)
        {
          subj = xpt->xpt_href;
          if (NULL != subj)
            break;
        }
      if ((RDFA_IN_HTML & outer_place_bits) &&
        !((RDFA_IN_HEAD | RDFA_IN_BODY) & outer_place_bits) &&
        ((RDFA_IN_HEAD | RDFA_IN_BODY) & inner_place_bits) )
        {
          subj = uname___empty;
          need_rdfa_local = 1;
        }
      else if (NULL != avalues[RDFA_ATTR_TYPEOF]) /* There was "if (0 != typeof_count)" here but that's wrong for typeof="" needed solely to make a bnode */
	{
	  bnode_subj = subj = tf_bnode_iid (xp->xp_tf, NULL);
	}
      else if (!(RDFA_IN_HTML & inner_place_bits) && (NULL == xn->xn_parent)) /*1104 */
        {
          subj = uname___empty;
          need_rdfa_local = 1;
        }
      break;
    }
  if (prop_pred_count)
    {
      inner_place_bits |= RDFA_IN_LITERAL;
      if (NULL != xpt->xpt_obj_content)
        inner_place_bits |= RDFA_IN_UNUSED;
      else if (NULL != xpt->xpt_dt)
        {
          if (strcmp (xpt->xpt_dt, uname_rdf_ns_uri_XMLLiteral))
            inner_place_bits |= RDFA_IN_STRLITERAL;
          else
            inner_place_bits |= RDFA_IN_XMLLITERAL;
        }
    }
/* Escape if nothing interesting is detected at all */
  if (!need_rdfa_local)
    {
      outer->xrdfal_boring_opened_elts++;
      if (bnode_subj)
	dk_free_box (bnode_subj);
      return;
    }
/* There is something interesting so the stack should grow */
  if (!xn_is_allocated)
    {
      xn = xp->xp_free_list;
      xp->xp_free_list = xn->xn_parent;
      memset (xn, 0, sizeof (xp_node_t));
      xn->xn_xp = xp;
      xn->xn_parent = xp->xp_current;
      xp->xp_current = xn;
    }
  if (!inner_is_allocated)
    inner = xp_push_rdfa_locals (xp);
#ifdef DEBUG
  if (NULL != xp->xp_boxed_name)
    GPF_T1("Memory leak in xp->xp_boxed_name");
#endif
  inner->xrdfal_xn = xn;
  inner->xrdfal_place_bits = inner_place_bits;
  if (NULL != xpt->xpt_base)
    {
      inner->xrdfal_base = xpt->xpt_base;
      xpt->xpt_base = NULL;
    }
  if (NULL != subj)
    {
      inner->xrdfal_subj = subj;
      if (subj == xpt->xpt_src)
        xpt->xpt_src = NULL;
      else if (subj == xpt->xpt_href)
        {
          if (rel_rev_attrcount)
            xpt->xpt_href = box_copy (xpt->xpt_href);
          else
            xpt->xpt_href = NULL;
        }
    }
  else if ((NULL != outer) && (NULL != outer->xrdfal_obj_res))
    inner->xrdfal_subj = outer->xrdfal_obj_res;
  else if (rel_rev_attrcount || prop_pred_count)
    {
      inner->xrdfal_subj = tf_bnode_iid (xp->xp_tf, NULL);
      parent_obj_should_be_set = 1;
    }
  else
    inner->xrdfal_subj = NULL;
  if (rel_rev_attrcount)
    {
      inner->xrdfal_obj_res = xpt->xpt_href;
      xpt->xpt_href = NULL;
    }
  else if ((!parent_obj_should_be_set) && (NULL == subj))
    inner->xrdfal_obj_res = outer->xrdfal_obj_res;
  inner->xrdfal_datatype = xpt->xpt_dt;
  xpt->xpt_dt = NULL;
  if (NULL != xpt->xpt_lang)
    {
      inner->xrdfal_language = xpt->xpt_lang;
      xpt->xpt_lang = NULL;
    }
  inner->xrdfal_boring_opened_elts = 0;
#ifdef RDFXML_DEBUG
  if (inner->xrdfal_ict_count)
    GPF_T1("xp_" "rdfa_element(): ict buffer is not empty");
#endif
/* Finally we can make triples, starting from incomplete triples at upper levels */
  if ((NULL != inner->xrdfal_subj) && (inner->xrdfal_subj != outer->xrdfal_obj_res))
    {
      caddr_t old_outer_obj = outer->xrdfal_obj_res;
      xp_rdfa_locals_t * ancestor = outer;
      for (;;)
        {
          for (ctr = ancestor->xrdfal_ict_count; ctr--; /* no step */) /* The order is important */
            {
              rdfa_ict_t *ict = ancestor->xrdfal_ict_buffer + ctr;
              if ((RDFA_ICT_PRED_PROPERTY != ict->ict_pred_type) && (NULL == ict->ict_right))
                {
                  rdfa_feed_or_make_ict (xp, ancestor, box_copy (ict->ict_left), box_copy (ict->ict_pred), box_copy (inner->xrdfal_subj), ict->ict_pred_type, NULL, NULL);
                  ict->ict_used_as_template = 1;
                }
            }
          if (parent_obj_should_be_set)
            ancestor->xrdfal_obj_res = inner->xrdfal_subj;
          ancestor = ancestor->xrdfal_parent;
          if (NULL == ancestor)
            break;
          if ((old_outer_obj != ancestor->xrdfal_obj_res) || (outer->xrdfal_subj != ancestor->xrdfal_subj))
            break;
        }
    }
  if ((NULL != inner->xrdfal_subj) && typeof_count)
    {
      for (ctr = typeof_count; ctr--; /* no step */)
        {
          caddr_t type_uri = xpt->xpt_typeofs[ctr];
          xpt->xpt_typeofs[ctr] = NULL;
          rdfa_feed_or_make_ict (xp, inner, box_copy (inner->xrdfal_subj), uname_rdf_ns_uri_type, type_uri, RDFA_ICT_PRED_REL_OR_TYPEOF, NULL, NULL);
        }
    }
  for (ctr = rel_pred_count; ctr--; /* no step */)
    {
      caddr_t p = xpt->xpt_rel_preds[ctr];
      xpt->xpt_rel_preds[ctr] = NULL;
      rdfa_feed_or_make_ict (xp, inner, box_copy (inner->xrdfal_subj), p, box_copy (inner->xrdfal_obj_res), RDFA_ICT_PRED_REL_OR_TYPEOF, NULL, NULL);
    }
  for (ctr = rev_pred_count; ctr--; /* no step */)
    {
      caddr_t p = xpt->xpt_rev_preds[ctr];
      xpt->xpt_rev_preds[ctr] = NULL;
      rdfa_feed_or_make_ict (xp, inner, box_copy (inner->xrdfal_subj), p, box_copy (inner->xrdfal_obj_res), RDFA_ICT_PRED_REV, NULL, NULL);
    }
  for (ctr = prop_pred_count; ctr--; /* no step */)
    {
      caddr_t p = xpt->xpt_prop_preds[ctr];
      caddr_t val = xpt->xpt_obj_content;
      caddr_t dt = inner->xrdfal_datatype;
      caddr_t lang = (((NULL == dt) || ('\0' == dt[0])) ? inner->xrdfal_language : NULL);
      if (NULL != lang)
        lang = (('\0' != lang[0]) ? box_copy (lang) : NULL);
      xpt->xpt_prop_preds[ctr] = NULL;
      if (0 < ctr)
        {
          val = box_copy (val);
          dt = box_copy (dt);
        }
      else
        {
          xpt->xpt_obj_content = NULL;
          inner->xrdfal_datatype = NULL;
        }
      rdfa_feed_or_make_ict (xp, inner, box_copy (inner->xrdfal_subj), p, val, RDFA_ICT_PRED_PROPERTY, dt, lang);
    }
  if (!prop_pred_count)
    {
      dk_free_box (xpt->xpt_obj_content); xpt->xpt_obj_content = NULL;
      dk_free_box (inner->xrdfal_datatype); inner->xrdfal_datatype = NULL;
    }
  if ((NULL == inner->xrdfal_obj_res) && !rel_rev_attrcount)
    inner->xrdfal_obj_res = inner->xrdfal_subj;
}

void
xp_rdfa_element_end (void *userdata, const char * name)
{
  xparse_ctx_t *xp = (xparse_ctx_t*) userdata;
  xp_rdfa_locals_t *inner = xp->xp_rdfa_locals;
  xp_node_t *current_node, *parent_node;
  int inner_place_bits = inner->xrdfal_place_bits;
  int ctr;
  if (NULL == inner->xrdfal_xn)
    return; /* This happens for elements that are closed outside any "interesting" element */
  if (xp->xp_current != inner->xrdfal_xn)
    {
      if (!(RDFA_IN_XMLLITERAL & inner_place_bits))
        GPF_T1 ("xp_" "rdfa_element_end(): misaligned stacks");
      xp_element_end (userdata, name);
      return;
    }
  if (inner->xrdfal_boring_opened_elts)
    {
      inner->xrdfal_boring_opened_elts--;
      return;
    }
  inner_place_bits = inner->xrdfal_place_bits;
  current_node = xp->xp_current;
  if ((RDFA_IN_BASE & inner_place_bits) && !(RDFA_IN_UNUSED & inner_place_bits))
    {
      caddr_t new_base = strses_string (xp->xp_strses);
      strses_flush (xp->xp_strses);
      xp_rdfa_set_base (xp, inner, new_base);
    }
  if (RDFA_IN_LITERAL & inner_place_bits)
    {
      caddr_t obj = NULL;
      int obj_use_count = 0;
      for (ctr = inner->xrdfal_ict_count; ctr--; /* no step */)
        {
          rdfa_ict_t *ict = inner->xrdfal_ict_buffer + ctr;
          if ((RDFA_ICT_PRED_PROPERTY != ict->ict_pred_type) || (NULL != ict->ict_right))
            continue;
          obj_use_count++;
        }
      if (RDFA_IN_XMLLITERAL & inner_place_bits)
        {
          dk_set_t children;
          caddr_t *literal_head;
          caddr_t literal_tree;
          XP_STRSES_FLUSH (xp);
          children = dk_set_nreverse (current_node->xn_children);
          literal_head = (caddr_t *)list (1, uname__root);
          children = CONS (literal_head, children);
          literal_tree = list_to_array (children);
          current_node->xn_children = NULL;
          if (obj_use_count)
            {
              xml_tree_ent_t *literal_xte;
              literal_xte = xte_from_tree (literal_tree, xp->xp_qi);
              obj = (caddr_t) literal_xte;
            }
          else
            dk_free_tree (literal_tree);
        }
      else
        {
          if (obj_use_count)
            obj = strses_string (xp->xp_strses);
          strses_flush (xp->xp_strses);
        }
      for (ctr = inner->xrdfal_ict_count; ctr--; /* no step */)
        {
          rdfa_ict_t *ict = inner->xrdfal_ict_buffer + ctr;
          if ((RDFA_ICT_PRED_PROPERTY != ict->ict_pred_type) || (NULL != ict->ict_right))
            continue;
          if (RDFA_IN_XMLLITERAL & inner_place_bits)
            ict->ict_datatype = uname_rdf_ns_uri_XMLLiteral;
          ict->ict_right = --obj_use_count ? box_copy_tree (obj) : obj;
          rdfa_ict_feed_or_leave (xp, inner, ctr);
        }
#ifdef RDFXML_DEBUG
      if (obj_use_count)
        GPF_T1 ("xp_" "rdfa_element_end(): obj_use_count is out of sync");
#endif
    }
  if (RDFA_IN_HEAD & inner_place_bits)
    {
      xp_rdfa_locals_t *parent = inner->xrdfal_parent;
      int inner_size = sizeof (rdfa_ict_t) * inner->xrdfal_ict_count;
      int parent_size = sizeof (rdfa_ict_t) * parent->xrdfal_ict_count;
      int needed_size = inner_size + parent_size;
      if (NULL == parent->xrdfal_ict_buffer)
        {
          if (inner->xrdfal_ict_count)
            {
              parent->xrdfal_ict_buffer = inner->xrdfal_ict_buffer;
              inner->xrdfal_ict_buffer = NULL;
            }
        }
      else if (box_length (parent->xrdfal_ict_buffer) < needed_size)
        {
          rdfa_ict_t *new_buf = dk_alloc_box_zero (needed_size, DV_ARRAY_OF_POINTER);
          memcpy (new_buf, parent->xrdfal_ict_buffer, parent_size);
          memset (parent->xrdfal_ict_buffer, 0, parent_size);
          memcpy (new_buf + parent->xrdfal_ict_count, inner->xrdfal_ict_buffer, inner_size);
          memset (inner->xrdfal_ict_buffer, 0, inner_size);
          dk_free_tree (parent->xrdfal_ict_buffer);
          parent->xrdfal_ict_buffer = new_buf;
        }
      else
        {
          memcpy (parent->xrdfal_ict_buffer + parent->xrdfal_ict_count, inner->xrdfal_ict_buffer, inner_size);
          memset (inner->xrdfal_ict_buffer, 0, inner_size);
        }
      parent->xrdfal_ict_count += inner->xrdfal_ict_count;
      inner->xrdfal_ict_count = 0;
    }
  else
    {
      for (ctr = inner->xrdfal_ict_count; ctr--; /* no step */)
        {
          rdfa_ict_t *ict = inner->xrdfal_ict_buffer + ctr;
          xp_expand_relative_uri (inner->xrdfal_base, &(ict->ict_left));
          xp_expand_relative_uri (inner->xrdfal_base, &(ict->ict_pred));
          if (RDFA_ICT_PRED_PROPERTY == ict->ict_pred_type)
            {
              if (uname___empty != ict->ict_datatype)
                xp_expand_relative_uri (inner->xrdfal_base, &(ict->ict_datatype));
            }
          else
            xp_expand_relative_uri (inner->xrdfal_base, &(ict->ict_right));
          if (RDFA_ICT_NO_OBJ == rdfa_ict_feed_or_leave (xp, inner, ctr))
            {
              if (!ict->ict_used_as_template)
                xmlparser_logprintf (xp->xp_parser, XCFG_WARNING, 500,
                  (RDFA_ICT_PRED_REV == ict->ict_pred_type) ?
                    "Predicate %.200s with object %.200s has no subject" :
                    "Property %.200s of subject %.200s has no value",
                  (DV_IRI_ID == DV_TYPE_OF (ict->ict_left)) ? "(blank node)" : ict->ict_left,
                  (DV_IRI_ID == DV_TYPE_OF (ict->ict_pred)) ? "(blank node)" : ict->ict_pred );
              dk_free_box (ict->ict_left); ict->ict_left = NULL;
              dk_free_box (ict->ict_pred); ict->ict_pred = NULL;
              ict->ict_pred_type = 0;
              ict->ict_used_as_template = 0;
            }
        }
    }
  parent_node = xp->xp_current->xn_parent;
  dk_free_tree (current_node->xn_attrs);
  xp->xp_current = parent_node;
  current_node->xn_parent = xp->xp_free_list;
  xp->xp_free_list = current_node;
  xp_pop_rdfa_locals (xp);
}

void
xp_rdfa_id (void *userdata, char * name)
{
  xparse_ctx_t *xp = (xparse_ctx_t*) userdata;
  xp_rdfa_locals_t *inner = xp->xp_rdfa_locals;
  if (RDFA_IN_XMLLITERAL & inner->xrdfal_place_bits)
    xp_id (userdata, name);
}

void
xp_rdfa_character (void *userdata,  char * s, int len)
{
  xparse_ctx_t *xp = (xparse_ctx_t*) userdata;
  xp_rdfa_locals_t *inner = xp->xp_rdfa_locals;
  int inner_place_bits = inner->xrdfal_place_bits;
  if (((RDFA_IN_BASE & inner_place_bits) || (RDFA_IN_LITERAL & inner_place_bits)) &&
    !(RDFA_IN_UNUSED & inner_place_bits) )
    session_buffered_write (xp->xp_strses, s, len);
}

void
xp_rdfa_entity (void *userdata, const char * refname, int reflen, int isparam, const xml_def_4_entity_t *edef)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) userdata;
  xp_rdfa_locals_t *inner = xp->xp_rdfa_locals;
  if (RDFA_IN_XMLLITERAL & inner->xrdfal_place_bits)
    xp_entity ((vxml_parser_t *)userdata, refname, reflen, isparam, edef);
  else if (RDFA_IN_STRLITERAL & inner->xrdfal_place_bits)
    xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Entities are not supported in string literal object");
}

void
xp_rdfa_pi (void *userdata, const char *target, const char *data)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) userdata;
  xp_rdfa_locals_t *inner = xp->xp_rdfa_locals;
  if (RDFA_IN_XMLLITERAL & inner->xrdfal_place_bits)
    xp_pi ((vxml_parser_t *)userdata, target, data);
}

void
xp_rdfa_comment (void *userdata, const char *text)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) userdata;
  xp_rdfa_locals_t *inner = xp->xp_rdfa_locals;
  if (RDFA_IN_XMLLITERAL & inner->xrdfal_place_bits)
    xp_comment ((vxml_parser_t *)userdata, text);
}

/* Part 3. Microdata parser */

const char *mdata_attribute_lognames[COUNTOF__MDATA_ATTR] = {
  "meta content",	/* MDATA_ATTR_OBJ_CONTENT_STRLIT	0	*/
  "datetime",		/* MDATA_ATTR_OBJ_DATETIME		1	*/
  "literal content",	/* MDATA_ATTR_OBJ_STRLIT		2	*/
  "cite",		/* MDATA_ATTR_OBJ_CITE			3	*/
  "href/src/data",	/* MDATA_ATTR_OBJ_REF			4	*/
  "name",		/* MDATA_ATTR_OBJ_NAME			5	*/
  "id",			/* MDATA_ATTR_ID			6	*/
  "itemid",		/* MDATA_ATTR_ITEMID			7	*/
  "itemprop",		/* MDATA_ATTR_ITEMPROP			8	*/
  "itemref",		/* MDATA_ATTR_ITEMREF			9	*/
  "itemscope",		/* MDATA_ATTR_ITEMSCOPE			10	*/
  "itemtype",		/* MDATA_ATTR_ITEMTYPE			11	*/
  "rel",		/* MDATA_ATTR_REL			12	*/
  "xml:base",		/* MDATA_ATTR_XML_BASE			13	*/
  "xml:lang" };		/* MDATA_ATTR_XML_LANG			14	*/

int
mdata_find_attr_idx (const char *attrname, const char *elname)
{
  if (!strcmp (attrname, "href"))
    {
      if (!strcmp (elname, "a") || !strcmp (elname, "link") || !strcmp (elname, "area"))
        return MDATA_ATTR_OBJ_REF;
      return -1;
    }
  if (!strcmp (attrname, "src"))
    {
      if (!strcmp (elname, "img") || !strcmp (elname, "iframe") || !strcmp (elname, "audio")
        || !strcmp (elname, "embed") || !strcmp (elname, "source") || !strcmp (elname, "track") || !strcmp (elname, "video"))
        return MDATA_ATTR_OBJ_REF;
      return -1;
    }
  if (!strcmp (attrname, "data"))
    {
      if (!strcmp (elname, "object"))
        return MDATA_ATTR_OBJ_REF;
      return -1;
    }
  if (!strcmp (attrname, "content"))
    {
      if (!strcmp (elname, "meta"))
        return MDATA_ATTR_OBJ_CONTENT_STRLIT;
      return -2;
    }
  if (!strcmp (attrname, "cite"))
    {
      if (!strcmp (elname, "blockquote") || !strcmp (elname, "q"))
        return MDATA_ATTR_OBJ_CITE_REF;
      return -2;
    }
  if (!strcmp (attrname, "name"))
    {
      if (!strcmp (elname, "meta"))
        return MDATA_ATTR_OBJ_NAME;
      return -2;
    }
  if (!strcmp (attrname, "id"))
    return MDATA_ATTR_ID;
  if (!strcmp (attrname, "rel"))
    {
      if (!strcmp (elname, "a") || !strcmp (elname, "link") || !strcmp (elname, "area"))
        return MDATA_ATTR_REL;
      return -1;
    }
  if (!strncmp (attrname, "xml:", 4))
    {
      if (!strcmp (attrname, "xml:base"))
        return MDATA_ATTR_XML_BASE;
      if (!strcmp (attrname, "xml:lang"))
        return MDATA_ATTR_XML_LANG;
      return -3;
    }
  if (!strncmp (attrname, "item", 4))
    {
      if (!strcmp (attrname, "itemid"))
        return MDATA_ATTR_ITEMID;
      if (!strcmp (attrname, "itemprop"))
        return MDATA_ATTR_ITEMPROP;
      if (!strcmp (attrname, "itemref"))
        return MDATA_ATTR_ITEMREF;
      if (!strcmp (attrname, "itemscope"))
        return MDATA_ATTR_ITEMSCOPE;
      if (!strcmp (attrname, "itemtype"))
        return MDATA_ATTR_ITEMTYPE;
      return -4;
    }
  if (!strcmp (attrname, "datetime"))
    {
      if (!strcmp (elname, "time"))
        return MDATA_ATTR_OBJ_DATETIME;
      return -5;
    }
  return -6;
}


#define MDATA_ATTRSYNTAX_URI		0x01
#define MDATA_ATTRSYNTAX_REL		0x02
#define MDATA_ATTRSYNTAX_ID		0x04
#define MDATA_ATTRSYNTAX_WS_LIST	0x08
#define MDATA_ATTRSYNTAX_OPTIONAL	0x10
#define MDATA_ATTRSYNTAX_SILENT		0x20

caddr_t
xp_mdata_parse_attr_value (xparse_ctx_t *xp, xp_node_t * xn, int attr_id, char **attrvalues, int allowed_syntax, caddr_t **values_ret, int *values_count_ret)
{
  char *attrvalue = attrvalues[attr_id];
  char *tail = attrvalue;
  char *token_start, *token_end;
  int token_syntax;
  caddr_t expanded_token = NULL;
  int values_count, expanded_token_not_saved = 0;
#define free_unsaved_token() do { \
  if (expanded_token_not_saved) { \
      dk_free_box (expanded_token); \
      expanded_token = NULL; \
      expanded_token_not_saved = 0; } \
  } while (0)
#ifdef RDFXML_DEBUG
  if (((NULL != values_ret) ? 1 : 0) != ((NULL != values_count_ret) ? 1 : 0))
    GPF_T1 ("xp_" "mdata_parse_attr_value(): bad call (1)");
  if (((NULL != values_ret) ? 1 : 0) != ((MDATA_ATTRSYNTAX_WS_LIST & allowed_syntax) ? 1 : 0))
    GPF_T1 ("xp_" "mdata_parse_attr_value(): bad call (2)");
#endif
  if (NULL != values_ret)
    {
      if (NULL == values_ret[0])
        values_ret[0] = dk_alloc_list_zero (1);
      values_count = values_count_ret[0];
    }
  else
    values_count = 0;
  if (NULL == attrvalue)
    {
      if (!(MDATA_ATTRSYNTAX_OPTIONAL & allowed_syntax))
        {
          free_unsaved_token();
          if (MDATA_ATTRSYNTAX_SILENT & allowed_syntax)
            return NULL;
          xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "Missing attribute %.20s", mdata_attribute_lognames[attr_id]);
        }
      return NULL;
    }

next_token:
  if ((MDATA_ATTRSYNTAX_WS_LIST | MDATA_ATTRSYNTAX_ID) & allowed_syntax)
    while (('\0' != tail[0]) && isspace (tail[0])) tail++;
  else if (isspace (tail[0]))
    {
      free_unsaved_token();
      if (MDATA_ATTRSYNTAX_SILENT & allowed_syntax)
        return NULL;
      xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "Whitespaces are not allowed for attribute %.20s", mdata_attribute_lognames[attr_id]);
      return NULL;
    }
  if ('\0' == tail[0])
    {
      if (0 == values_count)
        {
          if (MDATA_ATTRSYNTAX_WS_LIST & allowed_syntax)
            return NULL;
          if (MDATA_ATTRSYNTAX_SILENT & allowed_syntax)
            return NULL;
          xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "Empty value is not allowed for attribute %.20s", mdata_attribute_lognames[attr_id]);
        }
      if (NULL != values_count_ret)
        values_count_ret[0] = values_count;
      return expanded_token;
    }
  if ((1 == values_count) && !(MDATA_ATTRSYNTAX_WS_LIST & allowed_syntax))
    {
      free_unsaved_token();
      if (MDATA_ATTRSYNTAX_SILENT & allowed_syntax)
        return NULL;
      xmlparser_logprintf (xp->xp_parser, XCFG_ERROR, 100, "Multiple values are not allowed for attribute %.20s", mdata_attribute_lognames[attr_id]);
      if (NULL != values_count_ret)
        values_count_ret[0] = values_count;
      return NULL;
    }
  token_syntax = allowed_syntax & (MDATA_ATTRSYNTAX_URI | MDATA_ATTRSYNTAX_ID);
  token_start = tail;
  while (('\0' != tail[0]) && !isspace(tail[0]))
    tail++;
  token_end = tail;
  if (NULL != values_ret)
    {
      if (values_count == BOX_ELEMENTS (values_ret[0]))
        {
          caddr_t *new_buf = dk_alloc_list_zero (values_count * 2);
          memcpy (new_buf, values_ret[0], box_length (values_ret[0]));
          dk_free_box ((caddr_t)(values_ret[0]));
          values_ret[0] = (caddr_t *)new_buf;
        }
      else if (NULL != values_ret[0][values_count]) /* There's some old garbage to delete */
        {
#ifdef RDFXML_DEBUG
          GPF_T1 ("xp_" "mdata_parse_attr_value(): garbage?");
#endif
          dk_free_tree (values_ret[0][values_count]);
          values_ret[0][values_count] = NULL;
        }
    }
  expanded_token = box_dv_short_nchars (token_start, token_end-token_start);
  if (MDATA_ATTRSYNTAX_REL & token_syntax)
    {
      if (NULL != values_ret)
        {
          const char *alt_ssheet_compl_name = NULL;
          if (!strcasecmp (expanded_token, "alternate"))
            alt_ssheet_compl_name = "http://www.w3.org/1999/xhtml/vocab#stylesheet";
          else if (!strcasecmp (expanded_token, "stylesheet"))
            alt_ssheet_compl_name = "http://www.w3.org/1999/xhtml/vocab#alternate";
          if (NULL != alt_ssheet_compl_name)
            {
              int prev_ctr = values_count;
              while (0 < prev_ctr--)
                {
                  if (strcmp (values_ret[0][prev_ctr], alt_ssheet_compl_name))
                    continue;
                  dk_free_box (values_ret[0][prev_ctr]);
                  dk_free_box (expanded_token);
                  values_ret[0][prev_ctr] = box_dv_short_string ("http://www.w3.org/1999/xhtml/vocab#ALTERNATE-STYLESHEET");
                  goto token_done; /* see below */
                }
            }
        }
      if (NULL == strchr (expanded_token, ':'))
        {
          caddr_t vocab_token;
          char *ttail;
          for (ttail = expanded_token; ('\0' != ttail[0]) && !(ttail[0] & ~0x7f); ttail++) ttail[0] = tolower (ttail[0]);
          vocab_token = box_dv_short_strconcat ("http://www.w3.org/1999/xhtml/vocab#", expanded_token);
          dk_free_box (expanded_token);
          expanded_token = vocab_token;
          goto token_done; /* see below */
        }
    }
  if (MDATA_ATTRSYNTAX_URI & token_syntax)
    {
      caddr_t base = xn->xn_xp->xp_mdata_locals->xmdatal_base;
      xp_expand_relative_uri (base, &expanded_token);
      if (NULL == expanded_token)
        {
          if (MDATA_ATTRSYNTAX_SILENT & allowed_syntax)
            return NULL;
          xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Bad URI token in the value of attribute \"%.20s\"", mdata_attribute_lognames[attr_id]);
        }
    }
token_done:
  expanded_token_not_saved = 1;
  if (NULL != values_ret)
    {
      values_ret[0][values_count] = expanded_token;
      expanded_token_not_saved = 0;
    }
  values_count++;
  goto next_token; /* see above */
}

typedef struct mdata_id_desc_s {
  ptrlong iddesc_found;
  ptrlong iddesc_refcount;
  caddr_t *iddesc_refs;
}
mdata_id_desc_t;

void
mdata_register_id_elt (xparse_ctx_t *xp, ccaddr_t id)
{
  id_hash_t *ht = xp->xp_tmp->xpt_id2desc;
  mdata_id_desc_t **desc;
  mdata_id_desc_t *new_desc;
  desc = (mdata_id_desc_t **)id_hash_get (ht, (caddr_t)(&id));
  if (NULL != desc)
    {
      if (desc[0]->iddesc_found)
        xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Id %.200s is not unique", id);
      desc[0]->iddesc_found = 1;
      return;
    }
  id = box_copy (id);
  new_desc = (mdata_id_desc_t *)list (3, (ptrlong)1, (ptrlong)0, dk_alloc_list_zero (2));
  id_hash_set (ht, (caddr_t)(&id), (caddr_t)(&new_desc));
}

void
mdata_register_id_usage (xparse_ctx_t *xp, ccaddr_t id, caddr_t itemid)
{
  id_hash_t *ht = xp->xp_tmp->xpt_id2desc;
  mdata_id_desc_t **desc;
  mdata_id_desc_t *new_desc;
  desc = (mdata_id_desc_t **)id_hash_get (ht, (caddr_t)(&id));
  if (NULL != desc)
    {
      int refs_room = BOX_ELEMENTS (desc[0]->iddesc_refs);
      if (desc[0]->iddesc_refcount >= refs_room)
        {
          caddr_t *new_refs = dk_alloc_list_zero (refs_room * 2);
          memcpy (new_refs, desc[0]->iddesc_refs, refs_room * sizeof (caddr_t));
          dk_free_box ((caddr_t)(desc[0]->iddesc_refs));
          desc[0]->iddesc_refs = new_refs;
        }
      desc[0]->iddesc_refs [desc[0]->iddesc_refcount++] = box_copy_tree (itemid);
      return;
    }
  new_desc = (mdata_id_desc_t *)list (3, (ptrlong)0, (ptrlong)1, (caddr_t *)dk_alloc_list_zero (2));
  new_desc->iddesc_refs[0] = box_copy_tree (itemid);
  id = box_copy (id);
  id_hash_set (ht, (caddr_t)(&id), (caddr_t)(&new_desc));
}

void
mdata_feed_or_keep (xparse_ctx_t *xp, xp_mdata_locals_t *subj_l, caddr_t prop, xp_mdata_locals_t *inner, caddr_t obj, int obj_type)
{
  int obj_is_iri = ((MDATA_ATTR_ITEMID == obj_type) || (MDATA_ATTR_ID == obj_type) || (MDATA_ATTR_OBJ_REF == obj_type) || (MDATA_ATTR_OBJ_REF == obj_type));
  caddr_t obj_datatype = NULL;
  caddr_t obj_lang = (obj_is_iri ? NULL : inner->xmdatal_language);
  switch (obj_type)
    {
    case MDATA_ATTR_OBJ_DATETIME:
      {
        dtp_t dt_dtp = 0;
        caddr_t dt_obj;
        caddr_t dt_err = NULL;
        char month[4], weekday[10], tzstring[10];
        unsigned day, year, mnth, hour, minute, second;
        if (6 == sscanf (obj, "%4u-%2u-%2uT%2u:%2u:%2u",
          &year, &mnth, &day, &hour, &minute, &second) )
          dt_dtp = DV_DATETIME;
        else if (6 == sscanf (obj, "%4u-%2u-%2u %2u:%2u:%2u",
          &year, &mnth, &day, &hour, &minute, &second) )
          dt_dtp = DV_DATETIME;
        else if (8 == sscanf (obj, "%9s, %2u-%3s-%2u %2u:%2u:%u %9s",
          weekday, &day, month, &year, &hour, &minute, &second, tzstring) )
          dt_dtp = DV_DATETIME;
        else if (3 == sscanf (obj, "%4u-%2u-%2u",
          &year, &mnth, &day) )
          dt_dtp = DV_DATE;
        else if (3 == sscanf (obj, "%2u-%3s-%2u",
          &day, month, &year) )
          dt_dtp = DV_DATE;
        else if (3 == sscanf (obj, "%2u:%2u:%2u",
          &hour, &minute, &second) )
          dt_dtp = DV_TIME;
        if (0 != dt_dtp)
          {
            dt_obj = box_cast_to ((caddr_t *)(xp->xp_qi), obj, DV_STRING, dt_dtp, 0, 0, &dt_err);
            if (((dt_dtp == DV_TYPE_OF (dt_obj)) || (DV_DATETIME == DV_TYPE_OF (dt_obj))) && (NULL == dt_err))
              {
                dk_free_box (obj);
                obj = dt_obj;
                obj_datatype = NULL;
                obj_lang = NULL;
              }
            else
              dk_free_box (dt_obj);
          }
        break;
      }
    case MDATA_ATTR_OBJ_REF:
      {
        caddr_t base = xp->xp_mdata_locals->xmdatal_base;
        xp_expand_relative_uri (base, &obj);
        if (NULL == obj)
          {
            dk_free_box (prop);
            return;
          }
        break;
      }
      default: ;
    }

  if (subj_l->xmdatal_subj_is_id || (MDATA_ATTR_ID == obj_type))
    {
      ptrlong new_cvt_bits = MDATA_DANGLING_TRIPLE_CVT_BITS (subj_l->xmdatal_subj_is_id, ((MDATA_ATTR_ID == obj_type) ? 1 : 0));
      caddr_t *triple = (caddr_t *)list (6, box_copy (subj_l->xmdatal_subj), prop, obj,
        (ptrlong)(obj_is_iri ? 1 : 0),
        ((NULL != obj_datatype) ? NULL : box_copy_tree (obj_datatype)),
        ((NULL != obj_lang) ? NULL : box_copy_tree (obj_lang)) );
      ptrlong *cvt_bits_ptr = (ptrlong *)id_hash_get (xp->xp_tmp->xpt_dangling_triples, (caddr_t)(&triple));
      if (NULL == cvt_bits_ptr)
        {
          id_hash_set (xp->xp_tmp->xpt_dangling_triples, (caddr_t)(&triple), (caddr_t)(&new_cvt_bits));
        }
      else
        {
          cvt_bits_ptr[0] |= new_cvt_bits;
          dk_free_tree ((caddr_t)triple);
        }
    }
  else if (NULL != subj_l->xmdatal_subj)
    {
      if (obj_is_iri)
        tf_triple (xp->xp_tf, subj_l->xmdatal_subj, prop, obj);
      else
        tf_triple_l (xp->xp_tf, subj_l->xmdatal_subj, prop, obj, obj_datatype, obj_lang);
      dk_free_box (prop);
      dk_free_box (obj);
    }
  else
    {
      dk_free_box (prop);
      dk_free_box (obj);
    }
}

void
mdata_feed_single_pending (xparse_ctx_t *xp, caddr_t *triple, int s_is_id, int o_is_id)
{
  caddr_t patched_triple[6];
  patched_triple[0] = triple[0];
  patched_triple[1] = triple[1];
  patched_triple[2] = triple[2];
  patched_triple[3] = triple[3];
  patched_triple[4] = triple[4];
  patched_triple[5] = triple[5];
  if (s_is_id)
    {
      caddr_t subj = triple[0];
      int ctr;
      mdata_id_desc_t **id_desc_ptr = (mdata_id_desc_t **)id_hash_get (xp->xp_tmp->xpt_id2desc, (caddr_t)(&subj));
      if (NULL == id_desc_ptr)
        GPF_T1("unknown id as subj");
      for (ctr = id_desc_ptr[0]->iddesc_refcount; ctr--; /* no step */)
        {
          patched_triple[0] = id_desc_ptr[0]->iddesc_refs[ctr];
          mdata_feed_single_pending (xp, patched_triple, 0, o_is_id);
        }
    }
  else if (o_is_id)
    {
      caddr_t obj = triple[2];
      int ctr;
      mdata_id_desc_t **id_desc_ptr = (mdata_id_desc_t **)id_hash_get (xp->xp_tmp->xpt_id2desc, (caddr_t)(&obj));
      if (NULL == id_desc_ptr)
        GPF_T1("unknown id as obj");
      for (ctr = id_desc_ptr[0]->iddesc_refcount; ctr--; /* no step */)
        {
          patched_triple[2] = id_desc_ptr[0]->iddesc_refs[ctr];
          mdata_feed_single_pending (xp, patched_triple, s_is_id, 0);
        }
    }
  else
    {
      if (triple[3])
        tf_triple (xp->xp_tf, triple[0], triple[1], triple[2]);
      else
        tf_triple_l (xp->xp_tf, triple[0], triple[1], triple[2], triple[4], triple[5]); /* index 3 is skipped intentionally ;) */
    }
}

void
mdata_process_pending_triples (xparse_ctx_t *xp)
{
  id_hash_iterator_t hit;
  mdata_id_desc_t **id_desc_ptr;
  caddr_t *id_ptr, **triple_ptr;
  ptrlong *flags_ptr;
  id_hash_iterator (&hit, xp->xp_tmp->xpt_id2desc);
  while (hit_next (&hit, (char **)&id_ptr, (char **)&id_desc_ptr))
    {
      if (!(id_desc_ptr[0]->iddesc_found))
        xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Id '%.200s' is mentioned in an itemref attribute of some itemscope but not found in the whole XHTML/Microdata resource", id_ptr[0]);
    }
  id_hash_iterator (&hit, xp->xp_tmp->xpt_dangling_triples);
  while (hit_next (&hit, (char **)&triple_ptr, (char **)&flags_ptr))
    {
      if (flags_ptr[0] & MDATA_DANGLING_TRIPLE_CVT_BITS (0, 0))
        mdata_feed_single_pending (xp, triple_ptr[0], 0, 0);
      if (flags_ptr[0] & MDATA_DANGLING_TRIPLE_CVT_BITS (0, 1))
        mdata_feed_single_pending (xp, triple_ptr[0], 0, 1);
      if (flags_ptr[0] & MDATA_DANGLING_TRIPLE_CVT_BITS (1, 0))
        mdata_feed_single_pending (xp, triple_ptr[0], 1, 0);
      if (flags_ptr[0] & MDATA_DANGLING_TRIPLE_CVT_BITS (1, 1))
        mdata_feed_single_pending (xp, triple_ptr[0], 1, 1);
    }
}

xp_mdata_locals_t *
xp_push_mdata_locals (xparse_ctx_t *xp)
{
  xp_mdata_locals_t *outer = xp->xp_mdata_locals;
  xp_mdata_locals_t *inner = xp->xp_mdata_free_list;
  if (NULL == inner)
    inner = dk_alloc (sizeof (xp_mdata_locals_t));
  else
    xp->xp_mdata_free_list = xp->xp_mdata_free_list->xmdatal_parent;
  memset (inner, 0, sizeof (xp_mdata_locals_t));
  if (NULL != outer)
    {
      inner->xmdatal_subj = outer->xmdatal_subj;
      inner->xmdatal_subj_is_id = outer->xmdatal_subj_is_id;
      inner->xmdatal_prop_count = outer->xmdatal_prop_count;
      inner->xmdatal_props = outer->xmdatal_props;
      inner->xmdatal_datatype = outer->xmdatal_datatype;
      inner->xmdatal_base = outer->xmdatal_base;
      inner->xmdatal_language = outer->xmdatal_language;
    }
  inner->xmdatal_parent = outer;
  xp->xp_mdata_locals = inner;
  return inner;
}

void
xp_pop_mdata_locals (xparse_ctx_t *xp)
{
  xp_mdata_locals_t *inner = xp->xp_mdata_locals;
  xp_mdata_locals_t *outer = inner->xmdatal_parent;
#define XP_FREE_INNER_IF_NEQ_OUTER(fld) do { \
  if ((NULL != inner->fld) && ((NULL == outer) || (outer->fld != inner->fld))) \
    dk_free_tree ((caddr_t)(inner->fld)); } while (0)
  XP_FREE_INNER_IF_NEQ_OUTER (xmdatal_subj);
  XP_FREE_INNER_IF_NEQ_OUTER (xmdatal_props);
  XP_FREE_INNER_IF_NEQ_OUTER (xmdatal_datatype);
  XP_FREE_INNER_IF_NEQ_OUTER (xmdatal_base);
  XP_FREE_INNER_IF_NEQ_OUTER (xmdatal_language);
  inner->xmdatal_parent = xp->xp_mdata_free_list;
  xp->xp_mdata_free_list = inner;
  xp->xp_mdata_locals = outer;
}

void
xp_mdata_element (void *userdata, char * name, vxml_parser_attrdata_t *attrdata)
{
  xparse_ctx_t *xp = (xparse_ctx_t*) userdata;
  xp_mdata_locals_t *outer = xp->xp_mdata_locals;
  xp_mdata_locals_t *inner = NULL; /* This is not allocated at all if there's nothing "interesting" in the tag */
  xp_tmp_t *xpt = xp->xp_tmp;
  xp_node_t *xn = xp->xp_current;
  caddr_t avalues[COUNTOF__MDATA_ATTR];
  int inx, fill, n_attrs, n_ns, xn_is_allocated = 0;
  char *local_name;
  int obj_attr_idx = -1;
  int outer_place_bits = outer->xmdatal_place_bits;
  int need_mdata_local = 0;
  int props_connect_local_id_to_local_itemscope = 0;
#ifdef RDFXML_DEBUG
  if (xpt->xpt_base || xpt->xpt_dt || xpt->xpt_lang || xpt->xpt_obj_content || xpt->xpt_obj_res || xpt->xpt_src || xpt->xpt_href)
    GPF_T1("xp_" "mdata_element(): nonempty xpt");
#endif
#ifdef RECOVER_RDF_VALUE
  caddr_t rdf_val = NULL;
#endif
  if ((MDATA_IN_UNUSED | MDATA_IN_STRLITERAL) & outer_place_bits)
    {
      outer->xmdatal_boring_opened_elts++;
      return;
    }
  if ((MDATA_IN_XMLLITERAL) & outer_place_bits)
    {
      xp_element (userdata, name, attrdata);
      return;
    }
/* Let's make xp->xp_free_list nonempty just to not duplicate this code in few places below */
  if (NULL == xp->xp_free_list)
    {
      xp->xp_free_list = (xp_node_t *)dk_alloc (sizeof (xp_node_t));
      xp->xp_free_list->xn_parent = NULL;
    }
  n_ns = attrdata->local_nsdecls_count;
  if (n_ns)
    {
      caddr_t *save_ns;
      xn = xp->xp_free_list;
      xp->xp_free_list = xn->xn_parent;
      memset (xn, 0, sizeof (xp_node_t));
      xn->xn_xp = xp;
      xn->xn_parent = xp->xp_current;
      xp->xp_current = xn;
      xn_is_allocated = 1;
      need_mdata_local++;
      save_ns = (caddr_t*) dk_alloc_box (2 * n_ns * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      /* Trick here: xn->xn_attrs is set to xn->xn_namespaces in order to free memory on errors or element end. */
      xn->xn_attrs = xn->xn_namespaces = save_ns;
      fill = 0;
      for (inx = 0; inx < n_ns; inx++)
        {
          save_ns[fill++] = box_dv_uname_string (attrdata->local_nsdecls[inx].nsd_prefix);
          save_ns[fill++] = box_dv_uname_string (attrdata->local_nsdecls[inx].nsd_uri);
        }
    }
/* Setting place bits */
  local_name = strchr (name, ':');
  if (NULL == local_name)
    local_name = name;
  n_attrs = attrdata->local_attrs_count;
  memset (avalues, 0, sizeof (avalues));
  if (0 == n_attrs)
    goto all_attributes_are_retrieved; /* see below */
  for (inx = 0; inx < n_attrs; inx ++)
    {
      char *raw_aname = attrdata->local_attrs[inx].ta_raw_name.lm_memblock;
      int mdata_attr_idx = mdata_find_attr_idx (raw_aname, name);
      if (0 > mdata_attr_idx)
        continue;
      need_mdata_local++;
      if (NULL != avalues[mdata_attr_idx])
        xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Duplicate/conflicting attribute names in one element head");
      avalues[mdata_attr_idx] = attrdata->local_attrs[inx].ta_value;
    }
  if (!need_mdata_local)
    {
      goto all_attributes_are_retrieved; /* see below */
    }
  if (NULL != avalues[MDATA_ATTR_ITEMPROP])
    {
      if (NULL != avalues[MDATA_ATTR_OBJ_REF])
        obj_attr_idx = MDATA_ATTR_OBJ_REF;
      else if (NULL != avalues[MDATA_ATTR_OBJ_STRLIT])
        obj_attr_idx = MDATA_ATTR_OBJ_STRLIT;
      else if (NULL != avalues[MDATA_ATTR_OBJ_CONTENT_STRLIT])
        obj_attr_idx = MDATA_ATTR_OBJ_CONTENT_STRLIT;
      else if (NULL != avalues[MDATA_ATTR_OBJ_DATETIME])
        obj_attr_idx = MDATA_ATTR_OBJ_DATETIME;
    }
  if ((2 == need_mdata_local) && (NULL != outer->xmdatal_subj) && (0 <= obj_attr_idx))
    {

      int prop_ctr, prop_count = 0;
      caddr_t *props = NULL;
      xp_mdata_parse_attr_value (xp, xn, MDATA_ATTR_ITEMPROP, avalues,
            MDATA_ATTRSYNTAX_ID | MDATA_ATTRSYNTAX_WS_LIST, &props, &prop_count );
      for (prop_ctr = 0; prop_ctr < prop_count; prop_ctr++)
        {
          caddr_t prop = props[prop_ctr];
          props[prop_ctr] = NULL;
          mdata_feed_or_keep (xp, outer, prop, outer /* yes, not inner */, box_dv_short_string (avalues[obj_attr_idx]), obj_attr_idx );
        }
      dk_free_box ((caddr_t)props);
      outer->xmdatal_boring_opened_elts++; /* This is to disable processing of closing tag because it can not be interesting and it should do nothing. */
      return;
    }
  if (!xn_is_allocated)
    {
      xn = xp->xp_free_list;
      xp->xp_free_list = xn->xn_parent;
      memset (xn, 0, sizeof (xp_node_t));
      xn->xn_xp = xp;
      xn->xn_parent = xp->xp_current;
      xp->xp_current = xn;
      xn_is_allocated = 1;
    }
  inner = xp_push_mdata_locals (xp);
  inner->xmdatal_xn = xn;
  if (NULL != avalues[MDATA_ATTR_XML_BASE])
    {
      if (NULL != xpt->xpt_base)
        dk_free_tree (xpt->xpt_base);
      xpt->xpt_base = box_dv_short_string (avalues[MDATA_ATTR_XML_BASE]);
    }
  if (NULL != avalues[MDATA_ATTR_XML_LANG])
    {
      if (NULL != xpt->xpt_lang)
        dk_free_tree (xpt->xpt_lang);
      xpt->xpt_lang = box_dv_short_string (avalues[MDATA_ATTR_XML_LANG]);
    }
  if (NULL != xpt->xpt_base)
    {
      inner->xmdatal_base = xpt->xpt_base;
      xpt->xpt_base = NULL;
    }
  if (NULL != xpt->xpt_lang)
    {
      inner->xmdatal_language = xpt->xpt_lang;
      xpt->xpt_lang = NULL;
    }
  if ((NULL != avalues[MDATA_ATTR_ID]) && ((NULL == avalues[MDATA_ATTR_ITEMSCOPE]) || (NULL != avalues[MDATA_ATTR_ITEMPROP])))
    {
      caddr_t id = xp_mdata_parse_attr_value (xp, xn, MDATA_ATTR_ID, avalues, MDATA_ATTRSYNTAX_ID, NULL, NULL);
      mdata_register_id_elt (xp, id);
      inner->xmdatal_subj = id;
      inner->xmdatal_subj_is_id = 1;
      inner->xmdatal_props = NULL;
      inner->xmdatal_prop_count = 0;
    }
  if (NULL != avalues[MDATA_ATTR_ITEMSCOPE])
    {
      caddr_t itemid = xp_mdata_parse_attr_value (xp, xn, MDATA_ATTR_ITEMID, avalues,
            MDATA_ATTRSYNTAX_URI | MDATA_ATTRSYNTAX_OPTIONAL, NULL, NULL );
      if (NULL == itemid)
        itemid = tf_bnode_iid (xp->xp_tf, NULL);
      if ((NULL != avalues[MDATA_ATTR_ID]) && (NULL != avalues[MDATA_ATTR_ITEMPROP]))
        {
          int prop_ctr, prop_count = 0;
          caddr_t *props = NULL;
          xp_mdata_parse_attr_value (xp, xn, MDATA_ATTR_ITEMPROP, avalues,
                MDATA_ATTRSYNTAX_ID | MDATA_ATTRSYNTAX_WS_LIST, &props, &prop_count );
          inner->xmdatal_props = props;
          inner->xmdatal_prop_count = prop_count;
          for (prop_ctr = 0; prop_ctr < prop_count; prop_ctr++)
            {
              caddr_t prop = props[prop_ctr];
              props[prop_ctr] = NULL;
              mdata_feed_or_keep (xp, inner, prop, inner, box_copy (itemid), MDATA_ATTR_ITEMID);
            }
          dk_free_box (inner->xmdatal_subj);
          inner->xmdatal_subj = NULL;
          dk_free_box ((caddr_t)(inner->xmdatal_props));
          inner->xmdatal_props = NULL;
          inner->xmdatal_prop_count = 0;
          props_connect_local_id_to_local_itemscope = 1;
        }
      if (!(props_connect_local_id_to_local_itemscope || outer->xmdatal_prop_count) && (NULL != xp->xp_tf->tf_base_uri))
        tf_triple (xp->xp_tf, xp->xp_tf->tf_base_uri, box_dv_uname_string ("http://www.w3.org/1999/xhtml/microdata#item"), itemid);
      inner->xmdatal_subj = itemid;
      inner->xmdatal_subj_is_id = 0;
      inner->xmdatal_props = NULL;
      inner->xmdatal_prop_count = 0;
      if (NULL != avalues[MDATA_ATTR_ITEMREF])
        {
          caddr_t *ref_ids = 0;
          int ref_id_ctr, ref_id_count = 0;
          xp_mdata_parse_attr_value (xp, xn, MDATA_ATTR_ITEMREF, avalues,
            MDATA_ATTRSYNTAX_ID | MDATA_ATTRSYNTAX_WS_LIST, &ref_ids, &ref_id_count );
          for (ref_id_ctr = 0; ref_id_ctr < ref_id_count; ref_id_ctr++)
            mdata_register_id_usage (xp, ref_ids[ref_id_ctr], inner->xmdatal_subj);
          dk_free_tree ((caddr_t)ref_ids);
        }
    }
  else if (NULL != avalues[MDATA_ATTR_ITEMREF])
    xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Attribute itemref in an opening tag that has no itemscope attribute");
  if (outer->xmdatal_prop_count && (NULL != outer->xmdatal_subj) && (NULL != inner->xmdatal_subj) && ((NULL != avalues[MDATA_ATTR_ITEMSCOPE]) || (NULL != avalues[MDATA_ATTR_ID])))
    {
      int prop_ctr;
      for (prop_ctr = 0; prop_ctr < outer->xmdatal_prop_count; prop_ctr++)
        {
          caddr_t prop = outer->xmdatal_props[prop_ctr];
          mdata_feed_or_keep (xp, outer, box_copy (prop), inner,
            box_dv_short_string (inner->xmdatal_subj), ((NULL != avalues[MDATA_ATTR_ITEMSCOPE]) ? MDATA_ATTR_ITEMSCOPE : MDATA_ATTR_ID) );
        }
    }
  if (NULL != avalues[MDATA_ATTR_ITEMTYPE])
    {
      caddr_t itemtype, itemid;
      caddr_t *old_itemtype_ptr;
      if (NULL == avalues[MDATA_ATTR_ITEMSCOPE])
        xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Attribute itemtype without attribute itemscope");
      itemtype = xp_mdata_parse_attr_value (xp, xn, MDATA_ATTR_ITEMTYPE, avalues,
            MDATA_ATTRSYNTAX_URI, NULL, NULL );
      itemid = inner->xmdatal_subj;
      old_itemtype_ptr = (caddr_t *)id_hash_get (xpt->xpt_subj2type, (caddr_t)(&itemid));
      if (NULL != old_itemtype_ptr)
        {
          dk_free_tree (itemtype);
          xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "The subject '%.200s' has more than one itemtype definition", inner->xmdatal_subj);
        }
      else
        {
          mdata_feed_or_keep (xp, inner, uname_rdf_ns_uri_type, inner, box_copy (itemtype), MDATA_ATTR_ITEMSCOPE);
          itemid = box_copy (itemid);
          id_hash_set (xpt->xpt_subj2type, (caddr_t)(&itemid), (caddr_t)(&itemtype));
        }
    }
  if ((NULL != avalues[MDATA_ATTR_ITEMPROP]) && !props_connect_local_id_to_local_itemscope)
    {
      int prop_ctr, prop_count = 0;
      caddr_t *props = NULL;
      if (NULL == inner->xmdatal_subj)
        xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Attribute itemprop outside any element with itemscope or id");
      xp_mdata_parse_attr_value (xp, xn, MDATA_ATTR_ITEMPROP, avalues,
            MDATA_ATTRSYNTAX_ID | MDATA_ATTRSYNTAX_WS_LIST, &props, &prop_count );
      inner->xmdatal_props = props;
      inner->xmdatal_prop_count = prop_count;
      if ((NULL != outer->xmdatal_subj) && (0 <= obj_attr_idx))
        {
          if (inner->xmdatal_subj != outer->xmdatal_subj)
            xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "An opening tag with itemscope or id can not contain both attribute itemprop and some object attribute");
          for (prop_ctr = 0; prop_ctr < prop_count; prop_ctr++)
            {
              caddr_t prop = props[prop_ctr];
              props[prop_ctr] = NULL;
              mdata_feed_or_keep (xp, outer, prop, inner, box_dv_short_string (avalues[obj_attr_idx]), obj_attr_idx );
            }
          inner->xmdatal_prop_count = 0;
        }
      else if ((NULL != outer->xmdatal_subj) && (inner->xmdatal_subj != outer->xmdatal_subj))
        {
          for (prop_ctr = 0; prop_ctr < prop_count; prop_ctr++)
            {
              caddr_t prop = props[prop_ctr];
              props[prop_ctr] = NULL;
              mdata_feed_or_keep (xp, outer, prop, inner, box_copy_tree (inner->xmdatal_subj),
                (inner->xmdatal_subj_is_id ? MDATA_ATTR_ID : MDATA_ATTR_ITEMID) );
            }
          inner->xmdatal_prop_count = 0;
        }
      else
        {
          inner->xmdatal_place_bits |= MDATA_IN_STRLITERAL;
        }
    }
  if ((NULL != avalues[MDATA_ATTR_REL]) && (NULL != avalues[MDATA_ATTR_OBJ_REF]))
    {
      int rel_ctr, rel_count = 0;
      caddr_t *rels = NULL;
      caddr_t ref;
      xp_mdata_parse_attr_value (xp, xn, MDATA_ATTR_REL, avalues,
            MDATA_ATTRSYNTAX_REL | MDATA_ATTRSYNTAX_URI | MDATA_ATTRSYNTAX_WS_LIST, &rels, &rel_count );
      ref = xp_mdata_parse_attr_value (xp, xn, MDATA_ATTR_OBJ_REF, avalues,
            MDATA_ATTRSYNTAX_URI | MDATA_ATTRSYNTAX_OPTIONAL, NULL, NULL );
      if ((NULL != ref) && (NULL != xp->xp_tf->tf_base_uri))
        for (rel_ctr = 0; rel_ctr < rel_count; rel_ctr++)
          {
            caddr_t prop = rels[rel_ctr];
            tf_triple (xp->xp_tf, xp->xp_tf->tf_base_uri, prop, ref);
          }
      dk_free_tree ((caddr_t)rels);
      dk_free_box (ref);
    }
  if ((NULL != avalues[MDATA_ATTR_OBJ_NAME]) && (NULL != avalues[MDATA_ATTR_OBJ_CONTENT_STRLIT]))
    {
      caddr_t rel = xp_mdata_parse_attr_value (xp, xn, MDATA_ATTR_OBJ_NAME, avalues,
            MDATA_ATTRSYNTAX_REL | MDATA_ATTRSYNTAX_URI | MDATA_ATTRSYNTAX_SILENT, NULL, NULL );
      if ((NULL != rel) && (NULL != xp->xp_tf->tf_base_uri))
        tf_triple_l (xp->xp_tf, xp->xp_tf->tf_base_uri, rel, avalues[MDATA_ATTR_OBJ_CONTENT_STRLIT], NULL, inner->xmdatal_language);
      dk_free_box (rel);
    }
  if (NULL != avalues[MDATA_ATTR_OBJ_CITE_REF])
    {
      caddr_t ref = xp_mdata_parse_attr_value (xp, xn, MDATA_ATTR_OBJ_CITE_REF, avalues,
            MDATA_ATTRSYNTAX_URI | MDATA_ATTRSYNTAX_OPTIONAL, NULL, NULL );
      if ((NULL != ref) && (NULL != xp->xp_tf->tf_base_uri))
        tf_triple (xp->xp_tf, xp->xp_tf->tf_base_uri, box_dv_uname_string ("http://purl.org/dc/terms/source"), ref);
      dk_free_box (ref);
    }

all_attributes_are_retrieved:
/* Escape if nothing interesting is detected at all */
  if (!need_mdata_local)
    {
      outer->xmdatal_boring_opened_elts++;
      return;
    }
/* There is something interesting so the stack should grow */
  if (!xn_is_allocated)
    {
      xn = xp->xp_free_list;
      xp->xp_free_list = xn->xn_parent;
      memset (xn, 0, sizeof (xp_node_t));
      xn->xn_xp = xp;
      xn->xn_parent = xp->xp_current;
      xp->xp_current = xn;
    }
}

void
xp_mdata_element_end (void *userdata, const char * name)
{
  xparse_ctx_t *xp = (xparse_ctx_t*) userdata;
  xp_mdata_locals_t *inner = xp->xp_mdata_locals;
  xp_node_t *current_node, *parent_node;
  int inner_place_bits = inner->xmdatal_place_bits;
  if (NULL == inner->xmdatal_xn)
    return; /* This happens for elements that are closed outside any "interesting" element */
  if ((xp->xp_current != inner->xmdatal_xn) && (MDATA_IN_XMLLITERAL & inner_place_bits))
    {
      xp_element_end (userdata, name);
      return;
    }
  if (inner->xmdatal_boring_opened_elts)
    {
      inner->xmdatal_boring_opened_elts--;
      return;
    }
  inner_place_bits = inner->xmdatal_place_bits;
  current_node = xp->xp_current;
  if ((MDATA_IN_STRLITERAL | MDATA_IN_XMLLITERAL) & inner_place_bits)
    {
      caddr_t obj = NULL;
      int prop_ctr, prop_count;
      if (MDATA_IN_XMLLITERAL & inner_place_bits)
        {
          dk_set_t children;
          caddr_t *literal_head;
          caddr_t literal_tree;
          xml_tree_ent_t *literal_xte;
          XP_STRSES_FLUSH (xp);
          children = dk_set_nreverse (current_node->xn_children);
          literal_head = (caddr_t *)list (1, uname__root);
          children = CONS (literal_head, children);
          literal_tree = list_to_array (children);
          current_node->xn_children = NULL;
          literal_xte = xte_from_tree (literal_tree, xp->xp_qi);
          obj = (caddr_t) literal_xte;
        }
      else
        {
          obj = strses_string (xp->xp_strses);
          strses_flush (xp->xp_strses);
        }
      prop_count = inner->xmdatal_prop_count;
      for (prop_ctr = prop_count; prop_ctr--; /* no step */)
        {
          caddr_t prop = inner->xmdatal_props[prop_ctr];
          inner->xmdatal_props[prop_ctr] = NULL;
          mdata_feed_or_keep (xp, inner, prop, inner, (prop_ctr ? box_copy_tree (obj) : obj), MDATA_ATTR_OBJ_STRLIT);
        }
    }
  parent_node = xp->xp_current->xn_parent;
  dk_free_tree ((caddr_t)(current_node->xn_attrs));
  xp->xp_current = parent_node;
  current_node->xn_parent = xp->xp_free_list;
  xp->xp_free_list = current_node;
  xp_pop_mdata_locals (xp);
}

void
xp_mdata_id (void *userdata, char * name)
{
  xparse_ctx_t *xp = (xparse_ctx_t*) userdata;
  xp_mdata_locals_t *inner = xp->xp_mdata_locals;
  if (RDFA_IN_XMLLITERAL & inner->xmdatal_place_bits)
    xp_id (userdata, name);
}

void
xp_mdata_character (void *userdata,  char * s, int len)
{
  xparse_ctx_t *xp = (xparse_ctx_t*) userdata;
  xp_mdata_locals_t *inner = xp->xp_mdata_locals;
  int inner_place_bits = inner->xmdatal_place_bits;
  if ((MDATA_IN_STRLITERAL | MDATA_IN_XMLLITERAL) & inner_place_bits)
    session_buffered_write (xp->xp_strses, s, len);
}

void
xp_mdata_entity (void *userdata, const char * refname, int reflen, int isparam, const xml_def_4_entity_t *edef)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) userdata;
  xp_mdata_locals_t *inner = xp->xp_mdata_locals;
  if (MDATA_IN_XMLLITERAL & inner->xmdatal_place_bits)
    xp_entity ((vxml_parser_t *)userdata, refname, reflen, isparam, edef);
  else if (MDATA_IN_STRLITERAL & inner->xmdatal_place_bits)
    xmlparser_logprintf (xp->xp_parser, XCFG_FATAL, 100, "Entities are not supported in string literal object");
}

void
xp_mdata_pi (void *userdata, const char *target, const char *data)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) userdata;
  xp_mdata_locals_t *inner = xp->xp_mdata_locals;
  if (MDATA_IN_XMLLITERAL & inner->xmdatal_place_bits)
    xp_pi ((vxml_parser_t *)userdata, target, data);
}

void
xp_mdata_comment (void *userdata, const char *text)
{
  xparse_ctx_t *xp = (xparse_ctx_t *) userdata;
  xp_mdata_locals_t *inner = xp->xp_mdata_locals;
  if (MDATA_IN_XMLLITERAL & inner->xmdatal_place_bits)
    xp_comment ((vxml_parser_t *)userdata, text);
}

/* Part 4. Common parser invocation routine */

void
rdfxml_parse (query_instance_t * qi, caddr_t text, caddr_t *err_ret,
  int mode_bits, const char *source_name, caddr_t base_uri, caddr_t graph_uri,
  ccaddr_t *cbk_names, caddr_t *app_env,
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
  xp_rdfxml_locals_t *root_xrl;
  xml_read_iter_env_t xrie;
  static caddr_t default_dtd_config = NULL;
  memset (&xrie, 0, sizeof (xml_read_iter_env_t));
  if (DV_BLOB_XPER_HANDLE == dtp_of_text)
    sqlr_new_error ("42000", "XM031", "Unable to parse RDF/XML from a persistent XML object");
  if (!xml_set_xml_read_iter (qi, text, &xrie, &enc))
    sqlr_new_error ("42000", "XM032",
      "Unable to parse RDF/XML from data of type %s (%d)", dv_type_title (dtp_of_text), dtp_of_text);
  if (DV_WIDE == DV_TYPE_OF (base_uri))
    base_uri = box_cast_to_UTF8 ((caddr_t *)qi, base_uri);
  else
    base_uri = box_copy (base_uri);
  xn = (xp_node_t *) dk_alloc (sizeof (xp_node_t));
  memset (xn, 0, sizeof(xp_node_t));
  memset (&context, 0, sizeof (context));
  context.xp_current = xn;
  xn->xn_xp = &context;
  root_xrl = (xp_rdfxml_locals_t *) dk_alloc_zero (sizeof (xp_rdfxml_locals_t));
  root_xrl->xrl_base = base_uri;
  root_xrl->xrl_base_set = 1;
  root_xrl->xrl_parsetype = XRL_PARSETYPE_TOP_LEVEL;
  root_xrl->xrl_xn = xn;
  context.xp_strses = strses_allocate ();
  context.xp_top = xn;
  context.xp_rdfxml_locals = root_xrl;
  context.xp_qi = qi;
  memset (&config, 0, sizeof(config));
  config.input_is_wide = xrie.xrie_text_is_wide;
  config.input_is_ge = ((mode_bits & RDFXML_OMIT_TOP_RDF) ? GE_XML : 0);
  config.input_is_html = ((mode_bits >> 8) & 0xff);
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
  if (file_read == xrie.xrie_iter)
    config.feed_buf_size = 0x10000;
  parser = VXmlParserCreate (&config);
  parser->fill_ns_2dict = 0;
  context.xp_parser = parser;
  VXmlSetUserData (parser, &context);
  if (mode_bits & RDFXML_IN_MDATA)
    {
      xp_mdata_locals_t *root_xmdatal = xp_push_mdata_locals (&context);
      root_xmdatal->xmdatal_base = box_copy (base_uri);
      context.xp_tmp = (xp_tmp_t *)dk_alloc_box_zero (sizeof (xp_tmp_t), DV_ARRAY_OF_POINTER);
      context.xp_tmp->xpt_id2desc = (id_hash_t *)box_dv_dict_hashtable (30);
      context.xp_tmp->xpt_dangling_triples = (id_hash_t *)box_dv_dict_hashtable (100);
      context.xp_tmp->xpt_subj2type = (id_hash_t *)box_dv_dict_hashtable (30);
      VXmlSetElementHandler (parser, (VXmlStartElementHandler) xp_mdata_element, xp_mdata_element_end);
      VXmlSetIdHandler (parser, (VXmlIdHandler)xp_mdata_id);
      VXmlSetCharacterDataHandler (parser, (VXmlCharacterDataHandler) xp_mdata_character);
      VXmlSetEntityRefHandler (parser, (VXmlEntityRefHandler) xp_mdata_entity);
      VXmlSetProcessingInstructionHandler (parser, (VXmlProcessingInstructionHandler) xp_mdata_pi);
      VXmlSetCommentHandler (parser, (VXmlCommentHandler) xp_mdata_comment);
    }
  else if (mode_bits & RDFXML_IN_ATTRIBUTES)
    {
      xp_rdfa_locals_t *root_xrdfal = xp_push_rdfa_locals (&context);
      root_xrdfal->xrdfal_base = box_copy (base_uri);
      context.xp_tmp = (xp_tmp_t *)dk_alloc_box_zero (sizeof (xp_tmp_t), DV_ARRAY_OF_POINTER);
      VXmlSetElementHandler (parser, (VXmlStartElementHandler) xp_rdfa_element, xp_rdfa_element_end);
      VXmlSetIdHandler (parser, (VXmlIdHandler)xp_rdfa_id);
      VXmlSetCharacterDataHandler (parser, (VXmlCharacterDataHandler) xp_rdfa_character);
      VXmlSetEntityRefHandler (parser, (VXmlEntityRefHandler) xp_rdfa_entity);
      VXmlSetProcessingInstructionHandler (parser, (VXmlProcessingInstructionHandler) xp_rdfa_pi);
      VXmlSetCommentHandler (parser, (VXmlCommentHandler) xp_rdfa_comment);
    }
  else
    {
      VXmlSetElementHandler (parser, (VXmlStartElementHandler) xp_rdfxml_element, xp_rdfxml_element_end);
      VXmlSetIdHandler (parser, (VXmlIdHandler)xp_rdfxml_id);
      VXmlSetCharacterDataHandler (parser, (VXmlCharacterDataHandler) xp_rdfxml_character);
      VXmlSetEntityRefHandler (parser, (VXmlEntityRefHandler) xp_rdfxml_entity);
      VXmlSetProcessingInstructionHandler (parser, (VXmlProcessingInstructionHandler) xp_rdfxml_pi);
      VXmlSetCommentHandler (parser, (VXmlCommentHandler) xp_rdfxml_comment);
    }
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
  tf->tf_base_uri = box_copy (base_uri);
  tf->tf_default_graph_uri = box_copy (graph_uri);
  tf->tf_app_env = app_env;
  tf->tf_creator = "rdf_load_rdfxml";
  tf->tf_boxed_input_name = box_dv_short_string (source_name);
  tf->tf_line_no_ptr = &(parser->curr_pos.line_num);
  context.xp_tf = tf;
  QR_RESET_CTX
    {
      tf_set_cbk_names (tf, cbk_names);
      TF_CHANGE_GRAPH_TO_DEFAULT (tf);
      if (0 == setjmp (context.xp_error_ctx))
        rc = VXmlParse (parser, text, xrie.xrie_text_len);
      else
        rc = 0;
      if (mode_bits & RDFXML_IN_MDATA)
        mdata_process_pending_triples (&context);
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

void
xp_free_rdf_parser_fields (xparse_ctx_t *xp)
{
  xp_rdfxml_locals_t *xrl;
  xp_rdfa_locals_t *xrdfal;
  xp_mdata_locals_t *xmdatal;
  while (NULL != xp->xp_rdfxml_locals)
    xp_pop_rdf_locals (xp);
  while (NULL != xp->xp_rdfa_locals)
    {
#ifndef NDEBUG
      dk_free_tree (xp->xp_rdfa_locals->xrdfal_ict_buffer);
      xp->xp_rdfa_locals->xrdfal_ict_buffer = NULL;
#endif
      xp_pop_rdfa_locals (xp);
    }
  while (NULL != xp->xp_mdata_locals)
    xp_pop_mdata_locals (xp);
  xrl = xp->xp_rdfxml_free_list;
  while (NULL != xrl)
    {
      xp_rdfxml_locals_t *next_xrl = xrl->xrl_parent;
      dk_free (xrl, sizeof (xp_rdfxml_locals_t));
      xrl = next_xrl;
    }
  xrdfal = xp->xp_rdfa_free_list;
  while (NULL != xrdfal)
    {
      xp_rdfa_locals_t *next_xrdfal = xrdfal->xrdfal_parent;
      dk_free_tree (xrdfal->xrdfal_ict_buffer);
      dk_free (xrdfal, sizeof (xp_rdfa_locals_t));
      xrdfal = next_xrdfal;
    }
  xmdatal = xp->xp_mdata_free_list;
  while (NULL != xmdatal)
    {
      xp_mdata_locals_t *next_xmdatal = xmdatal->xmdatal_parent;
      dk_free (xmdatal, sizeof (xp_mdata_locals_t));
      xmdatal = next_xmdatal;
    }
  dk_free_tree (xp->xp_tmp);
  /* Note that xp_tf is intentionally left untouched. */
}
