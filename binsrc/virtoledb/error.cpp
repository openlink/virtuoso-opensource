/*  error.cpp
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
 *  
*/

#include "headers.h"
#include "asserts.h"
#include "error.h"
#include "dllmodule.h"
#include "util.h"

/**********************************************************************/
/* ErrorInfo                                                          */

#define ERROR_RECKLESS ((ErrorInfo*) 0)
#define ERROR_CAUTIOUS ((ErrorInfo*) 1)

#if GLOBAL_ERROR_FACTORY
IClassFactory* ErrorInfo::m_pErrorObjectFactory = NULL;
#endif
std::map<LONG, std::string> ErrorInfo::m_dynamicLookupMap;
std::multimap<LONG, LONG> ErrorInfo::m_dynamicReleaseMap;
LONG ErrorInfo::m_dwLastLookupID = LID_DynamicErrorBase;
LONG ErrorInfo::m_dwLastDynamicID = 0;
SyncObj ErrorInfo::m_sync;

HRESULT
ErrorInfo::Init()
{
  LOGCALL(("ErrorInfo::Init()\n"));

#if GLOBAL_ERROR_FACTORY
  assert(m_pErrorObjectFactory == NULL);

  HRESULT hr = CoGetClassObject(CLSID_EXTENDEDERRORINFO, CLSCTX_INPROC_SERVER, NULL,
				IID_IClassFactory, (void**) &m_pErrorObjectFactory);
  if (FAILED(hr))
    return hr;

  return m_pErrorObjectFactory->LockServer(TRUE);
#else
  return S_OK;
#endif
}

void
ErrorInfo::Fini()
{
  LOGCALL(("ErrorInfo::Fini()\n"));

#if GLOBAL_ERROR_FACTORY
  if (m_pErrorObjectFactory != NULL)
    {
      m_pErrorObjectFactory->LockServer(FALSE);
      m_pErrorObjectFactory->Release();
      m_pErrorObjectFactory = NULL;
    }
#endif
}

ErrorInfo*
ErrorInfo::Get()
{
  return static_cast<ErrorInfo*>(TlsGetValue(Module::GetTlsIndex()));
}

ErrorInfo*
ErrorInfo::InternalSet(HRESULT hrError, DWORD dwLookupId, DWORD dwDynamicErrorId, ErrorInfo* pNext)
{
  static ErrorInfo s_OutOfMemory(E_OUTOFMEMORY, IDENTIFIER_SDK_ERROR, 0, NULL);
  if (hrError == E_OUTOFMEMORY)
    {
      assert(dwLookupId == IDENTIFIER_SDK_ERROR && dwDynamicErrorId == 0);
      TlsSetValue(Module::GetTlsIndex(), &s_OutOfMemory);
      delete pNext;
      return NULL;
    }
  else
    {
      ErrorInfo* pErrorInfo = new ErrorInfo(hrError, dwLookupId, dwDynamicErrorId, pNext);
      if (pErrorInfo == NULL)
	{
	  TlsSetValue(Module::GetTlsIndex(), &s_OutOfMemory);
	  delete pNext;
	  return NULL;
	}
      TlsSetValue(Module::GetTlsIndex(), pErrorInfo);
      return pErrorInfo;
    }
}

HRESULT
ErrorInfo::Set(HRESULT hrError, DWORD dwLookupId)
{
  LOGCALL (("ErrorInfo::Set(herr=%ld)\n", (unsigned long) hrError));
  ErrorInfo* pErrorInfo = Get();
  if (pErrorInfo == ERROR_RECKLESS)
    return hrError;
  assert(pErrorInfo == ERROR_CAUTIOUS);

  return InternalSet(hrError, dwLookupId, 0, NULL) ? hrError : E_OUTOFMEMORY;
}

HRESULT
ErrorInfo::Set(HRESULT hrError, const std::string& description)
{
  LOGCALL (("ErrorInfo::Set()\n"));

  ErrorInfo* pErrorInfo = Get();
  if (pErrorInfo == ERROR_RECKLESS)
    return hrError;
  assert(pErrorInfo == ERROR_CAUTIOUS);

  try {
    CriticalSection critical_section(&m_sync);
    if (m_dynamicLookupMap.size() == 0)
      {
	m_dwLastLookupID = LID_DynamicErrorBase;
	m_dwLastDynamicID = 0;
      }
    DWORD dwDynamicID = ++m_dwLastDynamicID;
    DWORD dwLookupID = ++m_dwLastLookupID;
    m_dynamicReleaseMap.insert(DynamicReleaseMap::value_type(dwDynamicID, dwLookupID));
    m_dynamicLookupMap.insert(DynamicLookupMap::value_type(dwLookupID, description));
    return InternalSet(hrError, dwLookupID, dwDynamicID, NULL) ? hrError : E_OUTOFMEMORY;
  } catch (...) {
    return Set(E_OUTOFMEMORY);
  }
}

HRESULT
ErrorInfo::Set(HRESULT hrError, SQLSMALLINT handleType, SQLHANDLE handle)
{
  LOGCALL (("ErrorInfo::Set()\n"));

  ErrorInfo* pErrorInfo = Get();
  if (pErrorInfo == ERROR_RECKLESS)
    return hrError;
  assert(pErrorInfo == ERROR_CAUTIOUS);

    CriticalSection critical_section(&m_sync);
    if (m_dynamicLookupMap.size() == 0)
      {
	m_dwLastLookupID = LID_DynamicErrorBase;
	m_dwLastDynamicID = 0;
      }
    DWORD dwDynamicID = ++m_dwLastDynamicID;

    ErrorInfo* next = NULL;

    SQLCHAR sql_state[6], error_msg[SQL_MAX_MESSAGE_LENGTH];
    SQLSMALLINT error_msg_len;
    SQLINTEGER native_error;
    for (SQLSMALLINT i = 1;
	 SQLGetDiagRec(handleType, handle, i, sql_state, &native_error,
		       error_msg, sizeof error_msg, &error_msg_len) != SQL_NO_DATA;
	 i++)
      {
	DWORD dwLookupID = ++m_dwLastLookupID;
	m_dynamicReleaseMap.insert(DynamicReleaseMap::value_type(dwDynamicID, dwLookupID));
	m_dynamicLookupMap.insert(DynamicLookupMap::value_type(dwLookupID, (char*) error_msg));
	next = InternalSet(hrError, dwLookupID, dwDynamicID, next);
	if (next == NULL)
	  return E_OUTOFMEMORY;
      }
    return hrError;
}

void
ErrorInfo::Allow()
{
  assert(Get() == ERROR_RECKLESS);
  TlsSetValue(Module::GetTlsIndex(), ERROR_CAUTIOUS);
}

void
ErrorInfo::Check(REFIID riid, DISPID dispid)
{
  ErrorInfo* pErrorInfo = Get();
  if (pErrorInfo == ERROR_RECKLESS)
    ; // do nothing
  else
    {
      TlsSetValue(Module::GetTlsIndex(), ERROR_RECKLESS);
      if (pErrorInfo == ERROR_CAUTIOUS)
	{
	  // Clear the current error object.
	  ::SetErrorInfo(0, NULL);
	}
      else
	{
	  pErrorInfo->Post(riid, dispid);
	  // OUTOFMEMORY ErrorInfo is always a static variable.
	  if (pErrorInfo->GetErrorCode() != E_OUTOFMEMORY)
	    delete pErrorInfo;
	}
    }
}

void
ErrorInfo::Clear()
{
  ErrorInfo* pErrorInfo = Get();
  if (pErrorInfo == ERROR_RECKLESS || pErrorInfo == ERROR_CAUTIOUS)
    ; // do nothing
  else
    {
      // Since there was a error object then the error reporting has been allowed before.
      TlsSetValue(Module::GetTlsIndex(), ERROR_CAUTIOUS);
      // OUTOFMEMORY ErrorInfo is always a static variable.
      if (pErrorInfo->GetErrorCode() != E_OUTOFMEMORY)
	delete pErrorInfo;
    }
}

HRESULT
ErrorInfo::GetDynamicError(DWORD dwLookupId, BSTR* pbstrDescription)
{
  LOGCALL (("ErrorInfo::GetDynamicError()\n"));

  CriticalSection critical_section(&m_sync);
  DynamicLookupMap::iterator error = m_dynamicLookupMap.find(dwLookupId);
  if (error == m_dynamicLookupMap.end())
    return DB_E_BADLOOKUPID;
  return string2bstr(error->second, pbstrDescription);
}

HRESULT
ErrorInfo::ReleaseErrors(DWORD dwDynamicErrorId)
{
  LOGCALL (("ErrorInfo::ReleaseErrors()\n"));
  CriticalSection critical_section(&m_sync);
  std::pair<DynamicReleaseMap::iterator, DynamicReleaseMap::iterator>
    range = m_dynamicReleaseMap.equal_range(dwDynamicErrorId);
  DynamicReleaseMap::iterator i = range.first;
  if (i == m_dynamicReleaseMap.end())
    return DB_E_BADDYNAMICERRORID;
  for (; i != range.second; i++)
    m_dynamicLookupMap.erase(i->second);
  m_dynamicReleaseMap.erase(range.first, range.second);
  return S_OK;
}

ErrorInfo::ErrorInfo(HRESULT hrError, DWORD dwLookupId, DWORD dwDynamicErrorId, ErrorInfo* pNext)
{
  m_hrError = hrError;
  m_dwLookupId = dwLookupId;
  m_dwDynamicErrorId = dwDynamicErrorId;
  m_pNext = pNext;
}

ErrorInfo::~ErrorInfo()
{
  delete m_pNext;
}

void
ErrorInfo::Post(REFIID riid, DISPID dispid)
{
  AutoInterface<IErrorRecords> pErrorRecords;
#if GLOBAL_ERROR_FACTORY
  HRESULT hr = pErrorRecords.CreateInstance(m_pErrorObjectFactory, NULL, IID_IErrorRecords);
#else
  HRESULT hr = pErrorRecords.CreateInstance(CLSID_EXTENDEDERRORINFO, NULL, IID_IErrorRecords);
#endif
  if (FAILED(hr))
    {
      TRACE((__FILE__, __LINE__, "Cannot create error object\n"));
      return;
    }

  ErrorInfo* next = this;
  do
    {
      ERRORINFO error_info;
      error_info.hrError = next->m_hrError;
      error_info.dwMinor = next->m_dwLookupId;
      error_info.clsid = CLSID_VIRTOLEDB;
      error_info.iid = riid;
      error_info.dispid = dispid;

      hr = pErrorRecords->AddErrorRecord(&error_info, next->m_dwLookupId, NULL, NULL, next->m_dwDynamicErrorId);
      if (FAILED(hr))
	{
	  TRACE((__FILE__, __LINE__, "Cannot add error record.\n"));
	  return;
	}

      next = next->GetNext();
    }
  while(next != NULL);

  AutoInterface<IErrorInfo> pErrorInfo;
  hr = pErrorInfo.QueryInterface(pErrorRecords.Get(), IID_IErrorInfo);
  if (FAILED(hr))
    {
      TRACE((__FILE__, __LINE__, "Cannot get error info interface\n"));
      return;
    }
  hr = SetErrorInfo(0, pErrorInfo.Get());
  if (FAILED(hr))
    {
      TRACE((__FILE__, __LINE__, "Cannot set error info\n"));
      return;
    }
}

/**********************************************************************/
/* CErrorLookup                                                       */

HRESULT
CErrorLookup::GetInterface(REFIID riid, IUnknown** ppUnknown)
{
  LOGCALL (("CErrorLookup::GetInterface(%s)\n", STRINGFROMGUID (riid)));

  IUnknown* pUnknown = NULL;
  if (riid == IID_IErrorLookup)
    pUnknown = static_cast<IErrorLookup*>(this);
  else if (riid == IID_IMarshal)
    {
      CriticalSection critical_section(&Module::m_GlobalSync);
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

STDMETHODIMP
CErrorLookup::GetErrorDescription
(
  HRESULT hrError,
  DWORD dwLookupID,
  DISPPARAMS* pdipsparams,
  LCID lcid,
  BSTR* pbstrSource,
  BSTR* pbstrDescription
)
{
  LOGCALL(("CErrorLookup::GetErrorDescription(0x%x, 0x%x)\n", hrError, dwLookupID));

  if (pbstrSource != NULL)
    *pbstrSource = NULL;
  if (pbstrDescription != NULL)
    *pbstrDescription = NULL;

  if (pbstrSource == NULL || pbstrDescription == NULL)
    return E_INVALIDARG;

  BSTR bstrSource = SysAllocString(L"OpenLink OLE DB Provider for Virtuoso");
  if (bstrSource == NULL)
    return E_OUTOFMEMORY;

  BSTR bstrDescription = NULL;
  if (dwLookupID & IDENTIFIER_SDK_MASK)
    ; // do nothing
  else if (dwLookupID > LID_DynamicErrorBase)
    {
      HRESULT hr = ErrorInfo::GetDynamicError(dwLookupID, &bstrDescription);
      if (FAILED(hr))
	return hr;
    }
  else
    {
      switch (dwLookupID)
	{
	case LID_Unknown:
	  bstrDescription = SysAllocString(L"An unknown error occured");
	  break;
	default:
	  SysFreeString(bstrSource);
	  return DB_E_BADLOOKUPID;
	}
      if (bstrDescription == NULL)
	{
	  SysFreeString(bstrSource);
	  return E_OUTOFMEMORY;
	}
    }

  *pbstrSource = bstrSource;
  *pbstrDescription = bstrDescription;
  return S_OK;
}

STDMETHODIMP
CErrorLookup::GetHelpInfo
(
  HRESULT hrError,
  DWORD dwLookupID,
  LCID lcid,
  BSTR* pbstrHelpFile,
  DWORD* pdwHelpContext
)
{
  LOGCALL(("CErrorLookup::GetHelpInfo()\n"));

  if (pbstrHelpFile != NULL)
    *pbstrHelpFile = NULL;
  if (pdwHelpContext != NULL)
    *pdwHelpContext = 0;

  if (pbstrHelpFile == NULL || pdwHelpContext == NULL)
    return E_INVALIDARG;

  return S_OK;
}

STDMETHODIMP
CErrorLookup::ReleaseErrors
(
  const DWORD dwDynamicErrorId
)
{
  LOGCALL(("CErrorLookup::ReleaseErrors(%d)\n", dwDynamicErrorId));

  return ErrorInfo::ReleaseErrors(dwDynamicErrorId);
}
