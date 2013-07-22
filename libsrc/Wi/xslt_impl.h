/*
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

#ifndef __XSLT_IMPL_H
#define __XSLT_IMPL_H

#include "xmltree.h"

#define XSLNS "http://www.w3.org/XSL/Transform/1.0"
#define XSLNS_1999 "http://www.w3.org/1999/XSL/Transform"
#define XSLNS_WD "http://www.w3.org/TR/WD-xsl"

#define is_xslns(s) ((0 == strncmp (XSLNS, s, strlen (XSLNS))) || \
		     (0 == strncmp (XSLNS_1999, s, strlen (XSLNS_1999))) || \
		     (0 == strncmp (XSLNS_WD, s, strlen (XSLNS_WD))))

extern int xte_is_xsl (caddr_t * xte);

#define XQ_TRUTH_VALUE 1
#define XQ_NODE_SET 2
#define XQ_VALUE 3

#define XSLT_EL__MASK				0x3F
#define XSLT_EL__ERROR				0
#define XSLT_EL_APPLY_IMPORTS			1
#define XSLT_EL_APPLY_TEMPLATES			2
#define XSLT_EL_ATTRIBUTE			3
#define XSLT_EL_ATTRIBUTE_SET			4
#define XSLT_EL_CALL_TEMPLATE			5
#define XSLT_EL_CHOOSE				6
#define XSLT_EL_COMMENT				7
#define XSLT_EL_COPY				8
#define XSLT_EL_COPY_OF				9
#define XSLT_EL_DECIMAL_FORMAT			10
#define XSLT_EL_ELEMENT				11
#define XSLT_EL_ELEMENT_RDFQNAME		12
#define XSLT_EL_FALLBACK			13
#define XSLT_EL_FOR_EACH			14
#define XSLT_EL_FOR_EACH_ROW			15
#define XSLT_EL_IF				16
#define XSLT_EL_IMPORT				17
#define XSLT_EL_INCLUDE				18
#define XSLT_EL_KEY				19
#define XSLT_EL_MESSAGE				20
#define XSLT_EL_NAMESPACE_ALIAS			21
#define XSLT_EL_NUMBER				22
#define XSLT_EL_OTHERWISE			23
#define XSLT_EL_OUTPUT				24
#define XSLT_EL_PARAM				25
#define XSLT_EL_PRESERVE_SPACE			26
#define XSLT_EL_PROCESSING_INSTRUCTION		27
#define XSLT_EL_SORT				28
#define XSLT_EL_STRIP_SPACE			29
#define XSLT_EL_STYLESHEET			30
#define XSLT_EL_TEMPLATE			31
#define XSLT_EL_TRANSFORM			32
#define XSLT_EL_TEXT				33
#define XSLT_EL_VALUE_OF			34
#define XSLT_EL_VARIABLE			35
#define XSLT_EL_WHEN				36
#define XSLT_EL_WITH_PARAM			37

#define XSLT_ELGRP_PCDATA			0x0001
#define XSLT_ELGRP_RESELS			0x0002
#define XSLT_ELGRP_CHARINS			0x0010
#define XSLT_ELGRP_NONCHARINS			0x0020
#define XSLT_ELGRP_INS				(XSLT_ELGRP_CHARINS | XSLT_ELGRP_NONCHARINS)
#define XSLT_ELGRP_CHARTMPL			(XSLT_ELGRP_PCDATA | XSLT_ELGRP_CHARINS)
#define XSLT_ELGRP_TMPL				(XSLT_ELGRP_PCDATA | XSLT_ELGRP_INS | XSLT_ELGRP_RESELS)
#define XSLT_ELGRP_TOPLEVEL			0x0040
#define XSLT_ELGRP_ROOTLEVEL			0x0080
#define XSLT_ELGRP_SORT				0x0100
#define XSLT_ELGRP_PARAM			0x0200
#define XSLT_ELGRP_WITH_PARAM			0x0400
#define XSLT_ELGRP_CHOICES			0x0800
#define XSLT_ELGRP_ATTRIBUTE			0x1000
#define XSLT_ELGRP_TMPLBODY			(XSLT_ELGRP_PCDATA | XSLT_ELGRP_INS | XSLT_ELGRP_RESELS | XSLT_ELGRP_PARAM)


#define XSLT_ATTR_UNUSED			0xFFFF /* special, unused */
#define XSLT_ATTR_ANY_LOCATION			1 /* not required */
#define XSLT_ATTR_ANY_NS			2 /* not required */
#define XSLT_ATTR_FIRST_SPECIAL			3 /* special, never used directly */

#define XSLT_ATTR_GENERIC_XMLNS			(XSLT_ATTR_FIRST_SPECIAL + 0) /* not required */
#define XSLT_ATTR_ATTRIBUTESET_NAME		(XSLT_ATTR_FIRST_SPECIAL + 0) /* required */
#define XSLT_ATTR_ATTRIBUTESET_USEASETS		(XSLT_ATTR_FIRST_SPECIAL + 1) /* not required */
#define XSLT_ATTR_DECIMALFORMAT_NAME		(XSLT_ATTR_FIRST_SPECIAL + 0) /* not required */
#define XSLT_ATTR_DECIMALFORMAT_DSEP		(XSLT_ATTR_FIRST_SPECIAL + 1) /* not required */
#define XSLT_ATTR_DECIMALFORMAT_GSEP		(XSLT_ATTR_FIRST_SPECIAL + 2) /* not required */
#define XSLT_ATTR_DECIMALFORMAT_INF		(XSLT_ATTR_FIRST_SPECIAL + 3) /* not required */
#define XSLT_ATTR_DECIMALFORMAT_MINUS		(XSLT_ATTR_FIRST_SPECIAL + 4) /* not required */
#define XSLT_ATTR_DECIMALFORMAT_NAN		(XSLT_ATTR_FIRST_SPECIAL + 5) /* not required */
#define XSLT_ATTR_DECIMALFORMAT_PERCENT		(XSLT_ATTR_FIRST_SPECIAL + 6) /* not required */
#define XSLT_ATTR_DECIMALFORMAT_PPM		(XSLT_ATTR_FIRST_SPECIAL + 7) /* not required */
#define XSLT_ATTR_DECIMALFORMAT_ZERO		(XSLT_ATTR_FIRST_SPECIAL + 8) /* not required */
#define XSLT_ATTR_DECIMALFORMAT_DIGIT		(XSLT_ATTR_FIRST_SPECIAL + 9) /* not required */
#define XSLT_ATTR_DECIMALFORMAT_PSEP		(XSLT_ATTR_FIRST_SPECIAL + 10) /* not required */
#define XSLT_ATTR_VARIABLEORPARAM_NAME		(XSLT_ATTR_FIRST_SPECIAL + 0) /* required */
#define XSLT_ATTR_VARIABLEORPARAM_SELECT	(XSLT_ATTR_FIRST_SPECIAL + 1) /* not required */
#define XSLT_ATTR_IMPORTORINCLUDE_HREF		(XSLT_ATTR_FIRST_SPECIAL + 0) /* required */
#define XSLT_ATTR_COPYOF_SELECT			(XSLT_ATTR_FIRST_SPECIAL + 0) /* required */
#define XSLT_ATTR_VALUEOF_SELECT		(XSLT_ATTR_FIRST_SPECIAL + 0) /* required */
#define XSLT_ATTR_VALUEOF_DISOESC		(XSLT_ATTR_FIRST_SPECIAL + 1) /* not required */
#define XSLT_ATTR_NAMESPACEALIAS_SPREF		(XSLT_ATTR_FIRST_SPECIAL + 0) /* required */
#define XSLT_ATTR_NAMESPACEALIAS_RPREF		(XSLT_ATTR_FIRST_SPECIAL + 1) /* required */
#define XSLT_ATTR_TEMPLATE_MATCH		(XSLT_ATTR_FIRST_SPECIAL + 0) /* not required */
#define XSLT_ATTR_TEMPLATE_NAME			(XSLT_ATTR_FIRST_SPECIAL + 1) /* not required */
#define XSLT_ATTR_TEMPLATE_PRIORITY		(XSLT_ATTR_FIRST_SPECIAL + 2) /* not required */
#define XSLT_ATTR_TEMPLATE_MODE			(XSLT_ATTR_FIRST_SPECIAL + 3) /* not required */
#define XSLT_ATTR_TEXT_DISOESC			(XSLT_ATTR_FIRST_SPECIAL + 0) /* not required */
#define XSLT_ATTR_SORT_DATATYPE			(XSLT_ATTR_FIRST_SPECIAL + 0) /* not required */
#define XSLT_ATTR_SORT_ORDER			(XSLT_ATTR_FIRST_SPECIAL + 1) /* not required */
#define XSLT_ATTR_SORT_SELECT			(XSLT_ATTR_FIRST_SPECIAL + 2) /* not required */
#define XSLT_ATTR_SORT_LANG			(XSLT_ATTR_FIRST_SPECIAL + 3) /* not required */
#define XSLT_ATTR_SORT_CASEORDER		(XSLT_ATTR_FIRST_SPECIAL + 4) /* not required */
#define XSLT_ATTR_STRIPORPRESERVESPACE_ELEMENTS	(XSLT_ATTR_FIRST_SPECIAL + 0) /* required */
/* XSLT_ATTR_GENERIC_XMLNS is (XSLT_ATTR_FIRST_SPECIAL + 0) for xsl:stylesheet or xsl:transform */
#define XSLT_ATTR_STYLESHEET_VERSION		(XSLT_ATTR_FIRST_SPECIAL + 1) /* required */
#define XSLT_ATTR_STYLESHEET_ID			(XSLT_ATTR_FIRST_SPECIAL + 2) /* not required */
#define XSLT_ATTR_STYLESHEET_EXT_EL_PREFS	(XSLT_ATTR_FIRST_SPECIAL + 3) /* not required */
#define XSLT_ATTR_STYLESHEET_EXC_RES_PREFS	(XSLT_ATTR_FIRST_SPECIAL + 4) /* not required */
#define XSLT_ATTR_APPLYTEMPLATES_SELECT		(XSLT_ATTR_FIRST_SPECIAL + 0) /* not required */
#define XSLT_ATTR_APPLYTEMPLATES_MODE		(XSLT_ATTR_FIRST_SPECIAL + 1) /* not required */
#define XSLT_ATTR_CALLTEMPLATE_NAME		(XSLT_ATTR_FIRST_SPECIAL + 0) /* required */
#define XSLT_ATTR_FOREACH_SELECT		(XSLT_ATTR_FIRST_SPECIAL + 0) /* required */
#define XSLT_ATTR_FOREACHROW_SPARQL		(XSLT_ATTR_FIRST_SPECIAL + 0) /* not required */
#define XSLT_ATTR_FOREACHROW_SQL		(XSLT_ATTR_FIRST_SPECIAL + 1) /* not required */
/* XSLT_ATTR_GENERIC_XMLNS is (XSLT_ATTR_FIRST_SPECIAL + 0) for xsl:attribute or xsl:element */
#define XSLT_ATTR_ATTRIBUTEORELEMENT_NAME	(XSLT_ATTR_FIRST_SPECIAL + 1) /* required */
#define XSLT_ATTR_ATTRIBUTEORELEMENT_NAMESPACE	(XSLT_ATTR_FIRST_SPECIAL + 2) /* not required */
#define XSLT_ATTR_ELEMENT_USEASETS		(XSLT_ATTR_FIRST_SPECIAL + 3) /* required */
#define XSLT_ATTR_IFORWHEN_TEST			(XSLT_ATTR_FIRST_SPECIAL + 0) /* required */
#define XSLT_ATTR_COPY_USEASETS			(XSLT_ATTR_FIRST_SPECIAL + 0) /* not required */
#define XSLT_ATTR_MESSAGE_TERMINATE		(XSLT_ATTR_FIRST_SPECIAL + 0) /* not required */
#define XSLT_ATTR_NUMBER_LEVEL			(XSLT_ATTR_FIRST_SPECIAL + 0) /* not required */
#define XSLT_ATTR_NUMBER_COUNT			(XSLT_ATTR_FIRST_SPECIAL + 1) /* not required */
#define XSLT_ATTR_NUMBER_FROM			(XSLT_ATTR_FIRST_SPECIAL + 2) /* not required */
#define XSLT_ATTR_NUMBER_VALUE			(XSLT_ATTR_FIRST_SPECIAL + 3) /* not required */
#define XSLT_ATTR_NUMBER_FORMAT			(XSLT_ATTR_FIRST_SPECIAL + 4) /* not required */
#define XSLT_ATTR_NUMBER_LANG			(XSLT_ATTR_FIRST_SPECIAL + 5) /* not required */
#define XSLT_ATTR_NUMBER_LETTERVALUE		(XSLT_ATTR_FIRST_SPECIAL + 6) /* not required */
#define XSLT_ATTR_NUMBER_GSEPARATOR		(XSLT_ATTR_FIRST_SPECIAL + 7) /* not required */
#define XSLT_ATTR_NUMBER_GSIZE			(XSLT_ATTR_FIRST_SPECIAL + 8) /* not required */
#define XSLT_ATTR_KEY_NAME			(XSLT_ATTR_FIRST_SPECIAL + 0) /* required */
#define XSLT_ATTR_KEY_MATCH			(XSLT_ATTR_FIRST_SPECIAL + 1) /* required */
#define XSLT_ATTR_KEY_USE			(XSLT_ATTR_FIRST_SPECIAL + 2) /* required */
#define XSLT_ATTR_OUTPUT_METHOD			(XSLT_ATTR_FIRST_SPECIAL + 0) /* not required */
#define XSLT_ATTR_OUTPUT_VERSION		(XSLT_ATTR_FIRST_SPECIAL + 1) /* not required */
#define XSLT_ATTR_OUTPUT_ENCODING		(XSLT_ATTR_FIRST_SPECIAL + 2) /* not required */
#define XSLT_ATTR_OUTPUT_OMITXMLDECL		(XSLT_ATTR_FIRST_SPECIAL + 3) /* not required */
#define XSLT_ATTR_OUTPUT_STANDALONE		(XSLT_ATTR_FIRST_SPECIAL + 4) /* not required */
#define XSLT_ATTR_OUTPUT_DTDPUBLIC		(XSLT_ATTR_FIRST_SPECIAL + 5) /* not required */
#define XSLT_ATTR_OUTPUT_DTDSYSTEM		(XSLT_ATTR_FIRST_SPECIAL + 6) /* not required */
#define XSLT_ATTR_OUTPUT_CDATAELS		(XSLT_ATTR_FIRST_SPECIAL + 7) /* not required */
#define XSLT_ATTR_OUTPUT_INDENT			(XSLT_ATTR_FIRST_SPECIAL + 8) /* not required */
#define XSLT_ATTR_OUTPUT_MEDIATYPE		(XSLT_ATTR_FIRST_SPECIAL + 9) /* not required */
#define XSLT_ATTR_PI_NAME			(XSLT_ATTR_FIRST_SPECIAL + 0) /* required */


typedef void (* xslt_el_fun_t) (xparse_ctx_t *, caddr_t * xstree);

#define XSLTMA_ANY	0
#define XSLTMA_LOCATION 1
#define XSLTMA_XPATH	2
#define XSLTMA_QNAME	3
#define XSLTMA_QNAMES	4

typedef struct xsltm_arg_descr_s
{
  caddr_t			xsltma_uname;
  ptrlong			xsltma_idx;
  ptrlong			xsltma_type;
  ptrlong			xsltma_required;
  struct xslt_metadata_s *	xsltma_subelem;		/*!< Subelements that are arguments. */
} xsltm_arg_descr_t;

typedef struct xslt_metadata_s
{
  xslt_el_fun_t			xsltm_executable;	/*!< Function to call */
  caddr_t			xsltm_uname;		/*!< Uname of the element */
  ptrlong			xsltm_el_id;		/*!< Numerical id of the element for use in xslt_arg_elt */
  ptrlong			xsltm_idx;		/*!< Index in \c xslt_meta_list. */
  ptrlong			xsltm_arg_no;		/*!< Number of attributes. */
  xsltm_arg_descr_t *		xsltm_args;		/*!< Allowed attributes and special subelements. */
  ptrlong			xsltm_el_memberofgroups;	/*!< Bitwise OR of IDs of all elements groups that contain this element. */
  ptrlong			xsltm_el_containsgroups;	/*!< Bitwise OR of IDs of all elements groups that may occur inside this element. */
} xslt_metadata_t;


extern id_hash_t * xslt_meta_hash;
#define XSLTM_MAXID 40
extern int xslt_meta_list_length;
extern xslt_metadata_t xslt_meta_list[XSLTM_MAXID];

#define xslt_arg_define(type,required,subelem,uname,idx) \
  ((xsltm_arg_descr_t *) (list (5, box_dv_uname_string (uname),(idx),(type),(required),(subelem))))

#define xslt_arg_eol \
  ((xsltm_arg_descr_t *) (list (1, NULL)))

extern xslt_metadata_t *xslt_define (const char * name, int xslt_el_id, xslt_el_fun_t f, int xslt_el_memberofgroups, int xslt_el_containsgroups, xsltm_arg_descr_t *arg1, ...);

#ifdef DEBUG
extern caddr_t xslt_arg_value (caddr_t * xsltree, size_t idx);
#else
#define xslt_arg_value(xsltree,idx) (XTE_HEAD(xsltree)[(idx)])
#endif

extern xslt_number_format_t *xsnf_default;
#define MAX_ATTRIBUTE_SETS_DEPTH	10

extern int xslt_measure_uses;

extern void
sqlr_new_error_xsltree_xdl (const char *code, const char *virt_code, caddr_t * xmltree, const char *string, ...)
#ifdef __GNUC__
                __attribute__ ((format (printf, 4, 5)))
#endif
;

extern caddr_t xslt_attr_value (caddr_t * xsltree, const char * name, int reqd);

extern void
xslt_sheet_prepare (xslt_sheet_t *xsh, caddr_t * xstree, query_instance_t * qi,
		    caddr_t * err_ret, xml_ns_2dict_t *ns_2dict );

extern shuric_vtable_t xslt_shuric_vtable;

extern char * xslt_fmt_print_numbers (char *tail, int tail_max_fill, unsigned *nums,
    int nums_count, char *format);

/* Historically, in-memory dictionaries and weird sortings are part of XSLT. That should be changed sooner or later. */

/*#define VECTOR_SORT_DEBUG*/
#define MAX_VECTOR_BSORT_BLOCK 8

struct vector_sort_s;

/*! Type of comparison callback for vector_qsort_int() and the like */
typedef int vector_sort_cmp_t (caddr_t * e1, caddr_t * e2, struct vector_sort_s * specs);

/*! Comparison callback used in gvector_qsort_int */
extern int gvector_sort_cmp (caddr_t * e1, caddr_t * e2, struct vector_sort_s * specs);

typedef struct vector_sort_s
{
  int vs_block_elts;		/*!< Number of elements in the sorting block */
  int vs_block_size;		/*!< Size of sorting block in bytes */
  int vs_key_ofs;		/*!< Offset of key element in sorting block, (offset in elements, not in bytes) */
  int vs_sort_asc;		/*!< Descending sort if 0, ascending sort otherwise */
  int vs_whole_vector_elts;	/*!< Number of elements in the whole vector to sort */
  caddr_t *vs_whole_vector;	/*!< Whole vector to sort */
  caddr_t *vs_whole_tmp;
  vector_sort_cmp_t *vs_cmp_fn;	/*!< Comparison callback */
  void *vs_env;			/*!< Callback-specific data */
}
vector_sort_t;

/*! Bubble sort of a vactor or its fragment */
void vector_bsort (caddr_t *bs, int n_bufs, vector_sort_t * specs);
void vector_qsort (caddr_t *vect, int group_count, vector_sort_t *specs);



#endif
