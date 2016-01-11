/*
 *  extent.c
 *
 *  $Id$
 *
 *  Disk extent management
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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
#include "sqlbif.h"
#include "srvstat.h"
#include "recovery.h"


#if 0
#define em_printf(a) printf a
#else
#define em_printf(a)
#endif


int ext_free_count (extent_t * ext);
extent_t * em_new_extent (extent_map_t * em, int type, dp_addr_t extends);
dp_addr_t em_try_get_dp (extent_map_t * em, int pg_type, dp_addr_t near);
dp_addr_t em_new_dp_1 (extent_map_t * em, int ext_type, dp_addr_t near);
extern int32 c_dense_page_allocation;

int
fd_extend (dbe_storage_t * dbs, int fd, int n_pages)
{
  OFF_T n;
  OFF_T org_len;
  static ALIGNED_PAGE_ZERO (zero);
  ASSERT_IN_DBS (dbs);
  org_len = LSEEK (fd, 0, SEEK_END);
  for (n = 0; n < n_pages; n++)
    {
      int rc = write (fd, (char *) zero, PAGE_SZ);
      if (PAGE_SZ != rc)
	{
	  FTRUNCATE (fd, org_len);
	  return 0;
	}
    }
  return n_pages;
}


int
dbs_seg_extend (dbe_storage_t * dbs, int n)
{
  /* extend each stripe of the last segment of dbs by n */
  disk_segment_t * ds;
  dk_set_t last = dbs->dbs_disks;
  int fd, inx, rc;
  OFF_T org_sz;
  while (last->next)
    last = last->next;
  ds = (disk_segment_t*)last->data;
  fd = dst_fd (ds->ds_stripes[0]);
  org_sz = LSEEK (fd, 0, SEEK_END);
  dst_fd_done (ds->ds_stripes[0], fd, NULL);
  DO_BOX (disk_stripe_t *, dst, inx, ds->ds_stripes)
    {
      fd = dst_fd (dst);
      rc = fd_extend (dbs, fd, n);
      dst_fd_done (dst, fd, NULL);
      if (rc != n)
	{
	  int inx2;
	  for (inx2 = 0; inx2 < inx; inx2++)
	    {
	      fd = dst_fd (ds->ds_stripes[inx2]);
	      ftruncate (fd, org_sz);
	      dst_fd_done (ds->ds_stripes[inx2], fd, NULL);
	    }
	  return 0;
	}
    }
  END_DO_BOX;
  ds->ds_size += n * ds->ds_n_stripes;
  dbs->dbs_n_pages+= n * ds->ds_n_stripes;
  dbs->dbs_n_free_pages+= n * ds->ds_n_stripes;
  return n;
}


buffer_desc_t *
page_set_last (buffer_desc_t * buf)
{
  while (buf && buf->bd_next)
    {
      if (!buf->bd_physical_page) GPF_T1 ("fucking page set got 0 dp");
    buf = buf->bd_next;
    }
  return buf;
}


buffer_desc_t *
page_set_extend (dbe_storage_t * dbs, buffer_desc_t ** set, dp_addr_t dp, int flag)
{
  buffer_desc_t * buf, * last = page_set_last (*set);
  buf = buffer_allocate (flag);
  memset (buf->bd_buffer + DP_DATA, 0, PAGE_DATA_SZ);
  buf->bd_page = buf->bd_physical_page = dp;
  buf->bd_storage = dbs;
  if (!last)
    *set = buf;
  else
    last->bd_next = buf;
  if (set == &dbs->dbs_free_set && DPF_FREE_SET == flag)
    dbs_set_free_set_arr (dbs);
  return buf;
}


void
dbs_locate_ext_bit (dbe_storage_t* dbs, dp_addr_t near_dp,
    uint32 **array, dp_addr_t *page_no, int *inx, int *bit)
{
  dp_addr_t near_page;
  dp_addr_t n;
  buffer_desc_t* free_set = dbs->dbs_extent_set;
  if (near_dp % EXTENT_SZ)
    GPF_T1 ("when locating extent bit, must have a dp that is at extent boundary");
  near_dp /= EXTENT_SZ;
  near_page = near_dp / BITS_ON_PAGE;

  *page_no = near_page;
  for (n = 0; n < near_page; n++)
    {
      if (!free_set->bd_next)
	GPF_T1 ("extent set too short");
      if (!free_set->bd_physical_page)
	GPF_T1 ("ext set got 0 dp");
      free_set = free_set->bd_next;
    }
  page_set_check (free_set->bd_buffer + DP_DATA);
  *array = (dp_addr_t *) (free_set->bd_buffer + DP_DATA);
  *inx = (int) ((near_dp % BITS_ON_PAGE) / BITS_IN_LONG);
  *bit = (int) ((near_dp % BITS_ON_PAGE) % BITS_IN_LONG);
}


void
dbs_extent_allocated (dbe_storage_t * dbs, dp_addr_t n)
{
  uint32 *array;
  dp_addr_t page;
  int inx, bit;
  dbs_locate_ext_bit (dbs, n, &array, &page, &inx, &bit);
  if (0 == (array[inx] & 1L << bit))
    {
      page_set_update_checksum (array, inx, bit);
      array[inx] |= 1 << bit;
    }
}

dp_addr_t
em_free_count (extent_map_t * em, int type)
{
  dp_addr_t n = 0;
  DO_EXT (ext, em)
    {
      if (type != EXT_TYPE (ext))
	continue;
      n += ext_free_count (ext);
    }
  END_DO_EXT;
  return n;
}


extern long dbf_no_disk;


void
dbs_ec_enter (dbe_storage_t * dbs)
{
  int inx;
  for (inx = 0; inx <  DBS_EC_N_SETS; inx++)
    mutex_enter (dbs->dbs_ext_cache_mtx[inx]);
}


void
dbs_ec_leave (dbe_storage_t * dbs)
{
  int inx;
  for (inx = 0; inx <  DBS_EC_N_SETS; inx++)
    mutex_leave (dbs->dbs_ext_cache_mtx[inx]);
}


void
dbs_extend_ext_cache (dbe_storage_t * dbs)
{
  if (dbs->dbs_ext_ref_ct && box_length (dbs->dbs_ext_ref_ct) < dbs->dbs_n_pages / EXTENT_SZ)
    {
      dbs_ec_enter (dbs);
      {
	int64 len = box_length (dbs->dbs_ext_ref_ct);
	int64 reserve = len + 10000;
	ext_ts_t * new_ts = (ext_ts_t*)dk_alloc_box_long (reserve * sizeof (ext_ts_t), DV_BIN);
	db_buf_t new_ct = (db_buf_t)dk_alloc_box_long (reserve, DV_BIN);
	memset (new_ct + len, 0, reserve - len);
	memset (&new_ts[len], 0, sizeof (ext_ts_t) * (reserve - len));
	memcpy (new_ct, dbs->dbs_ext_ref_ct, len);
	memcpy (new_ts, dbs->dbs_ext_ts, len * sizeof (ext_ts_t));
	  dk_free_box ((caddr_t)dbs->dbs_ext_ts);
	  dk_free_box ((caddr_t)dbs->dbs_ext_ref_ct);
	  dbs->dbs_ext_ts = new_ts;
	  dbs->dbs_ext_ref_ct = new_ct;
      }
      dbs_ec_leave (dbs);
    }
}

int32 dbs_check_extent_free_pages = 1;


int
dbs_file_extend (dbe_storage_t * dbs, extent_t ** new_ext_ret, int is_in_sys_em)
{
  extent_map_t * em;
  	  extent_t * new_ext = NULL;
  int n, n_allocated = 0;
  dp_addr_t ext_first = dbs->dbs_n_pages;
  ASSERT_IN_DBS (dbs);
  if (dbf_no_disk)
    return 0;
  if (dbs->dbs_disks)
    {
      int quota = DBS_ELASTIC == dbs->dbs_type ? 8 * EXTENT_SZ :  EXTENT_SZ;
      n = dbs_seg_extend (dbs, quota);
      if (n != quota)
	return 0;
    }
  else
    {
      mutex_enter (dbs->dbs_file_mtx);
      n = fd_extend (dbs, dbs->dbs_fd, EXTENT_SZ);
      mutex_leave (dbs->dbs_file_mtx);
      if (EXTENT_SZ != n)
	return 0;
      dbs->dbs_file_length += PAGE_SZ * EXTENT_SZ;
      dbs->dbs_n_pages+= EXTENT_SZ;
      dbs->dbs_n_free_pages+= EXTENT_SZ;
    }
  wi_storage_offsets ();
  dbs_extend_ext_cache (dbs);
  em = dbs->dbs_extent_map;
  if (!em)
    {
      return n;
    }
  if (!is_in_sys_em)
    mutex_enter (em->em_mtx);
  if (dbs_check_extent_free_pages)
    {
      dp_addr_t em_n_free = em_free_count (em, EXT_INDEX);
      if (em->em_n_free_pages != em_n_free)
	{
	  log_error ("The %s free pages incorrect %d != %d actually free", em->em_name, em->em_n_free_pages, em_n_free);
	  em->em_n_free_pages = em_n_free;
	}
    }

  if (em->em_n_free_pages < 16)
    {
      /* extending and the system extent has little space.  Make this ext a system index ext.  If allocating some other ext, retry and take the next ext for that.  */
      int fill;
      buffer_desc_t * last;
      last = page_set_last (em->em_buf);
      fill = LONG_REF (last->bd_buffer + DP_BLOB_LEN);
      if (fill + sizeof (extent_t) > PAGE_DATA_SZ)
	{
	  dp_addr_t em_dp = ext_first + n_allocated;
	  n_allocated++;
	  last = page_set_extend (dbs, &em->em_buf, em_dp, DPF_EXTENT_MAP);
	  LONG_SET (last->bd_buffer + DP_BLOB_LEN, sizeof (extent_t));
	  new_ext = (extent_t *) (last->bd_buffer + DP_DATA);
	}
      else
	{
	  new_ext = (extent_t*) (last->bd_buffer + fill + DP_DATA);
	  LONG_SET (last->bd_buffer + DP_BLOB_LEN, fill + sizeof (extent_t));
	}
      em->em_n_pages += EXTENT_SZ;
      em->em_n_free_pages += EXTENT_SZ;
      new_ext->ext_flags = EXT_INDEX;
      new_ext->ext_dp = ext_first;
      if (gethash (DP_ADDR2VOID (new_ext->ext_dp), dbs->dbs_dp_to_extent_map))
	GPF_T1 ("ext for new dp range already exists in dbs");
      sethash (DP_ADDR2VOID (new_ext->ext_dp), em->em_dp_to_ext, (void*)new_ext);
      sethash (DP_ADDR2VOID (new_ext->ext_dp), dbs->dbs_dp_to_extent_map, (void*)em);
      new_ext->ext_prev = EXT_EXTENDS_NONE;
      if (n_allocated)
	{
	  new_ext->ext_pages[0] = 1;
	  em->em_n_free_pages--;
	}
    }
  /* there is a guarantee of at least 16 pages in the dbs sys extent map */
  if (dbs->dbs_n_pages > dbs->dbs_n_pages_in_sets)
    {
      /* add a page of global free set and backup set */
      buffer_desc_t * last = page_set_extend (dbs, &dbs->dbs_free_set, 0, DPF_FREE_SET);
      page_set_checksum_init (last->bd_buffer + DP_DATA);
      if (n_allocated)
	dbs_page_allocated (dbs, ext_first);
      last->bd_page = last->bd_physical_page = em_try_get_dp (em, EXT_INDEX, DP_ANY);
      if (!last->bd_page) GPF_T1 ("0 dp for page set page");
      em->em_n_free_pages--;
      last = page_set_extend (dbs, &dbs->dbs_incbackup_set, 0, DPF_INCBACKUP_SET);
      page_set_checksum_init (last->bd_buffer + DP_DATA);
      last->bd_page = last->bd_physical_page = em_try_get_dp (em, EXT_INDEX, DP_ANY);
      if (!last->bd_page) GPF_T1 ("0 dp for page set page");
      em->em_n_free_pages--;
      dbs->dbs_n_pages_in_sets += BITS_ON_PAGE;
    }
  if (dbs->dbs_n_pages > dbs->dbs_n_pages_in_extent_set)
    {
      buffer_desc_t * last = page_set_extend (dbs, &dbs->dbs_extent_set, 0, DPF_EXTENT_SET);
      last->bd_page = last->bd_physical_page = em_try_get_dp (em, EXT_INDEX, DP_ANY);
      if (!last->bd_page) GPF_T1 ("0 dp for extents alloc page");
      em->em_n_free_pages--;
      LONG_SET (last->bd_buffer + DP_DATA, 1); /* the newly made ext is the 1st of this page of the ext set, so set the bm 1st bit to 1 */
      page_set_checksum_init (last->bd_buffer + DP_DATA);
      dbs->dbs_n_pages_in_extent_set += EXTENT_SZ * BITS_ON_PAGE;
    }
  if (new_ext)
    {
      dbs_extent_allocated (dbs, ext_first);
    }
  *new_ext_ret = new_ext;
  if (!is_in_sys_em)
    mutex_leave (em->em_mtx);
  return n;
}


dp_addr_t
em_get_extent (extent_map_t * em, int type, dp_addr_t near_dp, extent_t ** new_ext_ret)
{
  extent_t * new_ext = NULL;
  dbe_storage_t * dbs = em->em_dbs;
  dp_addr_t dp;
  /* Look both sides of near. If there's nothing, start at the beginning. */
  buffer_desc_t *free_buf;
  uint32 *page;
  dp_addr_t page_no;
  int word;
  int bit;
  *new_ext_ret = NULL;
  IN_DBS (dbs);
  bit = -1;
  if (near_dp > dbs->dbs_n_pages_in_extent_set - EXTENT_SZ && near_dp > EXTENT_SZ)
    near_dp -= EXTENT_SZ;
  dbs_locate_ext_bit (dbs, near_dp, &page, &page_no, &word, &bit);
  if (page[word] != 0xffffffff)
    {
      bit = word_free_bit (page[word]);
    }
  else
    {
      page_no = 0;
      free_buf = dbs->dbs_extent_set;
      while (free_buf)
	{
	  page = (uint32 *) (free_buf->bd_buffer + DP_DATA);
	  page_set_check ((db_buf_t) page);
	  for (word = 0; word < LONGS_ON_PAGE; word++)
	    {
	      if (page[word] != 0xffffffff)
		{
		  bit = word_free_bit (page[word]);
		  goto bit_found;
		}
	    }
	  free_buf = free_buf->bd_next;
	  page_no++;
	}
      if (!dbs_file_extend (dbs, &new_ext, 1))
	{
	  LEAVE_DBS (dbs);
	  return DP_OUT_OF_DISK;
	}
      LEAVE_DBS (dbs);
      if (EXT_INDEX == type && em == dbs->dbs_extent_map && new_ext)
	{
	  *new_ext_ret = new_ext;
	  return (*new_ext_ret)->ext_dp;
	}
      return em_get_extent (em, type, 0, new_ext_ret);
    }
bit_found:
  dp = EXTENT_SZ * ((bit + (word * BITS_IN_LONG) + (page_no * BITS_ON_PAGE)));
  if (dp >= dbs->dbs_n_pages)
    {
      if (!dbs_file_extend (dbs, &new_ext, 1))
	{
	  LEAVE_DBS (dbs);
	  return DP_OUT_OF_DISK;
	}
      if (EXT_INDEX == type && em == dbs->dbs_extent_map && new_ext)
	{
	  LEAVE_DBS (dbs);
	  *new_ext_ret = new_ext;
	  return new_ext->ext_dp;
	}
      if (new_ext)
	{
	  LEAVE_DBS (dbs);
	  return em_get_extent (em, type, 0, new_ext_ret);
	}
    }
  page_set_update_checksum (page, word, bit);
  page[word] |= ((uint32) 1) << bit;
  LEAVE_DBS (dbs);
  return dp;
}


void
dbs_extent_free (dbe_storage_t * dbs, dp_addr_t ext_dp, int must_be_in_em)
{
  extent_map_t * em;
  extent_t * ext;
  int word, bit;
  uint32 * arr, page_no;
  ASSERT_IN_DBS (dbs);
  dbs_locate_ext_bit (dbs, ext_dp, &arr, &page_no, &word, &bit);
  if (0 == (arr[word] & 1 << bit))
    GPF_T1 ("double free in ext set");
  page_set_update_checksum (arr, word, bit);
  arr[word] &= ~(1 << bit);
  em = DBS_DP_TO_EM (dbs, ext_dp);
  if (em)
    {
      ASSERT_IN_MTX (em->em_mtx);
      ext = EM_DP_TO_EXT (em, ext_dp);
      if (ext)
	{
	  remhash (DP_ADDR2VOID (ext_dp), em->em_dp_to_ext);
	  switch (EXT_TYPE (ext))
	    {
	    case EXT_INDEX:
	      em->em_n_pages -= EXTENT_SZ;
	      em->em_n_free_pages -= EXTENT_SZ;
	      break;
	    case EXT_REMAP:
	      em->em_n_remap_pages -= EXTENT_SZ;
	      em->em_n_free_remap_pages -= EXTENT_SZ;
	      break;
	    case EXT_BLOB:
	      em->em_n_blob_pages -= EXTENT_SZ;
	      em->em_n_free_blob_pages -= EXTENT_SZ;
	      break;
	    }
	  ext->ext_flags = EXT_FREE;
	}
      if (ext == em->em_last_remap_ext)
	em->em_last_remap_ext = NULL;
      if (ext == em->em_last_blob_ext)
	em->em_last_blob_ext = NULL;
      remhash (DP_ADDR2VOID (ext_dp), dbs->dbs_dp_to_extent_map);
    }
  else if (must_be_in_em)
    GPF_T1 ("cannot free ext that is not part of any em");
}

#undef near

dp_addr_t
ext_get_dp (extent_t * ext, dp_addr_t near)
{
  int word, bit;
  if (EXT_FULL & ext->ext_flags)
    return 0;
  if (near)
    {
      if (!DP_IN_EXTENT (near, ext))
	GPF_T1 ("near outside of extent");
	word = (near - ext->ext_dp) / BITS_IN_LONG;
	if (ext->ext_pages[word] != 0xffffffff)
	  {
	    bit = word_free_bit (ext->ext_pages[word]);
	    goto bit_found;
	  }
    }
  for (word = 0; word < EXTENT_SZ / BITS_IN_LONG; word++)
    {
      if (ext->ext_pages[word] != 0xffffffff)
	{
	  bit = word_free_bit (ext->ext_pages[word]);
	  goto bit_found;
	}
    }
  ext->ext_flags |= EXT_FULL;
  return 0;
 bit_found:
  ext->ext_pages[word] |= 1 << bit;
  return ext->ext_dp + (word * BITS_IN_LONG) + bit;
}


extent_t *
em_alloc_ext (extent_map_t * em, int type)
{
  DO_EXT (ext, em)
    {
      if (EXT_FREE == EXT_TYPE (ext))
	{
	  memset (ext, 0, sizeof (extent_t));
	  ext->ext_flags = type;
	  return ext;
	}
    }
  END_DO_EXT;
  return NULL;
}


extent_t *
em_first_ext (extent_map_t * em, int type)
{
  extent_t * new_ext;
  DO_EXT (ext, em)
    {
      if (type == EXT_TYPE (ext))
	return ext;
    }
  END_DO_EXT;
  new_ext = em_new_extent (em, type, EXT_EXTENDS_NONE);
  return new_ext;
}


caddr_t
em_page_list (extent_map_t * em, int type)
{
  dk_set_t l = NULL;
  int n = 0;
  DO_EXT (ext, em)
    {
      if (type == EXT_TYPE (ext))
	{
	  dp_addr_t dp;
	  for (dp = ext->ext_dp; dp < ext->ext_dp + EXTENT_SZ; dp++)
	    {
	      int32 word = ext->ext_pages[(dp - ext->ext_dp) / 32];
	      int bit = (dp - ext->ext_dp) % 32;
	      if ((word & (1 << bit)))
		{
		  if (n > 1000000)
		    break;
		  dk_set_push (&l, (void*) box_num (dp));
		  n++;
		}
	    }
	}
    }
  END_DO_EXT;
  return list_to_array (dk_set_nreverse (l));
}


dp_addr_t
em_try_get_dp (extent_map_t * em, int pg_type, dp_addr_t near)
{
  if (DP_ANY == near)
    {
      int inx;
      buffer_desc_t * buf = em->em_buf;
      if (EXT_BLOB == pg_type && !em->em_n_free_blob_pages)
	return 0;
      while (buf)
	{
	  for (inx = 0; inx < LONG_REF (buf->bd_buffer + DP_BLOB_LEN); inx+=  sizeof (extent_t))
	    {
	      extent_t * ext = (extent_t *) (buf->bd_buffer + DP_DATA + inx);
	      dp_addr_t dp;
	      if (pg_type != EXT_TYPE (ext))
		continue;
	      dp = ext_get_dp (ext, 0);
	      if (dp)
		return dp;
	    }
	  buf = buf->bd_next;
	}
      return 0;
    }
  else
    {
      extent_t * ext = EM_DP_TO_EXT (em, near);
      if (!ext)
	{
	  if (em == em->em_dbs->dbs_extent_map)
	    GPF_T1 ("asking for a from sys ext map near that is not in any ext of the em");
	  /* a key has an own em but some pages are in the sys em.  One such splits.  Consider the first used index  ext of the em to be the extender for these */
	  ext = em_first_ext (em, pg_type);
	  if (!ext)
	    return 0;
	  return ext_get_dp (ext, 0);
	}
      return ext_get_dp (ext, near);
    }
}


extent_t *
em_append_em_page (extent_map_t * em, dp_addr_t em_dp, dp_addr_t ext_dp)
{
  /* add a new em page at em_dp to the em.  The ext of the first ext of the new em page starts at ext_dp */
  extent_t * ext;
  buffer_desc_t * last = page_set_extend (em->em_dbs, &em->em_buf, 0, DPF_EXTENT_MAP);
  last->bd_page = last->bd_physical_page = em_dp;
  ext = (extent_t *) (last->bd_buffer + DP_DATA);
  /* this is a new buffer, set to 0 by page_set_extend, guaranteed to be 0 */
  LONG_SET (last->bd_buffer + DP_BLOB_LEN, sizeof (extent_t));
  ext->ext_dp = ext_dp;
  return ext;
}


extent_t *
em_sys_extend (extent_map_t * em)
{
  /* add an empty extent record into the system extent map   and returns that.  null if out of disk.   */
  extent_t * new_ext = NULL;
  dbe_storage_t * dbs = em->em_dbs;
  int fill;
  buffer_desc_t * last = page_set_last (em->em_buf);
  ASSERT_IN_MTX (em->em_mtx);
  fill = LONG_REF (last->bd_buffer + DP_BLOB_LEN);
  if (fill + sizeof (extent_t) >= PAGE_DATA_SZ)
    {
      dp_addr_t ext_dp = em_get_extent (dbs->dbs_extent_map, EXT_INDEX, 0, &new_ext);
      if (DP_OUT_OF_DISK == ext_dp)
	{
	  return NULL;
	}
      if (new_ext)
	return new_ext;
      new_ext = em_append_em_page (dbs->dbs_extent_map, ext_dp, ext_dp);
      new_ext->ext_pages[0] = 1;
      IN_DBS (dbs);
      dbs_page_allocated (dbs, ext_dp);
      LEAVE_DBS (dbs);
      return new_ext;
    }
  new_ext = (extent_t *) (last->bd_buffer + DP_DATA + fill);
  LONG_SET (last->bd_buffer + DP_BLOB_LEN, fill + sizeof (extent_t));
  memset (new_ext, 0, sizeof (extent_t));
  return new_ext;
}


extent_t *
em_extend (extent_map_t * em, int type)
{
  /* add an empty extent record into an em and returns that.  null if out of disk */
  extent_t * ext;
  int fill;
  buffer_desc_t * last;
  dbe_storage_t * dbs = em->em_dbs;
  ext = em_alloc_ext (em, type);
  if (ext)
    return ext;
  last  = page_set_last (em->em_buf);
  fill = LONG_REF (last->bd_buffer + DP_BLOB_LEN);
  if (em == em->em_dbs->dbs_extent_map && EXT_INDEX == type)
    return em_sys_extend (em);
  if (fill + sizeof (extent_t) >= PAGE_DATA_SZ)
    {
      dp_addr_t dp;
      ASSERT_IN_MTX (em->em_dbs->dbs_extent_map->em_mtx);
      dp = em_new_dp_1 (em->em_dbs->dbs_extent_map, EXT_INDEX, DP_ANY);
      if (!dp)
	return NULL;
      IN_DBS (dbs);
      dbs_page_allocated (dbs, dp);
      LEAVE_DBS (dbs);
      last = page_set_extend (em->em_dbs, &em->em_buf, dp, DPF_EXTENT_MAP);
      fill = 0;
    }
  ext = (extent_t *) (last->bd_buffer + DP_DATA + fill);
  LONG_SET (last->bd_buffer + DP_BLOB_LEN, fill + sizeof (extent_t));
  memset (ext, 0, sizeof (extent_t));
  return ext;
}


void
em_ins_after (extent_map_t * em, extent_t * point, extent_t * inserted)
{
  extent_t * old_next = NULL;
  inserted->ext_next = point->ext_next;
  if (point->ext_next)
    {
      old_next = EM_DP_TO_EXT (em, point->ext_next);
      if (old_next)
	old_next->ext_prev = inserted->ext_dp;
    }
  point->ext_next = inserted->ext_dp;
  inserted->ext_prev = point->ext_dp;
  em_printf (("  Ext %d got new next %d, prev next was %d with %d occupied em=%s\n", point->ext_dp / EXTENT_SZ, inserted->ext_dp / EXTENT_SZ, old_next ? old_next->ext_dp / EXTENT_SZ : 0,
	      old_next ? EXTENT_SZ - ext_free_count (old_next) : 0, em->em_name));
}

void
em_ext_unlink (extent_map_t * em, extent_t * ext)
{
  if (ext->ext_prev && ext->ext_prev != DP_ANY)
    {
      extent_t * t = EM_DP_TO_EXT (em, ext->ext_prev);
      if (t)
	t->ext_next = ext->ext_next;
    }
  if (ext->ext_next)
    {
      extent_t * t = EM_DP_TO_EXT (em, ext->ext_next);
      if (t)
	t->ext_prev = ext->ext_prev;
    }
  em_printf (("unlink ext %d between %d and %d \n", ext->ext_dp / EXTENT_SZ, ext->ext_prev / EXTENT_SZ, ext->ext_next / EXTENT_SZ));
  ext->ext_next = 0;
  ext->ext_prev = 0;
}


dp_addr_t
em_find_free_extender (extent_map_t * em, extent_t * near_ext)
{
  dp_addr_t dp = 0;
  DO_EXT (ext, em)
    {
      if (near_ext == ext)
	continue;
      if (EXT_INDEX == EXT_TYPE (ext) && EXT_EXTENDS_NONE == ext->ext_prev
	  && 0 == (ext->ext_flags & EXT_FULL))
	{
	  dp = ext_get_dp (ext, 0);
	  em_ins_after (em, near_ext, ext);
	  return dp;
	}
    }
  END_DO_EXT;
  return 0;
}


int
ext_free_count (extent_t * ext)
{
  int inx, b_idx, free = 0;
  for (inx = 0; inx < EXTENT_SZ / BITS_IN_LONG; inx++)
    {
      for (b_idx = 0; b_idx < BITS_IN_LONG; b_idx++)
	{
	  if (0 == (ext->ext_pages[inx] & (1 << b_idx)))
	    free++;
	}
    }
  return free;
}


extent_t *
em_new_extent (extent_map_t * em, int type, dp_addr_t extends)
{
  extent_t * new_ext;
  int is_sys_em = em == em->em_dbs->dbs_extent_map;
  extent_map_t * sys_em = em->em_dbs->dbs_extent_map;
  dp_addr_t dp;
  if (is_sys_em)
    {
      ASSERT_IN_MTX (em->em_mtx);
    }
  else
    mutex_enter (sys_em->em_mtx);

  dp = em_get_extent (em, type, EXT_EXTENDS_NONE == extends ? 0 : extends, &new_ext);
  if (DP_OUT_OF_DISK == dp)
    {
      if (!is_sys_em)
	mutex_leave (sys_em->em_mtx);
      return 0;
    }
  if (EXT_INDEX == type && em == em->em_dbs->dbs_extent_map && new_ext)
    {
      /* in sys em, so no extra leave here */
      return new_ext;
    }
  new_ext = em_extend (em, type);
  if (!new_ext)
    {
      dbs_extent_free (em->em_dbs, dp, 0);
      if (!is_sys_em)
	mutex_leave (sys_em->em_mtx);
      return 0;
    }
  new_ext->ext_dp = dp;
  sethash (DP_ADDR2VOID (dp), em->em_dp_to_ext, (void*) new_ext);
  IN_DBS (em->em_dbs);
  if (gethash (DP_ADDR2VOID (dp), em->em_dbs->dbs_dp_to_extent_map))
    GPF_T1 ("an extent was made for a range already taken by other ext");
  sethash (DP_ADDR2VOID (dp), em->em_dbs->dbs_dp_to_extent_map, (void*) em);
  LEAVE_DBS (em->em_dbs);
  new_ext->ext_flags = type;

  if (EXT_INDEX == type)
    {
      if (EXT_EXTENDS_NONE == extends)
	new_ext->ext_prev = 0;
      else
	em_ins_after (em, EM_DP_TO_EXT (em, extends), new_ext);
    }
  if (EXT_REMAP == type)
    {
      em->em_n_remap_pages += EXTENT_SZ;
      em->em_n_free_remap_pages += ext_free_count (new_ext);
    }
  else if (EXT_BLOB == type)
    {
      em->em_n_blob_pages += EXTENT_SZ;
      em->em_n_free_blob_pages += ext_free_count (new_ext);
    }
  else
    {
      em->em_n_pages += EXTENT_SZ;
      em->em_n_free_pages += ext_free_count (new_ext);
    }
  if (!is_sys_em)
    mutex_leave (sys_em->em_mtx);
  return new_ext;
}

#define EM_DEC_FREE(em, t) \
{ \
  if (EXT_INDEX == t) em->em_n_free_pages--; \
  else if (EXT_BLOB == t) em->em_n_free_blob_pages--; \
  else em->em_n_free_remap_pages--;		      \
}


dp_addr_t
em_new_dp_1 (extent_map_t * em, int ext_type, dp_addr_t near)
{
  extent_t * new_ext, * near_ext;
  dp_addr_t dp;
  if (!near || EXT_BLOB == ext_type)
    near = DP_ANY;
  dp = em_try_get_dp (em, ext_type, near);
  if (dp)
    {
      EM_DEC_FREE (em, ext_type);
      return dp;
    }
  near_ext = EM_DP_TO_EXT (em, near);
  if (DP_ANY != near && !near_ext)
    {
      if (em == em->em_dbs->dbs_extent_map)
	GPF_T1 ("near dp has no extent");
      near_ext = em_first_ext (em, ext_type);
      if (!near_ext)
	return 0;
    }
  if (EXT_INDEX == ext_type && near_ext && near_ext->ext_next)
    {
      extent_t * next_ext = EM_DP_TO_EXT (em, near_ext->ext_next);
      if (next_ext && EXT_INDEX != EXT_TYPE (next_ext))
	{
	  log_error ("ext %d should have a next that is an index ext but %d is %d.  Dropping the next link", near_ext->ext_dp, next_ext->ext_dp, EXT_TYPE (next_ext));
	  near_ext->ext_next = 0;
	  next_ext = NULL;
	}
      if (next_ext)
	{
	  dp = ext_get_dp (next_ext, 0);
	  if (dp)
	    {
	      EM_DEC_FREE (em, EXT_INDEX);
	      return dp;
	    }
	}
    }
  /* no pages in the desired ext or its extender.  Make a new extender for the desired ext */
  if (near_ext)
    {
      dp = em_find_free_extender (em, near_ext);
      if (dp)
	{
	  EM_DEC_FREE (em, ext_type);
	  return dp;
	}
    }
  new_ext = em_new_extent (em, ext_type, near_ext ? near_ext->ext_dp : EXT_EXTENDS_NONE);
  if (!new_ext)
    {
      return 0;
    }
  if (EXT_EXTENDS_NONE == new_ext->ext_prev && near_ext)
    {
      /* this is an exception valid for index exts of the sys ext map.  These are made differently.  Need linking here */
      new_ext->ext_prev = 0;
      em_ins_after (em, near_ext, new_ext);
    }
  dp = ext_get_dp (new_ext, 0);
  if (!dp)
    GPF_T1 ("no dp even though brand new ext");
  EM_DEC_FREE (em, ext_type);
  return dp;
}


dp_addr_t
em_new_remap (extent_map_t * em, dp_addr_t near)
{
  dp_addr_t dp;
  extent_t * new_ext;
  if (em->em_last_remap_ext)
    {
      dp = ext_get_dp (em->em_last_remap_ext, 0);
      if (dp)
	{
	  EM_DEC_FREE (em, EXT_REMAP);
	  return dp;
	}
    }
  dp = em_try_get_dp (em, EXT_REMAP, DP_ANY);
  if (dp)
    {
      em->em_last_remap_ext = EM_DP_TO_EXT (em, EXT_ROUND (dp));
      EM_DEC_FREE (em, EXT_REMAP);
      return dp;
    }
  new_ext = em->em_last_remap_ext = em_new_extent (em, EXT_REMAP, 0);
  if (!new_ext)
    {
      return 0;
    }
  dp = ext_get_dp (em->em_last_remap_ext, 0);
  if (!dp)
    GPF_T1 ("no dp but new remap ext");
  EM_DEC_FREE (em, EXT_REMAP);
  return dp;
}


dp_addr_t
em_new_blob (extent_map_t * em, dp_addr_t near)
{
  dp_addr_t dp;
  extent_t * new_ext;
  if (em->em_last_blob_ext)
    {
      dp = ext_get_dp (em->em_last_blob_ext, 0);
      if (dp)
	{
	  EM_DEC_FREE (em, EXT_BLOB);
	  return dp;
	}
    }
  dp = em_try_get_dp (em, EXT_BLOB, DP_ANY);
  if (dp)
    {
      em->em_last_blob_ext = EM_DP_TO_EXT (em, EXT_ROUND (dp));
      EM_DEC_FREE (em, EXT_BLOB);
      return dp;
    }
  new_ext = em->em_last_blob_ext = em_new_extent (em, EXT_BLOB, 0);
  if (!new_ext)
    {
      return 0;
    }
  dp = ext_get_dp (em->em_last_blob_ext, 0);
  if (!dp)
    GPF_T1 ("no dp but new remap ext");
  EM_DEC_FREE (em, EXT_BLOB);
  return dp;
}


int
em_hold_remap (extent_map_t * em, int * hold)
{
  mutex_enter (em->em_mtx);
  while (em->em_n_free_remap_pages - em->em_remap_on_hold < *hold)
    {
      extent_t * new_ext = em_new_extent (em, EXT_REMAP, 0);
      if (!new_ext)
	{
	  mutex_leave (em->em_mtx);
	  *hold = 0;
	  return 0;
	}
    }
  em->em_remap_on_hold += *hold;
  mutex_leave (em->em_mtx);
  return 1;
}

void
em_free_remap_hold (extent_map_t * em, int * hold)
{
  mutex_enter (em->em_mtx);
  if (*hold > em->em_remap_on_hold)
    {
      log_info ("Not supposed to free more hold than taken on %s h=%d free=%d", em->em_name, em->em_remap_on_hold, *hold);
      em->em_remap_on_hold = 0;
    }
  else
    em->em_remap_on_hold -= *hold;
  *hold = 0;
  mutex_leave (em->em_mtx);
}

dp_addr_t
em_new_dp (extent_map_t * em, int type, dp_addr_t near, int * hold)
{
  dp_addr_t dp;
  mutex_enter (em->em_mtx);
  if (EXT_REMAP == type)
    {
      if (!hold || !*hold)
	{
	  while  (em->em_n_free_remap_pages <= em->em_remap_on_hold)
	    {
	      if (!em_new_extent (em, EXT_REMAP, 0))
		{
		  mutex_leave (em->em_mtx);
		  return 0;
		}
	    }
	  dp = em_new_remap (em, near);
	}
      else
	{
	  dp = em_new_remap (em, near);
	  if (!dp)
	    {
	      mutex_leave (em->em_mtx);
	      return 0;
	    }
	  if (em->em_remap_on_hold  > 0)
	    em->em_remap_on_hold--;
	  else
	    {
	      log_info ("not supposed to decrement hold below 0 on %s", em->em_remap_on_hold);
	      em->em_remap_on_hold = 0;
	    }
	  (*hold)--;
	}
    }
  else if (EXT_BLOB == type)
    dp = em_new_blob (em, near);
  else
    dp = em_new_dp_1 (em, type, c_dense_page_allocation ? DP_ANY : near);
  if (EXT_INDEX == type && em != em->em_dbs->dbs_extent_map)
    sethash (DP_ADDR2VOID(dp), em->em_uninitialized, (void*) 1);
  em_printf ((" alloc L=%d t=%d\n", dp, type));
  mutex_leave (em->em_mtx);
  IN_DBS (em->em_dbs);
  /* not inside the em mtx.  sys em must be taken from inside in_dbs, hence if inside sys em would deadlock if taking in_dbs */
  dbs_page_allocated (em->em_dbs, dp);
  LEAVE_DBS (em->em_dbs);
  return dp;
}


int
ext_is_empty (extent_t * ext)
{
  int inx;
  for (inx = 0; inx < EXTENT_SZ / BITS_IN_LONG; inx++)
    {
      if (ext->ext_pages[inx])
	return 0;
    }
  return 1;
}


#define emf_is_type(ext_type, wanted) \
  ((wanted & EMF_ANY) \
   || ((wanted & 7) == type)						\
   || ((EMF_INDEX_OR_REMAP & wanted) && (EXT_INDEX == type || EXT_REMAP == type)) \
|| ((EMF_INDEX_OR_BLOB & wanted) && (EXT_INDEX == type || EXT_BLOB == type)))


void
em_free_dp (extent_map_t * em, dp_addr_t dp, int flags)
{
  int word, bit, type;
  extent_t * ext;
  mutex_enter (em->em_mtx);
  ext = EM_DP_TO_EXT (em, EXT_ROUND (dp));
  if (!ext)
    {
      if (em == em->em_dbs->dbs_extent_map)
	GPF_T1 ("freeing dp that is not part of the em");
      mutex_leave (em->em_mtx);
      em_free_dp (em->em_dbs->dbs_extent_map, dp, flags);
      return;
    }
  em_printf (("free L=%d t=%d\n", dp, EXT_TYPE (ext)));
  EXT_BIT (ext, dp,  word, bit);
  type = EXT_TYPE (ext);
  if (!emf_is_type (type, flags))
    {
      log_error ("Expecting to free %d in ext of type %d but ext is %d.  Free not done.  Seems to be corrupt ref", dp, flags, type);
      if (!wi_inst.wi_checkpoint_atomic)
	GPF_T1 ("Because not in atomic cpt, stopping the process with a core");
      mutex_leave (em->em_mtx);
      return;
    }
  dbs_free_disk_page (em->em_dbs, dp);
  if (0 == (ext->ext_pages[word] & 1 << bit))
    GPF_T1 ("double free of dp bit in ext");
  ext->ext_pages[word] &= ~(1 << bit);
  ext->ext_flags &= ~EXT_FULL;
  if (0 == ext->ext_pages[word] && !(flags & EMF_DO_NOT_FREE_EXT))
    {
      int inx;
      for (inx = 0; inx < EXTENT_SZ / BITS_IN_LONG; inx++)
	{
	  if (ext->ext_pages[inx])
	    goto not_empty;
	}
      IN_DBS (em->em_dbs);
      dbs_extent_free (em->em_dbs, ext->ext_dp, 1);
      LEAVE_DBS (em->em_dbs);
      if (EXT_INDEX == type)
	em_ext_unlink (em, ext);
    }
 not_empty:
 if (!(flags & EMF_DO_NOT_FREE_EXT))
    {
      if (EXT_REMAP == type)
	em->em_n_free_remap_pages++;
      else if (EXT_BLOB == type)
	em->em_n_free_blob_pages++;
      else
	em->em_n_free_pages++;
    }
  mutex_leave (em->em_mtx);
}


int
buf_ext_check (buffer_desc_t * buf)
{
  /* given a buffer, check that its type and the type of page and ext agree */
  dp_addr_t dp = buf->bd_page;
  int type, flags;
  index_tree_t * it = buf->bd_tree;
  extent_map_t * em;
  extent_t * ext;
  if (!it)
    return WI_OK;
  if (DPF_COLUMN == SHORT_REF (buf->bd_buffer + DP_FLAGS))
    {
      if (!it->it_col_extent_maps)
	return WI_OK;
      em = (extent_map_t *)gethash ((void*)(ptrlong)LONG_REF (buf->bd_buffer + DP_PARENT), it->it_col_extent_maps);
    }
  else
  em = it->it_extent_map;
  if (!em)
    return WI_OK;
 again:
  mutex_enter (em->em_mtx);
  ext = EM_DP_TO_EXT (em, EXT_ROUND (dp));
  if (!ext)
    {
      if (em == em->em_dbs->dbs_extent_map)
	GPF_T1 ("freeing dp that is not part of the em");
      mutex_leave (em->em_mtx);
      em = em->em_dbs->dbs_extent_map;
      goto again;
    }
  type = EXT_TYPE (ext);
  flags = SHORT_REF (buf->bd_buffer + DP_FLAGS);
  if (DPF_INDEX == flags)
    flags = EMF_INDEX_OR_REMAP;
  else if (DPF_BLOB == flags || DPF_BLOB_DIR == flags)
    flags = EXT_BLOB;
  else
    flags = EXT_INDEX;
  mutex_leave (em->em_mtx);
  if (!emf_is_type (type, flags))
    {
      log_error ("Expecting to read %d in ext of type %d but ext is %d. Will be unfreeable.", dp, flags, type);
      return WI_ERROR;
    }
  return WI_OK;
}


void
em_check_dp (extent_map_t * em, dp_addr_t dp)
{
  int word, bit;
  extent_t * ext;
  if (!em)
    return;
  mutex_enter (em->em_mtx);
  ext = EM_DP_TO_EXT (em, EXT_ROUND (dp));
  if (!ext)
    {
      if (em == em->em_dbs->dbs_extent_map)
	GPF_T1 ("em_check_dp: Accessing dp that is not part of the em");
      mutex_leave (em->em_mtx);
      em_check_dp (em->em_dbs->dbs_extent_map,dp);
      return;
    }
  EXT_BIT (ext, dp,  word, bit);
  if (0 == (ext->ext_pages[word] & 1 << bit))
    GPF_T1 ("double free of dp bit in ext");
  mutex_leave (em->em_mtx);
}


void
em_dp_allocated (extent_map_t * em, dp_addr_t dp, int is_temp)
{
  int word, bit, type, was_allocd;
  extent_t * ext;
  IN_DBS (em->em_dbs);
  dbs_page_allocated (em->em_dbs, dp);
  LEAVE_DBS (em->em_dbs);
  mutex_enter (em->em_mtx);
  ext = EM_DP_TO_EXT (em, EXT_ROUND (dp));
  if (!ext)
    GPF_T1 ("freeing dp that is not part of the em");
  EXT_BIT (ext, dp,  word, bit);
  type = EXT_TYPE (ext);
  was_allocd = ext->ext_pages[word] & 1 << bit;
  ext->ext_pages[word] |= 1 << bit;
  if (!is_temp && !was_allocd)
    {
      if (EXT_INDEX == EXT_TYPE (ext))
	em->em_n_free_pages--;
      else if (EXT_BLOB == EXT_TYPE (ext))
	em->em_n_free_blob_pages--;
      else
	em->em_n_free_remap_pages--;
    }
  mutex_leave (em->em_mtx);
}


void
dbs_cpt_set_allocated (dbe_storage_t * dbs, dp_addr_t dp, int is_allocd)
{
  extent_map_t * em = DBS_DP_TO_EM (dbs, dp);
  int word, bit, was_allocd;
  extent_t * ext;
  if (!wi_inst.wi_checkpoint_atomic)
    GPF_T1 ("should not call dbs_cpt_set_allocated outside of checkpoint");
  if (!em)
    {
      log_error ("No ext map for dp %d in uncommitted blob cpt", dp);
      return;
    }
  IN_DBS (em->em_dbs);
  if (is_allocd)
    dbs_page_allocated (em->em_dbs, dp);
  else
    dbs_free_disk_page (em->em_dbs, dp);
  if (THREAD_CURRENT_THREAD == dbs->dbs_owner_thr)
    LEAVE_DBS (em->em_dbs);
  mutex_enter (em->em_mtx);
  ext = EM_DP_TO_EXT (em, EXT_ROUND (dp));
  if (!ext)
    {
      log_error ("no ext in the em picked for dp %d in cpt set allocd", dp);
      mutex_leave (em->em_mtx);
      return;
    }
  if (EXT_BLOB != EXT_TYPE (ext))
    {
      log_error ("uncommitted blob %d in cpt is not in a blob extent, ext_flags = %d", dp, ext->ext_flags);
      mutex_leave (em->em_mtx);
      return;
    }

  EXT_BIT (ext, dp,  word, bit);
  was_allocd = ext->ext_pages[word] & 1 << bit;
  if (is_allocd)
    ext->ext_pages[word] |= 1 << bit;
  else
    ext->ext_pages[word] &= ~(1 << bit);
  em->em_n_free_blob_pages += is_allocd ? 1 : -1;
  mutex_leave (em->em_mtx);
}


extent_map_t *
em_allocate (dbe_storage_t * dbs, dp_addr_t dp_of_map)
{
  NEW_VARZ (extent_map_t, em);
  if (dp_of_map)
    {
      page_set_extend (dbs, &em->em_buf, dp_of_map, DPF_EXTENT_MAP);
      LONG_SET (em->em_buf->bd_buffer + DP_BLOB_LEN, 0);
      em->em_map_start = dp_of_map;
    }
  em->em_dbs = dbs;
  em->em_mtx = mutex_allocate ();
  mutex_option (em->em_mtx, "extent_map", NULL, NULL);
  em->em_dp_to_ext = hash_table_allocate (51);
  dk_mutex_init (&em->em_read_history_mtx, MUTEX_TYPE_SHORT);
  em->em_read_history = hash_table_allocate (101);
  dk_hash_set_rehash (em->em_read_history, 2);
  em->em_uninitialized = hash_table_allocate (11);
#ifdef MTX_DEBUG
  em->em_uninitialized->ht_required_mtx = em->em_mtx;
#endif
  return em;
}


void
ext_free_dps (extent_map_t * em, extent_t * ext)
{
  /* mark the allocated dps of the ext as free in the global page set.  Done for recovery when freeing an non empty em.  Can happen if pages are leaked by index ops and dropping the index */
  dp_addr_t dp;
  uint32 word, bit;
  for (dp = ext->ext_dp; dp < ext->ext_dp + EXTENT_SZ; dp++)
    {
      EXT_BIT (ext, dp,  word, bit);
      if ((ext->ext_pages[word] & 1 << bit))
	{
	  ASSERT_IN_DBS (em->em_dbs);
	  dbs_free_disk_page (em->em_dbs, dp);
	  IN_DBS (em->em_dbs); /* the free func can leave dbs. */
	}
    }
}


void
em_free (extent_map_t * em)
{
  buffer_desc_t * target = em->em_buf;
  dbe_storage_t * dbs = em->em_dbs;
  mutex_enter (em->em_mtx);
  IN_DBS (dbs);
  /* remap and blob exts may be around and not get freed */
  while (em->em_dp_to_ext->ht_count)
    {
      DO_HT (void *, dp, extent_t *, ext, em->em_dp_to_ext)
	{
	  if (ext_is_empty (ext))
	    dbs_extent_free (em->em_dbs, ext->ext_dp, 1);
	  else
	    {
	      if (wi_inst.wi_checkpoint_atomic)
		{
		  ext_free_dps (em, ext);
		  dbs_extent_free (em->em_dbs, ext->ext_dp, 1);
		}
	      else
		GPF_T1 ("in freeing em, there is a non-empty ext");
	    }
	  break;
	}
      END_DO_HT;
    }
  DO_HT (void *, dp, void *, em2, dbs->dbs_dp_to_extent_map)
    {
      if (em == em2)
	GPF_T1 ("freeing an em that has pages and is refd from the dbs");
    }
  END_DO_HT;
  LEAVE_DBS (dbs);
  mutex_leave (em->em_mtx);
  while (target)
    {
      buffer_desc_t * next = target->bd_next;
      freeing_unfreeable = 1;
      if (em == em->em_dbs->dbs_extent_map)
	dbs_free_disk_page (em->em_dbs, target->bd_page);
      else
	em_free_dp (em->em_dbs->dbs_extent_map, target->bd_page, EXT_INDEX);
      freeing_unfreeable = 0;
      buffer_free (target);
      target = next;
    }
  dk_free_box (em->em_name);
  mutex_free (em->em_mtx);
  hash_table_free (em->em_dp_to_ext);
  hash_table_free (em->em_read_history);
  HT_NO_REQUIRE_MTX (em->em_uninitialized);
  hash_table_free (em->em_uninitialized);
  dk_mutex_destroy (&em->em_read_history_mtx);
  dk_free ((caddr_t) em, sizeof (extent_map_t));
}

void
em_rename (extent_map_t * em, char * name)
{
  char str[4 * MAX_NAME_LEN];
  IN_TXN;
  dbs_registry_set (em->em_dbs, em->em_name, NULL, 1);
  LEAVE_TXN;
  snprintf (str, sizeof (str), "__EM:%s", name);
  dk_free_box (em->em_name);
  em->em_name = box_dv_short_string (name);
}


void
it_rename_col_ems (index_tree_t * it, char * key_name)
{
  if (!it->it_col_extent_maps)
    return;
  DO_HT (ptrlong,  col_id, extent_map_t *, em, it->it_col_extent_maps)
    {
      char str[4 * MAX_NAME_LEN];
      snprintf (str, sizeof (str), "__EMC:%s:%s:%d", it->it_key->key_table->tb_name, key_name, (int)col_id);
      em_rename (em, str);
    }
  END_DO_HT;
}


void
em_free_mem (extent_map_t * em)
{
  /* frees the  memory associated with the em and removes it from the storage etc but does not affect its disk based state */
  buffer_desc_t * target = em->em_buf;
  mutex_enter (em->em_mtx);
  mutex_leave (em->em_mtx);
  while (target)
    {
      buffer_desc_t * next = target->bd_next;
      buffer_free (target);
      target = next;
    }
  dk_free_box (em->em_name);
  mutex_free (em->em_mtx);
  hash_table_free (em->em_dp_to_ext);
  dk_free ((caddr_t) em, sizeof (extent_map_t));
}


void
em_compact (extent_map_t * em, int free_em)
{
  buffer_desc_t * next, * prev = NULL;
  char str[20];
  int n_exts = 0;
  buffer_desc_t * target = em->em_buf;
  int target_fill = 0;
  em->em_last_remap_ext = NULL;
  em->em_last_blob_ext = NULL;
  DO_EXT (ext, em)
    {
      if (free_em)
	{
	  dp_addr_t dp;
	  for (dp = ext->ext_dp; dp < ext->ext_dp + EXTENT_SZ; dp += 32)
	    {
	      uint32* array;
	      int inx, bit;
	      dp_addr_t array_page;
	      IN_DBS (em->em_dbs);
	      dbs_locate_incbackup_bit (em->em_dbs, dp, &array, &array_page, &inx, &bit);
	      array[inx] = 0;
	      page_set_checksum_init (array);
	      if (EXT_INDEX == EXT_TYPE (ext))
		{
		  /* when dropping a column extent map in a drop index, cpt remaps are possible, so if any, drop them. The remap pagge is dropped anyway as part of the em */
		  dp_addr_t dp2;
		  for (dp2 = dp; dp2 < dp + 32; dp2++)
		    remhash (DP_ADDR2VOID (dp2), em->em_dbs->dbs_cpt_remap);
		}
	      LEAVE_DBS (em->em_dbs);
	    }
	}
      if (EXT_FREE == EXT_TYPE (ext))
	{
	  if (ext == (extent_t*)gethash (DP_ADDR2VOID (ext->ext_dp), em->em_dp_to_ext))
	    log_error ("ext %d is free but is mapped to the free extent_t record in em_dp_to_ext of em %s", ext->ext_dp, em->em_name);
	  continue;
	}
      else if (EXT_REMAP == EXT_TYPE (ext)
	       && !em->em_remap_on_hold
	       && ext_is_empty (ext))
	{
	  /* a remap ext that is empty does not stay allocd to the em, the ext alloc bit is also reset */
	  IN_DBS (em->em_dbs);
	  mutex_enter (em->em_mtx);
	  dbs_extent_free  (em->em_dbs, ext->ext_dp, 1);
	  mutex_leave (em->em_mtx);
	  LEAVE_DBS (em->em_dbs);
	  continue;
	}
      else
	{
	  if (target_fill + sizeof (extent_t) > PAGE_DATA_SZ)
	    {
	      LONG_SET (target->bd_buffer + DP_BLOB_LEN, target_fill);
	      prev = target;
	      target = target->bd_next;
	      target_fill = 0;
	    }
	  *(extent_t*) (target->bd_buffer + DP_DATA +  target_fill) = *ext;
	  sethash (DP_ADDR2VOID (ext->ext_dp), em->em_dp_to_ext,
		   (void*) (target->bd_buffer + DP_DATA + target_fill));
	  target_fill += sizeof (extent_t);
	  n_exts++;
	}
    }
  END_DO_EXT;
  LONG_SET (target->bd_buffer + DP_BLOB_LEN, target_fill);
  if (target_fill)
    {
      next = target->bd_next;
      target->bd_next = NULL;
      target = next;
    }
  else
    {
      if (prev)
	prev->bd_next = NULL;
    }
  while (target)
    {
      next = target->bd_next;
      target->bd_next = NULL; /* if single empty page kept, it must still have nextset to 0 */
      if (target != em->em_buf || free_em)
	{
	  freeing_unfreeable = 1;
	  if (em == em->em_dbs->dbs_extent_map)
	    dbs_free_disk_page (em->em_dbs, target->bd_page);
	  else
	    em_free_dp (em->em_dbs->dbs_extent_map, target->bd_page, EXT_INDEX);
	  freeing_unfreeable = 0;
	  buffer_free (target);
	}
      target = next;
    }
  if (!free_em)
    {
      sprintf (str, "%ld", (long) em->em_buf->bd_page);
      dbs_registry_set (em->em_dbs, em->em_name, str, 0);
    }
  else
    {
      em->em_buf = NULL;
      dbs_registry_set (em->em_dbs, em->em_name, NULL, 0);
    }
}


void
dbs_cpt_extents (dbe_storage_t * dbs, dk_set_t free_trees)
{
  /* compact the extent maps.  Put them in the registry.
  * Deled go first because drop-create-drop-create would otherwise leave the dropped state in effect.*/
  DO_SET (index_tree_t *, free_it, &free_trees)
    {
      if (free_it->it_extent_map != dbs->dbs_extent_map
	  && free_it->it_extent_map)
	{
	  extent_map_t * em = free_it->it_extent_map;
	  em_compact (em, 1);
	  if (em->em_buf)
	    log_error ("suspect that the ext map of %s is not empty at after drop", free_it->it_key->key_name);
	  em_free (em);
	  free_it->it_extent_map = NULL;
	}
    }
  END_DO_SET();
  DO_SET (extent_map_t *, em, &dbs->dbs_deleted_ems)
    {
      em_compact (em, 1);
      if (em->em_buf)
	log_error ("suspect that the column ext map of %s is not empty at after drop", em->em_name);
      em_free (em);
    }
  END_DO_SET();
  dk_set_free (dbs->dbs_deleted_ems);
  dbs->dbs_deleted_ems = NULL;

  DO_SET (index_tree_t *, it, &dbs->dbs_trees)
    {
      if (it->it_extent_map != dbs->dbs_extent_map
	  && it->it_extent_map)
	{
	  em_compact (it->it_extent_map, 0);
	}
      if (it->it_col_extent_maps)
	{
	  DO_HT (ptrlong, col_id, extent_map_t *, em, it->it_col_extent_maps)
	    {
	      em_compact (em, 0);
	    }
	  END_DO_HT;
	}
    }
  END_DO_SET();
  /* the sys em is compacted last because the deletes can free pages and therefore extents  from the sys em due to drop of em's */
  em_compact (dbs->dbs_extent_map, 0);
}


void
dbs_cpt_write_extents (dbe_storage_t * dbs)
{
  /* write out the extent maps. */
  DO_SET (index_tree_t *, it, &dbs->dbs_trees)
    {
      if (it->it_extent_map != dbs->dbs_extent_map
	  && it->it_extent_map)
	{
	  dbs_write_page_set (dbs, it->it_extent_map->em_buf);
	}
      if (it->it_col_extent_maps)
	{
	  DO_HT (ptrlong, col_id, extent_map_t *, em, it->it_col_extent_maps)
	    dbs_write_page_set (dbs, em->em_buf);
	  END_DO_HT;
	}
    }
  END_DO_SET();
  dbs_write_page_set (dbs, dbs->dbs_extent_map->em_buf);
}


void
em_save_dp (extent_map_t * em)
{
  char xx[15];
  sprintf (xx, "%ld", (long) em->em_buf->bd_page);
  IN_TXN;
  dbs_registry_set (em->em_dbs, em->em_name, xx, 0);
  LEAVE_TXN;
}


void
dbs_cpt_recov_write_extents (dbe_storage_t * dbs)
{
  /* write out the extent maps. */
  DO_SET (index_tree_t *, it, &dbs->dbs_trees)
    {
      if (it->it_extent_map != dbs->dbs_extent_map
	  && it->it_extent_map)
	{
	  em_save_dp (it->it_extent_map);
	  dbs_recov_write_page_set (dbs, it->it_extent_map->em_buf);
	}
      if (it->it_col_extent_maps)
	{
	  DO_HT (ptrlong, col_id, extent_map_t *, em, it->it_col_extent_maps)
	    {
	      em_save_dp (em);
	      dbs_recov_write_page_set (dbs, em->em_buf);
	    }
	  END_DO_HT;
	}
    }
  END_DO_SET();
  em_save_dp (dbs->dbs_extent_map);
  dbs_recov_write_page_set (dbs, dbs->dbs_extent_map->em_buf);
}


extent_map_t *
dbs_dp_to_em (dbe_storage_t * dbs, dp_addr_t dp)
{
  return (extent_map_t *) gethash (DP_ADDR2VOID (EXT_ROUND (dp)), dbs->dbs_dp_to_extent_map);
}

extent_map_t *
dbs_read_extent_map (dbe_storage_t * dbs, char * name, dp_addr_t dp)
{
  extent_map_t * em = em_allocate (dbs, 0);
  em->em_name = box_dv_short_string (name);
  em->em_buf = dbs_read_page_set (dbs, dp, DPF_EXTENT_MAP);
  em->em_map_start = dp;
  DO_EXT (ext, em)
    {
      if (EXT_FREE == EXT_TYPE (ext))
	continue;
      sethash (DP_ADDR2VOID (ext->ext_dp), em->em_dp_to_ext, (void*) ext);
      if (gethash (DP_ADDR2VOID (ext->ext_dp), dbs->dbs_dp_to_extent_map))
	GPF_T1 ("reading an ext from ext map that is already allocated in the dbs");
      sethash (DP_ADDR2VOID (ext->ext_dp), dbs->dbs_dp_to_extent_map, (void*) em);
      if (EXT_REMAP == EXT_TYPE (ext))
	{
	  em->em_n_remap_pages += EXTENT_SZ;
	  em->em_n_free_remap_pages += ext_free_count (ext);
	}
      else if (EXT_BLOB == EXT_TYPE (ext))
	{
	  em->em_n_blob_pages += EXTENT_SZ;
	  em->em_n_free_blob_pages += ext_free_count (ext);
	}
      else if (EXT_INDEX == EXT_TYPE (ext))
	{
	  em->em_n_pages += EXTENT_SZ;
	  em->em_n_free_pages += ext_free_count (ext);
	}
      else
	log_error ("not supposed to read a free ext from an ext map");
    }
  END_DO_EXT;
  return em;
}


buffer_desc_t **
ext_read (index_tree_t * it, extent_t * ext, int keep_ts, dk_hash_t * phys_to_log)
{
  int inx, word, bit, fill = 0;
  int n_pages = bits_count ((db_buf_t) &ext->ext_pages, EXTENT_SZ / 32, EXTENT_SZ);
  dk_set_t buf_list = NULL;
  buffer_desc_t ** bufs, ** bufs_copy;
  if (!n_pages)
    return NULL;
  for (inx = 0; inx < EXTENT_SZ; inx++)
    {
      EXT_BIT (ext, ext->ext_dp + inx, word, bit);
      if (ext->ext_pages[word] & 1 << bit)
	{
	  buffer_desc_t * buf = bp_get_buffer (NULL, BP_BUF_IF_AVAIL);
	  it_map_t * itm;
	  dp_addr_t log;
	  if (!buf)
	    break;
	  dk_set_push (&buf_list, (void*)buf);
	  buf->bd_physical_page = ext->ext_dp + inx;
	  log = (ptrlong) gethash (DP_ADDR2VOID (buf->bd_physical_page), phys_to_log);
	  if (!log)
	    log = buf->bd_physical_page;
	  itm = IT_DP_MAP (it, log);
	  mutex_enter (&itm->itm_mtx);
	  sethash (DP_ADDR2VOID (log), &itm->itm_dp_to_buf, (void*)buf);
	  mutex_leave (&itm->itm_mtx);
	  buf->bd_page = log;

	  if (keep_ts)
	    buf->bd_timestamp = buf->bd_pool->bp_last_buf_ts;
	  buf->bd_being_read = 1;
	  buf->bd_registered = (it_cursor_t*) -1; /* buffer is not replaceable even after read completes */
	  buf->bd_storage = it->it_storage;
	  buf->bd_readers = 0;
	  buf->bd_tree = it;
	  BD_SET_IS_WRITE (buf, 1);
	}
    }
  bufs = (buffer_desc_t **)dk_alloc_box (sizeof (caddr_t) * dk_set_length (buf_list), DV_BIN);
  fill = 0;
  DO_SET (buffer_desc_t *, elt, &buf_list)
    {
      bufs[fill++] = elt;
    }
  END_DO_SET();
  dk_set_free (buf_list);
  bufs_copy = (buffer_desc_t **) box_copy ((caddr_t) bufs);
  iq_schedule (bufs_copy, fill);
  dk_free_box ((caddr_t)bufs_copy);
  return bufs;
}


dk_mutex_t * extent_map_create_mtx;


int
it_own_extent_map (index_tree_t * tree)
{
  char name[1000];
  dp_addr_t em_dp;
  dbe_storage_t * dbs = tree->it_storage;
  extent_map_t * em;
  extent_t * new_ext;
  int slice = 0;
  mutex_enter (extent_map_create_mtx);
  if (tree->it_extent_map != dbs->dbs_extent_map)
    {
      mutex_leave (extent_map_create_mtx);
      return 1;
    }
  em_dp = em_new_dp (dbs->dbs_extent_map, EXT_INDEX, 0, NULL);
  if (!em_dp)
	{
	  log_error ("Out of disk in making a new ext map");
	  mutex_leave (extent_map_create_mtx);
	  return 0;
	}
  em = em_allocate (dbs, em_dp);
  new_ext = em_new_extent (em, EXT_INDEX, EXT_EXTENDS_NONE);
  if (!new_ext)
    {
      log_error ("out of disk in making first ext for new ext map");
	  mutex_leave (extent_map_create_mtx);
	  return 0;
    }
  if (DBS_ELASTIC == tree->it_storage->dbs_type)
    slice = tree->it_slice;
  snprintf (name, sizeof (name), "__EM:%s",
	    KI_TEMP == tree->it_key->key_id ? "temp": tree->it_key->key_fragments[slice]->kf_name);
  em->em_name = box_dv_short_string (name );
  tree->it_extent_map = em;
  mutex_leave (extent_map_create_mtx);
  return 1;
}


extent_map_t *
it_col_own_extent_map (index_tree_t * tree, oid_t col_id)
{
  char name[1000];
  dp_addr_t em_dp;
  dbe_storage_t * dbs = tree->it_storage;
  extent_map_t * em;
  extent_t * new_ext;
  mutex_enter (extent_map_create_mtx);
  em = (extent_map_t *)gethash ((void*)(ptrlong)col_id, tree->it_col_extent_maps);
  if (em)
    {
      mutex_leave (extent_map_create_mtx);
      return em;
    }
  em_dp = em_new_dp (dbs->dbs_extent_map, EXT_INDEX, 0, NULL);
  if (!em_dp)
	{
	  log_error ("Out of disk in making a new ext map");
	  mutex_leave (extent_map_create_mtx);
	  return NULL;
	}
  em = em_allocate (dbs, em_dp);
  new_ext = em_new_extent (em, EXT_INDEX, EXT_EXTENDS_NONE);
  if (!new_ext)
    {
      log_error ("out of disk in making first ext for new ext map");
	  mutex_leave (extent_map_create_mtx);
	  return NULL;
    }
  snprintf (name, sizeof (name), "__EMC:%s:%s:%d",
	    KI_TEMP == tree->it_key->key_id ? "temp" : tree->it_key->key_table->tb_name,
	    KI_TEMP == tree->it_key->key_id ? "temp": tree->it_key->key_name, (int)col_id);
  em->em_name = box_dv_short_string (name);
  sethash ((void*)(ptrlong)col_id, tree->it_col_extent_maps, (void*)em);
  mutex_leave (extent_map_create_mtx);
  return em;
}


void
kf_set_extent_map (dbe_key_frag_t * kf)
{
  char name[1000];
  caddr_t dp_str;
  dp_addr_t dp;
  dbe_storage_t * dbs = kf->kf_it->it_storage;
  snprintf (name, sizeof (name), "__EM:%s", kf->kf_name);
  IN_TXN;
  dp_str = dbs_registry_get (dbs, name);
  LEAVE_TXN;
  dp = dp_str ? atoi (dp_str) : 0;
  dk_free_box (dp_str);
  if (!dp)
    kf->kf_it->it_extent_map = kf->kf_it->it_storage->dbs_extent_map;
  else
    {
      kf->kf_it->it_extent_map = dbs_read_extent_map (dbs, name, dp);
    }
  if (kf->kf_it->it_key->key_is_col)
    {
      index_tree_t * it = kf->kf_it;
      DO_SET (dbe_column_t *, col, &it->it_key->key_parts)
	{
	  snprintf (name, sizeof (name), "__EMC:%s:%s:%d", it->it_key->key_table->tb_name, it->it_key->key_name, (int)col->col_id);
	  IN_TXN;
	  dp_str = dbs_registry_get (dbs, name);
	  LEAVE_TXN;
	  dp = dp_str ? atoi (dp_str) : 0;
	  dk_free_box (dp_str);
	  if (dp)
	    {
	      extent_map_t * em = dbs_read_extent_map (dbs, name, dp);
	      if (!it->it_col_extent_maps)
		it->it_col_extent_maps = hash_table_allocate (11);
	      sethash ((void*)(ptrlong)col->col_id, it->it_col_extent_maps, (void*)em);

	    }
	}
      END_DO_SET();
    }
}


void
dbs_stretch_sets (dbe_storage_t * dbs)
{
  while (dbs->dbs_n_pages > dbs->dbs_n_pages_in_extent_set)
    {
      buffer_desc_t * last = page_set_extend (dbs, &dbs->dbs_extent_set, 0, DPF_EXTENT_SET);
      last->bd_page = last->bd_physical_page = em_new_dp (dbs->dbs_extent_map, EXT_INDEX, DP_ANY, NULL);
      page_set_checksum_init (last->bd_buffer + DP_DATA);
      dbs->dbs_n_pages_in_extent_set += EXTENT_SZ * BITS_ON_PAGE;
    }
  while (dbs->dbs_n_pages > dbs->dbs_n_pages_in_sets)
    {
      /* add a page of global free set and backup set */
      buffer_desc_t * last = page_set_extend (dbs, &dbs->dbs_free_set, 0, DPF_FREE_SET);
      page_set_checksum_init (last->bd_buffer + DP_DATA);
      last->bd_page = last->bd_physical_page = em_new_dp (dbs->dbs_extent_map, EXT_INDEX, DP_ANY, NULL);

      last = page_set_extend (dbs, &dbs->dbs_incbackup_set, 0, DPF_INCBACKUP_SET);
      page_set_checksum_init (last->bd_buffer + DP_DATA);
      last->bd_page = last->bd_physical_page = em_new_dp (dbs->dbs_extent_map, EXT_INDEX, DP_ANY, NULL);
      dbs->dbs_n_pages_in_sets += BITS_ON_PAGE;
    }
}


void
dbs_extent_init (dbe_storage_t * dbs)
{
  buffer_desc_t * ps;
  int inx;
  extent_map_t * em;
  extent_t * new_ext;
  page_set_extend (dbs, &dbs->dbs_extent_set, 1, DPF_EXTENT_SET);
  dbs->dbs_n_pages_in_extent_set = EXTENT_SZ * BITS_ON_PAGE;
  ps = page_set_extend (dbs, &dbs->dbs_free_set, 2, DPF_FREE_SET);
  ps = page_set_extend (dbs, &dbs->dbs_incbackup_set, 3, DPF_INCBACKUP_SET);
  dbs->dbs_n_pages_in_sets = BITS_ON_PAGE;
  em = em_allocate (dbs, 4);
  em->em_name = box_dv_short_string ("__sys_ext_map");
  dbs->dbs_extent_map = em;
  mutex_enter (em->em_mtx);
  new_ext = em_new_extent (em, EXT_INDEX, 0);
  mutex_leave (em->em_mtx);
  for (inx = 0; inx < 5; inx++)
    em_dp_allocated (em, inx, 0);
  page_set_checksum_init (dbs->dbs_free_set->bd_buffer + DP_DATA);
  page_set_checksum_init (dbs->dbs_incbackup_set->bd_buffer + DP_DATA);
  page_set_checksum_init (dbs->dbs_extent_set->bd_buffer + DP_DATA);
  dbs_stretch_sets (dbs);
}


void
dbs_extent_open (dbe_storage_t * dbs)
{
  dp_addr_t dp;
  caddr_t str;
  IN_TXN;
  str = registry_get ("__sys_ext_map");
  LEAVE_TXN;
  dp = atoi (str);
  if (!dp)
    GPF_T1 ("no system ext map opening existent db");
  dbs->dbs_extent_map = dbs_read_extent_map (dbs, "__sys_ext_map", dp);
  dbs_stretch_sets (dbs);
}

