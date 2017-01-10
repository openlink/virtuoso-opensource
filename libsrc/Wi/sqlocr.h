/*
 * sqlocr.h
 *
 *  $Id$
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

#ifndef _SQLOCR_H
#define _SQLOCR_H

/* the functions used from the old cursors */
query_t *sqlc_cr_method (sql_comp_t * sc, ST ** ptree, int pass_state, int no_err);
void qc_make_continues (sql_comp_t * sc, query_cursor_t * qc);
int sqlc_is_updatable (sql_comp_t * sc, ST * tree);
ST *qc_make_insert (sql_comp_t * sc, query_cursor_t * qc);

/* the new cursor functions entry point */
int sqlo_cr_is_identifiable (sqlo_t * so, ST * tree);
int sqlo_qc_make_cols (sqlo_t * so, query_cursor_t * qc, ST * tree);
void sqlo_qc_make_stmts (sqlo_t * so, query_cursor_t * qc);

#endif /* _SQLOCR_H */
