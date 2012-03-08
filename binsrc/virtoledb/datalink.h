/*  datalink.h
 *
 *  $Id$
 *
 *  Data Link property pages.
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

#ifndef DATALINK_H
#define DATALINK_H

#include "baseobj.h"


class CPropertyPage;
class CConnectionPage;
struct PageProperty;

class PagePropertyAdapter
{
public:

  PagePropertyAdapter(int id, const wchar_t* szName)
  {
    m_id = id;
    m_szName = szName;
    m_fIsDirty = false;
  }

  int
  GetControlId()
  {
    return m_id;
  }

  const wchar_t*
  GetPropertyName()
  {
    return m_szName;
  }

  bool
  IsDirty()
  {
    return m_fIsDirty;
  }

  void
  SetDirty(bool fIsDirty = true)
  {
    m_fIsDirty = fIsDirty;
  }

  virtual HRESULT InitValue(VARIANT& v);
  virtual HRESULT LoadValue(CPropertyPage* pPage, const VARIANT& v) = 0;
  virtual HRESULT SaveValue(CPropertyPage* pPage, VARIANT& v) = 0;

private:

  int m_id; // dialog control id
  const wchar_t* m_szName; // property name (corresponds to the DBPROPINFO's pwszDescription field)
  bool m_fIsDirty;
};


class BoolPagePropertyAdapter : public PagePropertyAdapter
{
public:

  BoolPagePropertyAdapter(int id, const wchar_t* szName, bool fSaveAlways = false)
    : PagePropertyAdapter(id, szName)
  {
    m_fSaveAlways = fSaveAlways;
  }

  virtual HRESULT LoadValue(CPropertyPage* pPage, const VARIANT& v);
  virtual HRESULT SaveValue(CPropertyPage* pPage, VARIANT& v);

private:

  bool m_fSaveAlways;
};


class CharPagePropertyAdapter : public PagePropertyAdapter
{
public:

  CharPagePropertyAdapter(int id, const wchar_t* szName)
    : PagePropertyAdapter(id, szName)
  {
  }

  virtual HRESULT LoadValue(CPropertyPage* pPage, const VARIANT& v);
  virtual HRESULT SaveValue(CPropertyPage* pPage, VARIANT& v);
};


class PasswordPagePropertyAdapter : public CharPagePropertyAdapter
{
public:

  PasswordPagePropertyAdapter(int passwordId, int blankPasswordId, const wchar_t* szName)
    : CharPagePropertyAdapter(passwordId, szName)
  {
    m_fUnchecked = false;
    m_blankPasswordId = blankPasswordId;
  }

  void
  SetUnchecked (bool fUnchecked)
  {
    m_fUnchecked = fUnchecked;
  }

  virtual HRESULT LoadValue(CPropertyPage* pPage, const VARIANT& v);
  virtual HRESULT SaveValue(CPropertyPage* pPage, VARIANT& v);

private:

  bool m_fUnchecked;
  int m_blankPasswordId;
};


#if 0
class DatabasePagePropertyAdapter : public CharPagePropertyAdapter
{
public:

};
#endif


class NOVTABLE CPropertyPage :
  public IPersistPropertyBag,
  public IPropertyPage,
  public ComObjBase
{
public:

  CPropertyPage();
  ~CPropertyPage();

  HWND
  GetWindowHandle()
  {
    return m_hWnd;
  }

  void SetDirty(bool fIsDirty = true);

  // ComObjBase members
  HRESULT GetInterface(REFIID riid, IUnknown** ppUnknown);

  // IPersist members

  STDMETHODIMP GetClassID(
    CLSID *pClassID
  );

  // IPersistPropertyBag members

  STDMETHODIMP InitNew();

  STDMETHODIMP Load(
    IPropertyBag* pPropBag,
    IErrorLog* pErrorLog
  );

  STDMETHODIMP Save(
    IPropertyBag* pPropBag,
    BOOL fClearDirty,
    BOOL fSaveAllProperties
  );

  // IPropertyPage members

  STDMETHODIMP Activate(
    HWND hWndParent,
    LPCRECT pRect,
    BOOL bModal
  );

  STDMETHODIMP Apply();

  STDMETHODIMP Deactivate();

  STDMETHODIMP GetPageInfo(
    PROPPAGEINFO* pPageInfo
  );

  STDMETHODIMP Help(
    LPCOLESTR pszHelpDir
  );

  STDMETHODIMP IsPageDirty();

  STDMETHODIMP Move(
    LPCRECT pRect
  );

  STDMETHODIMP SetObjects(
    ULONG cObjects,
    IUnknown** ppUnk
  );

  STDMETHODIMP SetPageSite(
    IPropertyPageSite* pPageSite
  );

  STDMETHODIMP Show(
    UINT nCmdShow
  );

  STDMETHODIMP CPropertyPage::TranslateAccelerator(
    MSG* pMsg
  );

protected:

#ifdef DEBUG_STYLE
  void StyleBox(TCHAR* szCaption, HWND hWnd, HWND hWndOwner = NULL);
#endif

  virtual REFCLSID GetClassID() = 0;
  virtual int GetDialogID() = 0;
  virtual const std::vector<PagePropertyAdapter*>& GetPropertyAdapters() = 0;
  virtual BOOL HandleCommand(HWND hWnd, WPARAM wParam, LPARAM lParam) = 0;

private:

  static INT_PTR CALLBACK DialogProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam);

  HRESULT InitProperties(IPropertyBag* pPropBag, IErrorLog* pErrorLog);

  HWND m_hWnd;
  bool m_fIsDirty;
  IPropertyPageSite* m_pPropertyPageSite;
};


class NOVTABLE CConnectionPage : public CPropertyPage
{
public:

  CConnectionPage();
  ~CConnectionPage();

  HRESULT Initialize (void*);

  STDMETHODIMP SetPageSite(
    IPropertyPageSite* pPageSite
  );

protected:

  virtual REFCLSID GetClassID();
  virtual int GetDialogID();
  virtual const std::vector<PagePropertyAdapter*>& GetPropertyAdapters();
  virtual BOOL HandleCommand(HWND hWnd, WPARAM wParam, LPARAM lParam);

private:

  void TestConnection();
  void SetDatabaseList();
  std::wstring GetConnectionString();

  CharPagePropertyAdapter m_hostname;
  CharPagePropertyAdapter m_username;
  PasswordPagePropertyAdapter m_password;
  BoolPagePropertyAdapter m_persist_security_info;
  BoolPagePropertyAdapter m_encrypt_connection;
  BoolPagePropertyAdapter m_show_system_tables;
  CharPagePropertyAdapter m_pkcs12_file;
  CharPagePropertyAdapter m_database;
  std::vector<PagePropertyAdapter*> m_adapters;
};


#if ADVANCED_PAGE

class NOVTABLE CAdvancedPage : public CPropertyPage
{
public:

  CAdvancedPage();
  ~CAdvancedPage();

protected:

  virtual BOOL HandleCommand(HWND hWnd, WPARAM wParam, LPARAM lParam);
};

#endif

#endif
