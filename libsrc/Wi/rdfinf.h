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
#ifndef _RDFINF_H
#define _RDFINF_H

typedef struct rdf_sub_s
{
  caddr_t	rs_iri;			/*!< Boxed IRI_ID of self */
  dk_set_t	rs_super;		/*!< Direct superproperties or superclasses (set of pointers to their rdf_sub_t) */
  dk_set_t	rs_sub;			/*!< Direct subproperties or subclasses (set of pointers to their rdf_sub_t) */
  dk_set_t	rs_equiv;		/*!< Equivalent prperties or classes (set of pointers to their rdf_sub_t) */
  int32		rs_n_subs;		/*!< Count of distinct subproperties or subclasses, recursively.  Filled in on traversal */
  char		rs_flags;
} rdf_sub_t;


typedef struct rdf_inf_ctx_s
{
  caddr_t	ric_name;
  id_hash_t *	ric_iri_to_subclass;			/*!< Map from IRI of class to pointer to rdf_sub_t */
  id_hash_t *	ric_iri_to_subproperty;			/*!< Map from IRI of property to pointer to rdf_sub_t */
  id_hash_t *	ric_iid_to_rel_ifp;			/*!< Map from IRI_ID of an IFP to array of IFPs of all IFPs with a common IFP superproperty */
  caddr_t *	ric_ifp_list;				/*!< Array of IRI_IDs of inverse functional properties */
  caddr_t *	ric_ifp_rel_list;			/*!< Array of IRI_IDs of inverse functional properties that have related IFPs (i.e. IFP super- and/or sub- properties) */
  caddr_t *	ric_inverse_prop_pair_sortedalist;	/*!< List of pairs of UNAMEs of props that are inverse to each other. Each pair is named twice. Pairs are sorted by keys. */
  caddr_t *	ric_prop_props;				/*!< Flags of properties name1 bits1 name2 bits2... names are sorted UNAMEs, only bit 1 is used atm and means "transitive" */
  id_hash_t *	ric_ifp_exclude;			/*!< Map from ifp P iri to values that do not make identity even if they occur as ifp values of 2 subjects. e.g. sha1 of "mailto://" */
  id_hash_t *	ric_samples;				/*!< Cardinality estimates with this inf ctx enabled */
  dk_mutex_t *	ric_mtx;				/*!< Mutex for ric_samples sample cache */
} rdf_inf_ctx_t;


typedef struct ri_state_s
{
  rdf_sub_t  *	ris_node;
  dk_set_t	ris_position;
  struct	ri_state_s *	ris_prev;
  char	ris_is_equiv; /* true if traversing equivalents */
} ri_state_t;


typedef struct ri_iterator_s
{
  id_hash_t *	rit_visited;
  char		rit_mode;
  char		rit_next_sibling;
  char		rit_at_start;
  char		rit_at_end;
  rdf_sub_t *	rit_value;
  ri_state_t *	rit_state;
} ri_iterator_t;


struct rdf_inf_node_s
{
  data_source_t	src_gen;
  iter_node_t		ri_iter;
  rdf_inf_ctx_t *	ri_ctx;
  caddr_t 		ri_ctx_name;
  char		ri_mode; /* enum subclasses or subproperties */
  char		ri_is_after; /* true if postprocess of the ts or hs */
  state_slot_t *	ri_p; /* if open P and subclass, thios is the p, so look if this is rdf:type before activation */
  state_slot_t *	ri_o;
  state_slot_t *	ri_isnon_org_o; /* for gs, fp, go, this ssl is true if the o is an enum other than the given o */
  caddr_t	ri_given; /* the iri for which to enum sub/super classes/properties */
#define ri_output 	ri_iter.in_output
#define ri_current_value ri_iter.in_current_value
#define ri_current_set 	ri_iter.in_current_set
#define ri_vec_array ri_iter.in_vec_array
  state_slot_t *	ri_outer_any_passed; /* if rhs of left outer, flag here to see if any answer. If not, do outer output when at end */
  state_slot_t *	ri_iterator;
  state_slot_t *	ri_sas_in; /* the value whose same_as-s are to be listed */
  state_slot_t **	ri_sas_g;
    state_slot_t *	ri_sas_out;
  state_slot_t *	ri_sas_reached;
  state_slot_t *	ri_sas_follow;
  int		ri_sas_last_out;
  int		ri_sas_next_out;
  int		ri_sas_last_follow;
  int		ri_sas_next_follow;
};


#define RI_CONT_RESTORE ((dk_set_t) -1)

/* ri_mode */
#define  RI_SUBCLASS 1
#define RI_SUPERCLASS 2
#define RI_SUBPROPERTY 3
#define RI_SUPERPROPERTY 4
#define RI_SAME_AS_O 5
#define RI_SAME_AS_S 6
#define RI_SAME_AS_P 7
#define RI_SAME_AS_IFP 128 /* in same as mode, means that we use the ifp sas criterion */




typedef struct trans_state_s
{
  caddr_t	tst_value;
  caddr_t	tst_data;
  struct trans_state_s * 	tst_prev;
  int		tst_depth;
  int		tst_path_no; /* in result set, identifies the path. Set to -1 if this tst is not the last of the path */
} trans_state_t;


typedef struct trans_set_s
{
  caddr_t	ts_value;
  id_hash_t *	ts_traversed;
  dk_set_t	ts_new;
  dk_set_t 	ts_input_set_nos; /* if non-unq inputs, this is the list of ordinal positions corresponding to this set */
  caddr_t	ts_target; /* if looking for a specific value, this is equal to tst_value and the tst is considered a result */
  struct trans_set_s *	ts_target_ts; /* if doing both ends against the middle, a tst is a result if its input equals the input of one of the values in this ts */
  int	ts_target_flag_col; /* if the dt has a col that indicates a successful path, this is its position */
  int		ts_max_depth;
  dk_set_t	ts_result;
  dk_set_t	ts_last_result;
  dk_set_t 	ts_current_result;
  int		ts_current_result_step; /* if enumerating the steps of result tst */
} trans_set_t;


struct trans_node_s
{
  data_source_t	src_gen;
  cl_buffer_t	clb;
  int		tn_current_set; /* current set in vector */
  char		tn_is_pre_iter; /* like an invisible sameas or such */
  char		tn_is_primary;
  char		tn_commutative;
  char		tn_lowest_sas; /* for a sas, return the lowest id of the generated same as set */
  char		tn_iri_only;
  char		tn_exists; /* stop at first result */
  char		tn_keep_path;
  char		tn_distinct;
  char		tn_no_cycles;
  char		tn_cycles_only;
  char		tn_ordered;
  char		tn_ends_given; /* both start and end are given */
  char		tn_shortest_only; /* if both ends given, generate all paths with length equal to the shortest path length */
  char		tn_direction;
  trans_node_t *	tn_complement; /* from left-right and back */
  state_slot_t *	tn_min_depth;
  state_slot_t *	tn_max_depth;
  caddr_t *		tn_input_pos;
  caddr_t *		tn_output_pos;
  state_slot_t **	tn_input;
  state_slot_t **	tn_input_src;
  state_slot_t **	tn_input_ref;
  state_slot_t **	tn_output;
  state_slot_t **	tn_target;
  state_slot_t **	tn_data;
  state_slot_t *	tn_path_no_ret;
  state_slot_t *	tn_step_no_ret;
  state_slot_t **	tn_step_out; /* out slots for intermediate inputs when returning full path */
  state_slot_t *	tn_state_ssl; /* put the trans_state being processed here for access in the step dt */
  state_slot_t *	tn_step_set_no;
  state_slot_t *	tn_end_flag;
  state_slot_t * 	tn_relation; /* fetched input->output tuples, list indexed on input tuple */
  state_slot_t *	tn_lc;
  int 		tn_input_sets; /* from distinct input to trans set */
  int		tn_state;
  int		tn_path_ctr; /*inx in ssl for counter of solution ids if steps are shown */
  state_slot_t *	tn_to_fetch; /* the inputs for which the step is about to be run */
  query_t *	tn_prepared_step; /* if precompiled step qr with its own qi, like for sameas */
  query_t *	tn_inlined_step; /* if repeated step shares the same qi */
  code_vec_t	tn_after_join_test;
  state_slot_t **	tn_sas_g;
  state_slot_t **	tn_out_slots;
  ptrlong		tn_max_memory;
  caddr_t		tn_ifp_ctx_name;
  state_slot_t *	tn_ifp_g_list;
  int	        tn_nth_cache_result;
  ssl_index_t	tn_d0_sent; /* set if input is part of output and has been passed on when first recd */
  char	tn_step_qr_id;
};

#define TN_DEFAULT_MAX_MEMORY tn_max_memory
extern int64 tn_max_memory;
extern id_hash_t * rdf_name_to_ric;
void rdf_inf_pre_input (rdf_inf_pre_node_t * ri, caddr_t * inst, 		   caddr_t * volatile state);
void rdf_inf_pre_free (rdf_inf_pre_node_t * ri);
caddr_t dfe_iri_const (df_elt_t * dfe);
dk_set_t ri_list (rdf_inf_pre_node_t * ri, caddr_t iri, rdf_sub_t ** sub_ret);
rdf_inf_ctx_t * rdf_name_to_ctx (caddr_t name);
rdf_sub_t * ric_iri_to_sub (rdf_inf_ctx_t * ctx, caddr_t iri, int mode, int create);
void ri_outer_output (rdf_inf_pre_node_t * ri, state_slot_t * any_flag, caddr_t * inst);
void sqlg_outer_with_iters (df_elt_t * tb_dfe, data_source_t * ts, data_source_t ** head);
void sqlg_leading_multistate_same_as (sqlo_t * so, data_source_t ** q_head, data_source_t * ts,
				      df_elt_t * g_dfe, df_elt_t * s_dfe, df_elt_t * p_dfe,  df_elt_t * o_dfe, int mode,
				 rdf_inf_ctx_t * ctx, df_elt_t * tb_dfe, int inxop_inx, rdf_inf_pre_node_t ** ri_ret);
void sqlg_rdf_ts_replace_ssl (table_source_t * ts, state_slot_t * old, state_slot_t * new, int col_id, int inxop_inx);
rdf_inf_ctx_t *  sqlg_rdf_inf_same_as_opt (df_elt_t * tb_dfe);
char * ssl_inf_name (df_elt_t * dfe);
void tn_free (trans_node_t * tn);
data_source_t * sqlg_distinct_same_as (sqlo_t * so, data_source_t ** q_head,
				       ST ** col_sts, df_elt_t * dt_dfe, 		       dk_set_t pre_code);


rdf_inf_ctx_t * rdf_inf_ctx (char * name);

rdf_sub_t * rit_next (ri_iterator_t * rit);
ri_iterator_t * ri_iterator (rdf_sub_t * rs, int mode, int distinct);
void sas_ensure ();
id_hash_t * tn_hash_table_get (trans_node_t * tn);
extern dk_mutex_t * tn_cache_mtx;

#define RDFS_TYPE_IRI "http://www.w3.org/1999/02/22-rdf-syntax-ns#type"

caddr_t iri_ensure (caddr_t * qst, caddr_t name, int flag, caddr_t * err_ret);

#define RI_INIT_NEEDED_REC(qst)			\
  if (1 != cl_rdf_inf_inited) cl_rdf_inf_init_1 (qst);

void  cl_rdf_inf_init_1 (caddr_t * qst);

#endif
