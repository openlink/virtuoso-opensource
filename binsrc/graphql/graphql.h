#ifndef GRAPHQL_H
#define GRAPHQL_H

#include <stdlib.h>
#include <string.h>
#ifdef _USRDLL
#include "plugin.h"
#include "import_gate_virtuoso.h"
#endif
#include "sqlver.h"

#define YYERROR_VERBOSE 1

#ifdef _USRDLL
#define t_CONS(car,cdr)	t_cons ((caddr_t) car, (dk_set_t) cdr)
#define t_NCONC(x,y)	dk_set_conc ((dk_set_t) x, (dk_set_t) y)
#endif

#define GQL_NULL        (ptrlong)0
#define GQL_NON_NULL    (ptrlong)1

#define GQL_TOP		199
#define GQL_QRY		200
#define GQL_FIELD	201
#define GQL_ARGS	202
#define GQL_FRAG	203
#define GQL_FRAG_REF	204
#define GQL_MUTATION	205
#define GQL_SUBS	206
#define GQL_VARS	207
#define GQL_VAR	        208
#define GQL_DIRECTIVES	209
#define GQL_DIRECTIVE	210
#define GQL_TYPE	211
#define GQL_LIST_TYPE	212
#define GQL_OBJ         214
#define GQL_VAR_TYPE    215
#define GQL_OBJ_FIELD   216
#define GQL_INLINE_FRAG 217
#define GQL_TYPE_SCHEMA 512

typedef struct gql_token_s {
  int token;
  char * name;
} gql_token_t;

#define GQT_SCHEMA 1000
#define GQT_SCALAR 1001
#define GQT_OBJ 1002
#define GQT_IFACE 1003
#define GQT_DIRECTIVE 1004
#define GQT_ARGS 1005
#define GQT_FLD 1006
#define GQT_INPUT 1007
#define GQT_UNION 1008
#define GQT_ENUM 1009
#define GQT_ENUM_VAL 1010
#define GQT_IFACE_DEF 1011
#define GQT_INPUT_DEF 1012

#endif
