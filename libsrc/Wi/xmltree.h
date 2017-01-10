/*
 *  xmltree.h
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

#ifndef _XMLTREE_H
#define _XMLTREE_H

#include "uname_const_decl.h"
#include "xpath.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "langfunc.h"
#include "xmlparser.h"
#ifdef __cplusplus
}
#endif

/*
#ifdef DEBUG
#define XPATH_DEBUG
#endif
*/

#define MAX_XML_LNAME_LENGTH 500				/* for local names, namespace prefixes and namespace URIs */
#define MAX_XML_QNAME_LENGTH (2*MAX_XML_LNAME_LENGTH + 1)	/* for qualified names (that have semicolons) */

#define XP_TRANSLATE_HOST 1

void bx_out_value (caddr_t * qst, dk_session_t * out, db_buf_t val, wcharset_t *tgt_charset, wcharset_t *src_charset, int dks_esc_mode);

typedef struct xml_entity_s xml_entity_t;
typedef struct xml_tree_doc_s xml_tree_doc_t;
typedef struct xml_lazy_doc_s xml_lazy_doc_t;
typedef struct xper_doc_s xper_doc_t;
typedef struct xml_doc_s xml_doc_t;

#ifdef MALLOC_DEBUG
#define xe_copy(XE) dbg_xe_copy(__FILE__,__LINE__,(XE))
#define xe_cut(XE,QI) dbg_xe_cut(__FILE__,__LINE__,(XE),(QI))
#define xe_clone(XE,QI) dbg_xe_clone(__FILE__,__LINE__,(XE),(QI))
#define xe_attribute(XE,S,N,AVAL,ANAME) dbg_xe_attribute(__FILE__,__LINE__,(XE),(S),(N),(AVAL),(ANAME))
#define xe_string_value(XE,RET,DTP) dbg_xe_string_value(__FILE__,__LINE__,(XE),(RET),(DTP))
#endif

/* These bits control the handling of transitions from a subdocument to
an outer document.
'SIDEWAY' means that if 'up' happens then it must try find
a sibling of the original node and go down there, so it will be
moving left or right in the tree.
'MAY_TRANSIT' means that
if the result of 'up' is a root of generic entity (GE) is reached then
the reference node in a parent document should be made current.
This is because the XPath does not handle roots of GEs and top-level nodes of
GE are children of the parent of the reference entity node in the parent doc.
*/

#define XE_UP_SIDEWAY		0x01	/*!< Tells xe_up() to go down to the sibling if 'up' */
#define XE_UP_SIDEWAY_FWD	0x02	/*!< Tells xe_up() to move forward (not backward); has no meaning if XE_UP_SIDEWAY bit is not set */
#define XE_UP_SIDEWAY_WR	0x04	/*!< Tells xe_up() to use word-range optimization; has no meaning if XE_UP_SIDEWAY bit is not set */
#define XE_UP_MAY_TRANSIT_ONCE	0x40	/*!< Tells xe_up() that transition is allowed but not not a recursive one */
#define XE_UP_MAY_TRANSIT	0x80	/*!< Tells xe_up() that any number of transitions is allowed if GEreferences are top-level children of each other. */


/*! Table of virtual functions for XML entities */
typedef struct xe_class_s
  {
/* An explicit #ifdef is used instead of usual
DBG_NAME(typ,name,(DBG_PARAMS ...))
style in order to bypass a bug in browsing info builder of Visual Studio. */
#ifdef MALLOC_DEBUG
    xml_entity_t * (* dbg_xe_copy) (DBG_PARAMS xml_entity_t * xe);
/*! Cut the copy of given entity, turning it into a new document. */
    xml_entity_t * (* dbg_xe_cut) (DBG_PARAMS xml_entity_t *xe, query_instance_t *qi);
/*! Clone given entity by copying the root document and placing the entity into the same logical path on the copy */
    xml_entity_t * (* dbg_xe_clone) (DBG_PARAMS xml_entity_t *xe, query_instance_t *qi);
/*! Searches an entity for attributes whose names matches \c node, starting from \c start index */
    int (* dbg_xe_attribute) (DBG_PARAMS xml_entity_t * xe, int start, XT * node, caddr_t * ret, caddr_t * name_ret);
/*! Returns the string value of an entity casted to \c dtp
according to section 5 'Data Model' of XML Path Language (XPath) Version 1.0 W3C Recommendation 16 November 1999 */
    void (* dbg_xe_string_value) (DBG_PARAMS xml_entity_t * xe, caddr_t * ret, dtp_t dtp);
#else
    xml_entity_t * (* xe_copy) (xml_entity_t * xe);
/*! Cut the copy of given entity, turning it into a new document. */
    xml_entity_t * (* xe_cut) (xml_entity_t *xe, query_instance_t *qi);
/*! Clone given entity by copying the root document and placing the entity into the same logical path on the copy */
    xml_entity_t * (* xe_clone) (xml_entity_t *xe, query_instance_t *qi);
/*! Searches an entity for attributes whose names matches \c node, starting from \c start index */
    int (* xe_attribute) (xml_entity_t * xe, int start, XT * node, caddr_t * ret, caddr_t * name_ret);
/*! Returns the string value of an entity casted to \c dtp
according to section 5 'Data Model' of XML Path Language (XPath) Version 1.0 W3C Recommendation 16 November 1999 */
    void (* xe_string_value) (xml_entity_t * xe, caddr_t * ret, dtp_t dtp);
#endif
    int (* xe_string_value_is_nonempty) (xml_entity_t * xe);
/*! Tries to go up to parent and maybe through entity reference(s). */
    int (* xe_up) (xml_entity_t * xe, XT * node, int up_flags);
/*! Tries to go down through entity reference(s). If down, tries to find first child of the root. If not down, tests given node. */
    int (* xe_down) (xml_entity_t * xe, XT * node);
/*! Tries to go down through entity reference(s). If down, tries to find last child of the root. If not down, tests given node. */
    int (* xe_down_rev) (xml_entity_t * xe, XT * node);
/*! Tries to find the first child of the current node that matches \c node_test. */
    int (* xe_first_child) (xml_entity_t * xe, XT *  node_test);
/*! Tries to find the last child of the current node that matches \c node_test. */
    int (* xe_last_child) (xml_entity_t * xe, XT *  node_test);
/*! Tries to get count of children of the current node.
When some child is a reference then xe_down is used and the number of child of the root of the referenced doc is added to the total. */
    int (* xe_get_child_count_any) (xml_entity_t * xe);
/*! Tries to find the next sibling that matches \c node_test. */
    int (* xe_next_sibling) (xml_entity_t * xe, XT * node_test);
/*! Tries to find the next sibling that matches \c node_test, skipping siblings with no text hits without processing.
'wr' stands for 'Word-Range optimization' */
    int (* xe_next_sibling_wr) (xml_entity_t * xe, XT * node_test);
/*! Tries to find the previous sibling that matches \c node_test. */
    int (* xe_prev_sibling) (xml_entity_t * xe, XT * node_test);
/*! Tries to find the previous sibling that matches \c node_test, skipping siblings with no text hits without processing.
'wr' stands for 'Word-Range optimization' */
    int (* xe_prev_sibling_wr) (xml_entity_t * xe, XT * node_test);
/*! Returns string value of attribute with given name if it exists, otherwise returns NULL */
    caddr_t (* xe_attrvalue) (xml_entity_t * xe, caddr_t qname);
/*! Returns string value of current attribute of attribute entity, can't return NULL, can GPF on non-attribute entity */
    caddr_t (* xe_currattrvalue) (xml_entity_t * xe);
/*! Returns number of attributes with user data, (i.e. excluding xmlns:... attributes) */
    size_t (* xe_data_attribute_count) (xml_entity_t * xe);
/*! Returns name of element if attribute or element node; special name if texts etc. */
    caddr_t (* xe_element_name) (xml_entity_t * xe);
/*! Returns name of attribute if attribute node; name of element if element node; special name if texts etc. */
    caddr_t (* xe_ent_name) (xml_entity_t * xe);
/*! Returns the string that is an XML text representation of the entity */
    void (* xe_serialize) (xml_entity_t * xe, dk_session_t * ses);
/*! The destructor */
    void (* xe_destroy) (xml_entity_t * xe);
/*! Fills \c start and \c end with word positions of the first and the last words in main text of the entity.
Refer to fields \c xewr_main_beg and \c xewr_main_end of struct xe_word_ranges_s. */
    void (* xe_word_range) (xml_entity_t * xe, wpos_t * start, wpos_t * end);
/*! Fills \c start and \c this_end and \c last_end with word positions of the first and the last words in attributes of the entity.
\c this_end relates to the last attribute of the current entity whereas \c last_end relates to the last attribute in the whole subtree.
Refer to fields \c xewr_attr_beg, \c xewr_attr_this_end and \c xewr_attr_tree_end of struct xe_word_ranges_s. */
    void (* xe_attr_word_range) (xml_entity_t * xe, wpos_t * start, wpos_t * this_end, wpos_t * last_end);
/* IvAn/XperUpdate/000904 xe_log_update added */
    void (* xe_log_update) (xml_entity_t * xe, dk_session_t * log);
/*! Builds dk_set_t (<CODE>path[0]</CODE>) with the full path to given entity, in form
   (NONCOUNTED root document pointer, addr of root's children, addr of root's children's children ...)
   The first item of the set is the outermost document where entity is located and
   every next item specifies the step to the depth of hierarchy.
   For XML trees, the step is the index of children, for XPERs it is the position in BLOB.
   \c path should be pointer to NULL dk_set, and the result will be made by pushing steps there,
   from innermost level to root.
   Please note that the pointer to the root will NOT be counted and the pointer may become dangling,
   so the resulting path may be invalidated on any change of \c xe XML entity.
   The function returns 1 if the path is valid, 0 if it is made based on obsolete entity in changed tree. */
    int (* xe_get_logical_path) (xml_entity_t * xe, dk_set_t *path);
/*! Returns additional DTD, not associated with document but stored inside, e.g. partial DTD saved in XPER BLOB.
   It is important that the refcounter of the returned value is not incremented on return.
   If passed somewhere outside "auto" scope, refcounter should be incremented! */
    struct dtd_s * (* xe_get_addon_dtd) (xml_entity_t * xe);
/*! Returns pointer to system identifier of given "generic entity reference" name */
   const char * (* xe_get_sysid) (xml_entity_t *xe, const char *ref_name);
/*! Checks whether the name of the current element matches \c wname_node. For element entities only! */
   int (* xe_element_name_test) (xml_entity_t *xe, XT *wname_node);
/*! Checks whether the name of the current node matches \c wname_node. */
   int (* xe_ent_name_test) (xml_entity_t *xe, XT *wname_node);
/*! Checks whether the current node matches condition \c node. */
   int (* xe_ent_node_test) (xml_entity_t *xe, XT *node);
/*! Finds if two given entities refers to the same fragment of the same document */
   int (* xe_is_same_as) (const xml_entity_t *this_xe, const xml_entity_t *that_xe);
/*! Returns a node with given ID in the document of given entity or NULL. Can change the current entity. */
   xml_entity_t * (* xe_deref_id) (xml_entity_t *xe, const char * idbegin, size_t idlength);
/*! Returns a node that is \c path away from the current entity or NULL if failed. Can change the current entity. */
   xml_entity_t * (* xe_follow_path) (xml_entity_t *xe, ptrlong *path, size_t path_depth);
/*! Returns an xte_head with all attributes and element name cloned from 'this' entity */
   caddr_t * (* xe_copy_to_xte_head) (xml_entity_t *xe);
/*! Returns an xte_tree with all children and attributes and element name cloned from 'this' entity */
   caddr_t * (* xe_copy_to_xte_subtree) (xml_entity_t *xe);
/*! Returns a vector of xte_tree-s with all children of 'this' entity; generic references will be be extended. */
   caddr_t ** (* xe_copy_to_xte_forest) (xml_entity_t *xe);
/*! Emulates an input of the current entity into \c parser */
   void (* xe_emulate_input) (xml_entity_t *xe, struct vxml_parser_s *parser);
/*! Composes a new (or returns a cached) entity that is a root of a document that will become a subdocument of \c from_doc.
This is not always an external reference of the current entity, it can also be a document retrieved by xpf_document() */
   struct xml_entity_s * (* xe_reference) (query_instance_t * qi, caddr_t base, caddr_t ref, xml_doc_t * from_doc, caddr_t *err_ret);
   caddr_t (* xe_find_expanded_name_by_qname) (xml_entity_t *xe, const char *qname, int use_default);
   dk_set_t (* xe_namespace_scope) (xml_entity_t *xe, int use_default);
  } xe_class_t;

/*! Finds if two given entities have identical name, attributes and content */
int xe_are_equal (xml_entity_t *this_xe, xml_entity_t *that_xe);

/*! For an entity, returns a fingerprint of xe_are_equal.
If xe_are_equal(A,B) then xe_equal_fingerprint(A) == xe_equal_fingerprint(B) */
ptrlong xe_equal_fingerprint (xml_entity_t *xe);

/*! Finds if two given entities have identical name and attributes, but content may differ */
int xe_have_equal_heads (xml_entity_t *this_xe, xml_entity_t *that_xe);

/*! For an entity, returns a fingerprint of xe_are_equal_heads.
If xe_are_equal_heads(A,B) then xe_equal_heads_fingerprint(A) == xe_equal_heads_fingerprint(B) */
ptrlong xe_equal_heads_fingerprint (xml_entity_t *xe);

#ifdef MALLOC_DEBUG
extern xml_entity_t * dbg_xte_copy(DBG_PARAMS xml_entity_t * xe);
#define XE_IS_TREE(xe) (dbg_xte_copy == ((xml_entity_t *)(xe))->_->dbg_xe_copy)
extern xml_entity_t * dbg_xp_copy(DBG_PARAMS xml_entity_t * xe);
#define XE_IS_PERSISTENT(xe) (dbg_xp_copy == ((xml_entity_t *)(xe))->_->dbg_xe_copy)
#else
extern xml_entity_t * xte_copy(xml_entity_t * xe);
#define XE_IS_TREE(xe) (xte_copy == ((xml_entity_t *)(xe))->_->xe_copy)
extern xml_entity_t * xlazye_copy(xml_entity_t * xe);
#define XE_IS_LAZY(xe) (xlazye_copy == ((xml_entity_t *)(xe))->_->xe_copy)
extern xml_entity_t * xp_copy(xml_entity_t * xe);
#define XE_IS_PERSISTENT(xe) (xp_copy == ((xml_entity_t *)(xe))->_->xe_copy)
#endif

/* 'Base class' members that are common for all sorts of XML entities:
'_' is a pointer to table of virtual functions of the instance;
'xe_attr_name' is an expanded name of attribute for attribute nodes, NULL otherwise;
'xe_nth_attr' is an index of the attribute in the list of all attributes of an element (unused in non-attribute nodes);
'xd', 'xtd', 'xpd' is a pointer to document where the entity resides;
'xe_referer' is a pointer to parent document, NULL for entities in standalone and in top-level docs;
*/
#define XE_MEMBERS \
    xe_class_t *	_; \
    caddr_t		 xe_attr_name; \
    int			xe_nth_attr; \
    union { \
      xml_doc_t *	xd; \
      xml_tree_doc_t *  xtd; \
      xml_lazy_doc_t *  xlazyd; \
      xper_doc_t *	xpd; \
    } xe_doc; \
    xml_entity_t *	xe_referer;

/*! Base class for xml_tree_ent_t, xper_entity_t, (map_entity_t in future) */
struct xml_entity_s
  {
    XE_MEMBERS
  };

/* Set of parameters that configures the default serialization of an XML document. */
#define XOUT_MEMBERS \
  caddr_t	xout_method; \
  caddr_t	xout_version; \
  caddr_t	xout_encoding; \
  int		xout_encoding_meta; \
  int		xout_omit_xml_declaration; \
  int		xout_standalone; \
  caddr_t	xout_doctype_public; \
  caddr_t	xout_doctype_system; \
  id_hash_t *	xout_cdata_section_elements; \
  int		xout_indent; \
  caddr_t	xout_media_type; \
  int 		xout_default_ns;

/* This is to track memory leaks and double free of XML documents.
See where the document is created and put an appropriate breakpoint */
#ifdef MALLOC_DEBUG
#define XD_DBG_MEMBERS \
  const char *	xd_dbg_file; \
  int		xd_dbg_line;
#else
#define XD_DBG_MEMBERS
#endif

/* 'Base class' members that are common for all sorts of XML documents:
'xd_type' is unused and I have no idea what was the initial intention, will kill it;
'xd_qi' is the creator of the document: neither XML document nor XML entity can survive the end of query or be passed from one query instance to other;
'xd_xqi' is the creator of the document if it is composed or loaded to memory by XPath or XQuery expression;
'xd_ref_count' is the reference counter of the document to free it when the last user disappears, users are entities in the document and members of 'xd_referenced_entities' or 'xd_cached_docs';
'xd_cost' is the cost of the reloading of the document; the more it costs the later it should be removed from cache;
'xd_weight' is the estimate of the size of the document in memory, in kbytes; note that this includes referenced entities.
'xd_top_doc' is a pointer to document that references to this one;
'xd_uri' is an uri where the document comes from (maybe a fake string), that is used as base uri for subdocuments;
'xd_referenced_entities' lists all loaded generic entities that are in this document, it may be non-NULL for top-level docs only;
'xd_cached_docs' lists all documents that were loaded by XPath processor when this document was a part of initial content, it may be non-NULL for top-level docs only;
'xd_dtd' is a DTD of the document or NULL;
'xd_id_dict' maps values of ID attributes to logical paths to nodes with these IDs, this is for id() XPath function and for XQuery pointer operator, this requires DTD data and IdCache=ENABLE, otherwise it will be NULL;
'xd_id_scan' is for incremental filling of 'xd_id_dict';
'xd_default_lh' is a default language of the document, this is for free-text indexing;
'xd_ns_2dict' is two-way dictionary that maps namespace prefixes to URIs and vice versa, this is to preserve prefixes used in input document when the in-memory document is serialized;
'xd_dom_lock_count' is number of locks set by users of XML entity to prevent mutation, e.g., no one can mutate a context document of XQuery is progress;
'xd_dom_mutation' is set if a document is patched by DOM mutation function like XMLReplace, this makes it invalid input for, e.g., XSLT compiler;
*/

#define XD_MEMBERS \
  int			xd_type; \
  query_instance_t *	xd_qi; \
  xp_instance_t *	xd_xqi; \
  int		xd_ref_count; \
  struct xml_doc_s *	 xd_top_doc; \
  caddr_t	xd_uri; \
  dk_set_t	xd_referenced_entities; \
  ptrlong	xd_cost; \
  ptrlong	xd_weight; \
  struct dtd_s	*xd_dtd; \
  id_hash_t *xd_id_dict; \
  caddr_t xd_id_scan; \
  struct lang_handler_s *xd_default_lh; \
  xml_ns_2dict_t xd_ns_2dict; \
  int			xd_dom_lock_count; \
  int			xd_dom_mutation; \
  int		xd_namespaces_are_valid; \
  XOUT_MEMBERS \
  XD_DBG_MEMBERS

#define xe_ns_2dict_extend(tgt,src) \
  xml_ns_2dict_extend ( \
    &(((xml_entity_t *)(tgt))->xe_doc.xd->xd_ns_2dict), \
    &(((xml_entity_t *)(src))->xe_doc.xd->xd_ns_2dict) )

#define XD_DOM_LOCK(xd) (xd)->xd_dom_lock_count++

#ifdef DEBUG
#define XD_DOM_RELEASE(xd) do { \
    if (0 >= (xd)->xd_dom_lock_count) GPF_T; \
    (xd)->xd_dom_lock_count--; \
  } while (0)
#define XTD_DOM_MUTATE(xtd) do { \
    if ((xtd)->xd_dom_lock_count) GPF_T; \
    (xtd)->xd_dom_mutation++; \
    if (NULL != xtd->xtd_wrs) \
      { \
	id_hash_free (xtd->xtd_wrs); \
	xtd->xtd_wrs = NULL; \
      } \
 } while (0)
#else
#define XD_DOM_RELEASE(xd) (xd)->xd_dom_lock_count--
#define XTD_DOM_MUTATE(xtd) do { \
    (xtd)->xd_dom_mutation++; \
    if (NULL != xtd->xtd_wrs) \
      { \
	id_hash_free (xtd->xtd_wrs); \
	xtd->xtd_wrs = NULL; \
      } \
 } while (0)
#endif

#define XD_ID_SCAN_COMPLETED ((caddr_t)1)

struct xml_doc_s
  {
    XD_MEMBERS
  };

struct xe_word_ranges_s
  {
    wpos_t xewr_main_beg;		/*!< Position of opening tag / of the first word of text */
    wpos_t xewr_main_end;		/*!< Position of closing tag / of the last word of text */
    wpos_t xewr_attr_beg;		/*!< Position of start mark of the first attribute of opening tag or counter's value */
    wpos_t xewr_attr_this_end;		/*!< Position of end mark of the last attribute of opening tag or counter's value */
    wpos_t xewr_attr_tree_end;		/*!< Position of end mark of the last attribute in whole subtree, i.e. counter's value */
  };

typedef struct xe_word_ranges_s xe_word_ranges_t;

#define XTD_MEMBERS \
  caddr_t *	xtd_tree; \
  id_hash_t *	xtd_wrs; \
  dk_set_t 	xtd_garbage_boxes; \
  dk_set_t 	xtd_garbage_trees;

struct xml_tree_doc_s
{
  XD_MEMBERS
  XTD_MEMBERS
};

typedef struct xml_doc_cache_stdkey_s xml_doc_cache_stdkey_t;

#define XPER_MEMBERS \
  blob_handle_t	*	xpd_bh; \
  int			xpd_state; \
  id_hash_t *		xpd_wrs;

struct xper_doc_s
{
  XD_MEMBERS
  XPER_MEMBERS
};

struct xml_lazy_doc_s
{
  XD_MEMBERS
  union {
    struct { XTD_MEMBERS } xtd_stub;
    struct { XPER_MEMBERS } xper_stub;
    } stub;
  dk_set_t xlazyd_entities;
  xml_doc_cache_stdkey_t *xlazyd_cache_key;
};

typedef struct xte_bmk_s
{
  caddr_t *		xteb_current;	/*!< An subtree that is selected at some level of nesting (i.e. a subtree of either a current entity or one of its ancestors */
  int			xteb_child_no;	/*!< Index of the subtree referred by this->xteb_current in the list of children of its parent. */
} xte_bmk_t;


typedef struct xml_tree_ent_s
{
  XE_MEMBERS
  xte_bmk_t *		xte_stack_buf; /*!< Buffer for stack of ancestors of current subtree (and for current subtree) */
  xte_bmk_t *		xte_stack_top; /*!< Pointer to the top element of the stack (i.e. to info about current subtree */
  xte_bmk_t *		xte_stack_max; /*!< Pointer to the past-the-buffer-end of the stack */
} xml_tree_ent_t;

typedef struct xml_lazy_ent_s
{
  XE_MEMBERS
} xml_lazy_ent_t;

#define xte_current	xte_stack_top->xteb_current
#define xte_child_no	xte_stack_top->xteb_child_no
#define XTE_HAS_PARENT(xte) ((xte)->xte_stack_top > (xte)->xte_stack_buf)
#define XTE_HAS_2PARENTS(xte) (((xte)->xte_stack_top - (xte)->xte_stack_buf) >= 2)
#define XTE_PARENT_SUBTREE(xte) ((xte)->xte_stack_top[-1].xteb_current)

#define XTE_ADD_STACK_POS(xte) \
do { \
    xte->xte_stack_top++; \
    if (xte->xte_stack_top >= xte->xte_stack_max) \
      { size_t stack_elems = (xte->xte_stack_max - xte->xte_stack_buf); \
        size_t stack_sz = stack_elems * sizeof (xte_bmk_t); \
	xte_bmk_t * newstack = (xte_bmk_t *) dk_alloc (stack_sz * 2); \
	memcpy (newstack, xte->xte_stack_buf, stack_sz); \
	dk_free (xte->xte_stack_buf, stack_sz); \
	xte->xte_stack_buf = newstack; \
	xte->xte_stack_top = newstack + stack_elems; \
	xte->xte_stack_max = newstack + (stack_elems * 2); \
      } \
  } while (0)

#ifdef DEBUG
#define XTE_SUB_STACK_POS(xte) do { if (xte->xte_stack_top-- <= xte->xte_stack_buf) GPF_T; } while (0)
#else
#define XTE_SUB_STACK_POS(xte) xte->xte_stack_top--
#endif

typedef int32 xperpos_t;

typedef struct xper_entity_s
{
  XE_MEMBERS
  char		xper_type;		/*!< type of this entity, one of XML_MKUP_XXX constants */
  xperpos_t	xper_pos;		/*!< position of this entity in in the BLOB */
  xperpos_t	xper_first_child;	/*!< position of the first child of the entity, or 0 */
  caddr_t	xper_name;		/*!< qualified tag name or the text of comment */
  xperpos_t	xper_left;		/*!< position of left neighbor, zero if there are no siblings at left, or 0 */
  xperpos_t	xper_right;		/*!< position of right neighbor, zero if there are no siblings at right, or 0 */
  xperpos_t	xper_parent;		/*!< position of parent, zero for root entity */
  xperpos_t	xper_end;		/*!< position of end tag record, coupled with given start tag, 0 if not applicable */
  wpos_t	xper_start_word;	/*!< index of start tag in whole list of document's words */
  wpos_t	xper_end_word;		/*!< index of end tag in whole list of document's words */
  xperpos_t	xper_ns_pos;		/*!< position of namespace */
  caddr_t	xper_text;		/*!< textual data */
  xperpos_t	xper_next_item;		/*!< position of the next item (text or entity) after the end of current one, 0 if not set. */
  xperpos_t	xper_cut_pos;		/*!< value of \c xper_pos, where xper_cut_xper() was called last time */
  struct xper_entity_s *xper_cut_ent;	/*!< root entity for caching xper_cut_xper() result for \c xper_cut_pos position */
} xper_entity_t;


typedef struct xml_ent_un_s
  {
    /* union of all entity subclasses. Instances must be of this since
     * an entity may transition between instances of different subclasses when traversing a reference */
    union {
      xml_tree_ent_t	xte;
      xml_lazy_ent_t	xlazye;
      xper_entity_t	xper;
    } _;
  } xml_entity_un_t;

/* These sequences of bytes are placed in front of XPER or packed LONG XML blobs.
I hope that these sequences are senseless in any encoding. */
#define XPACK_PREFIX_LEN 4
#define XPER_PREFIX "\xE8\xED\xEC\001"	/* Persistent XML. */
#define XPACK_PREFIX "\xE8\xED\xEC\003"	/* Packed serialization of an XML tree. */

#define XE_PLAIN_TEXT			    0
#define XE_PLAIN_TEXT_OR_SERIALIZED_VECTOR  1
#define XE_XPER_SERIALIZATION		    2
#define XE_XPACK_SERIALIZATION		    3
#define XE_ENTITY_READY			    4

#define XPACK_START_DTD		0xFF	/* Byte that indicates that next datum is DTD serialization as a single string */
/* More #define XPACK_START_xxx may appear here in the future. Their values _must_ be greater than 0xE0. */

extern void xpi_free (xp_instance_t * xqi);


#define XPI_OK 0
#define XPI_AT_END 100


#ifdef XPATH_DEBUG
extern void xqi_check_slots (xp_instance_t * xqi);
#else
#define xqi_check_slots(xqi)
#endif

#ifdef XPATH_DEBUG

extern ptrlong xqi_set_debug_start;
extern ptrlong xqi_set_odometer;

#define XP_SET(p, v) \
  do { \
    caddr_t *p_tmp = (caddr_t *)(p); \
    caddr_t v_tmp = (caddr_t) v; \
    if (p_tmp != (caddr_t *)(p)) \
      GPF_T1 ("Side effect in first argument of XP_SET macro"); \
    if (IS_BOX_POINTER (v_tmp) && (v_tmp == p_tmp[0])) \
      GPF_T1 ("Self-assignment in XP_SET"); \
    if (xqi_set_odometer >= 0) \
      xqi_set_odometer++; \
    if (xqi_set_odometer >= xqi_set_debug_start) \
      dk_check_tree (p_tmp[0]); \
    dk_free_tree (p_tmp[0]); \
    if (xqi_set_odometer >= xqi_set_debug_start) \
      dk_check_tree (v_tmp); \
    p_tmp[0] = v_tmp; \
    } while (0)

#else

#define XP_SET(p, v) \
  do { \
    dk_free_tree (((caddr_t *)(p))[0]); \
    ((caddr_t *)(p))[0] = v; \
    } while (0)

#endif


#ifdef XPATH_DEBUG
#define XQI_SET(xqi, cell_idx_expn, val_expn) \
do { \
  caddr_t __val = (val_expn); \
  xqst_t __cell_idx = (cell_idx_expn); \
  caddr_t *__cell = ((caddr_t*) (xqi))+__cell_idx; \
  if (0 == __cell_idx) \
    GPF_T1 ("Zero cell idx in XQI_SET"); \
  if (xqi_set_odometer >= 0) \
    xqi_set_odometer++; \
  if (xqi_set_odometer >= xqi_set_debug_start) \
    dk_check_tree (__cell[0]); \
  if (IS_BOX_POINTER (__val) && (__val == __cell[0])) \
    GPF_T1 ("Self-assignment in xqi_set()"); \
  dk_free_tree (__cell[0]); \
  if (xqi_set_odometer >= xqi_set_debug_start) \
    dk_check_tree (__val); \
  __cell[0] = __val; \
  if (xqi_set_odometer >= xqi_set_debug_start) \
    xqi_check_slots (xqi); \
  } while(0)
#else
#define XQI_SET(xqi, cell_idx_expn, val_expn) \
do { \
  caddr_t __val = (val_expn); \
  xqst_t __cell_idx = (cell_idx_expn); \
  caddr_t *__cell = ((caddr_t*) (xqi))+__cell_idx; \
  dk_free_tree (__cell[0]); \
  __cell[0] = __val; \
  } while(0)
#endif


#define XQI_GET(xqi, cell_idx) \
  (((caddr_t*)(xqi))[cell_idx])

#define XQI_SET_INT(xqi, cell_idx, val) \
  ( ((ptrlong *) (xqi))[cell_idx] = (val))

#define XQI_GET_INT(xqi, cell_idx) \
  (((ptrlong*)(xqi))[cell_idx])

#define XQI_ADDRESS(xqi, cell_idx) \
  (&(((caddr_t *)(xqi))[cell_idx]))


extern xp_instance_t * xp_eval (xp_query_t * xqr, xml_entity_t * ctx);
extern void xqi_eval (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern caddr_t xqi_value (xp_instance_t * xqi, XT * tree, dtp_t dtp);
extern caddr_t xqi_raw_value (xp_instance_t * xqi, XT * tree);
extern int xqi_next (xp_instance_t * xqi, XT * tree);

#define XI_INITIAL 1  /* the step's init is the context node to init the iterator */
#define XI_AT_END 2  /* upon next, get next of input and init the iterator by that */
#define XI_RESULT 3	/* the current of the iterator is at step.iterator, next will step this iterator  */
#define XI_NO_ATTRIBUTE -1

int xi_next (xp_instance_t * xqi, XT * tree);
#if 0
extern int xt_is_ret_boolean (XT * tree);
extern int xt_is_ret_node_set (XT * tree);
#endif
extern int xt_predict_returned_type (XT * tree);
extern caddr_t xp_box_number (caddr_t n);

typedef void (* xp_func_t) (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);

extern caddr_t xp_box_number (caddr_t n);


typedef struct xp_node_s
{
  struct xp_node_s * xn_parent;
  caddr_t *	xn_attrs;
  dk_set_t	 xn_children;
  caddr_t *	xn_namespaces;
  long 		xn_n_children;
  struct xparse_ctx_s * xn_xp;
} xp_node_t;

typedef struct xslt_template_uses_s
{
  long	xstu_byname_calls;
  long	xstu_find_calls;
  long	xstu_find_hits;
  long	xstu_find_match_calls;
  long	xstu_find_match_hits;
} xslt_template_uses_t;


typedef struct xslt_template_s
{
  caddr_t		xst_name;
  caddr_t		xst_mode;
  float			xst_priority;
  int			xst_match_attributes;
  XT *			xst_node_test; /*!< Can be NULL unlike other places, NULL if there's no full optimization */
  xp_query_t *		xst_match;
  caddr_t *		xst_tree;
  struct xslt_sheet_s *	xst_sheet;
  int			xst_simple;
  int			xst_union_member_idx;
  xslt_template_uses_t xst_total_uses;
  xslt_template_uses_t xst_new_uses;
} xslt_template_t;


typedef struct xslt_number_format_s
  {
    caddr_t xsnf_name;
    caddr_t xsnf_decimal_sep;
    caddr_t xsnf_grouping_sep;
    caddr_t xsnf_infinity;
    caddr_t xsnf_minus_sign;
    caddr_t xsnf_NaN;
    caddr_t xsnf_percent;
    caddr_t xsnf_per_mille;
    caddr_t xsnf_zero_digit;
    caddr_t xsnf_digit;
    caddr_t xsnf_pattern_sep;
  } xslt_number_format_t;

extern caddr_t xslt_format_number (numeric_t value, caddr_t format, xslt_number_format_t * nf);


typedef struct xslt_sheet_stats_s
  {
    long	xshu_calls;
    long	xshu_abends;
  } xslt_sheet_stats_t;

typedef struct xslt_sheet_mode_s
  {
    caddr_t xstm_name;
    xslt_template_t **	xstm_attr_templates;
    xslt_template_t **	xstm_nonattr_templates;
  } xslt_sheet_mode_t;

typedef struct xslt_sheet_s
  {
    shuric_t		xsh_shuric;
    struct xslt_sheet_s **	xsh_imported_sheets;
    caddr_t *		xsh_raw_tree;		/*!< The stylesheet entity in its (almost) original form */
    caddr_t *		xsh_compiled_tree;	/*!< The compiled version of stylesheet entity. To be removed soon! */
    dk_set_t		xsh_new_templates;	/*!< Temporary set of templates used by the XSLT optimizer to prevent memory leaks on abend. */
    xslt_template_t **	xsh_all_templates;
    dk_hash_t *		xsh_all_templates_byname;
    xslt_sheet_mode_t	xsh_default_mode;
    dk_hash_t *		xsh_named_modes;
    xqi_binding_t *	xsh_globals;
    dk_set_t		xsh_formats;
    xml_ns_2dict_t	xsh_ns_2dict;		/*!< Dictionary of namespace that are declared in the stylesheet (or imported) and will extend the xd_ns_2dict of the resulting tree */
    caddr_t		xsh_top_excl_res_prefx;	/*!< String that is an attribute value expression (string with expressions in {...}) that is value of exclude-result-prefixes attr of xsl:stylesheet element */
    caddr_t		xsh_sparql_preamble;	/*!< A string that is inserted at the front of any SPARQL query that is executed by for-each-row */
    XOUT_MEMBERS
    xslt_sheet_stats_t	xsh_total_uses;
    xslt_sheet_stats_t	xsh_new_uses;
  } xslt_sheet_t;


#define XSNF_NEW \
	(xslt_number_format_t *) dk_alloc_box_zero (11 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);

extern xslt_number_format_t *xsnf_default;

/*! Context of an XML parsers (XML, XSLT, RDF/XML, RDFa, Microdata) */
typedef struct xparse_ctx_s
{
  struct xparse_ctx_s *	xp_parent;	/*!< Context of parent parser (not-NULL when a parser reads GE (generic entity) nested in other document) */
  xp_node_t *		xp_top;		/*!< Topmost node of the (currently incomplete) tree */
  xp_node_t *		xp_current;	/*!< Current node (innermost not-yet-closed tag) */
  xp_node_t *		xp_free_list;	/*!< Free-list, to avoid costly dk_alloc() overhead for every node */
  long			xp_bytes;
  query_instance_t *	 xp_qi;		/*!< Query that launched the parser */
  dk_session_t *	xp_strses;
  caddr_t		xp_id;
  caddr_t		xp_id_limit;
  jmp_buf		xp_error_ctx;
  caddr_t		xp_error_msg;
#ifdef XP_TRANSLATE_HOST
  caddr_t		xp_schema;
  caddr_t		xp_net_loc;	/*!< [login] hostname [port] */
  caddr_t		xp_path;	/*!< with starting '/' but with no params or query */
#endif
  xslt_sheet_t *	xp_sheet;
  dk_set_t 		xp_checked_functions;
  struct vxml_parser_s *	xp_parser;	/*!< The XML parser itself */
  xslt_template_t *	xp_template;
  struct xml_doc_cache_s *	xp_doc_cache;
  xqi_binding_t *	xp_globals;
  xqi_binding_t *	xp_locals;
  xqi_binding_t *	xp_prepared_parameters;
  caddr_t		xp_mode;
  xml_entity_t *	xp_current_xe;
  long			xp_position;
  long			xp_size;
  dk_hash_t *		xp_temps;
  caddr_t		xp_xslt_start;
  caddr_t		xp_keys;
  id_hash_t *		xp_id_dict;
  caddr_t		xp_boxed_name;
  id_hash_t *		xp_namespaces;
  int			xp_namespaces_are_valid;
  caddr_t		xp_top_excl_res_prefx;	/*!< The value of exclude-result-prefixes XSLT attribute */
  struct triple_feed_s *xp_tf;			/*!< Triple feeder (for both RDF/XML and RDFa) */
  struct xp_rdfxml_locals_s *	xp_rdfxml_locals;
  struct xp_rdfxml_locals_s *	xp_rdfxml_free_list;
  struct xp_rdfa_locals_s *	xp_rdfa_locals;
  struct xp_rdfa_locals_s *	xp_rdfa_free_list;
  struct xp_mdata_locals_s *	xp_mdata_locals;
  struct xp_mdata_locals_s *	xp_mdata_free_list;
  struct xp_tmp_s *		xp_tmp;
} xparse_ctx_t;

extern void xp_free_rdf_parser_fields (xparse_ctx_t * xp);

extern void xp_element (void *userdata, char * name, vxml_parser_attrdata_t *attrdata);
extern void xp_element_end (void *userdata, const char * name);
extern void xp_id (void *userdata, char * name);
extern void xp_character (vxml_parser_t * parser,  char * s, int len);
extern void xp_entity (vxml_parser_t * parser, const char * refname, int reflen, int isparam, const xml_def_4_entity_t *edef);
extern void xp_pi (vxml_parser_t * parser, const char *target, const char *data);
extern void xp_comment (vxml_parser_t * parser, const char *text);

#define XP_CTX_POS(xp, sz, pos) xp->xp_position = pos, xp->xp_size = sz
#define XP_CTX_POS_GET(xp, sz, pos) pos = xp->xp_position, sz = xp->xp_size

#define XP_STRSES_FLUSH_NOCHECK(xp) \
  { \
    caddr_t text = strses_string ((xp)->xp_strses); \
    strses_flush ((xp)->xp_strses); \
    dk_set_push (&((xp)->xp_current->xn_children), (void*) text); \
    (xp)->xp_current->xn_n_children++; \
  }

#define XP_STRSES_FLUSH(xp) \
  do { \
    size_t xp_strses_length = strses_length ((xp)->xp_strses); \
    if (0 != xp_strses_length) \
      { \
        if (xp_strses_length & ~0xffffff) \
          sqlr_new_error ("42000", "SR596", "Unable to place abnormally long string into XML tree, %ld bytes is above 16Mb limit", (long)xp_strses_length); \
        XP_STRSES_FLUSH_NOCHECK(xp); \
	if ((xp)->xp_current->xn_n_children >= MAX_BOX_ELEMENTS) \
          sqlr_new_error ("42000", "SR596", "Unable to place abnormally long XML tree, %ld elements are above %ld limit", (long)(xp)->xp_current->xn_n_children, MAX_BOX_ELEMENTS); \
      } \
    } while (0)


#define XTE_HEAD(x) (((caddr_t **)x)[0])
#define XTE_HEAD_NAME(x) (((caddr_t *)x)[0])

extern void xn_xslt_attributes (xp_node_t * xn);

typedef struct xp_query_env_s
{
  int xqre_allow_sql_extensions;
  caddr_t xqre_base_uri;
  xp_node_t * xqre_nsctx_xn;		/*!< Namespace context as xp_node_t * */
  xml_entity_t *xqre_nsctx_xe;		/*!< Namespace context as xml_entity_t * */
  wcharset_t *xqre_query_charset;
  int xqre_query_charset_is_set;
  dk_set_t *xqre_checked_functions;
  dk_set_t *xqre_sql_columns;
  int xqre_key_gen;
} xp_query_env_t;

extern xp_query_env_t xqre_default;

extern xp_query_t * xp_query_parse (query_instance_t * qi, char * str, ptrlong predicate_type, caddr_t * err_ret, xp_query_env_t *xqre);
extern caddr_t xp_query_lex_analyze (caddr_t str, char predicate_type, xp_node_t * nsctx, wcharset_t *query_charset);

/* IvAn/SmartXContains/001025 WR-optimization added */
/* \brief Enables WR-optimization for given xpath subtree, if it's possible
\arg xqr - whole query
\arg subtree - current xpath tree to try to optimize
\arg target_is_wr - flags if current tree is an input for wr-optimized xpath step,
If so, it may be optimized even if it is has no optimization hints by itself. */
extern void xp_query_enable_wr (xp_query_t * xqr, XT *subtree, int target_is_wr);

extern caddr_t bif_xslt (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
extern caddr_t bif_xtree_doc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
extern void xpf_processXSLT (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);

extern xml_entity_t * xte_copy (xml_entity_t * xe);
extern void xslt_init (void);

extern int xqi_truth_value (xp_instance_t * xqi, XT * tree);
extern int xqi_truth_value_of_box (caddr_t val);
extern int xqi_pred_truth_value (xp_instance_t * xqi, XT * tree);
extern xp_instance_t *xqr_instance (xp_query_t * xqr, query_instance_t * qi);
extern void xn_error (xp_node_t * xn, const char * msg);
extern int xqi_is_next_value (xp_instance_t * xqi, XT * tree);
extern int xqi_is_value (xp_instance_t * xqi, XT * tree);

extern void xslt_instantiate_1 (xparse_ctx_t * xp, caddr_t * xstree);
extern void xslt_process_children (xparse_ctx_t * xp, xml_entity_t * xe);
extern void xp_free (xparse_ctx_t * xp);
#define xqi_free(q) dk_free_box ((caddr_t) q)


extern int xe_destroy (caddr_t box);
extern void xe_sqlnarrow_string_value (xml_entity_t * xe, caddr_t * ret, dtp_t dtp);

extern int xe_down_transit (xml_entity_t * xe);
extern int xe_destroy (caddr_t box);
extern const char * xe_get_sysid (xml_entity_t *xe, const char *ref_name);
extern const char * xe_get_sysid_base_uri(xml_entity_t *xe);

#if 0
int dv_is_node_set (caddr_t x);
#define DV_IS_NODE_SET(q) dv_is_node_set((caddr_t) q)
#endif

extern caddr_t xte_attr_value (caddr_t * xte, char * name, int reqd);
extern caddr_t xp_string (query_instance_t * qi, caddr_t val);

extern void DBG_NAME(xe_string_value_1) (DBG_PARAMS xml_entity_t * xe, caddr_t * ret, dtp_t dtp);
extern xml_tree_ent_t *DBG_NAME(xte_from_tree) (DBG_PARAMS caddr_t tree, query_instance_t * qi);
#ifdef MALLOC_DEBUG
#define xe_string_value_1(XE,RET,DTP) dbg_xe_string_value_1(__FILE__, __LINE__, (XE), (RET), (DTP))
#define xte_from_tree(TREE,QI) dbg_xte_from_tree(__FILE__, __LINE__, (TREE), (QI))
#endif

extern void xte_copy_output_elements (struct xml_tree_ent_s *xte, struct xslt_sheet_s *sheet);

extern ptrlong xqi_set_debug_start;	/* Value of xqi_set_odometer where rigorous memory testing must be started */
extern ptrlong xqi_set_odometer;	/* Debugging counter of xqi_set operations, set to negative to avoid counting */
extern caddr_t xqi_set (xp_instance_t * xqi, int n, caddr_t v);

extern shuric_vtable_t shuric_vtable__xmlschema;
extern shuric_vtable_t shuric_vtable__xqr;
extern shuric_vtable_t shuric_vtable__xslt;

extern shuric_t *shuric_load_xml_by_qi (query_instance_t * qi, caddr_t base, caddr_t ref,
	    caddr_t * err_ret, shuric_t *loaded_by, shuric_vtable_t *vt, const char *caller);
extern xslt_sheet_t * xslt_sheet (query_instance_t * qi, caddr_t base, caddr_t ref,
	    caddr_t * err_ret, shuric_t *loaded_by);
extern caddr_t xte_attr_value_eval (xparse_ctx_t * xp, caddr_t * xte, char * name, int reqd);
extern caddr_t xn_ns_name (xp_node_t * xn, char * name, int use_default);
extern void xslt_traverse_inner (xparse_ctx_t * xp, xslt_sheet_t * first_xsh);
extern xslt_sheet_t * xslt_compiled_sheet (caddr_t href, caddr_t base_uri);
extern void xslt_instantiate (xparse_ctx_t * xp, xslt_template_t * xst, xml_entity_t * xe);

#define xslt_traverse_1(XP) xslt_traverse_inner ((XP), NULL)

extern caddr_t xml_get_ns_uri (client_connection_t *cli, caddr_t pref, ptrlong persistent, int ret_in_mp_box);

extern void DBG_NAME(xte_string_value_from_tree) (DBG_PARAMS caddr_t * current, caddr_t * ret, dtp_t dtp);
#ifdef MALLOC_DEBUG
#define xte_string_value_from_tree(C,RET,DTP) dbg_xte_string_value_from_tree (__FILE__,__LINE__,(C),(RET),(DTP))
#endif
extern dk_set_t xn_namespace_scope (xp_node_t * xn);
extern void xte_serialize (xml_entity_t * xe, dk_session_t * ses);
extern query_instance_t * qi_top_qi (query_instance_t * qi);

#define xte_is_entity(e) (DV_ARRAY_OF_POINTER == DV_TYPE_OF ((e)))

extern int xsl_is_qnames_attr (char * attr);
extern int xslt_non_whitespace (caddr_t elt);

/* \brief Finds if there are any hits in current row between two given positions */
extern int txs_is_hit_in (text_node_t * txs, caddr_t * qst, xml_entity_t * xe);

extern void bif_text_init (void);
extern void bif_ap_init (void);
extern void xml_tree_init (void);
extern void xml_lazy_init (void);

extern void xn_free (xpath_node_t * xn);
extern void xn_input (xpath_node_t * xn, caddr_t * inst, caddr_t *state);

extern caddr_t xn_text_query (xpath_node_t * xn, query_instance_t * qi, caddr_t xp_str);

xml_schema_t * xs_allocate (void);

extern void xmls_set_view_def (void * sc, xml_view_t * xv);
extern int xml_is_sch_qname (char *tag, char *attr); /* What of attribute values to be expanded as QName */
extern int xml_is_soap_qname (char *tag, char *attr);
extern int xml_is_wsdl_qname (char *tag, char *attr);
extern char * xml_find_attribute (caddr_t *entity, const char *szName, const char *szURI);
extern char * xte_output_method (xml_tree_ent_t * xte);

extern xqi_binding_t *xqi_find_binding (xp_instance_t * xqi, caddr_t name);
extern xqi_binding_t *xqi_push_internal_binding (xp_instance_t * xqi, caddr_t name);
extern void xqi_pop_internal_binding (xp_instance_t * xqi);
extern void xqi_pop_internal_bindings (xp_instance_t * xqi, xqi_binding_t *bottom_xb);
extern void xqi_remove_internal_binding (xp_instance_t * xqi, caddr_t name);
extern caddr_t list_to_array_of_xqval (dk_set_t l);

extern caddr_t xml_deserialize_from_blob (caddr_t bh, lock_trx_t *lt, caddr_t *qst, caddr_t uri);

extern void xte_serialize_packed (caddr_t *tree, dtd_t *dtd, dk_session_t * ses);
extern void xte_deserialize_packed (dk_session_t *ses, caddr_t **ret_tree, dtd_t **ret_dtd);
int xte_serialization_len (db_buf_t str);
extern void dtd_save_str_to_buffer (unsigned char **tail_ptr, char *str);
extern int dtd_get_buffer_length (dtd_t * dtd);
extern void dtd_save_to_buffer (dtd_t *dtd, unsigned char *buf, size_t buf_len);
extern void dtd_load_from_buffer (dtd_t *res, caddr_t dtd_string);
extern void xe_insert_external_dtd (xml_entity_t *xe);
extern caddr_t xte_sum64 (caddr_t *curr);

extern caddr_t xml_make_tree (query_instance_t * qi, caddr_t text, caddr_t *err_ret,
    const char *enc, lang_handler_t *lh, struct dtd_s **ret_dtd);

extern int xe_strses_serialize_utf8 (xml_entity_t * xe, dk_session_t * strses, int set_encoding);
extern void xe_serialize (xml_entity_t * xe, dk_session_t * ses);

extern caddr_t xml_get_cli_or_global_ns_prefix (caddr_t * qst, const char *uri, ptrlong persistent);

extern void xte_replace_strings_with_unames (caddr_t **tree);

extern int xe_compare_content (xml_entity_t *xe1, xml_entity_t *xe2, int compare_uris_and_dtds);


#ifdef XTREE_DEBUG
extern void xte_tree_check (box_t box);
#else
#define xte_tree_check(box)
#endif


/* If the position of entity A is compared with position of B, then the result is coded as... */
#define XE_CMP_A_NULL_B_VALID		-4	/*!< entity cmp result if (NULL == A) && (NULL != B) */
#define XE_CMP_A_DOC_LT_B		-3	/*!< entity cmp result if A and B are in different docs and A's doc ptr < B's doc ptr */
#define XE_CMP_A_IS_BEFORE_B		-2	/*!< entity cmp result if A and B are in same doc and A is before B (and not an ancestor of B) */
#define XE_CMP_A_IS_ANCESTOR_OF_B	-1	/*!< entity cmp result if A and B are in same doc and A is an ancestor of B */
#define XE_CMP_A_IS_EQUAL_TO_B		0	/*!< entity cmp result if A and B are equal entities or both are NULLs */
#define XE_CMP_A_IS_DESCENDANT_OF_B	1	/*!< entity cmp result if A and B are in same doc and A is an descendant of B */
#define XE_CMP_A_IS_AFTER_B		2	/*!< entity cmp result if A and B are in same doc and A is after B (and not an descendant of B) */
#define XE_CMP_A_DOC_GT_B		3	/*!< entity cmp result if A and B are in different docs and A's doc ptr > B's doc ptr */
#define XE_CMP_A_VALID_B_NULL		4	/*!< entity cmp result if (NULL != A) && (NULL == B) */
extern int xe_compare_logical_paths (ptrlong *lp_A, size_t lp_A_len, ptrlong *lp_B, size_t lp_B_len);


#ifdef MALLOC_DEBUG
#define box_cast_to_UTF8(qst,data) dbg_box_cast_to_UTF8(__FILE__, __LINE__, (qst), (data))
extern caddr_t dbg_box_cast_to_UTF8 (DBG_PARAMS caddr_t * qst, caddr_t data);
#else
extern caddr_t box_cast_to_UTF8 (caddr_t * qst, caddr_t data);
#endif

extern caddr_t box_cast_to_UTF8_xsd (caddr_t *qst, caddr_t data);
extern caddr_t box_cast_to_UTF8_uname (caddr_t *qst, caddr_t raw_name);

#define XQ_SQL_COLUMN_FORMAT "sql:column(%s)"

#define BOX_DV_UNAME_CONCAT4(qname,nsuri,local,local_len) \
  do { \
    ccaddr_t _nsuri = (nsuri); \
    int _nsuri_len = box_length_inline (_nsuri) - 1; \
    ccaddr_t _local = (local); \
    int _local_len = (local_len); \
    int _qname_len = _nsuri_len + _local_len; \
    caddr_t _qname = box_dv_ubuf (_qname_len); \
    memcpy (_qname, _nsuri, _nsuri_len); \
    memcpy (_qname + _nsuri_len, _local, _local_len); \
    _qname[_qname_len] = '\0'; \
    (qname) = box_dv_uname_from_ubuf (_qname); \
  } while (0)

#define BOX_DV_UNAME_CONCAT(qname,nsuri,local) \
  do { \
    ccaddr_t _local1 = (local); \
    int _local1_len = box_length_inline (_local1) - 1; \
    BOX_DV_UNAME_CONCAT4(qname,nsuri,_local1,_local1_len); \
  } while (0)

#define BOX_DV_UNAME_COLONCONCAT5(qname,nsuri,nsuri_len,local,local_len) \
  do { \
    ccaddr_t _nsuri5 = (nsuri); \
    int _nsuri5_len = (nsuri_len); \
    ccaddr_t _local5 = (local); \
    int _local5_len = (local_len); \
    int _qname5_len = _nsuri5_len + _local5_len + 1; \
    caddr_t _qname5 = box_dv_ubuf (_qname5_len); \
    memcpy (_qname5, _nsuri5, _nsuri5_len); \
    _qname5[_nsuri5_len++] = ':'; \
    memcpy (_qname5 + _nsuri5_len, _local5, _local5_len); \
    _qname5[_qname5_len] = '\0'; \
    (qname) = box_dv_uname_from_ubuf (_qname5); \
  } while (0)

#define BOX_DV_UNAME_COLONCONCAT4(qname,nsuri,local,local_len) \
  do { \
    ccaddr_t _nsuri4 = (nsuri); \
    ccaddr_t _local4 = (local); \
    int _local4_len = (local_len); \
    int _nsuri4_len = box_length_inline (_nsuri4) - 1; \
    BOX_DV_UNAME_COLONCONCAT5(qname,_nsuri4,_nsuri4_len,_local4,_local4_len); \
  } while (0)

#define BOX_DV_UNAME_COLONCONCAT(qname,nsuri,local) \
  do { \
    ccaddr_t _local1 = (local); \
    int _local1_len = box_length_inline (_local1) - 1; \
    BOX_DV_UNAME_COLONCONCAT4(qname,nsuri,_local1,_local1_len); \
  } while (0)

extern int xt_node_test_match_impl (XT * node_test, caddr_t qname);

#define xt_node_test_match(NT,Q) (((XT *)XP_NODE == (NT)) ? 1 : xt_node_test_match_impl(NT,Q))

extern int xt_node_test_match_parts (XT * node_test, char *name, size_t name_len, caddr_t ns);

/* Data feeders to retrieve source XML texts from various sources */

extern size_t file_read (void *read_cd, char *buf, size_t bsize);

/* \brief Forward-only iterator for dk_session_t. */
typedef struct dk_session_fwd_iter_s
{
  dk_session_t *dsfi_dorigin;	/*!< Data origin = session to iterate */
  buffer_elt_t *dsfi_buffer;	/*!< Pointer to buffer from buffer chain of dk_session_t */
  size_t dsfi_offset;		/*!< Offset in dsfi_buffer, where first unread char resides */
  size_t dsfi_file_len;		/*!< Length of the file visible as dsfi_dorigin->dks_session->ses_file */
  size_t dsfi_file_offset;	/*!< Offset in dsfi_dorigin->dks_session->ses_file, where first unread char resides */
} dk_session_fwd_iter_t;

extern void dsfi_reset (dk_session_fwd_iter_t * iter, dk_session_t * ses);
extern size_t dsfi_read (void *read_cd, char *buf, size_t bsize);

typedef struct bh_from_client_fwd_iter_s
{
  blob_handle_t *bcfi_bh;
  client_connection_t *bcfi_cli;
} bh_from_client_fwd_iter_t;

extern void bcfi_reset (bh_from_client_fwd_iter_t * iter, blob_handle_t *bh, client_connection_t *cli);
extern size_t bcfi_read (void *read_cd, char *buf, size_t bsize);
extern void bcfi_abend (void *read_cd);

typedef struct bh_from_disk_fwd_iter_s
{
  blob_handle_t *bdfi_bh;
  query_instance_t *bdfi_qi;
  int bdfi_page_idx;
  size_t bdfi_page_data_pos;
  size_t bdfi_total_pos;
} bh_from_disk_fwd_iter_t;

extern void bdfi_reset (bh_from_disk_fwd_iter_t * iter, blob_handle_t *bh, query_instance_t *qi);
extern size_t bdfi_read (void *read_cd, char *buf, size_t bsize);

typedef struct xml_read_iter_env_s
{
  bh_from_client_fwd_iter_t	xrie_bcfi;
  bh_from_disk_fwd_iter_t	xrie_bdfi;
  dk_session_fwd_iter_t		xrie_dsfi;
  xml_read_func_t		xrie_iter;
  xml_read_abend_func_t		xrie_iter_abend;
  void *			xrie_iter_data;
  s_size_t			xrie_text_len;
  int				xrie_text_is_wide;
}
xml_read_iter_env_t;

extern int xml_set_xml_read_iter (query_instance_t * qi, caddr_t text, xml_read_iter_env_t *xrie, const char **enc_ret);


#define XDC_DOCUMENT 0		/*!< Storage type of dependant documents that are not external resources */
#define XDC_COLLECTION 1	/*!< Storage type of lists of resources in collections */

struct xml_doc_cache_stdkey_s
{
  ptrlong xdcs_type;
  caddr_t xdcs_abs_uri;
  ptrlong xdcs_parser_mode;
  caddr_t xdcs_enc_name;
  lang_handler_t **xdcs_lang_ptr;
  caddr_t xdcs_dtd_cfg;
};

/* This is a collection of XML document cache */
typedef struct xml_doc_cache_s
  {
    void *xdc_owner; /*!< Cache owner, e.g., to clean on owner's free */
    size_t xdc_total_weight; /*!< Total size of all docs in cache, in kbytes */
    size_t xdc_yellow_weight; /*!< Yellow mark: if exceeded then some docs should be freed */
    size_t xdc_red_weight; /*!< Red mark: if exceeded then all docs should be freed */
    id_hash_t *	xdc_res_cache; /*!< Hashtable of all dependant documents that are not external references */
  } xml_doc_cache_t;

xml_doc_cache_t *xml_doc_cache_alloc (void *owner);
void xml_doc_cache_free (xml_doc_cache_t *xdc);
caddr_t xml_doc_cache_get_copy (xml_doc_cache_t *xdc, ccaddr_t key);
void xml_doc_cache_add_copy (xml_doc_cache_t **xdc_ptr, ccaddr_t key, caddr_t doc);
void xml_doc_cache_shrink (xml_doc_cache_t *xdc, size_t weight_limit);

#define XE_IS_VALID_VALUE_FOR_XML_COL(val) (DV_BLOB_XPER_HANDLE != DV_TYPE_OF (val) && (DV_XML_ENTITY != DV_TYPE_OF (val) || (XE_IS_TREE (val))))

extern xml_lazy_ent_t *DBG_NAME(xlazye_from_cache_key) (DBG_PARAMS xml_doc_cache_stdkey_t *cache_key, query_instance_t *qi);
#ifdef MALLOC_DEBUG
#define xlazye_from_cache_key(key,qi) dbg_xlazye_from_cache_key(__FILE__, __LINE__, (key), (qi))
#endif

extern caddr_t xe_make_copy (caddr_t box);
#endif /* _XMLTREE_H */

