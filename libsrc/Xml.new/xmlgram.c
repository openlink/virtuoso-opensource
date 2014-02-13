/*
 *  xmlgram.c
 *
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

#include "xmlparser_impl.h"

void
push_tag (vxml_parser_t * parser)
{
  opened_tag_t *tag;
  tag = ++(parser->inner_tag);
  SET_STATE(XML_A_CHAR);
  tag->ot_name = parser->tmp.flat_name;
  parser->tmp.flat_name.lm_memblock = NULL;
  tag->ot_descr = parser->tmp.tag_descr;
  tag->ot_pos = parser->curr_pos;
}

int
pop_tag (vxml_parser_t * parser)
{
  int ns_ctr;
  opened_tag_t *tag = parser->inner_tag;
  if (tag == parser->tag_stack_holder)
    return 0;
  ns_ctr = parser->attrdata.all_nsdecls_count;
  while (ns_ctr--)
    {
      nsdecl_t *ns = parser->nsdecl_array + ns_ctr;
      if (ns->nsd_tag < parser->inner_tag)
	break;
      dk_free_box (ns->nsd_prefix);
      dk_free_box (ns->nsd_uri);
    }
  parser->attrdata.all_nsdecls_count = ns_ctr + 1;
  dk_free (tag->ot_name.lm_memblock, -1);
  parser->inner_tag--;
  if (tag == parser->tag_stack_holder)
    CLR_STATE(XML_A_CHAR);
  return 1;
}


void
free_attr_array (vxml_parser_t * parser)
{
  int ctr = parser->attrdata.local_attrs_count;
  while (ctr--)
    {
      tag_attr_t * att = parser->tmp.attr_array+ctr;
      dk_free (att->ta_raw_name.lm_memblock, -1);
      dk_free_box (att->ta_value);
    }
  parser->attrdata.local_attrs_count = 0;
}


/* IvAn/ParseDTD/000721 Reference dictionary support */

/*! \brief Stores description of the reference in parser's internal dictionary
\return zero if new entry, nonzero if re-definition detected. */
int xml_set_ref_value(
  vxml_parser_t * parser,
  char *refname,
  int reflen,
  char *uritext,
  int urilen
  )
{
  return 0;
}

/*! \brief Retrieves description of the reference from parser's internal dictionary
\return previously stored URI or NULL if no such reference found. */
char *xml_get_ref_value(
  vxml_parser_t * parser,
  char *refname,
  int reflen
  )
{
  return NULL;
}
