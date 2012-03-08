/*
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
// NNTP.h : Declaration of the CNNTP

#ifndef __NNTP_H_
#define __NNTP_H_

#include "resource.h"       // main symbols
//#import "D:\Virtuoso\VirtuosoSink\ReleaseMinDependency\Seo.tlb" raw_interfaces_only, raw_native_types, no_namespace, named_guids 
#import "D:\Program Files\Microsoft Platform SDK\Lib\CDOSys.Tlb" raw_interfaces_only, raw_native_types, no_namespace, named_guids 
#import "C:\Program Files\Common Files\System\ADO\msado15.dll" raw_interfaces_only, raw_native_types, no_namespace, named_guids 


/////////////////////////////////////////////////////////////////////////////
// CNNTP
class ATL_NO_VTABLE CNNTP : 
	public CComObjectRootEx<CComMultiThreadModel>,
	public CComCoClass<CNNTP, &CLSID_NNTP>,
	public IDispatchImpl<INNTP, &IID_INNTP, &LIBID_VIRTUOSOSINKLib>,
	public IDispatchImpl<INNTPOnPost, &IID_INNTPOnPost, &LIBID_CDO>,
	public IEventIsCacheable
{
public:
	CNNTP()
	{
	}

DECLARE_REGISTRY_RESOURCEID(IDR_NNTP)

DECLARE_PROTECT_FINAL_CONSTRUCT()

BEGIN_COM_MAP(CNNTP)
	COM_INTERFACE_ENTRY(INNTP)
//DEL 	COM_INTERFACE_ENTRY(IDispatch)
	COM_INTERFACE_ENTRY2(IDispatch, INNTP)
	COM_INTERFACE_ENTRY(INNTPOnPost)
	COM_INTERFACE_ENTRY(IEventIsCacheable)
END_COM_MAP()

// INNTP
public:
// INNTPOnPost
	STDMETHOD(OnPost)(IMessage * Msg, CdoEventStatus * EventStatus);
// IEventIsCacheable
	STDMETHOD(IsCacheable)()
	{
		return S_OK;
	}
};

#endif //__NNTP_H_
