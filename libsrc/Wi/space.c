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

#include "wi.h"

#ifdef MAP_DEBUG
# define dbg_map_printf(a) printf a
#else
# define dbg_map_printf(a)
#endif

#ifdef PAGE_TRACE
int page_trace_on = 1;
#endif


int space_rehash_threshold = 2;



int32 dbs_cache_check_enable = 0;

void
it_cache_check (index_tree_t * it, int mode)
{
  long remap;
  int error = 0, gpf_on_error = 0;
  short l;
  int inx;
  for (inx = 0; inx < IT_N_MAPS; inx++)
    {
      it_map_t * itm = &it->it_maps[inx];
      dk_hash_iterator_t hit;
      ptrlong dp;
      buffer_desc_t * buf;
      mutex_enter (&itm->itm_mtx);
      dk_hash_iterator (&hit, &itm->itm_dp_to_buf);
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
	  if (dbs_cache_check_enable && DPF_INDEX == SHORT_REF (buf->bd_buffer + DP_FLAGS)
	      && IT_CHECK_FAST != mode)
	    pg_check_map_1 (buf);
	    if (buf->bd_is_dirty && !gethash (DP_ADDR2VOID (buf->bd_page), &itm->itm_remap))
	      {
		log_error ("Buffer %p dirty but no remap, tree %s", buf, it->it_key ? it->it_key->key_name : "no key");
		dbg_page_map_log (buf, "missed_flush.txt", "Dirty page with no remap");
	      }
	  if (((dp_addr_t) dp) != buf->bd_page)
	    {
	      log_error ("*** Buffer %p cache dp %ld buf dp %ld \n",
		      (void *)buf, dp, (unsigned long) buf->bd_page);
	      error = 1;
	    }
	  if (IT_CHECK_POST == mode && dbs_is_free_page (it->it_storage, (dp_addr_t) dp))
	    {
	      log_error ("***  buffer with free dp L=%ld buf=%p \n",
		      dp, (void *)buf);
	      error = 1;
	    }
	  if (IT_CHECK_POST != mode && dbs_is_free_page (it->it_storage, (dp_addr_t) dp))
	    {
	      short fl = SHORT_REF (buf->bd_buffer + DP_FLAGS);
	      if (fl != DPF_BLOB && fl != DPF_BLOB_DIR)
		{
		  log_error ("***  In cpt, suspect to have buffer with free dp L=%ld buf=%p  while it is neither blob or blob dir, which may be free at this point if uncommitted.\n",
			     dp, (void *)buf);
		  error = 1;
		}
	    }
	  if (((dp_addr_t) dp) != buf->bd_physical_page
	      && dbs_is_free_page (it->it_storage, buf->bd_physical_page))
	    {
	      log_error ("***  buffer with free remap dp L=%ld P=%ld buf=%p \n",
		      dp, (unsigned long) buf->bd_physical_page, (void *)buf);
	      error = 1;
	    }
	    remap = (long) (ptrlong) gethash (DP_ADDR2VOID (dp), &itm->itm_remap);
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
	  if (dp != buf->bd_physical_page && (DPF_BLOB == l || DPF_BLOB_DIR == l ))
	    {
	      log_error ("*** Blob not to be remapped L=%ld P=%ld \n",
		      dp, (unsigned long) buf->bd_physical_page);
	    }
	  if (error && IT_CHECK_FAST == mode)
	    log_error ("it_cache_check got errors but will not stop in mid cpt");
	  else if (error && gpf_on_error)
	    GPF_T1 ("Buffer cache consistency check failed.");
	}
      if (error)
	{
	  gpf_on_error = 1;
	  error = 0;
	  mutex_leave (&itm->itm_mtx);
	  continue; /* loop again, this time gpf on first error. */
	}
      mutex_leave (&itm->itm_mtx);
    }
}


buffer_desc_t *
itc_delta_this_buffer (it_cursor_t * itc, buffer_desc_t * buf, int stay_in_map)
{
  /* The caller has no access but intends to change the parent link. */
  it_map_t * itm;
  dp_addr_t remap_to;
#ifdef PAGE_TRACE
  dp_addr_t old_dp = buf->bd_physical_page;
#endif
#ifdef _NOT
  FAILCK (itc);
#endif
  ASSERT_IN_MAP (itc->itc_tree, buf->bd_page);
  itm = IT_DP_MAP (itc->itc_tree, buf->bd_page);
#ifdef MTX_DEBUG
  if (buf->bd_is_dirty && !gethash (DP_ADDR2VOID (buf->bd_page), &itm->itm_remap))
    GPF_T1 ("dirty but not remapped in checking delta");
#endif
  if (gethash (DP_ADDR2VOID (buf->bd_page), &itm->itm_remap))
    {
      buf->bd_is_dirty = 1;
      return (buf);
    }
  if (it_can_reuse_logical (itc->itc_tree, buf->bd_page))
    remap_to = buf->bd_page;
  else
    remap_to = em_new_dp (itc->itc_tree->it_extent_map, EXT_REMAP, 0, &itc->itc_n_pages_on_hold);

  if (!remap_to)
    {
      if (LT_CLOSING == itc->itc_ltrx->lt_status)
	{
	  log_error ("Out if disk during commit.  The transaction is in effect and will be replayed from the log at restart.  Exiting due to no disk space, thus cannot maintain separation of checkpoint and commit space and transactional semantic."
		     "This happens due to running out of safety margin, which is not expected to happen.  If this takes place without in fact being out of disk on the database or consistently in a given situation, the condition may be reported to support.   This is a planned exit and not a database corruption.  A core will be made for possible support.");
	  GPF_T1 ("Deliberately made core for possible support");
	}
      if (itc->itc_n_pages_on_hold)
	GPF_T1 ("The database is out of disk during an insert.  The insert has exceeded its space safety margin.  This does not normally happen.  This is a planned exit and not a corruption. Make more disk space available.  If this occurs continuously or without in fact running out of space, this may be reported to support.");
      if (DELTA_STAY_INSIDE == stay_in_map)
	GPF_T1 ("out of disk on reloc_right_leaves.");
      log_error ("Out of disk space for database");
      itc->itc_ltrx->lt_error = LTE_NO_DISK;
      itc_bust_this_trx (itc, &buf, ITC_BUST_THROW);
    }

  buf->bd_physical_page = remap_to;
  sethash (DP_ADDR2VOID (buf->bd_page), &itm->itm_remap,
	   DP_ADDR2VOID (remap_to));
  buf->bd_is_dirty = 1;
  DBG_PT_DELTA_CLEAN (buf, old_dp);
  return buf;
}

long tc_new_page;

buffer_desc_t *
it_new_page (index_tree_t * it, dp_addr_t addr, int type, int in_pmap,
	     it_cursor_t * has_hold)
{
  it_map_t * itm;
  extent_map_t * em = it->it_extent_map;
  int ext_type = (!it->it_blobs_with_index && (DPF_BLOB  == type || DPF_BLOB_DIR == type)) ? EXT_BLOB : EXT_INDEX, n_tries;
  buffer_desc_t *buf;
  buffer_pool_t * action_bp = NULL;
  dp_addr_t physical_dp;

  if (in_pmap)
    GPF_T1 ("do not call isp_new_page in page map");

  physical_dp = em_new_dp (em, ext_type, addr, NULL);
  if (!physical_dp)
    {
      log_error ("Out of disk space for database");
      if (DPF_INDEX == type)
	{
	  /* a split must never fail to get a page.  Use the remap hold as a backup */
	  physical_dp = em_new_dp (it->it_extent_map, EXT_REMAP, 0, &has_hold->itc_n_pages_on_hold);
	  if (!physical_dp)
	    {
	      log_error ("After running out of disk, cannot get a page from remap reserve to complete operation.  Exiting.");
	      call_exit (-1);
	    }
	}
      else
	return NULL;
    }

  if (DPF_INDEX == type)
    it->it_n_index_est++;
  else
    it->it_n_blob_est++;
  for (n_tries =  0; ; n_tries++)
    {
      buf = bp_get_buffer_1 (NULL, &action_bp, in_log_replay ? BP_BUF_REQUIRED : BP_BUF_IF_AVAIL);
      if (buf)
	break;
      if (action_bp)
	bp_delayed_stat_action (action_bp);
      action_bp = NULL;
      if (n_tries > 10)
	{
	  log_error ("Signaling out of disk due to failure to get a buffer.  This condition is not a case of running out of disk");
	  return NULL;
	}
      if (5 == n_tries)
	log_info ("Failed to get a buffer for a new page. Retrying.  If the failure repeats, an out of disk error will be signalled.  The cause of this is having too many buffers wired down for preread, flush or group by/hash join temp space.  To correct, increase the number of buffers in the configuration file.  If this repeats in spite of having hundreds of thousands  of buffers, please report to support.");
      if (n_tries > 4)
	virtuoso_sleep (0, 50000 * (n_tries - 4));
    }
  if (action_bp)
    bp_delayed_stat_action (action_bp);
  if (buf->bd_readers != 1)
    GPF_T1 ("expecting buf to be wired down when allocated");
    buf_dbg_printf (("Buf %x new in tree %x dp=%d\n", buf, isp, physical_dp));
  itm = IT_DP_MAP (it, physical_dp);
  mutex_enter (&itm->itm_mtx);

  sethash (DP_ADDR2VOID (physical_dp), &itm->itm_dp_to_buf, (void*) buf);
  sethash (DP_ADDR2VOID (physical_dp), &itm->itm_remap,
	   DP_ADDR2VOID (physical_dp));
  buf->bd_page = physical_dp;
  buf->bd_physical_page = physical_dp;
  buf->bd_tree = it;
  buf->bd_storage = it->it_storage;
  buf->bd_pl = NULL;
  buf->bd_readers = 0;
  BD_SET_IS_WRITE (buf, 1);
  mutex_leave (&itm->itm_mtx);
  if (em != em->em_dbs->dbs_extent_map && EXT_INDEX == ext_type)
    {
      mutex_enter (em->em_mtx);
      remhash (DP_ADDR2VOID(physical_dp), em->em_uninitialized);
      mutex_leave (em->em_mtx);
    }
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
      LONG_SET (buf->bd_buffer + DP_KEY_ID, it->it_key ? it->it_key->key_id : KI_TEMP);
    }
  else if (buf->bd_content_map)
    {
      resource_store (PM_RC (buf->bd_content_map->pm_size), (void*) buf->bd_content_map);
      buf->bd_content_map = NULL;
    }

  buf_set_dirty (buf);
  DBG_PT_PRINTF (("New page L=%d B=%p FL=%d K=%s \n", buf->bd_page, buf, type,
		 it->it_key ? (it->it_key->key_name ? it->it_key->key_name : "unnamed key") : "no key"));
  TC (tc_new_page);
  return buf;
}

#define IS_NEW_BUFFER(buf) \
  (buf->bd_page == buf->bd_physical_page && !DP_CHECKPOINT_REMAP (buf->bd_storage, buf->bd_page))


void
it_free_page (index_tree_t * it, buffer_desc_t * buf)
{
  short l;
  it_map_t * itm;
  dp_addr_t remap;
  ASSERT_IN_MAP (buf->bd_tree, buf->bd_page);
  itm = IT_DP_MAP (buf->bd_tree, buf->bd_page);
  remap = (dp_addr_t) (ptrlong) gethash (DP_ADDR2VOID (buf->bd_page), &itm->itm_remap);
  if (!buf->bd_is_write)
    GPF_T1 ("isp_free_page without write access to buffer.");
  dp_may_compact (buf->bd_storage, buf->bd_page); /* no need to keep deld buffers in checked for compact list */
  l=SHORT_REF (buf->bd_buffer + DP_FLAGS);
  if (!(l == DPF_BLOB || l == DPF_BLOB_DIR)
      && !remap)
    GPF_T1 ("Freeing a page that is not remapped");
  if (DPF_INDEX == l)
    it->it_n_index_est--;
  else
    it->it_n_blob_est--;
  if (buf->bd_page != buf->bd_physical_page && (DPF_BLOB_DIR == l || DPF_BLOB == l))
    GPF_T1 ("blob is not supposed to be remapped");
  DBG_PT_PRINTF (("    Delete %ld remap %ld FL=%d buf=%p\n", buf->bd_page, buf->bd_physical_page, l, buf));
  if (buf->bd_iq)
    {
      mutex_leave (&itm->itm_mtx);
      buf_cancel_write (buf);
      mutex_enter (&itm->itm_mtx);
    }

  if (!remap)
    {
      /* a blob in checkpoint space can be deleted without a remap existing in commit space. */
      if (DPF_BLOB != l && DPF_BLOB_DIR != l )
	GPF_T1 ("not supposed to delete a buffer in a different space unless it's a blob");
      if (buf->bd_is_dirty)
	GPF_T1 ("blob in checkpoint space can't be dirty - has no remap, in commit, hence is in checkpoint");
      sethash (DP_ADDR2VOID (buf->bd_page), &itm->itm_remap, (void*) (ptrlong) DP_DELETED);
      remhash (DP_ADDR2VOID (buf->bd_page), &itm->itm_dp_to_buf);
      page_leave_as_deleted (buf);
      return;
    }
  if (IS_NEW_BUFFER (buf))
    /* if this was CREATED AND DELETED without intervening checkpoint the delete
     * does not carry outside the commit space. */
    remhash (DP_ADDR2VOID (buf->bd_page), &itm->itm_remap);
  else
    sethash (DP_ADDR2VOID (buf->bd_page), &itm->itm_remap, (void *) (ptrlong) DP_DELETED);
  if (!remhash (DP_ADDR2VOID (buf->bd_page), &itm->itm_dp_to_buf))
    GPF_T1 ("it_free_page does not hit the buffer in tree cache");

  it_free_remap (it, buf->bd_page, buf->bd_physical_page, l);
  page_leave_as_deleted (buf);
}

#if defined(DEBUG) || defined(MTX_DEBUG)
void bing () {}
#endif

void
it_free_dp_no_read (index_tree_t * it, dp_addr_t dp, int dp_type)
{
  buffer_desc_t * buf;
  dp_addr_t phys_dp = 0;
  it_map_t * itm = IT_DP_MAP (it, dp);
  ASSERT_IN_MAP (it, dp);
  buf = IT_DP_TO_BUF (it, dp);
  if (buf)
    phys_dp = buf->bd_physical_page;
  else
    IT_DP_REMAP (it, dp, phys_dp);
  if (buf && buf->bd_being_read)
    {
      log_info ("Deleting blob page while it is being read dp=%d .\n", dp);
/* the buffer can be a being read decoy with no dp, so check dps only if not being read */
    }
  else if (phys_dp != dp)
    GPF_T1 ("A blob/hash temp dp is not supposed to be remapped in isp_free_blob_dp_no_read");
  if (buf)
    {
      it_cursor_t itc_auto;
      it_cursor_t * itc = &itc_auto;
      ITC_INIT (itc, isp, NULL);
      itc_from_it (itc, it);
      itc->itc_itm1 = itm; /* already inside, set itc_itm1 to mark this */
/* Note that the the buf is not passed to page_wait_access.  This is because of 'being read' possibility. page_fault will detect this and sync. */
      page_wait_access (itc, dp, NULL, &buf, PA_WRITE, RWG_WAIT_ANY);
      if (PF_OF_DELETED == buf)
	{
	  ITC_LEAVE_MAPS (itc);
	  return;
	}
      if (dp_type != SHORT_REF (buf->bd_buffer + DP_FLAGS))
	GPF_T1 ("About to delete non-blob page from blob page dir.");
      ITC_IN_KNOWN_MAP (itc, dp); /* get back in, could have come out if waited */
      it_free_page (it, buf);
      return;
    }
  DBG_PT_PRINTF (("Free absent blob  L=%d \n", dp));
  {
    dp_addr_t remap = (dp_addr_t) (ptrlong) gethash (DP_ADDR2VOID (dp), &itm->itm_remap);
    dp_addr_t cpt_remap = (dp_addr_t) (ptrlong) DP_CHECKPOINT_REMAP (it->it_storage, dp);
    if (cpt_remap)
      GPF_T1 ("Blob/hash temp dp  not expected to have cpt remap in delete no read");
    if (DPF_BLOB == dp_type)
      it->it_n_blob_est--;
    if (remap)
      {
	/* if this was CREATED AND DELETED without intervening checkpoint the delete
	 * does not carry outside commit space. */
	remhash (DP_ADDR2VOID (dp), &itm->itm_remap);
	em_free_dp (it->it_extent_map, dp, DPF_BLOB == dp_type ? EXT_BLOB : EXT_INDEX);
      }
    else
      {
	if (DPF_HASH == dp_type) GPF_T1 ("a hash temp page is not supposed to be in cpt s[space");
	sethash (DP_ADDR2VOID (dp), &itm->itm_remap, (void *) (ptrlong) DP_DELETED);
      }
  }
}

/* this is needed in order to initialize the hosting pl code
*/
dbe_schema_t *
isp_schema_1 (void * thr)
{
  return (wi_inst.wi_schema);
}
