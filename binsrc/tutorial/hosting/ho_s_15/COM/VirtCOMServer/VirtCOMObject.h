/*
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
// VirtCOMObject.h : Declaration of the CVirtCOMObject

#pragma once
#include "resource.h"       // main symbols


// IVirtCOMObject
[
	object,
	uuid("051212BB-AD7E-47EE-BB0E-C1B723187166"),
	dual,	helpstring("IVirtCOMObject Interface"),
	pointer_default(unique)
]
__interface IVirtCOMObject : IDispatch
{
    [id(1), helpstring("adds an amount to the balance")] HRESULT AddAmount([in] DOUBLE amount);
    [id(2), helpstring("clears the balance (sets to 0)")] HRESULT Clear(void);
    [propget, id(3), helpstring("property balance")] HRESULT balance([out, retval] DOUBLE* pVal);
    [propput, id(3), helpstring("property balance")] HRESULT balance([in] DOUBLE newVal);
};



// CVirtCOMObject

[
	coclass,
	threading("apartment"),
	vi_progid("VirtCOMServer.VirtCOMObject"),
	progid("VirtCOMServer.VirtCOMObject.1"),
	version(1.0),
	uuid("2E280629-0FAA-4DCA-BAFD-AC4D0705B2EE"),
	helpstring("VirtCOMObject Class")
]
class ATL_NO_VTABLE CVirtCOMObject : 
	public IVirtCOMObject
{
public:
	CVirtCOMObject()
	    : m_Balance(0)
	{
	}


	DECLARE_PROTECT_FINAL_CONSTRUCT()

	HRESULT FinalConstruct()
	{
		return S_OK;
	}
	
	void FinalRelease() 
	{
	}

public:

    STDMETHOD(AddAmount)(DOUBLE amount);
    STDMETHOD(Clear)(void);
    STDMETHOD(get_balance)(DOUBLE* pVal);
    STDMETHOD(put_balance)(DOUBLE newVal);
protected:
    // the balance property
    double m_Balance;
};

