%{
#include "graphql.h"

void graphqlyyerror (const char *s);
caddr_t *graphql_tree;
caddr_t graphql_str;
int graphqlyylex (void);
extern int graphql_line;

char * valid_directive_locations[] = {
    "QUERY",
    "MUTATION",
    "SUBSCRIPTION",
    "FIELD",
    "FRAGMENT_DEFINITION",
    "FRAGMENT_SPREAD",
    "INLINE_FRAGMENT",
    "VARIABLE_DEFINITION",
    "SCHEMA",
    "SCALAR",
    "OBJECT",
    "FIELD_DEFINITION",
    "ARGUMENT_DEFINITION",
    "INTERFACE",
    "UNION",
    "ENUM",
    "ENUM_VALUE",
    "INPUT_OBJECT",
    "INPUT_FIELD_DEFINITION",
    NULL
};

char *
graphqlyy_directive_location (char * loc)
{
  char ** v;
  for (v = &valid_directive_locations[0]; NULL != *v; v++)
    {
      if (0 == strcmp (*v, loc))
        return loc;
    }
  graphqlyyerror ("INVALID LOCATION");
  return NULL;
}

%}

%union {
  caddr_t box;
  caddr_t *list;
  dk_set_t set;
}

%token BLK_BEGIN
%token BLK_END
%token ARR_BEGIN
%token ARR_END
%token LEFT_PAR
%token RIGHT_PAR
%token COLON
%token SYM_DOLLAR
%token SYM_AT
%token SYM_NOT
%token SYM_PIPE
%token SYM_AMP
%token SYM_EQ
%token ELLIPSIS

%token ON_L
%token <box> REPEATABLE_L
%token <box> FRAGMENT_L
%token <box> MUTATION_L
%token <box> SUBSCRIPTION_L
%token <box> SCHEMA_L
%token <box> SCALAR_L
%token <box> IMPLEMENTS_L
%token <box> INTERFACE_L
%token <box> DIRECTIVE_L
%token <box> UNION_L
%token <box> ENUM_L
%token <box> QUERY_L
%token <box> NAME_L
%token <box> TYPE_L
%token <box> INPUT_L

%token <box> STRING
%token <box> NUMBER
%token <box> TRUE_L
%token <box> FALSE_L
%token <box> NULL_L

%type <list> graphql
%type <list> selection_set
%type <set> operation
%type <set> operation_list
%type <list> arguments
%type <list> opt_arguments
%type <set> argument_list
%type <set> variables_list
%type <set> directives_list
%type <list> opt_variables
%type <list> opt_directives
%type <set> selection_list
%type <list> opt_selection_set
%type <list> selection
%type <list> field
%type <box> value
%type <box> variable
%type <box> opt_name
%type <list> named_type
%type <list> list_type
%type <list> type_name
%type <list> opt_on_type
%type <box> opt_default
%type <box> opt_repeatable
%type <box> array
%type <box> object_field
%type <box> object
%type <set> object_fields_list
%type <set> value_list
%type <set> value_list_opt

%type <set> type_system_definition_set
%type <list> type_system_definition
%type <box> opt_description
%type <set> root_operation_type_def_list
%type <list> root_operation_type_def
%type <list> opt_implements_interfaces
%type <set> implements_interfaces
%type <set> input_value_def
%type <set> input_value_def_list
%type <list> opt_arguments_def
%type <set> field_def
%type <set> fields_definition_list
%type <set> directive_locations
%type <set> union_members
%type <set> enum_values
%type <box> name

%%

graphql
	: operation_list { graphql_tree = t_list (2, GQL_TOP, t_list_to_array ($1)); }
        | type_system_definition_set    { graphql_tree = t_list (2, GQL_TYPE_SCHEMA, t_list_to_array ($1)); }
	;

/* type system */

opt_description
        : /* none */ { $$ = NULL; }
        | STRING { $$ = $1; }
        ;

root_operation_type_def
        : QUERY_L COLON name                 { $$ = t_list (2, GQL_QRY, $3); }
        | MUTATION_L COLON name              { $$ = t_list (2, GQL_MUTATION, $3); }
        | SUBSCRIPTION_L COLON name          { $$ = t_list (2, GQL_SUBS, $3); }
        ;

root_operation_type_def_list
        : root_operation_type_def { $$ = t_CONS ($1, NULL); }
        | root_operation_type_def_list root_operation_type_def { $$ = t_NCONC ($1, t_CONS ($2, NULL)); }
        ;

opt_implements_interfaces
        : /* none */ { $$ = NULL; }
        | implements_interfaces { $$ = t_list_to_array ($1); }
        ;

implements_interfaces
        : IMPLEMENTS_L SYM_AMP named_type { $$ = t_CONS (t_list (2, GQT_IFACE, $3), NULL); }
        | IMPLEMENTS_L named_type { $$ = t_CONS (t_list (2, GQT_IFACE, $2), NULL); }
        | implements_interfaces SYM_AMP named_type { $$ = t_NCONC ($1, t_CONS (t_list (2, GQT_IFACE, $3), NULL)); }
        ;

input_value_def
        : opt_description name COLON type_name opt_default opt_directives { $$ = t_CONS (t_list (6, GQT_INPUT, $2, $4, $5, $6, $1), NULL); }
        ;

input_value_def_list
        : input_value_def { $$ = $1; }
        | input_value_def_list input_value_def { $$ = t_NCONC ($1, $2); }
        ;

opt_arguments_def
        : /* none */ { $$ = NULL; }
        | LEFT_PAR input_value_def_list RIGHT_PAR { $$ = t_list_to_array ($2); }
        ;

name
        : NAME_L        { $$ = $1; }
        | QUERY_L       { $$ = $1; }
        | FRAGMENT_L    { $$ = $1; }
        | MUTATION_L    { $$ = $1; }
        | SUBSCRIPTION_L { $$ = $1; }
        | REPEATABLE_L  { $$ = $1; }
        | SCHEMA_L      { $$ = $1; }
        | TYPE_L        { $$ = $1; }
        | SCALAR_L      { $$ = $1; }
        | DIRECTIVE_L   { $$ = $1; }
        | UNION_L       { $$ = $1; }
        | ENUM_L        { $$ = $1; }
        | INPUT_L       { $$ = $1; }
        | IMPLEMENTS_L  { $$ = $1; }
        | INTERFACE_L   { $$ = $1; }
        ;

field_def
        : opt_description name opt_arguments_def COLON type_name opt_directives { $$ = t_CONS (t_list (6, GQT_FLD, $2, $3, $5, $6, $1), NULL); }
        ;

fields_definition_list
        : field_def  { $$ = $1; }
        | fields_definition_list field_def { $$ = t_NCONC ($1, $2); }
        ;

type_system_definition_set
        : type_system_definition { $$ = t_CONS ($1, NULL); }
        | type_system_definition_set type_system_definition  { $$ = t_NCONC ($1, t_CONS ($2, NULL)); }
        ;

opt_repeatable
        : /* none */ { $$ = (caddr_t)0; }
        | REPEATABLE_L { $$ = (caddr_t)1; }
        ;

directive_locations
        : name { $$ = t_CONS (graphqlyy_directive_location($1), NULL); }
        | SYM_PIPE name { $$ = t_CONS (graphqlyy_directive_location($2), NULL); }
        | directive_locations SYM_PIPE name { $$ = t_NCONC ($1, t_CONS (graphqlyy_directive_location ($3), NULL)); }
        ;

union_members
        : /* none */ { $$ = NULL; }
        | SYM_EQ name                   { $$ = t_CONS ($2, NULL); }
        | SYM_EQ SYM_PIPE name          { $$ = t_CONS ($3, NULL); }
        | union_members SYM_PIPE name   { $$ = t_NCONC ($1, t_CONS ($3, NULL)); }
        ;

enum_values
        : opt_description name opt_directives { $$ = t_CONS (t_list (4, GQT_ENUM_VAL, $1, $2, $3), NULL); }
        | enum_values opt_description name opt_directives { $$ = t_NCONC ($1, t_CONS (t_list (4, GQT_ENUM_VAL, $2, $3, $4), NULL)); }
        ;

type_system_definition
        : opt_description SCHEMA_L opt_directives BLK_BEGIN root_operation_type_def_list BLK_END
                { $$ = t_list (4, GQT_SCHEMA, $1, $3, t_list_to_array ($5)); }
        | opt_description TYPE_L name opt_implements_interfaces opt_directives BLK_BEGIN fields_definition_list BLK_END
                { $$ = t_list (6, GQT_OBJ, $1, $3, $4, $5, t_list_to_array ($7)); }
        | opt_description SCALAR_L name opt_directives  { $$ = t_list (4, GQT_SCALAR, $1, $3, $4); }
        | opt_description DIRECTIVE_L SYM_AT name opt_arguments_def opt_repeatable ON_L directive_locations
                { $$ = t_list (6, GQT_DIRECTIVE, $1, $4, $5, $6, t_list_to_array ($8)); }
        | opt_description UNION_L name opt_directives union_members { $$ = t_list (5, GQT_UNION, $1, $3, $4, t_list_to_array ($5)); }
        | opt_description ENUM_L name opt_directives BLK_BEGIN enum_values BLK_END { $$ = t_list (5, GQT_ENUM, $1, $3, $4, t_list_to_array ($6)); }
        | opt_description INPUT_L name opt_directives BLK_BEGIN input_value_def_list BLK_END
                { $$ = t_list (5, GQT_INPUT_DEF, $1, $3, $4, t_list_to_array ($6)); }
        | opt_description INTERFACE_L name opt_implements_interfaces opt_directives BLK_BEGIN fields_definition_list BLK_END
                { $$ = t_list (6, GQT_IFACE_DEF, $1, $3, $4, $5, t_list_to_array ($7)); }
        ;

/* executable */

operation_list
	: operation { $$ = $1; }
	| operation operation_list { $$ = t_NCONC ($1, $2); }
	;


named_type
        : name          { $$ = t_list (3, GQL_TYPE, $1, GQL_NULL); }
        | name SYM_NOT  { $$ = t_list (3, GQL_TYPE, $1, GQL_NON_NULL); }
        ;

list_type
        : ARR_BEGIN type_name ARR_END                { $$ = t_list (3, GQL_LIST_TYPE, $2, GQL_NULL); }
        | ARR_BEGIN type_name ARR_END SYM_NOT        { $$ = t_list (3, GQL_LIST_TYPE, $2, GQL_NON_NULL); }
        ;

type_name
        : named_type    { $$ = $1; }
        | list_type     { $$ = $1; }
        ;

opt_name
	: /* none */    { $$ = NULL; }
	| name          { $$ = $1; }
	;

opt_on_type
	: /* none */ { $$ = NULL; }
	| ON_L type_name { $$ = $2; }
	;

opt_default
        : /* none */ { $$ = NEW_DB_NULL; }
        | SYM_EQ value { $$ = $2; }
        ;

variables_list
	: variable COLON type_name opt_default opt_directives { $$ = t_NCONC (t_CONS ($1, NULL), t_CONS (t_list (4, GQL_VAR_TYPE, $3, $4, $5), NULL)); }
	| variables_list variable COLON type_name opt_default opt_directives { $$ = t_NCONC ($1,
                            t_NCONC (t_CONS ($2, NULL), t_CONS (t_list (4, GQL_VAR_TYPE, $4, $5, $6), NULL))); }
	;


opt_variables
	: /* none */ { $$ = NULL; }
	| LEFT_PAR variables_list RIGHT_PAR { $$ = t_list (2, GQL_VARS, t_list_to_array ($2)); }
	;

directives_list
	: SYM_AT name           { $$ = t_NCONC (t_CONS ($2, NULL), t_CONS (t_list (2, GQL_ARGS, t_list(0)), NULL)); }
	| SYM_AT name arguments { $$ = t_NCONC (t_CONS ($2, NULL), t_CONS ($3, NULL)); }
	| directives_list SYM_AT name { $$ = t_NCONC ($1,  t_NCONC (t_CONS ($3, NULL), t_CONS (t_list (2, GQL_ARGS, t_list(0)), NULL))); }
	| directives_list SYM_AT name arguments { $$ = t_NCONC ($1,  t_NCONC (t_CONS ($3, NULL), t_CONS ($4, NULL))); }
	;

opt_directives
	: /* none */ { $$ = NULL; }
	| directives_list { $$ = t_list (2, GQL_DIRECTIVES, t_list_to_array ($1)); }
	;

operation
	: QUERY_L opt_name opt_variables opt_directives selection_set
                    { $$ = t_CONS (t_list (5, GQL_QRY, $2, $5, $3, $4), NULL); }
	| FRAGMENT_L name opt_on_type opt_directives selection_set
                    { $$ = t_CONS (t_list (5, GQL_FRAG, $2, $3, $5, $4), NULL); }
	| MUTATION_L opt_name opt_variables opt_directives selection_set
                    { $$ = t_CONS (t_list (5, GQL_MUTATION, $2, $5, $3, $4), NULL); }
	| SUBSCRIPTION_L opt_name opt_variables opt_directives selection_set
                    { $$ = t_CONS (t_list (5, GQL_SUBS, $2, $5, $3, $4), NULL); }
	| selection_set { $$ = t_CONS (t_list (5, GQL_QRY, NULL, $1, NULL, NULL), NULL); }
	;

array /* a.k.a. LIST */
      	: ARR_BEGIN value_list_opt ARR_END { $$ = (box_t)t_list_to_array ($2);}
	;

object_field
        : name COLON value      { $$ = (caddr_t) t_list (3, GQL_OBJ_FIELD, $1, $3); }
        | name COLON variable   { $$ = (caddr_t) t_list (3, GQL_OBJ_FIELD, $1, $3); }
        ;

object_fields_list
        : object_field                             { $$ = t_CONS ($1, NULL); }
        | object_fields_list object_field          { $$ = t_NCONC ($1, t_CONS ($2, NULL)); }
        ;

object
        : BLK_BEGIN BLK_END                        { $$ = (caddr_t) t_list (2, GQL_OBJ, t_list (0)); }
        | BLK_BEGIN object_fields_list BLK_END     { $$ = (caddr_t) t_list (2, GQL_OBJ, t_list_to_array ($2)); }
        ;

value_list_opt
	: /* empty */ { $$ = NULL; }
	| value_list
	;

value_list
	: value { $$ = t_CONS ($1, NULL); }
	| value_list value { $$ = t_NCONC ($1, t_CONS($2, NULL)); }
	;

value
	: STRING        { $$ = $1; }
	| NUMBER        { $$ = $1; }
	| TRUE_L        { $$ = (caddr_t)1; }
	| FALSE_L       { $$ = (caddr_t)0; }
	| NULL_L        { $$ = NEW_DB_NULL; }
	| array         { $$ = $1; }
        | object        { $$ = $1; }
        | name          { $$ = $1; } /* ENUM */
	;

variable
	: SYM_DOLLAR name { $$ = (caddr_t) t_list (2, GQL_VAR, $2); }
	;

argument_list
	: name COLON value { $$ = t_NCONC (t_CONS ($1, NULL), t_CONS ($3, NULL)); }
	| name COLON variable { $$ = t_NCONC (t_CONS ($1, NULL), t_CONS ($3, NULL)); }
	| argument_list name COLON value { $$ = t_NCONC ($1,  t_NCONC (t_CONS ($2, NULL), t_CONS ($4, NULL))); }
	| argument_list name COLON variable { $$ = t_NCONC ($1,  t_NCONC (t_CONS ($2, NULL), t_CONS ($4, NULL))); }
	;

arguments
	: LEFT_PAR argument_list RIGHT_PAR { $$ = t_list (2, GQL_ARGS, t_list_to_array ($2)); }
	;

opt_arguments
	: /* none */ { $$ = NULL; }
	| arguments { $$ = $1; }
	;

selection_set
	: BLK_BEGIN selection_list BLK_END { $$ = t_list_to_array ($2); }
        ;

opt_selection_set  /* MUST return NULL if no selection, not an empty array  */
        : { $$ = NULL; }
        | selection_set { $$ = (BOX_ELEMENTS_0($1) > 0 ? $1 : NULL) ; }
        ;

field   /* 0:op, 1:field name, 2:args, 3:selection or zero, 4:alias, 5:plase for type(set further), 6:directives */
        : name opt_arguments opt_directives opt_selection_set { $$ = t_list (7, GQL_FIELD, $1, $2, $4, NULL, NULL, $3); }
        | name COLON name opt_arguments opt_directives opt_selection_set {  $$ = t_list (7, GQL_FIELD, $3, $4, $6, $1, NULL, $5); }
        ;

selection
        : field { $$ = $1; }
        | ELLIPSIS name opt_directives { $$ = t_list (3, GQL_FRAG_REF, $2, $3); }
        | ELLIPSIS opt_on_type opt_directives selection_set { $$ = t_list (4, GQL_INLINE_FRAG, $2, $3, $4); }
        ;


selection_list
	: selection { $$ = t_CONS ($1, NULL); }
	| selection selection_list { $$ = t_NCONC (t_CONS ($1, NULL), $2); }
	;

%%

void graphqlyyerror(const char *s)
{
  sqlr_new_error ("37000", "GQL01", "GRAPHQL parser failed: %.200s at line %d", s, graphql_line);
}

int graphqlyy_string_input (char *buf, int max)
{
  int len = (int) strlen (graphql_str);
  if (len == 0)
    return 0;
  if (len > max)
    len = max;
  memcpy (buf, graphql_str, len);
  graphql_str += len;
  return len;
}

void graphqlyy_string_input_init (char * str)
{
   graphql_str = str;
}

