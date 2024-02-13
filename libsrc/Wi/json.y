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

#define jsonyyerror(jsonp_arg,yyscan,str) jsonyyerror_impl(jsonp_arg, str)
#define json_error(str) jsonyyerror_impl(jsonp_arg, str)
extern int jsonyylex (void *yylval_param, jsonp_t *jsonp_arg, yyscan_t yyscanner);

%}

%union {
  caddr_t box;
  caddr_t *list;
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


%type <box> object
%type <list> jsondoc
%type <set> members
%type <set> members_opt
%type <set> pair
%type <box> value
%type <box> array
%type <set> value_list
%type <set> value_list_opt

%%

jsondoc
	: object { jsonp_arg->jtree = (caddr_t *) $1; }
	| array { jsonp_arg->jtree = (caddr_t *) $1; }
	;

object	: OBJ_BEGIN members_opt OBJ_END {
       					$$ = (caddr_t)t_list_to_array (
						t_NCONC (
						/* header */
						t_CONS(t_alloc_box (0, DV_COMPOSITE),
						t_CONS (t_box_string ("structure"), NULL))
						,
						$2
						)
					     );
				    }
     	;

members_opt
	: /* empty */ { $$ = NULL; }
	| members
	;

members : pair 		    { $$ = $1; }
	| members COMMA pair  { $$ = t_NCONC ($1, $3); }
	| members COMMA error { json_error ("pair of field name and value is expected after ','"); }
	;

pair
	: STRING COLON value {
                $$ = NULL;
                t_set_push (&($$), $3);
                t_set_push (&($$), $1);
                }
	| STRING COLON error { json_error ("value is expected after ':'"); }
	| STRING error { json_error ("colon is expected after field name"); }
	;


array
      	: ARR_BEGIN value_list_opt ARR_END { $$ = (caddr_t)t_list_to_array ($2);}
	;

value_list_opt
	: /* empty */ { $$ = NULL; }
	| value_list
	;

value_list
	: value { $$ = t_CONS ($1, NULL); }
	| value_list COMMA value { $$ = t_NCONC ($1, t_CONS($3, NULL)); }
	| value_list COMMA error { json_error ("array member is expected after ','"); }
	;


value	: STRING  { $$ = $1; }
      	| NUMBER  { $$ = $1; }
	| TRUE_L  { $$ = t_box_num (1); }
	| FALSE_L { $$ = t_box_num (0); }
	| NULL_L  { $$ = t_NEW_DB_NULL; }
	| object  { $$ = $1; }
      	| array   { $$ = $1; }
	;

%%

