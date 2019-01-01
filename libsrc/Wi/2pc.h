/*
 *  2pc.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

#ifndef _TPC_H
#define _TPC_H

#include "util/uuid.h"
#include "wi_xid.h"

#ifndef XA_IMPL
#define XA_IMPL
#endif

#ifndef NO_2PC_TRACE
#ifdef DEBUG
#ifndef _2PC_TRACE
#define _2PC_TRACE
#endif
#endif
#endif

#define UUID_BY_PORT

#ifndef WIN32
#ifndef HRESULT
#define HRESULT long
#define S_OK                                   ((HRESULT)0x00000000L)
#define S_FALSE                                ((HRESULT)0x00000001L)
#endif

#ifndef UWORD
#define UWORD unsigned short
#endif

#ifndef DWORD
#define DWORD uint32
#endif
#endif

    /* message identities for main queue */
#define TP_PREPARE	1
#define TP_COMMIT	2
#define TP_ABORT	3
#define TP_ENLIST_END	4
#define TP_JOIN		5
#define TP_RESUME	6
#define TP_SUSPEND	7

#define SQL_TP_UNENLIST		((UWORD)0x000000F0L)
#define SQL_XA_UNENLIST		((UWORD)0x00000F00L)
#define SQL_TP_PREPARE		((UWORD)(TP_PREPARE | SQL_TP_UNENLIST ))
#define SQL_TP_COMMIT		((UWORD)(TP_COMMIT | SQL_TP_UNENLIST ))
#define SQL_TP_ABORT		((UWORD)(TP_ABORT | SQL_TP_UNENLIST ))
#define SQL_TP_ENLIST		((UWORD)( 4UL | SQL_TP_UNENLIST ))

#define SQL_XA_ENLIST		((UWORD)( 6UL | SQL_TP_UNENLIST ))
#define SQL_XA_PREPARE		((UWORD)( TP_PREPARE | SQL_XA_UNENLIST ))
#define SQL_XA_COMMIT		((UWORD)( TP_COMMIT | SQL_XA_UNENLIST ))
#define SQL_XA_ROLLBACK		((UWORD)( TP_ABORT | SQL_XA_UNENLIST ))
#define SQL_XA_ENLIST_END	((UWORD)( TP_ENLIST_END | SQL_XA_UNENLIST ))
#define SQL_XA_JOIN		((UWORD)( TP_JOIN | SQL_XA_UNENLIST))
#define SQL_XA_WAIT		((UWORD)( SQL_XA_UNENLIST))
#define SQL_XA_RESUME		((UWORD)( TP_RESUME | SQL_XA_UNENLIST))
#define SQL_XA_SUSPEND		((UWORD)( TP_SUSPEND | SQL_XA_UNENLIST))

  /* types of TP */
#define TP_VIRT_TYPE	1
#define TP_MTS_TYPE	2
#define TP_XA_TYPE	3

  /* states of transactions */
#define ENLISTED 1
#define SHOULD_BE_ENLISTED 2

  /* states of client connection */
  /* local transactions state */
#define CONNECTION_LOCAL 0
  /* remote transactions state */
#define CONNECTION_PREPARED 1
#define CONNECTION_ENLISTED 2
#define CONNECTION_FINISHED 3
  /* this flag indicates that transaction is killed
     during checkpoint */
#define TP_PREPARE_CHKPNT 1

struct tp_message_s;

typedef unsigned long (*tp_log_t) (struct tp_message_s * mm);
typedef unsigned long (*tp_func_t) (void *res, int trx_status);

    /* vtbl for message object */
typedef struct queue_vtbl_s
{
  tp_func_t prepare_done;
  tp_func_t commit_done;
  tp_func_t abort_done;
  tp_log_t prepare_set_log;
}
queue_vtbl_t;

typedef struct tp_queue_s
{
  basket_t mq_basket;
  dk_mutex_t *mq_mutex;
  semaphore_t *mq_semaphore;
#ifdef MQ_DEBUG
  unsigned long mq_aborts;
  unsigned long mq_commits;
  unsigned long mq_prepares;
  unsigned long mq_errors;
#endif
}
tp_queue_t;

    /* list of enlisted connections for  */
typedef struct tp_connection_s
{
  basket_t tcon_basket;
}
tp_connection_t;

struct tp_dtrx_s;
struct rds_connection_s;
struct query_instance_s;
struct lock_trx_s;
struct tp_dtrx_s;

typedef int (*enlist_func_t) (struct rds_connection_s * rcon,
    struct query_instance_s * qi);
typedef int (*commit_func_1_t) (struct lock_trx_s * lt, int is_commit);
typedef int (*commit_func_2_t) (caddr_t distr_trx, int is_commit);
typedef int (*exclude_func_t) (struct lock_trx_s * lt,
    struct rds_connection_s * rcon);
typedef void (*dealloc_func_t) (struct tp_dtrx_s * dtrx);

    /* transaction flow management */
typedef struct tp_trx_vtbl_s
{
  enlist_func_t enlist;
  commit_func_1_t commit_1;
  commit_func_2_t commit_2;
  exclude_func_t exclude;
  dealloc_func_t dealloc;
}
tp_trx_vtbl_t;

typedef struct tp_dtrx_s
{
  caddr_t dtrx_info;		/* for MTS mts_t, for VIRT list of rcons */
  tp_trx_vtbl_t *vtbl;
}
tp_dtrx_t;

    /* distr. transaction data of connection */
typedef struct tp_data_s
{
  int cli_tp_enlisted;
  semaphore_t *cli_tp_sem2;
  int cli_trx_type;
  void *cli_tp_trx;
  struct lock_trx_s *cli_tp_lt;
  int tpd_client_is_reset;
  int tpd_last_act;

  caddr_t tpd_trx_cookie;
#ifdef _DEBUG
  int fail_after_prepare;
#endif
  unsigned cli_free_after_unenlist:2;
  struct tp_data_s *next;
}
tp_data_t;

#define CFAU_NONE	0
#define CFAU_DIED	1

typedef struct tp_future_s
{
  ptrlong ft_result;
  semaphore_t *ft_sem;
  char ft_release;
}
tp_future_t;

typedef struct tp_message_s
{
  int mm_type;			/* abort or commit */
  tp_future_t * mm_resource;
  struct lock_trx_s *mm_trx;
  struct tp_data_s *mm_tp_data;
  queue_vtbl_t *vtbl;
}
tp_message_t;

/* temporary solution, should be changed to real UUID */
#define DTRX_IP 0
#define DTRX_PORT 1
#define DTRX_NUMBER_ID 2
#define DTRX_RM_ID 3
typedef struct tp_addr_s
{
  uint32 tpa_ip_addr;
  uint32 tpa_port;
}
tp_addr_t;

typedef struct dtransact_id_s
{
  struct parsed_s
  {
    tp_addr_t p_tp;
    uint32 p_number_id;
    uint32 p_rm_id;		/* filled at rm side */
  } dtid_parsed;
  caddr_t dtid_brick;
} dtransact_id_t;

/* holder for enlisted hdbcs */
typedef struct d_trx_info_s
{
  box_t d_trx_id;
  dk_set_t d_trx_hdbcs;
} d_trx_info_t;


typedef struct virt_tp_s
{
  dk_set_t vtp_trxs;
  struct client_connection_s *vtp_cli;
  struct uuid *vtp_uuid;
}
virt_tp_t;

typedef unsigned long virt_trx_id_t;
typedef unsigned long virt_branch_id_t;
struct virt_trx_s;
struct virt_rcon_s;
typedef struct virt_rcon_s *(*virt_branch_factory_t) (struct virt_trx_s *
    vtrx);
typedef int tp_result_t;

typedef struct virt_rcon_s
{
  virt_branch_id_t vtr_id;
  struct virt_trx_s *vtr_trx;

  int vtr_is_local;
  union
  {
    struct rds_connection_s *l_rmt;
    caddr_t r_cookie;
  } vtr_branch_handle;


  int vtr_is_finalized;
}
virt_rcon_t;



typedef struct virt_trx_s
{
  virt_trx_id_t vtx_id;
  dk_set_t vtx_cons;
  const char *vtx_curr_state;

  virt_tp_t *vtx_transaction_processor;

  virt_branch_factory_t vtx_branch_factory;

  caddr_t vtx_cookie;
  uuid_t *vtx_uuid;

  int vtx_needs_recovery;
}
virt_trx_t;

/* Error reporting */
#define TP_ERR_COMMON		(tp_result_t)(-100)
#define TP_ERR_NO_DISTR_TRX	(tp_result_t)(-101)
#define TP_ERR_DTRX_INIT	(tp_result_t)(-102)
#define TP_ERR_SYS_TABLE	(tp_result_t)(-103)



struct client_connection_s;

    /* wait for end of distr. transaction */
EXE_EXPORT (int, tp_retire, (struct query_instance_s * qi));
int tp_wait_commit (struct client_connection_s *cli);
    /* switch connection state */
int tp_connection_state (struct client_connection_s *cli);
void tp_queue_free (tp_queue_t * queue);
    /*
       main function which manages 2PC messages
       runs in its own thread */
int tp_message_hook (void *queue);
void tp_data_free (tp_data_t * tpd);
void tp_main_queue_init (void);
EXE_EXPORT (tp_message_t *, mq_create_message, (int type,
	void *enlistment, void *client_connection));
tp_message_t *mq_create_xa_message (int type, void *enlistment, void *tpd);
EXE_EXPORT (void, mq_add_message, (tp_queue_t * mq, void *message));
EXE_EXPORT (tp_queue_t *, tp_get_main_queue, (void));
EXE_EXPORT (void, DoSQLError, (SQLHDBC hdbc, SQLHSTMT hstmt));

#define _LOG_INFO   0
#define _LOG_ERROR  1

EXE_EXPORT (void, twopc_log, (int log_level, char *message));

int lt_2pc_prepare (struct lock_trx_s *lt);

tp_dtrx_t *virt_trx_allocate (void);
caddr_t tp_add_enlisted_connection (struct dk_session_s *ses,
    dtransact_id_t * trx);
dtransact_id_t *dtransact_id_allocate (void);
void virt_tp_store_connections (struct lock_trx_s *lt);
extern tp_queue_t *tp_main_queue;

/* #define _2PC_TRACE */

#ifdef _2PC_TRACE
#define _2pc_printf(x) log_info x
#else
#define _2pc_printf(x)
#endif

/* #ifndef _MTX_ */
/* X/Open global transactions supporting functions */

/* #define XA_CLIENT (struct client_connection_s *)(-1) */

#define VXA_AGAIN	(-2)
#define VXA_ERROR	(-1)
#define VXA_OK		0

#ifdef TUXEDO
#define virtXID XID
#endif

typedef struct xa_id_s
{
  virtXID xid;
  semaphore_t *xid_sem;
  struct client_connection_s *xid_cli;
  struct tp_data_s *xid_tp_data;
  int xid_op;
} xa_id_t;

typedef struct virt_xa_map_s
{
  id_hash_t *xm_xids;
  id_hash_t *xm_log_xids;
  dk_mutex_t *xm_mtx;
  id_hash_iterator_t xm_hit;

} virt_xa_map_t;

extern virt_xa_map_t *global_xa_map;

int virt_xa_set_client (void *xid, struct client_connection_s *cli);
void virt_xa_suspend_lt (void *xid, struct client_connection_s *cli);
int virt_xa_client (void *xid_str, struct client_connection_s *cli, struct tp_data_s **tpd, int op);
void virt_xa_remove_xid (void *xid);
void *virt_xa_id (char *xid_str);
caddr_t virt_xa_xid_in_log (void *xid);
int virt_xa_replay_trx (void *xid, caddr_t trx, struct client_connection_s *cli);
int virt_xa_add_trx (void *xid, struct lock_trx_s * lt);

int xa_wait_commit (struct tp_data_s *tpd);
/* #endif _MTX_ */


/*
  xa transaction persistent info structures
*/
typedef struct txa_entry_s
{
  char *txe_id;
  char *txe_path;
  caddr_t txe_offset;
  char *txe_res;
} txa_entry_t;
/*
   info: id, file_path, offsets, res
   res = "PRP", "CMT", "RLL",
*/
typedef struct txa_info_s
{
  char *txi_trx_file;
  int txi_fd;
  caddr_t *txi_info;
  txa_entry_t **txi_parsed_info;
} txa_info_t;
#define TXE_ITEMS	4
void txa_from_trx (struct lock_trx_s *lt, char *log_file_name);
void txa_remove_entry (void *xid, int check);
txa_entry_t *txa_search_trx (void *xid);
int lt_2pc_commit (struct lock_trx_s *lt);
void virt_xa_tp_set_xid (tp_data_t * tpd, void *xid);

#define IS_ENLISTED_TXN(qi) \
    ( ((TP_MTS_TYPE == (qi)->qi_trx->lt_2pc._2pc_type)) || \
       ((qi)->qi_client->cli_tp_data && \
	(CONNECTION_ENLISTED == (qi)->qi_client->cli_tp_data->cli_tp_enlisted)) )

EXE_EXPORT (int, server_logmsg_ap, (int level, char *file, int line, int mask,
	char *format, va_list ap));
#endif /* TPC_H */
