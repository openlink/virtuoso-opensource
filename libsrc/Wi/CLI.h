/*
 *  CLI.h
 *
 *  $Id$
 *
 *  SQL client data structures
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

#ifndef _CLI_H
#define _CLI_H

#include "Dk.h"
#include "odbcinc.h"
#include "virtext.h"	/* virtuoso odbc extensions */
#include "sqlcomp.h"
#include "numeric.h"
#include "blobio.h"
#include "wirpce.h"
#include "date.h"
#include "datesupp.h"

#ifndef UNALIGNED
#define UNALIGNED
#endif

#define VARCHAR_UNSPEC_SIZE "4070"
typedef struct sql_error_rec_s
  {
    char *		sql_state;
    char *		sql_error_msg;
    int			sql_error_col;
    struct sql_error_rec_s *	sql_error_next;
  } sql_error_rec_t;


typedef struct sql_error_s
  {
    sql_error_rec_t *	err_queue;
    int			err_rc;
    sql_error_rec_t *	err_queue_head;
  } sql_error_t;


typedef struct cli_environment_s
  {
    sql_error_t		env_error;
    dk_set_t		env_connections;
	SQLINTEGER		env_connection_pooling;
	SQLINTEGER		env_cp_match;
	SQLINTEGER		env_odbc_version;
	int				env_output_nts;
	dk_mutex_t *		env_mtx;
  } cli_environment_t;


typedef struct con_defaults_s
  {
    long	cdef_query_timeout;
    long	cdef_txn_timeout;
    long	cdef_prefetch;
    long	cdef_prefetch_bytes;
    long	cdef_no_char_c_escape;
    long	cdef_utf8_execs;
    long	cdef_binary_timestamp;
  } con_defaults_t;

#define STMT_MSEC_OPTION(x) \
	((x > 0x7fffffff / 1000) ? 0x7ffffff : x * 1000)


typedef struct cli_connection_s
  {
    sql_error_t		con_error;
    cli_environment_t * con_environment;
    dk_session_t *	con_session;
    dk_set_t		con_statements;
    SDWORD		con_last_id;
    SDWORD		con_autocommit;
    long		con_isolation;
    int			con_is_read_only;
    id_hash_t *		con_cursors;
    SQLCHAR *		con_user;
    SQLCHAR *		con_dsn;
    SDWORD		con_access_mode;
    SQLCHAR *		con_qualifier;
    SQLCHAR *		con_db_ver;
    int 		con_db_casemode;
    int			con_db_gen; /* last 4 digits of con_db_ver */
    dk_hash_t *		con_bookmarks;
    long		con_last_bookmark;
    dk_mutex_t *	con_mtx;

    /* ODBC 3 stuff */
    SQLUINTEGER 	con_async_mode;
    SQLUINTEGER 	con_timeout;
    SQLUINTEGER 	con_max_rows;
    con_defaults_t	con_defs;
    wcharset_t *	con_charset;
    caddr_t		con_charset_name;
    int 		con_wide_as_utf16;
    int			con_string_is_utf8;
#ifdef VIRTTP
    caddr_t con_d_trx_id; /* connection is enlisted in Virtuoso TP transaction */
#endif
    caddr_t		con_encrypt;
    caddr_t		con_ca_list;
    int 		con_pwd_cleartext;
    int 		con_round_robin;
    long		con_shutdown;

#ifdef INPROCESS_CLIENT
    void *		con_inprocess_client;
#endif
    int			con_in_transaction;
    int			con_no_system_tables;
    int 		con_treat_views_as_tables;
    dk_hash_t *		con_rdf_langs;
    dk_hash_t *		con_rdf_types;
  } cli_connection_t;

#define IN_CON(c) mutex_enter (c->con_mtx)

#define LEAVE_CON(c) mutex_leave (c->con_mtx)

typedef struct col_binding_s col_binding_t;
struct col_binding_s
  {
    col_binding_t *	cb_next;
    caddr_t		cb_place;
    SQLLEN *		cb_length;
    SQLLEN		cb_max_length;
    int			cb_c_type; /* ODBC SQL_C_xx */
    SQLLEN		cb_read_up_to; /* used by SQLGetData */
    int			cb_not_first_getdata;
  };


typedef struct parm_binding_s parm_binding_t;
struct parm_binding_s
  {
    parm_binding_t *	pb_next;
    int			pb_nth;
    caddr_t		pb_place;
    SQLLEN *		pb_length;
    SQLULEN		pb_max_length;
    int			pb_param_type;
    int			pb_c_type;
    SQLSMALLINT		pb_sql_type;
    SQLLEN		pb_max;
  };


/* with array param data at exec blobs the bhid identifies the bh's param row and ipar */
#define BHID(row_no, col_no) (((row_no) * 1024) + (col_no))
#define BHID_COL(bhid) ((bhid) & 1023)
#define BHID_ROW(bhid) ((bhid) >> 10)


#define ROW_APP_DESCRIPTOR		1
#define ROW_IMP_DESCRIPTOR		2
#define PARAM_APP_DESCRIPTOR	3
#define PARAM_IMP_DESCRIPTOR	4

typedef struct stmt_descriptor_s  stmt_descriptor_t;

typedef struct pending_call_s
  {
    int		p_api;
    int		psp_op;
    int		psp_irow;
    int		psp_toral_rows;
    int		psp_nth_row;
    SQLHSTMT	psp_st_stmt;
    caddr_t	pex_text;
  } pending_call_t;


typedef struct cli_stmt_s
  {
    sql_error_t		stmt_error;

    /* Statement Information */
    int			stmt_status;
    char *		stmt_text;
    caddr_t		stmt_id;
    cli_connection_t *	stmt_connection;
    stmt_compilation_t *stmt_compilation;

    /* Cursor */
    future_t *		stmt_future;
    int			stmt_current_of;
    ptrlong		stmt_n_rows_to_get;
    int			stmt_at_end;
    char *		stmt_cursor_name;
    caddr_t		stmt_prefetch_row;

    /* Binding */
    int			stmt_n_parms;
    int			stmt_n_cols;
    SQLULEN		stmt_parm_rows;
    SQLULEN *		stmt_pirow;
    SQLLEN		stmt_parm_rows_to_go;
    parm_binding_t *	stmt_parms;
    parm_binding_t *	stmt_return;	/* proc return value host var */
    col_binding_t *	stmt_cols;

    /* Options */
    stmt_options_t *	stmt_opts;
    int			stmt_is_deflt_rowset;

    SDWORD		stmt_last_asked_param;	/* set when returning SQL_NEED_DATA */

    int			stmt_is_proc_returned;
    caddr_t *		stmt_current_row;
    char		stmt_co_last_in_batch;
    SDWORD		stmt_rows_affected;
    caddr_t		stmt_identity_value;
    caddr_t **		stmt_rowset;
    long		stmt_pos_in_rowset;
    int			stmt_bind_type;
    SQLUSMALLINT *		stmt_row_status;
    int			stmt_rowset_fill;
    int			stmt_fetch_mode; /* extended vs. regular */
    struct cli_stmt_s *	stmt_set_pos_stmt;
    int			stmt_fwd_fetch_irow;
    int			stmt_fetch_current_of;
    col_binding_t * 	stmt_bookmark_cb;
    dk_hash_t *		stmt_bookmarks;
    id_hash_t *		stmt_bookmarks_rev;

    /* ODBC 3 fields */
    SQLULEN *           stmt_rows_fetched_ptr;
    int			stmt_param_bind_type;
    SQLUSMALLINT *		stmt_param_status;
    SQLLEN *	        stmt_bookmark_ptr;
    SQLULEN 		stmt_retrieve_data;
    SQLULEN		stmt_rowset_size;

	/* descriptors */
    stmt_descriptor_t *stmt_app_row_descriptor,
    			*stmt_imp_row_descriptor,
			*stmt_app_param_descriptor,
			*stmt_imp_param_descriptor;

    pending_call_t	stmt_pending;
    dk_set_t		stmt_dae;
    long **		stmt_current_dae;
    dk_set_t		stmt_dae_fragments;
    caddr_t * 		stmt_param_array;
    dtp_t		stmt_next_putdata_dtp;
#ifndef MAP_DIRECT_BIN_CHAR
    int			stmt_next_putdata_translate_char_bin;
#endif
    int			stmt_on_first_row;
  } cli_stmt_t;


#define STS_NEW 1
#define STS_PREPARED 2
#define STS_LOCAL_DAE 3
#define STS_SERVER_DAE 4
#define STS_EXECUTED 5



struct stmt_descriptor_s {

		int d_type;
		cli_stmt_t * d_stmt;
		SQLINTEGER * d_bind_offset_ptr;
		int d_max_recs;
	};

#define FETCH_NONE 0
#define FETCH_FETCH 1
#define FETCH_EXT 2

#ifndef dbg_printf
# ifdef DEBUG_
#  define dbg_printf(a)  printf a; fflush (stdout);
# else
#  define dbg_printf(a)
# endif
#endif

#ifndef err_printf
# define err_printf(a)
#endif


#define CON(c, cc) \
  cli_connection_t *c = (cli_connection_t *) cc

#define CON_CONNECTED(c) \
  ((c) && ((cli_connection_t *)(c))->con_session)

#define ENV(e,ee) \
  cli_environment_t *e = (cli_environment_t *) ee

#define STMT(s, st) \
  cli_stmt_t *s = (cli_stmt_t *) st

#define DESC(d, de) \
  stmt_descriptor_t *d = (stmt_descriptor_t *) de

#define NOT_IMPL_FUN(eo, msg) \
  set_error ((sql_error_t *) eo, "IM001", "CL001", (msg)); \
  return SQL_ERROR;


#define SUCCESS(err) \
  ((err)->err_queue ? SQL_SUCCESS_WITH_INFO : SQL_SUCCESS)


#if !defined (LONG_TO_EXT)
#if defined (LOW_ORDER_FIRST)
# define LONG_TO_EXT(l) \
  ((((uint32) (l) >> 24) | \
   (((uint32) (l) & 0x00ff0000) >> 8) | \
   (((uint32) (l) & 0x0000ff00) << 8) | \
   (((uint32) (l)) << 24)) )
#else
# define LONG_TO_EXT(l) (l)
#endif
#endif

#define TV_TO_STRING(tv) \
  ((tv)->tv_sec =  LONG_TO_EXT ((tv)->tv_sec), \
   (tv)->tv_usec = LONG_TO_EXT ((tv)->tv_usec) )

#ifdef INPROCESS_CLIENT

# define VERIFY_INPROCESS_CLIENT(con)			\
  do							\
    {							\
      SQLRETURN rc = verify_inprocess_client (con);	\
      if (rc != SQL_SUCCESS)				\
        return rc;					\
    }							\
  while (0)

# define CON_IS_INPROCESS(con) (con->con_inprocess_client != NULL)

#else

# define VERIFY_INPROCESS_CLIENT(con)

# define CON_IS_INPROCESS(con) (0)

#endif

/* CLIsql1.c */
SQLRETURN internal_sql_connect (
	SQLHDBC hdbc,
	SQLCHAR * szDSN,
	SQLSMALLINT cbDSN,
	SQLCHAR * szUID,
	SQLSMALLINT cbUID,
	SQLCHAR * szAuthStr,
	SQLSMALLINT cbAuthStr);

#ifdef INPROCESS_CLIENT
SQLRETURN verify_inprocess_client (cli_connection_t *con);
#endif

/* CLIuti.c */
int sql_type_to_sqlc_default (int sqlt);
int dv_to_sql_type (dtp_t dv, int cli_binary_timestamp);
char *sql_type_to_sql_type_name (int type, char *resbuf, int maxbytes);
caddr_t box_n_string (SQLCHAR *str, SQLLEN len);
caddr_t con_new_id (cli_connection_t *con);
parm_binding_t *stmt_nth_parm (cli_stmt_t *stmt, int n);
col_binding_t *stmt_nth_col (cli_stmt_t *stmt, int n);
void set_error (sql_error_t *err, const char *state, const char *virt_state, const char *message);
sql_error_rec_t * cli_make_error (const char * state, const char *virt_state, const char * msg, int col);
void  err_queue_append (sql_error_rec_t ** q1, sql_error_rec_t ** q2);
void set_success_info (sql_error_t * err, const char *state, const char *virt_state, const char *message, int col);
void set_data_truncated_success_info (cli_stmt_t *stmt, const char *virt_state, SQLUSMALLINT icol);
SQLRETURN stmt_seq_error (cli_stmt_t *stmt);
void stmt_set_proc_return (cli_stmt_t *stmt, caddr_t *res);
SQLRETURN stmt_process_result (cli_stmt_t *stmt, int needs_evl);
#if 0
void stmt_check_at_end (cli_stmt_t * stmt);
#endif
cli_stmt_t *con_find_cursor (cli_connection_t *con, caddr_t id);
caddr_t con_make_current_ofs (cli_connection_t *con, cli_stmt_t *stmt);
void string_to_tm (struct tm *tm, int32 *usec_ret, char *tmp, SQLSMALLINT sql_type);
caddr_t *stmt_collect_parms (cli_stmt_t *stmt);
SQLRETURN str_box_to_buffer(char *box, char *buffer, int buffer_length, void *string_length_ptr, int length_is_long, sql_error_t *error);
void str_box_to_place (char *box, char *place, int max, int *sz);
int dv_to_sqlc_default (caddr_t xx);
int vector_to_text (caddr_t vec, size_t box_len, dtp_t vectype, char *dest, size_t dest_size);
SQLLEN dv_to_str_place (caddr_t it, dtp_t dtp, SQLLEN max, caddr_t place, SQLLEN *len_ret, SQLLEN str_from_pos, cli_stmt_t *stmt, int nth_col, SQLLEN box_len, int c_type, SQLSMALLINT sql_type, SQLLEN *out_chars);
SQLLEN dv_to_place (caddr_t it, int c_type, SQLSMALLINT sql_type, SQLLEN max, caddr_t place, SQLLEN *len_ret, SQLLEN str_from_pos, cli_stmt_t *stmt, int nth_col, SQLLEN *out_chars);
#ifndef MAP_DIRECT_BIN_CHAR
void bin_dv_to_str_place (unsigned char *str, char *place, size_t nbytes);
void bin_dv_to_wstr_place (unsigned char *str, wchar_t *place, size_t nbytes);
#endif
void stmt_set_columns (cli_stmt_t *stmt, caddr_t *row, int nth_in_set);
unsigned char *strncasestr (unsigned char *string1, unsigned char *string2, size_t maxbytes);
SQLCHAR *stmt_convert_brace_escapes (SQLCHAR *statement_text, SQLINTEGER *newCB);
char *get_next_keyword (char **str_ptr, char **start_ptr, char *result, int maxsize);
SQLCHAR *stmt_correct_create_table_for_jdbc_test (SQLCHAR *statement_text);
void stmt_reset_getdata_status (cli_stmt_t * stmt, caddr_t * row);
long stmt_row_bookmark (cli_stmt_t * stmt, caddr_t * row);
void stmt_free_bookmarks (cli_stmt_t * stmt);
caddr_t buffer_to_dv (caddr_t place, SQLLEN * len, int c_type, int sql_type, long bhid,
	      cli_stmt_t * err_stmt, int inprocess);
caddr_t stmt_param_place_ptr ( parm_binding_t * pb, int nth, cli_stmt_t * stmt, SQLULEN length );
SQLULEN sqlc_sizeof (int sqlc, SQLULEN deflt);
SQLCHAR * stmt_convert_brace_escapes (SQLCHAR * statement_text, SQLINTEGER * newCB);
void stmt_free_current_rows (cli_stmt_t * stmt);

SQLLEN col_desc_get_display_size (col_desc_t *cd, int cli_binary_timestamp);

#if defined(PARAM_DEBUG)
void dbg_print_box (caddr_t object, FILE * out);
#endif
extern int isdts_mode;

#define cli_dbg_printf(a)


/*
 *  Added prototypes for internal functions
 */
SQLRETURN SQL_API virtodbc__SQLCancel (SQLHSTMT hstmt);

SQLRETURN SQL_API virtodbc__SQLDescribeCol (SQLHSTMT hstmt, SQLUSMALLINT icol,
    SQLCHAR * szColName, SQLSMALLINT cbColNameMax, SQLSMALLINT * pcbColName,
    SQLSMALLINT * pfSqlType, SQLULEN * pcbColDef, SQLSMALLINT * pibScale,
    SQLSMALLINT * pfNullable);

SQLRETURN SQL_API virtodbc__SQLExecDirect (SQLHSTMT hstmt, SQLCHAR * szSqlStr,
    SDWORD cbSqlStr);

SQLRETURN SQL_API virtodbc__SQLFetch (SQLHSTMT hstmt, int preserve_rowset_at_end);

SQLRETURN SQL_API virtodbc__SQLSetParam (SQLHSTMT hstmt, SQLUSMALLINT ipar, SQLSMALLINT fCType,
    SQLSMALLINT fSqlType, SQLULEN cbColDef, SQLSMALLINT ibScale, SQLPOINTER rgbValue,
    SQLLEN * pcbValue);

SQLRETURN SQL_API virtodbc__SQLGetData (SQLHSTMT hstmt, SQLUSMALLINT icol, SQLSMALLINT fCType,
    SQLPOINTER rgbValue, SQLLEN cbValueMax, SQLLEN * pcbValue);

SQLRETURN SQL_API virtodbc__SQLAllocEnv (SQLHENV * phenv);

SQLRETURN SQL_API virtodbc__SQLAllocConnect (SQLHENV henv, SQLHDBC * phdbc);

SQLRETURN SQL_API virtodbc__SQLAllocStmt (SQLHDBC hdbc, SQLHSTMT * phstmt);

SQLRETURN SQL_API virtodbc__SQLFreeEnv (SQLHENV henv);

SQLRETURN SQL_API virtodbc__SQLFreeConnect (SQLHDBC hdbc);

SQLRETURN SQL_API virtodbc__SQLFreeStmt (SQLHSTMT hstmt, SQLUSMALLINT fOption);

SQLRETURN SQL_API virtodbc__SQLError (SQLHENV henv, SQLHDBC hdbc, SQLHSTMT hstmt,
	SQLCHAR * szSqlState, SQLINTEGER * pfNativeError, SQLCHAR * szErrorMsg,
	SQLSMALLINT cbErrorMsgMax, SQLSMALLINT * pcbErrorMsg, int bClearState);

SQLRETURN SQL_API virtodbc__SQLGetStmtOption (SQLHSTMT hstmt, SQLUSMALLINT fOption, SQLPOINTER pvParam);

SQLRETURN SQL_API virtodbc__SQLSetStmtOption (SQLHSTMT hstmt, SQLUSMALLINT fOption, SQLULEN vParam);

SQLRETURN SQL_API virtodbc__SQLSetConnectOption (SQLHDBC hdbc, SQLUSMALLINT fOption, SQLULEN vParam);

SQLRETURN SQL_API virtodbc__SQLGetConnectOption (SQLHDBC hdbc, SQLUSMALLINT fOption, SQLPOINTER pvParam, SQLINTEGER StringLength, UNALIGNED SQLINTEGER * StringLengthPtr);

SQLRETURN SQL_API virtodbc__SQLGetTypeInfo (SQLHSTMT hstmt, SQLSMALLINT fSqlType);

SQLRETURN SQL_API virtodbc__SQLAllocHandle (SQLSMALLINT handleType, SQLHANDLE inputHandle, SQLHANDLE * outputHandlePtr);

SQLRETURN SQL_API virtodbc__SQLFreeHandle (SQLSMALLINT handleType, SQLHANDLE handle);

SQLRETURN SQL_API virtodbc__SQLExtendedFetch ( SQLHSTMT hstmt, SQLUSMALLINT fFetchType, SQLLEN irow, SQLULEN * pcrow,
				    SQLUSMALLINT * rgfRowStatus, SQLLEN bookmark_offset);

SQLRETURN SQL_API virtodbc__SQLTransact ( SQLHENV henv, SQLHDBC hdbc, SQLUSMALLINT fType);

SQLRETURN SQL_API virtodbc__SQLPrepare (SQLHSTMT hstmt,SQLCHAR * szSqlStr, SQLINTEGER cbSqlStr);

SQLRETURN SQL_API virtodbc__SQLSetPos ( SQLHSTMT hstmt, SQLSETPOSIROW irow, SQLUSMALLINT fOption, SQLUSMALLINT fLock);

SQLRETURN SQL_API virtodbc__SQLColAttributes (SQLHSTMT hstmt,SQLUSMALLINT icol,SQLUSMALLINT fDescType, SQLPOINTER rgbDesc,SQLSMALLINT cbDescMax,SQLSMALLINT * pcbDesc, SQLLEN * pfDesc);

SQLRETURN SQL_API virtodbc__SQLNumResultCols (SQLHSTMT hstmt, SQLSMALLINT * pccol);

SQLRETURN SQL_API virtodbc__SQLBindParameter ( SQLHSTMT hstmt, SQLUSMALLINT ipar, SQLSMALLINT fParamType, SQLSMALLINT fCType,
    SQLSMALLINT fSqlType, SQLULEN cbColDef, SQLSMALLINT ibScale, SQLPOINTER rgbValue, SQLLEN cbValueMax, SQLLEN * pcbValue);


SQLRETURN SQL_API virtodbc__SQLSpecialColumns ( SQLHSTMT hstmt, SQLUSMALLINT fColType, SQLCHAR * szTableQualifier,
	SQLSMALLINT cbTableQualifier, SQLCHAR * szTableOwner, SQLSMALLINT cbTableOwner, SQLCHAR * szTableName,
	SQLSMALLINT cbTableName, SQLUSMALLINT fScope, SQLUSMALLINT fNullable);

SQLRETURN SQL_API virtodbc__SQLStatistics ( SQLHSTMT hstmt, SQLCHAR * szTableQualifier, SQLSMALLINT cbTableQualifier,
	SQLCHAR * szTableOwner, SQLSMALLINT cbTableOwner, SQLCHAR * szTableName, SQLSMALLINT cbTableName,
	SQLUSMALLINT fUnique, SQLUSMALLINT fAccuracy);
caddr_t stmt_parm_to_dv (parm_binding_t * pb, int nth, long bhid, cli_stmt_t *stmt);

SQLRETURN SQL_API
virtodbc__SQLColumnPrivileges (
	SQLHSTMT hstmt,
	SQLCHAR * szTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * szTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * szTableName,
	SQLSMALLINT cbTableName,
	SQLCHAR * szColumnName,
	SQLSMALLINT cbColumnName);

SQLRETURN SQL_API
virtodbc__SQLColumns (
	SQLHSTMT hstmt,
	SQLCHAR * szTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * szTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * szTableName,
	SQLSMALLINT cbTableName,
	SQLCHAR * szColumnName,
	SQLSMALLINT cbColumnName);

SQLRETURN SQL_API
virtodbc__SQLForeignKeys (
	SQLHSTMT hstmt,
	SQLCHAR * szPkTableQualifier,
	SQLSMALLINT cbPkTableQualifier,
	SQLCHAR * szPkTableOwner,
	SQLSMALLINT cbPkTableOwner,
	SQLCHAR * szPkTableName,
	SQLSMALLINT cbPkTableName,
	SQLCHAR * szFkTableQualifier,
	SQLSMALLINT cbFkTableQualifier,
	SQLCHAR * szFkTableOwner,
	SQLSMALLINT cbFkTableOwner,
	SQLCHAR * szFkTableName,
	SQLSMALLINT cbFkTableName);

SQLRETURN SQL_API
virtodbc__SQLGetCursorName (
	SQLHSTMT hstmt,
	SQLCHAR * szCursor,
	SQLSMALLINT cbCursorMax,
	SQLSMALLINT * pcbCursor);

SQLRETURN SQL_API
virtodbc__SQLGetInfo (
	SQLHDBC hdbc,
	SQLUSMALLINT fInfoType,
	SQLPOINTER rgbInfoValue,
	SQLSMALLINT cbInfoValueMax,
	SQLSMALLINT * pcbInfoValue);

SQLRETURN SQL_API
virtodbc__SQLNativeSql (
	SQLHDBC hdbc,
	SQLCHAR * szSqlStrIn,
	SQLINTEGER cbSqlStrIn,
	SQLCHAR * szSqlStr,
	SQLINTEGER cbSqlStrMax,
	SQLINTEGER * pcbSqlStr);

SQLRETURN SQL_API
virtodbc__SQLPrimaryKeys (
	SQLHSTMT hstmt,
	SQLCHAR * szTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * szTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * szTableName,
	SQLSMALLINT cbTableName);

SQLRETURN SQL_API
virtodbc__SQLProcedureColumns (
	SQLHSTMT hstmt,
	SQLCHAR * szProcQualifier,
	SQLSMALLINT cbProcQualifier,
	SQLCHAR * szProcOwner,
	SQLSMALLINT cbProcOwner,
	SQLCHAR * szProcName,
	SQLSMALLINT cbProcName,
	SQLCHAR * szColumnName,
	SQLSMALLINT cbColumnName);

SQLRETURN SQL_API
virtodbc__SQLProcedures (
	SQLHSTMT hstmt,
	SQLCHAR * szProcQualifier,
	SQLSMALLINT cbProcQualifier,
	SQLCHAR * szProcOwner,
	SQLSMALLINT cbProcOwner,
	SQLCHAR * szProcName,
	SQLSMALLINT cbProcName);

SQLRETURN SQL_API
virtodbc__SQLSetCursorName (
      SQLHSTMT hstmt,
      SQLCHAR * szCursor,
      SQLSMALLINT cbCursor);

SQLRETURN SQL_API
virtodbc__SQLTablePrivileges (
	SQLHSTMT hstmt,
	SQLCHAR * szTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * szTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * szTableName,
	SQLSMALLINT cbTableName);

SQLRETURN SQL_API
virtodbc__SQLTables (
	SQLHSTMT hstmt,
	SQLCHAR * szTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * szTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * szTableName,
	SQLSMALLINT cbTableName,
	SQLCHAR * szTableType,
	SQLSMALLINT cbTableType);

int sql_fetch_scrollable (cli_stmt_t * stmt);

#ifndef WIN32
#define HWND void *
#endif


#if ODBCVER >= 0x0300
SQLRETURN SQL_API
virtodbc__SQLGetConnectAttr (SQLHDBC connectionHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER StringLength,
    UNALIGNED SQLINTEGER * StringLengthPtr);

SQLRETURN SQL_API
virtodbc__SQLGetDescRec (SQLHDESC descriptorHandle,
    SQLSMALLINT RecNumber,
    SQLCHAR * Name,
    SQLSMALLINT BufferLength,
    SQLSMALLINT * StringLengthPtr,
    SQLSMALLINT * TypePtr,
    SQLSMALLINT * SubTypePtr,
    SQLLEN * LengthPtr,
    SQLSMALLINT * PrecisionPtr,
    SQLSMALLINT * ScalePtr,
    SQLSMALLINT * NullablePtr);

SQLRETURN SQL_API
virtodbc__SQLGetDescField (SQLHDESC descriptorHandle,
    SQLSMALLINT RecNumber,
    SQLSMALLINT FieldIdentifier,
    SQLPOINTER ValuePtr,
    SQLINTEGER BufferLength,
    SQLINTEGER * StringLengthPtr);

SQLRETURN SQL_API
virtodbc__SQLGetStmtAttr (SQLHSTMT statementHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER BufferLength,
    SQLINTEGER * StringLengthPtr);

SQLRETURN SQL_API
virtodbc__SQLSetConnectAttr (SQLHDBC connectionHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER StringLength);

SQLRETURN SQL_API
virtodbc__SQLGetDiagField (SQLSMALLINT nHandleType,
    SQLHANDLE Handle,
    SQLSMALLINT nRecNumber,
    SQLSMALLINT nDiagIdentifier,
    SQLPOINTER pDiagInfoPtr,
    SQLSMALLINT nBufferLength,
    SQLSMALLINT * pnStringLengthPtr);

SQLRETURN SQL_API
virtodbc__SQLGetDiagRec (SQLSMALLINT HandleType,
    SQLHANDLE Handle,
    SQLSMALLINT RecNumber,
    SQLCHAR * Sqlstate,
    SQLINTEGER * NativeErrorPtr,
    SQLCHAR * MessageText,
    SQLSMALLINT BufferLength,
    SQLSMALLINT * TextLengthPtr);

SQLRETURN SQL_API
virtodbc__SQLSetDescField (SQLHDESC descriptorHandle,
    SQLSMALLINT RecNumber,
    SQLSMALLINT FieldIdentifier,
    SQLPOINTER ValuePtr,
    SQLINTEGER BufferLength);

SQLRETURN SQL_API
virtodbc__SQLSetStmtAttr (SQLHSTMT statementHandle,
    SQLINTEGER Attribute,
    SQLPOINTER ValuePtr,
    SQLINTEGER StringLength);

SQLRETURN SQL_API
virtodbc__SQLColAttribute (SQLHSTMT statementHandle,
    SQLUSMALLINT ColumnNumber,
    SQLUSMALLINT FieldIdentifier,
    SQLPOINTER CharacterAttributePtr,
    SQLSMALLINT BufferLength,
    SQLSMALLINT * StringLengthPtr,
#if !defined (NO_UDBC_SDK) && !defined (WIN32)
    SQLPOINTER  NumericAttributePtr
#else
    SQLLEN *NumericAttributePtr
#endif
    );
#endif


extern char application_name[60];
extern char __virtodbc_dbms_name[512];
extern col_desc_t bm_info;

#define VIRT_SERVER "[Virtuoso Server]"
#define VIRT_SERVER_LEN sizeof (VIRT_SERVER) - 1

caddr_t cli_box_server_msg (char *msg);

#define STMT_CHARSET(hstmt)	\
	STMT(stmt, hstmt);	\
	wcharset_t *charset = stmt->stmt_connection->con_charset

#define CON_CHARSET(hdbc)	\
	CON(con, hdbc);	\
	wcharset_t *charset = con->con_charset

#define DESC_CHARSET1(hdesc)	\
  DESC (desc, hdesc); \
  wcharset_t *charset = desc->d_stmt->stmt_connection->con_charset

#define DESC_CHARSET(Handle, HandleType)	\
  /*ENV (env, Handle);*/ \
  CON (con, Handle); \
  STMT (stmt, Handle); \
  DESC (desc, Handle); \
  wcharset_t * charset = (HandleType == SQL_HANDLE_DBC ? con->con_charset : \
      ( HandleType == SQL_HANDLE_STMT ? stmt->stmt_connection->con_charset : \
	(HandleType == SQL_HANDLE_DESC ? desc->d_stmt->stmt_connection->con_charset : (wcharset_t *)(NULL))))

#define NDEFINE_OUTPUT_NONCHAR_NARROW(wide, len, pcb, con, type) \
  type _##len = (type) (len * (( (con) && (con)->con_defs.cdef_utf8_execs) ? VIRT_MB_CUR_MAX : 1)); \
  caddr_t _##wide = NULL; \
  type _v##pcb, * _##pcb = &_v##pcb

#define NMAKE_OUTPUT_NONCHAR_NARROW(wide, len, con) \
  if (wide && len > 0) \
    { \
      if ((con) && (con)->con_defs.cdef_utf8_execs) \
	_##wide = dk_alloc_box (_##len * VIRT_MB_CUR_MAX, DV_LONG_STRING); \
      else \
	_##wide = (caddr_t) wide; \
    }

#define NSET_AND_FREE_OUTPUT_NONCHAR_NARROW(wide, len, plen, con) \
  if (wide && len >= 0) \
    { \
      int len2 = (!_##plen || *_##plen == SQL_NTS) ? (int) strlen (_##wide) : *_##plen; \
      if ((con) && len > 0 && (con)->con_defs.cdef_utf8_execs) \
	{ \
	  SQLSMALLINT len1; \
	  len1 = (SQLSMALLINT) cli_utf8_to_narrow (con->con_charset, (unsigned char *) _##wide, len2, (unsigned char *) wide, len); \
	  if (len1 >= 0) \
	    { \
	      if (plen) \
		*plen = len1; \
	    } \
	  else \
	    { \
	      dk_free_box (_##wide); \
	      return SQL_ERROR; \
	    } \
	  dk_free_box (_##wide); \
	} \
      else \
	if (plen) \
	  *plen = len2; \
    }


#define NMAKE_OUTPUT_NONCHAR_NARROW_ALLOC(wide, len, con) \
  if (wide && len > 0) \
    { \
      if ((con) && (con)->con_defs.cdef_utf8_execs) \
	_##wide = (caddr_t) dk_alloc_box (_##len * VIRT_MB_CUR_MAX, DV_LONG_STRING); \
      else \
	_##wide = (caddr_t) dk_alloc_box (_##len, DV_LONG_STRING); \
    }

#define NSET_AND_FREE_OUTPUT_NONCHAR_NARROW_FREE(wide, len, plen, con) \
  if (wide && len >= 0) \
    { \
      int len2 = (!_##plen || *_##plen == SQL_NTS) ? (int) strlen ((char *) _##wide) : *_##plen; \
      if ((con) && len > 0 && (con)->con_defs.cdef_utf8_execs) \
	{ \
	  SQLSMALLINT len1; \
	  len1 = (SQLSMALLINT) cli_utf8_to_narrow (con->con_charset, (unsigned char *) _##wide, len2, (unsigned char *) wide, len); \
	  if (len1 >= 0) \
	    { \
	      if (plen) \
		*plen = len1; \
	    } \
	  else \
	    { \
	      dk_free_box ((box_t) _##wide); \
	      return SQL_ERROR; \
	    } \
	  dk_free_box ((box_t) _##wide); \
	} \
      else \
	{ \
	  if (len2 > 0) \
 	    strncpy ((char *) wide, (char *) _##wide, len2); \
          else \
	    ((SQLCHAR *)wide)[0] = 0; \
          dk_free_box ((box_t) _##wide); \
	  if (plen) \
	    *plen = len2; \
	} \
    }

#define NDEFINE_INPUT_NARROW(param) \
  SQLCHAR *sz##param = NULL

#define NMAKE_INPUT_NARROW_N(param) \
if (wsz##param) \
{ \
  sz##param = wsz##param; \
}

#define NMAKE_INPUT_NARROW(param, con) \
if (!(con)->con_defs.cdef_utf8_execs) \
{ \
  NMAKE_INPUT_NARROW_N(param); \
} \
else \
{ \
  if (wsz##param && cb##param) \
    { \
      len = cb##param > 0 ? cb##param : strlen ((const char *) wsz##param); \
      sz##param = (SQLCHAR *) dk_alloc_box (len * VIRT_MB_CUR_MAX + 1, DV_LONG_STRING); \
      cli_narrow_to_utf8 (con->con_charset, wsz##param, len, sz##param, len * VIRT_MB_CUR_MAX + 1); \
      cb##param = (SQLSMALLINT) strlen ((const char *) sz##param); \
    } \
}

#define NFREE_INPUT_NARROW(param) \
if (wsz##param && wsz##param != sz##param) \
{ \
  dk_free_box ((box_t) sz##param); \
}


#define NDEFINE_OUTPUT_CHAR_NARROW(param, con, type) \
  SQLCHAR *sz##param = NULL; \
  type _vpcb##param, *_pcb##param = &_vpcb##param; \
  type _cb##param = cb##param * ((con)->con_defs.cdef_utf8_execs ? VIRT_MB_CUR_MAX : 1)

#define NMAKE_OUTPUT_CHAR_NARROW(param, con) \
if (wsz##param) \
  { \
    if ((con)->con_defs.cdef_utf8_execs) \
      sz##param = (SQLCHAR *) dk_alloc_box (cb##param * VIRT_MB_CUR_MAX, DV_LONG_STRING); \
    else \
      sz##param = (SQLCHAR *) wsz##param; \
  }

#define NSET_AND_FREE_OUTPUT_CHAR_NARROW(param, con) \
if (wsz##param) \
  { \
    if ((con)->con_defs.cdef_utf8_execs) \
      { \
	SQLSMALLINT len1; \
	len1 = (SQLSMALLINT) cli_utf8_to_narrow (con->con_charset, sz##param, _vpcb##param, wsz##param, cb##param); \
	if (pcb##param) \
	  *pcb##param = *_pcb##param; \
	dk_free_box ((box_t) sz##param); \
      } \
    else \
      { \
	if (pcb##param) \
	  *pcb##param = *_pcb##param; \
      } \
  }

#define NMAKE_INPUT_ESCAPED_NARROW_N(param) NMAKE_INPUT_NARROW_N(param)

#define NMAKE_INPUT_ESCAPED_NARROW(param, con) NMAKE_INPUT_NARROW(param, con)
#define NDEFINE_INPUT_NONCHAR_NARROW(wide, len) \
SQLLEN _##len = ((len) < 0 ? strlen ((char *) wide) : (len)) ; \
    caddr_t _##wide = NULL

#define NMAKE_INPUT_NONCHAR_NARROW_N(wide, len) \
    _##wide = (caddr_t) wide

#define NMAKE_INPUT_NONCHAR_NARROW(wide, len, con) \
    if ((con)->con_defs.cdef_utf8_execs) \
      { \
	if (_##len > 0 && wide) \
	  { \
            _##wide = dk_alloc_box (len * VIRT_MB_CUR_MAX + 1, DV_LONG_STRING); \
	    cli_narrow_to_utf8 (con->con_charset, (unsigned char *) wide, _##len, (unsigned char *) _##wide, _##len * VIRT_MB_CUR_MAX + 1); \
	    _##len = strlen ((char *) _##wide); \
	  } \
      } \
    else \
      { \
	NMAKE_INPUT_NONCHAR_NARROW_N(wide, len); \
      }

#define NFREE_INPUT_NONCHAR_NARROW(wide, len) \
    if (_##len > 0 && wide && ((caddr_t) wide) != _##wide) \
      { \
	dk_free_box (_##wide); \
      }

#define CHECK_SI_TRUNCATED(errptr, max, str) \
      if (max < (SQLSMALLINT) strlen (str)) \
        { \
	  rc = SQL_SUCCESS_WITH_INFO; \
	  if (errptr) \
	    set_success_info (errptr, "01004", "CL087", "String data, right truncation", 0); \
	}

#define V_SET_ODBC_STR(str, _outb, max_len, ret_len, errptr) \
      if (str) \
        { \
	  size_t slen = strlen ((const char *) (str)); \
	  if (_outb && max_len > 0) \
	    { \
	      if (slen < max_len - 1) \
		strcpy_size_ck ((char *) _outb, (const char *) (str), max_len); \
	      else \
		{ \
		  strncpy ((char *) _outb, (const char *) (str), max_len - 1); \
		  ((char *) _outb)[max_len - 1] = 0; \
		} \
	    } \
	  if (ret_len) \
	    *ret_len = (SQLSMALLINT) slen; \
	  if (max_len < (SQLSMALLINT) slen) \
	    { \
	      rc = SQL_SUCCESS_WITH_INFO; \
	      if (errptr != NULL) \
		set_success_info (errptr, "01004", "CL088", "String data, right truncation", 0); \
	    } \
	} \
      else \
        { \
	  if (_outb && max_len > 0) \
	    *((char *)_outb) = '\x0'; \
	  if (ret_len) \
	    *ret_len = 0; \
	}


#endif /* _CLI_H */
