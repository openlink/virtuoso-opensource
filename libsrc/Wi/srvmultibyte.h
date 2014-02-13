/*
 *  srvmultibyte.h
 *
 *  $Id$
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

#ifndef _SRVMULTIBYTE_H
#define _SRVMULTIBYTE_H

#include "multibyte.h"

void row_print_wide (caddr_t thing, dk_session_t * ses, dbe_column_t * col,
    caddr_t * err_ret, dtp_t dtp, wcharset_t *wcharset);
dk_set_t bh_string_list_w (/* this was before 3.0: index_space_t * isp, */ lock_trx_t * lt, blob_handle_t * bh,
    long get_chars, int omit); /* if omit!=0, it just run through blob part */
dk_session_t *bh_string_output_w (/* this was before 3.0: index_space_t * isp, */ lock_trx_t * lt, blob_handle_t * bh, int omit); /* if omit!=0, it just run through blob part */
int compare_wide_to_utf8 (caddr_t utf8_data, long utf8_len, caddr_t wide_data, long wide_len, collation_t *collation);
int compare_utf8_with_collation (caddr_t dv1, long n1, caddr_t dv2, long n2, collation_t *collation);

caddr_t box_wide_char_string (caddr_t data, size_t len, dtp_t dtp);

caddr_t box_narrow_string_as_wide (unsigned char *str, caddr_t wide, long max_len, wcharset_t *charset, caddr_t * err_ret, int isbox);
caddr_t box_wide_string_as_narrow (caddr_t str, caddr_t narrow, long max_len, wcharset_t *charset);
caddr_t box_utf8_string_as_narrow (ccaddr_t _str, caddr_t narrow, long max_len, wcharset_t *charset);
caddr_t t_box_utf8_string_as_narrow (ccaddr_t _str, caddr_t narrow, long max_len, wcharset_t *charset);
caddr_t DBG_NAME (box_narrow_string_as_utf8) (DBG_PARAMS caddr_t _str, caddr_t narrow, long max_len, wcharset_t *charset, caddr_t * err_ret, int isbox);
#ifdef MALLOC_DEBUG
#define box_narrow_string_as_utf8(s,n,m,c,e,i) dbg_box_narrow_string_as_utf8 (__FILE__, __LINE__, (s), (n), (m), (c), (e), (i))
#endif
int parse_wide_string_literal (unsigned char **str_ptr, caddr_t box, wcharset_t *charset);

extern id_hash_t * global_wide_charsets;
extern wcharset_t * default_charset;
extern caddr_t default_charset_name;

caddr_t complete_charset_name (caddr_t qi, char *cs_name);

int compare_wide_to_narrow (wchar_t *wbox1, long n1, unsigned char *box2, long n2);

extern wcharset_t *sch_name_to_charset (const char *name);
extern wcharset_t * wcharset_by_name_or_dflt (ccaddr_t cs_name, query_instance_t *qi);

wchar_t * reverse_wide_string (wchar_t * str);
caddr_t strstr_utf8_with_collation (caddr_t dv1, long n1,
	    caddr_t dv2, long n2, caddr_t *next, collation_t *collation);

struct encoding_handler_s;
extern caddr_t charset_recode_from_named_to_named (caddr_t narrow, const char *cs1_uppercase, const char *cs2_uppercase, int *res_is_new_ret, caddr_t *err_ret);
extern caddr_t charset_recode_from_cs_or_eh_to_cs (caddr_t narrow, int bom_skip_offset, struct encoding_handler_s *eh_cs1, wcharset_t *cs1, wcharset_t *cs2, int *res_is_new_ret, caddr_t *err_ret);

#endif /* _SRVMULTIBYTE_H */
