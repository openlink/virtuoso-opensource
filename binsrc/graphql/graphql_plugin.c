/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2023 OpenLink Software
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

#include "graphql.h"
#include "git_head.c"

extern void graphqlyy_reset ();
extern void graphqlyyparse ();
extern caddr_t *graphql_tree;
extern int graphqlyydebug;
extern void graphqlyy_string_input_init (char *str);
static dk_mutex_t *graphql_parse_mtx = NULL;
extern int graphql_line;

#define GQL_BRIDGE_VER "0.9.1"

static
caddr_t
bif_graphql_parse (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "graphql_parse");
  caddr_t tree = NULL;
  caddr_t err = NULL;
  mutex_enter (graphql_parse_mtx);
  MP_START ();
  graphqlyy_string_input_init (str);
  QR_RESET_CTX
  {
    graphqlyy_reset ();
    graphqlyyparse ();
    tree = box_copy_tree ((caddr_t) graphql_tree);
  }
  QR_RESET_CODE
  {
    du_thread_t *self = THREAD_CURRENT_THREAD;
    err = thr_get_error_code (self);
    thr_set_error_code (self, NULL);
    tree = NULL;
    /*no POP_QR_RESET */ ;
  }
  END_QR_RESET;
  MP_DONE ();
  mutex_leave (graphql_parse_mtx);
  if (!tree)
    sqlr_resignal (err);
  return tree;
}

static
caddr_t
bif_graphql_token (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t ret = NULL, tid = (caddr_t) bif_long_arg (qst, args, 0, "gql_token");
  gql_token_t *tok;
  gql_token_t tokens[] = {
    {GQL_TOP, "top"},
    {GQL_QRY, "query"},
    {GQL_FIELD, "field"},
    {GQL_ARGS, "arguments"},
    {GQL_FRAG, "fragment"},
    {GQL_FRAG_REF, "fragment_ref"},
    {GQL_MUTATION, "mutation"},
    {GQL_SUBS, "subscription"},
    {GQL_VARS, "variables"},
    {GQL_VAR, "variable"},
    {GQL_DIRECTIVES, "directives"},
    {GQL_DIRECTIVE, "directive"},
    {GQL_TYPE, "type"},
    {GQL_LIST_TYPE, "list"},
    {0, NULL}
  };
  for (tok = tokens; tok->token; tok++)
    {
      if ((ptrlong) tid == tok->token)
	{
	  ret = box_dv_short_string (tok->name);
	  break;
	}
    }
  return ret ? ret : NEW_DB_NULL;
}

#define is_frag_ref(x)      (ARRAYP(x) && 3 == BOX_ELEMENTS_0(x) && (((caddr_t*)x)[0]) == (caddr_t)GQL_FRAG_REF)
#define is_inline_frag(x)   (ARRAYP(x) && 4 == BOX_ELEMENTS_0(x) && (((caddr_t*)x)[0]) == (caddr_t)GQL_INLINE_FRAG)
#define is_frag(x)          (ARRAYP(x) && 4 == BOX_ELEMENTS_0(x) && (((caddr_t*)x)[0]) == (caddr_t)GQL_FRAG)
#define is_top(x)           (ARRAYP(x) && BOX_ELEMENTS_0(x) > 1 && (((caddr_t*)x)[0]) == (caddr_t)GQL_TOP)
#define is_field(x)           (ARRAYP(x) && 7 == BOX_ELEMENTS_0(x) && (((caddr_t*)x)[0]) == (caddr_t)GQL_FIELD)
#define is_args(x)          (ARRAYP(x) && BOX_ELEMENTS_0(x) > 1 && (((caddr_t*)x)[0]) == (caddr_t)GQL_ARGS)
#define is_var(x)           (ARRAYP(x) && 2 == BOX_ELEMENTS_0(x) && (((caddr_t*)x)[0]) == (caddr_t)GQL_VAR)
#define is_vars_defs(x)     (ARRAYP(x) && 2 == BOX_ELEMENTS_0(x) && (((caddr_t*)x)[0]) == (caddr_t)GQL_VARS)
#define is_expression(x)    (ARRAYP(x) && 2 == BOX_ELEMENTS_0(x) && (((caddr_t*)x)[0]) == (caddr_t)GQL_OBJ \
                                                                    && ARRAYP(((caddr_t*)x)[1]) \
                                                                    && 1 == BOX_ELEMENTS_0 (((caddr_t*)x)[1]))
#define is_obj(x)           (ARRAYP(x) && 2 == BOX_ELEMENTS_0(x) && (((caddr_t*)x)[0]) == (caddr_t)GQL_OBJ)
#define is_directives(x)    (ARRAYP(x) && 2 == BOX_ELEMENTS_0(x) && (((caddr_t*)x)[0]) == (caddr_t)GQL_DIRECTIVES)


#define GQL_BIF(n) \
static caddr_t \
bif_gql_##n (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args) \
{ \
  caddr_t tree = bif_arg (qst, args, 0, "gql_" #n); \
  if (is_##n(tree)) \
    return box_num(1); \
  return box_num(0); \
} \

#define GQL_BIF_DEFINE(n) bif_define ("gql_" #n, bif_gql_##n)

GQL_BIF (frag_ref)
GQL_BIF (frag)
GQL_BIF (top)
GQL_BIF (field)
GQL_BIF (args)
GQL_BIF (var)
GQL_BIF (vars_defs)
GQL_BIF (expression)
GQL_BIF (obj)
GQL_BIF (directives)
GQL_BIF (inline_frag)

void sqls_define_graphql (void);
void graphql_cache_resources (void);

void
virt_graphql_postponed_action (char *mode)
{
  graphql_cache_resources ();
  sqls_define_graphql ();
}


static void
graphql_plugin_connect ()
{
  graphql_parse_mtx = mutex_allocate ();
  bif_define ("graphql_parse", bif_graphql_parse);
  bif_define ("gql_token", bif_graphql_token);
  GQL_BIF_DEFINE (frag_ref);
  GQL_BIF_DEFINE (frag);
  GQL_BIF_DEFINE (top);
  GQL_BIF_DEFINE (field);
  GQL_BIF_DEFINE (args);
  GQL_BIF_DEFINE (var);
  GQL_BIF_DEFINE (vars_defs);
  GQL_BIF_DEFINE (expression);
  GQL_BIF_DEFINE (obj);
  GQL_BIF_DEFINE (directives);
  GQL_BIF_DEFINE (inline_frag);
  dk_set_push (get_srv_global_init_postponed_actions_ptr (), virt_graphql_postponed_action);
}


static unit_version_t plugin_graphql_version = {
  "GraphQL/SPARQL Bridge",	/*!< Title of unit, filled by unit */
  GQL_BRIDGE_VER " (" GIT_HEAD_STR ")",	/*!< Version number, filled by unit */
  "OpenLink Software",		/*!< Plugin's developer, filled by unit */
  "Support functions for GraphQL/SPARQL Bridge",	/*!< Any additional info, filled by unit */
  0,				/*!< Error message, filled by unit loader */
  0,				/*!< Name of file with unit's code, filled by unit loader */
  graphql_plugin_connect,	/*!< Pointer to connection function, cannot be 0 */
  0,				/*!< Pointer to disconnection function, or 0 */
  0,				/*!< Pointer to activation function, or 0 */
  0,				/*!< Pointer to deactivation function, or 0 */
  &_gate
};


unit_version_t *CALLBACK
graphql_check (unit_version_t * in, void *appdata)
{
  return &plugin_graphql_version;
}
