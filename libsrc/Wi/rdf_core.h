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
#include "rdf_mapping_jso.h"
#include "xmlparser.h" /* for xml_read_func_t and xml_read_abend_func_t */

#define IRI_TO_ID_IF_KNOWN	0 /*!< Return IRI_ID if known, integer zero (NULL) if not known or error is not NULL */
#define IRI_TO_ID_WITH_CREATE	1 /*!< Return IRI_ID if known or created on the fly, integer zero (NULL) if error is not NULL */
#define IRI_TO_ID_IF_CACHED	2 /*!< Return IRI_ID if known and is in cache, integer zero (NULL) if not known or known but not cached or error is not NULL */
extern caddr_t iri_to_id (caddr_t *qst, caddr_t name, int mode, caddr_t *err_ret);
extern caddr_t key_id_to_iri (query_instance_t * qi, iri_id_t iri_id_no);
#define BNODE_IID_TO_LABEL(iid) (((iid) >= MIN_64BIT_BNODE_IRI_ID) ? \
  box_sprintf (30, "nodeID://b" BOXINT_FMT, (boxint)((iid)-MIN_64BIT_BNODE_IRI_ID)) : \
  box_sprintf (30, "nodeID://" BOXINT_FMT, (boxint)(iid)) )


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
  caddr_t tf_app_env;		/*!< Environment for use by callbacks, owned by caller */
  caddr_t tf_graph_uri;		/*!< Graph uri, owned by caller */
  caddr_t tf_graph_iid;		/*!< Graph iri ID, local */
  const char *tf_creator;	/*!< Name of BIF that created the feed (this name is printed in diagnostics) */
  ccaddr_t tf_cbk_names[COUNTOF__TRIPLE_FEED];
  query_t *tf_cbk_qrs[COUNTOF__TRIPLE_FEED];
} triple_feed_t;

extern triple_feed_t *tf_alloc (void);
extern void tf_free (triple_feed_t *tf);
extern void tf_set_cbk_names (triple_feed_t *tf, const char **cbk_names);
extern void tf_new_graph (triple_feed_t *tf);
extern caddr_t tf_get_iid (triple_feed_t *tf, caddr_t uri);
extern void tf_commit (triple_feed_t *tf);
extern void tf_triple (triple_feed_t *tf, caddr_t s_uri, caddr_t p_uri, caddr_t o_uri);
extern void tf_triple_l (triple_feed_t *tf, caddr_t s_uri, caddr_t p_uri, caddr_t obj_sqlval, caddr_t obj_datatype, caddr_t obj_language);

#define TTLP_STRING_MAY_CONTAIN_CRLF	0x01
#define TTLP_VERB_MAY_BE_BLANK		0x02
#define TTLP_ACCEPT_VARIABLES		0x04
#define TTLP_SKIP_LITERAL_SUBJECTS	0x08

#define TTLP_ALLOW_QNAME_A		0x01
#define TTLP_ALLOW_QNAME_HAS		0x02
#define TTLP_ALLOW_QNAME_IS		0x04
#define TTLP_ALLOW_QNAME_OF		0x08
#define TTLP_ALLOW_QNAME_THIS		0x10

typedef struct ttlp_s
{
  /* inputs */
  const char *ttlp_text;	/*!< Full source text, if short, or the beginning of long text, or an empty string */
  int ttlp_text_len;		/*!< Length of \c ttlp_text */
  int ttlp_text_ofs;		/*!< Current position in \c ttlp_text */
  xml_read_func_t ttlp_iter;
  xml_read_abend_func_t ttlp_iter_abend;
  void *ttlp_iter_data;
  const char *ttlp_input_name;	/*!< URI or file name or other name of source */
  encoding_handler_t *ttlp_enc;	/*!< Encoding of the source */
  long ttlp_flags;		/*!< Flags for dirty load */
  /* lexer */
  int ttlp_lexlineno;		/*!< Current line number */
  int ttlp_lexdepth;		/*!< Current number of not-yet-closed parenthesis */
  const char *ttlp_raw_text;	/*!< Raw text of the lexem */
  ptrlong ttlp_special_qnames;	/*!< Bitmask where every bit means that the identifier in qname, not a keyword */
  /* parser */
  const char *ttlp_err_hdr;	/*!< Human-readable phrase that gives a name to the parsing routine, e.g. "Turtle parser of web crawer" */
  caddr_t ttlp_catched_error;	/*!< The error that stopped the processing, as a three-element vector made by srv_make_new_error () */
  caddr_t ttlp_default_ns_uri;	/*!< IRI associated with ':' prefix */
  dk_set_t ttlp_namespaces;	/*!< get_keyword style list of namespace prefixes (keys) and IRIs (values) */
  dk_set_t ttlp_saved_uris;	/*!< Stack that keeps URIs. YACC stack is not used to let us free memory on error */
  caddr_t ttlp_base_uri;	/*!< Base URI to resolve relative URIs */
  caddr_t ttlp_subj_uri;	/*!< Current subject URI, but it become object URI if ttlp_pred_is_reverse */
  caddr_t ttlp_pred_uri;	/*!< Current predicate URI */
  caddr_t ttlp_obj;		/*!< Current object URI or value */
  caddr_t ttlp_obj_type;	/*!< Current object type URI */
  caddr_t ttlp_obj_lang;	/*!< Current object language mark */
  int ttlp_pred_is_reverse;	/*!< Flag if ttlp_pred_uri is used as reverse, e.g. in 'O is P of S' syntax */
  caddr_t ttlp_formula_iid;	/*!< IRI ID of the blank node of the formula ( '{ ... }' notation of N3 */
  /* feeder */
  triple_feed_t *ttlp_tf;
} ttlp_t;


#ifndef RE_ENTRANT_TTLYY
extern dk_mutex_t *ttl_lex_mtx;
#endif
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
extern void ttlyy_reset (void);
extern int ttlyyparse (void);

extern void ttlyyerror_impl (TTLP_PARAM const char *raw_text, const char *strg);
extern void ttlyyerror_impl_1 (TTLP_PARAM const char *raw_text, int yystate, short *yyssa, short *yyssp, const char *strg);

extern ptrlong ttlp_bit_of_special_qname (caddr_t qname);
extern caddr_t DBG_NAME (ttlp_expand_qname_prefix) (DBG_PARAMS TTLP_PARAM caddr_t qname);
extern caddr_t DBG_NAME (tf_bnode_iid) (DBG_PARAMS triple_feed_t *tf, caddr_t boxed_sparyytext);
extern caddr_t DBG_NAME (tf_formula_bnode_iid) (DBG_PARAMS TTLP_PARAM caddr_t boxed_sparyytext);
#ifdef MALLOC_DEBUG
#define ttlp_expand_qname_prefix(qname) DBG_NAME (ttlp_expand_qname_prefix) (__FILE__, __LINE__, (qname))
#define tf_bnode_iid(tf, boxed_sparyytext) DBG_NAME (tf_bnode_iid) (__FILE__, __LINE__, (tf), (boxed_sparyytext))
#ifdef RE_ENTRANT_TTLYY
#define tf_formula_bnode_iid(ttlp, boxed_sparyytext) DBG_NAME (tf_formula_bnode_iid) (__FILE__, __LINE__, (ttlp), (boxed_sparyytext))
#else
#define tf_formula_bnode_iid(boxed_sparyytext) DBG_NAME (tf_formula_bnode_iid) (__FILE__, __LINE__, (boxed_sparyytext))
#endif
#endif
extern caddr_t ttlp_uri_resolve (TTLP_PARAM caddr_t qname);

/* Numeric values of these constants are important, do not alter them. Theyh're used in tricky way. */
#define TTLP_STRLITERAL_QUOT 		1
#define TTLP_STRLITERAL_QUOT_AT		2
#define TTLP_STRLITERAL_3QUOT 		3
#define TTLP_STRLITERAL_3QUOT_AT	4
extern caddr_t ttlp_strliteral (TTLP_PARAM const char *sparyytext, int mode, char delimiter);
extern caddr_t ttl_query_lex_analyze (caddr_t str, wcharset_t *query_charset);

extern void ttlp_triple_and_inf (TTLP_PARAM caddr_t o_uri);
extern void ttlp_triple_l_and_inf (TTLP_PARAM caddr_t o_sqlval, caddr_t o_dt, caddr_t o_lang);

extern void
rdfxml_parse (query_instance_t * qi, caddr_t text, caddr_t *err_ret,
  int omit_top_rdf, caddr_t base_uri, caddr_t graph_uri,
  ccaddr_t *stmt_texts, caddr_t app_env,
  const char *enc, lang_handler_t *lh
   /*, caddr_t dtd_config, dtd_t **ret_dtd,
   id_hash_t **ret_id_cache, xml_ns_2dict_t *ret_ns_2dict*/ );

extern caddr_t rdf_load_turtle (
  caddr_t str, caddr_t base_uri, caddr_t graph_uri, long flags,
  ccaddr_t *cbk_names, caddr_t app_env,
  query_instance_t *qi, wcharset_t *query_charset, caddr_t *err_ret );

/* Metadata about free-text index on DB.DBA.RDF_OBJ */
extern id_hash_t *rdf_obj_ft_rules;

#endif
