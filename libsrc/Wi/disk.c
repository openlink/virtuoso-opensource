/*
 *  disk.c
 *
 *  $Id$
 *
 *  Managing buffer rings and paging to disk.
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
#ifdef HAVE_CONFIG_H
# include <config.h>
#endif

#if HAVE_SYS_MMAN_H
# if defined (__APPLE__)
#  undef thread_create
#  undef thread_t
#  undef semaphore_t
#  define _P1003_1B_VISIBLE
# elif defined HPUX_11
#  define _INCLUDE_POSIX4_SOURCE 1
# endif
# include <sys/mman.h>
#endif

#define NO_DBG_PRINTF
#include "libutil.h"
#include "wi.h"
#include "sqlver.h"
#include "sqlfn.h"
#include "srvstat.h"
#include "recovery.h"

static void dbs_extend_pagesets (dbe_storage_t * dbs);

#ifdef BYTE_ORDER_REV_SUPPORT

dk_hash_t * row_hash = 0;
int h_index = 0;

#if DB_SYS_BYTE_ORDER == DB_ORDER_LITTLE_ENDIAN
void DBS_REVERSE_LONG(db_buf_t pl)
{
  if (h_index && gethash((void*) pl, row_hash))
    return;
  else
    {
      long npl = LONG_REF_NA (pl);
      LONG_SET (pl,npl);
      if (h_index) sethash ((void*) pl, row_hash, (void*) 1);
    }
}
void  DBS_REVERSE_SHORT(db_buf_t ps)
{
  if (h_index && gethash((void*) ps, row_hash))
    return;
  else
    {
      short nps = SHORT_REF_NA (ps);
      SHORT_SET (ps, nps);
      if (h_index) sethash ((void*) ps, row_hash, (void*) 1);
    }
}
long  DBS_REV_LONG_REF(db_buf_t p)
{
  if (h_index && gethash((void*) p, row_hash))
    return LONG_REF (p);
  return LONG_REF_NA (p);
}
short DBS_REV_SHORT_REF(db_buf_t ps)
{
  if (h_index && gethash((void*) ps, row_hash))
    return SHORT_REF (ps);
  return SHORT_REF_NA ((ps));
}
#else
void  DBS_REVERSE_LONG(db_buf_t pl)
{
  if (h_index && gethash((void*) pl, row_hash))
    return;
  else
    {
      long npl = LONG_REF_BE (pl);
      LONG_SET (pl,npl);
      if (h_index) sethash ((void*) pl, row_hash, (void*) 1);
    }
}
void  DBS_REVERSE_SHORT(db_buf_t ps)
{
  if (h_index && gethash((void*) ps, row_hash))
    return;
  else
    {
      short nps = SHORT_REF_BE (ps);
      SHORT_SET (ps, nps);
      if (h_index) sethash ((void*) ps, row_hash, (void*) 1);
    }
}

long  DBS_REV_LONG_REF(db_buf_t p)
{
  if (h_index && gethash((void*) p, row_hash))
    return LONG_REF (p);
  return LONG_REF_BE (p);
}

short DBS_REV_SHORT_REF(db_buf_t ps)
{
  if (h_index && gethash((void*) ps, row_hash))
    return SHORT_REF (ps);
  return SHORT_REF_BE ((ps));
}

#endif

int ol_buf_disk_read (buffer_desc_t* buf);
void buf_disk_raw_write (buffer_desc_t* buf);

typedef void (*dbs_reverse_header_func_f)(dbe_storage_t * dbs, buffer_desc_t * buf);

void dbs_rev_h_index  (dbe_storage_t * dbs, buffer_desc_t * buf);
void dbs_rev_h_free_set  (dbe_storage_t * dbs, buffer_desc_t * buf);
void dbs_rev_h_ext (dbe_storage_t * dbs, buffer_desc_t * buf);
void dbs_rev_h_blob (dbe_storage_t * dbs, buffer_desc_t * buf);
void dbs_rev_h_free (dbe_storage_t * dbs, buffer_desc_t * buf);
void dbs_rev_h_head (dbe_storage_t * dbs, buffer_desc_t * buf);
void dbs_rev_h_remap (dbe_storage_t * dbs, buffer_desc_t * buf);
void  dbs_rev_h_blob_dir (dbe_storage_t * dbs, buffer_desc_t * buf);
void dbs_rev_h_incbackup (dbe_storage_t * dbs, buffer_desc_t * buf);

int dbs_reverse_db = 0;

dbs_reverse_header_func_f dbs_reverse_page_header[DPF_LAST_DPF] =
{
  /* DPF_INDEX */ dbs_rev_h_index,
  /* DPF_FREE_SET */ dbs_rev_h_free_set,
  /* DPF_EXTENSION */ dbs_rev_h_ext,
  /* DPF_BLOB	*/ dbs_rev_h_blob,
  /* DPF_FREE */ dbs_rev_h_free,
  /* DPF_DB_HEAD */ dbs_rev_h_head,
  /* DPF_CP_REMAP */ dbs_rev_h_remap,
  /* DPF_BLOB_DIR */ dbs_rev_h_blob_dir,
  /* DPF_INCBACKUP_SET */ dbs_rev_h_incbackup
};

wi_database_t rev_cfg;

#endif /* BYTE_ORDER_REV_SUPPORT */

int neodisk = 1;
wi_inst_t wi_inst;
resource_t * pm_rc_1;
resource_t * pm_rc_2;
resource_t * pm_rc_3;
resource_t * pm_rc_4;
hash_index_cache_t hash_index_cache;
dk_mutex_t * lt_locks_mtx;

struct wi_inst_s * wi_instance_get(void) { return &wi_inst; }

dp_addr_t dbs_get_free_disk_page_near (dbe_storage_t * dbs, dp_addr_t near_dp);

dbe_storage_t *
dbs_allocate (char * name, char type)
{
  NEW_VARZ (dbe_storage_t, dbs);
  dbs->dbs_type = type;
  dk_set_push (&wi_inst.wi_storage, (void*) dbs);
  dbs->dbs_name = box_string (name);
  dbs->dbs_page_mtx = mutex_allocate ();
  mutex_option (dbs->dbs_page_mtx, "dbs", NULL, NULL);
  dbs->dbs_file_mtx = mutex_allocate ();
  mutex_option (dbs->dbs_file_mtx, "file", NULL, NULL);
  fc_init (&dbs->dbs_free_cache);
  dbs->dbs_cpt_remap = hash_table_allocate (101);
  dk_hash_set_rehash (dbs->dbs_cpt_remap, 4);
  dbs->dbs_cpt_tree = it_allocate (dbs);
  return dbs;
}


dbe_storage_t *
wd_storage (wi_db_t * wd, caddr_t name)
{
  if (DV_DB_NULL == DV_TYPE_OF (name))
    return (wd->wd_primary_dbs);
  DO_SET (dbe_storage_t *, dbs, &wd->wd_storage)
    {
      if (0 == stricmp (dbs->dbs_name, name))
	return dbs;
    }
  END_DO_SET();
  return NULL;
}


void
it_not_in_any (du_thread_t * self, index_tree_t * except)
{
#ifdef MTX_DEBUG
#ifdef FAST_MTX_DEBUG
  return;
#endif
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_storage)
    {
      DO_SET (index_tree_t *, it, &dbs->dbs_trees)
	{
	  if (it != except &&
	      it->it_page_map_mtx->mtx_owner == self)
	    GPF_T1 ("may not be inside this tree map when entering other mtx");
	}
      END_DO_SET();
    }
  END_DO_SET();
#endif
}


#ifdef DBSE_TREES_DEBUG
int
dbg_it_print_trees ()
{
  DO_SET (dbe_storage_t *, dbs, &wi_inst.wi_storage)
    {
      fprintf (stderr, "\nStorage %s\n\n", dbs->dbs_file);
      DO_SET (index_tree_t *, it, &dbs->dbs_trees)
	{
	  if (it->it_key)
	    fprintf (stderr, "Key %s[%ld]\n", it->it_key->key_name, (long) it->it_key->key_id);
	  else
	    fprintf (stderr, "Tree with no key \n");
	}
      END_DO_SET();
    }
  END_DO_SET();
  return 0;
}
#endif

int
txn_mtx_entry_check (dk_mutex_t * mtx, du_thread_t * self, void * cd)
{
  it_not_in_any (self, NULL);
  return 1;
}


int
it_page_map_entry_check (dk_mutex_t * mtx, du_thread_t * self, void * cd)
{
  /* false if owns wrong mtxs when getting into map.  No other maps allowed at time */
#ifdef MTX_DEBUG
  index_tree_t * it = (index_tree_t *) cd;
  it_not_in_any (self, it);
#endif
  return 1;
}

resource_t * it_rc;


index_tree_t *
it_allocate (dbe_storage_t * dbs)
{
  NEW_VARZ (index_tree_t, tree);

  tree->it_page_map_mtx = mutex_allocate ();
  tree->it_lock_release_mtx = mutex_allocate ();

  tree->it_commit_space = isp_allocate (tree, COMMIT_REMAP_SIZE);
  tree->it_checkpoint_space = isp_allocate (tree, 3);
  tree->it_commit_space->isp_prev = tree->it_checkpoint_space;
  tree->it_locks = hash_table_allocate (101);
  dk_hash_set_rehash (tree->it_locks, space_rehash_threshold);
  tree->it_storage = dbs;
  dk_set_push (&dbs->dbs_trees, (void*)tree);
  return tree;
}


index_tree_t *
it_temp_allocate (dbe_storage_t * dbs)
{
  index_tree_t * tree = (index_tree_t *) resource_get (it_rc);
  if (!tree)
    {
      NEW_VARZ (index_tree_t, tree);

      tree->it_page_map_mtx = mutex_allocate ();

      tree->it_commit_space = isp_allocate (tree, 101);
      tree->it_locks = hash_table_allocate (10);
      dk_hash_set_rehash (tree->it_commit_space->isp_dp_to_buf, 2);
      dk_hash_set_rehash (tree->it_commit_space->isp_remap, 5);
      tree->it_storage = dbs;
      return tree;
    }
  else
    {
      tree->it_hi = NULL;
      tree->it_storage = dbs;
      tree->it_hash_first = 0;
      return tree;
    }
}


void
it_free (index_tree_t * it)
{
  IN_PAGE_MAP (it);
  isp_free (it->it_commit_space);
  if (it->it_checkpoint_space)
    isp_free (it->it_checkpoint_space);
  if (it->it_locks)
    hash_table_free (it->it_locks);
  LEAVE_PAGE_MAP (it);
  mutex_free (it->it_page_map_mtx);
  dk_free ((void*) it, sizeof (index_tree_t));
}


void
it_temp_tree (index_tree_t * it)
{
  buffer_desc_t * buf = isp_new_page (it->it_commit_space, 0, DPF_INDEX, 0, 0);
  pg_init_new_root (buf);
  it->it_commit_space->isp_root = buf->bd_page;
  IN_PAGE_MAP (it);
  page_leave_inner (buf);
  LEAVE_PAGE_MAP (it);
}


void
it_temp_free (index_tree_t * it)
{
  /* free a temp tree */
  it_cursor_t itc_auto;
  it_cursor_t * itc = &itc_auto;
  ptrlong dp, remap;
  buffer_desc_t * buf;
  dk_hash_iterator_t hit;
  index_space_t * isp;
  if (!it)
    return;
  if (it->it_hi && it_hi_done (it))
    return;  /* a reusable hash temp ref dropped */
  if (it->it_hi_signature)
    GPF_T1 ("freeing hash without invalidating it first");
  ITC_INIT (itc, NULL, NULL);
  itc_from_it (itc, it);
  isp = it->it_commit_space;
 again:
  ITC_IN_MAP (itc);
  dk_hash_iterator (&hit, isp->isp_dp_to_buf);
  while (dk_hit_next (&hit, (void**) &dp, (void **) &buf))
    {
      ASSERT_IN_MAP (itc->itc_tree);
      if (BUF_WIRED (buf))
	{
	  page_wait_access (itc, buf->bd_page, buf, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
	  ITC_IN_MAP (itc);
	  buf_cancel_write (buf);
	  ITC_IN_MAP (itc);
	  page_leave_inner (buf);
	  goto again; /* sequence broken, hash iterator to be re-inited */
	}
      else
	{
	  buf->bd_is_write = 1;
	  buf_cancel_write (buf);
	  buf->bd_is_write = 0;
	}
      BUF_BACKDATE(buf);
      buf->bd_space = NULL;
      buf->bd_is_dirty = 0;
      buf->bd_page = 0;
      buf->bd_physical_page = 0;
    }
  clrhash (isp->isp_dp_to_buf);
  ITC_LEAVE_MAP (itc);
  itc_free (itc);
  dk_hash_iterator (&hit, isp->isp_remap);
  IN_DBS (it->it_storage);
  while (dk_hit_next (&hit, (void**)&dp, (void**)&remap))
    {
      dbs_free_disk_page (it->it_storage, (dp_addr_t) dp);
    }
  LEAVE_DBS (it->it_storage);
  clrhash (isp->isp_remap);
  if (it->it_hi)
    hi_free (it->it_hi);
  it->it_hi = NULL;
  it->it_hi_reuses = 0;
  if (it->it_commit_space->isp_hash_size != it->it_commit_space->isp_dp_to_buf->ht_actual_size)
    it_free (it); /* rehashed to non-standard size. do not recycle.  */
  else
    {
      if (!resource_store (it_rc, (void*) it))
	it_free (it);
    }
}


page_map_t *
map_allocate (ptrlong sz)
{
  int bytes = (int) (PM_ENTRIES_OFFSET + sz * sizeof (short));
  page_map_t * map = (page_map_t *) dk_alloc (bytes);
  memset (map, 0, bytes);
  map->pm_size = (short) sz;
  return map;
}


void
map_free (page_map_t * map)
{
  int bytes = -1;
  if (map)
    bytes = PM_ENTRIES_OFFSET + map->pm_size * sizeof (short);
  dk_free ((void*) map, bytes);
}


buffer_desc_t *
buffer_allocate (int type)
{
  NEW_VARZ (buffer_desc_t, buf);
  buf->bd_buffer = (db_buf_t) dk_alloc (PAGE_SZ);
  memset (buf->bd_buffer, 0, PAGE_SZ);
  SHORT_SET (buf->bd_buffer + DP_FLAGS, type);
  return buf;
}


int32 bp_flush_trig_pct = 50;
int64 bp_replace_age;
int32 bp_replace_count;

long tc_bp_get_buffer;
long tc_bp_get_buffer_loop;
#define B_N_SAMPLE (BP_N_BUCKETS * 4)

dp_addr_t
bd_age_key (void * b)
{
  return (-((buffer_desc_t *)b)->bd_age);
}


void buf_qsort (buffer_desc_t ** in, buffer_desc_t ** left,
	   int n_in, int depth, sort_key_func_t key);


void
bp_stats (buffer_pool_t * bp)
{
  buffer_desc_t * sample[B_N_SAMPLE + 1];
  buffer_desc_t * sample_2[B_N_SAMPLE + 1];
  int inx, fill = 0;
  for (inx = bp->bp_ts & 0xf; inx < bp->bp_n_bufs; inx += bp->bp_n_bufs / B_N_SAMPLE)
    {
      buffer_desc_t * buf = &bp->bp_bufs[inx];
      buf->bd_age = BUF_AGE (buf);
      sample[fill++] = buf;
    }
  buf_qsort (sample, sample_2, fill, 0, bd_age_key);
  for (inx = 0; inx < BP_N_BUCKETS - 1; inx++)
    {
      bp->bp_bucket_limit[inx] = sample[(inx + 1) * 4]->bd_age;
    }
  bp->bp_bucket_limit[BP_N_BUCKETS - 1] = sample[fill - 1]->bd_age;
  memset (&bp->bp_n_dirty, 0, sizeof (bp->bp_n_dirty));
  memset (&bp->bp_n_clean, 0, sizeof (bp->bp_n_clean));
  for (inx = 0; inx < bp->bp_n_bufs; inx++)
    {
      int bucket;
      buffer_desc_t * buf = &bp->bp_bufs[inx];
      int age = bp->bp_ts - buf->bd_timestamp;
      for (bucket = 0; bucket < BP_N_BUCKETS - 1; bucket++)
	{
	  if (age >= bp->bp_bucket_limit[bucket])
	    {
	      if (buf->bd_is_dirty && !buf->bd_iq)
		bp->bp_n_dirty[bucket]++;
	      else
		bp->bp_n_clean[bucket]++;
	      goto next;
	    }
	}
      if (buf->bd_is_dirty)
	bp->bp_n_dirty[BP_N_BUCKETS - 1]++;
      else
	bp->bp_n_clean[BP_N_BUCKETS - 1]++;
    next: ;
    }
  bp->bp_stat_ts = bp->bp_ts;
}


int
bp_found (buffer_desc_t * buf)
{
  buffer_pool_t * bp = buf->bd_pool;
  index_space_t * last_isp = buf->bd_space;
  if (!last_isp)
    {
      /* when taking a non-used buffer, the serialization is on the
       * bp, not the map of the buffer's tree.  Must check for flags, as
       * double allocation is possible if the buffer is found by other thread before getting a tree and the flags are not checked */
      if (!BUF_AVAIL (buf))
	return 0;
      buf->bd_readers = 1;
      bp->bp_next_replace = (int) ((buf - bp->bp_bufs) + 1);
      bp_replace_count--; /* reuse of abandoned not counted as a replace */
      LEAVE_BP (bp);
      buf->bd_timestamp = bp->bp_ts;
      return 1;
    }
  IN_PAGE_MAP (last_isp->isp_tree);
  if (BUF_AVAIL (buf))
    {
      buf->bd_readers = 1;
      if (buf->bd_space == last_isp)
	{
	  /* the buffer may have been freed from its isp between reading the last_isp and entering its map.
	   */
	  if (!remhash (DP_ADDR2VOID (buf->bd_page), last_isp->isp_dp_to_buf))
	    GPF_T1 ("buffer not in the hash of the would be space of residence");
	}
      buf->bd_page = 0;
      buf->bd_space = NULL;
      bp->bp_next_replace = (int) ((buf - bp->bp_bufs) + 1);
      bp_replace_age += bp->bp_ts - buf->bd_timestamp;
      LEAVE_PAGE_MAP (last_isp->isp_tree);
      LEAVE_BP (bp);
      buf->bd_timestamp = bp->bp_ts;
      return 1;
    }
  LEAVE_PAGE_MAP (last_isp->isp_tree);
  return 0;
}


int
bp_stat_action (buffer_pool_t * bp)
{
  /* schedule writes if appropriate.  If nothing free write synchroneously */
  static int action_ctr;
  int n_dirty = 0, n_clean = 0;
  int bucket, age_limit;
  int flushable_range = bp->bp_n_bufs / BP_N_BUCKETS;
  for (bucket = 0; bucket < BP_N_BUCKETS; bucket++)
    {
      n_clean += bp->bp_n_clean[bucket];
      n_dirty += bp->bp_n_dirty[bucket];
      if (n_dirty + n_clean > bp->bp_n_bufs / flushable_range)
	break;
    }
  if (bucket == BP_N_BUCKETS)
    bucket--;
  age_limit = bp->bp_bucket_limit[bucket];
  if ((n_dirty * 100) / (n_clean + n_dirty) > bp_flush_trig_pct
    || action_ctr++ % 10 == 0)
    {
      mt_write_dirty (bp, age_limit, 0);
    }
  if (n_clean)
    return age_limit;
  else
    return 0;
}


int
bp_n_being_written (buffer_pool_t * bp)
{
  int inx, c = 0;
  for (inx = 0; inx < bp->bp_n_bufs; inx++)
    {
      if (bp->bp_bufs[inx].bd_iq
	  && bp->bp_bufs[inx].bd_is_dirty)
	c++;
    }
  return c;
}


void
bp_wait_flush (buffer_pool_t * bp)
{
  /* sleep until the backlog of buffers in async write is somewhat cleared.  Under 40% of last bucket in write queue */
  int limit = (bp->bp_n_bufs / BP_N_BUCKETS) / 3;
  int n = bp_n_being_written (bp);
  int n_tries = 1, waited = 0, first_n = n;
  limit = MAX (limit, n / 2);
  while (n > limit)
    {
      virtuoso_sleep (0, 50000 * n_tries);
      waited += n_tries * 50;
      if (waited > 1000)
	break;
      if (n_tries < 4)
	n_tries++;
      n = bp_n_being_written (bp);
    }
  dbg_printf (("waited for bp flush of %d for %d msec\n", first_n - n, waited));
}


buffer_desc_t *
bp_get_buffer (buffer_pool_t * bp, int mode)
{
  /* buffer returned with bd_readers = 1 so that it won't be allocated twice. Disconnected from any tree/page on return */
  buffer_desc_t * buf;
  int age_limit;
  if (!bp)
    bp = wi_inst.wi_bps[wi_inst.wi_bp_ctr ++ % wi_inst.wi_n_bps];
  tc_bp_get_buffer++;
  mutex_enter  (bp->bp_mtx);
  bp_replace_count++;
  bp->bp_ts++;
 again:
  if (((int) (bp->bp_ts - bp->bp_stat_ts)) > (bp->bp_n_bufs / BP_N_BUCKETS) / 2)
    {
      bp_stats (bp);
      age_limit = bp_stat_action (bp);
    }
  else
    age_limit = bp->bp_bucket_limit[0];
  for (buf = &bp->bp_bufs[bp->bp_next_replace]; buf < &bp->bp_bufs[bp->bp_n_bufs]; buf++)
    {
      if (!buf->bd_is_dirty
	  && ((int) (bp->bp_ts - buf->bd_timestamp)) >= age_limit)
	{
	  if (bp_found (buf))
	    return buf;
	}
      tc_bp_get_buffer_loop++;
      age_limit--;
    }
  for (buf = &bp->bp_bufs[0]; buf < &bp->bp_bufs[bp->bp_next_replace]; buf++)
    {
      if (!buf->bd_is_dirty
	  && ((int) (bp->bp_ts - buf->bd_timestamp)) >= age_limit)
	{
	  if (bp_found (buf))
	    return buf;
	}
      tc_bp_get_buffer_loop++;
      age_limit--;
    }
  /* absolutely all were dirty */
  bp->bp_stat_ts = bp->bp_ts - bp->bp_n_bufs;
  if (BP_BUF_IF_AVAIL == mode)
    {
      LEAVE_BP (bp);
      TC (tc_get_buf_failed);
      return NULL;
    }
  bp_wait_flush (bp); /* do not busy wait.  Flush in progress. Wait until there are old buffers for reuse. */
  goto again;
}


long gpf_time = 0;

int
buf_set_dirty (buffer_desc_t * buf)
{
  /* Not correct, exception in pg_reloc_right_leaves.
    if (!BUF_WIRED (buf))
    GPF_T1 ("can't set a buffer as dirty if not on it.");
  */
  if (!buf->bd_space->isp_prev
      && buf->bd_space->isp_tree->it_checkpoint_space)
    {
      gpf_time = get_msec_real_time();
      GPF_T1 ("Dirty buffer in checkpoint");
    }

  if (!buf->bd_is_dirty)
    {
      /* BUF_TICK (buf); */
      buf->bd_is_dirty = 1;
      wi_inst.wi_n_dirty++;
      if (0 && wi_inst.wi_n_dirty > wi_inst.wi_max_dirty
	  && !mt_write_pending)
	{
	  mt_write_start (OLD_DIRTY);
	}
      return 1;
    }
  return 0;
}


int
buf_set_dirty_inside (buffer_desc_t * buf)
{
  if (!BUF_WIRED (buf))
    GPF_T1 ("can't set a buffer as dirty if not on it.");
  if (!buf->bd_space->isp_prev)
#ifdef CHECKPOINT_TIMING
    {
      gpf_time = get_msec_real_time();
      GPF_T1 ("Dirty buffer in checkpoint");
    }
#else
    GPF_T1 ("Dirty buffer in checkpoint");
#endif


  if (!buf->bd_is_dirty)
    {
      wi_inst.wi_n_dirty++;
      /* BUF_TICK (buf); */
      buf->bd_is_dirty = 1;
      return 1;
    }
  return 0;
}


void
wi_new_dirty (buffer_desc_t * buf)
{
  /* BUF_TICK (buf); */
}


long occupied_frees = 0;

void
buf_untouch (buffer_desc_t * buf)
{
  /* put buffer in last place in LRU queue. Leave it valid */
  buffer_pool_t * bp = buf->bd_pool;
  buf->bd_timestamp = bp->bp_ts - bp->bp_n_bufs;
}


void
buf_set_last (buffer_desc_t * buf)
{
  /* when this is called, the buffer 1. will not be in any tree cache, 2. will be occupied, all other resets done elsewhere */
  buffer_pool_t * bp = buf->bd_pool;
  index_space_t * isp = buf->bd_space;
  DBG_PT_BUF_SCRAP (buf);
  if (isp)
    {
      ASSERT_IN_MAP (isp->isp_tree);
      if (buf->bd_page && gethash ((void*)(ptrlong)buf->bd_page, isp->isp_dp_to_buf))
	GPF_T1 ("buf_set_last called while buffer still in isp's cache.");
    }
  buf->bd_pl = NULL;
  buf->bd_page = 0;
  buf->bd_physical_page = 0;
  buf->bd_space = NULL;

  if (buf->bd_is_dirty)
    {
      wi_inst.wi_n_dirty--;
      buf->bd_is_dirty = 0;
    }
  buf->bd_timestamp = bp->bp_ts - bp->bp_n_bufs;
}


int
bp_mtx_entry_check (dk_mutex_t * mtx, du_thread_t * self, void * cd)
{
  it_not_in_any (self, NULL);
  return 1;
}


buffer_pool_t *
bp_make_buffer_list (int n)
{
  buffer_desc_t *buf;
  int c;
  unsigned char *buffers_space, *buf_ptr;
  NEW_VARZ (buffer_pool_t, bp);
  bp->bp_mtx = mutex_allocate ();
  mutex_option (bp->bp_mtx, "BP", bp_mtx_entry_check, (void*) bp);
  bp->bp_n_bufs = n;
  bp->bp_bufs = (buffer_desc_t *) dk_alloc (sizeof (buffer_desc_t) * n);
  memset (bp->bp_bufs, 0, sizeof (buffer_desc_t) * n);
  bp->bp_sort_tmp = (buffer_desc_t **) dk_alloc (sizeof (caddr_t) * n);

  buffers_space = malloc (ALIGN_VOIDP (PAGE_SZ) * n);
  memset (buffers_space, 0, ALIGN_VOIDP (PAGE_SZ) * n);
  buf_ptr = buffers_space;
  for (c = 0; c < n; c++)
    {
      buf = &bp->bp_bufs[c];
      buf->bd_buffer = buf_ptr;
      buf_ptr += ALIGN_VOIDP (PAGE_SZ);
      buf->bd_pool = bp;
      buf->bd_timestamp = bp->bp_ts - bp->bp_n_bufs;
      buf->bd_next = bp->bp_first_buffer;
      if (!bp->bp_last_buffer)
	bp->bp_last_buffer = buf;
      buf->bd_next = bp->bp_first_buffer;
      if (bp->bp_first_buffer)
	{
	  bp->bp_first_buffer->bd_prev = buf;
	}
      bp->bp_first_buffer = buf;
    }

#if HAVE_SYS_MMAN_H && !defined(__FreeBSD__)
  if (cf_lock_in_mem)
    {
      int rc = mlockall (MCL_CURRENT);
      if (rc)
	log_error ("mlockall system call failed with %d.", errno);
    }
#endif

  return bp;
}


void
dbg_sleep (int msecs)
{
#if !defined (WIN32)
  struct timeval tv;
  tv.tv_sec = msecs / 1000;
  tv.tv_usec = msecs % 1000;
  select (0, NULL, NULL, NULL, &tv);
#endif
}

disk_stripe_t *
dp_disk_locate (dbe_storage_t * dbs, dp_addr_t target, OFF_T * place)
{
  dp_addr_t start = 0, end;
  DO_SET (disk_segment_t *, seg, &dbs->dbs_disks)
  {
    end = start + seg->ds_size;
    if (target >= start && target < end)
      {
	int stripe_inx;
	target -= start;
	stripe_inx = target % seg->ds_n_stripes;
	*place = PAGE_SZ * (OFF_T) (target / seg->ds_n_stripes);
	return (seg->ds_stripes[stripe_inx]);
      }
    start = end;
  }
  END_DO_SET ();
  GPF_T1 ("Reference past end of configured stripes");
  return NULL;			/* dummy */
}


void
dp_set_backup_flag (dbe_storage_t * dbs, dp_addr_t page, int on)
{
  uint32* array;
  int inx, bit;
  dp_addr_t array_page;

  dbs_locate_incbackup_bit (dbs, page, &array, &array_page, &inx, &bit);

  if (on)
    {
      array[inx] |= (1 << bit);
    }
  else
    array[inx] &= ~(1 << bit);
}


int
dp_backup_flag (dbe_storage_t * dbs, dp_addr_t page)
{
  uint32* array;
  int inx, bit;
  dp_addr_t array_page;

  dbs_locate_incbackup_bit (dbs, page, &array, &array_page, &inx, &bit);
  return (array[inx] & (1 << bit));
}


/*#define DISK_CHECKSUM*/

#ifdef DISK_CHECKSUM
dk_hash_t * disk_checksum;
dk_mutex_t * dck_mtx;


void
d_check_write (dp_addr_t dp, db_buf_t buf)
{
  long sum = 0, inx;
  for (inx = 0; inx < PAGE_SZ / sizeof (long); inx++)
    sum += ((long *)buf)[inx];
  mutex_enter (dck_mtx);
  sethash ((void*)(ptrlong) dp, disk_checksum, (void*)(ptrlong) sum);
  mutex_leave (dck_mtx);
}


void
d_check_read (dp_addr_t dp, db_buf_t buf)
{
  long sum = 0, inx, chksum;
  for (inx = 0; inx < PAGE_SZ / sizeof (long); inx++)
    sum += ((long *)buf)[inx];
  mutex_enter (dck_mtx);
  chksum = (long) gethash ((void*)(ptrlong) dp, disk_checksum);
  if (chksum && sum != chksum)
    GPF_T1 ("disk checksum mismatch.");
  mutex_leave (dck_mtx);
}

#endif

int
dst_fd (disk_stripe_t * dst)
{
  int fd;
  semaphore_enter (dst->dst_sem);
  mutex_enter (dst->dst_mtx);
  fd = dst->dst_fds[--dst->dst_fd_fill];
  mutex_leave (dst->dst_mtx);
  return fd;
}


void
dst_fd_done (disk_stripe_t * dst, int fd)
{
  mutex_enter (dst->dst_mtx);
  dst->dst_fds[dst->dst_fd_fill++] = fd;
  mutex_leave (dst->dst_mtx);
  semaphore_leave (dst->dst_sem);
}


long disk_reads = 0;
long disk_writes = 0;
long read_cum_time = 0;
long write_cum_time = 0;
int assertion_on_read_fail = 1;

int
buf_disk_read (buffer_desc_t * buf)
{
  long start;
  OFF_T rc;
  dbe_storage_t * dbs = buf->bd_storage;
  short flags;
  OFF_T off;

  disk_reads++;
  if (dbs->dbs_disks)
    {
      disk_stripe_t *dst = dp_disk_locate (dbs, buf->bd_physical_page, &off);
      int fd = dst_fd (dst);
      start = get_msec_real_time ();
      rc = LSEEK (fd, off, SEEK_SET);
      if (rc != off)
	{
	  log_error ("Seek failure on stripe %s", dst->dst_file);
	  GPF_T;
	}
      rc = read (fd, buf->bd_buffer, PAGE_SZ);
      dst_fd_done (dst, fd);
      if (rc != PAGE_SZ)
	{
	  if (assertion_on_read_fail)
	    {
	      log_error ("Read failure on stripe %s", dst->dst_file);
	      GPF_T;
	    }
	  return WI_ERROR;
	}
      read_cum_time += get_msec_real_time () - start;
    }
  else
    {
      mutex_enter (dbs->dbs_file_mtx);
      start = get_msec_real_time ();
      off = ((OFF_T)buf->bd_physical_page) * PAGE_SZ;
      rc = LSEEK (dbs->dbs_fd, off, SEEK_SET);
      if (rc != off)
	{
	  if (assertion_on_read_fail)
	    {
	      log_error ("Seek failure on database %s", dbs->dbs_file);
	      GPF_T;
	    }
	  mutex_leave (dbs->dbs_file_mtx);
	  return WI_ERROR;
	}
      rc = read (dbs->dbs_fd, (char *) buf->bd_buffer, PAGE_SZ);
      if (rc != PAGE_SZ)
	{
	  if (assertion_on_read_fail)
	    {
	      log_error ("Read failure on database %s", dbs->dbs_file);
	      GPF_T;
	    }
	  mutex_leave (dbs->dbs_file_mtx);
	  return WI_ERROR;
	}
      read_cum_time += get_msec_real_time () - start;
      mutex_leave (dbs->dbs_file_mtx);
    }
  flags = SHORT_REF (buf->bd_buffer + DP_FLAGS);
#ifdef BYTE_ORDER_REV_SUPPORT
  if (dbs_reverse_db)
    {
      DBS_REVERSE_SHORT((db_buf_t)&flags);
      if (flags >= 0 && flags < DPF_LAST_DPF)
	(dbs_reverse_page_header[flags]) (dbs, buf);
    }
#endif
#ifdef DISK_CHECKSUM
  if (dbs->dbs_type == DBS_PRIMARY)
    d_check_read (buf->bd_physical_page, buf->bd_buffer);
#endif
  if (DPF_INDEX == flags)
    pg_make_map (buf);
  else if (buf->bd_content_map)
    {
      resource_store (PM_RC (buf->bd_content_map->pm_size), (void*) buf->bd_content_map);
      buf->bd_content_map = NULL;
    }
  if (DPF_BLOB == flags || DPF_BLOB_DIR == flags)
    TC(tc_blob_read);
  return WI_OK;
}




void
buf_disk_write (buffer_desc_t * buf, dp_addr_t phys_dp_to)
{
  long start;
  int bytes;
  short flags;
  dbe_storage_t * dbs = buf->bd_storage;
  OFF_T rc;
  OFF_T off;
  dp_addr_t dest = (phys_dp_to ? phys_dp_to : buf->bd_physical_page);

  /* dbg_sleep (2); */
  flags = SHORT_REF (buf->bd_buffer + DP_FLAGS);
  DBG_PT_WRITE (buf, phys_dp_to);
#ifdef O12DEBUG
  if (flags == DPF_INDEX)
    buf_check_deleted_refs (buf, checkpoint_in_progress ? 0 : 1);
#endif

  if (flags == DPF_INDEX)
    if (KI_TEMP != (key_id_t)SHORT_REF (buf->bd_buffer + DP_KEY_ID)
	&& !sch_id_to_key (wi_inst.wi_schema, SHORT_REF (buf->bd_buffer + DP_KEY_ID)))
      GPF_T1 ("Writing index page with no key");

  if (SHORT_REF (buf->bd_buffer + DP_FIRST) == 0 &&
      flags == DPF_INDEX &&
      buf->bd_page != buf->bd_space->isp_root)
    {
      log_error ("Write of empty page P=%ld Remap = %ld",
		 buf->bd_page, dest);
      if (!correct_parent_links)
	GPF_T1 ("Write of empty page");
    }

  if (DPF_INDEX == flags)
    bytes = PAGE_SZ;		/* buf -> bd_content_map -> pm_filled_to; */
  else
    bytes = PAGE_SZ;
  disk_writes++;
  if (DPF_BLOB == flags || DPF_BLOB_DIR == flags)
    TC(tc_blob_write);
  if (dbs->dbs_disks)
    {
      disk_stripe_t *dst = dp_disk_locate (dbs, dest, &off);
      int fd = dst_fd (dst);
      start = get_msec_real_time ();
      rc = LSEEK (fd, off, SEEK_SET);
      if (rc != off)
	{
	  log_error ("Seek failure on stripe %s", dst->dst_file);
	  GPF_T;
	}
      rc = write (fd, buf->bd_buffer, bytes);
      if (rc != bytes)
	{
	  log_error ("Write failure on stripe %s", dst->dst_file);
	  GPF_T;
	}
      dst_fd_done (dst, fd);
    }
  else
    {
      OFF_T off_dest = ((OFF_T) dest) * PAGE_SZ;
      /* dest *= PAGE_SZ; */
      mutex_enter (dbs->dbs_file_mtx);
      start = get_msec_real_time ();
      if (off_dest > dbs->dbs_file_length)
	{
	  /* Fill the gap. */
	  LSEEK (dbs->dbs_fd, 0, SEEK_END);
	  while (dbs->dbs_file_length <= off_dest)
	    {
	      if (PAGE_SZ != write (dbs->dbs_fd, (char *) buf->bd_buffer,
		      PAGE_SZ))
		{
		  log_error ("Write failure on database %s", dbs->dbs_file);
		  GPF_T;
		}
	      dbs->dbs_file_length += PAGE_SZ;
	    }
	}
      else
	{
	  off = ((OFF_T)buf->bd_physical_page) * PAGE_SZ;
	  if (off != LSEEK (dbs->dbs_fd, off, SEEK_SET))
	    {
	      log_error ("Seek failure on database %s", dbs->dbs_file);
	      GPF_T;
	    }
	  if (off_dest == dbs->dbs_file_length)
	    bytes = PAGE_SZ;
	  rc = write (dbs->dbs_fd, (char *) buf->bd_buffer, bytes);
	  if (rc != bytes)
	    {
	      log_error ("Write failure on database %s", dbs->dbs_file);
	      GPF_T;
	    }
#if 0
	  {
	    unsigned char page [PAGE_SZ];
	    if (36 * PAGE_SZ == lseek (dbs->dbs_fd, 36 * PAGE_SZ, SEEK_SET))
	      {
		if (PAGE_SZ == read (dbs->dbs_fd, page, PAGE_SZ))
		  {
		    if (DPF_INDEX != SHORT_REF (page + DP_FLAGS))
		      log_warning ("akaaaak");
		  }
	      }
	  }
#endif
	}
      write_cum_time += get_msec_real_time () - start;
      mutex_leave (dbs->dbs_file_mtx);
    }
#ifdef DEBUG
  if (buf->bd_page != buf->bd_physical_page)
    {
      dbg_printf (("L %ld W %ld , ", buf->bd_page, buf->bd_physical_page));
    }
#endif
#ifdef DISK_CHECKSUM
  if (dbs->dbs_type == DBS_PRIMARY)
    d_check_write (dest, buf->bd_buffer);
#endif
}


void
change_byte_order (dp_addr_t *arr, int n)
{
#ifdef LOW_ORDER_FIRST
  int c;
  for (c = 0; c < n; c++)
    arr[c] = LONG_TO_EXT (arr[c]);
#endif
}


buffer_desc_t *
dbs_read_page_set (dbe_storage_t * dbs, dp_addr_t first_dp, int flag)
{
  dp_addr_t dp_first;
  buffer_desc_t *first = buffer_allocate (flag);
  buffer_desc_t *prev = first;
  first->bd_storage = dbs;
  first->bd_physical_page = first->bd_page = first_dp;

  if (strchr (wi_inst.wi_open_mode, 'a'))	/* dummy, db unreadable */
    return first;

  buf_disk_read (first);
  while ((dp_first = LONG_REF (prev->bd_buffer + DP_OVERFLOW)))
    {
      buffer_desc_t *buf = buffer_allocate (flag);
      buf->bd_storage = dbs;
      prev->bd_next = buf;
      buf->bd_physical_page = buf->bd_page = dp_first;
      buf_disk_read (buf);

      prev = buf;
    }
  return first;
}

void
dbs_write_page_set (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  while (buf)
    {
      buf_disk_write (buf, 0);
      buf = buf->bd_next;
    }
}

static void
dbs_page_set_extend (dbe_storage_t* dbs, buffer_desc_t** page_set, int offset)
{
  buffer_desc_t **prev = page_set;
  db_buf_t prev_page = NULL;
  buffer_desc_t *new_page;

  buffer_desc_t *next;
  int n = 0;

  if (offset == V_EXT_OFFSET_UNK_SET)
    {
      if (page_set == &dbs->dbs_free_set)
	offset = V_EXT_OFFSET_FREE_SET;
      else if (page_set == &dbs->dbs_incbackup_set)
	offset = V_EXT_OFFSET_INCB_SET;
      else
	GPF_T;
    }
  else
    if (offset != V_EXT_OFFSET_FREE_SET && offset != V_EXT_OFFSET_INCB_SET)
      GPF_T;

  new_page = buffer_allocate (offset == V_EXT_OFFSET_FREE_SET ? DPF_FREE_SET : DPF_INCBACKUP_SET);
  new_page->bd_storage = dbs;
  memset (new_page->bd_buffer + DP_DATA, 0, PAGE_SZ - DP_DATA);
  while ((next = *prev))
    {
      n++;
      prev = &next->bd_next;
      prev_page = next->bd_buffer;
    }
  *prev = new_page;
  new_page->bd_physical_page = new_page->bd_page = n * BITS_ON_PAGE + offset;
  /* Free set is backed to the first page in its area */
  ((dp_addr_t *) (new_page->bd_buffer + DP_DATA))[0] |= 0x03;
  /* The free list is backed on the first page of the area it covers */
  if (prev_page)
    {
      LONG_SET (prev_page + DP_OVERFLOW, new_page->bd_page);
    }
}


void
dbs_locate_page_bit (dbe_storage_t* dbs, buffer_desc_t** ppage_set, dp_addr_t near_dp,
    uint32 **array, dp_addr_t *page_no, int *inx, int *bit, int offset)
{
  dp_addr_t near_page;
  dp_addr_t n;
  buffer_desc_t* free_set = ppage_set[0];


  near_page = near_dp / BITS_ON_PAGE;

  *page_no = near_page;
  for (n = 0; n < near_page; n++)
    {
      if (!free_set->bd_next)
	{
	  dbs_extend_pagesets (dbs);
	}
      free_set = free_set->bd_next;
    }
  *array = (dp_addr_t *) (free_set->bd_buffer + DP_DATA);
  *inx = (int) ((near_dp % BITS_ON_PAGE) / BITS_IN_LONG);
  *bit = (int) ((near_dp % BITS_ON_PAGE) % BITS_IN_LONG);
}


#define FC_ENT_MASK 0xffffffe0	/* 5 low bits zero. Anding makes modulo 32 */
#define FC_FREE -1

void
fc_init (free_set_cache_t * fc)
{
  int inx;
  fc->fc_first_free = 0;
  fc->fc_replace_next = 0;
  for (inx = 0; inx < FC_SLOTS; inx++)
    fc->fc_free_around[inx] = FC_FREE;
}


void
fc_mark_free (dbe_storage_t * dbs, dp_addr_t dp)
{
  free_set_cache_t * fc = &dbs->dbs_free_cache;
  int inx;
  int free_at = -1;
  if (dp > dbs->dbs_n_pages - 32)
    return;
  dp = dp & FC_ENT_MASK;
  for (inx = 0; inx < FC_SLOTS; inx++)
    {
      if (dp == fc->fc_free_around[inx])
	return;
      if (FC_FREE == fc->fc_free_around[inx])
	free_at = inx;
    }
  if (free_at != -1)
    fc->fc_free_around[free_at] = dp;
}


int
word_free_bit (dp_addr_t w)
{
  int n;

  for (n = 0; w & 1; n++)
    w >>= 1;

  return n;
}


dp_addr_t
fc_lookup (dbe_storage_t * dbs)
{
  free_set_cache_t *fc = &dbs->dbs_free_cache;
  int ctr;
  uint32 *array;
  int bit, inx;
  dp_addr_t page_no;
  ASSERT_IN_MTX (dbs->dbs_page_mtx);

  for (ctr = 0; ctr < FC_SLOTS; ctr++)
    {
      if (fc->fc_free_around[ctr] == FC_FREE)
	continue;
      dbs_locate_free_bit (dbs, fc->fc_free_around[ctr], &array, &page_no,
	  &inx, &bit);
      if (array[inx] != 0xffffffff)
	{
	  bit = word_free_bit (array[inx]);
	  array[inx] |= ((uint32) 1) << bit;
	  dbs->dbs_n_free_pages--;
	  if (0xffffffff == array[inx])
	    fc->fc_free_around[ctr] = FC_FREE;
	  return (bit + (inx * BITS_IN_LONG) + (page_no * BITS_ON_PAGE));
	}
    }
  return 0;
}


long
dbs_count_pageset_items (dbe_storage_t * dbs, buffer_desc_t** ppage_set)
{
  dp_addr_t n = 0;
  dp_addr_t n_pages = dbs->dbs_n_pages;
  long free_count = 0;
  buffer_desc_t *free_set = ppage_set[0];
  uint32 *buf;
  uint32 buf_no, no_bufs;
  int l_idx, b_idx, no_longs;
  uint32 *d_a;
  dp_addr_t d_p;
  int d_i;

  no_bufs = n_pages / BITS_ON_PAGE;
  no_longs = BITS_ON_PAGE / BITS_IN_LONG;

  /* Done for side effect, last 4 args are not used */
  dbs_locate_free_bit (dbs, n_pages - 1, &d_a, &d_p, &d_i, &d_i);

  for (buf_no = 0; buf_no < no_bufs; buf_no++)
    {
      buf = (dp_addr_t *) (free_set->bd_buffer + DP_DATA);
      for (l_idx = 0; l_idx < no_longs; l_idx++)
	{
	  for (b_idx = 0; b_idx < BITS_IN_LONG; b_idx++)
	    {
	      n++;
	      if (0 == (buf [l_idx] & (1 << b_idx)))
		{
		  free_count++;
		}
	    }
	}
      if (free_set->bd_next)
	{
	  free_set = free_set->bd_next;
	}
      else
	{
	  return free_count;
	}
    }
  buf = (dp_addr_t *) (free_set->bd_buffer + DP_DATA);
  while (n < n_pages)
    {
      l_idx = (int) ((n % BITS_ON_PAGE) / BITS_IN_LONG);
      b_idx = (int) ((n % BITS_ON_PAGE) % BITS_IN_LONG);
      if (0 == (buf[l_idx] & (1 << b_idx)))
	free_count++;
      n++;
    }

  return free_count;
}
long dbs_count_free_pages (dbe_storage_t * dbs)
{
  long res;
  IN_DBS (dbs);
  res = dbs_count_pageset_items (dbs, &dbs->dbs_free_set);
  LEAVE_DBS (dbs);
  return res;
}

long
dbs_is_free_page (dbe_storage_t * dbs, dp_addr_t n)
{
  uint32 *array;
  dp_addr_t page;
  int inx, bit;
  if (n >= dbs->dbs_n_pages)
    return 1;
  dbs_locate_free_bit (dbs, n, &array, &page, &inx, &bit);
  if (0 == (array[inx] & (1 << bit)))
    return 1;
  return 0;
}


void
dbs_page_allocated (dbe_storage_t * dbs, dp_addr_t n)
{
  uint32 *array;
  dp_addr_t page;
  int inx, bit;
  dbs_locate_free_bit (dbs, n, &array, &page, &inx, &bit);
  array[inx] |= 1 << bit;
  dbs->dbs_n_free_pages--;
}


#if defined (WIN32)
int
ftruncate (int fh, long sz)
{
  return (chsize (fh, sz));
}

int
ftruncate64 (int fd, OFF_T length)
{
  int res = -1;

  if (length < 0)
    return -1;
  else
    {
      HANDLE h = (HANDLE)_get_osfhandle(fd);
      OFF_T prev_loc = LSEEK (fd, 0, SEEK_CUR);
      LSEEK (fd, length, SEEK_SET);
      if (!SetEndOfFile (h))
	return -1;
      else
	res = 0;
      LSEEK (fd, prev_loc, SEEK_SET);
    }
  return res;
}

#endif /* WIN32 */

static void
dbs_extend_pageset (dbe_storage_t * dbs, buffer_desc_t ** set, int offset)
{
  size_t n_pages = 0;
  buffer_desc_t *set_ptr;

  ASSERT_IN_DBS (dbs);

  for (set_ptr = *set; set_ptr; set_ptr = set_ptr->bd_next)
    n_pages += 1;
  while (dbs->dbs_n_pages / BITS_ON_PAGE >= n_pages)
    {
/*      int dp = *set ? (*set)->bd_physical_page : 0;*/
      dbs_page_set_extend (dbs, set, offset);
/*
      (*set)->bd_physical_page = dbs_get_free_disk_page_near (dbs, dp);
      if ((*set)->bd_physical_page > dbs->dbs_n_pages)
	GPF_T1 ("no free page for the freeset");
*/
      n_pages += 1;
    }
}

static void
dbs_extend_pagesets (dbe_storage_t * dbs)
{
  ASSERT_IN_DBS (dbs);
  dbs_extend_pageset (dbs, & dbs->dbs_free_set, 0);
  dbs_extend_pageset (dbs, & dbs->dbs_incbackup_set, 1);
}


OFF_T
dbs_extend_file (dbe_storage_t * dbs)
{
  static char blank[PAGE_SZ];
  OFF_T n;
  OFF_T new_file_length;
  if (dbs->dbs_disks)
    return dbs_extend_stripes (dbs);

  ASSERT_IN_DBS (dbs);
  mutex_enter (dbs->dbs_file_mtx);
  LSEEK (dbs->dbs_fd, 0, SEEK_END);
  for (n = 0; n < dbs->dbs_extend; n++)
    {
      new_file_length = dbs->dbs_file_length + PAGE_SZ;
/* IvAn/0/010111 Additional check added for some critical lengths of files.
E.g. Windows will fail to handle more than or equal to 2 Gb in one file.
Some ramdrive-like drivers and ncache-like disk-caches may die on shorter
length, NFS may die with 1.8Gb files on some obsolete VPNs.
For safety, integer overflow check added. */
      if (
        (PAGE_SZ != write (dbs->dbs_fd, (char *) blank, PAGE_SZ)) ||
#if 0
#ifdef WIN32
        ( !(new_file_length & 0x0FFFFFFFL) &&
	  (tell (dbs->dbs_fd) != new_file_length) ) ||
#endif
#endif
	(0L >= new_file_length)
         )
	{
	  FTRUNCATE (dbs->dbs_fd, dbs->dbs_file_length);
	  break;
	}
      dbs->dbs_n_free_pages++;
      dbs->dbs_file_length = new_file_length;
      dbs->dbs_n_pages++;
      dbs_extend_pagesets (dbs);
    }
  mutex_leave (dbs->dbs_file_mtx);
  return n;
}

OFF_T growup_stripe_size (OFF_T x, double ratio, long n, long min_ext)
{
  OFF_T newx = (OFF_T) (x * ratio);

  if (newx%n)
    newx = (newx + (n-(newx%n)));
  if ((newx-x) < min_ext)
    return x+min_ext;
  return newx;
}


long stripe_growth_ratio;

static OFF_T
dbs_next_size (dbe_storage_t* dbs, disk_segment_t * ds, OFF_T * n)
{
  OFF_T new_size =  growup_stripe_size (ds->ds_size , (100.0 + stripe_growth_ratio) / 100, ds->ds_n_stripes, dbs->dbs_extend);
  n[0] = new_size - ds->ds_size;
  return new_size / ds->ds_n_stripes * PAGE_SZ;
}


OFF_T
dbs_extend_stripes (dbe_storage_t * dbs)
{
  disk_segment_t * ds = dbs->dbs_last_segment;
  OFF_T n = 0;
  OFF_T stripe_next_size = dbs_next_size(dbs,ds,&n);
  long inx;
  long new_pages = 0;
  static char* zero = 0;
  if (!stripe_growth_ratio)
    {
      log_error ("Cannot extend stripe with ratio %ld", stripe_growth_ratio);
      return -1;
    }
  if (!zero)
    {
      zero = (char *) dk_alloc (PAGE_SZ);
      memset (zero, 0, PAGE_SZ);
    }
  DO_BOX (disk_stripe_t *, dst, inx, ds->ds_stripes)
    {
      OFF_T stripe_size = (OFF_T) (ds->ds_size / ds->ds_n_stripes) * PAGE_SZ;
      if (!ds)
	{
	  log_error ("The segment has too few stripes.");
	  exit (1);
	}
      LSEEK (dst->dst_fds[0], 0, SEEK_END);
      while (stripe_size < stripe_next_size)
	{
	  int rc;
	  rc = write (dst->dst_fds[0], zero, PAGE_SZ);
	  if (rc != PAGE_SZ)
	    {
	 	char * err;
	      FTRUNCATE (dst->dst_fds[0], stripe_size);
	      err = strerror (errno);
	      log_error ("Cannot extend stripe on %s to %ld", dst->dst_file, stripe_next_size);
	      return -1;
	    }
	  stripe_size += PAGE_SZ;
	  new_pages ++;
	}
    }
  END_DO_BOX;
#if 1
  dbs->dbs_n_pages += new_pages / ds->ds_n_stripes;
  dbs->dbs_n_free_pages += new_pages / ds->ds_n_stripes;
#else
  dbs->dbs_n_pages += new_pages;
  dbs->dbs_n_free_pages += new_pages;
#endif
  ds->ds_size = (dp_addr_t) ( stripe_next_size / PAGE_SZ * ds->ds_n_stripes);
  dbs_extend_pagesets (dbs);
  return n;
}



void
itc_hold_pages (it_cursor_t * itc, buffer_desc_t * buf, int n)
{
  dbe_storage_t * dbs = itc->itc_space->isp_tree->it_storage;
  IN_DBS (dbs);
  FAILCK (itc);
  if (dbs->dbs_n_free_pages - dbs->dbs_n_pages_on_hold > (uint32) n)
    {
      itc->itc_n_pages_on_hold += n;
      dbs->dbs_n_pages_on_hold += n;
    }
  else
    {
      dbs_extend_file (dbs);
      wi_storage_offsets ();
      if (dbs->dbs_n_free_pages - dbs->dbs_n_pages_on_hold > (uint32) n)
	{
	  dbs->dbs_n_pages_on_hold += n;
	  itc->itc_n_pages_on_hold += n;
	}
      else
	{
	  LEAVE_DBS (dbs);
	  log_error ("Out of disk space for database");
	  if (itc->itc_ltrx)
	    itc->itc_ltrx->lt_error = LTE_NO_DISK; /* could be temp isp, no ltrx */
	  itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
	}
    }
  LEAVE_DBS (dbs);
}


void
itc_free_hold (it_cursor_t * itc)
{
  dbe_storage_t * dbs = itc->itc_space->isp_tree->it_storage;
  IN_DBS (dbs);
  dbs->dbs_n_pages_on_hold -= itc->itc_n_pages_on_hold;
  itc->itc_n_pages_on_hold = 0;
  if (dbs->dbs_n_pages_on_hold > dbs->dbs_n_pages) /* unsigned underflowed  into negative */
    GPF_T1 ("pages on hold < 0");
  LEAVE_DBS (dbs);
}


void
itc_check_disk_space (it_cursor_t * itc, buffer_desc_t * buf, int n)
{
  dbe_storage_t * dbs = itc->itc_space->isp_tree->it_storage;
  FAILCK (itc);
  if (dbs->dbs_n_free_pages - dbs->dbs_n_pages_on_hold < (uint32) n)
    {
      itc->itc_ltrx->lt_error = LTE_NO_DISK;
      itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
    }
}


dp_addr_t
dbs_get_free_disk_page_near (dbe_storage_t * dbs, dp_addr_t near_dp)
{
  dp_addr_t dp;
  /* Look both sides of near. If there's nothing, start at the beginning. */
  buffer_desc_t *free_buf;
  uint32 *page;
  dp_addr_t page_no;
  int word;
  int bit;
  ASSERT_IN_DBS (dbs);
  bit = -1;
  if (near_dp > 45 && near_dp > dbs->dbs_n_pages - 40)
    near_dp -= 40;
  dbs_locate_free_bit (dbs, near_dp, &page, &page_no, &word, &bit);
  if (page[word] != 0xffffffff)
    {
      bit = word_free_bit (page[word]);
    }
  else
    {
      dp_addr_t cached = fc_lookup (dbs);
      if (cached)
	return cached;
      page_no = 0;
      free_buf = dbs->dbs_free_set;
      while (free_buf)
	{
	  page = (uint32 *) (free_buf->bd_buffer + DP_DATA);
	  for (word = 0; word < LONGS_ON_PAGE; word++)
	    {
	      if (page[word] != 0xffffffff)
		{
		  bit = word_free_bit (page[word]);
		  goto bit_found;
		}
	    }
	  if (!free_buf->bd_next)
	    dbs_extend_pagesets (dbs);
	  free_buf = free_buf->bd_next;
	  page_no++;
	}

    }
bit_found:
  page[word] |= ((uint32) 1) << bit;
  dbs->dbs_n_free_pages--;
  dp = (bit + (word * BITS_IN_LONG) + (page_no * BITS_ON_PAGE));
  if (page[word] != 0xffffffff)
    fc_mark_free (dbs, dp);
  return dp;
}

dp_addr_t
dbs_get_free_disk_page (dbe_storage_t * dbs, dp_addr_t near_dp)
{
  dp_addr_t first;

  IN_DBS (dbs);
  first = dbs_get_free_disk_page_near (dbs, near_dp);
  if (first >= dbs->dbs_n_pages)
    {
      dbs_extend_file (dbs);
      wi_storage_offsets ();
      if (first >= dbs->dbs_n_pages)
	{
	  dbs_free_disk_page (dbs, first);
	  first = dbs_get_free_disk_page_near (dbs, 0);
	  if (first >= dbs->dbs_n_pages)
	    {
	      dbs_free_disk_page (dbs, first);
	      first = 0;
	    }
	}
    }
  LEAVE_DBS (dbs);
#ifdef DEBUG
  /* not really allowed but not fatal enough to gpf */
  if (first && dp_backup_flag (dbs, first))
    GPF_T1 ("Should not have backup change flag on for a freshly allocated page");
#endif
  return first;
}


long disk_releases = 0;
void
dbs_free_disk_page (dbe_storage_t * dbs, dp_addr_t dp)
{
  uint32 *page;
  int word;
  dp_addr_t page_no;
  int bit;
  IN_DBS (dbs);
  ASSERT_IN_DBS (dbs);
  if (dp == 0)
    GPF_T1 ("Freeing zero page");
  if (dp > dbs->dbs_n_pages)
    {
      log_info ("Freeing dp out of range %d ", dp);
      return;
    }
  dbs_locate_free_bit (dbs, dp, &page, &page_no, &word, &bit);

#ifndef NDEBUG
  /* GK: way to catch a double free of disk page */
  if (!(page[word] & (1 << bit)))
    GPF_T1 ("Double free of disk page.");
#endif
  page[word] &= ~(1 << bit);
  dbs->dbs_n_free_pages++;
  disk_releases++;
  fc_mark_free (dbs, dp);
}


dp_addr_t
bd_phys_page_key (buffer_desc_t * b)
{
  return (b->bd_physical_page + b->bd_storage->dbs_dp_sort_offset);
}


void
buf_bsort (buffer_desc_t ** bs, int n_bufs, sort_key_func_t key)
{
  /* Bubble sort n_bufs first buffers in the array. */
  int n, m;
  for (m = n_bufs - 1; m > 0; m--)
    {
      for (n = 0; n < m; n++)
	{
	  buffer_desc_t *tmp;
	  if (key (bs[n]) > key (bs[n + 1]))
	    {
	      tmp = bs[n + 1];
	      bs[n + 1] = bs[n];
	      bs[n] = tmp;
	    }
	}
    }
}


void
buf_qsort (buffer_desc_t ** in, buffer_desc_t ** left,
    int n_in, int depth, sort_key_func_t key)
{
  if (n_in < 2)
    return;
  if (n_in < 3)
    {
      if (key (in[0]) > key (in[1]))
	{
	  buffer_desc_t *tmp = in[0];
	  in[0] = in[1];
	  in[1] = tmp;
	}
    }
  else
    {
      dp_addr_t split;
      buffer_desc_t *mid_buf = NULL;
      int n_left = 0, n_right = n_in - 1;
      int inx;
      if (depth > 60)
	{
	  buf_bsort (in, n_in, key);
	  return;
	}

      split = key (in[n_in / 2]);

      for (inx = 0; inx < n_in; inx++)
	{
	  dp_addr_t this_pg = key (in[inx]);
	  if (!mid_buf && this_pg == split)
	    {
	      mid_buf = in[inx];
	      continue;
	    }
	  if (this_pg <= split)
	    {
	      left[n_left++] = in[inx];
	    }
	  else
	    {
	      left[n_right--] = in[inx];
	    }
	}
      buf_qsort (left, in, n_left, depth + 1, key);
      buf_qsort (left + n_right + 1, in + n_right + 1,
	  (n_in - n_right) - 1, depth + 1, key);
      memcpy (in, left, n_left * sizeof (caddr_t));
      in[n_left] = mid_buf;
      memcpy (in + n_right + 1, left + n_right + 1,
	  ((n_in - n_right) - 1) * sizeof (caddr_t));

    }
}


dk_mutex_t *buf_sort_mtx;
buffer_desc_t **left_bufs;


void
buf_sort (buffer_desc_t ** bs, int n_bufs, sort_key_func_t key)
{
  mutex_enter (buf_sort_mtx);
  if (!left_bufs)
    {
      left_bufs = (buffer_desc_t **) dk_alloc (sizeof (caddr_t) * main_bufs);
    }
  buf_qsort (bs, left_bufs, n_bufs, 0, key);
  mutex_leave (buf_sort_mtx);
}


long last_flush_time = 0;


void
bp_write_dirty (buffer_pool_t * bp, int force, int is_in_bp, int n_oldest)
{
  /* Locate, sort and write dirty buffers. */
  size_t bufs_len = sizeof (caddr_t) * bp->bp_n_bufs;
  buffer_desc_t **bufs = (buffer_desc_t **) dk_alloc (bufs_len);
  buffer_desc_t *buf;
  int fill = 0, n, page_ctr = 0, inx;
  if (!is_in_bp)
    mutex_enter (bp->bp_mtx);

  for (inx = 0; inx < bp->bp_n_bufs; inx++)
    {
      buf = &bp->bp_bufs[inx];
      if (force)
	{
	  if (buf->bd_is_dirty)
	    bufs[fill++] = buf;
	}
      else
	{
	  /* Be civilized. Get read access for the time to write */
	  index_space_t * isp = buf->bd_space;
	  if (isp)
	    {
	      IN_PAGE_MAP (isp->isp_tree);
	      if (buf->bd_is_dirty
		  && !buf->bd_in_write_queue
		  && !buf->bd_iq)
		{
		  if (!buf->bd_is_write &&
		      !buf->bd_write_waiting)
		    {
		      buf->bd_readers++;
		      bufs[fill++] = buf;
		    }
		}
	      LEAVE_PAGE_MAP (isp->isp_tree);
	    }
	}
      page_ctr++;
    }
  buf_sort (bufs, fill, (sort_key_func_t) bd_phys_page_key);

  if (fill)
    {
      dbg_printf (("     Flush %d buffers, pages %ld - %ld.\n", fill,
	      bufs[0]->bd_page, bufs[fill - 1]->bd_page));
    }
  for (n = 0; n < fill; n++)
    {
      /* dbg_printf ((" %ld ", bufs [n] -> bd_physical_page));  */
      buf_disk_write (bufs[n], 0);
      bufs[n]->bd_is_dirty = 0;
      wi_inst.wi_n_dirty--;
      if (!force)
	{
	  index_space_t * isp = bufs[n]->bd_space;
	  IN_PAGE_MAP (isp->isp_tree);
	  page_leave_inner (bufs[n]);
	  LEAVE_PAGE_MAP (isp->isp_tree);
	}
    }
  dk_free (bufs, bufs_len);
  last_flush_time = approx_msec_real_time ();
  if (!is_in_bp)
    mutex_leave (bp->bp_mtx);
}


int
dbs_open_disks (dbe_storage_t * dbs)
{
  dtp_t zero[PAGE_SZ];
  int inx;
  dp_addr_t pages = 0;
  int first_exists = 0;
  int is_first = 1;
  memset (zero, 0, sizeof (zero));
  DO_SET (disk_segment_t *, ds, &dbs->dbs_disks)
  {
    OFF_T stripe_size = ( (OFF_T) ds->ds_size / ds->ds_n_stripes) * PAGE_SZ;
    dp_addr_t actual_segment_size = 0;
    DO_BOX (disk_stripe_t *, dst, inx, ds->ds_stripes)
    {
      OFF_T org_size;
      OFF_T size;
      if (!ds)
	{
	  log_error ("The segment has too few stripes.");
	  call_exit (1);
	}
      if (!dst->dst_fds)
	{
	  int inx;
	  file_set_rw (dst->dst_file);
	  dst->dst_sem = semaphore_allocate (0);
	  dst->dst_fds = (int*) dk_alloc_box_zero (sizeof (int) * n_fds_per_file, DV_CUSTOM);
	  dst->dst_fd_fill = 0;
	  for (inx = 0; inx < n_fds_per_file; inx++)
	    {
	      int fd = fd_open (dst->dst_file, OPEN_FLAGS);
	      if (-1 == fd)
		{
		  log_error ("Cannot open stripe on %s (%d)",
			     dst->dst_file, errno);
		  call_exit (1);
		}
	      dst_fd_done (dst, fd);
	    }
	}
      size = LSEEK (dst->dst_fds[0], 0, SEEK_END);
      if (size)
	{
	  if (is_first)
	    first_exists = 1;
	}
      if (size < stripe_size)
	{
	  LSEEK (dst->dst_fds[0], PAGE_SZ * (size / PAGE_SZ), SEEK_SET);
	  org_size = size;
	  while (size < stripe_size)
	    {
	      int rc;
	      rc = write (dst->dst_fds[0], zero, PAGE_SZ);
	      if (rc != PAGE_SZ)
		{
		  FTRUNCATE (dst->dst_fds[0], org_size);
#ifndef FILE64
		  log_error ("Cannot extend stripe on %s to %ld", dst->dst_file, stripe_size);
#else
		  log_error ("Cannot extend stripe on %s to %lld", dst->dst_file, stripe_size);
#endif
		  return -1;
		}
	      size += PAGE_SZ;
	    }
	}
      actual_segment_size += (dp_addr_t) ( size / PAGE_SZ );
      is_first = 0;
    }
    END_DO_BOX;
    ds->ds_size = actual_segment_size;
    pages += ds->ds_size;
    dbs->dbs_last_segment = ds;
  }
  END_DO_SET ();
  dbs->dbs_n_pages = pages;
  return first_exists;
}


void
dbs_close_disks (dbe_storage_t * dbs)
{
  int inx;
  DO_SET (disk_segment_t *, seg, &dbs->dbs_disks)
  {
    DO_BOX (disk_stripe_t *, dst, inx, seg->ds_stripes)
    {
      int inx;
      for (inx = 0; inx < n_fds_per_file; inx++)
	{
	  int fd = dst_fd (dst);
	  fd_close (fd, dst->dst_file);
	}
    }
    END_DO_BOX;
  }
  END_DO_SET ();
}

int32 bp_n_bps = 4;

void
dbs_sync_disks (dbe_storage_t * dbs)
{
#ifdef HAVE_FSYNC
  int inx;

  switch (c_checkpoint_sync)
    {
    case 0:
	/* NO SYNC */
	break;

    case 1:
      sync();
      break;

    case 2:
    default:
      if (dbs->dbs_disks)
	{
	  DO_SET (disk_segment_t *, seg, &dbs->dbs_disks)
	    {
	      DO_BOX (disk_stripe_t *, dst, inx, seg->ds_stripes)
		{
		  fsync (dst->dst_fds[0]);
		}
	      END_DO_BOX;
	    }
	  END_DO_SET ();
	}
      else
	{
	  fsync (dbs->dbs_fd);
	}
    }
#endif
}

int
dbs_byte_order_cmp (char byte_order)
{
  if (byte_order != DB_ORDER_UNKNOWN && byte_order != DB_SYS_BYTE_ORDER)
    return -1;
  return 0;
}

void
dbs_write_cfg_page (dbe_storage_t * dbs, int is_first)
{
  disk_stripe_t *dst = NULL;
  wi_database_t db;
  int fd;
  if (dbs->dbs_disks)
    {
      OFF_T off;
      dst = dp_disk_locate (dbs, 0, &off);
      fd = dst_fd (dst);
    }
  else
    fd = dbs->dbs_fd;
  memset (&db, 0, sizeof (db));
  strcpy_ck (db.db_ver, DBMS_SRV_VER_ONLY);
  strcpy_ck (db.db_generic, DBMS_STORAGE_VER);
  db.db_registry = dbs->dbs_registry;
  db.db_free_set = dbs->dbs_free_set->bd_page;
  db.db_incbackup_set = dbs->dbs_incbackup_set->bd_page;
  if (bp_ctx.db_bp_ts)
    {
      strncpy (db.db_bp_prfx, bp_ctx.db_bp_prfx, BACKUP_PREFIX_SZ);
      db.db_bp_ts =  bp_ctx.db_bp_ts;
      db.db_bp_pages =  bp_ctx.db_bp_pages;
      db.db_bp_num =  bp_ctx.db_bp_num;
      db.db_bp_date = bp_ctx.db_bp_date;
      db.db_bp_index = bp_ctx.db_bp_index;
      db.db_bp_wr_bytes = bp_ctx.db_bp_wr_bytes;
    }
  db.db_checkpoint_map = dbs->dbs_cp_remap_pages ? (dp_addr_t) (uptrlong) dbs->dbs_cp_remap_pages->data : 0;
  db.db_byte_order = DB_SYS_BYTE_ORDER;

  LSEEK (fd, 0, SEEK_SET);
#ifdef BYTE_ORDER_REV_SUPPORT
  if (dbs_reverse_db == 1)
    write (fd, (char *) &rev_cfg, sizeof (db));
  else
#endif
    write (fd, (char *) &db, sizeof (db));
  if (dst)
    dst_fd_done (dst, fd);
}


short less_than_any[] = {0, KI_LEFT_DUMMY, 0, 0};
/* the dummy + 2 zero shorts for the null leaf pointer */

void
pg_init_new_root (buffer_desc_t * buf)
{
  db_buf_t page = buf->bd_buffer;
  memcpy (page + DP_DATA, less_than_any, sizeof (less_than_any));
  SHORT_SET (page + DP_FIRST, DP_DATA);
  pg_make_map (buf);
}


#ifdef BYTE_ORDER_REV_SUPPORT


static void
dbs_reverse_cfg_page (wi_database_t * cfg_page)
{
  DBS_REVERSE_LONG ((db_buf_t)(&cfg_page->db_root));
  DBS_REVERSE_LONG ((db_buf_t)&cfg_page->db_checkpoint_root);
  DBS_REVERSE_LONG ((db_buf_t)&cfg_page->db_free_set);
  DBS_REVERSE_LONG ((db_buf_t)&cfg_page->db_incbackup_set);
  DBS_REVERSE_LONG ((db_buf_t)&cfg_page->db_registry);
  DBS_REVERSE_LONG ((db_buf_t)&cfg_page->db_checkpoint_map);
  DBS_REVERSE_LONG ((db_buf_t)&cfg_page->db_last_id);
  DBS_REVERSE_LONG ((db_buf_t)&cfg_page->db_bp_ts);
  DBS_REVERSE_LONG ((db_buf_t)&cfg_page->db_bp_num);
  DBS_REVERSE_LONG ((db_buf_t)&cfg_page->db_bp_pages);
  DBS_REVERSE_LONG ((db_buf_t)&cfg_page->db_bp_date);
  cfg_page->db_byte_order = DB_SYS_BYTE_ORDER;
  memcpy (&rev_cfg, cfg_page, sizeof (wi_database_t));
}

/*??? static void
dbs_reverse_whole_database (dbe_storage_t * dbs, wi_database_t * cfg_page)
{
  dbs_reverse_cfg_page (cfg_page);
} */

#define KEY_COL_RESET_NA(key, row_data, cl, off, len) \
{ \
  len = cl.cl_fixed_len; \
  if (len > 0) \
    { \
      off = cl.cl_pos; \
    } \
  else if (CL_FIRST_VAR == len) \
    { \
      off = key->key_row_var_start; \
      DBS_REVERSE_SHORT (row_data + key->key_length_area); \
      len = SHORT_REF (row_data + key->key_length_area) - off; \
      if (len < 0) { _e = 1; len = 0; SHORT_SET (row_data + key->key_length_area, off); }; \
    } \
  else \
    { \
      len = -len; \
      DBS_REVERSE_SHORT (row_data + len); \
      DBS_REVERSE_SHORT (row_data + len + 2); \
      off= SHORT_REF (row_data + len); \
      if (off < 0) { _e = 1; off = 0; SHORT_SET (row_data + len, 0); }\
      len = SHORT_REF (row_data + len + 2) - off; \
      if ((len < 0) || ((off+len) > ROW_MAX_DATA + 2 )) {_e=1; len = 0; SHORT_SET (row_data - cl.cl_fixed_len + 2, off); }\
      /* GK: the +2 part in ROW_MAX_DATA is nessesary to allow reverse of oversized rows */ \
    } \
}

static
void row_na_length(db_buf_t row, dbe_key_t *key, db_buf_t * off)
{
  int len;
  key_id_t key_id = DBS_REV_SHORT_REF (row + IE_KEY_ID);
  if (!key_id)
    {
      len = key->key_key_len;
      if (len <= 0)
	len = IE_LEAF + 4 + DBS_REV_SHORT_REF ((row - len) + IE_LP_FIRST_KEY);
    }
  else if (key_id == KI_LEFT_DUMMY)
    {
      len = 8;
    }
  else
    {
      dbe_key_t * row_key;
      if (key_id != key->key_id)
	row_key = sch_id_to_key (wi_inst.wi_schema, key_id);
      else
	row_key = key;
      len = row_key->key_row_len;
      if (len <= 0)
	{
		;
	}
    }
}


int dbs_reset_row_na (db_buf_t row, dbe_key_t * page_key)
{
  db_buf_t orig_row = row;
  key_id_t key_id = DBS_REV_SHORT_REF (orig_row + IE_KEY_ID);
  dbe_col_loc_t * cl;
  int inx = 0, off, len;
  dbe_key_t * row_key = page_key;

  DBS_REVERSE_SHORT (row + IE_NEXT_IE);


  if (key_id && key_id != page_key->key_id)
    {
      row_key = sch_id_to_key (wi_inst.wi_schema, key_id);
      if (!row_key)
	{
	  DBS_REVERSE_SHORT (orig_row + IE_KEY_ID);
	  if (key_id != KI_LEFT_DUMMY && key_id)
	    {
	      /* looks like the page is inconsistent */
	      log_error ("Inconsistent row [unknown row key %d], skipped...", key_id);
	      return IE_NEXT (orig_row);
	    }
	}
    }
  row_na_length (row, row_key, 0);

  if (key_id)
    row += 4;
  else
    row += 8;

  DBS_REVERSE_SHORT (orig_row + IE_KEY_ID);

  if (KI_LEFT_DUMMY == key_id)
    {
      DBS_REVERSE_LONG (orig_row + IE_LEAF);
      return IE_NEXT (orig_row);
    }
  DO_SET (dbe_column_t *, col, &row_key->key_parts)
    {
      if (!key_id && ++inx > row_key->key_n_significant)
	break;
      cl = key_find_cl (row_key, col->col_id);
      if (!key_id)
	{
	  len = cl->cl_fixed_len;
	  if (len > 0)
	    {
	      off = cl->cl_pos;
	    }
	  else if (CL_FIRST_VAR == len)
	    {
	      off = row_key->key_key_var_start;
	      DBS_REVERSE_SHORT (row + row_key->key_length_area);
	      len = SHORT_REF (row + row_key->key_length_area) - off;
	    }
	  else
	    {
	      len = -len;
	      DBS_REVERSE_SHORT (row + len);
	      DBS_REVERSE_SHORT (row + len + 2);
	      off = SHORT_REF (row + len);
	      len = SHORT_REF (row + len + 2) - off;
	    }
	}
      else
	{
	  int _e = 0;
	  KEY_COL_RESET_NA (row_key, row, (*cl), off, len);
  	  if (_e)
	    return IE_NEXT(orig_row);
	  KEY_COL (row_key, row, (*cl), off, len);
	  if (cl->cl_null_mask && row[cl->cl_null_flag] & cl->cl_null_mask)
	    {
	      goto next;
	    }
	}
      switch (cl->cl_sqt.sqt_dtp)
	{
	case DV_SHORT_INT:
	  DBS_REVERSE_SHORT (row + off);
	  break;
	case DV_LONG_INT:
	  DBS_REVERSE_LONG (row + off);
	  break;
	case DV_ARRAY_OF_LONG:
	  {
	    int inx;
	    for (inx = 0; inx < len; inx += 4)
	      DBS_REVERSE_LONG (row + off + inx);
	  }
	  break;
	default:
	  break;
	}
    next: ;
    }
  END_DO_SET();
  if (!key_id)
    {
      DBS_REVERSE_LONG (orig_row + IE_LEAF);
    }
  return IE_NEXT (orig_row);
}
void dbs_rev_h_index  (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  if (buf->bd_physical_page && dbs_is_free_page (dbs, buf->bd_physical_page))
		return;
  if (gethash (DP_ADDR2VOID (buf->bd_physical_page), dbs->dbs_cpt_remap))
		return;
  DBS_REVERSE_LONG (buf->bd_buffer + DP_PARENT);

  DBS_REVERSE_SHORT (buf->bd_buffer + DP_RIGHT_INSERTS);
  DBS_REVERSE_SHORT (buf->bd_buffer + DP_LAST_INSERT);

  DBS_REVERSE_SHORT (buf->bd_buffer + DP_FLAGS);
  DBS_REVERSE_SHORT (buf->bd_buffer + DP_FIRST);

  DBS_REVERSE_SHORT (buf->bd_buffer + DP_KEY_ID);

  DBS_REVERSE_LONG (buf->bd_buffer + DP_OVERFLOW);

  h_index = 1;
#if 1
  if (!row_hash)
	row_hash = hash_table_allocate (1001);
  else
	clrhash(row_hash);
#else
	row_hash = hash_table_allocate (1001);
#endif
  {
    db_buf_t page = buf->bd_buffer;
    key_id_t pg_key_id = SHORT_REF (page + DP_KEY_ID);
    dbe_key_t * pg_key = KI_TEMP == pg_key_id ?  buf->bd_space->isp_tree->it_key
      : sch_id_to_key (wi_inst.wi_schema, pg_key_id);
    int pos = SHORT_REF (page + DP_FIRST);

    if (!pg_key)
	{
		h_index = 0;
      		return;
	}

    /* iterate over rows */
    while (pos > 0)
      {
	if (pos > PAGE_SZ)
	  {
	    log_error ("Link over end. Inconsistent page.");
	    break;
	  }
	pos = dbs_reset_row_na (page + pos, pg_key);
      }
  }
  h_index = 0;
}

void dbs_rev_h_free_set  (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  int inx;
  DBS_REVERSE_SHORT (buf->bd_buffer + DP_FLAGS);
  DBS_REVERSE_LONG (buf->bd_buffer + DP_OVERFLOW);
  for (inx = DP_DATA; inx <= PAGE_SZ - sizeof (uint32); inx += sizeof (uint32))
    {
      DBS_REVERSE_LONG (buf->bd_buffer + inx);
    }
}
void dbs_rev_h_ext (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  GPF_T1 ("not implemented");
}
void dbs_rev_h_blob (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  DBS_REVERSE_LONG (buf->bd_buffer + DP_PARENT);
  DBS_REVERSE_LONG (buf->bd_buffer + DP_BLOB_TS);
  DBS_REVERSE_SHORT (buf->bd_buffer + DP_FLAGS);
  DBS_REVERSE_SHORT (buf->bd_buffer + DP_FIRST);
  DBS_REVERSE_LONG (buf->bd_buffer + DP_BLOB_LEN);
  DBS_REVERSE_LONG (buf->bd_buffer + DP_OVERFLOW);
}
void dbs_rev_h_free (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  GPF_T1 ("not implemented");
}
void dbs_rev_h_head (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  GPF_T1 ("not implemented");
}

void dbs_rev_h_remap (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  int inx;
  for (inx = DP_DATA; inx <= PAGE_SZ - 8; inx += 8)
    {
      DBS_REVERSE_LONG (buf->bd_buffer + inx);
      DBS_REVERSE_LONG (buf->bd_buffer + inx + 4);
    }
  DBS_REVERSE_SHORT (buf->bd_buffer + DP_FLAGS);
  DBS_REVERSE_LONG (buf->bd_buffer + DP_OVERFLOW);
}
void  dbs_rev_h_blob_dir (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  /* ???? is blob dir the same as blob */
  DBS_REVERSE_LONG (buf->bd_buffer + DP_PARENT);
  DBS_REVERSE_LONG (buf->bd_buffer + DP_BLOB_TS);
  DBS_REVERSE_SHORT (buf->bd_buffer + DP_FLAGS);
  DBS_REVERSE_SHORT (buf->bd_buffer + DP_FIRST);
  DBS_REVERSE_LONG (buf->bd_buffer + DP_BLOB_LEN);
  DBS_REVERSE_LONG (buf->bd_buffer + DP_OVERFLOW);

  {
    long items_on_page = (LONG_REF (buf->bd_buffer + DP_BLOB_LEN)) / sizeof (dp_addr_t);
    if (items_on_page)
      {
	int i;
	for (i = 0; i < items_on_page; i++)
	  {
	    DBS_REVERSE_LONG (buf->bd_buffer + DP_DATA + i * sizeof (dp_addr_t));
	  }
      }
  }
}
void dbs_rev_h_incbackup (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  int inx;
  DBS_REVERSE_SHORT (buf->bd_buffer + DP_FLAGS);
  DBS_REVERSE_LONG (buf->bd_buffer + DP_OVERFLOW);
  for (inx = DP_DATA; inx <= PAGE_SZ - sizeof (uint32); inx += sizeof (uint32))
    {
      DBS_REVERSE_LONG (buf->bd_buffer + inx);
    }
}

void
dbs_write_reverse_db (dbe_storage_t * dbs)
{
  dp_addr_t page_no;
  buffer_desc_t * buf = buffer_allocate (0);
  int pc = 0;
  dbs_write_cfg_page (dbs, 0);
  pc++;

  for (page_no = 1; page_no < dbs->dbs_n_pages; page_no++)
    {
      buf->bd_storage = dbs;
      buf->bd_page = buf->bd_physical_page = page_no;
      if (WI_OK == ol_buf_disk_read (buf))
	{
	  (dbs_reverse_page_header[DBS_REV_SHORT_REF(buf->bd_buffer+DP_FLAGS)]) (dbs, buf);
	  buf_disk_raw_write (buf);
	  pc++;
	}
      else
	GPF_T1 ("error in reading page");
    }
  log_info ("%ld pages in database have been processed", pc);
}


#endif

void
dbs_read_cfg_page (dbe_storage_t * dbs, wi_database_t * cfg_page)
{
  disk_stripe_t *dst = NULL;
  int storage_ver;
  int fd;
  if (dbs->dbs_disks)
    {
      OFF_T off;
      dst = dp_disk_locate (dbs, 0, &off);
      fd = dst_fd (dst);
    }
  else
    fd = dbs->dbs_fd;
  LSEEK (fd, 0, SEEK_SET);
  read (fd, (char *) cfg_page, sizeof (wi_database_t));

  storage_ver = atoi (cfg_page->db_generic);
  if (storage_ver > atoi (DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR))
    {
      log_error ("Opening database in format v. %s with older server. Exiting.",
		 storage_ver);
      call_exit (-1);
    }
  if (cfg_page->db_byte_order != DB_ORDER_UNKNOWN && cfg_page->db_byte_order != DB_SYS_BYTE_ORDER)
    {
#ifdef BYTE_ORDER_REV_SUPPORT
      log_error ("The database file was produced on a system with different byte order. Reverting...");
      dbs_reverse_db = 1;
#else
      log_error ("The database file was produced on a system with different byte order. Exiting.");
      call_exit (-1);
#endif /* BYTE_ORDER_REV_SUPPORT */
    }
  if (dst)
    dst_fd_done (dst, fd);
}


buffer_desc_t *cp_buf;

char * db_version_string = DBMS_SRV_VER_ONLY;

volatile int db_exists = 0;

void
wi_storage_offsets ()
{
  /* give each storage a sort offset so they get flushed in order */
  dp_addr_t total = 0;
  DO_SET (wi_db_t *, wd, &wi_inst.wi_dbs)
    {
      DO_SET (dbe_storage_t *, dbs, &wd->wd_storage)
	{
	  dbs->dbs_dp_sort_offset = total;
	  total += dbs->dbs_n_pages;
	}
      END_DO_SET();
    }
  END_DO_SET();
  if (wi_inst.wi_temp)
    wi_inst.wi_temp->dbs_dp_sort_offset = total;
}

long temp_db_size = 0;

#define CHECK_PG(pg,name) \
      if (cfg_page.pg < 1 || cfg_page.pg > dbs->dbs_n_pages) \
	{ \
	  log_error ( \
	      "The %s database has invalid first " name " page pointer %ld." \
	      "This is probably caused by a corrupted file data.", \
	      dbs->dbs_name, (long) cfg_page.pg); \
	  call_exit (1); \
	}

dbe_storage_t *
dbs_from_file (char * name, char * file, char type, volatile int * exists)
{
  wi_database_t cfg_page;
  OFF_T size;
  int fd;
  dbe_storage_t * dbs = dbs_allocate (name, type);
  *exists = 0;
  if (!file)
    file = CFG_FILE;
  dbs_read_cfg ((caddr_t *) dbs, file);
  if (dbs->dbs_disks)
    {
      *exists = dbs_open_disks (dbs);
    }
  else
    {
      file_set_rw (dbs->dbs_file);
      if (DBS_TEMP == type)
	{
	  caddr_t sz = file_stat (dbs->dbs_file, 1);

	  if (sz && strtol (sz, (char **)NULL, 10) > temp_db_size * 1024L * 1024L)
	    {
	      if (unlink (dbs->dbs_file))
		{
		  log_error ("Can't unlink the temp db file %.1000s : %m", dbs->dbs_file);
		}
	      else
		log_info ("Unlinked the temp db file %.1000s as it's size (%s)"
		    " was greater than TempDBSize INI (%ldMB)",
		    dbs->dbs_file, sz, temp_db_size);
	    }
	  dk_free_box (sz);
	}

      fd = fd_open (dbs->dbs_file, OPEN_FLAGS);
      if (-1 == fd)
	{
	  log_error ("Cannot open database in %s (%d)", dbs->dbs_file, errno);
	  call_exit (1);
	}
      dbs->dbs_fd = fd;
      size = LSEEK (fd, 0L, SEEK_END);
      dbs->dbs_file_length = size;
      dbs->dbs_n_pages = (dp_addr_t ) (dbs->dbs_file_length / PAGE_SZ);
      if (size)
	*exists = 1;
    }
  if (*exists && DBS_TEMP != type)
    {
      /* There's a file. */
      dbs_read_cfg_page (dbs, &cfg_page);

#ifdef BYTE_ORDER_REV_SUPPORT
      if (dbs_reverse_db)
	dbs_reverse_cfg_page (&cfg_page);
#endif
      /* some consistency checks for the DB file */
      CHECK_PG (db_free_set, "free set");
      CHECK_PG (db_incbackup_set, "incbackup set");

      db_version_string = box_dv_short_string (cfg_page.db_ver);

      dbs->dbs_registry = cfg_page.db_registry;
      dbs->dbs_free_set = dbs_read_page_set (dbs, cfg_page.db_free_set, DPF_FREE_SET);
      dbs->dbs_incbackup_set = dbs_read_page_set (dbs, cfg_page.db_incbackup_set, DPF_INCBACKUP_SET);
      if (cfg_page.db_bp_ts)
	{
	  strncpy (bp_ctx.db_bp_prfx, cfg_page.db_bp_prfx, BACKUP_PREFIX_SZ);
	  bp_ctx.db_bp_ts = cfg_page.db_bp_ts;
	  bp_ctx.db_bp_pages = cfg_page.db_bp_pages;
	  bp_ctx.db_bp_num = cfg_page.db_bp_num;
	  bp_ctx.db_bp_date = cfg_page.db_bp_date;
	  bp_ctx.db_bp_index = cfg_page.db_bp_index;
	  bp_ctx.db_bp_wr_bytes = cfg_page.db_bp_wr_bytes;
	}
      dbs->dbs_n_free_pages = dbs_count_free_pages (dbs);
      dbs_read_checkpoint_remap (dbs, cfg_page.db_checkpoint_map);
    }
  else
    {
      /* No database. Make one. */
      IN_DBS (dbs)
      dbs_extend_pagesets (dbs);
      /* Bit 1 is taken. This is the cfg page. 2 will be the first page of
       * free set, 3will be registry etc */

      /* GK: here it leaks two pages : 1 for the free set and one for the incb set
       * but it has to - this actually expands the file. TODO: fix it later */

      dbs->dbs_free_set->bd_physical_page =
	dbs->dbs_free_set->bd_page = dbs_get_free_disk_page (dbs, 0);

      dbs->dbs_incbackup_set->bd_physical_page =
	dbs->dbs_incbackup_set->bd_page =  dbs_get_free_disk_page (dbs, dbs->dbs_free_set->bd_page);
      dbs->dbs_n_free_pages = dbs_count_free_pages (dbs);
      dbs_write_page_set (dbs, dbs->dbs_free_set);
      dbs_write_page_set (dbs, dbs->dbs_incbackup_set);
      dbs_write_cfg_page (dbs, 0);
    }
  if (DBS_PRIMARY == type)
    dbs_init_registry (dbs);
  return dbs;
}


dk_set_t
_cfg_read_storages (caddr_t **temp_storage)
{
  FILE *cfg = fopen (CFG_FILE, "r");
  dk_set_t res = NULL;
  char line_buf[2000];		/* Was 100 */

  *temp_storage = NULL;
  while (fgets (line_buf, sizeof (line_buf), cfg))
    {
      char name[100];
      char file [200];
      if (2 == sscanf (line_buf, "storage %s %s", name, file))
	{
	  caddr_t stor = list (2, box_string (name), box_string (file));
	  dk_set_push (&res, stor);
	}
      if (2 == sscanf (line_buf, "temp %s", name))
	{
	  *temp_storage = (caddr_t *) list (2, box_string ("temp"), box_string (name));
	}
    }
  fclose (cfg);
  if (!*temp_storage)
    {
      FILE * t = fopen ("witemp.cfg", "w");
      fprintf (t, "database_file: witemp.db\nfile_extend: 200\n");
      fclose (t);
      *temp_storage = (caddr_t *) list (2, box_string ("temp"), box_string ("witemp.cfg"));
    }
  return res;
}


void
wi_open_dbs ()
{
  int sec_exists;
/*  char line_buf[2000];	*/	/* Was 100 */
  caddr_t *temp_file = NULL;
  dbe_storage_t * master_dbs = NULL;
  dk_set_t storages = NULL;
  wi_db_t * this_wd;
  NEW_VARZ (wi_db_t, wd);
  wi_inst.wi_master_wd = wd;
  dk_set_push (&wi_inst.wi_dbs, (void*) wd);
  wd->wd_qualifier = box_dv_short_string ("DB");
  this_wd = wd;
  master_dbs = dbs_from_file ("master", NULL, DBS_PRIMARY, &db_exists);
  this_wd->wd_primary_dbs = master_dbs;
  dk_set_push (&this_wd->wd_storage, (void*) master_dbs);
  master_dbs->dbs_db = this_wd;
  storages = dbs_read_storages (&temp_file);
  DO_SET (caddr_t *, storage, &storages)
    {
      dbe_storage_t * dbs = dbs_from_file (storage[0], storage[1], DBS_SECONDARY, &sec_exists);
      dbs->dbs_db = this_wd;
      dk_set_push (&this_wd->wd_storage, (void*) dbs);
    }
  END_DO_SET();
  wi_inst.wi_temp = dbs_from_file (temp_file[0], temp_file[1], DBS_TEMP, &sec_exists);
  wi_storage_offsets ();
  dk_free_tree (list_to_array (storages));
  dk_free_tree ((box_t) temp_file);
}


void
wi_open (char *mode)
{
  int inx;
  const_length_init ();

  wi_inst.wi_txn_mtx = mutex_allocate ();
  mutex_option (wi_inst.wi_txn_mtx, "TXN", txn_mtx_entry_check, NULL);

  db_read_cfg (NULL, mode);

  wi_inst.wi_bps = (buffer_pool_t **) dk_alloc_box (bp_n_bps * sizeof (caddr_t), DV_CUSTOM);
  for (inx = 0; inx < bp_n_bps; inx++)
    {
      wi_inst.wi_bps[inx] = bp_make_buffer_list (main_bufs / bp_n_bps);
      wi_inst.wi_bps[inx]->bp_ts = inx * ((main_bufs / BP_N_BUCKETS) / 9); /* out of step, don't do stats all at the same time */
    }
  wi_inst.wi_n_bps = (short) BOX_ELEMENTS (wi_inst.wi_bps);


  pm_rc_1 = resource_allocate (main_bufs, (rc_constr_t) map_allocate,
			    (rc_destr_t) map_free, (rc_destr_t) NULL, (void*) PM_SZ_1);
  pm_rc_2 = resource_allocate (main_bufs, (rc_constr_t) map_allocate,
			    (rc_destr_t) map_free, (rc_destr_t) NULL, (void*) PM_SZ_2);
  pm_rc_3 = resource_allocate (main_bufs, (rc_constr_t) map_allocate,
			    (rc_destr_t) map_free, (rc_destr_t) NULL, (void*) PM_SZ_3);
  pm_rc_4 = resource_allocate (main_bufs / 10, (rc_constr_t) map_allocate,
			    (rc_destr_t) map_free, (rc_destr_t) NULL, (void*) PM_SZ_4);

  cp_buf = buffer_allocate (DPF_CP_REMAP);

  wi_open_dbs ();
  mt_write_init ();
}


void
dbs_close (dbe_storage_t * dbs)
{
  if (dbs->dbs_disks)
    dbs_close_disks (dbs);
  else
    fd_close (dbs->dbs_fd, dbs->dbs_file);
}


void
mem_cache_init (void)
{
  int sz;
  dk_cache_allocs (sizeof (it_cursor_t), 400);
  dk_cache_allocs (sizeof (search_spec_t), 2000);
  dk_cache_allocs (sizeof (placeholder_t), 2000);
  dk_cache_allocs (PAGE_SZ, 20); /* size of page or session buffer's item */
  dk_cache_allocs (PAGE_DATA_SZ, 20); /* size of data on page */
  for (sz = 16; sz < 240; sz += 4)
    {
      if (!dk_is_alloc_cache (sz))
	dk_cache_allocs (sz, 10);
    }
}


db_buf_t rbp_allocate (void);
void rbp_free (caddr_t p);


void
wi_init_globals (void)
{
  PrpcInitialize ();
  blobio_init ();

  #ifdef DISK_CHECKSUM
  disk_checksum = hash_table_allocate (100000);
  dck_mtx = mutex_allocate ();
#endif

  mem_cache_init ();
  db_schema_mtx = mutex_allocate ();
  it_rc = resource_allocate (20, NULL, NULL, NULL, 0); /* put a destructor */
  lock_rc = resource_allocate (2000, (rc_constr_t) pl_allocate,
			       (rc_destr_t) pl_free, NULL, 0);
  row_lock_rc = resource_allocate (5000, (rc_constr_t) rl_allocate,
				   (rc_destr_t) rl_free, NULL, 0);
  rb_page_rc = resource_allocate (100, (rc_constr_t) rbp_allocate,
				  (rc_destr_t) rbp_free, NULL, 0);
  /* resource_no_sem (lock_rc); */

  trx_rc = resource_allocate (200, (rc_constr_t) lt_allocate,
			    (rc_destr_t) lt_free, (rc_destr_t) lt_clear, 0);
  buf_sort_mtx = mutex_allocate_typed (MUTEX_TYPE_LONG);
  time_mtx = mutex_allocate ();
  checkpoint_mtx = mutex_allocate_typed (MUTEX_TYPE_LONG);
  mutex_option (checkpoint_mtx, "CPT", NULL, NULL);
  lt_locks_mtx = mutex_allocate ();
  mutex_option (lt_locks_mtx, "LT_LOCKS", NULL, NULL);

  hash_index_cache.hic_mtx = mutex_allocate ();
  mutex_option (hash_index_cache.hic_mtx, "hash index cache", NULL, NULL);
  hash_index_cache.hic_hashes = id_hash_allocate (101, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
  hash_index_cache.hic_col_to_it = hash_table_allocate (201);
  hash_index_cache.hic_pk_to_it = hash_table_allocate (201);
}


void
dbe_key_open (dbe_key_t * key)
{
  /* The key is read from the schema, now open its trees */
  int inx;
  if (!key->key_fragments)
    {
      char str[MAX_NAME_LEN * 4];
      NEW_VARZ (dbe_key_frag_t, kf);
      key->key_fragments = (dbe_key_frag_t **) sc_list (1, kf);
      snprintf (str, sizeof (str), "__key__%s:%s:1", key->key_table->tb_name, key->key_name);
      kf->kf_name = box_dv_short_string (str);
      kf->kf_storage = key->key_storage;
    }
  DO_BOX (dbe_key_frag_t *, kf, inx, key->key_fragments)
    {
      caddr_t start_str;
      dp_addr_t start_dp = 0;
      IN_TXN;
      start_str = registry_get (kf->kf_name);
      LEAVE_TXN;
      kf->kf_it = it_allocate (kf->kf_storage);

      mutex_option (kf->kf_it->it_page_map_mtx, kf->kf_name, it_page_map_entry_check, (void*) kf->kf_it);
      {
	char mtx_name[200];
	snprintf (mtx_name, sizeof (mtx_name), "lock rel %100s", kf->kf_name);
	mutex_option (kf->kf_it->it_lock_release_mtx, mtx_name, NULL,  NULL);
      }
      kf->kf_it->it_key = key;
      if (start_str)
	start_dp = atol (start_str);
      dk_free_tree (start_str);
      if (!start_dp)
	{
	  buffer_desc_t * buf = isp_new_page (kf->kf_it->it_commit_space, 0, DPF_INDEX, 0, 0);
	  pg_init_new_root (buf);
	  kf->kf_it->it_commit_space->isp_root = buf->bd_page;
	  kf->kf_it->it_checkpoint_space->isp_root = buf->bd_page;
	  IN_PAGE_MAP (kf->kf_it);
	  page_leave_inner (buf);
	  LEAVE_PAGE_MAP (kf->kf_it);
	}
      else
	{
	  kf->kf_it->it_commit_space->isp_root = start_dp;
	}
    }
  END_DO_BOX;
}


int
buf_is_empty_root (buffer_desc_t * buf)
{
  int ct = buf->bd_content_map->pm_count, pos;
  key_id_t key_id;
  if (ct != 1)
    return 0;
  pos = buf->bd_content_map->pm_entries[0];
  key_id = SHORT_REF (buf->bd_buffer + pos + IE_KEY_ID);
  if (key_id != KI_LEFT_DUMMY)
    return 0;
  if (0 != LONG_REF (buf->bd_buffer + pos + IE_LEAF))
    return 0;
  return 1;
}


void
key_dropped (dbe_key_t * key)
{
  int inx;
  if (key->key_supers)
    return; /* is in the tree of its super */
  DO_BOX (dbe_key_frag_t *, kf, inx, key->key_fragments)
    {
      buffer_desc_t * buf;
      it_cursor_t itc_auto;
      it_cursor_t * itc = &itc_auto;
      ITC_INIT (itc, kf->kf_it->itc_commit_space, NULL);
      itc_from_it (itc, kf->kf_it);
      do {
	ITC_IN_MAP (itc);
	page_wait_access (itc, itc->itc_space->isp_root, NULL, NULL, &buf, PA_WRITE, RWG_WAIT_SPLIT);
      } while (itc->itc_to_reset >= RWG_WAIT_SPLIT);
      if (!buf_is_empty_root (buf))
	{
	  log_error ("Dropping schema for a non-empty index tree");
	  itc_page_leave (itc, buf);
	  ITC_LEAVE_MAP (itc);
	  continue;
	}
      ITC_IN_MAP (itc);
      itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE);
      isp_free_page (kf->kf_it->it_commit_space, buf);
      ITC_LEAVE_MAP (itc);
      IN_TXN;
      registry_set (kf->kf_name, NULL);
      dk_set_delete (&wi_inst.wi_master->dbs_trees, kf->kf_it);
      dk_set_push (&wi_inst.wi_master->dbs_deleted_trees, kf->kf_it);
      LEAVE_TXN;
      kf->kf_it->it_commit_space->isp_root = 0;
    }
  END_DO_BOX;
}


void
dbe_key_save_roots (dbe_key_t * key)
{
  int inx;
  DO_BOX (dbe_key_frag_t *, kf, inx, key->key_fragments)
    {
      char str[20];
      snprintf (str, sizeof (str), "%d", (int) kf->kf_it->it_commit_space->isp_root);
      ASSERT_IN_TXN; /* called from checkpoint inside txn mtx */
      registry_set (kf->kf_name, str);
    }
  END_DO_BOX;
}


void
sch_save_roots (dbe_schema_t * sc)
{
  dbe_key_t * key;
  void * k;
  dk_hash_iterator_t hit;
  dk_hash_iterator (&hit, sc->sc_id_to_key);
  while (dk_hit_next (&hit, (void**) &k, (void **) &key))
    dbe_key_save_roots (key);
}

void
resources_reaper (void)
{
  resource_clear (lock_rc, NULL);
  resource_clear (row_lock_rc, NULL);
  resource_clear (rb_page_rc, NULL);
  IN_TXN;
  resource_clear (trx_rc, NULL);
  LEAVE_TXN;
  numeric_rc_clear ();
  mutex_enter (thread_mtx);
  resource_clear (free_threads, dk_thread_free);
  mutex_leave (thread_mtx);
  malloc_cache_clear ();
}


wi_db_t *
wi_ctx_db ()
{
  return (wi_inst.wi_master_wd);
}
