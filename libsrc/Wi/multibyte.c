/*
 *  multibyte.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

#include "libutil.h"
#include "sqlnode.h"
#include "sqlnode.h"
#include "multibyte.h"
#include "wi.h"
#ifndef ROLLBACK_XQ
#include "wifn.h"
#endif
#ifdef __cplusplus
extern "C" {
#endif
#include "langfunc.h"
#ifdef __cplusplus
}
#endif
#include <errno.h>
#if !defined (__APPLE__)
#include <wchar.h>
#endif

#ifndef EILSEQ
#define EILSEQ EINVAL
#endif


caddr_t
box_utf8_as_wide_char (ccaddr_t _utf8, caddr_t _wide_dest, size_t utf8_len, size_t max_wide_len)
{
  unsigned char *utf8 = (unsigned char *) _utf8;
  unsigned char *utf8work;
  size_t wide_len, wide_boxsize;
  virt_mbstate_t state;
  caddr_t dest;

  utf8work = utf8;
  memset (&state, 0, sizeof (virt_mbstate_t));
  wide_len = virt_mbsnrtowcs (NULL, &utf8work, utf8_len, 0, &state);
  if (((long) wide_len) < 0)
    return _wide_dest ? ((caddr_t) wide_len) : NULL;
  if (max_wide_len && max_wide_len < wide_len)
    wide_len = max_wide_len;
  if (_wide_dest)
    dest = _wide_dest;
  else
    {
      wide_boxsize = (int) (wide_len + 1) * sizeof (wchar_t);
      if (wide_boxsize > MAX_READ_STRING)
        return NULL; /* Prohibitively long UTF-8 string as a source */
      dest = dk_alloc_box (wide_boxsize, DV_WIDE);
    }
  utf8work = utf8;
  memset (&state, 0, sizeof (virt_mbstate_t));
  if (wide_len != virt_mbsnrtowcs ((wchar_t *) dest, &utf8work, utf8_len, wide_len, &state))
    GPF_T1("non consistent multi-byte to wide char translation of a buffer");

  ((wchar_t *)dest)[wide_len] = L'\0';
  if (_wide_dest)
    return ((caddr_t)wide_len);
  else
    return dest;
}


caddr_t
DBG_NAME(box_wide_as_utf8_char) (DBG_PARAMS ccaddr_t _wide, size_t wide_len, dtp_t dtp)
{
  char *dest;
  size_t utf8_len;
  virt_mbstate_t state;
  wchar_t *wide = (wchar_t *) _wide;
  wchar_t *wide_work;
#ifdef DEBUG
  if (wide_len & ~0xFFFFFF)
    GPF_T1 ("bad wide_len in cast wide as UTF8");
#endif
  wide_work = wide;
  memset (&state, 0, sizeof (virt_mbstate_t));
  utf8_len = virt_wcsnrtombs (NULL, &wide_work, wide_len, 0, &state);
  if (((long) utf8_len) < 0)
    return NULL;
  dest = DBG_NAME (dk_alloc_box) (DBG_ARGS utf8_len + 1, dtp);

  wide_work = wide;
  memset (&state, 0, sizeof (virt_mbstate_t));
  if (utf8_len != virt_wcsnrtombs ((unsigned char *) dest, &wide_work, wide_len, utf8_len + 1, &state))
    GPF_T1("non consistent wide char to multi-byte translation of a buffer");

  dest[utf8_len] = '\0';
  return dest;
}

caddr_t
mp_box_wide_as_utf8_char (mem_pool_t * mp, ccaddr_t _wide, size_t wide_len, dtp_t dtp)
{
  char *dest;
  size_t utf8_len;
  virt_mbstate_t state;
  wchar_t *wide = (wchar_t *) _wide;
  wchar_t *wide_work;
#ifdef DEBUG
  if (wide_len & ~0xFFFFFF)
    GPF_T1 ("bad wide_len in cast wide as UTF8");
#endif
  wide_work = wide;
  memset (&state, 0, sizeof (virt_mbstate_t));
  utf8_len = virt_wcsnrtombs (NULL, &wide_work, wide_len, 0, &state);
  if (((long) utf8_len) < 0)
    return NULL;
  dest = mp_alloc_box (mp, utf8_len + 1, dtp);

  wide_work = wide;
  memset (&state, 0, sizeof (virt_mbstate_t));
  if (utf8_len != virt_wcsnrtombs ((unsigned char *) dest, &wide_work, wide_len, utf8_len + 1, &state))
    GPF_T1("non consistent wide char to multi-byte translation of a buffer");

  dest[utf8_len] = '\0';
  return dest;
}

int
wide_serialize (caddr_t wide_data, dk_session_t *ses)
{
   wchar_t *wstr = (wchar_t *)wide_data, *wide_work = (wchar_t *)wide_data;
   size_t utf8_len, wide_len = box_length (wide_data) / sizeof (wchar_t) - 1;
   virt_mbstate_t state;
   unsigned char mbs[VIRT_MB_CUR_MAX];
   size_t len = 0, i;

   wide_work = wstr;
   memset (&state, 0, sizeof (virt_mbstate_t));
   utf8_len = virt_wcsnrtombs (NULL, &wide_work, wide_len, 0, &state);
   if (((long) utf8_len) < 0)
     GPF_T1("non consistent wide char to multi-byte translation of a buffer");


   if (utf8_len < 256)
     {
	session_buffered_write_char (DV_WIDE, ses);
	session_buffered_write_char ((char) utf8_len, ses);
     }
   else
     {
       session_buffered_write_char (DV_LONG_WIDE, ses);
       print_long ((long) utf8_len, ses);
     }

   memset (&state, 0, sizeof (virt_mbstate_t));
   wide_work = wstr;
   i = 0;
   while (i++ < wide_len)
     {
       len = virt_wcrtomb (mbs, *wide_work++, &state);
       if (((int) len) > 0)
	 session_buffered_write (ses, (char *) mbs, len);
     }
   return 0;
}


void *
box_read_wide_string (dk_session_t *ses, dtp_t macro)
{
  long utf8_len;
  unsigned char string [2048];

  utf8_len = session_buffered_read_char (ses);
  memset (string, 0, 2048);
  session_buffered_read (ses, (char *) string, utf8_len);
  return box_utf8_as_wide_char ((caddr_t) string, NULL, utf8_len, 0);
}

#define CHUNK_SIZE	2048
void *
box_read_long_wide_string (dk_session_t *session, dtp_t macro)
{
  long utf8_len, wide_len = 0;
  dk_set_t string_set = NULL;
  wchar_t *w_array, *ptr;
  virt_mbstate_t state;
  wchar_t tmp[1];
  char read;
  int rc;

  utf8_len = read_long (session);
  memset (&state, 0, sizeof (virt_mbstate_t));
  MARSH_CHECK_BOX (ptr = w_array = (wchar_t *) dk_try_alloc_box (CHUNK_SIZE * sizeof (wchar_t), DV_WIDE));
  while (utf8_len-- > 0)
    {
      read = session_buffered_read_char (session);
      rc = (int) virt_mbrtowc_z (tmp, (unsigned char *) &read, 1, &state);
      if (rc > 0)
	{
	  if (ptr - w_array == CHUNK_SIZE)
	    {
	      dk_set_push (&string_set, w_array);
	      MARSH_CHECK_BOX (ptr = w_array = (wchar_t *) dk_try_alloc_box (CHUNK_SIZE * sizeof (wchar_t), DV_WIDE));
	      MARSH_CHECK_LENGTH ((wide_len + 1) * sizeof (wchar_t));
	    }
	  *ptr++ = tmp[0];
	  wide_len++;
	}
      else if (-1 == rc)
	{ /* an error occurred */
	  caddr_t chunk_ptr;
	  while (NULL != (chunk_ptr = (caddr_t) dk_set_pop (&string_set)))
            {
#ifndef NDEBUG
              ((wchar_t *)chunk_ptr)[CHUNK_SIZE - 1] = 0;
#endif
	      dk_free_box (chunk_ptr);
            }
	  return NULL;
	}
    }
  if (wide_len > 0)
    {
      caddr_t box, chunk_ptr, box_ptr;
      MARSH_CHECK_LENGTH ((wide_len + 1) * sizeof (wchar_t));
      MARSH_CHECK_BOX (box_ptr = box = dk_try_alloc_box ((wide_len + 1) * sizeof (wchar_t), DV_WIDE));
      string_set = dk_set_nreverse (string_set);
      while (NULL != (chunk_ptr = (caddr_t) dk_set_pop (&string_set)))
	{
	  memcpy (box_ptr, chunk_ptr, CHUNK_SIZE * sizeof (wchar_t));
#ifndef NDEBUG
          ((wchar_t *)chunk_ptr)[CHUNK_SIZE - 1] = 0;
#endif
	  dk_free_box (chunk_ptr);
	  box_ptr += CHUNK_SIZE * sizeof (wchar_t);
	}
      if (ptr - w_array > 0)
	{
	  memcpy (box_ptr, w_array, (ptr - w_array) * sizeof (wchar_t));
#ifndef NDEBUG
          w_array[CHUNK_SIZE - 1] = 0;
#endif
	  dk_free_box ((box_t) w_array);
	}
      *((wchar_t *)(box_ptr + (((long)(ptr - w_array)) * sizeof (wchar_t)))) = L'\0';
      return box;
    }
  else
    { /* no wide chars at all */
#ifndef NDEBUG
      w_array[CHUNK_SIZE - 1] = 0;
#endif
      dk_free_box ((box_t) w_array);
      return NULL;
    }
}


size_t
wide_char_length_of_utf8_string (const unsigned char *str, size_t utf8_length)
{
  virt_mbstate_t state;
  memset (&state, 0, sizeof (virt_mbstate_t));
  return virt_mbsnrtowcs (NULL, (unsigned char **)&str, utf8_length, 0, &state);
}


const wchar_t *
virt_wcschr (const wchar_t *wcs, wchar_t wc)
{
  if (wcs)
    while (*wcs)
      {
	if (*wcs == wc)
	  return ((wchar_t *)wcs);
	wcs++;
      }
  return NULL;
}


const wchar_t *
virt_wcsrchr (const wchar_t *wcs, wchar_t wc)
{
  wchar_t *wcs_end = (wchar_t *)wcs;
  if (wcs && *wcs)
    {
      while (*wcs_end)
	wcs_end++;
      wcs_end -= 1;
      while (wcs_end >= wcs)
	{
	  if (*wcs == wc)
	    return ((wchar_t *)wcs);
	  wcs--;
	}
    }
  return NULL;
}

size_t
virt_wcslen (const wchar_t *wcs)
{
  size_t len = 0;
  while (wcs && *wcs)
    {
      wcs++;
      len++;
    }
  return len;
}


int
virt_wcsncmp (const wchar_t *from, const wchar_t *to, size_t len)
{
  static wchar_t zero = 0;
  if (!from)
    from = &zero;
  if (!to)
    to = &zero;
  while (*from && *to && (0 < len))
    {
      if (*from > *to)
        return 1;
      if (*from < *to)
        return -1;
      from++;
      to++;
      len--;
    }
  return 0;
}

const wchar_t *
virt_wcsstr (const wchar_t *wcs, const wchar_t *wc)
{
  size_t len;
  const wchar_t *cp;
  const wchar_t *ep;
  len = virt_wcslen (wc);
  if (0 == len)
    return wcs;
  ep = wcs + virt_wcslen (wcs) - len;
  if (ep < wcs)
    return NULL;
  for (cp = wcs; cp <= ep; cp++)
    if (*cp == *wc && !virt_wmemcmp (cp, wc, len))
      return cp;
  return NULL;
}

const wchar_t *
virt_wcsrstr (const wchar_t *wcs, const wchar_t *wc)
{
  size_t len;
  const wchar_t *cp;
  const wchar_t *ep;
  len = virt_wcslen (wc);
  if (0 == len)
    return wcs;
  ep = wcs + virt_wcslen (wcs) - len;
  if (ep < wcs)
  for (cp = ep; cp >= wcs; --cp)
    if (*cp == *wc && !virt_wmemcmp (cp, wc, len))
      return cp;
  return NULL;
}

const wchar_t *
virt_wmemmem (const wchar_t *haystack, size_t haystacklen, const wchar_t *needle, size_t needlelen)
{
  const wchar_t *stop;
  size_t cmplen;
  if (needlelen > haystacklen)
    return NULL;
  if (0 == needlelen)
    return haystack;
  stop = haystack + haystacklen - needlelen;
  cmplen = (needlelen - 1) * sizeof (wchar_t);
  while (haystack <= stop)
    {
      if (haystack[0] == needle[0] && !memcmp (haystack+1, needle+1, cmplen))
        return haystack;
      haystack++;
    }
  return NULL;
}

static unsigned char
cli_wchar_to_char (wchar_t src, wcharset_t *charset)
{
  unsigned char dest = '?';
  if (charset && charset != CHARSET_UTF8 && src)
    {
	{
	  dest = (unsigned char) ((ptrlong) gethash ((void *)((ptrlong)src), charset->chrs_ht));
	  if (!dest)
	    dest = '?';
	}
    }
  else if (((unsigned long)src) < 0x100L)
    dest = (unsigned char) src;
  else
    dest = '?';
  return dest;
}


size_t
cli_wide_to_narrow (wcharset_t * charset, int flags, const wchar_t *src, size_t max_wides,
    unsigned char *dest, size_t max_len, char *default_char, int *default_used)
{
  size_t n = 0, w = 0;
  while (n < max_len && w < max_wides)
    {
      if (charset && *src)
	{
	  if (charset == CHARSET_UTF8)
	    {
	      char temp[VIRT_MB_CUR_MAX];
	      virt_mbstate_t st;
	      size_t len, len_written = 0;
	      memset (&st, 0, sizeof (st));
	      len = virt_wcrtomb ((unsigned char *) temp, *src, &st);
	      if (((long) len) > 0)
		{
		  len_written = MIN (len, max_len - n);
		  memcpy (dest, temp, len_written);
		  n += len_written - 1;
		  dest += len_written - 1;
		}
	      else
		*dest = '?';
	    }
	  else
	    {
	      *dest = (unsigned char) ((ptrlong) gethash ((void *)((ptrlong)(*src)), charset->chrs_ht));
	      if (!*dest)
		*dest = '?';
	    }
	}
      else if (((unsigned long)*src) < 0x100L)
	*dest = (unsigned char) *src;
      else
	*dest = '?';
      n++;
      w++;
      dest++;
      if (!*src)
	break;
      src++;
    }
  return n;
}


char *
cli_box_wide_to_narrow (const wchar_t * in)
{
  unsigned char *ret = NULL;
  if (in)
    {
      size_t len = wcslen (in);
      ret = (unsigned char *) dk_alloc_box (len + 1, DV_LONG_STRING);
      if (0 > (long) cli_wide_to_narrow (NULL, 0, in, len + 1, ret, len + 1, NULL, NULL))
	{
	  dk_free_box ((box_t) ret);
	  ret = NULL;
	}
    }
  return (char *) ret;
}


size_t
cli_narrow_to_wide (wcharset_t * charset, int flags, const unsigned char *src, size_t max_len,
    wchar_t *dest, size_t max_wides)
{
  size_t n = 0, w = 0;
  while (n < max_len && w < max_wides)
    {
      if (charset == CHARSET_UTF8)
	{
	  virt_mbstate_t st;
	  size_t len;
	  memset (&st, 0, sizeof (st));
	  len = virt_mbrtowc (dest, src, max_len - n, &st);
	  if (((long) len) > 0)
	    {
	      n += len - 1;
	      src += len - 1;
	    }
	}
      else
	*dest = charset ? charset->chrs_table[*src] : (wchar_t) *src;
      n++;
      w++;
      if (!*src)
	break;
      src++;
      dest++;
    }
  return w;
}


wchar_t *
cli_box_narrow_to_wide (const char * in)
{
  wchar_t *ret = NULL;
  if (in)
    {
      size_t len = strlen (in);
      ret = (wchar_t *) dk_alloc_box ((len + 1) * sizeof (wchar_t), DV_LONG_STRING);
      if (0 > (long) cli_narrow_to_wide (NULL, 0, (unsigned char *) in, len + 1, ret, len + 1))
	{
	  dk_free_box ((box_t) ret);
	  ret = NULL;
	}
    }
  return ret;
}


size_t
cli_utf8_to_narrow (wcharset_t * charset, const unsigned char *_str, size_t max_len, unsigned char *dst, size_t max_narrows)
{
  virt_mbstate_t state;
  size_t len, inx;
  unsigned char *str = (unsigned char *) _str, *src = (unsigned char *) _str;
  caddr_t box;
  memset (&state, 0, sizeof (virt_mbstate_t));
  len = virt_mbsnrtowcs (NULL, &src, max_len, 0, &state);
  if (max_narrows > 0 && len > max_narrows)
    len = max_narrows;
  if (((long) len) <= 0)
    return len;
  box = (caddr_t) dst;
  for (inx = 0, src = str, memset (&state, 0, sizeof (virt_mbstate_t)); inx < len; inx++)
    {
      wchar_t wc;
      size_t char_len = virt_mbrtowc (&wc, src, max_len - (src - str), &state);
      if (((long) char_len) <= 0)
	{
	  box[inx] = '?';
	  src++;
	}
      else
	{
	  box[inx] = cli_wchar_to_char (wc, charset);
	  src += char_len;
	}
    }
  box[len] = 0;
  return len;
}


size_t
cli_narrow_to_utf8 (wcharset_t *charset, const unsigned char *_str, size_t max_narrows, unsigned char *dst, size_t max_utf8)
{
  virt_mbstate_t state;
  size_t inx, inx_src = 0;
  unsigned char *str = (unsigned char *) _str, *src = (unsigned char *) _str;
  caddr_t box;

  memset (&state, 0, sizeof (virt_mbstate_t));
  box = (caddr_t) dst;
  for (inx = 0, src = str, memset (&state, 0, sizeof (virt_mbstate_t)); inx < max_utf8 && inx_src < max_narrows; inx++, src++, inx_src++)
    {
      wchar_t wc;
      size_t char_len;
      char utf8[VIRT_MB_CUR_MAX];
      wc = charset && charset != CHARSET_UTF8 ? charset->chrs_table[*src] : (wchar_t) *src;
      char_len = virt_wcrtomb ((unsigned char *) utf8, wc, &state);
      if (char_len <= 0)
	box[inx] = '?';
      else if (inx + char_len >= max_utf8)
	break;
      else
	{
	  memcpy (box + inx, utf8, char_len);
	  inx += char_len - 1;
	}
    }
  box[inx] = 0;
  return inx;
}


size_t
cli_wide_to_escaped (wcharset_t * charset, int flags, const wchar_t *src, size_t max_wides,
    unsigned char *dest, size_t max_len, char *default_char, int *default_used)
{
  size_t n = 0, w = 0;
  unsigned char *initial_dest = dest;

  while (n < max_len && w < max_wides)
    {
      if (charset && charset != CHARSET_UTF8 && *src)
	{
	  *dest = (unsigned char) ((ptrlong) gethash ((void *)((ptrlong)(*src)), charset->chrs_ht));
	  if (!*dest)
	    {
	      char buf[15];
	      int len;
	      snprintf (buf, sizeof (buf), "\\x%lX", (unsigned long)*src);
	      len = (int) strlen (buf);
	      if (len + n < max_len)
		{
		  strcpy_size_ck ((char *) dest, buf, max_len - (dest - initial_dest));
		  n += len - 1;
		  dest += len - 1;
		}
	      else
		*dest = '?';
	    }
	}
      else if (((unsigned long)*src) < 0x100L)
	*dest = (unsigned char) *src;
      else
	{
	  char buf[15];
	  int len;
	  snprintf (buf, sizeof (buf), "\\x%lX", (unsigned long)*src);
	  len = (int) strlen (buf);
	  if (len + n < max_len)
	    {
	      strcpy_size_ck ((char *) dest, buf, max_len - (dest - initial_dest));
	      n += len - 1;
	      dest += len - 1;
	    }
	  else
	    *dest = '?';
	}
      n++;
      w++;
      dest++;
      if (!*src)
	break;
      src++;
    }
  return n;
}


wcharset_t *
wide_charset_create (char *name, wchar_t *ltable, int table_len, caddr_t *aliases)
{
  int i;
  wchar_t elem;
  NEW_VARZ (wcharset_t, charset);

  charset->chrs_ht = hash_table_allocate (256);
  strcpy_ck (charset->chrs_name, name);
  for (i = 0; i < 255; i++)
    {
      if (i < table_len)
	elem = (wchar_t) ltable[i];
      else
	elem = (wchar_t) i + 1;
      charset->chrs_table[i + 1] = elem;
      sethash ((void *) (ptrlong) elem, charset->chrs_ht, (void *) (ptrlong) (i + 1));
    }
  charset->chrs_aliases = aliases;
  return (charset);
}


void
wide_charset_free (wcharset_t *charset)
{
  clrhash (charset->chrs_ht);
  dk_free_tree ((box_t) charset->chrs_aliases);
  dk_free (charset, sizeof (wcharset_t));
}


size_t
wide_as_utf8_len (caddr_t _wide)
{
  ptrlong _n = box_length (_wide);
  size_t _utf8_len;
  virt_mbstate_t state;
  memset (&state, 0, sizeof (virt_mbstate_t));

  _utf8_len = virt_wcsnrtombs (NULL, ((wchar_t **)(&_wide)), _n / sizeof (wchar_t) - 1, 0, &state);
  if (((long) _utf8_len) < 0)
    GPF_T1 ("Obscure wide string in wide_as_utf8_len");
  return _utf8_len;
}


wchar_t *
virt_wcsdup(const wchar_t *s)
{
  wchar_t *ret = NULL;
  if (s)
    {
      size_t len = wcslen (s);
      ret = (wchar_t *) malloc ((len + 1) * sizeof (wchar_t));
      if (ret)
	memcpy (ret, s, (len + 1) * sizeof (wchar_t));
    }
  return ret;
}


/* note: that will work only for latin1, but that's all the driver needs it for */
int
virt_wcscasecmp(const wchar_t *s1, const wchar_t *s2)
{
  char *ns1 = cli_box_wide_to_narrow (s1);
  char *ns2 = cli_box_wide_to_narrow (s2);
  int ret = stricmp (ns1, ns2);
  dk_free_box (ns1);
  dk_free_box (ns2);
  return ret;
}

int
wide_atoi (caddr_t data)
{
  char *ndata = cli_box_wide_to_narrow ((wchar_t *) data);
  int ret = atoi (ndata);
  dk_free_box (ndata);
  return ret;
}

caddr_t
box_wide_string (const wchar_t *wstr)
{
  caddr_t ret = NULL;
  if (wstr)
    {
      size_t len = (wcslen (wstr) + 1) * sizeof (wchar_t);
      ret = dk_alloc_box (len, DV_WIDE);
      memcpy (ret, wstr, len);
    }
  return ret;
}

#ifdef UTF8_DEBUG

#define GUESS_ENC_UNKNOWN	0
#define GUESS_UTF8		1
#define GUESS_8BIT		2
#define GUESS_WCHAR		3
#define GUESS_UTF8_OF_UTF8	4
#define GUESS_UTF8_OF_8BIT	5
#define GUESS_UTF8_OF_WCHAR	6
#define GUESS_WCHAR_OF_UTF8	7
#define GUESS_WCHAR_OF_8BIT	8
#define GUESS_WCHAR_OF_WCHAR	9
#define COUNTOF__GUESS_ENC	10

static const char *guess_encoding_names [COUNTOF__GUESS_ENC] = {
  "(unidentified encoding, maybe ASCII)"	, /* GUESS_ENC_UNKNOWN	*/
  "UTF-8"					, /* GUESS_UTF8		*/
  "8-bit"					, /* GUESS_8BIT		*/
  "wide"					, /* GUESS_WCHAR	*/
  "overencoded UTF-8 of UTF-8"			, /* GUESS_UTF8_OF_UTF8	*/
  "overencoded UTF-8 of 8-bit"			, /* GUESS_UTF8_OF_8BIT	*/
  "overencoded UTF-8 of wide"			, /* GUESS_UTF8_OF_WCHAR	*/
  "overencoded wide of UTF-8"			, /* GUESS_WCHAR_OF_UTF8	*/
  "overencoded wide of 8-bit"			, /* GUESS_WCHAR_OF_8BIT	*/
  "overencoded wide of wide"			/* GUESS_WCHAR_OF_WCHAR	*/
};

/* Important: the guess works fine only with Cyrillic, Make extra tests for other alphabets.

Proper Cyrillic in UTF-8:
P       r       i       v       e       t
\320\237\321\200\320\270\320\262\320\265\321\202

Overencoded Cyrillic in UTF-8 of UTF-8
P               r                   i                   v                   e                   t
\320\277\303\267\321\217\342\224\200\320\277\342\225\246\320\277\342\225\241\320\277\342\225\243\321\217\342\224\214

*/

int
guess_nchars_enc (const unsigned char *buf, size_t buflen)
{
  const unsigned char *tail = buf;
  const unsigned char *end = buf+buflen;
  const unsigned char *lastwc = ((void *)(((wchar_t *)end) - 1));
  wchar_t prev_wc = 0;
  int curr_res = GUESS_ENC_UNKNOWN, curr_score = 0, ctr;
  int scores [COUNTOF__GUESS_ENC];
  memset (scores, 0, COUNTOF__GUESS_ENC * sizeof (int));
  while (tail < end)
    {
      unsigned char c = tail[0];
      wchar_t wc = ((wchar_t *)tail)[0];
      if ((tail >= (buf+3)) && (0xD0 == tail[-3]) && (0xBF == tail[-2]) && (0xC0 == (tail[-1] & ~0x03)) && (0x80 == (c & ~0x3F)))
        scores [GUESS_UTF8_OF_UTF8] += (8+8+6+2);
      if ((tail >= (buf+4)) && (0xD0 == tail[-4]) && (0xBF == tail[-3]) && (0xE0 == (tail[-2] & ~0x03)) && (0x94 == (tail[-1] & ~0x03)) && (0x80 == (c & ~0x3F)))
        scores [GUESS_UTF8_OF_UTF8] += (8+8+6+6+2);
      if ((tail >= (buf+4)) && (0xD1 == tail[-4]) && (0x8F == tail[-3]) && (0xE0 == (tail[-2] & ~0x03)) && (0x94 == (tail[-1] & ~0x03)) && (0x80 == (c & ~0x3F)))
        scores [GUESS_UTF8_OF_UTF8] += (8+8+6+6+2);
      if ((tail >= (buf+3)) && (0 == tail[-3]) && (0 == tail[-2]) && (0xC0 == (tail[-1] & ~0x03)) && (0x80 == (c & ~0x3F)))
        scores [GUESS_UTF8_OF_WCHAR] += (8+8+6+2);
      if ((tail > buf) && (0xC0 == (tail[-1] & ~0x03)) && (0x80 == (c & ~0x3F)))
        scores [GUESS_UTF8_OF_8BIT] += (6+2);
      if ((tail > buf) && (0xD0 == (tail[-1] & ~0x07)) && (0x80 == (c & ~0x3F)))
        scores [GUESS_UTF8] += (5+2);
      if (0x80 == (c & ~0x7F))
        scores [GUESS_8BIT] += 1;
      if ((tail < lastwc) && (0 == (wc & ~0x7FF))) /* Probably wchars */
        {
          if ((0xD0 == (prev_wc & ~0x07)) && (0x80 == (wc & ~0x3F)))
            scores [GUESS_WCHAR_OF_UTF8] += (16 * sizeof (wchar_t) - (2+6));
          if ((0x80 == (prev_wc & ~0x7F)) && (0x80 == (wc & ~0x7F)))
            scores [GUESS_WCHAR_OF_8BIT] += (16 * sizeof (wchar_t) - (7+7));
          if ((0 == prev_wc) && (0 == wc))
            scores [GUESS_WCHAR_OF_WCHAR] += (16 * sizeof (wchar_t));
          scores [GUESS_WCHAR] += (8 * sizeof (wchar_t) - 11);
          tail += (sizeof (wchar_t) - 1);
        }
      tail++;
    }
  for (ctr = COUNTOF__GUESS_ENC; ctr--; /* no step */)
    {
      if (scores [ctr] >= curr_score)
        {
          curr_score = scores [ctr];
          curr_res = ctr;
        }
    }
  return curr_res;
}

void dbg_dump_encoded_nchars (const char *buf, size_t len, size_t max_len)
{
  const char *tail = buf;
  const char *end = buf+len;
  if (len > max_len)
    end = buf+max_len;
  putchar ('\"');
  while (tail < end)
    {
      switch (tail[0])
        {
	case '\'': printf ("\\\'"); break;
	case '\"': printf ("\\\""); break;
	case '\r': printf ("\\r"); break;
	case '\n': printf ("\\n"); break;
	case '\t': printf ("\\t"); break;
	case '\\': printf ("\\\\"); break;
	default:
          if (((unsigned char)(tail[0]) < ' ') || (0x80 & tail[0]))
	    printf ("\\x%02x", (unsigned char)(tail[0]));
	  else
	    putchar (tail[0]);
	}
      tail++;
    }
  if (len > max_len)
    printf ("...");
  putchar ('\"');
}

#define PRINTF_BAD_ENC_INT(enc,expected,type,buf,len) do { \
  printf ("\nUTF8_DEBUG\n%s(%d): %s instead of %s, %s box is ", file, line, guess_encoding_names[enc], expected, type); \
  dbg_dump_encoded_nchars (buf, len, 100); \
  printf ("\n"); } while (0)

#define PRINTF_BAD_BF_INT(bf,enc,type,buf,len) do { \
  printf ("\nUTF8_DEBUG\n%s(%d): %x flags of %s %s box is ", file, line, bf, guess_encoding_names[enc], type); \
  dbg_dump_encoded_nchars (buf, len, 100); \
  printf ("\n"); } while (0)

void
assert_box_enc_matches_bf (const char *file, int line, ccaddr_t box, int expected_bf_if_zero)
{
  int enc, bf;
  bf = box_flags (box);
  switch (DV_TYPE_OF(box))
    {
    case DV_UNAME:
      enc = guess_nchars_enc ((const unsigned char *)box, box_length (box) - 1);
      if (0 != bf)
        PRINTF_BAD_BF_INT (bf, enc, "DV_UNAME", box, box_length (box) - 1);
      if ((GUESS_UTF8 != enc) && (GUESS_ENC_UNKNOWN != enc))
        PRINTF_BAD_ENC_INT (enc, "UTF-8", "DV_UNAME", box, box_length (box) - 1);
      break;
    case DV_WIDE:
      enc = guess_nchars_enc ((const unsigned char *)box, box_length (box));
      if (0 != bf)
        PRINTF_BAD_BF_INT (bf, enc, "DV_UNAME", box, box_length (box) - sizeof (wchar_t));
      if ((GUESS_WCHAR != enc) && (GUESS_ENC_UNKNOWN != enc))
        PRINTF_BAD_ENC_INT (enc, "wide", "DV_WIDE", box, box_length (box) - sizeof (wchar_t));
      break;
    case DV_STRING:
      enc = guess_nchars_enc ((const unsigned char *)box, box_length (box) - 1);
      if (0 == (box_flags(box) & (BF_IRI | BF_UTF8 | BF_DEFAULT_SERVER_ENC)))
        {
          if ((GUESS_UTF8 != enc) && (GUESS_8BIT != enc) && (GUESS_ENC_UNKNOWN != enc))
            PRINTF_BAD_ENC_INT (enc, "8-bit or UTF-8", "DV_STRING", box, box_length (box) - 1);
          if (expected_bf_if_zero & (BF_IRI | BF_UTF8))
            {
              if ((GUESS_UTF8 != enc) && (GUESS_ENC_UNKNOWN != enc))
                PRINTF_BAD_ENC_INT (enc, "presumably UTF-8", "DV_STRING", box, box_length (box) - 1);
            }
          if (expected_bf_if_zero & (BF_DEFAULT_SERVER_ENC))
            {
              if ((GUESS_8BIT != enc) && (GUESS_ENC_UNKNOWN != enc))
                PRINTF_BAD_ENC_INT (enc, "presumably 8-bit", "DV_STRING", box, box_length (box) - 1);
            }
        }
      else
        {
          if (box_flags(box) & (BF_IRI | BF_UTF8))
            {
              if ((GUESS_UTF8 != enc) && (GUESS_ENC_UNKNOWN != enc))
                PRINTF_BAD_ENC_INT (enc, "UTF-8", "DV_STRING", box, box_length (box) - 1);
            }
          if (box_flags(box) & (BF_DEFAULT_SERVER_ENC))
            {
              if ((GUESS_8BIT != enc) && (GUESS_ENC_UNKNOWN != enc))
                PRINTF_BAD_ENC_INT (enc, "8-bit", "DV_STRING", box, box_length (box) - 1);
            }
        }
      if (box_flags(box) & ~(BF_IRI | BF_UTF8 | BF_DEFAULT_SERVER_ENC))
        PRINTF_BAD_BF_INT (bf, enc, "DV_WIDE", box, box_length (box) - 1);
    default:
      break;
    }
}

void
assert_box_utf8 (const char *file, int line, caddr_t box)
{
  int enc = guess_nchars_enc ((const unsigned char *)box, box_length (box) - 1);
  if ((GUESS_UTF8 != enc) && (GUESS_ENC_UNKNOWN != enc))
    PRINTF_BAD_ENC_INT (enc, "UTF-8", "(?)", box, box_length (box) - 1);
}

void
assert_box_8bit (const char *file, int line, caddr_t box)
{
  int enc = guess_nchars_enc ((const unsigned char *)box, box_length (box) - 1);
  if ((GUESS_8BIT != enc) && (GUESS_ENC_UNKNOWN != enc))
    PRINTF_BAD_ENC_INT (enc, "8-bit", "(?)", box, box_length (box) - 1);
}

void
assert_box_wchar (const char *file, int line, caddr_t box)
{
  int enc = guess_nchars_enc ((const unsigned char *)box, box_length (box) - 1);
  if ((GUESS_WCHAR != enc) && (GUESS_ENC_UNKNOWN != enc))
    PRINTF_BAD_ENC_INT (enc, "WIDE", "(?)", box, box_length (box) - 1);
}

void
assert_nchars_utf8 (const char *file, int line, const char *buf, size_t len)
{
  int enc = guess_nchars_enc ((const unsigned char *)buf, len);
  if ((GUESS_UTF8 != enc) && (GUESS_ENC_UNKNOWN != enc))
    PRINTF_BAD_ENC_INT (enc, "UTF-8", "(?)", buf, len);
}

void
assert_nchars_8bit (const char *file, int line, const char *buf, size_t len)
{
  int enc = guess_nchars_enc ((const unsigned char *)buf, len);
  if ((GUESS_8BIT != enc) && (GUESS_ENC_UNKNOWN != enc))
    PRINTF_BAD_ENC_INT (enc, "8-bit", "(?)", buf, len);
}

void
assert_nchars_wchar (const char *file, int line, const char *buf, size_t len)
{
  int enc = guess_nchars_enc ((const unsigned char *)buf, len);
  if ((GUESS_WCHAR != enc) && (GUESS_ENC_UNKNOWN != enc))
    PRINTF_BAD_ENC_INT (enc, "WIDE", "(?)", buf, len);
}

#endif
