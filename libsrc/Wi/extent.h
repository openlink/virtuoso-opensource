/*
 *  $Id$
 *
 *  Disk extents
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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


#define EXTENT_SZ 256
#define KEY_OWN_EXTENT_THRESHOLD (EXTENT_SZ / 2)

#define EXT_FREE 0
#define EXT_INDEX 1
#define EXT_REMAP 2
#define EXT_BLOB 3
#define EXT_FULL 8

#define EXT_TYPE(ext) (7 & (ext)->ext_flags)

/* em_free_dp flags to indicate expected type of ext.  In addition to EXT_* */
#define EMF_INDEX_OR_REMAP 4
#define EMF_DO_NOT_FREE_EXT 16
#define EMF_ANY 32
#define EMF_INDEX_OR_BLOB 64


#define EXT_ROUND(dp) ((dp) & ~(EXTENT_SZ - 1))

typedef struct extent_s
{
  int32	ext_flags;
  dp_addr_t	ext_dp;
  dp_addr_t	ext_prev; /* splits overflowing from that extent come here */
  dp_addr_t	ext_next; /* if this is full, splits here go to that extent */
  int32	ext_pages[EXTENT_SZ / 32];
} extent_t;


struct extent_map_s
{
  caddr_t		em_name; /* registry name, value is the 1st page  */
  dp_addr_t		em_map_start; /* first dp of stored em */
  dp_addr_t		em_n_pages;
  dp_addr_t		em_n_free_pages;
  dp_addr_t		em_n_remap_pages;
  dp_addr_t		em_n_free_remap_pages;
  int32		em_remap_on_hold;  /* no of pages provisionally reserved for possible delta caused by tree splitting */
  dp_addr_t		em_n_blob_pages;
  dp_addr_t		em_n_free_blob_pages;
  extent_t *		em_last_remap_ext;
  extent_t *		em_last_blob_ext;
  buffer_desc_t *	em_buf;
  dk_hash_t *		em_dp_to_ext;
  dk_mutex_t *		em_mtx;
  dbe_storage_t *	em_dbs;
  dbe_key_frag_t *	em_kf; /*  null for general sys ext, else the kf which allocates from here */
  dk_hash_t *		em_read_history;
  uint32		em_last_ext_read;
  dk_mutex_t 		em_read_history_mtx;
  dk_hash_t *		em_uninitialized; /* just alloc'd no buffer yet, avoid these in read ahead even if they look allocd.  Not applied to system ext map. */
};


#define EM_DP_TO_EXT(em, dp) \
  ((extent_t *) gethash (DP_ADDR2VOID (EXT_ROUND (dp)), em->em_dp_to_ext))

#define DP_IN_EXTENT(dp, ext) ((dp) >= (ext)->ext_dp && (dp) < (ext)->ext_dp + EXTENT_SZ)

#define EXT_BIT(ext, dp, inx, bit) \
{ \
  inx = ((dp) - ext->ext_dp) >> 5; \
  bit = (dp - ext->ext_dp) & 0x1f; \
}

#define DP_ANY ((dp_addr_t)-1)
#define DP_MAX ((dp_addr_t)0xffffffff)

#define EXT_EXTENDS_NONE ((dp_addr_t) -1)

#define DBS_DP_TO_EM(dbs, dp) \
  ((extent_map_t *) gethash (DP_ADDR2VOID (EXT_ROUND (dp)), dbs->dbs_dp_to_extent_map))

#define DP_OUT_OF_DISK ((dp_addr_t)-1)

caddr_t em_page_list (extent_map_t * em, int type);

#define DO_EXT(ext, em) \
{ \
  extent_t * ext; \
  buffer_desc_t * _buf; \
  for (_buf = em->em_buf; _buf; _buf = _buf->bd_next) \
    { \
      int _fill = LONG_REF (_buf->bd_buffer + DP_BLOB_LEN), _off; \
      for (_off = DP_DATA; _off < DP_DATA + _fill; _off += sizeof (extent_t)) \
	{ \
	  ext = (extent_t *) (_buf->bd_buffer + _off);


#define END_DO_EXT } } }

buffer_desc_t **  ext_read (index_tree_t * it, extent_t * ext, int keep_ts, dk_hash_t * phys_to_log);
buffer_desc_t * page_set_last (buffer_desc_t * buf);

