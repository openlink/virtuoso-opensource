/*
 *  sqlcomp.h
 *
 *  $Id$
 *
 *  SQL Query Description
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

#ifndef _SQLCOMP_H
#define _SQLCOMP_H

/*  Answer Tags */
#define QA_ROW		1
#define QA_ERROR	3
#define QA_COMPILED	4
#define QA_NEED_DATA	5
#define QA_PROC_RETURN	6
#define QA_ROWS_AFFECTED 7
#define QA_BLOB_POS	8 /* occurs in sf_sql_get_data_ac answer array */
#define QA_LOGIN	9
#define QA_ROW_ADDED	10
#define QA_ROW_UPDATED	11
#define QA_ROW_DELETED	12
#define QA_ROW_LAST_IN_BATCH 13
#define QA_WARNING	14


/* The QA_ROWS_AFFECTED case */
#define QA_N_AFFECTED	1

/* Fields in QA_LOGIN */
#define LG_QUALIFIER	1
#define LG_DB_VER	2
#define LG_DB_CASEMODE	3
#define LG_DEFAULTS 	4
#define LG_CHARSET 	5
#define QA_LOGIN_FIELDS 6

/* Fields in s_sql_login info param */
#define LGID_APP_NAME	0
#define LGID_PID	1
#define LGID_MACHINE	2
#define LGID_OS		3
#define LGID_CHARSET	4
#define LGID_SHUTDOWN	5
/* The QA_ERROR case */
#define QA_ERRNO	1
#define QA_ERROR_STRING	2

/* Query Compilation Return */
#define QC_STATUS	0

/* Fields for compilation error */
#define QC_ERRNO	1
#define QC_ERROR_STRING	2


typedef struct stmt_compilation_s
  {
    caddr_t *		sc_columns;
    ptrlong		sc_is_select;
    caddr_t *		sc_cursors_used;
    caddr_t *		sc_params;
    ptrlong		sc_hidden_columns;
  } stmt_compilation_t;

/* values for sc_is_select */
#define QT_UPDATE 0
#define QT_SELECT 1
#define QT_PROC_CALL 2

#define SC_HIDDEN_COLUMNS(sc) \
  (sc && (box_length ((caddr_t) sc) > (ptrlong) & (((stmt_compilation_t*)0)->sc_hidden_columns)) \
   ? sc->sc_hidden_columns : 0)


typedef struct param_desc_s
  {
    caddr_t		pd_dtp;
    caddr_t		pd_prec;
    caddr_t		pd_scale;
    caddr_t		pd_nullable;
    /* Access the fileds below only if PARAM_DESC_IS_EXTENDED() is true. */
    caddr_t		pd_name;
    caddr_t		pd_iotype;
  } param_desc_t;

#define PARAM_DESC_IS_EXTENDED(param) \
  (param && (box_length ((caddr_t) param) > (ptrlong) & ((param_desc_t*)0)->pd_iotype))


/* Fields for output column */

typedef struct col_desc_s
  {
    char *		cd_name;
    ptrlong		cd_dtp;
    caddr_t		cd_scale;
    caddr_t		cd_precision;
    caddr_t		cd_nullable;
    caddr_t		cd_updatable;
    caddr_t		cd_searchable;
    /* Access the fileds below only if COL_DESC_IS_EXTENDED() is true. */
    char *		cd_base_catalog_name;
    char *		cd_base_column_name;
    char *		cd_base_schema_name;
    char *		cd_base_table_name;
    caddr_t		cd_flags;
  } col_desc_t;

#define COL_DESC_IS_EXTENDED(col) \
  (col && (box_length ((caddr_t) col) > (ptrlong) & ((col_desc_t*)0)->cd_flags))

#define CDF_KEY			1
#define CDF_AUTOINCREMENT	2
#define CDF_XMLTYPE		4 /* the column contains XML */


/* Statement Options */

typedef struct stmt_options_s {
  ptrlong            so_concurrency;
  ptrlong            so_is_async;
  ptrlong            so_max_rows;
  ptrlong            so_timeout;
  ptrlong            so_prefetch;
  ptrlong            so_autocommit;
  ptrlong            so_rpc_timeout;
  ptrlong		  so_cursor_type;
  ptrlong		  so_keyset_size;
  ptrlong		  so_use_bookmarks;
  ptrlong		  so_isolation;
  ptrlong		  so_prefetch_bytes;
  ptrlong		so_unique_rows;
} stmt_options_t;

#define SO_CURSOR_TYPE(so) \
  (so && (box_length ((caddr_t) so) > (ptrlong) & (((stmt_options_t*)0)->so_cursor_type)) \
   ? so->so_cursor_type : _SQL_CURSOR_FORWARD_ONLY)

#define SO_ISOLATION(so) \
  (so && (box_length ((caddr_t) so) > (ptrlong) & (((stmt_options_t*)0)->so_isolation)) \
   ? so->so_isolation : ISO_REPEATABLE)


#define SO_PREFETCH_BYTES(so) \
  (so && (box_length ((caddr_t) so) > (ptrlong) & (((stmt_options_t*)0)->so_prefetch_bytes)) \
   ? so->so_prefetch_bytes : 0)


#define SO_UNIQUE_ROWS(so) \
  (so && (box_length ((caddr_t) so) > (ptrlong) & (((stmt_options_t*)0)->so_unique_rows)) \
   ? so->so_unique_rows : 0)

#define SET_QR_TEXT(qr,text) \
  qr->qr_text = qr->qr_text_is_constant ?  (caddr_t) text : box_string (text)

#define _SQL_CURSOR_FORWARD_ONLY 	0
#define _SQL_CURSOR_KEYSET_DRIVEN	1
#define _SQL_CURSOR_DYNAMIC		2
#define _SQL_CURSOR_STATIC		3



#define SELECT_PREFETCH_QUOTA	20
#define PREFETCH_ALL -1

#define SO_DEFAULT_TIMEOUT	0 /* indefinite */


/* so_isolation */
#define ISO_UNCOMMITTED		1
#define ISO_COMMITTED		2
#define ISO_REPEATABLE 	4
#define ISO_SERIALIZABLE	8




/* so_isolation */
#define _SQL_TXN_READ_UNCOMMITTED	0x00000001L
#define _SQL_TXN_READ_COMMITTED		0x00000002L
#define _SQL_TXN_REPEATABLE_READ 	0x00000004L
#define _SQL_TXN_SERIALIZABLE		0x00000008L
#define _SQL_TXN_VERSIONING		0x00000010L

#endif /* _SQLCOMP_H */
