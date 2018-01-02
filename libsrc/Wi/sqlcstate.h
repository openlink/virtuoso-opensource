/*
 *  sqlcstate.h
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

#ifndef SQLCSTATE_H
#define SQLCSTATE_H

typedef struct scn3_context_s
  {
  int national_char;
  int uname_strlit;
  int lineno;			/*!< Throughout counter of lines in the source text */
  int plineno;			/*!< Physical counter of lines in the source text - used for the PL debugger */
  int lineno_increment;		/*!< This is zero for 'macroexpanded' fragments of SQL text, to prevent from confusing when a long text is inserted instead of a single line */
  int lexdepth;			/*!< Number of opened parenthesis */
  dk_set_t namespaces;		/*!< List of namespace prefixes and URIs */
  scn3_paren_t parens[SCN3_MAX_LEX_DEPTH];
  scn3_line_loc_t line_locs[SCN3_MAX_PRAGMALINE_DEPTH];		/*! Stack of logical locations. */
  int pragmaline_depth;		/*! This is the number of not-yet-popped '#pragma line push' directives. */
  scn3_include_fragment_t include_stack [MAX_INCLUDE_DEPTH];
  int include_depth;		/*! Number of fragments that are started but not yet completed. It's zero while the whole text is in SQL */
  int inside_error_reporter;	/*! Flag that indicates that yylex() is called from yy_new_error() and error during te call should not cause infinite recursion */
  char *last_keyword_yytext;
  int last_keyword_yyleng;
  dk_session_t *split_ses;
  dk_set_t html_lines;
  } scn3_context_t;

typedef struct sql_compile_state_s /* serialized in parse_sem */
{
  oid_t scs_v_u_id;
  oid_t scs_v_g_id;
  char scs_sql_line_loc_text[1000];
  char scs_sql_err_text[2000];
  char scs_sql_err_state[6];
  char scs_sql_err_native[1000];
  int scs_parse_not_char_c_escape;
  int scs_parse_utf8_execs;
  int scs_parse_pldbg;
  caddr_t scs_pl_file;
  int 	scs_pl_file_offs;
  dk_set_t scs_sql3_breaks;
  dk_set_t scs_sql3_pbreaks;
  dk_set_t scs_sql3_ppbreaks;
  caddr_t scs_sqlp_udt_current_type;
  int scs_sqlp_udt_current_type_lang;
  sql_tree_t *scs_parse_tree;
  sql_tree_t *scs_global_trans;
  char *scs_sql_text;
  int scs_param_inx;
  int scs_sqlp_have_infoschema_views;
  char * scs_inside_view;
  char	scs_count_qr_global_refs; /*   qr global ssl's will be counted as refs in cv_refd_slots etc. */
  char	scs_inside_sem;
  sql_comp_t *	scs_current_sc;
  sql_comp_t *	scs_top_sc;
  scn3_context_t scs_scn3c;
  jmp_buf_splice parse_reset;
} sql_compile_state_t;


#define top_sc global_scs->scs_top_sc
#define v_u_id global_scs->scs_v_u_id
#define v_g_id global_scs->scs_v_g_id
#define sql_line_loc_text	global_scs->scs_sql_line_loc_text
#define sql_err_text		global_scs->scs_sql_err_text
#define sql_err_state		global_scs->scs_sql_err_state
#define sql_err_native		global_scs->scs_sql_err_native
#define parse_not_char_c_escape	global_scs->scs_parse_not_char_c_escape
#define parse_utf8_execs	global_scs->scs_parse_utf8_execs
#define parse_pldbg		global_scs->scs_parse_pldbg
#define pl_file			global_scs->scs_pl_file
#define pl_file_offs		global_scs->scs_pl_file_offs
#define sql3_breaks		global_scs->scs_sql3_breaks
#define sql3_pbreaks		global_scs->scs_sql3_pbreaks
#define sql3_ppbreaks		global_scs->scs_sql3_ppbreaks
#define sqlp_udt_current_type	global_scs->scs_sqlp_udt_current_type
#define sqlp_udt_current_type_lang global_scs->scs_sqlp_udt_current_type_lang
#define parse_tree		global_scs->scs_parse_tree
#define global_trans		global_scs->scs_global_trans
#define sqlc_sql_text		global_scs->scs_sql_text
#define param_inx		global_scs->scs_param_inx
#define sqlp_have_infoschema_views	global_scs->scs_sqlp_have_infoschema_views
#define inside_view global_scs->scs_inside_view
#define sqlg_count_qr_global_refs global_scs->scs_count_qr_global_refs
#define sqlc_inside_sem global_scs->scs_inside_sem
#define sqlc_current_sc global_scs->scs_current_sc
#define html_lines global_scs->scs_scn3c.html_lines

#define SET_SCS(scs) \
  THREAD_CURRENT_THREAD->thr_sql_scs = (void*)scs

#define global_scs ((sql_compile_state_t*) (THREAD_CURRENT_THREAD->thr_sql_scs))

#define SCS_STATE_FRAME		sql_compile_state_t * save_scs; sql_compile_state_t scs

#define SCS_STATE_PUSH \
        { \
	  save_scs = global_scs; \
          memset (&scs, 0, sizeof (sql_compile_state_t)); \
	  SET_SCS (&scs); \
	}

#define SCS_STATE_POP \
  SET_SCS (save_scs)


#endif
