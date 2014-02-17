/*
 *  sqlofn.h
 *
 *  $Id$
 *
 *  sql opt export functions
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

#ifndef _SQLOFN_H
#define _SQLOFN_H

void sqlo_top_select (sql_comp_t * sc, ST ** tree);
void sqlo_query_spec (sql_comp_t *sc, ptrlong is_distinct, caddr_t * selection,
    sql_tree_t * table_exp, data_source_t ** head_ret, state_slot_t *** sel_out_ret);
caddr_t sqlo_top (sql_comp_t * sc, ST ** volatile ptree, float * volatile score_ptr);

void sqlo_calculate_view_scope (query_instance_t *qi, ST **tree, char *view_name);
void sqlo_calculate_subq_view_scope (sql_comp_t *super_sc, ST **tree);

void sqlo_expand_group_by (caddr_t *selection, ST ***p_group_by, ptrlong *p_is_distinct);

int ssl_is_special (state_slot_t * ssl);

extern int sqlo_print_debug_output;

extern query_t *DBG_NAME(sql_compile_1) (DBG_PARAMS const char *string2, client_connection_t * cli,
	     caddr_t * err, volatile int cr_type, ST *the_parse_tree, char *view_name);
#ifdef MALLOC_DEBUG
#define sql_compile_1(s,c,e,ct,tpt,vn) dbg_sql_compile_1(__FILE__, __LINE__, (s),(c),(e),(ct),(tpt),(vn))
#endif

void t_st_or (ST ** cond, ST * pred);

#endif /* _SQLOFN_H */
