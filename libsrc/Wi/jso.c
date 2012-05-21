/*
 *  jso.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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

#include "jso.h"
#include "sqlbif.h"
#include "security.h"

dk_hash_t *jso_consts = NULL;
dk_hash_t *jso_classes = NULL;
dk_hash_t *jso_properties = NULL;
dk_hash_t *jso_rttis_of_names = NULL;
dk_hash_t *jso_rttis_of_structs = NULL;

dk_hash_t *jso_triple_preds = NULL;
dk_hash_t *jso_triple_subjs = NULL;
dk_hash_t *jso_triple_objs = NULL;

static void
jso_define_array (jso_class_descr_t *cd)
{
  jso_array_descr_t *ad = &(cd->_.ad);
  ad->jsoad_member_type = box_dv_uname_string (ad->jsoad_member_type);
}

static void
jso_define_struct (jso_class_descr_t *cd)
{
  jso_struct_descr_t *sd = &(cd->_.sd);
  int field_ctr;
  if (0 > sd->jsosd_field_count)
    {
      sd->jsosd_field_count = 0;
      while (NULL != sd->jsosd_field_list[sd->jsosd_field_count].jsofd_local_name)
        sd->jsosd_field_count += 1;
    }
  sd->jsosd_field_hash = hash_table_allocate (sd->jsosd_field_count);
  for (field_ctr = sd->jsosd_field_count; field_ctr--; /* no step */)
    {
      jso_field_descr_t *fldd = sd->jsosd_field_list+field_ctr;
      jso_field_descr_t *old_fldd;
      fldd->jsofd_local_name = box_dv_uname_string (fldd->jsofd_local_name);
      BOX_DV_UNAME_CONCAT (fldd->jsofd_property_iri, cd->jsocd_ns_uri, fldd->jsofd_local_name);
      fldd->jsofd_type = box_dv_uname_string (fldd->jsofd_type);
      fldd->jsofd_class = cd;
      old_fldd = (jso_field_descr_t *)gethash (fldd->jsofd_property_iri, jso_properties);
      if (NULL != old_fldd)
        {
          char buf[2000];
          sprintf (buf, "JSO property IRI %s in %s conflicts with same property IRI in %s",
            fldd->jsofd_property_iri, cd->jsocd_c_typedef, old_fldd->jsofd_class->jsocd_c_typedef );
          GPF_T1 (buf);
        }
      sethash (fldd->jsofd_property_iri, jso_properties, fldd);
      sethash (fldd->jsofd_property_iri, sd->jsosd_field_hash, fldd);
    }
}


void
jso_define_const (const char *iri, ptrlong value)
{
  caddr_t old_value;
  iri = box_dv_uname_string (iri);
  old_value = gethash (iri, jso_consts);
  if (NULL != old_value)
    {
      char buf[2000];
      sprintf (buf, "JSO const IRI %s is defined before", iri);
      GPF_T1 (buf);
    }
  sethash (iri, jso_consts, box_num_nonull (value));
}


void
jso_define_class (jso_class_descr_t *cd)
{
  jso_class_descr_t *old_cd;
  cd->jsocd_c_typedef = box_dv_uname_string (cd->jsocd_c_typedef);
  cd->jsocd_ns_uri = box_dv_uname_string (cd->jsocd_ns_uri);
  cd->jsocd_local_name = box_dv_uname_string (cd->jsocd_local_name);
  BOX_DV_UNAME_CONCAT(cd->jsocd_class_iri, cd->jsocd_ns_uri, cd->jsocd_local_name);
  old_cd = gethash (cd->jsocd_class_iri, jso_classes);
  if (NULL != old_cd)
    {
      char buf[2000];
      sprintf (buf, "JSO class IRI %s of %s conflicts with same class IRI in %s",
        cd->jsocd_class_iri,
        cd->jsocd_c_typedef, old_cd->jsocd_c_typedef );
      GPF_T1 (buf);
    }
  cd->jsocd_rttis = hash_table_allocate (97);
  sethash (cd->jsocd_class_iri, jso_classes, cd);
  switch (cd->jsocd_cat)
    {
    case JSO_CAT_STRUCT: jso_define_struct (cd); break;
    case JSO_CAT_ARRAY: jso_define_array (cd); break;
    default: GPF_T1("jso_define_class (): unknown value of jsocd_cat");
    }
}


caddr_t
bif_jso_new (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t jclass = bif_string_or_wide_or_uname_arg (qst, args, 0, "jso_new");
  caddr_t jinstance = bif_string_or_wide_or_uname_arg (qst, args, 1, "jso_new");
  jso_class_descr_t *cd;
  void *inst = NULL;
  jso_rtti_t *inst_rtti;
  jclass = box_cast_to_UTF8_uname (qst, jclass);
  cd = gethash (jclass, jso_classes);
  if (NULL == cd)
    sqlr_new_error ("22023", "SR491", "Undefined JSO class IRI <%.500s>", jclass);
  jinstance = box_cast_to_UTF8_uname (qst, jinstance);
  inst_rtti = gethash (jinstance, jso_rttis_of_names);
  if ((NULL != inst_rtti) && (JSO_STATUS_DELETED != inst_rtti->jrtti_status))
    {
      sqlr_new_error ("22023", "SR492", "JSO instance IRI <%.500s> already exists, type <%.500s>",
        jinstance, inst_rtti->jrtti_class->jsocd_class_iri );
    }
  if (NULL == inst_rtti)
    {
      inst_rtti = dk_alloc_box_zero (sizeof (jso_rtti_t), DV_CUSTOM);
      if (NULL == cd)
        inst = dk_alloc_box_zero (2 * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
      else
        switch (cd->jsocd_cat)
          {
          case JSO_CAT_STRUCT: inst = dk_alloc_box_zero (cd->_.sd.jsosd_sizeof, DV_ARRAY_OF_POINTER); break;
          case JSO_CAT_ARRAY:
            {
              int init_size = cd->_.ad.jsoad_max_length;
              if (init_size > 16)
                init_size = 16;
              inst = dk_alloc_box_zero ((init_size + 1) * sizeof (caddr_t), DV_ARRAY_OF_POINTER); break;
            }
          default: GPF_T1("jso_new (): unknown value of jsocd_cat");
          }
      inst_rtti->jrtti_self = inst;
      inst_rtti->jrtti_inst_iri = jinstance;
      inst_rtti->jrtti_class = cd;
#ifdef DEBUG
      inst_rtti->jrtti_loop = inst_rtti;
#endif
      sethash (jinstance, jso_rttis_of_names, inst_rtti);
      if (NULL != cd)
        sethash (jinstance, cd->jsocd_rttis, inst_rtti);
      sethash (inst, jso_rttis_of_structs, inst_rtti);
    }
  inst_rtti->jrtti_status = JSO_STATUS_NEW;
  return box_copy (jinstance);
}


void
jso_get_cd_and_rtti (ccaddr_t jclass, ccaddr_t jinstance, jso_class_descr_t **cd_ptr, jso_rtti_t **inst_rtti_ptr, int quiet_if_deleted)
{
  cd_ptr[0] = gethash (jclass, jso_classes);
  if (NULL == cd_ptr[0])
    sqlr_new_error ("22023", "SR500", "Undefined JSO class IRI <%.500s>", jclass);
  inst_rtti_ptr[0] = gethash (jinstance, jso_rttis_of_names);
  if (NULL == inst_rtti_ptr[0])
    {
      if (NULL == cd_ptr[0])
        return;
      if (!quiet_if_deleted)
        sqlr_new_error ("22023", "SR501", "JSO instance IRI <%.500s> does not exist",
          jinstance );
      return;
    }
  if (JSO_STATUS_DELETED == inst_rtti_ptr[0]->jrtti_status)
    {
      if (!quiet_if_deleted)
        sqlr_new_error ("22023", "SR501", "JSO instance IRI <%.500s> has been deleted before, type <%.500s>",
          jinstance, inst_rtti_ptr[0]->jrtti_class->jsocd_class_iri );
      return;
    }
  if ((NULL != cd_ptr[0]) && (cd_ptr[0] != inst_rtti_ptr[0]->jrtti_class))
    {
      sqlr_new_error ("22023", "SR502", "JSO instance IRI <%.500s> is of type <%.500s>, required type is <%.500s>",
        jinstance, inst_rtti_ptr[0]->jrtti_class->jsocd_class_iri, jclass );
    }
}


caddr_t
bif_jso_delete (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t jclass = bif_string_or_wide_or_uname_arg (qst, args, 0, "jso_delete");
  caddr_t jinstance = bif_string_or_wide_or_uname_arg (qst, args, 1, "jso_delete");
  long quiet = bif_long_arg (qst, args, 2, "jso_delete");
  jso_class_descr_t *cd;
  jso_rtti_t *inst_rtti;
  caddr_t *inst;
  int fld_ctr;
  jclass = box_cast_to_UTF8_uname (qst, jclass);
  jinstance = box_cast_to_UTF8_uname (qst, jinstance);
  jso_get_cd_and_rtti (jclass, jinstance, &cd, &inst_rtti, quiet);
  if (NULL == inst_rtti)
    return jinstance;
  inst = inst_rtti->jrtti_self;
  if (JSO_CAT_STRUCT != cd->jsocd_cat)
    goto end_delete_private_members; /* see below */
  switch (inst_rtti->jrtti_status)
    {
    case JSO_STATUS_FAILED: break;
    case JSO_STATUS_LOADED: break;
    case JSO_STATUS_NEW: break;
    default: goto end_delete_private_members; /* see below */
    }
#ifndef NDEBUG
  for (fld_ctr = cd->_.sd.jsosd_field_count; fld_ctr--; /*no step*/)
    {
      jso_field_descr_t *fldd = cd->_.sd.jsosd_field_list + fld_ctr;
      jso_class_descr_t *fld_type_cd = gethash (fldd->jsofd_type, jso_classes);
      jso_rtti_t *sub = (jso_rtti_t *)(JSO_FIELD_PTR (inst, fldd)[0]);
      if ((JSO_PRIVATE == fldd->jsofd_required) && (NULL != sub))
        {
          if ((NULL == fld_type_cd) && (DV_CUSTOM != DV_TYPE_OF (sub)))
            dk_check_tree (sub);
        }
    }
#endif
  for (fld_ctr = cd->_.sd.jsosd_field_count; fld_ctr--; /*no step*/)
    {
      jso_field_descr_t *fldd = cd->_.sd.jsosd_field_list + fld_ctr;
      jso_class_descr_t *fld_type_cd = gethash (fldd->jsofd_type, jso_classes);
      jso_rtti_t *sub = (jso_rtti_t *)(JSO_FIELD_PTR (inst, fldd)[0]);
      if ((JSO_PRIVATE == fldd->jsofd_required) && (NULL != sub))
        {
          if ((NULL == fld_type_cd) && (DV_CUSTOM != DV_TYPE_OF (sub)))
            dk_free_tree (sub);
          JSO_FIELD_PTR (inst, fldd)[0] = NULL;
        }
    }
end_delete_private_members:
  if ((NULL != cd) && (JSO_CAT_STRUCT == cd->jsocd_cat))
    memset (inst_rtti->jrtti_self, 0, cd->_.sd.jsosd_sizeof);
  else
    memset (inst_rtti->jrtti_self, 0, box_length (inst_rtti->jrtti_self));
  inst_rtti->jrtti_status = JSO_STATUS_DELETED;
  return jinstance;
}


void
jso_validate (jso_rtti_t *inst_rtti, jso_rtti_t *root_rtti, dk_hash_t *known, int change_status)
{
#define SET_STATUS_FAILED \
  do { \
    if (!change_status) \
      break; \
    if (JSO_STATUS_NEW == inst_rtti->jrtti_status) \
      inst_rtti->jrtti_status = JSO_STATUS_FAILED; \
    if (JSO_STATUS_NEW == root_rtti->jrtti_status) \
      root_rtti->jrtti_status = JSO_STATUS_FAILED; \
    } while (0)
  jso_rtti_t *known_rtti;
  jso_class_descr_t *cd = inst_rtti->jrtti_class;
  caddr_t *inst;
  int ctr;
  inst = inst_rtti->jrtti_self;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (inst))
    GPF_T1("jso_validate(): bad instance");
  known_rtti = gethash (inst, known);
  if (NULL != known_rtti)
    {
      if (inst_rtti != known_rtti)
        GPF_T1("jso_validate(): two rttis for one class instance");
      return;
    }
  switch (inst_rtti->jrtti_status)
    {
    case JSO_STATUS_DELETED:
      sqlr_new_error ("22023", "SR525", "JSO instance IRI <%.500s> is DELETED but is available from <%.500s>",
        inst_rtti->jrtti_inst_iri, root_rtti->jrtti_inst_iri );
    case JSO_STATUS_FAILED: break;
    case JSO_STATUS_LOADED: return;
    case JSO_STATUS_NEW: break;
    default: GPF_T1("jso_validate(): unknown status");
    }
  switch (cd->jsocd_cat)
    {
    case JSO_CAT_ARRAY:
      {
        jso_class_descr_t *fld_type_cd = gethash (cd->_.ad.jsoad_member_type, jso_classes);
        int ctr;
        int full_length = BOX_ELEMENTS (inst);
        int used_length = full_length;
        if (full_length > cd->_.ad.jsoad_min_length)
          {
            while ((0 < used_length) && (NULL == inst[used_length - 1])) used_length--;
          }
        if (used_length < cd->_.ad.jsoad_min_length)
          {
            SET_STATUS_FAILED;
            sqlr_new_error ("22023", "SR526", "JSO array instance <%.500s> of type <%.500s> is only %ld items long, should have at least %ld",
              inst_rtti->jrtti_inst_iri, inst_rtti->jrtti_class->jsocd_class_iri, (long)used_length, (long)(cd->_.ad.jsoad_min_length) );
          }
        for (ctr = 0; ctr < used_length; ctr++)
          {
            jso_rtti_t * sub = ((jso_rtti_t **)(inst))[ctr];
            if (NULL == sub)
              {
                SET_STATUS_FAILED;
                sqlr_new_error ("22023", "SR527", "JSO array instance <%.500s> of type <%.500s> contains uninitialized element %ld",
                  inst_rtti->jrtti_inst_iri, inst_rtti->jrtti_class->jsocd_class_iri, (long)ctr );
                continue;
              }
            switch (DV_TYPE_OF (sub))
              {
              case DV_CUSTOM:
                if (NULL != fld_type_cd)
                  {
                    if (sub->jrtti_class->jsocd_class_iri != cd->_.ad.jsoad_member_type)
                      {
                        SET_STATUS_FAILED;
                        sqlr_new_error ("22023", "SR531", "Item # %d of JSO array <%.500s> of type <%.500s> is of wrong type <%.500s>, must be <%.500s>",
                          ctr, inst_rtti->jrtti_inst_iri, inst_rtti->jrtti_class->jsocd_class_iri,
                          sub->jrtti_class->jsocd_class_iri, cd->_.ad.jsoad_member_type );
                      }
                  }
                break;
              case DV_LONG_INT:
                if (&jso_cd_array_of_any != cd)
                  {
                    SET_STATUS_FAILED;
                    sqlr_new_error ("22023", "SR538", "The value of rdf:_%d in JSO instance <%.500s> of type <%.500s> is an integer, not an object of type <%.500s>",
                      ctr, inst_rtti->jrtti_inst_iri, inst_rtti->jrtti_class->jsocd_class_iri, cd->_.ad.jsoad_member_type );
                  }
                break;
              case DV_STRING:
                if (&jso_cd_array_of_string != cd)
                  {
                    SET_STATUS_FAILED;
                    sqlr_new_error ("22023", "SR539", "The value of rdf:_%d in JSO instance <%.500s> of type <%.500s> is a string, not an object of type <%.500s>",
                      ctr, inst_rtti->jrtti_inst_iri, inst_rtti->jrtti_class->jsocd_class_iri, cd->_.ad.jsoad_member_type );
                  }
                break;
              default:
                SET_STATUS_FAILED;
                sqlr_new_error ("22023", "SR539", "The value of rdf:_%d in JSO instance <%.500s> of type <%.500s> is not an object of type <%.500s>",
                  ctr, inst_rtti->jrtti_inst_iri, inst_rtti->jrtti_class->jsocd_class_iri, cd->_.ad.jsoad_member_type );
              }
          }
        break;
      }
    case JSO_CAT_STRUCT:
      {
        int fld_ctr;
        for (fld_ctr = cd->_.sd.jsosd_field_count; fld_ctr--; /*no step*/)
          {
            jso_field_descr_t *fldd = cd->_.sd.jsosd_field_list + fld_ctr;
            jso_class_descr_t *fld_type_cd = gethash (fldd->jsofd_type, jso_classes);
            jso_rtti_t *sub = (jso_rtti_t *)(JSO_FIELD_PTR (inst, fldd)[0]);
            if (NULL != sub)
              {
                if ((JSO_PRIVATE == fldd->jsofd_required) && !change_status)
                  {
                    SET_STATUS_FAILED;
                    sqlr_new_error ("22023", "SR532", "Private property %.500s is set in JSO instance <%.500s> of type <%.500s>",
                      fldd->jsofd_local_name, inst_rtti->jrtti_inst_iri, inst_rtti->jrtti_class->jsocd_class_iri );
                  }
                if ((JSO_DEPRECATED == fldd->jsofd_required) && !change_status)
                  {
                    SET_STATUS_FAILED;
                    sqlr_new_error ("22023", "SR529", "Deprecated property %.500s is set in JSO instance <%.500s> of type <%.500s>",
                      fldd->jsofd_local_name, inst_rtti->jrtti_inst_iri, inst_rtti->jrtti_class->jsocd_class_iri );
                  }
                if ((NULL != fld_type_cd) && (DV_CUSTOM == DV_TYPE_OF (sub)))
                  {
                    if (sub->jrtti_class->jsocd_class_iri != fldd->jsofd_type)
                      {
                        SET_STATUS_FAILED;
                        sqlr_new_error ("22023", "SR530", "Property %.500s of JSO instance <%.500s> of type <%.500s> is of wrong type <%.500s>, must be <%.500s>",
                          fldd->jsofd_local_name, inst_rtti->jrtti_inst_iri, inst_rtti->jrtti_class->jsocd_class_iri,
                          sub->jrtti_class->jsocd_class_iri, fldd->jsofd_type );
                      }
                  }
              }
            else
              {
                if ((JSO_REQUIRED == fldd->jsofd_required) || (JSO_INHERITABLE == fldd->jsofd_required))
                  {
                    SET_STATUS_FAILED;
                    sqlr_new_error ("22023", "SR528", "Uninitialized property %.500s in JSO instance <%.500s> of type <%.500s>",
                      fldd->jsofd_local_name, inst_rtti->jrtti_inst_iri, inst_rtti->jrtti_class->jsocd_class_iri );
                  }
              }
          }
        break;
      }
    }
  sethash (inst, known, inst_rtti);
  DO_BOX_FAST (jso_rtti_t *, sub, ctr, inst)
    {
      if (DV_CUSTOM == DV_TYPE_OF(sub))
        jso_validate (sub, root_rtti, known, change_status);
    }
  END_DO_BOX_FAST;
  switch (cd->jsocd_cat)
    {
    case JSO_CAT_ARRAY:
      {
        DO_BOX_FAST (jso_rtti_t *, sub, ctr, inst)
          {
            if (DV_CUSTOM == DV_TYPE_OF (sub))
              jso_validate (sub, root_rtti, known, change_status);
          }
        END_DO_BOX_FAST;
        break;
      }
    case JSO_CAT_STRUCT:
      {
        int fld_ctr;
        for (fld_ctr = cd->_.sd.jsosd_field_count; fld_ctr--; /*no step*/)
          {
            jso_field_descr_t *fldd = cd->_.sd.jsosd_field_list + fld_ctr;
            jso_class_descr_t *fld_type_cd = gethash (fldd->jsofd_type, jso_classes);
            jso_rtti_t *sub = (jso_rtti_t *)(JSO_FIELD_PTR (inst, fldd)[0]);
            if ((NULL != sub) && (NULL != fld_type_cd))
              jso_validate (sub, root_rtti, known, change_status);
          }
        break;
      }
    }
  if (change_status && (JSO_STATUS_FAILED == inst_rtti->jrtti_status))
    inst_rtti->jrtti_status = JSO_STATUS_NEW;
}


caddr_t
bif_jso_validate (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t jclass = bif_string_or_wide_or_uname_arg (qst, args, 0, "jso_validate");
  caddr_t jinstance = bif_string_or_wide_or_uname_arg (qst, args, 1, "jso_validate");
  ptrlong change_status = bif_long_arg (qst, args, 2, "jso_validate");
  dk_hash_t *known = hash_table_allocate (256);
  jso_class_descr_t *cd;
  jso_rtti_t *inst_rtti;
  jclass = box_cast_to_UTF8_uname (qst, jclass);
  jinstance = box_cast_to_UTF8_uname (qst, jinstance);
  jso_get_cd_and_rtti (jclass, jinstance, &cd, &inst_rtti, 0);
  QR_RESET_CTX
    {
      jso_validate (inst_rtti, inst_rtti, known, change_status);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      POP_QR_RESET;
      hash_table_free (known);
      sqlr_resignal (err);
    }
  END_QR_RESET
  hash_table_free (known);
  return jinstance;
}


void
jso_pin (jso_rtti_t *inst_rtti, jso_rtti_t *root_rtti, dk_hash_t *known)
{
  jso_rtti_t *known_rtti;
  jso_class_descr_t *cd = inst_rtti->jrtti_class;
  caddr_t *inst;
  int ctr;
  inst = inst_rtti->jrtti_self;
  if (DV_ARRAY_OF_POINTER != DV_TYPE_OF (inst))
    GPF_T1("jso_pin(): bad instance");
  known_rtti = gethash (inst, known);
  if (NULL != known_rtti)
    {
      if (inst_rtti != known_rtti)
        GPF_T1("jso_pin(): two rttis for one class instance");
      return;
    }
  switch (inst_rtti->jrtti_status)
    {
    case JSO_STATUS_DELETED:
      sqlr_new_error ("22023", "SR513", "JSO instance IRI <%.500s> is DELETED but is available from <%.500s>",
        inst_rtti->jrtti_inst_iri, root_rtti->jrtti_inst_iri );
    case JSO_STATUS_FAILED:
      sqlr_new_error ("22023", "SR529", "JSO instance IRI <%.500s> contains inconsistent data but is available from <%.500s>",
        inst_rtti->jrtti_inst_iri, root_rtti->jrtti_inst_iri );
    case JSO_STATUS_LOADED: return;
    case JSO_STATUS_NEW: break;
    default: GPF_T1("jso_pin(): unknown status");
    }
  if (JSO_CAT_ARRAY == cd->jsocd_cat)
    {
      int full_length = BOX_ELEMENTS (inst);
      if (full_length > cd->_.ad.jsoad_min_length)
        {
          int used_length = full_length;
          while ((0 < used_length) && (NULL == inst[used_length - 1])) used_length--;
          if (used_length < full_length)
            {
              caddr_t *new_inst = dk_alloc_box (used_length * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
              memcpy (new_inst, inst, used_length * sizeof (caddr_t));
              /* memory of old inst is lost here */
              inst = inst_rtti->jrtti_self = new_inst;
	      sethash (new_inst, jso_rttis_of_structs, inst_rtti);
            }
        }
    }
  sethash (inst, known, inst_rtti);
  DO_BOX_FAST (jso_rtti_t *, sub, ctr, inst)
    {
      if (DV_CUSTOM == DV_TYPE_OF(sub))
        jso_pin (sub, root_rtti, known);
    }
  END_DO_BOX_FAST;
  if (JSO_CAT_ARRAY == cd->jsocd_cat)
    {
      for (ctr = BOX_ELEMENTS(inst); ctr--; /*no step*/)
        {
          caddr_t *sub_ptr = inst + ctr;
          caddr_t sub = sub_ptr[0];
          switch (DV_TYPE_OF(sub))
            {
            case DV_CUSTOM:
              sub_ptr[0] = ((jso_rtti_t *)sub)->jrtti_self;
              break;
            case DV_LONG_INT:
              ((ptrlong *)(sub_ptr))[0] = unbox (sub);
              break;
            case DV_DOUBLE_FLOAT:
              if (NULL != sub)
                ((double *)(sub_ptr))[0] = unbox_double (sub);
              else
                ((double *)(sub_ptr))[0] = 0;
              break;
            default: break;
            }
        }
    }
  else
    {
      for (ctr = cd->_.sd.jsosd_field_count; ctr--; /* no step */)
        {
          jso_field_descr_t *fd = cd->_.sd.jsosd_field_list + ctr;
          caddr_t sub, *sub_ptr;
          if (!strcmp (JSO_ANY, fd->jsofd_type))
            continue;
          sub_ptr = ((caddr_t *)(((char *)inst) + (fd->jsofd_byte_offset)));
          sub = sub_ptr[0];
          switch (DV_TYPE_OF(sub))
            {
            case DV_CUSTOM:
              sub_ptr[0] = ((jso_rtti_t *)sub)->jrtti_self;
              break;
            case DV_LONG_INT:
              ((ptrlong *)(sub_ptr))[0] = unbox (sub);
              break;
            case DV_DOUBLE_FLOAT:
              if (NULL != sub)
                ((double *)(sub_ptr))[0] = unbox_double (sub);
              else
                ((double *)(sub_ptr))[0] = 0;
              break;
            default: break;
            }
        }
    }
  inst_rtti->jrtti_status = JSO_STATUS_LOADED;
}


caddr_t
bif_jso_pin (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t jclass = bif_string_or_wide_or_uname_arg (qst, args, 0, "jso_pin");
  caddr_t jinstance = bif_string_or_wide_or_uname_arg (qst, args, 1, "jso_pin");
  dk_hash_t *known = hash_table_allocate (256);
  jso_class_descr_t *cd;
  jso_rtti_t *inst_rtti;
  jclass = box_cast_to_UTF8_uname (qst, jclass);
  jinstance = box_cast_to_UTF8_uname (qst, jinstance);
  jso_get_cd_and_rtti (jclass, jinstance, &cd, &inst_rtti, 0);
  QR_RESET_CTX
    {
      jso_pin (inst_rtti, inst_rtti, known);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      POP_QR_RESET;
      hash_table_free (known);
      sqlr_resignal (err);
    }
  END_QR_RESET
  hash_table_free (known);
  return jinstance;
}

static caddr_t
bif_jso_set_impl (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args, int do_set, const char *func_name)
{
  caddr_t jclass = bif_string_or_wide_or_uname_arg (qst, args, 0, func_name);
  caddr_t jinstance = bif_string_or_wide_or_uname_arg (qst, args, 1, func_name);
  caddr_t jprop = NULL;
  ccaddr_t dt = NULL;
  caddr_t *retval;
  caddr_t old_fld_val = NULL;
  jso_class_descr_t *cd, *fld_type_cd;
  jso_field_descr_t fldd_for_array;
  jso_field_descr_t *fldd = NULL;
  void *inst;
  jso_rtti_t *inst_rtti;
  void **fld_ptr = NULL;
  jclass = box_cast_to_UTF8_uname (qst, jclass);
  cd = gethash (jclass, jso_classes);
  if (NULL == cd)
    sqlr_new_error ("22023", "SR493", "Undefined JSO class IRI <%.500s>", jclass);
  jinstance = box_cast_to_UTF8_uname (qst, jinstance);
  inst_rtti = gethash (jinstance, jso_rttis_of_names);
  if (NULL == inst_rtti)
    {
      sqlr_new_error ("22023", "SR494", "JSO instance IRI <%.500s> does not exist", jinstance);
    }
  if (do_set)
    {
      if (JSO_STATUS_NEW != inst_rtti->jrtti_status)
        {
          sqlr_new_error ("22023", "SR503", "JSO instance IRI <%.500s> is not marked as NEW, can not edit it", jinstance);
        }
    }
  else
    {
      if (JSO_STATUS_DELETED == inst_rtti->jrtti_status)
        {
          sqlr_new_error ("22023", "SR504", "JSO instance IRI <%.500s> is marked as DELETED, can not read it", jinstance);
        }
      if (JSO_STATUS_LOADED == inst_rtti->jrtti_status)
        {
          sqlr_new_error ("22023", "SR504", "JSO instance IRI <%.500s> is marked as LOADED, can not read it", jinstance);
        }
    }
  if (cd != inst_rtti->jrtti_class)
    {
      sqlr_new_error ("22023", "SR495", "JSO instance IRI <%.500s> is of type <%.500s>, required type is <%.500s>",
        jinstance, inst_rtti->jrtti_class->jsocd_class_iri, jclass );
    }
  inst = inst_rtti->jrtti_self;
  switch (cd->jsocd_cat)
    {
    case JSO_CAT_STRUCT:
      jprop = box_cast_to_UTF8_uname (qst, bif_string_or_wide_or_uname_arg (qst, args, 2, func_name));
      fldd = gethash (jprop, cd->_.sd.jsosd_field_hash);
      if (NULL == fldd)
        {
          sqlr_new_error ("22023", "SR496", "Property <%.500s> is not a field of %.500s, RDF class <%.500s>",
            jprop, cd->jsocd_c_typedef, jclass );
        }
      fld_ptr = (void **)(JSO_FIELD_PTR(inst,fldd));
      dt = fldd->jsofd_type;
      break;
    case JSO_CAT_ARRAY:
      {
        dtp_t jprop_dtp;
        ptrlong idx = 0;
        jprop = bif_arg (qst, args, 2, func_name);
        jprop_dtp = DV_TYPE_OF(jprop);
        if (IS_NUM_DTP(jprop_dtp))
          idx = bif_long_arg (qst, args, 2, func_name);
        else
          {
            jprop = box_cast_to_UTF8_uname (qst, bif_string_or_wide_or_uname_arg (qst, args, 2, func_name));
            if ((box_length (jprop) > (RDF_NS_URI_LEN + 2)) &&
              !memcmp (jprop, RDF_NS_URI, RDF_NS_URI_LEN) &&
              ('_' == jprop[RDF_NS_URI_LEN]) )
              {
                idx = atol (jprop + RDF_NS_URI_LEN+1);
                if (idx <= 0)
                  {
                    sqlr_new_error ("22023", "SR516", "Invalid index 'rdf:%s' specified for instance %.500s of RDF array class <%.500s>",
                      jprop+RDF_NS_URI_LEN, jinstance, jclass);
                  }
                idx--;
              }
            else
              {
                sqlr_new_error ("22023", "SR509", "The instance %.500s of RDF class <%.500s> is an array and can not have property <%.500s>",
                  jinstance, jclass, jprop );
              }
          }
        if ((idx < 0) || (idx >= cd->_.ad.jsoad_max_length))
          {
            sqlr_new_error ("22023", "SR510", "Invalid index %ld specified for instance %.500s of RDF array class <%.500s>",
              (long)idx, jinstance, jclass);
          }
        fldd_for_array.jsofd_byte_offset = sizeof (caddr_t) * idx;
        fldd_for_array.jsofd_class = cd;
        fldd_for_array.jsofd_local_name = "(N-th array element)";
        fldd_for_array.jsofd_property_iri = "rdf:_NNN";
        fldd_for_array.jsofd_required = JSO_REQUIRED;
        fldd_for_array.jsofd_type = cd->_.ad.jsoad_member_type;
        fldd = &fldd_for_array;
        dt = fldd->jsofd_type;
        if (idx >= (ptrlong)(BOX_ELEMENTS (inst)))
          {
            if (JSO_STATUS_NEW == inst_rtti->jrtti_status)
              {
                ptrlong newsize = BOX_ELEMENTS (inst);
                void *new_inst;
                if (newsize < 1)
                  newsize = 1;
                while (newsize <= idx) newsize *= 2;
                if (newsize > cd->_.ad.jsoad_max_length)
                  newsize = cd->_.ad.jsoad_max_length;
                new_inst = dk_alloc_box_zero (newsize * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
                memcpy (new_inst, inst, box_length (inst));
                inst = inst_rtti->jrtti_self = new_inst;
	        sethash (new_inst, jso_rttis_of_structs, inst_rtti);
              }
            else
              {
                sqlr_new_error ("22023", "SR511", "Index %ld specified for instance %.500s of RDF array class <%.500s> exceed array length %ld",
                  (long)idx, jinstance, jclass, BOX_ELEMENTS (inst) );
              }
          }
        fld_ptr = (void **)(((caddr_t *)inst) + idx);
        break;
      }
    default: GPF_T1("jso_set_impl (): unknown value of jsocd_cat");
    }
  if (do_set)
    {
      if ((NULL != fld_ptr[0]) && (uname_virtrdf_ns_uri_bitmask != dt))
        sqlr_new_error ("22023", "SR497", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> has been set already",
          jprop, jinstance, jclass );
    }
  else
    {
      if (NULL == fld_ptr[0])
        {
          if (JSO_REQUIRED == fldd->jsofd_required)
            sqlr_new_error ("22023", "SR498", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> is mandatory but it has not been set",
              jprop, jinstance, jclass );
          return NEW_DB_NULL;
        }
    }
  if (uname_xmlschema_ns_uri_hash_any != dt)
    fld_type_cd = gethash (dt, jso_classes);
  else
    fld_type_cd = NULL;
  if (do_set)
    {
      caddr_t arg = bif_arg (qst, args, 3, func_name);
      dtp_t arg_dtp = DV_TYPE_OF (arg);
      caddr_t const_name = NULL, defarg = NULL;
      dtp_t defarg_dtp = 0;
      long arg_is_iri = ((BOX_ELEMENTS (args) > 4) ? bif_long_arg (qst, args, 4, func_name) : (DV_UNAME == DV_TYPE_OF (arg)));
      if ((DV_STRING == arg_dtp) || (DV_UNAME == arg_dtp))
        {
          caddr_t iri_uname = box_dv_uname_string (arg);
          caddr_t boxed_const = gethash (iri_uname, jso_consts);
          if (NULL != boxed_const)
            {
              const_name = arg;
              defarg = arg = boxed_const;
              defarg_dtp = arg_dtp = DV_TYPE_OF (arg);
            }
          dk_free_tree (iri_uname);
        }
      if (NULL != fld_type_cd)
        {
          caddr_t value_iri;
          jso_rtti_t *value_rtti;
          value_iri = (defarg_dtp ? box_dv_uname_string (defarg) : box_cast_to_UTF8_uname (qst, (bif_string_or_wide_or_uname_arg (qst, args, 3, func_name))));
          value_rtti = gethash (value_iri, jso_rttis_of_names);
          if (NULL == value_rtti)
            {
              sqlr_new_error ("22023", "SR512", "JSO instance IRI <%.500s> does not exist",
                value_iri );
            }
          if (JSO_STATUS_DELETED == value_rtti->jrtti_status)
            {
              sqlr_new_error ("22023", "SR537", "JSO instance IRI <%.500s> has been deleted before, type <%.500s>",
                value_iri, value_rtti->jrtti_class->jsocd_class_iri );
            }
          if (fld_type_cd != value_rtti->jrtti_class)
            {
              sqlr_new_error ("22023", "SR513", "JSO instance IRI <%.500s> is of type <%.500s>, required type is <%.500s>",
                value_iri, value_rtti->jrtti_class->jsocd_class_iri, dt );
            }
          fld_ptr[0] = value_rtti;
          goto make_retval; /* see below */
        }
      old_fld_val = fld_ptr[0];
      if (uname_xmlschema_ns_uri_hash_any == dt)
        {
          if (arg_is_iri && (DV_STRING == arg_dtp))
            fld_ptr[0] = box_dv_uname_string (arg);
          else
            fld_ptr[0] = ((NULL == arg) ? box_num_nonull (0) : box_copy_tree (arg));
          goto make_retval; /* see below */
        }
      if (uname_xmlschema_ns_uri_hash_anyURI == dt)
        {
          if (defarg_dtp && (DV_STRING != defarg_dtp) && (DV_UNAME != defarg_dtp))
            sqlr_new_error ("22023", "SR519", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> is an xsd:anyURI, can not set it to constant <%.500s> of type %s",
              jprop, jinstance, jclass, const_name, dv_type_title (defarg_dtp) );
          if ((DV_STRING != arg_dtp) && (DV_UNAME != arg_dtp))
            sqlr_new_error ("22023", "SR520", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> is an xsd:string, can not set it to %s",
              jprop, jinstance, jclass, dv_type_title (arg_dtp) );
          if (defarg_dtp)
            fld_ptr[0] = box_copy (defarg);
          else if (DV_UNAME == arg_dtp)
            fld_ptr[0] = arg;
          else
            fld_ptr[0] = box_cast_to_UTF8 (qst, (bif_string_or_wide_or_null_arg (qst, args, 3, func_name)));
          if (DV_UNAME != DV_TYPE_OF (fld_ptr[0]))
            {
              caddr_t uname = box_dv_uname_string (fld_ptr[0]);
              dk_free_box (fld_ptr[0]);
              fld_ptr[0] = uname;
            }
          goto make_retval; /* see below */
        }
      if (uname_xmlschema_ns_uri_hash_boolean == dt)
        {
          if (defarg_dtp && (DV_LONG_INT != defarg_dtp))
            sqlr_new_error ("22023", "SR517", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> is an xsd:boolean, can not set it to constant <%.500s> of type %s",
              jprop, jinstance, jclass, const_name, dv_type_title (defarg_dtp) );
          if (!IS_NUM_DTP(arg_dtp))
            sqlr_new_error ("22023", "SR506", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> is an xsd:boolean, can not set it to %s",
              jprop, jinstance, jclass, dv_type_title (arg_dtp) );
          fld_ptr[0] = box_num_nonull (defarg_dtp ? unbox(defarg) : bif_long_arg (qst, args, 3, func_name) ? 1 : 0);
          goto make_retval; /* see below */
        }
      if (uname_virtrdf_ns_uri_bitmask == dt)
        {
          if (defarg_dtp && (DV_LONG_INT != defarg_dtp))
            sqlr_new_error ("22023", "SR517", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> is an xsd:bitmask, can not set it to constant <%.500s> of type %s",
              jprop, jinstance, jclass, const_name, dv_type_title (defarg_dtp) );
          if (DV_LONG_INT != arg_dtp)
            sqlr_new_error ("22023", "SR506", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> is an xsd:bitmask, can not set it to %s",
              jprop, jinstance, jclass, dv_type_title (arg_dtp) );
          fld_ptr[0] = box_num_nonull (unbox (fld_ptr[0]) | unbox (defarg_dtp ? defarg : arg));
          goto make_retval; /* see below */
        }
      if (uname_xmlschema_ns_uri_hash_double == dt)
        {
          if (defarg_dtp && (DV_DOUBLE_FLOAT != defarg_dtp))
            sqlr_new_error ("22023", "SR517", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> is an xsd:double, can not set it to constant <%.500s> of type %s",
              jprop, jinstance, jclass, const_name, dv_type_title (defarg_dtp) );
          if (!IS_NUM_DTP(arg_dtp))
            sqlr_new_error ("22023", "SR507", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> is an xsd:double, can not set it to %s",
              jprop, jinstance, jclass, dv_type_title (arg_dtp) );
          fld_ptr[0] = box_double (defarg_dtp ? unbox_double (defarg) : bif_double_arg (qst, args, 3, func_name));
          goto make_retval; /* see below */
        }
      if (uname_xmlschema_ns_uri_hash_integer == dt)
        {
          if (defarg_dtp && (DV_LONG_INT != defarg_dtp))
            sqlr_new_error ("22023", "SR517", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> is an xsd:integer, can not set it to constant <%.500s> of type %s",
              jprop, jinstance, jclass, const_name, dv_type_title (defarg_dtp) );
          if (!IS_NUM_DTP(arg_dtp))
            sqlr_new_error ("22023", "SR505", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> is an xsd:integer, can not set it to %s",
              jprop, jinstance, jclass, dv_type_title (arg_dtp) );
          fld_ptr[0] = box_num_nonull (defarg_dtp ? unbox(defarg) : bif_long_arg (qst, args, 3, func_name));
          goto make_retval; /* see below */
        }
      if (uname_xmlschema_ns_uri_hash_string == dt)
        {
          if (defarg_dtp && (DV_STRING != defarg_dtp) && (DV_UNAME != defarg_dtp))
            sqlr_new_error ("22023", "SR521", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> is an xsd:string, can not set it to constant <%.500s> of type %s",
              jprop, jinstance, jclass, const_name, dv_type_title (defarg_dtp) );
          if (!IS_STRING_DTP(arg_dtp) && (DV_WIDE != arg_dtp))
            sqlr_new_error ("22023", "SR522", "Property <%.500s> of instance <%.500s> of RDF class <%.500s> is an xsd:string, can not set it to %s",
              jprop, jinstance, jclass, dv_type_title (arg_dtp) );
          if (defarg_dtp)
            fld_ptr[0] = box_dv_short_string (defarg);
          else if (DV_UNAME == arg_dtp)
            fld_ptr[0] = box_dv_short_string (arg);
          else
            fld_ptr[0] = box_cast_to_UTF8 (qst, (bif_string_or_wide_or_null_arg (qst, args, 3, func_name)));
          goto make_retval; /* see below */
        }
      sqlr_new_error ("22023", "SR499", "Property <%.500s> of JSO RDF class <%.500s> has unsupported type <%.500s>",
        jprop, jclass, dt );
    }

make_retval:
  if (NULL != fld_type_cd)
    return box_copy (((jso_rtti_t *)(fld_ptr[0]))->jrtti_inst_iri);
/*
  if (IS_BOX_POINTER (fld_ptr[0]) && IS_BOX_POINTER (old_fld_val) &&
     (DV_TYPE_OF (fld_ptr[0]) == DV_TYPE_OF (old_fld_val)) &&
     (box_length (fld_ptr[0]) == box_length (old_fld_val)) &&
     !memcmp (fld_ptr[0], old_fld_val, box_length (old_fld_val)) )
     {
       dk_free_tree (fld_ptr[0]);
       fld_ptr[0] = old_fld_val;
     }
*/
  dk_free_tree (old_fld_val);
  retval = (caddr_t *)(box_copy (fld_ptr[0]));
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (retval))
    {
      int ctr;
      DO_BOX_FAST (caddr_t, el, ctr, retval)
        {
          if (NULL == el)
            retval[ctr] = NEW_DB_NULL;
          else if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (el))
            retval[ctr] = box_dv_uname_string ("vector");
          else if (DV_CUSTOM == DV_TYPE_OF (el))
            retval[ctr] = box_dv_uname_string ("instance");
          else
            retval[ctr] = box_copy_tree (el);
        }
      END_DO_BOX_FAST;
    }
  return (caddr_t)retval;
}

caddr_t
bif_jso_set (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_jso_set_impl (qst, err_ret, args, 1, "jso_set");
}

caddr_t
bif_jso_get (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  return bif_jso_set_impl (qst, err_ret, args, 0, "jso_get");
}

caddr_t
jso_get_field_value_as_o (caddr_t val, ccaddr_t fld_type, int fld_req, ptrlong status)
{
  if (NULL == val)
    {
      if ((JSO_STATUS_LOADED == status) &&
        (!strcmp (JSO_INTEGER, fld_type) ||
          (!strcmp (JSO_ANY, fld_type) && (JSO_REQUIRED == fld_req)) ) )
        return box_num_nonull (0);
      return NULL;
    }
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (val))
    {
      jso_rtti_t *sub = gethash (val, jso_rttis_of_structs);
      if (NULL == sub)
        return box_dv_uname_string (VIRTRDF_NS_URI "PointerToCorrupted");
      else if (sub->jrtti_self != val)
        return box_dv_uname_string (VIRTRDF_NS_URI "PointerToStaleDeleted");
      else
        return box_copy (((jso_rtti_t *)(sub))->jrtti_inst_iri);
    }
  if (DV_CUSTOM == DV_TYPE_OF (val))
    {
      jso_rtti_t *val_as_rtti = (jso_rtti_t *)val;
      return box_copy (val_as_rtti->jrtti_inst_iri);
    }
  return box_copy_tree (val);
}

typedef struct jso_rtti_proplist_acc_s {
  dk_set_t acc_set;
  int acc_only_loaded;
} jso_rtti_proplist_acc_t;

static const char *
jso_status_string (int status)
{
  switch (status)
    {
    case JSO_STATUS_NEW: return "new";
    case JSO_STATUS_LOADED: return "loaded";
    case JSO_STATUS_FAILED: return "failed";
    case JSO_STATUS_DELETED: return "deleted";
    default: return "invalid status ?";
    }
}

void
jso_rtti_proplist (caddr_t iri, jso_rtti_t *rtti, void *acc_env)
{
  jso_rtti_proplist_acc_t *acc = acc_env;
  jso_class_descr_t *cd = rtti->jrtti_class;
  const char *status_strg = jso_status_string (rtti->jrtti_status);
  jso_rtti_t *rtti_of_name = gethash (rtti->jrtti_inst_iri, jso_rttis_of_names);
  jso_rtti_t *rtti_of_self = gethash (rtti->jrtti_self, jso_rttis_of_structs);
  dk_set_push (&(acc->acc_set), list (3, box_copy (iri),
      box_dv_uname_string (VIRTRDF_NS_URI "status"),
      box_sprintf (100, "%s%s", status_strg,
        ((rtti_of_name == rtti) ? "" : ", not key of jso_rttis_of_names"),
        ((rtti_of_self == rtti) ? "" : ", not key of jso_rttis_of_structs") ) ) );
  if (JSO_STATUS_DELETED == rtti->jrtti_status)
    {
      dk_set_push (&(acc->acc_set), list (3, box_copy (iri),
          box_dv_uname_string (VIRTRDF_NS_URI "jso-type"), box_copy_tree (cd->jsocd_class_iri)) );
      return;
    }
  dk_set_push (&(acc->acc_set), list (3, box_copy (iri),
      uname_rdf_ns_uri_type, box_copy_tree (cd->jsocd_class_iri)) );
  switch (cd->jsocd_cat)
    {
    case JSO_CAT_STRUCT:
      {
        int ctr;
        for (ctr = cd->_.sd.jsosd_field_count; ctr--; /* no step */)
          {
            jso_field_descr_t * fldd = cd->_.sd.jsosd_field_list + ctr;
            caddr_t * fld_ptr = JSO_FIELD_PTR(rtti->jrtti_self,fldd);
            caddr_t val, o;
            if (JSO_PRIVATE == fldd->jsofd_required)
              continue;
            val = fld_ptr[0];
            o = jso_get_field_value_as_o (val, fldd->jsofd_type, fldd->jsofd_required, rtti->jrtti_status);
            if (NULL == o)
              {
                if (JSO_STATUS_LOADED != rtti->jrtti_status)
                  continue;
                if ((JSO_OPTIONAL == fldd->jsofd_required) || (JSO_DEPRECATED == fldd->jsofd_required))
                  continue;
              }
            dk_set_push (&(acc->acc_set), list (3, box_copy (iri),
                box_copy (fldd->jsofd_property_iri), o) );
          }
        break;
      }
    case JSO_CAT_ARRAY:
      {
        int ctr;
        DO_BOX_FAST (caddr_t, val, ctr, rtti->jrtti_self)
          {
            char buf[RDF_NS_URI_LEN + 20];
            caddr_t o = jso_get_field_value_as_o (val, cd->_.ad.jsoad_member_type, JSO_REQUIRED, rtti->jrtti_status);
            sprintf (buf, "%s_%d", RDF_NS_URI, ctr+1);
            if (NULL != o)
              dk_set_push (&(acc->acc_set), list (3, box_copy (iri),
                  box_dv_uname_string (buf), o) );
          }
        END_DO_BOX_FAST;
        break;
      }
    default: GPF_T1("jso_rtti_proplist(): bad jsocd_cat");
    }
}


void
jso_class_proplist (caddr_t iri, jso_class_descr_t *cd, void *acc_env)
{
  maphash3 ((maphash3_func) jso_rtti_proplist, cd->jsocd_rttis, acc_env);
}


caddr_t
bif_jso_proplist (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  jso_rtti_proplist_acc_t acc;
  acc.acc_set = NULL;
  acc.acc_only_loaded = 2 & bif_long_arg (qst, args, 0, "jso_proplist");
  if (1 == BOX_ELEMENTS (args))
    maphash3 ((maphash3_func) jso_class_proplist, jso_classes, &acc);
  else
    {
      caddr_t jclass = bif_string_or_wide_or_uname_arg (qst, args, 1, "jso_proplist");
      jso_class_descr_t *cd;
      jclass = box_cast_to_UTF8_uname (qst, jclass);
      cd = gethash (jclass, jso_classes);
      if (NULL == cd)
        {
          sqlr_new_error ("22023", "SR514", "Undefined JSO class IRI <%.500s>", jclass);
        }
      if (2 == BOX_ELEMENTS (args))
        maphash3 ((maphash3_func) jso_rtti_proplist, cd->jsocd_rttis, &acc);
      else
        {
          caddr_t jinstance = bif_string_or_wide_or_uname_arg (qst, args, 2, "jso_proplist");
          jso_rtti_t *inst_rtti;
          jinstance = box_cast_to_UTF8_uname (qst, jinstance);
          inst_rtti = gethash (jinstance, cd->jsocd_rttis);
          if (NULL == inst_rtti)
            {
              sqlr_new_error ("22023", "SR515", "JSO instance IRI <%.500s> does not exist", jinstance);
            }
          jso_rtti_proplist (inst_rtti->jrtti_inst_iri, inst_rtti, &acc);
        }
    }
  return list_to_array (acc.acc_set);
}

caddr_t
bif_jso_dbg_dump_rtti (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
#ifdef DEBUG
  jso_rtti_t *rtti;
  jso_rtti_t *rtti_of_name;
  jso_rtti_t *rtti_of_self;
#endif
  caddr_t res;
  sec_check_dba ((query_instance_t *)qst, "jso_dbg_dump_rtti");
#ifdef DEBUG
  rtti = ((jso_rtti_t *)((void *)bif_arg (qst, args, 0, "jso_dbg_dump_rtti")))->jrtti_loop;
  rtti_of_name = (jso_rtti_t *)gethash (rtti->jrtti_inst_iri, jso_rttis_of_names);
  rtti_of_self = (jso_rtti_t *)gethash (rtti->jrtti_self, jso_rttis_of_structs);
  res = box_sprintf (1000,
    "DV_CUSTOM (rtti STATUS=%s(%d), %s, self %s, IRI=%.300s, CLASS=%.300s)",
    jso_status_string (rtti->jrtti_status), rtti->jrtti_status,
    ((rtti_of_name == rtti) ? "rtti of name matches" : "not key of jso_rttis_of_names"),
    ((rtti_of_self == rtti) ? "rtti of self matches" : "not key of jso_rttis_of_structs"),
    rtti->jrtti_inst_iri, rtti->jrtti_class->jsocd_class_iri );
#else
  res = box_dv_short_string ("DV_CUSTOM (sorry, function jso_dbg_dump_rtti () works well only in debug build of Virtuoso)");
#endif
  return res;
}

caddr_t
jso_triple_add (caddr_t * qst, caddr_t jsubj, caddr_t jpred, caddr_t jobj)
{
  caddr_t new_jsubj;
  caddr_t new_jpred;
  caddr_t new_jobj;
  dk_hash_t *jso_single_subj;
  dk_hash_t *jso_single_pred;
  dk_hash_t *jso_single_obj;
  dk_set_t jso_objs;
  dk_set_t jso_subjs;
  new_jsubj = jsubj = box_cast_to_UTF8_uname (qst, jsubj);
  new_jpred = jpred = box_cast_to_UTF8_uname (qst, jpred);
  new_jobj = jobj = box_cast_to_UTF8_uname (qst, jobj);
  jso_single_subj = (dk_hash_t *)gethash (jsubj, jso_triple_subjs);
  if (NULL == jso_single_subj)
    {
      jso_single_subj = hash_table_allocate (13);
      sethash (new_jsubj, jso_triple_subjs, jso_single_subj);
      new_jsubj = NULL;
    }
  jso_single_pred = (dk_hash_t *)gethash (jpred, jso_triple_preds);
  if (NULL == jso_single_pred)
    {
      jso_single_pred = hash_table_allocate (251);
      sethash (new_jpred, jso_triple_preds, jso_single_pred);
      new_jpred = NULL;
    }
  jso_single_obj = (dk_hash_t *)gethash (jobj, jso_triple_objs);
  if (NULL == jso_single_obj)
    {
      jso_single_obj = hash_table_allocate (13);
      sethash (new_jobj, jso_triple_objs, jso_single_obj);
      new_jobj = NULL;
    }
  jso_objs = (dk_set_t)gethash (jpred, jso_single_subj);
#ifdef DEBUG
  if (jso_objs != gethash (jsubj, jso_single_pred))
    GPF_T1 ("jso_triple_add(): gethash (jpred, gethash (jsubj, jso_triple_subjs)) != gethash (jsubj, gethash (jpred, jso_triple_preds))");
#endif
  if (NULL == dk_set_member (jso_objs, jobj))
    {
      if (NULL == new_jobj)
        new_jobj = box_copy (jobj);
      dk_set_push (&jso_objs, jobj);
      new_jobj = NULL;
      sethash (jpred, jso_single_subj, jso_objs);
      sethash (jsubj, jso_single_pred, jso_objs);
    }
  jso_subjs = (dk_set_t)gethash (jpred, jso_single_obj);
  if (NULL == dk_set_member (jso_subjs, jsubj))
    {
      if (NULL == new_jsubj)
        new_jsubj = box_copy (jsubj);
      dk_set_push (&jso_subjs, jsubj);
      new_jsubj = NULL;
      sethash (jpred, jso_single_obj, jso_subjs);
    }
  dk_free_box (new_jsubj);
  dk_free_box (new_jpred);
  dk_free_box (new_jobj);
  return 0;
}

caddr_t *
jso_triple_get_objs_impl (caddr_t * qst, caddr_t jsubj, caddr_t jpred, dk_hash_t *top_hash)
{
  dk_hash_t *jso_single_subj;
  dk_set_t jso_objs;
  caddr_t *res;
  int ctr, len;
  jsubj = box_cast_to_UTF8_uname (qst, jsubj);
  jso_single_subj = (dk_hash_t *)gethash (jsubj, top_hash);
  if (NULL == jso_single_subj)
    {
      dk_free_box (jsubj);
      return (caddr_t *)list (0);
    }
  jpred = box_cast_to_UTF8_uname (qst, jpred);
  jso_objs = (dk_set_t)gethash (jpred, jso_single_subj);
  if (NULL == jso_objs)
    {
      dk_free_box (jsubj);
      dk_free_box (jpred);
      return (caddr_t *)list (0);
    }
  len = dk_set_length (jso_objs);
  res = (caddr_t *)dk_alloc_box (len * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  ctr = 0;
  while (NULL != jso_objs)
    {
      res[ctr++] = box_copy ((caddr_t)(jso_objs->data));
      jso_objs = jso_objs->next;
    }
  return res;
}

caddr_t *
jso_triple_get_objs (caddr_t * qst, caddr_t jsubj, caddr_t jpred)
{
  return jso_triple_get_objs_impl (qst, jsubj, jpred, jso_triple_subjs);
}

caddr_t *
jso_triple_get_subjs (caddr_t * qst, caddr_t jpred, caddr_t jobj)
{
  return jso_triple_get_objs_impl (qst, jobj, jpred, jso_triple_objs); /* Trick: we swap subj and obj and pass 'wrong' hashtable */
}


caddr_t
bif_jso_triple_add (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t jsubj = bif_string_or_wide_or_uname_arg (qst, args, 0, "jso_triple_add");
  caddr_t jpred = bif_string_or_wide_or_uname_arg (qst, args, 1, "jso_triple_add");
  caddr_t jobj = bif_string_or_wide_or_uname_arg (qst, args, 2, "jso_triple_add");
  return jso_triple_add (qst, jsubj, jpred, jobj);
}

caddr_t
bif_jso_triple_get_objs (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t jsubj = bif_string_or_wide_or_uname_arg (qst, args, 0, "jso_triple_get_objs");
  caddr_t jpred = bif_string_or_wide_or_uname_arg (qst, args, 1, "jso_triple_get_objs");
  return (caddr_t)jso_triple_get_objs (qst, jsubj, jpred);
}

caddr_t
bif_jso_triple_get_subjs (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t jpred = bif_string_or_wide_or_uname_arg (qst, args, 0, "jso_triple_get_subjs");
  caddr_t jobj = bif_string_or_wide_or_uname_arg (qst, args, 1, "jso_triple_get_subjs");
  return (caddr_t)jso_triple_get_subjs (qst, jpred, jobj);
}

void
jso_triple_sp_objlist (caddr_t pred, dk_set_t jso_objs, void *acc_env)
{
  caddr_t subj = ((caddr_t *)acc_env)[0];
  dk_set_t *res = ((dk_set_t *)acc_env)+1;
  DO_SET (caddr_t, obj, &jso_objs)
    {
      dk_set_push (res, list (3, box_copy_tree (subj), box_copy_tree (pred), box_copy_tree (obj)));
    }
  END_DO_SET ()
}

void
jso_triple_subj_predlist (caddr_t subj, dk_hash_t *jso_single_subj, void *acc_env)
{
  ((caddr_t *)acc_env)[0] = subj;
  maphash3 ((maphash3_func) jso_triple_sp_objlist, jso_single_subj, acc_env);
}

caddr_t
bif_jso_triple_list (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  void *acc_env[2];
  acc_env[0] = NULL;
  acc_env[1] = NULL;
  maphash3 ((maphash3_func) jso_triple_subj_predlist, jso_triple_subjs, (void *)acc_env);
  return revlist_to_array (acc_env[1]);
}

caddr_t
bif_jso_mark_affected (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t inst_raw = bif_string_or_wide_or_uname_arg (qst, args, 0, "jso_mark_affected");
  caddr_t inst = box_cast_to_UTF8_uname (qst, inst_raw);
  jso_mark_affected (inst);
  return inst;
}

/* JSO digest layout is as following:
2-byte type (i.e. 0-th item of jso), LSB first
Up to 20 first bytes of string value (i.e. 1-st item of jso).
Zero byte.
4-byte ID (i.e. 3-rd item of jso), LSB first, MSB last
2-byte language (i.e. 2-th item of jso), LSB first
The whole digest can be cached as 4-th item of jso.
 */

caddr_t
bif_jso_make_digest (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  int argcount = BOX_ELEMENTS (args);
  caddr_t *longobj;
  caddr_t strg = NULL, old_digest = NULL;
  unsigned char buf[30];
  unsigned char *buf_tail;
  ptrlong dt_idx = 0, lang_idx = 0, obj_id = 0;
  int strg_len;
  switch (argcount)
    {
    case 1:
      longobj = (caddr_t *)bif_array_arg (qst, args, 0, "jso_make_digest");
      if ((DV_ARRAY_OF_POINTER != DV_TYPE_OF (longobj)) || (5 > BOX_ELEMENTS (longobj)))
        sqlr_new_error ("22023", "SR542", "Argument of jso_make_digest() is not a JSO (type %d)", DV_TYPE_OF (longobj));
      if (DV_STRING == DV_TYPE_OF (longobj[4]))
        return box_copy (longobj[4]);
      if (DV_LONG_INT != DV_TYPE_OF (longobj[0]))
        sqlr_new_error ("22023", "SR542", "Argument of jso_make_digest() is not a JSO (type of [0] %d)", DV_TYPE_OF (longobj[0]));
      dt_idx = unbox (longobj[0]);
      strg = longobj[1];
      if (DV_STRING != DV_TYPE_OF (strg))
        sqlr_new_error ("22023", "SR542", "Argument of jso_make_digest() is not a JSO (type of [1] %d)", DV_TYPE_OF (strg));
      if (DV_LONG_INT != DV_TYPE_OF (longobj[2]))
        sqlr_new_error ("22023", "SR542", "Argument of jso_make_digest() is not a JSO (type of [2] %d)", DV_TYPE_OF (longobj[2]));
      lang_idx = unbox (longobj[2]);
      if (DV_LONG_INT != DV_TYPE_OF (longobj[3]))
        sqlr_new_error ("22023", "SR542", "Argument of jso_make_digest() is not a JSO (type of [3] %d)", DV_TYPE_OF (longobj[3]));
      obj_id = unbox (longobj[3]);
      break;
    case 5:
      old_digest = bif_arg (qst, args, 4, "jso_make_digest");
      if (DV_STRING == DV_TYPE_OF (old_digest))
        return box_copy (old_digest);
      /* no break */
    case 4:
      dt_idx = bif_long_arg (qst, args, 0, "jso_make_digest");
      strg = bif_string_arg (qst, args, 1, "jso_make_digest");
      lang_idx = bif_long_arg (qst, args, 2, "jso_make_digest");
      obj_id = bif_long_arg (qst, args, 3, "jso_make_digest");
      break;
    default:
      sqlr_new_error ("22023", "SR542", "%d arguments in call of jso_make_digest(), should be 1, 4 or 5", argcount);
    }
  if (dt_idx & ~0xffff)
    sqlr_new_error ("22023", "SR542", "Argument of jso_make_digest() is not a JSO ([0]=%ld)", (long)dt_idx);
  if (lang_idx & ~0xffff)
    sqlr_new_error ("22023", "SR542", "Argument of jso_make_digest() is not a JSO ([2]=%ld)", (long)lang_idx);
  if (!obj_id)
    sqlr_new_error ("22023", "SR542", "Argument of jso_make_digest() is not a JSO ([3]=%ld)", (long)obj_id);
  buf_tail = buf;
  (buf_tail++)[0] = (unsigned char)dt_idx;
  (buf_tail++)[0] = (unsigned char)(dt_idx >> 8);
  strg_len = box_length (strg) - 1;
  if (strg_len > 20)
    strg_len = 20;
  memcpy (buf_tail, strg, strg_len);
  buf_tail += strg_len;
  (buf_tail++)[0] = '\0';
  (buf_tail++)[0] = (unsigned char)obj_id;
  (buf_tail++)[0] = (unsigned char)(obj_id >> 8);
  (buf_tail++)[0] = (unsigned char)(obj_id >> 16);
  (buf_tail++)[0] = (unsigned char)(obj_id >> 24);
  (buf_tail++)[0] = (unsigned char)lang_idx;
  (buf_tail++)[0] = (unsigned char)(lang_idx >> 8);
  return box_dv_short_nchars ((char *)buf, buf_tail-buf);
}

caddr_t
bif_jso_parse_digest (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  unsigned char *buf = (unsigned char *) bif_string_arg (qst, args, 0, "jso_parse_digest");
  size_t buf_len = box_length (buf) - 1;
  unsigned char *buf_end = buf + buf_len;
  ptrlong dt, obj_idx, lang;
  if ((29 < buf_len) || (9 > buf_len))
    sqlr_new_error ("22023", "SR543", "Argument of jso_parse_digest() is not valid (length = %ld)", (long)(buf_len));
  if ('\0' != buf_end[-7])
    sqlr_new_error ("22023", "SR543", "Argument of jso_parse_digest() is not valid (bad syntax)");
  dt = buf[0] | (buf[1] << 8);
  obj_idx = buf_end[-6] | (buf_end[-5] << 8) | (buf_end[-4] << 16) | (buf_end[-3] << 24);
  lang = buf_end[-2] | (buf_end[-1] << 8);
  return list (5, dt, box_dv_short_nchars ((char *)(buf + 2), buf_len - 9), lang,
    box_num (obj_idx), box_dv_short_nchars ((char *)buf, buf_len) );
}


jso_class_descr_t jso_cd_array_of_any;
jso_class_descr_t jso_cd_array_of_string;

void jso_init ()
{
  jso_consts = hash_table_allocate (61);
  jso_classes = hash_table_allocate (13);
  jso_properties = hash_table_allocate (97);
  jso_rttis_of_names = hash_table_allocate (251);
  jso_rttis_of_structs = hash_table_allocate (251);
  jso_triple_subjs = hash_table_allocate (1021);
  jso_triple_preds = hash_table_allocate (251);
  jso_triple_objs = hash_table_allocate (1021);
  jso_cd_array_of_any.jsocd_c_typedef = "caddr_t *";
  jso_cd_array_of_any.jsocd_cat = JSO_CAT_ARRAY;
  jso_cd_array_of_any.jsocd_class_iri = uname_virtrdf_ns_uri_array_of_any;
  jso_cd_array_of_any.jsocd_ns_uri = uname_virtrdf_ns_uri;
  jso_cd_array_of_any.jsocd_local_name = "array-of-any";
  jso_cd_array_of_any._.ad.jsoad_member_type = uname_xmlschema_ns_uri_hash_any;
  jso_cd_array_of_any._.ad.jsoad_max_length = MAX_BOX_ELEMENTS;
  jso_define_class (&jso_cd_array_of_any);
  jso_cd_array_of_string.jsocd_c_typedef = "caddr_t *";
  jso_cd_array_of_string.jsocd_cat = JSO_CAT_ARRAY;
  jso_cd_array_of_string.jsocd_class_iri = uname_virtrdf_ns_uri_array_of_string;
  jso_cd_array_of_string.jsocd_ns_uri = uname_virtrdf_ns_uri;
  jso_cd_array_of_string.jsocd_local_name = "array-of-string";
  jso_cd_array_of_string._.ad.jsoad_member_type = uname_xmlschema_ns_uri_hash_string;
  jso_cd_array_of_string._.ad.jsoad_max_length = MAX_BOX_ELEMENTS;
  jso_define_class (&jso_cd_array_of_string);
  bif_define ("jso_new", bif_jso_new);
  bif_define ("jso_delete", bif_jso_delete);
  bif_define ("jso_validate", bif_jso_validate);
  bif_define ("jso_pin", bif_jso_pin);
  bif_define ("jso_set", bif_jso_set);
  bif_define ("jso_get", bif_jso_get);
  bif_define ("jso_proplist", bif_jso_proplist);
  bif_define ("jso_dbg_dump_rtti", bif_jso_dbg_dump_rtti);
  bif_define ("jso_triple_add", bif_jso_triple_add);
  bif_define ("jso_triple_get_objs", bif_jso_triple_get_objs);
  bif_define ("jso_triple_get_subjs", bif_jso_triple_get_subjs);
  bif_define ("jso_triple_list", bif_jso_triple_list);
  bif_define ("jso_mark_affected", bif_jso_mark_affected);
  bif_define ("jso_make_digest", bif_jso_make_digest);
  bif_define ("jso_parse_digest", bif_jso_parse_digest);
}
