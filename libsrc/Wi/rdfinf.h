/*
 *  rdfinf.h
 *
 *  $Id$
 *
 *  RDF Inference
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
 */

typedef struct rdf_sub_s 
{
  caddr_t	rs_iri;
  dk_set_t	rs_superclasses;
  dk_set_t	rs_subclasses;
  dk_set_t	rs_subproperties;
  dk_set_t	rs_superproperties;
  id_hash_t *   rs_superclasses_ht;
  id_hash_t *   rs_subclasses_ht;
  id_hash_t *   rs_subproperties_ht;
  id_hash_t *   rs_superproperties_ht;
  char		rs_transitive;
} rdf_sub_t;


typedef struct rdf_inf_ctx_s 
{
  caddr_t			ric_name;
  id_hash_t * ric_iri_to_sub;
} rdf_inf_ctx_t;


struct rdf_inf_node_s
{
  data_source_t	src_gen;
  rdf_inf_ctx_t *	ri_ctx;
  char		ri_mode; /* enum subclasses or subproperties */
  char		ri_is_after; /* true if postprocess of the ts or hs */
  state_slot_t *	ri_p; /* if open P and subclass, thios is the p, so look if this is rdf:type before activation */
  state_slot_t *	ri_o;
  state_slot_t *	ri_isnon_org_o; /* for gs, fp, go, this ssl is true if the o is an enum other than the given o */
  caddr_t	ri_given; /* the iri for which to enum sub/super classes/properties */
  state_slot_t *	ri_output;
  state_slot_t *	ri_outer_any_passed; /* if rhs of left outer, flag here to see if any answer. If not, do outer output when at end */ 
  int		ri_list_slot;
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
#define RI_SUBCLASS 1
#define RI_SUPERCLASS 2
#define RI_SUBPROPERTY 3
#define RI_SUPERPROPERTY 4
#define RI_SAME_AS_O 5
#define RI_SAME_AS_S 6
#define RI_SAME_AS_P 7


void rdf_inf_pre_input (rdf_inf_pre_node_t * ri, caddr_t * inst, 		   caddr_t * volatile state);
caddr_t dfe_iri_const (df_elt_t * dfe);
dk_set_t ri_list (rdf_inf_pre_node_t * ri, caddr_t iri);
rdf_inf_ctx_t * rdf_name_to_ctx (caddr_t name);
rdf_sub_t * ric_iri_to_sub (rdf_inf_ctx_t * ctx, caddr_t iri);
void ri_outer_output (rdf_inf_pre_node_t * ri, state_slot_t * any_flag, caddr_t * inst);
void sqlg_outer_with_iters (df_elt_t * tb_dfe, data_source_t * ts, data_source_t ** head);
