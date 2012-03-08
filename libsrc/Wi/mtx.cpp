/*
 *  mtx.cpp
 *
 *  $Id$
 *
 *  MS DTC support
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2012 OpenLink Software
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
 *
*/

#define _MTX_

extern "C"
{
#include <Dk.h>
#include "remote.h"
#include "2pc.h"
#include "mts.h"
}



#include <txdtc.h>
#include <xolehlp.h>
#include <transact.h>


extern "C"
{
  extern long mts_txn_timeout;
#define IGNORE_SERVER_IMP_TOKEN
#include "import_gate_virtuoso.h"
}

#include "mts_com.h"

GUID VirtRMGUID;

class Guard
{
protected:dk_mutex_t * mutex_;
public:Guard (dk_mutex_t * mtx):mutex_ (mtx)
  {
    mutex_enter (mutex_);
  };
  ~Guard ()
  {
    mutex_leave (mutex_);
  };
};

#define LOCK_OBJECT(__obj) \
  ( mutex_enter(__obj##_mutex) )
#define RELEASE_OBJECT(__obj) \
  ( mutex_leave(__obj##_mutex) )
#define INIT_OBJECT(__obj) \
  ( __obj##_mutex = mutex_allocate() )
#define FREE_OBJECT(__obj) \
  ( mutex_free(__obj##_mutex) )

/*
    DOUBLE_LOCK (attribute_of_local_rm,label_to_go)
	initializing code ...
    RELEASE_OBJECT(local_rm);
*/

#define DOUBLE_LOCK(attribute,label)\
if (local_rm->attribute)\
    goto label;\
else {\
    LOCK_OBJECT(local_rm);\
    if (local_rm->attribute) {\
        RELEASE_OBJECT(local_rm);\
	goto label;\
    }\
}



/* int mts_trx_enlist(lock_trx_t* lt,BYTE* cookie,DWORD cookie_len);
int mts_whereabouts(BYTE** where_abouts,DWORD* len); */

typedef struct mts_s
{
  ITransaction *mts_trx;
  ITransactionEnlistmentAsync *mts_enlistment;
}
mts_t;

typedef struct mts_RM_s
{
  IResourceManager *rm;
  ITransactionDispenser *trx_dispenser;
  ITransactionImport *trx_import;

  BYTE *rmcookie;
  DWORD rmcookie_len;

}
mts_RM_t;

mts_RM_t *init_RM ();
static void free_RM (mts_RM_t ** rm);


static mts_RM_t *local_rm = 0;
static dk_mutex_t *local_rm_mutex = 0;

void
mts_trx_free (mts_t * trx)
{
  if (trx->mts_trx)
    trx->mts_trx->Release ();
  if (trx->mts_enlistment)
    trx->mts_enlistment->Release ();

  dk_free (trx, sizeof (mts_t));
};

int
mts_set_trx_options (query_instance_t * qi, ITransactionOptions ** options)
{
  lock_trx_t *lt = qi->qi_trx;
  XACTOPT xa_opt;

  xa_opt.ulTimeout = (-1 == mts_txn_timeout) ?
      qi->qi_rpc_timeout : mts_txn_timeout;
  strcpy ((char *) xa_opt.szDescription, "hello");

  HRESULT hr = (*options)->SetOptions (&xa_opt);
  if (!SUCCEEDED (hr))
    {
      *options = 0;
    }
  return 0;
}

int
mts_trx_begin (query_instance_t * qi)
{
  lock_trx_t *lt = qi->qi_trx;

  MTS_TRACE (("mts_trx_begin %x \n", lt));
  ITransaction *transaction;
  try
  {
    Guard grd (local_rm_mutex);
    auto_interface < ITransactionOptions > options;
    HRESULT hr = local_rm->trx_dispenser->GetOptionsObject (&options.get ());
    if (SUCCEEDED (hr))
      {
	mts_set_trx_options (qi, &options.get ());
      }
    hr = local_rm->trx_dispenser->BeginTransaction (0, ISOLATIONLEVEL_BROWSE,
	0, options.get (), &transaction);
    MTS_THROW_ASSERT (hr, "BeginTransaction");
  }
  catch (const mts_error & err)
  {
    err.dump ();
    return -1;
  }
  ((mts_t *) (lt->lt_2pc._2pc_info->dtrx_info))->mts_trx = transaction;
  return 0;
}

int
mts_trx_enlist_loc (client_connection_t * connection, ITransaction * itrn)
{
  MTS_TRACE (("mts_trx_enlist_loc client (%x)\n", connection));
  CTransactResourceAsync *ctra = 0;
  try
  {
    if (!itrn)
      {
	throw mts_error (0, "uninitialized ITransaction object");
      }
    XACTUOW guid;
    long used;
    ctra = new CTransactResourceAsync;
    ITransactionEnlistmentAsync *enlistment;

    LOCK_OBJECT (local_rm);
    HRESULT hr = local_rm->rm->Enlist (itrn, ctra, &guid, &used, &enlistment);
    RELEASE_OBJECT (local_rm);
    MTS_THROW_ASSERT (hr, "Enlisting");

    ctra->SetEnlistment (enlistment);
    ctra->SetConnection (connection);
  }
  catch (const mts_error & err)
  {
    delete ctra;
    err.dump ();
    return err.get_errcode ();
  }
  return 0;
}

int
mts_trx_enlist (lock_trx_t * lt, caddr_t tr_cookie, unsigned long len)
{
  if (!local_rm)
    {
      return 1;
    }
  DOUBLE_LOCK (trx_import, enlist);
  if (!local_rm->rm)
    {
      RELEASE_OBJECT (local_rm);
      return 0;
    }
  try
  {
    HRESULT hr =
	DtcGetTransactionManager (0, 0, __uuidof (ITransactionImport),
	0, 0, 0, (void **) &local_rm->trx_import);
    MTS_THROW_ASSERT (hr, "Get Transaction Import");
  }
  catch (const mts_error & err)
  {
    err.dump ();
    RELEASE_OBJECT (local_rm);
    return err.get_errcode ();
  }
  RELEASE_OBJECT (local_rm);
enlist:
  try
  {
    auto_interface < ITransaction > itrx;
    tp_data_t *tpd;
    HRESULT hr = local_rm->trx_import->Import (len,
	(BYTE *) tr_cookie,
	(IID *) & __uuidof (ITransaction),
	(void **) &itrx.get ());
    MTS_THROW_ASSERT (hr, "Import transaction");

    hr = mts_trx_enlist_loc (lt->lt_client, itrx.get ());
    MTS_THROW_ASSERT (hr, "Enlist local transaction");
    tpd = (tp_data_t *) dk_alloc (sizeof (tp_data_t));
    memset (tpd, 0, sizeof (tp_data_t));
    tpd->cli_tp_enlisted = CONNECTION_PREPARED;
    tpd->cli_tp_trx = itrx.release ();
    tpd->cli_tp_sem2 = semaphore_allocate (0);
    lt->lt_client->cli_tp_data = tpd;
    lt->lt_2pc._2pc_type = tpd->cli_trx_type = TP_MTS_TYPE;
#ifdef MSDTC_DEBUG
    lt->lt_in_mts = 1;
#endif
  }
  catch (const mts_error & err)
  {
    err.dump ();
    return err.get_errcode ();
  }
  return 0;
};

int
mts_trx_commit_stage_2 (caddr_t distr_trx, int is_commit)
{
  return LTE_OK;
}

int
mts_trx_commit (lock_trx_t * lt, int is_commit)
{
  tp_dtrx_t *dtrx = lt->lt_2pc._2pc_info;
  tp_data_t *tpd = lt->lt_client->cli_tp_data;

  if (tpd && (CONNECTION_ENLISTED == tpd->cli_tp_enlisted))
    {
      MTS_TRACE (("mts_trx_commit (connection level) %x\n", lt->lt_client));
      return 0;
    }
  if (dtrx->dtrx_info)
    {
      HRESULT hr;
      MTS_TRACE (("mts_trx_commit (transaction level) %x\n", lt));
      ITransaction *trx = ((mts_t *) dtrx->dtrx_info)->mts_trx;
      hr = is_commit ? trx->Commit (FALSE, 0, 0) : trx->Abort (0, 0, 0);
      trx->Release ();
      if (SUCCEEDED (hr))
	return LTE_OK;
      return LTE_DEADLOCK;

    }
  return 0;
}

mts_RM_t *
init_RM ()
{
  MTS_TRACE (("init_RM\n"));
  mts_RM_t *rm = (mts_RM_t *) dk_alloc (sizeof (mts_RM_t));
  memset (rm, 0, sizeof (mts_RM_t));

  try
  {
    auto_interface < IResourceManagerFactory > rm_factory;
    HRESULT hr =
	DtcGetTransactionManager (0, 0, __uuidof (IResourceManagerFactory),
	0, 0, 0, (void **) &rm_factory.get ());
    MTS_THROW_ASSERT (hr, "Get RM Factory");

    int guid = open ("guid.bin", O_RDONLY | O_BINARY);
    if (-1 == guid)
      {
/*	log_info("Generating RM GUID..."); */
	guid = open ("guid.bin", O_CREAT | O_WRONLY | O_BINARY);
	UuidCreate (&VirtRMGUID);
	write (guid, &VirtRMGUID, sizeof (VirtRMGUID));
      }
    else
      read (guid, &VirtRMGUID, sizeof (VirtRMGUID));

    hr = rm_factory->Create (&VirtRMGUID, "Virtuoso Resource Manager",
	new CResMgrSink, &(rm->rm));
    MTS_THROW_ASSERT (hr, "Create RM");

    hr = DtcGetTransactionManager (0, 0, __uuidof (ITransactionDispenser),
	0, 0, 0, (void **) &(rm->trx_dispenser));
    MTS_THROW_ASSERT (hr, "Get Transaction Dispenser");
  }
  catch (const mts_error & err)
  {
    err.dump ();
    vd_use_mts = 0;
    /* log_info ("MS DTC could not be found, call reconnect"); */
    return 0;
  }

  return rm;
}

void
free_RM (mts_RM_t ** prm)
{
  mts_RM_t *rm = *prm;
  if (rm->rm)
    {
      rm->rm->Release ();
      rm->rm = 0;
    };
  if (rm->rmcookie)
    {
      dk_free (rm->rmcookie, rm->rmcookie_len);
      rm->rmcookie = 0;
    };
  if (rm->trx_dispenser)
    {
      rm->trx_dispenser->Release ();
      rm->trx_dispenser = 0;
    };
  if (rm->trx_import)
    {
      rm->trx_import->Release ();
      rm->trx_import = 0;
    };
  rm = 0;
}

int
mts_ms_sql_enlist (rds_connection_t * rcon, query_instance_t * qi)
{
  lock_trx_t *lt = qi->qi_trx;
  if (rcon->rc_is_enlisted != SHOULD_BE_ENLISTED)
    {
      return 0;
    }
  mts_t *trx = (mts_t *) lt->lt_2pc._2pc_info->dtrx_info;
  MTS_TRACE (("mts_ms_sql_enlist %x\n", rcon));
  ITransaction *itrx = 0;

  tp_data_t *tpd = qi->qi_client->cli_tp_data;
  if (tpd && CONNECTION_ENLISTED == tpd->cli_tp_enlisted)
    itrx = (ITransaction *) tpd->cli_tp_trx;
  else if ((!trx->mts_trx) && (mts_trx_begin (qi) == -1))
    {
      return -1;
    }
  else
    itrx = trx->mts_trx;


  try
  {
    SQLRETURN sr =
	SQLSetConnectAttr (rcon->rc_hdbc, SQL_COPT_SS_ENLIST_IN_DTC,
	(SQLPOINTER) itrx, SQL_IS_INTEGER);
    if ((sr != SQL_SUCCESS) && (sr != SQL_SUCCESS_WITH_INFO))
      {
	DoSQLError (rcon->rc_hdbc, 0);
	throw mts_error (sr, "SQLSetConnectOption");
      }

    rcon->rc_is_enlisted = ENLISTED;

  }
  catch (const mts_error & err)
  {
    err.dump ();
    return -1;
  }
  return 0;
}

int
mts_trx_exclude (lock_trx_t * lt, rds_connection_t * rcon)
{
  if (rcon->rc_is_enlisted != ENLISTED)
    return 1;

  try
  {
    MTS_TRACE (("mts_trx_exclude %x\n", rcon));
    SQLRETURN sr =
	SQLSetConnectAttr (rcon->rc_hdbc, SQL_COPT_SS_ENLIST_IN_DTC,
	NULL, SQL_IS_INTEGER);
    MTS_THROW_SQLASSERT (sr, rcon->rc_hdbc, "SQLSetConnectOption");

    rcon->rc_is_enlisted = 0;
  }
  catch (const mts_error & err)
  {
    err.dump ();
  }
  return 1;
}

caddr_t
mts_get_rmcookie ()
{
  if (!local_rm)
    {
      return 0;
    }

  DOUBLE_LOCK (rmcookie, alloc_ret);

  try
  {
    auto_interface < ITransactionImportWhereabouts > import_abouts;
    HRESULT hr = DtcGetTransactionManager (0,
	0,
	__uuidof (ITransactionImportWhereabouts),
	0,
	0,
	0,
	(void **) &import_abouts.get ());
    MTS_THROW_ASSERT (hr, "Get ITransactionImportWhereabouts");

    hr = import_abouts->GetWhereaboutsSize (&local_rm->rmcookie_len);
    MTS_THROW_ASSERT (hr, "GetTransactionImportWhereaboutsLen");

    DWORD used;
    auto_dkptr < BYTE >
	whereabouts_aptr ((BYTE *) dk_alloc (sizeof (BYTE) *
	    local_rm->rmcookie_len));
    hr = import_abouts->GetWhereabouts (local_rm->rmcookie_len,
	whereabouts_aptr.get (), &used);

    local_rm->rmcookie = whereabouts_aptr.release ();
  }
  catch (const mts_error & err)
  {
    RELEASE_OBJECT (local_rm);
    err.dump ();
    return 0;
  }
  RELEASE_OBJECT (local_rm);

alloc_ret:
  caddr_t cookie = (caddr_t) dk_alloc_box (local_rm->rmcookie_len, DV_BIN);
  memcpy (cookie, local_rm->rmcookie, local_rm->rmcookie_len);

  return cookie;
};


int
mts_init ()
{
  if (!local_rm_mutex)
    local_rm_mutex = mutex_allocate ();
  if (vd_use_mts)
    local_rm = init_RM ();
  else
    local_rm = 0;
  return local_rm != NULL;
}


int
mts_connect (long reconnect)
{
  if (reconnect)
    vd_use_mts = 1;
  if (!reconnect && local_rm)
    goto ret;
  LOCK_OBJECT (local_rm);
  if (local_rm)
    {
      if (!reconnect)
	{
	  RELEASE_OBJECT (local_rm);
	  goto ret;
	}
      free_RM (&local_rm);
    }
  local_rm = init_RM ();
  if (!local_rm)
    {
      RELEASE_OBJECT (local_rm);
      return 0;
    };
  RELEASE_OBJECT (local_rm);
ret:
  return 1;
}

box_t
mts_server_status ()
{
  LOCK_OBJECT (local_rm);
  if (local_rm)
    {
      RELEASE_OBJECT (local_rm);
      return box_dv_short_string ("connected");
    }
  else
    {
      RELEASE_OBJECT (local_rm);
      return box_dv_short_string ("disconnected");
    }
}

box_t
mts_transaction_status (lock_trx_t * lt)
{
  if (lt->lt_2pc._2pc_type)
    {
      return box_dv_short_string ("2pc enabled");
    }
  else
    {
      return box_dv_short_string ("2pc disabled");
    }
};

unsigned long
mts_prepare_set_log (tp_message_t * mm)
{
  ITransactionEnlistmentAsync *mts_enlistment =
      (ITransactionEnlistmentAsync *) mm->mm_resource;
  IPrepareInfo *info = 0;
  unsigned long sz = 0;
  dbg_printf (("mts_prepare_set_log.."));
  if (SUCCEEDED (mts_enlistment->QueryInterface (IID_IPrepareInfo,
	      (void **) &info))
      && (SUCCEEDED (info->GetPrepareInfoSize (&sz))))
    {
      box_t info_box = dk_alloc_box (sz, DV_BIN);
      if (SUCCEEDED (info->GetPrepareInfo ((BYTE *) info_box)))
	{
	  mm->mm_trx->lt_2pc._2pc_log = info_box;
	  dbg_printf ((".. success\n"));
	}
      else
	dk_free_box (info_box);
    }
  if (info)
    info->Release ();
  return 0;
}

#define S_STATE(x) (((x)==LTE_OK) ? S_OK : E_FAIL)

unsigned long
mts_prepare_done (void *res, int trx_status)
{
  mts_log_debug (("mts_prepare_done res=%p stat=%d", res, trx_status));
  ITransactionEnlistmentAsync *mts_enlistment =
      (ITransactionEnlistmentAsync *) res;
  return mts_enlistment->PrepareRequestDone (S_STATE (trx_status), 0, 0);
}
unsigned long
mts_commit_done (void *res, int trx_status)
{
  mts_log_debug (("mts_commit_done res=%p stat=%d", res, trx_status));
  ITransactionEnlistmentAsync *mts_enlistment =
      (ITransactionEnlistmentAsync *) res;
  return mts_enlistment->CommitRequestDone (S_STATE (trx_status));
}

unsigned long
mts_abort_done (void *res, int trx_status)
{
  mts_log_debug (("mts_abort_done res=%p stat=%d", res, trx_status));
  ITransactionEnlistmentAsync *mts_enlistment =
      (ITransactionEnlistmentAsync *) res;
  return mts_enlistment->AbortRequestDone (S_STATE (trx_status));
}

void
mts_trx_dealloc (struct tp_dtrx_s *dtrx)
{
  mts_trx_free ((mts_t *) dtrx->dtrx_info);
  dk_free (dtrx, sizeof (tp_dtrx_t));
}

void *
export_mts_trx_allocate ()
{
  static tp_trx_vtbl_t mts_vtbl = {
    mts_ms_sql_enlist,
    mts_trx_commit,
    mts_trx_commit_stage_2,
    mts_trx_exclude,
    mts_trx_dealloc
  };
  NEW_VARZ (tp_dtrx_t, dtrx);
  dtrx->vtbl = &mts_vtbl;
  dtrx->dtrx_info = (caddr_t) dk_alloc (sizeof (mts_t));
  memset (dtrx->dtrx_info, 0, sizeof (mts_t));

  return (void *) dtrx;
};

int
export_mts_recover (box_t recov_data)
{
  XACTSTAT xact;
  dbg_printf (("MTS transaction recover... "));
  if (local_rm && local_rm->rm)
    {
      HRESULT hr = local_rm->rm->Reenlist ((UCHAR *) recov_data,
	  box_length (recov_data), 0, &xact);
      if (SUCCEEDED (hr))
	{
	  dbg_printf (("done %x\n", xact));
	  if (XACTSTAT_ABORTED == xact)
	    return SQL_ROLLBACK;
	  if (XACTSTAT_COMMITTED == xact)
	    return SQL_COMMIT;
/*	  local_rm->rm->ReenlistmentComplete(); */
	}
      else
	dbg_printf (("reenlist error %x\n", hr));
    }
  return SQL_ROLLBACK;
}

int
mts_check ()
{
  IResourceManagerFactory *rm_factory = 0;
  HRESULT hr =
      DtcGetTransactionManager (0, 0, __uuidof (IResourceManagerFactory),
      0, 0, 0, (void **) &rm_factory);
  if (!rm_factory)
    return 0;
  rm_factory->Release ();
  return 1;
}
