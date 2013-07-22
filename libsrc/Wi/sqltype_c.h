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

#define UST struct udt_parse_tree_s

typedef struct udt_parse_tree_s
{
  ptrlong type;
  union
  {
    struct
    {
      caddr_t name;
      caddr_t parent;
      UST *ext_def;
      UST *representation;
      UST *options;
      UST **methods;
    }
    type;
    struct
    {
      ptrlong language;
      caddr_t name;
      caddr_t type;
    }
    ext_def;
    struct
    {
      caddr_t name;
      ST *data_type;
      ST *ref_scope_check;
      caddr_t deflt;
      ST *collate;
      UST *ext_def;
      UST *soap_def;
    }
    member;
    struct
    {
      ptrlong final;
    }
    final;
    struct
    {
      ST *type;
    }
    ref;
    struct
    {
      ptrlong to_src;
      caddr_t function;
    }
    refcast;
    struct
    {
      ptrlong type;
      caddr_t name;
      ST **parms;
      ST *ret_type;
      caddr_t specific_name;
    }
    method;
    struct
    {
      ptrlong override;
      UST *method;
      ptrlong self_mask;
      UST **props;
    }
    method_def;
    struct
    {
      ptrlong specific;
      ptrlong type;
      caddr_t name;
      ST **parms;
      ST *ret_type;
      caddr_t type_name;
      ST *code;
    }
    method_decl;
    struct
    {
      caddr_t name;
      ptrlong drop_behaviour;
    }
    drop_udt;
    struct
    {
      caddr_t type;
      caddr_t name;
    }
    soap_def;

    struct
    {
      caddr_t type;
      UST* action;
    }
    alter;

    struct
    {
      UST *def;
    }
    member_add;

    struct
    {
      caddr_t name;
      ptrlong behaviour;
    }
    member_drop;

    struct
    {
      UST *spec;
    }
    method_add;

    struct
    {
      UST *spec;
      ptrlong behaviour;
    }
    method_drop;
  }
  _;
}
udt_parse_tree_t;

#define IS_DISTINCT_TYPE(tree) \
   ((tree)->_.type.representation && BOX_ELEMENTS ((tree)->_.type.representation) == 1 && \
       !ST_P (((UST **)(tree)->_.type.representation)[0], UDT_MEMBER))

void udt_exec_class_def (query_instance_t * qi, ST * tree);
void udt_drop_class_def (query_instance_t * qi, ST * tree);
void udt_alter_class_def (query_instance_t * qi, ST * tree);
int sqlc_udt_is_udt_call (sql_comp_t * sc, char *name, dk_set_t * code,
    state_slot_t * ret, state_slot_t ** params, caddr_t ret_param, caddr_t fun_udt_name);
int sqlc_udt_method_call (sql_comp_t * sc, char *name, dk_set_t * code,
    state_slot_t * ret, state_slot_t ** params, caddr_t ret_param,
    caddr_t type_name);

int udt_is_udt_bif (bif_t bif);

#define UDT_METHOD_CALL_BIF     "__udt_method_call"
#define UDT_MEMBER_HANDLER_BIF	"__udt_member_handler"
#define UDT_INSTANTIATE_CLASS_BIF "__udt_instantiate_class"
