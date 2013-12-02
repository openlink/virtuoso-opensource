/*
 *  xmllazy.c
 *
 *  $Id$
 *
 *  A stub XML entity that is a container for data of lazy loader of XML trees
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

#include "libutil.h"
#include "sqlnode.h"
#include "lisprdr.h"
#include "sqlpar.h"
#include "sqlpfn.h"
#include "sqlcmps.h"
#include "sqlfn.h"
#include "xml.h"
#include "xmlgen.h"
#include "xmltree.h"
#include "xpf.h"
#include "arith.h"
#include "sqlbif.h"
#include "math.h"
#include "text.h"
#include "bif_xper.h"
#include "security.h"
#include "srvmultibyte.h"
#include "xml_ecm.h"
#include "http.h"
#include "sqltype.h" /* for XMLTYPE_TO_ENTITY */
#ifdef __cplusplus
extern "C" {
#endif
#include "xmlparser_impl.h"
#ifdef __cplusplus
}
#endif
#include "xpathp_impl.h"
#include "xpathp.h"

struct xe_class_s xec_lazy_xe;

xml_lazy_ent_t *
DBG_NAME(xlazye_from_cache_key) (DBG_PARAMS xml_doc_cache_stdkey_t *cache_key, query_instance_t *qi)
{
  xml_lazy_ent_t * xlazye = (xml_lazy_ent_t*) dk_alloc_box_zero (sizeof (xml_entity_un_t), DV_XML_ENTITY);
  NEW_BOX_VARZ (xml_lazy_doc_t, xlazyd);
  xlazye->_ = &xec_lazy_xe;
#ifdef MALLOC_DEBUG
  xlazyd->xd_dbg_file = file;
  xlazyd->xd_dbg_line = line;
#endif
  xlazyd->xd_qi = qi_top_qi (qi);
  xlazyd->xd_top_doc = (xml_doc_t *) xlazyd;
  xlazyd->xd_ref_count = 1;
  xlazyd->xlazyd_cache_key = cache_key;
  xlazyd->xd_default_lh = server_default_lh;
  xlazyd->xd_cost = 0; /* Costs nothing */
  xlazyd->xd_weight = 0; /* Unknown */
  xlazye->xe_doc.xlazyd = xlazyd;
  xlazye->xe_doc.xd->xd_uri = cache_key->xdcs_abs_uri;
  dk_set_push (&(xlazyd->xlazyd_entities), xlazye);
  return xlazye;
}

void
xlazye_make_actual_load (xml_entity_t *xe)
{
  xml_lazy_ent_t *xlazye = (xml_lazy_ent_t *)xe;
  xml_doc_cache_stdkey_t *cache_key = xlazye->xe_doc.xlazyd->xlazyd_cache_key;
  query_instance_t *qi = xlazye->xe_doc.xd->xd_qi;
  xml_ns_2dict_t ns_2dict;
  xml_entity_t * loaded_xe;
  xml_doc_t *loaded_doc;
  dtd_t *doc_dtd = NULL;
  id_hash_t *id_cache = NULL;
  caddr_t doc_text, doc_tree, loading_error = NULL;
  dk_set_t all_lazy_entities;
  ns_2dict.xn2_size = 0;
  doc_text = xml_uri_get (qi, &loading_error, NULL, NULL /* = no base uri */, cache_key->xdcs_abs_uri, XML_URI_STRING_OR_ENT);
  if (DV_XML_ENTITY == DV_TYPE_OF (doc_text)) /* if comes from LONG XML column via virt://... */
    {
      loaded_xe = (xml_entity_t *)doc_text;
      goto loaded_xe_is_ready;
    }
  if (loading_error)
    goto loading_error;
  doc_tree = xml_make_mod_tree (qi, doc_text, (caddr_t *) &loading_error,
    cache_key->xdcs_parser_mode, cache_key->xdcs_abs_uri,
    cache_key->xdcs_enc_name, cache_key->xdcs_lang_ptr[0], cache_key->xdcs_dtd_cfg,
    &doc_dtd, &id_cache, &ns_2dict );
  if (loading_error)
    goto loading_error;

  loaded_xe = (xml_entity_t *)xte_from_tree (doc_tree, qi);
  loaded_xe->xe_doc.xd->xd_dtd = doc_dtd; /* Refcounter added inside xml_make_tree */
  loaded_xe->xe_doc.xd->xd_uri = cache_key->xdcs_abs_uri;
  loaded_xe->xe_doc.xd->xd_id_dict = id_cache;
  loaded_xe->xe_doc.xd->xd_id_scan = XD_ID_SCAN_COMPLETED;
  loaded_xe->xe_doc.xd->xd_ns_2dict = ns_2dict;
  dk_free_box (doc_text);

loaded_xe_is_ready:
  all_lazy_entities = xlazye->xe_doc.xlazyd->xlazyd_entities;
  xlazye->xe_doc.xlazyd->xlazyd_cache_key = NULL;
  loaded_doc = loaded_xe->xe_doc.xd;
  if (XE_IS_TREE (loaded_xe))
    {
      memcpy (xlazye->xe_doc.xd, loaded_doc, sizeof (xml_tree_doc_t));
      dk_free (loaded_doc, sizeof (xml_tree_doc_t));
    }
  else
    {
      memcpy (xlazye->xe_doc.xd, loaded_doc, sizeof (xper_doc_t));
      dk_free (loaded_doc, sizeof (xper_doc_t));
    }
  xlazye->xe_doc.xd->xd_top_doc = xlazye->xe_doc.xd;
  loaded_xe->xe_doc.xd = xlazye->xe_doc.xd;
  while (NULL != all_lazy_entities)
    {
      xml_entity_t *copy = dk_set_pop (&all_lazy_entities);
      memcpy (copy, loaded_xe, sizeof (xml_entity_un_t));
      if (XE_IS_TREE (loaded_xe))
        {
          xml_tree_ent_t *loaded_xte = (xml_tree_ent_t *)loaded_xe;
          xml_tree_ent_t *copy_xte = (xml_tree_ent_t *)copy;
          size_t stack_elems = loaded_xte->xte_stack_max - loaded_xte->xte_stack_buf;
          copy_xte->xte_stack_buf = (xte_bmk_t *) dk_alloc (stack_elems * sizeof (xte_bmk_t));
          copy_xte->xte_stack_max = copy_xte->xte_stack_buf + stack_elems;
          memcpy (copy_xte->xte_stack_buf, loaded_xte->xte_stack_buf,
            (char *)(loaded_xte->xte_stack_top + 1) - (char *)(loaded_xte->xte_stack_buf) );
          copy_xte->xte_stack_top = copy_xte->xte_stack_buf + (loaded_xte->xte_stack_top - loaded_xte->xte_stack_buf);
        }
      xlazye->xe_doc.xd->xd_ref_count++;
    }
  xlazye->xe_doc.xd->xd_ref_count--; /* because this is counted already while making a copy */
  dk_free_box (cache_key);
  box_tag_modify (loaded_xe, DV_CUSTOM);
  dk_free_box (loaded_xe);
  return;

loading_error:
  dk_free_box (doc_text);
  sqlr_resignal (loading_error);
}

void
xlazye_destroy (xml_entity_t * xe)
{
  xml_lazy_doc_t *xlazyd = xe->xe_doc.xlazyd;
  if (!dk_set_delete (&(xlazyd->xlazyd_entities), xe))
    GPF_T1 ("bad xlazye_destroy()");
#ifdef DEBUG
  if (0 >= xlazyd->xd_ref_count)
    GPF_T1 ("bad refcount in xlazye_destroy()");
#endif
  xlazyd->xd_ref_count--;
  if (0 == xlazyd->xd_ref_count)
    {
#ifdef DEBUG
      if (NULL != xlazyd->xlazyd_entities)
        GPF_T1 ("bad xlazyd_entities in xlazye_destroy()");
#endif
      dk_free_tree (xlazyd->xlazyd_cache_key);
      dk_free (xlazyd, sizeof (xml_lazy_doc_t));
    }
}

xml_entity_t *
DBG_NAME(xlazye_copy) (DBG_PARAMS xml_entity_t * xe)
{
  xml_lazy_ent_t *copy = dk_alloc_box (sizeof (xml_entity_un_t), DV_XML_ENTITY);
  memcpy (copy, xe, sizeof (xml_entity_un_t));
  xe->xe_doc.xd->xd_ref_count++;
  dk_set_push (&(xe->xe_doc.xlazyd->xlazyd_entities), copy);
  return (xml_entity_t *)copy;
}

xml_entity_t *
DBG_NAME(xlazye_cut) (DBG_PARAMS xml_entity_t *xe, query_instance_t *qi)
{ xlazye_make_actual_load (xe); return xe->_->DBG_NAME(xe_cut)(DBG_ARGS xe, qi); }

xml_entity_t *
DBG_NAME(xlazye_clone) (DBG_PARAMS xml_entity_t *xe, query_instance_t *qi)
{ xlazye_make_actual_load (xe); return xe->_->DBG_NAME(xe_clone)(DBG_ARGS xe, qi); }

int
DBG_NAME(xlazye_attribute) (DBG_PARAMS xml_entity_t *xe, int start, XT *node, caddr_t *ret, caddr_t *name_ret)
{ xlazye_make_actual_load (xe); return xe->_->DBG_NAME(xe_attribute)(DBG_ARGS xe, start, node, ret, name_ret); }

void
DBG_NAME(xlazye_string_value) (DBG_PARAMS xml_entity_t * xe, caddr_t * ret, dtp_t dtp)
{ xlazye_make_actual_load (xe); xe->_->DBG_NAME(xe_string_value)(DBG_ARGS xe, ret, dtp); }

int
xlazye_string_value_is_nonempty (xml_entity_t * xe)
{ xlazye_make_actual_load (xe); return xe->_->xe_string_value_is_nonempty (xe); }

int
xlazye_up (xml_entity_t * xe, XT * node, int up_flags)
{ xlazye_make_actual_load (xe); return xe->_->xe_up (xe, node, up_flags); }

int
xlazye_down (xml_entity_t * xe, XT * node)
{ xlazye_make_actual_load (xe); return xe->_->xe_down (xe, node); }

int
xlazye_down_rev (xml_entity_t * xe, XT * node)
{ xlazye_make_actual_load (xe); return xe->_->xe_down_rev (xe, node); }

int
xlazye_first_child (xml_entity_t * xe, XT *node_test)
{ xlazye_make_actual_load (xe); return xe->_->xe_first_child (xe, node_test); }

int
xlazye_last_child (xml_entity_t * xe, XT *node_test)
{ xlazye_make_actual_load (xe); return xe->_->xe_last_child (xe, node_test); }

int
xlazye_get_child_count_any (xml_entity_t * xe)
{ xlazye_make_actual_load (xe); return xe->_->xe_get_child_count_any (xe); }

int
xlazye_next_sibling (xml_entity_t * xe, XT * node_test)
{ xlazye_make_actual_load (xe); return xe->_->xe_next_sibling (xe, node_test); }

int
xlazye_next_sibling_wr (xml_entity_t * xe, XT * node_test)
{ xlazye_make_actual_load (xe); return xe->_->xe_next_sibling_wr (xe, node_test); }

int
xlazye_prev_sibling (xml_entity_t * xe, XT * node_test)
{ xlazye_make_actual_load (xe); return xe->_->xe_prev_sibling (xe, node_test); }

int
xlazye_prev_sibling_wr (xml_entity_t * xe, XT * node_test)
{ xlazye_make_actual_load (xe); return xe->_->xe_prev_sibling (xe, node_test); }

caddr_t
xlazye_attrvalue (xml_entity_t * xe, caddr_t qname)
{ xlazye_make_actual_load (xe); return xe->_->xe_attrvalue (xe, qname); }

caddr_t
xlazye_currattrvalue (xml_entity_t * xe)
{ xlazye_make_actual_load (xe); return xe->_->xe_currattrvalue (xe); }

size_t
xlazye_data_attribute_count (xml_entity_t * xe)
{ xlazye_make_actual_load (xe); return xe->_->xe_data_attribute_count (xe); }

caddr_t
xlazye_element_name (xml_entity_t * xe)
{ xlazye_make_actual_load (xe); return xe->_->xe_element_name (xe); }

caddr_t
xlazye_ent_name (xml_entity_t * xe)
{ xlazye_make_actual_load (xe); return xe->_->xe_ent_name (xe); }

void
xlazye_serialize (xml_entity_t * xe, dk_session_t * ses)
{ xlazye_make_actual_load (xe); xe->_->xe_serialize (xe, ses); }

void
xlazye_word_range (xml_entity_t * xe, wpos_t * start, wpos_t * end)
{ xlazye_make_actual_load (xe); xe->_->xe_word_range (xe, start, end); }

void
xlazye_attr_word_range (xml_entity_t * xe, wpos_t * start, wpos_t * this_end, wpos_t * last_end)
{ xlazye_make_actual_load (xe); xe->_->xe_attr_word_range (xe, start, this_end, last_end); }

void
xlazye_log_update (xml_entity_t * xe, dk_session_t * log)
{ xlazye_make_actual_load (xe); xe->_->xe_log_update (xe, log); }

int
xlazye_get_logical_path (xml_entity_t * xe, dk_set_t *path)
{ xlazye_make_actual_load (xe); return xe->_->xe_get_logical_path (xe, path); }

struct dtd_s *
xlazye_get_addon_dtd (xml_entity_t * xe)
{ xlazye_make_actual_load (xe); return xe->_->xe_get_addon_dtd (xe); }

const char *
xlazye_get_sysid (xml_entity_t *xe, const char *ref_name)
{ xlazye_make_actual_load (xe); return xe->_->xe_get_sysid (xe, ref_name); }

int
xlazye_element_name_test (xml_entity_t *xe, XT *wname_node)
{ xlazye_make_actual_load (xe); return xe->_->xe_element_name_test (xe, wname_node); }

int
xlazye_ent_name_test (xml_entity_t *xe, XT *wname_node)
{ xlazye_make_actual_load (xe); return xe->_->xe_ent_name_test (xe, wname_node); }

int
xlazye_ent_node_test (xml_entity_t *xe, XT *node)
{ xlazye_make_actual_load (xe); return xe->_->xe_ent_node_test (xe, node); }

int
xlazye_is_same_as (const xml_entity_t *this_xe, const xml_entity_t *that_xe)
{ xlazye_make_actual_load ((xml_entity_t *)this_xe); return this_xe->_->xe_is_same_as (this_xe, that_xe); }

xml_entity_t *
xlazye_deref_id (xml_entity_t *xe, const char * idbegin, size_t idlength)
{ xlazye_make_actual_load (xe); return xe->_->xe_deref_id (xe, idbegin, idlength); }

xml_entity_t *
xlazye_follow_path (xml_entity_t *xe, ptrlong *path, size_t path_depth)
{ GPF_T1("xlazye_follow_path() is called"); return NULL; }

caddr_t *
xlazye_copy_to_xte_head (xml_entity_t *xe)
{ xlazye_make_actual_load (xe); return xe->_->xe_copy_to_xte_head (xe); }

caddr_t *
xlazye_copy_to_xte_subtree (xml_entity_t *xe)
{ xlazye_make_actual_load (xe); return xe->_->xe_copy_to_xte_subtree (xe); }

caddr_t **
xlazye_copy_to_xte_forest (xml_entity_t *xe)
{ xlazye_make_actual_load (xe); return xe->_->xe_copy_to_xte_forest (xe); }

void
xlazye_emulate_input (xml_entity_t *xe, struct vxml_parser_s *parser)
{ xlazye_make_actual_load (xe); xe->_->xe_emulate_input (xe, parser); }

struct xml_entity_s *
xlazye_reference (query_instance_t * qi, caddr_t base, caddr_t ref, xml_doc_t * from_doc, caddr_t *err_ret)
{ GPF_T1("xlazye_reference() is called"); return NULL; }

caddr_t
xlazye_find_expanded_name_by_qname (xml_entity_t *xe, const char *qname, int use_default)
{ xlazye_make_actual_load (xe); return xe->_->xe_find_expanded_name_by_qname (xe, qname, use_default); }

dk_set_t
xlazye_namespace_scope (xml_entity_t *xe, int use_default)
{ xlazye_make_actual_load (xe); return xe->_->xe_namespace_scope (xe, use_default); }

void
xml_lazy_init (void)
{
#ifdef MALLOC_DEBUG
  xec_lazy_xe.dbg_xe_copy = dbg_xlazye_copy;
  xec_lazy_xe.dbg_xe_cut = dbg_xlazye_cut;
  xec_lazy_xe.dbg_xe_clone = dbg_xlazye_clone;
  xec_lazy_xe.dbg_xe_attribute = dbg_xlazye_attribute;
  xec_lazy_xe.dbg_xe_string_value = (void (*) (DBG_PARAMS xml_entity_t * xe, caddr_t * ret, dtp_t dtp)) dbg_xlazye_string_value;
#else
  xec_lazy_xe.xe_copy = xlazye_copy;
  xec_lazy_xe.xe_cut = xlazye_cut;
  xec_lazy_xe.xe_clone = xlazye_clone;
  xec_lazy_xe.xe_attribute = xlazye_attribute;
  xec_lazy_xe.xe_string_value = (void (*) (xml_entity_t * xe, caddr_t * ret, dtp_t dtp)) xlazye_string_value;
#endif
  xec_lazy_xe.xe_string_value_is_nonempty = xlazye_string_value_is_nonempty;
  xec_lazy_xe.xe_first_child = xlazye_first_child;
  xec_lazy_xe.xe_last_child = xlazye_last_child;
  xec_lazy_xe.xe_get_child_count_any = xlazye_get_child_count_any;
  xec_lazy_xe.xe_next_sibling = xlazye_next_sibling;
  xec_lazy_xe.xe_next_sibling_wr = xlazye_next_sibling_wr;
  xec_lazy_xe.xe_prev_sibling = xlazye_prev_sibling;
  xec_lazy_xe.xe_prev_sibling_wr = xlazye_prev_sibling_wr;
  xec_lazy_xe.xe_element_name = xlazye_element_name;
  xec_lazy_xe.xe_ent_name = xlazye_ent_name;
  xec_lazy_xe.xe_is_same_as = xlazye_is_same_as;
  xec_lazy_xe.xe_destroy = xlazye_destroy;
  xec_lazy_xe.xe_serialize = xlazye_serialize;
  xec_lazy_xe.xe_attrvalue = xlazye_attrvalue;
  xec_lazy_xe.xe_currattrvalue = xlazye_currattrvalue;
  xec_lazy_xe.xe_data_attribute_count = (size_t (*) (xml_entity_t *)) xlazye_data_attribute_count;
  xec_lazy_xe.xe_up = xlazye_up;
  xec_lazy_xe.xe_down = xlazye_down;
  xec_lazy_xe.xe_down_rev = xlazye_down_rev;
  xec_lazy_xe.xe_word_range = xlazye_word_range;
  xec_lazy_xe.xe_attr_word_range = xlazye_attr_word_range;
  xec_lazy_xe.xe_log_update = xlazye_log_update;
  xec_lazy_xe.xe_get_logical_path = xlazye_get_logical_path;
  xec_lazy_xe.xe_get_addon_dtd = xlazye_get_addon_dtd;
  xec_lazy_xe.xe_get_sysid = xlazye_get_sysid;
  xec_lazy_xe.xe_element_name_test = xlazye_element_name_test;
  xec_lazy_xe.xe_ent_name_test = xlazye_ent_name_test;
  xec_lazy_xe.xe_ent_node_test = (int (*) (xml_entity_t *, XT *))xlazye_ent_node_test;
  xec_lazy_xe.xe_deref_id = xlazye_deref_id;
  xec_lazy_xe.xe_follow_path = xlazye_follow_path;
  xec_lazy_xe.xe_copy_to_xte_head = xlazye_copy_to_xte_head;
  xec_lazy_xe.xe_copy_to_xte_subtree = xlazye_copy_to_xte_subtree;
  xec_lazy_xe.xe_copy_to_xte_forest = xlazye_copy_to_xte_forest;
  xec_lazy_xe.xe_emulate_input = xlazye_emulate_input;
  xec_lazy_xe.xe_reference = xlazye_reference;
  xec_lazy_xe.xe_find_expanded_name_by_qname = xlazye_find_expanded_name_by_qname;
  xec_lazy_xe.xe_namespace_scope = xlazye_namespace_scope;
}
