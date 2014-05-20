/*
 *  $Id$
 *
 *  Bifs for text index
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

#include "libutil.h"
#include "sqlfn.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "bif_text.h"
#include "text.h"
#include "xml.h"
#include "bif_xper.h"
#include "srvmultibyte.h"
#include "security.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "langfunc.h"
#ifdef __cplusplus
}
#endif
#include "arith.h"

#define VT_BATCH_SIZE_MIN	31
#define VT_BATCH_SIZE_MAX	500000
#define VT_BATCH_SIZE_DEFAULT	1001

lang_handler_t *server_default_lh = &lh__xany;
char *server_default_language_name = NULL;


/* The last error number used is FT038 */

#if 0
char *
asciiword_start_0 (char *str)
{
  char c;
  while ((c = *str))
    {
      if (IS_ASCIIWORD_CHAR_0 (c))
	return str;
      str++;
    }
  return 0;
}


char *
asciiword_last_0 (char *str)
{
  char c;
  while ((c = *str))
    {
      if (!IS_ASCIIWORD_CHAR_0 (c))
	return str - 1;
      str++;
    }
  return str - 1;
}


char *
asciiword_start (char *str, char * extra)
{
  char c;
  while ((c = *str))
    {
      if (IS_ASCIIWORD_CHAR (c, extra))
	return str;
      str++;
    }
  return 0;
}


char *
asciiword_last (char *str, char * extra)
{
  char c;
  while ((c = *str))
    {
      if (!IS_ASCIIWORD_CHAR (c, extra))
	return str - 1;
      str++;
    }
  return str - 1;
}


void
asciistr_upc_copy (char *to, const char *from, int len)
{
  int inx;
  for (inx = 0; inx < len; inx++)
    {
      unsigned char fc = (((unsigned char *) from)[inx]);
      if ((fc >= 'a' && fc <= 'z') || (fc >= 224))
	fc -= 32;
/* Not needed anymore, because (fc >= 224) applies to all ISO 8059/x
   lowercase letters, whether Western Latin-1, Baltic, Turkish, Greek,
   Cyrillic. Only certain special letters like Polish crossed L and l
   are outside of 192-256 range.
   else if (fc == '�' ) fc = '�' ; // o umlaut
   else if (fc == '�' ) fc ='�' ; // a umlaut
   else if (fc == '�') fc = '�'; // swedish o - educated guess
 */
	(((unsigned char *) to)[inx]) = fc;
    }
  to[len] = 0;
}

#endif



typedef struct _invdentstruct
{
  caddr_t in_word;
  caddr_t in_phi;
  long		 *in_pos;
} inv_doc_entry_t;


typedef struct word_hash_s
  {
    long wh_count;
    dk_set_t wh_pos;
    long *wh_pos_array;
  } w_hash_entry_t;


#if 0
dk_set_t
vt_string_words  ( char *string, char * extra)
{
  dk_set_t words = NULL;
  char temp[WORD_MAX_CHARS];
  char *temp_ptr = (char *) &temp;
  char *point = string;
  char *w_start = point, *w_end;
  for (;;)
    {
      w_start = asciiword_start (point, extra);
      if (!w_start)
	break;
      w_end = asciiword_last (w_start, extra);
      if ((long) w_end - (long) w_start >= 1)
	{
	  str_asciiupc_copy (temp, w_start,
	      MIN (sizeof (temp) - 2, ((long) w_end - (long) w_start) + 1));

	  if (!id_hash_get (lh_noise_words, (char *) &temp_ptr))
	    {
	      dk_set_push (&words, box_string (temp));
	    }
	}
      point = w_end + 1;
    }
  words = dk_set_nreverse (words);
  return words;
}
#endif

/* Initialization of noise-words hashtable from noise.txt

File noise.txt should be in the server's working directory.
It consists of control lines and text lines.

Text line is just a string of one or more words to be declared as noise.
Please keep them shorter than 1000 characters.

Control lines are those started from "Language:" or "Encoding:" (case is important)
"Language: lang-id" tells to use rules for language "lang-id" for future text
lines, until either another "Language:" control line or end of file.
Similarly, "Encoding: enc-id" tells to use rules for encoding "enc-id".
Control lines are always in plain ASCII, no matter which encoding is active
for text lines.
By default, server default language and "UTF-8" encoding will be used.

Noise words seem to be case-insensitive, but it is not true. If you
enter a word in text line, up to four noise words will be registered:
the word exactly as it was entered;
an uppercased form of this word, if it is defined for active language;
an lowercased form of this word, if it is defined for active language;
a capitalized form, with one (or more) first chars in upper case and the rest in lower case.
*/

/* When we use language handlers to split text lines on (noise) words, they
may try to access to lh_noise_words. Bugs will occur if this table will be
filled during the scan: some word may be filtered out as noise before all
four forms will be stored. To avoid this, temporary table will be filled;
meanwhile dummy (= empty) hashtable will be used to provide valid non-NULL
pointer for language-specific callbacks. */

id_hash_t * vt_stop_words;
static dk_mutex_t *stop_words_mtx;

void
noise_word_init_callback(const utf8char *buf, size_t bufsize, void *future_noise_words)
{
  lenmem_t lm;
  ptrlong one = 1;
  unichar wordbuf[WORD_MAX_CHARS];
  const utf8char *tail = buf;
  int wordlen = eh_decode_buffer__UTF8 (wordbuf, WORD_MAX_CHARS, (__constcharptr *)(&tail), (const char *) buf+bufsize);
  if (wordlen <= 0)
    GPF_T1("Encoding bug in noise_word_init_callback");
  lm.lm_length = wordlen * sizeof(unichar);
  lm.lm_memblock = (char *) dk_alloc(lm.lm_length);
  memcpy(lm.lm_memblock,wordbuf,lm.lm_length);
  id_hash_set ((id_hash_t *)future_noise_words, (char *) &lm, (char *) &one);
}


void
vt_noise_word_init (char *file, id_hash_t ** noise_ht)
{
  char nw[1000];
  char *tail;
  char *name;
  int res;
  encoding_handler_t *eh = &eh__UTF8;
  lang_handler_t *lh = server_default_lh;
  FILE *noise = fopen (file, "r");
  id_hash_t *future_noise_words = id_hash_allocate (2039, sizeof (lenmem_t), sizeof (caddr_t), lenmemhash, lenmemhashcmp);
  *noise_ht = id_hash_allocate (7, sizeof (lenmem_t), sizeof (caddr_t), lenmemhash, lenmemhashcmp);
  if (NULL == noise)
    return;
  while (fgets (nw, sizeof (nw), noise))
    {
      tail = nw + strlen (nw);
      if (!memcmp (nw, "Language:", strlen ("Language:")))
	{
	  name = nw + strlen ("Language:");
	  while ((tail > nw) && ((unsigned char) (tail[-1]) <= 32))
	    (--tail)[0] = '\0';
	  while ((name <= tail) && ((unsigned char) (name[0]) <= 32))
	    name++;
	  lh = lh_get_handler (name);
	  continue;
	}
      if (!memcmp (nw, "Encoding:", strlen ("Encoding:")))
	{
	  name = nw + strlen ("Encoding:");
	  while ((tail > nw) && ((unsigned char) (tail[-1]) <= 32))
	    (--tail)[0] = '\0';
	  while ((name <= tail) && ((unsigned char) (name[0]) <= 32))
	    name++;
	  eh = eh_get_handler (name);
	  if (NULL == eh)
	    log_error ("Unsupported encoding \"%s\" used in noise.txt file, some strings may be ignored", name);
	  continue;
	}
      if (NULL == eh)
	continue;
      res = lh_iterate_patched_words (eh, lh, nw, tail - nw, lh->lh_is_vtb_word, NULL, noise_word_init_callback, (void *) (future_noise_words));
      res |= lh_iterate_patched_words (eh, lh, nw, tail - nw, lh->lh_is_vtb_word, lh->lh_tocapital_word, noise_word_init_callback, (void *) (future_noise_words));
      res |= lh_iterate_patched_words (eh, lh, nw, tail - nw, lh->lh_is_vtb_word, lh->lh_toupper_word, noise_word_init_callback, (void *) (future_noise_words));
      res |= lh_iterate_patched_words (eh, lh, nw, tail - nw, lh->lh_is_vtb_word, lh->lh_tolower_word, noise_word_init_callback, (void *) (future_noise_words));
      res |= lh_iterate_patched_words (eh, lh, nw, tail - nw, lh->lh_is_vtb_word, lh->lh_normalize_word, noise_word_init_callback, (void *) (future_noise_words));
      if (res)
	log_error ("Broken text in noise.txt file, (encoding \"%s\"): %s", eh->eh_names[0], nw);
    }
  fclose (noise);
  id_hash_free (*noise_ht);
  *noise_ht = future_noise_words;
}


caddr_t
box_n_chars_reuse2 (char * str, int n, caddr_t replace1, caddr_t replace2)
{
  caddr_t res;
  uint32 res_size = (uint32)n + 1;
  uint32 aligned_res_size = ALIGN_STR (res_size);
  if (replace1 && aligned_res_size == ALIGN_STR (box_length (replace1)))
    {
      box_reuse ((box_t) replace1, (box_t) str, res_size, DV_SHORT_STRING);
      replace1[n] = '\0';
      dk_free_box (replace2);
      return replace1;
    }
  if (replace2 && aligned_res_size == ALIGN_STR (box_length (replace2)))
    {
      box_reuse ((box_t) replace2, (box_t) str, res_size, DV_SHORT_STRING);
      replace2[n] = '\0';
      dk_free_box (replace1);
      return replace2;
    }
  res = dk_alloc_box (res_size, DV_SHORT_STRING);
  memcpy (res, str, n);
  res [n] = '\0';
  dk_free_box (replace1);
  dk_free_box (replace2);
  return res;
}

/* depends of get_existing we either initialize explicitly or only when not initialized */
id_hash_t *
vt_load_stop_words  (char * file, int get_existing)
{
  id_hash_t * ht, **place;
  caddr_t copy;

  mutex_enter (stop_words_mtx);
  place = (id_hash_t **) id_hash_get (vt_stop_words, (caddr_t) &file);
  if (get_existing && place)
    {
      ht = *place;
      goto ret;
    }
  vt_noise_word_init (file, &ht);
  if (place)
    {
      id_hash_free (*place);
      *place = ht;
    }
  else
    {
      copy = box_copy (file);
      id_hash_set (vt_stop_words, (caddr_t) &copy, (caddr_t) &ht);
    }
ret:
  mutex_leave (stop_words_mtx);
  return ht;
}

#define TA_NOISE_HT 2201


int
is_vtb_word__xany (const unichar * buf, size_t bufsize)
{
  lenmem_t lm;
  char *nw;
  id_hash_t *ht = THR_ATTR (THREAD_CURRENT_THREAD, TA_NOISE_HT);
  if (1 > bufsize)
    return 0;
  if (NULL == ht)
    return 1;
  lm.lm_length = bufsize * sizeof (unichar);
  lm.lm_memblock = ( /*const */ char *) buf;
  nw = id_hash_get (ht, (char *) &lm);
  if (NULL == nw)
    return 1;
  return 0;
}

caddr_t
bif_vt_is_noise (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t word = bif_string_arg (qst, args, 0, "vt_is_noise");
  caddr_t enc_name = bif_string_arg (qst, args, 1, "vt_is_noise");
  caddr_t lang_name = bif_string_arg (qst, args, 2, "vt_is_noise");
  encoding_handler_t *eh = eh_get_handler (enc_name);
#if 0				/* Stub variant */
  lenmem_t lm;
  lm.lm_length = strlen (word);
  lm.lm_memblock = word;
  return box_num (NULL != id_hash_get (lh_noise_words, &lm));
#else /* Variant which may be reliably used for any language with any sort of word normalization */
  lang_handler_t *lh = lh_get_handler (lang_name);
  int cnt;
  if (NULL == eh)
    sqlr_new_error ("22023", "FT006", "Unknown encoding name '%s'", enc_name);
  cnt = lh_count_words (eh, lh, word, strlen (word), NULL);
  if (1 != cnt)
    return (box_num (0));
  if (BOX_ELEMENTS (args) > 3)
    {
      id_hash_t **ht, *ht_n = NULL;
      caddr_t file = bif_string_arg (qst, args, 3, "vt_is_noise");
      ht = (id_hash_t **) id_hash_get (vt_stop_words, (caddr_t) & file);
      if (NULL == ht && sec_bif_caller_is_dba ((query_instance_t *) qst) && is_allowed (file))
	ht_n = vt_load_stop_words (file, 1);
      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_NOISE_HT, (ht ? *ht : (ht_n ? ht_n : NULL)));
      cnt = lh_count_words (eh, lh, word, strlen (word), is_vtb_word__xany);
      SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_NOISE_HT, NULL);
    }
  else
    {
      cnt = lh_count_words (eh, lh, word, strlen (word), lh_get_handler (lang_name)->lh_is_vtb_word);
    }
  if (1 != cnt)
    return (box_num (1));
  return (box_num (0));
#endif
}


caddr_t
bif_vt_load_stop_words (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t file = bif_string_arg (qst, args, 0, "vt_load_stop_words");
  sec_check_dba ((query_instance_t *) qst, "vt_load_stop_words");
  if (!is_allowed (file))
    sqlr_new_error ("42000", "FA...", "Access to %s is denied due to access control in ini file", file);
  vt_load_stop_words (file, 0);
  return NULL;
}


void
vt_word_string_ends  (db_buf_t str, d_id_t * d_id_1, d_id_t * d_id_2)
{
  /* string, out first, out last */
  int l, hl;
    int pos = 0;
  d_id_t first;
  int total = box_length (str) - 1;
  d_id_t * id = NULL;

  D_SET_AT_END (&first);
  while (pos < total)
    {
      WP_LENGTH (str + pos, hl, l, str, total);
      id = (d_id_t *) (str + pos + hl);
      if (D_AT_END (&first))
	d_id_set (&first, id);
      pos += l + hl;
    }
  d_id_set (d_id_1, &first);
  d_id_set (d_id_2, id);
}


caddr_t
bif_vt_word_string_ends  (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* string, out first, out last */
  int l, hl;
  db_buf_t str = (db_buf_t) bif_string_arg (qst, args, 0, "vt_word_string_ends");
  int pos = 0;
  d_id_t first, last;
  int total = box_length (str) - 1;
  d_id_t * id = NULL;

  D_SET_AT_END (&first);
  while (pos < total)
    {
      WP_LENGTH (str + pos, hl, l, str, total);
      id = (d_id_t *) (str + pos + hl);
      if (D_AT_END (&first))
	d_id_set (&first, id);
      pos += l + hl;
    }
  d_id_set (&last, id);
  qst_set (qst, args[1], box_d_id (&first));
  qst_set (qst, args[2], box_d_id (&last));
  return 0;
}


caddr_t
bif_wb_all_done  (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* word batch, out first d_id, out flag true if more than 1 left */
  d_id_t d_id_1;
  d_id_t d_id_2;
  db_buf_t * wb = (db_buf_t *) bif_array_arg (qst, args, 0, "wb_all_done");
  int inx;
  int len = BOX_ELEMENTS (wb);
  for (inx = 0; inx < len; inx++)
    {
      db_buf_t wst = wb[inx];
      if (DV_STRINGP (wst))
	{
	  vt_word_string_ends (wst, &d_id_1, &d_id_2);
	  qst_set (qst, args[1], box_d_id (&d_id_1));
	  if (inx < len - 1)
	    qst_set (qst, args[2], box_num (1));
	  else
	    qst_set (qst, args[2], box_num (0));
	  return box_num (0);
	}
    }
  return box_num (1);
}


caddr_t
bif_vt_word_string_details  (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int n_d_ids = 0, n_words = 0;
  db_buf_t str = (db_buf_t) bif_string_arg (qst, args, 0, "vt_word_string_details");
  long print = (long) bif_long_arg (qst, args, 1, "vt_word_string_details");
  int pos = 0, w_pos;
  int len = box_length (str) - 1;
  if (print)
    printf ("{");
  while (pos < len)
    {
      d_id_t *id;
      int l2, dist, wp;
      int l, hl;
      n_d_ids ++;
      WP_LENGTH (str + pos, hl, l, str, len);
      id = (d_id_t *) (str + pos + hl);
      if (print)
	printf ("   [id: %ld ( ", (long) LONG_REF_NA (&id->id[0]));
      w_pos = pos + hl + WP_FIRST_POS (str + pos + hl);
      dist = 0;
      while (w_pos < pos + hl + l)
	{
	  n_words++;
	  WP_LENGTH (str + w_pos, l2, wp, str, len);
	  dist += wp;
	  if (print)
	    printf (" %d", dist);
	  w_pos += l2;
	}
      if (print)
	printf (")]\n");
      pos += l + hl;
    }
  if (print)
  printf ("}\n");
  return (list (2, box_num (n_d_ids), box_num (n_words)));
}

#define WB_DELETED ((wpos_t *) -1L)


caddr_t
wb_word_string  (word_batch_t *wb)
{
  caddr_t res;
  wpos_t *main_pos_array, *attr_pos_array, *pos_array;
  unsigned char atmp[5000];
  unsigned char * tmp = atmp;
  unsigned max = sizeof (atmp);
  unsigned fill = 6, len;
  int pass_main_positions = 1;
  wpos_t pos = 0, n_pos, inx;
  unsigned id_len = WP_FIRST_POS ((unsigned char *)(&(wb->wb_d_id)));
  memcpy (tmp+6, &(wb->wb_d_id), id_len);
  fill += id_len;
  main_pos_array = wb->wb_main_positions.wbp_buf;
  attr_pos_array = wb->wb_attr_positions.wbp_buf;
  if (WB_DELETED == main_pos_array)
    {
#ifndef NDEBUG
      if (0 != wb->wb_main_positions.wbp_buf_fill)
	GPF_T;
#endif
      main_pos_array = NULL;
    }
  if (WB_DELETED == attr_pos_array)
    {
#ifndef NDEBUG
      if (0 != wb->wb_attr_positions.wbp_buf_fill)
	GPF_T;
#endif
      attr_pos_array = NULL;
    }
  pos_array = main_pos_array;
  n_pos = wb->wb_main_positions.wbp_buf_fill;
process_wbp_buf:
  for (inx = 0; inx < n_pos; inx++)
    {
      wpos_t w_pos = pos_array[inx];
      wpos_t dist = w_pos -pos;
      if (dist < WP_MAX_8_BIT_LEN)
	tmp[fill++] = (unsigned char) dist;
      else if (dist < (254 - WP_MAX_8_BIT_LEN) * 256)
	{
	  tmp[fill++] = (unsigned char) ((dist >> 8) + WP_MAX_8_BIT_LEN);
	  tmp[fill++] = (unsigned char) (dist & 0xff);
	}
      else
	{
	  tmp[fill++] = (unsigned char) WP_32_BIT_LEN;
	  LONG_SET_NA (&tmp[fill], dist);
	  fill += 4;
	}
      pos = w_pos;
      if (fill > max - 10)
	{
	  caddr_t new_tmp;
	  max *= 2;
	  new_tmp = dk_alloc_box (max, DV_LONG_STRING);
	  memcpy (new_tmp, tmp, fill);
	  if (tmp != &atmp[0])
	    dk_free_box ((box_t) tmp);
	  tmp = (unsigned char *) new_tmp;
	}
    }
/* After writing of all main positions, additional loop may be done for
attribute positions. Main positions are ordered and in range from 0 to 2G-1,
Attribute positions are ordered too and in range from 2G to 4G. */
  if (pass_main_positions)
    {
      pass_main_positions = 0;
      if (NULL != attr_pos_array)
	{
	  pos_array = attr_pos_array;
	  n_pos = wb->wb_attr_positions.wbp_buf_fill;
	  goto process_wbp_buf;
	}
    }
  len = fill - 6;
  if (len < WP_MAX_8_BIT_LEN)
    {
      tmp[5] = len;
      res = box_n_chars_reuse2 ((char *) &tmp[5], len + 1, (caddr_t) main_pos_array, (caddr_t) attr_pos_array);
    }
  else if (len < (254 - WP_MAX_8_BIT_LEN) * 256)
    {
      tmp[4] = (len >> 8) + WP_MAX_8_BIT_LEN;
      tmp[5] = len & 0xff;
      res = box_n_chars_reuse2 ((char *) &tmp[4], len + 2, (caddr_t) main_pos_array, (caddr_t) attr_pos_array);
    }
  else
    {
      tmp[1] = (char) WP_32_BIT_LEN;
      LONG_SET_NA (&tmp[2], len);
      res = box_n_chars_reuse2 ((char *) &tmp[1], len + 5, (caddr_t) main_pos_array, (caddr_t) attr_pos_array);
    }
  if (tmp != &atmp[0])
    dk_free_box ((box_t) tmp);
  wb->wb_main_positions.wbp_buf = wb->wb_attr_positions.wbp_buf = NULL;
  wb->wb_main_positions.wbp_buf_fill = wb->wb_attr_positions.wbp_buf_fill = 0;
  return res;
}


caddr_t
wb_offband_1 (int hl, char * head, d_id_t * d_id, int len, char * string)
{
  caddr_t res = dk_alloc_box (hl + len + 1, DV_LONG_STRING);
  int id_len = WP_FIRST_POS (&d_id->id[0]);
  memcpy (res, head, hl);
  memcpy (res + hl, d_id, id_len);
  if (len > id_len)
    memcpy (res + hl + id_len, string, len - id_len);
  res[hl + len] = 0;
  return res;
}


caddr_t
wb_offband_string  (d_id_t * d_id, wpos_t * pos_array)
{
  char tmp[6];
  caddr_t string = (caddr_t) pos_array;
  int len = 0;
  if (WB_DELETED == pos_array)
    string = NULL;
  else
    len = box_length (string) - 1;
  len += WP_FIRST_POS (&d_id->id[0]);
  if (len < WP_MAX_8_BIT_LEN)
    {
      tmp[0] = len;
      return (wb_offband_1 (1, tmp, d_id, len, string));
    }
  else if (len < (254 - WP_MAX_8_BIT_LEN) * 256)
    {
      tmp[0] = (len >> 8) + WP_MAX_8_BIT_LEN;
      tmp[1] = len & 0xff;
      return (wb_offband_1 (2, tmp, d_id, len, string));
    }
  else
    {
      tmp[0] = (char) WP_32_BIT_LEN;
      LONG_SET_NA (&tmp[1], len);
      return (wb_offband_1 (5, tmp, d_id, len, string));
    }
}


static void
wbp_add_pos (wb_pos_t * wbp, wpos_t pos)
{
  wpos_t fill, len;
  if (wbp->wbp_buf == NULL || WB_DELETED == wbp->wbp_buf)
    {
      wbp->wbp_buf = (wpos_t *) dk_alloc_box (sizeof (wpos_t) * 4, DV_SHORT_STRING);
      /* string tag because the length should be aligned to string length alignment */
      wbp->wbp_buf_fill = 0;
    }
  len = box_length (wbp->wbp_buf) / sizeof (wpos_t);
  fill = wbp->wbp_buf_fill;
  if (fill >= len)
    {
      wpos_t * old = wbp->wbp_buf;
      wbp->wbp_buf = (wpos_t *) dk_alloc_box (len * 2 * sizeof (wpos_t), DV_SHORT_STRING);
      memcpy (wbp->wbp_buf, old, fill * sizeof (wpos_t));
      dk_free_box ((caddr_t) old);
    }
  wbp->wbp_buf[wbp->wbp_buf_fill++] = pos;
}


caddr_t
bif_vt_batch (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int sz = 1001;
  caddr_t name;
  lang_handler_t *lh = server_default_lh;
  encoding_handler_t *eh = NULL;
  vt_batch_t * vtb = (vt_batch_t *) dk_alloc_box_zero (sizeof (vt_batch_t), DV_TEXT_BATCH);
  vtb->vtb_ref_count = 1;
  vtb->vtb_words = id_hash_allocate (sz, sizeof (lenmem_t), sizeof (word_batch_t), lenmemhash, lenmemhashcmp);
  id_hash_set_rehash_pct (vtb->vtb_words, 200);
  switch (BOX_ELEMENTS (args))
    {
      default:
      case 3:
	name = bif_string_arg (qst, args, 2, "vt_batch");
	if (strcmp (name, "*ini*"))
	  {
	    eh = eh_get_handler (name);
	    if (NULL == eh)
	      sqlr_new_error ("42000", "FT036", "Invalid encoding name '%s' is specified by an argument of vt_batch()", name);
	  }
	/* no break */
      case 2:
	name = bif_string_arg (qst, args, 1, "vt_batch");
	if (strcmp (name, "*ini*"))
	  {
	    lh = lh_get_handler (name);
	    if (NULL == lh)
	      sqlr_new_error ("42000", "FT037", "Invalid language name '%s' is specified by an argument of vt_batch()", name);
	  }
	/* no break */
      case 1:
	sz = (int) bif_long_arg (qst, args, 0, "vt_batch");
	if ((sz < VT_BATCH_SIZE_MIN) || (VT_BATCH_SIZE_MAX < sz))
	  {
	    if (0 == sz)
	      sz = VT_BATCH_SIZE_DEFAULT;
	    else
	      sqlr_new_error ("42000", "FT038", "Invalid batch size argument '%ld' is specified by an argument of vt_batch()", (long)sz);
	  }
	/* no break */
      case 0:
	break;
    }
  if (NULL == eh)
    {
      wcharset_t *query_charset = QST_CHARSET(qst);
      if (NULL == query_charset)
	query_charset = default_charset;
      if (NULL == query_charset)
	eh = &eh__ISO8859_1;
      else
	{
	  eh = eh_get_handler (CHARSET_NAME (query_charset, NULL));
	  if (NULL == eh)
	    eh = &eh__ISO8859_1;
	}
    }
  vtb->vtb_default_eh = eh;
  vtb->vtb_default_lh = lh;
  vtb->vtb_attr_word_pos = FIRST_ATTR_WORD_POS;
  return ((caddr_t) vtb);
}


vt_batch_t *
bif_vtb_arg (caddr_t * qst, state_slot_t ** args, int n, const char * f)
{
  caddr_t v = bif_arg (qst, args, n, f);
  if (DV_TYPE_OF (v) != DV_TEXT_BATCH)
    sqlr_new_error ("22023", "FT220", "function %s expects a word batch as argument %d\n", f, n);
  return ((vt_batch_t *) v);
}

caddr_t
bif_vt_batch_d_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  vt_batch_t * vtb = bif_vtb_arg (qst, args, 0, "vt_batch_d_id");
  caddr_t new_d_id = bif_arg (qst, args, 1, "vt_batch_d_id");
  d_id_t nid;
  dtp_t dtp = DV_TYPE_OF (new_d_id);
  if (! (DV_LONG_INT == dtp || DV_COMPOSITE == dtp) )
    sqlr_new_error ("22023", "FT007", "vt_batch_d_id requires a composite or a number as id");
  if (dtp == DV_COMPOSITE && box_length (new_d_id) > sizeof (d_id_t))
    sqlr_new_error ("22023", "FT008", "composite document id over 32 characters long.");
  d_id_set_box (&nid, new_d_id);
  if (!D_AT_END (&vtb->vtb_d_id)
      && IS_LT (d_id_cmp (&nid, &vtb->vtb_d_id)))
    sqlr_new_error ("22023", "FT009", "vt_batch_d_id id's not in ascending order");

  if (D_AT_END (&nid) || D_INITIAL (&nid) || D_PRESET (&nid)
      || (DV_LONG_INT == DV_TYPE_OF (new_d_id) &&  unbox (new_d_id) < 0))
    sqlr_new_error ("22023", "FT010", "vt_batch_d_id id's cannot be 0 or negative.");

  vtb->vtb_d_id = nid;
  vtb->vtb_word_pos = 0;
  vtb->vtb_attr_word_pos = FIRST_ATTR_WORD_POS;
  return NULL;
}

caddr_t
bif_vt_batch_words_length (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  vt_batch_t * vtb = bif_vtb_arg (qst, args, 0, "vt_batch_words_length");
  return box_num (vtb->vtb_words_len);
}


caddr_t
bif_vt_batch_alpha_range (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  vt_batch_t * vtb = bif_vtb_arg (qst, args, 0, "vt_batch_d_id");
  caddr_t lower = bif_string_or_null_arg (qst, args, 1, "vt_batch_alpha_range");
  caddr_t upper = bif_string_or_null_arg (qst, args, 2, "vt_batch_alpha_range");
  vtb->vtb_min_word.lm_memblock = box_copy (lower);
  vtb->vtb_min_word.lm_length = lower ? strlen (lower) : 0;
  vtb->vtb_max_word.lm_memblock = box_copy (upper);
  vtb->vtb_max_word.lm_length = upper ? strlen (upper) : 0;
  return NULL;
}


void
vtb_qsort (caddr_t * in, caddr_t * left,
	    int n_in, int depth)
{
  if (n_in < 3)
    return;
  if (n_in < 5)
    {
      if (DVC_GREATER == cmp_boxes (in[0], in[2], NULL, NULL))
	{
	  caddr_t tmp = in[0];
	  caddr_t tmp1 = in[1];
	  in[0] = in[2];
	  in[1] = in[3];
	  in[2] = tmp;
	  in[3] = tmp1;
	}
    }
  else
    {
      caddr_t split;
      caddr_t mid_buf = NULL;
      int n_left = 0, n_right = n_in - 1;
      int inx;
      if (depth > 60)
	{
	  return;
	}

      split = in[(n_in / 4) * 2]; /* n_in always even, make sure split is at even */

      for (inx = 0; inx < n_in; inx+= 2)
	{
	  caddr_t this_pg = in[inx];
	  int rc = cmp_boxes (this_pg, split, NULL, NULL);
	  if (!mid_buf && rc == DVC_MATCH)
	    {
	      mid_buf = in[inx + 1];
	    }
	  else if (DVC_LESS == rc)
	    {
	      left[n_left++] = in[inx];
	      left[n_left++] = in[inx + 1];
	    }
	  else
	    {
	      left[n_right--] = in[inx + 1];
	      left[n_right--] = in[inx];
	    }
	}
      vtb_qsort (left, in, n_left, depth + 1);
      vtb_qsort (left + n_right + 1, in + n_right + 1,
	  (n_in - n_right) - 1, depth + 1);
      memcpy (in, left, n_left * sizeof (caddr_t));
      in[n_left] = split;
      in[n_left + 1] = mid_buf;
      memcpy (in + n_left + 2, left + n_left + 2,
	  ((n_in - n_right) - 1) * sizeof (caddr_t));

    }
}


caddr_t
bif_vt_batch_array_sort (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t * arr = (caddr_t *) bif_array_arg (qst, args, 0, "vt_batch_array_sort");
  caddr_t * left = (caddr_t *) dk_alloc_box (box_length ((caddr_t) arr), DV_ARRAY_OF_POINTER);
  vtb_qsort (arr, left, BOX_ELEMENTS (arr), 1);
  dk_free_box ((caddr_t) left);
  return NULL;
}


void
push_string_into_set_callback(const utf8char *buf, size_t bufsize, void *userdata)
{
  caddr_t word;
  word = box_dv_short_nchars ((char *)buf, bufsize);
  dk_set_push((dk_set_t *)userdata, word);
}

int
lm_compare (lenmem_t lm1, lenmem_t lm2)
{
  int rc = memcmp (lm1.lm_memblock, lm2.lm_memblock, MIN (lm1.lm_length, lm2.lm_length));
  if (rc != 0)
    return (rc > 0 ? 1 : -1);
  rc = (int)lm2.lm_length - (int)lm1.lm_length;
  if (rc != 0)
    return (rc > 0 ? 1 : -1);
  return 0;
}

void
vtb_hash_string_ins_callback(const utf8char *buf, size_t bufsize, void *userdata)
{
  vt_batch_t * vtb = (vt_batch_t *)userdata;
  id_hash_t * hash = vtb->vtb_words;
  lenmem_t lm;
  word_batch_t *place;
  ASSERT_NCHARS_UTF8(buf,bufsize);
  lm.lm_length = bufsize;
  lm.lm_memblock = (char *)(buf);
  if (0 && id_hash_get (lh_noise_words, (char *)&lm))
    return;

  if ((vtb->vtb_min_word.lm_memblock && 1 == lm_compare (vtb->vtb_min_word, lm))
      || (vtb->vtb_max_word.lm_memblock && -1 == lm_compare (vtb->vtb_max_word, lm)))
    {
      vtb->vtb_word_pos++;
      vtb->vtb_words_len += bufsize;
      return;
    }
  if (DK_MEM_RESERVE)
    return; /* Dry run in progress */
  place = (word_batch_t *)id_hash_get (hash, (char *)(&lm));
  if(NULL != place)
    {
      if (DVC_MATCH != d_id_cmp (&vtb->vtb_d_id, &place->wb_d_id))
	{
	  dk_set_push (&place->wb_word_recs, (void*)wb_word_string (place));
	  place->wb_d_id = vtb->vtb_d_id;
	}
      wbp_add_pos (
	(IS_ATTR_WORD_POS(vtb->vtb_word_pos) ? &(place->wb_attr_positions) : &(place->wb_main_positions)),
	vtb->vtb_word_pos );
    }
  else
    {
      lenmem_t lm;
      word_batch_t wb;
      lm.lm_length = bufsize;
      lm.lm_memblock = dk_alloc_box(bufsize+1,DV_SHORT_STRING);
      memcpy (lm.lm_memblock, buf,bufsize);
      lm.lm_memblock[bufsize] = '\0';
      memset (&wb, 0, sizeof (wb));
      wb.wb_d_id = vtb->vtb_d_id;
      wbp_add_pos (
	(IS_ATTR_WORD_POS(vtb->vtb_word_pos) ? &(wb.wb_attr_positions) : &(wb.wb_main_positions)),
	vtb->vtb_word_pos );
      id_hash_set (hash, (char *) &lm, (char *) &wb);
    }
  vtb->vtb_words_len += bufsize;
  vtb->vtb_word_pos++;
}


void
vtb_hash_string_del_callback(const utf8char *buf, size_t bufsize, void *userdata)
{
  vt_batch_t * vtb = (vt_batch_t *)userdata;
  id_hash_t * hash = vtb->vtb_words;
  lenmem_t lm;
  word_batch_t *place;
  lm.lm_length = bufsize;
  lm.lm_memblock = (char *)(buf);
  if (DK_MEM_RESERVE)
    return; /* Dry run in progress */
  place = (word_batch_t *)id_hash_get (hash, (char *)(&lm));
  if(NULL != place)
    {
      if (DVC_MATCH != d_id_cmp (&vtb->vtb_d_id, &place->wb_d_id))
	{
	  dk_set_push (&place->wb_word_recs, (void*)wb_word_string (place));
	  place->wb_d_id = vtb->vtb_d_id;
	}
      FREE_WBP_BUF (place->wb_main_positions);
      FREE_WBP_BUF (place->wb_attr_positions);
      place->wb_main_positions.wbp_buf = place->wb_attr_positions.wbp_buf = WB_DELETED;
      place->wb_main_positions.wbp_buf_fill = place->wb_attr_positions.wbp_buf_fill = 0;
    }
  else
    {
      lenmem_t lm;
      word_batch_t wb;
      lm.lm_length = bufsize;
      lm.lm_memblock = dk_alloc_box(bufsize+1,DV_SHORT_STRING);
      memcpy (lm.lm_memblock, buf,bufsize);
      lm.lm_memblock[bufsize] = '\0';
      memset (&wb, 0, sizeof (wb));
      wb.wb_d_id = vtb->vtb_d_id;
      wb.wb_main_positions.wbp_buf = wb.wb_attr_positions.wbp_buf = WB_DELETED;
      id_hash_set (hash, (char *) &lm, (char *) &wb);
    }
  vtb->vtb_words_len += bufsize;
  vtb->vtb_word_pos++;
}


static char
xte_vtb_feed (caddr_t * xte, vt_batch_t * vtb, lh_word_callback_t *cbk, char **textbufptr, lang_handler_t *lh, char hider)
{
  wpos_t inx;
  dtp_t dtp = DV_TYPE_OF (xte);
  if (is_string_type (dtp))
    {
      inx=vtb->vtb_word_pos;
      lh_iterate_patched_words(
	&eh__UTF8, lh,
	(caddr_t) xte, box_length((caddr_t)xte),
	lh->lh_is_vtb_word, lh->lh_normalize_word,
	cbk, vtb );
      if (vtb->vtb_word_pos!=inx)
	hider = XML_MKUP_TEXT;
      return hider;
    }
  if (DV_ARRAY_OF_POINTER == dtp)
    {
      caddr_t * head = ((caddr_t**) xte)[0];
      int attr_idx, attr_idx_max;
      caddr_t name;
      size_t namelen;
      if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (head))
	sqlr_new_error ("22023", "FT011", "Bad XML entity tree in vt_batch_feed");
	name = head[0];
	if (!DV_STRINGP (name))
	  sqlr_new_error ("22023", "FT012", "Bad XML entity tree in vt_batch_feed");
	if (' ' == name[0])
	  {
	    if (!strcmp(name," root"))
	      goto process_tag; /* see below */
	    return hider;
	  }
	if(box_length(name)>(XML_MAX_EXP_NAME-2))
	  sqlr_new_error ("22023", "FT013", "Bad XML entity tree in vt_batch_feed");
process_tag:
      attr_idx_max = BOX_ELEMENTS(head) - 1;
      for (attr_idx = 1; attr_idx < attr_idx_max; attr_idx += 2)
	{
	  if (!strcmp(head[attr_idx], "xml:lang"))
	    {
	      lh = lh_get_handler(head[attr_idx+1]);
	      break;
	    }
	}
      if((XML_MKUP_ETAG != hider) && (vtb->vtb_word_pos>0))
	vtb->vtb_word_pos--;
      if (0 != attr_idx_max)
	{
	  wpos_t saved_pos = vtb->vtb_word_pos;
	  wpos_t attr_poss[2];
	  attr_poss[0] = vtb->vtb_attr_word_pos;
	  vtb->vtb_word_pos = attr_poss[0];
	  for (attr_idx = 1; attr_idx < attr_idx_max; attr_idx += 2)
	    {
	      char *attr_name = head[attr_idx];
	      char *attr_value;
#if 0
	      if (!strcmp(attr_name, WST_ATTRPOSS))
		continue;
#endif
	      if (' ' == attr_name[0])
		continue;
	      namelen = strlen(attr_name);
	      snprintf (textbufptr[0], box_length (textbufptr[0]), "{%s", attr_name);
	      cbk ((const utf8char *) textbufptr[0], 1+namelen, vtb);
	      attr_value = head[attr_idx+1];
	      lh_iterate_patched_words(
		&eh__UTF8, lh,
		attr_value, box_length(attr_value),
		lh->lh_is_vtb_word, lh->lh_normalize_word,
		cbk, vtb );
	      snprintf (textbufptr[0], box_length (textbufptr[0]), "}%s", attr_name);
	      cbk ((const utf8char *) textbufptr[0], 1+namelen, vtb);
	    }
	  attr_poss[1] = vtb->vtb_attr_word_pos = vtb->vtb_word_pos;
	  vtb->vtb_word_pos =  saved_pos;
	}
      hider = XML_MKUP_STAG;
      namelen = strlen(name);
      snprintf (textbufptr[0], box_length (textbufptr[0]), "<%s", name);
      cbk ((const utf8char *) textbufptr[0], 1+namelen, vtb);
      for (inx = 1; inx < (int) BOX_ELEMENTS (xte); inx++)
	hider = xte_vtb_feed ((caddr_t*) xte[inx], vtb, cbk, textbufptr, lh, hider);
      snprintf (textbufptr[0], box_length (textbufptr[0]), "/%s", name);
      cbk ((const utf8char *) textbufptr[0], 1+namelen, vtb);
      vtb->vtb_word_pos--;
      hider = XML_MKUP_ETAG;
      return hider;
    }
  return hider;
}


caddr_t
bif_vt_batch_feed_offband (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  vt_batch_t * vtb = bif_vtb_arg (qst, args, 0, "vt_batch_feed_offband");
  caddr_t str = bif_arg (qst, args, 1, "vt_batch_feed_offband");
  long is_deleted = (long) bif_long_arg (qst, args, 2, "vt_batch_feed_offband");
  word_batch_t * place;
  lenmem_t offb;
  offb.lm_memblock = WST_OFFBAND;
  offb.lm_length = 1;
  place = (word_batch_t *) id_hash_get (vtb->vtb_words, (caddr_t) &offb);
  if (place)
    {
      if (DVC_MATCH != d_id_cmp (&vtb->vtb_d_id, &place->wb_d_id))
	{
	  dk_set_push (&place->wb_word_recs, (void*)
		       wb_offband_string (&place->wb_d_id, place->wb_main_positions.wbp_buf));
	  place->wb_d_id = vtb->vtb_d_id;
	  place->wb_main_positions.wbp_buf_fill = 0;
	  FREE_WBP_BUF (place->wb_main_positions);
	  place->wb_main_positions.wbp_buf = NULL;
	}
      FREE_WBP_BUF (place->wb_main_positions);
      place->wb_main_positions.wbp_buf = (is_deleted ? WB_DELETED : (wpos_t *) box_copy (str));
    }
  else
    {
      word_batch_t wb;
      lenmem_t lm;
      lm.lm_memblock = box_dv_short_string (WST_OFFBAND);
      lm.lm_length = 1;
      memset (&wb, 0, sizeof (wb));
      wb.wb_d_id = vtb->vtb_d_id;
      wb.wb_main_positions.wbp_buf = (is_deleted ? WB_DELETED : (wpos_t *) box_copy (str));
      id_hash_set (vtb->vtb_words, (char *) &lm, (char *) &wb);
    }
  return 0;
}


/* vt_batch_feed forth optional argument */
#define VTB_NOT_XML		0
#define VTB_FORSE_XML		1
#define VTB_TRY_XML		2
#define VTB_NOT_STORE_MASK	128

/* IvAn/TextXperIndex/000815 Persistent XML cases changed */
caddr_t
bif_vt_batch_feed (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t *qi = (query_instance_t *) qst;
  int argc = BOX_ELEMENTS (args);
  caddr_t tmpbuf;
  vt_batch_t * vtb = bif_vtb_arg (qst, args, 0, "vt_batch_feed");
  caddr_t str = bif_arg (qst, args, 1, "vt_batch_feed");
  lang_handler_t *lh = (
    (argc > 4) ?
    lh_get_handler (bif_string_arg (qst, args, 4, "vt_batch_feed")) :
    vtb->vtb_default_lh );
  int is_delete = (int) bif_long_arg (qst, args, 2, "vt_batch_feed");
  lh_word_callback_t *cbk = (is_delete ? vtb_hash_string_del_callback : vtb_hash_string_ins_callback);
  int is_xml = VTB_NOT_XML;
  int is_serialized_xml = 1;
  int is_wide = 0;
  int store_result = 1;
  dtp_t dtp = DV_TYPE_OF (str);
  caddr_t temp_str = NULL, temp_tree = NULL;
  if (vtb->vtb_strings_taken)
    sqlr_new_error ("42000", "FT014", "The vt_batch object can't be used in vt_batch_feed() if vt_batch_strings() or vt_batch_strings_array() has been called.");

  if (dtp == DV_DB_NULL)
    return NULL;
  if (argc > 3)
    {
      is_xml = (int) bif_long_arg (qst, args, 3, "vt_batch_feed");
      if (is_xml >= VTB_NOT_STORE_MASK)
	{
	  store_result = 0;
	  is_xml -= VTB_NOT_STORE_MASK;
	}
    }
/* IvAn/DvBlobXper/001212 XPER support changed */
  if (dtp == DV_XML_ENTITY)
    {
#ifdef DV_BLOB_XPER
      if (XE_IS_PERSISTENT ((xml_entity_t *)str))
	{
	  if(store_result)
	    {
	      const char *errmsg;
	      tmpbuf = dk_alloc_box (XML_MAX_EXP_NAME, DV_LONG_STRING);
	      errmsg = xper_elements_vtb_feed ((xper_entity_t *)str, vtb, cbk, lh, &tmpbuf);
	      dk_free_box(tmpbuf);
	      if (NULL != errmsg)
		sqlr_new_error ("37000", "XP9C0", "Error while indexing persistent XML blob: %.1000s", errmsg);
	    }
	  return NULL;
	}
#endif
      if(store_result)
	 {
	   caddr_t * tree = (caddr_t *)((xml_tree_ent_t *)str)->xe_doc.xtd->xtd_tree;
	   tmpbuf = dk_alloc_box (XML_MAX_EXP_NAME, DV_LONG_STRING);
	   if ((0 != vtb->vtb_word_pos) || (FIRST_ATTR_WORD_POS != vtb->vtb_attr_word_pos))
	     sqlr_new_error ("37000", "XP9C1", "XML tree may not be indexed as part of compound text");
	   xte_vtb_feed (tree, vtb, cbk, &tmpbuf, lh, XML_MKUP_STAG);
	   dk_free_box(tmpbuf);
	 }
      return NULL;
    }
  if (dtp == DV_BLOB_XPER_HANDLE)
    {
      if(store_result)
	{
	  tmpbuf = dk_alloc_box (XML_MAX_EXP_NAME, DV_LONG_STRING);
	  xper_blob_vtb_feed (qi, (blob_handle_t *) str, vtb, cbk, lh, &tmpbuf);
	  dk_free_box(tmpbuf);
	}
      return NULL;
    }
  if (dtp == DV_BLOB_HANDLE || dtp == DV_BLOB_BIN)
    {
      is_serialized_xml = blob_looks_like_serialized_xml (qi, (blob_handle_t *)(str));
      if (XE_XPER_SERIALIZATION == is_serialized_xml)
	{
	  if(store_result)
	    {
	      tmpbuf = dk_alloc_box (XML_MAX_EXP_NAME, DV_LONG_STRING);
	      xper_blob_vtb_feed (qi, (blob_handle_t *) str, vtb, cbk, lh, &tmpbuf);
	      dk_free_box(tmpbuf);
	    }
	  return NULL;
	}
      if (XE_XPACK_SERIALIZATION == is_serialized_xml)
        {
          dk_session_t *ses = blob_to_string_output (qi->qi_trx, str);
          xte_deserialize_packed (ses, (caddr_t **) &temp_tree, NULL);
          strses_free (ses);
          goto temp_tree_ready;
	}
      if ((((blob_handle_t *) str)->bh_length) > 10000000)
	return NULL;
      temp_str = blob_to_string (qi->qi_trx, str);
      goto process_string;
    }
  if (dtp == DV_BLOB_WIDE_HANDLE)
    {
      /*caddr_t temp_str1 = NULL;*/
      if ((((blob_handle_t *) str)->bh_length) > 10000000)
	return NULL;
#if 1
      temp_str = blob_to_string (qi->qi_trx, str);
      is_wide = 1;
#else
      temp_str1 = blob_to_string (qi->qi_trx, str);
      temp_str = box_wide_string_as_narrow (temp_str1, NULL, 0, QST_CHARSET (qi));
      dk_free_box (temp_str1);
#endif
      goto process_string;
    }
  if (IS_WIDE_STRING_DTP (dtp))
    {
#if 1
      is_wide = 1;
#else
      temp_str = box_wide_string_as_narrow (str, NULL, 0, QST_CHARSET (qi));
#endif
      goto process_string;
    }
  if (dtp == DV_STRING_SESSION)
    {
      if (!STRSES_CAN_BE_STRING ((dk_session_t *) str))
	return NULL;
      temp_str = strses_string ((dk_session_t *) str);
      goto process_string;
    }
  if (!DV_STRINGP (str) && dtp != DV_BIN)
    return NULL;
process_string:
  if (temp_str)
    str = temp_str;
  is_serialized_xml = str_looks_like_serialized_xml(str);
  if(XE_XPER_SERIALIZATION == is_serialized_xml)
    {
      /* this was: sqlr_new_error ("37000", "XXX", "Persistent XML strings not supported yet by text index"); */
      if(store_result)
	{
	  tmpbuf = dk_alloc_box (XML_MAX_EXP_NAME, DV_LONG_STRING);
	  xper_str_vtb_feed (qi, str, vtb, cbk, lh, &tmpbuf);
	  dk_free_box(tmpbuf);
	}
      goto done; /* jump toward end of function to free resources */
    }
  if (XE_XPACK_SERIALIZATION == is_serialized_xml)
    {
      dk_session_t *ses = blob_to_string_output (qi->qi_trx, str);
      xte_deserialize_packed (ses, (caddr_t **) &temp_tree, NULL);
      strses_free (ses);
      goto temp_tree_ready;
    }
  if (is_xml)
    {
      wcharset_t *charset;
      if (is_wide)
	charset = NULL;
      else
	{
	  charset = QST_CHARSET (qi);
	  if (!charset)
	    charset = default_charset;
	}
      {
        static caddr_t dtd_config = NULL;
        if (NULL == dtd_config)
          dtd_config = box_dv_short_string ("Validation=DISABLE Include=DISABLE");
        temp_tree = xml_make_mod_tree (qi, str, err_ret, GE_XML, NULL, NULL /*(is_wide ? NULL : vtb->vtb_default_eh->eh_names[0])*/, lh, dtd_config, NULL /* do not save DTD */, NULL /* do not cache IDs */, NULL /* no namespace 2way dict */);
      }
      if (is_xml == VTB_TRY_XML && (err_ret && *err_ret))
	{
	  dk_free_tree (*err_ret);
	  *err_ret = NULL;
	  goto process_as_text;
	}
      else
	{
	  if (temp_str)
	    {
	      dk_free_box (temp_str);
	      temp_str = NULL;
	    }
	  str = temp_tree;
	}
      if (err_ret && *err_ret)
	goto done;
      goto temp_tree_ready;
    }
process_as_text:
  if (store_result)
    {
      encoding_handler_t *eh = (is_wide ? &eh__WIDE_121 : vtb->vtb_default_eh);
      if ((&eh__UTF8 == eh) || (&eh__UTF8_QR == eh))
        {
          ASSERT_BOX_UTF8 (str);
	}
      else if (&eh__WIDE_121 == eh)
        {
          ASSERT_BOX_WCHAR (str);
	}
      else
        {
          ASSERT_BOX_8BIT (str);
	}
      lh_iterate_patched_words (
         eh, lh,
         str, box_length(str),
         lh->lh_is_vtb_word, lh->lh_normalize_word,
         cbk, vtb );
    }
  goto done;

temp_tree_ready:
  if (temp_tree && store_result)
    {
      tmpbuf = dk_alloc_box (XML_MAX_EXP_NAME, DV_LONG_STRING);
      if ((0 != vtb->vtb_word_pos) || (FIRST_ATTR_WORD_POS != vtb->vtb_attr_word_pos))
	sqlr_new_error ("37000", "XP9C2", "Temporary XML tree may not be indexed as part of compound text");
      xte_vtb_feed ((caddr_t*) str, vtb, cbk, &tmpbuf, lh, XML_MKUP_STAG);
      dk_free_box(tmpbuf);
  }

done:
  if (temp_str)
    dk_free_box (temp_str);
  if (temp_tree)
    dk_free_tree (temp_tree);
  return NULL;
}


caddr_t
bif_vt_batch_feed_wordump (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  vt_batch_t * vtb = bif_vtb_arg (qst, args, 0, "vt_batch_feed_wordump");
  caddr_t str = bif_arg (qst, args, 1, "vt_batch_feed_wordump");
  dtp_t dtp = DV_TYPE_OF (str);
  int is_delete = (int) bif_long_arg (qst, args, 2, "vt_batch_feed_wordump");
  lh_word_callback_t *cbk = (is_delete ? vtb_hash_string_del_callback : vtb_hash_string_ins_callback);
  unsigned char *str_tail, *str_next_tail, *str_end;
  int wordlen;
  caddr_t temp_str = NULL;
  if (vtb->vtb_strings_taken)
    sqlr_new_error ("42000", "FT034", "The vt_batch object can't be used in vt_batch_feed_wordump() after vt_batch_strings_array() has been called.");
  if (dtp == DV_DB_NULL)
    return NULL;
  if (dtp == DV_STRING_SESSION)
    {
      if (!STRSES_CAN_BE_STRING ((dk_session_t *) str))
	return NULL;
      temp_str = strses_string ((dk_session_t *) str);
      goto process_string;
    }
  if (!DV_STRINGP (str))
    return NULL;
process_string:
  if (temp_str)
    str = temp_str;
  str_end = (unsigned char *)(str + box_length (str)-1);
  str_tail = (unsigned char *) str;
  while (str_tail < str_end)
    {
      wordlen = (str_tail++)[0];
      str_next_tail = str_tail + wordlen;
      if (str_next_tail > str_end)
	sqlr_new_error ("42000", "FT035", "Invalid format of string argument in vt_batch_feed_wordump()");
      cbk (str_tail, wordlen, vtb);
      str_tail = str_next_tail;
    }
  if (temp_str)
    dk_free_box (temp_str);
  return NULL;
}

void
vtb_wordump (vt_batch_t * vtb, dk_session_t * ses)
{
  word_batch_t * wb;
  lenmem_t *lm;
  id_hash_iterator_t hit;
  if (vtb->vtb_strings_taken)
    id_hash_clear (vtb->vtb_words);
  id_hash_iterator (&hit, vtb->vtb_words);
  while (hit_next (&hit, (caddr_t*) &lm, (caddr_t*) &wb))
    {
      session_buffered_write_char ((unsigned char )(lm->lm_length), ses);
      session_buffered_write (ses, lm->lm_memblock, lm->lm_length);
    }
}


caddr_t
vtb_strings (vt_batch_t * vtb, dk_session_t * ses, caddr_t * err_ret)
{
  word_batch_t * wb;
  int fill = 0;
  lenmem_t *lm;
  caddr_t * res;
  size_t ret_len = sizeof (caddr_t) * 2 * vtb->vtb_words->ht_inserts;
  id_hash_iterator_t hit;

  if (ret_len >= MAX_BOX_LENGTH)
    {
      if (err_ret)
	err_ret [0] = srv_make_new_error ("22023", "FT...", "The result array too large");
      return NULL;
    }
  res = (caddr_t*) dk_alloc_box (ret_len, DV_ARRAY_OF_POINTER);
  if (vtb->vtb_strings_taken)
    id_hash_clear (vtb->vtb_words);
  id_hash_iterator (&hit, vtb->vtb_words);

  while (hit_next (&hit, (caddr_t*) &lm, (caddr_t*) &wb))
    {
      res[fill] = lm->lm_memblock;
      if (ses)
	{
	  session_buffered_write (ses, lm->lm_memblock, lm->lm_length);
	  session_buffered_write_char (' ', ses);
	}
      if (!D_AT_END (&wb->wb_d_id))
	{
	  caddr_t strg;
/* Note that wb_word_string will reuse and/or free wb->wb_main_positions and wb->wb_attr_positions
whereas wb_offband_string will not, so a separate FREE_WBP_BUF is needed for offband data. */
	  if (WST_OFFBAND_CHAR == lm->lm_memblock[0])
	    {
	      wpos_t *buf = wb->wb_main_positions.wbp_buf;
	      strg = wb_offband_string (&wb->wb_d_id, buf);
	      FREE_WBP_BUF (wb->wb_main_positions);
	    }
	  else
	    strg = wb_word_string (wb);
	  dk_set_push (&wb->wb_word_recs, (void*) strg);
	}
      else /* if not released or reused above we must free */
	{
	  FREE_WBP_BUF (wb->wb_attr_positions);
	  FREE_WBP_BUF (wb->wb_main_positions);
	  wb->wb_main_positions.wbp_buf = wb->wb_attr_positions.wbp_buf = NULL;
	}
      res[fill + 1] = list_to_array (dk_set_nreverse (wb->wb_word_recs));
      wb->wb_word_recs = (dk_set_t) res[fill + 1];
      fill += 2;
    }
  vtb->vtb_strings_taken = 1;
  vtb->vtb_words->ht_inserts = 0;
  return (caddr_t) res;
}


caddr_t
bif_vt_batch_strings (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  vt_batch_t * vtb = bif_vtb_arg (qst, args, 0, "vt_batch_strings");
  dk_session_t *out = NULL;
  dtp_t out_dtp;
  if (BOX_ELEMENTS (args) > 1)
    {
      out = (dk_session_t *) bif_arg (qst, args, 1, "vt_batch_strings");
      out_dtp = DV_TYPE_OF (out);

      if (DV_STRING_SESSION != out_dtp)
	sqlr_new_error ("22023", "FT016",
	    "vt_batch_strings needs a string_output as a second argument, not an argument of type %s (%d)",
	    dv_type_title (out_dtp), out_dtp);
    }
  return (vtb_strings (vtb, out, err_ret));
}

/*caddr_t
bif_vt_batch_strings (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  sqlr_new_error ("22000", "FT033",
    "vt_batch_strings() is no longer supported; you should probably make a backup and then re-create freetext indexes of your database");
  return NULL;
}*/


caddr_t
bif_vt_batch_strings_array (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  vt_batch_t * vtb = bif_vtb_arg (qst, args, 0, "vt_batch_strings_array");
  caddr_t *words = (caddr_t *)vtb_strings (vtb, NULL, err_ret);
  return (caddr_t)(words);
}


caddr_t
bif_vt_batch_wordump (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  vt_batch_t * vtb = bif_vtb_arg (qst, args, 0, "vt_batch_wordump");
  dk_session_t *out = (dk_session_t *) bif_arg (qst, args, 1, "vt_batch_wordump");
  dtp_t out_dtp = DV_TYPE_OF (out);
  if (DV_STRING_SESSION != out_dtp)
    sqlr_new_error ("22023", "FT016",
      "vt_batch_wordump needs a string_output as a second argument, not an argument of type %s (%d)",
      dv_type_title (out_dtp), out_dtp);
  vtb_wordump (vtb, out);
  return NULL;
}

#define SWITCH_IF_NO_FIT(len) \
  if (len + fill > max && fill > 0) \
    { \
      dk_set_push (&res, box_dv_short_nchars ((char *) temp, fill)); \
      fill = 0; \
    }


#define COPY(str, len) \
  if (len > max) \
    dk_set_push (&res, (void*) box_dv_short_nchars ((char *) str, len)); \
  else  \
    { \
      memcpy (&temp[fill], str, len); \
      fill += len; \
    }


int wb_apply_count;

caddr_t
bif_wb_apply (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int batch_over = 0;
  db_buf_t org = (db_buf_t) bif_string_arg (qst, args, 0, "wb_apply");
  caddr_t * batch = (caddr_t*) bif_array_arg (qst, args, 1, "wb_apply");
  d_id_t end_id;
  caddr_t end_id_2 = bif_arg (qst, args, 2, "wb_apply");
  long max = (long) bif_long_arg (qst, args, 3, "wb_apply");
  int batch_len = BOX_ELEMENTS (batch);
  int org_len = box_length ((caddr_t) org) - 1;
  caddr_t ins = NULL;
  int wb_inx = 0;
  int ins_len = 0;
  d_id_t ins_id, d_id;
  dtp_t temp[VT_MAX_WORD_STRING_BYTES * 2];
  int mid = 0;
  int fill = 0;
  dk_set_t res = NULL;
  int l = 0, hl = 0;

  D_SET_INITIAL (&d_id);
  D_SET_INITIAL (&ins_id);
  if (unbox (end_id_2))
    d_id_set_box (&end_id, end_id_2);
  else
    D_SET_INITIAL (&end_id);
  wb_apply_count++;
  if (max > VT_MAX_WORD_STRING_BYTES)
    sqlr_new_error ("22003", "FT017", "word_string_insert max length too high");
  while (wb_inx < batch_len && !batch[wb_inx])
    wb_inx++;
  if (wb_inx >= (int) BOX_ELEMENTS (batch))
    return NULL;
  for (;;)
    {
      if (!ins && !batch_over)
	{
	  if (wb_inx >= batch_len)
	    batch_over = 1;
	  else
	    {
	      int ihl, il, id_len;
	      ins = (caddr_t) batch[wb_inx];
	      ins_len = box_length (ins) - 1;
	      WP_LENGTH (ins, ihl, il, ins, ins_len);
	      d_id_set (&ins_id, (d_id_t*) (ins + ihl));
	      id_len = WP_FIRST_POS (ins + ihl);
	      if (id_len + 1 == ins_len)
		ins_len = 0; /* word entry deleted, no positions */
	      if (!D_INITIAL (&end_id) && IS_GTE (d_id_cmp (&ins_id, &end_id)))
		{
		  batch_over = 1;
		  ins = NULL;
		}
	      else
		{
		  batch[wb_inx] = NULL;
		  wb_inx++;
		}
	    }
	}
      if (mid < org_len)
	{
	  WP_LENGTH (org + mid, hl, l, org, org_len);
	  d_id_set (&d_id,  (d_id_t *) (org + mid + hl));
	}
      if (mid >= org_len && !ins)
	break;
      if (ins
	  && (mid >= org_len || IS_LTE (d_id_cmp (&ins_id, &d_id))))
	{
	  SWITCH_IF_NO_FIT (ins_len);
	  COPY (ins, ins_len);
	  dk_free_box (ins);
	  ins = NULL;
	  if (DVC_MATCH == d_id_cmp (&d_id, &ins_id))
	    mid += l + hl; /* org replaced */
	}
      else
	{
	  SWITCH_IF_NO_FIT (l + hl);
	  COPY (org + mid, l + hl);
	  mid += l + hl;
	}
    }
  if (fill)
    dk_set_push (&res, (void*) box_dv_short_nchars ((char *) temp, fill));
  return (list_to_array (dk_set_nreverse (res)));
}



caddr_t
bif_key_is_d_id_partition (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return 0;
}


int
vtb_destroy (vt_batch_t * vtb)
{
  vtb->vtb_ref_count--;
  if (vtb->vtb_ref_count)
    return 1;
  if (vtb->vtb_words->ht_inserts)
    dk_free_tree (vtb_strings (vtb, NULL, NULL));
  id_hash_free (vtb->vtb_words);
  dk_free_box (vtb->vtb_min_word.lm_memblock);
  dk_free_box (vtb->vtb_max_word.lm_memblock);
  return 0;
}

void
vtb_serialize (caddr_t vtb, dk_session_t * out)
{
  session_buffered_write_char (DV_DB_NULL, out);
}

static char *exestr_text =
"create procedure execstr (in str varchar)\n"
"{\n"
"  declare st, msg varchar;\n"
"  st := \'00000\';\n"
/*"  dbg_obj_print (str); \n"*/
"  exec (str, st, msg, vector (), 0, null, null);\n"
"  if (st <> \'00000\')\n"
"    {\n"
"      txn_error (6);\n"
"      signal (st, msg);\n"
"    }\n"
"}\n";

static char *vt_batch_update_text =
"create procedure vt_batch_update (in datatable varchar, in new_mode varchar, in update_interval integer)\n"
"{ \n"
"  declare registry_name, old_mode, _p_name varchar; \n"
"  declare has_it integer; \n"
/*"  datatable := complete_table_name (fix_identifier_case (datatable), 1); \n"*/
"  datatable := complete_table_name ((datatable), 1); \n"
"  select count (*) into has_it from DB.DBA.SYS_VT_INDEX where VI_TABLE = datatable; \n"
"  if (has_it <> 1) \n"
"    signal (\'42S02\', \'The table is not freetext indexed\', \'FT018\'); \n"
"  registry_name := concat (\'DELAY_UPDATE_\', DB.DBA.SYS_ALFANUM_NAME (replace (datatable, \'.\', \'_\'))); \n"
"  old_mode := registry_get (registry_name); \n"
"  if (0 = isstring (old_mode)) old_mode := \'OFF\'; \n"
"  if (isstring(new_mode)) \n"
"    { \n"
"      new_mode := ucase (new_mode); \n"
"      if (new_mode <> \'ON\' and new_mode <> \'OFF\') \n"
"	signal (\'22023\', concat (\'The new mode should be ON or OFF, not \', new_mode), \'FT019\'); \n"
"      else \n"
"	{ \n"
"	  declare stat, msg varchar; \n"
"	  declare rc integer; \n"
"	  registry_set (registry_name, new_mode); \n"
"	  datatable := DB.DBA.SYS_ALFANUM_NAME (replace (datatable, \'.\', \'_\')); \n"
"	  _p_name := coalesce ((select P_NAME from DB.DBA.SYS_PROCEDURES where lcase (P_NAME) like lcase (concat ('%VT_INC_INDEX_' ,datatable))), concat ('VT_INC_INDEX_', datatable, '()'));\n"
"	  _p_name := sprintf ('\"%I\".\"%I\".\"%I\"', name_part (_p_name, 0), name_part (_p_name, 1), name_part (_p_name, 2)); \n"
"	  if (new_mode = 'ON') \n"
"	    { \n"
"	      if (isnull(update_interval)) return old_mode; \n"
"	      rc := exec ('insert replacing DB.DBA.SYS_SCHEDULED_EVENT (SE_NAME, SE_START, SE_INTERVAL, SE_SQL) values (?, curdatetime(), ?, ?)', \n"
"		      stat, msg, \n"
"		      vector ( \n"
"			 concat ('VT_INC_INDEX_', datatable, '()'), \n"
"			 update_interval, \n"
"			 concat (_p_name, '()')\n"
"		      )\n"
"		    );\n"
"	      if (rc <> 0) \n"
"		rc := exec ('update DB.DBA.SYS_SCHEDULED_EVENT set SE_SQL = ?, SE_START = curdatetime(), SE_INTERVAL = ? where SE_NAME = ?', \n"
"			stat, msg, \n"
"			vector ( \n"
"			   concat (_p_name, '()'), \n"
"			   update_interval, \n"
"			   concat ('VT_INC_INDEX_', datatable, '()')\n"
"			)\n"
"		      );\n"
"	      if (rc <> 0) \n"
"		signal (stat, concat ('Cannot create a scheduled event : ', msg), 'FT033'); \n"
"	    }\n"
"	  else \n"
"	    { \n"
"	      delete from DB.DBA.SYS_SCHEDULED_EVENT where SE_NAME = concat ('VT_INC_INDEX_', datatable, '()');\n"
"	      exec (concat (_p_name, '()'), stat, msg);"
"	    }\n"
"	}\n"
"    } \n"
"  else \n"
"    signal (\'22023\', \'The new mode should be ON or OFF \', \'FT019\'); \n"
"  return old_mode; \n"
"}";


#ifdef NEW_FTEXT_IN_SUBTABLES
static char *vt_find_index_text =
"create procedure vt_find_index (in orig_tb varchar, in col varchar)\n"
"{\n"
"  declare tb varchar;\n"
"  declare id, k1 integer;\n"
"  tb := orig_tb;\n"
"  declare _super varchar;\n"
"  declare _subid integer;\n"
"  declare _superid integer;\n"
"again:\n"
"  id := (select COL_ID from DB.DBA.SYS_COLS where 0 = casemode_strcmp (\"TABLE\", tb) and 0 = casemode_strcmp (\"COLUMN\" , col));\n"
"  if (id is null)\n"
"    {\n"
"      _subid := coalesce ((select KEY_ID from DB.DBA.SYS_KEYS where 0 = casemode_strcmp (KEY_TABLE, tb)), -1);\n"
"      _superid := coalesce ((select SUPER from DB.DBA.SYS_KEY_SUBKEY where SUB = _subid), -1);\n"
"      _super := coalesce ((select KEY_TABLE from DB.DBA.SYS_KEYS where KEY_ID = _superid), null);\n"
"      if (_super is not null)\n"
"        {\n"
"          tb := _super;\n"
"          goto again;\n"
"        }\n"
"      signal (\'42S22\', concat (\'No column \'\'\', col ,\'\'\' in table \'\'\', orig_tb, \'\'\'\'), \'FT020\');\n"
"    }\n"
"  k1 := (select KEY_ID from DB.DBA.SYS_KEYS, DB.DBA.SYS_KEY_PARTS  where 0 = casemode_strcmp (KEY_TABLE , tb) \n"
"	 and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null\n"
"	 and KP_KEY_ID = KEY_ID and KP_NTH = 0 and KP_COL = id);\n"
"  return k1;\n"
"}\n";
#else
static char *vt_find_index_text =
"create procedure vt_find_index (in tb varchar, in col varchar)\n"
"{\n"
"  declare id, k1 integer;\n"
"\n"
"  id := (select COL_ID from DB.DBA.SYS_COLS where 0 = casemode_strcmp (\"TABLE\", tb) and 0 = casemode_strcmp (\"COLUMN\" , col));\n"
"  if (id is null)\n"
"    signal (\'42S22\', \'No column\', \'FT020\');\n"
"  k1 := (select KEY_ID from DB.DBA.SYS_KEYS, DB.DBA.SYS_KEY_PARTS  where 0 = casemode_strcmp (KEY_TABLE , tb) \n"
"	 and KEY_IS_MAIN = 1 and KEY_MIGRATE_TO is null\n"
"	 and KP_KEY_ID = KEY_ID and KP_NTH = 0 and KP_COL = id);\n"
"  if (k1 is null) { \n"
"    k1 := (select KEY_ID from DB.DBA.SYS_KEYS, DB.DBA.SYS_KEY_PARTS  where 0 = casemode_strcmp (KEY_TABLE , tb) \n"
"	 and KEY_DECL_PARTS = 1 and KEY_MIGRATE_TO is null\n"
"	 and KP_KEY_ID = KEY_ID and KP_NTH = 0 and KP_COL = id);\n"
"  }\n"
"  return k1;\n"
"}\n";
#endif

static char *vt_create_text_index_text =
"create procedure vt_create_text_index (in tb varchar, in col varchar,\n"
"				       in use_id varchar, in is_xml integer, in defer_generation integer,"
"				      in obd any, in _func any, in _lang varchar := \'*ini*\', in _enc varchar := \'*ini*\', in silent int := 0)\n"
"{\n"
"  declare str, text_id_col, kn, vt_name, pk_suits, _colname, func, ufunc, vi_column, text_id_col_type varchar;\n"
"  declare _coldtp smallint;\n"
"  declare k_id, pk_used, pk_parts, is_bigint_id, is_int_id, is_part integer;\n"
"  if (_lang is null)\n"
"    _lang := '*ini*';\n"
"  if (_enc is null)\n"
"    _enc := '*ini*';\n"
/*"  dbg_obj_print (tb);"*/
/*"  tb := complete_table_name (fix_identifier_case (tb), 1);\n"*/
"  is_bigint_id := is_int_id := 0; \n"
"  tb := complete_table_name ((tb), 1);\n"
"  if (not exists (select 1 from DB.DBA.SYS_KEYS where 0 = casemode_strcmp (KEY_TABLE,  tb))) {\n"
"      signal (\'42S02\', sprintf (\'No table \\\'%s\\\' in create text index\', tb), \'FT021\');\n"
"  }\n"
"  if (exists (select 1 from DB.DBA.SYS_VT_INDEX where 0 = casemode_strcmp (VI_TABLE,  tb))) {\n"
"    if (is_xml = 2 or silent) \n"
"      return; \n"
"    else\n"
"      signal (\'42S01\', \'Only one text index allowed per table\', \'FT022\');\n"
"  }\n"
/*"  dbg_obj_print (obd);"*/
"  is_part := 0; \n"
"  if (sys_stat ('cl_run_local_only') <> 1 and exists (select 1 from DB.DBA.SYS_PARTITION where 0 = casemode_strcmp (PART_TABLE, tb))) \n"
"    is_part := 1; \n"
"  col := DB.DBA.col_check (tb, col);\n"
"\n"
"  func := null; ufunc := null; \n"
"  if (_func = 1) { \n"
"    func := coalesce ((select P_NAME from DB.DBA.SYS_PROCEDURES where 0 =  casemode_strcmp (P_NAME, sprintf ('%s_%s_INDEX_HOOK', tb, col))), NULL);\n "
"    if (func is null) \n"
"      func := __proc_exists (sprintf ('%s_%s_INDEX_HOOK', tb, col)); \n"
"    ufunc := coalesce ((select P_NAME from DB.DBA.SYS_PROCEDURES where 0 = casemode_strcmp (P_NAME, sprintf ('%s_%s_UNINDEX_HOOK', tb, col))), NULL);\n "
"    if (ufunc is null) \n"
"      ufunc := __proc_exists (sprintf ('%s_%s_UNINDEX_HOOK', tb, col)); \n"
"  } \n"
" \n"
"  if (_func = 1 and not defer_generation and (func is null or ufunc is null)) \n"
"    signal ('37000', 'Use NOT INSERT flag, because function hooks does not generated before text index creation.', 'FT023'); \n"
"  else if (_func = 1 and defer_generation and (func is null or ufunc is null)) \n"
"    { \n"
"      if (func is null)\n"
"	func := sprintf ('%s_%s_INDEX_HOOK', tb, col);\n"
"      if (ufunc is null)\n"
"	ufunc := sprintf ('%s_%s_UNINDEX_HOOK', tb, col);\n"
"    } \n"
""
"  if (use_id is not null)\n"
"    use_id := DB.DBA.col_check (tb, use_id);\n"
"  k_id := 0; \n"
"  pk_used := 1; pk_parts := 0;\n"
"  pk_suits := \'\'; \n"
"  declare cr cursor for  \n"
"      select  \n"
"	  sc.\"COLUMN\", \n"
"	  sc.\"COL_DTP\" \n"
"      from  \n"
"	  DB.DBA.SYS_KEYS k,  \n"
"	  DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS sc \n"
"      where  \n"
"	  0 = casemode_strcmp (k.KEY_TABLE, tb) and \n"
"	  __any_grants(k.KEY_TABLE) and \n"
"	  k.KEY_IS_MAIN = 1 and \n"
"	  k.KEY_MIGRATE_TO is NULL and \n"
"	  kp.KP_KEY_ID = k.KEY_ID and \n"
"	  kp.KP_NTH < k.KEY_DECL_PARTS and \n"
"	  sc.COL_ID = kp.KP_COL and \n"
"	  0 <> casemode_strcmp (sc.\"COLUMN\", \'_IDN\') \n"
"      order by \n"
"	  sc.COL_ID; \n"
"  whenever not found goto pk_check_done; \n"
"  open cr; \n"
"  while (1) \n"
"    { \n"
"      fetch cr into _colname, _coldtp; \n"
"      _colname := DB.DBA.repl_undot_name (_colname); \n"
"      if (isstring (use_id) and _colname = DB.DBA.repl_undot_name (use_id) and (dv_type_title (_coldtp) <> \'INTEGER\' and dv_type_title (_coldtp) <> \'BIGINT\')) \n"
"	signal (\'22023\', concat (\'the column \', use_id, \' is not an integer\'), \'FT024\'); \n"
"      if (k_id > 0) \n"
"	pk_suits := \'\'; \n"
"      else if (dv_type_title (_coldtp) = \'INTEGER\' or dv_type_title (_coldtp) = \'BIGINT\') \n"
"	pk_suits := _colname; \n"
"      pk_parts := pk_parts + 1; \n"
"    } \n"
"pk_check_done: \n"
"  close cr;  \n"
"  if (isarray (obd) and length (obd) > 0) {\n"
"    declare ix integer;\n"
"    declare coll varchar;\n"
"    ix := 0;\n"
"    while (ix < length (obd)) {\n"
"     coll := cast (aref (obd, ix) as varchar);\n"
"     aset (obd, ix, DB.DBA.col_check (tb, coll));\n"
/*"     if (not exists (select 1 from DB.DBA.SYS_COLS where 0 = casemode_strcmp (\"TABLE\", tb) "
"						and 0 = casemode_strcmp (\"COLUMN\", coll)))"
"	signal (\'FT001\', concat (\'Unknown column \', coll, \'  specified in off-band data list\')); \n"*/
"     ix := ix + 1;\n"
"    }\n"
"  }\n"
"  if (isstring (use_id))\n"
"    { \n"
"      text_id_col := use_id;\n"
/*"      text_id_col := fix_identifier_case (text_id_col); "*/
"      text_id_col := (text_id_col); \n"
"      k_id := DB.DBA.vt_find_index (tb, text_id_col);\n"
"      if (k_id is null)\n"
"	{\n"
"	  kn := concat (name_part (tb, 2), \'_\', col, \'_WORDS\');\n"
"	  str := sprintf ('create index \"%I\" on \"%I\".\"%I\".\"%I\" (\"%I\")', kn, name_part (tb, 0), name_part (tb, 1), name_part (tb, 2), text_id_col);\n"
"	  DB.DBA.execstr (str);\n"
"	  k_id := (select KEY_ID from DB.DBA.SYS_KEYS where 0 = casemode_strcmp (KEY_TABLE, tb) and 0 = casemode_strcmp (KEY_NAME, kn));\n"
"	}\n"
"      else\n"
"	{\n"
"	  kn := (select KEY_NAME from DB.DBA.SYS_KEYS where KEY_ID = k_id);\n"
"	}\n"
"    } \n"
"  else\n"
"    {\n"
"      if (length (pk_suits) > 0 and pk_parts = 1) \n"
"	{ \n"
"	  text_id_col := pk_suits; \n"
"	  k_id := DB.DBA.vt_find_index (tb, text_id_col);\n"
"	  if (k_id is null)\n"
"	    {\n"
"	      kn := concat (name_part (tb, 2), \'_\', col, \'_WORDS\');\n"
"	      str := sprintf ('create index %s on %s (%s)', kn, tb, text_id_col);\n"
"	      DB.DBA.execstr (str);\n"
"	      k_id := (select KEY_ID from DB.DBA.SYS_KEYS where 0 = casemode_strcmp (KEY_TABLE, tb) and 0 = casemode_strcmp (KEY_NAME, kn));\n"
"	    }\n"
"	  else\n"
"	    {\n"
"	      kn := (select KEY_NAME from DB.DBA.SYS_KEYS where KEY_ID = k_id);\n"
"	    }\n"
"	} \n"
"      else \n"
"	{ \n"
"	  if (is_part and sys_stat ('cl_run_local_only') = 0) \n"
"	    signal ('22023', 'Explicit with key is required on partitioned table.'); \n"
"	  k_id := NULL; \n"
"	  kn := NULL; \n"
"	  text_id_col := concat (col, \'_ID\');\n"
"	  DB.DBA.execstr (sprintf (\'ALTER TABLE \"%I\".\"%I\".\"%I\" ADD \"%I\" BIGINT\', name_part (tb, 0), name_part (tb, 1), name_part (tb, 2), text_id_col));\n"
"	  pk_used := null; \n"
"          if (is_part) { \n"
"	     declare cl_part, part_decl, index_cmd varchar; \n"
"	     part_decl := ''; \n"
"            cl_part := DB.DBA.VT_GET_CLUSTER (tb, tb); \n"
"            part_decl := sprintf (' PARTITION %S (\"%I\" int (0hexffff00))', cl_part, text_id_col); \n"
"	     kn := concat (name_part (tb, 2), \'_\', col, \'_WORDS\');\n"
"	     index_cmd := sprintf ('CREATE INDEX \"%I\" ON \"%I\".\"%I\".\"%I\" (\"%I\") %s', "
"		kn, name_part (tb, 0), name_part (tb, 1), name_part (tb, 2), text_id_col, part_decl);\n"
"	     DB.DBA.execstr (index_cmd);\n"
"	     k_id := (select KEY_ID from DB.DBA.SYS_KEYS where 0 = casemode_strcmp (KEY_TABLE, tb) and 0 = casemode_strcmp (KEY_NAME, kn));\n"
"          } \n"
"	} \n "
"    }\n"
"  vt_name := concat (tb, \'_\', col, \'_WORDS\');\n"
/*"  str := sprintf (\'create table \"%I\".\"%I\".\"%I\" (VT_WORD varchar, VT_D_ID any, VT_D_ID_2 any, VT_DATA varchar, VT_LONG_DATA long varchar, primary key (VT_WORD, VT_D_ID) not column)\',\n"*/
/* the PK can be bigint */
"  is_bigint_id := DB.DBA.col_of_type (tb, text_id_col, 247);\n"
"  is_int_id := DB.DBA.col_of_type (tb, text_id_col, 189); \n"
"  if (is_bigint_id = 0 and is_int_id = 0)"
"    signal (\'22023\', concat (\'the column \', text_id_col, \' is not an integer\'), \'FT024\'); \n"
"  text_id_col_type := case when is_bigint_id then \'BIGINT\' when is_int_id then \'INTEGER\' else \'ANY\' end;\n"
"  str := sprintf (\'create table \"%I\".\"%I\".\"%I\" (VT_WORD varchar, VT_D_ID %s, VT_D_ID_2 %s, VT_DATA varchar, VT_LONG_DATA long varchar, primary key (VT_WORD, VT_D_ID) not column)\',\n"
"  name_part (vt_name, 0), name_part (vt_name, 1), name_part (vt_name, 2), text_id_col_type, text_id_col_type);\n"
"  DB.DBA.execstr (str);\n"
"  if (is_part) { \n" /* cluster options */
"    declare cl_part, cl_col_opt varchar; \n"
"    cl_part := DB.DBA.VT_GET_CLUSTER (tb, kn); \n"
"    cl_col_opt := ''; \n"
"    if (isstring (text_id_col)) { \n"
"      cl_col_opt := DB.DBA.VT_GET_CLUSTER_COL_OPTS (tb, kn, text_id_col) ;\n"
"    } \n"
"    str := sprintf (\'ALTER INDEX \"%I\" on \"%I\".\"%I\".\"%I\" partition %s (VT_D_ID int %s)\', \n"
"    name_part (vt_name, 2),  name_part (vt_name, 0), name_part (vt_name, 1), name_part (vt_name, 2), cl_part, cl_col_opt); \n"
"    DB.DBA.execstr (str);\n"
"  } \n"
"  declare the_key_table varchar; \n"
"  for select KEY_TABLE from DB.DBA.SYS_KEYS where (k_id is not null and KEY_ID = k_id) or (k_id is null and KEY_TABLE = tb and KEY_ID = KEY_SUPER_ID)   do\n"
"    {\n"
/*"      dbg_obj_print (\'adding into sys_vt_index for\', KEY_TABLE); \n"*/
"      the_key_table := KEY_TABLE; \n"
"      if (kn is null) \n"
"	vi_column := null; \n"
"      else \n"
"	vi_column := name_part (kn, 2); \n"
"	insert into DB.DBA.SYS_VT_INDEX (VI_TABLE, VI_INDEX, VI_COL, VI_ID_COL, VI_INDEX_TABLE, VI_ID_IS_PK, VI_OFFBAND_COLS, VI_LANGUAGE, VI_ENCODING)\n"
"	  values (KEY_TABLE, vi_column, col, text_id_col, vt_name, pk_used, serialize (obd), _lang, _enc);\n"
"      __ddl_changed (KEY_TABLE);\n"
"    }\n"
"  DB.DBA.vt_free_text_proc_gen (tb, text_id_col, col, is_xml, obd, func, ufunc, _lang, _enc, is_part);\n"
"  DB.DBA.vt_create_update_log (tb, is_xml, defer_generation, obd, func, ufunc, _lang, _enc, 1, is_part); \n"
/*"  dbg_obj_print (\'after create_update_log, k_id=\', k_id, \' kn=\', kn); \n"*/
"  select VI_INDEX into kn from DB.DBA.SYS_VT_INDEX where VI_TABLE = tb; \n"
/*"  dbg_obj_print (\'after select, k_id=\', k_id, \' kn=\', kn); \n"
"  dbg_obj_print ('calling vt_index', the_key_table, name_part (kn, 2), col, text_id_col, vt_name); \n"*/
"  __vt_index (the_key_table, name_part (kn, 2), col, text_id_col, vt_name, obd, _lang, _enc); \n"
"}\n";


static char *wb_all_done_text =
"create procedure wb_all_done (inout wb any, out d_id integer, inout several_left integer)\n"
"{\n"
"  declare wst varchar;\n"
"  declare d_id_2 integer;\n"
"  declare inx integer;\n"
"  inx := 0;\n"
"  while (inx < length (wb))\n"
"    {\n"
"      if (isstring (wst := aref (wb, inx)))\n"
"	{\n"
"	  vt_word_string_ends (wst, d_id, d_id_2);\n"
"	  if (inx < length (wb) - 1)\n"
"	    several_left := 1;\n"
"	  else \n"
"	    several_left := 0;\n"
"	  return 0;\n"
"	}\n"
"      inx := inx + 1;\n"
"    }\n"
"  return 1;\n"
"}\n";

static char *vt_free_text_proc_gen_text =
"create procedure vt_free_text_proc_gen (\n"
"  in _data_table varchar,\n"
"  in _key_column varchar,\n"
"  in _data_column varchar,\n"
"  in is_xml integer,\n"
"  in obd any,\n"
"  in func varchar,\n"
"  in ufunc varchar,\n"
"  in _lang varchar,\n"
"  in _enc varchar,\n"
"  in is_part int := 0 \n"
"  )\n"
"{\n"
"  declare data_table, words_table, full_words_table, text_value, data_table_suffix, dav_cond, theuser, _type_col varchar;\n"
"  declare _flag_val integer;\n"
"  declare dbpref, dbpref1 varchar;\n"
"  declare _lang_enc_args varchar;\n"
"  theuser := user; \n"
"  if (theuser = 'dba') theuser := 'DBA'; \n"
/*"  _data_table := complete_table_name (fix_identifier_case (_data_table), 1);\n"*/
"  _data_table := complete_table_name ((_data_table), 1);\n"
"  data_table := name_part (_data_table, 2);\n"
"  data_table_suffix := concat (name_part (_data_table, 0), \'_\', name_part (_data_table, 1), \'_\', name_part (_data_table, 2));\n"
"  dbpref := sprintf ('\"%I\".\"%I\".',  name_part (_data_table, 0),  name_part (_data_table, 1));\n"
"  dbpref1 := sprintf ('%s.%s.',  name_part (_data_table, 0),  name_part (_data_table, 1));\n"
"  data_table_suffix := DB.DBA.SYS_ALFANUM_NAME (data_table_suffix);\n"
"  words_table := concat (data_table, \'_\', _data_column, \'_WORDS\');\n"
"  full_words_table := concat (_data_table, \'_\', _data_column, \'_WORDS\');\n"
"  if (0 = casemode_strcmp (data_table, \'SYS_DAV_RES\')) {\n"
"    dav_cond := \' and 0 = isnull (RES_TYPE) and lcase (subseq (RES_TYPE, 0, 4)) = \\\'text\\\'\n"
"		and subseq (RES_PERMS, 9, 10) <> \\\'N\\\' \';\n"
"    _type_col := \'RES_TYPE\';\n"
"    _flag_val := 2;\n"
" } else {\n"
"    dav_cond := \' \';\n"
"    _flag_val := 1;\n"
"    if (is_xml = 1)\n"
"      _type_col := \'\'\'text/xml\'\'\';\n"
"    else\n"
"      _type_col := \'\'\'text/plain\'\'\';\n"
" }\n"
"\n"
"  _lang_enc_args := concat (\', \\\'\', _lang, \'\\\', \\\'\', _enc, \'\\\'\');\n"
"  text_value := concat (\n"
"      sprintf (\n"
"	\'create procedure %s\"VT_NEXT_CHUNK_ID_%s\" (in word varchar, in d_id integer)\\\n\', dbpref, data_table_suffix),\n"
"	\'{\n"
"	   declare id any;\\\n\',\n"
"      sprintf (\n"
"       \'id := (select VT_D_ID from \"%I\".\"%I\".\"%I\" table option (no cluster) where VT_WORD = word and VT_D_ID > d_id);\\\n\', name_part (full_words_table,0), name_part (full_words_table,1), name_part (full_words_table,2)),\n"
"       \'if (d_id = id)\n"
"	   signal (\\\'42000\\\', \\\'id = id\\\', \\\'FT025\\\'); \n"
"	 return (coalesce (id, 0));\n"
"	  }\');\n"
"  DB.DBA.execstr (text_value);\n"
"\n"
"  text_value := concat (\n"
"      sprintf (\n"
"	\'create procedure %s\"VT_INSERT_1_%s\" (inout word varchar, inout wst varchar)\\\n\', dbpref, data_table_suffix),\n"
"	\'{\n"
"	   declare blob varchar;\n"
"	   declare id1, id2 integer;\n"
"	   vt_word_string_ends (wst, id1, id2); \n"
"	   blob := null;\n"
"	   if (length (wst) > 1900)\n"
"	     {\n"
"	       blob := wst;\n"
"	       wst := null;\n"
"	     }\n"
"	\\\n\',\n"
"      sprintf (\n"
"	  \'insert into \"%I\".\"%I\".\"%I\" option (no cluster) (VT_WORD, VT_D_ID, VT_D_ID_2, VT_DATA, VT_LONG_DATA)\n"
"	    values (word, id1, id2, wst, blob);\\\n\', name_part (full_words_table,0), name_part (full_words_table,1), name_part (full_words_table,2)),\n"
"	\'}\');\n"
"  DB.DBA.execstr (text_value);\n"
"\n"
"  text_value := concat (\n"
"      sprintf (\n"
"	\'create procedure %s\"VT_PROCESS_WORD_BATCH_%s\" (in word varchar, \\\n\' , dbpref, data_table_suffix),\n"
"	\'	in wb any) \n"
"	 {\n"
"	   declare d_id, next_id, id1, id2, several_left, inx, chunk_d_id  integer;\n"
"	   declare org_str, str1, strs, blob varchar;\n"
"	   declare cr cursor for \\\n\',\n"
"      sprintf (\n"
"	\'    select VT_D_ID, VT_DATA, VT_LONG_DATA  from \"%I\".\"%I\".\"%I\" TABLE OPTION (no cluster, INDEX PRIMARY KEY) where VT_WORD = word and VT_D_ID <= d_id\\\n\', name_part (full_words_table,0), name_part (full_words_table,1), name_part (full_words_table,2)), \n"
"	\'       order by VT_WORD desc, VT_D_ID desc for update; \n"
"  set isolation = ''serializable'';\n"
"	   while (0 = wb_all_done_bif (wb, d_id, several_left))\n"
"	     {\n"
"	       chunk_d_id := 0;\n"
"	       whenever not found goto first;\n"
"	       open cr;\n"
"	       fetch cr into chunk_d_id, org_str, blob;\n"
"	       if (org_str is null)\n"
"		 org_str := blob_to_string (blob);\n"
"	       goto ins;\n"
"	     first:  \n"
"	       org_str := \\\'\\\';\n"
"	     ins:\n"
"	       if (several_left)\n"
"		 {\n"
"		   if (org_str = \\\'\\\')\n"
"		     {\\\n\',\n"
"      sprintf (\n"
"       \'	     next_id := %s\"VT_NEXT_CHUNK_ID_%s\" (word, chunk_d_id);\\\n\', dbpref, data_table_suffix), \n"
"	\'	       \n"
"		     }\n"
"		   else\\\n\',\n"
"      sprintf (\n"
"	\'	      next_id := vt_words_next_d_id (\\\'%s\\\', \\\'<%s >\\\', word, d_id);\\\n\', full_words_table, full_words_table),\n"
"	\'	}\n"
"	       else\n"
"		 next_id := 0;\n"
"	       strs := wb_apply (org_str, wb, next_id,  1010 - (24 + length (word) + 2*(case when isinteger (d_id) then 5 else length (d_id) end)));\n"
"	       str1 := case when length (strs) > 0 then aref_set_0 (strs, 0) else \\\'\\\' end;\n"
"	       if (str1 <> org_str)\n"
"		 {\n"
"		   blob := null;\n"
"		   if (0 = length (str1))\\\n\',\n"
"      sprintf (\n"
"	\'	     delete from \"%I\".\"%I\".\"%I\" where current of cr option (no cluster);\\\n\', name_part (full_words_table,0), name_part (full_words_table,1), name_part (full_words_table,2)),\n"
"	\'	  else\n"
"		     {\n"
"		       vt_word_string_ends (str1, id1, id2);\n"
"		       if (length (str1) > 1900)\n"
"			 {\n"
"			   blob := str1;\n"
"			   str1 := null;\n"
"			 }\n"
"		       if (\\\'\\\' <> org_str)\n"
"			 {\n"
"			   \\\n\',\n"
"      sprintf (\n"
"	\'		   update \"%I\".\"%I\".\"%I\" set VT_D_ID = id1, VT_D_ID_2 = id2, VT_DATA = str1, VT_LONG_DATA = blob where current of cr option (no cluster);\\\n\', name_part (full_words_table,0), name_part (full_words_table,1), name_part (full_words_table,2)),\n"
"	\'		}\n"
"		       else\n"
"			 {\n"
"			   \\\n\',\n"
"     sprintf (\n"
"       \'		   insert into \"%I\".\"%I\".\"%I\" option (no cluster) (VT_WORD, VT_D_ID, VT_D_ID_2, VT_DATA, VT_LONG_DATA)\\\n\', name_part (full_words_table,0), name_part (full_words_table,1), name_part (full_words_table,2)),\n"
"       \'		      values (word, id1, id2, str1, blob);\n"
"			 }\n"
"		     }\n"
"		 }\n"
"	       inx := 1;\n"
"	       while (inx < length (strs))\n"
"		 {\\\n\',\n"
"     sprintf (\n"
"       \'	   %s\"VT_INSERT_1_%s\" (word, aref_set_0 (strs, inx));\\\n\', dbpref, data_table_suffix),\n"
"       \'\n"
"		   inx := inx + 1;\n"
"		   \n"
"		 }\n"
"	     }\n"
"	 }\\\n\');\n"
"  DB.DBA.execstr (text_value);\n"
"\n"
"  text_value := concat (\n"
"      sprintf (\n"
"	\'create procedure %s\"VT_BATCH_REAL_PROCESS_1_%s\" (in invd any, in doc_id int)\\\n\', dbpref, data_table_suffix),\n"
"	\'{\n\',"
"\'	   declare inx integer;\n"
"	   inx := 0;\n"
"	  if (__tag (invd) <> 193) return; \n"
"	   while (inx < length (invd))\n"
"	     {\\\n\',\n"
"      sprintf (\n"
"	\'      %s\"VT_PROCESS_WORD_BATCH_%s\" (aref_set_0 (invd, inx), aref_set_0 (invd, inx + 1)); \\\n\', dbpref, data_table_suffix),\n"
"	\'"
"	       inx := inx + 2;\n"
"	     }\n"
"	 }\');\n"
"  DB.DBA.execstr (text_value);\n"
"\n"
"  text_value := concat (\n"
"      sprintf (\n"
"	\'create procedure %s\"VT_BATCH_REAL_PROCESS_%s\" (inout invd any, in doc_id int, in in_batch int)\\\n\', dbpref, data_table_suffix),\n"
"	\'{\n\',"
"	case when is_part then "
"	   sprintf (\' if (0 = in_batch and 0 = sys_stat (\\\'cl_run_local_only\\\')) "
" 	         { \\\n %s\"VT_BATCH_REAL_PROCESS_CL_%s\" (invd, doc_id);\\\n return;\\\n }\', dbpref, data_table_suffix) "
"	   else \'\' end, \n"
"	   sprintf ( \'declare len, qp, clen, part, inx, enab int; len := length (invd) / 2; qp := sys_stat (''enable_qp''); enab := sys_stat (''enable_mt_ft_inx''); "
"		       if (0 = sys_stat (\\\'cl_run_local_only\\\') or enab = 0 or qp < 2 or len < 200) { %s\"VT_BATCH_REAL_PROCESS_1_%s\" (invd, doc_id); } "
"                      else { \\\n"
"			  declare aq any; \\\n"
"			  gvector_sort (invd, 2, 0, 1); \\\n"
"			  aq := async_queue (qp, 8);  clen := 2 * (len / qp); \\\n"
"			  for (inx := 0; inx < qp and (inx * qp) < len; inx := inx + 1) { \\\n"
"			     part := subseq (invd, clen * inx, clen * (inx + 1)); \\\n"
/*"			     dbg_obj_print ('' from '', clen * inx, '' to '', clen * (inx + 1) , '' part '' , length (part), '' len '', len); \\\n"*/
"			     aq_request (aq, ''%sVT_BATCH_REAL_PROCESS_1_%s'', vector (part, doc_id)); \\\n"
"			  } \\\n"
"			  aq_wait_all (aq); \\\n"
"                      }\', dbpref, data_table_suffix, dbpref1, data_table_suffix), \n"
" \'	 }\');\n"
"  DB.DBA.execstr (text_value);\n"
"\n"
"  text_value := concat (\n"
"      sprintf (\n"
"	\'create procedure %s\"VT_BATCH_REAL_PROCESS_CL_%s\" (inout invd any, in doc_id int)\\\n\', dbpref, data_table_suffix),\n"
"	\'{\n"
"	   declare daq any; \n"
"	  daq := daq (1); \', \n"
"      sprintf (\n"
"	 \'  daq_call (daq, \\\'%s.%s.%s\\\', \\\'%s\\\', \\\'%s.%s.VT_BATCH_REAL_PROCESS_1_%s\\\', vector (invd, doc_id), 1); \\\n\', name_part (full_words_table, 0), name_part (full_words_table,1), name_part (full_words_table,2), name_part (full_words_table,2), name_part (full_words_table, 0), name_part (full_words_table,1), data_table_suffix),\n"
"	 \'  DB.DBA.daq_results (daq); \n"
"	 }\');\n"
"  DB.DBA.execstr (text_value);\n"
"\n"
"  text_value := concat (\n"
"      sprintf (\n"
"	\'create procedure %s\"VT_BATCH_PROCESS_%s\" (inout vtb any, in doc_id int, in in_batch int := 0)\\\n\', dbpref, data_table_suffix),\n"
"	\'{\n{\n"
"	   declare invd any;\n"
"	   declare log_enable_ok integer;\n"
"	   invd := vt_batch_strings_array (vtb); \n"
"	   if (length (invd) < 1) return;\n"
"	   log_enable_ok := 0;\n"
"	   whenever sqlstate ''*'' goto recov;\\\n\',\n"
"	  sprintf (\'\"%I\".\"%I\".\"VT_HITS_%I\" (vtb, invd);\\\n\', name_part(_data_table,0),name_part(_data_table,1),name_part (_data_table,2)),\n"
"      sprintf (\n"
"	\'log_text (\\\'\"%I\".\"%I\".\"VT_BATCH_REAL_PROCESS_%I\" (?, ?, ?)\\\', invd, doc_id, in_batch); \\\n\', name_part(_data_table,0), name_part(_data_table,1), data_table_suffix),\n"
"	\'log_enable_ok := log_enable (0, 1); \\\n\', \n"
"      sprintf (\n "
"	\'%s\"VT_BATCH_REAL_PROCESS_%s\" (invd, doc_id, in_batch); \\\n\', dbpref, data_table_suffix),\n"
"	\'if (log_enable_ok)\n"
"	  log_enable (1);\n"
"	  return;\n\n"
"recov:\n"
"	if (log_enable_ok)\n"
"	  log_enable (1);\n}\n"
"	signal (__SQL_STATE, __SQL_MESSAGE);\n"
"	 }\');\n"
"  DB.DBA.execstr (text_value);\n"
"\n"
"  text_value := \n"
"	  sprintf (\'create procedure \"%I\".\"%I\".\"VT_HITS_%I\" (inout vtb any, inout invd any) {return;}\',\n"
"	  name_part(_data_table,0),name_part(_data_table,1),name_part (_data_table,2));\n"
"  DB.DBA.execstr (text_value);\n"
"\n"
"  declare ix integer;\n"
"  declare of_cols, of_vars, of_vars_decl, of_vtb, of_coll varchar;\n"
"  of_cols := \'\'; of_vars := \'\'; of_vtb:= \'\'; of_vars_decl := \'\'; ix := 0;\n"
"  if (isarray (obd) and length (obd) > 0) {\n"
"    of_vtb := \'vt_batch_feed_offband (vtb, serialize (vector (\';\n"
"    while (ix < length (obd)) {\n"
"      of_coll := cast (aref (obd, ix) as varchar);\n"
"      of_cols := concat (of_cols, \',\', of_coll);\n"
"      of_vars := concat (of_vars, \'_VAR_\', upper (DB.DBA.SYS_ALFANUM_NAME (of_coll)), \',\');\n"
"      ix := ix + 1;\n"
"    }\n"
"    of_vars := substring (of_vars, 1, length (of_vars) - 1);\n"
"    of_vtb := concat (of_vtb, of_vars, \')), 0);\');\n"
"    of_vars_decl := concat (\'declare \', of_vars, \' any;\');\n"
"    of_vars := concat (\',\', of_vars);\n"
"  }\n"
"  text_value := concat (\n"
"      sprintf (\n"
"	\'create procedure \"%I\".\"%I\".\"VT_INDEX_%I\" (in flag integer := 0, in start any := null, in end_id any := null, in low_w any := null, in high_w any := null)\\\n\', name_part (_data_table, 0) , name_part (_data_table, 1) , data_table_suffix),\n"
"	sprintf (\'{ \\\n"
"	    if (0 = %d) \\\n"
"	      \"%I\".\"%I\".\"VT_INDEX_1_%I\" (flag, start, end_id, low_w, high_w); \\\n"
"	    else \\\n"
"	      DB.DBA.CL_EXEC (\\\'\"%I\".\"%I\".\"VT_INDEX_1_%I\" (?, ?, ?, ?, ?)\\\', "
"				vector (flag, start, end_id, low_w, high_w)); \\\n"
"         } \', is_part, name_part (_data_table, 0) , name_part (_data_table, 1) , data_table_suffix, "
"               name_part (_data_table, 0) , name_part (_data_table, 1) , data_table_suffix) ); \n"
"  DB.DBA.execstr (text_value);\n"
"  text_value := concat (\n"
"      sprintf (\n"
"	\'create procedure \"%I\".\"%I\".\"VT_INDEX_1_%I\" (in flag integer := 0, in start any := null, in end_id any := null, in low_w any := null, in high_w any := null)\\\n\', name_part (_data_table, 0) , name_part (_data_table, 1) , data_table_suffix),\n"
"	\'{\n"
"	   declare vtb any; \\\n\',\n"
"      sprintf (\n"
"	\'  declare cr cursor for select \"%I\", \"%I\", %s %s from \"%I\".\"%I\".\"%I\" table option (no cluster) where \"%I\" > start %s order by \"%I\";\\\n\', _key_column, _data_column, _type_col, of_cols , name_part (_data_table, 0), name_part (_data_table, 1), name_part (_data_table, 2), _key_column, dav_cond, _key_column),\n"
"      sprintf (\n"
"	\'  if (start is null) { start := (select top 1 \"%I\" from \"%I\".\"%I\".\"%I\" table option (no cluster)); start := case when start is null then 0 when __tag (start) = 255 then composite (\'\'\'\') else 0 end; }\\\n\', _key_column, name_part (_data_table,0), name_part (_data_table,1), name_part (_data_table,2)),\n"
"	\'  whenever not found goto done;\n"
"	    whenever sqlstate \\\'40001\\\' goto deadl;\n"
"	   \n"
"  do_next_after_deadl:;\n\', \n"
"      sprintf (\n"
"	\'   vtb := vt_batch (8191 %s);\n\', _lang_enc_args ),\n"
"	\'   vt_batch_alpha_range (vtb, low_w, high_w); \n"
"	  declare max_len integer; "
"	   max_len := sys_stat (\\\'vt_batch_size_limit\\\');\n"
"	   while (1)\n"
"	     {\n"
"	       declare len integer;\n"
"	       declare _vt_id_ integer;\n"
"	      len := 0;\n"
"	       open cr;\n"
"	       while (len < max_len)\n"
"		 {\n"
"		   declare data, _type varchar;\n"
/*"		   declare blob_size integer; \n"*/
"		  <OFF_DATA_VARS_DECL> \n"
"		   fetch cr into _vt_id_, data, _type <OFF_DATA_VARS>; \n"
"		  if (end_id is not null and _vt_id_ > end_id) goto done; \n', \n"
"	either (matches_like (_data_table, \'DB.DBA.NEWS_MSG\'), \n"
"	      \'  data := DB.DBA.ns_make_index_content (data, 1); \', \'\'), \n"
/*"	      \'  blob_size := length (data);\n"*/
"	      \'  \n"
"		  vt_batch_d_id (vtb, _vt_id_);\n"
/*"		       dbg_obj_print (_vt_id_);\n"
"		      declare gogo any;\n"
"		      select nm_id into gogo from news_msg where nm_body_id = _vt_id_;\n"
"		       dbg_obj_print (\\\'ID=\\\', gogo);\n"*/
"		 declare to_process integer; \n to_process := 1;\n"
"		 if (not flag and <FN_IDX_HOOK_I>) \n to_process := 0; \n"
"		 if (flag and <FN_IDX_HOOK_D>) \n to_process := 0; \n"
"		  if (not isnull(data) and to_process) \n"
"		    { \n"
"		      if (lcase (_type) = \\\'text/xml\\\') \\\n \' , \n"
"		sprintf (\n"
"		 \'	vt_batch_feed (vtb, data, flag, %d);\\\n\', _flag_val) , \n"
"		\'      else \n"
"			  vt_batch_feed (vtb, data, flag);\n"
"		      if (low_w is null) { \\\n"
"		       <VTB_OFF_DATA_FEED>\n"
"			 ; \n"
"			} \n"
/*"		      len := len + blob_size; \n"*/
/*"		   dbg_obj_print (\\\'calculated len: \\\', len, \\\' words len: \\\', vt_batch_words_length (vtb));"*/
"		    } \n"
"		   len := len + vt_batch_words_length (vtb); \n"
"		 }\n"
"	       \\\n\',\n"
"      sprintf (\n"
"	\'      %s\"VT_BATCH_PROCESS_%I\" (vtb, _vt_id_, 1);\\\n\', dbpref, data_table_suffix),\n"
"      sprintf (\n"
"	\'   vtb := vt_batch (8191 %s);\n\', _lang_enc_args ),\n"
"	\'   vt_batch_alpha_range (vtb, low_w, high_w); \n"
"	       commit work;\n start := _vt_id_;\n"
"	     }\n"
"	 done:\\\n\',\n"
"      sprintf (\n"
"	\'  %s\"VT_BATCH_PROCESS_%I\" (vtb, start, 1);\\\n\', dbpref, data_table_suffix),\n"
"	\'  return;\n"
" deadl: \n"
"   close cr;\n"
"   rollback work;\n"
/*"   dbg_obj_print (\\\'deadlock > begin from: \\\', start); \n"*/
"   goto do_next_after_deadl;\n"
"	 }\'"
"    );\n"
"  text_value := replace (text_value, \'<OFF_DATA_VARS_DECL>\', of_vars_decl);\n"
"  text_value := replace (text_value, \'<OFF_DATA_VARS>\', of_vars);\n"
"  text_value := replace (text_value, \'<VTB_OFF_DATA_FEED>\', of_vtb);\n"
""
"  declare fn_idx_hook_i, fn_idx_hook_d varchar;"
"  fn_idx_hook_i := '(1 <> 1)';\n"
"  fn_idx_hook_d := '(1 <> 1)';\n"
"  if (func is not null) "
"    fn_idx_hook_i := sprintf ('\"%I\".\"%I\".\"%I\" (vtb, _vt_id_)', name_part (func,0), name_part (func,1), name_part (func,2));"
""
"  if (ufunc is not null) "
"    fn_idx_hook_d := sprintf ('\"%I\".\"%I\".\"%I\" (vtb, _vt_id_)', name_part (ufunc,0), name_part (ufunc,1), name_part (ufunc,2));"
""
"  text_value := replace (text_value, \'<FN_IDX_HOOK_I>\', fn_idx_hook_i);\n"
"  text_value := replace (text_value, \'<FN_IDX_HOOK_D>\', fn_idx_hook_d);\n"

"  DB.DBA.execstr (text_value);\n"
"}\n";


/*XXX: this wrapper is needed due to existing old type indexes
       and because iscompr is taken out from new definition  */
static char *vt_get_gz_wordump_ex_text_0 =
" create procedure vt_get_gz_wordump_ex (in comprdata varchar, \n"
"                                        in textdata varchar, \n"
" 				       in iscompr any, \n"
" 				       in feed_flags any, \n"
" 				       in fn any := NULL, \n"
" 				       in id any := 0, \n"
" 				       in _lang varchar := \'*ini*\', \n"
" 				       in _enc varchar := \'*ini*\') \n"
" { \n"
"   if (isinteger (iscompr) and isinteger (feed_flags)) \n"
"     { \n"
/*"       dbg_obj_print (\'Old type caller : \', feed_flags, fn, id, _lang, _enc); \n"*/
"       return DB.DBA.vt_get_gz_wordump_ex_1 (comprdata, textdata, feed_flags, fn, id, _lang, _enc); \n"
"     } \n"
"   else \n"
"     { \n"
/*"       dbg_obj_print (\'New type caller : \', iscompr, feed_flags, fn, id, _lang); \n"*/
"       return DB.DBA.vt_get_gz_wordump_ex_1 (comprdata, textdata, iscompr, feed_flags, fn, id, _lang); \n"
"     } \n"
" } \n";

static char *vt_get_gz_wordump_ex_text =
"create procedure vt_get_gz_wordump_ex_1 (in comprdata varchar, in textdata varchar, in feed_flags integer,\n"
"					in fn any, in id any,\n"
"					in _lang varchar := \'*ini*\', in _enc varchar := \'*ini*\') \n"
"{ \n"
"  declare vtb any;\n"
"  declare i, len integer; \n"
"  declare ses any; \n"
"  \n"
"  ses := null; \n"
"  if (comprdata is not null) \n"
"    { \n"
"      ses := string_output(); \n"
"      gz_uncompress (blob_to_string (comprdata), ses); \n"
"      comprdata := string_output_string (ses); \n"
"      ses := null; \n"
"    } \n"
"  if (textdata is null and comprdata is null) \n"
"    return textdata; \n"
"  vtb := vt_batch(1001, _lang, _enc); \n"
"  if (fn is null or (fn is not null and not call (fn) (vtb, id))) {\n"
"     if (textdata is not null and '' <> textdata) \n"
"	vt_batch_feed (vtb, textdata, 1, feed_flags); -- word positions not needed, so like del.\n"
"     if (comprdata is not null and '' <> comprdata) \n"
"	vt_batch_feed_wordump (vtb, comprdata, 1); -- word positions not needed, so like del.\n"
"   }\n"
"  ses := string_output(); \n"
"  vt_batch_wordump (vtb, ses); \n"
"  vtb := null; \n"
"  return gz_compress (string_output_string (ses)); \n"
"} ";

static char *vt_create_update_log_text =
"create procedure vt_create_update_log (\n"
"  in tablename varchar,\n"
"  in is_xml integer,\n"
"  in defer_generation integer,\n"
"  in ofbd any,\n"
"  in func varchar,\n"
"  in ufunc varchar,\n"
"  in _lang varchar,\n"
"  in _enc varchar,\n"
"  in create_log_tb integer := 1,\n"
"  in is_part int := 0 \n"
"  ) "
"{ "
"  declare commands, command any; "
"  declare inx, _dav_flag, is_pk, is_bigint_id, is_int_id integer; "
"  declare datacol, keycol, pk_col_cond, pk_col_vars, pk_col_assign varchar; "
"  declare DAV_indexing_condition, DAV_indexing_condition_O, DAV_indexing_condition_N, DAV_update_cols varchar; "
"  declare IS_XML_cond, IS_O_XML_cond, IS_N_XML_cond, DAV_upd_cond varchar; "
"  declare IS_DAV_cond, IS_XML_PR_cond, TYPE_col, TYPE_var, IS_NEWS_MSG_cond varchar;"
"  declare of_vtb, of_vtb_o, of_vtb_n, of_vtb_d, of_cols, of_cols_d, of_cols_o, of_vars, of_vars_decl, of_inc_vtb varchar;"
"  declare tb_suff, vtlog_suff, id_col_type, key_name, cl_part, cl_opts varchar;"
"  declare _lang_enc_args varchar;"
/*"  tablename := complete_table_name (fix_identifier_case (tablename), 1); "*/
"  tablename := complete_table_name ((tablename), 1); "
"  vtlog_suff := concat (name_part (tablename, 0), \'_\', name_part (tablename, 1), \'_\', name_part (tablename, 2));\n"
"  tb_suff := DB.DBA.SYS_ALFANUM_NAME (vtlog_suff);\n"
"  of_vtb := \'\'; of_vtb_o := \'\'; of_vtb_n := \'\'; of_vtb_d := \'\';"
"  of_cols := \'\'; of_vars := \'\'; of_vars_decl := \'\'; of_inc_vtb := \'\';"
"  of_cols_o := \'null\'; of_cols_d := \'null\';"
"  is_bigint_id := is_int_id := 0;\n"
"  if (isarray (ofbd) and length (ofbd) > 0) {"
"   declare ix integer;"
"   declare ofcol varchar;"
"   ix := 0;"
"   of_cols_o := \'\'; of_cols_d := \'\';"
"   of_vtb := \'vt_batch_feed_offband ( vtb, serialize (vector (\';"
"   of_vtb_d := \'vt_batch_feed_offband ( vtb, serialize (vector (\';"
"   of_vtb_o := \'vt_batch_feed_offband ( vtb, serialize (vector (\';"
"   of_vtb_n := \'vt_batch_feed_offband ( vtb, serialize (vector (\';"
"   while (ix < length (ofbd)) {"
"    ofcol := cast (aref (ofbd, ix) as varchar);"
"    of_vtb := concat (of_vtb, \'\"\', ofcol, \'\",\');"
"    of_vtb_d := concat (of_vtb_d, \'\"\', ofcol, \'\",\');"
"    of_vtb_o := concat (of_vtb_o, \'O.\"\', ofcol, \'\",\');"
"    of_vtb_n := concat (of_vtb_n, \'N.\"\', ofcol, \'\",\');"
"    of_cols := concat (of_cols, \',\"\', ofcol,\'\" \');"
"    of_vars := concat (of_vars, \'_VAR_\', upper(DB.DBA.SYS_ALFANUM_NAME(ofcol)),\', \');"
"    of_cols_d := concat (of_cols_d, \'\"\', ofcol, \'\",\');"
"    of_cols_o := concat (of_cols_o, \'O.\"\', ofcol, \'\",\');"
/*"    of_cols_n := concat (of_cols_n, \'N.\"\', ofcol, \'\",\');"*/
"    ix := ix + 1;"
"   }"
"    of_vtb   := concat (substring(of_vtb,   1, length (of_vtb)   - 1), \')), 0);\');"
"    of_vtb_d   := concat (substring(of_vtb_d,   1, length (of_vtb_d)   - 1), \')), 1);\');"
"    of_vtb_o := concat (substring(of_vtb_o, 1, length (of_vtb_o) - 1), \')), 1);\');"
"    of_vtb_n := concat (substring(of_vtb_n, 1, length (of_vtb_n) - 1), \')), 0);\');"
"    of_vars := substring(of_vars, 1, length (of_vars) - 2);"
"    of_vars_decl := concat (\'declare \', of_vars, \' any;\');"
"    of_inc_vtb := concat (\'vt_batch_feed_offband (vtb, serialize (vector (\', of_vars,\')), 0);\');"
"    of_vars := concat (\', \', of_vars);"
"    of_cols_d := concat (\'serialize (vector(\', substring (of_cols_d,1,length (of_cols_d)-1),\'))\');"
"    of_cols_o := concat (\'serialize (vector(\', substring (of_cols_o,1,length (of_cols_o)-1),\'))\');"
/*"    of_cols_n := concat (\'serialize (vector(\', substring (of_cols_n,1,length (of_cols_n)-1),\'))\');"*/
"  }"
"  if (0 = casemode_strcmp (tablename, \'WS.WS.SYS_DAV_RES\')) "
"    { "
"      DAV_indexing_condition := \'isnull (RES_TYPE) or lcase (subseq (RES_TYPE, 0, 4)) <> \\\'text\\\'"
"		or length (RES_PERMS) < 10 or subseq (RES_PERMS, 9, 10) = \\\'N\\\' \'; "
"      DAV_indexing_condition_O := \'isnull (O.RES_TYPE) or lcase (subseq (O.RES_TYPE, 0, 4)) <> \\\'text\\\'"
"		or length (O.RES_PERMS) < 10 or subseq (O.RES_PERMS, 9, 10) = \\\'N\\\' \'; "
"      DAV_indexing_condition_N := \'isnull (N.RES_TYPE) or lcase (subseq (N.RES_TYPE, 0, 4)) <> \\\'text\\\'"
"		or length (N.RES_PERMS) < 10 or subseq (N.RES_PERMS, 9, 10) = \\\'N\\\' \'; \n"
"      DAV_update_cols := \', RES_TYPE, RES_PERMS\'; \n"
"      IS_O_XML_cond := \' not (isnull (O.RES_TYPE)) and lcase (O.RES_TYPE) = \\\'text/xml\\\' \';"
"      IS_N_XML_cond := \' not (isnull (N.RES_TYPE)) and lcase (N.RES_TYPE) = \\\'text/xml\\\' \';"
"      IS_XML_cond := \' not (isnull (RES_TYPE)) and lcase (RES_TYPE) = \\\'text/xml\\\' \';"
"      IS_DAV_cond := \'1 = 1\';"
"      IS_XML_PR_cond := \'1 <> 1\';"
"      TYPE_col := \'RES_TYPE, \';"
"      TYPE_var := \'dav_res_type, \';"
"      _dav_flag := 2;"
"      DAV_upd_cond := \'aref (O.RES_PERMS, 9) <> 78 and aref (N.RES_PERMS, 9) <> 78 and O.RES_PERMS <> N.RES_PERMS\';"
"    } "
"  else "
"    { "
"      DAV_indexing_condition := \'1 <> 1\';"
"      DAV_indexing_condition_N := \'1 <> 1\';"
"      DAV_indexing_condition_O := \'1 <> 1\';"
"      DAV_upd_cond := \'1 <> 1\';"
"      DAV_update_cols := \'\'; \n"
"      if (is_xml = 1)"
"	IS_XML_cond := \'1 = 1\';"
"      else "
"	IS_XML_cond := \'1 <> 1\';"
"      IS_O_XML_cond := IS_XML_cond;"
"      IS_N_XML_cond := IS_XML_cond;"
"      IS_DAV_cond := \'1 <> 1\';"
"      IS_XML_PR_cond := IS_XML_cond;"
"      TYPE_col := \'\';"
"      TYPE_var := \'\';"
"      _dav_flag := 1;"
"    } "
"  if (is_xml = 0)"
"    _dav_flag := 0;"
"  if (0 = casemode_strcmp (tablename, \'DB.DBA.NEWS_MSG\')) \n"
"    { \n"
"      IS_NEWS_MSG_cond := \'1\';"
"    } \n"
"  else \n"
"    { \n"
"      IS_NEWS_MSG_cond := \'0\';"
"    } \n"
"  declare cr_pk cursor for select  \n"
"      sc.\"COLUMN\" \n"
"  from  \n"
"      DB.DBA.SYS_KEYS k,  \n"
"      DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS sc \n"
"  where  \n"
"      0 = casemode_strcmp (k.KEY_TABLE, tablename) and \n"
"      __any_grants(k.KEY_TABLE) and \n"
"      k.KEY_IS_MAIN = 1 and \n"
"      k.KEY_MIGRATE_TO is NULL and \n"
"      kp.KP_KEY_ID = k.KEY_ID and \n"
"      kp.KP_NTH < k.KEY_DECL_PARTS and \n"
"      sc.COL_ID = kp.KP_COL and \n"
"      0 <> casemode_strcmp (sc.\"COLUMN\", \'_IDN\') \n"
"  order by \n"
"      sc.COL_ID; \n"
"  whenever not found goto pk_done; "
"  open cr_pk; "
"  pk_col_vars := \'\'; "
"  pk_col_cond := \'\'; "
"  pk_col_assign := \'\'; "
"  while (1) "
"   { "
"     declare _col_name varchar; "
"     fetch cr_pk into _col_name; \n"
"     _col_name := DB.DBA.repl_undot_name(_col_name); \n"
"     if (length (pk_col_vars) > 0) "
"       { "
"	 pk_col_vars := concat (pk_col_vars, \' , \'); "
"	 pk_col_cond := concat (pk_col_cond, \' and \'); "
"	 pk_col_assign := concat (pk_col_assign, \' ; \'); "
"       } "
"     pk_col_vars := concat (pk_col_vars, \'_var_\', _col_name); "
"     pk_col_cond := concat (pk_col_cond, _col_name, \' = _var_\', _col_name); "
"     pk_col_assign := concat (pk_col_assign, \'_var_\', _col_name, \' := \', _col_name); "
"   } "
" pk_done: "
"  close cr_pk; "
"  if (length (pk_col_vars) = 0) "
"    { "
"      pk_col_vars := \'_var_idn\'; "
"      pk_col_cond := \'\\\"_IDN\\\" = _var_idn\'; "
"      pk_col_assign := \'_var_idn := \\\"_IDN\\\"\'; "
"    } "
"  "
"  datacol := null;"
"  whenever not found default;"
"  select VI_COL, VI_ID_COL, VI_ID_IS_PK, VI_INDEX into datacol, keycol, is_pk, key_name from DB.DBA.SYS_VT_INDEX where VI_TABLE = tablename; "
"  if (datacol is null)"
"    signal ('42000','Misc. error upon update log creation. The free text index cannot be created.', 'FT026');"
"  is_bigint_id := DB.DBA.col_of_type (tablename, keycol, 247); \n"
"  is_int_id := DB.DBA.col_of_type (tablename, keycol, 189); \n"
"  id_col_type := case when is_bigint_id then \'BIGINT\' when is_int_id then \'INTEGER\' else \'ANY\' end;\n"
"  _lang_enc_args := concat (\', \\\'\', _lang, \'\\\', \\\'\', _enc, \'\\\'\');\n"
"  cl_part := DB.DBA.VT_GET_CLUSTER (tablename, key_name); \n"
"  cl_opts := DB.DBA.VT_GET_CLUSTER_COL_OPTS (tablename, key_name, keycol); \n"
"  commands := vector ( "
/* KFU_TYPE is the type of PK, can be bigint */
"      case when create_log_tb then \'create table <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" (\"VTLOG_<KFU>\" <KFU_TYPE> not null primary key (not column), SNAPTIME datetime, DMLTYPE varchar (1), VT_GZ_WORDUMP long varbinary, VT_OFFBAND_DATA long varchar)\\\n\' else NULL end, "
"      case when is_part then \'ALTER INDEX \"VTLOG_<VTLOGSUFF>\" on <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" partition <CL_PART> (\"VTLOG_<KFU>\" <KFU_TYPE> <CL_OPTS>)\' else NULL end,"
"	either (isnull (is_pk), "
"	 \'create trigger \"<SUFF>_VTI_log\" after insert on <DB>.<DBA>.<TB>  ORDER 2 { \\\n"
"	     declare _dmltype, _kf varchar; \\\n"
"	     declare <PK_COL_VARS> any; \\\n"
"	     <PK_COL_ASSIGN>; \\\n"
"	     set triggers off; \\\n"
"	     _kf := sequence_next (\\\'VTLOG_<SUFF>\\\'); \\\n"
"	     update <DB>.<DBA>.<TB> set <KF> = _kf where <PK_COL_COND>; \\\n"
"	     \\\n"
"	     if (<DAV_indexing_condition>) return;\\\n"
"	     declare vtb any; \\\n"
"	     vtb := vt_batch(1001 <LANG_ENC>); \\\n"
"	     vt_batch_d_id (vtb, _kf); \\\n"
"	     whenever SQLSTATE \\\'22007\\\' goto do_the_rollback; \\\n"
"	     if (registry_get (\\\'DELAY_UPDATE_<SUFF>\\\') <> \\\'ON\\\') \\\n"
"	       { \\\n"
"		 if (<FN_HOOK_I>) { \\\n"
"		       <DB>.<DBA>.\"VT_BATCH_PROCESS_<SUFF>\" (vtb, _kf); \\\n"
"		     } \\\n"
"		 else if (not isnull (<DF>)) \\\n"
"		   { \\\n"
"		       if (<IS_XML>) { \\\n"
"			 if (<IS_NEWS_MSG>) \\\n"
"			    vt_batch_feed (vtb, DB.DBA.ns_make_index_content (<DF>,<IS_NEWS_MSG>), 0, <FLAG_VAL>); \\\n"
"			 else \\\n"
"			    vt_batch_feed (vtb,<DF>, 0, <FLAG_VAL>) ; \\\n"
"			 } \\\n"
"		       else { \\\n"
"			 if (<IS_NEWS_MSG>) \\\n"
"			   vt_batch_feed (vtb, DB.DBA.ns_make_index_content (<DF>,<IS_NEWS_MSG>), 0); \\\n"
"			 else \\\n"
"			   vt_batch_feed (vtb, <DF>, 0); \\\n"
"		       } \\\n"
"		      <VTB_OFF_DATA_I> \\\n"
"		     <DB>.<DBA>.\"VT_BATCH_PROCESS_<SUFF>\" (vtb, _kf); \\\n"
"		   } \\\n"
"		 return; \\\n"
"	       } \\\n"
"	     else \\\n"
"	       if (<IS_XML>) { \\\n"
"		 if (<IS_NEWS_MSG>) \\\n"
"		   vt_batch_feed (vtb, DB.DBA.ns_make_index_content (<DF>,<IS_NEWS_MSG>), 0, <FLAG_VAL> + 128); \\\n"
"		 else \\\n"
"		   vt_batch_feed (vtb, <DF>, 0, <FLAG_VAL> + 128); \\\n"
"		  }; \\\n"
"	     declare cr cursor for select DMLTYPE from <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" where \"VTLOG_<KFU>\" = _kf; \\\n"
"	     whenever not found goto insert_dest; \\\n"
"	     open cr (exclusive, prefetch 1); fetch cr into _dmltype; \\\n"
"	     update <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" set DMLTYPE = \\\'I\\\', SNAPTIME = now() where current of cr; \\\n"
"	     close cr; return; \\\n"
"	    insert_dest: \\\n"
"	     close cr; \\\n"
"	     insert into <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" (\"VTLOG_<KFU>\", SNAPTIME, DMLTYPE, VT_GZ_WORDUMP, VT_OFFBAND_DATA) values (_kf, now(), \\\'I\\\', NULL, NULL); \\\n"
"	     return; \\\n"
"	    do_the_rollback: \\\n"
"	     txn_error (6); \\\n"
"	     signal (\\\'22008\\\', \\\'Invalid XML supplied for an validating free text index of <DB>.<DBA>.<TB>:\\\n\\\' || __SQL_MESSAGE, \\\'FT027\\\'); \\\n"
"	  }\', "
"	 \'create trigger \"<SUFF>_VTI_log\" after insert on <DB>.<DBA>.<TB>  ORDER 2 { \\\n"
"	     declare _dmltype varchar; \\\n"
"	     if (<DAV_indexing_condition>) return; \\\n"
"	     declare vtb any; \\\n"
"	     vtb := vt_batch(1001 <LANG_ENC>); \\\n"
"	     vt_batch_d_id (vtb, <KF>); \\\n"
"	     whenever SQLSTATE \\\'22007\\\' goto do_the_rollback; \\\n"
"	     if (registry_get (\\\'DELAY_UPDATE_<SUFF>\\\') <> \\\'ON\\\') \\\n"
"	       { \\\n"
"		 if (<FN_HOOK_I>) { \\\n"
"		     <DB>.<DBA>.\"VT_BATCH_PROCESS_<SUFF>\" (vtb, <KF>); \\\n"
"		   } \\\n"
"		 else if (not isnull (<DF>)) \\\n"
"		   { \\\n"
"		       if (<IS_XML>) {"
"			 if (<IS_NEWS_MSG>) vt_batch_feed (vtb, DB.DBA.ns_make_index_content (<DF>,<IS_NEWS_MSG>), 0, <FLAG_VAL>); else vt_batch_feed (vtb, <DF>, 0, <FLAG_VAL>); }\\\n"
"		       else {"
"			 if (<IS_NEWS_MSG>) vt_batch_feed (vtb, DB.DBA.ns_make_index_content (<DF>,<IS_NEWS_MSG>), 0); else vt_batch_feed (vtb, <DF>, 0); };\\\n"
"		       <VTB_OFF_DATA_I>\\\n"
"		     <DB>.<DBA>.\"VT_BATCH_PROCESS_<SUFF>\" (vtb, <KF>); \\\n"
"		   } \\\n"
"		 return; \\\n"
"	       } \\\n"
"	     else \\\n"
"	       if (<IS_XML>) { \\\n"
"		 if (<IS_NEWS_MSG>) vt_batch_feed (vtb, DB.DBA.ns_make_index_content (<DF>,<IS_NEWS_MSG>), 0, <FLAG_VAL> + 128); else vt_batch_feed (vtb, <DF>, 0, <FLAG_VAL> + 128); };\\\n"
"	     declare cr cursor for select DMLTYPE from <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" where \"VTLOG_<KFU>\" = <KF>; \\\n"
"	     whenever not found goto insert_dest; \\\n"
"	     open cr (exclusive, prefetch 1); fetch cr into _dmltype; \\\n"
"	     update <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" set DMLTYPE = \\\'I\\\', SNAPTIME = now() where current of cr;\\\n "
"	     close cr; return; \\\n"
"	    insert_dest: \\\n"
"	     close cr; \\\n"
"	     insert into <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" (\"VTLOG_<KFU>\", SNAPTIME, DMLTYPE, VT_GZ_WORDUMP, VT_OFFBAND_DATA) values (<KF>, now(), \\\'I\\\', NULL, NULL); \\\n"
"	     return; \\\n"
"	    do_the_rollback: \\\n"
"	     txn_error (6); \\\n"
"	     signal (\\\'22008\\\', \\\'Invalid XML supplied for an validating free text index of <DB>.<DBA>.<TB>:\\\n\\\' || __SQL_MESSAGE, \\\'FT028\\\'); \\\n"
"	  }\' ), "
"      \'create trigger \"<SUFF>_VTD_log\" before delete on <DB>.<DBA>.<TB>  ORDER 2 { \\\n"
"	  declare _gz_wordump varchar; \\\n"
"	  if (<DAV_indexing_condition>) return; \\\n"
"	  declare vtb any; \\\n"
"	  vtb := vt_batch(1001 <LANG_ENC>); \\\n"
"	  vt_batch_d_id (vtb, <KF>); \\\n"
"	  if (registry_get (\\\'DELAY_UPDATE_<SUFF>\\\') <> \\\'ON\\\') \\\n"
"	    { \\\n"
"	     if (<FN_HOOK_D>) { \\\n"
"		  <DB>.<DBA>.\"VT_BATCH_PROCESS_<SUFF>\" (vtb, <KF>); \\\n"
"	       } \\\n"
"	      else if (not isnull (<DF>)) \\\n"
"		{ \\\n"
"		    if (<IS_XML>) {"
"		      if (<IS_NEWS_MSG>) vt_batch_feed (vtb, DB.DBA.ns_make_index_content (<DF>,<IS_NEWS_MSG>), 1, <FLAG_VAL>); else vt_batch_feed (vtb, <DF>, 1, <FLAG_VAL>); }\\\n"
"		    else {"
"		      if (<IS_NEWS_MSG>) vt_batch_feed (vtb, DB.DBA.ns_make_index_content (<DF>,<IS_NEWS_MSG>), 1); else vt_batch_feed (vtb, <DF>, 1); };\\\n"
"		    <VTB_OFF_DATA_D>\\\n"
"		  <DB>.<DBA>.\"VT_BATCH_PROCESS_<SUFF>\" (vtb, <KF>); \\\n"
"		} \\\n"
"	      return; \\\n"
"	    } \\\n"
"	     else \\\n"
"	       if (<IS_XML>) {\\\n"
"		 if (<IS_NEWS_MSG>) vt_batch_feed (vtb, DB.DBA.ns_make_index_content (<DF>,<IS_NEWS_MSG>), 0, <FLAG_VAL> + 128); else vt_batch_feed (vtb, <DF>, 0, <FLAG_VAL> + 128); };\\\n"
"	  declare cr cursor for select VT_GZ_WORDUMP from <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" where \"VTLOG_<KFU>\" = <KF>; \\\n"
"	  whenever not found goto insert_dest; \\\n"
"	  open cr (exclusive, prefetch 1); fetch cr into _gz_wordump; \\\n"
"	  update <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\"\n"
"	    set\n"
"	      DMLTYPE = \\\'D\\\',\n"
"	      SNAPTIME = now(),\n"
"	      VT_GZ_WORDUMP = (\n"
"		case <IS_NEWS_MSG>\n"
"		  when 1 then DB.DBA.vt_get_gz_wordump_ex (_gz_wordump, DB.DBA.ns_make_index_content (<DF>,<IS_NEWS_MSG>), <FLAG_VAL>, null, 0 <LANG_ENC>)\n"
"		  else DB.DBA.vt_get_gz_wordump_ex (_gz_wordump, <DF>, <FLAG_VAL>, <FN_HOOK_D_NAME>, <KF> <LANG_ENC>)\n"
"		end),\n"
"	      VT_OFFBAND_DATA = <OFF_COLS_D>\n"
"	    where current of cr; \\\n"
"	  close cr; return; \\\n"
"	 insert_dest: \\\n"
"	  close cr; \\\n"
"	  insert into <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" (\"VTLOG_<KFU>\", SNAPTIME, DMLTYPE, VT_GZ_WORDUMP, VT_OFFBAND_DATA) values"
"	    (<KF>, now(), \\\'D\\\',"
"	      (case <IS_NEWS_MSG>"
"		when 1 then DB.DBA.vt_get_gz_wordump_ex (NULL, DB.DBA.ns_make_index_content (<DF>,<IS_NEWS_MSG>), <FLAG_VAL>, null, 0 <LANG_ENC>)"
"		else DB.DBA.vt_get_gz_wordump_ex (NULL, <DF>, <FLAG_VAL>, <FN_HOOK_D_NAME>, <KF> <LANG_ENC>)"
"	       end),"
"	     <OFF_COLS_D>); \\\n"
"       }\', "
"      \'create trigger \"<SUFF>_VTUB_log\" before update (<KF>, <DF> <DAV_update_cols> <OFF_DATA_COLS>) on <DB>.<DBA>.<TB>  ORDER 2 referencing old as O, new as N { \\\n"
"	  declare _gz_wordump, old_dmltype, new_dmltype varchar; \\\n"
"	  declare _new_compr varchar; \\\n"
"	  declare _key integer; \\\n"
"	  if (N.<KF> <> O.<KF>) \\\n"
"	    { \\\n"
"	      old_dmltype := \\\'D\\\'; \\\n"
"	      new_dmltype := \\\'I\\\'; \\\n"
"	    } \\\n"
"	  else \\\n"
"	    { \\\n"
"	      old_dmltype := \\\'U\\\'; \\\n"
"	      new_dmltype := null; \\\n"
"	    } \\\n"
"	  declare cr cursor for select VT_GZ_WORDUMP from <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" where \"VTLOG_<KFU>\" = _key; \\\n"
"	  if (<DAV_upd_cond>) return;\\\n"
"	  if (<DAV_indexing_condition_O>) goto new_upd;\\\n"
"	  declare vtb any; \\\n"
"	  vtb := vt_batch(1001 <LANG_ENC>); \\\n"
"	  vt_batch_d_id (vtb, O.<KF>); \\\n"
"	  whenever SQLSTATE \\\'22007\\\' goto do_the_rollback; \\\n"
"	  if (registry_get (\\\'DELAY_UPDATE_<SUFF>\\\') <> \\\'ON\\\') \\\n"
"	    { \\\n"
"	      if (<FN_HOOK_OD>) { \\\n"
"		  <DB>.<DBA>.\"VT_BATCH_PROCESS_<SUFF>\" (vtb, O.<KF>); \\\n"
"		}\\\n"
"	      else if (not isnull (O.<DF>)) \\\n"
"		{ \\\n"
"		    if (<IS_O_XML>) {\\\n"
"		      if (<IS_NEWS_MSG>) vt_batch_feed (vtb, DB.DBA.ns_make_index_content (O.<DF>,<IS_NEWS_MSG>), 1, <FLAG_VAL>); else vt_batch_feed (vtb, O.<DF>, 1, <FLAG_VAL>); }\\\n"
"		    else {\\\n"
"		      if (<IS_NEWS_MSG>) vt_batch_feed (vtb, DB.DBA.ns_make_index_content (O.<DF>,<IS_NEWS_MSG>), 1); else vt_batch_feed (vtb, O.<DF>, 1); };\\\n"
"		    <VTB_OFF_DATA_UO>\\\n"
"		  <DB>.<DBA>.\"VT_BATCH_PROCESS_<SUFF>\" (vtb, O.<KF>); \\\n"
"		} \\\n"
"	      goto new_upd; \\\n"
"	    } \\\n"
"	     else \\\n"
"	       if (<IS_O_XML>) {\\\n"
"		 if (<IS_NEWS_MSG>) vt_batch_feed (vtb, DB.DBA.ns_make_index_content (O.<DF>,<IS_NEWS_MSG>), 0, <FLAG_VAL> + 128); else vt_batch_feed (vtb, O.<DF>, 0, <FLAG_VAL> + 128); };\\\n"
"	  whenever not found goto insert_dest_old; \\\n"
"	  _key := O.<KF>; \\\n"
"	  open cr (exclusive); \\\n"
"	  fetch cr into _gz_wordump; \\\n"
"	  update <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\""
"	    set"
"	      DMLTYPE = old_dmltype,"
"	      SNAPTIME = now(),"
"	      VT_GZ_WORDUMP ="
"		(case <IS_NEWS_MSG>"
"		  when 1 then DB.DBA.vt_get_gz_wordump_ex (_gz_wordump, DB.DBA.ns_make_index_content (O.<DF>,<IS_NEWS_MSG>), <FLAG_VAL>, null, 0 <LANG_ENC>)"
"		  else DB.DBA.vt_get_gz_wordump_ex (_gz_wordump, O.<DF>, <FLAG_VAL>, <FN_HOOK_D_NAME>, _key <LANG_ENC>)"
"		end),"
"	      VT_OFFBAND_DATA = <OFF_COLS_O>"
"	    where current of cr; \\\n"
"	  goto new_upd; \\\n"
"	 insert_dest_old: \\\n"
"	  insert into <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" (\"VTLOG_<KFU>\", SNAPTIME, DMLTYPE, VT_GZ_WORDUMP, VT_OFFBAND_DATA) values"
"	    (O.<KF>, now(), old_dmltype,"
"	      (case <IS_NEWS_MSG>"
"		when 1 then DB.DBA.vt_get_gz_wordump_ex (NULL, DB.DBA.ns_make_index_content (O.<DF>,<IS_NEWS_MSG>), <FLAG_VAL>, null, 0 <LANG_ENC>)"
"		else DB.DBA.vt_get_gz_wordump_ex (NULL, O.<DF>, <FLAG_VAL>, <FN_HOOK_D_NAME>, _key <LANG_ENC>)"
"	      end),"
"	    <OFF_COLS_O>); \\\n"
"	 new_upd:; \\\n"
"	 close cr; return; \\\n"
"	    do_the_rollback: \\\n"
"	     txn_error (6); \\\n"
"	     signal (\\\'22008\\\', \\\'Invalid XML supplied for an validating free text index of <DB>.<DBA>.<TB>:\\\n\\\' || __SQL_MESSAGE, \\\'FT029\\\'); \\\n"
"       }\', "
"      \'create trigger \"<SUFF>_VTU_log\" after update (<KF>, <DF> <DAV_update_cols> <OFF_DATA_COLS>) on <DB>.<DBA>.<TB>  ORDER 2 referencing old as O, new as N { \\\n"
"	  declare _gz_wordump, old_dmltype, new_dmltype varchar; \\\n"
"	  declare _new_compr varchar; \\\n"
"	  declare _key integer; \\\n"
"	  if (N.<KF> <> O.<KF>) \\\n"
"	    { \\\n"
"	      old_dmltype := \\\'D\\\'; \\\n"
"	      new_dmltype := \\\'I\\\'; \\\n"
"	    } \\\n"
"	  else \\\n"
"	    { \\\n"
"	      old_dmltype := \\\'U\\\'; \\\n"
"	      new_dmltype := null; \\\n"
"	    } \\\n"
"	  declare cr cursor for select VT_GZ_WORDUMP from <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" where \"VTLOG_<KFU>\" = _key; \\\n"
"	  if (<DAV_upd_cond>) return;\\\n"
"	  if (<DAV_indexing_condition_O>) goto new_upd;\\\n"
"	  declare vtb any; \\\n"
"	 new_upd:; \\\n"
"	  whenever SQLSTATE \\\'22007\\\' goto do_the_rollback; \\\n"
"	  if (<DAV_indexing_condition_N>) return; \\\n"
"	  vtb := vt_batch(1001 <LANG_ENC>); \\\n"
"	  vt_batch_d_id (vtb, N.<KF>); \\\n"
"	  if (registry_get (\\\'DELAY_UPDATE_<SUFF>\\\') <> \\\'ON\\\') \\\n"
"	    { \\\n"
"	      if (<FN_HOOK_NI>) {\\\n"
"		 <DB>.<DBA>.\"VT_BATCH_PROCESS_<SUFF>\" (vtb, N.<KF>); \\\n"
"		} \\\n"
"	      else if (not isnull (N.<DF>)) \\\n"
"		{ \\\n"
"		    if (<IS_N_XML>) {\\\n"
"		      if (<IS_NEWS_MSG>) vt_batch_feed (vtb, DB.DBA.ns_make_index_content (N.<DF>,<IS_NEWS_MSG>), 0, <FLAG_VAL>); else vt_batch_feed (vtb, N.<DF>, 0, <FLAG_VAL>); }\\\n"
"		    else {\\\n"
"		      if (<IS_NEWS_MSG>) vt_batch_feed (vtb, DB.DBA.ns_make_index_content (N.<DF>,<IS_NEWS_MSG>), 0); else vt_batch_feed (vtb, N.<DF>, 0); };\\\n"
"		    <VTB_OFF_DATA_UN>\\\n"
"		  <DB>.<DBA>.\"VT_BATCH_PROCESS_<SUFF>\" (vtb, N.<KF>); \\\n"
"		} \\\n"
"	      return; \\\n"
"	    } \\\n"
"	     else \\\n"
"	       if (<IS_N_XML>) {\\\n"
"		 if (<IS_NEWS_MSG>) vt_batch_feed (vtb, DB.DBA.ns_make_index_content (N.<DF>,<IS_NEWS_MSG>), 0, <FLAG_VAL> + 128); else vt_batch_feed (vtb, N.<DF>, 0, <FLAG_VAL> + 128); };\\\n"
"	  _key := N.<KF>; \\\n"
"	  open cr (exclusive); \\\n"
"	  whenever not found goto insert_dest_new; \\\n"
"	  if (new_dmltype is null) new_dmltype := old_dmltype; \\\n"
"	  fetch cr into _gz_wordump; \\\n"
"	  update <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" set DMLTYPE = new_dmltype, SNAPTIME = now() where current of cr; \\\n"
"	  close cr; return; \\\n"
"	 insert_dest_new: \\\n"
"	  insert into <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" (\"VTLOG_<KFU>\", SNAPTIME, DMLTYPE) values (N.<KF>, now(), new_dmltype); \\\n"
"	  close cr; return; \\\n"
"	    do_the_rollback: \\\n"
"	     txn_error (6); \\\n"
"	     signal (\\\'22008\\\', \\\'Invalid XML supplied for an validating free text index of <DB>.<DBA>.<TB>:\\\n\\\' || __SQL_MESSAGE, \\\'FT030\\\'); \\\n"
"       }\', "
"       \'create procedure <DB>.<DBA>.\"VT_INC_INDEX_SLICE_<SUFF>\" (in slid int)\n"
"       {\n"
"         cl_set_slice (\\'<DB_1>.<DBA_1>.<TBU>\\', \\'<TBU>\\', slid);\n"
"         <DB>.<DBA>.\"VT_INC_INDEX_1_<SUFF>\" ();\n"
"       }\', \n"
"	\'create procedure <DB>.<DBA>.\"VT_INC_INDEX_<SUFF>\" () \n"
"	{ \n"
"	  if (0 = <IS_CL>) \n"
"	    <DB>.<DBA>.\"VT_INC_INDEX_1_<SUFF>\" (); \n"
"	  else \n"
"	    DB.DBA.CL_EXEC (\\'<DB>.<DBA>.\"VT_INC_INDEX_SRV_<SUFF>\" ()\\'); \n"
"	}\', \n"
"	\'create procedure <DB>.<DBA>.\"VT_INC_INDEX_SRV_<SUFF>\" () \n"
"	{ \n"
"	  declare aq, slices any; \n"
"         declare inx int; \n"
"	  if (not exists (select 1 from DB.DBA.SYS_CLUSTER where CL_NAME = \\'ELASTIC\\')) { aq := async_queue (1); \n"
"	  aq_request (aq, \\'<DB_1>.<DBA_1>.VT_INC_INDEX_1_<SUFF_1>\\', vector ()); } else { \n"
"	  aq := async_queue (sys_stat (\\'enable_qp\\')); \n"
"         slices := cl_hosted_slices (\\'ELASTIC\\', sys_stat (\\'cl_this_host\\'));\n"
"         for (inx := 0; inx < length (slices); inx := inx + 1) \n"
"	    aq_request (aq, \\'<DB_1>.<DBA_1>.VT_INC_INDEX_SLICE_<SUFF>\\', vector (slices[inx])); }\n"
"	  aq_wait_all (aq); \n"
"	}\', \n"
"	\'create procedure <DB>.<DBA>.\"VT_INC_INDEX_1_<SUFF>\" () \n"
"	{ \n"
"	  declare _vtlog_id, _data, _dmltype, _vt_wordump, _vt_offband_data, vtb, decses, dav_res_type any; \n"
"	  declare len, max_len integer; \n"
"	  declare start any; \n"
"	 <OFF_DATA_VARS_DECL>\n"
" "
"	  start := 0; \n"
"	  declare cr cursor for  \n"
"	      select  \n"
"		\"VTLOG_<KFU>\", \n"
"		DMLTYPE, \n"
"		VT_GZ_WORDUMP, \n"
"		VT_OFFBAND_DATA \n"
"	      from \n"
"		<DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\" table option (no cluster) \n"
"	       order by 1 for update option (order); \n"
" "
"	  decses := string_output();	\n "
"	  vtb := vt_batch (8191 <LANG_ENC>); \n"
"	  max_len := sys_stat (\\\'vt_batch_size_limit\\\');  \n"
"	  whenever not found goto done; \n"
"	  while (1) \n"
"	    { \n"
"	      len := 0; \n"
"	      open cr (exclusive); \n"
"	      while (len < max_len) \n"
"		{ \n"
"		  fetch cr into _vtlog_id, _dmltype, _vt_wordump, _vt_offband_data; \n"
"		  vt_batch_d_id (vtb, _vtlog_id); \n"
"		  if (_vt_wordump is not null) \n"
"		    { \n"
"		      gz_uncompress (blob_to_string(_vt_wordump), decses); \n"
"		      _data := string_output_string (decses); \n"
/*"		      len := len + length (_data); \n"*/
"		      if (not isnull(_data)) { \n"
"		       vt_batch_feed_wordump (vtb, _data, 1); \n"
"		       if (not isnull(_vt_offband_data)) \n"
"			 vt_batch_feed_offband (vtb, blob_to_string(_vt_offband_data), 1); \n"
"		     }; \n"
"		      string_output_flush (decses); \n"
"		      len := len + vt_batch_words_length (vtb); \n"
"		      vt_batch_d_id (vtb, _vtlog_id); \n"
/*"		     dbg_obj_print (\\\'batch len: \\\', len); \n"*/
"		    } \n"
"		  _data := null; \n"
"		  if (_dmltype <> \\\'D\\\') \n"
"		    { \n"
/* XXX: here depends how key is partitioned */
"			select <RES_TYPE_COL> <DF> <OFF_DATA_COLS> into <DAV_RES_TYPE_VAR> _data <OFF_DATA_VARS> from <DB>.<DBA>.<TB> table option (no cluster) where <KF> = _vtlog_id; \n"
"			if (_data is not null and <IS_NEWS_MSG>) \n"
"			  _data := DB.DBA.ns_make_index_content (_data,<IS_NEWS_MSG>); \n"
/*"			  len := len + length (_data); \n"*/
"			if (not <FN_HOOK_I_INC> and not isnull(_data)) \n"
"			  { \n"
"			     if ((<IS_XML_PR>) or (<IS_DAV> and lcase (dav_res_type) = \\\'text/xml\\\')) \n"
"			       vt_batch_feed (vtb, _data, 0, <FLAG_VAL>); \n"
"			     else \n"
"			       vt_batch_feed (vtb, _data, 0); \n"
"			       <OFF_DATA_VTB>\n"
"			   } \n"
"			len := len + vt_batch_words_length (vtb); \n"
/*"		       dbg_obj_print (\\\'batch len: \\\', len); \n"*/
"		    } \n"
"		} \n"
"	      start := _vtlog_id; \n"
"	      <DB>.<DBA>.\"VT_BATCH_PROCESS_<SUFF>\" (vtb, _vtlog_id, 1); \n"
"	      vtb := vt_batch (1001 <LANG_ENC>); \n"
"	      delete from <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\"  table option (no cluster) where \"VTLOG_<KFU>\" <= start; \n"
"	      len := 0; \n"
"	      commit work; \n"
"	    } \n"
"	done: \n"
"	  <DB>.<DBA>.\"VT_BATCH_PROCESS_<SUFF>\" (vtb, _vtlog_id, 1); \n"
"	  delete from <DB>.<DBA>.\"VTLOG_<VTLOGSUFF>\"  table option (no cluster); \n"
"	}\', "
"	either (isnull (is_pk), "
"	 \'sequence_set (\\\'VTLOG_<SUFF>\\\', 1, 1)\\\n\', "
"	   null), "
"	either (isnull (is_pk), "
"	 \'create procedure <DB>.<DBA>.\"VT_PK_FILLUP_<SUFF>\" () \n"
"	     { \n"
"	       set triggers off; \n"
"	       declare _dummy_, ctr, num integer; \n"
"	       whenever not found goto done; \n"
"	       declare cr cursor for select <KF> from <DB>.<DBA>.<TB> where <KF> is null; \n"
"	       while (1) \n"
"		 { \n"
"		   num := 0; \n"
"		   open cr (exclusive); \n"
"		   while (num < 10000) \n"
"		     { \n"
"		       fetch cr into _dummy_; \n"
"		       _dummy_ := sequence_next (\\\'VTLOG_<SUFF>\\\'); \n"
"		       update <DB>.<DBA>.<TB> set <KF> = _dummy_ where current of cr; \n"
"		       num := num + 1; \n"
"		     } \n"
"		   close cr; \n"
"		   commit work; \n"
"		 } \n"
"	      done: \n"
"	       close cr; \n"
"	    }\', \n"
"	   null) \n"
"  ); \n"
" \n"
" "
"  declare fn_hook_i, fn_hook_d, fn_hook_od, fn_hook_ni, fn_hook_i_inc, fn_hook_d_name varchar; \n"
"  fn_hook_i := '(1 <> 1)'; \n"
"  fn_hook_d := '(1 <> 1)'; \n"
"  fn_hook_od := '(1 <> 1)'; \n"
"  fn_hook_ni := '(1 <> 1)'; \n"
"  fn_hook_i_inc := '(1 <> 1)'; \n"
"  fn_hook_d_name := 'NULL';\n"
"  if (func is not null) { \n"
"   fn_hook_i   := sprintf ('\"%I\".\"%I\".\"%I\" (vtb, \"%I\")',  name_part (func, 0),name_part (func, 1), name_part (func, 2) , keycol); \n"
"   fn_hook_i_inc   := sprintf ('\"%I\".\"%I\".\"%I\" (vtb, _vtlog_id)',  name_part (func, 0),name_part (func, 1), name_part (func, 2)); \n"
"   fn_hook_ni := sprintf ('\"%I\".\"%I\".\"%I\" (vtb, N.\"%I\")', name_part (func, 0),name_part (func, 1), name_part (func, 2), keycol); \n"
"   } \n"
""
"  if (ufunc is not null) { \n"
"   fn_hook_d   := sprintf ('\"%I\".\"%I\".\"%I\" (vtb, \"%I\")',  name_part (ufunc, 0),name_part (ufunc, 1), name_part (ufunc, 2) , keycol); \n"
"   fn_hook_od := sprintf ('\"%I\".\"%I\".\"%I\" (vtb, O.\"%I\")', name_part (ufunc, 0),name_part (ufunc, 1), name_part (ufunc, 2), keycol); \n"
"   fn_hook_d_name := concat ('\\\'', ufunc, '\\\''); \n"
"  } \n"
" "
"  inx := 0; \n"
"  while (inx < length (commands)) \n"
"    { \n"
"      command := aref (commands, inx); \n"
"      if (command is not null) \n"
"	{ \n"
"	  command := replace (command, \'<DB>\',	sprintf ('\"%I\"', name_part (tablename, 0))); \n"
"	  command := replace (command, \'<DBA>\',	sprintf ('\"%I\"', name_part (tablename, 1))); \n"
"	  command := replace (command, \'<TB>\',	sprintf ('\"%I\"', name_part (tablename, 2))); \n"
"	  command := replace (command, \'<TBU>\',	sprintf ('%I', name_part (tablename, 2))); \n"
"	  command := replace (command, \'<SUFF>\',	sprintf ('%I', tb_suff)); \n"
"	  command := replace (command, \'<VTLOGSUFF>\',	sprintf ('%I', vtlog_suff)); \n"
"	  command := replace (command, \'<DF>\',	sprintf ('\"%I\"', datacol)); \n"
"	  command := replace (command, \'<KF>\',	sprintf ('\"%I\"', keycol)); \n"
"	  command := replace (command, \'<KFU>\',	sprintf ('%I', keycol)); \n"
"	  command := replace (command, \'<KFU_TYPE>\',	id_col_type); \n"
"	  command := replace (command, \'<PK_COL_COND>\',	pk_col_cond); \n"
"	  command := replace (command, \'<PK_COL_VARS>\',	pk_col_vars); \n"
"	  command := replace (command, \'<PK_COL_ASSIGN>\',	pk_col_assign); \n"
"	  command := replace (command, \'<DAV_indexing_condition>\',	DAV_indexing_condition); \n"
"	  command := replace (command, \'<DAV_indexing_condition_O>\',	DAV_indexing_condition_O); \n"
"	  command := replace (command, \'<DAV_indexing_condition_N>\',	DAV_indexing_condition_N); \n"
"	  command := replace (command, \'<DAV_update_cols>\',	DAV_update_cols); \n"
"	  command := replace (command, \'<IS_XML>\',	IS_XML_cond); \n"
"	  command := replace (command, \'<IS_O_XML>\',	IS_O_XML_cond); \n"
"	  command := replace (command, \'<IS_N_XML>\',	IS_N_XML_cond); \n"
"	  command := replace (command, \'<IS_DAV>\',	IS_DAV_cond); \n"
"	  command := replace (command, \'<IS_XML_PR>\',	IS_XML_PR_cond); \n"
"	  command := replace (command, \'<RES_TYPE_COL>\',	TYPE_col); \n"
"	  command := replace (command, \'<DAV_RES_TYPE_VAR>\',	TYPE_var); \n"
"	  command := replace (command, \'<FLAG_VAL>\',	sprintf (\'%d\', _dav_flag)); \n"
"	  command := replace (command, \'<DAV_upd_cond>\',	DAV_upd_cond); \n"
"	  command := replace (command, \'<IS_NEWS_MSG>\',	IS_NEWS_MSG_cond); \n"
"	  command := replace (command, \'<VTB_OFF_DATA_I>\',	of_vtb); \n"
"	  command := replace (command, \'<VTB_OFF_DATA_D>\',	of_vtb_d); \n"
"	  command := replace (command, \'<VTB_OFF_DATA_UO>\',	of_vtb_o); \n"
"	  command := replace (command, \'<VTB_OFF_DATA_UN>\',	of_vtb_n); \n"
"	  command := replace (command, \'<OFF_DATA_VTB>\',	of_inc_vtb); \n"
"	  command := replace (command, \'<OFF_DATA_VARS_DECL>\',of_vars_decl); \n"
"	  command := replace (command, \'<OFF_DATA_VARS>\',     of_vars); \n"
"	  command := replace (command, \'<OFF_DATA_COLS>\',     of_cols); \n"
"	  command := replace (command, \'<OFF_COLS_D>\',     of_cols_d); \n"
"	  command := replace (command, \'<OFF_COLS_O>\',     of_cols_o); \n"
"	  command := replace (command, \'<FN_HOOK_I>\',	 fn_hook_i); \n"
"	  command := replace (command, \'<FN_HOOK_D>\',	 fn_hook_d); \n"
"	  command := replace (command, \'<FN_HOOK_OD>\',	fn_hook_od); \n"
"	  command := replace (command, \'<FN_HOOK_NI>\',	fn_hook_ni); \n"
"	  command := replace (command, \'<FN_HOOK_I_INC>\',     fn_hook_i_inc); \n"
"	  command := replace (command, \'<FN_HOOK_D_NAME>\',     fn_hook_d_name); \n"
"	  command := replace (command, \'<LANG_ENC>\',     _lang_enc_args); \n"
"	  command := replace (command, \'<CL_PART>\',     cl_part); \n"
"	  command := replace (command, \'<CL_OPTS>\',     cl_opts); \n"
"	  command := replace (command, \'<IS_CL>\',     cast (is_part as varchar)); \n"
"	  command := replace (command, \'<DB_1>\',	sprintf ('%S', name_part (tablename, 0))); \n"
"	  command := replace (command, \'<DBA_1>\',	sprintf ('%S', name_part (tablename, 1))); \n"
"	  command := replace (command, \'<SUFF_1>\',	sprintf ('%S', tb_suff)); \n"
"	  DB.DBA.execstr (command); \n"
"	} \n"
"      inx := inx + 1; \n"
"    } \n"
"  if (is_pk is null or defer_generation = 0) \n"
"    { \n"
"      declare st, msg, index_cmd, the_index varchar; \n"
"      declare log_the_fillup, log_the_index, log_the_cr_index integer; \n"
"      log_the_fillup := 0; log_the_index := 0; log_the_cr_index := 0; \n"
"      the_index := NULL; \n"
"      index_cmd := NULL; \n"
"      select VI_INDEX into the_index from DB.DBA.SYS_VT_INDEX where VI_TABLE = tablename; \n"
"      if (the_index is null) \n"
"	{ \n"
"	   declare kn, cl_part, part_decl varchar; \n"
"	   part_decl := ''; \n"
"          if (is_part) { \n"
"            cl_part := DB.DBA.VT_GET_CLUSTER (tablename, tablename); \n"
"            part_decl := sprintf (' PARTITION %S (\"%I\" int (0hexffff00))', cl_part, keycol); \n"
"          } \n"
"	   kn := concat (name_part (tablename, 2), \'_\', datacol, \'_WORDS\');\n"
"	   index_cmd := sprintf ('CREATE INDEX \"%I\" ON \"%I\".\"%I\".\"%I\" (\"%I\") %s', "
"		kn, name_part (tablename, 0), name_part (tablename, 1), name_part (tablename, 2), keycol, part_decl);\n"
"	   update DB.DBA.SYS_VT_INDEX set VI_INDEX = kn where VI_TABLE = tablename; \n"
"	} \n"
"      st := \'00000\'; \n"
/*"      dbg_obj_print (\'going atomic \'); \n"*/
"      declare atomic integer; \n"
"      atomic := __row_count_exceed (tablename, 10000); \n"
"      if (atomic) __atomic (1); \n"
"      if (isnull (is_pk)) \n"
"	{ \n"
/*"	  dbg_obj_print (\'calling fillup \'); \n"*/
"	  exec (sprintf (\'\"%I\".\"%I\".\"VT_PK_FILLUP_%I\" ()\', \n"
"	      name_part (tablename, 0), name_part (tablename, 1), tb_suff), st, msg); \n"
"	  if (st = \'00000\') \n"
"	    log_the_fillup := 1; \n"
/*"	  else \n"
"	    dbg_obj_print (\'fillup failed\', st, msg); \n"
"	  dbg_obj_print (\'done fillup \'); \n"*/
"	} \n"
"      if (st = \'00000\' and index_cmd is not null) \n"
"	{ \n"
/*"	  dbg_obj_print (\'calling create index  \'); \n"*/
"	  exec (index_cmd, st, msg); \n"
"	  if (st = \'00000\') \n"
"	    log_the_cr_index := 1; \n"
/*"	  else \n"
"	    dbg_obj_print (\'create index failed\', st, msg); \n"
"	  dbg_obj_print (\'create index done\'); \n"*/
"	} \n"
"      if (st = \'00000\' and defer_generation = 0) \n"
"	{ \n"
/*"	  dbg_obj_print (\'calling vt_index\'); \n"*/
"	  exec (sprintf (\'\"%I\".\"%I\".\"VT_INDEX_%I\" (flag=>0)\', name_part (tablename, 0), \n"
"			name_part (tablename, 1), tb_suff), st, msg); \n"
"	  if (st = \'00000\') \n"
"	    log_the_index := 1; \n"
/*"	  else \n"
"	    dbg_obj_print (\'create index failed\', st, msg); \n"
"	  dbg_obj_print (\'done vt_index\'); \n"*/
"	} \n"
"      if (atomic) __atomic (0); \n"
/*"      dbg_obj_print (\'atomic done\'); \n"*/
"      if (st <> \'00000\') \n"
"	signal (\'37000\', sprintf (\'Setting initial state of the freetext index for %s failed. The data is intact, but the freetext index is unusable. In order to recover from this state the table %s_%s_WORDS should be dropped. This will clear all the objects created so far. Then the freetext index creation should be retried after removing the cause of the error which is : SQL State [%s] Explanation : %s\', tablename, name_part (tablename, 2), datacol, st, msg), \'FT031\'); \n"
"      if (log_the_fillup and atomic) \n"
/*"	{  dbg_obj_print (\'logging the fillup\'); \n"*/
"	log_text (sprintf (\'\"%I\".\"%I\".\"VT_PK_FILLUP_%I\" ()\', name_part (tablename, 0), \n"
"	    name_part (tablename, 1), tb_suff)); \n"
/*"	} \n"*/
"      if (log_the_cr_index and atomic) \n"
/*"	{  dbg_obj_print (\'logging the create index\'); \n"*/
"	log_text (index_cmd); \n"
/*"	} \n"*/
"      if (log_the_index and atomic) \n"
/*"	{  dbg_obj_print (\'logging the vt_index\'); \n"*/
"	log_text (sprintf (\'\"%I\".\"%I\".\"VT_INDEX_%I\" (flag=>0)\', name_part (tablename, 0), \n "
"		    name_part (tablename, 1), tb_suff)); \n"
/*"	} \n"*/
"	  \n"
"    } \n"
/*"  dbg_obj_print ('exiting create_update_log'); \n"*/
"  return; \n"
"no_index: \n"
"  signal (\'42S02\', concat (\'The table \', tablename, \'is not full-text indexed\'), \'FT032\'); \n"
"} ";


static char *vt_clear_free_text_index_text =
"create procedure vt_clear_text_index (in tablename varchar) \n"
"{ \n"
"  declare stat, msg, indextable, datatable, log_table, id_col, data_col varchar; \n"
"  declare is_pk integer; \n"
"  declare is_log integer; \n"
"  declare db_suff varchar;\n"
"  declare cr cursor for select \n"
"    VI_TABLE, VI_INDEX_TABLE, VI_ID_IS_PK, VI_ID_COL, VI_COL, \n"
"    concat (\'VTLOG_\', name_part (VI_TABLE, 0), \'_\', name_part (VI_TABLE, 1), \'_\', name_part (VI_TABLE, 2)) as VI_LOG_TABLE \n"
"   from DB.DBA.SYS_VT_INDEX \n"
"   where VI_TABLE = tablename or VI_INDEX_TABLE = tablename; \n"

/*" dbg_obj_print ('dropping table: ', tablename);"*/

"  whenever not found goto no_table; \n"
"  if (upper (subseq (name_part (tablename, 2), 0, 6)) = 'VTLOG_') \n"
"    { \n"
"      declare pref, qual, tb varchar; "
"      pref := name_part (tablename, 0); qual := name_part (tablename, 1); tb := name_part (tablename, 2); "
"      tb := subseq (tb, 8 + length (pref) + length (qual), length (tb)); "
"      is_log := 1; \n"
"      tablename := concat (pref, \'.\', qual, \'.\', tb); \n"
/*" dbg_obj_print ('ch dropping table: ', tablename);"*/
"    } \n"
"  else \n"
"    is_log := null; \n"
"  \n"
"  open cr (EXCLUSIVE, PREFETCH 1); \n"
"  fetch cr into datatable, indextable, is_pk, id_col, data_col, log_table; \n"
"  db_suff := DB.DBA.SYS_ALFANUM_NAME (sprintf ('%s_%s_%s', name_part (datatable, 0), name_part (datatable, 1), name_part (datatable, 2))); \n"
"  if (is_log is not null) \n"
"    { \n"
/*"      dbg_printf (\'Deleting the update log triggers for table %s\', datatable); \n"*/
"      exec (sprintf (\'drop trigger \"%I\".\"%I\".\"%I_VTI_log\"\', "
"	name_part (datatable, 0), name_part (datatable, 1), db_suff), stat, msg); \n"
/*"      dbg_obj_print ('trigger1', stat, msg); "*/
"      exec (sprintf (\'drop trigger \"%I\".\"%I\".\"%I_VTUB_log\"\', "
"	name_part (datatable, 0), name_part (datatable, 1), db_suff), stat, msg); \n"
/*"      dbg_obj_print ('trigger2', stat, msg); "*/
"      exec (sprintf (\'drop trigger \"%I\".\"%I\".\"%I_VTU_log\"\', "
"	name_part (datatable, 0), name_part (datatable, 1), db_suff), stat, msg); \n"
/*"      dbg_obj_print ('trigger3', stat, msg); "*/
"      exec (sprintf (\'drop trigger \"%I\".\"%I\".\"%I_VTD_log\"\', "
"	name_part (datatable, 0), name_part (datatable, 1), db_suff), stat, msg); \n"
/*"      dbg_obj_print ('trigger4', stat, msg); "*/
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_INC_INDEX_%I\"\', "
"	name_part (datatable, 0), name_part (datatable, 1), db_suff), stat, msg); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_INC_INDEX_1_%I\"\', "
"	name_part (datatable, 0), name_part (datatable, 1), db_suff), stat, msg); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_INC_INDEX_SRV_%I\"\', "
"	name_part (datatable, 0), name_part (datatable, 1), db_suff), stat, msg); \n"
/*"      dbg_obj_print ('trigger5', stat, msg); "*/
/*"      dbg_printf (\'Done Deleting the update log triggers for table %s\', datatable); \n"*/
"    } \n"
"  else if (indextable = tablename) \n"
"    { \n"
"      declare _datatable varchar; "
/*"      dbg_printf (\'Dropping the index on table %s of %s\', tablename, datatable); \n"*/
"      DB.DBA.vt_batch_update (datatable, \'OFF\', 0);"
"      exec (\'DB.DBA.vt_drop_ftt (?, null)\', stat, msg, vector (datatable)); \n"
"      exec (sprintf (\'drop index \"%I_%I_WORDS\" \"%I\".\"%I\".\"%I\"\', name_part (datatable, 2), data_col, name_part (datatable, 0), name_part (datatable, 1), name_part (datatable, 2)), stat, msg); \n"
"      if (is_pk is null) \n"
"	{ \n"
/*"	  dbg_printf (\'Dropping the column %s of table %s\', id_col, datatable); \n"*/
"	  exec (sprintf (\'alter table \"%I\".\"%I\".\"%I\" drop \"%I\"\', name_part (datatable, 0), name_part (datatable, 1), name_part (datatable, 2), id_col), stat, msg); \n"
"	} \n"
/*"      dbg_printf (\'Deleting the procedures for fulltext index table %s of %s\', tablename, datatable); \n"*/
"      _datatable := DB.DBA.SYS_ALFANUM_NAME (replace (datatable, \'.\', \'_\')); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_INDEX_%s\"\', name_part (datatable, 0), name_part (datatable, 1), _datatable), stat, msg); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_INDEX_1_%s\"\', name_part (datatable, 0), name_part (datatable, 1), _datatable), stat, msg); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_INC_INDEX_SLICE_%s\"\', name_part (datatable, 0), name_part (datatable, 1), _datatable), stat, msg); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_BATCH_PROCESS_%s\"\', name_part (datatable, 0), name_part (datatable, 1), _datatable), stat, msg); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_HITS_%I\"\', name_part (datatable,0), name_part (datatable, 1), name_part (datatable, 2)), stat, msg); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_BATCH_REAL_PROCESS_%s\"\', name_part (datatable, 0), name_part (datatable, 1), _datatable), stat, msg); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_BATCH_REAL_PROCESS_CL_%s\"\', name_part (datatable, 0), name_part (datatable, 1), _datatable), stat, msg); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_BATCH_REAL_PROCESS_1_%s\"\', name_part (datatable, 0), name_part (datatable, 1), _datatable), stat, msg); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_INSERT_1_%s\"\', name_part (datatable, 0), name_part (datatable, 1), _datatable), stat, msg); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_NEXT_CHUNK_ID_%s\"\', name_part (datatable, 0), name_part (datatable, 1), _datatable), stat, msg); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_PROCESS_WORD_BATCH_%s\"\', name_part (datatable, 0), name_part (datatable, 1), _datatable), stat, msg); \n"
"      exec (sprintf (\'drop procedure \"%I\".\"%I\".\"VT_PK_FILLUP_%s\"\', name_part (datatable, 0), name_part (datatable, 1), _datatable), stat, msg); \n"
"      exec (sprintf (\'drop trigger \"XML_U_CHECK_%s\"\', _datatable), stat, msg); \n"
"      exec (sprintf (\'drop trigger \"XML_I_CHECK_%s\"\', _datatable), stat, msg); \n"
/*"      dbg_printf (\'Deleting the update log VTLOG_%s for table %s\', _datatable, datatable); \n"*/
"      commit work;\n"
"      exec (sprintf (\'drop table \"%I\".\"%I\".\"VTLOG_%I\"\',  \n"
"	name_part (datatable, 0), name_part (datatable, 1), replace (datatable, \'.\', \'_\')), stat, msg);\n"
/*"      dbg_printf (\'Deleting the fulltext index definition for %s from DB.DBA.SYS_VT_INDEX\', tablename); \n"*/
"      delete from DB.DBA.SYS_VT_INDEX where current of cr; \n"
/*"      dbg_printf (\'Done Dropping the index on table %s of %s\', tablename, datatable); \n"*/
"    } \n"
"  else if (datatable = tablename) \n"
"    { \n"
/*"      dbg_printf (\'Deleting the fulltext index table %s for table %s\', indextable, tablename); \n"*/
"      commit work;\n"
"      exec (sprintf (\'drop table \"%I\"\', indextable), stat, msg); \n"
/*"      dbg_printf (\'Done Deleting the fulltext index table %s for table %s\', indextable, tablename); \n"*/
"    } \n"
"no_table: \n"
"  close cr; \n"
"} \n";


vt_batch_t *
vtb_copy (vt_batch_t * vtb)
{
  vtb->vtb_ref_count++;
  return vtb;
}


void
bif_text_init (void)
{
  stop_words_mtx = mutex_allocate ();
  vt_stop_words = id_hash_allocate (11, sizeof (caddr_t), sizeof (caddr_t), strhash, strhashcmp);
  bif_define ("vt_word_string_ends", bif_vt_word_string_ends);
  bif_define ("vt_word_string_details", bif_vt_word_string_details);
  bif_define_ex ("wb_all_done_bif", bif_wb_all_done, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define ("vt_batch", bif_vt_batch);
  bif_define ("vt_batch_d_id", bif_vt_batch_d_id);
  bif_define ("vt_batch_alpha_range", bif_vt_batch_alpha_range);
  bif_define ("vt_batch_array_sort", bif_vt_batch_array_sort);
  bif_define ("vt_batch_feed", bif_vt_batch_feed);
  bif_define ("vt_batch_feed_wordump", bif_vt_batch_feed_wordump);
  bif_define ("vt_batch_feed_offband", bif_vt_batch_feed_offband);
  bif_define ("vt_batch_strings", bif_vt_batch_strings);
  bif_define ("vt_batch_strings_array", bif_vt_batch_strings_array);
  bif_define ("vt_batch_wordump", bif_vt_batch_wordump);
  bif_define ("wb_apply", bif_wb_apply);
  bif_define ("vt_batch_words_length", bif_vt_batch_words_length);

  bif_define_ex ("vt_is_noise", bif_vt_is_noise, BMD_RET_TYPE, &bt_integer, BMD_DONE);
  bif_define_ex ("vt_load_stop_words", bif_vt_load_stop_words, BMD_RET_TYPE, &bt_any, BMD_DONE);
  bif_define ("key_is_d_id_partition", bif_key_is_d_id_partition);
  vt_noise_word_init ("noise.txt", &lh_noise_words);
  dk_mem_hooks(DV_TEXT_BATCH, (box_copy_f)vtb_copy, (box_destr_f) vtb_destroy, 0);
  PrpcSetWriter (DV_TEXT_BATCH, (ses_write_func) vtb_serialize);

  text_init ();
}

void
ddl_text_index_upgrade (void)
{
  query_t *proc = NULL;
  char *full_name = sch_full_proc_name (/*isp_schema (db_main_tree->it_commit_space)*/ wi_inst.wi_schema, "DB.DBA.vt_create_text_index",
	bootstrap_cli->cli_qualifier, CLI_OWNER (bootstrap_cli));
  if (full_name)
    proc = sch_proc_def (/*isp_schema (db_main_tree->it_commit_space)*/ wi_inst.wi_schema, full_name);
  if (proc != NULL)
    return;
  ddl_sel_for_effect ("select count (*)  from SYS_VT_INDEX where 0 = __vt_index (VI_TABLE, VI_INDEX, VI_COL, VI_ID_COL, VI_INDEX_TABLE, deserialize (VI_OFFBAND_COLS), VI_LANGUAGE, VI_ENCODING, deserialize (VI_ID_CONSTR))");
  ddl_std_proc (vt_create_text_index_text, 0x0);
}

void
ddl_text_init (void)
{
  dbe_table_t *tb = sch_name_to_table (isp_schema (NULL), "DB.DBA.SYS_VT_INDEX");
  ddl_std_proc (exestr_text, 0);
  ddl_std_proc (vt_batch_update_text, 0);
  ddl_std_proc (vt_find_index_text, 0);

  if (tb && tb_name_to_column (tb, LAST_FTI_COL))
    ddl_std_proc (vt_create_text_index_text, 0);
  ddl_std_proc (vt_get_gz_wordump_ex_text_0, 0);
  ddl_std_proc (vt_get_gz_wordump_ex_text, 0);
  ddl_std_proc (vt_free_text_proc_gen_text, 0);
  ddl_std_proc (vt_clear_free_text_index_text, 1);
  ddl_std_proc (wb_all_done_text, 0);
  ddl_std_proc (vt_create_update_log_text, 0);
}

