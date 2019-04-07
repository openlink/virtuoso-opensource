/*
 *  xpath.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

#ifndef _XPATH_H
#define _XPATH_H

#include "libutil.h"
#include "xmlgen.h"
#include "xmlnode.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "langfunc.h"
#ifdef __cplusplus
}
#endif
#include "shuric.h"

#define XP_UNION	(ptrlong)1000
#define XP_ABS_DESC	(ptrlong)1001
#define XP_ABS_DESC_WR	(ptrlong)1021 /* IvAn/SmartXContains/001025 Optimized axises added */
#define XP_ABS_CHILD	(ptrlong)1002
#define XP_ABS_CHILD_WR	(ptrlong)1022 /* IvAn/SmartXContains/001025 Optimized axises added */
#define XP_STEP		(ptrlong)1003
#define XP_FILTER	(ptrlong)1004
#define XP_PREDICATE	(ptrlong)1005
#define XP_ABS_DESC_OR_SELF	(ptrlong)1006
#define XP_ABS_DESC_OR_SELF_WR	(ptrlong)1026 /* IvAn/SmartXContains/040302 Optimized axises added */

#define XP_ANCESTOR		(ptrlong) AX_ANCESTOR
#define XP_ANCESTOR_OR_SELF	(ptrlong) AX_ANCESTOR_OR_SELF
#define XP_ATTRIBUTE		(ptrlong) 1301
#define XP_ATTRIBUTE_WR		(ptrlong) 1321 /* IvAn/AttrXContains/010405 Optimized axises added */
#define XP_CHILD		(ptrlong) AX_CHILD_1
#define XP_CHILD_WR		(ptrlong) AX_CHILD_1_WR	 /* IvAn/SmartXContains/001025 Optimized axises added */
#define XP_DESCENDANT		(ptrlong) AX_CHILD_REC
#define XP_DESCENDANT_WR	(ptrlong) AX_CHILD_REC_WR	/* IvAn/SmartXContains/001025 Optimized axises added */
#define XP_DESCENDANT_OR_SELF	(ptrlong) AX_DESCENDANT_OR_SELF
#define XP_DESCENDANT_OR_SELF_WR	(ptrlong) AX_DESCENDANT_OR_SELF_WR	/* IvAn/SmartXContains/001025 Optimized axises added */
#define XP_FOLLOWING		(ptrlong) AX_FOLLOWING
#define XP_FOLLOWING_SIBLING	(ptrlong) AX_SIBLING
#define XP_NAMESPACE		(ptrlong) 1307
#define XP_PARENT		(ptrlong) AX_ANCESTOR_1
#define XP_PRECEDING		(ptrlong) AX_PRECEDING
#define XP_PRECEDING_SIBLING	(ptrlong) AX_SIBLING_REV
#define XP_SELF			(ptrlong) 1011
#define XP_NODE			(ptrlong) 1012
/* No more #define W_NAME			(ptrlong) 1013 */
#define XP_ROOT			(ptrlong) 1014
#define XP_DEREF		(ptrlong) 1015

#define XP_NAME_EXACT		(ptrlong) 1030
#define XP_NAME_NSURI		(ptrlong) 1031
#define XP_NAME_LOCAL		(ptrlong) 1032

#define XP_ABS_SLASH_SLASH	(ptrlong) 1097
#define XP_SLASH_SLASH		(ptrlong) 1098
#define XP_BY_MAIN_STEP		(ptrlong) 1099



#define XP_TEXT		(ptrlong) 1100
#define XP_PI		(ptrlong) 1102
#define XP_COMMENT	(ptrlong) 1103
#define XP_VARIABLE	(ptrlong) 1104
#define XP_LITERAL	(ptrlong) 1105
#define XP_STAR		(ptrlong) 1106	/*!< This is a wildcard for part of name, not a node test */
#define XP_ELT		(ptrlong) 1107	/*!< This is a node test for any element but not a wildcard for part of name */
#define XP_ELT_OR_ROOT	(ptrlong) 1108
#define XP_FAKE_VAR	(ptrlong) 1109

/*
#define XP_HTTP		(ptrlong) 1200
#define XP_SHALLOW	(ptrlong) 1201
#define XP_DOC		(ptrlong) 1202
#define XP_KEY		(ptrlong) 1203
#define XP_TAG		(ptrlong) 1204
#define XP_VIEW		(ptrlong) 1205
#define XP__STAR	(ptrlong) 1206
#define XP_SAX		(ptrlong) 1207
#define XP_XMLNS	(ptrlong) 1208
*/
#define XP_NEAR		(ptrlong) 1209
#define XP_WORD_CHAIN	(ptrlong) 1210
#define XP_AND_NOT	(ptrlong) 1211
/*
#define XP_QUIET	(ptrlong) 1212
#define XP_DTD_CONFIG	(ptrlong) 1213
*/

/*
#define XP_LANG		(ptrlong) 1220
#define XP_ENC		(ptrlong) 1221
*/

/* #define XQ_QUERY_MODULE_LIST	(ptrlong) 1400 */
#define XQ_QUERY_MODULE		(ptrlong) 1401
#define XQ_NS_DECL	(ptrlong) 1410
/*#define XQ_SCHEMA_DECL	(ptrlong) 1411*/
#define XQ_DEFPARAM		(ptrlong) 1412
#define XQ_DEFGLOBAL		(ptrlong) 1413
#define XQ_DEFUN	(ptrlong) 1415
#define XQ_SEQTYPE	(ptrlong) 1420
#define XQ_SEQTYPE_OPT_ONE	(ptrlong) 1421
#define XQ_SEQTYPE_REQ_ONE	(ptrlong) 1422
#define XQ_SEQTYPE_OPT_MANY	(ptrlong) 1423
#define XQ_SEQTYPE_REQ_MANY	(ptrlong) 1424
#define XQ_SEQTYPE_DOCELEMENT	(ptrlong) 1425
#define XQ_SEQTYPE_ELEMENT	(ptrlong) 1426
#define XQ_SEQTYPE_ATTRIBUTE	(ptrlong) 1427
#define XQ_SEQTYPE_PI		(ptrlong) 1428
#define XQ_SEQTYPE_NODE		(ptrlong) 1429
#define XQ_NCNAME	(ptrlong) 1430
#define XQ_QNAME	(ptrlong) 1431
#define XQ_INSERT	(ptrlong) 1440
#define XQ_MOVE		(ptrlong) 1441
#define XQ_UPSERT	(ptrlong) 1442
#define XQ_DELETE	(ptrlong) 1443
#define XQ_RENAME		(ptrlong) 1444
#define XQ_REPLACE		(ptrlong) 1445
#define XQ_NOT		(ptrlong) 1450
#define XQ_INSTANCEOF	(ptrlong) 1451
#define XQ_IN		(ptrlong) 1452
#define XQ_ASSIGN	(ptrlong) 1453
#define XQ_BEFORE		(ptrlong) 1460
#define XQ_AFTER		(ptrlong) 1461
#define XQ_ASCENDING		(ptrlong) 1462
#define XQ_DESCENDING		(ptrlong) 1463
#define XQ_CAST			(ptrlong) 1464
#define XQ_TREAT		(ptrlong) 1465
#define XQ_FOR			(ptrlong) 1466
#define XQ_LET			(ptrlong) 1467
#define XQ_FOR_SQL              (ptrlong) 1468
#define XQ_IMPORT_MODULE	(ptrlong) 1469
#define XQ_IMPORT_SCHEMA	(ptrlong) 1470
#define XQ_EMPTY_SQL_ORDER	(ptrlong) 1471
#define XQ_EMPTY_GREATEST	(ptrlong) 1472
#define XQ_EMPTY_LEAST		(ptrlong) 1473
/*
SRC_RANGE_WITH_NAME_IN specifies two offsets:
One offset is for adding to \c start of xe_word_range to calculate \c from argument of sst_ranges.
It is 0 if search phrase contains starting tag, and 1 otherwise, to ignore the word before opening tag.
The word before opening tag is equal to the tag itself in terms of word position, and it may cause errors if the shift is not used.
Another offset is for adding to \c end of xe_word_range to calculate \c to argument of sst_ranges.
It is 1 if search phrase contains closing tag, and 0 otherwise, to ignore the word after closing tag.
The word after closing tag is equal to the tag itself in terms of word position, and it may cause errors if the shift is used by mistake.
*/

#define SRC_RANGE_MAIN		0x0001		/* Search is to be performed in main text (and maybe in attributes) */
#define SRC_RANGE_ATTR		0x0002		/* Search is to be performed in attributes (and maybe in main text) */
#define SRC_RANGE_OUTSIDE_WR	0x0004		/* The result of search will not be used for WR-optimization, because parts of ranges are outside the query */
#define SRC_RANGE_WITH_NAME_IN	0x0008		/* Names of tags/attribute names are parts of query expression */
#define SRC_RANGE_DUMMY		0x0010		/* The combination of flags is dummy and should be adjusted */

typedef struct xp_tree_s XT;

extern caddr_t xsltvar_uname_current;
extern caddr_t xsltvar_uname_sheet;
#define XSLT_CURRENT_ENTITY_INTERNAL_NAME	xsltvar_uname_current
#define XSLT_SHEET_INTERNAL_NAME		xsltvar_uname_sheet

typedef struct xp_ctx_s
  {
    int			xc_axis;
    int			xc_c_no;
    XT *		xc_step;
    struct xp_ctx_s *	xc_input;
    dbe_table_t *	xc_table;
    xv_join_elt_t *	xc_xj;
    dk_set_t		xc_cols;
    int			xc__pos_refd;
    ST **		xc_pk_parts;
    int			xc_left_c_no;
    int			xc_size_refd;
    int *		xc_next_c_no;
    ST *		xc_node_test;
    int			xc_is_generated;
  } xp_ctx_t;


typedef ptrlong xqst_t; /* int size of caddr_t */

#define XQR_XPATH  1
#define XQR_XSLT   2
#define XQR_XQUERY 3

typedef struct xp_debug_location_s
{
  char *		xdl_attribute;
  char *		xdl_element;
#ifdef EXTERNAL_XDLS
  ptrlong		xdl_line;
#else
  caddr_t		xdl_line;
#endif
  char *		xdl_file;
} xp_debug_location_t;


typedef struct xp_query_s
  {
    shuric_t *		xqr_shuric;
    int			xqr_owned_by_shuric;
    dk_set_t		xqr_state_map;
    int			xqr_instance_length;
    XT *		xqr_tree;
    int			xqr_wr_enabled;		/*!< non-zero if xp_query_enable_wr() was called for the query */
    /* int			xqr_mode;		/ *!< Mode of running, as XQR_NNN */
    ptrlong *	        xqr_slots;
    int			xqr_n_slots;
    xqst_t		xqr_top_pos;
    xqst_t		xqr_top_size;
    caddr_t		xqr_key;
    caddr_t		xqr_base_uri;
    xp_debug_location_t	xqr_xdl;		/*!< the query does not own these data if EXTERNAL_XDLS is defined. */
    dk_set_t		xqr_imports;
    int			xqr_is_quiet;
    int			xqr_is_davprop;
    caddr_t		xqr_xml_parser_cfg;
  } xp_query_t;


typedef struct xqi_binding_s
  {
    caddr_t		xb_name;
    caddr_t		xb_value;
    struct xqi_binding_s *	xb_next;
} xqi_binding_t;


typedef struct xp_instance_s
  {
    xp_query_t *	xqi_xqr;	/*! XPath or XQuery expression to run */
    query_instance_t *	xqi_qi;		/*! QI used by BIF that started to execute all this blab */
    xqi_binding_t *	xqi_internals;	/*! Internal variables that are local for current scope */
    xqi_binding_t *	xqi_xp_locals;	/*! Local variables that are local for current function call */
    xqi_binding_t *	xqi_xp_globals;	/*! Query-wide bindings that are top-level xsl:variable, xsl:param or similar XPath/XQuery params */
    caddr_t		xqi_xp_keys;	/*! Keys made by xsl:key */
    text_node_t *	xqi_text_node;	/*! Text node that calculates the expression, if this works inside xcontains() */
    struct xml_doc_cache_s *	xqi_doc_cache;  /*! Pointer to the document cache */
    short		xqi_slot_map_offset;
    short		xqi_n_slots;
    short		xqi_return_attrs_as_nodes;
    short		xqi_xpath2_compare_rules;
  } xp_instance_t;

#define XPP_XMLSPACE_PRESERVE	1
#define XPP_XMLSPACE_STRIP	2
#define XPP_TYPE_PRESERVE	3
#define XPP_TYPE_STRIP		4
#define XPP_ORDERING_ORDERED	5
#define XPP_ORDERING_UNORDERED	6
#define XPP_VALIDATION_SKIP	7
#define XPP_VALIDATION_LAX	8
#define XPP_VALIDATION_STRICT	9

typedef struct xp_env_s
  {
    dk_set_t		xe_ctxs;
    dbe_schema_t *	xe_schema;
    struct sql_comp_s *	xe_sc;
    struct xml_view_s *	xe_view;
#ifdef OLD_VXML_TABLES
    caddr_t		xe_doc_spec;
#endif
    int			xe_is_http;
    int			xe_is_shallow;
    int			xe_is_for_key; /*!< __key XPATH option is set: Select the key of the selected entities instead of the serialization text. */
    int			xe_is_for_attrs; /*!< __* Select all columns of the selected entity instead of its serialization text. This is only valid when __view is specified and the result set is homogeneous. */
    int			xe_inside_sql; /*!< Falgs if this is either a XPATH as a inner SELECT or an XPATH after xmlview(). */
    int			xe_after_xmlview; /*!< Flags if this is an XPATH after xmlview(). */
    int			xe_is_sax;
    caddr_t		xe_result_tag;
    int			xe_doc_bounds;
    dk_set_t		xe_namespace_prefixes;	/*!< Pairs of ns prefixes and URIs */
    dk_set_t		xe_namespace_prefixes_outer;	/*!< Bookmark in xe_namespace_prefixes that points to the first inherited (not local) namespace */
    caddr_t		xe_dflt_elt_namespace;	/*!< Default namespace URI for elements and types */
    caddr_t		xe_dflt_fn_namespace;	/*!< Default namespace URI for functions */
    dk_set_t		xe_collation_uris;	/*!< Pairs of collation URIs and descriptions */
    dk_set_t		xe_collation_uris_outer;	/*!< Bookmark in xe_collation_uris that points to the first inherited (not local) collation */
    caddr_t		xe_dflt_collation;	/*!< Description of the default collation */
    ptrlong		xe_validation_mode;	/*!< Validation mode for element constructors and validate... expressions */
    ptrlong		xe_xmlspace_mode;	/*!< processing of whitespaces in element constructors */
    ptrlong		xe_construction_mode;	/*!< processing of types in element constructors */
    ptrlong		xe_ordering_mode;	/*!< ordered/unordered default behaviour of path expressions and loops */
    caddr_t		xe_base_uri;		/*!< Default base URI for fn:doc and fn:resolve-uri */
    dk_set_t		xe_schemas;		/*!< In-scope schema definitions (imports) */
    dk_set_t		xe_schemas_outer;	/*!< Bookmark in xe_schemas that points to the first inherited (not local) schema def */
    dk_set_t		xe_modules;		/*!< In-scope module definitions (imports) */
    dk_set_t		xe_modules_outer;	/*!< Bookmark in xe_modules that points to the first inherited (not local) module def */
    int			xe_for_interp;
    int			xe_xqst_ctr;
    xp_query_t *	xe_xqr;
    dk_set_t		xe_pred_stack;
    struct xp_env_s *	xe_parent_env;
    id_hash_t *		xe_fundefs;		/*!< In-scope function definitions */
    int                 xe_outputxml;		/*!< Flags that xml document should be produced, not a text in XML syntax */
    int			xe_nonattribute_output;
  } xp_env_t;


typedef struct xp_ret_s
{
  ST *		xr_tree;
  int		xr_is_empty;
  int		xr_c_no;
  caddr_t	xr_value_col;
} xp_ret_t;



typedef struct xp_ctxbox_s
  {
    xp_ctx_t *		xcb_xc;
  } xp_ctxbox_t;

#define xpctx ctxbox->xcb_xc

typedef struct xslt_sort_s {
  xp_query_t *	xs_query;
  XT *		xs_tree;
  int		xs_is_desc;
  caddr_t	xs_type;
  caddr_t	xs_empty_weight;
  collation_t *	xs_collation;
} xslt_sort_t;

#define XPDV_BOOL	(ptrlong) 1001
#define XPDV_NODESET	(ptrlong) 1002
#define XPDV_DURATION	(ptrlong) 1003

#define XT_HEAD 2 /* number of elements before \c _ union in xp_tree_t */
typedef struct xp_tree_s
{
  ptrlong	type;
  caddr_t	srcline;
  union {
    struct {
      XT *		input;
      ptrlong		axis;
      XT *		node;
      xp_ctxbox_t *	ctxbox;
      XT **		preds;
      ptrlong		preds_use_size;
      xqst_t		iter_idx;
      xqst_t		iterator;
      xqst_t		cast_res;
      xqst_t		init;
      xqst_t		node_set;
      xqst_t		node_set_size;
      xqst_t		node_set_iter;
      xqst_t		depth;
      xqst_t		state;
    } step;
    struct {
      caddr_t	name;
      xqst_t	state;
      xqst_t	inx;
      xqst_t	res;
      xqst_t	init;
    } var;
    struct {
      caddr_t           lhptr; /* a numeric box keeping lang_handler_t ** */
      caddr_t		val;
      xqst_t		res;
    } literal;
    struct {
      XT *	expr;
      ptrlong	has_last;
      xqst_t	pos;
      xqst_t	size;
    } pred;
    struct {
      XT *	path;
      XT *	pred;
      xqst_t	state;
    } filter;
    struct {
      caddr_t		qname;
      caddr_t		executable;	/*!< Pointer to built-in function, stored as an integer. */
      ptrlong		res_dtp;	/*!< Type of the result, e.g. DV_nnn, XPDV_BOOL or XPDV_NODESET. */
      xqst_t		res;
      xqst_t		tmp;		/*!< Temporary data, e.g. for cache or to prevent leaks. */
      XT *		var;		/*!< for a set value, use the var as iterator. */
      ptrlong		argcount;	/*!< Number of actual arguments. */
      XT *		argtrees[1];	/*!< Args 2 3 etc are after the structure. */
    } xp_func;
    struct {
      XT *	left;
      XT *	right;
      xqst_t	left_lpath;
      xqst_t	right_lpath;
      xqst_t	res;
      xqst_t	state;
    } xp_union;
    struct {
      caddr_t	nsuri;
      caddr_t	local;
      caddr_t	qname;
    } name_test;
    struct {
      XT *	left;
      XT *	right;
      xqst_t	res;
    } bin_exp;
    struct {
      caddr_t		name;
      XT *		ret_type;
      xp_query_t *	body;
      ptrlong		argcount;
      XT *		params[1];
    } defun;
    struct {
      caddr_t		name;
      XT *		val_type;
      XT *		init_expn;
      xqst_t		res;
    } defglobal;
    struct {
      XT *	type;
      caddr_t	name;
      ptrlong	is_iter;
      ptrlong	is_bool;
    } paramdef;
    struct {
      XT **context;
      XT **schema_imports;
      XT **module_imports;
      XT **defuns;
      XT **defglobals;
      XT *body;
    } module;
    struct {
      ptrlong	mode;
      caddr_t   name;
      struct xs_component_s **type;
      ptrlong	is_nillable;
      ptrlong	occurrences;
    } seqtype;
    struct {
      dk_mem_wrapper_t * qr_mem_wrapper;
      dk_mem_wrapper_t * qr_for_count_mem_wrapper;	/* for count evaluation */
      caddr_t*  xp2sql_params;	/* Parameters that passes data from XPath variables to QR */
      xqst_t    xp2sql_values;	/* Normalized values of variables from xp2sql_params */
      xqst_t	lc;		/* the local_cursor_t * slot that holds the opened cursor as XQI_INT */
      xqst_t	lc_mem_wrapper; /* the dk_mem_wrapper_t * slot that holds the wrapper for lc */
      xqst_t	lc_state;	/* a state flag indicating whether the lc is at end */
      xqst_t	current;	/* slot number for holding the xml_entity_t corresponding to the current row of the cursor */
      xqst_t    inx;		/* row no */
    } xq_for_sql;
    xslt_sort_t xslt_sort;
  } _;
} xp_tree_t;



#define stlist (ST*) list
#define t_stlist (ST*) t_list
struct xpp_s;

#ifdef MALLOC_DEBUG
typedef XT* xtlist_impl_t (struct xpp_s *xpp, ptrlong length, ptrlong type, ...);
typedef XT* xtlist_with_tail_impl_t (struct xpp_s *xpp, ptrlong length, caddr_t tail, ptrlong type, ...);
typedef struct xtlist_track_s
  {
    xtlist_impl_t *xtlist_ptr;
    xtlist_with_tail_impl_t *xtlist_with_tail_ptr;
  } xtlist_track_t;

xtlist_track_t *xtlist_track (const char *file, int line);
#define xtlist xtlist_track (__FILE__, __LINE__)->xtlist_ptr
#define xtlist_with_tail xtlist_track (__FILE__, __LINE__)->xtlist_with_tail_ptr
#else
extern XT* xtlist (struct xpp_s *xpp, ptrlong length, ptrlong type, ...);
extern XT* xtlist_with_tail (struct xpp_s *xpp, ptrlong length, caddr_t tail, ptrlong type, ...);
#define xtlist_impl xtlist
#define xtlist_with_tail_impl xtlist_with_tail
#endif

caddr_t xqr_clone (caddr_t orig);
extern shuric_cache_t *xquery_eval_cache;
extern shuric_cache_t *xpath_eval_cache;

#define XNAME(v) \
  char v[10]; v##__i = (int) sprintf (v, "c__%d", (* xc->xc_next_c_no)++);


extern caddr_t * xpt_text_exp (XT * tree, XT * ctx_node);

extern int snprint_xdl (char *buffer, size_t buflength, xp_debug_location_t *xdl);
extern caddr_t sqlr_make_new_error_xdl_base (const char *code, const char *virt_code, xp_debug_location_t *xdl, const char *string, va_list vlst);
extern void sqlr_new_error_xdl_base (const char *code, const char *virt_code, xp_debug_location_t *xdl, const char *string, va_list vlst);
extern caddr_t sqlr_make_new_error_xdl (const char *code, const char *virt_code, xp_debug_location_t *xdl, const char *string, ...)
#ifdef __GNUC__
                __attribute__ ((format (printf, 4, 5)))
#endif
;
extern void sqlr_new_error_xdl (const char *code, const char *virt_code, xp_debug_location_t *xdl, const char *string, ...)
#ifdef __GNUC__
                __attribute__ ((format (printf, 4, 5)))
#endif
;
extern caddr_t
sqlr_make_new_error_xqi_xdl (const char *code, const char *virt_code, xp_instance_t * xqi, const char *string, ...)
#ifdef __GNUC__
                __attribute__ ((format (printf, 4, 5)))
#endif
;
extern void sqlr_new_error_xqi_xdl (const char *code, const char *virt_code, xp_instance_t * xqi, const char *string, ...)
#ifdef __GNUC__
                __attribute__ ((format (printf, 4, 5)))
#endif
;

#if 0
extern int xpyyleng;
extern char *xpyytext;
#endif

#endif /* _XPATH_H */

