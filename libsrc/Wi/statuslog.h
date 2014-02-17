/*
 *  statuslog.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

extern unsigned long log_stat;
extern unsigned long log_file_line;

#define LOG_HUMAN_READ		0
#define LOG_VUSER		1	/* USER */
#define LOG_FAILED		2	/* FAIL */
#define LOG_COMPILE		3	/* COMP */
#define LOG_DDL			4	/* DDLC */
#define LOG_CLIENT_SQL		5	/* CSLQ */
#define LOG_SRV_ERROR		6	/* ERRS */
#define LOG_DSN			7	/* DSNL	*/
#define LOG_SQL_SEND		8	/* DSNS	*/
#define LOG_TRANSACT		9	/* LTRS	*/
#define LOG_R_TRANSACT		10	/* RTRS	*/
#define LOG_EXEC		11	/* EXEC	*/
#define LOG_SOAP		12	/* SOAP	*/
#define LOG_THR			13	/* SOAP	*/
#define LOG_CURSOR		14	/* CURS	*/
#define LOG_SOAP_CLI		15	/* SOAP	*/

#define DO_LOG1(cond) (log_stat & (1 << (cond)))

#define DO_LOG(cond) (DO_LOG1(cond) && \
    (!(log_file_line & 0x2) || ( log_info ("%s (%d)", __FILE__, (int) __LINE__), 1) > 0))

#define DO_LOG_INT(cond)  (DO_LOG (cond) && is_internal_user (cli))
#define LOG_GET \
              char from[16]; \
              char user[16]; \
              char peer[32]; \
              dks_client_ip (cli, from, user, peer, sizeof (from), sizeof (user), sizeof (peer));

#define GET_USER \
	      DO_LOG (LOG_HUMAN_READ) ? \
	        (usr && usr->usr_name ? usr->usr_name : "<DBA>" ) \
	      : \
	        ((usr && usr->usr_id) ? usr->log_usr_name : "0")

#ifndef _THREAD_INT_HS
void dks_client_ip (client_connection_t *cli, char *buf, char *user, char *peer, int buf_len, int user_len, int peer_len);
int is_internal_user (client_connection_t *cli);
#endif

#define LOG_STR_D const char * str [] = {"user_names", "user_log", "failed_log", "compile", \
  "ddl_log", "client_sql", "errors", "dsn", "sql_send", "transact", "remote_transact", \
  "exec", "soap", "thread", "cursor", "soap_client" }
#define LOG_STR_L (sizeof (str)/sizeof (char *))
#define LOG_PRINT_STR_L 500
#define LOG_PRINT_SOAP_STR_L 1500

