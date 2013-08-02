/*
 *  lisprdr.h
 *
 *  $Id$
 *
 *  Lisp Reader
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

#ifndef _LISPRDR_H
#define _LISPRDR_H

#ifndef _DK_H
#include "Dk.h"
#endif

typedef struct lisp_stream_s
  {
    char		ls_unread;
    const char *	ls_buffer;
    int			ls_at;
    int			ls_length;
  } lisp_stream_t;

typedef caddr_t (*mcfunc_t) (lisp_stream_t * stream, char character);


#define MAX_TOKEN		50
#define CLOSE_PAR_MARKER	-1

#define OBJ_COMMENT		((caddr_t) -1L)
#define OBJ_CLOSE_PAR		((caddr_t) -2L)

#define CATCH_LISP_ERROR	102

#undef CATCH
#define CATCH_T(ct, thr) \
{ \
   du_thread_t * cur_thread = thr; \
   int reset_code;  \
   int old_ct = ct; \
   void * old_ctx = THR_ATTR (cur_thread, ct); \
   jmp_buf_splice ctx;  \
   SET_THR_ATTR (cur_thread, ct, & ctx); \
   if (0 == (reset_code = setjmp_splice (& ctx)))

#define CATCH(ct)	CATCH_T (ct, THREAD_CURRENT_THREAD)

#define THROW_CODE \
  else

#define END_CATCH \
  SET_THR_ATTR (cur_thread, old_ct, old_ctx); \
}

#define POP_CATCH \
  SET_THR_ATTR (cur_thread, old_ct, old_ctx);

#define THR_ERROR	12

#define THR_GET_ERROR \
  THR_ATTR (THREAD_CURRENT_THREAD, THR_ERROR)

#define LIST_MAX_LEN	100

#define INTEGERP(x) \
  (! IS_BOX_POINTER (x) || DV_LONG_INT == box_tag (x))


dtp_t lisp_type_of (caddr_t xx);
caddr_t lisp_read (lisp_stream_t *);
void lisp_error (char *, ...);
void init_lisp_stream (lisp_stream_t * str, char * nts);
void lisp_throw (int ctx, int code);
void lisp_throw_thr (int ctx, int code, du_thread_t * thr);
void lisp_stream_init (lisp_stream_t * ls, const char *buf);
void box_tree_check (caddr_t tree);

#endif /* _LISPRDR_H */
