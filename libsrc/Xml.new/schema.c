/*
 *  schema.c
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

#include "xmlparser_impl.h"

#include "sqlnode.h"
#include "eqlcomp.h"
#include "sqlfn.h"
#include "lisprdr.h"
#include "sqlpar.h"
#include "sqlcmps.h"
#include "sqlintrp.h"
#include "sqlbif.h"
#include "arith.h"
#include "security.h"
#include "sqlpfn.h"
#include "libutil.h"
#include "xml.h"

#include "bif_text.h"	/* for server_default_lh */
#include "schema.h"
#include "stdarg.h"

/* The following line is a stub for an idiotic bug. */
encoding_handler_t *intl_find_user_charset (const char *encname, int xml_input_is_wide);
void xs_add_predefined_attributes (vxml_parser_t * parser);

xml_syspath_t *xml_sys_path_list;

#define XS_FIXSTRING(z) ((z)?(z):(char*)"")

#define XS_TYPECOMPONENT(id) \
((XS_TAG_SIMPLE_TYPE == (id)) || (XS_TAG_COMPLEX_TYPE == (id)))

#define SHOULD_BE_CHANGED

#ifdef XMLSCHEMA_UNIT_DEBUG
#define schema_printf(Z) printf Z
#else
#define schema_printf(Z)
#endif

#define XSPAT__CENTURY		"-?\\d{2}\\d*"
#define XSPAT__YEAR		"-?\\d{4}\\d*"
#define XSPAT__MONTH		XSPAT__YEAR "-\\d{2}"
#define XSPAT__DATE		XSPAT__MONTH "-\\d{2}"
#define XSPAT__TIME		"\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?"
#define XSPAT__TIMEZONE		"(?:((Z)|([+-]\\d{2}:\\d{2})))?"
#define XSPAT_CENTURY		XSPAT__CENTURY XSPAT__TIMEZONE
#define XSPAT_YEAR		XSPAT__YEAR XSPAT__TIMEZONE
#define XSPAT_MONTH		XSPAT__MONTH XSPAT__TIMEZONE
#define XSPAT_DATE		XSPAT__DATE XSPAT__TIMEZONE
#define XSPAT_TIME		XSPAT__TIME XSPAT__TIMEZONE
#define XSPAT_RECCURINGDURATION	XSPAT_DATE "[T ]" XSPAT__TIME XSPAT__TIMEZONE
#define XSPAT_TIMEDURATION	"-?P(\\d+Y)?(\\d+M)?(\\d+D)?((T\\d+H(\\d+M(\\d+(\\.\\d+)?S)?)?)|(T\\d+M(\\d+(\\.\\d+)?S)?)|(T\\d+(\\.\\d+)?S))?"
#define XSPAT_LANGUAGE		"([a-zA-z]{2}|[iI]-[a-zA-Z]+|[xX]-[a-zA-Z]+)(-[a-zA-Z]+)*"
#define XSPAT_IEEE_FLOAT	"([+-]?\\d+(\\.\\d+)?(?:[Ee][+-]?\\d+)?)|(-?INF)|(NaN)"
#define XSPAT_IDREF		"\\w+[\\w.-]*"
#define XSPAT_NMTOKEN		"\\w+[\\w.:-]*"
#define XSPAT_LISTOF(x)		"((" x ")(\\s+(" x "))*)?"
xs_builtin_types_info_t xs_builtin_type_info_dict[] = {
  {""			, XS_BLTIN__UNKNOWN		, 0x00000000 , NULL},
  {"ENTITIES"		, XS_BLTIN_ENTITIES		, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, "((\\w+[\\w.-]*)([\\s]+\\w+[\\w.-]*)*)?"},
  {"ENTITY"		, XS_BLTIN_ENTITY		, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, "\\w+[\\w.-]*"},
  {"ID"			, XS_BLTIN_ID			, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, "\\w+[\\w.-]*"},
  {"IDREF"		, XS_BLTIN_IDREF		, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, XSPAT_IDREF},
  {"IDREFS"		, XS_BLTIN_IDREFS		, facet_length| facet_minLength| facet_maxLength| facet_enumeration| facet_whiteSpace, XSPAT_LISTOF(XSPAT_IDREF)},
  {"NCName"		, XS_BLTIN_NCNAME		, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, "\\w+[\\w.-]*"},
  {"NMTOKEN"		, XS_BLTIN_NMTOKEN		, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, XSPAT_NMTOKEN},
  {"NMTOKENS"		, XS_BLTIN_NMTOKENS		, facet_length| facet_minLength| facet_maxLength| facet_enumeration| facet_whiteSpace, XSPAT_LISTOF(XSPAT_NMTOKEN)},
  {"NOTATION"		, XS_BLTIN_NOTATION		, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, NULL},
  {"Name"		, XS_BLTIN_NAME			, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, "[\\w:.-]+"},
  {"QName"		, XS_BLTIN_QNAME		, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, "\\w+[\\w:.-]*"},
  {"anyType"		, XS_BLTIN_ANYTYPE		, 0xffffffff, NULL},
  {"anyURI"		, XS_BLTIN_ANYURI		, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, "^(([^:/?#]+):)?(//([^/?#]*))?([^?#]*)(\\?([^#]*))?(#(.*))?"},
  {"base64Binary"	, XS_BLTIN_BASE64BINARY		, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, NULL},
  {"binary"		, XS_BLTIN_BINARY		, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, NULL},
  {"boolean"		, XS_BLTIN_BOOLEAN		, facet_pattern| facet_whiteSpace, "(?:true|false|1|0)"},
  {"byte"		, XS_BLTIN_BYTE			, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "[+-]?\\d+"},
  {"century"		, XS_BLTIN_CENTURY		, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive|	facet_maxExclusive| facet_minInclusive| facet_minExclusive, XSPAT_CENTURY},
  {"date"		, XS_BLTIN_DATE			, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive|	facet_maxExclusive| facet_minInclusive| facet_minExclusive, XSPAT_DATE},
  {"dateTime"		, XS_BLTIN_DATETIME		, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive|	facet_maxExclusive| facet_minInclusive| facet_minExclusive, XSPAT_RECCURINGDURATION},
  {"decimal"		, XS_BLTIN_DECIMAL		, facet_totalDigits| facet_pattern| facet_enumeration| facet_whiteSpace|	facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "[+-]?((\\d+(\\.\\d+)?)|(\\.\\d+))"},
  {"double"		, XS_BLTIN_DOUBLE		, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive|	facet_maxExclusive| facet_minInclusive| facet_minExclusive, XSPAT_IEEE_FLOAT},
  {"duration"		, XS_BLTIN_DURATION		, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive|	facet_maxExclusive| facet_minInclusive| facet_minExclusive, NULL},
  {"emptyType"		, XS_BLTIN_EMPTYTYPE		, 0x00000000, "[]"},
  {"float"		, XS_BLTIN_FLOAT		, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive|	facet_maxExclusive| facet_minInclusive| facet_minExclusive, XSPAT_IEEE_FLOAT},
  {"gDay"		, XS_BLTIN_GDAY			, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive|	facet_maxExclusive| facet_minInclusive| facet_minExclusive, "---\\d{2}"},
  {"gMonth"		, XS_BLTIN_GMONTH		, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive|	facet_maxExclusive| facet_minInclusive| facet_minExclusive, "--\\d{2}--"},
  {"gMonthDay"		, XS_BLTIN_GMONTHDAY		, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive|	facet_maxExclusive| facet_minInclusive| facet_minExclusive, "--\\d{2}-\\d{2}"},
  {"gYear"		, XS_BLTIN_GYEAR		, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive|	facet_maxExclusive| facet_minInclusive| facet_minExclusive, "\\d{4}"},
  {"gYearMonth"		, XS_BLTIN_GYEARMONTH		, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "\\d{4}-\\d{2}"},
  {"hexBinary"		, XS_BLTIN_HEXBINARY		, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, "[+-]?[0-9a-fA-F]+"},
  {"int"		, XS_BLTIN_INT			, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "[+-]?\\d+"},
  {"integer"		, XS_BLTIN_INTEGER		, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "[+-]?\\d+"},
  {"language"		, XS_BLTIN_LANGUAGE		, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, XSPAT_LANGUAGE},
  {"list"		, XS_BLTIN_LIST			, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, NULL},
  {"long"		, XS_BLTIN_LONG			, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "[+-]?\\d+"},
  {"month"		, XS_BLTIN_MONTH		, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive|	facet_maxExclusive| facet_minInclusive| facet_minExclusive, XSPAT_MONTH},
  {"negativeInteger"	, XS_BLTIN_NEGATIVEINTEGER	, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "-[0]*[1-9]\\d*"},
  {"nonNegativeInteger"	, XS_BLTIN_NONNEGATIVEINTEGER	, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "[+]?\\d+"},
  {"nonPositiveInteger"	, XS_BLTIN_NONPOSITIVEINTEGER	, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "(-\\d+)|(-?0+)"},
  {"normalizedString"	, XS_BLTIN_NORMALIZEDSTRING	, facet_length| facet_minLength| facet_maxLength|	facet_pattern| facet_enumeration| facet_whiteSpace, NULL},
  {"number"		, XS_BLTIN_NUMBER		, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_whiteSpace| facet_enumeration| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "[+-]?\\d+"},
  {"positiveInteger"	, XS_BLTIN_POSITIVEINTEGER	, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "[+]?[0]*[1-9]\\d*"},
  {"reccuringDate"	, XS_BLTIN_RECCURINGDATE	, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "--\\d{2}-\\d{2}"},
  {"reccuringDay"	, XS_BLTIN_RECCURINGDAY		, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "---\\d{2}"},
  {"reccuringDuration"	, XS_BLTIN_RECCURINGDURATION	, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, XSPAT_RECCURINGDURATION},
  {"short"		, XS_BLTIN_SHORT		, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "[+-]?\\d+"},
  {"string"		, XS_BLTIN_STRING		, facet_length| facet_minLength| facet_maxLength|	facet_pattern| facet_enumeration| facet_whiteSpace, NULL},
  {"time"		, XS_BLTIN_TIME			, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive|	facet_maxExclusive| facet_minInclusive| facet_minExclusive, XSPAT_TIME},
  {"timeDuration"	, XS_BLTIN_TIMEDURATION		, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, XSPAT_TIMEDURATION},
  {"timeInstant"	, XS_BLTIN_TIMEINSTANT		, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, XSPAT_RECCURINGDURATION},
  {"timePeriod"		, XS_BLTIN_TIMEPERIOD		, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, XSPAT_RECCURINGDURATION},
  {"token"		, XS_BLTIN_TOKEN		, facet_length| facet_minLength| facet_maxLength|	facet_pattern| facet_enumeration| facet_whiteSpace, NULL},
  {"unsignedByte"	, XS_BLTIN_UNSIGNEDBYTE		, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "[+]?\\d+"},
  {"unsignedInt"	, XS_BLTIN_UNSIGNEDINT		, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "[+]?\\d+"},
  {"unsignedLong"	, XS_BLTIN_UNSIGNEDLONG		, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "[+]?\\d+"},
  {"unsignedShort"	, XS_BLTIN_UNSIGNEDSHORT	, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "[+]?\\d+"},
  {"uriReference"	, XS_BLTIN_URIREFERENCE		, facet_totalDigits| facet_fractionDigits| facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive| facet_maxExclusive| facet_minInclusive| facet_minExclusive, "\\w+[\\w:/?.-]*"},
  {"union"		, XS_BLTIN_UNION		, facet_pattern| facet_enumeration, NULL},
  {"xml:lang"		, XS_BLTIN_LANGUAGE		, facet_length| facet_minLength| facet_maxLength| facet_pattern| facet_enumeration| facet_whiteSpace, XSPAT_LANGUAGE},
  {"year"		, XS_BLTIN_YEAR			, facet_pattern| facet_enumeration| facet_whiteSpace| facet_maxInclusive|	facet_maxExclusive| facet_minInclusive| facet_minExclusive, XSPAT_YEAR}
};

int xs_builtin_type_info_dict_size = sizeof(xs_builtin_type_info_dict)/sizeof(xs_builtin_type_info_dict[0]);

/*#define XS_TYPECOMP(parser,idx) (&(parser)->processor.sp_schema->sp_types[idx])*/
/*#define XS_ATTRCOMP(parser,idx) (&(parser)->processor.sp_schema->sp_attrs[idx])*/

#define YOUNGEST_COMPONENT(z) (((z)->tag_base && (z)->tag_base->tag_basetag) ? (z)->tag_base->tag_basetag->tag_component : 0 )

#define DECLARE_TAG_HANDLERS(tagname)\
extern void xs_tag_##tagname(struct vxml_parser_s* parser, xs_tag_t* _this); \
extern void xs_tag_pre_##tagname(struct vxml_parser_s* parser, xs_tag_t* _this);

#define DEFINE_TAG_HANDLERS(tagname)\
void xs_tag_pre_##tagname(struct vxml_parser_s* parser, xs_tag_t* _this)\
{ schema_printf (("pre processing %s %d\n", __FILE__, __LINE__)); } \
void xs_tag_##tagname(struct vxml_parser_s* parser, xs_tag_t* _this)\
{ schema_printf (("processing %s %d\n", __FILE__, __LINE__)); }

DECLARE_TAG_HANDLERS (element)
DECLARE_TAG_HANDLERS (cstype)
DECLARE_TAG_HANDLERS (attribute)
DECLARE_TAG_HANDLERS (anyattribute)
DECLARE_TAG_HANDLERS (attgroup)
DECLARE_TAG_HANDLERS (group)
DECLARE_TAG_HANDLERS (redefine)
DECLARE_TAG_HANDLERS (restrict)
DECLARE_TAG_HANDLERS (simplefacet)
DECLARE_TAG_HANDLERS (sequence)
DECLARE_TAG_HANDLERS (choice)
DECLARE_TAG_HANDLERS (all)
DECLARE_TAG_HANDLERS (complexcontent)
DECLARE_TAG_HANDLERS (simplecontent)
DECLARE_TAG_HANDLERS (extension)
DECLARE_TAG_HANDLERS (import)
DECLARE_TAG_HANDLERS (include)
DECLARE_TAG_HANDLERS (any)
DECLARE_TAG_HANDLERS (annotation)
DECLARE_TAG_HANDLERS (appinfo)
DECLARE_TAG_HANDLERS (documentation)
DECLARE_TAG_HANDLERS (key)
DECLARE_TAG_HANDLERS (unique)
DECLARE_TAG_HANDLERS (keyref)
DECLARE_TAG_HANDLERS (selector)
DECLARE_TAG_HANDLERS (field)
DECLARE_TAG_HANDLERS (enumeration)
DECLARE_TAG_HANDLERS (notation)
DECLARE_TAG_HANDLERS (list)
DECLARE_TAG_HANDLERS (union)

DECLARE_TAG_HANDLERS (mssql_rship)

/* stubs */
extern void xs_unsupported_handler (struct vxml_parser_s* parser, xs_tag_t* _this);

xs_tag_info_t	xs_xsd_tags_array[]={
/* name			| tag id		| component category	| index of hash	| pre handler			| end handler		| facets	*/
  {"all"		, XS_TAG_ALL		, -1			, -1		, xs_tag_pre_all		, xs_tag_all		, facet_UNKNOWN },
  {"annotation"		, XS_TAG_ANNOTATION	, -1			, -1		, xs_tag_pre_annotation		, NULL			, facet_UNKNOWN },
  {"any"		, XS_TAG_ANY		, -1			, -1		, xs_tag_pre_any		, xs_tag_any		, facet_UNKNOWN },
  {"anyAttribute"	, XS_TAG_ANYATTR	, -1			, -1		, NULL				, xs_tag_anyattribute	, facet_UNKNOWN },
  {"appinfo"		, XS_TAG_APPINFO	, -1			, -1		, xs_tag_pre_appinfo		, NULL			, facet_UNKNOWN },
  {"attribute"		, XS_TAG_ATTRIBUTE	, XS_COM_ATTRIBUTE	, XS_SP_ATTRS	, NULL				, xs_tag_attribute	, facet_UNKNOWN },
  {"attributeGroup"	, XS_TAG_ATTRGROUP	, XS_COM_ATTRGROUP	, XS_SP_ATTRGRPS, xs_tag_pre_attgroup		, xs_tag_attgroup	, facet_UNKNOWN },
  {"choice"		, XS_TAG_CHOICE		, -1			, -1		, xs_tag_pre_choice		, xs_tag_choice		, facet_UNKNOWN },
  {"complexContent"	, XS_TAG_COMLEXCONTENT	, -1			, -1		, xs_tag_pre_complexcontent	, NULL			, facet_UNKNOWN },
  {"complexType"	, XS_TAG_COMPLEX_TYPE	, XS_COM_COMPLEXT	, XS_SP_TYPES	, xs_tag_pre_cstype		, xs_tag_cstype		, facet_UNKNOWN },
  {"documentation"	, XS_TAG_DOCUMENTATION	, -1			, -1		, xs_tag_pre_documentation	, NULL			, facet_UNKNOWN },
  {"element"		, XS_TAG_ELEMENT	, XS_COM_ELEMENT	, XS_SP_ELEMS	, xs_tag_pre_element		, xs_tag_element	, facet_UNKNOWN },
  {"enumeration"	, XS_TAG_ENUMERATION	, -1			, -1		, xs_tag_pre_simplefacet	, NULL			, facet_enumeration },
  {"extension"		, XS_TAG_EXTENSION	, -1			, -1		, xs_tag_pre_extension		, xs_tag_extension	, facet_UNKNOWN },
  {"field"		, XS_TAG_FIELD		, -1			, -1		, NULL				, xs_tag_field		, facet_UNKNOWN},
  {"fractionDigits"	, XS_TAG_FRACDIGITS	, -1			, -1		, xs_tag_pre_simplefacet	, NULL			, facet_fractionDigits },
  {"group"		, XS_TAG_GROUP		, XS_COM_GROUP		, XS_SP_GROUPS	, xs_tag_pre_group		, xs_tag_group		, facet_UNKNOWN },
  {"import"		, XS_TAG_IMPORT		, -1			, -1		, NULL				, xs_tag_import		, facet_UNKNOWN },
  {"include"		, XS_TAG_INCLUDE	, -1			, -1		, NULL				, xs_tag_include	, facet_UNKNOWN },
  {"key"		, XS_TAG_KEY		, XS_COM_KEY		, XS_SP_KEYS	, xs_tag_pre_key		, NULL			, facet_UNKNOWN },
  {"keyref"		, XS_TAG_KEYREF		, -1			, -1		, xs_tag_pre_keyref		, xs_tag_keyref		, facet_UNKNOWN },
  {"length"		, XS_TAG_LENGTH		, -1			, -1		, xs_tag_pre_element		, xs_tag_element	, facet_UNKNOWN },
  {"list"		, XS_TAG_LIST		, -1			, -1		, xs_tag_pre_list		, xs_tag_list		, facet_UNKNOWN },
  {"maxExclusive"	, XS_TAG_MAXEXCL	, -1			, -1		, xs_tag_pre_simplefacet	, NULL			, facet_maxExclusive },
  {"maxInclusive"	, XS_TAG_MAXINCL	, -1			, -1		, xs_tag_pre_simplefacet	, NULL			, facet_maxInclusive },
  {"maxLength"		, XS_TAG_MAXLENGTH	, -1			, -1		, xs_tag_pre_simplefacet	, NULL			, facet_maxLength },
  {"minExclusive"	, XS_TAG_MINEXCL	, -1			, -1		, xs_tag_pre_simplefacet	, NULL			, facet_minExclusive },
  {"minInclusive"	, XS_TAG_MININCL	, -1			, -1		, xs_tag_pre_simplefacet	, NULL			, facet_minInclusive },
  {"minLength"		, XS_TAG_MINLENGTH	, -1			, -1		, xs_tag_pre_simplefacet	, NULL			, facet_minLength },
  {"notation"		, XS_TAG_NOTATION	, XS_COM_NOTATION	, XS_SP_NOTATIONS, xs_tag_pre_notation		, NULL			, facet_UNKNOWN },
  {"pattern"		, XS_TAG_LENGTH		, -1			, -1		, xs_tag_pre_simplefacet	, NULL			, facet_pattern },
  {"redefine"		, XS_TAG_REDEFINE	, -1			, -1		, xs_tag_pre_redefine		, xs_tag_redefine	, facet_UNKNOWN },
  {"restriction"	, XS_TAG_RESTRICTION	, -1			, -1		, xs_tag_pre_restrict		, xs_tag_restrict	, facet_UNKNOWN },
  {"selector"		, XS_TAG_SELECTOR	, -1			, -1		, NULL				, xs_tag_selector	, facet_UNKNOWN },
  {"sequence"		, XS_TAG_SEQUENCE	, -1			, -1		, xs_tag_pre_sequence		, xs_tag_sequence	, facet_UNKNOWN },
  {"simpleContent"	, XS_TAG_SIMPLECONTENT	, -1			, -1		, xs_tag_pre_simplecontent	, NULL			, facet_UNKNOWN },
  {"simpleType"		, XS_TAG_SIMPLE_TYPE	, XS_COM_SIMPLET	, XS_SP_TYPES	, xs_tag_pre_cstype		, xs_tag_cstype		, facet_UNKNOWN },
  {"totalDigits"	, XS_TAG_TOTALDIGITS	, -1			, -1		, xs_tag_pre_simplefacet	, NULL			, facet_totalDigits },
  {"union"		, XS_TAG_UNION		, -1			, -1		, xs_tag_pre_union		, xs_tag_union		, facet_UNKNOWN },
  {"unique"		, XS_TAG_UNIQUE		, XS_COM_KEY		, XS_SP_KEYS	, xs_tag_pre_unique		, NULL			, facet_UNKNOWN },
  {"whiteSpace"		, XS_TAG_WHITESPACE	, -1			, -1		, xs_tag_pre_simplefacet	, NULL			, facet_whiteSpace },
};

#define xs_xsd_tags_count (sizeof(xs_xsd_tags_array)/sizeof(xs_tag_info_t))

xs_tags_dict_t xs_xsd_tags_dict = {xs_xsd_tags_array, xs_xsd_tags_count, "XML Schema namespace"};

xs_tag_info_t	xs_mssql_tags_array[]={
  {"relationship"	, XS_TAG_MSSQL_RSHIP	, XS_COM_MSSQL_RSHIP	, XS_SP_MSSQL_RSHIPS, NULL			, xs_tag_mssql_rship	, facet_UNKNOWN },
};

#define xs_mssql_tags_count (sizeof(xs_mssql_tags_array)/sizeof(xs_tag_info_t))

xs_tags_dict_t xs_mssql_tags_dict = { xs_mssql_tags_array, xs_mssql_tags_count, "Microsoft's \"SQL extensions\" namespace"};

#define XS_NAME_IS_XSD		0
#define XS_NAME_IS_MSSQL	1

xs_tags_dict_t *xs_dicts[2] = { &xs_xsd_tags_dict, &xs_mssql_tags_dict};

/*! The function gets a raw name (value of "name" attribute or NULL) and builds fully qualified and maybe prefixed \c expname and human-readable \c qname
\returns 1 if \c expname is identical to name that will actually appear in XML documents (i.e. either prefix_by_context is zero or there's no context) */
extern int xs_generate_component_names (struct vxml_parser_s *parser, const char *raw_name, int prefix_by_context, char **ret_longname, char **ret_qname, int qual_or_unqual);

/* component methods declaration  */
int xs_add_content_entry_def (struct xs_component_s *_this,
    struct xs_tag_s *obj);
int xs_comp_destr_def (struct xs_component_s *_this);

int xs_add_content_entry_element (struct xs_component_s *_this,
    struct xs_tag_s *obj);
/* int xs_comp_destr_def(struct xs_component_s* obj); */


const char *xs_component_type_names[COUNTOF__XS_COM] = {
  "undefined component",
  "element",
  "attribute",
  "simple type",
  "complex type",
  "attribute group",
  "content model group",
  "identity constraint",
  "integrity constrint",
  "notation",
  "mapping schema relationship"
  };

/* derivation term's table */

derivation_types_t _derivation_types[] =
{
  {"#all",		XS_DER_EXTENSION | XS_DER_RESTRICTION},
  {"extension",		XS_DER_EXTENSION},
  {"restriction",	XS_DER_RESTRICTION}
};
derivation_types_t _derivation_element_types[] =
{
  {"#all",		XS_DER_EXTENSION | XS_DER_RESTRICTION | XS_DER_SUBSTITUTION },
  {"extension",		XS_DER_EXTENSION},
  {"restriction",	XS_DER_RESTRICTION},
  {"substitution",	XS_DER_SUBSTITUTION}
};
derivation_types_t _derivation_simple_types[] =
{
  {"#all",		XS_DER_EXTENSION | XS_DER_RESTRICTION | XS_DER_LIST | XS_DER_UNION},
  {"extension",		XS_DER_EXTENSION},
  {"list",		XS_DER_LIST},
  {"restriction",	XS_DER_RESTRICTION},
  {"union",		XS_DER_UNION}
};
qualified_types_t _qualified_types[] =
{
  {"qualified", XS_QUAL},
  {"unqualified", XS_UNQUAL}
};

const derivation_types_t * derivation_types = _derivation_types;
const int derivation_types_no = sizeof (_derivation_types) / sizeof (derivation_types_t);

const derivation_types_t * derivation_el_types = _derivation_element_types;
const int derivation_el_types_no = sizeof (_derivation_element_types) / sizeof (derivation_types_t);

const derivation_types_t * derivation_simple_types = _derivation_simple_types;
const int derivation_simple_types_no = sizeof (_derivation_simple_types) / sizeof (derivation_types_t);

const qualified_types_t * qualified_types  = _qualified_types;
const int qualified_types_no = sizeof (_qualified_types) / sizeof (qualified_types_t);

#ifdef XS_POOL_DEBUG
int xs_pool_free = 0;
int xs_pool_free_tries = 0;
int xs_pool_allocs = 0;
int xs_pool_allocs_tries = 0;
int xs_pool_schemas = 0;
#endif

int xmlparser_log_cm_location (struct vxml_parser_s *parser, xs_component_t *comp, int mode)
{
  xml_pos_t *pos;
  const char *format, *src;
  if (0 == mode)
    mode = (IS_DEFINED(comp) ? XS_DEF_DEFINED : XS_DEF_REFERENCED);
  switch (mode)
    {
    case (XS_DEF_DEFINED | XS_DEF_REFERENCED):
      return (
        xmlparser_log_cm_location (parser, comp, XS_DEF_DEFINED) &&
        xmlparser_log_cm_location (parser, comp, XS_DEF_REFERENCED) );
    case XS_DEF_DEFINED:
      if (!IS_DEFINED(comp))
        return 1;
      pos = &(comp->cm_definition);
      format = "The %s '%s' is defined at line %ld of '%s'";
      break;
    case XS_DEF_REFERENCED:
      if (!IS_REFERENCED(comp))
        return 1;
      pos = &(comp->cm_reference);
      format = "The first reference to %s '%s' is at line %ld of '%s'";
      break;
    default:
#ifdef DEBUG
      GPF_T;
#endif
      return 1;
    }
  src = pos->origin_uri;
  if (NULL == src)
    src = parser->cfg.uri;
  if (NULL == src)
    src = "source text";
  return xmlparser_logprintf (parser, XCFG_DETAILS,
    100+strlen(src)+strlen(comp->cm_qname),
    format,
    xs_component_type_names[MAJOR_ID(comp)], comp->cm_qname,
    (long)(pos->line_num), src );
}

void
VXmlAddSchemaDeclarationCallbacks (vxml_parser_t * parser)
{
  INNER_HANDLERS->start_element_handler =
      (VXmlStartElementHandler) dtd_start_element_handler;
  INNER_HANDLERS->end_element_handler =
      (VXmlEndElementHandler) dtd_end_element_handler;
  OUTER_HANDLERS->start_element_handler = xsd_start_element_handler;
  OUTER_HANDLERS->end_element_handler = xsd_end_element_handler;

  if (NULL == parser->processor.sp_schema)
    parser->processor.sp_schema = xs_alloc_schema();
  if (!parser->processor.sp_schema->sp_elems)
    {
      int ctr;
      for (ctr = 0; ctr < COUNTOF__XS_SP_HASH; ctr++)
        parser->processor.sp_schema->sp_hashtables[ctr] = id_str_hash_create (61);
    }
}

/*! finds name without namespace if namespace (ns) is not null.
  If namespace couldnot be found, returns NULL.
  In other cases returns name.
*/
char *
xs_get_local_name (const char * ns_uri, char * name)
{
  if (NULL != ns_uri)
    {
      char *ns_end = strrchr (name, ':');
      if ((NULL != ns_end) && !strncmp (ns_uri, name, ns_end - name))
	return (char*) box_dv_short_string (ns_end + 1);
      return NULL;
    }
  return name;
}


const char *
xs_strip_prefix (const char* name)
{
  const char* strippedname = strrchr (name, ':');
  if (strippedname)
    return strippedname+1;
  return name;
}


void
xs_names_of_surrounding_type (vxml_parser_t * parser, int last_resort, char** ret_longname, char** ret_qname)
{
  ptrlong depth = parser->validator.dv_depth;
  dtd_astate_t *state = parser->validator.dv_stack + depth;
  xs_tag_t *basetag;
  static int mask1[] = {XS_COM_SIMPLET, XS_COM_COMPLEXT, XS_COM_ATTRGROUP, XS_COM_GROUP, -1};
  static int mask2[] = {XS_COM_ELEMENT, XS_COM_ATTRIBUTE, -1};
  basetag = xs_find_ancestor_by_component_type (state->da_tag, mask1);
  if ((NULL == basetag) && last_resort)
    basetag = xs_find_ancestor_by_component_type (state->da_tag, mask2);
  if (basetag)
    {
      ret_longname[0] = basetag->tag_component->cm_longname;
      ret_qname[0] = basetag->tag_component->cm_qname;
    }
  else
    {
      ret_longname[0] = NULL;
      ret_qname[0] = NULL;
    }
}

int
xs_generate_component_names (vxml_parser_t * parser, const char* raw_name, int prefix_by_context, char** ret_longname, char** ret_qname, int qual_or_unqual)
{
  const char *longname_delim, *qname_delim;
  const char *colon;
  ccaddr_t longname_prefix = NULL, qname_prefix = NULL;
  int longname_matches_real_name = ((NULL == raw_name) ? 0 : 1);
  mem_pool_t* pool = parser->processor.sp_schema->pool;
  if (prefix_by_context)
    xs_names_of_surrounding_type (parser, (NULL == raw_name), (char **) &longname_prefix, (char **) &qname_prefix);

  if (NULL != longname_prefix)
    {
      longname_delim = qname_delim = "#";
      longname_matches_real_name = 0;
      goto parts_prepared;
    }
  colon = strrchr (raw_name, ':');
  if (NULL != colon)
    {
      if (colon == raw_name)
        {
          xs_set_error (parser, XCFG_FATAL,
	    ECM_MESSAGE_LEN * 2 + utf8len (raw_name),
	    "Name '%s' should not start with colon", raw_name );
          longname_prefix = "";
          longname_delim = "";
          qname_prefix = "";
          qname_delim = "";
          goto parts_prepared;
        }
      qname_prefix = mp_box_dv_short_nchars (pool, raw_name, colon-raw_name);
      longname_prefix = VXmlFindNamespaceUriByPrefix (parser, qname_prefix);
      if (NULL == longname_prefix)
        {
          xs_set_error (parser, XCFG_FATAL,
	    ECM_MESSAGE_LEN * 2 + utf8len (raw_name),
	    "Undefined namespace prefix '%s' in name '%s'", qname_prefix, raw_name );
          longname_prefix = "";
        }
      longname_delim = longname_prefix[0] ? ":" : "";
      qname_delim = qname_prefix[0] ? ":" : "";
      goto parts_prepared;
    }
  longname_prefix = parser->processor.sp_schema->sp_target_ns_uri;
  if ((NULL != longname_prefix) && (XS_QUAL == qual_or_unqual))
    {
      qname_prefix = VXmlFindNamespacePrefixByUri (parser, longname_prefix);
      if ((NULL == qname_prefix) || (uname___empty == qname_prefix))
        qname_prefix = longname_prefix;
      longname_delim = longname_prefix[0] ? ":" : "";
      qname_delim = qname_prefix[0] ? ":" : "";
      goto parts_prepared;
    }
  longname_prefix = (char *)"";
  qname_prefix = (char *)"";
  longname_delim = qname_delim = "";

parts_prepared:
  if (NULL != ret_longname)
    ret_longname[0] =
      mp_alloc_box (pool, utf8len (longname_prefix) +
      (raw_name ? utf8len (raw_name) : 10) + 20, DV_SHORT_STRING);
  if (NULL != ret_qname)
    ret_qname[0] =
      mp_alloc_box (pool, utf8len (qname_prefix) +
      (raw_name ? utf8len (raw_name) : 10) + 20, DV_SHORT_STRING);
  if (raw_name)
    {
      if (NULL != ret_longname)
	sprintf ((char*) ret_longname[0], "%s%s%s",
	  (char*) longname_prefix, longname_delim, (char*) raw_name);
      if (NULL != ret_qname)
	sprintf ((char*) ret_qname[0], "%s%s%s",
	  (char*) qname_prefix, qname_delim, (char*) raw_name);
    }
  else
    {
      if (NULL != ret_longname)
	sprintf ((char*) ret_longname[0], "%s%sanonymous-%03ld",
	  (char*) longname_prefix, longname_delim,
	  parser->processor.sp_schema->sp_type_counter);
      if (NULL != ret_qname)
	sprintf ((char*) ret_qname[0], "%s%sanonymous-%03ld",
	  (char*) qname_prefix, qname_delim,
	  parser->processor.sp_schema->sp_type_counter);
      parser->processor.sp_schema->sp_type_counter++;
    }
  return longname_matches_real_name;
}

ptrlong xs_get_tag_idx (const char* name, int tag_dict_id)
{
  xs_tags_dict_t *dict = xs_dicts[tag_dict_id];
  ptrlong tagidx = ecm_find_name(name, (void*)dict->dict_array, dict->dict_count, sizeof(xs_tag_info_t));
#ifdef XMLSCHEMA_UNIT_DEBUG
  if (-1 == tagidx)
    GPF_T1("this XSD tag is not supported");
#endif
  return tagidx;
}

enum xs_tags
xs_get_major_id (char * comp_name, int tag_dict_id)
{
  xs_tags_dict_t *dict = xs_dicts[tag_dict_id];
  ptrlong tagidx = xs_get_tag_idx(comp_name, tag_dict_id);
  if (-1 != tagidx)
    return dict->dict_array[tagidx].info_tagid;
  schema_printf (("schema: warning: unknown tag '%s' in %s\n", comp_name, dict->dict_name));
  return XS_TAG_UNKNOWN;
}

#define MEMBERPOINTER(structure_t,member_path) \
( \
  ((char *)(&(((structure_t*)(NULL))->member_path))) - \
  ((char *)(NULL)) )

#define MEMBERPOINTERDEREF(structure_ptr,member_pointer,member_type) \
(((member_type *) (((char *)(structure_ptr)) + member_pointer))[0])

typedef enum xs_sql_ann_type
{
  ANN_INT,
  ANN_BOOL,
  ANN_ENUM,
  ANN_STRING,
  ANN_NAME,
  ANN_RELATION,
  ANN_IDREFS
} xs_sql_ann_type_t;

typedef struct xs_sql_ann_info_s
{
  ptrdiff_t		ann_field;
  const char *		ann_attrname;
  xs_sql_ann_type_t	ann_type;
  const char *		ann_vals[5];
  const char *		ann_purpose;
} xs_sql_ann_info_t;

xs_sql_ann_info_t xs_sql_ann_array[] = {
  { MEMBERPOINTER(xs_mssql_ann_t,sql_relation)		, "relation"	, ANN_NAME	, {NULL}, "database table"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_field)		, "field"	, ANN_NAME	, {NULL}, "database column"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_is_constant)	, "is-constant"	, ANN_BOOL	, {"false", "true", "0", "1", NULL}, "'constant element' flag"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_exclude)		, "mapped"	, ANN_BOOL	, {"true", "false", "1", "0", NULL} /* 'true' is before 'false' to make a negation */, "'mapped item' flag"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_relationship)	, "relationship", ANN_RELATION	, {NULL}, "e.g. join condition"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_limit_field)	, "limit-field"	, ANN_NAME	, {NULL}, "database column for use in WHERE clause"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_limit_value)	, "limit-value"	, ANN_STRING	, {NULL}, "column value for use in WHERE clause"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_key_fields)	, "key-fields"	, ANN_IDREFS	, {NULL}, "column(s) that uniquely identify the rows in a table"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_prefix)		, "prefix"	, ANN_STRING	, {NULL}, "prefix for ID, IDREF and IDREFS values"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_use_cdata)		, "use-cdata"	, ANN_BOOL	, {"false", "true", "0", "1", NULL}, "'CDATA output' flag"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_encode)		, "encode"	, ANN_INT	, {"default", "url", NULL}, "BLOB encoding method"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_overflow_field)	, "overflow-field", ANN_NAME	, {NULL}, "database column with the overflow data"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_inverse)		, "inverse"	, ANN_BOOL	, {"false", "true", "0", "1", NULL}, "'inverse relationship' flag"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_hide)		, "hide"	, ANN_BOOL	, {"false", "true", "0", "1", NULL}, "'hide the subtree' flag"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_identity)		, "identity"	, ANN_ENUM	, {"", "ignore", "useValue", NULL}, "update mode of IDENTITY-type database column"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_guid)		, "guid"	, ANN_ENUM	, {"", "generate", "useValue", NULL}, "the origin of GUID values for a database column"},
  { MEMBERPOINTER(xs_mssql_ann_t,sql_max_depth)		, "max-depth"	, ANN_INT	, {NULL}, "depth of the recursive relationship"}
};

#define xs_sql_ann_count (sizeof (xs_sql_ann_array) / sizeof (xs_sql_ann_array[0]))


const char *
xs_get_sql_attr (vxml_parser_t *parser, const char * local_name, char ** attrs)
{
  while (*attrs)
    {
      char *colon = strrchr ((char *)(attrs[0]), ':');
      if (colon && !strcmp (colon + 1, local_name))
	return attrs[1];
      attrs += 2;
    }
  return NULL;
}


dk_set_t xs_attr_val_to_idrefs (const char *attr_val)
{
  const char *attr_tail = attr_val;
  const char *attr_id_begin;
  dk_set_t attr_idrefs = NULL;
  for (;;)
    {
      while (isspace (attr_tail[0])) attr_tail++;
      if ('\0' == attr_tail[0])
	break;
      attr_id_begin = attr_tail;
      while (('\0' != attr_tail[0]) && (!isspace (attr_tail[0]))) attr_tail++;
      dk_set_push (&attr_idrefs, box_dv_short_nchars ((const char *)attr_id_begin, attr_tail-attr_id_begin));
    }
  return attr_idrefs;
}

void xsd_fill_mssql_ann (vxml_parser_t *parser, xs_tag_t *curr_tag, xs_component_t *curr_comp)
{
  xs_mssql_ann_t *ann = NULL;
  int ann_ctr;
  switch (curr_comp->cm_type.t_major)
    {
    case XS_COM_ELEMENT:
      ann = &(curr_comp->cm_type.spec.element.ann);
      break;
    case XS_COM_ATTRIBUTE:
      ann = &(curr_comp->cm_type.spec.attribute.ann);
      break;
    default:
      return;
    }
/* Raw reading of annotation attributes without any consistency checking */
  for (ann_ctr = 0; ann_ctr < xs_sql_ann_count; ann_ctr++)
    {
      xs_sql_ann_info_t * ann_info = xs_sql_ann_array + ann_ctr;
      const char *attr_val = xs_get_sql_attr (parser, ann_info->ann_attrname, curr_tag->tag_atts);
      int attr_enum_idx;
      int isbool = 0;
      if (NULL == attr_val)
	continue;
      if (NULL == ann)
        {
	  xs_set_error (parser, XCFG_ERROR, 400 + strlen(attr_val),
	    "MS SQL extension attribute '%s' (%s) is not allowed in tag %s",
	    ann_info->ann_attrname, ann_info->ann_purpose, curr_tag->tag_info->info_name );
	}
      switch (ann_info->ann_type)
	{
	  case ANN_INT:
	    MEMBERPOINTERDEREF(ann, ann_info->ann_field, int) = atoi (attr_val);
	    break;
	  case ANN_STRING:
	  case ANN_NAME:
	    MEMBERPOINTERDEREF(ann, ann_info->ann_field, char *) = box_dv_short_string (attr_val);
	    break;
	  case ANN_BOOL:
	    isbool= 1;
	    /* no break */
	  case ANN_ENUM:
	    for (attr_enum_idx = 0; ann_info->ann_vals[attr_enum_idx] != NULL; attr_enum_idx++)
	      {
		if (!strcmp (ann_info->ann_vals[attr_enum_idx], attr_val))
		  break;
	      }
	    if (NULL == ann_info->ann_vals[attr_enum_idx])
	      {
		xs_set_error (parser, XCFG_ERROR, 400 + strlen(attr_val),
		  "Invalid value '%s' of MS SQL extension attribute '%s' (%s) of tag %s",
		  attr_val, ann_info->ann_attrname, ann_info->ann_purpose, curr_tag->tag_info->info_name );
		attr_enum_idx = -1;
	      }
	    else
	      {
		if (isbool)
		  attr_enum_idx %= 2;
	      }
	    MEMBERPOINTERDEREF(ann, ann_info->ann_field, int) = attr_enum_idx;
	    break;
	  case ANN_IDREFS:
	    {
	      dk_set_t attr_idrefs = xs_attr_val_to_idrefs (attr_val);
	      MEMBERPOINTERDEREF(ann, ann_info->ann_field, xs_ids_t).ids_count = dk_set_length (attr_idrefs);
	      MEMBERPOINTERDEREF(ann, ann_info->ann_field, xs_ids_t).ids_array = (char **)list_to_array (attr_idrefs);
	      break;
	    }
	  case ANN_RELATION:
	    {
	      caddr_t expname = VXmlFindExpandedNameByQName (parser, attr_val,
		((NULL == parser->processor.sp_schema->sp_target_ns_uri) ? 1 : 0) );
	      xs_component_t *rel = add_component_reference (
		parser, expname, attr_val, parser->processor.sp_schema->sp_mssql_rships,
		&parser->curr_pos, 0);
	      dk_free_box (expname);
	      MEMBERPOINTERDEREF(ann, ann_info->ann_field, ptrlong) = (ptrlong)rel;
	      break;
	    }
	  default:
	    GPF_T;
	}
    }
}


void xsd_destroy_mssql_ann (xs_mssql_ann_t *ann)
{
  int ann_ctr;
  for (ann_ctr = 0; ann_ctr < xs_sql_ann_count; ann_ctr++)
    {
      xs_sql_ann_info_t * ann_info = xs_sql_ann_array + ann_ctr;
      switch (ann_info->ann_type)
	{
	  case ANN_INT:
	  case ANN_BOOL:
	  case ANN_ENUM:
	  case ANN_RELATION:
	    break;
	  case ANN_STRING:
	  case ANN_NAME:
	    dk_free_box (MEMBERPOINTERDEREF(ann, ann_info->ann_field, char *));
	    break;
	  case ANN_IDREFS:
	    dk_free_tree (MEMBERPOINTERDEREF(ann, ann_info->ann_field, xs_ids_t).ids_array);
	    break;
	  default:
	    GPF_T;
	}
    }
}

void
xsd_start_element_handler (void *parser_v,
    const char * name, vxml_parser_attrdata_t *attrdata)
{
  vxml_parser_t *parser = parser_v;
  schema_parsed_t *schema = parser->processor.sp_schema;
  dtd_astate_t *state =
      parser->validator.dv_stack + parser->validator.dv_depth;
  char *element_expname;
  const char *element_localname;
  mem_pool_t* pool = schema->pool;
  int dict_id;
  char **atts;

  if ((ECM_ST_ERROR == state->da_state) && parser->validator.dv_dtd->ed_is_filled)
    return;

/*  set_context_buffer (&state->da_context_buffer, parser);*/

  if (!parser->validator.dv_depth)
    {
#ifdef XS_POOL_DEBUG
      xs_pool_allocs_tries++;
#endif
      if (!schema->sp_is_internal)
        {
          if (NULL == pool)
	    {
	      parser->processor.sp_schema->pool = pool = mem_pool_alloc();
#ifdef MP_MAP_CHECK
              mp_comment (pool, "xsd ", ((NULL != schema->sp_target_ns_uri) ? schema->sp_target_ns_uri : " NULL sp_target_ns_uri"));
#endif

#ifdef XS_POOL_DEBUG
	      xs_pool_allocs++;
#endif
	    }
	}
    }

  {
    char **att_temp;
    tag_attr_t *attr = attrdata->local_attrs;
    tag_attr_t *attr_end = attr + attrdata->local_attrs_count;
    atts = att_temp = (char **) mp_alloc (pool, (attrdata->local_attrs_count * 2 + 1) * sizeof (char *));
    for (/* no init*/; attr < attr_end; attr++)
      {
       (att_temp++)[0] = mp_box_string (pool, attr->ta_raw_name.lm_memblock);
       (att_temp++)[0] = mp_box_string (pool, attr->ta_value);
      }
    att_temp[0] = 0;
  }


  if (parser->validator.dv_depth)
    {
      if ((TAG_ST_ERROR == state[-1].da_sstate) ||
	  ((ECM_ST_ERROR == state[-1].da_state) && parser->validator.dv_dtd->ed_is_filled) )
	{
	  state[0].da_sstate = TAG_ST_ERROR;
	  return;
	}
      else
	  state[0].da_sstate = TAG_ST_NORMAL;
      element_expname = VXmlFindExpandedNameByQName (parser, name, 0);
      element_localname = xs_strip_prefix (element_expname);
      do {
	if (
	  (element_expname + XMLSCHEMA_NS_URI_LEN == element_localname - 1) &&
	  !strncmp (XMLSCHEMA_NS_URI, element_expname, (element_localname - element_expname)-1) )
	  {
	    dict_id = XS_NAME_IS_XSD;
	    break;
	  }
	if (
	  (element_expname + MSSQL_NS_URI_LEN == element_localname - 1) &&
	  !strncmp (MSSQL_NS_URI, element_expname, (element_localname - element_expname)-1) )
	  {
	    dict_id = XS_NAME_IS_MSSQL;
	    break;
	  }
        element_localname = NULL;
#if 0
	xs_set_error (parser, XCFG_WARNING, 100 + utf8len (element_expname),
	  "Unknown tag <%s>", (char*) element_expname );
	goto cleanup;
#else
	break;
#endif
	} while (0);

      if (element_localname)
	{
	  ptrlong tagidx = xs_get_tag_idx (element_localname, dict_id);
	  if (-1 == tagidx)
	    {
	      SHOULD_BE_CHANGED;	/* error, unknown type */
	      xs_set_error (parser, XCFG_ERROR, 100 + utf8len (element_localname),
		  "Unknown tag <%s> in %s", (char*) element_localname, xs_dicts[dict_id]->dict_name );
	      goto cleanup;
	    }
	  else
	    {
	      xs_tag_info_t *tag_info = xs_dicts[dict_id]->dict_array + tagidx;
	      xs_component_t *curr_comp = 0;
	      xs_tag_t *tag = (xs_tag_t *) mp_alloc (pool, sizeof (xs_tag_t));
	      memset (tag, 0, sizeof (xs_tag_t));
	      tag->tag_base = state[-1].da_tag;
	      tag->tag_info = tag_info;
	      tag->tag_atts = atts;
	      state[0].da_tag = tag;
	      switch (xs_component_status(tag))
	      {
	      case XS_COMPONENT:
		{
		  const char *raw_name = xs_get_attr ("name", tag->tag_atts);
		  char *longname, *qname;
		  ptrlong hashtable_idx = tag_info->info_sp_hashtable_idx;
		  id_hash_t *array = schema->sp_hashtables[hashtable_idx];
		  xs_component_t *xs_comp;
		  int raw_name_qual_or_unqual = XS_QUAL;
		  int longname_matches_real_name;
		  for (;;)
		    {
		      const char *form;
		      static int base_mask[] = {XS_COM_SIMPLET, XS_COM_COMPLEXT, XS_COM_ATTRGROUP, XS_COM_GROUP, -1};
		      xs_tag_t *basetag;
		      if (NULL == raw_name)
		        break;
		      basetag = xs_find_ancestor_by_component_type (state->da_tag, base_mask);
		      form = xs_get_attr ("form", tag->tag_atts);
		      if (form)
			{
			  ptrlong idx = QUAL__GET_BYNAME (form);
			  if (idx < 0)
			    {
			      xmlparser_logprintf (parser, XCFG_ERROR,
				ECM_MESSAGE_LEN + utf8len (form),
				"[%s] value is not allowed for [form] attribute", form );
			    }
			  else if (NULL == basetag) /* top-level declaration */
			    {
			      xmlparser_logprintf (parser, XCFG_WARNING,
				ECM_MESSAGE_LEN,
				"[form] attribute has no effect on top-level schema component declarations" );
			    }
			  else
			    {
			      raw_name_qual_or_unqual = (qualified_types + idx)->value;
			      break;
			    }
			}
		      if (NULL == basetag) /* top-level declaration */
		        {
		          raw_name_qual_or_unqual = ((NULL == schema->sp_target_ns_uri) ? XS_UNQUAL : XS_QUAL);
		          break;
		        }
		      switch (hashtable_idx)
		        {
		        case XS_SP_ELEMS:
		          raw_name_qual_or_unqual = schema->sp_el_qualified;
		          break;
		        case XS_SP_ATTRS:
		          raw_name_qual_or_unqual = schema->sp_att_qualified;
		          break;
		        }
		      break;
		    }
		  longname_matches_real_name = xs_generate_component_names (parser, raw_name, 1, &longname, &qname, raw_name_qual_or_unqual);
		  xs_comp = add_component_reference (parser, longname, qname, array,
		      &parser->curr_pos, 1);
		  if (0 != xs_comp->cm_version)
		    longname_matches_real_name = 0; /* Versioning suffix makes \c xs_comp->expname different from \c expname */
		  switch (xs_comp->cm_redef_error)
		    {
		    case XS_REDEF_NONE:
		      xs_comp->cm_type.t_major = tag_info->info_compcat;
		      xs_comp->cm_tag = tag;
		      schema_printf (
			  ("schema: start_element_handler %s (%s = %s) >> component init %ld\n",
			      raw_name, qname, longname, tagidx));
		      curr_comp = xs_comp;
		      curr_comp->cm_deflevel |= XS_DEF_DEFINED;
		      break;
		    case XS_REDEF_SYSDEF:
		      xs_set_error (parser, XCFG_WARNING,
			  ECM_MESSAGE_LEN * 2 + utf8len (qname),
			  "Name '%s' is declared as a part of XMLSchema standard; this redefinition has no effect.", qname);
		      goto cleanup;
		    case XS_REDEF_ERROR:
		      xs_set_error (parser, XCFG_FATAL,
			  ECM_MESSAGE_LEN * 2 + utf8len (qname),
			  "Name '%s' is already declared at line %ld of '%s'",
			  qname, xs_comp->cm_definition.line_num,
			  ((NULL == xs_comp->cm_definition.origin_uri) ? parser->cfg.uri : xs_comp->cm_definition.origin_uri)
			  );
		      goto cleanup;
		    }
		  xs_comp->cm_defval = mp_box_string (pool, (char *)xs_get_attr ("default", tag->tag_atts));
		  tag->tag_component = xs_comp;
		  tag->tag_basetag = tag;
		  xsd_fill_mssql_ann (parser, tag, curr_comp);
		  if ((XS_SP_ELEMS == hashtable_idx) && (NULL != raw_name))
		    {
		      caddr_t xmlexpname;
		      dk_set_t *lst;
		      s_node_t *newitem = (s_node_t *)mp_alloc (pool, sizeof (s_node_t));
		      newitem->data = xs_comp;
		      xs_generate_component_names (parser, raw_name, 0, &xmlexpname, NULL, raw_name_qual_or_unqual);
		      xs_comp->cm_elname = xmlexpname;
		      lst = (dk_set_t *)id_hash_get (schema->sp_all_elnames, (caddr_t)&xmlexpname);
		      if (lst)
		        {
		          newitem->next = lst[0];
		          xs_comp->cm_elname_idx = ((xs_component_t *)(lst[0]->data))->cm_elname_idx;
		        }
		      else
		        {
		          newitem->next = NULL;
		          xs_comp->cm_elname_idx = schema->sp_all_elnames_count;
		          id_hash_set (schema->sp_all_elnames, (caddr_t)&xmlexpname, (caddr_t)(&newitem));
		        }
		    }
		  if ((XS_SP_ATTRS == hashtable_idx) && (NULL != raw_name))
		    {
		      caddr_t xmlexpname;
		      xs_generate_component_names (parser, raw_name, 0, &xmlexpname, NULL, raw_name_qual_or_unqual);
		      xs_comp->cm_elname = xmlexpname;
		    }
		}
		break;
	      case XS_REFERENCE:
		{

		  if (parser->validator.dv_depth == 1)
		    xs_set_error(parser, XCFG_ERROR, 200, "Reference is not allowed to be here" );
		  else
		    {
		      const char *cname = xs_get_attr ("ref", tag->tag_atts);
		      caddr_t expname = VXmlFindExpandedNameByQName (parser, cname,
			    ((NULL == schema->sp_target_ns_uri) ? 1 : 0) );
		      id_hash_t *array = schema->sp_hashtables[tag_info->info_sp_hashtable_idx];
		      tag->tag_component_ref = add_component_reference (parser, expname, cname, array,
									&parser->curr_pos, 0);
		      dk_free_box (expname);
		    }
		} /* fall into next case */
	      case XS_SKIP:
		tag->tag_basetag = state[-1].da_tag ? state[-1].da_tag->tag_basetag : NULL;
		break;
	      default:
#ifdef XMLSCHEMA_UNIT_DEBUG
		GPF_T;
#else
		;
#endif
	      }
	      if (NULL != tag_info->info_start_handler)
		(tag_info->info_start_handler) (parser, tag);
	    }
	}
cleanup:
      dk_free_box (element_expname);
      return;
    }
  else
    {
      const char *ns, *final_default, *block_default, *att_qualified, *el_qualified;
      ns = xs_get_attr ("targetNamespace", atts);
      att_qualified = xs_get_attr ("attributeFormDefault", atts);
      el_qualified = xs_get_attr ("elementFormDefault", atts);
      if (ns)
	{
	  dk_free_box (schema->sp_target_ns_uri);
	  schema->sp_target_ns_uri = box_dv_short_string (ns);
	}
      if (NULL != schema->sp_target_ns_uri)
        ecm_add_name (mp_box_string (pool, schema->sp_target_ns_uri), (void **)(&(schema->sp_xecm_namespaces)), &(schema->sp_xecm_namespace_no), sizeof (char *));
      final_default = xs_get_attr ( "finalDefault", atts);
      if (final_default)
	{
	  ptrlong idx = ecm_find_name (final_default, (void*) derivation_types,
				       derivation_types_no, sizeof (derivation_types_t));
	  if (idx < 0)
	    {
	      xmlparser_logprintf (parser, XCFG_WARNING,
		ECM_MESSAGE_LEN + utf8len (final_default),
		"[%s] value is not allowed for [finalDefault] attribute", final_default );
	    }
	  else
	    schema->sp_final_default = (derivation_types + idx)->dts_type;
	}
      block_default = xs_get_attr ( "blockDefault", atts);
      if (block_default)
	{
	  ptrlong idx = ecm_find_name (block_default, (void*) derivation_types,
				       derivation_types_no, sizeof (derivation_types_t));
	  if (idx < 0)
	    {
	      xmlparser_logprintf (parser, XCFG_WARNING,
		ECM_MESSAGE_LEN + utf8len (block_default),
		"[%s] value is not allowed for [blockDefault] attribute", block_default );
	    }
	  else
	    schema->sp_block_default = (derivation_types + idx)->dts_type;
	}
      schema->sp_att_qualified = XS_UNQUAL;
      schema->sp_el_qualified = XS_UNQUAL;
      if (att_qualified)
	{
	  ptrlong idx = QUAL__GET_BYNAME (att_qualified);
	  if (idx < 0)
	    {
	      xmlparser_logprintf (parser, XCFG_ERROR,
		ECM_MESSAGE_LEN + utf8len (att_qualified),
		"[%s] value is not allowed for [attributeFormDefault] attribute", att_qualified );
	    }
	  else
	    schema->sp_att_qualified = (qualified_types + idx)->value;
	}
      if (el_qualified)
	{
	  ptrlong idx = QUAL__GET_BYNAME (el_qualified);
	  if (idx < 0)
	    {
	      xmlparser_logprintf (parser, XCFG_ERROR,
		ECM_MESSAGE_LEN + utf8len (el_qualified),
		"[%s] value is not allowed for [elementFormDefault] attribute", el_qualified );
	    }
	  else
	    schema->sp_el_qualified = (qualified_types + idx)->value;
	}
      xs_add_predefined_types(parser);
      xs_add_predefined_attributes(parser);
    }
}

void
xsd_end_element_handler (void *parser_v, const char * name)
{
  vxml_parser_t *parser = parser_v;
  dtd_astate_t *state = parser->validator.dv_stack + parser->validator.dv_depth;
  schema_printf (("schema: end_element_handler %s ", name));

/*  if (!state->da_el)
    return; */
  schema_printf (("performing\n"));
  if (TAG_ST_ERROR == state[0].da_sstate)
    goto ret;
  if (parser->validator.dv_depth)
    {
      xs_component_t* comp; /* for  attribute or element */
      if ((TAG_ST_ERROR == state[-1].da_sstate) ||
  	  ((ECM_ST_ERROR == state[-1].da_state) && parser->validator.dv_dtd->ed_is_filled) )
	{
	  goto ret;
	}
      if (!state->da_tag)
	goto ret;
      if (state->da_tag->tag_info->info_end_handler)
	(state->da_tag->tag_info->info_end_handler) (parser, state->da_tag);
      comp = state->da_tag->tag_component;
      SHOULD_BE_CHANGED; /* Cleanup will be here */
    }
  else
    {
      if (!parser->processor.sp_schema->sp_is_internal)
	{
	  if (
	    check_unresolved_components (parser, parser->processor.sp_schema->sp_types, "Type") &&
	    check_defvals (parser) &&
	    check_unresolved_components (parser, parser->processor.sp_schema->sp_elems, "Element") &&
	    check_unresolved_components (parser, parser->processor.sp_schema->sp_attrgrps, "Attribute group") &&
	    check_unresolved_components (parser, parser->processor.sp_schema->sp_attrs, "Attribute") &&
	    check_unresolved_components (parser, parser->processor.sp_schema->sp_keys, "Key") &&
	    check_unresolved_components (parser, parser->processor.sp_schema->sp_notations, "notation") )
	    {
	      xecm_create_all_fsas (parser);
	    }
	  /* xs_clear_processor(&parser->processor); no need :) */
	}
    }
ret:
  state->da_tag=0;
}


int check_defvals (vxml_parser_t* parser)
{
  char **name;
  id_hash_iterator_t dict_hit;
  xs_component_t **elem;
  /* check for proper defvalue */
  for (id_hash_iterator(&dict_hit, parser->processor.sp_schema->sp_elems);
    hit_next(&dict_hit,(char**)&name, (char**)&elem);
    /* no step */)
    {
      if (!IS_DEFINED(elem[0]))
	continue;
      if (elem[0]->cm_defval)
	{
	  if (elem[0]->cm_typename &&
	      xs_check_type_compliance (parser, elem[0]->cm_typename, elem[0]->cm_defval, XCFG_NOLOGPLACE))
	    xmlparser_log_cm_location (parser, elem[0], 0);
	}
    }
  return 1;
}

int check_unresolved_components (vxml_parser_t* parser, id_hash_t* hash, const char* metaname)
{ /* checking for unresolved symbols */
  char **dict_key;
  id_hash_iterator_t dict_hit;	/* Iterator to zap dictionary */
  xs_component_t **dict_entry;
  int count = 0;
  int resolved = 1;
  for (id_hash_iterator (&dict_hit, hash);
  hit_next (&dict_hit, (char **) (&dict_key),
      (char **) (&dict_entry));
  /*no step */ )
    {
      xs_component_t *elem = *dict_entry;
      if (!IS_DEFINED(elem))
	{
	  const char *prob_reason = "";
	  if (!strcmp (elem->cm_qname, elem->cm_longname))
	    {
	      if (strrchr (elem->cm_qname, ':'))
		prob_reason = ", maybe due to undeclared namespace prefix";
	      else if (!strrchr (elem->cm_qname, ':') &&
		(-1 != ecm_find_name (elem->cm_qname,
		  (void*) xs_builtin_type_info_dict, xs_builtin_type_info_dict_size, sizeof (xs_builtin_types_info_t) ) ) )
		prob_reason = ", maybe a namespace prefix is forgotten for builtin XMLSchema type";
	    }
	  if (xmlparser_logprintf (parser, XCFG_FATAL | XCFG_NOLOGPLACE,
	      ECM_MESSAGE_LEN + utf8len (elem->cm_qname),
	      "%s '%s' (%s) is not declared%s",
	      metaname,
	      elem->cm_qname, elem->cm_longname,
	      prob_reason) )
	    xmlparser_log_cm_location (parser, elem, 0);
	  resolved = 0;
	}
      schema_printf (("schema dump: element %s type %ld\n", elem->cm_qname,
	  elem->cm_typename));
      count++;
    }
  schema_printf (("schema dump: %d elements\n", count));
  return resolved;
}


void
xsp_start_element_handler (void *parser_v,
    const char * name, vxml_parser_attrdata_t *attrdata)
{
  /*  vxml_parser_t* parser = parser_v; */
}

void
xsp_end_element_handler (void *parser_v, const char * name)
{
  /*  vxml_parser_t* parser = parser_v; */
}


const char *
xs_get_attr (const char *name, /* yes, const */ char **attrs)
{
  while (*attrs)
    {
      if (!utf8cmp (*attrs, name))
	return *(++attrs);
      attrs++;
      attrs++;
    }
  return NULL;
}

/* TAG HANDLERS ----------------------------------------------------------------*/

/* Element component handlers ------------------------------------------------ */
void
xs_tag_pre_element (vxml_parser_t * parser, xs_tag_t * _this)
{
  xs_tag_t *group_or_complext;
  static int pat[] = {XS_COM_GROUP , XS_COM_COMPLEXT, -1};
  group_or_complext = xs_find_ancestor_by_component_type (_this, pat);
  if (group_or_complext)
    {
      set_grp_tree_elems (parser, _this);
/*    schema_printf (("schema: adding to group %s element %s at %s:%d\n",
	      group->tag_component->cm_name, tree_elem->elem_value->cm_name,
	      parser->curr_pos.origin_uri, parser->curr_pos.line_num)); */
    }
  else
    {
      if (NULL == parser->processor.sp_schema->sp_first_element)
	{
	  const char* elname = xs_get_attr ("name", _this->tag_atts);
	  if (NULL != elname)
	    {
	      /*caddr_t expname = VXmlFindExpandedNameByQName (parser, elname,
		((XS_UNQUAL == parser->processor.sp_schema->sp_el_qualified) ? 1 : 0) );*/
	      parser->processor.sp_schema->sp_first_element = mp_box_string (parser->processor.sp_schema->pool, _this->tag_component->cm_longname);
	      /*dk_free_box (expname);*/
	    }
	}
    }
}


void
xs_tag_element (struct vxml_parser_s *parser, xs_tag_t * _this)
{
  schema_parsed_t *schema = parser->processor.sp_schema;
  mem_pool_t *pool = schema->pool;
  xs_component_t* element = _this->tag_component;
  const char* nillable = xs_get_attr ("nillable", _this->tag_atts);
  const char* block = xs_get_attr ("block", _this->tag_atts);
  const char* type = xs_get_attr ("type", _this->tag_atts);
  const char *sg_name = xs_get_attr ("substitutionGroup", _this->tag_atts);
  if (element) /* component declaration */
    {
      /* Element declaration in group definition is not supported yet */
      if (!type)
	{
	  if (!element->cm_typename) /* no definition */
	    {
	      xs_set_error(parser,XCFG_WARNING,200+utf8len(element->cm_qname),
		  "No type definition in element <%s> declaration, built-in [xsd:string] will be used",
		  element->cm_qname );
	      element->cm_typename = xs_get_builtinidx (parser, NULL, "string", 1);
	    }
	}
      else
	{
	  caddr_t expname;
	  if (element->cm_typename) /* double definition */
	    {
	      xs_set_error(parser,XCFG_ERROR,200+utf8len(element->cm_qname),
		  "Attribute 'type' conflicts with other type definition for element <%s>",
		  element->cm_qname );
	      SHOULD_BE_CHANGED;
	      /* GPF_T1("call customer support"); */
	    }
	  expname = VXmlFindExpandedNameByQName (parser, type,
	    ((NULL == parser->processor.sp_schema->sp_target_ns_uri) ? 1 : 0) );
	  element->cm_typename = xs_get_builtinidx (parser, expname, type, 1);
	  dk_free_box (expname);
	}
      if (sg_name)
        {
	  caddr_t sg_expname = VXmlFindExpandedNameByQName (parser, sg_name,
	    ((NULL == parser->processor.sp_schema->sp_target_ns_uri) ? 1 : 0) );
          xs_component_t* sg_comp = add_component_reference (parser, sg_expname, sg_name, schema->sp_elems, &parser->curr_pos, 0);
          mp_set_push (pool, &(sg_comp->cm_subst_group), element);
          dk_free_box (sg_expname);
        }
      if (nillable && is_attr_boolean (nillable, 1))
	INFO_ELEMENT (element).is_nillable = 1;
      if (block)
	{
	  ptrlong idx = ecm_find_name (block, (void*) derivation_el_types,
				       derivation_el_types_no, sizeof (derivation_types_t));
	  if (idx < 0)
	    {
	      xmlparser_logprintf (parser, XCFG_WARNING,
			     ECM_MESSAGE_LEN + utf8len (block),
			     "[%s] value is not allowed for [block] attribute", block );
	    }
	  else
	    INFO_ELEMENT (element).block = (derivation_el_types + idx)->dts_type;
	}
    }
}

/* Type component handlers -------------------------------------------------------- */

void
xs_tag_pre_cstype (vxml_parser_t * parser, xs_tag_t * _this)
{
  const char* base, *is_mixed, *final, *block;
  const derivation_types_t * der_types = (_this->tag_info->info_tagid == XS_TAG_COMPLEX_TYPE) ?
    derivation_types : derivation_simple_types;
  ptrlong der_types_no =  (_this->tag_info->info_tagid == XS_TAG_COMPLEX_TYPE) ?
    derivation_types_no : derivation_simple_types_no;

  set_grp_root_element (parser, _this);
  base=xs_get_attr ( "base", _this->tag_atts);
  is_mixed=xs_get_attr ( "mixed", _this->tag_atts);
  final=xs_get_attr ( "final", _this->tag_atts);
  block=xs_get_attr ( "block", _this->tag_atts);

  if (base) /* base type reference */
    {
      caddr_t expname = VXmlFindExpandedNameByQName (parser, base,
	((NULL == parser->processor.sp_schema->sp_target_ns_uri) ? 1 : 0) );
      _this->tag_component->cm_typename =
	  xs_get_builtinidx (parser, expname, base, 1);
      dk_free_box (expname);
    }
  if (is_mixed)
    INFO_CSTYPE(_this->tag_component).pcdata_mode = (
      strcmp (is_mixed, "true") ? XS_PCDATA_PROHIBITED : XS_PCDATA_ALLOWED );
  else if (IS_SIMPLE_TYPE(_this->tag_component))
    INFO_CSTYPE(_this->tag_component).pcdata_mode = XS_PCDATA_TYPECHECK;
  /* set finalDefault & blockDefault up */
  if (parser->processor.sp_schema->sp_final_default)
    INFO_CSTYPE (_this->tag_component).final = parser->processor.sp_schema->sp_final_default;
  if (parser->processor.sp_schema->sp_block_default)
    INFO_CSTYPE (_this->tag_component).block = parser->processor.sp_schema->sp_block_default;
  if (final)
    {
      ptrlong idx = ecm_find_name (final, (void*) der_types,
		der_types_no, sizeof (derivation_types_t));
      if (idx < 0)
	{
	  xmlparser_logprintf (parser, XCFG_WARNING,
		ECM_MESSAGE_LEN + utf8len (final),
		"[%s] value is not allowed for [final] attribute", final );

	}
      else
	INFO_CSTYPE (_this->tag_component).final = (der_types + idx)->dts_type;
    }
  if (block)
    {
      ptrlong idx = ecm_find_name (block, (void*) der_types,
		der_types_no, sizeof (derivation_types_t));
      if (idx < 0)
	{
	  xmlparser_logprintf (parser, XCFG_WARNING,
		ECM_MESSAGE_LEN + utf8len (block),
		"[%s] value is not allowed for [block] attribute", block );

	}
      else
	INFO_CSTYPE (_this->tag_component).block = (der_types + idx)->dts_type;
    }

}

void
xs_tag_cstype (vxml_parser_t * parser, xs_tag_t * _this)
{
  xs_component_t *elem;
  xs_component_t *type = _this->tag_component;
#ifdef XMLSCHEMA_UNIT_DEBUG
  if ((_this->tag_info->info_tagid == XS_TAG_COMPLEX_TYPE) && !_this->temp.grp_tree && strcmp ("anyType", xs_get_attr ("name", _this->tag_atts)))
      GPF_T;
  if ((_this->tag_info->info_tagid != XS_TAG_COMPLEX_TYPE) && _this->temp.grp_tree)
      GPF_T;
#endif

  elem = YOUNGEST_COMPONENT (_this);

  schema_printf (("schema: cs type %d processing... ", _this->tag_info->info_tagid));

  if (_this->tag_base && (XS_TAG_RESTRICTION == _this->tag_base->tag_info->info_tagid))
    {  /* I could not understand anything */
      if (elem)
	elem->cm_typename = type;
#ifdef XMLSCHEMA_UNIT_DEBUG
      else
	GPF_T;  SHOULD_BE_CHANGED;
#endif
      schema_printf ((" typename %s = %s\n", type->cm_qname, type->cm_longname));
      schema_printf ((" done\n"));
      goto set;

    };

  if (elem)
    {
      switch (elem->cm_type.t_major)
	{
	case XS_COM_ATTRIBUTE:	/* typename is a first member in structures element & attribute */
	case XS_COM_ELEMENT:
	case XS_COM_SIMPLET:
	case XS_COM_COMPLEXT:
	  if (!elem->cm_typename)
	    {
	      elem->cm_typename = type;
	    }
	  break;
	default:
#ifdef XMLSCHEMA_UNIT_DEBUG
	  GPF_T;
	  SHOULD_BE_CHANGED;
#else
	  ;
#endif
	}
    };
  /* setting up model group definition */
set:
  if (!elem && _this->temp.grp_tree)
    _this->temp.grp_tree = xecm_advance_tree (parser, _this->temp.grp_tree);

  if ((NULL != type) && _this->temp.grp_tree)
    INFO_CSTYPE(type).lg_group=_this->temp.grp_tree;


  SHOULD_BE_CHANGED;
/*  xs_tag_free (_this); */
  if (type)
    schema_printf ((" typename %s = %s\n", type->cm_qname, type->cm_longname));
  else
    schema_printf ((" NULL typename"));
  schema_printf ((" done\n"));
#ifdef XMLSCHEMA_UNIT_DEBUG
  if(_this->temp.grp_tree)
    grp_print_tree(_this->temp.grp_tree,0,"");
#endif
  return ;
}


void
xs_tag_pre_restrict (struct vxml_parser_s* parser, xs_tag_t* _this)
{
  penetrate_grp_elems (_this);
}

void
xs_tag_restrict (struct vxml_parser_s *parser, xs_tag_t * _this)
{
  xs_component_t *sbase = YOUNGEST_COMPONENT (_this);
  const char *base;		/* base name */

  schema_printf (("schema: restriction processing %d... ", _this->tag_info->info_tagid));
  base = xs_get_attr ("base", _this->tag_atts);

  if (!sbase->cm_typename)
    {
      if (base)
	{
	  caddr_t expname = VXmlFindExpandedNameByQName (parser, base,
	    ((NULL == parser->processor.sp_schema->sp_target_ns_uri) ? 1 : 0) );
	  sbase->cm_typename = xs_get_builtinidx (parser, expname, base, 1);
	  dk_free_box (expname);
	  goto ok;
	}
    }
  if (base && sbase->cm_typename)
    {
      xmlparser_logprintf (parser, XCFG_ERROR,
	  ECM_MESSAGE_LEN + utf8len (sbase->cm_qname) +
	  strlen (XS_FIXSTRING (parser->curr_pos.origin_uri)),
	  "'simpleType' child of <%s> conflicts with the 'base' attribute of the same element",
	  sbase->cm_qname );
      return ;
    }
ok:
  sbase->cm_derivation = XS_DER_RESTRICTION;
  schema_printf ((" done\n"));
  return ;
}


void
xs_tag_pre_list (struct vxml_parser_s* parser, xs_tag_t* _this)
{
  penetrate_grp_elems (_this);
}


void
xs_tag_list (struct vxml_parser_s *parser, xs_tag_t * _this)
{
  xs_component_t *sbase = YOUNGEST_COMPONENT (_this);
  const char *itemtype;		/* base name */

  schema_printf (("schema: list processing %d... ", _this->tag_info->info_tagid));
  itemtype = xs_get_attr ("itemType", _this->tag_atts);

  if (!sbase->cm_typename)
    {
      if (itemtype)
	{
	  caddr_t expname = VXmlFindExpandedNameByQName (parser, itemtype,
	    ((NULL == parser->processor.sp_schema->sp_target_ns_uri) ? 1 : 0) );
	  sbase->cm_typename = xs_get_builtinidx (parser, expname, itemtype, 1);
	  dk_free_box (expname);
	  goto ok;
	}
    }
  if (itemtype && sbase->cm_typename)
    {
      xmlparser_logprintf (parser, XCFG_ERROR,
	  ECM_MESSAGE_LEN + utf8len (sbase->cm_qname) +
	  strlen (XS_FIXSTRING (parser->curr_pos.origin_uri)),
	  "'simpleType' child of <%s> conflicts with the 'base' attribute of the same element",
	  sbase->cm_qname );
      return ;
    }
ok:
  sbase->cm_derivation = XS_DER_LIST;
  schema_printf ((" done\n"));
  return ;
}


void
xs_tag_pre_union (struct vxml_parser_s* parser, xs_tag_t* _this)
{
  penetrate_grp_elems (_this);
}


void
xs_tag_union (struct vxml_parser_s *parser, xs_tag_t * _this)
{
  xs_component_t *sbase = YOUNGEST_COMPONENT (_this);
  const char *itemtype;		/* base name */

  schema_printf (("schema: union processing %d... ", _this->tag_info->info_tagid));
  itemtype = xs_get_attr ("itemType", _this->tag_atts);

  if (!sbase->cm_typename)
    {
      if (itemtype)
	{
	  caddr_t expname = VXmlFindExpandedNameByQName (parser, itemtype,
	    ((NULL == parser->processor.sp_schema->sp_target_ns_uri) ? 1 : 0) );
	  sbase->cm_typename = xs_get_builtinidx (parser, expname, itemtype, 1);
	  dk_free_box (expname);
	  goto ok;
	}
    }
  if (itemtype && sbase->cm_typename)
    {
      xmlparser_logprintf (parser, XCFG_ERROR,
	  ECM_MESSAGE_LEN + utf8len (sbase->cm_qname) +
	  strlen (XS_FIXSTRING (parser->curr_pos.origin_uri)),
	  "'simpleType' child of <%s> conflicts with the 'base' attribute of the same element",
	  sbase->cm_qname );
      return ;
    }
ok:
  sbase->cm_derivation = XS_DER_UNION;
  schema_printf ((" done\n"));
  return ;
}


/*
0  default = string
1  fixed = string
2  form = (qualified | unqualified)
3  id = ID
4  name = NCName
5  ref = QName
6  targetNamespace (tn)
7  type = QName
8  use = (optional | prohibited | required)
9  __SCHEMA_IS_PARENT
10  __SCHEMA_IS_NOT_PARENT
11 noref
#defene ATTR_ATTR_STATES_NUM
*/

const char * attr_attr_strs[] =
{ "default", "fixed", "form", "id", "name", "ref", "targetNamespace", "type", "use"};
#define _SCHEMA_IS_PARENT_AT	9
#define _SCHEMA_ISNOT_PARENT_AT 10
#define _NOREF_AT		11

const int attr_attr_strs_no = sizeof (attr_attr_strs) / sizeof (char*);
#define  ATTR_ATTR_STATES_NUM  (sizeof (attr_attr_strs) / sizeof (char*) + 3) /* schema + not schema + noref */

int attr_attr_states[][ATTR_ATTR_STATES_NUM] =
{ /*	default	fixed	form	id	name	ref	tn	type	use	_ISP	_ISNOT	nor */
  {/* 0 */-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	-1,	1,	3,	-1},
  {/* 1 */-1,	-1,	-1,	-1,	2,	-1,	-1,	-1,	-1,	-1,	-1,	-1},
  {/* 2 */2,	2,	2,	-1,	2,	-1,	2,	2,	-1,	-1,	-1,	-1},
  {/* 3 */-1,	-1,	-1,	-1,	6,	4,	-1,	-1,	-1,	-1,	-1,	5},
  {/* 4 */4,	4,	-1,	-1,	-1,	4,	-1,	-1,	4,	-1,	-1,	-1},
  {/* 5 */5,	5,	5,	-1,	-1,	-1,	5,	5,	5,	-1,	-1,	-1},
  {/* 6 */6,	6,	6,	-1,	6,	-1,	6,	6,	6,	-1,	-1,	-1},
};

/* Attribute ---------------------------------------------------------*/

/* \return value less than 0 if it is not OK */
int xs_check_attr_attr_fsm (vxml_parser_t * parser, ptrlong curr_attr_st, char ** atts)
{
  int idx = 0;
  const char* attr_str = atts ? atts[0] : 0;
  ptrlong curr_state = curr_attr_st;
  ptrlong curr_attr_idx;

  if (!attr_str)
    return 0;

  if (parser->validator.dv_depth == 1) /* schema is parent */
    curr_attr_idx = _SCHEMA_IS_PARENT_AT;
  else
    curr_attr_idx = _SCHEMA_ISNOT_PARENT_AT;

  /* first step */
  curr_state = attr_attr_states[curr_state][curr_attr_idx];
  if (curr_attr_idx < 0)
    return -1;

  /* second step - ref, noref, name */
  if (xs_get_attr ( "name", atts))
    curr_attr_idx = ecm_find_name (attr_str, (void **) attr_attr_strs,
				   attr_attr_strs_no, sizeof (char*));
  else if (xs_get_attr ( "ref", atts))
    curr_attr_idx = ecm_find_name (attr_str, (void **) attr_attr_strs,
				   attr_attr_strs_no, sizeof (char*));
  else
    curr_attr_idx = _NOREF_AT;

  /* stage three */
  while (curr_state >= 0)
    {
      curr_state = attr_attr_states[curr_state][curr_attr_idx];
      if (curr_state < 0)
	break;
    next_attr:
      ++idx; ++idx;
      attr_str = atts[idx];
      if (!attr_str)
	break;
      curr_attr_idx = ecm_find_name (attr_str, (void **) attr_attr_strs,
				     attr_attr_strs_no, sizeof (char*));
      if (curr_attr_idx < 0)
	goto next_attr;
    }
  if (curr_state < 0)
    {
      if (curr_attr_idx < attr_attr_strs_no)
	{
	  xs_set_error (parser, XCFG_FATAL, 200 + strlen(attr_attr_strs[curr_attr_idx]),
		       "Attribute [%s] could not appear here (see 3.2.2 XML Schema Part 1: Structures)",
		       attr_attr_strs[curr_attr_idx] );
	}
      else
	{
	  xs_set_error(parser, XCFG_FATAL, 200,
		       "Attribute [name] is needed here (see 3.2.2 XML Schema Part 1: Structures)" );
	}
      return -1;
    }
  return 0;
}

void
xs_tag_attribute (struct vxml_parser_s *parser, xs_tag_t * _this)
{
  xs_component_t* attrtype;
  const char *_typename = xs_get_attr ("type", _this->tag_atts);
  const char *_use = xs_get_attr ("use", _this->tag_atts);
  const char *_fixed = xs_get_attr ("fixed", _this->tag_atts);
  const char *_default = xs_get_attr ("default", _this->tag_atts);
  xs_component_t* attr = _this->tag_component;
  xs_tag_t* basetag;
  static int pat[] = {XS_COM_COMPLEXT , XS_COM_SIMPLET , XS_COM_ATTRGROUP, -1};
  int curr_attr_st = 0;

  if (xs_check_attr_attr_fsm (parser, curr_attr_st, _this->tag_atts) < 0)
    return;

  /* schema_printf (("schema: processing attribute %s\n", _this->tag_component->cm_name)); */
  if (_this->tag_component_ref)
    {
#if 0
      xs_set_error(parser,XCFG_ERROR,200,
	"References are not allowed for attributes" );
#endif
      basetag = xs_find_ancestor_by_component_type (_this, pat);
      if (basetag) /* reference */
	xs_add_attribute (basetag, _this->tag_component_ref);
      return ;
    }
  else if (!attr)
    {
      xs_set_error (parser, XCFG_ERROR, 200,
	"Attribute must have either \"name\" or \"ref\"" );
      return;
    }
  if (_default)
    {
      xs_set_error (parser, XCFG_WARNING, 200 + strlen(attr->cm_qname),
	"\"default\" is not supported (and ignored) in attribute <%s> declaration", attr->cm_qname );
    }
  if (_typename)
    {
      caddr_t expname;
      if (attr->cm_typename)	/* duplicate declaration */
	{
	  xs_set_error (parser, XCFG_ERROR, 200 + strlen(attr->cm_qname),
	    "Double definition in attribute <%s> declaration", attr->cm_qname );
	  return ;
	}
      expname = VXmlFindExpandedNameByQName (parser, _typename,
	((NULL == parser->processor.sp_schema->sp_target_ns_uri) ? 1 : 0) );
      attrtype = xs_get_builtinidx (parser, expname, _typename, 1);
      dk_free_box (expname);
      attr->cm_typename = attrtype;
    }
  if (_use)
    { /* here (optional | prohibited | required) could appear only due to DTD */
      switch (_use[0])
      {
      case 'o': /* optional */
	  INFO_ATTRIBUTE(attr).use = XS_ATTRIBUTE_USE_OPT;
	  break;
      case 'p': /* prohibited */
	  INFO_ATTRIBUTE(attr).use = XS_ATTRIBUTE_USE_PRH;
	  break;
      case 'r': /* required */
	  INFO_ATTRIBUTE(attr).use = XS_ATTRIBUTE_USE_REQ;
      }
    }
  if (!_typename)
    {
      if (!attr->cm_typename)	/* no definition */
	{
	  if (attr->cm_defval || (XS_ATTRIBUTE_USE_PRH != INFO_ATTRIBUTE(attr).use))
	    {
	      xs_set_error(parser,XCFG_WARNING,200+strlen(attr->cm_qname),
		"Unknown type for attribute <%s>, [xs:string] type is set",attr->cm_qname );
	    }
	  attr->cm_typename = xs_get_builtinidx (parser, NULL, "string", 1);
	/*  return ; */
	}
    }
  if (attr->cm_defval && _fixed)
    xmlparser_logprintf (parser, XCFG_WARNING, 200,
      "Both default and fixed values are presented, fixed value is ignored" );
  else if (_fixed)
    INFO_ATTRIBUTE(attr).fixval = box_dv_short_string(_fixed);
  basetag = xs_find_ancestor_by_component_type (_this, pat);
  if (basetag) /* reference */
    xs_add_attribute (basetag, attr);
  xsd_fill_mssql_ann (parser, _this, attr);
}
/* Attribute Group -----------------------------------------------------*/

void xs_add_attribute(xs_tag_t* basetag, xs_component_t* attr)
{
  switch (basetag->tag_info->info_tagid)
  {
  case XS_TAG_COMPLEX_TYPE:
  case XS_TAG_SIMPLE_TYPE:
    {
      XS_ASSERT(basetag->tag_component);
      dk_set_push(&INFO_CSTYPE(basetag->tag_component).lg_agroup, (void*)attr);
    }
      break;
  case XS_TAG_ATTRGROUP:
      XS_ASSERT(basetag->tag_component);
      dk_set_push(&INFO_ATTRGROUP(basetag->tag_component).lg_agroup, (void*)attr);
      break;
  default:
#ifdef XMLSCHEMA_UNIT_DEBUG
      GPF_T;
#else
      ;
#endif
  }
}

void
xs_tag_pre_attgroup (vxml_parser_t * parser, xs_tag_t * _this)
{
  xs_component_t* attgroup = _this->tag_component_ref;
  if (attgroup) /* reference */
    {
      static int pat[] = {XS_COM_COMPLEXT , XS_COM_SIMPLET , XS_COM_ATTRGROUP, -1};
      xs_tag_t* basetag = xs_find_ancestor_by_component_type (_this, pat);
      if (basetag)
	xs_add_attribute(basetag, attgroup);
    }
}
void
xs_tag_attgroup (vxml_parser_t * parser, xs_tag_t * _this)
{
}

/* AnyAttribute --------------------------------------------------------*/
void
xs_tag_anyattribute (vxml_parser_t * parser, xs_tag_t * _this)
{
  const char* namespace_ = xs_get_attr ("namespace", _this->tag_atts);
  const char* processcontent = xs_get_attr ("processContent", _this->tag_atts);
  static int pat[] = {XS_COM_COMPLEXT , XS_COM_SIMPLET , XS_COM_ATTRGROUP, -1};
  xs_tag_t* basetag = xs_find_ancestor_by_component_type (_this, pat);
  if (basetag)
    {
      int invert = 0;
      xs_any_attr_ns any_attr_ns;
      XS_ANY_ATTR_OP any_attr;
      if (!namespace_)
	any_attr_ns = XS_ANY_ATTR_NS_ANY;
      else if (!strcmp(namespace_, "##any"))
	any_attr_ns = XS_ANY_ATTR_NS_ANY;
      else if (!strcmp(namespace_, "##other"))
	{
	  any_attr_ns = box_dv_short_string (parser->processor.sp_schema->sp_target_ns_uri);
	  invert = 1;
	}
      else if (!strcmp(namespace_, "##local"))
	any_attr_ns = XS_ANY_ATTR_NS_LOCAL;
      else if (!strcmp(namespace_, "##targetNamespace"))
	any_attr_ns = box_dv_short_string (parser->processor.sp_schema->sp_target_ns_uri);
      else
	any_attr_ns = (xs_any_attr_ns) box_dv_short_string (namespace_);

      if (!processcontent) /* default */
	any_attr = XS_ANY_ATTR_ERROR;
      else if (!strcmp (processcontent, "skip"))
	any_attr = XS_ANY_ATTR_SKIP;
      else if (!strcmp (processcontent, "lax"))
	any_attr = XS_ANY_ATTR_SKIP;
      else if (!strcmp (processcontent, "strict"))
	any_attr = XS_ANY_ATTR_ERROR;
      else /* warning */
	{
	  xmlparser_logprintf (parser, XCFG_WARNING,
			 ECM_MESSAGE_LEN + strlen (processcontent),
			 "Unsupported processContent argument value %s, strict is used.",
			 processcontent );
	  any_attr = XS_ANY_ATTR_ERROR;
	}
      if (invert)
        {
          if (XS_ANY_ATTR_ERROR == any_attr)
	    any_attr = XS_ANY_ATTR_ERROR_WITH_OTHER;
	  else if (XS_ANY_ATTR_SKIP == any_attr)
	    any_attr = XS_ANY_ATTR_SKIP_WITH_OTHER;
	}
      XS_CM_TYPE(basetag->tag_component).any_attribute = any_attr;
      XS_CM_TYPE(basetag->tag_component).any_attr_ns = any_attr_ns;
    }
}

/* Simple facets -------------------------------------------------------*/
void
xs_tag_pre_simplefacet (vxml_parser_t * parser, xs_tag_t * _this)
{
/* This is unused for a while
  ptrlong facet_id = _this->tag_info->info_facetid;
  xs_component_t *c = YOUNGEST_COMPONENT (_this);
  xs_add_facet (parser, c, facet_id, xs_get_attr ("value", _this->tag_atts));
  return ;
*/
}

/* Model Group handlers ------------------------------------------------*/
void
xs_tag_pre_group (vxml_parser_t * parser, xs_tag_t * _this)
{
  if (_this->tag_component) /* Group definition */
    set_grp_root_element (parser, _this);
  else /* Group reference */
    set_grp_tree_elems (parser, _this);
}
void
xs_tag_group (vxml_parser_t * parser, xs_tag_t * _this)
{
  xs_component_t * group = _this->tag_component;
  if (group && _this->temp.grp_tree)
    INFO_GROUP(group).grp_tree=_this->temp.grp_tree;
}

void
xs_tag_pre_all (vxml_parser_t * parser, xs_tag_t * _this)
{
  set_grp_tree_elems (parser, _this);
}
void
xs_tag_all (vxml_parser_t * parser, xs_tag_t * _this)
{
}

void
xs_tag_pre_choice (vxml_parser_t * parser, xs_tag_t * _this)
{
  set_grp_tree_elems (parser, _this);
}
void
xs_tag_choice (vxml_parser_t * parser, xs_tag_t * _this)
{
}
void
xs_tag_pre_sequence (vxml_parser_t * parser, xs_tag_t * _this)
{
  set_grp_tree_elems (parser, _this);
}
void
xs_tag_sequence (vxml_parser_t * parser, xs_tag_t * _this)
{
}
void
xs_tag_pre_any (vxml_parser_t * parser, xs_tag_t * _this)
{
  set_grp_tree_elems (parser, _this);
}
void
xs_tag_any (vxml_parser_t * parser, xs_tag_t * _this)
{
}

/* Complex content handlers */
void
xs_tag_pre_complexcontent (vxml_parser_t * parser, xs_tag_t * _this)
{
  penetrate_grp_elems (_this);
}

void
xs_tag_pre_simplecontent (vxml_parser_t * parser, xs_tag_t * _this)
{
  penetrate_grp_elems (_this);
}

void
xs_tag_pre_extension (vxml_parser_t * parser, xs_tag_t * _this)
{
  static int pat[] = {XS_COM_COMPLEXT , XS_COM_SIMPLET, -1};
  xs_tag_t* basetag = xs_find_ancestor_by_component_type (_this, pat);
  penetrate_grp_elems (_this);
  basetag->tag_component->cm_derivation = XS_DER_EXTENSION;
}
void
xs_tag_extension (vxml_parser_t * parser, xs_tag_t * _this)
{
  xs_component_t *sbase = YOUNGEST_COMPONENT (_this);
  const char *base;		/* base name */

  schema_printf (("schema: extension processing %ld... ", (long)(_this->tag_info->info_tagid)));
  base = xs_get_attr ("base", _this->tag_atts);

  if (!sbase->cm_typename)
    {
      if (base)
	{
	  caddr_t expname = VXmlFindExpandedNameByQName (parser, base,
	    ((NULL == parser->processor.sp_schema->sp_target_ns_uri) ? 1 : 0) );
	  sbase->cm_typename = xs_get_builtinidx (parser, expname, base, 1);
	  dk_free_box (expname);
	  if (!sbase->cm_typename)
	    {
	      if (xmlparser_logprintf (parser, XCFG_ERROR | XCFG_NOLOGPLACE,
		  ECM_MESSAGE_LEN + utf8len (base),
		  "Invalid base type name <%s>", base) )
	        xmlparser_log_cm_location (parser, sbase, 0);
	      return ;
	    }
	  goto ok;
	}
    }
  if (base && sbase->cm_typename)
    {
      xmlparser_logprintf (parser, XCFG_ERROR,
	  ECM_MESSAGE_LEN + utf8len (sbase->cm_qname) +
	  strlen (XS_FIXSTRING (parser->curr_pos.origin_uri)),
	  "Either the base [attribute] or the simpleType [child] or the complexType [child] must be present at <%s>, but no more than one of them",
	  sbase->cm_qname );
      return ;
    }
ok:
  sbase->cm_derivation = XS_DER_EXTENSION;
  schema_printf ((" done\n"));
  return ;

}


void /* including external document */
xs_tag_include (vxml_parser_t * parser, xs_tag_t * _this)
{
  const char* external_doc_name =
      xs_get_attr ("schemaLocation", _this->tag_atts);
  if (XCFG_ENABLE == parser->validator.dv_curr_config.dc_build_standalone)
    load_external_schema (parser, external_doc_name, 1);
}


void /* importing external namespaces */
xs_tag_import (vxml_parser_t * parser, xs_tag_t * _this)
{
  const char* external_doc_name =
      xs_get_attr ("schemaLocation", _this->tag_atts);
#if 0 /* it is unused */
  const char* xs_namespace =
      xs_get_attr ("namespace", _this->tag_atts);
#endif
  if ((XCFG_ENABLE == parser->validator.dv_curr_config.dc_build_standalone) &&
      external_doc_name)
    load_external_schema (parser, external_doc_name, 1);
}

void /* redefine mode, include the document and switch to redefine mode */
xs_tag_pre_redefine (vxml_parser_t * parser, xs_tag_t * _this)
{
  const char* external_doc_name =
      xs_get_attr ("schemaLocation", _this->tag_atts);
  if (XCFG_ENABLE == parser->validator.dv_curr_config.dc_build_standalone)
    {
      load_external_schema (parser, external_doc_name, 1);
      parser->processor.sp_schema->sp_redefine_mode = 1;
    }
}


void /* switch off redefine mode */
xs_tag_redefine (vxml_parser_t * parser, xs_tag_t* _this)
{
  parser->processor.sp_schema->sp_redefine_mode = 0;
}
/* Uniqueness handlers ----------------------------------------------------*/

void xs_tag_pre_key (vxml_parser_t* parser, xs_tag_t* tag)
{
  INFO_KEY(tag->tag_component).keytype = XSK_KEY;
}


void xs_tag_pre_unique (vxml_parser_t* parser, xs_tag_t* tag)
{
  INFO_KEY(tag->tag_component).keytype = XSK_UNIQUE;
}


void xs_tag_selector (vxml_parser_t* parser, xs_tag_t* tag)
{
  const char* xpath_text = xs_get_attr ("xpath", tag->tag_atts);
  if (xpath_text)
    { /* xpath checking should be here */
      switch (tag->tag_base->tag_info->info_tagid)
      {
      case XS_TAG_UNIQUE:
      case XS_TAG_KEY:
	{
	  INFO_KEY(tag->tag_base->tag_component).xpath_selector = box_dv_short_string(xpath_text);
	} break;
      case XS_TAG_KEYREF:
	{
	  elm_keyref_t* kr = tag->tag_base->temp.elm_keyref;
	  kr->kr_selector = box_dv_short_string(xpath_text);
	} break;
      default:
#ifdef XMLSCHEMA_UNIT_DEBUG
	  GPF_T;
#else
	  ;
#endif
      }
    }
}


void xs_tag_field (vxml_parser_t* parser, xs_tag_t* tag)
{
  const char* xpath_field = xs_get_attr ("xpath", tag->tag_atts);
  ptrlong idx = 0;
  if (xpath_field)
    { /* xpath checking should be here */
      switch (tag->tag_base->tag_info->info_tagid)
      {
      case XS_TAG_UNIQUE:
      case XS_TAG_KEY:
	{
	  void ** array = (void**) &INFO_KEY(tag->tag_base->tag_component).xpath_fields;
	  ptrlong * array_no = &INFO_KEY(tag->tag_base->tag_component).xpath_fields_no;
#if 0
	  ptrlong idx = ecm_add_name (xpath_field, array, array_no, sizeof (char*));
#else
	  ecm_add_name (xpath_field, array, array_no, sizeof (char*));
#endif

	} break;
      case XS_TAG_KEYREF:
	{
	  elm_keyref_t* kr = tag->tag_base->temp.elm_keyref;
#if 0
	  ptrlong idx = ecm_add_name (xpath_field, (void**) &kr->kr_fields, &kr->kr_fields_no, sizeof(elm_keyref_t));
#else
	  ecm_add_name (xpath_field, (void**) &kr->kr_fields, &kr->kr_fields_no, sizeof(elm_keyref_t));
#endif

	} break;
      default:
#ifdef XMLSCHEMA_UNIT_DEBUG
	  GPF_T;
#else
	  ;
#endif
      }
      if (-1 == idx)
	{ /* error, duplicate fields */
	  xs_set_error (parser, XCFG_ERROR, 100 + utf8len (xpath_field),
	    "Duplicate field names <%s> in key declaration", xpath_field );
	}
    }
}


void xs_tag_pre_keyref (vxml_parser_t* parser, xs_tag_t* tag)
{
  const char* refer = xs_get_attr ("refer", tag->tag_atts);
  tag->temp.elm_keyref = dk_alloc(sizeof(elm_keyref_t));
  memset(tag->temp.elm_keyref,0,sizeof(elm_keyref_t));
  if (refer)
    {
      caddr_t expname = VXmlFindExpandedNameByQName (parser, refer,
	((NULL == parser->processor.sp_schema->sp_target_ns_uri) ? 1 : 0) );
      xs_component_t * elem = add_component_reference (parser, expname, refer,
	  parser->processor.sp_schema->sp_keys, &parser->curr_pos, 0);
      dk_free_box (expname);
      tag->temp.elm_keyref->kr_refer = elem;
    }
}
void xs_tag_keyref(vxml_parser_t* parser, xs_tag_t* tag)
{
  elm_keyref_t* kr = tag->temp.elm_keyref;
  static int pat[] = {XS_COM_ELEMENT, -1};
  xs_tag_t* elem_tag = xs_find_ancestor_by_component_type (tag, pat);
#ifdef XMLSCHEMA_UNIT_DEBUG
  if (!elem_tag)
    GPF_T;
#endif
  dk_set_push(&INFO_ELEMENT(elem_tag->tag_component).keyrefs, (void*) kr);
}


void xs_tag_pre_notation (vxml_parser_t* parser, xs_tag_t* tag)
{
  INFO_NOTATION(tag->tag_component).pub_uri = box_copy ((caddr_t)xs_get_attr ("public", tag->tag_atts));
  INFO_NOTATION(tag->tag_component).sys_uri = box_copy ((caddr_t)xs_get_attr ("system", tag->tag_atts));
}


/* stubs */

#if 0 /* Now unused. */
void xs_unsupported_handler (struct vxml_parser_s* parser, xs_tag_t* _this)
{
  xs_set_error (parser, XCFG_ERROR, 100 + utf8len (_this->tag_info->info_name),
    "Tag %s is not supported", _this->tag_info->info_name);
  /* state->da_sstate = TAG_ST_ERROR; -- set in xs_set_error */
}
#endif

void xs_tag_pre_annotation (vxml_parser_t* parser, xs_tag_t* _this)
{
}


void xs_tag_pre_appinfo (vxml_parser_t* parser, xs_tag_t* _this)
{
}

void xs_tag_pre_documentation (vxml_parser_t* parser, xs_tag_t* _this)
{
  dtd_astate_t *state = parser->validator.dv_stack + parser->validator.dv_depth;
  state->da_sstate = TAG_ST_ERROR; /* To prevent inner tags from processing */
}

/* MSSQL extensions */
void
xs_tag_mssql_rship (vxml_parser_t * parser, xs_tag_t * _this)
{
  const char *name = xs_get_attr ("name", _this->tag_atts);
  const char *parent = xs_get_attr ("parent", _this->tag_atts);
  const char *parent_key = xs_get_attr ("parent-key", _this->tag_atts);
  const char *child = xs_get_attr ("child", _this->tag_atts);
  const char *child_key = xs_get_attr ("child-key", _this->tag_atts);
  caddr_t expname;
  xs_component_t *rel;
  expname = VXmlFindExpandedNameByQName (parser, name,
    ((NULL == parser->processor.sp_schema->sp_target_ns_uri) ? 1 : 0) );
  rel = add_component_reference (
    parser, expname, name, parser->processor.sp_schema->sp_mssql_rships,
    &parser->curr_pos, 0);
  dk_free_box (expname);
  if ((NULL == parent) || (NULL == parent_key))
    GPF_T;
  if ((NULL == child) || (NULL == child_key))
    GPF_T;
  rel->cm_type.spec.mssql_rship.parent = box_dv_short_string (parent);
  rel->cm_type.spec.mssql_rship.parent_keys = (char **)list_to_array (xs_attr_val_to_idrefs (parent_key));
  rel->cm_type.spec.mssql_rship.child = box_dv_short_string (child);
  rel->cm_type.spec.mssql_rship.child_keys = (char **)list_to_array (xs_attr_val_to_idrefs (child_key));
}

/* End of tag handlers */

void
xml_schema_init ()
{
  xml_sys_path_list = dk_alloc (sizeof (xml_syspath_t));
  memset (xml_sys_path_list, 0, sizeof (xml_syspath_t));
  xml_sys_path_list->xmlp_mutex = mutex_allocate();
}

xs_tag_t *
xs_find_ancestor_by_component_type (xs_tag_t * tag, int *cts)
{
  xs_tag_t *ret;
  for (ret = tag ? tag->tag_base : NULL; NULL != ret; ret = ret->tag_base)
    {
      if (NULL != ret->tag_component)
	{
	  enum xs_component_type ct = ret->tag_component->cm_type.t_major;
	  int *cts_tail = cts;
	  do
	    {
	      if (cts_tail[0] == ct)
		return ret;
	      cts_tail++;
	    } while (0 <= cts_tail[0]);
	}
    }
  return NULL;
}


ptrlong
xs_component_status (xs_tag_t * tag)
{
  switch (tag->tag_info->info_compcat)
    {
    case XS_COM_COMPLEXT:
    case XS_COM_SIMPLET:
    case XS_COM_ANNOTATION:
    case XS_COM_KEY:
    case XS_COM_NOTATION:
#if 0
	{
	  const char* name = xs_get_attr ("name", tag->tag_atts);
	  if (name && !strcmp(name, "annotated"))
	    breakpoint();
	}
#endif
      schema_printf (("schema: component could be initialized\n"));
      return XS_COMPONENT;
    case XS_COM_ELEMENT:
      {
	if (xs_get_attr ("ref", tag->tag_atts))
	  {
	    static int pat[] = {XS_COM_COMPLEXT , XS_COM_GROUP, -1};
	    schema_printf (("schema: component could not be initialized\n"));
	    if (xs_find_ancestor_by_component_type (tag, pat))
	      return XS_REFERENCE;
	    else
	      {
		SHOULD_BE_CHANGED;
#if 0
#ifdef XMLSCHEMA_UNIT_DEBUG
		GPF_T1("testing purpose, it is not normal, call to customer support\n");
#endif
#endif
      return XS_SKIP;
	      }
	  }
	else if (xs_get_attr ("name", tag->tag_atts))
	  return XS_COMPONENT;
	SHOULD_BE_CHANGED; /* error handling must be here */
	return XS_SKIP;
      }
    case XS_COM_GROUP:
    case XS_COM_ATTRIBUTE:
    case XS_COM_ATTRGROUP:
      if (xs_get_attr ("ref", tag->tag_atts))
	return XS_REFERENCE;
      if (xs_get_attr ("name", tag->tag_atts))
	return XS_COMPONENT;
#if 0
#ifdef XMLSCHEMA_UNIT_DEBUG
      GPF_T1("testing purpose, it is not normal, call to customer support\n");
#endif
#endif
      return XS_SKIP;
    default:
      schema_printf (("schema: component could not be initialized\n"));
      return XS_SKIP;
    }
}

xs_component_t *
add_component_reference (
  vxml_parser_t* parser, const char * longname, const char *qname,
  id_hash_t * array, xml_pos_t * pos, int is_definition)
{
  schema_processor_t* proc = &parser->processor;
  mem_pool_t* pool = proc->sp_schema->pool;
  xs_component_t **dict_entry;
  xs_component_t *comp;

#ifdef DEBUG
  if ((NULL != strstr (pos->origin_uri, ".xml")) || (0 == pos->line_num))
    GPF_T1(box_sprintf(strlen (pos->origin_uri) + 50, "Bad position of component reference: '%s':%d", pos->origin_uri, pos->line_num));
#endif

  dict_entry = (xs_component_t **) id_hash_get (array, (caddr_t) & longname);
  comp = dict_entry ? *dict_entry : NULL;
  if (!comp)
    {
      comp = (xs_component_t*) mp_alloc_box (pool, sizeof (xs_component_t), DV_CUSTOM);
      memset (comp, 0, sizeof (xs_component_t));
      comp->cm_serial = parser->obj_serial++;
      comp->cm_longname = mp_box_string (pool, (char*)longname);
      comp->cm_qname = mp_box_string (pool, (char*)qname);
      comp->cm_xecm_idx = comp->cm_elname_idx = -1; /* element is not in internal tables */
      id_hash_set (array, (caddr_t) & comp->cm_longname, (caddr_t) & comp);
#ifdef DEBUG
      if (parser->processor.sp_schema->sp_debug_dict_size < XML_MAX_DEBUG_DICT)
	parser->processor.sp_schema->sp_debug_dict[parser->processor.sp_schema->sp_debug_dict_size++] = comp;
#endif
      if (is_definition)
	{
	  xml_pos_set (&comp->cm_definition, pos);
	  return comp;
	}
    }
  else if (is_definition)
    {
      if(IS_DEFINED(comp)) /* Already defined */
	{
	  if (proc->sp_schema->sp_redefine_mode) /* use versioning */
	    {
	      size_t newlongname_sz = strlen(longname) + 4 /*$ver*/ + XS_VERSION_DIGITS /*digits for version*/ + 1;
	      size_t newqname_sz = strlen(qname) + 4 /*$ver*/ + XS_VERSION_DIGITS /*digits for version*/ + 1;
	      xs_component_t* newcomp;
	      if (comp->cm_version >= XS_MAX_VERSION_NUM)
		{
		  xs_set_error (parser, XCFG_FATAL, strlen (comp->cm_qname),
		    "Version number for component <%s> is exceeded maximum allowed",
		    comp->cm_qname );
		  return comp;
		}
	      newcomp = (xs_component_t*) mp_alloc_box (pool, sizeof (xs_component_t), DV_CUSTOM);
	      memset (newcomp, 0, sizeof (xs_component_t));
	      newcomp->cm_serial = parser->obj_serial++;
	      newcomp->cm_version = comp->cm_version + 1;
	      newcomp->cm_longname = mp_alloc_box (pool, newlongname_sz, DV_SHORT_STRING);
	      sprintf (newcomp->cm_longname, "%s$ver%.3ld", longname, comp->cm_version);
	      newcomp->cm_qname = mp_alloc_box (pool, newqname_sz, DV_SHORT_STRING);
	      sprintf (newcomp->cm_qname, "%s$ver%.3ld", qname, comp->cm_version);
	      newcomp->cm_xecm_idx = newcomp->cm_elname_idx = -1; /* element is not in internal table */
	      id_hash_set (array, (caddr_t) & newcomp->cm_longname, (caddr_t) & newcomp);
#ifdef DEBUG
	      if (parser->processor.sp_schema->sp_debug_dict_size < XML_MAX_DEBUG_DICT)
		parser->processor.sp_schema->sp_debug_dict[parser->processor.sp_schema->sp_debug_dict_size++] = newcomp;
#endif
	      xml_pos_set (&newcomp->cm_definition, pos);
	      comp->cm_next_version = newcomp;
	      return newcomp;
	    }
	  if (XS_REDEF_NONE == comp->cm_redef_error)
	    comp->cm_redef_error = XS_REDEF_ERROR;
	  return comp;
	};
    };
  if ((!is_definition) && !IS_REFERENCED(comp))
    {
      comp->cm_deflevel |= XS_DEF_REFERENCED;
      xml_pos_set (&comp->cm_reference, pos);
    };
  return comp;
}


xs_component_t *
xs_get_builtinidx (vxml_parser_t * parser, const char * expname_or_null, const char *qname, int auto_def)
{
  ptrlong binfo_idx;
  char* strippedname = (char *)qname;
  char* tmpname = NULL;
  if (expname_or_null)
    {
      strippedname = xs_get_local_name (XMLSCHEMA_NS_URI, (char *)expname_or_null);
      if (strippedname != expname_or_null)
        tmpname = strippedname;
    }
  if (strippedname)
    {
      binfo_idx = ecm_find_name (strippedname,
	(void*) xs_builtin_type_info_dict, xs_builtin_type_info_dict_size, sizeof (xs_builtin_types_info_t));
      if (NULL != tmpname)
	dk_free_box (tmpname);
      if (-1 != binfo_idx)
	return (void *)binfo_idx;
    }
  else if ((NULL == strchr (expname_or_null, ':')) && (NULL == parser->processor.sp_schema->sp_target_ns_uri))
    {
      binfo_idx = ecm_find_name (expname_or_null,
	(void*) xs_builtin_type_info_dict, xs_builtin_type_info_dict_size, sizeof (xs_builtin_types_info_t));
      if (-1 != binfo_idx)
	return (void *)binfo_idx;
    }
  if (NULL == expname_or_null)
    GPF_T;
  if (!auto_def)
    return 0;
  return add_component_reference (parser, expname_or_null, qname,
    parser->processor.sp_schema->sp_types, &parser->curr_pos, 0 );
}

#ifdef DEBUG
/* this code is not used actually, but it could be usefull in future */
/* called at moment when all types are defined */
xs_facet_t *
xs_check_facet_constraint (vxml_parser_t * parser,
    xs_component_t * c, xs_facet_t * f)
{
  xs_component_t *root;
  XS_ASSERT ((c->cm_deflevel & XS_DEF_DEFINED));
  root = get_root_type (parser, c);
  XS_ASSERT (!IS_BOX_POINTER(root->cm_typename));
  if (xs_builtin_type_info_dict[(ptrlong)(root->cm_typename)].binfo_facetmask & f->fc_type)	/* facet is allowed */
    {
      dk_set_push (&INFO_CSTYPE (c).facets, f);
      SHOULD_BE_CHANGED;
      return 0;
    }
  else
    {				/* not allowed */
      const char *facet_name =
	  xs_builtin_type_info_dict[(ptrlong)(root->cm_typename)].binfo_name;
      xmlparser_logprintf (parser, XCFG_ERROR,
	  ECM_MESSAGE_LEN + utf8len (facet_name),
	  "Facet is not allowed for base type <%s> ", facet_name );
      return 0;
    }
}
#endif /*DEBUG*/

xs_lg_item_t *
xs_add_lg_item (vxml_parser_t * parser, void *item)
{
  mem_pool_t* pool = parser->processor.sp_schema->pool;
  xs_lg_item_t *lgi = (xs_lg_item_t*) mp_alloc_box (pool, sizeof (xs_lg_item_t), DV_CUSTOM);
  xml_pos_set (&lgi->lg_pos, &parser->curr_pos);
  lgi->lg_item = item;
  return lgi;
}

/* This is unused for a while
void
xs_add_facet (vxml_parser_t * parser, xs_component_t * c, ptrlong fc_id,
    const char * value)
{
  mem_pool_t* pool=parser->processor.sp_schema->pool;
  xs_facet_t *fc;
  XS_ASSERT ((XS_COM_COMPLEXT == c->cm_type.t_major) || (XS_COM_SIMPLET == c->cm_type.t_major));
  fc = (xs_facet_t*) mp_alloc_box (pool, sizeof (xs_facet_t), DV_CUSTOM);
  fc->fc_type = fc_id;
  fc->fc_value = mp_box_string (pool, (char*)value);
  dk_set_push (&INFO_CSTYPE (c).lg_facets,
	       xs_add_lg_item (parser,  (void *) fc));
}
*/

/* subject of change - there are many restrictions for appearing attributes in different contents
   type must be checked and reference on it must be logged
*/

void
xs_add_en (vxml_parser_t * parser, xs_component_t * c, ptrlong fc_id,
    char * value)
{
  /* zzzz */
  SHOULD_BE_CHANGED;
}


xs_component_t *
get_root_type (struct vxml_parser_s * parser, xs_component_t * c)
{
  xs_component_t *type = c;
  xs_component_t *base;
again:
  base = type->cm_typename;
  if (!IS_BOX_POINTER (base))
    return type;
  if (IS_SCTYPE (type) || (MAJOR_ID((type))==XS_COM_ELEMENT))
    type = (xs_component_t *) base;
  goto again;
}


int
xs_set_error (vxml_parser_t * parser, ptrlong errlevel, size_t buflen_eval,
    const char *format, ...)
{
  dtd_astate_t *state =
      parser->validator.dv_stack + parser->validator.dv_depth;
  int ret = 0;
  size_t buflen_used;
  char *buf = dk_alloc (buflen_eval);
  va_list va_tail;
  va_start (va_tail, format);
  /* see Dk/Dkstub.c */
  buflen_used = vsnprintf (buf, buflen_eval, format, va_tail);
  va_end (va_tail);
  ret = xmlparser_logprintf (parser, errlevel, buflen_used, "%s", buf);
  dk_free (buf, buflen_eval);
  if (XCFG_ERROR >= errlevel)	/* Not '<=' ! zero errlevel is XCFG_FATAL ! */
    state->da_sstate = TAG_ST_ERROR;
  return ret;
}

void xs_swap_global_vars (schema_parsed_t* target, schema_parsed_t* source)
{
  int ctr;
#define XS_SWAP_1(type,item) \
  do { type tmp = target->item; \
    target->item = source->item; \
    source->item = tmp; } while (0)
  for (ctr = 0; ctr < COUNTOF__XS_SP_HASH; ctr++)
    XS_SWAP_1 (id_hash_t *, sp_hashtables[ctr]);

  XS_SWAP_1 (xecm_el_t *, sp_xecm_els);
  XS_SWAP_1 (ptrlong, sp_xecm_el_no);
  XS_SWAP_1 (ptrlong, sp_type_counter);
  XS_SWAP_1 (caddr_t *, sp_xecm_namespaces);
  XS_SWAP_1 (ptrlong, sp_xecm_namespace_no);

  XS_SWAP_1 (xecm_st_t *, sp_empty_states);
  XS_SWAP_1 (ptrlong, sp_empty_st_no);

  XS_SWAP_1 (qualification_t, sp_att_qualified);
  XS_SWAP_1 (qualification_t, sp_el_qualified);
}


int load_external_schemas (struct vxml_parser_s* parser, int location_attr, const char* ref)
{
  int res = 0, parts_count;
  mem_pool_t *pool = parser->processor.sp_schema->pool;
  dk_set_t ref_parts = NULL, ref_parts_tail;
  char *part_begin, *part_end;
  if (NULL == pool)
    {
#ifdef XS_POOL_DEBUG
      xs_pool_allocs++;
      xs_pool_allocs_tries++;
#endif
      pool = parser->processor.sp_schema->pool = mem_pool_alloc ();
    }  
  if (XSI_ATTR_NONAMESPACESCHEMALOCATION == (location_attr & XSI_ATTR_MASK))
    mp_set_push (pool, &ref_parts, NULL);
  part_begin = (char*) ref;
  for (;;)
    {
      while (('\0' != part_begin[0]) && strchr (" \n\r\t", part_begin[0])) part_begin++;
      if ('\0' == part_begin[0])
        break;
      part_end = part_begin;
      while (('\0' != part_end[0]) && !strchr (" \n\r\t", part_end[0])) part_end++;
      mp_set_push (pool, &ref_parts, mp_box_dv_short_nchars (pool, part_begin, part_end - part_begin));
      part_begin = part_end;
    }
  parts_count = dk_set_length (ref_parts);
  ref_parts = dk_set_nreverse (ref_parts);
  switch (location_attr & XSI_ATTR_MASK)
    {
    case XSI_ATTR_SCHEMALOCATION:
      if (1 == parts_count)	/* Backward compatibility */
        {
          mp_set_push (pool, &ref_parts, NULL);
          break;
        }
      if (parts_count % 2)
        {
	  xmlparser_logprintf (parser, XCFG_FATAL, 100,
	    "The value of schemaLocation attribute is not a list of pairs of URIs" );
	  return 0;
        }
      break;
    case XSI_ATTR_NONAMESPACESCHEMALOCATION:
      if (2 != parts_count)
        {
	  xmlparser_logprintf (parser, XCFG_FATAL, 100,
	    "The value of noNamespaceSchemaLocation attribute is not a single URI" );
          return 0;
        }
      break;
    default: GPF_T;
    }
  for (ref_parts_tail = ref_parts; NULL != ref_parts_tail; ref_parts_tail = ref_parts_tail->next->next)
    {
      caddr_t ref_ns = ref_parts_tail->data;
      caddr_t ref_uri = ref_parts_tail->next->data;
      if (NULL == ref_uri)
        break;
#ifdef XS_POOL_DEBUG
      xs_pool_schemas++;
#endif
      if (load_external_schema (parser, ref_uri, 0))
        {
          if (NULL == ref_ns)          
	    xmlparser_logprintf (parser, XCFG_FATAL,
	      100 + strlen (ref_uri),
	      "XML Schema declaration '%s' is not valid", ref_uri);
	  else
	    xmlparser_logprintf (parser, XCFG_FATAL,
	      100 + strlen (ref_uri) + strlen (ref_ns),
	      "XML Schema declaration '%s' is not valid (namespace URI '%s')", ref_uri, ref_ns);
	  res = 1;
	}
    }
  return res;
}

int
load_external_schema (struct vxml_parser_s* parser, const char* ref, int is_internal)
{
  caddr_t err = NULL;
  const char * base = parser->cfg.uri;
  char * path;
  caddr_t text;
  ptrlong mode = parser->validator.dv_curr_config.dc_include;
  ptrlong trace = parser->validator.dv_curr_config.dc_trace_loading;
  ptrlong errors = 0;
  vxml_parser_t * new_parser = NULL;
  if (XCFG_DISABLE == mode)
    {
      if (XCFG_DISABLE != trace)
	xmlparser_logprintf (parser, XCFG_DETAILS, 100+strlen(base)+strlen(ref),
	  "Loading of external XMLSchema skipped from reference URI '%s' with base URI '%s', as configured by DTD validation options.", ref, base );
      return 1;
    }
  path = parser->cfg.uri_resolver (parser->cfg.uri_appdata, &err, base, (char*) ref, "UTF-8");
  if (!parser->processor.sp_schema->pool)
    {
#ifdef XS_POOL_DEBUG
      xs_pool_allocs++;
      xs_pool_allocs_tries++;
#endif
      parser->processor.sp_schema->pool = mem_pool_alloc ();
    }
  if (err)
    {
      dk_free_box (path);
      if (xmlparser_logprintf (parser, mode, 100+strlen(base)+strlen(ref),
	    "Unable to resolve reference URI '%s' with base URI '%s'", ref, base ) )
	xmlparser_logprintf (parser, XCFG_DETAILS, strlen(((char **)err)[1])+strlen(((char **)err)[2]), "[%s]: %s", ((char **)err)[1], ((char **)err)[2] );
      return 1;
    }
  text = xml_uri_get (parser->cfg.uri_appdata, &err, NULL, base, (caddr_t)ref, 1);
  if (err)
    { /* try system paths */
      struct xml_iter_syspath_s* syspath_iter = xml_iter_system_path();
      char* syspath = NULL;
      while (err)
	{
	  syspath = xml_iter_syspath_hitnext (syspath_iter);
	  if (syspath)
	    text = parser->cfg.uri_reader (parser->cfg.uri_appdata, &err, NULL, syspath, (char*)ref, 1);
	  else
	    break;
	}
      xml_free_iter_system_path(syspath_iter);
      if (!syspath) /* all syspaths are failed */
	{
          dk_free_box (path);
	  xmlparser_logprintf (parser, mode, 100+strlen(base)+strlen(ref),
	    "Could not get text from '%s' (base='%s')", ref, base );
	  return 1;
	}
    }
  /* Now we have \c text ready to process */
  QR_RESET_CTX
    {
      ptrlong maxval;
      vxml_parser_config_t config;
/*    schema_processor_t saved_new_parser_proc; */
      memset (&config, 0, sizeof (config));
      config.input_is_wide = 0;
      config.input_is_ge = 0;
      config.input_is_html = FINE_XML;
      config.input_is_xslt = 0;
      config.user_encoding_handler = intl_find_user_charset;
      config.uri_resolver = (VXmlUriResolver)xml_uri_resolve_like_get;
      config.uri_reader = (VXmlUriReader)xml_uri_get;
      config.uri_appdata = parser->cfg.uri_appdata;
      config.initial_src_enc_name = NULL;
      {
	static caddr_t dflt_config = NULL;
	if (NULL == dflt_config)
	  dflt_config = box_dv_short_string ("Validation=RIGOROUS FsaBadWs=IGNORE Fsa=ERROR BuildStandalone=ENABLE SchemaDecl=ENABLE");
        config.dtd_config = dflt_config;
      }
 /* This 'if' is incorrect because diagnostics will print locations of components as
 as if they're in XML file under validation, not in XSD file
	 if (!is_internal)
	config.uri = parser->cfg.uri;
      else */
      config.uri = mp_box_string (parser->processor.sp_schema->pool, path);
      config.root_lang_handler = server_default_lh;
      new_parser = VXmlParserCreate (&config);
#ifdef DEBUG
      if (NULL != new_parser->processor.sp_schema)
	GPF_T;
#endif
      new_parser->processor.sp_schema = xs_alloc_schema();
      new_parser->processor.sp_schema->sp_is_internal = is_internal;
      VXmlSetUserData (new_parser, new_parser);
      xs_swap_global_vars (new_parser->processor.sp_schema, parser->processor.sp_schema);
      new_parser->processor.sp_schema->pool = parser->processor.sp_schema->pool;
      new_parser->validator.dv_curr_config.dc_xs_decl = XCFG_ENABLE;
      maxval = parser->validator.dv_curr_config.dc_max_errors - parser->msglog_ctrs[XCFG_ERROR];
      if (maxval < 0) maxval = 0;
      new_parser->validator.dv_curr_config.dc_max_errors = maxval;
      maxval = parser->validator.dv_curr_config.dc_max_warnings - parser->msglog_ctrs[XCFG_WARNING];
      if (maxval < 0) maxval = 0;
      new_parser->validator.dv_curr_config.dc_max_warnings = maxval;
      new_parser->validator.dv_curr_config.dc_namespaces = XCFG_ENABLE;

      if (config.auto_load_xmlschema_dtd_p &&
	  config.auto_load_xmlschema_dtd_s)
	{
	  new_parser->cfg.auto_load_xmlschema_dtd = 1;
	}

      VXmlParse (new_parser, text, box_length(text) - (new_parser->cfg.input_is_wide ? sizeof (wchar_t) : sizeof (char)));
      errors = new_parser->msglog_ctrs[XCFG_FATAL] + new_parser->msglog_ctrs[XCFG_ERROR];
      xmlparser_log_nconcat (parser, new_parser);
      xs_swap_global_vars (parser->processor.sp_schema, new_parser->processor.sp_schema);
      dk_free_box (new_parser->processor.sp_schema->sp_target_ns_uri);
      dk_free (new_parser->processor.sp_schema, sizeof (schema_parsed_t));
      new_parser->processor.sp_schema = NULL;
      parser->input_weight += new_parser->input_weight;
      parser->input_cost += new_parser->input_cost;
      if (XML_MAX_DOC_COST < parser->input_cost)
        parser->input_cost = XML_MAX_DOC_COST;
      VXmlParserDestroy (new_parser);
      dk_free_tree (err);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t thr_err = thr_get_error_code (self);
      dk_free_box (text);
      dk_free_box (path);

      dk_free_box (new_parser->processor.sp_schema->sp_target_ns_uri);
      new_parser->processor.sp_schema->sp_target_ns_uri = NULL;

      if (NULL != new_parser)
        {
	  xs_swap_global_vars (parser->processor.sp_schema, new_parser->processor.sp_schema);
	  dk_free_box (new_parser->processor.sp_schema->sp_target_ns_uri);
	  dk_free (new_parser->processor.sp_schema, sizeof (schema_parsed_t));
	  new_parser->processor.sp_schema = NULL;
	  VXmlParserDestroy (new_parser);
	}
      POP_QR_RESET;
      sqlr_resignal (thr_err);
    }
  END_QR_RESET;
  dk_free_box (text);
  dk_free_box (path);
  return (int) errors;
}

extern caddr_t uname_xmlschema_ns_uri;

xs_component_t* xs_new_predefined_component (vxml_parser_t* parser, const char* _typename)
{
  id_hash_t* types = parser->processor.sp_schema->sp_types;
  ccaddr_t prefix_or_null = VXmlFindNamespacePrefixByUri (parser, uname_xmlschema_ns_uri);
  const char *prefix = ((prefix_or_null && (uname___empty != prefix_or_null)) ? prefix_or_null : "");
  mem_pool_t *pool = parser->processor.sp_schema->pool;
  xs_component_t* newtype = (xs_component_t*) mp_alloc_box(pool, sizeof (xs_component_t), DV_CUSTOM);
  memset (newtype, 0, sizeof (xs_component_t));
  newtype->cm_serial = parser->obj_serial++;
  newtype->cm_longname = mp_alloc_box (pool, strlen(_typename)+utf8len(XMLSCHEMA_NS_URI)+2, DV_SHORT_STRING);
  sprintf(newtype->cm_longname, "%s:%s", XMLSCHEMA_NS_URI, _typename);
  if (prefix)
    {
      newtype->cm_qname =mp_alloc_box (pool, strlen(_typename)+utf8len(prefix)+2, DV_SHORT_STRING);
      sprintf(newtype->cm_qname, "%s:%s", prefix, _typename);
    }
  else
    {
      newtype->cm_qname =mp_alloc_box (pool, strlen(_typename)+1, DV_SHORT_STRING);
      sprintf(newtype->cm_qname, "%s", _typename);
    }
  newtype->cm_deflevel = XS_DEF_DEFINED;
  newtype->cm_redef_error = XS_REDEF_SYSDEF;
  id_hash_set (types, (caddr_t) & newtype->cm_longname, (caddr_t) & newtype);
#ifdef DEBUG
  if (parser->processor.sp_schema->sp_debug_dict_size < XML_MAX_DEBUG_DICT)
    parser->processor.sp_schema->sp_debug_dict[parser->processor.sp_schema->sp_debug_dict_size++] = newtype;
#endif
  return newtype;
}

xs_component_t* xs_new_predefined_attribute (vxml_parser_t* parser, const char* attr, const char* tpname)
{
  id_hash_t* attrs = parser->processor.sp_schema->sp_attrs;
  mem_pool_t *pool = parser->processor.sp_schema->pool;
  xs_component_t* newtype = (xs_component_t*) mp_alloc_box(pool, sizeof (xs_component_t), DV_CUSTOM);
  memset (newtype, 0, sizeof (xs_component_t));
  newtype->cm_serial = parser->obj_serial++;
  newtype->cm_longname = mp_alloc_box (pool, strlen(attr) + 1, DV_SHORT_STRING);
  newtype->cm_qname =mp_alloc_box (pool, strlen(attr)+1, DV_SHORT_STRING);
  sprintf(newtype->cm_longname, "%s", attr);
  sprintf(newtype->cm_qname, "%s", attr);
  newtype->cm_typename = xs_get_builtinidx (parser, NULL, tpname, 0);

  newtype->cm_deflevel = XS_DEF_DEFINED;
  newtype->cm_redef_error = XS_REDEF_SYSDEF;

  id_hash_set (attrs, (caddr_t) & newtype->cm_longname, (caddr_t) & newtype);
#ifdef DEBUG
  if (parser->processor.sp_schema->sp_debug_dict_size < XML_MAX_DEBUG_DICT)
    parser->processor.sp_schema->sp_debug_dict[parser->processor.sp_schema->sp_debug_dict_size++] = newtype;
#endif
  return newtype;
}

void xs_add_predefined_compl_type (vxml_parser_t* parser, const char* _typename, grp_tree_elem_t* content)
{
  xs_component_t* newtype = xs_new_predefined_component (parser, _typename);
  newtype->cm_type.t_major = XS_COM_COMPLEXT;
  INFO_CSTYPE(newtype).group = content;
}


void xs_add_predefined_simple_type (vxml_parser_t* parser, const char* _typename)
{
  xs_component_t* newtype = xs_new_predefined_component (parser, _typename);
  newtype->cm_type.t_major = XS_COM_SIMPLET;
}

void xs_add_predefined_types (vxml_parser_t* parser)
{
  xs_add_predefined_compl_type (parser, "anyType", XECM_ANY);
  xs_add_predefined_simple_type (parser, "anySimpleType");
}

void xs_add_predefined_attributes (vxml_parser_t * parser)
{
  xs_new_predefined_attribute (parser, "xml:lang", "language");
}

/* returns error if could not add path in system list */
caddr_t xml_add_system_path (caddr_t path_uri)
{
  if (path_uri)
    {
      mutex_enter (xml_sys_path_list->xmlp_mutex);
      if (xml_sys_path_list->xmlp_list)
	{
	  DO_SET(char* , path_iter, &xml_sys_path_list->xmlp_list)
	    if (!strcmp(path_iter, path_uri))
	    {
	      mutex_leave (xml_sys_path_list->xmlp_mutex);
	      return (caddr_t)0; /* just ignore this case */
	    };
	  END_DO_SET()
	}
      dk_set_push(&xml_sys_path_list->xmlp_list, box_dv_short_string(path_uri));
      mutex_leave (xml_sys_path_list->xmlp_mutex);
    }
  return (caddr_t)0;
}

struct xml_iter_syspath_s
{
  dk_set_t isp_list;
  s_node_t *isp_iter;
};

struct xml_iter_syspath_s* xml_iter_system_path (void)
{
  struct xml_iter_syspath_s* iter = dk_alloc(sizeof(struct xml_iter_syspath_s));
  mutex_enter(xml_sys_path_list->xmlp_mutex);
  memset (iter, 0, sizeof(struct xml_iter_syspath_s));
  iter->isp_list = dk_set_copy(xml_sys_path_list->xmlp_list);
  iter->isp_iter = iter->isp_list;
  mutex_leave(xml_sys_path_list->xmlp_mutex);
  return iter;
}

void xml_free_iter_system_path(struct xml_iter_syspath_s* iter)
{
  dk_set_free(iter->isp_list);
  dk_free(iter, sizeof (struct xml_iter_syspath_s));
}

caddr_t xml_iter_syspath_hitnext(struct xml_iter_syspath_s* iter)
{
  if (iter->isp_iter)
    {
      caddr_t data = iter->isp_iter->data;
      iter->isp_iter = iter->isp_iter->next;
      return data;
    }
  return 0;
}

ptrlong xml_iter_syspath_length(struct xml_iter_syspath_s* iter)
{
  return dk_set_length(iter->isp_list);
}

void xs_clear_states (xs_component_t * component)
{
  if (component->cm_states)
    {
      ptrlong st_idx;
      for (st_idx = 0; st_idx < component->cm_state_no; st_idx++)
	{
	  xecm_nexts_free (component->cm_states[st_idx].xes_nexts);
	}
      dk_free_box (component->cm_states);
      component->cm_states = NULL;
    }
#ifdef DEBUG
  if (component->cm_raw_states)
    {
      ptrlong st_idx;
      for (st_idx = 0; st_idx < component->cm_raw_state_no; st_idx++)
	{
	  xecm_nexts_free (component->cm_raw_states[st_idx].xes_nexts);
	}
      dk_free_box (component->cm_raw_states);
      component->cm_raw_states = NULL;
    }
#endif
}


static void
xs_clear_empty_states (schema_parsed_t * sp)
{
  xecm_st_t * states = sp->sp_empty_states;
  ptrlong st_no = sp->sp_empty_st_no;

  if (states)
    {
      ptrlong st_idx;
      for (st_idx=0;st_idx<st_no;st_idx++)
	{
	  xecm_nexts_free(states[st_idx].xes_nexts);
	}
      dk_free_box(states);
    }
}


schema_parsed_t *
DBG_NAME (xs_alloc_schema) (DBG_PARAMS_0)
{
  schema_parsed_t *schema = DK_ALLOC (sizeof (schema_parsed_t));
  memset (schema, 0, sizeof (schema_parsed_t));
  schema->sp_refcount = 1;
  return schema;
}


void xs_addref_schema (schema_parsed_t * schema)
{
  if (schema->sp_refcount <= 0)
    GPF_T;
  schema->sp_refcount++;
}


void xs_release_schema (schema_parsed_t* schema)
{
  int hashtablectr;
  id_hash_iterator_t hit;
  char** name;
  xs_component_t** component;
  schema->sp_refcount--;
  if (schema->sp_refcount > 0)
    return;

  dk_free_box (schema->sp_target_ns_uri);

  if (NULL != schema->sp_all_elnames)
    {
      id_hash_free (schema->sp_all_elnames);
      schema->sp_all_elnames = NULL;
    }
  for (hashtablectr = 0; hashtablectr < COUNTOF__XS_SP_HASH; hashtablectr++)
    {
      id_hash_t *dict = schema->sp_hashtables[hashtablectr];
      if (NULL == dict)
        continue;
retry_hashtable:
      for (id_hash_iterator(&hit, dict);
	hit_next(&hit, (char**)&name, (char**)&component);
        /* no step */)
	{
	  if (!IS_UNDEF_TYPE(*component))
	    continue;
#ifdef DEBUG
#if 0 /* ??? */
	  if (IS_DEFINED(*component))
	    GPF_T;
#endif
#endif
	  id_hash_remove (dict, (caddr_t)name);
	  goto retry_hashtable;
	}
    }

  if (NULL == schema->sp_types)
    goto skip_sp_types;
  for (id_hash_iterator(&hit,schema->sp_types);
    hit_next(&hit, (char**)&name, (char**)&component);
    /* no step */)
    {
#ifdef DEBUG
      id_hash_iterator_t hit2;
      char** name2;
      xs_component_t** component2;
        for (id_hash_iterator(&hit2,schema->sp_types);
          hit_next(&hit2, (char**)&name2, (char**)&component2);
          /* no step */)
          {
	    if (strcmp (name[0], name2[0]) &&
	      (NULL != INFO_CSTYPE(*component).composed_atts) &&
	      (INFO_CSTYPE(*component).composed_atts == INFO_CSTYPE(*component2).composed_atts) )
	      GPF_T;
          }
#endif
      if (INFO_CSTYPE(*component).lg_agroup)
	dk_set_free(INFO_CSTYPE(*component).lg_agroup);
#if 0
      if (INFO_CSTYPE(*component).composed_atts_no)
	{
	  ptrlong idx = 0;
	  xecm_attr_t * att;
	  while (idx < INFO_CSTYPE(*component).composed_atts_no)
	    {
	      att = INFO_CSTYPE(*component).composed_atts + idx++;
	      dk_free_box (att->xa_name);
	    }
	}
#endif

      if (INFO_CSTYPE(*component).composed_atts)
	dk_free_box (INFO_CSTYPE(*component).composed_atts);
/*
      if (INFO_CSTYPE(*component).lg_facets)
	dk_set_free (INFO_CSTYPE(*component).lg_facets);
*/
      dk_free_box (XS_CM_TYPE (*component).any_attr_ns);
      xs_clear_states (component[0]);
    }
  id_hash_free(schema->sp_types);
skip_sp_types:

  xs_clear_empty_states (schema);

  if (NULL == schema->sp_elems)
    goto skip_sp_elems;
  for (id_hash_iterator(&hit,schema->sp_elems);
    hit_next(&hit, (char**)&name, (char**)&component);
    /* no step */)
    {
      DO_SET (elm_keyref_t*, kr, &INFO_ELEMENT(component[0]).keyrefs)
	{
	  dk_free_box (kr->kr_selector);
	  dk_free_box (kr->kr_fields);
	  dk_free (kr, sizeof (elm_keyref_t));
	}
      END_DO_SET();
      dk_set_free (INFO_ELEMENT(component[0]).keyrefs);
      xsd_destroy_mssql_ann (&(INFO_ELEMENT(component[0]).ann));
      xs_clear_states (component[0]);
    }
  id_hash_free(schema->sp_elems);
skip_sp_elems:

  if (NULL == schema->sp_attrs)
    goto skip_sp_attrs;

  for (id_hash_iterator(&hit,schema->sp_attrs);
    hit_next(&hit, (char**)&name, (char**)&component);
    /* no step */)
    {
      dk_free_box (INFO_ATTRIBUTE(component[0]).fixval);
      xsd_destroy_mssql_ann (&(INFO_ATTRIBUTE(component[0]).ann));
    }
  id_hash_free(schema->sp_attrs);
skip_sp_attrs:

  if (NULL == schema->sp_attrgrps)
    goto skip_sp_attrgrps;
  for (id_hash_iterator(&hit,schema->sp_attrgrps);
    hit_next(&hit, (char**)&name, (char**)&component);
    /* no step */)
    {
#if 0
      if (INFO_ATTRGROUP(*component).composed_atts_no)
	{
	  ptrlong idx = 0;
	  xecm_attr_t * att;
	  while (idx < INFO_ATTRGROUP(*component).composed_atts_no)
	    {
	      att = INFO_ATTRGROUP(*component).composed_atts + idx++;
	      dk_free_box (att->xa_name);
	    }
	}
#endif
      if (INFO_ATTRGROUP(*component).lg_agroup)
	dk_set_free(INFO_ATTRGROUP(*component).lg_agroup);
      if (INFO_ATTRGROUP(*component).composed_atts)
	dk_free_box(INFO_ATTRGROUP(*component).composed_atts);
      dk_free_box (XS_CM_TYPE(*component).any_attr_ns);
    }
  id_hash_free(schema->sp_attrgrps);
skip_sp_attrgrps:

  if (NULL == schema->sp_groups)
    goto skip_sp_groups;
  for (id_hash_iterator(&hit,schema->sp_groups);
    hit_next(&hit, (char**)&name, (char**)&component);
    /* no step */)
    {
      xs_clear_states (component[0]);
    }
  id_hash_free(schema->sp_groups);
skip_sp_groups:

  if (NULL == schema->sp_keys)
    goto skip_sp_keys;
  for (id_hash_iterator(&hit,schema->sp_keys);
    hit_next(&hit, (char**)&name, (char**)&component);
    /* no step */)
    {
      if (INFO_KEY(*component).xpath_selector)
	dk_free_box (INFO_KEY(*component).xpath_selector);
      if (INFO_KEY(*component).xpath_fields)
	dk_free_box (INFO_KEY(*component).xpath_fields);
    }
  id_hash_free(schema->sp_keys);
skip_sp_keys:

  if (NULL == schema->sp_annots)
    goto skip_sp_annots;
  id_hash_free(schema->sp_annots);
skip_sp_annots:

  if (NULL == schema->sp_notations)
    goto skip_sp_notations;
  for (id_hash_iterator(&hit,schema->sp_notations);
    hit_next(&hit, (char**)&name, (char**)&component);
    /* no step */)
    {
      if (INFO_NOTATION(*component).pub_uri)
	dk_free_box (INFO_NOTATION(*component).pub_uri);
      if (INFO_NOTATION(*component).sys_uri)
	dk_free_box (INFO_NOTATION(*component).sys_uri);
    }
  id_hash_free(schema->sp_notations);
skip_sp_notations:

  if (NULL == schema->sp_mssql_rships)
    goto skip_sp_mssql_rships;
  for (id_hash_iterator(&hit,schema->sp_mssql_rships);
    hit_next(&hit, (char**)&name, (char**)&component);
    /* no step */)
    {
      dk_free_box (INFO_MSSQL_RSHIP(*component).parent);
      dk_free_tree (INFO_MSSQL_RSHIP(*component).parent_keys);
      dk_free_box (INFO_MSSQL_RSHIP(*component).child);
      dk_free_tree (INFO_MSSQL_RSHIP(*component).child_keys);
    }
  id_hash_free(schema->sp_mssql_rships);
skip_sp_mssql_rships:

#ifdef XS_POOL_DEBUG
  xs_pool_free_tries++;
#endif

  dk_free_box(schema->sp_xecm_els);
  dk_free_box(schema->sp_xecm_namespaces);
  if (schema->pool)
    {
      mp_free(schema->pool);
#ifdef XS_POOL_DEBUG
      xs_pool_free++;
#endif
    }
  dk_free (schema, sizeof (schema_parsed_t));
}


void xs_clear_processor (schema_processor_t* processor)
{
  lenmem_t *acc = &(processor->sp_simpletype_value_acc);
  if (NULL != acc->lm_memblock)
    dk_free_box (acc->lm_memblock);
  if (processor->sp_schema)
    xs_release_schema (processor->sp_schema);
}
