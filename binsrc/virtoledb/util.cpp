/*  util.cpp
 *
 *  $Id$
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2014 OpenLink Software
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
#include "util.h"
#include "error.h"

#ifdef _MSC_VER
# include <malloc.h>
#else
# include <alloca.h>
#endif


HRESULT
olestr2string(const OLECHAR* olestr, std::string& string)
{
  string.erase();
  if (olestr == NULL)
    return S_OK;

  int length = WideCharToMultiByte(CP_ACP, 0, olestr, -1, NULL, 0, NULL, NULL);
  char* buffer = (char*) alloca(length);
  if (buffer == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  WideCharToMultiByte(CP_ACP, 0, olestr, -1, buffer, length, NULL, NULL);

  try {
    string.assign(buffer);
  } catch (...) {
    return ErrorInfo::Set(E_OUTOFMEMORY);
  }
  return S_OK;
}

HRESULT
string2bstr(const std::string& string, BSTR* pbstr)
{
  if (pbstr == NULL)
    return E_INVALIDARG;
  *pbstr = NULL;

  if (string.length() == 0)
    return S_OK;

  int length = MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, string.c_str(), -1, NULL, 0);
  OLECHAR *buffer = SysAllocStringLen(NULL, length * sizeof(OLECHAR));
  if (buffer == NULL)
    return ErrorInfo::Set(E_OUTOFMEMORY);

  MultiByteToWideChar(CP_ACP, MB_PRECOMPOSED, string.c_str(), -1, buffer, length);

  *pbstr = buffer;
  return S_OK;
}
