/*
 *  xpathp.y
 *
 *  $Id$
 *
 *  SQL Parser
 *
 *   This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *   project.
 *
 *   Copyright (C) 1998-2014 OpenLink Software
 *
 *   This project is free software; you can redistribute it and/or modify it
 *   under the terms of the GNU General Public License as published by the
 *   Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *   This program is distributed in the hope that it will be useful, but
 *   WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *   General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License along
 *   with this program; if not, write to the Free Software Foundation, Inc.,
 *   51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

%pure_parser
%parse-param {xpp_t * xpp_arg}
%lex-param {xpp_t * xpp_arg}

%{

#include "libutil.h"
#include "sqlnode.h"
#include "xpathp_impl.h"
#include "sqlpar.h"
#include "sqlpfn.h"
/*#include "langfunc.h"*/

#ifdef DEBUG
#define xpyyerror(xpp_arg, strg) xpyyerror_impl_1(xpp_arg, NULL, yystate, yyssa, yyssp, (strg))
#else
#define xpyyerror(xpp_arg, strg) xpyyerror_impl(xpp_arg, NULL, (strg))
#endif

#ifdef XPYYDEBUG
#define YYDEBUG 1
#endif

#define xpyylex(lval_ptr, param) xpyylex_from_xpp_bufs ((caddr_t *)(lval_ptr), ((xpp_t *)(param)))

#define bmk_offset xpp_curr_lexem_bmk.xplb_offset
#define bmk_bufs_tail xpp_curr_lexem_bmk.xplb_lexem_bufs_tail
int xpyylex_from_xpp_bufs (caddr_t *yylval, xpp_t *xpp)
{
  xp_lexem_t *xpl;
  while (xpp->bmk_offset >= xpp->xpp_lexem_buf_len)
    {
      xpp->bmk_bufs_tail = xpp->bmk_bufs_tail->next;
      if (NULL == xpp->bmk_bufs_tail)
	{
	  /*xpp->xpp_curr_lexem = NULL; -- commented out to have at least 'some' current lexem */
	  return 0;
	}
      xpp->xpp_lexem_buf_len = box_length (xpp->bmk_bufs_tail->data) / sizeof (xp_lexem_t);
      xpp->bmk_offset = 0;
    }
  xpl = ((xp_lexem_t *)(xpp->bmk_bufs_tail->data)) + xpp->bmk_offset;
  yylval[0] = xpl->xpl_sem_value;
  /* Destructive read is no longer usable because re-compilation of xmlview(smth)/... should read twice.
  xpl->xpl_sem_value = NULL; */
  xpp->xpp_curr_lexem = xpl;
  xpp->bmk_offset += 1;
  return (int) xpl->xpl_lex_value;
}

#define PUSH_STRING_ARG_OF_CONCAT(arglist, strliteral) \
  do \
    { \
      if (1 != box_length((strliteral))) \
	dk_set_push (&(arglist), xp_make_literal_tree (xpp_arg, (strliteral), 1)); \
    } while (0)

#define XBIN_OP(target,opq,l,r) target = xtlist(xpp_arg, 4, (ptrlong)opq, l, r, xe_new_xqst (xpp_arg, XQST_REF))

#define XPP_PROLOG_SET(field,name,val) \
  do { \
      if (xpp_arg->xpp_xp_env->field) \
        xpyyerror (xpp_arg, "The prolog contains more than one declaration of " name); \
      xpp_arg->xpp_xp_env->field = val; \
    } while (0)

%}

/* symbolic tokens */
%union {
  caddr_t box;
  ptrlong token_type;
  XT *tree;
  XT **trees;
  caddr_t *fts;
  dk_set_t list;
  dk_set_t backstack;
  xp_lexbmk_t *bookmark;
  void *nothing;
}

%token __PUNCT_BEGIN	/* Delimiting value for syntax highlighting */

%token _AT		/*:: PUNCT("@"), XQ, LAST("@"), NULL ::*/
%token _ASSIGN		/*:: PUNCT(":="), XQ, LAST("let $x :="), NULL ::*/
%token _COLON		/*:: PUNCT(":"), XQ, LAST(":"), LAST("a:"), XP, LAST(":"), NULL ::*/
%token _COLON_COLON	/*:: PUNCT("::"), XQ, MISS("ancestor-or-self::"), LAST("nosuch::"), XP, MISS("ancestor-or-self::"), LAST("nosuch::"), NULL ::*/
%token _DOLLAR		/*:: PUNCT("$"), XQ, LAST1("$x"), LAST1("$ xx"), LAST1("$(::pragma index::)xx"), LAST1("$(::pragma virt:index::)xx"), MISS("for $x"), LAST1("$x:y"), ERR("$x:y:z"), NULL ::*/
%token _DOT		/*:: PUNCT("."), XQ, LAST("."), LAST("./."), MISS(".."), XP, LAST("."), LAST("./."), MISS(".."), NULL ::*/
%token _DOT_DOT		/*:: PUNCT(".."), NULL ::*/
%token _EQ		/*:: PUNCT("="), NULL ::*/
%token _GE		/*:: PUNCT(">="), NULL ::*/
%token _GT		/*:: PUNCT(">"), NULL ::*/
%token _GT_OF_TAG	/*:: PUNCT(">"), NULL ::*/
%token _GT_GT		/*:: PUNCT(">>"), XQ, LAST1("and >> or"), NULL ::*/
%token _LE		/*:: PUNCT("<="), NULL ::*/
%token _LPAR_LSQBRA	/*:: PUNCT("(["), NULL ::*/
%token _LT		/*:: PUNCT("<"), XQ, LAST1("and < or"), MISS("a<<b"), MISS("<a/>"), XP, LAST1("a<b"), NULL ::*/
%token _LT_OF_TAG	/*:: PUNCT("<"), XQ, LAST("<"), LAST1("<a"), MISS("a + b < c"), XP, MISS("<a>"), NULL ::*/
%token _LT_LT		/*:: PUNCT("<<"), XQ, LAST1("and << or"), NULL ::*/
%token _LT_SLASH	/*:: PUNCT("</"), XQ, LAST("<a></"), LAST1("<a></{"), MISS("a</b"), ERR("</a>"), NULL ::*/
%token _LT_BANG_CDATA	/*:: PUNCT("<![CDATA["), NULL ::*/
%token _LT_BANG_MINUS_MINUS /*:: PUNCT("<!--"), NULL ::*/
%token _LT_QMARK	/*:: PUNCT("<?"), NULL ::*/
%token _MINUS		/*:: PUNCT("-"), NULL ::*/
%token _NOT_EQ		/*:: PUNCT("!="), NULL ::*/
%token _NOT_SAME	/*:: PUNCT("!=="), NULL ::*/
%token _PLUS		/*:: PUNCT("+"), NULL ::*/
%token _POINTER_VIA_ID	/*:: PUNCT("=>"), NULL ::*/
%token _SAME		/*:: PUNCT("=="), NULL ::*/
%token _SLASH		/*:: PUNCT("/"), NULL ::*/
%token _SLASH_GT	/*:: PUNCT("/>"), NULL ::*/
%token _SLASH_SLASH	/*:: PUNCT("//"), NULL ::*/
%token _STAR		/*:: PUNCT("*"), XQ, LAST("*"), LAST("/*"), MISS("a:*"), MISS("*:a"), XP, LAST("*"), LAST("/*"), NULL ::*/
%token _STAR_COLON	/*:: PUNCT("*:"), NULL ::*/
%token _RPAR_AS_L	/*:: PUNCT(")as"), NULL ::*/
%token _RPAR_PLUS	/*:: PUNCT(")+"), NULL ::*/
%token _RPAR_QMARK	/*:: PUNCT(")?"), NULL ::*/
%token _RPAR_STAR	/*:: PUNCT(")*"), NULL ::*/
%token _RSQBRA_LSQBRA	/*:: PUNCT("]["), XP, LAST("[xmlns:a='http://a'] ["), NULL ::*/

%token A_ANCESTOR		/*:: PUNCT("ancestor::")		, XQ, LAST("ancestor::")		, XP, LAST("ancestor::"), NULL ::*/
%token A_ANCESTOR_OR_SELF	/*:: PUNCT("ancestor-or-self::")	, XQ, LAST("ancestor-or-self::")	, XP, LAST("ancestor-or-self::"), NULL ::*/
%token A_ATTRIBUTE		/*:: PUNCT("attribute::")		, XQ, LAST("attribute::")		, XP, LAST("attribute::"), NULL ::*/
%token A_CHILD			/*:: PUNCT("child::")			, XQ, LAST("child::")			, XP, LAST("child::"), NULL ::*/
%token A_DESCENDANT		/*:: PUNCT("descendant::")		, XQ, LAST("descendant::")		, XP, LAST("descendant::"), NULL ::*/
%token A_DESCENDANT_OR_SELF	/*:: PUNCT("descendant-or-self::")	, XQ, LAST("descendant-or-self::")	, XP, LAST("descendant-or-self::"), NULL ::*/
%token A_FOLLOWING		/*:: PUNCT("following::")		, XQ, LAST("following::")		, XP, LAST("following::"), NULL ::*/
%token A_FOLLOWING_SIBLING	/*:: PUNCT("following-sibling::")	, XQ, LAST("following-sibling::")	, XP, LAST("following-sibling::"), NULL ::*/
%token A_NAMESPACE		/*:: PUNCT("namespace::")		, XQ, LAST("namespace::")		, XP, LAST("namespace::"), NULL ::*/
%token A_PARENT			/*:: PUNCT("parent::")			, XQ, LAST("parent::")			, XP, LAST("parent::"), NULL ::*/
%token A_PRECEDING		/*:: PUNCT("preceding::")		, XQ, LAST("preceding::")		, XP, LAST("preceding::"), NULL ::*/
%token A_PRECEDING_SIBLING	/*:: PUNCT("preceding-sibling::")	, XQ, LAST("preceding-sibling::")	, XP, LAST("preceding-sibling::"), NULL ::*/
%token A_SELF			/*:: PUNCT("self::")			, XQ, LAST("self::")			, XP, LAST("self::"), NULL ::*/

%token K_AND			/*:: PUNCT("and")			, XQ, LAST("a and"), MISS("and"), XP, LAST("a and"), NULL ::*/
%token K_DIV			/*:: PUNCT("div")			, XQ, LAST("a div"), MISS("div"), XP, LAST("a div"), NULL ::*/
%token K_IDIV			/*:: PUNCT("idiv")			, XQ, LAST("a idiv"), MISS("idiv"), XP, MISS("a idiv"), NULL ::*/
%token K_LIKE			/*:: PUNCT("like")			, XQ, LAST("a like"), MISS("like"), XP, LAST("a like"), NULL ::*/
%token K_MOD			/*:: PUNCT("mod")			, XQ, LAST("a mod"), MISS("mod"), XP, LAST("a mod"), NULL ::*/
%token K_NEAR			/*:: PUNCT("near"), NULL ::*/
%token K_NOT			/*:: PUNCT("not"), NULL ::*/
%token K_OR			/*:: PUNCT("or")			, XQ, LAST("a or"), MISS("or"), XP, LAST("a or"), NULL ::*/

%token K2_EQ_L			/*:: PUNCT("eq"), NULL ::*/
%token K2_GE_L			/*:: PUNCT("ge"), NULL ::*/
%token K2_GT_L			/*:: PUNCT("gt"), NULL ::*/
%token K2_LE_L			/*:: PUNCT("le"), NULL ::*/
%token K2_LT_L			/*:: PUNCT("lt"), NULL ::*/
%token K2_NE_L			/*:: PUNCT("ne"), NULL ::*/

%token AFTER_L				/*:: PUNCT("after"), XQ, NULL ::*/
%token AS_L				/*:: PUNCT("as"), XQ, NULL ::*/
%token AT_L				/*:: PUNCT("at"), XQ, NULL ::*/
%token ASCENDING_L			/*:: PUNCT("ascending"), XQ, NULL ::*/
%token ATTRIBUTE_LBRA_L			/*:: PUNCT("attribute{"), XQ, NULL ::*/
%token ATTRIBUTE_LPAR_L			/*:: PUNCT("attribute("), XQ, NULL ::*/
%token BEFORE_L				/*:: PUNCT("before"), XQ, NULL ::*/
%token CASE_L				/*:: PUNCT("case"), XQ, NULL ::*/
%token COLLATION_L			/*:: PUNCT("castable as"), XQ, NULL ::*/
%token COMMENT_LBRA_L			/*:: PUNCT("comment {"), XQ, NULL ::*/
%token COMMENT_LPAR_L			/*:: PUNCT("comment ("), XQ, NULL ::*/
%token CONTEXT_L			/*:: PUNCT("context"), XQ, NULL ::*/
%token DECLARE_CONSTRUCTION_PRESERVE_L	/*:: PUNCT("declare construction preserve"), XQ, LAST("declare  construction  preserve"), NULL ::*/
%token DECLARE_CONSTRUCTION_STRIP_L	/*:: PUNCT("declare construction strip"), XQ, LAST("declare  construction  strip"), NULL ::*/
%token DECLARE_BASE_URI_L		/*:: PUNCT("declare base-uri"), XQ, LAST("declare  base-uri"), NULL ::*/
%token DECLARE_DEFAULT_COLLATION_L	/*:: PUNCT("declare default collation"), XQ, LAST("declare  default  collation"), NULL ::*/
%token DECLARE_DEFAULT_ELEMENT_L	/*:: PUNCT("declare default element"), XQ, LAST("declare  default  element"), NULL ::*/
%token DECLARE_DEFAULT_FUNCTION_L	/*:: PUNCT("declare default function"), XQ, LAST("declare  default  function"), NULL ::*/
%token DECLARE_FUNCTION_L		/*:: PUNCT("declare function"), XQ, LAST("declare  function"), NULL ::*/
%token DECLARE_NAMESPACE_L		/*:: PUNCT("declare namespace"), XQ, LAST("declare  namespace"), NULL ::*/
%token DECLARE_ORDERING_ORDERED_L	/*:: PUNCT("declare ordering ordered"), XQ, LAST("declare  ordering  ordered"), NULL ::*/
%token DECLARE_ORDERING_UNORDERED_L	/*:: PUNCT("declare ordering unordered"), XQ, LAST("declare  ordering  unordered"), NULL ::*/
%token DECLARE_VALIDATION_LAX_L		/*:: PUNCT("declare validation lax"), XQ, NULL ::*/
%token DECLARE_VALIDATION_SKIP_L	/*:: PUNCT("declare validation skip"), XQ, NULL ::*/
%token DECLARE_VALIDATION_STRICT_L	/*:: PUNCT("declare validation strict"), XQ, NULL ::*/
%token DECLARE_VARIABLE_DOLLAR_L	/*:: PUNCT("declare validation dollar"), XQ, NULL ::*/
%token DECLARE_XMLSPACE_PRESERVE_L	/*:: PUNCT("declare xmlspace preserve"), XQ, NULL ::*/
%token DECLARE_XMLSPACE_STRIP_L		/*:: PUNCT("declare xmlspace strip"), XQ, NULL ::*/
%token DEFAULT_L			/*:: PUNCT("default"), XQ, NULL ::*/
%token DEFAULT_ELEMENT_L		/*:: PUNCT("default element"), XQ, NULL ::*/
%token DELETE_L				/*:: PUNCT("delete"), XQ, NULL ::*/
%token DESCENDING_L			/*:: PUNCT("descending"), XQ, NULL ::*/
%token DOCUMENT_LBRA_L			/*:: PUNCT("document {"), XQ, NULL ::*/
%token DOCUMENT_NODE_LPAR_L		/*:: PUNCT("document-node ("), XQ, NULL ::*/
%token ELEMENT_LBRA_L			/*:: PUNCT("element {"), XQ, NULL ::*/
%token ELEMENT_LPAR_L			/*:: PUNCT("element ("), XQ, NULL ::*/
%token ELSE_L				/*:: PUNCT("else"), XQ, NULL ::*/
%token EMPTY_GREATEST_L			/*:: PUNCT("empty greatest"), XQ, NULL ::*/
%token EMPTY_LEAST_L			/*:: PUNCT("empty least"), XQ, NULL ::*/
%token EMPTY_LPAR_RPAR_L		/*:: PUNCT("empty ()"), XQ, NULL ::*/
%token EVERY_DOLLAR_L			/*:: PUNCT("every $"), XQ, NULL ::*/
%token EXCEPT_L				/*:: PUNCT("except"), XQ, NULL ::*/
%token EXTENSION_L			/*:: PUNCT("extension"), XQ, NULL ::*/
%token EXTERNAL_L			/*:: PUNCT("external"), XQ, NULL ::*/
%token FOR_DOLLAR_L			/*:: PUNCT("for $"), XQ, NULL ::*/
%token FREETEXT_L			/*:: PUNCT("freetext"), XQ, NULL ::*/
%token GLOBAL_L				/*:: PUNCT("global"), XQ, NULL ::*/
%token IF_LPAR_L			/*:: PUNCT("if ("), XQ, NULL ::*/
%token IMPORT_MODULE_L			/*:: PUNCT("import module"), XQ, LAST("import  module"), NULL ::*/
%token IMPORT_SCHEMA_L			/*:: PUNCT("import schema"), XQ, LAST("import  schema"), NULL ::*/
%token INSTANCE_OF_L			/*:: PUNCT("instance of"), XQ, NULL ::*/
%token INTERSECT_L			/*:: PUNCT("intersect"), XQ, NULL ::*/
%token IN_L				/*:: PUNCT("in"), XQ, NULL ::*/
%token ITEM_LPAR_RPAR_L			/*:: PUNCT("item ()"), XQ, NULL ::*/
%token ITEM_LPAR_RPAR_PLUS_L		/*:: PUNCT("item ()+"), XQ, NULL ::*/
%token ITEM_LPAR_RPAR_QMARK_L		/*:: PUNCT("item ()?"), XQ, NULL ::*/
%token ITEM_LPAR_RPAR_STAR_L		/*:: PUNCT("item ()*"), XQ, NULL ::*/
%token LAX_L				/*:: PUNCT("lax"), XQ, NULL ::*/
%token LET_DOLLAR_L			/*:: PUNCT("let $"), XQ, NULL ::*/
%token MODULE_NAMESPACE_L		/*:: PUNCT("module namespace"), XQ, NULL ::*/
%token NAMESPACE_L			/*:: PUNCT("namespace"), XQ, NULL ::*/
%token NILLABLE_L			/*:: PUNCT("nillable"), XQ, NULL ::*/
%token NODE_LPAR_L			/*:: PUNCT("node ("), XQ, NULL ::*/
%token O_BASE_URI			/*:: PUNCT("__base_uri"), XQ, NULL ::*/
%token O_DAVPROP			/*:: PUNCT("__davprop"), XQ, NULL ::*/
%token O_DOC				/*:: PUNCT("__doc"), XQ, NULL ::*/
%token O_ENC				/*:: PUNCT("__enc"), XQ, NULL ::*/
%token O_HTTP				/*:: PUNCT("__http"), XQ, NULL ::*/
%token O_KEY				/*:: PUNCT("__key"), XQ, NULL ::*/
%token O_LANG				/*:: PUNCT("__lang"), XQ, NULL ::*/
%token O_QUIET				/*:: PUNCT("__quiet"), XQ, NULL ::*/
%token O_SAX				/*:: PUNCT("__sax"), XQ, NULL ::*/
%token O_SHALLOW			/*:: PUNCT("__shallow"), XQ, NULL ::*/
%token O_TAG				/*:: PUNCT("__tag"), XQ, NULL ::*/
%token O_VIEW				/*:: PUNCT("__view"), XQ, NULL ::*/
%token O__STAR				/*:: PUNCT("__*"), XQ, NULL ::*/
%token ORDER_BY_L			/*:: PUNCT("order by"), XQ, NULL ::*/
%token ORDERED_LBRA_L			/*:: PUNCT("ordered {"), XQ, NULL ::*/
%token PI_LBRA_L			/*:: PUNCT("processing-instruction {"), XQ, NULL ::*/
%token PI_LPAR_L			/*:: PUNCT("processing-instruction ("), XQ, NULL ::*/
%token PRAGMA_L				/*:: PUNCT("pragma"), XQ, NULL ::*/
%token RETURN_L				/*:: PUNCT("return"), XQ, NULL ::*/
%token SATISFIES_L			/*:: PUNCT("satisfies"), XQ, NULL ::*/
%token SORTBY_LPAR_L			/*:: PUNCT("sort by ("), XQ, NULL ::*/
%token SCHEMA_ATTRIBUTE_LPAR_L		/*:: PUNCT("schema-attribute ("), XQ, NULL ::*/
%token SCHEMA_ELEMENT_LPAR_L		/*:: PUNCT("schema-element ("), XQ, NULL ::*/
%token SKIP_L				/*:: PUNCT("skip"), XQ, NULL ::*/
%token SOME_DOLLAR_L			/*:: PUNCT("some $"), XQ, NULL ::*/
%token STABLE_ORDER_BY_L		/*:: PUNCT("stable order by"), XQ, NULL ::*/
%token STRICT_L				/*:: PUNCT("strict"), XQ, NULL ::*/
%token TEXT_LBRA_L			/*:: PUNCT("text {"), XQ, NULL ::*/
%token TEXT_LPAR_L			/*:: PUNCT("text ("), XQ, NULL ::*/
%token THEN_L				/*:: PUNCT("then"), XQ, NULL ::*/
%token TO_L				/*:: PUNCT("to"), XQ, NULL ::*/
%token TREAT_AS_L			/*:: PUNCT("treat as"), XQ, NULL ::*/
%token TYPESWITCH_LPAR_L		/*:: PUNCT("typeswitch ("), XQ, NULL ::*/
%token UNION_L				/*:: PUNCT("union"), XQ, NULL ::*/
%token UNORDERED_LBRA_L			/*:: PUNCT("unordered {"), XQ, NULL ::*/
%token VALIDATE_CONTEXT_L		/*:: PUNCT("validate context"), XQ, NULL ::*/
%token VALIDATE_GLOBAL_L		/*:: PUNCT("validate global"), XQ, NULL ::*/
%token VALIDATE_LAX_L			/*:: PUNCT("validate lax"), XQ, NULL ::*/
%token VALIDATE_LBRA_L			/*:: PUNCT("validate {"), XQ, NULL ::*/
%token VALIDATE_STRICT_L		/*:: PUNCT("validate strict"), XQ, NULL ::*/
%token VALIDATE_SKIP_L			/*:: PUNCT("validate skip"), XQ, NULL ::*/
%token WHERE_L				/*:: PUNCT("where"), XQ, NULL ::*/
%token XMLNS				/*:: PUNCT("xmlns"), XQ, LAST("<Q xmlns"), MISS("<Q xmlns:ns"), NULL ::*/
%token SQL_COLON_COLUMN			/*:: PUNCT("sql:column"), XQ, NULL ::*/

%token __PUNCT_END	/* Delimiting value for syntax highlighting */

%token EXEC_SQL_XPATH			/*:: PUNCT("EXEC SQL XPATH"), XP, NULL ::*/
%token START_OF_XQ_TEXT			/*:: FAKE("the beginning of XQuery text"), XQ, NULL ::*/
%token START_OF_XP_TEXT			/*:: FAKE("the beginning of XPath text"), XQ, NULL ::*/
%token START_OF_FT_TEXT			/*:: FAKE("the beginning of free-text query"), XQ, NULL ::*/

%token END_OF_XPSCN_TEXT		/*:: FAKE("the end of query text"), XQ, NULL ::*/

%token __NONPUNCT_START	/* Delimiting value for syntax highlighting */

%token <box> CDATA_SECTION		/*:: LITERAL("<![CDATA[%s]]>"), XQ, NULL ::*/
%token <box> CHAR_REF			/*:: LITERAL("&#x%x;"), XQ, NULL ::*/
%token <box> PREDEFINED_ENTITY_REF	/*:: LITERAL("&%z;"), XQ, NULL ::*/
%token <box> NUMBER			/*:: LITERAL("%d"), XQ, NULL ::*/
%token <box> RBRA_NDQSTRING_DQ		/*:: LITERAL("}%s\""), XQ, NULL ::*/
%token <box> RBRA_NDQSTRING_LBRA	/*:: LITERAL("}%s{"), XQ, NULL ::*/
%token <box> RBRA_NSQSTRING_LBRA	/*:: LITERAL("}%s{"), XQ, NULL ::*/
%token <box> RBRA_NSQSTRING_SQ		/*:: LITERAL("}%s\'"), XQ, NULL ::*/
%token <box> NAMESPACE_LNAME_LBRA	/*:: LITERAL("namespace %s {"), XQ, NULL ::*/
%token <box> NOT_XQCNAME_LPAR		/*:: LITERAL("not %s ("), XQ, NULL ::*/
%token <box> PI_LNAME_LBRA		/*:: LITERAL("processing-instruction %s {"), XQ, NULL ::*/
%token <box> ATTRIBUTE_QNAME_LBRA	/*:: LITERAL("attribute %s {"), XQ, NULL ::*/
%token <box> ELEMENT_QNAME_LBRA		/*:: LITERAL("element %s {"), XQ, NULL ::*/
%token <box> SINGLE_WORD		/*:: LITERAL("%s"), FT, NULL ::*/
%token <box> XQ_AT_DQ_NDQSTRING_DQ	/*:: LITERAL("at \"%s\""), XQ, NULL ::*/
%token <box> XQ_CAST_AS_CNAME		/*:: LITERAL("cast as %s"), XQ, NULL ::*/
%token <box> XQ_CASTABLE_AS_CNAME	/*:: LITERAL("cast as %s"), XQ, NULL ::*/
%token <box> XQ_CNAME_PLUS		/*:: LITERAL("%s +"), XQ, NULL ::*/
%token <box> XQ_CNAME_QMARK		/*:: LITERAL("%s ?"), XQ, NULL ::*/
%token <box> XQ_CNAME_SLASH		/*:: LITERAL("%s /"), XQ, NULL ::*/
%token <box> XQ_CNAME_STAR		/*:: LITERAL("%s *"), XQ, NULL ::*/
%token <box> XQ_NCNAME_COLON_STAR	/*:: LITERAL("%s:*"), XQ, NULL ::*/
%token <box> XQ_STAR_COLON_NCNAME	/*:: LITERAL("*:%s"), XQ, NULL ::*/
%token <box> XQ_STRG_EXT_CONTENT	/*:: LITERAL("%s"), XQ, NULL ::*/
%token <box> XQ_STRG_QMARK_GT		/*:: LITERAL("%s?>"), XQ, NULL ::*/
%token <box> XQ_TYPE_LPAR_CNAME_RPAR	/*:: LITERAL("type (%s)"), XQ, NULL ::*/
%token <box> XQ_XQUERY_VERSION_DQ_NDQSTRING_DQ	/*:: LITERAL("xquery version \"%s\""), XQ, NULL ::*/
%token <box> XQ_AT_SQ_NSQSTRING_SQ	/*:: LITERAL("at \'%s\'"), XQ, NULL ::*/
%token <box> XQ_XML_COMMENT_STRING	/*:: LITERAL("%s-->"), XQ, NULL ::*/
%token <box> XQ_XQUERY_VERSION_SQ_NSQSTRING_SQ	/*:: LITERAL("xquery version \'%s\'"), XQ, NULL ::*/
%token <box> XQCNAME			/*:: LITERAL("%s"), XQ, NULL ::*/
%token <box> XQCNAME_LPAR		/*:: LITERAL("%s ("), XQ, NULL ::*/
%token <box> XQDQ_NAME_DQ		/*:: LITERAL("\"%s\""), XQ, NULL ::*/
%token <box> XQDQ_NDQSTRING_DQ		/*:: LITERAL("\"%s\""), XQ, LAST("<Q xmlns:ns=\"http://www.example.com/uri\""), MISS("<Q xmlns:ns=\"some{calculable}text\""), NULL ::*/
%token <box> XQDQ_NDQSTRING_LBRA	/*:: LITERAL("\"%s{"), XQ, NULL ::*/
%token <box> XQ_ECSTRING		/*:: LITERAL("%s"), XQ, NULL ::*/
%token <box> XQNCNAME			/*:: LITERAL("%s"), XQ, NULL ::*/
%token <box> XQNAMERESERVED		/*:: LITERAL("%s"), XQ, LAST("<Q xmlns:ns"), MISS("<Q xmlns"), NULL ::*/
%token <box> XQQQNAME			/*:: LITERAL("%s"), XQ, NULL ::*/
%token <box> XQSQ_NSQSTRING_LBRA	/*:: LITERAL("\'%s{"), XQ, NULL ::*/
%token <box> XQSQ_NSQSTRING_SQ		/*:: LITERAL("\'%s\'"), XQ, NULL ::*/
%token <box> XQVARIABLE_POS		/*:: LITERAL("%s"), XQ, NULL ::*/
%token <box> XQVARIABLE_NAME		/*:: LITERAL("%s"), XQ, NULL ::*/

%token __NONPUNCT_END	/* Delimiting value for syntax highlighting */

%type <tree>		absolute_path
%type <token_type>	axis_name
%type <token_type>	axis_spec
%type <tree>		filter_expr
%type <box>		literal
%type <box>		literal_strg
/* %type <box> keyword_as_name */
%type <tree>		node_test
%type <trees>		opt_predicates
%type <tree>		path
%type <tree>		path_expr
%type <list>		pred_list
%type <tree>		predicate
%type <tree>		primary_expr
%type <tree>		relative_path
%type <tree>		sql
%type <tree>		top_xq
%type <tree>		top_xp
%type <tree>		top_ft
%type <tree>		step
%type <fts>		text_exp
%type <tree>		variable_ref
%type <box>		view_name
%type <nothing>		xp_option
%type <nothing>		xp_options
%type <nothing>		xp_options_seq
%type <nothing>		xp_options_seq_opt
%type <list>		xpath_arg_list
%type <tree>		xpath_expr
%type <tree>		xpath_function
/*%type <tree>		xq_data_type
%type <tree>		xq_data_type_opt*/
/* %type <tree>		xq_dml_stmt */
/* %type <backstack>	xq_dml_stmts */
%type <tree>		xq_comp_ctor
%type <backstack>	xq_comp_elem_body
%type <backstack>	xq_comp_elem_body_opt
%type <tree>		xq_comp_elem_child
%type <tree>		xq_dir_ctor
%type <backstack>	xq_dir_el_attr_dq_tail
%type <backstack>	xq_dir_el_attr_list_opt
%type <box>		xq_dir_el_attr_ns_uri
%type <tree>		xq_dir_el_attr_spec
%type <backstack>	xq_dir_el_attr_sq_tail
%type <list>		xq_dir_el_attr_value
%type <nothing>		xq_dir_el_closing_ctor
%type <tree>		xq_dir_el_ctor
%type <backstack>	xq_dir_el_ctor_tail
%type <tree>		xq_dir_el_child
%type <backstack>	xq_dir_el_content
%type <tree>		xq_dir_el_name_spec
%type <tree>		xq_document_test_cont
%type <tree>		xq_element_test_item
%type <tree>		xq_element_test_seq
%type <tree>		xq_expr_enclosed
%type <tree>		xq_expr
%type <backstack>	xq_expr_flwr_for
%type <backstack>	xq_expr_flwr_forlet
%type <backstack>	xq_expr_flwr_forlets
%type <backstack>	xq_expr_flwr_let
%type <tree>		xq_expr_flwr_where_opt
%type <backstack>	xq_expr_flwr_order_opt
%type <tree>		xq_expr_funcall
%type <tree>		xq_expr_syscall
%type <tree>		xq_expr_name_test
%type <tree>		xq_expr_node_test
%type <token_type>	xq_expr_ordering_block
%type <tree>		xq_expr_primary_calc
%type <tree>		xq_expr_seq
%type <tree>		xq_expr_single
%type <token_type>	xq_expr_sort_dir
%type <token_type>	xq_expr_sort_empty
%type <box>		xq_expr_sort_collation
%type <tree>		xq_expr_sort_spec
%type <backstack>	xq_expr_sort_specs
%type <box>		xq_expr_sort_type
%type <backstack>	xq_expr_sortby
%type <trees>		xq_expr_typecase
%type <backstack>	xq_expr_typecases
%type <trees>		xq_expr_typedflt
%type <token_type>	xq_expr_validation_block
%type <tree>		xq_expr_varass
%type <backstack>	xq_expr_varasss
%type <tree>		xq_expr_variable
%type <tree>		xq_expr_varin
%type <backstack>	xq_expr_varins
%type <tree>		xq_expr_wildcard
%type <backstack>	xq_exprs
%type <backstack>	xq_exprs_opt
%type <tree>		xq_function_decl
%type <tree>		xq_function_ret_decl_opt
%type <backstack>	xq_import_at_opt
%type <backstack>	xq_import_more_opt
%type <tree>		xq_kind_test
%type <box>		xq_literal
%type <box>		xq_module_prefix_opt
%type <box>		xq_name_or_star
%type <tree>		xq_param
%type <backstack>	xq_params
%type <backstack>	xq_params_opt
%type <tree>		xq_path
%type <tree>		xq_path_calc
%type <tree>		xq_path_rel_from_axn
%type <tree>		xq_path_step
%type <tree>		xq_path_step_axis
%type <tree>		xq_path_step_nodetest
%type <backstack>	xq_path_step_qualifs_opt
%type <tree>		xq_path_step_qualif
%type <tree>		xq_pi_test_cont
%type <box>		xq_qname
%type <token_type>	xq_path_axis
/*
%type <tree>		xq_query
%type <tree>		xq_query_or_dml_stmts
*/
%type <token_type>	xq_rpar_oi
%type <box>		xq_schema_prefix_opt
%type <tree>		xq_schema_element_test_item
%type <tree>		xq_schema_element_test_seq
%type <tree>		xq_sequence_type
/*
%type <token_type>	xq_sdml_locator
%type <tree>		xq_sdml_stmt
%type <tree>		xq_sdml_stmt_insert
%type <tree>		xq_sdml_stmt_move
%type <tree>		xq_sdml_stmt_rename
%type <tree>		xq_sdml_stmt_with
*/
/*%type <tree>		xq_sdt*/
%type <box>		xq_strg
%type <tree>		xq_type_declaration_opt
%type <tree>		xq_var_decl_init


%nonassoc NOT_AS_NAME
%left ';'
%left ','
%left SORTBY_LPAR_L
%nonassoc RETURN_L SATISFIES_L ELSE_L
%left FOR_DOLLAR_L LET_DOLLAR_L SOME_DOLLAR_L EVERY_DOLLAR_L TYPESWITCH_LPAR_L IF_LPAR_L
%left K_OR
%left K_AND
%nonassoc K_NOT
%nonassoc _EQ _NOT_EQ
%nonassoc K2_EQ_L K2_GE_L K2_GT_L K2_LE_L K2_LT_L K2_NE_L _LT _LE _GT _GE _LT_LT _GT_GT _SAME _NOT_SAME K_LIKE
%left BEFORE_L AFTER_L
%left TO_L
%left _PLUS _MINUS
%nonassoc STANDALONE_SLASH
%left _STAR /* _SLASH */ K_DIV K_IDIV K_MOD
%nonassoc UMINUS
%nonassoc UPLUS
%left K_NEAR
%left '|' UNION_L
%left INTERSECT_L EXCEPT_L
%left INSTANCE_OF_L
%left TREAT_AS_L
%left XQ_CASTABLE_AS_CNAME
%left XQ_CAST_AS_CNAME
%left SLASH_AS_MAP
%nonassoc REL_PATH_TO_PATH
%left VALIDATE_LAX_L VALIDATE_LBRA_L VALIDATE_STRICT_L VALIDATE_SKIP_L _SLASH _SLASH_SLASH _POINTER_VIA_ID
%left STEPS_IN_REL_PATH
%nonassoc LEFT_SLASH
%left '[' ']' '(' ')'

%%

/* TOP-LEVEL begin */
sql
	: START_OF_XQ_TEXT
		{
		  xpp_arg->xpp_allowed_options = XP_XQUERY_OPTS | XP_XPATH_OPTS | XP_FREETEXT_OPTS;
		  xp_register_default_namespace_prefixes (xpp_arg);
		}
	  top_xq { xpp_arg->xpp_expr = $$ = $3; }
	| START_OF_XP_TEXT
		{
		  xpp_arg->xpp_allowed_options = XP_XPATH_OPTS | XP_FREETEXT_OPTS;
		  xp_register_default_namespace_prefixes (xpp_arg);
		}
	  top_xp { xpp_arg->xpp_expr = $$ = $3; }
	| START_OF_FT_TEXT { xpp_arg->xpp_allowed_options = XP_FREETEXT_OPTS; } top_ft { xpp_arg->xpp_expr = $$ = $3; }
	| __PUNCT_BEGIN __PUNCT_END __NONPUNCT_START __NONPUNCT_END EXEC_SQL_XPATH { $$ = NULL; /* This never happens and it's here solely to remove warnings */ }
	| error { xpyyerror (xpp_arg, "(internal SQL processing error) XQuery, XPath or Free-Text mark expected"); }
	;

top_xq	/* XQ2003[30] Module, XQ2003[31] MainModule, XQ2003[32] LibraryModule */
	: END_OF_XPSCN_TEXT	{ xpyyerror (xpp_arg, "The XQuery expression is totally empty"); }
	| xq_version_decl_opt xq_prolog xq_expr END_OF_XPSCN_TEXT
		{
		  $$ = xp_make_module (xpp_arg, NULL, NULL, $3);
		}
	| xq_version_decl_opt MODULE_NAMESPACE_L XQNCNAME _EQ xq_strg ';'
		{
		  xp_register_namespace_prefix (xpp_arg, $3, $5);
		}
	     xq_prolog END_OF_XPSCN_TEXT
		{
		  $$ = xp_make_module (xpp_arg, box_copy ($3), box_copy ($5), NULL);
		}
	;

top_xp
	: xp_options_seq_opt xpath_expr opt_semi_END_OF_XPSCN_TEXT { $$ = $2; }
	;

opt_semi_END_OF_XPSCN_TEXT
	: ';' END_OF_XPSCN_TEXT
	| END_OF_XPSCN_TEXT
	;

top_ft
	: xp_options_seq_opt text_exp END_OF_XPSCN_TEXT { $$ = (XT*)($2); }
	;

/* TOP-LEVEL end */

/* XQuery begin */

xq_version_decl_opt
	: /* empty */
	| XQ_XQUERY_VERSION_SQ_NSQSTRING_SQ ';' { ; }
	| XQ_XQUERY_VERSION_DQ_NDQSTRING_DQ ';' { ; }
	;

xq_prolog
	: xq_prolog_setters_opt xq_prolog_decls_opt
	;

xq_prolog_setters_opt
	: /* empty */
	| xq_prolog_setters_opt xq_prolog_setter ';'
	| xq_prolog_setters_opt xq_prolog_setter error	{ xpyyerror (xpp_arg, "Missing semicolon after prolog (setter) declaration"); }
	;

xq_prolog_decls_opt
	: /* empty */
	| xq_prolog_decls_opt xq_prolog_decl
	| xq_prolog_decls_opt xq_prolog_decl xq_prolog_setter	{ xpyyerror (xpp_arg, "Prolog setter declaration can not appear after a non-setter declaration"); }
	;

xq_prolog_setter
	: DECLARE_XMLSPACE_PRESERVE_L				{ XPP_PROLOG_SET (xe_xmlspace_mode, "xmlspace mode", XPP_XMLSPACE_PRESERVE); }
	| DECLARE_XMLSPACE_STRIP_L				{ XPP_PROLOG_SET (xe_xmlspace_mode, "xmlspace mode", XPP_XMLSPACE_STRIP); }
	| DECLARE_DEFAULT_COLLATION_L xq_strg			{ XPP_PROLOG_SET (xe_dflt_collation, "default collation", box_copy ($2)); }
	| DECLARE_BASE_URI_L xq_strg				{ XPP_PROLOG_SET (xe_base_uri, "base-uri", box_copy ($2)); }
	| DECLARE_CONSTRUCTION_PRESERVE_L			{ XPP_PROLOG_SET (xe_construction_mode, "construction mode", XPP_TYPE_PRESERVE); }
	| DECLARE_CONSTRUCTION_STRIP_L				{ XPP_PROLOG_SET (xe_construction_mode, "construction mode", XPP_TYPE_STRIP); }
	| DECLARE_DEFAULT_ELEMENT_L NAMESPACE_L xq_strg		{ XPP_PROLOG_SET (xe_dflt_elt_namespace, "default element namespace", box_copy ($3)); }
	| DECLARE_DEFAULT_FUNCTION_L NAMESPACE_L xq_strg	{ XPP_PROLOG_SET (xe_dflt_fn_namespace, "default function namespace", box_copy ($3)); }
	| DECLARE_ORDERING_ORDERED_L				{ XPP_PROLOG_SET (xe_ordering_mode, "ordering mode", XPP_ORDERING_ORDERED); }
	| DECLARE_ORDERING_UNORDERED_L				{ XPP_PROLOG_SET (xe_ordering_mode, "ordering mode", XPP_ORDERING_UNORDERED); }
	| DECLARE_VALIDATION_LAX_L				{ XPP_PROLOG_SET (xe_validation_mode, "validation mode", XPP_VALIDATION_LAX); }
	| DECLARE_VALIDATION_SKIP_L				{ XPP_PROLOG_SET (xe_validation_mode, "validation mode", XPP_VALIDATION_SKIP); }
	| DECLARE_VALIDATION_STRICT_L				{ XPP_PROLOG_SET (xe_validation_mode, "validation mode", XPP_VALIDATION_STRICT); }
	;

xq_prolog_decl
	: xq_schema_import ';'
	| xq_module_import ';'
	| DECLARE_NAMESPACE_L XQNCNAME _EQ xq_strg ';'		{
		xp_register_namespace_prefix (xpp_arg, $2, $4);
		 }
	| DECLARE_NAMESPACE_L xq_strg _EQ xq_strg ';'		{
		xp_register_namespace_prefix (xpp_arg, $2, $4);
		 }
	| xq_var_decl ';'
	| xq_function_decl ';'					{ /* dk_set_push (&(xpp_arg->xpp_preamble_decls), $1) */ ; }
	| xq_function_decl					{ /* dk_set_push (&(xpp_arg->xpp_preamble_decls), $1) */ ; }
	;

xq_schema_import
	: IMPORT_SCHEMA_L xq_schema_prefix_opt xq_strg xq_import_at_opt
		{
		  if ($2)
		    {
		      if (IS_BOX_POINTER ($2))
			xp_register_namespace_prefix (xpp_arg, $2, $3);
		      else
			XPP_PROLOG_SET (xe_dflt_elt_namespace, "default element namespace", $2);
		    }
		  xp_import_schema (xpp_arg, $2, $3, (caddr_t *)revlist_to_array ($4));
		}
	;

xq_schema_prefix_opt
	: /* empty */					{ $$ = NULL; }
	| NAMESPACE_L XQNCNAME _EQ			{ $$ = $2; }
	| NAMESPACE_L xq_strg _EQ			{ $$ = $2; }
	| DEFAULT_ELEMENT_L NAMESPACE_L			{ $$ = (void *)1; }
	;

xq_import_at_opt
	: /* empty */					{ $$ = NULL; }
	| AT_L xq_strg xq_import_more_opt		{ dk_set_push (&($$), $2); $$ = dk_set_conc ($$, $3); }
	;

xq_import_more_opt
	: /* empty */					{ $$ = NULL; }
	| xq_import_more_opt ',' xq_strg		{ $$ = $1; dk_set_push (&($$), $3); }
	;

xq_module_import
	: IMPORT_MODULE_L xq_module_prefix_opt xq_strg xq_import_at_opt
		{
		  if ($2)
		    xp_register_namespace_prefix (xpp_arg, $2, $3);
		  xp_import_module (xpp_arg, $2, $3, (caddr_t *)revlist_to_array ($4));
		}
	;

xq_module_prefix_opt
	: /* empty */					{ $$ = NULL; }
	| NAMESPACE_L XQNCNAME _EQ			{ $$ = $2; }
	| NAMESPACE_L xq_strg _EQ			{ $$ = $2; }
	;

xq_var_decl
	: DECLARE_VARIABLE_DOLLAR_L XQVARIABLE_NAME xq_type_declaration_opt xq_var_decl_init
	    {
	      xp_var_decl (xpp_arg, box_copy ($2), $3, $4);
	    }
	;

xq_var_decl_init
	: EXTERNAL_L					{ $$ = NULL; }
	| _ASSIGN xq_expr_single			{ $$ = $2; }
	;

/* Type descriptions */

xq_type_declaration_opt
	: /* empty */					{ $$ = NULL; }
	| AS_L xq_sequence_type				{ $$ = $2; }
	;

xq_sequence_type
	: xq_kind_test
	| XQCNAME						{ $$ = xp_make_seq_type (xpp_arg, XQCNAME, NULL, (XT *)$1, 0, XQ_SEQTYPE_REQ_ONE); }
	| XQ_CNAME_STAR						{ $$ = xp_make_seq_type (xpp_arg, XQCNAME, NULL, (XT *)$1, 0, XQ_SEQTYPE_OPT_MANY); }
	| XQ_CNAME_PLUS						{ $$ = xp_make_seq_type (xpp_arg, XQCNAME, NULL, (XT *)$1, 0, XQ_SEQTYPE_REQ_MANY); }
	| XQ_CNAME_QMARK					{ $$ = xp_make_seq_type (xpp_arg, XQCNAME, NULL, (XT *)$1, 0, XQ_SEQTYPE_OPT_ONE); }
	| DOCUMENT_NODE_LPAR_L xq_document_test_cont xq_rpar_oi	{ $$ = xp_make_seq_type (xpp_arg, DOCUMENT_NODE_LPAR_L, NULL, $2, 0, $3); }
	| xq_element_test_seq
	| ATTRIBUTE_LPAR_L xq_name_or_star xq_rpar_oi	{ $$ = xp_make_seq_type (xpp_arg, ATTRIBUTE_LPAR_L, $2, NULL, 0, $3); }
	| ATTRIBUTE_LPAR_L xq_name_or_star ',' XQCNAME xq_rpar_oi    { $$ = xp_make_seq_type (xpp_arg, ATTRIBUTE_LPAR_L, $2, (XT *)$4, 0, $5); }
	| xq_schema_element_test_seq
	| SCHEMA_ATTRIBUTE_LPAR_L XQCNAME xq_rpar_oi		{ $$ = xp_make_seq_type (xpp_arg, SCHEMA_ATTRIBUTE_LPAR_L, $2, NULL, 0, $3); }
	| PI_LPAR_L xq_pi_test_cont xq_rpar_oi			{ $$ = xp_make_seq_type (xpp_arg, PI_LPAR_L, NULL, $2, 0, $3); }
	| COMMENT_LPAR_L xq_rpar_oi				{ $$ = xp_make_seq_type (xpp_arg, COMMENT_LPAR_L, NULL, NULL, 0, $2); }
	| TEXT_LPAR_L xq_rpar_oi				{ $$ = xp_make_seq_type (xpp_arg, TEXT_LPAR_L, NULL, NULL, 0, $2); }
	| NODE_LPAR_L xq_rpar_oi				{ $$ = xp_make_seq_type (xpp_arg, NODE_LPAR_L, NULL, NULL, 0, $2); }
	| ITEM_LPAR_RPAR_L					{ $$ = xp_make_seq_type (xpp_arg, ITEM_LPAR_RPAR_L, NULL, NULL, 0, XQ_SEQTYPE_REQ_ONE); }
	| ITEM_LPAR_RPAR_PLUS_L					{ $$ = xp_make_seq_type (xpp_arg, ITEM_LPAR_RPAR_L, NULL, NULL, 0, XQ_SEQTYPE_REQ_MANY); }
	| ITEM_LPAR_RPAR_QMARK_L				{ $$ = xp_make_seq_type (xpp_arg, ITEM_LPAR_RPAR_L, NULL, NULL, 0, XQ_SEQTYPE_OPT_ONE); }
	| ITEM_LPAR_RPAR_STAR_L					{ $$ = NULL; }
	| EMPTY_LPAR_RPAR_L					{ $$ = xp_make_seq_type (xpp_arg, EMPTY_LPAR_RPAR_L, NULL, NULL, 0, XQ_SEQTYPE_OPT_ONE); }
	;

xq_kind_test
	: DOCUMENT_NODE_LPAR_L xq_document_test_cont ')'	{ $$ = xp_make_seq_type (xpp_arg, DOCUMENT_NODE_LPAR_L, NULL, $2, 0, XQ_SEQTYPE_REQ_ONE); }
	| xq_element_test_item
	| ATTRIBUTE_LPAR_L xq_name_or_star ')'		{ $$ = xp_make_seq_type (xpp_arg, ATTRIBUTE_LPAR_L, $2, NULL, 0, XQ_SEQTYPE_REQ_ONE); }
	| ATTRIBUTE_LPAR_L xq_name_or_star ',' XQCNAME ')'	{ $$ = xp_make_seq_type (xpp_arg, ATTRIBUTE_LPAR_L, $2, (XT *)$4, 0, XQ_SEQTYPE_REQ_ONE); }
	| xq_schema_element_test_item
	| SCHEMA_ATTRIBUTE_LPAR_L XQCNAME ')'			{ $$ = xp_make_seq_type (xpp_arg, SCHEMA_ATTRIBUTE_LPAR_L, $2, NULL, 0, XQ_SEQTYPE_REQ_ONE); }
	| PI_LPAR_L xq_pi_test_cont ')'				{ $$ = xp_make_seq_type (xpp_arg, PI_LPAR_L, NULL, $2, 0, XQ_SEQTYPE_REQ_ONE); }
	| COMMENT_LPAR_L ')'					{ $$ = xp_make_seq_type (xpp_arg, COMMENT_LPAR_L, NULL, NULL, 0, XQ_SEQTYPE_REQ_ONE); }
	| TEXT_LPAR_L ')'					{ $$ = xp_make_seq_type (xpp_arg, TEXT_LPAR_L, NULL, NULL, 0, XQ_SEQTYPE_REQ_ONE); }
	| NODE_LPAR_L ')'					{ $$ = xp_make_seq_type (xpp_arg, NODE_LPAR_L, NULL, NULL, 0, XQ_SEQTYPE_REQ_ONE); }
	;

xq_rpar_oi
	: _RPAR_PLUS	    { $$ = XQ_SEQTYPE_REQ_MANY; }
	| _RPAR_QMARK	    { $$ = XQ_SEQTYPE_OPT_ONE; }
	| _RPAR_STAR	    { $$ = XQ_SEQTYPE_OPT_MANY; }
	;

xq_element_test_seq
	: ELEMENT_LPAR_L xq_rpar_oi    { $$ = xp_make_seq_type (xpp_arg, ELEMENT_LPAR_L, NULL, NULL, 0, $2); }
	| ELEMENT_LPAR_L xq_name_or_star xq_rpar_oi    { $$ = xp_make_seq_type (xpp_arg, ELEMENT_LPAR_L, $2, NULL, 0, $3); }
	| ELEMENT_LPAR_L xq_name_or_star ',' XQCNAME xq_rpar_oi    { $$ = xp_make_seq_type (xpp_arg, ELEMENT_LPAR_L, $2, (XT *)$4, 0, $5); }
	| ELEMENT_LPAR_L xq_name_or_star ',' XQCNAME '?' xq_rpar_oi    { $$ = xp_make_seq_type (xpp_arg, ELEMENT_LPAR_L, $2, (XT *)$4, 1, $6); }
	| ELEMENT_LPAR_L xq_name_or_star ',' XQ_CNAME_QMARK xq_rpar_oi    { $$ = xp_make_seq_type (xpp_arg, ELEMENT_LPAR_L, $2, (XT *)$4, 1, $5); }
	;

xq_element_test_item
	: ELEMENT_LPAR_L ')'						{ $$ = xp_make_seq_type (xpp_arg, ELEMENT_LPAR_L, NULL, NULL, 0, XQ_SEQTYPE_REQ_ONE); }
	| ELEMENT_LPAR_L xq_name_or_star ')'			{ $$ = xp_make_seq_type (xpp_arg, ELEMENT_LPAR_L, $2, NULL, 0, XQ_SEQTYPE_REQ_ONE); }
	| ELEMENT_LPAR_L xq_name_or_star ',' XQCNAME ')'		{ $$ = xp_make_seq_type (xpp_arg, ELEMENT_LPAR_L, $2, (XT *)$4, 0, XQ_SEQTYPE_REQ_ONE); }
	| ELEMENT_LPAR_L xq_name_or_star ',' XQCNAME '?' ')'	{ $$ = xp_make_seq_type (xpp_arg, ELEMENT_LPAR_L, $2, (XT *)$4, 1, XQ_SEQTYPE_REQ_ONE); }
	| ELEMENT_LPAR_L xq_name_or_star ',' XQ_CNAME_QMARK ')'	{ $$ = xp_make_seq_type (xpp_arg, ELEMENT_LPAR_L, $2, (XT *)$4, 1, XQ_SEQTYPE_REQ_ONE); }
	;

xq_schema_element_test_seq
	: SCHEMA_ELEMENT_LPAR_L XQCNAME xq_rpar_oi	    { $$ = xp_make_seq_type (xpp_arg, SCHEMA_ELEMENT_LPAR_L, $2, NULL, 0, $3); }
	;

xq_schema_element_test_item
	: SCHEMA_ELEMENT_LPAR_L XQCNAME ')'		    { $$ = xp_make_seq_type (xpp_arg, SCHEMA_ELEMENT_LPAR_L, $2, NULL, 0, XQ_SEQTYPE_REQ_ONE); }
	;

xq_document_test_cont
	: /* empty */					    { $$ = NULL; }
	| xq_element_test_seq				    { $$ = $1; }
	| xq_element_test_item				    { $$ = $1; }
	| xq_schema_element_test_seq			    { $$ = $1; }
	| xq_schema_element_test_item			    { $$ = $1; }
	;

xq_name_or_star
	: XQCNAME
	| K_NOT	%prec NOT_AS_NAME	{ $$ = box_dv_uname_string ("not"); }
	| _STAR	    { $$ = NULL; }
	;

xq_pi_test_cont
	: /* empty */					    { $$ = NULL; }
	| XQNCNAME					    { $$ = (XT *)$1; }
	| xq_strg					    { $$ = (XT *)$1; }
	;

xq_function_decl			/* XQ[4] */
	: DECLARE_FUNCTION_L XQCNAME_LPAR xq_params_opt xq_function_ret_decl_opt
		{
		  caddr_t fname = xp_make_extfunction_name (xpp_arg, NULL, $2);
		  xp_env_push (xpp_arg, "function", fname, 1);
		  $<tree>$ = xp_make_defun (xpp_arg, fname, list_to_array (dk_set_nreverse ($3)), $4, NULL);
		}
	 xq_expr_enclosed
		{
#ifdef MALLOC_DEBUG
		  dk_check_tree ($6);
#endif
		  $$ = $<tree>5;
		  do
		    {
		      xp_query_t *xqr = xpp_arg->xpp_xp_env->xe_xqr;
		      long  n_slots = dk_set_length (xqr->xqr_state_map);
		      ptrlong *map = (ptrlong *) dk_alloc_box (sizeof (ptrlong) * n_slots, DV_SHORT_STRING);
		      int fill = 0;
		      DO_SET (ptrlong, pos, &xqr->xqr_state_map)
			{
			  map[fill++] = (pos);
			}
		      END_DO_SET();
		      xqr->xqr_slots = map;
		      xqr->xqr_n_slots = n_slots;
		      xqr->xqr_tree = $6;
		      xqr->xqr_instance_length = sizeof (caddr_t) * xpp_arg->xpp_xp_env->xe_xqst_ctr;
		      $$->_.defun.body = xqr;
		    } while (0);
		  xpp_arg->xpp_xp_env->xe_xqr = NULL;
		  xp_env_pop(xpp_arg);
#ifdef MALLOC_DEBUG
		  dk_check_tree ($$);
#endif
		}
	;

xq_function_ret_decl_opt
	: ')'				    { $$ = NULL; }
	| ')' AS_L xq_sequence_type	    { $$ = $3; }
	| _RPAR_AS_L xq_sequence_type	    { $$ = $2; }
	;

xq_params_opt				/* (XQ[5])? */
	: /* empty */			{ $$ = NULL; }
	| xq_params			/* default { $$ = $1; } is OK */
	;

xq_params				/* XQ[5] */
	: xq_param			{ $$ = NULL; dk_set_push (&($$), $1); }
	| xq_params ',' xq_param	{ $$ = $1; dk_set_push (&($$), $3); }
	;

xq_param				/* XQ[6] */
	: _DOLLAR XQVARIABLE_NAME xq_type_declaration_opt { $$ = xtlist (xpp_arg, 5, XQ_DEFPARAM, $3, box_copy ($2), (ptrlong)0, (ptrlong)0); }
	;

/*
xq_query_or_dml_stmts
	: xq_query			/ * default { $$ = $1; } is OK * /
/ *	| xq_dml_stmts
		{
		  if (1 == dk_set_length($1))
		    $$ = dk_set_pop (&($1));
		  else
		    $$ = xp_make_call (xpp_arg, "progn", list_to_array (dk_set_nreverse ($1)));
		}* /
	| error { xpyyerror (xpp_arg, "A Query or Data Manipulation Statement expected"); }
	;

xq_query
	: xq_expr / * default { $$ = $1; } is OK * /
	;
*/

/* XQ hierarchy of multiary expressions -- begin */

xq_expr
	: xq_exprs
		{
		  if (dk_set_length($1) > 1)
		    $$ = xp_make_call (xpp_arg, "append", revlist_to_array ($1));
		  else
		    $$ = dk_set_pop (&($1));
		}
	;

xq_expr_single
	: xq_expr_single xq_expr_sortby	{ $$ = xp_make_sortby (xpp_arg, $1, $2); }
	| xq_expr_single K_OR xq_expr_single %prec K_OR
		{
		  $$ = xp_make_call (xpp_arg, "or", list (2, $1, $3));
		}
	| xq_expr_single K_OR error { xpyyerror (xpp_arg, "operand expected after 'OR'"); }
	| xq_expr_single K_AND xq_expr_single %prec K_AND
		{
		  $$ = xp_make_call (xpp_arg, "and", list (2, $1, $3));
		}
	| xq_expr_single K_AND error { xpyyerror (xpp_arg, "operand expected after 'AND'"); }
	| K_NOT xq_expr_single %prec K_NOT
		{
		  $$ = xp_make_call (xpp_arg, "not", list (1, $2));
		}
	| K_NOT error  %prec K_NOT { xpyyerror (xpp_arg, "operand expected after 'NOT'"); }
	| xq_expr_single K2_EQ_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "EQ operator", list (2, $1, $3));
		}
	| xq_expr_single K2_EQ_L error		{ xpyyerror (xpp_arg, "operand expected after 'eq'"); }
	| xq_expr_single K2_GE_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, box_dv_uname_string("GE operator"), list (2, $1, $3));
		}
	| xq_expr_single K2_GE_L error		{ xpyyerror (xpp_arg, "operand expected after 'ge'"); }
	| xq_expr_single K2_GT_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "GT operator", list (2, $1, $3));
		}
	| xq_expr_single K2_GT_L error		{ xpyyerror (xpp_arg, "operand expected after 'gt'"); }
	| xq_expr_single K2_LE_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "LE operator", list (2, $1, $3));
		}
	| xq_expr_single K2_LE_L error		{ xpyyerror (xpp_arg, "operand expected after 'le'"); }
	| xq_expr_single K2_LT_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "LT operator", list (2, $1, $3));
		}
	| xq_expr_single K2_LT_L error		{ xpyyerror (xpp_arg, "operand expected after 'lt'"); }
	| xq_expr_single K2_NE_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "NE operator", list (2, $1, $3));
		}
	| xq_expr_single K2_NE_L error		{ xpyyerror (xpp_arg, "operand expected after 'ne'"); }
	| xq_expr_single _LT_LT xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "BEFORE operator", list (2, $1, $3));
		}
	| xq_expr_single _LT_LT error		{ xpyyerror (xpp_arg, "operand expected after '<<'"); }
	| xq_expr_single BEFORE_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "BEFORE operator", list (2, $1, $3));
		}
	| xq_expr_single BEFORE_L error		{ xpyyerror (xpp_arg, "operand expected after 'before'"); }
	| xq_expr_single _GT_GT xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "AFTER operator", list (2, $1, $3));
		}
	| xq_expr_single _GT_GT error		{ xpyyerror (xpp_arg, "operand expected after '>>'"); }
	| xq_expr_single AFTER_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "AFTER operator", list (2, $1, $3));
		}
	| xq_expr_single AFTER_L error		{ xpyyerror (xpp_arg, "operand expected after 'after'"); }
	| xq_expr_flwr_forlets xq_expr_flwr_where_opt xq_expr_flwr_order_opt RETURN_L xq_expr_single
		{ $$ = xp_make_flwr (xpp_arg, $1, $2, $3, $5); }
	| IF_LPAR_L xq_expr ')' THEN_L xq_expr_single ELSE_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "if", list (3, $2, $5, $7));
		}
	| SOME_DOLLAR_L XQVARIABLE_NAME IN_L xq_expr_single SATISFIES_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "some", list (3, xp_make_literal_tree (xpp_arg, $2, 1), $4, $6));
		}
	| EVERY_DOLLAR_L XQVARIABLE_NAME IN_L xq_expr_single SATISFIES_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "every", list (3, xp_make_literal_tree (xpp_arg, $2, 1), $4, $6));
		}
	| xq_expr_single INSTANCE_OF_L xq_sequence_type { $$ = xp_make_call (xpp_arg, "INSTANCE OF predicate", list (2, $1, $3)); }
	| xq_expr_single XQ_CAST_AS_CNAME		{ $$ = xp_make_cast (xpp_arg, XQ_CAST_AS_CNAME, NULL, $1); }
	| xq_expr_single XQ_CASTABLE_AS_CNAME		{ $$ = xp_make_cast (xpp_arg, XQ_CASTABLE_AS_CNAME, NULL, $1); }
	| xq_expr_single TREAT_AS_L			{ $$ = xp_make_cast (xpp_arg, TREAT_AS_L, NULL, $1); }
	| TYPESWITCH_LPAR_L xq_expr ')' xq_expr_typecases xq_expr_typedflt { $$ = xp_make_typeswitch (xpp_arg, $2, $4, $5); }
	| xq_expr_single _EQ xq_expr_single		{ XBIN_OP ($$, BOP_EQ, $1, $3); }
	| xq_expr_single _NOT_EQ xq_expr_single		{ XBIN_OP ($$, BOP_NEQ, $1, $3); }
	| xq_expr_single _SAME xq_expr_single		{ XBIN_OP ($$, BOP_SAME, $1, $3); }
	| xq_expr_single _NOT_SAME xq_expr_single	{ XBIN_OP ($$, BOP_NSAME, $1, $3); }
	| xq_expr_single K_LIKE xq_expr_single		{ XBIN_OP ($$, BOP_LIKE, $1, $3); }
	| xq_expr_single _LT xq_expr_single		{ XBIN_OP ($$, BOP_LT, $1, $3); }
	| xq_expr_single _LE xq_expr_single		{ XBIN_OP ($$, BOP_LTE, $1, $3); }
	| xq_expr_single _GT xq_expr_single		{ XBIN_OP ($$, BOP_GT, $1, $3); }
	| xq_expr_single _GE xq_expr_single		{ XBIN_OP ($$, BOP_GTE, $1, $3); }
/*
	| xq_expr_single INSTANCEOF xq_data_type	{ $$ = xtlist (xpp_arg, 4, XQ_INSTANCEOF, $1, $3); }
	| xq_expr_single INSTANCE OF xq_data_type	{ $$ = xtlist (xpp_arg, 4, XQ_INSTANCEOF, $1, $4); }
*/
	| xq_expr_single TO_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "TO operator", list (2, $1, $3));
		}
	| xq_expr_single _PLUS xq_expr_single		{ XBIN_OP ($$, BOP_PLUS, $1, $3); }
	| xq_expr_single _MINUS xq_expr_single		{ XBIN_OP ($$, BOP_MINUS, $1, $3); }
	| xq_expr_single _STAR xq_expr_single		{ XBIN_OP ($$, BOP_TIMES, $1, $3); }
	| xq_expr_single K_IDIV xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "IDIV operator", list (2, $1, $3));
		}
	| xq_expr_single K_IDIV error			{ xpyyerror (xpp_arg, "operand expected after 'idiv'"); }
	| xq_expr_single K_DIV xq_expr_single		{ XBIN_OP ($$, BOP_DIV, $1, $3); }
	| xq_expr_single K_MOD xq_expr_single		{ XBIN_OP ($$, BOP_MOD, $1, $3); }
	| _PLUS xq_expr_single	%prec UPLUS	{ $$ = $2; }
	| _MINUS xq_expr_single	%prec UMINUS	{ XBIN_OP ($$, BOP_MINUS, box_num_nonull (0), $2); }
	| xq_expr_single UNION_L xq_expr_single
		{ $$ = xp_make_call (xpp_arg, "union", list (2, $1, $3)); }
	| xq_expr_single '|' xq_expr_single
		{ $$ = xtlist (xpp_arg, 7, XP_UNION,
		    $1, $3, xe_new_xqst (xpp_arg, XQST_REF),
		    xe_new_xqst (xpp_arg, XQST_REF), xe_new_xqst (xpp_arg, XQST_REF),
		    xe_new_xqst (xpp_arg, XQST_INT) ); }
	| xq_expr_single INTERSECT_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "intersect", list (2, $1, $3));
		}
	| xq_expr_single EXCEPT_L xq_expr_single
		{
		  $$ = xp_make_call (xpp_arg, "except", list (2, $1, $3));
		}
	| xq_expr_validation_block xq_expr '}'	{ $$ = xp_make_call (xpp_arg, "VALIDATE operator", list (2, $2, $1)); }
	| xq_path
	;

xq_expr_sortby
	: SORTBY_LPAR_L xq_expr_sort_specs ')' { $$ = $2; }
	| SORTBY_LPAR_L xq_expr_sort_specs error { xpyyerror (xpp_arg, "')' or ',' expected"); }
	;

xq_expr_sort_specs			/* XQ[8] */
	: xq_expr_sort_spec				{ $$ = NULL; dk_set_push (&($$), $1); }
	| xq_expr_sort_specs ',' xq_expr_sort_spec	{ $$ = $1; dk_set_push (&($$), $3); }
	;

xq_expr_sort_spec
	: xq_expr_single xq_expr_sort_dir xq_expr_sort_empty xq_expr_sort_collation xq_expr_sort_type
		{ $$ = xtlist (xpp_arg, 7, $2,
		  NULL,				    /* xs_query */
		  $1,				    /* xs_tree */
		  (ptrlong)((XQ_DESCENDING == $2) ? 1 : 0),  /* xs_is_desc */
		  $5,				    /* xs_type */
		  $3,				    /* xs_empty_weight */
		  ($4 ? xp_make_literal_tree (xpp_arg, (caddr_t)$4, 1) : NULL) ); /*	xs_collation, must be collation_t! */
		 }
	;

xq_expr_sort_dir
	: /* empty */ { $$ = XQ_ASCENDING; }
	| ASCENDING_L { $$ = XQ_ASCENDING; }
	| DESCENDING_L { $$ = XQ_DESCENDING; }
	;

xq_expr_sort_empty
	: /* empty */ { $$ = XQ_EMPTY_SQL_ORDER; }
	| EMPTY_GREATEST_L { $$ = XQ_EMPTY_GREATEST; }
	| EMPTY_LEAST_L { $$ = XQ_EMPTY_LEAST; }
	;

xq_expr_sort_collation
	: /* empty */ { $$ = NULL; }
	| COLLATION_L xq_strg { $$ = $2; }
	;

xq_expr_sort_type
	: /* empty */ { $$ = DV_UNKNOWN; }
	| AS_L xq_qname { $$ = $2; }
	;

xq_expr_flwr_forlets			/* ((XQ[14])|(XQ[15]))+ */
	: xq_expr_flwr_forlet				{ $$ = NULL; dk_set_push (&($$), $1); }
	| xq_expr_flwr_forlets xq_expr_flwr_forlet	{ $$ = $1; dk_set_push (&($$), $2); }
	;

xq_expr_flwr_forlet			/* (XQ[14])|(XQ[15]) */
	: xq_expr_flwr_for	/* default { $$ = $1; } is OK */
	| xq_expr_flwr_let	/* default { $$ = $1; } is OK */
	;

xq_expr_flwr_for			/* Like XQ[14] */
	: FOR_DOLLAR_L xq_expr_varins	{ $$ = $2; dk_set_push (&($$), (void *)(XQ_FOR)); }
	;

xq_expr_varins
	: xq_expr_varin					{ $$ = NULL; dk_set_push (&($$), $1); }
	| xq_expr_varins ',' _DOLLAR xq_expr_varin	{ $$ = $1; dk_set_push (&($$), $4); }
	;

xq_expr_varin
	: XQVARIABLE_NAME IN_L
            {
	      $<bookmark>$ = dk_alloc_box (sizeof (xp_lexbmk_t), DV_ARRAY_OF_LONG);
              ($<bookmark>$)[0] = xpp_arg->xpp_curr_lexem_bmk;
	    }
	   xq_expr_single
	    {
              $$ = xtlist (xpp_arg, 3, XQ_IN, box_copy ($1), xp_embedded_xmlview (xpp_arg, $<bookmark>3, $4));
	      dk_free_box ($<bookmark>3);
            }
	;

xq_expr_flwr_let			/* Like XQ[15] */
	: LET_DOLLAR_L xq_expr_varasss { $$ = $2; dk_set_push (&($$), (void *)(XQ_LET)); }
	;

xq_expr_varasss
	: xq_expr_varass				{ $$ = NULL; dk_set_push (&($$), $1); }
	| xq_expr_varasss ',' _DOLLAR xq_expr_varass	{ $$ = $1; dk_set_push (&($$), $4); }
	;

xq_expr_varass
	: XQVARIABLE_NAME _ASSIGN xq_expr_single { $$ = xtlist (xpp_arg, 3, XQ_ASSIGN, box_copy ($1), $3); }
	;

xq_expr_flwr_where_opt			/* (XQ[16])? */
	: /* empty */ { $$ = NULL; }
	| WHERE_L xq_expr { $$ = $2; }
	;

xq_expr_flwr_order_opt
	: /* empty */ { $$ = NULL; }
	| ORDER_BY_L xq_expr_sort_specs { $$ = $2; dk_set_push (&($$), (void *)((ptrlong)ORDER_BY_L)); }
	| STABLE_ORDER_BY_L xq_expr_sort_specs { $$ = $2; dk_set_push (&($$), (void *)((ptrlong)STABLE_ORDER_BY_L)); }
	;

xq_expr_typecases			/* Like (XQ[21])+ */
	: xq_expr_typecase			{ $$ = NULL; dk_set_push (&($$), $1); }
	| xq_expr_typecases xq_expr_typecase	{ $$ = $1; dk_set_push (&($$), $2); }
	;

xq_expr_typecase			/* XQ[21] */
	: CASE_L _DOLLAR XQVARIABLE_NAME AS_L xq_sequence_type RETURN_L xq_expr_single { $$ = (XT **) list (3, $5, $3, $7); }
	| CASE_L xq_sequence_type RETURN_L xq_expr_single { $$ = (XT **) list (3, $2, NULL, $4); }
	;

xq_expr_typedflt			/* From XQ[20] */
	: DEFAULT_L _DOLLAR XQVARIABLE_NAME RETURN_L xq_expr_single { $$ = (XT **) list (3, NULL, $3, $5); }
	| DEFAULT_L RETURN_L xq_expr_single { $$ = (XT **) list (3, NULL, NULL, $3); }
	;

xq_expr_validation_block
	: VALIDATE_LBRA_L	{ $$ = xpp_arg->xpp_xp_env->xe_validation_mode; }
	| VALIDATE_LAX_L '{'	{ $$ = XPP_VALIDATION_LAX; }
	| VALIDATE_STRICT_L '{'	{ $$ = XPP_VALIDATION_STRICT; }
	| VALIDATE_SKIP_L '{'	{ $$ = XPP_VALIDATION_SKIP; }
	;

/* XQ hierarchy of multiary expressions -- end */

/* XQ path expressions -- start */

xq_path					/* Like XQ[31] */
	: xq_path_rel_from_axn		%prec REL_PATH_TO_PATH
	| xq_path_calc
	| xq_path _SLASH xq_path_rel_from_axn		{ $$ = xp_path (xpp_arg, $1, $3, 0); }
	| xq_path _SLASH_SLASH xq_path_rel_from_axn	{ $$ = xp_path (xpp_arg, $1, $3, XP_SLASH_SLASH); }
	| xq_path _POINTER_VIA_ID xq_path_rel_from_axn	{ $$ = xp_path (xpp_arg, $1, $3, XP_DEREF); }
	| _SLASH xq_path_rel_from_axn		%prec LEFT_SLASH	{ $$ = xp_absolute (xpp_arg, $2, XP_ABS_CHILD); }
	| _SLASH_SLASH xq_path_rel_from_axn	%prec LEFT_SLASH	{ $$ = xp_absolute (xpp_arg, $2, XP_ABS_SLASH_SLASH); }
	| _SLASH			%prec STANDALONE_SLASH	{ $$ = xp_make_step (xpp_arg, XP_ROOT, (XT*) XP_NODE, NULL); }
	| xq_path _SLASH xq_path_calc	%prec SLASH_AS_MAP
		{
		  XT *src = $1;
		  $$ = xp_make_call (xpp_arg, "map", list (2, src, $3));
		}
	| xq_path _SLASH_SLASH xq_path_calc	%prec SLASH_AS_MAP
		{
		  XT *left = $1;
		  XT *node_type = xp_make_seq_type (xpp_arg, NODE_LPAR_L, NULL, NULL, 0, XQ_SEQTYPE_REQ_ONE);
		  XT *last_step = xp_make_step (xpp_arg, XP_DESCENDANT_OR_SELF, node_type, NULL);
		  XT *src = xp_path (xpp_arg, left, last_step, 0);
		  $$ = xp_make_call (xpp_arg, "map", list (2, src, $3));
		}
	;

xq_path_calc
	: xq_expr_primary_calc xq_path_step_qualifs_opt
		{
		  $$ = xp_make_filters (xpp_arg, $1, dk_set_nreverse ($2));
		}
	;


xq_path_rel_from_axn			/* Like XQ[32] */
	: xq_path_step_axis					{ $$ = xp_step (xpp_arg, NULL, $1, XP_BY_MAIN_STEP); }
	| xq_path_step_nodetest					{ $$ = xp_step (xpp_arg, NULL, $1, XP_BY_MAIN_STEP); }
	| xq_path_rel_from_axn _SLASH xq_path_step		%prec STEPS_IN_REL_PATH { $$ = xp_step (xpp_arg, $1, $3, XP_BY_MAIN_STEP); }
	| xq_path_rel_from_axn _SLASH_SLASH xq_path_step	%prec STEPS_IN_REL_PATH { $$ = xp_step (xpp_arg, $1, $3, XP_SLASH_SLASH); }
	| xq_path_rel_from_axn _POINTER_VIA_ID xq_path_step	%prec STEPS_IN_REL_PATH { $$ = xp_step (xpp_arg, $1, $3, XP_DEREF); }
	;

xq_path_step				/* Like XQ[33] */
	: xq_path_step_axis
	| xq_path_step_nodetest
	;

xq_path_step_axis			/* Like XQ[34] */
	: xq_path_axis xq_expr_node_test xq_path_step_qualifs_opt
		{
		  $$ = xp_make_step (xpp_arg, $1, $2,
		    ((NULL == $3) ? NULL :
		      (XT **) (list_to_array (dk_set_nreverse ($3))) ) ); }
	| _DOT_DOT
		{ $$ = xp_make_step (xpp_arg, XP_PARENT, (XT *)XP_NODE, NULL); }
	;

xq_path_step_nodetest			/* Like XQ[35] */
	: xq_expr_node_test xq_path_step_qualifs_opt
		{
		  $$ = xp_make_step (xpp_arg, XP_CHILD, $1, (XT **) list_to_array (dk_set_nreverse ($2)));
		  /* $$ = xp_make_filters (xpp_arg, $1, dk_set_nreverse ($2)); */
		}
	;


xq_path_step_qualifs_opt		/* Like XQ[36] */
	: /* empty */	{ $$ = NULL; }
	| xq_path_step_qualifs_opt xq_path_step_qualif	{ $$ = $1; dk_set_push (&($$), $2); }
	;

xq_path_step_qualif
	: '[' { xp_pred_start (xpp_arg); } xq_expr ']' { $$ = xp_make_pred (xpp_arg, $3); }
	;

xq_path_axis				/* Like XQ[37] */
	: axis_spec
	| XQNCNAME _COLON_COLON	{ xpyyerror (xpp_arg, "Unknown axis name"); }
	;

/* XQ path expressions -- end */

/* XQ primary expressions -- start */

xq_expr_primary_calc
	: xq_literal			{ $$ = xp_make_literal_tree (xpp_arg, $1, 1); }
	| xq_expr_variable
	| '(' xq_expr_seq ')'		{ $$ = $2; }	/* Like XQ[47] */
	| '(' ')'			{ $$ = xp_make_call (xpp_arg, "append", list(0)); }	/* Like XQ[47] */
	| _DOT				{ $$ = xp_make_step (xpp_arg, XP_SELF, (XT *) XP_NODE, NULL); }
	| xq_expr_funcall
	| xq_dir_ctor
	| xq_comp_ctor
	| xq_expr_syscall
	| xq_expr_ordering_block
		{
		  $<token_type>$ = xpp_arg->xpp_xp_env->xe_ordering_mode; xpp_arg->xpp_xp_env->xe_ordering_mode = $1;
		}
	  xq_expr '}'	{ $$ = $3; xpp_arg->xpp_xp_env->xe_ordering_mode = $<token_type>2;  }
	;

xq_expr_ordering_block
	: ORDERED_LBRA_L { $$ = XPP_ORDERING_ORDERED; }
	| UNORDERED_LBRA_L { $$ = XPP_ORDERING_UNORDERED; }
	;


xq_expr_node_test			/* XQ[40] */
	: xq_expr_name_test
	| xq_kind_test
	;

xq_expr_name_test			/* XQ[41] */
	: xq_expr_wildcard		/* default { $$ = $1; } is OK */
	| XQCNAME			{ $$ = xp_make_name_test_from_qname (xpp_arg, $1, 0); }
	| XQNCNAME			{ $$ = xp_make_name_test_from_qname (xpp_arg, $1, 0); }
	| XQNAMERESERVED		{ $$ = xp_make_name_test_from_qname (xpp_arg, $1, 0); }
	;

xq_expr_wildcard
	: _STAR				{ $$ = (XT *) XP_ELT; }
	| XQ_NCNAME_COLON_STAR		{ $$ = xtlist (xpp_arg, 4, XP_NAME_NSURI, xp_namespace_pref (xpp_arg, $1), XP_STAR, NULL); }
	| XQ_STAR_COLON_NCNAME		{ $$ = xtlist (xpp_arg, 4, XP_NAME_LOCAL, XP_STAR, box_copy ($1), NULL); }
	;

xq_expr_funcall				/* Like XQ[49] */
	: XQCNAME_LPAR xq_exprs ')'
		{
		    $$ = xp_make_call_or_funcall (xpp_arg, $1, list_to_array (dk_set_nreverse ($2)));
		}
	| XQCNAME_LPAR ')'
		{
		    $$ = xp_make_call_or_funcall (xpp_arg, $1, list(0));
		}
	| NOT_XQCNAME_LPAR xq_exprs ')'
		{
		    $$ = xp_make_call_or_funcall (xpp_arg, $1, list_to_array (dk_set_nreverse ($2)));
		    $$ = xp_make_call (xpp_arg, "not", list(1, $$));
		}
	| NOT_XQCNAME_LPAR ')'
		{
		    $$ = xp_make_call_or_funcall (xpp_arg, $1, list(0));
		    $$ = xp_make_call (xpp_arg, "not", list(1, $$));
		}
	;

xq_expr_syscall				/* Virtuoso extension, like Yukon */
	: SQL_COLON_COLUMN '(' xq_strg ')'	{ $$ = xp_make_sqlcolumn_ref (xpp_arg, $3); }
	| SQL_COLON_COLUMN '(' xq_strg error	{ xpyyerror (xpp_arg, "')' expected after column name"); }
	| SQL_COLON_COLUMN '(' error		{ xpyyerror (xpp_arg, "Column name in sql:column must be a string constant"); }
	| SQL_COLON_COLUMN error		{ xpyyerror (xpp_arg, "'(' expected after sql:column"); }
	;

xq_expr_variable
	: _DOLLAR XQVARIABLE_NAME		{ $$ = xp_make_variable_ref (xpp_arg, $2); }
	| XQVARIABLE_POS			{ $$ = xp_make_variable_ref (xpp_arg, $1); }
	;

xq_literal
	: xq_strg		/* default { $$ = $1; } is OK */
	| NUMBER		/* default { $$ = $1; } is OK */
	;

xq_strg
	: XQSQ_NSQSTRING_SQ	/* default { $$ = $1; } is OK */
	| XQDQ_NDQSTRING_DQ	/* default { $$ = $1; } is OK */
	;

/* XQ primary expressions -- end */

xq_comp_ctor
	: DOCUMENT_LBRA_L xq_exprs '}'
		{
		  $$ = xp_make_call (xpp_arg, "DOCUMENT computed constructor", revlist_to_array ($2));
		}
	| ELEMENT_QNAME_LBRA xq_comp_elem_body_opt '}'
		{
		  dk_set_push (&($2), xp_make_literal_tree (xpp_arg, xp_make_expanded_name (xpp_arg, $1, 0), 0));
		  $$ = xp_make_call (xpp_arg, "ELEMENT computed constructor", revlist_to_array ($2));
		}
	| ELEMENT_LBRA_L xq_expr '}' '{' xq_comp_elem_body_opt '}'
		{
		  dk_set_push (&($5), $2);
		  $$ = xp_make_call (xpp_arg, "ELEMENT computed constructor", revlist_to_array ($5));
		}
	| ATTRIBUTE_QNAME_LBRA xq_exprs_opt '}'
		{
		  dk_set_push (&($2), xp_make_literal_tree (xpp_arg, xp_make_expanded_name (xpp_arg, $1, 1), 0));
		  $$ = xp_make_call (xpp_arg, "ATTRIBUTE computed constructor", revlist_to_array ($2));
		}
	| ATTRIBUTE_LBRA_L xq_expr '}' '{' xq_exprs_opt '}'
		{
		  dk_set_push (&($5), $2);
		  $$ = xp_make_call (xpp_arg, "ATTRIBUTE computed constructor", revlist_to_array ($5));
		}
	| TEXT_LBRA_L xq_exprs '}'
		{
		  $$ = xp_make_call (xpp_arg, "TEXT computed constructor", revlist_to_array ($2));
		}
	| COMMENT_LBRA_L xq_exprs '}'
		{
		  $$ = xp_make_call (xpp_arg, "COMMENT computed constructor", revlist_to_array ($2));
		}
	| PI_LNAME_LBRA xq_exprs_opt '}'
		{
		  dk_set_push (&($2), xp_make_literal_tree (xpp_arg, $1, 1));
		  $$ = xp_make_call (xpp_arg, "PROCESSING-INSTRUCTION computed constructor", revlist_to_array ($2));
		}
	| PI_LBRA_L xq_expr '}' '{' xq_exprs_opt '}'
		{
		  dk_set_push (&($5), $2);
		  $$ = xp_make_call (xpp_arg, "PROCESSING-INSTRUCTION computed constructor", revlist_to_array ($5));
		}
	;

xq_comp_elem_body_opt
	: /* empty */		{ $$ = NULL; }
	| xq_comp_elem_body
	;

xq_comp_elem_body
	: xq_comp_elem_child	{ $$ = NULL; if ($1) dk_set_push (&($$), $1); }
	| xq_comp_elem_body ',' xq_comp_elem_child  { $$ = $1; if ($3) dk_set_push (&($$), $3); }
	;

xq_comp_elem_child
	: xq_expr_single
	| NAMESPACE_L '{' xq_strg '}'		{ $$ = NULL; }
	| NAMESPACE_L XQNCNAME '{' xq_strg '}'	{ $$ = NULL; }
	| NAMESPACE_LNAME_LBRA xq_strg '}'	{ $$ = NULL; }
	;

/* XQ direct element ctor -- start */

xq_dir_ctor
	: xq_dir_el_ctor
	| _LT_BANG_MINUS_MINUS XQ_XML_COMMENT_STRING { $$ = xp_make_direct_comment_ctor (xpp_arg, xp_make_literal_tree (xpp_arg, $2, 1)); }
	| _LT_QMARK xq_qname XQ_STRG_QMARK_GT	     { $$ = xp_make_direct_pi_ctor (xpp_arg, xp_make_literal_tree (xpp_arg, $2, 1), xp_make_literal_tree (xpp_arg, $3, 1)); }
	;

xq_dir_el_ctor
	: _LT_OF_TAG
		{
		  $<list>$ = xp_bookmark_namespaces (xpp_arg);
		}
		{
		  $<box>$ = xpp_arg->xpp_xp_env->xe_dflt_elt_namespace;
		}
	  xq_dir_el_name_spec xq_dir_el_attr_list_opt xq_dir_el_ctor_tail
		{
		  $$ = xp_make_direct_el_ctor (xpp_arg, $4, dk_set_nreverse($5), dk_set_nreverse($6));
		  xp_unregister_local_namespaces (xpp_arg, $<list>2);
		  xpp_arg->xpp_xp_env->xe_dflt_elt_namespace = $<box>3;
		}
	;

xq_dir_el_ctor_tail
	: _SLASH_GT						{ $$ = NULL; }
	| _GT_OF_TAG xq_dir_el_content xq_dir_el_closing_ctor	{ $$ = $2; }
	;

xq_dir_el_closing_ctor
	: _LT_SLASH _GT_OF_TAG			{ /* no default action */; }
	| _LT_SLASH xq_qname _GT_OF_TAG		{ /*dk_free_box ($2)*/; }
	;

xq_dir_el_name_spec
	: XQNCNAME		{ $$ = xp_make_literal_tree (xpp_arg, xp_make_expanded_name (xpp_arg, $1, 0), 0); }
	| XQCNAME		{ $$ = xp_make_literal_tree (xpp_arg, xp_make_expanded_name (xpp_arg, $1, 0), 0); }
	| '{' xq_expr '}'	{ $$ = $2; }
	;

xq_dir_el_attr_list_opt
	: /* empty */								{ $$ = NULL; }
	| xq_dir_el_attr_list_opt xq_dir_el_attr_spec _EQ xq_dir_el_attr_value	{ $$ = $1; dk_set_push (&($$), $2); dk_set_push (&($$), dk_set_nreverse($4)); }
	| xq_dir_el_attr_list_opt XMLNS _EQ xq_dir_el_attr_ns_uri		{ $$ = $1; xpp_arg->xpp_xp_env->xe_dflt_elt_namespace = box_dv_short_string ($4); }
	| xq_dir_el_attr_list_opt XQNAMERESERVED _EQ xq_dir_el_attr_ns_uri	{ $$ = $1; xp_register_namespace_prefix_by_xmlns (xpp_arg, $2, $4); }
	;

xq_dir_el_attr_spec
	: XQNCNAME		{ $$ = xp_make_literal_tree (xpp_arg, xp_make_expanded_name (xpp_arg, $1, 1), 0); }
	| XQCNAME		{ $$ = xp_make_literal_tree (xpp_arg, xp_make_expanded_name (xpp_arg, $1, 1), 0); }
	| '{' xq_expr '}'	{ $$ = $2; }
	;


xq_dir_el_attr_ns_uri
	: XQDQ_NAME_DQ
	| XQDQ_NDQSTRING_DQ
	| XQSQ_NSQSTRING_SQ
	;

xq_dir_el_attr_value
	: xq_expr_enclosed	{ $$ = NULL; dk_set_push (&($$), $1); }
	| XQDQ_NAME_DQ		{ $$ = NULL; dk_set_push (&($$), xp_make_literal_tree (xpp_arg, $1, 1)); }
	| XQDQ_NDQSTRING_DQ	{ $$ = NULL; dk_set_push (&($$), xp_make_literal_tree (xpp_arg, $1, 1)); }
	| XQSQ_NSQSTRING_SQ	{ $$ = NULL; dk_set_push (&($$), xp_make_literal_tree (xpp_arg, $1, 1)); }
	| XQDQ_NDQSTRING_LBRA xq_dir_el_attr_dq_tail	{ $$ = NULL; PUSH_STRING_ARG_OF_CONCAT($$, $1); $$ = dk_set_conc ($2, $$); }
	| XQSQ_NSQSTRING_LBRA xq_dir_el_attr_sq_tail	{ $$ = NULL; PUSH_STRING_ARG_OF_CONCAT($$, $1); $$ = dk_set_conc ($2, $$); }
	;


xq_dir_el_attr_dq_tail
	: xq_exprs RBRA_NDQSTRING_DQ
		{ $$ = $1;
		  PUSH_STRING_ARG_OF_CONCAT($$, $2);
		}
	| xq_exprs RBRA_NDQSTRING_LBRA xq_dir_el_attr_dq_tail
		{ $$ = $1;
		  PUSH_STRING_ARG_OF_CONCAT($$, $2);
		  $$ = dk_set_conc ($3, $$);
		}
	;

xq_dir_el_attr_sq_tail
	: xq_exprs RBRA_NSQSTRING_SQ
		{ $$ = $1;
		  PUSH_STRING_ARG_OF_CONCAT($$, $2);
		}
	| xq_exprs RBRA_NSQSTRING_LBRA xq_dir_el_attr_sq_tail
		{ $$ = $1;
		  PUSH_STRING_ARG_OF_CONCAT($$, $2);
		  $$ = dk_set_conc ($3, $$);
		}
	;

xq_dir_el_content
	: /* empty */	{ $$ = NULL; }
	| xq_dir_el_content xq_dir_el_child	{ $$ = $1; dk_set_push (&($$), $2); }
	;

xq_dir_el_child
	: xq_dir_ctor			/* default { $$ = $1; } is OK */
	| xq_expr_enclosed		/* default { $$ = $1; } is OK */
	| XQ_ECSTRING			{ $$ = xp_make_literal_tree (xpp_arg, $1, 1); }
	| CHAR_REF			{ $$ = xp_make_literal_tree (xpp_arg, $1, 1); }
	| PREDEFINED_ENTITY_REF		{ $$ = xp_make_literal_tree (xpp_arg, $1, 1); }
	| _LT_BANG_CDATA CDATA_SECTION	{ $$ = xp_make_literal_tree (xpp_arg, $2, 1); }
	;

/* XQ direct element ctor -- end */

/* XQ data manipulation statements -- begin */

/*
xq_dml_stmts
	: xq_dml_stmt			{ $$ = NULL; dk_set_push (&($$), $1); }
	| xq_dml_stmts ',' xq_dml_stmt	{ $$ = $1; dk_set_push (&($$), $3); }
	;


xq_dml_stmt
	: xq_sdml_stmt
	;


xq_sdml_stmt
	: xq_sdml_stmt_insert xq_sdml_locator xq_expr { $$ = xtlist (xpp_arg, 3, XQ_INSERT, $1, $2, $3); }
	| xq_sdml_stmt_move xq_sdml_locator xq_expr { $$ = xtlist (xpp_arg, 3, XQ_MOVE, $1, $2, $3); }
	| UPSERT xq_expr xq_sdml_stmt_with xq_sdml_locator xq_expr  { $$ = xtlist (xpp_arg, 3, XQ_UPSERT, $2, $3, $4, $5); }
	| UPSERT error { xpyyerror (xpp_arg, "error in UPSERT DML statement"); }
	| DELETE_L xq_expr { $$ = xtlist (xpp_arg, 2, XQ_DELETE, $2); }
	| DELETE_L error { xpyyerror (xpp_arg, "error in DELETE DML statement"); }
	| xq_sdml_stmt_rename TO_L xq_expr { $$ = xtlist (xpp_arg, 3, XQ_RENAME, $1, $3); }
	| REPLACE xq_expr xq_sdml_stmt_with { $$ = xtlist (xpp_arg, 3, XQ_REPLACE, $2, $3); }
	| REPLACE error { xpyyerror (xpp_arg, "error in REPLACE DML statement"); }
	;

xq_sdml_stmt_insert
	: INSERT xq_expr	%prec INSERT	{ $$ = $2; }
	| INSERT error { xpyyerror (xpp_arg, "error in INSERT DML statement"); }
	;

xq_sdml_stmt_move
	: MOVE xq_expr		%prec MOVE	{ $$ = $2; }
	| MOVE error { xpyyerror (xpp_arg, "error in MOVE DML statement"); }
	;

xq_sdml_stmt_rename
	: RENAME xq_expr	%prec RENAME	{ $$ = $2; }
	| RENAME error { xpyyerror (xpp_arg, "error in RENAME DML statement"); }
	;

xq_sdml_stmt_with
	: WITH xq_expr		%prec RENAME	{ $$ = $2; }
	| WITH error { xpyyerror (xpp_arg, "expression expected after WITH in DML statement"); }
	;

xq_sdml_locator
	: INTO { $$ = INTO; }
	| AFTER { $$ = AFTER; }
	| BEFORE { $$ = BEFORE; }
	| error { xpyyerror (xpp_arg, "INTO, AFTER or BEFORE (i.e., a \"DML locator\") expected"); }
	;
*/

/* XQ data manipulation statements -- end */

xq_expr_enclosed
	: '{' xq_expr_seq '}'		{ $$ = $2; }
	;


xq_expr_seq
	: xq_exprs
		{
		  /* if (1 == dk_set_length($1))
		    $$ = dk_set_pop (&($1));
		  else*/
		    $$ = xp_make_call (xpp_arg, "append", list_to_array (dk_set_nreverse ($1)));
		}
	;

xq_exprs_opt
	: /* empty */	{ $$ = NULL; }
	| xq_exprs
	;

xq_exprs
	: xq_expr_single		{ $$ = NULL; dk_set_push (&($$), $1); }
	| xq_exprs ',' xq_expr_single	{ $$ = $1; dk_set_push (&($$), $3); }
	;

xq_qname
	: XQNCNAME
	| XQCNAME
	| XQNAMERESERVED
	;

/* XQuery end */


/* XPath begin */


xp_options_seq_opt
	: /* empty */ { ; }
        | xp_options_seq { ; }
	;

xp_options_seq
	: '[' xp_options ']'	{ ; }
	| '[' xp_options error { xpyyerror (xpp_arg, "']' or option expected"); }
	;

xp_options
	: xp_option { ; }
	| xp_options xp_option { ; }
	| xp_options _RSQBRA_LSQBRA xp_option { ; }
	;

xp_option
	: O_HTTP { xp_reject_option_if_not_allowed (xpp_arg, XP_XPATH_OPTS); xpp_arg->xpp_xp_env->xe_is_http = 1; }
	| O_KEY { xp_reject_option_if_not_allowed (xpp_arg, XP_XPATH_OPTS); xpp_arg->xpp_xp_env->xe_is_for_key = 1; }
	| O__STAR { xp_reject_option_if_not_allowed (xpp_arg, XP_XPATH_OPTS); xpp_arg->xpp_xp_env->xe_is_for_attrs = 1; }
	| O_SAX { xp_reject_option_if_not_allowed (xpp_arg, XP_XPATH_OPTS); xpp_arg->xpp_xp_env->xe_is_sax = 1; }
	| O_SHALLOW { xp_reject_option_if_not_allowed (xpp_arg, XP_XPATH_OPTS); xpp_arg->xpp_xp_env->xe_is_shallow = 1; }
	| O_QUIET { xp_reject_option_if_not_allowed (xpp_arg, XP_XPATH_OPTS); xpp_arg->xpp_is_quiet = 1; }
	| O_DAVPROP { xp_reject_option_if_not_allowed (xpp_arg, XP_XPATH_OPTS); xpp_arg->xpp_is_davprop = 1; }
	| O_BASE_URI literal_strg { xp_reject_option_if_not_allowed (xpp_arg, XP_XPATH_OPTS); xpp_arg->xpp_xp_env->xe_base_uri = box_copy_tree ($2); }
	| O_DOC literal_strg {
#ifdef OLD_VXML_TABLES
	   xp_reject_option_if_not_allowed (xpp_arg, XP_XPATH_OPTS); xpp_arg->xpp_xp_env->xe_doc_spec = box_copy_tree ($2);
#else
           xp_error (xpp_arg, "The __doc XPATH option is deprecated after version 2.7 of Virtuoso Universal Server and not available in any version of Virtuoso Open Source");
#endif
	   }
	| O_VIEW view_name {
		xp_reject_option_if_not_allowed (xpp_arg, XP_XPATH_OPTS);
		if (NULL != xpp_arg->xpp_xp_env->xe_view)
		  xp_error (xpp_arg, "XML view is specified twice by __view option");
		xpp_arg->xpp_xp_env->xe_view = xmls_view_def ($2);
		if (NULL == xpp_arg->xpp_xp_env->xe_view)
		  xp_error (xpp_arg, "Nonexistent XML view specified by __view option");
	   }
	| O_TAG literal_strg { xp_reject_option_if_not_allowed (xpp_arg, XP_XPATH_OPTS); xpp_arg->xpp_xp_env->xe_result_tag = box_copy ($2); }
	| XQNAMERESERVED _EQ literal_strg {
		xp_reject_option_if_not_allowed (xpp_arg, XP_XPATH_OPTS);
		if (!strncmp ($1, "xmlns:", 6))
		  xp_register_namespace_prefix (xpp_arg, $1+6, $3);
		else
		  xpyyerror(xpp_arg, "Only xmlns special namespace may be used in parameter name");
	  }
	| XMLNS _EQ literal_strg { XPP_PROLOG_SET (xe_dflt_elt_namespace, "default element namespace", $3); }
	| O_LANG literal_strg { xp_reject_option_if_not_allowed (xpp_arg, XP_FREETEXT_OPTS); xpp_arg->xpp_lang = lh_get_handler ($2); }
	| O_ENC literal_strg { xp_reject_option_if_not_allowed (xpp_arg, XP_FREETEXT_OPTS); xp_set_encoding_option (xpp_arg, $2); }
	| XQNCNAME _EQ XQNCNAME {
		dk_set_push (&(xpp_arg->xpp_dtd_config_tmp_set), box_dv_short_string ($1));
		dk_set_push (&(xpp_arg->xpp_dtd_config_tmp_set), box_dv_short_string ($3));
	  }
	;


xpath_expr
	: path_expr			/* default { $$ = $1; } is OK */
	| xpath_expr K_OR xpath_expr		{ XBIN_OP ($$, BOP_OR, $1, $3); }
	| xpath_expr K_AND xpath_expr		{ XBIN_OP ($$, BOP_AND, $1, $3); }
	| K_NOT xpath_expr %prec K_NOT	{ XBIN_OP ($$, BOP_NOT, $2, NULL); }
	| xpath_expr _EQ xpath_expr		{ XBIN_OP ($$, BOP_EQ, $1, $3); }
	| xpath_expr _NOT_EQ xpath_expr		{ XBIN_OP ($$, BOP_NEQ, $1, $3); }
	| xpath_expr _LT xpath_expr		{ XBIN_OP ($$, BOP_LT, $1, $3); }
	| xpath_expr _LE xpath_expr		{ XBIN_OP ($$, BOP_LTE, $1, $3); }
	| xpath_expr _GT xpath_expr		{ XBIN_OP ($$, BOP_GT, $1, $3); }
	| xpath_expr _GE xpath_expr		{ XBIN_OP ($$, BOP_GTE, $1, $3); }
	| xpath_expr K_LIKE xpath_expr		{ XBIN_OP ($$, BOP_LIKE, $1, $3); }
	| xpath_expr _MINUS xpath_expr		{ XBIN_OP ($$, BOP_MINUS, $1, $3); }
	| xpath_expr _PLUS xpath_expr		{ XBIN_OP ($$, BOP_PLUS, $1, $3); }
	| xpath_expr _STAR xpath_expr		{ XBIN_OP ($$, BOP_TIMES, $1, $3); }
	| xpath_expr K_DIV xpath_expr		{ XBIN_OP ($$, BOP_DIV, $1, $3); }
	| xpath_expr K_MOD xpath_expr		{ XBIN_OP ($$, BOP_MOD, $1, $3); }
	| xpath_expr '|' xpath_expr
		{ $$ = xtlist (xpp_arg, 7, XP_UNION,
		    $1, $3, xe_new_xqst (xpp_arg, XQST_REF),
		    xe_new_xqst (xpp_arg, XQST_REF), xe_new_xqst (xpp_arg, XQST_REF),
		    xe_new_xqst (xpp_arg, XQST_INT) ); }
	| _MINUS xpath_expr %prec UMINUS	{ XBIN_OP ($$, BOP_MINUS, box_num_nonull (0), $2); }
	;



path
	: relative_path
	| absolute_path
	| _SLASH	%prec STANDALONE_SLASH	{ $$ = xp_make_step (xpp_arg, XP_ROOT, (XT*) XP_NODE, NULL); }
	;


relative_path
	: step		 { $$ = xp_step (xpp_arg, NULL, $1, XP_BY_MAIN_STEP); }
	| relative_path _SLASH step { $$ = xp_step (xpp_arg, $1, $3, XP_BY_MAIN_STEP); }
	| relative_path _SLASH_SLASH step { $$ = xp_step (xpp_arg, $1, $3, XP_SLASH_SLASH); }
	;


absolute_path
	: _SLASH relative_path		%prec LEFT_SLASH { $$ = xp_absolute (xpp_arg, $2, XP_ABS_CHILD); }
	| _SLASH_SLASH relative_path	%prec LEFT_SLASH { $$ = xp_absolute (xpp_arg, $2, XP_ABS_SLASH_SLASH); }
	;


step
	: axis_spec node_test opt_predicates { $$ = xp_make_step (xpp_arg, $1, $2, $3); }
	| node_test opt_predicates	 { $$ = xp_make_step (xpp_arg, XP_CHILD, $1, $2); }
	| _DOT opt_predicates		{ $$ = xp_make_step (xpp_arg, XP_SELF, (XT*) XP_NODE, $2); }
	| _DOT_DOT opt_predicates	{ $$ = xp_make_step (xpp_arg, XP_PARENT, (XT*) XP_NODE, $2); }
	;


axis_spec
	: axis_name /* default { $$ = $1; } is OK */
	| _AT { $$ = XP_ATTRIBUTE; }
	;


node_test
	: XQNCNAME		{ $$ = xp_make_name_test_from_qname (xpp_arg, $1, 0); }
	| K_NOT	%prec NOT_AS_NAME	{ $$ = xp_make_name_test_from_qname (xpp_arg, box_dv_uname_string ("not"), 0); }
	| XQNAMERESERVED	{ $$ = xp_make_name_test_from_qname (xpp_arg, $1, 0); }
	| XQ_NCNAME_COLON_STAR	{ $$ = xtlist (xpp_arg, 4, XP_NAME_NSURI, xp_namespace_pref (xpp_arg, $1), XP_STAR, NULL); }
	| XQ_STAR_COLON_NCNAME	{ $$ = xtlist (xpp_arg, 4, XP_NAME_LOCAL, XP_STAR, box_copy ($1), NULL); }
	| _STAR			{ $$ = (XT *) XP_ELT; }
	| PI_LPAR_L literal ')'	{ $$ = xp_make_name_test_from_qname (xpp_arg, $2, 0); $$->type = XP_PI; }
	| PI_LPAR_L XQNCNAME ')'	{ $$ = xp_make_name_test_from_qname (xpp_arg, $2, 0); $$->type = XP_PI; }
	| PI_LPAR_L ')'		{ $$ = (XT*) XP_PI; }
	| COMMENT_LPAR_L ')'	{ $$ = (XT*) XP_COMMENT; }
	| TEXT_LPAR_L ')'	{ $$ = (XT*) XP_TEXT; }
	| NODE_LPAR_L ')'	{ $$ = (XT*) XP_NODE; }
	| XQCNAME		{ $$ = xp_make_name_test_from_qname (xpp_arg, $1, 0); }
	;


axis_name
	: A_ANCESTOR		{ $$ = XP_ANCESTOR; }
	| A_ANCESTOR_OR_SELF	{ $$ = XP_ANCESTOR_OR_SELF; }
	| A_ATTRIBUTE		{ $$ = XP_ATTRIBUTE; }
	| A_CHILD		{ $$ = XP_CHILD; }
	| A_DESCENDANT		{ $$ = XP_DESCENDANT; }
	| A_DESCENDANT_OR_SELF	{ $$ = XP_DESCENDANT_OR_SELF; }
	| A_FOLLOWING		{ $$ = XP_FOLLOWING; }
	| A_FOLLOWING_SIBLING	{ $$ = XP_FOLLOWING_SIBLING; }
	| A_NAMESPACE		{ $$ = XP_NAMESPACE; xpyyerror (xpp_arg, "namespace axis not allowed"); }
	| A_PARENT		{ $$ = XP_PARENT; }
	| A_PRECEDING		{ $$ = XP_PRECEDING; }
	| A_PRECEDING_SIBLING	{ $$ = XP_PRECEDING_SIBLING; }
	| A_SELF		{ $$ = XP_SELF; }
	;

opt_predicates
	:  /* empty */ { $$ = NULL; }
	| pred_list	{ $$ = (XT **) list_to_array ($1); }
	;

predicate
	: '[' { xp_pred_start (xpp_arg); }  xpath_expr ']' { $$ = xp_make_pred (xpp_arg, $3); }
	;

pred_list
	: predicate { $$ = CONS ($1, NULL); }
	| pred_list predicate { $$ = NCONC ($1, CONS ($2, NULL)); }
	;


variable_ref
        : _DOLLAR XQVARIABLE_NAME	{ $$ = xp_make_variable_ref(xpp_arg, $2); }
        | XQVARIABLE_POS		{ $$ = xp_make_variable_ref(xpp_arg, $1); }
	;


primary_expr
	: variable_ref
	| '(' xpath_expr ')' { $$ = $2; }
	| xpath_function
	| literal	{ $$ = xp_make_literal_tree (xpp_arg, $1, 1); }
	;


xpath_function
	: XQCNAME_LPAR xpath_arg_list ')'
		{
		  $$ = xp_make_call_or_funcall (xpp_arg, $1, list_to_array ($2));
		}
	| NOT_XQCNAME_LPAR xpath_arg_list ')'
		{
		  $$ = xp_make_call_or_funcall (xpp_arg, $1, list_to_array ($2));
		  $$ = xp_make_call (xpp_arg, "not", list(1, $$));
		}
	;

xpath_arg_list
	: /*empty */ { $$ = NULL; }
	| xpath_expr { $$ = CONS ($1, NULL); }
	| xpath_arg_list ',' xpath_expr { $$ = NCONC ($1, CONS ($3, NULL)); }
	;



path_expr
	: path
	| filter_expr
	| filter_expr _SLASH relative_path { $$ = xp_path (xpp_arg, $1, $3, 0); }
	| filter_expr _SLASH_SLASH relative_path { $$ = xp_path (xpp_arg, $1, $3, XP_SLASH_SLASH); }
	;


filter_expr
	: primary_expr
	| primary_expr predicate { $$ = xp_make_filter (xpp_arg, $1, $2); }
	;




literal
	: literal_strg
	| NUMBER
	;

literal_strg
	: XQSQ_NSQSTRING_SQ
	| XQDQ_NDQSTRING_DQ
	| XQDQ_NAME_DQ
	;

view_name
	: literal_strg
		{ $$ = xp_xml_view_name (xpp_arg, NULL, NULL, $1); }
	| literal_strg _DOT literal_strg
		{ $$ = xp_xml_view_name (xpp_arg, NULL, $1, $3); }
	| literal_strg _DOT literal_strg _DOT literal_strg
		{ $$ = xp_xml_view_name (xpp_arg, $1, $3, $5); }
	| literal_strg _DOT_DOT literal_strg
		{ /* Note one _DOT_DOT here, not two _DOTs */
		  $$ = xp_xml_view_name (xpp_arg, $1, NULL, $3); }
	;

text_exp
	: SINGLE_WORD { $$ = xp_word_or_phrase_from_string (xpp_arg, $1, xpp_arg->xpp_enc, xpp_arg->xpp_lang, 1); }
	| literal_strg { $$ = xp_word_or_phrase_from_string (xpp_arg, $1, xpp_arg->xpp_enc, xpp_arg->xpp_lang, 1); }
	| '^' literal_strg { $$ = xp_word_from_exact_string (xpp_arg, $2, xpp_arg->xpp_enc, 1); }
	| text_exp K_AND text_exp		{TBIN_OP ($$, BOP_AND, $1, $3); }
	| text_exp K_AND K_NOT text_exp		{ TBIN_OP ($$, XP_AND_NOT, $1, $4); }
	| text_exp K_OR text_exp		{ TBIN_OP ($$, BOP_OR, $1, $3); }
	| text_exp K_NEAR text_exp		{ TBIN_OP ($$, XP_NEAR, $1, $3); }
	| '(' text_exp ')' { $$ = $2; }
	| _LPAR_LSQBRA xp_options ']' text_exp ')' { $$ = $4; }
	| _LPAR_LSQBRA xp_options error { xpyyerror (xpp_arg, "']' or option expected"); }
	;
