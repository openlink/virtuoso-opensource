/*
 *  widd.h
 *
 *  $Id$
 *
 *  Data Dictionary
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

#ifndef _WIDD_H
#define _WIDD_H

#include "Dk.h"

#define MAX_NAME_LEN		100
#define MAX_QUAL_NAME_LEN	310
#define TB_MAX_COLS		301
#define VDB_TB_MAX_COLS		2001

/*
 *  GRANTS flags
 */
#define GR_SELECT	0x0001
#define GR_UPDATE	0x0002
#define GR_INSERT	0x0004
#define GR_DELETE	0x0008
#define GR_GRANT	0x0010  /* 'with grant option' */
#define GR_EXECUTE	0x0020
#define GR_REFERENCES	0x0040
#define GR_REXECUTE	0x0080
#define GR_UDT_UNDER	0x0100

/* Sequence number, object id */
typedef uptrlong oid_t;	/* must be size of pointer */

typedef unsigned int key_id_t;
typedef unsigned char row_ver_t; /* the bit mask for what is on the row and what is an offset to another row */
typedef unsigned char key_ver_t; /* index into the bd_tree's key's key_bersions */
typedef unsigned short row_size_t;

typedef struct dbe_schema_s	dbe_schema_t;
typedef struct dbe_table_s	dbe_table_t;
typedef struct dbe_column_s	dbe_column_t;
typedef struct dbe_key_s	dbe_key_t;
typedef struct dbe_col_loc_s dbe_col_loc_t;
typedef struct dbe_storage_s dbe_storage_t;
typedef struct wi_db_s wi_db_t;

typedef enum { sc_to_table = 0, sc_to_proc = 1, sc_to_module = 2, sc_to_type = 3 } sc_object_type;

struct dbe_schema_s
  {
    struct dbe_schema_s *sc_prev;
    dk_hash_t *		sc_id_to_key;
    dk_hash_t *		sc_key_subkey;
    dk_hash_t *		sc_id_to_col;
    long		sc_free_since; /* msec real time when became unreferenced*/
    dk_hash_t *		sc_id_to_type;
#if defined (PURIFY) || defined (VALGRIND)
    dk_set_t		sc_old_views;
    dk_set_t		sc_old_types;
#endif
    id_hash_t *		sc_name_to_object[4];
  };


#define sch_id_to_col(sc, id) \
  ((dbe_column_t *) gethash (DP_ADDR2VOID (id), sc->sc_id_to_col))


extern dk_mutex_t * db_schema_mtx; /* global schema hash tables */

#define DBE_NO_STAT_DATA	-1
#define TB_RLS_U	0
#define TB_RLS_I	1
#define TB_RLS_D	2
#define TB_RLS_S	3
#define TB_RLS_LAST	TB_RLS_S

#define TB_RLS_OP_TO_INX(op) \
	((op) == 'S' ? TB_RLS_S : \
	 ((op) == 'I' ? TB_RLS_I : \
	  ((op) == 'U' ? TB_RLS_U : \
	   ((op) == 'D' ? TB_RLS_D : GPF_T1 ("invalid op")))))


struct dbe_table_s
  {
    char *		tb_name; /* qualifier.owner.name */
    char *		tb_name_only; /* point in the middle of tb_name, after owner */
    char *		tb_qualifier;
    char *		tb_owner;
    char *		tb_qualifier_name;
    id_hash_t *		tb_name_to_col;
    dbe_key_t *		tb_primary_key;
    dk_set_t		tb_keys;
    dk_set_t		tb_old_keys;
    dk_set_t		tb_cols;
    dbe_schema_t *	tb_schema;
    struct triggers_s *	tb_triggers;
    dk_hash_t *		tb_grants;
    oid_t		tb_owner_col_id;
    char		tb_any_blobs;
    char		tb_is_rdf_quad;
    struct remote_ds_s *tb_remote_ds;
    caddr_t		tb_remote_name;
    dk_hash_t *		tb_misc_id_to_col_id;
    dk_hash_t *		tb_col_id_to_misc_id;
    struct xml_table_ins_s *	tb_xml_ins;
    dbe_key_t *	tb__text_key;

    /* SQL statistics members */
    int64                tb_count;
    int64	tb_count_estimate;
    double	tb_geo_area;
    int64		tb_count_delta;

    /* row level security functions */
    caddr_t		tb_rls_procs[TB_RLS_LAST + 1];
  };

typedef struct collation_s
  {
    caddr_t	co_name;
    caddr_t	co_table;
    char	co_is_wide;
  } collation_t;

struct sql_class_s;
struct sql_domain_s;
typedef struct sql_type_s
  {
    collation_t *sqt_collation;
    uint32	sqt_precision;
    dtp_t	sqt_dtp;
    dtp_t	sqt_col_dtp; /* in column wise index, dtp is varchar for the leaf row col but the content dtp is sqt_col_dtp */
    char	sqt_scale;
    char		sqt_non_null;
    char		sqt_is_xml;
    struct sql_class_s *   sqt_class;
    caddr_t *		sqt_tree;
  } sql_type_t;

typedef struct cl_host_s cl_host_t;

typedef struct col_partition_s
{
  oid_t	cp_col_id;
  sql_type_t	cp_sqt;
  short	cp_shift; /* shift so many bits down before hash */
  char		cp_type;
  int64	cp_mask; /* after shift, and with this */
  int		cp_n_first; /* for a string, use so many leading chars */
} col_partition_t;

/* for cp_type */
#define CP_INT 1
#define CP_WORD 3


typedef unsigned short slice_id_t;
#define CL_MAX_SLICES (16 * 1024)
#define CL_ALL_SLICES 0xffff

typedef struct cl_host_group_s
{
  struct cluster_map_s *	chg_clm;
  cl_host_t **	chg_hosts;
  slice_id_t *	chg_slices;
  struct cl_slice_s **	chg_hosted_slices;
  char		chg_status; /* any slices in read only */
} cl_host_group_t;

#define CLM_INITIAL_SLICES 1024

/* cl_slice_status */
#define CL_SLICE_RW 0  /* read write */
#define CL_SLICE_LOG 1 /* read write but special logging on write */
#define CL_SLICE_RO 2 /* read only */

/* location of data based on hash */

typedef struct cl_slice_s cl_slice_t;

typedef struct cluster_map_s
{
  caddr_t	clm_name;
  short		clm_id;
  char		clm_is_modulo;
  char		clm_is_elastic;
  char		clm_init_slices;
  int		clm_distinct_slices; /* no of different slices */
  int	clm_n_slices; /* no of places in the clm_slice_map */
  int		clm_n_replicas;
  unsigned short *	clm_host_rank; /* indexed with host ch_id, gives the ordinal position of host in the host group it occupies in this map */
  char *		clm_slice_status;
  dk_hash_t *		clm_id_to_slice;
  cl_slice_t **	clm_slices; /* which physical slice contains the data for the place in slice map, if not elastic 1:1 to host groups  */
  cl_slice_t **	clm_phys_slices; /* distinct physical slices */
  cl_host_group_t **	clm_slice_map;
  cl_host_group_t **	clm_hosts;
  cl_host_group_t *	clm_local_chg;
  uint64 *		clm_slice_req_count;  /* per logical slice count  of  requests from this host */
  char		clm_any_in_transfer; /* true if logging should check whether an extra log entry is needed due to updating a slice being relocated.  True is any in cl_slice_status is CL_CLICE_LOG.  */
  dk_mutex_t	clm_mtx; /* slice thread counts and slice status */
} cluster_map_t;

#define CLM_REQ(clm, sl)  clm->clm_slice_req_count[(uint32)sl % clm->clm_n_slices]++

#define CLM_ID_TO_CSL(clm, slid) \
  (cl_slice_t*)gethash ((void*)(ptrlong)(slid), clm->clm_id_to_slice)
#define MAX_PART_COLS 4

typedef struct key_partition_def_s
{
  cluster_map_t *	kpd_map;
  col_partition_t **	kpd_cols;
} key_partition_def_t;


extern cluster_map_t * clm_replicated;


typedef struct col_stat_s
{
  id_hash_t *	cs_distinct;
  int64		cs_len;
  int64		cs_n_values;
} col_stat_t;

/* fields in int64 in cs_distinct counting repeats of a value */
#define CS_IN_SAMPLE 0x8000000000000000
#define CS_SAMPLE_INC 0x1000000000000
#define CS_N_SAMPLES(n) (0x7fff & ((int64)(n) >> 48))
#define CS_N_VALUES(n) ((int64)(n) & 0xffffffffffff)


struct dbe_column_s
  {
    char *		col_name;
    oid_t		col_id;
    caddr_t		col_default;
    char *		col_check;
    dk_hash_t *		col_grants;
    char		col_is_key_part;
    int			col_is_autoincrement;
    dbe_table_t *	col_defined_in;
    sql_type_t		col_sqt;
    char		col_compression;
    char		col_is_misc;
    char		col_is_misc_cont; /* true for a misc container, e.g. E_MISC of VXML_ENTITY */
    char		col_is_text_index;
    char		col_is_geo_index;
    index_tree_t *	col_it;
    caddr_t 		col_lang;
    caddr_t 		col_enc;
    dbe_column_t **	col_offband_cols;
    dbe_column_t **	col_constr_cols;
    caddr_t 		col_xml_base_uri;

    /* SQL statistics members */
    int64                col_count; /* non-null */
    int64                col_n_distinct; /* count of distinct */
    caddr_t *           col_hist;
    col_stat_t *	col_stat;
    caddr_t		col_min; /* min column value */
    caddr_t		col_max; /* max column value */
    caddr_t *		col_options; /* max column value */
    long		col_avg_len; /* average column length */
    long		col_avg_blob_len;
  };


#define col_precision col_sqt.sqt_precision
#define col_scale col_sqt.sqt_scale
#define col_non_null col_sqt.sqt_non_null
#define col_collation col_sqt.sqt_collation

/* col_is_key_part */
#define COL_KP_UNQ 100




#define N_COMPRESS_OFFSETS 5
#define N_ROW_VERSIONS 32
#define ROW_NO_MASK 0x0fff
#define COL_OFFSET_SHIFT 12
#define COL_VAR_LEN_MASK 0x3fff  /* and to get the var len field of a row length area entry */
#define COL_VAR_FLAGS_MASK 0xc000 /* and to get the var len flag  bits */
#define COL_VAR_SUFFIX 0x8000 /* bit set if this var len is a suffix of an earlier col in the same place */


/* values of cl_compress and col_compress, ret codes for try offset and try prefix */
#undef CC_NONE

#define CC_UNDEFD 0
#define CC_NONE 1
#define CC_OFFSET 2
#define CC_PREFIX 3
#define CC_LAST_BYTE 4


#define ROW_SET_NULL(row, cl, rv)		\
  row[cl->cl_null_flag[rv]] |= cl->cl_null_mask[rv]

#define ROW_CLR_NULL(row, cl, rv)		\
  row[cl->cl_null_flag[rv]] &= ~cl->cl_null_mask[rv]


struct dbe_col_loc_s
{
  oid_t		cl_col_id;
  sql_type_t	cl_sqt;
  row_ver_t	cl_row_version_mask; /* and with row version is true if this cl is compressed on that row. 0x00 if always on row */
  unsigned char	cl_compression:4;
  unsigned char	cl_comp_asc:1; /* look for left to right for compression */
  short		cl_nth;  /* 0 based ordinal pos in key in layout order */
  short		cl_fixed_len;
  short		cl_pos[N_ROW_VERSIONS];
  short	cl_null_flag[N_ROW_VERSIONS];
  dtp_t		cl_null_mask[N_ROW_VERSIONS];
};


#define CL_FIRST_VAR -1
#define CL_VAR -2

#define DO_CL_0(cl, cls) \
  { int __inx; \
    for (__inx = 0; cls[__inx].cl_col_id; __inx++) {

#define DO_CL(cl, cls) \
  { int __inx; \
    for (__inx = 0; cls[__inx].cl_col_id; __inx++) { \
      dbe_col_loc_t * cl = &cls[__inx];

#define END_DO_CL } }

dbe_col_loc_t * key_next_list (dbe_key_t * key, dbe_col_loc_t * list);

#define DO_ALL_CL(cl, key) \
{\
  dbe_col_loc_t * __list;\
  for (__list = key->key_key_fixed; __list; __list = key_next_list (key, __list))\
    {\
      DO_CL (cl, __list)


#define END_DO_ALL_CL  END_DO_CL; } }


typedef struct dbe_key_frag_s
{
  caddr_t *	kf_start;  /* key part values <= values accepted in this frag. NULL for first */
  db_buf_t 	kf_start_row;	/* same in leaf pointer row layout */
  dbe_storage_t *	kf_storage;
  caddr_t	kf_name;  /* root is in main registry under this name */
  struct index_tree_s *	kf_it;
  char			kf_all_in_em; /*true if all pages are in the extent map and none in the system general em */
} dbe_key_frag_t;


typedef struct key_spec_s
{
  struct search_spec_s * 	ksp_spec_array;
  int (*ksp_key_cmp) (struct buffer_desc_s * buf, int pos, struct it_cursor_s * itc);
} key_spec_t;


#define ITC_KEY_INC(itc, dm) if (itc->itc_insert_key) itc->itc_insert_key->dm++;


#define KEY_MAX_VERSIONS KV_LONG_GAP  /* lowest special purpose kv number */
#define KEY_VERSION_OVERFLOW -1

#define KEY_PRIMARY 1
#define KEY_PRIMARY_ORDER 2 /* starts with pk, more columns as dependent */

struct dbe_key_s
{
  char *		key_name;
  key_id_t		key_id;
  dbe_table_t *	key_table;
  dk_set_t		key_parts;

  int			key_n_significant;
  int			key_decl_parts;
  unsigned short	key_geo_srcode;
  char			key_is_primary;
  char			key_is_unique;
  char			key_is_temp;
  char			key_is_bitmap;
  char			key_simple_compress;
  key_ver_t		key_version;
  char			key_is_geo;
  char			key_is_col; /* column-wise layout */
  char		key_no_pk_ref; /* the key does not ref the main row */
  char		key_distinct; /* if no pk ref, do not put duplicates */
  char		key_not_null; /* if a significant key part is nullable and null, do not make an index entry */
  char		key_no_compression; /* no key part is compressed in any version of key*/
  char		key_is_dropped;
  char		key_is_elastic; /* key_storage->dbs_type == DBS_ELASTIC */
  key_id_t		key_migrate_to;
  key_id_t		key_super_id;
  dbe_key_t **		key_versions;
  dk_set_t		key_supers;
  key_partition_def_t *	key_partition;
  dbe_col_loc_t *	key_bm_cl; /* the var length string where the bits are, dependent part of a bitmap inx */
  dbe_col_loc_t *	key_bit_cl; /* for a bitmap inx, the last key part, the int or int64 that is the bit bitmap start */
  /* access inx */
  int64		key_touch;
  int64		key_read;
  int64		key_write;
  int64		key_lock_wait;
  int64		key_lock_wait_time;
  int64		key_deadlocks;
  int64		key_lock_set;
  int64		key_lock_escalations;
  int64		key_page_end_inserts;
  int64		key_write_wait;
  int64		key_read_wait;
  int64		key_landing_wait;
  int64		key_pl_wait;
  int64		key_ac_in;
  int64		key_ac_out;
  dp_addr_t		key_last_page;
  char		key_is_last_right_edge;
  int64		key_n_last_page_hits;
  int64		key_total_last_page_hits;
  int64		key_n_landings;

  key_spec_t 		key_insert_spec;
  key_spec_t		key_bm_ins_spec;
  key_spec_t		key_bm_ins_leading;
  dk_set_t		key_visible_parts; /* parts in create table order, only if primary key */
  struct query_s *	key_ins_qr; /* in cluster, local only qrs for ins/ins/ soft/del of key, pars in layout order */
  struct query_s *	key_ins_soft_qr;
  struct query_s *	key_del_qr;


  /* free text */
  dbe_table_t *	key_text_table;
  dbe_table_t *	key_geo_table;
  dbe_column_t *	key_text_col;

  /* row layout */
  short *		key_part_in_layout_order; /* this is for each significant, the index in the order of layout: kf kv */
  dbe_col_loc_t **	key_part_cls; /* cl's in key part order */
  dk_set_t		key_key_compressibles; /* compressible cls on leaf ptr */
  dk_set_t		key_row_compressibles; /* compressible cls on row */
  dk_set_t		key_key_pref_compressibles; /* prefix compressible cls on leaf ptr */
  dk_set_t		key_row_pref_compressibles; /* prefix compressible cls on row */
  dbe_col_loc_t *	key_key_fixed;
  dbe_col_loc_t *	key_key_var;
  dbe_col_loc_t *	key_row_fixed;
  dbe_col_loc_t *	key_row_var;
  short		key_n_parts;
  short		key_n_key_compressibles;
  short		key_n_row_compressibles;
  short		key_length_area[N_ROW_VERSIONS]; /* if key/row have variable length, the offset of the first length word */
  short		key_key_leaf[N_ROW_VERSIONS];
  short		key_row_compressed_start[N_ROW_VERSIONS]; /* compress offsets of non-key offset compressibles */
  short		key_key_var_start[N_ROW_VERSIONS];	/* offset of first var on leaf ptr */
  short		key_row_var_start[N_ROW_VERSIONS];	/* offset of first var on leaf row */
  short		key_null_flag_start[N_ROW_VERSIONS];
  short		key_null_flag_bytes[N_ROW_VERSIONS];
  short		key_key_len[N_ROW_VERSIONS];	/* if positive, the fixed length.  If neg the -position of the 2 byte len from start of leaf ptr */
  short		key_row_len[N_ROW_VERSIONS];  /* if positive, the fixed length.  If neg the -position of the 2 byte len from start of row */

/* Note that key_insert() in row.c contains code that will not work when keys
with multiple fragments are implemented, because It will always use the first
fragment instead of searching for the the fragment actually needed. */
  dbe_key_frag_t **	key_fragments;
  int		key_n_fragments;
  dbe_storage_t *	key_storage;
  caddr_t *	key_options;
  uint32	key_segs_sampled;
  uint32	key_rows_in_sampled_segs;
  id_hash_t *	key_p_stat; /* for rdf inx starting with p, stats on the rest for a given p */
  int64		key_count; /* if distinct proj, count is not the table count */
};


#define KEY_INSERT_SPEC(key) \
  key->key_insert_spec

#define KEY_TOUCH(k)	k->key_touch ++;


#define ITC_MARK_READ(it) \
{ \
  client_connection_t * cli; \
  dbe_key_t * k1 = it->itc_insert_key; \
  it->itc_read_waits += 10000; \
  if (k1) \
    k1->key_read++; \
  if (itc->itc_ltrx && itc->itc_ltrx->lt_client) itc->itc_ltrx->lt_client->cli_activity.da_disk_reads++; else if ((cli = sqlc_client ())) cli->cli_activity.da_disk_reads++; \
}

#define ITC_MARK_LOCK_WAIT(it, t) \
{ \
  dbe_key_t *k1 = it->itc_insert_key; \
  uint32 delay = get_msec_real_time () - t; \
  if (k1) \
    { \
      k1->key_lock_wait++; \
      k1->key_lock_wait_time += delay; \
    } \
  lock_wait_msec += delay; \
  it->itc_ltrx->lt_client->cli_activity.da_lock_wait_msec += delay; \
  it->itc_ltrx->lt_client->cli_activity.da_lock_waits++; \
}

#define ITC_MARK_DEADLOCK(it) \
{ \
  dbe_key_t *k1 = it->itc_insert_key; \
  if (k1) \
    k1->key_deadlocks++; \
}

#define ITC_MARK_LOCK_SET(it) \
{ \
  dbe_key_t *k1 = it->itc_insert_key; \
  if (k1) \
    k1->key_lock_set++; \
}


#define ITC_MARK_LANDED(itc) \
{ \
  if (itc->itc_insert_key) itc->itc_insert_key->key_n_landings++; \
  if (itc->itc_ltrx && itc->itc_ltrx->lt_client) itc->itc_ltrx->lt_client->cli_activity.da_random_rows++; \
}


#define ITC_MARK_LANDED_NC(itc) \
{ \
  itc->itc_insert_key->key_n_landings++; \
  itc->itc_ltrx->lt_client->cli_activity.da_random_rows++; \
}

#define ITC_MARK_DIRTY(itc) \
  if (itc->itc_insert_key) itc->itc_insert_key->key_n_dirty++

#define ITC_MARK_NEW(itc) \
  if (itc->itc_insert_key) itc->itc_insert_key->key_n_new++

#define ITC_MARK_ROW(itc) \
  {if (itc->itc_ltrx) itc->itc_ltrx->lt_client->cli_activity.da_seq_rows++;}

#define KEY_DECLARED_PARTS(k) \
  (k->key_decl_parts ? k->key_decl_parts : k->key_n_significant)

#define NAME_SEPARATOR '.'


typedef struct triggers_s
  {
    dk_set_t		trig_list;
  } triggers_t;



/*
   System tables, columns and keys.
*/

/*
  SYS_COLS:   TABLE, COL > ID
  SYS_COL_DEFS:  ID> DTP, ....
  SYS_KEYS:  TABLE, KEY > KEY_ID, N_SIGNIFICANT, CLUSTER_ON_ID
  SYS_KEY_PARTS:   KEY_ID, N > COL_ID

  For each table:
    Name, Key ID, ID's of cols

  TN_<table name>
  KI_<table name>
  CI_<tbl>_<col>
  CN_<tbl><col>
*/


/*
create_table SYS_COLS (TABLE COLUMN COL_ID COL_DTP)
create_unique_nidex SYS_COLS on SYS_COLS (COL_ID)
create_index SYS_COLS_BY_NAME on SYS_COLS (TABLE COLUMN)

create_table SYS_KEYS (KEY_TABLE KEY_NAME KEY_ID KEY_N_SIGNIFICANT
        KEY_CLUSTER_ON_ID KEY_IS_MAIN KEY_IS_OBJECT_ID
        KEY_IS_UNIQUE KEY_MIGRATE_TO)
create_unique_index SYS_KEYS on SYS_KEYS (KEY_TABLE KEY_NAME)
create_index SYS_KEYS_BY_ID on SYS_KEYS (KEY_ID)

create_table SYS_KEY_PARTS (KP_KEY_ID KP_NTH KP_COL)
create_unique_index SYS_KEY_PARTS on SYS_KEY_PARTS (KP_KEY_ID KP_NTH)
*/

#define TN_COLS			"DB.DBA.SYS_COLS"
#define TN_KEYS			"DB.DBA.SYS_KEYS"
#define TN_KEY_PARTS		"DB.DBA.SYS_KEY_PARTS"
#define TN_COLLATIONS		"DB.DBA.SYS_COLLATIONS"
#define TN_CHARSETS		"DB.DBA.SYS_CHARSETS"
#define TN_SUB                  "DB.DBA.SYS_KEY_SUBKEY"
#define TN_FRAGS                "DB.DBA.SYS_KEY_FRAGMENTS"
#define TN_UDT                  "DB.DBA.SYS_USER_TYPES"


#define KI_COLS			1
#define KI_COLS_ID		2
#define KI_KEYS			3
#define KI_KEYS_ID		21
#define KI_KEY_PARTS		4

#define KI_OBJECT_ID		5
#define KI_COLLATIONS		6
#define KI_CHARSETS		7
#define KV_LEAF_PTR 0
#define KV_LEFT_DUMMY           127
#define KI_SUB                  9
#define KV_GAP 126  /* on page layout, the next byte is 8 bit length of free space from KV_GAP */
#define KV_LONG_GAP 125 /* on page layout, 2 next bytes are the length of free space, from DV_LONG_GAP */
#define MAX_KV_GAP_BYTES 3 /* longest gap marker len */
#define KI_FRAGS                10
#define KI_UDT                  11

#define KI_SORT_TEMP		22
#define KI_DISTINCT		23

#define KI_IS_TEMP(k_id) (k_id >= 22 && k_id <= 199)

#define CI_COLS_TBL		1
#define CI_COLS_COL		2
#define CI_COLS_COL_ID		3
#define CI_COLS_DTP		5
#define CI_COLS_PREC		22
#define CI_COLS_SCALE		23
#define CI_COLS_DEFAULT		24
#define CI_COLS_CHECK		25
#define CI_COLS_NULLABLE	26
#define CI_COLS_NTH		27
#define CI_COLS_OPTIONS 43

#define CI_KEYS_TBL		6
#define CI_KEYS_KEY		7
#define CI_KEYS_ID		8
#define CI_KEYS_SIGNIFICANT	9
#define CI_KEYS_CLUSTER_ON_ID	10
#define CI_KEYS_IS_MAIN		14
#define CI_KEYS_IS_OBJECT_ID	16
#define CI_KEYS_IS_UNIQUE	17
#define CI_KEYS_MIGRATE_TO	19
#define CI_KEYS_SUPER_ID	20
#define CI_KEYS_DECL_PARTS	21
#define CI_KEYS_STORAGE 36
#define CI_KEYS_OPTIONS 37
#define CI_KEYS_VERSION 49
#define CI_KPARTS_ID		11
#define CI_KPARTS_N		12
#define CI_KPARTS_COL_ID	13

#define CI_COLLATIONS_NAME	28
#define CI_COLLATIONS_WIDE	29
#define CI_COLLATIONS_TABLE	30

#define CI_CHARSET_NAME		31
#define CI_CHARSET_TABLE	32
#define CI_CHARSET_ALIASES	33
#define CI_SUB_SUPER 34
#define CI_SUB_SUB 35

#define CI_FRAGS_KEY 38
#define CI_FRAGS_NO 39
#define CI_FRAGS_START 40
#define CI_FRAGS_STORAGE 41
#define CI_FRAGS_SERVER 42

#define CI_UDT_NAME		44
#define CI_UDT_PARSE_TREE	45
#define CI_UDT_ID		46
#define CI_UDT_MIGRATE_TO	47

#define CI_BITMAP 48 /*invisible string col at the end of a bitmap inx leaf.  One shared among all. &*/

#define CN_COLS_TBL		"TABLE"
#define CN_COLS_COL		"COLUMN"
#define CN_COLS_COL_ID		"COL_ID"
#define CN_COLS_DTP		"COL_DTP"
#define CN_COLS_PREC		"COL_PREC"
#define CN_COLS_SCALE		"COL_SCALE"
#define CN_COLS_DEFAULT		"COL_DEFAULT"
#define CN_COLS_CHECK		"COL_CHECK"
#define CN_COLS_NULLABLE	"COL_NULLABLE"
#define CN_COLS_NTH		"COL_NTH"
#define CN_COLS_OPTIONS "COL_OPTIONS"

#define CN_KEYS_TBL		"KEY_TABLE"
#define CN_KEYS_KEY		"KEY_NAME"
#define CN_KEYS_ID		"KEY_ID"
#define CN_KEYS_SIGNIFICANT	"KEY_N_SIGNIFICANT"
#define CN_KEYS_CLUSTER_ON_ID	"KEY_CLUSTER_ON_ID"
#define CN_KEYS_IS_MAIN		"KEY_IS_MAIN"
#define CN_KEYS_IS_OBJECT_ID	"KEY_IS_OBJECT_ID"
#define CN_KEYS_IS_UNIQUE	"KEY_IS_UNIQUE"
#define CN_KEYS_MIGRATE_TO	"KEY_MIGRATE_TO"
#define CN_KEYS_SUPER_ID	"KEY_SUPER_ID"
#define CN_KEYS_DECL_PARTS	"KEY_DECL_PARTS"
#define CN_KEYS_STORAGE "KEY_STORAGE"
#define CN_KEYS_OPTIONS "KEY_OPTIONS"
#define CN_KEYS_VERSION "KEY_VERSION"


#define CN_KPARTS_ID		"KP_KEY_ID"
#define CN_KPARTS_N		"KP_NTH"
#define CN_KPARTS_COL_ID	"KP_COL"

#define CN_COLLATIONS_NAME	"COLL_NAME"
#define CN_COLLATIONS_TABLE	"COLL_TABLE"
#define CN_COLLATIONS_WIDE	"COLL_WIDE"

#define CN_CHARSET_NAME		"CS_NAME"
#define CN_CHARSET_TABLE	"CS_TABLE"
#define CN_CHARSET_ALIASES	"CS_ALIASES"
#define CN_SUB_SUPER  "SUPER"
#define CN_SUB_SUB "SUB"


#define CN_FRAGS_KEY "FRAG_KEY"
#define CN_FRAGS_NO "FRAG_NO"
#define CN_FRAGS_START "FRAG_START"
#define CN_FRAGS_STORAGE "FRAG_STORAGE"
#define CN_FRAGS_SERVER "FRAG_SERVER"


#define CN_UDT_NAME "UT_NAME"
#define CN_UDT_PARSE_TREE  "UT_PARSE_TREE"
#define CN_UDT_ID  "UT_ID"
#define CN_UDT_MIGRATE_TO  "UT_MIGRATE_TO"


/* Special ID's */

#define CI_INDEX		197
#define CI_ANY			198
#define CI_ROW			199

#define DD_FIRST_PRIVATE_OID	200
#define DD_FIRST_FREE_OID	1000

#define KI_TEMP 0xffff
/* marks query temp keys */

struct search_spec_s * dbe_key_insert_spec (dbe_key_t * key);

dbe_schema_t * dbe_schema_create (dbe_schema_t *sc);
void sch_create_meta_seed (dbe_schema_t * sc, dbe_schema_t * prev_sc);

void dbe_schema_free (dbe_schema_t * sc);
dbe_table_t * dbe_table_create (dbe_schema_t * sc, const char * name);
dbe_column_t * dbe_column_add (dbe_table_t * tb, const char * name, oid_t id,
    dtp_t dtp);

dbe_key_t * dbe_key_create (dbe_schema_t * sc, dbe_table_t * tb, const char * name,
    key_id_t id, int n_significant, int cluster_on_id, int is_main,
    key_id_t migrate_to, key_id_t super_id);

dbe_key_t * tb_text_key (dbe_table_t *tb);

void key_add_part (dbe_key_t * key, oid_t col);
void sqt_max_desc (sql_type_t * res, sql_type_t * arg);
int dbe_cols_are_valid (db_buf_t row, dbe_key_t * key, int throw_error);

#endif


