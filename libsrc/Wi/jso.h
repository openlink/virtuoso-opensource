/*
 *  jso.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2006 OpenLink Software
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
 *  
 */

#ifndef __JSO_H
#define __JSO_H
#include "Dk.h"
#include "xmltree.h"

#define JSO_OPTIONAL	11
#define JSO_INHERITABLE	12
#define JSO_REQUIRED	13
#define JSO_DEPRECATED	14

#define JSO_ANY		"http://www.w3.org/2001/XMLSchema#any"
#define JSO_BOOLEAN	"http://www.w3.org/2001/XMLSchema#boolean"
#define JSO_BITMASK	"http://www.openlinksw.com/schemas/virtrdf#bitmask"
#define JSO_DOUBLE	"http://www.w3.org/2001/XMLSchema#double"
#define JSO_INTEGER	"http://www.w3.org/2001/XMLSchema#integer"
#define JSO_STRING	"http://www.w3.org/2001/XMLSchema#string"

#define JSO_FIELD_OFFSET(dt,f) (((char *)(&(((dt *)NULL)->f)))-((char *)NULL))

typedef struct jso_field_descr_s {
  const char *	jsofd_property_iri;
  const char *	jsofd_local_name;
  const char *	jsofd_type;
  int		jsofd_required;
  ptrdiff_t	jsofd_byte_offset;
  struct jso_class_descr_s *	jsofd_class;
} jso_field_descr_t;

#define JSO_CAT_STRUCT 21
#define JSO_CAT_ARRAY 22

typedef struct jso_struct_descr_s {
  size_t	jsosd_sizeof;
  int		jsosd_field_count;
  jso_field_descr_t *	jsosd_field_list;
  dk_hash_t *	jsosd_field_hash;
} jso_struct_descr_t;

typedef struct jso_array_descr_s {
  const char *	jsoad_member_type;
  int		jsoad_min_length;
  int		jsoad_max_length;
} jso_array_descr_t;

typedef struct jso_class_descr_s {
  int		jsocd_cat;
  const char *	jsocd_c_typedef;
  const char *  jsocd_class_iri;
  const char *	jsocd_ns_uri;
  const char *	jsocd_local_name;
  dk_hash_t *	jsocd_rttis;
  struct {
    jso_struct_descr_t sd;
    jso_array_descr_t ad;
    } _;
} jso_class_descr_t;

#define JSO_STATUS_NEW 31
#define JSO_STATUS_LOADED 32
#define JSO_STATUS_FAILED 33
#define JSO_STATUS_DELETED 34

typedef struct jso_rtti_s {
  void *	jrtti_self;
  caddr_t	jrtti_inst_iri;
  jso_class_descr_t *	jrtti_class;
  int		jrtti_status;
} jso_rtti_t;

extern void jso_init (void);
extern void jso_define_class (jso_class_descr_t *jsocd);
extern dk_hash_t *jso_classes;
extern dk_hash_t *jso_properties;
extern dk_hash_t *jso_rttis;

#endif
