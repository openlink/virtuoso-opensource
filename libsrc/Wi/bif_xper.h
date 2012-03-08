/*
 *  bif_xper.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

#ifndef _BIF_XPER_H
#define _BIF_XPER_H

#include "sqlpar.h"
#include "xmltree.h"
#include "bif_text.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "langfunc.h"
#ifdef __cplusplus
}
#endif
#include "multibyte.h"

#define XPD_NEW		0
#define XPD_PERSISTENT	1

#define XML_MKUP_STAG		'['
#define XML_MKUP_ETAG		']'
#define XML_MKUP_COMMENT	'!'
#define XML_MKUP_PI		'?'
#define XML_MKUP_REF		'&'
#define XML_MKUP_TEXT		'T'

const char *xper_elements_vtb_feed (xper_entity_t *xpe, vt_batch_t *vtb, lh_word_callback_t *cbk, lang_handler_t *lh, caddr_t *textbufptr);
void xper_blob_vtb_feed (query_instance_t *qi, blob_handle_t *xper_blob, vt_batch_t *vtb, lh_word_callback_t *cbk, lang_handler_t *lh, caddr_t *textbufptr);
void xper_str_vtb_feed (query_instance_t *qi, caddr_t xper_str, vt_batch_t *vtb, lh_word_callback_t *cbk, lang_handler_t *lh, caddr_t *textbufptr);

extern xe_class_t xec_xper_xe;

/* bif_xper.c */
char *serialize_string (char *ptr, const char *s);
ptrlong find_ns (const char *ns, size_t len, dk_set_t *nss_ptr);
buffer_desc_t *get_blob_page_for_read (it_cursor_t *itc, xper_doc_t *xpd, unsigned n);
buffer_desc_t *get_blob_page_for_write (it_cursor_t *itc, xper_doc_t *xpd, unsigned n);
long get_long_in_blob (blob_handle_t *bh, query_instance_t *qi, long pos);
int xper_name_node_test (char *name, size_t len, caddr_t ns, XT *node);
int xper_node_test (xper_entity_t *xpe, long pos, XT *node);
size_t file_read (void *read_cd, char *buf, size_t bsize);
int str_looks_like_serialized_xml (caddr_t source);
int blob_looks_like_serialized_xml (query_instance_t *qi, blob_handle_t *bh);
int looks_like_serialized_xml (query_instance_t *qi, caddr_t source);

xper_entity_t *DBG_NAME(xper_entity) (DBG_PARAMS query_instance_t *qi, caddr_t source_arg, caddr_t vt_batch, int is_html, caddr_t path, caddr_t enc_name, lang_handler_t *lh, caddr_t dtd_config, int index_attrs);
xper_entity_t *DBG_NAME(xper_cut_xper) (DBG_PARAMS query_instance_t * volatile qi, xper_entity_t *src_xpe);
xml_entity_t *DBG_NAME(xp_copy) (DBG_PARAMS xml_entity_t *xe);
caddr_t DBG_NAME(xper_get_namespace) (DBG_PARAMS xper_entity_t *xpe, long pos);
#ifdef MALLOC_DEBUG
#define xper_entity(QI,SRC,VTB,ISHTML,PATH,ENC,LH,DTDCFG,IDXATTR) \
  dbg_xper_entity(__FILE__,__LINE__,(QI),(SRC),(VTB),(ISHTML),(PATH),(ENC),(LH),(DTDCFG),(IDXATTR))
#define xper_cut_xper(QI,SRC) dbg_xper_cut_xper(__FILE__,__LINE__,(QI),(SRC))
#define xp_copy(XE) dbg_xp_copy(__FILE__,__LINE__,(XE))
#define xper_get_namespace(XPE,P) dbg_xper_get_namespace(__FILE__,__LINE__,(XPE),(P));
#endif

void xp_destroy (xml_entity_t * xe);
void write_escaped (dk_session_t *ses, unsigned char *ptr, int len, wcharset_t *charset);
void write_escaped_comment (dk_session_t *ses, unsigned char *ptr, int len, wcharset_t *charset);
void write_escaped_attvalue (dk_session_t * ses, unsigned char *ptr, int len, wcharset_t *charset);
void xp_string_value (xml_entity_t *xe, caddr_t *ret, dtp_t dtp);
void xp_log_update (xml_entity_t *xe, dk_session_t *log);
void bif_xper_init (void);
void dtd_serialize (dtd_t * dtd, dk_session_t * ses);

#endif /* _BIF_XPER_H */

