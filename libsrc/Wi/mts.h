/*
 *  mts.h
 *
 *  $Id$
 *
 *  MTS related functions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

#ifndef _MTS_H
#define _MTS_H

#define ENABLE_PROFILE

struct rds_connection_s;
struct tp_dtrx_s;
struct ITransaction;
struct query_instance_s;
struct client_connection_s;

#define EXE_IMPORT1(type, func, args) \
	type func args

EXE_IMPORT1 (int, enlist_transaction, (lock_trx_t * lt, unsigned char *cookie,
	unsigned long cookie_len));
EXE_IMPORT1 (int, mts_ms_sql_enlist, (struct rds_connection_s * rcon,
	struct query_instance_s * qi));
EXE_IMPORT1 (int, mts_trx_exclude, (lock_trx_t * lt,
	struct rds_connection_s * rcon));
EXE_IMPORT1 (void, mts_trx_dealloc, (struct tp_dtrx_s * dtrx));


EXE_IMPORT1 (int, mts_trx_begin, (struct query_instance_s * qi));

EXE_IMPORT1 (int, mts_connection_state,
    (struct client_connection_s * client));
EXE_IMPORT1 (int, mts_wait_commit, (struct client_connection_s * client));
EXE_IMPORT1 (int, mts_trx_enlist_loc,
    (struct client_connection_s * connection, struct ITransaction * itrn));
EXE_IMPORT1 (int, mts_trx_enlist, (lock_trx_t * lt, caddr_t tr_cookie,
	unsigned long len));
EXE_IMPORT1 (caddr_t, mts_get_rmcookie, ());

EXE_IMPORT1 (int, mts_trx_commit, (lock_trx_t * lt, int is_commit));

EXE_IMPORT1 (int, mts_init, ());
EXE_IMPORT1 (int, mts_connect, (long reconnect));

EXE_IMPORT1 (box_t, mts_server_status, ());
EXE_IMPORT1 (box_t, mts_transaction_status, (lock_trx_t *));
EXE_IMPORT (int, mts_recover, (box_t recov_data));
EXE_IMPORT (void *, mts_trx_allocate, ());
EXE_IMPORT (void, mts_bif_init, ());

int mts_check ();

extern int vd_use_mts;

#ifndef ENABLE_PROFILE
#define STATIC static
#else
#define STATIC
#endif

#endif /* _MTS_H */
