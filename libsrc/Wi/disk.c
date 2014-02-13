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
#include "sqlbif.h"
#include "srvstat.h"
#include "recovery.h"
#include "zlib.h"
#ifdef _SSL
#include <openssl/md5.h>
#define MD5Init   MD5_Init
#define MD5Update MD5_Update
#define MD5Final  MD5_Final
#else
#include "util/md5.h"
#endif /* _SSL */



#ifdef BYTE_ORDER_REV_SUPPORT

dk_hash_t * row_hash = 0;
int h_index = 0;

#if DB_SYS_BYTE_ORDER == DB_ORDER_LITTLE_ENDIAN
void
DBS_REVERSE_LONG(db_buf_t pl)
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


void
DBS_REVERSE_SHORT(db_buf_t ps)
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


long
DBS_REV_LONG_REF(db_buf_t p)
{
  if (h_index && gethash((void*) p, row_hash))
    return LONG_REF (p);
  return LONG_REF_NA (p);
}


short
DBS_REV_SHORT_REF(db_buf_t ps)
{
  if (h_index && gethash((void*) ps, row_hash))
    return SHORT_REF (ps);
  return SHORT_REF_NA ((ps));
}
#else
void
DBS_REVERSE_LONG(db_buf_t pl)
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


void
DBS_REVERSE_SHORT(db_buf_t ps)
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

long
DBS_REV_LONG_REF(db_buf_t p)
{
  if (h_index && gethash((void*) p, row_hash))
    return LONG_REF (p);
  return LONG_REF_BE (p);
}

short
DBS_REV_SHORT_REF(db_buf_t ps)
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
int dbs_cpt_recov_in_progress = 0;

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

struct wi_inst_s * wi_instance_get(void) { return &wi_inst; }


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
  dbs->dbs_cpt_remap = hash_table_allocate (101);
  dk_hash_set_rehash (dbs->dbs_cpt_remap, 4);
  dbs->dbs_cpt_tree = it_allocate (dbs);
  dbs->dbs_unfreeable_dps = hash_table_allocate (203);
  dbs->dbs_dp_to_extent_map = hash_table_allocate (301);
  dbs->dbs_stripe_unit = 1;
  return dbs;
}

dk_hash_t * page_set_checksums;

#ifdef PAGE_SET_CHECKSUM

uint32
page_set_checksum (db_buf_t page)
{
  uint32 ck = 0;
  uint32 * p = (uint32*) page;
  int inx;
  /* first 2021 int32's with a step of 17, the last 3 with a step of 1 */
  for (inx = 0; inx < ((PAGE_DATA_SZ / sizeof (uint32)) / 17) * 17; inx+= 17)
    ck = ck ^ p[inx] ^ p[inx + 1] ^ p[inx + 2] ^ p[inx + 3]
      ^ p[inx + 4] ^ p[inx + 5] ^ p[inx + 6] ^ p[inx + 7] ^ p[inx + 8]
      ^ p[inx + 9] ^ p[inx + 10] ^ p[inx +11] ^ p[inx + 12] ^ p[inx + 13]
      ^ p[inx + 14] ^ p[inx + 15] ^ p[inx + 16];
  for (inx = ((PAGE_DATA_SZ / sizeof (uint32)) / 17) * 17; inx < PAGE_DATA_SZ / sizeof (uint32); inx++)
    ck = ck ^ ((uint32*)page)[inx];
  return ck;
}


void
page_set_checksum_init (db_buf_t page)
{
  sethash ((void *) page, page_set_checksums, (void*) (ptrlong) page_set_checksum (page));
}

void
page_set_check (db_buf_t page)
{
  void * cks;
  uint32 ck, pck;
  GETHASH (page, page_set_checksums, cks, no_cksum);
  ck = (unsigned ptrlong) cks;
  pck = page_set_checksum (page);
  if (ck != pck)
    {
      log_error ("page set checksum ck=%x pck=%x xor = %x", (void*)(uptrlong)ck, (void*)(uptrlong)pck, (void*)(uptrlong) (ck ^ pck));
      GPF_T1 ("page set checksum error");
    }
 no_cksum: ;
}

void
page_set_update_checksum (uint32 * page, int inx, int bit)
{
  uint32 ck = (unsigned ptrlong) gethash ((void*)page, page_set_checksums);
  ck = ck ^ 1L << bit;
  sethash ((void *)page, page_set_checksums, (void*) (unsigned ptrlong) ck);
}
#endif


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
#ifdef NNMTX_DEBUG
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

#define IT_INIT_HASH_SIZE (11 * IT_N_MAPS)

index_tree_t *
it_allocate (dbe_storage_t * dbs)
{
  int inx;
  index_tree_t * tree = (index_tree_t *)dk_alloc_box_zero (sizeof (index_tree_t), DV_ITC);
  tree->it_maps = dk_alloc (sizeof (it_map_t) * IT_N_MAPS);
  memset (tree->it_maps, 0, sizeof (it_map_t) * IT_N_MAPS);
  tree->it_lock_release_mtx = mutex_allocate ();
  for (inx = 0; inx < IT_N_MAPS; inx++)
    {
      it_map_t * itm = &tree->it_maps[inx];
      dk_mutex_init (&itm->itm_mtx, MUTEX_TYPE_SHORT);
      hash_table_init (&itm->itm_remap, IT_INIT_HASH_SIZE / IT_N_MAPS);
      dk_hash_set_rehash (&itm->itm_remap, space_rehash_threshold);
      hash_table_init (&itm->itm_dp_to_buf, IT_INIT_HASH_SIZE / IT_N_MAPS);
      dk_hash_set_rehash (&itm->itm_dp_to_buf, space_rehash_threshold);

      hash_table_init (&itm->itm_locks, IT_INIT_HASH_SIZE / IT_N_MAPS);
      dk_hash_set_rehash (&itm->itm_locks, space_rehash_threshold);
#ifdef MTX_DEBUG
      itm->itm_dp_to_buf.ht_required_mtx = &itm->itm_mtx;
      itm->itm_remap.ht_required_mtx = &itm->itm_mtx;
      itm->itm_locks.ht_required_mtx = &itm->itm_mtx;
#endif
    }
  tree->it_storage = dbs;
  tree->it_extent_map = dbs->dbs_extent_map;
  dk_set_push (&dbs->dbs_trees, (void*)tree);
  return tree;
}

#ifdef BUF_DEBUG
dk_set_t temp_trees;
dk_mutex_t * temp_trees_mtx;

void
it_temp_tree_active (index_tree_t * it)
{
  return;
  mutex_enter (temp_trees_mtx);
  dk_set_push (&temp_trees, (void*) it);
  mutex_leave (temp_trees_mtx);
}

void
it_temp_tree_done (index_tree_t * it)
{
  return;
  mutex_enter (temp_trees_mtx);
  dk_set_delete  (&temp_trees, (void*) it);
  mutex_leave (temp_trees_mtx);
}


void
it_temp_tree_check ()
{
  DO_SET (index_tree_t *, it, &temp_trees)
    {
      dk_hash_iterator_t hit;
      void * dp;
      buffer_desc_t * buf;
      int inx;
      GPF_T ("function not complete");
      for (inx = 0; inx < IT_N_MAPS; inx++)
	{
	  it_map_t * itm = &it->it_maps[inx];
	  dk_hash_iterator (&hit, &itm->itm_dp_to_buf);
	  /* This function is not complete */
	}
    }
  END_DO_SET();
}


#else
#define it_temp_tree_active(a)
#define it_temp_tree_done(a)
#define it_temp_tree_check(a)
#endif


#ifdef WIN32
#define PATH_MAX	 MAX_PATH
#endif

void
dbs_sys_db_check (caddr_t file)
{
  static char abs_path[PATH_MAX + 1];
  char *p_abs_path = abs_path;
  caddr_t ** already_open;
  caddr_t name_save;
  id_hash_t * virt_sys_files = wi_inst.wi_files;

  if (!rel_to_abs_path (p_abs_path, file, sizeof (abs_path)))
    return;

  if (!virt_sys_files)
    return;

  name_save = box_dv_short_string (abs_path);

  already_open = (caddr_t **) id_hash_get (virt_sys_files, (caddr_t)&name_save);

  if (already_open)
    {
      log_error ("The file %s is already open. Check %s settings.", file, f_config_file);
      call_exit (1);
    }

  id_hash_set (virt_sys_files, (caddr_t) & name_save, (caddr_t) & file);
}


index_tree_t *
it_temp_allocate (dbe_storage_t * dbs)
{
  index_tree_t * tree = (index_tree_t *) resource_get (it_rc);
  if (!tree)
    {
      int inx;
      index_tree_t * tree = (index_tree_t*) dk_alloc_box_zero (sizeof (index_tree_t), DV_INDEX_TREE);
      tree->it_maps = dk_alloc (sizeof (it_map_t) * IT_N_MAPS);
      memset (tree->it_maps, 0, sizeof (it_map_t) * IT_N_MAPS);
      for (inx = 0; inx < IT_N_MAPS; inx++)
	{
	  it_map_t * itm = &tree->it_maps[inx];
	  dk_mutex_init (&itm->itm_mtx, MUTEX_TYPE_SHORT);
	  hash_table_init (&itm->itm_remap, 11);
	  dk_hash_set_rehash (&itm->itm_remap, space_rehash_threshold);
	  hash_table_init (&itm->itm_dp_to_buf, 11);
	  dk_hash_set_rehash (&itm->itm_dp_to_buf, space_rehash_threshold);
	  hash_table_init (&itm->itm_locks, 11);
	  dk_hash_set_rehash (&itm->itm_locks, space_rehash_threshold);
	}

      tree->it_storage = dbs;
      tree->it_extent_map = dbs->dbs_extent_map;
      it_temp_tree_active (tree);
      return tree;
    }
  else
    {
      tree->it_hi = NULL;
      tree->it_storage = dbs;
      tree->it_extent_map = dbs->dbs_extent_map;
      tree->it_hash_first = 0;
      it_temp_tree_active (tree);
      return tree;
    }
}


void
it_free (index_tree_t * it)
{
  int inx;
  for (inx = 0; inx < IT_N_MAPS; inx++)
    {
      it_map_t * itm = &it->it_maps[inx];
      dk_mutex_destroy (&itm->itm_mtx);
      hash_table_destroy (&itm->itm_remap);
      hash_table_destroy (&itm->itm_dp_to_buf);
      hash_table_destroy (&itm->itm_locks);
    }
  if (it->it_lock_release_mtx)
    mutex_free (it->it_lock_release_mtx);
  dk_free ((void*) it->it_maps, sizeof (it_map_t) * IT_N_MAPS);
  box_tag_modify (it, DV_CUSTOM);
  dk_free_box ((void*) it);
}


int
it_temp_tree (index_tree_t * it)
{
  buffer_desc_t * buf = it_new_page (it, 0, DPF_INDEX, 0, 0);
  it_map_t * itm;
  if (!buf)
    return 0;
  pg_init_new_root (buf);
  it->it_root = buf->bd_page;
  itm = IT_DP_MAP (it, buf->bd_page);
  mutex_enter (&itm->itm_mtx);
  page_leave_inner (buf);
  mutex_leave (&itm->itm_mtx);
  return 1;
}


void
buf_unregister_itcs (buffer_desc_t * buf)
{
  it_cursor_t * reg = buf->bd_registered;
  while (reg)
    {
      it_cursor_t * next = reg->itc_next_on_page;
      reg->itc_buf_registered = NULL;
      reg->itc_is_registered = 0;
      reg->itc_next_on_page = NULL;
      reg = next;
    }
  buf->bd_registered = NULL;
}


void
it_temp_free (index_tree_t * it)
{
  /* free a temp tree */

  /*Note the following problem scenario:  A  buffer becomes available in it_temp_free, space and pages set to 0.
   * This buffer then gets used in  another tree, no need to sync because the buffer in question is free. [B
   * Another buffer in the same temp tree must be cancelled from the write queue. This leaves the mutexes and restarts the scan of the hash.  The hash will however still reference buffers that have been set free.
   * It may be that a buffer is then encountered which legitimately  belongs to another tree by this time.
   * An inadvertent write cancellation and page_wait_access with the wrong page map mtx may be attempted, which is objectionable. Worst case is an erroneous mark as free and losing non-serialization of the buffer's rw gate.
   * Therefore  all cancellations get done first and then all buffers that remain are detached from the it being deleted. */

  it_cursor_t itc_auto;
  int inx;
  it_cursor_t * itc = &itc_auto;
  ptrlong dp, remap;
  buffer_desc_t * buf;
  dk_hash_iterator_t hit;
  if (!it)
    return;
  if (it->it_hi && it_hi_done (it))
    return;  /* a reusable hash temp ref dropped */
  if (it->it_hi_signature)
    GPF_T1 ("freeing hash without invalidating it first");
  ITC_INIT (itc, NULL, NULL);
  itc_from_it (itc, it);
  buf_dbg_printf (("temp tree %x free \n", isp));
  for (inx = 0; inx < IT_N_MAPS; inx++)
    {
      it_map_t * itm = &it->it_maps[inx];
 again:
      ITC_IN_KNOWN_MAP (itc, inx);
      dk_hash_iterator (&hit, &itm->itm_dp_to_buf);
  while (dk_hit_next (&hit, (void**) &dp, (void **) &buf))
    {
	  ASSERT_IN_MAP (itc->itc_tree, inx);
	  if (buf->bd_tree && buf->bd_tree != it)
	GPF_T1 ("it_temp_free with buffer that belongs to other tree");
      buf->bd_is_dirty = 0;
      if (BUF_WIRED (buf)
	      ||buf->bd_iq)
	{
	      page_wait_access (itc, buf->bd_page, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
	      ITC_LEAVE_MAPS (itc);
	  buf_cancel_write (buf);
	      ITC_IN_KNOWN_MAP (itc, inx);
	  page_leave_inner (buf);
	  goto again; /* sequence broken, hash iterator to be re-inited */
	}
    }
      ITC_IN_KNOWN_MAP (itc, inx);
      dk_hash_iterator (&hit, &itm->itm_dp_to_buf);
  while (dk_hit_next (&hit, (void**) &dp, (void **) &buf))
    {
	  ASSERT_IN_MAP (itc->itc_tree, inx);
	  if (buf->bd_tree && buf->bd_tree != it)
	GPF_T1 ("it_temp_free with buffer that belongs to other tree");
      if (BUF_WIRED (buf)
	      || buf->bd_iq)
	{
	  log_error ("it_temp_free:  Buffers should not be in write queue after cancellation.");
	}
      BUF_BACKDATE(buf);
	  buf->bd_tree = NULL;
      buf->bd_is_dirty = 0;
      buf->bd_page = 0;
      buf->bd_physical_page = 0;
      buf_unregister_itcs (buf);
    }
      clrhash (&itm->itm_dp_to_buf);
      ITC_LEAVE_MAPS (itc);
      if (DBS_TEMP != it->it_storage->dbs_type) GPF_T1 ("temp tree free with a non temp dbs");
      dk_hash_iterator (&hit, &itm->itm_remap);
  while (dk_hit_next (&hit, (void**)&dp, (void**)&remap))
    {
      em_free_dp (it->it_extent_map, (dp_addr_t) dp, EMF_ANY);
    }
      clrhash (&itm->itm_remap);
      ITC_LEAVE_MAPS (itc);
    }
  itc_free (itc);
  if (it->it_extent_map != it->it_storage->dbs_extent_map)
    em_free (it->it_extent_map);
  if (it->it_hi)
    hi_free (it->it_hi);
  it->it_hi = NULL;
  it->it_hi_reuses = 0;
  it_temp_tree_done (it);
  if (it->it_maps[0].itm_remap.ht_actual_size != IT_INIT_HASH_SIZE / IT_N_MAPS)
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

#define BUFFER_GROUP_SIZE 14

typedef dtp_t db_page_buf_t[BUF_ALLOC_SZ];

typedef struct buffer_group_s {
  buffer_desc_t bg_items[BUFFER_GROUP_SIZE];
  int bg_used;
  struct buffer_group_s *bg_prev, *bg_next;
  db_page_buf_t *bg_buffer0;
  dtp_t bg_space [BUF_ALLOC_SZ * (BUFFER_GROUP_SIZE+1)];
} buffer_group_t;

static dk_hash_t *bg_of_bd = NULL;
static buffer_group_t *bg_first = NULL;
static int bg_free_buffers = 0;
static dk_mutex_t *bg_mutex = NULL;

buffer_group_t *
buffer_group_allocate ()
{
  NEW_VARZ (buffer_group_t, bg);
  bg->bg_buffer0 = ALIGN_8K (bg->bg_space);
  if (NULL != bg_first)
    {
      bg->bg_next = bg_first;
      bg->bg_prev = bg_first->bg_prev;
      bg->bg_prev->bg_next = bg;
      bg_first->bg_prev = bg;
    }
  bg_free_buffers += BUFFER_GROUP_SIZE;
  return bg;
}

buffer_desc_t *
buffer_allocate (int type)
{
  int b_ctr;
  buffer_group_t *iter;
  if (NULL == bg_mutex)
    {
      bg_mutex = mutex_allocate ();
      mutex_enter (bg_mutex);
      bg_of_bd = hash_table_allocate (200);
      bg_first = buffer_group_allocate ();
      bg_first->bg_next = bg_first->bg_prev = bg_first;
    }
  else
    mutex_enter (bg_mutex);
  if (bg_free_buffers < (1 + (bg_of_bd->ht_count / BUFFER_GROUP_SIZE)))
    bg_first = buffer_group_allocate ();
  iter = bg_first;
  for (;;)
    {
      if (iter->bg_used < BUFFER_GROUP_SIZE)
        {
          bg_first = iter;
          break;
        }
      iter = iter->bg_next;
      if (iter == bg_first)
        GPF_T1 ("buffer_allocate(): can't find a non-full buffer group");
    }
  for (b_ctr = BUFFER_GROUP_SIZE; b_ctr--; /* no step */)
    {
      buffer_desc_t *buf = bg_first->bg_items + b_ctr;
      if (NULL != buf->bd_buffer)
        continue;
      memset (buf, 0, sizeof (buffer_desc_t));
      buf->bd_buffer = (void *)(bg_first->bg_buffer0 + b_ctr);
      memset (buf->bd_buffer, 0, PAGE_SZ);
      BUF_SET_END_MARK (buf);
      SHORT_SET (buf->bd_buffer + DP_FLAGS, type);
      sethash (buf, bg_of_bd, bg_first);
      bg_first->bg_used++;
      bg_free_buffers--;
      mutex_leave (bg_mutex);
      return buf;
    }
  GPF_T1 ("buffer_allocate(): can't find a free buffer in a group");
  return NULL; /* never happen */
}

void
buffer_free (buffer_desc_t * buf)
{
  buffer_group_t *bg;
  if (NULL == buf)
    return;
  if (NULL == buf->bd_buffer)
    GPF_T1 ("buffer_free(): double free ?");
  mutex_enter (bg_mutex);
  bg = gethash (buf, bg_of_bd);
  if (NULL == bg)
    GPF_T1 ("buffer_free(): can't find a group of the buffer, was the buffer allocated by buffer_allocate() ?");
  if (0 >= bg->bg_used)
    GPF_T1 ("buffer_free(): the group is empty");
  buf->bd_buffer = NULL;
  remhash (buf, bg_of_bd);
  bg_free_buffers++;
  bg->bg_used--;
  if ((0 == bg->bg_used) && (bg != bg_first) && (bg->bg_next != bg) &&
    (bg_free_buffers > (2 * BUFFER_GROUP_SIZE + (bg_of_bd->ht_count / (BUFFER_GROUP_SIZE - 2)))) )
    {
      bg->bg_next->bg_prev = bg->bg_prev;
      bg->bg_prev->bg_next = bg->bg_next;
      bg_free_buffers -= BUFFER_GROUP_SIZE;
      dk_free (bg, sizeof (buffer_group_t));
    }
  mutex_leave (bg_mutex);
}

void
buffer_set_free (buffer_desc_t* ps)
{
  while (ps)
    {
      buffer_desc_t * next_buf = ps->bd_next;
      buffer_free (ps);
      ps = next_buf;
    }
}


int32 bp_flush_trig_pct = 50;
int64 bp_replace_age;
int32 bp_replace_count;

long tc_bp_get_buffer;
long tc_bp_get_buffer_loop;
long tc_first_free_replace;
long tc_get_buffer_while_stat;
#define B_N_SAMPLE (BP_N_BUCKETS * 4)

dp_addr_t
bd_age_key (void * b)
{
  buffer_desc_t * buf = (buffer_desc_t *) b;
  return - BUF_AGE (buf);
}


void buf_qsort (buffer_desc_t ** in, buffer_desc_t ** left,
	   int n_in, int depth, sort_key_func_t key);

int
bd_age_cmp (int a1, int a2, void * cd)
{
  if ((uint32)a1 < (uint32)a2)
    return DVC_GREATER;
  if (a1 == a2)
    return DVC_MATCH;
  return DVC_LESS;
}


void
bp_stats (buffer_pool_t * bp)
{
  bp_ts_t sample[B_N_SAMPLE + 1];
  bp_ts_t sample_2[B_N_SAMPLE + 1];
  int inx, fill = 0;
  for (inx = bp->bp_ts & 0xf; inx < bp->bp_n_bufs; inx += bp->bp_n_bufs / B_N_SAMPLE)
    {
      buffer_desc_t * buf = &bp->bp_bufs[inx];
      sample[fill++] = BUF_AGE (buf);
    }
  if (fill < 1 || fill * sizeof (bp_ts_t) > sizeof (sample_2)) GPF_T1 ("buf fill anomaly");
  gen_qsort ((int*)sample, (int*)sample_2, fill, 0, bd_age_cmp, NULL);
  if (fill < 1) GPF_T1 ("buf fill < 1");
  for (inx = 0; inx < BP_N_BUCKETS - 1; inx++)
    {
      bp->bp_bucket_limit[inx] = sample[(inx + 1) * 4];
    }
  if (fill < 1) GPF_T1 ("buf fill < 1");
  bp->bp_bucket_limit[BP_N_BUCKETS - 1] = sample[fill - 1];
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
bp_buf_enter (buffer_desc_t * buf, it_map_t ** itm_ret)
{
  index_tree_t  ** volatile bd_tree = &buf->bd_tree;
  volatile dp_addr_t * bd_page = &buf->bd_page;
  dp_addr_t dp = *bd_page;
  index_tree_t * tree = *bd_tree;
  it_map_t * itm;
  if (!tree)
    return 0;
  itm = IT_DP_MAP (tree, dp);
  mutex_enter (&itm->itm_mtx);
  if (*bd_tree == tree && dp == *bd_page)
    {
      *itm_ret = itm;
      return 1;
    }
  mutex_leave (&itm->itm_mtx);
 return 0;
}

long tc_unused_read_aside;

int
bp_found (buffer_desc_t * buf, int from_free_list)
{
  buffer_pool_t * bp = buf->bd_pool;
  index_tree_t * last_tree = buf->bd_tree;
  dp_addr_t dp;
  volatile dp_addr_t * bd_page = &buf->bd_page;
  index_tree_t ** volatile bd_tree = &buf->bd_tree;
  it_map_t * itm;
  /* the buffer is considered for reuse.  If so, even if not getting the buf from the deleted list,
   * pop it out of the deleted list.  If the list breaks in the middle, no harm done.  Seldom occurrence due to it being dirty written outside of bp_mtx */
  if (buf->bd_registered)
    return 0;
  if (!from_free_list && buf->bd_next)
    {
      buf->bd_pool->bp_first_free = buf->bd_next;
      buf->bd_next = NULL;
    }

  if (!last_tree)
    {
      /* when taking a non-used buffer, the serialization is on the
       * bp, not the map of the buffer's tree.  Must check for flags, as
       * double allocation is possible if the buffer is found by other thread before getting a tree and the flags are not checked */
      if (!BUF_AVAIL (buf))
	return 0;
      buf->bd_readers = 1;
      if (!from_free_list)
	bp->bp_next_replace = (int) ((buf - bp->bp_bufs) + 1);
      bp_replace_count--; /* reuse of abandoned not counted as a replace */
      LEAVE_BP (bp);
      buf->bd_timestamp = bp->bp_ts;
#ifdef BUF_DEBUG
      buf->bd_prev_tree = NULL;
#endif
      return 1;
    }
  dp = *bd_page;
  itm = IT_DP_MAP (last_tree, dp);
  mutex_enter (&itm->itm_mtx);
  if (dp != *bd_page || *bd_tree != last_tree)
    {
      mutex_leave (&itm->itm_mtx);
      return 0;
    }
  if (BUF_AVAIL (buf))
    {
      buf->bd_readers = 1;
      /* the buffer may have been freed from its isp between reading the last_isp and entering its map.
       */
#ifdef BUF_DEBUG
      buf->bd_prev_tree = last_tree;
      buf_dbg_printf (("Buf %x leaves tree %x\n", buf, last_isp));
#endif
      if (!remhash (DP_ADDR2VOID (buf->bd_page), &itm->itm_dp_to_buf))
	GPF_T1 ("buffer not in the hash of the would be space of residence");
      buf->bd_page = 0;
      buf->bd_tree = NULL;
      mutex_leave (&itm->itm_mtx);
      if (!from_free_list)
	bp->bp_next_replace = (int) ((buf - bp->bp_bufs) + 1);
      bp_replace_age += bp->bp_ts - buf->bd_timestamp;
      LEAVE_BP (bp);
      bp->bp_last_buf_ts = buf->bd_timestamp;
      buf->bd_timestamp = bp->bp_ts;
      if (buf->bdf.r.is_read_aside)
	{
	  TC (tc_unused_read_aside);
	  buf->bdf.r.is_read_aside = 0;
	}
      return 1;
    }
  mutex_leave (&itm->itm_mtx);
  return 0;
}


int
bp_stat_action (buffer_pool_t * bp)
{
  /* schedule writes if appropriate.  If nothing free write synchronously */
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
    || action_ctr++ % 100 == 0)
    {
      if (!wi_inst.wi_checkpoint_atomic)
	{
	  /* not inside checkpoint. bp_get_buffer can happen inside, for reading uncommitted pages for cpt rb */
	  bp->bp_stat_pending = 1;
	  LEAVE_BP (bp);
      wi_check_all_compact (age_limit);
      IN_BP (bp);
      bp->bp_stat_pending = 0;
      mt_write_dirty (bp, age_limit, 0);
    }
      else
	{
	  /*  mtx just pro forma, only one thread in cpt anyway */
	  mutex_leave (bp->bp_mtx);
	  bp_write_dirty (bp, 0, 0, ALL_DIRTY);
	  mutex_enter (bp->bp_mtx);
	}
    }
  bp->bp_stat_pending = 0;
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

long tc_bp_wait_flush;

void
bp_wait_flush (buffer_pool_t * bp)
{
  /* sleep until the backlog of buffers in async write is somewhat cleared.  Under 40% of last bucket in write queue */
  int limit = (bp->bp_n_bufs / BP_N_BUCKETS) / 3;
  int n = bp_n_being_written (bp);
  int n_tries = 1, waited = 0;
#ifdef DEBUG
  int first_n = n;
#endif
  limit = MAX (limit, n / 2);
  while (n > limit)
    {
      virtuoso_sleep (0, 50000 * n_tries);
      TC (tc_bp_wait_flush);
      waited += n_tries * 50;
      if (waited > 1000)
	break;
      if (n_tries < 4)
	n_tries++;
      n = bp_n_being_written (bp);
    }
  dbg_printf (("waited for bp flush of %d for %d msec\n", first_n - n, waited));
}


#define BD_REPLACE_CHECK_BATCH 20

#define BD_REPLACE_CHECK(n) \
{ \
  if (!buf[n].bd_tree) \
    { \
      best = &buf[n]; \
      best_age = 0; \
      goto found; \
    } \
  if (0 == (buf[n].bdf.flags & bdf_is_avail_mask)			\
      && (age = ts - buf[n].bd_timestamp) >= best_age && !buf[n].bd_registered) \
    { \
      best_age = age; \
      best = &buf[n]; \
    } \
}


void
bp_delayed_stat_action (buffer_pool_t * bp)
{
  IN_BP (bp);
  bp_stats (bp);
  bp_stat_action (bp);
  LEAVE_BP (bp);
}


buffer_desc_t *
bp_get_buffer_1 (buffer_pool_t * bp, buffer_pool_t ** action_bp_ret, int mode)
{
  /* buffer returned with bd_readers = 1 so that it won't be allocated twice. Disconnected from any tree/page on return */
  int n_again = 1;
  buffer_desc_t * buf, * first_free;
  int age_limit;
  if (action_bp_ret)
    *action_bp_ret = NULL;
  if (!bp)
    bp = wi_inst.wi_bps[wi_inst.wi_bp_ctr ++ % wi_inst.wi_n_bps];
  tc_bp_get_buffer++;
  mutex_enter  (bp->bp_mtx);
  if ((first_free = bp->bp_first_free))
    {
      bp->bp_first_free = first_free->bd_next;
      first_free->bd_next = NULL;
      if (bp_found (first_free, 1))
	{
	  TC (tc_first_free_replace);
	  return first_free;
	}
    }
  bp_replace_count++;
  bp->bp_ts++;
 again:
  if (((int) (bp->bp_ts - bp->bp_stat_ts)) > (bp->bp_n_bufs / BP_N_BUCKETS) / 2)
    {
      if (!bp->bp_stat_pending)
	{
	  if (BP_BUF_IF_AVAIL == mode && !wi_inst.wi_checkpoint_atomic)
	    {
	      /* if read aside, must not risk autocompact before the reads are scheduled because an autocompact might need to update a parent which may be in the pages being scheduled for read aside, would deadlock */
	      if (!action_bp_ret) GPF_T1 ("must provide action bp for bp get buffer in read ahead outside cpt");
	      bp->bp_stat_pending = 1;
	      *action_bp_ret = bp;
	      LEAVE_BP (bp);
	      return NULL;
	    }
	  bp_stats (bp);
	  age_limit = bp_stat_action (bp);
	}
      else
	{
	  age_limit = bp->bp_bucket_limit[0] / n_again;
	  /* can hang if age limit is too high and the stat batch can never finish because this thread never allows reentry into the bp because it stays busy looking for bufs of which all are too young */
	  TC (tc_get_buffer_while_stat);
	}
    }
  else
    age_limit = bp->bp_bucket_limit[0];
  for (buf = &bp->bp_bufs[bp->bp_next_replace]; buf < &bp->bp_bufs[bp->bp_n_bufs]; buf++)
    {
      if (buf < &bp->bp_bufs[bp->bp_n_bufs - BD_REPLACE_CHECK_BATCH])
	{
	  bp_ts_t ts = bp->bp_ts;
	  bp_ts_t age, best_age;
	  buffer_desc_t * best = NULL;
	  if (age_limit < 0)
	    age_limit = 0;
	  best_age = age_limit;
	  BD_REPLACE_CHECK (0);
	  BD_REPLACE_CHECK (1);
	  BD_REPLACE_CHECK (2);
	  BD_REPLACE_CHECK (3);
	  BD_REPLACE_CHECK (4);
	  BD_REPLACE_CHECK (5);
	  BD_REPLACE_CHECK (6);
	  BD_REPLACE_CHECK (7);
	  BD_REPLACE_CHECK (8);
	  BD_REPLACE_CHECK (9);
	  BD_REPLACE_CHECK (10);
	  BD_REPLACE_CHECK (11);
	  BD_REPLACE_CHECK (12);
	  BD_REPLACE_CHECK (13);
	  BD_REPLACE_CHECK (14);
	  BD_REPLACE_CHECK (15);
	  BD_REPLACE_CHECK (16);
	  BD_REPLACE_CHECK (17);
	  BD_REPLACE_CHECK (18);
	  BD_REPLACE_CHECK (19);

	found:
	  if (best && bp_found (best, 0))
	    {
	      if (best_age)
		bp->bp_next_replace = (buf - bp->bp_bufs)  + BD_REPLACE_CHECK_BATCH;
	      return best;
	    }
	  buf += BD_REPLACE_CHECK_BATCH - 1;
	  age_limit -= 10; /* not in the last checked.  Be less picky for the next batch. */
	}

      if (!buf->bd_is_dirty
	  && ((int) (bp->bp_ts - buf->bd_timestamp)) >= age_limit)
	{
	  if (bp_found (buf, 0))
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
	  if (bp_found (buf, 0))
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
  n_again++;
  if (n_again > 3)
    mt_write_dirty (bp, 0, 0);
  goto again;
}


long gpf_time = 0;

#ifdef MTX_DEBUG
int
buf_set_dirty (buffer_desc_t * buf)
{
  /* Not correct, exception in pg_reloc_right_leaves.
    if (!BUF_WIRED (buf))
    GPF_T1 ("can't set a buffer as dirty if not on it.");
  */

#ifdef MTX_DEBUG
    {
    it_map_t * itm = IT_DP_MAP (buf->bd_tree, buf->bd_page);
    mutex_enter (&itm->itm_mtx);
    assert (gethash (DP_ADDR2VOID(buf->bd_page), &itm->itm_remap));
    mutex_leave (&itm->itm_mtx);
    }
#endif
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

#ifdef MTX_DEBUG
    {
    it_map_t * itm = IT_DP_MAP (buf->bd_tree, buf->bd_page);
    ASSERT_IN_MTX (&itm->itm_mtx);
    if (!gethash (DP_ADDR2VOID(buf->bd_page), &itm->itm_remap)) GPF_T1 ("not remapped when being set to dirty");
    }
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
#endif


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
  index_tree_t * tree = buf->bd_tree;
  DBG_PT_BUF_SCRAP (buf);
  if (tree && buf->bd_page)
    {
      ASSERT_IN_MAP (tree, buf->bd_page);
      if (buf->bd_page && gethash ((void*)(ptrlong)buf->bd_page, &IT_DP_MAP (tree, buf->bd_page)->itm_dp_to_buf))
	GPF_T1 ("buf_set_last called while buffer still in isp's cache.");
    }
  if (!buf->bd_is_write && !buf->bd_readers)
    GPF_T1 ("Must have write on a buffer to set it last"); /* we also accept read cause blob structure errors sometimes have read access when they scrap the buffer */
  buf->bd_pl = NULL;
  /* set the bd_tree and bd_page to null only later, in the final page_leave_inner.  This prevents buffer replacement from taking the buffer until it is all cleared because it will wat on the space's map. */
  if (buf->bd_is_dirty)
    {
      wi_inst.wi_n_dirty--;
      buf->bd_is_dirty = 0;
    }
  buf->bd_timestamp = bp->bp_ts - bp->bp_n_bufs;
}

void
buf_recommend_reuse (buffer_desc_t * buf)
{
  /* Dirty write.  Should be inside the bp_mtx of the pool.
   * Not dangerous since bp__first_free is always some buffer of the bp or NULL and likewise with bd_next.  The list can get screwed up, it is always popped a single unit at a time and if a member of the list gets reallocated by normal eans the list just breaks because the  bd_next of the allocated one will be reset.
   * Pops from the list are serialized anyway and normal checks apply to the buffers, so even if they actually are not reusable no harm is done. */

  /* this does not work.  Turned off until fixed. */
  return;
  if (!BUF_AVAIL (buf))
    return;
  buf->bd_next = buf->bd_pool->bp_first_free;
  buf->bd_pool->bp_first_free = buf;
}


int
bp_mtx_entry_check (dk_mutex_t * mtx, du_thread_t * self, void * cd)
{
  it_not_in_any (self, NULL);
  return 1;
}

int32 malloc_bufs = 0;
#define MIN_BUFS_FOR_ALLOC 100000 /* below 1gig buffer space */

buffer_pool_t *
bp_make_buffer_list (int n)
{
  buffer_desc_t *buf;
  int c;
  unsigned char *buffers_space;
  unsigned char *buf_ptr = NULL;
  NEW_VARZ (buffer_pool_t, bp);
  bp->bp_mtx = mutex_allocate ();
  mutex_option (bp->bp_mtx, "BP", NULL /*bp_mtx_entry_check */, (void*) bp);
  bp->bp_n_bufs = n;
  bp->bp_bufs = (buffer_desc_t *) dk_alloc (sizeof (buffer_desc_t) * n);
  memset (bp->bp_bufs, 0, sizeof (buffer_desc_t) * n);
  bp->bp_sort_tmp = (buffer_desc_t **) dk_alloc (sizeof (caddr_t) * n);

  if (n > MIN_BUFS_FOR_ALLOC)
    malloc_bufs = 1;

  if (!malloc_bufs)
    {
      buffers_space = (unsigned char *) malloc (PAGE_SZ * (n + 1));
      if (!buffers_space)
	GPF_T1 ("Cannot allocate memory for Database buffers, try to decrease NumberOfBuffers INI setting");
      buffers_space = (db_buf_t) ALIGN_8K (buffers_space);
      memset (buffers_space, 0, ALIGN_VOIDP (PAGE_SZ) * n);
      buf_ptr = buffers_space;
    }
  else
    c_use_o_direct = 0;

  for (c = 0; c < n; c++)
    {
      buf = &bp->bp_bufs[c];
      if (malloc_bufs)
	{
	  if (c_use_o_direct)
	    GPF_T1 ("An exe compiled with malloc_bufs defd is not compatible with the use O_DIRECT setting");
	  buf->bd_buffer = malloc (BUF_ALLOC_SZ);
	  BUF_SET_END_MARK (buf);
	}
      else
	{
	  buf->bd_buffer = buf_ptr;
	  buf_ptr += ALIGN_VOIDP (PAGE_SZ);
	}
      buf->bd_pool = bp;
      buf->bd_timestamp = 0;
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
bp_free_buffer_list (buffer_pool_t *bp)
{
  mutex_free (bp->bp_mtx);

  dk_free (bp->bp_bufs, sizeof (buffer_desc_t) * bp->bp_n_bufs);
  dk_free (bp->bp_sort_tmp, sizeof (caddr_t) * bp->bp_n_bufs);

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
	dp_addr_t ext_no;
	target -= start;
	ext_no = target / dbs->dbs_stripe_unit;
	stripe_inx = ext_no % seg->ds_n_stripes;
	*place = PAGE_SZ * (OFF_T) (((ext_no / seg->ds_n_stripes) * dbs->dbs_stripe_unit) + (target - (ext_no * dbs->dbs_stripe_unit)));
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
  IN_DBS (dbs);
  dbs_locate_incbackup_bit (dbs, page, &array, &array_page, &inx, &bit);
  if (on)
    {
      if (0 == (array[inx] & 1L<<bit))
	{
	  page_set_update_checksum (array, inx, bit);
      array[inx] |= (1 << bit);
    }
    }
  else
    {
      if (array[inx] & 1L<<bit)
	{
	  page_set_update_checksum (array, inx, bit);
    array[inx] &= ~(1 << bit);
	}
    }
  LEAVE_DBS (dbs);
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


int
page_is_disk_order (buffer_desc_t * buf, row_size_t * lead_start, row_size_t * lead_end)
{
  int inx, prev = 0;
  page_map_t * pm = buf->bd_content_map;
  prev = pm->pm_entries[0];
  for (inx = 1; inx < pm->pm_count; inx++)
    {
      if (pm->pm_entries[inx] < prev)
	{
	  return 0;
	}
      prev = pm->pm_entries[inx];
    }
  return 1;
}


typedef struct row_writer_s
{
  size_t	rw_fill;
  db_buf_t	rw_copy;
  z_stream	rw_z_stream;
} row_writer_t;



void
row_copy_no_comp (row_writer_t * rw, db_buf_t row, int row_len)
{
  row_len = ROW_ALIGN (row_len);
  if (rw->rw_fill + row_len > PAGE_SZ)
    GPF_T1 ("rows add up to more than the page size");
  memcpy (rw->rw_copy + rw->rw_fill, row, row_len);
  rw->rw_fill += row_len;
}


int
row_compress (row_writer_t * rw, db_buf_t row, int row_len)
{
  row_len = ROW_ALIGN (row_len);
  rw->rw_z_stream.next_in = row;
  rw->rw_z_stream.avail_in = row_len;
  rw->rw_fill += ROW_ALIGN (row_len);
  return deflate (&rw->rw_z_stream, Z_NO_FLUSH);
}

#define PAGE_WRITE_ORG 1
#define PAGE_WRITE_COPY 2

int
page_prepare_write (buffer_desc_t * buf, db_buf_t * copy, int * copy_fill, int page_compress)
{
  int rc, is_order;
  row_size_t first_c, last_c;
  dbe_key_t * key;
  row_writer_t rw;

  if (DPF_INDEX != SHORT_REF (buf->bd_buffer + DP_FLAGS))
    {
      *copy = buf->bd_buffer;
      return PAGE_WRITE_ORG;
    }
  if (!wi_inst.wi_checkpoint_atomic)
    pg_check_map_1 (buf);
  is_order = page_is_disk_order (buf, &first_c, &last_c);
  if (!page_compress && is_order)
    {
      *copy = buf->bd_buffer;
      return PAGE_WRITE_ORG;
    }
  key = buf->bd_tree->it_key;
  rw.rw_copy = *copy;
  rw.rw_fill = 0;
  if (page_compress)
    {
      SHORT_SET (rw.rw_copy + DP_FLAGS, DPF_GZIP | SHORT_REF (buf->bd_buffer + DP_FLAGS));
      rw.rw_fill = DP_COMP_HEAD_LEN;
      rw.rw_z_stream.zalloc = (alloc_func)0;
      rw.rw_z_stream.zfree = (free_func)0;
      rc = deflateInit(&rw.rw_z_stream, Z_DEFAULT_COMPRESSION);
      if (rc != Z_OK)
	GPF_T1 ("compress init failed");
      rw.rw_z_stream.avail_out = PAGE_SZ / 2 - DP_COMP_HEAD_LEN;
      rw.rw_z_stream.next_out = rw.rw_copy + DP_COMP_HEAD_LEN;
      row_compress (&rw, buf->bd_buffer + DP_COMP_HEAD_LEN, DP_DATA - DP_COMP_HEAD_LEN);
    }
  else
    {
      memcpy (rw.rw_copy, buf->bd_buffer, DP_DATA);
      rw.rw_fill = DP_DATA;
    }
  DO_ROWS (buf, irow, row,  NULL)
    {
      int row_len = row_length (row, key);
      if (page_compress)
	{
	  int rc = row_compress (&rw, row, row_len);
	  if (Z_OK != rc)
	    goto not_compressible;
	}
      else
	row_copy_no_comp (&rw, row, row_len);
    }
  END_DO_ROWS;
  if (page_compress)
    {
      dtp_t gap_mark[4];
      if (rw.rw_fill < PAGE_SZ - 1)
	{
	  page_write_gap (gap_mark, PAGE_SZ - ROW_ALIGN (rw.rw_fill));
	  rw.rw_z_stream.next_in = gap_mark;
	  rw.rw_z_stream.avail_in = 3;
	}
      else
	rw.rw_z_stream.avail_in = 0;
      rc = deflate (&rw.rw_z_stream, Z_FINISH);
      SHORT_SET (rw.rw_copy + DP_COMP_LEN, ((PAGE_SZ / 2) - DP_COMP_HEAD_LEN) - rw.rw_z_stream.avail_out);
      deflateEnd (&rw.rw_z_stream);
      if (rc != Z_STREAM_END)
	goto not_compressible;
    }
  else
    {
      if (rw.rw_fill < PAGE_SZ - 1)
	page_write_gap (rw.rw_copy + rw.rw_fill, PAGE_SZ - rw.rw_fill);
#if 0 /* only if corrupt write suspected */
      memcpy (buf->bd_buffer + DP_DATA, rw.rw_copy + DP_DATA, PAGE_DATA_SZ);
      pg_make_map (buf);
	      pg_check_map_1 (buf);
#endif
    }
  return PAGE_WRITE_COPY;
 not_compressible:
  return page_prepare_write (buf, copy, copy_fill, 0);
}


void
page_after_read (buffer_desc_t * buf)
{
  /* if compression, uncompress and get any overflow page if all compressed data is not here */
  int rc;
  dtp_t page_buf[PAGE_SZ - DP_COMP_HEAD_LEN];
  z_stream d_stream;
  short flags = SHORT_REF (buf->bd_buffer + DP_FLAGS);
  if (0 == (flags & DPF_GZIP))
    return;
  d_stream.zalloc = (alloc_func)0;
  d_stream.zfree = (free_func)0;
  d_stream.opaque = (voidpf)0;
  d_stream.next_in  = (Bytef *) buf->bd_buffer + DP_COMP_HEAD_LEN;
  d_stream.avail_in = SHORT_REF (buf->bd_buffer + DP_COMP_LEN);
  d_stream.next_out = &page_buf[0];
  d_stream.avail_out = PAGE_SZ - DP_COMP_HEAD_LEN;
  inflateInit (&d_stream);
  rc = inflate (&d_stream, Z_FINISH);
  if (Z_STREAM_END != rc)
    GPF_T1 ("bad uncompress");
  inflateEnd (&d_stream);
  SHORT_SET (buf->bd_buffer + DP_FLAGS, flags & ~DPF_GZIP);
  memcpy (buf->bd_buffer + DP_COMP_HEAD_LEN, page_buf, (PAGE_SZ - DP_COMP_HEAD_LEN) - d_stream.avail_out);
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



#define ALIGNED_PAGE_COPY(copy, source) \
  ALIGNED_PAGE_BUFFER (copy##_temp); \
  db_buf_t copy = IS_8K (source) ? source : (memcpy (copy##_temp, source, 8192), copy##_temp);


long disk_reads = 0;
long disk_writes = 0;
long read_cum_time = 0;
long write_cum_time = 0;
int assertion_on_read_fail = 1;

#if 0
int
buf_disk_read_impl (buffer_desc_t * buf)
{
  if (!IS_IO_ALIGN (buf->bd_buffer))
    {
      return buf_disk_read_not_aligned (buf);
    }
  return buf_disk_read_impl (buf, buf->bd_buffer);
}

int
buf_disk_read_not_aligned (buffer_desc_t * buf)
{
  ALIGNED_PAGE_BUFFER (copy);
  db_buf_t target = IS_IO_ALIGN (buf->bd_buffer) ? buf->bd_buffer : copy;
}

int
buf_disk_read_impl (buffer_desc_t * buf, db_buf_t target)
#endif

int
buf_disk_read (buffer_desc_t * buf)
{
  long start;
  OFF_T rc;
  dbe_storage_t * dbs = buf->bd_storage;
  short flags;
  OFF_T off;
  disk_reads++;
#ifdef O_DIRECT
  if (c_use_o_direct && !IS_IO_ALIGN (buf->bd_buffer))
    GPF_T1 ("buf_disk_read (): The buffer is not io-aligned");
#endif
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
      rc = read (dbs->dbs_fd, (char *)(buf->bd_buffer), PAGE_SZ);
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
  page_after_read (buf);
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
  if (dbs_cpt_recov_in_progress)
    return WI_OK;
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
  dtp_t c_buf[PAGE_SZ];
  db_buf_t out = c_buf;
  long start;
  int bytes, n_out;
  short flags;
  dbe_storage_t * dbs = buf->bd_storage;
  OFF_T rc;
  OFF_T off;
  dp_addr_t dest = (phys_dp_to ? phys_dp_to : buf->bd_physical_page);
#ifdef VALGRIND
  memset (c_buf, 0, sizeof (c_buf));
#endif
#ifdef O_DIRECT
  if (c_use_o_direct && !IS_IO_ALIGN (buf->bd_buffer))
    GPF_T1 ("buf_disk_write (): The buffer is not io-aligned");
#endif
  if (dbs_cpt_recov_in_progress)
    out = buf->bd_buffer;
  else
    page_prepare_write (buf, &out, &n_out, c_compress_mode);
  /* dbg_sleep (2); */
  flags = SHORT_REF (buf->bd_buffer + DP_FLAGS);
  DBG_PT_WRITE (buf, phys_dp_to);
#ifdef O12DEBUG
  if (flags == DPF_INDEX)
    buf_check_deleted_refs (buf, checkpoint_in_progress ? 0 : 1);
#endif

  if (0 == dest)
    GPF_T1 ("cannot write buffer to 0 page.");
  if (flags == DPF_INDEX && !dbs_cpt_recov_in_progress)
    {
      if (KI_TEMP != (key_id_t)LONG_REF (buf->bd_buffer + DP_KEY_ID)
	  && !sch_id_to_key (wi_inst.wi_schema, LONG_REF (buf->bd_buffer + DP_KEY_ID)))
	GPF_T1 ("Writing index page with no key");
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
      rc = write (fd, out, bytes);
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
	      if (PAGE_SZ != write (dbs->dbs_fd, (char *)out,
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
	  rc = write (dbs->dbs_fd, (char *)out, bytes);
	  if (rc != bytes)
	    {
	      log_error ("Write failure on database %s", dbs->dbs_file);
	      GPF_T;
	    }
#if 0
	  {
	    unsigned char page [PAGE_SZ];
	    if (36 * PAGE_SZ == LSEEK (dbs->dbs_fd, 36 * PAGE_SZ, SEEK_SET))
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

  dbs_unfreeable (dbs, first_dp, flag);
  buf_disk_read (first);
  if (flag != DPF_EXTENT_MAP)
    {
      page_set_checksum_init (first->bd_buffer + DP_DATA);
    }
  while ((dp_first = LONG_REF (prev->bd_buffer + DP_OVERFLOW)))
    {
      buffer_desc_t *buf = buffer_allocate (flag);
      buf->bd_storage = dbs;
      prev->bd_next = buf;
      buf->bd_physical_page = buf->bd_page = dp_first;
      dbs_unfreeable (dbs, dp_first, flag);
      buf_disk_read (buf);
      page_set_checksum_init (buf->bd_buffer + DP_DATA);
      prev = buf;
    }
  return first;
}

void
dbs_write_page_set (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  while (buf)
    {
      if (SHORT_REF (buf->bd_buffer + DP_FLAGS) != DPF_EXTENT_MAP)
	{
	  page_set_check (buf->bd_buffer + DP_DATA);
	}
      if (buf->bd_next)
	{
	  LONG_SET (buf->bd_buffer + DP_OVERFLOW, buf->bd_next->bd_page);
	}
      else
	LONG_SET (buf->bd_buffer + DP_OVERFLOW, 0);
      buf_disk_write (buf, 0);
      buf = buf->bd_next;
    }
}


int
dbs_locate_page_bit (dbe_storage_t* dbs, buffer_desc_t** ppage_set, dp_addr_t near_dp,
    uint32 **array, dp_addr_t *page_no, int *inx, int *bit, int offset, int assert_on_out_of_range)
{
  dp_addr_t near_page;
  dp_addr_t n;
  buffer_desc_t* free_set = ppage_set[0];

  ASSERT_IN_DBS (dbs);
  near_page = near_dp / BITS_ON_PAGE;

  *page_no = near_page;
  for (n = 0; n < near_page; n++)
    {
      if (!free_set->bd_next)
	{
	  if (assert_on_out_of_range)
	  GPF_T1 ("looking for a dp allocation bit that is out of range");
	  else
	    return 0;
	}
      free_set = free_set->bd_next;
    }
  page_set_check (free_set->bd_buffer + DP_DATA);
  *array = (dp_addr_t *) (free_set->bd_buffer + DP_DATA);
  *inx = (int) ((near_dp % BITS_ON_PAGE) / BITS_IN_LONG);
  *bit = (int) ((near_dp % BITS_ON_PAGE) % BITS_IN_LONG);
  return 1;
}





int
word_free_bit (dp_addr_t w)
{
  int n;

  for (n = 0; w & 1; n++)
    w >>= 1;

  return n;
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


#ifdef PAGE_SET_CHECKSUM
/* if free set checksum is on, checking the free bit checks the checksum and this should be serialized to avoid false positives
 * If no checksum, no serialization is needed for checking a free bit */
#define IN_DBS_IF_CKSUM(dbs) IN_DBS(dbs)
#define LEAVE_DBS_IF_CKSUM(dbs) LEAVE_DBS(dbs)
#else
#define IN_DBS_IF_CKSUM(dbs)
#define LEAVE_DBS_IF_CKSUM(dbs)
#endif

long
dbs_is_free_page (dbe_storage_t * dbs, dp_addr_t n)
{
  uint32 *array;
  dp_addr_t page;
  int inx, bit;
  if (n >= dbs->dbs_n_pages)
    return 1;
  IN_DBS (dbs);
  dbs_locate_free_bit (dbs, n, &array, &page, &inx, &bit);
  if (0 == (array[inx] & (1 << bit)))
    {
      LEAVE_DBS (dbs);
    return 1;
    }
  LEAVE_DBS (dbs);
  return 0;
}


void
dbs_page_allocated (dbe_storage_t * dbs, dp_addr_t n)
{
  uint32 *array;
  dp_addr_t page;
  int inx, bit;
  dbs_locate_free_bit (dbs, n, &array, &page, &inx, &bit);
  if (0 == (array[inx] & 1L << bit))
    {
      page_set_update_checksum (array, inx, bit);
  array[inx] |= 1 << bit;
  dbs->dbs_n_free_pages--;
    }
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


long stripe_growth_ratio;


void
itc_hold_pages (it_cursor_t * itc, buffer_desc_t * buf, int n)
{
  int held = 1;
  index_tree_t * it = itc->itc_tree;
  FAILCK (itc);

  if (it->it_extent_map == it->it_storage->dbs_extent_map
      && it->it_n_index_est + it->it_n_blob_est > KEY_OWN_EXTENT_THRESHOLD
      && it->it_key && it->it_key->key_id > DD_FIRST_PRIVATE_OID)
    {
      if (!it_own_extent_map (it))
	held = 0;
    }
  if (held)
    {
      extent_map_t * hold_em = itc->itc_tree->it_extent_map;
      itc->itc_n_pages_on_hold = n;
      held = em_hold_remap (hold_em, &itc->itc_n_pages_on_hold);
      itc->itc_hold_em = hold_em;
    }
  if (!held)
    {
      itc->itc_n_pages_on_hold = 0;
      log_error ("Out of disk space for database");
      if (itc->itc_ltrx)
	itc->itc_ltrx->lt_error = LTE_NO_DISK; /* could be temp isp, no ltrx */
      itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
    }
}


void
itc_free_hold (it_cursor_t * itc)
{
  if (itc->itc_n_pages_on_hold)
    em_free_remap_hold (itc->itc_hold_em, &itc->itc_n_pages_on_hold);
}



void
dbs_unfreeable (dbe_storage_t * dbs, dp_addr_t dp, int flag)
{
  if (!flag) GPF_T1 ("must have non-0 flag for unfreeable dp");
  sethash (DP_ADDR2VOID (dp), dbs->dbs_unfreeable_dps, (void*)(ptrlong)  flag);
}


int freeing_unfreeable; /*must be set if freeing registry, remap list or such pages */

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
      LEAVE_DBS (dbs);
      return;
    }
  if (gethash (DP_ADDR2VOID (dp), dbs->dbs_unfreeable_dps))
    {
      if (freeing_unfreeable)
	remhash (DP_ADDR2VOID (dp), dbs->dbs_unfreeable_dps);
      else
	GPF_T1 ("freeing an unfreeable page, like registry, remap list or page set");
    }
  dbs_locate_free_bit (dbs, dp, &page, &page_no, &word, &bit);

#ifndef NDEBUG
  /* GK: way to catch a double free of disk page */
  if (!(page[word] & (1 << bit)))
    GPF_T1 ("Double free of disk page.");
#endif
  page_set_update_checksum (page, word, bit);
  page[word] &= ~(1 << bit);
  dbs->dbs_n_free_pages++;
  disk_releases++;
  LEAVE_DBS (dbs);
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
      if (!mid_buf)
	{
	  log_error ("In buf_qsort, the items being sorted have moved, so results are not necessarily in order");
	  return;
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
size_t left_bufs_len;


void
buf_sort (buffer_desc_t ** bs, int n_bufs, sort_key_func_t key)
{
  mutex_enter (buf_sort_mtx);
  if (!left_bufs)
    {
      left_bufs_len = sizeof (caddr_t) * main_bufs;
      left_bufs = (buffer_desc_t **) dk_alloc (left_bufs_len);
    }
  if ((left_bufs_len / sizeof (caddr_t)) < n_bufs)
    {
      dk_free ((void *) left_bufs, (size_t)-1);
      left_bufs_len = sizeof (caddr_t) * n_bufs;
      left_bufs = (buffer_desc_t **) dk_alloc (left_bufs_len);
    }
  buf_qsort (bs, left_bufs, n_bufs, 0, key);
  if (main_bufs != (left_bufs_len / sizeof (caddr_t)))
    {
      dk_free ((void *) left_bufs, (size_t)-1);
      left_bufs = NULL;
    }
  mutex_leave (buf_sort_mtx);
}



void
gen_bsort (int * in, int n_in, sort_cmp_func_t cmp, void* cd)
{
  /* Bubble sort n_in first items in the array. */
  int n, m;
  for (m = n_in - 1; m > 0; m--)
    {
      for (n = 0; n < m; n++)
	{
	  int tmp;
	  if (DVC_GREATER == cmp (in[n], in[n + 1], cd))
	    {
	      tmp = in[n + 1];
	      in[n + 1] = in[n];
	      in[n] = tmp;
	    }
	}
    }
}


void
gen_qsort (int * in, int * left,
	   int n_in, int depth, sort_cmp_func_t cmp, void* cd)
{
  /* sort the ints in in, using cmp for comparison, cmp gets cd for context */
  if (n_in < 2)
    return;
  if (n_in < 3)
    {
      if (DVC_GREATER == cmp (in[0], in[1], cd))
	{
	  int tmp = in[0];
	  in[0] = in[1];
	  in[1] = tmp;
	}
    }
  else
    {
      int split;
      int mid = 0, is_mid = 0;
      int n_left = 0, n_right = n_in - 1;
      int inx;
      if (depth > 60)
	{
	  gen_bsort (in, n_in, cmp, cd);
	  return;
	}
      split =  in[n_in / 2];
      for (inx = 0; inx < n_in; inx++)
	{
	  int res = cmp (in[inx], split, cd);
	  if (!is_mid && DVC_MATCH == res)
	    {
	      is_mid = 1;
	      mid = in[inx];
	      continue;
	    }
	  if (DVC_LESS == res)
	    {
	      left[n_left++] = in[inx];
	    }
	  else
	    {
	      left[n_right--] = in[inx];
	    }
	}
      if (!is_mid)
	{
	  log_error ("in gen_qsort, items being sorted look to have changed during sort, result will not be in order");
	  return;
	}
      gen_qsort (left, in, n_left, depth + 1, cmp, cd);
      gen_qsort (left + n_right + 1, in + n_right + 1,
		 (n_in - n_right) - 1, depth + 1, cmp, cd);
      memcpy (in, left, n_left * sizeof (int));
      in[n_left] = mid;
      memcpy (in + n_right + 1, left + n_right + 1,
	  ((n_in - n_right) - 1) * sizeof (int));

    }
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
	  index_tree_t * tree = buf->bd_tree;
	  if (tree)
	    {
	      it_map_t * itm;
	      if (bp_buf_enter (buf, &itm))
		{
	      if (buf->bd_is_dirty
		  && !buf->bd_iq)
		{
		  if (!buf->bd_is_write &&
		      !buf->bd_write_waiting)
		    {
		      buf->bd_readers++;
		      bufs[fill++] = buf;
		    }
		    }
		  mutex_leave (&itm->itm_mtx);
		}
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
	  index_tree_t * tree = bufs[n]->bd_tree;
	  it_map_t * itm = IT_DP_MAP (tree, bufs[n]->bd_page);
	  mutex_enter (&itm->itm_mtx);
	  page_leave_inner (bufs[n]);
	  mutex_leave (&itm->itm_mtx);
	}
    }
  dk_free (bufs, bufs_len);
  last_flush_time = approx_msec_real_time ();
  if (!is_in_bp)
    mutex_leave (bp->bp_mtx);
}


OFF_T
db_file_size (int fd, char * fn, int check)
{
  OFF_T rem;
  OFF_T size = LSEEK (fd, 0L, SEEK_END);
  if ((rem = (size % (PAGE_SZ * EXTENT_SZ))) && check)
    {
      log_error ("It is impossible to have a database file %s with a length not multiple of 2MB.", fn);
      log_error ("The process must have last terminated while growing the file.");
      log_error ("Please contact OpenLink Customer Support");
      call_exit (1);
    }
  return size - rem;
}


int
dbs_open_disks (dbe_storage_t * dbs)
{
  int inx;
  dp_addr_t pages = 0;
  int first_exists = 0;
  int is_first = 1;
  ALIGNED_PAGE_ZERO (zero);
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
	  dbs_sys_db_check (dst->dst_file);
	  file_set_rw (dst->dst_file);
	  dst->dst_sem = semaphore_allocate (0);
	  dst->dst_fds = (int*) dk_alloc_box_zero (sizeof (int) * n_fds_per_file, DV_CUSTOM);
	  dst->dst_fd_fill = 0;
	  for (inx = 0; inx < n_fds_per_file; inx++)
	    {
	      int fd = fd_open (dst->dst_file, DB_OPEN_FLAGS);
	      if (fd < 0)
		{
		  log_error ("Cannot open stripe on %s (%d)",
			     dst->dst_file, errno);
		  call_exit (1);
		}
	      dst_fd_done (dst, fd);
	    }
	}
      size = db_file_size (dst->dst_fds[0], dst->dst_file, 0);
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
wi_close()
{
  int inx;

  DO_BOX (buffer_pool_t *, bp, inx, wi_inst.wi_bps)
  {
    bp_free_buffer_list (bp);
    dk_free (bp, sizeof (buffer_pool_t));
  }
  END_DO_BOX;
  dk_free_box (wi_inst.wi_bps);

  resource_clear (pm_rc_1, NULL);
  resource_clear (pm_rc_2, NULL);
  resource_clear (pm_rc_3, NULL);
  resource_clear (pm_rc_4, NULL);

  buffer_free (cp_buf);

#if HAVE_SYS_MMAN_H && !defined(__FreeBSD__)
  if (cf_lock_in_mem)
    munlockall ();
#endif
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
#ifndef WIN32
      sync();
#endif
      break;

    case 2:
    default:
      if (dbs->dbs_disks)
	{
	  DO_SET (disk_segment_t *, seg, &dbs->dbs_disks)
	    {
	      DO_BOX (disk_stripe_t *, dst, inx, seg->ds_stripes)
		{
		  fd_fsync (dst->dst_fds[0]);
		}
	      END_DO_BOX;
	    }
	  END_DO_SET ();
	}
      else
	{
	  fd_fsync (dbs->dbs_fd);
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

extern caddr_t *local_interfaces;
extern char *srv_cwd;

static void
dbs_init_id (char * str)
{
  int inx;
  char buf[100];
  MD5_CTX ctx;
  memset (&ctx, 0, sizeof (MD5_CTX));
  MD5Init (&ctx);
  DO_BOX (caddr_t, val, inx, local_interfaces)
    {
      MD5Update (&ctx, (unsigned char *) val, box_length (val) - 1);
    }
  END_DO_BOX;
  MD5Update (&ctx, (unsigned char *) srv_cwd, strlen (srv_cwd));
  snprintf (buf, sizeof (buf), "%ld,%p", srv_pid, &str);
  MD5Update (&ctx, (unsigned char *) buf, strlen (buf));
  MD5Final (str, &ctx);
}

void
dbs_write_cfg_page (dbe_storage_t * dbs, int is_first)
{
  disk_stripe_t *dst = NULL;
  wi_database_t db;
  int fd, rc;
  ALIGNED_PAGE_ZERO (zero);
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
  if (!rdf_no_string_inline)
    strcpy_ck (db.db_generic, "3100");
  else
    strcpy_ck (db.db_generic, DBMS_STORAGE_VER);
  db.db_registry = dbs->dbs_registry;
  db.db_extent_set = dbs->dbs_extent_set->bd_page;
  db.db_free_set = dbs->dbs_free_set->bd_page;
  db.db_incbackup_set = dbs->dbs_incbackup_set->bd_page;
  db.db_stripe_unit = dbs->dbs_stripe_unit;
  db.db_initial_gen = dbs->dbs_initial_gen;
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
  if (0 == dbs->dbs_id[0])
    dbs_init_id (dbs->dbs_id);
  memcpy (db.db_id, dbs->dbs_id, sizeof (db.db_id));

  LSEEK (fd, 0, SEEK_SET);
  memcpy (zero, &db, sizeof (db));
  rc = write (fd, zero, PAGE_SZ);
  if (PAGE_SZ != rc)
    printf  ("failed write of 0 page errno %d\n", errno);
  if (dst)
    dst_fd_done (dst, fd);
}


dtp_t less_than_any[] = {KV_LEFT_DUMMY, 0, 0, 0, 0, 0};
/* dummy key 0 row version, 4x0 for a 0 leaf ptr */

void
pg_init_new_root (buffer_desc_t * buf)
{
  db_buf_t page = buf->bd_buffer;
  memcpy (page + DP_DATA, less_than_any, sizeof (less_than_any));
  page_write_gap (page + DP_DATA + sizeof (less_than_any), PAGE_SZ - (DP_DATA + sizeof (less_than_any)));
  pg_make_map (buf);
}


#ifdef BYTE_ORDER_REV_SUPPORT


static void
dbs_reverse_cfg_page (wi_database_t * cfg_page)
{
  DBS_REVERSE_LONG ((db_buf_t)(&cfg_page->db_extent_set));
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
      /* GK: the +2 part in ROW_MAX_DATA is necessary to allow reverse of oversized rows */ \
    } \
}

row_size_t
row_na_length (db_buf_t  row, dbe_key_t * key)
{
  int len;
  row_ver_t rv = IE_ROW_VERSION (row);
  key_ver_t kv = IE_KEY_VERSION (row);
  if (!kv)
    {
      len = key->key_key_len[rv];
      if (len <= 0)
	len = COL_VAR_LEN_MASK & DBS_REV_SHORT_REF (row - len);
    }
  else if (kv == KV_LEFT_DUMMY)
    {
      len = 6;
    }
  else
    {
      dbe_key_t * row_key = NULL;
      if (kv >= KV_LONG_GAP
	  || !(row_key = key->key_versions[kv]) )
	STRUCTURE_FAULT1 ("bad kv in row_na_length");
      len = row_key->key_row_len[rv];
      if (len <= 0)
	len = COL_VAR_LEN_MASK & DBS_REV_SHORT_REF (row - len);
    }
  return len;
}



#ifndef KEYCOMP
int
dbs_reset_row_na (db_buf_t row, dbe_key_t * page_key)
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
	case DV_IRI_ID:
	  DBS_REVERSE_LONG (row + off);
	  break;
	case DV_INT64:
	case DV_IRI_ID_8:
	  DBS_REVERSE_LONG (row + off);
	  DBS_REVERSE_LONG (row + off + 4);
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
  if (key_id && row_key && row_key->key_is_bitmap)
    {
      int off, len, _e =0;
      KEY_COL_RESET_NA (row_key, row, (*row_key->key_bm_cl), off, len);
    }

  return IE_NEXT (orig_row);
}
#endif


void
dbs_rev_h_index  (dbe_storage_t * dbs, buffer_desc_t * buf)
{
#ifndef KEYCOMP
  if (buf->bd_physical_page && dbs_is_free_page (dbs, buf->bd_physical_page))
		return;
  if (gethash (DP_ADDR2VOID (buf->bd_physical_page), dbs->dbs_cpt_remap))
		return;
  DBS_REVERSE_LONG (buf->bd_buffer + DP_PARENT);

  DBS_REVERSE_SHORT (buf->bd_buffer + DP_RIGHT_INSERTS);
  DBS_REVERSE_SHORT (buf->bd_buffer + DP_LAST_INSERT);

  DBS_REVERSE_SHORT (buf->bd_buffer + DP_FLAGS);
  DBS_REVERSE_SHORT (buf->bd_buffer + DP_FIRST);

  DBS_REVERSE_long (buf->bd_buffer + DP_KEY_ID);

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
    key_id_t pg_key_id = LONG_REF (page + DP_KEY_ID);
    dbe_key_t * pg_key = KI_TEMP == pg_key_id ?  buf->bd_tree->it_key
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
#endif
}

void
dbs_rev_h_free_set  (dbe_storage_t * dbs, buffer_desc_t * buf)
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
dbs_rev_h_ext (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  GPF_T1 ("not implemented");
}
void dbs_rev_h_blob (dbe_storage_t * dbs, buffer_desc_t * buf)
{
  DBS_REVERSE_LONG (buf->bd_buffer + DP_PARENT);
  DBS_REVERSE_LONG (buf->bd_buffer + DP_BLOB_TS);
  DBS_REVERSE_SHORT (buf->bd_buffer + DP_FLAGS);
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
  ALIGNED_PAGE_ZERO (zero);
  if (dbs->dbs_disks)
    {
      OFF_T off;
      dst = dp_disk_locate (dbs, 0, &off);
      fd = dst_fd (dst);
    }
  else
    fd = dbs->dbs_fd;
  LSEEK (fd, 0, SEEK_SET);
  read (fd, (char *) zero, PAGE_SZ);
  memcpy (cfg_page, zero, sizeof (*cfg_page));
  storage_ver = atoi (cfg_page->db_generic);
  if (storage_ver < 3100)
    {
      log_error ("The database you are opening was last closed with a server of version %d." , storage_ver);
      log_error ("The present server is of version " DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR ".");
      log_error ("This server does not read this pre 6.0 format.");
      call_exit (-1);
    }
  if (storage_ver > atoi (DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR))
    {
      log_error ("The database you are opening was last closed with a server of version %d." , storage_ver);
      log_error ("The present server is of version " DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR ".");
      log_error ("The database will contain data types which are not recognized by this server.");
      log_error ("Please use a newer server.");
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
  log_info ("Database version %d", storage_ver);
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

int
page_set_length (buffer_desc_t * buf)
{
  int n = 0;
  for (buf = buf; buf; buf = buf->bd_next)
    n++;
  return n;
}


dbe_storage_t *
dbs_from_file (char * name, char * file, char type, volatile int * exists)
{
  wi_database_t cfg_page;
  OFF_T size;
  int fd = -1;
  dbe_storage_t * dbs = dbs_allocate (name, type);
  *exists = 0;
  if (!file)
    file = CFG_FILE;
  dbs_read_cfg ((caddr_t *) dbs, file);

  dbs_sys_db_check (dbs->dbs_file);
  if (dbs->dbs_log_name)
    dbs_sys_db_check (dbs->dbs_log_name);

  if (dbs->dbs_disks)
    {
      *exists = dbs_open_disks (dbs);
    }
  else
    {
      int of = DB_OPEN_FLAGS;
      file_set_rw (dbs->dbs_file);
      if (DBS_TEMP == type)
	{
	  caddr_t sz = file_stat (dbs->dbs_file, 1);
	  long real_sz = (sz ? strtol (sz, (char **)NULL, 10) : 0);

	  dk_free_box (sz);
	  if (real_sz > temp_db_size * 1024L * 1024L)
	    {
	      if (unlink (dbs->dbs_file))
		{
		  log_error ("Can't unlink the temp db file %.1000s : %m", dbs->dbs_file);
		}
	      else
		log_info ("Unlinked the temp db file %.1000s as its size (%ldMB)"
		    " was greater than TempDBSize INI (%ldMB)",
		    dbs->dbs_file, (real_sz/1024/1024), temp_db_size);
	    }
	}
      fd = fd_open (dbs->dbs_file, of);
      if (fd < 0)
	{
	  log_error ("Cannot open database in %s (%d)", dbs->dbs_file, errno);
	  call_exit (1);
	}

#if defined (F_SETLK)
     if (DBS_TEMP != type)
      {
	struct flock fl;

#ifdef DEBUG
        log_info ("Setting write lock on %s", dbs->dbs_file);
#endif

	/* Get an advisory WRITE lock */
	fl.l_type = F_WRLCK;
	fl.l_whence = SEEK_SET;
	fl.l_start = 0;
	fl.l_len = 0;

	if (fcntl (fd, F_SETLK, &fl) < 0)
	  {
  	    /* we could not get a lock, so who owns it? */
	    fcntl (fd, F_GETLK, &fl);

	    log_error ("Virtuoso is already running (pid %ld)", fl.l_pid);
 	    call_exit(1);
	  }
      }
#endif

      dbs->dbs_fd = fd;
      size = db_file_size (fd, dbs->dbs_file, 0);
      dbs->dbs_file_length = size;
      dbs->dbs_n_pages = (dp_addr_t ) (dbs->dbs_file_length / PAGE_SZ);
      if (size)
	*exists = 1;
    }

  if (*exists && type == DBS_RECOVER)
    return NULL;

  if (*exists && DBS_TEMP != type)
    dbs_read_cfg_page (dbs, &cfg_page);

  if (dbs->dbs_disks)
    {
      int inx;
      DO_SET (disk_segment_t *, ds, &dbs->dbs_disks)
	{
	  DO_BOX (disk_stripe_t *, dst, inx, ds->ds_stripes)
	    {
	      db_file_size (dst->dst_fds[0], dst->dst_file, 1);
	    }
	  END_DO_BOX;
	}
      END_DO_SET ();
    }
  else
    {
      db_file_size (fd, dbs->dbs_file, 1);
    }

  if (*exists && DBS_TEMP != type)
    {
      /* There's a file. */
      dbs->dbs_stripe_unit = cfg_page.db_stripe_unit ? cfg_page.db_stripe_unit : 1;
      dbs->dbs_initial_gen = cfg_page.db_initial_gen;
#ifdef BYTE_ORDER_REV_SUPPORT
      if (dbs_reverse_db)
	dbs_reverse_cfg_page (&cfg_page);
#endif
      /* some consistency checks for the DB file */
      CHECK_PG (db_free_set, "free set");
      CHECK_PG (db_incbackup_set, "incbackup set");

      db_version_string = box_dv_short_string (cfg_page.db_ver);

      dbs->dbs_registry = cfg_page.db_registry;
      dbs->dbs_extent_set = dbs_read_page_set (dbs, cfg_page.db_extent_set, DPF_EXTENT_SET);

      dbs->dbs_n_pages_in_extent_set = EXTENT_SZ * BITS_ON_PAGE * page_set_length (dbs->dbs_extent_set);
      dbs->dbs_free_set = dbs_read_page_set (dbs, cfg_page.db_free_set, DPF_FREE_SET);
      dbs->dbs_n_pages_in_sets = BITS_ON_PAGE * page_set_length (dbs->dbs_free_set);
      dbs->dbs_incbackup_set = dbs_read_page_set (dbs, cfg_page.db_incbackup_set, DPF_INCBACKUP_SET);
      dbs_read_checkpoint_remap (dbs, cfg_page.db_checkpoint_map);
      dbs_cpt_recov (dbs);
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
      memcpy (dbs->dbs_id, cfg_page.db_id, sizeof (cfg_page.db_id));
      if (DBS_PRIMARY == type)
	dbs_init_registry (dbs);
      dbs_extent_open (dbs);
      dbs->dbs_n_free_pages = dbs_count_free_pages (dbs);
    }
  else
    {
      /* No database. Make one. */
      IN_DBS (dbs);
      dbs->dbs_stripe_unit = c_stripe_unit;
      dbs_extent_init (dbs);
      dbs->dbs_initial_gen = atoi (DBMS_SRV_GEN_MAJOR	) * 100 + atoi (DBMS_SRV_GEN_MINOR);
      dbs_write_cfg_page (dbs, 0);
      if (DBS_PRIMARY == type)
	dbs_init_registry (dbs);
      dbs->dbs_n_free_pages = dbs_count_free_pages (dbs);
    }
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
  wi_inst.wi_files = id_str_hash_create (11);
  wd->wd_qualifier = box_dv_short_string ("DB");
  this_wd = wd;
  master_dbs = dbs_from_file ("master", NULL, DBS_PRIMARY, &db_exists);
  master_dbs->dbs_registry_hash = registry;
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


extern dk_mutex_t * log_write_mtx;
extern   dk_mutex_t * transit_list_mtx;

int64 bdf_is_avail_mask;

void
wi_open (char *mode)
{
  int inx;
  const_length_init ();
  bm_init ();
  extent_map_create_mtx = mutex_allocate ();
  mutex_option (extent_map_create_mtx, "em_create", NULL, NULL);
  search_inline_init ();
  wi_inst.wi_txn_mtx = mutex_allocate_typed (MUTEX_TYPE_SHORT);
  mutex_option (wi_inst.wi_txn_mtx, "TXN", NULL /*txn_mtx_entry_check */, NULL);
  pl_ref_count_mtx = mutex_allocate ();
  mutex_option (pl_ref_count_mtx, "pl_ref_count", NULL, NULL);
  log_write_mtx = mutex_allocate ();
  mutex_option (log_write_mtx, "Log_write", NULL, NULL);
  transit_list_mtx = mutex_allocate ();
  mutex_option (transit_list_mtx, "transit_list", NULL, NULL);
  srv_client_defaults_init ();
  wi_inst.wi_bps = (buffer_pool_t **) dk_alloc_box (bp_n_bps * sizeof (caddr_t), DV_CUSTOM);
  for (inx = 0; inx < bp_n_bps; inx++)
    {
      wi_inst.wi_bps[inx] = bp_make_buffer_list (main_bufs / bp_n_bps);
      wi_inst.wi_bps[inx]->bp_ts = inx * ((main_bufs / BP_N_BUCKETS) / 9); /* out of step, don't do stats all at the same time */
    }
  wi_inst.wi_n_bps = (short) BOX_ELEMENTS (wi_inst.wi_bps);
  {
    buffer_desc_t bd;
    bd.bdf.flags = 0xffffffffffffffff;
    bd.bdf.r.is_read_aside = 0;
    bdf_is_avail_mask = bd.bdf.flags;
  }
  pm_rc_1 = resource_allocate (main_bufs / 20, (rc_constr_t) map_allocate,
			    (rc_destr_t) map_free, (rc_destr_t) NULL, (void*) PM_SZ_1);
  pm_rc_2 = resource_allocate (main_bufs / 20, (rc_constr_t) map_allocate,
			    (rc_destr_t) map_free, (rc_destr_t) NULL, (void*) PM_SZ_2);
  pm_rc_3 = resource_allocate (main_bufs / 20, (rc_constr_t) map_allocate,
			    (rc_destr_t) map_free, (rc_destr_t) NULL, (void*) PM_SZ_3);
  pm_rc_4 = resource_allocate (10, (rc_constr_t) map_allocate,
			    (rc_destr_t) map_free, (rc_destr_t) NULL, (void*) PM_SZ_4);

  cp_buf = buffer_allocate (DPF_CP_REMAP);

  wi_open_dbs ();
  mt_write_init ();
  sqlo_tc_init ();
  if (wi_inst.wi_master->dbs_initial_gen >= 3126)
    rdf_no_string_inline = 1;
  else
    {
      IN_TXN;
      if (registry_get ("rdf_no_string_inline"))
	rdf_no_string_inline = 1;
      LEAVE_TXN;
    }
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
  dk_cache_allocs (DKSES_OUT_BUFFER_LENGTH, 20);
  for (sz = 16; sz < 480; sz += 8)
    {
      if (!dk_is_alloc_cache (sz))
	dk_cache_allocs (sz, 10);
    }
}


db_buf_t rbp_allocate (void);
void rbp_free (caddr_t p);

extern dk_hash_t * dp_compact_checked;
extern dk_mutex_t * dp_compact_mtx;

#ifdef MTX_DEBUG
#define TRX_RC_SZ 2
#else
#define TRX_RC_SZ 200
#endif

int
itc_free_cb (caddr_t itc)
{
  itc_free ((it_cursor_t *)itc);
  return 1;
}


int
it_free_cb (caddr_t it)
{
  it_temp_free ((index_tree_t *)it);
  return 1;
}


void
wi_init_globals (void)
{
  PrpcInitialize ();
  blobio_init ();

#ifdef PAGE_SET_CHECKSUM
  page_set_checksums = hash_table_allocate (203);
#endif
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
  pfh_rc = resource_allocate (10, (rc_constr_t) pfh_allocate,
				  (rc_destr_t) pfh_free, NULL, 0);

  rb_page_rc = resource_allocate (100, (rc_constr_t) rbp_allocate,
				  (rc_destr_t) rbp_free, NULL, 0);
  mutex_option (rb_page_rc->rc_mtx, "rb_pages", NULL, NULL);
  /* resource_no_sem (lock_rc); */

  trx_rc = resource_allocate (TRX_RC_SZ, (rc_constr_t) lt_allocate,
			    (rc_destr_t) lt_free, (rc_destr_t) lt_clear, 0);
  buf_sort_mtx = mutex_allocate_typed (MUTEX_TYPE_LONG);
  time_mtx = mutex_allocate ();
  checkpoint_mtx = mutex_allocate_typed (MUTEX_TYPE_LONG);
  mutex_option (checkpoint_mtx, "CPT", NULL, NULL);
  old_roots_mtx = mutex_allocate ();
  mutex_option (old_roots_mtx, "old_root_images", NULL, NULL);

  hash_index_cache.hic_mtx = mutex_allocate ();
#ifdef BUF_DEBUG
  temp_trees_mtx = mutex_allocate ();
#endif
  mutex_option (hash_index_cache.hic_mtx, "hash_index_cache", NULL, NULL);
  hash_index_cache.hic_hashes = id_hash_allocate (101, sizeof (caddr_t), sizeof (caddr_t), treehash, treehashcmp);
  hash_index_cache.hic_col_to_it = hash_table_allocate (201);
  hash_index_cache.hic_pk_to_it = hash_table_allocate (201);
  dp_compact_mtx = mutex_allocate_typed (MUTEX_TYPE_SPIN);
  dp_compact_checked = hash_table_allocate (1000);
  dk_hash_set_rehash (dp_compact_checked, 3);
  dbs_autocompact_mtx = mutex_allocate ();
  dk_mem_hooks (DV_INDEX_TREE, box_non_copiable, it_free_cb, 0);
  dk_mem_hooks (DV_ITC, box_non_copiable, itc_free_cb, 0);
  alt_ts_mtx = mutex_allocate ();
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
      {
	int inx;
	char mtx_name[200];
	snprintf (mtx_name, sizeof (mtx_name), "lock_rel_%100s", kf->kf_name);
	mutex_option (kf->kf_it->it_lock_release_mtx, mtx_name, NULL,  NULL);
	for (inx = 0; inx < IT_N_MAPS; inx++)
	  {
	    sprintf (mtx_name, "%s:%d", kf->kf_name, inx);
	    mutex_option (&(kf->kf_it->it_maps[inx].itm_mtx), mtx_name, NULL /*it_page_map_entry_check*/, (void*) &kf->kf_it->it_maps[inx]);
      }
      }
      kf->kf_it->it_key = key;
      if (start_str)
	start_dp = atol (start_str);
      dk_free_tree (start_str);
      if (!start_dp)
	{
	  it_map_t * itm;
	  buffer_desc_t * buf = it_new_page (kf->kf_it, 0, DPF_INDEX, 0, 0);
	  pg_init_new_root (buf);
	  kf->kf_it->it_root = buf->bd_page;
	  itm = IT_DP_MAP (kf->kf_it, buf->bd_page);
	  mutex_enter (&itm->itm_mtx);
	  page_leave_inner (buf);
	  mutex_leave (&itm->itm_mtx);
	}
      else
	{
	  kf->kf_it->it_root = start_dp;
	}
      kf_set_extent_map (kf);
    }
  END_DO_BOX;
}


#define ROOT_WRONG_KEY 0
#define ROOT_EMPTY 1
#define ROOT_NOT_EMPTY 2


int
buf_is_empty_root (buffer_desc_t * buf, dbe_key_t * key)
{
  int ct = buf->bd_content_map->pm_count, pos;
  key_id_t key_id = LONG_REF (buf->bd_buffer + DP_KEY_ID);
  key_ver_t kv;
  dbe_key_t * page_key = sch_id_to_key (wi_inst.wi_schema, key_id);
  if (!page_key || page_key->key_super_id != key->key_super_id)
    return ROOT_WRONG_KEY;
  if (ct != 1)
    return ROOT_NOT_EMPTY;
  pos = buf->bd_content_map->pm_entries[0];
  kv = IE_KEY_VERSION (buf->bd_buffer + pos);
  if (kv != KV_LEFT_DUMMY)
    return ROOT_NOT_EMPTY;
  if (0 != LONG_REF (buf->bd_buffer + pos + LD_LEAF))
    return ROOT_NOT_EMPTY;
  return ROOT_EMPTY;
}


void
key_dropped (dbe_key_t * key)
{
  int inx;
  if (key->key_supers)
    return; /* is in the tree of its super */
  DO_BOX (dbe_key_frag_t *, kf, inx, key->key_fragments)
    {
      int is_empty;
      buffer_desc_t * buf;
      it_cursor_t itc_auto;
      it_cursor_t * itc = &itc_auto;
      ITC_INIT (itc, kf->kf_it->itc_commit_space, NULL);
      itc_from_it (itc, kf->kf_it);
      do {
	ITC_IN_VOLATILE_MAP (itc, itc->itc_tree->it_root);
	page_wait_access (itc, itc->itc_tree->it_root, NULL, &buf, PA_WRITE, RWG_WAIT_SPLIT);
      } while (itc->itc_to_reset >= RWG_WAIT_SPLIT);
      is_empty = buf_is_empty_root (buf, key);
      if (ROOT_NOT_EMPTY == is_empty)
	{
	  log_error ("Dropping schema for a non-empty index tree %s.  Not dangerous.", key->key_name);
	}

      if (ROOT_WRONG_KEY != is_empty)
	{
	  itc->itc_page = buf->bd_page;
	  ITC_IN_KNOWN_MAP (itc, buf->bd_page);
      itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE);
	  it_free_page (kf->kf_it, buf);
	  ITC_LEAVE_MAP_NC (itc);
	}
      else
	{
	  log_error ("Tree with a root of another key in dropping tree of %s.", key->key_name);
	}
      ITC_LEAVE_MAPS (itc);
      if (kf->kf_it->it_extent_map != kf->kf_it->it_storage->dbs_extent_map)
	{
	  char name[1000];
	  snprintf (name, sizeof (name), "__EM:%s", kf->kf_name);
	  IN_TXN;
	  registry_set (name, NULL);
	  LEAVE_TXN;
	}
      IN_TXN;
      registry_set (kf->kf_name, NULL);
      dk_set_delete (&wi_inst.wi_master->dbs_trees, kf->kf_it);
      dk_set_push (&wi_inst.wi_master->dbs_deleted_trees, kf->kf_it);
      LEAVE_TXN;
      kf->kf_it->it_root = 0;
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
      snprintf (str, sizeof (str), "%d", (int) kf->kf_it->it_root);
      ASSERT_IN_TXN; /* called from checkpoint inside txn mtx */
      dbs_registry_set (kf->kf_it->it_storage, kf->kf_name, str, 0);
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
  /* first mark the dropped as 0, then all non dropped.  Note that a dropped + recreate of same name may get confused otherwise with the drop overwriting the new root */
  while (dk_hit_next (&hit, (void**) &k, (void **) &key))
    {
      if (0 == key->key_fragments[0]->kf_it->it_root)
	dbe_key_save_roots (key);
    }
  dk_hash_iterator (&hit, sc->sc_id_to_key);
  while (dk_hit_next (&hit, (void**) &k, (void **) &key))
    {
      if (key->key_fragments[0]->kf_it->it_root)
	dbe_key_save_roots (key);
    }
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
