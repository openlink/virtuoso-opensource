/*
 *  xmlparser_impl.h
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

#ifndef _XML_PARSER_IMPL_H
#define _XML_PARSER_IMPL_H

#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>

#include "Dk.h"
#include "xmlparser.h"
#include "xml_ecm.h"
#include "charclasses.h"
#include "schema.h"

/*#define UNIT_DEBUG 0*/

#ifndef UNIT_DEBUG
#include "libutil.h"
#else
#define dk_alloc(sz)		malloc (sz)
#define dk_free(ptr, sz)	free (ptr)
#endif

#include "xmlparser.h"

#include "charclasses.h"
/*#include "encodings.h"*/
#include "html_mode.h"

/* Types of errors (severity levels) */
#define XCFG_FATAL	0	/*!< Fatal error, which will abort processing immediately */
#define XCFG_ERROR	1	/*!< Error, which will abort processing after check completion */
#define XCFG_WARNING	2	/*!< Warning, which will not abort processing */
#define XCFG_DETAILS	3	/*!< Special value to mark details of previous value */
#define XCFG_OK		4	/*!< Success confirmation  */
#define XCFG_ERRLEVELS	5	/*!< Total number of error levels */

#define XCFG_NOLOGPLACE 0x10	/*!< Bit that prevents automatic calling xmlparser_log_place when reporting message */

/* If violation should be reported, error level is used as ID of action */
#define XCFG_IGNORE	5	/*!< Do processing quietly, do not report nonfatal errors */
#define XCFG_DISABLE	6	/*!< Disable some sort of processing fully */
#define XCFG_ENABLE	7	/*!< Enable some sort of processing fully */
#define XCFG_QUICK	7	/*!< Process DTD to report those serious errors which are easy to find */
#define XCFG_RIGOROUS	8	/*!< Process DTD to report all violations of validity constrains */
#define XCFG_SGML	9	/*!< Full check of DTD plus checks for SGML compatibility */

#define DTD_IN_UNSPEC	0
#define DTD_IN_ISUNREAD	1
#define DTD_IN_ISREAD	2

#define BRICK_SIZE	4076

#define PM(member) (parser->member)

#define LIST_INC 32
#define MAX_ENTITY_NESTING_DEPTH 5  /*!< Entities can not be stedted deeper than this limit */

#define MAX_CONTEXT_LEFT 70
#define MAX_CONTEXT_ALL (MAX_CONTEXT_LEFT+8)
#define CONTEXT_BUF_LENGTH (MAX_CONTEXT_LEFT*2+MAX_CONTEXT_ALL+10)

#define RET_ERRMSG(msg) { xmlparser_logprintf (parser, XCFG_ERROR, 100, (msg)); return 0; }

typedef enum xml_tok_type {
XML_TOK_FINISH,
XML_TOK_ERROR,
XML_TOK_INVALID,
XML_TOK_WS,
XML_TOK_CHAR_DATA,
XML_TOK_START_TAG,
XML_TOK_END_TAG,
XML_TOK_EMPTY_TAG,
XML_TOK_ENTITY_REF,
XML_TOK_COMMENT,
XML_TOK_CDATA,
XML_TOK_PI,
XML_TOK_DTD
} xml_tok_type_t;

typedef int XML_PARSER_STATE;
#define XML_A_XMLDECL	1
#define XML_A_DTD	2
#define XML_A_SPACE	4
#define XML_A_COMMENT	8
#define XML_A_PI	16
#define XML_A_ELEMENT	32
#define XML_A_CHAR	64

#define XML_ST_NOT_EMPTY	128


#define XML_A_MISC	XML_A_COMMENT | XML_A_PI | XML_A_SPACE
#define XML_A_PROLOG	XML_A_XMLDECL | XML_A_DTD | XML_A_MISC

#define  XML_ST_INITIAL XML_A_PROLOG | XML_A_ELEMENT

#define CLR_STATE(x) do { parser->state &= ~(x); } while (0)
#define SET_STATE(x) do { parser->state |=  (x); } while (0)

/*! Brick is a descriptor of data source.
It can own some data under \c data_begin, and other bricks may reference to it.
To count uses of brick's data buffer, \c data_refctr is used.
Pointers \c beg and \c end delimits visible area in some buffer. */
struct brick_s {
  utf8char *		end;		/*<! Pointer past last byte of visible part of data. Should be the first field, for efficiency */
  utf8char *		beg;		/*<! Pointer to the first byte of visible part of data */
  struct brick_s *	next;		/*<! Pointer to the next brick in the chain. */
  struct brick_s *	prev;		/*<! Pointer to previous brick in the chain. */
  caddr_t		data_begin;	/*<! Pointer to data, owned by this brick, if brick owns some data at all */
  int			data_refctr;	/*<! Counter of external references to buffer under data_begin */
  struct brick_s *	data_owner;	/*<! Owner of data which are in memory from \c beg to \c end */
  xml_pos_t		beg_pos;	/*<! Position of beg[0] char in the source */
};

typedef struct brick_s brick_t;

struct buf_ptr_s {
  utf8char	* ptr;
  brick_t	* buf;
};

typedef struct buf_ptr_s buf_ptr_t;

struct buf_range_s {
  buf_ptr_t	beg;
  buf_ptr_t	end;
};

typedef struct buf_range_s buf_range_t;

struct vxml_parser_handlers_s
{
  void			* user_data;
  VXmlCharacterDataHandler		char_data_handler;
  VXmlStartElementHandler		start_element_handler;
  VXmlEndElementHandler			end_element_handler;
  VXmlIdHandler				id_handler;
  VXmlCommentHandler			comment_handler;
  VXmlProcessingInstructionHandler	pi_handler;
  VXmlEntityRefHandler			entity_ref_handler;
/*
  VXmlDtdHandler			dtd_handler;
*/
};

typedef struct vxml_parser_handlers_s vxml_parser_handlers_t;


typedef struct lenmem_list_elem_s {
  struct lenmem_list_elem_s	* next;
  lenmem_t	name;
} lenmem_list_elem_t, * lenmem_list_t;


#define XML_MAX_DOC_COST 0x3FFFffff
#define XML_BIG_DOC_COST 0x03FFffff
#define XML_XPER_DOC_WEIGHT 1000		/*!< Weight is in 16-bytes units */


struct vxml_parser_s {
  char *		static_src;		/*!< The source text to be parsed, this is the whole text if there's no feed, otherwise, it's a begginning only */
  char *		static_src_tail;	/*!< Unparsed rest of source text to be parsed */
  char *		static_src_end;		/*!< End of source text to be parsed */
  vxml_parser_config_t	cfg;
  encoding_handler_t	* src_eh;		/*!< (currenlty known) encoding of the input text */
  struct
    {
      int		byteorder;
      char		exact_mark;
      char		code_length;
      char		ucs4;
      char		utf16;
      char		utf8;
      char		ebcdic;
    } bom;
  int			src_eh_state;		/*!< State stored for stateful encodings, must be reset to 0 on any change of the encoding */

  xml_enc_flag_t	enc_flag;

  struct id_hash_s * includes;		/*!< Hash table of all texts included via URIs of entities */
  struct id_hash_s * ids;		/*!< Hash table of all ids */

  buf_ptr_t		bptr;		/*!< data begin */
  buf_ptr_t		eptr;		/*!< data end */
  buf_ptr_t		pptr;		/*!< it points past last parsed byte */

  char			* feed_buf;		/*!< buffer for getting new data */
  int			feed_buf_size;		/*!< Allocated size of \c feed_buf */
  char			* feed_tail;		/*!< untranslated tail of \c feed_buf */
  char			* feed_end;		/*!< end of data in \c feed_buf */
  unichar		* uni_buf;		/*!< buffer for data in unicode */
  unichar		* uni_tail;		/*!< tail of \c uni_tail */
  unichar		* uni_end;		/*!< end of \c uni_tail */

  xml_read_func_t	feeder;
  void			* read_cd;

  XML_PARSER_STATE	state;		/*!< state of parser */

  struct {
    buf_range_t		name;
    buf_range_t		string;
    buf_range_t		value;
    lenmem_list_t	enum_of_values;
    tag_attr_t		attr_array[XML_PARSER_MAX_ATTRS];
    ptrlong		att_type;
    char		* dtd_puburi;
    char		* dtd_sysuri;
    int			dtd_loaded_from_uri;
#if 0
    ptrlong		* tag_index;
#endif
    html_tag_descr_t	* tag_descr;
    lenmem_t		flat_name;
  }			tmp;
  vxml_parser_attrdata_t attrdata;

  xml_pos_t		curr_pos;	/*!< current position in source text of document (main or included) */
  buf_ptr_t		curr_pos_ptr;   /*!< Place in current buffer where curr_pos has measured */
  xml_pos_t		last_main_pos;	/*!< Last reached position in main source text */
  int			entity_nesting;	/*!< Nesting of entities in text of names of other entities */

  vxml_parser_handlers_t masters;	/*!< top level callbacks */
  vxml_parser_handlers_t slaves;		/*!< lower level of callbacks */

  dtd_validator_t	validator;
  schema_processor_t	processor;

  opened_tag_t		tag_stack_holder[XML_PARSER_MAX_DEPTH];
  opened_tag_t *	inner_tag;
  nsdecl_t		nsdecl_array[XML_PARSER_MAX_NSDECLS];
  ptrlong		fill_ns_2dict;
  xml_ns_2dict_t 	ns_2dict;
  dk_set_t		msglog;				/*!< Log of all messages */
  ptrlong		msglog_ctrs[XCFG_ERRLEVELS];	/*!< Numbers of messages grouped by error levels */
  /* xml logging, later it will substitute usual log throw xslt */
  /* caddr_t*		msglog_as_xml; */

#ifdef DEBUG
  int			last_err_detector;
#endif
  ptrlong		obj_serial; /*!< A growing counter for various objects. */
  ptrlong		input_cost; /*!< Total cost of input */
  ptrlong		input_weight; /*!< Total weight of input in 16-byte units */
};

extern encoding_handler_t *find_encoding (vxml_parser_t *parser, char * enc_name);

#ifdef DEBUG
extern int names_are_equal (lenmem_t * sname, char * name);
#endif
extern xml_tok_type_t get_token (vxml_parser_t * parser);
extern void advance_ptr (vxml_parser_t * parser);
extern unichar get_one_xml_char (vxml_parser_t * parser);
extern unichar get_tok_char (vxml_parser_t * parser);

extern void push_tag (vxml_parser_t * parser);
extern int pop_tag (vxml_parser_t * parser);
extern void add_attribute (vxml_parser_t * parser, buf_range_t * name, buf_range_t * value);
extern void free_attr_array (vxml_parser_t * parser);
extern void convert_attr_array (vxml_parser_t * parser);

extern void DBG_NAME(brcpy) (DBG_PARAMS lenmem_t * to, buf_range_t * from);
extern caddr_t DBG_NAME(box_brcpy) (DBG_PARAMS buf_range_t * from);

#ifdef MALLOC_DEBUG
#define brcpy(to,from) dbg_brcpy(__FILE__, __LINE__, (to), (from))
#define box_brcpy(from) dbg_box_brcpy(__FILE__, __LINE__, (from))
#endif

/* Rus/ DTD Validation Functions  */
extern void dtd_start_element_handler (struct vxml_parser_s* parser,
			   const char * name,
			   vxml_parser_attrdata_t *attrdata );

extern void dtd_end_element_handler (struct vxml_parser_s* parser,
			 const char * name);
extern void dtd_char_data_handler (struct vxml_parser_s* parser,
			   const char * s,
			   int len);
extern void dtd_pi_handler (struct vxml_parser_s* parser,
	     const char * target,
	     const char * data);
extern void dtd_comment_handler (struct vxml_parser_s* parser,  const char * text);
extern void dtd_start_cdata_section_handler (struct vxml_parser_s* parser);
extern void dtd_end_cdata_section_handler (struct vxml_parser_s* parser);
extern void dtd_unparsed_entity_decl_handler (struct vxml_parser_s* parser,
			  const char * entityName,
			  const char * base,
			  const char * systemId,
			  const char * publicId,
			  const char * notationName);
extern void dtd_notation_decl_handler (struct vxml_parser_s* parser,
		   const char * notationName,
		   const char * base,
		   const char * systemId,
		   const char * publicId);
extern void dtd_start_namespace_decl_handler (struct vxml_parser_s* parser,
			  const char * prefix,
			  const char * uri);
extern void dtd_end_namespace_decl_handler (struct vxml_parser_s* parser,
			const char * prefix);
extern void dtd_default_handler (struct vxml_parser_s* parser,
		  const char * s,
		  int len);

extern void dtd_entity_ref_handler (struct vxml_parser_s* parser,
		     const char *refname,
		     int reflen,
		     int isparam,
		     const xml_def_4_entity_t *edef);
/*
extern void dtd_dtd_handler (struct vxml_parser_s* parser,
		     struct dtd_s *doc_dtd);
*/

void
normalize_value (lenmem_t * lsp);

/* Functions that in common use for dtd.c and xmlread.c */
extern int test_ws (struct vxml_parser_s * parser);
extern int get_att_name (struct vxml_parser_s * parser);
extern int test_char_int (struct vxml_parser_s * parser, unichar ch);
#define test_char(parser,ch) \
  (((0 != parser->src_eh->eh_stable_ascii7) && \
    (parser->pptr.ptr == (parser->eptr.ptr-1)) && \
    (parser->pptr.ptr[0] != ch) && \
    (parser->pptr.buf == (parser->eptr.buf)) && \
    (parser->pptr.ptr[0] != '%') ) ? \
   0 : test_char_int (parser, ch) )

extern char* get_encoded_name (struct vxml_parser_s* parser, unichar* beg, unichar* end,
			   char** name, dtd_validator_t* validator);
extern int dtd_get_att_type (struct vxml_parser_s* parser,
			     ecm_el_t* elem, ptrlong attr_index,
			     dtd_validator_t* validator);
extern int dtd_get_def_decl (struct vxml_parser_s * parser, ecm_attr_t* attr, ecm_el_t* el);
extern int test_string (struct vxml_parser_s * parser, const char * s);
extern int test_class_str (struct vxml_parser_s * parser, const xml_char_class_t _class);
extern int test_class_str_noentity (struct vxml_parser_s * parser, const xml_char_class_t _class);
extern int get_name (struct vxml_parser_s * parser);
extern int get_value (struct vxml_parser_s * parser, int dtd_body);
extern int dtd_constraint_check (struct vxml_parser_s *parser, ecm_el_t* elem, ptrlong attr_idx);
extern int dtd_add_element_decl (dtd_validator_t* validator, struct vxml_parser_s * parser);
extern int get_content_def (struct vxml_parser_s * parser);

extern caddr_t dtd_normalize_attr_value (struct vxml_parser_s* parser, struct buf_range_s* range, ptrlong attr_type);
extern caddr_t dtd_normalize_attr_val (vxml_parser_t *parser, const char* value, int level);

/* functions from dtd.c for reading DTD declarations and filling dtd_, ecm_ structures */
extern int dtd_add_attlist_decl(dtd_validator_t* validator,  struct vxml_parser_s* parser);
extern int dtd_get_element_decl (dtd_validator_t* validator, struct vxml_parser_s * parser);
extern int dtd_add_include_section (struct vxml_parser_s* parser);
extern int dtd_add_ignore_section (struct vxml_parser_s* parser);

extern int entity_compile_repl (vxml_parser_t *parser, xml_def_4_entity_t *newdef);

extern int get_att_type (vxml_parser_t* parser);
extern int get_def_decl (vxml_parser_t* parser);

/*********************************************************************************************/

extern int replace_entity (vxml_parser_t* parser); /*replaces parameter entity */
extern void dtd_check_ids(vxml_parser_t* parser);
extern int get_refentry (vxml_parser_t* parser, char* refname);

extern ptrlong xs_get_primitive_typeidx(vxml_parser_t* parser, xs_component_t *type);



/* if entity is not found already, than leave ent with NULL */
extern int replace_entity_common (vxml_parser_t* parsery, int is_ge, struct xml_def_4_entity_s* ent, buf_ptr_t rem, int log_syntax_error);
extern void insert_buffer (vxml_parser_t* parser, buf_ptr_t* cut_begin, buf_ptr_t* cut_end, lenmem_t* ins, xml_pos_t *ins_beg_pos, xml_pos_t *end_pos);
extern int dtd_check_attribute (vxml_parser_t* parser, const char* value, struct ecm_attr_s* attr);
extern void free_refid_log (basket_t* refid_log);
extern int get_include (vxml_parser_t *parser, const char *base, const char *ref, lenmem_t *res_text, xml_pos_t *res_pos);

#ifndef MALLOC_DEBUG
#define NO_validate_parser_bricks
#endif

#ifndef NO_validate_parser_bricks
extern int validate_parser_bricks (vxml_parser_t * parser);
#else
#define validate_parser_bricks(parser)
#endif

extern int insert_external_dtd(struct vxml_parser_s* parser);

extern const char *concat_full_name (const char *ns, const char *name);

extern int check_entity_recursiveness (vxml_parser_t* parser, const char* entityname, int level, const char* currentname);

int insert_external_xmlschema_dtd (struct vxml_parser_s * parser);

#define LM_EQUAL(a,b) \
  ( \
   (((lm_equal_tmp1 = (a))->lm_length) == \
    ((lm_equal_tmp2 = (b))->lm_length) ) && \
   (0 == memcmp (lm_equal_tmp1->lm_memblock, lm_equal_tmp2->lm_memblock, lm_equal_tmp1->lm_length)))

#define LM_EQUAL_TO_STR(a,str) \
  ( \
   (((lm_equal_tmp1 = (a))->lm_length) == \
    strlen ((void *)(lm_equal_tmp2 = (void *)(str))) ) && \
   (0 == memcmp (lm_equal_tmp1->lm_memblock, (void *)lm_equal_tmp2, lm_equal_tmp1->lm_length)))

/*! Adds namespace declaration \c ns into \c xn2.
Returns 1 if really added or a duplicate detected, 0 if there's a conflict between prefixes or URIs */
extern int xml_ns_2dict_add (xml_ns_2dict_t *xn2, nsdecl_t *ns);
/*! Removes namespace declaration for prefix \c pref from \c xn2.
Returns 1 if really deleted, 0 if the prefix is not found. */
extern int xml_ns_2dict_del (xml_ns_2dict_t *xn2, caddr_t pref);
/*! Adds all namespace declaration from \src into \c dest.
Returns 1 if all declarations from \c src are really added or detected as duplicates,
0 if there's at least one conflict between prefixes or URIs */
extern int xml_ns_2dict_extend (xml_ns_2dict_t *dest, xml_ns_2dict_t *src);

/*! Adds a message of \c errlevel importance into log of \c parser.
\c msg is out of caller's ownership after the call (it's either in parser->msglog or freed).
\returns zero if message is not dumped e.g. due to limitation on number of messages.
 */
extern int xmlparser_log_box (vxml_parser_t *parser, int errlevel, caddr_t msg);

/* Adds a message of \errlevel importance into log of \c dv, allocating
at least \c buflen_eval bytes for internal buffer.
\returns zero if message is not dumped e.g. due to limitation on number of messages. */
extern int xmlparser_logprintf (vxml_parser_t *parser, ptrlong errlevel, size_t buflen_eval, const char *format, ...);

extern int xmlparser_log_place (struct vxml_parser_s *parser);

/* Adds a ECM_DETAILS message into log if grammar of element \c el is brief enough to be printed */
extern int xmlparser_logprintf_grammar (vxml_parser_t *parser, struct ecm_el_s *el);

void xmlparser_log_nconcat (vxml_parser_t *parser, vxml_parser_t *sub_parser);

/* \returns 0 if the config is void or invalid */
extern int xmlparser_configure (vxml_parser_t *parser, caddr_t dtd_config, struct vxml_parser_config_s *parser_config);
extern void xmlparser_tighten_validator (vxml_parser_t *parser);
extern void xmlparser_loose_validator (vxml_parser_t *parser);
extern int xmlparser_is_ok (vxml_parser_t *parser); /*!< returns if there were severe problems */
extern char *xmlparser_log_section_to_string (dk_set_t top, dk_set_t pastbottom, const char *title);

#define INNER_HANDLERS ((NULL != parser->cfg.dtd_config) ? &(parser->masters) : &(parser->slaves))
#define OUTER_HANDLERS ((NULL != parser->cfg.dtd_config) ? &(parser->slaves) : &(parser->masters))

char *xecm_print_fsm (xecm_el_idx_t el_idx, schema_parsed_t * schema, int use_raw);

#endif /* _XML_PARSER_IMPL_H */

