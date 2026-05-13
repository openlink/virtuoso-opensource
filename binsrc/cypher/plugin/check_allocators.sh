#!/bin/sh
#
#  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
#  project.
#
#  Copyright (C) 1998-2026 OpenLink Software
#
#  This project is free software; you can redistribute it and/or modify it
#  under the terms of the GNU General Public License as published by the
#  Free Software Foundation; only version 2 of the License, dated June 1991.
#
#  This program is distributed in the hope that it will be useful, but
#  WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
#
#
#
# openCypher plugin allocator and value-ABI guardrail.
#
# Enforces the rules in PLUGIN_VALUE_ABI.md:
#   1. No direct libc allocators in plugin C code.
#   2. dk_alloc_box construction of runtime-bound boxes happens
#      through opencypher_box.* helpers (opencypher_box.c is the single
#      sanctioned site; opencypher_lexer.c may keep one inline call for
#      the outer DV_ARRAY_OF_POINTER backing the token stream).
#
# Run via `make check-allocators` or directly:
#   sh binsrc/cypher/plugin/check_allocators.sh

set -eu

dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

# Rule 1: forbidden libc allocators.  strdup/strndup/asprintf/vasprintf
# all return libc-allocated storage that cannot be handed to the SQL
# runtime, so they are banned alongside malloc/calloc/realloc/free.
forbidden='\b(malloc|calloc|realloc|free|strdup|strndup|asprintf|vasprintf)\s*\('
if grep -nE "$forbidden" "$dir"/*.[ch] 2>/dev/null; then
  echo "Direct libc allocator usage is not allowed in openCypher plugin code." >&2
  echo "Use dk_alloc(), dk_alloc_box(), dk_free(), dk_free_box(), or the" >&2
  echo "opencypher_box_* helpers in opencypher_box.h." >&2
  exit 1
fi

# Rule 2: opencypher_box.h must exist and declare the boundary helpers.
required_helpers='opencypher_box_string opencypher_box_string_n opencypher_box_token opencypher_box_sparql_result'
for sym in $required_helpers; do
  if ! grep -q "$sym" "$dir/opencypher_box.h"; then
    echo "opencypher_box.h is missing required helper '$sym'." >&2
    echo "See PLUGIN_VALUE_ABI.md for the boundary helper contract." >&2
    exit 1
  fi
done

# Rule 3: token tuples MUST be built via opencypher_box_token, not inline
# dk_alloc_box of a 5-slot DV_ARRAY_OF_POINTER.  We approximate this
# by rejecting the exact inline pattern outside opencypher_box.c.
if grep -nE 'dk_alloc_box\s*\(\s*sizeof\s*\(\s*caddr_t\s*\)\s*\*\s*5\s*,\s*DV_ARRAY_OF_POINTER' \
    "$dir"/*.c 2>/dev/null \
    | grep -v '^.*opencypher_box\.c:' >&2; then
  echo "Inline 5-slot token tuple allocation is not allowed outside opencypher_box.c." >&2
  echo "Use opencypher_box_token() instead." >&2
  exit 1
fi

exit 0
