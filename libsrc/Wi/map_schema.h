/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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

#include "xpathp_impl.h"
#include "libutil.h"
#include "sqlnode.h"
#include "sqlpar.h"
#include "sqlpfn.h"
/*#include "sqlcmps.h"*/
#include "sqlfn.h"
#include "xml.h"
#include "xmlgen.h"
#include "xmltree.h"
#include "text.h"
#include "multibyte.h"
#include "bif_text.h"
#include "xpf.h"
/*#include "xpathp.h"*/
#ifdef __cplusplus
extern "C" {
#endif
#include "langfunc.h"
#include "xmlparser_impl.h"
#include "schema.h"
#ifdef __cplusplus
}
#endif

/*mapping schema*/
#define XS_NAME_DELIMETER '#'
#define XS_VIEW_DELIMETER '.'
#define XS_BLANC ' '

extern xml_view_t* mapping_schema_to_xml_view (schema_parsed_t * schema);
extern void xmls_proc (query_instance_t * qi, caddr_t name);
extern void mpschema_set_view_def (char *name, caddr_t tree);
extern caddr_t  tables_from_mapping_schema (schema_parsed_t * schema, client_connection_t * qi_client);

caddr_t get_view_name (utf8char * fullname, char sign);
void xmlview_free (xml_view_t * xv);/*mapping schema*/
int
VXmlTree_Parse (vxml_parser_t * parser, xml_entity_t * xml_ent, caddr_t schema_name, caddr_t type_name);

#define _COMMA(text, len, fill, first) \
  if (!first) \
    sprintf_more (text, len, fill, ", "); \
  else \
    first = 0;


typedef struct foreign_key_s
{
  caddr_t field;
  caddr_t ref_table;
  caddr_t ref_field;
} foreign_key_t;

typedef struct table_mapping_schema_s
{
  caddr_t name;
  dk_set_t fields;
  dk_set_t fields_types;
  dk_set_t keys;
  dk_set_t foreign_keys;
} table_mapping_schema_t;
