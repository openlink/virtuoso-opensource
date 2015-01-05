/*  lobdata.h
 *
 *  $Id$
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
 *  
*/

#include "headers.h"
#include "asserts.h"
#include "rowset.h"
#include "lobdata.h"
#include "dllmodule.h"

/**********************************************************************/
/* CGetDataSequentialStream                                           */

CGetDataSequentialStream::CGetDataSequentialStream()
{
  LOGCALL(("CGetDataSequentialStream::CGetDataSequentialStream()\n"));

  m_status = STATUS_UNINITIALIZED;
  m_pStreamSync = NULL;
  m_pgd = NULL;
  m_pUnkFTM = NULL;
}

CGetDataSequentialStream::~CGetDataSequentialStream()
{
  LOGCALL(("CGetDataSequentialStream::~CGetDataSequentialStream()\n"));
}

HRESULT
CGetDataSequentialStream::Initialize (CGetDataSequentialStreamInitializer* pInitializer)
{
  LOGCALL(("CGetDataSequentialStream::Init(iRecordID = %d, iFieldOrdinal)\n",
    pInitializer->iRecordID, pInitializer->iFieldOrdinal));

  assert(m_status == STATUS_UNINITIALIZED);
  m_status = STATUS_INITIALIZED;

  assert(pInitializer->pStreamSync != NULL && pInitializer->pStreamSync->IsRowsetAlive() && !pInitializer->pStreamSync->IsStreamAlive());
  m_pStreamSync = pInitializer->pStreamSync;
  m_pStreamSync->SetStreamStatus(true);

  assert(pInitializer->pgd != NULL);
  m_pgd = pInitializer->pgd;

  m_iRecordID = pInitializer->iRecordID;
  m_iFieldOrdinal = pInitializer->iFieldOrdinal;
  m_wSqlCType = pInitializer->wSqlCType;
  return S_OK;
}

void
CGetDataSequentialStream::Delete()
{
  LOGCALL(("CGetDataSequentialStream::Delete()\n"));

  if (m_pStreamSync != NULL)
    {
      CriticalSection critical_section(m_pStreamSync);
      m_pStreamSync->SetStreamStatus(false);
      m_pStreamSync = NULL;
    }
  if (m_pUnkFTM != NULL)
    {
      m_pUnkFTM->Release();
      m_pUnkFTM = NULL;
    }
}

HRESULT
CGetDataSequentialStream::GetInterface(REFIID riid, IUnknown** ppUnknown)
{
  LOGCALL (("CGetDataSequentialStream::GetInterface(%s)\n", STRINGFROMGUID (riid)));

  IUnknown* pUnknown = NULL;
  if (riid == IID_ISequentialStream)
    pUnknown = static_cast<ISequentialStream*>(this);
  else if (riid == IID_ISupportErrorInfo)
    pUnknown = static_cast<ISupportErrorInfo*>(this);
  else if (riid == IID_IMarshal)
    {
      CriticalSection critical_section(m_pStreamSync);
      if (m_pUnkFTM == NULL)
	CoCreateFreeThreadedMarshaler(GetControllingUnknown(), &m_pUnkFTM);
      if (m_pUnkFTM != NULL)
	return m_pUnkFTM->QueryInterface(riid, (void**) ppUnknown);
    }
  if (pUnknown == NULL)
    return E_NOINTERFACE;

  *ppUnknown = pUnknown;
  return S_OK;
}

const IID**
CGetDataSequentialStream::GetSupportErrorInfoIIDs()
{
  static const IID* rgpIIDs[] =
  {
    &IID_ISequentialStream,
    NULL
  };

  return rgpIIDs;
}

void
CGetDataSequentialStream::Kill()
{
  LOGCALL(("CGetDataSequentialStream::Kill()\n"));

  assert(m_pStreamSync != NULL);
  CriticalSection critical_section(m_pStreamSync);
  m_status = STATUS_ZOMBIE;
}

STDMETHODIMP
CGetDataSequentialStream::Read(void* pv, ULONG cb, ULONG* pcbRead)
{
  LOGCALL(("CGetDataSequentialStream::Read(cb = %d)\n", cb));

  if (pcbRead != NULL)
    *pcbRead = 0;

  if (cb == 0)
    return S_OK;
  if (pv == NULL)
    return STG_E_INVALIDPOINTER;

  assert(m_pStreamSync != NULL);
  CriticalSection critical_section(m_pStreamSync);
  if (m_status == STATUS_ZOMBIE)
    return E_UNEXPECTED;
  if (m_status == STATUS_FINISHED)
    return S_FALSE;

  SQLLEN cbRead;
  if (m_status == STATUS_INITIALIZED)
    {
#if 0
      HRESULT hr = m_pdsp->ResetLongData(m_iRecordID, m_iFieldOrdinal);
      if (FAILED(hr))
	return hr;
#endif

      m_status = STATUS_INPROGRESS;
    }

  HRESULT hr = m_pgd->GetLongData(m_iRecordID, m_iFieldOrdinal, m_wSqlCType, (char*) pv, cb, cbRead);
  if (FAILED(hr))
    return hr;
  if (hr == S_FALSE)
    {
      m_status = STATUS_FINISHED;
      return hr;
    }

  ULONG cbTerm = 0;
  if (m_wSqlCType == SQL_C_CHAR)
    cbTerm = sizeof(CHAR);
  else if (m_wSqlCType == SQL_C_WCHAR)
    cbTerm = sizeof(WCHAR);
  if (cbRead == SQL_NO_TOTAL || cbRead + cbTerm > cb)
    {
      cbRead = cb - cbTerm;
      if (m_wSqlCType == SQL_C_WCHAR)
	cbRead -= cbRead % sizeof(WCHAR);
      // FIXME: Is it necessary to fill the last 0-3 bytes of the buffer?
    }

  if (pcbRead != NULL)
    *pcbRead = (ULONG)cbRead;
  return S_OK;
}

STDMETHODIMP
CGetDataSequentialStream::Write(void const* pv, ULONG cb, ULONG* pcbWritten)
{
  LOGCALL(("CGetDataSequentialStream::Write(cb = %d)\n", cb));

  if (pcbWritten != NULL)
    *pcbWritten = 0;

  if (cb == 0)
    return S_OK;
  if (pv == NULL)
    return STG_E_INVALIDPOINTER;

  assert(m_pStreamSync != NULL);
  CriticalSection critical_section(m_pStreamSync);
  if (m_status == STATUS_ZOMBIE)
    return E_UNEXPECTED;

  return STG_E_CANTSAVE;
}
