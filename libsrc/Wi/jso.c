/*
 *  jso.c
 *
 *  $Id$
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

#include "jso.h"
#include "sqlbif.h"

dk_hash_t *jso_consts = NULL;
dk_hash_t *jso_classes = NULL;
dk_hash_t *jso_properties = NULL;
dk_hash_t *jso_rttis = NULL;

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
  void *inst;
  jso_rtti_t *inst_rtti;
  jclass = box_cast_to_UTF8_uname (qst, jclass);
  cd = gethash (jclass, jso_classes);
  if (NULL == cd)
    {
      sqlr_new_error ("22023", "SR491", "Undefined JSO class IRI <%.500s>", jclass);
    }
  jinstance = box_cast_to_UTF8_uname (qst, jinstance);
  inst_rtti = gethash (jinstance, jso_rttis);
  if ((NULL != inst_rtti) && (JSO_STATUS_DELETED != inst_rtti->jrtti_status))
    {
      sqlr_new_error ("22023", "SR492", "JSO instance IRI <%.500s> already exists, type <%.500s>",
        jinstance, inst_rtti->jrtti_class->jsocd_class_iri );
    }
  if (NULL == inst_rtti)
    {
      inst_rtti = dk_alloc_box_zero (sizeof (jso_rtti_t), DV_ARRAY_OF_POINTER);
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
      sethash (jinstance, jso_rttis, inst_rtti);
      sethash (jinstance, cd->jsocd_rttis, inst_rtti);
    }
  inst_rtti->jrtti_status = JSO_STATUS_NEW;
  return box_copy (jinstance);
}


void
jso_get_cd_and_rtti (ccaddr_t jclass, ccaddr_t jinstance, jso_class_descr_t **cd_ptr, jso_rtti_t **inst_rtti_ptr, int quiet_if_deleted)
{
  cd_ptr[0] = gethash (jclass, jso_classes);
  if (NULL == cd_ptr[0])
    {
      sqlr_new_error ("22023", "SR500", "Undefined JSO class IRI <%.500s>", jclass);
    }
  inst_rtti_ptr[0] = gethash (jinstance, jso_rttis);
  if (NULL == inst_rtti_ptr[0])
    {
      if (!quiet_if_deleted)
        sqlr_new_error ("22023", "SR501", "JSO instance IRI <%.500s> does not exists",
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
  if (cd_ptr[0] != inst_rtti_ptr[0]->jrtti_class)
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
  jclass = box_cast_to_UTF8_uname (qst, jclass);
  jinstance = box_cast_to_UTF8_uname (qst, jinstance);
  jso_get_cd_and_rtti (jclass, jinstance, &cd, &inst_rtti, quiet);
  if (NULL == inst_rtti)
    return jinstance;
  switch (cd->jsocd_cat)
    {
    case JSO_CAT_STRUCT: memset (inst_rtti->jrtti_self, 0, cd->_.sd.jsosd_sizeof); break;
    case JSO_CAT_ARRAY: memset (inst_rtti->jrtti_self, 0, box_length (inst_rtti->jrtti_self)); break;
    default: GPF_T1("jso_delete (): unknown value of jsocd_cat");
    }
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
        int full_length = BOX_ELEMENTS (inst);
        if (full_length > cd->_.ad.jsoad_min_length)
          {
            int used_length = full_length;
            int ctr;
            while ((0 < used_length) && (NULL == inst[used_length - 1])) used_length--;
            if (used_length < cd->_.ad.jsoad_min_length)
              {
                SET_STATUS_FAILED;
                sqlr_new_error ("22023", "SR526", "JSO array instance <%.500s> of type <%.500s> is only %ld items long, should have at least %ld",
                  inst_rtti->jrtti_inst_iri, inst_rtti->jrtti_class->jsocd_class_iri, (long)used_length, (long)(cd->_.ad.jsoad_min_length) );
              }
            for (ctr = 0; ctr < used_length; ctr++)
              if (NULL == inst[ctr])
                {
                  SET_STATUS_FAILED;
                  sqlr_new_error ("22023", "SR527", "JSO array instance <%.500s> of type <%.500s> contains unitialized element %ld",
                    inst_rtti->jrtti_inst_iri, inst_rtti->jrtti_class->jsocd_class_iri, (long)ctr );
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
            if (NULL != JSO_FIELD_PTR (inst, fldd)[0])
              {
                if ((JSO_DEPRECATED == fldd->jsofd_required) && !change_status)
                  {
                    SET_STATUS_FAILED;
                    sqlr_new_error ("22023", "SR529", "Deprecated property %.500s is set in JSO instance <%.500s> of type <%.500s>",
                      fldd->jsofd_local_name, inst_rtti->jrtti_inst_iri, inst_rtti->jrtti_class->jsocd_class_iri );
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
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF(sub))
        jso_validate (sub, root_rtti, known, change_status);
    }
  END_DO_BOX_FAST;
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
  caddr_t *inst, sub;
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
            }
        }
    }
  sethash (inst, known, inst_rtti);
  DO_BOX_FAST (jso_rtti_t *, sub, ctr, inst)
    {
      if (DV_ARRAY_OF_POINTER == DV_TYPE_OF(sub))
        jso_pin (sub, root_rtti, known);
    }
  END_DO_BOX_FAST;
  for (ctr = BOX_ELEMENTS(inst); ctr--; /*no step*/)
    {
      sub = inst[ctr];
      switch (DV_TYPE_OF(sub))
        {
        case DV_ARRAY_OF_POINTER:
          if (NULL != sub)
            inst[ctr] = ((jso_rtti_t *)sub)->jrtti_self;
          break;
        case DV_LONG_INT:
          ((ptrlong *)(inst+ctr))[0] = unbox (inst[ctr]);
          break;
        case DV_DOUBLE_FLOAT:
          if (NULL != sub)
            ((double *)(inst+ctr))[0] = unbox_double (inst[ctr]);
          else
            ((double *)(inst+ctr))[0] = 0;
          break;
        default: break;
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
  caddr_t jprop;
  ccaddr_t dt = NULL;
  caddr_t *retval;
  jso_class_descr_t *cd, *fld_type_cd;
  jso_field_descr_t fldd_for_array;
  jso_field_descr_t *fldd;
  void *inst;
  jso_rtti_t *inst_rtti;
  void **fld_ptr;
  jclass = box_cast_to_UTF8_uname (qst, jclass);
  cd = gethash (jclass, jso_classes);
  if (NULL == cd)
    sqlr_new_error ("22023", "SR493", "Undefined JSO class IRI <%.500s>", jclass);
  jinstance = box_cast_to_UTF8_uname (qst, jinstance);
  inst_rtti = gethash (jinstance, jso_rttis);
  if (NULL == inst_rtti)
    {
      sqlr_new_error ("22023", "SR494", "JSO instance IRI <%.500s> does not exists", jinstance);
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
      fld_ptr = JSO_FIELD_PTR(inst,fldd);
      dt = fldd->jsofd_type;
      break;
    case JSO_CAT_ARRAY:
      {
        dtp_t jprop_dtp;
        ptrlong idx;
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
                void *newinst;
                if (newsize < 1)
                  newsize = 1;
                while (newsize <= idx) newsize *= 2;
                if (newsize > cd->_.ad.jsoad_max_length)
                  newsize = cd->_.ad.jsoad_max_length;
                newinst = dk_alloc_box_zero (newsize * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
                memcpy (newinst, inst, box_length (inst));
                inst = inst_rtti->jrtti_self = newinst;
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
  fld_type_cd = gethash (dt, jso_classes);
  if (do_set)
    {
      caddr_t arg = bif_arg (qst, args, 3, func_name);
      dtp_t arg_dtp = DV_TYPE_OF (arg);
      caddr_t const_name, defarg = NULL;
      dtp_t defarg_dtp = 0;
      if ((DV_STRING == DV_TYPE_OF (arg)) || (DV_UNAME == DV_TYPE_OF (arg)))
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
          value_iri = box_dv_uname_string (defarg_dtp ? box_copy (defarg) : box_cast_to_UTF8 (qst, (bif_string_or_wide_or_uname_arg (qst, args, 3, func_name))));
          value_rtti = gethash (value_iri, jso_rttis);
          if (NULL == value_rtti)
            {
              sqlr_new_error ("22023", "SR512", "JSO instance IRI <%.500s> does not exists",
                value_iri );
            }
          if (JSO_STATUS_DELETED == value_rtti->jrtti_status)
            {
              sqlr_new_error ("22023", "SR512", "JSO instance IRI <%.500s> has been deleted before, type <%.500s>",
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
      if (uname_xmlschema_ns_uri_hash_any == dt)
        {
          fld_ptr[0] = ((NULL == arg) ? box_num_nonull (0) : arg);
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
  retval = (caddr_t *)(box_copy (fld_ptr[0]));
  if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (retval))
    {
      int ctr;
      DO_BOX_FAST (caddr_t, el, ctr, retval)
        {
          if (NULL == el)
            retval[ctr] = NEW_DB_NULL;
          else if (DV_TYPE_OF (el) == DV_ARRAY_OF_POINTER)
            retval[ctr] = box_dv_uname_string ("vector");
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


void
jso_rtti_proplist (caddr_t iri, jso_rtti_t *rtti, void *env)
{
  jso_class_descr_t *cd = rtti->jrtti_class;
  if (JSO_STATUS_DELETED == rtti->jrtti_status)
    return;
  dk_set_push (env, list (3, box_copy (iri), uname_rdf_ns_uri_type, box_copy_tree (cd->jsocd_class_iri)));
  switch (cd->jsocd_cat)
    {
    case JSO_CAT_STRUCT:
      {
        int ctr;
        for (ctr = cd->_.sd.jsosd_field_count; ctr--; /* no step */)
          {
            jso_field_descr_t * fldd = cd->_.sd.jsosd_field_list + ctr;
            caddr_t * fld_ptr = JSO_FIELD_PTR(rtti->jrtti_self,fldd);
            caddr_t val = fld_ptr[0];
            if (NULL == val)
              continue;
            if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (val))
              val = ((jso_rtti_t *)(val))->jrtti_inst_iri;
            dk_set_push (env, list (3, box_copy (iri), box_copy (fldd->jsofd_property_iri), box_copy_tree (val)));
          }
        break;
      }
    case JSO_CAT_ARRAY:
      {
        int ctr;
        DO_BOX_FAST (caddr_t, val, ctr, rtti->jrtti_self)
          {
            char buf[RDF_NS_URI_LEN + 20];
            if (NULL == val)
              continue;
            if (DV_ARRAY_OF_POINTER == DV_TYPE_OF (val))
              val = ((jso_rtti_t *)(val))->jrtti_inst_iri;
            sprintf (buf, "%s_%d", RDF_NS_URI, ctr+1);
            dk_set_push (env, list (3, box_copy (iri), box_dv_uname_string(buf), box_copy_tree (val)));
          }
        END_DO_BOX_FAST;
        break;
      }
    default: GPF_T1("jso_rtti_proplist(): bad jsocd_cat");
    }
}


void
jso_class_proplist (caddr_t iri, jso_class_descr_t *cd, void *env)
{
  maphash3 (jso_rtti_proplist, cd->jsocd_rttis, env);
}


caddr_t
bif_jso_proplist (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  dk_set_t acc_set = NULL;
  dk_set_t *acc_set_ptr = &acc_set;
  if (0 == BOX_ELEMENTS (args))
    maphash3 (jso_class_proplist, jso_classes, acc_set_ptr);
  else
    {
      caddr_t jclass = bif_string_or_wide_or_uname_arg (qst, args, 0, "jso_proplist");
      jso_class_descr_t *cd;
      jclass = box_cast_to_UTF8_uname (qst, jclass);
      cd = gethash (jclass, jso_classes);
      if (NULL == cd)
        {
          sqlr_new_error ("22023", "SR514", "Undefined JSO class IRI <%.500s>", jclass);
        }
      if (0 == BOX_ELEMENTS (args))
        maphash3 (jso_rtti_proplist, cd->jsocd_rttis, acc_set_ptr);
      else
        {
          caddr_t jinstance = bif_string_or_wide_or_uname_arg (qst, args, 1, "jso_proplist");
          jso_rtti_t *inst_rtti;
          jinstance = box_cast_to_UTF8_uname (qst, jinstance);
          inst_rtti = gethash (jinstance, cd->jsocd_rttis);
          if (NULL == inst_rtti)
            {
              sqlr_new_error ("22023", "SR515", "JSO instance IRI <%.500s> does not exists", jinstance);
            }
          jso_rtti_proplist (inst_rtti->jrtti_inst_iri, inst_rtti, acc_set_ptr);
        }
    }
  return list_to_array (acc_set);
}

void jso_init ()
{
  jso_consts = hash_table_allocate (61);
  jso_classes = hash_table_allocate (13);
  jso_properties = hash_table_allocate (97);
  jso_rttis = hash_table_allocate (251);
  bif_define ("jso_new", bif_jso_new);
  bif_define ("jso_delete", bif_jso_delete);
  bif_define ("jso_validate", bif_jso_validate);
  bif_define ("jso_pin", bif_jso_pin);
  bif_define ("jso_set", bif_jso_set);
  bif_define ("jso_get", bif_jso_get);
  bif_define ("jso_proplist", bif_jso_proplist);
}
