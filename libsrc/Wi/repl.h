/*
 *  repl.h
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

#ifndef _REPL_H
#define _REPL_H

typedef int32 repl_level_t; /* portable dtp of integer sequence */

#define REPL_MAX_DELTA  1000000000
#define REPL_WRAPAROUND 0x7fffffff

#define LEVEL_0		1

typedef struct repl_subscriber_s
 {
    caddr_t		rs_subscriber;
    int			rs_level;
    int			rs_valid;
 } repl_subscriber_t;

typedef struct repl_trail_s repl_trail_t;

typedef struct repl_acct_s
  {
    caddr_t		ra_server;
    caddr_t		ra_account;
    caddr_t		ra_sync_user;
    repl_level_t	ra_level;
    int			ra_synced;
    int			ra_is_mandatory;
    int                 ra_is_updatable;
    struct timeval	ra_last_txn;
    caddr_t		ra_sequence;
    caddr_t             ra_pub_sequence;  /* publisher sequence */
    caddr_t		ra_usr;
    caddr_t		ra_pwd;
    struct repl_acct_s *ra_parent; /* parent (publisher -> subscriber) acct */
    id_hash_t *		ra_subscribers;
    repl_trail_t *	ra_rt; /* replication trail */

    int			ra_p_month;
    int			ra_p_day;
    int			ra_p_wday;
    TIME_STRUCT *	ra_p_time;
  } repl_acct_t;

/* ra_synced */
#define RA_OFF		       0
#define RA_SYNCING	       1
#define RA_IN_SYNC	       2
#define RA_REMOTE_DISCONNECTED 3
#define RA_DISCONNECTED        4
#define RA_TO_DISCONNECT       5

#define RA_IS_PUSHBACK(ra)  (ra[0] == '!')

typedef struct _srastruct
  {
    caddr_t		sa_server;
    caddr_t		sa_db_address;
    caddr_t		sa_repl_address;
  } server_addr_t;

extern char * db_name;
extern dk_set_t repl_accounts;
extern client_connection_t *repl_util_cli;
extern dk_mutex_t *repl_uc_mtx;

repl_level_t ra_new_trx_no (lock_trx_t * lt, repl_acct_t * ra);
repl_acct_t * ra_find (char * server, char * name);
repl_acct_t * ra_find_pushback (char * server, char * name);
repl_acct_t *ra_add (char * server, char * account, repl_level_t level,
        int mand, int is_updatable);
repl_level_t ra_trx_no (repl_acct_t * ra);
repl_level_t ra_pub_trx_no (repl_acct_t * ra);
void ra_set_pub_trx_no (repl_acct_t *ra, repl_level_t level);
void repl_commit (lock_trx_t * lt, caddr_t * header, long trx_len);
void repl_checkpoint (char * new_log);
int repl_check_header (caddr_t * header);
char * repl_peer_name (repl_acct_t * ra);
repl_subscriber_t *rs_find (repl_acct_t *ra, char *subscriber);
repl_subscriber_t *repl_save_subscriber (
    repl_acct_t *ra, char *subscriber, int level, int valid);
query_t *repl_compile (char *text);

#endif /* _REPL_H */
