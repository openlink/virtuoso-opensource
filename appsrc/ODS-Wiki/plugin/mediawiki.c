/*
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

#ifdef _USRDLL
#include "plugin.h"
#include "import_gate_virtuoso.h"
#define wi_inst (wi_instance_get()[0])
#else
#include <libutil.h>
#include "sqlnode.h"
#include "sqlbif.h"
#include "wi.h"
#include "Dk.h"
#endif

#if 0
#define mlex_dbg_printf(x) printf x
#else
#define mlex_dbg_printf(x)
#endif

#define MEDIAWIKI_VERSION "0.1"

static dk_mutex_t *mediawiki_lexer_mutex = NULL;

static caddr_t mediawiki_CLUSTER = NULL;
static caddr_t mediawiki_TOPIC = NULL;
static caddr_t mediawiki_WIKINAME = NULL;
static caddr_t mediawiki_WIKIVERSION = NULL;
static caddr_t *mediawiki_env = NULL;

extern void mediamacyyrestart (FILE *input_file);
extern void mediamacyylex_prepare (char *text, dk_session_t *out);
extern int mediamacyylex (void);
extern void mediawikiyyrestart (FILE *input_file);
extern void mediawikiyylex_prepare (char *text, dk_session_t *out);
extern int mediawikiyylex (void);

char * media_mlex_macro_resolver (char *call)
{
  int envlen = BOX_ELEMENTS ((caddr_t)mediawiki_env);
  int envidx;
  int call_len;
  static caddr_t last_macro_found = NULL;
  char name_buf[140];
  dk_free_box (last_macro_found);
  last_macro_found = NULL;
  call_len = strlen (call);
  mlex_dbg_printf (("{'%s' => ", call));
  if ((call_len >= 66) || (call_len < 3))
    goto failed; /* see below */
  memcpy (name_buf, call + 1, call_len - 2);
  name_buf[call_len - 2] = '\0';
  for (envidx = 0; envidx < envlen; envidx += 2)
    {
      if (strcmp (mediawiki_env[envidx], name_buf))
        continue;
      last_macro_found = box_copy (mediawiki_env[envidx+1]);
      mlex_dbg_printf (("'%s' via env}", last_macro_found));
      return last_macro_found;
    }
  sprintf (name_buf, "WikiV (U=%.64s) %s", mediawiki_WIKINAME, call);
  IN_TXN;
  last_macro_found = registry_get (name_buf);
  if (NULL != last_macro_found)
    {
      mlex_dbg_printf (("'%s' via registry U=%s}", last_macro_found, mediawiki_WIKINAME));
      LEAVE_TXN;
      return last_macro_found;
    }
  sprintf (name_buf, "WikiV (C=%.64s) %s", mediawiki_CLUSTER, call);
  last_macro_found = registry_get (name_buf);
  if (NULL != last_macro_found)
    {
      mlex_dbg_printf (("'%s' via registry C=%s}", last_macro_found, mediawiki_CLUSTER));
      LEAVE_TXN;
      return last_macro_found;
    }
  sprintf (name_buf, "WikiV %s", call);
  last_macro_found = registry_get (name_buf);
  if (NULL != last_macro_found)
    {
      mlex_dbg_printf (("'%s' via registry}", last_macro_found));
      LEAVE_TXN;
      return last_macro_found;
    }
failed:
  mlex_dbg_printf (("failure }"));
  LEAVE_TXN;
  return NULL;
}

caddr_t bif_mediawiki_lexer_impl (caddr_t * qst, caddr_t * err, state_slot_t ** args, char *bifname, int run_lexer)
{
  caddr_t rawtext = bif_string_arg (qst, args, 0, bifname);
  caddr_t CLUSTER_arg = bif_string_arg (qst, args, 1, bifname);
  caddr_t TOPIC = bif_string_arg (qst, args, 2, bifname);
  caddr_t WIKINAME = bif_string_arg (qst, args, 3, bifname);
  caddr_t *env = (caddr_t *)bif_arg (qst, args, 4, bifname);
  int envlen = 0, envctr;
  dk_session_t *pipe = NULL, *out = NULL;
  caddr_t macroexpanded = NULL, res = NULL;
  switch (DV_TYPE_OF ((caddr_t)env))
    {
    case DV_ARRAY_OF_POINTER:
      envlen = BOX_ELEMENTS ((caddr_t)env);
      if (envlen % 2)
        sqlr_new_error ("22023", "WV001", "%s needs an array of even length or NULL argument 4", bifname);
      for (envctr = 0; envctr < envlen; envctr++)
        if (DV_STRING != DV_TYPE_OF (env[envctr]))
          sqlr_new_error ("22023", "WV001", "%s needs an array of even length of strings or NULL argument 4", bifname);
      break;
    case DV_DB_NULL:
      break;
    default:
      sqlr_new_error ("22023", "WV001", "%s needs an array or NULL as argument 4", bifname);
    }
  pipe = strses_allocate ();
  mutex_enter (mediawiki_lexer_mutex);
  mediawiki_env = dk_alloc_box ((8 + envlen) * sizeof (caddr_t), DV_ARRAY_OF_POINTER);
  mediawiki_env[0] = "CLUSTER";	mediawiki_env[1] = mediawiki_CLUSTER	= CLUSTER_arg;
  mediawiki_env[2] = "TOPIC";	mediawiki_env[3] = mediawiki_TOPIC	= TOPIC;
  mediawiki_env[4] = "WIKINAME";	mediawiki_env[5] = mediawiki_WIKINAME	= WIKINAME;
  mediawiki_env[6] = "WIKIVERSION";	mediawiki_env[7] = mediawiki_WIKIVERSION;
  for (envctr = 0; envctr < envlen; envctr++)
    mediawiki_env[8+envctr] = env[envctr];
  QR_RESET_CTX
    {
      mediamacyyrestart (NULL);
      mediamacyylex_prepare (rawtext, pipe);
      mediamacyylex ();
      macroexpanded = strses_string (pipe);
      if (run_lexer)
        {
	  out = strses_allocate ();
	  mediawikiyyrestart (NULL);
	  mediawikiyylex_prepare (macroexpanded, out);
          mediawikiyylex ();
	}
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      caddr_t err = thr_get_error_code (self);
      dk_free_box (mediawiki_env); /* not dk_free_tree */
      mutex_leave (mediawiki_lexer_mutex);
      strses_free (pipe);
      dk_free_box (macroexpanded);
      if (run_lexer)
        strses_free (out);
      POP_QR_RESET;
      sqlr_resignal (err);
    }
  END_QR_RESET;
  dk_free_box (mediawiki_env); /* not dk_free_tree */
  mutex_leave (mediawiki_lexer_mutex);
  if (run_lexer)
    {
      res = strses_string (out);
      strses_free (out);
      strses_free (pipe);
      dk_free_box (macroexpanded);
      return res;
    }
  else
    {
      strses_free (pipe);
      return macroexpanded;
    }
}

caddr_t bif_mediawiki_macroexpander (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  return bif_mediawiki_lexer_impl (qst, err, args, "WikiV macroexpander", 0);
}

caddr_t bif_mediawiki_lexer (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  return bif_mediawiki_lexer_impl (qst, err, args, "WikiV lexer", 1);
}

caddr_t bif_mediawiki_name (caddr_t * qst, caddr_t * err, state_slot_t ** args)
{
  return box_dv_short_string  ("MediaWiki");
}

void mediawiki_connect (void *appdata)
{
  mediawiki_WIKIVERSION = box_dv_short_string (MEDIAWIKI_VERSION);
  mediawiki_lexer_mutex = mutex_allocate ();
  bif_define ("WikiV macroexpander 1", bif_mediawiki_macroexpander);
  bif_define ("WikiV lexer 1", bif_mediawiki_lexer);
  bif_define ("WikiV name 1", bif_mediawiki_name);
}

#ifdef _USRDLL
static unit_version_t
mediawiki_version = {
  "MediaWiki",				/*!< Title of unit, filled by unit */
  MEDIAWIKI_VERSION,			/*!< Version number, filled by unit */
  "OpenLink Software",			/*!< Plugin's developer, filled by unit */
  "Support functions for MediaWiki collaboration tool",	/*!< Any additional info, filled by unit */
  0,					/*!< Error message, filled by unit loader */
  0,					/*!< Name of file with unit's code, filled by unit loader */
  mediawiki_connect,			/*!< Pointer to connection function, cannot be 0 */
  0,					/*!< Pointer to disconnection function, or 0 */
  0,					/*!< Pointer to activation function, or 0 */
  0,					/*!< Pointer to deactivation function, or 0 */
  &_gate
};

unit_version_t *
CALLBACK mediawiki_check (unit_version_t *in, void *appdata)
{
  return &mediawiki_version;
}
#endif
