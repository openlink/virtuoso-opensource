/*  connobj.h
 *
 *  $Id$
 *
 *  Connectable objects.
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
#include "connobj.h"
#include "error.h"

/**********************************************************************/
/* CEnumConnectionPoints                                              */

CEnumConnectionPoints::CEnumConnectionPoints()
{
  LOGCALL(("CEnumConnectionPoints::CEnumConnectionPoints()\n"));

  m_pUnkCPC = NULL;
  m_pUnkFTM = NULL;
  m_rgpCP = NULL;
  m_iCurrent = 0;
}

CEnumConnectionPoints::~CEnumConnectionPoints()
{
  LOGCALL(("CEnumConnectionPoints::~CEnumConnectionPoints()\n"));
}

HRESULT
CEnumConnectionPoints::Initialize (CEnumConnectionPointsInitializer* pInitializer)
{
  assert (pInitializer != NULL);
  assert (pInitializer->pUnkCPC != NULL);
  assert (pInitializer->rgpCP != NULL);

  m_pUnkCPC = pInitializer->pUnkCPC;
  m_rgpCP = pInitializer->rgpCP;
  m_iCurrent = pInitializer->iCurrent;
  return S_OK;
}

void
CEnumConnectionPoints::Delete()
{
  if (m_pUnkCPC != NULL)
    {
      m_pUnkCPC->Release();
      m_pUnkCPC = NULL;
    }
  if (m_pUnkFTM != NULL)
    {
      m_pUnkFTM->Release();
      m_pUnkFTM = NULL;
    }
}

HRESULT
CEnumConnectionPoints::GetInterface(REFIID riid, IUnknown** ppUnknown)
{
  LOGCALL (("CEnumConnectionPoints::GetInterface(%s)\n", STRINGFROMGUID (riid)));

  IUnknown* pUnknown = NULL;
  if (riid == IID_IEnumConnectionPoints)
    pUnknown = static_cast<IEnumConnectionPoints*>(this);
  else if (riid == IID_IMarshal)
    {
      CriticalSection critical_section(this);
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
CEnumConnectionPoints::Clone(IEnumConnectionPoints** ppEnum)
{
  LOGCALL(("CEnumConnectionPoints::Clone()\n"));

  if (ppEnum == NULL)
    return E_POINTER;

  *ppEnum = NULL;

  CriticalSection critical_section(this);
  CEnumConnectionPointsInitializer initializer = { m_pUnkCPC, m_rgpCP, m_iCurrent };
  return ComImmediateObj<CEnumConnectionPoints>::CreateInstance (
    NULL, IID_IEnumConnectionPoints, (void**) ppEnum, &initializer
  );
}

STDMETHODIMP
CEnumConnectionPoints::Next(ULONG cConnections, IConnectionPoint** rgpCP, ULONG* pcFetched)
{
  LOGCALL(("CEnumConnectionPoints::Next(%ld)\n", cConnections));

  if (rgpCP == NULL)
    return E_POINTER;
  if (cConnections > 1 && pcFetched == NULL)
    return E_POINTER;

  CriticalSection critical_section(this);

  ULONG iConnections = 0;
  while (iConnections < cConnections)
    {
      IConnectionPoint* pCP = m_rgpCP[m_iCurrent];
      if (pCP == NULL)
	break;
      m_iCurrent++;

      rgpCP[iConnections++] = pCP;
      pCP->AddRef();
    }

  if (pcFetched)
    *pcFetched = iConnections;
  return iConnections < cConnections ? S_FALSE : S_OK;
}

STDMETHODIMP
CEnumConnectionPoints::Reset()
{
  LOGCALL(("CEnumConnectionPoints::Reset()\n"));

  CriticalSection critical_section(this);

  m_iCurrent = 0;
  return S_OK;
}

STDMETHODIMP
CEnumConnectionPoints::Skip(ULONG cConnections)
{
  LOGCALL(("CEnumConnectionPoints::Skip()\n"));

  CriticalSection critical_section(this);

  while (cConnections--)
    {
      IConnectionPoint* pCP = m_rgpCP[m_iCurrent];
      if (pCP == NULL)
	return S_FALSE;
      m_iCurrent++;
    }
  return S_OK;
}

/**********************************************************************/
/* CConnectionPoint                                                   */

CConnectionPoint::CConnectionPoint(REFIID riid)
  : m_riid(riid)
{
  LOGCALL(("CConnectionPoint::CConnectionPoint()\n"));

  m_pUnkFTM = NULL;
}

CConnectionPoint::~CConnectionPoint()
{
  LOGCALL(("CConnectionPoint::~CConnectionPoint()\n"));

  if (m_pUnkFTM != NULL)
    {
      m_pUnkFTM->Release();
      m_pUnkFTM = NULL;
    }
  for (CookieIter iter = m_cookies.begin(); iter != m_cookies.end(); iter++)
    {
      DWORD dwCookie = *iter;
      Module::GetGIT()->RevokeInterfaceFromGlobal(dwCookie);
    }
  m_cookies.clear();
}

bool
CConnectionPoint::HasConnections()
{
  LOGCALL (("CConnectionPoint::HasConnections()\n"));

  CriticalSection critical_section(this);
  return !m_cookies.empty();
}

bool
CConnectionPoint::GetFirstConnection(DWORD* pdwCookie, IUnknown** ppUnkSink)
{
  LOGCALL (("CConnectionPoint::GetFirstConnection()\n"));

  CriticalSection critical_section(this);

  CookieIter iter = m_cookies.begin();
  if (iter == m_cookies.end())
    return false;

  DWORD dwCookie = *iter;
  if (pdwCookie != NULL)
    *pdwCookie = dwCookie;

  if (ppUnkSink != NULL)
    {
      HRESULT hr = Module::GetGIT()->GetInterfaceFromGlobal(dwCookie, IID_IUnknown, (void**) ppUnkSink);
      if (FAILED(hr))
	return false;
    }

  return true;
}

bool
CConnectionPoint::GetNextConnection(DWORD dwCookiePrev, DWORD* pdwCookie, IUnknown** ppUnkSink)
{
  LOGCALL (("CConnectionPoint::GetNextConnection()\n"));

  CriticalSection critical_section(this);

  CookieIter iter = m_cookies.upper_bound(dwCookiePrev);
  if (iter == m_cookies.end())
    return false;

  DWORD dwCookie = *iter;
  if (pdwCookie != NULL)
    *pdwCookie = dwCookie;

  if (ppUnkSink != NULL)
    {
      HRESULT hr = Module::GetGIT()->GetInterfaceFromGlobal(dwCookie, IID_IUnknown, (void**) ppUnkSink);
      if (FAILED(hr))
	return false;
    }

  return true;
}

STDMETHODIMP
CConnectionPoint::QueryInterface(REFIID riid, void** ppv)
{
  LOGCALL(("CConnectionPoint::QueryInterface(riid = %s)\n", StringFromGuid(riid)));

  if (ppv == NULL)
    return E_INVALIDARG;
  *ppv = NULL;

  if (riid == IID_IUnknown || riid == IID_IConnectionPoint)
    {
      AddRef();
      *ppv = static_cast<IConnectionPoint*>(this);
      return S_OK;
    }
  else if (riid == IID_IMarshal)
    {
      CriticalSection critical_section(&Module::m_GlobalSync);
      if (m_pUnkFTM == NULL)
	CoCreateFreeThreadedMarshaler(static_cast<IConnectionPoint*>(this), &m_pUnkFTM);
      if (m_pUnkFTM != NULL)
	return m_pUnkFTM->QueryInterface(riid, ppv);
    }
  return E_NOINTERFACE;
}

STDMETHODIMP
CConnectionPoint::Advise(IUnknown *pUnkSink, DWORD *pdwCookie)
{
  LOGCALL(("CConnectionPoint::Advise()\n"));

  if (pdwCookie == NULL)
    return E_POINTER;
  *pdwCookie = 0;

  if (pUnkSink == NULL)
    return E_POINTER;

  AutoInterface<IUnknown> pSink;
  HRESULT hr = pSink.QueryInterface(pUnkSink, m_riid);
  if (FAILED(hr))
    {
      if (hr == E_NOINTERFACE)
	hr = CONNECT_E_CANNOTCONNECT;
      return hr;
    }

  CriticalSection critical_section(this);

  DWORD dwCookie;
  hr = Module::GetGIT()->RegisterInterfaceInGlobal(pSink.Get(), IID_IUnknown, &dwCookie);
  if (FAILED(hr))
    return hr;

  try {
    m_cookies.insert(dwCookie);
  } catch (...) {
    Module::GetGIT()->RevokeInterfaceFromGlobal(dwCookie);
    return E_OUTOFMEMORY;
  }

  *pdwCookie = dwCookie;
  return S_OK;
}

STDMETHODIMP
CConnectionPoint::EnumConnections(IEnumConnections** ppEnum)
{
  LOGCALL(("CConnectionPoint::EnumConnections()\n"));

  if (ppEnum == NULL)
    return E_POINTER;
  *ppEnum = NULL;

  CEnumConnectionsInitializer initializer = { this, true, 0 };
  return ComImmediateObj<CEnumConnections>::CreateInstance (
    NULL, IID_IEnumConnections, (void**) ppEnum, &initializer
  );
}

STDMETHODIMP
CConnectionPoint::GetConnectionInterface(IID *pIID)
{
  LOGCALL(("CConnectionPoint::GetConnectionInterface()\n"));

  if (pIID == NULL)
    return E_POINTER;
  *pIID = m_riid;
  return S_OK;
}

STDMETHODIMP
CConnectionPoint::GetConnectionPointContainer(IConnectionPointContainer **ppCPC)
{
  LOGCALL(("CConnectionPoint::GetConnectionPointContainer()\n"));

  // CConnectionPoint's GetOuterUnknown() returns the IUnknown of the host object.
  IUnknown* pUnkCPC = GetOuterUnknown();
  assert(pUnkCPC != NULL);

  return pUnkCPC->QueryInterface(IID_IConnectionPointContainer, (void**) ppCPC);
}

STDMETHODIMP
CConnectionPoint::Unadvise(DWORD dwCookie)
{
  LOGCALL(("CConnectionPoint::Unadvise()\n"));

  CriticalSection critical_section(this);

  CookieIter iter = m_cookies.find(dwCookie);
  if (iter == m_cookies.end())
    return CONNECT_E_NOCONNECTION;

  HRESULT hr = Module::GetGIT()->RevokeInterfaceFromGlobal(dwCookie);
  if (FAILED(hr))
    return hr;

  return S_OK;
}

/**********************************************************************/
/* CEnumConnections                                                   */

CEnumConnections::CEnumConnections()
{
  LOGCALL(("CEnumConnections::CEnumConnections()\n"));

  m_pCP = NULL;
  m_pUnkFTM = NULL;
  m_fReset = true;
  m_dwCookieCurrent = 0;
}

CEnumConnections::~CEnumConnections()
{
  LOGCALL(("CEnumConnections::~CEnumConnections()\n"));
}

HRESULT
CEnumConnections::Initialize (CEnumConnectionsInitializer* pInitializer)
{
  assert (pInitializer != NULL);
  assert (pInitializer->pCP != NULL);

  m_pCP = pInitializer->pCP,
  m_fReset = pInitializer->fReset;
  m_dwCookieCurrent = pInitializer->dwCookieCurrent;

  m_pCP->AddRef();
  return S_OK;
}

void
CEnumConnections::Delete()
{
  if (m_pCP != NULL)
    {
      m_pCP->Release();
      m_pCP = NULL;
    }
  if (m_pUnkFTM != NULL)
    {
      m_pUnkFTM->Release();
      m_pUnkFTM = NULL;
    }
}

HRESULT
CEnumConnections::GetInterface(REFIID riid, IUnknown** ppUnknown)
{
  LOGCALL (("CEnumConnections::GetInterface(%s)\n", STRINGFROMGUID (riid)));

  IUnknown* pUnknown = NULL;
  if (riid == IID_IEnumConnections)
    pUnknown = static_cast<IEnumConnections*>(this);
  else if (riid == IID_IMarshal)
    {
      CriticalSection critical_section(this);
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
CEnumConnections::Clone(IEnumConnections **ppEnum)
{
  LOGCALL(("CEnumConnections::Clone()\n"));

  if (ppEnum == NULL)
    return E_POINTER;
  *ppEnum = NULL;

  CEnumConnectionsInitializer initializer = { m_pCP, m_fReset, m_dwCookieCurrent };
  return ComImmediateObj<CEnumConnections>::CreateInstance (
    NULL, IID_IEnumConnections, (void**) ppEnum, &initializer
  );
}

STDMETHODIMP
CEnumConnections::Next(ULONG cConnections, CONNECTDATA *rgpCD, ULONG *pcFetched)
{
  LOGCALL(("CEnumConnections::Next(%ld)\n", cConnections));

  if (rgpCD == NULL)
    return E_POINTER;
  if (cConnections > 1 && pcFetched == NULL)
    return E_POINTER;

  CriticalSection critical_section(this);

  ULONG iConnections = 0;
  if (cConnections > 0)
    {
      bool fHasNext = false;
      DWORD dwCookie;
      IUnknown* pUnkSink;
      if (m_fReset)
	{
	  fHasNext = m_pCP->GetFirstConnection(&dwCookie, &pUnkSink);
	  if (fHasNext)
	    m_fReset = false;
	}
      else
	{
	  fHasNext = m_pCP->GetNextConnection(m_dwCookieCurrent, &dwCookie, &pUnkSink);
	}

      while (fHasNext)
	{
	  m_dwCookieCurrent = dwCookie;

	  rgpCD[iConnections].dwCookie = dwCookie;
	  rgpCD[iConnections].pUnk = pUnkSink;
	  iConnections++;

	  fHasNext = m_pCP->GetNextConnection(m_dwCookieCurrent, &dwCookie, &pUnkSink);
	}
    }

  if (pcFetched)
    *pcFetched = iConnections;
  return iConnections < cConnections ? S_FALSE : S_OK;
}

STDMETHODIMP
CEnumConnections::Reset()
{
  LOGCALL(("CEnumConnections::Reset()\n"));

  CriticalSection critical_section(this);

  m_fReset = true;
  return S_OK;
}

STDMETHODIMP
CEnumConnections::Skip(ULONG cConnections)
{
  LOGCALL(("CEnumConnections::Skip()\n"));

  CriticalSection critical_section(this);

  if (cConnections > 0)
    {
      bool fHasNext = false;
      DWORD dwCookie;
      if (m_fReset)
	{
	  fHasNext = m_pCP->GetFirstConnection(&dwCookie, NULL);
	  if (fHasNext)
	    m_fReset = false;
	}
      else
	{
	  fHasNext = m_pCP->GetNextConnection(m_dwCookieCurrent, &dwCookie, NULL);
	}

      while (fHasNext)
	{
	  cConnections--;
	  m_dwCookieCurrent = dwCookie;
	  fHasNext = m_pCP->GetNextConnection(m_dwCookieCurrent, &dwCookie, NULL);
	}
    }

  return cConnections ? S_FALSE : S_OK;
}
