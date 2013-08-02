/*
 *  eqlcomp.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

#ifndef _EQLCOMP_H
#define _EQLCOMP_H

#include "sqlcomp.h"
#include "sqlnode.h"

void eql_stmt_comp (comp_context_t * cc, caddr_t stmt, data_source_t ** head,
    data_source_t ** tail);

query_t *eql_compile_2 (const char *string, client_connection_t * cli, caddr_t * err,
	       int mode);
/* mode for sql_compile - other values are SQL_CURSOR_<xx> */
#define SQLC_DEFAULT _SQL_CURSOR_FORWARD_ONLY
#define SQLC_DO_NOT_STORE_PROC -1
#define SQLC_PARSE_ONLY 	-2
#define SQLC_NO_REMOTE -3
#define SQLC_TRY_SQLO -4
#define SQLC_SQLO_VERBOSE -5
#define SQLC_UNIQUE_ROWS -6
#define SQLC_SQLO_SCORE -7
#define SQLC_QR_TEXT_IS_CONSTANT -8
#define SQLC_IS_RECOMPILE  0x100
#define SQLC_PARSE_ONLY_REC 	-9
#define SQLC_STATIC_PRESERVES_TREE 	-10

query_t *eql_compile (const char *string, client_connection_t * cli);

caddr_t box_keyword_get (caddr_t * box, char *kwd, int *);

stmt_compilation_t *qr_describe (query_t * qr, caddr_t *err_ret);
stmt_compilation_t *qr_describe_1 (query_t * qr, caddr_t *err_ret, client_connection_t * cli);

caddr_t str_to_sym (const char *str);

void ts_free (table_source_t * ts);

void sel_free (select_node_t * sel);

#define SSL_ADD_TO_QR(sl) \
  dk_set_push (&cc->cc_super_cc->cc_query->qr_state_map, (void *) sl);

state_slot_t * ssl_copy (comp_context_t * cc, state_slot_t * org);

state_slot_t *ssl_new_variable (comp_context_t * cc, const char *name, dtp_t dtp);

state_slot_t *ssl_new_parameter (comp_context_t * cc, const char *name);

state_slot_t *ssl_new_column (comp_context_t * cc, const char *cr_name,
    dbe_column_t * col);

state_slot_t *ssl_new_inst_variable (comp_context_t * cc, const char *name,
    dtp_t dtp);
state_slot_t * ssl_new_vec (comp_context_t * cc, const char *name, dtp_t dtp);
state_slot_t * ssl_new_tree (comp_context_t * cc, const char *name);

extern state_slot_t *ssl_new_constant (comp_context_t * cc, caddr_t val);
extern state_slot_t *ssl_new_big_constant (comp_context_t * cc, caddr_t val);

state_slot_t *ssl_new_placeholder (comp_context_t * cc, const char *name);

state_slot_t *ssl_new_itc (comp_context_t * cc);

int cc_new_instance_slot (comp_context_t * cc);

void ins_free (insert_node_t * ins);

void upd_free (update_node_t * upd);

void ddl_free (ddl_node_t * ddl);

void sqlc_error (comp_context_t * cc, const char *st, const char *str,...);
void sqlc_new_error (comp_context_t * cc, const char *st, const char *virt_code, const char *str,...);
void sqlc_resignal_1 (comp_context_t * cc, caddr_t err);

EXE_EXPORT(query_t *, sql_compile, (const char *string2, client_connection_t * cli, caddr_t * err, volatile int store_procs));
EXE_EXPORT(query_t *, sql_proc_to_recompile, (const char *string2, client_connection_t * cli, caddr_t proc_name, int text_is_constant));

extern query_t *DBG_NAME (sql_compile) (DBG_PARAMS const char *string2, client_connection_t * cli, caddr_t * err,
    volatile int store_procs);
extern query_t *DBG_NAME (sql_proc_to_recompile) (DBG_PARAMS const char *string2, client_connection_t * cli, caddr_t proc_name,
    int text_is_constant);
#ifdef MALLOC_DEBUG
#ifndef _USRDLL
#ifndef EXPORT_GATE
#define sql_compile(s,c,e,sp) dbg_sql_compile(__FILE__,__LINE__,(s),(c),(e),(sp))
#define sql_proc_to_recompile(s,c,pn,tic) dbg_sql_proc_to_recompile(__FILE__,__LINE__,(s),(c),(pn),(tic))
#endif
#endif
#endif

#if defined (MALLOC_DEBUG) || defined (VALGRIND)
extern query_t *static_qr_dllist; /*!< Double-linked list of queries that should be freed only at server shutdown. */
extern query_t *dbg_sql_compile_static (const char *file, int line,
    const char *string2, client_connection_t * cli, caddr_t * err,
    volatile int store_procs);
#define sql_compile_static(s,c,e,sp) dbg_sql_compile_static(__FILE__,__LINE__,(s),(c),(e),(sp))
extern void static_qr_dllist_append (query_t *qr, int gpf_on_dupe);
extern void static_qr_dllist_remove (query_t *qr);
#else
extern query_t *sql_compile_static (const char *string2, client_connection_t * cli, caddr_t * err,
    volatile int store_procs);
#define static_qr_dllist_append(qr,g)
#define static_qr_dllist_remove(qr)
#endif
extern void sql_compile_many (int count, int compile_static, ...);

void sqlc_set_client (client_connection_t * cli);


#define TA_SQLC_ERROR 111
#define TA_SQLC_CURRENT_CLIENT 113
#define TA_SQL_WARNING_SET 115
#define TA_TARGET_RDS 116

void ks_spec_add (search_spec_t ** place, search_spec_t * sp);

void data_source_init (data_source_t * src, comp_context_t * cc, int type);

void ks_add_key_cols (comp_context_t * cc, key_source_t * ks, dbe_key_t * key,
    char *cr_name);

void ks_make_main_spec (comp_context_t * cc, key_source_t * ks, char *cr_name);

void query_free (query_t * query);


#define IS_TS_NODE(ts)  \
 ((qn_input_fn) table_source_input ==  ts->src_gen.src_input || \
  (qn_input_fn) table_source_input_unique == ts->src_gen.src_input)

void sqlc_ts_set_no_blobs (table_source_t * ts);

void ts_alias_current_of (table_source_t * ts);

void qr_add_current_of_output (query_t * qr);

void qr_resolve_aliases (query_t * qr);

int ssl_is_settable (state_slot_t * ssl);

typedef struct dependence_def_s
{
  id_hash_t *ddef_name_to_qr;
  dk_mutex_t *ddef_mtx;
} dependence_def_t;

typedef dk_set_t dependent_t;

dependence_def_t *dependence_def_new (int sz);
void qr_uses_object (query_t *qr, const char *object, dependent_t *dep, dependence_def_t *dependence);
void object_mark_affected (const char *object, dependence_def_t *dependence, int force_text_reparsing);
void qr_drop_obj_dependencies (query_t *qr, dependent_t *dep, dependence_def_t *ddef);

void qr_uses_table (query_t * qr, const char *tb);

void tb_mark_affected (const char *tb);
void udt_mark_affected (const char *tb);
extern void jso_mark_affected (const char *jso_inst);
int udt_is_qr_used (char *name);
void qr_uses_type (query_t * qr, const char *udt);
void qr_uses_jso (query_t * qr, const char *jso_iri);
void qc_free (struct query_cursor_s * qc);

search_spec_t ** ks_col_specs (key_source_t * ks, dbe_column_t * col,
	      int rm_from_row_specs);

void qr_garbage (query_t * qr, caddr_t garbage);

void sqlc_ins_keys (comp_context_t * cc, insert_node_t * ins);
void table_source_om (comp_context_t * cc, table_source_t * ts);
void qr_set_freeable (comp_context_t * cc, query_t * qr);

query_t *sqlc_make_policy_trig (comp_context_t *cc, dbe_table_t *tb, int op);

state_slot_t * ssl_with_info (comp_context_t * cc, state_slot_t * ssl);
state_slot_t * ssl_use_stock  (comp_context_t * cc, state_slot_t * ssl);
void stssl_ins (comp_context_t * cc, instruction_t * ins);
void stssl_query (comp_context_t * cc, query_t * qr);
void stssl_cv (comp_context_t * cc, instruction_t * cv);
void  il_init (comp_context_t * cc, inx_locality_t * il);
void key_source_om (comp_context_t * cc, key_source_t * ks);
void clb_free (cl_buffer_t * clb);
void dsr_free (data_source_t * x);
void qn_free (data_source_t * qn);
void cl_order_free (clo_comp_t ** ord);
void sp_list_free (dk_set_t sps);
void ks_free (key_source_t *ks);
void ik_array_free (ins_key_t ** iks);
void ssl_sort_by_index (state_slot_t ** ssls);

#endif /* __EQLCOMP_H_010520 */
