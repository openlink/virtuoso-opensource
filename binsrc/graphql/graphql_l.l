%option 8bit
%option never-interactive
%option noyywrap
%option nounput
%{
#include "graphql.h"
#include "graphql_p.h"

#undef YY_INPUT
#define YY_INPUT(buf, res, max) \
  res = graphqlyy_string_input (buf, max);

extern void graphqlyyerror (const char *s);
extern int graphqlyy_string_input (char *buf, int max);
int graphql_line;
struct sparp_s; /* forward */
#define SPAR_STRLITERAL_SPARQL_STRING	0
#define SPAR_STRLITERAL_JSON_STRING	1
#define SPAR_STRLITERAL_SPARQL_QNAME	2
extern caddr_t spar_unescape_strliteral (struct sparp_s *sparp, const char *strg, int count_of_quotes, int mode);
#define BOX_TOKEN_L graphqlyylval.box = t_box_dv_short_nchars (graphqlyytext, strlen (graphqlyytext))
%}

%x STRLIT
%x STRLIT_DQ

HEX             ([0-9A-Fa-f])
S_NL		((\r\n)|(\n\r)|\n|\r)
DQ_PLAIN	([^\x00-\x1f\\""\r\n]|[\t])
DQ_ECHAR        ([\\]([bfnrt\\""''/]|("u"{HEX}{HEX}{HEX}{HEX})))

%%
<INITIAL>"{"	{ return BLK_BEGIN; }
<INITIAL>"}"	{ return BLK_END; }
<INITIAL>"["	{ return ARR_BEGIN; }
<INITIAL>"]"	{ return ARR_END; }
<INITIAL>"("	{ return LEFT_PAR; }
<INITIAL>")"	{ return RIGHT_PAR; }
<INITIAL>":"	{ return COLON; }
<INITIAL>"..."  { return ELLIPSIS; }
<INITIAL>"!"	{ return SYM_NOT; }
<INITIAL>"|"	{ return SYM_PIPE; }
<INITIAL>"$"	{ return SYM_DOLLAR; }
<INITIAL>"@"	{ return SYM_AT; }
<INITIAL>"&"	{ return SYM_AMP; }
<INITIAL>"="	{ return SYM_EQ; }

<INITIAL>query          { BOX_TOKEN_L; return QUERY_L; }
<INITIAL>fragment       { BOX_TOKEN_L; return FRAGMENT_L; }
<INITIAL>on             { BOX_TOKEN_L; return ON_L; }
<INITIAL>mutation       { BOX_TOKEN_L; return MUTATION_L; }
<INITIAL>subscription   { BOX_TOKEN_L; return SUBSCRIPTION_L; }
<INITIAL>repeatable     { BOX_TOKEN_L; return REPEATABLE_L; }
<INITIAL>schema         { BOX_TOKEN_L; return SCHEMA_L; }
<INITIAL>type           { BOX_TOKEN_L; return TYPE_L; }
<INITIAL>scalar         { BOX_TOKEN_L; return SCALAR_L; }
<INITIAL>directive      { BOX_TOKEN_L; return DIRECTIVE_L; }
<INITIAL>union          { BOX_TOKEN_L; return UNION_L; }
<INITIAL>enum           { BOX_TOKEN_L; return ENUM_L; }
<INITIAL>input          { BOX_TOKEN_L; return INPUT_L; }
<INITIAL>implements     { BOX_TOKEN_L; return IMPLEMENTS_L; }
<INITIAL>interface      { BOX_TOKEN_L; return INTERFACE_L; }

<INITIAL>[""][""][""]           { yymore(); BEGIN (STRLIT_DQ); };
<STRLIT_DQ>[""][""]([""]+)      {
                                  BEGIN (INITIAL);
                                  graphqlyylval.box =  spar_unescape_strliteral (NULL, graphqlyytext, 3, SPAR_STRLITERAL_JSON_STRING);
                                  return STRING;
                                }
<STRLIT_DQ>((([""]([""]?))?({DQ_PLAIN}|{DQ_ECHAR}|{S_NL}))+)  { yymore(); }

<INITIAL>"\""[^\\\"\n\r\t]*	{ yymore(); BEGIN(STRLIT); }
<INITIAL>"\""[^\\\"\n\r\t]*"\"" 	{
                   graphqlyylval.box = t_box_dv_short_nchars (graphqlyytext+1, strlen (graphqlyytext)-2);
		   return STRING;
		}
<STRLIT>[^\\\"\n\r\t]*"\"" 	{
		   BEGIN(INITIAL);
                   graphqlyylval.box = spar_unescape_strliteral (NULL, graphqlyytext, 1, SPAR_STRLITERAL_JSON_STRING);
		   return STRING;
		}
<STRLIT>"\\"([\\\"bfnrt/]|(u{HEX}{HEX}{HEX}{HEX})) { yymore (); }
<STRLIT>[^\\\"\n\r\t]* { yymore (); }
<STRLIT>[\n\r]	{ graphqlyyerror ("line break is not allowed in JSON strings"); }
<STRLIT>"\t"	{ graphqlyyerror ("tab character is not allowed in JSON strings"); }
<STRLIT>"\\"	{ graphqlyyerror ("invalid escaping sequence in a string"); }

<INITIAL>true	{ return TRUE_L; }
<INITIAL>false	{ return FALSE_L; }
<INITIAL>null	{ return NULL_L; }

<INITIAL>[A-Za-z_][A-Za-z0-9_]* { BOX_TOKEN_L; return NAME_L; }

<INITIAL>"-"?(([1-9][0-9]*)|"0")	{
		  caddr_t err = NULL;
                  int64 n = safe_atoi (graphqlyytext, &err);
		  if (err)
                    {
		      dk_free_tree (err);
                      graphqlyyerror ("bad integer constant");
		    }
                  graphqlyylval.box = t_box_num_and_zero (n);
		  return NUMBER;
		}
<INITIAL>"-"?[0-9]+"."[0-9]* |
<INITIAL>"-"?"."[0-9]+ {
  numeric_t num = t_numeric_allocate ();
  int rc = numeric_from_string (num, graphqlyytext);
  if (NUMERIC_STS_SUCCESS == rc)
    {
      graphqlyylval.box = (caddr_t) num;
      return NUMBER;
    }
  graphqlyylval.box = t_box_double (atof (graphqlyytext));
  return NUMBER;
}

<INITIAL>"-"?[0-9]+[eE][+-]?[0-9]+	|
<INITIAL>"-"?[0-9]+"."[0-9]+[eE][+-]?[0-9]+ |
<INITIAL>"-"?"."[0-9]+[eE][+-]?[0-9]+	{
  graphqlyylval.box = t_box_double (atof (graphqlyytext));
  return NUMBER;
}

<INITIAL>[+-]?[0-9.eE+-]+ { graphqlyyerror ("syntax error in number"); }

<INITIAL>[ \r\t,]+
<INITIAL>"#"([^\n]*)[\n]   { graphql_line++; }
<INITIAL>[\n]   { graphql_line++; }
<INITIAL>.	{ graphqlyyerror ("character outside string"); }

%%
void graphqlyy_reset (void)
{
  graphql_line = 1;
  graphqlyyrestart (NULL);
  BEGIN INITIAL;
}
