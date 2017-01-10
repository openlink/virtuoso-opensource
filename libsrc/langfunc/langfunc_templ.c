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
/* Template started */

int LH_COUNT_WORDS_NAME (const unichar *buf, size_t bufsize, lh_word_check_t *check)
{
  int res = 0;
  size_t pos = 0;
  size_t word_start;
  size_t word_length;
  int prop;
  while (pos < bufsize)
    {
      prop = UNICHAR_GETPROPS_EXPN (buf, bufsize, pos);
      if (prop & UCP_ALPHA)
	{
	  word_start = pos;
	  do pos++; while ((pos < bufsize) && (UNICHAR_GETPROPS_EXPN (buf, bufsize, pos) & UCP_ALPHA));
	  word_length = pos - word_start;
	  if (WORD_MAX_CHARS < word_length)
	    continue;
	  if (NULL!=check && 0 == check(buf+word_start, word_length))
	    continue;
	    res++;
	  continue;
	}
      if (prop & UCP_IDEO)
	{
	  pos++;
	  if (NULL!=check && 0 == check(buf+pos-1, 1))
	    continue;
	  res++;
	  continue;
	}
      pos++;
    }
  return res;
}


void LH_ITERATE_WORDS_NAME(const unichar *buf, size_t bufsize, lh_word_check_t *check, lh_word_callback_t *callback, void *userdata)
{
  size_t pos = 0;
  size_t word_start;
  size_t word_length;
  utf8char word_buf[BUFSIZEOF__UTF8_WORD];
  utf8char *hugeword_buf = NULL;
  size_t hugeword_buf_size = 0;
  utf8char *word_end;
  int prop;
#ifdef LH_ITERATOR_DEBUG
  int wordctr = 0, wordcount = LH_COUNT_WORDS_NAME (buf, bufsize, check);
#define wordctr_INC1 wordctr++
#else
#define wordctr_INC1
#endif
  while (pos < bufsize)
    {
      prop = UNICHAR_GETPROPS_EXPN (buf, bufsize, pos);
      if (prop & UCP_ALPHA)
	{
	  word_start = pos;
	  do pos++; while ((pos < bufsize) && (UNICHAR_GETPROPS_EXPN (buf, bufsize, pos) & UCP_ALPHA));
	  word_length = pos - word_start;
	  if (WORD_MAX_CHARS < word_length)
	    continue;
	  if (NULL!=check && 0 == check(buf+word_start, word_length))
	    continue;
	  word_end = (utf8char *)eh_encode_buffer__UTF8 (buf+word_start, buf+pos, (char *)word_buf, (char *)(word_buf+BUFSIZEOF__UTF8_WORD));
	  if (NULL != word_end)
	    {
	      callback (word_buf, word_end-word_buf, userdata);
              wordctr_INC1;
	      continue;
	    }
	  if (hugeword_buf_size<(word_length*MAX_UTF8_CHAR))
	    {
	      if (hugeword_buf_size)
		dk_free (hugeword_buf, hugeword_buf_size);
	      hugeword_buf_size = word_length*MAX_UTF8_CHAR;
	      hugeword_buf = (utf8char *) dk_alloc (hugeword_buf_size);
	    }
	  word_end = (utf8char *)eh_encode_buffer__UTF8 (buf+word_start, buf+pos, (char *)hugeword_buf, (char *)(hugeword_buf+hugeword_buf_size));
	  callback (hugeword_buf, word_end-hugeword_buf, userdata);
          wordctr_INC1;
	  continue;
	}
      if (prop & UCP_IDEO)
	{
	  word_start = pos;
	  pos++;
	  if (NULL!=check && 0 == check(buf+pos-1, 1))
	    continue;
	  word_end = (utf8char *)eh_encode_buffer__UTF8 (buf+word_start, buf+pos, (char *)(word_buf), (char *)(word_buf+BUFSIZEOF__UTF8_WORD));
	  callback (word_buf, word_end-word_buf, userdata);
          wordctr_INC1;
	  continue;
	}
      pos++;
    }
  if (hugeword_buf_size)
    dk_free (hugeword_buf, hugeword_buf_size);
#ifdef LH_ITERATOR_DEBUG
  if (wordctr != wordcount)
    GPF_T;
#endif
}


void LH_ITERATE_PATCHED_WORDS_NAME(const unichar *buf, size_t bufsize, lh_word_check_t *check, lh_word_patch_t *patch, lh_word_callback_t *callback, void *userdata)
{
  size_t pos = 0;
  size_t word_start;
  size_t word_length;
  unichar patch_buf[WORD_MAX_CHARS];
  const unichar *arg_begin;
  size_t arg_length;
  utf8char word_buf[BUFSIZEOF__UTF8_WORD];
  utf8char *hugeword_buf = NULL;
  size_t hugeword_buf_size = 0;
  utf8char *word_end;
  int prop;
#ifdef LH_ITERATOR_DEBUG
  int wordctr = 0, wordcount = LH_COUNT_WORDS_NAME (buf, bufsize, check);
#define wordctr_INC1 wordctr++
#else
#define wordctr_INC1
#endif
  while (pos < bufsize)
    {
      prop = UNICHAR_GETPROPS_EXPN(buf,bufsize,pos);
      if (prop & UCP_ALPHA)
	{
	  word_start = pos;
	  do pos++; while ((pos < bufsize) && (UNICHAR_GETPROPS_EXPN(buf,bufsize,pos) & UCP_ALPHA));
	  word_length = pos - word_start;
	  if (WORD_MAX_CHARS < word_length)
	    continue;
	  if (NULL!=check && 0 == check(buf+word_start, word_length))
	    {
	      DBG_PRINTF_NOISE_WORD(word_start,word_length);
	      continue;
	    }
	  if (NULL != patch)
	    { /* word should be patched */
	      if (0 == patch (buf+word_start, word_length, patch_buf, &arg_length))
		{
		  DBG_PRINTF_PATCH_FAILED(word_start,word_length);
		  continue;
		}
	      arg_begin = patch_buf;
	    }
	  else
	    { /* argument should be taken right from \c buf */
	      arg_begin = buf+word_start;
	      arg_length = word_length;
	    }
	  word_end = (utf8char *)eh_encode_buffer__UTF8 (arg_begin, arg_begin+arg_length, (char *)(word_buf), (char *)(word_buf+BUFSIZEOF__UTF8_WORD));
	  if (NULL != word_end)
	    {
	      callback (word_buf, word_end-word_buf, userdata);
              wordctr_INC1;
	      continue;
	    }
	  if (hugeword_buf_size<(word_length*MAX_UTF8_CHAR))
	    { /* overflow danger detected */
	      if (hugeword_buf_size)
		dk_free (hugeword_buf, hugeword_buf_size);
	      hugeword_buf_size = word_length*MAX_UTF8_CHAR;
	      hugeword_buf = (utf8char *) dk_alloc (hugeword_buf_size);
	    }
	  word_end = (utf8char *)eh_encode_buffer__UTF8 (arg_begin, arg_begin+arg_length, (char *)(hugeword_buf), (char *)(hugeword_buf+hugeword_buf_size));
	  callback (hugeword_buf, word_end-hugeword_buf, userdata);
          wordctr_INC1;
	  continue;
	}
      if (prop & UCP_IDEO)
	{
	  word_start = pos;
	  pos++;
	  word_length = pos - word_start;
	  if (NULL!=check && 0 == check(buf+word_start, word_length))
	    {
	      DBG_PRINTF_NOISE_IDEO(word_start,word_length);
	      continue;
	    }
	  if (NULL != patch)
	    { /* word should be patched */
	      if (0 == patch (buf+word_start, word_length, patch_buf, &arg_length))
		{
		  DBG_PRINTF_IDEO_PATCH_FAILED(word_start,word_length);
		  continue;
		}
	      arg_begin = patch_buf;
	    }
	  else
	    { /* argument should be taken right from \c buf */
	      arg_begin = buf+word_start;
	      arg_length = word_length;
	    }
	  word_end = (utf8char *)eh_encode_buffer__UTF8 (arg_begin, arg_begin+arg_length, (char *)(word_buf), (char *)(word_buf+BUFSIZEOF__UTF8_WORD));
	  callback (word_buf, word_end-word_buf, userdata);
          wordctr_INC1;
	  continue;
	}
      pos++;
    }
  if (hugeword_buf_size)
    dk_free (hugeword_buf, hugeword_buf_size);
#ifdef LH_ITERATOR_DEBUG
  if (wordctr != wordcount)
    GPF_T;
#endif
}

