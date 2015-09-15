/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
#include "rdf_core.h"

extern ptrdiff_t qm_field_map_offsets[SPART_TRIPLE_FIELDS_COUNT];
extern ptrdiff_t qm_field_const_rvrs_offsets[SPART_TRIPLE_FIELDS_COUNT];

#define SPARP_FIELD_QMV_OF_QM(qm,field_ctr) (JSO_FIELD_ACCESS(qm_value_t *, (qm), qm_field_map_offsets[(field_ctr)])[0])
#define SPARP_FIELD_CONST_RVR_OF_QM(qm,field_ctr) (JSO_FIELD_ACCESS(rdf_val_range_t, (qm), qm_field_const_rvrs_offsets[(field_ctr)]))

/* PART 1. EXPRESSION TERM REWRITING */

#define SPAR_GPT_NODOWN		0x10	/*!< Don't trav children, i.e. do not call any callbacks for children of the current subtree */
#define SPAR_GPT_NOOUT		0x20	/*!< Don't call 'out' callback for the current subtree */
#define SPAR_GPT_COMPLETED	0x40	/*!< Don't trav anything at all: the processing is complete */
#define SPAR_GPT_RESCAN		0x80	/*!< Lists of children should be found again because they may become obsolete during 'in' callback */
#define SPAR_GPT_ENV_PUSH	0x01	/*!< Environment should be pushed. */

/*! Single item of state stack of sparp_gp_trav() */
typedef struct sparp_trav_state_s {
    SPART *sts_ancestor_gp;		/*!< Group pattern that contains the current subtree, say, gp of filter, parent of gp or triple. */
    SPART *sts_parent;			/*!< Parent of the current state, NULL for WHERE tree */
    SPART **sts_curr_array;		/*!< Array that contains current subtree */
    int sts_ofs_of_curr_in_array;	/*!< Offset of the current subtree from sts_curr_array */
    void *sts_env;			/*!< Task-specific traverse environment data; */
  } sparp_trav_state_t;

/*! Returns combination of SPAR_GPT_... bits */
typedef int sparp_gp_trav_cbk_t (sparp_t *sparp, SPART *curr, sparp_trav_state_t *sts_this, void *common_env);

/*! Parameters of the call of sparp_gp_trav() */
typedef struct sparp_trav_params_s {
  sparp_gp_trav_cbk_t *stp_gp_in_cbk;		/*!< Preorder callback to traverse group patterns */
  sparp_gp_trav_cbk_t *stp_gp_out_cbk;		/*!< Postorder callback to traverse group patterns */
  sparp_gp_trav_cbk_t *stp_expn_in_cbk;		/*!< Preorder callback to traverse expressions (filters, retvals etc.) */
  sparp_gp_trav_cbk_t *stp_expn_out_cbk;	/*!< Postordercallback to traverse expressions (filters, retvals etc.) */
  sparp_gp_trav_cbk_t *stp_expn_subq_cbk;	/*!< Inorder callback to traverse scalar subqueries inside expressions */
  sparp_gp_trav_cbk_t *stp_literal_cbk;		/*!< Inorder callback to traverse literals (scalars) inside expressions */
  SPART *stp_trav_req_top;				/*!< The req_top of a tree in question */
  SPART *stp_trav_root;				/*!< The expression where the traversal has started from, i.e., \c tree argument of sparp_gp_trav() or a whole clause of sparp_trav_out_clauses() */
  sparp_trav_state_t *stp_stack_in_use;		/*!< Pointer to a stack in use */
  struct sparp_trav_params_s *stp_prev_suspended;	/*!< Pointer to the previous suspended traversal, NULL if the current one is top-level */
} sparp_trav_params_t;

extern int sparp_gp_trav (sparp_t *sparp, SPART *req_top, SPART *tree, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 );

extern int sparp_gp_trav_top_pattern (sparp_t *sparp, SPART *req_top, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 );

extern int sparp_trav_out_clauses (sparp_t *sparp, SPART *root, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 );

typedef int sparp_gp_trav_int_t (sparp_t *sparp, SPART *tree,
  sparp_trav_state_t *sts_this, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 );

extern int sparp_gp_trav_1 (sparp_t *sparp, sparp_gp_trav_int_t *intcall, SPART *req_top, SPART *root, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 );

extern void
sparp_gp_localtrav_treelist (sparp_t *sparp, SPART **treelist,
  void *init_stack_env, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 );

extern int sparp_gp_trav_int (sparp_t *sparp, SPART *tree,
  sparp_trav_state_t *sts_this, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 );

extern int sparp_trav_out_clauses_int (sparp_t *sparp, SPART *root,
  sparp_trav_state_t *sts_this, void *common_env,
  sparp_gp_trav_cbk_t *gp_in_cbk, sparp_gp_trav_cbk_t *gp_out_cbk,
  sparp_gp_trav_cbk_t *expn_in_cbk, sparp_gp_trav_cbk_t *expn_out_cbk, sparp_gp_trav_cbk_t *expn_subq_cbk,
  sparp_gp_trav_cbk_t *literal_cbk
 );


#define SPARP_GP_TRAV_CALLBACK_ARGS(stp) \
  (stp).stp_gp_in_cbk, (stp).stp_gp_out_cbk, \
  (stp).stp_expn_in_cbk, (stp).stp_expn_out_cbk, (stp).stp_expn_subq_cbk, \
  (stp).stp_literal_cbk

/*!< Suspends the traversal in order to start other traversal, params and state are saved in \c saved_stp_ptr[0] and \c saved_stss_ptr[0], the values under taht pointers should be NULLs initially */
extern void sparp_gp_trav_suspend (sparp_t *sparp);
/*!< Resumes the suspended traversal */
extern void sparp_gp_trav_resume (sparp_t *sparp);
/*!< Continues the current traversal in the given gp with subquery */
extern void sparp_continue_gp_trav_in_sub (sparp_t *sparp, SPART *subq_gp_wrapper, void *common_env, int trav_in_out_clauses);

extern SPART **spar_macroexpand_treelist (sparp_t *sparp, SPART **trees, int begin_with);
/*!< Do nothing or macroexpand a single tree, returns the result, destroying and/or reusing the original */
extern SPART *spar_macroexpand_tree (sparp_t *sparp, SPART *tree);

struct sparp_equiv_s;

/*! Equivalence class of variables. All instances of \c sparp_equiv_s are enumerated in \c sparp_sg->sg_equivs .
When adding new fields, check the code of \c sparp_equiv_clone() and \c sparp_equiv_exact_copy() ! */
typedef struct sparp_equiv_s
  {
    ptrlong e_own_idx;		/*!< Index of this instance (in \c req_top.equivs) */
    SPART *e_gp;		/*!< Graph pattern where these variable resides */
    caddr_t *e_varnames;	/*!< Array of distinct names of equivalent variables. Usually one element, if there's no ?x=?y in FILTER */
    caddr_t e_front_varname;	/*!< it may be ambiguous how to name a result column of an equiv if the equiv is printed as SELECT, this name is treated as preferable */
    SPART **e_vars;		/*!< Array of all equivalent variables, including different occurrences of same name in different triples */
    ptrlong e_var_count;	/*!< Number of used items in e_vars. This can be zero if equiv passes top-level var from alias to alias without local uses */
    ptrlong e_gspo_uses;	/*!< Number of all local uses in members (+1 for each in G, P, S or O in triples). Note that nonzero e_gspo_uses does not imply SPART_VARR_NOT_NULL if some members has triple.subtype == OPTIONAL_L */
    ptrlong e_nested_bindings;	/*!< Number of all nested uses in members (+1 for each in G, P, S or O in triples, +1 for each sub-gp use, +1 if \c e_gp is of subtype VALUES_L) */
    ptrlong e_nested_optionals;	/*!< Number of all nested uses in OPTIONAL_L members, VALUES_L memebers with UNDEF for the variable in question and"pure chains" to such OPTIONALs and VALUEs (+1 for each such sub-gp use) */
    ptrlong e_const_reads;	/*!< Number of constant-read uses in filters and in 'graph' of members */
    ptrlong e_optional_reads;	/*!< Number of uses in scalar subqueries of filters; both local and member filter are counted */
    ptrlong e_subquery_uses;	/*!< Number of all local uses in subquery (0 for plain queries, 1 in groups of subtype SELECT_L) */
    ptrlong e_replaces_filter;	/*!< Bitmask of SPART_RVR_XXX bits, nonzero if a filter has been replaced (and removed) by tightening of this equiv or by merging this and some other equiv, so the equiv is the only bearer of knowledge about the restriction. */
    rdf_val_range_t e_rvr;	/*!< Restrictions that are common for all variables. They are combined from rvrs of variables and subvalues, however rvrs of variables can be tightened by ancestor equivs, making the dependencies circular. */
    ptrlong *e_subvalue_idxs;	/*!< Subselects where values of these variables come from, as array of indexes of equivs. The order is not defined, but subvalues from OPTIONALs are after all other. */
    ptrlong *e_receiver_idxs;	/*!< Aliases of surrounding query where values of variables from this equiv are used, as array of indexes of equivs */
    ptrlong e_clone_idx;	/*!< Index of the current clone of the equiv */
    ptrlong e_cloning_serial;	/*!< The serial used when \c e_clone_idx is set, should be equal to \c sparp->sparp_sg->sg_cloning_serial */
    ptrlong e_external_src_idx;	/*!< Index in \c req_top.equivs of the binding of external variable at ancestor of scalar subquery */
    ptrlong *e_uses_as_params;	/*!< Equivs where the given equiv is used as an external source, as array of indexes of equivs */
    ptrlong e_deprecated;	/*!< The equivalence class belongs to a gp that is no longer usable */
    ptrlong e_pos1_t_in;	/*!< 1-based position of variable in T_IN list */
    ptrlong e_pos1_t_out;	/*!< 1-based position of variable in T_OUT list */
#ifdef DEBUG
    ptrlong e_dbg_merge_dest;	/*!< After the merge of equiv into some destination equiv, \c e_dbg_merge_dest keeps destination */
    SPART **e_dbg_saved_gp;	/*!< \c e_gp that is boxed as ptrlong, to save the pointer after \c e_gp is set to NULL */
#endif
  } sparp_equiv_t;

#define SPARP_FIXED_AND_NOT_NULL(v) ((SPART_VARR_FIXED | SPART_VARR_NOT_NULL) == ((SPART_VARR_FIXED | SPART_VARR_NOT_NULL) & (v)))

#define SPARP_ASSIGNED_BY_CONTEXT(v) \
  ((v) & (SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL))

#define SPARP_ASSIGNED_EXTERNALLY(v) \
  (SPARP_FIXED_AND_NOT_NULL (v) || ((v) & (SPART_VARR_GLOBAL | SPART_VARR_EXTERNAL)))

#define SPARP_EQ_IS_FIXED_AND_NOT_NULL(eq) SPARP_FIXED_AND_NOT_NULL ((eq)->e_rvr.rvrRestrictions)

#define SPARP_EQ_IS_ASSIGNED_BY_CONTEXT(eq) \
  (SPARP_ASSIGNED_BY_CONTEXT ((eq)->e_rvr.rvrRestrictions))

#define SPARP_EQ_IS_ASSIGNED_EXTERNALLY(eq) \
  (SPARP_ASSIGNED_EXTERNALLY ((eq)->e_rvr.rvrRestrictions))

#define SPARP_EQ_IS_ASSIGNED_LOCALLY(eq) \
  ((0 != (eq)->e_gspo_uses) || (0 != (eq)->e_subquery_uses) || (0 != (eq)->e_nested_bindings))

#define SPARP_EQ_IS_USED(eq) \
  ((0 != eq->e_const_reads) || (0 != BOX_ELEMENTS_0 (eq->e_receiver_idxs)))

#define SPAR_VALUES_GP_HAS_UNBOUND(sparp,wrapping_gp,vname) \
      ((wrapping_gp)->_.gp.subquery->_.binv.counters_of_unbound [ \
                  sparp_find_binv_rset_pos_of_varname ((sparp), (wrapping_gp), (wrapping_gp)->_.gp.subquery, (vname)) ] )

#define SPARP_EQ_RETURNS_LIKE_OPTIONAL(sparp,eq) \
  ( (OPTIONAL_L == (eq)->e_gp->_.gp.subtype) \
    || \
    ((VALUES_L == (eq)->e_gp->_.gp.subtype) && \
      SPAR_VALUES_GP_HAS_UNBOUND((sparp), (eq)->e_gp, (eq)->e_varnames[0]) ) \
    || \
    (((eq)->e_nested_bindings == (eq)->e_nested_optionals) && (0 == (eq)->e_gspo_uses) && (0 == (eq)->e_subquery_uses) ) )

#define SPARP_EQUIV_GET_NAMESAKES	0x01	/*!< \c sparp_equiv_get() returns equiv of namesakes, no need to search for exact var. */
#define SPARP_EQUIV_INS_CLASS		0x02	/*!< \c sparp_equiv_get() has a right to add a new equiv to the \c haystack_gp */
#define SPARP_EQUIV_INS_VARIABLE	0x04	/*!< \c sparp_equiv_get() has a right to insert \c needle_var into an equiv */
#define SPARP_EQUIV_GET_ASSERT		0x08	/*!< \c sparp_equiv_get() will signal internal error instead of returning NULL */
#define SPARP_EQUIV_ADD_GSPO_USE	0x10	/*!< \c sparp_equiv_get() will increment \c e_gspo_uses if variable is added */
#define SPARP_EQUIV_ADD_CONST_READ	0x20	/*!< \c sparp_equiv_get() will increment \c e_const_reads if variable is added */
#define SPARP_EQUIV_ADD_SUBQUERY_USE	0x40	/*!< \c sparp_equiv_get() will increment \c e_subquery_uses if variable is added */
#define SPARP_EQUIV_ADD_OPTIONAL_READ	0x80	/*!< \c sparp_equiv_get() will increment \c e_optional_reads if variable is added */
/* There's no SPARP_EQUIV_ADD_OPTIONAL_READ because subquery vars are not added to the equiv */

/*! This allocates a new quivalence class. Don't use it in vain, use sparp_equiv_get with SPARP_EQUIV_INS_CLASS instead. */
extern sparp_equiv_t *sparp_equiv_alloc (sparp_t *sparp);

/*! Finds or create an equiv class for a \c needle_var in \c haystack_gp.
The core behaviour is specified by (flags & (SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE)):
   when 0 then only existing equiv with existing occurrence is returned;
   when SPARP_EQUIV_INS_CLASS | SPARP_EQUIV_INS_VARIABLE then new equiv with 1 new variable can be added;
   when SPARP_EQUIV_INS_CLASS then new equiv with no variables can be added, for passing from alias to alias.
If (flags & SPARP_EQUIV_GET_NAMESAKES) then \c needle_var can be a boxed string with name of variable. */
extern sparp_equiv_t *sparp_equiv_get (sparp_t *sparp, SPART *haystack_gp, SPART *needle_var, int flags);
/*! Similar to sparp_equiv_get(), but gets a vector of pointers to equivs instead of \c sparp */
extern sparp_equiv_t *sparp_equiv_get_ro (sparp_equiv_t **equivs, ptrlong equiv_count, SPART *haystack_gp, SPART *needle_var, int flags);
/*! Finds an equiv class that supplies a subvalue to the \c receiver from the specified \c haystack_gp */
extern sparp_equiv_t *sparp_equiv_get_subvalue_ro (sparp_equiv_t **equivs, ptrlong equiv_count, SPART *haystack_gp, sparp_equiv_t *receiver);
/*! Returns if variables from \c equiv are used in \c tree (or the tree is a gp of some subvalue of \c equiv.
The returned value is actually boolean but the real value of "true" can be used for debugging purposes. */
extern void *sparp_tree_uses_var_of_eq (sparp_t *sparp, SPART *tree, sparp_equiv_t *equiv);

/*! Returns 2 if connection exists, 1 if did not exist but added, 0 if not exists and not added. GPFs if tries to add the second up */
extern int sparp_equiv_connect_outer_to_inner (sparp_t *sparp, sparp_equiv_t *outer, sparp_equiv_t *inner, int add_if_missing);

/*! Returns 1 if connection existed and removed. */
extern int sparp_equiv_disconnect_outer_from_inner (sparp_t *sparp, sparp_equiv_t *outer, sparp_equiv_t *inner);

/*! Returns 2 if connection exists, 1 if did not exist but added, 0 if not exists and not added. Old ext src is silently replaced with new one */
extern int sparp_equiv_connect_param_to_external (sparp_t *sparp, sparp_equiv_t *param, sparp_equiv_t *ext_src);

/*! Returns 1 if connection existed and removed. */
extern int sparp_equiv_disconnect_param_from_external (sparp_t *sparp, sparp_equiv_t *param);

/*! Removes a variable from equiv class. The \c var must belong to \c eq, internal error signaled otherwise.
The call does not decrement \c eq_gspo_uses or \c eq_const_reads, do it by a separate operation. */
extern void sparp_equiv_remove_var (sparp_t *sparp, sparp_equiv_t *eq, SPART *var);

/*! Creates a clone of \c orig equiv. Variable names are copied, variables, receivers and senders are not.
An error is signaled if the \c orig has been cloned during current cloning on gp.
Using the function outside gp cloning may need fake increment of \c sparp_gp_cloning_serial to avoid the signal. */
extern sparp_equiv_t *sparp_equiv_clone (sparp_t *sparp, sparp_equiv_t *orig, SPART *cloned_gp);

extern void spart_dump_eq (sparp_equiv_t *eq, dk_session_t *ses);

#define SPARP_VAR_SELID_MISMATCHES_GP(var_to_check,parent_gp) (\
  (NULL != (var_to_check)->_.var.selid) && ('(' != (var_to_check)->_.var.selid[0]) && strcmp ((var_to_check)->_.var.selid, (parent_gp)->_.gp.selid) )

#if 0
/*! Makes an exact copy of equiv without changing indexes.
Should be used only if \c orig and the resulting copy will reside in different subqueries, the result should be tweaked in order to point to new gp.
Not for use in optimization of plain SPARQL query! */
extern sparp_equiv_t *sparp_equiv_exact_copy (sparp_t *sparp, sparp_equiv_t *orig);
#endif


#define SPARP_EQUIV_MERGE_ROLLBACK	1001 /*!< Restrict or merge is impossible (in principle or just not implemented) */
#define SPARP_EQUIV_MERGE_OK		1002 /*!< Restrict or merge is done successfully */
#define SPARP_EQUIV_MERGE_CONFLICT	1003 /*!< Restrict or merge is done but it is proven that restrictions contradict */
#define SPARP_EQUIV_MERGE_DUPE		1004 /*!< Merge gets \c primary equal to \c secondary */

/*! Tries to restrict \c primary by \c datatype and/or value.
If neither datatype nor value is provided, SPARP_EQUIV_MERGE_OK is returned. */
extern int sparp_equiv_restrict_by_constant (sparp_t *sparp, sparp_equiv_t *primary, ccaddr_t datatype, SPART *value, ccaddr_t orig_text);

/*! Removes unused \c garbage from the list of equivs of its gp.
The debug version GPFs if the \c garbage is somehow used. */
extern void sparp_equiv_remove (sparp_t *sparp, sparp_equiv_t *garbage);

/*! Merges the content of \c secondary into \c primary (when a variable from \c secondary is proven to be equal to one from \c primary.
At the end of operation, varnames, vars, restrictions, counters subvalues and receivers from \c secondary are added to \c primary
and \c secondary is replaced with \c primary (or removed as dupe) from lists of uses in gp, receivers of senders and senders of receivers.
Conflict in datatypes or fixed values results in SPART_VARR_CONFLICT to eliminate never-happen graph pattern later.
Returns appropriate SPARP_EQUIV_MERGE_xxx */
extern int sparp_equiv_merge (sparp_t *sparp, sparp_equiv_t *primary, sparp_equiv_t *secondary);

/*! Removes the given veriable from its equiv. This is useful for <sparql-only:args_in_same_eq> and similar internal tricks */
extern void sparp_equiv_forget_var (sparp_t *sparp, SPART *var);

/*! Returns whether two given values are equal (same language, same datatype, same SQL value).
If \c first is SPAR_LIT or SPAR_QNAME tree then \c first_dt and \c first_lang are redundand and thus should be NULLs;
If \c first is not a string then \c first_lang should be NULL and \c first_dt should be non-NULL.
Ditto \c second / \c second_dt / \c second_lang .
 */
extern int sparp_values_equal (sparp_t *sparp, ccaddr_t first, ccaddr_t first_dt, ccaddr_t first_lang, ccaddr_t second, ccaddr_t second_dt, ccaddr_t second_lang);

/*! Returns 1 if tightening \c dest by \c add_on might give some effect, 0 if that is proven to be no-op.
Nonzero \c assume_binv_var_and_eq means special policy for binding variable as \c dest an its equiv as \c add_on */
extern int rvr_can_be_tightened (sparp_t *sparp, rdf_val_range_t *dest, rdf_val_range_t *add_on, int assume_binv_var_and_eq);

/*! Returns whether two given rvrs have equal restriction by fixedvalue (and fixedtype).
If any of two are not restricted or they are restricted by two different values then the function returns zero */
extern int sparp_rvrs_have_same_fixedvalue (sparp_t *sparp, rdf_val_range_t *first_rvr, rdf_val_range_t *second_rvr);

/*! Returns whether two given equivs have equal restriction by fixedvalue (and fixedtype).
If any of two are not restricted or they are restricted by two different values then the function returns zero */
#define sparp_equivs_have_same_fixedvalue(sparp,first_eq,second_eq) sparp_rvrs_have_same_fixedvalue ((sparp), &((first_eq)->e_rvr), &((second_eq)->e_rvr))

/*! Returns a datatype that may contain any value from both dt_iri1 and dt_iri2 datatypes, NULL if the result is 'any'.
The function is not 100% accurate so its result may be a supertype of the actual smallest union datatype. */
extern ccaddr_t sparp_smallest_union_superdatatype (sparp_t *sparp, ccaddr_t dt_iri1, ccaddr_t dt_iri2);

/*! Returns a datatype that may contain any value from intersection of dt_iri1 and dt_iri2 datatypes, NULL if the result is 'any'.
The function is not 100% accurate so its result may be a supertype of the actual largest intersect datatype. */
extern ccaddr_t sparp_largest_intersect_superdatatype (sparp_t *sparp, ccaddr_t iri1, ccaddr_t iri2);

/*! Checks whether the given sprintf format string is a bijection */
extern int sprintff_is_proven_bijection (const char *sprintf_fmt);

/*! Checks whether the given sprintf format string is proven to be bad for bijection because fields are merged and the parsing is impossible */
extern int sprintff_is_proven_unparseable (const char *sprintf_fmt);

/*! Returns an sprintf format string such that any string that can be printed by both \c sprintf_fmt1 and \c sprintf_fmt2 can
also be printed by the returned format.
The returned value can be NULL if it's proven that no one string can be printed by both given formats.
The function returns pointer ot DV_STRING that resides in a global hashtable; it shoud not be changed or deleted.
The exception is that values returned by function when \c ignore_cache is set; these values are temporarily and should be deleted. */
extern ccaddr_t sprintff_intersect (ccaddr_t sprintf_fmt1, ccaddr_t sprintf_fmt2, int ignore_cache);

/*! Returns whether \c strg1 can be printed by \c sprintf_fmt2.
The returned value is 0 if it's proven that \c strg1 can not be printed by \c sprintf_fmt2, nonzero otherwise. */
extern int sprintff_like (ccaddr_t strg1, ccaddr_t sprintf_fmt2);

/*! Replaces every "%" in \c strg with "%%", so the result is an sprintf format string (a new DV_STRING plain or mempool box) */
extern caddr_t sprintff_from_strg (ccaddr_t strg, int use_mem_pool);

/*! Changes fields \c rvrSprintffs and \c rvrSprintffCount of \c rvr by adding (up to) \c add_count elements of \c add_sffs */
extern void sparp_rvr_add_sprintffs (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *add_sffs, ptrlong add_count);

/*! Changes fields \c rvrSprintffs and \c rvrSprintffCount of \c rvr by deleting sffs not found in \c isect_count elements of \c isect_sffs */
extern void sparp_rvr_intersect_sprintffs (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *isect_sffs, ptrlong isect_count);

/*! Returns whether \c value matches one of formats of \c rvr (signals an error if \c SPART_VARR_SPRINTFF is nto set in \c rvr->rvrRestrictions ) */
extern int rvr_sprintffs_like (caddr_t value, rdf_val_range_t *rvr);

/*! Adds IRIs classes from \c add_classes into rvr->rvrIriClasses. \c add_count is the length of \c add_classes.
Duplicates are not added, of course. */
extern void sparp_rvr_add_iri_classes (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *add_classes, ptrlong add_count);

/*! Removes from \c rvr->rvrIriClasses all IRIs classes that are missing in \c isect_classes. \c isect_count is the length of \c isect_classes.
Duplicates are not added, of course. */
extern void sparp_rvr_intersect_iri_classes (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *isect_classes, ptrlong isect_count);

/*! Returns fixed string value of \c rvr if the restriction is fixed and the value is of string type; otherwise returns NULL */
extern caddr_t rvr_string_fixedvalue (rdf_val_range_t *rvr);

/*! Adds impossible values from \c add_cuts into \c rvr->rvrIriRedCuts. \c add_count is the length of \c add_cuts.
Duplicates are not added, of course. */
extern void sparp_rvr_add_red_cuts (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *add_cuts, ptrlong add_count);

/*! Removes from \c rvr->rvrIriRedCuts all IRIs classes that are missing in \c isect_cuts. \c isect_count is the length of \c isect_cuts.
Duplicates are not added, of course. */
extern void sparp_rvr_intersect_red_cuts (sparp_t *sparp, rdf_val_range_t *rvr, ccaddr_t *isect_cuts, ptrlong isect_count);

#define SPARP_RVR_CREATE ((rdf_val_range_t *)1L)

#define SPARP_EQUIV_AUDIT_NOBAD 0x01
#ifdef DEBUG
extern void dbg_sparp_rvr_audit (const char *file, int line, sparp_t *sparp, const rdf_val_range_t *rvr);
#define sparp_rvr_audit(sparp,rvr) dbg_sparp_rvr_audit (__FILE__, __LINE__, sparp, rvr)
extern void sparp_equiv_audit_all (sparp_t *sparp, int flags);
extern void sparp_audit_mem (sparp_t *sparp);
extern void sparp_equiv_audit_gp (sparp_t *sparp, SPART *gp, int is_deprecated, sparp_equiv_t *chk_eq);
extern void sparp_equiv_audit_retvals (sparp_t *sparp, SPART *top);

#else
#define sparp_rvr_audit(sparp,rvr)
#define sparp_equiv_audit_all(sparp,flags)
#define sparp_audit_mem(sparp)
#endif

/*! Creates a copy of given \c src (the structure plus member lists but not literals).
If dest is equal to SPARP_RVR_CREATE then it allocates new rvr otherwise it overwrites \c dest */
extern rdf_val_range_t *sparp_rvr_copy (sparp_t *sparp, rdf_val_range_t *dest, const rdf_val_range_t *src);

/*! Tries to zap \c dest and then restrict it by \c datatype and/or value. */
extern void sparp_rvr_set_by_constant (sparp_t *sparp, rdf_val_range_t *dest, ccaddr_t datatype, SPART *value, ccaddr_t orig_text);

/*! Restricts \c dest by additional restrictions from \c addon_restrictions.
The operation checks for validity of resulting combination of the \c rvrRestrictions bits and may set SPART_VARR_CONFLICT.
The following are not supported: SPART_VARR_FIXED, SPART_VARR_TYPED, SPART_VARR_SPRINTFF, SPART_VARR_IRI_CALC. */
extern void sparp_rvr_add_restrictions (sparp_t *sparp, rdf_val_range_t *dest, ptrlong addon_restrictions);

/*! Restricts \c dest by additional restrictions from \c addon that match the mask of \c changeable_flags.
The operation may set SPART_VARR_CONFLICT even if SPART_VARR_CONFLICT bit is not set in \c changeable_flags. */
extern void sparp_rvr_tighten (sparp_t *sparp, rdf_val_range_t *dest, rdf_val_range_t *addon, int changeable_flags);

#if 0 /* Attention: this code is not complete */
/*! Restricts \c dest by additional restrictions from \c addon that match the mask of \c changeable_flags.
The operation will not set SPART_VARR_CONFLICT if addon is not a conflict.
Instead, it removes original restrictions in \c dest when they contradict to \c addon. */
extern void sparp_rvr_override (sparp_t *sparp, rdf_val_range_t *dest, rdf_val_range_t *addon, int changeable_flags);
#endif

/*! Disables restrictions of \c eq that are in contradiction with \c addon and match the mask of \c changeable_flags.
The function can not be used if \c addon has SPART_VARR_CONFLICT set */
extern void sparp_rvr_loose (sparp_t *sparp, rdf_val_range_t *dest, rdf_val_range_t *addon, int changeable_flags);

#ifndef NDEBUG
/*! Restricts \c eq by additional restrictions of \c addon that match the mask of \c changeable_flags, using sparp_rvr_tighten() */
extern void sparp_equiv_tighten (sparp_t *sparp, sparp_equiv_t *eq, rdf_val_range_t *addon, int changeable_flags);

#if 0 /* Attention: this code is not complete */
/*! Restricts \c eq by additional restrictions of \c addon that match the mask of \c changeable_flags, using sparp_rvr_override() */
extern void sparp_equiv_override (sparp_t *sparp, sparp_equiv_t *eq, rdf_val_range_t *addon, int changeable_flags);
#endif

/*! Disables restrictions of \c eq that are in contradiction with \c addon and match the mask of \c changeable_flags.
The function can not be used if \c addon has SPART_VARR_CONFLICT set */
extern void sparp_equiv_loose (sparp_t *sparp, sparp_equiv_t *eq, rdf_val_range_t *addon, int changeable_flags);
#else
#define sparp_equiv_tighten(sparp,eq,addon,flags) sparp_rvr_tighten((sparp),&((eq)->e_rvr),(addon),(flags))
#define sparp_equiv_loose(sparp,eq,addon,flags) sparp_rvr_loose((sparp),&((eq)->e_rvr),(addon),(flags))
#endif

/*! Returns true if the \c tree is an expression that is free from non-global variables */
extern int sparp_tree_is_global_expn (sparp_t *sparp, SPART *tree);

/*! Returns true if some variable from \c eq occurs in \c expn or one of its subexpressions. */
extern int sparp_expn_reads_equiv (sparp_t *sparp, SPART *expn, sparp_equiv_t *eq);

/*! Adds variables to equivalence classes and set counters of usages */
extern void sparp_count_usages (sparp_t *sparp, SPART *req_top, dk_set_t *optvars_ret);

/*! Given set \c binds of \c SPAR_ALIAS expressions and a poitner to an expression to edit, replaces all bound variables with \c alias.arg expressions from alias expressions */
extern void sparp_expand_binds_like_macro (sparp_t *sparp, SPART **expr_ptr, dk_set_t binds, SPART *parent_gp);

/*! Changes and expands lists of return values to handle recursive graph traversal and DESCRIBE. */
void sparp_rewrite_retvals (sparp_t *sparp, SPART *req_top, int safely_copy_retvals);

/*! Performs all basic term rewritings of the query tree, except simplification of all expressions, that can be made by sparp_simplify_expns().
sparp_rewrite_basic() should not call sparp_simplify_expns() directly or indirectly due to the danger of infinite recursion. */
extern void sparp_rewrite_basic (sparp_t *sparp, SPART *req_top);

/*! Checks whether \c sqlval of a literal is a proper string represendation of an object value with type \c dt_iri and language \c lang */
extern int sparp_literal_is_xsd_valid (sparp_t *sparp, ccaddr_t sqlval, ccaddr_t dt_iri, ccaddr_t lang);

/*! Tries to calculate the range of values returned by a \c tree and fill in the structure under \c rvr_ret.
if \c return_independent_copy is zero then the filled structure should remain static, otherwise it gets its own copy of list of formats and can be edited
(however literals should not be edited in any case) */
extern void sparp_get_expn_rvr (sparp_t *sparp, SPART *tree, rdf_val_range_t *rvr_ret, int return_independent_copy);

typedef char sparp_bool4way_t; /* Four-way "boolean" value, 'T' for true, 'F' for false, 'U' for unset, always NULL or conflict, '?' for value that may wary */

/*! Returns boolean value common for the given value range */
extern sparp_bool4way_t sparp_cast_rvr_to_bool4way (sparp_t *sparp, rdf_val_range_t *rvr);
/*! Returns boolean value common for the given literal or variable */
extern sparp_bool4way_t sparp_cast_var_or_lit_to_bool4way (sparp_t *sparp, SPART *tree);


/*! Performs calculation of "pure math" subexpressions and runs custom bif-specific optimizers.
This should be done after at least one sparp_rewrite_basic() on same query tree.
This also should be done at least once before check for sql:signal-void-variable because it may eliminate branches of IF and the like, eliminating "conditionally void" variables.
In case of success, i.e., if some expression is really rewritten, the function ends its execution with sparp_rewrite_basic(). */
extern void sparp_simplify_expns (sparp_t *sparp, SPART *req_top);

/* PART 2. GRAPH PATTERN TERM REWRITING */

extern void spar_invalidate_binv_dataset_row (sparp_t *sparp, SPART *binv, int rowno, int reason_col);

/*! Removes data rows from \c binv as soon as they conflict with equivs of variables in any single cell. As a side effect, unused sprintf formats are removed from equivs. */
extern void spar_shorten_binv_dataset (sparp_t *sparp, SPART *binv);

/*! Re-calculates common properties of \c binv variables by values in their data columns. Any UNBOUND in column disables the re-calculation. */
extern void spar_refresh_binv_var_rvrs (sparp_t *sparp, SPART *binv);

/*! Checks whether a single-column binv without UNSETs and duplicates can be replaced with FILTER (?var IN ( values )) on a gspo or otherwise set variable */
extern int spar_binv_is_convertible_to_filter (sparp_t *sparp, SPART *parent_gp, SPART *member_gp, SPART *member_binv);

/*! Replace binv with FILTER (?var IN ( values )) . No checks are made in this function, the check must be made before via \c spar_binv_is_convertible_to_filter () */
extern void spar_binv_to_filter (sparp_t *sparp, SPART *parent_gp, SPART *member_gp, SPART *member_binv);

/*! Returns triple that contains the given variable \c var as a field.
If \c gp is not NULL the search is restricted by triples that
are direct members of \c gp, otherwise the gp to search will be found by selid of the variable.
If \c need_strong_match is nonzero then the triple should contain pointer to var,
otherwise a triple should contain a field whose selid, tabid, name and tr_idx matches \c var.
The \c var may b blank node or retval as well, but retval has no meaning if \c need_strong_match is set */
extern SPART *sparp_find_triple_of_var_or_retval (sparp_t *sparp, SPART *gp, SPART *var, int need_strong_match);

/*! This finds a variable that is a source of value of a given variable name \c varname in equiv class \c eq.
If there is no such a source variable (e.g. if the source is a UNION, not a triple pattern) then an appropriate retval is returned.
If \c find_exact_specimen then the function will try return a variable from origin eq or its subequivs
that will provide as many restrictions and valmode preferences as possible, but may be unusable for direct use in the codegen
because it can be nested too deep in subqueries and its alias will not be visible at the location of \c var.
If not \c find_exact_specimen then an upper-level retval can be returned instead of deeply buried origin var. */
extern SPART *sparp_find_origin_of_external_varname_in_eq (sparp_t *sparp, sparp_equiv_t *eq, caddr_t varname, int find_exact_specimen, int null_result_allowed);

/*! This is similar to \c sparp_find_origin_of_external_varname_in_eq() but it tries to find an appropriate variable name automatically */
extern SPART *sparp_find_origin_of_some_external_varname_in_eq (sparp_t *sparp, sparp_equiv_t *eq, int find_exact_specimen);

/*! This is a wrapper for \c sparp_find_origin_of_external_varname_in_eq() that gets a single variable \c var
instead of a pair of the equivalence class of \c var and the name of \c var */
extern SPART *sparp_find_origin_of_external_var (sparp_t *sparp, SPART *var, int find_exact_specimen);

/*! This finds a position of a variable or an equivalent of that variable in the result-set array made by a binv (an external, with NULL \c wrapping_gp or a VALUES_L nested into \c wrapping_gp).
If no suitable item found then -1 is returned */
extern int sparp_find_binv_rset_pos_of_varname (sparp_t *sparp, SPART *wrapping_gp, SPART *binv, caddr_t e_varname);

/*! This finds a position of a variable or an equivalent of that variable in the result-set/param-list array made by a sinv.
\c do_search_for_param instructs where to search: true for param-list, zero for result-set.
If no suitable item found then -1 is returned */
extern int sparp_find_sinv_rset_or_param_pos_of_varname (sparp_t *sparp, SPART *service_gp, caddr_t e_varname, int do_search_for_param);

/*! This finds a variable or SPAR_ALIAS in \c retvals whose name is equal to \c varname, return the expression or, if \c return_alias, the whole SPAR_ALIAS */
extern SPART *sparp_find_subexpn_in_retlist (sparp_t *sparp, const char *varname, SPART **retvals, int return_alias);

/*! This finds a variable or SPAR_ALIAS in \c retvals whose name is equal to \c varname, return the 1-based position in \c retvals */
extern int sparp_subexpn_position1_in_retlist (sparp_t *sparp, const char *varname, SPART **retvals);

/*! This returns a mapping of \c var.
If var_triple is NULL then it tries to find it using \c sparp_find_triple_of_var() for vars and \c sparp_find_triple_of_var_or_retval() for retvals.
\c allow_returning_null is useful when a \c var is a retval from subselect so it is not associated with any triple pattern */
extern qm_value_t *sparp_find_qmv_of_var_or_retval (sparp_t *sparp, SPART *var_triple, SPART *gp, SPART *var, int allow_returning_null);

extern int sparp_find_language_dialect_by_service (sparp_t *sparp, SPART *service_expn);

/*! This searches for storage by its name. NULL arg means default (or no storage if there's no default loaded), empty UNAME means no storage */
extern quad_storage_t *sparp_find_storage_by_name (ccaddr_t name);

/*! This searches for quad map by its name. */
extern quad_map_t *sparp_find_quad_map_by_name (ccaddr_t name);

#define SSG_QM_UNSET		0	/*!< The value is not yet calculated */
#define SSG_QM_NO_MATCH		1	/*!< Triple matching triple pattern can not match the qm restriction, disjoint */
#define SSG_QM_PARTIAL_MATCH	2	/*!< Triple matching triple pattern may match the qm restriction, but no warranty, common case */
#define SSG_QM_APPROX_MATCH	3	/*!< Triple matching triple pattern will always match the qm restriction (so triple pattern is more strict than qm) OR var in pattern and non-constant qm value */
#define SSG_QM_PROVEN_MATCH	4	/*!< Triple matching triple pattern will always match the qm restriction, this is strictly proven so it can be used to cut by soft exclusive */
#define SSG_QM_MATCH_AND_CUT	5	/*!< SSG_QM_APPROX_MATCH plus qm is soft/hard exclusive so red cut and no more search for possible quad maps of lower priority */

typedef struct tc_context_s {
  SPART *		tcc_triple;			/*!< Triple pattern in question */
  int			tcc_check_source_graphs;	/*!< Nonzero if \c tcc_sources contains nonzero number of graphs so it forms the restriction that should be checked */
  SPART **		tcc_sources;			/*!< Source graphs that can be used */
  uint32 *		tcc_source_invalidation_masks;	/*!< String of integers, nonzero means that the source graph with same index in \c tcc_sourcess has failed some restriction at some level of nested quad maps. 0x1 is for global restriction by type, 0x2 is for RDF views etc. SPAN_NOT_FROM_xxx are never masked, of course */
  quad_storage_t *	tcc_qs;				/*!< Quad storage in question */
  quad_map_t **		tcc_top_allowed_qms;		/*!< Top qms that are allowed, if some are specified in the triple via QUAD MAP xx { } */
  void *tcc_last_qmvs [SPART_TRIPLE_FIELDS_COUNT];	/*!< Pointers to recently checked QMVs or constants. QMVs tend to repeat in sequences. */
  int tcc_last_qmv_results [SPART_TRIPLE_FIELDS_COUNT];	/*!< Results of recent comparisons. */
  dk_set_t tcc_cuts [SPART_TRIPLE_FIELDS_COUNT];	/*!< Accumulated red cuts for possible values of fields */
  dk_set_t		tcc_found_cases;		/*!< Accumulated triple cases */
  int			tcc_nonfiltered_cases_found;	/*!< Count of triples cases that passed tests, including cases rejected due to QUAD MAP xx { } restriction of triple */
} tc_context_t;

/*! This checks if the given \c qm may contain data that matches \c tcc->tcc_triple by itself,
without its submaps and without the check of qmEmpty. */
extern int sparp_check_triple_case (sparp_t *sparp, tc_context_t *tcc, quad_map_t *qm, int invalidation_level);

/*! The function fills in the \c tc_set_ret[0] with triple cases of all matching quad mappings
(\c qm, submaps of \c qm and al subsubmaps recursively
that match and not empty and not after the first (empty or nonempty) full match. */
extern int sparp_qm_find_triple_cases (sparp_t *sparp, tc_context_t *tcc, quad_map_t *qm, int inside_allowed_qm, int invalidation_level);

/*! This returns a mempool-allocated vector of quad maps
that describe an union of all elementary datasources that can store triples that match a pattern.
\c required_source_type should be SPART_GRAPH_FROM or SPART_GRAPH_NAMED */
extern triple_case_t **sparp_find_triple_cases (sparp_t *sparp, SPART *triple, SPART **sources, int required_source_type);

/*! This calls sparp_find_triple_cases() and fills in \c tc_list and \c native_formats of \c triple->_.triple */
extern void sparp_refresh_triple_cases (sparp_t *sparp, SPART **sources, SPART *triple);

extern int sparp_expns_are_equal (sparp_t *sparp, SPART *one, SPART *two);
extern int sparp_expn_lists_are_equal (sparp_t *sparp, SPART **one, SPART **two);

/*! This replaces selid and tabid in all variables in an option list (say, options of a triple) (assuming that ids in field variables match ids of a triple) */
extern void sparp_set_options_selid_and_tabid (sparp_t *sparp, SPART **options, caddr_t new_selid, caddr_t new_tabid);
/*! This replaces selid and tabid in a triple (assuming that ids in field variables match ids of a triple) */
extern void sparp_set_triple_selid_and_tabid (sparp_t *sparp, SPART *triple, caddr_t new_selid, caddr_t new_tabid);

/*! This replaces selids of all variables in retvals and soring expressions with current selid of the topmost gp */
extern void sparp_set_retval_and_order_selid (sparp_t *sparp);

extern void sparp_set_special_order_selid (sparp_t *sparp, SPART *new_gp);

/*! This replaces selids of all variables in a filter */
extern void sparp_set_filter_selid (sparp_t *sparp, SPART *filter, caddr_t new_selid);

extern SPART **sparp_treelist_full_clone_int (sparp_t *sparp, SPART **origs, SPART *parent_gp);
extern SPART *sparp_tree_full_clone_int (sparp_t *sparp, SPART *orig, SPART *parent_gp);

/*! This creates a full clone of \c gp subtree with cloned equivs.
The function will substitute all selids and tabids of all graph patterns and triples in the tree and
substitute equiv indexes with indexes of cloned equivs (except SPART_BAD_EQUIV_IDX index that persists). */
extern SPART *sparp_gp_full_clone (sparp_t *sparp, SPART *gp);

/*! This makes a full clone of \c origs. As a result, triples and variables outside any GPs are copied, inside GPs they're changed like in case of sparp_gp_full_clone. */
extern SPART **sparp_treelist_full_clone (sparp_t *sparp, SPART **origs);

/*! This creates a full copy of \c orig subtree without cloning equivs.
Variables inside copy have unidirectional pointers to equivs until attached to other tree or same place in same tree. */
#if 0
extern SPART *sparp_tree_full_copy (sparp_t *sparp, SPART *orig, SPART *parent_gp);
#else
#define sparp_tree_full_copy(sparp,orig,parent_gp) sparp_tree_full_copy_2(sparp,orig)
extern SPART *sparp_tree_full_copy_2 (sparp_t *sparp, SPART *orig);
#endif

/*! This creates a copy of \c origs array and fills it with sparp_tree_full_copy of each member of the array. */
#if 0
extern SPART **sparp_treelist_full_copy (sparp_t *sparp, SPART **origs, SPART *parent_gp);
#else
#define sparp_treelist_full_copy(sparp,orig,parent_gp) sparp_treelist_full_copy_2(sparp,orig)
extern SPART **sparp_treelist_full_copy_2 (sparp_t *sparp, SPART **origs);
#endif

/*! This fills in \c acc with all distinct variable names found inside the tree, including subqueries.
Found variable names are pushed into \c acc that may be non-empty when the procedure is called */
extern void sparp_distinct_varnames_of_tree (sparp_t *sparp, SPART *tree, dk_set_t *acc);

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
Filters should be detached before triple patterns are detached, to make proper assignments of triple_with_var_obj->_.triple.ft_type .
\returns the detached filter. */
extern SPART *sparp_gp_detach_filter (sparp_t *sparp, SPART *parent_gp, int filter_idx, sparp_equiv_t ***touched_equivs_ptr);

/*! This removes all filters from \c parent_gp and removes its variables from equivs.
If \c touched_equivs_ptr is not NULL then the list of edited equivs is composed.
Removal of filters does not alter restrictions of equivalence classes derived from filters, because the operation should be used as
a part of safe rewriting that preserves the logic.
If \c extract_filters_replaced_by_equivs is true and \c parent_gp contains equivs with nonzero e_replaces_filters
then the replaced filters become expressions again and added to the resulting list.
Filters should be detached before triple patterns are detached, to make proper assignments of triple_with_var_obj->_.triple.ft_type .
\returns the list of detached filters. */
extern SPART **sparp_gp_detach_all_filters (sparp_t *sparp, SPART *parent_gp, int extract_filters_replaced_by_equivs, sparp_equiv_t ***touched_equivs_ptr);

/*! This adds \c new_filter into list of filters of \c parent_gp, the insert position is specified by \c insert_before_idx
If \c touched_equivs_ptr is not NULL then the list of edited equivs is composed.
All selids of variables of the attached filter are adjusted automatically and these variables are added to equiv classes of \c parent_gp.
Restrictions on variables of \c new_filter should be propagated across the tree by additional calls of appropriate functions.
Filters should be attached after triple patterns are attached, to make proper assignments of triple_with_var_obj->_.triple.ft_type . */
extern void sparp_gp_attach_filter (sparp_t *sparp, SPART *parent_gp, SPART *new_filter, int insert_before_idx, sparp_equiv_t ***touched_equivs_ptr);

/*! This adds \c new_filters into list of filters of \c parent_gp, the insert position is specified by \c insert_before_idx
If \c touched_equivs_ptr is not NULL then the list of edited equivs is composed.
All selids of variables of the attached filters are adjusted automatically and these variables are added to equiv classes of \c parent_gp.
Restrictions on variables of \c new_filters should be propagated across the tree by additional calls of appropriate functions.
This is faster than attach \c new_filters by a sequence of sparp_gp_attach_member() calls.
Filters should be attached after triple patterns are attached, to make proper assignments of triple_with_var_obj->_.triple.ft_type . */
extern void sparp_gp_attach_many_filters (sparp_t *sparp, SPART *parent_gp, SPART **new_filters, int insert_before_idx, sparp_equiv_t ***touched_equivs_ptr);

extern void sparp_gp_tighten_by_eq_replaced_filters (sparp_t *sparp, SPART *dest, SPART *orig, int remove_origin);

/*! This makes the gp and all its sub-gps unusable and marks 'deprecated' all equivs that belong to these gps. */
extern void sparp_gp_deprecate (sparp_t *sparp, SPART *parent_gp, int suppress_eq_check);

/*! This calls sparp_gp_deprecate() for all gps ofa subquery. */
extern void sparp_req_top_deprecate (sparp_t *sparp, SPART *top);

/*! This traverse triple or group options to count usages. If selids of vars are equal to uname_nil then they're replaced with selid of \c gp inside sparp_equiv_get() calls. */
extern void sparp_gp_trav_cu_in_options (sparp_t *sparp, SPART *gp, SPART *curr, SPART **options, void *common_env);

/*! This may turn, e.g., '10 > ?a' into '?a < 10' in order to normalize expressions before optimizations.
No effects if called for the second time. */
extern void sparp_rotate_comparisons_by_rank (SPART *filt);

/*! This replaces group patterns with conflicts into explicitly empty patterns.
\c returns 1 if \c parent_gp is made empty (by sparp_gp_produce_nothing (), 0 otherwise */
extern int sparp_detach_conflicts (sparp_t *sparp, SPART *parent_gp);

/*! This converts union of something and unions into flat union.
Any single-item subjoin of one GP is treated as union.
The changed part is changed again while there are some subunions but unchanged part is not visited recursively.
Equivalences are touched, of course, but who cares?
!!!TBD: support of filters in the union GP, this is GPF now. */
extern void sparp_flatten_union (sparp_t *sparp, SPART *parent_gp);

/*! This converts join of something and inner joins.
Any single-item subunion is treated as join.
The changed part is changed again while there are some subjoins but unchanged part is not visited recursively.
Equivalences are touched, of course, but who cares?
!!!TBD: support of filters in the union GP, this is GPF now. */
extern void sparp_flatten_join (sparp_t *sparp, SPART *parent_gp);

/*! If a gp is group of non-optional triples and each triple has exactly one possible quad map then the function returns vector of tabids of triples.
In addition, if the \c expected_triples_count argument is nonnegative then number of triples in group should be equal to that argument.
If any condition fails, the function returns NULL.
This function is used in breakup code generation. */
extern caddr_t *sparp_gp_may_reuse_tabids_in_union (sparp_t *sparp, SPART *gp, int expected_triples_count);

/*! This produces a list of single-triple GPs such that every GP implements only one quad mapping from
qm_list of the original \c triple.
Every generated gp contains a triple that has qm_list of length 1; guess what's the member of the list :)
If an original triple has \c ft_type set then a free-text condition should be removed from \c parent_gp before the removal of triple from parent_gp and passed as \c ft_cod_to_relocate argument to be cloned into every generated gp
*/
extern SPART **sparp_make_qm_cases (sparp_t *sparp, SPART *triple, SPART *parent_gp, SPART *ft_cond_to_relocate);

/*! Creates a new graph pattern of specified \c subtype as if it is parsed ar \c srcline of source text. */
extern SPART *sparp_new_empty_gp (sparp_t *sparp, ptrlong subtype, ptrlong srcline);

/*! This turns \c gp into a union of zero cases and adjust VARR flags of variables to make them always-NULL */
extern void sparp_gp_produce_nothing (sparp_t *sparp, SPART *gp);

/*! This fills in "all atables" member of the given quad map */
extern void sparp_collect_all_atable_uses (sparp_t *sparp_or_null, quad_map_t *qm);

/*! This fills in "all conds" member of the given quad map */
extern void sparp_collect_all_conds (sparp_t *sparp_or_null, quad_map_t *qm);

/*! Perform all rewritings according to the type of the tree, grab logc etc. */
extern SPART *sparp_rewrite_all (sparp_t *sparp, SPART *req_top, int safely_copy_retvals);

extern void sparp_make_common_eqs (sparp_t *sparp, SPART *req_top);

/*! Assigns table aliases to all variables in the expression */
extern void sparp_make_aliases (sparp_t *sparp, SPART *req_top);


typedef struct sparp_label_external_vars_env_s {
  dk_set_t parent_gps_for_var_search;
  dk_set_t parent_gps_for_table_subq;
} sparp_label_external_vars_env_t;

/*! Label variables as EXTERNAL. */
extern void sparp_label_external_vars (sparp_t *sparp, SPART *req_top, sparp_label_external_vars_env_t *sleve);

/*! Visits all subtres and subqueries of \c tree and places all distinct names of global and external variables to \c set_set[0] */
extern void sparp_list_external_vars (sparp_t *sparp, SPART *tree, dk_set_t *set_ret);

/*! Removes equivalence classes that are no longer in any sort of use (neither pure connections nor equivs of actual variables */
extern void sparp_remove_totally_useless_equivs (sparp_t *sparp);

#define SPARP_UNLINK_IF_ASSIGNED_EXTERNALLY 0x1
/*! Removes equivalence classes that were supposed to be pure connections but are not connections at all. */
extern void sparp_remove_redundant_connections (sparp_t *sparp, SPART *req_top, ptrlong flags);

/*! Given an OPTIONAL_L right side of loj (specified by combination of \c parent and \c pos_of_curr_memb) and an equiv \c eq,
this finds the most restrictive variable or retval at left side, and fills in \c ret_parent_eq[0] and \c ret_tree_in_parent[0].
If \c eq->e_replaces_filter and eq is not assigned locally then a condition with ret_tree_in_parent[0] instead of \c eq will act as a filter.
The repeated expression can be placed in ON (...) clause of the generated LEFT OUTER JOIN and thus preserved from being lost due to lack of
appropriated variables in scope of WHERE clause of SELECT at the right size of loj. */
extern void sparp_find_best_join_eq_for_optional (sparp_t *sparp, SPART *parent, int pos_of_curr_memb, sparp_equiv_t *eq, sparp_equiv_t **ret_parent_eq, SPART **ret_tree_in_parent, SPART **ret_source_in_parent);

/*! Convert a query with grab vars into a select with procedure view with seed/iter/final sub-SQLs as arguments. */
extern SPART *sparp_rewrite_grab (sparp_t *sparp, SPART *req_top);

/*! Scans the query with its subqueries and replaces vars made by binds with expressions from that binds. Members of UNION gp that have BINDs inside become subqueries. BINDs of subquery are added to the resultset of the subquery. */
extern void sparp_expand_binds (sparp_t *sparp, SPART *req_top);

/*! Finds all mappings of all triples, then performs all graph pattern term rewritings of the query tree */
extern SPART *sparp_rewrite_qm (sparp_t *sparp, SPART *req_top);

/*! Initial part of sparp_rewrite_qm() that is executed once at top and in every subquery. It finds all mappings of all triples. */
extern void sparp_rewrite_qm_preopt (sparp_t *sparp, SPART *req_top, int safely_copy_retvals);

/*! Optimization loop body sparp_rewrite_qm() that is executed recursively at top and in every subquery while it has some effect.
Returns zero if optimization gives no effect. \c opt_ctr is just a value counter of loops, mostly to run some optimizations not on every loop.
A special value of SPARP_MULTIPLE_OPTLOOPS tells to run default sequence of few optloops with check for dirty and endless optimization. */
extern int sparp_rewrite_qm_optloop (sparp_t *sparp, SPART *req_top, int opt_ctr);
#define SPARP_MULTIPLE_OPTLOOPS -20080327

/*! Tries to propagate the \c outer_limit inside the \c tree */
extern void spar_propagate_limit_as_option (sparp_t *sparp, SPART *tree, SPART *outer_limit);

/*! Finalization part of sparp_rewrite_qm(), including invocation of whole support of recursive sponge. */
extern void sparp_rewrite_qm_postopt (sparp_t *sparp, SPART *req_top);

/*! Expand '*' retval list into actual list of variables, add MAX around non-grouped variables etc.
This also edits ORDER BY ?top-resultset-alias and replaces it with appropriate ORDER BY <int> */
extern void sparp_expand_top_retvals (sparp_t *sparp, SPART *query, int safely_copy_all_vars, dk_set_t binds_revlist);

#define SPARP_SET_OPTION_NEW		0	/*!< Set an option only if it do not exists yet */
#define SPARP_SET_OPTION_REPLACING	1	/*!< Set an option, overwriting any existing value */
#define SPARP_SET_OPTION_APPEND1	2	/*!< Adds an item to an exising value that is SPAR_LIST already (or creates a new single-item SPAR_LIST) */
/*! Creates a new option (or changes existing one), alters \c options_ptr if needed and returns the whole value changed or created */
extern SPART *sparp_set_option (sparp_t *sparp, SPART ***options_ptr, ptrlong key, SPART *value, ptrlong mode);
/*! Scans the \c options vector and returns an option value for the given option key */
extern SPART *sparp_get_option (sparp_t *sparp, SPART **options, ptrlong key);
/*! Returns list of options of a GP or TRIPLE tree */
extern SPART **sparp_get_options_of_tree (sparp_t *sparp, SPART *tree);
extern void sparp_validate_options_of_tree (sparp_t *sparp, SPART *tree, SPART **options);

/*! Returns 0 of \c tree is not a req_top or has no LIMIT or OFFSET, 1 if LIMIT and/or OFFSET exist and what exist is plain integer, 2 if at lease one of LIMIT / OFFSET is an expression other than a constant integer */
extern int sparp_req_top_has_limofs (SPART *tree);

/* PART 3. SQL OUTPUT GENERATOR */

struct spar_sqlgen_s;
#if 0
struct rdf_ds_field_s;
#endif
struct rdf_ds_s;

/* Special 'macro' names of ssg_valmode_t modes. The order of numeric values is important ssg_shortest_valmode() */
#define SSG_VALMODE_SHORT_OR_LONG	((ssg_valmode_t)((ptrlong)(0x300)))	/*!< Any representation, whatever is "shorter" */
#define SSG_VALMODE_NUM			((ssg_valmode_t)((ptrlong)(0x310)))	/*!< Something that is number for numbers, date for date, NULL or something else for everything else; a shortest reasonable input for arithmetics */
#define SSG_VALMODE_LONG		((ssg_valmode_t)((ptrlong)(0x320)))	/*!< Completed RDF objects */
#define SSG_VALMODE_SQLVAL		((ssg_valmode_t)((ptrlong)(0x330)))	/*!< SQL value to bereturned to the SQL caller */
#define SSG_VALMODE_DATATYPE		((ssg_valmode_t)((ptrlong)(0x340)))	/*!< Datatype UNAME or BF_URI string, not a value */
#define SSG_VALMODE_LANGUAGE		((ssg_valmode_t)((ptrlong)(0x350)))	/*!< Language is needed, not a value */
#define SSG_VALMODE_BOOL		((ssg_valmode_t)((ptrlong)(0x360)))	/*!< No more than a boolean is needed */
#define SSG_VALMODE_AUTO		((ssg_valmode_t)((ptrlong)(0x370)))	/*!< Something simplest */
#define SSG_VALMODE_SPECIAL		((ssg_valmode_t)((ptrlong)(0x380)))
/* typedef struct rdf_ds_field_s *ssg_valmode_t; -- moved to sparql.h */

/*! \c returns smallest valmode that can keep values from both \c m1 and \c m2.
In addition to the returned value it can set \c sqlval_is_ok_and_cheap_ret[0] to zero if the sqlval of either \c m1 or \c m2 is not cheap.
sqlval of SSG_VALMODE_AUTO is cheap because "auto" can become sqlval when needed and the conversion is not needed at all.
sqlval SSG_VALMODE_SHORT_OR_LONG \c m1 or \c m2 is not cheap.
SSG_VALMODE_LONG \c m1 is not cheap by default but can be treated as cheap if \c sqlval_is_ok_and_cheap_ret[0] has bit 0x2 set:
this bit is convenient if \c m1 is a result of previous ssg_smallest_union_valmode() of other members of same union.
Similarly, SSG_VALMODE_LONG \c m2 is not cheap by default but can be treated as cheap if \c sqlval_is_ok_and_cheap_ret[0] has bit 0x4 set:
this is primarily for internal use when ssg_smallest_union_valmode() calls itself with swapped arguments. */
extern ssg_valmode_t ssg_smallest_union_valmode (ssg_valmode_t m1, ssg_valmode_t m2, int *sqlval_is_ok_and_cheap_ret);
extern ssg_valmode_t ssg_largest_intersect_valmode (ssg_valmode_t m1, ssg_valmode_t m2);
extern ssg_valmode_t ssg_largest_eq_valmode (ssg_valmode_t m1, ssg_valmode_t m2);
extern int ssg_valmode_is_subformat_of (ssg_valmode_t m1, ssg_valmode_t m2);
extern ssg_valmode_t ssg_find_nullable_superformat (ssg_valmode_t fmt);


extern qm_format_t *qm_format_default_iri_ref;
extern qm_format_t *qm_format_default_ref;
extern qm_format_t *qm_format_default;
extern qm_format_t *qm_format_default_iri_ref_nullable;
extern qm_format_t *qm_format_default_ref_nullable;
extern qm_format_t *qm_format_default_nullable;
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

/*! Description of SPARQL Built In Function (one mentioned in spec and in lang syntax) */
typedef struct sparp_bif_desc_s {
  const char *		sbd_name;		/*!< Name, uppercased */
  int			sbd_subtype;		/*!< Assigned SPAR_BIF_xxx value */
  char			sbd_implementation;	/*!< Type of implementation. '-' for special code generation, 'B' for BIF, 'S' for stored procedures */
  int			sbd_required_syntax;	/*!< Bits of sparql dialect such that at least one bit should be set in dialect in order to allow the function */
  int			sbd_minargs;		/*!< Minimum allowed number of arguments */
  int			sbd_maxargs;		/*!< Maximum allowed number of arguments */
  ssg_valmode_t 	sbd_ret_valmode;	/*!< Native valmode of the expression */
  ssg_valmode_t 	sbd_arg_valmodes[3];	/*!< Expected valmodes of the arguments. The valmode of last specified argument is used for the rest of arguments */
  int			sbd_result_restr_bits;	/*!< (Approximate) restriction bits of the result, they can be changed after inspecting restriction bits of arguments */
} sparp_bif_desc_t;

extern const sparp_bif_desc_t sparp_bif_descs[];


#define NULL_ASNAME ((const char *)NULL)
#define COL_IDX_ASNAME (((const char *)NULL) + 0x100)

/*! Prints a subalias (and dot after alias, if flagged by the last argument), returns whether everything is printed */
extern int ssg_prin_subalias (struct spar_sqlgen_s *ssg, const char *alias, const char *colalias, int dot_after_alias);
/*! Prints the SQL expression based on \c tmpl template of \c qm_fmt valmode. \c asname is name used for AS xxx clauses, other arguments form context */
extern void ssg_print_tmpl (struct spar_sqlgen_s *ssg, qm_format_t *qm_fmt, ccaddr_t tmpl, ccaddr_t alias, qm_value_t *qm_val, SPART *tree, const char *asname);
extern void sparp_check_tmpl (sparp_t *sparp, ccaddr_t tmpl, int qmv_known, dk_set_t *used_aliases);
extern caddr_t sparp_patch_tmpl (sparp_t *sparp, ccaddr_t tmpl, dk_set_t alias_replacements);

extern int ssg_is_odbc_cli (void);
extern int ssg_is_odbc_msaccess_cli (void);

/*! This searches for declaration of type by its name. NULL name result in NULL output, unknown name is an error */
extern ssg_valmode_t ssg_find_valmode_by_name (ccaddr_t name);

extern void ssg_find_formatter_by_name_and_subtype (ccaddr_t name, ptrlong subtype,
  const char **ret_formatter, const char **ret_agg_formatter, const char **ret_agg_mdata );

/*! Field is the expression that represents the value of a SPARQL variable. */
typedef struct spar_sqlgen_var_s
{
  quad_map_t	*ssgv_source_qm;	/*!< The source where the value comes from, to access table names and vtable with template printer. */
  qm_value_t	*ssgv_field_qmv;	/*!< The field, with data for template printer */
  int		ssgv_is_short;	/*!< Flag whether the value is short (for local joins in graph) or long (for generic ops) */
} spar_sqlgen_var_t;

/*! Context of SQL generator */
typedef struct spar_sqlgen_s
{
/* Query data */
  /*spar_query_t		*ssg_query;*/	/*!< Query to process */
  struct sql_comp_s	*ssg_sc;		/*!< Environment for sqlc_exp_print and similar functions. */
  sparp_t		*ssg_sparp;		/*!< Pointer to general parser data */
  SPART			*ssg_tree;		/*!< Select tree to process, of type SPAR_REQ_TOP */
  sparp_equiv_t		**ssg_equivs;		/*!< Shorthand for ssg_sparp->sparp_sg->sg_equivs */
  ptrlong		ssg_equiv_count;	/*!< Shorthand for ssg_sparp->sparp_sg->sg_equiv_count */
  struct spar_sqlgen_s	*ssg_parent_ssg;	/*!< Ssg that prints outer subquery */
  struct spar_sqlgen_s	*ssg_nested_ssg;	/*!< Ssg that prints some fragment for the current one, like a text of query to send to a remote service. This is used for GC on abort */
  SPART *		ssg_wrapping_gp;	/*!< A gp of subtype SELECT_L or SERVICE_L that contains the current subquery */
  SPART *		ssg_wrapping_sinv;	/*!< Service invocation description of \c ssg_wrapping_p in case of SERVICE_L gp subtype */
  int			ssg_comment_sql;	/*!< The mode of putting comments into the generated SQL, as set by define sql:comments (default 0 for release, 1 otherwise) */
/* Run-time environment */
  SPART			**ssg_sources;		/*!< Data sources from ssg_tree->_.req_top.sources and/or environment */
/* SQL Codegen temporary values */
  dk_session_t		*ssg_out;		/*!< Output for SQL text */
  int			ssg_where_l_printed;	/*!< Flags what to print before a filter: " WHERE" if 0, " AND" otherwise */
  const char *		ssg_where_l_text;	/*!< Text to print when (0 == ssg_where_l_printed), usually " WHERE" */
  int			ssg_indent;		/*!< Number of whitespaces to indent. Actually, pairs of whitespaces, not singles */
  int			ssg_line_count;		/*!< Number of lines of generated SQL code */
  dk_set_t		ssg_valid_ret_selids;	/*!< stack of selids of GPs that can be safely used to generate SQL code for retvals (i.e. their selids are in current scope) */
  dk_set_t		ssg_valid_ret_tabids;	/*!< stack like ssg_valid_ret_selids, but for tabids */
  dk_set_t		ssg_outer_valid_ret_selids;	/*!< Initial content of \c ssg_valid_ret_selids. This content is passed to sub-ssgs that make non-scalar subqueries, because they do not access selids of neigbours but can access selids outside some surrounding scalar subquery */
  dk_set_t		ssg_outer_valid_ret_tabids;	/*!< Initial content of \c ssg_valid_ret_tabids. */
  int			ssg_seealso_enabled;	/*!< Flags if \c ssg_print_fld_var_restrictions_ex() (or the like) should generate calls of RDF_GRAB_SEEALSO; they should for "init" and "iter" of a pview, but not for "final" */
/* SPARQL-D Codegen temporary values */
  SPART *		ssg_sd_current_sinv;	/*!< Service invocation that will receive the fragment that is printed ATM (for error reporting) */
  caddr_t		ssg_sd_service_naming;	/*!< The text like "SERVICE <iri>" or "SERVICE called via ?var" (for error reporting) */
  int			ssg_sd_flags;		/*!< Bitmask of SSG_SD_xxx flags, see rdf_mapping.jso */
  id_hash_t		*ssg_sd_used_namespaces;	/*!< Dictionary of namespaces used for prettyprinting of IRIs */
  dk_set_t		ssg_sd_outer_gps;	/*!< Parent GP of the current tree */
  int			ssg_sd_forgotten_graph;	/*!< Flags that a '}' is not printed after the last triple (in hope that the next member of a group is a triple with same graph so '} GRAPH ... {' is not required */
  int			ssg_sd_forgotten_dot;	/*!< Flags that a dot is not printed after the last triple (in hope that the next member of a group is a triple with same subject so ';' or ',' shorthand can be used) */
  SPART *		ssg_sd_prev_graph;	/*!< Graph of the previous triple in a group, to make a decision about avoiding print of '} GRAPH ... {' */
  SPART *		ssg_sd_prev_subj;	/*!< Subject of the previous triple in a group, to make a decision about using ';' or ',' shorthand */
  SPART *		ssg_sd_prev_pred;	/*!< Predicate of the previous triple in a group, to make a decision about using ',' shorthand */
  SPART *		ssg_sd_req_top;		/*!< Current SPAR_RQ_TOP ancestor-or-self, used, e.g., to convert ORDER BY 1 into ORDER_BY ?first_column */
  caddr_t		ssg_sd_single_from;	/*!< The IRI in FROM clause, if there's only one FROM clause, NULL otherwise */
  int			ssg_sd_graph_gp_nesting;	/*!< Count of GRAPH {...} gps that are opened but not yet closed */
  dk_set_t		ssg_param_pos_set;	/*!< revlist of byte offsets of params in text and numbers of params in question, for sinv templates with unsupported named params */
  int			ssg_inside_t_inouts;	/*!< The list of T_IN or T_OUT values is being printed */
  dk_set_t		ssg_param_t_inouts;	/*!< list of variables that are used in T_IN and T_OUT options but passed as parameters to a remote, so the option should use internal name and a separate FILTER should appear later */
/* RDB2RDF Codegen temporary values */
  const char *		ssg_alias_to_search;	/*!< Alias to select for search-and-replace (say, to replace "main alias" with prefixes for old or new columns) */
  const char *		ssg_alias_to_replace;	/*!< Replacing alias for search-and-replace */
} spar_sqlgen_t;

/*!< Releases non-mempooled internals of \c ssg (currently the ssg_out) but does not free \c ssg itself (it's supposed to be on stack (if top-level) or in mem pool (if top-level or nested) */
void ssg_free_internals (spar_sqlgen_t *ssg);

#define ssg_putchar(c) session_buffered_write_char (c, ssg->ssg_out)
#define ssg_puts(strg) session_buffered_write (ssg->ssg_out, strg, strlen (strg))

#define ssg_puts_with_comment(strg,cmt) do {\
  if (ssg->ssg_comment_sql) \
    ssg_puts (strg " /* " cmt " */"); \
  else \
    ssg_puts (strg); \
} while (0)

#define ssg_puts_with_comment3(strg,cmt1,cmt2,cmt3) do {\
  if (ssg->ssg_comment_sql) \
    { ssg_puts (strg " /* " cmt1); ssg_puts (cmt2); ssg_puts (cmt3 " */"); } \
  else \
    ssg_puts (strg); \
} while (0)

#define ssg_puts_comment(cmt) do {\
  if (ssg->ssg_comment_sql) \
    ssg_puts (" /* " cmt " */"); \
} while (0)

#define ssg_puts_comment3(cmt1,cmt2,cmt3) do {\
  if (ssg->ssg_comment_sql) \
    { ssg_puts (" /* " cmt1); ssg_puts (cmt2); ssg_puts (cmt3 " */"); } \
} while (0)

#define ssg_print_asname_tail(cmt,asname) do { \
  if (NULL != (asname)) { \
      ssg_puts_with_comment (" AS", cmt); \
      ssg_putchar (' '); \
      ssg_prin_id (ssg, (asname)); \
    } } while (0);

#define ssg_putbuf(buf,bytes) session_buffered_write (ssg->ssg_out, (buf), (bytes))

#ifdef DEBUG
extern void spar_sqlprint_error_impl (spar_sqlgen_t *ssg, const char *msg);
#define spar_sqlprint_error(x) do { spar_sqlprint_error_impl (ssg, (x)); return; } while (0)
#define spar_sqlprint_error2(x,v) do { spar_sqlprint_error_impl (ssg, (x)); return (v); } while (0)
#else
#define spar_sqlprint_error_impl(ssg,msg) spar_internal_error (NULL, (msg))
#define spar_sqlprint_error(x) spar_internal_error (NULL, (x))
#define spar_sqlprint_error2(x,v) spar_internal_error (NULL, (x))
#endif


#define SSG_INDENT_FACTOR 2
#define SSG_MAX_ALLOWED_LINE_COUNT 10000
#define ssg_newline(back) \
  do { \
    int ind = ssg->ssg_indent; \
    if (0 < ind) \
      ind = 1 + ind * SSG_INDENT_FACTOR - (back); \
    else \
      ind = 1; \
    if (SSG_MAX_ALLOWED_LINE_COUNT == ssg->ssg_line_count++) \
      spar_sqlprint_error_impl (ssg, "The length of generated SQL text has exceeded 10000 lines of code"); \
    session_buffered_write (ssg->ssg_out, "\n                              ", (ind > 31) ? 31 : ind); \
    } while (0)

/*! Adds either iri of \c jso_inst or \c jso_name into dependencies of the generated query. \c jso_inst is used only if \c jso_name is NULL */
extern void spar_qr_uses_jso_int (comp_context_t *cc, ccaddr_t jso_inst, ccaddr_t jso_name);

#define sparp_qr_uses_jso(sparp,jso_inst,jso_name) do { \
  struct sql_comp_s *super_sc = (sparp)->sparp_sparqre->sparqre_super_sc; \
  if (NULL != super_sc) \
    spar_qr_uses_jso_int (super_sc->sc_cc, (jso_inst), (jso_name)); } while (0)

#define ssg_qr_uses_jso(ssg,jso_inst,jso_name) spar_qr_uses_jso_int ((ssg)->ssg_sc->sc_cc, (jso_inst), (jso_name))

extern void ssg_qr_uses_table (spar_sqlgen_t *ssg, const char *tbl);

extern ssg_valmode_t sparp_lit_native_valmode (SPART *tree);
extern ssg_valmode_t sparp_expn_native_valmode (sparp_t *sparp, SPART *tree);
extern ptrlong sparp_restr_bits_of_dtp (dtp_t dtp);
extern ptrlong sparp_restr_bits_of_expn (sparp_t *sparp, SPART *tree);
extern ssg_valmode_t sparp_equiv_native_valmode (sparp_t *sparp, SPART *gp, sparp_equiv_t *eq);

extern void sparp_jso_validate_format (sparp_t *sparp, ssg_valmode_t fmt);

/*! Prints an SQL identifier. 'prin' instead of 'print' because it does not print whitespace or delim before the text */
extern void ssg_prin_id (spar_sqlgen_t *ssg, const char *name);
extern void ssg_prin_id_with_suffix (spar_sqlgen_t *ssg, const char *name, const char *suffix);
#define SQL_ATOM_ASCII_ONLY	10
#define SQL_ATOM_NARROW_ONLY	11
#define SQL_ATOM_UTF8_ONLY	12
#define SQL_ATOM_NARROW_OR_WIDE	13
#define SQL_ATOM_UNAME_ALLOWED	14
#define SQL_ATOM_ABORT_ON_CAST	15	/*!< Intentionally "bad" mode to get an error on any cast to string */
#define SQL_ATOM_SPARQL_INTEROP	16
extern void ssg_print_box_as_sql_atom (spar_sqlgen_t *ssg, ccaddr_t box, int mode);
extern void ssg_print_literal_as_sql_atom (spar_sqlgen_t *ssg, ccaddr_t type, SPART *lit);
extern void ssg_print_literal_as_sqlval (spar_sqlgen_t *ssg, ccaddr_t type, SPART *lit);
extern void ssg_print_literal_as_long (spar_sqlgen_t *ssg, SPART *lit);
extern void ssg_print_equiv (spar_sqlgen_t *ssg, caddr_t selectid, sparp_equiv_t *eq, ccaddr_t asname);

extern ssg_valmode_t sparp_rettype_of_global_param (sparp_t *sparp, caddr_t name);
extern ssg_valmode_t sparp_rettype_of_function (sparp_t *sparp, caddr_t name, SPART *call_tree);
extern ssg_valmode_t sparp_argtype_of_function (sparp_t *sparp, caddr_t name, SPART *call_tree, int arg_idx);
extern void ssg_prin_function_name (spar_sqlgen_t *ssg, ccaddr_t name);

extern void ssg_print_global_param (spar_sqlgen_t *ssg, SPART *var, ssg_valmode_t needed);
extern void ssg_print_global_param_name (spar_sqlgen_t *ssg, caddr_t vname);
extern void ssg_print_valmoded_scalar_expn (spar_sqlgen_t *ssg, SPART *tree, ssg_valmode_t needed, ssg_valmode_t native, const char *asname);
extern void ssg_print_scalar_expn (spar_sqlgen_t *ssg, SPART *tree, ssg_valmode_t needed, const char *asname);
extern void ssg_print_filter_expn (spar_sqlgen_t *ssg, SPART *tree);
extern void ssg_print_retval (spar_sqlgen_t *ssg, SPART *tree, ssg_valmode_t vmode, const char *asname);
extern void ssg_print_qm_sql (spar_sqlgen_t *ssg, SPART *tree);

/* These bitmasks begin with 0x10, not with 0x1, in order to not conflict with SSG_PRINT_UNION_xxx bits; ssg_print_union() can get a mix */
#define SSG_RETVAL_SET_ALIAS_BY_EQUIV		0x00010	/*!< If alias name is NULL, set it by the "default" varname of equiv */
#define SSG_RETVAL_USES_ALIAS			0x00020	/*!< Return value can be printed in form 'expn AS alias' if alias name is not NULL */
#define SSG_RETVAL_SUPPRESSED_ALIAS		0x00040	/*!< Return value is not printed in form 'expn AS alias', only 'expn' but alias is known to subtree and let generate names like 'alias~0' */
#define SSG_RETVAL_MUST_PRINT_SOMETHING		0x00080	/*!< The function signals an error instead of returning failure and tries to relax SSG_RETVAL_FROM_GOOD_SELECTED to SSG_RETVAL_FROM_ANY_SELECTED as a last resort */
#define SSG_RETVAL_CAN_PRINT_NULL		0x00100	/*!< The function should print at least NULL but it can not return failure */
#define SSG_RETVAL_FROM_GOOD_SELECTED		0x00200	/*!< Use result-set columns from 'good' (non-optional) subqueries */
#define SSG_RETVAL_FROM_ANY_SELECTED		0x00400	/*!< Use result-set columns from any subqueries, including 'optional' that can make NULL */
#define SSG_RETVAL_FROM_JOIN_MEMBER		0x00800	/*!< The function can print expression like 'tablealias.colname' */
#define SSG_RETVAL_FROM_FIRST_UNION_MEMBER	0x01000	/*!< The function can print the value from the first member of UNION, because if the gp is union then other members will be printed later */
#define SSG_RETVAL_TOPMOST			0x02000	/*!< Top-level result list is printed, so __dummy_retval is renamed to __ask_retval (and there may be more renames in future) */
#define SSG_RETVAL_EQUIV_INSTEAD_OF_TREE	0x04000	/*!< The name is passed to the function, not an SPART * with retval */
#define SSG_RETVAL_DIST_SER_LONG		0x08000	/*!< Use DB.DBA.RDF_DIST_SER_LONG wrapper to let DISTINCT work with formatters. */
#define SSG_RETVAL_IGNORE_NEEDED_VALMODE_IF_BIJ	0x10000	/*!< Ignore "needed" valmode specified for retval list if the native valmode is bijection. */
#define SSG_RETVAL_OPTIONAL_MAKES_NULLABLE	0x20000	/*!< Return value should be printed as nullable because it comes from, say, OPTIONAL sub-gp */
#define SSG_RETVAL_STRICT_TYPES			0x40000	/*!< Every returned expression should either be accomplished with its (known) SQL type or be CAST-ed to the VARCHAR (esp., if it's ANY) */
/* descend = 0 -- at level, can descend. 1 -- at sublevel, can't descend, -1 -- at level, can't descend */
extern int ssg_print_equiv_retval_expn (spar_sqlgen_t *ssg, SPART *gp,
  sparp_equiv_t *eq, int flags, ssg_valmode_t needed, const char *asname );

extern void ssg_print_sparul_run_call (spar_sqlgen_t *ssg, SPART *gp, SPART *tree, int compose_report);
extern void ssg_print_retval_simple_expn (spar_sqlgen_t *ssg, SPART *gp, SPART *tree, ssg_valmode_t needed, const char *asname);

/*! Prints restrictions specified by \c rvr on \c fld_tree variable that is a field of \c triple.
If bit is set in both \c rvr and \c restr_bits_to_ignore then the codegen for bit's property can be suppressed, however the bit in \c rvr is still valid for use in other parts of the codegen.
The purpose of \c restr_bits_to_ignore is to suspend checks that are made as a side effect of "good" equalities printed for the equiv of the variable */
extern void ssg_print_fld_var_restrictions_ex (spar_sqlgen_t *ssg, quad_map_t *qmap, qm_value_t *field, caddr_t tabid, SPART *fld_tree, SPART *triple, SPART *fld_if_outer, rdf_val_range_t *rvr, ptrlong restr_bits_to_ignore);
extern void ssg_print_fld_restrictions (spar_sqlgen_t *ssg, quad_map_t *qmap, qm_value_t *field, caddr_t tabid, SPART *gp, SPART *triple, int fld_idx, int print_outer_filter);
extern void ssg_print_all_table_fld_restrictions (spar_sqlgen_t *ssg, quad_map_t *qm, caddr_t alias, SPART *gp, SPART *triple, int enabled_field_bitmask, int print_outer_filter);

extern void ssg_print_limofs_expn (spar_sqlgen_t *ssg, SPART *lim, SPART *ofs);

#define	SSG_TABLE_SELECT_PASS		1
#define	SSG_TABLE_WHERE_PASS		2
#define	SSG_TABLE_PVIEW_PARAM_PASS	3
extern void ssg_print_table_exp (spar_sqlgen_t *ssg, SPART *gp, SPART **trees, int tree_count, int pass);
extern void ssg_print_subquery_table_exp (spar_sqlgen_t *ssg, SPART *wrapping_gp);
extern void ssg_print_sinv_table_exp (spar_sqlgen_t *ssg, SPART *gp, int pass);
extern void ssg_print_scalar_subquery_exp (spar_sqlgen_t *ssg, SPART *sub_req_top, SPART *wrapping_gp, ssg_valmode_t needed);

#define SSG_PRINT_UNION_NOFIRSTHEAD	0x01	/*!< Flag to suppress printing of 'SELECT retvallist' of the first member of the union */
#define SSG_PRINT_UNION_NONEMPTY_STUB	0x02	/*!< Flag to print a stub that returns a 1-row result of single column, instead of a stub with empty resultset */
extern void ssg_print_union (spar_sqlgen_t *ssg, SPART *gp, SPART **retlist, int head_flags, int retval_flags, ssg_valmode_t needed);

extern void ssg_print_orderby_item (spar_sqlgen_t *ssg, SPART *gp, SPART *oby_itm);
extern void ssg_print_where_or_and (spar_sqlgen_t *ssg, const char *location);

/*! Returns nonzero if \c rv may produce value that may screw up result of SELECT DISTINCT if not wrapped in RDF_DIST_SER_LONG/RDF_DIST_DESER_LONG */
extern int sparp_retval_should_wrap_distinct (sparp_t *sparp, SPART *tree, SPART *rv);
/*! Returns nonzero if some retvals of \c tree may screw up the result if not wrapped in RDF_DIST_SER_LONG/RDF_DIST_DESER_LONG */
extern int sparp_some_retvals_should_wrap_distinct (sparp_t *sparp, SPART *tree);

#define SSG_REQ_TOP_RB_COMPLETE_OFF		0	/*!< Flag to indicate that there is no need in SELECT __ro2sq(x) FROM (SELECT x ...) trick */
#define SSG_REQ_TOP_RB_COMPLETE_DISTINCT_ONLY	1	/*!< Flag to indicate a need for either SELECT __ro2sq(x) FROM (SELECT DISTINCT x ...) or SELECT x FROM (SELECT DISTINCT __ro2sq(x) ...) trick depending on bijection/non-bijection of native valmode of x */
#define SSG_REQ_TOP_RB_COMPLETE_COMMON_CASE	2	/*!< Flag to indicate that there a need in SELECT __ro2sq(x) FROM (SELECT x ...) trick not for (not only for) the DISTINCT_L */
/*! Fills in ssg->ssg_out with an SQL text of a query. \c need_for_rb_complete is one of SSG_REQ_TOP_RB_COMPLETE_xxx */
extern void ssg_make_sql_query_text (spar_sqlgen_t *ssg, int need_for_rb_complete);
/*! Fills in ssg->ssg_out with a wrapping query with rdf box completion for a result of \c ssg_make_sql_query_text(). \c need_for_rb_complete is one of SSG_REQ_TOP_RB_COMPLETE_xxx but not SSG_REQ_TOP_RB_COMPLETE_OFF */
extern void ssg_make_rb_complete_wrapped (spar_sqlgen_t *ssg, int need_for_rb_complete);
/*! Makes a decision whether \c ssg_make_rb_complete_wrapped() is needed or plain \c ssg_make_sql_query_text() is adequate */
extern int ssg_req_top_needs_rb_complete (spar_sqlgen_t *ssg);
/*! Fills in ssg->ssg_out with an SQL text of quad map manipulation statement */
extern void ssg_make_qm_sql_text (spar_sqlgen_t *ssg);
/*! Fills in ssg->ssg_out with an SQL text of arbitrary statement, by calling ssg_make_sql_query_text(), ssg_make_qm_sql_text(), or some special codegen callback */
extern void ssg_make_whole_sql_text (spar_sqlgen_t *ssg);

/* PART 4. SPARQL-D ("-DISTRIBUTED") GENERATOR */

#define SSG_SD_VOS_CURRENT	(SSG_SD_VOS_6 | SSG_SD_SPARQL11_DRAFT)	/*!< Allows everything that is supported by current version of Virtuoso Open Source */
#define SSG_SD_SPARQL11		(SSG_SD_SPARQL11_DRAFT | SSG_SD_SPARQL11_FULL)	/*!< Allows the use of SPARQL 1.1 extensions, blocking in most of cases */
#define SSG_SD_BI_OR_SPARQL11_DRAFT	(SSG_SD_BI | SSG_SD_SPARQL11_DRAFT)
#define SSG_SD_DEPRECATED_MASK	0x0	/*!< All bits of deprecated flags (none so far) */
#define SSG_SD_MAXVALUE		(SSG_SD_VOS_CURRENT | SSG_SD_DEPRECATED_MASK)

extern void ssg_sdprin_literal (spar_sqlgen_t *ssg, SPART *tree);
extern void ssg_sdprin_qname (spar_sqlgen_t *ssg, SPART *tree);
extern void ssg_sdprint_tree (spar_sqlgen_t *ssg, SPART *tree);
extern void ssg_sdprin_local_varname (spar_sqlgen_t *ssg, ccaddr_t vname);
extern void ssg_sdprin_varname (spar_sqlgen_t *ssg, ccaddr_t vname);
extern void ssg_sdprint_equiv_restrs (spar_sqlgen_t *ssg, sparp_equiv_t *eq);
extern void sparp_make_sparqld_text (spar_sqlgen_t *ssg);

#endif
