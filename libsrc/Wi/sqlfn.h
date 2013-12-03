/*
 *  sqlfn.h
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

#ifndef _SQLFN_H
#define _SQLFN_H

#include "sqlcomp.h"

#ifndef _SQLNODE_H_
#include "sqlnode.h"
#endif

/*! Commonly used description of fragment of source sql text, to pass data from SQL compiler to, say, SPARQL compiler. */
typedef struct scn3_include_frag_s {
  dk_session_t *sif_skipped_part;
  int sif_saved_lineno;
  int sif_saved_plineno;
  int sif_saved_lineno_increment;
  int sif_saved_lexdepth;
} scn3_include_frag_t;

struct user_s;
struct sparp_s;

typedef struct spar_query_env_s
{
  scn3_include_frag_t *	sparqre_src;	/*!< This is not for use in the parser! This is for inliner inside scn3.l only */
  int			sparqre_direct_client_call;	/*!< The result-set produced by the compiled query will go directly to the ODBC/JDBC client */
  ptrlong		sparqre_start_lineno;
  int *			sparqre_param_ctr;
  const char *		sparqre_tail_sql_text;
  int			sparqre_allow_sql_extensions;
  caddr_t		sparqre_base_uri;
#if 0
  xp_node_t * sparqre_nsctx_xn;		/*!< Namespace context as xp_node_t * */
  xml_entity_t *sparqre_nsctx_xe;	/*!< Namespace context as xml_entity_t * */
#endif
  query_instance_t *	sparqre_qi;		/*!< NULL if parsing is inside SQL compiler, current qi for runtime */
  client_connection_t *	sparqre_cli;		/*!< Client connection, can be NULL or what sqlc_client() return */
  struct sql_comp_s *	sparqre_super_sc;	/*!< The context of the compilation, if nested into SQL code */
  struct user_s *	sparqre_exec_user;	/*!< User that will execute the query */
  wcharset_t *		sparqre_query_charset;
  int			sparqre_query_charset_is_set;
  dk_set_t		sparqre_external_namespaces;
  /*dk_set_t *		sparqre_checked_functions;*/
  /*dk_set_t *		sparqre_sql_columns;*/
  int			sparqre_key_gen;
  caddr_t		sparqre_compiled_text;
  caddr_t		sparqre_catched_error;
  const char *		sparqre_dbg_query_text;	/*!< A source text as passed to the top-level sparql compilation. For debug purposes and for mem pool callback only. Can be NULL. */
  struct sparp_s *	sparqre_dbg_sparp;  /*!< A top-level instance of sparql compiler. For debug purposes and for mem pool callback only. Can be NULL; when non-NULL then the structure under pointer may be half-full. */
} spar_query_env_t;

extern int national_char;
extern int uname_strlit;

/* Place of an opened '(' or '{' */
typedef struct scn3_paren_s {
  int sp_open_line;	/*!< Line number where it has been opened */
  char sp_close_paren;	/*!< The character that should be used to close it (e.g. '}' if '{' is opened */
} scn3_paren_t;

extern int scn3_lineno;	/*!< Throughout counter of lines in the source text */
extern int scn3_plineno;	/*!< Physical counter of lines in the source text - used for the PL debugger */
extern int scn3_lineno_increment;	/*!< This is zero for 'macroexpanded' fragments of SQL text, to prevent from confusing when a long text is inserted instead of a single line */
extern int scn3_lexdepth;	/*!< Number of opened parenthesis */

extern dk_set_t scn3_namespaces; /*!< List of namespace prefixes and URIs */

#define SCN3_MAX_LEX_DEPTH 180	/*!< Maximum allowed number of any opened parenthesis in SQL text. SPARQL lexer has its own limit of the sort, \c SPARP_MAX_LEX_DEPTH */
extern scn3_paren_t scn3_parens[SCN3_MAX_LEX_DEPTH];

#define SCN3_MAX_BRACE_DEPTH 80		/*!< Maximum allowed number of any opened parenthesis outside pair of curly braces in SQL text. SPARQL lexer has its own limit of the sort, \c SPARP_MAX_BRACE_DEPTH */
#define SCN3_MAX_PRAGMALINE_DEPTH 4	/*!< Maximum nesting of line locations (i.e. 1 + (max no of nested '#pragma line push')) */

/*! Logical line location as it is set by #pragma line statements.
See the body of scn3_sprint_curr_line_loc() to find out how to use such data
to get a logical filename and line number for the correct position
in the source text. */
typedef struct scn3_line_loc_s {
/*! The value of scn3_lineno at the beginning of #pragma line. */
  int sll_start_lineno;
/*! The value of scn3_lexdepth at the beginning of #pragma line.
This is used to check that there are no cases when e.g. an '{' is
opened in one file and pair '}' is closed in some other file. */
  int sll_start_lexdepth;
/*! Line number as it is written in the body of #pragma line. */
  int sll_pragma_lineno;
/*! File name as it is written in the body of #pragma line. */
  caddr_t sll_pragma_file;
} scn3_line_loc_t;

/*! Stack of logical locations. */
extern scn3_line_loc_t scn3_line_locs[SCN3_MAX_PRAGMALINE_DEPTH];
/*! This is the number of not-yet-popped '#pragma line push' directives. */
extern int scn3_pragmaline_depth;


#define MAX_INCLUDE_DEPTH 4	/*!< Maximum nesting of includes or fragments in different languages. */

/*! Fragment written on one language (say, in SPARQL) that is included into the text on other language (say, in SQL) */
typedef struct scn3_include_fragment_s {
  struct yy_buffer_state *sif_buffer;
  scn3_include_frag_t _;
} scn3_include_fragment_t;

extern scn3_include_fragment_t scn3_include_stack [MAX_INCLUDE_DEPTH];

/*! Number of fragments that are started but not yet completed. It's zero while the whole text is in SQL */
extern int scn3_include_depth;

/*! Flag that indicates that yylex() is called from yy_new_error() and error during te call should not cause infinite recursion */
extern int scn3_inside_error_reporter;

extern dk_session_t *scn3split_ses;

extern void scn3_pragma_line (char *text);
extern void scn3_pragma_line_push (void);
extern void scn3_pragma_line_pop (void);
extern void scn3_pragma_line_reset (void);
extern int scn3_sprint_curr_line_loc (char *buf, size_t max_buf);
extern int scn3_get_lineno (void);
extern char *scn3_get_file_name (void);
extern void scn3_set_file_line (char *file, int file_nchars, int line_no);
extern void scn3_sparp_inline_subselect (spar_query_env_t *sparqre, const char * tail_sql_text, scn3_include_fragment_t *outer);
extern void sparp_compile_subselect (spar_query_env_t *sparqre);


void ts_set_placeholder (table_source_t * ts, caddr_t * state,
    it_cursor_t *itc, buffer_desc_t ** buf_ret);

void insert_node_input (insert_node_t * ins, caddr_t * inst, caddr_t * state);
void insert_node_run (insert_node_t * ins, caddr_t * inst, caddr_t * state);

void delete_node_input (delete_node_t * ins, caddr_t * inst, caddr_t * state);
void del_free (delete_node_t * del);

int box_is_string (char ** box, char * str, int from, int len);

void deref_node_input (deref_node_t * ins, caddr_t * inst, caddr_t * state);

void end_node_input (end_node_t * ins, caddr_t * inst, caddr_t * state);

void op_node_input (op_node_t * ins, caddr_t * inst, caddr_t * state);

void select_node_input (select_node_t * ins, caddr_t * inst, caddr_t * state);
void select_node_input_subq (select_node_t * sel, caddr_t * inst, caddr_t * state);
void select_node_input_scroll (select_node_t * sel, caddr_t * inst, caddr_t * state);
void  qf_select_node_input (qf_select_node_t * qfs, caddr_t * inst, caddr_t * state);
void cli_send_row_count (client_connection_t * cli, long n_affected, caddr_t * ret, du_thread_t * thr);
void skip_node_input (skip_node_t * ins, caddr_t * inst, caddr_t * state);
void qfs_free (qf_select_node_t * qfs);

void qn_input (data_source_t * xx, caddr_t * inst, caddr_t * state);
void qn_restore_local_save (data_source_t * qn, caddr_t * inst);
void qn_set_local_save (data_source_t * qn, caddr_t * inst);
void qi_extend_anytime (caddr_t * inst, float ext_pct);
void cli_anytime_timeout (client_connection_t * cli);
void cli_terminate_in_itc_fail (client_connection_t * cli, it_cursor_t * itc, buffer_desc_t ** buf);
int err_is_anytime (caddr_t err);

#define QI_CHECK_ANYTIME_RST(qi, reset_code) \
  if (RST_DEADLOCK == reset_code && (LT_PENDING == qi->qi_trx->lt_status || LT_FREEZE == qi->qi_trx->lt_status)) \
    { reset_code = RST_ERROR; qi->qi_thread->thr_reset_code = srv_make_new_error (SQL_ANYTIME, "RC...", "Anytime in itc ctx"); }


void qn_send_output (data_source_t * src, caddr_t * state);

void qn_ts_send_output (data_source_t * src, caddr_t * state,
    code_vec_t after_join_test);

void qr_resume_pending_nodes (query_t * subq, caddr_t * inst);
caddr_t qi_handle_reset (query_instance_t * qi, int reset);
void subq_init (query_t * subq, caddr_t * inst);
void qn_init (table_source_t * ts, caddr_t * inst);

#define QI_BUNION_RESET(qi, qr, is_subq) \
  if (RST_AT_END == reset_code) \
    goto qr_complete; \
  if (qr->qr_bunion_node && RST_ERROR == reset_code) \
    { \
      caddr_t bun_ret = qi_bunion_reset (qi, qr, is_subq); \
      if (SQL_BUNION_COMPLETE == bun_ret) \
	goto qr_complete; \
      return bun_ret; \
    }

/* SQL_BUNION_COMPLETE must be different from SQL_SUCCESS, SQL_ERROR et al */
#define SQL_BUNION_COMPLETE ((caddr_t) -11)

caddr_t qi_bunion_reset (query_instance_t * qi, query_t * qr, int is_subq);



EXE_EXPORT (caddr_t, qr_exec, (client_connection_t * cli, query_t * qr, query_instance_t * caller, caddr_t cr_name, srv_stmt_t * stmt, local_cursor_t ** ret, caddr_t * parms, stmt_options_t * opts, int named_params));

caddr_t qr_dml_array_exec (client_connection_t * cli, query_t * qr,
			   query_instance_t * caller, caddr_t cr_name, srv_stmt_t * stmt,
			   caddr_t ** param_array, stmt_options_t * opts);


caddr_t qr_subq_exec (client_connection_t * cli, query_t * qr,
    query_instance_t * caller, caddr_t * auto_qi, int auto_qi_len,
    local_cursor_t * lc, caddr_t * parms, stmt_options_t * opts);
caddr_t qr_subq_exec_vec (client_connection_t * cli, query_t * qr,
			  query_instance_t * caller, caddr_t * auto_qi, int auto_qi_len,
			  state_slot_t ** parms, state_slot_t * ret, stmt_options_t * opts, local_cursor_t * lc);


#define AUTO_QI_DEFAULT_SZ (sizeof (query_instance_t) + 80 * sizeof (caddr_t))

caddr_t qr_more (caddr_t * inst);

caddr_t qr_quick_exec (query_t * qr, client_connection_t * cli, char * id,
    local_cursor_t ** cursor, long n_pars, ...);

query_t * qr_recompile (query_t * qr, caddr_t * err_ret);

/* Parameter types */
#define QRP_INT (long)0
#define QRP_STR (long)1
#define QRP_RAW (long)2

caddr_t lc_get_col (local_cursor_t * lc, char * name);

void lc_free (local_cursor_t * lc);

long lc_next (local_cursor_t * lc);
#define LC_FREE(lc) if (lc) \
    		      lc_free (lc)

caddr_t qr_quick_exec (query_t * qr, client_connection_t * cli, char * id,
		       local_cursor_t ** lc_ret, long n_pars, ...);

/* ddlrun.c */

char * ddl_complete_table_name (query_instance_t * qi, char *name);
void ddl_ensure_univ_tables (void);

void ddl_std_proc (const char * text, int is_public);
void ddl_std_proc_1 (const char *text, int is_public, int to_recompile);
#define DDL_STD_REENTRANT 0x40
void ddl_ensure_table (const char *name, const char *text);
void ddl_ensure_column (const char *table, const char *col, const char *text, int is_drop);
void ddl_sel_for_effect (const char *str);


void ddl_create_table (query_instance_t * cli, const char * name, caddr_t * cols);

void ddl_create_sub_table (query_instance_t * cli, char * name,
    caddr_t * supers, caddr_t * cols);

void ddl_create_primary_key (query_instance_t * cli, char * table, char * key,
			     caddr_t * parts, int cluster_on_id, int is_object_id, caddr_t * opts);

void ddl_create_key (query_instance_t * cli, char * table, char * key,
		     caddr_t * parts, int cluster_on_id, int is_object_id, int is_unique, int is_bitmap, caddr_t * opts);

void ddl_add_col (query_instance_t * cli, const char * table, caddr_t * col);

void ddl_drop_index (caddr_t * qst, const char * table, const char * name, int log_to_trx);

void ddl_drop_trigger (query_instance_t * qi, const char * name);

void ddl_store_proc (caddr_t * state, op_node_t * op);
void ddl_store_method (caddr_t * state, op_node_t * op);

void ddl_build_index (query_instance_t * qi, char * table, char * name, caddr_t * repl);

int inx_opt_flag (caddr_t * opts, char *name);

int inx_opt_flag (caddr_t * opts, char *name);

int inx_opt_flag (caddr_t * opts, char *name);

int inx_opt_flag (caddr_t * opts, char *name);

dtp_t ddl_type_to_dtp (caddr_t * type);
int dtp_parse_options (char *ck, sql_type_t *psqt, caddr_t *opts);

long ddl_type_to_prec (caddr_t * type);
int ddl_type_to_scale (caddr_t * type);
caddr_t * ddl_type_tree (caddr_t * type);

caddr_t * qn_get_in_state (data_source_t * src, caddr_t * inst);

void qn_record_in_state (data_source_t * src, caddr_t * inst, caddr_t * state);

/*gets rid of col types that just refer to storage versions of one actual type */
#if 1
#define DTP_NORMALIZE(dtp) \
  dtp = dtp_canonical[dtp]
#else
#define DTP_NORMALIZE(dtp) \
switch (dtp) \
{ \
 case DV_WIDE: dtp = DV_LONG_WIDE; break; \
 case DV_INT64: \
 case DV_SHORT_INT: dtp = DV_LONG_INT; break; \
 case DV_IRI_ID_8: dtp = DV_IRI_ID; break; \
}
#endif



void table_source_input (table_source_t * ts, caddr_t * inst,
    caddr_t * volatile state);
void inx_op_source_input (table_source_t * ts, caddr_t * inst,
    caddr_t * volatile state);
int table_source_input_rdf_range (table_source_t * ts, caddr_t * inst, caddr_t * state);
extern dk_mutex_t * alt_ts_mtx;
void table_source_input_unique (table_source_t * ts, caddr_t * inst,
    caddr_t * state);

void table_source_free (table_source_t * ts);

int ks_make_spec_list (it_cursor_t * it, search_spec_t * ks_spec, caddr_t * state);
/* when cast fails and cast errors suppressed, ks_cast_dtp_lt when value below the col dtp in ANY order, else ks_cast_dtp_gt */
#define KS_CAST_OK 0
#define KS_CAST_NULL 1
#define KS_CAST_DTP_LT 2
#define KS_CAST_DTP_GT 4
#define KS_CAST_UNDEF 16

int ks_start_search (key_source_t * ks, caddr_t * inst, caddr_t * state,
    it_cursor_t * itc, buffer_desc_t ** buf_ret, table_source_t * ts,
		 int search_mode);
int itc_il_search (it_cursor_t * itc, buffer_desc_t ** buf_ret, caddr_t * qst,
	       inx_locality_t * il, placeholder_t * pl, int is_asc);

void ts_outer_output (table_source_t * ts, caddr_t * qst);

void hash_fill_node_input (fun_ref_node_t * fref, caddr_t * inst, caddr_t * qst);
void hash_source_input (hash_source_t * hs, caddr_t * qst, caddr_t * qst_cont);
void hash_source_free (hash_source_t * hs);
void hash_source_vec_input (hash_source_t * hs, caddr_t * qst, caddr_t * qst_cont);
void hash_source_free (hash_source_t * hs);
void fun_ref_free (fun_ref_node_t * fref);
void gs_union_free (gs_union_node_t * gsu);


void ddl_node_input (ddl_node_t * ddl, caddr_t * inst, caddr_t * state);

void read_proc_and_trigger_tables (int remotes);
void read_utd_method_tables (void);
void ddl_read_constraints (char *spec_tb_name, caddr_t *qst);

void ddl_init_schema (void);

void ddl_init_proc (void);

void ddl_standard_procs (void);

EXE_EXPORT (void, ddl_commit, (query_instance_t * qi));

void sql_ddl_node_input (ddl_node_t * ddl, caddr_t * inst, caddr_t * state);

void srv_global_init (char * mode);

EXE_EXPORT (client_connection_t *, client_connection_create, (void));
EXE_EXPORT (void, client_connection_reset, (client_connection_t * cli));

typedef dk_session_t * (*client_connection_reset_hook_type) (dk_session_t *);

client_connection_reset_hook_type
client_connection_set_reset_hook (client_connection_reset_hook_type new_hook);
void client_connection_set_worker_ses (client_connection_t *cli, dk_session_t *ses);

void srv_close (void);

typedef struct server_lock_s
{
  int		sl_count;
  du_thread_t *	sl_owner;
  lock_trx_t *	sl_owner_lt;
  dk_set_t	sl_waiting;
  int		sl_ac_save; /* for atomic mode, save the cli ac flag */
  int 		sl_qp_save;
} server_lock_t;

extern server_lock_t server_lock;

void plh_free (placeholder_t * plh);

EXE_EXPORT (caddr_t, srv_make_new_error, (const char *code, const char *virt_code, const char *msg,...));
#ifndef _USRDLL
#ifdef __GNUC__
caddr_t srv_make_new_error (const char *code, const char *virt_code, const char *msg,...) __attribute__ ((format (printf, 3, 4)));
#endif
#endif
EXE_EXPORT (void, qi_enter, (query_instance_t * qi));
EXE_EXPORT (void, qi_leave, (query_instance_t * qi));

int lt_close (lock_trx_t * lt, int fcommit);

#define lt_threads_inc_inner(lt) \
    do \
      { \
	ASSERT_IN_TXN; \
	if ((lt)->lt_threads != 0) \
	  GPF_T1 ("lt_threads not 0 in increment"); \
	(lt)->lt_threads ++; \
	(lt)->lt_thr = THREAD_CURRENT_THREAD; \
	LT_THREADS_REPORT (lt, "INC"); \
	LT_ENTER_SAVE (lt); \
      } \
    while (0)

#define lt_threads_dec_inner(lt) \
    do \
      { \
	ASSERT_IN_TXN; \
	if ((lt)->lt_threads != 1) \
	  GPF_T1 ("lt_threads not 1 in decrement"); \
	(lt)->lt_threads --; \
	(lt)->lt_thr = NULL; \
	LT_THREADS_REPORT (lt, "DEC"); \
	LT_ENTER_SAVE (lt); \
      } \
    while (0)

#define lt_threads_set_inner(lt,threads) \
    do \
      { \
	ASSERT_IN_TXN; \
	if ((threads) != 0 && (threads) != 1) \
	  GPF_T1 ("lt_threads not 1 or 0 in set"); \
	(lt)->lt_threads = (threads); \
	(lt)->lt_thr = (threads) ? THREAD_CURRENT_THREAD : NULL; \
	LT_THREADS_REPORT (lt, "SET"); \
	LT_ENTER_SAVE (lt); \
      } \
    while (0)


#ifdef CHECK_LT_THREADS
void log_debug_dummy (char * str, ...);
int lt_enter_real (lock_trx_t * lt);
int lt_leave_real (lock_trx_t * lt);
#define lt_enter(lt) \
    (LT_THREADS_REPORT (lt, "LT_ENTER"), lt_enter_real(lt))
#define lt_leave(lt) \
    (LT_THREADS_REPORT (lt, "LT_LEAVE"), lt_leave_real(lt))
#else
EXE_EXPORT (int, lt_enter, (lock_trx_t * lt));
EXE_EXPORT (int, lt_leave, (lock_trx_t * lt));
#endif
int lt_enter_anyway (lock_trx_t * lt);


void qi_free (caddr_t * inst);
void qi_inst_state_free_rsts (caddr_t *qi);
#if 0
extern void qi_check_buf_writers (void);
#else
#define qi_check_buf_writers()
#endif
void ddl_fk_init (void);

void ddl_scheduler_init (void);
void ddl_scheduler_arfw_init (void);

void ddl_repl_init (void);
/* Transaction Functions */

#define QI_PENDING 0
#define QI_DONE 1
#define QI_ERROR 2


void cli_scrap_cursors (client_connection_t * cli,
    query_instance_t * exceptions, lock_trx_t * this_trx_only);
void cli_rcon_free (client_connection_t * cli);

caddr_t cli_transact (client_connection_t * cli, int op, caddr_t * replicate);
caddr_t srv_make_trx_error (int code, caddr_t detail);


#define MAKE_TRX_ERROR(code, err, detail) \
  err = srv_make_trx_error (code, detail)

#define SEND_TRX_ERROR(err, qi, code, reason) \
  MAKE_TRX_ERROR (code, err, reason); \
  if (qi->qi_caller == CALLER_CLIENT) \
    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);

#define SEND_TRX_ERROR_CALLER(err, caller, code, reason) \
  MAKE_TRX_ERROR (code, err, reason); \
  if (caller == CALLER_CLIENT) \
    PrpcAddAnswer (err, DV_ARRAY_OF_POINTER, 1, 1);


caddr_t qi_txn_code (int rc, query_instance_t * caller, caddr_t reason);

int qi_kill (query_instance_t * qi, int is_error);

void qi_detach_from_stmt (query_instance_t * qi);

EXE_EXPORT (void, sqlr_error, (const char * code, const char * msg, ...));
EXE_EXPORT (void, sqlr_new_error, (const char *code, const char *virt_code, const char *msg, ...));
#ifdef __GNUC__
extern void sqlr_error (const char * code, const char * msg, ...) __attribute__ ((format (printf, 2, 3)));
extern void sqlr_new_error (const char *code, const char *virt_code, const char *msg, ...) __attribute__ ((format (printf, 3, 4)));
#endif

void sqlr_warning (const char *code, const char *virt_code, const char *msg, ...);
#ifdef __GNUC__
void sqlr_warning (const char *code, const char *virt_code, const char *msg, ...) __attribute__ ((format (printf, 3, 4)));
#endif
void sqlc_warning (const char *code, const char *virt_code, const char *msg, ...);
#ifdef __GNUC__
void sqlc_warning (const char *code, const char *virt_code, const char *msg, ...) __attribute__ ((format (printf, 3, 4)));
#endif
void sql_warnings_clear (void);
void sql_warnings_send_to_cli (void);
void sql_warning_add (caddr_t err, int is_comp);
dk_set_t sql_warnings_save (dk_set_t new_warnings);

#define SQW_DTP_COERCE(dtp) \
	(IS_NUM_DTP(dtp) ? DV_NUMERIC : \
	 (dtp) == DV_IRI_ID_8 ? DV_IRI_ID \
: ((dtp) == DV_REFERENCE ? DV_OBJECT :	  \
	  ((dtp) == DV_DB_NULL ? DV_ANY : \
	  (IS_BLOB_DTP (dtp) ? DV_ANY : \
	   (dtp)))))

#define SQW_DTP_COLIDE(ldtp,lclass,rdtp,rclass) \
    (SQW_DTP_COERCE (ldtp) != DV_ANY && \
     SQW_DTP_COERCE (rdtp) != DV_ANY && \
     (SQW_DTP_COERCE (ldtp) != SQW_DTP_COERCE (rdtp) || \
      (DV_OBJECT == SQW_DTP_COERCE (ldtp) && rclass && lclass && \
       !udt_instance_of ((rclass), (lclass)) \
      ) \
     ))


/*#define RESIGNAL_TRACE*/
#ifdef RESIGNAL_TRACE
#define sqlr_resignal(e) sqlr_dbg_resignal (e, __FILE__, __LINE__)
void sqlr_dbg_resignal (caddr_t e, char * file, int line);
#else
EXE_EXPORT (void, sqlr_resignal, (caddr_t err));
#endif

#define TA_IMMEDIATE_CLIENT 1009
#define GET_IMMEDIATE_CLIENT_OR_NULL \
	((client_connection_t *)(IMMEDIATE_CLIENT_OR_NULL && IMMEDIATE_CLIENT ? DKS_DB_DATA (IMMEDIATE_CLIENT) : THR_ATTR (THREAD_CURRENT_THREAD, TA_IMMEDIATE_CLIENT)))

#define TA_REPORT_BUFFER	1212
#define TA_REPORT_PTR		1213
#define TA_REPORT_QST		1214
#define TA_SQLC_ASG_SET 1215
#define TA_DBG_STR 1216
#define TA_STAT_INST 1217
#define TA_TOTAL_RDTSC 1218

void update_node_input (update_node_t * del, caddr_t * inst, caddr_t * state);

void current_of_node_input (current_of_node_t * del, caddr_t * inst,
    caddr_t * state);
caddr_t upd_nth_value (update_node_t * upd, caddr_t * state, int nth);
int upd_n_cols  (update_node_t * upd, caddr_t * state);
oid_t upd_nth_col  (update_node_t * upd, caddr_t * state, int inx);
void upd_col_copy (dbe_key_t * key, dbe_col_loc_t * new_cl, db_buf_t new_image, int * v_fill, int max,
	      dbe_col_loc_t * old_cl, db_buf_t  old_image, int old_off, int old_len);
dk_set_t  upd_ha_pre (update_node_t * upd, query_instance_t * qi);
void lt_hi_row_change (lock_trx_t * lt, key_id_t key, int log_op, db_buf_t log_entry);
int  it_hi_done (index_tree_t * it);
void cli_set_trx (client_connection_t * cli, lock_trx_t * trx);
lock_trx_t * cli_set_new_trx (client_connection_t *cli);
lock_trx_t * cli_set_new_trx_no_wait_cpt (client_connection_t *cli);


void qr_free (query_t * qr);

void upd_insert_2nd_key (dbe_key_t * key, it_cursor_t * ins_itc,
			 row_delta_t * rd);

int itc_from_sort_temp (it_cursor_t * itc, query_instance_t * qi, state_slot_t * tree);
int itc_replace_row (it_cursor_t * main_itc, buffer_desc_t * main_buf,
		     row_delta_t * rd, caddr_t * state, int this_key_only);
void itc_make_deref_spec (it_cursor_t * itc, caddr_t * loc);

#define REPLACE_OK 1
#define REPLACE_RETRY 0

long ddl_name_to_prec (char *name);
dtp_t ddl_name_to_dtp (char *name);
dtp_t ddl_name_to_dtp_1 (char *name, int err_if_not);
caddr_t ddl_col_scale (char *name);
caddr_t ddl_col_nullable (char *name);
/* log.c */

void log_insert (lock_trx_t * lt, row_delta_t * rd, int flag);
#define LOG_KEY_ONLY 128 /* or to insert flags to mark that the rd's key only is to be remade at replay */
#define LOG_SYNC 256  /* with non txn insert, log_insert with this flag writes immediately */
#define LOG_ANY_AS_STRING 512
void log_update (lock_trx_t * lt, row_delta_t * rd,
    update_node_t * upd, caddr_t * qst);

void log_dd_change (lock_trx_t * lt, char * tb);
void log_dd_type_change (lock_trx_t * lt, char * udt, caddr_t tree);
void log_sc_change_1 (lock_trx_t * lt);
void log_sc_change_2 (lock_trx_t * lt);

void log_text (lock_trx_t * lt, char * text);

void log_text_array (lock_trx_t * lt, caddr_t box);
void log_text_array_as_user (user_t * usr, lock_trx_t * lt, caddr_t box);
int log_text_array_sync (lock_trx_t * lt, caddr_t box);

void log_sequence (lock_trx_t * lt, char * text, boxint count);
int log_sequence_sync (lock_trx_t * lt, char *text, boxint count);
void log_sequence_remove (lock_trx_t * lt, char *text);
void log_registry_set (lock_trx_t * lt, char * k, const char * d);

int log_commit (lock_trx_t * lt);
int log_final_transact(lock_trx_t* lt, int is_commit);

int log_enable_segmented (int rewrite);


caddr_t log_new_name(char * log_name);

void log_init (dbe_storage_t * dbs);

int sp_lt_check_error (client_connection_t * cli);

void row_insert_node_input (row_insert_node_t * ins, caddr_t * inst,
    caddr_t * state);

void key_insert_node_input (key_insert_node_t * ins, caddr_t * inst,
    caddr_t * state);

void fun_ref_node_input (fun_ref_node_t * fref, caddr_t * inst,
    caddr_t * state);
void cl_fref_input (fun_ref_node_t * fref, caddr_t * inst, caddr_t * state);

void gs_union_node_input (gs_union_node_t * gsu, caddr_t * inst, caddr_t * state);

caddr_t qst_get (caddr_t * state, state_slot_t * sl);

placeholder_t * qst_place_get (caddr_t * state, state_slot_t * sl);

caddr_t * qst_copy (caddr_t * qst, state_slot_t ** copy_ssls, ssl_index_t * cp_sets);

void qst_free (caddr_t * qst);

void qst_set (caddr_t * state, state_slot_t * sl, caddr_t v);
void qst_set_over (caddr_t * qst, state_slot_t * ssl, caddr_t v);
void qst_set_copy (caddr_t * state, state_slot_t * sl, caddr_t v);
void qst_set_null (caddr_t * inst, state_slot_t * ssl);
void qst_swap (caddr_t * state, state_slot_t * sl, caddr_t *v);
extern int qst_swap_or_get_copy (caddr_t * state, state_slot_t * sl, caddr_t *v);


void qst_set_float (caddr_t * state, state_slot_t * sl, float fv);

void qst_set_long (caddr_t * state, state_slot_t * sl, boxint lv);

void qst_set_double (caddr_t * state, state_slot_t * sl, double dv);

void qst_set_string (caddr_t * state, state_slot_t * sl, db_buf_t data, size_t len, uint32 flags);

void qst_set_wide_string (caddr_t * state, state_slot_t * sl, db_buf_t data,
    int len, dtp_t dtp, int isUTF8);

void qst_set_numeric_buf (caddr_t * state, state_slot_t * sl, db_buf_t xx);

void qst_set_bin_string (caddr_t * state, state_slot_t * sl, db_buf_t data,
    size_t len, dtp_t dtp);

void ssl_free_data (state_slot_t * sl, caddr_t data);

void itc_qst_set_column (it_cursor_t * it, buffer_desc_t * buf, dbe_col_loc_t * cl,
		    caddr_t * qst, state_slot_t * target);


caddr_t * qst_address (caddr_t * state, state_slot_t * sl);

#define SSL_IS_REFERENCEABLE(ssl) (ssl->ssl_type != SSL_CONSTANT)

void qst_set_ref (caddr_t * state, state_slot_t * sl, caddr_t * v);

void ssl_alias (state_slot_t * alias, state_slot_t * real);

void ssl_copy_types (state_slot_t * to, state_slot_t * from);

caddr_t qr_rec_exec (query_t * qr, client_connection_t * cli,
    local_cursor_t ** lc_ret, query_instance_t * caller, stmt_options_t * opts,
    long n_pars, ...);

caddr_t lc_nth_col (local_cursor_t * lc, int n);

caddr_t sel_out_get (caddr_t * out_copy, int inx, state_slot_t * sl);

caddr_t lc_take_or_copy_nth_col (local_cursor_t * lc, int n);

oid_t cli_new_col_id (client_connection_t * cli);

void itc_delete_this (it_cursor_t * del_itc, buffer_desc_t ** del_buf, int res,
    int maybe_blobs);

#define NO_BLOBS 0
#define MAYBE_BLOBS 1

caddr_t qi_nth_col (query_instance_t * qi, int current_of, int n);

int qi_check_1_distinct (query_instance_t * qi, caddr_t data, int data_id, state_slot_t *st);

int setp_node_run (setp_node_t * setp, caddr_t * inst, caddr_t * state, int delete_blobs);
void setp_node_input (setp_node_t * setp, caddr_t * inst, caddr_t * state);
void setp_node_free (setp_node_t * setp);
int setp_top_pre (setp_node_t * setp, caddr_t * qst, int * is_ties_edge);
void subq_node_free (subq_source_t * sqs);
void union_node_free (union_node_t * un);
void end_node_free (end_node_t * en);

void setp_temp_clear (setp_node_t * setp, hash_area_t * ha, caddr_t * qst);
void setp_mem_sort_flush (setp_node_t * setp, caddr_t * qst);
void setp_mem_sort (setp_node_t * setp, caddr_t * qst, int n_sets, int merge_set);
void setp_filled (setp_node_t * setp, caddr_t * qst);

void union_node_input (union_node_t * setp, caddr_t * inst, caddr_t * state);

void subq_node_input (subq_source_t * setp, caddr_t * inst, caddr_t * state);
void subq_node_free (subq_source_t * sqs);
void cl_subq_node_input (subq_source_t * sqs, caddr_t * inst, caddr_t * state);

void breakup_node_input (breakup_node_t * brk, caddr_t * inst, caddr_t * state);
void breakup_node_free (breakup_node_t * brk);

void iter_node_vec_input (data_source_t * qn, iter_node_t * in, caddr_t * inst, caddr_t * state, caddr_t * array);
void in_iter_input (in_iter_node_t * brk, caddr_t * inst, caddr_t * state);
void in_iter_free (in_iter_node_t * brk);
void sort_read_input (table_source_t * ts, caddr_t * inst, caddr_t * state);
void  set_ctr_input (set_ctr_node_t * sctr, caddr_t * inst, caddr_t * state);
void set_ctr_free (set_ctr_node_t * sctr);
void  outer_seq_end_input (outer_seq_end_node_t * ose, caddr_t * inst, caddr_t * state);
void ose_free (outer_seq_end_node_t * ose);

void breakup_node_input (breakup_node_t * brk, caddr_t * inst, caddr_t * state);
void breakup_node_free (breakup_node_t * brk);

void in_iter_input (in_iter_node_t * brk, caddr_t * inst, caddr_t * state);
void in_iter_free (in_iter_node_t * brk);
void sort_read_input (table_source_t * ts, caddr_t * inst, caddr_t * state);


void breakup_node_input (breakup_node_t * brk, caddr_t * inst, caddr_t * state);
void breakup_node_free (breakup_node_t * brk);

void in_iter_input (in_iter_node_t * brk, caddr_t * inst, caddr_t * state);
void in_iter_free (in_iter_node_t * brk);
void sort_read_input (table_source_t * ts, caddr_t * inst, caddr_t * state);


void pl_source_input (pl_source_t * pls, caddr_t * inst,
		    caddr_t * state);
void pl_source_free (pl_source_t * pls);

int err_is_state (caddr_t err, char * state);

EXE_EXPORT (void, local_commit, (client_connection_t * cli));
EXE_EXPORT (void, local_start_trx, (client_connection_t * cli));
EXE_EXPORT (void, local_commit_end_trx, (client_connection_t * cli));
EXE_EXPORT (void, local_rollback_end_trx, (client_connection_t * cli));

caddr_t code_vec_run_1 (code_vec_t code_vec, caddr_t * qst, int offset);
#define code_vec_run(c, i) code_vec_run_1 (c, i, 0)
#define CV_THIS_SET_ONLY -1
caddr_t code_vec_run_no_catch (code_vec_t code_vec, it_cursor_t *itc);

void cv_free (code_vec_t cv);

/* RPS's called from inside */

void client_connection_free (client_connection_t * cli);

void vdb_enter (query_instance_t * qi);
void vdb_leave (query_instance_t * qi);
void vdb_leave_1 (query_instance_t * qi, caddr_t *err_ret);
void vdb_enter_lt_nc (lock_trx_t * lt);
void vdb_enter_lt (lock_trx_t * lt);
void vdb_enter_lt_1 (lock_trx_t * lt, caddr_t * err_ret, int enter_always);
void vdb_leave_lt (lock_trx_t * lt, caddr_t *err_ret);

void remote_table_source_input (remote_table_source_t * ts, caddr_t * inst,
    caddr_t * state);
void rts_skip_to_set (remote_table_source_t * rts, caddr_t * inst, int set);
int  rts_target_set (remote_table_source_t * rts, caddr_t * inst, state_slot_t * set_ssl, int set_no);



caddr_t deref_node_main_row (it_cursor_t * it, buffer_desc_t ** buf,
    dbe_key_t * key, it_cursor_t * main_itc);

client_connection_t * sqlc_client (void);

char * cli_owner (client_connection_t * cli);

char * sch_full_proc_name (dbe_schema_t * sc, const char * ref_name,
    char * q_def, char * o_def);
char * sch_full_proc_name_1 (dbe_schema_t * sc, const char * ref_name,
    char * q_def, char * o_def, char *m_def);
char * sch_full_module_name (dbe_schema_t * sc, char * ref_name,
    char * q_def, char * o_def);
char * cli_qual (client_connection_t * cli);

long bh_get_data_from_user (blob_handle_t * bh, client_connection_t * cli,
    db_buf_t to, int max_bytes);
void bh_set_it_fields (blob_handle_t *bh);

void cli_end_blob_read (client_connection_t * cli);

#define BLOB_NONE_RECEIVED 0
#define BLOB_DATA_COMING 1
#define BLOB_ALL_RECEIVED 2
#define BLOB_NULL_RECEIVED 3

void ks_get_cols (key_source_t * ks, caddr_t * state, it_cursor_t * it,
    buffer_desc_t * buf);
long bh_get_data_from_http_user (blob_handle_t * bh, client_connection_t * cli,
    db_buf_t to, int max_bytes);
long bh_get_data_from_http_user_no_err (blob_handle_t * bh, client_connection_t * cli,
    db_buf_t to, int max_bytes);

int itc_get_alt_key (it_cursor_t * del_itc, buffer_desc_t ** alt_buf_ret,
		 dbe_key_t * alt_key, row_delta_t * rd);


void itc_copy_row (it_cursor_t * itc, buffer_desc_t * buf, db_buf_t copy);

void itc_make_pl (it_cursor_t * itc, buffer_desc_t * buf);

/* update.c */

void rd_inline (query_instance_t * qi, row_delta_t * rd, caddr_t * err_ret, int log_mode);
void upd_blob_opt (query_instance_t * qi, row_delta_t * rd, caddr_t * err_ret);
int  box_col_len (caddr_t box);
void upd_refit_row (it_cursor_t * it, buffer_desc_t ** buf, row_delta_t * rd, int op);
/* in upd refit row, mark if compressibles changed */
#define UPD_NO_COMP 1
#define UPD_COMP_CHANGE 2

int upd_write_cont_header (dk_session_t *ses);


/* repldb.c */
void ra_update_db (client_connection_t * cli);

void repl_init (void);

void repl_serv_init (int make_thr);

/* srvstat.c */

void da_string (db_activity_t * da, char * out, int len);
void srv_ip (char *ip_addr, size_t max_ip_addr, char *host);

/* recovery.c */
int db_check (query_instance_t * qi);
int db_backup (query_instance_t * qi, char * file);
void db_recover_key (int k_id, int n_id);

int repl_sync_server (char *server, char *account);

void dbg_print_box (caddr_t object, FILE * out);

void dbg_page_structure_error (buffer_desc_t *bd, db_buf_t ptr);

extern long  prof_on;
extern unsigned long  prof_compile_time;
extern unsigned long prof_n_compile;
extern unsigned long prof_n_reused;
void prof_exec (query_t * qr, char * text, long msecs, int flags);
#define PROF_EXEC 1
#define PROF_FETCH 2
#define PROF_ERROR 4



/* http.c */
void http_reaper (void);

int cli_check_ws_terminate (client_connection_t *cli);



#ifndef _REMOTE_STMT_T_
#define _REMOTE_STMT_T_
typedef struct _rstmtstruct remote_stmt_t;
#endif

void remote_init (void);

/* sqlprt.h */

#ifdef NO_CLI_DEBUG
#define dbg_cli_printf(a)
#else
#define dbg_cli_printf(a) dbg_printf (a)
#endif

/* srv_make_error */
#define ERR_STATE(err)  (((caddr_t*) err)[1])
#define ERR_MESSAGE(err)  (((caddr_t*) err)[2])

/* datesupp.c */
void dt_now (caddr_t dt);
void time_t_to_dt (time_t tim, long fraction, char *dt);
#if defined (WIN32) && (defined (_AMD64_) || defined (_FORCE_WIN32_FILE_TIME))
int file_mtime_to_dt (const char * name, char *dt);
#endif
void dt_date_round (char *dt);
void dt_to_tv (char *dt, char *tv);

/* sqltrig.c */
void tb_drop_trig_def (dbe_table_t * tb, char *name);
void trig_set_def (dbe_table_t * tb, query_t * nqr);
int tb_has_similar_trigger (dbe_table_t * tb, query_t * qr);
void trig_wrapper (caddr_t * qst, state_slot_t ** args, dbe_table_t * tb,
    int event, data_source_t * qn, qn_input_fn qn_run);
void trig_call (query_t * qr, caddr_t * qst, state_slot_t ** args,
		dbe_table_t *calling_tb, data_source_t * qn);
int tb_is_trig (dbe_table_t * tb, int event, caddr_t * col_names);
int tb_is_trig_at (dbe_table_t * tb, int event, int trig_time, caddr_t * col_names);

/* meta.c */
dbe_table_t *qi_name_to_table (query_instance_t * qi, const char *name);
void qi_read_table_schema (query_instance_t * qi, char *read_tb);
extern id_hash_t *global_collations;
long unbox_or_null (caddr_t box);
int sqt_fixed_length (sql_type_t * sqt);
void wi_free_schemas (void);
void wi_free_old_qrs (void);
int dtp_is_column_compatible (dtp_t dtp);
proc_name_t * proc_name (char * str);
void proc_name_free (proc_name_t * pn);
proc_name_t * proc_name_ref (proc_name_t * pn);


/* srvcr.c */
caddr_t box_conc (caddr_t, caddr_t);
caddr_t t_box_conc (caddr_t, caddr_t);
void sf_sql_extended_fetch (caddr_t stmt_id, long type, long irow, long n_rows,
			    long is_autocommit, caddr_t bookmark);
void stmt_set_scroll_co (srv_stmt_t * stmt, long co);

caddr_t srv_client_defaults (void);
void srv_client_defaults_init (void);

extern int32 cli_not_c_char_escape;
extern int32 cli_utf8_execs;
extern int32 cli_no_system_tables;
extern int32 cli_binary_timestamp;
extern long cli_encryption_on_password;
int current_of_node_scrollable (current_of_node_t * co, query_instance_t * qi, char * cr_name);
void cli_set_scroll_current_ofs (client_connection_t * cli, caddr_t * current_ofs);
void stmt_start_scroll (client_connection_t * cli, srv_stmt_t * stmt,
		   caddr_t ** params, char *cursor_name,
		   stmt_options_t * opts);
void stmt_scroll_close (srv_stmt_t * stmt);

/* security.c */
int sec_tb_check (dbe_table_t * tb, oid_t group, oid_t user, int op);
int sec_col_check (dbe_column_t * col, oid_t group, oid_t user, int op);

/* disk.c */
void buf_bsort (buffer_desc_t ** bs, int n_bufs, sort_key_func_t key);


#define QR_EXEC_CHECK_STACK(qi, addr, margin) \
  if (THR_IS_STACK_OVERFLOW (qi->qi_thread, addr, margin)) \
    return srv_make_new_error ("42000", "SR178", "Stack overflow (stack size is %ld, more than %ld is in use)", (long)(qi->qi_thread->thr_stack_size), (long)(qi->qi_thread->thr_stack_size - margin));


#ifdef DEBUG
extern void qi_check_stack (query_instance_t *qi, void *addr, ptrlong margin);
#define QI_CHECK_STACK(qi,addr,margin) qi_check_stack (qi, addr, margin)
#else
#define QI_CHECK_STACK(qi, addr, margin) \
  if (THR_IS_STACK_OVERFLOW (qi->qi_thread, addr, margin)) \
    sqlr_new_error ("42000", "SR178", "Stack overflow (stack size is %ld, more than %ld is in use)", (long)(qi->qi_thread->thr_stack_size), (long)(qi->qi_thread->thr_stack_size - margin)); \
  if (DK_MEM_RESERVE) \
    { \
      SET_DK_MEM_RESERVE_STATE(qi->qi_trx); \
      qi_signal_if_trx_error (qi); \
    }
#endif

#define DEL_STACK_MARGIN (2*PAGE_SZ + 200 * sizeof (caddr_t))
#define SPLIT_STACK_MARGIN (PAGE_SZ + 2000 * sizeof (caddr_t))
#define UPD_STACK_MARGIN (3*PAGE_SZ + SPLIT_STACK_MARGIN + 1000 * sizeof (caddr_t))
#define INS_STACK_MARGIN (SPLIT_STACK_MARGIN + PAGE_SZ + 1200 * sizeof (caddr_t))
#define CALL_STACK_MARGIN (AUTO_QI_DEFAULT_SZ + (3000 * sizeof (caddr_t)))
#define OL_BACKUP_STACK_MARGIN (4*PAGE_SZ + 1000 * sizeof (caddr_t))
#define AC_STACK_MARGIN (3000 * sizeof (caddr_t)) /* do not do autocompact if less */

/* row.c */


caddr_t row_set_col_cast (caddr_t data, sql_type_t *tsqt, caddr_t *err_ret,
    oid_t col_id, dbe_key_t *key, caddr_t *qst);

int key_insert (insert_node_t * ins, caddr_t * qst, it_cursor_t * it, ins_key_t * ik);

caddr_t box_bin_string (db_buf_t place, size_t len, dtp_t dtp);
caddr_t box_varchar_string (db_buf_t place, size_t len, dtp_t dtp);

/* equlcomp.c */
char * cd_strip_col_name (char *name);

/* sqlsrv.c */

caddr_t n_srv_make_new_error (const char *code, const char *virt_code, size_t buf_len, const char *msg, ...);
#define GET_EXCLUSIVE 1
#define GET_ANY 0

caddr_t  sf_make_new_log_name(dbe_storage_t * dbs);

dk_set_t srv_get_logons (void);

srv_stmt_t * cli_get_stmt_access (client_connection_t * cli, caddr_t id, int mode, caddr_t * err_ret);
caddr_t stmt_set_query (srv_stmt_t * stmt, client_connection_t * cli, caddr_t text,
		stmt_options_t * opts);
query_t * cli_cached_sql_compile (caddr_t query_text, client_connection_t *cli,
    caddr_t *err_ret, const char *stmt_id_name);


/* sqlrcomp.h */
void sprintf_more (char *text, size_t len, int *fill, const char *string,...);
void tailprintf(char *text, size_t len, int *fill, const char *string,...);

/* sqlexp.c */
caddr_t * proc_result_col_from_ssl (int inx, state_slot_t *ssl, long type, caddr_t pq, caddr_t po, caddr_t pn);

/*sqlintrp.h */
void lt_check_error (lock_trx_t * lt);
caddr_t subq_handle_reset (query_instance_t * qi, int reset);

#define QN_N_SETS(qn, inst) \
{\
  QNCAST (data_source_t, __qn, qn); \
  QNCAST (query_instance_t, __qi, inst); \
  if (__qn->src_prev) \
    __qi->qi_n_sets = QST_INT (inst, __qn->src_prev->src_out_fill); \
}

#define QI_IS_SET(qi, n) \
  (!qi->qi_set_mask || qi->qi_set_mask[(n) >> 3] & (1 << ((n) & 7)))


#define SET_MASK_SET(sm, n) \
  ((dtp_t*)sm)[(n) >> 3] |= 1 << ((n) & 7)

#define SET_LOOP \
{ \
  for (set = first_set; set < n_sets; set++) \
    { \
      if (set_mask && !(set_mask[set >> 3] & (1 << (set & 7))))	\
    continue; \
    qi->qi_set = set;

#define END_SET_LOOP \
  }}

#define SET_LOOP2 \
{ \
  for (set = first_set; set < n_sets; set++) \
    { \
      if (set_mask) \
	{ dtp_t b = set_mask[set >> 3]; \
	  if (!b) { set |= 7; continue;} \
	  if (!(b & (1 << (set & 7))))	\
	    continue; \
    }\
    qi->qi_set = set;



#define IS_SET_MASK(sm, inx) \
  (!(sm) || ((sm)[(inx) >> 3] & 1 << ((inx) & 7)))


/* neodisk.c */
void srv_global_lock (query_instance_t * qi, int flag);
#define SRVL_ATOMIC 1 /* faiils if all hosts are not contacted */
#define SRVL_CL_CONFIG 2 /* ignores unavailable hosts */
#define SRVL_CL_CONFIG_SRV 3 /* like cl config but can be made from proc invoked from daq, like resync server */
int srv_have_global_lock (du_thread_t *thr);
void srv_global_unlock (client_connection_t *cli, lock_trx_t *lt);


/* hash.c */
uint32 key_hash_box (caddr_t box, dtp_t dtp, uint32 code, int * var_len, collation_t * collation, dtp_t col_dtp, int allow_shorten_any);
caddr_t hash_cast (query_instance_t * qi, hash_area_t * ha, int inx, state_slot_t * ssl, caddr_t data);
hash_index_t * hi_allocate (unsigned int32 sz, int use_memcache, hash_area_t * ha);
int it_hi_done (index_tree_t * it);
index_tree_t * qst_tree (caddr_t * inst, state_slot_t * ssl, state_slot_t * set_no_ssl);
void qst_set_tree (caddr_t * inst, state_slot_t * ssl, state_slot_t * set_no_ssl, index_tree_t * tree);
void itc_from_it_ha (it_cursor_t * itc, index_tree_t * it, hash_area_t * ha);
void HI_BUCKET_PTR (hash_index_t *hi, uint32 code, it_cursor_t *itc, hash_inx_b_ptr_t *hibp, int mode);
int itc_ha_disk_find_new (it_cursor_t * itc, buffer_desc_t ** ret_buf, int * ret_pos,
		      hash_area_t * ha, caddr_t * qst, uint32 code, dp_addr_t he_page, short he_pos);

state_slot_t * ssl_single_state_shadow (state_slot_t * ssl, state_slot_t * tmp_ssl);

void setp_order_row (setp_node_t * setp, caddr_t * qst);
void setp_group_row (setp_node_t * setp, caddr_t * qst);
#define HASH_NUM_SAFE(n) n = n & 0x7fffffff
#define MAX_STACK_N_KEYS 200


typedef struct itc_ha_feed_ret_s {
  hash_index_t *ihfr_hi;
  int ihfr_memcached;
  buffer_desc_t *ihfr_disk_buf;
  int ihfr_disk_pos;
  caddr_t *ihfr_hmk_data;
  caddr_t *ihfr_deps;
} itc_ha_feed_ret_t;

int itc_ha_feed (itc_ha_feed_ret_t *ret, hash_area_t * ha, caddr_t * qst, unsigned long feed_temp_blobs);
extern void itc_ha_flush_memcache (hash_area_t * ha, caddr_t * qst, int is_in_fill);

/* is in fill */
#define SETP_HASH_FILL 1
#define SETP_NO_CHASH_FLUSH 2

boxint num_check_prec (boxint val, int prec, char *title, caddr_t *err_ret);
const char *dv_type_title (int type);

/* sqlbif.c */
void connection_set (client_connection_t *cli, caddr_t name, caddr_t val);
void sprintf_escaped_table_name (char *out, char *name);
void sprintf_escaped_str_literal (caddr_t str, char *out, dk_session_t *ses);
extern caddr_t get_keyword_int (caddr_t * arr, char * item, const char * me);
extern caddr_t get_keyword_ucase_int (caddr_t * arr, const char * item, caddr_t dflt);
extern char *find_repl_account_in_src_text (char **src_text_ptr);
caddr_t bif_commit (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);


#define IO_SECT(qi) \
{ \
 int64 __ts = rdtsc (); \
  query_instance_t * _qi2 = (query_instance_t *) qi; \
  vdb_enter (_qi2); \
  QR_RESET_CTX_T (_qi2->qi_thread)  \
    {  \


#define END_IO_SECT(err_ret) \
      vdb_leave_1 (_qi2, err_ret); \
      _qi2->qi_client->cli_activity.da_thread_time -= rdtsc () - __ts; \
    } \
  QR_RESET_CODE  \
    { \
      caddr_t _err_1 = NULL, _err_2 = NULL; \
      _qi2->qi_client->cli_activity.da_thread_time -= rdtsc () - __ts; \
      POP_QR_RESET; \
      vdb_leave_1 (_qi2, &_err_1); \
      _err_2 = subq_handle_reset (_qi2, reset_code); \
      if (_err_1 && _err_2) \
       	{ \
	  dk_free_tree (_err_1); \
          _err_1 = _err_2; \
	} \
      else if (_err_2) \
	_err_1 = _err_2; \
      if (_err_1) \
	{ \
	  if (err_ret) \
	    *err_ret = _err_1; \
	  else \
	    sqlr_resignal (_err_1); \
	} \
    } \
  END_QR_RESET; \
}

void db_replay_registry_setting (caddr_t ent, caddr_t *err_ret);
dk_session_t * dbs_read_registry (dbe_storage_t * dbs, client_connection_t * cli);

boxint safe_atoi (const char *data, caddr_t *err_ret);
double safe_atof (const char *data, caddr_t *err_ret);
caddr_t box_to_any (caddr_t data, caddr_t * err_ret);
caddr_t box_to_any_1 (caddr_t data, caddr_t * err_ret, auto_pool_t *ap, int ser_flags);
caddr_t mp_box_to_any_1 (caddr_t data, caddr_t * err_ret, mem_pool_t *ap, int ser_flags);
#define DKS_TO_OBY_KEY 2 /*!< flag to indicate that an rdf box with text should be stored with the text, not just id */
#define DKS_TO_HA_DISK_ROW 4 /*!< flag to indicate that the destination is a temp table with no sorting and box_to_any_1 serialization in a column */
#define DKS_TO_DC 8
#define DKS_REPLICATION 16

caddr_t box_to_shorten_any (caddr_t data, caddr_t * err_ret);
char* __get_column_name (oid_t col_id, dbe_key_t *key);
void pl_bif_name_define (const char *name);
caddr_t find_pl_bif_name (caddr_t name);

/* sqltype.c */
void udt_can_write_to (sql_type_t *sqt, caddr_t data, caddr_t *err_ret);

/* interconnection communication */

#define ICCL_IS_LOCAL	0x01
#define ICCL_WAIT 2

typedef struct icc_lock_s
{
  caddr_t		iccl_name;
  client_connection_t *	iccl_cli;
  query_instance_t *	iccl_qi;
  int			iccl_waits_for_commit;
  /* Semaphore is used here instead of mutex in order to bypass
     assertion checking when MTX_DEBUG is on.  */
  /* dk_mutex_t *	iccl_mutex; */
  semaphore_t *		iccl_sem;

} icc_lock_t;

extern id_hash_t *icc_locks;
extern dk_mutex_t *icc_locks_mutex;

extern icc_lock_t *icc_lock_alloc (caddr_t name, client_connection_t * cli, query_instance_t * qi);
#define icc_lock_free(lock) dk_free ((lock), sizeof (icc_lock_t))

extern icc_lock_t *icc_lock_from_hashtable (caddr_t name);
extern int icc_lock_release (caddr_t name, client_connection_t *cli);

#ifdef WIN32
#define CHANGE_THREAD_USER(x) if(x) change_thread_user(x);
#else
#define CHANGE_THREAD_USER(x) ;
#endif

#ifdef WIN32
int check_os_user (caddr_t u_sys_name, caddr_t u_sys_pwd);
#endif

typedef enum { MPU_MODULE, MPU_PROC, MPU_UDT } mpu_name_type_t;
void sqlc_check_mpu_name (caddr_t name, mpu_name_type_t type);

caddr_t sqlc_rls_get_condition_string (dbe_table_t *tb, int op, caddr_t *err);
int ddl_dv_default_prec (dtp_t dtp);
dk_set_t upd_hi_pre (update_node_t * upd, query_instance_t * qi);
extern id_hash_t *global_collations;
extern dk_set_t all_trxs;
extern dk_mutex_t * recomp_mtx;
extern buffer_desc_t *cp_buf;
int sqlc_set_brk (query_t *qr, long line1, int what, caddr_t * inst);
extern int in_log_replay;

extern int hash_join_enable;

void list_wired_buffers (char *file, int line, char *format, ...);
extern dk_mutex_t * parse_mtx;
extern du_thread_t * parse_mtx_owner;

#define IN_PARSE { mutex_enter (parse_mtx); parse_mtx_owner = THREAD_CURRENT_THREAD; }
#define LEAVE_PARSE { parse_mtx_owner = NULL; mutex_leave (parse_mtx); }

extern void set_ini_trace_option (void);

extern volatile int db_exists; /* from disk.c */

extern int bif_tidy_init(void);

int count_exceed (query_instance_t * qi, const char *name, long cnt, const char *idx);
void ddl_type_to_sqt (sql_type_t * sqt, caddr_t * type);

const char *ssl_type_to_name (char ssl_type);

extern void bpel_init (void);

extern caddr_t file_stat (const char *fname, int what);

void itc_delete_blobs (it_cursor_t * itc, buffer_desc_t * buf);

int qr_proc_repl_check_valid (query_t *qr, caddr_t *err);

#define STRSES_CAN_BE_STRING(ses) \
	(strses_length ((dk_session_t *) (ses)) <= 16000000)

#define STRSES_LENGTH_ERROR(place) \
    srv_make_new_error ("22023", "HT057", \
		"The STRING session in %s is longer than 10Mb. " \
		"Either use substring to access it in parts or place less data in it.", (place))

void ddl_commit_trx (query_instance_t *qi);

/* bitmap.c */

extern unsigned char byte_logcount[256];
void bm_ends (bitno_t bm_start, db_buf_t bm, int bm_len, bitno_t * start, bitno_t * end);
void key_bm_insert (it_cursor_t * itc, row_delta_t * rd);
void itc_bm_insert_single (it_cursor_t * itc, buffer_desc_t * buf, row_delta_t * rd, int prev_rc);
void key_make_bm_specs (dbe_key_t * key);
void itc_bm_insert_in_row (it_cursor_t * itc, buffer_desc_t * buf, row_delta_t * rd);
int itc_bm_row_check (it_cursor_t * itc, buffer_desc_t * buf);
int itc_bm_vec_row_check (it_cursor_t * itc, buffer_desc_t * buf);
void itc_bm_land (it_cursor_t * itc, buffer_desc_t * buf);
void itc_next_bit (it_cursor_t * itc, buffer_desc_t *buf);
void itc_invalidate_bm_crs (it_cursor_t * itc, buffer_desc_t * buf, int is_transit, dk_set_t * local_transits);
/*! This splits an IRI as it is stored in RDF "prefix" and "local" tables. */
extern int iri_split (char * iri, caddr_t * pref, caddr_t * name);
/*! This splits an IRI to "prefix" and "local" parts, making "local" as short as it is allowed by TURTLE syntax. */
extern void iri_split_ttl_qname (const char * iri, caddr_t * pref, caddr_t * name, int abbreviate_nodeid);
int64  unbox_iri_int64 (caddr_t x);
int itc_bm_land_lock (it_cursor_t * itc, buffer_desc_t ** buf_ret);
void itc_init_bm_search (it_cursor_t * itc);
extern void bm_init (void);
int itc_bm_delete (it_cursor_t * itc, buffer_desc_t ** buf_ret);
#define BM_DEL_DONE 1
#define BM_DEL_ROW 2
caddr_t box_iri_int64 (int64 n, dtp_t dtp);
int itc_bm_count (it_cursor_t * itc, buffer_desc_t * buf);
void itc_bm_ends (it_cursor_t * itc, buffer_desc_t * buf, bitno_t * start, bitno_t * end, int * is_single);
int pl_next_bit (placeholder_t * itc, db_buf_t bm, short bm_len, bitno_t bm_start, int is_desc);
void pl_set_at_bit (placeholder_t * pl, db_buf_t bm, short bm_len, bitno_t bm_start, bitno_t value, int is_desc);
int bits_count (db_buf_t bits, int n_int32, int count_max);


/* sqlcost.h */
int sample_search_param_cast (it_cursor_t * itc, search_spec_t * sp, caddr_t data);

void ri_outer_output (rdf_inf_pre_node_t * ri, state_slot_t * any_flag, caddr_t * inst);
void rdf_inf_pre_input (rdf_inf_pre_node_t * ri, caddr_t * inst, 		   caddr_t * volatile state);
void trans_node_input (trans_node_t * tn, caddr_t * inst, caddr_t * state);
void tn_qn_init (data_source_t * qn, caddr_t * inst);

void query_frag_input (query_frag_t * qf, caddr_t * inst, caddr_t * state);
void query_frag_free (query_frag_t * qf);
void  code_node_input (code_node_t * cn, caddr_t * inst, caddr_t * state);
void cn_free (code_node_t * cn);

void trset_printf (const char *str, ...);
void rdf_core_init (void);
void sparql_init (void);

query_instance_t * qi_top_qi (query_instance_t * qi);
void fun_ref_set_defaults_and_counts (fun_ref_node_t *fref, caddr_t * inst);
caddr_t * qi_alloc (query_t * qr, stmt_options_t * opts, caddr_t * auto_qi,
		    int auto_qi_len, int n_sets);

data_source_t * qn_next (data_source_t * qn);
data_source_t * qn_last (data_source_t * qn);
void sqlo_tc_init ();
void sqlo_timeout_text_count ();

void xte_set_qi (caddr_t xte, query_instance_t * qi);
caddr_t
xml_deserialize_packed (caddr_t * qst, caddr_t strg);

#if 0
#define at_printf(a) printf a
#else
#define at_printf(a) {if (enable_at_print) printf a;}
extern int enable_at_print;
#endif

/* sqlcost.h */
int sample_search_param_cast (it_cursor_t * itc, search_spec_t * sp, caddr_t data);

void ri_outer_output (rdf_inf_pre_node_t * ri, state_slot_t * any_flag, caddr_t * inst);

void rdf_core_init (void);
void sparql_init (void);

int box_position (caddr_t * box, caddr_t elt);
int box_position_no_tag (caddr_t * box, caddr_t elt);

void cl_fref_read_input (cl_fref_read_node_t * clf, caddr_t * inst, caddr_t * state);
void clf_free (cl_fref_read_node_t * clf);
void  ssa_iter_input (ssa_iter_node_t * ssi, caddr_t * inst, caddr_t * state);
void ssi_free (ssa_iter_node_t * ssi);


caddr_t box_append_1 (caddr_t box, caddr_t elt);

query_t * sch_ua_func_ua (caddr_t name);

caddr_t box_n_chars (dtp_t * bin, int len);
caddr_t sys_dirlist (caddr_t fname, int files);


#ifdef MTX_DEBUG
void itc_assert_no_reg (it_cursor_t * itc);
#else
#define itc_assert_no_reg(itc)
#endif

/* vectored exec */
void qn_result (data_source_t * qn, caddr_t * inst, int set_no);
void ssl_result (state_slot_t * ssl, caddr_t * inst, int set_no);
void itc_pop_last_out (it_cursor_t * itc, caddr_t * inst, v_out_map_t * om, buffer_desc_t * buf);
void qi_vec_init (query_instance_t * qi, int n_sets);
void itc_vec_new_results (it_cursor_t * itc);
void ks_vec_new_results (key_source_t * ks, caddr_t * inst, it_cursor_t * itc);
int qi_free_cb (caddr_t qi);
caddr_t qi_copy_cb (caddr_t);
int ts_handle_aq (table_source_t * ts, caddr_t * inst, buffer_desc_t ** order_buf_ret, int * order_buf_preset);
void ts_aq_handle_end (table_source_t * ts, caddr_t * inst);
void ts_aq_final (table_source_t * ts, caddr_t * inst, it_cursor_t * itc);
void ts_check_batch_sz (table_source_t * ts, caddr_t * inst, it_cursor_t * itc);
buffer_desc_t * ts_split_range (table_source_t * ts, caddr_t * inst, it_cursor_t * itc, int n_parts);
buffer_desc_t * ts_initial_itc (table_source_t * ts, caddr_t * inst, it_cursor_t * itc);
extern dk_mutex_t * qi_ref_mtx;
void vec_fref_result (fun_ref_node_t * fref, caddr_t * inst, int n_sets);
int fref_setp_flush (fun_ref_node_t * fref, caddr_t * inst);
int itc_vec_split_search (it_cursor_t * itc, buffer_desc_t ** buf_ret, int at_or_above, dp_addr_t * leaf_ret);

void ssl_cast (data_source_t * qn, caddr_t * inst, state_slot_t * res, state_slot_ref_t * source, dc_cast_t cf, caddr_t * err_ret);
int key_vec_insert (insert_node_t * ins, caddr_t * qst, it_cursor_t * itc, ins_key_t * ik);
void itc_make_param_order (it_cursor_t * itc, query_instance_t * qi, int n_sets);
void code_vec_run_v (code_vec_t code_vec, caddr_t * qst, int offset, int run_until, int n_sets, data_col_t * ret_dc, int * bool_ret, ssl_index_t bool_ret_fill);
void ssl_set_dc_type (state_slot_t * ssl);
void qst_vec_set (caddr_t * inst, state_slot_t * ssl, caddr_t v);
void qst_vec_set_copy (caddr_t * inst, state_slot_t * ssl, caddr_t v);
void select_node_input_vec (select_node_t * sel, caddr_t * inst, caddr_t * state);
void select_node_input_subq_vec (select_node_t * sel, caddr_t * inst, caddr_t * state);
void set_ctr_vec_input (set_ctr_node_t * sctr, caddr_t * inst, caddr_t * state);
void ins_vec_exists (instruction_t * ins, caddr_t * inst, db_buf_t next_mask, int * n_true, int * n_false);
void ins_vec_subq (instruction_t * ins, caddr_t * inst);
int * qn_extend_sets (data_source_t * qn, caddr_t * inst, int n);
#define QN_CHECK_SETS(qn, inst, n) \
  if (box_length (QST_BOX (caddr_t, inst, ((data_source_t*)qn)->src_sets)) < n * sizeof (int)) \
    qn_extend_sets ((data_source_t*)qn, inst, n);
int key_cmp_boxes (caddr_t box1, caddr_t box2, sql_type_t * sqt);
void vec_dtp_init ();
int itc_vec_sp_copy (it_cursor_t * itc, int inx, int64 new_v, int set);
void subq_node_vec_input (subq_source_t * sqs, caddr_t * inst, caddr_t * state);
void outer_seq_end_vec_input (outer_seq_end_node_t * ose, caddr_t * inst, caddr_t * state);



/* column store */
void itc_col_init  (it_cursor_t * itc);
col_data_ref_t * itc_new_cr (it_cursor_t * itc);
void itc_col_free (it_cursor_t * itc);
void pg_make_col_map (buffer_desc_t * buf);
void itc_col_leave (it_cursor_t * itc, int flags);
#define ITC_NO_CEIC_CLEAR 1
void itc_fetch_col (it_cursor_t * itc, buffer_desc_t * buf, dbe_col_loc_t * cl, int from_row, ptrlong to_row);
#define FC_APPEND -1
#define FC_APPEND_PRESENT -2
#define FC_FROM_CEIC -3 /* the ceic contains updates to the page for itc_fetch_col.  If a col is updated in the ceic, use that instead of the value on the page. */
void itc_col_search (it_cursor_t * itc, buffer_desc_t * buf);
void key_col_insert (it_cursor_t * itc, row_delta_t * rd, insert_node_t * ins);
int ce_col_cmp (db_buf_t any, int64 offset, dtp_t ce_flags, dbe_col_loc_t * cl, caddr_t value);
int itc_col_row_check (it_cursor_t * itc, buffer_desc_t ** buf_ret, dp_addr_t * leaf_ret);
int itc_col_row_check_dummy (it_cursor_t * itc, buffer_desc_t * buf);
#ifdef MALLOC_DEBUG
caddr_t DBG_NAME (itc_alloc_box) (DBG_PARAMS it_cursor_t * itc, int len, dtp_t dtp);
#define itc_alloc_box(itc, len, dtp) dbg_itc_alloc_box (__FILE__, __LINE__, (itc), (len), (dtp))
#else
caddr_t itc_alloc_box (it_cursor_t * itc, int len, dtp_t dtp);
#endif

#define itc_free_box(itc, b) \
  {if ((uptrlong)itc->itc_temp > (uptrlong)b || (uptrlong)itc->itc_temp + itc->itc_temp_max < (uptrlong)b) dk_free_box ((caddr_t)b);}

int pm_n_rows (page_map_t * pm, int first_ce);
void key_vec_col_insert (it_cursor_t * itc, row_delta_t * rd);
void rd_left_col_refs (page_fill_t * pf, row_delta_t * rd);
void pf_col_right_edge (page_fill_t * pf, row_delta_t * rd);
void itc_col_vec_insert (it_cursor_t * itc, insert_node_t * ins);
void delete_node_vec_run (delete_node_t * del, caddr_t * inst, caddr_t * state, int in_update);
void update_node_vec_run (update_node_t * upd, caddr_t * inst, caddr_t * state);

void dc_digit_sort (data_col_t ** dcs, int n_dcs, int * sets, int n_sets);
void sslr_n_consec_ref (caddr_t * inst, state_slot_ref_t * sslr, int * sets, int set, int n_sets);
void dc_reset_array (caddr_t * inst, data_source_t * qn, state_slot_t ** ssls, int new_sz);

void chash_init ();
int setp_chash_group (setp_node_t * setp, caddr_t * inst);
int setp_chash_distinct (setp_node_t * setp, caddr_t * inst);
void chash_to_memcache (caddr_t * inst, index_tree_t * it, hash_area_t * ha);
int ce_int_chash_check (col_pos_t * cpo, db_buf_t val, dtp_t flags, int64 offset, int rl);
void setp_chash_fill (setp_node_t * setp, caddr_t * inst);
void hash_source_chash_input (hash_source_t * hs, caddr_t * inst, caddr_t * state);
void cha_free (chash_t * cha);
int itc_hash_compare (it_cursor_t * itc, buffer_desc_t * buf, search_spec_t * sp);
int ks_add_hash_spec (key_source_t * ks, caddr_t * inst, it_cursor_t * itc);
int fref_hash_partitions_left (fun_ref_node_t * fref, caddr_t * inst);
int fref_hash_is_first_partition (fun_ref_node_t * fref, caddr_t * inst);

extern int enable_chash_join;
extern int enable_chash_gb;
extern int64 chash_min_parallel_fill_rows;
void chash_fill_input (fun_ref_node_t * fref, caddr_t * inst, caddr_t * state);
void cl_fref_resume (fun_ref_node_t * fref, caddr_t * inst);
void chash_read_input (table_source_t * ts, caddr_t * inst, caddr_t * state);
void memcache_read_input (table_source_t * ts, caddr_t * inst, caddr_t * state);
void fun_ref_streaming_input (fun_ref_node_t * fref, caddr_t * inst, caddr_t * state);
void chash_merge (setp_node_t * setp, chash_t * cha, chash_t * delta, int n_to_go);
dtp_t cha_dtp (dtp_t dtp, int is_key);
caddr_t * chash_reader_current_branch (table_source_t * ts, caddr_t * inst, int is_next);
int64  cha_bytes_est (hash_area_t * ha, int64 * card_ret);
extern int64 chash_space_avail;
index_tree_t * qst_get_chash (caddr_t * inst, state_slot_t * ssl, state_slot_t * id_ssl, setp_node_t * setp);
void cha_part_from_ssl (caddr_t * inst, state_slot_t * ssl, int min, int max);
search_spec_t * sp_copy (search_spec_t * sp);
search_spec_t * sp_list_copy (search_spec_t * sp);
void qi_assign_root_id (query_instance_t * qi);
void qi_root_done (query_instance_t * qi);
int qi_inc_branch_count (query_instance_t * qi, int max, int n);

#define BIT_IS_SET(b,i) (((db_buf_t)(b))[(i) / 8] & (1 << ((i) & 0x7)))
#define BIT_SET(b, i) ((db_buf_t)(b))[(i) / 8] |= 1 << ((i) & 0x7);
#define BIT_CLR(b, i) ((db_buf_t)(b))[(i) / 8] &= ~(1 << ((i) & 0x7));

void ssl_insert_cast (insert_node_t * ins, caddr_t * inst, int nth_col, caddr_t * err_ret, row_delta_t * rd, int from_row, int to_row, int no_blobs);
void ssl_consec_results (state_slot_t * ssl, caddr_t * inst, int n_sets);
caddr_t * itc_bm_array (it_cursor_t * itc, buffer_desc_t * buf);
void da_add (db_activity_t * a1, db_activity_t * a2);
void da_sub (db_activity_t * a1, db_activity_t * a2);
void da_copy (db_activity_t * to, db_activity_t * from);
void da_clear (db_activity_t * da);
int itc_vec_digit_sort (it_cursor_t * itc);
int sctr_hash_range_check (caddr_t * inst, search_spec_t * sp);

#define TB_IS_RQ(tb) (tb && 0 == stricmp (tb->tb_name_only, "RDF_QUAD"))

db_buf_t sel_extend_bits (select_node_t * sel, caddr_t * inst, int row_no, int * bits_max);
uint32 cp_any_hash (col_partition_t * cp, db_buf_t val, int32 * rem_ret);


#define SRC_N_IN(src, inst, n)  {if (src->src_stat)  SRC_STAT (src, inst)->srs_n_in += n;}


#define SRC_STOP_TIME(src, inst) \
{ \
  src_stat_t * srs = SRC_STAT (src, inst); \
  if (srs->srs_start) { srs->srs_cum_time += now - srs->srs_start; srs->srs_start = 0;} \
}


#define SRC_ENTER(src, inst) \
{ \
  if (src->src_stat) \
    { \
      uint64 now = rdtsc(); \
      if (src->src_prev && src->src_prev->src_stat) \
	SRC_STOP_TIME (src->src_prev, inst); \
      SRC_STAT (src, inst)->srs_start = now; \
    } \
}

#define SRC_RESUME(src, inst) \
{ \
  if (src->src_stat) \
    { \
      uint64 now = rdtsc(); \
      SRC_STAT (src, inst)->srs_start = now; \
    } \
}


#define SRC_START_TIME(src, inst) \
  if (((data_source_t*)src)->src_stat) SRC_STAT(src, inst)->srs_start = rdtsc ();

#define SRC_RETURN(src, inst)  \
{ \
  if (src->src_stat) \
    { \
      uint64 now = rdtsc(); \
      SRC_STOP_TIME (src, inst); \
    } \
}

#define SRC_RESULT(src, inst) \
{ \
  if (src->src_stat) \
    { \
      src_stat_t * srs = SRC_STAT (src, inst); \
      unsigned int64 now = rdtsc (); \
      SRC_STOP_TIME (src, inst); \
      srs->srs_n_out += QST_INT (inst, src->src_out_fill); \
    } \
}

void ts_split_input (ts_split_node_t * tssp, caddr_t * inst, caddr_t * state);
void ts_always_null (table_source_t * ts, caddr_t * inst);
void qi_qn_stat (query_instance_t * qi);
void sqs_out_sets (subq_source_t * sqs, caddr_t * inst);
int key_col_layout_pos (dbe_key_t * key, oid_t col_id);

#define SET_MASK_CLEAR(sm, n) \
  memset (sm, 0, ALIGN_8 (n) / 8)

#define NEXT_MASK(ms, qst, inx) \
{ \
  ms = QST_BOX (dtp_t*, qst, inx); \
  if (ms && box_length ((caddr_t)ms) < ALIGN_8 (qi->qi_n_sets) / 8) ms = NULL; \
  if (!ms) \
    ms = (dtp_t*) (qst[inx] = mp_alloc_box_ni (qi->qi_mp, ALIGN_8 (MAX (n_sets, dc_batch_sz)) / 8, DV_BIN)); \
}

query_t * log_key_ins_del_qr (dbe_key_t * key, caddr_t * err_ret, int op, int ins_mode, int is_rfwd);
int  fnr_max_set_no (fun_ref_node_t * fref, caddr_t * inst, state_slot_t ** ssl_ret);
void ins_vec_agg (instruction_t * ins, caddr_t * inst);
sort_cmp_func_t  itc_param_cmp_func (it_cursor_t * itc);
void upd_col_pk (update_node_t * upd, caddr_t * inst);
caddr_t cl_vec_exec (query_t * qr, client_connection_t * cli, mem_pool_t * mp, caddr_t * params, slice_id_t * slices, slice_id_t slid, db_buf_t * set_mask_ret, data_col_t ** dc_ret, int set_no_in_params);
void sqlg_ks_col_alter  (key_source_t * ks);
int sqlg_fref_n_grouping_sets (fun_ref_node_t * fref);
setp_node_t * sqlg_qf_nth_setp (query_frag_t * qf, int nth);

#define CAR(dt,x)	(x ? ((dt) ((x)->data)) : 0)
#define CDR(x)		(x ? (x)->next : NULL)
#define CONS(car,cdr)	dk_set_cons ((caddr_t) car, (dk_set_t) cdr)
#define t_CONS(car,cdr)	t_cons ((caddr_t) car, (dk_set_t) cdr)
#define NCONC(x,y)	dk_set_conc ((dk_set_t) x, (dk_set_t) y)
#define t_NCONC(x,y)	dk_set_conc ((dk_set_t) x, (dk_set_t) y)
#define NCONCF1(l, n)	(l = NCONC (l, CONS (n, NULL)))

void qst_set_hash_part (caddr_t * copy, caddr_t * org, query_t * qr);

void vec_fref_single_result (fun_ref_node_t * fref, table_source_t * ts, caddr_t * inst, int n_sets);
void vec_fref_group_result (fun_ref_node_t * fref, table_source_t * ts, caddr_t * inst, int n_sets);
void qi_branch_stats (query_instance_t * qi, query_instance_t * branch, query_t * qr);
void  qi_da_stat (query_instance_t * qi, db_activity_t * da, int is_final);
void qi_log_stats (query_instance_t * qi, caddr_t err);

#define CLI_THREAD_TIME(cli) \
  {uint64 rt = rdtsc (); cli->cli_run_clocks += rt - cli->cli_cl_start_ts; cli->cli_activity.da_thread_time += rt - cli->cli_cl_start_ts; cli->cli_cl_start_ts = rt; }

void cli_set_start_times (client_connection_t * cli);

caddr_t * itc_bm_array (it_cursor_t * itc, buffer_desc_t * buf);
extern int32 log_proc_overwrite;

#ifdef MALLOC_DEBUG
#define TMP_ARRAY_INIT_SZ 2
#else
#define TMP_ARRAY_INIT_SZ 20
#endif

#define TMP_ARRAY(dtp, a, f) \
  dtp a##_pre[TMP_ARRAY_INIT_SZ]; dtp *a = &a##_pre[0]; int f = 0;

#define TMP_ARRAY_DEF(dtp, a, f) \
  dtp a##_pre[TMP_ARRAY_INIT_SZ]

#define TMP_ARRAY_INIT(dtp, a, f) \
  dtp *a = &a##_pre[0]; int f = 0

#define TMP_ARRAY_ADD(dtp, a, f, elt)  \
  { if (&a##_pre[0] == a) { a[f++] = elt; if (f >= TMP_ARRAY_INIT_SZ) a = (dtp*)box_n_chars ((unsigned char*)a##_pre, sizeof (a##_pre));} else array_add ((caddr_t**)&a,&f, (caddr_t)elt);}

#define TMP_ARRAY_DONE(a) if (&a##_pre[0] != a) dk_free_box ((caddr_t)a);

void qi_add_cl_stat  (query_instance_t * qi, int64 * stat, int fill);
void qi_qp_anytime (caddr_t * inst, query_t * qr);
void ssl_consec_results (state_slot_t * ssl, caddr_t * inst, int n_sets);

extern int enable_rec_qf;
extern int32 enable_mt_txn;
extern int enable_trans_colocate;

int64 dv_rdf_ro_id (db_buf_t dv2);
int dv_rdf_id_delta (int64 ro_id_1, int64 ro_id_2, int64 *delta_ret);

blob_handle_t * cli_ready_dae (client_connection_t  * cli, blob_handle_t * bh);
void cli_free_dae (client_connection_t * cli);
void qi_set_batch_sz (caddr_t * inst, table_source_t * ts, int new_sz);
void dk_hash_copy (dk_hash_t * to, dk_hash_t * from);
state_slot_t * upd_find_col_ssl (update_node_t * upd, oid_t col_id);
void complete_proc_name (char * proc_name, char * complete, char * def_qual, char * def_owner);



#define LC_INIT 0
#define LC_ROW 1
#define LC_AT_END 2
#define LC_ERROR 3

srv_stmt_t * qr_multistate_lc (query_t * qr, query_instance_t * caller, int n_sets);
int lc_exec (srv_stmt_t * lc, caddr_t * row, caddr_t last, int is_exec);
void lc_reuse (srv_stmt_t * sst);
caddr_t * lc_t_row (srv_stmt_t * lc);

int cfg2_getlong (PCONFIG pconfig,  char * sect, char * item, int32 * ret);
int cfg2_getstring (PCONFIG pconfig,  char * sect, char * item, char ** ret);

uint64 qi_total_mem (query_instance_t * qi);

int tb_is_rdf_quad (dbe_table_t * tb);
void qn_vec_reuse (data_source_t * qn, caddr_t * inst);
extern int32 enable_vec_reuse;

#define B_NEW_VARZ(t, v) NEW_VARZ(t, v)

#endif /* _SQLFN_H */
