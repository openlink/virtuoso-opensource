%{
/*
 *  json.y
 *
 *  $Id$
 *
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
 */
#include <Dk.h>
#include "sqlparext.h"
#include "sqlfn.h"

#define jsonyyerror(str) jsonyyerror_impl(str)
void jsonyyerror_impl(const char *s);
int jsonyy_string_input (char *buf, int max);
caddr_t *json_tree; 
caddr_t json_str;
int jsonyydebug;
int jsonyylex (void);
%}

%union {
  caddr_t box;
  caddr_t *list;
  dk_set_t set;
}

%token OBJ_BEGIN
%token OBJ_END
%token ARR_BEGIN
%token ARR_END
%token COLON
%token COMMA
%token LEXICAL_ERROR

%token <box> STRING
%token <box> NUMBER
%token <box> TRUE_L
%token <box> FALSE_L
%token <box> NULL_L

%type <box> object
%type <list> jsondoc 
%type <set> members
%type <set> pair
%type <box> value
%type <box> array
%type <set> value_list

%%

jsondoc	: object { json_tree = $$; }
	;

object	: OBJ_BEGIN members OBJ_END { 
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

members : pair 		    { $$ = $1; }
	| pair COMMA members  { $$ = t_NCONC ($1, $3); }
	;

pair	: STRING COLON value  { 
     		dk_set_t set = NULL;
		t_set_push (&set, $3);
		t_set_push (&set, $1);
		$$ = set;
    	 }
	;


array	: ARR_BEGIN ARR_END { $$ = (caddr_t)t_list (0); }
      	| ARR_BEGIN value_list ARR_END { $$ = (caddr_t)t_list_to_array ($2);}
	;

value_list: value { $$ = t_CONS ($1, NULL); }
	| value COMMA value_list { $$ = t_NCONC (t_CONS($1, NULL), $3); }
	;	   


value	: STRING  { $$ = $1; }
      	| NUMBER  { $$ = $1; }
	| TRUE_L  { $$ = t_box_num (1); }
	| FALSE_L { $$ = t_box_num (0); }
	| NULL_L  { $$ = t_alloc_box (0, DV_DB_NULL); }
	| object  { $$ = $1; } 
      	| array   { $$ = $1; }
	;

%%

#define YY_INPUT(buf, res, max) \
  res = jsonyy_string_input (buf, max);

void 
jsonyyerror_impl(const char *s) 
{
  sqlr_new_error("37000", "JSON1", "Parse failed");
}

int
jsonyywrap (void)
{
  return 1;
}

int jsonyy_string_input (char *buf, int max)
{
  int len = (int) strlen (json_str);
  if (len == 0) 
    return 0;
  if (len > max)
    len = max;
  memcpy (buf, json_str, len);
  json_str += len;
  return len;
}

void jsonyy_string_input_init (char * str)
{
   json_str = str;
}
