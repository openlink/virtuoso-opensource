/*  dllmodule.cpp
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2017 OpenLink Software
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
#include "dllmodule.h"
#include "datasource.h"
#include "datalink.h"
#include "error.h"

#if DEBUG
# include <crtdbg.h>
#endif

#ifdef VIRTOLEDB_CLI
extern "C" void SetOdbcInstanceHandle(HINSTANCE hModule);
#endif

/**********************************************************************/
/* DLL entry points.                                                  */

BOOL APIENTRY
DllMain(HINSTANCE hModule, DWORD dwReason, LPVOID lpReserved)
{
#ifdef VIRTOLEDB_CLI
  SetOdbcInstanceHandle(hModule);
#endif

  BOOL rv;
  if (dwReason == DLL_PROCESS_ATTACH)
    {
      LOGCALL(("DllMain(DLL_PROCESS_ATTACH)\n"));
      rv = Module::Attach(hModule);
      DisableThreadLibraryCalls(hModule);
    }
  else if (dwReason == DLL_PROCESS_DETACH)
    {
      LOGCALL(("DllMain(DLL_PROCESS_DETACH)\n"));
      rv = Module::Detach();
    }
  return rv;
}

STDAPI
DllGetClassObject(REFCLSID rclsid, REFIID riid, void** ppv)
{
  LOGCALL(("DllGetClassObject(rclsid=%s, riid=%s)\n", STRINGFROMGUID(rclsid), STRINGFROMGUID(riid)));
  return Module::GetClassObject (rclsid, riid, ppv);
}

STDAPI
DllCanUnloadNow()
{
  LOGCALL(("DllCanUnloadNow()\n"));
  return Module::CanUnloadNow() ? S_OK : S_FALSE;
}

STDAPI
DllRegisterServer()
{
  return Module::Register();
}

STDAPI
DllUnregisterServer()
{
  return Module::Unregister();
}

/**********************************************************************/
/* Module                                                             */

struct RegInfo
{
  TCHAR* reg_key;
  TCHAR* value_name;
  int type;
  TCHAR* value;
};

// {F89A5A2C-EBC0-4d12-A12D-D207EFA7A621}
//DEFINE_GUID(CLSID_VIRTOLEDB_0,
//    0xf89a5a2c, 0xebc0, 0x4d12, 0xa1, 0x2d, 0xd2, 0x7, 0xef, 0xa7, 0xa6, 0x21);

// {125E8E16-4D1B-42a3-AEE3-46291DF459A2}
//DEFINE_GUID(CLSID_VIRTOLEDB_ERROR_0, 
//    0x125e8e16, 0x4d1b, 0x42a3, 0xae, 0xe3, 0x46, 0x29, 0x1d, 0xf4, 0x59, 0xa2);

#define VIRTOLEDB_0_PROGID TEXT("VIRTOLEDB.0")
#define VIRTOLEDB_0_CLSID TEXT("{F89A5A2C-EBC0-4d12-A12D-D207EFA7A621}")

#define VIRTOLEDB_0_ERROR_PROGID TEXT("VIRTOLEDB ErrorLookup.0")
#define VIRTOLEDB_0_ERROR_CLSID TEXT("{125E8E16-4D1B-42a3-AEE3-46291DF459A2}")

#define VIRTOLEDB_PROGID TEXT("VIRTOLEDB.1")
#define VIRTOLEDB_VI_PROGID TEXT("VIRTOLEDB")
#define VIRTOLEDB_CLSID TEXT("{754b2f25-3297-44a4-bd04-55eaf8cc5b18}")
#define VIRTOLEDB_DESCRIPTION TEXT("OpenLink OLE DB Provider for Virtuoso")

#define VIRTOLEDB_ERROR_PROGID TEXT("VIRTOLEDB ErrorLookup.1")
#define VIRTOLEDB_ERROR_VI_PROGID TEXT("VIRTOLEDB ErrorLookup")
#define VIRTOLEDB_ERROR_DISPLAY_NAME TEXT("VIRTOLEDB Error Lookup")
#define VIRTOLEDB_ERROR_CLSID TEXT("{452f0f97-f69f-4cd9-94de-bdf3ff49e3e4}")
#define VIRTOLEDB_ERROR_DESCRIPTION TEXT("OpenLink OLE DB Error Lookup for Virtuoso")

#define VIRTOLEDB_CPAGE_PROGID TEXT("VIRTOLEDB Connection Page")
#define VIRTOLEDB_CPAGE_VI_PROGID TEXT("VIRTOLEDB Connection Page")
#define VIRTOLEDB_CPAGE_CLSID TEXT("{7bf2f14e-435d-4201-bc4d-09c9db2a93c7}")
#define VIRTOLEDB_CPAGE_DESCRIPTION TEXT("OpenLink Data Link Connection Page for Virtuoso")

#define VIRTOLEDB_APAGE_PROGID TEXT("VIRTOLEDB Advanced Page")
#define VIRTOLEDB_APAGE_VI_PROGID TEXT("VIRTOLEDB Advanced Page")
#define VIRTOLEDB_APAGE_CLSID TEXT("{9d701381-30a8-44f6-bcfb-987e8e3fc0f1}")
#define VIRTOLEDB_APAGE_DESCRIPTION TEXT("OpenLink Data Link Advanced Page for Virtuoso")

static const RegInfo obsolete_reg_info[] =
{
  // Provider Registry Entries
  { VIRTOLEDB_0_PROGID, NULL, REG_SZ, NULL },
  { VIRTOLEDB_0_PROGID TEXT("\\Clsid"), NULL, REG_SZ, NULL },
  { TEXT("CLSID\\") VIRTOLEDB_0_CLSID, NULL, REG_SZ, NULL },
  { TEXT("CLSID\\") VIRTOLEDB_0_CLSID TEXT("\\ExtendedErrors"), NULL, REG_SZ, NULL },
  { TEXT("CLSID\\") VIRTOLEDB_0_CLSID TEXT("\\ExtendedErrors\\") VIRTOLEDB_ERROR_CLSID, NULL, REG_SZ, NULL },
  { TEXT("CLSID\\") VIRTOLEDB_0_CLSID TEXT("\\InprocServer32"), NULL, REG_SZ, NULL },
  { TEXT("CLSID\\") VIRTOLEDB_0_CLSID TEXT("\\OLE DB Provider"), NULL, REG_SZ, NULL },
  { TEXT("CLSID\\") VIRTOLEDB_0_CLSID TEXT("\\ProgID"), NULL, REG_SZ, NULL },
  { TEXT("CLSID\\") VIRTOLEDB_0_CLSID TEXT("\\VersionIndependentProgID"), NULL, REG_SZ, NULL },

  // Error Lookup Service Registry Entries
  { VIRTOLEDB_0_ERROR_PROGID, NULL, REG_SZ, NULL },
  { VIRTOLEDB_0_ERROR_PROGID TEXT("\\Clsid"), NULL, REG_SZ, NULL },
  { TEXT("CLSID\\") VIRTOLEDB_0_ERROR_CLSID, NULL, REG_SZ, NULL },
  { TEXT("CLSID\\") VIRTOLEDB_0_ERROR_CLSID TEXT("\\InprocServer32"), NULL, REG_SZ, TEXT("%s") },
  { TEXT("CLSID\\") VIRTOLEDB_0_ERROR_CLSID TEXT("\\ProgId"), NULL, REG_SZ, NULL },
  { TEXT("CLSID\\") VIRTOLEDB_0_ERROR_CLSID TEXT("\\VersionIndependentProgId"), NULL, REG_SZ, NULL },
};

#define OBSOLETE_REG_INFO_SIZE (sizeof obsolete_reg_info / sizeof obsolete_reg_info[0])

static const RegInfo reg_info[] =
{
  // Provider Registry Entries
  { VIRTOLEDB_VI_PROGID, NULL, REG_SZ, VIRTOLEDB_DESCRIPTION },
  { VIRTOLEDB_VI_PROGID TEXT("\\Clsid"), NULL, REG_SZ, VIRTOLEDB_CLSID },
  { VIRTOLEDB_PROGID, NULL, REG_SZ, VIRTOLEDB_DESCRIPTION },
  { VIRTOLEDB_PROGID TEXT("\\Clsid"), NULL, REG_SZ, VIRTOLEDB_CLSID },
  { TEXT("CLSID\\") VIRTOLEDB_CLSID, NULL, REG_SZ, VIRTOLEDB_VI_PROGID },
  { TEXT("CLSID\\") VIRTOLEDB_CLSID, TEXT("OLEDB_SERVICES"), REG_DWORD, TEXT("-1") },
  { TEXT("CLSID\\") VIRTOLEDB_CLSID TEXT("\\ExtendedErrors"), NULL, REG_SZ, TEXT("Extended Error Service") },
  { TEXT("CLSID\\") VIRTOLEDB_CLSID TEXT("\\ExtendedErrors\\") VIRTOLEDB_ERROR_CLSID, NULL, REG_SZ, VIRTOLEDB_ERROR_DISPLAY_NAME },
  { TEXT("CLSID\\") VIRTOLEDB_CLSID TEXT("\\InprocServer32"), NULL, REG_SZ, TEXT("%s") },
  { TEXT("CLSID\\") VIRTOLEDB_CLSID TEXT("\\InprocServer32"), TEXT("ThreadingModel"), REG_SZ, TEXT("Both") },
  { TEXT("CLSID\\") VIRTOLEDB_CLSID TEXT("\\OLE DB Provider"), NULL, REG_SZ, VIRTOLEDB_DESCRIPTION },
  { TEXT("CLSID\\") VIRTOLEDB_CLSID TEXT("\\ProgID"), NULL, REG_SZ, VIRTOLEDB_PROGID },
  { TEXT("CLSID\\") VIRTOLEDB_CLSID TEXT("\\VersionIndependentProgID"), NULL, REG_SZ, VIRTOLEDB_VI_PROGID },

  // Error Lookup Service Registry Entries
  { VIRTOLEDB_ERROR_VI_PROGID, NULL, REG_SZ, VIRTOLEDB_ERROR_DESCRIPTION },
  { VIRTOLEDB_ERROR_VI_PROGID TEXT("\\Clsid"), NULL, REG_SZ, VIRTOLEDB_ERROR_CLSID },
  { VIRTOLEDB_ERROR_PROGID, NULL, REG_SZ, VIRTOLEDB_ERROR_DESCRIPTION },
  { VIRTOLEDB_ERROR_PROGID TEXT("\\Clsid"), NULL, REG_SZ, VIRTOLEDB_ERROR_CLSID },
  { TEXT("CLSID\\") VIRTOLEDB_ERROR_CLSID, NULL, REG_SZ, VIRTOLEDB_ERROR_DISPLAY_NAME },
  { TEXT("CLSID\\") VIRTOLEDB_ERROR_CLSID TEXT("\\InprocServer32"), NULL, REG_SZ, TEXT("%s") },
  { TEXT("CLSID\\") VIRTOLEDB_ERROR_CLSID TEXT("\\InprocServer32"), TEXT("ThreadingModel"), REG_SZ, TEXT("Both") },
  { TEXT("CLSID\\") VIRTOLEDB_ERROR_CLSID TEXT("\\ProgId"), NULL, REG_SZ, VIRTOLEDB_ERROR_PROGID },
  { TEXT("CLSID\\") VIRTOLEDB_ERROR_CLSID TEXT("\\VersionIndependentProgId"), NULL, REG_SZ, VIRTOLEDB_ERROR_VI_PROGID },

  // Data Link Connection Page Registry Entries
  { VIRTOLEDB_CPAGE_VI_PROGID, NULL, REG_SZ, VIRTOLEDB_CPAGE_DESCRIPTION },
  { VIRTOLEDB_CPAGE_VI_PROGID TEXT("\\Clsid"), NULL, REG_SZ, VIRTOLEDB_CPAGE_CLSID },
  //{ VIRTOLEDB_CPAGE_PROGID, NULL, REG_SZ, VIRTOLEDB_CPAGE_DESCRIPTION },
  //{ VIRTOLEDB_CPAGE_PROGID TEXT("\\Clsid"), NULL, REG_SZ, VIRTOLEDB_CPAGE_CLSID },
  { TEXT("CLSID\\") VIRTOLEDB_CPAGE_CLSID, NULL, REG_SZ, VIRTOLEDB_CPAGE_VI_PROGID},
  { TEXT("CLSID\\") VIRTOLEDB_CPAGE_CLSID TEXT("\\InprocServer32"), NULL, REG_SZ, TEXT("%s")},
  { TEXT("CLSID\\") VIRTOLEDB_CPAGE_CLSID TEXT("\\InprocServer32"), TEXT("ThreadingModel"), REG_SZ, TEXT("Both")},
  { TEXT("CLSID\\") VIRTOLEDB_CPAGE_CLSID TEXT("\\ProgId"), NULL, REG_SZ, VIRTOLEDB_CPAGE_PROGID },
  { TEXT("CLSID\\") VIRTOLEDB_CPAGE_CLSID TEXT("\\VersionIndependentProgId"), NULL, REG_SZ, VIRTOLEDB_CPAGE_VI_PROGID },

  // Data Link Advanced Page Registry Entries
#if ADVANCED_PAGE
  { VIRTOLEDB_APAGE_VI_PROGID, NULL, REG_SZ, VIRTOLEDB_APAGE_DESCRIPTION },
  { VIRTOLEDB_APAGE_VI_PROGID TEXT("\\Clsid"), NULL, REG_SZ, VIRTOLEDB_APAGE_CLSID },
  //{ VIRTOLEDB_APAGE_PROGID, NULL, REG_SZ, VIRTOLEDB_APAGE_DESCRIPTION },
  //{ VIRTOLEDB_APAGE_PROGID TEXT("\\Clsid"), NULL, REG_SZ, VIRTOLEDB_APAGE_CLSID },
  { TEXT("CLSID\\") VIRTOLEDB_APAGE_CLSID, NULL, REG_SZ, VIRTOLEDB_APAGE_VI_PROGID},
  { TEXT("CLSID\\") VIRTOLEDB_APAGE_CLSID TEXT("\\InprocServer32"), NULL, REG_SZ, TEXT("%s")},
  { TEXT("CLSID\\") VIRTOLEDB_APAGE_CLSID TEXT("\\InprocServer32"), TEXT("ThreadingModel"), REG_SZ, TEXT("Both")},
  { TEXT("CLSID\\") VIRTOLEDB_APAGE_CLSID TEXT("\\ProgId"), NULL, REG_SZ, VIRTOLEDB_APAGE_PROGID },
  { TEXT("CLSID\\") VIRTOLEDB_APAGE_CLSID TEXT("\\VersionIndependentProgId"), NULL, REG_SZ, VIRTOLEDB_APAGE_VI_PROGID },
#endif
};

#define REG_INFO_SIZE (sizeof reg_info / sizeof reg_info[0])


HINSTANCE Module::m_hModule;
LONG Module::m_iLockCnt = 0;
IGlobalInterfaceTable* Module::m_pGIT = NULL;
DWORD Module::m_dwTlsIndex = TLS_OUT_OF_INDEXES;
SyncObj Module::m_GlobalSync;

BOOL
Module::Attach(HINSTANCE hModule)
{
  m_hModule = hModule;

  HRESULT hr = ErrorInfo::Init();
  if (FAILED(hr))
    return FALSE;

  hr = CoCreateInstance(CLSID_StdGlobalInterfaceTable, NULL,
			CLSCTX_INPROC_SERVER, IID_IGlobalInterfaceTable,
			(void**) &m_pGIT);
  if (FAILED(hr))
    {
      LOGCALL(("Cannot create a global interface table instance.\n"));
      return false;
    }

  m_dwTlsIndex = TlsAlloc();
  if (m_dwTlsIndex == TLS_OUT_OF_INDEXES)
    {
      LOGCALL(("Cannot allocate a TLS index.\n"));
      return FALSE;
    }

  return TRUE;
}

BOOL
Module::Detach()
{
  ErrorInfo::Fini();

  if (m_dwTlsIndex != TLS_OUT_OF_INDEXES)
    {
      TlsFree(m_dwTlsIndex);
      m_dwTlsIndex = TLS_OUT_OF_INDEXES;
    }

  if (m_pGIT != NULL)
    {
      m_pGIT->Release();
      m_pGIT = NULL;
    }

  return TRUE;
}

HRESULT
Module::Register()
{
  TCHAR module_file_name[MAX_PATH + 1];

  if (0 == GetModuleFileName(m_hModule,
			     module_file_name,
			     sizeof module_file_name / sizeof (TCHAR)))
    return E_FAIL;

  DllUnregisterServer();

  for (int i = 0; i < REG_INFO_SIZE; i++)
    {
      const RegInfo* ri = reg_info + i;

      TCHAR buffer[1024];
      size_t size;
      if (ri->type == REG_DWORD)
	{
	  *(DWORD*)buffer = _ttoi(ri->value);
	  size = sizeof (DWORD);
	}
      else
	{
	  _stprintf(buffer, ri->value, module_file_name);
	  size = _tcslen(buffer) + 1;
	}

      HKEY hkey;
      DWORD disposition;
      LONG stat = RegCreateKeyEx(HKEY_CLASSES_ROOT, ri->reg_key, 0, NULL,
	                         REG_OPTION_NON_VOLATILE, KEY_ALL_ACCESS,
				 NULL, &hkey, &disposition);
      if (stat != ERROR_SUCCESS)
	return E_FAIL;

      stat = RegSetValueEx(hkey, ri->value_name, 0, ri->type, (BYTE*) buffer, size);
      RegCloseKey(hkey);
      if (stat != ERROR_SUCCESS)
	return E_FAIL;
    }

  return S_OK;
}

HRESULT
Module::Unregister()
{
  int i, errors = 0;

  // Delete all table entries.  Loop in reverse order, since they
  // are entered in a basic-to-complex order.
  // We cannot delete a key that has subkeys.
  // Ignore errors.
  for (i = OBSOLETE_REG_INFO_SIZE - 1; i >= 0; i--)
    {
      LONG stat = RegDeleteKey(HKEY_CLASSES_ROOT, obsolete_reg_info[i].reg_key);
      if ((stat != ERROR_SUCCESS) && (stat != ERROR_FILE_NOT_FOUND))
	errors++;
    }
  for (i = REG_INFO_SIZE - 1; i >= 0; i--)
    {
      LONG stat = RegDeleteKey(HKEY_CLASSES_ROOT, reg_info[i].reg_key);
      if ((stat != ERROR_SUCCESS) && (stat != ERROR_FILE_NOT_FOUND))
	errors++;
    }

  return errors ? E_FAIL : S_OK;
}

HRESULT
Module::GetClassObject(REFCLSID rclsid, REFIID riid, void** ppv)
{
  LOGCALL(("Module::GetClassObject(rclsid=%s, riid=%s)\n", STRINGFROMGUID(rclsid), STRINGFROMGUID(riid)));

  if (ppv == NULL)
    return E_INVALIDARG;

#if DEBUG
  int tmpDbgFlag = _CrtSetDbgFlag(_CRTDBG_REPORT_FLAG);
  tmpDbgFlag |= _CRTDBG_CHECK_ALWAYS_DF;
  _CrtSetDbgFlag(tmpDbgFlag);
#endif

  *ppv = NULL;

  static ComClassFactory<ComAggregateObj <CDataSource> > ds_factory;
  static ComClassFactory<ComAdaptiveObjCreator <CErrorLookup> > el_factory;
  static ComClassFactory<ComAdaptiveObjCreator <CConnectionPage> > cp_factory;
#if ADVANCED_PAGE
  static ComClassFactory<ComAdaptiveObjCreator <CAdvancedPage> > ap_factory;
#endif

  if (rclsid == CLSID_VIRTOLEDB)
    return ds_factory.QueryInterface(riid, ppv);
  else if (rclsid == CLSID_VIRTOLEDB_ERROR)
    return el_factory.QueryInterface(riid, ppv);
  else if (rclsid == CLSID_VIRTOLEDB_CONNECTION_PAGE)
    return cp_factory.QueryInterface(riid, ppv);
#if ADVANCED_PAGE
  else if (rclsid == CLSID_VIRTOLEDB_ADVANCED_PAGE)
    return ap_factory.QueryInterface(riid, ppv);
#endif
  return CLASS_E_CLASSNOTAVAILABLE;
}
