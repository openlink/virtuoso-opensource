/*
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

#include <ctype.h>
#include <stdlib.h>
#include <limits.h>
#include "langfunc.h"

#ifndef _MSC_VER
#define iswdigit isdigit
#define iswalpha isalpha
#endif

extern lang_handler_t lh__xViAny;
extern lang_handler_t lh__xftqxViAny;

#define ISSPECIAL(X) (('_' == (X)) || ('&' == (X)) || ('-' == (X)))

#define ISWALPHA(X) (iswalpha(X) || ISSPECIAL (X))

static int unichar_getprops_point__xViAny(const unichar *ptr)
{
  unichar before, after;
  if ((ptr[-1] & ~0xFF) || ptr[+1] & ~0xFF)
    return UCP_PUNCT;
  before = ptr[-1];
  after = ptr[+1];
  if (iswdigit((unsigned)before) && iswdigit((unsigned)after))
    return UCP_ALPHA;
  if (ISWALPHA((unsigned)before) && ISWALPHA((unsigned)after))
    return UCP_ALPHA;
  return UCP_PUNCT;
}


#define LH_COUNT_WORDS_NAME lh_count_words__xViAny
#define LH_ITERATE_WORDS_NAME lh_iterate_words__xViAny
#define LH_ITERATE_PATCHED_WORDS_NAME lh_iterate_patched_words__xViAny
#define UNICHAR_GETPROPS_EXPN(buf,bufsize,pos) \
(('.' == buf[pos]) ? \
  (((pos > 0) && (pos+1 < bufsize)) ? unichar_getprops_point__xViAny(buf+pos) : UCP_PUNCT) : \
  (ISSPECIAL(buf[pos]) ? UCP_ALPHA : unichar_getprops (buf[pos])) )
#define DBG_PRINTF_NOISE_WORD(word_start,word_length) dbg_printf (("Noise word in x-ViAny text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of word failed in x-ViAny text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_NOISE_IDEO(word_start,word_length) dbg_printf (("Noise ideograph in x-ViAny text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_IDEO_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of ideograph failed in x-ViAny text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#include "langfunc_templ.c"
#undef LH_COUNT_WORDS_NAME
#undef LH_ITERATE_WORDS_NAME
#undef LH_ITERATE_PATCHED_WORDS_NAME
#undef UNICHAR_GETPROPS_EXPN
#undef DBG_PRINTF_NOISE_WORD
#undef DBG_PRINTF_PATCH_FAILED
#undef DBG_PRINTF_NOISE_IDEO
#undef DBG_PRINTF_IDEO_PATCH_FAILED


static int unichar_getprops_point__xftqxViAny(const unichar *ptr)
{
  unichar before, after;
  if ((ptr[-1] & ~0xFF) || ptr[+1] & ~0xFF)
    return UCP_PUNCT;
  before = ptr[-1];
  after = ptr[+1];
  if (('*' == before) && (('*' == after) || iswdigit((unsigned)after) || ISWALPHA((unsigned)after)))
    return UCP_ALPHA;
  if (iswdigit((unsigned)before) && (('*' == after) || iswdigit((unsigned)after)))
    return UCP_ALPHA;
  if (ISWALPHA((unsigned)before) && (('*' == after) || ISWALPHA((unsigned)after)))
    return UCP_ALPHA;
  return UCP_PUNCT;
}


#define LH_COUNT_WORDS_NAME lh_count_words__xftqxViAny
#define LH_ITERATE_WORDS_NAME lh_iterate_words__xftqxViAny
#define LH_ITERATE_PATCHED_WORDS_NAME lh_iterate_patched_words__xftqxViAny
#define UNICHAR_GETPROPS_EXPN(buf,bufsize,pos) \
(('.' == buf[pos]) ? \
  (((pos > 0) && (pos+1 < bufsize)) ? unichar_getprops_point__xftqxViAny(buf+pos) : UCP_PUNCT) : \
  (('*' == buf[pos]) ? UCP_ALPHA : \
  (ISSPECIAL(buf[pos]) ? UCP_ALPHA : unichar_getprops (buf[pos])) ))
#define DBG_PRINTF_NOISE_WORD(word_start,word_length) dbg_printf (("Noise word in x-ViAny query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of word failed in x-ViAny query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_NOISE_IDEO(word_start,word_length) dbg_printf (("Noise ideograph in x-ViAny query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_IDEO_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of ideograph failed in x-ViAny query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#include "langfunc_templ.c"
#undef LH_COUNT_WORDS_NAME
#undef LH_ITERATE_WORDS_NAME
#undef LH_ITERATE_PATCHED_WORDS_NAME
#undef UNICHAR_GETPROPS_EXPN
#undef DBG_PRINTF_NOISE_WORD
#undef DBG_PRINTF_PATCH_FAILED
#undef DBG_PRINTF_NOISE_IDEO
#undef DBG_PRINTF_IDEO_PATCH_FAILED

int lh_is_vtb_word__xViAny (const unichar *buf, size_t bufsize)
{
  lenmem_t lm;
  char *nw;
  if (1 > bufsize)
    return 0;
  lm.lm_length = bufsize * sizeof(unichar);
  lm.lm_memblock = (/*const*/ char *)buf;
  nw = id_hash_get (lh_noise_words, (char *) &lm);
  if (NULL == nw)
    return 1;
  return 0;
}


lang_handler_t lh__xViAny = {
  "x-ViAny",		/* ISO 639 */
  "x-ViAny",		/* RFC 1766 */
  NULL,			/* more generic handler, will be set to handler for "x-any" before first use */
  &lh__xftqxViAny,	/* query language handler */
  1, WORD_MAX_CHARS,	/* minimal and maximal lengths of one indexable word */
  NULL,			/* application-specific data */
  lh_is_vtb_word__xViAny,/* lh_is_vtb_word */
  NULL,			/* lh_tocapital_word */
  NULL,			/* lh_toupper_word */
  NULL,			/* lh_tolower_word */
  NULL /*lh_normalize_word__xViAny*/ ,
  lh_count_words__xViAny,		/* lh_count_words */
  lh_iterate_words__xViAny,		/* lh_iterate_words */
  lh_iterate_patched_words__xViAny,	/* lh_iterate_patched_words */
#ifdef HYPHENATION_OK
  NULL			/* lh_iterate_hyppoints */
#endif
};

lang_handler_t lh__xftqxViAny = {
  "x-ftq-x-ViAny",	/* ISO 639 */
  "x-ftq-x-ViAny",	/* RFC 1766 */
  NULL,			/* more generic handler, will be set to handler for "x-ftq-x-any" before first use */
  &lh__xftqxViAny,	/* query language handler */
  1, WORD_MAX_CHARS,	/* minimal and maximal lengths of one indexable word */
  NULL,			/* application-specific data */
  lh_is_vtb_word__xViAny,/* lh_is_vtb_word */
  NULL,			/* lh_tocapital_word */
  NULL,			/* lh_toupper_word */
  NULL,			/* lh_tolower_word */
  NULL /*lh_normalize_word__xViAny*/ ,
  lh_count_words__xftqxViAny,		/* lh_count_words */
  lh_iterate_words__xftqxViAny,		/* lh_iterate_words */
  lh_iterate_patched_words__xftqxViAny,	/* lh_iterate_patched_words */
#ifdef HYPHENATION_OK
  NULL			/* lh_iterate_hyppoints */
#endif
};

#define IS_CONNECTIVE ((uchr == '.' && word_length == 1) || (uchr == '-') || (uchr == '&'))

int elh_count_words__xViAny__UTF8(const char *buf, size_t bufsize, lh_word_check_t *check)
{
  unichar check_buf[WORD_MAX_CHARS];
  int res = 0;
  int prop;
  const char *curr = buf;
  const char *buf_end = buf+bufsize;
  const char *word_begin = curr;
  const char *word_end = NULL;
  unichar uchr;
  size_t word_length;
  while (curr < buf_end)
    {
      word_begin = curr;
      uchr = eh_decode_char__UTF8 (&curr, buf_end);
      prop = unichar_getprops (uchr);
      if (prop & UCP_ALPHA)
	{
	  check_buf[0] = uchr;
	  word_length = 1;
	  for(;;)
	    {
	      word_end = curr;
	      uchr = eh_decode_char__UTF8 (&curr, buf_end);
	      if (uchr < 0)
		{
		  if ((UNICHAR_NO_DATA == uchr) || (UNICHAR_BAD_ENCODING == uchr))
		    return uchr;
		  if (UNICHAR_EOD == uchr)
		    break;
		}
	      prop = unichar_getprops (uchr);
	      if (!(prop & UCP_ALPHA) && !IS_CONNECTIVE)
		break;
	      if (WORD_MAX_CHARS > word_length)
		check_buf[word_length] = uchr;
	      word_length++;
	    }
	  if (WORD_MAX_CHARS < word_length)
	    goto done_word;
	  if (NULL!=check && 0 == check(check_buf, word_length))
	    goto done_word;
	  res++;
done_word:
	  if (prop & UCP_IDEO)
	    goto proc_ideo;
	  continue;
	}
      if (prop & UCP_IDEO)
	{
proc_ideo:
	  check_buf[0] = uchr;
	  if (NULL!=check && 0 == check(check_buf, 1))
	    continue;
	  res++;
	  continue;
	}
      if ((uchr < 0) && ((UNICHAR_NO_DATA == uchr) || (UNICHAR_BAD_ENCODING == uchr)))
	return uchr;
    }
  return res;
}


int elh_iterate_words__xViAny__UTF8(const char *buf, size_t bufsize, lh_word_check_t *check, lh_word_callback_t *callback, void *userdata)
{
  unichar check_buf[WORD_MAX_CHARS];
  int prop;
  const char *curr = buf;
  const char *buf_end = buf+bufsize;
  const char *word_begin = curr;
  const char *word_end;
  unichar uchr;
  size_t word_length;
  while (curr < buf_end)
    {
      word_begin = curr;
      uchr = eh_decode_char__UTF8 (&curr, buf_end);
      prop = unichar_getprops (uchr);
      if (prop & UCP_ALPHA)
	{
	  check_buf[0] = uchr;
	  word_length = 1;
	  for(;;)
	    {
	      word_end = curr;
	      uchr = eh_decode_char__UTF8 (&curr, buf_end);
	      if (uchr < 0)
		{
		  if ((UNICHAR_NO_DATA == uchr) || (UNICHAR_BAD_ENCODING == uchr))
		    return uchr;
		  if (UNICHAR_EOD == uchr)
		    break;
		}
	      prop = unichar_getprops (uchr);
	      if (!(prop & UCP_ALPHA) && !IS_CONNECTIVE)
		break;
	      if (WORD_MAX_CHARS > word_length)
		check_buf[word_length] = uchr;
	      word_length++;
	    }
	  if (WORD_MAX_CHARS < word_length)
	    goto done_word;
	  if (NULL!=check && 0 == check (check_buf, word_length))
	    goto done_word;
	  callback ((utf8char *)(word_begin), word_end-word_begin, userdata);
done_word:
	  if (prop & UCP_IDEO)
	    goto proc_ideo;
	  continue;
	}
      if (prop & UCP_IDEO)
	{
proc_ideo:
	  check_buf[0] = uchr;
	  if (NULL!=check && 0 == check (check_buf, 1))
	    continue;
	  callback ((utf8char *)(word_begin), curr-word_begin, userdata);
	  continue;
	}
      if ((uchr < 0) && ((UNICHAR_NO_DATA == uchr) || (UNICHAR_BAD_ENCODING == uchr)))
	return uchr;
    }
  return 0;
}


int elh_iterate_patched_words__xViAny__UTF8(const char *buf, size_t bufsize, lh_word_check_t *check, lh_word_patch_t *patch, lh_word_callback_t *callback, void *userdata)
{
  unichar check_buf[WORD_MAX_CHARS];
  int prop;
  const char *curr = buf;
  const char *buf_end = buf+bufsize;
  const char *word_begin = curr;
  const char *word_end = NULL;
  unichar uchr;
  size_t word_length;
  unichar patch_buf[WORD_MAX_CHARS];
  const unichar *arg_begin;
  size_t arg_length;
  char word_buf[BUFSIZEOF__UTF8_WORD];
  char *hugeword_buf = NULL;
  size_t hugeword_buf_size = 0;
  while (curr < buf_end)
    {
      word_begin = curr;
      uchr = eh_decode_char__UTF8 (&curr, buf_end);
      prop = unichar_getprops (uchr);
      if (prop & UCP_ALPHA)
	{
	  check_buf[0] = uchr;
	  word_length = 1;
	  for(;;)
	    {
	      word_end = curr;
	      uchr = eh_decode_char__UTF8 (&curr, buf_end);
	      if (uchr < 0)
		{
		  if ((UNICHAR_NO_DATA == uchr) || (UNICHAR_BAD_ENCODING == uchr))
		    return uchr;
		  if (UNICHAR_EOD == uchr)
		    break;
		}
	      prop = unichar_getprops (uchr);
	      if (!(prop & UCP_ALPHA) && !IS_CONNECTIVE)
		break;
	      if (WORD_MAX_CHARS > word_length)
		check_buf[word_length] = uchr;
	      word_length++;
	    }
	  if (WORD_MAX_CHARS < word_length)
	    goto done_word;
	  if (NULL!=check && 0 == check (check_buf, word_length))
	    goto done_word;
	  if (NULL != patch)
	    {
	      if (0 == patch (check_buf, word_length, patch_buf, &arg_length))
		goto done_word;
	      arg_begin = patch_buf;
	    }
	  else
	    {
	      callback ((utf8char *) word_begin, word_end-word_begin, userdata);
	      goto done_word;
	    }
	  word_end = eh_encode_buffer__UTF8 (arg_begin, arg_begin+arg_length, word_buf, word_buf+BUFSIZEOF__UTF8_WORD);
	  if (NULL != word_end)
	    {
	      callback ((utf8char *)(word_buf), word_end-word_buf, userdata);
	      goto done_word;
	    }
	  if (hugeword_buf_size<(word_length*MAX_UTF8_CHAR))
	    {
	      if (hugeword_buf_size)
		dk_free (hugeword_buf, hugeword_buf_size);
	      hugeword_buf_size = word_length*MAX_UTF8_CHAR;
	      hugeword_buf = (char *) dk_alloc (hugeword_buf_size);
	    }
	  word_end = eh_encode_buffer__UTF8 (arg_begin, arg_begin+arg_length, hugeword_buf, hugeword_buf+hugeword_buf_size);
	  callback ((utf8char *)(hugeword_buf), word_end-hugeword_buf, userdata);
done_word:
	  if (prop & UCP_IDEO)
	    goto proc_ideo;
	  continue;
	}
      if (prop & UCP_IDEO)
	{
proc_ideo:
	  check_buf[0] = uchr;
	  if (NULL!=check && 0 == check (check_buf, 1))
	    continue;
	  if (NULL != patch)
	    {
	      if (0 == patch (check_buf, 1, patch_buf, &arg_length))
		continue;
	      arg_begin = patch_buf;
	    }
	  else
	    {
	      callback ((utf8char *) word_begin, curr-word_begin, userdata);
	      continue;
	    }
	  word_end = eh_encode_buffer__UTF8 (arg_begin, arg_begin+arg_length, word_buf, word_buf+BUFSIZEOF__UTF8_WORD);
	  callback ((utf8char *)(word_buf), word_end-word_buf, userdata);
	  continue;
	}
      if ((uchr < 0) && ((UNICHAR_NO_DATA == uchr) || (UNICHAR_BAD_ENCODING == uchr)))
	goto cleanup; /* see below */
    }
  uchr = 0;
cleanup:
  if (hugeword_buf_size)
    dk_free (hugeword_buf, hugeword_buf_size);
  return uchr;
}

encodedlang_handler_t elh__xViAny__UTF8 = {
  &lh__xViAny,
  &eh__UTF8,
  NULL /*&elh__xftqxany__UTF8*/,
  NULL,/* application-specific data */
  elh_count_words__xViAny__UTF8,
  elh_iterate_words__xViAny__UTF8,
  elh_iterate_patched_words__xViAny__UTF8,
#ifdef HYPHENATION_OK
  elh_iterate_hyppoints__xany__UTF8
#endif
};

void connect__xViAny(void *appdata)
{
  lh__xViAny.lh_superlanguage = lh_get_handler("x-any");
  lh__xftqxViAny.lh_superlanguage = lh__xViAny.lh_superlanguage->lh_ftq_language;
  lh_load_handler(&lh__xViAny);
  lh_load_handler(&lh__xftqxViAny);
  elh_load_handler (&elh__xViAny__UTF8);
}
