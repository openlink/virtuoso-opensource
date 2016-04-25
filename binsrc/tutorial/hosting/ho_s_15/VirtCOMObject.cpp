// VirtCOMObject.cpp : Implementation of CVirtCOMObject
/*
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

#include "stdafx.h"
#include "VirtCOMObject.h"
#include ".\virtcomobject.h"


// CVirtCOMObject


STDMETHODIMP CVirtCOMObject::AddAmount(DOUBLE amount)
{
    m_Balance += amount;
    return S_OK;
}

STDMETHODIMP CVirtCOMObject::Clear(void)
{
    m_Balance = 0;
    return S_OK;
}

STDMETHODIMP CVirtCOMObject::get_balance(DOUBLE* pVal)
{
    *pVal = m_Balance;
    return S_OK;
}

STDMETHODIMP CVirtCOMObject::put_balance(DOUBLE newVal)
{
    m_Balance = newVal;
    return S_OK;
}
