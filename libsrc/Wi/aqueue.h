/*
 *  $Id$
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


typedef struct async_queue_s
{
  int		aq_ref_count;
  dk_mutex_t *	aq_mtx;
  basket_t	aq_queue;
  int		aq_max_threads;
  int		aq_n_threads;
  int		aq_req_no;
  dk_hash_t *	aq_requests;
  int		aq_deleted;
  user_t * 	aq_user;
  caddr_t 	aq_qualifier;
} async_queue_t;


typedef struct aq_thread_s
{
  client_connection_t *aqt_cli;
  du_thread_t *	aqt_thread;
  async_queue_t *	volatile aqt_aq;
  struct aq_request_s *	volatile aqt_aqr;
} aq_thread_t;


typedef caddr_t (*aq_func_t) (caddr_t args, caddr_t * err_ret);


typedef struct aq_request_s
{
  int	aqr_req_no;
  aq_func_t	aqr_func;
  caddr_t	aqr_args;
  du_thread_t *	aqr_waiting;
  caddr_t volatile aqr_value;
  caddr_t	aqr_error;
  volatile int		aqr_state;
  async_queue_t *	aqr_aq;
} aq_request_t;


/* aqr_state */
#define AQR_QUEUED 2
#define AQR_RUNNING 3
#define AQR_DONE 4


int aq_request (async_queue_t * aq, aq_func_t f, caddr_t arg, lock_trx_t * lt);
caddr_t  aq_wait (async_queue_t * aq, int req_no, caddr_t * err, int wait);
caddr_t aq_wait_all (async_queue_t * aq, caddr_t * err_ret);
async_queue_t *  aq_allocate (client_connection_t * cli, int n_threads);
void aq_init ();

#define AQ_NO_REQUEST ((caddr_t)100)
