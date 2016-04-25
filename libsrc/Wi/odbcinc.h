/*
 *  odbcinc.h
 *
 *  $Id$
 *
 *  Include the ODBC header, whichever appropriate
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

#ifndef __V_ODBCINC_H
#define __V_ODBCINC_H

#if defined(HAVE_CONFIG_H) && !defined(_CONFIG_H)
#define _CONFIG_H
# include "config.h"
#endif

#if (defined (WIN32) || defined (UNIX_ODBC)) && !defined (UDBC)
# include "Dk.h"
# ifdef WIN32
#  include <windows.h>
# endif
# include <sql.h>
# include <sqlext.h>
# include <sqlucode.h>
# if defined (WIN32)
#  include <odbcinst.h>
#  define ERR_STRING	"[OpenLink][Virtuoso ODBC Driver]"
# else
#  define ERR_STRING	"[OpenLink][Virtuoso iODBC Driver]"
# endif

# ifndef SQL_COPT_SS_BASE
#  define SQL_COPT_SS_BASE		1200
#  define SQL_COPT_SS_ENLIST_IN_DTC	(SQL_COPT_SS_BASE+7)
#  define SQL_COPT_SS_ENLIST_IN_XA	(SQL_COPT_SS_BASE+8)
# endif

# if defined (WIN32)
#  ifndef HAVE_ODBCINST_H
#   define HAVE_ODBCINST_H
#  endif
# else
#  ifdef NO_UDBC_SDK
#   include <iodbcinst.h>
#   define HAVE_ODBCINST_H
#  else
#   include "iodbcinst.h"
#  endif
# endif

#else /* unix */
# define ERR_STRING	"[Virtuoso Driver]"
# include <sql.h>
# include <sqlext.h>
# include <iodbcext.h>
# ifndef NO_UDBC_SDK
typedef SQLCHAR SQLTCHAR;
#  if !defined (__ODBC3_DEFINES) && (ODBCVER < 0x0300)
#   define __ODBC3_DEFINES 1
typedef void * SQLHANDLE;
#   define SQL_TYPE_DATE 91
#   define SQL_TYPE_TIME 92
#   define SQL_TYPE_TIMESTAMP 93
#   define SQL_PARAM_SUCCESS	0
#   define SQL_PARAM_ERROR		5
#   define SQL_PARAM_SUCCESS_WITH_INFO	6
#   define SQL_PARAM_UNUSED	7

#  endif /* __ODBC3_DEFINES */
# endif /* NO_UDBC_SDK */
#endif /* UNIX */

/* these are from sqlucode.h */
#ifndef SQL_WCHAR
#  define SQL_WCHAR		(-8)
#  define SQL_C_WCHAR		SQL_WCHAR
#endif

#ifndef SQL_WVARCHAR
#  define SQL_WVARCHAR		(-9)
#  define SQL_C_WVARCHAR 	SQL_WVARCHAR
#endif

#ifndef SQL_WLONGVARCHAR
#  define SQL_WLONGVARCHAR	(-10)
#  define SQL_C_WLONGVARCHAR	SQL_WLONGVARCHAR
#endif

#ifndef SQL_FN_CVT_CAST
#  define SQL_FN_CVT_CAST	0x00000002L
#endif

/* from iodbcext.h */
#ifndef SQL_GETLASTSERIAL
#define SQL_GETLASTSERIAL 1049L
#endif


#ifndef WIN32
#ifndef SQLLEN
#define SQLLEN SDWORD
#endif
#ifndef SQLULEN
#define SQLULEN UDWORD
#endif
#ifndef SQLSETPOSIROW
#define SQLSETPOSIROW SQLUSMALLINT
#endif
#endif

#define IS_INTERSOLV(drvr_name) (drvr_name[0] == 'I' && drvr_name[1] == 'V')
#define IS_ORACLE(rcon) (strindex (rcon->rc_dbms, "Oracle"))
#define IS_SQLSERVER(rcon) (strstr (rcon->rc_dbms, "SQL Server") || strstr (rcon->rc_dbms, "S Q L   S e r v e r"))
#define IS_SQLSERVER_RDS(rds) (strstr (rds_get_info (rds, SQL_DBMS_NAME), "SQL Server") || strstr (rds_get_info (rds, SQL_DBMS_NAME), "S Q L   S e r v e r"))
#define IS_SYBASE_RDS(rds) \
		( \
		  (strstr (rds_get_info (rds, SQL_DBMS_NAME), "SQL Server") || \
		   strstr (rds_get_info (rds, SQL_DBMS_NAME), "Sybase 11 (ctlib)") || \
		   strstr (rds_get_info (rds, SQL_DBMS_NAME), "S Q L   S e r v e r") \
		  ) && \
		  !(strstr (rds_get_info (rds, SQL_DBMS_NAME), "Microsoft") || \
		   strstr (rds_get_info (rds, SQL_DBMS_NAME), "M i c r o s o f t") || \
		   strstr (rds_get_info (rds, SQL_DBMS_NAME), "MS SQL Server") \
		  ) \
		)
#define IS_VIRTUOSO_RDS(rds) (strstr (rds_get_info (rds, SQL_DBMS_NAME), "Virtuoso") != NULL)
#define IS_VIASERV_RDS(rds) ( \
		  (strstr (rds_get_info (rds, SQL_DBMS_NAME), "ViaSQL")) || \
 		  (!strcmp (rds_get_info (rds, SQL_DBMS_NAME), "LDS")) || \
		  (strstr (rds_get_info (rds, SQL_DRIVER_VER), "ViaSQL")) \
		)
#define IS_ORACLE_RDS(rds) (strindex (rds_get_info (rds, SQL_DBMS_NAME), "Oracle"))
#define IS_INFORMIX_RDS(rds) (nc_strstr ((unsigned char *) rds_get_info (rds, SQL_DBMS_NAME), (unsigned char *) "Informix") != NULL)
#define IS_PROGRESS_RDS(rds) (nc_strstr ((unsigned char *) rds_get_info (rds, SQL_DBMS_NAME), (unsigned char *) "Progress") != NULL)
#define SHOULD_USE_SCROLLABLE(rcon) (IS_SQLSERVER (rcon))
#define SHOULD_USE_SCROLLABLE_RDS(rds) (IS_SQLSERVER_RDS (rds))

#define IS_ORACLE_NATIVE_RDS(rds) (IS_ORACLE_RDS(rds) && \
    ((0 == strncmp(rds_get_info (rds, SQL_DRIVER_NAME),"SQORA", 5)) || \
     (0 == strncmp(rds_get_info (rds, SQL_DRIVER_NAME),"SQOCI", 5))))

#define IS_ORACLE_NATIVE_DRIVER(rcon) (IS_ORACLE(rcon) && \
    ((0 == strncmp(rcon->rc_driver_name, "SQORA", 5)) || \
     (0 == strncmp(rcon->rc_driver_name, "SQOCI", 5))))
#endif


/*
 * Added extensions for retrieving RDF literal/type  meta data
 * through ODBC interface
 */
#ifndef SQL_DESC_COL_DV_TYPE
#define SQL_DESC_COL_DV_TYPE           1057L
#define SQL_DESC_COL_DT_DT_TYPE        1058L
#define SQL_DESC_COL_LITERAL_ATTR      1059L
#define SQL_DESC_COL_BOX_FLAGS         1060L
#define SQL_DESC_COL_LITERAL_LANG      1061L
#define SQL_DESC_COL_LITERAL_TYPE      1062L
#endif
