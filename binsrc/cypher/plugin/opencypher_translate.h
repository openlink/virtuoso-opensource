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
 *  openCypher Translator - Header
 *
 *  Cypher to SPARQL translation interface.
 */

#ifndef _OPENCYPHER_TRANSLATE_H
#define _OPENCYPHER_TRANSLATE_H

#include "import_gate_virtuoso.h"

/* Initialize the translator subsystem */
extern void opencypher_translate_init (void);

/* Cleanup the translator subsystem */
extern void opencypher_translate_cleanup (void);

extern int opencypher_translate_exec_sql_1 (caddr_t sql_text,
                                       caddr_t param0,
                                       caddr_t *result,
                                       caddr_t *err_msg);

extern int opencypher_translate_exec_sql_2 (caddr_t sql_text,
                                       caddr_t param0,
                                       caddr_t param1,
                                       caddr_t *result,
                                       caddr_t *err_msg);

extern int opencypher_translate_parse (caddr_t cypher_query,
                                  int32 flags,
                                  caddr_t *result,
                                  caddr_t *error_msg);

extern int opencypher_translate_plan (caddr_t cypher_query,
                                 int32 flags,
                                 caddr_t *result,
                                 caddr_t *error_msg);

extern int opencypher_translate_gen_sparql (caddr_t cypher_query,
                                       caddr_t graph_uri,
                                       int32 flags,
                                       caddr_t *result,
                                       caddr_t *error_msg);

/*
 * Translate Cypher query to SPARQL
 *
 * Parameters:
 *   cypher_query - input Cypher query string
 *   graph_uri    - default graph URI (can be NULL)
 *   params       - query parameters (can be NULL)
 *   flags        - translation flags
 *   result       - output SPARQL string (allocated with dk_alloc_box)
 *   error_msg    - error message if translation fails (allocated with dk_alloc_box)
 *
 * Returns:
 *   0 on success, non-zero on error
 */
extern int opencypher_translate_cypher_to_sparql (caddr_t cypher_query,
                                               caddr_t graph_uri,
                                               caddr_t params,
                                               int32 flags,
                                               caddr_t *result,
                                               caddr_t *error_msg);

/* Translation flags */
#define OPENCYPHER_FLAG_DEBUG        0x0001  /* Enable debug output */
#define OPENCYPHER_FLAG_VALIDATE     0x0002  /* Validate plan before translation */
#define OPENCYPHER_FLAG_PRESERVE_COMMENTS 0x0004  /* Preserve comments in output */

#endif /* _OPENCYPHER_TRANSLATE_H */
