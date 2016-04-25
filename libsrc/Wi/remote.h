/*
 *  remote.h
 *
 *  $Id$
 *
 *  Virtuoso Remote Data Source Access
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

#ifndef _REMOTE_H
#define _REMOTE_H

#include "sqlfn.h"
#include "msdtc.h"

typedef struct remote_ds_s
  {
    char *		rds_dsn;
    char *		rds_uid;
    char *		rds_pwd;
    caddr_t		rds_connstr; /* vector w/ SQLGetInfo info-value pairs */
#ifdef VIRTTP
    resource_t *	rds_mts_connections;
#endif
    char *		rds_quote;
    short		rds_identifier_case;
    int			rds_correlation_name;
    char *		rds_dbms_name;
    long		rds_oj_capsbility;
    char		rds_array_params;
    char		rds_array_checked;
    id_hash_t *		rds_pass_through_funcs;
    dk_mutex_t *	rds_pass_through_funcs_mtx;
    dk_hash_t *	        rds_rexec_grants;
    id_hash_t *		rds_connections_hash;
    int 		rds_timezoneless_datetimes;
  } remote_ds_t;


typedef struct remote_table_s
  {
    caddr_t		rt_local_name;
    caddr_t		rt_remote_name;
    remote_ds_t *	rt_rds;
  } remote_table_t;


typedef struct remote_proc_s
  {
    caddr_t		rp_local_name;
    caddr_t		rp_remote_name;
    remote_ds_t *	rp_rds;
    caddr_t *		rp_param_type;
    caddr_t *		rp_param_prec;
    caddr_t *		rp_param_mode;
    dtp_t		rp_ret_dtp;
    long		rp_ret_prec;
  } remote_proc_t;


typedef struct rds_connection_s
  {
    remote_ds_t *	rc_rds;
    SQLHDBC		rc_hdbc;
    id_hash_t *		rc_stmts;
    int			rc_n_stmts_cached;
    long		rc_last_used;
    char		rc_to_disconnect; /* remote dead, formally disconnect
					     at transact time */
    caddr_t		rc_dbms;
    caddr_t		rc_driver_name;
    dk_mutex_t *	rc_mtx;
    struct _rstmtstruct *rc_first_rst;
    struct _rstmtstruct *rc_last_rst;
    int			rc_access_mode;
    SQLSMALLINT		rc_txn_capable;
    SQLSMALLINT		rc_commit_behavior;
    SQLSMALLINT		rc_rollback_behavior;
    int			rc_autocommit;
    int			rc_vdb_actions;
    int			rc_n_active_stmts;
    struct _rstmtstruct *rc_first_active_rst;
    struct _rstmtstruct *rc_last_active_rst;
#ifdef VIRTTP
    int			rc_is_enlisted;
    int			rc_mts_used;
#endif
    lock_trx_t *       rc_lt;
    caddr_t		rc_uid;
    caddr_t		rc_pwd;
    caddr_t		rc_dsn_name;
#ifdef INPROCESS_CLIENT
    int			rc_inprocess;
#endif
    int 		rc_hdbc_access_mode;
  } rds_connection_t;



typedef struct rcc_entry_s
{
  remote_ds_t *		rce_rds;
  rds_connection_t * 	rce_rcon;
  struct rcc_entry_s *	rce_next;
} rcc_entry_t;


typedef struct rcon_cache_s
{
  rcc_entry_t *	rcc_entries;
} rcon_cache_t;


#ifndef _REMOTE_STMT_T_
#define _REMOTE_STMT_T_
typedef struct _rstmtstruct  remote_stmt_t;
#endif

extern remote_ds_t * local_rds;

#define IS_BLOB_SQL_TYPE(dt) (SQL_LONGVARCHAR == dt || SQL_LONGVARBINARY == dt || SQL_WLONGVARCHAR == dt)

#define IS_STRING_SQL_TYPE(dt) \
  (SQL_CHAR == dt || SQL_VARCHAR == dt || SQL_BINARY == dt || SQL_VARBINARY == dt || SQL_WVARCHAR == dt || SQL_WCHAR == dt)

/*
 *  Prototypes
 */
caddr_t box_timestamp_struct (TIMESTAMP_STRUCT * par_ts);

caddr_t find_pass_through_function (remote_ds_t * rds, int do_mutex, char *ref_name, char *q_def, char *o_def, caddr_t * found_remote);

remote_ds_t *find_remote_ds (const char *name, int create);

remote_proc_t *find_remote_proc (char *name, int create);

remote_table_t *find_remote_table (char *name, int create);

caddr_t rds_get_info (remote_ds_t * rds, int finfo);

int vd_dv_to_sql_type (int dv);

void sqlc_quote_dotted (char *text, size_t tlen, int *fill, char *name);

extern void dbev_dsn_login (remote_ds_t * rds, client_connection_t * cli, caddr_t * err_ret, caddr_t * puid, caddr_t * ppwd, caddr_t * pdsn);

#define RTS_ERROR_QI(rts, qi) \
  (rts->src_gen.src_query->qr_is_bunion_term ? NULL : (query_instance_t *) qi)

void rts_vec_run_single (remote_table_source_t * rts, query_instance_t * qi, caddr_t * state);

#endif /* _REMOTE_H */
