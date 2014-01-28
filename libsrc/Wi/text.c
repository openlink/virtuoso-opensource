/*
 *  text.c
 *
 *  $Id$
 *
 *  Text search
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

#include <limits.h>
#include "text.h"

#include "arith.h"
#include "bif_text.h"
#include "http_client.h"
#include "multibyte.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "xml.h"
#include "xmlgen.h"
#include "xmltree.h"
#include "xpathp_impl.h"
#include "qncache.h"

/*#define TEXT_DEBUG*/

unsigned char int_log2x16[0x100];
unsigned char vt_hit_dist_weight[0x100];


#define DBE_KEY_IS_INT_D_ID(key) (0 != (key)->key_key_fixed[0].cl_col_id)
#define ITC_IS_INT_D_ID(itc) DBE_KEY_IS_INT_D_ID((itc)->itc_row_key)

d_id_t * sst_next (search_stream_t * sst, d_id_t * target, int is_fixed);

static search_stream_t * wst_from_range (sst_tctx_t *tctx, ptrlong range_flags, const char * word, caddr_t lower, caddr_t higher);


int
d_id_cmp (d_id_t * d1, d_id_t * d2)
{
  if (d1->id[0] == DV_COMPOSITE && d2->id[0] == DV_COMPOSITE)
    {
      return (dv_composite_cmp (d1->id, d2->id, NULL, 0));

    }
  else if (d1->id[0] != DV_COMPOSITE && d2->id[0] != DV_COMPOSITE)
    {
      unsigned int64 n1 = D_ID_NUM_REF (&d1->id[0]);
      unsigned int64 n2 = D_ID_NUM_REF (&d2->id[0]);
      return (NUM_COMPARE (n1, n2));
    }
  if (d1->id[0] == DV_COMPOSITE)
    return DVC_GREATER;
  else
    return DVC_LESS;
}


int
sst_is_below (d_id_t * d1, d_id_t * d2, int desc)
{
  int rc = d_id_cmp (d1, d2);
  return (desc ? IS_GT (rc) : IS_LT (rc));
}


caddr_t
box_d_id (d_id_t * d_id)
{
  if (DV_COMPOSITE == d_id->id[0])
    {
      caddr_t box;
      int len = d_id->id[1];
      if (D_ID_RESERVED_LEN (len))
	len = 6; /* the D_AT_END, D_INITIAL etc special 4 byte values */
      box = dk_alloc_box (len + 2, DV_COMPOSITE);
      memcpy (box, &d_id->id[0], len + 2);
      return box;
    }
  else
    return (box_num (D_ID_NUM_REF (&d_id->id[0])));
}


void
d_id_set_box (d_id_t * d_id, caddr_t box)
{
  dtp_t dtp = DV_TYPE_OF (box);
  if (DV_COMPOSITE == dtp)
    {
      if (box_length (box) <= sizeof (d_id_t))
	memcpy (d_id, box, box_length (box));
      else
	D_SET_AT_END (d_id);
    }
  else if (DV_LONG_INT == dtp)
    {
      unsigned int64 n = (unsigned int64) unbox (box);
      if (n < 0xdf00000000000000ULL)
	{
	  D_ID_NUM_SET (&d_id->id[0], n);
	}
      else
	D_SET_AT_END (d_id);
    }
  else if (DV_RDF == dtp)
    {
      QNCAST (rdf_box_t, rb, box);
      unsigned int64 n = (unsigned int64) rb->rb_ro_id;
      if (n < 0xdf00000000000000ULL)
	{
	  D_ID_NUM_SET (&d_id->id[0], n);
	}
      else
	D_SET_AT_END (d_id);

    }
  else
    D_SET_AT_END (d_id);
}


void
d_id_set (d_id_t * to, d_id_t * from)
{
  if (from->id[0] == DV_COMPOSITE)
    {
      int len = from->id[1];
      if (D_ID_RESERVED_LEN (len))
	len = 6;
      memcpy (to, from, 2 + len);
    }
  else
    {
#ifdef WIN32
      D_ID_NUM_SET (&to->id[0], D_ID_NUM_REF (&from->id[0]));
#else
      if (D_ID_64 == ((dtp_t*)from)[0])
	memcpy (to, from, sizeof (int64) + 1);
      else
	memcpy (to, from, 4);
#endif
    }
}


void
wst_pos_array (word_stream_t * wst, db_buf_t page, int len)
{
  int pos = 0, afill = 0, l, hl;
  if (!wst->sst_pos_array)
    wst->sst_pos_array = (short*) dk_alloc_box (sizeof (short) * VT_DATA_MAX_DOC_STRINGS, DV_LONG_STRING);
  while (pos < len)
    {
      WP_LENGTH (page + pos, hl, l, page, len);
      wst->sst_pos_array[afill++] = pos;
      pos += hl + l;
    }
  wst->sst_nth_pos = afill - 1;
  wst->sst_pos = wst->sst_pos_array[wst->sst_nth_pos];
}


void
wst_set_buffer (word_stream_t * wst, db_buf_t page, int len)
{
  int copy_len;
  if (wst->sst_is_desc)
    {
      int l, hl;
      WP_LENGTH (page + wst->sst_pos, hl, l, page, len);
      copy_len = wst->sst_pos + hl + l;
      if (copy_len >= wst->sst_buffer_size)
	{
	  dk_free_box (wst->sst_buffer);
	  wst->sst_buffer = dk_alloc_box (copy_len + 1, DV_LONG_STRING);
	  wst->sst_buffer_size = copy_len;
	}
      memcpy (wst->sst_buffer, page, copy_len);
      wst->sst_buffer[copy_len] = '\0';	/* just to provide repeatable bugs on overflow */
      wst->sst_fill = copy_len;
    }
  else
    {
      copy_len = len - wst->sst_pos;
      if (copy_len >= wst->sst_buffer_size)
	{
	  dk_free_box (wst->sst_buffer);
	  wst->sst_buffer = dk_alloc_box (copy_len + 1, DV_LONG_STRING);
	  wst->sst_buffer_size = copy_len;
	}
      memcpy (wst->sst_buffer, page + wst->sst_pos, copy_len);
      wst->sst_buffer[copy_len] = '\0';	/* just to provide repeatable bugs on overflow */
      wst->sst_fill = copy_len;
      wst->sst_pos = 0; /* always 0 since copy starts at pos */
    }
}


void
d_id_num_col_ref (d_id_t * d_id, buffer_desc_t * buf, db_buf_t row, dbe_col_loc_t * cl)
{
  /* set d_id to the col'svalue, either 4 or 8 byte */
  if (DV_LONG_INT == cl->cl_sqt.sqt_dtp)
    {
      int32 n;
      ROW_INT_COL (buf, row, IE_ROW_VERSION (row), (*cl), LONG_REF, n);
      LONG_SET_NA (d_id->id, n);
    }
  else if (DV_INT64 == cl->cl_sqt.sqt_dtp)
    {
      int64 n;
      ROW_INT_COL (buf, row, IE_ROW_VERSION (row), (*cl), INT64_REF, n);
      if (n > D_ID32_MAX)
	{
	  d_id->id[0] = D_ID_64;
	  INT64_SET_NA (&d_id->id[1], n);
	}
      else
	{
	  LONG_SET_NA (&d_id->id[0], n);
	}
    }
  else
    GPF_T1 ("not a num d_id with text inx");
}


void
d_id_ref (d_id_t * d_id, db_buf_t p)
{
  GPF_T1 ("not supposed to call d_id_ref.  Uses pre 3.0 data layout");
  if (DV_LONG_INT == *p)
    {
      int32 n = LONG_REF_NA (p + 1);
      LONG_SET_NA (d_id->id, n);
    }
  else if (DV_COMPOSITE == *p)
    {
      int len = p[1];
      if (len > (int)(sizeof (d_id_t) - 2))
	len = sizeof (d_id_t) - 2;
      memcpy (d_id, p, len + 2);
      d_id->id[1] = len;
    }
  else if (DV_SHORT_INT == *p)
    {
      int32 n = ((signed char *)p)[1];
      LONG_SET_NA (d_id->id, n);
    }
  else
    {
      D_SET_AT_END (d_id);
    }
}

#define TXS_QST_SET(txs, qst, ssl, v) \
   do { \
      if ((txs)->src_gen.src_sets) \
	{ \
	  QNCAST (QI, qi, qst); \
	  int save_set = qi->qi_set; \
	  data_col_t * dc = QST_BOX (data_col_t *, qst, (ssl)->ssl_index); \
	  qi->qi_set = dc->dc_n_values; \
	  qst_vec_set (qst, ssl, v); \
	  qi->qi_set = save_set; \
	} \
      else \
	qst_set ((qst), (ssl), (v)); \
   } while (0)

int
itc_text_row (it_cursor_t * itc, buffer_desc_t * buf, dp_addr_t * leaf_ret)
{
  /* the row order is key_id, word, low_d_id, high_d_id, string, blob_string */
  key_ver_t kv;
  row_ver_t rv;
  word_stream_t * wst = itc->itc_wst;
  dbe_key_t *key;
  dtp_t dtp;
  int  rc;
  db_buf_t row = itc->itc_row_data;
  dp_addr_t leaf;
  caddr_t row_key_word;
  int d_id_is_int = ITC_IS_INT_D_ID(itc);
  dbe_col_loc_t *word_cl = &itc->itc_row_key->key_key_var[0];
  dbe_col_loc_t *d_id_cl = (d_id_is_int ?
    &itc->itc_row_key->key_key_fixed[0] :
    &itc->itc_row_key->key_key_var[1] );
  dbe_col_loc_t *d_id2_cl = (d_id_is_int ?
    &itc->itc_row_key->key_row_fixed[0] :
    &itc->itc_row_key->key_row_var[0] );
  dbe_col_loc_t *data1_cl = (d_id_is_int ?
    &itc->itc_row_key->key_row_var[0] :
    &itc->itc_row_key->key_row_var[1] );
  dbe_col_loc_t *data2_cl = (d_id_is_int ?
    &itc->itc_row_key->key_row_var[1] :
    &itc->itc_row_key->key_row_var[2] );
  short data_off, data_len;
#ifdef TEXT_DEBUG
/*  dbg_page_map (buf); */
#endif
  row = buf->bd_buffer + buf->bd_content_map->pm_entries[itc->itc_map_pos];
  kv = IE_KEY_VERSION (row);
  if (KV_LEFT_DUMMY == kv)
    {
      if (itc->itc_desc_order)
	{
	  /* when going in reverse always descend into the leftmost leaf */
	  leaf = LONG_REF (row + LD_LEAF);
	  if (leaf)
	    {
	      *leaf_ret = leaf;
	      return DVC_MATCH;
	    }
	}
/*!!!      goto next_row;*/
    }
/* Check for nulls */
  if (ITC_NULL_CK(itc, word_cl[0]))
    return DVC_GREATER; /* NULL word */
  if (DV_STRING != word_cl->cl_sqt.sqt_dtp)
    GPF_T1("invalid type of VT_WORD");
  rv = IE_ROW_VERSION (row);
  key = itc->itc_row_key;
  row_key_word = itc_box_column (itc, buf, 0, word_cl);
  rc = strcmp (row_key_word, wst->wst_word);
  dk_free_box (row_key_word);
  if (0 != rc)
    {
      goto cond_boundary;
    }
  if (d_id_is_int)
    d_id_num_col_ref (&wst->wst_first_d_id, buf, row, d_id_cl);
  else
    d_id_ref (&wst->wst_first_d_id, row);
  if (d_id_is_int)
    d_id_num_col_ref (&wst->wst_last_d_id, buf, row, d_id2_cl);
  else
    d_id_ref (&wst->wst_last_d_id, row);
  if (!D_INITIAL (&wst->wst_seek_target))
    {
      if ((!wst->sst_is_desc &&  IS_GT (d_id_cmp (&wst->wst_seek_target, &wst->wst_last_d_id)))
	  || (wst->sst_is_desc && IS_LT (d_id_cmp (&wst->wst_seek_target, &wst->wst_first_d_id))))
	return DVC_LESS;
    }
  wst->sst_pos = 0;
  if (!ITC_NULL_CK(itc, data1_cl[0]))
    {
      KEY_PRESENT_VAR_COL(key, row, data1_cl[0], data_off, data_len);
      rc = wst_chunk_scan (wst, row + data_off, data_len);
      if (DVC_MATCH == rc)
	{
	  wst_set_buffer (wst, row + data_off, data_len);
	  return rc;
	}
    }
  else if (!ITC_NULL_CK(itc, data2_cl[0]))
    {
      KEY_PRESENT_VAR_COL(key, row, data2_cl[0], data_off, data_len);
      dtp = row[data_off];
      if (DV_LONG_STRING == dtp || DV_SHORT_STRING == dtp)
	{
	  rc = wst_chunk_scan (wst, row + data_off+1, data_len-1);
	  if (DVC_MATCH == rc)
	    {
	      wst_set_buffer (wst, row + data_off+1, data_len-1);
	      return rc;
	    }
	}
      else
	{
	  caddr_t blob, bh;
	  if (DV_BLOB != dtp)
	    return DVC_GREATER;
	  bh = itc_box_column (itc, buf, 0, data2_cl);
	  blob = blob_to_string (itc->itc_ltrx, bh);
	  dk_free_box (bh);
	  rc = wst_chunk_scan (wst, (db_buf_t) blob, box_length (blob) - 1);
	  if (DVC_MATCH == rc)
	    {
	      dk_free_box (wst->sst_buffer);
	      wst->sst_buffer = blob;
	      wst->sst_buffer_size = box_length (blob);
	      wst->sst_fill = wst->sst_buffer_size - 1;
	    }
	  else
	    dk_free_box (blob);
	  return rc;
	}
    }
  return DVC_LESS;
cond_boundary:
  if (itc->itc_desc_order)
    {
      *leaf_ret = leaf_pointer (row, itc->itc_insert_key);
      if (*leaf_ret)
	return DVC_MATCH;
    }
  return DVC_GREATER;
}


int
itc_text_search (it_cursor_t * it, buffer_desc_t ** buf_ret, dp_addr_t * leaf_ret)
{
  db_buf_t row, page = (*buf_ret)->bd_buffer;
  dp_addr_t leaf = 0;
  key_ver_t kv;
  int res = DVC_LESS;
  char txn_clear = PS_LOCKS;

  if (ISO_UNCOMMITTED == it->itc_isolation)
    txn_clear = PS_OWNED;
  else if (ISO_COMMITTED == it->itc_isolation)
    {
      if (!it->itc_pl)
	txn_clear = PS_OWNED;
    }
  else if (ISO_REPEATABLE == it->itc_isolation)
    {
      if (!it->itc_pl)
	{
	  txn_clear = PS_NO_LOCKS;
	}
    }

  while (1)
    {
      if (ITC_AT_END == it->itc_map_pos)
	{
	  *leaf_ret = 0;
	  return DVC_INDEX_END;
	}
      if ((*buf_ret)->bd_content_map->pm_entries[it->itc_map_pos] >= PAGE_SZ)
	GPF_T;			/* Link over page end */

      if (PS_LOCKS == txn_clear)
	{
	  if (it->itc_owns_page != it->itc_page)
	    {
	      if (it->itc_isolation == ISO_SERIALIZABLE
		  || (it->itc_isolation > ISO_COMMITTED && ITC_MAYBE_LOCK (it, it->itc_map_pos)))
		{
		  for (;;)
		    {
		      int wrc = itc_landed_lock_check (it, buf_ret);
		      if (ISO_SERIALIZABLE == it->itc_isolation
			  || NO_WAIT == wrc)
			break;
		      /* passing this means for a RR cursor that a subsequent itc_set_lock_on_row is
		       * GUARANTEED to be with no wait. Needed not to run itc_row_check side effect twice */
		      wrc = wrc;  /* breakpoint here */
		    }
		  page = (*buf_ret)->bd_buffer;
		  if (ITC_AT_END == it->itc_map_pos)
		    {
		      /* The row may have been deleted during lock wait.
		       * if this was the last row, the itc_position will have been set to 0 */
		      *leaf_ret = 0;
		      return DVC_INDEX_END;
		    }
		}
	    }
	  else
	    txn_clear = PS_OWNED;
	}

      row = page + (*buf_ret)->bd_content_map->pm_entries[it->itc_map_pos];
      kv = IE_KEY_VERSION (row);
      if (KV_LEFT_DUMMY == kv)
	{
	  if (it->itc_desc_order)
	    {
	      /* when going in reverse always descend into the leftmost leaf */
	      leaf = LONG_REF (row + LD_LEAF);
	      if (leaf)
		{
		  *leaf_ret = leaf;
		  return DVC_MATCH;
		}
	    }
	  goto next_row;
	}
      if (!kv)
	{
	  *leaf_ret = LONG_REF (row + it->itc_insert_key->key_key_leaf[IE_ROW_VERSION (row)]);
	  it->itc_row_data = row;
	  return DVC_MATCH;
	}
      else
	{
	  it->itc_row_data = row;
	  it->itc_at_data_level = 1;
	  leaf = 0;
#ifdef DEBUG
	  if (!it->itc_row_key /*|| it->itc_row_key->key_id != key_id*/)
	    {
/*
	    it->itc_row_key = sch_id_to_key (wi_inst.wi_schema, key_id);
*/
	      GPF_T;
	    }
#endif
	}

      if (IE_ISSET (row, IEF_DELETE))
	goto next_row;
      *leaf_ret = 0;
      res = itc_text_row (it, *buf_ret, leaf_ret);
      if (DVC_GREATER == res)
	return DVC_GREATER;
      if (!*leaf_ret)
	it->itc_at_data_level = 1;
      else
	return DVC_MATCH;
      if (! *leaf_ret && res == DVC_MATCH)
	{
	  KEY_TOUCH (it->itc_insert_key);
	  return DVC_MATCH;
	  /* if there's a lesser leaf ptr, go down if desc order.
	   * The end is when you hit a lesser leaf */
	}
      /* Next entry on page */

    next_row:
      ITC_MARK_ROW (it);
      if (it->itc_desc_order)
	{
	  itc_prev_entry (it, *buf_ret);
	}
      else
	{
	  itc_skip_entry (it, *buf_ret);
	}
    }
}



#define WP_NEXT(p, pos, end) \
{ \
  if (p >= end) \
    pos = -1; \
  else \
    { \
      WP_LENGTH (p, __hl, __d, p, end-p); \
      p += __hl; \
      pos += __d; \
  } \
}



#define HIT(pos1, pos2) \
if (pos1 != pos2) \
{ \
  rel->wrl_score++; \
  if (rel->wrl_hit_fill < rel->wrl_max_hits) \
    { \
      rel->wrl_hits[rel->wrl_hit_fill].h_1 = pos1; \
      rel->wrl_hits[rel->wrl_hit_fill++].h_2 = pos2;  \
    } \
}


/* Proximity check for hits of words that are in a phrase or NEAR */
int
wp_proximity (db_buf_t p1, int l1, db_buf_t p2, int l2,
	      word_rel_t * rel)
{
  int prev;
  int dist = rel->wrl_dist;
  int is_dist_fixed = rel->wrl_is_dist_fixed;
  int is_lefttoright = rel->wrl_is_lefttoright;
  int __hl, __d;
  int pos1 = 0, pos2 = 0;
  db_buf_t end1, end2;
  if (!dist && !is_dist_fixed)
    {
      /* This word_rel_t can be refd within proximity group but no proximity between these 2 terms */
      rel->wrl_score = 1;
      return 1;
    }
  if (is_lefttoright && 0 > dist)
    {
      db_buf_t pt = p1;
      int lt = l1;
      l1 = l2;
      p1 = p2;
      p2 = pt;
      l2 = lt;
      dist = -dist;
    }
  end1 = p1 + l1;
  end2 = p2 + l2;
  rel->wrl_hit_fill = 0;
  rel->wrl_score = 0;
  WP_NEXT (p1, pos1, end1);
  WP_NEXT (p2, pos2, end2);
  if (is_lefttoright)
    {
      for (;;)
	{
	  if (pos1 == -1 || pos2 == -1)
	    return (rel->wrl_score);
	  if (is_dist_fixed ? (pos2 == (pos1 + dist)) : ((pos1 <= pos2) && (pos2 <= (pos1 + dist))))
	    {
	      HIT (pos1, pos2);
	      WP_NEXT (p1, pos1, end1);
	      WP_NEXT (p2, pos2, end2);
	      continue;
	    }
	  if (pos2 <= (pos1 + dist))
	    {
	      WP_NEXT (p2, pos2, end2);
	    }
	  else
	    {
	      WP_NEXT (p1, pos1, end1);
	    }
	}
    }
  for (;;)
    {
      if (pos1 < pos2)
	{
	next_pos1:
	  prev = pos1;
	  WP_NEXT (p1, pos1, end1);
	  if (-1 == pos1)
	    {
	      if (pos2 < (prev + dist))
		{
		  HIT (prev, pos2);
		}
	      return (rel->wrl_score);
	    }
	  if (pos1 <= pos2)
	    goto next_pos1;
	  if (pos1 > pos2)
	    {
	      if (pos1 < (pos2 + dist))
		HIT (pos1, pos2);
	      continue;
	    }
	}
      else
	{
	next_pos2:
	  prev = pos2;
	  WP_NEXT (p2, pos2, end2);
	  if (-1 == pos2)
	    {
	      if (pos1 < (prev + dist))
		{
		  HIT (prev, pos1);
		}
	      return (rel->wrl_score);
	    }
	  if (pos2 <= pos1)
	    goto next_pos2;
	  if (pos2 > pos1)
	    {
	      if (pos2 < (pos1 + dist))
		HIT (pos2, pos1);
	      continue;
	    }
	}
    }

  /*NOTREACHED*/
  return rel->wrl_score;
}


int
wst_seek_d_id (word_stream_t * wst, d_id_t * target, db_buf_t * pos_ret,
	       int * len_ret, d_id_t * next_d_id_ret)
{
  db_buf_t buf = (db_buf_t) wst->sst_buffer;
  int pos = wst->sst_pos, first_pos, rc;
  while (pos < wst->sst_fill && pos != -1)
    {
      d_id_t * d_id;
      int l, hl;
      WP_LENGTH (buf + pos, hl, l, buf, wst->sst_buffer_size);
      d_id =  (d_id_t *) (buf + hl + pos);
      rc = d_id_cmp (d_id, target);
      if (DVC_MATCH == rc)
	{
	  wst->sst_pos = pos;
	  d_id_set (&wst->sst_d_id, d_id);
	  first_pos = WP_FIRST_POS (buf + pos + hl);
	  *pos_ret = buf + pos + hl + first_pos;
	  *len_ret = l - first_pos;
	  return 1;
	}
      if ((DVC_LESS == rc && !wst->sst_is_desc)
	  || (DVC_GREATER == rc && wst->sst_is_desc))
	{
	  if (!wst->sst_is_desc)
	    pos += l + hl;
	  else
	    {
	      wst->sst_nth_pos--;
	      if (wst->sst_nth_pos >= 0)
		pos = wst->sst_pos_array[wst->sst_nth_pos];
	      else
		pos = -1;
	      wst->sst_pos = pos;
	    }
	  continue;
	}
      wst->sst_pos = pos;
      d_id_set (&wst->sst_d_id, d_id);
      d_id_set (next_d_id_ret, d_id);
      return 0;
    }
  return 0;
}


int
wst_check_related (word_stream_t * wst, db_buf_t buf, d_id_t * d_id, int pos)
{
  db_buf_t positions;
  int pos_len, l, hl;
  if (!wst->sst_related)
    return 1;
  WP_LENGTH (buf + pos, hl, l, buf, box_length (buf) - 1);
  positions = buf + pos + hl + WP_FIRST_POS(buf + pos + hl);
  pos_len = l - WP_FIRST_POS (buf + pos + hl);
  DO_SET(word_rel_t *, rel, &wst->sst_related)
    {
      word_stream_t * rel_st = (word_stream_t *) rel->wrl_sst;
      if (SRC_WORD == rel_st->sst_op)
	{
	  if (!D_INITIAL (&rel_st->wst_first_d_id)
	      && IS_LTE (d_id_cmp (&rel_st->wst_first_d_id, d_id)) && IS_GTE (d_id_cmp (&rel_st->wst_last_d_id, d_id)))
	    {
	      d_id_t next_target;
	      db_buf_t rel_pos;
	      int rel_pos_len;
	      D_SET_AT_END (&next_target);
	      if (wst_seek_d_id (rel_st, d_id, &rel_pos, &rel_pos_len,
				 &next_target))
		{
		  if (rel->wrl_dist)
		    {
		      wp_proximity (positions, pos_len, rel_pos, rel_pos_len, rel);
		      if (0 == rel->wrl_score)
			return 0;
		    }
		  else
		    rel->wrl_score = 1;
		  d_id_set (&rel->wrl_d_id, d_id);
		}
	      else
		{
		  if (! D_AT_END (&next_target))
		    d_id_set (&wst->wst_seek_target,  &next_target);
		  return 0;
		}
	    }
	}
    }
  END_DO_SET();
  return 1;
}


int
wst_chunk_scan_rev (word_stream_t * wst, db_buf_t buf, int chunk_len)
{
  d_id_t target;
  d_id_t * d_id;
  int pos, pos_inx;
  int match_any;
  d_id_set (&target, &wst->wst_seek_target);
  match_any  = D_INITIAL (&target) || D_NEXT (&target);
  if (!match_any && IS_LT (d_id_cmp (&target, &wst->wst_first_d_id)))
    return DVC_LESS;
  if (!buf)
    buf = (db_buf_t) wst->sst_buffer;
  else
    {
      wst_pos_array (wst, buf, chunk_len);
    }
  pos_inx = wst->sst_nth_pos;
  pos = wst->sst_pos_array[pos_inx];
  if (D_NEXT (&target) && pos_inx >= 0)
    {
      pos_inx--;
      wst->sst_nth_pos = pos_inx;
      if (pos_inx >= 0)
	pos = wst->sst_pos_array[pos_inx];
      else
	pos = -1;
    }
  while (pos_inx >= 0)
    {
      int hl, l;
      WP_LENGTH (buf + pos, hl, l, buf, chunk_len);
      wst->sst_pos = pos;
      d_id = (d_id_t *) (buf + pos + hl);
      d_id_set (&wst->sst_d_id, d_id);
      if (!match_any && IS_GT (d_id_cmp (d_id, &target)))
	{
	  pos_inx--;
	  wst->sst_nth_pos = pos_inx;
	  if (pos_inx >= 0)
	    pos = wst->sst_pos_array[pos_inx];
	  continue;
	}
      else
	{
	  if (wst_check_related (wst, buf, d_id, pos))
	    return DVC_MATCH;
	  if (DVC_MATCH != d_id_cmp (&target, &wst->wst_seek_target))
	    {
	      d_id_set (&target, &wst->wst_seek_target);
	      if (IS_LT (d_id_cmp (&target, &wst->wst_first_d_id)))
		return DVC_LESS;
	    }
	}
      pos_inx--;
      wst->sst_nth_pos = pos_inx;
      if (pos_inx >= 0)
	pos = wst->sst_pos_array[pos_inx];
    }
  wst->sst_pos = pos;
  return DVC_LESS;
}


int
wst_chunk_scan (word_stream_t * wst, db_buf_t buf, int chunk_len)
{
  d_id_t target;
  d_id_t * d_id;
  int pos;
  int hl, l;
  int match_any;
  if (wst->sst_is_desc)
    return (wst_chunk_scan_rev (wst, buf, chunk_len));
  if (!buf)
    buf = (db_buf_t) wst->sst_buffer;
  d_id_set (&target, &wst->wst_seek_target);
    match_any = D_INITIAL (&target) || D_NEXT (&target);
  if (!match_any && IS_GT (d_id_cmp (&target, &wst->wst_last_d_id)))
    return DVC_LESS;
  pos = wst->sst_pos;
  if (D_NEXT (&target) && pos < chunk_len)
    {
      WP_LENGTH (buf + pos, hl, l, buf, chunk_len);
      pos += l + hl;
      wst->sst_pos = pos;
    }
  while (pos < chunk_len)
    {
      WP_LENGTH (buf + pos, hl, l, buf, chunk_len);
      wst->sst_pos = pos;
      d_id = (d_id_t *) (buf + pos + hl);
      d_id_set (&wst->sst_d_id, d_id);
      if (!match_any && IS_LT (d_id_cmp (d_id, &target)))
	{
	  pos += l + hl;
	  continue;
	}
      else
	{
	  if (wst_check_related (wst, buf, d_id, pos))
	    return DVC_MATCH;
	  if (DVC_MATCH != d_id_cmp (&target, &wst->wst_seek_target))
	    {
	      d_id_set (&target, &wst->wst_seek_target);
	      if (IS_GT (d_id_cmp (&target, &wst->wst_last_d_id)))
		return DVC_LESS;
	    }
	}
      pos += l + hl;
      wst->sst_pos = pos;
    }
  wst->sst_pos = pos;
  return DVC_LESS;
}


static wst_search_specs_t wst_int_key_search_specs;
static wst_search_specs_t wst_int64_key_search_specs;
static wst_search_specs_t wst_any_key_search_specs;
static dk_mutex_t * wst_get_specs_mtx;

wst_search_specs_t *
wst_get_specs (dbe_key_t *key)
{
  search_spec_t *ss;
  int key_is_int_d_id = DBE_KEY_IS_INT_D_ID(key);
  int key_is_int64_d_id = key_is_int_d_id ? key->key_key_fixed[0].cl_sqt.sqt_dtp == DV_INT64 : 0;
  wst_search_specs_t *res = key_is_int64_d_id ? &wst_int64_key_search_specs : (key_is_int_d_id ? &wst_int_key_search_specs : &wst_any_key_search_specs);
  dbe_col_loc_t *word_cl;
  dbe_col_loc_t *d_id_cl;
  if (res->wst_specs_are_initialized)
    return res;

  mutex_enter (wst_get_specs_mtx);

  word_cl = &(key->key_key_var[0]);
  d_id_cl = (key_is_int_d_id ?
    &(key->key_key_fixed[0]) :
    &(key->key_key_var[1]) );

#define SS_ASSIGN(cl,minop,minarg,maxop,maxarg) \
  ss->sp_cl = (cl); \
  ss->sp_min_op = (minop);	ss->sp_min = (minarg); \
  ss->sp_max_op = (maxop);	ss->sp_max = (maxarg); \

#define SS_ADVANCE ss->sp_next = ss+1; ss++

  ss = res->wst_init_spec;		SS_ASSIGN(word_cl[0]	,CMP_EQ	,+0	,0	,0	);

  ss = res->wst_seek_spec;		SS_ASSIGN(word_cl[0]	,CMP_EQ	,+0	,0	,0	);
  SS_ADVANCE;				SS_ASSIGN(d_id_cl[0]	,0	,0	,CMP_LTE,+1	);

  ss = res->wst_seek_asc_seq_spec;	SS_ASSIGN(word_cl[0]	,CMP_EQ ,+0	,0	,0	);
  SS_ADVANCE;				SS_ASSIGN(d_id_cl[0]	,CMP_GTE,+1	,0	,0	);

  ss = res->wst_range_spec;		SS_ASSIGN(word_cl[0]	,CMP_GT	,+0	,CMP_LT	,+1	);

  ss = res->wst_next_spec;		SS_ASSIGN(word_cl[0]	,CMP_EQ	,+0	,0	,0	);
  SS_ADVANCE;				SS_ASSIGN(d_id_cl[0]	,CMP_GT	,+1	,0	,0	);

  ss = res->wst_next_d_id_spec;		SS_ASSIGN(word_cl[0]	,CMP_EQ	,+0	,0	,0	);

#define WST_KSP(name) \
  res->wst_ks_##name .ksp_spec_array = &res->wst_##name##_spec[0]; \
  ksp_cmp_func (&res->wst_ks_##name, NULL);

  WST_KSP (init);
  WST_KSP (seek);
  WST_KSP (seek_asc_seq);
  WST_KSP (range);
  WST_KSP (next);
  WST_KSP (next_d_id);
  res->wst_out_map = (out_map_t *)dk_alloc_box (sizeof (out_map_t) * 4, DV_STRING);
  memset (res->wst_out_map, 0, box_length ((caddr_t) res->wst_out_map));

  if (key_is_int_d_id)
    {
      res->wst_out_map[0].om_cl = key->key_key_fixed[0];
      res->wst_out_map[1].om_cl = key->key_row_fixed[0];
      res->wst_out_map[2].om_cl = key->key_row_var[0];
      res->wst_out_map[3].om_cl = key->key_row_var[1];
    }
  else
    GPF_T1 ("not supporting composite d_id's");
  res->wst_specs_are_initialized = 1;
  mutex_leave (wst_get_specs_mtx);
  return res;
}


#define TEXT_ITC_INIT(itc, qi) \
  itc->itc_isolation = qi->qi_isolation; \
  itc->itc_search_mode = SM_READ; \
  itc->itc_lock_mode = PL_SHARED; \
  itc->itc_ltrx = qi->qi_trx; /* qi can be contd w different clis in cl */


int
wst_random_seek (word_stream_t * wst)
{
  d_id_t target = wst->wst_seek_target;
  int rc;
  buffer_desc_t * buf;
  query_instance_t * qi = wst->wst_qi;
  it_cursor_t * volatile itc = wst->wst_itc;
  wst_search_specs_t *specs;
  int spec_is_seek;
  if (!itc)
    {
      itc = itc_create (QI_SPACE(qi), qi->qi_trx);
    }
  TEXT_ITC_INIT (itc, qi);
  itc_from (itc, wst->wst_table->tb_primary_key, qi->qi_client->cli_slice);
  specs = wst_get_specs(itc->itc_row_key);

  if (D_NEXT (&target))
    D_SET_INITIAL (&target);
  if (D_INITIAL (&target))
    {
      spec_is_seek = 0;
      itc->itc_key_spec = specs->wst_ks_init;
      itc->itc_desc_order = wst->sst_is_desc;
    }
  else
    {
      tft_random_seek++;
      spec_is_seek = 1;
      itc->itc_key_spec = specs->wst_ks_seek;
      itc->itc_desc_order = 1;
    }
  dk_free_box (wst->wst_seek_target_box);
  wst->wst_seek_target_box = box_d_id (&wst->wst_seek_target);

  ITC_SEARCH_PARAM (itc, wst->wst_word);
  ITC_SEARCH_PARAM (itc, wst->wst_seek_target_box);

  ITC_FAIL (itc)
    {
      itc->itc_wst = NULL;
      buf = itc_reset (itc);
      rc = itc_search (itc, &buf);
      if (DVC_MATCH != rc)
	{
	  itc_page_leave (itc, buf);
	  itc_free (itc);
	  wst->wst_itc = NULL;
	  D_SET_AT_END (&wst->sst_d_id);
	  return DVC_GREATER;
	}
      itc->itc_desc_order = wst->sst_is_desc;
      if (spec_is_seek && !itc->itc_desc_order)
	itc->itc_key_spec = specs->wst_ks_seek_asc_seq;
      itc->itc_wst = wst;
      itc->itc_is_on_row = 0;
      rc = itc_next (itc, &buf);
      if (DVC_MATCH != rc)
	{
	  itc_page_leave (itc, buf);
	  itc_free (itc);
	  wst->wst_itc = NULL;
	  D_SET_AT_END (&wst->sst_d_id);
	  return DVC_GREATER;
	}
      itc_register (itc, buf);
      itc_page_leave (itc, buf);
      wst->wst_itc = itc;
      return DVC_MATCH;
    }
  ITC_FAILED
    {
      wst->wst_itc = NULL;
      itc_free (itc);
      D_SET_AT_END (&wst->sst_d_id);
    }
  END_FAIL (itc);
  return DVC_GREATER;
}



caddr_t wst_itc_col_word (it_cursor_t * itc, buffer_desc_t * buf)
{
  dbe_col_loc_t *cl = &itc->itc_row_key->key_key_var[0];
  return itc_box_column (itc, buf, 0, cl);
}

caddr_t wst_itc_col_d_id (it_cursor_t * itc, buffer_desc_t * buf)
{
  dbe_col_loc_t *cl;
  if (ITC_IS_INT_D_ID(itc))
    cl = &itc->itc_row_key->key_key_fixed[0];
  else
    cl = &itc->itc_row_key->key_key_var[1];
  return itc_box_column (itc, buf, 0, cl);
}

caddr_t wst_itc_col_d_id2 (it_cursor_t * itc, buffer_desc_t * buf)
{
  dbe_col_loc_t *cl;
  if (ITC_IS_INT_D_ID(itc))
    cl = &itc->itc_row_key->key_row_fixed[0];
  else
    cl = &itc->itc_row_key->key_row_var[0];
  return itc_box_column (itc, buf, 0, cl);
}

caddr_t wst_itc_col_data (it_cursor_t * itc, buffer_desc_t * buf)
{
  dbe_col_loc_t *cl;
  if (ITC_IS_INT_D_ID(itc))
    cl = &itc->itc_row_key->key_row_var[0];
  else
    cl = &itc->itc_row_key->key_row_var[1];
  return itc_box_column (itc, buf, 0, cl);
}

caddr_t wst_itc_col_long_data (it_cursor_t * itc, buffer_desc_t * buf)
{
  dbe_col_loc_t *cl;
  if (ITC_IS_INT_D_ID(itc))
    cl = &itc->itc_row_key->key_row_var[1];
  else
    cl = &itc->itc_row_key->key_row_var[2];
  return itc_box_column (itc, buf, 0, cl);
}


it_cursor_t *
wst_range_itc (sst_tctx_t *tctx, const char * word, caddr_t *lower, caddr_t higher)
{
  /* get first word > lower and < higher and like word. Return this word as *lower.
   * return the cursor positioned at first record of that word */
  buffer_desc_t * buf;
  query_instance_t *qi = tctx->tctx_qi;
  it_cursor_t * itc = itc_create (QI_SPACE(qi), qi->qi_trx);
  wst_search_specs_t *specs;
  int lower_offs = 0;
  caddr_t lcopy = box_copy(*lower);
  TEXT_ITC_INIT (itc, qi);
  itc_from (itc, tctx->tctx_table->tb_primary_key, qi->qi_client->cli_slice);
  specs = wst_get_specs(itc->itc_row_key);
  itc->itc_key_spec = specs->wst_ks_range;
  lower_offs = (int) itc->itc_search_par_fill; /* Ensure the offset of lower limit */
  ITC_SEARCH_PARAM (itc, lcopy);
  ITC_SEARCH_PARAM (itc, higher);
  ITC_FAIL (itc)
    {
      for (;;)
	{
	  int rc;
	  char * hit = NULL;
	  itc->itc_wst = NULL;
	  buf = itc_reset (itc);
	  rc = itc_search (itc, &buf);
	  dk_free_box (itc->itc_search_params[lower_offs]); /* lower limit */
	  if (DVC_MATCH != rc)
	    {
	      itc_page_leave (itc, buf);
	      itc_free (itc);
	      return NULL;
	    }
	  hit = wst_itc_col_word (itc, buf);
	  if (DVC_MATCH == cmp_like (hit, word, NULL, 0, LIKE_ARG_CHAR, LIKE_ARG_CHAR))
	    {
	      *lower = hit;
	      itc_register (itc, buf);
	      itc_page_leave (itc, buf);
	      return itc;
	    }
	  itc_page_leave (itc, buf);
	  itc->itc_search_params[lower_offs] = hit;
	}
    }
 ITC_FAILED
    {
      itc_free (itc);
    }
  END_FAIL (itc);
  return NULL;
}


caddr_t
bif_vt_words_next_d_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* given a cursor on a copy of vt_words, get the next chunk's d_id */
  volatile int rc = 0;
  buffer_desc_t * buf;
  query_instance_t * qi = (query_instance_t*) qst;
  caddr_t tb_name = bif_string_arg (qst, args, 0, "vt_words_next_d_id");
  dbe_table_t * tb = sch_name_to_table (isp_schema (qi->qi_space), tb_name);
  char * cr_name = bif_string_arg (qst, args, 1, "vt_words_next_d_id");
  caddr_t word = bif_string_arg (qst, args, 2, "vt_words_next_d_id");
/*
  caddr_t d_id_box = bif_arg (qst, args, 3, "vt_words_next_d_id");
*/
  volatile caddr_t res = NULL;
  state_slot_t * cr_ssl = NULL;
  placeholder_t * pl = NULL;
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  wst_search_specs_t *specs;
  if (!tb)
    sqlr_new_error ("S0002", "FT002", "bad table for vt_words_next_d_id");
  ITC_INIT (itc, qi->qi_space, qi->qi_trx);
  DO_SET (state_slot_t *, ssl, &qi->qi_query->qr_state_map)
    {
      if (SSL_ITC == ssl->ssl_type || SSL_PLACEHOLDER == ssl->ssl_type)
	{
	  if  (ssl->ssl_name && 0 == strcmp (ssl->ssl_name, cr_name))
	    {
	      cr_ssl = ssl;
	      break;
	    }
	}
    }
  END_DO_SET ();
  if (!cr_ssl)
    sqlr_new_error ("09000", "FT040", "No cursor for vt_words_next_d_id");
  pl = (placeholder_t *) qst_get (qst, cr_ssl);
  if (!pl || !pl->itc_is_registered)
    sqlr_new_error ("24000", "FT004", "cursor in vt_words_next_d_id is not open or not on row");
  itc_from (itc, tb->tb_primary_key, qi->qi_client->cli_slice);
  specs = wst_get_specs (itc->itc_row_key);
  itc->itc_key_spec = specs->wst_ks_next_d_id;
  ITC_SEARCH_PARAM (itc, word);
  ITC_FAIL (itc)
    {
      buf = itc_set_by_placeholder (itc, pl);
      itc->itc_desc_order = 0; /* the pl is from a desc itc, this one goes fwd */
      rc = itc_next (itc, &buf);
    }
  ITC_FAILED
    {
    }
  END_FAIL (itc);
  if (DVC_MATCH == rc)
    {
      res = wst_itc_col_d_id (itc, buf);
    }
  itc_page_leave (itc, buf);
  itc_free (itc);
  return (res ? res : box_num (0));
}

int
wst_seq_seek (word_stream_t * wst)
{
  int rc;
  buffer_desc_t * buf;
  it_cursor_t * itc = wst->wst_itc;
  if (!itc)
    {
      D_SET_AT_END (&wst->sst_d_id);
      return DVC_GREATER;
    }
  itc->itc_ltrx = wst->wst_qi->qi_trx; /* qi can be contd w different clis in cl */
  ITC_FAIL (itc)
    {
      tft_seq_seek++;
      if (!itc->itc_buf_registered)
	{
	  log_error ("full text itc not registered at continue, can be dfgcontinue coming after anytime reset");
	  itc_free (itc);
	  wst->wst_itc = NULL;
	  D_SET_AT_END (&wst->sst_d_id);
	  return DVC_GREATER;
	}
      buf = page_reenter_excl (wst->wst_itc);
      rc = itc_next (itc, &buf);
      if (DVC_MATCH != rc)
	{
	  itc_page_leave (itc, buf);
	  itc_free (itc);
	  wst->wst_itc = NULL;
	  D_SET_AT_END (&wst->sst_d_id);
	  return DVC_GREATER;
	}
      if (WRST_SKIP == wst->wst_reset_reason)
	{
	  itc_page_leave (itc, buf);
	  return (wst_random_seek (wst));
	}
      itc_register (itc, buf);
      itc_page_leave (itc, buf);
    }
  ITC_FAILED
    {
      itc_free (itc);
      wst->wst_itc = NULL;
      D_SET_AT_END (&wst->sst_d_id);
    }
  END_FAIL (wst->wst_itc);
  return DVC_MATCH;
}


#define INT_REF(dv)\
  (  (*(dv) == DV_SHORT_INT) ? (long) ((signed char*)dv)[1] : LONG_REF_NA ((dv) + 1))


double
composite_diff (db_buf_t dv1, db_buf_t dv2)
{
  double diff = 0;
  db_buf_t e1, e2;
  int len;
  int l1 = dv1[1];
  int l2 = dv2[1];
  dtp_t dtp1, dtp2;
  dv1 += 2;
  dv2 += 2;
  e1 = dv1 + l1;
  e2 = dv2 + l2;
  while (dv1 < e1 && dv2 < e2)
    {
      long n1, n2;
      dtp1 = dv1[0];
      dtp2 = dv2[0];
      if (DV_SHORT_INT == dtp1)
	dtp1 = DV_LONG_INT;
      if (DV_SHORT_INT == dtp2)
	dtp2 = DV_LONG_INT;

      if (dtp1 != dtp2)
	return diff;
      switch (dtp1)
	{
	case DV_LONG_INT:
	  n1 = INT_REF (dv1);
	  n2 = INT_REF (dv2);
	  diff = diff * 10000000 + abs (n1 - n2);
	  break;
	default: ;
	}
      DB_BUF_TLEN (len, dv1[0], dv1);
      dv1 += len;
      DB_BUF_TLEN (len, dv2[0], dv2);
      dv2 += len;
    }
  return diff;
}


int
wst_is_target_far (word_stream_t * wst)
{
  /* if distance over 30 times the width of the current window */
  int64 row_width, dist;
  if (D_INITIAL (&wst->wst_seek_target) || D_NEXT (&wst->wst_seek_target))
    return 0;
  if (DV_COMPOSITE == wst->wst_first_d_id.id[0])
    {
      double row_width = composite_diff (wst->wst_first_d_id.id, wst->wst_last_d_id.id);
      double dist = composite_diff (wst->wst_last_d_id.id, wst->wst_seek_target.id);
      return (dist > 30 * row_width);
    }

  row_width = D_ID_NUM_REF (wst->wst_last_d_id.id) - D_ID_NUM_REF (wst->wst_first_d_id.id);
  dist = D_ID_NUM_REF (wst->wst_seek_target.id) - D_ID_NUM_REF (wst->wst_last_d_id.id);
  if (dist < 0)
    dist = -dist;
  return (dist  > 30 * row_width);
}


d_id_t *
wst_word_strings_next (word_stream_t * wst)
{
  d_id_t * d_id;
  int n, inx;
  if (D_NEXT (&wst->wst_seek_target))
    wst->wst_nth_word_string++;
  inx = wst->wst_nth_word_string;
  n = BOX_ELEMENTS (wst->wst_word_strings);
  while (inx < n)
    {
      long l, hl;
      caddr_t buf = wst->wst_word_strings[inx];
      WP_LENGTH (buf, hl, l, buf, box_length (buf) - 1);
      d_id = (d_id_t *) (buf + hl);
      if ((D_INITIAL (&wst->wst_seek_target)
	   || D_NEXT (&wst->wst_seek_target)
	   || IS_GTE (d_id_cmp (d_id,  &wst->wst_seek_target)))
	  && l > WP_FIRST_POS (buf + hl))
	{
	  wst->wst_nth_word_string = inx;
	  wst->sst_buffer = buf;
	  wst->sst_fill = box_length (buf) - 1;
	  wst->sst_pos = 0;
	  d_id_set (&wst->wst_first_d_id, d_id);
	  d_id_set (&wst->wst_last_d_id, d_id);
	  d_id_set (&wst->sst_d_id, d_id);
	  return (&wst->sst_d_id);
	}
      inx++;
    }
  D_SET_AT_END (&wst->sst_d_id);
  return (&wst->sst_d_id);
}


void
wst_next (word_stream_t * wst, d_id_t * target)
{
  int rc, match_any;
  /* caddr_t x;*/
  if (D_AT_END (&wst->sst_d_id))
    return;
  wst->wst_seek_target = *target;
  /*x = box_d_id (&wst->wst_seek_target);   printf ("wst next of %s target %d\n", wst->wst_word, (int) unbox (x));  dk_free_box (x);*/
  if (wst->wst_word_strings)
    {
      wst_word_strings_next (wst);
      return;
    }
  if (D_INITIAL (&wst->sst_d_id))
    {
      rc = wst_random_seek (wst);
      if (DVC_MATCH == rc)
	return;
      /* the first seek, if going to a target, can fail if the first row start at higher than target. Seek thus with no target because it can still contain hits later */
      D_SET_INITIAL (&wst->wst_seek_target);
      wst_random_seek (wst);
      return;
    }
  match_any = D_INITIAL (&wst->wst_seek_target) ||  D_NEXT (&wst->wst_seek_target);
  if (match_any ||
      (!D_INITIAL (&wst->wst_last_d_id)
       && IS_LTE (d_id_cmp (&wst->wst_seek_target, &wst->wst_last_d_id))))
    {
      rc = wst_chunk_scan (wst, NULL, wst->sst_fill);
      if (DVC_MATCH == rc)
	return;
    }
  if (D_NEXT (&wst->wst_seek_target))
    D_SET_INITIAL (&wst->wst_seek_target);
  if (wst_is_target_far (wst)
      && !D_PRESET (&wst->sst_d_id))
    rc = wst_random_seek (wst);
  else
    rc = wst_seq_seek (wst);
  return;
}


void
sst_range_hit (search_stream_t * sst, int r1, int r2)
{
  int fill = sst->sst_all_ranges_fill;
  word_range_t * r;
  if (!sst->sst_all_ranges)
    sst->sst_all_ranges = (word_range_t *) dk_alloc_box (10 * sizeof (word_range_t), DV_ARRAY_OF_LONG);
  if (((int) (box_length ((caddr_t) sst->sst_all_ranges) / sizeof (word_range_t))) <= fill)
    {
      r = (word_range_t *) dk_alloc_box (sizeof (word_range_t) * fill * 2, DV_ARRAY_OF_LONG);
      memcpy (r, sst->sst_all_ranges, fill * sizeof (word_range_t));
      dk_free_box ((caddr_t) sst->sst_all_ranges);
      sst->sst_all_ranges = r;
      r += fill;
    }
  else
    r = sst->sst_all_ranges+fill;
  r->r_start = r1;
  r->r_end = r2;
  sst->sst_all_ranges_fill = fill + 1;
}


#define RANGE_NEXT(sst, pos, inx) \
  pos = (sst->sst_all_ranges_fill > inx ? sst->sst_all_ranges[inx++].r_start : -1)


#define SST_RANGE_HIT(sst, r1, r2) \
{ \
  sst_range_hit ((sst), (int) (r1), (int) (r2)); \
  if (!make_ranges) \
    goto hit_found; \
}

#if 1
int
sst_prox_ranges (search_stream_t * sst1, search_stream_t * sst2,
		 word_rel_t * rel, int make_ranges)
{
  word_range_t * src_ranges = sst1->sst_all_ranges+sst1->sst_sel_startofs;
  unsigned src_ranges_fill = sst1->sst_sel_count;
  int dist = rel->wrl_dist;
  int is_lefttoright = rel->wrl_is_lefttoright;
  int is_dist_fixed = rel->wrl_is_dist_fixed;
  wpos_t inx1, inx2, best_hit, sst2_sofs;

  sst1->sst_all_ranges_fill = sst1->sst_sel_startofs;
  sst2_sofs = sst2->sst_sel_startofs;

  for (inx1 = 0; inx1 < src_ranges_fill; inx1++)
    {
      wpos_t s1 = src_ranges[inx1].r_start;
      wpos_t e1 = src_ranges[inx1].r_end;
      wpos_t min_s2;
      wpos_t max_s2;
      if (is_lefttoright)
	{
	  if (dist > 0)
	    {
	      min_s2 = s1 + (is_dist_fixed ? dist : 1);
	      max_s2 = s1 + dist;
	    }
	  else if (dist < 0)
	    {
	      min_s2 = e1 + dist;
	      max_s2 = e1 + (is_dist_fixed ? dist : ((e1 > 0) ? -1 : 0));
	    }
	  else
	    min_s2 = max_s2 = s1;
	}
      else
	{
	  int curdist = (int) (e1-s1);
	  if (dist < curdist)
	    dist = curdist;
	  /* lefttoright == 0, so dist is positive here: */
	  min_s2 = (e1 > (wpos_t)(dist)) ? (e1 - (wpos_t)(dist)) : 0;
	  max_s2 = s1 + dist;
	}
      best_hit = HUGE_WPOS_T;
      for (inx2 = 0; inx2 < sst2->sst_sel_count; inx2++)
	{
	  wpos_t pos2 = sst2->sst_all_ranges[sst2_sofs+inx2].r_start;
	  if (pos2 > max_s2)
	    break;
	  if (pos2 < min_s2)
	    continue;
	  best_hit = pos2;
	  if (pos2 >= s1)
	    break;
	}
      if (HUGE_WPOS_T != best_hit)
	SST_RANGE_HIT ( sst1,
	  (s1<best_hit ? s1 : best_hit),
	  (e1>best_hit ? e1 : best_hit) );
    }
  goto finalize;
hit_found:
  sst1->sst_all_to = sst1->sst_sel_to = sst1->sst_all_ranges[sst1->sst_all_ranges_fill-1].r_start+1;
finalize:
  sst1->sst_sel_count = sst1->sst_all_ranges_fill - sst1->sst_sel_startofs;
  return (sst1->sst_sel_count);
}
#else
int
sst_prox_ranges (search_stream_t * sst1, search_stream_t * sst2,
		 word_rel_t * rel, int make_ranges)
{
  word_range_t * src_ranges = sst1->sst_all_ranges+sst1->sst_sel_startofs;
  int src_ranges_fill = sst1->sst_sel_count;
  int dist = rel->wrl_dist;
  int is_lefttoright = rel->wrl_is_lefttoright;
  int is_dist_fixed = rel->wrl_is_dist_fixed;
  int inx1 = 0, inx2 = 0;

  sst1->sst_all_ranges_fill = sst1->sst_sel_startofs;

  for (inx1 = 0; inx1 < src_ranges_fill; inx1++)
    {
      int s1 = src_ranges[inx1].r_start;
      int e1 = src_ranges[inx1].r_end;
      int before = -1, inside = -1, after = -1;
      int sst2_sofs = sst2->sst_sel_startofs;
      for (inx2 = 0; inx2 < sst2->sst_sel_count; inx2++)
	{
	  int pos2 = sst2->sst_all_ranges[sst2_sofs+inx2].r_start;
	  if (pos2 < s1)
	    {
	      if (-1 == before || pos2 > before)
		before = pos2;
	      continue;
	    }
	  if (pos2 > e1)
	    {
	      if (-1 == after || pos2 < after)
		after = pos2;
	      continue;
	    }
	  /* Now (s1 <= pos2 && e1 >= pos2) */
	  inside = pos2;
	  break;
	}
      if (is_lefttoright)
	{
	  if (dist > 0)
	    {
	      if (after != -1
		&& (is_dist_fixed ? after - s1 == dist : after - s1 < dist))
		SST_RANGE_HIT (sst1, s1, after);
	      continue;
	    }
	  if (dist < 0)
	    {
	      if (before != -1
		&& (is_dist_fixed ? e1 - before == dist : e1 - before < dist))
		SST_RANGE_HIT (sst1, s1, after);
	      continue;
	    }
	}
      else
	{
	  if (-1 != inside)
	    {
	      SST_RANGE_HIT (sst1, s1, e1);
	    }
	  else
	    {
	      if (before != -1 && e1 - before < dist)
		SST_RANGE_HIT (sst1, before, e1);
	      if (after != -1 && after - s1 < dist)
		SST_RANGE_HIT (sst1, s1, after);
	    }
	}
    }
  goto finalize;
hit_found:
  sst1->sst_all_to = sst1->sst_sel_to = sst1->sst_all_ranges[sst1->sst_all_ranges_fill-1].r_start+1;
finalize:
  sst1->sst_sel_count = sst1->sst_all_ranges_fill - sst1->sst_sel_startofs;
  return (sst1->sst_sel_count);
}
#endif

#undef SST_RANGE_HIT

int
sst_is_top_and_term (search_stream_t * sst, search_stream_t * term)
{
  /* either first of proximity group or not a member of a proximity group */
  if (dk_set_member (sst->sst_near_group_firsts, (void*) term))
    return 1;
  DO_SET (word_rel_t *, rel, &term->sst_related)
    {
      if (rel->wrl_is_dist_fixed)
	return 0; /* Tails of phrases are not top and terms */
      if ((0 != rel->wrl_dist) && (HUGE_DIST != rel->wrl_dist))
	return 0;
    }
  END_DO_SET();
  return 1;
}

#ifdef TEXT_DEBUG
static int sst_ranges_debug (search_stream_t * sst, d_id_t * d_id, wpos_t from, wpos_t to, int make_ranges);
#endif

int
sst_ranges (search_stream_t * sst, d_id_t * d_id, wpos_t from, wpos_t to, int make_ranges)
#ifdef TEXT_DEBUG
{
  int res;
  fprintf(stderr,"{{ sst_ranges(%p,",sst);
  dbg_print_d_id_aux (stderr, (unsigned char *)(d_id));
  fprintf(stderr,",");
  dbg_print_wpos_aux (stderr, from);
  fprintf(stderr,",");
  dbg_print_wpos_aux (stderr, to);
  fprintf(stderr,",%d)\n", make_ranges);
  res = sst_ranges_debug (sst, d_id, from, to, make_ranges);
  fprintf(stderr,"   sst_ranges(%p,",sst);
  dbg_print_d_id_aux (stderr, (unsigned char *)(d_id));
  fprintf(stderr,",");
  dbg_print_wpos_aux (stderr, from);
  fprintf(stderr,",");
  dbg_print_wpos_aux (stderr, to);
  fprintf(stderr,",%d) returns %d }}\n", make_ranges, res);
  return res;
}

int
sst_ranges_debug (search_stream_t * sst, d_id_t * d_id, wpos_t from, wpos_t to, int make_ranges)
#endif
{
  int inx;
  int rc;
  wpos_t startofs, endofs, right_cop, robber;
  word_range_t *ranges;
  if (to < from)
    return 0;
  if (!D_INITIAL (&sst->sst_d_id)
      && (IS_GT (d_id_cmp (&sst->sst_d_id, d_id))
	  || D_AT_END (&sst->sst_d_id)))
    return 0;
  if (D_INITIAL (&sst->sst_d_id)
      || IS_LT (d_id_cmp (&sst->sst_d_id, d_id)))
    {
      sst_next (sst, d_id, 0);
      if (DVC_MATCH != d_id_cmp (&sst->sst_d_id, d_id))
	return 0;
      goto create_new_ranges;
    }
  /* Now we know that we're at right document. We should check if we can use
     information cached in \c sst_all_xxx members of \c sst */
  if (DVC_MATCH != d_id_cmp (&sst->sst_range_d_id, d_id))
    goto create_new_ranges; /* see below */
  if ((from < sst->sst_all_from) || (to > sst->sst_all_to))
    goto create_new_ranges; /* see below */
  if ((from == sst->sst_view_from) && (to == sst->sst_view_to))
    { /* If we have whole row cached and asked for full row, we should select all */
      sst->sst_sel_from = sst->sst_sel_to = 0;
      sst->sst_sel_startofs = 0;
      sst->sst_sel_count = sst->sst_all_ranges_fill;
      return (0 != sst->sst_sel_count);
    }
  /* Now we know we have enough cached data, and we should locate them in cache
  by binary search */
  ranges = sst->sst_all_ranges;
  startofs = 0; right_cop = sst->sst_all_ranges_fill;
  if (0 == right_cop)
    return 0;
  right_cop--;
  if (ranges[0].r_start > to)
    return 0;
  while (right_cop > startofs)
    {
      robber = (startofs+right_cop)/2;
      if (ranges[robber].r_start < from)
	startofs = robber+1;
      else
	{
	  if(right_cop > robber)
	    right_cop = robber;
	  else
	    if (ranges[startofs].r_start < from)
	      startofs++;
	    else
	      break;
	}
    }
  endofs = startofs; right_cop = sst->sst_all_ranges_fill-1;
  if (ranges[endofs].r_end <= from)
    return 0;
  while (right_cop > endofs)
    {
      robber = (endofs+right_cop)/2;
      if (ranges[robber].r_end >= to)
	right_cop = robber-1;
      else
	{
	  if (endofs < robber)
	    endofs = robber;
	  else
	    if (ranges[right_cop].r_end >= to)
	      right_cop--;
	    else
	      break;
	}
    }
  sst->sst_sel_from = from;
  sst->sst_sel_to = to;
  sst->sst_sel_startofs = (unsigned) startofs;
  sst->sst_sel_count = (unsigned) (endofs+1-startofs);
  return (0 != sst->sst_sel_count);

create_new_ranges:
  if (make_ranges)
    d_id_set (&sst->sst_range_d_id,  d_id);
  else
    D_SET_INITIAL (&sst->sst_range_d_id);
  sst->sst_all_ranges_fill = 0;
  switch (sst->sst_op)
    {
    case SRC_WORD:
      {
	int hl, l, pos = sst->sst_pos, current = 0, end;
	if (WST_OFFBAND_CHAR == ((word_stream_t *)sst)->wst_word[0])
	  return 1;
	if (NULL == sst->sst_buffer)
	  return 0;
	WP_LENGTH (sst->sst_buffer + pos, hl, l, sst->sst_buffer, sst->sst_buffer_size);
	end = pos + l + hl;
	pos += hl + WP_FIRST_POS (sst->sst_buffer + pos + hl);
	while (pos < end)
	  {
	    int pl, p;
	    WP_LENGTH_IMPL (sst->sst_buffer + pos, pl, p);
	    pos += pl;
	    current += p;
	    if (!to || (((wpos_t) current) >= from && ((wpos_t) current) < to))
	      {
		if (!make_ranges)
		  return 1;
		sst_range_hit (sst, current, current);
	      }
	    if (to && ((wpos_t) current) >= to)
	      break;
	  }
	sst->sst_sel_from = sst->sst_all_from = from;
	sst->sst_sel_to = sst->sst_all_to = to;
	if (!make_ranges)
	  return 0;
	sst->sst_sel_startofs = 0;
	sst->sst_sel_count = sst->sst_all_ranges_fill;
	return (0 != sst->sst_sel_count);
      }
    case BOP_OR:
      {
	/* The following string is Orri's bypass for bug in OR */
	/* make_ranges = 0; */
	DO_BOX (search_stream_t *, term, inx, sst->sst_terms)
	  {
	    rc = sst_ranges (term, d_id, from, to, make_ranges);
	    if (rc)
	      {
		if (!make_ranges)
		  return rc;
	      }
	    else
	      term->sst_sel_count = 0;
	  }
	END_DO_BOX;
	for(;;)
	  {
	    wpos_t minstart, minend;
	    search_stream_t * minterm;
	    minstart = minend = HUGE_WPOS_T;
	    minterm = NULL;
	    DO_BOX (search_stream_t *, term, inx, sst->sst_terms)
	      {
		word_range_t *wrt;
		if(0 == term->sst_sel_count)
		  continue;
		wrt = term->sst_all_ranges+term->sst_sel_startofs;
		if (wrt->r_start > minstart)
		  continue;
		if (wrt->r_start < minstart)
		  {
		    minstart = wrt->r_start;
		    minend = wrt->r_end;
		    minterm = term;
		    continue;
		  }
		if (wrt->r_end > minend)
		  continue;
		if (wrt->r_end < minend)
		  {
		    minend = wrt->r_end;
		    minterm = term;
		    continue;
		  }
		/* If we're here, we have duplicated ranges, so we may remove all
		   of them except one. Note that the range removed may be not the
		   leftmost, but it's safe anyway. */
		term->sst_sel_startofs += 1;
		term->sst_sel_count -= 1;
	      }
	    END_DO_BOX;
	    if (NULL == minterm)
	      break;
	    sst_range_hit (sst, (int) minstart, (int) minend);
	    minterm->sst_sel_startofs += 1;
	    minterm->sst_sel_count -= 1;
	  }
	sst->sst_sel_from = sst->sst_all_from = from;
	sst->sst_sel_to = sst->sst_all_to = to;
	sst->sst_sel_startofs = 0;
	sst->sst_sel_count = sst->sst_all_ranges_fill;
	return (0 != sst->sst_sel_count);
      }
    case SRC_NEAR:
    case SRC_WORD_CHAIN:
    case BOP_AND:
      {
	DO_BOX (search_stream_t *, term, inx, sst->sst_terms)
	  {
	    rc = sst_ranges (term, d_id, from, to, 1);
	    if (!rc)
	      return 0;
	  }
	END_DO_BOX;
	DO_SET (search_stream_t *, neg_term, &sst->sst_not)
	  {
	    if (sst_ranges (neg_term, d_id, from, to, 0))
	      return 0;
	  }
	END_DO_SET();
	DO_SET (search_stream_t *, first, &sst->sst_near_group_firsts)
	  {
	    DO_SET (word_rel_t *, rel, &first->sst_related)
	      {
		/* If both dist and is_lefttorigth are zero, then it's a dummy relation */
		if (! (0 == rel->wrl_dist && 0 == rel->wrl_is_lefttoright))
		  {
		    if (0 == sst_prox_ranges (first, rel->wrl_sst, rel, make_ranges))
		      return 0;
		  }
	      }
	    END_DO_SET();
	  }
	END_DO_SET();
	if (0 != sst->sst_all_ranges_fill)
	  {
	    sst->sst_sel_from = sst->sst_all_from = from;
	    sst->sst_sel_to = sst->sst_all_to = to;
	  }
	else
	  {
	    sst->sst_sel_from = sst->sst_all_from = LAST_ATTR_WORD_POS+1;	/* dummy */
	    sst->sst_sel_to = sst->sst_all_to = LAST_ATTR_WORD_POS+2;		/* dummy */
	  }
	sst->sst_sel_startofs = 0;
	sst->sst_sel_count = sst->sst_all_ranges_fill;
	return 1;
      }
    }
  GPF_T1 ("bad search op in sst_ranges");
  return 0; /*never reached*/
}


void
sst_freq_factor (search_stream_t * sst)
{
  /* decrease the score if hits are sparse relative to document length.
   * last hit position is considered as length; 16 added then to adjust weights for very short documents */
  int last;
  if (0 == sst->sst_all_ranges || !sst->sst_all_ranges_fill)
    last = 16;
  else
    last = (int) sst->sst_all_ranges[sst->sst_all_ranges_fill-1].r_end + 16;
/* '16 * 15.0' in the line below is some fake Jordan 16 * StatisticalWeight as for 1 hit per 32K docs. */
  sst->sst_score = (int) (sst->sst_raw_score * 16 * 15.0 / last);
  if (!sst->sst_score)
    sst->sst_score = 1;
}


void
sst_scores (search_stream_t * sst, d_id_t * d_id)
{
  int score, raw_score, mult;
  int inx;
  if (DVC_MATCH != d_id_cmp (d_id, &sst->sst_d_id))
    return;
  if (sst->sst_score)
    return; /* sometimes known as side effect of search */
  switch (sst->sst_op)
    {
    case SRC_WORD:
      sst_ranges (sst, d_id, sst->sst_view_from, sst->sst_view_to, 1);
      sst->sst_raw_score = sst->sst_all_ranges_fill;
      sst_freq_factor (sst);
      return;
    case BOP_OR:
      sst_ranges (sst, d_id, sst->sst_view_from, sst->sst_view_to, 1);
      score = raw_score = 0;
      mult = 16;
      DO_BOX (search_stream_t *, term, inx, sst->sst_terms)
	{
          sst_scores (term, d_id);
	  if (score < term->sst_score)
	    score = term->sst_score;
	  if (raw_score < term->sst_raw_score)
	    raw_score = term->sst_raw_score;
	  mult--;
	}
      END_DO_BOX;
      if (mult < 1)
	mult = 1;
      sst->sst_raw_score = (raw_score ? (16 + (raw_score - 1) * mult) / 16 : 0);
      sst->sst_score = (score ? (16 + (score - 1) * mult) / 16 : 0);
      return;
    case BOP_AND:
      sst_ranges (sst, d_id, sst->sst_view_from, sst->sst_view_to, 1);
      raw_score = 0x10000;
      score = 0x10000;
      mult = 0;
      DO_BOX (search_stream_t *, term, inx, sst->sst_terms)
	{
	  if (sst_is_top_and_term (sst, term))
	    {
	      sst_scores (term, d_id);
	      if (score > term->sst_score)
		score = term->sst_score;
	      if (raw_score > term->sst_raw_score)
		raw_score = term->sst_raw_score;
	      mult++;
	    }
	}
      END_DO_BOX;
      sst->sst_raw_score = raw_score * mult;
      sst->sst_score = score * mult;
      return;
    case SRC_WORD_CHAIN:
      sst_ranges (sst, d_id, sst->sst_view_from, sst->sst_view_to, 1);
      raw_score = score = 0;
      DO_SET (search_stream_t *, first, &sst->sst_near_group_firsts)
	{
	  raw_score +=
	  first->sst_raw_score = first->sst_all_ranges_fill * VT_ZERO_DIST_WEIGHT * (1 + dk_set_length (first->sst_related));
	  sst_freq_factor (first);
	  raw_score += first->sst_raw_score;
	  score += first->sst_score;
	}
      END_DO_SET();
      sst->sst_raw_score = raw_score;
      sst->sst_score = score;
      return;
    case SRC_NEAR:
      sst_ranges (sst, d_id, sst->sst_view_from, sst->sst_view_to, 1);
      raw_score = 0x10000;
      score = 0x10000;
      DO_BOX (search_stream_t *, term, inx, sst->sst_terms)
	{
	  if (sst_is_top_and_term (sst, term))
	    {
	      sst_scores (term, d_id);
	      if (score > term->sst_score)
		score = term->sst_score;
	      if (raw_score > term->sst_raw_score)
		raw_score = term->sst_raw_score;
	    }
	}
      END_DO_BOX;
      DO_SET (search_stream_t *, first, &sst->sst_near_group_firsts)
	{
	  int rscore = 0;
	  for (inx = 0; inx < (int) first->sst_all_ranges_fill; inx++)
	    {
	      int width = (int) (first->sst_all_ranges[inx].r_end - first->sst_all_ranges[inx].r_start);
	      if (width < NEAR_DIST)
		rscore += vt_hit_dist_weight[width + (int)0x80];
	    }
	  first->sst_raw_score = rscore;
	  sst_freq_factor (first);
	  raw_score += first->sst_raw_score;
	  score += first->sst_score;
	}
      END_DO_SET();
      sst->sst_raw_score = raw_score;
      sst->sst_score = score;
      return;
    }
}


#define SST_NAME(sst) \
  (sst->sst_op == SRC_WORD ? ((word_stream_t*)sst)->wst_word : "--")

#define SST_AND_HIT 0	/* all on same doc and proximity and not terms OK */
#define SST_AND_NEXT 2  /*terms on same doc but fail on proximity or because of not term */

int
sst_check_and_hit (search_stream_t * sst, d_id_t * d_id, int is_fixed)
{
  /* hit if all on same d_id and proximity satisfied */
  /* int score = 0; */
#ifdef TEXT_DEBUG
  dbg_printf (("checking hit at 0x%lx\n", (long)(d_id->num)));
#endif
/*
  DO_BOX (search_stream_t *, term, inx, sst->sst_terms)
    {
#ifdef TEXT_DEBUG
      dbg_printf (("  stream of %s at 0x%lx\n", SST_NAME (term), (long)(term->sst_d_id.num)));
#endif
      if (DVC_MATCH != d_id_cmp (&term->sst_d_id, d_id))
	return AND_NO_HIT;
    }
  END_DO_BOX;
*/
  sst->sst_score = 0;
  d_id_set (&sst->sst_d_id, d_id);
  if (sst->sst_need_ranges)
    {
      if (!sst_ranges (sst, &sst->sst_d_id, sst->sst_view_from, sst->sst_view_to, sst->sst_need_ranges))
	return SST_AND_NEXT;
    }
  else
    {
      DO_SET (search_stream_t *, first, &sst->sst_near_group_firsts)
	{
	  DO_SET (word_rel_t *, rel, &first->sst_related)
	    {
	      search_stream_t * rel_sst = rel->wrl_sst;
	      if (DVC_MATCH != d_id_cmp (&rel->wrl_d_id, d_id))
		{
                  db_buf_t pos, rel_pos;
		  int pos_len, rel_len, hl;
                  if (!rel->wrl_dist && !rel->wrl_is_dist_fixed)
                    {
                      rel->wrl_score = 1;
                      continue;
                    }
		  pos = (db_buf_t) (first->sst_buffer + first->sst_pos);
		  rel_pos = (db_buf_t) (rel_sst->sst_buffer + rel_sst->sst_pos);
		  WP_LENGTH (pos, hl, pos_len, first->sst_buffer, first->sst_fill);
		  pos_len -= WP_FIRST_POS (pos + hl);
		  pos += hl + WP_FIRST_POS (pos + hl);
		  WP_LENGTH (rel_pos, hl, rel_len, rel_sst->sst_buffer, rel_sst->sst_fill);
		  rel_len -= WP_FIRST_POS (rel_pos + hl);
		  rel_pos += hl + WP_FIRST_POS (rel_pos + hl);
		  wp_proximity (pos, pos_len, rel_pos, rel_len, rel);
		}
	      if (0 == rel->wrl_score)
		return SST_AND_NEXT;
	      /* score += rel->wrl_score; */
	    }
	  END_DO_SET ();
	}
      END_DO_SET ();
    }
  if (sst->sst_not)
    {
      DO_SET (search_stream_t *, _not, &sst->sst_not)
	{
	  if (!D_AT_END (&_not->sst_d_id))
	    {
	      if (D_INITIAL (&_not->sst_d_id)
		  || sst_is_below (&_not->sst_d_id, d_id, sst->sst_is_desc))
		{
		  sst_next (_not, d_id, is_fixed);
		}
	      if (DVC_MATCH == d_id_cmp (&_not->sst_d_id, d_id))
		return SST_AND_NEXT;
	    }
	}
      END_DO_SET ();
    }
  /* sst->sst_score = score; */ /*done with sst_ranges if a score is actually wanted */
  return SST_AND_HIT;
}


d_id_t *
sst_and_advance (search_stream_t * sst, d_id_t * target2, int is_fixed)
{
  d_id_t target = *target2;
  d_id_t next;
  int inx;
  int rc;
  d_id_t d_id = sst->sst_d_id;
  if (D_AT_END (&d_id))
    return (&sst->sst_d_id);
  for (;;)
    {
again:
      DO_BOX (search_stream_t *, term, inx, sst->sst_terms)
	{
	  d_id_t * nextp = sst_next (term, &target, is_fixed);
	  next = * nextp;
#ifdef TEXT_DEBUG
	  dbg_printf (("AND sst %s advanced %s to %lx = %lx\n", SST_NAME(sst), SST_NAME (term), (long)(target.num), (long)(term->sst_d_id.num)));
#endif
	  if (D_AT_END (&next))
	    {
	      D_SET_AT_END (&sst->sst_d_id);
	      return (&sst->sst_d_id);
	    }
	  if (DVC_MATCH != d_id_cmp (&term->sst_d_id, &target))
	    {
	      d_id_set (&target, &term->sst_d_id);
	      goto again;
	    }
	}
      END_DO_BOX;
      rc = sst_check_and_hit (sst, &next, is_fixed);
      if (SST_AND_HIT == rc)
	{
	  d_id_set (&sst->sst_d_id, &next);
	  return (&sst->sst_d_id);
	}
      if (SST_AND_NEXT == rc)
	{
	  D_SET_NEXT (&target);
	  goto again;
	}
      GPF_T; /* never reached */
    }
}


d_id_t *
sst_or_advance (search_stream_t * sst, d_id_t target, int is_fixed)
{
  int inx /*, n_at_target = 0 */;
  d_id_t d_id = sst->sst_d_id;
  d_id_t lowest;
  int has_target;
  d_id_t prev_d_id = sst->sst_d_id;
  if (D_AT_END (&d_id))
    return (&sst->sst_d_id);
  has_target = !(D_INITIAL (&target) || D_NEXT (&target));
  D_SET_INITIAL (&lowest);
#ifdef TEXT_DEBUG
  dbg_printf (("OR sst %s started with target %ld\n", SST_NAME(sst), target));
#endif
  DO_BOX (search_stream_t *, term, inx, sst->sst_terms)
    {
      if (D_AT_END (&term->sst_d_id))
	continue;
      if (has_target)
	{
	  while (
	    D_INITIAL (&term->sst_d_id) ||
	    sst_is_below (&term->sst_d_id, &target, sst->sst_is_desc))
	    {
	      sst_next (term, &target, is_fixed);
	      if (D_AT_END (&term->sst_d_id))
		break;
	    }
	  if (D_AT_END (&term->sst_d_id))
	    continue;
	  if (DVC_MATCH == d_id_cmp (&term->sst_d_id, &target))
	    {
	      lowest = term->sst_d_id;
	      /* n_at_target++; */
	    }
	  else
	    {
	      if (D_INITIAL (&lowest) ||
		  sst_is_below (&term->sst_d_id, &lowest, sst->sst_is_desc))
		{
		  lowest = term->sst_d_id;
		}
	    }
	}
      else
	{
	  if (
	    D_INITIAL (&term->sst_d_id) ||
	    DVC_MATCH == d_id_cmp (&prev_d_id, &term->sst_d_id))
	    {
	      sst_next (term, &target, is_fixed);
	    }
	  if (D_AT_END (&term->sst_d_id))
	    continue;
	  if (
	    D_INITIAL (&lowest) ||
	    sst_is_below (&term->sst_d_id, &lowest, sst->sst_is_desc))
	    {
	      lowest = term->sst_d_id;
	    }
	}
    }
  END_DO_BOX;
  if (D_INITIAL (&lowest))
    D_SET_AT_END (&lowest);
  sst->sst_d_id = lowest;
#ifdef TEXT_DEBUG
  dbg_printf (("OR sst %s finished with lowest found %ld\n", SST_NAME(sst), lowest));
#endif
  return (&sst->sst_d_id);
}


d_id_t *
sst_next (search_stream_t * sst, d_id_t * target, int is_fixed)
{
  sst->sst_score = 0;
  switch (sst->sst_op)
    {
    case SRC_WORD:
      {
	word_stream_t * wst = (word_stream_t *) sst;
	wst_next ( wst, target);
	if (!D_AT_END (&wst->wst_end_id)
	    && !D_AT_END (&sst->sst_d_id))
	  {
	    int rc = d_id_cmp (&wst->sst_d_id, &wst->wst_end_id);
	    if (sst->sst_is_desc ? IS_LT (rc) : IS_GT (rc))
	      D_SET_AT_END (&sst->sst_d_id);
	  }
	if (is_fixed && DVC_MATCH != d_id_cmp (&sst->sst_d_id, target))
	  D_SET_AT_END (&sst->sst_d_id);
	return (&sst->sst_d_id);
      }
    case SRC_NEAR:
    case SRC_WORD_CHAIN:
    case BOP_AND:
      sst_and_advance (sst, target, is_fixed);
      return (&sst->sst_d_id);
    case BOP_OR:
      sst_or_advance (sst, *target, is_fixed);
      return (&sst->sst_d_id);
    case SRC_ERROR:
      {
	caddr_t err = sst->sst_error;
	sst->sst_error = NULL;
	sqlr_resignal (err);
      }
    default:
      GPF_T1 ("unsupported search op");
    }
  return NULL; /*dummy*/
}



#define RANGE_ERROR 0
#define RANGE 1
#define EXACT_WORD 2
#define RANGE_NOT_SUPPORTED 3


int
wp_wildcard_range (const char * word, caddr_t * lower, caddr_t * higher)
{
  char * star = strchr (word, '*');
  int leading = star ? (int) (star - word) : 0;
  if (star)
    {
      if (leading < 4)
	return RANGE_ERROR;
      if (cl_run_local_only)
	{
	  *lower = box_dv_short_nchars (word, leading + 1);
	  (*lower)[leading - 1]--;
	  (*lower)[leading] = '\377';
	  (*lower)[leading + 1] = 0;
	}
      else
	*lower = box_dv_short_nchars (word, leading); /* for cluster, the test is different, do not decrement lower bound extra */
      *higher = box_dv_short_nchars (word, leading);
      (*higher) [box_length (*higher) - 2]++;
      return RANGE;
    }
  return EXACT_WORD;
}


dk_set_t
wst_range_from_vtb (sst_tctx_t *tctx, ptrlong range_flags, const char * word)
{
  dk_set_t wsts = NULL;
  lenmem_t * lm;
  word_batch_t * wb;
  id_hash_iterator_t hit;
  id_hash_iterator (&hit, tctx->tctx_vtb->vtb_words);
  while (hit_next (&hit, (caddr_t*) &lm, (caddr_t*) &wb))
    {
      if (DVC_MATCH == cmp_like (lm->lm_memblock, word, NULL, '\0', LIKE_ARG_CHAR, LIKE_ARG_CHAR))
	{
	  dbe_table_t *tbl_save = tctx->tctx_table;
	  word_stream_t *wst;
	  tctx->tctx_table = NULL;
	  wst = (word_stream_t *)(wst_from_word (tctx, range_flags, lm->lm_memblock));
	  tctx->tctx_table = tbl_save;
	  dk_set_push (&wsts, (void*) wst);
	}
    }
  return wsts;
}


search_stream_t *
wst_from_wsts (sst_tctx_t *tctx, ptrlong range_flags, dk_set_t wsts)
{
  if (!wsts)
    {
      search_stream_t *sst = wst_from_word (tctx, range_flags, "---");
      D_SET_AT_END (&sst->sst_d_id);
      return sst;
    }
  if (wsts->next)
    {
      NEW_SST (search_stream_t, sst);
      sst->sst_is_desc = tctx->tctx_descending;
      sst->sst_range_flags = range_flags;
      sst->sst_view_from = ((range_flags & SRC_RANGE_MAIN) ? FIRST_MAIN_WORD_POS : FIRST_ATTR_WORD_POS);
      sst->sst_view_to = ((range_flags & SRC_RANGE_ATTR) ? LAST_ATTR_WORD_POS : LAST_MAIN_WORD_POS);
      sst->sst_terms = (search_stream_t **) list_to_array (wsts);
      D_SET_INITIAL (&sst->sst_d_id);
      sst->sst_op = BOP_OR;
      return sst;
    }
  else
    {
      search_stream_t * sst = (search_stream_t *) wsts->data;
      dk_set_free (wsts);
      return sst;
    }
}


static search_stream_t *
wst_from_range (sst_tctx_t *tctx, ptrlong range_flags, const char * word, caddr_t lower, caddr_t higher)
{
/*  vt_batch_t * vtb;*/
  dk_set_t wsts = NULL;
  int n_words = 0;
  it_cursor_t * itc;
  caddr_t limit;
  limit = box_copy (lower);

/*  vtb = (vt_batch_t *) THR_ATTR (qi->qi_thread, TA_SST_USE_VTB);*/

  if (NULL != tctx->tctx_vtb)
    wsts = wst_range_from_vtb (tctx, range_flags, word);
  else
    {
      for (;;)
	{
	  caddr_t old_limit = limit;
	  itc = wst_range_itc (tctx, word, &limit, higher);
	  dk_free_box (old_limit);
	  if (itc)
	    {
	      word_stream_t * wst = (word_stream_t *) wst_from_word (tctx, range_flags, limit);
	      n_words++;
	      if (!wst->sst_is_desc)
		{
		  wst->wst_itc = itc;
		  D_SET_INITIAL (&wst->sst_d_id);
		  D_SET_INITIAL (&wst->wst_first_d_id);
		  D_SET_INITIAL (&wst->wst_last_d_id);
/*
		  D_SET_PRESET (&wst->sst_d_id);
*/
		  itc->itc_wst = wst;
		  itc->itc_is_on_row = 0;
		}
	      else
		{
		  /* desc order, the itc is at the wrong end of the words. */
		  itc_free (itc);
		}
	      dk_set_push (&wsts, (void*) wst);
	    }
	  else
	    break;
	  if (n_words > WST_WILDCARD_MAX)
	    {
	      NEW_SST (search_stream_t, sst);
	      sst->sst_error = srv_make_new_error ("22015", "FT038", "wildcard has over 1000 matches");
	      sst->sst_op = SRC_ERROR;
	      dk_free_tree ((caddr_t) list_to_array (wsts));
	      return sst;
	    }
	}
    }
  return wst_from_wsts (tctx, range_flags, wsts);
}
search_stream_t *
wst_from_word (sst_tctx_t *tctx, ptrlong range_flags, const char *word)
{
  vt_batch_t * vtb;
  caddr_t upper = NULL, lower = NULL;
  int rc = wp_wildcard_range (word, &lower, &upper);
  if (rc == RANGE_ERROR || rc == RANGE_NOT_SUPPORTED)
    {
      NEW_SST (search_stream_t, sst);
      sst->sst_is_desc = tctx->tctx_descending;
      sst->sst_range_flags = range_flags;
      sst->sst_view_from = ((range_flags & SRC_RANGE_MAIN) ? FIRST_MAIN_WORD_POS : FIRST_ATTR_WORD_POS);
      sst->sst_view_to = ((range_flags & SRC_RANGE_ATTR) ? LAST_ATTR_WORD_POS : LAST_MAIN_WORD_POS);
      sst->sst_error = srv_make_new_error ("22023", "FT370",
	  rc == RANGE_NOT_SUPPORTED ?  "Wildcards in text expressions are temporarily disabled in cluster configurations." :
	  			"Wildcard word needs at least 4 leading characters");
      sst->sst_op = SRC_ERROR;
      return sst;
    }
  if (rc == RANGE)
    {
      search_stream_t * sst = wst_from_range (tctx, range_flags, word, lower, upper);
      dk_free_box (lower);
      dk_free_box (upper);
      return (sst);
    }
  if (rc == EXACT_WORD)
    {
      caddr_t end_id = tctx->tctx_end_id;
      NEW_SST (word_stream_t, wst);
      wst->sst_is_desc = tctx->tctx_descending;
      wst->sst_range_flags = range_flags;
      wst->sst_view_from = ((range_flags & SRC_RANGE_MAIN) ? FIRST_MAIN_WORD_POS : FIRST_ATTR_WORD_POS);
      wst->sst_view_to = ((range_flags & SRC_RANGE_ATTR) ? LAST_ATTR_WORD_POS : LAST_MAIN_WORD_POS);
      wst->sst_op = SRC_WORD;
      wst->wst_table = tctx->tctx_table;
      wst->wst_qi = tctx->tctx_qi;
      D_SET_INITIAL (&wst->sst_d_id);
      D_SET_INITIAL (&wst->wst_first_d_id);
      D_SET_INITIAL (&wst->wst_last_d_id);
      wst->wst_word = box_dv_short_string (word);
      if (end_id)
	d_id_set_box (&wst->wst_end_id, end_id);
      vtb = tctx->tctx_vtb;
      if (vtb)
	{
	  lenmem_t lm;
	  word_batch_t * wb;
	  lm.lm_length = strlen(word);
	  lm.lm_memblock = (char *)word;
	  wb = (word_batch_t *) id_hash_get (vtb->vtb_words, (caddr_t) &lm);
	  if (!wb)
	    D_SET_AT_END (&wst->sst_d_id);
	  else
	    wst->wst_word_strings = (caddr_t *) wb->wb_word_recs;
	}
      else
	{
	}
      return ((search_stream_t *) wst);
    }
  return NULL; /*dummy*/
}


void
sst_related (search_stream_t * sst1, search_stream_t * sst2, int dist, int dist_is_fixed, int is_lefttoright)
{
  word_rel_t *rel;
  dk_set_t addon;
  DO_SET (word_rel_t *, rel, &sst1->sst_related)
    {
      if (rel->wrl_sst == sst2)
	return;
    }
  END_DO_SET ();
  rel = (word_rel_t *) dk_alloc (sizeof (word_rel_t));
  memset (rel, 0, sizeof (word_rel_t));
  rel->wrl_sst = sst2;
  rel->wrl_is_and = 1;
  rel->wrl_op = dist ? SRC_NEAR : BOP_AND;
  rel->wrl_is_dist_fixed = dist_is_fixed;
  rel->wrl_dist = dist;
  rel->wrl_is_lefttoright = is_lefttoright;
  /* Previous version was dk_set_push (&sst1->sst_related, (void*) rel);
     It's wrong because phrase "A B C" become "B after[dist=1] (C after[dist=2] A)",
     but should be "C after[dist=2] (B after[dist=1] A)" */
  addon = NULL;
  dk_set_push (&addon, (void *)rel);
  sst1->sst_related = dk_set_conc(sst1->sst_related, addon);
}

#define SST_IS_MERGEABLE(super, term) \
  ( (super->sst_op == BOP_AND && \
     (term->sst_op == SRC_NEAR || term->sst_op == SRC_WORD_CHAIN || term->sst_op == BOP_AND) && \
     sst_term_is_mergable (term)) \
    || (super->sst_op == SRC_NEAR && (term->sst_op == SRC_NEAR)))

int
sst_term_is_mergable (search_stream_t * term)
{
  int inx;
  DO_BOX (search_stream_t *, sst, inx, term->sst_terms)
    {
      if (sst->sst_op != SRC_WORD_CHAIN && sst->sst_op != SRC_NEAR && sst->sst_op != BOP_AND && sst->sst_op != SRC_WORD)
	return 0;
      if (sst->sst_op != SRC_WORD && !sst_term_is_mergable (sst))
	return 0;
    }
  END_DO_BOX;
  return 1;
}

void
sst_interrelate (search_stream_t * sst, int calc_score)
{
  int inx1, inx2;
  DO_BOX (search_stream_t *, sst1, inx1, sst->sst_terms)
    {
      if ((SRC_WORD_CHAIN == sst->sst_op || SRC_NEAR == sst->sst_op)
	  && SRC_WORD != sst1->sst_op)
	sst->sst_need_ranges = 1;
      DO_BOX (search_stream_t *, sst2, inx2, sst->sst_terms)
	{
	  if (sst1 != sst2)
	    {
	      if (SRC_WORD_CHAIN == sst->sst_op)
		{
		  sst_related (sst1, sst2, inx2 - inx1, 1, 1);
		  sst_related (sst2, sst1, inx1 - inx2, 1, 1);
		}
	      else if (SRC_NEAR == sst->sst_op)
		{
		  sst_related (sst1, sst2, NEAR_DIST, 0, 0);
		  sst_related (sst2, sst1, NEAR_DIST, 0, 0);
		}
	      else
		{
/* This does not work
		  int should_make_near = (calc_score &&
		    (sst1->sst_range_flags == sst2->sst_range_flags) &&
		    (SRC_WORD == sst1->sst_op) && (SRC_WORD == sst2->sst_op) );
		  int dist = (should_make_near ? HUGE_DIST : 0);
 */
		  sst_related (sst1, sst2, 0 /* not 'dist' */, 0, 0);
		  sst_related (sst2, sst1, 0 /* not 'dist' */, 0, 0);
		}
	    }
	}
      END_DO_BOX;
    }
  END_DO_BOX;
  if (SRC_NEAR == sst->sst_op || SRC_WORD_CHAIN == sst->sst_op)
    dk_set_pushnew (&sst->sst_near_group_firsts, (void*) sst->sst_terms[0]);
}


void
sst_merge_ands (search_stream_t * sst, int calc_score)
{
  int total = 0, nots = 0;
  int inx;
  search_stream_t ** old_terms;
  DO_BOX (search_stream_t *, term, inx, sst->sst_terms)
    {
      if (term->sst_op == BOP_AND
	  && term->sst_not)
	{
	  nots += dk_set_length (term->sst_not);
	  total += BOX_ELEMENTS (term->sst_terms);
	}
      else if (SST_IS_MERGEABLE (sst, term))
	total += BOX_ELEMENTS (term->sst_terms);
      else
	total++;
    }
  END_DO_BOX;
  old_terms = sst->sst_terms;
  if (nots ||  total > (int) BOX_ELEMENTS (old_terms))
    {
      size_t fill = 0;
      search_stream_t ** new_terms = (search_stream_t**) dk_alloc_box (total * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      DO_BOX (search_stream_t *, term, inx, old_terms)
	{
	  if (SST_IS_MERGEABLE (sst, term))
	    {
	      memcpy (((char*) new_terms) + fill, term->sst_terms, box_length (term->sst_terms));
	      fill += box_length (term->sst_terms);
	      sst->sst_not = dk_set_conc (sst->sst_not, term->sst_not);
	      term->sst_not = NULL;
	      sst->sst_near_group_firsts = dk_set_conc (sst->sst_near_group_firsts, term->sst_near_group_firsts);
	      term->sst_near_group_firsts = NULL;
	      memset (term->sst_terms, 0, box_length (term->sst_terms));
	      dk_free_box ((caddr_t) term);
	    }
	  else
	    {
	      new_terms[fill / sizeof (caddr_t)] = term;
	      fill += sizeof (caddr_t);
	    }
	}
      END_DO_BOX;
      if (fill != (total * sizeof (caddr_t)))
	GPF_T;
      sst->sst_terms = new_terms;
      dk_free_box ((box_t) old_terms);
    }
  sst_interrelate (sst, calc_score);
  sst->sst_range_flags = 0;
  DO_BOX (search_stream_t *, curr_term, inx, sst->sst_terms)
    {
      sst->sst_range_flags |= curr_term->sst_range_flags;
    }
  END_DO_BOX;
  sst->sst_view_from = ((sst->sst_range_flags & SRC_RANGE_MAIN) ? FIRST_MAIN_WORD_POS : FIRST_ATTR_WORD_POS);
  sst->sst_view_to = ((sst->sst_range_flags & SRC_RANGE_ATTR) ? LAST_ATTR_WORD_POS : LAST_MAIN_WORD_POS);
}

/* Structure of text search expression tree:
SRC_WORD:
 wr_flags word

BOP_AND,SRC_NEAR,BOP_OR,SRC_WORD_CHAIN,XP_AND_NOT:
 wr_flags, arg1,...argN
*/

#ifdef TEXT_DEBUG
static search_stream_t *sst_from_tree_debug (sst_tctx_t *tctx, caddr_t * tree);
#endif


search_stream_t *
sst_from_tree (sst_tctx_t *tctx, caddr_t * tree)
{
#ifdef TEXT_DEBUG
search_stream_t *res;
dbg_printf(("\n{ sst_from_tree(%x, ",tctx));
dbg_print_box ((caddr_t)(tree), stdout);
dbg_printf((")"));
res = sst_from_tree_debug (tctx, tree);
dbg_printf(("\nreturn\n"));
dbg_print_box ((caddr_t)(res), stdout);
dbg_printf((" }\n"));
return res;
}

search_stream_t *
sst_from_tree_debug (sst_tctx_t *tctx, caddr_t * tree)
{
#endif
  int op = /*unbox (tree[0])*/ (int) ((ptrlong *)tree)[0];
  int range_flags = /*unbox (tree[1])*/ (int) ((ptrlong *)tree)[1];
#ifdef DEBUG
  if (SRC_RANGE_DUMMY & range_flags)
    GPF_T1 ("dummy ranges in sst_from_tree");
#endif
  switch (op)
    {
    case SRC_WORD:
      return (wst_from_word (tctx, range_flags, tree[2]));
    case BOP_AND:
    case SRC_NEAR:
    case BOP_OR:
    case SRC_WORD_CHAIN:
      {
	size_t inx, tree_elems = BOX_ELEMENTS (tree);
	search_stream_t ** terms;
	NEW_SST (search_stream_t, sst);
	sst->sst_is_desc = tctx->tctx_descending;
	sst->sst_range_flags = range_flags;
	sst->sst_view_from = ((range_flags & SRC_RANGE_MAIN) ? FIRST_MAIN_WORD_POS : FIRST_ATTR_WORD_POS);
	sst->sst_view_to = ((range_flags & SRC_RANGE_ATTR) ? LAST_ATTR_WORD_POS : LAST_MAIN_WORD_POS);
	terms = (search_stream_t **) dk_alloc_box ((tree_elems-2)*sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	D_SET_INITIAL (&sst->sst_d_id);
	sst->sst_op = op;
	sst->sst_terms = terms;
	for (inx = 2; inx < tree_elems; inx++)
	  {
	    search_stream_t * curr_term = sst_from_tree (tctx, (caddr_t*) tree[inx]);
	    terms[inx - 2] = curr_term;
	  }
	if (BOP_OR != op)
	  sst_merge_ands (sst, (int) tctx->tctx_calc_score);
	return (sst);
      }
    case XP_AND_NOT:
      {
	search_stream_t ** terms = (search_stream_t **) dk_alloc_box (sizeof (caddr_t), DV_ARRAY_OF_POINTER);
	NEW_SST (search_stream_t, sst);
	sst->sst_is_desc = tctx->tctx_descending;
	sst->sst_range_flags = range_flags;
	sst->sst_view_from = ((range_flags & SRC_RANGE_MAIN) ? FIRST_MAIN_WORD_POS : FIRST_ATTR_WORD_POS);
	sst->sst_view_to = ((range_flags & SRC_RANGE_ATTR) ? LAST_ATTR_WORD_POS : LAST_MAIN_WORD_POS);
	D_SET_INITIAL (&sst->sst_d_id);
	sst->sst_op = BOP_AND;
	sst->sst_terms = terms;
	dk_set_push (&sst->sst_not, (void*) sst_from_tree (tctx, (caddr_t*) tree[3]));
	terms[0] = sst_from_tree (tctx, (caddr_t*) tree[2]);
	sst_merge_ands (sst, (int) tctx->tctx_calc_score);
	return (sst);
      }
    default:
      GPF_T1 ("bad text-search operation in sst_from_tree");
    }
  return NULL; /* dummy */
}


caddr_t
bif_vtb_match (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  d_id_t d_id_next;
  dk_set_t res = NULL, score_list = NULL, ranges_list = NULL;
  sst_tctx_t context;
  search_stream_t * sst;
  query_instance_t * qi = (query_instance_t *) qst;
  caddr_t err = NULL, name;
  caddr_t * tree;
  lang_handler_t *lh = server_default_lh;
  encoding_handler_t *eh = &eh__ISO8859_1;
  vt_batch_t * vtb = bif_vtb_arg (qst, args, 0, "vt_batch_match");
  caddr_t str = bif_array_arg (qst, args, 1, "vt_batch_match"); /* use an array as argument bif_string_arg */
  state_slot_t * scores = BOX_ELEMENTS (args) > 2 && ssl_is_settable (args[2]) ? args[2] : NULL;
  state_slot_t * ranges = BOX_ELEMENTS (args) > 3 && ssl_is_settable (args[3]) ? args[3] : NULL;
  dtp_t dtp = DV_TYPE_OF (str);

  switch (BOX_ELEMENTS (args))
    {
      case 6:
	name = bif_string_arg (qst, args, 5, "vt_batch_match");
	if (strcmp (name, "*ini*"))
	  {
	    eh = eh_get_handler (name);
	    if (NULL == eh)
	      sqlr_new_error ("42000", "FT036", "Invalid encoding name '%s' is specified by an argument of vt_batch_match()", name);
	  }
	/* no break */
      case 5:
	name = bif_string_arg (qst, args, 4, "vt_batch_match");
	if (strcmp (name, "*ini*"))
	  {
	    lh = lh_get_handler (name);
	    if (NULL == lh)
	      sqlr_new_error ("42000", "FT037", "Invalid language name '%s' is specified by an argument of vt_batch_match()", name);
	  }
    }

  D_SET_INITIAL (&d_id_next);
  if (!vtb->vtb_strings_taken)
    sqlr_new_error ("42000", "FT005", "vtb_match only allowed after vt_batch_strings");
  if (IS_STRING_DTP (dtp))
    {
      tree = xp_text_parse (str, eh, lh, NULL /* ignore run-time options */, &err);
      if (err)
	{
	  dk_free_tree ((caddr_t) tree);
	  sqlr_resignal (err);
	}
    }
  else
    tree = (caddr_t *) str;

  context.tctx_vtb = vtb; /* SET_THR_ATTR (qi->qi_thread, TA_SST_USE_VTB, (void*) vtb); */
  context.tctx_descending = 0; /* SET_THR_ATTR (qi->qi_thread, TA_SST_DESC_ORDER, (void*) 0); */
  context.tctx_end_id = 0; /* SET_THR_ATTR (qi->qi_thread, TA_SST_END_ID, (void*) 0); */
  context.tctx_qi = qi;
  context.tctx_table = NULL;
  context.tctx_calc_score = ((NULL != scores) ? 1 : 0);
  context.tctx_range_flags = SRC_RANGE_MAIN;
  xpt_edit_range_flags (tree, ~SRC_RANGE_DUMMY, SRC_RANGE_MAIN);
  sst = sst_from_tree (&context, (caddr_t*)tree);
  if (IS_STRING_DTP (dtp))
    dk_free_tree ((caddr_t) tree);

  D_SET_INITIAL (&d_id_next);
  for (;;)
    {
      QR_RESET_CTX
	{
	  sst_next (sst, &d_id_next, 0);
	}
      QR_RESET_CODE
	{
	  du_thread_t * self = THREAD_CURRENT_THREAD;
	  caddr_t err = thr_get_error_code (self);
	  POP_QR_RESET;
	  *err_ret = err;
	  /* cleanup */
	  dk_free_box ((caddr_t) sst);
	  dk_free_tree (list_to_array (dk_set_nreverse (score_list)));
	  dk_free_tree (list_to_array (dk_set_nreverse (ranges_list)));
	  dk_free_tree (list_to_array (dk_set_nreverse (res)));
	  return NULL;
	}
      END_QR_RESET
      if (D_AT_END (&sst->sst_d_id))
	break;
      D_SET_NEXT (&d_id_next);
      dk_set_push (&res, (void*) box_d_id (&sst->sst_d_id));
      if (scores)
	{
	  sst_scores (sst, &sst->sst_d_id);
	  dk_set_push (&score_list, (void*) box_num (sst->sst_score));
	}
      if (ranges)
	{
	  dk_set_t main_list = NULL, attr_list = NULL;
	  sst_ranges (sst, &sst->sst_d_id, sst->sst_view_from, sst->sst_view_to, 1);
	  sst_range_lists (sst, &main_list, &attr_list);
	  dk_set_push (&ranges_list, (void*) list_to_array (dk_set_nreverse (main_list)));
	  /* attr_list should remain empty here,
	     because there's no way to create attr ranges in plain text expression
	     and there's context.tctx_range_flags = SRC_RANGE_MAIN; setting above.
	   */
	}
    }
  if (scores)
    qst_set (qst, scores, list_to_array (dk_set_nreverse (score_list)));

  if (ranges)
    qst_set (qst, ranges, list_to_array (dk_set_nreverse (ranges_list)));

  dk_free_box ((caddr_t) sst);
  return (list_to_array (dk_set_nreverse (res)));
}


caddr_t
bif_vt_parse (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /*DELME: query_instance_t * qi = (query_instance_t *) qst;*/
  caddr_t err = NULL;
  caddr_t * tree = NULL;
  caddr_t str = bif_string_arg (qst, args, 0, "vt_parse");
  tree = xp_text_parse (str, &eh__ISO8859_1, server_default_lh, NULL /* ignore run-time options */, &err);
  if (err)
    {
      dk_free_tree ((caddr_t) tree);
      sqlr_resignal (err);
    }
  return ((caddr_t) tree);
}


int
sst_destroy (search_stream_t * sst)
{
  dk_free_box ((caddr_t) sst->sst_all_ranges);
  dk_free_tree (sst->sst_error);
  DO_SET (word_rel_t *, rel, &sst->sst_related)
    {
      dk_free ((caddr_t) rel, sizeof (word_rel_t));
    }
  END_DO_SET();
  dk_set_free (sst->sst_related);
  if (SRC_WORD == sst->sst_op)
    {
      caddr_t item;
      word_stream_t * wst = (word_stream_t *) sst;
      if (wst->wst_itc)
	itc_free (wst->wst_itc);
      dk_free_box (wst->wst_word);
      dk_free_box (wst->wst_seek_target_box);
      dk_free_box ((caddr_t) sst->sst_pos_array);
      if (!wst->wst_word_strings) /* if against db, not a set of word batch strings */
	dk_free_box (sst->sst_buffer);
      while ((item = (caddr_t)basket_get (&wst->wst_cl_word_strings)))
	dk_free_tree (item);
      dk_free_box ((caddr_t)wst->wst_clrg);
      return 0;
    }
  dk_free_box (sst->sst_buffer);
  dk_free_tree ((caddr_t) sst->sst_terms);
    DO_SET (caddr_t, _not, &sst->sst_not)
    {
      dk_free_box (_not);
    }
  END_DO_SET ();
  dk_set_free (sst->sst_not);
  dk_set_free (sst->sst_near_group_firsts);
  return 0;
}


void
txs_set_offband (text_node_t * txs, caddr_t * qst)
{
  int inx;
  if (txs->txs_offband)
    {
      search_stream_t * sst = (search_stream_t *) qst_get (qst, txs->txs_sst);
      DO_BOX (word_stream_t *, wst, inx, sst->sst_terms)
	{
	  if (SRC_WORD == wst->sst_op
	      && 0 == strcmp (wst->wst_word, WST_OFFBAND))
	    {
	      size_t inx2;
	      caddr_t * offband;
	      db_buf_t buf = (db_buf_t) (wst->sst_buffer + wst->sst_pos);
	      int pos_len, len;
	      WP_LENGTH (buf, pos_len, len, wst->sst_buffer, wst->sst_buffer_size);
	      len -= WP_FIRST_POS (buf + pos_len);
	      buf += pos_len + WP_FIRST_POS (buf + pos_len);
	      offband = (caddr_t *) box_deserialize_string ((caddr_t) buf , len, 0);
	      for (inx2 = 0; inx2 < BOX_ELEMENTS (txs->txs_offband); inx2 += 2)
		{
		  size_t nth_offb = (size_t)((ptrlong) txs->txs_offband[inx2]);
		  state_slot_t * ssl = txs->txs_offband[inx2 + 1];
		  if (IS_BOX_POINTER (offband) && BOX_ELEMENTS (offband) > nth_offb)
		    {
		      TXS_QST_SET (txs, qst, ssl, offband[nth_offb]);
		      offband[nth_offb] = NULL;
		    }
		}
	      dk_free_tree ((caddr_t) offband);
	      return;
	    }

	}
      END_DO_BOX;
    }
}


void
txs_init (text_node_t * txs, query_instance_t * qi)
{
  caddr_t * qst = (caddr_t*) qi;
  search_stream_t * sst;
  caddr_t err = NULL;
  caddr_t str = qst_get (qst, txs->txs_text_exp);
  caddr_t * old_tree, * tree;
  caddr_t dtd_config = NULL;
  caddr_t cached_string;
  int tree_is_temporary;
  sst_tctx_t context;
  if (txs->txs_xn_xq_source)
    {
      tree_is_temporary = 1;
      tree = (caddr_t *) txs_xn_text_query (txs, (query_instance_t *)qst, str);
#ifdef TEXT_DEBUG
      fprintf(stderr, "\nCompiled xcontains text criteria:\n");
      dbg_print_box((caddr_t)tree,stderr);
      fprintf(stderr, "\n");
      fflush(stderr);
#endif
      if (!tree)
	sqlr_new_error ("22023", "XP370" , "xpath expression in xcontains has no text criteria");
    }
  else
    {
      wcharset_t *query_charset;
      encoding_handler_t *eh;
      query_charset = QST_CHARSET(qi);
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
      tree_is_temporary = 0;
      err = NULL;
      cached_string = (caddr_t) qst_get (qst, txs->txs_cached_string);
      if (NULL != cached_string)		/* cache is nonempty */
	{
	  if(strcmp(cached_string, str))
	    {
	      qst_set (qst, txs->txs_cached_string, NULL);
	      qst_set (qst, txs->txs_cached_compiled_tree, NULL);
	      qst_set (qst, txs->txs_cached_dtd_config, NULL);
	      old_tree = NULL;
	      goto parse_new_tree;
	    }
	  else
	    {
	      old_tree = tree = (caddr_t *)qst_get (qst, txs->txs_cached_compiled_tree);
	      goto skip_parsing_of_new_tree;
	    }
	}
      else					/* cache is empty */
	{
	  old_tree = NULL;
	  goto parse_new_tree;
	}
parse_new_tree:
      tree = xp_text_parse (str, eh, server_default_lh, &dtd_config, &err);
      if (NULL != err)
	{
	  dk_free_tree ((caddr_t)tree);
	  dk_free_tree (dtd_config);
	  sqlr_resignal (err);
	}
      xpt_edit_range_flags (tree, ~SRC_RANGE_DUMMY, SRC_RANGE_MAIN);
      qst_set (qst, txs->txs_cached_dtd_config, dtd_config);
skip_parsing_of_new_tree:
      qst_set (qst, txs->txs_cached_string, box_dv_short_string(str));
      if (tree != old_tree)
	qst_set (qst, txs->txs_cached_compiled_tree, (caddr_t) tree);
    }
  context.tctx_vtb = NULL; /* SET_THR_ATTR (qi->qi_thread, TA_SST_USE_VTB, NULL); */
  context.tctx_descending = (txs->txs_desc ? (int) unbox (qst_get (qst, txs->txs_desc)) : 0);
/*
  if (txs->txs_desc)
    SET_THR_ATTR (qi->qi_thread, TA_SST_DESC_ORDER, (void*)
		  unbox (qst_get (qst, txs->txs_desc)));
  else
    SET_THR_ATTR (qi->qi_thread, TA_SST_DESC_ORDER, (void*) 0);
*/
  context.tctx_end_id = (txs->txs_end_id ? qst_get (qst, txs->txs_end_id) : NULL);
/*
  SET_THR_ATTR (qi->qi_thread, TA_SST_END_ID, txs->txs_end_id ? (void*) qst_get (qst, txs->txs_end_id) : NULL);
*/
  if (txs->txs_offband)
    tree = (caddr_t *) list (4, BOP_AND, (ptrlong)SRC_RANGE_MAIN, tree, list (3, (ptrlong)SRC_WORD, (ptrlong)SRC_RANGE_MAIN, box_dv_short_string (WST_OFFBAND)));
  context.tctx_qi = qi;
  context.tctx_table = txs->txs_table;
  context.tctx_calc_score = ((NULL != txs->txs_score) ? 1 : 0);
  context.tctx_range_flags = SRC_RANGE_DUMMY;
  sst = sst_from_tree (&context, (caddr_t*)tree);
  if (tree_is_temporary)
    dk_free_tree ((caddr_t)tree);
  else if (txs->txs_offband)
    {
      caddr_t * tree2 = tree;
      tree = (caddr_t *) tree[2];
      tree2[2] = NULL;
      dk_free_tree ((caddr_t) tree2);
    }
  qst_set (qst, txs->txs_sst, (caddr_t) sst);
}


ptrlong *
sst_range_array (search_stream_t * sst)
{
  int fill;
  ptrlong * res, * tgt;
  word_range_t * src = sst->sst_all_ranges;
  fill = sst->sst_all_ranges_fill;
  res = (ptrlong*) dk_alloc_box (sizeof (ptrlong) * 2 * fill, DV_ARRAY_OF_LONG);
  tgt = res;
  while(fill--)
    {
      (tgt++)[0] = src->r_start;
      (tgt++)[0] = src->r_end;
      src++;
    }
  return res;
}


void
sst_range_lists (search_stream_t * sst, dk_set_t * main_ranges, dk_set_t * attr_ranges)
{
  switch (sst->sst_op)
    {
    case SRC_WORD:
    case BOP_OR:
      switch (sst->sst_range_flags & (SRC_RANGE_MAIN | SRC_RANGE_ATTR))
	{
	case SRC_RANGE_MAIN:
	  dk_set_push (main_ranges, (void*) sst_range_array (sst));
	  return;
	case SRC_RANGE_ATTR:
	  dk_set_push (attr_ranges, (void*) sst_range_array (sst));
	  return;
	}
      return;
    case BOP_AND:
    case SRC_WORD_CHAIN:
    case SRC_NEAR:
      {
	int inx;
	DO_BOX (search_stream_t *, term, inx, sst->sst_terms)
	  {
	    if (sst_is_top_and_term (sst, term))
	      sst_range_lists (term, main_ranges, attr_ranges);
	  }
	END_DO_BOX;
      }
    }
}


void
txs_set_ranges (text_node_t * txs, caddr_t * qst, search_stream_t * sst)
{
/* IvAn/SmartXContains/001025 Now ranges may remains unused even if
   there's a room allocated for them.
   Thus if (txs->txs_range_out)... becomes unusable */
  dk_set_t main_list = NULL, attr_list = NULL;
  ptrlong ** main_ranges;
  ptrlong ** attr_ranges;
  if (txs->txs_why_ranges == 0x00)
    return;
  sst_ranges (sst, &sst->sst_d_id, sst->sst_view_from, sst->sst_view_to, 1);
  sst_range_lists (sst, &main_list, &attr_list);
  main_ranges = (ptrlong **)list_to_array (dk_set_nreverse (main_list));
  attr_ranges = (ptrlong **)list_to_array (dk_set_nreverse (attr_list));
  TXS_QST_SET (txs, qst, txs->txs_main_range_out, (caddr_t)(main_ranges));
  TXS_QST_SET (txs, qst, txs->txs_attr_range_out, (caddr_t)(attr_ranges));
#ifdef TEXT_DEBUG
  fprintf(stderr,"\ntxs_set_ranges(...) stores ");
  dbg_print_box((caddr_t)main_ranges,stderr);
  fprintf(stderr," and ");
  dbg_print_box((caddr_t)attr_ranges,stderr);
  fprintf(stderr," for row %ld", (long)(unbox (qst_get (qst, txs->txs_d_id))));
#endif
}


int
txs_is_hit_between_1 (ptrlong * ranges, wpos_t from, wpos_t to)
{
  int left_cop, robber, right_cop;
  /* Here we perform binary search on EVEN indexes (i.e. starts of ranges) */
  left_cop = 0; right_cop = BOX_ELEMENTS(ranges);
  if (0 == right_cop)
    return 0;
  right_cop -= 2;
  if ((wpos_t)(ranges[0]) >= to)
    return 0;
  while (right_cop > left_cop)
    {
      robber = ((left_cop+right_cop)/2) & ~1;
      if ((wpos_t)(ranges[robber]) < from)
	left_cop = robber+2;
      else
	{
	  if(right_cop > robber)
	    right_cop = robber;
	  else
	    if ((wpos_t)(ranges[left_cop]) < from)
	      left_cop += 2;
	    else
	      break;
	}
    }
  return ((wpos_t) ranges[left_cop]) >= from && ((wpos_t) ranges[left_cop+1]) < to;
}


int
txs_is_hit_in (text_node_t * txs, caddr_t * qst, xml_entity_t *xe)
{
#ifdef TEXT_DEBUG
  long row_idx = unbox (qst_get (qst, txs->txs_d_id));
#endif
  ptrlong ** main_ranges = (ptrlong**)(qst_get(qst,txs->txs_main_range_out));
  ptrlong ** attr_ranges = (ptrlong**)(qst_get(qst,txs->txs_attr_range_out));
  long main_count = ((NULL == main_ranges) ? 0 : (long)(BOX_ELEMENTS(main_ranges)));
  long attr_count = ((NULL == attr_ranges) ? 0 : (long)(BOX_ELEMENTS(attr_ranges)));
  long idx;
#ifdef TEXT_DEBUG
  fprintf(stderr,"\n{ Calculating txs_is_hit_in at row %ld", row_idx);
  if (main_count < 20)
    {
      fprintf(stderr,"\n  main_ranges = ");
      dbg_print_box((caddr_t)main_ranges,stderr);
    }
  if (attr_count < 20)
    {
      fprintf(stderr,"\n  attr_ranges = ");
      dbg_print_box((caddr_t)attr_ranges,stderr);
    }
#endif

  if (0 != attr_count)
    {
      wpos_t start_wpos, this_end_wpos, whole_end_wpos;
      xe->_->xe_attr_word_range (xe, &start_wpos, &this_end_wpos, &whole_end_wpos);
#ifdef TEXT_DEBUG
      fprintf(stderr,"\n  attr scope is from %u to %u", (unsigned)start_wpos, (unsigned)whole_end_wpos);
#endif
      whole_end_wpos += 1; /* Search range captures the closing attribute name */
      for (idx = 0; idx < attr_count; idx++)
	{
	  if (txs_is_hit_between_1 (attr_ranges[idx], start_wpos, whole_end_wpos))
	    {
#ifdef TEXT_DEBUG
	      fprintf(stderr,"\n HIT in attr range %d\n", idx);
#endif
	      goto check_main;
	    }
	}
#ifdef TEXT_DEBUG
      fprintf(stderr,"\n NOTHING FOUND IN ATTR\n");
#endif
      return 0;
    }

check_main:
  if (0 != main_count)
    {
      wpos_t start_wpos, end_wpos;
      xe->_->xe_word_range (xe, &start_wpos, &end_wpos);
#ifdef TEXT_DEBUG
      fprintf(stderr,"\n  main scope is from %u to %u", (unsigned)start_wpos, (unsigned)end_wpos);
#endif
      end_wpos += 1; /* Search range captures the closing tag */
      for (idx = 0; idx < main_count; idx++)
	{
	  if (txs_is_hit_between_1 (main_ranges[idx], start_wpos, end_wpos))
	    {
#ifdef TEXT_DEBUG
	      fprintf(stderr,"\n HIT in main range %d\n", idx);
#endif
	      goto done;
	    }
	}
#ifdef TEXT_DEBUG
      fprintf(stderr,"\n NOTHING FOUND IN MAIN\n");
#endif
      return 0;
    }
done:
#ifdef TEXT_DEBUG
  fprintf(stderr,"\n ALL HITS ARE FOUND\n");
#endif
  return 1;
}


caddr_t
txs_next (text_node_t * txs, caddr_t * qst, int first_time)
{
  search_stream_t * sst = (search_stream_t *) qst_get (qst, txs->txs_sst);
  d_id_t d_id;
  int score_limit = txs->txs_score_limit ? (int) unbox (qst_get (qst, txs->txs_score_limit)) : 0;
  d_id_set_box (&d_id, qst_get (qst, txs->txs_d_id));
  if (!txs->txs_is_driving)
    {
      if (D_AT_END (&d_id))
	return ((caddr_t) SQL_NO_DATA_FOUND);
      sst_next (sst, &d_id, 1);
      if (DVC_MATCH != d_id_cmp (&sst->sst_d_id, &d_id))
	return ((caddr_t) SQL_NO_DATA_FOUND);

      if (score_limit || txs->txs_score)
	sst_scores (sst, &d_id);
      if (txs->txs_score)
	TXS_QST_SET (txs, qst, txs->txs_score, box_num (sst->sst_score));
      if (score_limit && sst->sst_score < score_limit)
	return ((caddr_t) SQL_NO_DATA_FOUND);
      txs_set_ranges (txs, qst, sst);
      return ((caddr_t) SQL_SUCCESS);

    }
  for (;;)
    {
      if (first_time)
	{
	  if (txs->txs_init_id)
	    d_id_set_box (&d_id, qst_get (qst, txs->txs_init_id));
	  else
	    D_SET_INITIAL (&d_id);
	}
      else
	D_SET_NEXT (&d_id);
      d_id = * sst_next (sst, &d_id, 0);
      first_time = 0;
      if (D_AT_END (&sst->sst_d_id))
	return ((caddr_t) SQL_NO_DATA_FOUND);
      if (score_limit || txs->txs_score)
	sst_scores (sst, &d_id);
      if (score_limit && sst->sst_score < score_limit)
	continue;
      break;
    }
  if (txs->txs_score)
    TXS_QST_SET (txs, qst, txs->txs_score, box_num (sst->sst_score));
  if (txs->txs_is_rdf)
    {
      unsigned int64 n = D_ID_NUM_REF (&d_id.id[0]);
      dtp_t buf[9];
      int len;
      if (((dtp_t*)(&d_id.id[0]))[0] == D_ID_64)
	{
	  buf[0] = DV_RDF_ID_8;
	  INT64_SET_NA (&buf[1], n);
	  len = 9;
	}
      else
	{
	  buf[0] = DV_RDF_ID;
	  LONG_SET_NA (&buf[1], n);
	  len = 5;
	}
      if (txs->src_gen.src_sets)
	{
	  data_col_t * dc = QST_BOX (data_col_t *, qst, txs->txs_d_id->ssl_index);
	  dc_append_bytes (dc, buf, len, NULL, 0);
	}
      else
      TXS_QST_SET (txs, qst, txs->txs_d_id, (caddr_t)rbb_from_id (n));
    }
  else
    {
      TXS_QST_SET (txs, qst, txs->txs_d_id, box_d_id (&d_id));
    }
  txs_set_offband (txs, qst);
  txs_set_ranges (txs, qst, sst);
  return ((caddr_t) SQL_SUCCESS);
}


void
txs_qc_lookup (text_node_t * txs, caddr_t * inst)
{
  QNCAST (QI, qi, inst);
  dbe_key_t * key = txs->txs_table->tb_primary_key;
  qc_result_t *qcr;
  uint32 clslice = key->key_partition ? (uint32)key->key_partition->kpd_map->clm_id + (((uint32)qi->qi_client->cli_slice) << 16) : 0;
  caddr_t  qckey = list (2, box_num (key->key_id), box_copy (qst_get (inst, txs->txs_text_exp)));
  qcr= qc_lookup (clslice, qckey);
  qst_set (inst, txs->txs_qcr, (caddr_t)qcr);
  if (!qcr)
    return;
}

void
txs_qc_accumulate (text_node_t * txs, caddr_t * inst)
{
  data_col_t * id = QST_BOX (data_col_t *, inst, txs->txs_d_id->ssl_index);
  data_col_t * score = NULL, * id_cp = NULL, * score_cp = NULL;
  qc_result_t * qcr = (qc_result_t *)QST_GET_V (inst, txs->txs_qcr);
  if (!qcr)
    return;
  id_cp = mp_data_col (qcr->qcr_mp, txs->txs_d_id, id->dc_n_values);
  dc_copy (id_cp, id);
  if (txs->txs_score)
    {
      score = QST_BOX (data_col_t *, inst, txs->txs_score->ssl_index);
      score_cp = mp_data_col (qcr->qcr_mp, txs->txs_score, id->dc_n_values);
      dc_copy (score_cp, score);
    }
  mp_array_add (qcr->qcr_mp, (caddr_t **) &qcr->qcr_result, &qcr->qcr_fill, (void*) id_cp);
  mp_array_add (qcr->qcr_mp, (caddr_t **) &qcr->qcr_result, &qcr->qcr_fill, (void*) score_cp);
  if (!SRC_IN_STATE (txs, inst))
    {
      mutex_enter (&qcr_ref_mtx);
      qcr->qcr_status = QCR_READY;
      QST_BOX (void*, inst, txs->txs_qcr->ssl_index) = NULL;
      qcr->qcr_ref_count--;
      mutex_leave (&qcr_ref_mtx);
    }
}


void
txs_from_qcr (text_node_t * txs, caddr_t * inst, caddr_t * state)
{
  int nth_dc = QST_INT (inst, txs->txs_pos_in_qcr);
  int pos_in_dc = QST_INT (inst, txs->txs_pos_in_dc);
  qc_result_t * qcr = (qc_result_t *)QST_GET_V (inst, txs->txs_qcr);
  data_col_t * id_ret = QST_BOX (data_col_t *, inst, txs->txs_d_id->ssl_index);
  data_col_t * score_ret = QST_BOX (data_col_t *, inst, txs->txs_score->ssl_index);
  int batch_size = QST_INT (inst, txs->src_gen.src_batch_size), dc_inx, pos;
  if (state)
    {
      pos_in_dc = nth_dc = 0;
    }
  for (dc_inx = nth_dc; dc_inx < qcr->qcr_fill; dc_inx += 2)
    {
      data_col_t * id = qcr->qcr_result[dc_inx];
      data_col_t * score = qcr->qcr_result[dc_inx + 1];
      for (pos = pos_in_dc; pos < id->dc_n_values; pos++)
	{
	  if (score)
	    dc_append_int64 (score_ret, ((int64*)score->dc_values)[pos]);

	  dc_append_int64 (id_ret, ((int64*)id->dc_values)[pos]);
	  qn_result ((data_source_t *)txs, inst, 0);
	  if (id_ret->dc_n_values == batch_size)
	    {
	      QST_INT (inst, txs->txs_pos_in_dc) = pos + 1;
	      QST_INT (inst, txs->txs_pos_in_qcr) = dc_inx;
	      SRC_IN_STATE (txs, inst) = inst;
	      qn_send_output ((data_source_t*)txs, inst);
	      batch_size = QST_INT (inst, txs->src_gen.src_batch_size);
	      dc_reset_array (inst, (data_source_t*)txs, txs->src_gen.src_continue_reset, -1);
	      QST_INT (inst, txs->src_gen.src_out_fill) = 0;
	      state = NULL;
	    }
	}
      pos_in_dc = 0;
    }
  SRC_IN_STATE (txs, inst) = NULL;
  if (QST_INT (inst, txs->src_gen.src_out_fill))
    qn_send_output ((data_source_t*)txs, inst);
}


#define DCINT1(dc)  ((int*)(dc)->dc_values)[0]


void
txs_qcr_reverse (qc_result_t * qcr)
{
  int inx, sz = 0, n;
  for (inx = 0; inx < qcr->qcr_fill; inx += 2)
    sz += qcr->qcr_result[inx]->dc_n_values;
  SET_THR_TMP_POOL (qcr->qcr_mp);
  qcr->qcr_reverse = t_id_hash_allocate (sz, sizeof (boxint), sizeof (boxint), boxint_hash, boxint_hashcmp);
    for (inx =  0; inx < qcr->qcr_fill; inx += 2)
      {
	data_col_t * id = qcr->qcr_result[inx];
	data_col_t * score = qcr->qcr_result[inx + 1];
	for (n = 0; n < id->dc_n_values; n++)
	  {
	    t_id_hash_set (qcr->qcr_reverse, (caddr_t)& ((int64*)id->dc_values)[n], (caddr_t) &((int64*)score->dc_values)[n]);
	  }
      }
    SET_THR_TMP_POOL (NULL);
}

dk_mutex_t * txs_qcr_rev_mtx;

void
txs_qcr_check (text_node_t * txs, caddr_t * inst)
{
  /* d id is given, see if these are in the qcr */
  QNCAST (QI, qi, inst);
#if 0
  data_col_t * dc = NULL;
  int at_or_above = 0, below, guess;
  int64 n;
#endif
  qc_result_t * qcr = QST_BOX (qc_result_t *, inst, txs->txs_qcr->ssl_index);
  int n_sets = QST_INT (inst, txs->src_gen.src_prev->src_out_fill), set;
  QST_INT (inst, txs->src_gen.src_out_fill) = 0;
  mutex_enter (txs_qcr_rev_mtx);
  if (!qcr->qcr_reverse)
    txs_qcr_reverse (qcr);
  mutex_leave (txs_qcr_rev_mtx);
  for (set = 0; set < n_sets; set++)
    {
      int64 d_id = qst_vec_get_int64 (inst, txs->txs_d_id, set);
      if (qcr->qcr_reverse)
	{
	  int64 * place = (int64 *) id_hash_get (qcr->qcr_reverse, (caddr_t)&d_id);
	  if (place)
	    {
	      qi->qi_set = set;
	      qst_set_long (inst, txs->txs_score, *place);
	      qn_result ((data_source_t *)txs, inst, set);
	    }
	}
#if 0
      for (inx = 0; inx < qcr->qcr_fill; inx+= 2)
	{
	  int64 n = DCINT1 (qcr->qcr_result[inx]);
	  if (n == d_id)
	    goto found;
	  if (n > d_id)
	    {
	      if (0 == inx)
		goto next_set;
	      dc = qcr->qcr_result[inx - 2];
	      goto look_in_dc;
	    }
	  if (inx == qcr->qcr_fill)
	    {
	      dc = qcr->qcr_result[inx];
	      goto look_in_dc;
	    }
	}
      inx = qcr->qcr_fill - 2;
      dc = qcr->qcr_result[inx];
      if (d_id > ((int64*)dc->dc_values)[dc->dc_n_values - 1])
	goto next_set;
    look_in_dc:
      at_or_above = 0;
      below = dc->dc_n_values;
      for (;;)
	{
	  if (below - at_or_above <= 1)
	    {
	      n = ((int64*)dc->dc_values)[at_or_above];
	      if (n < d_id)
		goto next_set;

	      if (n == d_id)
		goto found;
	      goto next_set;
	    }
	  guess = (at_or_above + below) / 2;
	  n = ((int64*)dc->dc_values)[guess];
	  if (n == d_id)
	    goto found;
	  if (n > d_id)
	    below = guess;
	  else
	    at_or_above = guess;
	}
    found:
      qi->qi_set = set;
      if (txs->txs_score)
	qst_set_long (inst, txs->txs_score, ((int64*)qcr->qcr_result[inx+1]->dc_values)[at_or_above]);
      qn_result ((data_source_t*)txs, inst, set);
    next_set: ;
#endif

    }  qst_set (inst, txs->txs_qcr, NULL);
  if (QST_INT (inst, txs->src_gen.src_out_fill))
    qn_send_output ((data_source_t*)txs, inst);
}


int enable_qn_cache = 0;


void
txs_vec_input (text_node_t * txs, caddr_t * inst, caddr_t *state)
{
  QNCAST (query_instance_t, qi, inst);
  int n_sets = txs->src_gen.src_prev ? QST_INT (inst, txs->src_gen.src_prev->src_out_fill) : qi->qi_n_sets;
  int nth_set, first_time = 0, batch_sz;
  QNCAST (data_source_t, qn, txs);
  caddr_t err = NULL;
  if (enable_qn_cache)
    {
      if (state)
	{
	  qc_result_t * qcr;
	  txs_qc_lookup (txs, inst);
	  qcr = (qc_result_t*)QST_GET_V (inst, txs->txs_qcr);
	  if (qcr && QCR_READY == qcr->qcr_status)
	    {
	      if (txs->txs_is_driving)
		txs_from_qcr (txs, inst, state);
	      else
		txs_qcr_check (txs, inst);
	      return;
	    }
	}
      else
	{
	  qc_result_t * qcr = (qc_result_t*)QST_GET_V (inst, txs->txs_qcr);
	  if (qcr && QCR_READY == qcr->qcr_status)
	    {
	      txs_from_qcr (txs, inst, NULL);
	      return;
	    }
	}
    }


  if (state)
    nth_set = QST_INT (inst, txs->clb.clb_nth_set) = 0;
  else
    nth_set = QST_INT (inst, txs->clb.clb_nth_set);

again:
  batch_sz = QST_INT (inst, txs->src_gen.src_batch_size); /* May vary, receiver may increase the batch size to improve the locality */
  QST_INT (inst, qn->src_out_fill) = 0;
  dc_reset_array (inst, qn, qn->src_continue_reset, -1);
  for (; nth_set < n_sets; nth_set ++)
    {
      qi->qi_set = nth_set;
      for (;;)
	{
	  if (!state)
	    {
	      state = SRC_IN_STATE (qn, inst);
	    }
	  else
	    {
	      txs_init (txs, (query_instance_t *) state);
	      first_time = 1;
	    }
	  err = txs_next (txs, state, first_time); /* Should become vectored and produce up to batch_sz - qn->src_out_fill results at a single run */
	  first_time = 0;
	  if (err != SQL_SUCCESS)
	    {
	      SRC_IN_STATE (qn, inst) = NULL;
	      if (err != (caddr_t) SQL_NO_DATA_FOUND)
		sqlr_resignal (err);
	      break;
	    }
	  qn_result (qn, inst, nth_set);
	  if (!txs->txs_is_driving)
	    break;
	  SRC_IN_STATE (qn, inst) = state;
	  state = NULL;
	  if (QST_INT (inst, qn->src_out_fill) >= batch_sz)
	    {
	      QST_INT (inst, txs->clb.clb_nth_set) = nth_set;
	      if (txs->txs_is_driving && txs->txs_qcr)
		txs_qc_accumulate (txs, inst);
	      qn_send_output (qn, inst);
	      goto again;
	    }
	}
    }

  SRC_IN_STATE (qn, inst) = NULL;
  if (txs->txs_is_driving && txs->txs_qcr)
    txs_qc_accumulate (txs, inst);
  if (QST_INT (inst, qn->src_out_fill))
    qn_send_output (qn, inst);
}

#define EXT_FTI_LOG 0

caddr_t **
txs_ext_fti_get (query_instance_t * qi, slice_id_t slice, caddr_t ext_fti, caddr_t req)
{
  caddr_t call_uri = NULL;
  caddr_t err = NULL;
  caddr_t tree = NULL;
  xml_ns_2dict_t ns_2dict;
  dtd_t *dtd = NULL;
  id_hash_t *id_cache = NULL;
  xml_tree_ent_t *xte = NULL;
  static XT *response_test = NULL;
  static XT *result_test = NULL;
  static XT *doc_test = NULL;
  static XT *int_test = NULL;
  static XT *long_test = NULL;
  static XT *name_test = NULL;
  caddr_t **res = NULL;
  int res_len = 0;
  int res_ctr = 0;
  unsigned buflen;
  static char fti_params_template[] = "%s?wt=standard&sort=id%%20asc&start=0&rows=2147483647&fl=id&q=%s";
  caddr_t resp_text;
  if (!strcmp (ext_fti, "solr:local"))
    {
      caddr_t ext_fti_local = NULL;
      static caddr_t solr_url = 0;
      static caddr_t solr_url_sliced = 0;
      if (0 == solr_url && 0 == solr_url_sliced)
        {
          solr_url = registry_get ("solr_url");
          solr_url_sliced = registry_get ("solr_url_sliced");

          if (!solr_url && !solr_url_sliced)
            sqlr_new_error ("22023", "SOLR9", "Neither registry values \"solr_url\" or \"solr_url_sliced\" is set.");
        }
      if (QI_NO_SLICE == slice)
        {
          if (solr_url)
            ext_fti_local = solr_url;
          else
            sqlr_new_error ("22023", "SOLR9", "Registry value \"solr_url\" is not set.");
        }
      else
        {
          if (solr_url_sliced)
            ext_fti_local = box_sprintf (100, solr_url_sliced, slice);
          else if (solr_url)
            ext_fti_local = solr_url;
          else
            sqlr_new_error ("22023", "SOLR9", "Registry value \"solr_url_sliced\" is not set.");
        }
      buflen = box_length (ext_fti_local) + box_length (req) + sizeof(fti_params_template);
      call_uri = box_sprintf (buflen, fti_params_template, ext_fti_local, req);
      if (solr_url != ext_fti_local)
        dk_free_box (ext_fti_local);
    }
  else
    {
      buflen = box_length (ext_fti) + box_length (req) + sizeof(fti_params_template);
      call_uri = box_sprintf (buflen, fti_params_template, ext_fti, req);
    }

/* First we query the remote with HTTP */
  resp_text = bif_http_client_impl ((caddr_t *)qi, &err, NULL /* no need in args */, "HTTP call to an external free-text indexing server",
    call_uri, NULL /*uid*/, NULL /*pwd*/, NULL /*method*/, NULL /*http_hdr*/, NULL /*body*/,
    NULL /*cert*/, NULL /*pk_pass*/, 600000 /*time_out*/, 0 /*time_out_is_null*/, NULL /*proxy*/, NULL /*ca_certs*/, 0 /*insecure*/,
    0 /* ret_arg_index */,
    3);

#ifdef EXT_FTI_LOG
  {
  FILE *solr_log = fopen("solr_fti_log","a");
  dbg_print_box(call_uri,solr_log);
  fputs("\n",solr_log);
  dbg_print_box(resp_text,solr_log);
  fputs("\n",solr_log);
  fclose(solr_log);
  }
#endif

  if (NULL != err)
    goto handle_err; /* see below */;
/* Now we parse the returned XML */
  tree = xml_make_mod_tree (qi, resp_text, (caddr_t *) &err, 0 /*parser_mode*/, call_uri, "UTF-8", &lh__xany, NULL/*dtd_config*/, &dtd, &id_cache, &ns_2dict);
  if (NULL == tree)
    goto handle_err; /* see below */;
  xte = xte_from_tree (tree, qi);
  tree = NULL;
  xte->xe_doc.xd->xd_uri = call_uri;
  xte->xe_doc.xd->xd_dtd = dtd; /* The refcounter is incremented inside xml_make_tree */
  xte->xe_doc.xd->xd_id_dict = id_cache;
  xte->xe_doc.xd->xd_id_scan = XD_ID_SCAN_COMPLETED;
  xte->xe_doc.xd->xd_ns_2dict = ns_2dict;
  xte->xe_doc.xd->xd_namespaces_are_valid = 0;
  /* test only : xte_word_range(xte,&l1,&l2); */
/* And fetch values from it */
  if (NULL == response_test)
    {
      response_test = xp_make_name_test_from_qname (NULL /*xpp*/, box_dv_uname_string ("response"), 1);
      result_test = xp_make_name_test_from_qname (NULL /*xpp*/, box_dv_uname_string ("result"), 1);
      doc_test = xp_make_name_test_from_qname (NULL /*xpp*/, box_dv_uname_string ("doc"), 1);
      int_test = xp_make_name_test_from_qname (NULL /*xpp*/, box_dv_uname_string ("int"), 1);
      long_test = xp_make_name_test_from_qname (NULL /*xpp*/, box_dv_uname_string ("long"), 1);
      name_test = xp_make_name_test_from_qname (NULL /*xpp*/, box_dv_uname_string ("name"), 1);
    }
  if (XI_AT_END != xte->_->xe_first_child ((xml_entity_t *) xte, response_test))
    if (XI_AT_END != xte->_->xe_first_child ((xml_entity_t *) xte, result_test))
      {
        res_len = 3 + BOX_ELEMENTS (xte->xte_current);
        res = (caddr_t **) dk_alloc_list_zero (res_len);
        res_ctr = 3;
        if (XI_AT_END != xte->_->xe_first_child ((xml_entity_t *) xte, doc_test))
          {
            do {
                 if (XI_AT_END != xte->_->xe_first_child ((xml_entity_t *) xte, int_test))
                   {
                     if (2 == BOX_ELEMENTS (xte->xte_current) && (DV_STRING == DV_TYPE_OF (xte->xte_current[1])))
                       res[res_ctr++] = (caddr_t *) list (1, box_num (atoi (xte->xte_current[1])));
                   }
                 else if (XI_AT_END != xte->_->xe_first_child ((xml_entity_t *) xte, long_test))
                   {
                     if (2 == BOX_ELEMENTS (xte->xte_current) && (DV_STRING == DV_TYPE_OF (xte->xte_current[1])))
                       res[res_ctr++] = (caddr_t *) list (1, box_num (atoi (xte->xte_current[1])));
                   }
                 xte->_->xe_up ((xml_entity_t *) xte, (XT *) XP_NODE, 0);
              } while (XI_AT_END != xte->_->xe_next_sibling ((xml_entity_t *) xte, doc_test));
          }
        res[0] = box_num (res_ctr-1);
      }
  if (NULL == res)
    res = (caddr_t **) dk_alloc_list_zero (3);
  dk_free_tree (xte);
  dk_free_tree (tree);
  dk_free_tree (resp_text);
  return res;
#if 1
  return (caddr_t **)list (6, box_num (4), box_num (0), box_num (0),
    list (1, box_num (10)),
    list (1, box_num (11)),
    uname__bang_exclude_result_prefixes /* as sample of garbage */ );
#endif
handle_err:
  dk_free_tree (xte);
  dk_free_tree (tree);
  dk_free_tree (resp_text);
  sqlr_resignal (err);
  return NULL;
}

void
txs_ext_fti_init (text_node_t * txs, query_instance_t * qi)
{
  caddr_t * qst = (caddr_t*) qi;
  caddr_t err = NULL;
  caddr_t str = qst_get (qst, txs->txs_text_exp);
  caddr_t * old_tree, * tree;
  caddr_t dtd_config = NULL;
  caddr_t cached_string;
  int tree_is_temporary;
  sst_tctx_t context;
  caddr_t **results;
  wcharset_t *query_charset;
  encoding_handler_t *eh;
  slice_id_t slice;
  query_charset = QST_CHARSET(qi);
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
  tree_is_temporary = 0;
  err = NULL;
  cached_string = (caddr_t) qst_get (qst, txs->txs_cached_string);
  if (NULL != cached_string)                /* cache is nonempty */
    {
      if(strcmp(cached_string, str))
        {
          qst_set (qst, txs->txs_cached_string, NULL);
          qst_set (qst, txs->txs_cached_compiled_tree, NULL);
          qst_set (qst, txs->txs_cached_dtd_config, NULL);
          old_tree = NULL;
          goto parse_new_tree;
        }
      else
        {
          old_tree = tree = (caddr_t *)qst_get (qst, txs->txs_cached_compiled_tree);
          goto skip_parsing_of_new_tree;
        }
    }
  else                                        /* cache is empty */
    {
      old_tree = NULL;
      goto parse_new_tree;
    }
parse_new_tree:
  tree = box_copy_tree (str);
  if (NULL != err)
    {
      dk_free_tree ((caddr_t)tree);
      dk_free_tree (dtd_config);
      sqlr_resignal (err);
    }
  /*xpt_edit_range_flags (tree, ~SRC_RANGE_DUMMY, SRC_RANGE_MAIN);*/
  qst_set (qst, txs->txs_cached_dtd_config, dtd_config);
skip_parsing_of_new_tree:
  qst_set (qst, txs->txs_cached_string, box_dv_short_string(str));
  if (tree != old_tree)
    qst_set (qst, txs->txs_cached_compiled_tree, (caddr_t) tree);
  context.tctx_vtb = NULL;
  context.tctx_descending = (txs->txs_desc ? (int) unbox (qst_get (qst, txs->txs_desc)) : 0);
  context.tctx_end_id = (txs->txs_end_id ? qst_get (qst, txs->txs_end_id) : NULL);
  if (txs->txs_offband)
    sqlr_new_error ("22023", "FT100", "Offband with EXT_FTI");
  context.tctx_qi = qi;
  context.tctx_table = txs->txs_table;
  context.tctx_calc_score = ((NULL != txs->txs_score) ? 1 : 0);
  context.tctx_range_flags = SRC_RANGE_DUMMY;
  slice = qi->qi_client->cli_slice;
  results = txs_ext_fti_get (qi, slice, qst_get (qst, txs->txs_ext_fti), (caddr_t)tree);
  if (tree_is_temporary)
    dk_free_tree ((caddr_t)tree);
  if (txs->txs_is_driving)
    qst_set_long (qst, txs->txs_d_id, 0);
  qst_set (qst, txs->txs_sst, (caddr_t)results);
}

boxint
txs_ext_fti_next_result (caddr_t **results, boxint *target, int is_fixed)
{
  boxint len = unbox ((caddr_t)(results[0]));
  boxint ctr = unbox ((caddr_t)(results[1])) + 3;
  while (ctr <= len)
    {
      boxint curr_id = unbox ((caddr_t)(results[ctr][0]));
      if (curr_id < target[0])
        {
          ctr++;
          continue;
        }
      if (is_fixed && (curr_id > target[0]))
        goto notfound;
      ctr++;
      dk_free_box (results[2]);
      results[2] = box_num (curr_id);
      dk_free_box (results[1]);
      results[1] = box_num (ctr - 3);
      return curr_id;
    }
notfound:
  dk_free_box (results[1]);
  results[1] = box_num (ctr - 3);
  return -1;
}


caddr_t
txs_ext_fti_next (text_node_t * txs, caddr_t * qst, int first_time)
{
  caddr_t **results = (caddr_t **) qst_get (qst, txs->txs_sst);
  boxint d_id;
#if 0
  int score_limit = txs->txs_score_limit ? (int) unbox (qst_get (qst, txs->txs_score_limit)) : 0;
#endif
  d_id = unbox (qst_get (qst, txs->txs_d_id));
  if (!txs->txs_is_driving)
    {
      if (d_id < 0)
	return ((caddr_t) SQL_NO_DATA_FOUND);
      if (0 > txs_ext_fti_next_result (results, &d_id, 1))
	return ((caddr_t) SQL_NO_DATA_FOUND);
#if 0 /*!!! tbd later */
      if (score_limit || txs->txs_score)
	sst_scores (sst, &d_id);
      if (txs->txs_score)
	TXS_QST_SET (txs, qst, txs->txs_score, box_num (sst->sst_score));
      if (score_limit && sst->sst_score < score_limit)
	return ((caddr_t) SQL_NO_DATA_FOUND);
      txs_set_ranges (txs, qst, sst);
#endif
      return ((caddr_t) SQL_SUCCESS);

    }
  for (;;)
    {
      if (first_time)
	{
	  if (txs->txs_init_id)
	    d_id = unbox (qst_get (qst, txs->txs_init_id));
  else
	    d_id = 0;
	}
      d_id = txs_ext_fti_next_result (results, &d_id, 0);
      first_time = 0;
      if (d_id < 0)
	return ((caddr_t) SQL_NO_DATA_FOUND);
#if 0 /*!!! tbd later */
      if (score_limit || txs->txs_score)
	sst_scores (sst, &d_id);
      if (score_limit && sst->sst_score < score_limit)
	continue;
#endif
      break;
    }
#if 0 /*!!! tbd later */
  if (txs->txs_score)
    TXS_QST_SET (txs, qst, txs->txs_score, box_num (sst->sst_score));
#endif
  if (txs->txs_is_rdf)
    sqlr_new_error ("22023", "FT101", "RDF with EXT_FTI");
  TXS_QST_SET (txs, qst, txs->txs_d_id, box_num (d_id));
#if 0 /*!!! tbd later */
  txs_set_offband (txs, qst);
  txs_set_ranges (txs, qst, sst);
#endif
  return ((caddr_t) SQL_SUCCESS);
}


/* That's an exact clone of txs_vec_input */
void
txs_ext_fti_vec_input (text_node_t * txs, caddr_t * inst, caddr_t *state)
{
  QNCAST (query_instance_t, qi, inst);
  int n_sets = txs->src_gen.src_prev ? QST_INT (inst, txs->src_gen.src_prev->src_out_fill) : qi->qi_n_sets;
  int nth_set, first_time = 0, batch_sz;
  QNCAST (data_source_t, qn, txs);
  caddr_t err = NULL;
  if (enable_qn_cache)
    {
      if (state)
	{
	  qc_result_t * qcr;
	  txs_qc_lookup (txs, inst);
	  qcr = (qc_result_t*)QST_GET_V (inst, txs->txs_qcr);
	  if (qcr && QCR_READY == qcr->qcr_status)
	    {
	      if (txs->txs_is_driving)
		txs_from_qcr (txs, inst, state);
	      else
		txs_qcr_check (txs, inst);
	      return;
	    }
	}
      else
	{
	  qc_result_t * qcr = (qc_result_t*)QST_GET_V (inst, txs->txs_qcr);
	  if (qcr && QCR_READY == qcr->qcr_status)
	    {
	      txs_from_qcr (txs, inst, NULL);
	      return;
	    }
	}
    }
  if (state)
    nth_set = QST_INT (inst, txs->clb.clb_nth_set) = 0;
  else
    nth_set = QST_INT (inst, txs->clb.clb_nth_set);

again:
  batch_sz = QST_INT (inst, txs->src_gen.src_batch_size); /* May vary, receiver may increase the batch size to improve the locality */
  QST_INT (inst, qn->src_out_fill) = 0;
  dc_reset_array (inst, qn, qn->src_continue_reset, -1);
  for (; nth_set < n_sets; nth_set ++)
    {
      qi->qi_set = nth_set;
      for (;;)
	{
	  if (!state)
	    {
	      state = SRC_IN_STATE (qn, inst);
	    }
	  else
	    {
	      txs_ext_fti_init (txs, (query_instance_t *) state);
	      if (txs->txs_is_driving)
	      dc_reset (QST_BOX (data_col_t *, inst, txs->txs_d_id->ssl_index));
	      first_time = 1;
	    }
	  err = txs_ext_fti_next (txs, state, first_time); /* Should become vectored and produce up to batch_sz - qn->src_out_fill results at a single run */
	  first_time = 0;
	  if (err != SQL_SUCCESS)
	    {
	      SRC_IN_STATE (qn, inst) = NULL;
	      if (err != (caddr_t) SQL_NO_DATA_FOUND)
		sqlr_resignal (err);
	      break;
	    }
	  qn_result (qn, inst, nth_set);
	  if (!txs->txs_is_driving)
	    break;
	  SRC_IN_STATE (qn, inst) = state;
	  state = NULL;
	  if (QST_INT (inst, qn->src_out_fill) >= batch_sz)
	    {
	      QST_INT (inst, txs->clb.clb_nth_set) = nth_set;
              if (txs->txs_is_driving && txs->txs_qcr)
                txs_qc_accumulate (txs, inst);
	      qn_send_output (qn, inst);
	      goto again;
	    }
	}
    }

  SRC_IN_STATE (qn, inst) = NULL;
  if (txs->txs_is_driving && txs->txs_qcr)
    txs_qc_accumulate (txs, inst);
  if (QST_INT (inst, qn->src_out_fill))
    qn_send_output (qn, inst);
}


/* That's an exact clone of loop in txn_input */
void
txs_ext_fti_input (text_node_t * txs, caddr_t * inst, caddr_t *state)
{
  int first_time = 0;
  for (;;)
    {
      caddr_t err;
      if (!state)
	{
	  state = qn_get_in_state ((data_source_t *) txs, inst);
	}
      else
	{
	  txs_ext_fti_init (txs, (query_instance_t *) state);
	  first_time = 1;
	}
      err = txs_ext_fti_next (txs, state, first_time);
      first_time = 0;
      if (err == SQL_SUCCESS)
	{
	  if (txs->txs_is_driving)
	    qn_record_in_state ((data_source_t *) txs, inst, state);
	  if (!txs->src_gen.src_after_test
	      || code_vec_run (txs->src_gen.src_after_test, inst))
	    {
	      qn_send_output ((data_source_t *) txs, inst);
	    }
	  if (!txs->txs_is_driving)
	    {
	      qn_record_in_state ((data_source_t *) txs, inst, NULL);
	      return;
	    }
	}
      else
	{
	  qn_record_in_state ((data_source_t *) txs, inst, NULL);
	  if (err != (caddr_t) SQL_NO_DATA_FOUND)
	    sqlr_resignal (err);
	  return;
	}
      state = NULL;
    }
}


void
txs_input (text_node_t * txs, caddr_t * inst, caddr_t *state)
{
  caddr_t err;
  int first_time = 0;
  if (txs->txs_geo)
    {
      geo_node_input (txs, inst, state);
      return;
    }
  if (txs->txs_ext_fti)
    {
      if (txs->src_gen.src_sets)
        txs_ext_fti_vec_input (txs, inst, state);
      else
        txs_ext_fti_input (txs, inst, state);
      return;
    }
  if (txs->src_gen.src_sets)
    {
      txs_vec_input (txs, inst, state);
      return;
    }
  for (;;)
    {
      if (!state)
	{
	  state = qn_get_in_state ((data_source_t *) txs, inst);
	}
      else
	{
	  txs_init (txs, (query_instance_t *) state);
	  first_time = 1;
	}
      err = txs_next (txs, state, first_time);
      first_time = 0;
      if (err == SQL_SUCCESS)
	{
	  if (txs->txs_is_driving)
	    qn_record_in_state ((data_source_t *) txs, inst, state);

	  if (!txs->src_gen.src_after_test
	      || code_vec_run (txs->src_gen.src_after_test, inst))
	    {
	      qn_send_output ((data_source_t *) txs, inst);
	    }
	  if (!txs->txs_is_driving)
	    {
	      qn_record_in_state ((data_source_t *) txs, inst, NULL);
	      return;
	    }
	}
      else
	{
	  qn_record_in_state ((data_source_t *) txs, inst, NULL);
	  if (err != (caddr_t) SQL_NO_DATA_FOUND)
	    sqlr_resignal (err);
	  return;
	}
      state = NULL;
    }
}


void
txs_free (text_node_t * txs)
{
}

caddr_t
bif_int_log2x16 (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* given a cursor on a copy of vt_words, get the next chunk's d_id */
  ptrlong src = bif_long_arg (qst, args, 0, "int_log2x16");
  ptrlong res = 0;
  if (src <= 0)
    return box_double (log10 (-1)); /* system-dependent NAN */
  while (src >= 0x100)
    {
      src >>= 2;
      res += 32;
    }
  return (caddr_t)(res + int_log2x16[src]); /* It's surely very small, less than 256 and positive */
}

caddr_t
bif_vt_hit_dist_weight (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* given a cursor on a copy of vt_words, get the next chunk's d_id */
  ptrlong src = bif_long_arg (qst, args, 0, "vt_hit_dist_weight");
  src += 0x80;
  return (caddr_t)(ptrlong)((src & ~0xFF) ? 1 : vt_hit_dist_weight[src]); /* It's surely very small, less than 256 and positive */
}

void
text_init (void)
{
  int x;
  for (x = 1; x < 0x100; x++)
    int_log2x16[x] = (unsigned char)(floor (16 * log (x) / log (2)));
  for (x = -0x80; x < 0x80; x++)
    vt_hit_dist_weight[x + 0x80] = (unsigned char)(1 + floor ((VT_ZERO_DIST_WEIGHT-1) / (1 + (1.0 / (VT_HALF_FADE_DIST*VT_HALF_FADE_DIST)) * x * x)));
  wst_get_specs_mtx = mutex_allocate ();
  bif_define ("vt_words_next_d_id", bif_vt_words_next_d_id );
  bif_define ("vt_batch_match", bif_vtb_match);
  bif_define ("vt_parse", bif_vt_parse);
  bif_define ("int_log2x16", bif_int_log2x16);
  bif_define ("vt_hit_dist_weight", bif_vt_hit_dist_weight);
  dk_mem_hooks(DV_TEXT_SEARCH, box_non_copiable, (box_destr_f) sst_destroy, 0);
  txs_qcr_rev_mtx = mutex_allocate ();
  qc_init ();
}

