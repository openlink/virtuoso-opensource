/*
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

#ifndef __RDF_CORE_H
#define __RDF_CORE_H
#include "langfunc.h"
#include "uname_const_decl.h"
#include "sqlnode.h"
#include "rdf_mapping_jso.h"
#include "xmlparser.h" /* for xml_read_func_t and xml_read_abend_func_t */

#define RO_START_LEN 10 /*!< Maximum length of string prefixes in prefix table */

#define IRI_TO_ID_IF_KNOWN	0 /*!< Return IRI_ID if known, integer zero (NULL) if not known or error is not NULL */
#define IRI_TO_ID_WITH_CREATE	1 /*!< Return IRI_ID if known or created on the fly, integer zero (NULL) if error is not NULL */
#define IRI_TO_ID_IF_CACHED	2 /*!< Return IRI_ID if known and is in cache, integer zero (NULL) if not known or known but not cached or error is not NULL */

/*!< returns 0 for NULL or non-cached rdf box or error, 1 for ready to use iri_id, 2 for URI string */
extern int iri_canonicalize (query_instance_t *qi, caddr_t name, int mode, caddr_t *res_ret, caddr_t *err_ret);
extern caddr_t iri_to_id (caddr_t *qst, caddr_t name, int mode, caddr_t *err_ret);
extern caddr_t key_id_to_canonicalized_iri (query_instance_t * qi, iri_id_t iri_id_no);
extern caddr_t key_id_to_iri (query_instance_t * qi, iri_id_t iri_id_no);
extern int key_id_to_namespace_and_local (query_instance_t *qi, iri_id_t iid, caddr_t *subj_ns_ret, caddr_t *subj_loc_ret);
#define rdf_type_twobyte_to_iri(twobyte) nic_id_name (rdf_type_cache, (twobyte))
#define rdf_lang_twobyte_to_string(twobyte) nic_id_name (rdf_lang_cache, (twobyte))
/*! \returns NULL for string, (ccaddr_t)((ptrlong)1) for unsupported, 2 for NULL, UNAME for others */
extern caddr_t xsd_type_of_box (caddr_t arg);
/*! Casts \c new_val to some datatype appropriate for XPATH/XSLT and stores in an XSLT variable value or XQI slot passed as an address to free and set */
extern void rb_cast_to_xpath_safe (query_instance_t *qi, caddr_t new_val, caddr_t *retval_ptr);
extern iri_id_t bnode_t_treshold;
#ifndef NDEBUG
#define BNODE_FMT_IMPL(fn,arg1,pfx,iid) (((iri_id_t)(iid) >= bnode_t_treshold) ? \
  (fn) ((arg1), pfx "t" IIDBOXINT_FMT, (boxint)((iri_id_t)(iid) - bnode_t_treshold)) : \
  (((iri_id_t)(iid) >= MIN_64BIT_BNODE_IRI_ID) ? \
    (fn) ((arg1), pfx "b" IIDBOXINT_FMT, (boxint)((iri_id_t)(iid)-MIN_64BIT_BNODE_IRI_ID)) : \
    (fn) ((arg1), pfx IIDBOXINT_FMT, (boxint)((iri_id_t)(iid))) ) )
#else
#define BNODE_FMT_IMPL(fn,arg1,pfx,iid) (((iri_id_t)(iid) >= MIN_64BIT_BNODE_IRI_ID) ? \
  (fn) ((arg1), pfx "b" IIDBOXINT_FMT, (boxint)((iri_id_t)(iid)-MIN_64BIT_BNODE_IRI_ID)) : \
  (fn) ((arg1), pfx IIDBOXINT_FMT, (boxint)((iri_id_t)(iid))) )
#endif


#define BNODE_IID_TO_LABEL_BUFFER(buf,iid) BNODE_FMT_IMPL(sprintf,buf,"nodeID://",iid)
#define BNODE_IID_TO_LABEL(iid) BNODE_FMT_IMPL(box_sprintf,30,"nodeID://",iid)
#define BNODE_IID_TO_LABEL_LOCAL(iid) BNODE_FMT_IMPL(box_sprintf,30,"",iid)
#define BNODE_IID_TO_TTL_LABEL_LOCAL(iid) BNODE_FMT_IMPL(box_sprintf,30,"v",iid)
#define BNODE_IID_TO_TALIS_JSON_LABEL(iid) BNODE_FMT_IMPL(box_sprintf,30,"_:v",iid)

/* Set of callback to accept the stream of RDF quads that are grouped by graph and share blank node IDs */

#define TRIPLE_FEED_NEW_GRAPH	0
#define TRIPLE_FEED_NEW_BLANK	1
#define TRIPLE_FEED_GET_IID	2
#define TRIPLE_FEED_TRIPLE	3
#define TRIPLE_FEED_TRIPLE_L	4
#define TRIPLE_FEED_COMMIT	5
#define TRIPLE_FEED_MESSAGE	6
#define COUNTOF__TRIPLE_FEED__REQUIRED	7
#define TRIPLE_FEED_NEW_BASE	7
#define COUNTOF__TRIPLE_FEED__ALL	8

typedef struct triple_feed_s {
  query_instance_t *tf_qi;
  id_hash_t *tf_blank_node_ids;
  caddr_t *tf_app_env;		/*!< Environment for use by callbacks, owned by caller. It's "caddr_t *" instead of plain "caddr_t" because it's vector in most cases. */
  caddr_t tf_boxed_input_name;	/*!< URI or file name or other name of source, can be NULL, local */
  caddr_t tf_default_graph_uri;	/*!< Default graph uri, local */
  caddr_t tf_current_graph_uri;	/*!< Currently active graph uri, can be equal to tf_default_graph_uri, local */
  caddr_t tf_base_uri;		/*!< Base URI to resolve relative URIs, local */
  caddr_t tf_default_graph_iid;	/*!< Default graph iri ID, local */
  caddr_t tf_current_graph_iid;	/*!< Current graph iri ID, local */
  const char *tf_creator;	/*!< Name of BIF that created the feed (this name is printed in diagnostics) */
  ccaddr_t tf_cbk_names[COUNTOF__TRIPLE_FEED__ALL];	/*!< Callback names, owned by caller */
  query_t *tf_cbk_qrs[COUNTOF__TRIPLE_FEED__ALL];	/*!< Compiled callback queries, they can be NULLs for empty string names or names that starts with '!' */
  ptrlong tf_triple_count;	/*!< Number of triples that are sent to callbacks already, must be boxed before sending to SQL callbacks! */
  ptrlong tf_message_count;	/*!< Number of messages that are reported already, must be boxed before sending to SQL callbacks! */
  int *tf_line_no_ptr;		/*!< Pointer to some line number counter somewhere outside, may be NULL */
} triple_feed_t;

extern triple_feed_t *tf_alloc (void);
extern void tf_free (triple_feed_t *tf);
extern void tf_set_cbk_names (triple_feed_t *tf, ccaddr_t *cbk_names);
extern void tf_new_graph (triple_feed_t *tf, caddr_t uri);
extern caddr_t tf_get_iid (triple_feed_t *tf, caddr_t uri);
extern void tf_commit (triple_feed_t *tf);
extern void tf_triple (triple_feed_t *tf, caddr_t s_uri, caddr_t p_uri, caddr_t o_uri);
extern void tf_triple_l (triple_feed_t *tf, caddr_t s_uri, caddr_t p_uri, caddr_t obj_sqlval, caddr_t obj_datatype, caddr_t obj_language);
extern void tf_report (triple_feed_t *tf, char msg_type, const char *sqlstate, const char *sqlmore, const char *descr);
extern void tf_new_base (triple_feed_t *tf, caddr_t new_base);


#define TF_ONE_GRAPH_AT_TIME(tf) (NULL != (tf)->tf_cbk_names[TRIPLE_FEED_NEW_GRAPH])

#define TF_CHANGE_GRAPH(tf,new_uri) do { \
    if ((NULL != (tf)->tf_cbk_names[TRIPLE_FEED_NEW_GRAPH]) && (NULL != (tf)->tf_current_graph_uri)) \
      tf_commit ((tf)); \
    if ((tf)->tf_current_graph_uri != (tf)->tf_default_graph_uri) \
      dk_free_tree ((tf)->tf_current_graph_uri); \
    (tf)->tf_current_graph_uri = (new_uri); \
    (new_uri) = NULL; \
    if (TF_ONE_GRAPH_AT_TIME(tf)) { \
        dk_free_tree ((tf)->tf_current_graph_iid); \
        (tf)->tf_current_graph_iid = NULL; /* to avoid double free in case of error in tf_get_iid() below */ \
        (tf)->tf_current_graph_iid = tf_get_iid ((tf), (tf)->tf_current_graph_uri); \
        tf_new_graph ((tf), (tf)->tf_current_graph_uri); } \
  } while (0)

#define TF_CHANGE_GRAPH_TO_DEFAULT(tf) do { \
    if ((NULL != (tf)->tf_cbk_names[TRIPLE_FEED_NEW_GRAPH]) && (NULL != (tf)->tf_current_graph_uri)) \
      tf_commit ((tf)); \
    if ((tf)->tf_current_graph_uri != (tf)->tf_default_graph_uri) \
      dk_free_tree ((tf)->tf_current_graph_uri); \
    (tf)->tf_current_graph_uri = (tf)->tf_default_graph_uri; \
    if (NULL != (tf)->tf_cbk_names[TRIPLE_FEED_NEW_GRAPH]) { \
        dk_free_tree ((tf)->tf_current_graph_iid); \
        if (TF_ONE_GRAPH_AT_TIME(tf)) { \
            (tf)->tf_current_graph_iid = NULL; /* to avoid double free in case of error in tf_get_iid() below */ \
            (tf)->tf_default_graph_iid = tf_get_iid ((tf), (tf)->tf_default_graph_uri); } \
        (tf)->tf_current_graph_iid = box_copy ((tf)->tf_default_graph_iid); \
        tf_new_graph ((tf), (tf)->tf_current_graph_uri); } \
  } while (0)

#define TF_CHANGE_BASE_AND_DEFAULT_GRAPH(tf,new_uri) do { \
    if (NULL != (tf)->tf_cbk_names[TRIPLE_FEED_NEW_BASE]) \
      tf_new_base ((tf),(new_uri)); \
    else { \
        dk_free_box ((tf)->tf_base_uri); (tf)->tf_base_uri = (new_uri); } \
  } while (0)

#define TF_GRAPH_ARG(tf) ((TF_ONE_GRAPH_AT_TIME((tf))) ? &((tf)->tf_current_graph_iid) : &(tf->tf_current_graph_uri))

#define TTLP_STRING_MAY_CONTAIN_CRLF	0x0001	/*!< Single quoted and double quoted strings may contain newlines. */
#define TTLP_VERB_MAY_BE_BLANK		0x0002	/*!< Allows bnode predicates (but SPARQL processor may ignore them!) */
#define TTLP_ACCEPT_VARIABLES		0x0004	/*!< Allows variables, but triples with variables are ignored. */
#define TTLP_SKIP_LITERAL_SUBJECTS	0x0008	/*!< Allows literal subjects, but triples with them are ignored. */
#define TTLP_NAME_MAY_CONTAIN_PATH	0x0010	/*!< Allows '/', '#', '%' and '+' in local part of QName ("Qname with path") */
#define TTLP_ACCEPT_DIRTY_NAMES		0x0020	/*!< Allows ill bnode labels and invalid symbols between '<' and '>', i.e. in relative IRIs. */
#define TTLP_ACCEPT_DIRTY_SYNTAX	0x0040	/*!< Relax TURTLE syntax to include popular violations. */
#define TTLP_ERROR_RECOVERY		0x0080	/*!< Try to recover from lexical errors as much as it is possible. */
#define TTLP_ALLOW_TRIG			0x0100	/*!< Allows TriG syntax, thus loading data in more than one graph. */
#define TTLP_ALLOW_NQUAD		0x0200	/*!< Enables NQuads syntax but disables TURTLE and TriG */
#define TTLP_DEBUG_BNODES		0x1000	/*!< Add virtrdf:bnode-base, virtrdf:bnode-row and virtrdf:bnode-label triples for every created blank node. */
#define TTLP_SNIFFER			0x2000	/*!< Sniffer mode: scan for Turtle fragments in non-Turtle texts. */

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
  encoding_handler_t *ttlp_enc;	/*!< Encoding of the source */
  long ttlp_flags;		/*!< TTLP_xxx Flags for dirty load, enabling TriG or NQuad, debugging */
  /* lexer */
  int ttlp_lexlineno;		/*!< Current line number */
  int ttlp_lexdepth;		/*!< Current number of not-yet-closed parenthesis */
  const char *ttlp_raw_text;	/*!< Raw text of the lexem */
  ptrlong ttlp_special_qnames;	/*!< Bitmask where every bit means that the identifier is qname, not a keyword */
  /* parser */
  const char *ttlp_err_hdr;	/*!< Human-readable phrase that gives a name to the parsing routine, e.g. "Turtle parser of web crawler" */
  caddr_t ttlp_catched_error;	/*!< The error that stopped the processing, as a three-element vector made by srv_make_new_error () */
  caddr_t ttlp_default_ns_uri;	/*!< IRI associated with ':' prefix */
  id_hash_t *ttlp_namespaces_prefix2iri;	/*!< A hashtable of namespace prefixes (keys) and IRIs (values) */
  dk_set_t ttlp_saved_uris;	/*!< Stack that keeps URIs. YACC stack is not used to let us free memory on error */
  dk_set_t ttlp_unused_seq_bnodes;	/*!< A list of bnodes that were allocated for use in lists but not used because lists are terminated before use */
  caddr_t ttlp_base_uri;		/*!< Base URI used to resolve relative URIs of the document and optionally to resolve the relative URI of the graph in "graph CRUD" endpoint */
  caddr_t ttlp_last_complete_uri;	/*!< Last \c QNAME or \c Q_IRI_REF that is expanded and resolved if needed */
  caddr_t ttlp_subj_uri;	/*!< Current subject URI, but it become object URI if ttlp_pred_is_reverse */
  caddr_t ttlp_pred_uri;	/*!< Current predicate URI */
  caddr_t ttlp_obj;		/*!< Current object URI or value */
  caddr_t ttlp_obj_type;	/*!< Current object type URI */
  caddr_t ttlp_obj_lang;	/*!< Current object language mark */
  int ttlp_pred_is_reverse;	/*!< Flag if ttlp_pred_uri is used as reverse, e.g. in 'O is P of S' syntax */
  caddr_t ttlp_formula_iid;	/*!< IRI ID of the blank node of the formula ( '{ ... }' notation of N3 */
  int ttlp_in_trig_graph;	/*!< The parser is inside TriG graph so \c ttlp_inner_namespaces_prefix2iri is in use etc. */
  id_hash_t *ttlp_inner_namespaces_prefix2iri;	/*!< An equivalent of \c ttlp_namespaces_prefix2iri for prefixes defined inside TriG block */
  caddr_t ttlp_default_ns_uri_saved;	/*!< In TriG, @prefix can be used inside the graph block, in that case global \c ttlp_default_ns_uri is temporarily saved here */
  caddr_t ttlp_base_uri_saved;	/*!< In TriG, @base can be used inside the graph block, in that case global \c ttlp_base_uri is temporarily saved here */
  /* feeder */
  triple_feed_t *ttlp_tf;
} ttlp_t;


extern ttlp_t *ttlp_alloc (void);
extern void ttlp_enter_trig_group (ttlp_t *ttlp);
extern void ttlp_leave_trig_group (ttlp_t *ttlp);
extern void ttlp_reset_stacks (ttlp_t *ttlp);
extern void ttlp_free (ttlp_t *ttlp);

extern caddr_t rdf_load_turtle (
  caddr_t text_or_filename, int arg1_is_filename, caddr_t base_uri, caddr_t graph_uri, long flags,
  ccaddr_t *cbk_names, caddr_t *app_env,
  query_instance_t *qi, wcharset_t *query_charset, caddr_t *err_ret );

#ifndef YY_TYPEDEF_YY_SCANNER_T
#define YY_TYPEDEF_YY_SCANNER_T
typedef void* yyscan_t;
#endif

#define TTL_MAX_IRI_LEN 8000
#define TTL_MAX_KEYWORD_LEN 100
#define TTL_MAX_LANGNAME_LEN 64
#define TTL_MAX_LITERAL_LEN 10000000

extern int ttlyyparse (ttlp_t *ttlp_arg, yyscan_t scanner);
extern int nqyyparse (ttlp_t *ttlp_arg, yyscan_t scanner);
extern void ttlyyerror_impl (ttlp_t *ttlp_arg, const char *raw_text, const char *strg);
extern void ttlyyerror_impl_1 (ttlp_t *ttlp_arg, const char *raw_text, int yystate, short *yyssa, short *yyssp, const char *strg);

extern ptrlong ttlp_bit_of_special_qname (caddr_t qname);
extern int ttlp_qname_prefix_is_explicit_and_valid (ttlp_t *ttlp_arg, caddr_t qname);
extern caddr_t DBG_NAME (ttlp_expand_qname_prefix) (DBG_PARAMS ttlp_t *ttlp_arg, caddr_t qname);
extern caddr_t DBG_NAME (tf_bnode_iid) (DBG_PARAMS triple_feed_t *tf, caddr_t boxed_sparyytext);
extern caddr_t DBG_NAME (tf_formula_bnode_iid) (DBG_PARAMS ttlp_t *ttlp_arg, caddr_t boxed_sparyytext);
#ifdef MALLOC_DEBUG
#define ttlp_expand_qname_prefix(ttlp,qname) DBG_NAME (ttlp_expand_qname_prefix) (__FILE__, __LINE__, (ttlp), (qname))
#define tf_bnode_iid(tf, boxed_sparyytext) DBG_NAME (tf_bnode_iid) (__FILE__, __LINE__, (tf), (boxed_sparyytext))
#define tf_formula_bnode_iid(ttlp,boxed_sparyytext) DBG_NAME (tf_formula_bnode_iid) (__FILE__, __LINE__, (ttlp), (boxed_sparyytext))
#endif
extern caddr_t ttlp_uri_resolve (ttlp_t *ttlp_arg, caddr_t qname);

/* Numeric values of these constants are important, do not alter them. They are used in tricky way. */
#define TTLP_STRLITERAL_LTGT 		0x10
#define TTLP_STRLITERAL_QUOT 		0x11
#define TTLP_STRLITERAL_QUOT_AT		0x21
#define TTLP_STRLITERAL_3QUOT 		0x31
#define TTLP_STRLITERAL_3QUOT_AT	0x41
extern caddr_t ttlp_strliteral (ttlp_t *ttlp_arg, const char *sparyytext, int mode, char delimiter);
extern caddr_t ttl_lex_analyze (caddr_t str, int mode_bits, wcharset_t *query_charset);

extern void ttlp_triple_and_inf (ttlp_t *ttlp_arg, caddr_t o_uri);
extern void ttlp_triple_l_and_inf (ttlp_t *ttlp_arg, caddr_t o_sqlval, caddr_t o_dt, caddr_t o_lang);
extern void ttlp_triples_for_bnodes_debug (ttlp_t *ttlp_arg, caddr_t bnode_iid, int lineno, caddr_t label);

#define RDFXML_COMPLETE		0
#define RDFXML_OMIT_TOP_RDF	1
#define RDFXML_IN_ATTRIBUTES	2
#define RDFXML_IN_MDATA		4

extern void
rdfxml_parse (query_instance_t * qi, caddr_t text, caddr_t *err_ret,
  int mode_bits, const char *source_name, caddr_t base_uri, caddr_t graph_uri,
  ccaddr_t *stmt_texts, caddr_t *app_env,
  const char *enc, lang_handler_t *lh
   /*, caddr_t dtd_config, dtd_t **ret_dtd,
   id_hash_t **ret_id_cache, xml_ns_2dict_t *ret_ns_2dict*/ );

/* Metadata about free-text index on DB.DBA.RDF_OBJ. We're keeping two similar hashtables but one has IRI_IDs as keys and other has strings. */
extern id_hash_t *rdf_obj_ft_rules_by_iids;
extern id_hash_t *rdf_obj_ft_rules_by_iris;

extern int uriqa_dynamic_local;
extern caddr_t uriqa_get_host_for_dynamic_local (client_connection_t *qi, int * is_https);
extern caddr_t uriqa_get_default_for_connvar (query_instance_t *qi, const char *varname);
/*!< checks whether the given \c iri starts with the http://default-host , returns zero if not or number of leading chars to cut the local part. */
extern int uriqa_iri_is_local (query_instance_t *qi, const char *iri);

#define RDF_GRAPH_PERM_READ 0x01
#define RDF_GRAPH_PERM_WRITE 0x02
#define RDF_GRAPH_PERM_SPONGE 0x04
#define RDF_GRAPH_PERM_LIST 0x08
#define RDF_GRAPH_PERM_DEFAULT (RDF_GRAPH_PERM_READ | RDF_GRAPH_PERM_WRITE | RDF_GRAPH_PERM_SPONGE | RDF_GRAPH_PERM_LIST)

extern id_hash_t *rdf_graph_iri2id_dict_htable;		/*!< Dictionary of IRI_IDs of IRIs of graphs mentioned in graph-level security config, IRI UNAMEs are keys, boxed IRI_IDs are values */
extern id_hash_iterator_t *rdf_graph_iri2id_dict_hit;	/*!< Hash iterator for \c rdf_graph_iri2id_dict_hit */
extern id_hash_t *rdf_graph_id2iri_dict_htable;		/*!< Dictionary of IRIs of IRI_IDs of graphs mentioned in graph-level security config, boxed IRI_IDs are keys, IRI UNAMEs are values */
extern id_hash_iterator_t *rdf_graph_id2iri_dict_hit;	/*!< Hash iterator for \c rdf_graph_id2irid_dict_hit */
extern id_hash_t *rdf_graph_group_dict_htable;		/*!< Dictionary of graph group members: group IID is key, vector or hashtable of member IIDs is value */
extern id_hash_iterator_t *rdf_graph_group_dict_hit;	/*!< Hash iterator for \c rdf_graph_group_dict_htable */
extern id_hash_t *rdf_graph_public_perms_dict_htable;		/*!< Dictionary of public permissions for graphs: graph/group IID is key, copy of DB.DBA.RDF_GRAPH_USER.RGU_PERMISSIONS is a value */
extern id_hash_iterator_t *rdf_graph_public_perms_dict_hit;	/*!< Hash iterator for \c rdf_graph_group_dict_htable */
extern id_hash_t *rdf_graph_group_of_privates_dict_htable;		/*!< Dictionary of private graphs, to accelerate the access to content of virtrdf:PrivateGraphs */
extern id_hash_iterator_t *rdf_graph__of_privates_dict_hit;	/*!< Hash iterator for \c rdf_graph_group_of_privates_dict_htable */
extern id_hash_t *rdf_graph_default_world_perms_of_user_dict_htable;		/*!< Dictionary of default permissions for users: user ID is key, copy of DB.DBA.RDF_GRAPH_USER.RGU_PERMISSIONS for #0 is a value */
extern id_hash_iterator_t *rdf_graph_default_world_perms_of_user_dict_hit;	/*!< Hash iterator for \c rdf_graph_default_world_perms_of_user_dict_htable */
extern id_hash_t *rdf_graph_default_private_perms_of_user_dict_htable;		/*!< Dictionary of default permissions for users: user ID is key, copy of DB.DBA.RDF_GRAPH_USER.RGU_PERMISSIONS for #0 is a value */
extern id_hash_iterator_t *rdf_graph_default_private_perms_of_user_dict_hit;	/*!< Hash iterator for \c rdf_graph_default_private_perms_of_user_dict_htable */
extern id_hash_t *rdf_graph_default_private_perms_of_user_dict_htable;		/*!< Dictionary of default permissions for users: user ID is key, copy of DB.DBA.RDF_GRAPH_USER.RGU_PERMISSIONS for #0 is a value */
extern id_hash_iterator_t *rdf_graph_default_private_perms_of_user_dict_hit;	/*!< Hash iterator for \c rdf_graph_default_private_perms_of_user_dict_htable */

extern caddr_t boxed_zero_iid;
extern caddr_t boxed_one_iid;
extern caddr_t boxed_nobody_uid;

caddr_t iri_ensure (caddr_t * qst, caddr_t name, int flag, caddr_t * err_ret);
void rdf_graph_keyword (iri_id_t id, char *ret);
extern caddr_t uriqa_dynamic_local_replace_nocheck (caddr_t name, client_connection_t * cli);
#define uriqa_dynamic_local_replace(name, cli) \
  (strncmp ((name), "local:", 6) ? (name) : uriqa_dynamic_local_replace_nocheck ((name), (cli)))

/* if rb content longer than this, use md5 in rdf_obj table key */
#define RB_BOX_HASH_MIN_LEN 50


#endif
