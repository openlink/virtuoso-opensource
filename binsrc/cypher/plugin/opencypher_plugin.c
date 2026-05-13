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
 *  openCypher VSEI Plugin - C pipeline implementation
 *
 *  Production openCypher parsing and SPARQL generation for Virtuoso.
 *  Uses gate-based plugin model with Virtuoso allocator APIs.
 */

#include "import_gate_virtuoso.h"
#include "sqlver.h"

#include "opencypher_arena.h"
#include "opencypher_lexer.h"
#include "opencypher_translate.h"

#include <string.h>

#define OPENCYPHER_PLUGIN_VERSION_TEXT "openCypher VSEI plugin 0.4.0 - Phase 9"

/* BIF: OPENCYPHER_PLUGIN_VERSION - returns plugin version string */
static caddr_t
bif_opencypher_plugin_version (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t res;
  size_t len;

  len = strlen (OPENCYPHER_PLUGIN_VERSION_TEXT);
  res = dk_alloc_box (len + 1, DV_STRING);
  memcpy (res, OPENCYPHER_PLUGIN_VERSION_TEXT, len + 1);
  return res;
}

/* BIF: OPENCYPHER_PLUGIN_TO_SPARQL - translate Cypher to SPARQL */
static caddr_t
bif_opencypher_plugin_to_sparql (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t cypher_query = bif_string_arg (qst, args, 0, "OPENCYPHER_PLUGIN_TO_SPARQL");
  caddr_t graph_uri = bif_string_or_null_arg (qst, args, 1, "OPENCYPHER_PLUGIN_TO_SPARQL");
  caddr_t params = bif_arg (qst, args, 2, "OPENCYPHER_PLUGIN_TO_SPARQL");
  int32 flags = (int32) bif_long_arg (qst, args, 3, "OPENCYPHER_PLUGIN_TO_SPARQL");

  caddr_t result;
  caddr_t error_msg;
  int rc;

  /* Call the translator */
  rc = opencypher_translate_cypher_to_sparql (cypher_query, graph_uri, params, flags,
                                           &result, &error_msg);

  if (rc != 0)
    {
      /* Translation failed - signal error */
      sqlr_new_error ("VY001", "VPY01", "openCypher translation failed: %s", error_msg);
      return NULL;
    }

  return result;
}

/* BIF: OPENCYPHER_PLUGIN_AVAILABLE - check if plugin is loaded and functional */
static caddr_t
bif_opencypher_plugin_available (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  /* If this BIF is callable, the plugin is available */
  return box_num (1);
}

/* BIF: OPENCYPHER_PLUGIN_TOKENIZE - tokenize Cypher in the C plugin */
static caddr_t
bif_opencypher_plugin_tokenize (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t cypher_query = bif_string_arg (qst, args, 0, "OPENCYPHER_PLUGIN_TOKENIZE");
  opencypher_arena_t arena;
  opencypher_token_stream_t tokens;
  caddr_t error_msg = NULL;
  caddr_t result = NULL;
  int rc;

  opencypher_arena_init (&arena, 4096);
  rc = opencypher_lexer_tokenize (&arena, cypher_query, &tokens, &error_msg);
  if (rc != 0)
    {
      sqlr_new_error ("VY001", "VPY02", "openCypher tokenizer failed: %s",
                      error_msg ? error_msg : "unknown error");
      if (error_msg)
        dk_free_box (error_msg);
      opencypher_arena_destroy (&arena);
      return NULL;
    }

  result = opencypher_lexer_tokens_to_box (&tokens);
  opencypher_arena_destroy (&arena);
  return result;
}

/* BIF: OPENCYPHER_PLUGIN_PARSE - parse Cypher and return the AST */
static caddr_t
bif_opencypher_plugin_parse (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t cypher_query = bif_string_arg (qst, args, 0, "OPENCYPHER_PLUGIN_PARSE");
  int32 flags = (int32) bif_long_arg (qst, args, 1, "OPENCYPHER_PLUGIN_PARSE");
  caddr_t result = NULL;
  caddr_t error_msg = NULL;

  if (opencypher_translate_parse (cypher_query, flags, &result, &error_msg) != 0)
    {
      sqlr_new_error ("VY001", "VPY04", "openCypher parse failed: %s",
                      error_msg ? error_msg : "unknown error");
      return NULL;
    }

  return result;
}

/* BIF: OPENCYPHER_PLUGIN_PLAN - build and return the logical plan */
static caddr_t
bif_opencypher_plugin_plan (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t cypher_query = bif_string_arg (qst, args, 0, "OPENCYPHER_PLUGIN_PLAN");
  int32 flags = (int32) bif_long_arg (qst, args, 1, "OPENCYPHER_PLUGIN_PLAN");
  caddr_t result = NULL;
  caddr_t error_msg = NULL;

  if (opencypher_translate_plan (cypher_query, flags, &result, &error_msg) != 0)
    {
      sqlr_new_error ("VY001", "VPY05", "openCypher plan failed: %s",
                      error_msg ? error_msg : "unknown error");
      return NULL;
    }

  return result;
}

/* BIF: OPENCYPHER_PLUGIN_GEN_SPARQL - generate SPARQL through plugin pipeline */
static caddr_t
bif_opencypher_plugin_gen_sparql (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  caddr_t cypher_query = bif_string_arg (qst, args, 0, "OPENCYPHER_PLUGIN_GEN_SPARQL");
  caddr_t graph_uri = bif_string_or_null_arg (qst, args, 1, "OPENCYPHER_PLUGIN_GEN_SPARQL");
  int32 flags = (int32) bif_long_arg (qst, args, 2, "OPENCYPHER_PLUGIN_GEN_SPARQL");
  caddr_t result = NULL;
  caddr_t error_msg = NULL;

  if (opencypher_translate_gen_sparql (cypher_query, graph_uri, flags,
                                  &result, &error_msg) != 0)
    {
      sqlr_new_error ("VY001", "VPY06", "openCypher SPARQL generation failed: %s",
                      error_msg ? error_msg : "unknown error");
      return NULL;
    }

  return result;
}

/* Plugin connect callback - register all BIFs */
static void
opencypher_plugin_connect (void *appdata)
{
  /* Version and availability BIFs */
  bif_define ("OPENCYPHER_PLUGIN_VERSION", bif_opencypher_plugin_version);
  bif_define ("OPENCYPHER_PLUGIN_AVAILABLE", bif_opencypher_plugin_available);

  /* Translation BIF - main entry point for Cypher to SPARQL */
  bif_define ("OPENCYPHER_PLUGIN_TO_SPARQL", bif_opencypher_plugin_to_sparql);

  /* Tokenizer scaffold BIF for C/PL parity testing */
  bif_define ("OPENCYPHER_PLUGIN_TOKENIZE", bif_opencypher_plugin_tokenize);
  bif_define ("OPENCYPHER_PLUGIN_PARSE", bif_opencypher_plugin_parse);
  bif_define ("OPENCYPHER_PLUGIN_PLAN", bif_opencypher_plugin_plan);
  bif_define ("OPENCYPHER_PLUGIN_GEN_SPARQL", bif_opencypher_plugin_gen_sparql);

  /* Initialize the translator subsystem */
  opencypher_translate_init ();
}

/* Plugin disconnect callback - cleanup resources */
static void
opencypher_plugin_disconnect (void *appdata)
{
  /* Cleanup translator subsystem */
  opencypher_translate_cleanup ();
}

/* Plugin version structure - gate-based plain plugin model */
static unit_version_t opencypher_plugin_version = {
  "openCypher OpenCypher Frontend",
  DBMS_SRV_GEN_MAJOR DBMS_SRV_GEN_MINOR,
  "OpenLink Software",
  "openCypher VSEI plugin for openCypher 2024.3",
  0,
  0,
  opencypher_plugin_connect,
  opencypher_plugin_disconnect,
  0,
  0,
  &_gate
};

unit_version_t *CALLBACK
opencypher_plugin_check (unit_version_t * in, void *appdata)
{
  return &opencypher_plugin_version;
}
