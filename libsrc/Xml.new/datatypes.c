/*
 *  datatypes.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2016 OpenLink Software
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
#include "schema.h"
#include "pcre.h"

ptrlong
xs_get_primitive_typeidx (vxml_parser_t * parser, xs_component_t *type)
{
  xs_component_t *base_type;
  if (!IS_BOX_POINTER (type))
    base_type = type;
  else
    {
      xs_component_t *type_cm = (xs_component_t *) type;
      xs_component_t *root = get_root_type (parser, type_cm);
      if (!root)
	{
	  xs_set_error (parser, XCFG_DETAILS, 200,
	      "Could not resolve base type for '%s'", type_cm->cm_qname);
	  return -1;
	}
      base_type = root->cm_typename;
    }
  return (ptrlong)base_type;
}

extern caddr_t regexp_match_01 (const char* pattern, const char* str, int c_opts);

int
xs_check_type_compliance (vxml_parser_t * parser, xs_component_t *type,
    const char * value, int err_options)
{
  ptrlong base_type_idx;
  const char *basetype_regexp;
/*  XS_ASSERT(IS_COMPLEX_TYPE((type) || IS_SIMPLE_TYPE(type)); */

  base_type_idx = xs_get_primitive_typeidx (parser, type);
  if (base_type_idx == -1)
    {
      xmlparser_logprintf (parser, XCFG_ERROR | err_options, 200 + utf8len (value),
	  "Value '%s' could not be checked due to undefined type", value);
      return XS_ROOT_TYPE_ERROR;
    }
  basetype_regexp = xs_builtin_type_info_dict[base_type_idx].binfo_regexp_or_null;
  if (NULL != basetype_regexp)
    {
      int match_len = 1;
      caddr_t match = regexp_match_01 (basetype_regexp, (const char *) value, PCRE_UTF8);
      if (match)
	{
	  match_len = box_length (match);
          dk_free_box (match);
          if ((strlen ((caddr_t) value) + 1) == match_len)
            match_len = 0;
        }
      if (match_len)
	{
	  if ('\0' == value[0])
	    {
	      xs_set_error (parser, XCFG_ERROR | err_options, 300,
		"Empty string does not match expected pattern '%s' for type '%s'",
		basetype_regexp,
		xs_builtin_type_info_dict[base_type_idx].binfo_name );
	    }
	  else
	    {
	      char *err_line = dk_alloc_box (match_len + 1, DV_SHORT_STRING);
	      memset (err_line, '-', match_len - 1);
	      err_line[match_len - 1] = '^';
	      err_line[match_len] = '\0';
	      xs_set_error (parser, XCFG_ERROR | err_options, 300 + utf8len (value) + match_len,
		"Value does not match expected pattern '%s' for type '%s':\nValue='%s'\n-------%s",
		basetype_regexp,
		xs_builtin_type_info_dict[base_type_idx].binfo_name, value, err_line);
	      dk_free_box (err_line);
	      SHOULD_BE_CHANGED;	/* errors handling */
	    }
	}
      return match_len;
    }
  return 0;
}
