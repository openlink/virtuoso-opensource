/*
 *  lisprdr.c
 *
 *  $Id$
 *
 *  Reader for lisp expressions
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

#include "wi.h"
#include "lisprdr.h"


mcfunc_t macro_chars[256];


int
lisp_read_char (lisp_stream_t * str)
{
  if (str->ls_unread)
    {
      char tmp = str->ls_unread;
      str->ls_unread = 0;
      return tmp;
    };
  if (str->ls_at >= str->ls_length)
    return -1;
  return (str->ls_buffer[str->ls_at++]);
}


void
lisp_unread_char (lisp_stream_t * str, char ch)
{
  str->ls_unread = ch;
}

#define CST_CONSTITUENT 0L
#define CST_WHITESPACE  1L

caddr_t interpret_token (char *token, int length);


caddr_t
lisp_read (lisp_stream_t * stream)
{
  char token[MAX_TOKEN];
  int token_fill = 0;
  mcfunc_t macro_func;
  for (;;)
    {
      int ich = lisp_read_char (stream);
      if (-1 == ich)
	{
	  if (token_fill)
	    return interpret_token (token, token_fill);
	  else
	    return box_num (-1L);
	};
      macro_func = macro_chars[ich];
      if (macro_func == (mcfunc_t) CST_CONSTITUENT)
	{
	  token[token_fill++] = (char) ich;
	  continue;
	}
      if (macro_func == (mcfunc_t) CST_WHITESPACE)
	{
	  if (token_fill)
	    return (interpret_token (token, token_fill));
	  continue;
	}

      if (!token_fill)
	{
	  caddr_t res = macro_func (stream, (char) ich);
	  if (res == OBJ_COMMENT)
	    continue;
	  return res;
	}
      else
	{
	  lisp_unread_char (stream, (char) ich);
	  return (interpret_token (token, token_fill));
	}
    }
/*  GPF_T;	*/		/* Can't pass through here */
}


caddr_t
interpret_token (char *token, int length)
{
  long l_tmp;
  float f_tmp;
  caddr_t sym_tmp;
  token[length] = 0;

  if (1 == sscanf (token, "%ld", &l_tmp))
    {
      return (box_num (l_tmp));
    }
  if (1 == sscanf (token, "%f", &f_tmp)
      && !strstr (token, "INF"))
    {
      return (box_float (f_tmp));
    }
  sym_tmp = dk_alloc_box (length + 1, DV_SYMBOL);
  memcpy (sym_tmp, token, length + 1);
  return sym_tmp;
}


caddr_t
list_reader (lisp_stream_t * stream, char ch)
{
  caddr_t elems[LIST_MAX_LEN];
  int fill = 0;
  while (1)
    {
      caddr_t thing = lisp_read (stream);
      if (thing == OBJ_CLOSE_PAR)
	{
	  caddr_t res = dk_alloc_box (fill * sizeof (caddr_t),
				      DV_ARRAY_OF_POINTER);
	  memcpy (res, elems, fill * sizeof (caddr_t));
	  return res;
	};
      elems[fill++] = thing;
      if (fill >= LIST_MAX_LEN)
	lisp_error ("list_reader: list too long");
    }
}


caddr_t
close_par_reader (lisp_stream_t * stream, char ch)
{
  return (OBJ_CLOSE_PAR);
}

#define STRING_MAX_CHARS 1000

caddr_t
string_reader (lisp_stream_t * stream, char ch)
{
  char buf[STRING_MAX_CHARS];
  int ich;
  int fill = 0;
  while (1)
    {
      ich = lisp_read_char (stream);
      if (ich == '"')
	{
	  char *str = dk_alloc_box (fill + 1, DV_LONG_STRING);
	  memcpy (str, buf, fill);
	  str[fill] = 0;
	  return str;
	}
      buf[fill++] = (char) ich;
      if (fill >= STRING_MAX_CHARS)
	lisp_error ("string_reader: string too long");
    }
}


dtp_t
lisp_type_of (caddr_t xx)
{
  if (!xx)
    return DV_NULL;
  if (IS_BOX_POINTER (xx))
    return (box_tag (xx));
  else
    return DV_LONG_INT;
}


void
init_lisp_stream (lisp_stream_t * str, char *nts)
{
  str->ls_at = 0;
  str->ls_buffer = nts;
  str->ls_length = (int) strlen (nts);
  str->ls_unread = 0;
}


void
lisp_throw (int ctx, int code)
{
  jmp_buf_splice *j = (jmp_buf_splice *) THR_ATTR (THREAD_CURRENT_THREAD, ctx);
  if (NULL == j)	/* IvAn/CreateXmlView/000904 Bug fixed: if(!ctx) is wrong */
#if 1 /* GK : otherwise that's an endless loop */
    GPF_T1 ("lisp_throw: no catcher");
#else
    lisp_error ("lisp_throw: no catcher for %d", ctx);
#endif
  longjmp_splice (j, code);
}


void
lisp_throw_thr (int ctx, int code, du_thread_t * thr)
{
  jmp_buf_splice *j = (jmp_buf_splice *) THR_ATTR (thr, ctx);
#ifndef NDEBUG
  if (thr != THREAD_CURRENT_THREAD)
    GPF_T1 ("Bad thread in lisp_throw_thr");
#endif
  if (NULL == j)	/* IvAn/CreateXmlView/000904 Bug fixed: if(!ctx) is wrong */
#if 1 /* GK : otherwise that's an endless loop */
    GPF_T1 ("lisp_throw_thr: no catcher");
#else
    lisp_error ("lisp_throw_thr: no catcher for %d", ctx);
#endif
  longjmp_splice (j, code);
}


void
lisp_error (char *str, ...)
{
  char buf[100];
  va_list list;

  va_start (list, str);
  vsnprintf (buf, sizeof (buf), str, list);
  log_error (buf);
  va_end (list);
  lisp_throw (CATCH_LISP_ERROR, 0);
}


void
lisp_reader_init (void)
{
  static int is_inited = 0;
  if (!is_inited)
    {
      int inx;
      for (inx = 0; inx < 256; inx++)
	macro_chars[inx] = (mcfunc_t) CST_CONSTITUENT;
      is_inited = 1;
      macro_chars[' '] = (mcfunc_t) CST_WHITESPACE;
      macro_chars[9] = (mcfunc_t) CST_WHITESPACE;
      macro_chars[10] = (mcfunc_t) CST_WHITESPACE;
      macro_chars[12] = (mcfunc_t) CST_WHITESPACE;
      macro_chars[13] = (mcfunc_t) CST_WHITESPACE;

      macro_chars['('] = (mcfunc_t) list_reader;
      macro_chars['"'] = (mcfunc_t) string_reader;
      macro_chars[')'] = (mcfunc_t) close_par_reader;
    }
}


void
lisp_stream_init (lisp_stream_t * ls, const char *buf)
{
  lisp_reader_init ();
  ls->ls_unread = 0;
  ls->ls_buffer = buf;
  ls->ls_length = (int) strlen (buf);
  ls->ls_at = 0;
}


#if 1

#define TREE_MAX 10000

caddr_t tree_map[TREE_MAX];
int tree_fill;

void dbg_print_box (caddr_t object, FILE * out);


int
box_tree_check_1 (caddr_t tree, int print)
{
  int inx;
  if (!IS_BOX_POINTER (tree))
    {
      if (print)
	dbg_print_box (tree, stdout);
      return 0;
    }
  for (inx = 0; inx < tree_fill; inx++)
    {
      if (tree_map[inx] == tree)
	{
	  if (print)
	    GPF_T1 ("Tree has a cycle");
	  else
	    return -1;
	}
    }
  if (tree_fill < TREE_MAX)
    tree_map[tree_fill++] = tree;
#if 0
  dk_alloc_box_assert (tree);
#endif
  if (print)
    printf (" %d= ", tree_fill - 1);
  if (IS_NONLEAF_DTP(box_tag (tree)))
    {
      if (print)
	printf ("(");
      DO_BOX (caddr_t, elt, inx, ((caddr_t *) tree))
      {
	if (-1 == box_tree_check_1 (elt, print))
	  return -1;
      }
      END_DO_BOX;
      if (print)
	printf (")");
    }
  else
    {
      if (print)
	dbg_print_box (tree, stdout);
    }
  return 0;
}


void
box_tree_check (caddr_t tree)
{
  tree_fill = 0;
  if (-1 == box_tree_check_1 (tree, 0))
    {
      tree_fill = 0;
      box_tree_check_1 (tree, 1);
    }
  if (tree_fill >= TREE_MAX)
    GPF_T1 ("Tree cycle check overflow");
}
#endif

