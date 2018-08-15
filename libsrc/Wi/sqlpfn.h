/*
 *  sqlpfn.h
 *
 *  $Id$
 *
 *  SQL Parser Utility Functions
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

#ifndef _SQLPFN_H
#define _SQLPFN_H

caddr_t sym_string (const char * string);
caddr_t t_sym_string (const char * string);

caddr_t not_impl (char * text);

int ammsc_to_code (char * op);

caddr_t list (long n, ...);
void list_extend (caddr_t *list_ptr, long n, ...);
void list_nappend (caddr_t *list_ptr, caddr_t cont);
caddr_t sc_list (long n, ...);

caddr_t strliteral (char * s);
caddr_t t_strliteral (char * s);

caddr_t wideliteral (char * s);


caddr_t sym_conc (caddr_t x, caddr_t y);


#define YY_INPUT(buf, res, max) \
  res = yy_string_input (buf, max);

int yy_string_input (char * buf, int max);

void yy_string_input_init (char * text);

ST ** asg_val_list (ST ** asg_list);

ST ** asg_col_list (ST ** asg_list);

ST ** sqlp_local_variable_decls (caddr_t * names, ST * dtp);

caddr_t DBG_NAME (sqlp_box_id_upcase) (DBG_PARAMS const char *str);
#ifdef MALLOC_DEBUG
#define sqlp_box_id_upcase(s) dbg_sqlp_box_id_upcase (__FILE__, __LINE__, s)
#endif
caddr_t t_sqlp_box_id_upcase (const char * str);
caddr_t t_sqlp_box_id_upcase_nchars (const char * str, int len);
caddr_t sqlp_box_upcase (const char * str);
caddr_t t_sqlp_box_upcase (const char * str);

caddr_t t_sqlp_box_id_quoted (const char * str, int end_ofs);

void sqlp_set_qualifier (caddr_t * q, caddr_t o);

caddr_t c_pref (char *q, size_t max_q, char *o, size_t max_o, char *n);

caddr_t qqlp_table_name (caddr_t q, caddr_t o, caddr_t n);

caddr_t qqlp_new_table_name (caddr_t q, caddr_t o, caddr_t n);

#ifdef DEBUG
int save_str (char * yytxt);
#else
#define save_str(x)
#endif

dk_set_t sqlc_ensure_primary_key (dk_set_t elements);

caddr_t sqlp_proc_name (char *q, size_t max_q, char *o, size_t max_o, char *mn, char *fn);

caddr_t sqlp_table_name (char *q, size_t max_q, char *o, size_t max_o, char *n, int do_case);
caddr_t sqlp_type_name (char *q, size_t max_q, char *o, size_t max_o, char *n, int add_if_not);
caddr_t sqlp_function_name (char *q, char *o, char *n);

caddr_t sqlp_new_table_name (char *q, size_t max_q, char *o, size_t max_o, char *n);
caddr_t sqlp_new_qualifier_name (char *q, size_t max_q);


ST ** asg_col_list (ST ** asg_list);

ST ** asg_val_list (ST ** asg_list);

ST * sqlp_view_def (ST ** names, ST * exp, int generate_col_names);

ST ** sqlp_stars (ST ** selection, ST ** from);

dk_set_t sqlp_process_col_options (caddr_t table_name, dk_set_t table_opts);

typedef struct
  {
    int natural;
    long type;
  } sqlp_join_t;


ST *sqlp_numeric (caddr_t prec, caddr_t scale);

caddr_t sqlp_known_function_name (caddr_t name);
ST *sqlp_make_user_aggregate_fun_ref (caddr_t function_name, ST **arglist, int allow_yyerror);
void sqlp_complete_fun_ref (ST * tree);

void sqlp_in_view (char * view);
void sqlp_no_table (char *pref, char *name);

caddr_t sqlp_view_u_id (void);
caddr_t sqlp_view_g_id (void);


caddr_t sqlp_html_string (void);

ST * sqlp_for_statement (ST * sel, ST * body);
ST * sqlp_c_for_statement (ST **init, ST *cond, ST **inc, ST * body);
ST * sqlp_foreach_statement (ST *data_type, caddr_t var, ST *arr, ST *body);
ST * sqlp_add_top_1 (ST *select_stmt);
long sqlp_handler_star_pos (caddr_t name);
ST * sqlp_resignal (ST *state);

ST * sqlp_embedded_xpath (caddr_t str);

ST * sqlp_union_tree_select (ST * tree);
ST * sqlp_union_tree_right (ST * tree);


caddr_t sqlc_convert_odbc_to_sql_type (caddr_t id);
/* ST * sqlc_embedded_xpath (sql_comp_t * sc, char * str, caddr_t * err_ret); */

caddr_t * sqlp_string_col_list (caddr_t * lst);

caddr_t sqlp_xml_col_name (ST * tree);
extern int sqlp_xml_col_directive (char *id);
long sqlp_xml_select_flags (char * mode, char * elt);
ptrlong sqlp_bunion_flag (ST * l, ST * r, long f);
ST *sqlp_wpar_nonselect (ST *subq);
ST * sqlp_inline_order_by (ST *tree, ST **oby);
/*! Tweaks special calls and replaces calls of pure functions on costants with results of that functions */
ST * sqlp_patch_call_if_special_or_optimizable (ST * funcall_tree);
ptrlong sqlp_cursor_name_to_type (caddr_t name);
ptrlong sqlp_fetch_type_to_code (caddr_t name);

extern dk_set_t view_aliases;

void sqlo_calculate_view_scope (query_instance_t *qi, ST **tree, char *view_name);

extern int sqlo_print_debug_output;

ST * sqlp_in_exp (ST * l, dk_set_t  right, int is_not);

void sqlp_pl_file (char * text);
void sqlp_pragma_line (char * text);

#ifdef GPF_IN_SQLO
#define SQL_GPF_T(cc)   GPF_T
#define SQL_GPF_T1(cc, tx) GPF_T1(tx)
#else
#define SQL_GPF_T(cc)   sqlc_new_error (cc, "37000", "SQ155", \
    "General internal Optimized compiler error in %.200s:%d.\n" \
    "Please report the statement compiled.", __FILE__, __LINE__)
#define SQL_GPF_T1(cc, tx)   sqlc_new_error (cc, "37000", "SQ156", \
    "Internal Optimized compiler error : %.200s in %.200s:%d.\n" \
    "Please report the statement compiled.", tx, __FILE__, __LINE__)
#endif


caddr_t sqlp_hex_literal (char *yytxt, int unprocess_chars_at_end);
caddr_t sqlp_bit_literal (char *yytxt, int unprocess_chars_at_end);

caddr_t sql_lex_analyze (const char * str2, caddr_t * qst, int max_lexems, int use_strval, int find_lextype);

ST * sqlp_udt_create_external_proc (ptrlong routine_head, caddr_t proc_name,
    caddr_t parms, ST *opt_return, caddr_t alt_type, ptrlong language_name, caddr_t external_name, ST **opts);
ST ** sqlp_wrapper_sqlxml (ST ** selection);
ST * sqlp_wrapper_sqlxml_assign (ST * tree);

int sqlp_tree_has_fun_ref (ST *tree);

extern int scn3_get_lineno (void);
extern char *scn3_get_file_name (void);
#ifndef YY_TYPEDEF_YY_SCANNER_T
#define YY_TYPEDEF_YY_SCANNER_T
typedef void* yyscan_t;
#endif
#if 0
#ifndef YY_DECL
extern int scn3yylex (YYSTYPE *yylval, yyscan_t yyscanner);
extern int scn3splityylex(YYSTYPE *yylval, yyscan_t yyscanner);
#define YY_DECL int scn3yylex (YYSTYPE *yylval, yyscan_t yyscanner)
#endif
#endif
extern int scn3yylex_init (yyscan_t* scanner);
extern int scn3yylex_destroy (yyscan_t yyscanner );
/* No need as soon as thing is reentrant: void scn3yyrestart (FILE * in, yyscan_t yyscanner); */
/* No need as soon as thing is reentrant: void scn3splityyrestart (FILE * in, yyscan_t yyscanner); */
extern void sql_yy_reset (yyscan_t yyscanner);
extern void scn3split_yy_reset (yyscan_t yyscanner);
extern void sql_pop_all_buffers (yyscan_t yyscanner);
extern void scn3split_pop_all_buffers (yyscan_t yyscanner);
/*void yyerror (const char *s);*/
extern int yydebug;
extern char * scn3_get_yytext (yyscan_t yyscanner);
extern size_t scn3_get_yyleng (yyscan_t yyscanner);
int scn3_sprint_curr_line_loc (char *buf, size_t max_buf);
void scn3_set_file_line (char *file, int file_nchars, int line_no);

int bop_weight (int bop);

extern char *part_tok (char ** place);

ST * sqlp_infoschema_redirect (ST *texp);

void sqlp_breakup (ST * sel);
int sel_n_breakup (ST * sel);
void sqlp_dt_header (ST * exp);
caddr_t sqlp_col_num (caddr_t);
int sqlp_is_num_lit (caddr_t x);
caddr_t sqlp_minus (caddr_t n);
char * sqlp_default_cluster ();
dk_set_t cl_all_host_group_list ();
dk_set_t sqlp_index_default_opts(dk_set_t opts);
char * sqlp_inx_col_opt ();

#endif /* _SQLPFN_H */
