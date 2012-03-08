/*
 *  text.h
 *
 *  $Id$
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
 */

#ifndef _TEXT_H
#define _TEXT_H

#include "sqlnode.h"

typedef struct d_id_u {
  dtp_t	id[32];
} d_id_t;


#define D_ID_64 0xfd /*marks that the next 8 bytes are a 8 byte numeric d_id */
#define D_ID32_MAX 0xfcffffff /* if unsigned int32 gt this, it is 64 */

#define D_ID_NUM_REF(place) \
  (  (((dtp_t*)(place))[0] == D_ID_64) \
     ? (unsigned int64)INT64_REF_NA (((db_buf_t)(place)) + 1)	\
     : (unsigned int64)(uint32)(LONG_REF_NA (place)))
/* #define FREETEXT_PORTABILITY_TEST */

#define D_ID_NUM_SET(place, id) \
{ \
  if ((unsigned int64) (id) > (unsigned int64)D_ID32_MAX) \
    { ((dtp_t*)(place))[0] = D_ID_64; \
      INT64_SET_NA ((((db_buf_t)(place)) + 1), ((int64) id)); \
    } else { \
    LONG_SET_NA ((place), (id)); \
  } \
}


#ifndef FREETEXT_PORTABILITY_TEST
typedef uint32 wpos_t; /* was uint32, then ptrlong then back to uint32 */
#define HUGE_WPOS_T 0xFFFFFFf0U
#define NEAR_DIST 100			/* Must be <= 0x7F */
#define HUGE_DIST 0x00FFFFFFU
#else
typedef unsigned short wpos_t;
#define HUGE_WPOS_T 0xFFf0U
#define NEAR_DIST 100			/* Must be <= 0x7F */
#define HUGE_DIST 0x00FFU
#endif

#define VT_ZERO_DIST_WEIGHT	100	/* Must be <= 0x7F */
#define VT_HALF_FADE_DIST	10	/* Distance at which the hit score is a half of VT_ZERO_DIST_WEIGHT, keep it some between 5 and 20. */


typedef struct wp_hit_s
  {
    wpos_t		h_1;
    wpos_t		h_2;
  } wp_hit_t;


#define REL_PROXIMITY 1


typedef struct word_rel_s
  {
    int				wrl_op;
    struct search_stream_s *	wrl_sst;
    int				wrl_pos;
    d_id_t			wrl_d_id;
    int				wrl_is_and;  /* if that and the related are AND'ed single word streams */
    int				wrl_dist;
    int				wrl_is_dist_fixed;
    int				wrl_is_lefttoright;
    wp_hit_t *			wrl_hits;
    int				wrl_max_hits;
    int				wrl_hit_fill;
    int				wrl_score;
  } word_rel_t;


typedef struct word_range_s
  {
    wpos_t	r_start;
    wpos_t	r_end;
  } word_range_t;


/* Translation context for sst_from_tree and similar */
struct sst_tctx_s
{
  query_instance_t	*tctx_qi;
  dbe_table_t		*tctx_table;
  struct vt_batch_s	*tctx_vtb;		/* batch used to find all words in the interval */
  ptrlong		tctx_calc_score;	/* Compile tree to enable accurate calculation of scores */
  ptrlong		tctx_range_flags;	/* Flags related to shift_4_xxx, WR-optimization, attribute indexing etc. */
  caddr_t		tctx_end_id;		/* do not seek beyond this in created word streams */
  int			tctx_descending;	/* created search streams should return results in descending order */
};

typedef struct sst_tctx_s sst_tctx_t;

#define SST_COMMON \
    int			sst_op; \
    d_id_t		 sst_d_id; \
    dk_set_t		sst_related; \
    caddr_t		sst_buffer; \
    int			sst_buffer_size; \
    int			sst_fill; \
    int			sst_pos; \
    short *		sst_pos_array; /* when reading reverse, need array of doc rec starts for reverse seq access */ \
    int			sst_nth_pos; \
    int			sst_raw_score; /* Hit count or the term score before applying a frequency correction and the statistical weight */ \
    int			sst_score;	/* Final corrected score */ \
    wpos_t		sst_view_from; /* do not process word positions smaller than this value */ \
    wpos_t		sst_view_to; /* do not process word positions larger than or equal to this value */ \
    word_range_t *	sst_all_ranges; \
    unsigned		sst_all_ranges_fill; \
    wpos_t		sst_all_from; \
    wpos_t		sst_all_to; \
    unsigned		sst_sel_startofs; \
    unsigned		sst_sel_count; \
    wpos_t		sst_sel_from; \
    wpos_t		sst_sel_to; \
    d_id_t		sst_range_d_id; \
    int			sst_need_ranges; \
    ptrlong		sst_range_flags; \
    int			sst_is_desc; \
    caddr_t		sst_error;


#define VT_DATA_MAX_DOC_STRINGS (2048 / 6) /* 300 max d_id's in a VT_DATA chunk, 2KB / 6 */

struct word_stream_s
  {
    SST_COMMON
    query_instance_t *	wst_qi;
    dbe_table_t *	wst_table;
    it_cursor_t *	wst_itc;
    caddr_t		wst_word;
    d_id_t		wst_first_d_id;
    d_id_t		wst_last_d_id;
    d_id_t		wst_seek_target;
    caddr_t		wst_seek_target_box;
    int			wst_reset_reason;
    caddr_t *		wst_word_strings;
    int			wst_nth_word_string;
    d_id_t		wst_end_id; /* do not seek beyond this */
    cl_req_group_t *	wst_clrg;
    cl_host_t *		wst_host;
    basket_t		wst_cl_word_strings; /* prefetched consecutive word strings from cluster */
    char		wst_all_fetched; /* all stuff is in word strings */
    char		wst_fixed_d_id; /* only the id sought  for and no other will do */
};

typedef struct word_stream_s word_stream_t;


#define WST_OFFBAND "\001"
#define WST_OFFBAND_CHAR '\001'

#if 0
#define WST_ATTRPOSS "\002"
#define WST_ATTRPOSS_CHAR '\002'
#endif

#define WRST_SKIP 1
#define WRST_AT_TARGET 2
#define WST_AHEAD_TARGET 3

#define SRC_WORD	1
#define SRC_NEAR XP_NEAR
#define SRC_WORD_CHAIN XP_WORD_CHAIN
#define SRC_ERROR -1

struct search_stream_s
  {
    SST_COMMON
    struct search_stream_s **	sst_terms;
    dk_set_t			sst_not;
    dk_set_t			sst_near_group_firsts;
};

typedef struct search_stream_s search_stream_t;

#define D_AT_END(d) (D_ID_NUM_REF(&(d)->id[0]) == 0)
#define D_INITIAL(d)  (D_ID_NUM_REF(&(d)->id[0]) == (int64)(0xFFFFFFFFFFFFfe30LL))
#define D_PRESET(d)  (D_ID_NUM_REF(&(d)->id[0]) == (unsigned int64)(0xFFFFFFFFFFFFfe20LL))
#define D_NEXT(d)  (D_ID_NUM_REF(&(d)->id[0]) == (unsigned int64)(0xFFFFFFFFFFFFfe10LL))

#define D_SET_AT_END(d) do { D_ID_NUM_SET(&(d)->id[0], 0); } while (0)
#define D_SET_INITIAL(d)  do { D_ID_NUM_SET(&(d)->id[0], (int64)(0xFFFFFFFFFFFFfe30LL)); } while (0)
#define D_SET_PRESET(d)  do { D_ID_NUM_SET(&(d)->id[0], (int64)(0xFFFFFFFFFFFFfe20LL)); } while (0)
#define D_SET_NEXT(d)  do { D_ID_NUM_SET(&(d)->id[0], (int64)(0xFFFFFFFFFFFFfe10LL)); } while (0)

#define D_ID_RESERVED_LEN(l) (((dtp_t) l) > 0xfb)

#define IS_GT(x) DVC_GREATER == (x)
#define IS_GTE(x) DVC_LESS != (x)
#define IS_LTE(x) DVC_GREATER != (x)
#define IS_LT(x) DVC_LESS == (x)



#define WP_MAX_8_BIT_LEN 200U
#define WP_32_BIT_LEN 0xFFU




#define WP_LENGTH_IMPL(wp, hl, l) \
do { \
  l = ((db_buf_t) (wp))[0]; \
  if (((unsigned)(l)) < WP_MAX_8_BIT_LEN) \
       hl = 1; \
  else if (l != WP_32_BIT_LEN) \
    { \
      l = (l - WP_MAX_8_BIT_LEN) * 256 + ((db_buf_t) (wp))[1]; \
      hl = 2; \
    } \
  else \
    { \
      hl = 5; \
      l = LONG_REF_NA (wp + 1); \
    } \
} while (0)

#ifdef WP_DEBUG
#define WP_LENGTH(wp, hl, l, buf, buf_size) \
  do { \
   if (((db_buf_t) (wp)) < ((db_buf_t) (buf))) \
     GPF_T1 ("WP_LENGTH: access before the beginning of the buffer"); \
   WP_LENGTH_IMPL(wp, hl, l); \
   if ((((db_buf_t) (wp)) + hl + l) > (((db_buf_t) (buf)) + (buf_size))) \
     GPF_T1 ("WP_LENGTH: danger of access past the end of buffer"); \
  } while (0)
#else
#define WP_LENGTH(wp, hl, l, buf, buf_size) WP_LENGTH_IMPL(wp, hl, l)
#endif


#define WP_D_ID 0
#define WP_FIRST_POS(l) \
  (((db_buf_t)l)[0] == DV_COMPOSITE ? ((db_buf_t)l)[1] + 2   \
   : (((db_buf_t)l)[0] == D_ID_64 ? 9 : 4))


#define VT_MAX_WORD_STRING_BYTES 2000

#define LAST_FTI_COL "VI_ENCODING"


struct wst_search_specs_s
{
  int wst_specs_are_initialized;
  search_spec_t wst_init_spec[1];
  search_spec_t wst_seek_spec[2];
  search_spec_t wst_seek_asc_seq_spec[2];	/* like wst_seek_spec but allow read ahead */
  search_spec_t wst_range_spec[1];
  search_spec_t wst_next_spec[2];
  search_spec_t wst_next_d_id_spec[2];

  key_spec_t	wst_ks_init;
  key_spec_t	wst_ks_seek;
  key_spec_t	wst_ks_seek_asc_seq;
  key_spec_t	wst_ks_range;
  key_spec_t	wst_ks_next;
  key_spec_t	wst_ks_next_d_id;
  out_map_t *	wst_out_map; /* cols returned from cluster read of a words table */
};

typedef struct wst_search_specs_s wst_search_specs_t;

void text_init (void);
/* no longer needed
dk_set_t vt_string_words  ( char *string, char * extra);
*/

#define WST_WILDCARD_MAX 1000

search_stream_t * sst_from_tree (sst_tctx_t *tctx, caddr_t * tree);

/* #define TA_SST_USE_VTB 1011
#define TA_SST_DESC_ORDER 1012
#define TA_SST_END_ID 1013
 */

/* if def'd sst_from_tree makes an sst tree referencing the vt_batch_t that is the value of this TA */

/* \brief Checks if there any matches to freetext pattern in given search stream

   If \c make_ranges, sst_range_hit is used to fill \c sst_all_ranges vector of ranges (and
   store vector's length in sst_all_ranges_fill).

   \returns if any matches were found.
 */
int sst_ranges (search_stream_t * sst, d_id_t * d_id, wpos_t from, wpos_t to, int make_ranges);

void sst_range_lists (search_stream_t * sst, dk_set_t * main_ranges, dk_set_t * attr_ranges);

#if 0
int string_word_count (char * string);
#endif

void d_id_set_box (d_id_t * d_id, caddr_t box);
void d_id_set (d_id_t * to, d_id_t * from);
caddr_t box_d_id (d_id_t * d_id);
int d_id_cmp (d_id_t * d1, d_id_t * d2);

extern int dbg_print_wpos_aux (FILE *out, wpos_t elt);
extern void dbg_print_d_id_aux (FILE *out, d_id_t *d_id_buf_ptr);


extern long  tft_random_seek;
extern long  tft_seq_seek;

wst_search_specs_t * wst_get_specs (dbe_key_t *key);
int wst_chunk_scan (word_stream_t * wst, db_buf_t chunk, int chunk_len);

void wst_cl_start (word_stream_t * wst);
void wst_cl_locate (word_stream_t * wst);
void wst_cl_next (word_stream_t * wst);
search_stream_t * wst_from_word (sst_tctx_t *tctx, ptrlong range_flags, const char *word);
search_stream_t * wst_cl_from_range (sst_tctx_t *tctx, ptrlong range_flags, const char * word, caddr_t lower, caddr_t higher);
search_stream_t * wst_from_wsts (sst_tctx_t *tctx, ptrlong range_flags, dk_set_t wsts);

#define NEW_SST(dt, v) \
  dt * v = (dt *) dk_alloc_box_zero (sizeof (dt), DV_TEXT_SEARCH);


#endif /* _TEXT_H */
