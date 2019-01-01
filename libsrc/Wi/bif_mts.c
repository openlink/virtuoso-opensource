/*
 *  bif_mts.c
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2019 OpenLink Software
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

#include "sqlnode.h"
#include "sqlbif.h"

#include "odbcinc.h"
#include "remote.h"
#include "mts.h"
#include "2pc.h"
#include "mts_client.h"

#include "import_gate_virtuoso.h"

long mts_txn_timeout = -1;
int vd_use_mts;

static caddr_t
bif_mts_get_rmcookie (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  caddr_t cookie = mts_get_rmcookie ();
  if (!cookie)
    {
      sqlr_error("MX008","Could not get resource manager cookie");
      return NEW_DB_NULL;
    }
  else
    {
      caddr_t rmcookie_str = export_mts_bin_encode (cookie, box_length (cookie));
      return rmcookie_str;
    }
};

static caddr_t
bif_mts_enlist_transaction (caddr_t * qst, caddr_t * err_ret,
    state_slot_t ** args)
{
  /* get encoded transaction cookie */
  caddr_t tr_cookie_str =
      bif_string_arg (qst, args, 0, "mts_enlist_transaction");
  caddr_t tr_cookie;
  unsigned long len;

  if (!stricmp(tr_cookie_str,"LOCAL"))
    {
      /* should be changed */
      dbg_printf(("retire lt=%x\n",((query_instance_t*)QST_INSTANCE(qst))->qi_trx));
      tp_retire((query_instance_t*)QST_INSTANCE(qst));
      return box_num (0);
    }
  dbg_printf(("enlisting...\n"));

  if (export_mts_bin_decode (tr_cookie_str, &tr_cookie, &len) == -1)
    sqlr_error("MX001", "could not decode transaction cookie");

  if (mts_trx_enlist (QI_TRX (QST_INSTANCE (qst)), tr_cookie, len))
    {
      dk_free (tr_cookie, -1);
      sqlr_error("MX002", "could not enlist in transaction (%s)",tr_cookie_str);
    };

  dk_free (tr_cookie, -1);
  return box_num (0);
}

static caddr_t
bif_mts_connect (caddr_t * qst, caddr_t * err_ret, state_slot_t ** args)
{
  /* reconnect? */
  long reconnect_fl = bif_long_arg (qst, args, 0, "mts_connect");
  if (!mts_connect(reconnect_fl))
    {
      sqlr_error ("MX000", "connection to MS DTC failed");
    }

  return box_num(0);
};

static caddr_t
bif_mts_status (caddr_t* qst, caddr_t * err_ret, state_slot_t ** args)
{
    caddr_t param_str =
	bif_string_arg (qst, args, 0, "mts_status");
    if (!stricmp("TRANSACTION",param_str))
    {
	return (caddr_t)mts_transaction_status(QI_TRX(QST_INSTANCE(qst)));
    } else if (!stricmp("MTS",param_str))
    {
	return (caddr_t)mts_server_status();
    }
    sqlr_error("MX000", "unknown parameter %s", param_str);

    return 0;

};

static caddr_t
bif_mts_set_timeout(caddr_t* qst, caddr_t * err_ret, state_slot_t ** args)
{
    long param_timeout =
	bif_long_arg (qst, args, 0, "mts_set_timeout");
    mts_txn_timeout = param_timeout;
    return box_num(0);
};

static caddr_t
bif_mts_get_timeout(caddr_t* qst, caddr_t * err_ret, state_slot_t ** args)
{
    if (-1 == mts_txn_timeout )
      return box_num(((query_instance_t*)qst)->qi_rpc_timeout);
    else
      return box_num(mts_txn_timeout);
};

static caddr_t
bif_mts_usleep(caddr_t* qst, caddr_t * err_ret, state_slot_t ** args)
{
    long msec = bif_long_arg (qst, args, 0, "mts_usleep");
    Sleep(msec);
    return box_num(0);
};


static caddr_t
bif_mts_all_info(caddr_t* qst, caddr_t * err_ret, state_slot_t ** args)
{
  query_instance_t* qi = (query_instance_t*)qst;
  client_connection_t* cli =
      qi->qi_client;
  dbg_printf(("******** cli %x tr %x st %d nthr %d tr2 %x\n",
	 cli,
	 cli->cli_trx,
	 cli->cli_trx->lt_status,
	 cli->cli_trx->lt_threads,
	 qi->qi_trx));
#if 0
  if (!cli->cli_tp_data)
    GPF_T1("should in distributed transaction\n");
#endif
  return NEW_DB_NULL;
}

void
export_mts_bif_init ()
{
  mts_init ();
  if(!mts_connect (1))
    {
      twopc_log (_LOG_ERROR, "MS DTC is not available");
      exit (0);
    }
  bif_define ("mts_get_rmcookie", bif_mts_get_rmcookie);
  bif_define ("mts_enlist_transaction", bif_mts_enlist_transaction);
  bif_define ("mts_connect", bif_mts_connect);
  bif_define ("mts_status", bif_mts_status);

  bif_define ("mts_set_timeout", bif_mts_set_timeout);
  bif_define ("mts_get_timeout", bif_mts_get_timeout);

  bif_define ("mts_sleep", bif_mts_usleep);

  /* bif_define ("__mts_fail_after_prepare", bif_mts_fail_after_prepare); */
  bif_define ("__mts_all_info", bif_mts_all_info);
};
