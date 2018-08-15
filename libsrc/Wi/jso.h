/*
 *  jso.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2018 OpenLink Software
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

#ifndef __JSO_H
#define __JSO_H
#include "Dk.h"
#include "xmltree.h"


/* Part 1. Java Script style objects with named instances and properties. */

/* A property of a class MAY, MUST or SHOULD NOT appear in declaration of instances of the class. TBD: support for it :) */
#define JSO_OPTIONAL		11	/*!< The property is fully optional */
#define JSO_OPTIONAL_MIDTREE	12	/*!< The property is fully optional; even more, it makes optional all radios */
#define JSO_INHERITABLE		13	/*!< The property is required but it can be inherited */
#define JSO_REQUIRED		14	/*!< The property is required, it should be specified directly even if can be inherited */
#define JSO_PRIVATE		15	/*!< The property is never loaded. It's used only in C code */
#define JSO_DEPRECATED		16	/*!< The property is deprecated and should not be specified at all */
#define JSO_RADIO1		21	/*!< The property belongs to a group #1 of properties such that exactly one property of the group is required and should be specified directly even if can be inherited */
#define JSO_RADIO2		22	/*!< The property is like JSO_RADIO1 but the group is #2 */
#define JSO_RADIO3		23	/*!< The property is like JSO_RADIO1 but the group is #3 */
#define JSO_RADIO4		24	/*!< The property is like JSO_RADIO1 but the group is #4 */
#define JSO_RADIO5		25	/*!< The property is like JSO_RADIO1 but the group is #5 */
#define JSO_RADIO_COUNT		5	/*!< Count of JSO_RADIO1... JSO_RADIO5 values, increment if added more */

#define JSO_ANY			"http://www.w3.org/2001/XMLSchema#any"				/*!< Arbitrary boxed SQL value */
#define JSO_ANY_array		"http://www.openlinksw.com/schemas/virtrdf#array-of-any"		/*!< A vector of arbitrary boxed SQL values */
#define JSO_ANY_URI		"http://www.w3.org/2001/XMLSchema#anyURI"			/*!< boxed DV_UNAME in UTF-8 encoding */
#define JSO_BOOLEAN		"http://www.w3.org/2001/XMLSchema#boolean"			/*!< Bool as ptrlong 1 or 0 */
#define JSO_BITMASK		"http://www.openlinksw.com/schemas/virtrdf#bitmask"		/*!< Bitmask as ptrlong, can be loaded as OR of a list of values */
#define JSO_DOUBLE		"http://www.w3.org/2001/XMLSchema#double"			/*!< Double float as unboxed double */
#define JSO_INTEGER		"http://www.w3.org/2001/XMLSchema#integer"			/*!< Integer as ptrlong */
#define JSO_INTEGER_array	"http://www.openlinksw.com/schemas/virtrdf#array-of-integer"	/*!< Either a vector of DV_LONG_INTs or DV_ARRAY_OF_LONG */
#define JSO_STRING		"http://www.w3.org/2001/XMLSchema#string"			/*!< String, boxed DV_STRING */
#define JSO_STRING_array	"http://www.openlinksw.com/schemas/virtrdf#array-of-string"	/*!< A vector of DV_STRING-s */

#define JSO_FIELD_OFFSET(dt,f) (((char *)(&(((dt *)NULL)->f)))-((char *)NULL))
#define JSO_FIELD_ACCESS(dt,inst,ofs) ((dt *)(((char *)(inst)) + (ofs)))
#define JSO_FIELD_PTR(inst,fldd) JSO_FIELD_ACCESS(caddr_t,(inst),(fldd)->jsofd_byte_offset)

/*! Description of a single field of JSO class or JSO array */
typedef struct jso_field_descr_s {
  const char *	jsofd_property_iri;	/*!< IRI for loading from RDF graphs, will be used as a predicate IRI */
  const char *	jsofd_local_name;	/*!< Name of a field in C structure, it usually matches local part of \c jsofd_property_iri */
  const char *	jsofd_type;		/*!< Datatype IRI that is either one of JSO_xxx preset type IRIs or an IRI of some JSO class */
  int		jsofd_required;		/*!< One of JSO_OPTIONAL ... JSO_DEPRECATED */
  ptrdiff_t	jsofd_byte_offset;	/*!< Byte offset of the beginning of the field from the beginning of the class instance */
  struct jso_class_descr_s *	jsofd_class;	/*!< The backlink to the class where the field is declared */
} jso_field_descr_t;

/* Category of JSO class. This implementation supports only structures with fixed list of named fields and arrays with non-negative integer indexes */
#define JSO_CAT_STRUCT	21	/*!< Class instances are strtuctures with fixed list of named fields */
#define JSO_CAT_ARRAY	22	/*!< Class instances are arrays with non-negative integer indexes */
/*#define JSO_CAT_MAP	23	*!< Class instances are sets of key-value pairs with keys and values of any types */

/*! Data specific to JSO_CAT_STRUCT classes */
typedef struct jso_struct_descr_s {
  size_t	jsosd_sizeof;			/*!< Size of an instance in bytes */
  int		jsosd_field_count;		/*!< Number of fields, including deprecated fields */
  jso_field_descr_t *	jsosd_field_list;	/*!< Array of field descriptions. The array may be longer than needed and have NULL pointers at the end */
  dk_hash_t *	jsosd_field_hash;		/*!< Hashtable to get field description by jsofd_property_iri of a field */
  jso_field_descr_t **	jsosd_fields_by_idx;	/*!< \c jsosd_fields_by_idx is array of (mostly) NULLs, jsosd_sizeof/sizeof(caddr_t) elements long. If the structure is treated as DV_ARRAY_OF_POINTER, N-th item of arrary can be a described field. In this case the description can be found as jsosd_fields_by_idx[N]. */
} jso_struct_descr_t;

/*! Data specific to JSO_CAT_ARRAY classes */
typedef struct jso_array_descr_s {
  const char *	jsoad_member_type;	/*!< Datatype IRI that is either one of JSO_xxx preset type IRIs or an IRI of some JSO class */
  int		jsoad_min_length;	/*!< Min allowed number of elements in the instance */
  int		jsoad_max_length;	/*!< Max allowed number of elements in the instance */
} jso_array_descr_t;

/*! A type for validation callback called at the end of jso_validate(). The callback can validate and optionally enrich the data.
\c warning_acc_ptr is a pointer to set of 2-element vectors, each vector is a pair of pointer to jso_rtti_t and text of warning.
\c inst_rtti is made void * because gcc 4.4.7 disliked proper typedef for proper type of pointer. */
typedef void jso_validation_cbk_t (void * /* actually jso_rtti_t * */ inst_rtti, dk_set_t *errors_log_ptr, dk_set_t *warnings_log_ptr);

/*! Description of a JSO class */
typedef struct jso_class_descr_s {
  int		jsocd_cat;		/*!< Class category as an JSO_CAT_xxx value */
  const char *	jsocd_c_typedef;	/*!< Text of C typedef (say, 'struct myexample_s') */
  const char *  jsocd_class_iri;	/*!< IRI for loading from RDF graphs, will be used as value of rdf:type property of an instance */
  const char *	jsocd_ns_uri;		/*!< Namespace URI, it will be used for fields as well */
  const char *	jsocd_local_name;	/*!< Local part of jsocd_class_iri */
  caddr_t	jsocd_rwlock_id;	/*!< the id of the icc_lock that will be locked exclusively by bif_jso_validate_and_pin() */
  jso_validation_cbk_t *jsocd_validation_cbk;
  dk_hash_t *	jsocd_pinned_rttis;	/*!< Hashtable to get jso_rtti_t of an pinned instance by instance IRI */
  dk_hash_t *	jsocd_draft_rttis;	/*!< Hashtable to get jso_rtti_t of an draft instance by instance IRI */
  struct {
    jso_struct_descr_t sd;
    jso_array_descr_t ad;
    } _;
} jso_class_descr_t;

extern jso_class_descr_t jso_cd_array_of_any;		/*!< JSO class 'array of any number of values' */
extern jso_class_descr_t jso_cd_array_of_string;	/*!< JSO class 'array of any number of strings' */

/* State of a JSO class instance. An instance is NEW when created, FAILED if filled incorrectly, LOADED if filled correctly, DELETED when it become a memory leak */
#define JSO_STATUS_NEW		31	/*!< The instance is created but jso_pin() is not called for it */
#define JSO_STATUS_LOADED	32	/*!< jso_pin() has found no errors in the content of the instance and all referred instances and has unboxed values that should be unboxed. The result is a valid C structure */
#define JSO_STATUS_FAILED	33	/*!< jso_pin() has found errors in the content of the instance, the result is an invalid structure */
#define JSO_STATUS_DELETED	34	/*!< The instance is deleted. It stays in memory because it still can have references from other places */

/*! Run-time type info about JSO instance */
typedef struct jso_rtti_s {
  void *	jrtti_self;		/*!< Pointer to the actual C structure that contains instance data */
  caddr_t	jrtti_inst_iri;		/*!< Instance IRI */
  jso_class_descr_t *	jrtti_class;	/*!< Pointer to description of the class of the instance */
  int		jrtti_status;		/*!< Status as one of JSO_STATUS_xxx values */
#ifdef DEBUG
  struct jso_rtti_s *	jrtti_loop;		/*!< Loop pointer to the RTTI itself: when debug code copies DV_OBJECT box, the pointer remains unchanged and points to the original rtti */
#endif
} jso_rtti_t;

/*! Initialization of JSO unit */
extern void jso_init (void);

/*! Declaration of an named constant that can be used later in loading values of JSO_BITMASK type */
extern void jso_define_const (const char *iri, ptrlong value);

/*! Initialization of an class description that can be used later in loading instances of that class */
extern void jso_define_class (jso_class_descr_t *jsocd);

#define JSO_GET_OK 0
#define JSO_GET_BAD_CD_IRI 1
#define JSO_GET_BAD_INSTANCE_IRI 2
#define JSO_GET_INSTANCE_CD_MISMATCH 3
#define JSO_GET_BAD_RTTI_STATUS 4

/*! The function searches for an pinned instance such that { ?jinstance rdf:type ?jclass }, always quiet */
extern int jso_get_pinned_cd_and_rtti (ccaddr_t jclass, ccaddr_t jinstance, jso_class_descr_t **cd_ptr, jso_rtti_t **inst_rtti_ptr);

/*! The function searches for an draft instance such that { ?jinstance rdf:type ?jclass }, does not signal an error if \c quiet */
extern int jso_get_draft_cd_and_rtti (ccaddr_t jclass, ccaddr_t jinstance, jso_class_descr_t **cd_ptr, jso_rtti_t **inst_rtti_ptr, int quiet);

/*! The function returns a description of member field pointed to by \c inst_member_field assuming that this is a field of instance described by \c inst_rtti and the category is JSO_CAT_STRUCT */
extern jso_field_descr_t *jso_get_fd_by_rtti_and_member (jso_rtti_t *inst_rtti, void *inst_member_field);

extern caddr_t jso_dbg_text_fd_and_member_field (jso_field_descr_t *fd, void *inst_member_field);

extern dk_hash_t *jso_consts;		/*!< All known named constants, e.g., made by jso_define_const() */
extern dk_hash_t *jso_classes;		/*!< All known JSO classes, e.g., made by jso_define_class() */
extern dk_hash_t *jso_properties;	/*!< All known property names of all JSO classes, to cross-check classes for duplicate names */
extern dk_hash_t *jso_pinned_rttis_of_names;	/*!< All pinned JSO class instances of all classes, to distinguish between missing instances and type mismatches on post-mortem debugging */
extern dk_hash_t *jso_draft_rttis_of_names;	/*!< All draft JSO class instances of all classes, to distinguish between missing instances and type mismatches */
extern dk_hash_t *jso_rttis_of_structs;	/*!< Similar to union of \c jso_pinned_rttis_of_names and \c jso_draft_rttis_of_names but keys are 'jrtti_self' structures, not instance IRIs */

/* Part 2. A small storage of triples that are not preset properties of objects. */

extern caddr_t jso_triple_add (caddr_t * qst, caddr_t jsubj, caddr_t jpred, caddr_t jobj);
extern caddr_t jso_triples_del (caddr_t * qst, caddr_t jsubj, caddr_t jpred, caddr_t jobj);
extern caddr_t *jso_triple_get_objs (caddr_t * qst, caddr_t jsubj, caddr_t jpred);
extern caddr_t *jso_triple_get_subjs (caddr_t * qst, caddr_t jpred, caddr_t jobj);

#endif
