/*
 *  xml_ecm.h
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

#ifndef _XML_ECM_H
#define _XML_ECM_H

#include "Dk.h"
#include "libutil.h"
#include "langfunc.h"

/* XML element-content model (ECM) processor */

extern unsigned char ecm_utf8props[0x100];
#define ECM_ISZERO	0x01
#define ECM_ISSPACE	0x02
#define ECM_ISNAME	0x04
#define ECM_ISNAMEBEGIN 0x08

/* Part 1. Data types for compiled DTD description */

/*! All element names should be enumerated: negative are special values,
0...N-1 are N known element names. */
typedef ptrlong ecm_el_idx_t;

#define ECM_EL_EOS		(-1)		/* end of sequence (a closing tag) */
#define ECM_EL_UNKNOWN		(-2)		/* unknown element */
#define ECM_EL_PCDATA		(-3)		/* non-element (#PCDATA) */
#define ECM_EL_NULL_T		(-4)		/* "null-transportation" (unconditional jump in FSA graph) */
#define ECM_EL_OFFSET		4		/* offset in arrays for known element names */
#define ECM_EL_UNDEF		(-21)
#define ECM_EL_ERROR		(-22)


/*! A basic unit of ECM description is a term. Element name and #PCDATA
are terms, repetition of term is term, select among two terms is term.
*/
struct ecm_term_s
{
  ecm_el_idx_t	et_value;			/*!< Value of type ecm_el_idx, or ECM_CHAIN or ECM_CHOICE or ECM_LOOP */
  struct ecm_term_s *	et_subterm1;		/*!< \c NULL for a leaf, or left side of ECM_TERM_CHAIN, or body of ECM_LOOP, or first case of ECM_CHOICE */
  struct ecm_term_s *	et_subterm2;		/*!< \c NULL for a leaf or ECM_LOOP, or right side of ECM_TERM_CHAIN, or second case of ECM_CHOICE */
  ptrlong		et_may_be_empty;	/*!< Flags if empty sequence may match this term, thus producing glue between start and finish states */
};

typedef struct ecm_term_s ecm_term_t;

#define ECM_TERM_CHAIN		(-31)	/*!< Sequence of two given subterms should present */
#define ECM_TERM_CHOICE		(-32)	/*!< One of two given subterms should present */
#define ECM_TERM_LOOP_ZERO	(-33)	/*!< Given subterm should be repeated zero or more times */
#define ECM_TERM_LOOP_ONE	(-34)	/*!< Given subterm should be repeated one or more times */

#define ECM_EMPTY	((ecm_term_t *)(-1))
#define ECM_ANY		((ecm_term_t *)(-2))

void ecm_term_free (ecm_term_t* term);

/*! All states should be enumerated, too. -1 is an error, 0 is initial,
-2 is a terminal, others are intermediates. */
typedef ptrlong ecm_st_idx_t;

#define ECM_ST_START	0
#define ECM_ST_UNDEF	(-41)
#define ECM_ST_ERROR	(-42)
#define ECM_ST_ANY	(-51)
#define ECM_ST_EMPTY	(-52)

/*! element state */
struct ecm_st_s
{
  ecm_st_idx_t	*es_nexts;		/*!< \c es_targets[el_idx] is a index of resulting state */
  ecm_el_idx_t	es_conflict;		/*!< Sample of element which causes jump/jump conflict */
  ptrlong	es_is_frozen;		/*!< Flags if the state should not be reused */
};

typedef struct ecm_st_s ecm_st_t;

/* Index of an attribute in the array of element's attributes */
typedef ptrlong ecm_attr_idx_t;

/*! All DTD types of attributes are enumerated */
/* Do not change order of attributes' types in this enumeration! see definition of
   index_hashed_types
*/
typedef ptrlong ecm_attr_type_t;
#define ECM_AT_CDATA		0

#define ECM_AT_ENUM_NAMES	1
#define ECM_AT_ENUM_NOTATIONS	2
#define ECM_AT_ID		3
#define ECM_AT_IDREF		4
#define ECM_AT_IDREFS		5
#define ECM_AT_ENTITY		6
#define ECM_AT_ENTITIES		7
#define ECM_AT_NMTOKEN		8
#define ECM_AT_NMTOKENS		9
#define ECM_COUNTOFATTS		10

#define ECM_MESSAGE_LEN	 512

/*! Description of an attribute */
struct ecm_attr_s
{
  char *		da_name;	/*!< Name of attribute */
  ecm_attr_type_t	da_type;	/*!< Data type for attribute's values */
  ptrlong		da_is_required;	/*!< Flags if #REQUIRED specified */
  ptrlong		da_is_implied;	/*!< Flags if #IMPLIED specified */
  ptrlong		da_is_fixed;    /*!< Flags if #FIXED specified */
  char **		da_values;	/*!< Array of \c da_values_no pointers to normalized values */
  ptrlong		da_values_no;	/*!< Number of enumerated values, default value will come first */
  union
    {
      caddr_t		boxed_value;	/*!< Pointer to memory with boxed default value, valid if (NULL == da_values) */
      ptrlong		index;		/*!< Index in da_values array, valid if (NULL == da_values) */
    } da_default;
};

typedef struct ecm_attr_s ecm_attr_t;

/*! Description of an element */
struct ecm_el_s
{
  char *		ee_name;	/*!< Name of element */
  char *		ee_grammar;	/*!< String which represents grammar of order of element's children */
  char *		ee_errmsg;	/*!< Boxed string with compilation error message or NULL */
  ecm_attr_t *		ee_attrs;	/*!< Array of definitions of element's attributes */
  ecm_attr_idx_t	ee_attrs_no;	/*!< Number of defined attributes */
  ecm_st_t *		ee_states;	/*!< Array of FSA states */
  ecm_st_idx_t		ee_state_no;	/*!< Number of FSA states */
  ecm_el_idx_t		ee_conflict;	/*!< Sample of jump/jump conflict to prove that grammar is non-LARL(1) */
  ptrlong		ee_has_id_attr;	/*!< Indicates that the element has an ID attribute */
  ecm_attr_idx_t	ee_id_attr_idx;	/*!< Index of element's ID attribute, if \c ee_has_attr is set */
  ptrlong		ee_is_empty;	/*!< Indicates that element must be empty */
  ptrlong		ee_is_any;	/*!< Indicates that element could be any */
  ptrlong		ee_has_notation; /*!< Indicates that element contains notation attribute */
  ptrlong		ee_req_no;	/*!< Number of required attributes */
  ptrlong		ee_is_defbyatt; /*!< Element is defined by attribute declaration */
};

typedef struct ecm_el_s ecm_el_t;

/*! Description of XML DTD, it should be stored as box of type DV_CUSTOM */
struct dtd_s
{
  char *		ed_puburi;	/*!< PUBLIC URI of external DTD */
  char *		ed_sysuri;	/*!< SYSTEM URI of external DTD */
  int			ed_refctr;	/*!< Reference counter */
  int			ed_is_global;	/*!< Flags if the object is global and refcounting should be mutexed */
  int			ed_is_filled;	/*!< Flags if the DTD is filled by reading DTD from an XML file so it contains some actual data */
  ecm_el_t *		ed_els;		/*!< Array of elements' descriptions */
  ecm_el_idx_t		ed_el_no;	/*!< Number of described elements (0 while DTD is not parsed) */
  ecm_attr_idx_t	ed_max_attr_no;	/*!< Maximum possible number of attributes per element */
  struct id_hash_s *	ed_notations;	/*!< Hash table of all notations' definitions */
  struct id_hash_s *	ed_params;	/*!< Hash table of all parameter-entities' definitions */
  struct id_hash_s *	ed_generics;	/*!< Hash table of all generic-entities' definitions */
/*! Length of string (w/o markup header) in XPER, -1 if empty, 0 while not calculated */
  int			ed_xper_text_length;
};

#ifndef DTD_T_DECLARED
#define DTD_T_DECLARED
typedef struct dtd_s dtd_t;
#endif

/* Macro defs and functions for handling of dtd_t in a refcountable box */
#ifdef UNIT_DEBUG
#define dtd_alloc()		(dtd_t *)(calloc (1, sizeof (dtd_t)))
#define dtd_free(dtd)		free (dtd)
#define dtd_addref(dtd,global)	(dtd->ed_refctr++)
#define dtd_release(dtd)	((--(dtd->ed_refctr) > 0) ? 0 : (dtd_free(dtd), 1))
#else
#define dtd_alloc()	(dtd_t *)(dk_alloc_box_zero (sizeof (dtd_t), DV_CUSTOM))
extern void dtd_free (dtd_t *dtd);
extern void dtd_addref (dtd_t *dtd, int make_global);
extern int dtd_release (dtd_t *dtd);
#endif

/* Part 2. Data types for validator */

/*! Maximal depth for checking. If this depth reached, either fatal error
 or error or warning will be reported, and children-order-validation
will be suspended temporary. */
#define ECM_MAX_DEPTH 1024

typedef struct dc_attr_dict_item_s
{
  caddr_t dcad_attr_name;
  VXmlAttrParser dcad_handler;
  caddr_t *dcad_elements;
  ptrlong dcad_elements_count;  
}
dc_attr_dict_item_t;


/* There's a trick with storing of dictionaries. Dictionary can be DV_CUSTOM or of fake type 0.
DV_CUSTOM if made on the fly from app-specific vector or 0 if it's a static structure that is built into the server.
Attribute and element names are not copied/freed when placed to dc_attr_dict_item_t.
*/
typedef struct dc_attr_dict_s
{
  ptrlong dcad_count;
  dc_attr_dict_item_t *dcad_items;
} dc_attr_dict_t;

/* Configuration of validator. Keep static ecm_cfgparam_t ecm_cfgparams in
sync after changes of this structure. */

struct dtd_config_s
{
  ptrlong dc_attr_completion;	/*!< If validator should complete XML document with default values of attributes. */
  ptrlong dc_attr_misformat;	/*!< Check of attributes' values for matching their format with declared types: [VC: ID] [VC: IDREF] [VC: Entity Name] [VC: Name Token] */
  ptrlong dc_attr_missing;	/*!< Check if every element contain all 'required' attributes */
  ptrlong dc_attr_unknown;	/*!< Check if every attribute is declared in DTD */
  ptrlong dc_bad_recursion;	/*!< Check if entity's replacement text references to itself */
  ptrlong dc_build_standalone;	/*!< If texts of external documents should be included instead of references to GEs */
  ptrlong dc_error_context;	/*!< If error mesages should have lines taht list context in soruce text. Should be disabled if precise byte offsets are needed. */
  ptrlong dc_fsa;		/*!< Partial children-order-validation via FSA: [VC: Element Valid] */
  ptrlong dc_fsa_bad_ws;	/*!< Check if spaces are in place where no PCDATA allowed by FSA: [VC: Element Valid] */
  ptrlong dc_fsa_sgml;		/*!< Partial check if a content model is deterministic */
  ptrlong dc_ge_redef;		/*!< Check if no one GE is defined more than once */
  ptrlong dc_ge_unknown;	/*!< Report if a generic entity is defined (an expanded). This check has no effect if BuildStandalone=DISABLE. */
  ptrlong dc_id_cache;		/*!< Build a hashtable whose keys are IDs and values are locations of identified elements */
  ptrlong dc_id_dupe;		/*!< Check that ID attribute is unique: [VC: ID] */
  ptrlong dc_idref_dangling;	/*!< Check that IDREF attribute is not dangling: [VC: IDREF] */
  ptrlong dc_include;		/*!< If validator should include referenced subdocuments. */
  ptrlong dc_max_errors;	/*!< Maximal number of errors to detect before "too many errors" fatal error */
  ptrlong dc_max_warnings;	/*!< Maximal number of warnings to detect & report before before "too many warnings" */
  ptrlong dc_names_unknown;	/*!< Check if every element name used in whole document is declared in DTD */
  ptrlong dc_names_unordered;	/*!< Check if every element name is declared before use in DTD */
  ptrlong dc_names_unresolved;	/*!< Check if every element name used in DTD is declared, maybe not before */
  ptrlong dc_ns_redef;		/*!< Check if no one namespace prefix is used for different URIs in same document */
  ptrlong dc_ns_unknown;	/*!< Check if every namespace prefix is declared before use */
  ptrlong dc_pe_redef;		/*!< Check if no one PE is defined more than once */
  ptrlong dc_signal_on_error;	/*!< Signal if an XCFG_ERROR or XCFG_FATAL is detected */
  ptrlong dc_sgml;		/*!< Check for those things which are important _solely_ for SGML-compatibility */
  ptrlong dc_too_many_warns;	/*!< Status of "too many warnings" message */
  ptrlong dc_trace_loading;	/*!< Report names of used resources for validation of non-standalone documents */
  ptrlong dc_validation;	/*!< Overall mode of validator, used to choose one of preset configurations. */
  ptrlong dc_vc_data;		/*!< Check for violations of validity constraints in data (main) part of XML. */
  ptrlong dc_vc_dtd;		/*!< Check for violations of validity constraints in DTD. */
  ptrlong dc_namespaces;	/*!< Enable / disable namespace processing -- UNUSED */
  /* schema related configuration parameters */
  ptrlong dc_xs_counter;	/*!< Element appearence counter support */
  ptrlong dc_xs_decl;		/*!< Current document is schema declaration */
  ptrlong dc_xs_namespaces;	/*!< Turn off needness of using namespace prefixes -- UNUSED */
  /* postprocessing */
  dc_attr_dict_t *dc_shadow_attr_names;	/*!< List of names of attributes that should have shadow copies (with parsed values) */
};

typedef struct dtd_config_s dtd_config_t;

/*! Description of actual state of validator at one level of nesting */
struct dtd_astate_s
{
  ecm_el_t *	da_el;		/*!< Description of current element */
  ecm_st_idx_t	da_state;	/*!< Index of current state at this level */
  ptrlong	da_sstate;	/*!< XML Schema	state */
  struct xs_tag_s*	da_tag;	/*!< Schema related data */
};

typedef struct dtd_astate_s dtd_astate_t;

struct dtd_validator_s
{
  dtd_t *	dv_dtd;				/*!< DTD of the document */
  char*     dv_root;			/*!< Root element's name for DTD to be applied */
  ptrlong	dv_depth;			/*!< Current number of not-yet-closed elements */
  dtd_astate_t	dv_stack[ECM_MAX_DEPTH];	/*!< Stack of actual states, one item per one not-yet-closed element */
  dtd_config_t	dv_init_config;			/*!< Initial configuration, as set by XML parser caller */
  dtd_config_t	dv_curr_config;			/*!< Current configuration, equal to \c dv_init_config at start and possibly changed after errors' detection */
  char *	dv_attr_uses;			/*!< Buffer for collecting counters of attributes' occurrences in current element */
};

typedef struct dtd_validator_s dtd_validator_t;

typedef struct ecm_refid_logitem_s
{
  ccaddr_t			li_filename; /* boxed string of URI */
  ptrlong			li_line_no;
} ecm_refid_logitem_t;

typedef struct ecm_id_s
{
  basket_t			id_log;
  ptrlong			id_defined;
} ecm_id_t;


/* Dictionary-in-array support */

#define ECM_MEM_NOT_FOUND   ((ptrlong ) -1)
#define ECM_MEM_UNIQ_ERROR  ((ptrlong ) -1)
/* for future... */
#define ECM_MEM_ERROR       ((ptrlong ) -2)

/* number of items in initial array */
#define ECM_MEM_PREALLOCATE_ITEMS 4

#define utf8len(zz) strlen((const char*)(zz))
#define utf8cmp(zz1,zz2) strcmp((const char*)(zz1),(const char*)(zz2))

/* Functions */

struct vxml_parser_config_s;

extern ecm_term_t *ecm_term_ctor (
  ecm_el_idx_t et_value_, ecm_term_t *et_subterm1_, ecm_term_t *et_subterm2_ );

extern ecm_term_t *ecm_term_compose (
  utf8char *ee_grammar_string, dtd_t *dv_dtd, char **errmsg);

/*! Translates term tree into graph of FSA.
\c tree contains expression for path;
\c states is a pointer to array to be edited/appended, must be pointer to NULL!;
\c state_no is a pointer to current number of items in \c states, must be pointer to zero! */
extern void ecm_term_to_fsa (
  ecm_term_t *tree, ecm_st_t **states, ptrlong *state_no,
  dtd_t *dv_dtd );

/* Compiles grammar of element with index \c el_idx, filling \c ee_states and \c ee_state_no */
extern void ecm_grammar_to_fsa (ecm_el_idx_t el_idx, dtd_t *dv_dtd);

/* Returns a box with listing of FSM states */
extern char *ecm_print_fsm (ecm_el_idx_t el_idx, dtd_t *dtd);

/*! Inserts new item into array of named objs. New item is zero-filled and only
its name is set to new_obj_name.
\return index of newly added object or -1 if name is already defined */
#ifdef MALLOC_DEBUG
extern ptrlong dbg_ecm_add_name (DBG_PARAMS const char *new_obj_name, void **objs, ptrlong *obj_no, size_t size_of_obj);
#define ecm_add_name(new_obj_name,objs,obj_no,size_of_obj) dbg_ecm_add_name(__FILE__,__LINE__,new_obj_name,objs,obj_no,size_of_obj)
#else
extern ptrlong ecm_add_name (const char *new_obj_name, void **objs, ptrlong *obj_no, size_t size_of_obj);
#endif

/*! Inserts new item into hash of named objs if it does not exist. New item is zero-filled
If this item is exist locates this one.
\return pointer to the allocated or found object */
extern caddr_t ecm_try_add_name (const char *new_obj_name, struct id_hash_s *hash, size_t size_of_obj);

/*! Deletes nth item from array of named objs.
\return 1 if deleted 0 if \c obj_idx is out of bounds */
extern int ecm_delete_nth (ptrlong obj_idx, void *objs, ptrlong *obj_no, size_t size_of_obj);

/*! Locates an existing item in array of named objs.
\return index of found object or -1 if name is already defined */
extern ptrlong ecm_find_name (const char *new_obj_name, void *objs, ptrlong obj_no, size_t size_of_obj);


/*! Replacement for 2 calls find and add,
  locates item in any case, if there is no item with such name add new one (zero filled)
  \return index of object */
extern ptrlong ecm_map_name (const char *new_obj_name, void **objs, ptrlong *obj_no, size_t size_of_obj);

/*! fuse to sorted arrays,
    \return -1 if there are two items with equal names,
    otherwise returns number of items in new array */
extern int ecm_fuse_arrays(caddr_t* target, ptrlong *target_no,
		      caddr_t branch, ptrlong branch_no, size_t size_of_obj, int copy, mem_pool_t *pool);

/*! functions for rare arrayes */
struct xecm_big_array_s;
struct xecm_big_el_s;
extern struct xecm_big_array_s* xecm_create_big_array(size_t valsz);
extern void xecm_ba_set_defval(struct xecm_big_array_s* ar, ptrlong defval);
extern struct xecm_big_el_s* xecm_ba_get_elem(struct xecm_big_array_s* array, ptrlong idx);
extern void xecm_ba_set_val(struct xecm_big_array_s* array, ptrlong idx, ptrlong val);
extern ptrlong xecm_ba_get_val(struct xecm_big_array_s* array, ptrlong idx);
extern void xecm_ba_delete(struct xecm_big_array_s* array);
extern void xecm_ba_copy(struct xecm_big_array_s* target, struct xecm_big_array_s* source);

#endif /* _XML_ECM_H */

