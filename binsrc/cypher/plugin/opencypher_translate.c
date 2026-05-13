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
 *  openCypher Translator - Implementation
 *
 *  Cypher to SPARQL translation using Virtuoso SQL execution APIs.
 *  Uses dk_alloc/dk_free for all memory management.
 */

#include "opencypher_translate.h"
#include "list2.h"    /* For dk_alloc_list */
#include <string.h>

/* Internal state for the translator */
static int opencypher_translate_initialized = 0;

static int opencypher_exec_sql_raw (caddr_t sql_text,
                               int n_params,
                               caddr_t param0,
                               caddr_t param1,
                               caddr_t *result,
                               caddr_t *err_msg);

/* Initialize the translator subsystem */
void
opencypher_translate_init (void)
{
  if (opencypher_translate_initialized)
    return;

  /* Translator initialization complete */
  opencypher_translate_initialized = 1;
}

/* Cleanup the translator subsystem */
void
opencypher_translate_cleanup (void)
{
  if (!opencypher_translate_initialized)
    return;

  opencypher_translate_initialized = 0;
}

int
opencypher_translate_exec_sql_1 (caddr_t sql_text,
                            caddr_t param0,
                            caddr_t *result,
                            caddr_t *err_msg)
{
  return opencypher_exec_sql_raw (sql_text, 1, param0, NULL, result, err_msg);
}

int
opencypher_translate_exec_sql_2 (caddr_t sql_text,
                            caddr_t param0,
                            caddr_t param1,
                            caddr_t *result,
                            caddr_t *err_msg)
{
  return opencypher_exec_sql_raw (sql_text, 2, param0, param1, result, err_msg);
}

int
opencypher_translate_parse (caddr_t cypher_query,
                       int32 flags,
                       caddr_t *result,
                       caddr_t *error_msg)
{
  caddr_t sql_text;
  int rc;

  if (cypher_query == NULL || DV_TYPE_OF (cypher_query) != DV_STRING)
    {
      *error_msg = box_dv_short_string ("Invalid or missing Cypher query string");
      return -1;
    }

  /* flags reserved for native parser diagnostics. */
  sql_text = box_dv_short_string (
    "SELECT DB.DBA.CYP_PARSE (OPENCYPHER_PLUGIN_TOKENIZE (:0))");
  rc = opencypher_translate_exec_sql_1 (sql_text, cypher_query, result, error_msg);
  dk_free_box (sql_text);
  return rc;
}

int
opencypher_translate_plan (caddr_t cypher_query,
                      int32 flags,
                      caddr_t *result,
                      caddr_t *error_msg)
{
  caddr_t sql_text;
  int rc;

  if (cypher_query == NULL || DV_TYPE_OF (cypher_query) != DV_STRING)
    {
      *error_msg = box_dv_short_string ("Invalid or missing Cypher query string");
      return -1;
    }

  /* flags reserved for native planner diagnostics. */
  sql_text = box_dv_short_string (
    "SELECT DB.DBA.CYP_PLAN_BUILD ("
    "  DB.DBA.CYP_PARSE (OPENCYPHER_PLUGIN_TOKENIZE (:0)))");
  rc = opencypher_translate_exec_sql_1 (sql_text, cypher_query, result, error_msg);
  dk_free_box (sql_text);
  return rc;
}

int
opencypher_translate_gen_sparql (caddr_t cypher_query,
                            caddr_t graph_uri,
                            int32 flags,
                            caddr_t *result,
                            caddr_t *error_msg)
{
  caddr_t sql_text;
  caddr_t graph_param;
  int rc;

  if (cypher_query == NULL || DV_TYPE_OF (cypher_query) != DV_STRING)
    {
      *error_msg = box_dv_short_string ("Invalid or missing Cypher query string");
      return -1;
    }

  /* flags reserved for native generator diagnostics. */
  sql_text = box_dv_short_string (
    "SELECT DB.DBA.CYP_TO_SPARQL ("
    "  DB.DBA.CYP_PARSE (OPENCYPHER_PLUGIN_TOKENIZE (:0)),"
    "  :1)");

  graph_param = (graph_uri && DV_TYPE_OF (graph_uri) == DV_STRING)
                  ? graph_uri : NEW_DB_NULL;
  rc = opencypher_translate_exec_sql_2 (sql_text, cypher_query, graph_param,
                                   result, error_msg);
  dk_free_box (sql_text);
  if (graph_param != graph_uri)
    dk_free_box (graph_param);
  return rc;
}

/*
 * Translate Cypher to SPARQL
 *
 * Implementation: Run the plugin-owned tokenizer and then feed the
 * resulting token stream through the established PL AST/plan/generator
 * primitives. This keeps translation behind the VSEI plugin boundary while
 * native C parser/planner/generator work continues.
 */
int
opencypher_translate_cypher_to_sparql (caddr_t cypher_query,
                                  caddr_t graph_uri,
                                  caddr_t params,
                                  int32 flags,
                                  caddr_t *result,
                                  caddr_t *error_msg)
{
  caddr_t sparql_result = NULL;
  caddr_t err_text = NULL;
  int rc = 0;
  client_connection_t *cli = sqlc_client ();

  /* Validate input */
  if (cypher_query == NULL || DV_TYPE_OF (cypher_query) != DV_STRING)
    {
      err_text = dk_alloc_box (40, DV_STRING);
      memcpy (err_text, "Invalid or missing Cypher query string", 40);
      *error_msg = err_text;
      return -1;
    }

  /*
   * Call the plugin pipeline using Virtuoso SQL execution APIs:
   * 1. Build SQL text to run OPENCYPHER_PLUGIN_TOKENIZE -> CYP_PARSE -> CYP_TO_SPARQL
   * 2. Compile with sql_compile()
   * 3. Execute with qr_rec_exec()
   * 4. Fetch result from local_cursor_t
   */
  {
    caddr_t sql_text;
    caddr_t graph_param;
    caddr_t exec_result = NULL;
    caddr_t exec_err = NULL;

    /*
     * Call the PL primitives directly, NOT DB.DBA.CYPHER_TO_SPARQL.
     * CYPHER_TO_SPARQL itself dispatches back to this BIF when the
     * plugin is loaded, so calling it here would recurse forever.
     * Mirror cypher_main.sql's CYPHER_TO_SPARQL body (plugin tokenizer ->
     * CYP_PARSE -> CYP_TO_SPARQL). Preserve NULL graph values for
     * read-only RDF-native queries so SPARQL executes without an
     * injected FROM clause; CYP_TO_SPARQL still applies the openCypher
     * default graph for write/update forms.
     * TODO: bind params for $name parameters; flags currently unused.
     */
    sql_text = box_dv_short_string (
      "SELECT DB.DBA.CYP_TO_SPARQL ("
      "  DB.DBA.CYP_PARSE (OPENCYPHER_PLUGIN_TOKENIZE (:0)),"
      "  :1)");

    graph_param = (graph_uri && DV_TYPE_OF (graph_uri) == DV_STRING)
                    ? graph_uri : NEW_DB_NULL;

    rc = opencypher_translate_exec_sql_2 (sql_text, cypher_query, graph_param,
                                     &exec_result, &exec_err);

    dk_free_box (sql_text);
    if (graph_param != graph_uri)
      dk_free_box (graph_param);

    if (rc != 0 || exec_result == NULL)
      {
        /* Translation failed */
        if (exec_err)
          {
            size_t len = strlen (exec_err);
            err_text = dk_alloc_box (len + 1, DV_STRING);
            memcpy (err_text, exec_err, len + 1);
            dk_free_box (exec_err);
          }
        else
          {
            err_text = dk_alloc_box (35, DV_STRING);
            memcpy (err_text, "Translation failed (SQL execution)", 35);
          }

        *error_msg = err_text;
        return -1;
      }

    /* Success - exec_result contains the SPARQL string */
    *result = exec_result;
    return 0;
  }
}

/*
 * Execute SQL with two named bind parameters (:0, :1).
 *
 * qr_rec_exec is variadic (signature in libsrc/Wi/sqlfn.h):
 *   caddr_t qr_rec_exec (query_t *qr, client_connection_t *cli,
 *                        local_cursor_t **lc_ret,
 *                        query_instance_t *caller,
 *                        stmt_options_t *opts,
 *                        long n_pars, ...);
 * Each bound parameter is a triplet: (const char *name, value, long kind),
 * where kind is QRP_STR for boxed values to be re-boxed by the engine and
 * QRP_RAW for already-boxed values transferred verbatim. Returns NULL on
 * success, or an error caddr_t on failure (caller must dk_free_tree it).
 */
static int
opencypher_exec_sql_raw (caddr_t sql_text,
                    int n_params,
                    caddr_t param0,
                    caddr_t param1,
                    caddr_t *result,
                    caddr_t *err_msg)
{
  query_t *qr = NULL;
  local_cursor_t *lc = NULL;
  caddr_t query_result = NULL;
  caddr_t error_text = NULL;
  caddr_t exec_err = NULL;
  client_connection_t *cli = sqlc_client ();

  if (cli == NULL)
    {
      *err_msg = box_dv_short_string ("No client connection available");
      return -1;
    }

  /* Compile */
  qr = sql_compile_static (sql_text, cli, &error_text, 0);
  if (qr == NULL || error_text != NULL)
    {
      *err_msg = error_text ? error_text
                            : box_dv_short_string ("SQL compilation failed");
      return -1;
    }

  /* Execute with QRP_RAW parameters. The engine takes ownership of
   * box_copy'd values, so duplicate before passing. */
  if (n_params == 1)
    exec_err = qr_rec_exec (qr, cli, &lc, CALLER_LOCAL, NULL, 1,
                            ":0", box_copy (param0), QRP_RAW);
  else if (n_params == 2)
    exec_err = qr_rec_exec (qr, cli, &lc, CALLER_LOCAL, NULL, 2,
                            ":0", box_copy (param0), QRP_RAW,
                            ":1", box_copy (param1), QRP_RAW);
  else
    {
      *err_msg = box_dv_short_string ("Unsupported plugin SQL parameter count");
      return -1;
    }
  if (exec_err != NULL)
    {
      if (DV_TYPE_OF (exec_err) == DV_ARRAY_OF_POINTER
          && BOX_ELEMENTS (exec_err) > 2
          && ERR_MESSAGE (exec_err) != NULL)
        *err_msg = box_dv_short_string (ERR_MESSAGE (exec_err));
      else
        *err_msg = box_dv_short_string ("SQL execution failed");
      dk_free_tree (exec_err);
      if (lc)
        lc_free (lc);
      return -1;
    }
  if (lc == NULL)
    {
      *err_msg = box_dv_short_string ("SQL execution returned no cursor");
      return -1;
    }

  /* Fetch first row, first column */
  if (lc_next (lc))
    {
      caddr_t col_value = lc_nth_col (lc, 0);
      if (col_value != NULL)
        query_result = box_copy_tree (col_value);
      else
        {
          query_result = dk_alloc_box (1, DV_STRING);
          ((char *) query_result)[0] = '\0';
        }
    }
  else
    {
      *err_msg = box_dv_short_string ("No result from translator");
      lc_free (lc);
      return -1;
    }

  lc_free (lc);

  *result = query_result;
  return 0;
}
