/*
 *  security.h
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

#ifndef _SECURITY_H
#define _SECURITY_H

int sec_user_has_group (oid_t CheckGroup, oid_t user);
int sec_user_has_group_name (char *name, oid_t user);
int sec_user_is_in_hash (dk_hash_t *ht, oid_t user, int op);

#define QI_IS_DBA(qi) \
  (sec_user_has_group (0, ((query_instance_t *) qi)->qi_u_id) || \
   sec_user_has_group (0, ((query_instance_t *) qi)->qi_g_id))

user_t * sec_id_to_user (oid_t id);

int sec_tb_check (dbe_table_t * tb, oid_t group, oid_t user, int op);

int sec_col_check (dbe_column_t * col, oid_t group, oid_t user, int op);

/* group and user were defined as pointers, corrected by AK 17-APR-97: */
int sec_proc_check (query_t * proc, oid_t group, oid_t user);

void sec_dd_grant (dbe_schema_t * sc, const char * object, const char * column,
    int is_grant, int op, oid_t grantee);
void rds_dd_grant (const char *object, int is_grant, oid_t grantee);

void sec_read_tables (void);

caddr_t sec_read_grants (client_connection_t * cli, query_instance_t * caller_qi,
    char * table, int only_execute_gr);
caddr_t sec_read_tb_rls (client_connection_t * cli, query_instance_t * caller_qi,
    char * table);

user_t * sec_check_login (char * name, char * pass, dk_session_t * ses);

#define PLLH_NO_AUTH	-1
#define PLLH_INVALID	0
#define PLLH_VALID	1
int sec_call_login_hook (caddr_t *puid, caddr_t digest, dk_session_t *ses, client_connection_t *cli);


int sec_check_info (user_t * user, char *app_name, long pid, char *machine, char *os);

void sec_read_users (void);
user_t *sec_new_user (query_instance_t * qi, char *name, char *pass);


user_t * sec_name_to_user (char * name);
int sec_normalize_user_name (char *name, size_t max_name);

void sec_set_user_data (char * u_name, char * data);
void sec_set_user_struct (caddr_t u_name, caddr_t u_pwd,
			  long u_id, long u_g_id, caddr_t u_dta, int is_role, caddr_t u_sys_name, caddr_t u_sys_pwd);
void sec_remove_user_struct (query_instance_t * qi, user_t * user, caddr_t uname);
int init_os_users (user_t * user, caddr_t u_sys_name, caddr_t u_sys_pwd);

void sec_grant_single_role (user_t *user, user_t *gr, int make_err);
void sec_revoke_single_role (user_t *user, user_t *gr, int make_err);
void cli_flush_stmt_cache (user_t *user);
extern int sec_usr_flatten_g_ids_refill (user_t *user);

struct sql_tree_s; /* avoid gcc complaints */
void sec_check_ddl (query_instance_t * qi, struct sql_tree_s * tree);
extern int sec_bif_caller_is_dba (query_instance_t * qi);
oid_t sec_bif_caller_uid (query_instance_t * qi);
EXE_EXPORT (void, sec_check_dba, (query_instance_t * qi, const char * func));

void sec_log_login_failed (char *name, dk_session_t * ses, int mode);
void failed_login_remove (dk_session_t *ses);
void failed_login_purge (void);
void failed_login_from (dk_session_t *ses);
extern user_t *sec_set_user (query_instance_t * qi, char *name, char *pass, int is_update);
void sec_set_user_cert (caddr_t u_name, caddr_t u_cert);
void sec_user_remove_cert (caddr_t u_name, caddr_t u_cert);
int failed_login_to_disconnect (dk_session_t *ses);
int change_thread_user (user_t * user);
int sec_set_user_os_struct (caddr_t u_name, caddr_t u_sys_name, caddr_t u_sys_pwd);
caddr_t sec_get_user_by_cert (caddr_t u_cert);
void sec_user_disable (caddr_t u_name, int flag);
int set_user_id (client_connection_t * cli, caddr_t name, caddr_t preserve_qual);

#define USER_SHOULD_EXIST 0x1
#define USER_SHOULD_BE_LOGIN_ENABLED 0x2
#define USER_SHOULD_BE_SQL_ENABLED 0x4
#define USER_SHOULD_BE_DAV_ENABLED 0x8
#define USER_NOBODY_IS_PERMITTED 0x1000
#define USER_SPARQL_IS_PERMITTED 0x2000
extern caddr_t bif_user_id_or_name_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func);
extern user_t *bif_user_t_arg_int (caddr_t uid_or_uname, int nth, const char *func, int flags, int error_level);
extern user_t *bif_user_t_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int flags, int error_level);


#ifdef WIN32
#ifndef IGNORE_SERVER_IMP_TOKEN
  HANDLE server_imp_token;
#endif /* IGNORE_SERVER_IMP_TOKEN */
#endif

extern id_hash_t *sec_users;
void fill_log_user (user_t * usr);
extern dk_hash_t *sec_user_by_id;
extern void sec_init (void);

#endif /* _SECURITY_H */
