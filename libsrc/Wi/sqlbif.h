/*
 *  sqlbif.h
 *
 *  $Id$
 *
 *  SQL Built In Functions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

#ifndef _SQLBIF_H
#define _SQLBIF_H

#include "sqlnode.h"

typedef void (*bif_type_func_t) (state_slot_t ** args, long *dtp, long *prec,
				 long *scale, caddr_t *collation, long * non_null);

typedef struct
  {
    bif_type_func_t	bt_func;
    long		bt_dtp;
    long		bt_prec;
    long		bt_scale;
    long		bt_non_null;
    const char *	bt_sql_dml_name;
  } bif_type_t;

#define is_some_sort_of_an_integer(T)\
 ((DV_SHORT_INT == (T)) || (DV_LONG_INT == (T)) ||\
  (DV_CHARACTER == (T)) || (DV_C_SHORT == (T)) || (DV_C_INT == (T)))

#define is_some_sort_of_a_string(T)\
 (((T) == DV_SHORT_STRING) || ((T) == DV_LONG_STRING))
void sql_bif_init (void);

#define BIF_OPT_SIMPLIFY	1	/*!< The function-specific optimizer gets compiler as context, pointer to a tree made by parser (and, incase of SPARQL, enriched with at least equivalence classes), returns the pointer to the unchanged or patched tree */
#define BIF_OPT_RET_TYPE	2	/*!< The optimizer gets compiler as context, pointer to a tree made by SQL parser, return NULL, improves data under \c more taht is a pointer to bif_type_t (SQL) or rdf_val_range_t (SPARQL) */

typedef struct bif_metadata_s *bif_metadata_ptr_t;
typedef struct sql_comp_s *sql_comp_ptr_t;
typedef struct sparp_s *sparp_ptr_t;

typedef struct sql_tree_s *bif_sql_optimizer_t (sql_comp_ptr_t sqlc, int bif_opt_opcode, struct sql_tree_s *tree, bif_metadata_ptr_t bmd, void *more);
/*! Type of SPARQL expression optimization callback function.

The function gets the context, the opcode, the funcall tree to analyze/optimize, and the bif metadata in use.
if \c bif_opt_opcode is BIF_OPT_SIMPLIFY then the function returns an expression tree that is either the original \c tree,
or a simplified expression that returns same result.
If the expression is simplified, the returned pointer must differ from \c tree, it is not allowed to replace a part of the call without copying the top.
if \c bif_opt_opcode is case BIF_OPT_RET_TYPE then the function fills in and rdf_val_range_t * of expected return value that is passed as \c more argument. */
typedef struct spar_tree_s *bif_sparql_optimizer_t (sparp_ptr_t sparp, int bif_opt_opcode, struct spar_tree_s *tree, bif_metadata_ptr_t bmd, void *more);

#define BMD_DONE			12053	/*!< The value in arglist of bif_define_ex that indicates the end of arglist */
#define BMD_ALIAS			1	/*!< An additional (alias) name of a function */
#define BMD_VECTOR_IMPL			2	/*!< Flags that the BIF has a vectored variant, the pointer to the vectored implementation is the value */
#define BMD_SQL_OPTIMIZER_IMPL		3	/*!< Flags that the BIF has a special optimizer, the pointer to the function is the value */
#define BMD_SPARQL_OPTIMIZER_IMPL	4	/*!< Flags that the BIF has a special optimizer, the pointer to the function is the value */
#define BMD_RET_TYPE			5	/*!< The return type is fixed and equal to the specified value */
#define BMD_MIN_ARGCOUNT		6	/*!< Minimal valid number of arguments, the value is plain integer, not a ptrlong */
#define BMD_ARGCOUNT_INC		7	/*!< if the function gets more than minimal number of args, additional arguments comes in group os specified size. The value is plain integer, not a ptrlong */
#define BMD_MAX_ARGCOUNT		8	/*!< Maximal valid number of arguments, the value is plain integer, not a ptrlong */
#define BMD_IS_AGGREGATE		9	/*!< Flags that the function is aggragate, no associated value */
#define BMD_IS_PURE			10	/*!< Flags that the function is pure, no associated value */
#define BMD_IS_DBA_ONLY			11	/*!< Flags that the function is for DBA only, no associated value */
#define BMD_USES_INDEX			12	/*!< Flags that the function uses at least some index, no associated value */
#define BMD_SPARQL_ONLY			13	/*!< Flag for a special name that looks like a function name in SPARQL front-end, but not a BIF in the generated SQL. The value should be the last one because it does not correspond to any field of \c bif_metadata_t */
#define BMD_NO_CLUSTER			14	/*!< Flags that the function is not cluster friendly and can not be relocated from node to node without the change in semantics, no associated value */
#define BMD_OUT_OF_PARTITION		15	/*!< Flags that the function makes a cross partition cluster operation */
#define BMD_NEED_ENLIST			16	/*!< Flags that the query should get \c qr_need_enlist set to 1 if it contains any call of this function */
#define COUNTOF__BMD_OPTIONs		17

/*! \brief Metadata about single BIF or similar object.
These metadata are created once, remains constant after the creation and never deleted.
If a metadata record describes BIF that was loaeded from a plugin and later unloaded then at the unload time it can be deleted from
\c name_to_bif_metadata_idhash and \c bif_to_bif_metadata_hash but it should remain in memory. */
typedef struct bif_metadata_s {
  const char *			bmd_name;
  bif_t				bmd_main_impl;
  dk_set_t			bmd_aliases;			/*!< see \c BMD_ALIAS */
  bif_vec_t			bmd_vector_impl;		/*!< see \c BMD_VECTOR_IMPL */
  bif_sql_optimizer_t *		bmd_sql_optimizer_impl;		/*!< see \c BMD_SQL_OPTIMIZER_IMPL */
  bif_sparql_optimizer_t *	bmd_sparql_optimizer_impl;	/*!< see \c BMD_SPARQL_OPTIMIZER_IMPL */
  bif_type_t *			bmd_ret_type;			/*!< see \c BMD_RET_TYPE */
  ptrlong			bmd_min_argcount;		/*!< see \c BMD_MIN_ARGCOUNT */
  ptrlong			bmd_argcount_inc;		/*!< see \c BMD_ARGCOUNT_INC */
  ptrlong			bmd_max_argcount;		/*!< see \c BMD_MAX_ARGCOUNT */
  ptrlong			bmd_is_aggregate;		/*!< see \c BMD_IS_AGGREGATE */
  ptrlong			bmd_is_pure;			/*!< see \c BMD_IS_PURE */
  ptrlong			bmd_is_dba_only;		/*!< see \c BMD_IS_DBA_ONLY */
  ptrlong			bmd_uses_index;			/*!< see \c BMD_USES_INDEX */
  ptrlong			bmd_no_cluster;			/*!< see \c BMD_NO_CLUSTER, \c BMD_OUT_OF_PARTITION and \c BMD_NEED_ENLIST */
} bif_metadata_t;

extern id_hash_t *name_to_bif_metadata_idhash;			/*!< Metadata of all known BIFs (except \c BMD_SPARQL_ONLY records); results of sqlp_box_id_upcase() as keys, pointers to \c bif_metadata_t as values */
extern dk_hash_t *bif_to_bif_metadata_hash;			/*!< Metadata of all known BIFs (except \c BMD_SPARQL_ONLY records); bif_t pointers as keys, pointers to \c bif_metadata_t as values */
extern dk_hash_t *name_to_bif_sparql_only_metadata_hash;	/*!< Metadata of \c BMD_SPARQL_ONLY names; unames as keys, pointers to \c bif_metadata_t as values. Note that it is \c dk_hash_t, not \c dk_hash_t */

#define find_bif_metadata_by_bif(b) ((bif_metadata_t *)gethash ((void *)(b), bif_to_bif_metadata_hash))
EXE_EXPORT (bif_metadata_t *, find_bif_metadata_by_name, (const char *name));
EXE_EXPORT (bif_metadata_t *, find_bif_metadata_by_raw_name, (const char *name));
#define find_bif_metadata_by_raw_name_safe(name) ((NULL == name_to_bif_metadata_idhash) ? NULL : find_bif_metadata_by_raw_name(name))
EXE_EXPORT (bif_metadata_t *, bif_define, (const char * name, bif_t bif));
EXE_EXPORT (bif_metadata_t *, bif_define_ex, (const char * name, bif_t bif, ...));
EXE_EXPORT (bif_metadata_t *, bif_define_typed, (const char * name, bif_t bif, bif_type_t *bt));
EXE_EXPORT (void, bif_set_uses_index, (bif_t bif));
EXE_EXPORT (bif_t, bif_find, (const char *name));
int bif_is_aggregate (bif_t bif);
void bif_set_is_aggregate (bif_t  bif);
bif_vec_t bif_vectored (bif_t bif);
void bif_set_vectored (bif_t bif, bif_vec_t vectored);

EXE_EXPORT (caddr_t, sqlr_run_bif_in_sandbox, (bif_metadata_t *bmd, caddr_t *args, caddr_t *err_ret));

bif_type_t * bif_type (const char * name);
void bif_type_set (bif_type_t *bt, state_slot_t *ret, state_slot_t **params);

#define bif_arg_nochecks(qst,args,nth) QST_GET ((qst), (args)[(nth)])
EXE_EXPORT (caddr_t, bif_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (caddr_t, bif_arg_unrdf, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (caddr_t, bif_arg_unrdf_ext, (caddr_t * qst, state_slot_t ** args, int nth, const char *func, caddr_t *ret_orig));
EXE_EXPORT (caddr_t, bif_string_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (caddr_t, bif_string_or_uname_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (caddr_t, bif_string_or_wide_or_uname_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (dk_session_t *, bif_strses_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (dk_session_t *, bif_strses_or_http_ses_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (struct xml_entity_s *, bif_entity_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (struct xml_tree_ent_s *, bif_tree_ent_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (caddr_t, bif_bin_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (caddr_t, bif_string_or_null_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (caddr_t, bif_string_or_uname_or_iri_id_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (data_col_t *, bif_dc_arg, (caddr_t * qst, state_slot_t ** args, int nth, char * name));
EXE_EXPORT (caddr_t, bif_string_or_wide_or_null_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (caddr_t, bif_string_or_uname_or_wide_or_null_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (caddr_t, bif_string_or_wide_or_null_or_strses_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (boxint, bif_long_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (ptrlong, bif_long_range_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func, ptrlong low, ptrlong hi));
EXE_EXPORT (ptrlong, bif_long_low_range_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func, ptrlong low));
EXE_EXPORT (boxint, bif_long_or_null_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int *isnull));
EXE_EXPORT (float, bif_float_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (double, bif_double_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (ptrlong, bif_long_or_char_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (caddr_t, bif_array_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (caddr_t, bif_array_or_null_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (caddr_t, bif_strict_array_or_null_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (caddr_t *, bif_strict_type_array_arg, (dtp_t element_dtp, caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (caddr_t *, bif_strict_2type_array_arg, (dtp_t element_dtp1, dtp_t element_dtp2, caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (caddr_t, bif_varchar_or_bin_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (iri_id_t, bif_iri_id_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (iri_id_t, bif_iri_id_or_null_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (iri_id_t, bif_iri_id_or_long_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (struct id_hash_iterator_s *, bif_dict_iterator_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int chk_version));
EXE_EXPORT (struct id_hash_iterator_s *, bif_dict_iterator_or_null_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int chk_version));
EXE_EXPORT (caddr_t, bif_date_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (caddr_t, bif_date_arg_rb_type, (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int *rb_type_ret));
EXE_EXPORT (int, dt_print_flags_of_rb_type, (int rb_type));
EXE_EXPORT (int, dt_print_flags_of_xsd_type_uname, (ccaddr_t xsd_type_uname));

dbe_key_t * bif_key_arg (caddr_t * qst, state_slot_t ** args, int n, const char * fn);

EXE_EXPORT (caddr_t, box_find_mt_unsafe_subtree, (caddr_t box));
EXE_EXPORT (void, box_make_tree_mt_safe, (caddr_t box));

EXE_EXPORT (int, bif_uses_index, (bif_t bif));

EXE_EXPORT (void, bif_result_inside_bif, (int n, ...));

EXE_EXPORT (caddr_t, bif_result_names, (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args));

caddr_t bif_result_names_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, int is_select);

extern caddr_t print_object_to_new_string (caddr_t xx, const char *fun_name, caddr_t * err_ret, int flags);

const char *dv_type_title (int type);

caddr_t bif_date_string (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

int bif_is_relocatable (bif_t bif);
double bif_double_or_null_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int * isnull);
EXE_EXPORT (caddr_t *, bif_array_of_pointer_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));


EXE_EXPORT_TYPED (bif_type_t, bt_varchar);
EXE_EXPORT_TYPED (bif_type_t, bt_wvarchar);
EXE_EXPORT_TYPED (bif_type_t, bt_any);
EXE_EXPORT_TYPED (bif_type_t, bt_any_box);
EXE_EXPORT_TYPED (bif_type_t, bt_iri_id);
EXE_EXPORT_TYPED (bif_type_t, bt_integer);
EXE_EXPORT_TYPED (bif_type_t, bt_integer_nn);
EXE_EXPORT_TYPED (bif_type_t, bt_double);
EXE_EXPORT_TYPED (bif_type_t, bt_float);
EXE_EXPORT_TYPED (bif_type_t, bt_numeric);
EXE_EXPORT_TYPED (bif_type_t, bt_convert);
EXE_EXPORT_TYPED (bif_type_t, bt_timestamp);
EXE_EXPORT_TYPED (bif_type_t, bt_time);
EXE_EXPORT_TYPED (bif_type_t, bt_date);
EXE_EXPORT_TYPED (bif_type_t, bt_datetime);
EXE_EXPORT_TYPED (bif_type_t, bt_bin);
EXE_EXPORT_TYPED (bif_type_t, bt_xml_entity);


extern dk_mutex_t *time_mtx;

void row_deref (caddr_t * qst, caddr_t id, placeholder_t **place_ret, caddr_t * row_ret, int lock_mode);

typedef struct sql_tree_s sql_tree_tmp;

EXE_EXPORT (caddr_t, box_cast, (caddr_t * qst, caddr_t data, sql_tree_tmp * dtp, dtp_t arg_dtp));
caddr_t box_cast_to (caddr_t *qst, caddr_t data, dtp_t data_dtp,
    dtp_t to_dtp, ptrlong prec, unsigned char  scale, caddr_t *err_ret);

extern sql_tree_tmp * st_varchar;
extern sql_tree_tmp * st_nvarchar;

int is_allowed (char * path);
EXE_EXPORT (void, file_path_assert, (caddr_t fname_cvt, caddr_t *err_ret, int free_fname_cvt));
int mime_get_attr (char *szMessage, long Offset, char szDelim, int *rfc822mode,
    int *override_to_mime, char *_szName, int max_name, char *_szValue, int max_value);
void dime_compose (dk_session_t * ses, caddr_t *input, caddr_t * err);

#define TNF_UNCHANGED	0
#define TNF_MTYPE 	1
#define TNF_URI 	2
#define TNF_NONE 	4
#define TNF_UNKNOWN 	3

#define DIME_MB 	0x04
#define DIME_ME 	0x02
#define DIME_CF 	0x01
#define DIME_NA 	0x00
#define DIME_LAST_CF 	0x80
#define DIME_FIRST_CF 	0x40

caddr_t bif_curtime (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_curdatetime (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

long get_mime_part (int *rfc822, caddr_t szMessage, long message_size, long offset,
    char *szBoundry, char *szType, size_t max_szType,
    caddr_t ** _result, long to_add);
caddr_t mime_parse_header (int *rfc822, caddr_t szMessage, long message_size, long offset);

#define MIME_POST_LIMIT 10000000
#define MIME_SESSION_LIMIT 5000000
caddr_t mime_stream_get_part (int rfc822, dk_session_t *ses, long max_size,
    dk_session_t *header_ses, long header_size);
int find_index_to_vector (caddr_t item, caddr_t vec, int veclen, dtp_t vectype,
    int start, int skip_value, const char *calling_fun);

const char * ws_file_ctype (const char * name);
void sprintf_escaped_id (ccaddr_t str, char *out, dk_session_t *ses);
void bif_ldapcli_init (void);
void bif_hosting_init (void);

#define MD5_SIZE 16
caddr_t box_md5 (caddr_t str);
EXE_EXPORT (caddr_t, md5, (caddr_t str));
caddr_t md5_ses (dk_session_t *ses);
#ifdef _SSL
caddr_t box_sha1 (caddr_t str);
caddr_t box_hmac (caddr_t box, caddr_t key, int alg);
#define HMAC_ALG_SHA1		0
#define HMAC_ALG_RIPMD160	1
#endif

extern int32 sqlbif_rnd (int32* seed);
extern double sqlbif_rnd_double (int32* seed, double upper_limit);
extern int32 rnd_seed;		/*!< 32 bit seed */
extern int32 rnd_seed_b;	/*!< another 32 bit seed used in blobs */

int virtuoso_sleep (long secs, long tms);
void sqls_define_2pc (void);
void sqls_define_1 (void);
void sqls_arfw_define_1 (void);
void sqls_define_blog (void);
void sqls_arfw_define_blog (void);
void sqls_define_vdb (void);
void sqls_arfw_define_vdb (void);
int restore_from_files (const char* prefix);
void ddl_init_plugin (void);
void pldbg_init (void);

/* sqlbif2 */
void sqlbif2_init (void);
void sqlbif_sequence_init (void);
int dks_is_localhost (dk_session_t *ses);
extern int lockdown_mode;

int tcpses_check_disk_error (dk_session_t *ses, caddr_t *qst, int throw_error);
#ifdef WIN32
caddr_t os_get_uname_by_fname (char *fname);
caddr_t os_get_gname_by_fname (char *fname);
#endif
caddr_t os_get_uname_by_uid (long uid);
caddr_t os_get_gname_by_gid (long gid);

extern caddr_t file_native_name (caddr_t server_encoded_fname);
extern caddr_t file_native_name_from_iri_path_nchars (const char *iri_path, size_t iri_path_len);
caddr_t get_ssl_error_text (char *buf, int len);

caddr_t regexp_match_01 (const char *pattern, const char *str, int c_opts);
caddr_t regexp_match_01_const (const char* pattern, const char* str, int c_opts, void ** compiled_ret);
caddr_t regexp_split_match (const char* pattern, const char* str, int* next, int c_opts);
int regexp_make_opts (const char* mode);
int regexp_split_parse (const char* pattern, const char* str, int* offvect, int offvect_sz, int c_opts);

/*! Wrapper for uu_decode_part,
 modifies \c src input string! */
EXE_EXPORT (int, uudecode_base64, (char * src, char * tgt));

EXE_EXPORT (caddr_t, sprintf_inverse, (caddr_t *qst, caddr_t *err_ret, ccaddr_t str, ccaddr_t fmt, long hide_errors));
EXE_EXPORT (caddr_t, sprintf_inverse_ex, (caddr_t *qst, caddr_t *err_ret, ccaddr_t str, ccaddr_t fmt, long hide_errors, unsigned char *expected_dtp_strg));

/* another 32 bit seed used in blobs */
extern int32 rnd_seed_b;
extern int no_free_set;

char * rel_to_abs_path (char *p, const char *path, long len);

extern boxint sequence_next_inc_and_log (query_instance_t *qi, caddr_t * err_ret, caddr_t name, boxint inc_by, boxint cl_sz);
caddr_t bif_result_names (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_convert (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_clear_temp (caddr_t *  qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_sequence_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_sequence_set_no_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_sequence_next_no_check (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
long raw_length (caddr_t arg);

#define AS_DBA(qi, exp) \
{ \
  oid_t old_u = qi->qi_u_id, old_g = qi->qi_g_id; \
  qi->qi_u_id = U_ID_DBA; \
  qi->qi_g_id = G_ID_DBA;\
  exp; \
  qi->qi_u_id = old_u;\
  qi->qi_g_id = old_g;\
}

int bif_is_no_cluster (bif_t bif); /* cannot be execd except where invoked */
int bif_need_enlist (bif_t bif);

#define BIF_NO_CLUSTER		0x1	/*!< bif is not shippable, e.g., depends on local thread context */
#define BIF_OUT_OF_PARTITION	0x2	/*!< bif makes a cross partition cluster op, can ship only if recursive qf enabled */
#define BIF_ENLIST		0x4	/*!< require and propagate enlist, bif makes a transactional write */ 

typedef struct
{
  void * sc_buff;
  dk_session_t *sc_out;
  OFF_T sc_bytes_sent;
} strses_chunked_out_t;

void strses_write_out_gz (dk_session_t *ses, dk_session_t *out, strses_chunked_out_t * outd);
int gz_stream_free (void *s);
extern int32 cl_non_logged_write_mode;
caddr_t bif_rollback (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

int iso_string_to_code (char * i);


typedef struct bif_exec_stat_s
{
  uint32	exs_start;
  client_connection_t * 	exs_cli;
  caddr_t 	exs_text;
} bif_exec_stat_t;

extern dk_mutex_t bif_exec_pending_mtx;
extern id_hash_t * bif_exec_pending;
extern int c_no_dbg_print;

#define BIF_NOT_VECTORED ((caddr_t)-2) /* err ret of a vectored bif for reverting to non-vectored form */

/* sqlprt.c */

#define TRSET_BUF_MAX		4000

typedef struct trset_ctx_s
{
  caddr_t tc_buf;
  char *  tc_tail;
  query_instance_t* tc_qst;
  int tc_indent;
} trset_ctx_t;

extern void trset_start (caddr_t *qst);
extern void trset_printf (const char *str, ...);
extern void trset_end (void);
extern void trset_add_indent (int delta);

#endif /* _SQLBIF_H */
