/*
 *  bif_text.h
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

#ifndef _BIF_TEXT_H
#define _BIF_TEXT_H

#include "text.h"	/* IvAn/TextXperIndex/000815 */
#ifdef __cplusplus
extern "C" {
#endif
#include "langfunc.h"
#ifdef __cplusplus
}
#endif

#if 0
char * asciiword_start_0 (char * str);
char * asciiword_last_0 (char * str);
char * asciiword_start (char * str, char * extra);
char * asciiword_last (char * str, char * extra);
void str_asciiupc_copy (char * to, const char * from, int len);

#define ASCIIALPHACHARP(c) \
  (((c) >= '0' && (c) <= '9') || \
  ((c) >= 'a' && (c) <= 'z') || \
  ((c) >= 'A' && (c) <= 'Z'))

#define IS_ASCIIWORD_CHAR_0(c) \
  (((c) >= '0' && (c) <= '9') || \
  ((c) >= 'a' && (c) <= 'z') || \
  ((c) >= 'A' && (c) <= 'Z') \
  || (((unsigned char)(c)) >= 192)) /* Any ISO-8059/x letter. */

#define IS_ASCIIWORD_CHAR(c, extra) \
  (((c) >= '0' && (c) <= '9') || \
  ((c) >= 'a' && (c) <= 'z') || \
  ((c) >= 'A' && (c) <= 'Z') \
  || strchr (extra, (c)) \
  || (((unsigned char)(c)) >= 192)) /* Any ISO-8059/x letter. */
#endif

extern lang_handler_t *server_default_lh;
extern char *server_default_language_name;

#ifndef FREETEXT_PORTABILITY_TEST
#define FIRST_MAIN_WORD_POS	((wpos_t)(0x00000000L))
#define LAST_MAIN_WORD_POS	((wpos_t)(0x7FFFefffL))	/* I just reserved 4096 last positions */
#define FIRST_ATTR_WORD_POS	((wpos_t)(0x80000000L))
#define LAST_ATTR_WORD_POS	((wpos_t)(0xFFFFefffL))	/* I just reserved 4096 last positions */
#define BAD_WORD_POS		((wpos_t)(0xFFFFFFFFL))
#else
#define FIRST_MAIN_WORD_POS	((wpos_t)(0x0000L))
#define LAST_MAIN_WORD_POS	((wpos_t)(0x7effL))	/* The reserve is less, 256 only, but it's OK anyway */
#define FIRST_ATTR_WORD_POS	((wpos_t)(0x8000L))
#define LAST_ATTR_WORD_POS	((wpos_t)(0xFeffL))	/* The reserve is less, 256 only, but it's OK anyway */
#define BAD_WORD_POS		((wpos_t)(0xFFFFL))
#endif

#define IS_MAIN_WORD_POS(pos) (!((pos) & FIRST_ATTR_WORD_POS))
#define IS_ATTR_WORD_POS(pos) ((pos) & FIRST_ATTR_WORD_POS)

typedef struct vt_batch_s
  {
    int		vtb_ref_count;
    id_hash_t *	vtb_words;
    d_id_t	vtb_d_id;
    wpos_t	vtb_word_pos;
    wpos_t	vtb_attr_word_pos;
    int		vtb_strings_taken;
    lenmem_t	vtb_min_word;
    lenmem_t	vtb_max_word;
    encoding_handler_t *	vtb_default_eh;
    lang_handler_t *		vtb_default_lh;
    ptrlong	vtb_words_len;
  } vt_batch_t;

typedef struct wb_pos_s
  {
    wpos_t *	wbp_buf;
    wpos_t	wbp_buf_fill;
  } wb_pos_t;

#define FREE_WBP_BUF(WBP) \
  do \
    { \
      if ((WBP).wbp_buf && (WBP).wbp_buf != WB_DELETED) \
	{ \
	  dk_free_box ((box_t)(WBP).wbp_buf); \
	  (WBP).wbp_buf = NULL; \
	} \
    } \
  while (0)

typedef struct word_batch_s
  {
    d_id_t	wb_d_id;
    dk_set_t	wb_word_recs;
    wb_pos_t    wb_main_positions;
    wb_pos_t    wb_attr_positions;
  } word_batch_t;


extern lh_word_callback_t vtb_hash_string_ins_callback;
extern lh_word_callback_t vtb_hash_string_del_callback;
extern lh_word_callback_t push_string_into_set_callback;

void ddl_text_init (void);
void ddl_text_index_upgrade (void);
void log_thread_initialize (void);
vt_batch_t * bif_vtb_arg (caddr_t * qst, state_slot_t ** args, int n, const char * f);

#endif /* _BIF_TEXT_H */
