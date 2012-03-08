/*  dllmodule.h
 *
 *  $Id$
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

#ifndef DLLMODULE_H
#define DLLMODULE_H

#include "syncobj.h"
#include "util.h"

class Module
{
public:

  static BOOL Attach(HINSTANCE hModule);
  static BOOL Detach();

  static HRESULT Register();
  static HRESULT Unregister();
  static HRESULT GetClassObject(REFCLSID rclsid, REFIID riid, void** ppv);

  static HINSTANCE
  GetInstanceHandle()
  {
    return m_hModule;
  }

  static void
  Lock()
  {
    LOGCALL(("Module::Lock() %d\n", m_iLockCnt + 1));
    InterlockedIncrement(&m_iLockCnt);
  }

  static void
  Unlock()
  {
    LOGCALL(("Module::Unlock() %d\n", m_iLockCnt - 1));
    InterlockedDecrement(&m_iLockCnt);
  }

  static BOOL
  CanUnloadNow()
  {
    return m_iLockCnt == 0;
  }

  static DWORD
  GetTlsIndex()
  {
    return m_dwTlsIndex;
  }

  static SafeInterface<IGlobalInterfaceTable>*
  GetGIT()
  {
    return (SafeInterface<IGlobalInterfaceTable>*) m_pGIT;
  }

  static SyncObj m_GlobalSync;

private:

  static HINSTANCE m_hModule;
  static LONG m_iLockCnt;
  static DWORD m_dwTlsIndex;
  static IGlobalInterfaceTable* m_pGIT;
};


#endif
