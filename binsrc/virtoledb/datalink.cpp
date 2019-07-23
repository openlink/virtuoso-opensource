/*  datalink.cpp
 *
 *  $Id$
 *
 *  Data Link property pages.
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
#include "datalink.h"
#include "resource.h"

////////////////////////////////////////////////////////////////////////
// PagePropertyAdapter

HRESULT
PagePropertyAdapter::InitValue(VARIANT& v)
{
  return S_OK;
}

////////////////////////////////////////////////////////////////////////
// BoolPagePropertyAdapter

HRESULT
BoolPagePropertyAdapter::LoadValue(CPropertyPage* pPage, const VARIANT& v)
{
  WPARAM check = (V_VT(&v) == VT_BOOL && V_BOOL(&v) == VARIANT_TRUE
		  ? BST_CHECKED
		  : BST_UNCHECKED);
  CheckDlgButton (pPage->GetWindowHandle (), GetControlId (), check);
  return S_OK;
}

HRESULT
BoolPagePropertyAdapter::SaveValue(CPropertyPage* pPage, VARIANT& v)
{
  LRESULT check = IsDlgButtonChecked(pPage->GetWindowHandle(), GetControlId());
  if (m_fSaveAlways || check == BST_CHECKED)
    {
      V_VT(&v) = VT_BOOL;
      V_BOOL(&v) = (check == BST_CHECKED ? VARIANT_TRUE : VARIANT_FALSE);
    }
 return S_OK;
}

////////////////////////////////////////////////////////////////////////
// CharPagePropertyAdapter

HRESULT
CharPagePropertyAdapter::LoadValue(CPropertyPage* pPage, const VARIANT& v)
{
  WCHAR* value = (V_VT(&v) == VT_BSTR && V_BSTR(&v) != NULL
		  ? V_BSTR(&v)
		  : L"");
  SetDlgItemTextW(pPage->GetWindowHandle(), GetControlId(), value);
  return S_OK;
}

HRESULT
CharPagePropertyAdapter::SaveValue(CPropertyPage* pPage, VARIANT& v)
{
  LRESULT length = SendDlgItemMessage(pPage->GetWindowHandle(), GetControlId(), WM_GETTEXTLENGTH, 0, 0);
  if (length > 0)
    {
      AutoRelease<wchar_t, SysStrFree> buffer(new wchar_t[length + 1]);
      if (buffer == NULL)
	return E_OUTOFMEMORY;

      GetDlgItemTextW(pPage->GetWindowHandle(), GetControlId(), buffer.Get(), length + 1);

      V_VT(&v) = VT_BSTR;
      V_BSTR(&v) = SysAllocString(buffer.Get());
      if (V_BSTR(&v) == NULL)
	return E_OUTOFMEMORY;
    }
  return S_OK;
}

////////////////////////////////////////////////////////////////////////
// PasswordPagePropertyAdapter

HRESULT
PasswordPagePropertyAdapter::LoadValue(CPropertyPage* pPage, const VARIANT& v)
{
  WPARAM check;
  if (V_VT(&v) != VT_BSTR || (V_BSTR(&v) != NULL && SysStringLen(V_BSTR(&v)) != 0) || m_fUnchecked)
    check = BST_UNCHECKED;
  else
    check = BST_CHECKED;
  CheckDlgButton (pPage->GetWindowHandle (), m_blankPasswordId, check);
  EnableWindow (GetDlgItem (pPage->GetWindowHandle (), GetControlId ()), check != BST_CHECKED);
  return CharPagePropertyAdapter::LoadValue(pPage, v);
}

HRESULT
PasswordPagePropertyAdapter::SaveValue(CPropertyPage* pPage, VARIANT& v)
{
  LRESULT check = IsDlgButtonChecked (pPage->GetWindowHandle(), m_blankPasswordId);
  if (check == BST_CHECKED)
    {
      V_VT(&v) = VT_BSTR;
      V_BSTR(&v) = SysAllocString(L"");
      if (V_BSTR(&v) == NULL)
	return E_OUTOFMEMORY;
      m_fUnchecked = false;
      return S_OK;
    }
  // Store unchecked status to work around the problem with VT_EMPTY not overriding empty VT_BSTR.
  m_fUnchecked = true;
  return CharPagePropertyAdapter::SaveValue(pPage, v);
}

////////////////////////////////////////////////////////////////////////
// CPropertyPage

CPropertyPage::CPropertyPage()
{
  LOGCALL(("CPropertyPage::CPropertyPage()\n"));

  m_hWnd = NULL;
  m_fIsDirty = false;
  m_pPropertyPageSite = NULL;
}

CPropertyPage::~CPropertyPage()
{
  LOGCALL(("CPropertyPage::~CPropertyPage()\n"));

  if (m_pPropertyPageSite != NULL)
    {
      m_pPropertyPageSite->Release();
      m_pPropertyPageSite = NULL;
    }
}

HRESULT
CPropertyPage::GetInterface(REFIID riid, IUnknown** ppUnknown)
{
  IUnknown* pUnknown = NULL;
  if (riid == IID_IPersist)
    pUnknown = static_cast<IPersist*>(this);
  else if (riid == IID_IPersistPropertyBag)
    pUnknown = static_cast<IPersistPropertyBag*>(this);
  else if (riid == IID_IPropertyPage)
    pUnknown = static_cast<IPropertyPage*>(this);
  if (pUnknown == NULL)
    return E_NOINTERFACE;

  *ppUnknown = pUnknown;
  return S_OK;
}

void
CPropertyPage::SetDirty(bool fIsDirty)
{
  LOGCALL(("CPropertyPage::SetDirty(fIsDirty = %d)\n", fIsDirty));

  if (m_fIsDirty != fIsDirty)
    {
      m_fIsDirty = fIsDirty;
      if (m_pPropertyPageSite != NULL)
	m_pPropertyPageSite->OnStatusChange(m_fIsDirty ? PROPPAGESTATUS_DIRTY : PROPPAGESTATUS_CLEAN);
    }
}

INT_PTR CALLBACK
CPropertyPage::DialogProc(HWND hwndDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
  //LOGCALL(("CPropertyPage::DialogProc(hwndDlg=%d, uMsg=%d, wParam=0x%x, lParam=0x%x)\n", hwndDlg, uMsg, wParam, lParam));

  switch (uMsg)
    {
    case WM_INITDIALOG:
      {
	CPropertyPage* pThis = (CPropertyPage*) lParam;
	SetWindowLongPtr(hwndDlg, GWLP_USERDATA, lParam);
	return 0;
      }

    case WM_STYLECHANGING:
      // For some obscure reason some top-level party -- either the Data Link
      // component itself or something else -- changes the style of the dialog.
      // This code prevents the removal of the WS_EX_CONTROLPARENT flag because
      // this hampers the TAB key navigation among the controls. Initially, I
      // thought of this as of a dirty kludge but then I found that ATL does
      // the same thing.
      if (wParam == GWL_EXSTYLE)
	{
	  STYLESTRUCT* pStyleStruct = (STYLESTRUCT*) lParam;
	  pStyleStruct->styleNew |= WS_EX_CONTROLPARENT;
	}
      return 0;

    case WM_COMMAND:
      {
	//Get the "this" pointer
	CPropertyPage* pThis = (CPropertyPage*) GetWindowLongPtr(hwndDlg, GWLP_USERDATA);
	return pThis->HandleCommand(hwndDlg, wParam, lParam);
      }
    }

  return 0;
}

HRESULT
CPropertyPage::InitProperties(IPropertyBag* pPropBag, IErrorLog* pErrorLog)
{
  const std::vector<PagePropertyAdapter*>& adapters = GetPropertyAdapters();
  if (adapters.size() == 0)
    return S_OK;

  for (size_t i = 0; i < adapters.size(); i++)
    {
      PagePropertyAdapter* adapter = adapters[i];

      VARIANT v;
      VariantInit(&v);
      if (pPropBag != NULL)
	{
	  HRESULT hr = pPropBag->Read(adapter->GetPropertyName(), &v, pErrorLog);
	  if (FAILED(hr))
	    return hr;
	}
      if (V_VT(&v) == VT_EMPTY)
	{
	  HRESULT hr = adapter->InitValue(v);
	  if (FAILED(hr))
	    return hr;
	}

      LOG(("%S: %s\n", adapter->GetPropertyName(), StringFromVariant(v)));
      adapter->LoadValue(this, v);
      adapter->SetDirty(false);
      VariantClear(&v);
    }

  return S_OK;
}

#ifdef DEBUG_STYLE
void
CPropertyPage::StyleBox(TCHAR* szCaption, HWND hWnd, HWND hWndOwner)
{
  if (hWndOwner == NULL)
    hWndOwner = hWnd;

  LONG style = GetWindowLong(hWnd, GWL_STYLE);
  LONG exstyle = GetWindowLong(hWnd, GWL_EXSTYLE);

  TCHAR buffer[256];
  _stprintf(buffer, TEXT("style = %8X\n exstyle = %8X\n"), style, exstyle);

  MessageBox(hWndOwner, buffer, szCaption, MB_OK);
}
#endif

////////////////////////////////////////////////////////////////////////
// IPersist members

STDMETHODIMP
CPropertyPage::GetClassID(
  CLSID *pClassID
)
{
  LOGCALL(("CPropertyPage::GetClassID()\n"));

  if (pClassID == NULL)
    return E_FAIL;

  REFCLSID rclsid = GetClassID();
  memcpy(pClassID, &rclsid, sizeof(CLSID));
  return S_OK;
}

////////////////////////////////////////////////////////////////////////
// IPersistPropertyBag members

STDMETHODIMP
CPropertyPage::InitNew()
{
  LOGCALL(("CPropertyPage::InitNew()\n"));

  return InitProperties(NULL, NULL);
}

STDMETHODIMP
CPropertyPage::Load(
  IPropertyBag* pPropBag,
  IErrorLog* pErrorLog
)
{
  LOGCALL(("CPropertyPage::Load()\n"));

  if (pPropBag == NULL)
    return E_POINTER;

  return InitProperties(pPropBag, pErrorLog);
}

STDMETHODIMP
CPropertyPage::Save(
  IPropertyBag* pPropBag,
  BOOL fClearDirty,
  BOOL fSaveAllProperties
)
{
  LOGCALL(("CPropertyPage::Save(fClearDirty = %d, fSaveAllProperties = %d)\n", fClearDirty, fSaveAllProperties));

  if (pPropBag == NULL)
    return E_POINTER;

  const std::vector<PagePropertyAdapter*>& adapters = GetPropertyAdapters();
  if (adapters.size() == 0)
    return S_OK;

  for (size_t i = 0; i < adapters.size(); i++)
    {
      PagePropertyAdapter* adapter = adapters[i];
      if (fSaveAllProperties || adapter->IsDirty())
	{
	  VARIANT v;
	  VariantInit(&v);
	  HRESULT hr = adapter->SaveValue(this, v);
	  if (FAILED(hr))
	    return hr;

	  LOG(("%S: %s\n", adapter->GetPropertyName(), StringFromVariant(v)));
	  hr = pPropBag->Write(adapter->GetPropertyName(), &v);
	  if (FAILED(hr))
	    {
	      VariantClear(&v);
	      return hr;
	    }
	  if (fClearDirty)
	    adapter->SetDirty(false);

	  VariantClear(&v);
	}
    }

  if (fClearDirty)
    SetDirty(false);
  return S_OK;
}

////////////////////////////////////////////////////////////////////////
// IPropertyPage members

STDMETHODIMP
CPropertyPage::Activate(
  HWND hWndParent,
  LPCRECT pRect,
  BOOL bModal
)
{
  LOGCALL(("CPropertyPage::Activate()\n"));

  if (pRect == NULL)
    return E_POINTER;
  if (m_hWnd != NULL)
    return E_UNEXPECTED;

  m_hWnd = CreateDialogParam(Module::GetInstanceHandle(), MAKEINTRESOURCE(GetDialogID()), hWndParent, DialogProc, (LPARAM) this);
  if (m_hWnd == NULL)
    return E_FAIL;

#ifdef DEBUG_STYLE
  StyleBox("CPropertyPage::Activate", m_hWnd, hWndParent);
#endif
  return Move(pRect);
}

STDMETHODIMP
CPropertyPage::Apply()
{
  LOGCALL(("CPropertyPage::Apply()\n"));

  return S_OK;
}

STDMETHODIMP
CPropertyPage::Deactivate()
{
  LOGCALL(("CPropertyPage::Deactivate()\n"));

  if (m_hWnd != NULL)
    {
      DestroyWindow(m_hWnd);
      m_hWnd = NULL;
    }

  return S_OK;
}

STDMETHODIMP
CPropertyPage::GetPageInfo(
  PROPPAGEINFO* pPageInfo
)
{
  LOGCALL(("CPropertyPage::GetPageInfo()\n"));

  if (pPageInfo == NULL)
    return E_POINTER;
  if (pPageInfo->cb != sizeof(PROPPAGEINFO))
    return E_POINTER;

  memset(pPageInfo, 0, sizeof(PROPPAGEINFO));
  return S_OK;
}

STDMETHODIMP
CPropertyPage::Help(
  LPCOLESTR pszHelpDir
)
{
  LOGCALL(("CPropertyPage::Help()\n"));

  return E_NOTIMPL;
}

STDMETHODIMP
CPropertyPage::IsPageDirty()
{
  LOGCALL(("CPropertyPage::IsPageDirty()\n"));

  return m_fIsDirty ? S_OK : S_FALSE;
}

STDMETHODIMP
CPropertyPage::Move(
  LPCRECT pRect
)
{
  LOGCALL(("CPropertyPage::Move()\n"));

  MoveWindow(m_hWnd, pRect->left, pRect->top, pRect->right - pRect->left, pRect->bottom - pRect->top, TRUE);

#ifdef DEBUG_STYLE
  StyleBox("CPropertyPage::Move", m_hWnd);
#endif
  return S_OK;
}

STDMETHODIMP
CPropertyPage::SetObjects(
  ULONG cObjects,
  IUnknown** ppUnk
)
{
  LOGCALL(("CPropertyPage::SetObjects()\n"));

  return E_NOTIMPL;
}

STDMETHODIMP
CPropertyPage::SetPageSite(
  IPropertyPageSite* pPageSite
)
{
  LOGCALL(("CPropertyPage::SetPageSite()\n"));

  if (pPageSite == NULL)
    {
      if (m_pPropertyPageSite != NULL)
	{
	  m_pPropertyPageSite->Release();
	  m_pPropertyPageSite = NULL;
	}
    }
  else
    {
      if (m_pPropertyPageSite != NULL)
	return E_UNEXPECTED;

      HRESULT hr = pPageSite->QueryInterface(IID_IPropertyPageSite, (void**) &m_pPropertyPageSite);
      if (FAILED(hr))
	return E_FAIL;
    }

  return S_OK;
}

STDMETHODIMP
CPropertyPage::Show(
  UINT nCmdShow
)
{
  LOGCALL(("CPropertyPage::Show()\n"));

  ShowWindow(m_hWnd, nCmdShow);

#ifdef DEBUG_STYLE
  StyleBox("CPropertyPage::Show", m_hWnd);
#endif
  return S_OK;
}

STDMETHODIMP
CPropertyPage::TranslateAccelerator(
  MSG* pMsg
)
{
  LOGCALL(("CPropertyPage::TranslateAccelerator()\n"));

  if (pMsg == NULL)
    return E_POINTER;

  if ((pMsg->message < WM_KEYFIRST || pMsg->message > WM_KEYLAST)
      && (pMsg->message < WM_MOUSEFIRST || pMsg->message > WM_MOUSELAST))
    return S_FALSE;

  return IsDialogMessage(m_hWnd, pMsg) ? S_OK : S_FALSE;
}

////////////////////////////////////////////////////////////////////////
// DBTest

class DBTest
{
public:

  DBTest()
  {
    m_henv = NULL;
    m_hdbc = NULL;
    m_hstmt = NULL;
    m_fConnected = false;
  }

  ~DBTest()
  {
    if (m_hstmt != NULL)
      SQLFreeHandle(SQL_HANDLE_STMT, m_hstmt);

    if (m_hdbc != NULL)
      {
	if (m_fConnected)
	  SQLDisconnect(m_hdbc);
	SQLFreeHandle(SQL_HANDLE_DBC, m_hdbc);
      }

    if (m_henv != NULL)
      SQLFreeHandle(SQL_HANDLE_ENV, m_henv);
  }

  void
  Message(HWND hWnd, TCHAR* title, UINT uType)
  {
    SQLTCHAR state[6], error[SQL_MAX_MESSAGE_LENGTH];
    SQLSMALLINT error_length;
    SQLError(m_henv, m_hdbc, m_hstmt, state, NULL, error, sizeof error, &error_length);
    MessageBox(hWnd, (TCHAR*) error, title, uType);
  }

  bool
  Connect(const std::wstring& connection_string)
  {
    LOGCALL(("DBTest::Connect(%ls)\n", connection_string.c_str()));

    SQLRETURN rc;

    rc = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &m_henv);
    if (rc != SQL_SUCCESS)
      return false;

    rc = SQLSetEnvAttr(m_henv, SQL_ATTR_ODBC_VERSION, (SQLPOINTER) SQL_OV_ODBC3, SQL_IS_INTEGER);
    if (rc != SQL_SUCCESS)
      return false;

    rc = SQLAllocHandle(SQL_HANDLE_DBC, m_henv, &m_hdbc);
    if (rc != SQL_SUCCESS)
      return false;

    rc = SQLDriverConnectW(m_hdbc, NULL, (SQLWCHAR*) connection_string.c_str(), SQL_NTS, NULL, 0, NULL, SQL_DRIVER_NOPROMPT);
    if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
      return false;

    m_fConnected = true;
    return true;
  }

  bool
  Tables()
  {
    SQLRETURN rc;

    assert(m_hdbc != NULL);
    assert(m_hstmt == NULL);

    rc = SQLAllocHandle(SQL_HANDLE_STMT, m_hdbc, &m_hstmt);
    if (rc != SQL_SUCCESS)
      return false;

    rc = SQLTables(m_hstmt, (SQLTCHAR*) TEXT("%"), SQL_NTS,
		   (SQLTCHAR*) TEXT(""), SQL_NTS,
		   (SQLTCHAR*) TEXT(""), SQL_NTS,
		   (SQLTCHAR*) TEXT(""), SQL_NTS);
    if (rc != SQL_SUCCESS)
      return false;

    return true;
  }

  bool
  GetCatalogName(SQLTCHAR* buffer, SQLLEN length)
  {
    SQLRETURN rc;

    assert(m_hdbc != NULL);
    assert(m_hstmt != NULL);

    rc = SQLFetch(m_hstmt);
    if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
      return false;

    rc = SQLGetData(m_hstmt, 1, SQL_C_TCHAR, buffer, length, &length);
    if (rc != SQL_SUCCESS && rc != SQL_SUCCESS_WITH_INFO)
      return false;

    return true;
  }

private:

  SQLHENV m_henv;
  SQLHDBC m_hdbc;
  SQLHSTMT m_hstmt;
  bool m_fConnected;
};

////////////////////////////////////////////////////////////////////////
// CConnectionPage

CConnectionPage::CConnectionPage()
  : m_hostname(IDC_HOSTNAME, L"Data Source"),
    m_username(IDC_USERNAME, L"User ID"),
    m_password(IDC_PASSWORD, IDC_BLANK_PASSWORD, L"Password"),
    m_persist_security_info(IDC_PERSIST_SECURITY_INFO, L"Persist Security Info"),
    m_encrypt_connection(IDC_ENCRYPT, L"Encrypt Connection"),
    m_show_system_tables(IDC_NO_SYSTEMTABLES, L"NoSysTables"),
    m_pkcs12_file(IDC_PKCS12FILE, L"PKCS #12 File"),
    m_database(IDC_DATABASE, L"Initial Catalog")
{
}

CConnectionPage::~CConnectionPage()
{
}

HRESULT
CConnectionPage::Initialize (void*)
{
  try {
    m_adapters.reserve(8);
    m_adapters.push_back(&m_hostname);
    m_adapters.push_back(&m_username);
    m_adapters.push_back(&m_password);
    m_adapters.push_back(&m_persist_security_info);
    m_adapters.push_back(&m_encrypt_connection);
    m_adapters.push_back(&m_pkcs12_file);
    m_adapters.push_back(&m_database);
    m_adapters.push_back(&m_show_system_tables);
  } catch (...) {
    return E_OUTOFMEMORY;
  }
  return S_OK;
}

STDMETHODIMP
CConnectionPage::SetPageSite(
  IPropertyPageSite* pPageSite
)
{
  LOGCALL(("CConnectionPage::SetPageSite()\n"));

  m_password.SetUnchecked (false);
  return CPropertyPage::SetPageSite (pPageSite);
}

REFCLSID
CConnectionPage::GetClassID()
{
  return CLSID_VIRTOLEDB_CONNECTION_PAGE;
}

int
CConnectionPage::GetDialogID()
{
  return IDD_CONNECTION_PAGE;
}

const std::vector<PagePropertyAdapter*>&
CConnectionPage::GetPropertyAdapters()
{
  return m_adapters;
}

BOOL
CConnectionPage::HandleCommand(HWND hWnd, WPARAM wParam, LPARAM lParam)
{
  //LOGCALL (("CConnectionPage::HandleCommand()\n"));
  //LOG (("HIWORD(wParam) = 0x%x, LOWORD(wParam) = 0x%x\n", HIWORD(wParam), LOWORD(wParam)));

  switch (HIWORD(wParam))
    {
    case EN_CHANGE:
      switch (LOWORD(wParam))
	{
	case IDC_HOSTNAME:
	  SetDirty();
	  m_hostname.SetDirty();
	  break;

	case IDC_USERNAME:
	  SetDirty();
	  m_username.SetDirty();
	  break;

	case IDC_PASSWORD:
	  SetDirty();
	  m_password.SetDirty();
	  break;

	case IDC_PKCS12FILE:
	  SetDirty();
	  m_pkcs12_file.SetDirty();
	  break;

	case IDC_DATABASE:
	  SetDirty();
	  m_database.SetDirty();
	  break;
	}
      break;

    case CBN_DROPDOWN:
      switch (LOWORD(wParam))
	{
	case IDC_DATABASE:
	  SetDatabaseList();
	  break;
	}
      break;

    case CBN_EDITCHANGE:
    case CBN_SELCHANGE:
      switch (LOWORD(wParam))
	{
	case IDC_DATABASE:
	  SetDirty();
	  m_database.SetDirty();
	  break;
	}

    case BN_CLICKED:
      switch (LOWORD(wParam))
	{
	case IDC_BLANK_PASSWORD:
	  {
	    int checkState = IsDlgButtonChecked(GetWindowHandle(), IDC_BLANK_PASSWORD);
	    EnableWindow(GetDlgItem(GetWindowHandle(), IDC_PASSWORD), checkState != BST_CHECKED);

	    SetDirty();
	    m_password.SetDirty();
	  }
	  break;

	case IDC_PERSIST_SECURITY_INFO:
	  SetDirty();
	  m_persist_security_info.SetDirty();
	  break;

	case IDC_ENCRYPT:
	  SetDirty();
	  m_encrypt_connection.SetDirty();
	  break;

	case IDC_NO_SYSTEMTABLES:
	  SetDirty();
	  m_show_system_tables.SetDirty();
	  break;

	case IDC_BROWSE:
	  {
	    //Obtain the current value for the default
	    TCHAR szPath[1024] = {0};
	    GetDlgItemText(GetWindowHandle(), IDC_PKCS12FILE, szPath, sizeof szPath);

	    OPENFILENAME ofn;
	    ZeroMemory (&ofn, sizeof ofn);
	    ofn.lStructSize = sizeof ofn;
	    ofn.hwndOwner = GetWindowHandle();
	    ofn.lpstrFile = szPath;
	    ofn.nMaxFile = sizeof szPath;
	    ofn.lpstrFilter = _T("All\0*.*\0PKCS#12\0*.p12\0");
	    ofn.nFilterIndex = 1;
	    ofn.lpstrFileTitle = NULL;
	    ofn.nMaxFileTitle = 0;
	    ofn.lpstrInitialDir = NULL;
	    ofn.lpstrTitle = _T("Select PKCS#12 certificate");
	    ofn.Flags = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_HIDEREADONLY | OFN_NOCHANGEDIR;

	    if (GetOpenFileName(&ofn) == TRUE)
	      {
		SetDlgItemText(GetWindowHandle(), IDC_PKCS12FILE, szPath);
		SetDirty();
		m_pkcs12_file.SetDirty();
	      }
	  }
	  break;

	case IDC_TEST_CONNECTION:
	  TestConnection();
	  break;
	}
      break;

#if 0
    default:
      //Filter out any Control Notification codes
      if (HIWORD(wParam) > 1)
	break;

      switch (LOWORD(wParam))
	{
	}
      break;
#endif
    }
  return FALSE;
}

void
CConnectionPage::TestConnection()
{
  LOGCALL (("CConnectionPage::TestConnection()\n"));

  std::wstring connection_string;
  try {
    connection_string = GetConnectionString();
  } catch (...) {
    MessageBox(GetWindowHandle(), TEXT("Out of memory."), TEXT("OpenLink Connection Page"), MB_OK | MB_ICONSTOP);
    return;
  }

  DBTest db;
  if (db.Connect(connection_string))
    MessageBox(GetWindowHandle(), TEXT("Test Connection succeeded."), TEXT("OpenLink Connection Page"), MB_OK | MB_ICONINFORMATION);
  else
    db.Message(GetWindowHandle(), TEXT("OpenLink Connection Page Error"), MB_OK | MB_ICONSTOP);
}

void
CConnectionPage::SetDatabaseList()
{
  LOGCALL (("CConnectionPage::SetDatabaseList()\n"));

  std::wstring connection_string;
  try {
    connection_string = GetConnectionString();
  } catch (...) {
    MessageBox(GetWindowHandle(), TEXT("Out of memory."), TEXT("OpenLink Connection Page"), MB_OK | MB_ICONSTOP);
    return;
  }

  SendDlgItemMessage(GetWindowHandle(), IDC_DATABASE, CB_RESETCONTENT, 0, 0);

  DBTest db;
  if (db.Connect(connection_string) && db.Tables())
    {
      TCHAR name[1024];
      while (db.GetCatalogName((SQLTCHAR*) name, sizeof name))
	{
	  SendDlgItemMessage(GetWindowHandle(), IDC_DATABASE, CB_ADDSTRING, 0, (LPARAM) name);
	}
    }
  else
    {
      db.Message(GetWindowHandle(), TEXT("OpenLink Connection Page Error"), MB_OK | MB_ICONSTOP);
    }
}

std::wstring
CConnectionPage::GetConnectionString()
{
  std::wstring connection_string = L"DRIVER={OpenLink Virtuoso Driver};";

  int length;
  wchar_t buffer[1024];

  length = GetDlgItemTextW(GetWindowHandle(), IDC_HOSTNAME, buffer, sizeof buffer);
  if (length > 0)
    connection_string.append(L"HOST=").append(buffer).append(L";");

  length = GetDlgItemTextW(GetWindowHandle(), IDC_USERNAME, buffer, sizeof buffer);
  if (length > 0)
    connection_string.append(L"UID=").append(buffer).append(L";");

  if (BST_CHECKED == IsDlgButtonChecked(GetWindowHandle(), IDC_BLANK_PASSWORD))
    connection_string.append(L"PWD=;");
  else
    {
      length = GetDlgItemTextW(GetWindowHandle(), IDC_PASSWORD, buffer, sizeof buffer);
      if (length > 0)
	connection_string.append(L"PWD=").append(buffer).append(L";");
    }

  length = GetDlgItemTextW(GetWindowHandle(), IDC_DATABASE, buffer, sizeof buffer);
  if (length > 0)
    connection_string.append(L"DATABASE=").append(buffer).append(L";");

  length = GetDlgItemTextW(GetWindowHandle(), IDC_PKCS12FILE, buffer, sizeof buffer);
  if (length > 0)
    connection_string.append(L"ENCRYPT=").append(buffer).append(L";");
  else if (BST_CHECKED == IsDlgButtonChecked(GetWindowHandle(), IDC_ENCRYPT))
    connection_string.append(L"ENCRYPT=1;");

  if (BST_CHECKED == IsDlgButtonChecked (GetWindowHandle (), IDC_NO_SYSTEMTABLES))
    connection_string.append(L"NoSystemTables=1;");

  return connection_string;
}

////////////////////////////////////////////////////////////////////////
// CAdvancedPage

#if ADVANCED_PAGE

CAdvancedPage::CAdvancedPage()
  : CPropertyPage (CLSID_VIRTOLEDB_ADVANCED_PAGE, IDD_ADVANCED_PAGE)
{
}

CAdvancedPage::~CAdvancedPage()
{
}

BOOL
CAdvancedPage::HandleCommand(HWND hWnd, WPARAM wParam, LPARAM lParam)
{
  return FALSE;
}

#endif
