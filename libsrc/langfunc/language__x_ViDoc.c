/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2017 OpenLink Software
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
#include <ctype.h>
#include <stdlib.h>
#include <limits.h>
#include "langfunc.h"

#ifndef _MSC_VER
#define iswdigit isdigit
#define iswalpha isalpha
#endif

extern lang_handler_t lh__xViDoc;
extern lang_handler_t lh__xftqxViDoc;

#define ISWALPHA(X) (iswalpha(X) || ('_' == X))

static int unichar_getprops_point__xViDoc(const unichar *ptr)
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


#define LH_COUNT_WORDS_NAME lh_count_words__xViDoc
#define LH_ITERATE_WORDS_NAME lh_iterate_words__xViDoc
#define LH_ITERATE_PATCHED_WORDS_NAME lh_iterate_patched_words__xViDoc
#define UNICHAR_GETPROPS_EXPN(buf,bufsize,pos) \
(('.' == buf[pos]) ? \
  (((pos > 0) && (pos+1 < bufsize)) ? unichar_getprops_point__xViDoc(buf+pos) : UCP_PUNCT) : \
  (('_' == buf[pos]) ? UCP_ALPHA : unichar_getprops (buf[pos])) )
#define DBG_PRINTF_NOISE_WORD(word_start,word_length) dbg_printf (("Noise word in x-ViDoc text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of word failed in x-ViDoc text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_NOISE_IDEO(word_start,word_length) dbg_printf (("Noise ideograph in x-ViDoc text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_IDEO_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of ideograph failed in x-ViDoc text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#include "langfunc_templ.c"
#undef LH_COUNT_WORDS_NAME
#undef LH_ITERATE_WORDS_NAME
#undef LH_ITERATE_PATCHED_WORDS_NAME
#undef UNICHAR_GETPROPS_EXPN
#undef DBG_PRINTF_NOISE_WORD
#undef DBG_PRINTF_PATCH_FAILED
#undef DBG_PRINTF_NOISE_IDEO
#undef DBG_PRINTF_IDEO_PATCH_FAILED


static int unichar_getprops_point__xftqxViDoc(const unichar *ptr)
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


#define LH_COUNT_WORDS_NAME lh_count_words__xftqxViDoc
#define LH_ITERATE_WORDS_NAME lh_iterate_words__xftqxViDoc
#define LH_ITERATE_PATCHED_WORDS_NAME lh_iterate_patched_words__xftqxViDoc
#define UNICHAR_GETPROPS_EXPN(buf,bufsize,pos) \
(('.' == buf[pos]) ? \
  (((pos > 0) && (pos+1 < bufsize)) ? unichar_getprops_point__xftqxViDoc(buf+pos) : UCP_PUNCT) : \
  (('*' == buf[pos]) ? UCP_ALPHA : \
  (('_' == buf[pos]) ? UCP_ALPHA : unichar_getprops (buf[pos])) ))
#define DBG_PRINTF_NOISE_WORD(word_start,word_length) dbg_printf (("Noise word in x-ViDoc query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of word failed in x-ViDoc query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_NOISE_IDEO(word_start,word_length) dbg_printf (("Noise ideograph in x-ViDoc query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_IDEO_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of ideograph failed in x-ViDoc query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#include "langfunc_templ.c"
#undef LH_COUNT_WORDS_NAME
#undef LH_ITERATE_WORDS_NAME
#undef LH_ITERATE_PATCHED_WORDS_NAME
#undef UNICHAR_GETPROPS_EXPN
#undef DBG_PRINTF_NOISE_WORD
#undef DBG_PRINTF_PATCH_FAILED
#undef DBG_PRINTF_NOISE_IDEO
#undef DBG_PRINTF_IDEO_PATCH_FAILED


lang_handler_t lh__xViDoc = {
  "x-ViDoc",		/* ISO 639 */
  "x-ViDoc",		/* RFC 1766 */
  NULL,			/* more generic handler, will be set to handler for "x-any" before first use */
  &lh__xftqxViDoc,	/* query language handler */
  1, WORD_MAX_CHARS,	/* minimal and maximal lengths of one indexable word */
  NULL,			/* application-specific data */
  NULL,			/* lh_is_vtb_word */
  NULL,			/* lh_tocapital_word */
  NULL,			/* lh_toupper_word */
  NULL,			/* lh_tolower_word */
  NULL /*lh_normalize_word__xViDoc*/ ,
  lh_count_words__xViDoc,		/* lh_count_words */
  lh_iterate_words__xViDoc,		/* lh_iterate_words */
  lh_iterate_patched_words__xViDoc,	/* lh_iterate_patched_words */
#ifdef HYPHENATION_OK
  NULL			/* lh_iterate_hyppoints */
#endif
};


lang_handler_t lh__xftqxViDoc = {
  "x-ftq-x-ViDoc",	/* ISO 639 */
  "x-ftq-x-ViDoc",	/* RFC 1766 */
  NULL,			/* more generic handler, will be set to handler for "x-ftq-x-any" before first use */
  &lh__xftqxViDoc,	/* query language handler */
  1, WORD_MAX_CHARS,	/* minimal and maximal lengths of one indexable word */
  NULL,			/* application-specific data */
  NULL,			/* lh_is_vtb_word */
  NULL,			/* lh_tocapital_word */
  NULL,			/* lh_toupper_word */
  NULL,			/* lh_tolower_word */
  NULL /*lh_normalize_word__xViDoc*/ ,
  lh_count_words__xftqxViDoc,		/* lh_count_words */
  lh_iterate_words__xftqxViDoc,		/* lh_iterate_words */
  lh_iterate_patched_words__xftqxViDoc,	/* lh_iterate_patched_words */
#ifdef HYPHENATION_OK
  NULL			/* lh_iterate_hyppoints */
#endif
};


void connect__xViDoc(void *appdata)
{
  lh__xViDoc.lh_superlanguage = lh_get_handler("en");	/* in case of trouble, it looks like English :) */
  lh__xftqxViDoc.lh_superlanguage = lh__xViDoc.lh_superlanguage->lh_ftq_language;
  lh_load_handler(&lh__xViDoc);
  lh_load_handler(&lh__xftqxViDoc);
}
