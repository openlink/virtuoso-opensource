/*
 *  $Id$
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

#ifndef _WI_AQUEUE_H
#define _WI_AQUEUE_H

typedef struct async_queue_s
{
  int			aq_ref_count;
  uint32		aq_ts; /* time of last req */
  dk_mutex_t *		aq_mtx;
  basket_t		aq_queue;
  int			aq_max_threads;
  int			aq_n_threads;
  uint32		aq_req_no;
  int			aq_anytime_started;
  int			aq_anytime_timeout;
  char			aq_deleted;
  char			aq_do_self_if_would_wait; /* if the caller thread would block , it will run queued items by itself.  At time of requesting, it wil not run on self */
  char			aq_need_own_thread;
  char			aq_row_autocommit;
  char			aq_no_more; /* set after an error that should cause no more activity to start on the aq */
  bitf_t		aq_queue_only:1;
  bitf_t		aq_non_txn_insert:1;
  bitf_t		aq_no_triggers:1;
  bitf_t		aq_no_lt_enter:1; /* for use inside cpt, autocompact etc which run with no client or lt ctx */
  dk_hash_t *		aq_requests;
  du_thread_t *		aq_waiting; /*  thread waiting for any ready from this aq */
  user_t * 		aq_user;
  caddr_t 		aq_qualifier;
  query_instance_t * 	aq_wait_qi;
  caddr_t		aq_replicate;
  cl_call_stack_t *	aq_cl_stack;
  int64			aq_main_trx_no;
  int64			aq_rc_w_id;
  char			aq_lt_timestamp[DT_LENGTH];
  client_connection_t *	aq_creator_cli;
} async_queue_t;


typedef struct aq_thread_s
{
  client_connection_t *	aqt_cli;
  du_thread_t *		aqt_thread;
  async_queue_t *	volatile aqt_aq;
  struct aq_request_s *	volatile aqt_aqr;
} aq_thread_t;


typedef caddr_t (*aq_func_t) (caddr_t args, caddr_t * err_ret);


typedef struct aq_request_s
{
  uint32		aqr_req_no;
  aq_func_t		aqr_func;
  caddr_t		aqr_args;
  du_thread_t *		aqr_waiting;
  caddr_t volatile 	aqr_value;
  caddr_t		aqr_error;
  volatile int		aqr_state;
  async_queue_t *	aqr_aq;
  caddr_t		aqr_debug;
  du_thread_t *		aqr_dbg_thread;
  db_activity_t		aqr_activity;
} aq_request_t;


/* aqr_state */
#define AQR_QUEUED 2
#define AQR_RUNNING 3
#define AQR_DONE 4


int aq_request (async_queue_t * aq, aq_func_t f, caddr_t arg);
caddr_t aq_wait (async_queue_t * aq, int req_no, caddr_t * err, int wait);
caddr_t aq_wait_any (async_queue_t * aq, caddr_t * err, int wait, int *req_no_ret);
caddr_t aq_wait_all (async_queue_t * aq, caddr_t * err_ret);
async_queue_t *aq_allocate (client_connection_t * cli, int n_threads);

#define AQ_DO_SELF_IF_WAIT 1	/* the aq func may run on the requesting thread if the req thread would wait for the aq */
#define AQ_CLUSTER_RECURSIVE 2	/* the aq server threads will keep the cluster call trace for indefinite recursion */
#define AQ_SEPARATE_TXN 4	/* the aq func is  sure  to have a txn  separate from the caller's */
#define AQ_TXN_BRANCH 8

int aq_free (async_queue_t * aq);
void aq_init ();
typedef void (*aq_cleanup_t) (caddr_t);
void aq_wait_all_in_qi (async_queue_t * aq, caddr_t * inst, caddr_t * err_ret, aq_cleanup_t clup);
void aq_check_duplicate (async_queue_t * aq, caddr_t val);

#define AQ_NO_REQUEST ((caddr_t)100)

#endif
