/*
 *  schema_fsm.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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

#include "xmlparser_impl.h"
#include "schema_ecm.h"

#define MGRP_EMPTY_GROUP	(-100)	/* Root element */
#define MGRP_ALL	(-101)
#define MGRP_CHOICE	XECM_TERM_CHOICE
#define MGRP_SEQUENCE	XECM_TERM_CHAIN
/* #define MGRP_ELEMENT	(-104) */
#define MGRP_ANY	(-105)
#define MGRP_GROUPREF	(-106)

#define XS_ANY_LAX	200
#define XS_ANY_SKIP	201
#define XS_ANY_STRICT	202

#define AGRP_GROUP	0	/* Root element */
#define AGRP_ANY	1
#define AGRP_ATTR	2
#define AGRP_GROUPREF	3

#define NAMESPACE_ANY	0

#define XS_ATTRIBUTE_DELIMETER '#'
#define XS_ATTR_QUAL_DELIMETER ':'

#define GRP_MAGIC   (grp_tree_elem_t*)0xcdcdcdcd
#define GRP_ZERO    (grp_tree_elem_t*)0x00000000

#define XS_COMPOSE_SUCC	1
#ifndef max
#define max(a,b) (((a) > (b)) ? (a) : (b))
#endif
#ifndef min
#define min(a,b) (((a) < (b)) ? (a) : (b))
#endif

#ifndef DEBUG
#undef PRINT_FSA
#endif

#ifdef DEBUG
char *xecm_print_fsm (xecm_el_idx_t el_idx, schema_parsed_t * schema, int use_raw);
char *xecm_print_fsm_type (xs_component_t * type, schema_parsed_t * schema, int use_raw);
char *xecm_print_attributes (xecm_el_idx_t idx, schema_parsed_t * schema);
int xecm_validate_fsm (xecm_el_idx_t el_idx, schema_parsed_t * schema, int use_raw);
int xecm_validate_fsm_type (xs_component_t * type, schema_parsed_t * schema, int use_raw);
#endif

caddr_t xs_concat_full_name (const char *typeprefix,
    const char *name);

id_hashed_key_t xs_count_hash (caddr_t coorp);
int xs_count_hashcmp (caddr_t coorp1, caddr_t coorp2);

typedef struct xs_coor_s
{
  ptrlong x;
  ptrlong y;
}
xs_coor_t;

ptrlong
get_tag_minoccurs_number (xs_tag_t * this_)
{
  const char *minoccurs =
      xs_get_attr ("minOccurs", this_->tag_atts);
  if (minoccurs)
    return atol (minoccurs);
  return 1;			/* default value */
}

ptrlong
get_tag_maxoccurs_number (xs_tag_t * this_)
{
  const char *maxoccurs =
      xs_get_attr ("maxOccurs", this_->tag_atts);
  if (maxoccurs)
    {
      if (!stricmp ("unbounded", (char *) (maxoccurs)))
	return XECM_INF_MAXOCCURS;
      return atol (maxoccurs);
    };
  return 1;			/* default value */
}

#define GRPT_ERR_ALL_MAXOCCURS (grp_tree_elem_t *)(-1)
#define GRPT_ERR_MINMAX_OCCURS (grp_tree_elem_t *)(-2)
#define GRPT_ERR_NO_TREE_CUR   (grp_tree_elem_t *)(-3)

#define MP_GRP_TREE_ELEM ((grp_tree_elem_t *) mp_alloc (pool, sizeof (grp_tree_elem_t)))

grp_tree_elem_t *
xecm_grp_elem_ctor (vxml_parser_t *parser, ptrlong id, grp_tree_elem_t * et_subterm1_,
    grp_tree_elem_t * et_subterm2_)
{
  mem_pool_t * pool = parser->processor.sp_schema->pool;
  grp_tree_elem_t *res;
  ptrlong may_be_empty;
  switch (id)
    {
    case XECM_TERM_CHAIN:
      may_be_empty = et_subterm1_->elem_may_be_empty
	  && et_subterm2_->elem_may_be_empty;
      goto create_new;
    case XECM_TERM_CHOICE:
      may_be_empty = (XECM_EMPTY == et_subterm1_)
	  || (XECM_EMPTY == et_subterm2_) || et_subterm1_->elem_may_be_empty
	  || et_subterm2_->elem_may_be_empty;
      goto create_new;
    case XECM_TERM_LOOP_ZERO:
      if ((XECM_TERM_LOOP_ZERO == et_subterm1_->elem_idx)
	  || (ECM_TERM_LOOP_ONE == et_subterm1_->elem_idx))
	{
	  et_subterm1_->elem_idx = XECM_TERM_LOOP_ZERO;
	  return et_subterm1_;
	}
      may_be_empty = 1;
      goto create_new;
    case XECM_TERM_LOOP_ONE:
      if ((XECM_TERM_LOOP_ZERO == et_subterm1_->elem_idx)
	  || (XECM_TERM_LOOP_ONE == et_subterm1_->elem_idx))
	{
	  return et_subterm1_;
	}
      may_be_empty = et_subterm1_->elem_may_be_empty;
      if (may_be_empty)
	id = XECM_TERM_LOOP_ZERO;
    default:
      may_be_empty = 0;
    }
create_new:
  res = MP_GRP_TREE_ELEM;
  memset (res, 0, sizeof (grp_tree_elem_t));
  res->elem_idx = id;
  res->elem_content_left = et_subterm1_;
  res->elem_content_right = et_subterm2_;
  res->elem_may_be_empty = may_be_empty;

  res->elem_value = 0;
  res->elem_attrs.ea_maxoccurs = 1;
  res->elem_attrs.ea_minoccurs = 1;
  res->elem_attrs.ea_namespaces = NAMESPACE_ANY;	/* not supported */
  return res;
}


grp_tree_elem_t *
xecm_advance_tree (vxml_parser_t *parser, grp_tree_elem_t * node)
{
  ptrlong maxoccurs = node->elem_attrs.ea_maxoccurs;
  ptrlong minoccurs = node->elem_attrs.ea_minoccurs;
  grp_tree_elem_t *res;
  if ((1 == minoccurs) && (1 == maxoccurs))
    return node;
  if ((XECM_TERM_LOOP_ZERO == node->elem_idx) || (XECM_TERM_LOOP_ONE == node->elem_idx))
    return node;
  node->elem_attrs.ea_maxoccurs = 1;
  node->elem_attrs.ea_minoccurs = 1;
  res = xecm_grp_elem_ctor (parser, ((0 == minoccurs) ? XECM_TERM_LOOP_ZERO : XECM_TERM_LOOP_ONE), node, GRP_MAGIC);
  res->elem_attrs.ea_maxoccurs = maxoccurs;
  res->elem_attrs.ea_minoccurs = minoccurs;
  return res;
}


void
set_grp_tree_elems (vxml_parser_t * parser, xs_tag_t * _this)
{
  schema_parsed_t *schema = parser->processor.sp_schema;
  mem_pool_t * pool = schema->pool;
  dtd_astate_t *state =
      parser->validator.dv_stack + parser->validator.dv_depth;
  xs_tag_t *ptag = state[-1].da_tag;
  ptrlong mgrp_id = 0;
  ptrlong maxoccurs;
  ptrlong minoccurs;
  xs_component_t *tree_elem_value = 0;
  grp_tree_elem_t *new_leaf = NULL, *new_tree = NULL, **active_leaf = NULL;
  maxoccurs = get_tag_maxoccurs_number (_this);
  minoccurs = get_tag_minoccurs_number (_this);
  if (maxoccurs < minoccurs)
    {
      minoccurs = 0;
      maxoccurs = XECM_INF_MAXOCCURS;
    }

  switch (_this->tag_info->info_tagid)
    {
    case XS_TAG_ALL:
#if 0    
      if (maxoccurs > 1)	/* error, see http://www.w3.org/TR/xmlschema-1/#coss-modelGroup */
	return /*GRPT_ERR_ALL_MAXOCCURS*/;
#endif	
      mgrp_id = MGRP_ALL;      
      break;
    case XS_TAG_CHOICE:
      mgrp_id = MGRP_CHOICE;
      break;
    case XS_TAG_SEQUENCE:
      mgrp_id = MGRP_SEQUENCE;
      break;
    case XS_TAG_ELEMENT:
      tree_elem_value = _this->tag_component_ref ? _this->tag_component_ref : _this->tag_component;
      if (tree_elem_value->cm_xecm_idx != -1)
	mgrp_id = tree_elem_value->cm_xecm_idx;
      else
	{
	  mgrp_id = xecm_add_element (tree_elem_value, (void **) &(schema->sp_xecm_els), &schema->sp_xecm_el_no, sizeof (xecm_el_t));
	  tree_elem_value->cm_xecm_idx = mgrp_id;
	}
      break;
    case XS_TAG_ANY:
      {
        const char *pc = xs_get_attr ("processContents", _this->tag_atts);
        const char *nss = xs_get_attr ("namespace", _this->tag_atts);
        ptrlong mode;
        dk_set_t ns_set = NULL;
        caddr_t ns_lst;
        if (nss)
          {
	    char *toks = box_string (nss);
	    char *tok = toks, *tok_end;
	    for (;;)
	      {
	        caddr_t ns;
	        while (('\0' != tok[0]) && (NULL != strchr (" \t\r\n", tok[0]))) tok++;
	        tok_end = tok;
	        while (('\0' != tok_end[0]) && (NULL == strchr (" \t\r\n", tok_end[0]))) tok_end++;
	        if ('\0' != tok_end[0])
	          (tok_end++)[0] = '\0';
	        else
	          tok_end = NULL;
	        ns = box_dv_uname_string (tok);
	        dk_set_push (&ns_set, ns );
	        if (strncmp (ns, "##", 2))
	          ecm_add_name (ns, (void **)(&(schema->sp_xecm_namespaces)), &(schema->sp_xecm_namespace_no), sizeof (char *));
	        if (NULL == tok_end)
	          break;
	        tok = tok_end;
	      }
	    dk_free_box (toks);          
          }
        else
	  dk_set_push (&ns_set, box_dv_uname_string ("##any"));
        if (NULL == pc) mode = XS_ANY_STRICT;
        else if (!strcmp (pc, "skip")) mode = XS_ANY_SKIP;
        else if (!strcmp (pc, "lax")) mode = XS_ANY_LAX;
        else mode = XS_ANY_STRICT;
        dk_set_push (&ns_set, (caddr_t)mode);
        ns_lst = list_to_array (ns_set);
	tree_elem_value = (xs_component_t *)mp_box_copy (pool, ns_lst);
	dk_free_box (ns_lst);
	mgrp_id = MGRP_ANY;
	break;
      }
    case XS_TAG_GROUP:
      tree_elem_value =
	  _this->tag_component_ref ? _this->tag_component_ref : _this->
	  tag_component;
/*      tree_elem_value=add_component_reference (parser->processor.sp_schema->pool,
	  xs_get_attr("ref",_this->tag_atts),
	  parser->processor.sp_schema->sp_groups, &parser->curr_pos,0);*/
      mgrp_id = MGRP_GROUPREF;
      break;
#ifdef XMLSCHEMA_UNIT_DEBUG
    default:
      GPF_T1 ("invalid tag in group definition\n");
#else
    default:
      /* nop */ ;
#endif
    };
  new_leaf = MP_GRP_TREE_ELEM;
  memset (new_leaf, 0, sizeof (grp_tree_elem_t));
  new_leaf->elem_idx = mgrp_id;
  new_leaf->elem_value = tree_elem_value;
  new_leaf->elem_attrs.ea_maxoccurs = maxoccurs;
  new_leaf->elem_attrs.ea_minoccurs = minoccurs;
  new_leaf->elem_attrs.ea_namespaces = NAMESPACE_ANY;	/* not supported */
  new_tree = xecm_advance_tree (parser, new_leaf);
  if (NULL == ptag->temp.grp_tree)
    {
      ptag->temp.grp_tree = _this->temp.grp_tree = new_tree;
      ptag->temp.grp_tree_curr = _this->temp.grp_tree_curr = new_leaf;
      return;
    }
  if (ptag->temp.grp_tree->elem_idx == MGRP_EMPTY_GROUP)
    {
      memcpy (ptag->temp.grp_tree, new_tree, sizeof (grp_tree_elem_t));
      _this->temp.grp_tree = ptag->temp.grp_tree;
      ptag->temp.grp_tree_curr = _this->temp.grp_tree_curr = ((new_tree == new_leaf) ? ptag->temp.grp_tree : new_leaf);
      return;
    }
  if (!ptag->temp.grp_tree_curr->elem_content_left)
    active_leaf = &ptag->temp.grp_tree_curr->elem_content_left;
  else if (!ptag->temp.grp_tree_curr->elem_content_right)
    active_leaf = &ptag->temp.grp_tree_curr->elem_content_right;
  if (active_leaf)
    {
      *active_leaf = new_tree;
    }
  else				/* no space, add new node */
    {
      grp_tree_elem_t *old_leaf = ptag->temp.grp_tree_curr->elem_content_right;
      grp_tree_elem_t *ins = MP_GRP_TREE_ELEM;
      memset (ins, 0, sizeof (grp_tree_elem_t));
      /* inserting new items in the tree */
      ins->elem_idx = ptag->temp.grp_tree_curr->elem_idx;
      ins->elem_value = 0;
      ins->elem_attrs.ea_maxoccurs = 1;
      ins->elem_attrs.ea_minoccurs = 1;
      ins->elem_attrs.ea_namespaces = NAMESPACE_ANY;	/* not supported */
      ins->elem_content_left = old_leaf;
      ins->elem_content_right = new_tree;
      ptag->temp.grp_tree_curr->elem_content_right = ins;
      ptag->temp.grp_tree_curr = ins;
    }
  /* point tree pointers on new positions */
  _this->temp.grp_tree = new_tree;
  _this->temp.grp_tree_curr = new_leaf;
}


void
penetrate_grp_elems (xs_tag_t * _this)
{
  if (_this->tag_base)
    {
      _this->temp.grp_tree = _this->tag_base->temp.grp_tree;
      _this->temp.grp_tree_curr = _this->tag_base->temp.grp_tree_curr;
    }
}


void
set_grp_root_element (vxml_parser_t *parser, xs_tag_t * _this)
{
  schema_parsed_t *schema = parser->processor.sp_schema;
  mem_pool_t * pool = schema->pool;
  switch (_this->tag_info->info_tagid)
    {
    case XS_TAG_GROUP:
    case XS_TAG_COMPLEX_TYPE:
      _this->temp.grp_tree = _this->temp.grp_tree_curr =
	  MP_GRP_TREE_ELEM;
      memset (_this->temp.grp_tree_curr, 0, sizeof (grp_tree_elem_t));
      _this->temp.grp_tree->elem_idx = MGRP_EMPTY_GROUP;
      _this->temp.grp_tree->elem_attrs.ea_maxoccurs = 1;
      _this->temp.grp_tree->elem_attrs.ea_minoccurs = 1;
#ifdef DEBUG_GRP
      _this->temp.grp_tree_curr->elem_content_left = GRP_MAGIC;
      _this->temp.grp_tree_curr->elem_content_right = GRP_MAGIC;
#endif
      break;
    case XS_TAG_SIMPLE_TYPE:
      break;
#ifdef XMLSCHEMA_UNIT_DEBUG
    default:
      GPF_T1 ("model group's elements are not valid here\n");
#else
    default:
      /* nop */ ;
#endif
    }
}

#ifdef DEBUG
void
grp_print_tree (grp_tree_elem_t * tree, int level, const char *comment)
{
  int l = level;
  while (l--)
    printf (" ");
  if (tree == NULL)
    {
      printf ("NULL (%s)\n", comment);
      return;
    }
  else if (tree == XECM_EMPTY)
    {
      printf ("EMPTY (%s)\n", comment);
      return;
    }
  else if (tree == XECM_ANY)
    {
      printf ("ANY (%s)\n", comment);
      return;
    }
  else if (tree == GRP_MAGIC)
    {
      printf ("magic (%s)\n", comment);
      return;
    }
  switch (tree->elem_idx)
    {
    case MGRP_EMPTY_GROUP:
      printf ("empty group (%s)\n", comment);
      break;
    case MGRP_ALL:
      printf ("all: %ld %ld", tree->elem_attrs.ea_minoccurs,
	  tree->elem_attrs.ea_maxoccurs);
      break;
    case MGRP_CHOICE:
      printf ("choice: %ld %ld", tree->elem_attrs.ea_minoccurs,
	  tree->elem_attrs.ea_maxoccurs);
      break;
    case MGRP_SEQUENCE:
      printf ("seq: %ld %ld", tree->elem_attrs.ea_minoccurs,
	  tree->elem_attrs.ea_maxoccurs);
      break;
    case MGRP_ANY:
      {
        caddr_t *descr;
        int idx;
        printf ("any: %ld %ld ", tree->elem_attrs.ea_minoccurs, tree->elem_attrs.ea_maxoccurs);
        descr = (caddr_t *)(tree->elem_value);
        DO_BOX_FAST (caddr_t, ns, idx, descr)
          {
            if (idx) printf ("%s", ns);
	    else printf ("(mode %ld)", ((long)((ptrlong)(ns))));	    
          }
        END_DO_BOX_FAST;
      }
      break;
    case MGRP_GROUPREF:
      printf ("group <%s = %s>: %ld %ld", tree->elem_value->cm_qname, tree->elem_value->cm_longname,
	  tree->elem_attrs.ea_minoccurs, tree->elem_attrs.ea_maxoccurs);
      break;
    case XECM_TERM_LOOP_ZERO:
      printf ("loop zero-or-more: %p %ld %ld", tree->elem_value,
	  tree->elem_attrs.ea_minoccurs, tree->elem_attrs.ea_maxoccurs);
      break;
    case XECM_TERM_LOOP_ONE:
      printf ("loop one-or-mode: %p %ld %ld", tree->elem_value,
	  tree->elem_attrs.ea_minoccurs, tree->elem_attrs.ea_maxoccurs);
      break;
    default:			/* element */    
      printf ("element #%ld <%s = %s = %s>", (long)(tree->elem_idx),
        tree->elem_value ? tree->elem_value->cm_qname : "",
        tree->elem_value ? tree->elem_value->cm_elname : "",
        tree->elem_value ? tree->elem_value->cm_longname : ""
        );
      break;
    }
  printf ("(%s)\n", comment);
  grp_print_tree (tree->elem_content_left, level + 1, "Left");
  grp_print_tree (tree->elem_content_right, level + 1, "Right");
}
#endif


/*
void xecm_init_validation_vars(schema_processor_t* processor)
{
  id_hash_iterator_t hit;
  char** name;
  xs_component_t** element;

  for (id_hash_iterator(&hit, processor->sp_elems);
    hit_next(hit, (char**)&name, (char**)&element);
    NULL )
    {
      ptrlong idx = xecm_add_name(*name, (void**)&processor->schema_els,
	  &processor->schema_el_no, sizeof(xxecm_el_t));
      if (-1 != idx)
	(processor->schema_els + idx)->xee_component = *element;
      else
	GPF_T1("invalid hash, testing purpose, must be removed");
    }
} */
/* Adopted/Stolen code from xml_ecm.c file */

/* Compiler of terms' tree into FSA */

struct xecm_fts_context_s
{
  xecm_st_t **xfc_states;		/*!< Pointer to the array of states to be filled */
  xecm_st_idx_t *xfc_state_no;		/*!< Pointer to the size of xfc_states[0] */
  schema_processor_t *xfc_processor;
  schema_parsed_t *xfc_schema;
};

typedef struct xecm_fts_context_s xecm_fts_context_t;

struct xecm_fts_gap_s
{  
  xecm_st_idx_t xfg_from, xfg_to;
  ptrlong xfg_minc_factor, xfg_maxc_factor;
  grp_tree_t xfg_tree;
  struct xecm_fts_gap_s *xfg_outer;
};

typedef struct xecm_fts_gap_s xecm_fts_gap_t;

xecm_nexts_array_t *
xecm_nexts_allocate (ptrlong storage_type, ptrlong el_no, ptrlong defval)
{
  xecm_nexts_array_t *nexts = 0;
  if (storage_type == XECM_STORAGE_RAW)
    {
      ptrlong ctr;
      nexts = (xecm_nexts_array_t *) dk_alloc (sizeof (xecm_nexts_array_t));
      nexts->na_type_sel = XECM_STORAGE_RAW;
      nexts->na_nexts.raw = dk_alloc (el_no * sizeof (xecm_st_info_t));
      nexts->na_max_idx = el_no;
      if (!defval)
	memset (nexts->na_nexts.raw, 0, el_no * sizeof (xecm_st_info_t));
      else
	for (ctr = 0; ctr < el_no; ctr++)
	  {
	    nexts->na_nexts.raw[ctr].xsi_idx = defval;
	    nexts->na_nexts.raw[ctr].xsi_min_counters = 0;
	    nexts->na_nexts.raw[ctr].xsi_max_counters = 0;
	    nexts->na_nexts.raw[ctr].xsi_occurence_num = 0;
	  }
    }
  else if (storage_type == XECM_STORAGE_RARE)
    {
      xecm_st_info_t *def;
      nexts = (xecm_nexts_array_t *) dk_alloc (sizeof (xecm_nexts_array_t));
      nexts->na_type_sel = XECM_STORAGE_RARE;
      nexts->na_nexts.rare = xecm_create_big_array (sizeof (xecm_st_info_t));
      nexts->na_max_idx = el_no;
      def = dk_alloc_box (sizeof (xecm_st_info_t), DV_ARRAY_OF_LONG);
      memset (def, 0, sizeof (xecm_st_info_t));
      def->xsi_idx = defval;
      xecm_ba_set_defval (nexts->na_nexts.rare, (ptrlong) def);
    }
  return nexts;
}

void
xecm_nexts_free (xecm_nexts_array_t * nexts)
{
  if (nexts->na_type_sel == XECM_STORAGE_RAW)
    {
      dk_free (nexts->na_nexts.raw,
	  nexts->na_max_idx * sizeof (xecm_st_info_t));
      dk_free (nexts, sizeof (xecm_nexts_array_t));
    }
  else if (nexts->na_type_sel == XECM_STORAGE_RARE)
    {
      xecm_ba_delete (nexts->na_nexts.rare);
      dk_free (nexts, sizeof (xecm_nexts_array_t));
    }
}

xecm_st_idx_t
xecm_get_nextidx (xecm_nexts_array_t * nexts, ptrlong idx)
{
  switch (nexts->na_type_sel)
    {
    case XECM_STORAGE_RAW:
#ifdef XMLSCHEMA_UNIT_DEBUG
      if (idx >= nexts->na_max_idx || idx < 0)
	GPF_T1 ("unexpected state number");
#endif
      return nexts->na_nexts.raw[idx].xsi_idx;
    case XECM_STORAGE_RARE:
      return ((xecm_st_info_t *) xecm_ba_get_val (nexts->na_nexts.rare,
	      idx))->xsi_idx;
    }
  return -1;
}

xecm_st_info_t *
xecm_get_next (xecm_nexts_array_t * nexts, ptrlong idx)
{
  if (nexts->na_type_sel == XECM_STORAGE_RAW)
    {
#ifdef XMLSCHEMA_UNIT_DEBUG
      if (idx >= nexts->na_max_idx || idx < 0)
	GPF_T1 ("unexpected state number");
#endif
      return nexts->na_nexts.raw + idx;
    }
  else if (nexts->na_type_sel == XECM_STORAGE_RARE)
    {
      return (xecm_st_info_t *) xecm_ba_get_val (nexts->na_nexts.rare, idx);
    }
  return 0;
}

void
xecm_set_next (xecm_nexts_array_t * nexts, ptrlong idx, xecm_st_info_t * el)
{
  if (nexts->na_type_sel == XECM_STORAGE_RAW)
    {
#ifdef XMLSCHEMA_UNIT_DEBUG
      if (idx >= nexts->na_max_idx || idx < 0)
	GPF_T1 ("unexpected state number");
#endif
      memcpy (nexts->na_nexts.raw + idx, el, sizeof (xecm_st_info_t));
    }
  else if (nexts->na_type_sel == XECM_STORAGE_RARE)
    {
      xecm_st_info_t *newel =
	  dk_alloc_box (sizeof (xecm_st_info_t), DV_ARRAY_OF_LONG);
      memcpy (newel, el, sizeof (xecm_st_info_t));
      xecm_ba_set_val (nexts->na_nexts.rare, idx, (ptrlong) newel);
    }
  return;
}

void
xecm_set_nextidx (xecm_nexts_array_t * nexts, ptrlong idx, ecm_st_idx_t elidx, xs_component_t *el_comp)
{
  if (nexts->na_type_sel == XECM_STORAGE_RAW)
    {
#ifdef XMLSCHEMA_UNIT_DEBUG
      if (idx >= nexts->na_max_idx || idx < 0)
	GPF_T1 ("unexpected state number");
#endif
      nexts->na_nexts.raw[idx].xsi_idx = elidx;
      nexts->na_nexts.raw[idx].xsi_type = el_comp;
    }
  else if (nexts->na_type_sel == XECM_STORAGE_RARE)
    {
      xecm_st_info_t newel;
      memcpy (&newel, xecm_get_next (nexts, idx), sizeof (xecm_st_info_t));
      newel.xsi_idx = elidx;
      newel.xsi_type = el_comp;
      xecm_ba_set_val (nexts->na_nexts.rare, idx, (ptrlong) & newel);
    }
  return;
}

void
xecm_set_next_counters (xecm_nexts_array_t * nexts, ptrlong idx, ptrlong minc,
    ptrlong maxc)
{
  xecm_st_info_t *inf = xecm_get_next (nexts, idx);
#ifdef XMLSCHEMA_UNIT_DEBUG
  if (NULL == inf)
    GPF_T1("Trying to set counters on missing FSA edge");
#endif
  inf->xsi_max_counters = maxc;
  inf->xsi_min_counters = minc;
}

xecm_nexts_array_t *
xecm_copy_nexts (xecm_nexts_array_t * nexts)
{
  xecm_nexts_array_t *new_array;
  if (!nexts)
    return 0;
  new_array = xecm_nexts_allocate (nexts->na_type_sel, nexts->na_max_idx, 0);
  if (nexts->na_type_sel == XECM_STORAGE_RAW)
    memcpy (new_array->na_nexts.raw, nexts->na_nexts.raw,
	sizeof (xecm_st_info_t) * nexts->na_max_idx);
  else if (nexts->na_type_sel == XECM_STORAGE_RARE)
    {
      xecm_ba_copy (new_array->na_nexts.rare, nexts->na_nexts.rare);
    }
#ifdef XMLSCHEMA_UNIT_DEBUG
  else
    GPF_T;
#endif
  return new_array;
}

ptrlong *
xs_counter (xsv_astate_t * state, ptrlong nameidx, ptrlong stidx)
{
  xs_coor_t coor;
  xs_coor_t *coorp = &coor;
  ptrlong **count;
  coor.x = nameidx;
  coor.y = stidx;

  count =
      (ptrlong **) id_hash_get (state->xa_counter_hash, (caddr_t) & coorp);
  if (!count)
    {
      xs_coor_t *new_coor = dk_alloc (sizeof (xs_coor_t));
      ptrlong *new_count = dk_alloc (sizeof (ptrlong));

      memcpy (new_coor, coorp, sizeof (xs_coor_t));
      new_count[0] = 0;
      id_hash_set (state->xa_counter_hash, (caddr_t) & new_coor,
	  (caddr_t) & new_count);
      return new_count;
    }
  return count[0];
}

void
xs_clear_counter (xsv_astate_t * state)
{
  id_hash_t *hash = state->xa_counter_hash;
  id_hash_iterator_t hit;

  if (hash)
    {
      ptrlong **count;
      xs_coor_t **coor;
      for (id_hash_iterator (&hit, hash);
	  hit_next (&hit, (char **) &coor, (char **) &count);
	  /* */ )
	{
	  dk_free (coor[0], sizeof (xs_coor_t));
	  dk_free (count[0], sizeof (ptrlong));
	}
      id_hash_free (hash);
    }
}

xecm_st_idx_t
xfc_add_state (xecm_fts_context_t * xfc)
{
  xecm_st_idx_t res = xfc->xfc_state_no[0];
  xecm_el_idx_t height;
  xecm_st_t *new_st;
  xecm_nexts_array_t *jumps;
  if (!res || (0x7 == (0x7 & res)))
    {
      xecm_st_t *new_array =
	  (xecm_st_t *) dk_alloc_box ((res + 0x8) * sizeof (xecm_st_t),
	  DV_ARRAY_OF_LONG);
      memcpy (new_array, xfc->xfc_states[0], res * sizeof (xecm_st_t));
      if (0 != res)
	dk_free_box (xfc->xfc_states[0]);
      xfc->xfc_states[0] = new_array;
    }
  xfc->xfc_state_no[0] += 1;
  new_st = &(xfc->xfc_states[0][res]);
  height = xfc->xfc_schema->sp_xecm_el_no + xfc->xfc_schema->sp_xecm_namespace_no;
  if (height > XECM_STORAGE_MAXELS)
    jumps =
	xecm_nexts_allocate (XECM_STORAGE_RARE, XECM_EL_OFFSET + height,
	XECM_ST_ERROR);
  else
    jumps =
	xecm_nexts_allocate (XECM_STORAGE_RAW, XECM_EL_OFFSET + height,
	XECM_ST_ERROR);
  new_st->xes_nexts = jumps;
  new_st->xes_conflict = XECM_EL_UNDEF;
  new_st->xes_eqclass = res;
  return res;
}


void xfc_merge_eqclasses (xecm_fts_context_t * xfc, xecm_st_idx_t eqc1, xecm_st_idx_t eqc2)
{
  xecm_st_idx_t eqcsearch, eqcreplace, s;
#ifdef DEBUG
  if ((0 > eqc1) || (0 > eqc2))
    GPF_T;
#endif    
  if (eqc1 < eqc2)
    { eqcsearch = eqc2; eqcreplace = eqc1; }
  else
    { eqcsearch = eqc1; eqcreplace = eqc2; }
  for (s = xfc->xfc_state_no[0]; s--; /* no step */)
    if (eqcsearch == xfc->xfc_states[0][s].xes_eqclass)
      xfc->xfc_states[0][s].xes_eqclass = eqcreplace;
}


#define MAXOCCURS_MULT(res,v1,v2) \
  do { \
    ptrlong __v1 = (v1); \
    ptrlong __v2 = (v2); \
    if ((0 >= __v1) && (0 >= __v2)) \
      { \
        (res) = 0; \
        break; \
      } \
    if ((XECM_INF_MAXOCCURS > __v1) && (XECM_INF_MAXOCCURS > __v2)) \
      { \
	ptrlong __res = __v1 * __v2; \
	if (XECM_INF_MAXOCCURS <= __res) \
	  (res) = XECM_INF_MAXOCCURS; \
	else \
	  (res) = __res; \
      } \
    else \
      (res) = XECM_INF_MAXOCCURS; \
  } while (0)

enum xfc_jump_rep_mode {
  XFC_JUMP_DEFAULT,
  XFC_JUMP_SINGLE,
  XFC_LOOP_TAIL };


void
xfc_set_jump (xecm_fts_context_t * xfc, xecm_fts_gap_t *gap, ecm_el_idx_t event, xs_component_t *el_comp, enum xfc_jump_rep_mode rep_mode)
{
  xecm_st_info_t *old_jump;
  xecm_st_t *states = xfc->xfc_states[0];
  xecm_nexts_array_t *nexts = states[gap->xfg_from].xes_nexts;
  ptrlong minc = 0;
  ptrlong maxc_aux, maxc;
#ifdef DEBUG    
  if ((NULL != el_comp) && (el_comp->cm_elname_idx != event))
    GPF_T;
#endif
  switch (rep_mode)
    {
      case XFC_JUMP_DEFAULT:
      minc = (gap->xfg_tree ? gap->xfg_tree->elem_attrs.ea_minoccurs * gap->xfg_minc_factor : 0);
      MAXOCCURS_MULT (maxc, (gap->xfg_tree ? gap->xfg_tree->elem_attrs.ea_maxoccurs : XECM_INF_MAXOCCURS), gap->xfg_maxc_factor);
      break;
    case XFC_JUMP_SINGLE:
      minc = maxc = 1;
      break;
    case XFC_LOOP_TAIL:
      minc = (gap->xfg_tree ? (gap->xfg_tree->elem_attrs.ea_minoccurs - 1) * gap->xfg_minc_factor : 0);
      maxc_aux = (gap->xfg_tree ? gap->xfg_tree->elem_attrs.ea_maxoccurs : XECM_INF_MAXOCCURS);
      if (XECM_INF_MAXOCCURS > maxc_aux)
        maxc_aux--;
      MAXOCCURS_MULT (maxc, maxc_aux, gap->xfg_maxc_factor);
      break;
    default:
#ifdef DEBUG    
      GPF_T;
#endif
      maxc = 0;
    }
  if (0 >= maxc)
    {
#ifdef DEBUG    
      if (XECM_EL_NULL_T == event)
        GPF_T;
#endif
      if (states[gap->xfg_from].xes_eqclass != states[gap->xfg_to].xes_eqclass)
	xfc_set_jump (xfc, gap, XECM_EL_NULL_T, NULL, XFC_JUMP_SINGLE);
    }
  old_jump = xecm_get_next (nexts, XECM_EL_OFFSET + event);
  if ((0 <= old_jump->xsi_idx) &&
    (states[old_jump->xsi_idx].xes_eqclass == states[gap->xfg_to].xes_eqclass) ) /* Something similar has been drawn already */ 
    {
      if (gap->xfg_from == gap->xfg_to)
        {
/* TBD: resolve conflict of counters */
        }
      return;
    }
  if (XECM_ST_ERROR == old_jump->xsi_idx)
    {
      xecm_set_nextidx (nexts, XECM_EL_OFFSET + event, gap->xfg_to, el_comp);
      xecm_set_next_counters (nexts, XECM_EL_OFFSET + event, minc, maxc);
      return;
    }
/* We have a conflict */
  xfc_merge_eqclasses (xfc, states[old_jump->xsi_idx].xes_eqclass, states[gap->xfg_to].xes_eqclass);
  if ((1 != minc) || (1 != maxc) || (1 != old_jump->xsi_min_counters) ||  (1 != old_jump->xsi_max_counters))
    xecm_set_next_counters (nexts, XECM_EL_OFFSET + event, 0, XECM_INF_MAXOCCURS);
}


void
xfc_set_jumps_for_any (xecm_fts_context_t * xfc, xecm_fts_gap_t *gap, const char *ns, xs_component_t *mode, enum xfc_jump_rep_mode rep_mode)
{
  int el_ctr, el_no = xfc->xfc_schema->sp_xecm_el_no;
  int ns_ctr, ns_no = xfc->xfc_schema->sp_xecm_namespace_no;
  int negate_test = 0;
  int ns_idx = ECM_MEM_NOT_FOUND;
  if (!strcmp (ns, "##any"))
    {
       ns = box_dv_uname_string (" "); /* fake */
       negate_test = 1;
    }
  if (!strcmp (ns, "##targetNamespace"))
    ns = xfc->xfc_schema->sp_target_ns_uri;
  else if (!strcmp (ns, "##other"))
    {
       ns = xfc->xfc_schema->sp_target_ns_uri;
       negate_test = 1;
    }
  else if (!strcmp (ns, "##local"))
    ns = NULL;
  if (ns)
    ns_idx = ecm_find_name (ns, xfc->xfc_schema->sp_xecm_namespaces, ns_no, sizeof (void *));
  for (el_ctr = 0; el_ctr < el_no; el_ctr++)
    {
      xs_component_t *el_comp = xfc->xfc_schema->sp_xecm_els[el_ctr].xee_component;
      char *el_name = ((NULL != el_comp) ? el_comp->cm_elname : "");
      int ns_eq;
      if (NULL != ns)
	{
	  int ns_len = box_length (ns) - 1;
          ns_eq = (!strncmp (el_name, ns, ns_len) && (':' == el_name [ns_len]));
	}
      else
        ns_eq = (NULL == strrchr (el_name, ':'));
      if (ns_eq ? !negate_test : negate_test)
        {
	  if ((NULL != el_comp) || ((xs_component_t *)XS_ANY_STRICT != mode))
	    xfc_set_jump (xfc, gap, el_comp->cm_elname_idx, (((xs_component_t *)XS_ANY_SKIP != mode) ? el_comp : NULL), rep_mode);
	}
    }
  if ((xs_component_t *)XS_ANY_STRICT == mode)
    return; /* 'strict' can not deal with elements that are not listed in the schema */
  for (ns_ctr = 0; ns_ctr < ns_no; ns_ctr++)
    {
      int ns_eq = (ns_idx == ns_ctr);
      if (ns_eq ? !negate_test : negate_test)
	xfc_set_jump (xfc, gap, el_no + ns_ctr, NULL, rep_mode);
    }       	          
  if (negate_test ? (NULL != ns) : (NULL == ns))
    xfc_set_jump (xfc, gap, XECM_EL_ANY_LOCAL, NULL, rep_mode);
  if (negate_test)
    xfc_set_jump (xfc, gap, XECM_EL_ANY_NOT_LISTED_NS, NULL, rep_mode);
}


void
xfc_draw_subgraph (xecm_fts_context_t * xfc, xecm_fts_gap_t *gap)
{
  xecm_fts_gap_t sub;
  if ((NULL == gap->xfg_tree) || (XECM_EMPTY == gap->xfg_tree))
    {    
      if (/* (XECM_ST_UNDEF != gap->xfg_to) && */ (gap->xfg_from != gap->xfg_to)) /* XECM_ST_UNDEF is no longer used */
	{
	  xfc_set_jump (xfc, gap, XECM_EL_NULL_T, NULL, XFC_JUMP_SINGLE);
	}
      return;
    }
  memcpy (&sub, gap, sizeof (xecm_fts_gap_t));
  sub.xfg_outer = gap;
  switch (gap->xfg_tree->elem_idx)
    {
    case XECM_TERM_CHAIN:
      {
        sub.xfg_tree = gap->xfg_tree->elem_content_left;
	if (NULL == gap->xfg_tree->elem_content_right)	/* single-element chain one element */
	  {
	    /* Closely nested loops are multiplied */
            sub.xfg_minc_factor = gap->xfg_minc_factor * gap->xfg_tree->elem_attrs.ea_minoccurs;
	    MAXOCCURS_MULT (sub.xfg_maxc_factor, gap->xfg_maxc_factor, gap->xfg_tree->elem_attrs.ea_maxoccurs);
	    xfc_draw_subgraph (xfc, &sub);
	  }
	else
	  {
            xecm_st_idx_t new_state = xfc_add_state (xfc);
	    sub.xfg_to = new_state;
	    xfc_draw_subgraph (xfc, &sub);
	    sub.xfg_from = new_state;
	    sub.xfg_to = gap->xfg_to;
            sub.xfg_tree = gap->xfg_tree->elem_content_right;
	    xfc_draw_subgraph (xfc, &sub);
	  }
	break;
      }
    case XECM_TERM_CHOICE:
      {
        sub.xfg_tree = gap->xfg_tree->elem_content_left;
	if (NULL == gap->xfg_tree->elem_content_right)	/* single-element chain one element */
	  {
	    /* Closely nested loops are multiplied */
            sub.xfg_minc_factor = gap->xfg_minc_factor * gap->xfg_tree->elem_attrs.ea_minoccurs;
	    MAXOCCURS_MULT (sub.xfg_maxc_factor, gap->xfg_maxc_factor, gap->xfg_tree->elem_attrs.ea_maxoccurs);
	    xfc_draw_subgraph (xfc, &sub);
	  }
	else
	  {
	    xfc_draw_subgraph (xfc, &sub);
            sub.xfg_tree = gap->xfg_tree->elem_content_right;
	    xfc_draw_subgraph (xfc, &sub);
	  }
	break;
      }
    case XECM_TERM_LOOP_ONE:
    case XECM_TERM_LOOP_ZERO:
      {
	ptrlong loop_minc, loop_maxc;
	loop_minc = gap->xfg_minc_factor * gap->xfg_tree->elem_attrs.ea_minoccurs;
        MAXOCCURS_MULT (loop_maxc, gap->xfg_maxc_factor, gap->xfg_tree->elem_attrs.ea_maxoccurs);
	if ((0 == loop_minc) || (XECM_TERM_LOOP_ZERO == gap->xfg_tree->elem_idx))
	  xfc_set_jump (xfc, gap, XECM_EL_NULL_T, NULL, XFC_JUMP_SINGLE);
	else
	  loop_minc--;
	if (XECM_INF_MAXOCCURS != loop_maxc)
	  loop_maxc--;
	if (0 == loop_maxc) /* Not a loop but a single run and maybe bypass */
	  {
            sub.xfg_minc_factor = 1;
	    sub.xfg_maxc_factor = 1;
	    sub.xfg_tree = gap->xfg_tree->elem_content_left;
	    xfc_draw_subgraph (xfc, &sub);
	  }
	else
	  {
	    xecm_st_idx_t loop_state = xfc_add_state (xfc);
	    sub.xfg_tree = gap->xfg_tree->elem_content_left;
	    sub.xfg_to = loop_state;
	    sub.xfg_minc_factor = 1;
	    sub.xfg_maxc_factor = 1;
	    xfc_draw_subgraph (xfc, &sub);
	    sub.xfg_from = loop_state;
	    sub.xfg_minc_factor = loop_minc;
	    sub.xfg_maxc_factor = loop_maxc;
	    xfc_draw_subgraph (xfc, &sub);
	    sub.xfg_to = gap->xfg_to;
            xfc_set_jump (xfc, &sub, XECM_EL_NULL_T, NULL, XFC_JUMP_SINGLE);
	  }
	break;
      }
    case XECM_EL_EOS:
      {
        xfc_set_jump (xfc, gap, XECM_EL_EOS, NULL, XFC_JUMP_SINGLE);
	break;
      }
    case MGRP_EMPTY_GROUP:		/* ignore all this particles */
    case MGRP_ALL:
      break;
    case MGRP_ANY:
      {
        caddr_t *descr = (caddr_t *)(gap->xfg_tree->elem_value);
        xs_component_t *mode = (xs_component_t *)(descr[0]);
        int descr_ns_ctr, descr_ns_count = BOX_ELEMENTS(descr) - 1;
        for (descr_ns_ctr = 0; descr_ns_ctr < descr_ns_count; descr_ns_ctr++)
          {
            caddr_t ns = descr [descr_ns_ctr+1];
            xfc_set_jumps_for_any (xfc, gap, ns, mode, XFC_JUMP_SINGLE);
	  }
	break;
      }
    case MGRP_GROUPREF:
      {				/* make substitution */
	xs_component_t *group = gap->xfg_tree->elem_value;
	if (group && !IS_UNDEF_TYPE(group))
	  {
	    sub.xfg_tree = INFO_GROUP (group).grp_tree;
            sub.xfg_minc_factor = gap->xfg_minc_factor * gap->xfg_tree->elem_attrs.ea_minoccurs;
	    MAXOCCURS_MULT (sub.xfg_maxc_factor, gap->xfg_maxc_factor, gap->xfg_tree->elem_attrs.ea_maxoccurs);
	    xfc_draw_subgraph (xfc, &sub);
	  }
        else
	  {
            xfc_set_jumps_for_any (xfc, &sub, "##any", (xs_component_t *)((ptrlong)(XS_ANY_STRICT)), XFC_JUMP_SINGLE);
	  }
	break;
      }
    default:
      {
        xs_component_t *val = gap->xfg_tree->elem_value;
        dk_set_t done = NULL, queue = NULL;
        dk_set_push (&queue, val);
        while (NULL != queue)
          {
            xs_component_t *curr = (xs_component_t *)dk_set_pop (&queue);
            if (dk_set_member (done, curr))
              continue;
            dk_set_push (&done, curr);
#ifdef DEBUG
	    if (NULL == curr)
	      GPF_T;
	    if (0 > curr->cm_elname_idx)
	      GPF_T;
#endif
	    xfc_set_jump (xfc, &sub, curr->cm_elname_idx, curr, XFC_JUMP_DEFAULT);
	    DO_SET (xs_component_t *, memb, &(curr->cm_subst_group))
	      {
		dk_set_push (&queue, memb);
	      }
            END_DO_SET ();
          }
        dk_set_free (done);
      }
    }
}


void
xfc_term_to_fsa (xecm_fts_context_t *xfc, grp_tree_t tree)
{
  grp_tree_elem_t term;
  xecm_fts_gap_t gap;
  gap.xfg_from = xfc_add_state (xfc);	/* State added will have idx 0 (== XECM_ST_START) and will be starting state. */
  gap.xfg_to = xfc_add_state (xfc);	/* State added will have idx 1 (== XECM_ST_START) and will be starting state. */
  gap.xfg_outer = NULL;
  gap.xfg_maxc_factor = gap.xfg_minc_factor = 1;
  gap.xfg_tree = tree;
  xfc_draw_subgraph (xfc, &gap);
  term.elem_idx = XECM_EL_EOS;
  term.elem_may_be_empty = 0;
  gap.xfg_tree = &term;
  gap.xfg_from = gap.xfg_to;
  gap.xfg_to = XECM_ST_START;
  xfc_set_jump (xfc, &gap, XECM_EL_EOS, NULL, XFC_JUMP_SINGLE);
}


xecm_el_idx_t
xfc_make_fsa_deterministic (xecm_fts_context_t *xfc)
{
  xecm_st_t *states = xfc->xfc_states[0];
  xecm_st_idx_t state_no = xfc->xfc_state_no[0];
  xecm_el_idx_t res = XECM_EL_UNDEF;
  xecm_el_idx_t height = xfc->xfc_schema->sp_xecm_el_no + xfc->xfc_schema->sp_xecm_namespace_no;
  xecm_st_idx_t start;
  int dirt_edges = 0;
  int dirt_eqclasses = 0;
try_optimize:
  for (start = state_no; start--; /* no step */ )
    {
      xecm_st_idx_t st_n;
      xecm_el_idx_t jump;
      st_n = xecm_get_nextidx (states[start].xes_nexts, XECM_EL_OFFSET + XECM_EL_NULL_T);
      if ((0 > st_n) || (st_n == start))
	continue;
      for (jump = 0; jump < XECM_EL_OFFSET + height; jump++)
	{
	  xecm_st_info_t *st_j, *st_n_j;
	  st_n_j = xecm_get_next (states[st_n].xes_nexts, jump);
	  if (0 > st_n_j->xsi_idx)
	    continue;
	  st_j = xecm_get_next (states[start].xes_nexts, jump);
	  if (0 > st_j->xsi_idx)
	    {
	      xecm_set_nextidx (states[start].xes_nexts, jump, st_n_j->xsi_idx, st_n_j->xsi_type);
	      xecm_set_next_counters (states[st_n].xes_nexts, jump, st_n_j->xsi_min_counters, st_n_j->xsi_max_counters);
	      dirt_edges = 1;
	      continue;
	    }
	  if ((st_j->xsi_min_counters != st_n_j->xsi_min_counters) || (st_j->xsi_max_counters != st_n_j->xsi_max_counters))
	    xecm_set_next_counters (states[st_n].xes_nexts, jump, 0, XECM_INF_MAXOCCURS);
	  if (st_j->xsi_type != st_n_j->xsi_type) /* Conflict of destination types, type info should be removed */
	    xecm_set_nextidx (states[start].xes_nexts, jump, st_j->xsi_idx, NULL);
	  /* TBD: check for conflict of properties */
	  if (states[st_n_j->xsi_idx].xes_eqclass != states[st_j->xsi_idx].xes_eqclass)
	    { /* Conflict between edges */
	      dirt_eqclasses = 1;
	      if (XECM_EL_UNDEF == res)
		{
		  res = jump;
		}
	      xfc_merge_eqclasses (xfc, states[st_n_j->xsi_idx].xes_eqclass, states[st_j->xsi_idx].xes_eqclass);
	    }
	}
    }
  if (dirt_edges)
    {
      dirt_edges = 0;
      goto try_optimize;
    }
/* Now it's time to replace eqclasses with their smallest representatives */
  for (start = state_no; start--; /* no step */ )
    {
      xecm_st_idx_t start_eqclass = states[start].xes_eqclass;
      xecm_el_idx_t jump;
      for (jump = 0; jump < XECM_EL_OFFSET + height; jump++)
	{
	  xecm_st_info_t *st_j = xecm_get_next (states[start].xes_nexts, jump);
	  if (0 > st_j->xsi_idx)
	    continue;
	  if (start_eqclass != start)
	    {
	      xecm_st_info_t *st_eqc_j = xecm_get_next (states[start_eqclass].xes_nexts, jump);
	      if ((st_j->xsi_min_counters != st_eqc_j->xsi_min_counters) || (st_j->xsi_max_counters != st_eqc_j->xsi_max_counters))
		xecm_set_next_counters (states[start_eqclass].xes_nexts, jump, 0, XECM_INF_MAXOCCURS);
	      if ((0 <= st_eqc_j->xsi_idx) && (states[st_eqc_j->xsi_idx].xes_eqclass != states[st_j->xsi_idx].xes_eqclass))
	        {
	          /* Conflict between edges */
		  dirt_eqclasses = 1;
		  if (XECM_EL_UNDEF == res)
		    {
		      res = jump;
		    }
		  if (st_eqc_j->xsi_type != st_j->xsi_type)
		    st_eqc_j->xsi_type = st_j->xsi_type = NULL;
		  xfc_merge_eqclasses (xfc, states[st_eqc_j->xsi_idx].xes_eqclass, states[st_j->xsi_idx].xes_eqclass);
		}
	      xecm_set_next (states[start_eqclass].xes_nexts, jump, st_j);
	    }
	  xecm_set_nextidx (states[start_eqclass].xes_nexts, jump, states[st_j->xsi_idx].xes_eqclass, st_j->xsi_type);
	}
    }    
  if (dirt_eqclasses)
    {
      dirt_eqclasses = 0;
      goto try_optimize;
    }
  return res;  
}

/* component is a group or complex type */
void
xecm_create_fsa (grp_tree_t tree, xs_component_t * component,
    schema_processor_t * processor)
{
  xecm_fts_context_t xfc;
  xfc.xfc_states = &(component->cm_states);
  xfc.xfc_state_no = &(component->cm_state_no);
  xfc.xfc_processor = processor;
  xfc.xfc_schema = processor->sp_schema;
  xfc_term_to_fsa (&xfc, tree);
  component->cm_conflict = xfc_make_fsa_deterministic (&xfc);
#ifdef DEBUG
  xfc.xfc_states = &(component->cm_raw_states);
  xfc.xfc_state_no = &(component->cm_raw_state_no);
  xfc_term_to_fsa (&xfc, tree);
#endif  
}

/* searched last right internal node (not leaf) */
grp_tree_elem_t *
search_marked_node (grp_tree_elem_t * tree)
{
  while (tree->elem_content_right
      && (tree->elem_idx == tree->elem_content_right->elem_idx))
    tree = tree->elem_content_right;
  return tree;
}

/* usual inserting in free leaf, if there are no free leafs,
force it to be placed in right one */
void
insert_grp_tree (vxml_parser_t * parser,
    grp_tree_elem_t * marked_tree_elem, grp_tree_elem_t * base_tree)
{
  schema_parsed_t *schema = parser->processor.sp_schema;
  mem_pool_t *pool = schema->pool;
  
  grp_tree_elem_t **to;
  if (!marked_tree_elem->elem_content_left)
    {
      to = &marked_tree_elem->elem_content_left;
    }
  else if (!marked_tree_elem->elem_content_right)
    {
      to = &marked_tree_elem->elem_content_right;
    }
  else				/* create new node */
    {
      grp_tree_elem_t *old_leaf = marked_tree_elem->elem_content_right;
      grp_tree_elem_t *right;
      right = MP_GRP_TREE_ELEM;
      memset (right, 0, sizeof (grp_tree_elem_t));
      right->elem_idx = marked_tree_elem->elem_idx;
      right->elem_value = 0;
      right->elem_attrs.ea_maxoccurs = 1;
      right->elem_attrs.ea_minoccurs = 1;
      right->elem_attrs.ea_namespaces = NAMESPACE_ANY;	/* not supported */
      right->elem_content_left = old_leaf;

      marked_tree_elem->elem_content_right = right;
      to = &right->elem_content_right;
    }
  /* inserting tree */
  to[0] = base_tree;
}

/* returns the most recent version of component */
static xs_component_t *
get_recent_component (xs_component_t * el_type)
{
  xs_component_t *more_recent_comp = el_type;
  while (more_recent_comp->cm_next_version)
    more_recent_comp = el_type->cm_next_version;
  return more_recent_comp;
}

/* \return TRUE (1) if derivation is allowed */
int derivation_is_allowed (vxml_parser_t * parser, derivation_t der,
			   const char * der_str, xs_component_t * type, xs_component_t * base)
{
  if (INFO_CSTYPE (base).final & der)
    {
      if (xmlparser_logprintf (parser, XCFG_FATAL | XCFG_NOLOGPLACE,
		     strlen (type->cm_qname) + strlen (base->cm_qname) + strlen (der_str),
		     "Derivation by %s from type <%s> is explicitly depricated",
		     der_str, base->cm_qname) &&
	  xmlparser_log_cm_location (parser, base, 0) )
	xmlparser_log_cm_location (parser, type, 0);
      return 0;
    }
  return 1;
}

/* \return TRUE (1) if casting is allowed at validation stage */
int check_is_cast_allowed (vxml_parser_t * parser, xs_component_t * type,
			   xs_component_t * xsi_type)
{
  xs_component_t * curr_type = xsi_type;
  xs_component_t * curr_basetype;

  if (!IS_BOX_POINTER (xsi_type))
    return 1;

  curr_basetype = xsi_type->cm_typename;
  if (type == xsi_type)
    return 1;
 again_seach_type:
  if (!curr_basetype)
    {
      /* error, hit the top */
      if (xmlparser_logprintf (parser, XCFG_ERROR,
	  strlen (type->cm_qname) + strlen (xsi_type->cm_qname),
	  "<%s> is not descendant of <%s>",
	  xsi_type->cm_qname, type->cm_qname )
	  && xmlparser_log_cm_location (parser, xsi_type, 0) )
	xmlparser_log_cm_location (parser, type, 0);
      return 0;
    }
  if ((curr_basetype == type) &&
      INFO_CSTYPE (curr_basetype).block & curr_type->cm_derivation)
    {
      if (xmlparser_logprintf (parser, XCFG_ERROR,
	strlen (curr_type->cm_qname) + strlen (curr_basetype->cm_qname),
	"casting from <%s> to <%s> is not allowed due to non empry \"prohibited substitutions\" list",
	curr_basetype->cm_qname, curr_type->cm_qname )
	&& xmlparser_log_cm_location (parser, curr_basetype, 0) )
	xmlparser_log_cm_location (parser, curr_type, 0);
      return 0;
    }
  if (curr_basetype == type)
    return 1;
  curr_type = curr_basetype;
  curr_basetype = curr_type->cm_typename;
  goto again_seach_type;
}

/* \return XS_COMPOSE_SUCC if no errors have occured, zero otherwise */
int
compose_all_groups (vxml_parser_t * parser, xs_component_t * type)
{
  schema_parsed_t *schema = parser->processor.sp_schema;
  mem_pool_t *pool = schema->pool;
  if (parser->processor.temp.depth++ > SCHEMA_MAX_DEPTH)
    {
      if (xmlparser_logprintf (parser, XCFG_ERROR | XCFG_NOLOGPLACE, strlen (type->cm_qname),
	  "Inheritance loop in type <%s>", type->cm_qname) )
      xmlparser_log_cm_location (parser, type, 0);
      return 0;
    }
  if (type->cm_type.t_major == XS_COM_COMPLEXT)
    {
      grp_tree_elem_t **active_tree;
      grp_tree_elem_t **log_tree;
      active_tree = &INFO_CSTYPE (type).group;
      log_tree = &INFO_CSTYPE (type).lg_group;
      if (!log_tree[0])		/* composing has been performed already */
	return XS_COMPOSE_SUCC;
      if (log_tree[0] == XECM_EMPTY)
	return XS_COMPOSE_SUCC;
      if (log_tree[0] == XECM_ANY)
	return XS_COMPOSE_SUCC;
      if (IS_BOX_POINTER (type->cm_typename))
	{
	  xs_component_t *base = (xs_component_t *) type->cm_typename;
	  grp_tree_elem_t *base_tree;
	  if (!compose_all_groups (parser, base))
	    return 0;
	  /* base is some kind of type */
	  if (MAJOR_ID(base) == XS_COM_SIMPLET)
	    {			/* base type is simple, move tree from log to group */
	      goto move;
	    }
	  if (MAJOR_ID(base) != XS_COM_COMPLEXT)
	    {			/* base type is undefined, move tree from log to group */
	      if (xmlparser_logprintf (parser, XCFG_ERROR,
		  strlen (type->cm_qname) + strlen (base->cm_qname),
		  "Could not derive <%s> from undefined base type <%s>",
		  type->cm_qname, base->cm_qname) &&
	        xmlparser_log_cm_location (parser, type, XS_DEF_DEFINED) )
	        xmlparser_log_cm_location (parser, base, 0);
	      return 0;
	    }
	  if (!derivation_is_allowed (parser, XS_DER_RESTRICTION, "restriction", type, base))
	    return 0;
	  if (!derivation_is_allowed (parser, XS_DER_EXTENSION, "extension", type, base))
	    return 0;
	  /* base type is complex, perform merging
	     base group must be composed */
	  base_tree = INFO_CSTYPE (base).group;
	  if (!base_tree || (base_tree == XECM_EMPTY))	/* only derivation by extension is allowed */
	    {
	      if (type->cm_derivation == XS_DER_EXTENSION)
		goto move;
	      if (xmlparser_logprintf (parser, XCFG_ERROR,
		  strlen (type->cm_qname) + strlen (base->cm_qname),
		  "Could not derive by restriction type <%s> from base type <%s> due to base type is EMPTY",
		  type->cm_qname, base->cm_qname) &&
	          xmlparser_log_cm_location (parser, type, 0) )
	        xmlparser_log_cm_location (parser, base, 0);
	      return 0;
	    }
	  if (base_tree == XECM_ANY)	/* only derivation by restriction is allowed */
	    {
	      if (type->cm_derivation == XS_DER_RESTRICTION)
		goto move;
	      if (xmlparser_logprintf (parser, XCFG_ERROR,
		  strlen (type->cm_qname) + strlen (base->cm_qname),
		  "Could not derive by extension type <%s> from base type <%s> due to base type is ANY",
		  type->cm_qname, base->cm_qname) &&
		  xmlparser_log_cm_location (parser, type, 0) )
		xmlparser_log_cm_location (parser, base, 0);
	      return 0;
	    }
	  if (type->cm_derivation == XS_DER_UNION)
	    {
	      if (xmlparser_logprintf (parser, XCFG_ERROR,
		  strlen (type->cm_qname) + strlen (base->cm_qname),
		  "Derivation by union is only for simple types and anyType, not for base <%s>. Derived type <%s>",
		  base->cm_qname, type->cm_qname) &&
		  xmlparser_log_cm_location (parser, type, 0) )
		xmlparser_log_cm_location (parser, base, 0);
	      return 0;
	    }
	  if (type->cm_derivation == XS_DER_LIST)
	    {
	      if (xmlparser_logprintf (parser, XCFG_ERROR,
		  strlen (type->cm_qname) + strlen (base->cm_qname),
		  "Derivation by list is only for simple types and anyType, not for base <%s>. Derived type <%s>",
		  base->cm_qname, type->cm_qname) &&
		  xmlparser_log_cm_location (parser, type, 0) )
	        xmlparser_log_cm_location (parser, base, 0);
	      return 0;
	    }
	  if (type->cm_derivation == XS_DER_RESTRICTION)
	    {
	      goto move;
	    } /* new code for deriving by extension handling */
	  if (type->cm_derivation == XS_DER_EXTENSION)
	    {
	      grp_tree_elem_t *new_tree;
	      grp_tree_elem_t *curr_type_tree;
	      new_tree = MP_GRP_TREE_ELEM;
	      curr_type_tree = INFO_CSTYPE(type).lg_group;
	      if (!GRP_TREE_IS_PREDEFINED (curr_type_tree))
		curr_type_tree = (curr_type_tree->elem_idx == MGRP_EMPTY_GROUP) ? 0 : curr_type_tree;
	      memset (new_tree, 0, sizeof (grp_tree_elem_t));
	      new_tree->elem_idx = MGRP_SEQUENCE;
	      /* base_tree could not be zero or -1, -2 since it is checked above */
	      new_tree->elem_content_left = (base_tree->elem_idx == MGRP_EMPTY_GROUP) ? 0 : base_tree;
	      new_tree->elem_content_right = (!GRP_TREE_IS_PREDEFINED (curr_type_tree)) ?
		xecm_advance_tree (parser, curr_type_tree) : curr_type_tree;
	      new_tree->elem_may_be_empty = 0;
	      new_tree->elem_value = 0;
	      new_tree->elem_attrs.ea_maxoccurs = 1;
	      new_tree->elem_attrs.ea_minoccurs = 1;
	      new_tree->elem_attrs.ea_namespaces = NAMESPACE_ANY;	/* not supported */
	      INFO_CSTYPE (type).lg_group = new_tree;
	    }
	  if (log_tree[0]->elem_idx == MGRP_EMPTY_GROUP)	/* empty declaration */
	    {
	      log_tree[0] = base_tree;
	      goto move;
	    }

#if 0
	  /* check is root of base type is same as in current type */
	  if (base_tree->elem_idx != log_tree[0]->elem_idx)
	    {
	      if (xmlparser_logprintf (parser, XCFG_ERROR,
		  100 + strlen (type->cm_qname) + strlen (base->cm_qname),
		  "Content model of type <%s> is not compatible with model of base type <%s>",
		  type->cm_qname, base->cm_qname ) &&
	          xmlparser_log_cm_location (parser, type, 0) &&
	        xmlparser_log_cm_location (parser, base, 0) );
	      return 0;
	    }
	  else			/* merging, only extension is supported.
				   subject to change */
	    {
	      grp_tree_elem_t *marked_tree_elem =
		  search_marked_node (log_tree[0]);
	      insert_grp_tree (parser, marked_tree_elem, base_tree);
	      /* fall to move */
	    }
#endif
	}
      /* base is primitive type, move tree from log to group */
    move:
      active_tree[0] = log_tree[0];
      if (active_tree[0]->elem_idx == MGRP_EMPTY_GROUP)
	{
	  active_tree[0] = XECM_EMPTY;
	}

      log_tree[0] = 0;

      return XS_COMPOSE_SUCC;
    }
  return XS_COMPOSE_SUCC;
}

#if 0
/*  strip component prefixes from attribute name */
static char *
get_attribute_name (const char * fullname, int is_qualified)
{
  int i, sz = (int) (strlen (fullname));
  int state = 1;
  const char * qual_end = 0, * attr_begin = fullname;
  for (i = sz - 1; i >= 0; i--)
    {
      switch (state)
	{
	case 1:
	  if (fullname[i] == XS_ATTRIBUTE_DELIMETER)
	    {
	      if (!is_qualified)
		{
		  return box_dv_short_string(fullname + i + 1);
		}
	      else
		{
		  state = 0;
		  attr_begin = fullname + i + 1;
		}
	    }
	  else if (fullname[i] == XS_ATTR_QUAL_DELIMETER)
	    {
	      if (!is_qualified)
		return box_dv_short_string (fullname + i + 1);
	      attr_begin = fullname + i + 1;
	      state = -2;
	    }
	  break;
	case 0:
	  if (fullname[i] == XS_ATTR_QUAL_DELIMETER)
	    {
	      qual_end = fullname + i + 1;
	      state = -1;
	    }
	  break;
	default:
	  GPF_T;
	}
      if (state < 0)
	break;
    }
  if (!is_qualified)
    return box_dv_short_string (fullname);
  switch (state)
    {
    case -2: /* qual */
    case 1: /* no delim, no qual*/
      return box_dv_short_string (fullname);
    case 0: /* delim */
      return box_dv_short_string (attr_begin);
    case -1: /* delim + qual */
      {
	size_t res_sz = sz - (attr_begin - qual_end);
	char * res = dk_alloc_box (res_sz, DV_STRING);
	memset (res, 0, box_length (res));
	strncpy (res, fullname, (qual_end - fullname));
	strcpy (res + (qual_end - fullname), attr_begin);
	return res;
      }
    }
  GPF_T;
  return 0; /* keeps compiler happy */
}
#endif


static void
xs_any_attr_compose (xs_component_t * basetype, xs_component_t * type)
{
  switch (type->cm_derivation)
    {
    case XS_DER_RESTRICTION:
      if ((XS_ANY_ATTR_NS_NONE == XS_CM_TYPE(basetype).any_attr_ns) &&
	(XS_ANY_ATTR_NS_NONE != XS_CM_TYPE(type).any_attr_ns) )
	return;
      goto inherit;
    case XS_DER_EXTENSION:
      if ((XS_ANY_ATTR_NS_NONE != XS_CM_TYPE(basetype).any_attr_ns) &&
	(XS_ANY_ATTR_NS_NONE == XS_CM_TYPE(type).any_attr_ns) )
	return;
      goto inherit;
    case XS_DER_SUBSTITUTION:
      return;
    case XS_DER_LIST:
      return;
    case XS_DER_UNION:
      return;
    }
inherit:
  XS_CM_TYPE(type).any_attribute = XS_CM_TYPE(basetype).any_attribute;
  /*dk_free_box (XS_CM_TYPE(type).any_attr_ns);*/
  if (XS_CM_TYPE(basetype).any_attr_ns)
    XS_CM_TYPE(type).any_attr_ns = box_copy (XS_CM_TYPE(basetype).any_attr_ns);
}

/*  inherit all attributes from all referenced attribute groups
    and base type */
int
compose_all_attributes (vxml_parser_t * parser, xs_component_t * type,
    const char * el_qname)
{
  dk_set_t *active_set = 0;
  xecm_attr_t **atts = 0;
  ptrlong *atts_no = 0;
  /* compose attributes from types */
  if (parser->processor.temp.depth++ > SCHEMA_MAX_DEPTH)
    {
      if (xmlparser_logprintf (parser, XCFG_ERROR | XCFG_NOLOGPLACE,
	  strlen (type->cm_qname) + strlen (el_qname),
	  "Inheritance loop in type or attribute group <%s> detected when processing element <%s>",
	  type->cm_qname, el_qname) )
	xmlparser_log_cm_location (parser, type, 0);
      return 0;
    }
  if (!IS_DEFINED (type))
    {
      if (xmlparser_logprintf (parser, XCFG_ERROR | XCFG_NOLOGPLACE,
	  100 + strlen (type->cm_qname) + strlen (el_qname),
	  "Found undefined base type <%s> of element <%s>", type->cm_qname,
	  el_qname) )
	xmlparser_log_cm_location (parser, type, 0);
      return 0;
    }
  if (IS_SIMPLE_TYPE(type) || IS_COMPLEX_TYPE(type))
    {
/*
      if (0 == type->cm_derivation)
	GPF_T;
*/
	{
	  xs_component_t *basetype;
	  basetype = (xs_component_t *)
	    (IS_BOX_POINTER (type->cm_typename) ? type->cm_typename : 0);
	  if (INFO_CSTYPE (type).composed_atts_no != 0)	/* composed already */
	    return XS_COMPOSE_SUCC;
	  if (INFO_CSTYPE (type).lg_agroup)
	    active_set = &INFO_CSTYPE (type).lg_agroup;
	  atts = &INFO_CSTYPE (type).composed_atts;
	  atts_no = &INFO_CSTYPE (type).composed_atts_no;
	  if (type->cm_derivation == XS_DER_RESTRICTION)
	    basetype = 0;
	  if (basetype)
	    {			/* compose base types */
	      if (!compose_all_attributes (parser, basetype, el_qname))
		return 0;
	      if (INFO_CSTYPE (basetype).composed_atts_no)
		{
		  if (-1 == ecm_fuse_arrays ((caddr_t *) atts, atts_no,
				     (caddr_t) INFO_CSTYPE (basetype).composed_atts,
				     INFO_CSTYPE (basetype).composed_atts_no,
				     sizeof (xecm_attr_t), 1, parser->processor.sp_schema->pool ) )
		    {
		      if (xmlparser_logprintf (parser, XCFG_ERROR | XCFG_NOLOGPLACE,
			     100 + strlen (basetype->cm_qname) + strlen (el_qname),
			     "Attribute from basetype <%s> of element <%s> has been inherited already",
			     basetype->cm_qname, el_qname) )
			   xmlparser_log_cm_location (parser, type, 0);
		      return 0;
		    }
		}
	      xs_any_attr_compose (basetype, type);
	    }
	}
    }
  else if (XS_COM_ATTRGROUP == MAJOR_ID(type))
    {
      if (INFO_ATTRGROUP (type).composed_atts_no != 0)
	return XS_COMPOSE_SUCC;
      if (INFO_ATTRGROUP (type).lg_agroup)
	{
	  active_set = &INFO_ATTRGROUP (type).lg_agroup;
	  atts = &INFO_ATTRGROUP (type).composed_atts;
	  atts_no = &INFO_ATTRGROUP (type).composed_atts_no;
	}
    }
#ifdef XMLSCHEMA_UNIT_DEBUG
  else
    GPF_T;
#endif
  if (active_set)
    {
      DO_SET (xs_component_t *, attg, active_set)
      {
	if (attg->cm_type.t_major == XS_COM_ATTRIBUTE)
	  {
	    ptrlong idx;
	    xecm_attr_t *attr_el;
	    char * attg_attr_name = 0;
#if 0
	    if (parser->processor.sp_schema->sp_att_qualified == XS_UNQUAL)
	      idx = ecm_add_name ((attg_attr_name = get_attribute_name (attg->cm_longname, 0)),
				  (void **) atts,  atts_no, sizeof (xecm_attr_t));
	    else if (parser->processor.sp_schema->sp_att_qualified == XS_QUAL)
	      idx = ecm_add_name ((attg_attr_name = get_attribute_name (attg->cm_longname, 1)),
				  (void **) atts, atts_no, sizeof (xecm_attr_t));
	    else
	      GPF_T;
#else
	    attg_attr_name = attg->cm_elname;
	    idx = ecm_add_name (attg_attr_name, (void **) atts,  atts_no, sizeof (xecm_attr_t));
#endif	      
	    attr_el = atts[0] + idx;
	    if (ECM_MEM_UNIQ_ERROR == idx)
	      {
		/* attg_attr_name is in memory pool. dk_free_box (attg_attr_name); */
		if (xmlparser_logprintf (parser, XCFG_ERROR | XCFG_NOLOGPLACE,
		    100 + strlen (attg->cm_qname) + strlen (el_qname),
		    "Attribute <%s> in element <%s> have been inherited already, redefinition is ignored",
		    attg->cm_qname, el_qname) &&
		  xmlparser_log_cm_location (parser, attg, 0) )
		  xmlparser_log_cm_location (parser, type, 0);
		continue;
	      }
        /*mapping schema*/
            attr_el->attr_component = (ptrlong) attg;
        /*end mapping schema*/
	    /* copy attribute info from component to attribute element */
	    attr_el->xa_type.ref = attg->cm_typename;
	    switch (INFO_ATTRIBUTE (attg).use)
	      {
	      case XS_ATTRIBUTE_USE_OPT:
		attr_el->xa_is_implied = 1;
		break;
	      case XS_ATTRIBUTE_USE_REQ:
		attr_el->xa_required = 1;
		break;
	      case XS_ATTRIBUTE_USE_PRH:
		attr_el->xa_is_prohibited = 1;
		break;
#ifdef XMLSCHEMA_UNIT_DEBUG
	      default:
		GPF_T1 ("unknown use option");
#endif
	      }
	    if (attg->cm_defval)
	      {
		attr_el->xa_value_sel = XEA_DEFAULT;
		attr_el->xa_value._default.ptr = attg->cm_defval;
	      }
	    else if (INFO_ATTRIBUTE (attg).fixval)
	      {
		attr_el->xa_value_sel = XEA_FIXED;
		attr_el->xa_value._fixed.ptr = INFO_ATTRIBUTE (attg).fixval;
	      }
	    attr_el->xa_pr_typeidx =
		xs_get_primitive_typeidx (parser, attg->cm_typename);
	    /* end */
	  }
	else if (attg->cm_type.t_major == XS_COM_ATTRGROUP)
	  {
	    xs_any_attr_compose (attg, type);
	    if (!compose_all_attributes (parser, attg, el_qname))
	      continue;
	    if (-1 == ecm_fuse_arrays ((char **) atts, atts_no,
		    (char *) INFO_ATTRGROUP (attg).composed_atts,
		    INFO_ATTRGROUP (attg).composed_atts_no,
		    sizeof (xecm_attr_t), 1, parser->processor.sp_schema->pool ) )
	      {
		if (xmlparser_logprintf (parser, XCFG_ERROR | XCFG_NOLOGPLACE,
		    100 + strlen (attg->cm_qname) + strlen (el_qname),
		    "Attribute from attribute group <%s> in element <%s> has been inherited already, redefinition is ignored",
		    attg->cm_qname, el_qname) &&
		  xmlparser_log_cm_location (parser, attg, 0) )
		  xmlparser_log_cm_location (parser, type, 0);
		continue;
	      }
	  }
	else
	  {
	    if (xmlparser_logprintf (parser, XCFG_WARNING | XCFG_NOLOGPLACE,
		100 + strlen (attg->cm_qname) + strlen (el_qname),
		"Attribute <%s> in element <%s> is ignored", attg->cm_qname,
		el_qname) &&
	      xmlparser_log_cm_location (parser, attg, 0) )
	      xmlparser_log_cm_location (parser, type, 0);
	  }
      }
      END_DO_SET ();
      dk_set_free (active_set[0]);
      active_set[0] = 0;
      if ((type->cm_type.t_major == XS_COM_COMPLEXT) ||
	  (type->cm_type.t_major == XS_COM_SIMPLET))
	{
	  ptrlong i;
	  for (i = 0; i < atts_no[0]; i++)
	    {
	      xecm_attr_t *xattr = atts[0] + i;
	      if (0 == xattr->xa_required)
	        continue;
	      INFO_CSTYPE (type).req_atts_no += 1;
	      xattr->xa_required = INFO_CSTYPE (type).req_atts_no;
	    }
	}
      SHOULD_BE_CHANGED;	/* free resources */
      return XS_COMPOSE_SUCC;
    }
  return XS_COMPOSE_SUCC;
}

int
xecm_create_all_fsas (vxml_parser_t * parser)
{
  schema_parsed_t *schema = parser->processor.sp_schema;
  id_hash_iterator_t hit;
  char **name;
  xs_component_t **elem;
  xs_component_t **type;

  for (id_hash_iterator (&hit, schema->sp_elems); hit_next (&hit, (char **) &name, (char **) &elem); /* no step */ )
    {
      if (elem[0]->cm_xecm_idx == -1)
	{
	  elem[0]->cm_xecm_idx = xecm_add_element (elem[0],
	      (void **)(&(schema->sp_xecm_els)),
	      &schema->sp_xecm_el_no, sizeof (xecm_el_t));
	}
    }
  
/* iterate over all types, since type casting exists by xsi:type */
  for (id_hash_iterator (&hit, schema->sp_types); hit_next (&hit, (char **) &name, (char **) &type); /* empty */)
    {
      xs_component_t * el_type = type[0];
      el_type = get_recent_component (el_type);
      if (0 == INFO_CSTYPE (el_type).pcdata_mode)
        {
          xs_component_t *ancestor = el_type;
          int rec_ctr = 32;
          while (IS_POINTER(ancestor->cm_typename) && !IS_UNDEF_TYPE(ancestor->cm_typename) && rec_ctr--)
            {
	      ptrlong base_pcdata_mode = INFO_CSTYPE (ancestor->cm_typename).pcdata_mode;
	      if (0 != base_pcdata_mode)
		{
	          INFO_CSTYPE (el_type).pcdata_mode = base_pcdata_mode;
	          break;
	        }
	      ancestor = ancestor->cm_typename;
	    }
	}
      if (!el_type->cm_states && INFO_CSTYPE (el_type).group != XECM_ANY
	  && INFO_CSTYPE (el_type).group != XECM_EMPTY)
	{			/* compose all lg_groups from whole derivation line */
	  parser->processor.temp.depth = 0;
	  compose_all_groups (parser, el_type);
	  parser->processor.temp.depth = 0;
	  compose_all_attributes (parser, el_type, el_type->cm_qname);
	  xecm_create_fsa (INFO_CSTYPE (el_type).group, el_type,
		  &parser->processor);
	}
#ifdef DEBUG
      if (type[0]->cm_states && (
		xecm_validate_fsm_type (type[0], schema, 0) ||
		xecm_validate_fsm_type (type[0], schema, 1)
#ifdef PRINT_FSA
		|| 1
#endif
		) )
	{
	  char * tmp;
	  tmp = xecm_print_fsm_type (type[0], schema, 1);
	  printf ("[%s] ==> RAW\n%s\n", type[0]->cm_qname, tmp);
	  dk_free_box (tmp);
	  tmp = xecm_print_fsm_type (type[0], schema, 0);
	  printf ("[%s] ==> DETERMINISTIC\n%s\n", type[0]->cm_qname, tmp);
	  dk_free_box (tmp);
#ifndef PRINT_FSA
	  GPF_T1 ("Bad fsa");
#endif
	}
#endif
    }
  for (id_hash_iterator (&hit, schema->sp_elems); hit_next (&hit, (char **) &name, (char **) &elem); /* no step */ )
    {
      xecm_el_t *xecm_el = schema->sp_xecm_els + elem[0]->cm_xecm_idx;
      xs_component_t *el_type = NULL;
      if (IS_BOX_POINTER (elem[0]->cm_typename))
        {
          el_type = elem[0]->cm_typename;
          if (IS_UNDEF_TYPE(el_type))
            el_type = NULL;
        }
      if (el_type)
	{
	  if (el_type->cm_states)
	    goto fill_xecm_el_t;
	  el_type = get_recent_component (el_type);
	  if (0 == INFO_CSTYPE (el_type).pcdata_mode)
	    {
	      xs_component_t *ancestor = el_type;
	      int rec_ctr = 32;
	      while (IS_POINTER(ancestor->cm_typename) && !IS_UNDEF_TYPE(ancestor->cm_typename) && rec_ctr--)
	        {
		  ptrlong base_pcdata_mode = INFO_CSTYPE (ancestor->cm_typename).pcdata_mode;
	          if (0 != base_pcdata_mode)
	            {
	              INFO_CSTYPE (el_type).pcdata_mode = base_pcdata_mode;
	              break;
	            }
	          ancestor = ancestor->cm_typename;
	        }
	    }
	  if (!el_type->cm_states)
	    {			/* compose all lg_groups from whole derivation line */
	      parser->processor.temp.depth = 0;
	      compose_all_groups (parser, el_type);
	      parser->processor.temp.depth = 0;
	      compose_all_attributes (parser, el_type, elem[0]->cm_qname);
	      xecm_create_fsa (INFO_CSTYPE (el_type).group, el_type,
		  &parser->processor);
	    }
fill_xecm_el_t:
	  xecm_el->xee_states = el_type->cm_states;
	  xecm_el->xee_st_no = el_type->cm_state_no;
#ifdef DEBUG
	  xecm_el->xee_raw_states = el_type->cm_raw_states;
	  xecm_el->xee_raw_st_no = el_type->cm_raw_state_no;
#endif	  
	  xecm_el->xee_attrs = INFO_CSTYPE (el_type).composed_atts;
	  xecm_el->xee_attrs_no = INFO_CSTYPE (el_type).composed_atts_no;
	  xecm_el->xee_req_atts_no = INFO_CSTYPE (el_type).req_atts_no;
	  xecm_el->xee_pcdata_mode = INFO_CSTYPE (el_type).pcdata_mode;
	  xecm_el->xee_any_attribute = XS_CM_TYPE (el_type).any_attribute;
	  xecm_el->xee_any_attr_ns = XS_CM_TYPE (el_type).any_attr_ns;
	  xecm_el->xee_is_nillable = INFO_ELEMENT (elem[0]).is_nillable;
#ifdef DEBUG
	  if (type[0]->cm_states && (
		xecm_validate_fsm (elem[0]->cm_xecm_idx, schema, 0) ||
		xecm_validate_fsm (elem[0]->cm_xecm_idx, schema, 1)
#ifdef PRINT_FSA
		|| 1
#endif
		) )
	  {
	    char * tmp;
	    tmp = xecm_print_fsm (elem[0]->cm_xecm_idx, schema, 1);
	    printf ("[%s] ==> (RAW)\n%s\n", elem[0]->cm_qname, tmp);
	    dk_free_box (tmp);
	    tmp = xecm_print_fsm (elem[0]->cm_xecm_idx, schema, 0);
	    printf ("[%s] ==> (DETERMINISTIC)\n%s\n", elem[0]->cm_qname, tmp);
	    dk_free_box (tmp);
	    tmp = xecm_print_attributes (elem[0]->cm_xecm_idx, schema);
	    printf ("[%s] ==> (ATTRIBUTES)\n%s\n", elem[0]->cm_qname, tmp);
	    dk_free_box (tmp);
#ifndef PRINT_FSA
	    GPF_T1("Bad FSA");
#endif
	  }
#endif
	}
      else			/* primitive types has empty content model */
	{
	  if (!schema->sp_empty_states)
	    {
	      xecm_fts_context_t xfc;
	      xfc.xfc_states = &(schema->sp_empty_states);
	      xfc.xfc_state_no = &(schema->sp_empty_st_no);
	      xfc.xfc_processor = &(parser->processor);
	      xfc.xfc_schema = schema;  
	      xfc_term_to_fsa (&xfc, XECM_EMPTY);
	      xfc_make_fsa_deterministic (&xfc);
	    }
	  xecm_el->xee_states = schema->sp_empty_states;
	  xecm_el->xee_st_no = schema->sp_empty_st_no;
	  xecm_el->xee_pcdata_mode = XS_PCDATA_TYPECHECK;
	}
    }
  return 1;
}

#ifdef DEBUG

char *
xecm_print_fsm_impl (xecm_st_t *states, xecm_st_idx_t cols, schema_parsed_t * schema)
{
  xecm_el_idx_t row, rows = XECM_EL_OFFSET + schema->sp_xecm_el_no + schema->sp_xecm_namespace_no;
  xecm_st_idx_t col;
  size_t bufsize = (rows + 2) * (cols * 20 + 300);
  caddr_t buf = dk_alloc_box (bufsize, DV_LONG_STRING);
  caddr_t tail = buf;
  caddr_t ret;
  char numbuf[80];
  memset (buf, ' ', bufsize);
  buf[bufsize - 1] = '\0';
  /* Lines with caption */
  tail += sprintf (tail, "%30s |"," ");
  for (col = 0; col < cols; col++)
    {
      sprintf (numbuf, "%ld = %ld", (long)col, states[col].xes_eqclass);
      tail += sprintf (tail, "%12s", numbuf);
    }
  (tail++)[0] = '\n';
  /* Lines with inputs */
  for (row = 0; row < rows; row++)
    {        
      const char *name = "<BUG>";
      int name_can_appear = 0;
      for (col = 0; col < cols; col++)
	{ 
	  xecm_nexts_array_t *nexts = states[col].xes_nexts;
          if (row >= XECM_EL_OFFSET)
	    {
	      xecm_st_info_t *jmp = xecm_get_next (nexts, row);
	      if (XECM_ST_ERROR == jmp->xsi_idx)
		continue;
	    }
	  else
	    {
	      ptrlong nst = xecm_get_nextidx (nexts, row);
	      if (XECM_ST_ERROR == nst)
	        continue;
	    }
	  name_can_appear = 1;
	  break;
	}
      if (!name_can_appear)
        continue;
      switch (row - XECM_EL_OFFSET)
	{
	case XECM_EL_EOS:
	  name = "EOS";
	  break;
	case XECM_EL_PCDATA:
	  name = "PCD";
	  break;
	case XECM_EL_NULL_T:
	  name = "NULL";
	  break;
	case XECM_EL_ANY_LOCAL:
	  name = "ANY LOCAL";
	  break;
	case XECM_EL_ANY_NOT_LISTED_NS:
	  name = "ANY NOT LISTED";
	  break;
	default:
	  {
	    if (row >= (XECM_EL_OFFSET + schema->sp_xecm_el_no))
	      name = schema->sp_xecm_namespaces [row - (XECM_EL_OFFSET + schema->sp_xecm_el_no)];
	    else
	      {
		id_hash_iterator_t hit;
		char** elname;
		dk_set_t * set;
		for (id_hash_iterator (&hit, schema->sp_all_elnames); hit_next(&hit, (char**)&elname, (char**)&set); /* no step*/)
		  {
	            if (((xs_component_t *)(set[0]->data))->cm_elname_idx != (row - XECM_EL_OFFSET))
		      continue;
		    name = elname[0];
	            break;
		  }
	      }
	  }
	}
      tail += sprintf (tail, "%30s |", name);
      for (col = 0; col < cols; col++)
	{    
	  xecm_st_info_t *jmp =
	    xecm_get_next (states[col].xes_nexts, row);
          if (row >= XECM_EL_OFFSET)
	    {
		if (XECM_INF_MAXOCCURS == jmp->xsi_max_counters)
		  sprintf (numbuf, "%ld %ld...", jmp->xsi_idx, jmp->xsi_min_counters);
		else
		  sprintf (numbuf, "%ld %ld-%ld", jmp->xsi_idx, jmp->xsi_min_counters, jmp->xsi_max_counters);
	    }
	  else
	    {
	      sprintf (numbuf, "%ld", xecm_get_nextidx (states[col].xes_nexts, row));
	    }
	  tail += sprintf (tail, "%12s", numbuf);
	}
      (tail++)[0] = '\n';
    }
  ret = box_dv_short_nchars (buf, tail-buf);
  dk_free_box (buf);
  return ret;
}


char *
xecm_print_fsm (xecm_el_idx_t el_idx, schema_parsed_t * schema, int use_raw)
{
  xecm_el_t *el = schema->sp_xecm_els + el_idx;
  xecm_st_idx_t cols = (use_raw ? el->xee_raw_st_no : el->xee_st_no);
  xecm_st_t *states = (use_raw ? el->xee_raw_states : el->xee_states);
  return xecm_print_fsm_impl (states, cols, schema);
}


char *
xecm_print_fsm_type (xs_component_t * type, schema_parsed_t * schema, int use_raw)
{
  xecm_st_idx_t cols = (use_raw ? type->cm_raw_state_no : type->cm_state_no);
  xecm_st_t *states = (use_raw ? type->cm_raw_states : type->cm_states);
  return xecm_print_fsm_impl (states, cols, schema);
}


char *
xecm_print_attributes (xecm_el_idx_t idx, schema_parsed_t * schema)
{
  xecm_el_t *el = schema->sp_xecm_els + idx;
  ptrlong i = 0;
  xecm_attr_t *atts = el->xee_attrs;
  ptrlong cols = el->xee_attrs_no;
  char *buf = dk_alloc_box ((cols * 18 + 1) * 3 + 1, DV_LONG_STRING);
  char *tail = buf;
  memset (buf, ' ', (cols * 18 + 1) * 3);
  printf ("Attributes of element <%s>:\n", el->xee_component->cm_qname);
  for (; i < cols; i++)
    {				/* caption */
      tail[0] = '|';
      tail++;
      strncpy (tail, atts[i].xa_name, min (strlen (atts[i].xa_name), 16));
      tail += 16;
    }
  *(tail++) = '\n';
  memset (tail, '-', 17 * cols);
  tail += 17 * cols;
  *(tail++) = '\n';
  for (i = 0; i < cols; i++)
    {				/* caption */
      const char *name = "UNKNOWN";
      tail[0] = '|';
      tail++;
      if (IS_BOX_POINTER (atts[i].xa_type.ref))
	{
	  xs_component_t *type = atts[i].xa_type.ref;
	  name = type->cm_qname;
	}
      else
	name = xs_builtin_type_info_dict[atts[i].xa_type.idx].binfo_name;
      strncpy (tail, name, min (strlen (name), 8));
      tail += 16;
    }
  *(tail++) = '\n';
  *(tail++) = '\0';
  return buf;
}


int
xecm_validate_fsm_impl (xecm_st_t *states, xecm_st_idx_t cols, schema_parsed_t * schema, int use_raw)
{
  xecm_el_idx_t row, rows = XECM_EL_OFFSET + schema->sp_xecm_el_no + schema->sp_xecm_namespace_no;
  xecm_st_idx_t col;
#if 0  
  size_t bufsize = (rows + 2) * (cols * 20 + 300);
  caddr_t buf = dk_alloc_box (bufsize, DV_LONG_STRING);
  caddr_t tail = buf;
#endif  
  for (col = 0; col < cols; col++)
    {
      xecm_nexts_array_t *nexts = states[col].xes_nexts;
      if ((nexts->na_type_sel == XECM_STORAGE_RAW) && (rows != nexts->na_max_idx))
	return 1;
    }
  for (row = 0; row < rows; row++)
    {
      for (col = 0; col < cols; col++)
	{    
	  xecm_st_info_t *jmp =
	    xecm_get_next (states[col].xes_nexts, row);
          int minc = jmp->xsi_min_counters, maxc = jmp->xsi_max_counters;
	  if (XECM_ST_ERROR == jmp->xsi_idx)
	    {
	      if ((0 != minc) || ((XECM_INF_MAXOCCURS != maxc) && (0 != maxc)))
		return 1;
	    }
	  else
	    {
	      if ((0 > jmp->xsi_idx) || (cols <= jmp->xsi_idx))
		return 1;
/*              if (((1 != minc) || (1 != maxc)) && (states[jmp->xsi_idx].xes_eqclass != states[col].xes_eqclass) && use_raw)
		return 1;*/
              if (minc > maxc)
		return 1;
	    }
	}
    }
  return 0;
}


int
xecm_validate_fsm (xecm_el_idx_t el_idx, schema_parsed_t * schema, int use_raw)
{
  xecm_el_t *el = schema->sp_xecm_els + el_idx;
  xecm_st_idx_t cols = (use_raw ? el->xee_raw_st_no : el->xee_st_no);
  xecm_st_t *states = (use_raw ? el->xee_raw_states : el->xee_states);
  return xecm_validate_fsm_impl (states, cols, schema, use_raw);
}


int
xecm_validate_fsm_type (xs_component_t * type, schema_parsed_t * schema, int use_raw)
{
  xecm_st_idx_t cols = (use_raw ? type->cm_raw_state_no : type->cm_state_no);
  xecm_st_t *states = (use_raw ? type->cm_raw_states : type->cm_states);
  return xecm_validate_fsm_impl (states, cols, schema, use_raw);
}


#endif /* DEBUG */

/* end of stolen code */

ptrlong
xecm_add_element (xs_component_t * elem, void **objs, ptrlong * obj_no,
    size_t sizeof_obj)
{
  if (!elem)
    return -1;
  if (!*objs)
    {
      *objs =
	  dk_alloc_box (max (sizeof (long),
	  sizeof_obj) * XECM_MEM_PREALLOCATE_ITEMS, DV_ARRAY_OF_LONG);
      memset (*objs, 0, max (sizeof (long),
	      sizeof_obj) * XECM_MEM_PREALLOCATE_ITEMS);
    }
  if (sizeof_obj * (*obj_no + 1) > box_length (*objs))
    {
      caddr_t new_objs =
	  dk_alloc_box (box_length (*objs) * 2, DV_ARRAY_OF_LONG);
      memcpy (new_objs, *objs, sizeof_obj * (*obj_no));
      memset (new_objs + sizeof_obj * (*obj_no), 0,
	  box_length (new_objs) - sizeof_obj * (*obj_no));
      dk_free_box (*objs);
      *objs = new_objs;
    }
  *((xs_component_t **) ((caddr_t) (*objs) + sizeof_obj * (obj_no[0]++))) =
      elem;
  return obj_no[0] - 1;
}

/* \return NULL if failed */
char *
xs_get_entity (vxml_parser_t * parser, const char * value)
{
  xml_def_4_entity_t **ent_repl;
  char *name = (char*)(value + 1);
  size_t name_sz = strlen (name);
  if (!name_sz || (name[name_sz - 1] != ';'))
    return NULL;
  name[name_sz - 1] = 0;
  ent_repl =
      (xml_def_4_entity_t **) id_hash_get (parser->validator.dv_dtd->ed_generics, (caddr_t) (&name));
  if (!ent_repl)
    return NULL;
  else
    return ent_repl[0]->xd4e_repl.lm_memblock;
}


#define ATTR_TYPE(attr) ( IS_BOX_POINTER((attr)->attr_component) ?\
 ((xs_component_t*) ((attr)->attr_component))->cm_typename : NULL)

int
schema_check_attribute (vxml_parser_t * parser, const char * value,
    struct xecm_attr_s *attr)
{
  dtd_config_t *conf = &parser->processor.sp_schema->sp_curr_config;
  /* fake char to force interpret empty string as string */
  char ch = (strlen (value)) ? value[0] : '\r';
  char *val;
  int ret = 0;
  xs_component_t * type = IS_BOX_POINTER (ATTR_TYPE(attr)) ? ATTR_TYPE(attr) : NULL;

  ptrlong mode = conf->dc_attr_misformat;
  if (XCFG_DISABLE == mode)
    return 1;
  /* replacement execution */
  if (ch == '&')
    {
      val = xs_get_entity (parser, value);
      if (NULL == val)
	{
	  xs_set_error (parser, mode,
	      strlen (attr->xa_name) + strlen (value) + 100,
	      "Could not resolve entity '%s' for attribute [%s]", value,
	      attr->xa_name);
	  return 0;
	}
    }
  else
    val = (char *) value;
  switch (xs_builtin_type_info_dict[attr->xa_pr_typeidx].binfo_typeid)
    {
    case XS_BLTIN_ID:
      if (XCFG_DISABLE != conf->dc_id_dupe)
	{
	  ecm_id_t *id =
	      (ecm_id_t *) ecm_try_add_name (val, parser->ids,
	      sizeof (ecm_id_t));
	  if (id->id_defined)
	    {
	      xmlparser_logprintf (parser, conf->dc_id_dupe,
		  ECM_MESSAGE_LEN + strlen (val),
		  "ID %s has been used already.  [VC: ID]", val);
	      break;
	    }
	  else
	    {
	      id->id_defined = 1;
	      /* ID is defined, log is not needed */
	      free_refid_log (&id->id_log);
	    }
	  ret = 1;
	};
      break;
    case XS_BLTIN_IDREFS:
      if (XCFG_DISABLE != conf->dc_idref_dangling)
	{
	  char *idrefs = box_string (val);
	  char *idrefs_iter = idrefs;
	  char *idref = strtok_r (idrefs, " \t\r\n", (char **) &idrefs_iter);
	  ret = 1;
	  while (idref)
	    {
	      if (!get_refentry (parser, idref))
		{
		  ret = 0;
		  break;
		}
	      else
		idref = strtok_r (NULL, " \t\r\n", (char **) &idrefs_iter);
	    }
	  dk_free_box (idrefs);
	};
      break;
    case XS_BLTIN_IDREF:
      if ((XCFG_DISABLE == conf->dc_idref_dangling) ||
	  get_refentry (parser, val))
	ret = 1;
      break;
    default:
      ret = 1;
    }
  /* removed */
  if (attr->xa_value_sel == XEA_FIXED)
    {
      if (strcmp (attr->xa_value._fixed.ptr, val))
	{
	  xs_set_error (parser, mode,
	      strlen (attr->xa_name) + strlen (val) +
	      strlen (attr->xa_value._fixed.ptr) + 100,
	      "Unexpected attribute value '%s', must be '%s'. [%s]", val,
	      attr->xa_value._fixed.ptr, attr->xa_name);
	  return 0;
	}
    }
  if (ret)			/* everything is fine, more checking */
    {
      if (type && (type->cm_derivation == XS_DER_LIST))
	{
	  char *toks = box_string (val);
	  char *toks_iter = toks;
	  char *tok = strtok_r (toks, " \t\r\n", (char **) &toks_iter);
	  while (tok)
	    {
	      xs_check_type_compliance (parser, (xs_component_t*)attr->xa_type.idx, tok, 0);
	      tok = strtok_r (NULL, " \t\r\n", (char **) &toks_iter);
	    }
	  dk_free_box (toks);
	}
      else
	return !xs_check_type_compliance (parser, (xs_component_t*)attr->xa_type.idx, val, 0);
    }
  return ret;
}

/* Schema Validation handlers */

#ifdef XMLSCHEMA_UNIT_DEBUG
int bobnum = 0;
#endif


#define XSI_ATTR_SCHEMALOCATION			0x01
#define XSI_ATTR_NONAMESPACESCHEMALOCATION	0x02
#define XSI_ATTR_TYPE				0x03
#define XSI_ATTR_NIL				0x04
#define XSI_ATTR_MASK				0xff
#define XSI_VERSION_2000			0x0100
#define XSI_VERSION_2001			0x0200
#define XSI_VERSION_MASK			0xff00

#define XSI_ATTR_GET_SCHEMALOCATION(res) ((res & XSI_ATTR_MASK) == XSI_ATTR_SCHEMALOCATION) ? res : \
		((res & XSI_ATTR_MASK) == XSI_ATTR_NONAMESPACESCHEMALOCATION) ? res : 0

typedef struct schema_attr_s
{
  const char *	attr_name;
  int	attr_res;
} schema_attr_t;

schema_attr_t xsi_attrs[] =
  {
    { "nil", XSI_ATTR_NIL },
    { "noNamespaceSchemaLocation", XSI_ATTR_NONAMESPACESCHEMALOCATION },
    { "schemaLocation", XSI_ATTR_SCHEMALOCATION },
    { "type", XSI_ATTR_TYPE }
  };
const unsigned long xsi_attrs_no = sizeof (xsi_attrs) / sizeof (schema_attr_t);

static int xsi_schema_attr_code (vxml_parser_t *parser, char *attr)
{
  char * delim_offset = strrchr (attr, ':');
  char *locname;
  lenmem_t ns_uri, *lm_equal_tmp1, *lm_equal_tmp2;
  int res;
  ptrlong idx;

  if (delim_offset)
    locname = delim_offset + 1;
  else
    locname = attr;

  idx = ecm_find_name (locname, xsi_attrs, xsi_attrs_no, sizeof (schema_attr_t));
  if (idx == -1)
    return 0;
  res = xsi_attrs[idx].attr_res;
  VXmlFindNamespaceUriByQName (parser, attr, 1, &ns_uri);
  if (NULL == ns_uri.lm_memblock)
    return 0;
  if (!LM_EQUAL_TO_STR (&ns_uri, "http://www.w3.org/2001/XMLSchema-instance"))
    return res | XSI_VERSION_2001;
  if (!LM_EQUAL_TO_STR (&ns_uri, "http://www.w3.org/2000/10/XMLSchema-instance"))
    return res | XSI_VERSION_2000;
  if (NULL != strstr (ns_uri.lm_memblock, "XMLSchema-instance"))
    return res;
  return 0; /* Occasional match */
}


int schema_attr_is_location (vxml_parser_t *parser, char *attr)
{
  int res = xsi_schema_attr_code (parser, attr);
  if ((res & XSI_ATTR_SCHEMALOCATION) ||
      (res & XSI_ATTR_NONAMESPACESCHEMALOCATION))
    return res;
  return 0;
}


xs_component_t * xs_get_type (vxml_parser_t * parser, const char * val)
{
  caddr_t type = VXmlFindExpandedNameByQName (parser, val, 0);
  xs_component_t **dict_entry;
  xs_component_t *res;
  id_hash_t *types = parser->processor.sp_schema->sp_types;
  dict_entry = (xs_component_t **) ((NULL == types) ? NULL : id_hash_get (types, (caddr_t) & type));
  if (dict_entry)
    res = dict_entry[0];
  else
    res = xs_get_builtinidx (parser, type, NULL, 0);
  dk_free_box (type);
  return res;
}


int is_attr_boolean (const char * attr_val, int is_true)
{
  const char * check_val = is_true ? XS_TRUE : XS_FALSE;
  if (!stricmp (check_val, attr_val))
    return 1;
  return 0;
}

void
xsv_start_element_handler (void *parser_v,
    const char * name, vxml_parser_attrdata_t * attrdata)
{
  vxml_parser_t *parser = (vxml_parser_t *) parser_v;
  schema_processor_t *proc = &parser->processor;
  schema_parsed_t *schema = proc->sp_schema;
  ptrlong fsa_cfg = schema->sp_curr_config.dc_fsa;
  xecm_attr_t * curr_type_attrs;
  ptrlong curr_type_attrs_no;
  int local_is_nil = 0;
  tag_attr_t *attr;
  tag_attr_t *attr_end;
  xsv_astate_t *newstate;
  char *fullname = 0;
  ptrlong local_nameidx;
  xs_component_t *local_comp, *xsi_local_type, **local_el_ptr;
  xecm_st_idx_t curidx;
  xecm_st_t *st;
  xecm_st_info_t *newst;
  xecm_el_t *local_xecm_el;
  ptrlong attr_unk_mode;
  ptrlong attr_misformat_mode;
  ptrlong attr_missing_mode;
  int attr_req_no;
  uint32 attr_req_hit_mask;
  const char *elem_value;
  
#ifdef XMLSCHEMA_UNIT_DEBUG
  bobnum++;
#endif
  proc->sp_simpletype_value_acc.lm_length = 0;
  proc->sp_simpletype_depth = 0;
  if (XCFG_DISABLE == fsa_cfg)
    goto end;
  if (proc->sp_depth > (ECM_MAX_DEPTH - 1))
    goto end;

  newstate = parser->processor.sp_stack + parser->processor.sp_depth;
  memset (newstate, 0, sizeof (xsv_astate_t));
  newstate[0].xa_state = XECM_ST_ERROR;
  if (parser->processor.sp_depth && newstate[-1].xa_state == XECM_ST_ERROR)
    goto end;

  fullname = 0;
  local_nameidx = XECM_EL_UNDEF;
  local_comp = NULL;
  xsi_local_type = NULL;
  local_xecm_el = NULL;

  attr = attrdata->local_attrs;
  attr_end = attr + attrdata->local_attrs_count;
/* First of all, let's try to load the schema if possible */

  if (parser->processor.sp_schema->sp_schema_is_loaded)
    goto skip_schema_loading;

  if (0 != parser->processor.sp_depth)
    goto skip_schema_loading;

  for (/* no init */; attr < attr_end; attr++)
    {
      int res = xsi_schema_attr_code (parser, attr->ta_raw_name.lm_memblock);
      int xsi_attr = XSI_ATTR_GET_SCHEMALOCATION (res);
      if (xsi_attr)
	{
	  if (NULL != parser->cfg.auto_load_xmlschema_uri)
	    {
	      xmlparser_logprintf (parser, XCFG_WARNING,
		  100 + attr->ta_raw_name.lm_length + strlen (attr->ta_value),
		  "XML Document contains explicit XSD %s='%s'. It will be used", attr->ta_raw_name.lm_memblock, attr->ta_value );
	      parser->cfg.auto_load_xmlschema_uri = NULL;
	    }
          parser->cfg.auto_load_xmlschema_uri = NULL;
	  if (load_external_schemas (parser, xsi_attr, attr->ta_value))
	    goto end;
	  parser->processor.sp_schema->sp_schema_is_loaded = 1;
	}
    }
  if (NULL != parser->cfg.auto_load_xmlschema_uri)
    {
      if (load_external_schema (parser, parser->cfg.auto_load_xmlschema_uri, 0))
	{
	  xmlparser_logprintf (parser, XCFG_FATAL,
		     100 + strlen (parser->cfg.auto_load_xmlschema_uri),
		     "XML Schema Declaration <%s> is not valid",
		     parser->cfg.auto_load_xmlschema_uri );
	  parser->cfg.auto_load_xmlschema_uri = NULL;
	  goto end;
	}
      parser->cfg.auto_load_xmlschema_uri = NULL;
      parser->processor.sp_schema->sp_schema_is_loaded = 1;
    }
  if (!parser->processor.sp_schema->sp_schema_is_loaded)
    {			/* error in schema declaration */
      xmlparser_logprintf (parser, XCFG_FATAL, 100,
	"No schema declaration found, schema is not loaded");
      goto end;
    }

skip_schema_loading:

  for (/* no init */; attr < attr_end; attr++)
    {
      int res = xsi_schema_attr_code (parser, attr->ta_raw_name.lm_memblock);
      switch (res & XSI_ATTR_MASK)
	{
	case XSI_ATTR_TYPE:
	  xsi_local_type = xs_get_type (parser, attr->ta_value);
	  if (!xsi_local_type)
	    {
	      xmlparser_logprintf (parser, XCFG_FATAL,
			 100 + strlen (attr->ta_value)*2,
			 "type cast to [%s] is impossible, since [%s] is not a known type name",
			 attr->ta_value, attr->ta_value );
	      goto end;
	    }
	  break;
	case XSI_ATTR_NIL:
	  if (is_attr_boolean (attr->ta_value, 1))
	    { local_is_nil = 1; continue; }
	  if (is_attr_boolean (attr->ta_value, 0))
	    { local_is_nil = 0; continue; }
	  /* error [true|false] allowed only */
	  xmlparser_logprintf (parser, XCFG_ERROR,
		     100 + strlen (attr->ta_value),
		     "xsi:nil is a boolean, [%s] value is not allowed",
		     attr->ta_value );
	  continue;
	default:
	  break;
	}
    }


  fullname = VXmlFindExpandedNameByQName (parser, name, 0);

  if (NULL != schema->sp_elems)
    {
      local_el_ptr = (xs_component_t **)id_hash_get (schema->sp_elems, (caddr_t)(&fullname));
      if (NULL != local_el_ptr) /* Local element has a top-level definition in schema... */
        {
          if (0 == parser->processor.sp_depth)
            {
              local_comp = local_el_ptr[0]; /* ... so we know default element descr */
              local_nameidx = local_comp->cm_elname_idx;	/* ... and exact \c local_nameidx */
            }
        }
      if (local_nameidx < 0)
        {
          dk_set_t *namesakes = (dk_set_t *)id_hash_get (schema->sp_all_elnames, (caddr_t)(&fullname));
          if (NULL != namesakes)
            local_nameidx = ((xs_component_t *)(namesakes[0]->data))->cm_elname_idx;
        }
    }

/* FSA processing for previous or top level and precise detection of the type */
  if (0 == parser->processor.sp_depth)
    goto end_of_fsa_for_parent; /* see below */

  if (NULL == newstate[-1].xa_type)
    {
      newstate->xa_type = NULL;
      goto end;
    }

  curidx = newstate[-1].xa_state;
  st = newstate[-1].xa_states + curidx;

  switch (curidx)
    {
    case XECM_ST_ERROR:
      goto end;		/* Error already reported, nothing to check */
    case XECM_ST_EMPTY:
      xmlparser_logprintf (parser, fsa_cfg,
	  100 + strlen (newstate[-1].xa_el->xee_component->cm_qname),
	  "Sub-elements are not allowed in element <%s> declared EMPTY",
	  newstate[-1].xa_el->xee_component->cm_qname );
      goto end;
    case XECM_ST_EMPTY_OR_PCDATA:
      xmlparser_logprintf (parser, fsa_cfg,
	100 + strlen (newstate[-1].xa_el->xee_component->cm_qname),
	"Sub-elements are not allowed in element <%s> that can contain only PCDATA",
	newstate[-1].xa_el->xee_component->cm_qname );
      goto end;
    }

  /* Support for unknown element names */
  if (XECM_EL_UNDEF == local_nameidx)
    {
      const char *colon;
      int ns_idx;
      colon = strrchr (fullname, ':');
      if (NULL == colon)
        local_nameidx = XECM_EL_ANY_LOCAL;
      else
        {
          caddr_t ns = box_dv_short_nchars (fullname, colon-fullname);
	  ns_idx = ecm_find_name (ns, schema->sp_xecm_namespaces, schema->sp_xecm_namespace_no, sizeof (char *));
	  dk_free_box (ns);
	  if (ns_idx < 0)
	    local_nameidx = XECM_EL_ANY_NOT_LISTED_NS;
	  else
	    local_nameidx = schema->sp_xecm_el_no + ns_idx;
	}
    }
  newst = xecm_get_next (st->xes_nexts, XECM_EL_OFFSET + local_nameidx);
  if (XECM_ST_ERROR == newst->xsi_idx)
    {
      char *outerqname;
      if (XS_ANY_LAX == (ptrlong)(newstate[-1].xa_type))
	goto end;
      outerqname = newstate[-1].xa_el->xee_component->cm_qname;
      xmlparser_logprintf (parser, fsa_cfg,
	100 + strlen (fullname) + strlen (outerqname),
	"Element <%s> %sdoes not match expected grammar of <%s>",
	fullname,
	((local_nameidx < 0) ? "is not listed in schema and " : ""),
	outerqname );
    }
  else
    {
    ptrlong countermode;
    if (NULL != newst->xsi_type)
      {
	newstate->xa_type = newst->xsi_type;
	local_comp = newst->xsi_type;
#ifdef DEBUG
        if ((NULL != local_comp) && (local_comp->cm_elname_idx != local_nameidx))
          GPF_T;
#endif
      }
    countermode = schema->sp_curr_config.dc_xs_counter;
    if (XCFG_DISABLE != countermode)		/* element occurence constraint checking */
      {
	xecm_st_t *nst = newstate[-1].xa_states + newst->xsi_idx;
	xecm_st_info_t *nst_info = xecm_get_next (nst->xes_nexts, XECM_EL_OFFSET + local_nameidx);
	ptrlong *count = xs_counter (newstate - 1, local_nameidx, newst->xsi_idx);
	if (newst->xsi_idx == curidx)
	  {	/* internal loop */
	    count[0]++;
	    if (nst_info->xsi_max_counters)
	      {
		if (count[0] > nst_info->xsi_max_counters)
		  {
		    xmlparser_logprintf (parser,
			countermode, 100 + strlen (fullname),
			"Element <%s> appeared %d times but [maxOccurs] allows only %d",
			fullname, count[0], nst_info->xsi_max_counters);
		  }
	      }
	  }	/* exit from previos state */
	else
	  {
	    xecm_st_info_t *st_info = xecm_get_next (nst->xes_nexts,
	    XECM_EL_OFFSET + newstate[-1].xa_prev_nameidx );
	    if (st_info->xsi_min_counters > count[0])
	      {
	    xmlparser_logprintf (parser, countermode,
		100 + strlen (fullname),
		"Element <%s> appeared only %d times whereas [minOccurs] requires at least %d",
		fullname, count[0], st_info->xsi_min_counters );
	      }
	  }
      }
  }
  newstate[-1].xa_prev_nameidx = local_nameidx;
  newstate[-1].xa_state = newst->xsi_idx;


end_of_fsa_for_parent:

  /* Report if element name is unknown */
  if (XECM_EL_UNDEF == local_nameidx)
    {
      if (0 == parser->processor.sp_depth)
	xmlparser_logprintf (parser, (fsa_cfg < XCFG_ERROR ? fsa_cfg : XCFG_ERROR), 100 + strlen (fullname),
	  "Top-level element name <%s> is not listed in schema", fullname );
      else
	xmlparser_logprintf (parser, fsa_cfg, 100 + strlen (fullname),
	  "Element name <%s> is not listed in schema", fullname );
      goto end;
    }

  if (NULL == local_comp)
    goto end;
    
  local_xecm_el = schema->sp_xecm_els + local_comp->cm_xecm_idx;
#ifdef DEBUG
  if (local_xecm_el->xee_component != local_comp)
    GPF_T;
#endif
  newstate->xa_el = local_xecm_el;
  newstate->xa_type = local_comp->cm_typename;
  curr_type_attrs = 0;
  curr_type_attrs_no = 0;

  if (xsi_local_type)
    {
      if (check_is_cast_allowed (parser, newstate->xa_type, xsi_local_type))
	{
	  if (IS_BOX_POINTER (xsi_local_type))
	    {
	      newstate->xa_states = xsi_local_type->cm_states;
	      newstate->xa_st_no = xsi_local_type->cm_state_no;
	      curr_type_attrs = INFO_CSTYPE (xsi_local_type).composed_atts;
	      curr_type_attrs_no = INFO_CSTYPE (xsi_local_type).composed_atts_no;
	    }
	  else
	    {
	      newstate->xa_state = XECM_ST_EMPTY_OR_PCDATA;
	      newstate->xa_states = 0;
	      newstate->xa_st_no = 0;
	      newstate->xa_prev_nameidx = XECM_EL_EOS;
	    }
	  newstate->xa_type = xsi_local_type;
	}
      else
	{
	  newstate->xa_el = NULL;
	  goto end;
	}
    }
  else
    {
      newstate->xa_states = local_xecm_el->xee_states;
      newstate->xa_st_no = local_xecm_el->xee_st_no;
      newstate->xa_prev_nameidx = XECM_EL_EOS;
    }

  if (NULL != newstate->xa_states)
    {
      if (local_is_nil)
	newstate->xa_state = XECM_ST_EMPTY;
      else if (XS_PCDATA_TYPECHECK == local_xecm_el->xee_pcdata_mode)
        newstate->xa_state = XECM_ST_EMPTY_OR_PCDATA;
      else
        newstate->xa_state = XECM_ST_START;
    }
    
  if (XCFG_DISABLE != parser->processor.sp_schema->sp_curr_config.dc_xs_counter)
    newstate->xa_counter_hash =
	id_hash_allocate (31, sizeof (xs_coor_t), sizeof (long),
	xs_count_hash, xs_count_hashcmp);

  /* Attribute constraints checking and enabling of sp_simpletype_value_acc */
  attr_unk_mode = schema->sp_curr_config.dc_attr_unknown;
  attr_misformat_mode = schema->sp_curr_config.dc_attr_misformat;
  attr_missing_mode = schema->sp_curr_config.dc_attr_missing;
  if (local_is_nil && !local_xecm_el->xee_is_nillable)
    xmlparser_logprintf (parser, attr_misformat_mode,
		   ECM_MESSAGE_LEN +  strlen (local_comp->cm_qname),
		   "Element <%s> is not nillable, xsi:nil=\"true\" may not occur here",
		   local_comp->cm_qname );
  if (!curr_type_attrs)
    {
      curr_type_attrs = local_xecm_el->xee_attrs;
      curr_type_attrs_no = local_xecm_el->xee_attrs_no;
    }
   
  if (XS_PCDATA_TYPECHECK == local_xecm_el->xee_pcdata_mode)
    parser->processor.sp_simpletype_depth = parser->processor.sp_depth + 1;
  if (XCFG_DISABLE == attr_unk_mode)
    goto end_attr_check;

  attr_req_no = 0;
  attr_req_hit_mask = 0;
  elem_value = 0;
  for (attr = attrdata->local_attrs; attr < attr_end; attr++)
    {
      char *attrname = attr->ta_raw_name.lm_memblock;
      int wildcard_match;
      ptrlong attridx = -1;
      if (parser->processor.sp_schema->sp_att_qualified == XS_QUAL)
	{
	  caddr_t exp_attrname = VXmlFindExpandedNameByQName (parser, attrname, 0);
	  attridx = ecm_find_name (exp_attrname,
	    curr_type_attrs, curr_type_attrs_no, sizeof (xecm_attr_t) );
	  dk_free_box (exp_attrname);
	}
      else if (parser->processor.sp_schema->sp_att_qualified == XS_UNQUAL)
	attridx = ecm_find_name (attr->ta_raw_name.lm_memblock,
	  curr_type_attrs, curr_type_attrs_no, sizeof (xecm_attr_t) );
      else
	GPF_T;
      if (-1 == attridx)
	{
	  if (('x' == attrname[0]) && ('m' == attrname[1]) && ('l' == attrname[2]))
	    continue;
	  if (xsi_schema_attr_code (parser, attrname))
	    continue;
	  if (!strcmp ("value", attrname))
	    {
    	      elem_value = attr->ta_value;
	      parser->processor.sp_simpletype_depth = 0;
	      continue;
    	    }
	  if (local_xecm_el->xee_any_attr_ns == XS_ANY_ATTR_NS_ANY)
	    wildcard_match = 1;
	  else
	  if (local_xecm_el->xee_any_attr_ns == XS_ANY_ATTR_NS_NONE)
	    wildcard_match = 0;
	  else
	    {
	      lenmem_t curr_ns, *lm_equal_tmp1, *lm_equal_tmp2;
	      char *target_ns = parser->processor.sp_schema->sp_target_ns_uri;
	      xs_any_attr_ns select_ns = local_xecm_el->xee_any_attr_ns;
	      VXmlFindNamespaceUriByQName (parser, attrname, 1, &curr_ns);
	      switch ((ptrlong)(select_ns))
		{
		      /* XS_ANY_ATTR_NS_ANY is handled before */
		case (ptrlong) XS_ANY_ATTR_NS_LOCAL:
		  wildcard_match = (NULL == strrchr (attrname, ':'));
		  break;
		case (ptrlong) XS_ANY_ATTR_NS_TARGET:
		  wildcard_match = (target_ns && (NULL != curr_ns.lm_memblock) && LM_EQUAL_TO_STR (&curr_ns, target_ns));
		  break;
		default:
		  wildcard_match = ((NULL != curr_ns.lm_memblock) && LM_EQUAL_TO_STR (&curr_ns, select_ns));
		}
	    }
	  if (wildcard_match ?
	    (XS_ANY_ATTR_ERROR_WITH_OTHER == local_xecm_el->xee_any_attribute) :
	    (XS_ANY_ATTR_ERROR == local_xecm_el->xee_any_attribute) )
	    {
	      xmlparser_logprintf (parser, attr_unk_mode,
    		ECM_MESSAGE_LEN + strlen (attrname) +
    		strlen (local_comp->cm_qname),
    		"Unexpected attribute name '%s' in element <%s>",
    		attrname, local_comp->cm_qname );
    	    }
	  continue;
	}
      if (curr_type_attrs[attridx].xa_is_prohibited)
	{
	  xmlparser_logprintf (parser, attr_misformat_mode,
    		     ECM_MESSAGE_LEN + strlen (attrname) +
    		     strlen (local_comp->cm_qname),
    		     "Attribute '%s' in element <%s> is marked as prohibited",
    		     attrname, local_comp->cm_qname );
	}

      /* check attribute type and value, report errors */
      {
        size_t len = box_length (attr->ta_value) - 1;
        unsigned char *tail = (unsigned char *) attr->ta_value;
        unsigned char *end = tail + len;
        int have_spaces = 0;
        while (tail < end)
          {
            if (!isspace ((tail++)[0]))
              continue;
            have_spaces = 1;
            break;
          }
        if (have_spaces)
          {
            lenmem_t lm;
            lm.lm_memblock = box_copy (attr->ta_value);
            lm.lm_length = len;
            normalize_value (&lm);
	    schema_check_attribute (parser, lm.lm_memblock, curr_type_attrs + attridx);
	    dk_free_box (lm.lm_memblock);
          }
        else
          schema_check_attribute (parser, attr->ta_value, curr_type_attrs + attridx);
      }
      {
	ptrlong attr_required = curr_type_attrs[attridx].xa_required;
	if ((0 != attr_required) &&
	  curr_type_attrs[attridx].xa_value_sel != XEA_FIXED)
	  {
	    attr_req_no++;
	    if (attr_required < 32)
	      attr_req_hit_mask |= (1 << attr_required);
	  }
      }
    }
  if (elem_value)
    xs_check_type_compliance (parser, local_comp->cm_typename, elem_value, 0);
  if (attr_req_no < local_xecm_el->xee_req_atts_no)
    {
      /* Before panic, let's count fixed attributes. BTW let's find first missing */
      ptrlong attridx;
      char *missing_attr_name = NULL;
      for (attridx = 0; attridx<curr_type_attrs_no; attridx++)
	{
	  ptrlong attr_required = curr_type_attrs[attridx].xa_required;
	  if (0 == attr_required)
	    continue;
	  if (curr_type_attrs[attridx].xa_value_sel == XEA_FIXED)
	    attr_req_no++;
	  else if ((NULL == missing_attr_name) && (attr_required < 32) &&
	    (0 == (attr_req_hit_mask & (1 << attr_required))) )
	    missing_attr_name = curr_type_attrs[attridx].xa_name;
	}
      if (attr_req_no < local_xecm_el->xee_req_atts_no)
	xmlparser_logprintf (parser, attr_missing_mode,
	      ECM_MESSAGE_LEN + strlen (local_comp->cm_qname) +
	      ((NULL == missing_attr_name) ? 0 : strlen (missing_attr_name)),
	      "Only %d out of %d required attributes are defined for element <%s>%s%s%s",
	      attr_req_no, local_xecm_el->xee_req_atts_no, local_comp->cm_qname,
	      ((NULL == missing_attr_name) ? "" : ", e.g. the element has no attribute '"),
	      ((NULL == missing_attr_name) ? "" : missing_attr_name),
	      ((NULL == missing_attr_name) ? "" : "'")
	      );
     }

end_attr_check: ;

end:
  if (fullname != name)
    dk_free_box ((char *) fullname);
  if (NULL != parser->slaves.start_element_handler)
    (parser->slaves.start_element_handler) (parser->slaves.user_data, name, attrdata);
  parser->processor.sp_depth += 1;
}


void
xsv_end_element_handler (vxml_parser_t * parser, const char * name)
{
  schema_processor_t *proc = &parser->processor;
  schema_parsed_t *schema = proc->sp_schema;
  ptrlong fsa_cfg = schema->sp_curr_config.dc_fsa;
#ifdef XMLSCHEMA_UNIT_DEBUG
  bobnum--;
#endif
  if ((XCFG_DISABLE != fsa_cfg)
      && (parser->validator.dv_depth <= ECM_MAX_DEPTH))
    {
      xsv_astate_t *currstate = proc->sp_stack + proc->sp_depth - 1;
      xecm_st_t *st;
      xecm_st_idx_t curidx;
/* FSA processing for current level */
      curidx = currstate->xa_state;
      st = currstate->xa_states + curidx;
      switch (curidx)
	{
	case XECM_ST_ERROR:
	  break;		/* Error already reported, nothing to check */
	case XECM_ST_EMPTY:
	  break;		/* Yes, end is only expected thing for EMPTY */
	case XECM_ST_EMPTY_OR_PCDATA:
	  break;		/* Yes, end is only expected tag for EMPTY_OR_PCDATA */
	default:
	  {
	    xecm_st_idx_t newidx =
		xecm_get_nextidx (st->xes_nexts,
		XECM_EL_OFFSET + XECM_EL_EOS);
	    if (XECM_ST_ERROR == newidx)
	      {
		const char *qname =
		    currstate->xa_el->xee_component->cm_qname;
		xmlparser_logprintf (parser, fsa_cfg,
		    100 + utf8len (qname),
		    "Ending tag is not allowed here by grammar of element <%s>", qname);
	      }
	  }
	}
      if (currstate->xa_states)
	{
	  currstate->xa_states = 0;
	  currstate->xa_st_no = 0;
	  currstate->xa_prev_nameidx = XECM_EL_EOS;
	}
      if (parser->processor.sp_depth == parser->processor.sp_simpletype_depth)
	{
	  lenmem_t *acc = &(parser->processor.sp_simpletype_value_acc);
	  if (NULL == acc->lm_memblock)
	    acc->lm_memblock = box_dv_short_string ("");
	  else
            acc->lm_memblock[acc->lm_length] = '\0';
          xs_check_type_compliance (parser, currstate->xa_el->xee_component, acc->lm_memblock, 0);
        }
    }
  proc->sp_depth -= 1;
  if (!proc->sp_depth)
    {
      if (XCFG_DISABLE != parser->validator.dv_curr_config.dc_id_dupe)
	{			/* check for unresolved IDREFS */
	  dtd_check_ids (parser);
	}
    }
  if (NULL != parser->slaves.end_element_handler)
    (parser->slaves.end_element_handler) (parser->slaves.user_data, name);
}

void
xsv_char_data_handler (vxml_parser_t * parser, const char * s, int len)
{
  ptrlong fsa_cfg = parser->processor.sp_schema->sp_curr_config.dc_fsa;
  ptrlong fsabadws_cfg = parser->processor.sp_schema->sp_curr_config.dc_fsa_bad_ws;
  if (XCFG_DISABLE == fsabadws_cfg)
    fsabadws_cfg = fsa_cfg;

  if ((XCFG_DISABLE != fsa_cfg) && (parser->processor.sp_depth < ECM_MAX_DEPTH)
      && parser->processor.sp_depth)
    {
      int wsonly = 1, ctr;
      xsv_astate_t *currstate =
	  parser->processor.sp_stack + parser->processor.sp_depth - 1;
      ecm_st_idx_t curidx;
/* FSA processing for current level */
      curidx = currstate->xa_state;
      switch (curidx)
	{
	case XECM_ST_ERROR:
	  break;		/* Error already reported, nothing to check */
	case XECM_ST_EMPTY:
	  for (ctr = len; ctr--; )
	    {
	      char c = s[ctr];
	      switch(c)
		{
		case ' ': case '\r': case '\n': case '\t':
		  continue;
		default:
		  wsonly = 0;
		}
	      break;
	    }
	  if (wsonly)
	    {
	      if (XCFG_IGNORE != fsabadws_cfg)
		xmlparser_logprintf (parser, fsa_cfg,
		    100 + strlen (currstate->xa_el->xee_component->cm_qname),
		    "Whitespace chars are not allowed in element <%s> declared EMPTY",
		    currstate->xa_el->xee_component->cm_qname );
	    }
	  else
	    xmlparser_logprintf (parser, fsa_cfg,
		100 + strlen (currstate->xa_el->xee_component->cm_qname),
		"PCDATA are not allowed in element <%s> declared EMPTY",
		currstate->xa_el->xee_component->cm_qname );
	  break;
	default:
	  {
	    xecm_st_t *st = currstate->xa_el->xee_states + curidx;
	    xecm_st_idx_t newidx;
	    switch (currstate->xa_el->xee_pcdata_mode)
	      {
	      case XS_PCDATA_PROHIBITED:
		newidx = xecm_get_nextidx (st->xes_nexts, ECM_EL_OFFSET + XECM_EL_PCDATA);
		if (XECM_ST_ERROR == newidx)
		  {
		    char *el_name = currstate->xa_el->xee_component->cm_qname;
		    for (ctr = len; ctr--; )
		      {
			char c = s[ctr];
			switch(c)
			  {
			  case ' ': case '\r': case '\n': case '\t':
			    continue;
			  default:
			    wsonly = 0;
			  }
			break;
		      }
		    if (wsonly)
		      {
			if (XCFG_IGNORE != fsabadws_cfg)
			  xmlparser_logprintf (parser, fsabadws_cfg,
				100 + utf8len (el_name),
				"Whitespace chars are not allowed here by grammar of element <%s>",
				el_name );
		      }
		    else
		      xmlparser_logprintf (parser, fsa_cfg,
			100 + utf8len (el_name),
			"PCDATA are not allowed by grammar of element <%s>",
			el_name );
		  }
		else
		  currstate->xa_state = newidx;
		break;
	      case XS_PCDATA_TYPECHECK:
		if (parser->processor.sp_depth == parser->processor.sp_simpletype_depth)
		  {
		    lenmem_t *acc = &(parser->processor.sp_simpletype_value_acc);
		    int len2 = 0x400;
		    while ((len2 <= acc->lm_length + len) && (len2 < 10000000)) len2 *= 2;
		    if (len2 >= 10000000)
		      parser->processor.sp_simpletype_depth = 0;
		    else
		      {
			if (NULL == acc->lm_memblock)
			  acc->lm_memblock = dk_alloc_box (len2, DV_STRING);
		        else if (((uint32) len2) > box_length (acc->lm_memblock))
			  {
			    caddr_t *tmp = dk_alloc_box (len2, DV_STRING);
			    memcpy (tmp, acc->lm_memblock, acc->lm_length);
			    dk_free_box (acc->lm_memblock);
			    acc->lm_memblock = (char*)tmp;
			  }
			memcpy (acc->lm_memblock + acc->lm_length, s, len);
		        acc->lm_length += len;
		      }
		  }
	      }
	  }
	}
    }
  /* finish: */
  if (NULL != parser->slaves.char_data_handler)
    (parser->slaves.char_data_handler) (parser->slaves.user_data, s, len);
}

void
VXmlSetElementSchemaHandler (vxml_parser_t * parser,
    VXmlStartElementHandler sh, VXmlEndElementHandler eh)
{
  INNER_HANDLERS->start_element_handler = xsv_start_element_handler;
  INNER_HANDLERS->end_element_handler = (VXmlEndElementHandler) xsv_end_element_handler;
  OUTER_HANDLERS->start_element_handler = sh;
  OUTER_HANDLERS->end_element_handler = eh;
}

static void
Null_XML_CharacterDataHandler (void *userData, const char * s, size_t len)
{
}

void
VXmlSetCharacterSchemaDataHandler (vxml_parser_t * parser,
    VXmlCharacterDataHandler h)
{
  if (NULL == h)
    h = Null_XML_CharacterDataHandler;
  INNER_HANDLERS->char_data_handler = (VXmlCharacterDataHandler) xsv_char_data_handler;
  OUTER_HANDLERS->char_data_handler = h;
}


/* support functions */
caddr_t
xs_concat_full_name (const char *typeprefix, const char *name)
{
  if (NULL == typeprefix)
    return box_dv_short_string (name);
  else
    {
      size_t typelen = strlen (typeprefix);
      const char *delim_offset = strrchr (name, ':');
      size_t namelen;
      char *res;
      char *res_ptr;
      if (delim_offset)
	name = delim_offset + 1;
      namelen = strlen (name);
      res_ptr = res =
	  dk_alloc_box (namelen + typelen + 3, DV_LONG_STRING);
      memcpy (res_ptr, typeprefix, typelen);
      res_ptr += typelen;
      *(res_ptr++) = '#';
      memcpy (res_ptr, name, namelen);
      *(res_ptr + namelen) = 0;
      return res;
    }
}


id_hashed_key_t
xs_count_hash (caddr_t coorp)
{
  xs_coor_t *coor = *(xs_coor_t **) coorp;
  return (id_hashed_key_t) (((coor->x * 0x101) ^ coor->y) & ID_HASHED_KEY_MASK);
}

int
xs_count_hashcmp (caddr_t coorp1, caddr_t coorp2)
{
  xs_coor_t *coor1 = *(xs_coor_t **) coorp1;
  xs_coor_t *coor2 = *(xs_coor_t **) coorp2;

  return ((coor1->x == coor2->x) && (coor1->y == coor2->y));
}


/* tests */

#if 0
static
int test_assert_1 (int res, char* file, long line)
{
  if (!res)
    printf ("test at %s:%ld FAILED\n", file, line);
  else
    printf ("test PASSED\n");
  return 1;
}

#define test_assert(res) test_assert_1 (res, __FILE__, __LINE__)

static
void
test_is_schema_location ()
{
  test_assert (is_schema_location ("xs", "xs:schemaLocation"));
  test_assert (is_schema_location (NULL , "schemaLocation"));
  test_assert (is_schema_location ("", ":schemaLocation"));

  test_assert (!is_schema_location ("xs:", "xs:schemaLocation"));
  test_assert (!is_schema_location ("xs:", "schemaLocation"));
  test_assert (!is_schema_location (NULL, "xs:schemaLocation"));
  test_assert (!is_schema_location ("", "xs:schemaLocation"));
}

void schema_fsm_test()
{
/*  test_is_schema_location ();*/
}
#endif
