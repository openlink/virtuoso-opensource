/*
 *  xmlnode.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

#ifndef _XMLNODE_H
#define _XMLNODE_H

#include "Dk.h"
#include "text.h"


/* Reasons why ranges may be required by caller of sst_ranges.
   During a run, some of them may be switched off, but not on.
   E.g. SST_RANGES4XCONTAINS may be disabled if record's XML will be XML
   text, not XPER. */
#define TXS_RANGES4OUTPUT	0x02	/*!< Ranges should be stored in some resulting recordset */
#define TXS_RANGES4XCONTAINS	0x04	/*!< Ranges may be useful for xcontains optimization */
#define TXS_RANGES4DEBUG	0x80	/*!< Ranges are needed for debugging purposes */

void * dk_alloc_zero (size_t c);/*mapping schema*/

typedef struct text_node_s
  {
    data_source_t	 src_gen;
    cl_buffer_t		clb;
    dbe_table_t *	txs_table;
    state_slot_t *	txs_text_exp;
    state_slot_t *	txs_xpath_text_exp; /* if in combination w xpath, this is the free text part */
    state_slot_t *	txs_score;
    state_slot_t *	txs_score_limit;
    state_slot_t *	txs_d_id;		/*!< Text-index id of the row found */
    state_slot_t *	txs_sst;
    state_slot_t *	txs_main_range_out;
    state_slot_t *	txs_attr_range_out;
    ptrlong		txs_why_ranges;			/*!< Bits from TXS_RANGES4XXX */
    char		txs_is_driving;
    char		txs_order; /* if should give deterministic order in cluster */
    unsigned char 	txs_geo;
    char		txs_is_rdf;
    table_source_t *	txs_loc_ts; /* half filled ts to serve for partitioning in cluster if txs partitioned by d_id */
    state_slot_t *	txs_cached_string;		/*!< previous string, compiled by xp_text_parse() for this node, as caddr_t */
    state_slot_t *	txs_cached_compiled_tree;	/*!< result of compilation txs_cached_str by xp_text_parse(), as caddr_t * */
    state_slot_t *	txs_cached_dtd_config;
    state_slot_t **	txs_offband;
    state_slot_t **	txs_offband_vars;
    state_slot_t *	txs_desc;
    state_slot_t *	txs_init_id;
    state_slot_t *	txs_end_id;
    state_slot_t *	txs_ext_fti;	/*!< String that describes the external free-text index to use */
    state_slot_t *	txs_precision;
    float		txs_card;
    /* if xcontains, properties of xpath node duplicated here */
    char		txs_xn_pred_type;
    state_slot_t *	txs_xn_xq_compiled;
    state_slot_t *	txs_xn_xq_source;
    state_slot_t *	txs_qcr;
    int		txs_pos_in_qcr;
    int		txs_pos_in_dc;
  } text_node_t;


/* txs_geo */
#define GSOP_CONTAINS	0x01
#define GSOP_WITHIN	0x02
#define GSOP_INTERSECTS	0x03
#define GSOP_MAY_INTERSECT	0x04
#define GSOP_MAY_CONTAIN	0x05

#define GSOP_CORE_MASK		0x0F

#define GSOP_NEGATION		0x10
#define GSOP_PRECISION		0x20
/* If more bits are occupied, change the size of txs_geo and itc_geo_op fields */


extern const char *predicate_name_of_gsop (int gsop);


typedef struct xpath_node_s
  {
    data_source_t	src_gen;
    cl_buffer_t		clb;
    ptrlong		xn_predicate_type;
    state_slot_t *	xn_exp_for_xqr_text;
    state_slot_t *	xn_compiled_xqr;
    state_slot_t *	xn_compiled_xqr_text;
    state_slot_t *	xn_text_col;
    state_slot_t *	xn_output_val;
    state_slot_t *	xn_xqi;
    text_node_t *	xn_text_node;
    state_slot_t *	xn_base_uri;
    state_slot_t *	xn_output_len;
    state_slot_t *	xn_output_ctr;
  } xpath_node_t;



typedef struct misc_accelerator_s {
  search_spec_t ***	ma_specs;
  oid_t *		ma_ids;
  state_slot_t **	ma_out_slots;
} misc_accelerator_t;




#define XML_MAX_EXP_NAME 1000

#define AX_ANCESTOR_1	11
#define AX_CHILD_1	 1

#define AX_ANCESTOR	12
#define AX_CHILD_REC	2

#define AX_SIBLING	 3
#define AX_SIBLING_REV	13

#define AX_FOLLOWING	4
#define AX_PRECEDING	14

#define AX_ANCESTOR_OR_SELF	 15
#define AX_DESCENDANT_OR_SELF	 5

/* IvAn/SmartXContains/001025 Optimized axises added for using word range information */
#define AX_CHILD_1_WR	 6
#define AX_CHILD_REC_WR	7
#define AX_DESCENDANT_OR_SELF_WR	8

typedef struct ancestor_scan_s
  {
    int			as_axis;
    state_slot_t *	as_init_pl;
    caddr_t		as_init_pl_name;
    state_slot_t *	as_current_level;
    state_slot_t *	as_subscript;
    key_id_t		as_key_id;
    caddr_t		as_entity_name;
    state_slot_t *	as_from_subscript;
    state_slot_t *	as_to_subscript;
  } ancestor_scan_t;


typedef struct xml_attr_s
  {
    oid_t	xa_id;
    caddr_t	xa_name;
    id_hash_t *	xa_meta_by_uri;
    dbe_column_t *	xa_col;
  } xml_attr_t;


typedef struct xml_schema_s
  {
    id_hash_t *		xs_name_to_attr;
    dk_hash_t *		xs_id_to_attr;
    id_hash_t *		xs_element_table;
    dk_hash_t *		xs_key_id_to_element;
    id_hash_t *		xs_views;
    dk_set_t  *         xs_old_views; /*mapping schema*/
  } xml_schema_t;


typedef struct xml_local_s
  {
    dk_hash_t *	xl_local_attrs;
  } xml_local_t;


typedef struct misc_asg_s
  {
    oid_t		asg_col_id;
    state_slot_t *	asg_ssl;
  } misc_asg_t;


typedef struct xml_table_ins_s {
  query_t *	iq_qr;
  oid_t *	iq_cols;
} xml_insert_qr_t;


xml_attr_t * lt_xml_attr (lock_trx_t * lt, char * name);
xml_attr_t * lt_xml_attr_by_id (lock_trx_t * lt, oid_t a_id);
dbe_column_t * lt_xml_col (lock_trx_t * lt, char * name);
oid_t qi_new_attr (query_instance_t * qi, char * name);
xml_attr_t qi_attr (query_instance_t * qi, char * name);


extern key_id_t entity_key_id;
extern key_id_t textfrag_key_id;
extern oid_t entity_misc_col_id;
extern oid_t entity_name_col_id;
extern oid_t entity_wspace_col_id;
extern oid_t entity_level_col_id;
extern oid_t entity_id_col_id;
extern oid_t entity_leading_col_id;
extern oid_t entity_trailing_col_id;
extern oid_t textfrag_leading_col_id;
extern oid_t textfrag_long_col_id;
extern dbe_table_t * entity_table;
extern dbe_table_t * textfrag_table;


int itc_xml_search (it_cursor_t * it, buffer_desc_t ** buf_ret, dp_addr_t * leaf_ret);
int itc_text_search (it_cursor_t * it, buffer_desc_t ** buf_ret, dp_addr_t * leaf_ret);
void tb_write_misc (dbe_column_t ** cols, dk_session_t * ses, db_buf_t old_misc, dbe_table_t * tb, caddr_t * qst, state_slot_t ** slots);

#define MIN_MISC_ID ((oid_t) 10000000)
#define MAX_MISC_ID ((oid_t) 0xffffffff)
/* space for 10 million col ids and 4G-10M XML attr ids */

#define IS_MISC_ID(id) \
  (((oid_t) id) >= MIN_MISC_ID && ((oid_t) id < MAX_MISC_ID))

#ifdef BIF_XML
dbe_column_t * tb_name_to_column_misc (dbe_table_t * tb, char * name);
#else
#define tb_name_to_column_misc tb_name_to_column
#endif



void upd_misc_col (update_node_t * upd, caddr_t * qst, dbe_table_t * row_tb, db_buf_t old_val, dk_session_t * ses,
	      caddr_t * err_ret);

void ins_misc_col (dk_session_t * ses,
		   dbe_table_t * tb, oid_t * col_ids, caddr_t * values);


caddr_t qi_tb_xml_schema (query_instance_t * qi, char * read_tb);

dbe_table_t * xmls_element_table (char * elt);

void xmls_init (void);
#ifdef OLD_VXML_TABLES
void xp_comp_init (void);
#endif

void ddl_init_xml (void);

#define ENTITY_MAX_ATTRS 200

void geo_node_input (text_node_t * txs, caddr_t * inst, caddr_t * state);
void txs_input (text_node_t * txs, caddr_t * inst, caddr_t *state);
void txs_free (text_node_t * txs);
void xn_input (xpath_node_t * xn, caddr_t * inst, caddr_t *state);
caddr_t txs_xn_text_query (text_node_t * txs, query_instance_t * qi, caddr_t xp_str);

#endif /* _XMLNODE_H */

