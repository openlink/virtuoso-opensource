/*
 *  gate_virtuoso_stubs.c
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

#include <stdlib.h>
#include "langfunc.h"

unichar eh_decode_char__UTF7 (__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{ return ((long *)-1)[0] += 1; }

int eh_decode_buffer__UTF7 (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{ return ((long *)-1)[0] += 1; }

int eh_decode_buffer_to_wchar__UTF7 (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{ return ((long *)-1)[0] += 1; }

char *eh_encode_char__UTF7 (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{ ((long *)-1)[0] += 1; return NULL; }

char *eh_encode_buffer__UTF7 (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{ ((long *)-1)[0] += 1; return NULL; }

char *eh_encode_wchar_buffer__UTF7 (const wchar_t *src_buf, const wchar_t *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{ ((long *)-1)[0] += 1; return NULL; }

#if 0
void	dbg_malloc_enable (void) { /* nop */; };
void *	dbg_malloc (const char *file, u_int line, size_t size) { return malloc (size); }
void *	dbg_calloc (const char *file, u_int line, size_t num, size_t size) { return calloc (num, size); }
void	dbg_free (const char *file, u_int line, void *data) { free (data); }
char *	dbg_strdup (const char *file, u_int line, const char *str) { return strdup (str); }
#endif

#if 0
#ifdef thread_create
#undef thread_create
thread_t *OPL_thread_create (thread_init_func init, unsigned long stack_size, void *init_arg)
{
  return thread_create (init, stack_size, init_arg);
}
#endif
#endif
