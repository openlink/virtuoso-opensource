/*
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

#ifndef _XPATH_IMPL_H
#define _XPATH_IMPL_H

#include "xpath.h"

#ifdef DEBUG
/*#define XPYYDEBUG*/
#endif

#define XPP_MAX_LEXDEPTH 16

typedef struct xp_lexem_s {
  ptrlong xpl_lex_value;
  caddr_t xpl_sem_value;
  ptrlong xpl_lineno;
  ptrlong xpl_depth;
  caddr_t xpl_raw_text;
#ifdef XPATHP_DEBUG
  ptrlong xpl_state;
#endif
} xp_lexem_t;

typedef struct xp_lexbmk_s {
  s_node_t*	xplb_lexem_bufs_tail;
  ptrlong	xplb_offset;
} xp_lexbmk_t;

typedef struct xpp_s {
/* Generic environment */
  query_instance_t * xpp_qi;	/* NULL if parsing is inside SQL compiler or for XSLT path attribute, current qi for runtime */
  client_connection_t *xpp_client;	/* Client of SQL compiler if parsing is inside SQL compiler, NULL for XSLT path attribute, qi->qi_client for runtime */
  char xpp_expn_type;
  caddr_t xpp_err_hdr;
  caddr_t xpp_err;
  XT * xpp_expr;
  encoding_handler_t *xpp_enc;
  lang_handler_t *xpp_lang;
  int xpp_is_quiet;		/* __quiet option is set in [ ... ] config options */
  int xpp_is_davprop;		/* __davprop option is set in [ ... ] config options so if first byte of text is equal to byte 193 then it's a serialized xml_tree */
  dk_set_t xpp_dtd_config_tmp_set;
  int xpp_synthighlight;
  dk_set_t *xpp_checked_functions;
  int xpp_allowed_options;
  dk_set_t xpp_preamble_decls;
  dk_set_t xpp_local_fundefs;
  dk_set_t xpp_global_vars_external;
  dk_set_t xpp_global_vars_preset;
  dk_set_t *xpp_sql_columns;
  int xpp_dry_run;		/*!< This indicates that the result of the compilation is invalid, and an error is not signaled solely in order to collect all sql:column */
  int xpp_lax_nsuri_test;	/*!< Nonzero value means that if name test is an non-qualified name X then the compiled test is 'local name X or *:X', not 'local X' */
  int xpp_save_pragmas;		/*!< This instructs the lexer to preserve pragmas for future use. This is not in use right now but may be used pretty soon */
  int xpp_key_gen;		/*!< 0 = do not fill xqr_key, 1 = save source text only, 2 = save source text and custom namespace decls */
  jmp_buf xpp_reset;
#ifdef XPYYDEBUG
  int xpp_yydebug;
#endif
  caddr_t xpp_uri;
  caddr_t xpp_text;
  int xpp_unictr;		/* Unique counter for objects */
/* Environment of yacc */
  xp_env_t * xpp_xp_env;
  int xpp_lexem_buf_len;
  int xpp_total_lexems_parsed;
  xp_lexem_t *xpp_curr_lexem;
  xp_lexbmk_t xpp_curr_lexem_bmk;
/* Environment of lex */
  size_t xpp_text_ofs;
  size_t xpp_text_len;
  int xpp_lexlineno;			/*!< Source line number, starting from 1 */
  int xpp_lexdepth;			/*!< Lexical depth, it's equal to the current position in \c xpp_lexpars and \c xpp_lexstates */
  int xpp_lexpars[XPP_MAX_LEXDEPTH+2];	/*!< Stack of not-yet-closed parenthesis */
  int xpp_lexstates[XPP_MAX_LEXDEPTH+2];/*!< Stack of lexical states */
  int xpp_string_literal_lexval;	/*!< Lexical value of string literal that is now in process. */
  dk_set_t xpp_output_lexem_bufs;	/*!< Reversed list of lexem buffers that are 100% filled by lexems */
  xp_lexem_t *xpp_curr_lexem_buf;	/*!< Lexem buffer that is filled now */
  xp_lexem_t *xpp_curr_lexem_buf_fill;	/*!< Number of lexems in \c xpp_curr_lexem_buf */
  dk_set_t xpp_xp2sql_params;
} xpp_t;

#define xp_env() xpp->xpp_xp_env

#define YY_DECL int xpyylex (void *yylval, xpp_t *xpp)
extern YY_DECL;

extern void xp_error (xpp_t *xpp, const char *strg);
extern void xp_error_printf (xpp_t *xpp, const char *format, ...);
extern void xpyyerror_impl (xpp_t *xpp, char *raw_text, const char *strg);
extern void xpyyerror_impl_1 (xpp_t *xpp, char *raw_text, int yystate, short *yyssa, short *yyssp, const char *strg);

/*! parses \c strg according to the rules of StringLiteral of XQuery 1.0
It ignores all chars before the first char that is equal to either \c delimiter (or '}').
It also ignores the last character that should be equal to either \c delimiter (or '{')).
'{' and '}' are handled specially when \c attr_cont is true.
The function can call xpyyerror().
*/
extern caddr_t xp_strliteral (xpp_t *xpp, const char *strg, char delimiter, int attr_cont);
extern caddr_t xp_charref_to_strliteral (xpp_t *xpp, const char *strg);

extern caddr_t xml_view_name (client_connection_t *cli, char *q, char *o, char *n, char **err_ret, caddr_t *q_ret, caddr_t *o_ret, caddr_t *n_ret);
extern caddr_t xp_xml_view_name (xpp_t *xpp, char *q, char *o, char *n);

extern XT * xp_step (xpp_t *xpp, XT * in, XT * step, ptrlong axis);
extern XT * xp_make_step (xpp_t *xpp, ptrlong axis, XT * node, XT ** preds);
extern XT * xp_make_literal_tree (xpp_t *xpp, caddr_t literal, int preserve_literal);
extern XT * xp_add_predicates (XT *step, XT **preds);
extern XT * xp_make_pred (xpp_t *xpp, XT * pred);
extern XT * xp_make_flwr (xpp_t *xpp, dk_set_t forlets, XT *where_expn, dk_set_t ordering, XT *return_expn);
extern XT * xp_make_direct_el_ctor (xpp_t *xpp, XT *el_name, dk_set_t attrs, dk_set_t subel_expns);
extern XT * xp_make_direct_comment_ctor (xpp_t *xpp, XT *content);
extern XT * xp_make_direct_pi_ctor (xpp_t *xpp, XT *name, XT *content);
extern XT * xp_make_deref (xpp_t *xpp, XT *step, XT * name_test);
extern XT * xp_make_cast (xpp_t *xpp, ptrlong cast_or_treat, XT *type, XT *arg_tree);
extern XT * xp_make_sortby (xpp_t *xpp, XT *arg_tree, dk_set_t criterions);
extern XT * xp_make_filter (xpp_t *xpp, XT * path, XT * pred);
extern XT * xp_make_filters (xpp_t *xpp, XT * path, dk_set_t pred_list);
extern XT * xp_absolute (xpp_t *xpp, XT * tree, ptrlong axis);
extern XT * xp_path (xpp_t *xpp, XT * in, XT * path, ptrlong axis);
extern XT * xp_make_variable_ref (xpp_t *xpp, caddr_t name);
extern XT * xp_make_sqlcolumn_ref (xpp_t *xpp, caddr_t name);
extern XT * xp_make_call (xpp_t *xpp, const char *qname, caddr_t arg_array);
extern XT * xp_make_call_or_funcall (xpp_t *xpp, caddr_t qname, caddr_t arg_array);
extern XT * xp_make_defun (xpp_t *xpp, caddr_t name, caddr_t param_array, XT *ret_type, xp_query_t *body);

extern XT * xp_embedded_xmlview (xpp_t *caller_xpp, xp_lexbmk_t *begin, XT * xp);

extern void xp_set_encoding_option (xpp_t *xpp, caddr_t enc_name);
extern void xp_register_default_namespace_prefixes (xpp_t *xpp);
extern void xp_register_namespace_prefix (xpp_t *xpp, ccaddr_t ns_prefix, ccaddr_t ns_uri);
extern void xp_register_namespace_prefix_by_xmlns (xpp_t *xpp, ccaddr_t xmlns_attr_name, ccaddr_t ns_uri);
extern dk_set_t xp_bookmark_namespaces (xpp_t *xpp);
extern void xp_unregister_local_namespaces (xpp_t *xpp, dk_set_t start_state);

extern void xp_var_decl (xpp_t *xpp, caddr_t var_name, XT *var_type, XT *init_expn);
extern XT *xp_make_typeswitch (xpp_t *xpp, XT *src, dk_set_t typecases, XT **dflt);
extern XT *xp_make_name_test_from_qname (xpp_t *xpp, caddr_t qname, int qname_is_expanded);
extern XT *xp_make_seq_type (xpp_t *xpp, ptrlong mode, caddr_t top_name, XT *type, ptrlong is_nilable, ptrlong n_occurrences);

extern XT *xp_make_module (xpp_t *xpp, caddr_t ns_prefix, caddr_t ns_uri, XT * expn);
extern void xp_import_schema (xpp_t *xpp, caddr_t ns_prefix, caddr_t ns_uri, caddr_t *at_hints);
extern void xp_import_module (xpp_t *xpp, caddr_t ns_prefix, caddr_t ns_uri, caddr_t *at_hints);
extern void xp_env_push (xpp_t *xpp, char *context_type, char *obj_name, int copy_static_context);
extern void xp_env_pop (xpp_t *xpp);


#define XP_XQUERY_OPTS 0x20
#define XP_XPATH_OPTS 0x40
#define XP_FREETEXT_OPTS 0x80

void xp_reject_option_if_not_allowed (xpp_t *xpp, int type);

extern shuric_vtable_t shuric_vtable__xqr;
extern shuric_t *xqr_shuric_retrieve (query_instance_t *qi, caddr_t uri, caddr_t *err_ret, shuric_t *loaded_by);


extern void xv_label_tree (xpp_t *xpp, xv_join_elt_t * start, XT * tree, dk_set_t * paths);
extern void xe_error (const char * state, const char * str);


#define TBIN_OP(r, o, x, y) (r) = (caddr_t *)(list (4, (ptrlong)(o), SRC_RANGE_DUMMY, (ptrlong)(x), (ptrlong)(y)))

/*! \brief Returns SRC_RANGE_xxx flags for the text search criterion, looking at tree for node argument

When text search tree is created by e.g. xcontains, all nodes of the tree have SRC_RANGE_DUMMY bit
set to 1, and neither SRC_RANGE_MAIN nor SRC_RANGE_ATTR are set. To find whether per-attribute search
is needed or per-main-text, the first (context) argument of xcontains should be processed.
If it is an "go-outside" step, we cannot optimize.
If it is an "step inside in main text", we should set SRC_RANGE_MAIN bit to 1.
If it is an XP_ATTRIBUTE, we should set SRC_RANGE_ATTR bit to 1. */
extern ptrlong xpt_range_flags_of_step (XT *tree, XT *context_node);

/*! \brief Traverses \c tree recursively, clearing range bits outside \c and_mask and marking bits under \c or_mask */
extern void xpt_edit_range_flags (caddr_t *tree, ptrlong and_mask, ptrlong or_mask);

/*! \brief Returns set of words from \c str

The set of words is pushed to \c wordstack_ptr[0], in reverse order (the leftmost word is closer to the bottom of the stack).
The value returned in an error code of the encoding hand'er's decoder */
extern int xp_wordstack_from_string (char * str, encoding_handler_t *eh, lang_handler_t *lh, dk_set_t *wordstack_ptr);

/*! \brief Expand words from \c words into text search nodes of type SRC_WORD or SRC_PHRASE

\c words is a set of words stored in reverse order (the leftmost word is at the bottom of the stack).
If there are no free-text-indexable words in \c words, then either NULL will be
returned, or xp_error will be called, depending on \c allow_xp_error argument.
\c xpp may be NULL if allow_xp_error is 0.
*/
extern caddr_t *xp_word_or_phrase_from_wordstack (xpp_t *xpp, dk_set_t words, int allow_xp_error);
/*! \brief Expand words from \c str into text search nodes of type SRC_WORD or SRC_PHRASE

If there are no free-text-indexable words in \c str, then either NULL will be
returned, or xpyyerror will be called, depending on \c allow_xpyyerror argument.
\c xpp may be NULL if allow_xp_error is 0.
*/
extern caddr_t *xp_word_or_phrase_from_string (xpp_t *xpp, char *str, encoding_handler_t *eh, lang_handler_t *lh, int allow_xp_error);
extern caddr_t *xp_text_parse (char * str, encoding_handler_t *eh, lang_handler_t *lh, caddr_t *ret_dtd_config, caddr_t * err_ret);
extern caddr_t *xp_word_from_exact_string (xpp_t *xpp, const char * str, encoding_handler_t *eh, int allow_xp_error);


xqst_t xe_new_xqst (xpp_t *xpp, int is_ref);
#define XQST_REF 1
#define XQST_INT 0

extern void xp_pred_start (xpp_t *xpp);

extern int xpyy_string_input_impl (xpp_t *xpp, char *buf, int max);

extern caddr_t xp_namespace_pref_to_uri (xpp_t *xpp, caddr_t pref);
extern caddr_t xp_namespace_pref (xpp_t *xpp, caddr_t pref);
extern caddr_t xp_namespace_pref_cname (xpp_t *xpp, caddr_t name);
extern caddr_t xp_make_expanded_name (xpp_t *xpp, caddr_t qname, int is_special /* 0=elt, 1=attr, -1=function */);
extern caddr_t xp_make_extfunction_name (xpp_t *xpp, caddr_t pref, caddr_t qname);
extern XT * xp_make_xqvariable_ref (xpp_t *xpp, caddr_t name);


extern void xp_fill_lexem_bufs (xpp_t *xpp);
extern void xp_copy_lexem_bufs (xpp_t *tgt_xpp, xp_lexbmk_t *begin, xp_lexbmk_t *end, int skip_last_n);

extern void xp_sql (xpp_t *xpp, xp_ctx_t * start_ctx, XT * tree, xp_ret_t * xr, int mode);

#ifdef MALLOC_DEBUG
extern void xt_check (xpp_t * xpp, XT *expn);
#else
#define xt_check(XPP,X)
#endif

#endif /* _XPATH_IMPL_H */

