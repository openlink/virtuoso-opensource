/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2024 OpenLink Software
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

%pure-parser
%parse-param {jsonp_t * jsonp_arg}
%parse-param {yyscan_t yyscanner}
%lex-param {jsonp_t * jsonp_arg}
%lex-param {yyscan_t yyscanner}

%{
#include "json.h"
#include "sqlparext.h"
#include "sqlfn.h"

#ifdef _JSONLD_DEBUG
void bing () {}
#endif
#define LVL jsonp_arg->lvl
#define NID jsonp_arg->curr_node_no
#define JNAME jsonp_arg->curr_name ? jsonp_arg->curr_name : "n/a"

#define jsonld_error(str) jsonyyerror_impl(jsonp_arg, str)
extern int jsonyylex (void *yylval_param, jsonp_t *jsonp_arg, yyscan_t yyscanner);

%}

%union {
  caddr_t box;
  caddr_t * list;
  ptrlong token_type;
  dk_set_t set;
}

%token __JSON_SYNTAX

%token OBJ_BEGIN
%token OBJ_END
%token ARR_BEGIN
%token ARR_END
%token COLON
%token COMMA

%token <box> STRING
%token <box> NUMBER
%token <box> TRUE_L
%token <box> FALSE_L
%token <box> NULL_L

%token BASE CONTEXT DIRECTION GRAPH ID IMPORT INCLUDED INDEX JSON LANGUAGE LIST CONTAINER
%token NEST NONE PREFIX PROPAGATE PROTECTED REVERSE SET TYPE VALUE VERSION VOCAB
%token <box> IRI
%token <box> QNAME
%token <box> NCNAME
%token <box> BNODE

%token __JSON_SYNTAX_END

%type <box> boolean
%type <box> scalar
%type <box> value
%type <box> keyword
%type <box> term
%type <box> type_value
%type <box> type_value_list
%type <set> iri_ref_list
%type <box> ctx_item_name
%type <box> iri_ref
%type <list> object
%type <box> array
%type <set> item_list
%type <box> item
%type <box> value_list
%type <set> container_value_list
%type <box> container_value
%type <box> ncname_or_null
%type <box> literal

%%

jsonld_doc
	: object
        | array
	;

keyword : DIRECTION     { $$ = uname_at_direction; }
        | ID            { $$ = uname_at_id; }
        | IMPORT        { $$ = uname_at_import; }
        | INCLUDED      { $$ = uname_at_included; }
        | INDEX         { $$ = uname_at_index; } /* no meaning in RDF, only usefull for serialization for sepecific application use */
        | JSON          { $$ = uname_at_json; } /* good invention, have to think for it's application :-) */
        | LANGUAGE      { $$ = uname_at_language; }
        | LIST          { $$ = uname_at_list; } /*  "knows":{@list:["joe","doe",...]} */
        | SET           { $$ = uname_at_set; }  /* similar syntax sugar */
        | NEST          { $$ = uname_at_nest; } /* imagine js user wants to have a ref between objects w/o any semantic meaning */
        | NONE          { $$ = uname_at_none; } /* because a NULL is a value and not possible as a key */
        | PREFIX        { $$ = uname_at_prefix; } /* this is for serialization */
        | PROPAGATE     { $$ = uname_at_propagate; }
        | PROTECTED     { $$ = uname_at_protected; }
        | REVERSE       { $$ = uname_at_reverse; }
        | TYPE          { $$ = uname_at_type; }
        | VALUE         { $$ = uname_at_value; }
        | VERSION    { $$ = uname_at_version; }
        | CONTAINER     { $$ = uname_at_container; }
        | BASE          { $$ = uname_at_base; }
        | VOCAB         { $$ = uname_at_vocab; }
        /*| GRAPH   { $$ = uname_at_graph; }
        | CONTEXT { $$ = uname_at_context; }*/
        ;


term    : keyword       { $$ = $1; } /* as alias @preserve can not be used */
        | QNAME         { $$ = $1; }
        | BNODE         { $$ = $1; }
        | NCNAME        { $$ = $1; }
        | GRAPH         { $$ = uname_at_graph; }
        ;

ctx_item_name
        : term          { $$ = $1; }
        | IRI           { $$ = $1; }
        ;

/*  A context definition MUST be a map whose keys MUST be either terms, compact IRIs, IRIs,
    or one of the keywords @base, @import, @language, @propagate, @protected, @type, @version, or @vocab.
*/
context_definition  /* "@context":"http://example.org/"  */
        : IRI    { CTX_DOWN; if (JSON_LD_META) jsonld_context_uri_get (jsonp_arg, $1, jsonp_arg->curr_ctx->ns2iri); CTX_UP; }
        | NCNAME { CTX_DOWN; if (JSON_LD_META) jsonld_context_uri_get (jsonp_arg, $1, jsonp_arg->curr_ctx->ns2iri); CTX_UP; }
        | NULL_L { }  /* self-evident */
        | context_tuple                            /* "@context":{"ex":"http://example.org/", "Book":"ex:Book"} */
        | array_of_context_tuples                  /* and array of above */
        ;

context_tuple                                     /* the thing @context:{...}*/
        : OBJ_BEGIN OBJ_END { /* nothing*/ }
        | OBJ_BEGIN { CTX_DOWN; } context_item_list OBJ_END { CTX_UP; }
        ;

context_item_list
        : context_item
        | context_item_list COMMA context_item
        ;

context_tuple_item
        : context_tuple
        | IRI    { CTX_DOWN; if (JSON_LD_META) jsonld_context_uri_get (jsonp_arg, $1, jsonp_arg->curr_ctx->ns2iri); CTX_UP; }
        | NCNAME { /* must resolve */ }
        | NULL_L { /* dummt tbs */ }
        | array  { /* dummy tbs */ }
        ;

context_tuples_list
        : context_tuple_item
        | context_tuples_list COMMA context_tuple_item
        ;

array_of_context_tuples
        : ARR_BEGIN ARR_END
        | ARR_BEGIN context_tuples_list ARR_END
        ;

context_item /* tbd: more specific */
        : ctx_item_name COLON term {
             if (JSON_LD_META) {
                if (uname_at_vocab == $1) /* must resolve @base & @vocab relative to existing if set */
                  {
                    JLD_IS_STRING ($3,$1);
                    jsonp_arg->curr_ctx->ns = $3;
                  }
                else if (uname_at_base == $1)
                  {
                    JLD_IS_STRING ($3,$1);
                    jsonp_arg->curr_ctx->base = $3;
                  }
                else if (uname_at_language == $1)
                  {
                    JLD_IS_STRING ($3,$1);
                    jsonp_arg->curr_ctx->lang = $3;
                  }
                else if (uname_at_import == $1)
                 {
                    JLD_IS_STRING ($3,$1);
                   jsonld_context_uri_get (jsonp_arg, $3, jsonp_arg->curr_ctx->ns2iri);
                 }
                else
                  {
                    caddr_t *item = jsonld_item_new (0, $3, 0, 0, 0);
                    t_id_hash_set (jsonp_arg->curr_ctx->ns2iri, (caddr_t)&($1), (caddr_t)&item);
                  }
               }
             }
        | ctx_item_name COLON IRI  {
             if (JSON_LD_META) {
                if (uname_at_vocab == $1)
                  jsonp_arg->curr_ctx->ns = $3;
                else if (uname_at_base == $1)
                  jsonp_arg->curr_ctx->base = $3;
                else if (uname_at_import == $1)
                 {
                   JLD_IS_STRING ($3,$1);
                   jsonld_context_uri_get (jsonp_arg, $3, jsonp_arg->curr_ctx->ns2iri);
                 }
                else
                  {
                    caddr_t *item = jsonld_item_new (0, $3, 0, 0, 0);
                    t_id_hash_set (jsonp_arg->curr_ctx->ns2iri, (caddr_t)&($1), (caddr_t)&item);
                  }
               }
             }
        | ctx_item_name COLON scalar { /* @version, @protected etc. tba */ }
        | ctx_item_name COLON OBJ_BEGIN OBJ_END {}
        | ctx_item_name COLON OBJ_BEGIN {
            CTX_DOWN;
            if (jsonp_arg->jpmode != JSON_LD)
              memset (&(jsonp_arg->curr_item), 0, sizeof (jsonld_item_t));
            }
            context_term_definitions OBJ_END
            {
                if (JSON_LD_META)
                  {
                    caddr_t item = t_alloc (sizeof (jsonld_item_t));
                    memcpy (item, &jsonp_arg->curr_item, sizeof (jsonld_item_t));
                    t_id_hash_set (jsonp_arg->curr_ctx->ns2iri, (caddr_t)&($1), (caddr_t)&item);
                  }
                CTX_UP;
            }
        | ctx_item_name COLON array { /* xxx */ }
        | STRING COLON value { /* bad or skip? */ }
        ;

context_term_definitions
        : context_term_definition_item
        | context_term_definitions COMMA context_term_definition_item
        ;

container_value_list
        : container_value {
                    if (JSON_LD_META) {
                        $$ = NULL;
                        t_set_push (&($$), $1);
                    }
            }
        | container_value_list COMMA container_value    {
                    if (JSON_LD_META) {
                        $$ = $1;
                        t_set_push (&($$), $3);
                    }
            }
        ;

ncname_or_null
        : NCNAME { $$ = $1; }
        | NULL_L { $$ = NULL; }
        ;

container_value
        : SET           { $$ = uname_at_set; JF_SET(SET_CONT); }
        | LIST          { $$ = uname_at_list; JF_SET(LIST_CONT); }
        | GRAPH         { $$ = uname_at_graph; JF_SET(GRAPH_CONT); }
        | ID            { $$ = uname_at_id;  JF_SET(ID_CONT); }
        | LANGUAGE      { $$ = uname_at_language; JF_SET(LANG_CONT); }
        | INDEX         { $$ = uname_at_index;  JF_SET(INDEX_CONT);  }
        | TYPE          { $$ = uname_at_type; JF_SET(TYPE_CONT); }
        | ARR_BEGIN container_value_list ARR_END { if (JSON_LD_META) { $$ = (caddr_t)t_revlist_to_array ($2); } }
        ;

context_term_definition_item            /* this is to traverse the ctx item and set the item's alias things */
        : ID COLON iri_ref { JLD_SET_CURRENT(id, $3); }
        | ID COLON keyword { JLD_SET_CURRENT(id, $3); } /* ck possibilities */
        | ID COLON NULL_L { JLD_SET_CURRENT(id, NULL); } /* ck possibilities */
        | TYPE COLON type_value { JLD_SET_CURRENT(type, $3); }
        | REVERSE COLON type_value { JF_SET(REV_CONT); if (jsonp_arg->jpmode != JSON_LD) JLD_SET_CURRENT(id, $3); }
        | LANGUAGE COLON ncname_or_null { JLD_SET_CURRENT(lang, $3); }
        | CONTAINER COLON container_value /* flags set inside container_value */
        | CONTEXT { /* new ctx? */ } COLON context_definition { /* inner traverse */ }
        | DIRECTION COLON ncname_or_null
        | PROTECTED COLON boolean
        | PROPAGATE COLON boolean
        | PREFIX COLON boolean
        | INDEX COLON value /* dummy */
        | NEST COLON NEST
/*
        | IMPORT
        | INCLUDED
        | JSON
        | LIST
        | SET
        | NEST
        | NONE
        | PREFIX
        | VALUE
        | VERSION
        | BASE
        | VOCAB
        | GRAPH */
        ;


/* node object should return either bnode/id or NULL if completed  */
object	: OBJ_BEGIN OBJ_END { $$ = NULL; }
        | OBJ_BEGIN {
                CTX_DOWN;
                JF_CLR(VALUE);
                if (JSON_LD_DATA)
                  {
                    jsonld_debug(("[%d %lld] %s OBJ BEGIN flags=%d\n", LVL,NID,JNAME, jsonp_arg->curr_flags));
                    if (JF_IS(NEST_INL))
                      {
                        jsonld_item_t * parent = (jsonld_item_t *)(jsonp_arg->stack ? jsonp_arg->stack->data : NULL);
                        if (!parent)
                          jsonld_error ("@nest cannot be a top-level key");
                        JLD_SET_CURRENT(id, parent->id);
                      }
                    if (JLD_CURRENT(id))
                      JF_SET(ID);
                    else
                      JF_CLR(ID);
                  }
                }
             item_list OBJ_END
                {
                  if (JSON_LD_DATA)
                    {
                      jsonld_item_t * parent = (jsonld_item_t *)(jsonp_arg->stack ? jsonp_arg->stack->data : NULL);
                      dk_set_t items = $3; /* we expect here incomplete items */
                      caddr_t subject_iri = JLD_CURRENT(id);
                      jsonld_debug(("[%d %lld] %s OBJ END\n", LVL,NID,JNAME));
                      jsonld_item_print_dbg (&jsonp_arg->curr_item);
                      $$ = NULL;
                      if (JF_IS(VALUE))
                        {
                          if (!parent)
                            jsonld_error ("@value cannot be a top-level key");
                          if (!parent->name)
                            jsonld_error ("@value without iri reference");
                          JLD_SET_CURRENT(name, parent->name);
                          if (NULL != parent->id)
                            {
                              JLD_SET_CURRENT(id, parent->id);
                              jsonld_quad_insert (jsonp_arg, &jsonp_arg->curr_item);
                              $$ = NULL;
                            }
                          else /* postponed */
                            {
                              caddr_t value_obj = t_alloc (sizeof (jsonld_item_t));
                              memcpy (value_obj, &jsonp_arg->curr_item, sizeof (jsonld_item_t));
                              $$ = (caddr_t *)value_obj;
                            }
                        }
                      else if (!JF_IS(JSON))
                        {
                          if (NULL == subject_iri)
                            {
                              subject_iri = JLD_NEW_BNODE(jsonp_arg);
                            }
                          DO_SET (jsonld_item_t *, item, &items)
                            {
                               item->id = subject_iri;
                               jsonld_quad_insert (jsonp_arg, item);
                            }
                          END_DO_SET()
                        }
                      if (parent && !(parent->flags & JLD_INLINED) && !JF_IS(VALUE)
                            && !JF_IS(REV_INL)) /* if parent is not a linined container, value is processed above  */
                        $$ = jsonld_item_new (uname_at_id, 0, subject_iri, 0, 0);
                    }
                  if (JSON_LD_MAP == jsonp_arg->jpmode && !JF_IS(VALUE) && !JLD_CURRENT(id))
                    {
                      caddr_t bn = JLD_NEW_BNODE(jsonp_arg);
                      sethash ((void*)JLD_CURRENT(node_no), jsonp_arg->node2id, (void*)bn);
                    }
                  CTX_UP;
                }
        ;

iri_ref : QNAME         { $$ = $1; }
        | BNODE         { $$ = $1; }
        | NCNAME        { $$ = $1; }
        | IRI           { $$ = $1; }
        /*| NONE          { $$ = uname_at_none; }*/
        ;


item_list   : item	                {
                    if (JSON_LD_DATA) {
                      $$ = NULL;
                      if($1)
                        t_set_push (&($$), $1);
                    }
                }
	    | item_list COMMA item      {
                    if (JSON_LD_DATA) {
                      $$ = $1;
                      if ($3)
                        t_set_push (&($$), $3);
                    }
                }
	    | item_list COMMA error     { jsonld_error ("pair of field name and value is expected after ','"); }
	    ;

iri_ref_list
        : iri_ref                      { $$ = NULL; t_set_push (&($$), $1); }
        | iri_ref_list COMMA iri_ref   { $$ = $1; t_set_push (&($$), $3); }
        | STRING                       { $$ = NULL; }
        | iri_ref_list COMMA STRING    { $$ = $1; }
        ;

type_value_list
        : ARR_BEGIN ARR_END                 { $$ = NULL; }
        | ARR_BEGIN iri_ref_list ARR_END    { $$ = (caddr_t)t_revlist_to_array ($2); }
        ;

type_value
        : iri_ref       { $$ = $1; }
        | keyword       { $$ = $1; }
        | NULL_L        { $$ = NULL; }
        | STRING        { $$ = NULL; } /* skip ? */
        | type_value_list   { $$ = $1; }
        ;

item	: CONTEXT {
                      if (JSON_LD_META)
                        jsonld_ctx_allocate (jsonp_arg);
                      JF_SET(CTX);
                  } COLON context_definition {
                      if (JSON_LD_META) {
                          uint64 nno = JLD_CURRENT(node_no);
                          jsonld_resolve_refs (jsonp_arg);
                          memset (&(jsonp_arg->curr_item), 0, sizeof (jsonld_item_t));
                          jsonp_arg->curr_node_no = nno;
                        }
                      JF_CLR(CTX);
                      $$ = NULL;
                  }
        | GRAPH { JF_SET(GRAPH); } COLON value {
                      uint64 nno = JLD_CURRENT(node_no);
                      memset (&(jsonp_arg->curr_item), 0, sizeof (jsonld_item_t));
                      jsonp_arg->curr_node_no = nno;
                      if (JSON_LD == jsonp_arg->jpmode || JSON_LD_MAP == jsonp_arg->jpmode)
                        {
                          jsonp_arg->curr_id = gethash ((void*)jsonp_arg->curr_node_no, jsonp_arg->node2id);
                          JF_SET(ID);
                        }
                      $$ = NULL;
                   }
        | ID COLON iri_ref {
                        caddr_t iri = NULL;
                        JF_SET(ID);
                        if (JSON_LD_META) JLD_SET_CURRENT(type,uname_at_id);
                        if (JF_IS(VALUE))
                          jsonld_error ("Can not have @id in value object node");
                        iri = jsonp_uri_resolve (jsonp_arg, $3);
                        JLD_SET_CURRENT(id, iri);
                        jsonld_debug(("[%d %lld] %s ID iri=%s\n", LVL,NID,JNAME, iri));
                        if (JSON_LD_MAP == jsonp_arg->jpmode)
                          {
                            sethash ((void*)JLD_CURRENT(node_no), jsonp_arg->node2id, (void*)iri);
                          }
                        if (JSON_LD == jsonp_arg->jpmode && JF_IS(REV_CONT))
                          {
                            jsonld_item_t item, * parent = (jsonld_item_t *)(jsonp_arg->stack ? jsonp_arg->stack->data : NULL);
                           if (!parent)
                             jsonld_error ("@reverse w/o ref");
                            item.id = iri;
                            item.name = parent->name;
                            item.value = parent->id;
                            item.type = uname_at_id;
                            item.lang = NULL;
                            item.flags = 0;
                            jsonld_quad_insert (jsonp_arg, &item);
                          }
                        $$ = NULL;
                   }
        | ID COLON STRING { JF_SET(ID); JLD_SET_CURRENT(id,uname_at_none);  $$ = NULL; } /* INVALID_ID skip triple */
        | VALUE COLON literal {
                        JF_SET(VALUE);
                        JF_CLR(ID);
                        if (JSON_LD_DATA) {
                            if (JF_IS(CTX))
                              jsonld_error ("Can not have @value in @context node object");
                            if (JLD_CURRENT(id) && !JF_IS(SET_CONT) && !JF_IS(LIST_CONT))
                              jsonld_error ("Can not have @value in node object");
                            JLD_SET_CURRENT(value,$3);
                            jsonld_debug(("[%d %lld] %s VALUE\n", LVL,NID,JNAME));
                          }
                        $$ = NULL;
                  }
        | VALUE COLON object { $$ = NULL; } /* error not supported? */
        | VALUE COLON array { $$ = NULL; } /* error not supported? */
        | LANGUAGE COLON NCNAME {
                            JLD_SET_CURRENT(lang,$3);
                            jsonld_debug(("[%d %lld] %s LANG\n", LVL,NID,JNAME));
                            $$ = NULL;
                  }
        | LANGUAGE COLON STRING { JLD_SET_CURRENT(lang,NULL); $$ = NULL; } /* skip trple? */
        | DIRECTION COLON NCNAME { $$ = NULL; }
        | BASE COLON IRI { $$ = NULL; jsonp_arg->curr_ctx->base = $3; }
        | TYPE COLON type_value {
               if (JSON_LD_DATA) {
                    caddr_t type;
                    if (0 && JLD_CURRENT(lang)) /* should ck if graph etc..*/
                      jsonld_error ("Can not have @type and @lang in value object");
                    jsonld_debug(("[%d %lld] %s TYPE\n", LVL,NID,JNAME));
                    $$ = NULL;
                    if (!JF_IS(ID))
                      {
                        JLD_IS_STRING (($3), type);
                        type = jsonld_qname_resolve (jsonp_arg, $3, NULL);
                        JLD_SET_CURRENT(type,type);
                      }
                    else
                      {
                        uint32 inx;
                        caddr_t box[sizeof (caddr_t) + BOX_AUTO_OVERHEAD];
                        caddr_t *types, *types0;
                        BOX_AUTO_TYPED (caddr_t*, types0, box, sizeof (caddr_t), DV_ARRAY_OF_POINTER);

                        types = types0;
                        if (!ARRAYP($3))
                          types0[0] = $3;
                        else
                          types = (caddr_t *)$3;
                        DO_BOX (caddr_t, tp, inx, types)
                          {
                            type = jsonld_qname_resolve (jsonp_arg, tp, NULL);
                            JLD_SET_CURRENT(name, uname_rdf_ns_uri_type);
                            JLD_SET_CURRENT(value, type);
                            JLD_SET_CURRENT(type, uname_at_id);
                            if (JLD_CURRENT(id))
                              {
                                jsonld_quad_insert (jsonp_arg, &jsonp_arg->curr_item);
                              }
                            else
                              {
                                caddr_t node = t_alloc (sizeof (jsonld_item_t));
                                memcpy (node, &jsonp_arg->curr_item, sizeof (jsonld_item_t));
                                $$ = node;
                              }
                          }
                        END_DO_BOX;
                        JLD_SET_CURRENT(value,NULL);
                        JLD_SET_CURRENT(type,NULL);
                        JLD_SET_CURRENT(lang,NULL);
                      }
                    }
                  if (JSON_LD_MAP == jsonp_arg->jpmode) {
                    caddr_t type = $3;
                    if (DV_STRINGP(type))
                      JLD_SET_CURRENT(type, type);
                    else if (ARRAYP(type) && BOX_ELEMENTS_0(type) > 0)
                      JLD_SET_CURRENT(type, ((caddr_t *)type)[0]);
                  }
                }
        | SET COLON {
              if (JSON_LD_DATA)
                {
                  jsonld_item_t * parent = (jsonld_item_t *)(jsonp_arg->stack ? jsonp_arg->stack->data : NULL);
                  JLD_SET_CURRENT(name, parent ? parent->name : NULL);
                  JLD_SET_CURRENT(id, parent ? parent->id : NULL);
                  JF_SET(SET_INL);
                }
            } value {
                  if (JSON_LD_DATA) {
                    $$ = NULL;
                  }
               }

        | LIST COLON {
               if (JSON_LD_DATA)
                 {
                   jsonld_item_t * parent = (jsonld_item_t *)(jsonp_arg->stack ? jsonp_arg->stack->data : NULL);
                   JLD_SET_CURRENT(name, parent ? parent->name : NULL);
                   JLD_SET_CURRENT(id, parent ? parent->id : NULL);
                   JF_SET(LIST_INL);
                 }
              } value {
                 if (JSON_LD_DATA) {
                   $$ = NULL;
                 }
             }
        | REVERSE COLON
            {
              if (JSON_LD_DATA)
                {
                  JF_SET(REV_INL);
                }
            } value {
               jsonld_debug(("[%d %lld] %s REV\n", LVL,NID,JNAME));
               if (JSON_LD_DATA)
                 {
                   JF_CLR(REV_INL);
                 }
               $$ = NULL;
             }
        | INCLUDED COLON value {
                 $$ = NULL;
                 if (JSON_LD_DATA)
                   {
                     JLD_SET_CURRENT (type, NULL);
                     JLD_SET_CURRENT (value, NULL);
                   }
            }
        | INDEX COLON /* no semantic use at all, gift for json peoples */
             {
               if (JSON_LD_DATA)
                 {
                   JF_SET(INDEX_INL);
                 }
             } value {
                 if (JSON_LD_DATA)
                   {
                     JF_CLR(INDEX_INL);
                     JLD_SET_CURRENT (type, NULL);
                     JLD_SET_CURRENT (value, NULL);
                     $$ = NULL;
                   }
             }
        | NEST COLON /* see ^^^ */
             {
               if (JSON_LD_DATA)
                 {
                   JF_SET(NEST_INL);
                 }
             } value {
                 if (JSON_LD_DATA)
                   {
                     JF_CLR(NEST_INL);
                     JLD_SET_CURRENT (type, NULL);
                     JLD_SET_CURRENT (value, NULL);
                     $$ = NULL;
                   }
             }
        | iri_ref COLON {
               if (JSON_LD_DATA) {
                    jsonld_item_t * itm = NULL;
                    jsonld_item_t * parent = (jsonld_item_t *)(jsonp_arg->stack ? jsonp_arg->stack->data : NULL);
                    if (JF_IS(LANG_CONT))
                      {
                        caddr_t lang_ref = jsonld_term_resolve (jsonp_arg, $1, NULL);
                        if (uname_at_none == lang_ref)
                          JLD_SET_CURRENT(lang, NULL);
                        else
                          JLD_SET_CURRENT(lang, $1);
                      }
                    else
                      {
                        caddr_t prop = jsonld_term_resolve (jsonp_arg, $1, &itm);
                        jsonld_debug(("[%d %lld] %s OBJ BEGIN REF flags=%d\n", LVL,NID,JNAME, itm?itm->flags:jsonp_arg->curr_flags));
                        if (uname_at_nest == prop)
                          JF_SET(NEST_INL);
                        if (JF_IS(ID_CONT))
                          {
                            if (uname_at_none == prop)
                              {
                                caddr_t bn = JLD_NEW_BNODE(jsonp_arg);
                                JLD_SET_CURRENT(id, bn);
                              }
                            else
                              {
                                JLD_SET_CURRENT(id, prop);
                              }
                          }
                        else
                          {
                            JLD_SET_CURRENT(name, prop);
                          }
                      }
                    if (JF_IS(ID))
                      JLD_SET_CURRENT(type, NULL);
                    if (NULL != itm)
                      {
                        jsonp_arg->curr_item.flags |= itm->flags;
                      }

                    if (JF_IS(LANG_CONT) && !JLD_CURRENT(id) && parent) /* not a top-level bound bnode */
                      {
                         caddr_t subj = gethash ((void*)parent->node_no, jsonp_arg->node2id);
                         if (!subj)
                           {
                             subj = JLD_NEW_BNODE(jsonp_arg);
                             sethash ((void*)parent->node_no, jsonp_arg->node2id, (void*)subj);
                           }
                         JLD_SET_CURRENT(id, subj);
                      }
                    if (itm && uname_at_json == itm->type)
                      JF_SET (JSON);
                }
              } object { /* here we process node object e.g. "x":{@value:"..." or "@id":..} etc */
                $$ = NULL;
                if (JSON_LD_DATA) /* the items should be complete by now, we should get IRI of that object or Bnode,
                                    OR we have value object then we should complete it here  */
                  {
                    jsonld_item_t * item = (jsonld_item_t *)($4);
                    if (NULL != item) /* there is a child or value object */
                      {
                        if (JF_IS(ID_CONT))
                          {
                            jsonld_item_t * parent = (jsonld_item_t *)(jsonp_arg->stack ? jsonp_arg->stack->data : NULL);
                            if (!parent)
                              jsonld_error ("@id container cannot w/o parent");
                            item->name = parent->name;
                            item->id = parent->id;
                            jsonld_quad_insert (jsonp_arg, item);
                            $$ = NULL;
                          }
                        else
                          {
                            item->name = JLD_CURRENT(name);
                            item->id = JLD_CURRENT(id);
                            /* filter only valid refs */
                            if (DV_STRINGP(item->name) && strchr (item->name, ':') && !JF_IS(JSON))
                              $$ = (caddr_t)item;
                          }
                      }
                    jsonld_debug(("[%d %lld] %s OBJ REF END\n", LVL,NID,JNAME));
                    jsonld_item_print_dbg (item);
                    JF_CLR (OBJ_NODE); /* we are done with contained object, clear all flags about it */
                  }
                 JLD_SET_CURRENT(lang,NULL); /*???*/
              }
        | iri_ref COLON { /* here we process containers e.g. "x":[...] */
               if (JSON_LD_DATA)
                 {
                   if (JF_IS(ID))
                     JLD_SET_CURRENT(type, NULL);
                   if (JF_IS(LANG_CONT))
                     {
                        caddr_t lang_ref = jsonld_term_resolve (jsonp_arg, $1, NULL);
                        if (uname_at_none == lang_ref)
                          JLD_SET_CURRENT(lang, NULL);
                        else
                          JLD_SET_CURRENT(lang, $1);
                     }
                   else
                    {
                        caddr_t subject_iri = JLD_CURRENT(id);
                        jsonld_item_t * itm = NULL;
                        caddr_t prop = jsonld_term_resolve (jsonp_arg, $1, &itm);

                        if (NULL == subject_iri)
                           subject_iri = gethash ((void*)jsonp_arg->curr_node_no, jsonp_arg->node2id);
                        if (NULL == subject_iri)
                          subject_iri = JLD_NEW_BNODE(jsonp_arg);
                        JLD_SET_CURRENT(id, subject_iri);

                        jsonld_debug(("[%d %lld] %s ARR BEGIN\n", LVL,NID,JNAME));
                        JLD_SET_CURRENT(name, prop);
                        if (NULL != itm)
                          {
                            JLD_SET_CURRENT(type, itm->type);
                            jsonp_arg->curr_item.flags |= itm->flags;
                          }
                        if (!JF_IS(CONTAINER))
                          JF_SET(SET_CONT);
                    }
                  JF_CLR(VALUE);
                }
              } array {
                    if (JSON_LD_DATA) {
                        $$ = NULL;
                       if (!JF_IS(LANG_CONT))
                         JF_CLR(CONTAINER); /* tbc: perhaps should keep, should ck */
                        JLD_SET_CURRENT(lang,NULL);
                        JLD_SET_CURRENT(type,NULL);
                        jsonld_debug(("[%d %lld] %s ARR END\n", LVL,NID,JNAME));
                    }
                 }
        | iri_ref COLON literal { /* here we process expanded form of object e.g. "x":"something", "b":42 etc. */
               jsonld_item_t * itm = NULL;
               caddr_t prop = jsonld_term_resolve (jsonp_arg, $1, &itm);
               caddr_t lit = $3, iri = NULL;

               if (uname_at_none == prop)
                  JF_SET(NONE);
               if (uname_at_id == prop) /* aliased @id */
                 {
                   JLD_IS_STRING(lit, id);
                   iri = jsonp_uri_resolve (jsonp_arg, lit);
                   JF_SET(ID);
                   if (JSON_LD_MAP == jsonp_arg->jpmode)
                     {
                       sethash ((void*)JLD_CURRENT(node_no), jsonp_arg->node2id, (void*)iri);
                       JLD_SET_CURRENT(id,iri);
                     }
                 }
               if (JSON_LD_DATA)
                 {
                   jsonld_debug(("[%d %lld] %s LIT\n", LVL,NID,JNAME));
                   if (JF_IS(LANG_CONT))
                     {
                       if (NULL != iri)
                         jsonld_error ("Cannot use aliased @id keyword as language id");
                       if (JF_IS(NONE))
                         JLD_SET_CURRENT(lang, NULL);
                       else
                         JLD_SET_CURRENT(lang, $1);
                     }
                   else
                     {
                       JLD_SET_CURRENT(name, prop);
                     }
                   if (NULL != itm)
                     {
                       if (itm->type)
                         {
                           if (uname_at_vocab != itm->type)
                             JLD_SET_CURRENT(type, itm->type);
                           else if (uname_at_vocab == itm->type && DV_STRINGP(lit))
                             {
                               JLD_SET_CURRENT(type, uname_at_id);
                               JLD_CURRENT(use_ns) = '\1';
                             }
                         }
                       jsonp_arg->curr_item.flags |= itm->flags;
                     }
                   $$ = NULL;
                   if (uname_at_id == prop)  /* "id":"iri" where "id" alias of "@id" */
                     {
                       JLD_SET_CURRENT(id, iri);
                       if (JF_IS(REV_INL))
                         {
                           jsonld_item_t item, * parent = (jsonld_item_t *)(jsonp_arg->stack ? jsonp_arg->stack->data : NULL);
                           if (!parent)
                             jsonld_error ("@reverse w/o ref");
                           item.id = iri;
                           item.name = parent->name;
                           item.value = parent->id;
                           item.type = uname_at_id;
                           item.lang = NULL;
                           item.flags = 0;
                           jsonld_quad_insert (jsonp_arg, &item);
                        }
                     }
                   else if (uname_at_type == prop) /* similar to above */
                     {
                       caddr_t q_type = jsonld_qname_resolve (jsonp_arg, lit, NULL);
                       if (!JF_IS(VALUE))
                         {
                           JLD_SET_CURRENT(name, uname_rdf_ns_uri_type);
                           JLD_SET_CURRENT(value, q_type);
                           JLD_SET_CURRENT(type, uname_at_id);
                           if (JLD_CURRENT(id))
                             {
                               jsonld_quad_insert (jsonp_arg, &jsonp_arg->curr_item);
                             }
                           else /* next is postponed */
                             {
                               caddr_t node = t_alloc (sizeof (jsonld_item_t));
                               memcpy (node, &jsonp_arg->curr_item, sizeof (jsonld_item_t));
                               $$ = node;
                             }
                           JLD_SET_CURRENT(type,NULL);
                         }
                       else
                         JLD_SET_CURRENT(type, q_type);
                     }
                   else if (uname_at_language == JLD_CURRENT(name))
                     JLD_SET_CURRENT(lang, lit);
                   else
                     {
                       JLD_SET_CURRENT(value, lit);
                       jsonld_item_print_dbg (&jsonp_arg->curr_item);
                       if (JLDI_COMPLETE (jsonp_arg))
                         {
                           jsonld_quad_insert (jsonp_arg, &jsonp_arg->curr_item);
                         }
                       else /* next is postponed */
                         {
                           caddr_t node = t_alloc (sizeof (jsonld_item_t));
                           memcpy (node, &jsonp_arg->curr_item, sizeof (jsonld_item_t));
                           $$ = node;
                         }
                       JLD_SET_CURRENT(type,NULL);
                       JLD_SET_CURRENT(lang,NULL);
                     }
                   /* result is NULL unless triple postponed */
                   JLD_SET_CURRENT(value,NULL);
                   JF_CLR(NONE);
                 }
              }
        | NONE COLON
                {
                   if (JSON_LD_DATA)
                     {
                       if (JF_IS(ID_CONT))
                         {
                           caddr_t bn = JLD_NEW_BNODE(jsonp_arg);
                           JLD_SET_CURRENT(id, bn);
                           JLD_SET_CURRENT(name, NULL);
                         }
                       JF_SET(NONE);
                     }
                } value {
                     $$ = NULL;
                     if (JSON_LD_DATA)
                       {
                         jsonld_item_t * item = (jsonld_item_t *)($4);
                         if (item && JF_IS(ID_CONT))
                           {
                             jsonld_item_t * parent = (jsonld_item_t *)(jsonp_arg->stack ? jsonp_arg->stack->data : NULL);
                             if (!parent)
                               jsonld_error ("@id container cannot w/o parent");
                             item->name = parent->name;
                             item->id = parent->id;
                             jsonld_quad_insert (jsonp_arg, item);
                             $$ = NULL;
                           }
                       }
                     JF_CLR(NONE);
                }
        | STRING COLON value { $$ = NULL; } /* unknown, skip */
	| iri_ref COLON error { jsonld_error ("value is expected after ':'"); }
	| iri_ref error { jsonld_error ("colon is expected after field name"); }
	;

/* array should not return value unlike of node object, i.e. it is a container thing */
array	: ARR_BEGIN ARR_END {
              if (JF_IS(LIST_CONT))
                {
                  JLD_SET_CURRENT(value, uname_rdf_ns_uri_nil);
                  JLD_SET_CURRENT(type, uname_at_id);
                  jsonld_quad_insert (jsonp_arg, &jsonp_arg->curr_item);
                  JLD_SET_CURRENT(type,NULL);
                }
               JLD_SET_CURRENT(value, NULL);
               $$ = NULL;
             }
        | ARR_BEGIN value_list ARR_END {
                if (JSON_LD_DATA)
                  {
                    jsonld_item_t item;
                    caddr_t bn = $2;
                    /* here we set rdf:rest rdf:nil and return 1st bnode  */
                    if (JF_IS(LIST_CONT))
                      {
                        item.id = bn;
                        item.name = uname_rdf_ns_uri_rest;
                        item.value = uname_rdf_ns_uri_nil;
                        item.type = uname_at_id;
                        item.lang = NULL;
                        jsonld_quad_insert (jsonp_arg, &item);
                      }
                    $$ = NULL;
                  }
                }
	;

value_list
	: value {
               if (JSON_LD_DATA) {
                 jsonld_item_t item;
                 caddr_t bn = NULL;
                 dtp_t dtp = DV_TYPE_OF($1);
                 /* we push a triple, bnode/rdf:first/rdf:rest ... and return bnode, OR id/prop/value */
                 switch (dtp) {
                   case DV_CUSTOM:
                     memcpy (&item, $1, sizeof (jsonld_item_t));
                     item.id = JLD_CURRENT(id);
                     item.name = JLD_CURRENT(name);
                     break;
                   case DV_STRING:
                   case DV_UNAME:
                   case DV_LONG_INT:
                   case DV_DOUBLE_FLOAT:
                   case DV_NUMERIC:
                   case DV_DB_NULL:
                     memcpy (&item, &jsonp_arg->curr_item, sizeof (jsonld_item_t));
                     item.value = $1;
                     item.type = JLD_CURRENT(type);
                     item.lang = JLD_CURRENT(lang);
                     if (!DV_STRINGP(item.value)) /* even there is a type ref in the container def, the native values are as-is  */
                       item.lang = NULL;
                     break;
                   default:
                     jsonld_error ("Must have scalar or object as element in JSON array");
                     break;
                   }
                 if (uname_at_type == item.name)
                   {
                     item.name = uname_rdf_ns_uri_type;
                     item.type = uname_at_id;
                     item.value = jsonld_qname_resolve (jsonp_arg, item.value, NULL);
                   }
                 if (NULL == $1 || DV_DB_NULL == dtp); /* this is a value object alredy inserted */
                 else if (JF_IS(SET_CONT))
                   {
                     jsonld_quad_insert (jsonp_arg, &item);
                   }
                 else if (JF_IS(LIST_CONT))
                   {
                     bn = JLD_NEW_BNODE(jsonp_arg);
                     item.id = bn;
                     item.name = uname_rdf_ns_uri_first;
                     jsonld_quad_insert (jsonp_arg, &item);

                     item.id = JLD_CURRENT(id);
                     item.name = JLD_CURRENT(name);
                     item.value = bn;
                     item.type = uname_at_id;
                     jsonld_quad_insert (jsonp_arg, &item);
                   }
                 else if (JF_IS(LANG_CONT))
                   {
                     /* ck for str */
                     jsonld_quad_insert (jsonp_arg, &item);
                   }
                 JLD_SET_CURRENT(value, NULL);
                 $$ = bn;
               }
            }
	| value_list COMMA value {
               $$ = NULL;
               if (JSON_LD_DATA && NULL != $3) {
                 jsonld_item_t item;
                 caddr_t prev = $1, bn = NULL;
                 dtp_t dtp = DV_TYPE_OF($3);
                 /* same here, we push a triple, bnode/rdf:first/rdf:rest ... and return bnode, OR id/prop/value */
                 switch (dtp) {
                   case DV_CUSTOM:
                     memcpy (&item, $3, sizeof (jsonld_item_t));
                     item.id = JLD_CURRENT(id);
                     item.name = JLD_CURRENT(name);
                     break;
                   case DV_STRING:
                   case DV_UNAME:
                   case DV_LONG_INT:
                   case DV_DOUBLE_FLOAT:
                   case DV_NUMERIC:
                   case DV_DB_NULL:
                     memcpy (&item, &jsonp_arg->curr_item, sizeof (jsonld_item_t));
                     item.value = $3;
                     item.type = JLD_CURRENT(type);
                     item.lang = JLD_CURRENT(lang);
                     if (!DV_STRINGP(item.value))
                       item.lang = NULL;
                     break;
                   default:
                     jsonld_error ("Must have scalar or object as element in JSON arraya");
                     break;
                   }
                 if (uname_at_type == item.name)
                   {
                     item.name = uname_rdf_ns_uri_type;
                     item.type = uname_at_id;
                     item.value = jsonld_qname_resolve (jsonp_arg, item.value, NULL);
                   }
                 if (NULL == $3 || DV_DB_NULL == dtp); /* this is a value object alredy inserted */
                 else if (JF_IS(SET_CONT))
                   {
                     jsonld_quad_insert (jsonp_arg, &item);
                   }
                 else if (JF_IS(LIST_CONT))
                   {
                     bn = item.id = JLD_NEW_BNODE(jsonp_arg);
                     item.name = uname_rdf_ns_uri_first;
                     jsonld_quad_insert (jsonp_arg, &item);

                     item.id = prev;
                     item.name = uname_rdf_ns_uri_rest;
                     item.value = bn;
                     item.type = uname_at_id;
                     jsonld_quad_insert (jsonp_arg, &item);
                   }
                 else if (JF_IS(LANG_CONT))
                   {
                     /* ck for str */
                     jsonld_quad_insert (jsonp_arg, &item);
                   }
                 JLD_SET_CURRENT(value, NULL);
                 $$ = bn;
               }
            }
	| value_list COMMA error { jsonld_error ("array member is expected after ','"); }
	;

boolean : TRUE_L  { $$ = t_box_num_and_zero (1); if (JSON_LD_DATA) JLD_SET_CURRENT(type, uname_xmlschema_ns_uri_hash_boolean); }
	| FALSE_L { $$ = t_box_num_and_zero (0); if (JSON_LD_DATA) JLD_SET_CURRENT(type, uname_xmlschema_ns_uri_hash_boolean); }
        ;

scalar	: STRING  { $$ = $1; }
        | NUMBER  {
                $$ = $1;
                if (JSON_LD_DATA && !JLD_CURRENT(type))
                  {
                    dtp_t dtp = DV_TYPE_OF ($1);
                    switch (dtp)
                      {
                        case DV_LONG_INT:
                            JLD_SET_CURRENT(type, uname_xmlschema_ns_uri_hash_integer);
                            break;
                        case DV_DOUBLE_FLOAT:
                            break;
                            JLD_SET_CURRENT(type, uname_xmlschema_ns_uri_hash_double);
                            break;
                        case DV_NUMERIC:
                            JLD_SET_CURRENT(type, uname_xmlschema_ns_uri_hash_decimal);
                            break;
                        default:
                            break;
                      }
                  }
            }
	| boolean { $$ = $1; }
	| NULL_L  { $$ = t_NEW_DB_NULL; }
        ;

literal
        : scalar  { $$ = $1; }
        | iri_ref { $$ = $1; }
        | keyword { $$ = $1; }
        | GRAPH   { $$ = uname_at_graph; }
        | CONTEXT { $$ = uname_at_context; }
	;

value   : scalar  { $$ = $1; }
        | iri_ref { $$ = $1; }
        | keyword { $$ = $1; }
	| object  { $$ = (caddr_t)$1; }
      	| array   { $$ = (caddr_t)$1; }
        | GRAPH   { $$ = uname_at_graph; }
        | CONTEXT { $$ = uname_at_context; }
	;

%%
