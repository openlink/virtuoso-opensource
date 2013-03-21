/*
 *  multibyte.h
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

#ifndef __MULTIBYTE_H
#define __MULTIBYTE_H

#include "libutil.h"

#ifndef UTF8CHAR_DEFINED
#define UTF8CHAR_DEFINED
typedef unsigned char utf8char;
#endif

typedef struct wcharset_s {
  char chrs_name[100];
  wchar_t chrs_table[256];
  dk_hash_t *chrs_ht;
  caddr_t *chrs_aliases;
} wcharset_t;

#define CHARSET_UTF8	(((wcharset_t *)NULL)+1)
#define CHARSET_WIDE	(((wcharset_t *)NULL)+2) /* not supported in many places, use only after double-check! */

#define CHARSET_NAME(c,d) ((char *) (c != NULL ? \
    (((wcharset_t *)c) != CHARSET_UTF8 ? ((wcharset_t *)c)->chrs_name : "UTF-8") : d))

/* size_t virt_mbsrtowcs (wchar_t *dst, unsigned char **src, size_t len, virt_mbstate_t *ps);
size_t virt_wcsrtombs (unsigned char *dst, wchar_t **src, size_t len, virt_mbstate_t *ps); */

wchar_t *virt_wcschr (const wchar_t *__wcs, wchar_t __wc);
wchar_t *virt_wcsrchr (const wchar_t *__wcs, wchar_t __wc);
wchar_t *virt_wcsstr (const wchar_t *__wcs, const wchar_t *__wc);
wchar_t *virt_wcsrstr (const wchar_t *__wcs, const wchar_t *__wc);
size_t virt_wcslen (const wchar_t *__wcs);
int virt_wcsncmp (const wchar_t *from, const wchar_t *to, size_t len);

caddr_t box_utf8_as_wide_char (ccaddr_t _utf8, caddr_t _wide_dest, size_t utf8_len, size_t max_wide_len, dtp_t dtp);
caddr_t t_box_utf8_as_wide_char (ccaddr_t _utf8, caddr_t _wide_dest, size_t utf8_len, size_t max_wide_len, dtp_t dtp);
extern caddr_t DBG_NAME (box_wide_as_utf8_char) (DBG_PARAMS ccaddr_t _wide, size_t wide_len, dtp_t dtp);
#ifdef MALLOC_DEBUG
#define box_wide_as_utf8_char(w,l,d) dbg_box_wide_as_utf8_char (__FILE__,__LINE__,(w),(l),(d))
#endif
extern caddr_t mp_box_wide_as_utf8_char (mem_pool_t * mp, ccaddr_t _wide, size_t wide_len, dtp_t dtp);
wchar_t CHAR_TO_WCHAR (unsigned char uchar, wcharset_t *charset);
unsigned char WCHAR_TO_CHAR (wchar_t wchar, wcharset_t *charset);

int wide_serialize (caddr_t wide_data, dk_session_t *ses);
void *box_read_wide_string (dk_session_t *ses, dtp_t macro);
void *box_read_long_wide_string (dk_session_t *ses, dtp_t macro);
int wide_atoi (caddr_t data);

wchar_t *virt_wcsdup(const wchar_t *s);
int virt_wcscasecmp(const wchar_t *s1, const wchar_t *s2);

/* long blob_fill_buffer_from_wide_string (caddr_t bh, caddr_t buf, int *at_end, long *char_len); moved to blob.c as static and excluded */
size_t wide_char_length_of_utf8_string (const unsigned char *str, size_t utf8_length);

struct query_instance_s;
extern wcharset_t *wcharset_by_name_or_dflt (ccaddr_t cs_name, struct query_instance_s *qi);

wcharset_t * wide_charset_create (char *name, wchar_t *table, int nelems, caddr_t *chrs_aliases);
void wide_charset_free (wcharset_t *charset);

size_t cli_wide_to_narrow (wcharset_t * charset, int flags, const wchar_t *src, size_t max_wides,
    unsigned char *dest, size_t max_len, char *default_char, int *default_used);
size_t cli_narrow_to_wide (wcharset_t *charset, int flags, const unsigned char *src, size_t max_wides,
    wchar_t *dest, size_t max_len);
size_t cli_wide_to_escaped (wcharset_t *charset, int flags, const wchar_t *src, size_t max_wides,
    unsigned char *dest, size_t max_len, char *default_char, int *default_used);

char *cli_box_wide_to_narrow (const wchar_t * in);
wchar_t *cli_box_narrow_to_wide (const char * in);

size_t cli_utf8_to_narrow (wcharset_t *charset, const unsigned char *str, size_t max_len, unsigned char *dst, size_t max_narrows);
size_t cli_narrow_to_utf8 (wcharset_t *charset, const unsigned char *_str, size_t max_narrows, unsigned char *dst, size_t max_utf8);
wcharset_t *sch_name_to_charset (const char *name);

size_t wide_as_utf8_len (caddr_t _wide);
caddr_t box_wide_string (const wchar_t *wstr);
caddr_t box_wide_nchars (const wchar_t *wstr, size_t len);

extern wcharset_t *charset_native_for_box (ccaddr_t box, int expected_bf_if_zero);


#ifdef UTF8_DEBUG
#define ASSERT_BOX_ENC_MATCHES_BF(box,expected_bf_if_zero) assert_box_enc_matches_bf (__FILE__, __LINE__, (box), (expected_bf_if_zero))
#define ASSERT_BOX_UTF8(box) assert_box_utf8 (__FILE__, __LINE__, (box))
#define ASSERT_BOX_8BIT(box) assert_box_8bit (__FILE__, __LINE__, (box))
#define ASSERT_BOX_WCHAR(box) assert_box_wchar (__FILE__, __LINE__, (box))
#define ASSERT_NCHARS_UTF8(buf,len) assert_nchars_utf8 (__FILE__, __LINE__, (buf), (len))
#define ASSERT_NCHARS_8BIT(buf,len) assert_nchars_8bit (__FILE__, __LINE__, (buf), (len))
#define ASSERT_NCHARS_WCHAR(buf,len) assert_nchars_wchar (__FILE__, __LINE__, (buf), (len))
extern void assert_box_enc_matches_bf (const char *file, int line, ccaddr_t box, int expected_bf_if_zero);
extern void assert_box_utf8 (const char *file, int line, caddr_t box);
extern void assert_box_8bit (const char *file, int line, caddr_t box);
extern void assert_box_wchar (const char *file, int line, caddr_t box);
extern void assert_nchars_utf8 (const char *file, int line, const char *buf, size_t len);
extern void assert_nchars_8bit (const char *file, int line, const char *buf, size_t len);
extern void assert_nchars_wchar (const char *file, int line, const char *buf, size_t len);
#else
#define ASSERT_BOX_ENC_MATCHES_BF(box,expected_bf_if_zero)
#define ASSERT_BOX_UTF8(box)
#define ASSERT_BOX_8BIT(box)
#define ASSERT_BOX_WCHAR(box)
#define ASSERT_NCHARS_UTF8(buf,size)
#define ASSERT_NCHARS_8BIT(buf,size)
#define ASSERT_NCHARS_WCHAR(buf,size)
#endif
#endif /* _MULTIBYTE_H */
