/*
 *  csrs.h
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

#ifndef _CRSR_H
#define _CRSR_H

#include "sqlcomp.h"

typedef struct id_cols_s
  {
    caddr_t	 idc_table;
    ptrlong *	idc_pos;
  } id_cols_t;

#ifndef ST
#define ST struct sql_tree_s
#endif

typedef struct query_cursor_s
  {
    id_cols_t **	qc_id_cols;
    long		qc_n_id_cols;
    ptrlong *		qc_order_cols;	/* position of all order cols in result set */
    long		 qc_n_select_cols;	/* This many from left to be sent to client */
    ST *		qc_org_text;
    ST **		qc_id_order_col_refs; /*subtree of text_with_ids */
    ST **		qc_order_by;

    ST *		qc_text_with_ids;	/* text w/ id + order cols */
    ST *		qc_referesh_text;
    ST *		qc_update_text;
    ST *		qc_delete_text;
    ST *		qc_insert_text;
    ST *		qc_pos_where;
    ST **		qc_next_text;
    ST **		qc_prev_text;
    ST *		qc_refresh_text;

    query_t *		qc_refresh;
    query_t *		qc_update;
    query_t *		qc_delete;
    query_t *		qc_insert;
    query_t **		qc_prev;
    query_t **qc_next;

    int		qc_cursor_type;		/* may differ from qr_cursor_type */
  } query_cursor_t;



typedef struct rowset_item_s
  {
    caddr_t *rsi_id;
    caddr_t *rsi_order;
    caddr_t rsi_checksum;
    caddr_t *rsi_row;
    struct rowset_item_s *rsi_next;
    struct rowset_item_s *rsi_prev;
  }
rowset_item_t;



typedef struct keyset_s
  {
    int kset_count;
    int kset_size;
    int kset_is_complete;	/* if all rows of cursor fit in */
/*    id_hash_t *kset_ids; 2 */
    rowset_item_t *kset_first;
    rowset_item_t *kset_last;
    rowset_item_t *kset_current;
    int kset_co_pos;
  }
keyset_t;

#define KSET_CO_FIRST 1
#define KSET_CO_LAST 2



#define CS_AT_START 1
#define CS_AT_END 2
#define CS_ON_ROW  3

#define FWD _SQL_FETCH_NEXT
#define BWD _SQL_FETCH_PRIOR
#define FIRST _SQL_FETCH_FIRST
#define LAST _SQL_FETCH_LAST



typedef struct cursor_state_s
  {
    caddr_t *cs_window_first;
    caddr_t *cs_window_last;
    caddr_t *cs_window_last_id;
    caddr_t *cs_window_first_id;
    caddr_t *cs_params;
    keyset_t *cs_keyset;
    int cs_keyset_pos;
    caddr_t cs_error;

    int cs_prev_dir;
    int cs_state;
    caddr_t *cs_from_order;
    caddr_t *cs_from_id;
    int cs_nth_cont;
    query_t *cs_query;
    local_cursor_t *cs_lc;
    stmt_options_t *cs_opts;
    client_connection_t *cs_client; /* 1 arg */
    srv_stmt_t *cs_stmt;

    int cs_lc_pos;
    rowset_item_t **cs_rowset;
    int cs_rowset_fill;
    long	cs_rowset_current_of;
    int cs_position;		/*index into rowset */

    /* for keyset/mixed mode */
    void *cs_client_data;
    int cs_n_scrolled;

    int cs_window_pos;
    caddr_t		cs_name;

    /* PL scrollable cursors */
    caddr_t *		cs_pl_output_row;
    long		cs_pl_state;
  } cursor_state_t;

#define CS_CR_TYPE(cs) cs->cs_query->qr_cursor->qc_cursor_type

#define CS_PL_ROW	1
#define CS_PL_AT_END	2
#define CS_PL_DELETED	3

#define CS_IS_PL_CURSOR(cs) cs->cs_stmt->sst_is_pl_cursor
#define STMT_IS_PL_CURSOR(stmt) stmt->sst_is_pl_cursor
#define CS_PL_SET_OUTPUT(cs, out) \
	{ \
	  dk_free_tree ((box_t) (cs)->cs_pl_output_row); \
	  (cs)->cs_pl_output_row = (caddr_t *) box_copy_tree ((box_t) out); \
	  (cs)->cs_pl_state = CS_PL_ROW; \
	}

/* cs_keyset_pos */
#define KSET_AT_START 1
#define KSET_MIDDLE 2
#define KSET_AT_END 3

/* cs_window_pos */
#define CS_WINDOW_START 0
#define CS_WINDOW_ROW 1
#define CS_WINDOW_END 2


/* cs_löc_pos */
#define LC_NONE 0
#define LC_AFTER_WINDOW 1
#define LC_BEFORE_WINDOW 2



#define _SQL_FETCH_NEXT			 1
#define _SQL_FETCH_FIRST		  2
#define _SQL_FETCH_LAST			 3
#define _SQL_FETCH_PRIOR			 4
#define _SQL_FETCH_ABSOLUTE		 5
#define _SQL_FETCH_RELATIVE		 6
#define _SQL_FETCH_BOOKMARK		 8

#define IS_FWD(f) (_SQL_FETCH_NEXT == f || _SQL_FETCH_FIRST == f)


#define _SQL_POSITION				0	/*	1.0 FALSE */
#define _SQL_REFRESH				 1	/*	1.0 TRUE */
#define _SQL_UPDATE					2
#define _SQL_DELETE					3
#define _SQL_ADD						4


typedef void (*kset_func) (cursor_state_t * cs);

extern long max_static_cursor_rows;
#define MAX_STATIC_CURSOR_ROWS max_static_cursor_rows
#define _MAX_STATIC_CURSOR_ROWS 5000

#define _SQL_BIND_BY_COLUMN 0

#define _SQL_CONCUR_VALUES 4

extern char __scroll_cr_init[17]	/* = "__scroll_cr_init" */;
extern char __scroll_cr_open[17]	/* = "__scroll_cr_open" */;
extern char __scroll_cr_close[18]	/* = "__scroll_cr_close" */;
extern char __scroll_cr_fetch[18]	/* = "__scroll_cr_fetch" */;

#define __SCROLL_CR_INIT	__scroll_cr_init
#define __SCROLL_CR_OPEN	__scroll_cr_open
#define __SCROLL_CR_CLOSE	__scroll_cr_close
#define __SCROLL_CR_FETCH	__scroll_cr_fetch

#endif /* _CRSR_H */
