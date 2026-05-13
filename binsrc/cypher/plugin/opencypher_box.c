/*
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2026 OpenLink Software
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

/*
 *  openCypher plugin boxed value helpers
 *
 *  All boxed values returned to Virtuoso flow through this file so
 *  the allocator and shape rules in PLUGIN_VALUE_ABI.md live in one
 *  place.  Internal scratch must come from the arena; this file is
 *  the only place dk_alloc_box is called for runtime-bound values.
 */

#include "opencypher_box.h"

#include <string.h>

caddr_t
opencypher_box_string (const char *text)
{
  size_t len;
  caddr_t box;

  if (text == NULL)
    text = "";
  len = strlen (text);
  box = dk_alloc_box (len + 1, DV_STRING);
  memcpy (box, text, len + 1);
  return box;
}

caddr_t
opencypher_box_string_n (const char *text, size_t len)
{
  caddr_t box;

  box = dk_alloc_box (len + 1, DV_STRING);
  if (len > 0)
    memcpy (box, text, len);
  box[len] = '\0';
  return box;
}

caddr_t
opencypher_box_token (long type, const char *text,
                 long pos, long line, long col)
{
  caddr_t *item;

  item = (caddr_t *) dk_alloc_box (sizeof (caddr_t) * 5,
                                   DV_ARRAY_OF_POINTER);
  item[0] = box_num (type);
  item[1] = opencypher_box_string (text);
  item[2] = box_num (pos);
  item[3] = box_num (line);
  item[4] = box_num (col);
  return (caddr_t) item;
}

caddr_t
opencypher_box_sparql_result (const char *sparql_text)
{
  return opencypher_box_string (sparql_text);
}
