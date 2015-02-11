/*
 *  schema.h
 *
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

#ifndef _XML_SCHEMA_H
#define _XML_SCHEMA_H

#include "schema_ecm.h"

#define XS_TRUE	"true"
#define XS_FALSE	"false"

#define SCHEMA_MAX_DEPTH 50
#define XS_FAILED (unsigned long)(-1)

/*! derivation modes */
typedef enum derivation_e
{
  XS_DER_RESTRICTION	= 0x01,
  XS_DER_EXTENSION	= 0x02,
  XS_DER_SUBSTITUTION	= 0x04, /*!< for element only */
  XS_DER_LIST		= 0x08, /*!< for simpleType final values */
  XS_DER_UNION		= 0x10 /*!< for simpleType final values */
} derivation_t;

typedef struct derivation_types_s {
  const char *	dts_name;
  derivation_t	dts_type;
} derivation_types_t;

/* derivation terms table */
extern const derivation_types_t * derivation_types;
extern const int derivation_types_no;

extern const derivation_types_t * derivation_el_types;
extern const int derivation_el_types_no;

extern const derivation_types_t * derivation_simple_types;
extern const int derivation_simple_types_no;

/*! qualification parameters declarations */
typedef enum qualification_e
{
  XS_QUAL = 0x1,
  XS_UNQUAL = 0x2
} qualification_t;

typedef struct qualified_types_s
{
  const char *		qts_name;
  qualification_t	value;
} qualified_types_t;

extern const qualified_types_t * qualified_types;
extern const int qualified_types_no;

/* should moved to another file */
#define QUAL__GET_BYNAME(name) \
	ecm_find_name (name, (void *)qualified_types, qualified_types_no, sizeof (qualified_types_t))

/*! status for schema components, see xs_component_status */
#define XS_COMPONENT	1   /*!< component must be initialized */
#define XS_REFERENCE	2   /*!< reference on the component must be created if needed */
#define XS_SKIP		0   /*!< nothing to do */

#define XSK_KEY		0   /*!< types for key component */
#define XSK_UNIQUE	1

/*! Component major identificators */
enum xs_component_type
{
  XS_COM_UNDEF = 0,	/*!< referenced but undefined	*/
  XS_COM_ELEMENT,	/*!< element			*/
  XS_COM_ATTRIBUTE,	/*!< attribute			*/
  XS_COM_SIMPLET,	/*!< simple type		*/
  XS_COM_COMPLEXT,	/*!< complex type		*/
  XS_COM_ATTRGROUP,	/*!< attribute group		*/
  XS_COM_GROUP,		/*!< model group		*/
  XS_COM_ANNOTATION,	/*!< identity constraint	*/
  XS_COM_KEY,		/*!< key, unique		*/
  XS_COM_NOTATION,	/*!< notation value		*/
  XS_COM_MSSQL_RSHIP,	/*!< MS SQL relationship	*/
  COUNTOF__XS_COM
};

/*! Titles of component major types for diagnostics purposes. */
extern const char *xs_component_type_names[COUNTOF__XS_COM];

#define IS_SCTYPE(component) ((XS_COM_SIMPLET==((component)->cm_type.t_major)) || (XS_COM_COMPLEXT==((component)->cm_type.t_major)))

/*! all tag identificators, must be filled. See xs_xsd_tags_array[] */
enum xs_tags
{
  XS_TAG_UNKNOWN = 0,		/*!< stub */
  XS_TAG_ELEMENT,		/*!< component types */
  XS_TAG_SIMPLE_TYPE,
  XS_TAG_COMPLEX_TYPE,
  XS_TAG_ATTRIBUTE,
  XS_TAG_ATTRGROUP,
  XS_TAG_ANYATTR,
  XS_TAG_ENUMERATION,		/*!< facets */
  XS_TAG_LENGTH,
  XS_TAG_MINLENGTH,
  XS_TAG_MAXLENGTH,
  XS_TAG_WHITESPACE,
  XS_TAG_MAXINCL,
  XS_TAG_MAXEXCL,
  XS_TAG_MININCL,
  XS_TAG_MINEXCL,
  XS_TAG_TOTALDIGITS,
  XS_TAG_FRACDIGITS,
  XS_TAG_REDEFINE,
  XS_TAG_RESTRICTION,		/*!< restrictions */
  XS_TAG_SEQUENCE,
  XS_TAG_CHOICE,
  XS_TAG_ALL,
  XS_TAG_GROUP,
  XS_TAG_SIMPLECONTENT,		/*!< contents */
  XS_TAG_COMLEXCONTENT,
  XS_TAG_ANNOTATION,		/*!< annotaion */
  XS_TAG_DOCUMENTATION,
  XS_TAG_UNION,
  XS_TAG_EXTENSION,
  XS_TAG_LIST,
  XS_TAG_NOTATION,
  XS_TAG_IMPORT,
  XS_TAG_INCLUDE,
  XS_TAG_ANY,
  XS_TAG_KEY,
  XS_TAG_KEYREF,
  XS_TAG_UNIQUE,
  XS_TAG_SELECTOR,
  XS_TAG_FIELD,

  XS_TAG_MSSQL_RSHIP,		/*!< component types */

  /*! stubs */
  XS_TAG_APPINFO,

  COUNTOF__XS_TAG
};


/*! XML Schema primitive types, see builtin_props */
enum xs_builtin_type_id
{
  XS_BLTIN_ANYTYPE = 0,		/*!< xs:anyType representation */
  XS_BLTIN_EMPTYTYPE,		/*!< duration */
  XS_BLTIN__PRIMITIVE,		/*!< 3.2 Primitive datatypes (generic value for a category) */
  XS_BLTIN_STRING,		/*!< 3.2.1 string */
  XS_BLTIN_BOOLEAN,		/*!< 3.2.2 boolean */
  XS_BLTIN_FLOAT,		/*!< 3.2.3 float */
  XS_BLTIN_DOUBLE,		/*!< 3.2.4 double */
  XS_BLTIN_DECIMAL,		/*!< 3.2.5 decimal */
  XS_BLTIN_TIMEDURATION,	/*!< 3.2.6 timeDuration */
  XS_BLTIN_RECCURINGDURATION,	/*!< 3.2.7 recurringDuration */
  XS_BLTIN_BINARY,		/*!< 3.2.8 binary */
  XS_BLTIN_URIREFERENCE,	/*!< 3.2.9 uriReference */
  XS_BLTIN_ID,			/*!< 3.2.10 ID */
  XS_BLTIN_IDREF,		/*!< 3.2.11 IDREF */
  XS_BLTIN_ENTITY,		/*!< 3.2.12 ENTITY */
  XS_BLTIN_NOTATION,		/*!< 3.2.13 NOTATION */
  XS_BLTIN_QNAME,		/*!< 3.2.14 QName */
  XS_BLTIN__DERIVED,		/*!< 3.3 Derived datatypes (generic value for a category) */
  XS_BLTIN_LANGUAGE,		/*!< 3.3.1 language */
  XS_BLTIN_IDREFS,		/*!< 3.3.2 IDREFS */
  XS_BLTIN_ENTITIES,		/*!< 3.3.3 ENTITIES */
  XS_BLTIN_NMTOKEN,		/*!< 3.3.4 NMTOKEN */
  XS_BLTIN_NMTOKENS,		/*!< 3.3.5 NMTOKENS */
  XS_BLTIN_NAME,		/*!< 3.3.6 Name */
  XS_BLTIN_NCNAME,		/*!< 3.3.7 NCName */
  XS_BLTIN_INTEGER,		/*!< 3.3.8 integer */
  XS_BLTIN_NONPOSITIVEINTEGER,	/*!< 3.3.9 nonPositiveInteger */
  XS_BLTIN_NEGATIVEINTEGER,	/*!< 3.3.10 negativeInteger*/
  XS_BLTIN_LONG,		/*!< 3.3.11 long */
  XS_BLTIN_INT,			/*!< 3.3.12 int */
  XS_BLTIN_SHORT,		/*!< 3.3.13 short */
  XS_BLTIN_BYTE,		/*!< 3.3.14 byte */
  XS_BLTIN_NONNEGATIVEINTEGER,	/*!< 3.3.15 nonNegativeInteger */
  XS_BLTIN_UNSIGNEDLONG,	/*!< 3.3.16 unsignedLong */
  XS_BLTIN_UNSIGNEDINT,		/*!< 3.3.17 unsignedInt */
  XS_BLTIN_UNSIGNEDSHORT,	/*!< 3.3.18 unsignedShort */
  XS_BLTIN_UNSIGNEDBYTE,	/*!< 3.3.19 unsignedByte */
  XS_BLTIN_POSITIVEINTEGER,	/*!< 3.3.20 positiveInteger */
  XS_BLTIN_TIMEINSTANT,		/*!< 3.3.21 timeInstant */
  XS_BLTIN_TIME,		/*!< 3.3.22 time */
  XS_BLTIN_TIMEPERIOD,		/*!< 3.3.23 timePeriod */
  XS_BLTIN_DATE,		/*!< 3.3.24 date */
  XS_BLTIN_MONTH,		/*!< 3.3.25 month */
  XS_BLTIN_YEAR,		/*!< 3.3.26 year */
  XS_BLTIN_CENTURY,		/*!< 3.3.27 century */
  XS_BLTIN_RECCURINGDATE,	/*!< 3.3.28 recurringDate */
  XS_BLTIN_RECCURINGDAY,	/*!< 3.3.29 recurringDay */
  XS_BLTIN__ADDITIONAL,		/*!< Datatypes from standards other than XMLSchema W3C Working Draft 07 April 2000 */
  XS_BLTIN_DATETIME,		/*!< dateTime */
  XS_BLTIN_DURATION,		/*!< duration */
  XS_BLTIN_GYEARMONTH,		/*!< gyearmonth */
  XS_BLTIN_GYEAR,		/*!< gyear */
  XS_BLTIN_GMONTHDAY,		/*!< gmonthday */
  XS_BLTIN_GDAY,		/*!< gday */
  XS_BLTIN_GMONTH,		/*!< gmonth */
  XS_BLTIN_HEXBINARY,		/*!< hexbinary */
  XS_BLTIN_BASE64BINARY,	/*!< base64binary */
  XS_BLTIN_NORMALIZEDSTRING,	/*!< normalizedString */
  XS_BLTIN_TOKEN,		/*!< token */
  XS_BLTIN_ANYURI,		/*!< anyURI */
  XS_BLTIN_LIST,		/*!< list */
  XS_BLTIN_NUMBER,		/*!< number */
  XS_BLTIN_UNION,		/*!< union */
  XS_BLTIN__UNKNOWN,		/*!< not built in type */
  COUNTOF__xs_builtin_types };


/* attribute use options */
#define XS_ATTRIBUTE_USE_OPT 0 /*!< This is a default value. */
#define XS_ATTRIBUTE_USE_PRH 1
#define XS_ATTRIBUTE_USE_REQ 2

/* attribute value selector */
#define XEA_DEFAULT 1
#define XEA_FIXED   2
#define XEA_ENUM    3


#define TAG_ST_NORMAL	0
#define TAG_ST_ERROR	1

#define XS_ROOT_TYPE_ERROR 1

#define VAL_FIXED	0
#define VAL_DEFAULT	1

#define XECM_INF_MAXOCCURS 0x1FFF

struct xs_component_s;
struct tag_attribute;

typedef struct elem_attrs_s /*!< Group tree element's info */
{
  ptrlong   ea_minoccurs;
  ptrlong   ea_maxoccurs;
  ptrlong   ea_namespaces;   /*!< still is unsupported */
} elem_attrs_t;

typedef struct grp_tree_elem_s
{
  ptrlong elem_idx;
  struct xs_component_s *elem_value;
  elem_attrs_t	elem_attrs;
  struct grp_tree_elem_s* elem_content_left;
  struct grp_tree_elem_s* elem_content_right;
  ptrlong elem_may_be_empty;	/*!< Flags if empty sequence may match this term, thus producing
					glue between start and finish states */
}
grp_tree_elem_t;

typedef struct elm_keyref_s
{
  struct xs_component_s*    kr_refer;
  caddr_t		    kr_selector;
  char**		    kr_fields;
  ptrlong		    kr_fields_no;
} elm_keyref_t;

typedef struct xs_tag_s
{
  struct xs_tag_info_s *	tag_info;	/*!< tag id */
  struct xs_tag_s *		tag_base;	/*!< could be found from parser */
  struct xs_component_s *	tag_component;	/*!< null if tag does not initialize new component */
  struct xs_component_s *	tag_component_ref;/*!< null if tag does not reference some component */
  struct xs_tag_s *		tag_basetag;	/*!< last youngest ansector tag with component */
  struct tag_attribute *	tag_attributes;	/*!< attribute list */
  lenmem_t tag_content;		/*!< content of attribute (if there are no elements) */
  basket_t tag_childs;		/*!< tag childs */
  char **tag_atts;		/*!< copy of tag attribute list */
  ptrlong tag_state;

  struct
  {
    grp_tree_elem_t *grp_tree;	/* storing attribute */
    grp_tree_elem_t *grp_tree_curr; /* helping attribute */
    elm_keyref_t    *elm_keyref;
  }
  temp;
}
xs_tag_t;

struct vxml_parser_s;
typedef void (*SMTagPreProcessContent) (struct vxml_parser_s * parser,
    xs_tag_t * _this);
typedef void (*SMTagProcessContent) (struct vxml_parser_s * parser,
    xs_tag_t * _this);

extern SMTagPreProcessContent xs_tag_preprocess_table[COUNTOF__XS_TAG];	/*!< pre processing of tag table , called at start tag */
extern SMTagProcessContent xs_tag_process_table[COUNTOF__XS_TAG];	/*!< processing of tag table, called at end tag */

extern struct xs_tag_meta_table_s
{
  enum xs_tags id;
  SMTagPreProcessContent start_handler;
  SMTagProcessContent end_handler;
  ptrlong facetid;		/*!< see facet_* defines */
}
xs_tag_meta_table[COUNTOF__XS_TAG];

typedef struct xs_facet_s
{
  ptrlong fc_type;		/*!< type of restriction */
  char *fc_value;		/*!< boxed value of restriction */
}
xs_facet_t;

#if 0
typedef struct xs_attribute_s
{
  char *at_name;		/*!< boxed name of attribute */
  ptrlong at_type;		/*!< type of attribute (either pointer to xs_component_t or id of builtin type */
}
xs_attribute_t;
#endif

typedef struct xs_lg_item_s
{
  xml_pos_t lg_pos;
  void *lg_item;		/*!< could be xs_facet_t, xs_attribute_t (?), xs_en_t */
}
xs_lg_item_t;

typedef struct xs_any_attribute_s
{
  ptrlong aa_anyattribute;  /*!< is anyAttribute is set */
  ptrlong aa_namespace;	    /*!< default='##any' */
  ptrlong aa_pcontent;	    /*!< (skip | lax | strict) default='strict' */
} xs_any_attribute_t;

#define XS_MSSQL_ENCODE_DEFAULT 1	/*!< The database value of type LONG VARBINARY is printed as base-64. */
#define XS_MSSQL_ENCODE_URL 2		/*!< The URL is printed that will refer to the LONG VARBINARY database value. */

#define XS_MSSQL_IDENTITY_IGNORE 1	/*!< Directs the updategram to ignore any value that is provided in the updategram for that column and to rely on SQL Server to generate the identity value. */
#define XS_MSSQL_IDENTITY_USEVALUE 2	/*!< Directs the updategram to use the value that is provided in the updategram to update the IDENTITY-type  column. An updategram does not check whether the column is an identity value or not. */

#define XS_MSSQL_GUID_USEVALUE 1	/*!< Specifies that the value that is specified in the updategram be used for the column. This is the default value. */
#define XS_MSSQL_GUID_GENERATE 2	/*!< Specifies that the GUID that is generated by SQL Server be used for that column in the update operation. */

typedef struct xs_ids_s
{
  char **	ids_array;
  int		ids_count;
} xs_ids_t;

typedef struct xs_mssql_ann_s
{
  char *	sql_relation;		/*!< Maps an XML item to a database table. */
  char *	sql_field;		/*!< Maps an XML item to a database column. */
  int		sql_is_constant;	/*!< Creates an XML element that does not map to any table. The element appears in the query output. */
  int		sql_exclude;		/*!< Allows schema items to be excluded (not mapped) from the result when set to nonzero; default is zero to leave mapped. Note that sql:mapped attribute has opposite meaning! */
  struct xs_component_s * sql_relationship;	/*!< Specifies relationships between XML elements. The parent, child, parent-key, and child-key attributes are used to establish the relationship. */
  char *	sql_limit_field;	/*!< Allows limiting the values that are returned on the basis of a limiting field. */
  char *	sql_limit_value;	/*!< The required value of the field specified by sql_limit_field. */
  xs_ids_t	sql_key_fields;		/*!< Allows specification of column(s) that uniquely identify the rows in a table. */
  char *	sql_prefix;		/*!< Creates valid XML ID, IDREF, and IDREFS. Prepends the values of ID,IDREF, and IDREFS with a string. */
  int		sql_use_cdata;		/*!< Allows specifying CDATA sections to be used for certain elements in the XML document. */
  int		sql_encode;		/*!< When an XML element or attribute is mapped to a SQL Server BLOB column, allows requesting a URIto be returned that can be used later to return BLOB data. */
  char *	sql_overflow_field;	/*!< Identifies the database column that contains the overflow data. */
  int		sql_inverse;		/*!< Instructs the updategram logic to inverse its interpretation of the parent-child relationship that has been specified using <sql:relationship>. */
  int		sql_hide;		/*!< Hides the element (and its children) or attribute that is specified in the schema in the resulting XML document. */
  int		sql_identity;		/*!< Can be specified on any node that maps to an IDENTITY-type database column. The value specified for this annotation defines how the corresponding IDENTITY-type column in the database is updated. */
  int		sql_guid;		/*!< Allows you to specify whether to use a GUID value generated by SQL Server or use the value provided in the updategram for that column. */
  int		sql_max_depth;		/*!< Allows you to specify depth in recursive relationships that are specified in the schema. */
} xs_mssql_ann_t;

#define XS_PCDATA_ALLOWED	 0x01	/*!< component can contain pcdata (e.g. simple type or a mixed content) */
#define XS_PCDATA_PROHIBITED	 0x02	/*!< component can not contain pcdata due to an explicit mixed="false" */
#define XS_PCDATA_TYPECHECK	 0x11	/*!< component can contain pcdata and they should be validated; empty element should be validated as an empty string. */

/*! general type identification */
typedef struct xs_type_s
{
  enum xs_component_type t_major;	/*!< major number(class) for this type */
  union
  {
    struct
    {
      /*ptrlong complex_type;	/ *!< non zero for complex type */
      ptrlong complex_content;	/*!< non zero for complext type with complex content */
      dk_set_t en;		/*!< enumerations */
      dk_set_t facets;		/*!< facets, xs_facet_t */
      /* dk_set_t attributes;	/ *!< attribute list, see xs_attribute_t  */
      caddr_t info;		/*!< primitive type specific info */

      ptrlong pcdata_mode;	/*!< 0 (senseless default) or XS_PCDATA_xxx */
      derivation_t final;	/*!< final. see PRIMER, section 4.8 */
      derivation_t block;	/*!< block. see PRIMER, section 4.8 */

      ptrlong value_type;	/*!< type of value */
      caddr_t value;	/*!< fixed or default value */
      /* dk_set_t lg_facets;	/ *!< temporary store for deffered writing, see xs_lg_item_t */
      /* dk_set_t lg_attributes;	/ *!< see above */
      /* dk_set_t lg_en;		/ *!< see above */
      grp_tree_elem_t* lg_group;/*!< model group components tree */
      grp_tree_elem_t* group;	/*!< composed group */

      dk_set_t lg_agroup;	/*!< attribute and attribute group list */
      struct xecm_attr_s* composed_atts;	/*!< composed attributes */
      ptrlong composed_atts_no;		/*!< number of composed attributes */
      ptrlong req_atts_no;	/*!< number of required attributes */
    }
    cstype;
    struct
    {
      dk_set_t keyrefs;		/*!< list of key refs, type: elm_keyref_t */
      xs_mssql_ann_t ann;	/*!< MsSQL annotations */
      ptrlong is_nillable;
      derivation_t block;	/*!< block attribute holder */
    }
    element;
    struct
    {
      ptrlong use; /*!< see XS_ATTRIBUTE_USE_... */
      char* fixval; /*!< boxed fixed value */
      xs_mssql_ann_t ann;	/*!< MsSQL annotations */
    }
    attribute;
    struct
    {
      dk_set_t lg_agroup;		/*!< set of xs_component_t*'s reptresenting attributes; */
      struct xecm_attr_s*	composed_atts;
      ptrlong	composed_atts_no;
    }
    attrgroup;
    struct
    {
      grp_tree_elem_t*  grp_tree;
    }
    group;
    struct
    {
      ptrlong   keytype;	/*!< either KEY or UNIQUE */
      char*	xpath_selector;
      char**	xpath_fields;	/*!< sorted array of fields */
      ptrlong	xpath_fields_no;
    }
    key;
    struct
    {
      char*	pub_uri;
      char*	sys_uri;
    }
    notation;
    struct
    {
      char*		parent;
      char**	parent_keys;
      char*		child;
      char**	child_keys;
    }
    mssql_rship;
  }
  spec;				/*!< type specific info */
  /* common part for AGROUP and CSTYPE */
  XS_ANY_ATTR_OP	any_attribute;
  xs_any_attr_ns	any_attr_ns;
}
xs_type_t;

struct xs_component_s;

#define XS_DEF_UNKNOWN		0
#define XS_DEF_REFERENCED	1
#define XS_DEF_DEFINED		2

#define XS_MAX_VERSION_NUM	999
#define XS_VERSION_DIGITS	3

#define XS_REDEF_NONE		0
#define XS_REDEF_ERROR		1
#define XS_REDEF_SYSDEF		2

/*! see XML Schema Formal Description */
typedef struct xs_component_s
{
  char  *cm_longname;	/*!< fully expanded name of component, including type name */
  char  *cm_elname;	/*!< fully expanded name of component as can appear in XML */
  char  *cm_qname;		/*!< normalized name of component as it appears in the text, for error reporting only! */
  xs_type_t cm_type;		/*!< type of component */
  /* struct xs_element_s *cm_base;	/ *!< pointer to base from which this component is derived */
  ptrlong cm_derivation;	/*!< accepted derivation: either XS_DER_EXTENSION or XS_DER_RESTRICTION */
  ptrlong cm_refinement;	/*!< accepted refinements: combination of XS_DER_RESTRICTION and XS_DER_EXTENSION */
  ptrlong cm_abstract;		/*!< indicates that component as abstract, either 0 or 1 */
  ptrlong cm_serial;		/*!< an unique id of the component in the schema. */

  ptrlong cm_deflevel;		/*!< level of definition, see XS_DEF_... */
  ptrlong cm_redef_error;	/*!< current redefinition error code, see XS_REDEF_ */
  xs_tag_t* cm_tag;		/*!< corresponding tag representation */
  xml_pos_t cm_reference;
  xml_pos_t cm_definition;

  struct xs_component_s * cm_typename;	/*!< type for elements and attributes, base type for complex and simple types */
  char* cm_defval;		/*!< boxed default value for attributes and elements */

  ptrlong cm_elname_idx;	/*!< index that is reserved for \c cm_elname for events */
  ptrlong cm_xecm_idx;		/*!< index in processor->schema_xecm_els */
  struct xecm_st_s* cm_states;	/*!< Array of FSA states */
  ptrlong cm_state_no;		/*!< Number of elements in \c cm_states */
#ifdef DEBUG
  struct xecm_st_s* cm_raw_states;
  ptrlong cm_raw_state_no;
#endif  
  ptrlong cm_conflict;
  dk_set_t cm_subst_group;	/*!< Elements that refers to this one in their 'substitutionGroup' attributes */

  ptrlong   cm_version;		/*!< number for version, if component is redefined, new component is created
				with name old_name + "$ver" + cm_version and version is increased */
  struct xs_component_s* cm_next_version; /*!< component which has more recent version */
}
xs_component_t;

typedef struct dtd_config_s xs_config_t; /* DTD ecm is used */

enum xs_sp_hash_id_t {
  XS_SP_TYPES = 0,	/*!< types */
  XS_SP_ELEMS,		/*!< elements */
  XS_SP_ATTRS,		/*!< attributes */
  XS_SP_ATTRGRPS,	/*!< attribute groups */
  XS_SP_GROUPS,		/*!< model groups */
  XS_SP_ANNOTS,		/*!< all annotations */
  XS_SP_KEYS,		/*!< hash for keys, uniques */
  XS_SP_NOTATIONS,	/*!< hash for notations */
  XS_SP_MSSQL_RSHIPS,	/*!< MS SQL relationships */
  XS_SP_ALL_ELNAMES,	/*!< Distinct elements, grouped in chains by equality of expanded XML name, including elements that have no top-level components but have one or more use inside types */
  COUNTOF__XS_SP_HASH
};

#ifdef DEBUG
#define XML_MAX_DEBUG_DICT 64
typedef xs_component_t *xs_debug_dict_t[XML_MAX_DEBUG_DICT];
#endif

typedef struct schema_parsed_s
{
  char*		sp_target_ns_uri;	/*!< target namspace URI */
  xs_config_t		sp_init_config;	/*!< initial processor configuration */
  xs_config_t		sp_curr_config;	/*!< processor configuration that is currently active */
  derivation_t		sp_final_default;	/*!< finalDefault holder */
  derivation_t		sp_block_default;	/*!< blockDefault holder */
  qualification_t	sp_el_qualified;	/*!< elementFormDefault holder */
  qualification_t	sp_att_qualified;	/*!< attributeFormDefault holder */

  struct id_hash_s *sp_hashtables[COUNTOF__XS_SP_HASH];
#ifdef DEBUG
  xs_component_t *sp_debug_dict[XML_MAX_DEBUG_DICT];
  ptrlong sp_debug_dict_size;
#endif
  ptrlong sp_type_counter;
  ptrlong sp_is_internal;	/*!< set if processor is invoked from load_external_schema */
  ptrlong sp_redefine_mode;	/*!< true if in redefine mode */
  caddr_t sp_first_element;	/*!< The name of the first element in the schema that is declared at top level */
  struct xecm_el_s* sp_xecm_els;
  ptrlong	    sp_xecm_el_no;
  struct xecm_st_s*	sp_empty_states;
  ptrlong		sp_empty_st_no;
  caddr_t *		sp_xecm_namespaces;
  ptrlong		sp_xecm_namespace_no;
  mem_pool_t*	pool;		/*!< processor's data must be in pool */
  int		sp_schema_is_loaded;	/*!< Flag that prevents schema from reloading on second top-level element */
  int		sp_serial;
  long sp_refcount;
}
schema_parsed_t;

/*! XML Schema processor structure */
typedef struct schema_processor_s
{
  schema_parsed_t *sp_schema;
  /* Validation declarations */
  xsv_astate_t	sp_stack[ECM_MAX_DEPTH]; /*!< Stack of actual states, one item per one not-yet-closed element */
  /* Current depth */
  ptrlong	sp_depth;
  lenmem_t sp_simpletype_value_acc;
  ptrlong sp_simpletype_depth;
  struct {
    ptrlong depth;
    struct xecm_el_s	*last_el;
  } temp;
} schema_processor_t;

#define sp_types	sp_hashtables[XS_SP_TYPES]
#define sp_elems	sp_hashtables[XS_SP_ELEMS]
#define sp_attrs	sp_hashtables[XS_SP_ATTRS]
#define sp_attrgrps	sp_hashtables[XS_SP_ATTRGRPS]
#define sp_groups	sp_hashtables[XS_SP_GROUPS]
#define sp_annots	sp_hashtables[XS_SP_ANNOTS]
#define sp_keys		sp_hashtables[XS_SP_KEYS]
#define sp_notations	sp_hashtables[XS_SP_NOTATIONS]
#define sp_mssql_rships sp_hashtables[XS_SP_MSSQL_RSHIPS]
#define sp_all_elnames	sp_hashtables[XS_SP_ALL_ELNAMES]

#define sp_all_elnames_count sp_all_elnames->ht_count

typedef
struct xs_tag_info_s {
  const char *	info_name;
  ptrlong	info_tagid;
  ptrlong	info_compcat;
  ptrlong	info_sp_hashtable_idx;
  SMTagPreProcessContent    info_start_handler;
  SMTagProcessContent	    info_end_handler;
  ptrlong	info_facetid; /* Unused for a while */
} xs_tag_info_t;

typedef
struct xs_tags_dict_s {
  xs_tag_info_t *	dict_array;
  int			dict_count;
  const char *		dict_name;
} xs_tags_dict_t;

extern xs_tag_info_t	xs_xsd_tags_array[];
extern xs_tag_info_t	xs_mssql_tags_array[];

typedef struct xml_syspath_s
{
  dk_set_t xmlp_list;
  dk_mutex_t *xmlp_mutex;
} xml_syspath_t;

extern xml_syspath_t *xml_sys_path_list;

/*** BEG RUS/FIXME Thu Mar 22 18:56:22 2001	*/
/* XML Schema Declaration callbacks		*/

/* if tag related to component creates it, in other case change last
   component's content */
extern void xsd_start_element_handler (void *parser,
    const char * name, vxml_parser_attrdata_t *attrdata);
/* compiles component content, erases internal tree */
extern void xsd_end_element_handler (void *parser, const char * name);

extern void xsd_start_namespace_decl_handler (void *parser,
    const char * prefix, const char * uri);
extern void xsd_end_namespace_decl_handler (void *parser,
    const char * prefix);
extern void xsd_entity_ref_handler (void *parser,
    const char * refname,
    int reflen, int isparam, const xml_def_4_entity_t * edef);



/* XML Schema Processin callbacks		*/
extern void xsp_start_element_handler (void *parser,
    const char * name, vxml_parser_attrdata_t *attrdata);
extern void xsp_end_element_handler (void *parser, const char * name);
extern void xsp_start_namespace_decl_handler (void *parser,
    const char * prefix, const char * uri);
extern void xsp_end_namespace_decl_handler (void *parser,
    const char * prefix);
extern void xsp_entity_ref_handler (void *parser,
    const char * refname,
    int reflen, int isparam, const xml_def_4_entity_t * edef);

ptrlong xs_register_type (xs_tag_t * type_tag);

xs_tag_t *xs_find_ancestor_by_component_type (xs_tag_t * tag, int *list);
ptrlong xs_component_status (xs_tag_t * tag);


#define facet_length		0x001UL
#define facet_minLength		0x002UL
#define facet_maxLength		0x004UL
#define facet_pattern		0x008UL
#define facet_enumeration	0x010UL
#define facet_whiteSpace	0x020UL
#define facet_maxInclusive	0x040UL
#define facet_maxExclusive	0x080UL
#define facet_minInclusive	0x100UL
#define facet_minExclusive	0x200UL
#define facet_totalDigits	0x400UL
#define facet_fractionDigits	0x800UL

#define facet_UNKNOWN		0x10000000UL

typedef struct builtin_props_s
{
  unsigned long facet_mask;
  char *type_name;
}
builtin_props_t;

extern builtin_props_t builtin_props[COUNTOF__xs_builtin_types];

/*! searches root origin for simple or complex type component, call only when all types are resolved */
xs_component_t *get_root_type (struct vxml_parser_s *, xs_component_t * c);
xs_facet_t *xs_check_facet_constraint (struct vxml_parser_s *,
    xs_component_t * c, xs_facet_t * f);
void xs_add_facet (struct vxml_parser_s *, xs_component_t * c, ptrlong fc_id,
    const char * value);
/*! the first argument is a tag of attribute declaration or att group reference,
    the second one is a either xs_component_t pointer or builtintype id */
void xs_add_attribute (xs_tag_t* tag, xs_component_t* attribute);
/*! subj. Argument is hash from processor */
int check_unresolved_components(struct vxml_parser_s* parser, struct id_hash_s* hash, const char* metaname);
int check_defvals (struct vxml_parser_s* parser);

extern int dtd_log_cm_location (struct vxml_parser_s *parser, xs_component_t *comp, int mode);

/*! makes component specific actions, fills deferred structures */
int xs_compile_component (struct vxml_parser_s *parser, xs_component_t * c);
/*! checks facets constraints for type component, fills set of facets */
int xs_compile_facets (struct vxml_parser_s *parser, xs_component_t * c);
/*! resolves attribute types */
int xs_compile_attributes (struct vxml_parser_s *parser, xs_component_t * c);


extern const char *xs_get_attr (const char * name, /* yes, const */ char **attrs);

#if 0
void xs_tag_free (xs_tag_t * ptag);
char **xs_copy_attlist (const char ** atts);
#endif
extern xs_component_t *xs_get_builtinidx (struct vxml_parser_s *parser, const char * expname_or_null, const char *qname, int auto_def);
extern xs_component_t *add_component_reference (vxml_parser_t* parser,
  const char * expname, const char * qname,
  id_hash_t * array, xml_pos_t * pos, int is_definition);

void set_grp_tree_elems (struct vxml_parser_s *parser,
    struct xs_tag_s *_this);
void penetrate_grp_elems (xs_tag_t * _this);
void set_grp_root_element (struct vxml_parser_s *parser, xs_tag_t * _this);


#define XSI_ATTR_SCHEMALOCATION			0x01
#define XSI_ATTR_NONAMESPACESCHEMALOCATION	0x02
#define XSI_ATTR_MASK				0xff
#define XSI_VERSION_2000			0x0100
#define XSI_VERSION_2001			0x0200
#define XSI_VERSION_MASK			0xff00
extern int schema_attr_is_location (vxml_parser_t *parser, char *attr);

/*! load and parse all external schemas listed in \c ref value of \c location_attr returns zero if finished successfuly.
  Error logs are appended to the main log. */
extern int load_external_schemas (struct vxml_parser_s* parser, int location_attr, const char* ref);
/*! load and parse external schema document returns zero if finished successfuly */
extern int load_external_schema (struct vxml_parser_s* parser, const char* ref, int is_internal);

/* support macros, implementation structures */
#define MAJOR_ID(z)	    ((z)->cm_type.t_major)
#define XS_CM_TYPE(z)	    ((z)->cm_type)

#ifdef DEBUG
#define _CM_TYPE_MAJOR_ID_CHECK(z,major) ((major == MAJOR_ID((z))) ? (z) : (xs_component_t *)(NULL))
#define _CM_TYPE_MAJOR_ID_CHECK2(z,major1,major2) ((major1 == MAJOR_ID((z)) || major2 == MAJOR_ID((z))) ? (z) : (xs_component_t *)(NULL))
#else
#define _CM_TYPE_MAJOR_ID_CHECK(z,major) (z)
#define _CM_TYPE_MAJOR_ID_CHECK2(z,major1,major2) (z)
#endif
#define INFO_ELEMENT(z)	    (_CM_TYPE_MAJOR_ID_CHECK((z),XS_COM_ELEMENT)->cm_type.spec.element)
#define INFO_CSTYPE(z)	    (_CM_TYPE_MAJOR_ID_CHECK2((z),XS_COM_SIMPLET,XS_COM_COMPLEXT)->cm_type.spec.cstype)
#define INFO_ATTRIBUTE(z)   (_CM_TYPE_MAJOR_ID_CHECK((z),XS_COM_ATTRIBUTE)->cm_type.spec.attribute)
#define INFO_ATTRGROUP(z)   (_CM_TYPE_MAJOR_ID_CHECK((z),XS_COM_ATTRGROUP)->cm_type.spec.attrgroup)
#define INFO_GROUP(z)	    (_CM_TYPE_MAJOR_ID_CHECK((z),XS_COM_GROUP)->cm_type.spec.group)
#define INFO_KEY(z)	    (_CM_TYPE_MAJOR_ID_CHECK((z),XS_COM_KEY)->cm_type.spec.key)
#define INFO_NOTATION(z)    (_CM_TYPE_MAJOR_ID_CHECK((z),XS_COM_NOTATION)->cm_type.spec.notation)
#define INFO_MSSQL_RSHIP(z) (_CM_TYPE_MAJOR_ID_CHECK((z),XS_COM_MSSQL_RSHIP)->cm_type.spec.mssql_rship)

#define IS_UNDEF_TYPE(z) ((MAJOR_ID((z))==XS_COM_UNDEF))
#define IS_COMPLEX_TYPE(z) ((MAJOR_ID((z))==XS_COM_COMPLEXT))
#define IS_SIMPLE_TYPE(z) ((MAJOR_ID((z))==XS_COM_SIMPLET))
#define IS_GROUP(z) ((MAJOR_ID((z))==XS_COM_GROUP))

#define XS_TYPE_ALLOWS_PCDATA(z) INFO_CSTYPE(z).allows_pcdata;

#define IS_DEFINED(comp) (XS_DEF_DEFINED & (comp)->cm_deflevel)
#define IS_REFERENCED(comp) (XS_DEF_REFERENCED & (comp)->cm_deflevel)

#if 1
#define XS_ASSERT(value) if (!(value)) GPF_T1("XS_ASSERT FAILED")
#define SHOULD_BE_CHANGED
#else
#define XS_ASSERT(value)
#define SHOULD_BE_CHANGED !!!!!!
#endif

typedef struct xs_builtin_type_info_s
{
  const char* binfo_name;
  enum xs_builtin_type_id binfo_typeid;
  unsigned long binfo_facetmask;
  const char* binfo_regexp_or_null;
} xs_builtin_types_info_t;
extern xs_builtin_types_info_t xs_builtin_type_info_dict[];
extern int xs_builtin_type_info_dict_size;


extern schema_parsed_t *DBG_NAME (xs_alloc_schema) (DBG_PARAMS_0);
#ifdef MALLOC_DEBUG
#define xs_alloc_schema() dbg_xs_alloc_schema (__FILE__, __LINE__)
#endif
extern void xs_addref_schema (schema_parsed_t *schema);
extern void xs_release_schema (schema_parsed_t *schema);

/*  returns 0 if succeeded,
    checks compliance of "value" string and allowed type's lex */
extern int xs_check_type_compliance(vxml_parser_t* parser, xs_component_t *type, const char* value, int err_options);
/*  internal usage function */
extern int xs_set_error (vxml_parser_t * parser, ptrlong errlevel, size_t buflen_eval,
    const char *format, ...);
int xmlparser_log_cm_location (struct vxml_parser_s *parser, xs_component_t *comp, int mode);
extern caddr_t xml_add_system_path (caddr_t uri);
extern void xs_add_predefined_types(vxml_parser_t* parser);
extern void xs_clear_processor(schema_processor_t* processor);

extern void grp_print_tree(grp_tree_elem_t* tree, int level, const char* comment);

int is_attr_boolean (const char * attr_val, int is_true);

extern void VXmlSetElementSchemaHandler (vxml_parser_t* parser, VXmlStartElementHandler sh, VXmlEndElementHandler eh);
extern void VXmlSetCharacterSchemaDataHandler (vxml_parser_t* parser, VXmlCharacterDataHandler h);

#endif	/* _XML_SCHEMA_H */

