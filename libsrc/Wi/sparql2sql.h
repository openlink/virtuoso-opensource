/*
 *  $Id$
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
 */

#ifndef __SPARQL2SQL_H
#define __SPARQL2SQL_H
#include "sparql.h"
#include "rdf_mapping_jso.h"

extern ptrdiff_t qm_field_map_offsets[SPART_TRIPLE_FIELDS_COUNT];
extern ptrdiff_t qm_field_constants_offsets[SPART_TRIPLE_FIELDS_COUNT];

#define SPARP_FIELD_QMV_OF_QM(qm,field_ctr) (JSO_FIELD_ACCESS(qm_value_t *, (qm), qm_field_map_offsets[(field_ctr)])[0])
#define SPARP_FIELD_CONST_OF_QM(qm,field_ctr) (JSO_FIELD_ACCESS(caddr_t, (qm), qm_field_constants_offsets[(field_ctr)])[0])

/* PART 1. EXPRESSION TERM REWRITING */

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

/*! Equivalence class of variables. All instances of sparp_equiv_s are enumerated in spare_equivs.
When adding new fields, check the code of sparp_equiv_clone() ! */
typedef struct sparp_equiv_s
  {
    ptrlong e_own_idx;		/*!< Index of this instance (in spare_equivs) */
    SPART *e_gp;		/*!< Graph pattern where these variable resides */
    caddr_t *e_varnames;	/*!< Array of distinct names of equivalent variables. Usually one element, if there's no ?x=?y in FILTER */
    SPART **e_vars;		/*!< Array of all equivalent variables, including different occurences of same name in different triples */
    ptrlong e_var_count;	/*!< Number of used items in e_vars. This can be zero if equiv passes top-level var from alias to alias without local uses */
    ptrlong e_gspo_uses;	/*!< Number of all local uses in members (+1 for each in G, P, S or O in triples */
    ptrlong e_const_reads;	/*!< Number of constant-read uses in filters and in 'graph' of members */
    rdf_val_range_t e_rvr;	/*!< Restrictions that are common for all variables */
    ptrlong *e_subvalue_idxs;	/*!< Subselects where values of these variables come from */
    ptrlong *e_receiver_idxs;	/*!< Aliases of surrounding query where values of variables from this equiv are used */
    ptrlong e_clone_idx;	/*!< Index of the current clone of the equiv */
    ptrlong e_cloning_serial;	/*!< The serial used when e_clone_idx is set, should be equal to sparp_cloning_serial */
    ptrlong e_deprecated;	/*!< The equivalence class belongs to a gp that is no longer usable */
#ifdef DEBUG
    SPART **e_dbg_saved_gp;	/*!< e_gp that is boxed as ptrlong, to same the pointer after e_gp is set to NULL */
#endif
  } sparp_equiv_t;

#define SPARP_EQUIV_GET_NAMESAKES	0x01	/*!< sparp_equiv_get returns equiv of namesakes, no need to search for exact var. */
#define SPARP_EQUIV_INS_CLASS		0x02	/*!< sparp_equiv_get has a right to add a new equiv to the haystack_gp */
#define SPARP_EQUIV_INS_VARIABLE	0x04	/*!< sparp_equiv_get has a right to insert needle_var into an equiv */
#define SPARP_EQUIV_GET_ASSERT		0x08	/*!< sparp_equiv_get will signal internal error instead of returning NULL */
#define SPARP_EQUIV_ADD_GPSO_USE	0x10	/*!< sparp_equiv_get will increment e_gspo_uses if variable is added */
#define SPARP_EQUIV_ADD_CONST_READ	0x20	/*!< sparp_equiv_get will increment e_const_reads if variable is added */
/*! Finds or create an equiv class for a needle_var in haystack_gp.
The core behaviour is specified by (flags & (SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE)):
   when 0 then only existing equiv with existing occurrence is returned;
   when SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE then new equiv with 1 new variable can be added;
   when SPARP_EQUIV_INS_CLASS then new equiv with no variables can be added, for passing from alias to alias.
If (flags & SPARP_EQUIV_GET_NAMESAKES) then \c needle_var can be a boxed string with name of variable.
*/
extern sparp_equiv_t *sparp_equiv_get (sparp_t *sparp, SPART *haystack_gp, SPART *needle_var, int flags);
/*! Similar to sparp_equiv_get(), but gets a vector of pointers to equivs instead of \c sparp */
extern sparp_equiv_t *sparp_equiv_get_ro (sparp_equiv_t **equivs, ptrlong equiv_count, SPART *haystack_gp, SPART *needle_var, int flags);
/*! Finds an equiv class that supplies a subvalue to the \c receiver from the specified \c haystack_gp */
extern sparp_equiv_t *sparp_equiv_get_subvalue_ro (sparp_equiv_t **equivs, ptrlong equiv_count, SPART *haystack_gp, sparp_equiv_t *receiver);

/*! Returns 1 if connection exists (or added), 0 otherwise. GPFs if tries to add the second up */
extern int sparp_equiv_connect (sparp_t *sparp, sparp_equiv_t *outer, sparp_equiv_t *inner, int add_if_missing);

/*! Returns 1 if connection existed and removed. */
extern int sparp_equiv_disconnect (sparp_t *sparp, sparp_equiv_t *outer, sparp_equiv_t *inner);

/*! Removes a variable from equiv class. The \c var must belong to \c eq, internal error signaled otherwise.
The call does not decrement eq_gspo_uses or eq_const_reads, do it by a separate operation. */
extern void sparp_equiv_remove_var (sparp_t *sparp, sparp_equiv_t *eq, SPART *var);

/*! Creates a clone of \c orig equiv. Variable names are copied, variables, receivers and senders are not.
An error is signaled if the \c orig has been cloned during current cloning on gp.
Using the function outside gp cloning may need fake increment of sparp_gp_cloning_serial to avoid the signal. */
extern sparp_equiv_t *sparp_equiv_clone (sparp_t *sparp, sparp_equiv_t *orig, SPART *cloned_gp);

#define SPARP_EQUIV_MERGE_ROLLBACK	1001 /*!< Restrict or merge is impossible (in principle or just not implemented) */
#define SPARP_EQUIV_MERGE_OK		1002 /*!< Restrict or merge is done successfully */
#define SPARP_EQUIV_MERGE_CONFLICT	1003 /*!< Restrict or merge is done but it is proven that restrictions contradict */
#define SPARP_EQUIV_MERGE_DUPE		1004 /*!< Merge gets \c primary equal to \c secondary */

/*! Returns 1 if tree always returns a reference or NULL but never returns literal */
extern int sparp_tree_returns_ref (sparp_t *sparp, SPART *tree);

/*! Tries to restrict \c primary by \c datatype and/or value.
If neither datatype nor value is provided, SPARP_EQUIV_MERGE_OK is returned. */
extern int sparp_equiv_restrict_by_constant (sparp_t *sparp, sparp_equiv_t *primary, ccaddr_t datatype, SPART *value);

/*! Removes unused \c garbage from the list of equivs of its gp.
The debug version GPFs if the \c garbage is somehow used. */
extern void sparp_equiv_remove (sparp_t *sparp, sparp_equiv_t *garbage);

/*! Merges the content of \c secondary into \c primary (when a variable from \c secondary is proven to be equal to one from \c primary.
At the end of operation, varnames, vars, restrictions, counters subvalues and receivers from \c secondary are added to \c primary
and \c secondary is replaced with \c primary (or removed as dupe) from lists of uses in gp, receivers of senders and senders of receivers.
Conflict in datatypes or fixed values results in SPART_VARR_CONFLICT to eliminate never-happen graph pattern later.
Returns appropriate SPARP_EQUIV_MERGE_xxx */
extern int sparp_equiv_merge (sparp_t *sparp, sparp_equiv_t *primary, sparp_equiv_t *secondary);

/* Returns whether two given fixedvalue trees are equal (same language and SQL value, no comparison for datatypes) */
extern int sparp_fixedvalues_equal (sparp_t *sparp, SPART *first, SPART *second);

/*! Returns whether two given equivs have equal restriction by fixedvalue (and fixedtype).
If any of two are not restricted or they are restricted by two different values then the function returns zero */
extern int sparp_equivs_have_same_fixedvalue (sparp_t *sparp, sparp_equiv_t *first_eq, sparp_equiv_t *second_eq);

/*! Returns a datatype that may contain any value from both dt_iri1 and dt_iri2 datatypes, NULL if the result is 'any'.
The function is not 100% accurate so its result may be a supertype of the actual smallest union datatype. */
extern ccaddr_t sparp_smallest_union_superdatatype (sparp_t *sparp, ccaddr_t dt_iri1, ccaddr_t dt_iri2);

/*! Returns a datatype that may contain any value from intersection of dt_iri1 and dt_iri2 datatypes, NULL if the result is 'any'.
The function is not 100% accurate so its result may be a supertype of the actual largest intersect datatype. */
extern ccaddr_t sparp_largest_intersect_superdatatype (sparp_t *sparp, ccaddr_t iri1, ccaddr_t iri2);

/*! Returns an sprintf format string such that any string that can be printed by both \c sprintf_fmt1 and \c sprintf_fmt2 can
also be printed by the returned format.
The returned value can be NULL if it's proven that no one string can be printed by both given formats.
The function returns pointer ot DV_STRING that resides in a global hashtable; it shoud not be changed or deleted.
The exception is that values returned by function when \c ignore_cache is set; these values are temporarily and should be deleted. */
extern ccaddr_t sprintff_intersect (ccaddr_t sprintf_fmt1, ccaddr_t sprintf_fmt2, int ignore_cache);

/*! Returns whether \c strg1 can be printed by \c sprintf_fmt2.
The returned value is 0 if it's proven that \c strg1 can not be printed by \c sprintf_fmt2, nonzero otherwise. */
extern int sprintff_like (ccaddr_t strg1, ccaddr_t sprintf_fmt2);

/* Replaces every "%" in \c strg with "%%", so the result is an sprintf format string (a new DV_STRING plain or mempool box) */
extern caddr_t sprintff_from_strg (ccaddr_t strg, int use_mem_pool);

/*!< Changes fields \c rvrSprintffs and \c rvrSprintffCount of \c rvr by adding (up to) \c add_count elements of \c add_sffs */
extern void sparp_rvr_add_sprintffs (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *add_sffs, ptrlong add_count);
extern void sparp_rvr_intersect_sprintffs (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *isect_sffs, ptrlong isect_count);

/*! Adds IRIs classes from \c add_classes into rvr->rvrIriClasses. \c add_count is the length of \c add_classes.
Duplicates are not added, of course. */
extern void sparp_rvr_add_iri_classes (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *add_classes, ptrlong add_count);

/*! Removes from rvr->rvrIriClasses all IRIs classes that are missing in \c isect_classes. \c isect_count is the length of \c isect_classes.
Duplicates are not added, of course. */
extern void sparp_rvr_intersect_iri_classes (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *isect_classes, ptrlong isect_count);

/*! Adds impossible values from \c add_cuts into rvr->rvrIriRedCuts. \c add_count is the length of \c add_cuts.
Duplicates are not added, of course. */
extern void sparp_rvr_add_red_cuts (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *add_cuts, ptrlong add_count);

/*! Removes from rvr->rvrIriRedCuts all IRIs classes that are missing in \c isect_cuts. \c isect_count is the length of \c isect_cuts.
Duplicates are not added, of course. */
extern void sparp_rvr_intersect_red_cuts (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *isect_cuts, ptrlong isect_count);

#define SPARP_RVR_CREATE ((rdf_val_range_t *)1L)

#ifdef DEBUG
extern void dbg_sparp_rvr_audit (const char *file, int line, sparp_t *sparp, rdf_val_range_t *rvr);
#define sparp_rvr_audit(sparp,rvr) dbg_sparp_rvr_audit (__FILE__, __LINE__, sparp, rvr)
#else
#define sparp_rvr_audit(sparp,rvr) 0
#endif

/*! Creates a copy of given \c src (the structure plus member lists but not literals).
If dest is equal to SPARP_RVR_CREATE then it allocates new rvr otherwise it overwrites \c dest */
extern rdf_val_range_t *sparp_rvr_copy (sparp_t *sparp, rdf_val_range_t *dest, rdf_val_range_t *src);

/*! Tries to zap \dest and then restrict it by \c datatype and/or value. */
extern void sparp_rvr_set_by_constant (sparp_t *sparp, rdf_val_range_t *dest, ccaddr_t datatype, SPART *value);

/*! Restricts \c dest by additional restrictions from \c addon that match the mask of \c changeable_flags */
extern void sparp_rvr_tighten (sparp_t *sparp, rdf_val_range_t *dest, rdf_val_range_t *addon, int changeable_flags);

/*! Disables restrictions of \c eq that are in contradiction with \c addon and match the mask of \c changeable_flags.
The function can not be used if \c addon has SPART_VARR_CONFLICT set */
extern void sparp_rvr_loose (sparp_t *sparp, rdf_val_range_t *dest, rdf_val_range_t *addon, int changeable_flags);

/*! Restricts \c eq by additional restrictions of \c addon that match the mask of \c changeable_flags */
extern void sparp_equiv_tighten (sparp_t *sparp, sparp_equiv_t *eq, rdf_val_range_t *addon, int changeable_flags);

/*! Disables restrictions of \c eq that are in contradiction with \c addon and match the mask of \c changeable_flags.
The function can not be used if \c addon has SPART_VARR_CONFLICT set */
extern void sparp_equiv_loose (sparp_t *sparp, sparp_equiv_t *eq, rdf_val_range_t *addon, int changeable_flags);

/*! Returns 1 if the \c tree is an expression that is free from non-global variables */
extern int sparp_tree_is_global_expn (sparp_t *sparp, SPART *tree);

/*! Performs all basic term rewritings of the query tree. */
extern void sparp_rewrite_basic (sparp_t *sparp);

/* PART 2. GRAPH PATTERN TERM REWRITING */

extern SPART *sparp_find_gp_by_alias (sparp_t *sparp, caddr_t alias);

/*! Returns triple that contains the given variable \c var as a field.
If \c gp is not NULL the search is restricted by triples that
are direct members of \c gp, otherwise the gp to search will be found by selid of the variable. */
extern SPART *sparp_find_triple_of_var (sparp_t *sparp, SPART *gp, SPART *var);

/*! This is like sparp_find_triple_of_var but returns triple that
contains the field whose selid, tabid, name and tr_idx matches \c var. */
extern SPART *sparp_find_triple_of_var_or_retval (sparp_t *sparp, SPART *gp, SPART *var);

/*! This returns a mapping of \c var.
If var_triple is NULL then it tries to find it using sparp_find_triple_of_var for vars and sparp_find_triple_of_var_or_retval for retvals */
extern qm_value_t *sparp_find_qmv_of_var_or_retval (sparp_t *sparp, SPART *var_triple, SPART *gp, SPART *var);

extern SPART *sparp_find_gp_by_eq_idx (sparp_t *sparp, ptrlong eq_idx);

/*! This searches for storage by its name. NULL arg means default (or no storage if there's no default loaded), empty UNAME means no storage */
extern quad_storage_t *sparp_find_storage_by_name (ccaddr_t name);

/*! This searches for quad map by its name. */
extern quad_map_t *sparp_find_quad_map_by_name (ccaddr_t name);

typedef struct tc_context_s {
  SPART *tcc_triple;		/*!< Triple pattern in question */
  SPART **tcc_sources;		/*!< Source graphs that can be used */
  int tcc_required_source_type;	/*!< NAMED_L or FROM_L, to indicate that the search is among named or unnamed sources */
  quad_storage_t *tcc_qs;	/*!< Quad storage in question */
  quad_map_t *tcc_top_allowed_qm;	/*!< Top qm that is allowed, if it is specified in the triple */
  void *tcc_last_qmvs [SPART_TRIPLE_FIELDS_COUNT];	/*!< Pointers to recently checked QMVs or constants. QMVs tend to repeat in sequences. */
  int tcc_last_qmv_results [SPART_TRIPLE_FIELDS_COUNT];	/*!< Results of recent comparisons. */
  dk_set_t tcc_cuts [SPART_TRIPLE_FIELDS_COUNT];	/*!< Accumulated red cuts for possible values of fields */
  dk_set_t tcc_found_cases;		/*!< Accumulated triple cases */
  int tcc_nonfiltered_cases_found;	/*!< Count of triples cases that passed tests, including cases rejected due to QUAD MAP xx { } restriction of triple */
} tc_context_t;

/*! This checks if the given \c qm may contain data that matches \c triple by itself,
without its submaps and without the check of qmEmpty. */
extern int sparp_check_triple_case (sparp_t *sparp, tc_context_t *tcc, quad_map_t *qm);

/*! The function fills in the \c tc_set_ret[0] with triple cases of all matching quad mappings (\c qm, submaps of \c qm and al subsubmaps recursively
that match and not empty and not after the first (empty or nonempty) full match. */
extern int sparp_qm_find_triple_cases (sparp_t *sparp, tc_context_t *tcc, quad_map_t *qm, int inside_allowed_qm);

/*! This returns a mempool-allocated vector of quad maps
that describe an union of all elementary datasources that can store triples that match a pattern.
\c required_source_type should be FROM_L or NAMED_L */
extern triple_case_t **sparp_find_triple_cases (sparp_t *sparp, SPART *triple, SPART **sources, int required_source_type);

/*! This calls sparp_find_triple_cases() and fills in tc_list and native_formats of triple->_.triple */
extern void sparp_refresh_triple_cases (sparp_t *sparp, SPART *triple);

extern int sparp_expns_are_equal (sparp_t *sparp, SPART *one, SPART *two);
extern int sparp_expn_lists_are_equal (sparp_t *sparp, SPART **one, SPART **two);

/*! This replaces selid and tabid in a triple (assuming that ids in field variables match ids of a triple) */
extern void sparp_set_triple_selid_and_tabid (sparp_t *sparp, SPART *triple, caddr_t new_selid, caddr_t new_tabid);

/*! This replaces selids of all variables in retvals and soring expressions with current selid of the topmost gp */
extern void sparp_set_retval_and_order_selid (sparp_t *sparp);

extern void sparp_set_special_order_selid (sparp_t *sparp, SPART *new_gp);

/*! This replaces selids of all variables in a filter */
extern void sparp_set_filter_selid (sparp_t *sparp, SPART *filter, caddr_t new_selid);

/*! This creates a full clone of \c gp subtree with cloned equivs.
The function will substitute all selids and tabids of all graph patterns and triples in the tree and
substitute equiv indexes with indexes of cloned equivs (except SPART_BAD_EQUIV_IDX index that persists). */
extern SPART *sparp_gp_full_clone (sparp_t *sparp, SPART *gp);

/*! This creates a full copy of \c orig subtree without cloning equivs.
Variables inside copy have unidirectional pointers to equivs until attached to other tree or same place in same tree. */
extern SPART *sparp_tree_full_copy (sparp_t *sparp, SPART *orig, SPART *parent_gp);

/*! This creates a copy of \c origs array and fills it with sparp_tree_full_copy of each member of the array. */
extern SPART **sparp_treelist_full_copy (sparp_t *sparp, SPART **origs, SPART *parent_gp);

/*! This removes the member with specified index from \c parent_gp and removes its variables from equivs.
If \c touched_equivs_ptr is not NULL then the list of edited equivs is composed.
Removal of a child does not alter restrictions of equivalence classes, because the operation should be used as
a part of safe rewriting that preserves the logic.
The function returns the detached member. */
extern SPART *sparp_gp_detach_member (sparp_t *sparp, SPART *parent_gp, int member_idx, sparp_equiv_t ***touched_equivs_ptr);

/*! This removes all members from \c parent_gp and removes its variables from equivs.
If \c touched_equivs_ptr is not NULL then the list of edited equivs is composed.
Removal of a child does not alter restrictions of equivalence classes, because the operation should be used as
a part of safe rewriting that preserves the logic.
The function returns the list of detached members. */
extern SPART **sparp_gp_detach_all_members (sparp_t *sparp, SPART *parent_gp, sparp_equiv_t ***touched_equivs_ptr);

/*! This adds \c new_child into list of members of \c parent_gp, the insert position is specified by \c insert_before_idx
Matching variables of \c parent_gp and \c new_child become connected.
If \c touched_equivs_ptr is not NULL then the list of edited equivs is composed.
selid and tabid of the attached member are adjusted automatically.
Restrictions on variables of \c new_child should be propagated across the tree by additional calls of appropriate functions. */
extern void sparp_gp_attach_member (sparp_t *sparp, SPART *parent_gp, SPART *new_child, int insert_before_idx, sparp_equiv_t ***touched_equivs_ptr);

/*! This adds \c new_childs into list of members of \c parent_gp, the insert position is specified by \c insert_before_idx
Matching variables of \c parent_gp and \c new_childs become connected.
If \c touched_equivs_ptr is not NULL then the list of edited equivs is composed.
selid and tabid of attached members are adjusted automatically.
Restrictions on variables of \c new_childs should be propagated across the tree by additional calls of appropriate functions.
This is faster than attach \c new_childs by a sequence of sparp_gp_attach_member() calls. */
extern void sparp_gp_attach_many_members (sparp_t *sparp, SPART *parent_gp, SPART **new_members, int insert_before_idx, sparp_equiv_t ***touched_equivs_ptr);

/*! This removes the filter with specified index from \c parent_gp and removes its variables from equivs.
If \c touched_equivs_ptr is not NULL then the list of edited equivs is composed.
Removal of a filter does not alter restrictions of equivalence classes derived from a filter, because the operation should be used as
a part of safe rewriting that preserves the logic.
The function returns the detached filter. */
extern SPART *sparp_gp_detach_filter (sparp_t *sparp, SPART *parent_gp, int filter_idx, sparp_equiv_t ***touched_equivs_ptr);

/*! This removes all filters from \c parent_gp and removes its variables from equivs.
If \c touched_equivs_ptr is not NULL then the list of edited equivs is composed.
Removal of filters does not alter restrictions of equivalence classes derived from filters, because the operation should be used as
a part of safe rewriting that preserves the logic.
The function returns the list of detached filters. */
extern SPART **sparp_gp_detach_all_filters (sparp_t *sparp, SPART *parent_gp, sparp_equiv_t ***touched_equivs_ptr);

/*! This adds \c new_filter into list of filters of \c parent_gp, the insert position is specified by \c insert_before_idx
If \c touched_equivs_ptr is not NULL then the list of edited equivs is composed.
All selids of variables of the attached filter are adjusted automatically and these variables are added to equiv classes of \c parent_gp.
Restrictions on variables of \c new_filter should be propagated across the tree by additional calls of appropriate functions. */
extern void sparp_gp_attach_filter (sparp_t *sparp, SPART *parent_gp, SPART *new_filter, int insert_before_idx, sparp_equiv_t ***touched_equivs_ptr);

/*! This adds \c new_filters into list of filters of \c parent_gp, the insert position is specified by \c insert_before_idx
If \c touched_equivs_ptr is not NULL then the list of edited equivs is composed.
All selids of variables of the attached filters are adjusted automatically and these variables are added to equiv classes of \c parent_gp.
Restrictions on variables of \c new_filters should be propagated across the tree by additional calls of appropriate functions.
This is faster than attach \c new_filters by a sequence of sparp_gp_attach_member() calls. */
extern void sparp_gp_attach_many_filters (sparp_t *sparp, SPART *parent_gp, SPART **new_filters, int insert_before_idx, sparp_equiv_t ***touched_equivs_ptr);

/*! This makes the gp and all its sub-gps unusable and marks 'deprecated' all equivs that belong to these gps. */
extern void sparp_gp_deprecate (sparp_t *sparp, SPART *parent_gp);

/*! This converts union of something and unions into flat union. The operation is recursive while there's some subunions.
Equivalences are touched, of course, but who cares?
!!!TBD: support of filters in the union GP, this is GPF now. */
extern void sparp_flatten_union (sparp_t *sparp, SPART *parent_gp);

/*! If a gp is group of non-optional triples and each triple has exactly one possible quad map then the function returns vector of tabids of triples.
In addition, if the \c expected_triples_count argument is nonnegative then number of triples in group should be equal to that argument.
If any condition fails, the function returns NULL.
This function is used in breakup code generation. */
extern caddr_t *sparp_gp_may_reuse_tabids_in_union (sparp_t *sparp, SPART *gp, int expected_triples_count);

/*! This produces a list of single-triple GPs such that every GP implements only one quad mapping from
qm_list of the original \c triple.
Every generated contains a triple that has qm_list of length 1; guess what's the member of the list :)
*/
extern SPART **sparp_make_qm_cases (sparp_t *sparp, SPART *triple);

/*! Creates a new graph pattern of specified \c subtype as if it is parsed ar \c srcline of source text. */
extern SPART *sparp_new_empty_gp (sparp_t *sparp, ptrlong subtype, ptrlong srcline);


/*! This turns \c gp into a union of zero cases and adjust VARR flags of variables to make them always-NULL */
extern void sparp_gp_produce_nothing (sparp_t *sparp, SPART *gp);


/*! Perform all rewritings according to the type of the tree, grab logc etc. */
extern void sparp_rewrite_all (sparp_t *sparp);

/*! Convert a query with grab vars into a select with procedure view with seed/iter/final sub-SQLs as arguments. */
extern void sparp_rewrite_grab (sparp_t *sparp);

/*! Finds all mappings of all triples, then performs all graph pattern term rewritings of the query tree */
extern void sparp_rewrite_qm (sparp_t *sparp);

/* PART 3. OUTPUT GENERATOR */

struct spar_sqlgen_s;
#if 0
struct rdf_ds_field_s;
#endif
struct rdf_ds_s;

/* Special 'macro' names of ssg_valmode_t modes. The order of numeric values is important ssg_shortest_valmode() */
#if 0
#define SSG_VALMODE_SHORT		((ssg_valmode_t)((ptrlong)(0x300)))
#endif
#define SSG_VALMODE_LONG		((ssg_valmode_t)((ptrlong)(0x310)))
#define SSG_VALMODE_SQLVAL		((ssg_valmode_t)((ptrlong)(0x320)))
#define SSG_VALMODE_DATATYPE		((ssg_valmode_t)((ptrlong)(0x330)))
#define SSG_VALMODE_LANGUAGE		((ssg_valmode_t)((ptrlong)(0x340)))
#define SSG_VALMODE_AUTO		((ssg_valmode_t)((ptrlong)(0x350)))
#define SSG_VALMODE_BOOL		((ssg_valmode_t)((ptrlong)(0x360)))
#define SSG_VALMODE_SPECIAL		((ssg_valmode_t)((ptrlong)(0x370)))
/* typedef struct rdf_ds_field_s *ssg_valmode_t; -- moved to sparql.h */

extern ssg_valmode_t ssg_smallest_union_valmode (ssg_valmode_t m1, ssg_valmode_t m2);
extern ssg_valmode_t ssg_largest_intersect_valmode (ssg_valmode_t m1, ssg_valmode_t m2);
extern ssg_valmode_t ssg_largest_eq_valmode (ssg_valmode_t m1, ssg_valmode_t m2);
extern int ssg_valmode_is_subformat_of (ssg_valmode_t m1, ssg_valmode_t m2);

extern qm_format_t *qm_format_default_iri_ref;
extern qm_format_t *qm_format_default_ref;
extern qm_format_t *qm_format_default;
extern qm_value_t *qm_default_values[SPART_TRIPLE_FIELDS_COUNT];
extern quad_map_t *qm_default;
extern triple_case_t *tc_default;
extern quad_storage_t *rdf_sys_storage;

/*! Loads all known definitions of datasources */
extern void rdf_ds_load_all (void);

typedef struct rdf_ds_usage_s
{
  quad_map_t *rdfdu_ds;	/*!< Datasource */
  qm_value_t *tr_fields[SPART_TRIPLE_FIELDS_COUNT];	/*!< Description of fields to be used */
  caddr_t rdfdu_alias;	/*!< Table alias used for the occurrence */
} rdf_ds_usage_t;

#define NULL_ASNAME ((const char *)NULL)
#define COL_IDX_ASNAME (((const char *)NULL) + 0x100)

/*! Prints the SQL expression based on \c tmpl template of \c qm_fmt valmode. \c asname is name used for AS xxx clauses, other arguments form context */
extern void ssg_print_tmpl (struct spar_sqlgen_s *ssg, qm_format_t *qm_fmt, ccaddr_t tmpl, caddr_t alias, qm_value_t *qm_val, SPART *tree, const char *asname);
extern void sparp_check_tmpl (sparp_t *sparp, ccaddr_t tmpl, int qmv_known, dk_set_t *used_aliases);
extern caddr_t sparp_patch_tmpl (sparp_t *sparp, ccaddr_t tmpl, dk_set_t alias_replacements);

/*! This searches for declaration of type by its name. NULL name result in NULL output, unknown name is an error */
extern ssg_valmode_t ssg_find_valmode_by_name (ccaddr_t name);

extern caddr_t ssg_find_formatter_by_name (ccaddr_t name);

/*! Field is the expression that represents the value of a SPARQL variable. */
typedef struct spar_sqlgen_var_s
{
  quad_map_t	*ssgv_source_qm;	/*!< The source where the value comes from, to access table names and vtable with template printer. */
  qm_value_t	*ssgv_field_qmv;	/*!< The field, with data for template printer */
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

#ifdef DEBUG
#define spar_sqlprint_error(x) do { ssg_putchar ('!'); ssg_puts ((x)); ssg_putchar ('!'); return; } while (0)
#define spar_sqlprint_error2(x,v) do { ssg_putchar ('!'); ssg_puts ((x)); ssg_putchar ('!'); return (v); } while (0)
#else
#define spar_sqlprint_error(x) spar_internal_error (NULL, (x))
#define spar_sqlprint_error2(x,v) spar_internal_error (NULL, (x))
#endif

/*! Adds either iri of \c jso_inst or \c jso_name into dependencies of the generated query. \c jso_inst is used only if \c jso_name is NULL */
extern void ssg_qr_uses_jso (spar_sqlgen_t *ssg, ccaddr_t jso_inst, ccaddr_t jso_name);
extern void ssg_qr_uses_table (spar_sqlgen_t *ssg, const char *tbl);

extern qm_value_t * ssg_equiv_native_qmv (spar_sqlgen_t *ssg, SPART *gp, sparp_equiv_t *eq);
extern ssg_valmode_t ssg_equiv_native_valmode (spar_sqlgen_t *ssg, SPART *gp, sparp_equiv_t *eq);
extern qm_value_t *ssg_expn_native_qmv (spar_sqlgen_t *ssg, SPART *tree);
extern ssg_valmode_t ssg_expn_native_valmode (spar_sqlgen_t *ssg, SPART *tree);

extern void sparp_jso_validate_format (sparp_t *sparp, ssg_valmode_t fmt);
extern void ssg_jso_validate_format (spar_sqlgen_t *ssg, ssg_valmode_t fmt);

/*! Prints an SQL identifier. 'prin' instead of 'print' because it does not print whitespace or delim before the text */
extern void ssg_prin_id (spar_sqlgen_t *ssg, const char *name);
extern void ssg_print_literal (spar_sqlgen_t *ssg, ccaddr_t type, SPART *lit);
extern void ssg_print_equiv (spar_sqlgen_t *ssg, caddr_t selectid, sparp_equiv_t *eq, ccaddr_t asname);

extern ssg_valmode_t ssg_rettype_of_global_param (spar_sqlgen_t *ssg, caddr_t name);
extern ssg_valmode_t ssg_rettype_of_function (spar_sqlgen_t *ssg, caddr_t name);
extern ssg_valmode_t ssg_argtype_of_function (spar_sqlgen_t *ssg, caddr_t name, int arg_idx);
extern void ssg_prin_function_name (spar_sqlgen_t *ssg, ccaddr_t name);

extern void ssg_print_global_param (spar_sqlgen_t *ssg, caddr_t vname, ssg_valmode_t needed);
extern void ssg_print_valmoded_scalar_expn (spar_sqlgen_t *ssg, SPART *tree, ssg_valmode_t needed, ssg_valmode_t native, const char *asname);
extern void ssg_print_scalar_expn (spar_sqlgen_t *ssg, SPART *tree, ssg_valmode_t needed, const char *asname);
extern void ssg_print_filter_expn (spar_sqlgen_t *ssg, SPART *tree);
extern void ssg_print_qm_sql (spar_sqlgen_t *ssg, SPART *tree);

#define SSG_RETVAL_USES_ALIAS			0x01	/*!< Return value can be printed in form 'expn AS alias' if alias name is not NULL */
#define SSG_RETVAL_SUPPRESSED_ALIAS		0x02	/*!< Return value is not printed in form 'expn AS alias', only 'expn' but alias is known to subtree and let generate names like 'alias~0' */
#define SSG_RETVAL_MUST_PRINT_SOMETHING		0x04	/*!< The function signals an error instead of returning failure */
#define SSG_RETVAL_CAN_PRINT_NULL		0x08	/*!< The function should print at least NULL but it can not return failure */
#define SSG_RETVAL_FROM_GOOD_SELECTED		0x10	/*!< Use result-set columns from 'good' (non-optional) subqueries */
#define SSG_RETVAL_FROM_ANY_SELECTED		0x20	/*!< Use result-set columns from any subqueries, including 'optional' that can make NULL */
#define SSG_RETVAL_FROM_JOIN_MEMBER		0x40	/*!< The function can print expression like 'tablealias.colname' */
#define SSG_RETVAL_FROM_FIRST_UNION_MEMBER	0x80
#define SSG_RETVAL_TOPMOST			0x100
#define SSG_RETVAL_NAME_INSTEAD_OF_TREE		0x200
#define SSG_RETVAL_DIST_SER_LONG		0x400	/*!< Use DB.DBA.RDF_DIST_SER_LONG wrapper to let DISTINCT work with formatters. */
/* descend = 0 -- at level, can descend. 1 -- at sublevel, can't descend, -1 -- at level, can't descend */
extern int ssg_print_equiv_retval_expn (spar_sqlgen_t *ssg, SPART *gp,
  sparp_equiv_t *eq, int flags, ssg_valmode_t needed, const char *asname );

extern void ssg_print_retval_simple_expn (spar_sqlgen_t *ssg, SPART *gp, SPART *tree, ssg_valmode_t needed, const char *asname);

extern void ssg_print_fld_restrictions (spar_sqlgen_t *ssg, quad_map_t *qmap, qm_value_t *field, caddr_t tabid, SPART *triple, int fld_idx, int print_outer_filter);
extern void ssg_print_all_table_fld_restrictions (spar_sqlgen_t *ssg, quad_map_t *qm, caddr_t alias, SPART *triple, int enabled_field_bitmask, int print_outer_filter);
extern void ssg_print_table_exp (spar_sqlgen_t *ssg, SPART *gp, SPART **trees, int tree_count, int pass);

#define SSG_PRINT_UNION_NOFIRSTHEAD	0x01	/*!< Flag to suppress printing of 'SELECT retvallist' of the first member of the union */
#define SSG_PRINT_UNION_NONEMPTY_STUB	0x02	/*!< Flag to print a stub that returns a 1-row result of single column, instead of a stub with empty resultset */
extern void ssg_print_union (spar_sqlgen_t *ssg, SPART *gp, SPART **retlist, int head_flags, int retval_flags, ssg_valmode_t needed);

extern void ssg_print_orderby_item (spar_sqlgen_t *ssg, SPART *gp, SPART *oby_itm);

/*! Fills in ssg->ssg_out with an SQL text of a query */
extern void ssg_make_sql_query_text (spar_sqlgen_t *ssg);
/*! Fills in ssg->ssg_out with an SQL text of quad map manipulation statement */
extern void ssg_make_qm_sql_text (spar_sqlgen_t *ssg);
/*! Fills in ssg->ssg_out with an SQL text of arbitrary statement, by calling ssg_make_sql_query_text(), ssg_make_qm_sql_text(), or some special codegen callback */
extern void ssg_make_whole_sql_text (spar_sqlgen_t *ssg);

#endif
