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

/*#define UDT_HASH_DEBUG 1*/

#ifdef UDT_HASH_DEBUG
void dbg_udt_print_class_hash (dbe_schema_t *sc, char *msg, char *udt_name);
#else
#define dbg_udt_print_class_hash(sc,msg,udt_name)
#endif
struct sql_class_s;
struct sql_method_s;
struct sql_field_s;
struct object_space_s;
typedef struct sql_class_s sql_class_t;
typedef struct sql_method_s sql_method_t;
typedef struct sql_field_s sql_field_t;
typedef struct object_space_s object_space_t;

struct sql_class_s
{
  sql_class_t *scl_class;	/* metaclass */

  caddr_t scl_name;
  sql_class_t *scl_super;
  sql_method_t *scl_methods;
  sql_field_t *scl_fields;
  sql_field_t *scl_id_fields;

  char *scl_name_only;		/* point in the middle of tb_name, after owner */
  char *scl_qualifier;
  char *scl_qualifier_name;
  char *scl_owner;

  sql_field_t **scl_member_map;
  sql_method_t **scl_method_map;
  id_hash_t *	scl_name_to_method;

  int scl_obsolete;
  long scl_id;
  long scl_migrate_to;

  int scl_ext_lang;
  caddr_t scl_ext_name;
  int scl_self_as_ref;
  int scl_mem_only;

  int scl_defined;
  caddr_t scl_soap_type;
#if defined (PURIFY) || defined (VALGRIND)
  dk_set_t scl_old_methods;
  dk_set_t scl_old_fields;
#endif
  dk_hash_t *scl_grants;
  int scl_sec_unrestricted;
};

struct sql_method_s
{
  caddr_t scm_name;
  caddr_t scm_specific_name;
  sql_type_t *scm_signature;
  caddr_t *scm_param_names;
  query_t *scm_qr;
  int scm_type;
  int scm_override;
  sql_class_t *scm_class;

  int scm_ext_lang;
  caddr_t scm_ext_name;
  caddr_t scm_ext_type;
  caddr_t *scm_param_ext_types;
};


struct sql_field_s
{
  caddr_t sfl_name;
  sql_type_t sfl_sqt;
  caddr_t sfl_default;

  int sfl_ext_lang;
  caddr_t sfl_ext_name;
  caddr_t sfl_ext_type;

  caddr_t sfl_soap_name;
  caddr_t sfl_soap_type;
};


struct object_space_s
{
  id_hash_t *os_map;		/* from PK array to the memory image */
  object_space_t *os_parent;
  ptrlong os_next_serial;
};

typedef struct sql_ref_s
{
  key_id_t sr_key_id;
  caddr_t sr_pk;		/* row_key string, incl table */
}
sql_ref_t;


/* add to dbe_table_t:
 *  sql_class_t * 	tb_row_type;
 * a DV_REFERENCE holds the key id, which leads to a table whose tb_row_type holds the type ref'd */


typedef struct sql_cast_s
{
  sql_class_t *scst_from;
  sql_class_t *scst_to;
  int scst_is_implicit;
  caddr_t scst_proc;
}
sql_cast_t;


typedef struct sql_domain_s
{
  caddr_t dom_name;
  sql_type_t dom_sqt;
  caddr_t dom_check;		/* ST * */
  caddr_t dom_default;
}
sql_domain_t;


sql_class_t *udt_alloc_class_def (caddr_t name);
sql_class_t *sch_name_to_type (dbe_schema_t * sc, const char *name);
sql_class_t *udt_compile_class_def (dbe_schema_t * sc, caddr_t _tree,
    sql_class_t * udt, caddr_t * err_ret, int store_in_hash, client_connection_t *cli,
    long udt_id, long udt_migrate_to);
void udt_ensure_init (client_connection_t * cli);
void udt_resolve_instantiable (dbe_schema_t * sc, caddr_t * err_ret);

caddr_t sqlp_udt_method_decl (int specific, int mtd_type,
    caddr_t method_name, caddr_t params_list, caddr_t opt_ret,
    caddr_t udt_name, caddr_t body, caddr_t alt_ret_type);
caddr_t sqlp_udt_identifier_chain_to_member_handler (dk_set_t idents,
    caddr_t args, int is_observer);

sql_class_t *ddl_type_to_class (caddr_t * type, sql_class_t *cls);
extern void udt_ses_init(void);
int udt_instance_of (sql_class_t * udt, sql_class_t * sudt);

sql_class_t *bif_udt_arg (caddr_t * qst, state_slot_t ** args, int nth, const char *func);
int udt_find_field (sql_field_t ** map, caddr_t name);

/* from meta.c */
caddr_t sch_complete_table_name (caddr_t n);
dbe_schema_t *dbe_schema_copy (dbe_schema_t * from);

sql_class_t *sch_id_to_type (dbe_schema_t * sc, long id);

caddr_t udt_i_find_member_address (caddr_t *qst, state_slot_t *actual_ssl,
    code_vec_t code_vec, instruction_t *ins);

#define UDT_IS_SAME_CLASS(cls1,cls2) \
  ((cls1)->scl_obsolete == (cls2)->scl_obsolete && \
	  !strcmp ((cls1)->scl_name, (cls2)->scl_name))

#define UDT_N_SIG_ELTS(sig) \
	((int) ((sig) ? (box_length ((sig)) / sizeof (sql_type_t)) : 0))

typedef caddr_t (*udt_instantiate_class_t) (caddr_t * qst, sql_class_t * udt, sql_method_t *mtd,
         state_slot_t ** args, int n_args);
typedef caddr_t (*udt_instance_copy_t) (caddr_t box);
typedef void (*udt_instance_free_t) (caddr_t * box);
typedef caddr_t (*udt_member_observer_t) (caddr_t *qst, caddr_t udi, sql_field_t *fld, int member_inx);
typedef caddr_t (*udt_member_mutator_t) (caddr_t *qst, caddr_t udi, sql_field_t *fld, int member_inx, caddr_t new_val);
typedef caddr_t (*udt_method_call_t) (caddr_t *qst, sql_class_t *udt, caddr_t udi,
    sql_method_t *mtd, state_slot_t **args, int n_args);
typedef int (*udt_serialize_t) (caddr_t udi, dk_session_t * session);
typedef void *(*udt_deserialize_t) (dk_session_t * session, dtp_t dtp, sql_class_t *udt);

#define UDT_I_CLASS(inst) \
   (((sql_class_t **)(inst))[0])

#define UDT_JAVA_CLIENT_OBJECT_ID -1

typedef struct sql_class_imp_s
{
  udt_instantiate_class_t scli_instantiate_class;
  udt_instance_copy_t     scli_instance_copy;
  udt_instance_free_t     scli_instance_free;
  udt_member_observer_t   scli_member_observer;
  udt_member_mutator_t    scli_member_mutator;
  udt_method_call_t       scli_method_call;
  udt_serialize_t         scli_serialize;
  udt_deserialize_t       scli_deserialize;
} sql_class_imp_t;

extern sql_class_imp_t imp_map[];
sql_class_imp_t *get_imp_map_ptr(int type);

caddr_t udt_instantiate_class (caddr_t * qst, sql_class_t * udt, long mtd_inx,
    state_slot_t ** args, int n_args);

caddr_t udt_instance_copy (caddr_t box);

void udt_instance_free (caddr_t * box);

caddr_t udt_member_observer (caddr_t *qst, caddr_t udi, sql_field_t *fld, int member_inx);
caddr_t udt_member_mutator (caddr_t *qst, caddr_t udi, sql_field_t *fld, int member_inx, caddr_t new_val);
caddr_t udt_method_call (caddr_t *qst, sql_class_t *udt, caddr_t udi,
    sql_method_t *mtd, state_slot_t **args, int n_args);

int udt_serialize (caddr_t udi, dk_session_t * session);
void *udt_deserialize (dk_session_t * session, dtp_t dtp);
caddr_t udt_deserialize_from_blob (caddr_t bh, lock_trx_t *lt);

void dbg_udt_print_object (caddr_t udi, FILE *out);

/* object space stuff */

object_space_t *udo_new_object_space (object_space_t *parent);
void udo_object_space_clear (object_space_t *udo);
caddr_t udo_find_object_by_ref (caddr_t ref);
caddr_t udo_dbg_find_object_by_ref (query_instance_t *qi, caddr_t ref);


#define TA_OBJECT_SPACE_OWNER 2000
#define OBJECT_SPACE_NOT_SET ((object_space_t *)(1L))
#define OBJECT_SPACE_GET_FROM(os,thr) \
  do { \
    query_instance_t *os_owner = (query_instance_t *)(THR_ATTR ((thr), TA_OBJECT_SPACE_OWNER)); \
    if (NULL == os_owner) GPF_T1 ("Thread has no object space owner"); \
    (os) = os_owner->qi_object_space; \
    if (OBJECT_SPACE_NOT_SET == (os)) \
      (os) = os_owner->qi_object_space = udo_new_object_space (NULL); \
    } while (0);

#define OBJECT_SPACE_GET(os) OBJECT_SPACE_GET_FROM ((os), THREAD_CURRENT_THREAD)

#define UDT_N_FIELDS(udt) \
	((int) ((udt)->scl_fields ? (box_length ((udt)->scl_fields) / sizeof (sql_field_t)) : 0))

#define UDT_N_METHODS(udt) \
	((int) ((udt)->scl_methods ? (box_length ((udt)->scl_methods) / sizeof (sql_method_t)) : 0))

#define UDT_IS_DISTINCT(udt) \
   ((udt) && UDT_N_FIELDS(udt) == 1 && (udt)->scl_fields[0].sfl_name == NULL)

#define UDT_IS_INSTANTIABLE(udt) \
	((udt)->scl_member_map != NULL)

#define UDT_I_VAL(inst,inx) \
   (((caddr_t *)(inst))[inx + 1])

#define UDT_I_LENGTH(inst) \
   ((int) ((inst) ? (BOX_ELEMENTS (inst) - 1): 0))

extern caddr_t xmltype_class_name;
#define XMLTYPE_CLASS (sch_name_to_type (isp_schema(NULL), xmltype_class_name))
#define XMLTYPE_TO_ENTITY(obj) \
  ((xml_entity_t *) \
    ((UDT_I_CLASS(obj) == XMLTYPE_CLASS) ? \
    UDT_I_VAL(obj,0) : \
    NULL ) )

#define XMLTYPE_I_SCHEMA 1
#define XMLTYPE_I_VALIDATED 2

int udt_soap_struct_to_udi (caddr_t *place, dk_set_t *ret_set, caddr_t *ret_ptr, caddr_t *err_ret);
extern query_t * qr_dotnet_get_assembly_real;
