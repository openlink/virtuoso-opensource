/*  connobj.h
 *
 *  $Id$
 *
 *  Connectable objects.
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

#ifndef CONNOBJ_H
#define CONNOBJ_H

#include "baseobj.h"
#include "syncobj.h"


struct CEnumConnectionPointsInitializer
{
  IUnknown* pUnkCPC;
  IConnectionPoint** rgpCP;
  ULONG iCurrent;
};

template<class T>
class NOVTABLE IConnectionPointContainerImpl : public IConnectionPointContainer
{
public:

  STDMETHODIMP
  EnumConnectionPoints(IEnumConnectionPoints **ppEnum)
  {
    LOGCALL(("%s::EnumConnectionPoints()\n", typeid(*this).name()));

    if (ppEnum == NULL)
      return E_POINTER;
    *ppEnum = NULL;

    T* theObj = static_cast<T*>(this);
    CEnumConnectionPointsInitializer initializer = {
      theObj->GetControllingUnknown(), theObj->GetConnectionPoints(), 0
    };
    return ComImmediateObj<CEnumConnectionPoints>::CreateInstance (
      NULL, IID_IEnumConnectionPoints, (void**) ppEnum, &initializer
    );
  }

  STDMETHODIMP
  FindConnectionPoint(REFIID riid, IConnectionPoint **ppCP)
  {
    if (ppCP == NULL)
      return E_POINTER;
    *ppCP = NULL;

    T* theObj = static_cast<T*>(this);
    IConnectionPoint** rgpCP = theObj->GetConnectionPoints();
    assert(rgpCP != NULL);

    for (;;)
      {
	IConnectionPoint* pCP = *rgpCP++;
	if (pCP == NULL)
	  break;

	IID iid;
	HRESULT hr = pCP->GetConnectionInterface(&iid);
	if (SUCCEEDED(hr) && riid == iid)
	  {
	    pCP->AddRef();
	    *ppCP = pCP;
	    return S_OK;
	  }
      }
    return CONNECT_E_NOCONNECTION;
  }

};


class CEnumConnectionPoints : public IEnumConnectionPoints, public ComObjBase, public SyncObj
{
public:

  CEnumConnectionPoints();
  ~CEnumConnectionPoints();

  HRESULT Initialize (CEnumConnectionPointsInitializer* pInitializer);
  
  void Delete();

  virtual HRESULT GetInterface(REFIID riid, IUnknown** ppUnknown);

  // IEnumConnectionPoints members

  STDMETHODIMP Clone(IEnumConnectionPoints** ppEnum);
  STDMETHODIMP Next(ULONG cConnections, IConnectionPoint** rgpCP, ULONG* pcFetched);
  STDMETHODIMP Reset();
  STDMETHODIMP Skip(ULONG cConnections);

private:

  IUnknown* m_pUnkCPC;
  IUnknown* m_pUnkFTM;
  IConnectionPoint** m_rgpCP;
  ULONG m_iCurrent;
};


// Connection point objects are subordinate objects of their host object.
// They implement their own IUnknown, but reference counting is delegated
// to the host object, which implements IConnectionPointContainer.
class CConnectionPoint : public IConnectionPoint, public ComObjRoot, public SyncObj
{
public:

  CConnectionPoint(REFIID riid);
  ~CConnectionPoint();

  void
  Init(IUnknown* pUnkCPC)
  {
    assert(pUnkCPC != NULL);
    SetOuterUnknown(pUnkCPC);
  }

  // The value returned by HasConnections() doesn't provide reliable info
  // about the value that the next call to GetFirstConnection() will return
  // because another thread could unadvise the connection just between the
  // two calls. However, HasConnections() is useful when it's possible to
  // optimize by *not calling* an impending GetFirstConnection() along with
  // other possibly costly operations that may accompany it.
  bool HasConnections();
  bool GetFirstConnection(DWORD* pdwCookie, IUnknown** ppUnkSink);
  bool GetNextConnection(DWORD dwCookiePrev, DWORD* pdwCookie, IUnknown** ppUnkSink);

  bool
  Before(DWORD dwCookie1, DWORD dwCookie2)
  {
    return dwCookie1 < dwCookie2;
  }

  // IUnknown members

  STDMETHODIMP QueryInterface(REFIID riid, void** ppv);

  STDMETHODIMP_(ULONG)
  AddRef()
  {
    return OuterAddRef();
  }

  STDMETHODIMP_(ULONG)
  Release()
  {
    return OuterRelease();
  }

  // IConnectionPoint members

  STDMETHODIMP Advise(IUnknown *pUnk, DWORD *pdwCookie);
  STDMETHODIMP EnumConnections(IEnumConnections **ppEnum);
  STDMETHODIMP GetConnectionInterface(IID *pIID);
  STDMETHODIMP GetConnectionPointContainer(IConnectionPointContainer **ppCPC);
  STDMETHODIMP Unadvise(DWORD dwCookie);

private:

  typedef std::set<DWORD> CookieEnum;
  typedef CookieEnum::iterator CookieIter;

  REFIID m_riid;
  CookieEnum m_cookies;
  IUnknown* m_pUnkFTM;
};


struct CEnumConnectionsInitializer
{
  CConnectionPoint* pCP;
  bool fReset;
  DWORD dwCookieCurrent;
};

class NOVTABLE CEnumConnections : public IEnumConnections, public ComObjBase, public SyncObj
{
public:

  CEnumConnections();
  ~CEnumConnections();

  HRESULT Initialize (CEnumConnectionsInitializer* pInitializer);

  void Delete();

  virtual HRESULT GetInterface(REFIID riid, IUnknown** ppUnknown);

  // IEnumConnections members

  STDMETHODIMP Clone(IEnumConnections** ppEnum);
  STDMETHODIMP Next(ULONG cConnections, CONNECTDATA* rgpCD, ULONG* pcFetched);
  STDMETHODIMP Reset();
  STDMETHODIMP Skip(ULONG cConnections);

private:

  CConnectionPoint* m_pCP;
  IUnknown* m_pUnkFTM;
  bool m_fReset;
  ULONG m_dwCookieCurrent;
};


#endif
