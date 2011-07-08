/*
 *  clrdf.c
 *
 *  $Id$
 *
 *  RDF funcs for cluster
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2011 OpenLink Software
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

#include "sqlnode.h"
#include "sqlbif.h"
#include "rdf_core.h"
#include "sqlcmps.h"
#include "sqlo.h"
#include "rdfinf.h"


id_hash_t *
dict_ht (id_hash_iterator_t * dict)
{
  if (DV_DICT_ITERATOR == DV_TYPE_OF (dict))
    return ((id_hash_iterator_t *)dict)->hit_hash;
  return NULL;
}


caddr_t
cl_id_to_iri (query_instance_t * qi, caddr_t id)
{
  GPF_T;
  return NULL;
}
