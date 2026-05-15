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
 *  Centralizes construction of Virtuoso boxed values handed back to
 *  the SQL runtime at the BIF boundary.  All helpers allocate via
 *  dk_alloc_box; callers MUST NOT reach for libc allocators.
 *
 *  See binsrc/cypher/plugin/PLUGIN_VALUE_ABI.md for the canonical
 *  shape contract.
 */

#ifndef _OPENCYPHER_BOX_H
#define _OPENCYPHER_BOX_H

#include "import_gate_virtuoso.h"

#include <stddef.h>

/* Box a NUL-terminated string as DV_STRING.  Returns a fresh box
 * owned by the caller.  Empty strings are allowed; NULL input is
 * boxed as an empty string so callers do not have to branch. */
caddr_t opencypher_box_string (const char *text);

/* Box exactly len bytes (plus a trailing NUL) from text as
 * DV_STRING.  text may be NULL only when len == 0. */
caddr_t opencypher_box_string_n (const char *text, size_t len);

/* Box a token tuple as DV_ARRAY_OF_POINTER of length 5:
 *   [type, text, pos, line, col]
 * text may be NULL; it is normalized to "". */
caddr_t opencypher_box_token (long type, const char *text,
                         long pos, long line, long col);

/* Box a SPARQL-generation result.  Currently a thin wrapper around
 * opencypher_box_string; reserved for the metadata shape described in
 * PLUGIN_VALUE_ABI.md when the EMIT_META flag is wired through. */
caddr_t opencypher_box_sparql_result (const char *sparql_text);

#endif /* _OPENCYPHER_BOX_H */
