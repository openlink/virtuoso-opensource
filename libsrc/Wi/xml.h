/*
 *  xml.h
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

#ifndef _XML_H
#define _XML_H

#ifdef BIF_XML

/* IvAn/ParseDTD/000721 system parser is wiped out, replaced with xmlparser.h
#include <xmlparse.h> */
#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser.h"
#ifdef __cplusplus
}
#endif

encoding_handler_t *intl_find_user_charset (const char *encname, int xml_input_is_wide);

/* Miscellaneous definition */
#define XML_VERSION		"1.0"

#define EID_MAX_WORDS		5
#define DELTA			8

/* Table names and columns names */
#ifdef OLD_VXML_TABLES
#define	TN_ENTITY		 "DB.DBA.VXML_ENTITY"
#define	TN_VXMLDOC		"DB.DBA.VXML_DOCUMENT"
#define	TN_TEXTFRAG		"DB.DBA.VXML_TEXT_FRAGMENT"
#define	IDX_URI			"URI"

#define	CN_ENT_ID		"E_ID"
#define	CN_ENT_NAME		"E_NAME"
#define CN_ENT_MISC		"E_MISC"
#define	CN_ENT_LEVEL		"E_LEVEL"
#define	CN_ENT_WSPACE		"E_WHITESPACE"
#define	CN_ENT_LEAD		 "E_LEADING"
#define	CN_ENT_TRAIL		"E_TRAILING"

#define	CN_VXML_DTD		"D_DTD"
#define	CN_VXML_URI		 "D_URI"

#define	CN_FRAG_SHORT		"V_SHORT"
#define	CN_FRAG_LONG		"V_LONG"
#endif

/* XML bif functions names */
#define XMLATTR			"xml_attr"
#define XMLATTRREPLAY		 "xml_attr_replay"
#define XMLSELEMENTTABLE	 "xmls_element_table"
#define XMLSELEMENTCOL		 "xmls_element_col"
#define XMLEID			 "xml_eid"
#define XMLSPROC		 "xmls_proc"
#define XMLROWVECT		 "row_vector"

#define PROLOG			"<?xml version=\"" XML_VERSION "\""

#define MAX_XML_STRING_LENGTH 0x9FFFF0L	/* 10 M2b - 16 */	/* IvAn/TextXmlIndex/000814 */

#define XML_CHAR_ESCAPE(c,s) xml_escapes [c] = s;

#ifndef __cplusplus
/* Types definition */
#ifndef _boolean
typedef enum
  {
    false, true
  }
_boolean;
#endif
#endif





typedef struct close_tag_s {
  int		ct_level;
  dk_set_t	ct_all_explicit_ns;
  dk_set_t	ct_all_default_ns;
  caddr_t	 ct_trailing;
  caddr_t	 ct_name;
  /*caddr_t 	ct_ns;
  int 		ct_start;*/
  struct close_tag_s *	 ct_prev;
} close_tag_t;

#define bx_std_ns_pref(name,ns_len) ((3 == ns_len) && !strnicmp (name, "xml", 3))
#define bx_std_ns_uri(name,ns_len) ((XML_NS_URI_LEN == ns_len) && !strnicmp (name, XML_NS_URI, XML_NS_URI_LEN))


void bx_push_ct (close_tag_t ** ct_ret, int e_level,  caddr_t e_name, caddr_t e_trailing);

typedef int (*xml_elm_serialize_t) (caddr_t * node, dk_session_t * ses, void * xsst);

/* XML bif functions prototypes */
struct xte_serialize_state_s
{
  struct xml_tree_ent_s *	xsst_entity;
  id_hash_t *		xsst_cdata_names; /* == xsst->xsst_entity->xe_doc.xtd->xout_cdata_section_elements*/
  xml_ns_2dict_t	xsst_ns_2dict; /* == xsst->xsst_entity->xe_doc.xtd->xd_ns_2dict */
  close_tag_t *		xsst_ct;
  caddr_t *		xsst_qst;
  int			xsst_out_method;
  struct wcharset_s *	xsst_charset;
  int			xsst_charset_meta;
  int			xsst_do_indent;
  int			xsst_indent_depth;
  int			xsst_in_block;
  int 			xsst_dks_esc_mode;
  int 			xsst_default_ns;
  xml_elm_serialize_t   xsst_hook;
  void *		xsst_data;
};

typedef struct xte_serialize_state_s xte_serialize_state_t;

extern void xte_serialize_1 (caddr_t * current, dk_session_t * ses, xte_serialize_state_t *xsst);

caddr_t bif_xml_eid (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xml_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xml_del (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xml_attr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xml_attr_replay (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xmls_element_table (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xmls_element_col (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xmls_proc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xml_to_tree (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_tree_to_xml (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

caddr_t bif_xml_attr (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xml_attr_replay (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xmls_element_table (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xmls_element_col (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xmls_proc (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t xml_make_tree (query_instance_t * qi, caddr_t text, caddr_t *err_ret, const char *enc, lang_handler_t *lh, struct dtd_s **ret_dtd);
caddr_t xml_make_tree_with_ns (query_instance_t * qi, caddr_t text, caddr_t *err_ret, const char *enc, lang_handler_t *lh, id_hash_t ** nss, id_hash_t ** id_cache);
void nss_free (id_hash_t * nss);
caddr_t xml_make_mod_tree (query_instance_t * qi, caddr_t text, caddr_t *err_ret, long mode, caddr_t uri, const char *enc, lang_handler_t *lh, caddr_t dtd_options, dtd_t **ret_dtd, id_hash_t **ret_id_cache, xml_ns_2dict_t *ret_ns_2dict);
void xml_expand_refs (caddr_t *tree, caddr_t *err_ret);
caddr_t bif_vt_index (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xmls_viewremove (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xml_view_dtd (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args); /* IvAn/ViewDTD/000718 Added */
caddr_t bif_xml_view_schema (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xml_auto (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xmlsql_update (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xml_template (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_xml_auto_dtd (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args); /* IvAn/AutoDTD/000919 Added */
caddr_t bif_xml_auto_schema (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args); /* IvAn/AutoDTD/000919 Added */

void xe_box_serialize (caddr_t xe, dk_session_t * ses);
extern void dtd_serialize (dtd_t * dtd, dk_session_t * ses);

/* Extern declarations */
extern query_t *insert_entity_qr;
extern query_t *insert_fragment_qr;
extern query_t *insert_document_qr;
extern query_t *select_entitylevel_qr;
extern query_t *delete_entity_qr;
extern query_t *select_countentity_qr;
extern query_t *select_maxentity_qr;
extern query_t *select_groupentity_qr;
extern query_t *select_elevel_qr;
extern struct xml_schema_s *xml_global;
extern const char *add_entity_with_param;
extern const char *xml_escapes[256];
#define OUT_METHOD_XML		1
#define OUT_METHOD_HTML		2
#define OUT_METHOD_TEXT		3
#define OUT_METHOD_XHTML	4
#define OUT_METHOD_OTHER	0

#define IS_HTML_OUT(o)		(OUT_METHOD_HTML == (o) || OUT_METHOD_XHTML == (o))

#define USE_HTML_XSL_ESCAPES	-1
#define USE_CDATA_XML_ESCAPES	-2
#define USE_CR_ESCAPE		-3 /* the CR is encoded, SOAP/interoperability  */
int dtd_insert_soft (dtd_t *tgt, dtd_t *src);
void ddl_store_mapping_schema (query_instance_t * qi, caddr_t view_name, caddr_t reload_text);
#endif /* BIF_XML */
#endif /* _XML_H */
