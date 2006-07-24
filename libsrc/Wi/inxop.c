/*
 *  inxop.c
 *
 *  $Id$
 *
 *  SQL query execution
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
#include "xmlnode.h"
#include "sqlfn.h"
#include "sqlcomp.h"
#include "lisprdr.h"
#include "sqlopcod.h"
#include "security.h"
#include "sqlbif.h"
#include "sqltype.h"
#include "libutil.h"
#include "arith.h"





#define QST_SET(qst, ssl, v) \
  ((caddr_t*)qst)[ssl->ssl_index] = (caddr_t) v



int
itc_near_random (it_cursor_t * itc, placeholder_t * pl, buffer_desc_t ** buf_ret,
		 ptrlong * n_hits, int is_asc)
{
  /* set by pl, see if on same page. If not, 
   * do full lookup.  If asc order, a negative can be confirmed on local page if max of page less than key sought.*/
  int res;
  ITC_IN_MAP (itc);
  page_wait_access (itc, pl->itc_page, NULL, NULL, buf_ret, PA_READ, RWG_WAIT_DATA);
  if (itc->itc_to_reset <= RWG_WAIT_DATA
      && (*buf_ret)->bd_content_map->pm_count)
    {
      page_map_t * pm = (*buf_ret)->bd_content_map;
      if (itc == (it_cursor_t *) pl)
	{
	  ITC_IN_MAP (itc);
	  itc_unregister (itc, INSIDE_MAP);
	}
      else 
	{
	  itc->itc_page = pl->itc_page;
	}
      itc->itc_landed = 0;
      if (is_asc)
	{
	  ITC_LEAVE_MAP (itc);
	  res = pg_key_compare (*buf_ret, pm->pm_entries[pm->pm_count - 1], itc);
	  if (DVC_GREATER == res || DVC_MATCH == res)
	    {
	      /* we know that it is asc order and max of page > value sought.  The result is valid without a full lookup */
	      res = itc_next (itc, buf_ret);
	      (*n_hits)++; /* hit for purposes of locality whether data found or not */
	      return res;
	    }
	  ITC_IN_MAP (itc);
	  page_leave_inner (*buf_ret);
	}
      else 
	{
	  res = itc_next (itc, buf_ret);
	  if (DVC_MATCH == res)
	    {
	      (*n_hits)++;
	      return res;
	    }
	  ITC_IN_MAP (itc);
	  page_leave_inner (*buf_ret);
	}
    }
  ITC_IN_MAP (itc);
  if (itc == (it_cursor_t *) pl)
    itc_unregister (itc, INSIDE_MAP);
  *buf_ret = itc_reset (itc);
  res = itc_next (itc, buf_ret);
  return res;
}



int
itc_il_search (it_cursor_t * itc, buffer_desc_t ** buf_ret, caddr_t * qst, 
	       inx_locality_t * il, placeholder_t * pl, int is_asc)
{
  ptrlong n = QST_PLONG (qst, il->il_n_read)++;
  ptrlong hits = QST_PLONG (qst, il->il_n_hits);
  int res;
  if (!il->il_n_read)
    GPF_T1 ("il not inited.");
  if (pl && pl->itc_space_registered 
      && n > 3 && n / (hits | 1) < 3)
    {
      res = itc_near_random (itc, pl, buf_ret,
			     &QST_PLONG (qst, il->il_n_hits), is_asc);
      QST_PLONG (qst, il->il_last_dp) = itc->itc_page;
      return res;
    }
  else 
    {
      *buf_ret = itc_reset (itc);
      res = itc_next (itc, buf_ret);
      if (itc->itc_page == QST_PLONG (qst, il->il_last_dp))
	QST_PLONG (qst, il->il_n_hits)++;
      else 
	QST_PLONG (qst, il->il_last_dp) = itc->itc_page;
      return res;
    }
}





int
ssl_n_cmp (query_instance_t * qi, state_slot_t ** s1, state_slot_t ** s2)
{
  int inx;
  caddr_t * qst = (caddr_t *) qi;
  DO_BOX (state_slot_t *, ssl1, inx, s1)
    {
      int rc = cmp_boxes (qst_get (qst, ssl1), qst_get (qst, s2[inx]), NULL, NULL);
      if (DVC_MATCH != rc)
	return rc;
    }
  END_DO_BOX;
  return DVC_MATCH;
}


#define IOP_START 0
#define IOP_TARGET 1
#define IOP_NEXT 2


void
inx_op_set_params (inx_op_t * iop, it_cursor_t * itc)
{
  ITC_START_SEARCH_PARS (itc);
}


int
inxop_next (inx_op_t * iop , query_instance_t * qi, int op,
	    table_source_t * ts)
{
  key_source_t * ks = iop->iop_ks;
  int is_nulls = 0, rc, rc2;
  int is_random = 0;
  caddr_t * qst = (caddr_t *) qi;
  it_cursor_t * itc = (it_cursor_t *) QST_GET (qst, iop->iop_itc);
  buffer_desc_t *buf;


  if (!itc)
    {
      itc = itc_create (NULL, qi->qi_trx);
      QST_SET (qst, iop->iop_itc, itc);
    }
  
  itc->itc_ks = ks;
  itc->itc_out_state = qst;

  itc_from (itc, ks->ks_key);
  itc->itc_insert_key = ks->ks_key;
  itc->itc_desc_order = ks->ks_descending;

  itc_free_owned_params (itc);
  ITC_START_SEARCH_PARS (itc);
  switch (op)
    {
    case IOP_START:
    case IOP_NEXT:
      is_nulls = ks_make_spec_list (itc, iop->iop_ks_start_spec, qst);
      itc->itc_search_par_fill = itc->itc_insert_key->key_n_significant;
      /* set the fill to be like full eq of all parts because the row spec is so laid out that it presupposes the full eq  search spec to precede it. */
      is_nulls |= ks_make_spec_list (itc, iop->iop_ks_row_spec, qst);
      itc->itc_specs = iop->iop_ks_start_spec;
      itc->itc_row_specs = iop->iop_ks_row_spec;
      break;
    case IOP_TARGET:
      is_nulls = ks_make_spec_list (itc, iop->iop_ks_full_spec, qst);
      if (is_nulls)
	{
	  int res;
	  if (itc->itc_space_registered)
	    return IOP_AT_END; /*found something already, type no longer castable but was, so no more hits possible */
	  res = inxop_next (iop, qi, IOP_START, ts);
	  if (IOP_ON_ROW == res)
	    return IOP_NEW_VAL;
	  return IOP_AT_END;
	}
      is_nulls |= ks_make_spec_list (itc, iop->iop_ks_row_spec, qst);
      itc->itc_specs = iop->iop_ks_full_spec;
      itc->itc_row_specs = iop->iop_ks_row_spec;
      break;
    }
  if (is_nulls)
    return IOP_AT_END;
  if (IOP_START == op)
    {
      if (ts->src_gen.src_query->qr_select_node
	  && ts->src_gen.src_query->qr_lock_mode != PL_EXCLUSIVE)
	{
	  itc->itc_lock_mode = qi->qi_lock_mode;
	}
      else
	itc->itc_lock_mode = PL_EXCLUSIVE;
      /* if the statement is not a SELECT, take excl. lock */
      itc->itc_isolation = qi->qi_isolation;
    }
      
  DO_SET (state_slot_t*, ssl, &ks->ks_always_null)
    {
      qst_set_bin_string (itc->itc_out_state, ssl, (db_buf_t) "", 0, DV_DB_NULL);
    }
  END_DO_SET();

  ITC_FAIL (itc)
    {
      switch (op)
	{
	case IOP_START:
	  is_random = 1;
	  itc->itc_search_mode = SM_READ;
	  buf = itc_reset (itc);
	  rc = itc_next (itc, &buf);
	  if (DVC_GREATER == rc || DVC_INDEX_END == rc)
	    {
	      itc_page_leave (itc, buf);
	      return IOP_AT_END;
	    }
	  break;
	case IOP_TARGET:
	  is_random = 1;
	  itc->itc_search_mode = SM_READ_EXACT;
	  rc = itc_il_search (itc, &buf, qst, &iop->iop_il, (placeholder_t*) itc, 
			      !itc->itc_desc_order);
	  break;
	case IOP_NEXT:
	  is_random = 0;
	  buf = page_reenter_excl (itc);
	  rc = itc_next (itc, &buf);
	  if (DVC_GREATER == rc || DVC_INDEX_END == rc)
	    {
	      itc_page_leave (itc, buf);
	      return IOP_AT_END;
	    }
	  break;
	}
      FAILCK (itc);
      
      if (DVC_MATCH == rc)
	{
	  ITC_IN_MAP (itc);
	  itc_register_cursor (itc, INSIDE_MAP);
	  itc_page_leave (itc, buf);
	  return IOP_ON_ROW;
	}

      switch (op)
	{
	case IOP_TARGET:
	  if (is_random)
	    {
	      if (DVC_LESS == rc)
		{
		  itc->itc_specs = iop->iop_ks_start_spec;
		  itc->itc_is_on_row = 1;  /* force it to go one forward */
		  rc2 = itc_next (itc, &buf);
		  if (DVC_GREATER == rc2 || DVC_INDEX_END == rc2)
		    {
		      itc_page_leave (itc, buf);
		      return IOP_AT_END;
		    }
		  if (DVC_MATCH == rc2)
		    {
		      /* the iop_out ssls are set because they are the ks:iouyt_ssls */
		      ITC_IN_MAP (itc);
		      itc_register_cursor (itc, INSIDE_MAP);
		      itc_page_leave (itc, buf);
		      return IOP_NEW_VAL;
		    }
		}
	      else 
		GPF_T1 ("iop should not have dvc_les here");
	    }
	  else 
	    {
	      /* serial seek to target */
	      GPF_T1 ("serial iop to target not done.");
	      if (DVC_GREATER == rc)
		{
		  /* if mismatch in given or in free parts */
		  itc->itc_specs = iop->iop_ks_start_spec;
		  rc2 = itc_next (itc, &buf);
		  if (DVC_GREATER == rc2)
		    {
		      itc_page_leave (itc, buf);
		      return IOP_AT_END;
		    }
		  else  if (DVC_MATCH == rc2)
		    {
		      ITC_IN_MAP (itc);
		      itc_register_cursor (itc, INSIDE_MAP);
		      itc_page_leave (itc, buf);
		      return IOP_NEW_VAL;
		    }
		  else 
		    GPF_T1 ("dvc less not expected here.");
		}
	    }
	  break;
	case IOP_NEXT:
	case IOP_START:
	  itc_page_leave (itc, buf);
	  return IOP_AT_END;
	}
    }
  ITC_FAILED
    {
    }
  END_FAIL (itc);
  return 0;			/* never executed */
}


int 
inx_op_and_next (inx_op_t * iop, query_instance_t * qi, 
		int op, table_source_t * ts)
{
  int inx;
  int n_terms = BOX_ELEMENTS (iop->iop_terms);
  caddr_t * qst = (caddr_t *) qi;
  int rc, n_hits = 0;
  for (;;)
    {
      DO_BOX (inx_op_t *, term, inx, iop->iop_terms)
	{
	  rc = inxop_next (term, qi,  op, ts);
	  QST_SET (qst, term->iop_state, rc);
	  switch (rc)
	    {
	    case IOP_AT_END:
	    {
	      QST_SET (qst, iop->iop_state, IOP_AT_END);
	      return rc;
	    }
	    case IOP_NEW_VAL:
	      op = IOP_TARGET;
	      n_hits = 1;
	      break;
	    case IOP_ON_ROW:
	      if (IOP_NEXT == op || IOP_START == op)
		{
		  n_hits = 1;
		  op = IOP_TARGET;
		  continue;
		}
	      n_hits++;
	      if (n_hits == n_terms)
		return  IOP_ON_ROW;
	      continue;
	    }
	}
      END_DO_BOX;
    }
  return 0; /*not done */
}



void
inx_op_source_input (table_source_t * ts, caddr_t * inst,
    caddr_t * volatile state)
{
  buffer_desc_t * main_buf;
  volatile int any_passed = 1;
  query_instance_t *qi = (query_instance_t *) inst;
  int rc, start;

  for (;;)
    {
      it_cursor_t *volatile main_itc = NULL;
      if (!state)
	{
	  start = 0;
	  state = qn_get_in_state ((data_source_t *) ts, inst);
	  if (!state)
	    return;
	}
      else
	start = 1;
      if (start)
	{
	  any_passed = 0;
	  rc = inx_op_and_next (ts->ts_inx_op, qi, IOP_START, ts);
	  if (IOP_AT_END == rc)
	    {
	      qn_record_in_state ((data_source_t *) ts, inst, NULL);
	      ts_outer_output (ts, inst);
	      return;
	    }
	  qn_record_in_state ((data_source_t *) ts, inst, state);
	}
      else
	{
	  rc = inx_op_and_next (ts->ts_inx_op, qi, IOP_NEXT, ts);
	  if (IOP_ON_ROW == rc)
	    {
	      qn_record_in_state ((data_source_t *) ts, inst, state);
	    }
	  else
	    {
	      if (!any_passed)
		ts_outer_output (ts, state);
	      return;
	    }
	}

      if (ts->ts_main_ks)
	{
	  it_cursor_t main_itc_auto;
	  int rc;
	  main_itc = &main_itc_auto;
	  ITC_INIT (main_itc, qi->qi_space, qi->qi_trx);
	  rc = ks_start_search (ts->ts_main_ks, inst, state, main_itc,
	      &main_buf, ts, SM_READ_EXACT);
	  itc_assert_lock (main_itc);
	  if (!rc)
	    {
#ifdef DEBUG
	      if (!ts->ts_main_ks->ks_row_spec &&
		  !ts->ts_main_ks->ks_local_test)
		{
		  /* no main row found, yet no special conditions on main rpw.
		     Integrity error */
		  dbg_printf (("Missed join to main row from %s\n",
		      ts->ts_order_ks->ks_key->key_name));
		}
#endif
	      state = NULL;
	      itc_free (main_itc);
	      continue;
	    }
	  else
	    {
	      /* We joined with the primary key row. */
	      ts_set_placeholder (ts, state, main_itc, main_buf);
	      ITC_FAIL (main_itc)
	      {
		itc_page_leave (main_itc, main_buf);
	      }
	      ITC_FAILED
	      {
		itc_free (main_itc);
	      }
	      END_FAIL (main_itc);
	      itc_free (main_itc);
	    }
	}
      if (!ts->src_gen.src_after_test
	  || code_vec_run (ts->src_gen.src_after_test, state))
	{
	  any_passed = 1;
	  qn_ts_send_output ((data_source_t *) ts, state, ts->ts_after_join_test);
	}
      state = NULL;
    }
}

