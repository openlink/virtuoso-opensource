/*
 *  CLIsql1.c
 *
 *  $Id$
 *
 *  Client API
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

#include "CLI.h"
#include "virtpwd.h"
#include "sqlver.h"
#include "multibyte.h"
#ifdef _SSL
#include <openssl/rsa.h>
#include <openssl/crypto.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#include <openssl/ssl.h>
#include <openssl/err.h>
#endif

#if defined(VIRTTP)
#include "2pc.h"
#endif

#include "mts_client.h"

#define MD5_LOGIN

SQLRETURN SQL_API
virtodbc__SQLAllocConnect (
	SQLHENV henv,
	SQLHDBC * phdbc)
{
  ENV (env, henv);
  NEW_VARZ (cli_connection_t, cli);

  dk_set_push (&env->env_connections, (void *) cli);
  *phdbc = (SQLHDBC) cli;
  cli->con_environment = env;
  cli->con_access_mode = SQL_MODE_READ_WRITE;
  cli->con_db_casemode = 1;

  /* ODBC has autocommit as default */
  cli->con_autocommit = 1;
  cli->con_isolation = SQL_TXN_REPEATABLE_READ;
  cli->con_mtx = mutex_allocate ();

  cli->con_defs.cdef_query_timeout = SO_DEFAULT_TIMEOUT;
  cli->con_defs.cdef_txn_timeout = SO_DEFAULT_TIMEOUT;
  cli->con_defs.cdef_prefetch = SELECT_PREFETCH_QUOTA;

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLAllocConnect (
	SQLHENV henv,
	SQLHDBC * phdbc)
{
  return virtodbc__SQLAllocConnect (henv, phdbc);
}


SQLRETURN SQL_API
virtodbc__SQLAllocEnv (
	SQLHENV * phenv)
{
  static int firsttime = 1;
  cli_dbg_printf (("SQLAllocEnv called.\n"));

  if (firsttime)
    {
      srand ((unsigned int) time(NULL));
      firsttime = 0;
    }

  PrpcInitialize ();
  blobio_init ();
  {
    NEW_VARZ (cli_environment_t, env);

#if (ODBCVER >= 0x0300)
    env->env_connection_pooling = SQL_CP_OFF;
    env->env_cp_match = SQL_CP_STRICT_MATCH;
    env->env_output_nts = SQL_TRUE;
#endif
    env->env_odbc_version = 2;
    env->env_mtx = mutex_allocate ();
    *phenv = (SQLHENV) env;

#ifdef WIN32
    /* check is MS DTC is exists on machine */
    mts_client_init ();
#endif

    return SQL_SUCCESS;
  }
}


SQLRETURN SQL_API
SQLAllocEnv (
	SQLHENV * phenv)
{
  return virtodbc__SQLAllocEnv (phenv);
}


SQLRETURN SQL_API
virtodbc__SQLAllocStmt (
	SQLHDBC hdbc,
	SQLHSTMT * phstmt)
{
  CON (con, hdbc);
  stmt_options_t *opts = (stmt_options_t *) dk_alloc_box (sizeof (stmt_options_t), DV_ARRAY_OF_LONG_PACKED);
#if (ODBCVER >= 0x0300)
  NEW_VAR (stmt_descriptor_t, desc1);
  NEW_VAR (stmt_descriptor_t, desc2);
  NEW_VAR (stmt_descriptor_t, desc3);
  NEW_VAR (stmt_descriptor_t, desc4);
#endif
  NEW_VARZ (cli_stmt_t, stmt);

  set_error (&con->con_error, NULL, NULL, NULL);

  memset (opts, 0, sizeof (stmt_options_t));
  *phstmt = (SQLHSTMT) stmt;
  dk_set_push (&con->con_statements, (void *) stmt);

  stmt->stmt_opts = opts;
  stmt->stmt_is_deflt_rowset = 1;
  stmt->stmt_rowset_size = 1;
  opts->so_concurrency = SQL_CONCUR_READ_ONLY;	/* Means READ-WRITE with Kubl! */
  stmt->stmt_id = con_new_id (con);
  stmt->stmt_parm_rows = 1;
  opts->so_cursor_type = SQL_CURSOR_FORWARD_ONLY;
  opts->so_keyset_size = 0;

  opts->so_prefetch = con->con_defs.cdef_prefetch;
  opts->so_timeout = STMT_MSEC_OPTION (con->con_defs.cdef_txn_timeout);
  opts->so_rpc_timeout = STMT_MSEC_OPTION (con->con_defs.cdef_query_timeout);
  opts->so_prefetch_bytes = con->con_defs.cdef_prefetch_bytes;
  opts->so_prefetch_bytes = con->con_defs.cdef_prefetch_bytes;

  stmt->stmt_connection = con;
  stmt->stmt_retrieve_data = SQL_RD_ON;

#if (ODBCVER >= 0x0300)
  stmt->stmt_app_row_descriptor = desc1;
  stmt->stmt_app_row_descriptor->d_type = ROW_APP_DESCRIPTOR;
  stmt->stmt_app_row_descriptor->d_stmt = stmt;
  stmt->stmt_app_row_descriptor->d_bind_offset_ptr = NULL;
  stmt->stmt_app_row_descriptor->d_max_recs = 0;

  stmt->stmt_imp_row_descriptor = desc2;
  stmt->stmt_imp_row_descriptor->d_type = ROW_IMP_DESCRIPTOR;
  stmt->stmt_imp_row_descriptor->d_stmt = stmt;
  stmt->stmt_imp_row_descriptor->d_bind_offset_ptr = NULL;
  stmt->stmt_imp_row_descriptor->d_max_recs = 0;

  stmt->stmt_app_param_descriptor = desc3;
  stmt->stmt_app_param_descriptor->d_type = PARAM_APP_DESCRIPTOR;
  stmt->stmt_app_param_descriptor->d_stmt = stmt;
  stmt->stmt_app_param_descriptor->d_bind_offset_ptr = NULL;
  stmt->stmt_app_param_descriptor->d_max_recs = 0;

  stmt->stmt_imp_param_descriptor = desc4;
  stmt->stmt_imp_param_descriptor->d_type = PARAM_IMP_DESCRIPTOR;
  stmt->stmt_imp_param_descriptor->d_stmt = stmt;
  stmt->stmt_imp_param_descriptor->d_bind_offset_ptr = NULL;
  stmt->stmt_imp_param_descriptor->d_max_recs = 0;

  stmt->stmt_opts->so_is_async = con->con_async_mode;
  stmt->stmt_opts->so_timeout = STMT_MSEC_OPTION (con->con_defs.cdef_txn_timeout);
#endif

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLAllocStmt (
	SQLHDBC hdbc,
	SQLHSTMT * phstmt)
{
  return virtodbc__SQLAllocStmt (hdbc, phstmt);
}


SQLRETURN SQL_API
SQLBindCol (
	SQLHSTMT hstmt,
	SQLUSMALLINT icol,
	SQLSMALLINT fCType,
	SQLPOINTER rgbValue,
	SQLLEN cbValueMax,
	SQLLEN * pcbValue)
{
  STMT (stmt, hstmt);
  col_binding_t *col = stmt_nth_col (stmt, icol);

  if (cbValueMax == 0 && icol > 0 && fCType != SQL_C_DEFAULT)
  {
    /*
     * If fCType == SQL_C_DEFAULT, we need to know the SQL type of the data to
     * determine which ODBC C type to use. Depending on when SQLBindCol
     * is called, we may not be able to determine the SQL type now
     */
    cbValueMax = sqlc_sizeof (fCType, cbValueMax);
  }

  col->cb_c_type = fCType;
  col->cb_place = (caddr_t) rgbValue;
  col->cb_length = pcbValue;
  col->cb_max_length = cbValueMax;

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
virtodbc__SQLCancel (
    SQLHSTMT hstmt)
{
  STMT (stmt, hstmt);
  future_t *future;

  VERIFY_INPROCESS_CLIENT (stmt->stmt_connection);
  future = PrpcFuture (stmt->stmt_connection->con_session, &s_sql_free_stmt, stmt->stmt_id, (long) SQL_CLOSE);

  if (stmt->stmt_connection->con_db_gen > 1519)
    PrpcSync (future);
  else
    /* close is always async before G15d20 */
    PrpcFutureFree (future);

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLCancel (
    SQLHSTMT hstmt)
{
  return virtodbc__SQLCancel (hstmt);
}


SQLRETURN SQL_API
SQLColAttributes (
	SQLHSTMT hstmt,
	SQLUSMALLINT icol,
	SQLUSMALLINT fDescType,
	SQLPOINTER rgbDesc,
	SQLSMALLINT cbDescMax,
	SQLSMALLINT * pcbDesc,
	SQLLEN * pfDesc)
{
  STMT (stmt, hstmt);

  switch (fDescType)
    {
    case SQL_COLUMN_LABEL:
    case SQL_COLUMN_NAME:
    case SQL_COLUMN_TYPE_NAME:
    case SQL_COLUMN_TABLE_NAME:
    case SQL_COLUMN_OWNER_NAME:
    case SQL_COLUMN_QUALIFIER_NAME:
#if ODBCVER >= 0x0300
    case SQL_DESC_BASE_COLUMN_NAME:
    case SQL_DESC_BASE_TABLE_NAME:
    case SQL_DESC_LITERAL_PREFIX:
    case SQL_DESC_LITERAL_SUFFIX:
    case SQL_DESC_LOCAL_TYPE_NAME:
    case SQL_DESC_NAME:
#endif
      {
	NDEFINE_OUTPUT_NONCHAR_NARROW (rgbDesc, cbDescMax, pcbDesc, stmt->stmt_connection, SQLSMALLINT);
	SQLRETURN rc;

	NMAKE_OUTPUT_NONCHAR_NARROW (rgbDesc, cbDescMax, stmt->stmt_connection);

	rc = virtodbc__SQLColAttributes (hstmt, icol, fDescType, _rgbDesc, _cbDescMax, _pcbDesc, pfDesc);

	NSET_AND_FREE_OUTPUT_NONCHAR_NARROW (rgbDesc, cbDescMax, pcbDesc, stmt->stmt_connection);
	return rc;
      }

    default:
      return virtodbc__SQLColAttributes (hstmt, icol, fDescType, rgbDesc, cbDescMax, pcbDesc, pfDesc);
    }
}


col_desc_t bm_info =
{
  NULL,				/* name */
  DV_LONG_INT,			/* type */
  (caddr_t) (ptrlong) 0,	/* scale */
  (caddr_t) (ptrlong) 10,	/* precision */
  (caddr_t) (ptrlong) 1,	/* nullable */
  (caddr_t) (ptrlong) 0,	/* updatable */
  (caddr_t) (ptrlong) 0		/* searchable */
};


SQLRETURN SQL_API
virtodbc__SQLColAttributes (
	SQLHSTMT hstmt,
	SQLUSMALLINT icol,
	SQLUSMALLINT fDescType,
	SQLPOINTER rgbDesc,
	SQLSMALLINT cbDescMax,
	SQLSMALLINT * pcbDesc,
	SQLLEN * pfDesc)
{
  col_desc_t *cd;
  int n_cols, was_bm_col = (icol == 0);
  SQLRETURN rc = SQL_SUCCESS;
  STMT (stmt, hstmt);
  stmt_compilation_t *sc = stmt->stmt_compilation;
  int use_binary_timestamp;

  icol--;
  if (!sc)
    {
      set_error (&stmt->stmt_error, "S1010", "CL028", "Statement not prepared.");
      return SQL_ERROR;
    }

  if (!sc->sc_is_select)
    {
      set_error (&stmt->stmt_error, "07005", "CL029", "Statement does not have output cols.");
      return SQL_ERROR;
    }

  if (was_bm_col && !stmt->stmt_opts->so_use_bookmarks)
    {
      set_error (&stmt->stmt_error, "07009", "CL030", "Bookmarks not enabled for statement");
      return SQL_ERROR;
    }

  n_cols = BOX_ELEMENTS (stmt->stmt_compilation->sc_columns);

  if (!was_bm_col && icol >= n_cols)
    {
      set_error (&stmt->stmt_error, "S1002", "CL031", "Column index too large.");
      return SQL_ERROR;
    }

  if (was_bm_col)
    cd = &bm_info;
  else
    cd = (col_desc_t *) stmt->stmt_compilation->sc_columns[icol];

  use_binary_timestamp = stmt->stmt_connection->con_defs.cdef_binary_timestamp;

  switch (fDescType)
    {
    case SQL_COLUMN_COUNT:
      if (pfDesc)
	*pfDesc = n_cols;
      break;

#if ODBCVER >= 0x0300
    case SQL_DESC_BASE_COLUMN_NAME:
      rc = str_box_to_buffer (
	  COL_DESC_IS_EXTENDED (cd) && cd->cd_base_column_name ? cd->cd_base_column_name : cd->cd_name,
	  (char *) rgbDesc, cbDescMax, pcbDesc, 0, &stmt->stmt_error);
      break;
#endif

#if ODBCVER >= 0x0300
    case SQL_DESC_NAME:
#endif
    case SQL_COLUMN_LABEL:	/* Transferred here by AK 20-FEB-1997. */
    case SQL_COLUMN_NAME:
      rc = str_box_to_buffer (cd->cd_name, (char *) rgbDesc, cbDescMax, pcbDesc, 0, &stmt->stmt_error);
      break;

#if ODBCVER >= 0x0300
    case SQL_DESC_TYPE:
#endif
    case SQL_COLUMN_TYPE:
      if (pfDesc)
	*pfDesc = dv_to_sql_type ((dtp_t) cd->cd_dtp, use_binary_timestamp);
      break;

    case SQL_COLUMN_TYPE_NAME:
      if (rgbDesc)
	sql_type_to_sql_type_name (dv_to_sql_type ((dtp_t) cd->cd_dtp,
		use_binary_timestamp), ((char *) rgbDesc), cbDescMax);
      if (pcbDesc)
	*pcbDesc = (SQLSMALLINT) strlen ((char *) rgbDesc);
      break;

#if ODBCVER >= 0x0300
    case SQL_DESC_LENGTH:
    case SQL_DESC_OCTET_LENGTH:
#endif
    case SQL_COLUMN_LENGTH:
      if (pfDesc)
        *pfDesc = unbox (cd->cd_precision);
      break;

#if ODBCVER >= 0x0300
    case SQL_DESC_PRECISION:
#endif
    case SQL_COLUMN_PRECISION:
      if (pfDesc)
        *pfDesc = unbox (cd->cd_precision);
      break;

#if ODBCVER >= 0x0300
    case SQL_DESC_SCALE:
#endif
    case SQL_COLUMN_SCALE:
      if (pfDesc)
	*pfDesc = unbox (cd->cd_scale);
      break;

    case SQL_COLUMN_DISPLAY_SIZE:
      if (pfDesc)
	*pfDesc = col_desc_get_display_size (cd, use_binary_timestamp);
      break;

#if ODBCVER >= 0x0300
    case SQL_DESC_NULLABLE:
#endif
    case SQL_COLUMN_NULLABLE:
      if (pfDesc)
	*pfDesc = unbox (cd->cd_nullable);
      break;

    case SQL_COLUMN_UNSIGNED:
      if (pfDesc)
	*pfDesc = 0;	/* Virtuoso does not support unsigned types */
      break;

    case SQL_COLUMN_MONEY:
      if (pfDesc)
	*pfDesc = 0;	/* Virtuoso does not support money types */
      break;

    case SQL_COLUMN_UPDATABLE:
      if (pfDesc)
	*pfDesc = unbox (cd->cd_updatable);
      break;

    case SQL_COLUMN_AUTO_INCREMENT:
      if (pfDesc)
	*pfDesc = COL_DESC_IS_EXTENDED (cd) ? ((unbox (cd->cd_flags) & CDF_AUTOINCREMENT) != 0) : 0;
      break;

    case SQL_COLUMN_CASE_SENSITIVE:
      if (pfDesc)
	*pfDesc = (IS_STRING_DTP (cd->cd_dtp) || IS_BLOB_DTP (cd->cd_dtp)) ? 1 : 0;
      break;

    case SQL_COLUMN_SEARCHABLE:
      if (pfDesc)
/* IvAn/DvBlobXper/001212 Case for XPER added, bug with DV_BLOB_WIDE fixed  */
	*pfDesc = IS_BLOB_DTP (cd->cd_dtp) ? 0 : (cd->cd_searchable ? SQL_SEARCHABLE : SQL_UNSEARCHABLE);
      break;

#if ODBCVER >= 0x0300
    case SQL_DESC_BASE_TABLE_NAME:
#endif
    case SQL_COLUMN_TABLE_NAME:
      rc = str_box_to_buffer (COL_DESC_IS_EXTENDED (cd) ? cd->cd_base_table_name : NULL,
	  (char *) rgbDesc, cbDescMax, pcbDesc, 0, &stmt->stmt_error);
      break;

    case SQL_COLUMN_OWNER_NAME:
      rc = str_box_to_buffer (COL_DESC_IS_EXTENDED (cd) ? cd->cd_base_schema_name : NULL,
	  (char *) rgbDesc, cbDescMax, pcbDesc, 0, &stmt->stmt_error);
      break;

    case SQL_COLUMN_QUALIFIER_NAME:
      rc = str_box_to_buffer (COL_DESC_IS_EXTENDED (cd) ? cd->cd_base_catalog_name : NULL,
	  (char *) rgbDesc, cbDescMax, pcbDesc, 0, &stmt->stmt_error);
      break;

#if ODBCVER >= 0x0300
    case SQL_DESC_LITERAL_SUFFIX:
    case SQL_DESC_LITERAL_PREFIX:
      {
	SQLINTEGER data;

	SQLRETURN rc = virtodbc__SQLGetDescField (
/* IvAn/IRIXport/011010 Explicit cast to SQLHDESC was added */
	    (SQLHDESC) (stmt->stmt_imp_row_descriptor),
	    icol + 1,
	    fDescType, rgbDesc, cbDescMax, &data);

	if (pcbDesc)
	  *pcbDesc = (SQLSMALLINT) data;

	return rc;
      }

    case SQL_DESC_UNNAMED:
      if (pfDesc)
	*pfDesc = cd->cd_name ? SQL_NAMED : SQL_UNNAMED;
      break;
#endif

    case SQL_COLUMN_HIDDEN:
      {
	int n_hidden_cols = (int) SC_HIDDEN_COLUMNS (stmt->stmt_compilation);
	if (was_bm_col || icol < n_cols - n_hidden_cols)
	  *pfDesc = 0;
	else
	  *pfDesc = 1;
      }
      break;

    case SQL_COLUMN_KEY:
      if (pfDesc)
	*pfDesc = COL_DESC_IS_EXTENDED (cd) ? (unbox (cd->cd_flags) & CDF_KEY) : 0;
      break;

#if ODBCVER >= 0x0350
    case SQL_DESC_ROWVER:
      if (pfDesc)
	*pfDesc = (DV_TIMESTAMP == cd->cd_dtp);
      break;
#endif

    default:
      set_error (&stmt->stmt_error, "S1C00", "CL032", "Information not available.");
    }

  return rc;
}


void
con_set_defaults (cli_connection_t * con, caddr_t * login_res)
{
  if (BOX_ELEMENTS (login_res) > LG_DEFAULTS)
    {
      caddr_t *cdefs = (caddr_t *) login_res[LG_DEFAULTS];
      con->con_isolation				= cdef_param (cdefs, "SQL_TXN_ISOLATION", SQL_TXN_REPEATABLE_READ);
      con->con_defs.cdef_prefetch		= cdef_param (cdefs, "SQL_PREFETCH_ROWS", SELECT_PREFETCH_QUOTA);
      con->con_defs.cdef_prefetch_bytes		= cdef_param (cdefs, "SQL_PREFETCH_BYTES", 0);
      con->con_defs.cdef_txn_timeout		= cdef_param (cdefs, "SQL_TXN_TIMEOUT", 0);
      con->con_defs.cdef_query_timeout		= cdef_param (cdefs, "SQL_QUERY_TIMEOUT", 0);
      con->con_defs.cdef_no_char_c_escape	= cdef_param (cdefs, "SQL_NO_CHAR_C_ESCAPE", 0);
      con->con_defs.cdef_utf8_execs		= cdef_param (cdefs, "SQL_UTF8_EXECS", 0);
      con->con_defs.cdef_binary_timestamp	= cdef_param (cdefs, "SQL_BINARY_TIMESTAMP", 1);
      con->con_defs.cdef_timezoneless_datetimes	= cdef_param (cdefs, "SQL_TIMEZONELESS_DATETIMES", 0);

      timezoneless_datetimes = con->con_defs.cdef_timezoneless_datetimes;

      dk_free_tree ((box_t) cdefs);
    }
}


char application_name[60];
static caddr_t
getApplicationName (void)
{
#ifdef WIN32
  char *name1;
  char *cp, *cend = NULL;
  size_t len;
  caddr_t name = NULL, name_start = NULL;

  if (application_name[0] == 0)
    {
      if ((name1 = GetCommandLine ()) == NULL)
	strcpy_ck (application_name, "UNKNOWN");
      else
	{
	  name = box_string (name1);
	  cp = NULL;
	  name_start = name;

	  /*lets skip the leading space */
	  while (name && *name && isspace (*name))
	    name++;

	  if (name && name[0] == '\"')
	    {
	      cp = strchr (name + 1, '\"');
	    }
	  else if (name && name[0] != 0)
	    {
	      cp = strchr (name + 1, ' ');
	    }

	  if (cp)
	    *cp = 0;

	  if ((cp = strrchr (name, '\\')) != NULL)
	    name = cp + 1;

	  if (name1[0] != '\"')
	    {
	      if ((cend = strchr (name, ' ')) != NULL)
		*cend = 0;
	    }
	  else
	    {
	      if (name[0] == '\"')
		name++;
	      if ((cend = strchr (name, '\"')) != NULL)
		*cend = 0;
	    }


	  if ((cp = strrchr (name, '.')) == NULL)
	    cp = name + strlen (name);

	  if ((len = (size_t) (cp - name)) > sizeof (application_name) - 1)
	    len = sizeof (application_name) - 1;

	  memcpy (application_name, name, len);
	  strupr (application_name);
	  application_name[len] = 0;

	  if (!strcmp (application_name, "KRNL386"))
	    strcpy_ck (application_name, "WOW");

	  dk_free_box (name_start);
	}
    }
  return box_string (application_name);

#elif defined (UNIX)
  return box_string (application_name);
#else
# error You should fix getApplicationName
#endif
}


static caddr_t *
fill_login_info_array (cli_connection_t *cli)
{
  caddr_t *ret = (caddr_t *) dk_alloc_box (6 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  int i;

  memset (ret, 0, 6 * sizeof (caddr_t));
  ret[0] = getApplicationName ();
  ret[1] = box_num (getpid ());

#if defined (WIN32)
  {
    char computerName[MAX_COMPUTERNAME_LENGTH + 1];
    DWORD size = sizeof (computerName);

    if (!GetComputerName (computerName, &size))
      computerName[0] = 0;
    ret[2] = box_string (computerName);
    ret[3] = box_string ("win32");
  }
#elif defined (UNIX)
  {
    ret[2] = box_string ("");
    ret[3] = box_string ("unix");
  }
#else
# error "You should fix the application info collection CLIsql1.c"
#endif
  ret[4] = box_string (cli->con_charset_name ? cli->con_charset_name : "");

  for (i = 0; ((uint32) i) < box_length (ret[4]) && ret[4][i]; i++)
    ret[4][i] = toupper (ret[4][i]);

  ret[5] = box_num (cli->con_shutdown);

  return ret;
}


caddr_t
cli_box_server_msg (char *msg)
{
  size_t msg_len = msg ? strlen (msg) : 0;
  caddr_t msg_box = msg ? dk_alloc_box (VIRT_SERVER_LEN + msg_len + 1, DV_SHORT_STRING) : NULL;

  if (msg_box)
    {
      memcpy (msg_box, VIRT_SERVER, VIRT_SERVER_LEN);
      memcpy (msg_box + VIRT_SERVER_LEN, msg, msg_len);
      msg_box[VIRT_SERVER_LEN + msg_len] = 0;
    }

  return msg_box;
}


#if defined (_SSL) && !defined (WIN32)
#define VIRT_PASS_LEN 1024
static char *
ssl_get_password (char * name, char *tpass)
{
  char *tmp = NULL;
  char prompt[VIRT_PASS_LEN];

  snprintf (prompt, sizeof (prompt), "Enter a password to open \"%s\": ", name);

  if (0 == EVP_read_pw_string (tpass, VIRT_PASS_LEN, prompt, 0 /* no verify */ ))
    {
      tmp = strchr (tpass, '\n');
      if (tmp)
	*tmp = 0;
      tmp = tpass;
    }

  return tmp;
}
#endif

#ifdef INPROCESS_CLIENT

static void *
get_inprocess_client ()
{
#ifndef USE_DYNAMIC_LOADER
  return (void *) 1;
#else
  du_thread_t *du_thread = THREAD_CURRENT_THREAD;
  dk_thread_t *dk_thread = du_thread ? PROCESS_TO_DK_THREAD (du_thread) : NULL;
  dk_session_t *session = (dk_thread && dk_thread->dkt_requests[0] ? dk_thread->dkt_requests[0]->rq_client : NULL);

  return session ? DKS_DB_DATA (session) : NULL;
#endif
}


SQLRETURN
verify_inprocess_client (cli_connection_t * con)
{
  if (con->con_session && SESSION_IS_INPROCESS (con->con_session))
    {
      void *client = get_inprocess_client ();

      if (client != con->con_inprocess_client)
	{
	  set_error (&con->con_error, "HY000", "CL091", "Calling from a different in-process client.");

	  return SQL_ERROR;
	}
    }

  return SQL_SUCCESS;
}

#endif

#define MAXPAIRS 64

/* This was SQLConnect */
SQLRETURN
internal_sql_connect (
	SQLHDBC hdbc,
	SQLCHAR * szDSN,
	SQLSMALLINT cbDSN,
	SQLCHAR * szUID,
	SQLSMALLINT cbUID,
	SQLCHAR * szAuthStr,
	SQLSMALLINT cbAuthStr)
{
  caddr_t pwd_box;
  caddr_t *login_res;
  CON (con, hdbc);
  char err[200];
  char *dsn = box_n_string (szDSN, szDSN ? cbDSN : 0);
  char *user = box_n_string (szUID, szUID ? cbUID : 0);
  char *passwd = box_n_string (szAuthStr, szAuthStr ? cbAuthStr : 0);
  dk_session_t *ses;
  char addr[100 + 1];
  caddr_t *info = fill_login_info_array (con), x509_error = NULL;
  SQLRETURN rc = SQL_SUCCESS;
#if defined (_SSL) && !defined (WIN32)
  char tpass[VIRT_PASS_LEN];
#endif
  char *szPasswd;
#ifdef INPROCESS_CLIENT
  int inprocess_client = dsn && (strncmp (dsn, ":in-process:", 12) == 0);
#endif
  char addr_lst[1024 + 1];
  char *index[MAXPAIRS];
  int index_count = 0;
  int useRoundRobin = con->con_round_robin;
  char *cp, *tok;
  int hostIndex = 0;
  int startIndex = 0;

  if (con->con_charset)
    {
      wide_charset_free (con->con_charset);
      con->con_charset = NULL;
    }
  strncpy (addr_lst, dsn, (sizeof (addr_lst) - 1));

  for (tok = cp = addr_lst; *cp != 0 && index_count < MAXPAIRS; cp++)
    if (*cp == ',')
      {
        *cp = 0;
        index[index_count++] = tok;
        tok = cp + 1;
      }
  if (tok < cp && *cp == 0 && index_count < MAXPAIRS)
    index[index_count++] = tok;

  szPasswd = (char *) szAuthStr;

#ifdef _SSL
  /* We need to ensure that SSL error stack is clear before peeking a error */
  ERR_clear_error ();
#if 0 /*!defined (WIN32)*/
  {
    char *ssl_usage = con->con_encrypt;
    if (ssl_usage && strlen (ssl_usage) > 0 && atoi (ssl_usage) == 0)
      szPasswd = ssl_get_password (con->con_encrypt, tpass);
  }
#endif
#endif


#ifdef INPROCESS_CLIENT
  if (inprocess_client)
    {
      void *client = get_inprocess_client ();

      if (client == NULL)
	{
	  set_error (&con->con_error, "08001", "CL092", "In-process connect failed.");

	  return SQL_ERROR;
	}

      con->con_inprocess_client = client;

      strcpy_ck (addr, "localhost:");
      if (dsn[12] == 0)
	strcat_ck (addr, "1111");
      else
	strcat_ck (addr, dsn + 12);

      ses = PrpcInprocessConnect (addr);
      if (ses == NULL)
	{
	  set_error (&con->con_error, "08001", "CL093", "In-process connect failed.");
	  return SQL_ERROR;
	}
    }
  else
#endif
    {
      srand ((unsigned) time (NULL));

      if (index_count > 1 && useRoundRobin)
        startIndex = hostIndex = (rand () % index_count);

      while(1)
        {
          if (index_count == 0)
            strncpy (addr, index[0], (sizeof (addr) - 1));
          else
            strncpy (addr, index[hostIndex], (sizeof (addr) - 1));

#if defined(WIN32)
          if (alldigits (addr))
            {
              strcpy_ck (addr, "localhost:");
              strcat_ck (addr, dsn);
            }
          else
#endif
          if (!alldigits (addr) && !strchr (dsn, ' ') && !strchr (dsn, ':'))
            {
              strncpy (addr, dsn, sizeof (addr) - 6);
#ifdef _SSL
              strcat_ck (addr, con->con_encrypt ? ":2111" : ":1111");
#else
              strcat_ck (addr, ":1111");
#endif
            }

          ses = PrpcConnect1 (addr, SESCLASS_TCPIP, con->con_encrypt, szPasswd, con->con_ca_list);

          if (!DKSESSTAT_ISSET (ses, SST_OK))
            {
              hostIndex++;
              if (useRoundRobin)
                {
                  if (index_count == hostIndex)
                    hostIndex = 0;
                  if (hostIndex == startIndex)
                    break; /* FAIL */
                }
              else if (index_count == hostIndex)
                {
                  break; /*FAIL*/
                }
              else
                {
                  PrpcDisconnect (ses);
                  PrpcSessionFree (ses);
                  /*TRY NEXT HOST FROM LIST*/
                }
            }
          else
            break; /*OK CONNECTED*/
        }
    }


  if (!DKSESSTAT_ISSET (ses, SST_OK))
    {
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);

#ifdef _SSL
      if (ERR_peek_error ())
	cli_ssl_get_error_string (err, sizeof (err));
      else
#endif
	snprintf (err, sizeof (err), "Connect failed to %s = %s.", dsn, addr);

      set_error (&con->con_error, "S2801", "CL033", err);

      return SQL_ERROR;
    }

#ifdef _SSL
# ifdef INPROCESS_CLIENT
  if (!inprocess_client)
# endif
    {
      if (NULL != (x509_error = ssl_get_x509_error (tcpses_get_ssl (ses->dks_session))))
	{
	  if (con->con_encrypt && atoi (con->con_encrypt) == 0)
	    {
	      PrpcDisconnect (ses);
	      PrpcSessionFree (ses);
	      set_error (&con->con_error, "S2801", "CL083", x509_error);
	      dk_free_box (x509_error);

	      return SQL_ERROR;
	    }
	  else
	    {
	      rc = SQL_SUCCESS_WITH_INFO;
	      set_success_info (&con->con_error, "01S02", "CL083", x509_error, 0);
	      dk_free_box (x509_error);
	    }
	}
    }
#endif

#ifdef MD5_LOGIN
  con->con_pwd_cleartext = cdef_param (ses->dks_caller_id_opts, "SQL_ENCRYPTION_ON_PASSWORD", con->con_pwd_cleartext);

  if (con->con_pwd_cleartext == 1)
    {
      if (!con->con_encrypt || strlen (con->con_encrypt) == 0)
	{
	  set_success_info (&con->con_error, "28000", "CL085", "Password to be sent in cleartext with no encryption", 0);
	  rc = SQL_SUCCESS_WITH_INFO;
	}
      pwd_box = box_dv_short_string (passwd);
    }
  else if (con->con_pwd_cleartext == 2)
    {
      pwd_box = dk_alloc_box (box_length (passwd) + 1, DV_SHORT_STRING);
      pwd_box[0] = 0;
      memcpy (pwd_box + 1, passwd, box_length (passwd));
      xx_encrypt_passwd (pwd_box + 1, box_length (passwd) - 1, user);
    }
  else
    {
      pwd_box = dk_alloc_box (17, DV_SHORT_STRING);
      sec_login_digest (ses->dks_own_name, user, passwd, (unsigned char *) pwd_box);
      pwd_box[16] = 0;
    }
#else
  pwd_box = box_dv_short_string (passwd);
#endif

  login_res = (caddr_t *) PrpcSync (PrpcFuture (ses, &s_sql_login, user, pwd_box, ODBC_DRV_VER, info));
  dk_free_box (pwd_box);
  dk_free_tree ((box_t) info);

  if (!login_res)
    {
      set_error (&con->con_error, "28000", "CL034", "Bad login");
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      return SQL_ERROR;
    }

  con->con_session = ses;
  con->con_user = (SQLCHAR *) user;

  if (IS_BOX_POINTER (login_res))
    {
      int flag = (int) unbox (login_res[0]);

      if (QA_ERROR == flag)
	{
	  caddr_t srv_msg = cli_box_server_msg (login_res[2]);
	  set_error (&con->con_error, login_res[1], NULL, srv_msg);
	  dk_free_tree ((caddr_t) login_res);
	  dk_free_box (srv_msg);
	  PrpcDisconnect (ses);
	  PrpcSessionFree (ses);
	  con->con_session = NULL;

	  return SQL_ERROR;
	}

      con->con_qualifier = (SQLCHAR *) login_res[LG_QUALIFIER];
      con->con_db_ver = (SQLCHAR *) login_res[LG_DB_VER];
      con->con_db_gen = ODBC_DRV_VER_G_NO ((char *) con->con_db_ver);

      if (con->con_db_gen < 2303)
	{
	  dk_free_tree ((caddr_t) login_res);
	  set_error (&con->con_error, "S2801", "CL034", "Old server version");
	  PrpcDisconnect (ses);
	  PrpcSessionFree (ses);
	  con->con_session = NULL;

	  return SQL_ERROR;
	}

      if (BOX_ELEMENTS (login_res) > LG_DB_CASEMODE)
	con->con_db_casemode = (int) unbox (login_res[LG_DB_CASEMODE]);

      con_set_defaults (con, login_res);

      if (BOX_ELEMENTS (login_res) > LG_CHARSET)
	{
	  caddr_t *cs_info = (caddr_t *) login_res[LG_CHARSET];
	  if (cs_info && DV_TYPE_OF (cs_info) == DV_ARRAY_OF_POINTER && BOX_ELEMENTS (cs_info) > 1)
	    con->con_charset =
		wide_charset_create (cs_info[0], (wchar_t *) cs_info[1], box_length (cs_info[1]) / sizeof (wchar_t) - 1, NULL);
	}

      if (con->con_charset_name && (!con->con_charset || strcmp (con->con_charset->chrs_name, con->con_charset_name)))
	{
	  if (strcmp ("ISO-8859-1", con->con_charset_name))
	    {
	      snprintf (err, sizeof (err),
		  "Charset %s not available. Server default %s will be used.",
		  con->con_charset_name, con->con_charset ? con->con_charset->chrs_name : "ISO-8859-1");
	      set_success_info (&con->con_error, "2C000", "CL035", err, 0);
	      rc = SQL_SUCCESS_WITH_INFO;
	    }
	}
      else if (!con->con_charset_name && con->con_charset && strcmp ("ISO-8859-1", con->con_charset->chrs_name))
	{
	  snprintf (err, sizeof (err), "Switching to the server default charset %s.", con->con_charset->chrs_name);
	  set_success_info (&con->con_error, "01S02", "CL036", err, 0);
	  rc = SQL_SUCCESS_WITH_INFO;
	}

      if (con->con_charset_name)
	dk_free_box (con->con_charset_name);

      con->con_charset_name = NULL;
      dk_free_box ((box_t) login_res);
    }
  else
    {
      set_error (&con->con_error, "S2801", "CL034", "Old server version");
      PrpcDisconnect (ses);
      PrpcSessionFree (ses);
      con->con_session = NULL;

      return SQL_ERROR;
    }

  cdef_add_param (&ses->dks_caller_id_opts, "__SQL_CLIENT_VERSION", con->con_db_gen);

  con->con_dsn = (SQLCHAR *) dsn;
  dk_free_box (passwd);

  return rc;
}


SQLRETURN SQL_API
virtodbc__SQLDescribeCol (
	SQLHSTMT hstmt,
	SQLUSMALLINT icol,
	SQLCHAR * szColName,
	SQLSMALLINT cbColNameMax,
	SQLSMALLINT * pcbColName,
	SQLSMALLINT * pfSqlType,
	SQLULEN * pcbColDef,
	SQLSMALLINT * pibScale,
	SQLSMALLINT * pfNullable)
{
  col_desc_t *cd;
  int n_cols, was_bm_col = (icol == 0);
  STMT (stmt, hstmt);
  stmt_compilation_t *sc = stmt->stmt_compilation;

  icol--;

  if (!sc)
    {
      set_error (&stmt->stmt_error, "S1010", "CL037", "Statement not prepared.");
      return SQL_ERROR;
    }

  if (!sc->sc_is_select)
    {
      set_error (&stmt->stmt_error, "07005", "CL038", "Statement does not have output cols.");
      return SQL_ERROR;
    }

  if (was_bm_col && !stmt->stmt_opts->so_use_bookmarks)
    {
      set_error (&stmt->stmt_error, "07009", "CL039", "Bookmarks not enabled for statement");
      return SQL_ERROR;
    }

  n_cols = BOX_ELEMENTS (stmt->stmt_compilation->sc_columns);

  if (!was_bm_col && icol >= n_cols)
    {
      set_error (&stmt->stmt_error, "S1002", "CL040", "Column index too large.");
      return SQL_ERROR;
    }

  if (was_bm_col)
    cd = &bm_info;
  else
    cd = (col_desc_t *) stmt->stmt_compilation->sc_columns[icol];

  if (szColName)		/* Check that it is not given as NULL. */
    {
      if (cd->cd_name)
	strncpy ((char *) szColName, cd->cd_name, cbColNameMax);
      else
	strncpy ((char *) szColName, "-", cbColNameMax);

      if (cbColNameMax > 0)
	szColName[cbColNameMax - 1] = 0;
      if (pcbColName)
	*pcbColName = (SQLSMALLINT) strlen ((char *) szColName);
    }

  if (pibScale)
    *pibScale = (SQLSMALLINT) unbox (cd->cd_scale);

  if (pcbColDef)
    *pcbColDef = (UDWORD) unbox (cd->cd_precision);

  if (pfNullable)
    *pfNullable = (SQLSMALLINT) unbox (cd->cd_nullable);

  if (pfSqlType)
    {
      ENV (env, stmt->stmt_connection->con_environment);
      *pfSqlType = dv_to_sql_type ((dtp_t) cd->cd_dtp, stmt->stmt_connection->con_defs.cdef_binary_timestamp);

      if (env && env->env_odbc_version == 3)
	{
	  switch (*pfSqlType)
	    {
	    case SQL_DATE:
	      *pfSqlType = SQL_TYPE_DATE;
	      break;

	    case SQL_TIME:
	      *pfSqlType = SQL_TYPE_TIME;
	      break;

	    case SQL_TIMESTAMP:
	      *pfSqlType = SQL_TYPE_TIMESTAMP;
	      break;
	    }
	}
    }

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLDescribeCol (
	SQLHSTMT hstmt,
	SQLUSMALLINT icol,
	SQLCHAR * wszColName,
	SQLSMALLINT cbColName,
	SQLSMALLINT * pcbColName,
	SQLSMALLINT * pfSqlType,
	SQLULEN * pcbColDef,
	SQLSMALLINT * pibScale,
	SQLSMALLINT * pfNullable)
{
  SQLRETURN rc;
  STMT (stmt, hstmt);
  NDEFINE_OUTPUT_CHAR_NARROW (ColName, stmt->stmt_connection, SQLSMALLINT);

  NMAKE_OUTPUT_CHAR_NARROW (ColName, stmt->stmt_connection);

  rc = virtodbc__SQLDescribeCol (hstmt, icol, szColName, _cbColName, _pcbColName, pfSqlType, pcbColDef, pibScale, pfNullable);

  NSET_AND_FREE_OUTPUT_CHAR_NARROW (ColName, stmt->stmt_connection);

  return rc;
}


SQLRETURN SQL_API
SQLDisconnect (SQLHDBC hdbc)
{
  CON (con, hdbc);
  if (con->con_session)
    PrpcDisconnect (con->con_session);

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLError (
	SQLHENV henv,
	SQLHDBC hdbc,
	SQLHSTMT hstmt,
	SQLCHAR * wszSqlState,
	SQLINTEGER * pfNativeError,
	SQLCHAR * wszErrorMsg,
	SQLSMALLINT cbErrorMsg,
	SQLSMALLINT * pcbErrorMsg)
{
  STMT (stmt, hstmt);
  CON (con, hdbc);
  /*ENV (env, henv); */
  SQLCHAR szSqlState[6];
  SQLRETURN rc;

  if (con || stmt)
    {
      cli_connection_t *conn = con ? con : stmt->stmt_connection;
      NDEFINE_OUTPUT_CHAR_NARROW (ErrorMsg, conn, SQLSMALLINT);

      NMAKE_OUTPUT_CHAR_NARROW (ErrorMsg, conn);

      rc = virtodbc__SQLError (henv, hdbc, hstmt,
	  wszSqlState ? szSqlState : NULL, pfNativeError, szErrorMsg, _cbErrorMsg, _pcbErrorMsg, 1);

      NSET_AND_FREE_OUTPUT_CHAR_NARROW (ErrorMsg, conn);
    }
  else
    {
      return virtodbc__SQLError (henv, hdbc, hstmt, wszSqlState, pfNativeError, wszErrorMsg, cbErrorMsg, pcbErrorMsg, 1);
    }

  if (wszSqlState)
    memcpy (wszSqlState, szSqlState, 6);

  return rc;
}


SQLRETURN SQL_API
virtodbc__SQLError (
	SQLHENV henv,
	SQLHDBC hdbc,
	SQLHSTMT hstmt,
	SQLCHAR * szSqlState,
	SQLINTEGER * pfNativeError,
	SQLCHAR * szErrorMsg,
	SQLSMALLINT cbErrorMsgMax,
	SQLSMALLINT * pcbErrorMsg,
	int bClearState)
{
  STMT (stmt, hstmt);
  CON (con, hdbc);
  ENV (env, henv);
  sql_error_t *err = stmt ? &stmt->stmt_error : (con ? &con->con_error : (env ? &env->env_error : NULL));
  sql_error_rec_t *rec = err->err_queue;
  SQLRETURN rc = SQL_SUCCESS;
  SQLSMALLINT *pcbSqlState = NULL;

  if (!rec)
    {
      V_SET_ODBC_STR ("00000", szSqlState, 6, pcbSqlState, NULL);
      V_SET_ODBC_STR (NULL, szErrorMsg, cbErrorMsgMax, pcbErrorMsg, NULL);
      return SQL_NO_DATA_FOUND;
    }

  if (bClearState)
    err->err_queue = rec->sql_error_next;

  V_SET_ODBC_STR (rec->sql_state, szSqlState, 6, pcbSqlState, NULL);

  if (pfNativeError)
    *pfNativeError = -1;
  V_SET_ODBC_STR (rec->sql_error_msg, szErrorMsg, cbErrorMsgMax, pcbErrorMsg, NULL);
  if (bClearState)
    {
      dk_free_box (rec->sql_state);
      dk_free_box (rec->sql_error_msg);
      dk_free ((caddr_t) rec, sizeof (sql_error_rec_t));
    }
  return rc;
}


void
stmt_free_current_rows (cli_stmt_t * stmt)
{
  /* In the extended fetch mode stmt_rowset is not null and stmt_current_row
     is one among it. In odbc3 mode even plain SQLFetch() uses the extended
     fetch mode. In this case the call stack is like this: SQLFetch ->
     -> virtodbc__SQLExtendedFetch -> sql_ext_fetch_fwd -> virtodbc_SQLFetch. */
  if (stmt->stmt_rowset)
    {
      dk_free_tree ((box_t) stmt->stmt_rowset);
      stmt->stmt_rowset = NULL;
    }
  else
    {
      dk_free_tree ((box_t) stmt->stmt_current_row);
    }

  stmt->stmt_current_row = NULL;
}


SQLRETURN SQL_API
virtodbc__SQLExecDirect (
	SQLHSTMT hstmt,
	SQLCHAR * szSqlStr,
	SDWORD cbSqlStr)
{
  int rc;
  ptrlong old_concur;
  char *cr_name = NULL;
/* Use comma operator to force that cbSqlStr is changed (if it is!)
   before it is used as an argument for box_n_string. */
  caddr_t string;
  STMT (stmt, hstmt);
  caddr_t current_ofs = NULL;
  caddr_t *params = stmt->stmt_param_array;

  cli_dbg_printf (("virtodbc__SQLExecDirect (hstmt=%p)\n", (void *) hstmt));

  set_error (&stmt->stmt_error, NULL, NULL, NULL);

  VERIFY_INPROCESS_CLIENT (stmt->stmt_connection);

  if (stmt->stmt_parm_rows != 1 && SQL_CURSOR_FORWARD_ONLY != stmt->stmt_opts->so_cursor_type)
    {
      set_error (&stmt->stmt_error, "IM001", "CL083", "Unable to handle array parameters on a scrollable cursor");

      return SQL_ERROR;
    }

  if (!params)
    {
      if (szSqlStr)
	{
	  dk_free_tree ((box_t) stmt->stmt_compilation);
	  stmt->stmt_compilation = NULL;
	}

      params = stmt_collect_parms (stmt);

#ifndef MAP_DIRECT_BIN_CHAR
      if (stmt->stmt_error.err_queue && stmt->stmt_error.err_rc == SQL_ERROR)
	{
	  dk_free_tree ((box_t) params);
	  return SQL_ERROR;
	}
#endif

      string = szSqlStr ? box_n_string (szSqlStr, cbSqlStr) : NULL;

      if (stmt->stmt_dae)
	{
	  stmt->stmt_param_array = params;
	  stmt->stmt_status = STS_LOCAL_DAE;
	  stmt->stmt_pending.pex_text = string;
	  stmt->stmt_pending.p_api = SQL_API_SQLEXECDIRECT;
	  return SQL_NEED_DATA;
	}
    }
  else
    {
      string = stmt->stmt_pending.pex_text;

      if (string)
	{
	  dk_free_tree ((box_t) stmt->stmt_compilation);
	  stmt->stmt_compilation = NULL;
	}
    }

  stmt->stmt_param_array = NULL;

  if (stmt->stmt_param_status)
    {
      int n;
      for (n = 0; n < stmt->stmt_parm_rows; n++)
	stmt->stmt_param_status[n] = SQL_PARAM_UNUSED;
    }

  if (stmt->stmt_future)
    {
      if (!FUTURE_IS_READY (stmt->stmt_future))
	{
	  PROCESS_ALLOW_SCHEDULE ();
	  if (!FUTURE_IS_READY (stmt->stmt_future))
	    return stmt_seq_error (stmt);
	}
    }

  dk_alloc_assert (stmt);

#ifdef INPROCESS_CLIENT
  if (SESSION_IS_INPROCESS (stmt->stmt_connection->con_session))
    stmt->stmt_opts->so_autocommit = 0;
  else
#endif
    stmt->stmt_opts->so_autocommit = stmt->stmt_connection->con_autocommit;

  stmt->stmt_opts->so_isolation = stmt->stmt_connection->con_isolation;
  stmt->stmt_current_of = -1;
  stmt->stmt_fetch_current_of = -1;
  stmt->stmt_parm_rows_to_go = stmt->stmt_parm_rows;
  stmt->stmt_fetch_mode = FETCH_NONE;

  if (stmt->stmt_pirow)
    *stmt->stmt_pirow = 0;

  stmt->stmt_n_rows_to_get = stmt->stmt_opts->so_prefetch;

  /* Initialize to not available */
  stmt->stmt_rows_affected = -1;

  dk_free_tree (stmt->stmt_prefetch_row);
  stmt->stmt_prefetch_row = NULL;
  stmt_free_current_rows (stmt);
  stmt->stmt_at_end = 0;
  stmt->stmt_on_first_row = 1;
  stmt->stmt_last_asked_param = 0;
  stmt->stmt_is_proc_returned = 0;

  if (!stmt->stmt_compilation)
    current_ofs = con_make_current_ofs (stmt->stmt_connection, stmt);
  else
    {
      if (stmt->stmt_compilation->sc_cursors_used)
	current_ofs = con_make_current_ofs (stmt->stmt_connection, stmt);
    }

  if (stmt->stmt_future)
    PrpcFutureFree (stmt->stmt_future);

  if (!stmt->stmt_compilation || stmt->stmt_compilation->sc_is_select)
    cr_name = stmt->stmt_cursor_name ? stmt->stmt_cursor_name : stmt->stmt_id;

  cli_dbg_printf (("RPC out.\n"));
  old_concur = stmt->stmt_opts->so_concurrency;

/* The following line was changed, because from 16-MAY-1997 onward
   con_access_mode can be also SQL_MODE_READ_ONLY_PERMANENTLY (2UL)
   not just SQL_MODE_READ_WRITE (0L) or SQL_MODE_READ_ONLY (1L)
  if (stmt->stmt_connection->con_access_mode == SQL_MODE_READ_ONLY)
 */
  if (stmt->stmt_connection->con_access_mode != SQL_MODE_READ_WRITE)
    {
      /* SQL_CONCUR_ROWVER means READ-ONLY SNAPSHOT readmode with Kubl! */
      stmt->stmt_opts->so_concurrency = SQL_CONCUR_ROWVER;
    }

  cli_dbg_printf (("Executing %s on HDBC %lx, concurrency %d\n",
	  stmt->stmt_id, stmt->stmt_connection, stmt->stmt_opts->so_concurrency));

  stmt->stmt_status = STS_SERVER_DAE;
  stmt->stmt_pending.p_api = SQL_API_SQLEXECDIRECT;

  stmt->stmt_status = STS_SERVER_DAE;
  stmt->stmt_pending.p_api = SQL_API_SQLEXECDIRECT;

  if (!stmt->stmt_connection->con_autocommit)
    stmt->stmt_connection->con_in_transaction = 1;

  cli_dbg_printf (("virtodbc__SQLExecDirect (hstmt=%p) : before RPC\n", (void *) hstmt));
  stmt->stmt_future =
      PrpcFuture (stmt->stmt_connection->con_session, &s_sql_execute,
      stmt->stmt_id, string, cr_name, params, current_ofs, stmt->stmt_opts);
  cli_dbg_printf (("virtodbc__SQLExecDirect (hstmt=%p) : after RPC\n", (void *) hstmt));

  if (stmt->stmt_opts->so_rpc_timeout)
    PrpcFutureSetTimeout (stmt->stmt_future, (long) stmt->stmt_opts->so_rpc_timeout);
  else
    PrpcFutureSetTimeout (stmt->stmt_future, 2000000000L); /* infinite, 2M s = 23 days  */

  stmt->stmt_opts->so_concurrency = old_concur;
  cli_dbg_printf (("RPC sent.\n"));

  if (string)
    dk_free_box (string);

  dk_free_tree ((caddr_t) params);
  dk_free_box_and_int_boxes ((caddr_t) current_ofs);

  if (stmt->stmt_opts->so_is_async)
    return SQL_STILL_EXECUTING;

  cli_dbg_printf (("Calling stmt_process_res\n"));
  rc = stmt_process_result (stmt, 1);
  cli_dbg_printf ((stderr, "virtodbc__SQLExecDirect (hstmt=%p) : after process_result\n", (void *) hstmt));

  if (stmt->stmt_opts->so_rpc_timeout)
    PrpcSessionResetTimeout (stmt->stmt_connection->con_session);

  if (rc == SQL_NO_DATA_FOUND)
    rc = SQL_SUCCESS;

  return rc;
}


SQLRETURN SQL_API
SQLExecDirect (
	SQLHSTMT hstmt,
	SQLCHAR * wszSqlStr,
	SQLINTEGER cbSqlStr)
{
  SQLRETURN rc;
  size_t len;
  STMT (stmt, hstmt);
  NDEFINE_INPUT_NARROW (SqlStr);

  NMAKE_INPUT_ESCAPED_NARROW (SqlStr, stmt->stmt_connection);

  rc = virtodbc__SQLExecDirect (hstmt, szSqlStr, cbSqlStr);

  NFREE_INPUT_NARROW (SqlStr);

  return rc;
}


SQLRETURN SQL_API
SQLExecute (
	SQLHSTMT hstmt)
{
  return virtodbc__SQLExecDirect (hstmt, NULL, 0);
}


SQLRETURN SQL_API
virtodbc__SQLFetch (
	SQLHSTMT hstmt, int preserve_rowset_at_end)
{
  STMT (stmt, hstmt);
  int err;

  cli_dbg_printf (("SQLFetch (%lx)\n", stmt));

  dk_alloc_assert (stmt);

  if (stmt->stmt_opts->so_cursor_type != SQL_CURSOR_FORWARD_ONLY)
    return (sql_fetch_scrollable (stmt));

  set_error (&stmt->stmt_error, NULL, NULL, NULL);

  VERIFY_INPROCESS_CLIENT (stmt->stmt_connection);

  while (1)
    {
      if (stmt->stmt_at_end)
	{
	  if (!preserve_rowset_at_end)
	    stmt_free_current_rows (stmt);

	  return SQL_NO_DATA_FOUND;
	}

      if (stmt->stmt_prefetch_row)
	{
	  stmt->stmt_current_of++;
	  set_error (&stmt->stmt_error, NULL, NULL, NULL);
	  dk_free_tree ((box_t) stmt->stmt_current_row);
	  stmt->stmt_current_row = (caddr_t *) stmt->stmt_prefetch_row;
	  stmt_set_columns (stmt, (caddr_t *) stmt->stmt_prefetch_row, stmt->stmt_fwd_fetch_irow);
	  stmt->stmt_prefetch_row = NULL;

	  return SUCCESS (&stmt->stmt_error);
	}

      if ((stmt->stmt_current_of == stmt->stmt_n_rows_to_get - 1
	      || stmt->stmt_co_last_in_batch)
	  && stmt->stmt_compilation && QT_SELECT == stmt->stmt_compilation->sc_is_select && 1 == stmt->stmt_parm_rows)
	{
	  /* Order the next batch */
	  PrpcFutureFree (PrpcFuture (stmt->stmt_connection->con_session,
		  &s_sql_fetch, stmt->stmt_id, stmt->stmt_future->ft_request_no));

	  if (stmt->stmt_opts->so_rpc_timeout)
	    PrpcFutureSetTimeout (stmt->stmt_future, (long) stmt->stmt_opts->so_rpc_timeout);
	  else
	    PrpcFutureSetTimeout (stmt->stmt_future, 2000000000L); /* infinite, 2M s = 23 days  */

	  stmt->stmt_current_of = -1;
	}

      if (stmt->stmt_opts->so_is_async)
	{
	  if (!FUTURE_IS_NEXT_RESULT (stmt->stmt_future))
	    PROCESS_ALLOW_SCHEDULE ();

	  if (!FUTURE_IS_NEXT_RESULT (stmt->stmt_future))
	    return SQL_STILL_EXECUTING;
	}

      err = stmt_process_result (stmt, 1);

      if (stmt->stmt_opts->so_rpc_timeout)
	PrpcSessionResetTimeout (stmt->stmt_connection->con_session);

      if (err == SQL_ERROR || err == SQL_NO_DATA_FOUND)
	return err;
    }
}


SQLRETURN SQL_API
SQLFetch (SQLHSTMT hstmt)
{
  STMT (stmt, hstmt);

  set_error (&stmt->stmt_error, NULL, NULL, NULL);

  if (stmt->stmt_connection->con_environment->env_odbc_version < 3)
    {
      if (stmt->stmt_fetch_mode == FETCH_EXT)
	{
	  set_error (&stmt->stmt_error, "HY010", "CL041", "Can't mix SQLFetch and SQLExtendedFetch.");
	  return SQL_ERROR;
	}

      stmt->stmt_fetch_mode = FETCH_FETCH;

      return virtodbc__SQLFetch (hstmt, 0);
    }
  else
    return virtodbc__SQLExtendedFetch (hstmt, SQL_FETCH_NEXT, 0, stmt->stmt_rows_fetched_ptr, stmt->stmt_row_status, 0);
}


SQLRETURN SQL_API
SQLFreeConnect (SQLHDBC hdbc)
{
  return virtodbc__SQLFreeConnect (hdbc);
}


SQLRETURN SQL_API
virtodbc__SQLFreeConnect (SQLHDBC hdbc)
{
  CON (con, hdbc);

  set_error (&con->con_error, NULL, NULL, NULL);

  if (con->con_session)
    {
      /* if client by some reason do SQLFreeConnect but not SQLDisconnect */
      if (SESSION_SCH_DATA (con->con_session)->sio_is_served != -1)
	PrpcDisconnect (con->con_session);
      PrpcSessionFree (con->con_session);
    }

  if (con->con_bookmarks)
    hash_table_free (con->con_bookmarks);

  if (con->con_charset)
    wide_charset_free (con->con_charset);

  if (con->con_user)
    dk_free_box ((box_t) con->con_user);

  if (con->con_qualifier)
    dk_free_box ((box_t) con->con_qualifier);

  if (con->con_db_ver)
    dk_free_box ((box_t) con->con_db_ver);

  if (con->con_charset_name)
    dk_free_box ((box_t) con->con_charset_name);

  if (con->con_dsn)
    dk_free_box ((box_t) con->con_dsn);

  if (con->con_rdf_langs)
    hash_table_free (con->con_rdf_langs);

  if (con->con_rdf_types)
    hash_table_free (con->con_rdf_types);

  mutex_free (con->con_mtx);

  dk_set_delete (&con->con_environment->env_connections, (void *) con);
  dk_free ((caddr_t) con, sizeof (cli_connection_t));

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLFreeEnv (SQLHENV henv)
{
  return virtodbc__SQLFreeEnv (henv);
}


SQLRETURN SQL_API
virtodbc__SQLFreeEnv (SQLHENV henv)
{
  ENV (env, henv);

  set_error (&env->env_error, NULL, NULL, NULL);

  mutex_free (env->env_mtx);

  dk_free ((caddr_t) env, sizeof (cli_environment_t));

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
virtodbc__SQLFreeStmt (SQLHSTMT hstmt, SQLUSMALLINT fOption)
{
  STMT (stmt, hstmt);
  future_t *f;

  cli_dbg_printf (("virtodbc__SQLFreeStmt (hstmt=%p, fOption=%u)\n", (void *) hstmt, (unsigned) fOption));
  set_error (&stmt->stmt_error, NULL, NULL, NULL);

  switch (fOption)
    {
    case SQL_CLOSE:
      /* stmt_check_at_end (stmt); */
      stmt_free_current_rows (stmt);
      dk_free_tree (stmt->stmt_prefetch_row);
      stmt->stmt_prefetch_row = NULL;
      stmt->stmt_rowset_fill = 0;

      if (!stmt->stmt_at_end)
	virtodbc__SQLCancel (hstmt);

      if (stmt->stmt_future)
	PrpcFutureFree (stmt->stmt_future);

      stmt->stmt_future = NULL;

      break;

    case SQL_RESET_PARAMS:
      {
	parm_binding_t *pb = stmt->stmt_parms;

	while (pb)
	  {
	    parm_binding_t *next = pb->pb_next;
	    dk_free ((caddr_t) pb, sizeof (parm_binding_t));
	    pb = next;
	  }

	stmt->stmt_parms = NULL;
	stmt->stmt_n_parms = 0;

	if (stmt->stmt_return)
	  {
	    dk_free ((caddr_t) stmt->stmt_return, sizeof (parm_binding_t));
	    stmt->stmt_return = NULL;
	  }

	break;
      }

    case SQL_UNBIND:
      {
	col_binding_t *pb = stmt->stmt_cols;

	while (pb)
	  {
	    col_binding_t *next = pb->cb_next;
	    dk_free ((caddr_t) pb, sizeof (col_binding_t));
	    pb = next;
	  }

	stmt->stmt_cols = NULL;
	stmt->stmt_n_cols = 0;

	if (stmt->stmt_bookmark_cb)
	  {
	    dk_free ((caddr_t) stmt->stmt_bookmark_cb, sizeof (col_binding_t));
	    stmt->stmt_bookmark_cb = NULL;
	  }

	break;
      }

    case SQL_DROP:
      virtodbc__SQLFreeStmt (hstmt, SQL_UNBIND);
      virtodbc__SQLFreeStmt (hstmt, SQL_RESET_PARAMS);

      if (stmt->stmt_set_pos_stmt)
	virtodbc__SQLFreeStmt ((SQLHSTMT) stmt->stmt_set_pos_stmt, SQL_DROP);

      {
#ifdef INPROCESS_CLIENT
	SQLRETURN rc = SQL_SUCCESS;

	if (SESSION_IS_INPROCESS (stmt->stmt_connection->con_session))
	  rc = verify_inprocess_client (stmt->stmt_connection);

	if (rc == SQL_SUCCESS)
#endif
	  {
	    f = PrpcFuture (stmt->stmt_connection->con_session, &s_sql_free_stmt, stmt->stmt_id, (long) SQL_DROP);
	    cli_dbg_printf (("virtodbc__SQLFreeStmt (hstmt=%p, fOption=%u) : after rpc\n", (void *) hstmt, (unsigned) fOption));

	    if (stmt->stmt_connection->con_db_gen > 1519)
	      PrpcSync (f);
	    else
	      /* close is always async before G15d20 */
	      PrpcFutureFree (f);

	    cli_dbg_printf (
		("virtodbc__SQLFreeStmt (hstmt=%p, fOption=%u) : after PrpcSync\n", (void *) hstmt, (unsigned) fOption));
	  }
      }

      if (stmt->stmt_bookmarks)
	stmt_free_bookmarks (stmt);
      if (stmt->stmt_future)
	PrpcFutureFree (stmt->stmt_future);
      IN_CON (stmt->stmt_connection);
      dk_set_delete (&stmt->stmt_connection->con_statements, (void *) stmt);
      LEAVE_CON (stmt->stmt_connection);
      stmt_free_current_rows (stmt);
      dk_free_tree (stmt->stmt_prefetch_row);
      stmt->stmt_prefetch_row = NULL;
      dk_free_tree ((caddr_t) stmt->stmt_compilation);
      dk_free_tree (stmt->stmt_id);
      stmt->stmt_id = NULL;
      dk_free_box ((caddr_t) stmt->stmt_opts);
      stmt->stmt_opts = NULL;

      if (stmt->stmt_dae)
	{
	  dk_free_tree ((box_t) dk_set_to_array (stmt->stmt_dae));
	  dk_set_free (stmt->stmt_dae);
	}

      stmt->stmt_dae = NULL;
      dk_free_box ((caddr_t) stmt->stmt_current_dae);
      stmt->stmt_current_dae = NULL;
      dk_set_free (stmt->stmt_dae_fragments);
      stmt->stmt_dae_fragments = NULL;
      dk_free_tree ((box_t) stmt->stmt_param_array);
      stmt->stmt_param_array = NULL;
      dk_free_box (stmt->stmt_identity_value);

#if (ODBCVER >= 0x0300)
      if (stmt->stmt_app_row_descriptor)
	{
	  dk_free ((caddr_t) stmt->stmt_app_row_descriptor, sizeof (stmt_descriptor_t));
	  dk_free ((caddr_t) stmt->stmt_imp_row_descriptor, sizeof (stmt_descriptor_t));
	  dk_free ((caddr_t) stmt->stmt_app_param_descriptor, sizeof (stmt_descriptor_t));
	  dk_free ((caddr_t) stmt->stmt_imp_param_descriptor, sizeof (stmt_descriptor_t));
	}
#endif
      dk_free ((caddr_t) stmt, sizeof (cli_stmt_t));
    }

  cli_dbg_printf (("virtodbc__SQLFreeStmt (hstmt=%p, fOption=%u) : done\n", (void *) hstmt, (unsigned) fOption));

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLFreeStmt (SQLHSTMT hstmt, SQLUSMALLINT fOption)
{
  return virtodbc__SQLFreeStmt (hstmt, fOption);
}


SQLRETURN SQL_API
virtodbc__SQLGetCursorName (
	SQLHSTMT hstmt,
	SQLCHAR * szCursor,
	SQLSMALLINT cbCursorMax,
	SQLSMALLINT * pcbCursor)
{
  STMT (stmt, hstmt);
  char *cr_name = stmt->stmt_cursor_name;
  int len;

  if (!cr_name)
    {
      cr_name = stmt->stmt_id;
#if 0
      set_error (&stmt->stmt_error, "42000", "Statement has no cursor name.");
      return SQL_ERROR;
#endif
    }

  str_box_to_place (cr_name, (char *) szCursor, cbCursorMax, &len);

  if (pcbCursor)
    *pcbCursor = len;

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLGetCursorName (
	SQLHSTMT hstmt,
	SQLCHAR * wszCursor,
	SQLSMALLINT cbCursor,
	SQLSMALLINT * pcbCursor)
{
  SQLRETURN rc;
  STMT (stmt, hstmt);
  NDEFINE_OUTPUT_CHAR_NARROW (Cursor, stmt->stmt_connection, SQLSMALLINT);

  NMAKE_OUTPUT_CHAR_NARROW (Cursor, stmt->stmt_connection);

  rc = virtodbc__SQLGetCursorName (hstmt, szCursor, _cbCursor, _pcbCursor);

  NSET_AND_FREE_OUTPUT_CHAR_NARROW (Cursor, stmt->stmt_connection);

  return rc;
}


SQLRETURN SQL_API
SQLNumResultCols (SQLHSTMT hstmt, SQLSMALLINT * pccol)
{
  return virtodbc__SQLNumResultCols (hstmt, pccol);
}


SQLRETURN SQL_API
virtodbc__SQLNumResultCols (
      SQLHSTMT hstmt,
      SQLSMALLINT * pccol)
{
  STMT (stmt, hstmt);
  stmt_compilation_t *sc = stmt->stmt_compilation;

  if (!sc)
    {
      set_error (&stmt->stmt_error, "HY010", "CL042", "Statement not prepared.");
      return SQL_ERROR;
    }

  if (sc->sc_is_select == QT_PROC_CALL)
    {
      if (sc->sc_columns)
	*pccol = (SQLSMALLINT) BOX_ELEMENTS ((caddr_t) sc->sc_columns);
      else
	*pccol = 0;

      return SQL_SUCCESS;
    }

  if (sc->sc_is_select != QT_SELECT)
    {
      *pccol = 0;

      return SQL_SUCCESS;
    }

  *pccol = (SQLSMALLINT) (box_length ((caddr_t) sc->sc_columns) / sizeof (caddr_t));

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
virtodbc__SQLPrepare (
	SQLHSTMT hstmt,
	SQLCHAR * szSqlStr,
	SQLINTEGER cbSqlStr)
{
  caddr_t local_copy, text;
  STMT (stmt, hstmt);

  set_error (&stmt->stmt_error, NULL, NULL, NULL);

  local_copy = box_n_string (szSqlStr, cbSqlStr);
  text = (caddr_t) stmt_convert_brace_escapes ((SQLCHAR *) local_copy, &cbSqlStr);

  cli_dbg_printf (("SQLPrepare (%s, %s)\n", stmt->stmt_id, text));
  VERIFY_INPROCESS_CLIENT (stmt->stmt_connection);

  dk_free_tree ((box_t) stmt->stmt_compilation);
  stmt->stmt_compilation = NULL;

  stmt->stmt_future = PrpcFuture (stmt->stmt_connection->con_session,
      &s_sql_prepare, stmt->stmt_id, text, (long) 0, stmt->stmt_opts);

  dk_free_box (local_copy);

  return (stmt_process_result (stmt, 0));
}


SQLRETURN SQL_API
SQLPrepare (
	SQLHSTMT hstmt,
	SQLCHAR * wszSqlStr,
	SQLINTEGER cbSqlStr)
{
  size_t len;
  SQLRETURN rc;
  STMT (stmt, hstmt);
  NDEFINE_INPUT_NARROW (SqlStr);

  NMAKE_INPUT_ESCAPED_NARROW (SqlStr, stmt->stmt_connection);

  rc = virtodbc__SQLPrepare (hstmt, szSqlStr, SQL_NTS);

  NFREE_INPUT_NARROW (SqlStr);

  return rc;
}


SQLRETURN SQL_API
SQLRowCount (SQLHSTMT hstmt, SQLLEN * pcrow)
{
  STMT (stmt, hstmt);

  *pcrow = stmt->stmt_rows_affected;

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
virtodbc__SQLSetCursorName (
      SQLHSTMT hstmt,
      SQLCHAR * szCursor,
      SQLSMALLINT cbCursor)
{
  STMT (stmt, hstmt);
  caddr_t name = box_n_string (szCursor, cbCursor);

  if (stmt->stmt_cursor_name)
    dk_free_box (stmt->stmt_cursor_name);

  stmt->stmt_cursor_name = name;

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLSetCursorName (
      SQLHSTMT hstmt,
      SQLCHAR * wszCursor,
      SQLSMALLINT _cbCursor)
{
  STMT (stmt, hstmt);
  SQLRETURN rc;
  size_t len;
  size_t cbCursor = _cbCursor;
  NDEFINE_INPUT_NARROW (Cursor);

  NMAKE_INPUT_NARROW (Cursor, stmt->stmt_connection);

  rc = virtodbc__SQLSetCursorName (hstmt, szCursor, (SQLSMALLINT) cbCursor);

  NFREE_INPUT_NARROW (Cursor);
  return rc;
}


SQLRETURN SQL_API
virtodbc__SQLSetParam (
      SQLHSTMT hstmt,
      SQLUSMALLINT ipar,
      SQLSMALLINT fCType,
      SQLSMALLINT fSqlType,
      SQLULEN cbColDef,
      SQLSMALLINT ibScale,
      SQLPOINTER rgbValue,
      SQLLEN * pcbValue)
{
  STMT (stmt, hstmt);
  parm_binding_t *pb = stmt_nth_parm (stmt, ipar);

  if (fCType == SQL_C_DEFAULT)
    fCType = sql_type_to_sqlc_default (fSqlType);

  pb->pb_c_type = fCType;
  pb->pb_sql_type = fSqlType;
  pb->pb_place = (caddr_t) rgbValue;
  pb->pb_max_length = cbColDef;
  pb->pb_length = pcbValue;
  pb->pb_param_type = SQL_PARAM_INPUT;

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLSetParam (
      SQLHSTMT hstmt,
      SQLUSMALLINT ipar,
      SQLSMALLINT fCType,
      SQLSMALLINT fSqlType,
      SQLULEN cbColDef,
      SQLSMALLINT ibScale,
      SQLPOINTER rgbValue,
      SQLLEN * pcbValue)
{
  return virtodbc__SQLSetParam (hstmt, ipar, fCType, fSqlType, cbColDef, ibScale, rgbValue, pcbValue);
}


SQLRETURN SQL_API
virtodbc__SQLBindParameter (
	SQLHSTMT hstmt,
	SQLUSMALLINT ipar,
	SQLSMALLINT fParamType,
	SQLSMALLINT fCType,
	SQLSMALLINT fSqlType,
	SQLULEN cbColDef,
	SQLSMALLINT ibScale,
	SQLPOINTER rgbValue,
	SQLLEN cbValueMax,
	SQLLEN * pcbValue)
{
  STMT (stmt, hstmt);
  parm_binding_t *pb;

  if (fParamType == SQL_RETURN_VALUE)
    {
      pb = (parm_binding_t *) dk_alloc (sizeof (parm_binding_t));
      memset (pb, 0, sizeof (parm_binding_t));
      stmt->stmt_return = pb;
    }
  else
    pb = stmt_nth_parm (stmt, ipar);

  if (cbValueMax == SQL_SETPARAM_VALUE_MAX)
    cbValueMax = MAX (cbColDef, 0);

  if (fCType == SQL_C_DEFAULT)
    fCType = sql_type_to_sqlc_default (fSqlType);

  pb->pb_c_type = fCType;
  pb->pb_sql_type = fSqlType;
  pb->pb_place = (caddr_t) rgbValue;
  pb->pb_max_length = cbColDef;
  pb->pb_length = pcbValue;
  pb->pb_param_type = fParamType;
  pb->pb_max = cbValueMax;

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLBindParameter (
    SQLHSTMT hstmt,
    SQLUSMALLINT ipar,
    SQLSMALLINT fParamType,
    SQLSMALLINT fCType,
    SQLSMALLINT fSqlType,
    SQLULEN cbColDef,
    SQLSMALLINT ibScale,
    SQLPOINTER rgbValue,
    SQLLEN cbValueMax,
    SQLLEN * pcbValue)
{
  return virtodbc__SQLBindParameter (hstmt, ipar, fParamType, fCType, fSqlType, cbColDef, ibScale, rgbValue, cbValueMax, pcbValue);
}


SQLRETURN SQL_API
SQLTransact (
      SQLHENV henv,
      SQLHDBC hdbc,
      SQLUSMALLINT fType)
{
  return virtodbc__SQLTransact (henv, hdbc, fType);
}


SQLRETURN SQL_API
virtodbc__SQLTransact (
      SQLHENV henv,
      SQLHDBC hdbc,
      SQLUSMALLINT fType)
{
  cli_dbg_printf ((stderr, "virtodbc__SQLTransact (henv=%p, hdbc=%p, fType=%u)\n", (void *) henv, (void *) hdbc, (unsigned) fType));

  if (!hdbc)
    {
      ENV (env, henv);
      int n;
      SQLRETURN rc;

      if (!env)
	return (SQL_INVALID_HANDLE);

      for (n = 0; ((uint32) n) < dk_set_length (env->env_connections); n++)
	{
	  rc = virtodbc__SQLTransact (SQL_NULL_HENV, (SQLHDBC) dk_set_nth (env->env_connections, n), fType);

	  if (rc != SQL_SUCCESS)
	    return rc;
	}

      return (SQL_SUCCESS);
    }
  else
    {
      CON (dbc, hdbc);
      future_t *f;
      caddr_t *res;

      VERIFY_INPROCESS_CLIENT (dbc);

#ifdef VIRTTP
      if (fType & SQL_TP_UNENLIST)
	{
	  dbg_printf (("sql_tp_transact... \n"));
	  f = PrpcFuture (dbc->con_session, &s_sql_tp_transact, (long) fType, NULL);
	}
      else
#endif
	f = PrpcFuture (dbc->con_session, &s_sql_transact, (long) fType, NULL);

      dbc->con_in_transaction = 0;
      res = (caddr_t *) PrpcFutureNextResult (f);
      set_error (&dbc->con_error, NULL, NULL, NULL);
      PrpcFutureFree (f);

      if (!DKSESSTAT_ISSET (dbc->con_session, SST_OK))
	{
	  set_error (&dbc->con_error, "08S01", "CL043", "Connection lost to server");
	  return SQL_ERROR;
	}

      if (res == (caddr_t *) SQL_SUCCESS)
	{
	  return SQL_SUCCESS;
	}
      else
	{
	  caddr_t srv_msg = cli_box_server_msg (res[2]);
	  set_error (&dbc->con_error, res[1], NULL, srv_msg);
	  dk_free_tree ((caddr_t) res);
	  dk_free_box (srv_msg);

	  return SQL_ERROR;
	}
    }
}


#if 0
SQLRETURN SQL_API
SQLSync (SQLHSTMT hstmt)
{
  STMT (stmt, hstmt);

  return stmt_process_result (stmt, 1);
}


SQLRETURN SQL_API
SQLShutdown (SQLHDBC hdbc, char *new_log)
{
  CON (dbc, hdbc);
  caddr_t box = new_log ? box_string (new_log) : NULL;

  PrpcFutureFree (PrpcFuture (dbc->con_session, &s_ds_shutdown, box));

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLCheckpoint (SQLHDBC hdbc, char *new_log)
{
  CON (dbc, hdbc);
  caddr_t box = new_log ? box_string (new_log) : NULL;

  VERIFY_INPROCESS_CLIENT (dbc);

  PrpcSync (PrpcFuture (dbc->con_session, &s_ds_makecp, box));

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLStatus (SQLHDBC hdbc, char *buffer, int max)
{
  CON (dbc, hdbc);
  caddr_t *sta;

  VERIFY_INPROCESS_CLIENT (dbc);

  sta = (caddr_t *) PrpcSync (PrpcFutureSetTimeout (PrpcFuture (dbc->con_session, &s_ds_status), 40000L));
  if (sta)
    {
      if (box_tag (sta) == DV_LIST_OF_POINTER)
	{
	  int inx;
	  int point = 0;

	  for (inx = 0; inx < BOX_ELEMENTS (sta); inx++)
	    {
	      int len = box_length (sta[inx]);

	      if (point + len > max - 1)
		break;

	      memcpy (buffer + point, sta[inx], len - 1);
	      point += len - 1;
	    }

	  buffer[point] = 0;
	  dk_free_tree (sta);

	  return SQL_SUCCESS;
	}
      else
	return SQL_ERROR;
    }
  else
    return SQL_ERROR;
}
#endif
