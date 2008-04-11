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

#ifndef _SQLBIF_H
#define _SQLBIF_H

typedef void (*bif_type_func_t) (state_slot_t ** args, long *dtp, long *prec,
    long *scale, caddr_t *collation);

typedef struct
  {
    bif_type_func_t	bt_func;
    long		bt_dtp;
    long		bt_prec;
    long		bt_scale;
  } bif_type_t;

#define NEW_DB_NULL dk_alloc_box (0, DV_DB_NULL)

#define is_some_sort_of_an_integer(T)\
 ((DV_SHORT_INT == (T)) || (DV_LONG_INT == (T)) ||\
  (DV_CHARACTER == (T)) || (DV_C_SHORT == (T)) || (DV_C_INT == (T)))

#ifndef O12
#define is_some_sort_of_a_string(T)\
 (((T) == DV_SHORT_STRING) || ((T) == DV_LONG_STRING) ||\
  ((T) == DV_G_REF) || ((T) == DV_G_REF_CLASS))
#else
#define is_some_sort_of_a_string(T)\
 (((T) == DV_SHORT_STRING) || ((T) == DV_LONG_STRING))
#endif
void sql_bif_init (void);

EXE_EXPORT (void, bif_define, (const char * name, bif_t bif));
EXE_EXPORT (void, bif_define_typed, (const char * name, bif_t bif, bif_type_t *bt));
EXE_EXPORT (void, bif_set_uses_index, (bif_t bif));
EXE_EXPORT (bif_t, bif_find, (const char *name));

bif_type_t * bif_type (const char * name);
void bif_type_set (bif_type_t *bt, state_slot_t *ret, state_slot_t **params);

EXE_EXPORT (caddr_t, bif_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (caddr_t, bif_string_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (caddr_t, bif_string_or_uname_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (caddr_t, bif_string_or_wide_or_uname_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (caddr_t, bif_strses_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (struct xml_entity_s *, bif_entity_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (struct xml_tree_ent_s *, bif_tree_ent_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
EXE_EXPORT (caddr_t, bif_bin_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func));
EXE_EXPORT (caddr_t, bif_string_or_null_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char * func));
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
EXE_EXPORT (struct id_hash_iterator_s *, bif_dict_iterator_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int chk_version));
EXE_EXPORT (struct id_hash_iterator_s *, bif_dict_iterator_or_null_arg, (caddr_t * qst, state_slot_t ** args, int nth, const char *func, int chk_version));

EXE_EXPORT (caddr_t, box_find_mt_unsafe_subtree, (caddr_t box));
EXE_EXPORT (void, box_make_tree_mt_safe, (caddr_t box));

EXE_EXPORT (int, bif_uses_index, (bif_t bif));

EXE_EXPORT (void, bif_result_inside_bif, (int n, ...));

EXE_EXPORT (caddr_t, bif_result_names, (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args));

extern caddr_t print_object_to_new_string (caddr_t xx, const char *fun_name, caddr_t * err_ret);

const char *dv_type_title (int type);

caddr_t bif_date_string (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

int bif_is_relocatable (bif_t bif);


extern bif_type_t bt_varchar;
extern bif_type_t bt_wvarchar;
extern bif_type_t bt_any;
extern bif_type_t bt_integer;
extern bif_type_t bt_double;
extern bif_type_t bt_float;
extern bif_type_t bt_numeric;
extern bif_type_t bt_convert;
extern bif_type_t bt_timestamp;
extern bif_type_t bt_time;
extern bif_type_t bt_date;
extern bif_type_t bt_datetime;
extern bif_type_t bt_bin;
extern bif_type_t bt_xml_entity;


extern dk_mutex_t *time_mtx;

void row_deref (caddr_t * qst, caddr_t id, placeholder_t **place_ret, caddr_t * row_ret, int lock_mode);

typedef struct sql_tree_s sql_tree_tmp;

EXE_EXPORT (caddr_t, box_cast, (caddr_t * qst, caddr_t data, sql_tree_tmp * dtp, dtp_t arg_dtp));
caddr_t box_cast_to (caddr_t *qst, caddr_t data, dtp_t data_dtp,
    dtp_t to_dtp, ptrlong prec, ptrlong scale, caddr_t *err_ret);

extern sql_tree_tmp * st_varchar;
extern sql_tree_tmp * st_nvarchar;

int is_allowed (char * path);
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

#define MIME_POST_LIMIT 10000000
#define MIME_SESSION_LIMIT 5000000
caddr_t mime_stream_get_part (int rfc822, dk_session_t *ses, long max_size,
    dk_session_t *header_ses, long header_size);
int find_index_to_vector (caddr_t item, caddr_t vec, int veclen, dtp_t vectype,
    int start, int skip_value, const char *calling_fun);

char * ws_file_ctype (char * name);
void sprintf_escaped_id (caddr_t str, char *out, dk_session_t *ses);
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

int32 sqlbif_rnd (int32* seed);
extern int32 rnd_seed_b;

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
int set_user_id (client_connection_t * cli, caddr_t name, caddr_t preserve_qual);

/* sqlbif2 */
void sqlbif2_init (void);
int dks_is_localhost (dk_session_t *ses);
extern int lockdown_mode;

int tcpses_check_disk_error (dk_session_t *ses, caddr_t *qst, int throw_error);
#ifdef WIN32
caddr_t os_get_uname_by_fname (char *fname);
caddr_t os_get_gname_by_fname (char *fname);
#endif
caddr_t os_get_uname_by_uid (long uid);
caddr_t os_get_gname_by_gid (long gid);

char *file_canonical_name (char *fname, int *is_allocated);
caddr_t get_ssl_error_text (char *buf, int len);

caddr_t regexp_match_01 (const char *pattern, const char *str, int c_opts);
caddr_t regexp_split_match (const char* pattern, const char* str, int* next, int c_opts);
int regexp_make_opts (const char* mode);
int regexp_split_parse (const char* pattern, const char* str, int* offvect, int offvect_sz, int c_opts);

/*! Wrapper for uu_decode_part,
 modifies \c src input string! */
EXE_EXPORT (int, uudecode_base64, (char * , char * ));

/* another 32 bit seed used in blobs */
extern int32 rnd_seed_b;
extern int no_free_set;


caddr_t bif_result_names (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);
caddr_t bif_convert (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args);

#endif /* _SQLBIF_H */
