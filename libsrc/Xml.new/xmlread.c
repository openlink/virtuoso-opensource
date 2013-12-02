/*
 *  xmlread.c
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

#include "xmlparser_impl.h"

#include <stdio.h>
#include "xml_ecm.h"


#ifdef DEBUG
#define DESCR(x) (x)
#else
#define DESCR(x) NULL
#endif
#include "xhtml_ent.h"

#ifdef UNIT_DEBUG
#define xml_dbg_printf(a) printf a
#else
#define xml_dbg_printf(a)
#endif

#define VXML_CHARPROP_CTRL		((unsigned char)('A'^'@'))	/*0x01*/
#define VXML_CHARPROP_SPACE		((unsigned char)('B'^'@'))	/*0x02*/
#define VXML_CHARPROP_TEXTEND		((unsigned char)('D'^'@'))	/*0x04*/
#define VXML_CHARPROP_ATTREND		((unsigned char)('H'^'@'))	/*0x08*/
#define VXML_CHARPROP_ENTBEGIN		((unsigned char)('P'^'@'))	/*0x10*/
#define VXML_CHARPROP_ELTEND		((unsigned char)('`'^'@'))	/*0x20*/
#define VXML_CHARPROP_8BIT		((unsigned char)(0x80))		/*0x80*/
#define VXML_CHARPROP_ANY_SPECIAL	((unsigned char)(~'@'))		/*0xcf*/
#define VXML_CHARPROP_ANY_NONCHAR	((unsigned char)(~0))		/*0xff*/

#define V8B VXML_CHARPROP_8BIT

unsigned char vxml_char_props [0x100] = {
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  'B','@','@','@','@','@','@','@','@','B','C','@','@','C','@','@',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  '@','@','@','@','@','@','@','@','@','@','@','@','@','@','@','@',
/*     !   "   #   $   %   &   '   (   )   *   +   ,   -   .   /  */
  'B','@','H','@','@','P','P','H','@','@','@','@','@','@','@','@',
/* 0   1   2   3   4   5   6   7   8   9   :   ;   <   =   >   ?  */
  '@','@','@','@','@','@','@','@','@','@','@','@','D','@','`','@',
/* @   A   B   C   D   E   F   G   H   I   J   K   L   M   N   O  */
  '@', 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 ,
/* P   Q   R   S   T   U   V   W   X   Y   Z   [   \   ]   ^   _  */
   0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 ,'@','@','D','@','@',
/* `   a   b   c   d   e   f   g   h   i   j   k   l   m   n   o  */
  '@', 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 ,
/* p   q   r   s   t   u   v   w   x   y   z   {   |   }   ~  \x7f*/
   0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 , 0 ,'@','@','@','@','@',
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,
/* 0   1   2   3   4   5   6   7   8   9   A   B   C   D   E   F  */
  V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B,V8B };

#ifndef NO_validate_parser_bricks
static int validate_brick (brick_t *brk)
{
  int err;
  if (brk->beg > brk->end) { err = -101; goto error; }
  if (0 > brk->data_refctr) { err = -102; goto error; }
  if ((NULL != brk->next) && (brk != brk->next->prev)) { err = -103; goto error; }
  if ((NULL != brk->prev) && (brk != brk->prev->next)) { err = -104; goto error; }
  if ((0 > brk->beg_pos.line_num) || (0 > brk->beg_pos.col_c_num)) { err = -105; goto error; }
  if ((NULL != brk->data_owner) && (NULL != brk->data_begin)) { err = -106; goto error; }
  return 0;
error:
  return err;
}

static int validate_buf_ptr (buf_ptr_t *ptr)
{
  int err;
  if (ptr->ptr < ptr->buf->beg) { err = -201; goto error; }
  if (ptr->ptr > ptr->buf->end) { err = -202; goto error; }
  if (validate_brick (ptr->buf)) { err = -203; goto error; }
  return 0;
error:
  return err;
}

int validate_parser_bricks (vxml_parser_t * parser)
{
  brick_t *curr = parser->eptr.buf;
  if (validate_buf_ptr (&(parser->bptr))) goto error;
  if (validate_buf_ptr (&(parser->eptr))) goto error;
  if (validate_buf_ptr (&(parser->pptr))) goto error;
  if (validate_buf_ptr (&(parser->curr_pos_ptr))) goto error;
  if (NULL != curr->next) goto error;
  while (NULL != curr)
    {
      if (validate_brick(curr)) goto error;
      curr = curr->prev;
    }
  return 0;
error:
  return -1;
}
#endif

#if 0
unichar get_many_plain_tok_chars (vxml_parser_t * parser, utf8char **tgtbuf_tail_ptr, utf8char *tgtbuf_end, unsigned char stop_at)
{
#ifdef DEBUG
  if (0 == parser->src_eh->eh_stable_ascii7)
    GPF_T;
  if (!(stop_at & VXML_CHARPROP_8BIT))
    GPF_T;
#endif
  tgtbuf_end -= (MAX_UTF8_CHAR+1); /* This is to  */
  if (parser->static_src_tail < parser->static_src_end)
    {
      do {
          utf8char c;
          if (tgtbuf_tail_ptr [0] >= tgtbuf_end)
            goto end_of_tgtbuf_fill;
          c = parser->static_src_tail[0];
          if (vxml_char_props [c] & stop_at)
            goto end_of_tgtbuf_fill;
          ((tgtbuf_tail_ptr[0])++)[0] = c;
          parser->static_src_tail++;
        } while (parser->static_src_tail < parser->static_src_end);
      goto end_of_tgtbuf_fill;
    }
  if (parser->feeder == NULL)
    return UNICHAR_EOD;
  while (parser->feed_tail < parser->feed_end)
    {
      utf8char c;
      if (tgtbuf_tail_ptr [0] >= tgtbuf_end)
        goto end_of_tgtbuf_fill;
      c = parser->feed_tail[0];
      if (vxml_char_props [c] & stop_at)
        goto end_of_tgtbuf_fill;
      ((tgtbuf_tail_ptr[0])++)[0] = c;
      parser->feed_tail++;
    }

end_of_tgtbuf_fill:
  return get_tok_char (parser);
}
#endif

/*
 * It will call a function for getting next parts of a document,
 * if it is available.
 */
unichar
get_one_xml_char (vxml_parser_t * parser)
{
  unichar c;

  if (parser->static_src_tail < parser->static_src_end)
    {
      c = parser->src_eh->eh_decode_char ((__constcharptr *)(&(parser->static_src_tail)), parser->static_src_end, parser->src_eh, &(parser->src_eh_state));
      if (c >= 0)
        goto ok;
      if ((UNICHAR_NO_DATA == c) && (parser->feeder != NULL))
        {
          parser->feed_end = parser->static_src_end;
          parser->feed_tail = parser->static_src_tail; /* This will cause non-zero moved_len and proper memove, se below */
        }
      else
        goto fail;
    }
  if (parser->feeder == NULL)
    return UNICHAR_EOD;
  c = UNICHAR_EOD;
  for (;;)
    {
#ifdef DEBUG
      if (parser->feed_buf > parser->feed_tail)
	GPF_T;
      if (parser->feed_tail > parser->feed_end)
	GPF_T;
      if (parser->feed_end > parser->feed_buf + parser->feed_buf_size)
	GPF_T;
#endif
      if (parser->feed_tail < parser->feed_end)
	{
	  c = parser->src_eh->eh_decode_char ((__constcharptr *)(&(parser->feed_tail)), parser->feed_end, parser->src_eh, &(parser->src_eh_state));
	  if (c >= 0)
            goto ok;
	  if (UNICHAR_NO_DATA != c)
	    goto fail;
	}
      do
	{
	  size_t moved_len = parser->feed_end - parser->feed_tail;
	  size_t feed_result;
	  char *put_begin;
	  if (moved_len)
	    memmove (parser->feed_buf, parser->feed_tail, moved_len);
	  parser->feed_end = put_begin = parser->feed_buf + moved_len;
	  parser->feed_tail = parser->feed_buf;
#ifdef DEBUG
      if (parser->feed_buf > parser->feed_tail)
	GPF_T;
      if (parser->feed_tail > parser->feed_end)
	GPF_T;
      if (parser->feed_end > parser->feed_buf + parser->feed_buf_size)
	GPF_T;
#endif
	  feed_result = parser->feeder (parser->read_cd, put_begin, parser->feed_buf + parser->feed_buf_size - put_begin);
	  if (0 >= feed_result)
	    goto fail;
	  parser->input_weight += 1 + (feed_result / 16);
	  parser->input_cost += 5 + (feed_result / 16);
	  parser->feed_end += feed_result;
#ifdef DEBUG
      if (parser->feed_buf > parser->feed_tail)
	GPF_T;
      if (parser->feed_tail > parser->feed_end)
	GPF_T;
      if (parser->feed_end > parser->feed_buf + parser->feed_buf_size)
	GPF_T;
#endif
	} while (0);
    }

ok:
  return c;

fail:
  switch (c)
    {
    case UNICHAR_NO_DATA:
      {
        const char *chk;
        for (chk = parser->feed_tail; chk < parser->feed_end; chk++)          
          if ('\0' != chk[0])
            {
	      xmlparser_logprintf (parser, XCFG_NOLOGPLACE | XCFG_FATAL, 100, "Text of source document is truncated: partial encoding sequence at the end of its text");	      
	      break;
	    }
	return UNICHAR_EOD;
      }
    case UNICHAR_BAD_ENCODING:
      xmlparser_logprintf (parser, XCFG_NOLOGPLACE | XCFG_FATAL, 100, "Text of source document contains encoding error");
      break;
    }
  return c;
}

void
add_buf (vxml_parser_t * parser)
{
  brick_t *buf = parser->eptr.buf;

  buf->next = dk_alloc (sizeof (brick_t));
  buf->next->prev = buf;
  buf = buf->next;
  buf->next = NULL;
  buf->beg = buf->data_begin = dk_alloc_box (BRICK_SIZE+1, DV_STRING);
  buf->beg[BRICK_SIZE] = 0;
  buf->end = buf->beg + BRICK_SIZE;
  buf->data_owner = NULL;
  buf->data_refctr = 0;
  if (parser->cfg.uri == parser->curr_pos.origin_uri)
    xml_pos_set (&(parser->last_main_pos), &(parser->curr_pos));
  xml_pos_set (&(buf->beg_pos), &(parser->last_main_pos));

#ifdef UNIT_DEBUG
  printf ("Adding a buffer element.\n");
#endif
}

/*GK: especially questionable 64bit portability */
int
ptr_diff (buf_ptr_t p1, buf_ptr_t p2)
{
  int diff;
  buf_ptr_t tmp;

  for (diff = 0, tmp = p1; tmp.buf; tmp.buf = tmp.buf->prev, tmp.ptr = tmp.buf->end)
    {
      if (tmp.buf == p2.buf)
	return ((int) (tmp.ptr - p2.ptr + diff));

      diff += (int) (tmp.ptr - tmp.buf->beg);
    }

  for (diff = 0, tmp = p2; tmp.buf; tmp.buf = tmp.buf->prev, tmp.ptr = tmp.buf->end)
    {
      if (tmp.buf == p1.buf)
	return (int) (p1.ptr - tmp.ptr - diff);

      diff += (int) (tmp.ptr - tmp.buf->beg);
    }

  return INT_MIN;
}

void
DBG_NAME(brcpy) (DBG_PARAMS lenmem_t * to, buf_range_t * from)
{
  buf_ptr_t ptr;
  char * bp;
  size_t sz;

  for (sz = 0, ptr = from->beg;
       ptr.buf;
       ptr.buf = ptr.buf->next, ptr.ptr = ptr.buf->beg)
    {
      if (from->end.buf == ptr.buf)
	{
	  sz += from->end.ptr - ptr.ptr;
	  break;
	}
      sz += ptr.buf->end - ptr.ptr;
    }

  to->lm_length = sz;
  bp = to->lm_memblock = DBG_NAME(dk_alloc_box) (DBG_ARGS to->lm_length + 1, DV_STRING);

  for (ptr = from->beg;
       ptr.buf;
       ptr.buf = ptr.buf->next, ptr.ptr = ptr.buf->beg)
    {
      if (from->end.buf == ptr.buf)
	{
	  memcpy (bp, ptr.ptr, from->end.ptr - ptr.ptr);
	  break;
	}
      memcpy (bp, ptr.ptr, ptr.buf->end - ptr.ptr);
      bp += ptr.buf->end - ptr.ptr;
    }
  to->lm_memblock[to->lm_length] = '\0';
}

caddr_t
DBG_NAME(box_brcpy) (DBG_PARAMS buf_range_t * from)
{
  buf_ptr_t ptr;
  char * bp;
  size_t sz;
  caddr_t res;

  for (sz = 0, ptr = from->beg;
       ptr.buf;
       ptr.buf = ptr.buf->next, ptr.ptr = ptr.buf->beg)
    {
      if (from->end.buf == ptr.buf)
	{
	  sz += from->end.ptr - ptr.ptr;
	  break;
	}
      sz += ptr.buf->end - ptr.ptr;
    }

  res = DBG_NAME (dk_alloc_box) (DBG_ARGS sz+1, DV_STRING);
  bp = res;

  for (ptr = from->beg;
       ptr.buf;
       ptr.buf = ptr.buf->next, ptr.ptr = ptr.buf->beg)
    {
      if (from->end.buf == ptr.buf)
	{
	  memcpy (bp, ptr.ptr, from->end.ptr - ptr.ptr);
	  bp += from->end.ptr - ptr.ptr;
	  break;
	}
      memcpy (bp, ptr.ptr, ptr.buf->end - ptr.ptr);
      bp += ptr.buf->end - ptr.ptr;
    }
  bp[0] = '\0';
  return res;
}

/*
 * returns 0 if strings are equal
 */
int
brcmp (lenmem_t * lsp, buf_range_t * brp)
{
  buf_ptr_t ptr;
  char * p1;
  size_t i, sz;

  for (ptr = brp->beg, i = lsp->lm_length, p1 = lsp->lm_memblock;
       ptr.buf;
       ptr.buf = ptr.buf->next, ptr.ptr = ptr.buf->beg)
    {
      if (brp->end.buf == ptr.buf)
	{
	  sz = brp->end.ptr - ptr.ptr;
	  if (i != sz)
	    return 1;
	  return memcmp (p1, ptr.ptr, sz);
	}

      sz = ptr.buf->end - ptr.ptr;

      if (i < sz || memcmp (p1, ptr.ptr, sz))
	return 1;

      p1 += sz;
      i -= sz;
    }
  return 1;
}

/* remove leading, trailing and repeating whitespace characters */
void
normalize_value (lenmem_t * lsp)
{
/* 'unsigned' here is important for case-unsafe isspace() on antique LIBC and 8-bit-set UTF-8 input */
  unsigned char *from = (unsigned char *)lsp->lm_memblock;
  unsigned char *to = from;
  unsigned char *end = from + lsp->lm_length;

/* Step 1: removal trailing spaces */
  while ((end > from) && isspace (end[-1])) end--;
/* Step 2: skipping leading spaces */
  while ((from < end) && isspace (from[0])) from++;
/* Step 3: skip till the first space, optimized for most common case */
  if (from == to)
    {
      while ((from < end) && !isspace (from[0])) from++;
      to = from;
    }
  else
    {
      while ((from < end) && !isspace (from[0])) (to++)[0] = (from++)[0];
    }
/* Step 4: handling internal spaces if any */
  while (from < end)
    {
#ifdef DEBUG
      if (!isspace (from[0]))
        GPF_T1 ("Internal error in xmlread.c, normalize_value()");
#endif
      from++;
      (to++)[0] = ' ';
      while ((from < end) && isspace (from[0])) from++;
      while ((from < end) && !isspace (from[0])) (to++)[0] = (from++)[0];
    }
  to[0] = '\0';
  lsp->lm_length = to - (unsigned char *)lsp->lm_memblock;
}

/* Converts to uppercase only latin chars */
unichar
upper_case (unichar c)
{
  if (c >= 'a' && c <= 'z')
    c -= 'a' - 'A';

  return c;
}

#ifdef DEBUG
/* returns 1 if equal */
int
names_are_equal (lenmem_t * sname, char * name)
{
  char * sname_tail = sname->lm_memblock;
  char * sname_end = sname_tail + sname->lm_length;

  for (/* no init*/; name[0] && sname_tail < sname_end; ++name, ++sname_tail)
    {
      if (name[0] != sname_tail[0])
	return 0;
    }

  if (name[0] == 0 && sname_tail == sname_end)
    return 1;
  return 0;
}
#endif

void
advance_ptr (vxml_parser_t * parser)
{
  brick_t *ptr, *leftmost_saved;
  while ((parser->pptr.ptr == parser->pptr.buf->end) && (parser->eptr.buf != parser->pptr.buf))
    {
      parser->pptr.buf = parser->pptr.buf->next;
      parser->pptr.ptr = parser->pptr.buf->beg;
      if (parser->cfg.uri == parser->curr_pos.origin_uri)
	xml_pos_set (&(parser->last_main_pos), &(parser->curr_pos));
      xml_pos_set (&(parser->curr_pos), &(parser->pptr.buf->beg_pos));
      parser->curr_pos_ptr.buf = parser->pptr.buf;
      parser->curr_pos_ptr.ptr = parser->pptr.ptr;
    }

  parser->bptr.ptr = parser->pptr.ptr;
  parser->bptr.buf = parser->pptr.buf;

  parser->curr_pos_ptr = parser->pptr;

  ptr = parser->pptr.buf->prev;
  leftmost_saved = parser->pptr.buf;

  if (NULL == ptr)
    return;
  validate_parser_bricks(parser);
  while (NULL != ptr)
    {
      brick_t *old = ptr;
      ptr = ptr->prev;
      if (0 < old->data_refctr)
	{
	  leftmost_saved->prev = old;
	  old->next = leftmost_saved;
	  leftmost_saved = old;
	  continue;
	}
      if (NULL != old->data_begin)
	dk_free_box (old->data_begin);
      else if (NULL != old->data_owner)
	old->data_owner->data_refctr -= 1;
#ifdef UNIT_DEBUG
      printf ("Releasing a buffer element. %x\n", old);
#endif
      dk_free (old, sizeof (brick_t));
    }
  leftmost_saved->prev = NULL;
  validate_parser_bricks(parser);
}

static void
normalize_name (buf_range_t * brp)
{
  buf_ptr_t ptr = brp->beg;
  utf8char * tmp;
  utf8char * ep;
  utf8char c;

  while (ptr.buf != brp->end.buf || ptr.ptr < brp->end.ptr)
    {
      if (ptr.ptr >= ptr.buf->end)
	{
	  ptr.buf = ptr.buf->next;
	  ptr.ptr = ptr.buf->beg;
	}
      tmp = ptr.ptr;
      ep = (ptr.buf == brp->end.buf) ? brp->end.ptr : ptr.buf->end;
      c = (ptr.ptr++)[0];
      if (c >= 'A' && c <= 'Z')
	tmp[0] = c + ('a' - 'A'); /* new size should be the same */
    }
}

#ifdef DEBUG
int grand_total_skip_ctr = 0;
int grand_total_get_ctr = 0;
#endif

int
skip_plain_tok_chars (vxml_parser_t * parser, int stop_at)
{
  utf8char *ebuf_end;
  utf8char *range_begin = (utf8char *)(parser->eptr.ptr);
  int res;
#ifndef NDEBUG
  if (0 == parser->src_eh->eh_stable_ascii7)
    GPF_T;
  if (parser->eptr.ptr != parser->pptr.ptr)
    GPF_T;
#endif
  ebuf_end = (utf8char *)(parser->eptr.buf->end) - (MAX_UTF8_CHAR+1);
  if (parser->static_src_tail < parser->static_src_end)
    {
      do {
          utf8char c;
          if (parser->eptr.ptr >= ebuf_end)
            goto end_of_ebuf_fill;
          c = parser->static_src_tail[0];
          if (vxml_char_props [c] & stop_at)
            goto end_of_ebuf_fill;
          ((parser->eptr.ptr)++)[0] = c;
          parser->static_src_tail++;
        } while (parser->static_src_tail < parser->static_src_end);
      goto end_of_ebuf_fill;
    }
  if (parser->feeder == NULL)
    goto end_of_ebuf_fill;
  while (parser->feed_tail < parser->feed_end)
    {
      utf8char c;
      if (parser->eptr.ptr >= ebuf_end)
        goto end_of_ebuf_fill;
      c = parser->feed_tail[0];
      if (vxml_char_props [c] & stop_at)
        goto end_of_ebuf_fill;
      ((parser->eptr.ptr)++)[0] = c;
      parser->feed_tail++;
    }
end_of_ebuf_fill:
  parser->pptr.ptr = parser->eptr.ptr;
  res = ((utf8char *)(parser->eptr.ptr) - range_begin);
  parser->curr_pos.col_c_num += res;
#ifdef DEBUG
  grand_total_skip_ctr += res;
  /*{
    int ctr;
    printf ("skip_plain_tok_chars(..., %d): |", stop_at);
    for (ctr = 0; ctr < res; ctr++)
      putchar (range_begin[ctr]);
    printf ("|\n");
  }*/
#endif
  return res;
}


unichar
get_tok_char (vxml_parser_t * parser)
{
  unichar c;
  char *put_tmp;
#ifdef DEBUG
  grand_total_get_ctr++;
#endif

#ifndef NO_validate_parser_bricks
  static int ctr = 0;
  if (!(ctr++ % 10000))
    validate_parser_bricks(parser);
#endif

ent_recover: /*recover from encoding error in included entity */
  while ((parser->pptr.ptr == parser->pptr.buf->end) && (parser->eptr.buf != parser->pptr.buf))
    {
      if (NULL == parser->pptr.buf->next)
	GPF_T;
      parser->pptr.buf = parser->pptr.buf->next;
      parser->pptr.ptr = parser->pptr.buf->beg;
#ifdef DEBUG
      if ((NULL != parser->cfg.uri) && (DV_STRING != DV_TYPE_OF (parser->cfg.uri)) && (DV_UNAME != DV_TYPE_OF (parser->cfg.uri)))
        GPF_T;
      if ((NULL != parser->curr_pos.origin_uri) && (DV_STRING != DV_TYPE_OF (parser->curr_pos.origin_uri)) && (DV_UNAME != DV_TYPE_OF (parser->curr_pos.origin_uri)))
        GPF_T;
#endif      
      if (parser->cfg.uri == parser->curr_pos.origin_uri)
	xml_pos_set (&(parser->last_main_pos), &(parser->curr_pos));
      xml_pos_set (&(parser->curr_pos), &(parser->pptr.buf->beg_pos));
      parser->curr_pos_ptr.buf = parser->pptr.buf;
      parser->curr_pos_ptr.ptr = parser->pptr.ptr;
    }
  if (parser->pptr.ptr != parser->eptr.ptr)
    {		/* there are unprocessed chars in the buffer */
      c = eh_decode_char__UTF8 ((__constcharptr *)(&(parser->pptr.ptr)), parser->pptr.buf->end);
      if (c >= 0)
	goto ok;
      parser->pptr.buf->end = parser->pptr.ptr;
      goto ent_recover;
    }

  /* get a new char */
again:

  c = get_one_xml_char (parser);

  if (c < 0)
    return c;

  if (c == 0xD)
    goto again;

  put_tmp = eh_encode_char__UTF8 (c, parser->eptr.ptr, parser->eptr.buf->end);

  if (((char *)UNICHAR_NO_ROOM) == put_tmp)
    {
      /* switching to next buffer */
      parser->eptr.buf->end = parser->eptr.ptr;	/* adjusting buffer end if there is a room
					 * only for a partial char */
      add_buf (parser);
      parser->eptr.buf = parser->eptr.buf->next;
      parser->eptr.ptr = parser->eptr.buf->beg;
      put_tmp = eh_encode_char__UTF8 (c, parser->eptr.ptr, parser->eptr.buf->end);
    }
  if (((char *)UNICHAR_NO_ROOM) == put_tmp)
    {
      xmlparser_logprintf (parser, XCFG_ERROR, 100, "Internal error in memory allocation");
      return -1;
    }
  parser->pptr.ptr = parser->eptr.ptr = put_tmp;
  parser->pptr.buf = parser->eptr.buf;

ok:
#if 0
  xml_dbg_printf (("%c", c));
#endif
  if (parser->curr_pos_ptr.buf == parser->pptr.buf)
    {
      if (parser->curr_pos_ptr.ptr >= parser->pptr.ptr)
	return c;
    }
  else
    {
      if (parser->curr_pos_ptr.buf->next != parser->pptr.buf)
	return c;
      parser->curr_pos_ptr.buf = parser->pptr.buf;
    }
  parser->curr_pos_ptr.ptr = parser->pptr.ptr;
  if (0x0A == c)
    {
      parser->curr_pos.line_num += 1;
      parser->curr_pos.col_c_num = 1;
    }
  else
    {
      if ('\t' == c)
	parser->curr_pos.col_c_num = ((parser->curr_pos.col_c_num-1) | 0x7) + 2;
      else
	parser->curr_pos.col_c_num += 1;
    }
#if 0
  parser->curr_pos.col_b_num += parser->last_ch_size;
#else
  parser->curr_pos.col_b_num = parser->static_src_tail - parser->static_src;
#endif

#ifndef NO_validate_parser_bricks
  if (!(ctr++ % 10000))
    validate_parser_bricks(parser);
#endif

  return c;
}

#if 0
/* like get_tok_char returns char
   + unfold entities */
unichar get_tok_char2(vxml_parser_t* parser)
{
  buf_ptr_t rem = parser->pptr;
  int ch = get_tok_char (parser);
  if ('&' == ch)
    {
      if (!replace_entity_common (parser, 1 /* = GE */, 0, rem, 1))
	return ch;
      parser->curr_pos_ptr = parser->pptr = rem;
      return get_tok_char (parser);
    };
  return ch;
}
#endif

int
test_string (vxml_parser_t * parser, const char * s)
{
  unichar c;
  buf_ptr_t rem = parser->pptr;

  for (; *s; ++s)
    {
      c = get_tok_char (parser);
      if (c != *s)
	{
	  parser->pptr = rem;
	  return 0;
	}
    }
  return 1;
}

int
test_case_string (vxml_parser_t * parser, const char * s,
		  int case_insensitive)
{
  unichar c;
  char sc;
  buf_ptr_t rem = parser->pptr;

  for (; *s; ++s)
    {
      c = get_tok_char (parser);
      sc = *s;
      if (case_insensitive)
	{
	  c = upper_case (c);
	  sc = upper_case (sc);
	}

      if (c != sc)
	{
	  parser->pptr = rem;
	  return 0;
	}
    }
  return 1;
}

int
test_char_int (vxml_parser_t * parser, unichar ch)
{
  unichar c;
  buf_ptr_t rem = parser->pptr;
  c = get_tok_char (parser);
  if (c == ch)
    {
      return 1;
    }
  else if ('%' == c)
    {
      parser->pptr = rem;
      if (replace_entity (parser))
	return test_char (parser,ch);
      else
	{
	  parser->pptr = rem;
	  return 0;
	};
    }
  parser->pptr = rem;
  return 0;
}

int
get_to_string (vxml_parser_t * parser, const char * s)
{
  unichar c;
  buf_ptr_t rem = parser->pptr;
  buf_ptr_t tmp;

  for (;;)
    {
      tmp = parser->pptr;
      if (test_string (parser, s))
	{
	  parser->tmp.string.beg = rem;
	  parser->tmp.string.end = tmp;
	  return 1;
	}
      c = get_tok_char (parser);
      if (c < 0)
	  return 0;
    }
  /* not reachable */
}

int
get_to_string2 (vxml_parser_t * parser, const char * s1, const char * s2)
{
  unichar c;
  buf_ptr_t rem = parser->pptr;
  buf_ptr_t tmp;

  for (;;)
    {
      tmp = parser->pptr;
      if (test_string (parser, s1) || test_string (parser, s2))
	{
	  parser->tmp.string.beg = rem;
	  parser->tmp.string.end = tmp;
	  return 1;
	}
      c = get_tok_char (parser);
      if (c < 0)
	  return 0;
    }
  /* not reachable */
}

int
test_ws (vxml_parser_t * parser)
{
  unichar c;
  buf_ptr_t rem = parser->pptr;
  buf_ptr_t tmp;

  for (;;)
    {
      tmp = parser->pptr;
      if (test_char(parser,' '))
	continue;

      c = get_tok_char (parser);
      if (c < 0)
	return 0;

      switch (c)
	{
	case 0x20:
	case 0x9:
	case 0xD:	/* really it shouldn't happen, all CR and CRLF chars
			 * are converted to LF in get_tok_char
			 */
	case 0xA:
	  break;
	default:
	  parser->pptr = tmp;
	  return (ptr_diff (tmp, rem));
	}
    }
}

/* for ENTITY */
int
test_ws2 (vxml_parser_t * parser)
{
  unichar c;
  buf_ptr_t rem = parser->pptr;
  buf_ptr_t tmp;

  for (;;)
    {
      tmp = parser->pptr;

      c = get_tok_char (parser);
      if (c < 0)
	return 0;

      switch (c)
	{
	case 0x20:
	case 0x9:
	case 0xD:	/* really it shouldn't happen, all CR and CRLF chars
			 * are converted to LF in get_tok_char
			 */
	case 0xA:
	  break;
	default:
	  parser->pptr = tmp;
	  return (ptr_diff (tmp, rem));
	}
    }
}

/*** BEG RUS/FIXME Tue Mar 27 19:58:25 2001 ***/
/* temporary solution (entity replacment), which should be wiped from here out */
/*** END RUS/FIXME Tue Mar 27 19:58:34 2001 ***/
int
test_class_str (vxml_parser_t * parser, const xml_char_class_t cclass)
{
  unichar c;
  buf_ptr_t rem = parser->pptr;
  buf_ptr_t tmp;
  const xml_char_range_t * cl_ptr;

  for (;;)
    {
      if ((0 != parser->src_eh->eh_stable_ascii7) && (parser->pptr.ptr == parser->eptr.ptr))
        skip_plain_tok_chars (parser, VXML_CHARPROP_ANY_NONCHAR);
      tmp = parser->pptr;
      c = get_tok_char (parser);
      switch (c)
      {
      case '&':
	if (replace_entity_common (parser, 1 /* = GE */, 0, tmp, 1))
	  {
	    parser->pptr=tmp;
	    c = get_tok_char (parser);
	  }
	break;
      case '%':
	if (replace_entity_common (parser, 0 /* = not GE */, 0, tmp, 1))
	  {
	    parser->pptr=tmp;
	    c = get_tok_char (parser);
	  }
	break;
      default:
	  ;
      }


      if (c < 0)
	return 0;

      cl_ptr = cclass;
      for (;;)
	{
	  if (c < cl_ptr->start)
	    break;
	  if (c <= cl_ptr->end)
	    goto c_is_in_char_class;
	  cl_ptr++;
	  if (cl_ptr->start < 0)
	    break;
	}

/*c_is_not_in_char_class:*/
      parser->pptr = tmp;
      return (ptr_diff (tmp, rem));

c_is_in_char_class:
      ;
    }
}

int
test_class_str_noentity (vxml_parser_t * parser, const xml_char_class_t cclass)
{
  unichar c;
  buf_ptr_t rem = parser->pptr;
  buf_ptr_t tmp;
  const xml_char_range_t * cl_ptr;
  for (;;)
    {
      if ((0 != parser->src_eh->eh_stable_ascii7) && (parser->pptr.ptr == parser->eptr.ptr))
        skip_plain_tok_chars (parser, VXML_CHARPROP_ANY_NONCHAR);
      tmp = parser->pptr;
      c = get_tok_char (parser);
      if (c < 0)
	return 0;
      cl_ptr = cclass;
      for (;;)
	{
	  if (c < cl_ptr->start)
	    break;
	  if (c <= cl_ptr->end)
	    goto c_is_in_char_class;
	  cl_ptr++;
	  if (cl_ptr->start < 0)
	    break;
	}
/*c_is_not_in_char_class:*/
      parser->pptr = tmp;
      return (ptr_diff (tmp, rem));

c_is_in_char_class:
      ;
    }
}

int
test_xhtml_char_ref (vxml_parser_t * parser)
{
  const struct xhtml_ent_s *lookup_res;
  char buf[MAX_WORD_LENGTH + 1], *tail;
  tail = buf;
  while (tail < buf+MAX_WORD_LENGTH)
    {
      unichar c = get_tok_char (parser);
      if (c < 0)
	return c;
      if ((c & ~0x7F) || !isalnum(c))
	{
	  if (';' != c)
	    return -1;
	  break;
	}
      tail[0] = (char)(c);
      tail++;
    }
  tail[0] = '\0';
  lookup_res = xhtml_ent_gperf (buf, tail-buf);
  if (NULL == lookup_res)
    return -1;
  return lookup_res->encoded_symbol;
}

/*
 * It gets *bpp points right after '&' char.
 * If reference is a predefined or char reference then
 * it returns a corresponding unicode character. In other
 * case it returns -1 an reset parser->pptr to original place -
 * right after '&' - here should be a name of an entity.
 */
unichar
test_char_ref (vxml_parser_t * parser)
{
  unichar c;
  unichar res = 0;
  int flag = 1;

  if (test_char (parser, '#'))
    {
      if (test_char (parser, 'x') ||
	  (parser->cfg.input_is_html && test_char (parser, 'X')))
	{
	  for (;;)
	    {
	      c = get_tok_char (parser);
	      if (c < 0)
		return c;

	      if (c >= '0' && c <= '9')
		res = (res << 4) + c - '0';	/* FIXME - overflow check */
	      else if (c >= 'a' && c <= 'f')
		res = (res << 4) + c - 'a' + 10;
	      else if (c >= 'A' && c <= 'F')
		res = (res << 4) + c - 'A' + 10;
	      else if (!flag && (c == ';' || parser->cfg.input_is_html))
		return res;
	      else
		{
		  xmlparser_logprintf (parser, XCFG_ERROR, 100, "Invalid character reference: hexadecimal digits and trailing ';' expected after '&#x'");
		  return -1;
		}

	      flag = 0;
	    }
	}
      else
	{
	  for (;;)
	    {
	      c = get_tok_char (parser);
	      if (c < 0)
		return c;

	      if (c >= '0' && c <= '9')
		res = res * 10 + c - '0';	/* FIXME - overflow check */
	      else if (!flag && (c == ';' || parser->cfg.input_is_html))
		return res;
	      else
		{
		  xmlparser_logprintf (parser, XCFG_ERROR, 100, "Invalid character reference: decimal digits and trailing ';' expected after '&#'");
		  return -1;
		}

	      flag = 0;
	    }
	}
    }
  if (parser->cfg.input_is_html)
    return test_xhtml_char_ref (parser);
  if (test_string (parser, "lt;"))
    return '<';
  if (test_string (parser, "gt;"))
    return '>';
  if (test_string (parser, "amp;"))
    return '&';
  if (test_string (parser, "apos;"))
    return '\'';
  if (test_string (parser, "quot;"))
    return '"';
/*  if (test_string (parser, "nbsp;"))
    return 160;*/
  return -1;
}

int
get_name (vxml_parser_t * parser)
{
  buf_ptr_t rem = parser->pptr;

  replace_entity (parser);
  if (!test_class_str (parser, XML_CLASS_NMSTART))
    return 0;

  test_class_str (parser, XML_CLASS_NMCHAR);

  parser->tmp.name.beg = rem;
  parser->tmp.name.end = parser->pptr;

  return 1;
}


int
get_att_name (vxml_parser_t * parser)
{
  buf_ptr_t rem = parser->pptr;


  if (!test_class_str (parser, XML_CLASS_NMSTART))
    return 0;

  test_class_str (parser, XML_CLASS_NMCHAR);

  parser->tmp.name.beg = rem;
  parser->tmp.name.end = parser->pptr;

  return 1;
}


int
get_value (vxml_parser_t * parser, int dtd_body)
{
  unichar delim, c;
  buf_ptr_t tmp, rem;

  rem = parser->pptr;
  delim = get_tok_char (parser);
  if (delim < 0)
    return 0;
  if (delim != '"' && delim != '\'')
    {
      parser->pptr = rem;
      return 0;
    }
  rem = parser->pptr;
  for (;;)
    {
      if ((0 != parser->src_eh->eh_stable_ascii7) && (parser->pptr.ptr == parser->eptr.ptr))
        skip_plain_tok_chars (parser, VXML_CHARPROP_8BIT | VXML_CHARPROP_CTRL | VXML_CHARPROP_ENTBEGIN | VXML_CHARPROP_ATTREND);
      tmp = parser->pptr;
      c = get_tok_char (parser);
      if (c == delim)
	{
	  parser->tmp.value.beg = rem;
	  parser->tmp.value.end = tmp;
	  return 1;
	}
      if (c < 0)
	{
	  parser->pptr = rem;
	  return 0;
	}
      if (!dtd_body && '&' == c)
	{
	  replace_entity_common (parser, 1 /* = GE */, 0, tmp, 0);
	  /* parser->curr_pos_ptr = parser->pptr = rem; */
	}
    }

  /* not reachable */
}


int
get_attr_value (vxml_parser_t * parser, int dtd_body)
{
  unichar delim, c;
  buf_ptr_t tmp, rem;
  int last_char_replaced = 0;

  rem = parser->pptr;
  delim = get_tok_char (parser);
  if (delim < 0)
    return 0;
  if (delim != '"' && delim != '\'')
    {
      if (parser->cfg.input_is_html)
	{
	  parser->pptr = rem;
	  for (;;)
	    {
              if ((0 != parser->src_eh->eh_stable_ascii7) && (parser->pptr.ptr == parser->eptr.ptr))
                skip_plain_tok_chars (parser, VXML_CHARPROP_8BIT | VXML_CHARPROP_SPACE | VXML_CHARPROP_CTRL | VXML_CHARPROP_ENTBEGIN | VXML_CHARPROP_ATTREND | VXML_CHARPROP_TEXTEND | VXML_CHARPROP_ELTEND);
	      tmp = parser->pptr;
	      c = get_tok_char (parser);
	      switch (c)
		{
		case 0x20:
		case 0x9:
		case 0xD:
		case 0xA:
		case '"':
		case '\'':
		  goto html_value_ended;
		case '&':
		  {
		    if (dtd_body)
		      continue;
		    if (replace_entity_common (parser, 1 /* = GE */, 0, tmp, 0))
		      {
			/* parser->curr_pos_ptr = parser->pptr = rem; */
			continue;
		      }
		  }
		  break;
		case '>':
		  goto html_value_ended;
		}
	      if (c < 0)
		{
		  parser->pptr = rem;
		  return 0;
		}
	    }
html_value_ended:
	  if ((tmp.ptr == rem.ptr) && (DEAD_HTML != parser->cfg.input_is_html))

	    {
	      parser->pptr = rem;
	      return 0;
	    }
	  parser->pptr = tmp;
	  parser->tmp.value.beg = rem;
	  parser->tmp.value.end = parser->pptr;
	  return 1;
	}
      parser->pptr = rem;
      return 0;
    }

  rem = parser->pptr;

  for (;;)
    {
      if ((0 != parser->src_eh->eh_stable_ascii7) && (parser->pptr.ptr == parser->eptr.ptr))
        {
          if (skip_plain_tok_chars (parser, VXML_CHARPROP_8BIT | VXML_CHARPROP_CTRL | VXML_CHARPROP_ENTBEGIN | VXML_CHARPROP_ATTREND))
	    last_char_replaced = 0;
        }
      tmp = parser->pptr;
      c = get_tok_char (parser);
      if (c == delim && !last_char_replaced)
	{
	  parser->tmp.value.beg = rem;
	  parser->tmp.value.end = tmp;
	  return 1;
	}
      if (c < 0)
	{
	  parser->pptr = rem;
	  return 0;
	}
      if (!dtd_body && '&' == c && !last_char_replaced)
	{
	  last_char_replaced = 1;
	  replace_entity_common (parser, 1 /* = GE */, 0, tmp, 0);
	  /* parser->curr_pos_ptr = parser->pptr = rem; */
	}
      else
	last_char_replaced = 0;
    }

  /* not reachable */
}

/* IvAn/ParseDTD/000721 */
int
/* Rus/20010724 XMLConf
   is_text_decl - see http://www.w3.org/TR/2000/REC-xml-20001006#NT-TextDecl */
get_PI (vxml_parser_t * parser, int is_text_decl)
{
  buf_ptr_t rem = parser->pptr;
/*  buf_ptr_t old = parser->pptr; */
  lenmem_t target, data; /* components of PI */

  if (!parser->cfg.input_is_html && test_case_string (parser, "xml", 1) &&
      test_ws (parser))

    {	/* XML declaration */
      if (!parser->cfg.input_is_html)
	{
	  if (parser->state & XML_A_XMLDECL)
	    CLR_STATE(XML_A_XMLDECL);
#if 0
	  else
	    RET_ERR(XML_ERR_ILLEGAL_PI);
#endif
	}

      test_ws (parser);

      if (!test_string (parser, "version"))
	{
	  if (!is_text_decl) /* version parameter is not required in text declaration */
	    goto xml_err_xmldecl;
	}
      else
	{
	  test_ws (parser);
	  if (!test_char (parser, '='))
	    goto xml_err_xmldecl;
	  test_ws (parser);
	  if (!get_value (parser,1))
	    goto xml_err_xmldecl;
	}

      test_ws (parser);
      if (test_string (parser, "encoding"))
	{
	  lenmem_t encname;
	  lenmem_t encname_orig;
	  int encname_is_bad;
	  char * name_tail;
	  encoding_handler_t * eh;

	  test_ws (parser);
	  if (!test_char (parser, '='))
	    goto xml_err_xmldecl;
	  test_ws (parser);
	  if (!get_value (parser,1))
	    goto xml_err_xmldecl;

	  brcpy (&encname, &parser->tmp.value);
	  normalize_value (&encname);
	  brcpy (&encname_orig, &parser->tmp.value);
	  encname_is_bad = (
	    (encname_orig.lm_length != encname.lm_length) ||
	    strcmp (encname_orig.lm_memblock, encname.lm_memblock) );
	  dk_free_box (encname_orig.lm_memblock);
	  if (encname_is_bad)
	    {
	      dk_free_box (encname.lm_memblock);
	      goto xml_invalid_encoding_name;
	    }
	  for (name_tail = encname.lm_memblock;
	    name_tail < encname.lm_memblock + encname.lm_length;
	    name_tail++ )
	    {
	      if (name_tail[0] & ~0x7F)
		{
		  dk_free_box (encname.lm_memblock);
		  goto xml_invalid_encoding_name;
		}
	    }
	  name_tail[0] = 0;

	  if (parser->enc_flag != XML_EF_FORCE)
	    {
	      eh = find_encoding (parser, encname.lm_memblock);
	      dk_free_box (encname.lm_memblock);

	      if (NULL != eh)
		{
		  int byteorder;
		  unsigned clength;
		  byteorder = parser->bom.byteorder;
		  if ((0 != byteorder) && (0 != eh->eh_byteorder) && (byteorder != eh->eh_byteorder))
		    {
		      if (DEAD_HTML != parser->cfg.input_is_html)
			xmlparser_logprintf (parser, XCFG_ERROR, 100, "The byteorder of the encoding required by <?xml ... ?> declaration does not match the actual data");
		      goto end_of_encoding;
		    }
		  clength = parser->bom.code_length;
		  if ((0 != clength) && ((clength < eh->eh_minsize) || (clength > eh->eh_maxsize)))
		    {
		      if (DEAD_HTML != parser->cfg.input_is_html)
			xmlparser_logprintf (parser, XCFG_ERROR, 100, "The code length of the encoding required by <?xml ... ?> declaration does not match the actual data");
		      goto end_of_encoding;
		    }
		  if (('Y' == parser->bom.ucs4) && (&eh__UCS4BE != eh) && (&eh__UCS4LE != eh) && (&eh__UCS4 != eh))
		    {
		      if (DEAD_HTML != parser->cfg.input_is_html)
			xmlparser_logprintf (parser, XCFG_ERROR, 100, "The XML text is starting from UCS-4 signature but <?xml ... ?> declaration specifies other encoding");
		      goto end_of_encoding;
		    }
		  if (('Y' == parser->bom.utf16) && (&eh__UTF16BE != eh) && (&eh__UTF16LE != eh) && (&eh__UTF16 != eh))
		    {
		      if (DEAD_HTML != parser->cfg.input_is_html)
			xmlparser_logprintf (parser, XCFG_ERROR, 100, "The XML text is starting from UTF-16 signature but <?xml ... ?> declaration specifies other encoding");
		      goto end_of_encoding;
		    }
		  if (('Y' == parser->bom.utf8) && (&eh__UTF8 != eh))
		    {
		      if (DEAD_HTML != parser->cfg.input_is_html)
			xmlparser_logprintf (parser, XCFG_ERROR, 100, "The XML text is starting from UTF-8 signature but <?xml ... ?> declaration specifies other encoding");
		      goto end_of_encoding;
		    }
		  if ((0 != byteorder) && (0 == eh->eh_byteorder))
		    {
		      goto end_of_encoding; /* This is for case when BOM gives an exact encoding but the name is as ambiguous as UTF-16 (neither UTF-16BE nor UTF-16LE) */
		    }
		  parser->src_eh = eh;
		  parser->src_eh_state = 0; /* reset of encoding state on encoding change */
		}
	      else if (parser->enc_flag != XML_EF_SUGGEST)
	        {
		  if (DEAD_HTML != parser->cfg.input_is_html)
		    xmlparser_logprintf (parser, XCFG_ERROR, 100, "Unknown encoding is specified in <?xml ... ?> XML declaration");
		}
	    }
	  else
	    dk_free_box (encname.lm_memblock);
	}
end_of_encoding:

      test_ws (parser);
      if (test_string (parser, "standalone"))
	{
	  lenmem_t standalone;
	  int yn_is_bad;
	  test_ws (parser);
	  if (!test_char (parser, '='))
	    goto xml_err_xmldecl;
	  test_ws (parser);
	  if (!get_value (parser,1))
	    goto xml_err_xmldecl;
	  brcpy(&standalone,&parser->tmp.value);
/* We do not need the value of "standalone" property at all, but
we have to ensure that it is correct */
	  yn_is_bad = (strcmp (standalone.lm_memblock, "yes") && strcmp (standalone.lm_memblock, "no"));
	  dk_free_box (standalone.lm_memblock);
	  if (yn_is_bad && (DEAD_HTML != parser->cfg.input_is_html))
	    {
	      RET_ERRMSG("Invalid <?xml ... ?> XML declaration");
	    }
	}
      test_ws (parser);
      if (test_string (parser, "?>"))
	return 1;

      if (DEAD_HTML != parser->cfg.input_is_html)
	goto xml_err_xmldecl;
      if(!get_to_string (parser, "-->"))
	return 0;
      return 1;

xml_err_xmldecl:
      if (DEAD_HTML == parser->cfg.input_is_html)
	return 1;
      RET_ERRMSG("Invalid <?xml ... ?> XML declaration");
/*
xml_err_encoding:
      if (DEAD_HTML == parser->cfg.input_is_html)
	return 1;
      RET_ERRMSG("Incomplete <?xml ... ?> XML declaration: explicit encoding=\"...\" attribute is required by application");
*/
xml_invalid_encoding_name:
      if (DEAD_HTML == parser->cfg.input_is_html)
	return 1;
      RET_ERRMSG("Encoding name contains invalid characters in <?xml ... ?> XML declaration");
    }

  parser->pptr = rem;

  if (!parser->cfg.input_is_html)
    {
      if (parser->state & XML_A_PI)
	CLR_STATE(XML_A_XMLDECL);
      else
	RET_ERRMSG("Processing instruction may not be used here due to XML structure rules");
    }

  /* Here we start processing of plain, non-heading PI */
  target.lm_memblock = data.lm_memblock = NULL;
  if (!get_name (parser)) goto synterror_cleanup;
  brcpy (&target, &parser->tmp.name);
  if (DEAD_HTML != parser->cfg.input_is_html)
    {
      if (test_ws (parser))
	{
	  if (!get_to_string (parser, "?>"))
            goto synterror_cleanup;
	  brcpy (&data, &parser->tmp.string);
	}
      else
	{
	  if (!test_string (parser, "?>"))
	    goto synterror_cleanup;
	}
    }
  else /* The following is solely to bypass MS Office [beep]-ups */
    {
      buf_ptr_t tmp;
      int ws_found = test_ws (parser);
      tmp = parser->pptr;
      if (ws_found)
        {
          if (!get_to_string2 (parser, "?>", "/>"))
            {
              parser->pptr = tmp;
	      goto synterror_cleanup;
	    }
	  brcpy (&data, &parser->tmp.string);
	}
      else
	{
	  if (!test_string (parser, "?>"))
	    {
	      if (!get_to_string2 (parser, "?>", "/>"))
		{
		  parser->pptr = tmp;
		  goto synterror_cleanup;
		}
	    }
	}
    }
  if (parser->masters.pi_handler)
    parser->masters.pi_handler (parser->masters.user_data, target.lm_memblock, data.lm_memblock);
  /* always true: if(NULL!=target.lm_memblock) */ dk_free_box (target.lm_memblock);
  if (NULL != data.lm_memblock) dk_free_box (data.lm_memblock);
  return 1;

synterror_cleanup:
  if (NULL!=target.lm_memblock) dk_free_box (target.lm_memblock);
  if (NULL!=data.lm_memblock) dk_free_box (data.lm_memblock);
  if (DEAD_HTML == parser->cfg.input_is_html)
    return 1;
  RET_ERRMSG("Only part of processing instruction <?...?> has found");
}

int
get_comment (vxml_parser_t * parser, int call_handler)
{
  lenmem_t text;
  /* rus 23/10/02 SGMLism comment must not contain "--" */
  if (XCFG_DISABLE != parser->validator.dv_curr_config.dc_sgml)
    {
      /*buf_ptr_t rem = parser->pptr ;*/
      if (!get_to_string (parser, "--")) return 0;
      if (!test_char (parser, '>'))
	{
	  xmlparser_logprintf (parser, parser->validator.dv_curr_config.dc_sgml, 100,
	      "\"--\" is not allowed in comments for SGML compatibility" );
	  goto cont;
	}
    }
  else
    {
    cont:
      if(!get_to_string (parser, "-->")) return 0;
    }
  if (call_handler)
    {
      if(NULL==parser->masters.comment_handler) return 1;
      brcpy (&text, &parser->tmp.string);
      parser->masters.comment_handler(parser->masters.user_data,text.lm_memblock);
      dk_free_box (text.lm_memblock);
    };
  return 1;
}

int
process_peref (vxml_parser_t * parser)
{
  replace_entity (parser);
  return 0;
}

/* IvAn/ParseDTD/990721 Many patches added to add entity to proper dictionary */
int
get_entity_decl (vxml_parser_t * parser)
{
  int PE_f = 0; /* if entity definition is param-entity decl? */
  caddr_t name = NULL, litval = NULL, publit = NULL, syslit = NULL, notat = NULL; /* components of the definition */
  xml_def_4_entity_t *newdef; /* definition of new entity */
  /*int entity_is_external = 0;*/
  xml_pos_t def_pos;
  id_hash_t **dictptr, *dict;
  xml_pos_set (&def_pos, &(parser->curr_pos));
  xml_dbg_printf(("{get_entity_decl "));

  if (test_char (parser, '%'))
    {
      if (!test_ws (parser))
	return 0;	/* no allocs done -> no memory cleanup */
      PE_f = 1;		/* parameter entity */
    }

  if (!get_name (parser) ||
      !test_ws (parser))
    goto synterror;

  name = box_brcpy (&(parser->tmp.name));

  if (test_string (parser, "PUBLIC"))
    {
      if (!test_ws (parser))
        goto synterror;
      if (!get_value (parser,1))
	goto synterror;
      publit = box_brcpy (&(parser->tmp.value));
      /* PUBLIC id is got */
      if (!test_ws (parser))
	goto synterror;
      goto do_external;
    }
  else if (test_string (parser, "SYSTEM"))
    {
      if (!test_ws (parser))
	goto synterror;
      goto do_external;
    }

  if (!get_value (parser,1))
    goto synterror;
	/* internal entity */
  litval = box_brcpy (&(parser->tmp.value));
  goto do_closing_gt;

do_external:
  if (!get_value (parser,1))
    goto synterror;

  syslit = box_brcpy (&(parser->tmp.value));

  if (!PE_f)
    {
      if (test_ws (parser) &&
	test_string (parser, "NDATA"))
	{		/* unparsed external entity */
	  if (!test_ws (parser) ||
	      !get_name (parser))
	    goto synterror;
	  notat = box_brcpy (&(parser->tmp.name));
	      /* we have a notation name */
	}
    }

do_closing_gt:
  test_ws (parser);
  if(!test_char (parser, '>'))
    goto synterror;

  dictptr = (PE_f ? &(parser->validator.dv_dtd->ed_params) : &(parser->validator.dv_dtd->ed_generics));
  if (NULL == dictptr[0])
    dictptr[0] = id_hash_allocate (251, sizeof (caddr_t), sizeof (caddr_t), strhash, strhashcmp);

  dict = dictptr[0];

  if(id_hash_get(dict,(caddr_t)(&name)))
    {
      dk_free_box (name);
      dk_free_box (litval);
      dk_free_box (publit);
      dk_free_box (syslit);
      dk_free_box (notat);
      xml_dbg_printf(("- ignored}"));
      return 1;
    }

  newdef = dk_alloc (sizeof(xml_def_4_entity_t));
  newdef->xd4e_literalVal = litval;
  newdef->xd4e_publicId = publit;
  newdef->xd4e_systemId = syslit;
  newdef->xd4e_notationName = notat;
  newdef->xd4e_repl.lm_memblock = NULL;
  newdef->xd4e_repl.lm_length = 0;
  newdef->xd4e_may_be_in_ecm = 1;
  newdef->xd4e_may_be_in_mkup = 1;
  newdef->xd4e_valid = 0;
  xml_pos_set (&(newdef->xd4e_defn_pos), &def_pos);

  if (NULL != notat)
    {
      xml_dbg_printf(("- will not compile"));
      newdef->xd4e_may_be_in_ecm = 0;
      newdef->xd4e_may_be_in_mkup = 0;
      xml_pos_set (&(newdef->xd4e_val_pos), &def_pos); /* A fake position is better than nothing. */
    }
  else
    {
      xml_dbg_printf(("- will compile"));
      if (0 == entity_compile_repl (parser, newdef))
	goto compile_error;
    }
  id_hash_set(dict,(caddr_t)(&name),(caddr_t)(&newdef));

  xml_dbg_printf(("- success }"));
  return 1;

compile_error:
  dk_free (newdef, sizeof(xml_def_4_entity_t));
  goto synterror;

synterror:
  dk_free_box (name);
  dk_free_box (litval);
  dk_free_box (publit);
  dk_free_box (syslit);
  dk_free_box (notat);
  xml_dbg_printf(("- failed }"));
  return 0;
}

/* IvAn/ParseDTD/990721 **/

int
get_content_def (vxml_parser_t * parser)
{
  unichar delim = 0;

  if (!test_char (parser, '('))
    return 0;

  for (;;)
    {
      test_ws (parser);

      replace_entity (parser);
      if (get_content_def (parser))
	{

	}
      else if (test_string (parser, "#PCDATA") || get_name (parser))
	{
	  if (!test_char (parser, '?'))
	    if (!test_char (parser, '*'))
	      test_char (parser, '+');
	}
      else
	return 0;

      test_ws (parser);
      replace_entity (parser);
      test_ws (parser);

      if (test_char (parser, ')'))
	break;
      if (delim)
	{
	  test_ws(parser);
	  if (!test_char (parser, delim))
	    return 0;
	}
      else
	{
	  if (test_char (parser, '|'))
	    delim = '|';
	  else if (test_char (parser, ','))
	    delim = ',';
	  else
	    return 0;
	}

      test_ws (parser);
    }

  if (!test_char (parser, '?'))
    if (!test_char (parser, '*'))
      test_char (parser, '+');

  return 1;
}

int
get_element_decl (vxml_parser_t * parser)
{
  if (!get_name (parser) ||
      !test_ws (parser))
    return 0;

  if (test_string (parser, "EMPTY"))
    {
      /* TBD - empty element processing */

    }
  else if (test_string (parser, "ANY"))
    {
      /* TBD - ANY element processing */
    }
  else if (!get_content_def (parser))
    return 0;

  test_ws (parser);
  return test_char (parser, '>');
}


int
get_att_type (vxml_parser_t * parser)
{
  if (test_char (parser, '('))
    {	/* enumeration */
      for (;;)
	{
	  buf_ptr_t rem ;
	  test_ws (parser);
	  rem = parser->pptr;
	  if (!test_class_str (parser, XML_CLASS_NMCHAR))
	    return 0;

	  test_ws (parser);
	  if (test_char (parser, ')'))
	    return 1;
	  if (!test_char (parser, '|'))
	    return 0;
	}
      /* not reachable */
    }
  else
    {
      if (test_string (parser, "NMTOKENS") ||
	  test_string (parser, "NMTOKEN") ||
	  test_string (parser, "ENTITIES") ||
	  test_string (parser, "ENTITY") ||
	  test_string (parser, "IDREFS") ||
	  test_string (parser, "IDREF") ||
	  test_string (parser, "CDATA") ||
	  test_string (parser, "ID"))
	{
	  return 1;
	}
      else if (test_string (parser, "NOTATION"))
	{
	  if (!test_ws (parser) ||
	      !test_char (parser, '('))
	    return 0;

	  for (;;)
	    {
	      test_ws (parser);
	      if (!get_name (parser))
		return 0;

	      test_ws (parser);
	      if (test_char (parser, ')'))
		return 1;
	      if (!test_char (parser, '|'))
		return 0;
	    }
	  /* not reachable */
	}
    }
  return 0;
}

int
get_def_decl (vxml_parser_t * parser)
{
  if (test_string (parser, "#REQUIRED") ||
      test_string (parser, "#IMPLIED"))
    return 1;

  if (test_string (parser, "#FIXED"))
    {
      if (!test_ws (parser))
	return 0;
    }

  return get_value (parser,1);
}

int
get_attlist_decl (vxml_parser_t * parser)
{
  if (!get_name (parser))
    return 0;

  for (;;)
    {
      if (!test_ws (parser) ||
	  !get_name (parser))
	{
	  if (test_char (parser, '>'))
	    return 1;
	  /* RUS/Fixme: here should be error, since there is no name for attribute */
	  else
	    return 0;
	}

      if (!test_ws (parser) ||
	  !get_att_type (parser) ||
	  !test_ws (parser) ||
	  !get_def_decl (parser))
	return 0;
    }
  /* not reachable */
}

/* IvAn/ParseDTD/000721 */
int
get_notation_decl (vxml_parser_t * parser)
{
  lenmem_t name, publit, syslit; /* components of the definition */
  xml_def_4_notation_t *newdef; /* definition of new entity */
  id_hash_t **dictptr, *dict;
  name.lm_memblock = publit.lm_memblock = syslit.lm_memblock = NULL;

  if (!get_name (parser))
    return 0; /* no allocs -> no mem cleanup */
  brcpy (&name, &parser->tmp.name);

  if (!test_ws (parser))
    goto synterror;

  if (test_string (parser, "PUBLIC"))
    {
      if (!test_ws (parser) ||
	  !get_value (parser,1))
	goto synterror;
      /* public identifier */
      brcpy (&publit, &parser->tmp.value);

      if (test_ws (parser) &&
	  get_value (parser,1))
	{	/* system identifier (optional) */
	  brcpy (&syslit, &parser->tmp.value);
	}
    }
  else if (test_string (parser, "SYSTEM"))
    {
      if (!test_ws (parser) ||
	  !get_value (parser,1))
	goto synterror;
      /* system identifier */
      brcpy (&syslit, &parser->tmp.value);
    }

  test_ws (parser);
  if (!test_char (parser, '>'))
    goto synterror;

  newdef = dk_alloc(sizeof(xml_def_4_notation_t));
  newdef->xd4n_publicId = publit.lm_memblock;
  newdef->xd4n_systemId = syslit.lm_memblock;

  dictptr = &(parser->validator.dv_dtd->ed_notations);
  if (NULL == dictptr[0])
    dictptr[0] = id_hash_allocate (251, sizeof (caddr_t), sizeof (caddr_t), strhash, strhashcmp);
  dict = dictptr[0];
  id_hash_set(dict,(caddr_t)(&name.lm_memblock),(caddr_t)(&newdef));

  return 1;

synterror:
  if (name.lm_memblock) dk_free_box (name.lm_memblock);
  if (publit.lm_memblock) dk_free_box (publit.lm_memblock);
  if (syslit.lm_memblock) dk_free_box (syslit.lm_memblock);
  return 0;
}


static void
handle_char_data (vxml_parser_t * parser, buf_ptr_t begin, buf_ptr_t end)
{
  buf_ptr_t iter;
  for (iter = begin; iter.buf != end.buf; iter.ptr = ((iter.buf = iter.buf->next) -> beg))
    {
      if (iter.ptr != iter.buf->end)
	parser->masters.char_data_handler (parser->masters.user_data, iter.ptr, iter.buf->end - iter.ptr);
    }
  if (iter.ptr != end.ptr)
    parser->masters.char_data_handler (parser->masters.user_data, iter.ptr, end.ptr - iter.ptr);
}

static int dtd_compile (vxml_parser_t *parser)
{
  ecm_el_idx_t ctr;
  dtd_t *dtd = parser->validator.dv_dtd;
  if (!parser->tmp.dtd_loaded_from_uri)
    {
      dtd->ed_puburi = box_copy (parser->tmp.dtd_puburi);
      dtd->ed_sysuri = box_copy (parser->tmp.dtd_sysuri);
    }

  for (ctr = 0; ctr < dtd->ed_el_no; ctr++)
    {
      ecm_el_t *el = dtd->ed_els+ctr;
#if 0
      caddr_t dump = NULL;
#endif
      if (el->ee_has_id_attr)
	{
	  ecm_attr_idx_t attr_idx;
	  for (attr_idx = 0; attr_idx < el->ee_attrs_no; attr_idx++)
	    {
	      if (ECM_AT_ID == el->ee_attrs[attr_idx].da_type)
		el->ee_id_attr_idx = attr_idx;
	    }
	}
      xml_dbg_printf (("\n\nFSM for children of %s, grammar %s:", el->ee_name, el->ee_grammar));
      if (NULL == el->ee_grammar)
	{
	  if (!el->ee_is_any && !el->ee_is_empty)
	    xmlparser_logprintf (parser, parser->validator.dv_curr_config.dc_names_unresolved, 100+strlen (el->ee_name),
	      "Element name '%s' is undefined but DTD contains references to it",
	      el->ee_name );
	    el->ee_is_any = 1;
	}
      else
	{
	  ecm_grammar_to_fsa (ctr, dtd);
	  if (NULL != el->ee_errmsg)
	    xmlparser_logprintf (parser, parser->validator.dv_curr_config.dc_fsa, 100+strlen (el->ee_name) + strlen(el->ee_errmsg),
	      "Syntax error in content model of element '%s': %s",
	      el->ee_name, el->ee_errmsg );
#if 0
#ifdef DEBUG
	  dump = ecm_print_fsm (ctr, dtd);
#endif
	  xml_dbg_printf (("\nConflict %d:\n%s", dtd->ed_els[ctr].ee_conflict, dump));
#endif
	}
      if (NULL == el->ee_states)
	el->ee_is_any = 1;
    }
  if (dtd->ed_generics)
    {
      char** name;
      xml_def_4_entity_t** repl_ent;
      id_hash_iterator_t hit;
      for (id_hash_iterator(&hit, dtd->ed_generics);
	   hit_next(&hit, (char**)&name, (char**)&repl_ent);
	   /* */)
      {
	if (repl_ent[0]->xd4e_valid)
	  continue;
	if (-1 == check_entity_recursiveness(parser, name[0], 0, name[0]))
	  return 0;
	repl_ent[0]->xd4e_valid = 1;
      }
    }
  dtd->ed_is_filled = 1;
  return 1;
}

/*
 *
 */
#ifdef DEBUG
#define SET_DETECTOR parser->last_err_detector = __LINE__
#else
#define SET_DETECTOR
#endif

#define RET_INVALID(X) do {\
  SET_DETECTOR; \
  xmlparser_logprintf (parser, XCFG_ERROR, 100, (X)); \
  return XML_TOK_INVALID;\
} while (0)

#define RET_INVALID_SOFT_IMPL(dest, ARGS) do {\
  SET_DETECTOR; \
  xmlparser_logprintf ARGS; \
  if (DEAD_HTML == parser->cfg.input_is_html) \
    goto dest; \
    return XML_TOK_INVALID;\
} while (0)

#define RET_INVALID_SOFT(X) RET_INVALID_SOFT_IMPL (character_data, (parser, XCFG_ERROR, 100, (X)))

#define RET_ERROR(X) do {\
  SET_DETECTOR; \
  xmlparser_logprintf (parser, XCFG_ERROR, 100, (X)); \
    return XML_TOK_ERROR;\
} while (0)

#define RET_ERROR_SOFT(X) do {\
  SET_DETECTOR; \
  xmlparser_logprintf (parser, XCFG_ERROR, 100, (X)); \
  if (DEAD_HTML == parser->cfg.input_is_html) \
    goto character_data; \
    return XML_TOK_ERROR;\
} while (0)

#define RET_ERROR_CONT(X) \
  if (DEAD_HTML == parser->cfg.input_is_html) \
    { \
      SET_DETECTOR; \
      xmlparser_logprintf (parser, XCFG_ERROR, 100, (X)); \
      c = get_tok_char(parser); \
      if ((0 > c) || ('>' == c)) break; else continue; \
    } \
  else \
    RET_ERROR(X)


xml_tok_type_t
get_dtd_token (vxml_parser_t *parser, int is_dtd_ge, char *recovery_flag_ret, unichar *c_ret)
{
  unichar c = c_ret[0];
	      int is_external_id = 0 ;
	      int is_internal_id = DTD_IN_ISREAD ;
	      int include_count = 0 ;
	      buf_ptr_t	pre_closebracket;   /* for inserting external DTD */
	      dtd_validator_t* validator = &parser->validator;
  recovery_flag_ret[0] = 'r';
	      SET_STATE(XML_A_DTD);

	      if (!parser->cfg.input_is_html)
		{
		  if (parser->state & XML_A_DTD)
		    CLR_STATE(XML_A_XMLDECL | XML_A_DTD);
		  else
		    RET_INVALID_SOFT("<!DOCTYPE ...> should not appear here due to XML structure rules");
		}
if (is_dtd_ge)
  goto process_internal_dtd_subset;

	      if (get_name (parser))
		{
		  lenmem_t name_buf;
		  brcpy (&name_buf, &parser->tmp.name);
		  validator->dv_root = name_buf.lm_memblock;
		}
	      else
		{
		  RET_INVALID_SOFT("Invalid name of top-level tag in <!DOCTYPE ...>");
		}
	      if (!test_ws (parser))
	        goto no_doctype_externalid;
	      if (test_case_string (parser, "PUBLIC", parser->cfg.input_is_html) && test_ws (parser))
		{
		  if (get_value (parser,1))
		    parser->tmp.dtd_puburi = box_brcpy (&parser->tmp.value);
		  test_ws (parser);
		  if (parser->cfg.input_is_html && test_string (parser, ">"))
		    { /* <!DOCTYPE PUBLIC "..."> is a special case, to be ignored entirely */
		      advance_ptr (parser); /* this is to skip whole !DOCTYPE text */
		      goto start_token_again;
		    }
		  if (get_value (parser, 1))
		    {
		      parser->tmp.dtd_sysuri = box_brcpy (&parser->tmp.value );
		      is_external_id = 1;
		      test_ws(parser);
		    }
		  else
		    {
		      /* This is for <!DOCTYPE HTML PUBLIC "trulala"> without system URI. */
		      int is_html_doctype;
		      lenmem_t name_buf;
		      brcpy (&name_buf, &parser->tmp.name);
		      is_html_doctype = !stricmp (name_buf.lm_memblock, "HTML");
		      dk_free_box (name_buf.lm_memblock);
		      if (!is_html_doctype && (DEAD_HTML != parser->cfg.input_is_html))
			RET_INVALID_SOFT("Missing URI of external DTD in <!DOCTYPE ... PUBLIC ...>");
		    }
		}
	      else if (test_case_string (parser, "SYSTEM", parser->cfg.input_is_html) && test_ws (parser))
		{
		  if (get_value (parser, 1))
		    parser->tmp.dtd_sysuri = box_brcpy (&parser->tmp.value);
		  else
		    RET_INVALID_SOFT("Missing URI of external DTD <!DOCTYPE ... SYSTEM ...>");
		  is_external_id = 1;
		  test_ws (parser);
		}
	      test_ws (parser);

no_doctype_externalid:
	      pre_closebracket = parser->pptr;
	      c = get_tok_char (parser);
	      if (c < 0)
	        {
	          if (is_dtd_ge)
	            goto compile;
		  RET_INVALID_SOFT("Closing '>' character not found in <!DOCTYPE ...> section");
		}

	      if (c == '>')
		{
		  if (is_external_id)
		    {
		      parser->pptr = pre_closebracket;
/* The enclosed code is not valid!
The config field dc_build_standalone instructs the parser to build standalone
even from non-standalone docs.
It never prevents the parser from reading additional resources, it may only
force the parser to read additional resources to resolve generic entities.
		      if (XCFG_ENABLE != parser->validator.dv_curr_config.dc_build_standalone)
			RET_INVALID_SOFT("External DTD is not allowed");
*/
		      if(!insert_external_dtd (parser))
			RET_INVALID_SOFT("Unable to read external DTD via URI of <!DOCTYPE ...>");
		    }
		  else
		    goto compile;
		}
	      if (c == '[')
		is_internal_id = DTD_IN_ISUNREAD;

	      if (!is_internal_id && !is_external_id)
		RET_INVALID_SOFT("<!DOCTYPE> contains neither reference to external DTD nor internal DTD");

process_internal_dtd_subset:
	      for (;;)
		{
		  test_ws (parser);

		  if (test_string (parser, "]]>"))
		    {
		      if (--include_count < 0)
			{
			  if (DEAD_HTML != parser->cfg.input_is_html)
			    RET_ERROR_SOFT ("More ]]> than <![...[ in the text of internal DTD");
			}
		      continue;
		    }
		  if ((DTD_IN_ISUNREAD == is_internal_id) &&
		      test_char (parser, ']'))
		    {
		      is_internal_id = DTD_IN_ISREAD;
		      if (is_external_id)
			{
/* The enclosed code is not valid! See the discussion above.
			  if (XCFG_ENABLE != parser->validator.dv_curr_config.dc_build_standalone)
			    RET_INVALID_SOFT("External DTD is not allowed");
*/
			  if (!insert_external_dtd (parser))
			    RET_ERROR_SOFT("Unable to read external part of DTD via URI of <!DOCTYPE ...>");
			}
		    }

		  if (is_internal_id)
		    {
		      if (test_char(parser, '>'))
			{
			  if ((!include_count) || (DEAD_HTML == parser->cfg.input_is_html))
			    break;
			  else
			    RET_ERROR_SOFT ("Not all conditional sections closed at the end of DTD");
			}
		    }

		  replace_entity (parser);
		  if (test_char (parser, '%'))
		    {	/* parameter entity reference */
		      process_peref (parser);
		      continue;
		    }

		  if (!test_char (parser, '<'))
		    {
		      if (is_dtd_ge)
		        {
			  c = get_tok_char (parser);
			  if (c < 0)
		            goto compile;
		        }
		      RET_ERROR_CONT("Syntax error: end of internal DTD or an '<' character or a parameter entity are allowed here");
		    }

		  if (test_char (parser, '?'))
		    {
		      if (!get_PI (parser,1))
			{ RET_ERROR_CONT("Generic syntax error in processing instruction inside internal DTD"); }
		    }
		  else if (test_char (parser, '!'))
		    {	/* comment or markup declaration */
		      if (test_string (parser, "--"))
			{
			  if (!get_comment (parser,0))
			    { RET_ERROR_CONT("Syntax error in <!--...--> comment"); }
			}
		      else if (test_string (parser, "ENTITY"))
			{	/* ENTITY declaration */
			  if (!test_ws2 (parser) ||
			      !get_entity_decl (parser) )
			    { RET_ERROR_CONT("Syntax error in <!ENTITY ...> declaration"); }
			}
		      else if (test_string (parser, "ELEMENT"))
			{	/* ELEMENT declaration */
			  if (!test_ws (parser) ||
			      !dtd_add_element_decl (validator, parser) )
			    { RET_ERROR_CONT("Syntax error in <!ELEMENT ...> declaration"); }
			}
		      else if (test_string (parser, "ATTLIST"))
			{	/* ATTLIST declaration */
			  xml_dbg_printf(("**ATTLIST\n"));
			  if (!test_ws (parser) ||
			      !dtd_add_attlist_decl (validator, parser) )
			    { RET_ERROR_CONT("Syntax error in <!ATTLIST ...> declaration"); }
			}
		      else if (test_string (parser, "NOTATION"))
			{	/* NOTATION declaration */
			  if (!test_ws (parser) ||
			      !get_notation_decl (parser) )
			    { RET_ERROR_CONT("Syntax error in <!NOTATION ...> declaration"); }
			}
		      else if (test_char (parser, '[' ))
			{
			  test_ws (parser);
			  if (dtd_add_include_section (parser))
			    include_count++;
			  else if (!dtd_add_ignore_section (parser))
			    { RET_ERROR_CONT("Syntax error in condition section, expected <![INCLUDE[ ... ]]> or <![IGNORE[ ... ]]>"); }
			}
		      else
			{ RET_ERROR_CONT("Syntax error in internal DTD, declaration or section expected after '<!' characters"); }
		    }
		  else
		    { RET_ERROR_CONT("Syntax error in internal DTD, '!' or '?' expected after '<' character"); }
		}

compile:
  if (dtd_compile (parser))
    goto ret_dtd;
  RET_INVALID_SOFT("Invalid DTD document");
    goto ret_dtd;

ret_dtd:
  return XML_TOK_DTD;

start_token_again:
  c_ret[0] = c;
  recovery_flag_ret[0] = 'a';
  return 0;

character_data:
  c_ret[0] = c;
  recovery_flag_ret[0] = 'c';
  return 0;

}


xml_tok_type_t
get_token (vxml_parser_t * parser)
{
  unichar c;
  buf_ptr_t rem, tmp;
  int name_found;
  int gt_found;
  int attr_dupe_found;
  html_tag_descr_t *start_tag_descr = NULL, *end_tag_descr;
  lenmem_t *lm_equal_tmp1, *lm_equal_tmp2;


start_token_again:

  rem = parser->pptr;

  c = get_tok_char (parser);

  if (c < 0)
    {
      SET_DETECTOR;
      if (xmlparser_is_ok (parser))
	return XML_TOK_FINISH;
      else
	return XML_TOK_ERROR;
    }

  switch (c)
    {
    case '<':
      /*parser->e_pos.start = parser->position;*/

      tmp = parser->pptr;
      c = get_tok_char (parser);
      if (c < 0)
	RET_INVALID_SOFT ("A tag or special section expected after '<' character");

      switch (c)
	{
	case '!':
	  if (parser->cfg.input_is_html)
	    {
	      if (
		(NULL != parser->inner_tag->ot_descr) &&
		parser->inner_tag->ot_descr->htmltd_is_ptext )
                {
                  if (test_string (parser, "--"))
                    { 
                      buf_ptr_t tmp2 = parser->pptr;
                      if (!get_to_string (parser, "-->"))
                        parser->pptr = tmp2;
                    }
                  else if (test_string (parser, "[CDATA["))
                    { 
                      buf_ptr_t tmp2 = parser->pptr;
                      if (!get_to_string (parser, "]]>"))
                        parser->pptr = tmp2;
                    }
		  goto character_data; /* no tags may be closed this way inside <SCRIPT> or <STYLE> */
                }
	    }
	  if (parser->cfg.auto_load_xmlschema_dtd)
	    parser->cfg.auto_load_xmlschema_dtd = 0;

	  if (test_case_string (parser, "DOCTYPE", parser->cfg.input_is_html) &&
	      test_ws (parser))
	    {	/* we have DTD */
	      xml_tok_type_t dtd_ret;
	      char recovery_flag = '\0';
	      dtd_ret = get_dtd_token (parser, 0, &recovery_flag, &c);
	      switch (recovery_flag)
	        {
	          case 'a': goto start_token_again;
	          case 'c': goto character_data;
	          case 'r': return dtd_ret;
	          default: GPF_T;
	        }
	    }
	  else if (test_string (parser, "[CDATA["))
	    {	/* we have CDATA section */
	      if (!parser->cfg.input_is_html)
		{
		  if (parser->state & XML_A_CHAR)
		    CLR_STATE(XML_A_XMLDECL | XML_A_DTD);
		  else
		    RET_INVALID_SOFT("<![CDATA[...]]> section is not allowed here by XML structure rules");
		}

	      if (get_to_string (parser, "]]>"))
		{
		  if (parser->pptr.ptr != parser->bptr.ptr)
		    handle_char_data(parser, parser->tmp.string.beg, parser->tmp.string.end);
		  return XML_TOK_CDATA;
		}
	      if (DEAD_HTML == parser->cfg.input_is_html)
		goto character_data;
	      RET_INVALID_SOFT ("End of <![CDATA[...]]> section not found");
	    }
	  else if (test_string (parser, "--"))
	    {	/* we have comments */
	      if (!parser->cfg.input_is_html)
		{
		  if (parser->state & XML_A_COMMENT)
		    CLR_STATE(XML_A_XMLDECL);
		  else
		    RET_INVALID_SOFT ("<!-- ... --> comment is not allowed here by XML structure rules");
		}

	      if (get_comment (parser,1))
		return XML_TOK_COMMENT;
	      if (DEAD_HTML == parser->cfg.input_is_html)
		goto character_data;
	      RET_INVALID_SOFT ("End of <!-- ... --> comment not found");
	    }
	  else if (parser->cfg.input_is_ge && (parser->state & XML_A_DTD))
	    {	/* we may have DTD as external GE */
	      xml_tok_type_t dtd_ret;
	      char recovery_flag = '\0';
	      parser->pptr = rem;
	      dtd_ret = get_dtd_token (parser, 1, &recovery_flag, &c);
	      switch (recovery_flag)
	        {
	          case 'a': goto start_token_again;
	          case 'c': goto character_data;
	          case 'r': return dtd_ret;
	          default: GPF_T;
	        }
	    }
	  else
	    RET_INVALID_SOFT("Syntax error: only <!DOCTYPE...> declaration, <![CDATA[...]]> section or <!--...--> comment may start with '<!' sequence") ;
	  break;
	case '?':	/* PI */
	  if (parser->cfg.input_is_html)
	    {
	      if (
		(NULL != parser->inner_tag->ot_descr) &&
		parser->inner_tag->ot_descr->htmltd_is_ptext )
		goto character_data; /* no tags may be closed this way inside <SCRIPT> or <STYLE> */
	    }
	  if (get_PI (parser,1))
	    return XML_TOK_PI;

	  /* error is already set */
	  RET_INVALID_SOFT("Generic syntax error in processing instruction");
	  break;
	case '/':	/* end-tag */
	  name_found = get_name (parser);
	  if (name_found)
	    {
	      test_ws (parser);
	      gt_found = test_char (parser, '>');
	    }
	  else
	    gt_found = 0;
	  if (!gt_found)
	    {
	      if (parser->cfg.input_is_html)
		{
	          if (
		    (NULL != parser->inner_tag->ot_descr) &&
		    parser->inner_tag->ot_descr->htmltd_is_ptext )
		    goto character_data; /* no tags may be closed this way inside <SCRIPT> or <STYLE> */
		}
	      if ((DEAD_HTML == parser->cfg.input_is_html) && name_found)
		{
		  if (parser->inner_tag != parser->tag_stack_holder)
		    {
		      if (parser->masters.end_element_handler)
			parser->masters.end_element_handler(parser->masters.user_data, parser->inner_tag->ot_name.lm_memblock);
		      pop_tag (parser);
		      return XML_TOK_END_TAG;
		    }
		  goto character_data;
		}
	      RET_INVALID_SOFT (name_found ? "No closing '>' found after the name of end tag" : "No name of end tag found after '</' characters");
	    }
	  if (!parser->cfg.input_is_html)
	    {
	      if (parser->inner_tag == parser->tag_stack_holder)
		RET_INVALID_SOFT ("More end tags than start tags");
	      if (brcmp (&parser->inner_tag->ot_name, &parser->tmp.name))
	        {
		  char *expected, *actual;
		  if (NULL != parser->tmp.flat_name.lm_memblock)
		    dk_free_box (parser->tmp.flat_name.lm_memblock);
		  brcpy (&parser->tmp.flat_name, &parser->tmp.name);
		  expected = parser->inner_tag->ot_name.lm_memblock;
		  actual = parser->tmp.flat_name.lm_memblock;
	          RET_INVALID_SOFT_IMPL (character_data,
                    (parser, XCFG_ERROR, 100 + strlen (actual) + strlen (expected),
	            "Tag nesting error: name '%s' of end tag does not match the name '%s' of start tag at line %d column %d",
	            actual, expected, parser->inner_tag->ot_pos.line_num, parser->inner_tag->ot_pos.col_c_num ));
	        }
	      if (parser->masters.end_element_handler)
		{
		  /*parser->e_pos.end = parser->position + parser->ch_size;*/
		  parser->masters.end_element_handler (parser->masters.user_data, parser->inner_tag->ot_name.lm_memblock);
		}
	      pop_tag (parser);
	      return XML_TOK_END_TAG;
			    }
	  /* At this point we know we are in HTML mode. */
	  normalize_name (&parser->tmp.name);
	  if (NULL != parser->tmp.flat_name.lm_memblock)
	    dk_free_box (parser->tmp.flat_name.lm_memblock);
	  brcpy (&parser->tmp.flat_name, &parser->tmp.name);
	  end_tag_descr = (html_tag_descr_t *)id_hash_get (html_tag_hash, (caddr_t)(&parser->tmp.flat_name.lm_memblock));
	  if ((NULL != end_tag_descr) && end_tag_descr->htmltd_is_empty)
	    goto start_token_again;
          if (parser->inner_tag == parser->tag_stack_holder)
	    {
	      if ((DEAD_HTML == parser->cfg.input_is_html) && (NULL != end_tag_descr))
			    {
		  SET_DETECTOR;
		  advance_ptr (parser);
		  goto start_token_again;
			    }
	      RET_INVALID_SOFT ("More end tags than start tags");
			}
	  if (!LM_EQUAL (&(parser->inner_tag->ot_name), &(parser->tmp.flat_name)))
	    {	/* tag names are different */
	      int end_tag_close_mask = ((NULL == end_tag_descr) ? 0 : end_tag_descr->htmltd_mask_m2);
	      opened_tag_t *stack_tail = parser->inner_tag;
	      int close_equal = 0;
	      if (
		(NULL != stack_tail->ot_descr) &&
		stack_tail->ot_descr->htmltd_is_ptext )
		goto character_data; /* no tags may be closed this way inside <SCRIPT> or <STYLE> */
	      /* Then of all we should find out whether the starting tag is available in the stack */
	      while (stack_tail != parser->tag_stack_holder)
		{
		  int own_mask;
		  if (0 == end_tag_close_mask)
		    {
		      stack_tail = parser->tag_stack_holder;
		      break;
		    }
		  own_mask = ((NULL == stack_tail->ot_descr) ? 0 : stack_tail->ot_descr->htmltd_mask_o);
		  if ((own_mask & end_tag_close_mask) != own_mask)
		    {
		      stack_tail = parser->tag_stack_holder;
		      break;
		    }
		  stack_tail--;
		  if (stack_tail == parser->tag_stack_holder)
		    break;
		  if (LM_EQUAL (&(stack_tail->ot_name), &(parser->tmp.flat_name)))
		    {
		      close_equal = 1;
		      break;
		    }
		}
	      if (stack_tail == parser->tag_stack_holder)
		{
		  if ((DEAD_HTML == parser->cfg.input_is_html) && (NULL != end_tag_descr))
		    {
		      SET_DETECTOR;
		      advance_ptr (parser);
		      goto start_token_again;
		    }
		  RET_INVALID_SOFT ("Tag nesting error: end tag cannot close any start tag");
		}
	      do
		{
		  if (parser->masters.end_element_handler)
		    {
		      /*parser->e_pos.end = parser->e_pos.start;*/
		      parser->masters.end_element_handler(parser->masters.user_data, parser->inner_tag->ot_name.lm_memblock);
		    }
		  pop_tag (parser);
		} while (parser->inner_tag != stack_tail);
	      if (close_equal)
		{
		  if (parser->masters.end_element_handler)
		    {
		      /*parser->e_pos.end = parser->position + parser->ch_size;*/
		      parser->masters.end_element_handler (parser->masters.user_data, parser->inner_tag->ot_name.lm_memblock);
		    }
	          pop_tag (parser);
		}
	    }
	  else
	    {
	      if (parser->masters.end_element_handler)
		{
		  /*parser->e_pos.end = parser->position + parser->ch_size;*/
		  parser->masters.end_element_handler (parser->masters.user_data, parser->inner_tag->ot_name.lm_memblock);
		}
	      pop_tag (parser);
	    }
	  return XML_TOK_END_TAG;
	  break;
	default:	/* start-tag or empty-tag*/
	  if (parser->cfg.auto_load_xmlschema_dtd)
	    {
	      parser->pptr = rem;
	      insert_external_xmlschema_dtd (parser);
	      parser->cfg.auto_load_xmlschema_dtd = 0;
	      goto start_token_again;
	    }
	  parser->pptr = tmp;	/* unget last char */

	  if (parser->cfg.input_is_html)
	    {
	      if (
		(NULL != parser->inner_tag->ot_descr) &&
		parser->inner_tag->ot_descr->htmltd_is_ptext )
		{
		  rem = parser->pptr;
		  goto character_data_without_backstep; /* no tags may be opened inside <SCRIPT> or <STYLE> */
		}
	    }
	  else
	    {
	      if (parser->state & XML_A_ELEMENT)
		{
		  CLR_STATE(XML_A_XMLDECL | XML_A_DTD);
		  SET_STATE(XML_A_CHAR | XML_ST_NOT_EMPTY);
		}
	      else
		RET_INVALID_SOFT("Start or empty tag is not allowed here by XML structure rules");
	    }

	  if (get_name (parser))
	    {
	      int ws_required = 1;
	      rem = parser->pptr;
	      if (parser->cfg.input_is_html)
		{
		  int start_tag_should_close;
		  const char *htmlname;
		  normalize_name (&parser->tmp.name);
		  if (NULL != parser->tmp.flat_name.lm_memblock)
		    dk_free_box (parser->tmp.flat_name.lm_memblock);
		  brcpy (&parser->tmp.flat_name, &parser->tmp.name);
		  htmlname = parser->tmp.flat_name.lm_memblock;
		  start_tag_descr = (html_tag_descr_t *)id_hash_get (html_tag_hash, (caddr_t)(&htmlname));
		  parser->tmp.tag_descr = start_tag_descr;
		  start_tag_should_close = ((NULL == start_tag_descr) ? 0 : start_tag_descr->htmltd_mask_s1);
		  if (0 != start_tag_should_close)
		    { /* This tag should close some other tags if possible */
		      int start_tag_may_close = start_tag_descr->htmltd_mask_m1;
		      opened_tag_t *stack_tail;
		      opened_tag_t *last_good_close = parser->tag_stack_holder;
		      for (stack_tail = parser->inner_tag; stack_tail != parser->tag_stack_holder; stack_tail--)
			{
			  int own_mask = ((NULL == stack_tail->ot_descr) ? (HTMLTM_BOX_FOR_BLOCKS | HTMLTM_BOX_FOR_INLINE) : stack_tail->ot_descr->htmltd_mask_o);
			  if ((own_mask & start_tag_may_close) != own_mask)
			    break;
			  if ((own_mask & start_tag_should_close) == own_mask)
			      last_good_close = stack_tail;
		        }
		      if (last_good_close != parser->tag_stack_holder)
			{
			  last_good_close--;
			  while (parser->inner_tag != last_good_close)
			    {
			      if (parser->masters.end_element_handler)
				{
				  /*parser->e_pos.end = parser->e_pos.start;*/
				  parser->masters.end_element_handler (parser->masters.user_data, parser->inner_tag->ot_name.lm_memblock);
				}
			      pop_tag (parser);
			    }
			}
		    }
		}
	      else
		{
		  if (NULL != parser->tmp.flat_name.lm_memblock)
		    dk_free_box (parser->tmp.flat_name.lm_memblock);
		  brcpy (&parser->tmp.flat_name, &parser->tmp.name);
		}
	      if (parser->inner_tag >= (parser->tag_stack_holder + (XML_PARSER_MAX_DEPTH-1)))
		RET_INVALID ("Too many unclosed starting tags");
	      free_attr_array (parser);
	      attr_dupe_found = 0;
	      parser->attrdata.local_nsdecls = parser->attrdata.all_nsdecls + parser->attrdata.all_nsdecls_count;
	      parser->attrdata.local_nsdecls_count = 0;
	      for (;;)
		{
		  /* rus 16/10/02 whitespaces must be in attlist id 123 */
		  int must_be_finished = 0;
		  if (ws_required && !test_ws (parser))
		    must_be_finished = 1;
                  if (parser->msglog_ctrs [XCFG_FATAL])
                    return XML_TOK_INVALID;
		  if (test_char (parser, '>'))
		    {
		      if (parser->masters.start_element_handler)
			{
			  if (attr_dupe_found && (FINE_XML == parser->cfg.input_is_html))
			    {
			      RET_INVALID ("Duplicate names of attributes found in opening tag");
			    }
			  push_tag (parser);
			  /*parser->e_pos.end = parser->position + parser->ch_size;*/
			  parser->masters.start_element_handler (parser->masters.user_data,
						     parser->inner_tag->ot_name.lm_memblock,
						     &(parser->attrdata) );
			}
		      else
			push_tag (parser);
		      if (parser->cfg.input_is_html &&
			  (NULL != start_tag_descr) && start_tag_descr->htmltd_is_empty)
			{
			  if (parser->masters.end_element_handler)
			    {
			      /*parser->e_pos.start = parser->e_pos.end;*/
			      parser->masters.end_element_handler (parser->masters.user_data, parser->inner_tag->ot_name.lm_memblock);
			    }
			  pop_tag (parser);
			  return XML_TOK_EMPTY_TAG;
			}
		      return XML_TOK_START_TAG;
		    }
		  if (test_string (parser, "/>"))
		    {
		      if (parser->masters.start_element_handler)
			{
			  if (attr_dupe_found && (FINE_XML == parser->cfg.input_is_html))
			    {
			      RET_INVALID ("Duplicate names of attributes found in empty <... /> tag");
			    }
			  push_tag (parser);
			  /*parser->e_pos.end = parser->position + parser->ch_size;*/
			  parser->masters.start_element_handler ( parser->masters.user_data,
						     parser->inner_tag->ot_name.lm_memblock,
						     &(parser->attrdata) );
			}
		      else
		        push_tag (parser);
		      if (parser->masters.end_element_handler)
			{
			  /*parser->e_pos.end = parser->position + parser->ch_size;*/
			  parser->masters.end_element_handler (parser->masters.user_data,
						   parser->inner_tag->ot_name.lm_memblock);
			}
		      pop_tag (parser);
		      return XML_TOK_EMPTY_TAG;
		    }
		  /* rus 16/10/02 id 123 */
		  if (must_be_finished && DEAD_HTML != parser->cfg.input_is_html)
		    {
		      RET_INVALID_SOFT ("Syntax error in the attribute list (no whitespace)");
		    }

		  /* getting attribute */
		  if (get_name (parser))
		    {
		      if (parser->cfg.input_is_html)
			normalize_name (&parser->tmp.name);
		      test_ws (parser);
		      ws_required = 0;
		      if (test_char (parser, '='))
			{
			  test_ws (parser);
			  if (!get_attr_value (parser,0))
			    {
			      rem = parser->pptr;
			      RET_INVALID_SOFT ("Syntax error in the value of attribute");
			    }
			  ws_required = 1;
			}
		      else
		        {
			  parser->tmp.value = parser->tmp.name;
			  if (!parser->cfg.input_is_html)
			    xmlparser_logprintf (parser, XCFG_ERROR, 100, "Attribute name without value is allowed in HTML but not in XML");
			}
		      if (parser->attrdata.local_attrs_count > XML_PARSER_MAX_ATTRS)
			xmlparser_logprintf (parser, XCFG_ERROR, 100, "Too many attributes in the tag.");
		      else
			{
			  lenmem_t raw_name;
			  lenmem_t raw_value;
			  buf_range_t * name = &parser->tmp.name;
			  buf_range_t * value = &parser->tmp.value;
			  int attr_ctr;
			  tag_attr_t *attr;
			  brcpy (&raw_name, name);
			  brcpy (&raw_value, value);
			  if (!strncmp (raw_name.lm_memblock, "xmlns", 5))
			    {
			      nsdecl_t *ns = parser->nsdecl_array + parser->attrdata.all_nsdecls_count;
			      if (parser->attrdata.all_nsdecls_count >= XML_PARSER_MAX_NSDECLS)
				{
				  dk_free_box (raw_name.lm_memblock);
				  dk_free_box (raw_value.lm_memblock);
				  rem = parser->pptr;
				  RET_INVALID_SOFT ("Too many namespace declarations");
				}
			      if (':' == raw_name.lm_memblock[5])
				{
				  ns->nsd_prefix = box_dv_short_nchars (raw_name.lm_memblock + 6, raw_name.lm_length - 6);
				}
			      else if ('\0' == raw_name.lm_memblock[5])
				{
				  ns->nsd_prefix = uname___empty;
				}
			      else
				{
				  if (DEAD_HTML == parser->cfg.input_is_html)
				    goto attribute_plain; /* see below */
				  dk_free_box (raw_name.lm_memblock);
				  dk_free_box (raw_value.lm_memblock);
				  RET_INVALID ("Invalid namespace declaration");
				}
			      ns->nsd_uri = dtd_normalize_attr_val (parser, raw_value.lm_memblock, 0);
			      ns->nsd_tag = parser->inner_tag + 1;
			      if (parser->fill_ns_2dict &&
			        ((uname___empty == ns->nsd_prefix) ?
                                  ((parser->inner_tag == parser->tag_stack_holder) &&
                                   ('\0' != ns->nsd_uri[0]) &&
                                   (0 == parser->cfg.input_is_ge) &&
                                   (0 == parser->cfg.input_is_html) &&
                                   (0 == parser->cfg.input_is_xslt) ) :
				  (('n' != ns->nsd_prefix[0]) || !isdigit(ns->nsd_prefix[1])) ) /* This is for 'n0', 'n2' etc... */
				 )
				xml_ns_2dict_add(&(parser->ns_2dict), ns);
			      parser->attrdata.all_nsdecls_count++;
			      parser->attrdata.local_nsdecls_count++;
/* In nice interface, xmlns attributes should not appear in the list of all attributes at all.
so there must be #if 1 here, not #if 0. But it will be #if 0 for next few months :) */
#if 1
			      dk_free_box (raw_name.lm_memblock);
			      goto attribute_completed; /* see below */
#endif
			    }
attribute_plain:
			  attr_ctr = parser->attrdata.local_attrs_count;
			  while (attr_ctr--)
			    {
			      attr = parser->tmp.attr_array + attr_ctr;
			      if (LM_EQUAL (&attr->ta_raw_name, &raw_name))
				{
				  attr_dupe_found = 1;
				  dk_free_box (raw_name.lm_memblock);
				  dk_free_box (attr->ta_value);
				  goto attribute_found; /* see below */
				}
			    }
			  if (parser->attrdata.local_attrs_count >= XML_PARSER_MAX_ATTRS)
			    {
			      dk_free_box (raw_name.lm_memblock);
			      if (DEAD_HTML == parser->cfg.input_is_html)
				goto attribute_completed; /* see below */
			      dk_free_box (raw_value.lm_memblock);
			      RET_INVALID ("Too many attributes");
			    }
			  attr = parser->tmp.attr_array + (parser->attrdata.local_attrs_count++);
			  attr->ta_raw_name = raw_name;
attribute_found:
			  attr->ta_value = dtd_normalize_attr_val (parser, raw_value.lm_memblock, 0);
attribute_completed:
			  dk_free_box (raw_value.lm_memblock);
			}
		    }
		  else
		    {
		      if (DEAD_HTML == parser->cfg.input_is_html)
			{
			  SET_DETECTOR;
			  test_char (parser, '=');
			  if (get_value (parser,0))
			    continue;
			  c = get_tok_char(parser);
			  if (0 > c) break; else continue;
			}
		      RET_INVALID_SOFT ("Syntax error in opening tag: ending '>' or attribute=value pair expected");
		    }
		}
	    }
	  if (DEAD_HTML == parser->cfg.input_is_html)
	    {
	      rem = parser->pptr;
	      goto character_data;
	    }
	  RET_INVALID_SOFT ("A tag, processing instruction or special <!...> item expected after '<' character");
	}
      break;	/* case '<' */
    case '&':
      if (!parser->cfg.input_is_html)
	{
	  if (!(parser->state & XML_A_CHAR))
	    {	/* "standalone" (not inside markup)  entity reference is
		 * allowed only inside a root element, where character
		 * data are allowed */
	      RET_INVALID_SOFT ("Entity reference is not allowed here by XML structure rules");
	    }
	}

      tmp = parser->pptr;
      if (test_char_ref (parser) < 0)
	{
	  if (0 != parser->msglog_ctrs[XCFG_ERROR])
	    RET_INVALID_SOFT("Generic syntax error in entity reference");
	  /* general entity reference */
	  parser->pptr = tmp;
	  if (get_name (parser))
	    {
	      if (test_char (parser, ';'))
		{		/* valid entity reference */
		  if (parser->masters.entity_ref_handler)
		    {
/* IvAn/ParseDTD/000721 Reference should be located in dictionary of generic entities */
		      lenmem_t ename; /* name of the reference */
		      id_hash_t *dict;
		      caddr_t hash_val;
		      xml_def_4_entity_t *ent;
		      xml_dbg_printf(("{get_tok:entity "));
		      brcpy (&ename, &parser->tmp.name);
		      dict = parser->validator.dv_dtd->ed_generics;
		      if (NULL == dict)
			ent = NULL;
		      else
			{
			  hash_val = id_hash_get (dict, (caddr_t)(&ename.lm_memblock));
			  ent = ((NULL == hash_val) ? NULL : ((xml_def_4_entity_t **)(void **)(hash_val))[0]);
			}
		      if (XCFG_DISABLE == parser->validator.dv_curr_config.dc_build_standalone)
			{
			  parser->masters.entity_ref_handler (parser->masters.user_data,
				ename.lm_memblock,
				ename.lm_length,
				0, /* = not parameter entity ref */
				ent);
		          dk_free_box (ename.lm_memblock);
			}
		      else
			{
			  parser->pptr = tmp;
			  if (replace_entity_common (parser, 1 /* = GE */, ent, rem, 1))
			    {
			      parser->pptr=rem;
			      dk_free_box (ename.lm_memblock);
			      goto start_token_again;
			    }
			  if (parser->cfg.input_is_html)
			    {
			      dk_free_box (ename.lm_memblock);
			      xmlparser_logprintf (parser, parser->validator.dv_curr_config.dc_ge_unknown, 100, "Undefined generic entity reference");
			      handle_char_data(parser, parser->bptr, parser->pptr);
			      return XML_TOK_CHAR_DATA;
			    }
			  else
			    {
			      parser->masters.entity_ref_handler (parser->masters.user_data,
				ename.lm_memblock,
				ename.lm_length,
				0, /* = not parameter entity ref */
				ent);
		              dk_free_box (ename.lm_memblock);
			      xmlparser_logprintf (parser, parser->validator.dv_curr_config.dc_ge_unknown, 100, "Undefined generic entity reference");
			    }
			}
		      xml_dbg_printf(("- done}"));
		    }
		  return XML_TOK_ENTITY_REF;
		}
	    }
	  if (parser->cfg.input_is_html)
	    {			/* invalid entity refs are char data */
	      handle_char_data(parser, parser->bptr, parser->pptr);
	      return XML_TOK_CHAR_DATA;
	    }
	  RET_INVALID_SOFT ("Entity reference expected after '&' character");
	}
      else
	{		/* c contains a value of char ref */
	  parser->pptr = tmp;
	}

      /* fall through for char reference and predefined entities */
    default:	/* character data */
character_data:
      /* parser->errmsg = NULL; */
      tmp = rem;
character_data_without_backstep:
      if (!parser->cfg.input_is_html)
	{
	  if (!(parser->state & XML_A_CHAR))
	    {
	      if (c == 0x20 || c == 0x9 || c == 0xA || c == 0xD)
		{	/* whitespace is allowed before root element */
		  CLR_STATE(XML_A_XMLDECL);
		  test_ws (parser);
		  return XML_TOK_WS;
		}
	      RET_INVALID ("Character data are not allowed here by XML structure rules");
	    }
	}

      for (;;)
	{
	  if (c < 0)
	    {
	      if (parser->pptr.ptr != parser->bptr.ptr)
	        {
		  handle_char_data(parser, parser->bptr, parser->pptr);
		  return XML_TOK_CHAR_DATA;
		}
              if ((UNICHAR_EOD == c) && xmlparser_is_ok (parser))
	        return XML_TOK_FINISH;
	      return XML_TOK_ERROR;
	    }

	  if (c == '<')
	    {
	      parser->pptr = tmp;
	      if (parser->pptr.ptr != parser->bptr.ptr)
		handle_char_data(parser, parser->bptr, parser->pptr);
	      return XML_TOK_CHAR_DATA;
	    }
	  else if (c == '&')
	    {		/* entity or char reference */
	      c = test_char_ref (parser);
	      if (c < 0)
		{	/* general entity reference or error*/
		  parser->pptr = tmp;
		  if (parser->pptr.ptr == rem.ptr)
		    c = get_tok_char (parser); /* to skip invalid '&' */
		  if (parser->pptr.ptr != parser->bptr.ptr)
		    handle_char_data(parser, parser->bptr, parser->pptr);
		  return XML_TOK_CHAR_DATA;
		}
	      else
		{
		  /*
		   * Predefined or char reference - put
		   * replacement char as a CHAR DATA instead
		   * of the reference.
		   */
		  lenmem_t char_buffer;
		  char *encode_end;
		  brick_t *char_brick;
		  char_buffer.lm_memblock = dk_alloc_box (MAX_UTF8_CHAR+1, DV_STRING);
		  encode_end = eh_encode_char__UTF8 (c, char_buffer.lm_memblock, char_buffer.lm_memblock+eh__UTF8.eh_maxsize);
		  char_buffer.lm_length = encode_end - char_buffer.lm_memblock;
		  insert_buffer (parser, &tmp, &parser->pptr, &char_buffer, &parser->curr_pos, &parser->curr_pos);
		  char_brick = tmp.buf->next;
		  char_brick->data_begin = char_brick->beg;
		  parser->curr_pos_ptr = parser->pptr = tmp;
#ifdef DEBUG
		  validate_parser_bricks (parser);
#endif
		  get_tok_char (parser);
		};
	    }

	  if (parser->pptr.ptr == parser->pptr.buf->end)
	    {
	      handle_char_data(parser, parser->bptr, parser->pptr);
	      advance_ptr (parser);
	    }
          if ((0 != parser->src_eh->eh_stable_ascii7) && (parser->pptr.ptr == parser->eptr.ptr))
            skip_plain_tok_chars (parser, VXML_CHARPROP_8BIT | VXML_CHARPROP_TEXTEND | VXML_CHARPROP_CTRL | VXML_CHARPROP_ENTBEGIN);
	  tmp = parser->pptr;
	  c = get_tok_char (parser);
	}
    }
  return XML_TOK_ERROR; /* Never happen */
#undef L_RET_ERR
}

