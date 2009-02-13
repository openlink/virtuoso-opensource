/*
 *  insert.c
 *
 *  $Id$
 *
 *  Insert
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

#include "sqlnode.h"


#ifdef PAGE_TRACE
#define rdbg_printf_2(q) printf q
#endif


void
pg_map_clear (buffer_desc_t * buf)
{
#ifdef PAGE_TRACE
  memset (&buf->bd_content_map->pm_entries[0], 0, buf->bd_content_map->pm_size * sizeof (short));
  /* Looks nicer in debugger. */
#endif
  buf->bd_content_map->pm_filled_to = DP_DATA;
  buf->bd_content_map->pm_bytes_free = PAGE_SZ - DP_DATA;
  buf->bd_content_map->pm_count = 0;
}


#define PG_ERR_OR_GPF_T \
  { if (assertion_on_read_fail) GPF_T; \
    else return WI_ERROR; }



void
map_resize (page_map_t ** pm_ret, int new_sz)
{
  page_map_t * pm = *pm_ret;
  page_map_t * new_pm = (page_map_t *) resource_get (PM_RC (new_sz));
  memcpy (new_pm, pm, PM_ENTRIES_OFFSET + sizeof (short) * pm->pm_count);
  *pm_ret = new_pm;
  resource_store (PM_RC (pm->pm_size), (void*) pm);
  new_pm->pm_size = new_sz;
}


void
map_append (page_map_t ** pm_ret, int ent)
{
  page_map_t * pm = *pm_ret;
  if (pm->pm_count + 1 > pm->pm_size)
    {
      int new_sz = PM_SIZE (pm->pm_size);
      if (pm->pm_count + 1 > PM_MAX_ENTRIES)
	GPF_T1 ("page map entry count overflow");
      map_resize (pm_ret, new_sz);
      pm = *pm_ret;
    }
  pm->pm_entries[pm->pm_count++] = ent;
}


int
row_length (db_buf_t row, dbe_key_t * key)
{
  int len;
  key_id_t key_id = SHORT_REF (row + IE_KEY_ID);
  if (key_id && key_id != key->key_id)
    {
      /* if obsolete row, subtable etc. If temp, then both given key and row have KI_TEMP and if leaf then id == 0 */
      key = sch_id_to_key (wi_inst.wi_schema, key_id);
    }
  ROW_LENGTH (row, key, len);
  return len;
}


void
row_write_reserved (dtp_t * end, int bytes)
{
  if (bytes < 128)
    end[0] = bytes;
  else
    {
      end[0] = 0;
      SHORT_SET_NA (end + 1, bytes);
    }
}


int
row_reserved_length (db_buf_t row, dbe_key_t * key)
{
  int len;
  key_id_t key_id = SHORT_REF (row + IE_KEY_ID);
  if (key_id && key_id != key->key_id)
    {
      /* if obsolete row, subtable etc. If temp, then both given key and row have KI_TEMP and if leaf then id == 0 */
      if (KI_LEFT_DUMMY == key_id)
	return 8;
      key = sch_id_to_key (wi_inst.wi_schema, key_id);
      if (!key)
	{
	  if (assertion_on_read_fail)
	    GPF_T1 ("Row with bad key");
	  return 8;  /* for crash dump this is not essential. Ret minimum */
	}
    }
  ROW_LENGTH (row, key, len);
  if (IE_ISSET (row, IEF_UPDATE))
    {
      dtp_t gap = row[len];
      if (!SHORT_REF (row + IE_KEY_ID))
	GPF_T1 ("a leaf pointer is not supposed to have the updated flag on");
      if (gap)
	len += gap;
      else
	len += SHORT_REF_NA (row + len + 1);
    }
  return len;
}

#define dbg_page_map_to_file(buf) { \
  FILE * dmp = fopen ("bufdump.txt", "w"); \
  dbg_page_map_f (buf, dmp); \
  fclose (dmp); \
} 

int
pg_make_map (buffer_desc_t * buf)
{
  db_buf_t page = buf->bd_buffer;
  key_id_t k_id = SHORT_REF (page + DP_KEY_ID);
  dbe_key_t * pg_key;
  int free = PAGE_SZ - DP_DATA, sz;
  int pos = SHORT_REF (page + DP_FIRST);
  page_map_t *map = buf->bd_content_map;
  int len, inx = 0, fill = DP_DATA;

  buf->bd_content_map = NULL;
  if (!wi_inst.wi_schema)
    {
      log_error (
	  "Trying to access the database schema data before the schema has been initialized. "
	  "This is usually caused by an unrecoverable corrupted database file. ");
      call_exit (-1);
    }

  pg_key = KI_TEMP == k_id ?
      buf->bd_tree->it_key :
      sch_id_to_key (wi_inst.wi_schema, k_id);
  if (!map)
    {
      map = (page_map_t *) resource_get (PM_RC (PM_SZ_1));
    }
  if (pos && !pg_key)
    {
      if (assertion_on_read_fail)
	GPF_T1 ("page read with no key defd");
      map->pm_count = 0;
      buf->bd_content_map = map;
      return 0;
    }
  while (pos)
    {
      if (pos >= PAGE_SZ)
	PG_ERR_OR_GPF_T;	/* Link over end */
      len = row_reserved_length (page + pos, pg_key);
      len = ROW_ALIGN (len);
      if (len < 0)
	{
	  log_error ("Structure inconsistent on key=%s, dp=%ld, physical dp=%ld",
	      (pg_key && pg_key->key_name ? pg_key->key_name : "TEMP KEY"),
	      buf->bd_page, buf->bd_physical_page);
	  dbg_page_map_to_file (buf);
	  STRUCTURE_FAULT;
	}
      free -= len;
      if (inx >= map->pm_size)
	{
	  map->pm_count = inx;
	  map_resize (&map, PM_SIZE (map->pm_size));
	}
      map->pm_entries[inx++] = pos;
      if (pos + len > fill)
	fill = pos + len;
      if (fill > PAGE_SZ)
	{
	  log_error ("Structure inconsistent on key=%s, dp=%ld, physical dp=%ld",
	      (pg_key && pg_key->key_name ? pg_key->key_name : "TEMP KEY"),
	      buf->bd_page, buf->bd_physical_page);
	  dbg_page_map_to_file (buf);
	  STRUCTURE_FAULT;
	}
      pos = IE_NEXT (page + pos);
      if (inx >= PM_MAX_ENTRIES)
	{
	  log_error ("Structure inconsistent on key=%s, dp=%ld, physical dp=%ld",
	      (pg_key && pg_key->key_name ? pg_key->key_name : "TEMP KEY"),
	      buf->bd_page, buf->bd_physical_page);
	  dbg_page_map_to_file (buf);
	  STRUCTURE_FAULT;
	}
    }
  if (free < 0)
    {
      log_error ("Structure inconsistent on key=%s, dp=%ld, physical dp=%ld",
	  (pg_key && pg_key->key_name ? pg_key->key_name : "TEMP KEY"),
	  buf->bd_page, buf->bd_physical_page);
      dbg_page_map_to_file (buf);
      STRUCTURE_FAULT;
    }
  map->pm_bytes_free = free;
  map->pm_count = inx;
  map->pm_filled_to = fill;
  sz = PM_SIZE (map->pm_count);
  if (sz < map->pm_size)
    {
      map_resize (&map, sz);
    }
  buf->bd_content_map = map;
  return 1;
}


void
pg_check_map_1 (buffer_desc_t * buf)
{
  page_map_t org_map;
  int org_free = buf->bd_content_map->pm_bytes_free;
#if 0
  int pos, ctr = 0;
  db_buf_t page;
#endif
  memcpy (&org_map, buf->bd_content_map, ((ptrlong)(&((page_map_t*)0)->pm_entries)) + 2 * buf->bd_content_map->pm_count);
  /* for debug, copy the entries, the whole struct may overflow addr space. */
  if (!buf->bd_is_write)
    GPF_T1 ("must have written access to buffer to check it");
#ifdef MTX_DEBUG
  if (buf->bd_writer != THREAD_CURRENT_THREAD)
    GPF_T1 ("Must have write on buffer to check it");
#endif
  pg_make_map (buf);
  if (org_free != buf->bd_content_map->pm_bytes_free)
    GPF_T1 ("map bytes free out of sync");
  org_map.pm_size = buf->bd_content_map->pm_size;
  if (org_map.pm_filled_to < buf->bd_content_map->pm_filled_to)
    GPF_T1 ("filled to of map is too low");
  org_map.pm_filled_to = buf->bd_content_map->pm_filled_to;
  if (memcmp (&org_map, buf->bd_content_map, ((ptrlong)(&((page_map_t*)0)->pm_entries)) + 2 * buf->bd_content_map->pm_count))
    GPF_T1 ("map not in sync with buf");
#if 0
  /* debug code for catching insert/update of a particular row */
  page = buf->bd_buffer;
  pos = SHORT_REF (page + DP_FIRST);
  while (pos)
    {
      key_id_t ki = SHORT_REF (page + pos + IE_KEY_ID);
      if (1001 == ki)
	{
	  if (1000037 == LONG_REF (page + pos + 4)
	      && 1155072 == LONG_REF (page + pos + 12)
	      && 1369287 == LONG_REF_NA (page + pos + 4 +17))
	    ctr++;
	  if (ctr > 1)
	    printf ("bingbing\n");
	}
      pos = IE_NEXT (page + pos);
    }
#endif
}

#if defined (MTX_DEBUG) | defined (PAGE_TRACE)
void
pg_check_map (buffer_desc_t * buf)
{
  pg_check_map_1 (buf);
}
#endif

void
pg_move_cursors (it_cursor_t ** temp_itc, int fill, buffer_desc_t * buf_from,
    int from, dp_addr_t page_to, int to, buffer_desc_t * buf_to)
{
  int n;
  it_cursor_t *it_list;
  if (!fill)
    return;
  assert (buf_from->bd_is_write && (!buf_to || buf_to->bd_is_write));
  for (n = 0; n < fill; n++)
    {
      it_list = temp_itc[n];
      if (!it_list)
	continue;
      if (it_list->itc_page == buf_from->bd_page
	  && it_list->itc_position == from)
	{
	  temp_itc[n] = NULL;
	  /* Once a cursor has been moved it will not move again
	     during the same pg_write_compact. Consider: x is moved to
	     future place, then the same place in pre-compacted is moved
	     someplace else.
	     If so the itc gets moved twice which is NEVER RIGHT */
	  it_list->itc_position = to;
	  if (page_to != it_list->itc_page)
	    {
	      itc_unregister_inner (it_list, buf_from, 1);
	      it_list->itc_page = page_to;
	      itc_register (it_list, buf_to);
	    }
	}
    }
}


void
pg_delete_move_cursors (it_cursor_t * itc, buffer_desc_t * buf_from, int pos_from,
			buffer_desc_t * buf_to, int pos_to)
{
  it_cursor_t *it_list;
  assert (buf_from->bd_is_write && (!buf_to || buf_to->bd_is_write));
  it_list = buf_from->bd_registered;

  while (it_list)
    {
      it_cursor_t *next = it_list->itc_next_on_page;
      if (buf_to)
	{
	  rdbg_printf (("  itc delete move by T=%d moved itc=%x  from L=%d pos=%d to L=%d pos=%d was_on_row=%d \n",
			TRX_NO (itc->itc_ltrx), it_list, it_list->itc_page, it_list->itc_position, buf_to->bd_page, pos_to, it_list->itc_is_on_row));
	  itc_unregister_inner (it_list, buf_from, 1);
	  it_list->itc_page = buf_to->bd_page;
	  it_list->itc_position = pos_to;
	  it_list->itc_is_on_row = 0;
	  itc_register (it_list, buf_to);
	}
      else
	{
	  if (it_list->itc_page == buf_from->bd_page
	      && it_list->itc_position == pos_from)
	    {
	      rdbg_printf (("  itc delete move inside page by T=%d moved itc=%x  from L=%d pos=%d to L=%d pos=%d was_on_row=%d \n",
			    TRX_NO (itc->itc_ltrx), it_list, it_list->itc_page, it_list->itc_position, buf_from->bd_page, pos_to, it_list->itc_is_on_row));
	      it_list->itc_position = pos_to;
	      it_list->itc_is_on_row = 0;
	    }
	}
      it_list = next;
    }
}


/* This function will write one page plus one insert as a compact
   image on one or two pages. All registered cursors will be moved.
   The argument cursor is set to point to the start of the inserted thing */

#define IS_FIRST(p, len) \
  if (!is_to_extend) \
    { \
      if (!first_copied) \
	first_copied = p; \
      last_copied = p + len;  \
    }

#define SWITCH_TO_EXT \
  if (!is_to_extend) \
    { \
      map_to = buf_ext->bd_content_map; \
      is_to_extend = 1; \
      prev_ent = 0; \
      page_to = ext_page; \
      place_to = DP_DATA; \
      pg_map_clear (buf_ext); \
    } \
  else \
    { \
      GPF_T; \
    }

#define LINK_PREV(ent)   \
  if (prev_ent) \
    { \
      IE_SET_NEXT (page_to + prev_ent, ent); \
    } \
  else \
    { \
      if (ent != DP_DATA) \
	GPF_T; \
      SHORT_SET (page_to + DP_FIRST, ent); \
    } \
  prev_ent = ent; \
  IE_SET_NEXT (page_to + prev_ent, 0); \

#define LINK_PREV_NC(ent)   \
  if (prev_ent) \
    { \
      IE_SET_NEXT (page_to + prev_ent, ent); \
    } \
  else \
    { \
      SHORT_SET (page_to + DP_FIRST, ent); \
    } \
  prev_ent = ent; \
  IE_SET_NEXT (page_to + prev_ent, 0); \



#define ADD_MAP_ENT(ent, len) \
  map_append (is_to_extend ? &buf_ext->bd_content_map : &buf_from->bd_content_map, ent); \
  map_to = is_to_extend ? buf_ext->bd_content_map : buf_from->bd_content_map; \
  map_to->pm_filled_to = ent + (int) (ROW_ALIGN (len)); \
  map_to->pm_bytes_free -= (int) (ROW_ALIGN (len)); \


int
is_ptr_in_array (void**array, int fill, void* ptr)
{
  int inx;
  for (inx = 0; inx < fill; inx++)
    if (array[inx] == ptr)
      return 1;
  return 0;
}


void
itc_keep_together (it_cursor_t * itc, buffer_desc_t * buf, buffer_desc_t * buf_from,
		   it_cursor_t ** cursors_in_trx, int cr_fill)
{
  it_cursor_t * cr_tmp [1000];
  int inx;

  if (itc->itc_bm_split_left_side && !itc->itc_bm_split_right_side)
    {
      /* this inserts the right side of a split bm inx entry. Move the crs registered on the left side to the right side
       * if they are past the dividing value.  If just landed waiting, mark then to reset the search 
       * The left and right are not always on the same page.  This is because the ins may have split or because of pre-existingf leaf pointers in the parent that just split the start of the left and of the right.  So different pages is not always split. */
      buffer_desc_t * left_buf;
      placeholder_t * left = itc->itc_bm_split_left_side;
      left_buf = left->itc_buf_registered;
      if (left_buf != buf_from && left_buf != buf)
	{
	  TC (tc_bm_split_left_separate_but_no_split);
	}
      itc->itc_bm_split_right_side = plh_landed_copy ((placeholder_t *) itc, buf);
    }

  if (!itc->itc_keep_together_pos)
    return;
  if (!cursors_in_trx)
    {
      it_cursor_t * registered = buf_from->bd_registered;

      /* could be inlined but use generic route for better testability */
      cursors_in_trx = cr_tmp;
      cr_fill = 0;
      while (registered)
	{
	  if (registered->itc_position == itc->itc_keep_together_pos)
	    cursors_in_trx[cr_fill++] = registered;
	  registered = registered->itc_next_on_page;
	}
    }
  for (inx = 0; inx < cr_fill; inx++)
    if (cursors_in_trx[inx]
	&& cursors_in_trx[inx]->itc_position == itc->itc_keep_together_pos
	&& cursors_in_trx[inx]->itc_page == itc->itc_keep_together_dp)
      {
	cursors_in_trx[inx]->itc_bp.bp_is_pos_valid = 0; /* set anyway even if not bm inx */
	TC (tc_update_wait_move);
	/* rdbg_printf (("keep together move on %d\n", itc->itc_page)); */
      }
  pg_move_cursors (cursors_in_trx, cr_fill,
		   buf_from, itc->itc_keep_together_pos,
		   itc->itc_page, itc->itc_position,
		   buf);


  itc->itc_keep_together_pos = 0;
}


int
map_entry_after (page_map_t * pm, int at)
{
  int after = PAGE_SZ, inx;
  for (inx = 0; inx < pm->pm_count; inx++)
    {
      short ent = pm->pm_entries[inx];
      if (ent > at && ent < after)
	after = ent;
    }
  return after;
}


extern long  tc_pg_write_compact;
#define WRITE_NO_GAP ((buffer_desc_t *)1)

void
pg_write_compact (it_cursor_t * it, buffer_desc_t * buf_from,
    int insert_to, db_buf_t insert, int split, buffer_desc_t * buf_ext,
    dp_addr_t dp_ext, row_lock_t * new_rl)
{
  page_map_t org_map;
  page_lock_t * pl_ext;
  page_lock_t * pl_from;
  int insert_len = 0, insert_len_1 = 0, insert_len_2 = 0;
  int tail = 0, ins_tail = 0; /*leave this much after each/inserted row for expansion */
  db_buf_t ext_page;
  db_buf_t from = buf_from->bd_buffer;
  unsigned char temp[PAGE_SZ];
  dp_addr_t dp_from = it->itc_page;
  it_cursor_t *cursors_in_trx[1000];
  row_lock_t * rlocks [PM_MAX_ENTRIES];
  int rl_fill = 0;
  int cr_fill = 0, inx;
  it_cursor_t *cr;

  page_map_t *map_to = buf_from->bd_content_map;
  db_buf_t page_to = (db_buf_t) & temp;
  int prev_ent = 0;
  long l;
  int place_from = SHORT_REF (from + DP_FIRST);
  int place_to = DP_DATA;
  int is_to_extend = 0;
  int first_copied = 0, last_copied = 0;


  if (insert)
    {
    insert_len = row_length (insert, it->itc_insert_key);
      if (INS_DOUBLE_LP == new_rl)
	{
	  insert_len_1 = ROW_ALIGN (insert_len);
	  insert_len_2 = row_length (insert + insert_len_1, it->itc_insert_key);
	  insert_len = insert_len_1 + insert_len_2;
	}
    }
  if (!buf_ext)
    {
      int space = buf_from->bd_content_map->pm_bytes_free - ROW_ALIGN (insert_len);
      int count = buf_from->bd_content_map->pm_count + (insert ? 1 : 0);
      if (space < 0) GPF_T1 ("negative space left in pg_write_compact");
      TC (tc_pg_write_compact);
      tail = (space / count) & ~3;  /* round to lower multiple of 4 */
      ins_tail = space - count * tail; /* ins tail is in addition to regular tail for the inserted row */
    }
  else if (WRITE_NO_GAP == buf_ext)
    {
      TC (tc_pg_write_compact);
      buf_ext = NULL;
    }
  ext_page = buf_ext ? buf_ext->bd_buffer : NULL;

  pl_ext = buf_ext ? buf_ext->bd_pl : NULL;
  pl_from = buf_from->bd_pl;
  if (pl_from && !PL_IS_PAGE (pl_from) && pl_from->pl_n_row_locks > map_to->pm_count)
    GPF_T1 ("more locks than rows");

  cr = buf_from->bd_registered;
  pl_rlock_table (pl_from, rlocks, &rl_fill);
  for (cr = cr; cr; cr = cr->itc_next_on_page)
    {
      cursors_in_trx[cr_fill++] = cr;
      if (cr_fill >= sizeof (cursors_in_trx) / sizeof (caddr_t))
	GPF_T1 ("too many cursors on splitting page.");
    }
  if (!cr_fill)
    ITC_LEAVE_MAPS (it);

  memcpy (&org_map, buf_from->bd_content_map, ((ptrlong)(&((page_map_t*)0)->pm_entries)) + 2 * buf_from->bd_content_map->pm_count); /* for debug, copy the entries, the whole struct may overflow addr space. */
  pg_map_clear (buf_from);
  while (1)
    {
      if (place_from >= PAGE_SZ)
	GPF_T;			/*Link over end */
      if (!is_to_extend && place_to >= split)
	{
	  if (buf_ext)
	    {
	      IS_FIRST (place_to, 0);
	      SWITCH_TO_EXT;
	    }
	  else
	    {
	      /* Over or at split, no extend */
	      if (place_to > PAGE_SZ)
		GPF_T;		/* Page overflows, no extend page */
	    }
	}
      if (insert_to == place_from)
	{
	  if (place_to + insert_len > PAGE_SZ)
	    {
	      IS_FIRST (place_to, 0);
	      SWITCH_TO_EXT;
	    }
	  memcpy (&page_to[place_to], insert, insert_len);
	  IS_FIRST (place_to, insert_len);
	  it->itc_position = place_to;
	  if (is_to_extend)
	    {
	      it->itc_page = dp_ext;
	      it->itc_pl = buf_ext->bd_pl;
	    }
	  itc_keep_together (it, is_to_extend ? buf_ext : buf_from, buf_from,
			     cursors_in_trx, cr_fill);
	  ITC_LEAVE_MAPS (it);
	  if (new_rl && INS_DOUBLE_LP != new_rl)
	    itc_insert_rl (it, is_to_extend ? buf_ext : buf_from, it->itc_position, new_rl, RL_NO_ESCALATE);
	  ADD_MAP_ENT (place_to, insert_len);
	  LINK_PREV (place_to);
	  if (INS_DOUBLE_LP == new_rl)
	    {
	      int right = place_to + insert_len_1;
	      LINK_PREV (right);
	      map_append (is_to_extend ? &buf_ext->bd_content_map : &buf_from->bd_content_map, right);
	    }
	  place_to += ROW_ALIGN (insert_len) + tail + ins_tail;
	}

      if (!place_from)
	break;			/* The end test. If insert_to == 0
				   the insert is to the end. */
      l = row_reserved_length (&from[place_from], it->itc_insert_key);
      if (place_to + l > PAGE_SZ)
	{
	  IS_FIRST (place_to, 0);
	  SWITCH_TO_EXT;
	}

      IS_FIRST (place_to, (int) (l));
      memcpy (&page_to[place_to], &from[place_from], (int) (l));
      pg_move_lock (it, rlocks, rl_fill, place_from, place_to,
		    is_to_extend ? pl_ext : pl_from, is_to_extend);
      pg_move_cursors (cursors_in_trx, cr_fill, buf_from, place_from,
	  is_to_extend ? dp_ext : dp_from, place_to,
	  is_to_extend ? buf_ext : buf_from);

      ADD_MAP_ENT (place_to, l);
      LINK_PREV (place_to);
      place_to += ROW_ALIGN (l)  + tail;
      place_from = IE_NEXT (from + place_from);
    }
  ITC_LEAVE_MAPS (it);
  IS_FIRST (place_to, 0);
  if (!first_copied)
    GPF_T;
  memcpy (from + first_copied, &temp[first_copied],
      MIN (PAGE_SZ, last_copied) - first_copied);
  SHORT_SET (from + DP_FIRST, DP_DATA);
  SHORT_SET (from + DP_RIGHT_INSERTS, 0);
  if (is_to_extend)
    SHORT_SET (page_to + DP_RIGHT_INSERTS, 0);

  for (inx = 0; inx < rl_fill; inx++)
    if (rlocks [inx] != NULL)
      GPF_T1 ("unmoved row lock");
}


/*
   When an inner node splits the leaves to the right of the split must be
   updated.
 */

int
pg_reloc_right_leaves (it_cursor_t * it, db_buf_t page, dp_addr_t dp)
{
  int any = 0;
  dp_addr_t leaf;
  int pos = SHORT_REF (page + DP_FIRST);
  while (pos)
    {
      leaf = leaf_pointer (page, pos);
      if (leaf)
	{
	  any = 1;
	  ITC_AGE_TRX (it, 5);
	  itc_set_parent_link (it, leaf, dp);
	    }
      pos = IE_NEXT (page + pos);
    }
  return any;
}


caddr_t
box_n_bin (dtp_t * bin, int len)
{
  caddr_t res = dk_alloc_box (len, DV_BIN);
  memcpy (res, bin, len);
  return res;
}


db_buf_t
itc_make_leaf_entry (it_cursor_t * itc, db_buf_t row, dp_addr_t to)
{
  dbe_col_loc_t * cl;
  int len;
  db_buf_t row_data;
  key_id_t key_id = SHORT_REF (row + IE_KEY_ID);
  dbe_key_t * key = itc->itc_insert_key;
  dtp_t image[PAGE_DATA_SZ];
  db_buf_t res = &image[0];
  int inx = 0, prev_end;
  itc->itc_row_key = key;
  if (!key_id)
    {
      int len = row_length (row, itc->itc_insert_key);
      if (len - IE_LP_FIRST_KEY > MAX_RULING_PART_BYTES)
	GPF_T1 ("leaf pointer too long in copying a leaf pointer in splitting");
      res = (db_buf_t) box_n_bin ((dtp_t *) row, len);
      LONG_SET (res + IE_LEAF, to);
      return res;
    }
  if (KI_LEFT_DUMMY == key_id)
    {
      res = &image[0];
      SHORT_SET (res + IE_NEXT_IE, 0);
      SHORT_SET (res + IE_KEY_ID, KI_LEFT_DUMMY);
      LONG_SET (res + IE_LEAF, to);
      return ((db_buf_t) box_n_bin ((dtp_t *) res, 8));
    }
  /* need the row's key since location of key vars depends on it, could be obsolete row etc */
  if (KI_TEMP != key_id)
    {
      key = sch_id_to_key (wi_inst.wi_schema, key_id);
      itc->itc_row_key = key;
      itc->itc_row_key_id = key->key_id;
    }
  LONG_SET (res, 0);
  LONG_SET (res + IE_LEAF, to);
  res += IE_LP_FIRST_KEY;
  row_data = row + IE_FIRST_KEY;
  if (key->key_key_fixed)
    {
      for (inx = 0; key->key_key_fixed[inx].cl_col_id; inx++)
	{
	  int off;
	  cl = &key->key_key_fixed[inx];
	  off = cl->cl_pos;
	  memcpy (res + off, row_data + off, cl->cl_fixed_len);
	  if (cl->cl_null_mask)
	    res[cl->cl_null_flag] = row_data[cl->cl_null_flag]; /* copy the byte since all parts have their bit copied */
	}
    }
  prev_end = key->key_key_var_start;
  if (key->key_key_var)
    {
      itc->itc_row_key_id = key_id;
      itc->itc_row_data = row_data;
      for (inx = 0; key->key_key_var[inx].cl_col_id; inx++)
	{
	  int off;
	  cl = &key->key_key_var[inx];
	  ITC_COL (itc, (*cl), off, len);
	  memcpy (res + prev_end, row_data + off, len);
	  if (0 == inx)
	    SHORT_SET (res + key->key_length_area, len + prev_end);
	  else
	    SHORT_SET ((res - cl->cl_fixed_len) + 2, len + prev_end);
	  prev_end = prev_end + len;
	  if (cl->cl_null_mask)
	    res[cl->cl_null_flag] = row_data[cl->cl_null_flag]; /* copy the byte since all parts have their bit copied */
	}
    }
  if (prev_end > MAX_RULING_PART_BYTES)
    GPF_T1 ("leaf pointer too long in making a leaf pointer from a row");
  return ((db_buf_t) box_n_bin (&image[0], IE_LP_FIRST_KEY + prev_end));
}


db_buf_t
lp_concat (dbe_key_t * key, db_buf_t lp1, db_buf_t lp2)
{
  int l1 = row_length (lp1, key);
  int l2 = row_length (lp2, key);
  db_buf_t dl = (db_buf_t) dk_alloc_box (ROW_ALIGN (l1) + ROW_ALIGN (l2), DV_STRING);
  memcpy (dl, lp1, l1);
  memcpy (dl + ROW_ALIGN (l1), lp2, l2);
  dk_free_box ((caddr_t) lp1);
  dk_free_box ((caddr_t) lp2);
  return dl;
}


void
itc_split (it_cursor_t * it, buffer_desc_t ** buf_ret, db_buf_t dv,
	   row_lock_t * new_rl)
{
  buffer_desc_t *buf = *buf_ret;
  db_buf_t page = buf->bd_buffer;
  int is_new_root = 0;
  db_buf_t left_leaf = NULL;
  int ext_pos;
  db_buf_t right_leaf = NULL;
  buffer_desc_t *parent;
  dp_addr_t dp_parent = LONG_REF (page + DP_PARENT);
  long right_count = SHORT_REF (page + DP_RIGHT_INSERTS);
  int split = right_count > 5 ? (PAGE_SZ / 100) * 95 : PAGE_SZ / 2;
  buffer_desc_t *extend;
  thread_t *self = THREAD_CURRENT_THREAD;
  if (!(*buf_ret)->bd_is_dirty)
    GPF_T1 ("buffer not marked dirty in split");

  if (THR_IS_STACK_OVERFLOW (self, &buf, SPLIT_STACK_MARGIN))
    GPF_T1 ("out of stack space in itc_split");
  /* Take extend near parent. if root, extend near old root */
  it->itc_tree->it_is_single_page = 0;
  extend = it_new_page (it->itc_tree,
      dp_parent ? dp_parent : buf->bd_page,
      DPF_INDEX, 0, it->itc_n_pages_on_hold);
  if (dp_parent)
    dp_may_compact ((*buf_ret)->bd_storage, dp_parent);

  ITC_MARK_NEW (it);
  if (!extend)
    GPF_T1 ("Out of disk in split");
  itc_split_lock (it, *buf_ret, extend);
  pg_write_compact (it, buf, it->itc_position, dv, split, extend,
      extend->bd_page, new_rl);
  if ((*buf_ret)->bd_pl && PL_IS_PAGE ((*buf_ret)->bd_pl))
    {
      itc_split_lock_waits (it, *buf_ret, extend);
    }
  ITC_LEAVE_MAPS (it);
  right_leaf = itc_make_leaf_entry (it, extend->bd_buffer + DP_DATA, extend->bd_page);

  if (!dp_parent)
    {
      /* Root split */

      rdbg_printf_2 (("Root %ld split.\n", (*buf_ret)->bd_page));

      is_new_root = 1;
      parent = it_new_page (it->itc_tree, buf->bd_page, DPF_INDEX, 0, it->itc_n_pages_on_hold);
      dp_parent = parent->bd_page;
      if (!parent)
	GPF_T1 ("Out of disk in root split");
      LONG_SET (buf->bd_buffer + DP_PARENT, dp_parent);
      left_leaf = itc_make_leaf_entry (it, buf->bd_buffer + DP_DATA, buf->bd_page);
      memcpy (parent->bd_buffer + DP_DATA, left_leaf,
	  (int) (box_length ((caddr_t) left_leaf)));
      SHORT_SET (parent->bd_buffer + DP_FIRST, DP_DATA);
      pg_make_map (parent);
      ITC_IN_KNOWN_MAP (it, parent->bd_page);
      /* do not set it in the middle of the itc_reset sequence */
      it->itc_tree->it_root = parent->bd_page;
      ITC_LEAVE_MAP_NC (it);
    }
  else
	{
      parent = itc_write_parent (it, buf);
      dp_parent = parent->bd_page;
      ITC_IN_KNOWN_MAP (it, dp_parent);
      it->itc_page = parent->bd_page;
      itc_delta_this_buffer (it, parent, DELTA_MAY_LEAVE);

    }

  ITC_LEAVE_MAPS (it);
  LONG_SET (&extend->bd_buffer[DP_PARENT], parent->bd_page);

  rdbg_printf_2 (("    Node %ld split %s. Extend to %ld , Parent %ld .\n",
		  (*buf_ret)->bd_page, (split > PAGE_SZ / 2 ? "R" : ""),
      extend->bd_page, dp_parent));

  /* Now change the parent pointers of leaves to the right of split */
  switch (pg_reloc_right_leaves (it, extend->bd_buffer, extend->bd_page))
    {
    case 0:
      break;
    case -1:
      GPF_T1 ("Out of disk on relock right leaves");
    default:;
#ifdef DEBUG
/*
      dbg_page_map (parent);
      dbg_page_map (buf);
      dbg_page_map (extend);
 */
#endif
    }

  /* Now search for the place to insert the extend. */
  ext_pos = find_leaf_pointer (parent, buf->bd_page, NULL, NULL);
  if (ext_pos <= 0)
    GPF_T;			/* Parent with no ref. to child leaf */

  it->itc_position = ext_pos;
  it->itc_page = parent->bd_page;
  it->itc_pl = parent->bd_pl;
  if (!is_new_root)
    {
      int next;
      it->itc_keep_together_pos = ext_pos;
      it->itc_keep_together_dp = parent->bd_page;
      left_leaf = itc_make_leaf_entry (it, buf->bd_buffer + DP_DATA, buf->bd_page);
      page_unlink_row (parent, it->itc_position, &next);
      it->itc_position = next;
      right_leaf = lp_concat (it->itc_insert_key, left_leaf, right_leaf);
      left_leaf = NULL;
    }
  else 
  itc_skip_entry (it, parent->bd_buffer);

  /* Position cursor on parent right after this leaf's pointer.
     The extend page leaf entry will come here. */
  ITC_IN_KNOWN_MAP (it, buf->bd_page);
  page_mark_change (buf, RWG_WAIT_SPLIT);
  page_leave_inner (buf);
  ITC_LEAVE_MAP_NC (it);
  ITC_IN_KNOWN_MAP (it, extend->bd_page);
  page_leave_inner (extend);
  ITC_LEAVE_MAP_NC (it);

  itc_insert_dv (it, &parent, right_leaf, 1, is_new_root ?NULL : INS_DOUBLE_LP);

  /* Returning edge. Deallocate and leave pages. */
  if (left_leaf)
    dk_free_box ((caddr_t) left_leaf);
  dk_free_box ((box_t) right_leaf);
}



/* Statistics */
long right_inserts = 0;
long mid_inserts = 0;


/* Insert before entry at <at>, return pos of previous entry,
   0 if this is first */


int
map_insert (page_map_t ** map_ret, int at, int what)
{
  page_map_t * map = *map_ret;
  int inx, prev = 0, tmp;
  int ct = map->pm_count;
  if (map->pm_count == map->pm_size)
    {
      map_resize (map_ret, PM_SIZE (map->pm_size));
      map = *map_ret;
    }

  if (ct > PM_MAX_ENTRIES - 1)
    GPF_T1 ("Exceeded max entries in page map");
  if (at == 0 || ct == 0)
    {

      map->pm_entries[ct] = what;
      map->pm_count = ct + 1;
      if (ct)
	return (map->pm_entries[ct - 1]);
      else
	return 0;
    }
  else
    {
      for (inx = 0; inx < ct; inx++)
	{
	  tmp = map->pm_entries[inx];
	  if (tmp == at)
	    {

	      memmove (&map->pm_entries[inx + 1], &map->pm_entries[inx],
		  sizeof (short) * (ct - inx));

	      map->pm_count = ct + 1;
	      map->pm_entries[inx] = what;
	      return prev;
	    }
	  prev = tmp;
	}
      GPF_T;			/* Insert point not in the map  */
    }
  /*noreturn */
  return 0;
}



#ifdef MTX_DEBUG
void
ins_leaves_check (buffer_desc_t * buf)
{
  /* see if inserting a leaf on a non leaf page */
  int inx;
  page_map_t * map = buf->bd_content_map;
  for (inx = 0; inx < map->pm_count; inx++)
    {
      key_id_t ki = SHORT_REF (buf->bd_buffer + map->pm_entries[inx] + IE_KEY_ID);
      if (!ki || (KI_LEFT_DUMMY == ki && LONG_REF (buf->bd_buffer + map->pm_entries[inx] +IE_LEAF)))
	{
	  printf ("non leaf\n");
	  break;
	}
    }
}
#endif

int
itc_insert_dv (it_cursor_t * it, buffer_desc_t ** buf_ret, db_buf_t dv,
    int is_recursive, row_lock_t * new_rl)
{
  buffer_desc_t *buf = *buf_ret;
  page_map_t *map = buf->bd_content_map;
  int  len, len_1 = 0, len_2 = 0;
  int pos = it->itc_position, pos_after;
  db_buf_t page = buf->bd_buffer;
  long right_ins = SHORT_REF (page + DP_RIGHT_INSERTS);
  int data_len;
  ITC_LEAVE_MAPS (it);
  buf_set_dirty (*buf_ret);
  if (it->itc_position == 0
      && it->itc_insert_key)
    it->itc_insert_key->key_page_end_inserts++;
  len = row_length (dv, it->itc_insert_key);
  if (INS_DOUBLE_LP == new_rl)
    {
      len_1 = ROW_ALIGN (len);
      len_2 = row_length (dv + len_1, it->itc_insert_key);
      len = len_1 + len_2;
    }
#ifdef MTX_DEBUG
  if (!is_recursive)
    ins_leaves_check (buf);
#endif
  if (len > MAX_ROW_BYTES
      + 2 /* GK: this is needed bacause there may be upgrade rows in rfwd */)

    GPF_T1 ("max row length exceeded in itc_insert_dv");

  data_len = ROW_ALIGN (len);

  if (PAGE_SZ - map->pm_filled_to >= data_len)
    {
      int ins_pos, first, next_link;
      ins_pos = map->pm_filled_to;
      memcpy (&page[ins_pos], dv, data_len);
      pos_after = map_insert (&buf->bd_content_map, pos, map->pm_filled_to);
      if (len_2)
	{
	  int p_2 = pos_after ? IE_NEXT (page + pos_after) : SHORT_REF (page + DP_FIRST);
	  map_insert (&buf->bd_content_map, p_2, map->pm_filled_to + len_1);
	  IE_SET_NEXT (page + ins_pos, ins_pos + len_1);
	  next_link = ins_pos + len_1;
	}
      else
	next_link = ins_pos;
      map = buf->bd_content_map;
      map->pm_filled_to += data_len;
      map->pm_bytes_free -= data_len;
      /* Link it. */

      if (pos_after)
	{
	  int next = IE_NEXT (page + pos_after);
	  IE_SET_NEXT (page + next_link, next);
	  IE_SET_NEXT (page + pos_after, ins_pos);

	  if (pos_after != SHORT_REF (page + DP_LAST_INSERT))
	    {
	      mid_inserts++;
	      if (right_inserts > 2)
		SHORT_SET (page + DP_RIGHT_INSERTS, 0);
	    }
	  else
	    {
	      right_inserts++;
	      if (right_ins < 1000)
		SHORT_SET ((page + DP_RIGHT_INSERTS), (short)(right_ins + 1));
	    }
	  SHORT_SET (page + DP_LAST_INSERT, next_link);
	}
      else
	{

	  first = SHORT_REF (page + DP_FIRST);
	  if (first && first != pos)
	    GPF_T;		/*Bad first of page */
	  IE_SET_NEXT (page + next_link, first);
	  SHORT_SET (page + DP_FIRST, ins_pos);
	}

      it->itc_position = ins_pos;
      ITC_IN_KNOWN_MAP (it, it->itc_page);
      itc_keep_together (it, buf, buf, NULL, 0);
      if (new_rl && INS_DOUBLE_LP != new_rl)
	itc_insert_rl (it, buf, ins_pos, new_rl, RL_ESCALATE_OK);
      ITC_LEAVE_MAPS (it);
      pg_check_map (buf);
      if (ins_pos == SHORT_REF (buf->bd_buffer + DP_FIRST)
	  && (!new_rl || INS_NEW_RL == new_rl || INS_DOUBLE_LP == new_rl))
	{
	  itc_fix_leaf_ptr (it, buf);
	  return 1;
	}
      ITC_IN_KNOWN_MAP (it, it->itc_page);
      buf_set_dirty_inside (buf);
      page_mark_change (*buf_ret, RWG_WAIT_KEY);
      itc_page_leave (it, *buf_ret);
      return 1;
    }

  /* No contiguous space. See if we compact this or split */

  if (data_len <= map->pm_bytes_free)
    {
      /* No split, compress. */
      int is_first = it->itc_position == SHORT_REF (buf->bd_buffer + DP_FIRST) 
	&& (INS_NEW_RL == new_rl || INS_DOUBLE_LP == new_rl);
      pg_check_map (buf);
      pg_write_compact (it, buf, it->itc_position, dv, PAGE_SZ, NULL, 0, new_rl);
      pg_check_map (buf);
      if (is_first)
	{
	  itc_fix_leaf_ptr (it, buf);
	  return 1;
	}
      ITC_IN_KNOWN_MAP (it, it->itc_page);
      page_mark_change (*buf_ret, RWG_WAIT_KEY);
      itc_page_leave (it, buf);
      return 1;
    }
  /* Time to split */
  if (!is_recursive)
    itc_hold_pages (it, buf, DP_INSERT_RESERVE);
  itc_split (it, buf_ret, dv, new_rl);
  if (!is_recursive)
    itc_free_hold (it);
  return 1;
}


/*
   The top level API for inserting an entry. The entry is a regular index
   entry. */

int
itc_insert_unq_ck (it_cursor_t * it, db_buf_t thing, buffer_desc_t ** unq_buf)
{
  row_lock_t * rl_flag = KI_TEMP != it->itc_insert_key->key_id  ? INS_NEW_RL : NULL;
  int res, was_allowed_duplicate = 0;
  buffer_desc_t *buf;

  FAILCK (it);

  if (it->itc_insert_key)
    {
      if (it->itc_insert_key->key_table && it->itc_insert_key->key_is_primary)
	it->itc_insert_key->key_table->tb_count_delta++;
      it->itc_key_id = it->itc_insert_key->key_id;
      /* for key access statistics */
    }
  it->itc_row_key = it->itc_insert_key;
  it->itc_lock_mode = PL_EXCLUSIVE;
  if (SM_INSERT_AFTER == it->itc_search_mode || SM_INSERT_BEFORE == it->itc_search_mode)
    {
      GPF_T1 ("positioned insert is not enabled");
      buf = *unq_buf;
      if (SM_INSERT_AFTER == it->itc_search_mode)
	res = DVC_LESS;
      else
	res = DVC_GREATER;
      goto searched;
    }
  it->itc_search_mode = SM_INSERT;
 reset_search:
  buf = itc_reset (it);
  res = itc_search (it, &buf);
 searched:
  if (NO_WAIT != itc_insert_lock (it, buf, &res))
    goto reset_search;
 re_insert:
  if (BUF_NEEDS_DELTA (buf))
    {
      ITC_IN_KNOWN_MAP (it, it->itc_page);
      itc_delta_this_buffer (it, buf, DELTA_MAY_LEAVE);
      ITC_LEAVE_MAP_NC (it);
    }
  if (!buf->bd_is_write)
    GPF_T1 ("insert and no write access to buffer");
  switch (res)
    {
    case DVC_INDEX_END:
    case DVC_LESS:
      /* Insert at leaf end. The cursor's position is perfect. */
      itc_skip_entry (it, buf->bd_buffer);
      ITC_AGE_TRX (it, 2);
      itc_insert_dv (it, &buf, thing, 0, rl_flag);
      break;

    case DVC_GREATER:
      /* Before the thing that is at cursor */

      ITC_AGE_TRX (it, 2);
      itc_insert_dv (it, &buf, thing, 0, rl_flag);
      break;

    case DVC_MATCH:

      if (!itc_check_ins_deleted (it, buf, thing))
	{
	  if (unq_buf == UNQ_ALLOW_DUPLICATES || unq_buf == UNQ_SORT)
	    {
	      if (!was_allowed_duplicate && UNQ_SORT == unq_buf)
		{
		  itc_page_leave (it, buf);
		  was_allowed_duplicate = 1;
		  it->itc_search_mode = SM_READ;
		  it->itc_desc_order = 1;
		  goto reset_search;
		}
	      res = DVC_LESS;
	      goto re_insert;
	    }
	  rdbg_printf (("  Non-unq insert T=%d on L=%d pos=%d \n", TRX_NO (it->itc_ltrx), buf->bd_page, it->itc_position));
	  if (unq_buf)
	    {
	      *unq_buf = buf;
	      it->itc_is_on_row = 1;
	      return DVC_MATCH;
	    }
	  if (it->itc_ltrx)
	    {
	      if (it->itc_insert_key)
		{
		  caddr_t detail = dk_alloc_box (50 + MAX_NAME_LEN + MAX_QUAL_NAME_LEN, DV_SHORT_STRING);
		  snprintf (detail, box_length (detail) - 1,
		      "Violating unique index %.*s on table %.*s",
		      MAX_NAME_LEN, it->itc_insert_key->key_name,
		      MAX_QUAL_NAME_LEN, it->itc_insert_key->key_table->tb_name);
		  LT_ERROR_DETAIL_SET (it->itc_ltrx, detail);
		}
	      it->itc_ltrx->lt_error = LTE_UNIQ;
	    }
	  itc_bust_this_trx (it, &buf, ITC_BUST_THROW);
	}
      break;
    default:
      GPF_T1 ("Bad search result in insert");
    }
  KEY_TOUCH (it->itc_insert_key);
  ITC_LEAVE_MAPS (it);
  if (KI_TEMP != it->itc_insert_key->key_id)
    {
      lt_rb_insert (it->itc_ltrx, thing);
    }
  if (was_allowed_duplicate)
    return DVC_MATCH;
  return DVC_LESS;		/* insert OK, no duplicate. */
}


db_buf_t
strses_to_db_buf (dk_session_t * ses)
{
  long length = strses_length (ses);
  db_buf_t buffer;
  if (length < 256)
    {
      buffer = (db_buf_t) dk_alloc ((int) length + 2);
      buffer[0] = DV_SHORT_CONT_STRING;
      buffer[1] = (unsigned char) length;
      strses_to_array (ses, (char *) &buffer[2]);
    }
  else
    {
      buffer = (db_buf_t) dk_alloc ((int) length + 5);
      buffer[0] = DV_LONG_CONT_STRING;
      buffer[1] = (dtp_t) (length >> 24);
      buffer[2] = (dtp_t) (length >> 16);
      buffer[3] = (dtp_t) (length >> 8);
      buffer[4] = (dtp_t) length;
      strses_to_array (ses, (char *) &buffer[5]);
    }
  return buffer;
}


int
map_delete (page_map_t ** map_ret, int pos)
{
  page_map_t * map = *map_ret;
  int inx, prev_pos = 0, sz;
  for (inx = 0; inx < map->pm_count; inx++)
    {
      int ent = map->pm_entries[inx];
      if (ent == pos)
	{
	  for (inx = inx; inx < map->pm_count - 1; inx++)
	    {
	      map->pm_entries[inx] = map->pm_entries[inx + 1];
	    }
	  map->pm_count--;
	  sz = PM_SIZE (map->pm_count);
	  if (sz < map->pm_size && map->pm_count < ((sz / 10) * 8))
	    map_resize (map_ret, sz);
	  return prev_pos;
	}
      prev_pos = ent;
    }
  GPF_T;			/* Entry to delete not in the map */
  return 0;
}


#define ITC_ID_TO_KEY(itc, key_id) \
  itc->itc_row_key


void
itc_delete_blobs (it_cursor_t * itc, db_buf_t page)
{
  /* do a round of the row map and delete if you see a blob */
  long pos = itc->itc_position;
  dbe_key_t * key = itc->itc_row_key;
  itc->itc_insert_key = key;
  itc->itc_row_data = page + pos + IE_FIRST_KEY;
  if (key && key->key_row_var)
    {
      int inx;
      for (inx = 0; key->key_row_var[inx].cl_col_id; inx++)
	{
	  dbe_col_loc_t * cl = &key->key_row_var[inx];
	  dtp_t dtp = cl->cl_sqt.sqt_dtp;
	  if (IS_BLOB_DTP (dtp)
	      && 0 == (itc->itc_row_data[cl->cl_null_flag] & cl->cl_null_mask))
	    {
	      int off, len;
	      ITC_COL (itc, (*cl), off, len);
	      dtp = itc->itc_row_data[off];
	      if (IS_BLOB_DTP (dtp))
		{

		  blob_layout_t * bl = bl_from_dv (itc->itc_row_data + off, itc);
		  blob_log_replace (itc, bl);
		  blob_schedule_delayed_delete (itc,
						bl,
						BL_DELETE_AT_COMMIT );
		  /* do not log the del'd blob if it was written by this trx. */
		}
	    }
	}
    }
}


void
itc_immediate_delete_blobs (it_cursor_t * itc, buffer_desc_t * buf)
{
  /* do a round of the row map and delete if you see a blob */
  db_buf_t page = buf->bd_buffer;
  long pos = itc->itc_position;
#if 0
  key_id_t key_id = SHORT_REF (page + pos + IE_KEY_ID);
#endif
  dbe_key_t * key = ITC_ID_TO_KEY (itc, key_id);
  if (key && key->key_row_var)
    {
      int inx;
      for (inx = 0; key->key_row_var[inx].cl_col_id; inx++)
	{
	  dbe_col_loc_t * cl = &key->key_row_var[inx];
	  dtp_t dtp = cl->cl_sqt.sqt_dtp;
	  if (IS_BLOB_DTP (dtp)
	      && 0 == (itc->itc_row_data[cl->cl_null_flag] & cl->cl_null_mask))
	    {
	      int off, len;
	      ITC_COL (itc, (*cl), off, len)
		dtp = page [pos + off];
	      if (IS_BLOB_DTP (dtp))
		{
		  blob_chain_delete (itc, bl_from_dv (page + pos, itc));
		}
	    }
	}
    }
}



void
itc_delete_as_excl (it_cursor_t * itc, buffer_desc_t ** buf_ret, int maybe_blobs)
{
  /* in drop table, no rb possible etc. */
  buffer_desc_t * buf = *buf_ret;
  db_buf_t page = buf->bd_buffer;
  if (!buf->bd_is_write)
    GPF_T1 ("Delete w/o write access");
  ITC_IN_KNOWN_MAP (itc, itc->itc_page);
  itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE);
  ITC_LEAVE_MAP_NC (itc);

  if (!itc->itc_no_bitmap && itc->itc_insert_key && itc->itc_insert_key->key_is_bitmap)
    {
      if (BM_DEL_DONE == itc_bm_delete (itc, buf_ret))
	return;
    }
  if (maybe_blobs)
    {
      itc_delete_blobs (itc, page);
    }
  itc_commit_delete (itc, buf_ret);
}


void
itc_delete (it_cursor_t * itc, buffer_desc_t ** buf_ret, int maybe_blobs)
{
  int pos = itc->itc_position;
  buffer_desc_t * buf = *buf_ret;
  db_buf_t page = buf->bd_buffer;
  if (itc->itc_ltrx->lt_is_excl)
    {
      itc_delete_as_excl (itc, buf_ret, maybe_blobs);
      return;
    }
  if (!buf->bd_is_write)
    GPF_T1 ("Delete w/o write access");
  if (!ITC_IS_LTRX (itc))
    GPF_T1 ("itc_delete outside of commit space");
  if (BUF_NEEDS_DELTA (buf))
    {
      ITC_IN_KNOWN_MAP (itc, itc->itc_page);
      itc_delta_this_buffer (itc, buf, DELTA_MAY_LEAVE);
      ITC_LEAVE_MAP_NC (itc);
    }
  lt_rb_update (itc->itc_ltrx, page + pos);
  if (!itc->itc_no_bitmap && itc->itc_insert_key->key_is_bitmap)
    {
      if (BM_DEL_DONE == itc_bm_delete (itc, buf_ret))
	return;
    }
  pl_set_finalize (itc->itc_pl, buf);
  itc->itc_is_on_row = 0;
  if (IE_ISSET (page + pos, IEF_DELETE))
    {
      /* multiple delete possible if several cr's first on row and then do co */
      TC (tc_double_deletes);
    }
  IE_ADD_FLAGS (page + pos, IEF_DELETE);
  ITC_AGE_TRX (itc, 2);
  if (maybe_blobs)
    {
      itc_delete_blobs (itc, page);
    }
}


void
itc_delete_rl_bust (it_cursor_t * itc, int pos)
{
  page_lock_t * pl = itc->itc_pl;
  row_lock_t * rl;
  if (!pl)
    return;
  rl = pl_row_lock_at (itc->itc_pl, pos);
  if (rl)
    rl->rl_pos = 0;
}


long delete_parent_waits;

#ifdef PAGE_TRACE
#define rdbg_printf_m(a) printf a
#else
#define rdbg_printf_m(a)
#endif

int
page_unlink_row (buffer_desc_t * buf, int pos, int * pos_after)
{
  int was_first_lp = 0;
  db_buf_t page = buf->bd_buffer;
  int len = row_reserved_length (page + pos, buf->bd_tree->it_key);
  int prev_pos = map_delete (&buf->bd_content_map, pos);
  page_map_t * map = buf->bd_content_map;
  int new_pos = IE_NEXT (page + pos);
  if (pos_after)
    *pos_after = new_pos;
  if (prev_pos)
    {
      IE_SET_NEXT (page + prev_pos, new_pos);
    }
  else
    {
      if (0 == SHORT_REF (page + pos + IE_KEY_ID))
	was_first_lp = 1;
      SHORT_SET (page + DP_FIRST, new_pos);
    }
  map->pm_bytes_free += ROW_ALIGN (len);
  return was_first_lp;
}


void
itc_fix_leaf_ptr (it_cursor_t * itc, buffer_desc_t * buf)
{
  buffer_desc_t * parent;
  db_buf_t lp;
  dp_addr_t dp_from = buf->bd_page;
  int first = SHORT_REF (buf->bd_buffer + DP_FIRST), pos;
  if (!LONG_REF (buf->bd_buffer + DP_PARENT))
    {
      page_leave_outside_map (buf);
      return;
    }
  TC (tc_fix_outdated_leaf_ptr);
  lp = itc_make_leaf_entry (itc, buf->bd_buffer + first, dp_from);
  parent =   itc_write_parent (itc, buf);
  ITC_IN_KNOWN_MAP (itc, buf->bd_page);
  page_mark_change (buf, RWG_WAIT_SPLIT);
  page_leave_inner (buf);
  ITC_LEAVE_MAP_NC (itc);
  if (!parent)
    return;
  pos = find_leaf_pointer (parent, dp_from, NULL, NULL);
  if (pos <= 0)
    GPF_T1 ("can't find leaf ptr in fix of outdated leaf ptr");
  itc->itc_position = pos;
  itc->itc_page = parent->bd_page;
  ITC_SAVE_FAIL (itc);
  ITC_FAIL (itc)
    {
      itc->itc_row_key = itc->itc_insert_key;
      itc->itc_position = pos;
      upd_refit_row (itc, &parent, lp);
    }
  ITC_FAILED
    {
      log_info ("A delete of first row failed updating the parent probably because of would split and could not get guaranteed space to split.  This is not very dangerous");
      goto after_fail;
    }
  END_FAIL (itc);
  ITC_RESTORE_FAIL (itc);
 after_fail:
  dk_free_box ((box_t) lp);
}


int
itc_delete_single_leaf (it_cursor_t * itc, buffer_desc_t ** buf_ret)
{
  buffer_desc_t * buf = *buf_ret;
  db_buf_t page = buf->bd_buffer;
  dp_addr_t leaf = 0, old_dp;
  if (buf->bd_content_map->pm_count == 1)
    {
      int pos = buf->bd_content_map->pm_entries[0];
      key_id_t key_id = SHORT_REF (page + pos + IE_KEY_ID);
      if (0 == key_id || KI_LEFT_DUMMY == key_id)
	leaf = LONG_REF (page + pos + IE_LEAF);
      if (!leaf)
	return 0;
      /*page consists of a single leaf pointer.  Set tree root or go change the leaf pointer on parent */
      {
	dp_addr_t old_leaf = buf->bd_page;
	buffer_desc_t *old_buf = buf;
	buffer_desc_t *parent;
	db_buf_t lp;
	placeholder_t * pl;
	old_dp = old_buf->bd_page;
	parent = itc_write_parent (itc, buf);
	if (!parent)
	      {
		buffer_desc_t * leaf_buf;
		/* The page w/ the single leaf is the root */
	    itc_set_parent_link (itc, leaf, 0);
		    
		rdbg_printf_m (("Single leaf root popped old root L=%ld new root L=%ld \n", (long)(buf->bd_page), (long)leaf));
	    ITC_IN_KNOWN_MAP (itc, leaf);
	    itc->itc_tree->it_root = leaf;
	    page_wait_access (itc, leaf, NULL, &leaf_buf, PA_WRITE, RWG_WAIT_ANY);
	    pg_delete_move_cursors (itc, buf, 0,
				    leaf_buf, SHORT_REF (leaf_buf->bd_buffer + DP_FIRST));
	    page_leave_outside_map (leaf_buf);
	    ITC_IN_KNOWN_MAP (itc, buf->bd_page);
	    it_free_page (itc->itc_tree, buf);
	    ITC_LEAVE_MAPS (itc);
		do
		  {
		ITC_IN_VOLATILE_MAP (itc, itc->itc_tree->it_root);
		page_wait_access (itc, itc->itc_tree->it_root, NULL, buf_ret, PA_WRITE, RWG_WAIT_SPLIT);
		  } while (itc->itc_to_reset >= RWG_WAIT_SPLIT);
		itc->itc_page = (*buf_ret)->bd_page;
	    ITC_LEAVE_MAPS (itc);
		return 1;
	      }
	buf = parent;
	itc->itc_page = buf->bd_page;
	pos = find_leaf_pointer (buf, old_leaf, NULL, NULL);
	if (pos <= 0)
	  GPF_T1 ("No leaf in super noted in popping a single child non-leaf");
	itc->itc_position = pos;
	itc->itc_is_on_row = 1;
	pl = plh_landed_copy ((placeholder_t *) itc, buf);

	ITC_IN_TRANSIT (itc, old_buf->bd_page, parent->bd_page);
	pg_delete_move_cursors (itc, old_buf, 0,
				buf, pos);

	page_mark_change (old_buf, RWG_WAIT_SPLIT);
	pl_page_deleted (IT_DP_PL (itc->itc_tree, old_buf->bd_page), old_buf);
	ITC_LEAVE_MAPS (itc);
	lp = itc_make_leaf_entry (itc, old_buf->bd_buffer + SHORT_REF (old_buf->bd_buffer + DP_FIRST), leaf);
	itc_set_parent_link (itc, leaf, buf->bd_page);
	ITC_IN_KNOWN_MAP (itc, old_buf->bd_page);
	it_free_page (itc->itc_tree, old_buf); /*incl. leave buffer */
	ITC_LEAVE_MAPS (itc);
	upd_refit_row (itc, &buf, lp);
	rdbg_printf_m ((" Single child page L=%ld popped parent L=%ld leaf L=%ld \n", (long)old_dp, (long)(buf->bd_page), (long)leaf));
	dk_free_box ((caddr_t)lp);
	*buf_ret = itc_set_by_placeholder (itc, pl);
	itc_unregister_inner ((it_cursor_t *) pl, *buf_ret, 0);
	plh_free (pl);
	return 1;
      }
    }
  return 0;
}


int
itc_commit_delete (it_cursor_t * it, buffer_desc_t ** buf_ret)
{
  /* Delete whatever the cursor is on. The cursor will be at the next entry */

  buffer_desc_t *buf = *buf_ret;
  long len;
  db_buf_t page;
  page_map_t *map;
  int pos, prev_pos = 0, new_pos, was_first_lp;

  if (!buf->bd_is_write)
    GPF_T;			/* Delete when cursor not on row */

delete_from_cursor:
  map = buf->bd_content_map;
  page = buf->bd_buffer;
  pos = it->itc_position;

  was_first_lp = 0;
  len = row_reserved_length (page + pos, buf->bd_tree->it_key);
  prev_pos = map_delete (&buf->bd_content_map, pos);
  map = buf->bd_content_map;
  new_pos = IE_NEXT (page + pos);
  if (prev_pos)
    {
      IE_SET_NEXT (page + prev_pos, new_pos);
    }
  else
    {
      if (0 == SHORT_REF (page + pos + IE_KEY_ID))
	was_first_lp = 1;
      SHORT_SET (page + DP_FIRST, new_pos);
    }

  if (!buf->bd_is_dirty)
    {
      ITC_LEAVE_MAPS (it);
      buf_set_dirty (buf);
    }
  pg_delete_move_cursors (it, buf, it->itc_position,
			  NULL, new_pos);
  it->itc_position = new_pos;
  map->pm_bytes_free += (short) ROW_ALIGN (len);
  if (map->pm_bytes_free > (PAGE_DATA_SZ * 2) / 3)  /* if less than 2/3 full */
    dp_may_compact ((*buf_ret)->bd_storage, LONG_REF ((*buf_ret)->bd_buffer + DP_PARENT));
  if (itc_delete_single_leaf (it, buf_ret))
    return DVC_MATCH;
  if (0 == SHORT_REF (page + DP_FIRST))
    {
      dp_addr_t old_leaf = buf->bd_page;
      buffer_desc_t *old_buf = buf;
      buffer_desc_t *parent;
      if (map->pm_bytes_free != PAGE_SZ - DP_DATA)
	GPF_T;			/* Bad free count */
      rdbg_printf_2 (("    Deleting page L=%d\n", old_buf->bd_page));
      parent = itc_write_parent (it, buf);
      
      if (!parent)
	    {
	      /* The root went empty */
	      pg_map_clear (buf);
	      *buf_ret = buf;
	      *buf_ret = buf;
	  ITC_LEAVE_MAPS (it);
	      return DVC_MATCH;
	    }
      buf = parent;
      it->itc_page = buf->bd_page;
      pos = find_leaf_pointer (buf, old_leaf, NULL, NULL);
      if (pos <= 0)
	GPF_T;			/* No leaf pointer in parent in delete */
      it->itc_position = pos;
      it->itc_is_on_row = 1;

      /* The cursor is now in on the parent. Delete on away. */
      ITC_IN_TRANSIT (it, old_buf->bd_page, buf->bd_page);
      pg_delete_move_cursors (it, old_buf, 0,
	  buf, pos);

      pl_page_deleted (IT_DP_PL (it->itc_tree, old_buf->bd_page), old_buf);
      itc_delta_this_buffer (it, buf, DELTA_MAY_LEAVE);
      ITC_LEAVE_MAPS (it);
      DBG_PT_PRINTF (("  Found leaf ptr for delete of L=%d on L=%d \n", old_buf->bd_page, buf->bd_page));
      ITC_IN_KNOWN_MAP (it, old_buf->bd_page);
      /* Note that it_free_page must be called when holding exactly one map, not while holding transit.  If this results in cancelling a write, the write cancel can deadlock if this thread holds an extra map mtx */
      page_mark_change (old_buf, RWG_WAIT_SPLIT);
      it_free_page (it->itc_tree, old_buf); /*incl. leave buffer */
      ITC_LEAVE_MAP_NC (it);
      *buf_ret = buf;
      goto delete_from_cursor;
    }
  itc_delete_rl_bust (it, pos);
  *buf_ret = buf;
  if (was_first_lp)
    {
      placeholder_t * pl = plh_landed_copy ((placeholder_t *)it, buf);
      itc_fix_leaf_ptr (it, buf);
      *buf_ret = itc_set_by_placeholder (it, pl);
      itc_unregister_inner ((it_cursor_t *) pl, *buf_ret, 0);
      plh_free (pl);
    }
  return DVC_MATCH;
}




dp_addr_t
ie_leaf (db_buf_t row)
{
  key_id_t k = SHORT_REF (row + IE_KEY_ID);
  if (!k || KI_LEFT_DUMMY == k)
    return LONG_REF (row + IE_LEAF);
  else
    return 0;
}

typedef struct page_rel_s
{
  short		pr_lp_pos;
  dp_addr_t	pr_dp;
  buffer_desc_t *	pr_buf;
  short		pr_old_fill;
  short 		pr_new_fill;
  short		pr_old_lp_len;
  short		pr_new_lp_len;
  short		pr_deleted;
  buffer_desc_t *	pr_new_buf;
  db_buf_t		pr_leaf_ptr;
} page_rel_t;

#define MAX_CP_BATCH (PAGE_DATA_SZ / 12)
#define CP_CHANGED 2
#define CP_STILL_INSIDE 1
#define CP_REENTER 0


#define START_PAGE(pr) \
{  \
  prev_ent = 0; \
  pg_fill = DP_DATA; \
  pr->pr_new_buf = buffer_allocate (DPF_INDEX); \
  page_to = pr->pr_new_buf->bd_buffer; \
}


#ifdef MTX_DEBUG
#define cmp_printf(a) printf a
#else
#define cmp_printf(a)
#endif

int
it_compact (index_tree_t *it, buffer_desc_t * parent2, page_rel_t * pr, int pr_fill, int target_fill, int *pos_ret)
{
  /* the pr's are filled, move the data */
  it_cursor_t itc_auto;
  page_map_t * pm;
  it_cursor_t * itc = NULL;
  page_rel_t * target_pr;
  db_buf_t page_to;
  buffer_desc_t * volatile parent = parent2;
  int n_target_pages, pg_fill, n_del = 0, n_ins = 0, n_leaves = 0;
  int prev_ent = 0, org_count = parent->bd_content_map->pm_count;
  int inx, first_after, first_lp_inx = 0;
  target_pr = &pr[0];
  n_target_pages = 1;
  START_PAGE (target_pr);
  for (inx = 0; inx < pr_fill; inx++)
    {
      buffer_desc_t * buf = pr[inx].pr_buf;
      db_buf_t page = buf->bd_buffer;
      int pos = SHORT_REF (buf->bd_buffer + DP_FIRST);
      if (!pr[inx].pr_deleted)
	n_ins++;
      else
	n_del++;
      while (pos)
	{
	  int len = ROW_ALIGN (row_length (page + pos, it->it_key));
	  if (pg_fill + len < target_fill)
	    {
	      memcpy (page_to + pg_fill, buf->bd_buffer + pos, len);
	      LINK_PREV (pg_fill);
	      pg_fill += len;
	      pos = IE_NEXT (page + pos);
	      continue;
	    }
	  if (pg_fill < target_fill && pg_fill + len < PAGE_SZ)
	    {
	      memcpy (page_to + pg_fill, buf->bd_buffer + pos, len);
	      LINK_PREV (pg_fill);
	      pg_fill += len;
	      pos = IE_NEXT (page + pos);
	      continue;
	    }
	  if (pg_fill != target_pr->pr_new_fill)
	    GPF_T1 ("different page fills in compact check and actual compact");
	  target_pr++;
	  START_PAGE (target_pr);
	  memcpy (page_to + pg_fill, buf->bd_buffer + pos, len);
	  LINK_PREV (pg_fill);
	  pg_fill += len;
	  pos = IE_NEXT (page + pos);
	}
    }
  if (pg_fill != target_pr->pr_new_fill)
    GPF_T1 ("different page fills on compact check and compact");
  /* update the leaf pointers on the parent page */
  pm = parent->bd_content_map;
  for (inx = 0; inx < pm->pm_count; inx++)
    {
      if (pm->pm_entries[inx] == pr[0].pr_lp_pos)
	{
	  first_lp_inx = inx;
	  break;
	}
    }
  if (0 == first_lp_inx)
    SHORT_SET (parent->bd_buffer + DP_FIRST, IE_NEXT (parent->bd_buffer + pr[pr_fill-1].pr_lp_pos));
  else
    IE_SET_NEXT (parent->bd_buffer + pm->pm_entries[first_lp_inx - 1], IE_NEXT (parent->bd_buffer + pr[pr_fill-1].pr_lp_pos));
  itc = &itc_auto;
  ITC_INIT (itc, NULL, NULL);
  itc_from_it (itc, it);
  {
    int dp_first = SHORT_REF (parent->bd_buffer + DP_FIRST);
    int pos = dp_first;
    int new_count = 0;
    while (pos)
      {
	new_count++;
	pos = IE_NEXT (parent->bd_buffer + pos);
      }
    if (org_count - pr_fill != new_count)
      GPF_T1 ("bad unlink of compacted in compact");
    pg_write_compact (itc, parent, -1, NULL,  0, WRITE_NO_GAP, 0, NULL);
    /* if the page is empty, pg_write_compact erroneously puts 20 as the first row instead of 0 */
    if (!dp_first)
      SHORT_SET (parent->bd_buffer + DP_FIRST, 0);
    pg_make_map (parent);
    if (parent->bd_content_map->pm_count != org_count - pr_fill)
      GPF_T1 ("bad quantity deleted from the parent map in compact");
  }
  pm = parent->bd_content_map;
  page_to = parent->bd_buffer;
  prev_ent = first_lp_inx ? pm->pm_entries[first_lp_inx - 1] : 0;
  first_after= prev_ent ? IE_NEXT (parent->bd_buffer + prev_ent) : SHORT_REF (parent->bd_buffer + DP_FIRST);
  pg_fill = ROW_ALIGN (pm->pm_filled_to);
  for (inx = 0; inx < pr_fill; inx++)
    {
      if (pr[inx].pr_deleted)
	break;
      memcpy (page_to + pg_fill, pr[inx].pr_leaf_ptr, pr[inx].pr_new_lp_len);
      LINK_PREV_NC (pg_fill);
      pg_fill += pr[inx].pr_new_lp_len;
    }
  IE_SET_NEXT (parent->bd_buffer + prev_ent, first_after);
  *pos_ret = prev_ent;
  pg_make_map (parent);
  /* delete the pages that are not needed */
	  for (inx = 0; inx < pr_fill; inx++)
    {
      buffer_desc_t * buf = pr[inx].pr_buf;
      itc->itc_page = buf->bd_page;
      ITC_IN_OWN_MAP (itc);
      itc_delta_this_buffer (itc, buf, DELTA_STAY_INSIDE);
      if (pr[inx].pr_deleted)
	{
	  rdbg_printf_2 (("D=%d ", pr[inx].pr_buf->bd_page));
	  it_free_page (it, pr[inx].pr_buf);
	}
      else
	{
	  rdbg_printf_2 (("W=%d ", pr[inx].pr_buf->bd_page));
		  	  memcpy (pr[inx].pr_buf->bd_buffer + DP_DATA, pr[inx].pr_new_buf->bd_buffer + DP_DATA, pr[inx].pr_new_fill - DP_DATA);
	  SHORT_SET (pr[inx].pr_buf->bd_buffer + DP_FIRST, SHORT_REF (pr[inx].pr_new_buf->bd_buffer + DP_FIRST));
	  pg_make_map (pr[inx].pr_buf);
	  n_leaves += pr[inx].pr_buf->bd_content_map->pm_count;
	  ITC_IN_KNOWN_MAP (itc, pr[inx].pr_buf->bd_page)
	  page_mark_change (pr[inx].pr_buf, RWG_WAIT_SPLIT);
	  page_leave_inner (pr[inx].pr_buf);
	}
      ITC_LEAVE_MAP_NC (itc);
    }
  itc->itc_page = parent->bd_page;
  ITC_IN_OWN_MAP (itc);
  itc_delta_this_buffer (itc, parent, DELTA_STAY_INSIDE);
  page_mark_change (parent, RWG_WAIT_SPLIT);
  ITC_LEAVE_MAP_NC (itc);
  cmp_printf (("  Compacted %d pages to %d under %ld first =%d, org count=%d\n", pr_fill, pr_fill - n_del, parent->bd_page, first_lp_inx, org_count));
  if (parent->bd_content_map->pm_count != org_count - n_del )
    GPF_T1 ("mismatch of leaves before and after compact");
  return n_leaves;
}

void
pr_free (page_rel_t * pr, int pr_fill, int leave_bufs)
{
  int inx;
  for (inx = 0; inx < pr_fill; inx++)
    {
      dk_free_box (pr[inx].pr_leaf_ptr);
      buffer_free (pr[inx].pr_new_buf);
      if (leave_bufs)
	page_leave_outside_map (pr[inx].pr_buf);
    }
}


extern long ac_pages_in;
extern long ac_pages_out;
extern long ac_n_busy;




int
it_try_compact (index_tree_t *it, buffer_desc_t * parent, page_rel_t * pr, int pr_fill, int * pos_ret, int mode)
{
  /* look at the pr's and see if can rearrange so as to save one or more pages.
   * if so, verify the rearrange and update the pr array. */
  it_cursor_t itc_auto;
  it_cursor_t * itc = NULL;
  page_rel_t * target_pr;
  int total_fill = 0, n_target_pages, pg_fill, n_leaves = 0, n_leaves_2;
  int olp_sum = 0, nlp_sum = 0;
  int target_fill, est_res_pages;
  int inx;
  int n_source_pages = 0;
  for (inx = 0; inx < pr_fill; inx++)
    {
      page_map_t * pm =  pr[inx].pr_buf->bd_content_map;
      int dp_fill = PAGE_DATA_SZ - pm->pm_bytes_free;
      total_fill += dp_fill;
      n_source_pages++;
    }
  est_res_pages = ((total_fill + (total_fill / 12)) / PAGE_DATA_SZ) + 1;
  if (est_res_pages>= n_source_pages)
    {
    return CP_STILL_INSIDE;
    }
  for (inx = 0; inx < pr_fill; inx++)
    {
      n_leaves += pr[inx].pr_buf->bd_content_map->pm_count;
    }
  /* could be savings.  Make precise relocation calculations */
  target_fill = MIN (PAGE_SZ, DP_DATA + (total_fill / est_res_pages));
  target_pr = &pr[0];
  n_target_pages = 1;
  pg_fill = DP_DATA;
  itc = &itc_auto;
  ITC_INIT (itc, NULL, NULL);
  itc_from_it (itc, it);

  for (inx = 0; inx < pr_fill; inx++)
    {
      buffer_desc_t * buf = pr[inx].pr_buf;
      db_buf_t page = buf->bd_buffer;
      int pos = SHORT_REF (buf->bd_buffer + DP_FIRST);
      if (!pos)
	{
	  log_error ("Unexpected empty db %d in compact", buf->bd_page);
	  return CP_REENTER;
	}
      if (0 == inx)
	{
	  target_pr->pr_leaf_ptr = itc_make_leaf_entry (itc, page+pos, target_pr->pr_dp);
	  target_pr->pr_new_lp_len = ROW_ALIGN (box_length (target_pr->pr_leaf_ptr));
	}
      while (pos)
	{
	  dp_addr_t leaf = ie_leaf (page + pos);
	  int len = ROW_ALIGN (row_length (page + pos, it->it_key));
	  if (leaf)
	    return CP_REENTER; /* do not compact inner pages, would have to relocate parent dp's of children  */
	  if (pg_fill + len < target_fill)
	    {
	      pg_fill += len;
	      pos = IE_NEXT (page + pos);
	      continue;
	    }
	  if (pg_fill < target_fill && pg_fill + len < PAGE_SZ)
	    {
	      pg_fill += len;
	      pos = IE_NEXT (page + pos);
	      continue;
	    }
	  target_pr->pr_new_fill = pg_fill;
	  if (++n_target_pages == pr_fill)
	    return CP_REENTER; /* as many pages in result and source */
	  target_pr++;
	  pg_fill = DP_DATA + len;
	  target_pr->pr_leaf_ptr = itc_make_leaf_entry (itc, page+pos, target_pr->pr_dp);
	  target_pr->pr_new_lp_len = ROW_ALIGN (box_length (target_pr->pr_leaf_ptr));
	  pos = IE_NEXT (page + pos);
	}
    }
  target_pr->pr_new_fill = pg_fill;
  for (inx = 0; inx < pr_fill; inx++)
    {
      nlp_sum += pr[inx].pr_new_lp_len;
      olp_sum += pr[inx].pr_old_lp_len;
    }
  if (nlp_sum - olp_sum >= ROW_ALIGN (parent->bd_content_map->pm_bytes_free))
    {
      /*fprintf (stderr, "nlp_sum - olp_sum > pm_bytes_free\n", nlp_sum, olp_sum, ROW_ALIGN (parent->bd_content_map->pm_bytes_free)); */
      return CP_REENTER; /* the new leaf pointers would not fit on parent.  Do nothing */
    }

  if (!LONG_REF (parent->bd_buffer + DP_PARENT))
    it_root_image_invalidate (parent->bd_tree);

  /* can compact now.  Will be at least 1 page shorter */
  ac_pages_in += pr_fill;
  ac_pages_out += n_target_pages;
  for (inx = n_target_pages; inx < pr_fill; inx++)
    {
      pr[inx].pr_deleted = 1;
    }
  n_leaves_2 = it_compact (it, parent, pr, pr_fill, target_fill, pos_ret);
  if (n_leaves != n_leaves_2)
    GPF_T1 ("compact ends up with different leaf counts before and after");
  return CP_CHANGED;
}



#define CHECK_COMPACT \
{  \
  if (pr_fill > 1) \
    {\
      compact_rc = it_try_compact (it, parent, pr, pr_fill, &pos, mode);	\
      pr_free (pr, pr_fill, CP_CHANGED != compact_rc); /*if no change, the bufs are still occupied */ \
      if (CP_CHANGED == compact_rc) \
        any_change = CP_CHANGED; \
    } \
  else \
    pr_free (pr, pr_fill, 1);	\
  pr_fill = 0; \
}



#define BUF_COMPACT_ALL_READY(buf, leaf, itm) \
  (buf && !buf->bd_is_write && !buf->bd_readers  \
   && !buf->bd_being_read && !buf->bd_read_waiting && !buf->bd_write_waiting \
   && !buf->bd_registered \
   && !gethash (DP_ADDR2VOID (leaf), &itm->itm_locks))



#define COMPACT_DIRTY 0
#define COMPACT_ALL 1

int
it_cp_check_node (index_tree_t *it, buffer_desc_t *parent, int mode)
{
  it_map_t  * parent_itm;
  page_rel_t pr[MAX_CP_BATCH];
  int pr_fill = 0, pos, any_change = 0, compact_rc;
  db_buf_t page = parent->bd_buffer;
  if (!parent->bd_is_write) GPF_T1 ("compact expects write access");
  if (DPF_INDEX != SHORT_REF (parent->bd_buffer + DP_FLAGS))
    {
      page_leave_outside_map (parent);
      return 0;
    }
  pg_check_map_1 (parent);
  /* loop over present and dirty children, find possible sequences to compact. Rough check first. */
  pos = SHORT_REF (parent->bd_buffer + DP_FIRST);
  while (pos)
    {
      dp_addr_t leaf = ie_leaf (page + pos);
      if (leaf)
	    {
	  it_map_t * itm = IT_DP_MAP (it, leaf);
	  buffer_desc_t * buf;
	  mutex_enter (&itm->itm_mtx);
	  buf = (buffer_desc_t*) gethash ((void*)(ptrlong) leaf, &itm->itm_dp_to_buf);
	  if (BUF_COMPACT_ALL_READY (buf, leaf, itm) 
	       && (COMPACT_ALL == mode ? 1 : buf->bd_is_dirty))
	    {
	      if (mode == COMPACT_DIRTY && !gethash ((void*)(void*)(ptrlong)leaf, &itm->itm_remap))
		GPF_T1 ("In compact, no remap dp for a dirty buffer");
	      BD_SET_IS_WRITE (buf, 1);
	      mutex_leave (&itm->itm_mtx);
	      pg_check_map_1 (buf);
	      memset (&pr[pr_fill], 0, sizeof (page_rel_t));
	      pr[pr_fill].pr_buf = buf;
	      pr[pr_fill].pr_dp = leaf;
	      pr[pr_fill].pr_old_lp_len = ROW_ALIGN(row_length (page + pos, it->it_key));
	      pr[pr_fill].pr_lp_pos = pos;
	      pr_fill++;
	    }
	  else
	    {
	      mutex_leave (&itm->itm_mtx);
	      CHECK_COMPACT;
	    }
	}
      else
	{
	  CHECK_COMPACT;
	}
      if (!pos)
	break;
      pos = IE_NEXT (page + pos);
    }
  CHECK_COMPACT;
  if (CP_CHANGED == any_change)
    parent->bd_is_dirty = 1;
  if (COMPACT_DIRTY == mode)
    {
      parent_itm = IT_DP_MAP (it, parent->bd_page);
      mutex_enter (&parent_itm->itm_mtx);
    page_leave_inner (parent);
      mutex_leave (&parent_itm->itm_mtx);
    }
  return any_change;
}

#define DP_VACUUM_RESERVE ((PAGE_DATA_SZ / 12) + 1) /* max no of leaf pointers + parent */


void
itc_vacuum_compact (it_cursor_t * itc, buffer_desc_t * buf)
{
  /*it_map_t * itm = IT_DP_MAP (itc->itc_tree, itc->itc_page);*/
  if (buf->bd_registered 
      || itc->itc_pl
      || buf->bd_read_waiting || buf->bd_write_waiting)
    {
      return;
    }
  itc_hold_pages (itc, buf, DP_VACUUM_RESERVE);
  ITC_LEAVE_MAPS (itc);
  it_cp_check_node (itc->itc_tree, buf, COMPACT_ALL);
  ITC_LEAVE_MAPS (itc);
  itc_free_hold (itc);
}


dk_hash_t * dp_compact_checked;
dk_mutex_t * dp_compact_mtx;

void
dp_may_compact (dbe_storage_t *dbs, dp_addr_t dp)
{
  mutex_enter (dp_compact_mtx);
  remhash ((void*)(ptrlong)dp, dp_compact_checked);
  mutex_leave (dp_compact_mtx);
}


int
dp_is_compact_checked (dbe_storage_t * dbs, dp_addr_t dp)
{
  int rc;
  mutex_enter (dp_compact_mtx);
  rc = (int)(ptrlong) gethash ((void*)(ptrlong)dp, dp_compact_checked);
  if (!rc)
    sethash ((void*)(ptrlong) dp, dp_compact_checked, (void*) 1);
  mutex_leave (dp_compact_mtx);
  return rc;
}



void
it_check_compact (index_tree_t * it, int age_limit)
{
  int rc, inx;
  dk_hash_t * candidates = hash_table_allocate (101);
  for (inx = 0; inx < IT_N_MAPS; inx++)
    {
      it_map_t * itm = &it->it_maps[inx];
      mutex_enter (&itm->itm_mtx);
      DO_HT (void *, ignore, buffer_desc_t *, buf, &itm->itm_dp_to_buf)
    {
      if (buf->bd_pool && buf->bd_pool->bp_ts - buf->bd_timestamp >= age_limit)
	{
	  dp_addr_t parent_dp = LONG_REF (buf->bd_buffer + DP_PARENT);
	      if (!dp_is_compact_checked (it->it_storage, parent_dp))
		{
		  sethash (DP_ADDR2VOID (parent_dp), candidates, (void*) 1);
		}
		}
	    }
      END_DO_HT;
      mutex_leave (&itm->itm_mtx);
	}

  DO_HT (ptrlong, parent_dp, void *, ignore, candidates)
    {
      buffer_desc_t * parent;
      it_map_t * parent_itm = IT_DP_MAP (it, parent_dp);
      mutex_enter (&parent_itm->itm_mtx);
      parent = (buffer_desc_t *) gethash ((void*)(ptrlong) parent_dp, &parent_itm->itm_dp_to_buf);
      if (BUF_COMPACT_ALL_READY (parent, parent_dp, parent_itm) && parent->bd_is_dirty)
	{
	  BD_SET_IS_WRITE (parent, 1);
	  mutex_leave (&parent_itm->itm_mtx);
	  rc = it_cp_check_node (it, parent, COMPACT_DIRTY);
	}
      else
	mutex_leave (&parent_itm->itm_mtx);
    }
  END_DO_HT;
  hash_table_free (candidates);
}


void
wi_check_all_compact (int age_limit)
{
  /*  call before writing old dirty out. Also before pre-checkpoint flush of all things.  */
  dbe_storage_t * dbs = wi_inst.wi_master;
#ifndef AUTO_COMPACT
  return;
#endif
  if (!dbs)
    return; /* at the very start of init */
  DO_SET (index_tree_t *, it, &dbs->dbs_trees)
    {
      it_check_compact (it, age_limit);
    }
  END_DO_SET();
}

