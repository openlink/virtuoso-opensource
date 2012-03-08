/*
 *  replsr.h
 *
 *  $Id$
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

#ifndef _REPLSR_H
#define _REPLSR_H

typedef struct subscription_s
  {
    char *		sub_account;
    char *		sub_subscriber_name;
    dk_session_t *	sub_session;
  } subscription_t;

typedef struct repl_trail_file_s
  {
    caddr_t		rtf_file;
    repl_level_t	rtf_level;  /* level of first entry */
  } repl_trail_file_t;

struct repl_trail_s
  {
    dk_set_t		rt_files;
    int			rt_is_busy;
    int			rt_keep_extra_log;
    caddr_t		rt_file_name;
    dk_session_t *	rt_out;
    OFF_T		rt_bytes_per_file;
    OFF_T		rt_commit_length;
    dk_mutex_t *	rt_mtx;
    rwlock_t *		rt_lock;
  };

typedef struct repl_message_s
  {
    caddr_t             rm_srv;
    caddr_t		rm_acct;
    caddr_t *		rm_header;
    dk_session_t *	rm_string;
    OFF_T		rm_blobs_start;
    caddr_t		rm_log_file;
    subscription_t *	rm_synced_sub;
    void *		rm_data;
  } repl_message_t;

typedef struct repl_queue_s
  {
    basket_t		rq_basket;
    dk_mutex_t *	rq_mtx;
    semaphore_t *	rq_sem;
    long		rq_bytes;
    int			rq_to_disconnect;
  } repl_queue_t;

typedef struct replay_message_s
  {
    int                 rpm_mode;
    dk_session_t *      rpm_ses;
    caddr_t             rpm_msg;
  } replay_message_t;

#define RPM_NONE  0
#define RPM_IN	  1
#define RPM_OUT   2

#define REPL_QUEUE_FULL		((caddr_t *) 1L)
#define REPL_QUEUE_SYNCED	((caddr_t *) 2L)
#define REPL_QUEUE_DISCONNECT	((caddr_t *) 3L)
#define REPL_PURGE		((caddr_t *) 4L)

#define LOGH_LEVEL(l) \
  unbox (((caddr_t *) l [LOGH_REPLICATION]) [REPLH_LEVEL])

/* replsri.c */
int repl_is_below (repl_level_t log, repl_level_t req);
dk_set_t repl_trail_start_pos (repl_trail_t *rt, repl_level_t level);
void repl_trail_new_file (repl_acct_t *ra, char *file, int lock);
#define LOG_REPL_TEXT_ARRAY_MASK_ALL	((ptrlong)((uptrlong)-1))
void log_repl_text_array (lock_trx_t *lt, char * srv, char * acct, caddr_t box);
void log_repl_text_array_all (const char *obj_name, int obj_type, caddr_t text,
    client_connection_t *cli, query_instance_t *qi, ptrlong opt_mask);
void trx_repl_log_ddl_index_def (query_instance_t * qi, caddr_t name, caddr_t table,
    caddr_t * cols, caddr_t * opts);
int lt_log_replication (lock_trx_t *lt);
void lt_send_repl_cast (lock_trx_t *lt);
void lt_repl_rollback (lock_trx_t *lt);
void repl_serv_init (int make_thr);
int repl_is_below (repl_level_t log, repl_level_t req);
int session_buffered_chunked_write (dk_session_t * ses,
        char * buffer, int length);
repl_trail_t * repl_trail_find (repl_acct_t *ra);
void rm_free (repl_message_t * rm);

subscription_t * sub_allocate (
        char * subscriber, char * account, dk_session_t * sess);
void sub_free (subscription_t * sub);
void repl_sub_synced (subscription_t * sub, repl_level_t level_at);
void repl_sub_dropped (repl_queue_t * rq, dk_session_t * ses);
void repl_purge (char *srv, char *acct);

#define REPL_LEVEL_OK(level, level_at)					\
    ((level) == (level_at) || repl_is_below ((level), (level_at)))

/* replsub.c */
void sf_resync_acct (char * account, repl_level_t level,
        char * subscriber_name, caddr_t name, caddr_t digest);
void resend_thread_loop (void);
void repl_send_resync (dk_session_t * ses);

/* repl.c */
extern repl_queue_t repl_queue;

char * repl_server_to_address (char * srv);

/* replpush.c */
extern repl_queue_t repl_replay_queue;
extern repl_queue_t repl_push_queue;
extern resource_t *replay_rc;
extern dk_session_t *replay_str_in;
extern client_connection_t *replay_cli;

replay_message_t * rpm_allocate (void);
void rpm_free (replay_message_t * rpm);
void rpm_clear (replay_message_t * rpm);

caddr_t sf_resync_replay (char * account, char * subscriber_name,
        caddr_t name, caddr_t digest);
int repl_sync_acct (repl_acct_t * ra, char * usr, char * pwd);
int repl_sync_updatable_acct (repl_acct_t *ra, char * usr, char * pwd);
void repl_replay_loop (void);
void repl_push_loop (void);
void repl_purge_run (repl_acct_t *ra);

#endif /* _REPLSR_H */
