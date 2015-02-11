/*
 *  colins.c
 *
 *  $Id$
 *
 *  Column insert
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


#include "sqlnode.h"
#include "arith.h"
#include "log.h"



int dbf_compress_mask = 0
/*
  | CS_NO_BITS
  | CS_NO_RLD
  | CS_NO_DICT
  | CS_NO_RL
  | CS_NO_DELTA
  | CS_NO_ANY_INT_VEC
*/
    ;


int ce_last_insert_margin = 100;


int
ce_list_n_values (dk_set_t l)
{
  int n = 0;
  DO_SET (db_buf_t, ce, &l) n += ce_n_values (ce);
  END_DO_SET ();
  return n;
}


int dbf_asc_check;
void
buf_asc_ck (buffer_desc_t * buf)
{
#if 1
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  int inx;
  mem_pool_t *mp;
  col_pos_t cpo;
  data_col_t dc;
  page_map_t *pm = buf->bd_content_map;
  int n_values = pm_n_rows (pm, 0);
  if (!dbf_asc_check)
    return;
  mp = mem_pool_alloc ();
  memset (&cpo, 0, sizeof (cpo));
  memset (&dc, 0, sizeof (data_col_t));
  ITC_INIT (itc, NULL, NULL);
  itc->itc_n_matches = 0;
  cpo.cpo_itc = itc;
  cpo.cpo_string = buf->bd_buffer + DP_DATA;
  cpo.cpo_bytes = pm->pm_filled_to - DP_DATA;
  dc.dc_type = DCT_BOXES | DCT_FROM_POOL;
  dc.dc_mp = mp;
  dc.dc_n_places = n_values;
  dc.dc_values = (db_buf_t) mp_alloc (mp, sizeof (caddr_t) * n_values);
  cpo.cpo_dc = &dc;
  cpo.cpo_value_cb = ce_result;
  cpo.cpo_ce_op = NULL;
  cpo.cpo_pm = NULL;
  cs_decode (&cpo, 0, n_values);
  for (inx = 1; inx < n_values; inx++)
    {
      if (DVC_GREATER == cmp_boxes_safe (((caddr_t *) dc.dc_values)[inx - 1], ((caddr_t *) dc.dc_values)[inx], NULL, NULL))
	{
	  printf ("outawak %d\n", inx);
	  break;
	}
    }
  mp_free (mp);
#endif
}


int enable_ce_ins_check = 0;
int enable_cr_trace;
void
itc_ce_check (it_cursor_t * itc, buffer_desc_t * buf, int leave)
{
  int ce_len[COL_PAGE_MAX_ROWS];
  int old = itc->itc_map_pos;
  page_map_t *pm = buf->bd_content_map;
  col_data_ref_t **old_cr = NULL;
  int nth_col, is_error = 0;
  db_buf_t old_r = itc->itc_row_data;
  dbe_key_t *key = itc->itc_insert_key;
#ifdef PAGE_DEBUG
  int prev_ck_ts = buf->bd_ck_ts;
#endif
  if (!enable_ce_ins_check)
    return;
  if (leave)
    {
      old_cr = itc->itc_col_refs;
      itc->itc_col_refs = (col_data_ref_t **) itc_alloc_box (itc, itc->itc_insert_key->key_n_parts * sizeof (caddr_t), DV_BIN);
      memset (itc->itc_col_refs, 0, box_length (itc->itc_col_refs));
    }
  if (pm->pm_count > COL_PAGE_MAX_ROWS)
    GPF_T1 ("can't have more  than so many segs per leaf page");
  for (nth_col = 0; nth_col < key->key_n_parts - key->key_n_significant; nth_col++)
    {
      int r;
      int expect_dp = 0;
      int expect_ce = -1;
      col_data_ref_t *cr = itc->itc_col_refs[nth_col];
      if (!cr)
	cr = itc->itc_col_refs[nth_col] = itc_new_cr (itc);
      for (r = 0; r < pm->pm_count; r++)
	{
	  int n_in_cr;
	  db_buf_t row = BUF_ROW (buf, r);
	  if (KV_LEFT_DUMMY == IE_KEY_VERSION (row) || KV_LEAF_PTR == IE_KEY_VERSION (row))
	    continue;
	  itc->itc_map_pos = r;
	  if (0 && 42 == r)
	    {
	      caddr_t *box = itc_box_col_seg (itc, buf, &key->key_row_var[nth_col]);
	      dk_free_tree ((caddr_t) box);
	    }
	  itc_fetch_col (itc, buf, &key->key_row_var[nth_col], COL_NO_ROW, COL_NO_ROW);
	  n_in_cr = cr_n_rows (cr);
	  if (0 == nth_col)
	    ce_len[r] = n_in_cr;
	  else
	    {
	      if (ce_len[r] != n_in_cr)
		{
		  log_error ("seg of %s dp %d row %d col %d bad len %d, 1st is %d", key->key_name, buf->bd_page, r, nth_col,
		      ce_len[r], n_in_cr);
		  is_error = 1;
		}
	    }
	  if (expect_dp)
	    {
	      if (cr->cr_pages[0].cp_buf->bd_page != expect_dp)
		{
		log_error ("col does not start at expected dp %d K %s C %d", expect_dp, key->key_name, nth_col);
		  is_error = 1;
		}
	      if (cr->cr_first_ce != expect_ce)
		{
		log_error ("col seg does not start at expected ce %d K %s C %d", expect_ce, key->key_name, nth_col);
		  is_error = 1;
		}
	    }
	  else
	    {
	      if (cr->cr_first_ce)
		{
		log_error ("seg is expected to start at ce 0 K %s C %d", key->key_name, nth_col);
		  is_error = 1;
		}
	    }
	  if (cr->cr_limit_ce && cr->cr_limit_ce < cr->cr_pages[cr->cr_n_pages - 1].cp_map->pm_count)
	    {
	      expect_dp = cr->cr_pages[cr->cr_n_pages - 1].cp_buf->bd_page;
	      expect_ce = cr->cr_limit_ce / 2;
	    }
	  else
	    expect_dp = 0;
	  itc_col_leave (itc, 0);
	}

    }
  itc->itc_map_pos = old;
  itc->itc_row_data = old_r;
  if (is_error && 2 == enable_ce_ins_check)
    {
      FILE *fp = fopen ("recovery.txt", "a");
      fprintf (fp, "\nSee error messages in messages log.  Ce structure broken on below page\n");
      dbg_page_map_f (buf, fp);
      fclose (fp);
      if (!wi_inst.wi_checkpoint_atomic)
	GPF_T1 ("ce structure bad");
    }
  if (leave)
    {
      int inx;
      itc_col_leave (itc, 0);
      DO_BOX (col_data_ref_t *, cr, inx, itc->itc_col_refs)
      {
	if (!cr)
	  continue;
	if (cr->cr_pages != &cr->cr_pre_pages[0])
	  itc_free_box (itc, cr->cr_pages);
	itc_free_box (itc, cr);
      }
      END_DO_BOX;
      itc_free_box (itc, itc->itc_col_refs);
      itc->itc_col_refs = old_cr;
    }
#ifdef COL_CK_TS
  buf->bd_ck_ts = leave ? buf->bd_timestamp : -buf->bd_timestamp;
#endif
}


void
buf_ce_check (buffer_desc_t * buf)
{
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  ITC_INIT (itc, NULL, NULL);
  itc_from_it (itc, buf->bd_tree);
  itc_ce_check (itc, buf, 1);
}


void
key_col_check (dbe_key_t * key)
{
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  dk_hash_t *dps_in = hash_table_allocate (1100);
  int inx;
  cluster_map_t *clm = key->key_partition->kpd_map;
  ITC_INIT (itc, NULL, NULL);
  itc->itc_insert_key = key;
  itc_col_init (itc);
  DO_LOCAL_CSL (csl, clm)
  {
    index_tree_t *it = key->key_fragments[csl->csl_id]->kf_it;
    itc_from_it (itc, it);
    for (inx = 0; inx < IT_N_MAPS; inx++)
      {
	it_map_t *itm = &it->it_maps[inx];
	dk_hash_iterator_t hit;
	ptrlong dp;
	buffer_desc_t *buf;
	mutex_enter (&itm->itm_mtx);
	dk_hash_iterator (&hit, &itm->itm_dp_to_buf);
	while (dk_hit_next (&hit, (void **) &dp, (void **) &buf))
	  {
	    if (!buf->bd_buffer)
	      continue;		/* this is a decoy holding a place while real buffer being read */
	    if (DPF_INDEX == SHORT_REF (buf->bd_buffer + DP_FLAGS))
	      sethash ((void *) (ptrlong) buf->bd_page, dps_in, (void *) 1);
	  }
	mutex_leave (&itm->itm_mtx);
	DO_HT (ptrlong, dp, ptrlong, ign, dps_in)
	{
	  buffer_desc_t *buf;
	  ITC_IN_KNOWN_MAP (itc, dp);
	  page_wait_access (itc, dp, NULL, &buf, PA_READ, RWG_WAIT_ANY);
	  ITC_LEAVE_MAPS (itc);
	  itc_ce_check (itc, buf, 1);
	  page_leave_outside_map (buf);
	}
	END_DO_HT;
	clrhash (dps_in);
      }
  }
  END_DO_LOCAL_CSL;
  hash_table_free (dps_in);
}



void
itc_fetch_col_dps (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, dk_hash_t * dps)
{
  dbe_key_t *key = itc->itc_insert_key;
  unsigned short vl1, vl2, offset;
  int n_pages, inx;
  db_buf_t xx, xx2;
  db_buf_t row = NULL;
  col_data_ref_t *cr = itc->itc_col_refs[cl->cl_nth - key->key_n_significant];
  dtp_t dtp;

  cr->cr_n_pages = 0;
  row = BUF_ROW (buf, itc->itc_map_pos);
  ROW_STR_COL (buf->bd_tree->it_key->key_versions[IE_KEY_VERSION (row)], buf, row, cl, xx, vl1, xx2, vl2, offset);
  if (vl2)
    GPF_T1 ("col ref string should nott be compressed");
  dtp = *xx;
  if (DV_STRING == dtp)
    GPF_T1 ("ces inlined on leaf page are not supported");
  n_pages = (vl1 - CPP_DP) / sizeof (dp_addr_t);
  for (inx = 0; inx < n_pages; inx++)
    {
      dp_addr_t dp = LONG_REF_NA ((xx + CPP_DP) + sizeof (dp_addr_t) * inx);
      sethash (DP_ADDR2VOID (dp), dps, (void *) 1);
    }
}


void
itc_col_page_free (it_cursor_t * itc, buffer_desc_t * buf, int col)
{
  int first_col, last_col;
  int old = itc->itc_map_pos;
  dk_hash_t *dps = hash_table_allocate (1001);
  page_map_t *pm = buf->bd_content_map;
  int nth_col;
  db_buf_t old_r = itc->itc_row_data;
  dbe_key_t *page_key = itc->itc_insert_key;
  dbe_key_t *row_key = NULL;
  if (pm->pm_count > COL_PAGE_MAX_ROWS)
    GPF_T1 ("can't have more  than so many segs per leaf page");
  if (-1 == col)
    {
      first_col = 0;
      last_col = page_key->key_n_parts - page_key->key_n_significant;
    }
  else
    {
      first_col = col;
      last_col = col + 1;
    }
  if (!itc->itc_col_refs || BOX_ELEMENTS (itc->itc_col_refs) < last_col)
    {
      int sz = BOX_ELEMENTS (itc->itc_col_refs);
      itc_extend_array (itc, &sz, sizeof (caddr_t), (void ***) &itc->itc_col_refs);
    }
  for (nth_col = first_col; nth_col < last_col; nth_col++)
    {
      int r;
      col_data_ref_t *cr = itc->itc_col_refs[nth_col];
      if (!cr)
	cr = itc->itc_col_refs[nth_col] = itc_new_cr (itc);
      for (r = 0; r < pm->pm_count; r++)
	{
	  db_buf_t row = BUF_ROW (buf, r);
	  key_ver_t kv = IE_KEY_VERSION (row);
	  if (KV_LEFT_DUMMY == kv || KV_LEAF_PTR == IE_KEY_VERSION (row))
	    continue;
	  row_key = page_key->key_versions[kv];
	  if (!row_key)
	    continue;
	  itc->itc_map_pos = r;
	  if (IS_BLOB_DTP (row_key->key_row_var[nth_col].cl_sqt.sqt_col_dtp))
	    {
	      caddr_t *box = itc_box_col_seg (itc, buf, &row_key->key_row_var[nth_col]);
	      itc_delete_blob_array (itc, box, BOX_ELEMENTS (box));
	      dk_free_tree ((caddr_t) box);
	    }
	  itc_fetch_col_dps (itc, buf, &row_key->key_row_var[nth_col], dps);
	}
      DO_HT (ptrlong, dp, ptrlong, ign, dps)
      {
	ITC_IN_KNOWN_MAP (itc, dp);
	it_free_dp_no_read (itc->itc_tree, dp, DPF_COLUMN, row_key->key_row_var[nth_col].cl_col_id);
	ITC_LEAVE_MAPS (itc);
      }
      END_DO_HT;
      clrhash (dps);
    }
  hash_table_free (dps);
  itc->itc_map_pos = old;
  itc->itc_row_data = old_r;
}


void
itc_asc_ck (it_cursor_t * itc)
{
  col_data_ref_t *cr = itc->itc_col_refs[0];
  int inx;
  if (cr)
    {
  for (inx = 0; inx < cr->cr_n_pages; inx++)
	if (cr->cr_pages[inx].cp_buf)
    buf_asc_ck (cr->cr_pages[inx].cp_buf);
}
}


int col_ins_error;
int enable_pogs_check;


int
cmp_boxes_inx (caddr_t b1, caddr_t b2)
{
  /* no epsilon in inx order cmp */
  dtp_t dtp1 = DV_TYPE_OF (b1);
  dtp_t dtp2 = DV_TYPE_OF (b2);
  if (DV_RDF == dtp1 || DV_RDF == dtp2)
    {
      caddr_t err = NULL;
      caddr_t a1 = box_to_any (b1, &err);
      caddr_t a2 = box_to_any (b2, &err);
      int rc = dv_compare ((db_buf_t) a1, (db_buf_t) a2, NULL, 0);
      dk_free_box (a1);
      dk_free_box (a2);
      return rc;
    }
  if (dtp1 == dtp2)
    {
      if (DV_SINGLE_FLOAT == dtp1)
	return NUM_COMPARE (*(float *) b1, *(float *) b2);
      if (DV_DOUBLE_FLOAT == dtp1)
	return NUM_COMPARE (*(double *) b1, *(double *) b2);
    }
  return cmp_boxes (b1, b2, NULL, NULL);
}


extern int key_seg_check[10];

int
key_is_seg_check (int id)
{
  int inx;
  for (inx = 0; key_seg_check[inx]; inx++)
    if (id == key_seg_check[inx])
      return 1;
  return 0;
}



void
itc_pogs_seg_check (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* take a seg of pogs and the planned inserts and check that the result would be in order */
  dbe_key_t *key = itc->itc_insert_key;
  caddr_t *p = itc_box_col_seg (itc, buf, &key->key_row_var[0]);
  caddr_t *o = itc_box_col_seg (itc, buf, &key->key_row_var[1]);
  caddr_t *s = itc_box_col_seg (itc, buf, &key->key_row_var[2]);
  caddr_t *g = itc_box_col_seg (itc, buf, &key->key_row_var[3]);
  int n_rows = BOX_ELEMENTS (p);
  iri_id_t p1, g1, s1;
  iri_id_t p_prev, g_prev, s_prev;
  db_buf_t o1, o_prev;
  int is_first = 1, o_cmp;
  mem_pool_t *mp = mem_pool_alloc ();
  int first_set = itc->itc_set;
  int set = 0, row = 0;

  while (row < n_rows || set < itc->itc_range_fill)
    {
      if (set < itc->itc_range_fill && row == itc->itc_ranges[set].r_first)
	{
	  p1 = (long) itcp (itc, 0, set + first_set);
	  o1 = (db_buf_t) mp_box_deserialize_string (mp, (caddr_t) itcp (itc, 1, set + first_set), INT32_MAX, 0);
	  s1 = (long) itcp (itc, 2, set + first_set);
	  g1 = (long) itcp (itc, 3, set + first_set);
	  set++;
	}
      else if (row < n_rows)
	{
	  p1 = unbox_iri_id (p[row]);
	  o1 = (db_buf_t) o[row];
	  s1 = unbox_iri_id (s[row]);
	  g1 = unbox_iri_id (g[row]);
	  row++;
	}
      if (!is_first)
	{
	  if (p_prev > p1)
	    goto oow;
	  o_cmp = cmp_boxes_inx ((caddr_t) o_prev, (caddr_t) o1);
	  if (p1 == p_prev && DVC_GREATER == o_cmp)
	    goto oow;
	  if (p1 == p_prev && DVC_MATCH == o_cmp && s1 < s_prev)
	    goto oow;
	  if (p1 == p_prev && DVC_MATCH == o_cmp && s1 == s_prev && g1 <= g_prev)
	    goto oow;
	}
      is_first = 0;
      p_prev = p1;
      o_prev = o1;
      g_prev = g1;
      s_prev = s1;
    }
  dk_free_tree ((caddr_t) p);
  dk_free_tree ((caddr_t) o);
  dk_free_tree ((caddr_t) g);
  dk_free_tree ((caddr_t) s);
  mp_free (mp);
  return;
oow:
  col_ins_error = 1;
}


void
itc_gs_seg_check (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* take a seg of gs and the planned inserts and check that the result would be in order */
  dbe_key_t *key = itc->itc_insert_key;
  caddr_t *g = itc_box_col_seg (itc, buf, &key->key_row_var[0]);
  caddr_t *s = itc_box_col_seg (itc, buf, &key->key_row_var[1]);
  int n_rows = BOX_ELEMENTS (s);
  iri_id_t g1, s1;
  iri_id_t g_prev, s_prev;
  int is_first = 1;
  mem_pool_t *mp = mem_pool_alloc ();
  int first_set = itc->itc_set;
  int set = 0, row = 0;

  while (row < n_rows || set < itc->itc_range_fill)
    {
      if (set < itc->itc_range_fill && row == itc->itc_ranges[set].r_first)
	{
	  s1 = (long) itcp (itc, 1, set + first_set);
	  g1 = (long) itcp (itc, 0, set + first_set);
	  set++;
	}
      else if (row < n_rows)
	{
	  s1 = unbox_iri_id (s[row]);
	  g1 = unbox_iri_id (g[row]);
	  row++;
	}
      if (!is_first)
	{
	  if (g1 < g_prev)
	    goto oow;
	  if (g1 == g_prev && s1 < s_prev)
	    goto oow;
	}
      is_first = 0;
      g_prev = g1;
      s_prev = s1;
    }
  dk_free_tree ((caddr_t) g);
  dk_free_tree ((caddr_t) s);
  mp_free (mp);
  return;
oow:
  col_ins_error = 1;
}

void
itc_revword_seg_check (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* take a seg of str2 and the planned inserts and check that the result would be in order */
  dbe_key_t *key = itc->itc_insert_key;
  caddr_t *rev = itc_box_col_seg (itc, buf, &key->key_row_var[0]);
  caddr_t *word = itc_box_col_seg (itc, buf, &key->key_row_var[1]);
  int n_rows = BOX_ELEMENTS (rev);
  db_buf_t word_prev, word_1;
  db_buf_t rev_1, rev_prev;
  int is_first = 1, str2_cmp, word_cmp;
  mem_pool_t *mp = mem_pool_alloc ();
  int first_set = itc->itc_set;
  int set = 0, row = 0;

  while (row < n_rows || set < itc->itc_range_fill)
    {
      if (set < itc->itc_range_fill && row == itc->itc_ranges[set].r_first)
	{
	  word_1 = (db_buf_t) mp_box_deserialize_string (mp, (caddr_t) itcp (itc, 1, set + first_set), INT32_MAX, 0);
	  rev_1 = (db_buf_t) mp_box_deserialize_string (mp, (caddr_t) itcp (itc, 0, set + first_set), INT32_MAX, 0);
	  set++;
	}
      else if (row < n_rows)
	{
	  word_1 = (db_buf_t) word[row];
	  rev_1 = (db_buf_t) rev[row];
	  row++;
	}
      if (!is_first)
	{
	  str2_cmp = cmp_boxes ((caddr_t) rev_prev, (caddr_t) rev_1, NULL, NULL);
	  if (DVC_GREATER == str2_cmp)
	    goto oow;
	  if (DVC_MATCH == str2_cmp)
	    {
	      word_cmp = cmp_boxes ((caddr_t) word_prev, (caddr_t) word_1, NULL, NULL);
	      if (DVC_LESS != word_cmp)
		goto oow;
	    }
	}
      is_first = 0;
      rev_prev = rev_1;
      word_prev = word_1;
    }
  dk_free_tree ((caddr_t) word);
  dk_free_tree ((caddr_t) rev);
  mp_free (mp);
  return;
oow:
  col_ins_error = 1;
}

int rq_check_ctr = 0;
int rq_check_mod = 1;
int rq_check_min = 0;
int dbf_rq_check = 0;
int dbf_rq_key = 0;
int rq_batch_sz = 10000;
int rq_range_check_min = 0;
int dbf_ins_no_distincts;
extern int dbf_rq_slice_only;
extern client_connection_t *rfwd_cli;

//#define RQ_CHECK_TEXT "select count (*) from rdf_quad a table option (index rdf_quad) where not exists (select 1 from rq_rows b table option (loop) where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s)"
//#define RQ_CHECK_TEXT "select count (*)  from rdf_quad a table option (index rdf_quad_op, index_only, no cluster) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_op, index_only, no cluster) where  a.p = b.p and a.o = b.o )"
//#define RQ_CHECK_TEXT "select count (*) from rdf_quad a table option (loop, index rdf_quad_pogs, no cluster) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_pogs, no cluster)  where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s)"
//#define RQ_CHECK_TEXT "select count (*)  from rdf_quad a table option (index rdf_quad_gs, index_only, no cluster) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_gs, index_only, no cluster) where  a.g = b.g and a.s = b.s )"
//#define RQ_CHECK_TEXT "select 0, count (s), count (p), count (o), count (g) from rdf_quad table option (index rdf_quad) where p =  #i292339462 and s > #ib390000000"

#define RQ_RANGE_CHECK_TEXT_1 "select count (*) from rdf_quad a table option (loop, index rdf_quad_pogs, no cluster) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_pogs, no cluster)  where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s) and p = ? and o >= ? and o <= ?"
#define RQ_RANGE_CHECK_TEXT_2 "select count (*) from rdf_quad a table option (loop, index rdf_quad_pogs, no cluster) where not exists (select 1 from rdf_quad b table option (loop, index rdf_quad_pogs, no cluster)  where a.g = b.g and a.p = b.p and a.o = b.o and a.s = b.s) and p >= ? and p <= ?"

//#define RQ_CHECK_TEXT "select count (*) from t1 a table option (index str2) where not exists (select 1 from t1 b table option (loop, index str2) where b.string2 = a.string2 and b.row_no = a.row_no)"
#define RQ_CHECK_TEXT "select count (*) from knows k1 table option (index k_p2) where not exists (select 1 from knows k2 table option (loop, index k_p2) where k1.k_person1id = k2.k_person1id and k1.k_person2id = k2.k_person2id)"


void
rq_check (it_cursor_t * itc)
{
  int n, bs;
  query_instance_t *qi = itc ? (query_instance_t *) itc->itc_out_state : NULL;
  caddr_t err = NULL;
  static query_t *qr;
  local_cursor_t *lc;
  if (!qr)
    {
      cl_run_local_only = 1;
      qr = sql_compile (RQ_CHECK_TEXT, bootstrap_cli, &err, SQLC_DEFAULT);
    }
  rq_check_ctr++;
  if (rq_check_ctr < rq_check_min || (rq_check_ctr % rq_check_mod) != 0)
    return;
  if (itc)
    {
  IN_TXN;
  lt_commit (itc->itc_ltrx, TRX_CONT);
  LEAVE_TXN;
    }
  bs = dc_batch_sz;
  dc_batch_sz = rq_batch_sz;
  if (-1 != dbf_rq_slice_only)
    cli_set_slice (qi->qi_client, itc->itc_insert_key->key_partition->kpd_map, dbf_rq_slice_only, NULL);
  if (qi)
  qr_rec_exec (qr, qi->qi_client, &lc, qi, NULL, 0);
  else
    {
      lt_enter (rfwd_cli->cli_trx);
      qr_quick_exec (qr, rfwd_cli, "", &lc, 0);
    }
  lc_next (lc);
  dc_batch_sz = bs;
  n = unbox (lc_nth_col (lc, 0));
  lc_free (lc);
  if (!qi)
    {
      IN_TXN;
      lt_leave (rfwd_cli->cli_trx);
      LEAVE_TXN;
    }
  if (n)
    {
      bing ();
      col_ins_error = 1;
    }
}

caddr_t *
rq_check_page_bounds (it_cursor_t * itc, buffer_desc_t * buf)
{
  caddr_t *bounds = dk_alloc_box (4 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  int save = itc->itc_map_pos;
  int lower = MAX (0, itc->itc_map_pos - 4);
  int upper = MIN (itc->itc_map_pos + 4, buf->bd_content_map->pm_count - 1);
  dbe_col_loc_t *cl1 =
      cl_list_find (itc->itc_insert_key->key_key_fixed, ((dbe_column_t *) itc->itc_insert_key->key_parts->data)->col_id);
  enable_pogs_check = 1;
  if (0 == lower && KV_LEFT_DUMMY == IE_KEY_VERSION (BUF_ROW (buf, lower)))
    lower = 1;
  itc->itc_map_pos = lower;
  itc->itc_row_data = BUF_ROW (buf, itc->itc_map_pos);
  bounds[0] = itc_box_column (itc, buf, 0, cl1);
  bounds[1] = itc_box_column (itc, buf, 0, &itc->itc_insert_key->key_key_var[0]);
  itc->itc_map_pos = upper;
  itc->itc_row_data = BUF_ROW (buf, itc->itc_map_pos);
  bounds[2] = itc_box_column (itc, buf, 0, cl1);
  bounds[3] = itc_box_column (itc, buf, 0, &itc->itc_insert_key->key_key_var[0]);
  itc->itc_map_pos = save;
  itc->itc_row_data = BUF_ROW (buf, itc->itc_map_pos);
  return bounds;
}


void
rq_range_check (it_cursor_t * itc, caddr_t * bounds)
{
  int n, bs;
  query_instance_t *qi = (query_instance_t *) itc->itc_out_state;
  caddr_t err = NULL;
  static query_t *qr1, *qr2;
  local_cursor_t *lc;
  if (!qr1)
    {
      cl_run_local_only = 1;
      qr1 = sql_compile (RQ_RANGE_CHECK_TEXT_1, bootstrap_cli, &err, SQLC_DEFAULT);
      qr2 = sql_compile (RQ_RANGE_CHECK_TEXT_2, bootstrap_cli, &err, SQLC_DEFAULT);
    }
  IN_TXN;
  lt_commit (itc->itc_ltrx, TRX_CONT);
  LEAVE_TXN;
  bs = dc_batch_sz;
  dc_batch_sz = rq_batch_sz;
  if (box_equal (bounds[0], bounds[2]))
    qr_rec_exec (qr1, qi->qi_client, &lc, qi, NULL, 3,
	":0", bounds[0], QRP_RAW, ":1", bounds[1], QRP_RAW, ":2", bounds[3], QRP_RAW);
  else
    qr_rec_exec (qr2, qi->qi_client, &lc, qi, NULL, 2, ":0", bounds[0], QRP_RAW, ":1", bounds[2], QRP_RAW);
  lc_next (lc);
  dc_batch_sz = bs;
  dk_free_box (bounds);
  n = unbox (lc_nth_col (lc, 0));
  lc_free (lc);
  if (n)
    {
      bing ();
      col_ins_error = 1;
    }
}

void
itc_any_dc_to_file (it_cursor_t * itc, int nth, int from, int to)
{
  data_col_t *dc = ITC_P_VEC (itc, nth);
  FILE *f = fopen ("col.out", "at");
  int inx;
  for (inx = from; inx < to; inx++)
    {
      caddr_t box = box_deserialize_string (((caddr_t *) dc->dc_values)[itc->itc_param_order[inx]], INT32_MAX, 0);
      dbg_print_box (box, f);
      fprintf (f, ",\n");
    }
  fclose (f);
}


db_buf_t
ce_skip_gap (db_buf_t ce)
{
  int l;
  while ((l = CE_GAP_LENGTH (ce, ce[0])))
    ce += l;
  return ce;
}


dk_set_t
mp_cons (mem_pool_t * mp, void *car, dk_set_t cdr)
{
  caddr_t c;
  MP_BYTES (c, mp, 2 * sizeof (caddr_t));
  ((dk_set_t) c)->data = car;
  ((dk_set_t) c)->next = cdr;
  return (dk_set_t) c;
}


void
mp_conc1 (mem_pool_t * mp, dk_set_t * r, void *v)
{
  dk_set_t c = mp_cons (mp, v, NULL);
  *r = dk_set_conc (*r, c);
}

void
mp_conc1_l (mem_pool_t * mp, dk_set_t * r, void* v, dk_set_t * last)
{
  dk_set_t c = mp_cons (mp, v, NULL);
  if (!*r)
    *r = c;
  else if (*last)
    {
      (*last)->next = c;
    }
  else 
    {
      *last = dk_set_last (*r);
      (*last)->next = c;
    }
  *last = c;
}

#if 0
int
ce_total_bytes (db_buf_t ce)
{
  int v, by, hl;
  dtp_t t, f;
  ce_head_info (ce, &by, &v, &t, &f, &hl);
  return by + hl;
}
#else
int
ce_total_bytes (db_buf_t ce)
{
  dtp_t flags, ce_type;
  int n_bytes, n_values, hl, is_null;
  flags = ce[0];
  ce_type = flags & CE_TYPE_MASK;
  if (ce_type < CE_BITS)
    {
      if (ce_type <= CE_RL)
	{
	  is_null = CET_NULL == (flags & CE_DTP_MASK);
	  if (is_null)
	    return (CE_IS_SHORT & flags) ? 2 : 3;
	  else if ((CE_IS_SHORT & flags))
	    {
	      n_values = ce[1];
	      hl = 2;
	    }
	  else
	    {
	      n_values = SHORT_REF_CA (ce + 1);
	      hl = 3;
	    }
	  n_bytes = ce_1_len (ce + hl, flags);
	}
      else
	{
	  if (CE_GAP == ce_type)
	    {
	      n_bytes = CE_GAP_LENGTH (ce, flags);
	      hl = 0;
	    }
	  else if (CE_VEC == ce_type)
	    {
	      n_values = (CE_IS_SHORT & flags) ? ce[1] : SHORT_REF_CA (ce + 1);
	      if (CE_INTLIKE (flags))
		{
		  n_bytes = n_values * ((flags & CE_IS_64) ? 8 : 4);
		  hl = (CE_IS_SHORT & flags) ? 2 : 3;
		}
	      else
		{
		  n_bytes = n_values;
		  hl = (CE_IS_SHORT & flags) ? 3 : 5;
		}
	    }
	}
    }
  else
    {
      if ((CE_IS_SHORT & flags))
	{
	  return 3 + (uint32) ce[1];
	}
      else
	{
	  return 5 + SHORT_REF_CA (ce + 1);
	}
    }
  return n_bytes + hl;
}
#endif


int
ce_n_values (db_buf_t ce)
{
  int v, by, hl;
  dtp_t t, f;
  ce_head_info (ce, &by, &v, &t, &f, &hl);
  return v;
}


caddr_t
col_dp_string (row_delta_t * rd, dp_addr_t dp)
{
  caddr_t box = rd_alloc_box (rd, 10, DV_STRING);
  box[0] = DV_BLOB;
  SHORT_SET_NA (box + CPP_FIRST_CE, 0);
  SHORT_SET_NA (box + CPP_N_CES, 1);
  LONG_SET_NA (box + CPP_DP, dp);
  return box;
}


int 
ff_nop (caddr_t x)
{
  return 0;
}

db_buf_t
ce_1_value (mem_pool_t * mp, dtp_t col_dtp, caddr_t val)
{
  compress_state_t cs;
  db_buf_t last_ce;
  int last_ce_len;
  caddr_t err = NULL;
  db_buf_t dv;
  if (DV_ANY == col_dtp || IS_BLOB_DTP (col_dtp))
    dv = (db_buf_t) val;
  else
    {
      dv = (db_buf_t) box_to_any (val, &err);

      CEIC_FLOAT_INT (col_dtp, dv, (db_buf_t) box_any_dv ((db_buf_t) dv), dk_free_box);
    }
  cs_init (&cs, mp, 0, 1);
  cs.cs_exclude = dbf_compress_mask;
  SET_THR_TMP_POOL (mp);
  cs_compress (&cs, (caddr_t) dv);
  cs_best (&cs, &last_ce, &last_ce_len);
  SET_THR_TMP_POOL (NULL);
  mp_set_push (mp, &cs.cs_ready_ces, (void *) last_ce);
  cs_distinct_ces (&cs);
  if (DV_ANY != col_dtp && !IS_BLOB_DTP (col_dtp))
    dk_free_box ((caddr_t) dv);
  return (db_buf_t) cs.cs_ready_ces->data;
}


void
buf_ce_initial (buffer_desc_t * buf, dbe_column_t * col, caddr_t val)
{
  /* make single ce with val in it and set the map */
  mem_pool_t *mp = mem_pool_alloc ();
  int fill = 0;
  db_buf_t str = ce_1_value (mp, col->col_sqt.sqt_dtp, val);
  db_buf_t page = buf->bd_buffer;
  int len = ce_total_bytes (str);
  memcpy_16 (page + DP_DATA, str, len);
  fill = DP_DATA + len;
  cs_write_gap (page + fill, PAGE_SZ - fill);
  pg_make_col_map (buf);
  page_leave_outside_map (buf);
  mp_free (mp);
}


buffer_desc_t *
it_new_col_page (index_tree_t * it, dp_addr_t near_dp, it_cursor_t * has_hold, dbe_column_t * col)
{
  buffer_desc_t *buf = it_new_page (it, near_dp, DPF_INDEX, col->col_id, has_hold);
  SHORT_SET (buf->bd_buffer + DP_FLAGS, DPF_COLUMN);
  LONG_SET (buf->bd_buffer + DP_PARENT, col->col_id);
  return buf;
}

void col_ins_rd_init (row_delta_t * rd, dbe_key_t * key);


row_lock_t *
rl_col_allocate ()
{
  row_lock_t *rl = rl_allocate ();
  rl->rl_cols = (col_row_lock_t **) dk_alloc_box_zero (32 * sizeof (caddr_t), DV_BIN);
  rl->pl_type = PL_SHARED;
  return rl;
}

int itc_col_initial (it_cursor_t * itc, buffer_desc_t * buf, row_delta_t * rd)
{
  dbe_key_t *key = itc->itc_insert_key;
  row_delta_t *prd2;
  dbe_col_loc_t *cl;
  dk_set_t parts = key->key_parts;
  int fill = 0, nth = 0;
  LOCAL_RD (rd2);
  prd2 = &rd2;
  fill = key->key_n_significant;
  memcpy_16 (rd2.rd_values, rd->rd_values, sizeof (caddr_t) * key->key_n_significant);
  rd2.rd_key = key;
  for (cl = key->key_row_var; cl->cl_col_id; cl++)
    {
      caddr_t val;
      dbe_column_t *col = (dbe_column_t *) parts->data;
      buffer_desc_t *col_buf = it_new_col_page (itc->itc_tree, 0, itc, col);
      parts = parts->next;
      prd2->rd_values[fill++] = col_dp_string (rd, col_buf->bd_page);
      val = nth < key->key_n_significant ? rd->rd_values[key->key_part_in_layout_order[nth]] : rd->rd_values[nth];
      buf_ce_initial (col_buf, col, val);
      nth++;
    }
  prd2->rd_map_pos = 1;
  prd2->rd_op = RD_INSERT;
  if (!itc->itc_non_txn_insert)
    {
      row_lock_t *rl;
      col_row_lock_t *clk;
      int rc;
      itc->itc_map_pos = 0;
      rc = itc_set_lock_on_row (itc, &buf);
      if (NO_WAIT != rc)
	return rc;
      rl = rl_col_allocate ();
      if (rd->rd_rl && INS_NEW_RL != rd->rd_rl)
	clk = (col_row_lock_t *) rd->rd_rl;
      else
      clk = itc_new_clk (itc, 0);
      rl_add_clk (rl, clk, 0, 1);
      itc->itc_map_pos = 1;
      prd2->rd_rl = rl;
    }
  col_ins_rd_init (prd2, key);
  ITC_DELTA (itc, buf);
  page_apply (itc, buf, 1, &prd2, PA_MODIFY);
  return NO_WAIT;
}


#define CEIC_NEXT_OP(ceic, delta, op, row)	\
{ \
  if (!ceic->ceic_delta_ce_op) \
    { op = 0; row = -2; }       \
  else  \
    { row = 0xffffff & (ptrlong)ceic->ceic_delta_ce_op->data;\
      op = 0xff000000 & (ptrlong)ceic->ceic_delta_ce_op->data; \
      delta = (db_buf_t)ceic->ceic_delta_ce->data; \
      ceic->ceic_delta_ce_op = ceic->ceic_delta_ce_op->next; \
      ceic->ceic_delta_ce = ceic->ceic_delta_ce->next; \
    } \
}


void
buf_set_pm (buffer_desc_t * buf, page_map_t * pm)
{
  int sz;
  if (buf->bd_content_map->pm_size != PM_SIZE (pm->pm_count))
    {
      buf->bd_content_map->pm_count = 0;	/* do not copy entries in map_resize, might no longer fit in new size */
      map_resize (buf, &buf->bd_content_map, PM_SIZE (pm->pm_count));
    }
  sz = buf->bd_content_map->pm_size;
  memcpy_16 (buf->bd_content_map, pm, PM_ENTRIES_OFFSET + pm->pm_count * sizeof (short));
  buf->bd_content_map->pm_size = sz;
}


db_buf_t
ceic_dps_top_col (ce_ins_ctx_t * ceic, col_data_ref_t * cr, int n_ces, dk_set_t dps)
{
  int nth = CPP_DP;
  int n_pages = dk_set_length (dps);
  db_buf_t str = (db_buf_t) mp_alloc_box (ceic->ceic_mp, CPP_DP + 1 + (n_pages * sizeof (dp_addr_t)), DV_STRING);
  str[0] = DV_BLOB;
  SHORT_SET_NA (str + CPP_N_CES, n_ces);
  SHORT_SET_NA (str + CPP_FIRST_CE, cr->cr_first_ce);
  DO_SET (ptrlong, dp, &dps)
  {
    LONG_SET_NA (str + nth, dp);
    nth += sizeof (dp_addr_t);
  }
  END_DO_SET ();
  return str;
}


page_map_t *
mp_pm_alloc (mem_pool_t * mp, int sz, page_map_t * init)
{
  page_map_t *pm = (page_map_t *) mp_alloc (mp, PM_ENTRIES_OFFSET + sizeof (short) * sz);
  memset (pm, 0, PM_ENTRIES_OFFSET);
  pm->pm_bytes_free = PAGE_DATA_SZ;
  pm->pm_filled_to = DP_DATA;
  if (init)
    memcpy_16 (pm, init, PM_ENTRIES_OFFSET + init->pm_count * sizeof (short));
  pm->pm_size = sz;
  return pm;
}


void
cep_append (ce_ins_ctx_t * ceic, ce_new_pos_t * cep)
{
  ce_new_pos_t **prev = &ceic->ceic_reloc;
  while (*prev)
    prev = &(*prev)->cep_next;
  *prev = cep;
  cep->cep_next = NULL;
}


ceic_result_page_t *
ceic_result_page (ce_ins_ctx_t * ceic)
{
  ceic_result_page_t **prev = &ceic->ceic_res;
  ceic_result_page_t *cer = (ceic_result_page_t *) mp_alloc (ceic->ceic_mp, sizeof (ceic_result_page_t));
  memset (cer, 0, sizeof (*cer));
  cer->cer_pm = mp_pm_alloc (ceic->ceic_mp, 40, NULL);
  while (*prev)
    prev = &(*prev)->cer_next;
  *prev = cer;
  cer->cer_next = NULL;
  return cer;
}


ceic_result_page_t *
ceic_prepare_result_page (ce_ins_ctx_t * ceic)
{
  ceic_result_page_t *cer;
  if (!ceic->ceic_cur_out)
    {
      ceic->ceic_cur_out = cer = ceic->ceic_res;
      cer->cer_buffer = (db_buf_t) mp_alloc (ceic->ceic_mp, PAGE_SZ);
    }
  else
    {
      ceic->ceic_cur_out = cer = ceic->ceic_cur_out->cer_next;
      cer->cer_buf = it_new_col_page (ceic->ceic_itc->itc_tree, ceic->ceic_org_buf->bd_page, ceic->ceic_itc, ceic->ceic_col);
      cer->cer_buffer = cer->cer_buf->bd_buffer;
    }
  /* the extra gap after last ins is substracted from free on prev pass, so no extra here */
  if (cer->cer_n_ces)
    cer->cer_spacing = cer->cer_pm->pm_bytes_free / cer->cer_n_ces;
  cer->cer_bytes_free = PAGE_DATA_SZ;
  if (cer->cer_pm->pm_size < 2 * cer->cer_n_ces)
    cer->cer_pm = mp_pm_alloc (ceic->ceic_mp, cer->cer_n_ces * 2, NULL);
  cer->cer_pm->pm_bytes_free = PAGE_DATA_SZ;
  if (cer->cer_n_ces > PM_MAX_CES)
    GPF_T1 ("A cer has more ces than fit in a pm");
  return cer;
}


void
cer_append_ce (ce_ins_ctx_t * ceic, ceic_result_page_t * cer, db_buf_t ce, int is_last)
{
  int bytes = ce_total_bytes (ce);
  page_map_t *pm = cer->cer_pm;
  cer->cer_bytes_free -= bytes + (is_last ? ce_last_insert_margin : 0);
  if (cer->cer_pm->pm_count + 2 >= cer->cer_pm->pm_size)
    pm = cer->cer_pm = mp_pm_alloc (ceic->ceic_mp, cer->cer_pm->pm_size * 2, cer->cer_pm);
  if (pm->pm_filled_to > DP_DATA)
    {
      int space = cer->cer_spacing;
      if (cer->cer_after_last_insert)
	{
	  space += ce_last_insert_margin;
	  cer->cer_after_last_insert = 0;
	}
      cs_write_gap (cer->cer_buffer + pm->pm_filled_to, space);
      pm->pm_filled_to += space;
    }
  memcpy_16 (cer->cer_buffer + pm->pm_filled_to, ce, bytes);
  pm->pm_bytes_free -= bytes;
  pm->pm_entries[pm->pm_count] = pm->pm_filled_to;
  pm->pm_entries[pm->pm_count + 1] = ce_n_values (ce);
  pm->pm_count += 2;
  pm->pm_filled_to += bytes;
  if (pm->pm_count / 2 > PM_MAX_CES)
    GPF_T1 ("filling more ces on a page than max per pm");
  cs_write_gap (cer->cer_buffer + pm->pm_filled_to, PAGE_SZ - pm->pm_filled_to);
  if (is_last)
    cer->cer_after_last_insert = 1;
}


#define CER_ADD(bytes, ce)				\
{  \
  if (cer->cer_pm->pm_bytes_free < bytes || cer->cer_n_ces >= PM_MAX_CES) \
    cer = ceic_result_page (ceic); \
  cer->cer_pm->pm_bytes_free -= bytes; \
  cer->cer_n_ces++; \
  if (even_split) mp_set_push (ceic->ceic_mp, &cer->cer_ces, (void*)ce); \
  if (in_seg && !after_seg) ceic->ceic_n_ces++; \
}

db_buf_t
cr_limit_ce (col_data_ref_t * cr, short *inx_ret)
{
  /* return first ce that is after this seg of the col.  null if the last page ends with a ce of this seg */
  int p, n_ces = 0, to_go = cr->cr_n_ces;
  int n_pages = cr->cr_n_pages;
  for (p = 0; p < n_pages; p++)
    {
      page_map_t *pm;
      int first_ce;
      int ces_on_page;
      if (p + 1 < n_pages)
	__builtin_prefetch (&cr->cr_pages[p + 1].cp_map->pm_count);
      pm = cr->cr_pages[p].cp_map;
      first_ce = 0 == p ? cr->cr_first_ce : 0;
      ces_on_page = (pm->pm_count / 2) - first_ce;
      if (ces_on_page + n_ces > to_go)
	{
	  int r = (first_ce + to_go - n_ces) * 2;
	  if (inx_ret)
	    *inx_ret = r;
	  return cr->cr_pages[p].cp_string + pm->pm_entries[r];
	}
      n_ces += ces_on_page;
#if 0
      for (r = 0 == p ? cr->cr_first_ce * 2 : 0; r < pm->pm_count; r += 2)
	{
	  if (n_ces++ == cr->cr_n_ces)
	    {
	      if (inx_ret)
		*inx_ret = r;
	      return cr->cr_pages[p].cp_string + pm->pm_entries[r];
	    }
	}
#endif
    }
  if (inx_ret)
    *inx_ret = cr->cr_pages[cr->cr_n_pages - 1].cp_map->pm_count;
  return NULL;
}


void
ceic_record_ce_move (ce_ins_ctx_t * ceic, db_buf_t ce, int r)
{
  ce_new_pos_t *cep;
  buffer_desc_t *buf = ceic->ceic_org_buf;
  ceic_result_page_t *cer = ceic->ceic_cur_out;
  cep = (ce_new_pos_t *) mp_alloc (ceic->ceic_mp, sizeof (ce_new_pos_t));
  cep->cep_old_dp = buf->bd_page;
  cep->cep_new_dp = cer->cer_buf ? cer->cer_buf->bd_page : ceic->ceic_org_buf->bd_page;
  cep->cep_old_nth = r / 2;
  cep->cep_new_nth = (cer->cer_pm->pm_count / 2) - 1;
  cep_append (ceic, cep);
}


int
pm_free_diff (page_map_t * pm1, page_map_t * pm2)
{
  int d = (int) pm1->pm_bytes_free - (int) pm2->pm_bytes_free;
  return d < 0 ? -d : d;
}


db_buf_t
ceic_even_split (ce_ins_ctx_t * ceic, int first_ce_inx)
{
  /* if a page splits in 2 and left side has ces inside the run that can move to the right for balance then move some.  The move updates the pms of the cers and gives a split ce that marks the split instead of left going full. */
  page_map_t *pm1, *pm2;
  int n_avail, ctr, prev_diff, next_diff;
  ceic_result_page_t *cer = ceic->ceic_res, *cer2;
  db_buf_t move_ce = NULL, prev_move = NULL;
  if (!cer->cer_next || cer->cer_next->cer_next)
    return NULL;
  pm1 = ceic->ceic_res->cer_pm;
  cer2 = ceic->ceic_res->cer_next;
  pm2 = cer2->cer_pm;
  prev_diff = pm_free_diff (pm1, pm2);
  if (prev_diff < 1000)
    return NULL;
  n_avail = dk_set_length (cer->cer_ces) - first_ce_inx;
  for (ctr = 0; ctr < n_avail; ctr++)
    {
      int bytes;
      move_ce = cer->cer_ces->data;
      bytes = ce_total_bytes (move_ce);
      cer->cer_ces = cer->cer_ces->next;
      next_diff = ((int) pm1->pm_bytes_free + bytes) - ((int) pm2->pm_bytes_free - bytes);
      next_diff = next_diff < 0 ? -next_diff : next_diff;
      if (cer2->cer_n_ces >= PM_MAX_CES - 2)
	return prev_move;
      if (next_diff > prev_diff)
	return prev_move;
      prev_diff = next_diff;
      pm2->pm_bytes_free -= bytes;
      pm1->pm_bytes_free += bytes;
      cer->cer_n_ces--;
      cer2->cer_n_ces++;
      prev_move = move_ce;
    }
  return move_ce;
}


void
ceic_apply (ce_ins_ctx_t * ceic, col_data_ref_t * cr, db_buf_t limit_ce)
{
  int op, delta_row, ce_ctr = 0, delta_bytes;
  int first_ce_inx = 0, r;
  db_buf_t delta, split_ce = NULL;
  dk_set_t op_save;
  dk_set_t delta_save;
  ceic_result_page_t *cer = ceic_result_page (ceic);
  int even_split = !ceic->ceic_itc->itc_col_right_ins;
  int after_seg = 0, in_seg = 0;
  page_map_t *pm = ceic->ceic_org_buf->bd_content_map;
  ceic->ceic_n_ces = 0;
  op_save = ceic->ceic_delta_ce_op;
  delta_save = ceic->ceic_delta_ce;
  if (cr->cr_pages[0].cp_ceic == ceic)
    first_ce_inx = cr->cr_first_ce;

  CEIC_NEXT_OP (ceic, delta, op, delta_row);
  for (r = 0; r < pm->pm_count; r += 2)
    {
      db_buf_t ce = ceic->ceic_org_buf->bd_buffer + pm->pm_entries[r];
      int any_replaces = 0;
      int bytes = ce_total_bytes (ce);
      any_replaces = 0;
      if (ce_ctr++ == first_ce_inx)
	in_seg = 1;
      while (r == delta_row)
	{
	  if (CE_DELETE == op)
	    {
	      delta_bytes = 0;
	      any_replaces = 1;
	      even_split = 0;
	    }
	  else
	    {
	      delta_bytes = ce_total_bytes (delta);
	      if (CE_REPLACE == op)
		any_replaces = 1;
	      if (!ceic->ceic_delta_ce)
		delta_bytes += ce_last_insert_margin;
	      CER_ADD (delta_bytes, delta);
	    }
	  CEIC_NEXT_OP (ceic, delta, op, delta_row);
	}
      if (ce == limit_ce)
	after_seg = 1;
      if (!any_replaces)
	{
	  CER_ADD (bytes, ce);
	}
    }
  while (r == delta_row)
    {
      int delta_bytes = ce_total_bytes (delta);
      if (CE_INSERT != op)
	GPF_T1 ("non-insert delta ce after page");
      if (!ceic->ceic_delta_ce)
	delta_bytes += ce_last_insert_margin;
      CER_ADD (delta_bytes, delta);
      CEIC_NEXT_OP (ceic, delta, op, delta_row);
    }
  ceic->ceic_delta_ce_op = op_save;
  ceic->ceic_delta_ce = delta_save;

  ce_ctr = 0;
  if (even_split)
    split_ce = ceic_even_split (ceic, first_ce_inx);
  in_seg = after_seg = 0;
  ceic->ceic_cur_out = NULL;
  cer = ceic_prepare_result_page (ceic);
  CEIC_NEXT_OP (ceic, delta, op, delta_row);
  for (r = 0; r < pm->pm_count; r += 2)
    {
      int any_replaces = 0;
      db_buf_t ce = (db_buf_t) ceic->ceic_org_buf->bd_buffer + pm->pm_entries[r];
      int bytes = ce_total_bytes (ce);
      if (ce_ctr++ == first_ce_inx)
	in_seg = 1;
      any_replaces = 0;
      while (r == delta_row)
	{
	  if (CE_DELETE == op)
	    {
	      any_replaces = 1;
	    }
	  else
	    {
	      delta_bytes = ce_total_bytes (delta);
	      if (!ceic->ceic_delta_ce && !split_ce)
		delta_bytes += ce_last_insert_margin;
	      if (cer->cer_bytes_free < delta_bytes || cer->cer_pm->pm_count / 2 >= PM_MAX_CES || delta == split_ce)
		cer = ceic_prepare_result_page (ceic);
	      cer_append_ce (ceic, cer, delta, !ceic->ceic_delta_ce && !split_ce);
	      if (CE_REPLACE == op)
		any_replaces = 1;
	    }
	  CEIC_NEXT_OP (ceic, delta, op, delta_row);
	}
      if (!any_replaces)
	{
	  if (cer->cer_bytes_free < bytes || cer->cer_pm->pm_count / 2 >= PM_MAX_CES || split_ce == ce)
	    cer = ceic_prepare_result_page (ceic);
	  cer_append_ce (ceic, cer, ce, 0);
	}
      if (ce == limit_ce)
	after_seg = 1;
      if (after_seg)
	ceic_record_ce_move (ceic, ce, r);
    }
  while (r == delta_row)
    {
      int delta_bytes = ce_total_bytes (delta);
      if (!ceic->ceic_delta_ce)
	delta_bytes += ce_last_insert_margin;
      if (cer->cer_bytes_free < delta_bytes || cer->cer_pm->pm_count / 2 >= PM_MAX_CES)
	cer = ceic_prepare_result_page (ceic);
      cer_append_ce (ceic, cer, delta, !ceic->ceic_delta_ce && !split_ce);
      CEIC_NEXT_OP (ceic, delta, op, delta_row);
    }
}


int
ce_space_after (buffer_desc_t * buf, db_buf_t ce)
{
  int n_bytes = ce_total_bytes (ce);
  if (ce > buf->bd_buffer && ce < buf->bd_buffer + PAGE_SZ)
    {
      if (ce + n_bytes - buf->bd_buffer > PAGE_SZ - CE_GAP_MAX_BYTES)
	return buf->bd_buffer + PAGE_SZ - (ce + n_bytes);
    }
  else
    {
      int len = box_length (ce);
      if (len < n_bytes)
	GPF_T1 ("replace ce over its box end");
      return len - n_bytes;
    }
  return CE_GAP_LENGTH (ce + n_bytes, ce[n_bytes]);
}

caddr_t
ceic_ce_value (ce_ins_ctx_t * ceic, db_buf_t ce, int inx)
{
  mem_pool_t *mp = ceic->ceic_mp;
  col_pos_t cpo;
  caddr_t val;
  data_col_t dc;
  int is_any = DV_ANY == ceic->ceic_itc->itc_insert_key->key_row_var[ceic->ceic_nth_col].cl_sqt.sqt_col_dtp;
  memset (&cpo, 0, sizeof (cpo));
  memset (&dc, 0, sizeof (data_col_t));
  cpo.cpo_itc = ceic->ceic_itc;
  cpo.cpo_string = ce;
  cpo.cpo_bytes = ce_total_bytes (ce);
  if (is_any)
    {
      dc.dc_type = DCT_FROM_POOL;
      dc.dc_sqt.sqt_dtp = DV_ANY;
    }
  else
    dc.dc_type = DCT_BOXES | DCT_FROM_POOL;
  dc.dc_mp = mp;
  dc.dc_n_places = 1;
  dc.dc_values = (db_buf_t) & val;
  cpo.cpo_dc = &dc;
  cpo.cpo_value_cb = ce_result;
  cpo.cpo_ce_op = NULL;
  cpo.cpo_pm = NULL;
  cs_decode (&cpo, inx, inx + 1);
  return val;
}

boxint
dv_int (db_buf_t dv, dtp_t * dtp_ret)
{
  switch (dv[0])
    {
    case DV_SHORT_INT:
      *dtp_ret = DV_LONG_INT;
      return ((char *) dv)[1];
    case DV_LONG_INT:
      *dtp_ret = DV_LONG_INT;
      return LONG_REF_NA (dv + 1);
    case DV_INT64:
      *dtp_ret = DV_LONG_INT;
      return INT64_REF_NA (dv + 1);
    case DV_IRI_ID:
      *dtp_ret = DV_IRI_ID;
      return (iri_id_t) (uint32) LONG_REF_NA (dv + 1);
    case DV_IRI_ID_8:
      *dtp_ret = DV_IRI_ID;
      return INT64_REF_NA (dv + 1);
    }
  *dtp_ret = dv[0];
  return 0;
}


int64
ceic_int_value (ce_ins_ctx_t * ceic, int nth, dtp_t * dtp_ret)
{
  it_cursor_t *itc = ceic->ceic_itc;
  caddr_t val;
  val = itc->itc_vec_rds[itc->itc_param_order[nth]]->rd_values[ceic->ceic_nth_col];
  if (nth + 1 < itc->itc_n_sets)
    __builtin_prefetch (itc->itc_vec_rds[itc->itc_param_order[nth + 1]]->rd_values[ceic->ceic_nth_col]);
  if (DV_ANY == ceic->ceic_col->col_sqt.sqt_dtp)
    {
      return dv_int ((db_buf_t) val, dtp_ret);
    }
  if (DV_DOUBLE_FLOAT == ceic->ceic_col->col_sqt.sqt_dtp)
    {
      *dtp_ret = DV_LONG_INT;
      return *(int64*)val;
    }
  if (DV_SINGLE_FLOAT == ceic->ceic_col->col_sqt.sqt_dtp)
    {
      *dtp_ret = DV_LONG_INT;
      return *(int32*)val;
    }
  *dtp_ret = DV_TYPE_OF (val);
  return unbox_iri_int64 (val);
}


db_buf_t
ceic_ins_any_value (ce_ins_ctx_t * ceic, int nth)
{
  caddr_t err = NULL;
  it_cursor_t *itc = ceic->ceic_itc;
  caddr_t r;
  caddr_t box = itc->itc_vec_rds[itc->itc_param_order[nth]]->rd_values[ceic->ceic_nth_col];
  if (nth + 1 < itc->itc_n_sets)
    __builtin_prefetch (itc->itc_vec_rds[itc->itc_param_order[nth + 1]]->rd_values[ceic->ceic_nth_col]);
  if (COL_UPD_NO_CHANGE == box)
    return (db_buf_t) box;
  if (DV_ANY == ceic->ceic_col->col_sqt.sqt_dtp || IS_BLOB_DTP (ceic->ceic_col->col_sqt.sqt_dtp))
    {
      return (db_buf_t) box;
    }
  r = mp_box_to_any_1 (box, &err, ceic->ceic_mp, 0);
  CEIC_FLOAT_INT (ceic->ceic_col->col_sqt.sqt_dtp, r, mp_box_any_dv (ceic->ceic_mp, (db_buf_t) r), ff_nop);
  return (db_buf_t) r;
}


int
ce_can_truncate (db_buf_t ce)
{
  dtp_t ce_type = *ce & CE_TYPE_MASK;
  if (CE_RL == ce_type || (CE_VEC == ce_type && CE_INTLIKE (*ce)))
    return 1;
  return 0;
}


void
ce_truncate_ce (db_buf_t ce, int new_n_values, int *new_bytes, int *prev_bytes)
{
  db_buf_t ce_first;
  dtp_t flags = *ce;
  int n_bytes, n_values, elt_sz;
  switch (flags & ~CE_IS_SHORT)
    {
    case CE_VEC:
    case CE_VEC | CE_IS_IRI:
    case CE_VEC | CE_IS_64:
    case CE_VEC | CE_IS_IRI | CE_IS_64:
      CE_INTVEC_LENGTH (ce, ce_first, n_bytes, n_values, int);
      elt_sz = CE_IS_64 & flags ? sizeof (int64) : sizeof (int32);
      if (CE_IS_64 & flags)
	n_bytes *= 2;
      if (CE_IS_SHORT & flags)
	{
	  ce[1] = new_n_values;
	}
      else
	{
	  SHORT_SET_CA (ce + 1, new_n_values);
	}
      *prev_bytes = (ce_first - ce) + elt_sz * n_values;
      *new_bytes = *prev_bytes - elt_sz * (n_values - new_n_values);
      break;
    case CE_ALL_VARIANTS (CE_RL):
      n_bytes = ce_total_bytes (ce);
      *new_bytes = *prev_bytes = n_bytes;
      if (CE_IS_SHORT & flags)
	ce[1] = new_n_values;
      else
	SHORT_SET_CA (ce + 1, new_n_values);
      break;
    default:
      GPF_T1 ("unsupported ce type for ce truncate");
    }
}

void
ce_truncate (buffer_desc_t * buf, int ice, int new_n_values)
{
  db_buf_t ce = BUF_ROW (buf, ice);
  int prev_bytes, new_bytes;
  ce_truncate_ce (ce, new_n_values, &new_bytes, &prev_bytes);
  buf->bd_content_map->pm_bytes_free += prev_bytes - new_bytes;
  buf->bd_content_map->pm_entries[ice + 1] = new_n_values;
  cs_write_gap (ce + new_bytes, prev_bytes - new_bytes);
}

void
cs_distinct_ces (compress_state_t * cs)
{
  /* starts w inverted list of cs_ready_ces where each string can have many ce's in order.  Ends with a list of distinct ce strings in left to right order */
  dk_set_t res = NULL;
  cs->cs_ready_ces = dk_set_nreverse (cs->cs_ready_ces);
  DO_SET (db_buf_t, ce, &cs->cs_ready_ces)
  {
    db_buf_t ce1 = ce_skip_gap (ce);
    int len = box_length (ce) - 1;
    while (ce1 < ce + len)
      {
	int l2 = ce_total_bytes (ce1);
	mp_set_push (cs->cs_mp, &res, (void *) ce1);
	ce1 += l2;
	if (ce1 < ce + len)
	  ce1 = ce_skip_gap (ce1);
      }
  }
  END_DO_SET ();
  cs->cs_ready_ces = dk_set_nreverse (res);
}


void
ce_mrg_check (compress_state_t * cs, int n_in)
{
  int n = 0;
  return;
  DO_SET (db_buf_t, ce, &cs->cs_ready_ces) n += ce_string_n_values (ce, box_length (ce) - 1);
  END_DO_SET ();
  if (n + cs->cs_n_values != n_in)
    GPF_T1 ("compress out of whack with values");
}


void
ce_merge_int (ce_ins_ctx_t * ceic, compress_state_t * cs, data_col_t * dc, int row_of_dc, int split_at)
{
  int is_key = ceic->ceic_nth_col < ceic->ceic_itc->itc_insert_key->key_n_significant;
  int n_in = 0;
  db_buf_t best;
  int inx, len;
  dtp_t ign;
  it_cursor_t *itc = ceic->ceic_itc;
  int nth_range = itc->itc_ce_first_range;
  for (inx = 0; inx <= dc->dc_n_values; inx++)
    {
      while (nth_range < itc->itc_range_fill && itc->itc_ranges[nth_range].r_first == inx + row_of_dc)
	{
	  int nth_val = nth_range + itc->itc_ce_first_set - itc->itc_ce_first_range;
	  int is_upd = itc->itc_ranges[nth_range].r_first != itc->itc_ranges[nth_range].r_end;
	  int64 value;
	  if (is_upd && inx >= dc->dc_n_values)
	    return;		/* upd would fall after the dc, only an insert can */
	  value = ceic_int_value (ceic, nth_val, &ign);
	  cs_compress_int (cs, &value, 1);
	  if (is_upd)
	    {
	      if (!is_key)
		ceic_del_ins_rbe_int (ceic, nth_range, ((int64 *) dc->dc_values)[inx], dc->dc_dtp);
	      inx++;
	    }
	  n_in++;
	  ce_mrg_check (cs, n_in);
	  nth_range++;
	  if (cs->cs_n_values == split_at)
	    {
	      if (cs->cs_n_values)
		{
		  cs_best (cs, &best, &len);
		  t_set_push (&cs->cs_ready_ces, (void *) best);
		}
	      split_at = -1;
	      cs_reset (cs);
	    }
	}
      if (inx == dc->dc_n_values)
	break;
      cs_compress_int (cs, &((int64 *) dc->dc_values)[inx], 1);
      n_in++;
      ce_mrg_check (cs, n_in);
      if (cs->cs_n_values == split_at)
	{
	  if (cs->cs_n_values)
	    {
	      cs_best (cs, &best, &len);
	      t_set_push (&cs->cs_ready_ces, (void *) best);
	    }
	  split_at = -1;
	  cs_reset (cs);
	}
}
}


void
ce_merge (ce_ins_ctx_t * ceic, compress_state_t * cs, data_col_t * dc, int row_of_dc, int split_at)
{
  int is_key = ceic->ceic_nth_col < ceic->ceic_itc->itc_insert_key->key_n_significant;
  int n_in = 0;
  db_buf_t best;
  int inx, len;
  it_cursor_t *itc = ceic->ceic_itc;
  int nth_range = itc->itc_ce_first_range;
  for (inx = 0; inx <= dc->dc_n_values; inx++)
    {
      while (nth_range < itc->itc_range_fill && itc->itc_ranges[nth_range].r_first == inx + row_of_dc)
	{
	  int nth_val = nth_range + itc->itc_ce_first_set - itc->itc_ce_first_range;
	  int is_upd = itc->itc_ranges[nth_range].r_first != itc->itc_ranges[nth_range].r_end;
	  caddr_t value;
	  if (is_upd && inx >= dc->dc_n_values)
	    return;		/* upd would fall after the dc, only an insert can */
	  value = (caddr_t) ceic_ins_any_value (ceic, nth_val);
	  if (COL_UPD_NO_CHANGE == value)
	    goto no_value;
	  cs_compress (cs, value);
	  if (is_upd)
	    {
	      if (!is_key)
	      ceic_del_ins_rbe (ceic, nth_range, ((db_buf_t *) dc->dc_values)[inx]);
	      inx++;
	    }
	  n_in++;
	  ce_mrg_check (cs, n_in);
	  nth_range++;
	  if (cs->cs_n_values == split_at)
	    {
	      if (cs->cs_n_values)
		{
	      cs_best (cs, &best, &len);
	      t_set_push (&cs->cs_ready_ces, (void *) best);
		}
	      split_at = -1;
	      cs_reset (cs);
	    }
	}
      if (inx == dc->dc_n_values)
	break;
    no_value:
      cs_compress (cs, ((caddr_t *) dc->dc_values)[inx]);
      n_in++;
      ce_mrg_check (cs, n_in);
      if (cs->cs_n_values == split_at)
	{
	  if (cs->cs_n_values)
	    {
	  cs_best (cs, &best, &len);
	  t_set_push (&cs->cs_ready_ces, (void *) best);
	    }
	  split_at = -1;
	  cs_reset (cs);
	}
    }
}


void
ceic_cs_flags (ce_ins_ctx_t * ceic, compress_state_t * cs, dtp_t dcdtp)
{
  dk_set_t parts = ceic->ceic_itc->itc_insert_key->key_parts;
  dbe_column_t *first_col = (dbe_column_t *) parts->data;
  dbe_column_t *second_col = parts->next ? (dbe_column_t *) parts->next->data : NULL;
  if (ceic->ceic_col == first_col)
    {
      cs->cs_no_dict = 2;
      cs->cs_is_asc = 1;
    }
  if (ceic->ceic_col == second_col && 0 == first_col->col_name[1] && ('P' == first_col->col_name[0]
	  || 'G' == first_col->col_name[0]))
    cs->cs_no_dict = 2;
  if (DV_IRI_ID == dcdtp || DV_LONG_INT == dcdtp)
    {
      cs->cs_all_int = CS_INT_ONLY;
      cs->cs_dtp = dcdtp;
    }
  else
    {
      cs->cs_all_int = 0;
      cs->cs_dtp = 0;
    }
}


void
ceic_cs_anify (ce_ins_ctx_t * ceic, compress_state_t * cs)
{
  int n_values = cs->cs_n_values, inx;
  dtp_t dtp = cs->cs_dtp;
  dk_set_t ready_ces = cs->cs_ready_ces;
  dk_set_t prev_ready = cs->cs_prev_ready_ces;
  cs->cs_n_values = 0;
  cs->cs_prev_ready_ces = cs->cs_ready_ces = NULL;
  cs_reset (cs);
  cs_clear (cs);
  cs->cs_ready_ces = ready_ces;
  cs->cs_prev_ready_ces = prev_ready;
  ceic_cs_flags (ceic, cs, DV_ANY);
  for (inx = 0; inx < n_values; inx++)
    {
      int64 num = cs->cs_numbers[inx];
      caddr_t any;
      dtp_t tmp[10];
      if (DV_IRI_ID == dtp)
	dv_from_iri (tmp, num);
      else
	dv_from_int (tmp, num);
      any = mp_box_any_dv (ceic->ceic_mp, tmp);
      cs_compress (cs, any);
    }
}


void
ceic_init_dc (ce_ins_ctx_t * ceic, data_col_t * dc, db_buf_t ce)
{
  /* set dc to be typed if values and ce are of the same type or col is non-null int or iri.  If cs previously typed and now heterogenous, fill in the cs values with anies */
  compress_state_t *cs = ceic->ceic_top_ceic->ceic_cs;
  dtp_t col_dtp = dtp_canonical[ceic->ceic_col->col_sqt.sqt_col_dtp];
  if (!cs)
    cs = ceic->ceic_cs;
  /*goto any; */
  if (ceic->ceic_is_cpt_restore > COL_UPDATE)
    goto any;
  if (ceic->ceic_col->col_sqt.sqt_non_null && (DV_IRI_ID == col_dtp || DV_LONG_INT == col_dtp))
    goto typed;
  if (CE_INTLIKE (ce[0]))
    {
      if (ceic->ceic_is_ac)
	{
	  if (!cs->cs_n_values || (CS_INT_ONLY == cs->cs_all_int && cs->cs_dtp == (CE_IS_IRI & ce[0] ? DV_IRI_ID : DV_LONG_INT)))
	    goto typed;
	  goto any;
	}
      else
	{
	  goto any;
	  if (ceic->ceic_is_finalize || ceic_all_dtp (ceic, CE_IS_IRI & ce[0] ? DV_IRI_ID : DV_LONG_INT))
	    goto typed;
	  goto any;
	}
    }
  else
    goto any;
typed:
  if (DV_IRI_ID == col_dtp || DV_LONG_INT == col_dtp)
    dc->dc_dtp = col_dtp;
  else
    dc->dc_dtp = CE_IS_IRI & ce[0] ? DV_IRI_ID : DV_LONG_INT;
  dc->dc_type = DCT_NUM_INLINE;
  return;
any:
  if (cs->cs_n_values && CS_INT_ONLY == cs->cs_all_int)
    ceic_cs_anify (ceic, cs);
  dc->dc_dtp = DV_ANY;
  dc->dc_type = DCT_FROM_POOL;
}


void
t_set_trunc (dk_set_t * set)
{
  dk_set_t *prev = set;
  if (!*prev)
    return;
  while ((*prev)->next)
    prev = &((*prev)->next);
  *prev = NULL;
}


db_buf_t
ceic_ice_string (ce_ins_ctx_t * ceic, buffer_desc_t * buf, int ice)
{
  db_buf_t ret;
  dk_set_t last = dk_set_last (ceic->ceic_delta_ce_op);
  if (!last || ((ptrlong) last->data) != (CE_REPLACE | ice))
    return BUF_ROW (buf, ice);
  ret = (db_buf_t) dk_set_last (ceic->ceic_delta_ce)->data;
  t_set_trunc (&ceic->ceic_delta_ce);
  t_set_trunc (&ceic->ceic_delta_ce_op);
  return ret;
}

int dbf_ce_comp_check = 0;


caddr_t
cs_next_org (compress_state_t * cs, dk_set_t * s, int *nth)
{
  int n_org;
  caddr_t *org;
  if (!*s)
    *s = cs->cs_org_values = dk_set_nreverse (cs->cs_org_values);
  org = (caddr_t *) (*s)->data;
  n_org = BOX_ELEMENTS (org);
  if (*nth >= n_org)
    {
      *s = (*s)->next;
      if (!*s)
	GPF_T1 ("more values produced in compress than fed in the input");
      *nth = 0;
      org = (caddr_t *) (*s)->data;
    }
  (*nth)++;
  return org[*nth - 1];
}


void
ce_comp_check (compress_state_t * cs, db_buf_t ce, dk_set_t * org, int *nth)
{
  int inx;
  caddr_t *res = ce_box (ce, 0);
  for (inx = 0; inx < BOX_ELEMENTS (res); inx++)
    {
      caddr_t ov = cs_next_org (cs, org, nth);
      if (!box_equal (ov, res[inx]))
	bing ();
    }
  dk_free_tree ((caddr_t) res);
}


void
ceic_merge_insert (ce_ins_ctx_t * ceic, buffer_desc_t * buf, int ice, db_buf_t org_ce, int start, int split_at)
{
  dk_set_t l_ce = NULL, l_ce_op = NULL;
  int prev_checked = 0;
  dk_set_t ck_set = NULL;
  dtp_t pre_dc_dtp;
  it_cursor_t *itc = ceic->ceic_itc;
  int op = 0 == start ? CE_REPLACE : CE_INSERT;
  compress_state_t *cs = ceic->ceic_top_ceic->ceic_cs;
  db_buf_t last_ce;
  int last_ce_len;
  col_pos_t cpo;
  data_col_t dc;
  int n_values, n_in_ce;
  memset (&cpo, 0, sizeof (cpo));
  cpo.cpo_itc = itc;
  cpo.cpo_string = ceic_ice_string (ceic, buf, ice);
  cpo.cpo_bytes = ce_total_bytes (cpo.cpo_string);
  n_in_ce = ce_n_values (cpo.cpo_string);
  n_values = n_in_ce - start;
  memset (&dc, 0, sizeof (dc));
  dc.dc_mp = ceic->ceic_mp;
  dc.dc_n_places = n_values;
  ceic->ceic_mp->mp_block_size = 128 * 1024;
  if (cs)
    {
      cs->cs_n_values = 0;
      cs->cs_prev_ready_ces = cs->cs_ready_ces = NULL;
      cs_reset (cs);
      cs_clear (cs);
    }
  else
    {
      ceic->ceic_top_ceic->ceic_cs = cs = (compress_state_t *) mp_alloc_box_ni (dc.dc_mp, sizeof (compress_state_t), DV_BIN);
      memset (cs, 0, sizeof (compress_state_t));
      cs_init (cs, dc.dc_mp, 0, MIN (2000, n_values + ceic->ceic_n_for_ce));
    }
  ceic_init_dc (ceic, &dc, org_ce);
  dc.dc_values = (db_buf_t) mp_alloc_box_ni (ceic->ceic_mp, sizeof (int64) * n_values, DV_BIN);
  ceic_cs_flags (ceic, cs, dc.dc_dtp);
  cs->cs_exclude = dbf_compress_mask;
  cpo.cpo_dc = &dc;
  cpo.cpo_value_cb = ce_result;
  cpo.cpo_ce_op = DV_ANY == dc.dc_dtp ? NULL : ce_op[ce_op_decode * 2];
  cpo.cpo_pm = NULL;
  pre_dc_dtp = dc.dc_dtp;
  cs_decode (&cpo, start, n_in_ce);
  if (dc.dc_n_values != dc.dc_n_places)
    GPF_T1 ("bad cs decode in merge ins");
  if (dc.dc_dtp != pre_dc_dtp)
    GPF_T1 ("must not do dc heterogenous in merge insert");
  cs->cs_for_test = dbf_ce_comp_check;
  SET_THR_TMP_POOL (ceic->ceic_mp);
  if (CS_INT_ONLY == cs->cs_all_int)
    ce_merge_int (ceic, cs, &dc, itc->itc_row_of_ce + start, split_at);
  else
  ce_merge (ceic, cs, &dc, itc->itc_row_of_ce + start, split_at);
  if (cs->cs_n_values)
    {
  cs_best (cs, &last_ce, &last_ce_len);
  mp_set_push (cs->cs_mp, &cs->cs_ready_ces, (void *) last_ce);
    }
  SET_THR_TMP_POOL (NULL);
  cs_reset_check (cs);
  cs_distinct_ces (cs);
  DO_SET (db_buf_t, prev_ce, &cs->cs_ready_ces)
  {
    mp_conc1_l (ceic->ceic_mp, &ceic->ceic_delta_ce_op, (void *) (ptrlong) (op | (itc->itc_nth_ce + (start ? 2 : 0))), &l_ce_op);
    prev_ce = ce_skip_gap (prev_ce);
    mp_conc1_l (ceic->ceic_mp, &ceic->ceic_delta_ce, (void *) prev_ce, &l_ce);
    op = CE_INSERT;
    if (dbf_ce_comp_check)
      ce_comp_check (cs, prev_ce, &ck_set, &prev_checked);
  }
  END_DO_SET ();
}


caddr_t
mp_any_box (mem_pool_t * mp, db_buf_t dv)
{
  caddr_t box;
  int l;
  DB_BUF_TLEN (l, *dv, dv);
  box = mp_alloc_box (mp, l + 1, DV_STRING);
  memcpy (box, dv, l);
  box[l] = 0;
  return box;
}


dk_set_t
ce_right (ce_ins_ctx_t * ceic, db_buf_t org_ce, int start, int n_values)
{
  dk_set_t res = NULL, l_ce;
  compress_state_t cs;
  db_buf_t last_ce;
  int last_ce_len, inx;
  col_pos_t cpo;
  data_col_t dc;
  memset (&cpo, 0, sizeof (cpo));
  cpo.cpo_itc = ceic->ceic_itc;
  cpo.cpo_string = org_ce;
  cpo.cpo_bytes = ce_total_bytes (cpo.cpo_string);
  if (-1 == n_values)
    n_values = ce_n_values (cpo.cpo_string);
  memset (&dc, 0, sizeof (dc));
  dc.dc_mp = ceic->ceic_mp;
  dc.dc_sqt.sqt_dtp = DV_ANY;
  dc.dc_type = DCT_FROM_POOL;
  dc.dc_values = (db_buf_t) mp_alloc_box_ni (dc.dc_mp, (n_values - start) * sizeof (caddr_t), DV_BIN);
  dc.dc_n_places = n_values - start;
  cpo.cpo_dc = &dc;
  cpo.cpo_value_cb = ce_result;
  cs_init (&cs, dc.dc_mp, 0, n_values);
  ceic_cs_flags (ceic, &cs, 0);
  cs.cs_exclude = dbf_compress_mask;
  cpo.cpo_ce_op = NULL;
  cpo.cpo_pm = NULL;
  cs_decode (&cpo, start, n_values);
  SET_THR_TMP_POOL (ceic->ceic_mp);
  for (inx = 0; inx < n_values - start; inx++)
    cs_compress (&cs, ((caddr_t *) dc.dc_values)[inx]);
  if (cs.cs_n_values)
    {
  cs_best (&cs, &last_ce, &last_ce_len);
  mp_set_push (ceic->ceic_mp, &cs.cs_ready_ces, (void *) last_ce);
    }
  SET_THR_TMP_POOL (NULL);
  cs_distinct_ces (&cs);
  l_ce = NULL;
  DO_SET (db_buf_t, prev_ce, &cs.cs_ready_ces)
  {
    mp_conc1_l (ceic->ceic_mp, &res, (void *) prev_ce, &l_ce);
  }
  END_DO_SET ();
  cs_free_allocd_parts (&cs);
  return res;
}


ce_ins_ctx_t *
ceic_col_ceic (ce_ins_ctx_t * ceic)
{
  ce_ins_ctx_t *new_ceic;
  if (!ceic->ceic_mp)
    ceic->ceic_mp = mem_pool_alloc ();
  new_ceic = (ce_ins_ctx_t *) mp_alloc (ceic->ceic_mp, sizeof (ce_ins_ctx_t));
  new_ceic->ceic_mp = ceic->ceic_mp;
  new_ceic->ceic_is_ac = ceic->ceic_is_ac;
  new_ceic->ceic_is_cpt_restore = ceic->ceic_is_cpt_restore;
  new_ceic->ceic_nth_col = ceic->ceic_nth_col;
  new_ceic->ceic_itc = ceic->ceic_itc;
  new_ceic->ceic_end_map_pos = ceic->ceic_end_map_pos;
  new_ceic->ceic_col = ceic->ceic_col;
  new_ceic->ceic_top_ceic = ceic;
  return new_ceic;
}


void
ce_split (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic_ret, buffer_desc_t * buf, int ice, int split_at)
{
  /* init col ceic if needed make a right side ce in the col ceic, truncate the org ce */
  ce_ins_ctx_t *col_ceic = *col_ceic_ret;
  it_cursor_t *itc = ceic->ceic_itc;
  int first_insert = itc->itc_ranges[itc->itc_ce_first_range].r_first - itc->itc_row_of_ce;
  db_buf_t ce = BUF_ROW (buf, ice);
  if (!col_ceic)
    *col_ceic_ret = col_ceic = ceic_col_ceic (ceic);
  if (buf && first_insert > split_at && ce_can_truncate (ce))
    {
      ceic_merge_insert (col_ceic, buf, ice, ce, split_at, -1);
      ce_truncate (buf, ice, split_at);
      return;
    }
  ceic_merge_insert (col_ceic, buf, ice, ce, 0, split_at);
}


db_buf_t
ce_extend (ce_ins_ctx_t * ceic, ce_ins_ctx_t ** col_ceic_ret, db_buf_t ce, db_buf_t * ce_first_ret, int new_bytes, int new_values,
    int *space_after_ret)
{
  /* return a pointer to the ce where the ce is n  values and n bytes longer.  Grow inb place or alloc from row ceic */
  int space_after = *space_after_ret, extra;
  dtp_t ce_type, flags;
  dk_set_t last;
  db_buf_t ce_first;
  int fill = 0, bytes_delta;
  db_buf_t new_ce;
  dtp_t tmp_head[10];
  ce_ins_ctx_t *col_ceic;
  int header_inc = 0;
  int n_values, n_bytes, hl, new_ce_len;
  ce_head_info (ce, &n_bytes, &n_values, &ce_type, &flags, &hl);
  ce_first = ce + hl;
  cs_append_header (tmp_head, &fill, flags & ~CE_IS_SHORT, new_values, new_bytes);
  header_inc = fill - hl;
  if (space_after >= (new_bytes - n_bytes) + header_inc)
    {
      /* space right there. */
      *space_after_ret -= (new_bytes - n_bytes) + header_inc;
      if (header_inc)
	{
	  memmove_16 (ce_first + header_inc, ce_first, n_bytes);
	  memcpy (ce, tmp_head, fill);
	  ce_first += header_inc;
	}
      else
	memcpy (ce, tmp_head, fill);
      bytes_delta = (header_inc + new_bytes - n_bytes);
      cs_write_gap (ce_first + new_bytes, space_after - bytes_delta);
      *ce_first_ret = ce_first;
      return ce;
    }
  col_ceic = *col_ceic_ret;
  if (!col_ceic)
    {
      col_ceic = *col_ceic_ret = ceic_col_ceic (ceic);
    }
  if (CE_VEC == ce_type || CE_DICT == ce_type)
    extra = 0;
  else
    extra = 50;
  *space_after_ret = extra;
  new_ce_len = new_bytes + fill + extra;
  new_ce = (db_buf_t) mp_alloc_box_ni (col_ceic->ceic_mp, new_ce_len, DV_BIN);
  last = dk_set_last (col_ceic->ceic_delta_ce);
  if (last && (void *) ce == last->data)
    last->data = (void *) new_ce;
  else
    {
      mp_conc1 (col_ceic->ceic_mp, &col_ceic->ceic_delta_ce_op, (void *) (ptrlong) (ceic->ceic_itc->itc_nth_ce | CE_REPLACE));
      mp_conc1 (col_ceic->ceic_mp, &col_ceic->ceic_delta_ce, (void *) new_ce);
    }
  memcpy (new_ce, tmp_head, fill);
  memcpy_16 (new_ce + fill, ce_first, n_bytes);
  cs_write_gap (new_ce + fill + new_bytes, extra);
  *ce_first_ret = new_ce + fill;
  return new_ce;
}

extern int64 trap_value[4];
int n_trap_vals = 0;

void
ce_ins_trap (ce_ins_ctx_t * ceic)
{
#if 1
  int inx;
  it_cursor_t *itc = ceic->ceic_itc;
  if (!n_trap_vals)
    return;
  for (inx = itc->itc_ce_first_set; inx < itc->itc_ce_first_set + ceic->ceic_n_for_ce; inx++)
    {
      int n_hits = 0, col, row = itc->itc_param_order[inx];
      for (col = 0; col < 4; col++)
	{
	  data_col_t *dc;
	  if (itc->itc_search_par_fill <= col)
	    break;
	  if (0x80000000000 == trap_value[col])
	    continue;
	  dc = ITC_P_VEC (itc, col);
	  if (!dc)
	    continue;
	  if (DV_ANY == dc->dc_dtp)
	    {
	      dtp_t dtp;
	      int64 v = dv_int (((db_buf_t *) dc->dc_values)[row], &dtp);
	      if (trap_value[col] == v)
		n_hits++;
	    }
	  else
	    {
	      if (trap_value[col] == ((int64 *) dc->dc_values)[row])
		n_hits++;
	    }
	}
      if (n_hits >= n_trap_vals)
	bing ();
    }
#endif
}


void
ceic_consec_inserts (ce_ins_ctx_t * ceic, buffer_desc_t * buf)
{
  /* crude trick to recognize asc single inserts or small batches. Record the row no in seg of last insert.  If the next starts one after that it is asc.  This could be the next row in another seg but this will not be recognized and is not very probable.  Autocompact will fic such errors.  Large consec batch is consec, any non-consec batch is non consec */
  it_cursor_t *itc = ceic->ceic_itc;
  int first = itc->itc_ce_first_range, prev, last_pos;
  int inx, last = first + ceic->ceic_n_for_ce, is_first = 1;
  for (inx = first; inx < last; inx++)
    {
      if (is_first)
	{
	  prev = itc->itc_ranges[inx].r_first;
	  is_first = 0;
	}
      else if (prev != itc->itc_ranges[inx].r_first)
	{
	  SHORT_SET (buf->bd_buffer + DP_RIGHT_INSERTS, 0);
	  return;		/* not consecutive */
	}
    }
  last_pos = SHORT_REF (buf->bd_buffer + DP_LAST_INSERT);
  if (ceic->ceic_n_for_ce < 10)
    {
      if (last_pos + 1 == itc->itc_ranges[first].r_first)
	{
	  int right_ins = SHORT_REF (buf->bd_buffer + DP_RIGHT_INSERTS);
	  SHORT_SET (buf->bd_buffer + DP_RIGHT_INSERTS, ceic->ceic_n_for_ce + right_ins);
	}
      else
	SHORT_SET (buf->bd_buffer + DP_RIGHT_INSERTS, 0);
      SHORT_SET (buf->bd_buffer + DP_LAST_INSERT, itc->itc_ranges[last - 1].r_first);
    }
  else
    {
      SHORT_SET (buf->bd_buffer + DP_LAST_INSERT, itc->itc_ranges[last - 1].r_first);
      SHORT_SET (buf->bd_buffer + DP_RIGHT_INSERTS, ceic->ceic_n_for_ce);
    }
}


void
ce_insert (ce_ins_ctx_t * ceic, col_data_ref_t * cr, int page_in_cr, int ice)
{
  buffer_desc_t *buf = cr->cr_pages[page_in_cr].cp_buf;
  int space_after, initial_len;
  db_buf_t ce, initial_ce;
  ce_ins_ctx_t **col_ceic = &cr->cr_pages[page_in_cr].cp_ceic;
  int split_at = -1;
  ITC_DELTA (ceic->ceic_itc, buf);
  ce = BUF_ROW (buf, ice);
  initial_ce = ce;
  initial_len = ce_total_bytes (ce);
  space_after = ce_space_after (buf, ce);
  if (0 == ceic->ceic_nth_col)
    {
      ceic_consec_inserts (ceic, buf);
      ceic->ceic_itc->itc_col_right_ins = SHORT_REF (buf->bd_buffer + DP_RIGHT_INSERTS) > 10;
    }
  ceic->ceic_org_buf = buf;
  if (ceic->ceic_itc->itc_ce_first_range + ceic->ceic_n_for_ce > ceic->ceic_itc->itc_range_fill)
    GPF_T1 ("going to insert more values than there are ranges");
  ce_ins_trap (ceic);
  ce = ce_insert_1 (ceic, col_ceic, ce, space_after, &split_at, ice);
  ceic->ceic_org_buf = NULL;
  if (-1 != split_at)
    {
      ce_split (ceic, col_ceic, buf, ice, split_at);
      return;
    }
  if (ce == initial_ce)
    {
      page_map_t *pm = buf->bd_content_map;
      int new_len = ce_total_bytes (ce);
      pm->pm_bytes_free -= new_len - initial_len;
      pm->pm_entries[ice + 1] += ceic->ceic_n_for_ce - ceic->ceic_n_updates;
      if (pm->pm_filled_to == (ce - buf->bd_buffer) + initial_len)
	pm->pm_filled_to += new_len - initial_len;
    }
}


void
cr_insert (ce_ins_ctx_t * ceic, buffer_desc_t * buf, col_data_ref_t * cr)
{
  it_cursor_t *itc = ceic->ceic_itc;
  int inx, set_save;
  int place, nth_range = 0;
  int ice, itc_set_save = itc->itc_set;
  int row_of_ce = 0;
  int is_key = ceic->ceic_nth_col < itc->itc_insert_key->key_n_significant;
  itc->itc_ce_first_set = itc->itc_set;
  for (inx = 0; inx < cr->cr_n_pages; inx++)
    {
      page_map_t *pm = cr->cr_pages[inx].cp_map;
      int is_upd = itc->itc_ranges[nth_range].r_end != itc->itc_ranges[nth_range].r_first;	/*in upd of last of seg, end will be col no row, so normalize to bool */
      place = itc->itc_ranges[nth_range].r_first;
      for (ice = 0 == inx ? cr->cr_first_ce * 2 : 0; ice < pm->pm_count; ice += 2)
	{
	  int n_in_ce = pm->pm_entries[ice + 1];
	  if (place >= row_of_ce && place + is_upd <= row_of_ce + n_in_ce)
	    {
	      int ira, n_inserts = 1, n_updates = 0;
	      itc->itc_row_of_ce = row_of_ce;
	      if (is_upd)
		n_updates++;
	      /*prefetch the ce here, will be touched shortly */
	      __builtin_prefetch (cr->cr_pages[inx].cp_buf->bd_buffer + pm->pm_entries[ice]);
	      for (ira = nth_range + 1; ira < itc->itc_range_fill; ira++)
		{
		  is_upd = itc->itc_ranges[ira].r_end != itc->itc_ranges[ira].r_first;
		  if (itc->itc_ranges[ira].r_first + is_upd <= row_of_ce + n_in_ce)
		    {
		      n_inserts++;
		      if (itc->itc_ranges[ira].r_first != itc->itc_ranges[ira].r_end)
			n_updates++;
		    }
		  else
		    break;
		}
	      ceic->ceic_n_for_ce = n_inserts;
	      ceic->ceic_itc->itc_nth_ce = ice;
	      itc->itc_ce_first_range = nth_range;
	      ceic->ceic_n_updates = n_updates;
	      set_save = itc->itc_ce_first_set;
	      if (!is_key || n_inserts != n_updates)
		ce_insert (ceic, cr, inx, ice);
	      nth_range += n_inserts;
	      if (nth_range >= itc->itc_range_fill)
		goto done;
	      itc->itc_ce_first_set = set_save + n_inserts;
	      place = itc->itc_ranges[nth_range].r_first;
	    }
	  row_of_ce += n_in_ce;
	}
    }
done:
  if (nth_range < itc->itc_range_fill)
    GPF_T1 ("Too few rows in seg for insert");
  itc->itc_set = itc_set_save;
}


int
cr_new_size (col_data_ref_t * cr, int *bytes_ret)
{
  int inx, minx, n = 0, bytes = 0, n_ces = 0;
  for (inx = 0; inx < cr->cr_n_pages; inx++)
    {
      dk_set_t delta_save, op_save;
      page_map_t *pm = cr->cr_pages[inx].cp_map;
      ce_ins_ctx_t *col_ceic = cr->cr_pages[inx].cp_ceic;
      db_buf_t delta_ce;
      int delta_op = 0, delta_row = -2;
      if (col_ceic)
	{
	  op_save = col_ceic->ceic_delta_ce_op;
	  delta_save = col_ceic->ceic_delta_ce;
	  CEIC_NEXT_OP (col_ceic, delta_ce, delta_op, delta_row);
	}
      if (!col_ceic && inx > 0 && inx < cr->cr_n_pages - 1)
	{
	  n_ces += pm->pm_count / 2;
	  bytes += PAGE_DATA_SZ - pm->pm_bytes_free;
	  for (minx = 0; minx < pm->pm_count; minx += 2)
	    n += pm->pm_entries[minx + 1];
	  continue;
	}
      for (minx = 0 == inx ? cr->cr_first_ce * 2 : 0;; minx += 2)
	{
	  int any_replace = 0;
	  db_buf_t ce = cr->cr_pages[inx].cp_string + pm->pm_entries[minx];
	  while (delta_row == minx)
	    {
	      if (CE_REPLACE == delta_op || CE_DELETE == delta_op)
		any_replace = 1;
	      if (CE_DELETE != delta_op)
		{
		  if (bytes_ret)
		    bytes += ce_total_bytes (delta_ce);
	      n += ce_n_values (delta_ce);
		}
	      CEIC_NEXT_OP (col_ceic, delta_ce, delta_op, delta_row);
	    }
	  if (minx >= pm->pm_count)
	    break;
	  if (n_ces++ == cr->cr_n_ces)
	    break;
	  if (!any_replace)
	    {
	      if (bytes_ret)
		bytes += ce_total_bytes (ce);
	      n += pm->pm_entries[minx + 1];
	    }
	}
      if (col_ceic)
	{
	  if (-2 != delta_row)
	    GPF_T1 ("uncounted delta ce");
	  col_ceic->ceic_delta_ce_op = op_save;
	  col_ceic->ceic_delta_ce = delta_save;
	}
    }
  if (bytes_ret)
    *bytes_ret = bytes;
  return n;
}



int32 col_seg_max_bytes = 16 * PAGE_DATA_SZ;
int32 col_seg_max_rows = 2 * 8192;
extern long ac_col_pages_in;
extern long ac_col_pages_out;


buffer_desc_t *
ceic_next_buf (ce_ins_ctx_t * ceic)
{
  int inx;
  buffer_desc_t *buf;
  col_data_ref_t *cr = ceic->ceic_cr;
  if (ceic->ceic_is_ac)
    {
      ceic->ceic_itc->itc_insert_key->key_ac_out++;
    ac_col_pages_out++;
    }
  for (inx = 0; inx < cr->cr_n_pages; inx++)
    {
      if ((buf = cr->cr_pages[inx].cp_buf))
	{
	  cr->cr_pages[inx].cp_buf = NULL;
	  ceic->ceic_near = buf->bd_page;
	  if (!buf->bd_is_write)
	    GPF_T1 ("buf not in write access in ceic split cr");
	  ITC_DELTA (ceic->ceic_itc, buf);
	  break;
	}
    }
  if (!buf)
    buf = it_new_col_page (ceic->ceic_itc->itc_tree, ceic->ceic_near, ceic->ceic_itc, ceic->ceic_col);
  ceic->ceic_out_buf = buf;
  mp_set_push (ceic->ceic_mp, &ceic->ceic_dps, DP_ADDR2VOID (buf->bd_page));
  return buf;
}


void
ceic_feed_flush (ce_ins_ctx_t * ceic)
{
  int n = dk_set_length (ceic->ceic_batch);
  int ctr = 0, fill = DP_DATA;
  int spacing = (PAGE_DATA_SZ - ceic->ceic_batch_bytes) / n;
  buffer_desc_t *buf = ceic->ceic_out_buf;
  page_map_t *pm = buf->bd_content_map;
  if (pm->pm_size != PM_SIZE (n * 2))
    {
      buf->bd_content_map->pm_count = 0;
      map_resize (buf, &buf->bd_content_map, PM_SIZE (n * 2));
    }
  pm = buf->bd_content_map;
  pm->pm_count = n * 2;
  pm->pm_bytes_free = PAGE_DATA_SZ;
  ceic->ceic_batch = dk_set_nreverse (ceic->ceic_batch);
  DO_SET (db_buf_t, ce, &ceic->ceic_batch)
  {
    int len = ce_total_bytes (ce);
    pm->pm_entries[ctr * 2] = fill;
    pm->pm_entries[(ctr * 2) + 1] = ce_n_values (ce);
    pm->pm_bytes_free -= len;
    memcpy_16 (buf->bd_buffer + fill, ce, len);
    fill += len;
    pm->pm_filled_to = fill;
    if (ctr == n - 1)
      cs_write_gap (buf->bd_buffer + fill, PAGE_SZ - fill);
    else
      cs_write_gap (buf->bd_buffer + fill, spacing);
    fill += spacing;
    ctr++;
  }
  END_DO_SET ();
  page_leave_outside_map (buf);
  ceic->ceic_batch = NULL;
  ceic->ceic_batch_bytes = 0;
}


void
ceic_feed (ce_ins_ctx_t * ceic, db_buf_t ce, int row)
{
  int bytes = ce_total_bytes (ce), spacing;
  spacing = (row != -1 && bytes < 4090) ? 50 : 0;
  if (ceic->ceic_batch_bytes + bytes > PAGE_DATA_SZ - spacing || ceic->ceic_last_nth >= PM_MAX_CES - 1)
    {
      /* leave some space at end but only if dealing with ces of the segment itself.  If a ce from before the seg, must fit where it was, thus apply no margin, else the seg before could acquire a new page that would be unrefd from the previous col ref string */
      ceic_feed_flush (ceic);
      if (0 == row)
	{
	  /* if first ce of seg causes move to new page then the previous page is not part of the seg and should not be mentioned in the col string */
	  ceic->ceic_dps = NULL;
	}
      ceic_next_buf (ceic);
    }
  ceic->ceic_last_nth = dk_set_length (ceic->ceic_batch);
  ceic->ceic_last_dp = ceic->ceic_out_buf->bd_page;
  mp_set_push (ceic->ceic_mp, &ceic->ceic_batch, (void *) ce);
  ceic->ceic_batch_bytes += bytes;
  if (ceic->ceic_batch_bytes > PAGE_DATA_SZ)
    GPF_T1 ("overflow in ceic_batch_feed");
  if (ceic->ceic_after_split)
    {
      ceic->ceic_after_split = 0;
      ceic->ceic_first_ce = dk_set_length (ceic->ceic_batch) - 1;
      ceic->ceic_dps = mp_cons (ceic->ceic_mp, (void *) (ptrlong) ceic->ceic_out_buf->bd_page, NULL);
    }
}



void
ceic_set_split_reloc (ce_ins_ctx_t * ceic, db_buf_t ce)
{
  ce_new_pos_t *cep;
  for (cep = ceic->ceic_reloc; cep; cep = cep->cep_next)
    {
      if (cep->cep_org_ce == ce)
	{
	  cep->cep_new_dp = ceic->ceic_last_dp;
	  cep->cep_new_nth = ceic->ceic_last_nth;
	  return;
	}
    }
  GPF_T1 ("should have had a ce reloc record");
}

void
ceic_set_rd (ce_ins_ctx_t * ceic, int nth, db_buf_t ce)
{
  row_delta_t *rd;
  caddr_t val;
  dbe_key_t *key = ceic->ceic_itc->itc_insert_key;
  if (ceic->ceic_nth_col >= key->key_n_significant)
    return;
  val = ceic_ce_value (ceic, ce, 0);
  rd = ceic->ceic_rds[nth + 1];
  rd->rd_values[key->key_part_in_layout_order[ceic->ceic_nth_col]] = val;
}

void
ceic_set_top_col (ce_ins_ctx_t * ceic, int nth_split, int n_ces)
{
  dbe_key_t *key = ceic->ceic_itc->itc_insert_key;
  row_delta_t *rd = ceic->ceic_rds[nth_split];
  int n_dps = dk_set_length (ceic->ceic_dps);
  int sf = CPP_DP;
  db_buf_t str = (db_buf_t) mp_alloc_box_ni (ceic->ceic_mp, sizeof (dp_addr_t) * n_dps + CPP_DP + 1, DV_STRING);
  str[0] = DV_BLOB;
  SHORT_SET_NA (str + CPP_FIRST_CE, ceic->ceic_first_ce);
  SHORT_SET_NA (str + CPP_N_CES, n_ces);
  ceic->ceic_dps = dk_set_nreverse (ceic->ceic_dps);
  DO_SET (ptrlong, dp, &ceic->ceic_dps)
  {
    LONG_SET_NA (str + sf, dp);
    sf += sizeof (dp_addr_t);
  }
  END_DO_SET ();
  rd->rd_values[key->key_n_significant + ceic->ceic_nth_col] = (caddr_t) str;
  ceic->ceic_after_split = 1;
}


void
ceic_del_unused (ce_ins_ctx_t * ceic, col_data_ref_t * cr)
{
  int inx;
  for (inx = 0; inx < cr->cr_n_pages; inx++)
    {
      buffer_desc_t *buf = cr->cr_pages[inx].cp_buf;
      if (buf)
	{
	  ITC_IN_KNOWN_MAP (ceic->ceic_itc, buf->bd_page);
	  itc_delta_this_buffer (ceic->ceic_itc, buf, DELTA_MAY_LEAVE);
	  it_free_page (ceic->ceic_itc->itc_tree, buf);
	  ITC_LEAVE_MAP_NC (ceic->ceic_itc);
	  cr->cr_pages[inx].cp_buf = NULL;
	}
    }
}


void
ceic_split_layout (ce_ins_ctx_t * ceic, col_data_ref_t * cr, int *split, int n_ways)
{
  dk_set_t iter, next;
  int n_values, nth_split = 0, after_limit = 0;
  int ce_ctr = 0;
  int n_ces = 0;
  int row = -1;
  ceic->ceic_col = (dbe_column_t *) dk_set_nth (ceic->ceic_itc->itc_insert_key->key_parts, ceic->ceic_nth_col);
  ceic->ceic_first_ce = cr->cr_first_ce;
  ceic_next_buf (ceic);
  for (iter = ceic->ceic_all_ces; iter; iter = next)
    {
      db_buf_t ce = (db_buf_t) iter->data;
      next = iter->next;
      if (ce_ctr++ == cr->cr_first_ce)
	{
	  row = 0;
	  ceic_set_rd (ceic, -1, ce);
	  ceic->ceic_after_split = 1;
	}
      n_values = ce_n_values (ce);
      if (nth_split < n_ways && row == split[nth_split])
	{
	  ceic_set_top_col (ceic, nth_split, n_ces);
	  ceic_set_rd (ceic, nth_split, ce);
	  n_ces = 0;
	  nth_split++;
	}
      if (row != -1 && nth_split < n_ways && row < split[nth_split] && split[nth_split] < row + n_values)
	{
	  dk_set_t right = ce_right (ceic, ce, split[nth_split] - row, -1);
	  dk_set_t left = ce_right (ceic, ce, 0, split[nth_split] - row);
	  ceic_set_rd (ceic, nth_split, (db_buf_t) right->data);
	  DO_SET (db_buf_t, left_ce, &left)
	  {
	    ceic_feed (ceic, left_ce, row);
	    n_ces++;
	    row += ce_n_values (left_ce);
	  }
	  END_DO_SET ();
	  ceic_set_top_col (ceic, nth_split, n_ces);
	  n_ces = 0;
	  nth_split++;
	  dk_set_conc (right, next);
	  next = right;
	  continue;
	}
      if (ce == ceic->ceic_limit_ce)
	{
	  ceic_set_top_col (ceic, nth_split, n_ces);
	  after_limit = 1;
	}
      ceic_feed (ceic, ce, row);
      if (-1 != row)
	row += n_values;
      if (after_limit)
	ceic_set_split_reloc (ceic, ce);
      else if (ce_ctr > cr->cr_first_ce)
	n_ces++;
    }
  if (!after_limit)
    ceic_set_top_col (ceic, nth_split, n_ces);
  ceic_feed_flush (ceic);
  ceic_del_unused (ceic, cr);
}


row_delta_t *
ceic_find_row_rd (ce_ins_ctx_t * ceic, int map_pos)
{
  row_delta_t *rd = NULL;
  row_delta_t **rds = ceic->ceic_rds;
  if (rds)
    {
      int inx;
      DO_BOX (row_delta_t *, rd2, inx, rds)
      {
	if (rd2->rd_map_pos == map_pos && RD_INSERT != rd2->rd_op)
	  {
	    rd = rd2;
	    break;
	  }
      }
      END_DO_BOX;
    }
  return rd;
}


row_delta_t *
ceic_row_rd (ce_ins_ctx_t * ceic, int map_pos)
{
  int new_rd = 0, inx;
  row_delta_t *rd = ceic_find_row_rd (ceic, map_pos);
  if (!rd)
    {
      it_cursor_t *itc = ceic->ceic_itc;
      dbe_key_t *key = itc->itc_insert_key;
      rd = (row_delta_t *) mp_alloc_box_ni (ceic->ceic_mp, sizeof (row_delta_t), DV_BIN);
      memset (rd, 0, sizeof (*rd));
      rd->rd_temp = (db_buf_t) mp_alloc_box_ni (ceic->ceic_mp, MAX_ROW_BYTES + 1, DV_BIN);
      rd->rd_temp_max = MAX_ROW_BYTES;
      rd->rd_allocated = RD_AUTO;
      rd->rd_map_pos = map_pos;
      rd->rd_keep_together_pos = map_pos;
      rd->rd_keep_together_dp = itc->itc_page;
      rd->rd_values = (caddr_t *) mp_alloc (ceic->ceic_mp, key->key_n_parts * sizeof (caddr_t));
      rd->rd_upd_change = (dbe_col_loc_t **) mp_alloc (ceic->ceic_mp, key->key_n_parts * sizeof (caddr_t));
      page_row_bm (itc->itc_buf, map_pos, rd, RO_ROW, NULL);
      rd->rd_op = RD_UPDATE_LOCAL;
      new_rd = 1;
    }
  if (!ceic->ceic_rds)
    {
      ceic->ceic_rds = (row_delta_t **) mp_alloc_box (ceic->ceic_mp, sizeof (caddr_t), DV_BIN);
      ceic->ceic_rds[0] = rd;
    }
  else if (new_rd)
    {
      row_delta_t **old_rds = ceic->ceic_rds;
      DO_BOX (row_delta_t *, rd2, inx, ceic->ceic_rds)
      {
	if (RD_INSERT != rd2->rd_op && rd2->rd_map_pos > rd->rd_map_pos)
	  break;
      }
      END_DO_BOX;
      ceic->ceic_rds = (row_delta_t **) mp_alloc_box (ceic->ceic_mp, box_length (ceic->ceic_rds) + sizeof (caddr_t), DV_BIN);
      memcpy (ceic->ceic_rds, old_rds, inx * sizeof (caddr_t));
      memcpy (ceic->ceic_rds + inx + 1, old_rds + inx, sizeof (caddr_t) * (BOX_ELEMENTS (old_rds) - inx));
      ceic->ceic_rds[inx] = rd;
      DO_BOX (row_delta_t *, rd2, inx, ceic->ceic_rds) if (RD_INSERT != rd2->rd_op && RD_DELETE != rd2->rd_op)
	rd2->rd_op = RD_UPDATE;
      END_DO_BOX;
    }
  return rd;
}


void
ceic_upd_rd (ce_ins_ctx_t * ceic, int map_pos, int nth_col, db_buf_t str)
{
  row_delta_t *rd = ceic_row_rd (ceic, map_pos);
  dbe_key_t *key = ceic->ceic_itc->itc_insert_key;
  if (RD_DELETE == rd->rd_op && str)
    GPF_T1 ("a seg does empty on one col but not another");
  if (!str)
    {
      rd->rd_op = RD_DELETE;
      return;
    }
  rd->rd_non_comp_len += box_col_len ((caddr_t) str) - box_col_len (rd->rd_values[key->key_n_significant + nth_col]);
  rd->rd_values[key->key_n_significant + nth_col] = (caddr_t) str;
  if (RD_UPDATE_LOCAL == rd->rd_op && rd->rd_upd_change)
    rd->rd_upd_change[key->key_n_significant + nth_col] = &key->key_row_var[nth_col];
}


db_buf_t
cr_1st_ce (col_data_ref_t * cr)
{
  buffer_desc_t *buf;
  ce_ins_ctx_t *page_ceic = cr->cr_pages[0].cp_ceic;
  int inx;
  if (page_ceic && page_ceic->ceic_all_ces)
    return (db_buf_t) dk_set_nth (page_ceic->ceic_all_ces, cr->cr_first_ce);
  for (inx = cr->cr_first_ce_page; inx < cr->cr_n_pages; inx++)
    {
      buf = cr->cr_pages[inx].cp_buf;
      if (buf)
	if (buf && 0 == inx)
	  return BUF_ROW (buf, cr->cr_first_ce * 2);
      if (buf)
	return BUF_ROW (buf, 0);
    }
  return NULL;
}


row_delta_t *
ceic_1st_changed (ce_ins_ctx_t * ceic)
{
  /* ins before 1st of seg or del of 1st of seg. The key in the leaf row must correspond to the new 1st row in the seg */
  it_cursor_t *itc = ceic->ceic_itc;
  dbe_key_t *key = itc->itc_insert_key;
  row_delta_t *rd = NULL;
  int inx = 0;
  if (0 != itc->itc_ranges[0].r_first)
    return NULL;
  if (!ceic->ceic_is_finalize && 0 != itc->itc_ranges[0].r_end)
    return NULL;		/* if coming from insert and range 1 long, this is update of dependent and does not affect the keys on the row-wise leaf page */
  if (ceic->ceic_is_finalize && COL_NO_ROW != itc->itc_ranges[0].r_end)
    return NULL;		/* a rb of dep update, keys not changed. */
  if (!ceic->ceic_mp)
    ceic->ceic_mp = mem_pool_alloc ();
  rd = ceic_row_rd (ceic, itc->itc_map_pos);
  if (RD_DELETE == rd->rd_op)
    return NULL;
  DO_SET (dbe_column_t *, col, &key->key_parts)
  {
    col_pos_t cpo;
    data_col_t dc;
    db_buf_t ce;
    col_data_ref_t *cr = itc->itc_col_refs[inx];
    caddr_t val = NULL;
    ce = cr_1st_ce (cr);
    if (!ce)
      {
	/* the whole seg is gone.  The row-level maintenance of correct leaf ptr will do the job */
	return NULL;
      }
    memset (&cpo, 0, sizeof (cpo));
    memset (&dc, 0, sizeof (data_col_t));
    itc->itc_n_matches = 0;
    cpo.cpo_itc = itc;
    cpo.cpo_string = ce;
    cpo.cpo_bytes = ce_total_bytes (ce);
    if (DV_ANY == col->col_sqt.sqt_dtp)
      {
	dc.dc_type = DCT_FROM_POOL;
	dc.dc_sqt.sqt_dtp = DV_ANY;
      }
    else
      dc.dc_type = DCT_BOXES | DCT_FROM_POOL;
    dc.dc_mp = ceic->ceic_mp;
    dc.dc_n_places = 1;
    dc.dc_values = (db_buf_t) & val;
    cpo.cpo_dc = &dc;
    cpo.cpo_value_cb = ce_result;
    cpo.cpo_ce_op = NULL;
    cpo.cpo_pm = NULL;
    cs_decode (&cpo, 0, 1);
    rd->rd_values[key->key_part_in_layout_order[inx]] = val;
    if (++inx == key->key_n_significant)
      break;
  }
  END_DO_SET ();
  rd->rd_op = RD_UPDATE;
  return rd;
}


db_buf_t
ce_copy (ce_ins_ctx_t * ceic, db_buf_t ce)
{
  int n = ce_total_bytes (ce);
  db_buf_t cp = (db_buf_t) mp_alloc (ceic->ceic_mp, n);
  memcpy_16 (cp, ce, n);
  return cp;
}


void
ceic_compress_break (ce_ins_ctx_t * ceic, db_buf_t * imm_ret)
{
  compress_state_t *cs = ceic->ceic_cs;
  db_buf_t last_ce;
  int last_ce_len;
  if (!cs->cs_n_values && !cs->cs_ready_ces)
    return;
  if (cs->cs_n_values)
    {
      cs_best (cs, &last_ce, &last_ce_len);
      mp_set_push (cs->cs_mp, &cs->cs_ready_ces, (void *) last_ce);
    }
  cs_reset_check (cs);
  cs_distinct_ces (cs);
  ceic->ceic_all_ces = dk_set_conc (dk_set_nreverse (cs->cs_ready_ces), ceic->ceic_all_ces);
  cs->cs_n_values = 0;
  cs->cs_prev_ready_ces = cs->cs_ready_ces = NULL;
  cs_reset (cs);
  cs_clear (cs);
}


void
ceic_compress (ce_ins_ctx_t * ceic, db_buf_t ce, int from, int to)
{
  compress_state_t *cs = ceic->ceic_cs;
  db_buf_t dc_vals[1000];
  data_col_t dc;
  it_cursor_t *itc = ceic->ceic_itc;
  col_pos_t cpo;
  int i;
  memset (&cpo, 0, sizeof (cpo));
  cpo.cpo_itc = itc;
  cpo.cpo_string = ce;
  cpo.cpo_bytes = ce_total_bytes (cpo.cpo_string);
  memset (&dc, 0, sizeof (dc));
  dc.dc_mp = ceic->ceic_cs->cs_mp;
  dc.dc_values = (db_buf_t) dc_vals;
  dc.dc_n_places = sizeof (dc_vals) / sizeof (db_buf_t);
  ceic_init_dc (ceic, &dc, ce);
  ceic_cs_flags (ceic, ceic->ceic_cs, dc.dc_dtp);
  cs->cs_exclude = dbf_compress_mask;
  cpo.cpo_dc = &dc;
  cpo.cpo_value_cb = ce_result;
  cpo.cpo_ce_op = DV_ANY == dc.dc_dtp ? NULL : ce_op[ce_op_decode * 2];
  for (i = from; i < to; i += dc.dc_n_places)
    {
      int i2 = i + MIN (dc.dc_n_places, to - i);
      dc.dc_n_values = 0;
      cpo.cpo_pm = NULL;
      cs_decode (&cpo, i, i2);
      if (CS_INT_ONLY == cs->cs_all_int)
	cs_compress_int (cs, (int64 *) dc.dc_values, dc.dc_n_values);
      else
      ce_recompress (ceic, cs, &dc);
    }
}


int
ce_is_good (db_buf_t ce, dtp_t ce_flags, int ce_bytes, int ce_rows)
{
  float bs = (float) ce_bytes / ce_rows;
  switch (ce_flags & CE_TYPE_MASK)
    {
    case CE_RL_DELTA:
    case CE_BITS:
      return bs < 1.2;
    case CE_DICT:
      {
	int n_dist = CE_IS_SHORT & ce_flags ? ce[3] : ce[5];
	return n_dist <= 16 ? (bs < 0.7) : (bs < 1.4);
      }
    case CE_INT_DELTA:
      return bs < 2.2;
    case CE_VEC:
      return ce_bytes > 250;
    case CE_RL:
      return ce_rows > 500;
    default:
      return 0;
    }
}

int
ce_has_space (db_buf_t ce, dtp_t ce_flags, int ce_bytes, int ce_rows, int n)
{
  dtp_t ce_type = CE_TYPE_MASK & ce_flags;
  switch (ce_type)
    {
    case CE_RL_DELTA:
    case CE_BITS:
      return ce_rows + n < 1900;
    default:
      return 1;
    }
}


void
cr_unq_check (col_data_ref_t * cr)
{
  dp_addr_t dp;
  int inx;
  dk_hash_t *unq = NULL;
  for (inx = 0; inx < cr->cr_n_pages; inx++)
    {
      if (!cr->cr_pages[inx].cp_buf->bd_is_write)
	GPF_T1 ("buffer not in write access in col ac");
      if (1 >= cr->cr_n_pages)
	return;
      if (!unq)
	unq = hash_table_allocate (cr->cr_n_pages);
      dp = cr->cr_pages[inx].cp_buf->bd_page;
      if (gethash (DP_ADDR2VOID (dp), unq))
	GPF_T1 ("duplicate buf in ceic col ac batch");
      sethash (DP_ADDR2VOID (dp), unq, (void *) 1);
    }
  if (unq)
  hash_table_free (unq);
}


int enable_ac_double_check = 0;

void
ceic_ac_check (ce_ins_ctx_t * col_ceic, int nth_row, int is_last)
{
  int ck = 0;
  if (!enable_ac_double_check && !is_last)
    return;
  DO_SET (db_buf_t, ce, &col_ceic->ceic_all_ces) ck += ce_n_values (ce);
  END_DO_SET ();
  if (ck != nth_row)
    GPF_T1 ("different value ct after recompress");
}


int
cp_dp_cmp (const void *s1, const void *s2)
{
  col_page_t *cp1 = (col_page_t *) s1;
  col_page_t *cp2 = (col_page_t *) s2;
  return cp1->cp_buf->bd_page < cp2->cp_buf->bd_page ? -1 : 1;
}


ce_ins_ctx_t *
cr_recompress (ce_ins_ctx_t * ceic, col_data_ref_t * cr, int *splits, int n_splits, db_buf_t limit_ce)
{
  /* make a col ceic and run through all ces, recompress what does not look compressed and make final list of ces.  Then put the buffers in order of reuse */
  compress_state_t cs;
  ce_ins_ctx_t *col_ceic;
  int nth_row = 0, nth_split = 0, page, ce_ctr = 0, after_limit = 0, extra_rows = 0;
  db_buf_t immutable = NULL;
  col_ceic = ceic_col_ceic (ceic);
  col_ceic->ceic_col =
      sch_id_to_column (wi_inst.wi_schema, ceic->ceic_itc->itc_insert_key->key_row_var[ceic->ceic_nth_col].cl_col_id);
  col_ceic->ceic_cs = &cs;
  memset (&cs, 0, sizeof (compress_state_t));
  cs_init (&cs, col_ceic->ceic_mp, 0, 2000);
  SET_THR_TMP_POOL (col_ceic->ceic_mp);
  ceic_cs_flags (col_ceic, &cs, 0);
  ac_col_pages_in += cr->cr_n_pages;
  ceic->ceic_itc->itc_insert_key->key_ac_in += cr->cr_n_pages;
  cr->cr_pages[0].cp_ceic = col_ceic;
  col_ceic->ceic_cs = &cs;
  for (page = 0; page < cr->cr_n_pages; page++)
    {
      buffer_desc_t *buf = cr->cr_pages[page].cp_buf;
      page_map_t *pm = buf->bd_content_map;
      int ice;
      for (ice = 0; ice < pm->pm_count; ice += 2)
	{
	  db_buf_t ce = BUF_ROW (buf, ice);
	  /*if (28846 == buf->bd_page && 84 == ice) bing (); */
	  dtp_t ce_type, ce_flags;
	  int ce_rows, ce_bytes, hl;
	  if (ce == limit_ce)
	    {
	      ceic_compress_break (col_ceic, NULL);
	      after_limit = 1;
	    }
	  if (ce_ctr++ < cr->cr_first_ce || after_limit)
	    {
	      db_buf_t copy = ce_copy (col_ceic, ce);
	      mp_set_push (col_ceic->ceic_mp, &col_ceic->ceic_all_ces, (void *) copy);
	      if (after_limit && !col_ceic->ceic_limit_ce)
		col_ceic->ceic_limit_ce = copy;
	      if (after_limit)
		{
		  ce_new_pos_t *cep = (ce_new_pos_t *) mp_alloc (ceic->ceic_mp, sizeof (ce_new_pos_t));
		  cep->cep_old_dp = buf->bd_page;
		  cep->cep_org_ce = copy;
		  cep->cep_old_nth = ice / 2;
		  cep_append (col_ceic, cep);
		}
	      extra_rows += ce_n_values (copy);	/* rows in ces before and after the recompressed range, can be if doing a range of segs in mid page */
	      continue;
	    }
	  ce_head_info (ce, &ce_bytes, &ce_rows, &ce_type, &ce_flags, &hl);
	  ce_bytes += hl;
	  if (nth_split < n_splits && nth_row == splits[nth_split])
	    {
	      ceic_compress_break (col_ceic, &immutable);
	      nth_split++;
	    }
	  /* thre is no else here, the first condition can be true and the next also if a larger than seg ce starts at the split boundary. */
	  if (nth_split < n_splits && splits[nth_split] < ce_rows + nth_row)
	    {
	      int split_row = splits[nth_split] - nth_row;
	      int split_start = 0, row_of_ce = nth_row;
	      for (;;)
		{
		  ceic_compress (col_ceic, ce, split_start, split_row);
		  ceic_compress_break (col_ceic, &immutable);
		  nth_row += split_row - split_start;
		  ceic_ac_check (col_ceic, nth_row + extra_rows, 0);
		  nth_split++;
		  if (nth_split >= n_splits || splits[nth_split] >= nth_row + (ce_rows - split_row))
		    {
		      ceic_compress (col_ceic, ce, split_row, ce_rows);
		      nth_row += ce_rows - split_row;
		      goto next_ce;
		    }
		  split_start = split_row;
		  split_row = splits[nth_split] - row_of_ce;
		}
	    }

	  if (ce_is_good (ce, ce_flags, ce_bytes, ce_rows))
	    {
	      if (cs.cs_n_values && cs.cs_n_values < 100 && ce_has_space (ce, ce_flags, ce_bytes, ce_rows, 100))
		{
		  ceic_compress (col_ceic, ce, 0, ce_rows);
		}
	      else
		{
		  ceic_compress_break (col_ceic, NULL);
		  mp_set_push (col_ceic->ceic_mp, &col_ceic->ceic_all_ces, (void *) ce_copy (col_ceic, ce));
		  ceic_ac_check (col_ceic, nth_row + ce_rows + extra_rows, 0);
		}
	    }
	  else
	    ceic_compress (col_ceic, ce, 0, ce_rows);
	  nth_row += ce_rows;
	next_ce:;
	}
    }
  ceic_compress_break (col_ceic, NULL);
  col_ceic->ceic_all_ces = dk_set_nreverse (col_ceic->ceic_all_ces);
  ceic_ac_check (col_ceic, nth_row + extra_rows, 1);
  SET_THR_TMP_POOL (NULL);
  if (cr->cr_first_ce)
    qsort (&cr->cr_pages[1], cr->cr_n_pages - 1, sizeof (col_page_t), cp_dp_cmp);
  else
    qsort (cr->cr_pages, cr->cr_n_pages, sizeof (col_page_t), cp_dp_cmp);
  cr_unq_check (cr);
  return col_ceic;
}


#define ADD_CE \
{ \
  db_buf_t ce = cr->cr_pages[inx].cp_string + pm->pm_entries[r], copy; \
  copy = ce_copy (ceic, ce); \
  if (ce == limit_ce) \
    { \
      limit_ce = copy; \
      after_limit = 1; \
    } \
  mp_set_push (ceic->ceic_mp, &all_ces, (void*)copy); \
  if (after_limit) \
    { \
      ce_new_pos_t * cep = (ce_new_pos_t *)mp_alloc (ceic->ceic_mp, sizeof (ce_new_pos_t)); \
      cep->cep_old_dp = cr->cr_pages[inx].cp_buf->bd_page; \
      cep->cep_org_ce = copy; \
      cep->cep_old_nth = r / 2; \
      cep_append (ceic, cep); \
    } \
}


ce_ins_ctx_t *
cr_make_full_ceic (ce_ins_ctx_t * ceic, col_data_ref_t * cr, int *splits, int n_splits)
{
  int r, inx;
  dk_set_t all_ces = NULL;
  ce_ins_ctx_t *page_ceic, *ceic2;
  db_buf_t limit_ce = cr_limit_ce (cr, NULL);
  int after_limit = 0;
  if (ceic->ceic_is_ac)
    {
      return cr_recompress (ceic, cr, splits, n_splits, limit_ce);
    }
  ceic->ceic_first_ce = cr->cr_first_ce;
  for (inx = 0; inx < cr->cr_n_pages; inx++)
    {
      if ((page_ceic = cr->cr_pages[inx].cp_ceic))
	{
	  page_map_t *pm = cr->cr_pages[inx].cp_map;
	  db_buf_t delta;
	  int delta_row, delta_op, row = 0, ce_ctr = 0;
	  row = 0;
	  CEIC_NEXT_OP (page_ceic, delta, delta_op, delta_row);
	  for (r = 0; r < pm->pm_count; r += 2)
	    {
	      int any_replace = 0;
	      if (0 == inx && ce_ctr++ == cr->cr_first_ce)
		row = 0;
	      while (r == delta_row)
		{
		  if (CE_REPLACE == delta_op)
		    any_replace = 1;
		  mp_set_push (ceic->ceic_mp, &all_ces, (void *) delta);
		  CEIC_NEXT_OP (page_ceic, delta, delta_op, delta_row);
		}
	      if (!any_replace)
		ADD_CE;
	      if (-1 != row)
		row += pm->pm_entries[r + 1];
	    }
	  while (r == delta_row)
	    {
	      mp_set_push (ceic->ceic_mp, &all_ces, (void *) delta);
	      CEIC_NEXT_OP (page_ceic, delta, delta_op, delta_row);
	    }
	}
      else
	{
	  page_map_t *pm = cr->cr_pages[inx].cp_map;
	  for (r = 0; r < pm->pm_count; r += 2)
	    ADD_CE;
	}
    }
  ceic2 = ceic_col_ceic (ceic);
  ceic2->ceic_all_ces = dk_set_nreverse (all_ces);
  ceic2->ceic_limit_ce = limit_ce;
  ceic2->ceic_reloc = ceic->ceic_reloc;
  ceic->ceic_reloc = NULL;
  return ceic2;
}


int
ceic_relocated (ce_ins_ctx_t * ceic, dp_addr_t * dp, int *nth)
{
  ce_new_pos_t *cep;
  for (cep = ceic->ceic_reloc; cep; cep = cep->cep_next)
    {
      if (*dp == cep->cep_old_dp && *nth == cep->cep_old_nth)
	{
	  *dp = cep->cep_new_dp;
	  *nth = cep->cep_new_nth;
	  return 1;
	}
    }
  return 0;
}


db_buf_t
ceic_updated_col (ce_ins_ctx_t * ceic, buffer_desc_t * buf, int row_no, dbe_col_loc_t * cl)
{
  db_buf_t row, xx, xx2;
  unsigned short vl1, vl2;
  unsigned short offset;
  row_delta_t *rd = ceic_find_row_rd (ceic, row_no);
  if (rd)
    return (db_buf_t) rd->rd_values[cl->cl_nth];
  row = BUF_ROW (buf, row_no);
  ROW_STR_COL (buf->bd_tree->it_key->key_versions[IE_KEY_VERSION (row)], buf, row, cl, xx, vl1, xx2, vl2, offset);
  return (db_buf_t) mp_box_n_chars (ceic->ceic_mp, (caddr_t) xx, vl1);
}


db_buf_t
ceic_reloc_ref (ce_ins_ctx_t * ceic, db_buf_t str, int new_ct)
{
  int n_ces = new_ct != -1 ? new_ct : SHORT_REF_NA (str + CPP_N_CES);
  int first_ce = SHORT_REF_NA (str + CPP_FIRST_CE), ctr, new_first = 0;
  dp_addr_t dp, dp1 = 0, dp2 = 0;
  ce_new_pos_t *cep = ceic->ceic_reloc;
  if (cep->cep_old_nth != first_ce)
    GPF_T1 ("col ref reloc out of sync");
  dp = LONG_REF_NA (str + CPP_DP);
  for (ctr = 0; ctr < n_ces; ctr++)
    {
      if (!dp1)
	{
	  dp1 = cep->cep_new_dp;
	  new_first = cep->cep_new_nth;
	}
      if (ctr > 0)
	if (cep->cep_new_dp != dp1)
	  dp2 = cep->cep_new_dp;
      ceic->ceic_reloc = cep = cep->cep_next;
      if (!cep)
	break;
    }
  if (ceic->ceic_reloc)
    {
      int l = dp2 ? 2 * sizeof (dp_addr_t) : sizeof (dp_addr_t);
      db_buf_t res = (db_buf_t) mp_alloc_box (ceic->ceic_mp, CPP_DP + l + 1, DV_STRING);
      res[0] = DV_BLOB;
      SHORT_SET_NA (res + CPP_N_CES, n_ces);
      SHORT_SET_NA (res + CPP_FIRST_CE, new_first);
      LONG_SET_NA (res + CPP_DP, dp1);
      if (dp2)
	LONG_SET_NA (res + CPP_DP + sizeof (dp_addr_t), dp2);
      return res;
    }
  else
    {
      int l = box_length (str) + (dp2 ? sizeof (dp_addr_t) : 0);
      db_buf_t res = (db_buf_t) mp_alloc_box (ceic->ceic_mp, l, DV_STRING);
      res[0] = DV_BLOB;
      SHORT_SET_NA (res + CPP_N_CES, n_ces);
      SHORT_SET_NA (res + CPP_FIRST_CE, new_first);
      LONG_SET_NA (res + CPP_DP, dp1);
      memcpy (res + CPP_DP + sizeof (dp_addr_t) + (dp2 ? sizeof (dp_addr_t) : 0), str + CPP_DP + sizeof (dp_addr_t),
	  box_length (str) - CPP_DP - sizeof (dp_addr_t));
      if (dp2)
	LONG_SET_NA (res + CPP_DP + sizeof (dp_addr_t), dp2);
      return res;
    }
}


void
ceic_right_ce_refs (ce_ins_ctx_t * top_ceic, ce_ins_ctx_t * ceic, buffer_desc_t * buf, int new_ct)
{
  it_cursor_t *itc = ceic->ceic_itc;
  page_map_t *pm = buf->bd_content_map;
  dbe_col_loc_t *cl = &itc->itc_insert_key->key_row_var[ceic->ceic_nth_col];
  db_buf_t row, xx, xx2;
  row_size_t vl1, vl2;
  unsigned short offset;
  int r;
  if (-1 != new_ct)
    {
      /* change the ce count.  Can be there is a rd for updating the row, so update the rd if there is one, else the row directly */
      row_delta_t *rd = ceic_find_row_rd (top_ceic, itc->itc_map_pos);
      if (rd)
	{
	  xx = (db_buf_t) rd->rd_values[cl->cl_nth];
	  if (RD_UPDATE_LOCAL == rd->rd_op)
	    rd->rd_upd_change[cl->cl_nth] = cl;
	}
      else
	{
	  ITC_DELTA (itc, buf);
	  row = BUF_ROW (buf, itc->itc_map_pos);
	  ROW_STR_COL (buf->bd_tree->it_key->key_versions[IE_KEY_VERSION (row)], buf, row, cl, xx, vl1, xx2, vl2, offset);
	}
      SHORT_SET_NA (xx + CPP_N_CES, new_ct);
    }
  if (!ceic->ceic_reloc)
    return;
  for (r = ceic->ceic_end_map_pos + 1; r < pm->pm_count; r++)
    {
      db_buf_t old_str, new_str;
      old_str = ceic_updated_col (top_ceic, buf, r, cl);
      new_str = ceic_reloc_ref (ceic, old_str, -1);
      if (!box_equal (old_str, new_str))
	ceic_upd_rd (top_ceic, r, ceic->ceic_nth_col, new_str);
      if (!ceic->ceic_reloc)
	break;
    }
}


void
ceic_split_registered (ce_ins_ctx_t * ceic, row_delta_t * rd, buffer_desc_t * buf, int *splits, int n_splits, int inx)
{
  it_cursor_t *itc = ceic->ceic_itc;
  it_cursor_t *reg, *next;
  if (!buf->bd_registered)
    return;
  ITC_IN_KNOWN_MAP (itc, itc->itc_page);
  for (reg = buf->bd_registered; reg; reg = next)
    {
      next = reg->itc_next_on_page;
      if (reg->itc_map_pos == itc->itc_map_pos
	  && reg->itc_col_row >= splits[inx - 1] && (n_splits == inx || reg->itc_col_row < splits[inx]))
	{
	  reg->itc_bp.bp_transiting = 1;
	  if (COL_NO_ROW != reg->itc_col_row)
	    reg->itc_col_row -= splits[inx - 1];
	  CR_TRACE (reg, "split move");
	  itc_unregister_inner (reg, buf, 1);
	  reg->itc_next_on_page = rd->rd_keep_together_itcs;
	  rd->rd_keep_together_itcs = reg;
	}
    }
  ITC_LEAVE_MAP_NC (itc);
}

#define CR_N_BITS 64


int
ceic_split (ce_ins_ctx_t * ceic, buffer_desc_t * buf)
{
  dtp_t cr_need_bytes[CR_N_BITS / 8];
  it_cursor_t *itc = ceic->ceic_itc;
  dbe_key_t *key = itc->itc_insert_key;
  row_delta_t **rds;
  int split_fill = 0, n_ways, chunk, row_chunk, inx, ce_ctr, n_rds, split_even = 0;
  int n_ins_before = 0, n_del = 0;
  dk_set_t split_list = NULL;
  int *splits;
  ce_ins_ctx_t *full_ceic;
  col_data_ref_t *cr;
  int bytes, sz = -1;
  int cinx, cum_rows = 0, cum_bytes = 0, row_ctr = 0;
  int longest_col = -1, longest_bytes = -1;
  int n_pages = 0, n_crs = 0, max_pages = 0, col_w_most_pages = -1, total_pages = 0;
  memzero (&cr_need_bytes, sizeof (cr_need_bytes));
  DO_BOX (col_data_ref_t *, cr, cinx, itc->itc_col_refs)
  {
    int pinx;
    if (!cr || !cr->cr_is_valid)
      continue;
    n_pages = cr->cr_n_pages;
    total_pages += n_pages;
    for (pinx = 0; pinx < n_pages; pinx++)
      {
	if (cr->cr_pages[pinx].cp_ceic)
	  {
	    BIT_SET (cr_need_bytes, cinx);
	  }
      }
    if (n_pages >= max_pages)
      {
	/* the test is gte so as to get last col with max no of pages */
	col_w_most_pages = cinx;
	max_pages = n_pages;
      }
    n_crs++;
  }
  END_DO_BOX;
  DO_BOX (col_data_ref_t *, cr, cinx, itc->itc_col_refs)
  {
    int new_sz;
    int *bytes_ret;
    if (!cr || !cr->cr_is_valid)
      continue;
    bytes = 0;
    if (cinx > CR_N_BITS || BIT_IS_SET (cr_need_bytes, cinx))
      bytes_ret = &bytes;
    else
      bytes_ret = NULL;
    new_sz = cr_new_size (cr, bytes_ret);
    if (-1 != sz && sz != new_sz)
      GPF_T1 ("uneven length cols after insert");
    sz = new_sz;
    if (-1 == longest_bytes || bytes > longest_bytes)
      {
	longest_bytes = bytes;
	longest_col = cinx;
      }
  }
  END_DO_BOX;
  itc->itc_rows_in_seg = sz;
  if (!longest_bytes || longest_bytes < max_pages * PAGE_DATA_SZ / 2)
    {
      longest_col = col_w_most_pages;
      cr_new_size (itc->itc_col_refs[longest_col], &longest_bytes);
    }
  if (longest_bytes < col_seg_max_bytes && sz < col_seg_max_rows)
    {
      if (!ceic->ceic_is_ac)
	return 0;
      n_ways = 1;
    }
  else
    {
      n_ways = MAX (2, (longest_bytes / col_seg_max_bytes) + 1);
      if (sz / n_ways > col_seg_max_rows)
	n_ways = sz / col_seg_max_rows;
    }
  if (!ceic->ceic_is_ac)
    dp_may_compact (buf->bd_storage, buf->bd_page);
  chunk = longest_bytes / n_ways;
  row_chunk = sz / n_ways;
  cr = itc->itc_col_refs[longest_col];
  ceic->ceic_nth_col = longest_col;
  full_ceic = cr_make_full_ceic (ceic, cr, NULL, 0);
  if (!full_ceic->ceic_all_ces)
    {
      if (!ceic->ceic_is_ac)
	GPF_T1 ("split cannot be empty except in autocompact");
      return 0;
    }
  cr->cr_pages[0].cp_ceic = full_ceic;
  ce_ctr = 0;
  DO_SET (db_buf_t, ce, &full_ceic->ceic_all_ces)
  {
    int len, n_rows;
    if (ce == full_ceic->ceic_limit_ce)
      break;
    if (ce_ctr++ < cr->cr_first_ce)
      continue;
    len = ce_total_bytes (ce);
    n_rows = ce_n_values (ce);
    if (n_rows > col_seg_max_rows)
      {
	split_even = 1;
	break;
      }
    cum_rows += n_rows;
    cum_bytes += len;
    row_ctr += n_rows;
    if ((cum_bytes > chunk || row_ctr > row_chunk) && cum_rows < sz - 10 && !(ceic->ceic_is_ac && 1 == n_ways))	/* if ac makes longer than before recompress and not intending to split, do not split even if exceeding org len */
      {
	if (1 == n_ways)
	  GPF_T1 ("should not split if decided not to split in col ac");
	mp_set_push (ceic->ceic_mp, &split_list, (void *) (ptrlong) cum_rows);
	cum_bytes = 0;
	row_ctr = 0;
	if (split_fill + 1 == n_ways)
	  break;
      }
  }
  END_DO_SET ();
  split_list = dk_set_nreverse (split_list);
  if (!split_list && n_ways > 1)
    mp_set_push (ceic->ceic_mp, &split_list, (void *) (ptrlong) (sz / 2));
  splits = (int *) mp_alloc_box (ceic->ceic_mp, sizeof (int) * (dk_set_length (split_list)), DV_BIN);
  DO_SET (ptrlong, s, &split_list) splits[split_fill++] = s;
  END_DO_SET ();
  if (split_even || (split_fill && sz - splits[split_fill - 1] > 2 * col_seg_max_rows))
    {
      /* it is possible that the last ce has over max seg rows in a run length.  If so, may split 2 ways but only 1 split point gets made and the right side is over 2*col_seg_max_rows which might overflow the row nos with the next insert.  So if irregularities in the longest col, split it evenly */
      int inx;
      splits = (int *) mp_alloc_box (ceic->ceic_mp, sizeof (int) * n_ways, DV_BIN);
      for (inx = 0; inx < n_ways - 1; inx++)
	splits[inx] = (inx + 1) * (sz / n_ways);
      split_fill = n_ways - 1;
    }
  if (1 == split_fill && (splits[0] < sz / 3 || splits[0] > (sz * 2) / 3))
    splits[0] = sz / 2;		/* Can be that split goes to the end of the seg if longest col has over half the bytes in last ce.  So if split in 2 and split point not in mid 1/3, then put in the middle.  Will not work if split makes empty segs */
  n_ways = split_fill + 1;
  if (1 + ceic->ceic_end_map_pos - itc->itc_map_pos > n_ways)
    n_del = 1 + ceic->ceic_end_map_pos - itc->itc_map_pos - n_ways;
  rds = (row_delta_t **) mp_alloc_box (ceic->ceic_mp, sizeof (caddr_t) * (n_ways + n_del), DV_BIN);
  DO_BOX (row_delta_t *, rd, inx, rds)
  {
    rd = rds[inx] = (row_delta_t *) mp_alloc (ceic->ceic_mp, sizeof (row_delta_t));
    memset (rd, 0, sizeof (row_delta_t));
    rd->rd_map_pos = ceic->ceic_itc->itc_map_pos + inx;
    rd->rd_n_values = key->key_n_parts;
    rd->rd_values = (caddr_t *) mp_alloc_box_ni (ceic->ceic_mp, key->key_n_parts * sizeof (caddr_t), DV_BIN);
    memset (rd->rd_values, 0, box_length (rd->rd_values));
    rd->rd_key = itc->itc_insert_key;
    /* a regular  split makes 1 update + n ins.  A recompress of n segs makes up to n updates plus maybe inserts.  The recompress may end up under n segs, in which case the rest are padded with dels.  The reloc to the right is always the same */
    if (inx >= n_ways)
      rd->rd_op = RD_DELETE;
    else if (inx <= ceic->ceic_end_map_pos - itc->itc_map_pos)
      rd->rd_op = RD_UPDATE;
    else
      rd->rd_op = RD_INSERT;
  }
  END_DO_BOX;
  ceic->ceic_rds = rds;
  DO_BOX (col_data_ref_t *, cr, cinx, itc->itc_col_refs)
  {
    ce_ins_ctx_t *full_ceic;
    if (cinx >= key->key_n_parts - key->key_n_significant)
      break;
    if (cinx == longest_col)
      full_ceic = cr->cr_pages[0].cp_ceic;
    else
      {
	if (!cr || !cr->cr_is_valid)
	  {
	    if (!cr)
	      itc->itc_col_refs[cinx] = cr = itc_new_cr (itc);
	    itc_fetch_col (itc, buf, &itc->itc_insert_key->key_row_var[cinx], cinx, COL_NO_ROW);
	  }
	ceic->ceic_nth_col = cinx;
	full_ceic = cr_make_full_ceic (ceic, cr, splits, split_fill);
      }
    full_ceic->ceic_cr = cr;
    full_ceic->ceic_rds = rds;
    ceic_split_layout (full_ceic, cr, splits, split_fill);
    ceic_right_ce_refs (ceic, full_ceic, buf, -1);
    full_ceic->ceic_reloc = NULL;
    cr->cr_pages[0].cp_ceic = full_ceic;
  }
  END_DO_BOX;
  if (!ceic->ceic_is_ac)
    ceic_1st_changed (ceic);
  itc_col_leave (ceic->ceic_itc, 0);
  rds = ceic->ceic_rds;
  n_rds = BOX_ELEMENTS (rds);
  DO_BOX (row_delta_t *, rd, inx, rds)
  {
    /* test the place of 1st ce in the rd, else an integer 0 in a key column will look like no value */
    if (rd->rd_op != RD_DELETE && !rd->rd_values[key->key_n_significant])
      GPF_T1 ("ceic split is expected to produce a seg for each split, there is an unused split rd");
    rd->rd_itc = itc;
    if (RD_DELETE != rd->rd_op)
      col_ins_rd_init (rd, itc->itc_insert_key);
    if (RD_INSERT == rd->rd_op)
      {
	n_ins_before++;
	ceic_split_registered (ceic, rd, buf, splits, split_fill, inx);
	rd->rd_rl = NULL;
      }
    else if (RD_UPDATE == rd->rd_op || RD_UPDATE_LOCAL == rd->rd_op)
      {
	rd->rd_keep_together_pos = rd->rd_map_pos;
	rd->rd_keep_together_dp = itc->itc_page;
	rd->rd_map_pos += n_ins_before;	/* offset by no of inserts to the left of this */
      }
  }
  END_DO_BOX;
  itc->itc_top_ceic = ceic;
  if (CEIC_AC_MULTIPAGE == ceic->ceic_is_ac)
    {
      itc->itc_vec_rds = rds;
      return 1;
    }
  if (CEIC_AC_SINGLE_PAGE != ceic->ceic_is_ac)
    ceic_split_locks (ceic, splits, split_fill, rds);
  ITC_DELTA (ceic->ceic_itc, buf) page_apply (ceic->ceic_itc, buf, n_rds, rds, PA_MODIFY);
  return 1;
}

int
ceic_n_new_ces (ce_ins_ctx_t * ceic)
{
  int n = 0;
  DO_SET (ptrlong, op, &ceic->ceic_delta_ce_op)
  {
    if (CE_DELETE == (0xff000000 & op))
      n--;
    else if (CE_INSERT == (0xff000000 & op))
      n++;
  }
  END_DO_SET ();
  return n;
}

int
ceic_last_all_after_seg (ce_ins_ctx_t * ceic, dk_set_t dps)
{
  /* true if the last dp has no ce of this seg, i.e. only ces to the right of the changed seg */
  dp_addr_t last_dp;
  ce_new_pos_t *cep;
  if (!ceic || !dps)
    return 0;
  last_dp = (ptrlong) dps->data;
  for (cep = ceic->ceic_reloc; cep; cep = cep->cep_next)
    if (cep->cep_new_dp == last_dp && cep->cep_new_nth == 0)
      return 1;
  return 0;
}


void
cr_set_new_first_ce_buf (col_data_ref_t * cr, buffer_desc_t * new_first_ce_buf)
{
  /* the page of the first ce may change.  If so, the cr must ref the buf where the first ce is because the leaf row may have to be updated to contain the new first value in the seg */
  if (!new_first_ce_buf)
    return;
  cr->cr_first_ce_page = 0;
  if (cr->cr_pages[0].cp_buf)
    page_leave_outside_map (cr->cr_pages[0].cp_buf);
  cr->cr_pages[0].cp_buf = new_first_ce_buf;
  cr->cr_pages[0].cp_map = new_first_ce_buf->bd_content_map;
  cr->cr_pages[0].cp_string = new_first_ce_buf->bd_buffer;
}


void
ceic_no_split (ce_ins_ctx_t * ceic, buffer_desc_t * buf, int *action)
{
  int inx, col_inx;
  it_cursor_t *itc = ceic->ceic_itc;
  DO_BOX (col_data_ref_t *, cr, col_inx, itc->itc_col_refs)
  {
    ce_ins_ctx_t *last_page_ceic = NULL;
    int n_ces = 0, first_dp_changed = 0, is_first_cer, any_del = 0;
    dk_set_t dps = NULL;
    db_buf_t limit_ce;
    buffer_desc_t *new_first_ce_buf = NULL;	/* if first ce after apply is in a new buf, put it here */
    if (!cr || !cr->cr_is_valid)
      continue;			/* itc can have mopre crs than the keyh has cols due to reuse in transact.  Also an update may not touch some cols */
    limit_ce = cr_limit_ce (cr, NULL);
    n_ces = cr->cr_n_ces;
    for (inx = 0; inx < cr->cr_n_pages; inx++)
      {
	ce_ins_ctx_t *page_ceic = cr->cr_pages[inx].cp_ceic;
	if (page_ceic)
	  {
	    buffer_desc_t *buf = cr->cr_pages[inx].cp_buf;
	    ceic_result_page_t *cer;
	    last_page_ceic = page_ceic;
	    n_ces += ceic_n_new_ces (page_ceic);
	    page_ceic->ceic_org_buf = buf;
	    ceic_apply (page_ceic, cr, limit_ce);
	    if (page_ceic->ceic_res->cer_n_ces > PM_MAX_CES)
	      GPF_T1 ("more ces than fit in pm");


	    is_first_cer = 1;
	    if (page_ceic->ceic_res && page_ceic->ceic_res->cer_next)
	      dp_may_compact (buf->bd_storage, buf->bd_page);
	    for (cer = page_ceic->ceic_res; cer; cer = cer->cer_next)
	      {
		if (!cer->cer_pm->pm_count)
		  {
		    if (cer->cer_next)
		      GPF_T1 ("deleted cer must not have a next cer");
		    if (0 == inx)
		      first_dp_changed = 1;
		    ITC_IN_KNOWN_MAP (itc, buf->bd_page);
		    it_free_page (buf->bd_tree, buf);
		    ITC_LEAVE_MAP_NC (itc);
		    any_del = 1;
		    cr->cr_pages[inx].cp_buf = NULL;
		    break;
		  }
		if (!cer->cer_buf)
		  {
		    if (0 == col_inx)
		      buf_asc_ck (buf);
		    memcpy_16 (buf->bd_buffer + DP_DATA, cer->cer_buffer + DP_DATA,
			MIN (cer->cer_pm->pm_filled_to + CE_GAP_MAX_BYTES, PAGE_SZ) - DP_DATA);
		  }
		else
		  buf = cer->cer_buf;
		buf_set_pm (buf, cer->cer_pm);
		if (0 == col_inx)
		  buf_asc_ck (buf);
		if (is_first_cer && 0 == inx && cr->cr_first_ce == cer->cer_pm->pm_count / 2)
		  {
		    /* the first ce of the seg grew and did not fit on the page where it previously was. This page is therefore no longer in the seg and the seg begins at ce 0 of the page where the first ce now resides */
		    first_dp_changed = 1;
		    cr->cr_first_ce = 0;
		    cr->cr_first_ce_page = 1;	/* if 1st value changed, and need to upd leaf row, find the 1st ce on page 1, not 0 of cr */
		    if (cer->cer_next)
		      new_first_ce_buf = cer->cer_next->cer_buf;
		    else
		      bing ();
		  }
		else
		  mp_set_push (ceic->ceic_mp, &dps, DP_ADDR2VOID (buf->bd_page));
		is_first_cer = 0;
		if (cer->cer_buf && new_first_ce_buf != cer->cer_buf)
		  page_leave_outside_map (cer->cer_buf);
	      }
	  }
	else
	  {
	    mp_set_push (ceic->ceic_mp, &dps, DP_ADDR2VOID (cr->cr_pages[inx].cp_buf->bd_page));
	  }
      }
    if (ceic_last_all_after_seg (last_page_ceic, dps))
      dps = dps->next;
    ceic->ceic_nth_col = col_inx;
    if (last_page_ceic)
      last_page_ceic->ceic_nth_col = col_inx;
    if (n_ces != cr->cr_n_ces || (last_page_ceic && last_page_ceic->ceic_reloc))
      ceic_right_ce_refs (ceic, last_page_ceic, buf, n_ces);
    if (first_dp_changed || !n_ces || any_del || dk_set_length (dps) != cr->cr_n_pages)
      {
	cr_set_new_first_ce_buf (cr, new_first_ce_buf);
	ceic_upd_rd (ceic, ceic->ceic_itc->itc_map_pos, col_inx, n_ces ? ceic_dps_top_col (ceic, cr, n_ces,
		dk_set_nreverse (dps)) : NULL);
      }
  }
  END_DO_BOX;
  ceic_1st_changed (ceic);
  itc_col_leave (ceic->ceic_itc, 0);
  if (ceic->ceic_is_finalize)
    return;
  if (ceic->ceic_rds)
    {
      ITC_DELTA (ceic->ceic_itc, buf);
      itc->itc_top_ceic = ceic;
      page_apply (ceic->ceic_itc, buf, BOX_ELEMENTS (ceic->ceic_rds), ceic->ceic_rds, PA_MODIFY);
    }
  else
    {
      ITC_IN_KNOWN_MAP (itc, buf->bd_page);
      page_mark_change (buf, RWG_WAIT_KEY);
      ITC_LEAVE_MAP_NC (itc);
      page_leave_outside_map (buf);
    }
}


void
itc_col_insert_rows (it_cursor_t * itc, buffer_desc_t * buf, int is_update)
{
  dbe_key_t *key = itc->itc_insert_key;
  col_data_ref_t *last_cr = NULL;
  ce_ins_ctx_t ceic;
  int nth = 0, ign;
  memset (&ceic, 0, sizeof (ce_ins_ctx_t));
  ceic.ceic_itc = itc;
  ceic.ceic_end_map_pos = itc->itc_map_pos;
  itc->itc_buf = buf;
  DO_SET (dbe_column_t *, col, &key->key_parts)
  {
    col_data_ref_t *cr;
    int rdinx = nth < key->key_n_significant ? key->key_part_in_layout_order[nth] : nth;
    if (is_update)
      {
	int row;
	ceic.ceic_is_cpt_restore = is_update;
	if (nth < key->key_n_significant)
	  goto next_col;
	for (row = 0; row < itc->itc_range_fill; row++)
	  if (COL_UPD_NO_CHANGE != itc->itc_vec_rds[itc->itc_col_first_set + row]->rd_values[rdinx])
	    goto updated;
	goto next_col;
      }
  updated:
    ceic.ceic_col = col;
    ceic.ceic_nth_col = rdinx;
    cr = itc->itc_col_refs[nth];
    if (!cr)
      itc->itc_col_refs[nth] = cr = itc_new_cr (itc);
    if (!cr->cr_is_valid)
      itc_fetch_col (itc, buf, &key->key_row_var[nth], 0, COL_NO_ROW);
    cr_insert (&ceic, buf, cr);
    if (!last_cr || cr->cr_n_ces < last_cr->cr_n_ces)
    last_cr = cr;
  next_col:
    nth++;
  }
  END_DO_SET ();
  if (!ceic.ceic_mp && !is_update && last_cr)
    {
      int new_sz = cr_new_size (last_cr, NULL);
      itc->itc_rows_in_seg = new_sz;
      if (new_sz > col_seg_max_rows)
	ceic.ceic_mp = mem_pool_alloc ();
    }
  if (ceic.ceic_mp)
    {
      if (!ceic_split (&ceic, buf))
	{
	  ceic_no_split (&ceic, buf, &ign);
	}
      cs_free_allocd_parts (ceic.ceic_cs);
      mp_free (ceic.ceic_mp);
    }
  else
    {
      row_delta_t *rd = ceic_1st_changed (&ceic);
      itc_asc_ck (itc);
      itc_col_leave (itc, 0);
      if (rd)
	{
	  ITC_DELTA (itc, buf);
	  page_apply (itc, buf, 1, &rd, PA_MODIFY);
	  mp_free (ceic.ceic_mp);
	}
      else
	{
	  ITC_IN_KNOWN_MAP (itc, buf->bd_page);
	  page_mark_change (buf, RWG_WAIT_KEY);
	  page_leave_inner (buf);
	  ITC_LEAVE_MAP_NC (itc);
	}
    }
  itc->itc_buf = NULL;
}


void
upd_col_error (it_cursor_t * itc, buffer_desc_t * buf, mem_pool_t * mp, char *code, char *virt_code, char *string, ...)
{
  static char temp[2000];
  va_list list;
  caddr_t err;
  va_start (list, string);
  vsnprintf (temp, sizeof (temp), string, list);
  va_end (list);
  temp[sizeof (temp) - 1] = '\0';
  err = srv_make_new_error (code, virt_code, "%s", temp);
  itc->itc_ltrx->lt_status = LT_BLOWN_OFF;
  if (!itc->itc_ltrx->lt_error)
    itc->itc_ltrx->lt_error = LTE_SQL_ERROR;
  itc_page_leave (itc, buf);
  itc_free (itc);
  mp_free (mp);
  sqlr_resignal (err);
}



int
blob_col_inlined (caddr_t * val_ret, dtp_t col_dtp, mem_pool_t * mp)
{
  /* a short string that implicitly goes inline, simpler rule than for row-wise, does not depend on ither cols */
  caddr_t err = NULL;
  caddr_t val = *val_ret;
  dtp_t dtp = DV_TYPE_OF (val);
  if (DV_DB_NULL == dtp)
    {
      *val_ret = mp_alloc_box (mp, 2, DV_STRING);
      (*val_ret)[0] = DV_DB_NULL;
      return 1;
    }
  if (IS_BLOB_HANDLE_DTP (dtp))
    return 0;
  if (DV_WIDE == dtp && DV_BLOB_WIDE == col_dtp)
    {
      if (box_length (val) > COL_MAX_STR_LEN - 5)
	return 0;
      val = mp_box_to_any_1 (val, &err, mp, 0);
      if (box_length (val) < COL_MAX_STR_LEN)
	{
	  *val_ret = val;
	  return 1;
	}
      return 0;
    }
  if (DV_STRING == DV_TYPE_OF (val) && box_length (val) < COL_MAX_STR_LEN - 5)	/* 5 for dv string header in the dv format in col */
    {
      *val_ret = mp_box_to_any_1 (val, &err, mp, 0);
      return 1;
    }
  return 0;
}


row_delta_t *
upd_col_rd (update_node_t * upd, caddr_t * inst, it_cursor_t * itc, buffer_desc_t * buf, int set, mem_pool_t * mp)
{
  QNCAST (QI, qi, inst);
  dbe_key_t *key = upd->upd_table->tb_primary_key;
  row_delta_t *rd = (row_delta_t *) mp_alloc (mp, sizeof (row_delta_t));
  int inx, cinx, cidi;
  rd->rd_values = (caddr_t *) mp_alloc_box (mp, sizeof (caddr_t) * key->key_n_parts, DV_ARRAY_OF_POINTER);
  rd->rd_key = key;
  memset (rd->rd_values, 0xff, box_length (rd->rd_values));
  qi->qi_set = set;
  DO_BOX (oid_t, col_id, cidi, upd->upd_col_ids)
  {
    for (cinx = 0; key->key_row_var[cinx].cl_col_id; cinx++)
      {
	dbe_col_loc_t *cl = &key->key_row_var[cinx];
	if (col_id == cl->cl_col_id)
	  {
	    caddr_t val;
	    if (DV_ANY == cl->cl_sqt.sqt_col_dtp)
	      {
		val = dc_mp_insert_copy_any (mp, QST_BOX (data_col_t *, inst, upd->upd_values[cidi]->ssl_index), qi->qi_set, NULL);
		rd->rd_values[cinx] = val;
		continue;
	      }
	    val = qst_get (inst, upd->upd_values[cidi]);
	    if (IS_BLOB_DTP (cl->cl_sqt.sqt_col_dtp))
	      {
		caddr_t old_blob = qst_get (inst, upd->upd_old_blobs[cidi]);
		blob_layout_t *old_bl = NULL;
		if (IS_BLOB_HANDLE_DTP (DV_TYPE_OF (old_blob)))
		  {
		    dtp_t tmp[DV_BLOB_LEN];
		    bh_to_dv ((blob_handle_t *) old_blob, tmp, DV_BLOB_DTP_FOR_BLOB_HANDLE_DTP (box_tag (old_blob)));
		    old_bl = bl_from_dv_it (tmp, itc->itc_tree);
		  }
		if (blob_col_inlined (&val, cl->cl_sqt.sqt_dtp, mp))
		  {
		    rd->rd_values[cinx] = val;
		    if (old_bl)
		      blob_schedule_delayed_delete (itc, old_bl, BL_DELETE_AT_COMMIT);
		  }
		else
		  {
		    int rc;
		    dtp_t blob_temp[DV_BLOB_LEN];
		    rc = itc_set_blob_col (itc, blob_temp, val, old_bl, BLOB_IN_UPDATE, &cl->cl_sqt);
		    if (LTE_OK != rc)
		      {
			upd_col_error (itc, buf, mp, "42000", ".....", "Error making blob in column store update");
		      }
		    rd->rd_values[cinx] = mp_box_n_chars (mp, (caddr_t) blob_temp, DV_BLOB_LEN);
		  }
	      }
	    else
	      {
		if (DV_WIDE == cl->cl_sqt.sqt_col_dtp && DV_WIDE == DV_TYPE_OF (val))
		  val = rd->rd_values[cinx] =
		      mp_box_wide_as_utf8_char (mp, val, (box_length (val) / sizeof (wchar_t)) - 1, DV_STRING);
		else
		  rd->rd_values[cinx] = mp_full_box_copy_tree (mp, val);
		if (IS_BOX_POINTER (val) && box_col_len (val) > COL_MAX_STR_LEN)
		  {
		    dbe_column_t *col = sch_id_to_column (wi_inst.wi_schema, col_id);
		    upd_col_error (itc, buf, mp, "22026", "COL..", "Non blob column %s too long, index %s %d bytes",
			col ? col->col_name : "no name", key->key_name, box_col_len (val));
		  }
	      }
	  }
      }
  }
  END_DO_BOX;
  DO_BOX (state_slot_t *, pk, inx, upd->upd_pk_values)
      /* used only in log_update, one row at a time, no need to copy */
      rd->rd_values[inx] = qst_get (inst, pk);
  END_DO_BOX;
  log_update (qi->qi_trx, rd, upd, inst);
  return rd;
}


void
upd_col_pk (update_node_t * upd, caddr_t * inst)
{
  data_col_t *place_dc = QST_BOX (data_col_t *, inst, upd->upd_place->ssl_index);
  QNCAST (QI, qi, inst);
  id_hash_t *to_unregister = NULL;
  mem_pool_t *mp = mem_pool_alloc ();
  it_cursor_t itc_auto;
  it_cursor_t *itc = &itc_auto;
  int nth = 0;
  dbe_key_t *key = upd->upd_table->tb_primary_key;
  placeholder_t **places = (placeholder_t **) place_dc->dc_values;
  placeholder_t *first_pl = NULL;
  buffer_desc_t *buf;
  int n_sets = QST_INT (inst, upd->src_gen.src_prev->src_out_fill);
  ITC_INIT (itc, NULL, qi->qi_trx);
  itc_from (itc, key, qi->qi_client->cli_slice);
  itc->itc_vec_rds = NULL;
  itc_col_init (itc);
  while (nth < n_sets)
    {
      int place_set = sslr_set_no (inst, upd->upd_place, nth);
      placeholder_t *pl = places[place_set];
      int next;
      ITC_FAIL (itc)
      {
	itc->itc_rl = NULL;
	buf = itc_set_by_placeholder (itc, pl);
	if (itc->itc_pl && itc->itc_is_on_row)
	  itc->itc_rl = pl_row_lock_at (itc->itc_pl, itc->itc_map_pos);
	if (!itc->itc_is_on_row || !itc->itc_rl)
	  {
	    rdbg_printf (("Row to update deld before update T=%d L=%d pos=%d\n",
		    TRX_NO (itc->itc_ltrx), itc->itc_page, itc->itc_map_pos));
	    upd_col_error (itc, buf, mp, "24000", "SR251",
		"Cursor not on row in column store UPDATE or no lock on row.  Check that there are no autocommitting functions in the statement");
	  }
	if (LT_PENDING != qi->qi_trx->lt_status)
	  {
	    upd_col_error (itc, buf, mp, "40001", "SR251", "col upd aborted because transaction async killed");
	  }
	if (IS_MT_BRANCH (qi->qi_trx))
	  {
	    IN_TXN;
	    itc->itc_lock_lt = lt_main_lt (itc->itc_ltrx);
	    LEAVE_TXN;
	    if (!itc->itc_lock_lt)
	      {
		itc->itc_ltrx->lt_error = LTE_CANCEL;
		upd_col_error (itc, buf, mp, "40001", "SR251",
		    "main branch of txn doing col upd is gone, aborting updates because locks are gone");
	      }
	  }
	else
	  itc->itc_lock_lt = itc->itc_ltrx;
	itc_range (itc, itc->itc_col_row, itc->itc_col_row + 1);
	first_pl = pl;
	mp_array_add (mp, (caddr_t **) & itc->itc_vec_rds, &itc->itc_n_sets, (void *) upd_col_rd (upd, inst, itc, buf, nth, mp));
	for (next = nth + 1; next < n_sets; next++)
	  {
	    placeholder_t *next_pl;
	    place_set = sslr_set_no (inst, upd->upd_place, next);
	    next_pl = places[place_set];
	    if (!next_pl->itc_is_on_row)
	      {
		upd_col_error (itc, buf, mp, "24000", "SR251", "Cursor not on row in column store UPDATE");
	      }
	    if (next_pl->itc_map_pos != itc->itc_map_pos || next_pl->itc_page != itc->itc_page)
	      break;
	    SET_THR_TMP_POOL (mp);
	    {
	      if (!to_unregister)
		{
		  to_unregister = t_id_hash_allocate (1.5 * n_sets, sizeof (ptrlong), 0, boxint_hash, boxint_hashcmp);
		  t_id_hash_set (to_unregister, (caddr_t) & first_pl, (caddr_t) & first_pl);
		}
	      t_id_hash_set (to_unregister, (caddr_t) & next_pl, (caddr_t) & next_pl);
	    }
	    SET_THR_TMP_POOL (NULL);
	    itc_range (itc, next_pl->itc_col_row, next_pl->itc_col_row + 1);
	    mp_array_add (mp, (caddr_t **) & itc->itc_vec_rds, &itc->itc_n_sets, (void *) upd_col_rd (upd, inst, itc, buf, next,
		    mp));
	  }
	if (!to_unregister)
	  itc_unregister_inner ((it_cursor_t *) first_pl, buf, 0);
	else
	  itc_unregister_n (buf, to_unregister);
	itc->itc_set = 0;
	itc->itc_col_first_set = 0;
	if (!itc->itc_param_order || box_length (itc->itc_param_order) / sizeof (int) < itc->itc_n_sets)
	  {
	    itc->itc_param_order = (int *) mp_alloc_box (mp, (itc->itc_n_sets + 100) * sizeof (int), DV_BIN);
	    int_asc_fill (itc->itc_param_order, itc->itc_n_sets + 100, 0);
	  }
	qi->qi_n_affected += itc->itc_n_sets;
	itc_col_insert_rows (itc, buf, 1);
	itc_clear_col_refs (itc);
	nth = next;
	itc->itc_range_fill = 0;
	itc->itc_n_sets = 0;
      }
      ITC_FAILED
      {
	itc_free (itc);
	mp_free (mp);
      }
      END_FAIL (itc);
    }
  itc_free (itc);
  mp_free (mp);
}


void
rd_left_col_refs (page_fill_t * pf, row_delta_t * rd)
{
  int inx;
  it_cursor_t *itc = pf->pf_itc;
  dbe_key_t *key = itc->itc_insert_key;
  for (inx = key->key_n_significant; inx < key->key_n_parts; inx++)
    {
      ce_ins_ctx_t *ceic = itc->itc_col_refs[inx - key->key_n_significant]->cr_pages[0].cp_ceic;
      db_buf_t str = (db_buf_t) rd->rd_values[inx], rel;
      if (!ceic || !ceic->ceic_reloc)
	{
	  if (ceic)
	    ceic->ceic_prev_reloc = NULL;
	  continue;
	}
      ceic->ceic_prev_reloc = ceic->ceic_reloc;
      rel = ceic_reloc_ref (ceic, str, -1);
      ceic->ceic_before_rel = str;
      if (RD_ALLOCATED == rd->rd_allocated)
	rel = (db_buf_t) box_copy ((caddr_t) rel);
      rd->rd_values[inx] = (caddr_t) rel;
    }
}


void
pf_col_right_edge (page_fill_t * pf, row_delta_t * rd)
{
  it_cursor_t *itc = pf->pf_itc;
  int icol = 0;
  dbe_key_t *key = itc->itc_insert_key;
  buffer_desc_t *left_buf = pf->pf_current;
  page_map_t *pm = left_buf->bd_content_map;
  db_buf_t row;
  short prev_pos = itc->itc_map_pos;
  itc->itc_map_pos = pm->pm_count - 1;
  row = BUF_ROW (left_buf, itc->itc_map_pos);
  if (KV_LEAF_PTR == IE_KEY_VERSION (row))
    {
      itc->itc_map_pos = prev_pos;
      return;
    }
  DO_CL (cl, key->key_row_var)
  {
    db_buf_t limit_ce;
    col_data_ref_t *cr = itc->itc_col_refs[icol];
    ce_ins_ctx_t *ceic;
    dbe_column_t *col;
    if (!cr)
      cr = itc->itc_col_refs[icol] = itc_new_cr (itc);
    ceic = cr->cr_pages[0].cp_ceic;
    col = sch_id_to_column (wi_inst.wi_schema, cl->cl_col_id);
    itc_fetch_col (itc, left_buf, cl, 0, COL_NO_ROW);
    cr->cr_pages[0].cp_ceic = ceic;
    limit_ce = cr_limit_ce (cr, NULL);
    if (limit_ce)
      {
	int after = 0, n_right = 0, r;
	buffer_desc_t *right = it_new_col_page (itc->itc_tree, cr->cr_pages[0].cp_buf->bd_page, itc, col);
	buffer_desc_t *buf = cr->cr_pages[cr->cr_n_pages - 1].cp_buf;
	page_map_t *pm = buf->bd_content_map, *right_pm;
	int has_old_reloc;
	ce_new_pos_t *old_reloc;
	if (!ceic)
	  {
	    itc->itc_top_ceic->ceic_nth_col = icol;
	    itc->itc_col_refs[icol]->cr_pages[0].cp_ceic = ceic = ceic_col_ceic (itc->itc_top_ceic);
	  }
	if (ceic->ceic_is_ac)
	  ac_col_pages_out++;
	old_reloc = ceic->ceic_prev_reloc;
	ceic->ceic_reloc = old_reloc;
	if (old_reloc)
	  rd->rd_values[icol + key->key_n_significant] = (caddr_t) ceic->ceic_before_rel;
	has_old_reloc = NULL != old_reloc;
	for (r = 0; r < pm->pm_count; r += 2)
	  {
	    db_buf_t ce = cr->cr_pages[cr->cr_n_pages - 1].cp_string + pm->pm_entries[r];
	    if (limit_ce == ce)
	      {
		after = 1;
		right->bd_content_map->pm_count = 0;
		  map_resize (right, &right->bd_content_map, PM_SIZE (pm->pm_count));
		right_pm = right->bd_content_map;
		right_pm->pm_count = 0;
		right_pm->pm_bytes_free = PAGE_DATA_SZ;
		right_pm->pm_filled_to = DP_DATA;
	      }
	    if (after)
	      {
		ce_new_pos_t *cep;
		int bytes = ce_total_bytes (ce);
		memcpy_16 (right->bd_buffer + right_pm->pm_filled_to, ce, bytes);
		right_pm->pm_entries[n_right] = right_pm->pm_filled_to;
		right_pm->pm_entries[n_right + 1] = ce_n_values (ce);
		right_pm->pm_bytes_free -= bytes;
		right_pm->pm_filled_to += bytes;
		cs_write_gap (right->bd_buffer + right_pm->pm_filled_to, right_pm->pm_bytes_free);
		right_pm->pm_count += 2;
		n_right += 2;
		if (has_old_reloc)
		  {
		    cep = old_reloc;
		    old_reloc = old_reloc->cep_next;
		  }
		else
		  {
		    cep = (ce_new_pos_t *) mp_alloc (ceic->ceic_mp, sizeof (ce_new_pos_t));
		    cep->cep_old_dp = buf->bd_page;
		    cep->cep_old_nth = r / 2;
		    cep_append (ceic, cep);
		  }
		cep->cep_new_dp = right->bd_page;
		cep->cep_new_nth = (right_pm->pm_count - 2) / 2;
	      }
	  }
	page_leave_outside_map (right);
	if (has_old_reloc && old_reloc)
	  GPF_T1 ("was old reloc in multiple split but was not consumed on 2nd split");
	ITC_DELTA (itc, buf);
	cs_write_gap (limit_ce, (buf->bd_buffer + PAGE_SZ) - limit_ce);
	pg_make_col_map (buf);
      }
    icol++;
  }
  END_DO_CL;
  itc_col_leave (itc, ITC_NO_CEIC_CLEAR);
  itc->itc_map_pos = prev_pos;
}


void
itc_col_ins_registered (it_cursor_t * itc, buffer_desc_t * buf)
{
  int ins_offset = 0, inx;
  if (!buf->bd_registered)
    return;
  for (inx = 0; inx < itc->itc_range_fill; inx++)
    {
      it_cursor_t *reg;
      int any_affected = 0;
      if (itc->itc_ranges[inx].r_first != itc->itc_ranges[inx].r_end)
	continue;		/* a non-0 range, i.e. uppdate does not shift */
      for (reg = buf->bd_registered; reg; reg = reg->itc_next_on_page)
	{
	  if (itc->itc_map_pos == reg->itc_map_pos && reg->itc_col_row >= itc->itc_ranges[inx].r_first + ins_offset)
	    {
	      reg->itc_col_row++;
	      any_affected = 1;
	    }
	}
      if (!any_affected)
	return;
      ins_offset++;
    }
}

#if 0
void
key_col_insert (it_cursor_t * itc, row_delta_t * rd)
{
  /* if no rd, itc_rds has the rds.  Find the row(s) and insert */
  key_ver_t kv;
  buffer_desc_t *buf;
  int rc, n;
  db_buf_t row;
  itc_col_free (itc);
  itc->itc_search_mode = SM_INSERT;
  buf = itc_reset (itc);
  rc = itc_search (itc, &buf);
  row = BUF_ROW (buf, itc->itc_map_pos);
  kv = IE_KEY_VERSION (row);
  if (KV_LEFT_DUMMY == kv)
    {
      if (1 == buf->bd_content_map->pm_count)
	{
	  itc_col_initial (itc, buf, rd);
	  return;
	}
      itc_range (itc, 0, 0);
      itc->itc_map_pos = 1;
    }
  else
    {
      itc->itc_set = 0;
      itc->itc_n_sets = 1;
      for (n = 0; n < itc->itc_insert_key->key_n_significant; n++)
	ITC_P_VEC (itc, n) = NULL;
      itc_col_search (itc, buf);
      if (COL_NO_ROW == itc->itc_ranges[0].r_first)
	{
	  col_data_ref_t *cr = itc->itc_col_refs[0];
	  int r = cr_n_rows (cr);
	  itc->itc_ranges[0].r_first = itc->itc_ranges[0].r_end = r;
	}
    }
  !!itc_col_ins_registered (itc, buf);
  itc->itc_vec_rds = (row_delta_t **) list (1, (caddr_t) rd);
  itc_col_insert_rows (itc, buf, 0);
  dk_free_box ((caddr_t) itc->itc_vec_rds);
}

#else
void
key_col_insert (it_cursor_t * itc, row_delta_t * rd, insert_node_t * ins)
{
  int inx;
  itc->itc_n_sets = 1;
  itc->itc_set = 0;
  for (inx = 0; inx < itc->itc_insert_key->key_n_parts; inx++)
    ITC_P_VEC (itc, inx) = NULL;
  if (!itc->itc_param_order)
    {
      itc->itc_param_order = (int *) itc_alloc_box (itc, sizeof (int), DV_BIN);
      itc->itc_param_order[0] = 0;
    }
  itc->itc_vec_rds = (row_delta_t **) list (1, (caddr_t) rd);
  itc_col_vec_insert (itc, ins);
  dk_free_box ((caddr_t) itc->itc_vec_rds);
  itc_free_box (itc, itc->itc_param_order);
  itc->itc_param_order = 0;
}
#endif

/* going to page above to see what the end of inserted range is does not work.  If try, get inx out of order */
int enable_end_seg_parent = 0;


buffer_desc_t *
itc_read_parent (it_cursor_t * itc, buffer_desc_t * buf)
{
  buffer_desc_t *parent_buf = NULL;
  dp_addr_t up;
  volatile dp_addr_t *up_field;
  up_field = (dp_addr_t *) (buf->bd_buffer + DP_PARENT);
  up = LONG_REF (up_field);
  if (!enable_end_seg_parent)
    return NULL;
  ITC_IN_TRANSIT (itc, up, buf->bd_page) if (!LONG_REF (up_field))
    {
      /* The parent got deld by itc_single_leaf_delete while waiting for parent access */
      ITC_LEAVE_MAPS (itc);
      return NULL;
    }
  if (LONG_REF (up_field) != up)
    {
      ITC_LEAVE_MAPS (itc);
      TC (tc_up_transit_parent_change);
      return NULL;
    }
  parent_buf = IT_DP_TO_BUF (itc->itc_tree, up);
  if (!parent_buf || parent_buf->bd_is_write || parent_buf->bd_write_waiting || parent_buf->bd_read_waiting
      || parent_buf->bd_being_read)
    {
      ITC_LEAVE_MAPS (itc);
      return NULL;
    }
  parent_buf->bd_readers++;
  ITC_LEAVE_MAPS (itc);
  return parent_buf;
}


void
itc_leave_parents (buffer_desc_t ** parents, int n_parents)
{
  int inx;
  for (inx = 0; inx < n_parents; inx++)
    page_leave_outside_map (parents[inx]);
}


int
itc_end_seg_insert_parent (it_cursor_t * itc, buffer_desc_t * buf, buffer_desc_t ** parent_bufs, int *n_parents, int *pos_ret)
{
  /* find the nearest parent the position is not the rightmost.  If don't get immediate access leave parents and return 0 */
  for (;;)
    {
      int pos;
      dp_addr_t dp_from = buf->bd_page;
      buffer_desc_t *parent = itc_read_parent (itc, buf);
      if (!parent)
	{
	  itc_leave_parents (parent_bufs, *n_parents);
	  return 0;
	}
      parent_bufs[*n_parents] = parent;
      (*n_parents)++;
      pos = page_find_leaf (parent, dp_from);
      if (-1 == pos)
	{
	  itc_leave_parents (parent_bufs, *n_parents);
	  return 0;
	}
      if (pos < parent->bd_content_map->pm_count - 1)
	{
	  *pos_ret = pos + 1;
	  return 1;
	}
      if (*n_parents > 5)
	{
	  itc_leave_parents (parent_bufs, *n_parents);
	  return 0;
	}
      buf = parent;
    }
  GPF_T1 ("does not come here");
  return 0;
}

int enable_seg_end_ins = 1;
long tc_seg_end_insert;
long tc_seg_end_insert_parent;

int64 new_v_end_trap = 0x80000000000;

void
itc_seg_end_inserts (it_cursor_t * itc, buffer_desc_t * buf, insert_node_t * ins)
{
  /* next set, check if this too below next seg. */
  int set_save = itc->itc_set;
  int rows_in_seg = -1;
  page_map_t *pm;
  buffer_desc_t *parent_bufs[10];
  int n_parents = 0;
  int rc;
  int n_pars, inx;
  search_spec_t *sp;
  int pos;
  if (!enable_seg_end_ins)
    return;
  if (itc->itc_range_fill + itc->itc_set >= itc->itc_n_sets)
    return;
  pm = buf->bd_content_map;
  if (itc->itc_map_pos == pm->pm_count - 1)
    {
      if (!itc_end_seg_insert_parent (itc, buf, parent_bufs, &n_parents, &pos))
	return;
      buf = parent_bufs[n_parents - 1];
    }
  else
    pos = itc->itc_map_pos + 1;

  itc->itc_set += itc->itc_range_fill;
next_set:
  sp = itc->itc_key_spec.ksp_spec_array;
  if (itc->itc_set >= itc->itc_n_sets || itc->itc_range_fill > 30000)
    {
      itc_leave_parents (parent_bufs, n_parents);
      itc->itc_set = set_save;
      return;
    }
  n_pars = itc->itc_search_par_fill;
  for (inx = 0; inx < n_pars; inx++)
    {
      data_col_t *dc = ITC_P_VEC (itc, inx);
      int ninx = itc->itc_param_order[itc->itc_set];
      int64 new_v;
      if (!dc)
	goto next;
      new_v = dc_any_value (dc, ninx);
      if (new_v == new_v_end_trap)
	bing ();
      if (DCT_NUM_INLINE & dc->dc_type)
	*(int64 *) itc->itc_search_params[inx] = new_v;
      else if (DV_ANY == sp->sp_cl.cl_sqt.sqt_dtp)
	itc->itc_search_params[inx] = (caddr_t) (ptrlong) new_v;
      else if (DV_ANY == dc->dc_dtp && sp->sp_cl.cl_sqt.sqt_dtp != DV_ANY)
	itc->itc_search_params[inx] = itc_temp_any_box (itc, inx, (db_buf_t) new_v);
      else if (!itc_vec_sp_copy (itc, inx, new_v, ninx))
	itc->itc_search_params[inx] = (caddr_t) (ptrlong) new_v;
    next:
      sp = sp->sp_next;
    }
  rc = itc->itc_key_spec.ksp_key_cmp (buf, pos, itc);
  if (DVC_GREATER == rc)
    {
      if (-1 == rows_in_seg)
	rows_in_seg = cr_n_rows (itc->itc_col_refs[0]);
      itc_range (itc, rows_in_seg, rows_in_seg);
      TC (tc_seg_end_insert);
      if (n_parents)
	TC (tc_seg_end_insert_parent);
      itc->itc_set++;
      goto next_set;
    }
  itc_leave_parents (parent_bufs, n_parents);
  itc->itc_set = set_save;
}


void itc_col_dbg_log (it_cursor_t * itc);
int col_ins_error = 0;
int dbf_col_ins_dbg_log = 0;


void
itc_col_ins_dups (it_cursor_t * itc, buffer_desc_t * buf, insert_node_t * ins)
{
  row_no_t point = 0, next = 0;
  int inx, fill = 0;
  col_row_lock_t *clk;
  int first_set = itc->itc_col_first_set;
  if (!ins || INS_SOFT == ins->ins_mode || itc->itc_insert_key->key_distinct)
    {
      for (inx = 0; inx < itc->itc_range_fill; inx++)
	{
	  if (inx && itc->itc_ranges[inx].r_first < itc->itc_ranges[inx - 1].r_first)
	    {
	      col_ins_error = 1;
	      if (dbf_col_ins_dbg_log)
		{
		  log_error ("insert of col-wise inx would be out of order, exiting.  Key %s slice %d",
		      itc->itc_insert_key->key_name, itc->itc_tree->it_slice);
		  itc_col_dbg_log (itc);
		  return;
		}
	      return;
	      GPF_T1 ("ranges to insert must have a non-decreasing r_first");
	    }
	  if (itc->itc_ranges[inx].r_first != itc->itc_ranges[inx].r_end)
	    {
	      if (!itc_is_own_del_clk (itc, itc->itc_ranges[inx].r_first, &clk, &point, &next))
		continue;
	      clk->clk_change &= ~CLK_DELETE_AT_COMMIT;
	      if (itc->itc_insert_key->key_n_significant * 2 == itc->itc_insert_key->key_n_parts)
		continue;
	    }
	  if (fill != inx)
	    {
	      itc->itc_param_order[fill + first_set] = itc->itc_param_order[inx + first_set];
	      itc->itc_ranges[fill++] = itc->itc_ranges[inx];
	    }
	  else
	    fill++;
	}
      itc->itc_range_fill = fill;
    }
  else
    {
      for (inx = 0; inx < itc->itc_range_fill; inx++)
	{
	  if (inx && itc->itc_ranges[inx].r_first < itc->itc_ranges[inx - 1].r_first)
	    GPF_T1 ("ranges to insert must have a non-decreasing r_first");
	  if (itc->itc_ranges[inx].r_end != itc->itc_ranges[inx].r_first)
	    {
	      if (!itc_is_own_del_clk (itc, itc->itc_ranges[inx].r_first, &clk, &point, &next))
		{
		  caddr_t detail = dk_alloc_box (50 + MAX_NAME_LEN + MAX_QUAL_NAME_LEN, DV_SHORT_STRING);
		  snprintf (detail, box_length (detail) - 1,
		      "Non unique insert on key %.*s on table %.*s",
		      MAX_NAME_LEN, itc->itc_insert_key->key_name, MAX_QUAL_NAME_LEN, itc->itc_insert_key->key_table->tb_name);
		  LT_ERROR_DETAIL_SET (itc->itc_ltrx, detail);
		  itc_col_leave (itc, 0);
		  itc->itc_ltrx->lt_error = LTE_UNIQ;
		  itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
		}
	      else
		{
		  clk->clk_change &= ~CLK_DELETE_AT_COMMIT;
		  if (itc->itc_insert_key->key_n_significant * 2 == itc->itc_insert_key->key_n_parts)
		    continue;	/* if no dependent, delete is reverted and index need not be touched */
		}
	    }
	  if (fill != inx)
	    {
	      itc->itc_param_order[fill + first_set] = itc->itc_param_order[inx + first_set];
	      itc->itc_ranges[fill++] = itc->itc_ranges[inx];
	    }
	  else
	    fill++;
	}
      itc->itc_range_fill = fill;
    }
}


void
itc_col_log_insert (it_cursor_t * itc)
{
  int inx;
  for (inx = 0; inx < itc->itc_range_fill; inx++)
    log_insert (itc->itc_ltrx, itc->itc_vec_rds[itc->itc_param_order[itc->itc_col_first_set + inx]], itc->itc_ins_flags);
}


extern int32 cl_non_logged_write_mode;
dk_session_t * dbg_log_ses;
caddr_t bif_curdatetime (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

void
col_dbg_log_new ()
{
  int fd, rc;
  TIMESTAMP_STRUCT ts;
  char *szExt, szNewName[255], szTS[15];
  caddr_t now;
  if (!dbg_log_ses)
    return;

  now = bif_curdatetime(NULL, NULL, NULL);
  dt_to_timestamp_struct(now, &ts);
  snprintf(szTS, sizeof (szTS), "%04d%02d%02d%02d%02d%02d",
	ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second);
  dk_free_box(now);
  snprintf (szNewName, sizeof (szNewName), COL_DBG_LOG ".%s", szTS);

  mutex_enter (log_write_mtx);
  fd = tcpses_get_fd (dbg_log_ses->dks_session);
  /*ftruncate (fd, 0);*/
  fd_close (fd, 0);
  rc = rename (COL_DBG_LOG, szNewName);
  PrpcSessionFree (dbg_log_ses);
  dbg_log_ses = NULL;
  mutex_leave (log_write_mtx);
}

void
itc_col_dbg_log (it_cursor_t * itc)
{
  /* debug func for logging insert locality and order.  Log the batch of rows that went intoo this seg */
  lock_trx_t *lt = itc->itc_ltrx;
  caddr_t *repl = lt->lt_replicate;
  dk_session_t *save = lt->lt_log;
  dk_session_t *ses;
  caddr_t *h = NULL;
  int fd;
  int inx;
  if (1 != dbf_col_ins_dbg_log && itc->itc_insert_key->key_id != dbf_col_ins_dbg_log
      && !(-dbf_col_ins_dbg_log == itc->itc_insert_key->key_id))
    return;
  lt->lt_log = ses = strses_allocate ();
  lt->lt_replicate = REPL_LOG;
  for (inx = 0; inx < itc->itc_range_fill; inx++)
    {
      row_delta_t *rd = itc->itc_vec_rds[itc->itc_param_order[itc->itc_set + inx]];
      if (itc->itc_ranges[inx].r_first != itc->itc_ranges[inx].r_end)
	continue;
      cl_non_logged_write_mode = 0;
      log_insert (itc->itc_ltrx, rd, dbf_col_ins_dbg_log > 0 ? LOG_KEY_ONLY : 0);
    }
  h = (caddr_t *) list (LOG_HEADER_LENGTH, 0, box_string (""), 0, box_num (strses_length (ses)), box_num (LOG_2PC_DISABLED));
  mutex_enter (log_write_mtx);
  /* write to file like in log_commit () */
  if (!dbg_log_ses)
    {
      OFF_T off;
      fd = fd_open (COL_DBG_LOG, LOG_OPEN_FLAGS);
      off = LSEEK (fd, 0, SEEK_END);
      dbg_log_ses = dk_session_allocate (SESCLASS_TCPIP);
      tcpses_set_fd (dbg_log_ses->dks_session, fd);
    }
  CATCH_WRITE_FAIL (dbg_log_ses)
  {
    print_object ((caddr_t) h, dbg_log_ses, NULL, NULL);
    strses_write_out (lt->lt_log, dbg_log_ses);
    session_flush_1 (dbg_log_ses);
    /* NO fsync.  Will fduck upp all timing fd_fsync (tcpses_get_fd (dbg_log_ses->dks_session)); */
  }
  END_WRITE_FAIL (dbg_log_ses);
  mutex_leave (log_write_mtx);
  dk_free_tree (ses);
  dk_free_tree (h);
  lt->lt_log = save;
  lt->lt_replicate = repl;
}


void
itc_col_vec_insert (it_cursor_t * itc, insert_node_t * ins)
{
  key_ver_t kv;
  buffer_desc_t *buf;
  caddr_t *bounds;
  int rc, n_ranges, save_n;
  int n_in_segs = 0;
  db_buf_t row;
  if (dbf_ins_no_distincts && itc->itc_insert_key->key_distinct)
    return;
  itc->itc_set = 0;
  itc->itc_search_mode = SM_INSERT;
  itc->itc_lock_mode = PL_EXCLUSIVE;
  if (ins && ins->ins_seq_col)
    sqlr_new_error ("42000", "COL..", "A column-wise index does not support the fetch option of insert");

  itc_col_free (itc);
  for (;;)
    {
      itc->itc_range_fill = 0;
      buf = itc_reset (itc);
      rc = itc_search (itc, &buf);
      if (COL_NO_ROW != itc->itc_col_row)
	GPF_T1 ("itc col insert must have itc col row not set at start of search");
      itc_ce_check (itc, buf, 0);
      row = BUF_ROW (buf, itc->itc_map_pos);
      kv = IE_KEY_VERSION (row);
      if (KV_LEFT_DUMMY == kv)
	{
	  if (1 == buf->bd_content_map->pm_count)
	    {
	      if (NO_WAIT != itc_col_initial (itc, buf, itc->itc_vec_rds[itc->itc_param_order[0]]))
		{
		  n_ranges = 0;
		  goto reset;
		}
	      itc_range (itc, 0, 0);
	      itc_col_ins_registered (itc, buf);
	      n_ranges = 1;
	      goto reset;
	    }
	  else
	    itc->itc_map_pos++;
	}
      save_n = itc->itc_n_sets;
      itc->itc_n_sets = MIN (itc->itc_n_sets, 32000 + itc->itc_set);
      if (!buf->bd_is_write)
	GPF_T1 ("col ins must have write access on index leaf");
      bounds = NULL;
      if (dbf_rq_check && rq_range_check_min && rq_check_ctr > rq_range_check_min && dbf_rq_key == itc->itc_insert_key->key_id)
	bounds = rq_check_page_bounds (itc, buf);
      itc_col_search (itc, buf);
      itc->itc_n_sets = save_n;
      if (1 == itc->itc_range_fill && COL_NO_ROW == itc->itc_ranges[0].r_first && COL_NO_ROW != itc->itc_ranges[0].r_end)
	itc->itc_ranges[0].r_first = itc->itc_ranges[0].r_end;
      if (COL_NO_ROW == itc->itc_ranges[itc->itc_range_fill - 1].r_first)
	{
	  if (itc->itc_map_pos == buf->bd_content_map->pm_count - 1
	      && (ITC_RIGHT_EDGE == itc->itc_keep_right_leaf || ITC_RL_INIT == itc->itc_keep_right_leaf))
	    {
	      int n_ins, r = cr_n_rows (itc->itc_col_refs[0]), inx;
	      itc->itc_ranges[itc->itc_range_fill - 1].r_first = itc->itc_ranges[itc->itc_range_fill - 1].r_end = r;
	      n_ins = MIN (32000, itc->itc_n_sets - itc->itc_set);
	      for (inx = itc->itc_range_fill; inx < n_ins; inx++)
		itc_range (itc, r, r);
	    }
	  else
	    {
	      if (itc->itc_range_fill > 1)
		itc->itc_range_fill--;
	      else
		{
		  col_data_ref_t *cr = itc->itc_col_refs[0];
		  int r = cr_n_rows (cr);
		  itc->itc_ranges[0].r_first = itc->itc_ranges[0].r_end = r;
		}
	      itc_seg_end_inserts (itc, buf, ins);
	    }
	}
      else
	itc_seg_end_inserts (itc, buf, ins);
      n_ranges = itc->itc_range_fill;
      if (!itc->itc_non_txn_insert)
	{
	  col_row_lock_t *clk = NULL;
	  itc->itc_rl = buf->bd_pl ? pl_row_lock_at (buf->bd_pl, itc->itc_map_pos) : NULL;
	  if (!wi_inst.wi_checkpoint_atomic)	/* reinsert of checkpoint uncommitted does not wait */
	    itc_first_col_lock (itc, &clk, buf);
	  if (0 == itc->itc_range_fill && clk)
	    {
	      lock_wait ((gen_lock_t *) clk, itc, buf, ITC_NO_LOCK);
	      n_ranges = 0;
	      goto reset;
	    }
	  n_ranges = itc->itc_range_fill;
	}
      else
	itc->itc_rl = NULL;
      if (itc->itc_pl)
	itc->itc_rl = pl_row_lock_at (itc->itc_pl, itc->itc_map_pos);
      itc_col_ins_dups (itc, buf, ins);
      if (itc->itc_log_actual_ins)
	itc_col_log_insert (itc);
      if (enable_pogs_check && !col_ins_error && key_is_seg_check (itc->itc_insert_key->key_id))
	{
	  if (strstr (itc->itc_insert_key->key_name, "POGS"))
	itc_pogs_seg_check (itc, buf);
	  else if (strstr (itc->itc_insert_key->key_name, "k_p2"))
	    itc_gs_seg_check (itc, buf);
	}
      if (col_ins_error)
	{
	  itc_col_leave (itc, 0);
	  page_leave_outside_map (buf);
	  sqlr_new_error ("XXXXX", "COL..", "Insert stopped because out of seg data here or elsewhere host %d key %s slice %d",
	      local_cll.cll_this_host, itc->itc_insert_key->key_name, itc->itc_tree->it_slice);
	}
      if (itc->itc_range_fill)
	{
	  itc_col_ins_registered (itc, buf);
	  if (!itc->itc_non_txn_insert)
	    itc_col_ins_locks (itc, buf);
	  else
	    itc_col_ins_locks_nti (itc, buf);
	  if (itc->itc_insert_key->key_is_primary)
	    itc->itc_insert_key->key_table->tb_count_delta += itc->itc_range_fill;
	  if (dbf_col_ins_dbg_log)
	    itc_col_dbg_log (itc);
	  itc->itc_insert_key->key_touch += itc->itc_range_fill;
	  itc_col_insert_rows (itc, buf, 0);
	  n_in_segs += itc->itc_rows_in_seg;
	  if (dbf_rq_check && dbf_rq_key == itc->itc_insert_key->key_id)
	    {
	      if (bounds)
		rq_range_check (itc, bounds);
	    rq_check (itc);
	}
	}
      else
	{
	  itc_col_leave (itc, 0);
	  page_leave_outside_map (buf);
	}
    reset:
      itc->itc_set += n_ranges;
      itc->itc_range_fill = 0;
      if (itc->itc_set == itc->itc_n_sets)
	{
	  if (dbf_rq_check && -dbf_rq_key == itc->itc_insert_key->key_id)
	    rq_check (itc);
	  if (itc->itc_out_state && itc->itc_n_sets > 10 && (n_in_segs - itc->itc_n_sets) > 10 * itc->itc_n_sets)
	    ins_check_batch_sz (ins, itc->itc_out_state, itc);
	  return;
	}
      if (itc->itc_n_sets > 1)
	itc_set_param_row (itc, itc->itc_set);
    }
}


void
col_ins_rd_init (row_delta_t * rd, dbe_key_t * key)
{
  int inx, ctr = 0;
  rd->rd_non_comp_len = key->key_row_var_start[0];
  DO_CL_0 (cl, key->key_key_fixed) ctr++;
  END_DO_CL;
  DO_CL_0 (cl, key->key_key_var)
  {
    rd->rd_non_comp_len += box_length (rd->rd_values[ctr]) - 1;
    ctr++;
  }
  END_DO_CL;
  for (inx = key->key_n_significant; inx < key->key_n_parts; inx++)
    rd->rd_non_comp_len += box_length (rd->rd_values[inx]) - 1;
}


int
pm_range_count (short *arr, int n)
{
  int inx, sum = 0;
  for (inx = 0; inx < n; inx++)
    sum += arr[inx * 2 + 1];
  return sum;
}
