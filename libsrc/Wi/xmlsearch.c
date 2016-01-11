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
 */

#include "sqlnode.h"
#include "sqlcomp.h"
#include "xmlnode.h"
#include "arith.h"





int itc_xml_row (it_cursor_t * itc, buffer_desc_t * buf, int pos,
		 dp_addr_t * leaf_ret);







long
pg_entity_level (db_buf_t first_key)
{
  int len;
  DB_BUF_TLEN (len, *first_key, first_key);
  first_key += len;
  first_key++;
  return (DV_LONG_INT == *first_key
	  ? LONG_REF (first_key)
	  : (long) (((signed char *) first_key)[1]));
}


int
itc_xml_row (it_cursor_t * itc, buffer_desc_t * buf, int pos,
	     dp_addr_t * leaf_ret)
{
  O12;
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
