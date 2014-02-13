/*
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
 *  
*/
#include "langfunc.h"
#include <stdarg.h>

/* WIDE identity */

#define next_wchar_begin(ptr) ((char *)( ((wchar_t *)(ptr)) + 1 ))

unichar eh_decode_char__widewrapper(__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  if (next_wchar_begin(src_begin_ptr[0]) > src_buf_end)
    {
      if (src_begin_ptr[0] > src_buf_end)
	return UNICHAR_EOD;
      return UNICHAR_NO_DATA;
    }
  else
    {
      const wchar_t *src_begin_wptr = (const wchar_t *)(src_begin_ptr[0]);
      unsigned char prefetch[MAX_ENCODED_CHAR];
      unsigned char *prefetch_tail = prefetch;
      unsigned char *prefetch_end = prefetch;
      size_t prefetch_ctr;
      unichar res_uchar;
      va_list tail;
      encoding_handler_t *my_eh;
      encoding_handler_t *inner_eh;
      int *state_ptr;
      va_start (tail, src_buf_end);
      my_eh = va_arg (tail, encoding_handler_t *);
      state_ptr = va_arg (tail, int *);
      va_end (tail);
      inner_eh = (encoding_handler_t *)(my_eh->eh_appdata);
      for (prefetch_ctr = 0;
	((prefetch_ctr < inner_eh->eh_maxsize) &&
	  next_wchar_begin (src_begin_wptr+prefetch_ctr) <= src_buf_end);
	prefetch_ctr++ )
        {
	  wchar_t wc = src_begin_wptr[prefetch_ctr];
	  if (wc & ~0xFF)
	    return UNICHAR_BAD_ENCODING;
	  (prefetch_end++)[0] = (unsigned char)wc;
	}
      res_uchar = inner_eh->eh_decode_char ((const char **)(&prefetch_tail), (char *)prefetch_end, inner_eh, state_ptr);
      src_begin_ptr[0] = (char *)(((wchar_t *)(src_begin_ptr[0])) + (prefetch_tail-prefetch));
      return res_uchar;
    }
}


char *eh_encode_char__widewrapper (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{
  if (char_to_put < 0)
    return tgt_buf;
  if (tgt_buf_end < next_wchar_begin(tgt_buf))
    return (char *)UNICHAR_NO_ROOM;
  ((wchar_t *)(tgt_buf))[0] = (wchar_t)('?');
  return next_wchar_begin(tgt_buf);
}


int eh_decode_buffer__widewrapper (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  const wchar_t *src_begin_wptr;
  unsigned char prefetch[MAX_ENCODED_CHAR];
  unsigned char *prefetch_tail;
  unsigned char *prefetch_end;
  size_t prefetch_ctr;
  unichar res_uchar;
  va_list tail;
  encoding_handler_t *my_eh;
  encoding_handler_t *inner_eh;
  int *state_ptr;
  va_start (tail, src_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  state_ptr = va_arg (tail, int *);
  va_end (tail);
  inner_eh = (encoding_handler_t *)(my_eh->eh_appdata);
  while((tgt_buf_len>0) && (next_wchar_begin(src_begin_ptr[0]) <= src_buf_end))
    {
      src_begin_wptr = (const wchar_t *)(src_begin_ptr[0]);
      prefetch_tail = prefetch;
      prefetch_end = prefetch;
      for (prefetch_ctr = 0;
	((prefetch_ctr < inner_eh->eh_maxsize) &&
	  next_wchar_begin (src_begin_wptr+prefetch_ctr) <= src_buf_end);
	prefetch_ctr++ )
        {
	  wchar_t wc = src_begin_wptr[prefetch_ctr];
	  if (wc & ~0xFF)
	    return UNICHAR_BAD_ENCODING;
	  (prefetch_end++)[0] = (unsigned char)wc;
	}
      res_uchar = inner_eh->eh_decode_char ((const char **)(&prefetch_tail), (char *)prefetch_end, inner_eh, state_ptr);
      switch (res_uchar)
	{
	case UNICHAR_BAD_ENCODING:
	case UNICHAR_EOD:
	  return res_uchar;
	case UNICHAR_NO_DATA:
	  src_begin_ptr[0] = (char *)(((wchar_t *)(src_begin_ptr[0])) + (prefetch_tail-prefetch));
	  return res;
	default: /* nop */ ;
	}
      src_begin_ptr[0] = (char *)(((wchar_t *)(src_begin_ptr[0])) + (prefetch_tail-prefetch));
      (tgt_buf++)[0] = res_uchar;
      tgt_buf_len--;
      res++;
    }
  if (src_begin_ptr[0] > src_buf_end)
    return UNICHAR_EOD;
  return res;
}


int eh_decode_buffer_to_wchar__widewrapper (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  const wchar_t *src_begin_wptr;
  unsigned char prefetch[MAX_ENCODED_CHAR];
  unsigned char *prefetch_tail;
  unsigned char *prefetch_end;
  size_t prefetch_ctr;
  unichar res_uchar;
  va_list tail;
  encoding_handler_t *my_eh;
  encoding_handler_t *inner_eh;
  int *state_ptr;
  va_start (tail, src_buf_end);
  my_eh = va_arg (tail, encoding_handler_t *);
  state_ptr = va_arg (tail, int *);
  va_end (tail);
  inner_eh = (encoding_handler_t *)(my_eh->eh_appdata);
  while((tgt_buf_len>0) && (next_wchar_begin(src_begin_ptr[0]) <= src_buf_end))
    {
      src_begin_wptr = (const wchar_t *)(src_begin_ptr[0]);
      prefetch_tail = prefetch;
      prefetch_end = prefetch;
      for (prefetch_ctr = 0;
	((prefetch_ctr < inner_eh->eh_maxsize) &&
	  next_wchar_begin (src_begin_wptr+prefetch_ctr) <= src_buf_end);
	prefetch_ctr++ )
        {
	  wchar_t wc = src_begin_wptr[prefetch_ctr];
	  if (wc & ~0xFF)
	    return UNICHAR_BAD_ENCODING;
	  (prefetch_end++)[0] = (unsigned char)wc;
	}
      res_uchar = inner_eh->eh_decode_char ((const char **)(&prefetch_tail), (char *)prefetch_end, inner_eh, state_ptr);
      switch (res_uchar)
	{
	case UNICHAR_BAD_ENCODING:
	case UNICHAR_EOD:
	  return res_uchar;
	case UNICHAR_NO_DATA:
	  src_begin_ptr[0] = (char *)(((wchar_t *)(src_begin_ptr[0])) + (prefetch_tail-prefetch));
	  return res;
	default:
          if (res & ~0xffffl)
            return UNICHAR_OUT_OF_WCHAR;
	}
      src_begin_ptr[0] = (char *)(((wchar_t *)(src_begin_ptr[0])) + (prefetch_tail-prefetch));
      (tgt_buf++)[0] = res_uchar;
      tgt_buf_len--;
      res++;
    }
  if (src_begin_ptr[0] > src_buf_end)
    return UNICHAR_EOD;
  return res;
}


char *eh_encode_buffer__widewrapper (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  unichar char_to_put;
  if ((((wchar_t *)tgt_buf_end) - ((wchar_t *)tgt_buf)) < (src_buf_end-src_buf))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char_to_put = (src_buf++)[0];
      ((wchar_t *)(tgt_buf))[0] = (wchar_t)('?');
      tgt_buf = next_wchar_begin(tgt_buf);
    }
  return tgt_buf;
}


char *eh_encode_wchar_buffer__widewrapper (const wchar_t *src_buf, const wchar_t *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  unichar char_to_put;
  if ((((wchar_t *)tgt_buf_end) - ((wchar_t *)tgt_buf)) < (src_buf_end-src_buf))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char_to_put = (src_buf++)[0];
      ((wchar_t *)(tgt_buf))[0] = (wchar_t)('?');
      tgt_buf = next_wchar_begin(tgt_buf);
    }
  return tgt_buf;
}


encoding_handler_t *eh_wide_from_narrow (encoding_handler_t *eh_narrow)
{
  encoding_handler_t *res = NULL;
#ifndef __NO_LIBDK
  static dk_mutex_t *mtx = NULL;
  static dk_hash_t *cache = NULL;
  if (NULL == mtx)
    {
      mtx = mutex_allocate();
      cache = hash_table_allocate(31);
    }
  mutex_enter (mtx);
  res = (encoding_handler_t *) gethash (eh_narrow, cache);
  if (NULL != res)
    goto res_is_prepared;
#endif
  res = (encoding_handler_t *)dk_alloc(sizeof(encoding_handler_t));
  memcpy (res, eh_narrow, sizeof(encoding_handler_t));
  res->eh_minsize *= sizeof (wchar_t);
  res->eh_maxsize *= sizeof (wchar_t);
  res->eh_byteorder = 0;
  res->eh_encodedlangs = NULL;
  res->eh_appdata = eh_narrow;
  res->eh_decode_char = eh_decode_char__widewrapper;
  res->eh_decode_buffer = eh_decode_buffer__widewrapper;
  res->eh_decode_buffer_to_wchar = eh_decode_buffer_to_wchar__widewrapper;
  res->eh_encode_char = eh_encode_char__widewrapper;
  res->eh_encode_buffer = eh_encode_buffer__widewrapper;
  res->eh_encode_wchar_buffer = eh_encode_wchar_buffer__widewrapper;
#ifndef __NO_LIBDK
  sethash (eh_narrow, cache, res);  
res_is_prepared:
  mutex_leave (mtx);
#endif
  return res;
}

