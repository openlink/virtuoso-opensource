
/*
 *  space.c
 *
 *  $Id$
 *
 *  Delta spaces
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

#include "wi.h"

#ifdef MAP_DEBUG
# define dbg_map_printf(a) printf a
#else
# define dbg_map_printf(a)
#endif

#ifdef PAGE_TRACE
int page_trace_on = 1;
#endif

#if 0
void
isp_clear (index_space_t * isp)
{
  isp_unregister_all (isp);
  clrhash (isp->isp_dp_to_buf);
  clrhash (isp->isp_remap);
  clrhash (isp->isp_page_to_cursor);
}
#endif

int space_rehash_threshold = 2;


index_space_t *
isp_allocate (index_tree_t * it, int hash_sz)
{
  long remap_hash_sz = hash_sz;
  NEW_VAR (index_space_t, isp);
  memset (isp, 0, sizeof (index_space_t));

  isp->isp_dp_to_buf = hash_table_allocate (hash_sz);
  isp->isp_remap = hash_table_allocate (remap_hash_sz);
  dk_hash_set_rehash (isp->isp_dp_to_buf, space_rehash_threshold);
  dk_hash_set_rehash (isp->isp_remap, space_rehash_threshold);

  isp->isp_tree = it;
  isp->isp_page_to_cursor = hash_table_allocate (11);
  dk_hash_set_rehash (isp->isp_page_to_cursor, space_rehash_threshold);


  isp->isp_hash_size = isp->isp_dp_to_buf->ht_actual_size;
  return isp;
}


const char *
isp_title (index_space_t * isp)
{
  if (!isp)
    return ("<none>");
  return (!isp->isp_prev ? "CPOINT"
	  : "COMMIT");
}


void
isp_free (index_space_t * isp)
{
  isp_unregister_all (isp);
  hash_table_free (isp->isp_dp_to_buf);
  hash_table_free (isp->isp_remap);

  hash_table_free (isp->isp_page_to_cursor);

  dk_free ((caddr_t) isp, sizeof (index_space_t));
}


dbe_schema_t *
isp_schema (void * thr)
{
  return (wi_inst.wi_schema);
}


buffer_desc_t *
isp_locate_page (index_space_t * isp, dp_addr_t dp,
		 index_space_t ** isp_ret, dp_addr_t * phys_dp)
{
  dp_addr_t remap;
  buffer_desc_t *buf;
  if (isp != isp->isp_tree->it_commit_space)
    GPF_T1 ("Only pf in commit space is allowed");
  *isp_ret = isp;
  buf = (buffer_desc_t *) gethash (DP_ADDR2VOID (dp), isp->isp_dp_to_buf);
  if (buf)
    {
      *phys_dp = buf->bd_physical_page;
      return buf;
    }
  remap = (dp_addr_t) (uptrlong) gethash (DP_ADDR2VOID (dp), isp->isp_remap);
  if (!remap)
    remap = (dp_addr_t) (uptrlong) gethash (DP_ADDR2VOID (dp), isp->isp_tree->it_storage->dbs_cpt_remap);
  if (!remap)
    *phys_dp = dp;
  else
    *phys_dp = remap;
  return NULL;
}


void
it_cache_check (index_tree_t * it)
{
  long remap;
  int error = 0, gpf_on_error = 0;
  short l;
  index_space_t * isp = it->it_commit_space;
  IN_PAGE_MAP (it);
  while (isp)
    {
      dk_hash_iterator_t hit;
      ptrlong dp;
      buffer_desc_t * buf;
      dk_hash_iterator (&hit, isp->isp_dp_to_buf);
      while (dk_hit_next (&hit, (void**) &dp, (void**) &buf))
	{
	  if (!buf->bd_buffer)
	    continue; /* this is a decoy holding a place while real buffer being read */
	  if (buf->bd_is_write || buf->bd_readers)
	    {
	      log_error ("Buffer %p occupied in cpt\n", buf);
	      /* This can be legitimate if a thread is in freeze mode and one itc is on a table scan and another is in order by or hash fill, so that the freeze is in the temp space operation . */
	      /* error = 1; */
	    }
	  if (((dp_addr_t) dp) != buf->bd_page)
	    {
	      log_error ("*** Buffer %p cache dp %ld buf dp %ld \n",
		      (void *)buf, dp, (unsigned long) buf->bd_page);
	      error = 1;
	    }
	  if (dbs_is_free_page (it->it_storage, (dp_addr_t) dp))
	    {
	      log_error ("***  buffer with free dp L=%ld buf=%p \n",
		      dp, (void *)buf);
	      error = 1;
	    }
	  if (((dp_addr_t) dp) != buf->bd_physical_page
	      && dbs_is_free_page (it->it_storage, buf->bd_physical_page))
	    {
	      log_error ("***  buffer with free remap dp L=%ld P=%ld buf=%p \n",
		      dp, (unsigned long) buf->bd_physical_page, (void *)buf);
	      error = 1;
	    }
	  remap = (long) (ptrlong) gethash (DP_ADDR2VOID (dp), isp->isp_remap);
	  if (!remap)
	    remap = (long) (ptrlong) gethash (DP_ADDR2VOID (buf->bd_page), it->it_storage->dbs_cpt_remap);
	  if ((remap && buf->bd_physical_page != (dp_addr_t) remap)
	      || (((dp_addr_t)dp) != buf->bd_physical_page && ((dp_addr_t) remap) != buf->bd_physical_page))
	    {
	      log_error ("*** Inconsistent remap L=%ld buf P=%ld isp P=%ld \n",
		      dp, (unsigned long) buf->bd_physical_page, remap);
	      error = 1;
	    }
	  l=SHORT_REF (buf->bd_buffer + DP_FLAGS);
	  if (dp != buf->bd_physical_page && DPF_BLOB == l && DPF_BLOB_DIR == l )
	    {
	      log_error ("*** Blob bot to be remapped L=%ld P=%ld \n",
		      dp, (unsigned long) buf->bd_physical_page);
	    }
	  if (error && gpf_on_error)
	    GPF_T1 ("Buffer cache consistency check failed.");
	}
      if (error)
	{
	  gpf_on_error = 1;
	  error = 0;
	  continue; /* loop again, this time gpf on first error. */
	}
      isp = isp->isp_prev;
    }
  LEAVE_PAGE_MAP (it);
}


void
isp_set_buffer (index_space_t * space_to, dp_addr_t logical_dp,
		dp_addr_t physical_dp, buffer_desc_t * buf)
{
  ASSERT_IN_MAP (space_to->isp_tree);
  if (buf->bd_page)
    {
      if (buf->bd_space != space_to)
	GPF_T1 ("buffer not supposed to be in any tree when placed into another tree");
      if (buf->bd_page != logical_dp)
	remhash (DP_ADDR2VOID (buf->bd_page), buf->bd_space->isp_dp_to_buf);
    };
  if (buf->bd_page != logical_dp)
    {
      sethash (DP_ADDR2VOID (logical_dp), space_to->isp_dp_to_buf, (void *) buf);
      buf->bd_pl = (page_lock_t *) gethash (DP_ADDR2VOID (logical_dp), space_to->isp_tree->it_locks);
    }
  buf->bd_page = logical_dp;
  buf->bd_space = space_to;
  buf->bd_physical_page = physical_dp;
  buf->bd_storage = buf->bd_space->isp_tree->it_storage;
}


#define PM_HEADER ((long) &(((page_map_t *) 0)->pm_entries))

#define PM_ACTIVE_BYTES(pm) \
  (PM_HEADER + (pm->pm_count * sizeof (short)))



void
itc_buf_set_dirty (it_cursor_t * itc, buffer_desc_t * buf, int stay_in_map)
{
  if (!buf->bd_is_dirty)
    {
      if (DELTA_STAY_INSIDE == stay_in_map)
	{
	  buf->bd_is_dirty = 1;
	  wi_inst.wi_n_dirty++;
	  return;
	}
      ITC_LEAVE_MAP (itc);
      buf_set_dirty (buf);
      ITC_IN_MAP (itc);
    }
}


buffer_desc_t *
itc_delta_this_buffer (it_cursor_t * itc, buffer_desc_t * buf, int stay_in_map)
{
  /* The caller has no access but intends to change the parent link. */
  index_space_t * space_to = itc->itc_space;
  dp_addr_t remap_to;
#ifdef PAGE_TRACE
  dp_addr_t old_dp = buf->bd_physical_page;
#endif
#ifdef _NOT
  FAILCK (itc);
#endif
  ASSERT_IN_MAP (itc->itc_tree);
  if (gethash (DP_ADDR2VOID (buf->bd_page), itc->itc_space->isp_remap))
    {
      itc_buf_set_dirty (itc, buf, stay_in_map);
      return (buf);
    }
  if (isp_can_reuse_logical (space_to, buf->bd_page))
    remap_to = buf->bd_page;
  else
    remap_to = dbs_get_free_disk_page (space_to->isp_tree->it_storage,
				       buf->bd_physical_page);
  if (!remap_to)
    {
      if (itc->itc_n_pages_on_hold)
	GPF_T1 ("pages on hold exceeded");
      if (DELTA_STAY_INSIDE == stay_in_map)
	GPF_T1 ("out of disk on reloc_right_leaves.");
      log_error ("Out of disk space for database");
      itc->itc_ltrx->lt_error = LTE_NO_DISK;
      itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
    }

  isp_set_buffer (space_to, buf->bd_page, remap_to, buf);
  sethash (DP_ADDR2VOID (buf->bd_page), space_to->isp_remap,
	   DP_ADDR2VOID (remap_to));
  itc_buf_set_dirty (itc, buf, stay_in_map);
  DBG_PT_DELTA_CLEAN (buf, old_dp);
  return buf;
}


buffer_desc_t *
isp_new_page (index_space_t * isp, dp_addr_t addr, int type, int in_pmap,
	      int has_hold)
{
  index_tree_t * it = isp->isp_tree;
  dbe_storage_t * dbs = it->it_storage;
  buffer_desc_t *buf;
  dp_addr_t physical_dp;

  IN_DBS (dbs);
  if (in_pmap)
    GPF_T1 ("do not call isp_new_page in page map");
  if (dbs->dbs_n_free_pages - dbs->dbs_n_pages_on_hold < 10
      && !has_hold)
    {
      dbs_extend_file (dbs);
      wi_storage_offsets ();
      if (dbs->dbs_n_free_pages - dbs->dbs_n_pages_on_hold < 10
	  && !has_hold)
	{
	  LEAVE_DBS (dbs);
	  return NULL;
	}
    }

  physical_dp = dbs_get_free_disk_page (dbs, addr);
  if (!physical_dp)
    {

      log_error ("Out of disk space for database");
      return NULL;
    }

  buf = bp_get_buffer (NULL, BP_BUF_REQUIRED);
  if (buf->bd_readers != 1)
    GPF_T1 ("expecting buf to be wired down when allocated");
  if (!in_pmap)
    buf_dbg_printf (("Buf %x new in tree %x dp=%d\n", buf, isp, physical_dp));
    IN_PAGE_MAP (it);

  isp_set_buffer (isp, physical_dp, physical_dp, buf);
  sethash (DP_ADDR2VOID (physical_dp), isp->isp_remap,
	   DP_ADDR2VOID (physical_dp));
  buf->bd_readers = 0;
  BD_SET_IS_WRITE (buf, 1);
  LEAVE_PAGE_MAP (it);
#ifdef PAGE_TRACE

  memset (buf->bd_buffer, 0, PAGE_SZ); /* all for debug view */
#else
  memset (buf->bd_buffer, 0, PAGE_SZ - PAGE_DATA_SZ); /* header only */
#endif
  SHORT_SET (buf->bd_buffer + DP_FLAGS, type);
  if (type == DPF_INDEX)
    {
      page_map_t * map = buf->bd_content_map;
      if (!map)
	buf->bd_content_map = (page_map_t*) resource_get (PM_RC (PM_SZ_1));
      else
	{
	  if (map->pm_size > PM_SZ_1)
	    {
	      resource_store (PM_RC (map->pm_size), (void*) map);
	      buf->bd_content_map = (page_map_t *) resource_get (PM_RC (PM_SZ_1));
	    }
	}
      pg_map_clear (buf);
      SHORT_SET (buf->bd_buffer + DP_KEY_ID, it->it_key ? it->it_key->key_id : KI_TEMP);
    }
  else if (buf->bd_content_map)
    {
      resource_store (PM_RC (buf->bd_content_map->pm_size), (void*) buf->bd_content_map);
      buf->bd_content_map = NULL;
    }

  buf_set_dirty (buf);
  DBG_PT_PRINTF (("New page L=%d B=%p FL=%d K=%s \n", buf->bd_page, buf, type,
		 it->it_key ? (it->it_key->key_name ? it->it_key->key_name : "unnamed key") : "no key"));
  return buf;
}

#define IS_NEW_BUFFER(buf) \
  (buf->bd_page == buf->bd_physical_page && !DP_CHECKPOINT_REMAP (buf->bd_storage, buf->bd_page))


void
isp_free_page (index_space_t * isp, buffer_desc_t * buf)
{
  short l;
  dp_addr_t remap = (dp_addr_t) (ptrlong) gethash (DP_ADDR2VOID (buf->bd_page), isp->isp_remap);
  ASSERT_IN_MAP (buf->bd_space->isp_tree);
  if (!buf->bd_is_write)
    GPF_T1 ("isp_free_page without write access to buffer.");
  l=SHORT_REF (buf->bd_buffer + DP_FLAGS);
  if (!(l == DPF_BLOB || l == DPF_BLOB_DIR)
      && !remap)
    GPF_T1 ("Freeing a page that is not remapped");
  if (buf->bd_page != buf->bd_physical_page && (DPF_BLOB_DIR == l || DPF_BLOB == l))
    GPF_T1 ("blob is not supposed to be remapped");
  DBG_PT_PRINTF (("    Delete %ld remap %ld FL=%d buf=%p\n", buf->bd_page, buf->bd_physical_page, l, buf));
  if (buf->bd_iq)
    {
      LEAVE_PAGE_MAP (isp->isp_tree);
      buf_cancel_write (buf);
      IN_PAGE_MAP (isp->isp_tree);
    }

  if (!remap)
    {
      /* a blob in checkpoint space can be deleted without a remap existing in commit space. */
      if (DPF_BLOB != l && DPF_BLOB_DIR != l )
	GPF_T1 ("not supposed to delete a buffer in a different space unless it's a blob");
      if (buf->bd_is_dirty)
	GPF_T1 ("blob in checkpoint space can't be dirty - has no remap, in commit, hence is in checkpoint");
      sethash (DP_ADDR2VOID (buf->bd_page), isp->isp_remap, (void*) (ptrlong) DP_DELETED);
      remhash (DP_ADDR2VOID (buf->bd_page), buf->bd_space->isp_dp_to_buf);
      buf_set_last (buf);
      page_leave_inner (buf);
      return;
    }
  if (IS_NEW_BUFFER (buf))
    /* if this was CREATED AND DELETED without intervening checkpoint the delete
     * does not carry outside the commit space. */
    remhash (DP_ADDR2VOID (buf->bd_page), isp->isp_remap);
  else
    sethash (DP_ADDR2VOID (buf->bd_page), isp->isp_remap, (void *) (ptrlong) DP_DELETED);
  remhash (DP_ADDR2VOID (buf->bd_page), buf->bd_space->isp_dp_to_buf);

  isp_free_remap (isp, buf->bd_page, buf->bd_physical_page);

  if (buf->bd_is_dirty)
    {
      wi_inst.wi_n_dirty--;
    }
  page_mark_change (buf, RWG_WAIT_SPLIT);
  buf_set_last (buf);
  page_leave_inner (buf);
}


void
isp_free_blob_dp_no_read (index_space_t * isp, dp_addr_t dp)
{
  buffer_desc_t * buf;
  index_space_t * phys_isp = NULL;
  dp_addr_t phys_dp = 0;
  ASSERT_IN_MAP (isp->isp_tree);
  buf = isp_locate_page (isp, dp, &phys_isp, &phys_dp);
  if (buf && buf->bd_being_read)
    {
      log_info ("Deleting blob page while it is being read dp=%d .\n", dp);
/* the buffer can be a being read decoy with no dp, so check dps only if not being read */
    }
  else if (phys_dp != dp)
    GPF_T1 ("A blob is not supposed to be remapped in isp_free_blob_dp_no_read");
  if (buf)
    {
      it_cursor_t itc_auto;
      it_cursor_t * itc = &itc_auto;
      ITC_INIT (itc, isp, NULL);
      itc_from_it (itc, isp->isp_tree);
      itc->itc_is_in_map_sem = 1; /* already inside, thus if wait, leave the page map */
/* Note that the the buf is not passed to page_wait_access.  This is because of 'being read' possibility. page_fault will detect this and sync. */
      page_wait_access (itc, dp, NULL, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
      if (PF_OF_DELETED == buf)
	{
	  ITC_LEAVE_MAP (itc);
	  return;
	}
      if (DPF_BLOB != SHORT_REF (buf->bd_buffer + DP_FLAGS))
	GPF_T1 ("About to delete non-blob page from blob page dir.");
      ITC_IN_MAP (itc); /* get back in, could have come out if waited */
      isp_free_page (isp, buf);
      return;
    }
  DBG_PT_PRINTF (("Free absent blob  L=%d \n", dp));
  {
    dp_addr_t remap = (dp_addr_t) (ptrlong) gethash (DP_ADDR2VOID (dp), isp->isp_remap);
    dp_addr_t cpt_remap = (dp_addr_t) (ptrlong) DP_CHECKPOINT_REMAP (isp->isp_tree->it_storage, dp);
    if (cpt_remap)
      GPF_T1 ("Blob not expected to have cpt remap in delete no read");
    if (remap)
      {
	/* if this was CREATED AND DELETED without intervening checkpoint the delete
	 * does not carry outside commit space. */
	remhash (DP_ADDR2VOID (dp), isp->isp_remap);
	dbs_free_disk_page (isp->isp_tree->it_storage, dp);
	LEAVE_DBS (isp->isp_tree->it_storage);
      }
    else
      {
	sethash (DP_ADDR2VOID (dp), isp->isp_remap, (void *) (ptrlong) DP_DELETED);
      }
  }
}


