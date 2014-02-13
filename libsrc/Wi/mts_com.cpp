/*
 *  mts_com.cpp
 *
 *  $Id$
 *
 *  MS DTC support
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2014 OpenLink Software
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
#include "Wi.h"
#include "thread\dkthread.h"
#include "sqlnode.h"
#include "2pc.h"
}


#include <txdtc.h>
#include <xolehlp.h>
#include <transact.h>



#include "mts_com.h"

extern "C"
{
#include "import_gate_virtuoso.h"
}

void *mts_create_message (int type, ITransactionEnlistmentAsync * enlistment,
    void *client_connection);

CResMgrSink::CResMgrSink ():ref_count (0)
{
};

ULONG CResMgrSink::AddRef ()
{
  InterlockedIncrement ((long *) &ref_count);
  MTS_TRACE (("IResourceManagerSink::AddRef\n"));
  return ref_count;
};

ULONG CResMgrSink::Release ()
{
  InterlockedDecrement ((long *) &ref_count);
  MTS_TRACE (("IResourceManagerSink::ReleaseRef\n"));
  /* subject of change */
  if (!ref_count)
    delete this;
  return ref_count;
};

HRESULT CResMgrSink::QueryInterface (const struct _GUID & guid, void **iFace)
{
  MTS_TRACE (("IResourceManagerSink::QueryInterface\n"));
  if (guid == IID_IResourceManagerSink)
    {
      *iFace = this;
      return S_OK;
    };
  if (guid == IID_IUnknown)
    {
      *iFace = static_cast < IUnknown * >(this);
      return S_OK;
    };
  *iFace = 0;
  return E_NOINTERFACE;
};

HRESULT CResMgrSink::TMDown ()
{
  MTS_TRACE (("IResourceManagerSink::shut down!\n"));
  return S_OK;
};


CTransactResourceAsync::CTransactResourceAsync ():ref_count (0)
{
};

void
CTransactResourceAsync::SetEnlistment (ITransactionEnlistmentAsync * trxea)
{
  trx_enlistment_ = trxea;
}

void
CTransactResourceAsync::SetConnection (void *client_connection)
{
  client_connection_ = client_connection;
}

ULONG CTransactResourceAsync::AddRef ()
{
  InterlockedIncrement ((long *) &ref_count);
  MTS_TRACE (("TRA::AddRef\n"));
  return ref_count;
};

ULONG CTransactResourceAsync::Release ()
{
  InterlockedDecrement ((long *) &ref_count);
  MTS_TRACE (("TRA::ReleaseRef\n"));
  /* subject of change */
  if (!ref_count)
    delete this;
  return ref_count;
};

HRESULT
    CTransactResourceAsync::QueryInterface (const struct _GUID & guid,
    void **iFace)
{
  MTS_TRACE (("TRA::QueryInterface\n"));
  if (guid == IID_ITransactionResourceAsync)
    {
      *iFace = this;
      return S_OK;
    };
  if (guid == IID_IUnknown)
    {
      *iFace = static_cast < IUnknown * >(this);
      return S_OK;
    };
  *iFace = 0;
  return E_NOINTERFACE;
};

int
log_debug (char *format, ...)
{
  va_list ap;
  int rc;

  va_start (ap, format);
  rc = server_logmsg_ap (LOG_DEBUG, NULL, 0, 1, format, ap);
  va_end (ap);

  return rc;
}

HRESULT CTransactResourceAsync::PrepareRequest (
    /* [in] */ BOOL fRetaining,
    /* [in] */ DWORD grfRM,
    /* [in] */ BOOL fWantMoniker,
    /* [in] */ BOOL fSinglePhase)
{
  MTS_TRACE (("TRA::prepare...\n"));
  mts_log_debug (("PrepareRequest res=%p cli=%p", trx_enlistment_,
	  client_connection_));
  void *
      mts_message =
      mts_create_message (TP_PREPARE, trx_enlistment_, client_connection_);
  mq_add_message (tp_get_main_queue (), mts_message);
  return S_OK;
};

HRESULT CTransactResourceAsync::CommitRequest (
    /* [in] */ DWORD grfRM,
    /* [in] */ XACTUOW __RPC_FAR * pNewUOW)
{
  MTS_TRACE (("TRA::commit...\n"));
  mts_log_debug (("CommitRequest res=%p cli=%p", trx_enlistment_,
	  client_connection_));
  void *
      mts_message =
      mts_create_message (TP_COMMIT, trx_enlistment_, client_connection_);
  mq_add_message (tp_get_main_queue (), mts_message);
  return S_OK;
};

HRESULT CTransactResourceAsync::AbortRequest (
    /* [in] */ BOID __RPC_FAR * pboidReason,
    /* [in] */ BOOL fRetaining,
    /* [in] */ XACTUOW __RPC_FAR * pNewUOW)
{
  MTS_TRACE (("TRA::abort...\n"));
  mts_log_debug (("AbortRequest res=%p cli=%p", trx_enlistment_,
	  client_connection_));
  void *
      mts_message =
      mts_create_message (TP_ABORT, trx_enlistment_, client_connection_);
  mq_add_message (tp_get_main_queue (), mts_message);
  return S_OK;
};

HRESULT CTransactResourceAsync::TMDown (void)
{
  MTS_TRACE (("TRA::down...\n"));
  return S_OK;
};

void *
    CTransactResourceAsync::operator
new (size_t sz)
{
  MTS_TRACE (("TRA::operator new...\n"));
  return dk_alloc (sz);
};

void
    CTransactResourceAsync::operator
delete (void *p)
{
  MTS_TRACE (("TRA::operator delete\n"));
  dk_free (p, -1);
}

void *
mts_create_message (int type, ITransactionEnlistmentAsync * enlistment,
    void *client_connection)
{
  static queue_vtbl_t mts_vtbl = {
    mts_prepare_done,
    mts_commit_done,
    mts_abort_done,
    mts_prepare_set_log
  };
  tp_message_t *mts_message =
      mq_create_message (type, enlistment, client_connection);
  mts_message->vtbl = &mts_vtbl;

  return mts_message;
}
