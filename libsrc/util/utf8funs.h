/*
 *  utf8funs.h
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2018 OpenLink Software
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

#ifndef _UTF8FUNS_H
#define _UTF8FUNS_H

BEGIN_CPLUSPLUS

#if !defined (_MTX_)
#if !defined (__APPLE__) || defined (HAVE_WCHAR_H)
#include <wchar.h>
#else
typedef unsigned int wint_t;
#endif
#endif

typedef struct
{
  int count;		/* Number of bytes needed for the current character. */
  wint_t value;		/* Value so far.  */
} virt_mbstate_t;

extern const wchar_t virt_utf8_encoding_mask[];
extern const unsigned char virt_utf8_encoding_byte[];
extern size_t virt_mbrlen (const char *s, size_t n, virt_mbstate_t *ps);
extern size_t virt_mbrlen_z (const char *s, size_t n, virt_mbstate_t *ps);
extern size_t virt_mbrtowc (wchar_t *pwc, const unsigned char *s, size_t n, virt_mbstate_t *ps);
extern size_t virt_mbrtowc_z (wchar_t *pwc, const unsigned char *s, size_t n, virt_mbstate_t *ps);
extern size_t virt_mbsnrtowcs (wchar_t *dst, const unsigned char **src, size_t nmc, size_t len, virt_mbstate_t *ps);
extern size_t virt_wcsnrtombs (unsigned char *dst, const wchar_t **src, size_t nwc, size_t len, virt_mbstate_t *ps);
extern size_t virt_wcrtomb (unsigned char *s, wchar_t wc, virt_mbstate_t *ps);
extern size_t virt_wcrtomb_z (unsigned char *s, wchar_t wc, virt_mbstate_t *ps);

#ifndef VIRT_MB_CUR_MAX
#define VIRT_MB_CUR_MAX 6
#endif

END_CPLUSPLUS

#endif
