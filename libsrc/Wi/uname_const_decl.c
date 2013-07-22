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

#include "Dk.h"
#include "xmlparser.h" /* For XML_NS_URI etc. */
#include "uname_const_decl.h"

caddr_t uname__bang_cdata_section_elements;
caddr_t uname__bang_exclude_result_prefixes;
caddr_t uname__bang_file;
caddr_t uname__bang_location;
caddr_t uname__bang_name;
caddr_t uname__bang_ns;
caddr_t uname__bang_uri;
caddr_t uname__bang_use_attribute_sets;
caddr_t uname__bang_xmlns;
caddr_t uname__attr;
caddr_t uname__comment;
caddr_t uname__disable_output_escaping;
caddr_t uname__root;
caddr_t uname__pi;
caddr_t uname__ref;
caddr_t uname__srcfile;
caddr_t uname__srcline;
caddr_t uname__txt;
caddr_t uname__xslt;
caddr_t uname_SPECIAL_cc_bif_c_AVG;
caddr_t uname_SPECIAL_cc_bif_c_COUNT;
caddr_t uname_SPECIAL_cc_bif_c_MAX;
caddr_t uname_SPECIAL_cc_bif_c_MIN;
caddr_t uname_SPECIAL_cc_bif_c_SUM;
caddr_t uname_lang;
caddr_t uname_nil;
caddr_t uname_nodeID_ns;
caddr_t uname_rdf_ns_uri;
caddr_t uname_rdf_ns_uri_Description;
caddr_t uname_rdf_ns_uri_ID;
caddr_t uname_rdf_ns_uri_RDF;
caddr_t uname_rdf_ns_uri_Seq;
caddr_t uname_rdf_ns_uri_Statement;
caddr_t uname_rdf_ns_uri_XMLLiteral;
caddr_t uname_rdf_ns_uri_about;
caddr_t uname_rdf_ns_uri_first;
caddr_t uname_rdf_ns_uri_li;
caddr_t uname_rdf_ns_uri_nil;
caddr_t uname_rdf_ns_uri_nodeID;
caddr_t uname_rdf_ns_uri_object;
caddr_t uname_rdf_ns_uri_predicate;
caddr_t uname_rdf_ns_uri_resource;
caddr_t uname_rdf_ns_uri_rest;
caddr_t uname_rdf_ns_uri_subject;
caddr_t uname_rdf_ns_uri_type;
caddr_t uname_rdf_ns_uri_datatype;
caddr_t uname_rdf_ns_uri_parseType;
caddr_t uname_rdf_ns_uri_value;
caddr_t uname_rdfdf_ns_uri;
caddr_t uname_rdfdf_ns_uri_default;
caddr_t uname_rdfdf_ns_uri_default_nullable;
caddr_t uname_rdfdf_ns_uri_default_iid;
caddr_t uname_rdfdf_ns_uri_default_iid_nullable;
caddr_t uname_space;
caddr_t uname_swap_reify_ns_uri;
caddr_t uname_swap_reify_ns_uri_statement;
caddr_t uname_virtrdf_ns_uri;
caddr_t uname_virtrdf_ns_uri_DefaultQuadMap;
caddr_t uname_virtrdf_ns_uri_DefaultQuadStorage;
caddr_t uname_virtrdf_ns_uri_DefaultServiceStorage;
caddr_t uname_virtrdf_ns_uri_DefaultSparul11Target;
caddr_t uname_virtrdf_ns_uri_PrivateGraphs;
caddr_t uname_virtrdf_ns_uri_QuadMap;
caddr_t uname_virtrdf_ns_uri_QuadMapFormat;
caddr_t uname_virtrdf_ns_uri_QuadStorage;
caddr_t uname_virtrdf_ns_uri_SparqlMacroLibrary;
caddr_t uname_virtrdf_ns_uri_SyncToQuads;
caddr_t uname_virtrdf_ns_uri_array_of_any;
caddr_t uname_virtrdf_ns_uri_array_of_string;
caddr_t uname_virtrdf_ns_uri_bitmask;
caddr_t uname_virtrdf_ns_uri_bnode_base;
caddr_t uname_virtrdf_ns_uri_bnode_label;
caddr_t uname_virtrdf_ns_uri_bnode_row;
caddr_t uname_virtrdf_ns_uri_dialect;
caddr_t uname_virtrdf_ns_uri_isSpecialPredicate;
caddr_t uname_virtrdf_ns_uri_isSubclassOf;
caddr_t uname_virtrdf_ns_uri_loadAs;
caddr_t uname_virtrdf_ns_uri_rdf_repl_graph_group;
caddr_t uname_virtrdf_ns_uri_rdf_repl_all;
caddr_t uname_xhv_ns_uri;
caddr_t uname_xhv_ns_uri_alternate;
caddr_t uname_xhv_ns_uri_appendix;
caddr_t uname_xhv_ns_uri_bookmark;
caddr_t uname_xhv_ns_uri_chapter;
caddr_t uname_xhv_ns_uri_cite;
caddr_t uname_xhv_ns_uri_contents;
caddr_t uname_xhv_ns_uri_copyright;
caddr_t uname_xhv_ns_uri_first;
caddr_t uname_xhv_ns_uri_glossary;
caddr_t uname_xhv_ns_uri_help;
caddr_t uname_xhv_ns_uri_icon;
caddr_t uname_xhv_ns_uri_index;
caddr_t uname_xhv_ns_uri_last;
caddr_t uname_xhv_ns_uri_license;
caddr_t uname_xhv_ns_uri_meta;
caddr_t uname_xhv_ns_uri_next;
caddr_t uname_xhv_ns_uri_p3pv1;
caddr_t uname_xhv_ns_uri_prev;
caddr_t uname_xhv_ns_uri_role;
caddr_t uname_xhv_ns_uri_section;
caddr_t uname_xhv_ns_uri_start;
caddr_t uname_xhv_ns_uri_stylesheet;
caddr_t uname_xhv_ns_uri_subsection;
caddr_t uname_xhv_ns_uri_up;
caddr_t uname_xml;
caddr_t uname_xmlns;
caddr_t uname_xml_colon_base;
caddr_t uname_xml_colon_lang;
caddr_t uname_xml_colon_space;
caddr_t uname_xml_ns_uri;
caddr_t uname_xml_ns_uri_colon_base;
caddr_t uname_xml_ns_uri_colon_lang;
caddr_t uname_xml_ns_uri_colon_space;
caddr_t uname_xmlschema_ns_uri;
caddr_t uname_xmlschema_ns_uri_hash;
caddr_t uname_xmlschema_ns_uri_hash_any;
caddr_t uname_xmlschema_ns_uri_hash_anyURI;
caddr_t uname_xmlschema_ns_uri_hash_boolean;
caddr_t uname_xmlschema_ns_uri_hash_bitmask;
caddr_t uname_xmlschema_ns_uri_hash_date;
caddr_t uname_xmlschema_ns_uri_hash_dateTime;
caddr_t uname_xmlschema_ns_uri_hash_decimal;
caddr_t uname_xmlschema_ns_uri_hash_double;
caddr_t uname_xmlschema_ns_uri_hash_float;
caddr_t uname_xmlschema_ns_uri_hash_integer;
caddr_t uname_xmlschema_ns_uri_hash_string;
caddr_t uname_xmlschema_ns_uri_hash_time;
caddr_t unames_colon_number[20];

typedef struct uname_const_decl_s
{
  caddr_t *var_ptr;
  const char *text;
} uname_const_decl_t;

void
uname_const_decl_init (void)
{
  int ctr;
#define UNAME_IT(var,txt) var = box_dv_uname_string (txt); box_dv_uname_make_immortal (var)

static uname_const_decl_t uname_const_decls[] = {
  { &uname__bang_cdata_section_elements		, " !cdata-section-elements"	},
  { &uname__bang_exclude_result_prefixes	, " !exclude_result_prefixes"	},
  { &uname__bang_file				, " !file"			},
  { &uname__bang_location			, " !location"			},
  { &uname__bang_name				, " !name"			},
  { &uname__bang_ns				, " !ns"			},
  { &uname__bang_uri				, " !uri"			},
  { &uname__bang_use_attribute_sets		, " !use-attribute-sets"		},
  { &uname__bang_xmlns				, " !xmlns"			},
  { &uname__attr				, " attr"			},
  { &uname__comment				, " comment"			},
  { &uname__disable_output_escaping		, " disable-output-escaping"	},
  { &uname__root				, " root"			},
  { &uname__pi					, " pi"				},
  { &uname__ref					, " ref"			},
  { &uname__srcfile				, " srcfile"			},
  { &uname__srcline				, " srcline"			},
  { &uname__txt					, " txt"			},
  { &uname__xslt				, " xslt"			},
  { &uname_SPECIAL_cc_bif_c_AVG			, "SPECIAL::bif:AVG"		},
  { &uname_SPECIAL_cc_bif_c_COUNT		, "SPECIAL::bif:COUNT"		},
  { &uname_SPECIAL_cc_bif_c_MAX			, "SPECIAL::bif:MAX"		},
  { &uname_SPECIAL_cc_bif_c_MIN			, "SPECIAL::bif:MIN"		},
  { &uname_SPECIAL_cc_bif_c_SUM			, "SPECIAL::bif:SUM"		},
  { &uname_lang					, "lang"			},
  { &uname_nil					, "nil"				},
  { &uname_nodeID_ns				, "nodeID://"			},
  { &uname_rdf_ns_uri				, RDF_NS_URI			},
  { &uname_rdf_ns_uri_Description		, RDF_NS_URI "Description"	},
  { &uname_rdf_ns_uri_ID			, RDF_NS_URI "ID"		},
  { &uname_rdf_ns_uri_RDF			, RDF_NS_URI "RDF"		},
  { &uname_rdf_ns_uri_Seq			, RDF_NS_URI "Seq"		},
  { &uname_rdf_ns_uri_Statement			, RDF_NS_URI "Statement"	},
  { &uname_rdf_ns_uri_XMLLiteral		, RDF_NS_URI "XMLLiteral"	},
  { &uname_rdf_ns_uri_about			, RDF_NS_URI "about"		},
  { &uname_rdf_ns_uri_first			, RDF_NS_URI "first"		},
  { &uname_rdf_ns_uri_li			, RDF_NS_URI "li"		},
  { &uname_rdf_ns_uri_nil			, RDF_NS_URI "nil"		},
  { &uname_rdf_ns_uri_nodeID			, RDF_NS_URI "nodeID"		},
  { &uname_rdf_ns_uri_object			, RDF_NS_URI "object"		},
  { &uname_rdf_ns_uri_predicate			, RDF_NS_URI "predicate"	},
  { &uname_rdf_ns_uri_resource			, RDF_NS_URI "resource"		},
  { &uname_rdf_ns_uri_subject			, RDF_NS_URI "subject"		},
  { &uname_rdf_ns_uri_rest			, RDF_NS_URI "rest"		},
  { &uname_rdf_ns_uri_type			, RDF_NS_URI "type"		},
  { &uname_rdf_ns_uri_datatype			, RDF_NS_URI "datatype"		},
  { &uname_rdf_ns_uri_parseType			, RDF_NS_URI "parseType"	},
  { &uname_rdf_ns_uri_value			, RDF_NS_URI "value"		},
  { &uname_rdfdf_ns_uri				, RDFDF_NS_URI			},
  { &uname_rdfdf_ns_uri_default			, RDFDF_NS_URI "default"	},
  { &uname_rdfdf_ns_uri_default_nullable	, RDFDF_NS_URI "default-nullable"	},
  { &uname_rdfdf_ns_uri_default_iid		, RDFDF_NS_URI "default-iid"	},
  { &uname_rdfdf_ns_uri_default_iid_nullable	, RDFDF_NS_URI "default-iid-nullable"	},
  { &uname_space				, "space"			},
  { &uname_swap_reify_ns_uri			, SWAP_REIFY_NS_URI		},
  { &uname_swap_reify_ns_uri_statement		, SWAP_REIFY_NS_URI "statement"	},
  { &uname_virtrdf_ns_uri			, VIRTRDF_NS_URI		},
  { &uname_virtrdf_ns_uri_DefaultQuadMap	, VIRTRDF_NS_URI "DefaultQuadMap"	},
  { &uname_virtrdf_ns_uri_DefaultQuadStorage	, VIRTRDF_NS_URI "DefaultQuadStorage"	},
  { &uname_virtrdf_ns_uri_DefaultServiceStorage	, VIRTRDF_NS_URI "DefaultServiceStorage"	},
  { &uname_virtrdf_ns_uri_DefaultSparul11Target	, VIRTRDF_NS_URI "DefaultSparul11Target"	},
  { &uname_virtrdf_ns_uri_PrivateGraphs		, VIRTRDF_NS_URI "PrivateGraphs"	},
  { &uname_virtrdf_ns_uri_QuadMap		, VIRTRDF_NS_URI "QuadMap"	},
  { &uname_virtrdf_ns_uri_QuadMapFormat		, VIRTRDF_NS_URI "QuadMapFormat"	},
  { &uname_virtrdf_ns_uri_QuadStorage		, VIRTRDF_NS_URI "QuadStorage"	},
  { &uname_virtrdf_ns_uri_SparqlMacroLibrary	, VIRTRDF_NS_URI "SparqlMacroLibrary"	},
  { &uname_virtrdf_ns_uri_SyncToQuads		, VIRTRDF_NS_URI "SyncToQuads"	},
  { &uname_virtrdf_ns_uri_array_of_any		, VIRTRDF_NS_URI "array-of-any"	},
  { &uname_virtrdf_ns_uri_array_of_string	, VIRTRDF_NS_URI "array-of-string"	},
  { &uname_virtrdf_ns_uri_bitmask		, VIRTRDF_NS_URI "bitmask"	},
  { &uname_virtrdf_ns_uri_bnode_base		, VIRTRDF_NS_URI "bnode-base"	},
  { &uname_virtrdf_ns_uri_bnode_label		, VIRTRDF_NS_URI "bnode-label"	},
  { &uname_virtrdf_ns_uri_bnode_row		, VIRTRDF_NS_URI "bnode-row"	},
  { &uname_virtrdf_ns_uri_dialect		, VIRTRDF_NS_URI "dialect"	},
  { &uname_virtrdf_ns_uri_isSpecialPredicate	, VIRTRDF_NS_URI "isSpecialPredicate"	},
  { &uname_virtrdf_ns_uri_isSubclassOf		, VIRTRDF_NS_URI "isSubclassOf"	},
  { &uname_virtrdf_ns_uri_loadAs		, VIRTRDF_NS_URI "loadAs"	},
  { &uname_virtrdf_ns_uri_rdf_repl_graph_group	, VIRTRDF_NS_URI "rdf_repl_graph_group"	},
  { &uname_virtrdf_ns_uri_rdf_repl_all		, VIRTRDF_NS_URI "rdf_repl_all"	},
  { &uname_xhv_ns_uri				, XHV_NS_URI			},
  { &uname_xhv_ns_uri_alternate			, XHV_NS_URI "alternate"	},
  { &uname_xhv_ns_uri_appendix			, XHV_NS_URI "appendix"		},
  { &uname_xhv_ns_uri_bookmark			, XHV_NS_URI "bookmark"		},
  { &uname_xhv_ns_uri_chapter			, XHV_NS_URI "chapter"		},
  { &uname_xhv_ns_uri_cite			, XHV_NS_URI "cite"		},
  { &uname_xhv_ns_uri_contents			, XHV_NS_URI "contents"		},
  { &uname_xhv_ns_uri_copyright			, XHV_NS_URI "copyright"	},
  { &uname_xhv_ns_uri_first			, XHV_NS_URI "first"		},
  { &uname_xhv_ns_uri_glossary			, XHV_NS_URI "glossary"		},
  { &uname_xhv_ns_uri_help			, XHV_NS_URI "help"		},
  { &uname_xhv_ns_uri_icon			, XHV_NS_URI "icon"		},
  { &uname_xhv_ns_uri_index			, XHV_NS_URI "index"		},
  { &uname_xhv_ns_uri_last			, XHV_NS_URI "last"		},
  { &uname_xhv_ns_uri_license			, XHV_NS_URI "license"		},
  { &uname_xhv_ns_uri_meta			, XHV_NS_URI "meta"		},
  { &uname_xhv_ns_uri_next			, XHV_NS_URI "next"		},
  { &uname_xhv_ns_uri_p3pv1			, XHV_NS_URI "p3pv1"		},
  { &uname_xhv_ns_uri_prev			, XHV_NS_URI "prev"		},
  { &uname_xhv_ns_uri_role			, XHV_NS_URI "role"		},
  { &uname_xhv_ns_uri_section			, XHV_NS_URI "section"		},
  { &uname_xhv_ns_uri_start			, XHV_NS_URI "start"		},
  { &uname_xhv_ns_uri_stylesheet		, XHV_NS_URI "stylesheet"	},
  { &uname_xhv_ns_uri_subsection		, XHV_NS_URI "subsection"	},
  { &uname_xhv_ns_uri_up			, XHV_NS_URI "up"		},
  { &uname_xml					, "xml"				},
  { &uname_xmlns				, "xmlns"			},
  { &uname_xml_colon_base			, "xml:base"			},
  { &uname_xml_colon_lang			, "xml:lang"			},
  { &uname_xml_colon_space			, "xml:space"			},
  { &uname_xml_ns_uri				, XML_NS_URI			},
  { &uname_xml_ns_uri_colon_base		, XML_NS_URI ":base"		},
  { &uname_xml_ns_uri_colon_lang		, XML_NS_URI ":lang"		},
  { &uname_xml_ns_uri_colon_space		, XML_NS_URI ":space"		},
  { &uname_xmlschema_ns_uri			, XMLSCHEMA_NS_URI		},
  { &uname_xmlschema_ns_uri_hash		, XMLSCHEMA_NS_URI "#"		},
  { &uname_xmlschema_ns_uri_hash_any		, XMLSCHEMA_NS_URI "#any"	},
  { &uname_xmlschema_ns_uri_hash_anyURI		, XMLSCHEMA_NS_URI "#anyURI"	},
  { &uname_xmlschema_ns_uri_hash_boolean	, XMLSCHEMA_NS_URI "#boolean"	},
  { &uname_xmlschema_ns_uri_hash_date		, XMLSCHEMA_NS_URI "#date"	},
  { &uname_xmlschema_ns_uri_hash_dateTime	, XMLSCHEMA_NS_URI "#dateTime"	},
  { &uname_xmlschema_ns_uri_hash_decimal	, XMLSCHEMA_NS_URI "#decimal"	},
  { &uname_xmlschema_ns_uri_hash_double		, XMLSCHEMA_NS_URI "#double"	},
  { &uname_xmlschema_ns_uri_hash_float		, XMLSCHEMA_NS_URI "#float"	},
  { &uname_xmlschema_ns_uri_hash_integer	, XMLSCHEMA_NS_URI "#integer"	},
  { &uname_xmlschema_ns_uri_hash_string		, XMLSCHEMA_NS_URI "#string"	},
  { &uname_xmlschema_ns_uri_hash_time		, XMLSCHEMA_NS_URI "#time"	},
  { NULL, NULL } };

  uname_const_decl_t *tail = uname_const_decls;
  while (NULL != tail->var_ptr)
    {
      UNAME_IT (tail->var_ptr[0], tail->text);
      tail++;
    }
  for (ctr = 0; ctr < (sizeof (unames_colon_number) / sizeof (caddr_t)); ctr++)
    {
      char tmp[15];
      sprintf (tmp, ":%d", ctr);
      UNAME_IT((unames_colon_number[ctr]), tmp);
    }
}
