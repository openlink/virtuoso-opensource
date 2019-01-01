/*
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

#ifndef SELF_INCLUDE
#include "http.h"		/* for dks_esc_write and DKS_ESC_... */
#include "langfunc.h"
#include "multibyte.h"
#include "sqlbif.h"
#include "strlike.h"		/* for nc_strstr */
#include "srvmultibyte.h"
#include <math.h>
extern const wchar_t *strchr__wide (const wchar_t * str, int c);


#define SE_MAX_EXCERPT_HITS	10
#define SE_HIT_WORD_WEIGHT	100

/*!
\returns pointer to that point of haystack, where the first instance of needle is found.
Case and accents of \c haystack does not matter.
\c needle is supposed to consist only uppercase base letters and non-letters, but no lowercase or accents
 */
const wchar_t *
st_wstr_contains_unaccented_ucase_wstr (const wchar_t * haystack, const wchar_t * needle)
{
  int first_is_plain;
  wchar_t first, hstk_first = 0, ndl_first;
  const wchar_t *hstk, *ndl;
  first = *needle;
  if (!first)
    return haystack;
  first_is_plain = !IS_UNICHAR_ALPHA (first);
  if (first_is_plain)
    needle++;			/* we will optimize it with strchr_wide */
again:
  if (first_is_plain)
    {				/* It's some non-letter character (e.g. a digit), then we can search
				   it with strchr. If the first letter of needle is not found from haystack, then this surely fails: */
      haystack = strchr__wide (haystack, first);
      if (NULL == haystack)
	return NULL;
      haystack++;
    }
  hstk = haystack, ndl = needle;
  for (;;)
    {
      ndl_first = ndl[0];
      if (0 == ndl_first)
	break;
      hstk_first = hstk[0];
      if (!hstk_first)
	return NULL;
      hstk_first = unicode3_getupperbasechar (hstk_first);
      if (hstk_first != ndl_first)
	{
	  if (!first_is_plain)
	    haystack++;
	  goto again;		/* see above */
	}
      ndl++;
      hstk++;
    }
  return (first_is_plain ? haystack - 1 : haystack);
}


/*!
\returns pointer to that point of haystack, where the first instance of needle is found.
Case and accents of \c haystack does not matter.
\c needle is supposed to consist only uppercase base letters and non-letters, but no lowercase or accents.
If \c hit_end_ptr is not NULL and the function returns non-NULL then \c hit_end_ptr is filled with pointer to the past-the end char of the found occurence. */
const utf8char *
st_utf8_str_contains_unaccented_ucase_wstr (const utf8char * haystack, const wchar_t * needle, const utf8char ** hit_end_ptr)
{
  int first_is_plain;
  wchar_t first_wide, hstk_first = 0, ndl_first;
  utf8char first_utf8buf[MAX_UTF8_CHAR + 1];
  int first_utf8len;
  const wchar_t *ndl;
  const utf8char *hstk;
  first_wide = *needle;
  if (!first_wide)
    return haystack;
  first_is_plain = !IS_UNICHAR_ALPHA (first_wide);
  if (first_is_plain)
    {
      utf8char *res = (utf8char *) eh_encode_char__UTF8 (first_wide, (char *) first_utf8buf, (char *) first_utf8buf + MAX_UTF8_CHAR);
      if (res == first_utf8buf)
	return NULL;		/* can't search for invalid char */
      first_utf8len = (first_utf8buf - res);
      res[0] = '\0';
      needle++;
    }
again:
  if (first_is_plain)
    {				/* It's some non-letter character (e.g. a digit), then we can search
				   it with strchr or strstr. If the first letter of needle is not found from haystack, then this surely fails: */
      haystack = (utf8char *) ((1 == first_utf8len) ? strchr ((const char *) haystack, first_wide) : strstr ((const char *) haystack, (char *) first_utf8buf));
      if (NULL == haystack)
	return NULL;
      haystack += first_utf8len;
    }
  hstk = haystack, ndl = needle;
  for (;;)
    {
      ndl_first = ndl[0];
      if (0 == ndl_first)
	break;
      hstk_first = eh_decode_char__UTF8 ((__constcharptr *) (&hstk), (const char *) (hstk + MAX_UTF8_CHAR));
      if (!hstk_first)
	return NULL;
      hstk_first = unicode3_getupperbasechar (hstk_first);
      if (hstk_first != ndl_first)
	{
	  if (!first_is_plain)
	    do
	      {
		haystack++;
	      }
	    while (IS_UTF8_CHAR_CONT (haystack[0]));
	  goto again;		/* see above */
	}
      ndl++;
    }
  if (NULL != hit_end_ptr)
    hit_end_ptr[0] = hstk;
  return (first_is_plain ? haystack - 1 : haystack);
}

typedef wchar_t *widecaddr_t;
typedef const wchar_t *wideccaddr_t;

#define SE_CHARPTR_HAS_WORDTAILDELIM(ptr) \
 (('.' == (ptr)[0]) || (',' == (ptr)[0]) || (':' == (ptr)[0]) || (';' == (ptr)[0]))


#define WORD_POINTS	(caddr_t)1
#define WORD_POINT_1	(caddr_t)2

#define PUSH_POINT(set) \
  if ((set) && ((set)->data != WORD_POINT_1)) dk_set_push (&(set), WORD_POINT_1);

#define SE_MODE_HTML	0
#define SE_MODE_WIKI	1
#define SE_MODE_TEXT	2
#define SE_MODE_MAX	3

#define SE_NARROW	0
#define SE_UTF8		1
#define SE_WIDE		2

typedef struct se_hit_s
{
  ptrlong seh_idx;		/*!< index of hit word in word_hit */
  const char *seh_hit_begin;	/*!< pointer of hit word found in main doc */
  const char *seh_hit_end;	/*!< pointer past the end of hit word found in main doc */
} se_hit_t;

#define SE_HIT_TAG_LEN 80
typedef struct se_ctx_s
{
  union
  {
    const char *se_narrow_doc;
    const char *se_utf8_doc;
    const wchar_t *se_wide_doc;
  } se_doc_;
  caddr_t *se_hit_words;
  se_hit_t **se_hits;
  int se_hits_len;
  int se_total;
  int se_excerpt_max;
  int se_text_mode;
  int se_wide_mode;
  char se_hit_tag[SE_HIT_TAG_LEN];
  /* result */
  caddr_t **se_sentences;
  /* do not search hit words, just make an excerpt from begin */
  int se_from_begin;
} se_ctx_t;

caddr_t
se_new_hit (int idx, const void *begin, const void *end)
{
  se_hit_t *seh = (se_hit_t *) dk_alloc (sizeof (se_hit_t));
  seh->seh_idx = idx;
  seh->seh_hit_begin = begin;
  seh->seh_hit_end = end;
  return (caddr_t) seh;
}

/* creates ordered set from ordered sets of ptrlongs
 */
dk_set_t
se_merge_sets (dk_set_t s1, dk_set_t s2)
{
  dk_set_t res = 0;
  while (s1 && s2)
    {
      if (((se_hit_t *) (s1->data))->seh_hit_begin < ((se_hit_t *) (s2->data))->seh_hit_begin)
	{
	  dk_set_push (&res, s1->data);
	  s1 = s1->next;
	}
      else
	{
	  dk_set_push (&res, s2->data);
	  s2 = s2->next;
	}
    }
  while (s1)
    {
      dk_set_push (&res, s1->data);
      s1 = s1->next;
    }
  while (s2)
    {
      dk_set_push (&res, s2->data);
      s2 = s2->next;
    }
  return res;
}

#endif


#ifdef SELF_INCLUDE

#ifdef WIDE_EXCERPT
#define SE_char wchar_t
#define SE_caddr_t widecaddr_t
#define SE_ccaddr_t wideccaddr_t
#define SE_NAME(name) se_wide_##name
#define SE_box_dv_nchars box_dv_wide_nchars
#define SE_ISUTF8HALFCHAR(c) 0
#define SE_SKIP_CHAR(ptr) do { (ptr)++; } while(0)

#define SE_CHARPTR_HAS_HITCHAR(ptr, ptrptr) \
  (((ptr)[0] & ~0x7f) ? \
    unichar_getprops((ptr)[0]) & (UCP_ALPHA | UCP_IDEO) : \
    (isalpha((ptr)[0]) || isdigit((ptr)[0])) )

#define SE_CHARPTR_HAS_WORDCHAR(ptr, ptrptr) \
  (((ptr)[0] & ~0x7f) ? \
    unichar_getprops((ptr)[0]) & (UCP_ALPHA | UCP_IDEO) : \
    (isalpha((ptr)[0]) || isdigit((ptr)[0]) || SE_CHARPTR_HAS_WORDTAILDELIM(ptr)) )

#endif


#ifdef UTF8_EXCERPT
#define SE_char char
#define SE_caddr_t caddr_t
#define SE_ccaddr_t ccaddr_t
#define SE_NAME(name) se_utf8_##name
#define SE_box_dv_nchars box_dv_short_nchars
#define SE_ISUTF8HALFCHAR(c) ((c & 0xC0) == 0x80)
#define SE_SKIP_CHAR(ptr) do { (ptr)++; }  while (SE_ISUTF8HALFCHAR ((ptr)[0]))

#define SE_CHARPTR_HAS_HITCHAR(ptr, ptrptr) \
  (((ptr)[0] & 0x80) ? \
    (SE_ISUTF8HALFCHAR ((ptr)[0]) ? 0 : \
      unichar_getprops((ptrptr[0] = (ptr), eh_decode_char__UTF8 (ptrptr, (ptr)+MAX_UTF8_CHAR))) & (UCP_ALPHA | UCP_IDEO) ) : \
    (isalpha((ptr)[0]) || isdigit((ptr)[0])) )

#define SE_CHARPTR_HAS_WORDCHAR(ptr, ptrptr) \
  (((ptr)[0] & 0x80) ? \
    (SE_ISUTF8HALFCHAR ((ptr)[0]) ? 0 : \
      unichar_getprops((ptrptr[0] = (ptr), eh_decode_char__UTF8 (ptrptr, (ptr)+MAX_UTF8_CHAR))) & (UCP_ALPHA | UCP_IDEO) ) : \
    (isalpha((ptr)[0]) || isdigit((ptr)[0]) || SE_CHARPTR_HAS_WORDTAILDELIM(ptr)) )

#endif


#ifdef NARROW_EXCERPT
#define SE_char char
#define SE_caddr_t caddr_t
#define SE_ccaddr_t ccaddr_t
#define SE_NAME(name) se_narrow_##name
#define SE_box_dv_nchars box_dv_short_nchars
#define SE_ISUTF8HALFCHAR(c) 0
#define SE_SKIP_CHAR(ptr) do { (ptr)++; } while(0)

#define SE_CHARPTR_HAS_HITCHAR(ptr, ptrptr) \
  (((ptr)[0] & 0x80) ? \
    unichar_getprops((ptr)[0]) & (UCP_ALPHA | UCP_IDEO) : \
    (isalpha((ptr)[0]) || isdigit((ptr)[0])) )

#define SE_CHARPTR_HAS_WORDCHAR(ptr, ptrptr) \
  (((ptr)[0] & 0x80) ? \
    unichar_getprops((ptr)[0]) & (UCP_ALPHA | UCP_IDEO) : \
    (isalpha((ptr)[0]) || isdigit((ptr)[0]) || SE_CHARPTR_HAS_WORDTAILDELIM(ptr)) )

#endif



/* search_excerpt */

#define SE_HIT_BEGIN(seh) (const SE_char *)(((se_hit_t*) seh)->seh_hit_begin)
#define SE_HIT_END(seh) (const SE_char *)(((se_hit_t*) seh)->seh_hit_end)

int
SE_NAME (check_html_tag) (const SE_char ** wpoint);

caddr_t
SE_NAME (print) (se_ctx_t * se)
{
  caddr_t _result;
  dk_session_t *strses = strses_allocate ();
  int sent_inx, word_inx;
  int points = 0;
  DO_BOX (caddr_t, sentence, sent_inx, se->se_sentences)
  {
    if (sent_inx && BOX_ELEMENTS (sentence))
      SES_PRINT (strses, " ");
    DO_BOX (caddr_t, word, word_inx, sentence)
    {
      if (word == WORD_POINTS)
	points++;
      else
	points = 0;
      if (points == 2)
	{
	  points = 0;
	  continue;
	}
      if (word == WORD_POINTS)
	SES_PRINT (strses, "...");
      else if (word == WORD_POINT_1)
	SES_PRINT (strses, ".");
      else if (DV_TYPE_OF (word) != DV_ARRAY_OF_POINTER)
	{
#ifdef WIDE_EXCERPT
	  dks_esc_write (strses, (char *) (word), box_length (word) - sizeof (wchar_t), CHARSET_UTF8, CHARSET_WIDE,
	      se->se_text_mode ? DKS_ESC_NONE : DKS_ESC_PTEXT);
#else
	  session_buffered_write (strses, word, box_length (word) - 1);
#endif
	}
      else
	{
	  caddr_t *hit = (caddr_t *) word;
	  if (!se->se_text_mode)
	    {
	      session_buffered_write_char ('<', strses);
	      SES_PRINT (strses, se->se_hit_tag);
	      session_buffered_write_char ('>', strses);
	    }
#ifdef WIDE_EXCERPT
	  dks_esc_write (strses, (char *) (hit[1]), box_length (hit[1]) - sizeof (wchar_t), CHARSET_UTF8, CHARSET_WIDE,
	      se->se_text_mode ? DKS_ESC_NONE : DKS_ESC_PTEXT);
#else
	  session_buffered_write (strses, hit[1], box_length (hit[1]) - 1);
#endif
	  if (!se->se_text_mode)
	    {
	      SES_PRINT (strses, "</");
	      SES_PRINT (strses, se->se_hit_tag);
	      session_buffered_write_char ('>', strses);
	    }
	  if (NULL != hit[2])
	    {
	      session_buffered_write_char ((ptrlong) (hit[2]), strses);
	    }
	}
      if (word_inx + 2 < BOX_ELEMENTS (sentence))	/* word before . or ... */
	SES_PRINT (strses, " ");
    }
    END_DO_BOX;
  }
  END_DO_BOX;
  _result = strses_string (strses);
#ifndef NARROW_EXCERPT
  box_flags (_result) = BF_UTF8;
#endif
  strses_free (strses);
  return _result;
}

void
SE_NAME (push_hit_word) (dk_set_t * set, const SE_char * start, const SE_char * end)
{
  caddr_t *hwrd = (caddr_t *) dk_alloc_box (3 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  hwrd[0] = box_num (1);
  if (SE_CHARPTR_HAS_WORDTAILDELIM (end - 1))
    {
      while ((end > (start + 1)) && SE_CHARPTR_HAS_WORDTAILDELIM (end - 1))
	end--;
      hwrd[1] = SE_box_dv_nchars (start, end - start);
      hwrd[2] = (caddr_t) ((ptrlong) ((unsigned) (end[0])));
      dk_set_push (set, hwrd);
    }
  else if (end > start)
    {
      hwrd[1] = SE_box_dv_nchars (start, end - start);
      hwrd[2] = NULL;
      dk_set_push (set, hwrd);
    }
}

/* returns offset to begin of tag */
int
SE_NAME (get_html_tag_offset) (SE_ccaddr_t doc, const SE_char * pointer, int max_offset)
{
  const SE_char *start = pointer;
  while (--start > doc)
    {
      if (pointer - start > max_offset)
	return max_offset + 1;
      if (start[0] == '<')
	{
	  const SE_char *tag_end = start;
	  if (SE_NAME (check_html_tag) (&tag_end) && (tag_end == (pointer + 1)))
	    return (pointer - start);
	}
    }
  return 0;
}

/* return 1 if html tag detected,
   points wpoint to the end of tag
*/
int
SE_NAME (check_html_tag) (const SE_char ** wpoint)
{
  const SE_char *p = wpoint[0];
  if (p[0] == '<')
    {
      p++;
      if ((p[0] == '/') && isalpha (p[1]))
	{			/* close tag */
	  p++;
	  while (p[0] && (p[0] != '>'))
	    p++;
	  if (p[0])
	    {
	      wpoint[0] = p + 1;
	      return 1;
	    }
	}
      else if (isalpha (p[0]))
	{			/* open tag, empty tag */
	  while (p[0] && (p[0] != '>'))
	    p++;
	  if (p[0])
	    {
	      wpoint[0] = p + 1;
	      return 1;
	    }
	}
      else if (p[0] == '!' && p[1] == '-' && p[2] == '-')	/* comments */
	{
	  p += 2;
	  while (p[0] && p[1] && p[2])
	    {
	      if (p[0] == '-' && p[1] == '-' && p[2] == '>')
		{
		  wpoint[0] = p + 3;
		  return 1;
		}
	      p++;
	    }
	}
    }
  else if (p[0] == '&')
    {
      p++;
      while (isalpha (p[0]))
	++p;
      if (p[0] == ';')
	{
	  wpoint[0] = ++p;
	  return 1;
	}
    }
  return 0;
}

/* return either begin of the sentence or pointer after left_border */
SE_ccaddr_t
SE_NAME (ctx_to_begin) (SE_ccaddr_t doc, const SE_char * left_border, const SE_char * start_from, int max_offset, int text_mode,
    int *hit_left_border)
{
  const SE_char *pointer = start_from;
  while ((max_offset-- >= 0) && (pointer > left_border))
    {
      if (pointer[0] == '.')
	return pointer + 1;
      else if (!text_mode && (pointer[0] == '>'))	/* possible tag */
	{
	  int back_offset = SE_NAME (get_html_tag_offset) (doc, pointer, max_offset);
	  if (back_offset > max_offset)
	    return pointer + 1;
	  else if (back_offset)
	    {
	      max_offset -= back_offset;
	      pointer -= back_offset + 1;
	      continue;
	    }
	}
      pointer--;
    }
  if (left_border == pointer)
    {
      if (hit_left_border)
	hit_left_border[0] = 1;
      if (doc == left_border)
	return pointer;
    }
  SE_SKIP_CHAR (pointer);
  return pointer;
}

void
SE_NAME (ctx_tokenize_doc) (se_ctx_t * se)
{
  caddr_t *curr_sentence;
  dk_set_t curr_sentence_set = 0;
  dk_set_t sentences_set = 0;
  const SE_char *wstart, *wpoint;
  int hidx = 0;
  int sentence_hit_weight = 0;
  int total_counter = 0, prev_total_counter = 0;
  int excerpt_counter = 0;
  int all_complete = 0;
  int point_at_the_end = 0;
  int sentences_count = 0;
#ifdef UTF8_EXCERPT
  __constcharptr ptrptr[1];
#endif
  if (!se->se_from_begin)
    wpoint = SE_NAME (ctx_to_begin) (se->se_doc_.SE_NAME (doc), se->se_doc_.SE_NAME (doc), SE_HIT_BEGIN (se->se_hits[0]),
	se->se_excerpt_max / 2, se->se_text_mode, 0);
  else
    wpoint = SE_NAME (ctx_to_begin) (se->se_doc_.SE_NAME (doc), se->se_doc_.SE_NAME (doc), se->se_doc_.SE_NAME (doc),
	se->se_excerpt_max / 2, se->se_text_mode, 0);
  wstart = wpoint;
  /* search sentence */
again:
  while (wpoint[0] && wpoint[0] != '.')
    {
#ifndef NDEBUG
      if (SE_ISUTF8HALFCHAR (wpoint[0]))
	GPF_T;
#endif
      if (!sentences_count)
	{
	  if (wpoint != se->se_doc_.SE_NAME (doc))
	    dk_set_push (&curr_sentence_set, WORD_POINTS);
	  ++sentences_count;
	}
      if (SE_CHARPTR_HAS_WORDCHAR (wpoint, ptrptr))
	{
	  SE_SKIP_CHAR (wpoint);
	  continue;
	}
      if (total_counter + wpoint - wstart >= se->se_total)
	{
	  all_complete = 1;
	  goto excerpt_end;
	}
      if (excerpt_counter + wpoint - wstart >= se->se_excerpt_max)
	{
	  wstart = wpoint;
	  goto excerpt_end;
	}
      if (!se->se_from_begin)
	{
	  int curr_sentence_set_is_ok = 0;
	  for (;;)
	    {
	      se_hit_t *seh;
	      caddr_t seh_word;
	      int seh_word_len;
	      if (hidx >= se->se_hits_len)
		break;
	      seh = se->se_hits[hidx];
	      if (SE_HIT_BEGIN (seh) < wstart)
		{
		  hidx++;
		  continue;
		}
	      if (SE_HIT_BEGIN (seh) > wstart)
		break;
	      seh_word = se->se_hit_words[seh->seh_idx];
	      seh_word_len = SE_HIT_END (seh) - SE_HIT_BEGIN (seh);
	      if (((wpoint - wstart) == seh_word_len) || !SE_CHARPTR_HAS_HITCHAR (wstart + seh_word_len, ptrptr))
		{
		  SE_NAME (push_hit_word) (&curr_sentence_set, wstart, wpoint);
		  sentence_hit_weight += SE_HIT_WORD_WEIGHT;
		}
	      hidx++;
	      curr_sentence_set_is_ok = 1;
	      break;
	    }
	  if ((wpoint - wstart) && !curr_sentence_set_is_ok)
	    {
	      dk_set_push (&curr_sentence_set, SE_box_dv_nchars (wstart, wpoint - wstart));
	    }
	}
      else if (wpoint - wstart)
	dk_set_push (&curr_sentence_set, SE_box_dv_nchars (wstart, wpoint - wstart));
      total_counter += wpoint - wstart;
      excerpt_counter += wpoint - wstart;
      if (!se->se_text_mode && SE_NAME (check_html_tag) (&wpoint))
	wstart = wpoint;
      while (wpoint[0] && !SE_CHARPTR_HAS_WORDCHAR (wpoint, ptrptr))
	{
	  if (!se->se_text_mode && SE_NAME (check_html_tag) (&wpoint))
	    wstart = wpoint;
	  else
	    {
	      if (wpoint[0])
		{
		  SE_SKIP_CHAR (wpoint);
		}
	      wstart = wpoint;
	    }
	}
    }
  if ((wstart + 1) != wpoint)	/* "{ws}." */
    {
      int curr_sentence_set_is_ok = 0;
      if (total_counter + wpoint - wstart >= se->se_total)
	{
	  all_complete = 1;
	  goto excerpt_end;
	}
      if (excerpt_counter + wpoint - wstart >= se->se_excerpt_max)
	{
	  wstart = wpoint;
	  goto excerpt_end;
	}
      for (;;)
	{
	  se_hit_t *seh;
	  caddr_t seh_word;
	  int seh_word_len;
	  if (se->se_from_begin)
	    break;
	  if (hidx >= se->se_hits_len)
	    break;
	  seh = se->se_hits[hidx];
	  if (SE_HIT_BEGIN (seh) != wstart)
	    break;
	  seh_word = se->se_hit_words[seh->seh_idx];
	  seh_word_len = SE_HIT_END (seh) - SE_HIT_BEGIN (seh);
	  if (((wpoint - wstart) == seh_word_len) || !SE_CHARPTR_HAS_HITCHAR (wstart + seh_word_len, ptrptr))
	    {
	      SE_NAME (push_hit_word) (&curr_sentence_set, wstart, wpoint);
	      sentence_hit_weight += SE_HIT_WORD_WEIGHT;
	    }
	  hidx++;
	  curr_sentence_set_is_ok = 1;
	  break;
	}
      if ((wpoint - wstart) && !curr_sentence_set_is_ok)
	{
	  dk_set_push (&curr_sentence_set, SE_box_dv_nchars (wstart, wpoint - wstart));
	  wstart = wpoint;
	}
      PUSH_POINT (curr_sentence_set);
      point_at_the_end = 1;
    }
excerpt_end:
  if (!point_at_the_end)
    dk_set_push (&curr_sentence_set, WORD_POINTS);
  if (wstart[0] == '.')
    wstart++;
  if (wpoint[0] == '.')
    wpoint++;
  if (se->se_from_begin || sentence_hit_weight)
    {
      /* dk_set_append_1 (&curr_sentence_set, box_num (sentence_hit_weight)); */
      if (dk_set_length (curr_sentence_set) > 0)
	{
	  curr_sentence = (caddr_t *) list_to_array (dk_set_nreverse (curr_sentence_set));
	  dk_set_push (&sentences_set, curr_sentence);
	}
      ++sentences_count;
    }
  else
    {
      DO_SET (caddr_t, el, &curr_sentence_set)
      {
	dk_free_box (el);
      }
      END_DO_SET ();
      all_complete = 0;
      total_counter = prev_total_counter;
      dk_set_free (curr_sentence_set);
      --sentences_count;
    }
  curr_sentence_set = 0;
  if (!se->se_from_begin)
    {
      if (!all_complete)
	{
	  while ((hidx < se->se_hits_len) && (SE_HIT_BEGIN (se->se_hits[hidx]) < wpoint))
	    hidx++;
	  if (hidx < se->se_hits_len)
	    {
	      int hit_left_border = 0;
	      if (!point_at_the_end && !hit_left_border)
		dk_set_push (&curr_sentence_set, WORD_POINTS);
	      wstart = wpoint = SE_NAME (ctx_to_begin) (se->se_doc_.SE_NAME (doc), wpoint, SE_HIT_BEGIN (se->se_hits[hidx]), se->se_excerpt_max / 2, se->se_text_mode, &hit_left_border);
	      if (!hit_left_border || (se->se_doc_.SE_NAME (doc) != wpoint))
		{
		  sentence_hit_weight = 0;
		  excerpt_counter = 0;
		  point_at_the_end = 0;
		  prev_total_counter = total_counter;
		  goto again;
		}
	    }
	}
    }
  else if (wpoint[0])
    {
      sentence_hit_weight = 0;
      excerpt_counter = 0;
      prev_total_counter = total_counter;
      SE_SKIP_CHAR (wpoint);
      goto again;
    }
  se->se_sentences = (caddr_t **) list_to_array (dk_set_nreverse (sentences_set));
}

int
SE_NAME (ctx_search_cluster) (se_hit_t ** hit_index, int hit_index_sz, int cluster_sz)
{
  int idx;
  for (idx = 1; idx < hit_index_sz; idx++)
    if ((SE_HIT_BEGIN (hit_index[idx]) - SE_HIT_BEGIN (hit_index[idx - 1])) < cluster_sz)
      return idx - 1;
  return 0;
}

#undef SE_char
#undef SE_caddr_t
#undef SE_ccaddr_t
#undef SE_NAME
#undef SE_box_dv_nchars
#undef SE_ISUTF8HALFCHAR
#undef SE_SKIP_CHAR
#undef SE_CHARPTR_HAS_HITCHAR
#undef SE_CHARPTR_HAS_WORDCHAR

#endif

#ifndef SELF_INCLUDE

#define SELF_INCLUDE
#define WIDE_EXCERPT
#include "bif_search_excerpt.c"
#undef WIDE_EXCERPT
#define UTF8_EXCERPT
#include "bif_search_excerpt.c"
#undef UTF8_EXCERPT
#define NARROW_EXCERPT
#include "bif_search_excerpt.c"
#undef NARROW_EXCERPT
#undef SELF_INCLUDE


caddr_t
se_tokenize_and_print (se_ctx_t * se)
{
  caddr_t res;
  switch (se->se_wide_mode)
    {
    case SE_NARROW:
      se_narrow_ctx_tokenize_doc (se);
      res = se_narrow_print (se);
      break;
    case SE_UTF8:
      se_utf8_ctx_tokenize_doc (se);
      res = se_utf8_print (se);
      break;
    case SE_WIDE:
      se_wide_ctx_tokenize_doc (se);
      res = se_wide_print (se);
      break;
    }
  dk_free_tree ((box_t) (se->se_sentences));
  return res;
}


caddr_t
bif_search_excerpt (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t *orig_word_hits = bif_strict_2type_array_arg (DV_STRING, DV_WIDE, qst, args, 0, "search_excerpt");
  caddr_t *normalized_word_hits = NULL;
  caddr_t text = NULL, text_with_offset = NULL, original_text = bif_arg (qst, args, 1, "search_excerpt");
  ptrlong within_first = 200000;
  ptrlong max_excerpt = 90;
  ptrlong total = 200;
  caddr_t html_hit_tag;
  caddr_t _result = NULL;
  int wide_mode, word_hits_count;
  long mode = SE_MODE_HTML;
  se_hit_t **hit_index;
  int hit_inx = 0;
  int inx, inx2;
  dk_set_t hit_sets[SE_MAX_EXCERPT_HITS];
  dk_set_t hit_res_set = 0;

  if (DV_RDF == DV_TYPE_OF (original_text))
    original_text = ((rdf_box_t *) original_text)->rb_box;
  if (DV_WIDESTRINGP (original_text))
    wide_mode = SE_WIDE;
  else if (DV_STRINGP (original_text))
    wide_mode = (((BF_UTF8 | BF_IRI) & box_flags (original_text)) ? SE_UTF8 : SE_NARROW);
  else
    return NEW_DB_NULL;		/* if not a string, can happen in weird join orders with any columns */
  memset (hit_sets, 0, sizeof (hit_sets));
  word_hits_count = BOX_ELEMENTS (orig_word_hits);
  if (word_hits_count > SE_MAX_EXCERPT_HITS)
    sqlr_new_error ("XXXXX", "SRXXX", "search_excerpt does not support more than %d hits", SE_MAX_EXCERPT_HITS);

  if (BOX_ELEMENTS (args) > 2)
    within_first = bif_long_range_arg (qst, args, 2, "search_excerpt", 0, MAX_BOX_LENGTH);
  if (BOX_ELEMENTS (args) > 3)
    max_excerpt = bif_long_range_arg (qst, args, 3, "search_excerpt", 0, MAX_BOX_LENGTH);
  if (BOX_ELEMENTS (args) > 4)
    total = bif_long_arg (qst, args, 4, "search_excerpt");
  if (BOX_ELEMENTS (args) > 5)
    html_hit_tag = bif_string_or_null_arg (qst, args, 5, "search_excerpt");
  else
    html_hit_tag = "b";
  if (BOX_ELEMENTS (args) > 6)
    mode = bif_long_arg (qst, args, 6, "search_excerpt");
  if ((mode < 0) && (mode >= SE_MODE_MAX))
    mode = SE_MODE_HTML;
  DO_BOX_FAST (caddr_t, hit, inx, orig_word_hits)
  {
    if (!box_length (hit) || !hit[0])
      sqlr_new_error ("XXXXX", "SRXXX", "hit words must be non-zero length");
  }
  END_DO_BOX_FAST;
  normalized_word_hits = (caddr_t *) box_copy /* not _tree */ ((caddr_t) orig_word_hits);
  DO_BOX_FAST (caddr_t, hit, inx, normalized_word_hits)
  {
    caddr_t tmp_wide_hit;
    wchar_t *tail;
    if (DV_STRINGP (hit))
      {
	if ((BF_UTF8 | BF_IRI) & box_flags (hit))
	  tmp_wide_hit = box_utf8_as_wide_char (hit, NULL, box_length (hit) - 1, 0);
	else
	  tmp_wide_hit = box_narrow_string_as_wide ((unsigned char *) hit, NULL, 0, qst ? QST_CHARSET (qst) : NULL, NULL /* no err */ , 1);
	if (NULL == tmp_wide_hit)
	  goto fin;		/* see below */
      }
    else
      tmp_wide_hit = box_copy (hit);
    for (tail = (wchar_t *) (tmp_wide_hit + box_length (tmp_wide_hit) - sizeof (wchar_t)); tail >= (wchar_t *) tmp_wide_hit; tail--)
      {
	if ((int) (tail[0]) & ~0x7f)
	  tail[0] = unicode3_getupperbasechar (tail[0]);
	else
	  tail[0] = toupper (tail[0]);
      }
    switch (wide_mode)
      {
      case SE_WIDE:
      case SE_UTF8:
	normalized_word_hits[inx] = tmp_wide_hit;
	break;
#if 0
      case SE_UTF8:
	normalized_word_hits[inx] = box_wide_as_utf8_char (tmp_wide_hit, box_length (tmp_wide_hit) / sizeof (wchar_t) - 1, DV_STRING);
	dk_free_box (tmp_wide_hit);
	break;
#endif
      case SE_NARROW:
	normalized_word_hits[inx] = box_wide_string_as_narrow (tmp_wide_hit, NULL, box_length (tmp_wide_hit) / sizeof (wchar_t) - 1,
	    qst ? QST_CHARSET (qst) : NULL);
	dk_free_box (tmp_wide_hit);
	break;
      }
  }
  END_DO_BOX_FAST;
  for (inx = word_hits_count; inx--; /* no step */ )
    {
      for (inx2 = inx; inx2--; /* no step */ )
	{
	  caddr_t swap;
	  if (box_length (normalized_word_hits[inx2]) <= box_length (normalized_word_hits[inx]))
	    continue;
	  swap = normalized_word_hits[inx2];
	  normalized_word_hits[inx2] = normalized_word_hits[inx];
	  normalized_word_hits[inx] = swap;
	}
    }
  if (SE_WIDE == wide_mode)
    {
      if (((box_length (original_text) / sizeof (wchar_t)) - 1) > within_first)
	text = box_dv_wide_nchars ((wchar_t *) original_text, within_first);
      else
	text = original_text;
    }
  else if (box_length (original_text) > within_first)
    text = box_dv_short_nchars (original_text, within_first);
  else
    text = original_text;

  if (html_hit_tag && (mode == SE_MODE_HTML))
    {
      if (SE_WIDE == wide_mode)
	text_with_offset = (caddr_t) nc_strstr__wide ((wchar_t *) text, L"<body");
      else
	text_with_offset = (caddr_t) nc_strstr ((unsigned char *) text, (unsigned char *) "<body");
    }
  if (!text_with_offset)
    text_with_offset = text;

  DO_BOX (caddr_t, hit, inx, normalized_word_hits)
  {
    const char *hit_pointer = text_with_offset;
    for (;;)
      {
	const char *hit_end;
	switch (wide_mode)
	  {
	  case SE_NARROW:
	    hit_pointer = (char *) nc_strstr ((unsigned char *) hit_pointer, (unsigned char *) hit);
	    if (hit_pointer)
	      hit_end = (hit_pointer + box_length (hit) - 1);
	    break;
	  case SE_UTF8:
	    hit_pointer = (const char *) st_utf8_str_contains_unaccented_ucase_wstr ((const utf8char *) hit_pointer, (const wchar_t *) hit,
		(const utf8char **) (&hit_end));
	    break;
	  case SE_WIDE:
	    hit_pointer = (const char *) st_wstr_contains_unaccented_ucase_wstr ((wchar_t *) hit_pointer, (wchar_t *) hit);
	    if (hit_pointer)
	      hit_end = (hit_pointer + box_length (hit) - sizeof (wchar_t));
	    break;
	  }
	if (NULL == hit_pointer)
	  break;
	dk_set_push (&hit_sets[inx], se_new_hit (inx, hit_pointer, hit_end));
	hit_pointer = hit_end;
	hit_inx++;
      }
    hit_sets[inx] = dk_set_nreverse (hit_sets[inx]);
  }
  END_DO_BOX;
  if (!hit_inx)
    goto fin;
  hit_res_set = hit_sets[0];
  for (inx = 1; inx < BOX_ELEMENTS (normalized_word_hits); inx++)
    {
      dk_set_t _prev = hit_res_set;
      hit_res_set = dk_set_nreverse (se_merge_sets (_prev, hit_sets[inx]));
      if (_prev != hit_sets[0])
	dk_set_free (_prev);
    }
  hit_index = (se_hit_t **) dk_set_to_array (hit_res_set);
  if (hit_res_set != hit_sets[0])
    dk_set_free (hit_res_set);
  for (inx = 0; inx < BOX_ELEMENTS (normalized_word_hits); inx++)
    dk_set_free (hit_sets[inx]);

  {				/* check consistency */
    ccaddr_t prev_el_hit = 0;
    DO_BOX (se_hit_t *, el, inx, hit_index)
    {
      /*        printf ("%s %x\n", el, el);
         fflush (stdout); */
      if (prev_el_hit > el->seh_hit_begin)
	GPF_T;
      prev_el_hit = el->seh_hit_begin;
    }
    END_DO_BOX;
  }
  {
    se_ctx_t se;
    int hit_index_cluster_ofs;
    switch (wide_mode)
      {
      case SE_NARROW:
	hit_index_cluster_ofs = se_narrow_ctx_search_cluster (hit_index, BOX_ELEMENTS (hit_index), max_excerpt / 2);
	break;
      case SE_UTF8:
	hit_index_cluster_ofs = se_utf8_ctx_search_cluster (hit_index, BOX_ELEMENTS (hit_index), max_excerpt / 2);
	break;
      case SE_WIDE:
	hit_index_cluster_ofs = se_wide_ctx_search_cluster (hit_index, BOX_ELEMENTS (hit_index), max_excerpt / 2);
	break;
      }
    memset (&se, 0, sizeof (se_ctx_t));
    se.se_doc_.se_narrow_doc = text_with_offset;
    se.se_hit_words = normalized_word_hits;
    se.se_hits = hit_index + hit_index_cluster_ofs;
    se.se_hits_len = BOX_ELEMENTS (hit_index) - hit_index_cluster_ofs;
    se.se_total = total;
    se.se_excerpt_max = max_excerpt;
    se.se_text_mode = (!html_hit_tag);
    se.se_wide_mode = wide_mode;
    if (html_hit_tag)
      strncpy (se.se_hit_tag, html_hit_tag, SE_HIT_TAG_LEN - 1);
    else
      strcpy (se.se_hit_tag, "b");
    _result = se_tokenize_and_print (&se);
  }

  DO_BOX (caddr_t, seh, inx, hit_index)
  {
    dk_free (seh, sizeof (se_hit_t));
  }
  END_DO_BOX;
  dk_free_box ((caddr_t) hit_index);

fin:
  if (!_result)
    {
      se_ctx_t se;
      memset (&se, 0, sizeof (se_ctx_t));
      se.se_doc_.se_narrow_doc = text_with_offset;
      se.se_total = total;
      se.se_excerpt_max = max_excerpt;
      se.se_text_mode = (!html_hit_tag);
      se.se_wide_mode = wide_mode;
      if (html_hit_tag)
	strncpy (se.se_hit_tag, html_hit_tag, SE_HIT_TAG_LEN - 1);
      else
	strcpy (se.se_hit_tag, "b");
      se.se_from_begin = 1;
      _result = se_tokenize_and_print (&se);
    }
  if (text != original_text)
    dk_free_box (text);
  dk_free_tree ((caddr_t) normalized_word_hits);
  return _result;
}

int enable_fct_level_vec = 1;

void
bif_fct_level_vec (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, state_slot_t * ret)
{
  data_col_t *ret_dc, *str_dc;
  QNCAST (QI, qi, qst);
  int set;
  int nth = bif_long_arg (qst, args, 1, "fct_level");
  int lev_only = 0, prev_lev = 0;
  if (nth < 0)
    {
      lev_only = 1;
      nth = -nth;
    }
  if (SSL_CONSTANT != args[1]->ssl_type || SSL_VEC != args[0]->ssl_type || !ret || qi->qi_set_mask || !enable_fct_level_vec)
    goto no;
  ret_dc = QST_BOX (data_col_t *, qst, ret->ssl_index);
  str_dc = QST_BOX (data_col_t *, qst, args[0]->ssl_index);
  if (DV_ANY != str_dc->dc_dtp || DV_ANY != ret_dc->dc_dtp)
    goto no;
  dc_reset (ret_dc);
  for (set = 0; set < str_dc->dc_n_values; set++)
    {
      dtp_t head[5];
      int head_len;
      int lev = 0, inx = 0;
      db_buf_t str = ((db_buf_t *) str_dc->dc_values)[set];
      int len;
      if (DV_SHORT_STRING_SERIAL == str[0])
	{
	  len = str[1];
	  str += 2;
	}
      else if (DV_STRING == str[0])
	{
	  len = LONG_REF_NA (str + 1);
	  str += 5;
	}
      else
	sqlr_new_error ("42000", "FCTLV", "fct_level needs a string as first argument");
      for (inx = 0; inx < len; inx++)
	{
	  char ch = str[inx];
	  if ('/' == ch)
	    {
	      lev++;
	      if (lev >= nth)
		break;
	      prev_lev = inx;
	    }
	}
      if (lev_only)
	{
	  prev_lev++;
	  str += prev_lev;
	  inx -= prev_lev;
	}
      if (inx < 256)
	{
	  head[0] = DV_SHORT_STRING_SERIAL;
	  head[1] = inx;
	  head_len = 2;
	}
      else
	{
	  head[0] = DV_STRING;
	  LONG_SET_NA (&head[1], inx);
	  head_len = 5;
	}
      dc_append_bytes (ret_dc, str, inx, head, head_len);
    }

  return;
no:
  *err_ret = BIF_NOT_VECTORED;
}

caddr_t
bif_fct_level (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "fct_level");
  caddr_t ret;
  int nth = bif_long_arg (qst, args, 1, "fct_level");
  int lev = 0, inx = 0;
  int len = box_length (str) - 1;
  int lev_only = 0, prev_lev = 0;
  if (nth < 0)
    {
      lev_only = 1;
      nth = -nth;
    }
  for (inx = 0; inx < len; inx++)
    {
      char ch = str[inx];
      if ('/' == ch)
	{
	  lev++;
	  if (lev >= nth)
	    break;
	  prev_lev = inx;
	}
    }
  if (lev_only)
    {
      prev_lev++;
      str += prev_lev;
      inx -= prev_lev;
    }
  ret = dk_alloc_box (inx + 1, DV_STRING);
  memcpy_16 (ret, str, inx);
  ret[inx] = 0;
  return ret;
}



float
rnk_scale (caddr_t box)
{
  dtp_t dtp = DV_TYPE_OF (box);
  int i;
  float ret;
  if (DV_DB_NULL == dtp)
    i = 0;
  else
    i = unbox_inline (box);

  ret = exp (i - 0x3FFFFFFF) / (float) 0x3FFFFFF;

  if (ret < 1)
    {
      return (2 * atan (ret * 5));
    }

  if (ret > 1 && ret < 10)
    {
      return 3 + ((atan (ret - 1) * 4) / 3.14e0);
    }
  else
    {
      return 7 + (atan ((ret - 10) / 50) * 2);
    }
}



caddr_t
bif_sum_rank (caddr_t *qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * arr = (caddr_t*)bif_arg (qst, args, 0, "sum_rank");
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (arr) || BOX_ELEMENTS (arr) < 3)
    return NULL;
  return box_double (rnk_scale (arr[0]) + (float) ((float)unbox (arr[2]) / ((unbox (arr[1]) / 3))));
  /* return  rnk_scale_v (arr[0]) + cast (arr[2] as real) / (arr[1] / 3); */
}


#endif
