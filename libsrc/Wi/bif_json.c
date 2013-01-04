/*
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2013 OpenLink Software
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

#include "libutil.h"
#include "sqlnode.h"
#include "sqlbif.h"
#include "wi.h"
#include "Dk.h"

extern void jsonyy_reset ();
extern void jsonyyparse ();
extern caddr_t *json_tree;
extern int jsonyydebug;
extern void jsonyy_string_input_init (char * str);
dk_mutex_t *json_parse_mtx = NULL;
extern int json_line;

static
caddr_t
bif_json_parse (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t str = bif_string_arg (qst, args, 0, "json_parse");
  caddr_t tree = NULL;
  caddr_t err = NULL;
  if (!json_parse_mtx)
    json_parse_mtx = mutex_allocate ();
  mutex_enter (json_parse_mtx);
  MP_START();
  jsonyy_string_input_init (str);
  QR_RESET_CTX
    {
      jsonyy_reset ();
      jsonyyparse ();
      tree = box_copy_tree (json_tree);
    }
  QR_RESET_CODE
    {
      du_thread_t *self = THREAD_CURRENT_THREAD;
      err = thr_get_error_code (self);
      thr_set_error_code (self, NULL);
      tree = NULL;
      /*no POP_QR_RESET*/;
    }
  END_QR_RESET;
  MP_DONE();
  mutex_leave (json_parse_mtx);
  if (!tree)
    sqlr_resignal (err);
  return tree;
}

void
bif_json_init (void)
{
  bif_define ("json_parse", bif_json_parse);
}
