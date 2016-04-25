/*
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

#include "libutil.h"
#include "map_schema.h"
#include "sqlcmps.h"

#define GRP_MAGIC   (grp_tree_elem_t*)0xcdcdcdcd

#define IS_REAL_BOX_POINTER(n) \
	((((unsigned ptrlong) (n)) < (unsigned ptrlong)XECM_ANY) && IS_BOX_POINTER (n))


/*mapping schema*/
void
xmlview_join_elt_free (xv_join_elt_t * xj)
{
  int inx;
  if (xj->xj_mp_schema)
    {
      ST * st;
      while (NULL != (st = (ST *) dk_set_pop (&xj->xj_mp_schema->xj_child_cols)))
        {
          dk_free_tree ((box_t) st);
        }
    }
/*
      DO_SET (caddr_t , xc, &xj->xj_mp_schema->xj_child_cols)
      {
        dk_free_tree ((caddr_t) xc);
      }
      END_DO_SET ();
      dk_set_free (xj->xj_mp_schema->xj_child_cols);
      xj->xj_mp_schema->xj_child_cols = NULL;
    }
*/
  DO_BOX (xj_col_t *, xc, inx, xj->xj_cols)
  {
    if (xc->xc_relationship)
      {
	xc->xc_relationship->xj_parent = NULL;
      }
  }
  END_DO_BOX;

  DO_BOX (xv_join_elt_t *, c, inx, xj->xj_children)
  {
    c->xj_parent = NULL;
    xmlview_join_elt_free (c);
  }
  END_DO_BOX;
}

void
xmlview_free (xml_view_t * xv)
{
  xmlview_join_elt_free (xv->xv_tree);
  dk_free_tree ((box_t) xv);
}


void *
dk_alloc_zero (size_t c)
{
  void * thing = dk_alloc (c);
  memset (thing, 0, c);
  return thing;
}


void
mpschema_set_view_def (char *name, caddr_t tree)
{
  caddr_t *old_tree = NULL;

  old_tree = (caddr_t *) id_hash_get (xml_global->xs_views, (caddr_t) &name);
  if (old_tree)
    {
      if (*old_tree)
        {
	  if (*old_tree == tree)
	    GPF_T;
	  dk_set_push (xml_global->xs_old_views, *old_tree);
        }
      *old_tree = tree;
    }
  else
    {
      name = box_dv_short_string (name);
      id_hash_set (xml_global->xs_views, (caddr_t) & name, (caddr_t) & tree);
    }
}


void
remove_old_xmlview ()
{
  if (xml_global->xs_old_views)
    {
      xml_view_t * xv = NULL;
      while (NULL != (xv = (xml_view_t *) dk_set_pop (xml_global->xs_old_views)))
        {
          xmlview_free ((xml_view_t *) xv);
        }
    }
}

caddr_t get_view_name (utf8char * fullname, char sign)
{
  utf8char *hit;
  while (
    ((hit = (utf8char *) strchr ((const char *) fullname, '/')) != NULL) ||
    ((hit = (utf8char *) strchr ((const char *) fullname, '\\')) != NULL) )
    fullname = hit+1;
  while ('.' == fullname[0])
    fullname++;
  if ((sign == fullname[0]) || ('\0' == fullname[0]))
    return box_dv_short_string ("_");
  if ((hit = (utf8char *) strchr ((const char *) fullname, sign)) != NULL)
    return box_dv_short_nchars ((const char *) fullname, hit - fullname);
  return box_dv_short_string ((const char *) fullname);
}

static const utf8char *
get_xml_name (const utf8char * fullname, char sign)
{
  int i, sz = (int) (strlen ((const char *) fullname));
  for (i = sz - 1; i >= 0; i--)
    {
      if (fullname[i] == sign)
	return fullname + i + 1;
    }
  return fullname;
}


#ifdef MS2003
caddr_t form_prefix (caddr_t table_name)
{
   char str[60];
   snprintf (str, sizeof (str), "t%lu", (unsigned long) table_name);
/*   sprintf(str, "t%08x", (long) table_name);*/
   return box_string(str);
}
#else
caddr_t xv_form_prefix (ptrlong serial)
{
   char str[60];
   snprintf (str, sizeof (str), "t%lu", (unsigned long) serial);
/*   sprintf(str, "t%08x", (long) table_name);*/
   return box_string(str);
}
#endif

void
set_xj_pk (xv_join_elt_t * xj) /*get primary key*/
{
  if (xj->xj_table)
    {
      dbe_table_t *tb = sch_name_to_table (wi_inst.wi_schema, xj->xj_table);
      if (!tb)
	{
	    sqlr_error ("S0002", "No table '%.300s' in create xml", xj->xj_table);
	}
      if (!xj->xj_pk)
	{
	  int fill = 0;
	  dbe_key_t *pk = tb->tb_primary_key;
	  xj->xj_pk = (caddr_t *) dk_alloc_box_zero (pk->key_n_significant * sizeof (caddr_t),
	      DV_ARRAY_OF_POINTER);
	  DO_SET (dbe_column_t *, col, &pk->key_parts)
	    {
	      xj->xj_pk[fill++] = box_dv_short_string (col->col_name);
	      if (fill >= pk->key_n_significant)
	        break;
	    }
	  END_DO_SET ();
	}
    }
}


xv_join_elt_t *
ms2xv_get_xj_by_table (xv_join_elt_t * element, char* table_name) /*get nick name of the table*/
{
  for (/* no init*/; NULL != element; element = element->xj_parent)
    {
      if ((NULL != element->xj_mp_schema) && element->xj_mp_schema->xj_is_constant)
        continue;
      if ((NULL != table_name) && (NULL != element->xj_table) && strcmp(element->xj_table, table_name))
        continue;
      break;
    }
  return element;
}


caddr_t
get_nickname (xv_join_elt_t * element, char* table_name) /*get nick name of the table*/
{
  xv_join_elt_t *xj = ms2xv_get_xj_by_table (element, table_name);
  if (NULL == xj)
    return NULL;
  return xj->xj_prefix;
}


void
extend_parent_xj_cols_by_parent_keys (xv_join_elt_t *parent_xj, caddr_t *parent_keys)
{
  int inx;
  _DO_BOX (inx, parent_keys )
  {
    xj_col_t *new_col;
    int colinx;
    caddr_t p_name = parent_keys[inx];
    DO_BOX (xj_col_t *, col, colinx, parent_xj->xj_cols)
     {
       if (ST_COLUMN (col->xc_exp, COL_DOTTED) && !strcmp (col->xc_exp->_.col_ref.name, p_name))
         {
           col->xc_usage |= XV_XC_PARENT_OF_JOIN;
           goto parent_col_found; /* see below */
         }
     }
    END_DO_BOX;
    new_col = (xj_col_t *) dk_alloc_box_zero (sizeof (xj_col_t), DV_ARRAY_OF_POINTER);
    new_col->xc_exp = (ST *) list (3, COL_DOTTED, NULL /* Not box_copy (parent_xj->xj_prefix) due to internal xmlsql errors */, box_string (p_name));
    new_col->xc_usage = XV_XC_PARENT_OF_JOIN;
    list_extend ((caddr_t *)(&(parent_xj->xj_cols)), 1, new_col);

parent_col_found: ;
  }
  END_DO_BOX;
}


void
form_element_join (xv_join_elt_t * element, xs_component_t * relationship)
{
  ST * left;
  ST * right;
  ST * bin_exp = NULL;
  ST * bin_exp_tmp;
  int inx;
  char * parent_table = relationship->cm_type.spec.mssql_rship.parent;
  char * child_table = relationship->cm_type.spec.mssql_rship.child;
  xv_join_elt_t *parent_xj = ms2xv_get_xj_by_table (element->xj_parent, parent_table);
  if (strchr(relationship->cm_longname, XS_BLANC)) /*temporarily*/
    sqlr_error ("S0002", "relationship chain '%.300s' is not supported", relationship->cm_longname);
  if (strcmp(element->xj_table, child_table))
    sqlr_error ("S0002", "relationship child table '%.300s' differs from element table '%.300s'", child_table, element->xj_table);
  extend_parent_xj_cols_by_parent_keys (parent_xj, (caddr_t *)(relationship->cm_type.spec.mssql_rship.parent_keys));
  _DO_BOX (inx, relationship->cm_type.spec.mssql_rship.child_keys )
  {
    right = (ST *) list (3, COL_DOTTED, box_copy (element->xj_prefix),
                                    box_string(relationship->cm_type.spec.mssql_rship.child_keys[inx]));
    left = (ST *) list (3, COL_DOTTED, box_copy (get_nickname (element->xj_parent, parent_table)),
                                   box_string(relationship->cm_type.spec.mssql_rship.parent_keys[inx]));
    bin_exp_tmp = (ST *) list (4, BOP_EQ, left, right, NULL);
    if (inx == 0)
      bin_exp = bin_exp_tmp;
    else
      bin_exp = (ST *) list (4, BOP_AND, bin_exp, bin_exp_tmp, NULL);
  }
  END_DO_BOX;

  element->xj_join_cond = bin_exp;
}


void
form_auto_element_join (xv_join_elt_t * element, xv_join_elt_t * child)
{
  int inx;
  ST * left;
  ST * right;
  ST * bin_exp = NULL;
  ST * bin_exp_tmp;
  extend_parent_xj_cols_by_parent_keys (element, element->xj_pk);
  _DO_BOX (inx, element->xj_pk)
  {
    left = (ST *) list (3, COL_DOTTED, box_copy (element->xj_prefix),
                                       box_string(element->xj_pk[inx]));
    right = (ST *) list (3, COL_DOTTED, box_copy (child->xj_prefix),
                                       box_string(child->xj_pk[inx]));
    bin_exp_tmp = (ST *) list (4, BOP_EQ, left, right, NULL);
    if (inx == 0)
      bin_exp = bin_exp_tmp;
    else
      bin_exp = (ST *) list (4, BOP_AND, bin_exp, bin_exp_tmp, NULL);
  }
  END_DO_BOX;
   child->xj_join_cond = bin_exp;
}


/*
caddr_t
mp_get_table_name (xs_component_t * component)
{
  dbe_table_t * table;
  caddr_t name = component->cm_type.spec.element.ann.sql_relation ? component->cm_type.spec.element.ann.sql_relation:
                 component->cm_longname;
  table = sch_name_to_table (wi_inst.wi_schema, name);
  if (table)
    return box_string (table->tb_name);
  return NULL;
}
*/

caddr_t
mp_get_table_name (caddr_t name)
{
  dbe_table_t * table = NULL;
  if (name)
    table = sch_name_to_table (wi_inst.wi_schema, name);
  if (table)
    return box_string (table->tb_name);
  if (name && !table)
     sqlr_new_error ("S0022", "SQ185", "Unknown table '%.300s' in mapping schema declaration", name);
  return NULL;
}

caddr_t
get_parent_table_name (xv_join_elt_t* element)
{
  if (element && element->xj_table)
    return element->xj_table;
  return get_parent_table_name (element->xj_parent);
}

void
form_constant_col (xv_join_elt_t* element)
{
  int inx;
  xv_join_elt_t * parent = element->xj_parent;
  caddr_t * key_elm;
  while (parent->xj_mp_schema && (parent->xj_mp_schema->xj_same_table || parent->xj_mp_schema->xj_is_constant))
    parent = parent->xj_parent;
  key_elm = parent->xj_pk;
  element->xj_mp_schema->xj_parent_cols = (ST **) dk_alloc_box_zero (sizeof (ST *) * BOX_ELEMENTS(key_elm), DV_ARRAY_OF_POINTER);

  _DO_BOX (inx, key_elm)
  {
/*    ST * column = (ST *) dk_alloc_box_zero (sizeof (xj_col_t), DV_ARRAY_OF_POINTER);*/
    ST* column = (ST *) list (3, COL_DOTTED, box_string (parent->xj_prefix), box_string (key_elm[inx]));
    element->xj_mp_schema->xj_parent_cols[inx] = column;
/*    dk_set_push(&element->xj_mp_schema->xj_parent_cols, column);*/
  }
  END_DO_BOX;
}

void
form_auxilary_condition (xv_join_elt_t * element, ST * limit_field, caddr_t limit_value)
{
   ST * left;
   ST * bin_exp;
   ST * new_join_condition;
/*   left = (ST *) list (3, COL_DOTTED, box_copy (element->xj_prefix),
                                      box_string (limit_field));
*/
   left = (ST*) (box_copy_tree((box_t) limit_field));
   bin_exp = (ST *) list (4, BOP_EQ, left, (ST*) (box_copy (limit_value)), NULL);
   if (element->xj_join_cond)
     {
       new_join_condition = (ST *) list (4, BOP_AND, element->xj_join_cond, bin_exp, NULL);
       element->xj_join_cond = new_join_condition;
     }
   else
     element->xj_join_cond = bin_exp;
}

/* create attributes of the element parameter*/
void
form_attributes (xv_join_elt_t* element, xs_component_t* component)
{
  if (!component)
    {
       sqlr_error ("S0002", "No component '%.300s' in mapping schema", element->xj_element);
    }
/*  if (element->xj_mp_schema->xj_same_table && component->cm_type.spec.cstype.composed_atts_no) / *temporarily* /
       sqlr_error ("S0002", "Subelement '%s' with attributes mapped to a column from the parent table is not supported", element->xj_element);
*/
  if (component->cm_type.spec.cstype.composed_atts_no)
    {
      ptrlong attributes_number = component->cm_type.spec.cstype.composed_atts_no;
      ptrlong idx;
      xj_col_t **new_cols = (xj_col_t **) dk_alloc_box_zero (sizeof (xj_col_t *) * attributes_number, DV_ARRAY_OF_POINTER);
      for (idx=0; idx<attributes_number; idx++)
        {
          xs_component_t * attr_component = (xs_component_t*) component->cm_type.spec.cstype.composed_atts[idx].attr_component;/*component of the attribute*/
          ST* col_ref;
          xj_col_t * attribute ;
          if (!attr_component)
            {
/*              return;*/
            }
          if (attr_component->cm_type.spec.attribute.ann.sql_field)
             col_ref = (ST *) list (3, COL_DOTTED, NULL,
               box_string (attr_component->cm_type.spec.attribute.ann.sql_field));/*column (sql) name of the attribute*/
          else col_ref = (ST *) list (3, COL_DOTTED, NULL,
               box_string (component->cm_type.spec.cstype.composed_atts[idx].xa_name));/*column (sql) name == xml name*/
          attribute = (xj_col_t *) dk_alloc_box_zero (sizeof (xj_col_t), DV_ARRAY_OF_POINTER);
          attribute->xc_exp = col_ref; /*column (sql) name of the attribute*/
          attribute->xc_usage = XV_XC_ATTRIBUTE;
          attribute->xc_xml_name = box_dv_uname_string ((caddr_t) component->cm_type.spec.cstype.composed_atts[idx].xa_name);/*xml name*/
          attribute->xc_prefix = box_copy ((caddr_t) attr_component->cm_type.spec.attribute.ann.sql_prefix); /* prefix for the attribute value*/
          if (IS_BOX_POINTER(attr_component->cm_type.spec.attribute.ann.sql_relationship)) /*IS_BOX_POINTER?????*/
            {
/*               xs_component_t * relationship = attr_component->cm_type.spec.attribute.ann.sql_relationship;*/
               xv_join_elt_t * xv = (xv_join_elt_t *) dk_alloc_box_zero (sizeof (xv_join_elt_t), DV_ARRAY_OF_POINTER);/*element for attribute join*/
               xv->xj_mp_schema = (xv_mp_schema_t *) dk_alloc_box_zero (sizeof (xv_mp_schema_t), DV_ARRAY_OF_POINTER);/**/
               xv->xj_table = box_copy ((caddr_t) attr_component->cm_type.spec.attribute.ann.sql_relation); /*table name*/
#ifdef MS2003
               xv->xj_prefix = form_prefix (xv->xj_table); /*nick name */
#else
               xv->xj_prefix = xv_form_prefix (attr_component->cm_serial); /* form_prefix (xv->xj_table);*/ /*nick name */
#endif
               xv->xj_element = box_dv_uname_string ((caddr_t) attr_component->cm_type.spec.attribute.ann.sql_field); /*column name */
               xv->xj_join_is_outer = 1;
               xv->xj_parent = element;
               set_xj_pk (xv);
               xv->xj_mp_schema->xj_minOccur = 1;
               xv->xj_mp_schema->xj_maxOccur = 1;
               xv->xj_mp_schema->xj_mapped = 1;
               form_element_join (xv, attr_component->cm_type.spec.attribute.ann.sql_relationship); /* filling xj_join_cond */
               attribute->xc_relationship = xv;
            }
          else if (element->xj_mp_schema->xj_same_table)
	    {
	      xv_join_elt_t* parent = element;
	      do
                {
		  parent = parent->xj_parent;
                  if (!parent->xj_mp_schema->xj_is_constant)
		    dk_set_push (&parent->xj_mp_schema->xj_child_cols, box_copy_tree ((box_t) col_ref));
		} while (parent->xj_mp_schema && (parent->xj_mp_schema->xj_same_table || parent->xj_mp_schema->xj_is_constant));
	    }
          new_cols[idx] = attribute;
        }
      list_nappend ((caddr_t *)(&(element->xj_cols)), (caddr_t)new_cols);
    }
}


/* create subelements of the element parameter*/
void
form_children (xv_join_elt_t* element, xs_component_t* component)
{

  if (!component || !IS_COMPLEX_TYPE(component))
    {
       sqlr_error ("S0002", "No complex type '%.300s' defined in mapping schema", element->xj_element);
    }
  if (IS_REAL_BOX_POINTER (component->cm_type.spec.cstype.group))
    {
      grp_tree_elem_t * group = component->cm_type.spec.cstype.group; /* pointer to the tree of components in a complex type */
      dk_set_t grp_ancestors = NULL;
      grp_tree_elem_t * group_cur_subtree = group;
      dk_set_t children = NULL; /* queue for the subelements*/
      int count_children = 0;
      int idx;
      for (;;)
        {
          xs_component_t *sub_component;
          char *xml_element_name;
          xv_join_elt_t *xv_child;

          if ((NULL != group_cur_subtree) && (GRP_MAGIC != group_cur_subtree))
            {
              if (IS_REAL_BOX_POINTER (group_cur_subtree->elem_content_left))
		{
		  dk_set_push (&grp_ancestors, group_cur_subtree);
		  group_cur_subtree = group_cur_subtree->elem_content_left;
		  continue;
		}
            }
          else
            {
              if (NULL == grp_ancestors)
                break;
              group_cur_subtree = (grp_tree_elem_t * ) dk_set_pop (&grp_ancestors);
            }
          if (!IS_REAL_BOX_POINTER (group_cur_subtree->elem_value))
            goto skip_subcomponent_processing; /* see below */

          sub_component = group_cur_subtree->elem_value;
          xml_element_name = (char *) get_xml_name ((const utf8char *) sub_component->cm_longname, XS_NAME_DELIMETER);
	  xv_child = (xv_join_elt_t *) dk_alloc_box_zero (sizeof (xv_join_elt_t), DV_ARRAY_OF_POINTER);/*subelement*/
          xv_child->xj_mp_schema = (xv_mp_schema_t *) dk_alloc_box_zero (sizeof (xv_mp_schema_t), DV_ARRAY_OF_POINTER);/**/
          xv_child->xj_mp_schema->xj_is_constant = sub_component->cm_type.spec.element.ann.sql_is_constant; /*constant*/;
          xv_child->xj_parent = element;
          xv_child->xj_element = box_dv_uname_string (xml_element_name); /*xml element name*/

	  if (IS_BOX_POINTER(sub_component->cm_type.spec.element.ann.sql_relationship) ||  /*if the subelement from another table*/
				xv_child->xj_mp_schema->xj_is_constant) /* if the subelement has is_constant annotation*/
            {
/* filling subelement (child)*/
              xv_child->xj_join_is_outer = 1;
	      if (!xv_child->xj_mp_schema->xj_is_constant)
                {
		  xv_child->xj_table = mp_get_table_name ((caddr_t) sub_component->cm_type.spec.element.ann.sql_relation);
		  if (xv_child->xj_table == NULL)
		    {
		      xv_child->xj_table = mp_get_table_name ((caddr_t) sub_component->cm_longname);
		      if (xv_child->xj_table == NULL)
			xv_child->xj_table = box_string (get_parent_table_name (element));
		    }
#ifdef MS2003
                  xv_child->xj_prefix = form_prefix (xv_child->xj_table); /*nick name for xj_prefix*/
#else
                  xv_child->xj_prefix = xv_form_prefix (sub_component->cm_serial); /*form_prefix (xv_child->xj_table);*/ /*nick name for xj_prefix*/
#endif
                  if (IS_BOX_POINTER(sub_component->cm_typename)) /*if subelement has attribute*/
                    form_attributes (xv_child, (xs_component_t*) sub_component->cm_typename);/* creation of the attributes*/
                  form_element_join (xv_child, sub_component->cm_type.spec.element.ann.sql_relationship); /* filling xj_join_cond */
                  set_xj_pk (xv_child);
		}
              else /* if subelement is constant*/
		{
		  xv_child->xj_table = box_copy(element->xj_table);
                  xv_child->xj_pk = (caddr_t *) box_copy_tree ((box_t) element->xj_pk);
#ifdef MS2003
                  xv_child->xj_prefix = form_prefix (xv_child->xj_table); /*nick name for xj_prefix*/
#else
                  xv_child->xj_prefix = xv_form_prefix (sub_component->cm_serial); /* form_prefix (xv_child->xj_table);*/ /*nick name for xj_prefix*/
#endif
		  form_auto_element_join (element, xv_child); /*another function must be and after its children would be created*/
                  form_constant_col (xv_child);
/*                  xv_child->xj_mp_schema->xj_parent_cols = dk_set_nreverse(xv_child->xj_mp_schema->xj_parent_cols);*/
		}

              if (IS_BOX_POINTER(sub_component->cm_typename)) /*if subelement has children*/
                form_children (xv_child, (xs_component_t*) sub_component->cm_typename);/* creation of the subelements*/
            }
          else /*if the subelement from the same table*/
            {
              ST* col_ref;
	      xv_join_elt_t* parent = xv_child;

	      xv_child->xj_table = box_copy(element->xj_table);
              xv_child->xj_pk = (caddr_t *) box_copy_tree ((box_t) element->xj_pk);
#ifdef MS2003
              xv_child->xj_prefix = form_prefix (xv_child->xj_table);
#else
              xv_child->xj_prefix = xv_form_prefix (sub_component->cm_serial); /* form_prefix (xv_child->xj_table); */
#endif

              if (sub_component->cm_type.spec.element.ann.sql_field)
                col_ref = (ST *) list (3, COL_DOTTED, NULL,
                           box_string (sub_component->cm_type.spec.element.ann.sql_field));/*column (sql) name of the subelement*/
              else col_ref = (ST *) list (3, COL_DOTTED, NULL,
                    box_string (xml_element_name));/*column (sql) name == xml name*/
              xv_child->xj_mp_schema->xj_column = col_ref;/*replace it*//*column (sql) name of the xv_child*/

              xv_child->xj_mp_schema->xj_same_table = 1;
              if (IS_BOX_POINTER(sub_component->cm_typename)) /*if subelement has attributes*/
                 form_attributes (xv_child, (xs_component_t*) sub_component->cm_typename);/* creation of the attributes*/

	      do
                {
		  parent = parent->xj_parent;
                  if (!parent->xj_mp_schema->xj_is_constant)
		    dk_set_push (&parent->xj_mp_schema->xj_child_cols, box_copy_tree ((box_t) col_ref));
		} while (parent->xj_mp_schema && (parent->xj_mp_schema->xj_same_table || parent->xj_mp_schema->xj_is_constant));
              form_constant_col (xv_child);
              if (IS_BOX_POINTER(sub_component->cm_typename)) /*if subelement has children*/
                form_children (xv_child, (xs_component_t*) sub_component->cm_typename);/* creation of the subelements*/
              form_auto_element_join (element, xv_child);
            }

          if (IS_BOX_POINTER(sub_component->cm_type.spec.element.ann.sql_limit_field))
            {
/*              ST* limit_field_ref = (ST *) list (3, COL_DOTTED, box_copy (xv_child->xj_prefix),
						 box_string (sub_component->cm_type.spec.element.ann.sql_limit_field));/  *name of the limit-field*/
              ST* col_ref;
              if (sub_component->cm_type.spec.element.ann.sql_field)
                col_ref = (ST *) list (3, COL_DOTTED, NULL,
                          box_string (sub_component->cm_type.spec.element.ann.sql_field));/*column (sql) name of the attribute*/
               else col_ref = (ST *) list (3, COL_DOTTED, NULL,
                 box_string ( xml_element_name));/*column (sql) name == xml name*/
              xv_child->xj_mp_schema->xj_column = col_ref;
              xv_child->xj_mp_schema->xj_limit_field = (ST *) list (3, COL_DOTTED, NULL,
						 box_string (sub_component->cm_type.spec.element.ann.sql_limit_field));/*name of the limit-field*/

	      xv_child->xj_mp_schema->xj_limit_value = IS_BOX_POINTER(sub_component->cm_type.spec.element.ann.sql_limit_value) ?
						   box_copy (sub_component->cm_type.spec.element.ann.sql_limit_value)
						   : NULL;
              form_auxilary_condition (xv_child, xv_child->xj_mp_schema->xj_limit_field, xv_child->xj_mp_schema->xj_limit_value);
            }


          xv_child->xj_mp_schema->xj_minOccur = 1; /*??????????????*/
          xv_child->xj_mp_schema->xj_maxOccur = 1; /*??????????????*/
          xv_child->xj_mp_schema->xj_hide_tree = sub_component->cm_type.spec.element.ann.sql_hide; /**/
          xv_child->xj_mp_schema->xj_hide = 0; /*??????????????*/
          xv_child->xj_mp_schema->xj_mapped = !(sub_component->cm_type.spec.element.ann.sql_exclude); /**/
/*              if (IS_BOX_POINTER(sub_component->cm_typename))/ *if subelement from another table*/
          dk_set_push(&children, xv_child);
          count_children++;

skip_subcomponent_processing:
          if (IS_REAL_BOX_POINTER (group_cur_subtree->elem_content_right))
            {
              group_cur_subtree = group_cur_subtree->elem_content_right;
              continue;
            }
          group_cur_subtree = NULL; /* This indicates that a subtree is completed and we have to pop from stack */
        }
      /*element->xj_children = (xv_join_elt_t **) malloc (sizeof (caddr_t) * count_children)?????*/
      element->xj_children = (xv_join_elt_t **) dk_alloc_box_zero (sizeof (xv_join_elt_t *) * count_children, DV_ARRAY_OF_POINTER);
      children = dk_set_nreverse(children);
      for (idx=0; idx < count_children; idx++)
        {
          element->xj_children[idx] = (xv_join_elt_t *) dk_set_pop(&children);
        }
      element->xj_mp_schema->xj_child_cols = dk_set_nreverse(element->xj_mp_schema->xj_child_cols);
    }
}

xml_view_t *
mapping_schema_to_xml_view (schema_parsed_t * schema)
{
   xs_component_t ** root_component = NULL;
   if (!schema->sp_first_element)
     {
	sqlr_error ("S0002", "No root element in create xml");
        return NULL;
     }
   root_component = (xs_component_t**) id_hash_get (schema->sp_hashtables[1], (caddr_t) &schema->sp_first_element);/*root_component[0] - the first component in the dictionaries*/

   if (root_component)
     {

       xs_component_t* root_cm_typename;
       xml_view_t * xml_view = (xml_view_t *) dk_alloc_box_zero (sizeof (xml_view_t), DV_ARRAY_OF_POINTER); /*it will be return*/
       xv_join_elt_t * xv = (xv_join_elt_t *) dk_alloc_box_zero (sizeof (xv_join_elt_t), DV_ARRAY_OF_POINTER); /*upper element*/
       xv_join_elt_t * xv_children = (xv_join_elt_t *) dk_alloc_box_zero (sizeof (xv_join_elt_t), DV_ARRAY_OF_POINTER);/*root element of the xml_view*/
       xv_children->xj_mp_schema = (xv_mp_schema_t *) dk_alloc_box_zero (sizeof (xv_mp_schema_t), DV_ARRAY_OF_POINTER);/**/
       xml_view->type = XML_VIEW;
       xml_view->xv_tree = xv;
       /*filling upper xv_join_elt*/
       xv->xj_join_is_outer = 1;
       xv->xj_children = (xv_join_elt_t **) dk_alloc_box_zero (sizeof (xv_join_elt_t *), DV_ARRAY_OF_POINTER);
       xv->xj_children[0] = xv_children;
       /*filling root xv_join_elt*/
/*       xv_children->xj_table = box_copy((caddr_t) root_component[0]->cm_type.spec.element.ann.sql_relation);*/
       xv_children->xj_mp_schema->xj_is_constant = root_component[0]->cm_type.spec.element.ann.sql_is_constant; /**/;
       if (!xv_children->xj_mp_schema->xj_is_constant)
         {
           xv_children->xj_table = mp_get_table_name ((caddr_t) root_component[0]->cm_type.spec.element.ann.sql_relation); /*table name of the root element*/
	   if (xv_children->xj_table == NULL)
	     xv_children->xj_table = mp_get_table_name ((caddr_t) root_component[0]->cm_longname);
         }
#ifdef MS2003
       xv_children->xj_prefix = form_prefix (xv_children->xj_table);
#else
       xv_children->xj_prefix = xv_form_prefix (root_component[0]->cm_serial); /* form_prefix (xv_children->xj_table); */
#endif
       xv_children->xj_element = box_dv_uname_string ((caddr_t) root_component[0]->cm_longname); /*element name*/
       xv_children->xj_join_is_outer = 1;
       xv_children->xj_parent = xv;
       set_xj_pk (xv_children);
       xv_children->xj_mp_schema->xj_minOccur = 1; /*??????????????*/
       xv_children->xj_mp_schema->xj_maxOccur = 1; /*??????????????*/
       xv_children->xj_mp_schema->xj_hide_tree = root_component[0]->cm_type.spec.element.ann.sql_hide; /**/
       xv_children->xj_mp_schema->xj_hide = 0; /*??????????????*/
       xv_children->xj_mp_schema->xj_mapped = !(root_component[0]->cm_type.spec.element.ann.sql_exclude); /**/
       root_cm_typename = (xs_component_t*) root_component[0]->cm_typename; /*component describing the type of the root element*/
       form_attributes (xv_children, root_cm_typename);
       form_children (xv_children, root_cm_typename);

       return xml_view;
     }

   return NULL;
}
/*end mapping schema*/

/*table creation from mapping schema*/
ccaddr_t xml_sql_type [] = {
"VARCHAR", /*""*/
"VARCHAR", /*"ENTITIES"*/
"VARCHAR", /*"ENTITY"*/
"VARCHAR", /*"ID"*/
"VARCHAR", /*"IDREF"*/
"VARCHAR", /*"IDREFS"*/
"VARCHAR", /*"NCName"*/
"VARCHAR", /*"NMTOKEN"*/
"VARCHAR", /*"NMTOKENS"*/
"VARCHAR", /*"NOTATION"*/
"VARCHAR", /*"Name"*/
"VARCHAR", /*"QName"*/
"VARCHAR", /*"anyType"*/
"VARCHAR", /*"anyURI"*/
"VARCHAR", /*"base64Binary"*/
"BINARY",  /*"binary"*/
"SMALLINT",/*"boolean"*/
"SMALLINT",/*"byte"*/
"INTEGER", /*"century"*/
"DATE",    /*"date"*/
"DATETIME",/*"dateTime"*/
"DECIMAL", /*"decimal"*/
"DOUBLE",  /*"double"*/
"VARCHAR", /*"duration"*/
"FLOAT",   /*"float"*/
"INTEGER", /*"gDay"*/
"INTEGER", /*"gMonth"*/
"INTEGER", /*"gMonthDay"*/
"INTEGER", /*"gYear"*/
"INTEGER", /*"gYearMonth"*/
"VARCHAR", /*"hexBinary"*/
"INTEGER", /*"int"*/
"INTEGER", /*"integer"*/
"VARCHAR", /*"language"*/
"VARCHAR", /*"list"*/
"INTEGER", /*"long"*/
"INTEGER", /*"month"*/
"INTEGER", /*"negativeInteger"*/
"INTEGER", /*"nonNegativeInteger"*/
"INTEGER", /*"nonPositiveInteger"*/
"VARCHAR", /*"normalizedString"*/
"DECIMAL", /*"number"*/
"INTEGER", /*"positiveInteger"*/
"VARCHAR", /*"recurringDate"*/
"VARCHAR", /*"recurringDay"*/
"VARCHAR", /*"recurringDuration"*/
"SMALLINT",/*"short"*/
"VARCHAR", /*"string"*/
"TIME",    /*"time"*/
"VARCHAR", /*"timeDuration"*/
"VARCHAR", /*"timeInstant"*/
"VARCHAR", /*"timePeriod"*/
"VARCHAR", /*"token"*/
"SMALLINT",/*"unsignedByte"*/
"INTEGER", /*"unsignedInt"*/
"INTEGER", /*"unsignedLong"*/
"INTEGER", /*"unsignedShort"*/
"VARCHAR", /*"uriReference"*/
"VARCHAR", /*"union"*/
"INTEGER"  /*"year"*/
};

/*      "CHAR";
      "NUMERIC";
      "DECIMAL";
      "INTEGER";
      "SMALLINT";
      "FLOAT";
      "REAL";
      "DOUBLE";
      "DATE";
      "TIME";
      "TIMESTAMP";
      "VARCHAR";
      "BIT";
      "LONG VARCHAR";
      "BINARY";
      "VARBINARY";
      "LONG VARBINARY";
      "BIGINT";
      "TINYINT";
      "NCHAR";
      "NVARCHAR";
      "LONG NVARCHAR";
*/

caddr_t
insert_quote (caddr_t name, client_connection_t *qi_client)
{
  char *xx = NULL;    /* strtok_r */
  size_t length1, length2, length3;
  int len = (int) strlen (name);
  char temp[MAX_QUAL_NAME_LEN];
  char res[MAX_QUAL_NAME_LEN];
  char *part1, *part2, *part3;
  memcpy (temp, name, len + 1);
  xx = &temp[0];
  part1 = part_tok (&xx);
  part2 = part_tok (&xx);
  part3 = part_tok (&xx);
  if (!part2)
    {
      part3 = part1;
      part1 = box_string (qi_client->cli_qualifier);
      part2 = box_string (qi_client->cli_user->usr_name);
    }
  else if (!part3)
    {
      part3 = part2;
      part2 = part1;
      part1 = box_string (qi_client->cli_qualifier);
    }
  length1 = strlen (part1);
  length2 = strlen (part2);
  length3 = strlen (part3);
  memcpy (res, part1, length1);
  res[length1] = '"';
  res[length1 + 1] = '.';
  res[length1 + 2] = '"';
  memcpy (res + 3 + length1 , part2, length2);
  res[length1 + length2 + 3] = '"';
  res[length1 + length2 + 4] = '.';
  res[length1 + length2 + 5] = '"';
  memcpy (res + 6 + length1 + length2 , part3, length3);
  res[length1 + length2 + length3 + 6] = '\0';

  return (box_string (res));
}


table_mapping_schema_t *
dk_alloc_table (void)
{
  NEW_VARZ(table_mapping_schema_t, table);
  return table;
}

caddr_t *
create_procedure (dk_set_t tables, client_connection_t *qi_client)
{
  caddr_t * box;/* = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * args_length, DV_ARRAY_OF_POINTER);*/
  int ifill_d = 0;
  int *fill_d = &ifill_d;
  int ifill_p = 0;
  int *fill_p = &ifill_p;
  int ifill_f = 0;
  int *fill_f = &ifill_f;
  int length_box = 0;
  dk_set_t drop_set = NULL;
  dk_set_t proc_set = NULL;
  dk_set_t fk_set = NULL;
  char drop[MAX_REMOTE_TEXT_SZ];
  char text[MAX_REMOTE_TEXT_SZ];
  char foreign_keys[MAX_REMOTE_TEXT_SZ];
  int first = 1;
  table_mapping_schema_t * table;
  while (NULL != (table = (table_mapping_schema_t *) dk_set_pop (&tables)))
    {
      caddr_t field;
      caddr_t type;
      tailprintf (drop, sizeof (drop), fill_d, "drop table \"%s\"", insert_quote (table->name, qi_client));
      dk_set_push (&drop_set, box_dv_short_string (drop));
      fill_d[0] = 0;
      length_box++;
      tailprintf (text, sizeof (text), fill_p, "create table \"%s\" (", insert_quote (table->name, qi_client));

      while (NULL != (field = (caddr_t) dk_set_pop (&(table->fields))) &&
	  NULL != (type = (caddr_t) dk_set_pop (&(table->fields_types))))
	{
          _COMMA (text, sizeof (text), fill_p, first);
	  tailprintf (text, sizeof (text), fill_p, "\n\"%s\"    %s", field, type);
	  dk_free_box (field);
	  dk_free_box (type);
	}

      if (table->keys)
	{
	  caddr_t key = (caddr_t) dk_set_pop (&(table->keys));
          tailprintf (text, sizeof (text), fill_p, ",\nPRIMARY KEY (\"%s\"", key);
	  while (NULL != (key = (caddr_t) dk_set_pop (&(table->keys))))
	    {
              tailprintf (text, sizeof (text), fill_p, ",\"%s\" ", (caddr_t) key);
	      dk_free_box (key);
	    }
          tailprintf (text, sizeof (text), fill_p, ")");
	}
      tailprintf (text, sizeof (text), fill_p, ")");
      dk_set_push (&proc_set, box_dv_short_string (text));
      fill_p[0] = 0;
      length_box++;

      if (table->foreign_keys)
	{
	  foreign_key_t* f_key;
	  while (NULL != (f_key = (foreign_key_t*) dk_set_pop (&(table->foreign_keys))))
	    {
	      tailprintf (drop, sizeof (drop), fill_d,
		"ALTER TABLE \"%s\" DROP CONSTRAINT \"%s_%s_FK\"",
		insert_quote (table->name, qi_client), table->name, f_key->ref_table);
	      dk_set_push (&drop_set, box_dv_short_string (drop));
	      fill_d[0] = 0;
	      length_box++;
	      tailprintf (foreign_keys, sizeof (foreign_keys), fill_f,
		"ALTER TABLE \"%s\" ADD CONSTRAINT \"%s_%s_FK\" FOREIGN KEY (\"%s\") REFERENCES \"%s\" (\"%s\")",
		insert_quote (table->name, qi_client), table->name, f_key->ref_table, f_key->field,
		insert_quote (f_key->ref_table, qi_client), f_key->ref_field);
	      dk_set_push (&fk_set, box_dv_short_string (foreign_keys));
	      fill_f[0] = 0;
	      length_box++;
	      dk_free_box (f_key->field);
	      dk_free_box (f_key->ref_table);
	      dk_free_box (f_key->ref_field);
              dk_free (f_key, sizeof (foreign_key_t));
	    }
	}

      first = 1;
      dk_free_box (table->name);
      dk_free (table, sizeof (table_mapping_schema_t));
    }
  if (length_box)
    {
      int idx = 0;
      caddr_t text;
      box = (caddr_t *) dk_alloc_box_zero (sizeof (caddr_t) * length_box, DV_ARRAY_OF_POINTER);
      while (NULL != (text = (caddr_t) dk_set_pop (&drop_set)))
	box[idx++] = text;
      while (NULL != (text = (caddr_t) dk_set_pop (&proc_set)))
	box[idx++] = text;
      while (NULL != (text = (caddr_t) dk_set_pop (&fk_set)))
	box[idx++] = text;
      return box;
    }
  else
    return NULL;
}

caddr_t
mp_set_table_name (caddr_t name)
{
  if (name)
    return box_string (name);
  return NULL;
}

s_node_t *
is_set_member_fkey_type (s_node_t * set, caddr_t elt, s_node_t * set_type) /*to find type of parent key*/
{
  while (set)
    {
      if (!strcmp((char*) (set->data), elt))
	return set_type;
      set = set->next;
      set_type = set_type->next;
    }
  return NULL;
}


s_node_t *
is_set_member (s_node_t * set, caddr_t elt)
{
  while (set)
    {
      if (!strcmp((char*) (set->data), elt))
	return set;
      set = set->next;
    }
  return NULL;
}


table_mapping_schema_t *
get_table (s_node_t * set, caddr_t elt)
{
  while (set)
    {
      if (!strcmp((char*)((table_mapping_schema_t *) (set->data))->name, elt))
	return (table_mapping_schema_t *) (set->data);
      set = set->next;
    }
  return NULL;
}

s_node_t *
is_set_member_table (s_node_t * set, caddr_t elt)
{
  while (set)
    {
      if (!strcmp((char*)((table_mapping_schema_t *) (set->data))->name, elt))
	return set;
      set = set->next;
    }
  return NULL;
}


void
insert_new_field (s_node_t ** set, caddr_t item, s_node_t ** set_type, const char *type)
{
  if (!is_set_member (*set, item))
    {
      dk_set_push (set, box_string (item));
      dk_set_push (set_type, box_string (type));
    }
}

void
insert_new_key (s_node_t ** set, caddr_t item)
{
  if (!is_set_member (*set, item))
    {
      dk_set_push (set, box_string (item));
    }
}

void
insert_new_table (s_node_t ** set, table_mapping_schema_t * item)
{
  if (!is_set_member_table (*set, (caddr_t) (item->name)))
    {
      s_node_t *newn = (s_node_t *) dk_alloc (sizeof (s_node_t));
      newn->next = *set;
      newn->data = item;
      *set = newn;
    }
}


s_node_t *
is_foreign_key (s_node_t * set, caddr_t child_field_name, caddr_t parent_table, caddr_t parent_field_name)
{
  while (set)
    {
      foreign_key_t * ft = (foreign_key_t *) (set->data);
      if (!strcmp(ft->field, child_field_name) && !strcmp(ft->ref_table, parent_table) && !strcmp(ft->ref_field, parent_field_name))
	return set;
      set = set->next;
    }
  return NULL;
}


void
insert_foreign_key (dk_set_t tables, caddr_t child_table, caddr_t child_field_name, caddr_t parent_table, caddr_t parent_field_name)
{
  table_mapping_schema_t * table = (table_mapping_schema_t *) get_table (tables, child_table);
  if (!is_foreign_key (table->foreign_keys, child_field_name, parent_table, parent_field_name))
    {
      foreign_key_t * ft = (foreign_key_t *) dk_alloc (sizeof (table_mapping_schema_t));
      ft->field = box_string (child_field_name);
      ft->ref_table = box_string (parent_table);
      ft->ref_field = box_string (parent_field_name);
      dk_set_push (&(table->foreign_keys), ft);
    }
}


void
fields_from_relationship (dk_set_t tables, caddr_t table_name, xs_component_t* relationship)
{
  int inx;
  char * parent_table_name = relationship->cm_type.spec.mssql_rship.parent;
  char * child_table_name = relationship->cm_type.spec.mssql_rship.child;
  table_mapping_schema_t* parent_table = (table_mapping_schema_t*) get_table (tables, parent_table_name);
  table_mapping_schema_t* child_table = (table_mapping_schema_t*) get_table (tables, child_table_name);
  if (strchr(relationship->cm_longname, XS_BLANC)) /*temporarily*/
    sqlr_error ("S0002", "relationship chain '%s' is not supported", relationship->cm_longname);
  if (strcmp(table_name, child_table_name))
    {
      sqlr_error ("S0002", "relationship child table '%s' differs from element table '%s'", child_table_name, table_name);
    }

  _DO_BOX (inx, relationship->cm_type.spec.mssql_rship.child_keys )
  {
    char * child_field_name = relationship->cm_type.spec.mssql_rship.child_keys[inx];
    char * parent_field_name = relationship->cm_type.spec.mssql_rship.parent_keys[inx];
    caddr_t c_type;
    insert_new_field (&(parent_table->fields), parent_field_name, &(parent_table->fields_types), "VARCHAR");
    c_type = (caddr_t) is_set_member_fkey_type (parent_table->fields, parent_field_name, parent_table->fields_types)->data;
    insert_new_field (&(child_table->fields), child_field_name, &(child_table->fields_types), c_type);
    insert_new_key (&(parent_table->keys), box_copy (parent_field_name));
    insert_foreign_key (tables, child_table_name, child_field_name, parent_table_name, parent_field_name);
  }
  END_DO_BOX;

}

void
attributes_analyze (dk_set_t *tables, table_mapping_schema_t* table, xs_component_t* component)
{
  if (!component)
    {
       sqlr_error ("S0002", "No component in mapping schema");
    }
  if (component->cm_type.spec.cstype.composed_atts_no)
    {
      ptrlong attributes_number = component->cm_type.spec.cstype.composed_atts_no;
      ptrlong idx;
      for (idx=0; idx<attributes_number; idx++)
        {
          xs_component_t * attr_component = (xs_component_t*) component->cm_type.spec.cstype.composed_atts[idx].attr_component;/*component of the attribute*/
          caddr_t field_name;
	  ptrlong idx_type =  unbox ((box_t) attr_component->cm_typename);

          if (!attr_component)
            {
/*              return;*/
            }
          if (attr_component->cm_type.spec.attribute.ann.sql_field)
             field_name = box_string (attr_component->cm_type.spec.attribute.ann.sql_field);/*column (sql) name of the attribute*/
          else
             field_name = box_string (component->cm_type.spec.cstype.composed_atts[idx].xa_name);/*column (sql) name == xml name*/

	  insert_new_field (&(table->fields), field_name, &(table->fields_types), xml_sql_type[idx_type]); /*column name */

          if (IS_BOX_POINTER(attr_component->cm_type.spec.attribute.ann.sql_relationship)) /*IS_BOX_POINTER?????*/
            {
	      caddr_t table_name = mp_set_table_name ((caddr_t) attr_component->cm_type.spec.attribute.ann.sql_relation);
	      if (strcmp(table->name, table_name))
		{
		  table_mapping_schema_t * curr_table = (table_mapping_schema_t * ) get_table (*tables, table_name);
		  if (NULL == curr_table)
		    {
		      curr_table = dk_alloc_table ();
		      curr_table->name = table_name;
		      insert_new_table (tables, curr_table);
		    }
		  fields_from_relationship (*tables, table_name, attr_component->cm_type.spec.attribute.ann.sql_relationship);
		  table = curr_table;
		}
            }
        }
    }
}


void
children_analyze (dk_set_t * tables, table_mapping_schema_t* table, xs_component_t* component)
{
  if (!component || !IS_COMPLEX_TYPE(component))
    {
       sqlr_error ("S0002", "No complex type  defined in mapping schema");
    }
  if (IS_REAL_BOX_POINTER(component->cm_type.spec.cstype.group))
    {
      grp_tree_elem_t * group = component->cm_type.spec.cstype.group; /* pointer to the first subelement in a complex type*/
      dk_set_t grp_ancestors = NULL;
      grp_tree_elem_t * group_cur_subtree = group;
      for (;;)
        {
          xs_component_t *sub_component;
          char *xml_element_name;
	  table_mapping_schema_t * curr_table;

          if (NULL != group_cur_subtree)
            {
              if (IS_REAL_BOX_POINTER (group_cur_subtree->elem_content_left))
		{
		  dk_set_push (&grp_ancestors, group_cur_subtree);
		  group_cur_subtree = group_cur_subtree->elem_content_left;
		  continue;
		}
            }
          else
            {
              if (NULL == grp_ancestors)
                break;
              group_cur_subtree = (grp_tree_elem_t *) dk_set_pop (&grp_ancestors);
            }
          if (!IS_REAL_BOX_POINTER (group_cur_subtree->elem_value))
            goto skip_subcomponent_processing; /* see below */

          sub_component = group->elem_value;
          xml_element_name = (char *) get_xml_name ((const utf8char *) sub_component->cm_longname, XS_NAME_DELIMETER);
	  if (sub_component->cm_type.spec.element.ann.sql_is_constant)  /*constant element*/
            {
              if (IS_BOX_POINTER(sub_component->cm_typename)) /*if subelement has children*/
                children_analyze (tables, table, (xs_component_t*) sub_component->cm_typename);/*subelements*/
	      group = group->elem_content_right; /*next subelement*/
	      continue;
            }

	  if (IS_BOX_POINTER(sub_component->cm_type.spec.element.ann.sql_relationship))  /*if the subelement from another table*/
            {
	      caddr_t table_name = mp_set_table_name ((caddr_t) sub_component->cm_type.spec.element.ann.sql_relation);
	      if (table_name == NULL)
		{
		  table_name = mp_set_table_name ((caddr_t) sub_component->cm_longname);
		  if (NULL == table_name)
		    table_name = box_string (table->name);
		}
	      if (strcmp(table->name, table_name))
		{
		  curr_table = (table_mapping_schema_t *) get_table (*tables, table_name);
		  if (curr_table == NULL)
		    {
		      curr_table = dk_alloc_table ();
		      curr_table->name = table_name;
		      insert_new_table (tables, curr_table);
		    }
		  /*fields_from_relationship (*tables, table_name, sub_component->cm_type.spec.element.ann.sql_relationship);*/
		  table = curr_table;
		}

              if (IS_BOX_POINTER(sub_component->cm_typename)) /*if subelement has attribute*/
		attributes_analyze (tables, table, (xs_component_t*) sub_component->cm_typename);
	      fields_from_relationship (*tables, table_name, sub_component->cm_type.spec.element.ann.sql_relationship);

              if (IS_BOX_POINTER(sub_component->cm_typename)) /*if subelement has children*/
		children_analyze (tables, table, (xs_component_t*) sub_component->cm_typename);
            }
          else /*if the subelement from the same table*/
            {
	      ptrlong idx_type;

              if (IS_BOX_POINTER(sub_component->cm_typename)) /*if subelement has attributes*/
		idx_type = unbox((box_t) sub_component->cm_typename->cm_typename);
	      else
		idx_type = unbox((box_t) sub_component->cm_typename);

              if (sub_component->cm_type.spec.element.ann.sql_field)
		insert_new_field (&(table->fields), sub_component->cm_type.spec.element.ann.sql_field,
				  &(table->fields_types), xml_sql_type[idx_type]);/*column (sql) name of the subelement*/
              else
		insert_new_field (&(table->fields), xml_element_name,
				 &(table->fields_types), xml_sql_type[idx_type]);/*column (sql) name == xml name*/
              if (IS_BOX_POINTER(sub_component->cm_typename)) /*if subelement has attributes*/
		attributes_analyze (tables, table, (xs_component_t*) sub_component->cm_typename);
              if (IS_BOX_POINTER(sub_component->cm_typename)) /*if subelement has children*/
		children_analyze (tables, table, (xs_component_t*) sub_component->cm_typename);
            }

          if (IS_BOX_POINTER(sub_component->cm_type.spec.element.ann.sql_limit_field))
            {
	      ptrlong idx_type = unbox ((box_t) sub_component->cm_typename);
              if (sub_component->cm_type.spec.element.ann.sql_field)
		insert_new_field (&(table->fields), sub_component->cm_type.spec.element.ann.sql_field,
				 &(table->fields_types), xml_sql_type[idx_type]);/*column (sql) name of the subelement*/
              else
		insert_new_field (&(table->fields), xml_element_name,
				 &(table->fields_types), xml_sql_type[idx_type]);/*column (sql) name == xml name*/

	      insert_new_field (&(table->fields), sub_component->cm_type.spec.element.ann.sql_limit_field,
				&(table->fields_types), "VARCHAR");/*name of the limit-field*/
            }

skip_subcomponent_processing:
          if (IS_REAL_BOX_POINTER (group_cur_subtree->elem_content_right))
            {
              group_cur_subtree = group_cur_subtree->elem_content_right;
              continue;
            }
          group_cur_subtree = NULL; /* This indicates that a subtree is completed and we have to pop from stack */
        }
    }
}


caddr_t
tables_from_mapping_schema (schema_parsed_t * schema, client_connection_t *qi_client)
{
  xs_component_t ** root_component = NULL;
  dk_set_t tables = NULL;

  if (!schema->sp_first_element)
    {
       sqlr_error ("S0002", "No root element in create xml");
    }
  root_component = (xs_component_t**) id_hash_get (schema->sp_hashtables[1], (caddr_t) &schema->sp_first_element);/*root_component[0] - the first component in the dictionaries*/

  if (root_component)
    {
      xs_component_t* root_cm_typename;
      table_mapping_schema_t * table = dk_alloc_table ();

      table->name = mp_set_table_name ((caddr_t) root_component[0]->cm_type.spec.element.ann.sql_relation); /*table name of the root element*/
      if (table->name == NULL)
	table->name = mp_set_table_name ((caddr_t) root_component[0]->cm_longname);
      root_cm_typename = (xs_component_t*) root_component[0]->cm_typename; /*component describing the type of the root element*/
      dk_set_push (&tables, table);
      attributes_analyze (&tables, table, root_cm_typename);
      children_analyze (&tables, table, root_cm_typename);
      return (caddr_t) create_procedure (tables, qi_client);
    }
  return NULL;
}

