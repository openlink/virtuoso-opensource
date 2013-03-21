/*
 *  xpf.h
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

#ifndef _XPF_H
#define _XPF_H

#include "xmltree.h"

#define XPF_BUILTIN 0
#define XPF_DEFUN 1

/* Don't forget to modify xp_register_default_namespace_prefixes() when adding new prefixes here! */
#define XFN_NS_PREFIX			"fn"
#define XFN_NS_URI			"http://www.w3.org/2005/xpath-functions"
#define XXF_NS_PREFIX			"xf"
#define XXF_NS_URI			"http://www.w3.org/2004/07/xpath-functions"
#define XLOCAL_NS_PREFIX		"local"
#define XLOCAL_NS_URI			"http://www.w3.org/2004/07/xquery-local-functions"
#define XOP_NS_PREFIX			"op"
#define XOP_NS_URI			"http://www.w3.org/2004/07/xpath-operators"
#define XDT_NS_PREFIX			"xdt"
#define XDT_NS_URI			"http://www.w3.org/2004/07/xpath-datatypes"
#define XS_NS_PREFIX			"xs"
#define XS_NS_URI			"http://www.w3.org/2001/XMLSchema"
#define XSI_NS_PREFIX			"xsi"
#define XSI_NS_URI			"http://www.w3.org/2001/XMLSchema-instance"
#define ORA_XPATH_EXTENSION_NS_URI	"http://schemas.oracle.com/xpath/extension"
#define VIRT_BPM_XPATH_EXTENSION_NS_URI "http://www.openlinksw.com/virtuoso/bpel"

typedef struct xpfm_arg_descr_s
{
  caddr_t xpfma_name;
  ptrlong xpfma_dtp;
  ptrlong xpfma_is_iter;
} xpfm_arg_descr_t;


typedef struct xpf_metadata_s
{
  char *xpfm_name;
  ptrlong xpfm_type;
  xp_func_t xpfm_executable;
  XT *xpfm_defun;
  ptrlong xpfm_res_dtp;			/*!< Type of the result, e.g. DV_BOOL for booleans and DV_XML_ENTITY for iters. */
  ptrlong xpfm_min_arg_no;		/*!< Minimum allowed number of arguments in the call (maybe less or greater than xpfm_arg_no). */
  ptrlong xpfm_main_arg_no;		/*!< Number of non-tail arguments. */
  ptrlong xpfm_tail_arg_no;		/*!< Number of tail arguments in the tail loop. */
  xpfm_arg_descr_t xpfm_args[1];	/*!< Args 2,3 etc. are after the structure, tail args are after plain. */
} xpf_metadata_t;


extern id_hash_t * xpf_metas;
extern id_hash_t * xpf_reveng;

#define xpfma(name,dtp,iter) ((xpfm_arg_descr_t *)(list (3, ((name) ? box_dv_uname_string (name) : NULL), (ptrlong)dtp, (ptrlong)iter)))
#define xpfmalist (xpfm_arg_descr_t **)list

extern void xpfm_create_and_store_builtin (
  const char *xpfm_name,
  xp_func_t xpfm_executable,
  ptrlong xpfm_res_dtp,
  ptrlong xpfm_min_arg_no,
  xpfm_arg_descr_t **xpfm_main_args,
  xpfm_arg_descr_t **xpfm_tail_args,
  const char* nmspace );

typedef void xpfm_define_builtin_t (
  const char *xpfm_name,
  xp_func_t xpfm_executable,
  ptrlong xpfm_res_dtp,
  ptrlong xpfm_min_arg_no,
  xpfm_arg_descr_t **xpfm_main_args,
  xpfm_arg_descr_t **xpfm_tail_args );

extern xpfm_define_builtin_t xpf_define_builtin, x2f_define_builtin, xqf_define_builtin, xsd_define_builtin, xop_define_builtin;

extern void xpfm_store_alias (const char *alias_local_name, const char *alias_ns, const char *main_local_name, const char *main_ns, const char *alias_mid_chars, int insert_soft);

extern void xpf_define_alias (const char *alias_local_name, const char *alias_ns, const char *main_local_name, const char *main_ns);


extern void
xslt_bsort (caddr_t ** bs, int n_bufs, xslt_sort_t * specs);

extern void
xslt_qsort (caddr_t ** in, caddr_t ** left,
	    int n_in, int depth, xslt_sort_t * specs);


extern caddr_t
xpf_arg (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe,
	 dtp_t target_dtp, int n);

extern caddr_t
xpf_raw_arg (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe, int n);


extern void xpf_call_udf (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_cartesian_product_loop (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_ceiling (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_concat (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_false (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_floor (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_not (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_round_number (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_string (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_true (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_sum (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_normalize_space  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_translate  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_contains  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_name  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_local_name  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_namespace_uri  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_number  (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_unordered (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_union (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_is_before (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_is_after (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_except (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_intersect (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_id (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_doc (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_to_operator (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_position (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);
extern void xpf_last (xp_instance_t * xqi, XT * tree, xml_entity_t * ctx_xe);



extern XT * xpf_arg_tree (XT * tree, int n);
extern void xpf_arg_list_impl (xp_instance_t * xqi, XT * arg, xml_entity_t * ctx_xe, caddr_t *res);
#define xpf_arg_list(xqi,tree,ctx_xe,n,res) xpf_arg_list_impl ((xqi), xpf_arg_tree ((tree), (n)), (ctx_xe), (res))

extern void xpf_init(void);

extern xp_query_t *xqr_stub_for_funcall (xpf_metadata_t *metas, int argcount);

#endif /* _XPF_H */
