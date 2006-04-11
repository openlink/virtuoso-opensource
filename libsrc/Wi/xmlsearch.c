/*
 *  xmlsearch.c
 *
 *  $Id$
 *
 *  Search
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
#include "sqlcomp.h"
#include "xmlnode.h"
#include "arith.h"





int itc_xml_row (it_cursor_t * itc, buffer_desc_t * buf, int pos,
		 dp_addr_t * leaf_ret);



int
itc_xml_search (it_cursor_t * it, buffer_desc_t ** buf_ret, dp_addr_t * leaf_ret)
{
  db_buf_t page = (*buf_ret)->bd_buffer;
  long key_id;
  int res = DVC_LESS;
  int pos, key_pos, key_pos_1;
  long head_len;
  pos = it->itc_position;

  while (1)
    {
      if (!pos)
	{
	  *leaf_ret = 0;
	  it->itc_position = 0;
	  return DVC_INDEX_END;
	}
      if (pos >= PAGE_SZ)
	GPF_T;			/* Link over page end */

      if (it->itc_owns_page != it->itc_page
	  && ITC_IS_LTRX (it)
	  && it->itc_isolation != ISO_UNCOMMITTED)
	{
	  if (it->itc_isolation == ISO_SERIALIZABLE
	      || ITC_MAYBE_LOCK (itc, pos))
	    {
	      it->itc_position = pos;
	      for (;;)
		{
		  int wrc = itc_landed_lock_check (it, buf_ret);
		  if (ISO_SERIALIZABLE == it->itc_isolation
		      || NO_WAIT == wrc)
		    break;
		  /* passing this means for a RR cursor that a subsequent itc_set_lock_on_row is
		   * GUARANTEED to be with no wait. Needed not to run sa_row_check side effect twice */
		  wrc = wrc;	/* breakpoint here */
		}
	      pos = it->itc_position;
	      page = (*buf_ret)->bd_buffer;
	      if (0 == pos)
		{
		  /* The row may have been deleted during lock wait.
		   * if this was the last row, the itc_position will have been set to 0 */
		  *leaf_ret = 0;
		  return DVC_INDEX_END;
		}
	    }
	}

      head_len = page[pos] == DV_SHORT_CONT_STRING ? 2 : 5;
      key_pos = pos + (int) head_len + IE_FIRST_KEY;
      key_pos_1 = key_pos;
      key_id = SHORT_REF (page + key_pos - 4 + IE_KEY_ID);
      it->itc_row_key_id = (key_id_t) key_id;


      if (IE_ISSET (page + pos + head_len, IEF_DELETE))
	goto next_row;
      it->itc_position = pos;
      *leaf_ret = 0;
      res = itc_xml_row (it, *buf_ret, key_pos, leaf_ret);
      if (DVC_GREATER == res)
	return DVC_GREATER;
      if (!*leaf_ret)
	it->itc_at_data_level = 1;
      else
	return DVC_MATCH;

      if (! *leaf_ret && res == DVC_MATCH)
	{
	  it->itc_position = pos;
#ifndef O12
	  if (!key_id == it->itc_key_id
	      && it->itc_sa)
	    {
	      if (DVC_MATCH_COMPLETE == sa_row_check (it->itc_sa, it, *buf_ret,
						      key_pos_1, key_pos))
		{
		  if (it->itc_ks->ks_is_last
		      && (it->itc_ltrx->lt_mode == TM_SNAPSHOT
			  || it->itc_page == it->itc_owns_page))
		    {
		      goto next_row;
		    }
		  return DVC_MATCH_COMPLETE;
		}
	      else
		goto next_row;
	    }
	  else
	    return DVC_MATCH;
#else
	    return DVC_MATCH;
#endif
	}


    next_row:

      if (it->itc_desc_order)
	{
	  itc_prev_entry (it, *buf_ret);
	  pos = it->itc_position;
	}
      else
	{
	  pos = IE_NEXT (page + pos + (int) head_len);
	}
    }
}





long
pg_entity_level (db_buf_t first_key)
{
  int len;
  DB_BUF_TLEN (len, *first_key, first_key);
  first_key += len;
#ifndef O12
  if (*first_key != DV_DEPENDENT)
    GPF_T1 ("not an entity subtable");
#endif
  first_key++;
  return (DV_LONG_INT == *first_key
	  ? LONG_REF (first_key)
	  : (long) (((signed char *) first_key)[1]));
}





void
itc_xml_init (it_cursor_t * itc, buffer_desc_t * buf)
{
O12
#ifndef O12
  int pos;
  long level;
  key_id_t key_id;
  int len;
  caddr_t *qst = itc->itc_out_state;
  db_buf_t page = buf->bd_buffer;
  ancestor_scan_t *as = itc->itc_ks->ks_ancestor_scan;
  pos = itc->itc_position;
  if (!itc->itc_is_on_row)
    sqlr_error ("24000", "Start of ancestor join not on row");
  len = pg_cont_head_length (page + pos);
  pos += len;
  key_id = SHORT_REF (page + pos + IE_KEY_ID);

  if (!sch_is_subkey_incl (isp_schema (itc->itc_space), key_id, entity_key_id))
    sqlr_error ("42000", "24000", "ancestor join start point must be an entity subtable");
  level = pg_entity_level (page + pos + IE_FIRST_KEY);
  if (as->as_axis == AX_ANCESTOR_OR_SELF)
    level++;
  if (as->as_axis == AX_ANCESTOR_1 || as->as_axis == AX_ANCESTOR)
    qst_set_long (qst, as->as_current_level, level);
  else
    qst_set_long (qst, as->as_current_level, level);
  qst_set_long (qst, as->as_subscript, -1);
  if (as->as_axis == AX_DESCENDANT_OR_SELF || as->as_axis == AX_DESCENDANT_OR_SELF_WR
      || as->as_axis == AX_ANCESTOR_OR_SELF)
    itc->itc_is_on_row = 0; /* first 'itc_next' will give this row */
#endif
}


int
itc_xml_row (it_cursor_t * itc, buffer_desc_t * buf, int pos,
	     dp_addr_t * leaf_ret)
{
  O12;
#ifndef O12
  long level, prev_level, subscript;
  key_id_t key_id;
  caddr_t *qst = itc->itc_out_state;
  db_buf_t page = buf->bd_buffer;
  ancestor_scan_t *as = itc->itc_ks->ks_ancestor_scan;

  key_id = SHORT_REF (page + pos + IE_KEY_ID - 4);

  *leaf_ret = leaf_pointer (page, itc->itc_position, pos);
  if (*leaf_ret)
    return DVC_MATCH;
  if (!sch_is_subkey_incl (isp_schema (itc->itc_space), key_id, entity_key_id))
    return DVC_LESS;
  level = pg_entity_level (page + pos);
  prev_level = unbox (qst_get (qst, as->as_current_level));
  subscript = unbox (qst_get (qst, as->as_subscript));
  if (-1 == prev_level)
    return DVC_GREATER;
  switch (as->as_axis)
    {
    case AX_ANCESTOR_1:
      if (level < prev_level
	  || 0 == level)
	{
	  qst_set_long (qst, as->as_current_level, -1);
	  qst_set_long (qst, as->as_subscript, 1);
	  return DVC_MATCH;
	}
      return DVC_LESS;
    case AX_ANCESTOR_OR_SELF:
    case AX_ANCESTOR:
      if (level == 0)
	{
	  qst_set_long (qst, as->as_current_level, -1);
	  qst_set_long (qst, as->as_subscript, subscript + 1);
	  return DVC_MATCH;
	}
      if (level < prev_level)
	{
	  qst_set_long (qst, as->as_current_level, level);
	  qst_set_long (qst, as->as_subscript, subscript + 1);
	  return DVC_MATCH;
	}
      return DVC_LESS;
    case AX_SIBLING:
    case AX_SIBLING_REV:
      if (level < prev_level)
	{
	  return DVC_GREATER;
	}
      if (level == prev_level)
	{
	  qst_set_long (qst, as->as_subscript, subscript + 1);
	  return DVC_MATCH;
	}
      return DVC_LESS;
    case AX_DESCENDANT_OR_SELF:
    case AX_DESCENDANT_OR_SELF_WR:
      if (subscript != -1 && level <= prev_level)
	{
	  qst_set_long (qst, as->as_current_level, -1);
	  return DVC_GREATER;
	}
      qst_set_long (qst, as->as_subscript, subscript + 1);
      return DVC_MATCH;

    case AX_CHILD_1:
    case AX_CHILD_REC:
      if (level <= prev_level)
	{
	  qst_set_long (qst, as->as_current_level, -1);
	  return DVC_GREATER;
	}
      if (level == prev_level + 1
	  || (as->as_axis == AX_CHILD_REC && level > prev_level))
	{
	  qst_set_long (qst, as->as_subscript, subscript + 1);
	  return DVC_MATCH;
	}
      return DVC_LESS;

    default:
      GPF_T1 ("bad ancestor axis");
    }
#endif
  return 0;
}



#ifndef O12
#define TEST_V(sps) \
{ \
  search_spec_t * sp = sps[0]; \
  spi2 = 1; \
  while (sp) \
    { \
      DV_COMPARE_SPEC (res, sp, itc); \
      if (res != DVC_MATCH) \
	return DVC_LESS; \
      sp = sps[spi2++]; \
    } \
}


db_buf_t
itc_misc_column (it_cursor_t * itc, db_buf_t page, dbe_table_t * tb, oid_t misc_id)
{
  oid_t cid;
  if (!tb || !tb->tb_misc_id_to_col_id)
    return NULL;
  cid = (oid_t) gethash ((void *) misc_id, tb->tb_misc_id_to_col_id);
  if (!cid)
    return NULL;
  return (itc_column (itc, page, cid));
}
#endif


#ifndef O12
#define TEST_DEF \
{ \
  col_pos = is_rmap ? itc_misc_column (itc, buf->bd_buffer, tb, sps[0]->sp_col_id) : NULL; \
  if (!col_pos) \
    return DVC_LESS; \
  TEST_V (sps); \
}


#define SET_DEF(sp_inx) \
{ \
  if (ma->ma_out_slots[out_inx]) \
  { \
    col_pos = is_rmap ? itc_misc_column (itc, buf->bd_buffer, tb, ma->ma_ids[out_inx]) : NULL; \
    if (!col_pos) \
      qst_set_bin_string (qst, ma->ma_out_slots[out_inx], (db_buf_t) "", 0, DV_DB_NULL); \
    else \
      itc_qst_set_column (itc, page, ma->ma_ids[out_inx], col_pos, qst, ma->ma_out_slots[out_inx]); \
  } \
}

int
itc_misc_check (it_cursor_t * itc, buffer_desc_t * buf,
		int first_key,
		int is_rm_to_date)
{
  int res;
  caddr_t *qst = itc->itc_out_state;
  int spi2;
  int len;
  db_buf_t page = buf->bd_buffer;
  int misc_pos;
  int is_rmap = 0;
  db_buf_t col_pos;
#ifndef O12
  misc_accelerator_t *ma = itc->itc_ks->ks_ma;
  int n_specs = BOX_ELEMENTS (ma->ma_specs);
  int n_out = BOX_ELEMENTS (ma->ma_ids);
#endif
  int misc_cr, misc_end;
  long misc_len, misc_hl;
  key_id_t key_id = itc->itc_row_key_id;
  dbe_table_t *tb = NULL;
  dtp_t misc_dtp;
  int sp_inx = 0;
  int out_inx = 0;
  if (key_id != entity_key_id)
    {
      db_buf_t misc;
      is_rmap = 1;
#ifndef O12
      if (!is_rm_to_date)
	itc_make_row_map (itc, buf->bd_buffer);
      misc = itc_column (itc, buf->bd_buffer, entity_misc_col_id);
#endif
      misc_pos = misc - buf->bd_buffer;
      if (!misc_pos)
	GPF_T1 ("entity is supposed to have a misc");
      tb = sch_id_to_key (wi_inst.wi_schema, key_id)->key_table;
    }
  else
    {
      /* misc is 4th. id, lev, table misc */
      DB_BUF_TLEN (len, page[first_key], page + first_key);
      misc_pos = first_key + len;
#ifndef O12
      if (page[misc_pos] != DV_DEPENDENT)
	GPF_T;
#endif
      misc_pos++;
      DB_BUF_TLEN (len, page[misc_pos], page + misc_pos);
      misc_pos += len;
      DB_BUF_TLEN (len, page[misc_pos], page + misc_pos);
      misc_pos += len;
    }
  misc_dtp = page[misc_pos];
  db_buf_length (page + misc_pos, &misc_hl, &misc_len);

  misc_cr = misc_pos + misc_hl;
  misc_end = misc_cr + misc_len;
  if (!IS_STRING_DTP (misc_dtp))
    misc_end = 0;

  for (;;)
    {
      oid_t misc_id;
      if (misc_cr >= misc_end)
	{
#ifndef O12
	  for (sp_inx = sp_inx; sp_inx < n_specs; sp_inx++)
	    {
	      search_spec_t **sps = ma->ma_specs[sp_inx];
	      if (sps)
		{
		  TEST_DEF /*(sp_inx)*/;
		}
	    }

	  for (out_inx = out_inx; out_inx < n_out; out_inx++)
	    SET_DEF (out_inx);
#endif
	  break;
	}
      misc_id = LONG_REF (page + misc_cr);
    next_sp:
#ifndef O12
      if (sp_inx < n_specs)
	{
	  search_spec_t **sps = ma->ma_specs[sp_inx];
	  if (!sps)
	    {
	      sp_inx++;
	      goto next_sp;
	    }
	  if (sps[0]->sp_col_id == misc_id)
	    {
	      TEST_V (sps);
	      sp_inx++;
	    }
	  else if (misc_id > sps[0]->sp_col_id)
	    {
	      /* the col is not in misc. is it on the row */
	      TEST_DEF /*(sp_inx)*/;
	      sp_inx++;
	      goto next_sp;
	    }
	}
#endif
    next_out:
#ifndef O12
      if (out_inx < n_out)
	{
	  oid_t cid = ma->ma_ids[out_inx];
	  if (0 == cid)
	    {
	      out_inx++;
	      goto next_out;
	    }
	  if (misc_id == cid)
	    {
	      itc_qst_set_column (itc, page, cid, page + misc_cr + 4, qst, ma->ma_out_slots[out_inx]);
	      out_inx++;
	    }
	  if (misc_id > cid)
	    {
	      SET_DEF (out_inx);
	      out_inx++;
	      goto next_out;
	    }
	}
      if (sp_inx >= n_specs && out_inx >= n_out)
	break;
#endif
      misc_cr += 4;
      DB_BUF_TLEN (len, page[misc_cr], page + misc_cr);
      misc_cr += len;
    }
  return DVC_MATCH;
}
#endif





typedef struct misc_upd_s
{
  int mu_nth_col;
  int mu_misc_pos;
  int mu_misc_end;
  dk_session_t *mu_out;
  int mu_ses_init_fill;
  update_node_t *mu_upd;
  dbe_table_t *mu_row_tb;
  db_buf_t mu_misc_str;
  caddr_t *mu_qst;
}
misc_upd_t;


void
mu_write_header (misc_upd_t * mu)
{
  dk_session_t *ses = mu->mu_out;
  db_buf_t buf = (db_buf_t) ses->dks_out_buffer;
  int init = mu->mu_ses_init_fill;
  int len = (mu->mu_out->dks_out_fill - init) - 5;
  buf[init] = DV_LONG_STRING;
  LONG_SET (buf + init + 1, len);
}


oid_t
mu_next_new (misc_upd_t * mu)
{
  for (;;)
    {
      oid_t cid;
      mu->mu_nth_col++;
      if (mu->mu_nth_col >= upd_n_cols (mu->mu_upd, mu->mu_qst))
	return 0;
      cid = upd_nth_col (mu->mu_upd, mu->mu_qst, mu->mu_nth_col);
      if (IS_MISC_ID (cid)
	  && (!mu->mu_row_tb->tb_misc_id_to_col_id
	   || !gethash ((void *) (ptrlong) cid, mu->mu_row_tb->tb_misc_id_to_col_id)))
	{
	  return cid;
	}
    }
}


oid_t
mu_next_old (misc_upd_t * mu)
{
  oid_t id;
  int len;
  int pos = mu->mu_misc_pos;
  if (-1 == pos)
    pos = 0;
  else
    {
      if (pos >= mu->mu_misc_end)
	return 0;
      pos += 4;
      DB_BUF_TLEN (len, mu->mu_misc_str[pos], mu->mu_misc_str + pos);
      pos += len;
    }
  mu->mu_misc_pos = pos;
  if (pos >= mu->mu_misc_end)
    return 0;
  id = LONG_REF (mu->mu_misc_str + pos);
  return id;
}


void
mu_copy_new (misc_upd_t * mu)
{
  caddr_t val = upd_nth_value (mu->mu_upd, mu->mu_qst, mu->mu_nth_col);
  print_long ((long) upd_nth_col (mu->mu_upd, mu->mu_qst, mu->mu_nth_col), mu->mu_out);
  print_object (val, mu->mu_out, NULL, NULL);
}


void
mu_copy_old (misc_upd_t * mu)
{
  int pos = mu->mu_misc_pos;
  int len;
  pos += 4;
  DB_BUF_TLEN (len, mu->mu_misc_str[pos], mu->mu_misc_str + pos);
  session_buffered_write (mu->mu_out, (char *) (mu->mu_misc_str + pos - 4), len + 4);
}


void
upd_misc_col (update_node_t * upd, caddr_t * qst, dbe_table_t * row_tb, db_buf_t old_val, dk_session_t * ses,
	      caddr_t * err_ret)
{
  oid_t old_id, new_id;
  misc_upd_t mu;
  long ol, ohl;
  db_buf_length (old_val, &ohl, &ol);

  memset (&mu, 0, sizeof (misc_upd_t));
  mu.mu_nth_col = -1;
  mu.mu_misc_pos = ohl;
  mu.mu_out = ses;
  mu.mu_ses_init_fill = ses->dks_out_fill;
  mu.mu_misc_str = old_val;
  mu.mu_upd = upd;
  mu.mu_misc_end = ohl + ol;
  mu.mu_row_tb = row_tb;
  mu.mu_qst = qst;

  old_id = mu_next_old (&mu);
  new_id = mu_next_new (&mu);
  session_buffered_write (ses, "     ", 5);	/* leave space for header */

  for (;;)
    {
      if (!old_id && !new_id)
	break;
      if (!new_id
	  || (old_id && old_id < new_id))
	{
	  mu_copy_old (&mu);
	  old_id = mu_next_old (&mu);
	}
      else if (old_id == new_id)
	{
	  mu_copy_new (&mu);
	  new_id = mu_next_new (&mu);
	  old_id = mu_next_old (&mu);
	}
      else
	{
	  mu_copy_new (&mu);
	  new_id = mu_next_new (&mu);
	}
    }
  mu_write_header (&mu);
}


void
ins_misc_col (dk_session_t * ses,
	      dbe_table_t * tb, oid_t * col_ids, caddr_t * values)
{
  int inx;
  misc_upd_t mu;

  memset (&mu, 0, sizeof (misc_upd_t));
  mu.mu_out = ses;
  mu.mu_ses_init_fill = ses->dks_out_fill;

  session_buffered_write (ses, "     ", 5);	/* space for header */
  DO_BOX (oid_t, cid, inx, col_ids)
  {
    if (IS_MISC_ID (cid)
	&& (!tb->tb_misc_id_to_col_id
	    || !gethash ((void *) (ptrlong) cid, tb->tb_misc_id_to_col_id)))
      {
	print_long ((long) cid, ses);
	print_object (values[inx], ses, NULL, NULL);
      }
  }
  END_DO_BOX;
  mu_write_header (&mu);
}
