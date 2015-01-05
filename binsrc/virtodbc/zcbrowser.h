/*
 *  zcbrowser.h
 *
 *  $Id$
 *
 *  ZeroConfig Browser
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2015 OpenLink Software
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
 */

#ifndef _ZCBROWSER_H
#define _ZCBROWSER_H

#ifdef _RENDEZVOUS
#include "DNSServices.h"
#else
#endif

#define OUR_RENDEZVOUS_TYPE	"_virtuoso._tcp."

struct TZCPublication
  {
    TZCPublication *		next;
    LONG			refCount;
#ifdef _RENDEZVOUS
    DNSBrowserEventType		eventType;
    DNSNetworkAddress		interfaceAddr;
    DNSNetworkAddress		address;
#endif
    PTSTR			szName;
    PTSTR			szType;
    PTSTR			szText;
    PTSTR			szDomain;

    TZCPublication ();
    ~TZCPublication ();
    void Unref (void);
    void AddRef (void);
  };


struct TZCNotifier
  {
    TZCNotifier *		next;
    HANDLE			handle;
    UINT			uMsg;
    LPARAM			lParam;
  };


struct TZCBrowser
  {
    LONG			m_activeCount;
    CRITICAL_SECTION		m_csLock;
#ifdef _RENDEZVOUS
    DNSBrowserRef		m_DNS;
#endif
    BOOL			m_bInitDone;
    BOOL			m_bBrowsing;
    TZCPublication *		m_pItems;
    TZCNotifier *		m_pNotifiers;

    void AddZCDomain (const char *szDomain);
    void AddZCPublication (TZCPublication *pItem);
    void DoNotify (void);
    void FreeItems (void);

    TZCBrowser ();
    ~TZCBrowser ();
    void Lock ();
    void Unlock ();
#ifdef _RENDEZVOUS
    void StartBrowse (void);
    void StopBrowse (void);
#endif
    void RegisterNotify (HWND hWnd, UINT uMsg, LPARAM lParam);
    void RegisterNotify (HANDLE hEvent);
    void UnregisterNotify (HANDLE h);
    TZCPublication *Resolve (LPCTSTR szServer, DWORD dwTimeout);
  };


inline void
TZCBrowser::Lock (void)
{
  EnterCriticalSection (&m_csLock);
}

inline void
TZCBrowser::Unlock (void)
{
  LeaveCriticalSection (&m_csLock);
}

#ifdef _RENDEZVOUS
void DNSNetworkAddressToString (
    const DNSNetworkAddress *inAddr,
    PTSTR outString);
#endif

#endif
