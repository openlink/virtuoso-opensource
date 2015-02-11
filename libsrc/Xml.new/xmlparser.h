/*
 *  xmlparser.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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

#ifndef _XML_PARSER_H
#define _XML_PARSER_H

#include <stddef.h>
#include "Dk.h"
#include "langfunc.h"

struct vxml_parser_s;
typedef struct vxml_parser_s vxml_parser_t;

/*				 0         1         2         3   */
/*				 012345678901234567890123456789012 */
#define XMLSCHEMA_NS_URI	"http://www.w3.org/2001/XMLSchema"
#define XMLSCHEMA_NS_URI_LEN	32
/*				 0         1         2         3         4    */
/*				 01234567890123456789012345678901234567890123 */
#define RDF_NS_URI		"http://www.w3.org/1999/02/22-rdf-syntax-ns#"
#define RDF_NS_URI_LEN		43
/*				 0         1         2         3       */
/*				 0123456789012345678901234567890123456 */
#define XML_NS_URI		"http://www.w3.org/XML/1998/namespace"
#define XML_NS_URI_LEN		36
/*				 0         1         2         3         4 */
/*				 01234567890123456789012345678901234567890 */
#define MSSQL_NS_URI		"urn:schemas-microsoft-com:mapping-schema"
#define MSSQL_NS_URI_LEN	40
/*				 0         1         2         3         4  */
/*				 012345678901234567890123456789012345678901 */
#define XMLSCHEMA_INSTANCE_URI	"http://www.w3.org/2001/XMLSchema-instance"
#define XMLSCHEMA_INSTANCE_URI_LEN  41


#ifndef UNICHAR_DEFINED
#define UNICHAR_DEFINED
typedef int /* or int32 ??? */ unichar;	/* 31-bit unicode values, negative ones are invalid */
#endif

typedef int s_size_t;	/* type for length of text, signed */

#ifndef DTD_T_DECLARED
#define DTD_T_DECLARED
typedef struct dtd_s dtd_t;
extern void dtd_addref (dtd_t *dtd, int make_global);
extern int dtd_release (dtd_t *dtd);
#endif

/* Cloned from Dk/Dkhashext.h */
#ifndef LENMEM_T_DEFINED
#define LENMEM_T_DEFINED
typedef struct struct lenmem_s
{
  size_t		lm_length;
  char *		lm_memblock;
} lenmem_t;
#endif

struct xml_pos_s {
  int			line_num;	/*!< current line number */
  int			col_b_num;	/*!< current column byte offset */
  int			col_c_num;	/*!< current column char offset */
  const char *		origin_uri;	/*<! URI where visible data of this brick comes from or NULL for main text. xml_pos_s is not owner of this string */
  struct xml_def_4_entity_s *	origin_ent;	/*<! Entity where visible data of this brick comes from or NULL for main text. xml_pos_s is not owner of this def. */
};
typedef struct xml_pos_s xml_pos_t;

#ifdef DEBUG
#define xml_pos_set(dst,src) \
  do { \
    if ((NULL != (src)->origin_uri) && (DV_STRING != DV_TYPE_OF ((src)->origin_uri)) && (DV_UNAME != DV_TYPE_OF ((src)->origin_uri))) \
      GPF_T; \
    memcpy ((dst), (src), sizeof (xml_pos_t)); \
    } while (0)
#else
#define xml_pos_set(dst,src) \
  memcpy ((dst), (src), sizeof (xml_pos_t))
#endif

struct xml_def_4_notation_s {
  char * xd4n_publicId; /*!< PUBLIC value, pub-literal (i.e. restricted charset), may be NULL */
  char * xd4n_systemId; /*!< SYSTEM value, sys-literal (i.e. any chars may occur), may be NULL */
  };
typedef struct xml_def_4_notation_s xml_def_4_notation_t;

struct xml_def_4_entity_s {
  caddr_t xd4e_literalVal;	/*!< Literal value, may be NULL */
  caddr_t xd4e_publicId;	/*!< PUBLIC value, pub-literal (i.e. restricted charset), may be NULL */
  caddr_t xd4e_systemId;	/*!< SYSTEM value, sys-literal (i.e. any chars may occur), may be NULL */
  caddr_t xd4e_notationName;	/*!< NDATA name, known NOTATION name expected */
  lenmem_t xd4e_repl;		/*!< Replacement text, entity is not its owner */
  xml_pos_t xd4e_defn_pos;	/*!< Position of the entity's definition */
  xml_pos_t xd4e_val_pos;	/*!< Position of the entity's value */
  int xd4e_may_be_in_mkup;	/*!< True if PE matches [  VC: Proper Declaration/PE Nesting ], i.e. \<...\> balance */
  int xd4e_may_be_in_ecm;	/*!< True if PE matches [  VC: Proper Group/PE Nesting ], i.e. (...) balance */
  int xd4e_may_be_in_cond;	/*!< True if PE matches [  VC: Proper Conditional Section/PE Nesting ], i.e. \<[...\]]> balance */
  int xd4e_valid;		/*!< True if entity does not contain recursive references */
  };
typedef struct xml_def_4_entity_s xml_def_4_entity_t;


typedef struct opened_tag_s {
  lenmem_t			ot_name;
  struct html_tag_descr_s	* ot_descr;
  xml_pos_t			ot_pos;
} opened_tag_t;

#define XML_PARSER_MAX_DEPTH 0x800

typedef struct nsdecl_s {
  caddr_t		nsd_prefix;
  caddr_t		nsd_uri;
  opened_tag_t *	nsd_tag;
} nsdecl_t;

#define XML_PARSER_MAX_NSDECLS 0x80

typedef struct tag_attr_s {
  /* nsdecl_t *		ns; */
  lenmem_t		ta_raw_name;
  caddr_t		ta_value;
} tag_attr_t;

#define XML_PARSER_MAX_ATTRS 0x100

typedef struct xml_name_assoc_s {
  caddr_t xna_key;
  caddr_t xna_value;
} xml_name_assoc_t;

typedef struct xml_ns_2dict_s {
  xml_name_assoc_t *	xn2_prefix2uri;
  xml_name_assoc_t *	xn2_uri2prefix;
  ptrlong		xn2_size;
} xml_ns_2dict_t;

#define xml_ns_2dict_clean(ns_2dict) \
do { \
  if ((ns_2dict)->xn2_size) \
    { \
      box_tag_modify ((ns_2dict)->xn2_prefix2uri, DV_ARRAY_OF_POINTER); \
      dk_check_tree ((ns_2dict)->xn2_prefix2uri); \
      dk_check_tree ((ns_2dict)->xn2_uri2prefix); \
      dk_free_tree ((box_t) (ns_2dict)->xn2_prefix2uri); \
      dk_free_box ((box_t) (ns_2dict)->xn2_uri2prefix); \
      (ns_2dict)->xn2_prefix2uri = NULL; \
      (ns_2dict)->xn2_uri2prefix = NULL; \
      (ns_2dict)->xn2_size = 0; \
    } \
 } while (0)

typedef struct vxml_parser_attrdata_s {
  tag_attr_t *local_attrs;	/*!< Attributes of the local tag */
  size_t local_attrs_count;	/*!< Number of used element in \c local_attrs array */
  nsdecl_t *local_nsdecls;	/*!< Namespace declarations made in the current opening tag */
  size_t local_nsdecls_count;	/*!< Number of used element in \c local_nsdecls array */
  nsdecl_t *all_nsdecls;	/*!< All namespace declarations in all ancestor-or-self tags, as a stack. It may contain duplicates so always search from end to begin */
  size_t all_nsdecls_count;	/*!< Number of used element in \c all_nsdecls array */
} vxml_parser_attrdata_t;

typedef void (*VXmlStartElementHandler)
     (void *userData,
      const char * name,
      vxml_parser_attrdata_t *attrdata);

typedef void (*VXmlEndElementHandler)
     (void *userData,
      const char * name);

typedef void (*VXmlIdHandler)
     (void *userData,
      const char * name);

/* s is not 0 terminated. */
typedef void (*VXmlCharacterDataHandler)
     (void *userData,
      const char * s,
      size_t len);

/* target and data are 0 terminated */
typedef void (*VXmlProcessingInstructionHandler)
     (void *userData,
      const char * target,
      const char * data);

/* data is 0 terminated */
  typedef void (*VXmlCommentHandler) (void *userData, const char * text);

/* IvAn/ParseDTD/000721
   Arg1 - e.g., vxml_parser_t,
   Arg2,3 - reference name (pointer to and length of text),
   Arg4 - flag if reference is global
   Arg5 - definition of the reference */
  typedef void (*VXmlEntityRefHandler) (void *userData, const char *refname, size_t reflen, int isparam, const xml_def_4_entity_t *edef);
/* IvAn/ParseDTD/000721 **/

  typedef void (*VXmlDtdHandler) (void *userData, dtd_t *doc_dtd);

  typedef encoding_handler_t * (*VXmlFindUserEncoding) (const char *encname, int xml_input_is_wide);

  typedef char *(*VXmlUriResolver) (void *uri_appdata, char **err_ret, ccaddr_t base_uri, ccaddr_t rel_uri, const char *output_charset);
  typedef char *(*VXmlUriReader) (void *uri_appdata, char **err_ret, char **options, ccaddr_t base_uri, ccaddr_t rel_uri, int cast_blob_to_varchar);
  typedef void (*VXmlErrorReporter) (const char *state, const char *format, ...);

  typedef void *(*VXmlAttrParser) (void *userData, const char *elname, const char *attrname, const char *attrvalue);
  
extern void *xmlap_qname (void *userData, const char *elname, const char *attrname, const char *attrvalue);
extern void *xmlap_xpath (void *userData, const char *elname, const char *attrname, const char *attrvalue);
  

typedef enum xml_enc_flag {
  XML_EF_NONE,
  XML_EF_DEFAULT,
  XML_EF_SUGGEST,
  XML_EF_FORCE
} xml_enc_flag_t;

#define FINE_XML	0
#define FINE_HTML	1
#define DEAD_HTML	2
#define GE_XML		0x10	/* May be passed to the parser */
#define WEBIMPORT_HTML	0x40	/* Not for passing to the parser */
#define FINE_XSLT	0x80	/* Not for passing to the parser */
#define FINE_XML_SRCPOS	0x100	/* Not for passing to the parser */

typedef size_t (*xml_read_func_t) (void * read_cd, char * buf, size_t bsize);
typedef void (*xml_read_abend_func_t) (void * read_cd);

#define XML_SOURCE_TYPE_TEXT		0	/*!< Plain default input from text representation */
#define XML_SOURCE_TYPE_XTREE_DOC	1	/*!< Special handling of attributes (they're expanded already) */

/* Memory pointed by members of this structure is owned by caller of
   VXmlParserCreate. This memory should not be freed until Xml_ParserDestroy */
struct vxml_parser_config_s
{
  int				input_is_wide;		/*!< Flags if XML input (to be parsed) is wchar_t, not plain character data */
  int				input_is_ge;		/*!< Flags if input is Generic Entity, not a complete document. */
  int				input_is_html;		/*!< Flags if input is HTML, not XML */
  int				input_is_xslt;		/*!< Flags if input is XSLT and should be handled in a special way */
  int				input_source_type;	/*!< Type of input (XML_SOURCE_TYPE_TEXT is default) */
  const char *			initial_src_enc_name;
  VXmlFindUserEncoding		user_encoding_handler;
  const char *			uri;			/*!< URI of the document, and base for relative URIs */
  VXmlUriResolver		uri_resolver;
  VXmlUriReader			uri_reader;
  VXmlErrorReporter		error_reporter;
  void *			uri_appdata;		/*!< Application-specific data for \c uri_resolver and \c uri_reader callbacks */
  caddr_t *			log_ret;		/*!< Application-specific data for \c error_reporter */
  caddr_t			dtd_config;
  lang_handler_t *		root_lang_handler;
  int				validation_mode;	/*!< XML_DTD (default) or XML_SCHEMA */
  int				auto_load_xmlschema_dtd;	/*!< 0 or 1 */
  caddr_t			auto_load_xmlschema_dtd_p;	/*!< xmlschema namespace prefix */
  caddr_t			auto_load_xmlschema_dtd_s;	/*!< xmlschema namespace suffix */
  caddr_t			auto_load_xmlschema_uri;	/*!< uri of the schema that is requested by parser caller */
  int				dc_namespaces;		/*!< Enforced fixed value for parser's dc_namespaces, dtd config will not override */
  int				feed_buf_size;		/*!< If nonzero then the size of the buffer for text input. */
};

typedef struct vxml_parser_config_s vxml_parser_config_t;

vxml_parser_t * VXmlParserCreate (vxml_parser_config_t *config);

void VXmlParserDestroy (vxml_parser_t * parser);
int VXmlParse (vxml_parser_t * parser, char * data, s_size_t size);
/*void VXmlParsePosition (vxml_parser_t * parser, size_t * start_pos, size_t * end_pos);*/

extern void VXmlSetElementHandler (vxml_parser_t * parser, VXmlStartElementHandler sh, VXmlEndElementHandler eh);
extern void VXmlSetIdHandler (vxml_parser_t * parser, VXmlIdHandler h);
extern void VXmlSetCommentHandler (vxml_parser_t * parser, VXmlCommentHandler h); /* IvAn/ParseDTD/999721 */
extern void VXmlSetProcessingInstructionHandler (vxml_parser_t * parser, VXmlProcessingInstructionHandler h); /* IvAn/ParseDTD/999721 */
extern void VXmlSetCharacterDataHandler (vxml_parser_t * parser, VXmlCharacterDataHandler h);

int VXmlGetCurrentLineNumber (vxml_parser_t * parser);
int VXmlGetOuterLineNumber (vxml_parser_t * parser);
int VXmlGetCurrentColumnNumber (vxml_parser_t * parser);
int VXmlGetCurrentByteNumber (vxml_parser_t * parser);
const char *VXmlGetCurrentFileName (vxml_parser_t * parser);
const char *VXmlGetOuterFileName (vxml_parser_t * parser);
void VXmlSetEntityRefHandler (vxml_parser_t * parser, VXmlEntityRefHandler h);
caddr_t VXmlErrorContext(vxml_parser_t * parser);
char *VXmlErrorContext2(char* buffer, vxml_parser_t * parser);
caddr_t VXmlValidationLog (vxml_parser_t * parser);
caddr_t VXmlFullErrorMessage (vxml_parser_t * parser);
extern ccaddr_t VXmlFindNamespaceUriByPrefix (vxml_parser_t * parser, ccaddr_t prefix);
extern ccaddr_t VXmlFindNamespacePrefixByUri (vxml_parser_t * parser, ccaddr_t uri);
extern void VXmlFindNamespaceUriByQName (vxml_parser_t * parser, const char *qname, int is_attr, lenmem_t *uri_ret);
extern caddr_t DBG_NAME(VXmlFindExpandedNameByQName) (DBG_PARAMS vxml_parser_t * parser, const char *qname, int is_attr);
#ifdef MALLOC_DEBUG
#define VXmlFindExpandedNameByQName(p,q,a) dbg_VXmlFindExpandedNameByQName (__FILE__, __LINE__, (p), (q), (a))
#endif
extern int VXmlExpandedNameEqualsQName (vxml_parser_t * parser, const char * expanded_name,
				 const char * qname, int is_attr);


/*!
 * valid values for force:
 * XML_EF_NONE - ignore the call - try to find proper encoding without any help
 * XML_EF_DEFAULT - set entity encoding and than try to find it from XML declaration
 * XML_EF_SUGGEST - same as above, except use suggested encoding if encoding in XML
 *		    declaration is unknown
 * XML_EF_FORCE - set encoding and ignore XML declaration
 */
void VXmlSetUserData (vxml_parser_t * parser, void * ptr);
void VXmlParserInput (vxml_parser_t * parser, xml_read_func_t f, void * read_cd);

const xml_def_4_notation_t *VXmlGetNotation(vxml_parser_t * parser, const char *refname);
const xml_def_4_entity_t *VXmlGetParameterEntity(vxml_parser_t * parser, const char *refname);
const xml_def_4_entity_t *VXmlGetGenericEntity(vxml_parser_t * parser, const char *refname);

void VXmlSetFindUserEncoding (vxml_parser_t * parser, VXmlFindUserEncoding find);


#define XML_DTD	    0	/* BTW zero value means 'default' */
#define XML_SCHEMA  1

extern dtd_t *VXmlGetDtd (vxml_parser_t * parser);

/*** BEG RUS/Schema Thu Mar 22 19:00:19 2001 ***/
extern void xml_schema_init (void);
extern void VXmlAddSchemaDeclarationCallbacks (vxml_parser_t * parser);
/*** END RUS/Schema Thu Mar 22 19:00:22 2001 ***/

extern caddr_t xml_add_system_path (caddr_t path_uri);
struct xml_iter_syspath_s* xml_iter_system_path (void);
extern void xml_free_iter_system_path(struct xml_iter_syspath_s*);
extern caddr_t xml_iter_syspath_hitnext(struct xml_iter_syspath_s*);
extern ptrlong xml_iter_syspath_length(struct xml_iter_syspath_s*);

extern void html_hash_init (void);

struct query_instance_s;
extern caddr_t xml_uri_resolve (struct query_instance_s * qi, caddr_t *err_ret, ccaddr_t base_uri, ccaddr_t rel_uri, const char *output_charset);
extern caddr_t xml_uri_resolve_like_get (struct query_instance_s * qi, caddr_t *err_ret, ccaddr_t base_uri, ccaddr_t rel_uri, const char *output_charset);

#define XML_URI_ANY 0
#define XML_URI_STRING 1
#define XML_URI_STRING_OR_ENT 2
extern caddr_t xml_uri_get (struct query_instance_s * qi, caddr_t *err_ret, caddr_t *options, ccaddr_t base_uri, ccaddr_t rel_uri, int mode);

/* These are from sqlbif2.c */

typedef struct rdf1808_split_s {
  ptrlong schema_begin;		/*!< schema without ':' */
  ptrlong schema_end;
  ptrlong netloc_begin;		/*!< network location/login without '/' */
  ptrlong netloc_end;
  ptrlong path_begin;		/*!< path with starting '/' */
  ptrlong path_end;
  ptrlong params_begin;		/*!< parameters without starting ';' */
  ptrlong params_end;
  ptrlong query_begin;		/*!< query without starting '?' */
  ptrlong query_end;
  ptrlong fragment_begin;	/*!< fragment without starting '#' */
  ptrlong fragment_end;
  ptrlong two_slashes;		/*!< position of end of two slashes, zero if missing */
} rdf1808_split_t;

#ifndef NDEBUG
#define CHECK_RDF1808_SPLIT(split,uri_len) \
  if ((0 != split.schema_begin) || \
    (split.schema_begin > split.schema_end) || \
    (split.schema_end > split.netloc_begin) || \
    (split.netloc_begin > split.netloc_end) || \
    (split.netloc_end > split.path_begin) || \
    (split.path_begin > split.path_end) || \
    (split.path_end > split.params_begin) || \
    (split.params_begin > split.params_end) || \
    (split.params_end > split.query_begin) || \
    (split.query_begin > split.query_end) || \
    (split.query_end > split.fragment_begin) || \
    (split.fragment_begin > split.fragment_end) || \
    (split.fragment_end > (uri_len)) ) \
    GPF_T1("CHECK_RDF1808_SPLIT failed");
#else
#define CHECK_RDF1808_SPLIT(split,uri_len)
#endif

extern void rfc1808_parse_uri (const char *iri, rdf1808_split_t *split_ret);
extern void rfc1808_parse_wide_uri (const wchar_t *iri, rdf1808_split_t *split_ret);
extern caddr_t rfc1808_expand_uri (ccaddr_t base_uri, ccaddr_t rel_uri,
  ccaddr_t output_cs_name, int do_resolve_like_http_get,
  ccaddr_t base_string_cs_name, /* Encoding used for base_uri IFF it is a narrow string, neither DV_UNAME nor WIDE */
  ccaddr_t rel_string_cs_name, /* Encoding used for rel_uri IFF it is a narrow string, neither DV_UNAME nor WIDE */
  caddr_t * err_ret );

#endif /* _XML_PARSER_H */

