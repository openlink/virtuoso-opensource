/*
 *  sqlrun.c
 *
 *  $Id$
 *
 *  SQL query execution
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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
#include "lisprdr.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "security.h"
#include "sqlpfn.h"
#include "sqlintrp.h"
#include "arith.h"
#include "crsr.h"
#include "util/strfuns.h"
#include "sqlbif.h"
#include "list2.h"
#include "sqltype_c.h"

#ifdef _SSL
#include <openssl/md5.h>
#define MD5Init   MD5_Init
#define MD5Update MD5_Update
#define MD5Final  MD5_Final
#else
#include "util/md5.h"
#endif /* _SSL */

long max_static_cursor_rows = _MAX_STATIC_CURSOR_ROWS;


caddr_t *cs_lc_row (cursor_state_t * cs, local_cursor_t * lc,
		    rowset_item_t * rsi);


#define BOX_SET(v, val) \
  (dk_free_tree ((caddr_t) v), *(caddr_t*)&v = box_copy_tree ((caddr_t) val));


void
box_md5_1 (caddr_t box, MD5_CTX * ctx)
{
  dtp_t dtp;
  int len, inx;
  if (!IS_BOX_POINTER (box))
    {
      char box_img[sizeof (long) + 1];
      /* an unboxed num will have ck sum identical to the same boxed value */
      box_img[0] = (dtp_t)(DV_LONG_INT);
      memcpy (&box_img[1], &box, sizeof (long));
      MD5Update (ctx, (unsigned char *) &box_img, sizeof (long) + 1);
      return;
    }
  dtp = box_tag (box);
  len = box_length (box);
  switch (dtp)
    {
    case DV_ARRAY_OF_POINTER: case DV_LIST_OF_POINTER: case DV_ARRAY_OF_XQVAL:
      {
	for (inx = 0; inx < (int) (len / sizeof (caddr_t)); inx++)
	  box_md5_1 (((caddr_t *) box)[inx], ctx);
      }
      break;
    case DV_BLOB_HANDLE:
    case DV_BLOB_WIDE_HANDLE:
      return;
#if 0 /* It's redundant now, because DV_SHORT_STRING == DV_LONG_STRING */
    case DV_STRING:
      box_tag_modify (box, DV_STRING);
      MD5Update (ctx, (unsigned char *) box - 1, len + 1);
      box_tag_modify (box, dtp);
      break;
#endif
    case DV_NUMERIC:
	{
	  unsigned int numeric_len = len - NUMERIC_MAX_DATA_BYTES + numeric_precision ((numeric_t) box);
	  MD5Update (ctx, (unsigned char *) box - 1, numeric_len + 1);
	}
      break;
    case DV_DB_NULL: /* special case since NULLs has zero len */
      MD5Update (ctx, (unsigned char *) box - 1, 1);
      break;
    default:
      MD5Update (ctx, (unsigned char *) box - 1, len + 1);
      break;
    }
}


caddr_t
box_md5 (caddr_t box)
{
  caddr_t res = dk_alloc_box (MD5_SIZE + 1, DV_SHORT_STRING);
  MD5_CTX ctx;
  memset (&ctx, 0, sizeof (MD5_CTX));
  MD5Init (&ctx);
  box_md5_1 (box, &ctx);
  MD5Final ((unsigned char *) res, &ctx);
  res[MD5_SIZE] = 0;
  return res;
}


caddr_t
bif_tree_md5  (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t x = bif_arg (qst, args, 0, "tree_md5");
  caddr_t hex = box_md5 (x), out;
  ptrlong make_it_hex = 0;
  int inx;

  if (BOX_ELEMENTS (args) > 1)
    make_it_hex = bif_long_arg (qst, args, 1, "tree_md5");
  if (make_it_hex)
    {
      char buf [3];
      out = dk_alloc_box (2 * (box_length (hex) - 1) + 1, DV_SHORT_STRING);
      out[0]=0;
      for (inx = 0; ((uint32) inx) < box_length (hex) - 1; inx++)
	{
	  snprintf (buf, sizeof (buf), "%02x", (unsigned char) hex[inx]);
	  strcat_box_ck (out, buf);
	}
      out[2 * (box_length (hex) - 1)] = 0;
      dk_free_box (hex);
    }
  else
    out = hex;
  return (out);
}


/* scrolling */
void
rsi_clear (rowset_item_t * rsi)
{
  dk_free_tree ((caddr_t) rsi->rsi_id);
  dk_free_tree ((caddr_t) rsi->rsi_row);
  dk_free_tree ((caddr_t) rsi->rsi_checksum);
  dk_free_tree ((caddr_t) rsi->rsi_order);
  memset (rsi, 0, sizeof (rowset_item_t));
}


rowset_item_t *
rsi_create (void)
{
  caddr_t rsi = dk_alloc_box (sizeof (rowset_item_t), DV_ARRAY_OF_POINTER);
  memset (rsi, 0, sizeof (rowset_item_t));
  return ((rowset_item_t *) rsi);
}


keyset_t *
kset_create (int sz)
{
  NEW_VARZ (keyset_t, kset);
  kset->kset_size = sz;
  return kset;
}


void
kset_clear (keyset_t * kset)
{
  int sz = kset->kset_size;
  rowset_item_t *rsi = kset->kset_first;
  while (rsi)
    {
      rowset_item_t *next = rsi->rsi_next;
      rsi->rsi_next = NULL;
      rsi->rsi_prev = NULL;
      dk_free_tree ((caddr_t) rsi);
      rsi = next;
    }
/*
  if (kset->kset_ids)
    id_hash_free (kset->kset_ids);*/
  memset (kset, 0, sizeof (keyset_t));
  kset->kset_size = sz;
}


void
kset_free (keyset_t * kset)
{
  kset_clear (kset);
  dk_free ((caddr_t) kset, sizeof (keyset_t));
}


#define ADD_LAST 0
#define ADD_FIRST 1


void
kset_add (cursor_state_t * cs, int add_first)
{
  int cr_type = CS_CR_TYPE (cs);
  int shift_window = 0;
  rowset_item_t *rsi = NULL;
  keyset_t *kset = cs->cs_keyset;
  if (kset->kset_count == kset->kset_size)
    {
      rsi = ADD_FIRST == add_first ? kset->kset_last : kset->kset_first;
      L2_DELETE (kset->kset_first, kset->kset_last, rsi, rsi_);
      rsi_clear (rsi);
      shift_window = 1;
    }
  else
    {
      rsi = rsi_create ();
      kset->kset_count++;
    }
  if (ADD_FIRST == add_first)
    {
      L2_PUSH (kset->kset_first, kset->kset_last, rsi, rsi_);
    }
  else
    {
      L2_PUSH_LAST (kset->kset_first, kset->kset_last, rsi, rsi_);
    }
  if (_SQL_CURSOR_STATIC == cr_type)
    rsi->rsi_row = cs_lc_row (cs, cs->cs_lc, NULL);
  rsi->rsi_id = (caddr_t *) box_copy_tree ((box_t) cs->cs_from_id);
  rsi->rsi_order = (caddr_t *) box_copy_tree ((box_t) cs->cs_from_order);
  if (shift_window)
    {
      if (ADD_FIRST == add_first)
	{
	  BOX_SET (cs->cs_window_last, kset->kset_last->rsi_order);
	  BOX_SET (cs->cs_window_last_id, kset->kset_last->rsi_id);
	}
      else
	{
	  BOX_SET (cs->cs_window_first, kset->kset_first->rsi_order);
	  BOX_SET (cs->cs_window_first_id, kset->kset_first->rsi_id);
	}
    }
}



/* keyset */


caddr_t
cs_err_ck (caddr_t err)
{
  if (err == (caddr_t) SQL_SUCCESS || err == (caddr_t) SQL_NO_DATA_FOUND)
    return err;
  sqlr_resignal (err);
  return NULL;
}


caddr_t
cr_lc_nth_col (local_cursor_t * lc, int nth)
{
  query_instance_t *qi = (query_instance_t *) lc->lc_inst;
  if (!qi)
    return NULL;
  return (qst_get ((caddr_t *) qi, qi->qi_query->qr_select_node->sel_out_slots[nth]));
}

caddr_t
cr_lc_next (cursor_state_t * cs)
{
  caddr_t err;
  query_instance_t *qi = (query_instance_t *) cs->cs_lc->lc_inst;
  if (!qi)
    return NULL;
  if (qi->qi_query->qr_proc_vectored)
    {
      qi->qi_set++;
      if (qi->qi_set < cs->cs_lc->lc_vec_n_rows)
	return (caddr_t)SQL_SUCCESS;
    }
  err = subq_next (qi->qi_query, (caddr_t *) qi, CR_OPEN);
  if (IS_BOX_POINTER (err))
    {
      cs->cs_lc->lc_error = NULL;
      lc_free (cs->cs_lc);
      cs->cs_lc = NULL;
      sqlr_resignal (err);
    }
  return err;
}

void
cs_free (cursor_state_t * cs)
{
  int cr_type = CS_CR_TYPE (cs);
  if (_SQL_CURSOR_DYNAMIC == cr_type)
    dk_free_tree ((caddr_t) cs->cs_rowset);
  else
    dk_free_box ((caddr_t) cs->cs_rowset);
  if (cs->cs_keyset)
    kset_free (cs->cs_keyset);

  dk_free_tree ((caddr_t) cs->cs_window_first);
  dk_free_tree ((caddr_t) cs->cs_window_last);
  dk_free_tree ((caddr_t) cs->cs_window_first_id);
  dk_free_tree ((caddr_t) cs->cs_window_last_id);
  dk_free_tree ((caddr_t) cs->cs_params);

  dk_free_tree ((caddr_t) cs->cs_from_order);
  dk_free_tree ((caddr_t) cs->cs_from_id);

  dk_free_box ((caddr_t) cs->cs_opts);
  if (cs->cs_lc)
    lc_free (cs->cs_lc);
  dk_free_box (cs->cs_name);
  dk_free_tree ((box_t) cs->cs_pl_output_row);
  dk_free ((caddr_t) cs, sizeof (cursor_state_t));
}


cursor_state_t *
cli_find_cs (client_connection_t * cli, char * cr_name)
{
  srv_stmt_t ** stmtp;
  srv_stmt_t * stmt;
  caddr_t * sidp;
  id_hash_iterator_t hit;

  ASSERT_IN_MTX (cli->cli_mtx);
  id_hash_iterator (&hit, cli->cli_statements);
  while (hit_next (&hit, (caddr_t*) &sidp, (caddr_t*) &stmtp))
    {
      stmt = *stmtp;
      if (stmt->sst_cursor_state
	  && 0 == strcmp (stmt->sst_cursor_state->cs_name, cr_name))
	{
	  return (stmt->sst_cursor_state);
	}
    }
  return NULL;
}


cursor_state_t *
cs_create (srv_stmt_t * stmt, caddr_t * params, stmt_options_t * opts, caddr_t cr_name)
{
  NEW_VARZ (cursor_state_t, cs);

  cs->cs_params = params;
  cs->cs_opts = opts;
  cs->cs_stmt = stmt;
  cs->cs_client = GET_IMMEDIATE_CLIENT_OR_NULL;
  cs->cs_query = stmt->sst_query;
  cs->cs_state = CS_AT_START;
  if (!cr_name)
    cr_name = box_string (stmt->sst_id);
  cs->cs_name = cr_name;
  return cs;
}


void
cs_read_row (cursor_state_t * cs)
{
  local_cursor_t *lc = cs->cs_lc;
  int inx, inx2, idfill = 0, ordfill = 0;
  caddr_t *id_row;
  caddr_t *ord_row;
  caddr_t val;
  query_cursor_t *qc = cs->cs_query->qr_cursor;
  if (!qc->qc_order_cols || !qc->qc_id_cols)
    return;
  if (!cs->cs_from_order)
    {
      cs->cs_from_order = (caddr_t *) dk_alloc_box (box_length ((caddr_t) qc->qc_order_cols),
						    DV_ARRAY_OF_POINTER);
      cs->cs_from_id = (caddr_t *) dk_alloc_box (qc->qc_n_id_cols * sizeof (caddr_t),
						 DV_ARRAY_OF_POINTER);
      memset (cs->cs_from_id, 0, box_length ((caddr_t) cs->cs_from_id));
      memset (cs->cs_from_order, 0, box_length ((caddr_t) cs->cs_from_order));
    }
  id_row = cs->cs_from_id;
  DO_BOX (id_cols_t *, ids, inx, qc->qc_id_cols)
  {
    DO_BOX (long, idinx, inx2, ids->idc_pos)
    {
      dk_free_tree (id_row[idfill]);
      val = cr_lc_nth_col (lc, idinx);
      id_row[idfill++] = val ? box_copy_tree (val) : box_num_nonull (0);
    }
    END_DO_BOX;
  }
  END_DO_BOX;

  ord_row = cs->cs_from_order;
  DO_BOX (long, ordinx, inx, qc->qc_order_cols)
  {
    dk_free_tree (ord_row[ordfill]);
    val = cr_lc_nth_col (lc, ordinx);
    ord_row[ordfill++] = val ? box_copy_tree (val) : box_num_nonull (0);
  }
  END_DO_BOX;
}


caddr_t
cs_start_cont (cursor_state_t * cs, query_t * qr, int n_order_params)
{
  caddr_t err;
  int inx;
  int n_params = cs->cs_params ? BOX_ELEMENTS (cs->cs_params) : 0;
  caddr_t *params = (caddr_t *) dk_alloc_box
  ((n_params + n_order_params) * sizeof (caddr_t) * 2, DV_ARRAY_OF_POINTER);
  char temp[50];

  for (inx = 0; inx < n_params; inx++)
    {
      snprintf (temp, sizeof (temp), ":%d", inx);
      params[inx * 2] = box_string (temp);
      params[inx * 2 + 1] = box_copy_tree (cs->cs_params[inx]);
    }
  for (inx = 0; inx < n_order_params; inx++)
    {
      snprintf (temp, sizeof (temp), ":%d", inx + 1000);
      params[(inx + n_params) * 2] = box_string (temp);
      params[(inx + n_params) * 2 + 1] = box_copy_tree (cs->cs_from_order[inx]);
    }
  err = qr_exec (cs->cs_client, qr, CALLER_LOCAL, NULL, NULL,
		 &cs->cs_lc, params, cs->cs_opts, 1);
  dk_free_box ((caddr_t) params);
  cs_err_ck (err);
  if (cs->cs_lc && cs->cs_lc->lc_position != -1)
    return ((caddr_t) SQL_SUCCESS);
  return ((caddr_t) SQL_NO_DATA_FOUND);
}


caddr_t
cs_next (cursor_state_t * cs, int dir)
{
  caddr_t err = NULL;
  query_cursor_t *qc = cs->cs_query->qr_cursor;
  dir = IS_FWD (dir) || _SQL_FETCH_RELATIVE == dir ? FWD : BWD;

  if (dir == FWD && cs->cs_state == CS_AT_END)
    return ((caddr_t) SQL_NO_DATA_FOUND);
  if (dir == BWD && cs->cs_state == CS_AT_START)
    return ((caddr_t) SQL_NO_DATA_FOUND);


  for (;;)
    {
      query_instance_t *qi = NULL;
      if (cs->cs_prev_dir == dir
	  && cs->cs_lc && cs->cs_lc->lc_inst)
	{
	  /* scroll from open position */
	  qi = (query_instance_t *)cs->cs_lc->lc_inst;
	  qi->qi_thread = THREAD_CURRENT_THREAD;
	  err = cr_lc_next (cs);
	check_fetch_result:

	  if (err == (caddr_t) SQL_NO_DATA_FOUND)
	    {
	      lc_free (cs->cs_lc);
	      cs->cs_lc = NULL;
	      if (cs->cs_nth_cont <= 1)
		{
		  cs->cs_state = dir == FWD ? CS_AT_END : CS_AT_START;
		  return ((caddr_t) SQL_NO_DATA_FOUND);
		}
	      cs->cs_nth_cont--;
	    }
	  if (err == (caddr_t) SQL_SUCCESS)
	    {
	      cs->cs_state = CS_ON_ROW;
	      cs_read_row (cs);
	      return ((caddr_t) SQL_SUCCESS);
	    }
	}
      else
	{
	  /* open from continue point */
	  query_t *c_qr;
	  if (!cs->cs_from_order)
	    cs->cs_nth_cont = 0;
	  c_qr = dir == FWD ? qc->qc_next[cs->cs_nth_cont] : qc->qc_prev[cs->cs_nth_cont];
	  cs->cs_prev_dir = dir;
	  err = cs_start_cont (cs, c_qr, cs->cs_nth_cont);
	  goto check_fetch_result;
	}
    }
}


caddr_t
cs_position_at_end (cursor_state_t * cs, int dir)
{
  BOX_SET (cs->cs_from_order, NULL);
  BOX_SET (cs->cs_from_id, NULL);
  cs->cs_nth_cont = 0;
  if (cs->cs_lc)
    lc_free (cs->cs_lc);
  cs->cs_lc = NULL;
  cs->cs_lc_pos = LC_NONE;
  return ((caddr_t) SQL_SUCCESS);
}


caddr_t
cs_position_at_from_row (cursor_state_t * cs, int ftype)
{
  caddr_t *row_id;
  caddr_t err;
  int dir = IS_FWD (ftype) || _SQL_FETCH_RELATIVE == ftype ? FWD : BWD;
  int org_nth;
  int last_order_inx = BOX_ELEMENTS (cs->cs_query->qr_cursor->qc_order_cols) - 1;
  caddr_t last_order_val = box_copy_tree (cs->cs_from_order[last_order_inx]);
  if (cs->cs_lc)
    lc_free (cs->cs_lc);
  cs->cs_lc = NULL;
  cs->cs_nth_cont = BOX_ELEMENTS (cs->cs_query->qr_cursor->qc_next) - 1;
  org_nth = cs->cs_nth_cont;
  if (!cs->cs_from_order)
    GPF_T1 ("no cs_from_order");

  row_id = (caddr_t *) box_copy_tree ((box_t) cs->cs_from_id);

  for (;;)
    {
      err = cs_next (cs, dir);
      if (err == (caddr_t) SQL_NO_DATA_FOUND)
	{
	  dk_free_tree (last_order_val);
	  dk_free_tree ((box_t) row_id);
	  return ((caddr_t) SQL_NO_DATA_FOUND);
	}
      if (!last_order_val)
	{
	  dk_free_tree ((box_t) row_id);
	  return ((caddr_t) SQL_SUCCESS);
	}
      if (box_equal (cs->cs_from_order[last_order_inx], last_order_val)
	  && cs->cs_nth_cont == org_nth)
	{
	  if (box_equal ((box_t) cs->cs_from_id, (box_t) row_id))
	    {
	      err = (caddr_t) SQL_SUCCESS;
	      if (ftype == _SQL_FETCH_NEXT || ftype == _SQL_FETCH_PRIOR)
		/* found prev row. Go to next/prev to be on first of new window. If rel, stay here */
		err = cs_next (cs, ftype);
	      dk_free_tree ((box_t) row_id);
	      dk_free_tree ((caddr_t) last_order_val);
	      return err;
	    }
	}
      else
	{
	  /* do not find org row. Next gt/lt shall be first of new window */
	  dk_free_tree ((box_t) row_id);
	  dk_free_tree ((caddr_t) last_order_val);
	  return ((caddr_t) SQL_SUCCESS);
	}
    }
}


void
cs_register_lc (cursor_state_t * cs)
{
  client_connection_t *cli = cs->cs_client;
  srv_stmt_t *stmt = cs->cs_stmt;
  if (cs->cs_lc && cs->cs_lc->lc_inst
      && !cs->cs_lc->lc_cursor_name && !CS_IS_PL_CURSOR (cs))
    {
      cs->cs_lc->lc_cursor_name = box_copy (stmt->sst_id);
      mutex_enter (cli->cli_mtx);
      id_hash_set (cli->cli_cursors, (caddr_t) & cs->cs_lc->lc_cursor_name, (caddr_t) & cs->cs_lc->lc_inst);
      mutex_leave (cli->cli_mtx);
    }
}


void
cs_send_at_end (cursor_state_t * cs)
{
  if (CS_IS_PL_CURSOR (cs))
    cs->cs_pl_state = CS_PL_AT_END;
  else
    PrpcAddAnswer (0, DV_LONG_INT, 1, 0);
}


long cs_keyset_row_no (cursor_state_t *cs, rowset_item_t *rsi);

void
cs_send_deleted (cursor_state_t * cs, rowset_item_t *rsi)
{
  caddr_t x;

  if (rsi)
    {
      x = (caddr_t) list (3, QA_ROW_DELETED,
	  list (2,
	    box_copy_tree ((caddr_t) rsi->rsi_order),
	    box_copy_tree ((caddr_t) rsi->rsi_id)
	  ),
	  box_num(cs_keyset_row_no(cs, rsi))
	);
    }
  else
    {
      x = (caddr_t) list (1, QA_ROW_DELETED);
    }
  if (CS_IS_PL_CURSOR (cs))
    cs->cs_pl_state = CS_PL_DELETED;
  else
    PrpcAddAnswer (x, DV_ARRAY_OF_POINTER, 1, 1);
  dk_free_tree (x);
}


void
cs_reset_rowset (cursor_state_t * cs, int n, int ftype)
{
  dk_free_tree ((caddr_t) cs->cs_rowset);
  cs->cs_rowset = (rowset_item_t **) dk_alloc_box (n * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  memset (cs->cs_rowset, 0, n * sizeof (caddr_t));
  cs->cs_rowset_fill = 0;
}

long
cs_keyset_row_no (cursor_state_t *cs, rowset_item_t *rsi) {

	rowset_item_t *curr;
	long curr_row_number = 1;
	if(cs->cs_keyset==NULL) return 0;
	for (curr = cs->cs_keyset->kset_first; curr && curr != rsi && curr->rsi_next ; curr = curr->rsi_next)
		curr_row_number += 1;
	return curr_row_number;
}

caddr_t *
cs_lc_row (cursor_state_t * cs, local_cursor_t * lc,
	   rowset_item_t * rsi)
{
  query_cursor_t *qc = cs->cs_query->qr_cursor;
  int inx;
  int use_bm = cs->cs_opts->so_use_bookmarks ? 1 : 0;
  int n_cols = qc->qc_n_select_cols;
  caddr_t *res = (caddr_t *) dk_alloc_box ((1 + n_cols + use_bm * 2) * sizeof (caddr_t),
					   DV_ARRAY_OF_POINTER);
  res[0] = (caddr_t) QA_ROW;
  for (inx = 1; inx <= n_cols; inx++)
    {
      res[inx] = box_copy_tree (cr_lc_nth_col (lc, inx - 1));
    }
  if (use_bm)
    {
      res[n_cols + 2] = box_num(0);
      if (_SQL_CURSOR_STATIC == CS_CR_TYPE (cs))
	res[n_cols + 1] = box_num (cs->cs_n_scrolled);
      else if (!rsi && _SQL_CURSOR_DYNAMIC == CS_CR_TYPE (cs))
	res[n_cols + 1] = list (2, box_copy_tree ((caddr_t) cs->cs_from_order),
	    box_copy_tree ((caddr_t) cs->cs_from_id));
      else if (rsi) {
	res[n_cols + 1] = list (2, box_copy_tree ((caddr_t) rsi->rsi_order),
	    box_copy_tree ((caddr_t) rsi->rsi_id));
	res[n_cols + 2] = box_num(cs_keyset_row_no(cs, rsi));
      }
      else
	GPF_T1 ("No bookmark value for row");
      ;
    }
  return res;
}


void
cs_rowset_row (cursor_state_t * cs, int inx)
{
  caddr_t *res = cs_lc_row (cs, cs->cs_lc, NULL);
  caddr_t ck = box_md5 ((caddr_t) res);

  {
    rowset_item_t *rsi = (rowset_item_t *) dk_alloc_box (sizeof (rowset_item_t), DV_ARRAY_OF_POINTER);
    memset (rsi, 0, sizeof (rowset_item_t));
    rsi->rsi_id = (caddr_t *) box_copy_tree ((caddr_t) cs->cs_from_id);
    rsi->rsi_checksum = ck;
    rsi->rsi_row = res;
    cs->cs_rowset[inx] = rsi;
  }
}


void
cs_fix_rowset_dir (cursor_state_t * cs, int ftype)
{
  if (_SQL_FETCH_PRIOR == ftype || _SQL_FETCH_LAST == ftype)
    {
      int inx;
      for (inx = 0; inx < cs->cs_rowset_fill / 2; inx++)
	{
	  rowset_item_t *tmp = cs->cs_rowset[inx];
	  int inx2 = (cs->cs_rowset_fill - inx) - 1;
	  cs->cs_rowset[inx] = cs->cs_rowset[inx2];
	  cs->cs_rowset[inx2] = tmp;
	}
    }
}


void
cs_send_rowset (cursor_state_t * cs, int ftype)
{
  int inx;
  if (CS_IS_PL_CURSOR (cs))
    {
      if (cs->cs_rowset_fill != 1)
	sqlr_new_error ("22003", "SR216", "PL Scrollable cursor with a rowset > 1");
      CS_PL_SET_OUTPUT (cs, cs->cs_rowset[0]->rsi_row);
    }
  else
    for (inx = 0; inx < cs->cs_rowset_fill; inx++)
      {
	rowset_item_t *rsi = cs->cs_rowset[inx];
	PrpcAddAnswer ((caddr_t) rsi->rsi_row, DV_ARRAY_OF_POINTER, 1, 0);
	if (_SQL_CURSOR_STATIC != cs->cs_query->qr_cursor->qc_cursor_type)
	  {
	    dk_free_tree ((caddr_t) rsi->rsi_row);
	    rsi->rsi_row = NULL;
	  }
      }
}


void
cs_prior_rel (cursor_state_t * cs, int irow)
{
  int inx;
  cs_position_at_from_row (cs, _SQL_FETCH_PRIOR);
  for (inx = 0; inx < (-irow) - 1; inx++)
    cs_next (cs, _SQL_FETCH_PRIOR);
}


caddr_t
stmt_dyn_fetch_inner (srv_stmt_t * stmt, int ftype, int irow,
		      int n_rows, kset_func f)
{
  caddr_t err;
  int inx;
  cursor_state_t *cs = stmt->sst_cursor_state;
  int cont_from_lc = 0, cont_from_value = 0;



  if (ftype == _SQL_FETCH_LAST
      || ftype == _SQL_FETCH_FIRST)
    {
      cs->cs_state = CS_ON_ROW;
      BOX_SET (cs->cs_window_first, NULL);
      BOX_SET (cs->cs_window_last, NULL);
      cs_position_at_end (cs, ftype);
      cont_from_lc = 1;
    }
  else if (ftype == _SQL_FETCH_NEXT)
    {
      BOX_SET (cs->cs_from_order, cs->cs_window_last);
      BOX_SET (cs->cs_from_id, cs->cs_window_last_id);
      if (cs->cs_prev_dir == FWD && cs->cs_lc_pos == LC_AFTER_WINDOW
	  && cs->cs_lc && cs->cs_lc->lc_inst)
	cont_from_lc = 1;
      else
	cont_from_value = 1;
    }
  else if (ftype == _SQL_FETCH_PRIOR)
    {
      BOX_SET (cs->cs_from_order, cs->cs_window_first);
      BOX_SET (cs->cs_from_id, cs->cs_window_first_id);
      if (cs->cs_prev_dir == BWD && cs->cs_lc_pos == LC_BEFORE_WINDOW
	  && cs->cs_lc && cs->cs_lc->lc_inst)
	cont_from_lc = 1;
      else
	cont_from_value = 1;
    }
  else if (ftype == _SQL_FETCH_RELATIVE)
    {
      cont_from_value = 1;
      BOX_SET (cs->cs_from_order, cs->cs_window_first);
      BOX_SET (cs->cs_from_id, cs->cs_window_first_id);
      if (irow < 0)
	{
	  cs_prior_rel (cs, irow);
	  irow = 0;
	}
      cs->cs_lc_pos = LC_AFTER_WINDOW;
    }

  if (cont_from_value && cs->cs_from_order)
    {
      cs->cs_prev_dir = IS_FWD (ftype) ? FWD : BWD;
      err = cs_position_at_from_row (cs, ftype);
      /* on first of new window */
    }
  else
    err = cs_next (cs, ftype);

  for (inx = 0; inx < irow; inx++)
    if (err == (caddr_t) SQL_SUCCESS)
      err = cs_next (cs, ftype);
  /* first row of new window */
  if (err == (caddr_t) SQL_NO_DATA_FOUND)
    {
      cs->cs_lc_pos = LC_NONE;
      if (f)
	return err;
      cs->cs_window_pos = IS_FWD (ftype) && _SQL_FETCH_RELATIVE != ftype
	? CS_WINDOW_END : CS_WINDOW_START;
      cs_send_at_end (cs);
      return err;
    }
  cs->cs_window_pos = CS_WINDOW_ROW;

  if (IS_FWD (ftype) || _SQL_FETCH_RELATIVE == ftype)
    {
      BOX_SET (cs->cs_window_first, cs->cs_from_order);
      BOX_SET (cs->cs_window_first_id, cs->cs_from_id);
      cs->cs_lc_pos = LC_AFTER_WINDOW;
    }
  else
    {
      BOX_SET (cs->cs_window_last, cs->cs_from_order);
      BOX_SET (cs->cs_window_last_id, cs->cs_from_id);
      cs->cs_lc_pos = LC_BEFORE_WINDOW;
    }
  if (!f)
    {
      cs_reset_rowset (cs, n_rows, ftype);
    }
  for (inx = 0; inx < n_rows; inx++)
    {
      if (err == SQL_SUCCESS)
	{
	  if (f)
	    f (cs);
	  else
	    {
	      cs_rowset_row (cs, inx);
	      cs->cs_rowset_fill++;
	    }
	}
      if (err == (caddr_t) SQL_NO_DATA_FOUND)
	{
	  break;
	}
      if (inx == n_rows - 1)
	break;
      err = cs_next (cs, ftype);
    }
  if (IS_FWD (ftype) || _SQL_FETCH_RELATIVE == ftype)
    {
      BOX_SET (cs->cs_window_last, cs->cs_from_order);
      BOX_SET (cs->cs_window_last_id, cs->cs_from_id);
    }
  else
    {
      BOX_SET (cs->cs_window_first, cs->cs_from_order);
      BOX_SET (cs->cs_window_first_id, cs->cs_from_id);
    }
  cs_register_lc (cs);
  if (f)
    return err;
  if (ftype == _SQL_FETCH_PRIOR && cs->cs_rowset_fill != n_rows)
    {
      return (stmt_dyn_fetch_inner (stmt, _SQL_FETCH_FIRST, 0,
			    n_rows, NULL));
    }
  cs_fix_rowset_dir (cs, ftype);
  cs_send_rowset (cs, ftype);
  if (cs->cs_rowset_fill != n_rows)
    cs_send_at_end (cs);
  return err;
}


void
cs_set_pos_ret (local_cursor_t * lc, caddr_t err)
{
  if (lc && (caddr_t) SQL_SUCCESS == err)
    {
      err = list (2, QA_ROWS_AFFECTED, lc->lc_row_count);
    }
  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 0);
  if (lc)
    lc_free (lc);
  dk_free_tree (err);
}


static caddr_t *
cs_make_start_cont_params (cursor_state_t * cs, caddr_t *sparams)
{
  int n_user_params = CS_IS_PL_CURSOR (cs) && cs->cs_params ? BOX_ELEMENTS (cs->cs_params) : 0;
  int n_sparams = DV_TYPE_OF (sparams) == DV_ARRAY_OF_POINTER ? BOX_ELEMENTS (sparams) : 0;
  int inx;
  char temp[50];

  caddr_t *params = (caddr_t *) dk_alloc_box ((n_user_params + n_sparams) * sizeof (caddr_t) * 2,
      DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < n_user_params; inx ++)
    {
      snprintf (temp, sizeof (temp), ":%d", inx);
      params[inx * 2] = box_string (temp);
      params[inx * 2 + 1] = box_copy_tree (cs->cs_params[inx]);
    }
  for (inx = 0; inx < n_sparams; inx ++)
    {
      snprintf (temp, sizeof (temp), ":%d", inx + 1000);
      params[(inx + n_user_params) * 2] = box_string (temp);
      params[(inx + n_user_params) * 2 + 1] = box_copy_tree (sparams[inx]);
    }
  return params;
}


caddr_t
cs_refresh_start_cont (cursor_state_t * cs, query_t * qr, query_instance_t *caller,
    local_cursor_t **lc_ret, caddr_t *sparams)
{
  caddr_t err;
  caddr_t *params = cs_make_start_cont_params (cs, sparams);
  err = qr_exec (cs->cs_client, qr, caller, NULL, NULL, lc_ret, params, cs->cs_opts, 1);
  dk_free_box ((box_t) params);
  return err;
}


void
cs_refresh_row (cursor_state_t * cs, int row_no, query_instance_t * caller,
		caddr_t ** row_ret, int update_rowset, caddr_t * err_ret)
{
  caddr_t err;
  query_cursor_t * qc = cs->cs_query->qr_cursor;
  local_cursor_t * lc;
  rowset_item_t * rsi = cs->cs_rowset[row_no];

  err = cs_refresh_start_cont (cs, qc->qc_refresh, caller, &lc, (caddr_t *) rsi->rsi_id);
  if (err_ret)
    *err_ret = err;
  if (lc && lc->lc_position != -1)
    {
      caddr_t *res = cs_lc_row (cs, lc, rsi);
      caddr_t ck;
      if (update_rowset)
	{
	  ck = box_md5 ((caddr_t) res);
	  dk_free_box (rsi->rsi_checksum);
	  rsi->rsi_checksum = ck;
	}
      if (row_ret)
	*row_ret = res;
      else
	{
	  dk_free_tree ((caddr_t) res);
	}
    }
  else if (lc && lc->lc_position == -1)
    {
      if (row_ret)
	*row_ret = NULL;

    }
  if (lc)
    lc_free (lc);
}


caddr_t
cs_check_values (cursor_state_t * cs, int row_no, query_instance_t * caller)
{
  caddr_t err;
  rowset_item_t * rsi = cs->cs_rowset[row_no];
  caddr_t * row = NULL;
  caddr_t ck = NULL;
  if (cs->cs_opts->so_concurrency != _SQL_CONCUR_VALUES)
    return ((caddr_t) SQL_SUCCESS);
  cs_refresh_row (cs, row_no, caller, &row, 0, &err);
  if (err != (caddr_t) SQL_SUCCESS)
    {
      dk_free_tree ((box_t) row);
      return err;
    }
  ck = box_md5 ((caddr_t) row);
  dk_free_tree ((box_t) row);

  if (box_equal (ck, rsi->rsi_checksum))
    {
      dk_free_box (ck);
      return ((caddr_t) SQL_SUCCESS);
    }
  dk_free_box (ck);
/*
  TRX_POISON (caller->qi_trx);
  caller->qi_trx->lt_error = LTE_DEADLOCK;
*/
  return (srv_make_new_error ("01001", "SR217", "Optimistic cursor updated since last read"));
}


void
cs_set_pos_1 (cursor_state_t * cs, int op, int row_no, caddr_t * params,
	      query_instance_t * caller, caddr_t * err_ret,
	      caddr_t ** row_ret);


void
cs_fix_ignores (cursor_state_t * cs, int row_no, caddr_t * params,
	      query_instance_t * caller, caddr_t * err_ret)
{
  caddr_t * fresh_row = NULL;
  int inx;
  DO_BOX (caddr_t, param, inx, params)
    {
      if (DV_IGNORE == DV_TYPE_OF (param))
	{
	  if (!fresh_row)
	    {
	      if (_SQL_CURSOR_STATIC == CS_CR_TYPE (cs))
		fresh_row = (caddr_t*) box_copy_tree ((caddr_t) cs->cs_rowset[row_no]->rsi_row);
	      else
		{
		  cs_set_pos_1 (cs, _SQL_REFRESH, row_no, NULL, caller, err_ret, &fresh_row);
		  if (! fresh_row)
		    return;
		}
	    }
	  dk_free_box (param);
	  params[inx] = fresh_row[inx+1];
	  fresh_row[inx+1] = NULL;
	}
    }
  END_DO_BOX;
  if (fresh_row)
    dk_free_tree ((caddr_t) fresh_row);
}

#define CS_ANSWER_OR_ERROR(err_ret,err) \
		do { \
		  if (err_ret) \
		    *err_ret = box_copy_tree (err); \
		  else \
		    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 0); \
		  dk_free_tree (err); \
		} while (0)

void
cs_set_pos_1 (cursor_state_t * cs, int op, int row_no, caddr_t * params,
	      query_instance_t * caller, caddr_t * err_ret,
	      caddr_t ** row_ret)
{
  caddr_t *row_id = NULL;
  local_cursor_t *lc = NULL;
  caddr_t err;
  query_cursor_t *qc = cs->cs_query->qr_cursor;
  rowset_item_t *rsi = cs->cs_rowset ? cs->cs_rowset[row_no] : NULL;
  switch (op)
    {
    case _SQL_REFRESH:
      if (!rsi)
	goto no_row;
      {
	err = cs_refresh_start_cont (cs, qc->qc_refresh, caller, &lc, (caddr_t *) rsi->rsi_id);
	if (err_ret)
	  *err_ret = box_copy_tree (err);
	if (lc && lc->lc_position != -1)
	  {
	    caddr_t *res = cs_lc_row (cs, lc, rsi);
	    caddr_t ck = box_md5 ((caddr_t) res);
	    if (rsi->rsi_checksum && 0 != memcmp (ck, rsi->rsi_checksum, MD5_SIZE))
	      res[0] = (caddr_t) QA_ROW_UPDATED;
	    dk_free_box (rsi->rsi_checksum);
	    rsi->rsi_checksum = ck;
	    dk_free_tree ((box_t) rsi->rsi_row);
	    rsi->rsi_row = NULL;
	    /* rsi->rsi_row = res; */
	    if (row_ret)
	      *row_ret = res;
	    else
	      {
		if (CS_IS_PL_CURSOR (cs))
		  {
		    CS_PL_SET_OUTPUT (cs, res);
		  }
		else
		  PrpcAddAnswer ((caddr_t) res, DV_ARRAY_OF_POINTER, 1, 0);
		dk_free_tree ((caddr_t) res);
	      }
	  }
	else if (lc && lc->lc_position == -1)
	  {
	    if (row_ret)
	      *row_ret = NULL;
	    else
	      cs_send_deleted (cs, rsi);
	  }
	else
	  if (err_ret)
	    *err_ret = box_copy_tree (err);
	  else
	    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	if (lc)
	  lc_free (lc);

	break;
      }
    case _SQL_UPDATE:
      {
	caddr_t *params2;
	if (!qc->qc_update)
	  goto cannot;
	if (!rsi)
	  goto no_row;
	err = cs_check_values (cs, row_no, caller);
	if (err != (caddr_t) SQL_SUCCESS)
	  {
	    CS_ANSWER_OR_ERROR (err_ret, err);
	    return;
	  }
	row_id = (caddr_t *) box_copy_tree ((caddr_t) rsi->rsi_id);
	cs_fix_ignores (cs, row_no, params, caller, err_ret);
	params2 = (caddr_t *) box_conc ((caddr_t) row_id, (caddr_t) params);
	err = qr_exec (cs->cs_client, qc->qc_update,
		       caller, NULL, NULL, &lc, params2,
		       NULL, 0);
	memset (params, 0, box_length (params));	/* contents freed by qe_exec */
	if (err == (caddr_t) SQL_SUCCESS
	    && _SQL_CONCUR_VALUES == cs->cs_opts->so_concurrency)
	  {
	    cs_refresh_row (cs, row_no, caller, NULL, 1, &err);
	  }
	if (err != (caddr_t) SQL_SUCCESS)
	  CS_ANSWER_OR_ERROR (err_ret, err);
	else
	  cs_set_pos_ret (lc, err);
	dk_free_box ((box_t) params2);
	dk_free_box ((caddr_t) row_id);
	break;
      }
    case _SQL_DELETE:
      {
	if (!qc->qc_delete)
	  goto cannot;
	if (!rsi)
	  goto no_row;
	err = cs_check_values (cs, row_no, caller);
	if (err != (caddr_t) SQL_SUCCESS)
	  {
	    CS_ANSWER_OR_ERROR (err_ret, err);
	    return;
	  }
	row_id = (caddr_t *) box_copy_tree ((caddr_t) rsi->rsi_id);
	err = qr_exec (cs->cs_client, qc->qc_delete,
		       caller, NULL, NULL, &lc, row_id,
		       NULL, 0);
	dk_free_box ((caddr_t) row_id);
	if (err != (caddr_t) SQL_SUCCESS)
	  CS_ANSWER_OR_ERROR (err_ret, err);
	else
	  cs_set_pos_ret (lc, err);
	break;
      }
    case _SQL_ADD:
      {
	if (!qc->qc_insert)
	  goto cannot;
	err = qr_exec (cs->cs_client, qc->qc_insert,
		       caller, NULL, NULL, &lc, params,
		       NULL, 0);
	memset (params, 0, box_length (params));	/* contents freed by qe_exec */
	if (err != (caddr_t) SQL_SUCCESS)
	  CS_ANSWER_OR_ERROR (err_ret, err);
	else
	  cs_set_pos_ret (lc, err);
	break;
      }

    }
  return;
cannot:
  err = srv_make_new_error ("HYC00", "SR218", "Cursor not capable of requested SQLSetPos operation");
  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
  dk_free_tree (err);
  return;
no_row:
  err = srv_make_new_error ("HY107", "SR219", "Row in SQLSetPos does not exist in the rowset");
  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
  dk_free_tree (err);
  return;
}



caddr_t
bif_sql_set_pos (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  cursor_state_t *cs;
  srv_stmt_t *stmt;
  srv_stmt_t **place;
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t stmt_id = bif_string_arg (qst, args, 0, "set_pos");
  int op = (int) bif_long_arg (qst, args, 1, "set_pos");
  int nth = (int) bif_long_arg (qst, args, 2, "set_pos");
  caddr_t *params = (caddr_t *) bif_arg (qst, args, 3, "set_pos");
  caddr_t err = NULL;


  IN_CLIENT (qi->qi_client);
  place = (srv_stmt_t **) id_hash_get (qi->qi_client->cli_statements, (caddr_t) & stmt_id);
  LEAVE_CLIENT (qi->qi_client);
  if (!place)
    sqlr_new_error ("S1010", "SR220", "Unopened cursor referenced by SQLSetPos");
  stmt = *place;
  cs = stmt->sst_cursor_state;
  if (!cs)
    {
      sqlr_new_error ("S1010", "SR221", "Not a scrollable cursor in SQLSetPos");
    }
  PrpcAddAnswer (SQL_SUCCESS, DV_ARRAY_OF_POINTER, 1, 0);
  /* this initial success means that the codes for the rows will be following. */
  if (0 == nth)
    {
      int inx;
      int n_rows = params ? BOX_ELEMENTS (params) : cs->cs_rowset_fill;
      for (inx = 0; inx < n_rows; inx++)
	{
	  if (!err)
	    cs_set_pos_1 (cs, op, inx, params ? (caddr_t *) params[inx] : NULL, qi, &err, NULL);
	  if (err)
	    {
	      caddr_t code = ERR_STATE (err);
	      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 0);
	      if (strncmp (code, "4000", 4) &&
		  strncmp (code, "S1T00", 5) &&
		  strncmp (code, "23000", 5) &&
		  strncmp (code, "08U01", 5))
		{
		  dk_free_tree (err);
		  err = NULL;
		}
	    }
	}
      dk_free_tree (err);
    }
  else
    cs_set_pos_1 (cs, op, nth - 1, params, qi, NULL, NULL);
  return NULL;
}




void
cs_keyset_add (cursor_state_t * cs)
{
  cs->cs_n_scrolled++;
  kset_add (cs, (((ptrlong) cs->cs_client_data) == FWD) ? ADD_LAST : ADD_FIRST);
}


caddr_t
cs_init_keyset (cursor_state_t * cs, int ftype)

{
  stmt_options_t *so = cs->cs_opts;
  int cr_type = CS_CR_TYPE (cs);
  int kssz = (int) cs->cs_opts->so_keyset_size;
  keyset_t *kset = cs->cs_keyset;
  int dir = FWD;
  if (_SQL_CURSOR_STATIC == cr_type)
    {
      kssz = so->so_max_rows == 0 ? MAX_STATIC_CURSOR_ROWS : (int) so->so_max_rows;
      ftype = _SQL_FETCH_FIRST;
    }
  if (0 == kssz)
    kssz = MAX_STATIC_CURSOR_ROWS;
  if (!kset)
    {
      kset = kset_create (kssz);
      cs->cs_keyset = kset;
    }
  if (_SQL_FETCH_LAST == ftype)
    dir = BWD;
  if (kset->kset_is_complete)
    return ((caddr_t) SQL_SUCCESS);
  if (KSET_AT_END == cs->cs_keyset_pos
      && dir == _SQL_FETCH_PRIOR)
    return ((caddr_t) SQL_SUCCESS);
  if (KSET_AT_START == cs->cs_keyset_pos
      && dir == _SQL_FETCH_NEXT)
    return ((caddr_t) SQL_SUCCESS);
  kset_clear (cs->cs_keyset);
  cs->cs_client_data = (void *) (ptrlong) dir;
  stmt_dyn_fetch_inner (cs->cs_stmt, ftype, 0, kssz,
			cs_keyset_add);
  if (kset->kset_count < kssz
      || _SQL_CURSOR_STATIC == cr_type)
    kset->kset_is_complete = 1;
  cs->cs_keyset_pos = IS_FWD (ftype) ? KSET_AT_START : KSET_AT_END;
  return ((caddr_t) SQL_SUCCESS);
}


caddr_t
cs_kset_move (cursor_state_t * cs, int dir)
{
  cs->cs_client_data = (void *) (ptrlong) dir;
  cs->cs_n_scrolled = 0;
  stmt_dyn_fetch_inner (cs->cs_stmt, dir, 0, 1,
			cs_keyset_add);
  if (0 == cs->cs_n_scrolled)
    cs->cs_keyset_pos = FWD == dir ? KSET_AT_END : KSET_AT_START;
  else
    cs->cs_keyset_pos = KSET_MIDDLE;
  return ((caddr_t) (ptrlong) (cs->cs_keyset_pos == KSET_MIDDLE
		     ? SQL_SUCCESS : SQL_NO_DATA_FOUND));
}


void
cs_reset_kset_rowset (cursor_state_t * cs, int n)
{
  dk_free_box ((caddr_t) cs->cs_rowset);
  cs->cs_rowset = (rowset_item_t **) dk_alloc_box (n * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  memset (cs->cs_rowset, 0, n * sizeof (caddr_t));
  cs->cs_rowset_fill = 0;
}


caddr_t
cs_kset_next (cursor_state_t * cs, int ftype)
{
  keyset_t *kset = cs->cs_keyset;
  int dir = IS_FWD (ftype) ? FWD : BWD;
  if (!kset->kset_current)
    return ((caddr_t) SQL_NO_DATA_FOUND);
  if (FWD == dir)
    kset->kset_current = kset->kset_current->rsi_next;
  else
    kset->kset_current = kset->kset_current->rsi_prev;
  if (!kset->kset_current)
    {
      if (kset->kset_is_complete)
	return ((caddr_t) SQL_NO_DATA_FOUND);
      if ((caddr_t) SQL_NO_DATA_FOUND == cs_kset_move (cs, dir))
	return ((caddr_t) SQL_NO_DATA_FOUND);
      if (FWD == dir)
	kset->kset_current = kset->kset_last;
      else
	kset->kset_current = kset->kset_first;

    }
  return ((caddr_t) SQL_SUCCESS);
}


void
cs_kset_co_pos (cursor_state_t * cs, int mode)
{
  int inx;
  keyset_t *kset = cs->cs_keyset;
  if (mode == cs->cs_keyset->kset_co_pos)
    return;
  for (inx = 0; inx < cs->cs_rowset_fill - 1; inx++)
    {
      cs_kset_next (cs, mode == KSET_CO_LAST ? FWD : BWD);
    }
  kset->kset_co_pos = mode;
}



caddr_t
cs_kset_relative (cursor_state_t * cs, int irow)
{
  caddr_t err = (caddr_t) SQL_SUCCESS;
  int dir = FWD;
  int inx;
  cs_kset_co_pos (cs, KSET_CO_FIRST);
  if (irow < 0)
    {
      irow = -irow;
      dir = BWD;
    }
  for (inx = 0; inx < irow; inx++)
    err = cs_kset_next (cs, dir);
  return err;
}

void
stmt_kset_fetch_inner (srv_stmt_t * stmt, long ftype, long irow, long n_rows)
{
  int inx;
  caddr_t err;
  cursor_state_t *cs = stmt->sst_cursor_state;
  keyset_t *kset = cs->cs_keyset;

  if (_SQL_FETCH_FIRST == ftype)
    {
      err = cs_init_keyset (cs, _SQL_FETCH_FIRST);
      kset = cs->cs_keyset;
      kset->kset_current = kset->kset_first;
      kset->kset_co_pos = KSET_CO_LAST;
    }
  else if (_SQL_FETCH_LAST == ftype)
    {
      err = cs_init_keyset (cs, _SQL_FETCH_LAST);
      kset = cs->cs_keyset;
      kset->kset_current = kset->kset_last;
      kset->kset_co_pos = KSET_CO_FIRST;
    }
  else if (_SQL_FETCH_RELATIVE == ftype)
    {
      err = cs_kset_relative (cs, irow);
	  irow = 0;
      kset = cs->cs_keyset;
      if ((caddr_t) SQL_NO_DATA_FOUND == err)
	{
	  if (irow < 0)
	    kset->kset_current = kset->kset_first;
	}
      ftype = _SQL_FETCH_NEXT;
      kset->kset_co_pos = KSET_CO_LAST;
    }
  else if (_SQL_FETCH_NEXT == ftype)
    {
      cs_kset_co_pos (cs, KSET_CO_LAST);
      err = cs_kset_next (cs, _SQL_FETCH_NEXT);
    }
  else if (_SQL_FETCH_PRIOR == ftype)
    {
      cs_kset_co_pos (cs, KSET_CO_FIRST);
      err = cs_kset_next (cs, _SQL_FETCH_PRIOR);
    }
  cs_reset_kset_rowset (cs, n_rows);

  if (irow > 0)
    {
      for (inx = 0; inx < irow; inx++)
	if ((caddr_t) SQL_SUCCESS == err)
	  err = cs_kset_next (cs, ftype);
    }
  else
    if (!kset->kset_current && kset->kset_is_complete)
      err = (caddr_t) SQL_NO_DATA_FOUND;

  if ((caddr_t) SQL_NO_DATA_FOUND == err)
    {
      cs->cs_window_pos = IS_FWD (ftype) && _SQL_FETCH_RELATIVE != ftype
	? CS_WINDOW_END : CS_WINDOW_START;
      cs_send_at_end (cs);
      return;
    }
  cs->cs_window_pos = CS_WINDOW_ROW;

  for (inx = 0; inx < n_rows; inx++)
    {
      if ((caddr_t) SQL_NO_DATA_FOUND == err)
	break;
      if ((caddr_t) SQL_SUCCESS == err)
	{
	  cs->cs_rowset[inx] = kset->kset_current;
	  cs->cs_rowset_fill++;
	}
      if (inx == n_rows - 1)
	break;
      err = cs_kset_next (cs, ftype);
    }
  if (_SQL_FETCH_PRIOR == ftype && cs->cs_rowset_fill < n_rows)
    {
      stmt_kset_fetch_inner (stmt, _SQL_FETCH_FIRST, 0, n_rows);
      return;
    }
  cs_fix_rowset_dir (cs, ftype);

  if (CS_IS_PL_CURSOR (cs))
    {
      if (cs->cs_rowset_fill != 1)
	sqlr_new_error ("22003", "SR222", "PL cursor with a rowset greater then 1");
      if (_SQL_CURSOR_STATIC == CS_CR_TYPE (cs))
	{
	  CS_PL_SET_OUTPUT (cs, cs->cs_rowset[0]->rsi_row);
	}
      else
	{
	  cs_set_pos_1 (cs, _SQL_REFRESH, inx, NULL, CALLER_LOCAL, &err, NULL);
	  if (err != (caddr_t) SQL_SUCCESS && err != (caddr_t) SQL_NO_DATA_FOUND)
	    return;
	}
      inx = 1;
    }
  else
    {
      for (inx = 0; inx < cs->cs_rowset_fill; inx++)
	{
	  if (_SQL_CURSOR_STATIC == CS_CR_TYPE (cs))
	    PrpcAddAnswer ((caddr_t) cs->cs_rowset[inx]->rsi_row, DV_ARRAY_OF_POINTER, 1, 0);
	  else
	    {
	      cs_set_pos_1 (cs, _SQL_REFRESH, inx, NULL, CALLER_LOCAL, &err, NULL);
	      if (err != (caddr_t) SQL_SUCCESS && err != (caddr_t) SQL_NO_DATA_FOUND)
		return;
	    }
	}
    }
  if (inx < n_rows)
    cs_send_at_end (cs);
}


void
cs_keyset_bookmark (cursor_state_t * cs, caddr_t * order, caddr_t * id)
{
  keyset_t * kset = cs->cs_keyset;
  rowset_item_t * rsi = kset->kset_first;
  while (rsi)
    {
      if (box_equal ((box_t) rsi->rsi_id, (box_t) id))
	{
	  kset->kset_current = rsi;
	  kset->kset_co_pos = KSET_CO_FIRST;
	  return;
	}
      rsi = rsi->rsi_next;
    }

  {
    /*stmt_options_t *so = cs->cs_opts;*/
    /*int cr_type = CS_CR_TYPE (cs);*/
    int kssz = (int) cs->cs_opts->so_keyset_size;
    keyset_t *kset = cs->cs_keyset;


    BOX_SET (cs->cs_window_first, order);
    BOX_SET (cs->cs_window_first_id, id);

    if (0 == kssz)
      kssz = MAX_STATIC_CURSOR_ROWS;
    if (!kset)
      {
	kset = kset_create (kssz);
	cs->cs_keyset = kset;
      }

    kset_clear (cs->cs_keyset);
    cs->cs_client_data = (void *) FWD;
    stmt_dyn_fetch_inner (cs->cs_stmt, _SQL_FETCH_RELATIVE, 0, kssz,
			  cs_keyset_add);
    if (kset->kset_count < kssz)
      cs->cs_keyset_pos = KSET_AT_END;
    else
      cs->cs_keyset_pos = KSET_MIDDLE;
    kset->kset_is_complete = 0;
    kset->kset_current = kset->kset_first;
    kset->kset_co_pos = KSET_CO_FIRST;
  }
}


void
cs_position_bookmark (cursor_state_t * cs, caddr_t bookmark,
		      long *ftype, long *irow)
{
  query_cursor_t *qc = cs->cs_query->qr_cursor;
  int cr_type = CS_CR_TYPE (cs);
  dtp_t dtp = DV_TYPE_OF (bookmark);
  if (cr_type == _SQL_CURSOR_STATIC)
    {
      if (dtp != DV_LONG_INT)
	sqlr_new_error ("HY111", "SR223", "Non static bookmark for a static cursor");
      *ftype = _SQL_FETCH_ABSOLUTE;
      *irow = (long) (unbox (bookmark) + *irow);
      return;
    }

  if (IS_NONLEAF_DTP(dtp))
    {
      caddr_t *order;
      caddr_t *id;
      if (dtp != DV_ARRAY_OF_POINTER || BOX_ELEMENTS (bookmark) != 2)
	sqlr_new_error ("HY111", "SR338", "Malformed bookmark");
      order = ((caddr_t **) bookmark)[0];
      id = ((caddr_t **) bookmark)[1];
      if (BOX_ELEMENTS (id) != (uint32) qc->qc_n_id_cols
	  || BOX_ELEMENTS (qc->qc_order_cols) != BOX_ELEMENTS (order))
	{
	  sqlr_new_error ("HY111", "SR224",
	      "Incompatible bookmark. Must be identical ordering and primary key columns");
	}
      if (cr_type == _SQL_CURSOR_KEYSET_DRIVEN)
	cs_keyset_bookmark (cs, order, id);
      else
	{
	  BOX_SET (cs->cs_window_first, order);
	  BOX_SET (cs->cs_window_first_id, id);
	  cs->cs_window_pos = CS_WINDOW_ROW;
	}
      *ftype = _SQL_FETCH_RELATIVE;
      /* preserve irow */
      dk_free_tree (bookmark);
    }
  else
    sqlr_new_error ("HY111", "SR225", "Static bookmark for a dynamic / keyset cursor");
}


void
stmt_ext_fetch (srv_stmt_t * stmt, long ftype, long irow, caddr_t bookmark, int rssz)
{
  caddr_t err;
  QR_RESET_CTX
  {
    cursor_state_t *cs = stmt->sst_cursor_state;
    int cr_type = cs->cs_query->qr_cursor->qc_cursor_type;
    int n_rows, send_extra_end = 0;
    cs->cs_opts->so_prefetch = rssz;
    n_rows = rssz;
    if (_SQL_FETCH_NEXT == ftype
	&& CS_WINDOW_START == cs->cs_window_pos)
      ftype = _SQL_FETCH_FIRST;
    if (_SQL_FETCH_PRIOR == ftype
	&& CS_WINDOW_END == cs->cs_window_pos)
      ftype = _SQL_FETCH_LAST;

    if (_SQL_FETCH_RELATIVE == ftype)
      {
	if (CS_WINDOW_ROW == cs->cs_window_pos)
	  {
	    if (irow < 0 && irow <= -rssz)
	      {
		ftype = _SQL_FETCH_PRIOR;
		irow = (-irow) - rssz;
	      }
	    else if (irow > 0 && irow >= rssz)
	      {
		ftype = _SQL_FETCH_NEXT;
		irow -= rssz;
	      }
	  }
	else
	  {
	    ftype = _SQL_FETCH_ABSOLUTE;
	    if ((CS_WINDOW_START == cs->cs_window_pos && irow < 0)
		|| (CS_WINDOW_END == cs->cs_window_pos && irow > 0))
	      {
		cs_send_at_end (cs);
		POP_QR_RESET; /*!!!*/
		return;
	      }
	  }
      }
    if (_SQL_FETCH_BOOKMARK == ftype)
      {
	cs_position_bookmark (cs, bookmark, &ftype, &irow);
	if (irow < 0 && CS_CR_TYPE (cs) == _SQL_CURSOR_STATIC)
	  {
	    cs->cs_window_pos = CS_WINDOW_START;
	    cs_send_at_end (cs);
	    POP_QR_RESET; /*!!!*/
	    return;
	  }
      }
    if (_SQL_FETCH_ABSOLUTE == ftype)
      {
	if (0 == irow)
	  {
	    cs->cs_window_pos = CS_WINDOW_START;
	    cs_send_at_end (cs);
	    POP_QR_RESET; /*!!!*/
	    return;
	  }
	if (irow < 0)
	  {
	    if (-irow < rssz)
	      {
		ftype = _SQL_FETCH_LAST;
		n_rows = -irow;
		irow = 0;
		send_extra_end = 1;
	      }
	    else
	      {
		ftype = _SQL_FETCH_LAST;
		irow = (-irow) - rssz;
	      }
	  }
	else if (irow > 0)
	  {
	    ftype = _SQL_FETCH_FIRST;
	    irow--;
	  }
      }



    switch (cr_type)
      {
      case _SQL_CURSOR_DYNAMIC:
	stmt_dyn_fetch_inner (stmt, ftype, irow, n_rows, NULL);
	break;
      case _SQL_CURSOR_STATIC:
      case _SQL_CURSOR_KEYSET_DRIVEN:
	stmt_kset_fetch_inner (stmt, ftype, irow, n_rows);
	break;

      }
    if (send_extra_end && cs->cs_rowset_fill == n_rows)
      cs_send_at_end (cs);
  }
  QR_RESET_CODE
  {
    POP_QR_RESET;
    if (RST_ERROR == reset_code)
      err = thr_get_error_code (THREAD_CURRENT_THREAD);
    else
      err = srv_make_new_error ("42000", "SR226", "Misc. cursor error");
    if (STMT_IS_PL_CURSOR (stmt))
      stmt->sst_pl_error = err;
    else
      {
	PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
	dk_free_tree (err);
      }
    return;
  }
  END_QR_RESET;
}

/* in sqlrun.c */
void
cli_send_row_count (client_connection_t * cli, long n_affected, caddr_t * ret,
    du_thread_t * thr);

int null_unspecified_params;

void
stmt_start_scroll (client_connection_t * cli, srv_stmt_t * stmt,
		   caddr_t ** params, char *cursor_name,
		   stmt_options_t * opts)
{
  caddr_t volatile err = NULL;
  int is_timeout;
  cursor_state_t * volatile cs = NULL;
  volatile long start = prof_on ? get_msec_real_time () : 0;

  lock_trx_t *lt = cli->cli_trx;
  if (!STMT_IS_PL_CURSOR (stmt))
    {
      is_timeout = lt_enter (cli->cli_trx);

      if (LTE_OK != is_timeout)
	{
	  MAKE_TRX_ERROR (is_timeout, err, LT_ERROR_DETAIL (cli->cli_trx));
	  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, FINAL, 1);
	  dk_free_tree (err);
	  mutex_leave (cli->cli_mtx);
	  thrs_printf ((thrs_fo, "ses %p thr:%p in start_scroll1\n", IMMEDIATE_CLIENT, THREAD_CURRENT_THREAD));
	  DKST_RPC_DONE (IMMEDIATE_CLIENT);
	  return;
	}
    }


  QR_RESET_CTX
    {
      if (!STMT_IS_PL_CURSOR (stmt) && cursor_name && cli_find_cs (cli, cursor_name))
	{
	  err = srv_make_new_error ("3C000", "SR227", "Non unique cursor name");
	  mutex_leave (cli->cli_mtx);
	}
      else
	{
	  int nCursorType = stmt->sst_query->qr_cursor_type;
	  long nActualParams = params && params[0] ? BOX_ELEMENTS(params[0]) : 0;
	  long nRequiredParams = dk_set_length(stmt->sst_query->qr_parms);

	  if (nActualParams < nRequiredParams)
	    {
	      if (null_unspecified_params)
		{
		  caddr_t *new_box = (caddr_t *)
		      dk_alloc_box(nRequiredParams * sizeof(caddr_t), DV_ARRAY_OF_POINTER);
		  long nParam;

		  for (nParam = 0; nParam < nActualParams; nParam++)
		    new_box[nParam] = params[0][nParam];
		  for (nParam = nParam; nParam < nRequiredParams; nParam++)
		    new_box[nParam] = dk_alloc_box(0, DV_DB_NULL);
		  dk_free_box((box_t) params[0]);
		  params[0] = new_box;
		  nActualParams = nRequiredParams;
		}
	      else
		{
		  if (!STMT_IS_PL_CURSOR (stmt))
		    mutex_leave (cli->cli_mtx);
		  sqlr_new_error ("07001", "SR228", "Too few actual parameters");
		}
	    }
	  if (_SQL_CURSOR_STATIC ==  nCursorType || _SQL_CURSOR_KEYSET_DRIVEN == nCursorType)
	    {
	      if (nActualParams >= nRequiredParams)
		{
		  stmt->sst_cursor_state = cs_create (stmt, params[0], opts, cursor_name);

		  cs = stmt->sst_cursor_state;
		  if (!STMT_IS_PL_CURSOR (stmt))
		    mutex_leave (cli->cli_mtx);
		  cs->cs_window_pos = CS_WINDOW_START;
		  err = (caddr_t)cs_init_keyset(cs, _SQL_FETCH_FIRST);
		  if ((caddr_t) SQL_SUCCESS == err)
		    cs->cs_window_pos = CS_WINDOW_START;
		}
	    }
	  else
	    {
	      err = (caddr_t)SQL_SUCCESS;
	      stmt->sst_cursor_state = cs_create (stmt, params[0], opts, cursor_name);
	      if (!STMT_IS_PL_CURSOR (stmt))
		mutex_leave (cli->cli_mtx);
	    }
	}
    }
  QR_RESET_CODE
    {
      POP_QR_RESET;
      if (RST_ERROR == reset_code)
	err = thr_get_error_code (THREAD_CURRENT_THREAD);
      else
	err = srv_make_new_error ("42000", "SR229", "Misc. cursor error");
    }
  END_QR_RESET;


  if (!STMT_IS_PL_CURSOR (stmt))
    {
      IN_TXN;
      is_timeout = lt_leave (lt);
      LEAVE_TXN;
      if (LTE_OK != is_timeout)
	{
	  MAKE_TRX_ERROR (is_timeout, err, LT_ERROR_DETAIL (lt));
	  PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, FINAL, 1);
	  dk_free_tree (err);
	  thrs_printf ((thrs_fo, "ses %p thr:%p in start_scroll2\n", IMMEDIATE_CLIENT, THREAD_CURRENT_THREAD));
	  DKST_RPC_DONE (IMMEDIATE_CLIENT);
	  return;
	}
      else if (err != SQL_SUCCESS)
	PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
      else if (cs) {
	sql_warnings_send_to_cli ();
	cli_send_row_count(cs->cs_client, cs->cs_keyset->kset_count, NULL, THREAD_CURRENT_THREAD);
      } else
	{
	  sql_warnings_send_to_cli ();
	  PrpcAddAnswer((caddr_t)0, DV_ARRAY_OF_POINTER, 1, 1);
	}

      thrs_printf ((thrs_fo, "ses %p thr:%p in start_scroll3\n", IMMEDIATE_CLIENT, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (IMMEDIATE_CLIENT);
      session_flush (IMMEDIATE_CLIENT); /* flush blob only after you've left the statement */
      if (start && prof_on)
	prof_exec (stmt->sst_query, NULL, get_msec_real_time () - start,
	    PROF_EXEC | (err != NULL ? PROF_ERROR : 0));
      dk_free_tree (err);
    }
  else
    {
      stmt->sst_pl_error = err;
      /* the qr is usually a result of sqlc_subquery, so no qr_text */
      if (start && prof_on)
	prof_exec (stmt->sst_query, "PL Scrollable cursor", get_msec_real_time () - start,
	    PROF_EXEC | (err != NULL ? PROF_ERROR : 0));
    }
}


void
stmt_scroll_close (srv_stmt_t * stmt)
{
  cursor_state_t * cs = stmt->sst_cursor_state;
  client_connection_t * cli = cs->cs_client;
  stmt->sst_cursor_state = NULL;
  if (!STMT_IS_PL_CURSOR (stmt))
    {
      ASSERT_IN_MTX (cs->cs_client->cli_mtx);
      LEAVE_CLIENT (cli);
      cs_free (cs);
      IN_CLIENT (cli);
    }
  else
      cs_free (cs);
}


void
sf_sql_extended_fetch (caddr_t stmt_id, long type, long irow, long n_rows,
		       long is_autocommit, caddr_t bookmark)
{
  int is_timeout;
  caddr_t err;
  srv_stmt_t **place;
  srv_stmt_t *stmt = NULL;
  lock_trx_t *lt;
  dk_session_t *client = IMMEDIATE_CLIENT;
  client_connection_t *cli = DKS_DB_DATA (IMMEDIATE_CLIENT);

  CHANGE_THREAD_USER(cli->cli_user);

  if (type == _SQL_FETCH_PRIOR || type == _SQL_FETCH_NEXT ||
      type == _SQL_FETCH_LAST || type == _SQL_FETCH_FIRST)
    irow = 0;
  mutex_enter (cli->cli_mtx);
  place = (srv_stmt_t **) id_hash_get (cli->cli_statements, (caddr_t) & stmt_id);
  dk_free_box (stmt_id);
  lt = cli->cli_trx;
  if (place)
    stmt = *place;
  if (!stmt || !stmt->sst_cursor_state)
    {
      mutex_leave (cli->cli_mtx);
      err = srv_make_new_error ("S1010", "SR230",
	  "Statement not executing or not scrollable cursor in SQLExtendedFetch");
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);
      dk_free_tree (err);
      thrs_printf ((thrs_fo, "ses %p thr:%p in ext_fetch1\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      return;
    }
  mutex_leave (cli->cli_mtx);
  if (LTE_OK != (is_timeout = lt_enter (cli->cli_trx)))
    {
      caddr_t err;
      MAKE_TRX_ERROR (is_timeout, err, LT_ERROR_DETAIL (lt));
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, FINAL, 1);
      dk_free_tree (err);
      thrs_printf ((thrs_fo, "ses %p thr:%p in ext_fetch2\n", client, THREAD_CURRENT_THREAD));
      DKST_RPC_DONE (client);
      return;
    }
  stmt_ext_fetch (stmt, type, irow, bookmark, n_rows);

  IN_TXN;
  is_timeout = lt_leave (lt);
  LEAVE_TXN;

  if (is_autocommit)
    {
      caddr_t err = cli_transact (cli, SQL_COMMIT, NULL);
      PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 0);
      dk_free_tree (err);
    }

  thrs_printf ((thrs_fo, "ses %p thr:%p in ext_fetch3\n", client, THREAD_CURRENT_THREAD));
  DKST_RPC_DONE (client);
  session_flush (client);
}


void
cli_set_scroll_current_ofs (client_connection_t * cli, caddr_t * current_ofs)
{
  int inx;
  int len = BOX_ELEMENTS (current_ofs);
  for (inx = 0; inx < len; inx += 2)
    {
      if (current_ofs[inx])
	{
	  cursor_state_t * cs = cli_find_cs (cli, current_ofs[inx]);
	  if (cs)
	    cs->cs_rowset_current_of = (long) unbox (current_ofs[inx + 1]);
	}
    }
}


caddr_t
cs_nth_id_col (cursor_state_t * cs, char * tb_name, int nth)
{
  int idfill = 0, inx;
  query_cursor_t * qc = cs->cs_query->qr_cursor;
  DO_BOX (id_cols_t *, idc, inx, qc->qc_id_cols)
    {
      if (0 == strcmp (idc->idc_table, tb_name))
	{
	  rowset_item_t * rsi = cs->cs_rowset[cs->cs_rowset_current_of];
	  return (rsi->rsi_id[idfill + nth]);
	}
      idfill += BOX_ELEMENTS (idc->idc_pos);
    }
  END_DO_BOX;
  sqlr_new_error ("42S02", "SR231", "Cursor does not have table %s", tb_name);
  return NULL; /*dummy*/
}


caddr_t
bif_cr_id_part (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t * qi = (query_instance_t*) qst;
  caddr_t cr_name = bif_string_arg (qst, args, 0, "cr_pk_col");
  caddr_t tb_name = bif_string_arg (qst, args, 1, "cr_pk_col");
  long nth = (long) bif_long_arg (qst, args, 2, "cr_pk_col");
  cursor_state_t * cs;
  IN_CLIENT (qi->qi_client);
  cs = cli_find_cs (qi->qi_client, cr_name);
  LEAVE_CLIENT (qi->qi_client);
  if (!cs)
    sqlr_new_error ("34000", "SR232", "No cursor %s", cr_name);
  return (cs_nth_id_col (cs, tb_name, nth));
}


static caddr_t
bif_scroll_cr_init (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t arg = bif_arg (qst, args, 0, "__scroll_cr_init");
  srv_stmt_t *stmt;
  query_t *qr;

  if (DV_TYPE_OF (arg) != DV_LONG_INT)
    sqlr_new_error ("22023", "SR233", "Wrong type of argument to __scroll_cr_init");

  qr = (query_t *) unbox_ptrlong (arg);
  stmt = (srv_stmt_t *) dk_alloc_box_zero (sizeof (srv_stmt_t), DV_PL_CURSOR);
  stmt->sst_is_pl_cursor = 1;
  stmt->sst_query = qr;
  qr->qr_ref_count++;

  return (caddr_t) stmt;
}

srv_stmt_t *
bif_pl_cursor_arg (caddr_t * qst, state_slot_t ** args, int nth, char *func)
{
  caddr_t arg = bif_arg (qst, args, nth, func);
  dtp_t dtp = DV_TYPE_OF (arg);
  if (dtp != DV_PL_CURSOR)
    sqlr_new_error ("22023", "SR234",
	"Function %s needs a cursor as argument %d, not an arg of type %s (%d)",
	func, nth + 1, dv_type_title (dtp), dtp);
  return (srv_stmt_t *) arg;
}

static caddr_t
bif_scroll_cr_open (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  srv_stmt_t *stmt = bif_pl_cursor_arg (qst, args, 0, "__scroll_cr_open");
  query_instance_t *qi = (query_instance_t *) qst;
  caddr_t params_box_buf[5];
  caddr_t params_box;
  caddr_t **params;
  stmt_options_t *opts = (stmt_options_t *)  dk_alloc_box_zero (sizeof (stmt_options_t), DV_ARRAY_OF_POINTER);
  uint32 inx, n_pars = BOX_ELEMENTS (args) - 1;

  BOX_AUTO (params_box, params_box_buf, sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  params = (caddr_t **)params_box;

  opts->so_use_bookmarks = 1;
  params[0] = (caddr_t *) dk_alloc_box_zero (n_pars * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  for (inx = 0; inx < n_pars; inx++)
    {
      params[0][inx] = box_copy_tree (bif_arg (qst, args, inx + 1, "__scroll_cr_open"));
    }
  memset (opts, 0, sizeof (opts));
  opts->so_concurrency = SQL_CONCUR_LOCK;
  opts->so_cursor_type = stmt->sst_query->qr_cursor_type;

  stmt_start_scroll (qi->qi_client, stmt, params, box_copy (args[0]->ssl_name), opts);
  BOX_DONE (params_box, params_box_buf);
  if (stmt->sst_pl_error)
    sqlr_resignal (stmt->sst_pl_error);
  return NULL;
}


static caddr_t
bif_scroll_cr_fetch (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  srv_stmt_t *stmt = bif_pl_cursor_arg (qst, args, 0, "__scroll_cr_fetch");
  cursor_state_t *cs;
  long type = (long) bif_long_arg (qst, args, 1, "__scroll_cr_fetch");
  caddr_t bookmark = NULL;
  int n_slots = BOX_ELEMENTS (args) - 3;
  long irow = 0; /* row offset for relative and absolute fetch */

  if (!stmt->sst_cursor_state)
    sqlr_new_error ("24000", "SR235", "Virtuoso/PL Scrollable cursor not opened");
  cs = stmt->sst_cursor_state;

  if (type == _SQL_FETCH_ABSOLUTE || type == _SQL_FETCH_RELATIVE)
    irow = (long) bif_long_arg (qst, args, 2, "__scroll_cr_fetch");
  else
    bookmark = box_copy_tree (bif_arg (qst, args, 2, "__scroll_cr_fetch"));

  dk_free_tree ((box_t) cs->cs_pl_output_row);
  cs->cs_pl_output_row = NULL;

  stmt_ext_fetch (stmt, type, irow, bookmark, 1);
  if (stmt->sst_pl_error)
    {
      caddr_t err = stmt->sst_pl_error;
      dk_free_tree ((box_t) cs->cs_pl_output_row);
      cs->cs_pl_output_row = NULL;
      stmt->sst_pl_error = NULL;
      sqlr_resignal (err);
    }

  if (cs->cs_pl_output_row)
    {
      if (BOX_ELEMENTS (cs->cs_pl_output_row) - 3 != n_slots)
	{
	  dk_free_tree ((box_t) cs->cs_pl_output_row);
	  cs->cs_pl_output_row = NULL;
	  sqlr_new_error ("07001", "SR236",
	      "scrollable fetch with different number of output columns");
	}
      else
	{
	  int inx;
	  for (inx = 0; inx < n_slots; inx++)
	    qst_set (qst, args[inx + 3], box_copy_tree (cs->cs_pl_output_row[inx + 1]));
	}
    }
  if (cs->cs_pl_state == CS_PL_AT_END)
    *err_ret = (caddr_t) SQL_NO_DATA_FOUND;
  else if (cs->cs_pl_state == CS_PL_DELETED)
    *err_ret = srv_make_new_error ("HY109", "SR237", "Row deleted");
  return NULL;
}


static caddr_t
bif_scroll_cr_close (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  srv_stmt_t *stmt = bif_pl_cursor_arg (qst, args, 0, "__scroll_cr_close");
  if (stmt->sst_cursor_state)
    stmt_scroll_close (stmt);
  return NULL;
}


static caddr_t
bif_bookmark (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  srv_stmt_t *stmt = bif_pl_cursor_arg (qst, args, 0, "bif_bookmark");
  caddr_t *row;
  if (!stmt->sst_cursor_state)
    sqlr_new_error ("24000", "SR238", "Virtuoso/PL Scrollable cursor not opened");
  if (!stmt->sst_cursor_state->cs_pl_output_row)
    sqlr_new_error ("HY109", "SR239", "Virtuoso/PL Scrollable cursor not positioned on a row");
  row = stmt->sst_cursor_state->cs_pl_output_row;
  return (box_copy_tree (row[BOX_ELEMENTS (row) - 2]));
}


int
pl_cursor_destroy (caddr_t box)
{
  srv_stmt_t *stmt = (srv_stmt_t *)box;
  if (stmt->sst_cursor_state)
    stmt_scroll_close (stmt);
  if (stmt->sst_qst)
    qi_free ((caddr_t *)stmt->sst_qst);
  return 0;
}

int
pl_cursor_serialize (void *cursor, dk_session_t *ses)
{
  session_buffered_write_char (DV_SHORT_STRING, ses);
  session_buffered_write_char ((char) 8, ses);
  session_buffered_write (ses, "<cursor>", 8);
  return 0;
}

/*				  0	    1        */
/*				  012345678901234567 */
char __scroll_cr_init[17]	= "__scroll_cr_init";
char __scroll_cr_open[17]	= "__scroll_cr_open";
char __scroll_cr_close[18]	= "__scroll_cr_close";
char __scroll_cr_fetch[18]	= "__scroll_cr_fetch";


static caddr_t
bif_burst_mode_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_session_t *dks = IMMEDIATE_CLIENT_OR_NULL;
  mutex_enter (thread_mtx);
  if (!DK_CURRENT_THREAD->dkt_requests[0]->rq_is_second &&
      dks->dks_thread_state == DKST_RUN
#if defined(INPROCESS_CLIENT) /*&& !defined(NO_THREAD)*/
      && !SESSION_IS_INPROCESS (dks)
#endif
      )
    {
      thrs_printf ((thrs_fo,
	    "bif_burst_mode_set switch to burst on ses %p thr:%p\n",
	    dks, THREAD_CURRENT_THREAD));
      mutex_leave (thread_mtx);
      PrpcCheckOut (dks);
      mutex_enter (thread_mtx);
      dks->dks_thread_state = DKST_BURST;
      mutex_leave (thread_mtx);
      return box_num (1);
    }
  else
    {
      thrs_printf ((thrs_fo,
	    "bif_burst_mode_set on already burst ses %p thr:%p\n",
	    dks, THREAD_CURRENT_THREAD));
      mutex_leave (thread_mtx);
      return box_num (0);
    }
}


void
bif_cursors_init (void)
{
  dk_mem_hooks (DV_PL_CURSOR, box_non_copiable, pl_cursor_destroy, 0);
  PrpcSetWriter (DV_PL_CURSOR, pl_cursor_serialize);

  bif_define ("__set_pos", bif_sql_set_pos);
  bif_define ("__cr_id_part", bif_cr_id_part);

/* this is done to avoid the dependency between config file & internal bif names in sqlprocc.c's cv_call */
  if (CM_UPPER == case_mode)
    {
      sqlp_upcase(__SCROLL_CR_INIT);
      sqlp_upcase(__SCROLL_CR_OPEN);
      sqlp_upcase(__SCROLL_CR_CLOSE);
      sqlp_upcase(__SCROLL_CR_FETCH);
    }
  bif_define ( __SCROLL_CR_INIT, bif_scroll_cr_init);
  bif_define ( __SCROLL_CR_OPEN, bif_scroll_cr_open);
  bif_define ( __SCROLL_CR_CLOSE, bif_scroll_cr_close);
  bif_define ( __SCROLL_CR_FETCH, bif_scroll_cr_fetch);

  bif_define ("bookmark", bif_bookmark);
  bif_define_typed ("tree_md5", bif_tree_md5, &bt_varchar);
  bif_define_typed ("__burst_mode_set", bif_burst_mode_set, &bt_integer);
}


caddr_t bif_iri_to_id (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_iri_to_id_nosignal (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

int
bif_is_relocatable (bif_t bif)
{
  bif_metadata_t * bmd;
  if (
      /* scrollable cursors */
      bif_sql_set_pos == bif
      || bif_cr_id_part == bif
      || bif_scroll_cr_init == bif
      || bif_scroll_cr_open == bif
      || bif_scroll_cr_fetch == bif
      || bif_scroll_cr_close == bif
      || bif_scroll_cr_close == bif

      /* UDTs */
      || udt_is_udt_bif (bif)

      /* cast (let the VDB layer decide) */
      || bif_convert == bif
      )
    return 0;

  bmd = find_bif_metadata_by_bif (bif);
  if (bmd && bmd->bmd_ret_type && DV_IRI_ID ==  bmd->bmd_ret_type->bt_dtp)
    return 0;
  if (bif_iri_to_id == bif || bif_iri_to_id_nosignal == bif)
    return 0;

  return 1;
}

placeholder_t *
cs_place (query_instance_t * qi, cursor_state_t * cs, dbe_table_t * tb)
{
    sqlr_new_error ("HY109", "SR241", "current of not supported");

#ifndef KEYCOMP
  int inx;
  placeholder_t * place = NULL;
  dbe_key_t * key = tb->tb_primary_key;
  dtp_t key_image[PAGE_DATA_SZ];
  caddr_t err = NULL;
  caddr_t *qst = (caddr_t *) qi;
  int v_fill = key->key_key_var_start;
  int ruling_part_bytes;
  SHORT_SET (&key_image[IE_NEXT_IE], 0);
  SHORT_SET (&key_image[IE_KEY_ID], key->key_id);

  inx = 0;
  DO_SET (dbe_column_t *, col, &tb->tb_primary_key->key_parts)
    {
      if (inx >= tb->tb_primary_key->key_n_significant)
	break;
      else
	{
	  caddr_t data = cs_nth_id_col (cs, tb->tb_name, inx);
	  dbe_col_loc_t * cl = key_find_cl (key, col->col_id);
	  if (!cl)
	    sqlr_new_error ("42000", "SR463", "No cl");
	  row_set_col (&key_image[IE_FIRST_KEY], cl, data, &v_fill, ROW_MAX_DATA, key, &err, NULL, NULL, qst);
	  if (err)
	    break;
	}
      inx ++;
    }
  END_DO_SET ();
  if (err)
    sqlr_resignal (err);
  ruling_part_bytes = v_fill - key->key_row_var_start + key->key_key_var_start;
  if (ruling_part_bytes > MAX_RULING_PART_BYTES)
    {
      sqlr_new_error ("22026", "SR464", "Key too long, index %.300s, ruling part is %d bytes that exceeds %d byte limit",
        key->key_name, ruling_part_bytes, MAX_RULING_PART_BYTES );
    }
  row_deref (qst, (caddr_t) &key_image[0], &place, NULL, PL_EXCLUSIVE);
  if (!place)
    sqlr_new_error ("HY109", "SR241", "Row referenced in where current of not present");
  return place;
#else
  return NULL; /* keep compiler happy */
#endif
}


int
current_of_node_scrollable (current_of_node_t * co, query_instance_t * qi, char * cr_name)
{
  cursor_state_t * cs;
  IN_CLIENT (qi->qi_client);
  cs = cli_find_cs (qi->qi_client, cr_name);
  LEAVE_CLIENT (qi->qi_client);
  if (!cs)
    return 0;

  qst_set ((caddr_t*) qi, co->co_place, (caddr_t)
	   cs_place (qi, cs, co->co_table));
  qn_send_output ((data_source_t *) co, (caddr_t*) qi);
  return 1;
}


ptrlong
sqlp_cursor_name_to_type (caddr_t name)
{
  if (!stricmp (name, "dynamic"))
    return _SQL_CURSOR_DYNAMIC;
  else if (!stricmp (name, "keyset"))
    return _SQL_CURSOR_KEYSET_DRIVEN;
  else if (!stricmp (name, "static"))
    return _SQL_CURSOR_STATIC;
  else
    return _SQL_CURSOR_FORWARD_ONLY;
}

ptrlong
sqlp_fetch_type_to_code (caddr_t name)
{
  if (!stricmp (name, "next"))
    return _SQL_FETCH_NEXT;
  else if (!stricmp (name, "previous"))
    return _SQL_FETCH_PRIOR;
  else if (!stricmp (name, "bookmark"))
    return _SQL_FETCH_BOOKMARK;
  else if (!stricmp (name, "first"))
    return _SQL_FETCH_FIRST;
  else if (!stricmp (name, "last"))
    return _SQL_FETCH_LAST;
  else if (!stricmp (name, "absolute"))
    return _SQL_FETCH_ABSOLUTE;
  else if (!stricmp (name, "relative"))
    return _SQL_FETCH_RELATIVE;
  else
    yy_new_error ("Invalid fetch direction in FETCH", "37000", "SQ169");
  /* dummy */
  return -1;
}

