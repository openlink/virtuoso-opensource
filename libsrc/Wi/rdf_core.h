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
#ifndef __RDF_CORE_H
#define __RDF_CORE_H
#include "langfunc.h"
#include "sqlnode.h"

/* Set of callback to accept the stream of RDF quads that are grouped by graph and share blank node IDs */

#define TRIPLE_FEED_NEW_GRAPH	0
#define TRIPLE_FEED_NEW_BLANK	1
#define TRIPLE_FEED_GET_IID	2
#define TRIPLE_FEED_TRIPLE	3
#define TRIPLE_FEED_TRIPLE_L	4
#define TRIPLE_FEED_COMMIT	5
#define COUNTOF__TRIPLE_FEED	6

typedef struct triple_feed_s {
  query_instance_t *tf_qi;
  id_hash_t *tf_blank_node_ids;
  id_hash_t *tf_cached_iids;
  caddr_t tf_app_env;		/*!< Environment for use by callbacks, owned by caller */
  caddr_t tf_graph_uri;		/*!< Graph uri, owned by caller */
  ccaddr_t tf_stmt_texts[COUNTOF__TRIPLE_FEED];
  query_t *tf_queries[COUNTOF__TRIPLE_FEED];
} triple_feed_t;

extern triple_feed_t *tf_alloc (void);
extern void tf_free (triple_feed_t *tf);
extern void tf_set_stmt_texts (triple_feed_t *tf, const char **stmt_texts, caddr_t *err_ptr);
extern caddr_t tf_get_iid (triple_feed_t *tf, caddr_t uri);
extern void tf_triple (triple_feed_t *tf, caddr_t s_uri, caddr_t p_uri, caddr_t o_uri);
extern void tf_triple_l (triple_feed_t *tf, caddr_t s_uri, caddr_t p_uri, caddr_t obj_sqlval, caddr_t obj_datatype, caddr_t obj_language);


typedef struct ttlp_s
{
  /* inputs */
  const char *ttlp_text;	/*!< Full source text, if short, or the beginning of long text, or an empty string */
  int ttlp_text_len;		/*!< Length of \c ttlp_text */
  int ttlp_text_ofs;		/*!< Current position in \c ttlp_text */
  dk_session_t *ttlp_input;	/*!< Long input */
  const char *ttlp_input_name;	/*!< URI or file name or other name of source */
  encoding_handler_t *ttlp_enc;	/*!< Encoding of the source */
  /* lexer */
  int ttlp_lexlineno;		/*!< Current line number */
  int ttlp_lexdepth;		/*!< Current number of not-yet-closed parenthesis */
  const char *ttlp_raw_text;	/*!< Raw text of the lexem */
  /* parser */
  const char *ttlp_err_hdr;
  caddr_t ttlp_catched_error;
  caddr_t ttlp_default_ns_uri;
  dk_set_t ttlp_namespaces;
  dk_set_t ttlp_saved_uris;
  caddr_t ttlp_base_uri;
  caddr_t ttlp_subj_uri;
  caddr_t ttlp_pred_uri;
  /* feeder */
  triple_feed_t *ttlp_tf;
} ttlp_t;


extern dk_mutex_t *ttl_lex_mtx;
extern ttlp_t global_ttlp;
extern ttlp_t *ttlp_alloc (void);
extern void ttlp_free (ttlp_t *ttlp);
#ifdef RE_ENTRANT_TTLYY
#define TTLP_PARAM ttlp_t *ttlp_arg,
#define TTLP_PARAM_0 ttlp_t *ttlp_arg
#define TTLP_ARG ttlp_arg,
#define TTLP_ARG_0 ttlp_arg
#define ttlp_ptr ttlp_arg
#define ttlp_inst ttlp_arg[0]
#else
#define TTLP_PARAM
#define TTLP_PARAM_0
#define TTLP_ARG
#define TTLP_ARG_0
#define ttlp_ptr (&global_ttlp)
#define ttlp_inst global_ttlp
#endif

#define YY_DECL int ttlyylex (void *yylval)
extern int ttlyylex (void *yylval);
extern void ttlyyrestart (FILE *input_file);
extern int ttlyyparse (void);

extern void ttlyyerror_impl (TTLP_PARAM const char *raw_text, const char *strg);
extern void ttlyyerror_impl_1 (TTLP_PARAM const char *raw_text, int yystate, short *yyssa, short *yyssp, const char *strg);

extern caddr_t DBG_NAME (ttlp_expand_qname_prefix) (DBG_PARAMS TTLP_PARAM caddr_t qname);
extern caddr_t DBG_NAME (tf_bnode_iid) (DBG_PARAMS triple_feed_t *tf, const char *sparyytext);
#ifdef MALLOC_DEBUG
#define ttlp_expand_qname_prefix(qname) DBG_NAME (ttlp_expand_qname_prefix) (__FILE__, __LINE__, (qname))
#define tf_bnode_iid(tf, sparyytext) DBG_NAME (tf_bnode_iid) (__FILE__, __LINE__, (tf), (sparyytext))
#endif

extern caddr_t ttlp_strliteral (TTLP_PARAM const char *sparyytext, int strg_is_long, char delimiter);
extern caddr_t ttl_query_lex_analyze (caddr_t str, wcharset_t *query_charset);

#define ttlp_triple(o_uri) tf_triple (ttlp_inst.ttlp_tf, box_copy (ttlp_inst.ttlp_subj_uri), box_copy (ttlp_inst.ttlp_pred_uri), (o_uri))
#define ttlp_triple_l(o_sqlval,o_dt,o_lang) tf_triple_l (ttlp_inst.ttlp_tf, box_copy (ttlp_inst.ttlp_subj_uri), box_copy (ttlp_inst.ttlp_pred_uri), (o_sqlval), (o_dt), (o_lang));

extern void
rdfxml_parse (query_instance_t * qi, caddr_t text, caddr_t *err_ret,
  int omit_top_rdf, caddr_t base_uri, caddr_t graph_uri,
  ccaddr_t *stmt_texts, caddr_t app_env,
  const char *enc, lang_handler_t *lh
   /*, caddr_t dtd_config, dtd_t **ret_dtd,
   id_hash_t **ret_id_cache, xml_ns_2dict_t *ret_ns_2dict*/ );

extern caddr_t rdf_load_turtle (
  caddr_t str, caddr_t base_uri, caddr_t graph_uri,
  caddr_t *stmts, caddr_t app_env,
  query_instance_t *qi, wcharset_t *query_charset, caddr_t *err_ret );

#endif
