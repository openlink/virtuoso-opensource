/*
 *  bif_repl.c
 *
 *  $Id$
 *
 *  Replication functions
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
#include "eqlcomp.h"
#include "odbcinc.h"
#include "datesupp.h"
#include "remote.h"
#include "sqlbif.h"
#include "statuslog.h"
#include "sqlpar.h"
#include "srvmultibyte.h"
#include "sqlpfn.h"


static client_connection_t *sched_cli;
unsigned long cfg_scheduler_period = 0;
long cfg_disable_vdb_stat_refresh = 0;

void
sched_set_thread_count (void)
{
}

void
sched_do_round_1 (const char * text)
{
  caddr_t err = NULL;
  query_t *qr;
  client_connection_t * save_cli = THR_ATTR (THREAD_CURRENT_THREAD, TA_IMMEDIATE_CLIENT);
  caddr_t org_qual = sched_cli->cli_qualifier; /* store the original qualifier */

  if (cpt_is_global_lock ())
    return;

  sched_cli->cli_qualifier = box_string (org_qual);
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_IMMEDIATE_CLIENT, sched_cli);
  local_start_trx (sched_cli);
  qr = sql_compile (text, sched_cli, &err, SQLC_DEFAULT);
  if (!err)
    err = qr_quick_exec (qr, sched_cli, "", NULL, 0);
  qr_free (qr);
  if (err && err != (caddr_t) SQL_NO_DATA_FOUND)
    {
      if (strcmp ("40001", ERR_STATE (err)))
	log_info ("Scheduler error %s : %s", ERR_STATE (err), ERR_MESSAGE (err));
      dk_free_tree (err);
    }
  local_commit_end_trx (sched_cli);
  SET_THR_ATTR (THREAD_CURRENT_THREAD, TA_IMMEDIATE_CLIENT, save_cli);
  /* restore the original qualifier */
  dk_free_box (sched_cli->cli_qualifier);
  sched_cli->cli_qualifier = org_qual;
}

void
sched_run_at_start (void)
{
}

void
sched_do_round (void)
{
  sched_do_round_1 ("scheduler_do_round(0)");
}


void
ddl_repl_init (void)
{
}

void
bif_repl_init (void)
{
  sched_cli = client_connection_create ();
}
