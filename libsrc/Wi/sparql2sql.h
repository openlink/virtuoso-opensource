/*
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
 *  
 *  
*/
#ifndef __SPARQL2SQL_H
#define __SPARQL2SQL_H
#include "sparql.h"


/* PART 1. TERM REWRITING */

#define SPAR_GPT_NODOWN		0x10	/* Don't trav children */
#define SPAR_GPT_COMPLETED	0x20	/* Don't trav anything at all: the processing is complete */
#define SPAR_GPT_RESCAN		0x40	/* Lists of children should be found again because they may become obsolete */
#define SPAR_GPT_ENV_PUSH	0x01	/* Environment should be pushed. */

/*! Returns combination of SPAR_GPT_... bits */
typedef int sparp_gp_trav_cbk_t (sparp_t *sparp, SPART *curr, void **trav_env_this, void *common_env);

extern int sparp_gp_trav (sparp_t *sparp, SPART *root, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 );

extern int sparp_gp_trav_int (sparp_t *sparp, SPART *tree,
  void **trav_env_this, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 );

struct sparp_equiv_s;

/*! Equivalence class of variables. All instances of sparp_equiv_s are enumerated in spare_equivs */
typedef struct sparp_equiv_s
  {
    ptrlong e_own_idx;		/*!< Index of this instance (in spare_equivs) */
    SPART *e_gp;		/*!< Graph pattern where these variable resides */
    caddr_t *e_varnames;	/*!< Array of distinct names of equivalent variables. Usually one element, if there's no ?x=?y in FILTER */
    SPART **e_vars;		/*!< Array of all equivalent variables, including different occurencies of same name in different triples */
    ptrlong e_var_count;	/*!< Number of used items in e_vars. This can be zero if equiv passes top-level var from alias to alias without local uses */
    ptrlong e_restrictions;	/*!< Restrictions that are common for all variable (can be propagated) */
    ptrlong e_uses;		/*!< Number of significally distinct local uses (+1 if in any filter, +1 if in e_inner_in, +1 for each member or item in triples) */
    ptrlong e_gpso_uses;	/*!< Number of all local uses in members (+1 for each in G, P, S or O in triples */
    ptrlong e_const_reads;	/*!< Number of constant-read uses in filters and in 'graph' of members */
    caddr_t e_datatype;		/*!< Datatype if known */
    SPART * e_fixedvalue;	/*!< Fixed value if variables are found to be equal to a constant or an external parameter */
    ptrlong *e_subvalue_idxs;	/*!< Subselects where values of these variables come from */
    ptrlong *e_receiver_idxs;	/*!< Aliases of surrounding query where values of variables from this equiv are used */
  } sparp_equiv_t;

#define SPARP_EQUIV_GET_NAMESAKES	0x01	/*!< sparp_equiv_get returns equiv of namesakes, no need to search for exact var. */
#define SPARP_EQUIV_INS_CLASS		0x02	/*!< sparp_equiv_get has a right to add a new equiv to the haystack_gp */
#define SPARP_EQUIV_INS_VARIABLE	0x04	/*!< sparp_equiv_get has a right to insert needle_var into an equiv */
#define SPARP_EQUIV_GET_ASSERT		0x08	/*!< sparp_equiv_get will signal internal error instead of returning NULL */
/*! Finds or create an equiv class for a needle_var in haystack_gp.
The core behaviour is specified by (flags & (SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE)):
   when 0 then only existing equiv with existing occurence is returned;
   when SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE then new equiv with 1 new variable can be added;
   when SPARP_EQUIV_INS_CLASS then new equiv with no variables can be added, for passing from alias to alias.
If (flags & SPARP_EQUIV_GET_NAMESAKES) then \c needle_var can be a boxed string with name of variable.
*/
extern sparp_equiv_t *sparp_equiv_get (sparp_t *sparp, SPART *haystack_gp, SPART *needle_var, int flags);
/*! Similar to sparp_equiv_get(), but gets a vector of pointers to equivs instead of \c sparp */
extern sparp_equiv_t *sparp_equiv_get_ro (sparp_equiv_t **equivs, ptrlong equiv_count, SPART *haystack_gp, SPART *needle_var, int flags);
/*! Finds an equiv class that supplies a subvalue to the \c receiver from the specified \c haystack_gp */
extern sparp_equiv_t *sparp_equiv_get_subvalue_ro (sparp_equiv_t **equivs, ptrlong equiv_count, SPART *haystack_gp, sparp_equiv_t *receiver);

/* Returns 1 if connection exists (or added), 0 otherwise. GPFs if tries to add the second up */
extern int sparp_equiv_connect (sparp_t *sparp, sparp_equiv_t *outer, sparp_equiv_t *inner, int add_if_missing);

/* Returns 1 if connection existed and removed. */
extern int sparp_equiv_disconnect (sparp_t *sparp, sparp_equiv_t *outer, sparp_equiv_t *inner);

#define SPARP_EQUIV_MERGE_ROLLBACK	1001 /*!< Restrict or merge is impossible (in principle or just not implemented) */
#define SPARP_EQUIV_MERGE_OK		1002 /*!< Restrict or merge is done successfully */
#define SPARP_EQUIV_MERGE_CONFLICT	1003 /*!< Restrict or merge is done but it is proven that restrictions contradict */
#define SPARP_EQUIV_MERGE_DUPE		1004 /*!< Merge gets \c primary equal to \c secondary */

/*! Tries to restrict \c primary by \c datatype and/or value.
If neither datatype nor value is provided, SPARP_EQUIV_MERGE_OK is returned. */
extern int sparp_equiv_restrict_by_literal (sparp_t *sparp, sparp_equiv_t *primary, caddr_t datatype, SPART *value);

/*! Removes unused \c garbage from the list of equivs of its gp.
The debug version GPFs if the \c garbage is somehow used. */
extern void sparp_equiv_remove (sparp_t *sparp, sparp_equiv_t *garbage);

/*! Merges the content of \c secondary into \c primary (when a variable from \c secondary is proven to be equal to one from \c primary.
At the end of operation, varnames, vars, restrinctions, counters subvalues and receivers from \c secondary are added to \c primary
and \c secondary is replaced with \c primary (or removed as dupe) from lists of uses in gp, receivers of senders and senders of receivers.
Conflict in datatypes or fixed values results in SPART_VARR_CONFLICT to eliminate never-happen graph pattern later.
Returns appropriate SPARP_EQUIV_MERGE_xxx */
extern int sparp_equiv_merge (sparp_t *sparp, sparp_equiv_t *primary, sparp_equiv_t *secondary);

/* Returns whether two given fixedvalue trees are equal (same language and SQL value, no comparison for datatypes) */
extern int sparp_fixedvalues_equal (sparp_t *sparp, SPART *first, SPART *second);

/*! Returns whether two given equivs have equal restriction by fixedvalue (and fixedtype).
If any of two are not restricted or they are restricted by two different values then the fuction returns zero */
extern int sparp_equivs_have_same_fixedvalue (sparp_t *sparp, sparp_equiv_t *first_eq, sparp_equiv_t *second_eq);


/*! Performs all basic term rewritings of the query tree */
extern void sparp_rewrite_basic (sparp_t *sparp);

/* PART 2. OUTPUT GENERATOR */

struct spar_sqlgen_s;
struct rdf_ds_field_s;
struct rdf_ds_s;

/*! Description of single field where RDF data may come from.
Every rdfdf describes a set of SQL expressions.
They convert data between 'short', 'long' and 'native SQL' data.
'Short' is something stored in the table;
'short' value that is enough to find out the type and the lang 
and compare two refs of the same graph(!) for equivalence and check if two literals of the same graph(!) are almost equal.
Not actually "same graph", the correct interop condition is "same format and same uri_id_offset".
'Long' is a standard form, including full serialized SQL datum;
'long' value is ref ID compareable among any graphs or seialized object value;
'long' consists of BLOB id (if any), type, language and SQL value.
Templates are strings with insertions like ^{alias}^, ^{alias-dot}^, ^{tree}^.
*/
typedef struct rdf_ds_field_s
{
  struct rdf_ds_s *rdfdf_ds;			/*!< Datasource the field belongs to */
  ccaddr_t rdfdf_format;			/*!< Name of format of 'short' representation */
  /* Templates that convert field value into other types */
  ccaddr_t rdfdf_short_tmpl;			/*!< 'short' value template, can be NULL */
  ccaddr_t rdfdf_long_tmpl;			/*!< 'long' value template, can be NULL */
  ccaddr_t rdfdf_sqlval_tmpl;			/*!< 'sqlval' value template, can be NULL */
  ccaddr_t rdfdf_bool_tmpl;			/*!< Boolean value template, can be NULL */
  /* Templates of booleans that tell whether the short is of some sort: */
  ccaddr_t rdfdf_isref_of_short_tmpl;		/*!< ... whether the short is ref */
  ccaddr_t rdfdf_isuri_of_short_tmpl;		/*!< ... whether the short is uri */
  ccaddr_t rdfdf_isblank_of_short_tmpl;		/*!< ... whether the short is blank node ref */
  ccaddr_t rdfdf_islit_of_short_tmpl;		/*!< ... whether the short is literal */
  /* Templates that convert short value into other types (can be applied to both field and not field expression) */
  ccaddr_t rdfdf_long_of_short_tmpl;		/*!< ... long from short */
  ccaddr_t rdfdf_sqlval_of_short_tmpl;		/*!< ... SQL value from short */
  ccaddr_t rdfdf_datatype_of_short_tmpl;	/*!< ... datatype IRI string from short */
  ccaddr_t rdfdf_language_of_short_tmpl;	/*!< ... language ID string from short */
  ccaddr_t rdfdf_bool_of_short_tmpl;		/*!< ... boolean value from short */
  ccaddr_t rdfdf_uri_of_short_tmpl;		/*!< ... URI string from short */
  ccaddr_t rdfdf_strsqlval_of_short_tmpl;	/*!< ... SQL representation of the string value of short */
  /* Templates of expressions that make short values from other representations */
  ccaddr_t rdfdf_short_of_typedsqlval_tmpl;	/*!< ... makes short by SQL value with specified type and/or language */
  ccaddr_t rdfdf_short_of_sqlval_tmpl;		/*!< ... makes short by sqlvalue with no language and a datatype specified by SQL type */
  ccaddr_t rdfdf_short_of_long_tmpl;		/*!< ... makes short by long */
  ccaddr_t rdfdf_short_of_uri_tmpl;		/*!< ... makes short by uri */
  /* Misc */
  ccaddr_t rdfdf_cmp_func_name;			/*!< Name of comparison function that acts like strcmp but args are of this type */
  ccaddr_t rdfdf_typemin_tmpl;			/*!< Template of expn that returns the smallest value of the type of value of arg */
  ccaddr_t rdfdf_typemax_tmpl;			/*!< Template of expn that returns the biggest possible value of the type of value of arg */
  /* Metadata about values that can be stored in this field */
  ptrlong rdfdf_ok_for_any_sqlvalue;		/*!< Nonzero if the field format can store any possible SQL value (even if the field itself can not) */
  ptrlong rdfdf_restrictions;			/*!< Natural restrictions on values stored at the field */
  ccaddr_t rdfdf_datatype;			/*!< Datatype of stored values, if fixed */
  ccaddr_t rdfdf_language;			/*!< Language, if fixed */
  ccaddr_t rdfdf_fixedvalue;			/*!< Value of stored values, if fixed */
  ptrlong rdfdf_uri_id_offset;			/*!< The value that should be added to locally stored ref id in order to get portable ref id */
} rdf_ds_field_t;

#define RDF_DS_FIELD_SAME_FORMAT(a,b) (\
  ((a)->rdfdf_uri_id_offset == (b)->rdfdf_uri_id_offset) && \
  !strcmp ((a)->rdfdf_format, (b)->rdfdf_format) )

#define RDF_DS_FIELD_SUBFORMAT_OF(a,b) (\
  ((a)->rdfdf_uri_id_offset == (b)->rdfdf_uri_id_offset) && \
  ((a)->rdfdf_format == strstr ((a)->rdfdf_format, (b)->rdfdf_format)) )

/* Special 'macro' names of ssg_valmode_t modes. The order of numeric values is important ssg_shortest_valmode() */
#define SSG_VALMODE_SHORT		((ssg_valmode_t)((ptrlong)(0x300)))
#define SSG_VALMODE_LONG		((ssg_valmode_t)((ptrlong)(0x310)))
#define SSG_VALMODE_SQLVAL		((ssg_valmode_t)((ptrlong)(0x320)))
#define SSG_VALMODE_DATATYPE		((ssg_valmode_t)((ptrlong)(0x330)))
#define SSG_VALMODE_LANGUAGE		((ssg_valmode_t)((ptrlong)(0x340)))
#define SSG_VALMODE_AUTO		((ssg_valmode_t)((ptrlong)(0x350)))
#define SSG_VALMODE_BOOL		((ssg_valmode_t)((ptrlong)(0x360)))
#define SSG_VALMODE_SPECIAL		((ssg_valmode_t)((ptrlong)(0x370)))
/* typedef struct rdf_ds_field_s *ssg_valmode_t; -- moved to sparql.h */

extern ssg_valmode_t ssg_shortest_valmode (ssg_valmode_t m1, ssg_valmode_t m2);

/*! Description of predicate stored as pair of object field and subject fields in same row. */
typedef struct rdf_ds_pred_mapping_s
{
  ccaddr_t rdfdpm_predicate;		/*!< URI of mapped predicate */
  rdf_ds_field_t *rdfdpm_subject;	/*!< Field where subjects reside */
  rdf_ds_field_t *rdfdpm_object;	/*!< Field where objects reside */
} rdf_ds_pred_mapping_t;

/*! Description of RDF datasource. RDF DS is something that can store one or more graphs where predicates, sujects and objects
are either arbitrary or comes from a fixed list defined in schema or just fixed. */
typedef struct rdf_ds_s
{
  rdf_ds_field_t *tr_fields[SPART_TRIPLE_FIELDS_COUNT];	/*!< Description of canonical fields, if any */
  rdf_ds_pred_mapping_t *rdfd_pred_mappings;
  ccaddr_t rdfd_base_table;		/*!< Table where triples are stored */
  ccaddr_t rdfd_uri_local_table;	/*!< Table that resolves ref ids to URIs */
  ccaddr_t rdfd_uri_ns_table;		/*!< Table that resolves ns ids to namespace URIs */
  ccaddr_t rdfd_uri_lob_table;		/*!< Table that contains full text of lobs */
  ccaddr_t rdfd_allmappings_view;	/*!< View that maps multicolumn table into union of triples */
} rdf_ds_t;

extern rdf_ds_t *rdf_ds_sys_storage;

/*! Loads all known definitions of datasources */
extern void rdf_ds_load_all (void);

typedef struct rdf_ds_usage_s
{
  rdf_ds_t *rdfdu_ds;	/*!< Datasource */
  rdf_ds_field_t *tr_fields[SPART_TRIPLE_FIELDS_COUNT];	/*!< Description of fields to be used */
  caddr_t rdfdu_alias;	/*!< Table alias used for the occurence */
} rdf_ds_usage_t;

extern void ssg_print_tmpl (struct spar_sqlgen_s *ssg, rdf_ds_field_t *field, ccaddr_t tmpl, caddr_t alias, SPART *tree);

/*! This returns dk_set_t of temporary dk_alloc-ed instances of rdf_ds_usage_t
that describe an union of all elementary datasources that can store triples that match a pattern.
The receiver should iterate the result by (rdf_ds_usage_t *)(dk_set_pop(...)) and
dk_free (... sizeof (rdf_ds_usage_t)) every iterated item */
extern dk_set_t rdf_ds_find_appropriate (SPART *triple, SPART **sources, int ignore_named_sources);

/*! This searches for declaration of type by its name. NULL name result in NULL output, unknown name is an error */
extern ssg_valmode_t ssg_find_valmode_by_name (ccaddr_t name);

extern caddr_t ssg_find_formatter_by_name (ccaddr_t name);

/*! Field is the expression that represents the value of a SPARQL variable. */
typedef struct spar_sqlgen_var_s
{
  rdf_ds_t		*ssgv_source;	/*!< The source where the value comes from, to access table names and vtable with template printer. */
  rdf_ds_field_t	*ssgv_field;	/*!< The field, with data for template printer */
  int			ssgv_is_short;	/*!< Flag whether the value is short (for local joins in graph) or long (for generic ops) */
} spar_sqlgen_var_t;

/*! Context of SQL generator */
typedef struct spar_sqlgen_s
{
/* Query data */
  /*spar_query_t		*ssg_query;*/	/*!< Query to process */
  struct sql_comp_s	*ssg_sc;		/*!< Environment for sqlc_exp_print and similar functions. */
  sparp_t		*ssg_sparp;		/*!< Pointer to general parser data */
  SPART			*ssg_tree;		/*!< Select tree to process, of type SPAR_REQ_TOP */
  sparp_equiv_t		**ssg_equivs;		/*!< Shorthand for ssg_tree->_.req_top.equivs */
  ptrlong		ssg_equiv_count;	/*!< Shorthand for ssg_tree->_.req_top.equiv_count */
/* Run-time environment */
  SPART			**ssg_sources;		/*!< Data sources from ssg_tree->_.req_top.sources and/or environment */
  rdf_ds_t		*ssg_sys_ds;		/*!< Default datasource that is root of closed group of tables, usually rdf_ds_sys_storage */
  id_hash_t		*ssg_fields;		/*!< A hashtable that maps vars into SQL fields, keys are SPART * on vars, values points to spar_sqlgen_var_t */
/* Codegen temporary values */
  dk_session_t		*ssg_out;		/*!< Output for SQL text */
  int			ssg_where_l_printed;	/*!< Flags what to print before a filter: " WHERE" if 0, " AND" otherwise */
  const char *          ssg_where_l_text;	/*!< Text to print when (0 == ssg_where_l_printed), usually " WHERE" */
  int			ssg_indent;		/*!< Number of whitespaces to indent. Actually, pairs of whitespaces, not singles */
} spar_sqlgen_t;


#define ssg_putchar(c) session_buffered_write_char (c, ssg->ssg_out)
#define ssg_puts(strg) session_buffered_write (ssg->ssg_out, strg, strlen (strg))

#define SSG_INDENT_FACTOR 4
#define ssg_newline(back) \
  do { \
    int ind = ssg->ssg_indent; \
    if (ind) \
      ind = 1 + ind * SSG_INDENT_FACTOR - (back); \
    else \
      ind = 1; \
    session_buffered_write (ssg->ssg_out, "\n                              ", (ind > 31) ? 31 : ind); \
    } while (0)

SPART *ssg_find_gp_by_alias (spar_sqlgen_t *ssg, caddr_t alias);
SPART *ssg_find_gp_by_eq_idx (spar_sqlgen_t *ssg, ptrlong eq_idx);

/*! Prints an SQL identifier. 'prin' instead of 'print' because it does not print whitespace or delim before the text */
extern void ssg_prin_id (spar_sqlgen_t *ssg, const char *name);
extern void ssg_print_literal (spar_sqlgen_t *ssg, ccaddr_t type, SPART *lit);
extern void ssg_print_equiv (spar_sqlgen_t *ssg, caddr_t selectid, sparp_equiv_t *eq, caddr_t as_name);

extern ssg_valmode_t ssg_rettype_of_global_param (spar_sqlgen_t *ssg, caddr_t name);
extern ssg_valmode_t ssg_rettype_of_function (spar_sqlgen_t *ssg, caddr_t name);
extern ssg_valmode_t ssg_argtype_of_function (spar_sqlgen_t *ssg, caddr_t name, int arg_idx);
extern void ssg_prin_function_name (spar_sqlgen_t *ssg, ccaddr_t name);

extern void ssg_print_valmoded_scalar_expn (spar_sqlgen_t *ssg, SPART *tree, ssg_valmode_t needed, ssg_valmode_t native);
extern void ssg_print_scalar_expn (spar_sqlgen_t *ssg, SPART *tree, ssg_valmode_t needed);
extern void ssg_print_filter_expn (spar_sqlgen_t *ssg, SPART *tree);

#define SSG_RETVAL_USES_ALIAS			0x01	/*!< Return value can be printed in form 'expn AS alias' if alias name is not NULL */
#define SSG_RETVAL_MUST_PRINT_SOMETHING		0x02	/*!< The function signals an error instead of returning failure */
#define SSG_RETVAL_CAN_PRINT_NULL		0x04	/*!< The function should print at least NULL but it can not return failure */
#define SSG_RETVAL_FROM_GOOD_SELECTED		0x08	/*!< Use result-set columns from 'good' (non-optional) subqueries */
#define SSG_RETVAL_FROM_ANY_SELECTED		0x10	/*!< Use result-set columns from any subqueries, including 'optional' that can make NULL */
#define SSG_RETVAL_FROM_JOIN_MEMBER		0x20	/*!< The function can print expression like 'tablealias.colname' */
#define SSG_RETVAL_FROM_FIRST_UNION_MEMBER	0x40
#define SSG_RETVAL_TOPMOST			0x80
#define SSG_RETVAL_NAME_INSTEAD_OF_TREE		0x100
/* descend = 0 -- at level, can descend. 1 -- at sublevel, can't descend, -1 -- at level, can't descend */
extern int ssg_print_equiv_retval_expn (spar_sqlgen_t *ssg, SPART *gp,
  sparp_equiv_t *eq, int flags, caddr_t as_name, ssg_valmode_t needed );

extern void ssg_print_retval_simple_expn (spar_sqlgen_t *ssg, SPART *gp, SPART *tree, ssg_valmode_t needed);

extern void ssg_print_table_exp (spar_sqlgen_t *ssg, SPART *tree, int pass);

#define SSG_PRINT_UNION_NOFIRSTHEAD	0x01	/*!< Flag to suppress printing of 'SELECT retvallist' of the first member of the union */
#define SSG_PRINT_UNION_NONEMPTY_STUB	0x02	/*!< Flag to print a stub that returns a 1-row result of single column, instead of a stub with empty resultset */
extern void ssg_print_union (spar_sqlgen_t *ssg, SPART *gp, SPART **retlist, int head_flags, int retval_flags, ssg_valmode_t needed);

extern void ssg_print_orderby_item (spar_sqlgen_t *ssg, SPART *gp, SPART *oby_itm);

/*! Fills in ssg->ssg_out with an SQL text */
extern void ssg_make_sql_query_text (spar_sqlgen_t *ssg);

#endif
