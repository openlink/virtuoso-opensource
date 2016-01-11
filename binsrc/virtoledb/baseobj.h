/*  baseobj.h
 *
 *  $Id$
 *
 *  Base class for COM objects.
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
 *  
*/

#ifndef BASEOBJ_H
#define BASEOBJ_H

#include "dllmodule.h"

#if _MSC_VER
# pragma warning(disable:4355)
#endif

#if _MSC_VER
# define NOVTABLE __declspec(novtable)
#else
# define NOVTABLE
#endif


// The root class for all COM objects. However ordinary COM objects should not
// generally derive from it directly. Instead they should derive from ComObjBase
// which in turn derives from ComObjRoot.
class ComObjRoot
{
public:

  ComObjRoot()
  {
    m_iRef = 0;
  }

  ULONG
  InternalAddRef()
  {
    assert(m_iRef != -1);
    return InterlockedIncrement(&m_iRef);
  }

  ULONG
  InternalRelease()
  {
    assert(m_iRef > 0);
    return InterlockedDecrement(&m_iRef);
  }

  ULONG
  OuterAddRef()
  {
    assert(m_pOuterUnknown != NULL);
    return m_pOuterUnknown->AddRef();
  }

  ULONG
  OuterRelease()
  {
    assert(m_pOuterUnknown != NULL);
    return m_pOuterUnknown->Release();
  }

  HRESULT
  OuterQueryInterface(REFIID riid, void** ppv)
  {
    assert(m_pOuterUnknown != NULL);
    return m_pOuterUnknown->QueryInterface(riid, ppv);
  }

protected:

  void
  SetOuterUnknown(IUnknown* pOuterUnknown)
  {
    m_pOuterUnknown = pOuterUnknown;
  }

  IUnknown*
  GetOuterUnknown()
  {
    return m_pOuterUnknown;
  }

  union
  {
    long m_iRef;
    IUnknown* m_pOuterUnknown;
  };
};


// The root class for ordinary COM objects. Ordinary objects are those that in
// the end get wrapped either into ComImmediateObj<> or ComAggregateObj<>.
class NOVTABLE ComObjBase : public IUnknown, public ComObjRoot
{
public:

/*
  HRESULT
  Create()
  {
    return S_OK;
  }
  */

  void
  Delete()
  {
  }

  HRESULT InternalQueryInterface(REFIID riid, void** ppv);

  virtual HRESULT GetInterface(REFIID riid, IUnknown** ppUnknown) = 0;

  virtual IUnknown*
  GetControllingUnknown()
  {
    return static_cast<IUnknown*>(this);
  }
};


// ComObj should derive from ComObjBase. Also it must have GetInterface() defined.
template <class ComObj>
class ComImmediateObj : public ComObj
{
public:

  ComImmediateObj()
  {
    Module::Lock();
  }

  ~ComImmediateObj()
  {
    Delete();
    Module::Unlock();
  }

  STDMETHODIMP
  QueryInterface(REFIID riid, void** ppv)
  {
    return InternalQueryInterface(riid, ppv);
  }

  STDMETHODIMP_(ULONG)
  AddRef()
  {
    LOGCALL(("%s::AddRef(), %d\n", typeid(*this).name(), m_iRef + 1));

    return InternalAddRef();
  }

  STDMETHODIMP_(ULONG)
  Release()
  {
    LOGCALL(("%s::Release(), %d\n", typeid(*this).name(), m_iRef - 1));

    LONG ul = InternalRelease();
    if (ul == 0)
      delete this;
    return ul;
  }

  template <class Initializer>
  static HRESULT
  CreateInstance (
    IUnknown* pUnkOuter, REFIID riid, void** ppv,
    Initializer* pInitializer, ComObj** ppComObj = NULL
  )
  {
    LOGCALL(("ComImmediateObj::CreateInstance(pUnkOuter=%x, riid=%s)\n", pUnkOuter, StringFromGuid(riid)));

    if (pUnkOuter != NULL)
      return DB_E_NOAGGREGATION;

    ComImmediateObj<ComObj>* pObj = new ComImmediateObj<ComObj>();
    if (pObj == NULL)
      return ErrorInfo::Set(E_OUTOFMEMORY);

    HRESULT hr = pObj->Initialize (pInitializer);
    if (FAILED(hr))
      {
	delete pObj;
	return hr;
      }

    hr = pObj->QueryInterface(riid, ppv);
    if (FAILED(hr))
      {
	delete pObj;
	return hr;
      }

    if (ppComObj != NULL)
      *ppComObj = (ComObj*) pObj;

    return hr;
  }
};


// ComDelegateObj is an auxiliary class used by ComAggregateObj.
// ComObj should derive from ComObjBase. Also it must have GetInterface() defined.
template <class ComObj>
class ComDelegateObj : public ComObj
{
public:

  ComDelegateObj(IUnknown* pUnkOuter)
  {
    SetOuterUnknown(pUnkOuter);
  }

  STDMETHODIMP
  QueryInterface(REFIID riid, void** ppv)
  {
    return OuterQueryInterface(riid, ppv);
  }

  STDMETHODIMP_(ULONG)
  AddRef()
  {
    LOGCALL(("%s::AddRef(), (outer)\n", typeid(*this).name()));

    return OuterAddRef();
  }

  STDMETHODIMP_(ULONG)
  Release()
  {
    LOGCALL(("%s::Release(), (outer)\n", typeid(*this).name()));

    return OuterRelease();
  }

  virtual IUnknown*
  GetControllingUnknown()
  {
    return GetOuterUnknown();
  }
};


// ComObj should derive from ComObjBase. Also it must have GetInterface() defined.
template <class ComObj>
class ComAggregateObj : public IUnknown, public ComObjRoot
{
public:

  ComAggregateObj(IUnknown* pUnknownOuter)
    : m_object(pUnknownOuter == NULL ? this : pUnknownOuter)
  {
    Module::Lock();
  }

  ~ComAggregateObj()
  {
    m_object.Delete();
    Module::Unlock();
  }

  STDMETHODIMP
  QueryInterface(REFIID riid, void** ppv)
  {
    if (riid == IID_IUnknown)
      {
	if (ppv == NULL)
	  return E_INVALIDARG;
	*ppv = static_cast<IUnknown*>(this);
	InternalAddRef();
	return S_OK;
      }
    return m_object.InternalQueryInterface(riid, ppv);
  }

  STDMETHODIMP_(ULONG)
  AddRef()
  {
    LOGCALL(("%s::AddRef(), %d\n", typeid(*this).name(), m_iRef + 1));

    return InternalAddRef();
  }

  STDMETHODIMP_(ULONG)
  Release()
  {
    LOGCALL(("%s::Release(), %d\n", typeid(*this).name(), m_iRef - 1));

    LONG ul = InternalRelease();
    if (ul == 0)
      delete this;
    return ul;
  }

  template <class Initializer>
  static HRESULT
  CreateInstance (
    IUnknown* pUnkOuter, REFIID riid, void** ppv,
    Initializer* pInitializer, ComObj** ppComObj = NULL
  )
  {
    LOGCALL(("ComAggregateObj::CreateInstance(pUnkOuter=%x, riid=%s)\n", pUnkOuter, StringFromGuid(riid)));

    if (pUnkOuter != NULL && riid != IID_IUnknown)
      return DB_E_NOAGGREGATION;

    ComAggregateObj<ComObj>* pObj = new ComAggregateObj<ComObj>(pUnkOuter);
    if (pObj == NULL)
      return ErrorInfo::Set(E_OUTOFMEMORY);

    HRESULT hr = pObj->m_object.Initialize (pInitializer);
    if (FAILED(hr))
      {
	delete pObj;
	return hr;
      }

    hr = pObj->QueryInterface(riid, ppv);
    if (FAILED(hr))
      {
	delete pObj;
	return hr;
      }

    if (ppComObj != NULL)
      *ppComObj = (ComObj*) &pObj->m_object;

    return hr;
  }

private:

  ComDelegateObj<ComObj> m_object;
};


// This class instantinates two different templates based on the same object.
// Therefore it bloats the generated code. So it is advisable to use either
// ComImmediateObj or ComAggregateObj whenever appropriate.
template <class ComObj>
class ComAdaptiveObjCreator
{
public:

  template <class Initializer>
  static HRESULT
  CreateInstance (
    IUnknown* pUnkOuter, REFIID riid, void** ppv,
    Initializer* pInitializer, ComObj** ppComObj = NULL)
  {
    return (pUnkOuter == NULL
	    ? ComImmediateObj<ComObj>::CreateInstance (pUnkOuter, riid, ppv, pInitializer, ppComObj)
	    : ComAggregateObj<ComObj>::CreateInstance (pUnkOuter, riid, ppv, pInitializer, ppComObj));
  }

};


// Class factory objects are supposed to be created statically with the only instance
// per module. So they never aggregate, never get created or destroyed dynamically,
// and the ordinary refernce counting semantics never applies to them.
template <class ComObjCreator>
class ComClassFactory : public IClassFactory, public ComObjRoot
{
public:

  ComClassFactory()
  {
    m_pUnkFTM = NULL;
  }

  ~ComClassFactory()
  {
    Delete();
  }

  void
  Delete()
  {
    if (m_pUnkFTM != NULL)
      {
	m_pUnkFTM->Release();
	m_pUnkFTM = NULL;
      }
  }

  // IUnknown members

  STDMETHODIMP
  QueryInterface(REFIID riid, void** ppv)
  {
    LOGCALL(("%s::QueryInterface(riid=%s)\n", typeid(*this).name(), StringFromGuid(riid)));

    if (ppv == NULL)
      return E_INVALIDARG;
    *ppv = NULL;

    if (riid == IID_IUnknown || riid == IID_IClassFactory)
      {
	AddRef();
	*ppv = static_cast<IClassFactory*>(this);
	return S_OK;
      }
    else if (riid == IID_IMarshal)
      {
	CriticalSection critical_section(&Module::m_GlobalSync);
	if (m_pUnkFTM == NULL)
	  CoCreateFreeThreadedMarshaler(static_cast<IClassFactory*>(this), &m_pUnkFTM);
	if (m_pUnkFTM != NULL)
	  return m_pUnkFTM->QueryInterface(riid, ppv);
      }
    return E_NOINTERFACE;
  }

  STDMETHODIMP_(ULONG)
  AddRef()
  {
    LOGCALL(("%s::AddRef(), %d\n", typeid(*this).name(), m_iRef + 1));

    ULONG ul = InternalAddRef();
    if (ul == 1)
      Module::Lock();
    return ul;
  }

  STDMETHODIMP_(ULONG)
  Release()
  {
    LOGCALL(("%s::Release(), %d\n", typeid(*this).name(), m_iRef - 1));

    ULONG ul = InternalRelease();
    if (ul == 0)
      {
	Delete();
	Module::Unlock();
      }
    return ul;
  }

  // IClassFactory members

  STDMETHODIMP
  CreateInstance(IUnknown* pUnkOuter, REFIID riid, void** ppv)
  {
    if (ppv == NULL)
      return E_INVALIDARG;
    *ppv = NULL;

    if (pUnkOuter != NULL && riid != IID_IUnknown)
      return DB_E_NOAGGREGATION;

    return ComObjCreator::CreateInstance<void>(pUnkOuter, riid, ppv, NULL, NULL);
  }

  STDMETHODIMP
  LockServer(BOOL fLock)
  {
    if (fLock)
      Module::Lock();
    else
      Module::Unlock();
    return S_OK;
  }

private:

  IUnknown* m_pUnkFTM;
};


#endif
