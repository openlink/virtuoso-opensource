/*  baseobj.cpp
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

#include "headers.h"
#include "asserts.h"
#include "baseobj.h"

HRESULT
ComObjBase::InternalQueryInterface(REFIID riid, void** ppv)
{
  LOGCALL(("%s::InternalQueryInterface(%s)\n", typeid(*this).name(), StringFromGuid(riid)));

  if (ppv == NULL)
    return E_INVALIDARG;
  *ppv = NULL;

  IUnknown* pUnknown = NULL;
  if (riid == IID_IUnknown)
    pUnknown = static_cast<IUnknown*>(this);
  else
    {
      HRESULT hr = GetInterface(riid, &pUnknown);
      if (FAILED(hr))
	return hr;
      assert(pUnknown != NULL);
    }

  pUnknown->AddRef();
  *ppv = pUnknown;
  return S_OK;
}
