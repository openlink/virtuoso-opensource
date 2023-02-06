/*
 *  json.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

#ifndef _JSON_H
#define _JSON_H
#include "Dk.h"
#undef VERSION
#include "sqlbif.h"
#include "rdf_core.h"
#include "uname_const_decl.h"

#define YYDEBUG 1
#define YYERROR_VERBOSE 1
#define jsonldyylex jsonyylex
#define jsonldyyerror(jsonp_arg,yyscan,str) jsonyyerror_impl(jsonp_arg, str)

#define JSON_TREE   0 /* parse and return tree used for json_parse() */
#define JSON_LD     1 /* context mode, parse and resolve names */
#define JSON_LD_CTX 3 /* parse only context and push in ht */
#define JSON_LD_MAP 7 /* make obj map & ctx */

/* bits of current value of a .curr_item.flags */
#define JLD_NULL                0
#define JLD_CTX                 (1<<0)
#define JLD_GRAPH               (1<<1)
#define JLD_LANG_CONT           ((1<<2) | JLD_INLINED) /* work as inlined */
#define JLD_SET_CONT            (1<<3)
#define JLD_LIST_CONT           (1<<4)
#define JLD_NEST_CONT           (1<<5)
#define JLD_ID_CONT             (1<<6)
#define JLD_INDEX_CONT          (1<<7)
#define JLD_TYPE_CONT           (1<<8)
#define JLD_GRAPH_CONT          (1<<9)
#define JLD_REV_CONT            (1<<10)
#define JLD_INLINED             (1<<11)

#define JLD_ID                  (1<<12)
#define JLD_NAME                (1<<13)
#define JLD_VALUE               ((1<<14) | JLD_INLINED) /* always is inlined */
#define JLD_JSON                (1<<15)
#define JLD_NONE                (1<<16)

/* some variants of containers when used as inlined e.g. @set:{...} */
#define JLD_SET_INL        (JLD_SET_CONT|JLD_INLINED)
#define JLD_LIST_INL       (JLD_LIST_CONT|JLD_INLINED)
#define JLD_NEST_INL       (JLD_NEST_CONT|JLD_INLINED)
#define JLD_INDEX_INL      (JLD_INDEX_CONT|JLD_INLINED)
#define JLD_REV_INL        (JLD_REV_CONT|JLD_INLINED)

#define JLD_OBJ_NODE           ~(JLD_GRAPH|JLD_CTX)
#define JLD_CONTAINER           (JLD_LANG_CONT|JLD_SET_CONT|JLD_LIST_CONT|JLD_ID_CONT|JLD_INDEX_CONT|JLD_TYPE_CONT|JLD_NEST_CONT)

#define JF_SET(x) jsonp_arg->curr_flags |= JLD_##x
#define JF_IS(x)  (jsonp_arg->curr_flags & JLD_##x)
#define JF_CLR(x) jsonp_arg->curr_flags &= ~(JLD_##x)

#define JSON_LD_DATA (JSON_LD == jsonp_arg->jpmode)
#define JSON_LD_META ((JSON_LD_CTX == jsonp_arg->jpmode) || (JSON_LD_MAP == jsonp_arg->jpmode))

typedef struct jsonld_ctx_s jsonld_ctx_t;

struct jsonld_ctx_s {
  caddr_t id;
  caddr_t ns;           /* @vocab */
  caddr_t base;         /* @base */
  caddr_t lang;         /* @language */
  uint32 lvl;           /* the containing node depth level */
  id_hash_t *ns2iri;
  jsonld_ctx_t *prev;   /* two-way list with vvv */
  jsonld_ctx_t *next;
};

/* represents context item expanded, for ex.
   "pic": { "@id": "http://xmlns.com/foaf/0.1/depiction", "@type": "@id" },
   "generatedAt": { "@id": "ex:generatedAt", "@type": "xsd:dateTime" }
   note @type here is the range of term object i.e. literal dt/lang or id @id then it's MUST be IRI
   these are collected on 1st go and finally all MUST have .id set to something which look-like as IRI
   allocated as jsonld_item_new()
 */
typedef struct jsonld_item_s {
  uint64  node_no;      /* node obj no */
  caddr_t name;         /* name or iri, RDF property */
  caddr_t type;         /* datatype or UNAME`@id` if it is an IRI */
  caddr_t id;           /* represents `term`, short name or qname and must be resolved to IRI finally as Subject */
  caddr_t value;        /* node object value, used for import, not used in ctx mode */
  caddr_t lang;         /* intl. */
  uint32 flags;         /* bitmask of node type, container, nesting, ordered or unordered set etc. see JLD_xx flags */
} jsonld_item_t;

typedef struct jsonp_s {
  caddr_t jtext;	/*!< Full source text, if short, or the beginning of long text, or an empty string */
  size_t jtext_len;     /* length w/o trailing zero of ^^^ */
  OFF_T jtext_ofs;      /*!< Current position */
  uint32 line;
  uint32 lvl;           /* obj node depth */
  uint64 last_node_no;  /* last obj node no */
  dk_hash_t * node2id;  /* node id -> @id/iri map */
  caddr_t *jtree;       /* parse tree for genric parser */
  uint32 jpmode;        /* parse mode tree/loader */
  uint64 bnode_iid;     /* last bnode id in current document */
  caddr_t base_uri;     /* document base URI */
  caddr_t curr_graph_uri; /* default graph */
  dk_set_t stack;       /* stack of node obj state */
  jsonld_item_t curr_item; /* current working item */
  jsonld_ctx_t * curr_ctx; /* json ld context  */
  dk_set_t pending_quads; /* not used for now */
  triple_feed_t *jtf;     /* hooks for loader etc. */
  query_instance_t *qi;   /* self evident */
} jsonp_t;

#define curr_id curr_item.id
#define curr_name curr_item.name
#define curr_value curr_item.value
#define curr_lang curr_item.lang
#define curr_type curr_item.type
#define curr_flags curr_item.flags
#define curr_node_no curr_item.node_no

#define JLD_ITM_INIT(itm, id, name, value, type, lang) \
        itm->id = id; \
        itm->name = name; \
        itm->value = value; \
        itm->type = type; \
        itm->lang = lang;

#define JLD_IS_STRING(v, term) \
    if ((v) && !DV_STRINGP((v))) \
      jsonld_error (#term " must be a string.")

/*  fprintf (stderr, "JLD_SET_CURRENT " #xx " %s:%d %s\n", __FILE__, __LINE__, v); */
#define JLD_SET_CURRENT(xx,v) \
     do { \
         if (DV_DB_NULL != DV_TYPE_OF(v)) \
          jsonp_arg->curr_##xx = v; \
         else \
          jsonp_arg->curr_##xx = NULL; \
        if (jsonp_arg->curr_id && !DV_STRINGP(jsonp_arg->curr_id)) \
          jsonld_error ("@id must be a string."); \
        if (jsonp_arg->curr_type && !DV_STRINGP(jsonp_arg->curr_type) && !ARRAYP(jsonp_arg->curr_type)) \
          jsonld_error ("@type must be a string or array of"); \
        if (jsonp_arg->curr_lang && !DV_STRINGP(jsonp_arg->curr_lang)) \
          jsonld_error ("@language must be a string"); \
    } while (0)

#define JLD_CURRENT(xx) jsonp_arg->curr_##xx

#define JLD_NEW_BNODE(jp) t_box_sprintf (20, "_:b" UBOXINT_FMT, jp->bnode_iid++)

#define CTX_DOWN jsonld_frame_push(jsonp_arg)
#define CTX_UP jsonld_frame_pop(jsonp_arg)

#define JLDI_COMPLETE(jp) (jp->curr_id && jp->curr_name && jp->curr_value) /* this must be removed*/

#define JLD_AUDIT_O(obj, dt, lang, err) \
      do { \
        if (NULL != dt && NULL != lang) \
          err = srv_make_new_error ("42000", "JSNLD", "Cannot have type and language at same time"); \
        if (dt && !DV_STRINGP(dt))\
          err = srv_make_new_error ("42000", "JSNLD", "type must resolve as IRI"); \
        if (lang && !DV_STRINGP(lang)) \
          err = srv_make_new_error ("42000", "JSNLD", "language must resolve as lang-tag string"); \
        if (obj && !DV_STRINGP((obj)) && !IS_NUM_DTP(DV_TYPE_OF(obj)) && !IS_DATE_DTP(DV_TYPE_OF(obj))) \
          err = srv_make_new_error ("42000", "JSNLD", "Object value of type %s (%d) is not supported", dv_type_title(DV_TYPE_OF(obj)), DV_TYPE_OF(obj)); \
      } while (0)

void jsonyyerror_impl(jsonp_t * jsonp_arg, const char *s);
jsonld_ctx_t * jsonld_ctx_allocate (jsonp_t *jsonp_arg);
void jsonld_ctx_set (jsonp_t *jsonp_arg);
caddr_t jsonld_term_resolve (jsonp_t *jsonp_arg, caddr_t term, jsonld_item_t **ret_item);
caddr_t jsonld_qname_resolve (jsonp_t *jsonp_arg, caddr_t qname, jsonld_item_t **ret_item);
void jsonld_quad_insert (jsonp_t * jsonp_arg, jsonld_item_t *itm);
void jsonld_context_uri_get (jsonp_t *jsonp_arg, caddr_t uri, id_hash_t *ht);
caddr_t * jsonld_item_new (caddr_t type, caddr_t id, caddr_t value, caddr_t lang, uint32 flags);
caddr_t jsonp_uri_resolve (jsonp_t *jsonp_arg, caddr_t qname);
caddr_t jsonp_term_uri_resolve (jsonp_t *jsonp_arg, caddr_t qname);
void jsonld_frame_push (jsonp_t *jsonp_arg);
void jsonld_frame_pop (jsonp_t *jsonp_arg);
void jsonld_resolve_refs (jsonp_t *jsonp_arg);
void jsonld_item_print(jsonld_item_t *itm);

#ifdef _JSONLD_DEBUG
#define jsonld_debug(x) printf x
#define jsonld_item_print_dbg jsonld_item_print
#else
#define jsonld_debug(x)
#define jsonld_item_print_dbg(x)
#endif

#endif
