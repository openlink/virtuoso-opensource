/*
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
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

#ifndef SCHEMA_ECM_H
#define SCHEMA_ECM_H
#include "xmlparser_impl.h"


/* forward declarations */
struct schema_processor_s;
struct xs_component_s;



/* schema FSM declarations */

typedef ptrlong xecm_st_idx_t;
typedef ptrlong xecm_el_idx_t;

typedef enum xs_any_attr_op_en
{
  XS_ANY_ATTR_ERROR = 0,	/*!< default is to report an error */
  XS_ANY_ATTR_SKIP,
  XS_ANY_ATTR_ERROR_WITH_OTHER,
  XS_ANY_ATTR_SKIP_WITH_OTHER
} XS_ANY_ATTR_OP;

typedef char * xs_any_attr_ns;

#define XS_ANY_ATTR_NS_NONE	(xs_any_attr_ns)(0)
#define XS_ANY_ATTR_NS_ANY	(xs_any_attr_ns)(1)
#define XS_ANY_ATTR_NS_OTHER	(xs_any_attr_ns)(2)	/* Attention! this is not used in data structures. */
#define XS_ANY_ATTR_NS_LOCAL	(xs_any_attr_ns)(3)
#define XS_ANY_ATTR_NS_TARGET	(xs_any_attr_ns)(4)

/*! schema element state */
struct xecm_st_info_s
{
  ecm_st_idx_t xsi_idx;
  struct xs_component_s *xsi_type;
  ptrlong xsi_min_counters;
  ptrlong xsi_max_counters;
  ptrlong xsi_occurence_num;
};
typedef struct xecm_st_info_s xecm_st_info_t;

#define XECM_STORAGE_RAW    1
#define XECM_STORAGE_RARE   2
/*  if number of elements more than XECM_STORAGE_MAXELS than
    sparse arrays are used */
#define XECM_STORAGE_MAXELS 70
typedef struct xecm_nexts_array_s
{
  ptrlong na_type_sel;		/* either raw array or big array type */
  union
  {
    xecm_st_info_t *raw;
    struct xecm_big_array_s *rare;
  }
  na_nexts;
  ptrlong na_max_idx;
}
xecm_nexts_array_t;

xecm_st_info_t *xecm_get_next (xecm_nexts_array_t * nexts, ptrlong el);
ptrlong xecm_get_nextidx (xecm_nexts_array_t * nexts, ptrlong el);

struct xecm_st_s
{
  xecm_nexts_array_t *xes_nexts;	/*!< \c xes_nexts[OFFSET+el_idx] is a index of resulting state */
  xecm_el_idx_t xes_conflict;	/*!< Sample of element which causes jump/jump conflict */
  xecm_st_idx_t xes_eqclass;	/*!< Index of equivalence class */
};
typedef struct xecm_st_s xecm_st_t;

typedef struct grp_tree_elem_s *grp_tree_t;

typedef union
{
  char *ptr;		/*!< Pointer to memory with default value (if NULL == values) */
  ptrlong index;		/*!< Index in values array */
}
ptrindex_t;

struct xecm_attr_s
{
  char *xa_name;		/*!< Name of attribute */
  union
  {
    ptrlong idx;
    struct xs_component_s *ref;
  }
  xa_type;			/*!< Data type for attribute's values */
  ptrlong xa_pr_typeidx;	/*!< base primitive type idx */
  ptrlong xa_is_implied;	/*!< Flags if use="implied" specified */
  ptrlong xa_is_prohibited;	/*!< Flags if use="prohibited" specified */
  ptrlong xa_value_sel;		/*!< Either XEA_FIXED or XEA_DEFAULT or XEA_ENUMERATION */
/*! Positive if use="required" specified, 0 if optional.
The positive value is 1-based number of attribute among all required attributes of a type if they are listed in the dictionary order.
This is used to quickly find an example of a missing required attribute. */
  ptrlong xa_required;		
  union
  {
    struct
    {
      char **values;	/*!< Array of \c da_values_no pointers to normalized values */
      ptrlong values_no;	/*!< Number of enumerated values, default value will come first */
    }
    _enumeration;
    ptrindex_t _fixed;
    ptrindex_t _default;
  }
  xa_value;
  ptrlong attr_component; /*mapping schema*/
};

typedef struct xecm_attr_s xecm_attr_t;

typedef struct xecm_el_s
{
  struct xs_component_s *xee_component;	/*!< component of element */
  struct xecm_attr_s *xee_attrs;	/*!< Descriptions of attributes */
  ptrlong xee_attrs_no;			/*!< Number of items in xee_attrs */
  ptrlong xee_req_atts_no;		/*!< number of required attributes */
  xecm_st_t *xee_states;		/*!< DTD like array of states */
  ecm_st_idx_t xee_st_no;		/*!< number of states in array */
#ifdef DEBUG  
  xecm_st_t *xee_raw_states;		/*!< DTD like array of states */
  ecm_st_idx_t xee_raw_st_no;		/*!< number of states in array */
#endif
  /* ptrlong xee_is_any; */
  /* ptrlong xee_is_empty; */
  ptrlong xee_pcdata_mode;
  XS_ANY_ATTR_OP	xee_any_attribute; /*!< indicates what to do with unknown attribute */
  xs_any_attr_ns	xee_any_attr_ns; /*!< which namespaces must be selected */
  xecm_el_idx_t xee_conflict;	/*!< HZ */
  ptrlong	xee_is_nillable;
}
xecm_el_t;

typedef struct xsv_astate_s
{
  xecm_el_t *xa_el;			/*!< Description of current element */
  struct xs_component_s * xa_type;	/*!< type, if applicable */
  xecm_st_idx_t xa_state;		/*!< Index of current state at this level */
  xecm_st_t *xa_states;			/*!< copy of element's fsm */
  xecm_el_idx_t xa_prev_nameidx;	/*!< Index of previous sibling element */
  ecm_st_idx_t xa_st_no;
  id_hash_t *xa_counter_hash;
}
xsv_astate_t;

#define XECM_TERM_CHAIN		(-31)	/*!< Sequence of two given subterms should present */
#define XECM_TERM_CHOICE	(-32)	/*!< One of two given subterms should present */
#define XECM_TERM_LOOP_ZERO	(-33)	/*!< Given subterm should be repeated zero or more times */
#define XECM_TERM_LOOP_ONE	(-34)	/*!< Given subterm should be repeated one or more times */


#define XECM_ST_START		0
#define XECM_ST_ERROR		(-42)
#define XECM_ST_EMPTY		(-52)
#define XECM_ST_EMPTY_OR_PCDATA	(-53)

#define XECM_EL_EOS		(-1)
#define XECM_EL_PCDATA		(-2)
#define XECM_EL_NULL_T		(-3)
#define XECM_EL_ANY_LOCAL	(-4)
#define XECM_EL_ANY_NOT_LISTED_NS	(-5)

#define XECM_EL_OFFSET		6
#define XECM_EL_UNDEF		(-21)
#define XECM_EL_ERROR		(-22)

#define XECM_EMPTY	((grp_tree_elem_t *)(-1))
#define XECM_ANY	((grp_tree_elem_t *)(-2))

#define GRP_TREE_IS_PREDEFINED(tree)  (!tree||tree == XECM_ANY||tree == XECM_EMPTY)


/* implementation definitions */

#define XECM_MEM_PREALLOCATE_ITEMS 16

void xecm_init_validation_vars (struct schema_processor_s *processor);
/* Adds type into internal unordered table */
ptrlong xecm_add_element (struct xs_component_s *elem, void **objs,
    ptrlong * obj_no, size_t sizeof_obj);
/* end of FSM declarations */

/* must be called at point when whole document is read */
int xecm_create_all_fsas (vxml_parser_t * parser);

/* FSM arrays manipullation functions */
struct xecm_nexts_array_s *xecm_nexts_allocate (ptrlong storage_type,
    ptrlong el_no, ptrlong defval);
void xecm_nexts_free (xecm_nexts_array_t * nexts);
ptrlong xecm_get_nextidx (xecm_nexts_array_t * nexts, ptrlong idx);
extern struct xecm_st_info_s *xecm_get_next (xecm_nexts_array_t * nexts, ptrlong idx);
extern void xecm_set_next (xecm_nexts_array_t * nexts, ptrlong idx, xecm_st_info_t * el);
extern void xecm_set_nextidx (xecm_nexts_array_t * nexts, ptrlong idx, ecm_st_idx_t elidx, struct xs_component_s *el_comp);
struct xecm_nexts_array_s *xecm_copy_nexts (struct xecm_nexts_array_s *nexts);

struct grp_tree_elem_s *
xecm_advance_tree (vxml_parser_t *parser, struct grp_tree_elem_s * node);

void xecm_nexts_free (xecm_nexts_array_t * nexts);

#endif /* #ifdef SCHEMA_ECM_H */
