/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
 *  
*/
#ifndef __SPARQL_H
#define __SPARQL_H

/* $Id$ */

#include "libutil.h"
#ifdef __cplusplus
extern "C" {
#endif
#include "langfunc.h"
#ifdef __cplusplus
}
#endif
#include "shuric.h"

#ifdef DEBUG
#define SPARYYDEBUG
#endif

#ifdef SPARQL_DEBUG
#define spar_dbg_printf(x) printf(x)
#else
#define spar_dbg_printf(x)
#endif

#define SPAR_ALIAS		(ptrlong)1001
#define SPAR_BLANK_NODE_LABEL	(ptrlong)1002
#define SPAR_BUILT_IN_CALL	(ptrlong)1003
#define SPAR_CONV		(ptrlong)1004	/*!< temporary use in SQL printer */
#define SPAR_FUNCALL		(ptrlong)1005
#define SPAR_GP			(ptrlong)1006
#define SPAR_REQ_TOP		(ptrlong)1007
#define SPAR_RETVAL		(ptrlong)1008	/*!< temporary use in SQL printer; this is similar to variable but does not search for field via equiv */
#define SPAR_LIT		(ptrlong)1009
#define SPAR_QNAME		(ptrlong)1011
#define SPAR_QNAME_NS		(ptrlong)1012
#define SPAR_VARIABLE		(ptrlong)1013
#define SPAR_TRIPLE		(ptrlong)1014

#define SPAR_VARNAME_DEFAULT_GRAPH ":default_graph"	/*!< Parameter name to specify default graph URI in SPARQL runtime */
#define SPAR_VARNAME_NAMED_GRAPHS ":named_graphs"	/*!< Parameter name to specify array of named graph URIs in SPARQL runtime */	

#define SPARP_MAX_LEXDEPTH 16
#define SPARP_MAX_SYNTDEPTH SPARP_MAX_LEXDEPTH+10

#define SPARP_MAXLIMIT 0x7Fffffff /* Default value for LIMIT clause of SELECT */

typedef struct spar_tree_s SPART;

typedef struct spar_lexem_s {
  ptrlong sparl_lex_value;
  caddr_t sparl_sem_value;
  ptrlong sparl_lineno;
  ptrlong sparl_depth;
  caddr_t sparl_raw_text;
#ifdef XPATHP_DEBUG  
  ptrlong sparl_state;
#endif  
} spar_lexem_t;

typedef struct spar_lexbmk_s {
  s_node_t*	sparlb_lexem_bufs_tail;
  ptrlong	sparlb_offset;
} spar_lexbmk_t;


#if 0
typedef struct spar_query_s
  {
    shuric_t *		sparqr_shuric;
    int			sparqr_owned_by_shuric;
    struct spar_tree_s * sparqr_tree;
    caddr_t		sparqr_key;
    dk_set_t		sparqr_imports;
  } spar_query_t;
#endif

typedef struct sparp_env_s
  {
    /*spar_query_t *	spare_sparqr;*/
    ptrlong             spare_start_lineno;		/*!< The first line number of the query, may be nonzero if inlined into SQL */
    ptrlong *           spare_param_counter_ptr;	/*!< Pointer to parameter counter used to convert '??' or '$?' to ':nnn' in the query */
    dk_set_t		spare_namespace_prefixes;	/*!< Pairs of ns prefixes and URIs */
    dk_set_t		spare_namespace_prefixes_outer;	/*!< Bookmark in spare_namespace_prefixes that points to the first inherited (not local) namespace */
    caddr_t		spare_base_uri;			/*!< Default base URI for fn:doc and fn:resolve-uri */
    caddr_t             spare_output_valmode_name;	/*!< Name of valmode for top-level result-set */
    caddr_t             spare_output_format_name;	/*!< Name of format for serialization of top-level result-set */
    SPART *		spare_parent_env;		/*!< Pointer to parent env, this will be used when libraries of inference rules are introduced. */
    id_hash_t *		spare_fundefs;			/*!< In-scope function definitions */
    id_hash_t *		spare_vars;			/*!< Known variables as keys, equivs as values */
    id_hash_t *		spare_global_bindings;		/*!< Dictionary of global bindings, varnames as keys, default value expns as values. DV_DB_NULL box for no expn! */
    struct sparp_equiv_s **spare_equivs;		/*!< All variable equivalences made for the tree, in growing buffer */
    int			spare_equiv_count;		/*!< Count of used items in the beginning of spare_equivs */
    caddr_t		spare_default_graph_uri;	/*!< Default graph as set by protocol or FROM graph-uri */
    int			spare_default_graph_locked;	/*!< Default graph is set by protocol and can not be overwritten */
    dk_set_t		spare_named_graph_uris;		/*!< Named graphs as set by protocol or FROM NAMED graph-uri */
    int			spare_named_graphs_locked;	/*!< Named graphs are set by protocol and can not be overwritten */
    dk_set_t		spare_context_graphs;		/*!< Expressions that are default values for graph field */
    dk_set_t		spare_context_subjects;		/*!< Expressions that are default values for subject field */
    dk_set_t		spare_context_predicates;	/*!< Expressions that are default values for predicate field */
    dk_set_t		spare_context_objects;		/*!< Expressions that are default values for objects field */
    dk_set_t		spare_context_gp_subtypes;	/*!< Subtypes of not-yet-completed graph patterns */
    dk_set_t		spare_acc_req_triples;		/*!< Sets of accumulated required triples of GPs */
    dk_set_t		spare_acc_opt_triples;		/*!< Sets of accumulated optional triples of GPs */
    dk_set_t		spare_acc_filters;		/*!< Sets of accumulated filters of GPs */
    dk_set_t		spare_good_graph_varnames;	/*!< Varnames found in non-optional triples before or outside, (including non-optional inside previous non-optional siblings), but not after or inside */
    dk_set_t		spare_good_graph_varname_sets;	/*!< Pointers to the spare_known_gspo_varnames stack, to pop */
    dk_set_t		spare_good_graph_bmk;		/*!< Varnames found in non-optional triples before or outside, (including non-optional inside previous non-optional siblings), but not after or inside */
    dk_set_t		spare_selids;			/*!< Select IDs of GPs */
  } sparp_env_t;

typedef struct sparp_s {
/* Generic environment */
  spar_query_env_t *sparp_sparqre;	/*!< External environment of the query */
  caddr_t sparp_err_hdr;
  SPART * sparp_expr;
  encoding_handler_t *sparp_enc;
  lang_handler_t *sparp_lang;
  int sparp_synthighlight;
  dk_set_t *sparp_checked_functions;
  int sparp_reject_extensions;		/*!< Reject Virtuoso-specific extensions */
  int sparp_save_pragmas;		/*!< This instructs the lexer to preserve pragmas for future use. This is not in use right now but may be used pretty soon */
  int sparp_key_gen;			/*!< 0 = do not fill xqr_key, 1 = save source text only, 2 = save source text and custom namespace decls */
#ifdef XPYYDEBUG
  int sparp_yydebug;
#endif
  caddr_t sparp_text;
  int sparp_unictr;			/*!< Unique counter for objects */
/* Environment of yacc */
  sparp_env_t * sparp_env;
  int sparp_lexem_buf_len;
  int sparp_total_lexems_parsed;
  spar_lexem_t *sparp_curr_lexem;
  spar_lexbmk_t sparp_curr_lexem_bmk;
/* Environment of lex */
  size_t sparp_text_ofs;
  size_t sparp_text_len;
  int sparp_lexlineno;			/*!< Source line number, starting from 1 */
  int sparp_lexdepth;			/*!< Lexical depth, it's equal to the current position in \c sparp_lexpars and \c sparp_lexstates */
  int sparp_lexpars[SPARP_MAX_LEXDEPTH+2];	/*!< Stack of not-yet-closed parenthesis */
  int sparp_lexstates[SPARP_MAX_LEXDEPTH+2];	/*!< Stack of lexical states */
  int sparp_string_literal_lexval;	/*!< Lexical value of string lit that is now in process. */
  dk_set_t sparp_output_lexem_bufs;	/*!< Reversed list of lexem buffers that are 100% filled by lexems */
  spar_lexem_t * sparp_curr_lexem_buf;	/*!< Lexem buffer that is filled now */
  spar_lexem_t * sparp_curr_lexem_buf_fill;	/*!< Number of lexems in \c sparp_curr_lexem_buf */
/* Environment of SPARQL-to-SQL compiler */
  void *sparp_trav_envs[SPARP_MAX_SYNTDEPTH+2];	/*!< Stack of traverse environments. [0] is fake for parent on 'where', [1] is for 'where' etc. */
#ifdef DEBUG
  int sparp_trav_running;		/*!< Flags that some traverse is in progress, in order to GPF if traverse procedure re-enters */
#endif
} sparp_t;


#define sparp_env() sparp_arg->sparp_env

#define YY_DECL int sparyylex (void *yylval, sparp_t *sparp)
extern YY_DECL;

/*extern void sparqr_free (spar_query_t *sparqr);*/

extern void spar_error (sparp_t *sparp, const char *format, ...);
extern void spar_internal_error (sparp_t *sparp, const char *strg);
extern void sparyyerror_impl (sparp_t *xpp, char *raw_text, const char *strg);
extern void sparyyerror_impl_1 (sparp_t *xpp, char *raw_text, int yystate, short *yyssa, short *yyssp, const char *strg);

#define SPART_VARR_EXPORTED	0x001
#define SPART_VARR_IS_REF	0x002
#define SPART_VARR_IS_IRI	0x004
#define SPART_VARR_IS_BLANK	0x008
#define SPART_VARR_IRI_CALC	0x010
#define SPART_VARR_IS_LIT	0x020
#define SPART_VARR_TYPED	0x040
#define SPART_VARR_FIXED	0x080
#define SPART_VARR_NOT_NULL	0x100
#define SPART_VARR_GLOBAL	0x200
#define SPART_VARR_CONFLICT	0x400

#define SPART_HEAD 2 /* number of elements before \c _ union in spar_tree_t */
#define SPART_TYPE(st) ((DV_ARRAY_OF_POINTER == DV_TYPE_OF(st)) ? st->type : SPAR_LIT)

#define SPART_TRIPLE_GRAPH_IDX		0
#define SPART_TRIPLE_SUBJECT_IDX	1
#define SPART_TRIPLE_PREDICATE_IDX	2
#define SPART_TRIPLE_OBJECT_IDX		3
#define tr_graph	tr_fields[0]
#define tr_subject	tr_fields[1]
#define tr_predicate	tr_fields[2]
#define tr_object	tr_fields[3]
#define SPART_TRIPLE_FIELDS_COUNT 4

#define SPARP_EQUIV(sparp,idx) ((sparp)->sparp_env->spare_equivs[(idx)])

#define SPARP_FOREACH_GP_EQUIV(sparp,groupp,inx,eq) \
  do { \
    int __max_##inx = groupp->_.gp.equiv_count; \
    for (inx = 0; inx < __max_##inx; inx ++) \
      { \
        sparp_equiv_t *eq = SPARP_EQUIV(sparp, groupp->_.gp.equiv_indexes[inx]);

#define END_SPARP_FOREACH_GP_EQUIV \
	  }} while (0);

#define SPARP_REVFOREACH_GP_EQUIV(sparp,groupp,inx,eq) \
    for (inx = groupp->_.gp.equiv_count; inx--;) \
      { \
        sparp_equiv_t *eq = SPARP_EQUIV(sparp, groupp->_.gp.equiv_indexes[inx]);

#define END_SPARP_REVFOREACH_GP_EQUIV }

typedef struct rdf_ds_field_s *ssg_valmode_t;

typedef struct spar_tree_s
{
  ptrlong	type;
  caddr_t	srcline;
  union {
    struct {
        SPART *arg;
        caddr_t aname;
      } alias; /*!< only for use in top-level result-set list */
    struct {
      SPART *left;
      SPART *right;
      } bin_exp;
    struct {
      ptrlong btype;
      SPART **args;
      } builtin;
    struct {
        SPART *arg;
        ssg_valmode_t native;
        ssg_valmode_t needed;
      } conv; /*!< temporary use in SQL printer */
    struct {
      caddr_t qname;
      ptrlong argcount;
      SPART **argtrees;
      } funcall;
    struct {
      ptrlong subtype;
      SPART **members;
      SPART **filters;
      caddr_t selid;
      ptrlong *equiv_indexes;
      ptrlong equiv_count;
      } gp;
    struct {
      caddr_t val;
      caddr_t datatype;
      caddr_t language;
      } lit;
    struct {
      ptrlong subtype;
      caddr_t retvalmode_name;
      caddr_t formatmode_name;
      SPART **retvals;
      caddr_t retselid;
      SPART **sources;
      SPART *pattern;
      SPART **order;
      caddr_t limit;
      caddr_t offset;
      struct sparp_equiv_s **equivs;
      ptrlong equiv_count;
      } req_top;
    struct {
      SPART *tr_fields[SPART_TRIPLE_FIELDS_COUNT];
      caddr_t selid;
      caddr_t tabid;
      } triple;
    struct {
      caddr_t vname;
      caddr_t selid;
      caddr_t tabid;
      ptrlong restrictions;
      ptrlong tr_idx;		/*!< Index in quad (0 = graph ... 3 = obj) */
      ptrlong equiv_idx;
      } var;
    struct {
      ptrlong direction;
      SPART *expn;
      } oby;
  } _;
} sparp_tree_t;

typedef unsigned char SPART_buf[sizeof (sparp_tree_t) + BOX_AUTO_OVERHEAD];
#define SPART_AUTO(ptr,buf,t) \
  do { \
    BOX_AUTO(ptr,buf,sizeof(SPART),DV_ARRAY_OF_POINTER); \
    memset (ptr, 0, sizeof (SPART)); \
    ptr->type = t; \
    } while (0)

extern sparp_t * sparp_query_parse (char * str, spar_query_env_t *sparqre);
extern int sparyyparse (void *sparp);

extern void spart_dump (void *tree_arg, dk_session_t *ses, int indent, const char *title, int hint);

#define SPAR_IS_BLANK_OR_VAR(tree) \
  ((DV_ARRAY_OF_POINTER == DV_TYPE_OF (tree)) && \
   ((SPAR_VARIABLE == tree->type) || \
    (SPAR_BLANK_NODE_LABEL == tree->type) ) )

#define SPAR_IS_LIT(tree) \
  ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (tree)) || \
   (SPAR_LIT == tree->type) )

#define SPART_VARNAME_IS_GLOB(varname) (':' == (varname)[0])

extern caddr_t spar_var_name_of_ret_column (SPART *tree);
extern caddr_t spar_alias_name_of_ret_column (SPART *tree);

#ifdef MALLOC_DEBUG
typedef SPART* spartlist_impl_t (sparp_t *sparp, ptrlong length, ptrlong type, ...);
typedef SPART* spartlist_with_tail_impl_t (sparp_t *sparp, ptrlong length, caddr_t tail, ptrlong type, ...);
typedef struct spartlist_track_s
  {
    spartlist_impl_t *spartlist_ptr;
    spartlist_with_tail_impl_t *spartlist_with_tail_ptr;
  } spartlist_track_t;

spartlist_track_t *spartlist_track (const char *file, int line);
#define spartlist spartlist_track (__FILE__, __LINE__)->spartlist_ptr
#define spartlist_with_tail spartlist_track (__FILE__, __LINE__)->spartlist_with_tail_ptr
#else
extern SPART* spartlist (sparp_t *sparp, ptrlong length, ptrlong type, ...);
extern SPART* spartlist_with_tail (sparp_t *sparp, ptrlong length, caddr_t tail, ptrlong type, ...);
#define spartlist_impl spartlist
#define spartlist_with_tail_impl spartlist_with_tail
#endif

extern caddr_t sparp_expand_qname_prefix (sparp_t *sparp, caddr_t qname);
extern caddr_t spar_strliteral (sparp_t *sparp, const char *sparyytext, int strg_is_long, char delimiter);
extern caddr_t spar_mkid (sparp_t * sparp, const char *prefix);
extern void spar_change_sign (caddr_t *lit_ptr);

extern void sparp_define (sparp_t *sparp, caddr_t param, ptrlong value_lexem_type, caddr_t value);
extern void spar_selid_push (sparp_t *sparp);
extern caddr_t spar_selid_pop (sparp_t *sparp);
extern void spar_gp_init (sparp_t *sparp, ptrlong subtype);
extern SPART *spar_gp_finalize (sparp_t *sparp);
extern void spar_gp_add_member (sparp_t *sparp, SPART *memb);
extern void spar_gp_add_filter (sparp_t *sparp, SPART *filt);
extern void spar_gp_add_filter_for_named_graph (sparp_t *sparp);
extern SPART **spar_retvals_of_construct (sparp_t *sparp, SPART *ctor_gp);
extern SPART **spar_retvals_of_describe (sparp_t *sparp, SPART **retvals);
extern SPART *spar_make_top (sparp_t *sparp, ptrlong subtype, SPART **retvals,
  caddr_t retselid, SPART *pattern, SPART **order, caddr_t limit, caddr_t offset);
extern SPART *spar_make_triple (sparp_t *sparp, SPART *graph, SPART *subject, SPART *predicate, SPART *object);
extern SPART *spar_make_variable (sparp_t *sparp, caddr_t name);
extern SPART *spar_make_blank_node (sparp_t *sparp, caddr_t name, int bracketed);
extern SPART *spar_make_typed_literal (sparp_t *sparp, caddr_t strg, caddr_t type, caddr_t lang);

extern void spar_fill_lexem_bufs (sparp_t *sparp);
extern void spar_copy_lexem_bufs (sparp_t *tgt_sparp, spar_lexbmk_t *begin, spar_lexbmk_t *end, int skip_last_n);

extern id_hashed_key_t spar_var_hash (caddr_t p_data);
extern int spar_var_cmp (caddr_t p_data1, caddr_t p_data2);

/*extern shuric_vtable_t shuric_vtable__sparqr;*/

#endif
