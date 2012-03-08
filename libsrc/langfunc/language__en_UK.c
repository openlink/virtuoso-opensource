/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2012 OpenLink Software
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
#include "plugin.h"
#ifdef _MSC_VER
#include "import_plugin_lang25.h"
#endif

#ifndef dk_alloc
extern void *dk_alloc (size_t sz);
#endif
#ifndef dk_free
extern void dk_free (void *alloc, size_t sz);
#endif

#ifndef dbg_printf
#ifdef DEBUG
#define dbg_printf(arglist) printf arglist
#else
#define dbg_printf(arglist)
#endif
#endif

#ifndef _MSC_VER
#define iswdigit isdigit
#define iswalpha isalpha
#endif

extern lang_handler_t lh__enUK;
extern lang_handler_t lh__xftqenUK;

static int unichar_getprops_point__enUK(const unichar *ptr)
{
  unichar before, after;
  if ((ptr[-1] & ~0xFF) || ptr[+1] & ~0xFF)
    return UCP_PUNCT;
  before = ptr[-1];
  after = ptr[+1];
  if (iswdigit(before) && iswdigit(after))
    return UCP_ALPHA;
  if (iswalpha(before) && iswalpha(after))
    return UCP_ALPHA;
  return UCP_PUNCT;
}


#define LH_COUNT_WORDS_NAME lh_count_words__enUK
#define LH_ITERATE_WORDS_NAME lh_iterate_words__enUK
#define LH_ITERATE_PATCHED_WORDS_NAME lh_iterate_patched_words__enUK
#define UNICHAR_GETPROPS_EXPN(buf,bufsize,pos) \
(('.' == buf[pos]) ? \
  (((pos > 0) && (pos+1 < bufsize)) ? unichar_getprops_point__enUK(buf+pos) : UCP_PUNCT) : \
  unichar_getprops (buf[pos]) )
#define DBG_PRINTF_NOISE_WORD(word_start,word_length) dbg_printf (("Noise word in en-UK text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of word failed in en-UK text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_NOISE_IDEO(word_start,word_length) dbg_printf (("Noise ideograph in en-UK text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_IDEO_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of ideograph failed in en-UK text, start %ld, length %ld\n", (long)word_start, (long)word_length))
#include "langfunc_templ.c"
#undef LH_COUNT_WORDS_NAME
#undef LH_ITERATE_WORDS_NAME
#undef LH_ITERATE_PATCHED_WORDS_NAME
#undef UNICHAR_GETPROPS_EXPN
#undef DBG_PRINTF_NOISE_WORD
#undef DBG_PRINTF_PATCH_FAILED
#undef DBG_PRINTF_NOISE_IDEO
#undef DBG_PRINTF_IDEO_PATCH_FAILED


static int unichar_getprops_point__xftqenUK(const unichar *ptr)
{
  unichar before, after;
  if ((ptr[-1] & ~0xFF) || ptr[+1] & ~0xFF)
    return UCP_PUNCT;
  before = ptr[-1];
  after = ptr[+1];
  if (('*' == before) && (('*' == after) || iswdigit(after) || iswalpha(after)))
    return UCP_ALPHA;
  if (iswdigit(before) && (('*' == after) || iswdigit(after)))
    return UCP_ALPHA;
  if (iswalpha(before) && (('*' == after) || iswalpha(after)))
    return UCP_ALPHA;
  return UCP_PUNCT;
}


#define LH_COUNT_WORDS_NAME lh_count_words__xftqenUK
#define LH_ITERATE_WORDS_NAME lh_iterate_words__xftqenUK
#define LH_ITERATE_PATCHED_WORDS_NAME lh_iterate_patched_words__xftqenUK
#define UNICHAR_GETPROPS_EXPN(buf,bufsize,pos) \
(('.' == buf[pos]) ? \
  (((pos > 0) && (pos+1 < bufsize)) ? unichar_getprops_point__xftqenUK(buf+pos) : UCP_PUNCT) : \
  (('*' == buf[pos]) ? UCP_ALPHA : unichar_getprops (buf[pos])) )
#define DBG_PRINTF_NOISE_WORD(word_start,word_length) dbg_printf (("Noise word in en-UK query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of word failed in en-UK query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_NOISE_IDEO(word_start,word_length) dbg_printf (("Noise ideograph in en-UK query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#define DBG_PRINTF_IDEO_PATCH_FAILED(word_start,word_length) dbg_printf (("Patch of ideograph failed in en-UK query, start %ld, length %ld\n", (long)word_start, (long)word_length))
#include "langfunc_templ.c"
#undef LH_COUNT_WORDS_NAME
#undef LH_ITERATE_WORDS_NAME
#undef LH_ITERATE_PATCHED_WORDS_NAME
#undef UNICHAR_GETPROPS_EXPN
#undef DBG_PRINTF_NOISE_WORD
#undef DBG_PRINTF_PATCH_FAILED
#undef DBG_PRINTF_NOISE_IDEO
#undef DBG_PRINTF_IDEO_PATCH_FAILED


lang_handler_t lh__enUK = {
  "en",			/* ISO 639 */
  "en-UK",		/* RFC 1766 */
  NULL,			/* more generic handler, will be set to handler for "x-any" before first use */
  &lh__xftqenUK,	/* query language handler */
  1, WORD_MAX_CHARS,	/* minimal and maximal lengths of one indexable word */
  NULL,			/* application-specific data */
  NULL,			/* lh_is_vtb_word */
  NULL,			/* lh_tocapital_word */
  NULL,			/* lh_toupper_word */
  NULL,			/* lh_tolower_word */
  NULL /*lh_normalize_word__enUK*/ ,
  lh_count_words__enUK,		/* lh_count_words */
  lh_iterate_words__enUK,		/* lh_iterate_words */
  lh_iterate_patched_words__enUK,	/* lh_iterate_patched_words */
#ifdef HYPHENATION_OK
  NULL			/* lh_iterate_hyppoints */
#endif
};


lang_handler_t lh__xftqenUK = {
  "x-ftq-en",		/* ISO 639 */
  "x-ftq-en-UK",	/* RFC 1766 */
  NULL,			/* more generic handler, will be set to handler for "x-ftq-x-any" before first use */
  &lh__xftqenUK,	/* query language handler */
  1, WORD_MAX_CHARS,	/* minimal and maximal lengths of one indexable word */
  NULL,			/* application-specific data */
  NULL,			/* lh_is_vtb_word */
  NULL,			/* lh_tocapital_word */
  NULL,			/* lh_toupper_word */
  NULL,			/* lh_tolower_word */
  NULL /*lh_normalize_word__enUK*/ ,
  lh_count_words__xftqenUK,		/* lh_count_words */
  lh_iterate_words__xftqenUK,		/* lh_iterate_words */
  lh_iterate_patched_words__xftqenUK,	/* lh_iterate_patched_words */
#ifdef HYPHENATION_OK
  NULL			/* lh_iterate_hyppoints */
#endif
};


void connect__enUK(void *appdata)
{
  lh__enUK.lh_superlanguage = lh_get_handler("x-any");
  lh__xftqenUK.lh_superlanguage = lh__enUK.lh_superlanguage->lh_ftq_language;
  lh_load_handler(&lh__enUK);
  lh_load_handler(&lh__xftqenUK);
}


unit_version_t plugin_version_lang__enUK = {
  "English language support",		/*!< Title of unit, filled by unit */
  "0.9",				/*!< Version number, filled by unit */
  "OpenLink Software",			/*!< Plugin's developer, filled by unit */
  "",					/*!< Any additional info, filled by unit */
  NULL,					/*!< Error message, filled by unit loader */
  NULL,					/*!< Name of file with unit's code, filled by unit loader */
  connect__enUK,			/*!< Pointer to connection function, cannot be NULL */
  NULL,					/*!< Pointer to disconnection function, or NULL */
  NULL,					/*!< Pointer to activation function, or NULL */
  NULL					/*!< Pointer to deactivation function, or NULL */
};
