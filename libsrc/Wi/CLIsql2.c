/*
 *  CLIsql2.c
 *
 *  $Id$
 *
 *  Client API, ODBC Extensions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

#if !defined (__APPLE__)
#include <wchar.h>
#endif
#include "CLI.h"
#include "sqlver.h"
#include "multibyte.h"
#include "libutil.h"


/* #include <transact.h>
#include "mts_client.h"*/
#define IN_ODBC_CLIENT
#include "wi.h"
#include "msdtc.h"
#include "2pc.h"
#include <string.h>

#ifdef VIRTTP
dk_set_t d_trx_set = 0;
#endif

#define SQL_LCK_NO_CHANGE		0x00000001L
#define SQL_LCK_EXCLUSIVE		0x00000002L
#define SQL_LCK_UNLOCK			0x00000004L
#define SQL_SS_ADDITIONS		0x00000001L
#define SQL_SS_DELETIONS		0x00000002L
#define SQL_SS_UPDATES			0x00000004L
#define SQL_API_ALL_FUNCTIONS		0
#define SQL_API_SQLBINDPARAMETER	72

#define SYS_TABLE_PREFIX "SYS_%"
#define METADATA_SEARCH_STRING_ESCAPE '\\'
#define KUBL_IDENTIFIER_MAX_LENGTH 128

#define is_empty(S,CB) \
  ((0 == (CB)) || ((SQL_NTS == (CB)) && ( !(S) || ((S) && !*(S)) ) ) )

#define is_empty_or_null(S,CB) \
	(is_empty((S), (CB)) || (SQL_NULL_DATA == (CB)))

#define is_percent(S, S1, CB)\
  ((S) && ((1 == (CB)) || ((SQL_NTS == (CB)) && !*((S1) + 1))) && ('%' == *(S1)))

#define BIND_NAME_PART(st, nth, szname, _szname, cbname, cbtemp) \
  cbtemp = cbname; \
  if (is_empty (szname, cbtemp)) \
    szname = NULL; \
  else \
    remove_search_escapes((char *) szname, _szname, sizeof (_szname), &cbtemp, cbname); \
  if (!szname) \
    { \
      szname = (SQLCHAR *) "%"; \
      _szname[0] = '%'; \
      _szname[1] = 0; \
      cbtemp = SQL_NTS; \
    } \
  virtodbc__SQLSetParam (st, nth, SQL_C_CHAR, SQL_CHAR, 0, 0, (SQLCHAR *)_szname, &cbtemp);

#define DEFAULT_QUAL(stmt, qlen) \
  if (!szTableQualifier) \
    { \
      char *__szTableQualifier = (char *) _szTableQualifier; \
      szTableQualifier = stmt->stmt_connection->con_qualifier; \
      strcpy_size_ck (__szTableQualifier, (const char *) szTableQualifier, sizeof (_szTableQualifier)); \
      qlen = (cbTableQualifier = SQL_NTS); \
    }

char __virtodbc_dbms_name[512];


SQLRETURN SQL_API
SQLBrowseConnect (
      SQLHDBC hdbc,
      SQLCHAR * szConnStrIn,
      SQLSMALLINT cbConnStrIn,
      SQLCHAR * szConnStrOut,
      SQLSMALLINT cbConnStrOutMax,
      SQLSMALLINT * pcbConnStrOut)
{
  NOT_IMPL_FUN (hdbc, "Function not supported: SQLBrowseConnect");
}


void
remove_search_escapes(char *szValue, char *szTo, size_t _max_szTo, SQLLEN *pLen, SQLLEN nLen)
{
  if (szValue && nLen)
    {
      SQLLEN max_szTo = (SQLLEN) _max_szTo;
      if (SQL_NTS != nLen)
	{
	  strncpy (szTo, szValue, MIN (nLen, max_szTo));
	  szTo[MIN (nLen, max_szTo)] = 0;
	}
      else
	strcpy_size_ck (szTo, szValue, max_szTo);
      *pLen = strlen (szTo);
    }
  else
    {
      szTo[0] = 0;
      *pLen = 0;
    }
}


/*
   SQLColumns returns the results as a standard result set, ordered by
   TABLE_QUALIFIER (here always 'db'), TABLE_OWNER (here always 'dba')
   and TABLE_NAME.

   Note how the clause: either(isnull(COL_NULLABLE),2,COL_NULLABLE)
   returns the 11th column (NULLABLE) either as 2 (= SQL_NULLABLE_UNKNOWN)
   in case that COL_NULLABLE in SYS_COLS is NULL, or then it should return
   0 (= SQL_NO_NULLS) or 1 (= SQL_NULLABLE) presumably contained in
   COL_NULLABLE column, if it is not NULL.
 */

char *sql_columns_text_casemode_2 =
"select\n"
" name_part (k.KEY_TABLE,0) AS TABLE_CAT VARCHAR(128),\n"
" name_part (k.KEY_TABLE,1) AS TABLE_SCHEM VARCHAR(128),\n"
" name_part (k.KEY_TABLE,2) AS TABLE_NAME VARCHAR(128), \n"
" c.\"COLUMN\" AS COLUMN_NAME VARCHAR(128),	\n"
" cast (case ? when 1 then dv_to_sql_type3(c.COL_DTP) else dv_to_sql_type(c.COL_DTP) end as INTEGER) AS DATA_TYPE SMALLINT,\n"
" case when (c.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (c.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(c.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */
" case when (c.COL_PREC = 0 and c.COL_DTP in (125, 132)) then " VARCHAR_UNSPEC_SIZE "  when (c.COL_PREC = 0 and c.COL_DTP = 225) then " VARCHAR_UNSPEC_SIZE " else c.COL_PREC end AS COLUMN_SIZE INTEGER,\n"
" c.COL_PREC AS BUFFER_LENGTH INTEGER,\n"
" c.COL_SCALE AS DECIMAL_DIGITS SMALLINT,\n"
" 2 AS NUM_PREC_RADIX SMALLINT,\n"
" case c.COL_NULLABLE when 1 then 0 else 1 end AS NULLABLE SMALLINT,\n"
" NULL AS REMARKS VARCHAR(254), \n"
" deserialize (c.COL_DEFAULT) AS COLUMN_DEF VARCHAR(254), \n"
" case ? when 1 then dv_to_sql_type3(c.COL_DTP) else dv_to_sql_type(c.COL_DTP) end AS SQL_DATA_TYPE SMALLINT,\n"
" case c.COL_DTP when 129 then 1 when 210 then 2 when 211 then 3 else NULL end AS SQL_DATETIME_SUB SMALLINT,\n"
" c.COL_PREC AS CHAR_OCTET_LENGTH INTEGER,\n"
" cast ((select count(*) from DB.DBA.SYS_COLS where \\TABLE = k.KEY_TABLE and COL_ID <= c.COL_ID) as INTEGER) AS ORDINAL_POSITION INTEGER, \n"
" case c.COL_NULLABLE when 1 then 'NO' else 'YES' end AS IS_NULLABLE VARCHAR \n"
"from DB.DBA.SYS_KEYS k, DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS c \n"
"where upper (name_part (k.KEY_TABLE,0)) like upper (?)\n"
"  and __any_grants (KEY_TABLE) "
"  and upper (name_part (k.KEY_TABLE,1)) like upper (?)\n"
"  and upper (name_part (k.KEY_TABLE,2)) like upper (?)\n"
"  and upper (c.\"COLUMN\") like upper (?)\n"
"  and c.\"COLUMN\" <> '_IDN' \n"
"  \n"
"  and k.KEY_IS_MAIN = 1\n"
"  and k.KEY_MIGRATE_TO is null\n"
"  and kp.KP_KEY_ID = k.KEY_ID\n"
"  and COL_ID = KP_COL\n"
"  \n"
"\n"
"order by KEY_TABLE, 17\n";

char *sql_columns_text_casemode_0 =
"select\n"
" name_part (k.KEY_TABLE,0) AS TABLE_CAT VARCHAR(128),\n"
" name_part (k.KEY_TABLE,1) AS TABLE_SCHEM VARCHAR(128),\n"
" name_part (k.KEY_TABLE,2) AS TABLE_NAME VARCHAR(128), \n"
" c.\"COLUMN\" AS COLUMN_NAME VARCHAR(128),	\n"
" cast (case ? when 1 then dv_to_sql_type3(c.COL_DTP) else dv_to_sql_type(c.COL_DTP) end as SMALLINT) AS DATA_TYPE SMALLINT,\n"
" case when (c.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (c.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(c.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */
" case when (c.COL_PREC = 0 and c.COL_DTP in (125, 132)) then " VARCHAR_UNSPEC_SIZE "  when (c.COL_PREC = 0 and c.COL_DTP = 225) then " VARCHAR_UNSPEC_SIZE " else c.COL_PREC end AS COLUMN_SIZE INTEGER,\n"
" c.COL_PREC AS BUFFER_LENGTH INTEGER,\n"
" c.COL_SCALE AS DECIMAL_DIGITS SMALLINT,\n"
" 2 AS NUM_PREC_RADIX SMALLINT,\n"
" cast (case c.COL_NULLABLE when 1 then 0 else 1 end as SMALLINT) AS NULLABLE SMALLINT,\n"
" NULL AS REMARKS VARCHAR(254), \n"
" cast (deserialize (c.COL_DEFAULT) as varchar) AS COLUMN_DEF VARCHAR(254), \n"
" cast (case ? when 1 then dv_to_sql_type3(c.COL_DTP) else dv_to_sql_type(c.COL_DTP) end as SMALLINT) AS SQL_DATA_TYPE SMALLINT,\n"
" cast (case c.COL_DTP when 129 then 1 when 210 then 2 when 211 then 3 else NULL end as SMALLINT) AS SQL_DATETIME_SUB SMALLINT,\n"
" cast (c.COL_PREC as INTEGER) AS CHAR_OCTET_LENGTH INTEGER,\n"
" cast ((select count(*) from DB.DBA.SYS_COLS where \\TABLE = k.KEY_TABLE and COL_ID <= c.COL_ID) as INTEGER) AS ORDINAL_POSITION INTEGER,\n"
" case c.COL_NULLABLE when 1 then 'NO' else 'YES' end AS IS_NULLABLE VARCHAR \n"
"from DB.DBA.SYS_KEYS k, DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS c \n"
"where name_part (k.KEY_TABLE,0) like ?\n"
" and __any_grants (KEY_TABLE)  "
"  and name_part (k.KEY_TABLE,1) like ?\n"
"  and name_part (k.KEY_TABLE,2) like ?\n"
"  and c.\"COLUMN\" like ?\n"
"  and c.\"COLUMN\" <> '_IDN' \n"
"  \n"
"  and k.KEY_IS_MAIN = 1\n"
"  and k.KEY_MIGRATE_TO is null\n"
"  and kp.KP_KEY_ID = k.KEY_ID\n"
"  and COL_ID = KP_COL\n"
"  \n"
"\n"
"order by KEY_TABLE, 17\n";

char *sql_columnsw_text_casemode_2 =
"select\n"
" charset_recode (name_part (k.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS TABLE_CAT VARCHAR(128),\n"
" charset_recode (name_part (k.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS TABLE_SCHEM VARCHAR(128),\n"
" charset_recode (name_part (k.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS TABLE_NAME VARCHAR(128), \n"
" charset_recode (c.\"COLUMN\", 'UTF-8', '_WIDE_') AS COLUMN_NAME VARCHAR(128),	\n"
" case ? when 1 then dv_to_sql_type3(c.COL_DTP) else dv_to_sql_type(c.COL_DTP) end AS DATA_TYPE SMALLINT,\n"
" case when (c.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (c.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(c.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */
" case when (c.COL_PREC = 0 and c.COL_DTP in (125, 132)) then " VARCHAR_UNSPEC_SIZE "  when (c.COL_PREC = 0 and c.COL_DTP = 225) then " VARCHAR_UNSPEC_SIZE " else c.COL_PREC end AS COLUMN_SIZE INTEGER,\n"
" c.COL_PREC AS BUFFER_LENGTH INTEGER,\n"
" c.COL_SCALE AS DECIMAL_DIGITS SMALLINT,\n"
" 2 AS NUM_PREC_RADIX SMALLINT,\n"
" case c.COL_NULLABLE when 1 then 0 else 1 end AS NULLABLE SMALLINT,\n"
" NULL AS REMARKS VARCHAR(254), \n"
" c.COL_DEFAULT AS COLUMN_DEF VARCHAR(254), \n"
" case ? when 1 then dv_to_sql_type3(c.COL_DTP) else dv_to_sql_type(c.COL_DTP) end AS SQL_DATA_TYPE SMALLINT,\n"
" case c.COL_DTP when 129 then 1 when 210 then 2 when 211 then 3 else NULL end AS SQL_DATETIME_SUB SMALLINT,\n"
" c.COL_PREC AS CHAR_OCTET_LENGTH INTEGER,\n"
" (select count(*) from DB.DBA.SYS_COLS where \\TABLE = k.KEY_TABLE and COL_ID <= c.COL_ID) AS ORDINAL_POSITION INTEGER,\n"
" case c.COL_NULLABLE when 1 then 'NO' else 'YES' end AS IS_NULLABLE INTEGER \n"
"from DB.DBA.SYS_KEYS k, DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS c \n"
"where charset_recode (upper (charset_recode (name_part (k.KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')\n"
"  and __any_grants (KEY_TABLE) "
"  and charset_recode (upper (charset_recode (name_part (k.KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')\n"
"  and charset_recode (upper (charset_recode (name_part (k.KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')\n"
"  and charset_recode (upper (charset_recode (c.\"COLUMN\", 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')\n"
"  and c.\"COLUMN\" <> '_IDN' \n"
"  \n"
"  and k.KEY_IS_MAIN = 1\n"
"  and k.KEY_MIGRATE_TO is null\n"
"  and kp.KP_KEY_ID = k.KEY_ID\n"
"  and COL_ID = KP_COL\n"
"  \n"
"\n"
"order by KEY_TABLE, 17\n";

char *sql_columnsw_text_casemode_0 =
"select\n"
" charset_recode (name_part (k.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS TABLE_CAT VARCHAR(128),\n"
" charset_recode (name_part (k.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS TABLE_SCHEM VARCHAR(128),\n"
" charset_recode (name_part (k.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS TABLE_NAME VARCHAR(128), \n"
" charset_recode (c.\"COLUMN\", 'UTF-8', '_WIDE_') AS COLUMN_NAME VARCHAR(128),	\n"
" case ? when 1 then dv_to_sql_type3(c.COL_DTP) else dv_to_sql_type(c.COL_DTP) end AS DATA_TYPE SMALLINT,\n"
" case when (c.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (c.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(c.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */
" case when (c.COL_PREC = 0 and c.COL_DTP in (125, 132)) then " VARCHAR_UNSPEC_SIZE "  when (c.COL_PREC = 0 and c.COL_DTP = 225) then " VARCHAR_UNSPEC_SIZE " else c.COL_PREC end AS COLUMN_SIZE INTEGER,\n"
" c.COL_PREC AS BUFFER_LENGTH INTEGER,\n"
" c.COL_SCALE AS DECIMAL_DIGITS SMALLINT,\n"
" 2 AS NUM_PREC_RADIX SMALLINT,\n"
" case c.COL_NULLABLE when 1 then 0 else 1 end AS NULLABLE SMALLINT,\n"
" NULL AS REMARKS VARCHAR(254), \n"
" c.COL_DEFAULT AS COLUMN_DEF VARCHAR(254), \n"
" case ? when 1 then dv_to_sql_type3(c.COL_DTP) else dv_to_sql_type(c.COL_DTP) end AS SQL_DATA_TYPE SMALLINT,\n"
" case c.COL_DTP when 129 then 1 when 210 then 2 when 211 then 3 else NULL end AS SQL_DATETIME_SUB SMALLINT,\n"
" c.COL_PREC AS CHAR_OCTET_LENGTH INTEGER,\n"
" (select count(*) from DB.DBA.SYS_COLS where \\TABLE = k.KEY_TABLE and COL_ID <= c.COL_ID) AS ORDINAL_POSITION INTEGER,\n"
" case c.COL_NULLABLE when 1 then 'NO' else 'YES' end AS IS_NULLABLE INTEGER \n"
"from DB.DBA.SYS_KEYS k, DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS c \n"
"where name_part (k.KEY_TABLE,0) like ?\n"
" and __any_grants (KEY_TABLE)  "
"  and name_part (k.KEY_TABLE,1) like ?\n"
"  and name_part (k.KEY_TABLE,2) like ?\n"
"  and c.\"COLUMN\" like ?\n"
"  and c.\"COLUMN\" <> '_IDN' \n"
"  \n"
"  and k.KEY_IS_MAIN = 1\n"
"  and k.KEY_MIGRATE_TO is null\n"
"  and kp.KP_KEY_ID = k.KEY_ID\n"
"  and COL_ID = KP_COL\n"
"  \n"
"\n"
"order by KEY_TABLE, 17\n";


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
	SQLSMALLINT cbColumnName)
{
  STMT (stmt, hstmt);
  SQLLEN cbcol = cbColumnName;
  SQLLEN cbqual = cbTableQualifier, cbown = cbTableOwner, cbtab = cbTableName;
  SQLCHAR *percent = (SQLCHAR *) "%";
  SQLLEN plen = SQL_NTS;
  SQLRETURN rc;
  UDWORD isODBC3 = stmt->stmt_connection->con_environment->env_odbc_version >= 3;
  char _szTableQualifier[KUBL_IDENTIFIER_MAX_LENGTH],
      _szTableOwner[KUBL_IDENTIFIER_MAX_LENGTH],
      _szTableName[KUBL_IDENTIFIER_MAX_LENGTH], _szColumnName[KUBL_IDENTIFIER_MAX_LENGTH];

  if (is_empty (szTableQualifier, cbTableQualifier))
    {
      szTableQualifier = NULL;
      _szTableQualifier[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableQualifier, _szTableQualifier, sizeof (_szTableQualifier), &cbqual, cbTableQualifier);

  if (is_empty (szTableOwner, cbTableOwner))
    {
      szTableOwner = NULL;
      _szTableOwner[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableOwner, _szTableOwner, sizeof (_szTableOwner), &cbown, cbTableOwner);

  if (is_empty (szTableName, cbTableName))
    {
      szTableName = NULL;
      _szTableName[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableName, _szTableName, sizeof (_szTableName), &cbtab, cbTableName);

  if (is_empty (szColumnName, cbColumnName))
    {
      szColumnName = NULL;
      _szColumnName[0] = 0;
    }
  else
    remove_search_escapes ((char *) szColumnName, _szColumnName, sizeof (_szColumnName), &cbcol, cbColumnName);

  DEFAULT_QUAL (stmt, cbqual);

  virtodbc__SQLSetParam (hstmt, 1, SQL_C_ULONG, SQL_INTEGER, 0, 0, &isODBC3, NULL);
  virtodbc__SQLSetParam (hstmt, 2, SQL_C_ULONG, SQL_INTEGER, 0, 0, &isODBC3, NULL);
/*
  virtodbc__SQLSetParam (hstmt, 2, SQL_C_ULONG, SQL_INTEGER, 0, 0, &sizeof_wchar_t, NULL);
*/
  virtodbc__SQLSetParam (hstmt, 3, SQL_C_CHAR, SQL_CHAR, 0, 0, szTableQualifier ? (SQLCHAR *) _szTableQualifier : percent, szTableQualifier ? &cbqual : &plen);
  virtodbc__SQLSetParam (hstmt, 4, SQL_C_CHAR, SQL_CHAR, 0, 0, szTableOwner ? (SQLCHAR *) _szTableOwner : percent, szTableOwner ? &cbown : &plen);
  virtodbc__SQLSetParam (hstmt, 5, SQL_C_CHAR, SQL_CHAR, 0, 0, szTableName ? (SQLCHAR *) _szTableName : percent, szTableName ? &cbtab : &plen);
  virtodbc__SQLSetParam (hstmt, 6, SQL_C_CHAR, SQL_CHAR, 0, 0, szColumnName ? (SQLCHAR *) _szColumnName : percent, szColumnName ? &cbcol : &plen);

  if (stmt->stmt_connection->con_defs.cdef_utf8_execs)
    rc = virtodbc__SQLExecDirect (hstmt,
	(SQLCHAR *) (stmt->stmt_connection->con_db_casemode == 2 ?
	    sql_columnsw_text_casemode_2 : sql_columnsw_text_casemode_0), SQL_NTS);
  else
    rc = virtodbc__SQLExecDirect (hstmt,
	(SQLCHAR *) (stmt->stmt_connection->con_db_casemode == 2 ?
	    sql_columns_text_casemode_2 : sql_columns_text_casemode_0), SQL_NTS);
  /* With COL_ID returns columns in the same order as they were defined
     with create table. Without it they would be in alphabetical order. */

  virtodbc__SQLFreeStmt (hstmt, SQL_RESET_PARAMS);

  return rc;
}


SQLRETURN SQL_API
SQLColumns (
	SQLHSTMT hstmt,
	SQLCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * wszTableName,
	SQLSMALLINT cbTableName,
	SQLCHAR * wszColumnName,
	SQLSMALLINT cbColumnName)
{
  size_t len;
  SQLRETURN rc;
  STMT (stmt, hstmt);
  NDEFINE_INPUT_NARROW (TableQualifier);
  NDEFINE_INPUT_NARROW (TableOwner);
  NDEFINE_INPUT_NARROW (TableName);
  NDEFINE_INPUT_NARROW (ColumnName);

  NMAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableName, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (ColumnName, stmt->stmt_connection);

  rc = virtodbc__SQLColumns (hstmt,
      szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName, szColumnName, cbColumnName);

  NFREE_INPUT_NARROW (TableQualifier);
  NFREE_INPUT_NARROW (TableOwner);
  NFREE_INPUT_NARROW (TableName);
  NFREE_INPUT_NARROW (ColumnName);

  return rc;
}


/*
   An excerpt from the ODBC API help file:

   The szTableOwner and szTableName arguments accept search patterns. (YES)

   To support enumeration of qualifiers, owners, and table types, SQLTables
   defines the following special semantics for the szTableQualifier,
   szTableOwner, szTableName, and szTableType arguments:

   If szTableQualifier is a single percent character (%) and szTableOwner
   and szTableName are empty strings, then the result set contains a
   list of valid qualifiers for the data source. (All columns except
   the TABLE_QUALIFIER column contain NULLs.)

   If szTableOwner is a single percent character (%) and szTableQualifier
   and szTableName are empty strings, then the result set contains a
   list of valid owners for the data source. (All columns except the
   TABLE_OWNER column contain NULLs.)

   If szTableType is a single percent character (%) and szTableQualifier,
   szTableOwner, and szTableName are empty strings, then the result set
   contains a list of valid table types for the data source. (All
   columns except the TABLE_TYPE column contain NULLs.)

   (THE STUFF ABOVE IS NOW IMPLEMENTED, 12-APR-1997)

   If szTableType is not an empty string, it must contain a list of
   comma-separated, values for the types of interest; each value may be
   enclosed in single quotes (') or unquoted. For example, "'TABLE','VIEW'"
   or "TABLE, VIEW". If the data source does not support a specified table
   type, SQLTables does not return any results for that type.
   Table type identifier is one of the following: "TABLE", "VIEW",
   "SYSTEM TABLE", "GLOBAL TEMPORARY", "LOCAL TEMPORARY", "ALIAS", "SYNONYM"
   or a data source - specific type identifier.

   SQLTables returns the results as a standard result set, ordered by
   TABLE_TYPE, TABLE_QUALIFIER, TABLE_OWNER, and TABLE_NAME.
   The columns of the the result set are:
   TABLE_QUALIFIER (here always 'db'), TABLE_OWNER (here always 'dba'),
   TABLE_NAME, TABLE_TYPE (either 'SYSTEM TABLE' or 'TABLE'),
   REMARKS Varchar(254) A description of the table.

   Note: See the kludge for giving either a literal 'SYSTEM TABLE'
   or 'TABLE' in TABLE_TYPE column, depending whether the table name
   begins with letters 'SYS_', or not. All the three following clauses
   would work. The last one is used as it is the shortest.

   either(matches_like(KEY_TABLE,'SYS_%'),'SYSTEM TABLE','TABLE')
   subseq('SYSTEM TABLE',7*iszero(matches_like(KEY_TABLE,'SYS_%')),12)
   subseq('SYSTEM TABLE',7-7*matches_like(KEY_TABLE,'SYS_%'),12)

   Modified 25.Dec.1997 so that gets the qualifier and owner parts
   that may now occur in KEY_TABLE column of SYS_KEYS properly.
   Still supposes that the system-tables occur there without
   explicit DB.DBA. -prefix, and that users never create their own
   tables with a qualifier or the name beginning with letters SYS_
 */

char *sql_tables_text_casemode_0 =
"select"
" name_part(KEY_TABLE,0) AS \\TABLE_QUALIFIER VARCHAR(128),"
" name_part(KEY_TABLE,1) AS TABLE_OWNER VARCHAR(128),"
" name_part(KEY_TABLE,2) AS TABLE_NAME VARCHAR(128),"
" case when (table_type (KEY_TABLE) = 'SYSTEM TABLE' and ? <> 0) then 'TABLE' else table_type (KEY_TABLE) end AS \\TABLE_TYPE VARCHAR(128),"
" NULL AS \\REMARKS VARCHAR(254) "
"from DB.DBA.SYS_KEYS "
"where"
" __any_grants (KEY_TABLE) and "
" either (?, "
"      matches_like (name_part(KEY_TABLE,0), ?) "
"      , "
"      equ (name_part(KEY_TABLE,0), ?) "
" ) and"
" name_part(KEY_TABLE,1) like ? and"
" name_part(KEY_TABLE,2) like ? and"
" locate (concat ('G', case when (table_type (KEY_TABLE) = 'SYSTEM TABLE' and ? <> 0) then 'TABLE' else table_type (KEY_TABLE) end), ?) > 0 and"
" KEY_IS_MAIN = 1 and"
" KEY_MIGRATE_TO is NULL "
"order by KEY_TABLE";

char *sql_tables_text_casemode_2 =
"select"
" name_part(KEY_TABLE,0) AS \\TABLE_QUALIFIER VARCHAR(128),"
" name_part(KEY_TABLE,1) AS TABLE_OWNER VARCHAR(128),"
" name_part(KEY_TABLE,2) AS TABLE_NAME VARCHAR(128),"
" case when (table_type (KEY_TABLE) = 'SYSTEM TABLE' and ? <> 0) then 'TABLE' else table_type (KEY_TABLE) end AS \\TABLE_TYPE VARCHAR(128),"
" NULL AS \\REMARKS VARCHAR(254) "
"from DB.DBA.SYS_KEYS "
"where"
" __any_grants (KEY_TABLE) and "
" either (cast (? as integer), "
"      matches_like (upper(name_part(KEY_TABLE,0)), upper(?)) "
"    , "
"      equ (upper(name_part(KEY_TABLE,0)), upper (?)) "
" ) and"
" upper(name_part(KEY_TABLE,1)) like upper(?) and"
" upper(name_part(KEY_TABLE,2)) like upper(?) and"
" locate (concat ('G', case when (table_type (KEY_TABLE) = 'SYSTEM TABLE' and ? <> 0) then 'TABLE' else table_type (KEY_TABLE) end), ?) > 0 and"
" KEY_IS_MAIN = 1 and"
" KEY_MIGRATE_TO is NULL "
"order by KEY_TABLE";

char *sql_tables_textw_casemode_0 =
"select"
" charset_recode (name_part(KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_QUALIFIER NVARCHAR(128),"
" charset_recode (name_part(KEY_TABLE,1), 'UTF-8', '_WIDE_') AS TABLE_OWNER NVARCHAR(128),"
" charset_recode (name_part(KEY_TABLE,2), 'UTF-8', '_WIDE_') AS TABLE_NAME NVARCHAR(128),"
" case when (table_type (KEY_TABLE) = 'SYSTEM TABLE' and ? <> 0) then 'TABLE' else table_type (KEY_TABLE) end AS \\TABLE_TYPE VARCHAR(128),"
" NULL AS \\REMARKS VARCHAR(254) "
"from DB.DBA.SYS_KEYS "
"where"
" __any_grants (KEY_TABLE) and "
" either (?, "
"      matches_like (name_part(KEY_TABLE,0), ?) "
"      , "
"      equ (name_part(KEY_TABLE,0), ?) "
" ) and"
" name_part(KEY_TABLE,1) like ? and"
" name_part(KEY_TABLE,2) like ? and"
" locate (concat ('G', case when (table_type (KEY_TABLE) = 'SYSTEM TABLE' and ? <> 0) then 'TABLE' else table_type (KEY_TABLE) end), ?) > 0 and"
" KEY_IS_MAIN = 1 and"
" KEY_MIGRATE_TO is NULL "
"order by KEY_TABLE";

char *sql_tables_textw_casemode_2 =
"select"
" charset_recode (name_part(KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_QUALIFIER NVARCHAR(128),"
" charset_recode (name_part(KEY_TABLE,1), 'UTF-8', '_WIDE_') AS TABLE_OWNER NVARCHAR(128),"
" charset_recode (name_part(KEY_TABLE,2), 'UTF-8', '_WIDE_') AS TABLE_NAME NVARCHAR(128),"
" case when (table_type (KEY_TABLE) = 'SYSTEM TABLE' and ? <> 0) then 'TABLE' else table_type (KEY_TABLE) end AS \\TABLE_TYPE VARCHAR(128),"
" NULL AS \\REMARKS VARCHAR(254) "
"from DB.DBA.SYS_KEYS "
"where"
" __any_grants (KEY_TABLE) and "
" either (cast (? as integer), "
"      matches_like (charset_recode (upper(charset_recode (name_part(KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8'), charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')) "
"    , "
"      equ (upper(name_part(KEY_TABLE,0)), upper (?)) "
" ) and"
" charset_recode (upper(charset_recode (name_part(KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') and"
" charset_recode (upper(charset_recode (name_part(KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') and"
" locate (concat ('G', case when (table_type (KEY_TABLE) = 'SYSTEM TABLE' and ? <> 0) then 'TABLE' else table_type (KEY_TABLE) end), ?) > 0 and"
" KEY_IS_MAIN = 1 and"
" KEY_MIGRATE_TO is NULL "
"order by KEY_TABLE";


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
	SQLSMALLINT cbTableType)
{
  STMT (stmt, hstmt);
  SQLLEN cbqual = cbTableQualifier, cbown = cbTableOwner, cbtab = cbTableName;
  SQLRETURN rc;
  SQLLEN cbtype = cbTableType;
  /*int maxtyplen; */
  SQLCHAR *percent = (SQLCHAR *) "%";
  SDWORD odbc_ver = stmt->stmt_connection->con_environment->env_odbc_version >= 3 ? 1 : 0;
  SQLLEN odbc_ver_len = 4;
  SDWORD no_sys_tbs = stmt->stmt_connection->con_no_system_tables ? 1 : 0;
  SQLLEN no_sys_tbs_len = 4;
  SDWORD views_as_tables = stmt->stmt_connection->con_treat_views_as_tables ? 1 : 0;
  char type_buffer[60], *type_ptr;

  /*  SQLCHAR *nada = (SQLCHAR *) ""; *//* KEY_TABLE not like nada should match with all */
  SQLLEN plen = SQL_NTS;
/*  int only_system_tables = 0, only_users_tables = 0;*/
  int QualEmpty = is_empty (szTableQualifier, cbTableQualifier);
  int OwnEmpty = is_empty (szTableOwner, cbTableOwner);
  int TabEmpty = is_empty (szTableName, cbTableName);

  /*SQLCHAR *ptr1, *ptr2, *tab_typ_ptr; */
  SQLCHAR _szTableQualifier[KUBL_IDENTIFIER_MAX_LENGTH],
      _szTableOwner[KUBL_IDENTIFIER_MAX_LENGTH], _szTableName[KUBL_IDENTIFIER_MAX_LENGTH], _szTableType[KUBL_IDENTIFIER_MAX_LENGTH];

  if (QualEmpty)
    {
      szTableQualifier = NULL;
      _szTableQualifier[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableQualifier,
	(char *) _szTableQualifier, sizeof (_szTableQualifier), &cbqual, cbTableQualifier);

  if (OwnEmpty)
    {
      szTableOwner = NULL;
      _szTableOwner[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableOwner, (char *) _szTableOwner, sizeof (_szTableOwner), &cbown, cbTableOwner);

  if (TabEmpty)
    {
      szTableName = NULL;
      _szTableName[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableName, (char *) _szTableName, sizeof (_szTableName), &cbtab, cbTableName);

  if (is_empty (szTableType, cbTableType))
    {
      szTableType = NULL;
      _szTableType[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableType, (char *) _szTableType, sizeof (_szTableType), &cbtype, cbTableType);

  if (is_percent (szTableQualifier, _szTableQualifier, cbTableQualifier) && OwnEmpty && TabEmpty)
    {
      /* Show valid table qualifiers, e.g. often just 'DB' */
      if (stmt->stmt_connection->con_defs.cdef_utf8_execs)
	rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	    "select"
	    " distinct charset_recode (name_part(KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_QUALIFIER NVARCHAR(128),"
	    " NULL AS \\TABLE_OWNER VARCHAR(128),"
	    " NULL AS \\TABLE_NAME VARCHAR(128),"
	    " NULL AS \\TABLE_TYPE VARCHAR(128),"
	    " NULL AS \\REMARKS VARCHAR(254) "
	    "from DB.DBA.SYS_KEYS", SQL_NTS);
      else
	rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	    "select"
	    " distinct name_part(KEY_TABLE,0) AS \\TABLE_QUALIFIER VARCHAR(128),"
	    " NULL AS \\TABLE_OWNER VARCHAR(128),"
	    " NULL AS \\TABLE_NAME VARCHAR(128),"
	    " NULL AS \\TABLE_TYPE VARCHAR(128),"
	    " NULL AS \\REMARKS VARCHAR(254) "
	    "from DB.DBA.SYS_KEYS", SQL_NTS);
    }
  else if (is_percent (szTableOwner, _szTableOwner, cbTableOwner) && QualEmpty && TabEmpty)
    {
      /* Show valid table owners, e.g. often just 'DBA' */
      if (stmt->stmt_connection->con_defs.cdef_utf8_execs)
	rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	    "select distinct"
	    " NULL AS \\TABLE_QUALIFIER VARCHAR(128),"
	    " charset_recode (name_part(KEY_TABLE, 1), 'UTF-8', '_WIDE_') AS \\TABLE_OWNER NVARCHAR(128),"
	    " NULL AS \\TABLE_NAME VARCHAR(128),"
	    " NULL AS \\TABLE_TYPE VARCHAR(128),"
	    " NULL AS \\REMARKS VARCHAR(254) "
	    "from DB.DBA.SYS_KEYS", SQL_NTS);
      else
	rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	    "select distinct"
	    " NULL AS \\TABLE_QUALIFIER VARCHAR(128),"
	    " name_part(KEY_TABLE, 1) AS \\TABLE_OWNER VARCHAR(128),"
	    " NULL AS \\TABLE_NAME VARCHAR(128),"
	    " NULL AS \\TABLE_TYPE VARCHAR(128),"
	    " NULL AS \\REMARKS VARCHAR(254) "
	    "from DB.DBA.SYS_KEYS", SQL_NTS);
    }
  else if (is_percent (szTableType, _szTableType, cbTableType) && QualEmpty && OwnEmpty && TabEmpty)
    {
      /* Show valid table types, i.e. 'SYSTEM TABLE' and 'TABLE' */
      /* There are certainly always a table named SYS_USERS in SYS_KEYS,
         as well as some other system table with a different name, so the
         kludge below will produce two lines, one with SYSTEM TABLE
         and one just with TABLE in the fourth (TABLE_TYPE) column. */
      rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	  "select distinct"
	  " NULL AS \\TABLE_QUALIFIER VARCHAR(128),"
	  " NULL AS \\TABLE_OWNER VARCHAR(128),"
	  " NULL AS \\TABLE_NAME VARCHAR(128),"
	  " table_type (KEY_TABLE)"
	  "   AS \\TABLE_TYPE VARCHAR(128),"
	  " NULL AS \\REMARKS VARCHAR(254) "
	  "from DB.DBA.SYS_KEYS", SQL_NTS);
    }
  else
    {
      /* Normal case, i.e. the client really wants to see the tables */
      if (cbqual == 0)
	szTableQualifier = NULL;

      if (cbown == 0)
	szTableOwner = NULL;

      if (cbtab == 0)
	szTableName = NULL;

      if (szTableName && 0 == strlen ((char *) _szTableName))
	szTableName = NULL;

      if (SQL_NTS == cbtype)
	{
	  if (szTableType)
	    cbtype = strlen ((char *) _szTableType);
	}
      else if (cbtype <= 0)	/* SQL_NULL_DATA (-1),  SQL_DATA_AT_EXEC (-2) */
	{
	  szTableType = NULL;
	}			/* Or simply zero (an empty string). */

/* Added by AK, 17-JAN-1997: Very rude checking of szTableType argument,
   just checking whether it contains types "SYSTEM TABLE", or "TABLE",
   and then act accordingly.
   12-APR-1997 AK Changed strstr to our own function strncasestr
   defined in cliuti.c, using also the third argument, max. chars cbtype
   so it should work now also with strings that are not zero-terminated.
 */
      type_ptr = (char *) szTableType;
      if (szTableType)
	{
#if 0
	  /* Actually it should be "SYSTEM TABLE" but we are tolerant. */
	  if ((ptr1 = strncasestr (_szTableType, (SQLCHAR *) "SYSTEM", cbtype)))
	    {
	      only_system_tables = 1;
	    }

	  for (tab_typ_ptr = _szTableType, maxtyplen = cbtype;;)
	    {
	      if ((ptr2 = strncasestr (tab_typ_ptr, (SQLCHAR *) "TABLE", maxtyplen)))
		{
		  /* Check also that it is not part of "SYSTEM TABLE", i.e.
		     either "TABLE" is in the beginning, or it's not preceded
		     by a space or alphanumeric character. (E.g. "HYPERTABLE" ?)
		   */
		  if ((ptr2 == _szTableType) || ((*(ptr2 - 1) != ' ') && !isalnum (*(ptr2 - 1))))
		    {
		      /* If there are both SYSTEM TABLES and TABLES given in
		       * the szTableType then clear both flags to zero, with
		       * the same effect as if szTableType wouldn't have been
		       * specified at all:
		       */
		      if (0 == only_system_tables)
			{
			  only_users_tables = 1;
			}
		      else
			{
			  only_system_tables = 0;
			}
		      break;
		    }
		  else
		    /* we found the "TABLE", as a part of "SYSTEM TABLE" */
		    {		/* Loop back to search for the real ,TABLE */
		      tab_typ_ptr = (ptr2 + 1);
		      maxtyplen = (cbtype - (tab_typ_ptr - szTableType));
		    }
		}
	      else
		break;		/* TABLE not found, break from the loop */
	    }
#else
	  unsigned char *szTypes = szTableType, *szComma, *szEnd, token_buffer[20];
	  int do_tables = 0, do_views = 0, do_system = 0;

	  type_buffer[0] = 0;
	  type_ptr = type_buffer;
	  while (szTypes - szTableType < cbtype)
	    {
	      /* skip the white space */
	      while (szTypes - szTableType < cbtype && isspace (*szTypes))
		szTypes++;

	      /* skip the leading quote */
	      if (szTypes - szTableType < cbtype && *szTypes == '\'')
		szTypes++;

	      /* find the comma */
	      szComma = (unsigned char *) strchr ((const char *) szTypes, ',');

	      szEnd = szComma ? szComma + 1 : szTableType + cbtype;

	      /* end of string is considered comma */
	      if (!szComma)
		szComma = szTableType + cbtype - 1;
	      else
		szComma--;

	      /* skip the trailing space */
	      while (szComma > szTypes && isspace (*szComma))
		szComma--;

	      /* skip the trailing quote */
	      if (szComma - szTableType < cbtype && *szComma == '\'')
		szComma--;

	      memset (token_buffer, 0, sizeof (token_buffer));
	      memcpy (token_buffer, szTypes, MIN (szComma - szTypes + 1, sizeof (token_buffer) - 1));

	      if (!stricmp ((const char *) token_buffer, "TABLE"))
		do_tables = 1;
	      else if (!stricmp ((const char *) token_buffer, "VIEW"))
		do_views = 1;
	      else if (!stricmp ((const char *) token_buffer, "SYSTEM TABLE"))
		do_system = 1;
	      szTypes = szEnd;
	    }
	  if (do_tables)
	    strcat_ck (type_buffer, "GTABLE");
	  if (do_views || (do_tables && views_as_tables))
	    strcat_ck (type_buffer, "GVIEW");
	  if (do_system)
	    strcat_ck (type_buffer, "GSYSTEM TABLE");
#endif
	}
      else
	type_ptr = "GTABLEGVIEWGSYSTEM TABLE";

      DEFAULT_QUAL (stmt, cbqual);

/* this param is whether to threat system tables as user ones */
      virtodbc__SQLSetParam (hstmt, 1, SQL_C_LONG, SQL_INTEGER, 0, 0, &no_sys_tbs, &no_sys_tbs_len);

      virtodbc__SQLSetParam (hstmt, 2, SQL_C_LONG, SQL_INTEGER, 0, 0, &odbc_ver, &odbc_ver_len);

      virtodbc__SQLSetParam (hstmt, 3, SQL_C_CHAR, SQL_CHAR, 0, 0, (szTableQualifier || odbc_ver == 2 ? (SQLCHAR *) _szTableQualifier : percent), (szTableQualifier || odbc_ver == 2 ? &cbqual : &plen));

      virtodbc__SQLSetParam (hstmt, 4, SQL_C_CHAR, SQL_CHAR, 0, 0, (szTableQualifier || odbc_ver == 2 ? (SQLCHAR *) _szTableQualifier : percent), (szTableQualifier || odbc_ver == 2 ? &cbqual : &plen));


/* The second parameter is the pattern the user himself gave in
   szTableOwner, or just a single percent if the szTableOwner was NULL: */
      virtodbc__SQLSetParam (hstmt, 5, SQL_C_CHAR, SQL_CHAR, 0, 0, (szTableOwner ? (SQLCHAR *) _szTableOwner : percent), (szTableOwner ? &cbown : &plen));

/* The third parameter is the pattern the user himself gave in szTableName,
   or just a single percent if the szTableName was NULL: */
      virtodbc__SQLSetParam (hstmt, 6, SQL_C_CHAR, SQL_CHAR, 0, 0, (szTableName ? (SQLCHAR *) _szTableName : percent), (szTableName ? &cbtab : &plen));

/* this param is whether to threat system tables as user ones */
      virtodbc__SQLSetParam (hstmt, 7, SQL_C_LONG, SQL_INTEGER, 0, 0, &no_sys_tbs, &no_sys_tbs_len);

/* The fourth parameter is for catching only system tables in case that
   the user has given "SYSTEM TABLE" spec in szTableType (but no "TABLE")
   (he still might have used some szTableName pattern like %E%, specifying
   all the tables whose name contain a letter 'E', so although in
   principle we could concatenate these to form the prefix SYS_%E%
   in practice it is easier to use three parameters.)
   It is supposed that the system table are not prefixed with the
   explicit DB.DBA. prefix.
 */
      virtodbc__SQLSetParam (hstmt, 8, SQL_C_CHAR, SQL_CHAR, 0, 0, type_ptr, &plen);

#if 0
/* The fifth parameter is for "KEY_TABLE not like ?" which is used
   to get rid off the system tables, in the case that user wants only
   ordinary tables.
   Expression KEY_TABLE not like '' should match with all table names! */

      virtodbc__SQLSetParam (hstmt, 5, SQL_C_CHAR, SQL_CHAR, 0, 0, (only_users_tables ? sys_table_prefix : nada), &plen);
#endif

      if (stmt->stmt_connection->con_defs.cdef_utf8_execs)
	rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	    (stmt->stmt_connection->con_db_casemode == 2 ? sql_tables_textw_casemode_2 : sql_tables_textw_casemode_0), SQL_NTS);
      else
	rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	    (stmt->stmt_connection->con_db_casemode == 2 ? sql_tables_text_casemode_2 : sql_tables_text_casemode_0), SQL_NTS);

/* Should actually be, but Kubl does not currently allow expressions in
   order by: (by TABLE_TYPE, TABLE_QUALIFIER, TABLE_OWNER and TABLE_NAME)
   "order by "
   "subseq('SYSTEM TABLE',7-7*matches_like(KEY_TABLE,'" SYS_TABLE_PREFIX "'))"
   "name_part(KEY_TABLE,0),name_part(KEY_TABLE,1),name_part(KEY_TABLE,2)"
 */
      virtodbc__SQLFreeStmt (hstmt, SQL_RESET_PARAMS);
    }

  return rc;
}


SQLRETURN SQL_API
SQLTables (
	SQLHSTMT hstmt,
	SQLCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * wszTableName,
	SQLSMALLINT cbTableName,
	SQLCHAR * wszTableType,
	SQLSMALLINT cbTableType)
{
  SQLRETURN rc;
  size_t len;
  STMT (stmt, hstmt);
  NDEFINE_INPUT_NARROW (TableQualifier);
  NDEFINE_INPUT_NARROW (TableOwner);
  NDEFINE_INPUT_NARROW (TableName);
  NDEFINE_INPUT_NARROW (TableType);

  NMAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableName, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableType, stmt->stmt_connection);

  rc = virtodbc__SQLTables (hstmt,
      szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName, szTableType, cbTableType);

  NFREE_INPUT_NARROW (TableQualifier);
  NFREE_INPUT_NARROW (TableOwner);
  NFREE_INPUT_NARROW (TableName);
  NFREE_INPUT_NARROW (TableType);

  return rc;
}


SQLRETURN SQL_API SQLDataSources (
	SQLHENV henv,
	SQLUSMALLINT fDirection,
	SQLCHAR * szDSN,
	SQLSMALLINT cbDSNMax,
	SQLSMALLINT * pcbDSN,
	SQLCHAR * szDescription,
	SQLSMALLINT cbDescriptionMax,
	SQLSMALLINT * pcbDescription)
{
  NOT_IMPL_FUN (henv, "Function not supported: SQLDataSources");
}


SQLRETURN SQL_API
SQLDescribeParam (
	SQLHSTMT hstmt,
	SQLUSMALLINT ipar,
	SQLSMALLINT * pfSqlType,
	SQLULEN * pcbColDef,
	SQLSMALLINT * pibScale,
	SQLSMALLINT * pfNullable)
{
  STMT (stmt, hstmt);
  stmt_compilation_t *sc = stmt->stmt_compilation;

  if (BOX_ELEMENTS (sc) > 3 && sc->sc_params)
    {
      param_desc_t **pds = (param_desc_t **) sc->sc_params;
      param_desc_t *pd;

      if (BOX_ELEMENTS (pds) < ipar)
	{
	  set_error (&stmt->stmt_error, "07009", "CL044", "Bad parameter index in SQLDescribeParam");

	  return SQL_ERROR;
	}

      pd = pds[ipar - 1];

      if (pfSqlType)
	{
	  ENV (env, stmt->stmt_connection->con_environment);

	  *pfSqlType = dv_to_sql_type ((dtp_t) unbox (pd->pd_dtp), stmt->stmt_connection->con_defs.cdef_binary_timestamp);

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

      if (pcbColDef)
	*pcbColDef = unbox (pd->pd_prec);

      if (pibScale)
	*pibScale = (SQLSMALLINT) unbox (pd->pd_scale);

      if (pfNullable)
	*pfNullable = unbox (pd->pd_nullable) ? SQL_NULLABLE : SQL_NO_NULLS;

      return SQL_SUCCESS;
    }

  NOT_IMPL_FUN (hstmt, "SQLDescribeParam: BOX_ELEMENTS (sc) <= 3 or no sc_params");
}


SQLRETURN SQL_API
SQLGetConnectOption (
	SQLHDBC hdbc,
	SQLUSMALLINT fOption,
	SQLPOINTER pvParam)
{
  CON (con, hdbc);
  SQLRETURN rc;

  switch (fOption)
    {
    case SQL_ATTR_CURRENT_CATALOG:
    case SQL_ATTR_TRACEFILE:
    case SQL_ATTR_TRANSLATE_LIB:
      {
	SQLINTEGER StrLen = 512, pl = 512, *StrLenPtr = &pl;

	NDEFINE_OUTPUT_NONCHAR_NARROW (pvParam, StrLen, StrLenPtr, con, SQLINTEGER);
	NMAKE_OUTPUT_NONCHAR_NARROW_ALLOC (pvParam, StrLen, con);
	rc = virtodbc__SQLGetConnectOption (hdbc, fOption, _pvParam, _StrLen, _StrLenPtr);
	NSET_AND_FREE_OUTPUT_NONCHAR_NARROW_FREE (pvParam, StrLen, StrLenPtr, con);
	return rc;
      }

    default:
      return virtodbc__SQLGetConnectOption (hdbc, fOption, pvParam, 65536, NULL);
    }
}


SQLRETURN SQL_API
virtodbc__SQLGetConnectOption (
	SQLHDBC hdbc,
	SQLUSMALLINT fOption,
	SQLPOINTER pvParam,
	SQLINTEGER StringLength,
	UNALIGNED SQLINTEGER * StringLengthPtr)
{
  CON (con, hdbc);
  SQLRETURN rc = SQL_SUCCESS;

  switch (fOption)
    {
    case SQL_AUTOCOMMIT:
      if (pvParam)
	*(SQLLEN *) pvParam = con->con_autocommit;
      break;
    case SQL_TXN_ISOLATION:
      if (pvParam)
	*(SQLLEN *) pvParam = con->con_isolation;
      break;

    case SQL_ACCESS_MODE:
      if (pvParam)
	*(SQLLEN *) pvParam = con->con_access_mode;
      break;

    case SQL_CURRENT_QUALIFIER:
      V_SET_ODBC_STR (con->con_qualifier, pvParam, StringLength, StringLengthPtr, &con->con_error);
      break;

    case SQL_NO_CHAR_C_ESCAPE:
      if (pvParam)
	*(SQLSMALLINT *) pvParam = (SQLSMALLINT) con->con_defs.cdef_no_char_c_escape;
      break;

    case SQL_CHARSET:
      {
	char *chrs_name = "";
	if (CON_CONNECTED (con))
	  {
	    if (con->con_charset->chrs_name)
	      chrs_name = con->con_charset->chrs_name;
	  }
	else
	  chrs_name = (char *) con->con_charset;
	V_SET_ODBC_STR (chrs_name, pvParam, StringLength, StringLengthPtr, &con->con_error);
      }
      break;

    case SQL_APPLICATION_NAME:
      V_SET_ODBC_STR (application_name, pvParam, StringLength, StringLengthPtr, &con->con_error);
      break;

    case SQL_ENCRYPT_CONNECTION:
      V_SET_ODBC_STR (((char *) con->con_encrypt), pvParam, StringLength, StringLengthPtr, &con->con_error);
      break;

    case SQL_SERVER_CERT:
      V_SET_ODBC_STR (((char *) con->con_ca_list), pvParam, StringLength, StringLengthPtr, &con->con_error);
      break;

    case SQL_PWD_CLEARTEXT:
      if (pvParam)
	*(SQLSMALLINT *) pvParam = (SQLSMALLINT) con->con_pwd_cleartext;
      break;

    case SQL_INPROCESS_CLIENT:
      if (pvParam)
	{
#ifdef INPROCESS_CLIENT
	  *(SQLSMALLINT *) pvParam = (SQLSMALLINT) SESSION_IS_INPROCESS (con->con_session);
#else
	  *(SQLSMALLINT *) pvParam = (SQLSMALLINT) 0;
#endif
	}
      break;
    }

  return rc;
}


SQLRETURN SQL_API
SQLSetConnectOption (
      SQLHDBC hdbc,
      SQLUSMALLINT fOption,
      SQLULEN vParam)
{
  CON (con, hdbc);
  switch (fOption)
    {
    case SQL_CURRENT_QUALIFIER:
      {
	SQLRETURN rc;
	SQLLEN StringLength = SQL_NTS;
	NDEFINE_INPUT_NONCHAR_NARROW (vParam, StringLength);

	NMAKE_INPUT_NONCHAR_NARROW (vParam, StringLength, con);

	rc = virtodbc__SQLSetConnectOption (hdbc, fOption, (SQLULEN) _vParam);

	NFREE_INPUT_NONCHAR_NARROW (vParam, StringLength);
	return rc;
      }

    default:
      return virtodbc__SQLSetConnectOption (hdbc, fOption, vParam);
    }
}


SQLRETURN SQL_API
virtodbc__SQLSetConnectOption (
      SQLHDBC hdbc,
      SQLUSMALLINT fOption,
      SQLULEN vParam)
{
  CON (con, hdbc);
#ifdef VIRTTP
  SQLUSMALLINT op = 0;
#endif

  cli_dbg_printf (("SQLSetConnectOption (%ld, %d, %d)\n", con, fOption, vParam));

  VERIFY_INPROCESS_CLIENT (con);

  switch (fOption)
    {
    case SQL_AUTOCOMMIT:
      if (!con->con_autocommit && vParam && con->con_in_transaction)
	virtodbc__SQLTransact (SQL_NULL_HENV, hdbc, SQL_COMMIT);
      con->con_autocommit = (int) vParam;
      break;

    case SQL_TXN_ISOLATION:
      con->con_isolation = (int) vParam;
      break;

    case SQL_ACCESS_MODE:
      con->con_access_mode = (int) vParam;
      break;

    case SQL_CURRENT_QUALIFIER:
      if (CON_CONNECTED (con))
	{
	  if (con->con_qualifier && vParam && strcmp ((const char *) con->con_qualifier, (char *) vParam))
	    {
	      SQLHSTMT stmt;
	      SQLRETURN rc = virtodbc__SQLAllocStmt (hdbc, &stmt);

	      if (SQL_SUCCESS != rc)
		return rc;

	      rc = virtodbc__SQLBindParameter (stmt, 1, SQL_PARAM_INPUT,
		  SQL_C_CHAR, SQL_CHAR, 0, 0, (char *) vParam, SQL_NTS, NULL);

	      if (SQL_SUCCESS == rc)
		rc = virtodbc__SQLExecDirect (stmt, (SQLCHAR *) "set_qualifier(?)", SQL_NTS);

	      virtodbc__SQLFreeStmt (stmt, SQL_DROP);

	      return rc;
	    }
	}
      else
	{
	  if (con->con_qualifier)
	    dk_free_box ((box_t) con->con_qualifier);

	  con->con_qualifier = vParam ? (SQLCHAR *) box_string ((char *) vParam) : NULL;
	}
      break;

    case SQL_NO_CHAR_C_ESCAPE:
      if (CON_CONNECTED (con))
	{
	  SQLHSTMT stmt;
	  SQLRETURN rc = virtodbc__SQLAllocStmt (hdbc, &stmt);

	  if (SQL_SUCCESS != rc)
	    return rc;

	  con->con_defs.cdef_no_char_c_escape = ((int) vParam) != 0;

	  rc = virtodbc__SQLExecDirect (stmt,
	      (SQLCHAR *) (((int) vParam) ? "set NO_CHAR_C_ESCAPE ON" : "set NO_CHAR_C_ESCAPE OFF"), SQL_NTS);

	  virtodbc__SQLFreeStmt (stmt, SQL_DROP);

	  return rc;
	}
      else
	goto nc;
      break;

    case SQL_CHARSET:
      if (CON_CONNECTED (con))
	{
	  SQLHSTMT stmt;
	  SQLRETURN rc = virtodbc__SQLAllocStmt (hdbc, &stmt);
	  wchar_t charset_table[256];
	  char szCharsetName[50];
	  SQLLEN nCharsetLen;

	  if (SQL_SUCCESS != rc)
	    return rc;

	  if (vParam)
	    {
	      int i;

	      for (i = 0; i < 49 && ((char *) vParam)[i]; i++)
		((char *) charset_table)[i] = szCharsetName[i] = toupper (((char *) vParam)[i]);

	      ((char *) charset_table)[i] = szCharsetName[i] = 0;
	      nCharsetLen = i;
	    }
	  else
	    {
	      szCharsetName[0] = 0;
	      charset_table[0] = 0;
	      nCharsetLen = SQL_NULL_DATA;
	    }

	  rc = virtodbc__SQLBindParameter (stmt, 1, SQL_PARAM_INPUT_OUTPUT,
	      SQL_C_CHAR, SQL_CHAR, 0, 0, (char *) charset_table, sizeof (charset_table), &nCharsetLen);

	  if (rc == SQL_SUCCESS)
	    rc = virtodbc__SQLExecDirect (stmt, (SQLCHAR *) "__set ('CHARSET', ?)", SQL_NTS);

	  if (rc == SQL_SUCCESS && nCharsetLen > 0)
	    {
	      if (con->con_charset)
		wide_charset_free (con->con_charset);

	      con->con_charset = wide_charset_create (szCharsetName,
		  (wchar_t *) charset_table, (int) (nCharsetLen - 1 / sizeof (wchar_t)), NULL);
	    }

	  virtodbc__SQLFreeStmt (stmt, SQL_DROP);

	  return rc;
	}
      else
	{
	  if (con->con_charset)
	    dk_free_box ((box_t) con->con_charset);

	  con->con_charset = vParam ? (wcharset_t *) box_string ((char *) vParam) : NULL;
	}
      break;

    case SQL_APPLICATION_NAME:
      {
	memset (application_name, 0, sizeof (application_name));

	if (vParam && ((char *) vParam)[0])
	  strncpy (application_name, (char *) vParam, sizeof (application_name) - 1);

	return SQL_SUCCESS;
      }

#ifdef VIRTTP
#undef dbg_printf
#define dbg_printf(a) printf a
    case SQL_ENLIST_IN_VIRTTP:
      if (CON_CONNECTED (con))
	{
#if 0
	  int found = 0;
	  DO_SET (d_trx_info_t *, info, &d_trx_set)
	  {
	    if (unbox ((box_t) vParam) == unbox (info->d_trx_id))
	      {
		dk_set_push (&info->d_trx_hdbcs, (void *) hdbc);
		con->con_d_trx_id = box_num (unbox ((box_t) vParam));
		found = 1;
	      }
	  }
	  END_DO_SET ();
	  if (!found)
	    {
	      NEW_VARZ (d_trx_info_t, info);
	      info->d_trx_id = box_num (unbox ((box_t) vParam));
	      dk_set_push (&info->d_trx_hdbcs, (void *) hdbc);
	      dk_set_push (&d_trx_set, info);
	      con->con_d_trx_id = box_num (unbox ((box_t) vParam));
	    }
#else
	  virt_rcon_t *vbranch = (virt_rcon_t *) vParam;
	  SQLHSTMT stmt;
	  SQLRETURN rc;

	  if (!vbranch || !vbranch->vtr_trx)
	    {
	      return SQL_ERROR;
	    }

	  rc = virtodbc__SQLAllocStmt (hdbc, &stmt);

	  if (SQL_SUCCESS != rc)
	    return rc;

	  rc = virtodbc__SQLBindParameter (stmt, 1, SQL_PARAM_INPUT,
	      SQL_C_CHAR, SQL_CHAR, 0, 0, (char *) vbranch->vtr_trx->vtx_cookie, SQL_NTS, NULL);

	  if (SQL_SUCCESS == rc)
	    rc = virtodbc__SQLExecDirect (stmt, (SQLCHAR *) "_2PC.DBA.virt_tp_enlist_branch (?)", SQL_NTS);

	  virtodbc__SQLFreeStmt (stmt, SQL_DROP);

	  return rc;
#endif
	}
      else
	goto nc;
      break;

    case SQL_VIRTTP_ABORT:
      op = SQL_TP_ABORT;

    case SQL_VIRTTP_COMMIT:
      if (CON_CONNECTED (con))
	{
	  s_node_t *iter, *nxt;
	  tp_dtrx_t *tpd = (tp_dtrx_t *) vParam;
	  d_trx_info_t *trx_i = 0;
	  int fail_pos = -1;
	  int i;
	  SQLRETURN rc = SQL_SUCCESS;

	  if (SQL_TP_ABORT != op)
	    op = SQL_TP_PREPARE;

	  DO_SET (d_trx_info_t *, info, &d_trx_set)
	  {
	    if (unbox (tpd->dtrx_info) == unbox (info->d_trx_id))
	      {
		trx_i = info;
		dbg_printf (("found transaction %ld\n", (long) dk_set_length (trx_i->d_trx_hdbcs)));
		break;
	      }
	  }
	  END_DO_SET ();

	  if (!trx_i)
	    return SQL_ERROR;

	again:
	  i = 0;

	  DO_SET_WRITABLE2 (cli_connection_t *, cli_con, iter, nxt, &trx_i->d_trx_hdbcs)
	  {
	    if (i != fail_pos)
	      {
		caddr_t res;
		future_t *f;

		dbg_printf (("sql_tp_transact... %x", op));
		f = PrpcFuture (cli_con->con_session, &s_sql_tp_transact, (short) op, 0);
		res = PrpcFutureNextResult (f);
		PrpcFutureFree (f);

		if (res != (caddr_t) SQL_SUCCESS)
		  {
		    dbg_printf (("commit failed %p\n", res));
		    rc = 1;

		    if (SQL_TP_PREPARE == op)
		      {
			op = SQL_TP_ABORT;
			fail_pos = i;

			goto again;
		      }
		    else
		      {
			iter = nxt;

			continue;
		      }
		  }
		else
		  dbg_printf ((" done\n"));
	      }
	    i++;
	    if (i > 10)
	      GPF_T;
	  }
	  END_DO_SET ();

	  if ((-1 == fail_pos) && (SQL_TP_PREPARE == op))
	    {
	      op = SQL_TP_COMMIT;
	      goto again;
	    }

	  dk_set_delete (&d_trx_set, (void *) trx_i);
	  dk_set_free (trx_i->d_trx_hdbcs);
	  dk_free_box (trx_i->d_trx_id);
	  dk_free (trx_i, sizeof (d_trx_info_t));

	  return rc;
	}
      else
	goto nc;
      break;

#undef dbg_printf
#define dbg_printf(a)
#endif
      /* MTS support block begin */
    case SQL_COPT_SS_ENLIST_IN_DTC:
#ifdef VIRTTP
#ifdef WIN32
      if (!MSDTC_IS_LOADED)
	return SQL_ERROR;

      if (CON_CONNECTED (con))
	{
	  SQLRETURN rc;
	  if (!vParam)
	    {
	      caddr_t *res;
	      future_t *future;

	      future = PrpcFuture (con->con_session, &s_sql_tp_transact, SQL_TP_UNENLIST, 0);
	      res = (caddr_t *) PrpcFutureNextResult (future);
	      PrpcFutureFree (future);

	      if (DKSESSTAT_ISSET (con->con_session, SST_BROKEN_CONNECTION))
		{
		  PrpcFutureFree (future);
		  set_error (&con->con_error, "08S01", "CL045", "Lost connection to server");
		  return SQL_ERROR;
		}

	      if (res == (caddr_t *) SQL_SUCCESS)
		{
		  return SQL_SUCCESS;
		}
	      else
		{
		  caddr_t srv_msg = cli_box_server_msg (res[2]);
		  set_error (&con->con_error, res[1], NULL, srv_msg);
		  dk_free_tree ((caddr_t) res);
		  dk_free_box (srv_msg);

		  return SQL_ERROR;
		}
	    }
	  else
	    {
	      caddr_t cookie = 0;
	      unsigned long cookie_len = 0;

	      if (con->con_autocommit)
		{
		  if (dk_set_length (con->con_statements) < 1)
		    {
		      rc = virtodbc__SQLTransact (SQL_NULL_HENV, hdbc, SQL_ROLLBACK);
		      if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
			return rc;

		      con->con_autocommit = 0;
		    }
		  else
		    {
		      set_error (&con->con_error, "42000", "CL094", "Not possible to enlist an AUTOCOMMIT connection in MS DTC");
		      return SQL_ERROR;
		    }
		}

	      mts_get_trx_cookie (con, (struct ITransaction *) vParam, (void **) &cookie, &cookie_len);

	      if (cookie)
		{
		  SQLHANDLE stmt;
		  char *enlist_command = (char *) dk_alloc (MTS_BUFSIZ);
		  char *cookie_encoded = mts_bin_encode (cookie, cookie_len);

		  snprintf (enlist_command, MTS_BUFSIZ, "select mts_enlist_transaction(\'%s\')", cookie_encoded);
		  rc = virtodbc__SQLAllocStmt (hdbc, &stmt);
		  if (SQL_SUCCESS != rc)
		    goto free_ret;

		  rc = virtodbc__SQLExecDirect (stmt, enlist_command, SQL_NTS);
		  if (SQL_SUCCESS == rc)
		    {
		      SQLINTEGER ret = 1;
		      SQLLEN cols;
		      rc = SQLBindCol (stmt, 1, SQL_INTEGER, (SQLPOINTER) & ret, 0, &cols);
		      if (SQL_SUCCESS == rc)
			{
			  rc = virtodbc__SQLFetch (stmt, 0);
			  if (SQL_SUCCESS == rc)
			    {
			      if (0 == ret)
				{
				  con->con_autocommit = 0;
				}
			      else
				{
				  rc = SQL_ERROR;
				  set_error (&con->con_error, "40001", "CL046", "could not enlist transaction");
				}

			    }
			}
		    }
		  virtodbc__SQLFreeStmt (stmt, SQL_DROP);

		free_ret:
		  if (cookie_encoded)
		    dk_free_box (cookie_encoded);
		  dk_free (enlist_command, MTS_BUFSIZ);

		  return rc;
		}
	      else
		{
		  set_error (&con->con_error, "25000", "CL047", "could not enlist resource manager in transaction");

		  return SQL_ERROR;
		}
	    }
	}
      else
	goto nc;

      return SQL_SUCCESS;
      /* end of MTS support */
#else
      return SQL_ERROR;
#endif
#else
      return SQL_ERROR;
#endif

#ifdef XA_IMPL
    case SQL_COPT_SS_ENLIST_IN_XA:
      if (CON_CONNECTED (con))
	{
	  int c;
	  char *xid_str = 0;
	  caddr_t *res;
	  future_t *future;

	  if (!vParam)
	    {
	      c = SQL_TP_UNENLIST;
	    }
	  else
	    {
	      c = SQL_XA_ENLIST;
	      xid_str = xid_bin_encode ((void *) vParam);
	      if (!xid_str)
		return SQL_ERROR;
	    }

	  future = PrpcFuture (con->con_session, &s_sql_tp_transact, c, xid_str);
	  res = (caddr_t *) PrpcFutureNextResult (future);
	  PrpcFutureFree (future);
	  dk_free_box (xid_str);

	  if (DKSESSTAT_ISSET (con->con_session, SST_BROKEN_CONNECTION))
	    {
	      PrpcFutureFree (future);
	      set_error (&con->con_error, "08S01", "CL045", "Lost connection to server");

	      return SQL_ERROR;
	    }

	  if (res == (caddr_t *) SQL_SUCCESS)
	    {
	      return SQL_SUCCESS;
	    }
	  else
	    {
	      caddr_t srv_msg = cli_box_server_msg (res[2]);
	      set_error (&con->con_error, res[1], NULL, srv_msg);
	      dk_free_tree ((caddr_t) res);
	      dk_free_box (srv_msg);

	      return SQL_ERROR;
	    }
	}
      else
	goto nc;
#endif

    case SQL_ENCRYPT_CONNECTION:
      if (con->con_encrypt)
	{
	  dk_free_box (con->con_encrypt);
	  con->con_encrypt = NULL;
	}

      if (vParam && ((char *) vParam)[0])
	{
	  con->con_encrypt = box_string ((char *) vParam);
	}
      return SQL_SUCCESS;

    case SQL_SERVER_CERT:
      {
	if (con->con_ca_list)
	  dk_free_box (con->con_ca_list);
	con->con_ca_list = NULL;
	if (vParam && ((char *) vParam)[0])
	  con->con_ca_list = box_string ((char *) vParam);
	return SQL_SUCCESS;
      }

    case SQL_PWD_CLEARTEXT:
      con->con_pwd_cleartext = (int) vParam;
      return SQL_SUCCESS;

    case SQL_SHUTDOWN_ON_CONNECT:
      con->con_shutdown = (vParam != 0);
      break;
    }

  return SQL_SUCCESS;
nc:
  set_error (&con->con_error, "42000", "CL089", "Not connected to the data source");
  return SQL_ERROR;
}


SQLRETURN SQL_API
SQLGetStmtOption (
      SQLHSTMT hstmt,
      SQLUSMALLINT fOption,
      SQLPOINTER pvParam)
{
  return virtodbc__SQLGetStmtOption (hstmt, fOption, pvParam);
}


SQLRETURN SQL_API
virtodbc__SQLGetStmtOption (
      SQLHSTMT hstmt,
      SQLUSMALLINT fOption,
      SQLPOINTER pvParam)
{
  STMT (stmt, hstmt);
  stmt_options_t *so = stmt->stmt_opts;

  if (NULL == pvParam)
    return SQL_SUCCESS;

  switch (fOption)
    {
    case SQL_ASYNC_ENABLE:
#ifndef WIN32
      *(SQLLEN *) pvParam = so->so_is_async;
#endif
      break;

    case SQL_MAX_ROWS:
      *(SQLLEN *) pvParam = so->so_max_rows;
      break;

    case SQL_QUERY_TIMEOUT:
      *(SQLULEN *) pvParam = stmt->stmt_opts->so_rpc_timeout / 1000;
      break;

    case SQL_TXN_TIMEOUT:
      *(SQLLEN *) pvParam = so->so_timeout / 1000;	/*msecs */
      break;

    case SQL_CONCURRENCY:
      *(SQLLEN *) pvParam = so->so_concurrency;
      break;

    case SQL_ROWSET_SIZE:
      *(SQLLEN *) pvParam = stmt->stmt_rowset_size;
      break;

    case SQL_KEYSET_SIZE:
      *(SQLLEN *) pvParam = so->so_keyset_size;
      break;

    case SQL_GET_BOOKMARK:
      return (virtodbc__SQLGetData (hstmt, 0, SQL_C_LONG, pvParam, sizeof (long), NULL));

    case SQL_MAX_LENGTH:
      *(SQLULEN *) pvParam = 64000000;
      break;

    case SQL_USE_BOOKMARKS:
      *(SQLULEN *) pvParam = so->so_use_bookmarks;
      break;

    case SQL_BIND_TYPE:
      *(SQLULEN *) pvParam = stmt->stmt_bind_type;
      break;

    case SQL_CURSOR_TYPE:
      *(SQLULEN *) pvParam = stmt->stmt_opts->so_cursor_type;
      break;

    case SQL_RETRIEVE_DATA:
      *(SQLULEN *) pvParam = stmt->stmt_retrieve_data;
      break;

    case SQL_ROW_NUMBER:
      switch (stmt->stmt_opts->so_cursor_type)
	{
	case SQL_CURSOR_STATIC:
	  if (stmt->stmt_current_row)
	    {
	      long len = BOX_ELEMENTS (stmt->stmt_current_row);
	      caddr_t bm = stmt->stmt_current_row[len - 2];
	      *(SQLULEN *) pvParam = (unbox (bm));
	    }
	  else
	    *(SQLULEN *) pvParam = 0;
	  break;

	case SQL_CURSOR_KEYSET_DRIVEN:
	  if (stmt->stmt_current_row)
	    {
	      long len = BOX_ELEMENTS (stmt->stmt_current_row);
	      caddr_t bm = stmt->stmt_current_row[len - 1];
	      *(SQLULEN *) pvParam = (unbox (bm));
	    }
	  else
	    *(SQLULEN *) pvParam = 0;
	  break;

	case SQL_CURSOR_DYNAMIC:
	  *(SQLULEN *) pvParam = stmt->stmt_current_of;
	  break;
	}
      break;

    case SQL_PREFETCH_SIZE:
      *(SQLLEN *) pvParam = stmt->stmt_opts->so_prefetch;
      break;

    case SQL_UNIQUE_ROWS:
      *(SQLULEN *) pvParam = stmt->stmt_opts->so_unique_rows;
      break;

    case SQL_GETLASTSERIAL:
      *(SQLINTEGER *) pvParam = unbox (stmt->stmt_identity_value);
      break;
    }

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
SQLSetStmtOption (
      SQLHSTMT hstmt,
      SQLUSMALLINT fOption,
      SQLULEN vParam)
{
  return virtodbc__SQLSetStmtOption (hstmt, fOption, vParam);
}


SQLRETURN SQL_API
virtodbc__SQLSetStmtOption (
      SQLHSTMT hstmt,
      SQLUSMALLINT fOption,
      SQLULEN vParam)
{
  STMT (stmt, hstmt);
  stmt_options_t *so = stmt->stmt_opts;

  switch (fOption)
    {
    case SQL_CURSOR_TYPE:
      stmt->stmt_opts->so_cursor_type = vParam;
      if (stmt->stmt_is_deflt_rowset)
	stmt->stmt_rowset_size = 1;
      break;

    case SQL_KEYSET_SIZE:
      stmt->stmt_opts->so_keyset_size = vParam;
      break;

    case SQL_BIND_TYPE:
      stmt->stmt_bind_type = (int) vParam;
      break;

    case SQL_ASYNC_ENABLE:
#ifndef WIN32
      so->so_is_async = vParam;
#endif
      break;

    case SQL_MAX_ROWS:
      so->so_max_rows = vParam;
      break;

    case SQL_QUERY_TIMEOUT:
      if (vParam > 0x7fffffff / 1000)
	vParam = 0x7fffffff / 1000;
      stmt->stmt_opts->so_rpc_timeout = vParam * 1000;
      break;

    case SQL_TXN_TIMEOUT:
      if (vParam > 0x7fffffff / 1000)
	vParam = 0;
      so->so_timeout = vParam * 1000;	/*msecs */
      break;

    case SQL_CONCURRENCY:
      so->so_concurrency = vParam;
      break;

    case SQL_ROWSET_SIZE:
      stmt->stmt_is_deflt_rowset = 0;
      stmt->stmt_rowset_size = vParam;
      break;

    case SQL_USE_BOOKMARKS:
      so->so_use_bookmarks = vParam;
      break;

    case SQL_RETRIEVE_DATA:
      stmt->stmt_retrieve_data = vParam;
      break;

    case SQL_PREFETCH_SIZE:
      stmt->stmt_opts->so_prefetch = (SDWORD) vParam;
      break;

    case SQL_UNIQUE_ROWS:
      stmt->stmt_opts->so_unique_rows = vParam;
      break;
    }

  return SQL_SUCCESS;
}



SQLUSMALLINT functions[100];
#define __F(n)
#if (ODBCVER >= 0x0300)
SQLSMALLINT functions3[SQL_API_ODBC3_ALL_FUNCTIONS_SIZE];

#define F(n) \
    if (n < 100) \
      functions[n]=1; \
    functions3[(n) >> 4] |= (1 << ((n) & 0x000F))
#else
#define F(n) functions[n]=1
#endif

SQLRETURN SQL_API
SQLGetFunctions (
      SQLHDBC hdbc,
      SQLUSMALLINT fFunction,
      SQLUSMALLINT * pfExists)
{
  F (SQL_API_SQLALLOCCONNECT);
  F (SQL_API_SQLALLOCENV);
  F (SQL_API_SQLALLOCSTMT);
  F (SQL_API_SQLBINDCOL);
  F (SQL_API_SQLCANCEL);
  F (SQL_API_SQLCOLATTRIBUTES);
  F (SQL_API_SQLCONNECT);
  F (SQL_API_SQLDESCRIBECOL);
  F (SQL_API_SQLDISCONNECT);
  F (SQL_API_SQLERROR);
  F (SQL_API_SQLEXECDIRECT);
  F (SQL_API_SQLEXECUTE);
  F (SQL_API_SQLFETCH);
  F (SQL_API_SQLFREECONNECT);
  F (SQL_API_SQLFREEENV);
  F (SQL_API_SQLFREESTMT);
  F (SQL_API_SQLGETCURSORNAME);
  F (SQL_API_SQLNUMRESULTCOLS);
  F (SQL_API_SQLPREPARE);
  F (SQL_API_SQLROWCOUNT);
  F (SQL_API_SQLSETCURSORNAME);
  F (SQL_API_SQLSETPARAM);
  F (SQL_API_SQLTRANSACT);
  F (SQL_API_SQLTRANSACT + 1);
  F (SQL_API_SQLBINDPARAMETER);

  F (SQL_API_SQLCOLUMNS);
  F (SQL_API_SQLDRIVERCONNECT);
  F (SQL_API_SQLGETCONNECTOPTION);
  F (SQL_API_SQLGETDATA);
  F (SQL_API_SQLGETFUNCTIONS);
  F (SQL_API_SQLGETINFO);
  F (SQL_API_SQLGETSTMTOPTION);
  F (SQL_API_SQLGETTYPEINFO);
  F (SQL_API_SQLPARAMDATA);
  F (SQL_API_SQLPUTDATA);
  F (SQL_API_SQLSETCONNECTOPTION);
  F (SQL_API_SQLSETSTMTOPTION);
  F (SQL_API_SQLSPECIALCOLUMNS);
  F (SQL_API_SQLSTATISTICS);	/* Added by AK 17-JAN-1997. */
  F (SQL_API_SQLTABLES);

  __F (SQL_API_SQLBROWSECONNECT);
  F (SQL_API_SQLCOLUMNPRIVILEGES);
  __F (SQL_API_SQLDATASOURCES);
  F (SQL_API_SQLDESCRIBEPARAM);
  F (SQL_API_SQLEXTENDEDFETCH);
  F (SQL_API_SQLFOREIGNKEYS);
  F (SQL_API_SQLMORERESULTS);
  F (SQL_API_SQLNATIVESQL);
  F (SQL_API_SQLNUMPARAMS);
  F (SQL_API_SQLPARAMOPTIONS);
  F (SQL_API_SQLPRIMARYKEYS);	/* Added by AK 17-JAN-1997. */
  F (SQL_API_SQLPROCEDURECOLUMNS);
  F (SQL_API_SQLPROCEDURES);
  F (SQL_API_SQLSETPOS);
  F (SQL_API_SQLSETSCROLLOPTIONS);
  F (SQL_API_SQLTABLEPRIVILEGES);
  __F (SQL_API_SQLDRIVERS);


#if (ODBCVER >= 0x0300)
  /* ODBC 3 stuff */
  F (SQL_API_SQLALLOCHANDLE);
  F (SQL_API_SQLFREEHANDLE);

  F (SQL_API_SQLGETDIAGREC);
  F (SQL_API_SQLGETDIAGFIELD);

  F (SQL_API_SQLGETENVATTR);
  F (SQL_API_SQLSETENVATTR);

  F (SQL_API_SQLSETCONNECTATTR);
  F (SQL_API_SQLGETCONNECTATTR);

  F (SQL_API_SQLGETSTMTATTR);
  F (SQL_API_SQLSETSTMTATTR);

  F (SQL_API_SQLGETDESCFIELD);
  F (SQL_API_SQLSETDESCFIELD);

  F (SQL_API_SQLGETDESCREC);
  __F (SQL_API_SQLSETDESCREC);

  __F (SQL_API_SQLCOPYDESC);

#if (ODBCVER < 0x0300)
  F (SQL_API_SQLCOLATTRIBUTE);
#endif

  F (SQL_API_SQLENDTRAN);

  F (SQL_API_SQLFETCHSCROLL);

  F (SQL_API_SQLBULKOPERATIONS);
#endif

  if (fFunction == SQL_API_ALL_FUNCTIONS)
    memcpy (pfExists, &functions, 100 * sizeof (SQLUSMALLINT));
#if (ODBCVER >= 0x0300)
  else if (fFunction == SQL_API_ODBC3_ALL_FUNCTIONS)
    memcpy (pfExists, &functions3, SQL_API_ODBC3_ALL_FUNCTIONS_SIZE * sizeof (SQLSMALLINT));
#endif
  else if (pfExists)
    {
#if (ODBCVER >= 0x0300)
      if (fFunction > 100)
	*pfExists = SQL_FUNC_EXISTS (functions3, fFunction) ? SQL_TRUE : SQL_FALSE;
      else
#endif
	*pfExists = functions[fFunction];
    }

  return SQL_SUCCESS;
}



#define KUBL_ARBITRARY_MAX_VALUE1 0	/* We do not know. */


SQLRETURN SQL_API
virtodbc__SQLGetInfo (
	SQLHDBC hdbc,
	SQLUSMALLINT fInfoType,
	SQLPOINTER rgbInfoValue,
	SQLSMALLINT cbInfoValueMax,
	SQLSMALLINT * pcbInfoValue)
{
  CON (dbc, hdbc);
  char *strres = NULL;
  SQLUSMALLINT shortres = 0;
  SQLUINTEGER intres = 0;
  SQLULEN ulenres = 0;
  SQLRETURN rc = SQL_SUCCESS;
  int is_short = 0;
  int is_ulen = 0;

  cli_dbg_printf (("SQLGetInfo called.\n"));

  switch (fInfoType)
    {
    case SQL_ACTIVE_CONNECTIONS:
      is_short = 1;
      shortres = KUBL_ARBITRARY_MAX_VALUE1;	/* 100; */
      break;

    case SQL_ACTIVE_STATEMENTS:
      is_short = 1;
      shortres = KUBL_ARBITRARY_MAX_VALUE1;	/* 10000; */
      break;

    case SQL_DATABASE_NAME:
      strres = (char *) dbc->con_qualifier;
      break;

    case SQL_DATA_SOURCE_NAME:
      strres = (char *) dbc->con_dsn;
      break;

#if 0
    /*
     * The next three are implemented by the Driver Manager alone.
     */
    case SQL_DRIVER_HDBC:
      ulenres = (SQLULEN) hdbc;
      is_ulen = 1;
      break;

    case SQL_DRIVER_HENV:
      ulenres = (SQLULEN) dbc->con_environment;
      is_ulen = 1;
      break;

    case SQL_DRIVER_HSTMT:
      ulenres = (SQLULEN) rgbInfoValue;		 /* Or *((SQLHSTMT *)rgbInfoValue) ? */
      is_ulen = 1;
      break;
#endif

    case SQL_DRIVER_NAME:
#ifdef WIN32
      strres = "virtodbc40.dll";
#else
      strres = "virtodbc.so";
#endif
      break;

    case SQL_DRIVER_VER:
      /* A character string with the version of the driver and,
         optionally a description of the driver.
         At a minimum the version is of the form ##.##.####
         where the first two digits are the major version,
         the next two digits are the minor version, and
         the last four digits are the release version. */
      strres = ODBC_DRV_VER " " ODBC_DRV_NAME;
      break;

    case SQL_DBMS_NAME:
#if 1
      if (__virtodbc_dbms_name[0] != 0)
	strres = &(__virtodbc_dbms_name[0]);
      else
#endif
	strres = PRODUCT_DBMS;
      break;

    case SQL_DBMS_VER:
      /* The version is of the form ##.##.#### where the first two
         digits are the major version, the next two digits are the
         minor version, and the last four digits are the release
         version. The driver can also append the DBMS product-specific
         version as well. For example, "04.01.0000 Rdb 4.1" */
      strres = (char *) dbc->con_db_ver;
      break;

    case SQL_SERVER_NAME:
      strres = DBMS_SRV_NAME;
      break;

    case SQL_FETCH_DIRECTION:
      intres =
	  SQL_FD_FETCH_NEXT |
	  SQL_FD_FETCH_FIRST |
	  SQL_FD_FETCH_LAST |
	  SQL_FD_FETCH_PRIOR |
	  SQL_FD_FETCH_ABSOLUTE |
	  SQL_FD_FETCH_RELATIVE |
	  SQL_FD_FETCH_BOOKMARK;

      break;

    case SQL_ODBC_API_CONFORMANCE:
      is_short = 1;
      shortres = SQL_OAC_LEVEL2;
      break;

    case SQL_ODBC_VER:
      strres = "03.00.0000";
      break;

    case SQL_ROW_UPDATES:
      /* "Y" if a keyset-driven or mixed cursor maintains row versions or
         values for all fetched rows and therefore can detect any changes
         made to a row by any user since the row was last fetched;
         otherwise, "N".
         Our cursor can prevent any changes being made to a row by any user,
         but our cursor is not keyset-driven or mixed cursor. */
      strres = "N";
      break;			/* WAS: goto na; */

    case SQL_ODBC_SAG_CLI_CONFORMANCE:
      is_short = 1;
      shortres = SQL_OSCC_COMPLIANT;
      break;			/* Or SQL_OSCC_NOT_COMPLIANT */

    case SQL_SEARCH_PATTERN_ESCAPE:
      strres = "\\";
/*      strres = ""; */
      break;

    case SQL_ODBC_SQL_CONFORMANCE:
      is_short = 1;
      shortres = SQL_OSC_CORE;
      break;			/* Or SQL_OSC_MINIMUM or _EXTENDED */

    case SQL_ACCESSIBLE_TABLES:
      /* Actually we should check whether user really has rights to all tables,
         that is, whether he is super-user dba or belongs to the same group,
         and whether there exists any protected tables in the system.
         (The group-id of the user is not currently included in connection
         structure, or at least I cannot find it.) */
      strres = (char *) ((dbc->con_user != NULL  && !strcmp ((char *) dbc->con_user, "dba")) ? "Y" : "N");
      break;

    case SQL_ACCESSIBLE_PROCEDURES:	/* The notes above apply here also. */
      strres = (char *) ((dbc->con_user && !strcmp ((char *) dbc->con_user, "dba")) ? "Y" : "N");
      break;

    case SQL_PROCEDURES:
      strres = "Y";
      break;

    case SQL_CONCAT_NULL_BEHAVIOR:
      is_short = 1;
      shortres = SQL_CB_NON_NULL;
      break;

    case SQL_CURSOR_COMMIT_BEHAVIOR:
      is_short = 1;
      shortres = SQL_CB_PRESERVE;
      break;

    case SQL_CURSOR_ROLLBACK_BEHAVIOR:
      is_short = 1;
      shortres = SQL_CB_PRESERVE;
      break;

    case SQL_DATA_SOURCE_READ_ONLY:
      strres = "N";
      break;

    case SQL_DEFAULT_TXN_ISOLATION:
      intres = SQL_TXN_REPEATABLE_READ;	/* SQL_TXN_SERIALIZABLE; */
      break;

    case SQL_EXPRESSIONS_IN_ORDERBY:	/* E.g. ORDER BY abs(A) */
      strres = "N";
      break;			/* Definitely NO with Kubl  0.96b G13d3. */

    case SQL_IDENTIFIER_CASE:
      is_short = 1;
      switch (dbc->con_db_casemode)
	{
	case 0:
	  shortres = SQL_IC_SENSITIVE;
	  break;

	case 1:
	  shortres = SQL_IC_UPPER;
	  break;

	case 2:
	  shortres = SQL_IC_MIXED;
	  break;
	}
      break;

    case SQL_QUOTED_IDENTIFIER_CASE:
      is_short = 1;
      shortres = SQL_IC_SENSITIVE;	/* For JDBC this was: SQL_IC_MIXED */
      break;

    case SQL_IDENTIFIER_QUOTE_CHAR:
      strres = "\"";		/* Was: "\\"; E.g. in Access "|" ? */
      break;

    case SQL_MAX_COLUMN_NAME_LEN:
      is_short = 1;
      shortres = KUBL_IDENTIFIER_MAX_LENGTH;	/* 250; */
      break;

    case SQL_MAX_CURSOR_NAME_LEN:
      is_short = 1;
      shortres = 100;
      break;

    case SQL_MAX_OWNER_NAME_LEN:
      is_short = 1;
      shortres = KUBL_IDENTIFIER_MAX_LENGTH;	/* 250; */
      break;

    case SQL_MAX_PROCEDURE_NAME_LEN:
      is_short = 1;
      shortres = KUBL_IDENTIFIER_MAX_LENGTH;
      break;

    case SQL_MAX_QUALIFIER_NAME_LEN:
      is_short = 1;
      shortres = KUBL_IDENTIFIER_MAX_LENGTH;	/* 250; */
      break;

    case SQL_MAX_TABLE_NAME_LEN:
      is_short = 1;
      shortres = KUBL_IDENTIFIER_MAX_LENGTH;	/* 250; */
      break;

    case SQL_MULT_RESULT_SETS:
      strres = "Y";
      break;

    case SQL_MULTIPLE_ACTIVE_TXN:
      strres = "Y";
      break;

    case SQL_OUTER_JOINS:	/* Constants SQL_OJ_* */
      strres = "Y";
      break;			/* break missing, added by AK 2-MAR-1997 */

#ifdef SQL_OJ_CAPABILITIES
    case SQL_OJ_CAPABILITIES:	/* Constants SQL_OJ_* ??? */
      intres =
	   SQL_OJ_LEFT |
	  SQL_OJ_RIGHT |
	  SQL_OJ_INNER |
	  SQL_OJ_NESTED |
	  SQL_OJ_NOT_ORDERED |
	  SQL_OJ_ALL_COMPARISON_OPS;
      break;
#endif

    case SQL_OWNER_TERM:
      strres = "owner";
      break;

    case SQL_PROCEDURE_TERM:
      strres = "procedure";
      break;

    case SQL_QUALIFIER_NAME_SEPARATOR:
      strres = ".";
      break;

    case SQL_QUALIFIER_TERM:
      strres = "qualifier";
      break;			/* For example, "database" or "directory" */

    case SQL_SCROLL_CONCURRENCY:
      intres =
	  SQL_SCCO_READ_ONLY |
	  SQL_SCCO_LOCK |
	  SQL_SCCO_OPT_ROWVER;
      break;

    case SQL_SCROLL_OPTIONS:
      intres =
	  SQL_SO_FORWARD_ONLY |
	  SQL_SO_STATIC |
	  SQL_SO_KEYSET_DRIVEN |
	  SQL_SO_DYNAMIC;
      break;

    case SQL_TABLE_TERM:
      strres = "table";
      break;

    case SQL_TXN_CAPABLE:
      is_short = 1;
      shortres = SQL_TC_ALL;
      break;

    case SQL_USER_NAME:
      strres = (char *) dbc->con_user;
      strupr (strres);
      break;

    case SQL_CONVERT_FUNCTIONS:
      intres =
	   SQL_FN_CVT_CAST |
	  SQL_FN_CVT_CONVERT;
      break;

    case SQL_CONVERT_BIT:
    case SQL_CONVERT_TINYINT:
    case SQL_CONVERT_BIGINT:
      intres = 0
/*	  SQL_CVT_BIGINT |
	  SQL_CVT_BINARY |
	  SQL_CVT_BIT |
	  SQL_CVT_CHAR |
	  SQL_CVT_DATE |
	  SQL_CVT_DECIMAL |
	  SQL_CVT_DOUBLE |
	  SQL_CVT_FLOAT |
	  SQL_CVT_INTEGER |
	  SQL_CVT_LONGVARBINARY |
	  SQL_CVT_LONGVARCHAR |
	  SQL_CVT_NUMERIC |
	  SQL_CVT_REAL |
	  SQL_CVT_SMALLINT |
	  SQL_CVT_TIME |
	  SQL_CVT_TIMESTAMP |
	  SQL_CVT_TINYINT |
	  SQL_CVT_VARBINARY |
#if (ODBCVER >= 0x0300)
	  SQL_CVT_WCHAR |
	  SQL_CVT_WVARCHAR |
	  SQL_CVT_WLONGVARCHAR |
#endif
	  SQL_CVT_VARCHAR*/
	  ;
      break;

    case SQL_CONVERT_VARBINARY:
    case SQL_CONVERT_BINARY:
      intres =
/*	  SQL_CVT_BIGINT |*/
	  SQL_CVT_BINARY |
/*	  SQL_CVT_BIT |*/
	  SQL_CVT_CHAR | !
/*	  SQL_CVT_DATE |
	  SQL_CVT_DECIMAL |
	  SQL_CVT_DOUBLE |
	  SQL_CVT_FLOAT |
	  SQL_CVT_INTEGER |
	  SQL_CVT_LONGVARBINARY |
	  SQL_CVT_LONGVARCHAR |
	  SQL_CVT_NUMERIC |
	  SQL_CVT_REAL |
	  SQL_CVT_SMALLINT |
	  SQL_CVT_TIME |
	  SQL_CVT_TIMESTAMP |
	  SQL_CVT_TINYINT |*/
	  SQL_CVT_VARBINARY |
#if (ODBCVER >= 0x0300)
/*	  SQL_CVT_WCHAR |
	  SQL_CVT_WVARCHAR |
	  SQL_CVT_WLONGVARCHAR |*/
#endif
	  SQL_CVT_VARCHAR;
      break;

    case SQL_CONVERT_VARCHAR:
    case SQL_CONVERT_CHAR:
      intres =
/*	  SQL_CVT_BIGINT |*/
	  SQL_CVT_BINARY |
/*	  SQL_CVT_BIT |*/
	  SQL_CVT_CHAR |
	  SQL_CVT_DATE |
	  SQL_CVT_DECIMAL |
	  SQL_CVT_DOUBLE |
	  SQL_CVT_FLOAT |
	  SQL_CVT_INTEGER |
/*	  SQL_CVT_LONGVARBINARY |*/
/*	  SQL_CVT_LONGVARCHAR |*/
	  SQL_CVT_NUMERIC |
	  SQL_CVT_REAL |
	  SQL_CVT_SMALLINT |
	  SQL_CVT_TIME |
	  SQL_CVT_TIMESTAMP |
/*	  SQL_CVT_TINYINT |*/
	  SQL_CVT_VARBINARY |
#if (ODBCVER >= 0x0300)
	  SQL_CVT_WCHAR |
	  SQL_CVT_WVARCHAR |
/*	  SQL_CVT_WLONGVARCHAR |*/
#endif
	  SQL_CVT_VARCHAR;
      break;

    case SQL_CONVERT_TIME:
    case SQL_CONVERT_TIMESTAMP:
    case SQL_CONVERT_DATE:
      intres =
/*	  SQL_CVT_BIGINT |*/
	  SQL_CVT_BINARY |
/*	  SQL_CVT_BIT |*/
	  SQL_CVT_CHAR |
	  SQL_CVT_DATE |
/*	  SQL_CVT_DECIMAL |*/
/*	  SQL_CVT_DOUBLE |*/
/*	  SQL_CVT_FLOAT |*/
/*	  SQL_CVT_INTEGER |*/
/*	  SQL_CVT_LONGVARBINARY |*/
/*	  SQL_CVT_LONGVARCHAR |*/
/*	  SQL_CVT_NUMERIC |*/
/*	  SQL_CVT_REAL |*/
/*	  SQL_CVT_SMALLINT |*/
	  SQL_CVT_TIME |
	  SQL_CVT_TIMESTAMP |
/*	  SQL_CVT_TINYINT |*/
	  SQL_CVT_VARBINARY |
#if (ODBCVER >= 0x0300)
	  SQL_CVT_WCHAR |
	  SQL_CVT_WVARCHAR |
/*	  SQL_CVT_WLONGVARCHAR |*/
#endif
	  SQL_CVT_VARCHAR;
      break;

    case SQL_CONVERT_DECIMAL:
    case SQL_CONVERT_NUMERIC:
      intres =
/*	  SQL_CVT_BIGINT |*/
	  SQL_CVT_BINARY |
/*	  SQL_CVT_BIT |*/
	  SQL_CVT_CHAR |
/*	  SQL_CVT_DATE |*/
	  SQL_CVT_DECIMAL |
	  SQL_CVT_DOUBLE |
	  SQL_CVT_FLOAT |
	  SQL_CVT_INTEGER |
/*	  SQL_CVT_LONGVARBINARY |*/
/*	  SQL_CVT_LONGVARCHAR |*/
	  SQL_CVT_NUMERIC |
	  SQL_CVT_REAL |
/*	  SQL_CVT_SMALLINT |*/
/*	  SQL_CVT_TIME |*/
/*	  SQL_CVT_TIMESTAMP |*/
/*	  SQL_CVT_TINYINT |*/
	  SQL_CVT_VARBINARY |
#if (ODBCVER >= 0x0300)
	  SQL_CVT_WCHAR |
	  SQL_CVT_WVARCHAR |
/*	  SQL_CVT_WLONGVARCHAR |*/
#endif
	  SQL_CVT_VARCHAR;
      break;

    case SQL_CONVERT_DOUBLE:
    case SQL_CONVERT_FLOAT:
    case SQL_CONVERT_REAL:
      intres =
/*	  SQL_CVT_BIGINT |*/
	  SQL_CVT_BINARY |
/*	  SQL_CVT_BIT |*/
	  SQL_CVT_CHAR |
/*	  SQL_CVT_DATE |*/
	  SQL_CVT_DECIMAL |
	  SQL_CVT_DOUBLE |
	  SQL_CVT_FLOAT |
	  SQL_CVT_INTEGER |
/*	  SQL_CVT_LONGVARBINARY |*/
/*	  SQL_CVT_LONGVARCHAR |*/
	  SQL_CVT_NUMERIC |
	  SQL_CVT_REAL |
/*	  SQL_CVT_SMALLINT |*/
/*	  SQL_CVT_TIME |*/
/*	  SQL_CVT_TIMESTAMP |*/
/*	  SQL_CVT_TINYINT |*/
	  SQL_CVT_VARBINARY |
#if (ODBCVER >= 0x0300)
	  SQL_CVT_WCHAR |
	  SQL_CVT_WVARCHAR |
/*	  SQL_CVT_WLONGVARCHAR |*/
#endif
	  SQL_CVT_VARCHAR;
      break;

    case SQL_CONVERT_INTEGER:
    case SQL_CONVERT_SMALLINT:
      intres =
/*	  SQL_CVT_BIGINT |*/
	  SQL_CVT_BINARY |
/*	  SQL_CVT_BIT |*/
	  SQL_CVT_CHAR |
/*	  SQL_CVT_DATE |*/
	  SQL_CVT_DECIMAL |
	  SQL_CVT_DOUBLE |
	  SQL_CVT_FLOAT |
	  SQL_CVT_INTEGER |
/*	  SQL_CVT_LONGVARBINARY |*/
/*	  SQL_CVT_LONGVARCHAR |*/
	  SQL_CVT_NUMERIC |
	  SQL_CVT_REAL |
/*	  SQL_CVT_SMALLINT |*/
/*	  SQL_CVT_TIME |*/
/*	  SQL_CVT_TIMESTAMP |*/
/*	  SQL_CVT_TINYINT |*/
	  SQL_CVT_VARBINARY |
#if (ODBCVER >= 0x0300)
	  SQL_CVT_WCHAR |
	  SQL_CVT_WVARCHAR |
/*	  SQL_CVT_WLONGVARCHAR |*/
#endif
	  SQL_CVT_VARCHAR;
      break;

    case SQL_CONVERT_LONGVARBINARY:
      intres =
/*	  SQL_CVT_BIGINT |*/
	  SQL_CVT_BINARY |
/*	  SQL_CVT_BIT |*/
	  SQL_CVT_CHAR |
/*	  SQL_CVT_DATE |*/
/*	  SQL_CVT_DECIMAL |*/
/*	  SQL_CVT_DOUBLE |*/
/*	  SQL_CVT_FLOAT |*/
/*	  SQL_CVT_INTEGER |*/
	  SQL_CVT_LONGVARBINARY |
/*	  SQL_CVT_LONGVARCHAR |*/
/*	  SQL_CVT_NUMERIC |*/
/*	  SQL_CVT_REAL |*/
/*	  SQL_CVT_SMALLINT |*/
/*	  SQL_CVT_TIME |*/
/*	  SQL_CVT_TIMESTAMP |*/
/*	  SQL_CVT_TINYINT |*/
	  SQL_CVT_VARBINARY |
#if (ODBCVER >= 0x0300)
	  SQL_CVT_WCHAR |
	  SQL_CVT_WVARCHAR |
/*	  SQL_CVT_WLONGVARCHAR |*/
#endif
	  SQL_CVT_VARCHAR;
      break;

    case SQL_CONVERT_LONGVARCHAR:
      intres =
/*	  SQL_CVT_BIGINT |*/
	  SQL_CVT_BINARY |
/*	  SQL_CVT_BIT |*/
	  SQL_CVT_CHAR |
/*	  SQL_CVT_DATE |*/
/*	  SQL_CVT_DECIMAL |*/
/*	  SQL_CVT_DOUBLE |*/
/*	  SQL_CVT_FLOAT |*/
/*	  SQL_CVT_INTEGER |*/
/*	  SQL_CVT_LONGVARBINARY |*/
	  SQL_CVT_LONGVARCHAR |
/*	  SQL_CVT_NUMERIC |*/
/*	  SQL_CVT_REAL |*/
/*	  SQL_CVT_SMALLINT |*/
/*	  SQL_CVT_TIME |*/
/*	  SQL_CVT_TIMESTAMP |*/
/*	  SQL_CVT_TINYINT |*/
	  SQL_CVT_VARBINARY |
#if (ODBCVER >= 0x0300)
	  SQL_CVT_WCHAR |
	  SQL_CVT_WVARCHAR |
/*	  SQL_CVT_WLONGVARCHAR |*/
#endif
	  SQL_CVT_VARCHAR;
      break;

#if (ODBCVER >= 0x0300)
    case SQL_CONVERT_WVARCHAR:
      intres =
/*	  SQL_CVT_BIGINT |*/
	  SQL_CVT_BINARY |
/*	  SQL_CVT_BIT |*/
	  SQL_CVT_CHAR |
/*	  SQL_CVT_DATE |*/
/*	  SQL_CVT_DECIMAL |*/
/*	  SQL_CVT_DOUBLE |*/
/*	  SQL_CVT_FLOAT |*/
/*	  SQL_CVT_INTEGER |*/
/*	  SQL_CVT_LONGVARBINARY |*/
	  SQL_CVT_LONGVARCHAR |
/*	  SQL_CVT_NUMERIC |*/
/*	  SQL_CVT_REAL |*/
/*	  SQL_CVT_SMALLINT |*/
/*	  SQL_CVT_TIME |*/
/*	  SQL_CVT_TIMESTAMP |*/
/*	  SQL_CVT_TINYINT |*/
	  SQL_CVT_VARBINARY |
	  SQL_CVT_WCHAR |
	  SQL_CVT_WVARCHAR |
/*	  SQL_CVT_WLONGVARCHAR |*/
	  SQL_CVT_VARCHAR;

    case SQL_CONVERT_WLONGVARCHAR:
      intres =
/*	  SQL_CVT_BIGINT |*/
	  SQL_CVT_BINARY |
/*	  SQL_CVT_BIT |*/
	  SQL_CVT_CHAR |
/*	  SQL_CVT_DATE |*/
/*	  SQL_CVT_DECIMAL |*/
/*	  SQL_CVT_DOUBLE |*/
/*	  SQL_CVT_FLOAT |*/
/*	  SQL_CVT_INTEGER |*/
/*	  SQL_CVT_LONGVARBINARY |*/
	  SQL_CVT_LONGVARCHAR |
/*	  SQL_CVT_NUMERIC |*/
/*	  SQL_CVT_REAL |*/
/*	  SQL_CVT_SMALLINT |*/
/*	  SQL_CVT_TIME |*/
/*	  SQL_CVT_TIMESTAMP |*/
/*	  SQL_CVT_TINYINT |*/
	  SQL_CVT_VARBINARY |
	  SQL_CVT_WCHAR |
	  SQL_CVT_WVARCHAR |
	  SQL_CVT_WLONGVARCHAR |
	  SQL_CVT_VARCHAR;
#endif

    case SQL_NUMERIC_FUNCTIONS:
      intres =
	  SQL_FN_NUM_ABS |
	  SQL_FN_NUM_MOD |
	  SQL_FN_NUM_SIGN |
	  SQL_FN_NUM_ACOS |
	  SQL_FN_NUM_ASIN |
	  SQL_FN_NUM_ATAN |
	  SQL_FN_NUM_ATAN2 |
	  SQL_FN_NUM_CEILING |
	  SQL_FN_NUM_COS |
	  SQL_FN_NUM_COT |
	  SQL_FN_NUM_EXP |
	  SQL_FN_NUM_FLOOR |
	  SQL_FN_NUM_LOG |
	  SQL_FN_NUM_SIN |
	  SQL_FN_NUM_SQRT |
	  SQL_FN_NUM_TAN |
	  SQL_FN_NUM_PI |
	  SQL_FN_NUM_RAND |
	  SQL_FN_NUM_DEGREES |
	  SQL_FN_NUM_LOG10 |
	  SQL_FN_NUM_POWER |
	  SQL_FN_NUM_RADIANS |
	  SQL_FN_NUM_ROUND |
	  SQL_FN_NUM_TRUNCATE;
      break;

    case SQL_STRING_FUNCTIONS:
      intres =
	  SQL_FN_STR_CONCAT |
	  SQL_FN_STR_LEFT |
	  SQL_FN_STR_LTRIM |
	  SQL_FN_STR_LENGTH |
	  SQL_FN_STR_LCASE |
	  SQL_FN_STR_REPEAT |
	  SQL_FN_STR_RIGHT |
	  SQL_FN_STR_RTRIM |
	  SQL_FN_STR_SUBSTRING |
	  SQL_FN_STR_UCASE |
	  SQL_FN_STR_ASCII |
	  SQL_FN_STR_CHAR |	/* Actually CHR, as CHAR is reserved word. */
	  SQL_FN_STR_SPACE |
	  SQL_FN_STR_POSITION |
	  SQL_FN_STR_LOCATE |
	  SQL_FN_STR_LOCATE_2;
      break;

      /* The following are still unimplemented (not in sqlbif.c)
         SQL_FN_STR_INSERT | SQL_FN_STR_REPLACE
         And the following of (ODBCVER >= 0x0200)
         SQL_FN_STR_DIFFERENCE | SQL_FN_STR_SOUNDEX */

    case SQL_SYSTEM_FUNCTIONS:
      intres =
	  SQL_FN_SYS_USERNAME |
	  SQL_FN_SYS_DBNAME |
	  SQL_FN_SYS_IFNULL;
      break;

    case SQL_TIMEDATE_FUNCTIONS:
      intres =
	  SQL_FN_TD_NOW |
	  SQL_FN_TD_CURDATE |
	  SQL_FN_TD_DAYOFMONTH |
	  SQL_FN_TD_DAYOFWEEK |
	  SQL_FN_TD_DAYOFYEAR |
	  SQL_FN_TD_MONTH |
	  SQL_FN_TD_QUARTER |
	  SQL_FN_TD_WEEK |
	  SQL_FN_TD_YEAR |
	  SQL_FN_TD_CURTIME |
	  SQL_FN_TD_HOUR |
	  SQL_FN_TD_MINUTE |
	  SQL_FN_TD_SECOND |
	  SQL_FN_TD_DAYNAME |
	  SQL_FN_TD_MONTHNAME |
	  SQL_FN_TD_TIMESTAMPADD |
	  SQL_FN_TD_TIMESTAMPDIFF |
	  SQL_FN_TD_EXTRACT;
      break;

    case SQL_TXN_ISOLATION_OPTION:
      intres =
	  SQL_TXN_READ_UNCOMMITTED |
	  SQL_TXN_REPEATABLE_READ |
	  SQL_TXN_SERIALIZABLE |
	  SQL_TXN_READ_COMMITTED;
      /* SQL_TXN_READ_UNCOMMITTED|SQL_TXN_READ_COMMITTED|SQL_TXN_VERSIONING */
      break;

    case SQL_ODBC_SQL_OPT_IEF:
      strres = "N";
      break;

    case SQL_CORRELATION_NAME:
/* The following statement works in Kubl:
    select testi.*, schwaller.* from testi testi, schwaller schwaller
    where schwaller.rivino = testi.turilas;
   AS WELL AS THIS:
    select schwaller.*, testi.rivi, schwaller.autotiming
    from testi schwaller, schwaller testi
    where testi.rivino = schwaller.turilas;
 */
      is_short = 1;
      shortres = SQL_CN_ANY;	/* SQL_CN_DIFFERENT; */
      break;

    case SQL_NON_NULLABLE_COLUMNS:
/* Changed from 0 (SQL_NNC_NULL) to 1 (SQL_NNC_NON_NULL) by AK 3-3-1997,
   although NOT NULL in column definitions still has no effect!!! */
      is_short = 1;
      shortres = SQL_NNC_NON_NULL;
      break;

/*** ODBC SDK 2.0 Additions ***/

    case SQL_DRIVER_HLIB:
      goto na;

    case SQL_DRIVER_ODBC_VER:
      strres = "03.00";
      break;

    case SQL_LOCK_TYPES:	/* SQLSetPos is not actually implemented. */
      intres =
	  SQL_LCK_NO_CHANGE |
	  SQL_LCK_EXCLUSIVE |
	  SQL_LCK_UNLOCK;
      break;

    case SQL_POS_OPERATIONS:
      intres =
	  SQL_POS_POSITION |
	  SQL_POS_REFRESH |
	  SQL_POS_UPDATE |
	  SQL_POS_DELETE |
	  SQL_POS_ADD;
      break;

    case SQL_POSITIONED_STATEMENTS:
      intres =
	  SQL_PS_POSITIONED_DELETE |
	  SQL_PS_POSITIONED_UPDATE
/*      | SQL_PS_SELECT_FOR_UPDATE */ ;
      /* The last one is commented out because otherwise JDBC Tests harness
         generates statements like following which have not been implemented
         in Kubl:
         select * from ResultSetCursor for update of val */
      break;

    case SQL_GETDATA_EXTENSIONS:
      intres =
	  SQL_GD_ANY_COLUMN |
	  SQL_GD_ANY_ORDER |
	  SQL_GD_BLOCK |
	  SQL_GD_BOUND;	/* CHECK THIS! */
      break;

    case SQL_BOOKMARK_PERSISTENCE:
      intres =
	  SQL_BP_CLOSE |
	  SQL_BP_DELETE |
	  SQL_BP_UPDATE |
	  SQL_BP_TRANSACTION |
	  SQL_BP_SCROLL |
	  SQL_BP_OTHER_HSTMT;

      break;

    case SQL_STATIC_SENSITIVITY:
      intres =
	  SQL_SS_ADDITIONS |
	  SQL_SS_DELETIONS |
	  SQL_SS_UPDATES;
      break;

    case SQL_FILE_USAGE:
      is_short = 1;
      shortres = SQL_FILE_NOT_SUPPORTED;
      break;

    case SQL_NULL_COLLATION:
      is_short = 1;
      shortres = SQL_NC_HIGH;
      break;

    case SQL_ALTER_TABLE:
      intres = SQL_AT_ADD_COLUMN;
      break;

    case SQL_COLUMN_ALIAS:
      strres = "Y";
      break;

    case SQL_GROUP_BY:
      is_short = 1;
      shortres = SQL_GB_GROUP_BY_CONTAINS_SELECT;
      break;

    case SQL_KEYWORDS:
      /* A comma separated list of all a database's SQL keywords that are NOT
         also SQL92 keywords. */
      strres = "CHAR,INT,LONG,OBJECT_ID,REPLACING,SMALLINT,SOFT,VALUES";
      break;

    case SQL_ORDER_BY_COLUMNS_IN_SELECT:
      strres = "N";
      break;

    case SQL_OWNER_USAGE:
      /* Actually no effect, but at least does not generate syntax error. */
      intres =
	  SQL_OU_DML_STATEMENTS |
	  SQL_OU_PRIVILEGE_DEFINITION;
      break;

    case SQL_QUALIFIER_USAGE:
      /* Actually no effect, but at least does not generate syntax error.
         Owner must be present too. E.g. select * from muu.kuu.luu */
      intres =
	  SQL_QU_DML_STATEMENTS |
	  SQL_QU_PRIVILEGE_DEFINITION;
      break;

    case SQL_SPECIAL_CHARACTERS:
      strres = "";
      break;

    case SQL_SUBQUERIES:
      intres =
	  SQL_SQ_EXISTS |
	  SQL_SQ_COMPARISON |
	  SQL_SQ_QUANTIFIED |
	  SQL_SQ_IN |
	  SQL_SQ_CORRELATED_SUBQUERIES;	/* Is the last one true? */
      break;

    case SQL_UNION:
      intres = 0;
      break;

    case SQL_MAX_COLUMNS_IN_GROUP_BY:
      is_short = 1;
      shortres = KUBL_ARBITRARY_MAX_VALUE1;
      break;

    case SQL_MAX_COLUMNS_IN_INDEX:
      is_short = 1;
      shortres = KUBL_ARBITRARY_MAX_VALUE1;
      break;

    case SQL_MAX_COLUMNS_IN_ORDER_BY:
      is_short = 1;
      shortres = KUBL_ARBITRARY_MAX_VALUE1;
      break;

    case SQL_MAX_COLUMNS_IN_SELECT:
      is_short = 1;
      shortres = KUBL_ARBITRARY_MAX_VALUE1;
      break;			/* Is 100 true or not ? */

    case SQL_MAX_COLUMNS_IN_TABLE:
      is_short = 1;
      shortres = 100;
      break;			/* Exact! */

    case SQL_MAX_INDEX_SIZE:
      intres = 1280;		/* Experiments support value 1280. Was 1500; */
      break;

    case SQL_MAX_ROW_SIZE_INCLUDES_LONG:
      strres = "N";
      break;

    case SQL_MAX_ROW_SIZE:
      intres = 2000;
      break;			/* Exact! */

    case SQL_MAX_STATEMENT_LEN:
      intres = KUBL_ARBITRARY_MAX_VALUE1;	/* 40000; */
      break;

    case SQL_MAX_TABLES_IN_SELECT:
      is_short = 1;
      shortres = KUBL_ARBITRARY_MAX_VALUE1;	/* 200; */
      break;

    case SQL_MAX_USER_NAME_LEN:
      is_short = 1;
      shortres = KUBL_ARBITRARY_MAX_VALUE1;	/* 250; */
      break;

    case SQL_MAX_CHAR_LITERAL_LEN:
      /* Depends on the length of whole statement? */
      intres = KUBL_ARBITRARY_MAX_VALUE1;
      break;			/* Was 2000, but can be longer, e.g. for blobs. */

    case SQL_TIMEDATE_ADD_INTERVALS:
      intres =
	  SQL_FN_TSI_SECOND |
	  SQL_FN_TSI_MINUTE |
	  SQL_FN_TSI_HOUR |
	  SQL_FN_TSI_DAY |
	  SQL_FN_TSI_MONTH |
	  SQL_FN_TSI_YEAR;
      break;

    case SQL_TIMEDATE_DIFF_INTERVALS:
      intres =
	  SQL_FN_TSI_SECOND |
	  SQL_FN_TSI_MINUTE |
	  SQL_FN_TSI_HOUR |
	  SQL_FN_TSI_DAY |
	  SQL_FN_TSI_MONTH |
	  SQL_FN_TSI_YEAR;
      break;

    case SQL_NEED_LONG_DATA_LEN:
      strres = "N";
      break;

    case SQL_MAX_BINARY_LITERAL_LEN:	/* Currently we have no */
      intres = KUBL_ARBITRARY_MAX_VALUE1;
      break;			/* binary literals like 0xDEADBEEF (intres = 8) */

    case SQL_LIKE_ESCAPE_CLAUSE:
      strres = "Y";
      break;

    case SQL_QUALIFIER_LOCATION:
      is_short = 1;
      shortres = SQL_QL_START;
      break;			/* Was: goto na; */

/************** ODBC 3 additions ***********************/
#if (ODBCVER >= 0x0300)
    case SQL_ACTIVE_ENVIRONMENTS:
      is_short = 1;
      shortres = 0;
      break;

    case SQL_AGGREGATE_FUNCTIONS:
      intres =
	  SQL_AF_ALL |
	  SQL_AF_AVG |
	  SQL_AF_COUNT |
	  SQL_AF_DISTINCT |
	  SQL_AF_MAX |
	  SQL_AF_MIN |
	  SQL_AF_SUM;
      break;

    case SQL_ALTER_DOMAIN:
      intres = 0;
      break;

    case SQL_ASYNC_MODE:
      intres = SQL_AM_NONE;
      break;

    case SQL_BATCH_ROW_COUNT:
/*		intres = SQL_BRC_PROCEDURES; */
      intres = 0;
      break;

    case SQL_BATCH_SUPPORT:
/*		intres = SQL_BS_SELECT_PROC | SQL_BS_ROW_COUNT_PROC;*/
      intres = 0;
      break;

    case SQL_CATALOG_NAME:
      strres = "Y";
      break;

    case SQL_COLLATION_SEQ:
      strres = "";
      break;

    case SQL_CREATE_ASSERTION:
      intres = 0;
      break;

    case SQL_CREATE_CHARACTER_SET:
      intres = 0;
      break;

    case SQL_CREATE_COLLATION:
      intres = 0;
      break;

    case SQL_CREATE_DOMAIN:
      intres = 0;
      break;

    case SQL_CREATE_SCHEMA:
      intres = 0;
      break;

    case SQL_CREATE_TABLE:
      intres =
	  SQL_CT_CREATE_TABLE |
	  SQL_CT_COMMIT_DELETE |
	  SQL_CT_COLUMN_DEFAULT |
	  SQL_CT_COLUMN_CONSTRAINT;
      break;

    case SQL_CREATE_TRANSLATION:
      intres = 0;
      break;

    case SQL_CREATE_VIEW:
      intres =
	  SQL_CV_CREATE_VIEW |
	  SQL_CV_CHECK_OPTION;
      break;

/*	case SQL_CURSOR_ROLLBACK_SQL_CURSOR_SENSITIVITY:
		intres = SQL_UNSPECIFIED;
		break;
*/
    case SQL_DATETIME_LITERALS:
      intres =
	  SQL_DL_SQL92_DATE |
	  SQL_DL_SQL92_TIME |
	  SQL_DL_SQL92_TIMESTAMP;
      break;

    case SQL_DDL_INDEX:
      intres =
	  SQL_DI_CREATE_INDEX |
	  SQL_DI_DROP_INDEX;
      break;

    case SQL_DESCRIBE_PARAMETER:
      strres = "N";
      break;

    case SQL_DROP_ASSERTION:
      intres = 0;
      break;

    case SQL_DROP_CHARACTER_SET:
      intres = 0;
      break;

    case SQL_DROP_COLLATION:
      intres = 0;
      break;

    case SQL_DROP_DOMAIN:
      intres = 0;
      break;

    case SQL_DROP_SCHEMA:
      intres = 0;
      break;

    case SQL_DROP_TABLE:
      intres = SQL_DT_DROP_TABLE;
      break;

    case SQL_DROP_TRANSLATION:
      intres = 0;
      break;

    case SQL_DROP_VIEW:
      intres = SQL_DV_DROP_VIEW;
      break;

    case SQL_DYNAMIC_CURSOR_ATTRIBUTES1:
      /* do not know */
      intres =
	  SQL_CA1_NEXT |
	  SQL_CA1_ABSOLUTE |
	  SQL_CA1_RELATIVE |
	  SQL_CA1_BOOKMARK |
	  SQL_CA1_LOCK_NO_CHANGE |
	  SQL_CA1_POS_POSITION |
	  SQL_CA1_POS_UPDATE |
	  SQL_CA1_POS_DELETE |
	  SQL_CA1_POS_REFRESH |
	  SQL_CA1_BULK_ADD;
      break;

    case SQL_DYNAMIC_CURSOR_ATTRIBUTES2:
      /* do not know */
      intres =
	  SQL_CA2_READ_ONLY_CONCURRENCY |
	  SQL_CA2_OPT_VALUES_CONCURRENCY |
	  SQL_CA2_SENSITIVITY_ADDITIONS |
	  SQL_CA2_SENSITIVITY_DELETIONS |
	  SQL_CA2_SENSITIVITY_UPDATES |
	  SQL_CA2_SIMULATE_UNIQUE;
      /* SQL_CA2_CRC_EXACT */
      break;

    case SQL_FORWARD_ONLY_CURSOR_ATTRIBUTES1:
      intres =
	  SQL_CA1_NEXT |
	  SQL_CA1_POS_POSITION;
      break;

    case SQL_FORWARD_ONLY_CURSOR_ATTRIBUTES2:
      intres =
	  SQL_CA2_READ_ONLY_CONCURRENCY |
	  SQL_CA2_OPT_VALUES_CONCURRENCY |
	  SQL_CA2_SENSITIVITY_ADDITIONS |
	  SQL_CA2_SENSITIVITY_DELETIONS |
	  SQL_CA2_SENSITIVITY_UPDATES |
	  SQL_CA2_SIMULATE_UNIQUE;
      break;

    case SQL_INDEX_KEYWORDS:
      intres = SQL_IK_ALL;
      break;

    case SQL_INFO_SCHEMA_VIEWS:
      /* do not know */
      intres = 0;
      break;

    case SQL_INSERT_STATEMENT:
      /* do not know */
      intres = 0;
      break;

    case SQL_KEYSET_CURSOR_ATTRIBUTES1:
      /* do not know */
      intres =
	  SQL_CA1_NEXT |
	  SQL_CA1_ABSOLUTE |
	  SQL_CA1_RELATIVE |
	  SQL_CA1_BOOKMARK |
	  SQL_CA1_LOCK_NO_CHANGE |
	  SQL_CA1_POS_POSITION |
	  SQL_CA1_POS_UPDATE |
	  SQL_CA1_POS_DELETE |
	  SQL_CA1_POS_REFRESH |
	  SQL_CA1_BULK_ADD;
      break;

    case SQL_KEYSET_CURSOR_ATTRIBUTES2:
      /* do not know */
      intres =
	  SQL_CA2_READ_ONLY_CONCURRENCY |
	  SQL_CA2_LOCK_CONCURRENCY |
	  SQL_CA2_OPT_VALUES_CONCURRENCY |
	  SQL_CA2_SENSITIVITY_ADDITIONS |
	  SQL_CA2_SENSITIVITY_DELETIONS |
	  SQL_CA2_SENSITIVITY_UPDATES |
	  SQL_CA2_SIMULATE_UNIQUE |
	  SQL_CA2_CRC_EXACT;
      break;

    case SQL_MAX_ASYNC_CONCURRENT_STATEMENTS:
      intres = 0;
      break;

    case SQL_MAX_IDENTIFIER_LEN:
      is_short = 1;
      intres = 128;
      break;

/*	case SQL_MAX_ROW_SIZE_INCLUDES_LONG:
		strres = "N";
		break;
*/

    case SQL_ODBC_INTERFACE_CONFORMANCE:
      intres = SQL_OIC_CORE;
      break;

    case SQL_PARAM_ARRAY_ROW_COUNTS:
      /* do not know */
      intres = SQL_PARC_BATCH;
      break;

    case SQL_PARAM_ARRAY_SELECTS:
      /* do not know */
      intres = SQL_PAS_BATCH;
      break;

    case SQL_SQL_CONFORMANCE:
      intres = SQL_SC_SQL92_ENTRY;
      break;

    case SQL_SQL92_DATETIME_FUNCTIONS:
      intres =
	  SQL_SDF_CURRENT_DATE |
	  SQL_SDF_CURRENT_TIME |
	  SQL_SDF_CURRENT_TIMESTAMP;
      break;

    case SQL_SQL92_FOREIGN_KEY_DELETE_RULE:
      intres = SQL_SFKD_NO_ACTION;
      break;

    case SQL_SQL92_FOREIGN_KEY_UPDATE_RULE:
      intres = SQL_SFKU_NO_ACTION;
      break;

    case SQL_SQL92_GRANT:
      intres =
	  SQL_SG_DELETE_TABLE |
	  SQL_SG_INSERT_TABLE |
	  SQL_SG_REFERENCES_TABLE |
	  SQL_SG_REFERENCES_COLUMN |
	  SQL_SG_SELECT_TABLE |
	  SQL_SG_UPDATE_COLUMN |
	  SQL_SG_UPDATE_TABLE;
      break;

    case SQL_SQL92_NUMERIC_VALUE_FUNCTIONS:
      /* do not know */
      intres = 0;
      break;

    case SQL_SQL92_PREDICATES:
      intres =
	  SQL_SP_BETWEEN |
	  SQL_SP_COMPARISON |
	  SQL_SP_EXISTS |
	  SQL_SP_IN |
	  SQL_SP_ISNOTNULL |
	  SQL_SP_ISNULL |
	  SQL_SP_LIKE;
      break;

    case SQL_SQL92_RELATIONAL_JOIN_OPERATORS:
      /* do not know */
      intres = 0;
      break;

    case SQL_SQL92_REVOKE:
      intres = 0;
      break;

    case SQL_SQL92_ROW_VALUE_CONSTRUCTOR:
      intres =
	  SQL_SRVC_VALUE_EXPRESSION |
	  SQL_SRVC_NULL;
      break;

    case SQL_SQL92_STRING_FUNCTIONS:
      intres =
	  SQL_SSF_SUBSTRING |
	  SQL_SSF_LOWER |
	  SQL_SSF_UPPER;
      break;

    case SQL_SQL92_VALUE_EXPRESSIONS:
      intres =
	  SQL_SVE_CAST |
	  SQL_SVE_CASE;
      break;

    case SQL_STANDARD_CLI_CONFORMANCE:
      intres = 0;
      break;

    case SQL_STATIC_CURSOR_ATTRIBUTES1:
      /* do not know */
      intres =
	  SQL_CA1_NEXT |
	  SQL_CA1_ABSOLUTE |
	  SQL_CA1_RELATIVE |
	  SQL_CA1_BOOKMARK |
	  SQL_CA1_LOCK_NO_CHANGE |
	  SQL_CA1_POS_POSITION |
	  SQL_CA1_POS_UPDATE |
	  SQL_CA1_POS_DELETE |
	  SQL_CA1_POS_REFRESH |
	  SQL_CA1_BULK_ADD;
      break;

    case SQL_STATIC_CURSOR_ATTRIBUTES2:
      /* do not know */
      intres =
	  SQL_CA2_READ_ONLY_CONCURRENCY |
	  SQL_CA2_OPT_VALUES_CONCURRENCY |
	  SQL_CA2_SIMULATE_UNIQUE |
	  SQL_CA2_CRC_EXACT;
      break;

    case SQL_XOPEN_CLI_YEAR:
      /* do not know */
      strres = "";
      break;
#endif

    default:
      goto na;

    }

  rc = SQL_SUCCESS;
  if (!strres && !is_short && cbInfoValueMax == 2)
    {
      is_short = 1;
      shortres = (short) intres;
    }

  if (is_short)
    {
      if (rgbInfoValue)
	*(SQLUSMALLINT *) rgbInfoValue = shortres;
      if (pcbInfoValue)
	*pcbInfoValue = 2;
      goto ret;
    }

  if (is_ulen)
    {
      if (rgbInfoValue)
	*(SQLULEN *) rgbInfoValue = ulenres;
      if (pcbInfoValue)
	*pcbInfoValue = sizeof (SQLULEN);
      goto ret;
    }

  if (strres)
    {
      if (rgbInfoValue)
	{
	  if (cbInfoValueMax > 0)
	    strncpy ((char *) rgbInfoValue, strres, cbInfoValueMax);
	  /*
	     if (cbInfoValueMax > 0)
	     ((char *)rgbInfoValue)[cbInfoValueMax - 1] = '\0'; */
	}

      if (pcbInfoValue)
	{
	  *pcbInfoValue = (SQLSMALLINT) strlen (strres);
	}

      CHECK_SI_TRUNCATED (&dbc->con_error, cbInfoValueMax, strres);
    }
  else
    {
      if (rgbInfoValue)
	*(SQLUINTEGER *) rgbInfoValue = intres;
      if (pcbInfoValue)
	*pcbInfoValue = sizeof (SQLUINTEGER);
    }

  goto ret;

na:
  set_error (&dbc->con_error, "S1009", "CL048", "Information not available.");
  rc = SQL_ERROR;

ret:
  return rc;
}


SQLRETURN SQL_API
SQLGetInfo (
	SQLHDBC hdbc,
	SQLUSMALLINT fInfoType,
	SQLPOINTER rgbInfoValue,
	SQLSMALLINT cbInfoValueMax,
	SQLSMALLINT * pcbInfoValue)
{
  CON (con, hdbc);

  switch (fInfoType)
    {
    case SQL_DATABASE_NAME:
    case SQL_DATA_SOURCE_NAME:
    case SQL_DRIVER_NAME:
    case SQL_DRIVER_VER:
    case SQL_DBMS_NAME:
    case SQL_DBMS_VER:
    case SQL_SERVER_NAME:
    case SQL_ODBC_VER:
    case SQL_ROW_UPDATES:
    case SQL_SEARCH_PATTERN_ESCAPE:
    case SQL_ACCESSIBLE_TABLES:
    case SQL_ACCESSIBLE_PROCEDURES:
    case SQL_PROCEDURES:
    case SQL_DATA_SOURCE_READ_ONLY:
    case SQL_EXPRESSIONS_IN_ORDERBY:
    case SQL_IDENTIFIER_QUOTE_CHAR:
    case SQL_MULT_RESULT_SETS:
    case SQL_MULTIPLE_ACTIVE_TXN:
    case SQL_OUTER_JOINS:
    case SQL_OWNER_TERM:
    case SQL_PROCEDURE_TERM:
    case SQL_QUALIFIER_NAME_SEPARATOR:
    case SQL_QUALIFIER_TERM:
    case SQL_TABLE_TERM:
    case SQL_USER_NAME:
    case SQL_ODBC_SQL_OPT_IEF:
    case SQL_DRIVER_ODBC_VER:
    case SQL_COLUMN_ALIAS:
    case SQL_KEYWORDS:
    case SQL_ORDER_BY_COLUMNS_IN_SELECT:
    case SQL_SPECIAL_CHARACTERS:
    case SQL_MAX_ROW_SIZE_INCLUDES_LONG:
    case SQL_NEED_LONG_DATA_LEN:
    case SQL_LIKE_ESCAPE_CLAUSE:
    case SQL_CATALOG_NAME:
    case SQL_COLLATION_SEQ:
    case SQL_DESCRIBE_PARAMETER:
    case SQL_XOPEN_CLI_YEAR:
      {
	SQLRETURN rc;
	NDEFINE_OUTPUT_NONCHAR_NARROW (rgbInfoValue, cbInfoValueMax, pcbInfoValue, con, SQLSMALLINT);

	NMAKE_OUTPUT_NONCHAR_NARROW (rgbInfoValue, cbInfoValueMax, con);

	rc = virtodbc__SQLGetInfo (hdbc, fInfoType, _rgbInfoValue, _cbInfoValueMax, _pcbInfoValue);

	NSET_AND_FREE_OUTPUT_NONCHAR_NARROW (rgbInfoValue, cbInfoValueMax, pcbInfoValue, con);

	return rc;
      }

    default:
      return virtodbc__SQLGetInfo (hdbc, fInfoType, rgbInfoValue, cbInfoValueMax, pcbInfoValue);
    }
}


SQLRETURN SQL_API
SQLGetTypeInfo (
	SQLHSTMT hstmt,
	SQLSMALLINT fSqlType)
{
  return virtodbc__SQLGetTypeInfo (hstmt, fSqlType);
}


SQLRETURN SQL_API
virtodbc__SQLGetTypeInfo (
	SQLHSTMT hstmt,
	SQLSMALLINT fSqlType)
{
  STMT (stmt, hstmt);
  SQLLEN ii = fSqlType, iil = 4;
  SQLRETURN rc;

  virtodbc__SQLSetParam (hstmt, 1, SQL_C_LONG, SQL_INTEGER, 0, 0, &ii, &iil);

  if (stmt->stmt_connection->con_environment->env_odbc_version >= 3)
    rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *) "DB.DBA.gettypeinfo3 (?, 3)", SQL_NTS);
  else
    rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *) "DB.DBA.gettypeinfo (?)", SQL_NTS);
  virtodbc__SQLFreeStmt (hstmt, SQL_RESET_PARAMS);

  return rc;
}


/*
   Called like this by getVersionColumns(null,null,"kubl_jdbc_test")
   method of the interface DatabaseMetaData of JDBC

   SQLSpecialColumns
   0x01010003
   SQL_ROWVER
   NULL
   SQL_NTS
   NULL
   SQL_NTS
   [14]kubl_jdbc_test
   SQL_NTS
   SQL_SCOPE_CURROW
   SQL_NO_NULLS
   SQL_ERROR
 */

/* Half-way implementation by AK 12-APR-1997:
   fColType must be SQL_ROWVER and fScope and fNullable are ignored.
   13-APR-1997 AK Added also SQL_BEST_ROWID functionality.

   Because SQLSpecialColumns should return the results as a standard
   result set, ordered by SCOPE, and because SCOPE is always constant
   in this implementation (0 or NULL), we can use our own additional
   sorting with ORDER BY clause.
 */
char *sql_special_columns1_casemode_0 =
"select"
" 0 AS \\SCOPE SMALLINT,"
" SYS_COLS.\\COLUMN AS \\COLUMN_NAME VARCHAR(128),"	/* NOT NULL */
" dv_to_sql_type(SYS_COLS.COL_DTP) AS \\DATA_TYPE SMALLINT,"/* NOT NULL */
" case when (SYS_COLS.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (SYS_COLS.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(SYS_COLS.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */
" case when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP in (125, 132)) then " VARCHAR_UNSPEC_SIZE "  when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP = 225) then " VARCHAR_UNSPEC_SIZE " else SYS_COLS.COL_PREC end AS \\PRECISION INTEGER,\n"
" SYS_COLS.COL_PREC AS \\LENGTH INTEGER,"
" SYS_COLS.COL_SCALE AS \\SCALE SMALLINT,"
" 1 AS \\PSEUDO_COLUMN SMALLINT "	/* = SQL_PC_NOT_PSEUDO */
"from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS,"
" DB.DBA.SYS_COLS SYS_COLS "
" where name_part(SYS_KEYS.KEY_TABLE,0) like ?"
"  and __any_grants (KEY_TABLE) "
"  and name_part(SYS_KEYS.KEY_TABLE,1) like ?"
"  and name_part(SYS_KEYS.KEY_TABLE,2) like ?"
"  and SYS_KEYS.KEY_IS_MAIN = 1"
"  and SYS_KEYS.KEY_MIGRATE_TO is NULL"
"  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID"
"  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS"
"  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL "
" order by SYS_KEYS.KEY_TABLE, SYS_KEY_PARTS.KP_NTH";

char *sql_special_columns1_casemode_2 =
"select"
" 0 AS \\SCOPE SMALLINT,"
" SYS_COLS.\\COLUMN AS \\COLUMN_NAME VARCHAR(128),"	/* NOT NULL */
" dv_to_sql_type(SYS_COLS.COL_DTP) AS \\DATA_TYPE SMALLINT,"/* NOT NULL */
" case when (SYS_COLS.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (SYS_COLS.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(SYS_COLS.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */
" case when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP in (125, 132)) then " VARCHAR_UNSPEC_SIZE "  when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP = 225) then " VARCHAR_UNSPEC_SIZE " else SYS_COLS.COL_PREC end AS \\PRECISION INTEGER,\n"
" SYS_COLS.COL_PREC AS \\LENGTH INTEGER,"
" SYS_COLS.COL_SCALE AS \\SCALE SMALLINT,"
" 1 AS \\PSEUDO_COLUMN SMALLINT "	/* = SQL_PC_NOT_PSEUDO */
"from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS,"
" DB.DBA.SYS_COLS SYS_COLS "
" where upper(name_part(SYS_KEYS.KEY_TABLE,0)) like upper(?)"
"  and __any_grants (KEY_TABLE) "
"  and upper(name_part(SYS_KEYS.KEY_TABLE,1)) like upper(?)"
"  and upper(name_part(SYS_KEYS.KEY_TABLE,2)) like upper(?)"
"  and SYS_KEYS.KEY_IS_MAIN = 1"
"  and SYS_KEYS.KEY_MIGRATE_TO is NULL"
"  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID"
"  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS"
"  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL "
" order by SYS_KEYS.KEY_TABLE, SYS_KEY_PARTS.KP_NTH";

char *sql_special_columns2_casemode_0 =
"select"
      " null as \\SCOPE smallint,"
      " \\COLUMN as \\COLUMN_NAME varchar(128),"	/* not null */
      " dv_to_sql_type(COL_DTP) as \\DATA_TYPE smallint,"	/* not null */
      " case when (SYS_COLS.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (SYS_COLS.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(SYS_COLS.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */
      " case when (c.COL_PREC = 0 and c.COL_DTP in (125, 132)) then " VARCHAR_UNSPEC_SIZE "  when (c.COL_PREC = 0 and c.COL_DTP = 225) then " VARCHAR_UNSPEC_SIZE " else c.COL_PREC end AS \\PRECISION INTEGER,\n"
      " COL_PREC as \\LENGTH integer,"
      " COL_SCALE as \\SCALE smallint,"
      " 1 as \\PSEUDO_COLUMN smallint "	/* = sql_pc_not_pseudo */
      "from DB.DBA.SYS_COLS "
      "where \\COL_DTP = 128"
      "  and name_part(\\TABLE,0) like ?"
      "  and name_part(\\TABLE,1) like ?"
      "  and name_part(\\TABLE,2) like ? "
      "order by \\TABLE, \\COL_ID";

char *sql_special_columns2_casemode_2 =
"select"
      " NULL as \\SCOPE smallint,"
      " \\COLUMN as \\COLUMN_NAME varchar(128),"	/* NOT NULL */
      " dv_to_sql_type(COL_DTP) as \\DATA_TYPE smallint,"	/* NOT NULL */
      " case when (SYS_COLS.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (SYS_COLS.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(SYS_COLS.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */
      " case when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP in (125, 132)) then " VARCHAR_UNSPEC_SIZE "  when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP = 225) then " VARCHAR_UNSPEC_SIZE " else SYS_COLS.COL_PREC end AS \\PRECISION INTEGER,\n"
      " COL_PREC as \\LENGTH integer,"
      " COL_SCALE as \\SCALE smallint,"
      " 1 as \\PSEUDO_COLUMN smallint "	/* = SQL_PC_NOT_PSEUDO */
      "from DB.DBA.SYS_COLS "
      "where \\COL_DTP = 128"
      "  and upper(name_part(\\TABLE,0)) like upper(?)"
      "  and upper(name_part(\\TABLE,1)) like upper(?)"
      "  and upper(name_part(\\TABLE,2)) like upper(?) "
      "order by \\TABLE, \\COL_ID";

char *sql_special_columnsw1_casemode_0 =
"select"
" 0 AS \\SCOPE SMALLINT,"
" charset_recode (SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128),"	/* NOT NULL */
" dv_to_sql_type(SYS_COLS.COL_DTP) AS \\DATA_TYPE SMALLINT,"/* NOT NULL */
" case when (SYS_COLS.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (SYS_COLS.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(SYS_COLS.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */
" case when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP in (125, 132)) then " VARCHAR_UNSPEC_SIZE "  when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP = 225) then " VARCHAR_UNSPEC_SIZE " else SYS_COLS.COL_PREC end AS \\PRECISION INTEGER,\n"
" SYS_COLS.COL_PREC AS \\LENGTH INTEGER,"
" SYS_COLS.COL_SCALE AS \\SCALE SMALLINT,"
" 1 AS \\PSEUDO_COLUMN SMALLINT "	/* = SQL_PC_NOT_PSEUDO */
"from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS,"
" DB.DBA.SYS_COLS SYS_COLS "
" where name_part(SYS_KEYS.KEY_TABLE,0) like ?"
"  and __any_grants (KEY_TABLE) "
"  and name_part(SYS_KEYS.KEY_TABLE,1) like ?"
"  and name_part(SYS_KEYS.KEY_TABLE,2) like ?"
"  and SYS_KEYS.KEY_IS_MAIN = 1"
"  and SYS_KEYS.KEY_MIGRATE_TO is NULL"
"  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID"
"  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS"
"  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL "
" order by SYS_KEYS.KEY_TABLE, SYS_KEY_PARTS.KP_NTH";

char *sql_special_columnsw1_casemode_2 =
"select"
" 0 AS \\SCOPE SMALLINT,"
" charset_recode (SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128),"	/* NOT NULL */
" dv_to_sql_type(SYS_COLS.COL_DTP) AS \\DATA_TYPE SMALLINT,"/* NOT NULL */
" case when (SYS_COLS.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (SYS_COLS.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(SYS_COLS.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */
" case when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP in (125, 132)) then " VARCHAR_UNSPEC_SIZE "  when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP = 225) then " VARCHAR_UNSPEC_SIZE " else SYS_COLS.COL_PREC end AS \\PRECISION INTEGER,\n"
" SYS_COLS.COL_PREC AS \\LENGTH INTEGER,"
" SYS_COLS.COL_SCALE AS \\SCALE SMALLINT,"
" 1 AS \\PSEUDO_COLUMN SMALLINT "	/* = SQL_PC_NOT_PSEUDO */
"from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS,"
" DB.DBA.SYS_COLS SYS_COLS "
" where charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
"  and __any_grants (KEY_TABLE) "
"  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
"  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
"  and SYS_KEYS.KEY_IS_MAIN = 1"
"  and SYS_KEYS.KEY_MIGRATE_TO is NULL"
"  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID"
"  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS"
"  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL "
" order by SYS_KEYS.KEY_TABLE, SYS_KEY_PARTS.KP_NTH";

char *sql_special_columnsw2_casemode_0 =
"select"
      " null as \\SCOPE smallint,"
      " charset_recode (\\COLUMN, 'UTF-8', '_WIDE_') as \\COLUMN_NAME nvarchar(128),"	/* not null */
      " dv_to_sql_type(COL_DTP) as \\DATA_TYPE smallint,"	/* not null */
      " case when (SYS_COLS.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (SYS_COLS.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(SYS_COLS.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */
      " case when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP in (125, 132)) then " VARCHAR_UNSPEC_SIZE "  when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP = 225) then " VARCHAR_UNSPEC_SIZE " else SYS_COLS.COL_PREC end AS \\PRECISION INTEGER,\n"
      " COL_PREC as \\LENGTH integer,"
      " COL_SCALE as \\SCALE smallint,"
      " 1 as \\PSEUDO_COLUMN smallint "	/* = sql_pc_not_pseudo */
      "from DB.DBA.SYS_COLS "
      "where \\COL_DTP = 128"
      "  and name_part(\\TABLE,0) like ?"
      "  and name_part(\\TABLE,1) like ?"
      "  and name_part(\\TABLE,2) like ? "
      "order by \\TABLE, \\COL_ID";

char *sql_special_columnsw2_casemode_2 =
"select"
      " NULL as \\SCOPE smallint,"
      " charset_recode (\\COLUMN, 'UTF-8', '_WIDE_') as \\COLUMN_NAME nvarchar(128),"	/* NOT NULL */
      " dv_to_sql_type(COL_DTP) as \\DATA_TYPE smallint,"	/* NOT NULL */
      " case when (SYS_COLS.COL_DTP in (125, 132) and get_keyword ('xml_col', coalesce (SYS_COLS.COL_OPTIONS, vector ())) is not null) then 'XMLType' else dv_type_title(SYS_COLS.COL_DTP) end AS TYPE_NAME VARCHAR(128),\n" /* DV_BLOB=125, DV_BLOB_WIDE=132 */
      " case when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP in (125, 132)) then " VARCHAR_UNSPEC_SIZE "  when (SYS_COLS.COL_PREC = 0 and SYS_COLS.COL_DTP = 225) then " VARCHAR_UNSPEC_SIZE " else SYS_COLS.COL_PREC end AS \\PRECISION INTEGER,\n"
      " COL_PREC as \\LENGTH integer,"
      " COL_SCALE as \\SCALE smallint,"
      " 1 as \\PSEUDO_COLUMN smallint "	/* = SQL_PC_NOT_PSEUDO */
      "from DB.DBA.SYS_COLS "
      "where \\COL_DTP = 128"
      "  and charset_recode (upper(charset_recode (name_part(\\TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
      "  and charset_recode (upper(charset_recode (name_part(\\TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
      "  and charset_recode (upper(charset_recode (name_part(\\TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') "
      "order by \\TABLE, \\COL_ID";


SQLRETURN SQL_API
virtodbc__SQLSpecialColumns (
	SQLHSTMT hstmt,
	SQLUSMALLINT fColType,
	SQLCHAR * szTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * szTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * szTableName,
	SQLSMALLINT cbTableName,
	SQLUSMALLINT fScope, /* SQL_SCOPE_CURROW, _TRANSACTION or _SESSION */
	SQLUSMALLINT fNullable) /* SQL_NO_NULLS or SQL_NULLABLE. <- Ignored ^ */
{
  STMT (stmt, hstmt);
  SQLRETURN rc;
  SQLCHAR *percent = (SQLCHAR *) "%";
  SQLLEN plen = SQL_NTS;
  SQLLEN cbqual = cbTableQualifier, cbown = cbTableOwner, cbtab = cbTableName;
  char _szTableQualifier[KUBL_IDENTIFIER_MAX_LENGTH],
      _szTableOwner[KUBL_IDENTIFIER_MAX_LENGTH], _szTableName[KUBL_IDENTIFIER_MAX_LENGTH];

  if (is_empty_or_null (szTableQualifier, cbTableQualifier))
    {
      szTableQualifier = NULL;
      _szTableQualifier[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableQualifier, _szTableQualifier, sizeof (_szTableQualifier), &cbqual, cbTableQualifier);

  if (is_empty_or_null (szTableOwner, cbTableOwner))
    {
      szTableOwner = NULL;
      _szTableOwner[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableOwner, _szTableOwner, sizeof (_szTableOwner), &cbown, cbTableOwner);

  if (is_empty_or_null (szTableName, cbTableName))
    {
      szTableName = NULL;
      _szTableName[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableName, _szTableName, sizeof (_szTableName), &cbtab, cbTableName);

  DEFAULT_QUAL (stmt, cbqual);

  virtodbc__SQLSetParam (hstmt, 1, SQL_C_CHAR, SQL_CHAR, 0, 0, szTableQualifier ? (SQLCHAR *) _szTableQualifier : percent, szTableQualifier ? &cbqual : &plen);
  virtodbc__SQLSetParam (hstmt, 2, SQL_C_CHAR, SQL_CHAR, 0, 0, szTableOwner ? (SQLCHAR *) _szTableOwner : percent, szTableOwner ? &cbown : &plen);
  virtodbc__SQLSetParam (hstmt, 3, SQL_C_CHAR, SQL_CHAR, 0, 0, szTableName ? (SQLCHAR *) _szTableName : percent, szTableName ? &cbtab : &plen);

  if (SQL_ROWVER != fColType)
    {
/*
   fColType must be one of the following values:
   SQL_BEST_ROWID: Returns the optimal column or set of columns that,
   by retrieving values from the column or columns, allows any row in
   the specified table to be uniquely identified. A column can be either
   a pseudocolumn specifically designed for this purpose
   (as in Oracle ROWID or Ingres TID) or the column or columns of any
   unique index for the table.

   Well, we implement this later better. Now just choose all the columns
   of the primary key.
   (0 = SQL_SCOPE_CURROW) Let's use the most narrow scope as I am not
   really sure about this. fScope argument is
   ignored anyway.
   (1 = SQL_SCOPE_TRANSACTION)
   (2 = SQL_SCOPE_SESSION)
 */
      if (stmt->stmt_connection->con_defs.cdef_utf8_execs)
	rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	    (stmt->stmt_connection->con_db_casemode == 2 ?
		sql_special_columnsw1_casemode_2 : sql_special_columnsw1_casemode_0), SQL_NTS);
      else
	rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	    (stmt->stmt_connection->con_db_casemode == 2 ?
		sql_special_columns1_casemode_2 : sql_special_columns1_casemode_0), SQL_NTS);
      /* With KP_NTH returns columns in the same order as they are in the
         primary key. */
    }
  else
    {
/*
   fColType is SQL_ROWVER: Returns the column or columns in the
   specified table, if any, that are automatically updated by the
   data source when any value in the row is updated by any transaction
   as in SQLBase ROWID or Sybase (and KUBL!) TIMESTAMP (= COL_DTP 128).
 */
      if (stmt->stmt_connection->con_defs.cdef_utf8_execs)
	rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	    (stmt->stmt_connection->con_db_casemode == 2 ?
		sql_special_columnsw2_casemode_2 : sql_special_columnsw2_casemode_0), SQL_NTS);
      else
	rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	    (stmt->stmt_connection->con_db_casemode == 2 ?
		sql_special_columns2_casemode_2 : sql_special_columns2_casemode_0), SQL_NTS);
      /* With COL_ID returns columns in the same order as they were defined
         with create table. Without it they would be in alphabetical order. */
    }

  virtodbc__SQLFreeStmt (hstmt, SQL_RESET_PARAMS);

  return rc;
}


SQLRETURN SQL_API
SQLSpecialColumns (
	SQLHSTMT hstmt,
	SQLUSMALLINT fColType,
	SQLCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * wszTableName,
	SQLSMALLINT cbTableName,
	SQLUSMALLINT fScope, /* SQL_SCOPE_CURROW, _TRANSACTION or _SESSION */
	SQLUSMALLINT fNullable) /* SQL_NO_NULLS or SQL_NULLABLE. <- Ignored ^ */
{
  SQLRETURN rc;
  size_t len;
  STMT (stmt, hstmt);
  NDEFINE_INPUT_NARROW (TableQualifier);
  NDEFINE_INPUT_NARROW (TableOwner);
  NDEFINE_INPUT_NARROW (TableName);

  NMAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableName, stmt->stmt_connection);

  rc = virtodbc__SQLSpecialColumns (hstmt, fColType,
      szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName, fScope, fNullable);

  NFREE_INPUT_NARROW (TableQualifier);
  NFREE_INPUT_NARROW (TableOwner);
  NFREE_INPUT_NARROW (TableName);

  return rc;
}


/*
   AK 17-JAN-1996 -- NOT THE FULL IMPLEMENTATION, BUT ENOUGH FOR DBDUMP

   SQLStatistics returns information about a single table as a standard
   result set, ordered by NON_UNIQUE, TYPE, INDEX_QUALIFIER, INDEX_NAME,
   and SEQ_IN_INDEX.
   (Well, here we order it by TABLE_NAME, INDEX_NAME and SEQ_IN_INDEX).

   Column Name  Data Type       Comments
   TABLE_QUALIFIER   Varchar(128)       Table qualifier identifier of the table
   to which the statistic or index applies;
   NULL if not applicable to the data source.
   If a driver supports qualifiers for
   some tables but not for others, such as
   when the driver retrieves data from
   different DBMSs, it returns an empty
   string ("") for those tables that do
   not have qualifiers. (ALWAYS 'db').
   TABLE_OWNER       Varchar(128)       Table owner identifier of the table to
   which the statistic or index applies;
   NULL if not applicable to the data source.
   If a driver ... see above. (ALWAYS 'dba')
   TABLE_NAME	Varchar(128) not NULL  Table identifier of the table.
   NON_UNIQUE	Smallint	  Indicates whether the index prohibits
   duplicate values: TRUE (1) if the index
   values can be nonunique. FALSE (0) if
   the index values must be unique. NULL
   is returned if TYPE is SQL_TABLE_STAT.
   INDEX_QUALIFIER   Varchar(128)       The identifier that is used to qualify
   the index name doing a DROP INDEX;
   NULL is returned if an index qualifier
   is not supported by the data source or
   if TYPE is SQL_TABLE_STAT.
   If a non-null value is returned in
   this column, it must be used to qualify
   the index name on a DROP INDEX statement;
   otherwise the TABLE_OWNER name should be
   used to qualify the index name.
   INDEX_NAME	Varchar(128)      Index identifier; NULL if SQL_TABLE_STAT.
   TYPE	      Smallint not NULL Type of information being returned:
   SQL_TABLE_STAT      0 (stats for table)
   SQL_INDEX_CLUSTERED 1
   SQL_INDEX_HASHED    2
   SQL_INDEX_OTHER     3 (we return this
   unless the index is clustered)

   SEQ_IN_INDEX      Smallint	  Column sequence number in index (1-based)
   NULL for SQL_TABLE_STAT.
   COLUMN_NAME       Varchar(128)       Column identifier. If the column is
   based on an expression, such as
   SALARY + BENEFITS, the expression is
   returned; if the expression cannot be
   determined, an empty string is returned.
   If the index is a filtered index, each
   column in the filter condition is returned;
   this may require more than one row.
   NULL is returned for SQL_TABLE_STAT.
   COLLATION	 Char(1)	   Sort sequence for the column; "A" for
   ascending; "D" for descending; NULL is
   returned if column sort sequence is not
   supported by the data source.
   CARDINALITY       Integer	   Cardinality of table or index; number of
   rows in table if TYPE is SQL_TABLE_STAT;
   number of unique values in the index if
   TYPE is not SQL_TABLE_STAT; NULL is
   returned if the value is not available
   from the data source.
   PAGES	     Integer	   Number of pages for the table if TYPE
   is SQL_TABLE_STAT; number of pages for
   the index if TYPE is not SQL_TABLE_STAT;
   NULL is returned if the value is not
   available from the data source, or if
   not applicable to the data source.
   FILTER_CONDITION  Varchar(128)      If the index is a filtered index, this
   is the filter condition, such as
   SALARY > 30000; if the filter condition
   cannot be determined, this is an empty
   string. NULL if the index is not a
   filtered index, it cannot be determined
   whether the index is a filtered index,
   or TYPE is SQL_TABLE_STAT.


   If the row in the result set corresponds to a table, the driver sets
   TYPE to SQL_TABLE_STAT and sets NON_UNIQUE, INDEX_QUALIFIER, INDEX_NAME,
   SEQ_IN_INDEX, COLUMN_NAME, and COLLATION  to NULL. If CARDINALITY or
   PAGES are not available from the data source, the driver sets them to
   NULL.

   Note that the row returning statistics for the table itself
   (when TYPE = SQL_TABLE_STAT) has not been implemented here.

   Citation from KUBLMAN.DOC (referring to tables SYS_KEYS and SYS_KEY_PARTS):

   The KEY_CLUSTER_ON_ID column is the clustering ID of the key. If this
   is zero the key is clustered by value. KEY_IS_MAIN is non-zero if this
   is the primary key of its table. The KEY_MIGRATE_TO is the key ID of a
   new version of this key if this key is obsolete (e.g. the primary key
   of a table from before an ALTER TABLE). The KEY_N_SIGNIFICANT indicates
   how many leading key parts are used in ordering keys.

   The KEY_ID references the KP_KEY_ID in the SYS_KEY_PARTS table. This
   table embodies the actual layout of keys and rows. The KP_NTH is a
   number positioning the KP_COL to the appropriate place in the row.
   The KP_COL references the COL_ID in SYS_COLS. The KP_NTH is NOT
   NECESSARILY a series of CONSECUTIVE INTEGERS but the order matches
   the order of columns on the row.

   However, we hope here that in the most of cases it is a series of
   consecutive integers, so that (KP_NTH+1) used below would work correctly.

   20.JAN.1997 AK Added a where-clause "and KEY_MIGRATE_TO is NULL"
   to avoid fetching obsolete keys from the SYS_KEYS table.

   20.FEB.1997 AK Added OBJECT_ID stuff below.

 */

char *sql_statistics_text_casemode_0 =
"select"
" name_part(SYS_KEYS.KEY_TABLE,0) AS \\TABLE_QUALIFIER VARCHAR(128),\n"
" name_part(SYS_KEYS.KEY_TABLE,1) AS \\TABLE_OWNER VARCHAR(128),\n"
" name_part(SYS_KEYS.KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128),\n"/* NOT NULL */
" iszero(SYS_KEYS.KEY_IS_UNIQUE) AS \\NON_UNIQUE SMALLINT,\n"
" name_part (SYS_KEYS.KEY_TABLE, 0) AS \\INDEX_QUALIFIER VARCHAR(128),\n"
" name_part (SYS_KEYS.KEY_NAME, 2) AS \\INDEX_NAME VARCHAR(128),\n"
" ((coalesce (SYS_KEYS.KEY_IS_OBJECT_ID, 0)*" SQL_INDEX_OBJECT_ID_STR ") + \n"
"(3-(2*iszero(SYS_KEYS.KEY_CLUSTER_ON_ID)))) AS \\TYPE SMALLINT,\n" /* NOT NULL */
" (SYS_KEY_PARTS.KP_NTH+1) AS \\SEQ_IN_INDEX SMALLINT,\n"
" SYS_COLS.\\COLUMN AS \\COLUMN_NAME VARCHAR(128),\n"
" NULL AS \\COLLATION CHAR(1),\n"	/* Value is either NULL, 'A' or 'D' */
" (case when SYS_KEYS.KEY_IS_MAIN = 1 and subseq (sys_stat ('st_dbms_ver'), 6) >= '2704' and \n"
"        key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') <> -1\n"
"           then key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') \n"
"           else NULL end) AS \\CARDINALITY INTEGER,\n"
" NULL AS \\PAGES INTEGER,\n"
" NULL AS \\FILTER_CONDITION VARCHAR(128) \n"
"from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS,\n"
" DB.DBA.SYS_COLS SYS_COLS \n"
"where name_part(SYS_KEYS.KEY_TABLE,0) like ?\n"
"  and __any_grants (SYS_KEYS.KEY_TABLE) \n"
"  and name_part(SYS_KEYS.KEY_TABLE,1) like ?\n"
"  and name_part(SYS_KEYS.KEY_TABLE,2) like ?\n"
"  and SYS_KEYS.KEY_IS_UNIQUE >= ?\n"
"  and SYS_KEYS.KEY_MIGRATE_TO is NULL\n"
"  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID\n"
"  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS\n"
"  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL\n"
"  and SYS_COLS.\\COLUMN <> '_IDN' \n"
"union all \n"
"select\n"
" name_part(SYS_KEYS.KEY_TABLE,0) AS \\TABLE_QUALIFIER VARCHAR(128),\n"
" name_part(SYS_KEYS.KEY_TABLE,1) AS \\TABLE_OWNER VARCHAR(128),\n"
" name_part(SYS_KEYS.KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128),\n"/* NOT NULL */
" NULL AS \\NON_UNIQUE SMALLINT,\n"
" NULL AS \\INDEX_QUALIFIER VARCHAR(128),\n"
" NULL AS \\INDEX_NAME VARCHAR(128),\n"
" 0 AS \\TYPE SMALLINT,\n" /* NOT NULL */
" NULL AS \\SEQ_IN_INDEX SMALLINT,\n"
" NULL AS \\COLUMN_NAME VARCHAR(128),\n"
" NULL AS \\COLLATION CHAR(1),\n"	/* Value is either NULL, 'A' or 'D' */
" (case when subseq (sys_stat ('st_dbms_ver'), 6) >= '2704' and \n"
"        key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') <> -1\n"
"           then key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') \n"
"           else NULL end) AS \\CARDINALITY INTEGER,\n"
" NULL AS \\PAGES INTEGER,\n"
" NULL AS \\FILTER_CONDITION VARCHAR(128) \n"
"from DB.DBA.SYS_KEYS SYS_KEYS\n"
"where name_part(SYS_KEYS.KEY_TABLE,0) like ?\n"
"  and __any_grants (SYS_KEYS.KEY_TABLE) \n"
"  and name_part(SYS_KEYS.KEY_TABLE,1) like ?\n"
"  and name_part(SYS_KEYS.KEY_TABLE,2) like ?\n"
"  and SYS_KEYS.KEY_IS_MAIN = 1\n"
"  and SYS_KEYS.KEY_MIGRATE_TO is NULL\n"
"order by 7,1,2,3,6,8";

char *sql_statistics_text_casemode_2 =
"select\n"
" name_part(SYS_KEYS.KEY_TABLE,0) AS \\TABLE_QUALIFIER VARCHAR(128),\n"
" name_part(SYS_KEYS.KEY_TABLE,1) AS \\TABLE_OWNER VARCHAR(128),\n"
" name_part(SYS_KEYS.KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128),\n"/* NOT NULL */
" iszero(SYS_KEYS.KEY_IS_UNIQUE) AS \\NON_UNIQUE SMALLINT,\n"
" name_part (SYS_KEYS.KEY_TABLE, 0) AS \\INDEX_QUALIFIER VARCHAR(128),\n"
" name_part (SYS_KEYS.KEY_NAME, 2) AS \\INDEX_NAME VARCHAR(128),\n"
" ((coalesce (SYS_KEYS.KEY_IS_OBJECT_ID, 0)*" SQL_INDEX_OBJECT_ID_STR ") + \n"
"(3-(2*iszero(SYS_KEYS.KEY_CLUSTER_ON_ID)))) AS \\TYPE SMALLINT,\n" /* NOT NULL */
" (SYS_KEY_PARTS.KP_NTH+1) AS \\SEQ_IN_INDEX SMALLINT,\n"
" SYS_COLS.\\COLUMN AS \\COLUMN_NAME VARCHAR(128),\n"
" NULL AS \\COLLATION CHAR(1),\n"	/* Value is either NULL, 'A' or 'D' */
" (case when SYS_KEYS.KEY_IS_MAIN = 1 and subseq (sys_stat ('st_dbms_ver'), 6) >= '2704' and \n"
"        key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') <> -1\n"
"           then key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') \n"
"           else NULL end) AS \\CARDINALITY INTEGER,\n"
" NULL AS \\PAGES INTEGER,\n"
" NULL AS \\FILTER_CONDITION VARCHAR(128) \n"
"from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS,\n"
" DB.DBA.SYS_COLS SYS_COLS \n"
"where upper(name_part(SYS_KEYS.KEY_TABLE,0)) like upper(?)\n"
"  and __any_grants (SYS_KEYS.KEY_TABLE) \n"
"  and upper(name_part(SYS_KEYS.KEY_TABLE,1)) like upper(?)\n"
"  and upper(name_part(SYS_KEYS.KEY_TABLE,2)) like upper(?)\n"
"  and SYS_KEYS.KEY_IS_UNIQUE >= ?\n"
"  and SYS_KEYS.KEY_MIGRATE_TO is NULL\n"
"  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID\n"
"  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS\n"
"  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL\n"
"  and SYS_COLS.\\COLUMN <> '_IDN' \n"
"union all \n"
"select\n"
" name_part(SYS_KEYS.KEY_TABLE,0) AS \\TABLE_QUALIFIER VARCHAR(128),\n"
" name_part(SYS_KEYS.KEY_TABLE,1) AS \\TABLE_OWNER VARCHAR(128),\n"
" name_part(SYS_KEYS.KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128),\n"/* NOT NULL */
" NULL AS \\NON_UNIQUE SMALLINT,\n"
" NULL AS \\INDEX_QUALIFIER VARCHAR(128),\n"
" NULL AS \\INDEX_NAME VARCHAR(128),\n"
" 0 AS \\TYPE SMALLINT,\n" /* NOT NULL */
" NULL AS \\SEQ_IN_INDEX SMALLINT,\n"
" NULL AS \\COLUMN_NAME VARCHAR(128),\n"
" NULL AS \\COLLATION CHAR(1),\n"	/* Value is either NULL, 'A' or 'D' */
" (case when subseq (sys_stat ('st_dbms_ver'), 6) >= '2704' and \n"
"        key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') <> -1\n"
"           then key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') \n"
"           else NULL end) AS \\CARDINALITY INTEGER,\n"
" NULL AS \\PAGES INTEGER,\n"
" NULL AS \\FILTER_CONDITION VARCHAR(128) \n"
"from DB.DBA.SYS_KEYS SYS_KEYS\n"
"where upper(name_part(SYS_KEYS.KEY_TABLE,0)) like upper(?)\n"
"  and __any_grants (SYS_KEYS.KEY_TABLE) \n"
"  and upper(name_part(SYS_KEYS.KEY_TABLE,1)) like upper(?)\n"
"  and upper(name_part(SYS_KEYS.KEY_TABLE,2)) like upper(?)\n"
"  and SYS_KEYS.KEY_IS_MAIN = 1\n"
"  and SYS_KEYS.KEY_MIGRATE_TO is NULL\n"
"order by 7,1,2,3,6,8";

char *sql_statistics_textw_casemode_0 =
"select\n"
" charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_QUALIFIER NVARCHAR(128),\n"
" charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_OWNER NVARCHAR(128),\n"
" charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128),\n"/* NOT NULL */
" iszero(SYS_KEYS.KEY_IS_UNIQUE) AS \\NON_UNIQUE SMALLINT,\n"
" charset_recode (name_part (SYS_KEYS.KEY_TABLE, 0), 'UTF-8', '_WIDE_') AS \\INDEX_QUALIFIER NVARCHAR(128),\n"
" charset_recode (name_part (SYS_KEYS.KEY_NAME, 2), 'UTF-8', '_WIDE_') AS \\INDEX_NAME NVARCHAR(128),\n"
" ((coalesce (SYS_KEYS.KEY_IS_OBJECT_ID,0)*" SQL_INDEX_OBJECT_ID_STR ") + \n"
"(3-(2*iszero(SYS_KEYS.KEY_CLUSTER_ON_ID)))) AS \\TYPE SMALLINT,\n" /* NOT NULL */
" (SYS_KEY_PARTS.KP_NTH+1) AS \\SEQ_IN_INDEX SMALLINT,\n"
" charset_recode (SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128),\n"
" NULL AS \\COLLATION CHAR(1),\n"	/* Value is either NULL, 'A' or 'D' */
" (case when SYS_KEYS.KEY_IS_MAIN = 1 and subseq (sys_stat ('st_dbms_ver'), 6) >= '2704' and \n"
"        key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') <> -1\n"
"           then key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') \n"
"           else NULL end) AS \\CARDINALITY INTEGER,\n"
" NULL AS \\PAGES INTEGER,\n"
" NULL AS \\FILTER_CONDITION VARCHAR(128) \n"
"from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS,\n"
" DB.DBA.SYS_COLS SYS_COLS \n"
"where name_part(SYS_KEYS.KEY_TABLE,0) like ?\n"
"  and __any_grants (SYS_KEYS.KEY_TABLE) \n"
"  and name_part(SYS_KEYS.KEY_TABLE,1) like ?\n"
"  and name_part(SYS_KEYS.KEY_TABLE,2) like ?\n"
"  and SYS_KEYS.KEY_IS_UNIQUE >= ?\n"
"  and SYS_KEYS.KEY_MIGRATE_TO is NULL\n"
"  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID\n"
"  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS\n"
"  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL\n"
"  and SYS_COLS.\\COLUMN <> '_IDN' \n"
"union all \n"
"select\n"
" charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_QUALIFIER NVARCHAR(128),\n"
" charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_OWNER NVARCHAR(128),\n"
" charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128),\n"/* NOT NULL */
" NULL AS \\NON_UNIQUE SMALLINT,\n"
" NULL AS \\INDEX_QUALIFIER VARCHAR(128),\n"
" NULL AS \\INDEX_NAME VARCHAR(128),\n"
" 0 AS \\TYPE SMALLINT,\n" /* NOT NULL */
" NULL AS \\SEQ_IN_INDEX SMALLINT,\n"
" NULL AS \\COLUMN_NAME VARCHAR(128),\n"
" NULL AS \\COLLATION CHAR(1),\n"	/* Value is either NULL, 'A' or 'D' */
" (case when subseq (sys_stat ('st_dbms_ver'), 6) >= '2704' and \n"
"        key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') <> -1\n"
"           then key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') \n"
"           else NULL end) AS \\CARDINALITY INTEGER,\n"
" NULL AS \\PAGES INTEGER,\n"
" NULL AS \\FILTER_CONDITION VARCHAR(128) \n"
"from DB.DBA.SYS_KEYS SYS_KEYS\n"
"where name_part(SYS_KEYS.KEY_TABLE,0) like ?\n"
"  and __any_grants (SYS_KEYS.KEY_TABLE) \n"
"  and name_part(SYS_KEYS.KEY_TABLE,1) like ?\n"
"  and name_part(SYS_KEYS.KEY_TABLE,2) like ?\n"
"  and SYS_KEYS.KEY_IS_MAIN = 1\n"
"  and SYS_KEYS.KEY_MIGRATE_TO is NULL\n"
"order by 7,1,2,3,6,8";

char *sql_statistics_textw_casemode_2 =
"select\n"
" charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_QUALIFIER NVARCHAR(128),\n"
" charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_OWNER NVARCHAR(128),\n"
" charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128),\n"/* NOT NULL */
" iszero(SYS_KEYS.KEY_IS_UNIQUE) AS \\NON_UNIQUE SMALLINT,\n"
" charset_recode (name_part (SYS_KEYS.KEY_TABLE, 0), 'UTF-8', '_WIDE_') AS \\INDEX_QUALIFIER NVARCHAR(128),\n"
" charset_recode (name_part (SYS_KEYS.KEY_NAME, 2), 'UTF-8', '_WIDE_') AS \\INDEX_NAME NVARCHAR(128),\n"
" ((coalesce (SYS_KEYS.KEY_IS_OBJECT_ID,0)*" SQL_INDEX_OBJECT_ID_STR ") + \n"
"(3-(2*iszero(SYS_KEYS.KEY_CLUSTER_ON_ID)))) AS \\TYPE SMALLINT,\n" /* NOT NULL */
" (SYS_KEY_PARTS.KP_NTH+1) AS \\SEQ_IN_INDEX SMALLINT,\n"
" charset_recode (SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128),\n"
" NULL AS \\COLLATION CHAR(1),\n"	/* Value is either NULL, 'A' or 'D' */
" (case when SYS_KEYS.KEY_IS_MAIN = 1 and subseq (sys_stat ('st_dbms_ver'), 6) >= '2704' and \n"
"        key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') <> -1\n"
"           then key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') \n"
"           else NULL end) AS \\CARDINALITY INTEGER,\n"
" NULL AS \\PAGES INTEGER,\n"
" NULL AS \\FILTER_CONDITION VARCHAR(128) \n"
"from DB.DBA.SYS_KEYS SYS_KEYS, DB.DBA.SYS_KEY_PARTS SYS_KEY_PARTS,\n"
" DB.DBA.SYS_COLS SYS_COLS \n"
"where charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')\n"
"  and __any_grants (SYS_KEYS.KEY_TABLE) \n"
"  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')\n"
"  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')\n"
"  and SYS_KEYS.KEY_IS_UNIQUE >= ?\n"
"  and SYS_KEYS.KEY_MIGRATE_TO is NULL\n"
"  and SYS_KEY_PARTS.KP_KEY_ID = SYS_KEYS.KEY_ID\n"
"  and SYS_KEY_PARTS.KP_NTH < SYS_KEYS.KEY_DECL_PARTS\n"
"  and SYS_COLS.COL_ID = SYS_KEY_PARTS.KP_COL\n"
"  and SYS_COLS.\\COLUMN <> '_IDN' \n"
"union all \n"
"select\n"
" charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_QUALIFIER NVARCHAR(128),\n"
" charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_OWNER NVARCHAR(128),\n"
" charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128),\n"/* NOT NULL */
" NULL AS \\NON_UNIQUE SMALLINT,\n"
" NULL AS \\INDEX_QUALIFIER VARCHAR(128),\n"
" NULL AS \\INDEX_NAME VARCHAR(128),\n"
" 0 AS \\TYPE SMALLINT,\n" /* NOT NULL */
" NULL AS \\SEQ_IN_INDEX SMALLINT,\n"
" NULL AS \\COLUMN_NAME VARCHAR(128),\n"
" NULL AS \\COLLATION CHAR(1),\n"	/* Value is either NULL, 'A' or 'D' */
" (case when subseq (sys_stat ('st_dbms_ver'), 6) >= '2704' and \n"
"        key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') <> -1\n"
"           then key_stat (SYS_KEYS.KEY_TABLE, name_part (SYS_KEYS.KEY_NAME, 2), 'n_rows') \n"
"           else NULL end) AS \\CARDINALITY INTEGER,\n"
" NULL AS \\PAGES INTEGER,\n"
" NULL AS \\FILTER_CONDITION VARCHAR(128) \n"
"from DB.DBA.SYS_KEYS SYS_KEYS\n"
"where charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')\n"
"  and __any_grants (SYS_KEYS.KEY_TABLE) \n"
"  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')\n"
"  and charset_recode (upper(charset_recode (name_part(SYS_KEYS.KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')\n"
"  and SYS_KEYS.KEY_IS_MAIN = 1\n"
"  and SYS_KEYS.KEY_MIGRATE_TO is NULL\n"
"order by 7,1,2,3,6,8";

SQLRETURN SQL_API
virtodbc__SQLStatistics (
	SQLHSTMT hstmt,
	SQLCHAR * szTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * szTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * szTableName,
	SQLSMALLINT cbTableName,
	SQLUSMALLINT fUnique,/* Type of index SQL_INDEX_UNIQUE or SQL_INDEX_ALL */
	SQLUSMALLINT fAccuracy) /* SQL_ENSURE or SQL_QUICK, currently ignored. */
{
  STMT (stmt, hstmt);
  SQLRETURN rc;
  SQLCHAR *percent = (SQLCHAR *) "%";
  SQLLEN plen = SQL_NTS;
  SQLSMALLINT uniques_only = (fUnique == SQL_INDEX_UNIQUE);	/* Either 1 or 0 */
  SQLLEN cb_uniques_only = 0;
  SQLLEN cbqual = cbTableQualifier, cbown = cbTableOwner, cbtab = cbTableName;
  char _szTableQualifier[KUBL_IDENTIFIER_MAX_LENGTH],
      _szTableOwner[KUBL_IDENTIFIER_MAX_LENGTH], _szTableName[KUBL_IDENTIFIER_MAX_LENGTH];

  if (is_empty_or_null (szTableQualifier, cbTableQualifier))
    {
      szTableQualifier = NULL;
      _szTableQualifier[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableQualifier, _szTableQualifier, sizeof (_szTableQualifier), &cbqual, cbTableQualifier);

  if (is_empty_or_null (szTableOwner, cbTableOwner))
    {
      szTableOwner = NULL;
      _szTableOwner[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableOwner, _szTableOwner, sizeof (_szTableOwner), &cbown, cbTableOwner);

  if (is_empty_or_null (szTableName, cbTableName))
    {
      szTableName = NULL;
      _szTableName[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableName, _szTableName, sizeof (_szTableName), &cbtab, cbTableName);

  DEFAULT_QUAL (stmt, cbqual);

  virtodbc__SQLSetParam (hstmt, 1, SQL_C_CHAR, SQL_CHAR, 0, 0, szTableQualifier ? (SQLCHAR *) _szTableQualifier : percent, szTableQualifier ? &cbqual : &plen);
  virtodbc__SQLSetParam (hstmt, 2, SQL_C_CHAR, SQL_CHAR, 0, 0, szTableOwner ? (SQLCHAR *) _szTableOwner : percent, szTableOwner ? &cbown : &plen);
  virtodbc__SQLSetParam (hstmt, 3, SQL_C_CHAR, SQL_CHAR, 0, 0, szTableName ? (SQLCHAR *) _szTableName : percent, szTableName ? &cbtab : &plen);
  virtodbc__SQLSetParam (hstmt, 4, SQL_C_SSHORT, SQL_INTEGER, 0, 0, &uniques_only, &cb_uniques_only);
  virtodbc__SQLSetParam (hstmt, 5, SQL_C_CHAR, SQL_CHAR, 0, 0, szTableQualifier ? (SQLCHAR *) _szTableQualifier : percent, szTableQualifier ? &cbqual : &plen);
  virtodbc__SQLSetParam (hstmt, 6, SQL_C_CHAR, SQL_CHAR, 0, 0, szTableOwner ? (SQLCHAR *) _szTableOwner : percent, szTableOwner ? &cbown : &plen);
  virtodbc__SQLSetParam (hstmt, 7, SQL_C_CHAR, SQL_CHAR, 0, 0, szTableName ? (SQLCHAR *) _szTableName : percent, szTableName ? &cbtab : &plen);

  if (stmt->stmt_connection->con_defs.cdef_utf8_execs)
    rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	(stmt->stmt_connection->con_db_casemode == 2 ? sql_statistics_textw_casemode_2 : sql_statistics_textw_casemode_0), SQL_NTS);
  else
    rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	(stmt->stmt_connection->con_db_casemode == 2 ? sql_statistics_text_casemode_2 : sql_statistics_text_casemode_0), SQL_NTS);

  virtodbc__SQLFreeStmt (hstmt, SQL_RESET_PARAMS);

  return rc;
}


SQLRETURN SQL_API
SQLStatistics (
	SQLHSTMT hstmt,
	SQLCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * wszTableName,
	SQLSMALLINT cbTableName,
	SQLUSMALLINT fUnique,/* Type of index SQL_INDEX_UNIQUE or SQL_INDEX_ALL */
	SQLUSMALLINT fAccuracy) /* SQL_ENSURE or SQL_QUICK, currently ignored. */
{
  SQLRETURN rc;
  size_t len;
  STMT (stmt, hstmt);
  NDEFINE_INPUT_NARROW (TableQualifier);
  NDEFINE_INPUT_NARROW (TableOwner);
  NDEFINE_INPUT_NARROW (TableName);

  NMAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableName, stmt->stmt_connection);

  rc = virtodbc__SQLStatistics (hstmt,
      szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName, fUnique, fAccuracy);

  NFREE_INPUT_NARROW (TableQualifier);
  NFREE_INPUT_NARROW (TableOwner);
  NFREE_INPUT_NARROW (TableName);

  return rc;
}


#if 0
SQLRETURN SQL_API SQLDrivers (
	SQLHENV henv,
	SQLUSMALLINT fDirection,
	SQLCHAR * szDriverDesc,
	SQLSMALLINT cbDriverDescMax,
	SQLSMALLINT * pcbDriverDesc,
	SQLCHAR * szDriverAttributes,
	SQLSMALLINT cbDrvrAttrMax,
	SQLSMALLINT * pcbDrvrAttr)
{
  NOT_IMPL_FUN (henv, "Function not supported: SQLDrivers");
}
#endif


SQLRETURN SQL_API
SQLExtendedFetch (
	SQLHSTMT hstmt,
	SQLUSMALLINT fFetchType,
	SQLLEN irow,
	SQLULEN * pcrow,
	SQLUSMALLINT * rgfRowStatus)
{
  STMT (stmt, hstmt);

  if (stmt->stmt_fetch_mode == FETCH_FETCH)
    {
      set_error (&stmt->stmt_error, "HY010", "CL049", "Can't mix SQLFetch and SQLExtendedFetch.");
      return SQL_ERROR;
    }
  stmt->stmt_fetch_mode = FETCH_EXT;

  return (virtodbc__SQLExtendedFetch (hstmt, fFetchType, irow, pcrow, rgfRowStatus, 0));
}


char * fk_text_casemode_0 =
"select"
" name_part (PK_TABLE, 0) as PKTABLE_QUALIFIER varchar (128),"
" name_part (PK_TABLE, 1) as PKTABLE_OWNER varchar (128),"
" name_part (PK_TABLE, 2) as PKTABLE_NAME varchar (128),"
" PKCOLUMN_NAME as PKCOLUMN_NAME varchar (128),"
" name_part (FK_TABLE, 0) as FKTABLE_QUALIFIER varchar (128),"
" name_part (FK_TABLE, 1) as FKTABLE_OWNER varchar (128),"
" name_part (FK_TABLE, 2) as FKTABLE_NAME varchar (128),"
" FKCOLUMN_NAME as FKCOLUMN_NAME varchar (128),"
" (KEY_SEQ + 1) as KEY_SEQ SMALLINT,"
" (case UPDATE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as UPDATE_RULE smallint,"
" (case DELETE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as DELETE_RULE smallint,"
" FK_NAME as FK_NAME varchar(128),"
" PK_NAME as PK_NAME varchar(128)"
"from DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS "
"where name_part (PK_TABLE, 0) like ?"
"  and name_part (PK_TABLE, 1) like ?"
"  and name_part (PK_TABLE, 2) like ?"
"  and name_part (FK_TABLE, 0) like ?"
"  and name_part (FK_TABLE, 1) like ?"
"  and name_part (FK_TABLE, 2) like ? "
"order by 1, 2, 3, 5, 6, 7, 9";

char * fk_text_casemode_2 =
"select"
" name_part (PK_TABLE, 0) as PKTABLE_QUALIFIER varchar (128),"
" name_part (PK_TABLE, 1) as PKTABLE_OWNER varchar (128),"
" name_part (PK_TABLE, 2) as PKTABLE_NAME varchar (128),"
" PKCOLUMN_NAME as PKCOLUMN_NAME varchar (128),"
" name_part (FK_TABLE, 0) as FKTABLE_QUALIFIER varchar (128),"
" name_part (FK_TABLE, 1) as FKTABLE_OWNER varchar (128),"
" name_part (FK_TABLE, 2) as FKTABLE_NAME varchar (128),"
" FKCOLUMN_NAME as FKCOLUMN_NAME varchar (128),"
" (KEY_SEQ + 1) as KEY_SEQ SMALLINT,"
" (case UPDATE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as UPDATE_RULE smallint,"
" (case DELETE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as DELETE_RULE smallint,"
" FK_NAME as FK_NAME varchar (128),"
" PK_NAME as PK_NAME varchar (128)"
"from DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS "
"where upper (name_part (PK_TABLE, 0)) like upper (?)"
"  and upper (name_part (PK_TABLE, 1)) like upper (?)"
"  and upper (name_part (PK_TABLE, 2)) like upper (?)"
"  and upper (name_part (FK_TABLE, 0)) like upper (?)"
"  and upper (name_part (FK_TABLE, 1)) like upper (?)"
"  and upper (name_part (FK_TABLE, 2)) like upper (?) "
"order by 1, 2, 3, 5, 6, 7, 9";

char * fk_textw_casemode_0 =
"select"
" charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_') as PKTABLE_QUALIFIER nvarchar (128),"
" charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_') as PKTABLE_OWNER nvarchar (128),"
" charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_') as PKTABLE_NAME nvarchar (128),"
" charset_recode (PKCOLUMN_NAME, 'UTF-8', '_WIDE_') as PKCOLUMN_NAME nvarchar (128),"
" charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_') as FKTABLE_QUALIFIER nvarchar (128),"
" charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_') as FKTABLE_OWNER nvarchar (128),"
" charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_') as FKTABLE_NAME nvarchar (128),"
" charset_recode (FKCOLUMN_NAME, 'UTF-8', '_WIDE_') as FKCOLUMN_NAME nvarchar (128),"
" (KEY_SEQ + 1) as KEY_SEQ SMALLINT,"
" (case UPDATE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as UPDATE_RULE smallint,"
" (case DELETE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as DELETE_RULE smallint,"
" charset_recode (FK_NAME, 'UTF-8', '_WIDE_') as FK_NAME nvarchar (128),"
" charset_recode (PK_NAME, 'UTF-8', '_WIDE_') as PK_NAME nvarchar (128) "
"from DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS "
"where name_part (PK_TABLE, 0) like ?"
"  and name_part (PK_TABLE, 1) like ?"
"  and name_part (PK_TABLE, 2) like ?"
"  and name_part (FK_TABLE, 0) like ?"
"  and name_part (FK_TABLE, 1) like ?"
"  and name_part (FK_TABLE, 2) like ? "
"order by 1, 2, 3, 5, 6, 7, 9";

char * fk_textw_casemode_2 =
"select"
" charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_') as PKTABLE_QUALIFIER nvarchar (128),"
" charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_') as PKTABLE_OWNER nvarchar (128),"
" charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_') as PKTABLE_NAME nvarchar (128),"
" charset_recode (PKCOLUMN_NAME, 'UTF-8', '_WIDE_') as PKCOLUMN_NAME nvarchar (128),"
" charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_') as FKTABLE_QUALIFIER nvarchar (128),"
" charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_') as FKTABLE_OWNER nvarchar (128),"
" charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_') as FKTABLE_NAME nvarchar (128),"
" charset_recode (FKCOLUMN_NAME, 'UTF-8', '_WIDE_') as FKCOLUMN_NAME nvarchar (128),"
" (KEY_SEQ + 1) as KEY_SEQ SMALLINT,"
" (case UPDATE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as UPDATE_RULE smallint,"
" (case DELETE_RULE when 0 then 3 when 1 then 0 when 3 then 4 end) as DELETE_RULE smallint,"
" charset_recode (FK_NAME, 'UTF-8', '_WIDE_') as FK_NAME nvarchar (128),"
" charset_recode (PK_NAME, 'UTF-8', '_WIDE_') as PK_NAME nvarchar (128) "
"from DB.DBA.SYS_FOREIGN_KEYS SYS_FOREIGN_KEYS "
"where charset_recode (upper (charset_recode (name_part (PK_TABLE, 0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
"  and charset_recode (upper (charset_recode (name_part (PK_TABLE, 1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
"  and charset_recode (upper (charset_recode (name_part (PK_TABLE, 2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
"  and charset_recode (upper (charset_recode (name_part (FK_TABLE, 0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
"  and charset_recode (upper (charset_recode (name_part (FK_TABLE, 1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
"  and charset_recode (upper (charset_recode (name_part (FK_TABLE, 2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper (charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') "
"order by 1, 2, 3, 5, 6, 7, 9";



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
	SQLSMALLINT cbFkTableName)
{
  STMT (stmt, hstmt);
  char *qual = (char *) stmt->stmt_connection->con_qualifier;
  SQLLEN l1, l2, l3, l4, l5, l6;
  SQLRETURN rc;
  char _szPkTableQualifier[KUBL_IDENTIFIER_MAX_LENGTH],
      _szPkTableOwner[KUBL_IDENTIFIER_MAX_LENGTH],
      _szPkTableName[KUBL_IDENTIFIER_MAX_LENGTH],
      _szFkTableQualifier[KUBL_IDENTIFIER_MAX_LENGTH],
      _szFkTableOwner[KUBL_IDENTIFIER_MAX_LENGTH], _szFkTableName[KUBL_IDENTIFIER_MAX_LENGTH];

  if (!szPkTableQualifier)
    {
      szPkTableQualifier = (SQLCHAR *) qual;
      cbPkTableQualifier = SQL_NTS;

      if (!szFkTableQualifier)
        {
          szFkTableQualifier = (SQLCHAR *) qual;
          cbFkTableQualifier = SQL_NTS;
        }
    }

  BIND_NAME_PART (hstmt, 1, szPkTableQualifier, _szPkTableQualifier, cbPkTableQualifier, l1);
  BIND_NAME_PART (hstmt, 2, szPkTableOwner, _szPkTableOwner, cbPkTableOwner, l2);
  BIND_NAME_PART (hstmt, 3, szPkTableName, _szPkTableName, cbPkTableName, l3);
  BIND_NAME_PART (hstmt, 4, szFkTableQualifier, _szFkTableQualifier, cbFkTableQualifier, l4);
  BIND_NAME_PART (hstmt, 5, szFkTableOwner, _szFkTableOwner, cbFkTableOwner, l5);
  BIND_NAME_PART (hstmt, 6, szFkTableName, _szFkTableName, cbFkTableName, l6);

  if (stmt->stmt_connection->con_defs.cdef_utf8_execs)
    rc = virtodbc__SQLExecDirect (hstmt,
	(SQLCHAR *) (stmt->stmt_connection->con_db_casemode == 2 ? fk_textw_casemode_2 : fk_textw_casemode_0), SQL_NTS);
  else
    rc = virtodbc__SQLExecDirect (hstmt,
	(SQLCHAR *) (stmt->stmt_connection->con_db_casemode == 2 ? fk_text_casemode_2 : fk_text_casemode_0), SQL_NTS);

  virtodbc__SQLFreeStmt (hstmt, SQL_RESET_PARAMS);

  return rc;
}


SQLRETURN SQL_API
SQLForeignKeys (
	SQLHSTMT hstmt,
	SQLCHAR * wszPkTableQualifier,
	SQLSMALLINT cbPkTableQualifier,
	SQLCHAR * wszPkTableOwner,
	SQLSMALLINT cbPkTableOwner,
	SQLCHAR * wszPkTableName,
	SQLSMALLINT cbPkTableName,
	SQLCHAR * wszFkTableQualifier,
	SQLSMALLINT cbFkTableQualifier,
	SQLCHAR * wszFkTableOwner,
	SQLSMALLINT cbFkTableOwner,
	SQLCHAR * wszFkTableName,
	SQLSMALLINT cbFkTableName)
{
  size_t len;
  SQLRETURN rc;
  STMT (stmt, hstmt);
  NDEFINE_INPUT_NARROW (PkTableQualifier);
  NDEFINE_INPUT_NARROW (PkTableOwner);
  NDEFINE_INPUT_NARROW (PkTableName);
  NDEFINE_INPUT_NARROW (FkTableQualifier);
  NDEFINE_INPUT_NARROW (FkTableOwner);
  NDEFINE_INPUT_NARROW (FkTableName);


  NMAKE_INPUT_NARROW (PkTableQualifier, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (PkTableOwner, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (PkTableName, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (FkTableQualifier, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (FkTableOwner, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (FkTableName, stmt->stmt_connection);

  rc = virtodbc__SQLForeignKeys (hstmt,
      szPkTableQualifier, cbPkTableQualifier,
      szPkTableOwner, cbPkTableOwner,
      szPkTableName, cbPkTableName,
      szFkTableQualifier, cbFkTableQualifier, szFkTableOwner, cbFkTableOwner, szFkTableName, cbFkTableName);

  NFREE_INPUT_NARROW (PkTableQualifier);
  NFREE_INPUT_NARROW (PkTableOwner);
  NFREE_INPUT_NARROW (PkTableName);
  NFREE_INPUT_NARROW (FkTableQualifier);
  NFREE_INPUT_NARROW (FkTableOwner);
  NFREE_INPUT_NARROW (FkTableName);

  return rc;
}


SQLRETURN SQL_API
SQLMoreResults (
	SQLHSTMT hstmt)
{
  STMT (stmt, hstmt);
  col_binding_t *saved_cols;
  int rc;
  set_error (&stmt->stmt_error, NULL, NULL, NULL);

  if (stmt->stmt_opts->so_cursor_type != SQL_CURSOR_FORWARD_ONLY)
    return SQL_NO_DATA_FOUND;

  if (!stmt->stmt_parm_rows_to_go || !stmt->stmt_future)
    return SQL_NO_DATA_FOUND;

  /* need to free stmt_rowset before virtodbc__SQLFetch because
   * it dk_frees stmt_current_row without checking if it is a
   * part of the rowset. */
  if (stmt->stmt_rowset)
    stmt_free_current_rows (stmt);

  saved_cols = stmt->stmt_cols;
  stmt->stmt_cols = NULL;
  while (!stmt->stmt_at_end)
    {
      SQLRETURN ret = virtodbc__SQLFetch (hstmt, 0);
      if (ret == SQL_ERROR)
	{
	  stmt->stmt_cols = saved_cols;
	  return ret;
	}
    }
  stmt->stmt_cols = saved_cols;

  if (!stmt->stmt_parm_rows_to_go)
    return SQL_NO_DATA_FOUND;

  /* Bugzilla 1996 */
  if (0 && stmt->stmt_current_of == -1 && !saved_cols)
    return SQL_NO_DATA_FOUND;

  stmt->stmt_at_end = 0;
  stmt->stmt_on_first_row = 1;
  rc = stmt_process_result (stmt, 1);
  /* if we have an empty set in a series of sets, we still return success even though process results returns no data */
  if (rc == SQL_ERROR)
    return rc;
  return SQL_SUCCESS;
}


SQLRETURN SQL_API
virtodbc__SQLNativeSql (
    SQLHDBC hdbc,
    SQLCHAR * szSqlStrIn,
    SQLINTEGER cbSqlStrIn,
    SQLCHAR * szSqlStr,
    SQLINTEGER cbSqlStrMax,
    SQLINTEGER * pcbSqlStr)
{
  CON (con, hdbc);

  if (!con)
    return (SQL_INVALID_HANDLE);

  if (szSqlStrIn && szSqlStr)
    {
      if (cbSqlStrMax >= 0)
	{
	  if (cbSqlStrMax > 0)
	    {
	      strncpy ((char *) szSqlStr, (const char *) szSqlStrIn, cbSqlStrMax);
	      szSqlStr[cbSqlStrMax - 1] = '\x0';
	    }
	}
      else
	{
	  set_error (&con->con_error, "HY009", "CL092", "Invalid string or buffer length");
	  return (SQL_ERROR);
	}

      stmt_convert_brace_escapes (szSqlStr, pcbSqlStr);
    }

  set_error (&con->con_error, NULL, NULL, NULL);

  return (SQL_SUCCESS);
}


SQLRETURN SQL_API
SQLNativeSql (
	SQLHDBC hdbc,
	SQLCHAR * wszSqlStrIn,
	SQLINTEGER cbSqlStrIn,
	SQLCHAR * wszSqlStr,
	SQLINTEGER cbSqlStr,
	SQLINTEGER * pcbSqlStr)
{
  CON (con, hdbc);
  SQLRETURN rc;
  size_t len;
  NDEFINE_INPUT_NARROW (SqlStrIn);
  NDEFINE_OUTPUT_CHAR_NARROW (SqlStr, con, SQLINTEGER);

  NMAKE_INPUT_NARROW (SqlStrIn, con);
  NMAKE_OUTPUT_CHAR_NARROW (SqlStr, con);

  rc = virtodbc__SQLNativeSql (hdbc, szSqlStrIn, SQL_NTS, szSqlStr, _cbSqlStr, _pcbSqlStr);

  NSET_AND_FREE_OUTPUT_CHAR_NARROW (SqlStr, con);
  NFREE_INPUT_NARROW (SqlStrIn);

  return rc;
}


SQLRETURN SQL_API
SQLNumParams (
	SQLHSTMT hstmt,
	SQLSMALLINT * pcpar)
{
  STMT (stmt, hstmt);
  stmt_compilation_t *sc = stmt->stmt_compilation;

  if (BOX_ELEMENTS (sc) > 3 && sc->sc_params)
    {
      if (pcpar)
	*pcpar = (SQLSMALLINT) BOX_ELEMENTS (sc->sc_params);

      return SQL_SUCCESS;
    }

  NOT_IMPL_FUN (hstmt, "SQLNumParams: BOX_ELEMENTS (sc) <= 3  or no  sc_params");
}

void *
stmt_bhid_place (cli_stmt_t * stmt, long bhid)
{
  if (SQL_API_SQLEXECDIRECT == stmt->stmt_pending.p_api)
    {
      parm_binding_t *pb = stmt_nth_parm (stmt, BHID_COL (bhid));
      size_t len = sqlc_sizeof (pb->pb_c_type, pb->pb_max_length);
      int btype = stmt->stmt_param_bind_type;
      size_t off = btype == 0 ? BHID_ROW (bhid) * len : BHID_ROW (bhid) * btype;
      int c_type = pb->pb_c_type;

      if (c_type == SQL_C_DEFAULT)
	c_type = sql_type_to_sqlc_default (pb->pb_sql_type);

      stmt->stmt_next_putdata_dtp = (c_type == SQL_C_WCHAR ? DV_LONG_WIDE : DV_LONG_STRING);

#ifndef MAP_DIRECT_BIN_CHAR
      stmt->stmt_next_putdata_translate_char_bin = (c_type == SQL_C_CHAR &&
	  (pb->pb_sql_type == SQL_BINARY || pb->pb_sql_type == SQL_VARBINARY || pb->pb_sql_type == SQL_LONGVARBINARY));
#endif

      return (pb->pb_place + off);
      /* can't use stmt_param_place_ptr because of its different handling of the pb_place == 0 */
    }

  if (SQL_API_SQLSETPOS == stmt->stmt_pending.p_api)
    {
      int btype = stmt->stmt_bind_type;
      col_binding_t *cb = stmt_nth_col (stmt, BHID_COL (bhid));
      int c_type = cb->cb_c_type;

#ifndef MAP_DIRECT_BIN_CHAR
      dtp_t col_dtp =
	  stmt && stmt->stmt_compilation && stmt->stmt_compilation->sc_columns
	  && BOX_ELEMENTS (stmt->stmt_compilation->sc_columns) >=
	  ((uint32) BHID_COL (bhid))
	  && BHID_COL (bhid) >
	  0 ? ((dtp_t) ((col_desc_t *) stmt->stmt_compilation->sc_columns[BHID_COL (bhid) - 1])->cd_dtp) : DV_LONG_STRING;

      stmt->stmt_next_putdata_translate_char_bin = (c_type == SQL_C_CHAR && col_dtp == DV_BLOB_BIN);
#endif

      stmt->stmt_next_putdata_dtp = (c_type == SQL_C_WCHAR ? DV_LONG_WIDE : DV_LONG_STRING);

      return (cb->cb_place + (btype == 0 ? cb->cb_max_length * BHID_ROW (bhid) : btype * BHID_ROW (bhid)));
    }

  return NULL;
}


int
stmt_col_sql_type (cli_stmt_t * stmt, int nth)
{
  SQLSMALLINT t = SQL_C_CHAR;
  virtodbc__SQLDescribeCol ((SQLHSTMT) stmt, (SQLUSMALLINT) nth, NULL, 0, NULL, &t, NULL, NULL, NULL);
  return t;
}


void
stmt_dae_value (cli_stmt_t * stmt)
{
  caddr_t v;
  caddr_t daeb;
  SQLLEN /*len, */ fill;
  long bhid = **(long **) stmt->stmt_current_dae;
  int c_type, sql_type;

  if (SQL_API_SQLEXECDIRECT == stmt->stmt_pending.p_api)
    {
      parm_binding_t *pb = stmt_nth_parm (stmt, BHID_COL (bhid));
      c_type = pb->pb_c_type;
      sql_type = pb->pb_sql_type;
    }
  else
    {
      col_binding_t *cb = stmt_nth_col (stmt, BHID_COL (bhid));
      c_type = cb->cb_c_type;
      sql_type = stmt_col_sql_type (stmt, BHID_COL (bhid));
    }

  if (!stmt->stmt_dae_fragments)
    {
      v = dk_alloc_box (1, DV_SHORT_STRING);
      v[0] = 0;
    }
  else if (dk_set_length (stmt->stmt_dae_fragments) == 1 && (DV_TYPE_OF (stmt->stmt_dae_fragments->data) == DV_DB_NULL || DV_TYPE_OF (stmt->stmt_dae_fragments->data) == DV_STRING_SESSION))
    {
      v = (caddr_t) stmt->stmt_dae_fragments->data;
      dk_set_free (stmt->stmt_dae_fragments);
      stmt->stmt_dae_fragments = NULL;
    }
  else
    {
      size_t len = 0;
      DO_SET (caddr_t, f, &stmt->stmt_dae_fragments)
      {
	len += box_length (f) - 1;
      }
      END_DO_SET ();
      if (len < MAX_READ_STRING)
	{
	  daeb = dk_alloc_box (len + 1, DV_SHORT_STRING);
	  fill = 0;
	  DO_SET (caddr_t, f, &stmt->stmt_dae_fragments)
	  {
	    len = box_length (f) - 1;
	    memcpy (daeb + fill, f, len);
	    fill += len;
	    dk_free_box (f);
	  }
	  END_DO_SET ();
	  daeb[fill] = 0;
	  if ((c_type == SQL_C_CHAR || c_type == SQL_C_BINARY) && (sql_type == SQL_CHAR || sql_type == SQL_VARCHAR))
	    v = daeb;
	  else
	    {
	      v = buffer_to_dv (daeb, &fill, c_type, sql_type, 0, stmt, CON_IS_INPROCESS (stmt->stmt_connection));
	      dk_free_box (daeb);
	    }
	}
      else
	{			/* serialize larger DAE values as string sessions */
	  dk_session_t *ses = strses_allocate ();

	  strses_set_utf8 (ses, c_type == SQL_C_WCHAR ? 1 : 0);
	  DO_SET (caddr_t, f, &stmt->stmt_dae_fragments)
	  {
	    len = box_length (f) - 1;
	    session_buffered_write (ses, f, len);
	    dk_free_box (f);
	  }
	  END_DO_SET ();
	  v = (caddr_t) ses;
	}
      dk_set_free (stmt->stmt_dae_fragments);
      stmt->stmt_dae_fragments = NULL;

    }
  dk_free_box ((caddr_t) * stmt->stmt_current_dae);
  *stmt->stmt_current_dae = (long *) v;
}


SQLRETURN SQL_API
SQLParamData (
	SQLHSTMT hstmt,
	SQLPOINTER * prgbValue)
{
  /* when passing blobs with SQLPutData returns the number of the
     next blob to send or if all have been sent, the return code of the
     statement */
  SQLRETURN rc;
  STMT (stmt, hstmt);
  dk_session_t *ses = stmt->stmt_connection->con_session;
  SDWORD last = stmt->stmt_last_asked_param;



  set_error (&stmt->stmt_error, NULL, NULL, NULL);
  if (STS_LOCAL_DAE == stmt->stmt_status)
    {
      if (stmt->stmt_current_dae)
	{
	  stmt_dae_value (stmt);
	}

      stmt->stmt_current_dae = (long **) dk_set_pop (&stmt->stmt_dae);

      if (!stmt->stmt_current_dae)
	{
	  if (SQL_API_SQLEXECDIRECT == stmt->stmt_pending.p_api)
	    {
	      rc = virtodbc__SQLExecDirect ((SQLHSTMT) stmt, NULL, SQL_NTS);
	      if (SQL_NEED_DATA == rc)
		{
		  *prgbValue = stmt_bhid_place (stmt, stmt->stmt_last_asked_param);
		  stmt->stmt_last_asked_param = -1;
		}
	      else
		{
		  memset (&stmt->stmt_pending, 0, sizeof (pending_call_t));

		}
	      return rc;
	    }

	  if (SQL_API_SQLSETPOS == stmt->stmt_pending.p_api)
	    /* no server DAE allowed for this */
	    return (virtodbc__SQLSetPos ((SQLHSTMT) stmt, (SQLUSMALLINT) stmt->stmt_pending.psp_irow, (SQLUSMALLINT) stmt->stmt_pending.psp_op, SQL_LOCK_NO_CHANGE));

	  set_error (&stmt->stmt_error, "S1010", "CL050", "Bad call to SQLParamData");

	  return SQL_ERROR;
	}

      *prgbValue = stmt_bhid_place (stmt, **(long **) stmt->stmt_current_dae);

      return SQL_NEED_DATA;
    }

  if (!last)
    {
      /* didn't ask. sequence error */
      set_error (&stmt->stmt_error, "S1010", "CL051", "No param was asked for.");

      return SQL_ERROR;
    }

  if (-1 == last || -2 == last)
    {
      /* A param eas being sent and this call marks it's complete.
         Send end mark and wait for instructions from server */
      if (-1 == last)
	{
	  CATCH_WRITE_FAIL (ses)
	  {
	    session_buffered_write_char (0, ses);
	    session_flush (ses);
	  }
	  END_WRITE_FAIL (ses);
	}
      else
	last = stmt->stmt_last_asked_param = -1;

      rc = stmt_process_result (stmt, 1);

      if (rc == SQL_NEED_DATA)
	{
	  *prgbValue = (void *) stmt_bhid_place (stmt, stmt->stmt_last_asked_param);
	  stmt->stmt_last_asked_param = -1;
	}
      else
	{
	  memset (&stmt->stmt_pending, 0, sizeof (pending_call_t));
	  stmt->stmt_last_asked_param = 0;
	}

      return rc;
    }

  *prgbValue = stmt_bhid_place (stmt, last);
  stmt->stmt_last_asked_param = -1;

  return SQL_NEED_DATA;
}


SQLRETURN SQL_API
SQLPutData (
	SQLHSTMT hstmt,
	SQLPOINTER rgbValue,
	SQLLEN cbValue)
{
  /* Send stuff. If called in the right place the server will be waiting
     for a string on the session */
  STMT (stmt, hstmt);
  SQLRETURN rc = SQL_SUCCESS;
  dk_session_t *ses = stmt->stmt_connection->con_session;
  volatile SQLLEN newValue = (cbValue == SQL_NTS ?
      (stmt->stmt_next_putdata_dtp == DV_LONG_STRING ?
	  strlen ((const char *) rgbValue) : wcslen ((wchar_t *) rgbValue) * sizeof (wchar_t)) : cbValue);

  if (STS_LOCAL_DAE == stmt->stmt_status)
    {
      caddr_t dae;
      size_t len;

      if (!stmt->stmt_current_dae)
	{
	  set_error (&stmt->stmt_error, "S1010", "CL052", "Bad place to call SQLPutData");

	  return SQL_ERROR;
	}

      if (SQL_NULL_DATA == cbValue)
	{
	  if (stmt->stmt_dae_fragments)
	    {
	      set_error (&stmt->stmt_error, "HY020", "CL085", "Attempt to concatenate NULL value");

	      return SQL_ERROR;
	    }

	  dae = dk_alloc_box (0, DV_DB_NULL);
	}
      else if (stmt->stmt_next_putdata_dtp == DV_LONG_WIDE && rgbValue != NULL && cbValue != 0)
	{			/* put a session for wides */
	  size_t wlen;
	  wchar_t *wValue = (wchar_t *) rgbValue, *wptr;
	  virt_mbstate_t ps;
	  dk_session_t *ses;
	  char *nbuffer;

	  if (cbValue != SQL_NTS && cbValue % sizeof (wchar_t))
	    {
	      set_error (&stmt->stmt_error, "22023", "CLXXX",
		  "Length argument passed to SQLPutData must be a multiple of the size of the wide char.");

	      return SQL_ERROR;
	    }
	  wptr = wValue;
	  memset (&ps, 0, sizeof (ps));
	  wlen = cbValue == SQL_NTS ? wcslen (wValue) : (cbValue / sizeof (wchar_t));

	  ses = strses_allocate ();
	  strses_set_utf8 (ses, 1);
	  nbuffer = (char *) dk_alloc (65000);

	  wptr = wValue;
	  while (wptr - wValue < wlen)
	    {
	      size_t res;

	      res = virt_wcsnrtombs ((unsigned char *) nbuffer, &wptr, wlen - (wptr - wValue), 65000, &ps);
	      if (res == (size_t) - 1)
		{
		  set_error (&stmt->stmt_error, "22023", "CLXXX", "Invalid wide data passed to SQLPutData");
		  dk_free (nbuffer, 65000);
		  strses_free (ses);
		  return SQL_ERROR;
		}

	      if (res != 0)
		session_buffered_write (ses, nbuffer, res);
	    }

	  dae = (caddr_t) ses;
	  dk_free (nbuffer, 65000);
	}
      else if (rgbValue && (len = (cbValue < 0) ? strlen ((const char *) rgbValue) : cbValue) + 1 > MAX_READ_STRING)
	{			/* make a session if the buffer is larger then 10 MB as well */
	  dk_session_t *ses = strses_allocate ();
	  session_buffered_write (ses, (const char *) rgbValue, len);
	  dae = (caddr_t) ses;
	}
      else
	dae = box_n_string ((SQLCHAR *) rgbValue, cbValue);

      stmt->stmt_dae_fragments = dk_set_conc (stmt->stmt_dae_fragments, dk_set_cons ((void *) dae, NULL));

      return SQL_SUCCESS;
    }

  if (stmt->stmt_last_asked_param != -1)
    {
      set_error (&stmt->stmt_error, "S1010", "CL053", "No data was asked for.");
      return SQL_ERROR;
    }

#ifndef MAP_DIRECT_BIN_CHAR
  if (stmt->stmt_next_putdata_translate_char_bin && (SQL_NULL_DATA != cbValue))
    {
      unsigned char *src, chr;
      if (newValue % 2)
	{
	  set_error (&stmt->stmt_error, "S1010", "CL054",
	      "Invalid buffer length (even) in passing character data to binary column in SQLPutData");

	  return SQL_ERROR;
	}

      for (src = (unsigned char *) rgbValue; src - ((unsigned char *) rgbValue) < newValue; src++)
	{
	  chr = toupper (*src);
	  if ((chr < '0' || chr > '9') && (chr < 'A' || chr > 'F'))
	    {
	      set_error (&stmt->stmt_error, "S1010", "CL055",
		  "Invalid buffer length (even) in passing character data to binary column in SQLPutData");

	      return SQL_ERROR;
	    }
	}
    }
#endif

  CATCH_WRITE_FAIL (ses)
  {
    if (SQL_NULL_DATA == cbValue)
      {
	session_buffered_write_char (DV_DB_NULL, ses);
	stmt->stmt_last_asked_param = -2;
      }
    else
      {
	session_buffered_write_char (stmt->stmt_next_putdata_dtp, ses);

	if (stmt->stmt_next_putdata_dtp == DV_LONG_STRING)
	  {
#ifndef MAP_DIRECT_BIN_CHAR
	    if (stmt->stmt_next_putdata_translate_char_bin)
	      {
		unsigned char *src = (unsigned char *) rgbValue, _lo, _hi, _res;
		print_long ((long) (newValue / 2), ses);

		for (src = (unsigned char *) rgbValue; src - ((unsigned char *) rgbValue) < newValue; src += 2)
		  {
		    _lo = toupper (src[1]);
		    _hi = toupper (src[0]);
		    _res = ((_hi - (_hi <= '9' ? '0' : 'A' + 10)) << 4) | (_lo - (_lo <= '9' ? '0' : 'A' + 10));
		    session_buffered_write_char (_res, ses);
		  }
	      }
	    else
#endif
	      {
		print_long ((long) newValue, ses);
		session_buffered_write (ses, (const char *) rgbValue, newValue);
	      }
	  }
	else
	  {
	    wchar_t *wstr = (wchar_t *) rgbValue;
	    size_t utf8_len;
	    virt_mbstate_t state;
	    unsigned char mbs[VIRT_MB_CUR_MAX];
	    size_t len = 0, i;

	    wstr = (wchar_t *) rgbValue;
	    memset (&state, 0, sizeof (virt_mbstate_t));
	    utf8_len = virt_wcsnrtombs (NULL, &wstr, newValue / sizeof (wchar_t), 0, &state);

	    if (utf8_len != (size_t) - 1)
	      {
		print_long ((long) utf8_len, ses);

		memset (&state, 0, sizeof (virt_mbstate_t));
		wstr = (wchar_t *) rgbValue;
		i = 0;
		while (i++ < newValue / sizeof (wchar_t))
		  {
		    len = virt_wcrtomb (mbs, *wstr++, &state);
		    if (len > 0)
		      session_buffered_write (ses, (char *) mbs, len);
		  }
	      }
	    else
	      {
		print_long ((long) 0, ses);
		set_error (&stmt->stmt_error, "S1010", "CL093", "Invalid wide data supplied to SQLPutData");
		rc = SQL_ERROR;
	      }
	  }
      }

    session_flush (ses);
  }
  END_WRITE_FAIL (ses);

  return rc;
}


/* A note from ODBC API help file (SQLGetData)

   With each call, the driver sets pcbValue to the number of bytes that
   were available in the result column prior to the current call to
   SQLGetData. (If SQL_MAX_LENGTH has been set with SQLSetStmtOption,
   and the total number of bytes available on the first call is greater
   than SQL_MAX_LENGTH, the available number of bytes is set to
   SQL_MAX_LENGTH. Note that the SQL_MAX_LENGTH statement option is
   intended to reduce network traffic and may not be supported by all
   drivers. To guarantee that data is truncated, an application should
   allocate a buffer of the desired size and specify this size in the
   cbValueMax argument.) If the total number of bytes in the result column
   cannot be determined in advance, the driver sets pcbValue to SQL_NO_TOTAL.
   If the data value for the column is NULL, the driver stores SQL_NULL_DATA
   in pcbValue.
 */


SQLRETURN
sql_get_bookmark (cli_stmt_t * stmt, caddr_t * row,
		  SQLSMALLINT fCType,
		  SQLPOINTER rgbValue,
		  SQLLEN cbValueMax,
		  SQLLEN * pcbValue)
{
  caddr_t box;
  SQLLEN len_read;

  if (!stmt->stmt_opts->so_use_bookmarks)
    {
      set_error (&stmt->stmt_error, "07009", "CL056", "Bookmarks not enable for statement");

      return SQL_ERROR;
    }

  box = box_num (stmt_row_bookmark (stmt, row));
  dv_to_place (box, fCType, 0, cbValueMax, (caddr_t) rgbValue, &len_read, 0, stmt, 0, NULL);
  dk_free_box (box);

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
virtodbc__SQLGetData (
	SQLHSTMT hstmt,
	SQLUSMALLINT icol,
	SQLSMALLINT fCType,
	SQLPOINTER rgbValue,
	SQLLEN cbValueMax,
	SQLLEN * pcbValue)
{
  int ref_cursor = 1;
  STMT (stmt, hstmt);
  dk_session_t *ses = stmt->stmt_connection->con_session;
  caddr_t *val;
  caddr_t *row;
  caddr_t col;
#ifdef SAFE_SQLGETDATA
  unsigned char *rgbValue_end;
#endif
#ifndef MAP_DIRECT_BIN_CHAR
  col_desc_t *col_desc = NULL;
  int is_blob_to_char = 0;
#endif
  int rlen;

  cli_dbg_printf (("SQLGetData (%lx, %d, %d, --, %d, --)\n", hstmt, icol, fCType, cbValueMax));

  VERIFY_INPROCESS_CLIENT (stmt->stmt_connection);

  row = stmt->stmt_current_row;
  if (!row)
    {
      set_error (&stmt->stmt_error, "S1010", "CL057", "Statement not fetched in SQLGetData.");
      return SQL_ERROR;
    }

  if (0 == icol)
    return (sql_get_bookmark (stmt, row, fCType, rgbValue, cbValueMax, pcbValue));

  rlen = BOX_ELEMENTS (row);

  if (icol >= rlen)
    {
      set_error (&stmt->stmt_error, "07009", "CL058", "Column out of range in SQLGetData");

      return SQL_ERROR;
    }

  col = row[icol];

#ifndef MAP_DIRECT_BIN_CHAR
  if (stmt->stmt_compilation && stmt->stmt_compilation->sc_is_select && BOX_ELEMENTS (stmt->stmt_compilation->sc_columns) >= icol)
    {
      col_desc = (col_desc_t *) stmt->stmt_compilation->sc_columns[icol - 1];
      is_blob_to_char = (fCType == SQL_C_CHAR || fCType == SQL_C_WCHAR) && col_desc->cd_dtp == DV_BLOB_BIN;
    }
#endif

  set_error (&stmt->stmt_error, NULL, NULL, NULL);

/* IvAn/DvBlobXper/001212 Case for XPER added */
  if (IS_BOX_POINTER (col) && IS_BLOB_HANDLE_DTP (DV_TYPE_OF (col)))
    {				/* it's a blob? */
      blob_handle_t *bh = (blob_handle_t *) col;
      int is_nts = (fCType == SQL_C_CHAR);
      int is_wnts = (fCType == SQL_C_WCHAR);
      col_binding_t *cb = stmt_nth_col (stmt, icol);
      size_t length = bh->bh_length >= cb->cb_read_up_to ? bh->bh_length - cb->cb_read_up_to : 0; /* it may get negative turned to uint64  */

      if (0 == length)
	{
	  if (pcbValue)
	    *pcbValue = 0;
	  if (!cb->cb_not_first_getdata)
	    {
	      cb->cb_not_first_getdata = 1;

	      return (SQL_SUCCESS);
	    }
	  else
	    return (SQL_NO_DATA_FOUND);
	}

      cb->cb_not_first_getdata = 1;

      if (!cbValueMax || (is_nts && cbValueMax == 1) || (is_wnts && cbValueMax == sizeof (wchar_t)))
	{
	  if (pcbValue)
	    {
#ifndef MAP_DIRECT_BIN_CHAR
	      *pcbValue = length * (is_wnts ? sizeof (wchar_t) : sizeof (char)) * (is_blob_to_char ? 2 : 1);
#else
	      *pcbValue = length * (is_wnts ? sizeof (wchar_t) : sizeof (char));
#endif
	    }

	  if (length)
	    {
	      set_data_truncated_success_info (stmt, "CL090", icol);

	      return (SQL_SUCCESS_WITH_INFO);
	    }
	  else
	    return (SQL_SUCCESS);
	}

      if (is_nts)
	cbValueMax--;

      if (is_wnts)
	{
	  if (cbValueMax % sizeof (wchar_t))
	    cbValueMax = ((int) (cbValueMax / sizeof (wchar_t))) * sizeof (wchar_t);

#ifdef SAFE_SQLGETDATA
	  rgbValue_end = ((unsigned char *) (rgbValue)) + cbValueMax;
#endif
	  cbValueMax = cbValueMax / sizeof (wchar_t) - 1;
	}
#ifdef SAFE_SQLGETDATA
      else
	rgbValue_end = ((unsigned char *) (rgbValue)) + cbValueMax;
#endif
      if (stmt->stmt_connection->con_autocommit
	  || (stmt->stmt_compilation &&
	      stmt->stmt_compilation->sc_is_select == QT_PROC_CALL)
	  || stmt->stmt_opts->so_cursor_type != SQL_CURSOR_FORWARD_ONLY
	  || stmt->stmt_connection->con_environment->env_odbc_version == 3)
	ref_cursor = 0;

      if (ref_cursor)
	{
	  val = (caddr_t *) PrpcSync (PrpcFuture (ses, &s_get_data, stmt->stmt_id, stmt->stmt_current_of, (long) icol,
#ifndef MAP_DIRECT_BIN_CHAR
		  cbValueMax / (is_blob_to_char ? 2 : 1),
#else
		  cbValueMax,
#endif
		  (long) 0));
	}
      else
	{
	  if (0 == cb->cb_read_up_to)
	    {
	      bh->bh_current_page = bh->bh_page;
	      bh->bh_position = 0;
	    }

	  val = (caddr_t *) PrpcSync (PrpcFuture (ses, &s_get_data_ac,
#ifndef MAP_DIRECT_BIN_CHAR
		  bh->bh_current_page,
		  cbValueMax / (is_blob_to_char ? 2 : 1),
		  bh->bh_position,
		  bh->bh_key_id,
						  bh->bh_frag_no, bh->bh_dir_page, bh->bh_pages, (ptrlong)(DV_TYPE_OF (bh) == DV_BLOB_WIDE_HANDLE), (ptrlong)bh->bh_timestamp
#else
		  bh->bh_current_page,
		  cbValueMax,
		  bh->bh_position,
		  bh->bh_key_id,
						  bh->bh_frag_no, bh->bh_dir_page, bh->bh_pages, (ptrlong)(DV_TYPE_OF (bh) == DV_BLOB_WIDE_HANDLE), (ptrlong)bh->bh_timestamp
#endif
	      ));
	}

      if (0 == val)
	{
	  if (pcbValue)
	    *pcbValue = 0;

	  return SQL_NO_DATA_FOUND;
	}

      if (IS_BOX_POINTER (val) && IS_NONLEAF_DTP (box_tag (val)))
	{
	  long strings = box_length ((caddr_t) val) / sizeof (caddr_t);
#ifdef SAFE_SQLGETDATA
	  long inx;
	  unsigned char *rgbValue_tail = (unsigned char *) rgbValue;
#else
	  long inx, fill = 0;
#endif
	  if (val[0] == (caddr_t) QA_ERROR)
	    {
	      caddr_t srv_msg = cli_box_server_msg (val[2]);

	      set_error (&stmt->stmt_error, val[1], NULL, srv_msg);
	      dk_free_tree ((caddr_t) val);
	      dk_free_box (srv_msg);

	      return SQL_ERROR;
	    }

	  for (inx = 0; inx < strings; inx++)
	    {
	      /* take 1 off for the terminating 0 added by reader: */
	      long len = box_length (val[inx]) - (IS_WIDE_STRING_DTP (box_tag (val[inx])) ? sizeof (wchar_t) : 1);
	      switch (box_tag (val[inx]))
		{
		case DV_ARRAY_OF_LONG:
		  {
		    ptrlong *elt = (ptrlong *) val[inx];
		    bh->bh_current_page = (dp_addr_t) elt[1];
		    bh->bh_position = (int) elt[2];
		    continue;
		  }
		  break;

		case DV_WIDE:
		case DV_LONG_WIDE:
		  {
#ifdef SAFE_SQLGETDATA
		    if (is_nts)
		      {
			int added = cli_wide_to_narrow (stmt->stmt_connection->con_charset,
			    0, (wchar_t *) val[inx], len / sizeof (wchar_t),
			    rgbValue_tail, rgbValue_end - rgbValue_tail, NULL, NULL);
			rgbValue_tail += added;
		      }
		    else
		      {
			int added = rgbValue_end - rgbValue_tail;

			if (added > len)
			  added = len;

			memcpy (rgbValue_tail, val[inx], added);
			rgbValue_tail += added;
		      }
#else
		    if (is_nts)
		      cli_wide_to_narrow (stmt->stmt_connection->con_charset,
			  0, (wchar_t *) val[inx], len / sizeof (wchar_t),
			  ((unsigned char *) rgbValue) + fill, len / sizeof (wchar_t), NULL, NULL);
		    else
		      memcpy (((wchar_t *) rgbValue) + fill, val[inx], len);

		    fill += len / sizeof (wchar_t);
#endif
		    break;
		  }

		case DV_STRING:
#ifndef MAP_DIRECT_BIN_CHAR
		  if (is_blob_to_char)
		    {
# ifdef SAFE_SQLGETDATA
		      if (is_wnts)
			{
			  int nbytes = (rgbValue_end - rgbValue_tail) / (2 * sizeof (wchar_t));
			  if (nbytes > len)
			    nbytes = len;

			  bin_dv_to_wstr_place ((unsigned char *) val[inx], (wchar_t *) rgbValue_tail, nbytes);
			  rgbValue_tail += nbyte * 2 * sizeof (wchar_t);
			}
		      else
			{
			  int nbytes = (rgbValue_end - rgbValue_tail) / 2;

			  if (nbytes > len)
			    nbytes = len;

			  bin_dv_to_str_place ((unsigned char *) val[inx], (char *) rgbValue_tail, nbytes);
			  rgbValue_tail += nbyte * 2;
			}
# else
		      if (is_wnts)
			bin_dv_to_wstr_place ((unsigned char *) val[inx], ((wchar_t *) rgbValue) + fill, len);
		      else
			bin_dv_to_str_place ((unsigned char *) val[inx], ((char *) rgbValue) + fill, len);
		      fill += len * 2;
# endif
		    }
		  else
#endif
		    {
#ifdef SAFE_SQLGETDATA
		      if (is_wnts)
			{
			  int added = cli_narrow_to_wide (stmt->stmt_connection->con_charset, 0,
			      (unsigned char *) val[inx], len,
			      ((wchar_t *) rgbValue_tail),
			      ((wchar_t *) rgbValue_end) - ((wchar_t *) rgbValue_tail));
			  rgbValue_tail += added * sizeof (wchar_t);
			}
		      else
			{
			  int added = rgbValue_end - rgbValue_tail;

			  if (added > len)
			    added = len;

			  memcpy (rgbValue_tail, val[inx], added);
			  rgbValue_tail += added;
			}
#else
		      if (is_wnts)
			cli_narrow_to_wide (stmt->stmt_connection->con_charset, 0,
			    (unsigned char *) val[inx], len, ((wchar_t *) rgbValue) + fill, len);
		      else
			memcpy (((char *) rgbValue) + fill, val[inx], len);

		      fill += len;
#endif
		    }
		  break;

		default:
#ifdef SAFE_SQLGETDATA
		  {
		    int added = rgbValue_end - rgbValue_tail;

		    if (added > len)
		      added = len;

		    memcpy (rgbValue_tail, val[inx], added);
		    rgbValue_tail += added;
		  }
#else
		  memcpy (((char *) rgbValue) + fill, val[inx], len);
		  fill += len;
#endif
		  break;
		}
	    }

#ifdef SAFE_SQLGETDATA
	  if (is_nts)
	    ((char *) rgbValue_tail)[0] = '\x0';

	  if (is_wnts)
	    ((wchar_t *) rgbValue_tail)[0] = L'\x0';
#else
	  if (is_nts)
	    ((char *) rgbValue)[fill] = 0;

	  if (is_wnts)
	    ((wchar_t *) rgbValue)[fill] = L'\x0';
#endif

	  if (pcbValue)
#ifndef MAP_DIRECT_BIN_CHAR
	    *pcbValue = length * (is_wnts ? sizeof (wchar_t) : sizeof (char)) * (is_blob_to_char ? 2 : 1);
#ifdef SAFE_SQLGETDATA
	  cb->cb_read_up_to += (rgbValue_tail - ((unsigned char *) rgbValue)) / (is_blob_to_char ? 2 : 1);
#else
	  cb->cb_read_up_to += fill / (is_blob_to_char ? 2 : 1);
#endif
#else
	    *pcbValue = length * (is_wnts ? sizeof (wchar_t) : sizeof (char));
#ifdef SAFE_SQLGETDATA
	  cb->cb_read_up_to += (rgbValue_tail - ((unsigned char *) rgbValue));
#else
	  cb->cb_read_up_to += fill;
#endif
#endif

	  dk_free_tree ((box_t) val);

	  if (bh->bh_length > (size_t) cb->cb_read_up_to)
	    {
	      set_data_truncated_success_info (stmt, "CL059", icol);
	      return SQL_SUCCESS_WITH_INFO;
	    }
	  else
	    return SQL_SUCCESS;
	}

      dk_free_tree ((caddr_t) val);
      set_error (&stmt->stmt_error, "07006", "CL060", "Non string data received with SQLGetData.");

      return SQL_ERROR;
    }
  else
    /* Not a blob, hopefully it is a normal string column or similar. */
    {
      /* How to make sure that cb->cb_read_up_to is initially zero ? It is! */
      SQLLEN piece_len;
      SQLLEN len_read = 0, out_chars = 0;

      col_binding_t *cb = stmt_nth_col (stmt, icol);
      /* Give sql_type always as zero as we do not know it. */
      int was_first = !cb->cb_not_first_getdata;
      cb->cb_not_first_getdata = 1;
      piece_len = dv_to_place (col, fCType, 0, cbValueMax, (caddr_t) rgbValue, &len_read, cb->cb_read_up_to, stmt, icol, &out_chars);

      if (pcbValue)
	{
	  *pcbValue = ((SQL_NULL_DATA == len_read) ? SQL_NULL_DATA : ((0 == len_read) ? len_read : (len_read - cb->cb_read_up_to)));
	  if (out_chars) *pcbValue = out_chars; /* case when writing utf16 */
	}

      switch (piece_len)
	{
	case SQL_NULL_DATA:
	  if (was_first)
	    return SQL_SUCCESS;
	  else
	    return SQL_NO_DATA_FOUND;	/* Box of len 0 */

	  /* If dv_to_place copies pieces of zero length (that is, nothing), then
	     return SQL_SUCCESS instead of SQL_SUCCESS_WITH_INFO, although the
	     data in principle is (severely) truncated. However, we want to avoid
	     idiot loops that would be produced in those cases where client gives
	     cbValueMax either as zero (when fCType is SQL_C_BINARY or SQL_C_CHAR)
	     or one (when fCType is SQL_C_CHAR), and instead go right to the next
	     column. */

	case 0:
	  if (was_first)
	    return SQL_SUCCESS;
	  else
	    return SQL_NO_DATA_FOUND;	/* Box of len 0 */

	default:
	  /* If the data is truncated, then it is the task of dv_str_to_place
	     function (called by dv_to_place) to set the error state with the call:
	     set_error (err, "01004", "Data truncated."); */
	  cb->cb_read_up_to += piece_len;	/* Was: += len_read; */
	  if (cb->cb_read_up_to < len_read)	/* Data truncated? */
	    {
	      set_data_truncated_success_info (stmt, "CL059", icol);
	      return (SQL_SUCCESS_WITH_INFO);
	    }
	  else
	    /* The whole stuff has been got now. */
	    return SQL_SUCCESS;
	}
    }
}


SQLRETURN SQL_API
SQLGetData (
    SQLHSTMT hstmt,
    SQLUSMALLINT icol,
    SQLSMALLINT fCType,
    SQLPOINTER rgbValue,
    SQLLEN cbValueMax,
    SQLLEN * pcbValue)
{
  return virtodbc__SQLGetData (hstmt, icol, fCType, rgbValue, cbValueMax, pcbValue);
}


/* Comments from dv_to_place function (in the module cliuti.c)
   clarifying the above piece of code in SQLGetData function.

   If dv_value 'it' is XXX, returns YYY and stores ZZZ to *len_ret

   NULL	 SQL_NULL_DATA  SQL_NULL_DATA
   box of length zero   SQL_NULL_DATA  0

   If max is 0 (c_type is
   SQL_C_BINARY or SQL_C_CHAR)
   or max is 1 and c_type
   is SQL_C_CHAR	   returns 0   and stores zero to *len_ret
   (in case c_type is SQL_C_CHAR and string is '')
   returns 0   and stores non-zero to *len_ret
   (in all other cases)

   If max is greater than 0 (with SQL_C_BINARY) or 1 (with SQL_C_CHAR)
   returns length of piece copied and stores to
   *len_ret the whole length of dv box (with
   SQL_C_BINARY) or one less (SQL_C_CHAR).

   If max is 777 and c_type is SQL_C_CHAR and box is '' (i.e. one byte '\0')
   then copies the terminating byte to place, returns zero, and stores
   zero to *len_ret.

   Otherwise, returns the size of data type (in bytes) and stores the
   same value to *len_ret (if len_ret is not NULL).

   Note how in *len_ret is always returned the original length of dv data
   (possibly - 1 if SQL_C_CHAR) without subtracting str_from_pos from it.
   It is the task of SQLGetData to calculate and store the correct value
   into its pcbValue pointer argument.
 */

SQLRETURN SQL_API
SQLParamOptions (
	SQLHSTMT hstmt,
	SQLULEN crow,
	SQLULEN * pirow)
{
  STMT (stmt, hstmt);

  stmt->stmt_parm_rows = crow;
  stmt->stmt_pirow = pirow;

  return SQL_SUCCESS;
}


/* AK 17-JAN-1996:
   See comments above SQLStatistics, especially the note about
   the behaviour of the column KP_NTH.
   Added where-clause "and KEY_MIGRATE_TO is NULL" to avoid obsolete
   primary keys after, e.g. commands like: ALTER TABLE tab ADD col integer;
   i.e. does not return twice the same information.

   AK 22-JAN-1996:
   Added the sixth column, called PK_NAME by ODBC 2.0 (Primary Key
   Identifier, NULL if not applicable to the data source) which in our
   case is just KEY_NAME
   Added also the seventh, eighth and ninth columns, a Non-Standard Kubl
   Extension, which contain the name of the Super Table of the table in
   question. (The name is actually in the ninth column, and the seventh
   and eight columns contains just constant strings 'db' and 'dba', just
   like the first and second columns.)
   If the table does not have super table, then this column will contain
   the same table name as the third column (i.e. the table is its own
   super table, so to speak). This requires a join with the table
   SYS_KEYS itself (using two views, v1 and v2).
   So an application (like dbdump for example) can check this
   ninth column, and if it is not NULL, and it differs from the third
   column (or 7th or 8th columns differ from 1st and 2nd), then it can
   surely assume that this is the subtable of the table whose name is
   given in this ninth column.
 */


char *sql_pk_text_casemode_0 =
"select"
" name_part(v1.KEY_TABLE,0) AS \\TABLE_QUALIFIER VARCHAR(128),"
" name_part(v1.KEY_TABLE,1) AS \\TABLE_OWNER VARCHAR(128),"
" name_part(v1.KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128),"
" DB.DBA.SYS_COLS.\\COLUMN AS \\COLUMN_NAME VARCHAR(128),"
" (kp.KP_NTH+1) AS \\KEY_SEQ SMALLINT,"
" name_part (v1.KEY_NAME, 2) AS \\PK_NAME VARCHAR(128),"
" name_part(v2.KEY_TABLE,0) AS \\ROOT_QUALIFIER VARCHAR(128),"
" name_part(v2.KEY_TABLE,1) AS \\ROOT_OWNER VARCHAR(128),"
" name_part(v2.KEY_TABLE,2) AS \\ROOT_NAME VARCHAR(128) "
"from DB.DBA.SYS_KEYS v1, DB.DBA.SYS_KEYS v2,"
"     DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS "
"where name_part(v1.KEY_TABLE,0) like ?"
"  and __any_grants (v1.KEY_TABLE) "
"  and name_part(v1.KEY_TABLE,1) like ?"
"  and name_part(v1.KEY_TABLE,2) like ?"
"  and v1.KEY_IS_MAIN = 1"
"  and v1.KEY_MIGRATE_TO is NULL"
"  and v1.KEY_SUPER_ID = v2.KEY_ID"
"  and kp.KP_KEY_ID = v1.KEY_ID"
"  and kp.KP_NTH < v1.KEY_DECL_PARTS"
"  and DB.DBA.SYS_COLS.COL_ID = kp.KP_COL"
"  and DB.DBA.SYS_COLS.\\COLUMN <> '_IDN' "
"order by v1.KEY_TABLE, kp.KP_NTH";

char *sql_pk_text_casemode_2 =
"select"
" name_part(v1.KEY_TABLE,0) AS \\TABLE_QUALIFIER VARCHAR(128),"
" name_part(v1.KEY_TABLE,1) AS \\TABLE_OWNER VARCHAR(128),"
" name_part(v1.KEY_TABLE,2) AS \\TABLE_NAME VARCHAR(128),"
" DB.DBA.SYS_COLS.\\COLUMN AS \\COLUMN_NAME VARCHAR(128),"
" (kp.KP_NTH+1) AS \\KEY_SEQ SMALLINT,"
" name_part (v1.KEY_NAME, 2) AS \\PK_NAME VARCHAR(128),"
" name_part(v2.KEY_TABLE,0) AS \\ROOT_QUALIFIER VARCHAR(128),"
" name_part(v2.KEY_TABLE,1) AS \\ROOT_OWNER VARCHAR(128),"
" name_part(v2.KEY_TABLE,2) AS \\ROOT_NAME VARCHAR(128) "
"from DB.DBA.SYS_KEYS v1, DB.DBA.SYS_KEYS v2,"
"     DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS "
"where upper(name_part(v1.KEY_TABLE,0)) like upper(?)"
"  and __any_grants (v1.KEY_TABLE) "
"  and upper(name_part(v1.KEY_TABLE,1)) like upper(?)"
"  and upper(name_part(v1.KEY_TABLE,2)) like upper(?)"
"  and v1.KEY_IS_MAIN = 1"
"  and v1.KEY_MIGRATE_TO is NULL"
"  and v1.KEY_SUPER_ID = v2.KEY_ID"
"  and kp.KP_KEY_ID = v1.KEY_ID"
"  and kp.KP_NTH < v1.KEY_DECL_PARTS"
"  and DB.DBA.SYS_COLS.COL_ID = kp.KP_COL"
"  and DB.DBA.SYS_COLS.\\COLUMN <> '_IDN' "
"order by v1.KEY_TABLE, kp.KP_NTH";

char *sql_pk_textw_casemode_0 =
"select"
" charset_recode (name_part(v1.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_QUALIFIER NVARCHAR(128),"
" charset_recode (name_part(v1.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_OWNER NVARCHAR(128),"
" charset_recode (name_part(v1.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128),"
" charset_recode (DB.DBA.SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128),"
" (kp.KP_NTH+1) AS \\KEY_SEQ SMALLINT,"
" charset_recode (name_part (v1.KEY_NAME, 2), 'UTF-8', '_WIDE_') AS \\PK_NAME NVARCHAR(128),"
" charset_recode (name_part (v2.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\ROOT_QUALIFIER NVARCHAR(128),"
" charset_recode (name_part (v2.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\ROOT_OWNER NVARCHAR(128),"
" charset_recode (name_part (v2.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\ROOT_NAME NVARCHAR(128) "
"from DB.DBA.SYS_KEYS v1, DB.DBA.SYS_KEYS v2,"
"     DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS "
"where name_part(v1.KEY_TABLE,0) like ?"
"  and __any_grants (v1.KEY_TABLE) "
"  and name_part(v1.KEY_TABLE,1) like ?"
"  and name_part(v1.KEY_TABLE,2) like ?"
"  and v1.KEY_IS_MAIN = 1"
"  and v1.KEY_MIGRATE_TO is NULL"
"  and v1.KEY_SUPER_ID = v2.KEY_ID"
"  and kp.KP_KEY_ID = v1.KEY_ID"
"  and kp.KP_NTH < v1.KEY_DECL_PARTS"
"  and DB.DBA.SYS_COLS.COL_ID = kp.KP_COL"
"  and DB.DBA.SYS_COLS.\\COLUMN <> '_IDN' "
"order by v1.KEY_TABLE, kp.KP_NTH";

char *sql_pk_textw_casemode_2 =
"select"
" charset_recode (name_part(v1.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\TABLE_QUALIFIER NVARCHAR(128),"
" charset_recode (name_part(v1.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\TABLE_OWNER NVARCHAR(128),"
" charset_recode (name_part(v1.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\TABLE_NAME NVARCHAR(128),"
" charset_recode (DB.DBA.SYS_COLS.\\COLUMN, 'UTF-8', '_WIDE_') AS \\COLUMN_NAME NVARCHAR(128),"
" (kp.KP_NTH+1) AS \\KEY_SEQ SMALLINT,"
" charset_recode (name_part (v1.KEY_NAME, 2), 'UTF-8', '_WIDE_') AS \\PK_NAME NVARCHAR(128),"
" charset_recode (name_part (v2.KEY_TABLE,0), 'UTF-8', '_WIDE_') AS \\ROOT_QUALIFIER NVARCHAR(128),"
" charset_recode (name_part (v2.KEY_TABLE,1), 'UTF-8', '_WIDE_') AS \\ROOT_OWNER NVARCHAR(128),"
" charset_recode (name_part (v2.KEY_TABLE,2), 'UTF-8', '_WIDE_') AS \\ROOT_NAME NVARCHAR(128) "
"from DB.DBA.SYS_KEYS v1, DB.DBA.SYS_KEYS v2,"
"     DB.DBA.SYS_KEY_PARTS kp, DB.DBA.SYS_COLS "
"where charset_recode (upper(charset_recode (name_part(v1.KEY_TABLE,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
"  and __any_grants (v1.KEY_TABLE) "
"  and charset_recode (upper(charset_recode (name_part(v1.KEY_TABLE,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
"  and charset_recode (upper(charset_recode (name_part(v1.KEY_TABLE,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
"  and v1.KEY_IS_MAIN = 1"
"  and v1.KEY_MIGRATE_TO is NULL"
"  and v1.KEY_SUPER_ID = v2.KEY_ID"
"  and kp.KP_KEY_ID = v1.KEY_ID"
"  and kp.KP_NTH < v1.KEY_DECL_PARTS"
"  and DB.DBA.SYS_COLS.COL_ID = kp.KP_COL"
"  and DB.DBA.SYS_COLS.\\COLUMN <> '_IDN' "
"order by v1.KEY_TABLE, kp.KP_NTH";

SQLRETURN SQL_API
virtodbc__SQLPrimaryKeys (
	SQLHSTMT hstmt,
	SQLCHAR * szTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * szTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * szTableName,
	SQLSMALLINT cbTableName)
{
  STMT (stmt, hstmt);
  SQLRETURN rc;
/*  SQLCHAR *percent = (SQLCHAR *) "%"; */
  SQLLEN cbqual, cbown, cbname;
  char _szTableQualifier[KUBL_IDENTIFIER_MAX_LENGTH],
      _szTableOwner[KUBL_IDENTIFIER_MAX_LENGTH], _szTableName[KUBL_IDENTIFIER_MAX_LENGTH];

  DEFAULT_QUAL (stmt, cbqual);
  BIND_NAME_PART (hstmt, 1, szTableQualifier, _szTableQualifier, cbTableQualifier, cbqual);
  BIND_NAME_PART (hstmt, 2, szTableOwner, _szTableOwner, cbTableOwner, cbown);
  BIND_NAME_PART (hstmt, 3, szTableName, _szTableName, cbTableName, cbname);

  if (stmt->stmt_connection->con_defs.cdef_utf8_execs)
    rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	(stmt->stmt_connection->con_db_casemode == 2 ? sql_pk_textw_casemode_2 : sql_pk_textw_casemode_0), SQL_NTS);
  else
    rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *)
	(stmt->stmt_connection->con_db_casemode == 2 ? sql_pk_text_casemode_2 : sql_pk_text_casemode_0), SQL_NTS);

  virtodbc__SQLFreeStmt (hstmt, SQL_RESET_PARAMS);

  return rc;
}


SQLRETURN SQL_API
SQLPrimaryKeys (
	SQLHSTMT hstmt,
	SQLCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * wszTableName,
	SQLSMALLINT cbTableName)
{
  STMT (stmt, hstmt);
  SQLRETURN rc;
  size_t len;

  NDEFINE_INPUT_NARROW (TableQualifier);
  NDEFINE_INPUT_NARROW (TableOwner);
  NDEFINE_INPUT_NARROW (TableName);

  NMAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableName, stmt->stmt_connection);

  rc = virtodbc__SQLPrimaryKeys (hstmt, szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName);

  NFREE_INPUT_NARROW (TableQualifier);
  NFREE_INPUT_NARROW (TableOwner);
  NFREE_INPUT_NARROW (TableName);

  return rc;
}


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
	SQLSMALLINT cbColumnName)
{
  static char *proc_cols_text = "DB.DBA.SQL_PROCEDURE_COLUMNS (?, ?, ?, ?, ?, ?)";
  static char *proc_cols_textw = "DB.DBA.SQL_PROCEDURE_COLUMNSW (?, ?, ?, ?, ?, ?)";

  STMT (stmt, hstmt);
  SQLRETURN rc;
  SQLLEN cbqual = cbProcQualifier,
      cbown = cbProcOwner, cbname = cbProcName, cbcol = cbColumnName, cbcasemode = sizeof (long), cbodbc3 = sizeof (long);
  char _szProcQualifier[KUBL_IDENTIFIER_MAX_LENGTH],
      _szProcOwner[KUBL_IDENTIFIER_MAX_LENGTH], _szProcName[KUBL_IDENTIFIER_MAX_LENGTH], _szColumnName[KUBL_IDENTIFIER_MAX_LENGTH];
  long casemode = stmt->stmt_connection->con_db_casemode == 2 ? 1 : 0;
  long isODBC3 = stmt->stmt_connection->con_environment->env_odbc_version >= 3;

  if (!szProcQualifier)
    {
      szProcQualifier = stmt->stmt_connection->con_qualifier;
      strcpy_ck (_szProcQualifier, (const char *) szProcQualifier);
      cbqual = (cbProcQualifier = SQL_NTS);
    }

  BIND_NAME_PART (hstmt, 1, szProcQualifier, _szProcQualifier, cbProcQualifier, cbqual);
  BIND_NAME_PART (hstmt, 2, szProcOwner, _szProcOwner, cbProcOwner, cbown);
  BIND_NAME_PART (hstmt, 3, szProcName, _szProcName, cbProcName, cbname);
  BIND_NAME_PART (hstmt, 4, szColumnName, _szColumnName, cbColumnName, cbcol);

  virtodbc__SQLSetParam (hstmt, 5, SQL_C_LONG, SQL_INTEGER, 0, 0, &casemode, &cbcasemode);
  virtodbc__SQLSetParam (hstmt, 6, SQL_C_LONG, SQL_INTEGER, 0, 0, &isODBC3, &cbodbc3);

  if (stmt->stmt_connection->con_defs.cdef_utf8_execs)
    rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *) proc_cols_textw, SQL_NTS);
  else
    rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *) proc_cols_text, SQL_NTS);

  virtodbc__SQLFreeStmt (hstmt, SQL_RESET_PARAMS);

  return rc;
}


SQLRETURN SQL_API
SQLProcedureColumns (
	SQLHSTMT hstmt,
	SQLCHAR * wszProcQualifier,
	SQLSMALLINT cbProcQualifier,
	SQLCHAR * wszProcOwner,
	SQLSMALLINT cbProcOwner,
	SQLCHAR * wszProcName,
	SQLSMALLINT cbProcName,
	SQLCHAR * wszColumnName,
	SQLSMALLINT cbColumnName)
{
  STMT (stmt, hstmt);
  SQLRETURN rc;
  size_t len;

  NDEFINE_INPUT_NARROW (ProcQualifier);
  NDEFINE_INPUT_NARROW (ProcOwner);
  NDEFINE_INPUT_NARROW (ProcName);
  NDEFINE_INPUT_NARROW (ColumnName);

  NMAKE_INPUT_NARROW (ProcQualifier, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (ProcOwner, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (ProcName, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (ColumnName, stmt->stmt_connection);

  rc = virtodbc__SQLProcedureColumns (hstmt,
      szProcQualifier, cbProcQualifier, szProcOwner, cbProcOwner, szProcName, cbProcName, szColumnName, cbColumnName);

  NFREE_INPUT_NARROW (ProcQualifier);
  NFREE_INPUT_NARROW (ProcOwner);
  NFREE_INPUT_NARROW (ProcName);
  NFREE_INPUT_NARROW (ColumnName);

  return rc;
}


/*
   SQLProcedures, implemented 13-APR-1997 by AK.
   Currently only PROCEDURE_NAME column contains any significant
   information, that is, the name of the procedure.

   Note that in contrast to SQLTables, the arguments szProcQualifier,
   szProcOwner and szProcName really have to be NULL (or their
   respective count byte arguments SQL_NULL_DATA) or percents "%"
   that all procedures are printed, that is, an empty string ''
   is really matched only against empty strings.
   This usage is more upto standard.

   The last column (PROCEDURE_TYPE) is either 0 (SQL_PT_UNKNOWN)
   1 (SQL_PT_PROCEDURE) or 2 (SQL_PT_FUNCTION). Currently Kubl stores
   always NULL to P_TYPE column, so let's return 0 for it.

   25.Dec.1997: Changed \\P_NAME to name_part(\\P_NAME,2) where possible.
   because procedure names might nowadays occur with full prefixes.
   (I do not know whether full prefixes are really necessary, and at
   least in old databases the procedure names (column P_NAME) do not
   contain prefixes. Anyways, name_part(X,2) from X where there is no
   periods (.) produces back the X itself, so it is not harmful.
*/

char *sql_procedures_casemode_0 =
"select"
" name_part (\\P_NAME, 0) AS \\PROCEDURE_QUALIFIER VARCHAR(128),"
" name_part (\\P_NAME, 1) AS \\PROCEDURE_OWNER VARCHAR(128),"
" name_part (\\P_NAME, 2) AS \\PROCEDURE_NAME VARCHAR(128)," /* NOT NULL */
" \\P_N_IN AS \\NUM_INPUT_PARAMETERS,"	/* Currently KUBL */
" \\P_N_OUT AS \\NUM_OUTPUT_PARAMETERS,"	/* keeps always NULLs */
" \\P_N_R_SETS AS \\NUM_RESULT_SETS,"	/* in these three columns */
" \\P_COMMENT AS \\REMARKS VARCHAR(254),"/* Also in these last two */
" either(isnull(P_TYPE),0,P_TYPE) AS \\PROCEDURE_TYPE SMALLINT "
"from DB.DBA.SYS_PROCEDURES "
"where "
"  __proc_exists (\\P_NAME) is not null "
"  and name_part (\\P_NAME, 2) like ? "
"  and name_part (\\P_NAME, 1) like ?"
"  and name_part (\\P_NAME, 0) like ?"
" order by \\P_NAME";

char *sql_procedures_casemode_2 =
"select"
" name_part(\\P_NAME,0) AS \\PROCEDURE_QUALIFIER VARCHAR(128),"
" name_part(\\P_NAME,1) AS \\PROCEDURE_OWNER VARCHAR(128),"
" name_part(\\P_NAME,2) AS \\PROCEDURE_NAME VARCHAR(128)," /* NOT NULL */
" \\P_N_IN AS \\NUM_INPUT_PARAMETERS,"	/* Currently KUBL */
" \\P_N_OUT AS \\NUM_OUTPUT_PARAMETERS,"	/* keeps always NULLs */
" \\P_N_R_SETS AS \\NUM_RESULT_SETS,"	/* in these three columns */
" \\P_COMMENT AS \\REMARKS VARCHAR(254),"/* Also in these last two */
" either(isnull(P_TYPE),0,P_TYPE) AS \\PROCEDURE_TYPE SMALLINT "
"from DB.DBA.SYS_PROCEDURES "
"where "
"  __proc_exists (\\P_NAME) is not null "
"  and upper(name_part(\\P_NAME,2)) like upper(?)"
"  and upper(name_part(\\P_NAME,1)) like upper(?)"
"  and upper(name_part(\\P_NAME,0)) like upper(?)"
" order by \\P_NAME";

char *sql_proceduresw_casemode_0 =
"select"
" charset_recode (name_part (\\P_NAME, 0), 'UTF-8', '_WIDE_') AS \\PROCEDURE_QUALIFIER NVARCHAR(128),"
" charset_recode (name_part (\\P_NAME, 1), 'UTF-8', '_WIDE_') AS \\PROCEDURE_OWNER NVARCHAR(128),"
" charset_recode (name_part (\\P_NAME, 2), 'UTF-8', '_WIDE_') AS \\PROCEDURE_NAME NVARCHAR(128)," /* NOT NULL */
" \\P_N_IN AS \\NUM_INPUT_PARAMETERS,"	/* Currently KUBL */
" \\P_N_OUT AS \\NUM_OUTPUT_PARAMETERS,"	/* keeps always NULLs */
" \\P_N_R_SETS AS \\NUM_RESULT_SETS,"	/* in these three columns */
" \\P_COMMENT AS \\REMARKS VARCHAR(254),"/* Also in these last two */
" either(isnull(P_TYPE),0,P_TYPE) AS \\PROCEDURE_TYPE SMALLINT "
"from DB.DBA.SYS_PROCEDURES "
"where "
"  __proc_exists (\\P_NAME) is not null "
"  and name_part (\\P_NAME, 2) like ?"
"  and name_part (\\P_NAME, 1) like ?"
"  and name_part (\\P_NAME, 0) like ? "
" order by \\P_NAME";

char *sql_proceduresw_casemode_2 =
"select"
" charset_recode (name_part (\\P_NAME, 0), 'UTF-8', '_WIDE_') AS \\PROCEDURE_QUALIFIER NVARCHAR(128),"
" charset_recode (name_part (\\P_NAME, 1), 'UTF-8', '_WIDE_') AS \\PROCEDURE_OWNER NVARCHAR(128),"
" charset_recode (name_part (\\P_NAME, 2), 'UTF-8', '_WIDE_') AS \\PROCEDURE_NAME NVARCHAR(128)," /* NOT NULL */
" \\P_N_IN AS \\NUM_INPUT_PARAMETERS,"	/* Currently KUBL */
" \\P_N_OUT AS \\NUM_OUTPUT_PARAMETERS,"	/* keeps always NULLs */
" \\P_N_R_SETS AS \\NUM_RESULT_SETS,"	/* in these three columns */
" \\P_COMMENT AS \\REMARKS VARCHAR(254),"/* Also in these last two */
" either(isnull(P_TYPE),0,P_TYPE) AS \\PROCEDURE_TYPE SMALLINT "
"from DB.DBA.SYS_PROCEDURES "
"where "
"  __proc_exists (\\P_NAME) is not null "
"  and charset_recode (upper(charset_recode (name_part(\\P_NAME,2), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
"  and charset_recode (upper(charset_recode (name_part(\\P_NAME,1), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
"  and charset_recode (upper(charset_recode (name_part(\\P_NAME,0), 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8') like charset_recode (upper(charset_recode (?, 'UTF-8', '_WIDE_')), '_WIDE_', 'UTF-8')"
" order by \\P_NAME";

SQLRETURN SQL_API
virtodbc__SQLProcedures (
	SQLHSTMT hstmt,
	SQLCHAR * szProcQualifier,
	SQLSMALLINT cbProcQualifier,
	SQLCHAR * szProcOwner,
	SQLSMALLINT cbProcOwner,
	SQLCHAR * szProcName,
	SQLSMALLINT cbProcName)
{
  STMT (stmt, hstmt);
  SQLLEN cbqual = cbProcQualifier;
  SQLLEN cbowner = cbProcOwner;
  SQLLEN cbname = cbProcName;
  SQLRETURN rc;
  SQLCHAR *percent = (SQLCHAR *) "%";
  SQLLEN plen = SQL_NTS;
  char _szProcQualifier[KUBL_IDENTIFIER_MAX_LENGTH],
      _szProcOwner[KUBL_IDENTIFIER_MAX_LENGTH], _szProcName[KUBL_IDENTIFIER_MAX_LENGTH];

  if (is_empty_or_null (szProcQualifier, cbqual))
    {
      szProcQualifier = NULL;
      _szProcQualifier[0] = 0;
    }
  else
    remove_search_escapes ((char *) szProcQualifier, _szProcQualifier, sizeof (_szProcQualifier), &cbqual, cbProcQualifier);

  if (!szProcQualifier)
    {
      szProcQualifier = stmt->stmt_connection->con_qualifier;
      cbqual = cbProcQualifier = SQL_NTS;
      strcpy_ck (_szProcQualifier, (const char *) szProcQualifier);
    }

  if (is_empty_or_null (szProcOwner, cbowner))
    {
      szProcOwner = NULL;
      _szProcOwner[0] = 0;
    }
  else
    remove_search_escapes ((char *) szProcOwner, _szProcOwner, sizeof (_szProcOwner), &cbowner, cbProcOwner);

  if (is_empty_or_null (szProcName, cbname))
    {
      szProcName = NULL;
      _szProcName[0] = 0;
    }
  else
    remove_search_escapes ((char *) szProcName, _szProcName, sizeof (_szProcName), &cbname, cbProcName);

  /* The first parameter is the pattern the user himself gave in
     szProcQualifier, or just a single percent if the szProcQualifier
     was NULL: */
  virtodbc__SQLSetParam (hstmt, 3, SQL_C_CHAR, SQL_CHAR, 0, 0, (szProcQualifier ? (SQLCHAR *) _szProcQualifier : percent),
      (szProcQualifier ? &cbqual : &plen));

  /* Similarly with szProcOwner and szProcName parameters: */
  virtodbc__SQLSetParam (hstmt, 2, SQL_C_CHAR, SQL_CHAR, 0, 0, (szProcOwner ? (SQLCHAR *) _szProcOwner : percent),
      (szProcOwner ? &cbowner : &plen));

  virtodbc__SQLSetParam (hstmt, 1, SQL_C_CHAR, SQL_CHAR, 0, 0, (szProcName ? (SQLCHAR *) _szProcName : percent),
      (szProcName ? &cbname : &plen));


  if (stmt->stmt_connection->con_defs.cdef_utf8_execs)
    rc = virtodbc__SQLExecDirect (hstmt,
	(SQLCHAR *) (stmt->stmt_connection->con_db_casemode == 2 ?
	    sql_proceduresw_casemode_2 : sql_proceduresw_casemode_0), SQL_NTS);
  else
    rc = virtodbc__SQLExecDirect (hstmt,
	(SQLCHAR *) (stmt->stmt_connection->con_db_casemode == 2 ? sql_procedures_casemode_2 : sql_procedures_casemode_0), SQL_NTS);

  virtodbc__SQLFreeStmt (hstmt, SQL_RESET_PARAMS);

  return rc;
}


SQLRETURN SQL_API
SQLProcedures (
	SQLHSTMT hstmt,
	SQLCHAR * wszProcQualifier,
	SQLSMALLINT cbProcQualifier,
	SQLCHAR * wszProcOwner,
	SQLSMALLINT cbProcOwner,
	SQLCHAR * wszProcName,
	SQLSMALLINT cbProcName)
{
  STMT (stmt, hstmt);
  SQLRETURN rc;
  size_t len;

  NDEFINE_INPUT_NARROW (ProcQualifier);
  NDEFINE_INPUT_NARROW (ProcOwner);
  NDEFINE_INPUT_NARROW (ProcName);

  NMAKE_INPUT_NARROW (ProcQualifier, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (ProcOwner, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (ProcName, stmt->stmt_connection);

  rc = virtodbc__SQLProcedures (hstmt, szProcQualifier, cbProcQualifier, szProcOwner, cbProcOwner, szProcName, cbProcName);

  NFREE_INPUT_NARROW (ProcQualifier);
  NFREE_INPUT_NARROW (ProcOwner);
  NFREE_INPUT_NARROW (ProcName);

  return rc;
}


SQLRETURN SQL_API
SQLSetScrollOptions (
	SQLHSTMT hstmt,
	SQLUSMALLINT fConcurrency,
	SQLLEN crowKeyset,
	SQLUSMALLINT crowRowset)
{
  STMT (stmt, hstmt);
  if (!stmt->stmt_at_end && stmt->stmt_future)
    {
      set_error (&stmt->stmt_error, "S1010", "CL061", "Can't set scroll on open cursor");
      return SQL_ERROR;
    }

  stmt->stmt_rowset_size = crowRowset;
  stmt->stmt_opts->so_concurrency = fConcurrency;

  return SQL_SUCCESS;
}


SQLRETURN SQL_API
virtodbc__SQLTablePrivileges (
	SQLHSTMT hstmt,
	SQLCHAR * szTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * szTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * szTableName,
	SQLSMALLINT cbTableName)
{
  STMT (stmt, hstmt);
  SQLRETURN rc;
  SQLLEN cbqual = cbTableQualifier;
  SQLLEN cbowner = cbTableOwner;
  SQLLEN cbname = cbTableName;
  SQLCHAR *percent = (SQLCHAR *) "%";
  SQLLEN plen = SQL_NTS;
  char _szTableQualifier[KUBL_IDENTIFIER_MAX_LENGTH],
      _szTableOwner[KUBL_IDENTIFIER_MAX_LENGTH], _szTableName[KUBL_IDENTIFIER_MAX_LENGTH];

  if (is_empty_or_null (szTableQualifier, cbqual))
    {
      szTableQualifier = NULL;
      _szTableQualifier[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableQualifier, _szTableQualifier, sizeof (_szTableQualifier), &cbqual, cbTableQualifier);

  if (is_empty_or_null (szTableOwner, cbowner))
    {
      szTableOwner = NULL;
      _szTableOwner[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableOwner, _szTableOwner, sizeof (_szTableOwner), &cbowner, cbTableOwner);

  if (is_empty_or_null (szTableName, cbname))
    {
      szTableName = NULL;
      _szTableName[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableName, _szTableName, sizeof (_szTableName), &cbname, cbTableName);


  DEFAULT_QUAL (stmt, cbqual);
  virtodbc__SQLSetParam (hstmt, 1, SQL_C_CHAR, SQL_CHAR, 0, 0, (szTableQualifier ? (SQLCHAR *) _szTableQualifier : percent),
      (szTableQualifier ? &cbqual : &plen));

/* Similarly with szTableOwner and szTableName parameters: */
  virtodbc__SQLSetParam (hstmt, 2, SQL_C_CHAR, SQL_CHAR, 0, 0, (szTableOwner ? (SQLCHAR *) _szTableOwner : percent),
      (szTableOwner ? &cbowner : &plen));

  virtodbc__SQLSetParam (hstmt, 3, SQL_C_CHAR, SQL_CHAR, 0, 0, (szTableName ? (SQLCHAR *) _szTableName : percent),
      (szTableName ? &cbname : &plen));

  rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *) "DB.DBA.table_privileges(?,?,?)", SQL_NTS);

  virtodbc__SQLFreeStmt (hstmt, SQL_RESET_PARAMS);

  return rc;
}


SQLRETURN SQL_API
SQLTablePrivileges (
	SQLHSTMT hstmt,
	SQLCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * wszTableName,
	SQLSMALLINT cbTableName)
{
  SQLRETURN rc;
  size_t len;
  STMT (stmt, hstmt);
  NDEFINE_INPUT_NARROW (TableQualifier);
  NDEFINE_INPUT_NARROW (TableOwner);
  NDEFINE_INPUT_NARROW (TableName);

  NMAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableName, stmt->stmt_connection);

  rc = virtodbc__SQLTablePrivileges (hstmt,
      szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName);

  NFREE_INPUT_NARROW (TableQualifier);
  NFREE_INPUT_NARROW (TableOwner);
  NFREE_INPUT_NARROW (TableName);

  return rc;
}


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
	SQLSMALLINT cbColumnName)
{
  STMT (stmt, hstmt);
  SQLRETURN rc;
  SQLLEN cbqual = cbTableQualifier;
  SQLLEN cbowner = cbTableOwner;
  SQLLEN cbname = cbTableName;
  SQLLEN cbcolnam = cbColumnName;
  SQLCHAR *percent = (SQLCHAR *) "%";
  SQLLEN plen = SQL_NTS;
  char _szTableQualifier[KUBL_IDENTIFIER_MAX_LENGTH],
      _szTableOwner[KUBL_IDENTIFIER_MAX_LENGTH],
      _szTableName[KUBL_IDENTIFIER_MAX_LENGTH], _szColumnName[KUBL_IDENTIFIER_MAX_LENGTH];

  if (is_empty_or_null (szTableQualifier, cbqual))
    {
      szTableQualifier = NULL;
      _szTableQualifier[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableQualifier, _szTableQualifier, sizeof (_szTableQualifier), &cbqual, cbTableQualifier);

  if (is_empty_or_null (szTableOwner, cbowner))
    {
      szTableOwner = NULL;
      _szTableOwner[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableOwner, _szTableOwner, sizeof (_szTableOwner), &cbowner, cbTableOwner);

  if (is_empty_or_null (szTableName, cbname))
    {
      szTableName = NULL;
      _szTableName[0] = 0;
    }
  else
    remove_search_escapes ((char *) szTableName, _szTableName, sizeof (_szTableName), &cbname, cbTableName);

  if (is_empty_or_null (szColumnName, cbcolnam))
    {
      szColumnName = NULL;
      _szColumnName[0] = 0;
    }
  else
    remove_search_escapes ((char *) szColumnName, _szColumnName, sizeof (_szColumnName), &cbcolnam, cbColumnName);

  DEFAULT_QUAL (stmt, cbqual);

  /* The first parameter is the pattern the user himself gave in
     szTableQualifier, or just a single percent if the szTableQualifier
     was NULL: */
  virtodbc__SQLSetParam (hstmt, 1, SQL_C_CHAR, SQL_CHAR, 0, 0, (szTableQualifier ? (SQLCHAR *) _szTableQualifier : percent),
      (szTableQualifier ? &cbqual : &plen));

/* Similarly with szTableOwner, szTableName and szColumnName parameters: */
  virtodbc__SQLSetParam (hstmt, 2, SQL_C_CHAR, SQL_CHAR, 0, 0, (szTableOwner ? (SQLCHAR *) _szTableOwner : percent),
      (szTableOwner ? &cbowner : &plen));

  virtodbc__SQLSetParam (hstmt, 3, SQL_C_CHAR, SQL_CHAR, 0, 0, (szTableName ? (SQLCHAR *) _szTableName : percent),
      (szTableName ? &cbname : &plen));

  virtodbc__SQLSetParam (hstmt, 4, SQL_C_CHAR, SQL_CHAR, 0, 0, (szColumnName ? (SQLCHAR *) _szColumnName : percent),
      (szColumnName ? &cbcolnam : &plen));

  if (stmt->stmt_connection->con_defs.cdef_utf8_execs)
    rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *) "DB.DBA.column_privileges_utf8(?,?,?,?)", SQL_NTS);
  else
    rc = virtodbc__SQLExecDirect (hstmt, (SQLCHAR *) "DB.DBA.column_privileges(?,?,?,?)", SQL_NTS);

  virtodbc__SQLFreeStmt (hstmt, SQL_RESET_PARAMS);

  return rc;
}


SQLRETURN SQL_API
SQLColumnPrivileges (
	SQLHSTMT hstmt,
	SQLCHAR * wszTableQualifier,
	SQLSMALLINT cbTableQualifier,
	SQLCHAR * wszTableOwner,
	SQLSMALLINT cbTableOwner,
	SQLCHAR * wszTableName,
	SQLSMALLINT cbTableName,
	SQLCHAR * wszColumnName,
	SQLSMALLINT cbColumnName)
{
  size_t len;
  SQLRETURN rc;
  STMT (stmt, hstmt);
  NDEFINE_INPUT_NARROW (TableQualifier);
  NDEFINE_INPUT_NARROW (TableOwner);
  NDEFINE_INPUT_NARROW (TableName);
  NDEFINE_INPUT_NARROW (ColumnName);

  NMAKE_INPUT_NARROW (TableQualifier, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableOwner, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (TableName, stmt->stmt_connection);
  NMAKE_INPUT_NARROW (ColumnName, stmt->stmt_connection);

  rc = virtodbc__SQLColumnPrivileges (hstmt,
      szTableQualifier, cbTableQualifier, szTableOwner, cbTableOwner, szTableName, cbTableName, szColumnName, cbColumnName);

  NFREE_INPUT_NARROW (TableQualifier);
  NFREE_INPUT_NARROW (TableOwner);
  NFREE_INPUT_NARROW (TableName);
  NFREE_INPUT_NARROW (ColumnName);

  return rc;
}


#if 0
/* Navigation Extensions prototypes */
SQLRETURN SQL_API
SQLBindKey (
	SQLHSTMT hstmt,
	SQLUSMALLINT iKeyPart,
	SQLSMALLINT fSQLType,
	SQLSMALLINT fCType,
	UDWORD cbPrecision,
	SQLSMALLINT ibScale,
	SQLPOINTER rgbValue,
	SDWORD * pcbValue)
{
  NOT_IMPL_FUN (hstmt, "Function not supported: SQLBindKey");
}


SQLRETURN SQL_API
SQLOpenTable (
	SQLHSTMT hstmt,
	SQLCHAR * szQualifiedTable,
	SQLSMALLINT cbQualifiedTable,
	SQLCHAR * szIndexList,
	SQLSMALLINT cbIndexList)
{
  NOT_IMPL_FUN (hstmt, "Function not supported: SQLOpenTable");
}
#endif

