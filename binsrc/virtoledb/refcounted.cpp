/*  refcounted.h
 *
 *  $Id$
 *
 *  Reference counted objects.
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

#include "headers.h"
#include "asserts.h"
#include "refcounted.h"

RefCountedImpl::RefCountedImpl(const char *identity)
  : ref_count(0), object_identity(identity)
{
  LOGCALL(("RefCountedImpl::RefCountedImpl() (%s)\n", object_identity));
}

RefCountedImpl::~RefCountedImpl()
{
  LOGCALL(("RefCountedImpl::~RefCountedImpl() (%s)\n", object_identity));
}

void
RefCountedImpl::AddRef()
{
  LOGCALL(("RefCountedImpl::AddRef() (%s), count=%d\n", object_identity, ref_count + 1));

  if (InterlockedIncrement(&ref_count) == 1)
    Referenced();
}

void
RefCountedImpl::Release()
{
  LOGCALL(("RefCountedImpl::Release() (%s), count=%d\n", object_identity, ref_count - 1));

  if (InterlockedDecrement(&ref_count) == 0)
    Unreferenced();
}

void
RefCountedImpl::Referenced()
{
}

void
RefCountedImpl::Unreferenced()
{
  delete this;
}
