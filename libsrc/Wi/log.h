/*
 *  log.h
 *
 *  $Id$
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

#ifndef _WI_LOG_H
#define _WI_LOG_H

#define LOG_INSERT	1  /* prime row as DV_STRING */
#define LOG_UPDATE	2  /* prime key as DV_STRING, cols as DV_ARRAY_OF_LONG,
			      value as DV_ARRAY_OF_POINTER */
#define LOG_DELETE	3  /* prime key as DV_STRING */
#define LOG_COMMIT	4
#define LOG_ROLLBACK	5
#define LOG_DD_CHANGE	6

#define LOG_SC_CHANGE_1	100
#define LOG_SC_CHANGE_2	101


#define LOG_CHECKPOINT	7
#define LOG_ENDS	8  /* used to mark end of backup log on tape or raw device */
#define LOG_INSERT_REPL	8
#define LOG_INSERT_SOFT	9  /* prime key row follows, like insert. */
#define LOG_TEXT	10 /* SQL string follows */
#define LOG_SEQUENCE	11 /* series name, count */
#define LOG_SEQUENCE_64	12 /* series name, count */
#define LOG_KEY_INSERT 13
#define LOG_KEY_DELETE 14
#define LOG_USER_TEXT   15 /* SQL string log'd by an user */


#define LOGH_CL_2PC		0 /* string with commit flag and 8 byte lt_trx_no.  If not cluster pc, then null pointer. */
#define LOGH_USER		1
#define LOGH_REPLICATION 	2
#define LOGH_BYTES		3
#ifndef VIRTTP
#define LOG_HEADER_LENGTH	4
#else
#define LOGH_2PC                4
#define LOG_HEADER_LENGTH	5
#define LOG_HEADER_LENGTH_OLD	4
#endif
#define LOGH_COMMIT_FLAG_OFFSET(lt) (5 + (lt->lt_2pc_hosts ? (BOX_ELEMENTS (lt->lt_2pc_hosts) < 128 ? 3 : 6) : 0))
/* 3 bytes of array head, 2 bytes of logh_cl_2pc string header, first byte of string.  If 2pc host list, then 3 or 6 bytes of anoither array header */

#define REPLH_ACCOUNT		0
#define REPLH_SERVER		1
#define REPLH_LEVEL		2
#define REPL_ORIGIN		3  /* name of origin server, use to detect cycles */
#define REPLH_CIRCULATION	4  /* This and up to the box's end */

/* A LOG_CHANGE message is sent by the DBMS when making a checkpoint and
 * starting a new log.  It's a 2 element box with:
 */
#define LOGC_ACCOUNT		0
#define LOGC_NEW_FILE		1
#define LOGC_LENGTH		2

typedef struct {
  dk_mutex_t *	lre_mtx;
  dk_hash_t *	lre_aqs; /** key_id_t => lre_queue_t */
  int lre_aqr_count;   /** number of running requests */
  caddr_t lre_err;   /** the first reported error */
  int lre_stopped; /** after first error */
  char	lre_need_sync;
  dk_session_t * lre_in;
} lr_executor_t;


#ifdef SQL_SUCCESS  /* If included in the DBMS code */
void logh_set_level (lock_trx_t * lt, caddr_t * logh);

int log_replay_trx (lr_executor_t * lr_executor, dk_session_t * in, client_connection_t * cli,
		    caddr_t repl_head, int is_repl, int is_pushback, OFF_T log_rec_start);
int log_replay_time (caddr_t * header);
int log_write_replication (caddr_t * header, char * string, long bytes);
#endif

void tcpses_set_fd (session_t * ses, int fd);
int tcpses_get_fd (session_t * ses);
void dbs_sys_db_check (caddr_t file);
extern int32 cl_non_logged_write_mode;
void log_skip_blobs_1 (dk_session_t * ses);
int log_check_header (caddr_t * header);
extern uint32 log_last_2pc_archive_time;
extern int log_in_cl_recov;
int log_time (caddr_t * box);
caddr_t * log_time_header (caddr_t dt);

#define LOG_CL_2PC_PREPARE 0x11
#define LOG_CL_2PC_PREPARE_FROM_SYNC 0x13
#define LOG_MTS_2PC_PREPARE	0x0E
#define LOG_VIRT_2PC_PREPARE	0x0F
#define LOG_XA_2PC_PREPARE	0x10
#define LOG_2PC_COMMIT		0x01
#define LOG_2PC_ABORT		0x02
#define LOG_MTS_ENABLED		0x03
#define LOG_2PC_DISABLED	0x04
#define LOG_2PC_NO_MONITOR 0x12 /* recov query could not be made */
#define LOG_2PC_NO_RECORD 0x0 /* not mentioned in logs */

#define LOG_2PC_COMMIT_S	"\001"
#define LOG_2PC_ABORT_S		"\002"


#define LT_2PC_TEXT(a, str)							\
  (LOG_2PC_ABORT == a ? "rollback": LOG_2PC_COMMIT == a ? "commit" : LOG_CL_2PC_PREPARE == a ? "cl prepared": \
   0 == a ? "no record in logs" : LOG_CL_2PC_PREPARE_FROM_SYNC == a ? "prepared received from flt log sync" : LOG_2PC_NO_MONITOR == a ? "owner not online" : (snprintf (str, sizeof (str), "other %d", a), str))

caddr_t log_cl_trx_id (caddr_t * header);
caddr_t log_2pc_hosts (caddr_t * header);
int log_is_replayed (caddr_t trx_id);
void log_remember_replay (caddr_t trx_id);
int lt_cl_is_single_authority (lock_trx_t * lt);


#endif /* _WI_LOG_H */
