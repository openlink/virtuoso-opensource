/*
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

%{
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
int json_line;
%}

%union {
  caddr_t box;
  caddr_t *list;
  dk_set_t revlist;
}

%token JSON_OBJ_BEGIN
%token JSON_OBJ_END
%token JSON_ARR_BEGIN
%token JSON_ARR_END
%token JSON_COLON
%token JSON_COMMA

%token <box> JSON_NAME
%token <box> JSON_SQSTRING
%token <box> JSON_DQSTRING
%token <box> JSON_NUMBER
%token <box> JSON_TRUE_L
%token <box> JSON_FALSE_L
%token <box> JSON_NULL_L

%type <box> object
%type <box> jsondoc
%type <revlist> members
%type <box> name_or_str
%type <box> value
%type <box> array
%type <revlist> value_list

%%

jsondoc
	: object { json_tree = (caddr_t *) $1; }
	| array { json_tree = (caddr_t *) $1; }
	;

object
	: JSON_OBJ_BEGIN JSON_OBJ_END		{ $$ = (caddr_t)t_list (2, t_alloc_box (0, DV_COMPOSITE), t_box_string ("structure")); }
        | JSON_OBJ_BEGIN members JSON_OBJ_END	{ $$ = (caddr_t)t_revlist_to_array ($2); }
     	;

members
	: name_or_str JSON_COLON value {
		dk_set_t res = NULL;
		t_set_push (&res, t_alloc_box (0, DV_COMPOSITE));
		t_set_push (&res, t_box_string ("structure"));
		t_set_push (&res, $1);
		t_set_push (&res, $3);
		$$ = res; }
	| members JSON_COMMA name_or_str JSON_COLON value	{
		$$ = $1; t_set_push (&($$), $3); t_set_push (&($$), $5); }
	| members JSON_COMMA error		{ jsonyyerror ("pair of field name and value is expected after ','"); }
	;

name_or_str
	: JSON_NAME
	| JSON_SQSTRING
	| JSON_DQSTRING
	;

array
	: JSON_ARR_BEGIN JSON_ARR_END		{ $$ = (caddr_t)t_alloc_list (0);}
	| JSON_ARR_BEGIN value_list JSON_ARR_END	{ $$ = (caddr_t)t_revlist_to_array ($2);}
	;

value_list
	: value				{ $$ = NULL; t_set_push (&($$), $1); }
	| value_list JSON_COMMA value	{ $$ = $1; t_set_push (&($$), $3); }
	| value_list JSON_COMMA error	{ jsonyyerror ("array member is expected after ','"); }
	;


value
	: JSON_NAME		{ jsonyyerror ("name without quotes is misused as a value"); }
	| JSON_SQSTRING	{ $$ = $1; }
	| JSON_DQSTRING	{ $$ = $1; }
      	| JSON_NUMBER	{ $$ = $1; }
	| JSON_TRUE_L	{ $$ = t_box_num (1); }
	| JSON_FALSE_L	{ $$ = t_box_num (0); }
	| JSON_NULL_L	{ $$ = t_alloc_box (0, DV_DB_NULL); }
	| object  { $$ = $1; }
      	| array   { $$ = $1; }
	;

%%

#define YY_INPUT(buf, res, max) \
  res = jsonyy_string_input (buf, max);

void
jsonyyerror_impl(const char *s)
{
  sqlr_new_error ("37000", "JSON1", "JSON parser failed: %.200s at line %d", s, json_line);
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
