/*  util.h
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2018 OpenLink Software
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

#ifndef UTIL_H
#define UTIL_H


inline bool
DBIDEqual(const DBID* pdbid1, const DBID* pdbid2)
{
  if (pdbid1 == pdbid2)
    return true;
  if (pdbid1 == NULL || pdbid2 == NULL)
    return false;
  if (pdbid1->eKind != pdbid2->eKind
      && ((pdbid1->eKind != DBKIND_GUID_NAME && pdbid1->eKind != DBKIND_PGUID_NAME)
	  || (pdbid2->eKind != DBKIND_GUID_NAME && pdbid2->eKind != DBKIND_PGUID_NAME))
      && ((pdbid1->eKind != DBKIND_GUID_PROPID && pdbid1->eKind != DBKIND_PGUID_PROPID)
	  || (pdbid2->eKind != DBKIND_GUID_PROPID && pdbid2->eKind != DBKIND_PGUID_PROPID)))
    return false;
  if (pdbid1->eKind == DBKIND_GUID
      || pdbid1->eKind == DBKIND_GUID_NAME || pdbid1->eKind == DBKIND_PGUID_NAME
      || pdbid1->eKind == DBKIND_GUID_PROPID || pdbid1->eKind == DBKIND_PGUID_PROPID)
    {
      if ((pdbid1->eKind == DBKIND_PGUID_NAME || pdbid1->eKind == DBKIND_PGUID_PROPID ? *pdbid1->uGuid.pguid : pdbid1->uGuid.guid)
	  !=
	  (pdbid2->eKind == DBKIND_PGUID_NAME || pdbid2->eKind == DBKIND_PGUID_PROPID ? *pdbid2->uGuid.pguid : pdbid2->uGuid.guid))
	return false;
    }
  if (pdbid1->eKind == DBKIND_NAME || pdbid1->eKind == DBKIND_GUID_NAME || pdbid1->eKind == DBKIND_PGUID_NAME)
    {
      if (pdbid1->uName.pwszName == pdbid2->uName.pwszName)
	return true;
      if (pdbid1->uName.pwszName == NULL || pdbid2->uName.pwszName == NULL)
	return false;
      return (wcscmp (pdbid1->uName.pwszName, pdbid2->uName.pwszName) == 0);
    }
  if (pdbid1->eKind == DBKIND_PROPID || pdbid1->eKind == DBKIND_GUID_PROPID || pdbid1->eKind == DBKIND_PGUID_PROPID)
    return (pdbid1->uName.ulPropid == pdbid2->uName.ulPropid);
  return true;
}


template<class T>
class DeletePlain
{
public:

  static void
  Release(T* p)
  {
    delete p;
  }
};


template<class T>
class DeleteArray
{
public:

  static void
  Release(T* p)
  {
    delete [] p;
  }
};


class ComMemFree
{
public:

  static void
  Release(void* p)
  {
    CoTaskMemFree(p);
  }
};


class SysStrFree
{
public:

  static void
  Release(BSTR p)
  {
    SysFreeString(p);
  }
};


template<class T, class ReleaseObj = DeletePlain<T>/**/>
class AutoRelease
{
public:

  AutoRelease()
  {
    m_p = NULL;
    m_owns = false;
  }

  explicit
  AutoRelease(T* p)
  {
    m_p = p;
    m_owns = (m_p != NULL);
  }

  ~AutoRelease()
  {
    if (m_owns)
      ReleaseObj::Release(m_p);
  }

  void
  Set(T* p)
  {
    if (p != m_p)
      {
	if (m_owns)
	  ReleaseObj::Release(m_p);
	m_p = p;
      }
    m_owns = (m_p != NULL);
  }

  T*
  Get() const
  {
    return m_p;
  }

  T*
  GiveUp()
  {
    m_owns = false;
    return m_p;
  }

  // This is mostly for comparison with the NULL pointer.
  bool
  operator==(void* p) const
  {
    return m_p == p;
  }

  T*
  operator->() const
  {
    return Get();
  }

  T&
  operator*() const
  {
    return *Get();
  }

  T*
  operator+(size_t n) const
  {
    return Get() + n;
  }

  T&
  operator[](size_t n) const
  {
    return Get()[n];
  }

private:

  // Disallow copying.
  AutoRelease(const AutoRelease<T, ReleaseObj>&);
  AutoRelease<T, ReleaseObj>& operator=(const AutoRelease<T, ReleaseObj>&);

  T* m_p;
  bool m_owns;
};


template <class T>
class SafeInterface : public T
{
private:

  STDMETHOD_(ULONG, AddRef)() = 0;
  STDMETHOD_(ULONG, Release)() = 0;
};

template <class T>
class AutoInterface
{
public:

  AutoInterface()
  {
    m_p = NULL;
  }

  AutoInterface(T* p, bool fAddRef = true)
  {
    m_p = p;
    if (m_p != NULL && fAddRef)
      m_p->AddRef();
  }

  AutoInterface(const AutoInterface<T>& x)
  {
    m_p = x.m_p;
    if (m_p != NULL)
      m_p->AddRef();
  }

  ~AutoInterface()
  {
    if (m_p != NULL)
      m_p->Release();
  }

  void
  Release()
  {
    if (m_p != NULL)
      {
	m_p->Release();
	m_p = NULL;
      }
  }

  void
  Set(T* p)
  {
    if (p != NULL)
      p->AddRef();
    if (m_p != NULL)
      m_p->Release();
    m_p = p;
  }

  T*
  Get() const
  {
    return m_p;
  }

  T*
  GiveUp()
  {
    T* p = m_p;
    m_p = NULL;
    return p;
  }
  
  // This is mostly for comparison with the NULL pointer.
  bool
  operator==(T* p) const
  {
    return m_p == p;
  }

  // This is mostly for comparison with the NULL pointer.
  bool
  operator!=(T* p) const
  {
    return m_p != p;
  }

  SafeInterface<T>*
  operator->() const
  {
    return (SafeInterface<T>*) Get();
  }

/*
  template<class ComObj>
  HRESULT
  ImmediateInstance(REFIID riid, ComObj** ppComObj)
  {
    assert(m_p == NULL);
    return ComImmediateObj<ComObj>::CreateInstance(NULL, riid, (void**) &m_p, ppComObj);
  }

  template<class ComObj>
  HRESULT
  AggregateInstance(IUnknown* pUnkOuter, REFIID riid, ComObj** ppComObj)
  {
    assert(m_p == NULL);
    return ComAggregateObj<ComObj>::CreateInstance(pUnkOuter, riid, (void**) &m_p, ppComObj);
  }
*/

  HRESULT
  CreateInstance(REFCLSID rclsid, IUnknown* pUnkOuter, REFIID riid)
  {
    assert(m_p == NULL);
    return CoCreateInstance(rclsid, pUnkOuter, CLSCTX_INPROC_SERVER, riid, (void**) &m_p);
  }

  HRESULT
  CreateInstance(IClassFactory* pClassFactory, IUnknown* pUnkOuter, REFIID riid)
  {
    assert(m_p == NULL);
    assert(pClassFactory != NULL);
    return pClassFactory->CreateInstance(pUnkOuter, riid, (void**) &m_p);
  }

  HRESULT
  QueryInterface(IUnknown* pUnknown, REFIID riid)
  {
    assert(m_p == NULL);
    assert(pUnknown != NULL);
    return pUnknown->QueryInterface(riid, (void**) &m_p);
  }

private:

  T* m_p;
};


typedef std::basic_string<OLECHAR> ostring;


HRESULT olestr2string(const OLECHAR* olestr, std::string& string);
HRESULT string2bstr(const std::string& string, BSTR* pbstr);

#endif
