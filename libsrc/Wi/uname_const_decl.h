/*
 *  $Id$
 *
 *  Constant declarations of commonly used UNAMEs.
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

#ifndef UNAME_CONST_DECL_H
#define UNAME_CONST_DECL_H
#include "Dk.h"

/*				 0         1         2         3        */
/*				 01234567890123456789012345678901234567 */
#define SWAP_REIFY_NS_URI	"http://www.w3.org/2000/10/swap/reify#"
#define SWAP_REIFY_NS_URI_LEN	37

/*				 0         1         2         3         4   */
/*				 0123456789012345678901234567890123456789012 */
#define VIRTRDF_NS_URI		"http://www.openlinksw.com/schemas/virtrdf#"
#define VIRTRDF_NS_URI_LEN	42

/*				 0         1         2         3         4   */
/*				 012345678901234567890123456789012345678901234567 */
#define RDFDF_NS_URI		"http://www.openlinksw.com/virtrdf-data-formats#"
#define RDFDF_NS_URI_LEN	47

/*				 0         1         2         3      */
/*				 012345678901234567890123456789012345 */
#define XHV_NS_URI		"http://www.w3.org/1999/xhtml/vocab#"
#define XHV_NS_URI_LEN		35

extern void uname_const_decl_init (void);

extern caddr_t uname___empty;
extern caddr_t uname__bang_cdata_section_elements;
extern caddr_t uname__bang_exclude_result_prefixes;
extern caddr_t uname__bang_file;
extern caddr_t uname__bang_location;
extern caddr_t uname__bang_name;
extern caddr_t uname__bang_ns;
extern caddr_t uname__bang_uri;
extern caddr_t uname__bang_use_attribute_sets;
extern caddr_t uname__bang_xmlns;
extern caddr_t uname__attr;
extern caddr_t uname__comment;
extern caddr_t uname__disable_output_escaping;
extern caddr_t uname__root;
extern caddr_t uname__pi;
extern caddr_t uname__ref;
extern caddr_t uname__srcfile;
extern caddr_t uname__srcline;
extern caddr_t uname__txt;
extern caddr_t uname__xslt;
extern caddr_t uname_SPECIAL_cc_bif_c_AVG;
extern caddr_t uname_SPECIAL_cc_bif_c_COUNT;
extern caddr_t uname_SPECIAL_cc_bif_c_MAX;
extern caddr_t uname_SPECIAL_cc_bif_c_MIN;
extern caddr_t uname_SPECIAL_cc_bif_c_SUM;
extern caddr_t uname_bif_c_contains;
extern caddr_t uname_bif_c_spatial_contains;
extern caddr_t uname_bif_c_spatial_intersects;
extern caddr_t uname_bif_c_sp_contains;
extern caddr_t uname_bif_c_sp_intersects;
extern caddr_t uname_bif_c_xcontains;
extern caddr_t uname_bif_c_xpath_contains;
extern caddr_t uname_bif_c_xquery_contains;
extern caddr_t uname_lang;
extern caddr_t uname_nil;
extern caddr_t uname_nodeID_ns;
extern caddr_t uname_rdf_ns_uri;
extern caddr_t uname_rdf_ns_uri_Description;
extern caddr_t uname_rdf_ns_uri_ID;
extern caddr_t uname_rdf_ns_uri_RDF;
extern caddr_t uname_rdf_ns_uri_Seq;
extern caddr_t uname_rdf_ns_uri_Statement;
extern caddr_t uname_rdf_ns_uri_XMLLiteral;
extern caddr_t uname_rdf_ns_uri_about;
extern caddr_t uname_rdf_ns_uri_first;
extern caddr_t uname_rdf_ns_uri_li;
extern caddr_t uname_rdf_ns_uri_nil;
extern caddr_t uname_rdf_ns_uri_nodeID;
extern caddr_t uname_rdf_ns_uri_object;
extern caddr_t uname_rdf_ns_uri_predicate;
extern caddr_t uname_rdf_ns_uri_resource;
extern caddr_t uname_rdf_ns_uri_rest;
extern caddr_t uname_rdf_ns_uri_subject;
extern caddr_t uname_rdf_ns_uri_type;
extern caddr_t uname_rdf_ns_uri_datatype;
extern caddr_t uname_rdf_ns_uri_parseType;
extern caddr_t uname_rdf_ns_uri_value;
extern caddr_t uname_rdfdf_ns_uri;
extern caddr_t uname_rdfdf_ns_uri_default;
extern caddr_t uname_rdfdf_ns_uri_default_nullable;
extern caddr_t uname_rdfdf_ns_uri_default_iid;
extern caddr_t uname_rdfdf_ns_uri_default_iid_nullable;
extern caddr_t uname_space;
extern caddr_t uname_swap_reify_ns_uri;
extern caddr_t uname_swap_reify_ns_uri_statement;
extern caddr_t uname_virtrdf_ns_uri;
extern caddr_t uname_virtrdf_ns_uri_DefaultQuadMap;
extern caddr_t uname_virtrdf_ns_uri_DefaultQuadStorage;
extern caddr_t uname_virtrdf_ns_uri_DefaultServiceStorage;
extern caddr_t uname_virtrdf_ns_uri_DefaultSparul11Target;
extern caddr_t uname_virtrdf_ns_uri_PrivateGraphs;
extern caddr_t uname_virtrdf_ns_uri_QuadMap;
extern caddr_t uname_virtrdf_ns_uri_QuadMapFormat;
extern caddr_t uname_virtrdf_ns_uri_QuadStorage;
extern caddr_t uname_virtrdf_ns_uri_SparqlMacroLibrary;
extern caddr_t uname_virtrdf_ns_uri_SyncToQuads;
extern caddr_t uname_virtrdf_ns_uri_array_of_any;
extern caddr_t uname_virtrdf_ns_uri_array_of_string;
extern caddr_t uname_virtrdf_ns_uri_bitmask;
extern caddr_t uname_virtrdf_ns_uri_bnode_base;
extern caddr_t uname_virtrdf_ns_uri_bnode_label;
extern caddr_t uname_virtrdf_ns_uri_bnode_row;
extern caddr_t uname_virtrdf_ns_uri_dialect;
extern caddr_t uname_virtrdf_ns_uri_isSpecialPredicate;
extern caddr_t uname_virtrdf_ns_uri_isSubclassOf;
extern caddr_t uname_virtrdf_ns_uri_loadAs;
extern caddr_t uname_virtrdf_ns_uri_rdf_repl_graph_group;
extern caddr_t uname_virtrdf_ns_uri_rdf_repl_all;
extern caddr_t uname_xhv_ns_uri;
extern caddr_t uname_xhv_ns_uri_alternate;
extern caddr_t uname_xhv_ns_uri_appendix;
extern caddr_t uname_xhv_ns_uri_bookmark;
extern caddr_t uname_xhv_ns_uri_cite;
extern caddr_t uname_xhv_ns_uri_chapter;
extern caddr_t uname_xhv_ns_uri_contents;
extern caddr_t uname_xhv_ns_uri_copyright;
extern caddr_t uname_xhv_ns_uri_first;
extern caddr_t uname_xhv_ns_uri_glossary;
extern caddr_t uname_xhv_ns_uri_help;
extern caddr_t uname_xhv_ns_uri_icon;
extern caddr_t uname_xhv_ns_uri_index;
extern caddr_t uname_xhv_ns_uri_last;
extern caddr_t uname_xhv_ns_uri_license;
extern caddr_t uname_xhv_ns_uri_meta;
extern caddr_t uname_xhv_ns_uri_next;
extern caddr_t uname_xhv_ns_uri_p3pv1;
extern caddr_t uname_xhv_ns_uri_prev;
extern caddr_t uname_xhv_ns_uri_role;
extern caddr_t uname_xhv_ns_uri_section;
extern caddr_t uname_xhv_ns_uri_stylesheet;
extern caddr_t uname_xhv_ns_uri_subsection;
extern caddr_t uname_xhv_ns_uri_start;
extern caddr_t uname_xhv_ns_uri_up;
extern caddr_t uname_xml;
extern caddr_t uname_xmlns;
extern caddr_t uname_xml_colon_base;
extern caddr_t uname_xml_colon_lang;
extern caddr_t uname_xml_colon_space;
extern caddr_t uname_xml_ns_uri;
extern caddr_t uname_xml_ns_uri_colon_base;
extern caddr_t uname_xml_ns_uri_colon_lang;
extern caddr_t uname_xml_ns_uri_colon_space;
extern caddr_t uname_xmlschema_ns_uri;
extern caddr_t uname_xmlschema_ns_uri_hash;
extern caddr_t uname_xmlschema_ns_uri_hash_ENTITY;
extern caddr_t uname_xmlschema_ns_uri_hash_ENTITIES;
extern caddr_t uname_xmlschema_ns_uri_hash_ID;
extern caddr_t uname_xmlschema_ns_uri_hash_IDREF;
extern caddr_t uname_xmlschema_ns_uri_hash_IDREFS;
extern caddr_t uname_xmlschema_ns_uri_hash_NCName;
extern caddr_t uname_xmlschema_ns_uri_hash_Name;
extern caddr_t uname_xmlschema_ns_uri_hash_NMTOKEN;
extern caddr_t uname_xmlschema_ns_uri_hash_NMTOKENS;
extern caddr_t uname_xmlschema_ns_uri_hash_NOTATION;
extern caddr_t uname_xmlschema_ns_uri_hash_QName;
extern caddr_t uname_xmlschema_ns_uri_hash_any;
extern caddr_t uname_xmlschema_ns_uri_hash_anyAtomicType;
extern caddr_t uname_xmlschema_ns_uri_hash_anySimpleType;
extern caddr_t uname_xmlschema_ns_uri_hash_anyType;
extern caddr_t uname_xmlschema_ns_uri_hash_anyURI;
extern caddr_t uname_xmlschema_ns_uri_hash_base64Binary;
extern caddr_t uname_xmlschema_ns_uri_hash_boolean;
extern caddr_t uname_xmlschema_ns_uri_hash_byte;
extern caddr_t uname_xmlschema_ns_uri_hash_date;
extern caddr_t uname_xmlschema_ns_uri_hash_dateTime;
extern caddr_t uname_xmlschema_ns_uri_hash_dateTimeStamp;
extern caddr_t uname_xmlschema_ns_uri_hash_decimal;
extern caddr_t uname_xmlschema_ns_uri_hash_double;
extern caddr_t uname_xmlschema_ns_uri_hash_duration;
extern caddr_t uname_xmlschema_ns_uri_hash_dayTimeDuration;
extern caddr_t uname_xmlschema_ns_uri_hash_yearMonthDuration;
extern caddr_t uname_xmlschema_ns_uri_hash_float;
extern caddr_t uname_xmlschema_ns_uri_hash_gDay;
extern caddr_t uname_xmlschema_ns_uri_hash_gMonth;
extern caddr_t uname_xmlschema_ns_uri_hash_gMonthDay;
extern caddr_t uname_xmlschema_ns_uri_hash_gYear;
extern caddr_t uname_xmlschema_ns_uri_hash_gYearMonth;
extern caddr_t uname_xmlschema_ns_uri_hash_hexBinary;
extern caddr_t uname_xmlschema_ns_uri_hash_int;
extern caddr_t uname_xmlschema_ns_uri_hash_integer;
extern caddr_t uname_xmlschema_ns_uri_hash_language;
extern caddr_t uname_xmlschema_ns_uri_hash_long;
extern caddr_t uname_xmlschema_ns_uri_hash_negativeInteger;
extern caddr_t uname_xmlschema_ns_uri_hash_nonNegativeInteger;
extern caddr_t uname_xmlschema_ns_uri_hash_nonPositiveInteger;
extern caddr_t uname_xmlschema_ns_uri_hash_normalizedString;
extern caddr_t uname_xmlschema_ns_uri_hash_positiveInteger;
extern caddr_t uname_xmlschema_ns_uri_hash_short;
extern caddr_t uname_xmlschema_ns_uri_hash_string;
extern caddr_t uname_xmlschema_ns_uri_hash_time;
extern caddr_t uname_xmlschema_ns_uri_hash_token;
extern caddr_t uname_xmlschema_ns_uri_hash_unsignedByte;
extern caddr_t uname_xmlschema_ns_uri_hash_unsignedInt;
extern caddr_t uname_xmlschema_ns_uri_hash_unsignedLong;
extern caddr_t uname_xmlschema_ns_uri_hash_unsignedShort;
extern caddr_t unames_colon_number[20];

#endif
