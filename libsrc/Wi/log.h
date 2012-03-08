/*
 *  log.h
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
#define LOGH_COMMIT_FLAG_OFFSET 5 /* 3 bytes of array head, 2 bytes of logh_cl_2pc string header, first byte of string */

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


#ifdef SQL_SUCCESS  /* If included in the DBMS code */
void logh_set_level (lock_trx_t * lt, caddr_t * logh);

int log_replay_trx (dk_session_t * in, client_connection_t * cli,
    caddr_t repl_head, int is_repl, int is_pushback);

int log_write_replication (caddr_t * header, char * string, long bytes);
#endif

void tcpses_set_fd (session_t * ses, int fd);
int tcpses_get_fd (session_t * ses);
void dbs_sys_db_check (caddr_t file);
extern int32 cl_non_logged_write_mode;

#endif /* _WI_LOG_H */
