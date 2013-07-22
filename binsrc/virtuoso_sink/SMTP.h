/*
 *  
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *  
 *  Copyright (C) 1998-2013 OpenLink Software
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
// SMTP.h : Declaration of the CSMTP

#ifndef __SMTP_H_
#define __SMTP_H_

#import "D:\Program Files\Microsoft Platform SDK\Lib\CDOSys.Tlb" raw_interfaces_only, raw_native_types, no_namespace, named_guids 
#import "C:\Program Files\Common Files\System\ADO\msado15.dll" raw_interfaces_only, raw_native_types, no_namespace, named_guids 
#include "resource.h"       // main symbols
#include "DBConnectionPool.h"
#define SMTPINITGUID
#include <smtpguid.h>
#include <atlbase.h>
#include <atlimpl.cpp>


/////////////////////////////////////////////////////////////////////////////
// CSMTP
class ATL_NO_VTABLE CSMTP : 
	public CComObjectRootEx<CComMultiThreadModel>,
	public CComCoClass<CSMTP, &CLSID_SMTP>,
	public IDispatchImpl<ISMTP, &IID_ISMTP, &LIBID_VIRTUOSOSINKLib>,
	public IDispatchImpl<ISMTPOnArrival, &IID_ISMTPOnArrival, &LIBID_CDO>,
	public IEventIsCacheable
{
public:
	CSMTP()
	{
	}

DECLARE_REGISTRY_RESOURCEID(IDR_SMTP)

DECLARE_PROTECT_FINAL_CONSTRUCT()

BEGIN_COM_MAP(CSMTP)
	COM_INTERFACE_ENTRY(ISMTP)
//DEL 	COM_INTERFACE_ENTRY(IDispatch)
	COM_INTERFACE_ENTRY2(IDispatch, ISMTP)
	COM_INTERFACE_ENTRY(ISMTPOnArrival)
	COM_INTERFACE_ENTRY(IEventIsCacheable)
END_COM_MAP()

// ISMTP
public:
	static HRESULT UnregisterSink (long lInstance, BSTR BindingGUID);
	static HRESULT RegisterSink (long lInstance, BSTR DisplayName, BSTR BindingGUID/*, BSTR LogFilePath*/, VARIANT_BOOL fEnabled, BSTR* OutBindingGUID, TCHAR *rule);
// ISMTPOnArrival
	STDMETHOD(OnArrival)(IMessage * Msg, CdoEventStatus * EventStatus);
// IEventIsCacheable
	STDMETHOD(IsCacheable)()
	{
		return S_OK;
	}
};

#endif //__SMTP_H_
