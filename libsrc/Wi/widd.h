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

#ifndef _WIDD_H
#define _WIDD_H

#include "Dk.h"

#define MAX_NAME_LEN		100
#define MAX_QUAL_NAME_LEN	310
#define TB_MAX_COLS		201
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
typedef uptrlong oid_t;	/* really 32 bit, but the code is too buggy */

typedef unsigned short key_id_t;

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
#define IN_SCHEMA mutex_enter (db_schema_mtx)
#define LEAVE_SCHEMA mutex_enter (db_schema_mtx)

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
    dk_hash_t *		tb_id_to_col;
    dbe_key_t *		tb_primary_key;
    dk_set_t		tb_keys;
    dk_set_t		tb_old_keys;
    dk_set_t		tb_cols;
    dbe_schema_t *	tb_schema;
    struct triggers_s *	tb_triggers;
    dk_hash_t *		tb_grants;
    oid_t		tb_owner_col_id;
    char		tb_any_blobs;
    struct remote_ds_s *tb_remote_ds;
    caddr_t		tb_remote_name;
    dk_hash_t *		tb_misc_id_to_col_id;
    dk_hash_t *		tb_col_id_to_misc_id;
    struct xml_table_ins_s *	tb_xml_ins;
    dbe_key_t *	tb__text_key;

    /* SQL statistics members */
    int64                tb_count;
    int64	tb_count_estimate;
    int			tb_count_delta;

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
    char	sqt_scale;
    char		sqt_non_null;
    char		sqt_is_xml;
    struct sql_class_s *   sqt_class;
    caddr_t *		sqt_tree;
  } sql_type_t;



typedef struct col_stat_s 
{
  id_hash_t *	cs_distinct;
  int64		cs_len;
  int64		cs_n_values;
} col_stat_t;


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

    char		col_is_misc;
    char		col_is_misc_cont; /* true for a misc container, e.g. E_MISC of VXML_ENTITY */
    char		col_is_text_index;
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

struct dbe_col_loc_s
{
  oid_t		cl_col_id;
  sql_type_t	cl_sqt;
  short		cl_fixed_len;
  short		cl_pos;
  short	cl_null_flag;
  dtp_t		cl_null_mask;
};


#define CL_FIRST_VAR -1
#define CL_VAR -2

typedef struct dbe_key_frag_s
{
  caddr_t *	kf_start;  /* key part values <= values accepted in this frag. NULL for first */
  db_buf_t 	kf_start_row;	/* same in leaf pointer row layout */
  dbe_storage_t *	kf_storage;
  caddr_t	kf_name;  /* root is in main registry under this name */
  struct index_tree_s *	kf_it;
} dbe_key_frag_t;


typedef struct key_spec_s 
{
  struct search_spec_s * 	ksp_spec_array;
  int (*ksp_key_cmp) (struct buffer_desc_s * buf, int pos, struct it_cursor_s * itc);
} key_spec_t;


#define ITC_KEY_INC(itc, dm) if (itc->itc_insert_key) itc->itc_insert_key->dm++;


struct dbe_key_s
{
  char *		key_name;
  key_id_t		key_id;
  dbe_table_t *	key_table;
  int			key_n_parts;
  dk_set_t		key_parts;

  int			key_n_significant;
  int			key_decl_parts;
  char			key_is_primary;
  char			key_is_unique;
  char			key_is_temp;
  char			key_is_bitmap;
  key_id_t		key_migrate_to;
  key_id_t		key_super_id;
  dk_set_t		key_supers;
  dbe_col_loc_t *	key_bm_cl; /* the var length string where the bits are, dependent part of a bitmap inx */
  dbe_col_loc_t *	key_bit_cl; /* for a bitmap inx, the last key part, the int or int64 that is the bit bitmap start */
  /* access inx */
    long		key_touch;
  long		key_read;
  long		key_lock_wait;
  long		key_lock_wait_time;
  long		key_deadlocks;
  long		key_lock_set;
  long		key_lock_escalations;
  long		key_page_end_inserts;
  long		key_write_wait;
  long		key_read_wait;
  long		key_landing_wait;
  long		key_pl_wait;

  dp_addr_t		key_last_page;
  char		key_is_last_right_edge;
  long		key_n_last_page_hits;
  long		key_total_last_page_hits;
  long		key_n_landings;
  long		key_n_dirty;
  long		key_n_new;

  key_spec_t 		key_insert_spec;
  key_spec_t		key_bm_ins_spec;
  key_spec_t		key_bm_ins_leading;
  dk_set_t		key_visible_parts; /* parts in create table order, only if primary key */

  /* free text */
  dbe_table_t *	key_text_table;
  dbe_column_t *	key_text_col;

  /* row layout */
  dbe_col_loc_t *	key_key_fixed;
  dbe_col_loc_t *	key_key_var;
  dbe_col_loc_t *	key_row_fixed;
  dbe_col_loc_t *	key_row_var;
  short		key_key_n_vars;	/* count of vars on leaf ptr */
  short		key_row_n_vars;	/* count of vars on leaf */
  short		key_length_area; /* if key/row have variable length, the offset of the first length word */
  short		key_key_var_start;	/* offset of first var on leaf ptr */
  short		key_row_var_start;	/* offset of first var on leaf row */
  short		key_null_flag_start;
  short		key_null_flag_bytes;
  short		key_key_len;	/* if positive, the fixed length.  If neg the -position of the 2 byte len from start of leaf ptr */
  short		key_row_len;  /* if positive, the fixed length.  If neg the -position of the 2 byte len from start of row */

/* Note that key_insert() in row.c contains code that will not work when keys
with multiple fragments are implemented, because It will always use the first
fragment instead of searching for the the fragment actually needed. */
  dbe_key_frag_t **	key_fragments;
  int		key_n_fragments;
  dbe_storage_t *	key_storage;
  caddr_t *	key_options;
};


#define KEY_INSERT_SPEC(key) \
  key->key_insert_spec

#define KEY_TOUCH(k)	k->key_touch ++;


#define ITC_MARK_READ(it) \
{ \
  dbe_key_t * k1 = it->itc_insert_key; \
  if (k1) \
    k1->key_read++; \
}

#define ITC_MARK_LOCK_WAIT(it, t) \
{ \
  dbe_key_t *k1 = it->itc_insert_key; \
  if (k1) \
    { \
      k1->key_lock_wait++; \
      k1->key_lock_wait_time += get_msec_real_time () - t; \
    } \
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
  if (itc->itc_insert_key) itc->itc_insert_key->key_n_landings++

#define ITC_MARK_DIRTY(itc) \
  if (itc->itc_insert_key) itc->itc_insert_key->key_n_dirty++

#define ITC_MARK_NEW(itc) \
  if (itc->itc_insert_key) itc->itc_insert_key->key_n_new++


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
#define KI_LEFT_DUMMY           8
#define KI_SUB                  9
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


