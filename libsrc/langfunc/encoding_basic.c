/*
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
#include "langfunc.h"



/* UTF-8 and UTF-8-STRICT */


unichar eh_decode_char__UTF8_QR (__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  unichar res;
  if (*src_begin_ptr >= src_buf_end)
    return UNICHAR_EOD;
  if ((src_begin_ptr[0][0] & (unsigned char)0x80) == 0)
    {
      res = ((unsigned char **)src_begin_ptr)[0][0];
      src_begin_ptr[0] += 1;
      return res;
    }
  if ((src_begin_ptr[0][0] & (unsigned char)0xc0) != (unsigned char)0xc0)
    {
      unsigned char res = src_begin_ptr[0][0];
      src_begin_ptr[0] += 1;
      return res;
    }
  else
    {
      int n = 0;
      char mask = 0x7f;
      char c = src_begin_ptr[0][0];
      while (c & (unsigned char)0x80)
	{
	  c <<= 1;
	  ++n;
	  mask >>= 1;
	}
      if (src_buf_end - *src_begin_ptr < n)
	return UNICHAR_NO_DATA;	/* we have a partial char at the end */
      res = *(*src_begin_ptr)++ & mask;
      --n;
      for (; n > 0; --n)
	{
	  if ((src_begin_ptr[0][0] & 0xc0) != 0x80)
	    {
	      res = ((unsigned char **)src_begin_ptr)[0][0];
	      return res;
	    }
	  res = (res << 6) + (*(*src_begin_ptr)++ & 0x3f);
	}
      return ((res & ~0x7fffffff) ? (((unsigned int)(0x80) | res) & 0x7fffffff) : res);
    }
  return 0;
}


unichar eh_decode_char__UTF8 (__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  unichar res;
  if (*src_begin_ptr >= src_buf_end)
    return UNICHAR_EOD;
  if ((**src_begin_ptr & (unsigned char)0x80) == 0)
    {
      res = ((unsigned char **)src_begin_ptr)[0][0];
      src_begin_ptr[0] += 1;
      return res;
    }
  if ((**src_begin_ptr & (unsigned char)0xc0) != (unsigned char)0xc0)
    {
      return UNICHAR_BAD_ENCODING;
    }
  else
    {
      int n = 0;
      unichar res;
      char mask = 0x7f;
      char c = **src_begin_ptr;
      while (c & (unsigned char)0x80)
	{
	  c <<= 1;
	  ++n;
	  mask >>= 1;
	}
      if (src_buf_end - *src_begin_ptr < n)
	return UNICHAR_NO_DATA;	/* we have a partial char at the end */
      res = *(*src_begin_ptr)++ & mask;
      --n;
      for (; n > 0; --n)
	{
	  if ((**src_begin_ptr & 0xc0) != 0x80)
	    return UNICHAR_BAD_ENCODING;
	  res = (res << 6) + (*(*src_begin_ptr)++ & 0x3f);
	}
      return res;
    }
  return 0;
}


char *eh_encode_char__UTF8 (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{
  int n = 0;
  unsigned int mask = 0x80;
  unichar tmp = char_to_put;
  char * ret;
  if (! (char_to_put & ~0x7F))
    { /* Most popular case should be handled extremely effective */
      if (tgt_buf >= tgt_buf_end)
	return (char *)UNICHAR_NO_ROOM;
      *tgt_buf++ = (char) char_to_put;
      return tgt_buf;
    }
  if (char_to_put < 0)
    return tgt_buf;
  while (tmp)
    {
      tmp >>= 1;
      ++n;
    }
  n = (n - 2) / 5;	/* number of additional octets */
  if (tgt_buf_end - tgt_buf < n + 1)
    return (char *)UNICHAR_NO_ROOM;
  ret = tgt_buf + n + 1;
  for (; n > 0; --n)
    {
      tgt_buf[n] = (char)((char_to_put & 0x3f) | 0x80);
      char_to_put >>= 6;
      mask = (mask >> 1) | 0x80;
    }
  *tgt_buf = (unsigned char)mask;
  mask = (~mask) >> 1;
  *tgt_buf |= (char)char_to_put & (unsigned char)mask;
  return ret;
}


int eh_decode_buffer__UTF8_QR (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while(tgt_buf_len>0)
    {
      unichar curr = eh_decode_char__UTF8_QR (src_begin_ptr, src_buf_end);
      switch(curr)
	{
	case UNICHAR_EOD:
	  return res;
	case UNICHAR_NO_DATA:
	case UNICHAR_BAD_ENCODING:
	  if (res)
	    return res;
	  return UNICHAR_BAD_ENCODING;
	default:
	  (tgt_buf++)[0] = curr;
	  tgt_buf_len--;
	  res++;
	}

    }
  return res;
}


int eh_decode_buffer__UTF8 (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while(tgt_buf_len>0)
    {
      unichar curr = eh_decode_char__UTF8 (src_begin_ptr, src_buf_end);
      switch(curr)
	{
	case UNICHAR_EOD:
	  return res;
	case UNICHAR_NO_DATA:
	case UNICHAR_BAD_ENCODING:
	  if (res)
	    return res;
	  return UNICHAR_BAD_ENCODING;
	default:
	  (tgt_buf++)[0] = curr;
	  tgt_buf_len--;
	  res++;
	}

    }
  return res;
}


int eh_decode_buffer_to_wchar__UTF8_QR (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while(tgt_buf_len>0)
    {
      unichar curr = eh_decode_char__UTF8_QR (src_begin_ptr, src_buf_end);
      switch(curr)
	{
	case UNICHAR_EOD:
	  return res;
	case UNICHAR_NO_DATA:
	case UNICHAR_BAD_ENCODING:
	  if (res)
	    return res;
	  return UNICHAR_BAD_ENCODING;
	default:
          if (curr & ~0xffffl)
            {
	      if (res)
	        return res;
              return UNICHAR_OUT_OF_WCHAR;
            }
	  (tgt_buf++)[0] = curr;
	  tgt_buf_len--;
	  res++;
	}

    }
  return res;
}


int eh_decode_buffer_to_wchar__UTF8 (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while(tgt_buf_len>0)
    {
      unichar curr = eh_decode_char__UTF8 (src_begin_ptr, src_buf_end);
      switch(curr)
	{
	case UNICHAR_EOD:
	  return res;
	case UNICHAR_NO_DATA:
	case UNICHAR_BAD_ENCODING:
	  if (res)
	    return res;
	  return UNICHAR_BAD_ENCODING;
	default:
          if (curr & ~0xffffl)
            return UNICHAR_OUT_OF_WCHAR;
	  (tgt_buf++)[0] = curr;
	  tgt_buf_len--;
	  res++;
	}

    }
  return res;
}


char *eh_encode_buffer__UTF8 (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  int n;
  unsigned int mask;
  unichar char_to_put, tmp;
  char * ret;
encode_next_char:
  if (src_buf >= src_buf_end)
    return tgt_buf;
  tmp = char_to_put = src_buf[0];
  if (! (char_to_put & ~0x7F))
    {
      if (tgt_buf >= tgt_buf_end)
	return (char *)UNICHAR_NO_ROOM;
      *tgt_buf++ = (char) char_to_put;
      src_buf++;
      goto encode_next_char;
    }
  if (char_to_put < 0)
    return tgt_buf;
  n = 0;
  while (tmp)
    {
      tmp >>= 1;
      ++n;
    }
  n = (n - 2) / 5;	/* number of additional octets */
  if (tgt_buf_end - tgt_buf < n + 1)
    return (char *)UNICHAR_NO_ROOM;
  ret = tgt_buf + n + 1;
  mask = 0x80;
  for (; n > 0; --n)
    {
      tgt_buf[n] = (char)((char_to_put & 0x3f) | 0x80);
      char_to_put >>= 6;
      mask = (mask >> 1) | 0x80;
    }
  *tgt_buf = (unsigned char)mask;
  mask = (~mask) >> 1;
  *tgt_buf |= (char)char_to_put & (unsigned char)mask;
  tgt_buf = ret;
  src_buf++;
  goto encode_next_char;
}


char *eh_encode_wchar_buffer__UTF8 (const wchar_t *src_buf, const wchar_t *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  int n;
  unsigned int mask;
  unichar char_to_put, tmp;
  char * ret;
encode_next_char:
  if (src_buf >= src_buf_end)
    return tgt_buf;
  tmp = char_to_put = src_buf[0];
  if (! (char_to_put & ~0x7F))
    {
      if (tgt_buf >= tgt_buf_end)
	return (char *)UNICHAR_NO_ROOM;
      *tgt_buf++ = (char) char_to_put;
      src_buf++;
      goto encode_next_char;
    }
  if (char_to_put < 0)
    return tgt_buf;
  n = 0;
  while (tmp)
    {
      tmp >>= 1;
      ++n;
    }
  n = (n - 2) / 5;	/* number of additional octets */
  if (tgt_buf_end - tgt_buf < n + 1)
    return (char *)UNICHAR_NO_ROOM;
  ret = tgt_buf + n + 1;
  mask = 0x80;
  for (; n > 0; --n)
    {
      tgt_buf[n] = (char)((char_to_put & 0x3f) | 0x80);
      char_to_put >>= 6;
      mask = (mask >> 1) | 0x80;
    }
  *tgt_buf = (unsigned char)mask;
  mask = (~mask) >> 1;
  *tgt_buf |= (char)char_to_put & (unsigned char)mask;
  tgt_buf = ret;
  src_buf++;
  goto encode_next_char;
}


char * eh_names__UTF8_QR[] = {"UTF-8-QR", NULL};

encoding_handler_t eh__UTF8_QR = {
  eh_names__UTF8_QR,
  1, MAX_UTF8_CHAR, 0x0000, 1, NULL, NULL,
  eh_decode_char__UTF8_QR,
  eh_decode_buffer__UTF8_QR,
  eh_decode_buffer_to_wchar__UTF8_QR,
  eh_encode_char__UTF8,
  eh_encode_buffer__UTF8,
  eh_encode_wchar_buffer__UTF8
};

char * eh_names__UTF8[] = {"UTF-8", "UTF8", NULL};

encoding_handler_t eh__UTF8 = {
  eh_names__UTF8,
  1, MAX_UTF8_CHAR, 0x0000, 1, NULL, NULL,
  eh_decode_char__UTF8,
  eh_decode_buffer__UTF8,
  eh_decode_buffer_to_wchar__UTF8,
  eh_encode_char__UTF8,
  eh_encode_buffer__UTF8,
  eh_encode_wchar_buffer__UTF8
};




/* UTF-16BE */

unichar eh_decode_char__UTF16BE (__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
/* As is in RFC 2781...
   U' = yyyyyyyyyyxxxxxxxxxx
   W1 = 110110yyyyyyyyyy
   W2 = 110111xxxxxxxxxx
*/
  unsigned char *src_begin = (unsigned char *)(src_begin_ptr[0]);
  unsigned char hi, lo, hiaddon, loaddon;
  unichar acc /* W1 */, accaddon /* W2 */;
  if (src_begin >= (unsigned char *)src_buf_end)
    return UNICHAR_EOD;
  if (src_begin+1 >= (unsigned char *)src_buf_end)
    return UNICHAR_NO_DATA;
  hi = src_begin[0];
  lo = src_begin[1];
  acc = (hi << 8) | lo;
  if (0xFFFE == acc)
    return UNICHAR_BAD_ENCODING; /* Maybe UTF16LE ? */
  switch (acc & 0xFC00)
    {
      case 0xD800:
	if (src_begin+3 >= (unsigned char *)src_buf_end)
	  return UNICHAR_NO_DATA;
	hiaddon = src_begin[2];
	loaddon = src_begin[3];
	accaddon = (hiaddon << 8) | loaddon;
	if (0xDC00 != (accaddon & 0xFC00))
	  return UNICHAR_BAD_ENCODING; /* No low-half after hi-half ? */
	src_begin_ptr[0] += 4;
	return 0x10000 + (((acc & 0x3FF) << 10) | (accaddon & 0x3FF));
      case 0xDC00:
	return UNICHAR_BAD_ENCODING; /* Low-half first ? */
      default:
	src_begin_ptr[0] += 2;
	return acc;
    }
}


char *eh_encode_char__UTF16BE (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{
  if (char_to_put < 0)
    return tgt_buf;
  if (char_to_put & ~0xFFFF)
    {
      if (tgt_buf+4 > tgt_buf_end)
	return (char *)UNICHAR_NO_ROOM;
      char_to_put -= 0x10000;
      tgt_buf[0] = (unsigned char)(0xD8 | ((char_to_put >> 18) & 0x03));
      tgt_buf[1] = (unsigned char)((char_to_put >> 10) & 0xFF);
      tgt_buf[2] = (unsigned char)(0xDC | ((char_to_put >> 8) & 0x03));
      tgt_buf[3] = (unsigned char)(char_to_put & 0xFF);
      return tgt_buf+4;
    }
  if (0xD800 == (char_to_put & 0xF800))
    return tgt_buf;
  if (tgt_buf+2 > tgt_buf_end)
    return (char *)UNICHAR_NO_ROOM;
  tgt_buf[0] = (unsigned char)(char_to_put >> 8);
  tgt_buf[1] = (unsigned char)(char_to_put & 0xFF);
  return tgt_buf+2;
}


int eh_decode_buffer__UTF16BE (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while(tgt_buf_len>0)
    {
      unichar curr = eh_decode_char__UTF16BE(src_begin_ptr, src_buf_end);
      switch(curr)
	{
	case UNICHAR_EOD:
	  return res;
	case UNICHAR_NO_DATA:
	case UNICHAR_BAD_ENCODING:
	  if (res)
	    return res;
	  return UNICHAR_BAD_ENCODING;
	default:
	  (tgt_buf++)[0] = curr;
	  tgt_buf_len--;
	  res++;
	}

    }
  return res;
}


int eh_decode_buffer_to_wchar__UTF16BE (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while(tgt_buf_len>0)
    {
      unichar curr = eh_decode_char__UTF16BE(src_begin_ptr, src_buf_end);
      switch(curr)
	{
	case UNICHAR_EOD:
	  return res;
	case UNICHAR_NO_DATA:
	case UNICHAR_BAD_ENCODING:
	  if (res)
	    return res;
	  return UNICHAR_BAD_ENCODING;
	default:
          if (curr & ~0xffffl)
            return UNICHAR_OUT_OF_WCHAR;
	  (tgt_buf++)[0] = curr;
	  tgt_buf_len--;
	  res++;
	}

    }
  return res;
}


char *eh_encode_buffer__UTF16BE (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  while (src_buf < src_buf_end)
    {
      char *put_res = eh_encode_char__UTF16BE (src_buf[0], tgt_buf, tgt_buf_end);
      if ((char *)UNICHAR_NO_ROOM == put_res)
	return (char *)UNICHAR_NO_ROOM;
      tgt_buf = put_res;
      src_buf++;
    }
  return tgt_buf;
}


char *eh_encode_wchar_buffer__UTF16BE (const wchar_t *src_buf, const wchar_t *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  while (src_buf < src_buf_end)
    {
      char *put_res = eh_encode_char__UTF16BE (src_buf[0], tgt_buf, tgt_buf_end);
      if ((char *)UNICHAR_NO_ROOM == put_res)
	return (char *)UNICHAR_NO_ROOM;
      tgt_buf = put_res;
      src_buf++;
    }
  return tgt_buf;
}


char * eh_names__UTF16BE[] = {"UTF-16BE", "UTF16BE", NULL};

encoding_handler_t eh__UTF16BE = {
  eh_names__UTF16BE,
  MIN_UTF16_CHAR, MAX_UTF16_CHAR, 0x1234, 0, NULL, NULL,
  eh_decode_char__UTF16BE,
  eh_decode_buffer__UTF16BE,
  eh_decode_buffer_to_wchar__UTF16BE,
  eh_encode_char__UTF16BE,
  eh_encode_buffer__UTF16BE,
  eh_encode_wchar_buffer__UTF16BE
};




/* UTF-16LE */

unichar eh_decode_char__UTF16LE (__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
/* As is in RFC 2781...
   U' = yyyyyyyyyyxxxxxxxxxx
   W1 = 110110yyyyyyyyyy
   W2 = 110111xxxxxxxxxx
*/
  unsigned char *src_begin = (unsigned char *)(src_begin_ptr[0]);
  unsigned char hi, lo, hiaddon, loaddon;
  unichar acc /* W1 */, accaddon /* W2 */;
  if (src_begin >= (unsigned char *)src_buf_end)
    return UNICHAR_EOD;
  if (src_begin+1 >= (unsigned char *)src_buf_end)
    return UNICHAR_NO_DATA;
  hi = src_begin[1];
  lo = src_begin[0];
  acc = (hi << 8) | lo;
  if (0xFFFE == acc)
    return UNICHAR_BAD_ENCODING; /* Maybe UTF16BE ? */
  switch (acc & 0xFC00)
    {
      case 0xD800:
	if (src_begin+3 >= (unsigned char *)src_buf_end)
	  return UNICHAR_NO_DATA;
	hiaddon = src_begin[3];
	loaddon = src_begin[2];
	accaddon = (hiaddon << 8) | loaddon;
	if (0xDC00 != (accaddon & 0xFC00))
	  return UNICHAR_BAD_ENCODING; /* No low-half after hi-half ? */
	src_begin_ptr[0] += 4;
	return 0x10000 + (((acc & 0x3FF) << 10) | (accaddon & 0x3FF));
      case 0xDC00:
	return UNICHAR_BAD_ENCODING; /* Low-half first ? */
      default:
	src_begin_ptr[0] += 2;
	return acc;
    }
}


char *eh_encode_char__UTF16LE (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{
  if (char_to_put < 0)
    return tgt_buf;
  if (char_to_put & ~0xFFFF)
    {
      if (tgt_buf+4 > tgt_buf_end)
	return (char *)UNICHAR_NO_ROOM;
      char_to_put -= 0x10000;
      tgt_buf[1] = (unsigned char)(0xD8 | ((char_to_put >> 18) & 0x03));
      tgt_buf[0] = (unsigned char)((char_to_put >> 10) & 0xFF);
      tgt_buf[3] = (unsigned char)(0xDC | ((char_to_put >> 8) & 0x03));
      tgt_buf[2] = (unsigned char)(char_to_put & 0xFF);
      return tgt_buf+4;
    }
  if (0xD800 == (char_to_put & 0xF800))
    return tgt_buf;
  if (tgt_buf+2 > tgt_buf_end)
    return (char *)UNICHAR_NO_ROOM;
  tgt_buf[1] = (unsigned char)(char_to_put >> 8);
  tgt_buf[0] = (unsigned char)(char_to_put & 0xFF);
  return tgt_buf+2;
}


int eh_decode_buffer__UTF16LE (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while(tgt_buf_len>0)
    {
      unichar curr = eh_decode_char__UTF16LE(src_begin_ptr, src_buf_end);
      switch(curr)
	{
	case UNICHAR_EOD:
	  return res;
	case UNICHAR_NO_DATA:
	case UNICHAR_BAD_ENCODING:
	  if (res)
	    return res;
	  return UNICHAR_BAD_ENCODING;
	default:
	  (tgt_buf++)[0] = curr;
	  tgt_buf_len--;
	  res++;
	}

    }
  return res;
}


int eh_decode_buffer_to_wchar__UTF16LE (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while(tgt_buf_len>0)
    {
      unichar curr = eh_decode_char__UTF16LE(src_begin_ptr, src_buf_end);
      switch(curr)
	{
	case UNICHAR_EOD:
	  return res;
	case UNICHAR_NO_DATA:
	case UNICHAR_BAD_ENCODING:
	  if (res)
	    return res;
	  return UNICHAR_BAD_ENCODING;
	default:
          if (curr & ~0xffffl)
            return UNICHAR_OUT_OF_WCHAR;
	  (tgt_buf++)[0] = curr;
	  tgt_buf_len--;
	  res++;
	}
    }
  return res;
}


char *eh_encode_buffer__UTF16LE (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  while (src_buf < src_buf_end)
    {
      char *put_res = eh_encode_char__UTF16LE (src_buf[0], tgt_buf, tgt_buf_end);
      if ((char *)UNICHAR_NO_ROOM == put_res)
	return (char *)UNICHAR_NO_ROOM;
      tgt_buf = put_res;
      src_buf++;
    }
  return tgt_buf;
}


char *eh_encode_wchar_buffer__UTF16LE (const wchar_t *src_buf, const wchar_t *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  while (src_buf < src_buf_end)
    {
      char *put_res = eh_encode_char__UTF16LE (src_buf[0], tgt_buf, tgt_buf_end);
      if ((char *)UNICHAR_NO_ROOM == put_res)
	return (char *)UNICHAR_NO_ROOM;
      tgt_buf = put_res;
      src_buf++;
    }
  return tgt_buf;
}


char * eh_names__UTF16LE[] = {"UTF-16LE", "UTF16LE", NULL};

encoding_handler_t eh__UTF16LE = {
  eh_names__UTF16LE,
  MIN_UTF16_CHAR, MAX_UTF16_CHAR, 0x4321, 0, NULL, NULL,
  eh_decode_char__UTF16LE,
  eh_decode_buffer__UTF16LE,
  eh_decode_buffer_to_wchar__UTF16LE,
  eh_encode_char__UTF16LE,
  eh_encode_buffer__UTF16LE,
  eh_encode_wchar_buffer__UTF16LE
};


char * eh_names__UTF16[] = {"UTF-16", "UTF16", NULL};

encoding_handler_t eh__UTF16 = {
  eh_names__UTF16,
  MIN_UTF16_CHAR, MAX_UTF16_CHAR, 0x0000, 0, NULL, NULL,
  eh_decode_char__UTF16LE,
  eh_decode_buffer__UTF16LE,
  eh_decode_buffer_to_wchar__UTF16LE,
  eh_encode_char__UTF16LE,
  eh_encode_buffer__UTF16LE,
  eh_encode_wchar_buffer__UTF16LE
};


/* ASCII */

unichar eh_decode_char__ASCII (__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  if (*src_begin_ptr >= src_buf_end)
    return UNICHAR_EOD;
  if ((**src_begin_ptr & (unsigned char)0x80) == 0)
    return *(*src_begin_ptr)++;
  return UNICHAR_BAD_ENCODING;
}


char *eh_encode_char__ASCII (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{
  if (char_to_put < 0)
    return tgt_buf;
  if (tgt_buf_end <= tgt_buf)
    return (char *)UNICHAR_NO_ROOM;
  tgt_buf[0] = (unsigned char)((char_to_put & ~0x7F) ? '?' : char_to_put);
  return tgt_buf+1;
}


int eh_decode_buffer__ASCII (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while((tgt_buf_len>0) && (src_buf_end > src_begin_ptr[0]))
    {
      if (**src_begin_ptr & ~0x7F)
	{
	  if (res)
	    return res;
	  return UNICHAR_BAD_ENCODING;
	}
      (tgt_buf++)[0] = ((src_begin_ptr[0])++)[0];
      tgt_buf_len--;
      res++;
    }
  return res;
}


int eh_decode_buffer_to_wchar__ASCII (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while((tgt_buf_len>0) && (src_buf_end > src_begin_ptr[0]))
    {
      if (**src_begin_ptr & ~0x7F)
	{
	  if (res)
	    return res;
	  return UNICHAR_BAD_ENCODING;
	}
      (tgt_buf++)[0] = ((src_begin_ptr[0])++)[0];
      tgt_buf_len--;
      res++;
    }
  return res;
}


char *eh_encode_buffer__ASCII (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  unichar char_to_put;
  if ((tgt_buf_end-tgt_buf) < (src_buf_end-src_buf))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char_to_put = (src_buf++)[0];
      (tgt_buf++)[0] = (unsigned char)((char_to_put & ~0x7F) ? '?' : char_to_put);
    }
  return tgt_buf;
}


char *eh_encode_wchar_buffer__ASCII (const wchar_t *src_buf, const wchar_t *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  unichar char_to_put;
  if ((tgt_buf_end-tgt_buf) < (src_buf_end-src_buf))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char_to_put = (src_buf++)[0];
      (tgt_buf++)[0] = (unsigned char)((char_to_put & ~0x7F) ? '?' : char_to_put);
    }
  return tgt_buf;
}


char * eh_names__ASCII[] = {"ASCII", "US-ASCII", NULL};

encoding_handler_t eh__ASCII = {
  eh_names__ASCII,
  1, 1, 0x0000, 1, NULL, NULL,
  eh_decode_char__ASCII,
  eh_decode_buffer__ASCII,
  eh_decode_buffer_to_wchar__ASCII,
  eh_encode_char__ASCII,
  eh_encode_buffer__ASCII,
  eh_encode_wchar_buffer__ASCII
};




/* ISO8859-1 */

unichar eh_decode_char__ISO8859_1(__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  if (*src_begin_ptr >= src_buf_end)
    return UNICHAR_EOD;
  return (unsigned char)(*(*src_begin_ptr)++);
}


char *eh_encode_char__ISO8859_1 (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{
  if (char_to_put < 0)
    return tgt_buf;
  if (tgt_buf_end <= tgt_buf)
    return (char *)UNICHAR_NO_ROOM;
  tgt_buf[0] = (unsigned char)((char_to_put & ~0xFF) ? '?' : char_to_put);
  return tgt_buf+1;
}


int eh_decode_buffer__ISO8859_1 (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while((tgt_buf_len>0) && (src_buf_end > src_begin_ptr[0]))
    {
      (tgt_buf++)[0] = (unsigned char)(((src_begin_ptr[0])++)[0]);
      tgt_buf_len--;
      res++;
    }
  return res;
}


int eh_decode_buffer_to_wchar__ISO8859_1 (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while((tgt_buf_len>0) && (src_buf_end > src_begin_ptr[0]))
    {
      (tgt_buf++)[0] = (unsigned char)(((src_begin_ptr[0])++)[0]);
      tgt_buf_len--;
      res++;
    }
  return res;
}


char *eh_encode_buffer__ISO8859_1 (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  unichar char_to_put;
  if ((tgt_buf_end-tgt_buf) < (src_buf_end-src_buf))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char_to_put = (src_buf++)[0];
      (tgt_buf++)[0] = (unsigned char)((char_to_put & ~0xFF) ? '?' : char_to_put);
    }
  return tgt_buf;
}


char *eh_encode_wchar_buffer__ISO8859_1 (const wchar_t *src_buf, const wchar_t *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  unichar char_to_put;
  if ((tgt_buf_end-tgt_buf) < (src_buf_end-src_buf))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char_to_put = (src_buf++)[0];
      (tgt_buf++)[0] = (unsigned char)((char_to_put & ~0xFF) ? '?' : char_to_put);
    }
  return tgt_buf;
}


char * eh_names__ISO8859_1[] = {
"ISO8859-1", "ISO-8859-1", "ISO_8859-1", "ISO_8859-1:1987", "8859-1", "ISO", "LATIN-1", "LATIN 1", "LATIN_1", "LATIN1", "ISO-IR-100", "L1", "IBM819", "CP819", "819", "CSISOLATIN1", NULL};

encoding_handler_t eh__ISO8859_1 = {
  eh_names__ISO8859_1,
  1, 1, 0x0000, 1, NULL, NULL,
  eh_decode_char__ISO8859_1,
  eh_decode_buffer__ISO8859_1,
  eh_decode_buffer_to_wchar__ISO8859_1,
  eh_encode_char__ISO8859_1,
  eh_encode_buffer__ISO8859_1,
  eh_encode_wchar_buffer__ISO8859_1
};




/* WIDE identity */

#define next_wchar_begin(ptr) ((char *)( ((wchar_t *)(ptr)) + 1 ))

unichar eh_decode_char__WIDE_121(__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  if (next_wchar_begin(src_begin_ptr[0]) > src_buf_end)
    {
      if (src_begin_ptr[0] > src_buf_end)
	return UNICHAR_EOD;
      return UNICHAR_NO_DATA;
    }
  return (unichar)(((((wchar_t **)(src_begin_ptr))[0])++)[0]);
}


char *eh_encode_char__WIDE_121 (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{
  if (char_to_put < 0)
    return tgt_buf;
  if (tgt_buf_end < next_wchar_begin(tgt_buf))
    return (char *)UNICHAR_NO_ROOM;
  ((wchar_t *)(tgt_buf))[0] = (wchar_t)((char_to_put & ~0xFFFF) ? (wchar_t)('?') : char_to_put);
  return next_wchar_begin(tgt_buf);
}


int eh_decode_buffer__WIDE_121 (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while((tgt_buf_len>0) && (next_wchar_begin(src_begin_ptr[0]) <= src_buf_end))
    {
      (tgt_buf++)[0] = (unichar)(((((wchar_t **)(src_begin_ptr))[0])++)[0]);
      tgt_buf_len--;
      res++;
    }
  if (src_begin_ptr[0] > src_buf_end)
    return UNICHAR_EOD;
  return res;
}


int eh_decode_buffer_to_wchar__WIDE_121 (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while((tgt_buf_len>0) && (next_wchar_begin(src_begin_ptr[0]) <= src_buf_end))
    {
      (tgt_buf++)[0] = (unichar)(((((wchar_t **)(src_begin_ptr))[0])++)[0]);
      tgt_buf_len--;
      res++;
    }
  if (src_begin_ptr[0] > src_buf_end)
    return UNICHAR_EOD;
  return res;
}


char *eh_encode_buffer__WIDE_121 (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  unichar char_to_put;
  if ((((wchar_t *)tgt_buf_end) - ((wchar_t *)tgt_buf)) < (src_buf_end-src_buf))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char_to_put = (src_buf++)[0];
      ((wchar_t *)(tgt_buf))[0] = (wchar_t)((char_to_put & ~0xFFFF) ? (wchar_t)('?') : char_to_put);
      tgt_buf = next_wchar_begin(tgt_buf);
    }
  return tgt_buf;
}


char *eh_encode_wchar_buffer__WIDE_121 (const wchar_t *src_buf, const wchar_t *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  unichar char_to_put;
  if ((((wchar_t *)tgt_buf_end) - ((wchar_t *)tgt_buf)) < (src_buf_end-src_buf))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char_to_put = (src_buf++)[0];
      ((wchar_t *)(tgt_buf))[0] = (wchar_t)((char_to_put & ~0xFFFF) ? (wchar_t)('?') : char_to_put);
      tgt_buf = next_wchar_begin(tgt_buf);
    }
  return tgt_buf;
}


char * eh_names__WIDE_121[] = {
  "WIDE identity", NULL};

encoding_handler_t eh__WIDE_121 = {
  eh_names__WIDE_121,
  sizeof (wchar_t), sizeof (wchar_t), 0x0000, 0, NULL, NULL,
  eh_decode_char__WIDE_121,
  eh_decode_buffer__WIDE_121,
  eh_decode_buffer_to_wchar__WIDE_121,
  eh_encode_char__WIDE_121,
  eh_encode_buffer__WIDE_121,
  eh_encode_wchar_buffer__WIDE_121
};


/* UCS-4BE */

#define UCS4BE_to_unichar(x) ((unichar)((x)[3] | ((x)[2] << 8) | ((x)[1] << 16) | ((x)[0] << 24)))

#define unichar_to_UCS4BE(buf,uni) \
  do { \
    (buf)[3] = (uni) & 0xFF; \
    (buf)[2] = ((uni) >> 8) & 0xFF; \
    (buf)[1] = ((uni) >> 16) & 0xFF; \
    (buf)[0] = ((uni) >> 24) & 0xFF; \
    } while (0)

unichar eh_decode_char__UCS4BE(__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  unichar res;
  if ((src_begin_ptr[0] + 4) > src_buf_end)
    {
      if (src_begin_ptr[0] > src_buf_end)
	return UNICHAR_EOD;
      return UNICHAR_NO_DATA;
    }
  res = UCS4BE_to_unichar (src_begin_ptr[0]);
  src_begin_ptr[0] += 4;
  return res;
}


char *eh_encode_char__UCS4BE (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{
  if (char_to_put < 0)
    return tgt_buf;
  if (tgt_buf_end < tgt_buf + 4)
    return (char *)UNICHAR_NO_ROOM;
  unichar_to_UCS4BE(tgt_buf, char_to_put);
  return tgt_buf + 4;
}


int eh_decode_buffer__UCS4BE (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while((tgt_buf_len>0) && ((src_begin_ptr[0] + 4) <= src_buf_end))
    {
      (tgt_buf++)[0] = UCS4BE_to_unichar (src_begin_ptr[0]);
      src_begin_ptr[0] += 4;
      tgt_buf_len--;
      res++;
    }
  if (src_begin_ptr[0] > src_buf_end)
    return UNICHAR_EOD;
  return res;
}


int eh_decode_buffer_to_wchar__UCS4BE (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while((tgt_buf_len>0) && ((src_begin_ptr[0] + 4) <= src_buf_end))
    {
      unichar curr = UCS4BE_to_unichar (src_begin_ptr[0]);
      if (curr & ~0xffffL)
        return UNICHAR_OUT_OF_WCHAR;
      (tgt_buf++)[0] = curr;
      src_begin_ptr[0] += 4;
      tgt_buf_len--;
      res++;
    }
  if (src_begin_ptr[0] > src_buf_end)
    return UNICHAR_EOD;
  return res;
}


char *eh_encode_buffer__UCS4BE (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  unichar char_to_put;
  if ((tgt_buf_end - tgt_buf) < ((src_buf_end - src_buf) * 4))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char_to_put = (src_buf++)[0];
      unichar_to_UCS4BE (tgt_buf, char_to_put);
      tgt_buf += 4;
    }
  return tgt_buf;
}


char *eh_encode_wchar_buffer__UCS4BE (const wchar_t *src_buf, const wchar_t *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  unichar char_to_put;
  if ((tgt_buf_end - tgt_buf) < ((src_buf_end - src_buf) * 4))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char_to_put = (src_buf++)[0];
      unichar_to_UCS4BE (tgt_buf, char_to_put);
      tgt_buf += 4;
    }
  return tgt_buf;
}


char * eh_names__UCS4BE[] = {
  "ISO-10646-UCS-4BE", "UCS4BE", "UCS-4BE", NULL};

encoding_handler_t eh__UCS4BE = {
  eh_names__UCS4BE,
  4, 4, 0x1234, 0, NULL, NULL,
  eh_decode_char__UCS4BE,
  eh_decode_buffer__UCS4BE,
  eh_decode_buffer_to_wchar__UCS4BE,
  eh_encode_char__UCS4BE,
  eh_encode_buffer__UCS4BE,
  eh_encode_wchar_buffer__UCS4BE
};


/* UCS-4LE */

#define UCS4LE_to_unichar(x) ((unichar)((x)[0] | ((x)[1] << 8) | ((x)[2] << 16) | ((x)[3] << 24)))

#define unichar_to_UCS4LE(buf,uni) \
  do { \
    (buf)[0] = (uni) & 0xFF; \
    (buf)[1] = ((uni) >> 8) & 0xFF; \
    (buf)[2] = ((uni) >> 16) & 0xFF; \
    (buf)[3] = ((uni) >> 24) & 0xFF; \
    } while (0)

unichar eh_decode_char__UCS4LE(__constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  unichar res;
  if ((src_begin_ptr[0] + 4) > src_buf_end)
    {
      if (src_begin_ptr[0] > src_buf_end)
	return UNICHAR_EOD;
      return UNICHAR_NO_DATA;
    }
  res = UCS4LE_to_unichar (src_begin_ptr[0]);
  src_begin_ptr[0] += 4;
  return res;
}


char *eh_encode_char__UCS4LE (unichar char_to_put, char *tgt_buf, char *tgt_buf_end, ...)
{
  if (char_to_put < 0)
    return tgt_buf;
  if (tgt_buf_end < tgt_buf + 4)
    return (char *)UNICHAR_NO_ROOM;
  unichar_to_UCS4LE(tgt_buf, char_to_put);
  return tgt_buf + 4;
}


int eh_decode_buffer__UCS4LE (unichar *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while((tgt_buf_len>0) && ((src_begin_ptr[0] + 4) <= src_buf_end))
    {
      (tgt_buf++)[0] = UCS4LE_to_unichar (src_begin_ptr[0]);
      src_begin_ptr[0] += 4;
      tgt_buf_len--;
      res++;
    }
  if (src_begin_ptr[0] > src_buf_end)
    return UNICHAR_EOD;
  return res;
}


int eh_decode_buffer_to_wchar__UCS4LE (wchar_t *tgt_buf, int tgt_buf_len, __constcharptr *src_begin_ptr, const char *src_buf_end, ...)
{
  int res = 0;
  while((tgt_buf_len>0) && ((src_begin_ptr[0] + 4) <= src_buf_end))
    {
      unichar curr = UCS4LE_to_unichar (src_begin_ptr[0]);
      if (curr & ~0xffffL)
        return UNICHAR_OUT_OF_WCHAR;
      (tgt_buf++)[0] = curr;
      src_begin_ptr[0] += 4;
      tgt_buf_len--;
      res++;
    }
  if (src_begin_ptr[0] > src_buf_end)
    return UNICHAR_EOD;
  return res;
}


char *eh_encode_buffer__UCS4LE (const unichar *src_buf, const unichar *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  unichar char_to_put;
  if ((tgt_buf_end - tgt_buf) < ((src_buf_end - src_buf) * 4))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char_to_put = (src_buf++)[0];
      unichar_to_UCS4LE (tgt_buf, char_to_put);
      tgt_buf += 4;
    }
  return tgt_buf;
}


char *eh_encode_wchar_buffer__UCS4LE (const wchar_t *src_buf, const wchar_t *src_buf_end, char *tgt_buf, char *tgt_buf_end, ...)
{
  unichar char_to_put;
  if ((tgt_buf_end - tgt_buf) < ((src_buf_end - src_buf) * 4))
    return (char *)UNICHAR_NO_ROOM;
  while (src_buf < src_buf_end)
    {
      char_to_put = (src_buf++)[0];
      unichar_to_UCS4LE (tgt_buf, char_to_put);
      tgt_buf += 4;
    }
  return tgt_buf;
}


char * eh_names__UCS4LE[] = {
  "ISO-10646-UCS-4LE", "UCS4LE", "UCS-4LE", NULL};

encoding_handler_t eh__UCS4LE = {
  eh_names__UCS4LE,
  4, 4, 0x4321, 0, NULL, NULL,
  eh_decode_char__UCS4LE,
  eh_decode_buffer__UCS4LE,
  eh_decode_buffer_to_wchar__UCS4LE,
  eh_encode_char__UCS4LE,
  eh_encode_buffer__UCS4LE,
  eh_encode_wchar_buffer__UCS4LE
};

char * eh_names__UCS4[] = {
  "ISO-10646-UCS-4", "UCS4", "UCS-4", NULL};

encoding_handler_t eh__UCS4 = {
  eh_names__UCS4,
  4, 4, 0x0000, 0, NULL, NULL,
  eh_decode_char__UCS4LE,
  eh_decode_buffer__UCS4LE,
  eh_decode_buffer_to_wchar__UCS4LE,
  eh_encode_char__UCS4LE,
  eh_encode_buffer__UCS4LE,
  eh_encode_wchar_buffer__UCS4LE
};

